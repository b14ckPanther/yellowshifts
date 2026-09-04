import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';

import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_status_badge.dart';
import '../../../core/design_system/components/app_page_header.dart';
import '../../../core/design_system/responsive/app_breakpoints.dart';
import '../../../core/permissions/station_access_context.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../../stations/domain/station_membership.dart';
import '../../employees/presentation/widgets/create_employee_dialog.dart';
import '../../reports/presentation/controllers/my_hours_controller.dart';
import '../../reports/presentation/widgets/active_session_card.dart';
import 'station_pulse_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(stationAccessContextProvider);
    final activeMembership = ref.watch(activeMembershipProvider);
    final l10n = AppLocalizations.of(context)!;

    if (!access.isActive || activeMembership == null) {
      return Scaffold(
        backgroundColor: AppColors.colorSurfaceBase,
        body: SafeArea(
          child: AppEmptyState(
            title: l10n.emptyStationsTitle,
            description: l10n.emptyStationsDescription,
            icon: LucideIcons.building,
            actionLabel: l10n.stationSelectTitle,
            onAction: () => context.go('/station-select'),
          ),
        ),
      );
    }

    if (access.isEmployee) {
      return const _EmployeeDashboardView();
    } else if (access.isShiftManager) {
      return const _ManagerDashboardView();
    } else {
      return const _AdminDashboardView();
    }
  }
}

// =============================================================================
// EMPLOYEE DASHBOARD VIEW
// =============================================================================
class _EmployeeDashboardView extends ConsumerWidget {
  const _EmployeeDashboardView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMembership = ref.watch(activeMembershipProvider)!;
    final myHoursState = ref.watch(myHoursControllerProvider);
    final isCompact = AppBreakpoints.isCompact(context);
    final l10n = AppLocalizations.of(context)!;
    const typography = AppTypography();

