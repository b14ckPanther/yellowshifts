import 'package:flutter/material.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';

class CameraLivenessOverlay extends StatefulWidget {
  final String statusText;
  final bool isScanning;
  final VoidCallback? onCancel;

  const CameraLivenessOverlay({
    super.key,
    required this.statusText,
    this.isScanning = true,
    this.onCancel,
  });

  @override
  State<CameraLivenessOverlay> createState() => _CameraLivenessOverlayState();
}

class _CameraLivenessOverlayState extends State<CameraLivenessOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Column(
          children: [
            // Top Privacy Shield Badge
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.privacy_tip_outlined,
                            size: 14, color: AppColors.colorBrandYellow),
                        SizedBox(width: 6),
                        Text(
                          'Zero Face Images Stored',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onCancel != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: widget.onCancel,
                    ),
                ],
              ),
            ),
            const Spacer(),

            // Biometric HUD Oval Scanner
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isScanning ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 240,
                    height: 320,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(120),
                      border: Border.all(
                        color: widget.isScanning
                            ? AppColors.colorBrandYellow
                            : Colors.white24,
                        width: 3,
                      ),
                      boxShadow: widget.isScanning
                          ? [
                              BoxShadow(
                                color: AppColors.colorBrandYellow
                                    .withValues(alpha: 0.3),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.face_retouching_natural_outlined,
                        size: 72,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                );
              },
            ),

            const Spacer(),

            // Guidance & Instructions
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space32, vertical: AppSpacing.space24),
              child: Column(
                children: [
                  if (widget.isScanning)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.colorBrandYellow,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.space16),
                  Text(
                    widget.statusText,
                    textAlign: TextAlign.center,
                    style: typography.titleMedium.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    'Position your face within the frame in good lighting',
                    textAlign: TextAlign.center,
                    style: typography.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
