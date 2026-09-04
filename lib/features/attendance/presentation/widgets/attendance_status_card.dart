import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../domain/models/attendance_record.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

class AttendanceStatusCard extends StatefulWidget {
  final AttendanceRecord? openAttendance;
  final VoidCallback onScanTap;
  final VoidCallback onCheckOutTap;

  const AttendanceStatusCard({
    super.key,
    required this.openAttendance,
    required this.onScanTap,
    required this.onCheckOutTap,
  });

  @override
  State<AttendanceStatusCard> createState() => _AttendanceStatusCardState();
}

class _AttendanceStatusCardState extends State<AttendanceStatusCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.openAttendance != null && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatElapsed(DateTime start) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(start);
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final isWorking = widget.openAttendance != null;

    if (!isWorking) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.space24),
        decoration: BoxDecoration(
          color: AppColors.colorSurfaceRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.colorBorderSubtle,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.space16),
              decoration: const BoxDecoration(
                color: AppColors.colorSurfaceBrandSubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.radio,
                size: 40,
                color: AppColors.colorTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            Text(
              l10n.attendanceNotCheckedIn,
              style: typography.titleLarge.copyWith(
                color: AppColors.colorTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              l10n.attendanceScanPrompt,
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(
                color: AppColors.colorTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: widget.onScanTap,
                icon: const Icon(LucideIcons.radio, size: 20),
                label: Text(
                  l10n.attendanceScanNfcAction,
                  style: typography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.colorSurfaceBrand,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final record = widget.openAttendance!;
    final elapsedStr = _formatElapsed(record.checkInTime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space24),
      decoration: BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.colorSuccess.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.colorSuccess.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.colorSuccess,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.space8),
              Text(
                l10n.attendanceCurrentlyWorking,
                style: typography.caption.copyWith(
                  color: AppColors.colorSuccess,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          Text(
            record.shiftName ?? l10n.attendanceActiveShift,
            style: typography.titleLarge.copyWith(
              color: AppColors.colorTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            elapsedStr,
            style: typography.displayLarge.copyWith(
              color: AppColors.colorTextPrimary,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (record.lateMinutes > 0) ...[
            const SizedBox(height: AppSpacing.space8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.colorStatusWarningSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.attendanceLateDuration(record.lateMinutes),
                style: typography.caption.copyWith(
                  color: AppColors.colorWarning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.space24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: widget.onCheckOutTap,
              icon: const Icon(LucideIcons.logOut, size: 20),
              label: Text(
                l10n.attendanceCheckOutAction,
                style: typography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.colorActionDestructive,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
