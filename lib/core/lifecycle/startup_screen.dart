import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'app_startup_state.dart';
import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_spacing.dart';
import '../design_system/tokens/app_typography.dart';
import '../../l10n/app_localizations.dart';

/// Fullscreen startup view presented during app initialization or fatal setup errors.
class StartupScreen extends ConsumerWidget {
  final VoidCallback? onRetry;

  const StartupScreen({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appStartupStateProvider);
    final l10n = AppLocalizations.of(context);
    const typography = AppTypography();

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space20),
                  decoration: BoxDecoration(
                    color: AppColors.colorSurfaceBrand,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.fuel,
                    size: 48,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: AppSpacing.space24),
                Text(
                  l10n?.appTitle ?? 'YellowShifts',
                  style: typography.displayLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.colorTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space16),
                if (startup.isLoading) ...[
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.colorActionPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  Text(
                    _resolveLoadingMessage(startup.phase, l10n),
                    textAlign: TextAlign.center,
                    style: typography.bodyMedium.copyWith(
                      color: AppColors.colorTextSecondary,
                    ),
                  ),
                ] else if (startup.hasError ||
                    startup.phase ==
                        StartupPhase.authenticatedStationAccessRevoked) ...[
                  const Icon(
                    LucideIcons.alertTriangle,
                    size: 40,
                    color: AppColors.colorStatusDanger,
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  Text(
                    startup.errorMessage ??
                        _resolveErrorMessage(startup.phase, l10n),
                    textAlign: TextAlign.center,
                    style: typography.bodyMedium.copyWith(
                      color: AppColors.colorStatusDanger,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space24),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (onRetry != null) {
                        onRetry!();
                      } else {
                        ref.invalidate(appStartupStateProvider);
                      }
                    },
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: Text(l10n?.startupRetry ?? 'Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.colorSurfaceBrand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space24,
                        vertical: AppSpacing.space12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolveLoadingMessage(StartupPhase phase, AppLocalizations? l10n) {
    switch (phase) {
      case StartupPhase.booting:
        return 'Initializing application environment...';
      case StartupPhase.authLoading:
        return 'Authenticating session...';
      case StartupPhase.authenticatedLoadingStations:
        return 'Loading station memberships...';
      default:
        return l10n?.startupLoading ?? 'Loading...';
    }
  }

  String _resolveErrorMessage(StartupPhase phase, AppLocalizations? l10n) {
    switch (phase) {
      case StartupPhase.clientOutdated:
        return l10n?.appUpdateAvailable ??
            'Application update is required to continue.';
      case StartupPhase.schemaIncompatible:
        return 'Server schema mismatch. Please update the application.';
      case StartupPhase.authenticatedStationAccessRevoked:
        return l10n?.errorMembershipDeactivated ??
            'Station membership access has been revoked.';
      case StartupPhase.configError:
        return 'Invalid environment configuration.';
      default:
        return l10n?.errorGeneric ??
            'An unexpected error occurred during startup.';
    }
  }
}
