import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_shell.dart';
import 'state/app_library.dart';
import 'state/settings_controller.dart';
import 'theme/app_theme.dart';

void main() {
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
