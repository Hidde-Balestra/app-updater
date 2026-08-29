import 'package:app_updater/models/release_info.dart';
import 'package:app_updater/services/accrescent/accrescent_service.dart';
import 'package:app_updater/services/accrescent/generated/accrescent_appstore.pbgrpc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

/// Overrides the real network call — the `grpc` package has no lightweight
/// fake channel for unit-testing a single RPC without a real server, so
/// [AccrescentService.getPackageInfo] is designed to be overridden directly
/// instead (same pattern as this codebase's other fakeable services).
class _FakeAccrescentService extends AccrescentService {
  final GetAppPackageInfoResponse? response;
  final Object? error;

  _FakeAccrescentService({this.response, this.error});

  @override
  Future<GetAppPackageInfoResponse> getPackageInfo(String appId) async {
    if (error != null) throw error!;
    return response!;
  }
}

void main() {
  test('resolves version name into a ReleaseSuccess with an Accrescent deep '
      'link as the download/source URL', () async {
    final service = _FakeAccrescentService(
      response: GetAppPackageInfoResponse(
        packageInfo: PackageInfo(versionName: '2026.07.23-6-Google'),
      ),
    );

    final result = await service.fetchLatestRelease('app.organicmaps');

    expect(result, isA<ReleaseSuccess>());
    final info = (result as ReleaseSuccess).info;
    expect(info.version, '2026.07.23-6-Google');
    expect(info.downloadUrl, 'https://accrescent.app/app/app.organicmaps');
    expect(info.sourcePageUrl, 'https://accrescent.app/app/app.organicmaps');
  });

  test('returns ReleaseNotFound on a gRPC NOT_FOUND error', () async {
    final service = _FakeAccrescentService(
      error: GrpcError.notFound('no such app'),
    );

    final result = await service.fetchLatestRelease('org.example.missing');

    expect(result, isA<ReleaseNotFound>());
  });

  test(
    'returns ReleaseNotFound when the package has no version name',
    () async {
      final service = _FakeAccrescentService(
        response: GetAppPackageInfoResponse(packageInfo: PackageInfo()),
      );

      final result = await service.fetchLatestRelease('app.organicmaps');

      expect(result, isA<ReleaseNotFound>());
    },
  );

  test('returns ReleaseError on any other gRPC error', () async {
    final service = _FakeAccrescentService(
      error: GrpcError.unavailable('server down'),
    );

    final result = await service.fetchLatestRelease('app.organicmaps');

    expect(result, isA<ReleaseError>());
  });

  test('returns ReleaseError for a non-gRPC exception too', () async {
    final service = _FakeAccrescentService(error: Exception('boom'));

    final result = await service.fetchLatestRelease('app.organicmaps');

    expect(result, isA<ReleaseError>());
  });

  test(
    'returns ReleaseError for empty input without calling the network',
    () async {
      final service = _FakeAccrescentService(
        error: StateError('should not be called'),
      );

      final result = await service.fetchLatestRelease('   ');

      expect(result, isA<ReleaseError>());
    },
  );
}
