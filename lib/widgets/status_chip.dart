import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/library_entry.dart';
import '../theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  final AppCheckStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    late final String label;
    late final Color foreground;
    Color background = Colors.transparent;

    switch (status) {
      case AppCheckStatus.updateAvailable:
        label = l10n.statusUpdate;
        foreground = AppColors.updateOrange;
        background = isDark ? AppColors.updateOrangeBgDark : AppColors.updateOrangeBgLight;
      case AppCheckStatus.upToDate:
        label = l10n.statusUpToDate;
        foreground = AppColors.upToDateGreen;
        background = isDark ? AppColors.upToDateGreenBgDark : AppColors.upToDateGreenBgLight;
      case AppCheckStatus.checking:
        label = l10n.statusChecking;
        foreground = AppColors.neutralGrey;
      case AppCheckStatus.error:
        label = l10n.statusError;
        foreground = AppColors.errorRed;
        background = isDark ? AppColors.errorRedBgDark : AppColors.errorRedBgLight;
      case AppCheckStatus.noReleases:
        label = l10n.statusNoReleases;
        foreground = AppColors.neutralGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
