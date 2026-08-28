import 'package:flutter/material.dart';
import '../../core/design_system/tokens/app_colors.dart';
import '../../core/design_system/tokens/app_radius.dart';
import '../../core/design_system/tokens/app_spacing.dart';

class AppSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const AppSkeleton({
    super.key,
    this.width,
    this.height = 20.0,
    this.borderRadius,
  });

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final disableAnimations = mediaQuery?.disableAnimations ?? false;

    if (disableAnimations) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.colorBorderSubtle,
          borderRadius: widget.borderRadius ?? AppRadius.borderSm,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.colorSurfaceMuted,
              AppColors.colorBorderSubtle,
              _animation.value,
            ),
            borderRadius: widget.borderRadius ?? AppRadius.borderSm,
          ),
        );
      },
    );
  }
}

class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.insetAll16,
      decoration: BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.colorBorderSubtle),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSkeleton(
                  width: 40.0,
                  height: 40.0,
                  borderRadius: AppRadius.borderPill),
              SizedBox(width: AppSpacing.space12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(width: 140.0, height: 16.0),
                  SizedBox(height: AppSpacing.space6),
                  AppSkeleton(width: 90.0, height: 12.0),
                ],
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space16),
          AppSkeleton(width: double.infinity, height: 14.0),
          SizedBox(height: AppSpacing.space8),
          AppSkeleton(width: 200.0, height: 14.0),
        ],
      ),
    );
  }
}
