import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

class AppFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;
  final int? count;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onSelected,
    this.avatar,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();

    return InkWell(
      onTap: onSelected != null ? () => onSelected!(!isSelected) : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.colorBrandYellow
              : AppColors.colorSurfaceRaised,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isSelected
                ? AppColors.colorBrandYellow
                : AppColors.colorBorderSubtle,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[
              avatar!,
              const SizedBox(width: AppSpacing.space6),
            ],
            Text(
              label,
              style: typography.caption.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.colorTextPrimary
                    : AppColors.colorTextSecondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: AppSpacing.space6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.black.withValues(alpha: 0.1)
                      : AppColors.colorSurfaceSubtle,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  count.toString(),
                  style: typography.caption.copyWith(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.colorTextPrimary
                        : AppColors.colorTextMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
