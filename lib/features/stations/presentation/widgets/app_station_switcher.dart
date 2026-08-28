import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/components/app_status_badge.dart';
import '../../../../core/design_system/motion/app_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/station_membership.dart';
import '../active_station_provider.dart';

class AppStationSwitcher extends ConsumerStatefulWidget {
  const AppStationSwitcher({super.key});

  @override
  ConsumerState<AppStationSwitcher> createState() => _AppStationSwitcherState();
}

class _AppStationSwitcherState extends ConsumerState<AppStationSwitcher> {
  bool _isHovered = false;

  void _showStationPicker(
      BuildContext context, List<StationMembership> memberships) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final activeId = ref.read(activeStationIdProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.colorSurfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.radiusLg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: AppSpacing.insetAll20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.stationSelectTitle,
                      style: typography.titleMedium.copyWith(
                        color: AppColors.colorTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20.0),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space16),
                ListView.separated(
                  shrinkWrap: true,
                  itemCount: memberships.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.space8),
                  itemBuilder: (context, index) {
                    final membership = memberships[index];
                    final isSelected = membership.stationId == activeId;
                    final stationName =
                        membership.station?.name ?? l10n.stationLabel;
                    final stationCode = membership.station?.code ?? 'N/A';

                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderMd,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.colorTextBrand
                              : AppColors.colorBorderSubtle,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      tileColor: isSelected
                          ? AppColors.colorSurfaceBrandSubtle
                          : AppColors.colorSurfaceRaised,
                      leading: Container(
                        width: 36.0,
                        height: 36.0,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.colorSurfaceBrand
                              : AppColors.colorSurfaceMuted,
                          borderRadius: AppRadius.borderSm,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.building2,
                          size: 18.0,
                          color: isSelected
                              ? AppColors.colorTextBrand
                              : AppColors.colorTextSecondary,
                        ),
                      ),
                      title: Text(
                        stationName,
                        style: typography.bodyStrong.copyWith(
                          color: AppColors.colorTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        stationCode,
                        style: typography.caption.copyWith(
                          color: AppColors.colorTextMuted,
                        ),
                      ),
                      trailing: _buildRoleBadge(membership.role, l10n),
                      onTap: () {
                        ref
                            .read(activeStationIdProvider.notifier)
                            .selectStation(membership.stationId);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleBadge(StationRole role, AppLocalizations l10n) {
    switch (role) {
      case StationRole.admin:
        return AppStatusBadge(
          label: l10n.roleAdmin,
          variant: AppBadgeVariant.brand,
          icon: LucideIcons.shieldCheck,
        );
      case StationRole.shiftManager:
        return AppStatusBadge(
          label: l10n.roleShiftManager,
          variant: AppBadgeVariant.info,
          icon: LucideIcons.userCheck,
        );
      case StationRole.employee:
        return AppStatusBadge(
          label: l10n.roleEmployee,
          variant: AppBadgeVariant.neutral,
          icon: LucideIcons.user,
        );
    }
  }

  String _getRoleName(StationRole role, AppLocalizations l10n) {
    switch (role) {
      case StationRole.admin:
        return l10n.roleAdmin;
      case StationRole.shiftManager:
        return l10n.roleShiftManager;
      case StationRole.employee:
        return l10n.roleEmployee;
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final activeMembership = ref.watch(activeMembershipProvider);
    final allMemberships = ref.watch(userMembershipsStreamProvider).value ?? [];

    if (activeMembership == null) {
      return const SizedBox.shrink();
    }

    final stationName = activeMembership.station?.name ?? l10n.stationLabel;
    final hasMultiple = allMemberships.length > 1;

    return MouseRegion(
      cursor: hasMultiple ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: hasMultiple
            ? () => _showStationPicker(context, allMemberships)
            : null,
        child: AnimatedContainer(
          duration: AppMotion.durationFast,
          curve: AppMotion.curveStandard,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space8,
            vertical: AppSpacing.space4,
          ),
          decoration: BoxDecoration(
            color: _isHovered && hasMultiple
                ? AppColors.colorSurfaceMuted
                : AppColors.colorSurfaceRaised,
            borderRadius: AppRadius.borderMd,
            border: Border.all(
              color: _isHovered && hasMultiple
                  ? AppColors.colorBorderMedium
                  : AppColors.colorBorderSubtle,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24.0,
                height: 24.0,
                decoration: const BoxDecoration(
                  color: AppColors.colorSurfaceBrandSubtle,
                  borderRadius: AppRadius.borderSm,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  LucideIcons.building2,
                  size: 14.0,
                  color: AppColors.colorTextBrand,
                ),
              ),
              const SizedBox(width: AppSpacing.space6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.caption.copyWith(
                        color: AppColors.colorTextPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      _getRoleName(activeMembership.role, l10n).toUpperCase(),
                      style: typography.caption.copyWith(
                        fontSize: 10.0,
                        color: AppColors.colorTextBrand,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasMultiple) ...[
                const SizedBox(width: AppSpacing.space4),
                const Icon(
                  LucideIcons.chevronDown,
                  size: 14.0,
                  color: AppColors.colorTextMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
