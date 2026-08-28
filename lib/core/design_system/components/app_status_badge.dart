import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

enum AppBadgeVariant { success, warning, danger, info, brand, neutral }

class AppStatusBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;

  const AppStatusBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
  });

  Color _getBackgroundColor() {
    switch (variant) {
      case AppBadgeVariant.success:
        return AppColors.colorStatusSuccessSubtle;
      case AppBadgeVariant.warning:
        return AppColors.colorStatusWarningSubtle;
      case AppBadgeVariant.danger:
        return AppColors.colorStatusDangerSubtle;
      case AppBadgeVariant.info:
        return AppColors.colorStatusInfoSubtle;
      case AppBadgeVariant.brand:
        return AppColors.colorSurfaceBrandAccent;
      case AppBadgeVariant.neutral:
        return AppColors.colorSurfaceMuted;
    }
  }

  Color _getTextColor() {
    switch (variant) {
      case AppBadgeVariant.success:
        return AppColors.colorStatusSuccess;
      case AppBadgeVariant.warning:
        return AppColors.colorStatusWarning;
      case AppBadgeVariant.danger:
        return AppColors.colorStatusDanger;
      case AppBadgeVariant.info:
        return AppColors.colorStatusInfo;
      case AppBadgeVariant.brand:
        return AppColors.colorTextPrimary;
      case AppBadgeVariant.neutral:
        return AppColors.colorTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final textColor = _getTextColor();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: AppRadius.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.0, color: textColor),
            const SizedBox(width: AppSpacing.space4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: typography.caption.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
