import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/design_system/tokens/app_colors.dart';
import '../../core/design_system/tokens/app_radius.dart';
import '../../core/design_system/tokens/app_spacing.dart';
import '../../core/design_system/tokens/app_typography.dart';
import '../../core/design_system/components/app_button.dart';

class AppErrorState extends StatelessWidget {
  final String title;
  final String description;
  final String? retryLabel;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    required this.title,
    required this.description,
    this.retryLabel,
    this.onRetry,
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
                color: AppColors.colorStatusDangerSubtle,
                borderRadius: AppRadius.borderXl,
                border:
                    Border.all(color: AppColors.colorStatusDanger, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Icon(
                LucideIcons.alertOctagon,
                size: 32.0,
                color: AppColors.colorStatusDanger,
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
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.space24),
              AppButton(
                label: retryLabel ?? 'Retry',
                onPressed: onRetry,
                variant: AppButtonVariant.primary,
                icon: LucideIcons.refreshCw,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
