import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../state/settings_controller.dart';
import '../widgets/section_header.dart';

const _repoUrl = 'https://github.com/Hidde-Balestra/app-updater';

class SettingsScreen extends StatefulWidget {
  final SettingsController settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  String _languageName(AppLocalizations l10n, Locale? locale) {
    if (locale == null) return l10n.languageSystem;
    return switch (locale.languageCode) {
      'nl' => l10n.languageDutch,
      'en' => l10n.languageEnglish,
      'es' => l10n.languageSpanish,
      'de' => l10n.languageGerman,
      'it' => l10n.languageItalian,
      _ => locale.languageCode,
    };
  }

  Future<void> _pickLanguage() async {
    final l10n = AppLocalizations.of(context)!;
    final options = <Locale?>[null, ...supportedLocales];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final locale in options)
                ListTile(
                  title: Text(_languageName(l10n, locale)),
                  trailing: widget.settings.locale == locale
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    widget.settings.setLocale(locale);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) {
          final settings = widget.settings;
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              SectionHeader(title: l10n.sectionDisplay),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.darkMode),
                subtitle: Text(l10n.darkModeSubtitle),
                value: settings.themeMode == ThemeMode.dark,
                onChanged: (value) => settings.setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
              SectionHeader(title: l10n.sectionLanguage),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.languageSubtitle),
                trailing: Text(_languageName(l10n, settings.locale)),
                onTap: _pickLanguage,
              ),
              SectionHeader(title: l10n.sectionUpdates),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.autoCheck),
                subtitle: Text(
                  l10n.autoCheckSubtitle(settings.autoCheckIntervalHours),
                ),
                value: settings.autoCheckEnabled,
                onChanged: settings.setAutoCheckEnabled,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.wifiOnly),
                subtitle: Text(l10n.wifiOnlySubtitle),
                value: settings.wifiOnly,
                onChanged: settings.setWifiOnly,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.notifications),
                subtitle: Text(l10n.notificationsSubtitle),
                value: settings.notificationsEnabled,
                onChanged: settings.setNotificationsEnabled,
              ),
              SectionHeader(title: l10n.sectionPrivacy),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF1E9E5A)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.privacyTitle,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(l10n.privacyMessage),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SectionHeader(title: l10n.sectionAbout),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.versionLabel),
                subtitle: Text(
                  l10n.versionValue(_version.isEmpty ? '…' : _version),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.sourceCodeLink),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => launchUrl(
                  Uri.parse(_repoUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
