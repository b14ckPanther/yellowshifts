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
import '../../data/platform_admin_repository.dart';
import '../../domain/platform_station_summary.dart';
import '../platform_admin_providers.dart';

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: l10n.platformAddManager,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(label: l10n.platformManagerEmail, controller: email),
            const SizedBox(height: 12),
            AppTextField(
                label: l10n.platformManagerFirstName, controller: first),
            const SizedBox(height: 12),
            AppTextField(label: l10n.platformManagerLastName, controller: last),
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
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(platformAdminRepositoryProvider).assignStationAdmin(
            stationId: widget.stationId,
            email: email.text.trim(),
            firstName: first.text.trim(),
            lastName: last.text.trim(),
          );
      ref.invalidate(platformStationManagersProvider(widget.stationId));
      ref.invalidate(platformStationsProvider);
      if (mounted) {
        AppFeedback.show(context,
            message: l10n.platformManagerAssignedToast,
            type: AppFeedbackType.success);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.show(context,
            message: ErrorLocalizer.localize(e, l10n),
            type: AppFeedbackType.error);
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
        AppFeedback.show(context,
            message: l10n.platformManagerRemovedToast,
            type: AppFeedbackType.success);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.show(context,
            message: ErrorLocalizer.localize(e, l10n),
            type: AppFeedbackType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const typography = AppTypography();
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
              subtitle: l10n.platformStationManagersSubtitle,
              onBack: () => context.go('/platform/stations'),
              actions: [
                if (currentStation != null)
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
                AppButton(
                  label: l10n.platformAddManager,
                  icon: LucideIcons.userPlus,
                  size: AppButtonSize.small,
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
                  return ListView.separated(
                    padding: AppSpacing.insetHorizontal16,
                    itemCount: managers.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.space12),
                    itemBuilder: (context, i) {
                      final m = managers[i];
                      return AppSurface(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.fullName,
                                      style: typography.bodyStrong),
                                  Text(m.email ?? m.phone ?? m.userId,
                                      style: typography.caption),
                                ],
                              ),
                            ),
                            AppStatusBadge(
                              label: m.isActive
                                  ? l10n.statusActive
                                  : l10n.statusInactive,
                              variant: m.isActive
                                  ? AppBadgeVariant.success
                                  : AppBadgeVariant.neutral,
                            ),
                            const SizedBox(width: 8),
                            AppButton(
                              label: l10n.platformRemoveManager,
                              size: AppButtonSize.small,
                              variant: AppButtonVariant.outline,
                              onPressed: () => _removeManager(m.userId),
                            ),
                          ],
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
