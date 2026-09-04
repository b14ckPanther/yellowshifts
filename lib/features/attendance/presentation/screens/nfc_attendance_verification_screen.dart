import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/auth/auth_state_provider.dart';
import '../../../../core/design_system/components/app_brand_mark.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/attendance_providers.dart';

enum NfcVerificationStatus {
  verifying,
  processing,
  success,
  error,
}

class NfcAttendanceVerificationScreen extends ConsumerStatefulWidget {
  final String token;

  const NfcAttendanceVerificationScreen({
    super.key,
    required this.token,
  });

  @override
  ConsumerState<NfcAttendanceVerificationScreen> createState() =>
      _NfcAttendanceVerificationScreenState();
}

class _NfcAttendanceVerificationScreenState
    extends ConsumerState<NfcAttendanceVerificationScreen>
    with SingleTickerProviderStateMixin {
  NfcVerificationStatus _status = NfcVerificationStatus.verifying;
  String? _errorMessage;
  Map<String, dynamic>? _attendanceResult;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processNfcPunch();
    });
  }

  @override
  void dispose() {
    _pulseController.stop();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _processNfcPunch() async {
    if (!mounted) return;

    _pulseController.repeat(reverse: true);
    setState(() {
      _status = NfcVerificationStatus.verifying;
      _errorMessage = null;
    });

    try {
      final attRepo = ref.read(attendanceRepositoryProvider);
      final result = await attRepo.nfcProcessAttendance(token: widget.token);

      if (!mounted) return;

      _pulseController.stop();
      setState(() {
        _status = NfcVerificationStatus.success;
        _attendanceResult = result;
      });

      // Invalidate attendance providers to refresh global state
      ref.invalidate(currentOpenAttendanceProvider);
      ref.invalidate(myAttendanceHistoryProvider);
    } catch (e) {
      if (!mounted) return;
      _pulseController.stop();
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _status = NfcVerificationStatus.error;
        _errorMessage = ErrorLocalizer.localize(e, l10n);
      });
    }
  }

  String _formatServerTime(String? isoString) {
    if (isoString == null) {
      return DateFormat('HH:mm:ss').format(DateTime.now());
    }
    try {
      final parsed = DateTime.parse(isoString).toLocal();
      return DateFormat('HH:mm:ss • dd/MM/yyyy').format(parsed);
    } catch (_) {
      return isoString;
    }
  }

  String _formatDuration(int? minutes, AppLocalizations l10n) {
    if (minutes == null || minutes <= 0) return '1 min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return '$hours hrs $mins mins';
    } else if (hours > 0) {
      return '$hours hrs';
    } else {
      return '$mins mins';
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(currentAuthUserProvider);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space24,
              vertical: AppSpacing.space32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header
                  Center(
                    child: Hero(
                      tag: 'app_brand_mark',
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.space12),
                        decoration: BoxDecoration(
                          color: AppColors.colorSurfaceRaised,
                          borderRadius:
                              BorderRadius.circular(AppRadius.radiusLg),
                          border:
                              Border.all(color: AppColors.colorBorderSubtle),
                        ),
                        child: const AppBrandMark(size: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space24),

                  // Card Content based on State
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.space32),
                    decoration: BoxDecoration(
                      color: AppColors.colorSurfaceRaised,
                      borderRadius: BorderRadius.circular(AppRadius.radiusXl),
                      border: Border.all(color: AppColors.colorBorderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _buildStateContent(typography, l10n, user?.email),
                  ),

                  const SizedBox(height: AppSpacing.space24),

                  // Bottom Navigation Actions
                  if (_status == NfcVerificationStatus.success ||
                      _status == NfcVerificationStatus.error) ...[
                    AppButton(
                      label: l10n.nfcReturnToDashboard,
                      variant: AppButtonVariant.primary,
                      icon: LucideIcons.layoutDashboard,
                      onPressed: () => context.go('/dashboard'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateContent(
    AppTypography typography,
    AppLocalizations l10n,
    String? userEmail,
  ) {
    switch (_status) {
      case NfcVerificationStatus.verifying:
      case NfcVerificationStatus.processing:
        return Column(
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.colorSurfaceBrandSubtle,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.radio,
                    size: 40,
                    color: AppColors.colorTextPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space24),
            Text(
              _status == NfcVerificationStatus.verifying
                  ? l10n.nfcVerifyingStation
                  : l10n.nfcProcessingPunch,
              textAlign: TextAlign.center,
              style: typography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.colorTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            if (userEmail != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                  vertical: AppSpacing.space6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.colorSurfaceBase,
                  borderRadius: BorderRadius.circular(AppRadius.radiusPill),
                  border: Border.all(color: AppColors.colorBorderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.userCheck,
                        size: 14, color: AppColors.colorSuccess),
                    const SizedBox(width: AppSpacing.space6),
                    Text(
                      userEmail,
                      style: typography.bodySmall.copyWith(
                        color: AppColors.colorTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.space24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        );

      case NfcVerificationStatus.success:
        final action = _attendanceResult?['action'] as String? ?? 'CHECK_IN';
        final isCheckIn = action == 'CHECK_IN';
        final stationName = _attendanceResult?['station_name'] as String? ??
            _attendanceResult?['station_code'] as String? ??
            'Station';
        final shiftName = _attendanceResult?['shift_name'] as String?;
        final timeStr = _attendanceResult?['check_out_time'] as String? ??
            _attendanceResult?['check_in_time'] as String? ??
            _attendanceResult?['server_timestamp'] as String?;
        final workedMinutes = _attendanceResult?['worked_minutes'] as int?;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.colorSuccess.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.circleCheck,
                  size: 48,
                  color: AppColors.colorSuccess,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space20),
            Text(
              isCheckIn
                  ? l10n.nfcCheckInSuccessTitle
                  : l10n.nfcCheckOutSuccessTitle,
              textAlign: TextAlign.center,
              style: typography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.colorTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            Text(
              stationName,
              textAlign: TextAlign.center,
              style: typography.titleMedium.copyWith(
                color: AppColors.colorTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (shiftName != null && shiftName.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.space4),
              Text(
                shiftName,
                textAlign: TextAlign.center,
                style: typography.bodyMedium.copyWith(
                  color: AppColors.colorTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.space24),
            const Divider(),
            const SizedBox(height: AppSpacing.space16),

            // Metadata info rows
            _buildMetaRow(
              icon: LucideIcons.clock,
              label: l10n.nfcTimeConfirmedLabel,
              value: _formatServerTime(timeStr),
              typography: typography,
            ),
            if (!isCheckIn && workedMinutes != null) ...[
              const SizedBox(height: AppSpacing.space12),
              _buildMetaRow(
                icon: LucideIcons.timer,
                label: l10n.nfcWorkedDurationLabel,
                value: _formatDuration(workedMinutes, l10n),
                typography: typography,
              ),
            ],
          ],
        );

      case NfcVerificationStatus.error:
        return Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.colorError.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.circleAlert,
                  size: 44,
                  color: AppColors.colorError,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space20),
            Text(
              l10n.nfcVerificationFailed,
              textAlign: TextAlign.center,
              style: typography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.colorError,
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            Text(
              _errorMessage ?? l10n.errorGeneric,
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(
                color: AppColors.colorTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _processNfcPunch,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: Text(l10n.commonRetry),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.space14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String label,
    required String value,
    required AppTypography typography,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.colorTextSecondary),
        const SizedBox(width: AppSpacing.space8),
        Expanded(
          child: Text(
            label,
            style: typography.bodyMedium.copyWith(
              color: AppColors.colorTextSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space8),
        Text(
          value,
          style: typography.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.colorTextPrimary,
          ),
        ),
      ],
    );
  }
}
