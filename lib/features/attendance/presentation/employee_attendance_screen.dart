import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'providers/attendance_providers.dart';
import 'widgets/attendance_status_card.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/errors/error_localizer.dart';
import '../../../l10n/app_localizations.dart';

class EmployeeAttendanceScreen extends ConsumerStatefulWidget {
  const EmployeeAttendanceScreen({super.key});

  @override
  ConsumerState<EmployeeAttendanceScreen> createState() =>
      _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState
    extends ConsumerState<EmployeeAttendanceScreen> {
  void _showTestNfcDialog() {
    final tokenController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.colorSurfaceRaised,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: const Row(
          children: [
            Icon(LucideIcons.terminal, color: AppColors.colorTextPrimary),
            SizedBox(width: AppSpacing.space8),
            Text('Simulate NFC Tag Tap'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter an NFC station token or paste a full /nfc/t/:token URL to test the flow:',
              style: TextStyle(color: AppColors.colorTextSecondary),
            ),
            const SizedBox(height: AppSpacing.space12),
            TextField(
              controller: tokenController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. 8cd51f15a8d746f0b52d92e08713c1d7...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              var input = tokenController.text.trim();
              if (input.isNotEmpty) {
                Navigator.of(dialogCtx).pop();
                if (input.contains('/nfc/t/')) {
                  final parts = input.split('/nfc/t/');
                  if (parts.length > 1) {
                    input = parts[1].split('?')[0].split('#')[0];
                  }
                }
                context.go('/nfc/t/$input');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.colorSurfaceBrand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Go to NFC Route'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final openAttAsync = ref.watch(currentOpenAttendanceProvider);
    final historyAsync = ref.watch(myAttendanceHistoryProvider);
    ref.watch(attendanceRealtimeSubscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      appBar: AppBar(
        title: Text(l10n.attendanceTitle),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () {
              ref.invalidate(currentOpenAttendanceProvider);
              ref.invalidate(myAttendanceHistoryProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentOpenAttendanceProvider);
          ref.invalidate(myAttendanceHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.space16),
          children: [
            // Status Hero Card
            openAttAsync.when(
              data: (openRecord) => AttendanceStatusCard(
                openAttendance: openRecord,
                onTestNfcTap: _showTestNfcDialog,
              ),
              loading: () => Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.colorSurfaceRaised,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(AppSpacing.space16),
                decoration: BoxDecoration(
                  color: AppColors.colorSurfaceRaised,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(ErrorLocalizer.localize(err, l10n)),
              ),
            ),
            const SizedBox(height: AppSpacing.space24),
            // Recent Attendance Section
            Text(
              l10n.attendanceRecentHistory,
              style: typography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.colorTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            historyAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.space24),
                    decoration: BoxDecoration(
                      color: AppColors.colorSurfaceRaised,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.colorBorderSubtle,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        l10n.attendanceNoHistory,
                        style: typography.bodyMedium.copyWith(
                          color: AppColors.colorTextSecondary,
                        ),
                      ),
                    ),
                  );
                }

                final timeFormat = DateFormat('HH:mm');
                final dateFormat = DateFormat('EEE, d MMM');

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: records.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.space8),
                  itemBuilder: (context, idx) {
                    final item = records[idx];
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.space16),
                      decoration: BoxDecoration(
                        color: AppColors.colorSurfaceRaised,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.colorBorderSubtle,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.space8),
                            decoration: BoxDecoration(
                              color: (item.isOpen
                                      ? AppColors.colorSurfaceBrand
                                      : AppColors.colorSuccess)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item.isOpen
                                  ? LucideIcons.clock
                                  : LucideIcons.checkCircle2,
                              size: 18,
                              color: item.isOpen
                                  ? AppColors.colorTextPrimary
                                  : AppColors.colorSuccess,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.shiftName ?? l10n.attendanceWorkShift,
                                  style: typography.bodyStrong.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.colorTextPrimary,
                                  ),
                                ),
                                Text(
                                  dateFormat.format(item.checkInTime.toLocal()),
                                  style: typography.caption.copyWith(
                                    color: AppColors.colorTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${timeFormat.format(item.checkInTime.toLocal())} - ${item.checkOutTime != null ? timeFormat.format(item.checkOutTime!.toLocal()) : l10n.timeNow}',
                                style: typography.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.colorTextPrimary,
                                ),
                              ),
                              if (item.workedMinutes != null)
                                Text(
                                  '${item.workedMinutes} min',
                                  style: typography.caption.copyWith(
                                    color: AppColors.colorActionPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