    final station = activeMembership.station;
    final stationName = station?.name ?? l10n.dashboardStationOverview;
    final activeSession = myHoursState.summary?.activeOpenSession;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.insetHorizontal16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: l10n.dashboardTitle,
                subtitle: '$stationName (${station?.code ?? "N/A"})',
                actions: [
                  _buildRealtimePill(l10n),
                ],
              ),

              // Station Overview Banner
              _buildStationBanner(
                context: context,
                stationName: stationName,
                stationCode: station?.code ?? 'N/A',
                timezone: station?.timezone ?? 'Asia/Jerusalem',
                locale: station?.locale ?? 'he',
                weekStart: station?.weekStart ?? 0,
                role: activeMembership.role,
                isCompact: isCompact,
                l10n: l10n,
              ),
              const SizedBox(height: AppSpacing.space16),

              // Active Session Card (If Clocked In)
              if (activeSession != null) ...[
                ActiveSessionCard(
                  session: activeSession,
                  onTap: () => context.go('/attendance'),
                ),
                const SizedBox(height: AppSpacing.space16),
              ] else ...[
                // Attendance Quick Clock-In Banner
                AppSurface(
                  tone: AppSurfaceTone.raised,
                  child: Row(
                    children: [
                      Container(
                        padding: AppSpacing.insetAll12,
                        decoration: const BoxDecoration(
                          color: AppColors.colorSurfaceBrandAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.clock,
                            size: 24.0, color: AppColors.colorTextPrimary),
                      ),
                      const SizedBox(width: AppSpacing.space16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.dashboardEmployeeAttendanceStatus,
                              style: typography.caption.copyWith(
                                color: AppColors.colorTextSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space4),
                            Text(
                              l10n.dashboardEmployeeNotCheckedIn,
                              style: typography.bodyStrong,
                            ),
                          ],
                        ),
                      ),
                      AppButton(
                        label: l10n.dashboardEmployeeClockInAction,
                        icon: LucideIcons.qrCode,
                        size: isCompact
                            ? AppButtonSize.small
                            : AppButtonSize.medium,
                        onPressed: () => context.go('/attendance'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.space16),
              ],

              // Personal Hours Overview Card
              AppSurface(
                tone: AppSurfaceTone.raised,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.dashboardEmployeeMyHoursTitle,
                          style: typography.caption.copyWith(
                            color: AppColors.colorTextMuted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/hours'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n.navMyHours,
                                  style: typography.caption.copyWith(
                                      color: AppColors.colorTextBrand,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: AppSpacing.space4),
                              const Icon(LucideIcons.chevronRight,
                                  size: 14.0, color: AppColors.colorTextBrand),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: l10n.kpiTotalWorked,
                            count:
                                '${((myHoursState.summary?.totalWorkedMinutes ?? 0) / 60).toStringAsFixed(1)}h',
                            icon: LucideIcons.timer,
                            color: AppColors.colorTextBrand,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space12),
                        Expanded(
                          child: _buildMetricCard(
                            title: l10n.kpiCompletedShifts,
                            count:
                                '${myHoursState.summary?.completedShifts ?? 0}',
                            icon: LucideIcons.checkCircle2,
                            color: AppColors.colorStatusSuccess,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.space16),

              // Personal Quick Shortcuts Grid
              Text(
                l10n.navSectionWorkspace.toUpperCase(),
                style: typography.caption.copyWith(
                  color: AppColors.colorTextMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Wrap(
                spacing: AppSpacing.space12,
                runSpacing: AppSpacing.space12,
                children: [
                  _buildShortcutCard(
                    context: context,
                    icon: LucideIcons.calendar,
                    title: l10n.navSchedule,
                    subtitle: l10n.dashboardEmployeeNextShift,
                    route: '/schedule',
                  ),
                  _buildShortcutCard(
                    context: context,
                    icon: LucideIcons.calendarCheck,
                    title: l10n.navAvailability,
                    subtitle: l10n.dashboardEmployeeAvailabilityTitle,
                    route: '/availability',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space24),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SHIFT MANAGER DASHBOARD VIEW
// =============================================================================
class _ManagerDashboardView extends ConsumerWidget {
  const _ManagerDashboardView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMembership = ref.watch(activeMembershipProvider)!;
    final pulseAsync = ref.watch(stationPulseProvider);
    final isCompact = AppBreakpoints.isCompact(context);
    final l10n = AppLocalizations.of(context)!;
    const typography = AppTypography();

    final station = activeMembership.station;
    final stationName = station?.name ?? l10n.dashboardStationOverview;
    final pulseData = pulseAsync.value ?? {};
    final totalActive = pulseData['total_active_members'] as int? ?? 0;
    final employeeCount = pulseData['employee_count'] as int? ?? 0;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.insetHorizontal16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: l10n.dashboardTitle,
                subtitle: '$stationName (${station?.code ?? "N/A"})',
                actions: [
                  _buildRealtimePill(l10n),
                ],
              ),

              // Station Overview Banner
              _buildStationBanner(
                context: context,
                stationName: stationName,
                stationCode: station?.code ?? 'N/A',
                timezone: station?.timezone ?? 'Asia/Jerusalem',
                locale: station?.locale ?? 'he',
                weekStart: station?.weekStart ?? 0,
                role: activeMembership.role,
                isCompact: isCompact,
                l10n: l10n,
              ),
              const SizedBox(height: AppSpacing.space16),

              // Operational Workforce Pulse
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: l10n.dashboardActiveMembers,
                      count: '$totalActive',
                      icon: LucideIcons.users,
                      color: AppColors.colorTextBrand,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space12),
                  Expanded(
                    child: _buildMetricCard(
                      title: l10n.dashboardEmployeesCount,
                      count: '$employeeCount',
                      icon: LucideIcons.userCheck,
                      color: AppColors.colorStatusSuccess,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),

              // Manager Action Cards
              Text(
                l10n.dashboardQuickStats.toUpperCase(),
                style: typography.caption.copyWith(
                  color: AppColors.colorTextMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Wrap(
                spacing: AppSpacing.space12,
                runSpacing: AppSpacing.space12,
                children: [
                  _buildShortcutCard(
                    context: context,
                    icon: LucideIcons.clock,
                    title: l10n.navAttendance,
                    subtitle: l10n.attendanceLiveMonitor,
                    route: '/attendance',
                  ),
                  _buildShortcutCard(
                    context: context,
                    icon: LucideIcons.calendar,
                    title: l10n.navSchedule,
                    subtitle: l10n.tabDailyBoard,
                    route: '/schedule',
                  ),
                  _buildShortcutCard(
                    context: context,
                    icon: LucideIcons.barChart3,
                    title: l10n.navReports,
                    subtitle: l10n.reportsTitle,
                    route: '/reports',
                  ),
                  _buildShortcutCard(
                    context: context,
                    icon: LucideIcons.calendarCheck,
                    title: l10n.navAvailability,
                    subtitle: l10n.dashboardManagerAvailabilityOverview,
                    route: '/availability/matrix',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space24),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ADMIN DASHBOARD VIEW
// =============================================================================
class _AdminDashboardView extends ConsumerWidget {
  const _AdminDashboardView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMembership = ref.watch(activeMembershipProvider)!;
    final pulseAsync = ref.watch(stationPulseProvider);
    final isCompact = AppBreakpoints.isCompact(context);
    final l10n = AppLocalizations.of(context)!;
    const typography = AppTypography();

    final station = activeMembership.station;
    final stationName = station?.name ?? l10n.dashboardStationOverview;
    final pulseData = pulseAsync.value ?? {};
    final totalActive = pulseData['total_active_members'] as int? ?? 1;
    final adminCount = pulseData['admin_count'] as int? ?? 1;
    final managerCount = pulseData['shift_manager_count'] as int? ?? 0;
    final employeeCount = pulseData['employee_count'] as int? ?? 0;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.insetHorizontal16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: l10n.dashboardTitle,
                subtitle: '$stationName (${station?.code ?? "N/A"})',
                actions: [
                  AppButton(
                    label: l10n.dashboardAdminAddEmployeeAction,
                    icon: LucideIcons.userPlus,
                    size:
                        isCompact ? AppButtonSize.small : AppButtonSize.medium,
                    onPressed: () => CreateEmployeeDialog.show(context),
                  ),
                  _buildRealtimePill(l10n),
                ],
              ),

              // Station Overview Banner
              _buildStationBanner(
                context: context,
                stationName: stationName,
                stationCode: station?.code ?? 'N/A',
                timezone: station?.timezone ?? 'Asia/Jerusalem',
                locale: station?.locale ?? 'he',
                weekStart: station?.weekStart ?? 0,
                role: activeMembership.role,
                isCompact: isCompact,
                l10n: l10n,
              ),
              const SizedBox(height: AppSpacing.space16),

              // Workforce Pulse Metrics
              if (isCompact) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: l10n.dashboardActiveMembers,
                        count: '$totalActive',
                        icon: LucideIcons.users,
                        color: AppColors.colorTextBrand,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: _buildMetricCard(
                        title: l10n.dashboardAdminsCount,
                        count: '$adminCount',
                        icon: LucideIcons.shieldCheck,
                        color: AppColors.colorTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: l10n.dashboardManagersCount,
                        count: '$managerCount',
                        icon: LucideIcons.userCheck,
                        color: AppColors.colorStatusInfo,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: _buildMetricCard(
                        title: l10n.dashboardEmployeesCount,
                        count: '$employeeCount',
                        icon: LucideIcons.user,
                        color: AppColors.colorStatusSuccess,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: l10n.dashboardActiveMembers,
                        count: '$totalActive',
                        icon: LucideIcons.users,
                        color: AppColors.colorTextBrand,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space16),
                    Expanded(
                      child: _buildMetricCard(
                        title: l10n.dashboardAdminsCount,
                        count: '$adminCount',
                        icon: LucideIcons.shieldCheck,
                        color: AppColors.colorTextPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space16),
                    Expanded(
                      child: _buildMetricCard(
                        title: l10n.dashboardManagersCount,
                        count: '$managerCount',
                        icon: LucideIcons.userCheck,
                        color: AppColors.colorStatusInfo,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space16),
                    Expanded(
                      child: _buildMetricCard(
                        title: l10n.dashboardEmployeesCount,
                        count: '$employeeCount',
                        icon: LucideIcons.user,
                        color: AppColors.colorStatusSuccess,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.space24),

              // Administrative Shortcuts
              Text(
                l10n.dashboardAdminQuickShortcuts.toUpperCase(),
                style: typography.caption.copyWith(
                  color: AppColors.colorTextMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Wrap(
                spacing: AppSpacing.space12,
                runSpacing: AppSpacing.space12,
                children: [
                  _buildShortcutCard(
                    context: context,
                    icon: LucideIcons.users,
                    title: l10n.navEmployees,
                    subtitle: l10n.employeesSubtitle,
                    route: '/employees',
                  ),
                  _buildShortcutCard(
                    context: context,
                    icon: LucideIcons.barChart3,
                    title: l10n.navReports,
                    subtitle: l10n.reportsSubtitle,
                    route: '/reports',
                  ),
                  _buildShortcutCard(
                    context: context,
                    icon: LucideIcons.calendarClock,
                    title: l10n.navShiftTemplates,
                    subtitle: l10n.navShiftTemplates,
                    route: '/settings/shifts',
                  ),
                  _buildShortcutCard(
                    context: context,
                    icon: LucideIcons.radio,
                    title: l10n.settingsNfcTags,
                    subtitle: l10n.settingsNfcTagsSubtitle,
                    route: '/settings/nfc-tags',
                  ),
                  _buildShortcutCard(
                    context: context,
                    icon: LucideIcons.sliders,
                    title: l10n.navStationSettings,
                    subtitle: l10n.navStationSettings,
                    route: '/settings/station',
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.space24),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SHARED DASHBOARD WIDGETS
// =============================================================================

Widget _buildRealtimePill(AppLocalizations l10n) {
  const typography = AppTypography();
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.space8,
      vertical: AppSpacing.space4,
    ),
    decoration: BoxDecoration(
      color: AppColors.colorSurfaceRaised,
      borderRadius: AppRadius.borderPill,
      border: Border.all(color: AppColors.colorBorderSubtle),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8.0,
          height: 8.0,
          decoration: const BoxDecoration(
            color: AppColors.colorStatusSuccess,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.space6),
        Flexible(
          child: Text(
            l10n.dashboardRealtimeSync,
            style: typography.caption.copyWith(
              color: AppColors.colorTextSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11.0,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Widget _buildStationBanner({
  required BuildContext context,
  required String stationName,
  required String stationCode,
  required String timezone,
  required String locale,
  required int weekStart,
  required StationRole role,
  required bool isCompact,
  required AppLocalizations l10n,
}) {
  const typography = AppTypography();
  final weekStartName = weekStart == 0 ? 'Sunday' : 'Monday';

  return AppSurface(
    tone: AppSurfaceTone.brand,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                l10n.dashboardStationOverview.toUpperCase(),
                style: typography.caption.copyWith(
                  color: AppColors.colorTextBrand,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            _buildRoleBadge(role, l10n),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        Text(
          stationName,
          style: typography.titleLarge.copyWith(
            color: AppColors.colorTextPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        Text(
          '${l10n.dashboardStationCode}: $stationCode • ${l10n.dashboardTimezone}: $timezone • Week: $weekStartName',
          style: typography.bodyMedium.copyWith(
            color: AppColors.colorTextPrimary.withAlpha(220),
          ),
        ),
      ],
    ),
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

Widget _buildMetricCard({
  required String title,
  required String count,
  required IconData icon,
  required Color color,
}) {
  const typography = AppTypography();

  return AppSurface(
    tone: AppSurfaceTone.raised,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: typography.caption.copyWith(
                  color: AppColors.colorTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(icon, size: 18.0, color: color),
          ],
        ),
        const SizedBox(height: AppSpacing.space8),
        Text(
          count,
          style: typography.headlineMedium.copyWith(
            color: AppColors.colorTextPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

Widget _buildShortcutCard({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required String route,
}) {
  const typography = AppTypography();

  return InkWell(
    onTap: () => context.go(route),
    borderRadius: AppRadius.borderMd,
    child: Container(
      width: 220.0,
      padding: AppSpacing.insetAll16,
      decoration: BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.colorBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22.0, color: AppColors.colorTextBrand),
          const SizedBox(height: AppSpacing.space12),
          Text(
            title,
            style: typography.bodyStrong,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            subtitle,
            style: typography.caption
                .copyWith(color: AppColors.colorTextSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}
