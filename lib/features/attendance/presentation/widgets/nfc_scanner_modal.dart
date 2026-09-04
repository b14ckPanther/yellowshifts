import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../core/nfc/nfc_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/attendance_providers.dart';

enum NfcScanState {
  ready,
  scanning,
  verifying,
  success,
  error,
}

class NfcScannerModal extends ConsumerStatefulWidget {
  final bool isCheckIn;
  final VoidCallback? onSuccess;

  const NfcScannerModal({
    super.key,
    required this.isCheckIn,
    this.onSuccess,
  });

  @override
  ConsumerState<NfcScannerModal> createState() => _NfcScannerModalState();
}

class _NfcScannerModalState extends ConsumerState<NfcScannerModal>
    with SingleTickerProviderStateMixin {
  NfcScanState _state = NfcScanState.ready;
  String? _errorMessage;
  Map<String, dynamic>? _resultData;
  late AnimationController _pulseController;
  late NfcService _nfcService;

  @override
  void initState() {
    super.initState();
    _nfcService = ref.read(nfcServiceProvider);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _nfcService.stopSession();
    super.dispose();
  }

  Future<void> _startScan() async {
    final l10n = AppLocalizations.of(context)!;
    final nfcService = ref.read(nfcServiceProvider);

    final available = await nfcService.isAvailable();
    if (!available) {
      if (mounted) {
        setState(() {
          _state = NfcScanState.error;
          _errorMessage = l10n.nfcUnavailableError;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _state = NfcScanState.scanning;
      _errorMessage = null;
    });

    await nfcService.startStationTagScan(
      alertMessage: widget.isCheckIn
          ? l10n.nfcScanCheckInPrompt
          : l10n.nfcScanCheckOutPrompt,
      onTagScanned: (payload) async {
        if (!mounted) return;
        setState(() {
          _state = NfcScanState.verifying;
        });
        await _verifyAndCommitAttendance(payload);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _state = NfcScanState.error;
          _errorMessage = err;
        });
      },
    );
  }

  Future<void> _verifyAndCommitAttendance(NfcStationTagPayload payload) async {
    final l10n = AppLocalizations.of(context)!;
    final attRepo = ref.read(attendanceRepositoryProvider);

    try {
      Map<String, dynamic> res;
      if (widget.isCheckIn) {
        res = await attRepo.nfcCheckIn(
          tagIdentifier: payload.tagIdentifier,
          tagSecret: payload.rawSecret,
        );
      } else {
        res = await attRepo.nfcCheckOut(
          tagIdentifier: payload.tagIdentifier,
          tagSecret: payload.rawSecret,
        );
      }

      if (!mounted) return;

      setState(() {
        _state = NfcScanState.success;
        _resultData = res;
      });

      ref.invalidate(currentOpenAttendanceProvider);
      ref.invalidate(myAttendanceHistoryProvider);

      widget.onSuccess?.call();

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = NfcScanState.error;
        _errorMessage = ErrorLocalizer.localize(e, l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space24,
        vertical: AppSpacing.space20,
      ),
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
          const SizedBox(height: AppSpacing.space20),
          _buildVisualState(typography, l10n),
          const SizedBox(height: AppSpacing.space24),
          _buildActionButtons(typography, l10n),
          const SizedBox(height: AppSpacing.space8),
        ],
      ),
    );
  }

  Widget _buildVisualState(AppTypography typography, AppLocalizations l10n) {
    switch (_state) {
      case NfcScanState.ready:
      case NfcScanState.scanning:
        return Column(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.12);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.colorSurfaceBrandSubtle,
                      border: Border.all(
                        color: AppColors.colorSurfaceBrand.withValues(
                            alpha: 0.5 + (_pulseController.value * 0.5)),
                        width: 3,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.radio,
                        size: 48,
                        color: AppColors.colorTextPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.space24),
            Text(
              widget.isCheckIn ? l10n.nfcCheckInTitle : l10n.nfcCheckOutTitle,
              style: typography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.colorTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            Text(
              l10n.nfcHoldNearPrompt,
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(
                color: AppColors.colorTextSecondary,
              ),
            ),
          ],
        );

      case NfcScanState.verifying:
        return Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.colorSurfaceBrandSubtle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.colorTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space24),
            Text(
              l10n.nfcVerifyingPresence,
              style: typography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.colorTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            Text(
              l10n.nfcAuthorizingBackend,
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(
                color: AppColors.colorTextSecondary,
              ),
            ),
          ],
        );

      case NfcScanState.success:
        return Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.colorSuccess.withValues(alpha: 0.15),
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.checkCircle2,
                  size: 52,
                  color: AppColors.colorSuccess,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space24),
            Text(
              widget.isCheckIn
                  ? l10n.nfcCheckInSuccess
                  : l10n.nfcCheckOutSuccess,
              style: typography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.colorSuccess,
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            if (_resultData != null && _resultData!['station_name'] != null)
              Text(
                _resultData!['station_name'] as String,
                style: typography.bodyStrong.copyWith(
                  color: AppColors.colorTextPrimary,
                ),
              ),
          ],
        );

      case NfcScanState.error:
        return Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.colorError.withValues(alpha: 0.15),
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.alertCircle,
                  size: 52,
                  color: AppColors.colorError,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space24),
            Text(
              l10n.nfcVerificationFailed,
              style: typography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.colorError,
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            Text(
              _errorMessage ?? l10n.errorGeneric,
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(
                color: AppColors.colorTextSecondary,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildActionButtons(AppTypography typography, AppLocalizations l10n) {
    if (_state == NfcScanState.error) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(l10n.dialogCancel),
            ),
          ),
          const SizedBox(width: AppSpacing.space12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(LucideIcons.rotateCcw, size: 18),
              label: Text(l10n.startupRetry),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppColors.colorSurfaceBrand,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_state == NfcScanState.success) {
      return const SizedBox.shrink();
    }

    return TextButton(
      onPressed: () {
        ref.read(nfcServiceProvider).stopSession();
        Navigator.of(context).pop();
      },
      child: Text(
        l10n.dialogCancel,
        style: typography.bodyMedium.copyWith(
          color: AppColors.colorTextSecondary,
        ),
      ),
    );
  }
}
