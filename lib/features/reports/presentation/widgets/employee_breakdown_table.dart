import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/employee_attendance_summary.dart';

class EmployeeBreakdownTable extends StatelessWidget {
  final List<EmployeeAttendanceSummary> employees;
  final String sortBy;
  final String sortOrder;
  final ValueChanged<String> onSort;
  final ValueChanged<EmployeeAttendanceSummary> onSelectEmployee;

  const EmployeeBreakdownTable({
    super.key,
    required this.employees,
    required this.sortBy,
    required this.sortOrder,
    required this.onSort,
    required this.onSelectEmployee,
  });

  String _formatHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;

    if (!isDesktop) {
      // Mobile card layout
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: employees.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final emp = employees[index];
          return _buildMobileEmployeeCard(context, emp, theme, l10n);
        },
      );
    }

    // Desktop/Tablet Responsive Table
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(
              theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
            ),
            sortColumnIndex: _getSortColumnIndex(sortBy),
            sortAscending: sortOrder == 'asc',
            columns: [
              DataColumn(
                label: Text(l10n.tableColEmployee),
                onSort: (_, __) => onSort('name'),
              ),
              DataColumn(
                label: Text(l10n.tableColCode),
                onSort: (_, __) => onSort('employee_code'),
              ),
              DataColumn(
                label: Text(l10n.tableColWorkedTime),
                numeric: true,
                onSort: (_, __) => onSort('worked_minutes'),
              ),
              DataColumn(
                label: Text(l10n.tableColCompleted),
                numeric: true,
                onSort: (_, __) => onSort('completed_shifts'),
              ),
              DataColumn(
                label: Text(l10n.tableColLateShifts),
                numeric: true,
                onSort: (_, __) => onSort('late_shifts'),
              ),
              DataColumn(
                label: Text(l10n.tableColCorrections),
                numeric: true,
                onSort: (_, __) => onSort('corrected_records'),
              ),
              DataColumn(label: Text(l10n.tableColStatus)),
            ],
            rows: employees.map((emp) {
              return DataRow(
                onSelectChanged: (_) => onSelectEmployee(emp),
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            emp.firstName.isNotEmpty
                                ? emp.firstName[0].toUpperCase()
                                : '?',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              emp.fullName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (emp.hasRepeatedLateness)
                              Text(
                                l10n.repeatedLatenessTag,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFFEF4444),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(emp.employeeCode ?? '--')),
                  DataCell(
                    Text(
                      _formatHours(emp.totalWorkedMinutes),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataCell(Text('${emp.completedShifts}')),
                  DataCell(
                    emp.lateShifts > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${emp.lateShifts} (${emp.totalLateMinutes}m)',
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : const Text('0'),
                  ),
                  DataCell(
                    emp.correctedRecords > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${emp.correctedRecords}',
                              style: const TextStyle(
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : const Text('0'),
                  ),
                  DataCell(
                    _buildStatusBadge(theme, emp.membershipStatus, l10n),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  int? _getSortColumnIndex(String sort) {
    switch (sort) {
      case 'name':
        return 0;
      case 'employee_code':
        return 1;
      case 'worked_minutes':
        return 2;
      case 'completed_shifts':
        return 3;
      case 'late_shifts':
        return 4;
      case 'corrected_records':
        return 5;
      default:
        return 0;
    }
  }

  Widget _buildMobileEmployeeCard(BuildContext context,
      EmployeeAttendanceSummary emp, ThemeData theme, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onSelectEmployee(emp),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        emp.firstName.isNotEmpty
                            ? emp.firstName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.fullName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${emp.employeeCode ?? '--'} • ${emp.stationRole}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(theme, emp.membershipStatus, l10n),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricCol(theme, l10n.tableMetricWorked,
                        _formatHours(emp.totalWorkedMinutes)),
                    _buildMetricCol(theme, l10n.tableMetricShifts,
                        '${emp.completedShifts}'),
                    _buildMetricCol(theme, l10n.tableMetricLate,
                        '${emp.lateShifts} (${emp.totalLateMinutes}m)',
                        isAlert: emp.lateShifts > 0),
                    _buildMetricCol(theme, l10n.tableMetricCorrected,
                        '${emp.correctedRecords}',
                        isInfo: emp.correctedRecords > 0),
                  ],
                ),
                if (emp.hasRepeatedLateness) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_rounded,
                            size: 14, color: Color(0xFFEF4444)),
                        const SizedBox(width: 4),
                        Text(
                          l10n.repeatedLatenessTag,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCol(ThemeData theme, String label, String val,
      {bool isAlert = false, bool isInfo = false}) {
    Color? color;
    if (isAlert) color = const Color(0xFFEF4444);
    if (isInfo) color = const Color(0xFF3B82F6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(
      ThemeData theme, String status, AppLocalizations l10n) {
    final isInactive = status.toUpperCase() == 'INACTIVE';
    final isSuspended = status.toUpperCase() == 'SUSPENDED';
    final color = isInactive
        ? const Color(0xFF94A3B8)
        : (isSuspended ? const Color(0xFFEF4444) : const Color(0xFF10B981));

    final label = isInactive
        ? l10n.statusInactive
        : (isSuspended ? l10n.statusSuspended : l10n.statusActive);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
