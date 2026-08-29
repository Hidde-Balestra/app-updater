import 'package:grpc/grpc.dart';

import '../../models/release_info.dart';
import 'generated/accrescent_appstore.pbgrpc.dart';

/// Resolves the latest known version of an Accrescent-distributed app via
/// Accrescent's public gRPC appstore API (only the `GetAppPackageInfo` RPC —
/// see tool/proto/accrescent_appstore.proto for why this app only
/// implements that one call out of the full service).
///
/// Deliberately version-check only: actually downloading an Accrescent app
/// requires sending a full device-fingerprint payload (Android App Bundle's
/// `DeviceSpec` — ABIs, screen density, locale, ...) and can return several
/// split APKs that must be installed together via Android's PackageInstaller
/// session API. Neither fits this app's single-file download+install
/// pipeline, so [ReleaseInfo.downloadUrl] here is instead a
/// `https://accrescent.app/app/<id>` deep link (verified against
/// Accrescent's own AndroidManifest.xml) that opens the Accrescent app
/// itself to that listing — the UI opens it externally rather than
/// downloading it.
class AccrescentService {
  static const _host = 'appstore-api.accrescent.app';
  static const _port = 443;

  Future<ReleaseResult> fetchLatestRelease(String appId) async {
    final id = appId.trim();
    if (id.isEmpty) {
      return const ReleaseError('invalid_source');
    }

    try {
      final response = await getPackageInfo(id);
      final info = response.packageInfo;
      if (!info.hasVersionName() || info.versionName.isEmpty) {
        return const ReleaseNotFound();
      }
      return ReleaseSuccess(
        ReleaseInfo(
          version: info.versionName,
          downloadUrl: 'https://accrescent.app/app/$id',
          sourcePageUrl: 'https://accrescent.app/app/$id',
        ),
      );
    } on GrpcError catch (e) {
      if (e.code == StatusCode.notFound) {
        return const ReleaseNotFound();
      }
      return ReleaseError(e.message ?? 'gRPC error ${e.code}');
    } catch (e) {
      return ReleaseError(e.toString());
    }
  }

  /// The actual network call, split out so tests can override it with a
  /// canned response/error instead of reaching the real Accrescent server —
  /// same pattern as [DeviceAppsService]/[ApkInstallerService] in this
  /// codebase, since the `grpc` package has no lightweight fake channel for
  /// unit-testing a single RPC.
  Future<GetAppPackageInfoResponse> getPackageInfo(String appId) async {
    final channel = ClientChannel(
      _host,
      port: _port,
      options: const ChannelOptions(credentials: ChannelCredentials.secure()),
    );
    try {
      final client = AppServiceClient(channel);
      return await client.getAppPackageInfo(
        GetAppPackageInfoRequest(appId: appId),
      );
    } finally {
      await channel.shutdown();
    }
  }
}
