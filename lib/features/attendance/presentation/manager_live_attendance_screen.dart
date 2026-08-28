import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import 'providers/attendance_providers.dart';
import 'widgets/manual_correction_dialog.dart';
import '../domain/models/live_attendance_roster.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../stations/presentation/active_station_provider.dart';

class ManagerLiveAttendanceScreen extends ConsumerWidget {
  const ManagerLiveAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final stationId = ref.watch(activeStationIdProvider);

    if (stationId == null) {
      return Scaffold(
        body: Center(child: Text(l10n.stationSelectTitle)),
      );
    }

    final liveAsync = ref.watch(managerLiveAttendanceProvider(stationId));
    ref.watch(attendanceRealtimeSubscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      appBar: AppBar(
        title: Text(l10n.attendanceLiveMonitor),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () =>
                ref.invalidate(managerLiveAttendanceProvider(stationId)),
          ),
        ],
      ),
      body: liveAsync.when(
        data: (data) {
          final kpis = data.kpis;
          final roster = data.roster;
          final timeFormat = DateFormat('HH:mm');

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(managerLiveAttendanceProvider(stationId)),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.space16),
              children: [
                // KPI Header Row
                Wrap(
                  spacing: AppSpacing.space12,
                  runSpacing: AppSpacing.space12,
                  children: [
                    _buildKpiCard(
                      label: l10n.kpiWorkingNow,
                      value: kpis.currentlyWorking.toString(),
                      color: AppColors.colorSuccess,
                      icon: LucideIcons.userCheck,
                    ),
                    _buildKpiCard(
                      label: l10n.kpiUpcoming,
                      value: kpis.scheduledUpcoming.toString(),
                      color: AppColors.colorStatusInfo,
                      icon: LucideIcons.calendarClock,
                    ),
                    _buildKpiCard(
                      label: l10n.kpiLate,
                      value: kpis.lateCheckedIn.toString(),
                      color: AppColors.colorWarning,
                      icon: LucideIcons.alertTriangle,
                    ),
                    _buildKpiCard(
                      label: l10n.kpiCompleted,
                      value: kpis.completed.toString(),
                      color: AppColors.colorTextSecondary,
                      icon: LucideIcons.checkCircle,
                    ),
                    _buildKpiCard(
                      label: l10n.kpiNotCheckedIn,
                      value: kpis.notCheckedIn.toString(),
                      color: AppColors.colorError,
                      icon: LucideIcons.userX,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space24),
                // Today's Roster Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.attendanceRosterTitle,
                      style: typography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.colorTextPrimary,
                      ),
                    ),
                    Text(
                      l10n.rosterScheduledCount(roster.length),
                      style: typography.caption.copyWith(
                        color: AppColors.colorTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space12),
                if (roster.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.space32),
                    decoration: BoxDecoration(
                      color: AppColors.colorSurfaceRaised,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        l10n.noEmployeesScheduledToday,
                        style: typography.bodyMedium.copyWith(
                          color: AppColors.colorTextSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: roster.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.space8),
                    itemBuilder: (context, idx) {
                      final item = roster[idx];
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.space16),
                        decoration: BoxDecoration(
                          color: AppColors.colorSurfaceRaised,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.colorBorderSubtle,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  AppColors.colorSurfaceBrandSubtle,
                              child: Text(
                                item.firstName.isNotEmpty
                                    ? item.firstName[0].toUpperCase()
                                    : '?',
                                style: typography.bodyStrong.copyWith(
                                  color: AppColors.colorTextPrimary,
                                  fontWeight: FontWeight.bold,
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
                                      Text(
                                        item.fullName,
                                        style: typography.bodyStrong.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.colorTextPrimary,
                                        ),
                                      ),
                                      if (item.employeeCode != null) ...[
                                        const SizedBox(
                                            width: AppSpacing.space4),
                                        Text(
                                          '(${item.employeeCode})',
                                          style: typography.caption.copyWith(
                                            color: AppColors.colorTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.shiftName} (${timeFormat.format(item.startsAt.toLocal())} - ${timeFormat.format(item.endsAt.toLocal())})',
                                    style: typography.caption.copyWith(
                                      color: AppColors.colorTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusPill(item, l10n),
                            if (item.attendanceId != null)
                              IconButton(
                                icon: const Icon(LucideIcons.edit2, size: 16),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => ManualCorrectionDialog(
                                      rosterItem: item,
                                      onConfirm: (newIn, newOut, reason) async {
                                        final repo = ref
                                            .read(attendanceRepositoryProvider);
                                        await repo.correctAttendanceRecord(
                                          attendanceRecordId:
                                              item.attendanceId!,
                                          newCheckIn: newIn,
                                          newCheckOut: newOut,
                                          reason: reason,
                                        );
                                        ref.invalidate(
                                            managerLiveAttendanceProvider(
                                                stationId));
                                      },
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Error loading live attendance: $err')),
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    const typography = AppTypography();
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.colorBorderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: typography.displayLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            label,
            style: typography.caption.copyWith(
              color: AppColors.colorTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(LiveRosterItem item, AppLocalizations l10n) {
    const typography = AppTypography();
    Color bg;
    Color fg;
    String label;

    switch (item.operationalStatus) {
      case LiveRosterStatus.working:
        bg = AppColors.colorStatusSuccessSubtle;
        fg = AppColors.colorStatusSuccess;
        label = item.elapsedMinutes != null
            ? '${item.elapsedMinutes}m'
            : l10n.attendanceStatusWorking;
        break;
      case LiveRosterStatus.upcoming:
        bg = AppColors.colorStatusInfoSubtle;
        fg = AppColors.colorStatusInfo;
        label = l10n.attendanceStatusUpcoming;
        break;
      case LiveRosterStatus.late:
        bg = AppColors.colorStatusWarningSubtle;
        fg = AppColors.colorStatusWarning;
        label = l10n.attendanceStatusLate(item.lateMinutes);
        break;
      case LiveRosterStatus.completed:
        bg = AppColors.colorStatusSuccessSubtle;
        fg = AppColors.colorStatusSuccess;
        label = l10n.attendanceStatusCompleted;
        break;
      case LiveRosterStatus.notCheckedIn:
        bg = AppColors.colorStatusDangerSubtle;
        fg = AppColors.colorStatusDanger;
        label = l10n.attendanceStatusNotCheckedIn;
        break;
      case LiveRosterStatus.unknown:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey;
        label = '--';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: typography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
