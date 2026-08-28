import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'providers/attendance_providers.dart';
import 'widgets/attendance_status_card.dart';
import 'widgets/attendance_scanner_modal.dart';
import 'widgets/shift_preview_modal.dart';
import '../domain/models/presence_proof.dart';
import '../../identity/presentation/widgets/camera_liveness_overlay.dart';
import '../../identity/presentation/providers/identity_providers.dart';
import '../../identity/domain/models/identity_policy.dart';
import '../../stations/presentation/providers/station_providers.dart';
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
  bool _showBiometricOverlay = false;
  bool _isProcessingAttendance = false;
  String _biometricStatus = 'Verifying face liveness...';

  void _openScanner() {
    if (_isProcessingAttendance) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => AttendanceScannerModal(
        onCodeDetected: (code) => _handleScannedCode(code),
      ),
    );
  }

  Future<void> _handleScannedCode(String scannedCode) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final attRepo = ref.read(attendanceRepositoryProvider);
      final proof = await attRepo.scanAttendanceQr(scannedCode);

      if (!mounted) return;
      _showShiftPreview(proof);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorLocalizer.localize(e, l10n)),
          backgroundColor: AppColors.colorStatusDanger,
        ),
      );
    }
  }

  void _showShiftPreview(PresenceProof proof) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => ShiftPreviewModal(
        proof: proof,
        onConfirm: () async {
          Navigator.of(modalCtx).pop();
          await _executeAttendanceMutation(proof);
        },
      ),
    );
  }

  Future<void> _executeAttendanceMutation(PresenceProof proof) async {
    if (_isProcessingAttendance) return;
    setState(() => _isProcessingAttendance = true);

    final l10n = AppLocalizations.of(context)!;
    final isCheckIn = proof.action == AttendanceAction.checkIn;
    final attRepo = ref.read(attendanceRepositoryProvider);

    try {
      final currentStation = ref.read(currentStationProvider);
      final policyMode = IdentityVerificationMode.fromString(
        currentStation?.identityVerificationMode,
      );

      final requiresIdentity = (isCheckIn && policyMode.isRequiredForCheckIn) ||
          (!isCheckIn && policyMode.isRequiredForCheckOut);

      String? identityProofToken;

      if (requiresIdentity) {
        setState(() {
          _showBiometricOverlay = true;
          _biometricStatus = l10n.identityVerifyingFace;
        });

        final identityRepo = ref.read(identityRepositoryProvider);
        final identityProvider = ref.read(identityVerificationProvider);

        // 1. Start verification session
        final init = await identityRepo.startIdentityVerification(
          presenceProofToken: proof.presenceProofToken,
          provider: identityProvider.providerIdentifier,
        );

        // 2. Perform liveness & face matching on device
        final providerResult =
            await identityProvider.performLivenessAndVerification(
          providerSessionId: init.providerSessionId,
        );

        // 3. Complete verification on backend
        final completedProof = await identityRepo.completeIdentityVerification(
          attemptId: init.attemptId,
          isVerified: providerResult.isVerified,
          failureCategory: providerResult.failureCategory,
        );

        if (!mounted) return;
        setState(() {
          _showBiometricOverlay = false;
        });

        if (!completedProof.success ||
            completedProof.identityProofToken == null) {
          throw Exception('Identity verification failed.');
        }

        identityProofToken = completedProof.identityProofToken;
      }

      if (isCheckIn) {
        await attRepo.checkInWithPresenceProof(
          proof.presenceProofToken,
          identityProofToken: identityProofToken,
        );
      } else {
        await attRepo.checkOutWithPresenceProof(
          proof.presenceProofToken,
          identityProofToken: identityProofToken,
        );
      }

      ref.invalidate(currentOpenAttendanceProvider);
      ref.invalidate(myAttendanceHistoryProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCheckIn
                ? 'כניסה למשמרת בוצעה בהצלחה!'
                : 'יציאה ממשמרת בוצעה בהצלחה!',
          ),
          backgroundColor: AppColors.colorSuccess,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _showBiometricOverlay = false;
      });

      // ----------------------------------------------------------------------
      // Uncertain-Result Reconciliation Strategy
      // If network timed out or disconnected, check if mutation committed on DB
      // ----------------------------------------------------------------------
      try {
        final currentStation = ref.read(currentStationProvider);
        if (currentStation != null) {
          final openRecord =
              await attRepo.getMyOpenAttendance(currentStation.id);
          if (isCheckIn && openRecord != null) {
            // Reconciled: Check-in actually succeeded!
            ref.invalidate(currentOpenAttendanceProvider);
            ref.invalidate(myAttendanceHistoryProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('כניסה למשמרת אומתה בהצלחה!'),
                  backgroundColor: AppColors.colorSuccess,
                ),
              );
            }
            return;
          } else if (!isCheckIn && openRecord == null) {
            // Reconciled: Check-out actually succeeded!
            ref.invalidate(currentOpenAttendanceProvider);
            ref.invalidate(myAttendanceHistoryProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('יציאה ממשמרת אומתה בהצלחה!'),
                  backgroundColor: AppColors.colorSuccess,
                ),
              );
            }
            return;
          }
        }
      } catch (_) {
        // Reconciliation failed, proceed with localized error display
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorLocalizer.localize(e, l10n)),
          backgroundColor: AppColors.colorError,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingAttendance = false);
      }
    }
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
      body: Stack(
        children: [
          RefreshIndicator(
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
                    onScanTap: _openScanner,
                    onCheckOutTap: _openScanner,
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
                                padding:
                                    const EdgeInsets.all(AppSpacing.space8),
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
                                      item.shiftName ??
                                          l10n.attendanceWorkShift,
                                      style: typography.bodyStrong.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.colorTextPrimary,
                                      ),
                                    ),
                                    Text(
                                      dateFormat
                                          .format(item.checkInTime.toLocal()),
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text('Error: $err'),
                ),
              ],
            ),
          ),
          if (_showBiometricOverlay)
            CameraLivenessOverlay(
              statusText: _biometricStatus,
              onCancel: () => setState(() => _showBiometricOverlay = false),
            ),
        ],
      ),
    );
  }
}
