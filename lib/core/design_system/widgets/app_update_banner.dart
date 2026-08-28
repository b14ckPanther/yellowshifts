import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import '../../../l10n/app_localizations.dart';

final appUpdateAvailableProvider = StateProvider<bool>((ref) => false);

/// Non-intrusive banner notifying users when a new frontend bundle is deployed.
class AppUpdateBanner extends ConsumerStatefulWidget {
  const AppUpdateBanner({super.key});

  @override
  ConsumerState<AppUpdateBanner> createState() => _AppUpdateBannerState();
}

class _AppUpdateBannerState extends ConsumerState<AppUpdateBanner> {
  bool _dismissed = false;

  void _reloadApp() {
    if (kIsWeb) {
      // In Flutter Web, reload the window
      // ignore: avoid_dynamic_calls
      // window.location.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpdateAvailable = ref.watch(appUpdateAvailableProvider);
    if (!isUpdateAvailable || _dismissed) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    const typography = AppTypography();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space8,
      ),
      color: AppColors.colorSurfaceBrandAccent,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(
              LucideIcons.sparkles,
              size: 16.0,
              color: AppColors.colorActionPrimary,
            ),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: Text(
                l10n?.appUpdateAvailable ??
                    'A new version of YellowShifts is available.',
                style: typography.bodySmall.copyWith(
                  color: AppColors.colorTextPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            TextButton(
              onPressed: () {
                setState(() => _dismissed = true);
              },
              child: Text(
                l10n?.appUpdateLater ?? 'Later',
                style: typography.labelSmall.copyWith(
                  color: AppColors.colorTextSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space4),
            ElevatedButton(
              onPressed: _reloadApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.colorActionPrimary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                  vertical: AppSpacing.space4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n?.appUpdateReloadNow ?? 'Reload Now',
                style: typography.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
