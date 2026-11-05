import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/settings_controller.dart';

/// The three optional source-API tokens (GitHub/GitLab/Codeberg), split out
/// of the main settings list into their own screen — they're a related,
/// rarely-touched group (only needed by someone hitting a rate limit or
/// using private repos), and listing all three inline on the main settings
/// screen pushed everything below them further down for every user who
/// never needs to touch any of them.
class AccessTokensScreen extends StatelessWidget {
  final SettingsController settings;

  const AccessTokensScreen({super.key, required this.settings});

  Future<void> _editToken(
    BuildContext context, {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accessTokensMenuTitle)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.accessTokensScreenIntro,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
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
                onTap: () => _editToken(
                  context,
                  dialogTitle: l10n.githubTokenDialogTitle,
                  fieldHint: l10n.githubTokenFieldHint,
                  currentValue: settings.githubToken,
                  onSave: settings.setGithubToken,
                ),
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
                onTap: () => _editToken(
                  context,
                  dialogTitle: l10n.gitlabTokenDialogTitle,
                  fieldHint: l10n.gitlabTokenFieldHint,
                  currentValue: settings.gitlabToken,
                  onSave: settings.setGitlabToken,
                ),
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
                onTap: () => _editToken(
                  context,
                  dialogTitle: l10n.codebergTokenDialogTitle,
                  fieldHint: l10n.codebergTokenFieldHint,
                  currentValue: settings.codebergToken,
                  onSave: settings.setCodebergToken,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
