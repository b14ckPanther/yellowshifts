import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_brand_mark.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/components/app_status_badge.dart';
import '../../../core/design_system/components/app_avatar.dart';
import '../../../core/design_system/components/app_page_header.dart';
import '../../../app/localization/locale_provider.dart';

class DesignSystemPreviewScreen extends ConsumerStatefulWidget {
  const DesignSystemPreviewScreen({super.key});

  @override
  ConsumerState<DesignSystemPreviewScreen> createState() =>
      _DesignSystemPreviewScreenState();
}

class _DesignSystemPreviewScreenState
    extends ConsumerState<DesignSystemPreviewScreen> {
  final _textController =
      TextEditingController(text: 'Sample operational input');

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Design System & Component Catalog',
                subtitle:
                    'Dev-only visual inspection for tokens and primitives',
                actions: [
                  AppButton(
                    label: locale.languageCode == 'he'
                        ? 'English (LTR)'
                        : 'עברית (RTL)',
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.small,
                    icon: LucideIcons.globe,
                    onPressed: () =>
                        ref.read(localeProvider.notifier).toggleLocale(),
                  ),
                ],
              ),
              Padding(
                padding: AppSpacing.insetHorizontal16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Marks
                    _buildSectionHeader('Brand Identity Slot'),
                    const AppCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          AppBrandMark(size: 32.0),
                          AppBrandMark(size: 40.0, showTagline: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space24),

                    // Semantic Colors
                    _buildSectionHeader('Semantic Colors'),
                    Wrap(
                      spacing: AppSpacing.space12,
                      runSpacing: AppSpacing.space12,
                      children: [
                        _buildColorChip(
                            'Brand Surface',
                            AppColors.colorSurfaceBrand,
                            AppColors.colorTextPrimary),
                        _buildColorChip(
                            'Brand Accent',
                            AppColors.colorSurfaceBrandAccent,
                            AppColors.colorTextPrimary),
                        _buildColorChip('Brand Text', AppColors.colorTextBrand,
                            AppColors.colorTextInverse),
                        _buildColorChip(
                            'Base Surface',
                            AppColors.colorSurfaceBase,
                            AppColors.colorTextPrimary),
                        _buildColorChip(
                            'Raised Surface',
                            AppColors.colorSurfaceRaised,
                            AppColors.colorTextPrimary),
                        _buildColorChip('Success', AppColors.colorStatusSuccess,
                            AppColors.colorTextInverse),
                        _buildColorChip('Warning', AppColors.colorStatusWarning,
                            AppColors.colorTextPrimary),
                        _buildColorChip('Danger', AppColors.colorStatusDanger,
                            AppColors.colorTextInverse),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space24),

                    // Buttons
                    _buildSectionHeader('Button Variants'),
                    AppCard(
                      child: Wrap(
                        spacing: AppSpacing.space12,
                        runSpacing: AppSpacing.space12,
                        children: [
                          AppButton(label: 'Primary', onPressed: () {}),
                          AppButton(
                              label: 'Secondary',
                              variant: AppButtonVariant.secondary,
                              onPressed: () {}),
                          AppButton(
                              label: 'Outline',
                              variant: AppButtonVariant.outline,
                              onPressed: () {}),
                          AppButton(
                              label: 'Destructive',
                              variant: AppButtonVariant.destructive,
                              onPressed: () {}),
                          AppButton(
                              label: 'Loading',
                              isLoading: true,
                              onPressed: () {}),
                          AppButton(
                              label: 'With Icon',
                              icon: LucideIcons.check,
                              onPressed: () {}),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space24),

                    // Inputs
                    _buildSectionHeader('Form Controls'),
                    AppCard(
                      child: Column(
                        children: [
                          AppTextField(
                            label: 'Standard Input',
                            hint: 'Enter text here...',
                            controller: _textController,
                            prefixIcon: const Icon(LucideIcons.edit,
                                size: 18.0, color: AppColors.colorTextMuted),
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          const AppTextField(
                            label: 'Password Input',
                            hint: 'Enter secret...',
                            obscureText: true,
                            prefixIcon: Icon(LucideIcons.lock,
                                size: 18.0, color: AppColors.colorTextMuted),
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          const AppTextField(
                            label: 'Error State',
                            errorText: 'This field has a validation error',
                            prefixIcon: Icon(LucideIcons.alertCircle,
                                size: 18.0, color: AppColors.colorStatusDanger),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space24),

                    // Badges & Avatars
                    _buildSectionHeader('Status Badges & Avatars'),
                    const AppCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          AppStatusBadge(
                              label: 'Active',
                              variant: AppBadgeVariant.success,
                              icon: LucideIcons.check),
                          AppStatusBadge(
                              label: 'Warning',
                              variant: AppBadgeVariant.warning,
                              icon: LucideIcons.alertTriangle),
                          AppStatusBadge(
                              label: 'Danger',
                              variant: AppBadgeVariant.danger,
                              icon: LucideIcons.alertCircle),
                          AppStatusBadge(
                              label: 'Admin',
                              variant: AppBadgeVariant.brand,
                              icon: LucideIcons.shieldCheck),
                          AppAvatar(name: 'David Cohen', size: 40.0),
                          AppAvatar(name: 'Sarah Levi', size: 40.0),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    const typography = AppTypography();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space12),
      child: Text(
        title,
        style: typography.titleMedium.copyWith(
          color: AppColors.colorTextPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildColorChip(String label, Color color, Color textColor) {
    return Container(
      width: 140.0,
      height: 70.0,
      padding: AppSpacing.insetAll8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.colorBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: textColor,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600)),
          Text(
            '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
            style: TextStyle(
                color: textColor, fontSize: 10.0, fontFamily: 'Courier'),
          ),
        ],
      ),
    );
  }
}
