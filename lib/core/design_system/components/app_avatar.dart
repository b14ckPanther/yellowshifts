import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_typography.dart';

class AppAvatar extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final double size;

  const AppAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.size = 40.0,
  });

  String get _initials {
    if (name == null || name!.trim().isEmpty) return '?';
    final parts = name!.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '?';
  }

  Color _getBackgroundColor() {
    if (name == null || name!.isEmpty) return AppColors.colorSurfaceBrand;
    final colors = [
      AppColors.colorSurfaceBrand,
      AppColors.colorSurfaceBrandAccent,
      const Color(0xFFFFD166),
      const Color(0xFF06D6A0),
      const Color(0xFF118AB2),
      const Color(0xFF073B4C),
      const Color(0xFFEF476F),
    ];
    final hash = name!.codeUnits.fold(0, (prev, elem) => prev + elem);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: AppRadius.borderPill,
        border: Border.all(color: AppColors.colorBorderSubtle, width: 1.0),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: imageUrl == null
          ? Text(
              _initials,
              style: typography.bodyStrong.copyWith(
                fontSize: size * 0.38,
                color: AppColors.colorTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}
