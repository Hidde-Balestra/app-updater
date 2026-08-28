import 'package:app_updater/services/device_apps_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('installed_apps');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

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

  test(
    'returns null for a blank package name without calling the platform',
    () async {
      var called = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        called = true;
        return null;
      });

      final version = await DeviceAppsService().installedVersion('   ');

      expect(version, isNull);
      expect(called, isFalse);
    },
  );

  test(
    'installedPackageNames returns the package name of every installed app',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getInstalledApps');
        return [
          {'name': 'One', 'package_name': 'com.example.one'},
          {'name': 'Two', 'package_name': 'com.example.two'},
        ];
      });

      final names = await DeviceAppsService().installedPackageNames();

      expect(names, {'com.example.one', 'com.example.two'});
    },
  );

  test(
    'installedPackageNames returns an empty set when the platform errors',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });

      final names = await DeviceAppsService().installedPackageNames();

      expect(names, isEmpty);
    },
  );

  test('installedApps maps every installed app to InstalledApp', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getInstalledApps');
      return [
        {
          'name': 'One',
          'package_name': 'com.example.one',
          'version_name': '1.0.0',
        },
        {
          'name': 'Two',
          'package_name': 'com.example.two',
          'version_name': '2.0.0',
        },
      ];
    });

    final apps = await DeviceAppsService().installedApps();

    expect(apps, hasLength(2));
    expect(apps[0].name, 'One');
    expect(apps[0].packageName, 'com.example.one');
    expect(apps[0].versionName, '1.0.0');
    expect(apps[1].packageName, 'com.example.two');
  });
}
