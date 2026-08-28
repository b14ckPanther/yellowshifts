import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_page_header.dart';
import '../../../core/errors/error_localizer.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/models/identity_profile.dart';
import 'providers/identity_providers.dart';
import 'widgets/camera_liveness_overlay.dart';

class EmployeeIdentityVerificationScreen extends ConsumerStatefulWidget {
  const EmployeeIdentityVerificationScreen({super.key});

  @override
  ConsumerState<EmployeeIdentityVerificationScreen> createState() =>
      _EmployeeIdentityVerificationScreenState();
}

class _EmployeeIdentityVerificationScreenState
    extends ConsumerState<EmployeeIdentityVerificationScreen> {
  bool _consentGiven = false;
  bool _showCameraOverlay = false;
  String _overlayStatusText = 'Aligning face...';

  Future<void> _handleEnroll(AppLocalizations l10n) async {
    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.identityAcceptConsentRequired),
          backgroundColor: AppColors.colorError,
        ),
      );
      return;
    }

    setState(() {
      _showCameraOverlay = true;
      _overlayStatusText = 'Analyzing face liveness...';
    });

    final success = await ref
        .read(identityEnrollmentControllerProvider.notifier)
        .enroll(noticeVersion: 'v1.0');

    if (!mounted) return;

    setState(() {
      _showCameraOverlay = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.identityEnrolledSuccess),
          backgroundColor: AppColors.colorSuccess,
        ),
      );
    } else {
      final error = ref.read(identityEnrollmentControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error != null
                ? ErrorLocalizer.localize(error, l10n)
                : l10n.identityEnrollmentFailed,
          ),
          backgroundColor: AppColors.colorError,
        ),
      );
    }
  }

  Future<void> _handleRevoke(AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.identityRevokeConfirmTitle),
        content: Text(l10n.identityRevokeConfirmDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.colorActionDestructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.identityRevokeButton,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await ref
        .read(identityEnrollmentControllerProvider.notifier)
        .revoke(reason: 'Employee self-revocation');

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.identityRevokedSuccess),
          backgroundColor: AppColors.colorTextSecondary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(myIdentityProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AppPageHeader(
                  title: l10n.identityAssuranceTitle,
                  subtitle: l10n.identityAssuranceSubtitle,
                ),
                Expanded(
                  child: profileAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.colorBrandYellow),
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.space24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: AppColors.colorError),
                            const SizedBox(height: AppSpacing.space16),
                            Text(
                              ErrorLocalizer.localize(err, l10n),
                              textAlign: TextAlign.center,
                              style: typography.bodyLarge,
                            ),
                            const SizedBox(height: AppSpacing.space16),
                            AppButton(
                              label: l10n.startupRetry,
                              onPressed: () =>
                                  ref.refresh(myIdentityProfileProvider),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (profile) => _buildContent(context, profile, l10n),
                  ),
                ),
              ],
            ),
            if (_showCameraOverlay)
              CameraLivenessOverlay(
                statusText: _overlayStatusText,
                onCancel: () => setState(() => _showCameraOverlay = false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, IdentityProfile profile, AppLocalizations l10n) {
    const typography = AppTypography();
    final isEnrolled = profile.status == IdentityProfileStatus.active;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Status Header Card
          _buildStatusCard(profile, l10n),
          const SizedBox(height: AppSpacing.space16),

          // Privacy & Zero-Data Architecture Notice
          _buildPrivacyNoticeCard(l10n),
          const SizedBox(height: AppSpacing.space20),

          // Action Section
          if (!isEnrolled) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    value: _consentGiven,
                    onChanged: (val) =>
                        setState(() => _consentGiven = val ?? false),
                    title: Text(
                      l10n.identityConsentText,
                      style: typography.bodyMedium,
                    ),
                    subtitle: Text(
                      l10n.identityConsentFooter('v1.0'),
                      style: typography.caption,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.colorBrandYellow,
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  AppButton(
                    label: l10n.identityEnrollButton,
                    icon: LucideIcons.scanFace,
                    isFullWidth: true,
                    onPressed: _consentGiven ? () => _handleEnroll(l10n) : null,
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.space16),
              decoration: BoxDecoration(
                color: AppColors.colorStatusSuccessSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.colorStatusSuccess),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.circleCheck,
                      color: AppColors.colorStatusSuccess, size: 28),
                  const SizedBox(width: AppSpacing.space12),
                  Expanded(
                    child: Text(
                      l10n.identityStatusActive,
                      style: typography.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space24),
            AppButton(
              label: l10n.identityRevokeButton,
              variant: AppButtonVariant.destructive,
              icon: LucideIcons.trash2,
              isFullWidth: true,
              onPressed: () => _handleRevoke(l10n),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(IdentityProfile profile, AppLocalizations l10n) {
    const typography = AppTypography();
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (profile.status) {
      case IdentityProfileStatus.active:
        statusColor = AppColors.colorStatusSuccess;
        statusText = l10n.identityStatusActive;
        statusIcon = LucideIcons.shieldCheck;
        break;
      case IdentityProfileStatus.revoked:
        statusColor = AppColors.colorStatusDanger;
        statusText = l10n.identityStatusRevoked;
        statusIcon = LucideIcons.shieldAlert;
        break;
      case IdentityProfileStatus.pending:
        statusColor = AppColors.colorStatusWarning;
        statusText = l10n.identityStatusPending;
        statusIcon = LucideIcons.hourglass;
        break;
      case IdentityProfileStatus.notEnrolled:
      default:
        statusColor = AppColors.colorTextSecondary;
        statusText = l10n.identityStatusNotEnrolled;
        statusIcon = LucideIcons.scanFace;
        break;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.identityStatusLabel, style: typography.caption),
                    Text(statusText,
                        style: typography.titleMedium
                            .copyWith(color: statusColor)),
                  ],
                ),
              ),
            ],
          ),
          if (profile.enrolledAt != null) ...[
            const Divider(
                height: AppSpacing.space24, color: AppColors.colorBorderSubtle),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.identityStatusActive, style: typography.caption),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(profile.enrolledAt!),
                  style: typography.bodyMedium,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacyNoticeCard(AppLocalizations l10n) {
    const typography = AppTypography();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.colorSurfaceBrandSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.colorSurfaceBrand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shield,
                  color: AppColors.colorTextPrimary, size: 20),
              const SizedBox(width: AppSpacing.space8),
              Text(
                l10n.identityPrivacyTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.colorTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            '• ${l10n.identityPrivacyBullet1}\n'
            '• ${l10n.identityPrivacyBullet2}\n'
            '• ${l10n.identityPrivacyBullet3}',
            style: typography.caption.copyWith(
              color: AppColors.colorTextPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
