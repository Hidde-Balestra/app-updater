import 'dart:convert';

import 'package:app_updater/services/background_scheduler.dart';
import 'package:app_updater/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScheduleCall {
  final Duration interval;
  final bool wifiOnly;
  _ScheduleCall(this.interval, this.wifiOnly);
}

class _FakeBackgroundScheduler extends BackgroundScheduler {
  final List<_ScheduleCall> scheduleCalls = [];
  int cancelCalls = 0;

  @override
  Future<void> schedule(Duration interval, {bool wifiOnly = false}) async {
    scheduleCalls.add(_ScheduleCall(interval, wifiOnly));
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'load() schedules the background check when auto-check is on by default',
    () async {
      final scheduler = _FakeBackgroundScheduler();
      final settings = SettingsController(scheduler: scheduler);

      await settings.load();

      expect(scheduler.scheduleCalls, hasLength(1));
      expect(
        scheduler.scheduleCalls.single.interval,
        const Duration(hours: 12),
      );
      expect(scheduler.scheduleCalls.single.wifiOnly, isTrue);
    },
  );

  test(
    'load() does not schedule when auto-check was persisted as off',
    () async {
      SharedPreferences.setMockInitialValues({'settings.autoCheck': false});
      final scheduler = _FakeBackgroundScheduler();
      final settings = SettingsController(scheduler: scheduler);

      await settings.load();

      expect(scheduler.scheduleCalls, isEmpty);
    },
  );

  test('setAutoCheckEnabled(false) cancels the background check', () async {
    final scheduler = _FakeBackgroundScheduler();
    final settings = SettingsController(scheduler: scheduler);
    await settings.load();

    await settings.setAutoCheckEnabled(false);

    expect(scheduler.cancelCalls, 1);
  });

  test(
    'setAutoCheckEnabled(true) (re)schedules the background check',
    () async {
      SharedPreferences.setMockInitialValues({'settings.autoCheck': false});
      final scheduler = _FakeBackgroundScheduler();
      final settings = SettingsController(scheduler: scheduler);
      await settings.load();
      expect(scheduler.scheduleCalls, isEmpty);

      await settings.setAutoCheckEnabled(true);

      expect(scheduler.scheduleCalls, hasLength(1));
    },
  );

  test(
    'setWifiOnly reschedules with the new constraint while auto-check is on',
    () async {
      final scheduler = _FakeBackgroundScheduler();
      final settings = SettingsController(scheduler: scheduler);
      await settings.load();
      scheduler.scheduleCalls.clear();

      await settings.setWifiOnly(false);

      expect(scheduler.scheduleCalls, hasLength(1));
      expect(scheduler.scheduleCalls.single.wifiOnly, isFalse);
    },
  );

  test('setWifiOnly does not schedule while auto-check is off', () async {
    SharedPreferences.setMockInitialValues({'settings.autoCheck': false});
    final scheduler = _FakeBackgroundScheduler();
    final settings = SettingsController(scheduler: scheduler);
    await settings.load();

    await settings.setWifiOnly(false);

    expect(scheduler.scheduleCalls, isEmpty);
  });

  test('githubToken is null by default', () async {
    final settings = SettingsController(scheduler: _FakeBackgroundScheduler());
    await settings.load();

    expect(settings.githubToken, isNull);
  });

  test('setGithubToken persists the token across a reload', () async {
    final settings = SettingsController(scheduler: _FakeBackgroundScheduler());
    await settings.load();

    await settings.setGithubToken('ghp_example123');

    expect(settings.githubToken, 'ghp_example123');
    final reloaded = SettingsController(scheduler: _FakeBackgroundScheduler());
    await reloaded.load();
    expect(reloaded.githubToken, 'ghp_example123');
  });

