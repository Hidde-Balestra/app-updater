import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/background_scheduler.dart';
import 'storage_keys.dart';

const List<Locale> supportedLocales = [
  Locale('nl'),
  Locale('en'),
  Locale('es'),
  Locale('de'),
  Locale('it'),
];

/// Persisted app-wide preferences (theme, language, update-check behaviour).
/// A plain ChangeNotifier + shared_preferences, no extra state-management
/// package — kept consistent with the other Flutter apps in this account.
///
/// Also owns (de)registering the WorkManager periodic task backing
/// "Automatisch controleren", since that's a setting-driven side effect
/// rather than something [AppLibrary] should know about.
class SettingsController extends ChangeNotifier {
  static const _kThemeMode = 'settings.themeMode';
  static const _kLocale = 'settings.locale';
  static const _kAutoCheck = 'settings.autoCheck';
  static const _kAutoCheckIntervalHours = 'settings.autoCheckIntervalHours';
  static const _kWifiOnly = 'settings.wifiOnly';
  static const _kNotifications = StorageKeys.notificationsEnabled;

  static const _secureStorage = FlutterSecureStorage();

  final BackgroundScheduler _scheduler;

  SettingsController({BackgroundScheduler? scheduler})
    : _scheduler = scheduler ?? BackgroundScheduler();

  ThemeMode themeMode = ThemeMode.system;
  Locale? locale; // null = follow system
  bool autoCheckEnabled = true;
  int autoCheckIntervalHours = 12;
  bool wifiOnly = true;
  bool notificationsEnabled = true;

  /// Optional GitHub personal access token, used to raise the unauthenticated
  /// API rate limit (60 requests/hour) when many GitHub-tracked apps are
  /// checked. Kept in secure storage rather than SharedPreferences since it's
  /// a credential, unlike every other setting here.
  String? githubToken;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_kThemeMode);
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == themeName,
      orElse: () => ThemeMode.system,
    );
    final localeCode = prefs.getString(_kLocale);
    locale = (localeCode == null || localeCode.isEmpty)
        ? null
        : Locale(localeCode);
    autoCheckEnabled = prefs.getBool(_kAutoCheck) ?? true;
    autoCheckIntervalHours = prefs.getInt(_kAutoCheckIntervalHours) ?? 12;
    wifiOnly = prefs.getBool(_kWifiOnly) ?? true;
    notificationsEnabled = prefs.getBool(_kNotifications) ?? true;
    githubToken = await _secureStorage.read(key: StorageKeys.githubToken);
    _loaded = true;
    notifyListeners();
    if (autoCheckEnabled) {
      await _applySchedule();
    }
  }

  Future<void> _applySchedule() {
    return _scheduler.schedule(
      Duration(hours: autoCheckIntervalHours),
      wifiOnly: wifiOnly,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }

  Future<void> setLocale(Locale? newLocale) async {
    locale = newLocale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, newLocale?.languageCode ?? '');
  }

  Future<void> setAutoCheckEnabled(bool value) async {
    autoCheckEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoCheck, value);
    if (value) {
      await _applySchedule();
    } else {
      await _scheduler.cancel();
    }
  }

  Future<void> setWifiOnly(bool value) async {
    wifiOnly = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWifiOnly, value);
    if (autoCheckEnabled) {
      await _applySchedule();
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, value);
  }

  Future<void> setGithubToken(String? value) async {
    final trimmed = value?.trim();
    githubToken = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    notifyListeners();
    if (githubToken == null) {
      await _secureStorage.delete(key: StorageKeys.githubToken);
    } else {
      await _secureStorage.write(
        key: StorageKeys.githubToken,
        value: githubToken,
      );
    }
  }
}
