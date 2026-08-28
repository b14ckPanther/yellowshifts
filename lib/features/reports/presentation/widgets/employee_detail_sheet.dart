import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/attendance_correction_detail.dart';

class EmployeeDetailSheet extends StatelessWidget {
  final StationEmployeeAttendanceDetailResponse detail;
  final VoidCallback onClose;

  const EmployeeDetailSheet({
    super.key,
    required this.detail,
    required this.onClose,
  });

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
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
    final summary = detail.summary;
    final totalMins = (summary['total_worked_minutes'] as num?)?.toInt() ?? 0;
    final shifts = (summary['completed_shifts'] as num?)?.toInt() ?? 0;
    final lateShifts = (summary['late_shifts'] as num?)?.toInt() ?? 0;
    final corrected = (summary['corrected_records'] as num?)?.toInt() ?? 0;
    final hasRepeatedLateness =
        summary['has_repeated_lateness'] as bool? ?? false;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    detail.employee.firstName.isNotEmpty
                        ? detail.employee.firstName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.employee.fullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${detail.employee.employeeCode ?? '--'} • ${detail.employee.stationRole} • ${detail.stationName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // KPI Summary Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildKpi(
                    theme, l10n.kpiWorkedHours, _formatMinutes(totalMins)),
                _buildKpi(theme, l10n.kpiCompletedShifts, '$shifts'),
                _buildKpi(
                  theme,
                  l10n.kpiLateArrivals,
                  '$lateShifts',
                  isAlert: lateShifts > 0,
                ),
                _buildKpi(
                  theme,
                  l10n.kpiCorrectedRecords,
                  '$corrected',
                  isInfo: corrected > 0,
                ),
              ],
            ),
          ),

          if (hasRepeatedLateness)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.repeatedLatenessPattern,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.attendanceCorrectionHistory,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),

          // Records List
          Expanded(
            child: detail.records.isEmpty
                ? Center(child: Text(l10n.noRecordsInPeriod))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: detail.records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final rec = detail.records[index];
                      return _buildRecordTile(context, rec, theme, l10n);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpi(ThemeData theme, String label, String value,
      {bool isAlert = false, bool isInfo = false}) {
    Color? color;
    if (isAlert) color = const Color(0xFFEF4444);
    if (isInfo) color = const Color(0xFF3B82F6);

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordTile(
      BuildContext context,
      AttendanceRecordWithCorrections rec,
      ThemeData theme,
      AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          title: Row(
            children: [
              Text(
                rec.operationalDate,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  rec.shiftNameSnapshot ?? l10n.walkInShift,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          subtitle: Text(
            '${_formatTime(rec.checkInTime)} -> ${_formatTime(rec.checkOutTime)}${rec.isLate ? ' • ${l10n.attendanceStatusLate(rec.lateMinutes)}' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: rec.isLate
                  ? const Color(0xFFEF4444)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatMinutes(rec.workedMinutes),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (rec.isCorrected)
                Text(
                  l10n.correctionsCount(rec.corrections.length),
                  style:
                      const TextStyle(color: Color(0xFF3B82F6), fontSize: 11),
                ),
            ],
          ),
          children: [
            if (rec.corrections.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.correctionLedger,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...rec.corrections.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      l10n.correctionByActor(c.actorName),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatTime(c.createdAt),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(fontSize: 10),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.correctionDurationChange(
                                    _formatMinutes(c.previousWorkedMinutes),
                                    _formatMinutes(c.newWorkedMinutes),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (c.reason.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.correctionReasonPrefix(c.reason),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
