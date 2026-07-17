import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads an .apk into the app's own sandbox directory (no storage
/// permission needed under Android's scoped storage) and hands it off to
/// the system package installer via open_filex, which takes care of the
/// content:// FileProvider URI Android requires from N onward.
class ApkInstallerService {
  final http.Client _client;

  ApkInstallerService({http.Client? client}) : _client = client ?? http.Client();

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
}
