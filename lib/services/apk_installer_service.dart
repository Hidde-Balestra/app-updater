import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads an .apk into the app's own sandbox directory (no storage
/// permission needed under Android's scoped storage) and hands it off to
/// the system package installer via open_filex, which takes care of the
/// content:// FileProvider URI Android requires from N onward.
class ApkInstallerService {
  final http.Client _client;

  ApkInstallerService({http.Client? client})
    : _client = client ?? http.Client();

  Future<String> downloadApk({
    required String url,
    required String fileName,
    void Function(int received, int? total)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$fileName';

    final request = http.Request('GET', Uri.parse(url));
    final streamedResponse = await _client.send(request);
    if (streamedResponse.statusCode != 200) {
      throw Exception('Download mislukt (HTTP ${streamedResponse.statusCode})');
    }

    final total = streamedResponse.contentLength;
    var received = 0;
    final file = File(filePath);
    final sink = file.openWrite();
    try {
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
    return filePath;
  }

  Future<void> installApk(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  /// Deletes every downloaded `.apk` in the app's sandbox directory older
  /// than [minAge] — every download through [downloadApk] stays on disk
  /// forever otherwise (nothing currently deletes them), which adds up to
  /// real storage over time for an app that tracks several frequently-
  /// updated sources.
  ///
  /// [minAge] defaults to 10 minutes rather than deleting right after a
  /// successful install: [installApk] only confirms the system installer's
  /// intent was launched, not that the install finished — the system's own
  /// confirmation dialog and the actual copy can still be reading the file
  /// for a few seconds (or longer, if the user doesn't immediately respond
  /// to the "Install" prompt) after that call returns. 10 minutes is ample
  /// margin, run as best-effort maintenance on every app open rather than
  /// tied to any one specific download.
  Future<void> cleanUpOldDownloads({
    Duration minAge = const Duration(minutes: 10),
    Directory? directory,
  }) async {
    try {
      final dir = directory ?? await getApplicationDocumentsDirectory();
      if (!await dir.exists()) return;
      final cutoff = DateTime.now().subtract(minAge);
      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.apk')) {
          continue;
        }
        try {
          final modified = await entity.lastModified();
          if (modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {
          // Best-effort per file — one locked/already-gone file must not
          // stop the rest of the sweep.
        }
      }
    } catch (_) {
      // Best-effort overall — a missing/unreadable directory must not
      // surface as an error to the caller (this runs unawaited on load()).
    }
  }

  /// Hex-encoded SHA-256 of the file at [filePath], streamed rather than
  /// read fully into memory (APKs can be tens of MB). Shown to the user
  /// before install so they can cross-check it against a hash published
  /// elsewhere for the release — GitHub's releases API and F-Droid's index
  /// don't reliably expose one themselves, so this is informational rather
  /// than an automatic verification.
  Future<String> sha256Of(String filePath) async {
    final digest = await sha256.bind(File(filePath).openRead()).first;
    return digest.toString();
  }
}
