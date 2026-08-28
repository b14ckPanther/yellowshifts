import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/components/app_page_header.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_status_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../domain/shift_template.dart';
import 'shift_templates_provider.dart';
import 'widgets/shift_template_dialog.dart';

class ShiftTemplatesScreen extends ConsumerWidget {
  const ShiftTemplatesScreen({super.key});

  void _openCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ShiftTemplateDialog(),
    );
  }

  void _openEditDialog(BuildContext context, ShiftTemplate template) {
    showDialog(
      context: context,
      builder: (context) => ShiftTemplateDialog(template: template),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final templatesAsync = ref.watch(shiftTemplatesProvider);
    final notifier = ref.read(shiftTemplatesProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: l10n.shiftsTitle,
              subtitle: l10n.shiftsSubtitle,
              actions: [
                AppButton(
                  label: l10n.shiftsAddButton,
                  icon: LucideIcons.plus,
                  onPressed: () => _openCreateDialog(context),
                ),
              ],
            ),
            Expanded(
              child: templatesAsync.when(
                loading: () => Padding(
                  padding: AppSpacing.insetHorizontal16,
                  child: Column(
                    children: List.generate(
                      4,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.space12),
                        child: AppSkeleton(height: 72.0),
                      ),
                    ),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: AppSpacing.inset24,
                  child: Center(
                    child: Text(
                      'Failed to load shift templates: $err',
                      style: typography.bodyMedium
                          .copyWith(color: AppColors.colorError),
                    ),
                  ),
                ),
                data: (templates) {
                  if (templates.isEmpty) {
                    return AppEmptyState(
                      title: l10n.shiftsEmptyTitle,
                      description: l10n.shiftsEmptyDesc,
                      actionLabel: l10n.shiftsAddButton,
                      icon: LucideIcons.plus,
                      onAction: () => _openCreateDialog(context),
                    );
                  }

                  return ReorderableListView.builder(
                    padding: AppSpacing.insetHorizontal16,
                    itemCount: templates.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final items = List<ShiftTemplate>.from(templates);
                      final moved = items.removeAt(oldIndex);
                      items.insert(newIndex, moved);
                      notifier
                          .reorderTemplates(items.map((e) => e.id).toList());
                    },
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return Padding(
                        key: ValueKey(template.id),
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.space12),
                        child: AppCard(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 360.0;

                              final content = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: AppSpacing.space8,
                                    runSpacing: AppSpacing.space4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        template.name,
                                        style: typography.bodyStrong
                                            .copyWith(fontSize: 16.0),
                                      ),
                                      if (template.code != null &&
                                          template.code!.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6.0, vertical: 2.0),
                                          decoration: BoxDecoration(
                                            color: AppColors.colorSurfaceSubtle,
                                            borderRadius: BorderRadius.circular(
                                                AppSpacing.radiusSmall),
                                          ),
                                          child: Text(
                                            template.code!,
                                            style: typography.caption.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11.0,
                                              color:
                                                  AppColors.colorTextSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      AppStatusBadge(
                                        label: template.isActive
                                            ? 'Active'
                                            : 'Inactive',
                                        variant: template.isActive
                                            ? AppBadgeVariant.success
                                            : AppBadgeVariant.neutral,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.space6),
                                  Wrap(
                                    spacing: AppSpacing.space8,
                                    runSpacing: AppSpacing.space4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        template.formatTimeRange(),
                                        style: typography.bodyMedium
                                            .copyWith(fontFamily: 'monospace'),
                                      ),
                                      Text(
                                        '• ${template.durationHours.toStringAsFixed(1)} hrs',
                                        style: typography.caption.copyWith(
                                            color:
                                                AppColors.colorTextSecondary),
                                      ),
                                      if (template.isCrossMidnight)
                                        Text(
                                          '• ${l10n.shiftsCrossMidnight}',
                                          style: typography.caption.copyWith(
                                            color: AppColors.colorBrandCrimson,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              );

                              final actions = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(LucideIcons.pencil,
                                        size: 18.0),
                                    tooltip: l10n.shiftsEdit,
                                    onPressed: () =>
                                        _openEditDialog(context, template),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      template.isActive
                                          ? LucideIcons.ban
                                          : LucideIcons.checkCircle,
                                      size: 18.0,
                                      color: template.isActive
                                          ? AppColors.colorError
                                          : AppColors.colorSuccess,
                                    ),
                                    tooltip: template.isActive
                                        ? l10n.shiftsDeactivate
                                        : l10n.shiftsReactivate,
                                    onPressed: () =>
                                        notifier.toggleTemplateActive(template),
                                  ),
                                ],
                              );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.gripVertical,
                                          size: 20.0,
                                          color: AppColors.colorTextMuted,
                                        ),
                                        const SizedBox(
                                            width: AppSpacing.space8),
                                        Expanded(child: content),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.space8),
                                    Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: actions,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  const Icon(
                                    LucideIcons.gripVertical,
                                    size: 20.0,
                                    color: AppColors.colorTextMuted,
                                  ),
                                  const SizedBox(width: AppSpacing.space12),
                                  Expanded(child: content),
                                  const SizedBox(width: AppSpacing.space8),
                                  actions,
                                ],
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
