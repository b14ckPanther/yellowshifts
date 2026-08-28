import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../domain/models/kiosk_device.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

class KioskHealthBadge extends StatelessWidget {
  final KioskDevice device;

  const KioskHealthBadge({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;

    if (!device.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.colorError.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppColors.colorError.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.powerOff,
                size: 12, color: AppColors.colorError),
            const SizedBox(width: 4),
            Text(
              l10n.kioskStatusInactive,
              style: typography.caption.copyWith(
                color: AppColors.colorError,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final isOnline = device.isOnline;
    final color = isOnline ? AppColors.colorSuccess : AppColors.colorWarning;
    final label = isOnline ? l10n.kioskStatusOnline : l10n.kioskStatusOffline;
    final icon = isOnline ? LucideIcons.activity : LucideIcons.wifiOff;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: typography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
