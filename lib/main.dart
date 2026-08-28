import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_shell.dart';
import 'services/background_scheduler.dart';
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

  @override
  void initState() {
    super.initState();
    _settings.load();
    _library.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        return MaterialApp(
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
