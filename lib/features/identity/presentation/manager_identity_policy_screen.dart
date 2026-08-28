import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/components/app_surface.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_page_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../stations/presentation/active_station_provider.dart';
import '../domain/models/identity_policy.dart';
import '../domain/models/identity_profile.dart';
import 'providers/identity_providers.dart';

class ManagerIdentityPolicyScreen extends ConsumerStatefulWidget {
  const ManagerIdentityPolicyScreen({super.key});

  @override
  ConsumerState<ManagerIdentityPolicyScreen> createState() =>
      _ManagerIdentityPolicyScreenState();
}

class _ManagerIdentityPolicyScreenState
    extends ConsumerState<ManagerIdentityPolicyScreen> {
  IdentityVerificationMode? _selectedMode;

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final currentStation = ref.watch(currentStationProvider);

    if (currentStation == null) {
      return Scaffold(
        backgroundColor: AppColors.colorSurfaceBase,
        appBar: AppBar(title: Text(l10n.settingsBiometricPolicy)),
        body: Center(
          child: Text(l10n.stationSelectTitle, style: typography.bodyMedium),
        ),
      );
    }

    final teamStatusAsync =
        ref.watch(stationTeamIdentityProvider(currentStation.id));
    final currentPolicyMode = IdentityVerificationMode.fromString(
        currentStation.identityVerificationMode);

    final effectiveMode = _selectedMode ?? currentPolicyMode;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: l10n.settingsBiometricPolicy,
              subtitle: l10n.settingsBiometricPolicySubtitle,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Station Header Card
                    AppCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.space8),
                            decoration: BoxDecoration(
                              color: AppColors.colorSurfaceBrandSubtle,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.store,
                                color: AppColors.colorTextPrimary),
                          ),
                          const SizedBox(width: AppSpacing.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(currentStation.name,
                                    style: typography.titleMedium),
                                Text(
                                    '${l10n.settingsStationCode}: ${currentStation.code}',
                                    style: typography.caption),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space20),

                    // Policy Selection Card
                    Text(l10n.settingsBiometricPolicy,
                        style: typography.titleMedium),
                    const SizedBox(height: AppSpacing.space12),
                    _buildPolicyOption(
                      mode: IdentityVerificationMode.disabled,
                      title: l10n.policyOptionDisabledTitle,
                      subtitle: l10n.policyOptionDisabledSubtitle,
                      current: effectiveMode,
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    _buildPolicyOption(
                      mode: IdentityVerificationMode.checkInOnly,
                      title: l10n.policyOptionCheckInOnlyTitle,
                      subtitle: l10n.policyOptionCheckInOnlySubtitle,
                      current: effectiveMode,
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    _buildPolicyOption(
                      mode: IdentityVerificationMode.checkInAndCheckOut,
                      title: l10n.policyOptionStrictTitle,
                      subtitle: l10n.policyOptionStrictSubtitle,
                      current: effectiveMode,
                    ),

                    if (effectiveMode != currentPolicyMode) ...[
                      const SizedBox(height: AppSpacing.space20),
                      AppButton(
                        label: l10n.policyApplyAction,
                        isFullWidth: true,
                        onPressed: () =>
                            _applyPolicy(currentStation.id, effectiveMode),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.space24),

                    // Team Readiness Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.policyTeamReadinessTitle,
                            style: typography.titleMedium),
                        IconButton(
                          icon: const Icon(LucideIcons.refreshCw, size: 18),
                          onPressed: () => ref.refresh(
                              stationTeamIdentityProvider(currentStation.id)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space8),

                    teamStatusAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.space24),
                          child: CircularProgressIndicator(
                              color: AppColors.colorBrandYellow),
                        ),
                      ),
                      error: (err, _) => Center(
                        child: Text('Error: $err', style: typography.caption),
                      ),
                      data: (roster) => _buildTeamRoster(roster, l10n),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyOption({
    required IdentityVerificationMode mode,
    required String title,
    required String subtitle,
    required IdentityVerificationMode current,
  }) {
    const typography = AppTypography();
    final isSelected = current == mode;

    return InkWell(
      onTap: () => setState(() => _selectedMode = mode),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.colorSurfaceBrandSubtle
              : AppColors.colorSurfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.colorSurfaceBrand
                : AppColors.colorBorderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.colorBrandYellow
                      : AppColors.colorBorderMedium,
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: typography.bodyStrong),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: typography.caption
                          .copyWith(color: AppColors.colorTextMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRoster(
      List<TeamMemberIdentityStatus> roster, AppLocalizations l10n) {
    const typography = AppTypography();

    if (roster.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Center(
          child: Text(l10n.policyNoMembersRegistered,
              style: typography.bodyMedium),
        ),
      );
    }

    final enrolledCount = roster
        .where((m) => m.identityStatus == IdentityProfileStatus.active)
        .length;
    final readinessPercent = (enrolledCount / roster.length * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Readiness summary progress bar
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$enrolledCount / ${roster.length} Staff Enrolled',
                    style: typography.bodyMedium,
                  ),
                  Text(
                    '$readinessPercent%',
                    style: typography.titleMedium.copyWith(
                      color: readinessPercent >= 80
                          ? AppColors.colorStatusSuccess
                          : AppColors.colorStatusWarning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: roster.isEmpty ? 0 : enrolledCount / roster.length,
                  backgroundColor: AppColors.colorBorderSubtle,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    readinessPercent >= 80
                        ? AppColors.colorStatusSuccess
                        : AppColors.colorSurfaceBrand,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space16),

        // Member list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: roster.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.space8),
          itemBuilder: (context, index) {
            final member = roster[index];
            final isEnrolled =
                member.identityStatus == IdentityProfileStatus.active;

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space16, vertical: AppSpacing.space12),
              decoration: BoxDecoration(
                color: AppColors.colorSurfaceRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.colorBorderSubtle),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isEnrolled
                        ? AppColors.colorStatusSuccessSubtle
                        : AppColors.colorBorderSubtle,
                    child: Icon(
                      isEnrolled ? LucideIcons.shieldCheck : LucideIcons.user,
                      color: isEnrolled
                          ? AppColors.colorStatusSuccess
                          : AppColors.colorTextMuted,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${member.firstName} ${member.lastName}',
                          style: typography.bodyStrong,
                        ),
                        Text(
                          member.employeeCode != null
                              ? 'Code: ${member.employeeCode}'
                              : member.role,
                          style: typography.caption,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isEnrolled
                          ? AppColors.colorStatusSuccessSubtle
                          : AppColors.colorBorderSubtle.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isEnrolled ? 'Enrolled' : 'Not Enrolled',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isEnrolled
                            ? AppColors.colorStatusSuccess
                            : AppColors.colorTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _applyPolicy(
      String stationId, IdentityVerificationMode mode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Verification Policy?'),
        content: Text(
          'Are you sure you want to change this station policy to ${mode.toDbValue()}? Employees will be bound to this policy immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.colorBrandYellow),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Change',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await ref
        .read(stationPolicyControllerProvider.notifier)
        .updatePolicy(stationId: stationId, mode: mode);

    if (!mounted) return;

    if (success) {
      ref.invalidate(currentStationProvider);
      ref.invalidate(stationsProvider);
      setState(() => _selectedMode = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Station identity policy updated successfully.'),
          backgroundColor: AppColors.colorSuccess,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update station policy.'),
          backgroundColor: AppColors.colorError,
        ),
      );
    }
  }
}
