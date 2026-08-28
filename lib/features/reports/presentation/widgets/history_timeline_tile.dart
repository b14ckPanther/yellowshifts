import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/attendance_history_item.dart';

class HistoryTimelineTile extends StatelessWidget {
  final AttendanceHistoryItem item;
  final VoidCallback? onTap;

  const HistoryTimelineTile({
    super.key,
    required this.item,
    this.onTap,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Date column
                Container(
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        item.operationalDate.length >= 10
                            ? item.operationalDate.substring(8, 10)
                            : '',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        item.operationalDate.length >= 7
                            ? item.operationalDate.substring(5, 7)
                            : '',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Shift & Station info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.shiftNameSnapshot ?? l10n.walkInShift,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.isLate) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.attendanceStatusLate(item.lateMinutes),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFFEF4444),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                          if (item.isCorrected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.statusCorrected,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFF3B82F6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.stationName} (${item.stationCode})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatTime(item.checkInTime)} -> ${_formatTime(item.checkOutTime)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                // Duration display
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatMinutes(item.workedMinutes),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: item.isOpen
                            ? const Color(0xFF10B981)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      item.isOpen
                          ? l10n.attendanceStatusWorking
                          : l10n.attendanceStatusCompleted,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: item.isOpen
                            ? const Color(0xFF10B981)
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
