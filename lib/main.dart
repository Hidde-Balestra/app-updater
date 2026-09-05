import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/app_detail_screen.dart';
import 'screens/home_shell.dart';
import 'services/background_scheduler.dart';
import 'services/notification_service.dart';
import 'state/app_library.dart';
import 'state/settings_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Registers the WorkManager callback dispatcher up front so a scheduled
  // background check has a handler to run against; actually scheduling (or
  // cancelling) the periodic task happens in SettingsController once
  // "Automatisch controleren" is known to be on or off.
  unawaited(BackgroundScheduler().initialize());
  runApp(const AppUpdaterApp());
}

class AppUpdaterApp extends StatefulWidget {
  const AppUpdaterApp({super.key});

  @override
  State<AppUpdaterApp> createState() => _AppUpdaterAppState();
}

class _AppUpdaterAppState extends State<AppUpdaterApp> {
  final _settings = SettingsController();
  final _library = AppLibrary();
  final _notifications = NotificationService();
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _settings.load();
    _library.load();
    unawaited(_setUpNotificationTapHandling());
  }

  /// Lets tapping a single-app "update available" notification jump
  /// straight to that app's detail screen instead of just opening the app
  /// to its default screen — see [NotificationService.showUpdatesAvailable]
  /// for when a payload is (and isn't) set.
  Future<void> _setUpNotificationTapHandling() async {
    await _notifications.initialize(onTap: _openAppFromNotification);
    final launchPayload = await _notifications.getLaunchPayload();
    if (launchPayload != null) {
      // The very first frame hasn't necessarily built the Navigator yet
      // when the app is cold-started by tapping a notification.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openAppFromNotification(launchPayload);
      });
    }
  }

  void _openAppFromNotification(String? appId) {
    if (appId == null || appId.isEmpty) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AppDetailScreen(library: _library, appId: appId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        _library.githubToken = _settings.githubToken;
        _library.gitlabToken = _settings.gitlabToken;
        _library.codebergToken = _settings.codebergToken;
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'App Updater',
          debugShowCheckedModeBanner: false,
          themeMode: _settings.themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: _settings.locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: HomeShell(library: _library, settings: _settings),
        );
      },
    );
  }
}