  test('setGithubToken clears the token when set to an empty value', () async {
    final settings = SettingsController(scheduler: _FakeBackgroundScheduler());
    await settings.load();
    await settings.setGithubToken('ghp_example123');

    await settings.setGithubToken('');

    expect(settings.githubToken, isNull);
    final reloaded = SettingsController(scheduler: _FakeBackgroundScheduler());
    await reloaded.load();
    expect(reloaded.githubToken, isNull);
  });

  test('gitlabToken and codebergToken are null by default', () async {
    final settings = SettingsController(scheduler: _FakeBackgroundScheduler());
    await settings.load();

    expect(settings.gitlabToken, isNull);
    expect(settings.codebergToken, isNull);
  });

  test('setGitlabToken persists the token across a reload', () async {
    final settings = SettingsController(scheduler: _FakeBackgroundScheduler());
    await settings.load();

    await settings.setGitlabToken('glpat-example123');

    expect(settings.gitlabToken, 'glpat-example123');
    final reloaded = SettingsController(scheduler: _FakeBackgroundScheduler());
    await reloaded.load();
    expect(reloaded.gitlabToken, 'glpat-example123');
  });

  test('setCodebergToken persists the token across a reload', () async {
    final settings = SettingsController(scheduler: _FakeBackgroundScheduler());
    await settings.load();

    await settings.setCodebergToken('codeberg-example123');

    expect(settings.codebergToken, 'codeberg-example123');
    final reloaded = SettingsController(scheduler: _FakeBackgroundScheduler());
    await reloaded.load();
    expect(reloaded.codebergToken, 'codeberg-example123');
  });

  test('setGitlabToken and setCodebergToken clear the token when set to an '
      'empty value', () async {
    final settings = SettingsController(scheduler: _FakeBackgroundScheduler());
    await settings.load();
    await settings.setGitlabToken('glpat-example123');
    await settings.setCodebergToken('codeberg-example123');

    await settings.setGitlabToken('');
    await settings.setCodebergToken('');

    expect(settings.gitlabToken, isNull);
    expect(settings.codebergToken, isNull);
  });

  group('exportSettingsData/importSettingsData', () {
    test('excludes tokens', () async {
      final settings = SettingsController(
        scheduler: _FakeBackgroundScheduler(),
      );
      await settings.load();
      await settings.setGithubToken('ghp_secret');
      await settings.setGitlabToken('glpat-secret');
      await settings.setCodebergToken('codeberg-secret');

      final data = settings.exportSettingsData();

      expect(data.containsKey('githubToken'), isFalse);
      expect(data.containsKey('gitlabToken'), isFalse);
      expect(data.containsKey('codebergToken'), isFalse);
      expect(jsonEncode(data), isNot(contains('secret')));
    });

    test('round-trips into a fresh controller', () async {
      final source = SettingsController(scheduler: _FakeBackgroundScheduler());
      await source.load();
      await source.setThemeMode(ThemeMode.dark);
      await source.setLocale(const Locale('de'));
      await source.setAutoCheckEnabled(false);
      await source.setWifiOnly(false);
      await source.setNotificationsEnabled(false);
      final data = source.exportSettingsData();

      final target = SettingsController(scheduler: _FakeBackgroundScheduler());
      await target.load();
      await target.importSettingsData(data);

      expect(target.themeMode, ThemeMode.dark);
      expect(target.locale, const Locale('de'));
      expect(target.autoCheckEnabled, isFalse);
      expect(target.wifiOnly, isFalse);
      expect(target.notificationsEnabled, isFalse);
    });

    test('ignores unknown or malformed fields instead of throwing', () async {
      final settings = SettingsController(
        scheduler: _FakeBackgroundScheduler(),
      );
      await settings.load();

      await settings.importSettingsData({
        'themeMode': 'not-a-real-mode',
        'autoCheckEnabled': 'not-a-bool',
        'somethingElse': 123,
      });

      expect(settings.themeMode, ThemeMode.system);
      expect(settings.autoCheckEnabled, isTrue);
    });
  });
}
