import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../domain/models/presence_proof.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

class ShiftPreviewModal extends StatelessWidget {
  final PresenceProof proof;
  final VoidCallback onConfirm;
  final bool isSubmitting;

  const ShiftPreviewModal({
    super.key,
    required this.proof,
    required this.onConfirm,
    this.isSubmitting = false,
  });

  String _formatTime(String? isoString) {
    if (isoString == null) return '--:--';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final preview = proof.shiftPreview ?? {};
    final isCheckIn = proof.action == AttendanceAction.checkIn;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space24),
      decoration: const BoxDecoration(
        color: AppColors.colorSurfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.colorBorderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.space12),
                decoration: BoxDecoration(
                  color: (isCheckIn
                          ? AppColors.colorSurfaceBrand
                          : AppColors.colorActionDestructive)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCheckIn ? LucideIcons.logIn : LucideIcons.logOut,
                  color: isCheckIn
                      ? AppColors.colorTextPrimary
                      : AppColors.colorActionDestructive,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCheckIn
                          ? l10n.attendanceConfirmCheckIn
                          : l10n.attendanceConfirmCheckOut,
                      style: typography.titleLarge.copyWith(
                        color: AppColors.colorTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      proof.stationName,
                      style: typography.caption.copyWith(
                        color: AppColors.colorTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space24),
          Container(
            padding: const EdgeInsets.all(AppSpacing.space16),
            decoration: BoxDecoration(
              color: AppColors.colorSurfaceBase,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.colorBorderSubtle,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.shiftLabel,
                      style: typography.bodyMedium.copyWith(
                        color: AppColors.colorTextSecondary,
                      ),
                    ),
                    Text(
                      (preview['shift_name'] as String?) ?? l10n.scheduledShift,
                      style: typography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.colorTextPrimary,
                      ),
                    ),
                  ],
                ),
                if (isCheckIn && preview['starts_at'] != null) ...[
                  const SizedBox(height: AppSpacing.space12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.scheduledWindow,
                        style: typography.bodyMedium.copyWith(
                          color: AppColors.colorTextSecondary,
                        ),
                      ),
                      Text(
                        '${_formatTime(preview['starts_at'] as String?)} - ${_formatTime(preview['ends_at'] as String?)}',
                        style: typography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.colorTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (!isCheckIn && preview['elapsed_minutes'] != null) ...[
                  const SizedBox(height: AppSpacing.space12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.workedTimeLabel,
                        style: typography.bodyMedium.copyWith(
                          color: AppColors.colorTextSecondary,
                        ),
                      ),
                      Text(
                        '${preview['elapsed_minutes']} min',
                        style: typography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.colorTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCheckIn
                    ? AppColors.colorSurfaceBrand
                    : AppColors.colorActionDestructive,
                foregroundColor: isCheckIn ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      isCheckIn
                          ? l10n.checkInNowAction
                          : l10n.checkOutNowAction,
                      style: typography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isCheckIn ? Colors.black : Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
