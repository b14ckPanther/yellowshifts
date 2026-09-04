import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'providers/attendance_providers.dart';
import 'widgets/attendance_status_card.dart';
import 'widgets/nfc_scanner_modal.dart';
import '../../../core/design_system/tokens/app_colors.dart';
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
  void _openNfcScanner({required bool isCheckIn}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => NfcScannerModal(
        isCheckIn: isCheckIn,
        onSuccess: () {
          ref.invalidate(currentOpenAttendanceProvider);
          ref.invalidate(myAttendanceHistoryProvider);
        },
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
                onScanTap: () => _openNfcScanner(isCheckIn: true),
                onCheckOutTap: () => _openNfcScanner(isCheckIn: false),
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
