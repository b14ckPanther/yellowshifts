import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

class AppBrandMark extends StatelessWidget {
  final double size;
  final bool showTagline;
  final bool isInverse;

  const AppBrandMark({
    super.key,
    this.size = 32.0,
    this.showTagline = false,
    this.isInverse = false,
  });

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.colorSurfaceBrand,
            borderRadius: AppRadius.borderSm,
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 4.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'Y',
            style: TextStyle(
              fontFamily: 'Ubuntu',
              fontSize: size * 0.62,
              fontWeight: FontWeight.w900,
              color: AppColors.colorTextBrand,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space8),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: typography.titleMedium.copyWith(
                    fontSize: size * 0.52,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isInverse
                        ? AppColors.colorTextInverse
                        : AppColors.colorTextPrimary,
                  ),
                  children: const [
                    TextSpan(text: 'YELLOW'),
                    TextSpan(
                      text: 'SHIFTS',
                      style: TextStyle(color: AppColors.colorTextBrand),
                    ),
                  ],
                ),
              ),
              if (showTagline) ...[
                Text(
                  'OPERATIONS',
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.copyWith(
                    fontSize: size * 0.24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isInverse
                        ? AppColors.colorSurfaceBrandAccent
                        : AppColors.colorTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
