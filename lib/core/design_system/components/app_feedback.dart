import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

enum AppFeedbackType { success, warning, error, info }

class AppFeedback {
  static void show(
    BuildContext context, {
    required String message,
    AppFeedbackType type = AppFeedbackType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    Color bgColor;
    Color textColor;
    IconData icon;

    switch (type) {
      case AppFeedbackType.success:
        bgColor = AppColors.colorStatusSuccess;
        textColor = AppColors.colorTextInverse;
        icon = LucideIcons.checkCircle2;
        break;
      case AppFeedbackType.warning:
        bgColor = AppColors.colorStatusWarning;
        textColor = AppColors.colorTextPrimary;
        icon = LucideIcons.alertTriangle;
        break;
      case AppFeedbackType.error:
        bgColor = AppColors.colorStatusDanger;
        textColor = AppColors.colorTextInverse;
        icon = LucideIcons.alertCircle;
        break;
      case AppFeedbackType.info:
        bgColor = AppColors.colorSurfaceRaised;
        textColor = AppColors.colorTextPrimary;
        icon = LucideIcons.info;
        break;
    }

    const typography = AppTypography();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.space16),
        content: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space16,
            vertical: AppSpacing.space12,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadius.borderMd,
            border: type == AppFeedbackType.info
                ? Border.all(color: AppColors.colorBorderSubtle)
                : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 8.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 20.0, color: textColor),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: Text(
                  message,
                  style: typography.bodyMedium.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
