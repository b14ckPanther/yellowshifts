import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import '../responsive/app_breakpoints.dart';

class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final isCompact = AppBreakpoints.isCompact(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space16,
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onBack != null) ...[
                      IconButton(
                        icon: const Icon(LucideIcons.arrowLeft, size: 20.0),
                        onPressed: onBack,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: AppSpacing.space12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: typography.titleLarge.copyWith(
                          color: AppColors.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    subtitle!,
                    style: typography.bodyMedium.copyWith(
                      color: AppColors.colorTextSecondary,
                    ),
                  ),
                ],
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.space12),
                  Wrap(
                    spacing: AppSpacing.space8,
                    runSpacing: AppSpacing.space8,
                    children: actions!,
                  ),
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (onBack != null) ...[
                  IconButton(
                    icon: const Icon(LucideIcons.arrowLeft, size: 20.0),
                    onPressed: onBack,
                  ),
                  const SizedBox(width: AppSpacing.space8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: typography.titleLarge.copyWith(
                          color: AppColors.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.space4),
                        Text(
                          subtitle!,
                          style: typography.bodyMedium.copyWith(
                            color: AppColors.colorTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions != null) ...[
                  Wrap(
                    spacing: AppSpacing.space8,
                    runSpacing: AppSpacing.space8,
                    children: actions!,
                  ),
                ],
              ],
            ),
    );
  }
}
