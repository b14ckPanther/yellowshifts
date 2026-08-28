import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../motion/app_motion.dart';

enum AppSurfaceTone { base, raised, muted, brand, brandAccent }

class AppSurface extends StatelessWidget {
  final Widget child;
  final AppSurfaceTone tone;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Border? border;
  final double? width;
  final double? height;

  const AppSurface({
    super.key,
    required this.child,
    this.tone = AppSurfaceTone.raised,
    this.padding = AppSpacing.insetAll16,
    this.borderRadius,
    this.border,
    this.width,
    this.height,
  });

  Color _getBackgroundColor() {
    switch (tone) {
      case AppSurfaceTone.base:
        return AppColors.colorSurfaceBase;
      case AppSurfaceTone.raised:
        return AppColors.colorSurfaceRaised;
      case AppSurfaceTone.muted:
        return AppColors.colorSurfaceMuted;
      case AppSurfaceTone.brand:
        return AppColors.colorSurfaceBrand;
      case AppSurfaceTone.brandAccent:
        return AppColors.colorSurfaceBrandAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: borderRadius ?? AppRadius.borderMd,
        border: border ??
            (tone == AppSurfaceTone.raised
                ? Border.all(color: AppColors.colorBorderSubtle, width: 1.0)
                : null),
      ),
      child: child,
    );
  }
}

class AppCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final BorderSide? borderSide;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.insetAll16,
    this.backgroundColor,
    this.borderSide,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasTap = widget.onTap != null;

    return MouseRegion(
      cursor: hasTap ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.durationFast,
          curve: AppMotion.curveStandard,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppColors.colorSurfaceRaised,
            borderRadius: AppRadius.borderMd,
            border: Border.fromBorderSide(
              widget.borderSide ??
                  BorderSide(
                    color: _isHovered && hasTap
                        ? AppColors.colorBorderStrong
                        : AppColors.colorBorderSubtle,
                    width: 1.0,
                  ),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
