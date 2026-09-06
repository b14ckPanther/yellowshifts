import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import '../motion/app_motion.dart';

class AppTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool autofocus;
  final bool readOnly;
  final dynamic prefixIcon; // Accepts Widget or IconData
  final dynamic suffixIcon; // Accepts Widget or IconData
  final FocusNode? focusNode;
  final int maxLines;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.obscureText = false,
    this.autofocus = false,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.maxLines = 1,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  bool _isHovered = false;
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _obscured = widget.obscureText;
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {});
  }

  Widget? _resolveIcon(dynamic icon, {Color? defaultColor}) {
    if (icon == null) return null;
    if (icon is Widget) return icon;
    if (icon is IconData) {
      return Icon(icon,
          size: 18.0, color: defaultColor ?? AppColors.colorTextMuted);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final hasFocus = _focusNode.hasFocus;
    final hasError = widget.errorText != null;

    Color borderColor = AppColors.colorBorderSubtle;
    if (hasError) {
      borderColor = AppColors.colorStatusDanger;
    } else if (hasFocus) {
      borderColor = AppColors.colorActionPrimary;
    } else if (_isHovered) {
      borderColor = AppColors.colorBorderMedium;
    }

    final resolvedPrefix = _resolveIcon(widget.prefixIcon);
    final resolvedSuffix = _resolveIcon(widget.suffixIcon);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: typography.caption.copyWith(
              color: hasError
                  ? AppColors.colorStatusDanger
                  : AppColors.colorTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.space6),
        ],
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: AppMotion.durationFast,
            curve: AppMotion.curveStandard,
            decoration: BoxDecoration(
              color: widget.readOnly
                  ? AppColors.colorSurfaceMuted
                  : AppColors.colorSurfaceRaised,
              borderRadius: AppRadius.borderMd,
              border: Border.all(
                color: borderColor,
                width: hasFocus || hasError ? 1.5 : 1.0,
              ),
              boxShadow: hasFocus
                  ? [
                      BoxShadow(
                        color: hasError
                            ? AppColors.colorStatusDanger
                                .withValues(alpha: 0.15)
                            : AppColors.colorActionPrimary
                                .withValues(alpha: 0.12),
                        blurRadius: 4.0,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                if (resolvedPrefix != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.space12,
                      right: AppSpacing.space8,
                    ),
                    child: resolvedPrefix,
                  ),
                ],
                Expanded(
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    onChanged: widget.onChanged,
                    onFieldSubmitted: widget.onSubmitted,
                    validator: widget.validator,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    obscureText: _obscured,
                    autofocus: widget.autofocus,
                    readOnly: widget.readOnly,
                    maxLines: widget.obscureText ? 1 : widget.maxLines,
                    style: typography.bodyLarge
                        .copyWith(color: AppColors.colorTextPrimary),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: typography.bodyMedium
                          .copyWith(color: AppColors.colorTextMuted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space16,
                        vertical: AppSpacing.space14,
                      ),
                    ),
                  ),
                ),
                if (widget.obscureText) ...[
                  IconButton(
                    icon: Icon(
                      _obscured ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 18.0,
                      color: AppColors.colorTextMuted,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                ] else if (resolvedSuffix != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.space12),
                    child: resolvedSuffix,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: AppSpacing.space4),
          Text(
            widget.errorText!,
            style:
                typography.caption.copyWith(color: AppColors.colorStatusDanger),
          ),
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: AppSpacing.space4),
          Text(
            widget.helperText!,
            style: typography.caption.copyWith(color: AppColors.colorTextMuted),
          ),
        ],
      ],
    );
  }
}
