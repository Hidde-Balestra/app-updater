import 'package:app_updater/services/device_apps_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('installed_apps');
  final messenger = TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('returns the installed versionName for a known package', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getAppInfo');
      expect(call.arguments, {'package_name': 'com.example.app'});
      return {
        'name': 'Example',
        'package_name': 'com.example.app',
        'version_name': '2.3.0',
        'version_code': 7,
      };
    });

    final version = await DeviceAppsService().installedVersion(
      'com.example.app',
    );

    expect(version, '2.3.0');
  });

  test('returns null when the package is not installed', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    final version = await DeviceAppsService().installedVersion(
      'com.example.notinstalled',
    );

    expect(version, isNull);
  });

  test('returns null for a blank package name without calling the platform', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });

    final version = await DeviceAppsService().installedVersion('   ');

    expect(version, isNull);
    expect(called, isFalse);
  });
}
