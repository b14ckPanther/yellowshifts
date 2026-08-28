import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../network/connectivity_service.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import '../../../l10n/app_localizations.dart';

/// Non-intrusive slim connectivity banner displayed at the top of the shell.
class AppConnectivityBanner extends ConsumerWidget {
  const AppConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectivityProvider);
    if (state.isOnline) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    const typography = AppTypography();

    Color bgColor;
    Color fgColor;
    IconData icon;
    String text;

    if (state.isOffline) {
      bgColor = AppColors.colorStatusDanger.withValues(alpha: 0.95);
      fgColor = Colors.white;
      icon = LucideIcons.wifiOff;
      text = l10n?.connectionOffline ?? 'Offline — Read Only';
    } else if (state.isReconnecting) {
      bgColor = AppColors.colorSurfaceBrand.withValues(alpha: 0.95);
      fgColor = Colors.black;
      icon = LucideIcons.refreshCw;
      text = l10n?.connectionReconnecting ?? 'Reconnecting...';
    } else {
      bgColor = AppColors.colorStatusWarning.withValues(alpha: 0.95);
      fgColor = Colors.black;
      icon = LucideIcons.alertTriangle;
      text = l10n?.connectionDegraded ?? 'Degraded Connection';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space6,
      ),
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14.0, color: fgColor),
            const SizedBox(width: AppSpacing.space8),
            Text(
              text,
              style: typography.labelSmall.copyWith(
                color: fgColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
