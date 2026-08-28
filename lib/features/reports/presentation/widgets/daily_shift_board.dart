import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/daily_attendance_report.dart';

class DailyShiftBoard extends StatelessWidget {
  final DailyAttendanceReport report;
  final ValueChanged<DailyShiftAttendanceRecord>? onSelectRecord;

  const DailyShiftBoard({
    super.key,
    required this.report,
    this.onSelectRecord,
  });

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatMinutes(int? mins) {
    if (mins == null) return '--';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (report.shifts.isEmpty && report.walkIns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(
                Icons.event_busy_outlined,
                size: 48,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.dailyNoRecords,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scheduled Shifts
        if (report.shifts.isNotEmpty) ...[
          Text(
            l10n.dailyScheduledShiftsTitle(report.shifts.length),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.shifts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final shift = report.shifts[index];
              return _buildShiftCard(context, shift, theme, l10n);
            },
          ),
          const SizedBox(height: 24),
        ],

        // Unscheduled Walk-Ins
        if (report.walkIns.isNotEmpty) ...[
          Text(
            l10n.dailyWalkInTitle(report.walkIns.length),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: report.walkIns.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final walkIn = report.walkIns[index];
                return ListTile(
                  title: Text(
                    walkIn.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${walkIn.employeeCode ?? '--'} • ${l10n.checkedInLabel}: ${_formatTime(walkIn.checkInTime)} -> ${walkIn.checkOutTime != null ? _formatTime(walkIn.checkOutTime!) : l10n.statusActive.toUpperCase()}',
                  ),
                  trailing: Text(
                    _formatMinutes(walkIn.workedMinutes),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: walkIn.isOpen
                          ? const Color(0xFF10B981)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  onTap: onSelectRecord != null
                      ? () => onSelectRecord!(walkIn)
                      : null,
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildShiftCard(BuildContext context, DailyScheduledShift shift,
      ThemeData theme, AppLocalizations l10n) {
    final hasStaffShortage = shift.unassignedCount > 0;

    return Container(
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Text(
                shift.shiftName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_formatTime(shift.startsAt)} - ${_formatTime(shift.endsAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildChip(
                  theme,
                  l10n.dailyRequiredStaff(shift.requiredStaffCount),
                  Colors.grey,
                ),
                _buildChip(
                  theme,
                  l10n.dailyAssignedStaff(shift.assignedCount),
                  hasStaffShortage
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF3B82F6),
                ),
                _buildChip(
                  theme,
                  l10n.dailyCheckedInStaff(shift.checkedInCount),
                  const Color(0xFF10B981),
                ),
                if (shift.lateCount > 0)
                  _buildChip(
                    theme,
                    l10n.dailyLateStaff(shift.lateCount),
                    const Color(0xFFEF4444),
                  ),
                if (shift.openCount > 0)
                  _buildChip(
                    theme,
                    l10n.dailyActiveOpenStaff(shift.openCount),
                    const Color(0xFF10B981),
                  ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1),
            if (shift.attendanceRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.dailyNoShiftRecords,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: shift.attendanceRecords.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, rIndex) {
                  final rec = shift.attendanceRecords[rIndex];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        rec.firstName.isNotEmpty
                            ? rec.firstName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      rec.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${_formatTime(rec.checkInTime)} -> ${rec.checkOutTime != null ? _formatTime(rec.checkOutTime!) : l10n.statusActive.toUpperCase()}${rec.lateMinutes > 0 ? ' • ${l10n.lateMinutesLabel(rec.lateMinutes)}' : ''}',
                    ),
                    trailing: Text(
                      _formatMinutes(rec.workedMinutes),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: rec.isOpen
                            ? const Color(0xFF10B981)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    onTap: onSelectRecord != null
                        ? () => onSelectRecord!(rec)
                        : null,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(ThemeData theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
