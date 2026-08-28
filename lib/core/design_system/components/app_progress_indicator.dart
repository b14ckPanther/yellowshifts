import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';

class AppLinearProgress extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final Color? color;
  final Color? backgroundColor;
  final double height;

  const AppLinearProgress({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(
            height: height,
            width: double.infinity,
            color: backgroundColor ?? AppColors.colorSurfaceSubtle,
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: height,
                width: constraints.maxWidth * clamped,
                decoration: BoxDecoration(
                  color: color ??
                      (clamped == 1.0
                          ? AppColors.colorSuccess
                          : AppColors.colorBrandYellow),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
