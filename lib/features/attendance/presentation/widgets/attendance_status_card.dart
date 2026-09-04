import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../domain/models/attendance_record.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

class AttendanceStatusCard extends StatefulWidget {
  final AttendanceRecord? openAttendance;
  final VoidCallback? onTestNfcTap;

  const AttendanceStatusCard({
    super.key,
    required this.openAttendance,
    this.onTestNfcTap,
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
          borderRadius: BorderRadius.circular(20.0),
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
            const SizedBox(height: AppSpacing.space8),
            Text(
              l10n.nfcTapPhysicalPrompt,
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(
                color: AppColors.colorTextSecondary,
                height: 1.4,
              ),
            ),
            if (widget.onTestNfcTap != null) ...[
              const SizedBox(height: AppSpacing.space20),
              OutlinedButton.icon(
                onPressed: widget.onTestNfcTap,
                icon: const Icon(LucideIcons.terminal, size: 16),
                label: const Text('Simulate / Test NFC URL'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  ),
                ),
              ),
            ],
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
        borderRadius: BorderRadius.circular(20.0),
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
          const SizedBox(height: AppSpacing.space20),
          Container(
            padding: const EdgeInsets.all(AppSpacing.space12),
            decoration: BoxDecoration(
              color: AppColors.colorSurfaceBase,
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              border: Border.all(color: AppColors.colorBorderSubtle),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.radio,
                    size: 18, color: AppColors.colorTextSecondary),
                const SizedBox(width: AppSpacing.space8),
                Expanded(
                  child: Text(
                    l10n.nfcTapPhysicalPrompt,
                    style: typography.caption.copyWith(
                      color: AppColors.colorTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.onTestNfcTap != null) ...[
            const SizedBox(height: AppSpacing.space12),
            TextButton.icon(
              onPressed: widget.onTestNfcTap,
              icon: const Icon(LucideIcons.terminal, size: 14),
              label: const Text('Simulate / Test NFC URL'),
            ),
          ],
        ],
      ),
    );
  }
}
