import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// Reusable modal dialog container following the YellowShifts design system.
class AppDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? content;
  final List<Widget>? actions;
  final double width;

  const AppDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.content,
    this.actions,
    this.width = 540.0,
  });

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Dialog(
      backgroundColor: AppColors.colorSurfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
        child: Padding(
          padding: AppSpacing.insetAll24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Text(
                title,
                style: typography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.colorTextPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.space6),
                Text(
                  subtitle!,
                  style: typography.caption.copyWith(
                    color: AppColors.colorTextSecondary,
                  ),
                ),
              ],
              if (content != null) ...[
                const SizedBox(height: AppSpacing.space20),
                Flexible(
                  child: SingleChildScrollView(
                    child: content!,
                  ),
                ),
              ],
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
