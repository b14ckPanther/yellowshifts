import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import '../motion/app_motion.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, destructive }

enum AppButtonSize { small, medium, large }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  double _getHeight() {
    switch (widget.size) {
      case AppButtonSize.small:
        return 34.0;
      case AppButtonSize.medium:
        return 42.0;
      case AppButtonSize.large:
        return 50.0;
    }
  }

  EdgeInsetsGeometry _getPadding() {
    switch (widget.size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.space12);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.space16);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.space24);
    }
  }

  Color _getBackgroundColor() {
    if (widget.onPressed == null || widget.isLoading) {
      return AppColors.colorSurfaceMuted;
    }
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return _isPressed
            ? AppColors.colorSurfaceBrandAccent
            : (_isHovered
                ? AppColors.colorSurfaceBrandAccent
                : AppColors.colorSurfaceBrand);
      case AppButtonVariant.secondary:
        return _isPressed
            ? AppColors.colorSurfaceMuted
            : (_isHovered
                ? AppColors.colorSurfaceMuted
                : AppColors.colorSurfaceRaised);
      case AppButtonVariant.outline:
      case AppButtonVariant.ghost:
        return _isHovered ? AppColors.colorSurfaceMuted : Colors.transparent;
      case AppButtonVariant.destructive:
        return _isPressed
            ? AppColors.colorStatusDanger
            : (_isHovered
                ? AppColors.colorStatusDanger
                : AppColors.colorStatusDangerSubtle);
    }
  }

  Color _getTextColor() {
    if (widget.onPressed == null || widget.isLoading) {
      return AppColors.colorTextMuted;
    }
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return AppColors.colorTextPrimary;
      case AppButtonVariant.secondary:
      case AppButtonVariant.outline:
      case AppButtonVariant.ghost:
        return AppColors.colorTextPrimary;
      case AppButtonVariant.destructive:
        return _isHovered || _isPressed
            ? AppColors.colorTextInverse
            : AppColors.colorStatusDanger;
    }
  }

  Border? _getBorder() {
    if (widget.variant == AppButtonVariant.outline) {
      return Border.all(
        color: _isHovered
            ? AppColors.colorBorderStrong
            : AppColors.colorBorderMedium,
        width: 1.0,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onPressed != null && !widget.isLoading;
    const typography = AppTypography();
    final textColor = _getTextColor();

    Widget content = widget.isLoading
        ? SizedBox(
            width: 18.0,
            height: 18.0,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        : Row(
            mainAxisSize:
                widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16.0, color: textColor),
                const SizedBox(width: AppSpacing.space8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: typography.labelLarge.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );

    return MouseRegion(
      cursor:
          isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => isInteractive ? setState(() => _isHovered = true) : null,
      onExit: (_) => isInteractive ? setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTapDown: (_) =>
            isInteractive ? setState(() => _isPressed = true) : null,
        onTapUp: (_) =>
            isInteractive ? setState(() => _isPressed = false) : null,
        onTapCancel: () =>
            isInteractive ? setState(() => _isPressed = false) : null,
        onTap: isInteractive ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: AppMotion.durationInstant,
          child: AnimatedContainer(
            duration: AppMotion.durationFast,
            curve: AppMotion.curveStandard,
            height: _getHeight(),
            padding: _getPadding(),
            decoration: BoxDecoration(
              color: _getBackgroundColor(),
              borderRadius: AppRadius.borderMd,
              border: _getBorder(),
            ),
            child: Align(
              alignment: Alignment.center,
              widthFactor: widget.isFullWidth ? null : 1.0,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
