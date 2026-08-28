import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../domain/models/live_attendance_roster.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

class ManualCorrectionDialog extends StatefulWidget {
  final LiveRosterItem rosterItem;
  final Function(DateTime newCheckIn, DateTime newCheckOut, String reason)
      onConfirm;

  const ManualCorrectionDialog({
    super.key,
    required this.rosterItem,
    required this.onConfirm,
  });

  @override
  State<ManualCorrectionDialog> createState() => _ManualCorrectionDialogState();
}

class _ManualCorrectionDialogState extends State<ManualCorrectionDialog> {
  late DateTime _checkIn;
  late DateTime _checkOut;
  final TextEditingController _reasonController = TextEditingController();
  final bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkIn = widget.rosterItem.checkInTime ?? widget.rosterItem.startsAt;
    _checkOut = widget.rosterItem.checkOutTime ?? widget.rosterItem.endsAt;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isCheckIn) async {
    final current = isCheckIn ? _checkIn : _checkOut;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current.toLocal()),
    );

    if (time != null) {
      setState(() {
        final local = DateTime(
          current.year,
          current.month,
          current.day,
          time.hour,
          time.minute,
        );
        if (isCheckIn) {
          _checkIn = local.toUtc();
        } else {
          _checkOut = local.toUtc();
        }
      });
    }
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      setState(() {
        _error =
            'Please enter a valid justification reason (at least 3 characters).';
      });
      return;
    }

    if (!_checkOut.isAfter(_checkIn)) {
      setState(() {
        _error = 'Check-out time must be after check-in time.';
      });
      return;
    }

    widget.onConfirm(_checkIn, _checkOut, reason);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final timeFormat = DateFormat('HH:mm');

    return AlertDialog(
      backgroundColor: AppColors.colorSurfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.space8),
            decoration: BoxDecoration(
              color: AppColors.colorStatusWarningSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.edit3,
                color: AppColors.colorWarning, size: 20),
          ),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Text(
              l10n.correctionDialogTitle,
              style: typography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.colorTextPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.rosterItem.fullName,
              style: typography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.colorTextPrimary,
              ),
            ),
            Text(
              widget.rosterItem.shiftName,
              style: typography.caption.copyWith(
                color: AppColors.colorTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            // Time selection rows
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(true),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.space12),
                      decoration: BoxDecoration(
                        color: AppColors.colorSurfaceBase,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.colorBorderSubtle,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.checkInLabel, style: typography.caption),
                          const SizedBox(height: 4),
                          Text(
                            timeFormat.format(_checkIn.toLocal()),
                            style: typography.titleMedium
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.space12),
                      decoration: BoxDecoration(
                        color: AppColors.colorSurfaceBase,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.colorBorderSubtle,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.checkOutLabel, style: typography.caption),
                          const SizedBox(height: 4),
                          Text(
                            timeFormat.format(_checkOut.toLocal()),
                            style: typography.titleMedium
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space16),
            // Mandatory reason
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.correctionReasonLabel,
                hintText: l10n.correctionReasonHint,
                filled: true,
                fillColor: AppColors.colorSurfaceBase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.space8),
              Text(
                _error!,
                style: typography.caption.copyWith(color: AppColors.colorError),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.dialogCancel),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.colorSurfaceBrand,
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(l10n.correctionSaveAction),
        ),
      ],
    );
  }
}
