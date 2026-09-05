import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../state/app_library.dart';
import '../state/settings_controller.dart';
import '../widgets/section_header.dart';
import 'device_apps_screen.dart';
import 'update_history_screen.dart';

const _repoUrl = 'https://github.com/Hidde-Balestra/app-updater';

class SettingsScreen extends StatefulWidget {
  final SettingsController settings;
  final AppLibrary library;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.library,
  });

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

  Future<void> _exportToClipboard() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final count = widget.library.entries.length;
    await Clipboard.setData(ClipboardData(text: widget.library.exportJson()));
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportSuccess(count))));
  }

  Future<void> _importFromClipboard() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text ?? '';
    if (raw.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importError)));
      return;
    }
    try {
      final added = await widget.library.importJson(raw);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added == 0 ? l10n.importNothingNew : l10n.importSuccess(added),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importError)));
    }
  }

  Future<void> _editToken({
    required String dialogTitle,
    required String fieldHint,
    required String? currentValue,
    required Future<void> Function(String?) onSave,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    var draft = currentValue ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogTitle),
        content: TextFormField(
          initialValue: draft,
          obscureText: true,
          decoration: InputDecoration(hintText: fieldHint),
          onChanged: (value) => draft = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(draft),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (result != null) {
      await onSave(result);
    }
  }

  Future<void> _editGithubToken() async {
    final l10n = AppLocalizations.of(context)!;
    await _editToken(
      dialogTitle: l10n.githubTokenDialogTitle,
      fieldHint: l10n.githubTokenFieldHint,
      currentValue: widget.settings.githubToken,
      onSave: widget.settings.setGithubToken,
    );
  }

  Future<void> _editGitlabToken() async {
    final l10n = AppLocalizations.of(context)!;
    await _editToken(
      dialogTitle: l10n.gitlabTokenDialogTitle,
      fieldHint: l10n.gitlabTokenFieldHint,
      currentValue: widget.settings.gitlabToken,
      onSave: widget.settings.setGitlabToken,
    );
  }

  Future<void> _editCodebergToken() async {
    final l10n = AppLocalizations.of(context)!;
    await _editToken(
      dialogTitle: l10n.codebergTokenDialogTitle,
      fieldHint: l10n.codebergTokenFieldHint,
      currentValue: widget.settings.codebergToken,
      onSave: widget.settings.setCodebergToken,
    );
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text(l10n.githubTokenTitle),
                subtitle: Text(
                  settings.githubToken == null
                      ? l10n.githubTokenNotSet
                      : l10n.githubTokenSet,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _editGithubToken,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text(l10n.gitlabTokenTitle),
                subtitle: Text(
                  settings.gitlabToken == null
                      ? l10n.gitlabTokenNotSet
                      : l10n.githubTokenSet,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _editGitlabToken,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text(l10n.codebergTokenTitle),
                subtitle: Text(
                  settings.codebergToken == null
                      ? l10n.codebergTokenNotSet
                      : l10n.githubTokenSet,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _editCodebergToken,
              ),
              SectionHeader(title: l10n.sectionDevice),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_android_outlined),
                title: Text(l10n.deviceAppsMenuTitle),
                subtitle: Text(l10n.deviceAppsMenuSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeviceAppsScreen(library: widget.library),
                  ),
                ),
              ),
              SectionHeader(title: l10n.sectionHistory),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(l10n.updateHistoryMenuTitle),
                subtitle: Text(l10n.updateHistoryMenuSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        UpdateHistoryScreen(library: widget.library),
                  ),
                ),
              ),
              SectionHeader(title: l10n.sectionBackup),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.copy_all_outlined),
                title: Text(l10n.exportButton),
                onTap: _exportToClipboard,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.content_paste_go_outlined),
                title: Text(l10n.importButton),
                onTap: _importFromClipboard,
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
