import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/design_system/tokens/app_colors.dart';
import '../../core/design_system/tokens/app_radius.dart';
import '../../core/design_system/tokens/app_spacing.dart';
import '../../core/design_system/tokens/app_typography.dart';
import '../../core/design_system/components/app_button.dart';

class AppEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = LucideIcons.inbox,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.0,
              height: 72.0,
              decoration: BoxDecoration(
                color: AppColors.colorSurfaceBrandSubtle,
                borderRadius: AppRadius.borderXl,
                border: Border.all(
                    color: AppColors.colorSurfaceBrandAccent, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 32.0,
                color: AppColors.colorTextBrand,
              ),
            ),
            const SizedBox(height: AppSpacing.space20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: typography.titleMedium.copyWith(
                color: AppColors.colorTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420.0),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: typography.bodyMedium.copyWith(
                  color: AppColors.colorTextSecondary,
                  height: 1.45,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.space24),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
