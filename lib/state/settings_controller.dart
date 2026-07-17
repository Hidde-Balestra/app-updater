import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
class SettingsController extends ChangeNotifier {
  static const _kThemeMode = 'settings.themeMode';
  static const _kLocale = 'settings.locale';
  static const _kAutoCheck = 'settings.autoCheck';
  static const _kAutoCheckIntervalHours = 'settings.autoCheckIntervalHours';
  static const _kWifiOnly = 'settings.wifiOnly';
  static const _kNotifications = 'settings.notifications';

  ThemeMode themeMode = ThemeMode.system;
  Locale? locale; // null = follow system
  bool autoCheckEnabled = true;
  int autoCheckIntervalHours = 12;
  bool wifiOnly = true;
  bool notificationsEnabled = true;

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
    _loaded = true;
    notifyListeners();
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
  }

  Future<void> setWifiOnly(bool value) async {
    wifiOnly = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWifiOnly, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, value);
  }
}
