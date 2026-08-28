import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

class AppSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? activeColor;

  const AppSegment({
    required this.value,
    required this.label,
    this.icon,
    this.activeColor,
  });
}

class AppSegmentedControl<T> extends StatelessWidget {
  final List<AppSegment<T>> segments;
  final T? selectedValue;
  final ValueChanged<T> onValueChanged;
  final bool isFullWidth;

  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedValue,
    required this.onValueChanged,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();

    final content = Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.colorSurfaceSubtle,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.colorBorderSubtle, width: 1.0),
      ),
      child: Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: segments.map((segment) {
          final isSelected = segment.value == selectedValue;
          final activeColor = segment.activeColor ?? AppColors.colorBrandYellow;

          final segmentWidget = InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onValueChanged(segment.value);
            },
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space12,
                vertical: AppSpacing.space8,
              ),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4.0,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (segment.icon != null) ...[
                    Icon(
                      segment.icon,
                      size: 16.0,
                      color: isSelected
                          ? AppColors.colorTextPrimary
                          : AppColors.colorTextMuted,
                    ),
                    const SizedBox(width: AppSpacing.space6),
                  ],
                  Text(
                    segment.label,
                    style: typography.caption.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.colorTextPrimary
                          : AppColors.colorTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );

          return isFullWidth ? Expanded(child: segmentWidget) : segmentWidget;
        }).toList(),
      ),
    );

    return content;
  }
}
