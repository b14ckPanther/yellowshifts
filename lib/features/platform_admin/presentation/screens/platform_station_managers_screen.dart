import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_dialog.dart';
import '../../../../core/design_system/components/app_feedback.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_status_badge.dart';
import '../../../../core/design_system/components/app_surface.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../data/platform_admin_repository.dart';
import '../../domain/platform_station_manager.dart';
import '../../domain/platform_station_summary.dart';
import '../platform_admin_providers.dart';
import '../widgets/edit_platform_manager_dialog.dart';
import '../widgets/edit_station_dialog.dart';
import '../widgets/reset_manager_password_dialog.dart';

class PlatformStationManagersScreen extends ConsumerStatefulWidget {
  final String stationId;
  const PlatformStationManagersScreen({super.key, required this.stationId});

  @override
  ConsumerState<PlatformStationManagersScreen> createState() =>
      _PlatformStationManagersScreenState();
}

class _PlatformStationManagersScreenState
    extends ConsumerState<PlatformStationManagersScreen> {
  Future<void> _confirmDeactivate(
      PlatformStationSummary station, bool activate) async {
    final l10n = AppLocalizations.of(context)!;
    final reason = TextEditingController();
    var force = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AppDialog(
              title: activate
                  ? l10n.platformReactivateStation
                  : l10n.platformConfirmDeactivateTitle,
              subtitle: activate ? null : l10n.platformConfirmDeactivateBody,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                      label: l10n.platformReasonLabel, controller: reason),
                  if (!activate) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: force,
                      onChanged: (v) => setLocal(() => force = v ?? false),
                      title: Text(l10n.platformForceDeactivate),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
              actions: [
                AppButton(
                  label: l10n.dialogCancel,
                  variant: AppButtonVariant.ghost,
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                AppButton(
                  label: activate
                      ? l10n.platformReactivateStation
                      : l10n.platformDeactivateStation,
                  variant: activate
                      ? AppButtonVariant.primary
                      : AppButtonVariant.destructive,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(platformAdminRepositoryProvider).setStationActive(
            stationId: widget.stationId,
            isActive: activate,
            reason: reason.text.trim(),
            forceDeactivate: force,
          );
      ref.invalidate(platformStationsProvider);
      ref.invalidate(platformOverviewProvider);
      if (mounted) {
        AppFeedback.show(
          context,
          message: activate
              ? l10n.platformReactivatedToast
              : l10n.platformDeactivatedToast,
          type: AppFeedbackType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.show(context,
            message: ErrorLocalizer.localize(e, l10n),
            type: AppFeedbackType.error);
      }
    }
  }

  Future<void> _addManager() async {
    final l10n = AppLocalizations.of(context)!;
    final email = TextEditingController();
    final first = TextEditingController();
    final last = TextEditingController();
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: l10n.platformAddManager,
        subtitle: l10n.platformStationManagersSubtitle,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: l10n.platformManagerFirstName,
                    controller: first,
                    prefixIcon: LucideIcons.user,
                  ),
                ),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: AppTextField(
                    label: l10n.platformManagerLastName,
                    controller: last,
                    prefixIcon: LucideIcons.user,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space12),
            AppTextField(
              label: l10n.platformManagerEmail,
              controller: email,
              prefixIcon: LucideIcons.mail,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.space12),
            AppTextField(
              label: l10n.platformManagerPhone,
              controller: phone,
              prefixIcon: LucideIcons.phone,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          AppButton(
            label: l10n.dialogCancel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppButton(
            label: l10n.platformAssignManager,
            variant: AppButtonVariant.primary,
            onPressed: () {
              if (first.text.trim().isEmpty || last.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(platformAdminRepositoryProvider).assignStationAdmin(
            stationId: widget.stationId,
            email: email.text.trim().isNotEmpty ? email.text.trim() : null,
            firstName: first.text.trim(),
            lastName: last.text.trim(),
            phone: phone.text.trim().isNotEmpty ? phone.text.trim() : null,
          );
      ref.invalidate(platformStationManagersProvider(widget.stationId));
      ref.invalidate(platformStationsProvider);
      if (mounted) {
        AppFeedback.show(
          context,
          message: l10n.platformManagerAssignedToast,
          type: AppFeedbackType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.show(
          context,
          message: ErrorLocalizer.localize(e, l10n),
          type: AppFeedbackType.error,
        );
      }
    }
  }

  Future<void> _removeManager(String userId) async {
    final l10n = AppLocalizations.of(context)!;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: l10n.platformConfirmRemoveManagerTitle,
        subtitle: l10n.platformConfirmRemoveManagerBody,
        content:
            AppTextField(label: l10n.platformReasonLabel, controller: reason),
        actions: [
          AppButton(
            label: l10n.dialogCancel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppButton(
            label: l10n.platformRemoveManager,
            variant: AppButtonVariant.destructive,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(platformAdminRepositoryProvider).removeStationAdmin(
            stationId: widget.stationId,
            userId: userId,
            reason: reason.text.trim(),
          );
      ref.invalidate(platformStationManagersProvider(widget.stationId));
      ref.invalidate(platformStationsProvider);
      if (mounted) {
        AppFeedback.show(
          context,
          message: l10n.platformManagerRemovedToast,
          type: AppFeedbackType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.show(
          context,
          message: ErrorLocalizer.localize(e, l10n),
          type: AppFeedbackType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stations = ref.watch(platformStationsProvider).value ?? const [];
    PlatformStationSummary? station;
    for (final s in stations) {
      if (s.id == widget.stationId) station = s;
    }
    final managersAsync =
        ref.watch(platformStationManagersProvider(widget.stationId));
    final currentStation = station;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: station?.name ?? l10n.platformStationManagers,
              subtitle: station != null
                  ? '${station.code} · ${l10n.platformStationManagersSubtitle}'
                  : l10n.platformStationManagersSubtitle,
              onBack: () => context.go('/platform/stations'),
              actions: [
                if (currentStation != null) ...[
                  AppButton(
                    label: l10n.platformEditStation,
                    icon: LucideIcons.pencil,
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.small,
                    onPressed: () => EditStationDialog.show(context,
                        station: currentStation),
                  ),
                  AppButton(
                    label: currentStation.isActive
                        ? l10n.platformDeactivateStation
                        : l10n.platformReactivateStation,
                    variant: currentStation.isActive
                        ? AppButtonVariant.destructive
                        : AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: () => _confirmDeactivate(
                        currentStation, !currentStation.isActive),
                  ),
                ],
                AppButton(
                  label: l10n.platformAddManager,
                  icon: LucideIcons.userPlus,
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.primary,
                  onPressed: _addManager,
                ),
              ],
            ),
            Expanded(
              child: managersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(ErrorLocalizer.localize(e, l10n))),
                data: (managers) {
                  if (managers.isEmpty) {
                    return AppEmptyState(
                      title: l10n.platformStationManagers,
                      description: l10n.platformStationManagersSubtitle,
                      icon: LucideIcons.users,
                      actionLabel: l10n.platformAddManager,
                      onAction: _addManager,
                    );
                  }
                  return ListView.separated(
                    padding: AppSpacing.insetHorizontal16,
                    itemCount: managers.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.space12),
                    itemBuilder: (context, i) {
                      final m = managers[i];
                      return _ManagerCard(
                        stationId: widget.stationId,
                        manager: m,
                        onEdit: () => EditPlatformManagerDialog.show(
                          context,
                          stationId: widget.stationId,
                          manager: m,
                        ),
                        onResetPassword: () => ResetManagerPasswordDialog.show(
                          context,
                          stationId: widget.stationId,
                          manager: m,
                        ),
                        onRemove: () => _removeManager(m.userId),
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

class _ManagerCard extends StatelessWidget {
  final String stationId;
  final PlatformStationManager manager;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onRemove;

  const _ManagerCard({
    required this.stationId,
    required this.manager,
    required this.onEdit,
    required this.onResetPassword,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const typography = AppTypography();

    final initials =
        (manager.firstName.isNotEmpty ? manager.firstName[0] : '') +
            (manager.lastName.isNotEmpty ? manager.lastName[0] : '');

    return AppSurface(
      child: Padding(
        padding: AppSpacing.insetAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.colorSurfaceBrandSubtle,
                  child: Text(
                    initials.toUpperCase(),
                    style: typography.bodyStrong.copyWith(
                      color: AppColors.colorTextBrand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              manager.fullName,
                              style: typography.bodyStrong.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space8),
                          AppStatusBadge(
                            label: manager.role == 'ADMIN'
                                ? l10n.platformColManagers
                                : manager.role,
                            variant: AppBadgeVariant.info,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (manager.email != null &&
                              manager.email!.isNotEmpty)
                            _infoChip(
                                LucideIcons.mail, manager.email!, typography),
                          if (manager.phone != null &&
                              manager.phone!.isNotEmpty)
                            _infoChip(
                                LucideIcons.phone, manager.phone!, typography),
                          if (manager.employeeCode != null &&
                              manager.employeeCode!.isNotEmpty)
                            _infoChip(LucideIcons.badgeCheck,
                                manager.employeeCode!, typography),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.space12),
                AppStatusBadge(
                  label: manager.isActive
                      ? l10n.statusActive
                      : l10n.statusInactive,
                  variant: manager.isActive
                      ? AppBadgeVariant.success
                      : AppBadgeVariant.neutral,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space16),
            const Divider(height: 1, color: AppColors.colorBorderSubtle),
            const SizedBox(height: AppSpacing.space12),
            Wrap(
              spacing: AppSpacing.space8,
              runSpacing: AppSpacing.space8,
              alignment: WrapAlignment.end,
              children: [
                AppButton(
                  label: l10n.platformEditManager,
                  icon: LucideIcons.pencil,
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.outline,
                  onPressed: onEdit,
                ),
                AppButton(
                  label: l10n.platformResetManagerPassword,
                  icon: LucideIcons.keyRound,
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.outline,
                  onPressed: onResetPassword,
                ),
                AppButton(
                  label: l10n.platformRemoveManager,
                  icon: LucideIcons.userMinus,
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.ghost,
                  onPressed: onRemove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, AppTypography typography) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.colorTextMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.caption
                .copyWith(color: AppColors.colorTextSecondary),
          ),
        ),
      ],
    );
  }
}
