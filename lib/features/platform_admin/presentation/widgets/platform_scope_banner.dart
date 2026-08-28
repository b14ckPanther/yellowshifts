import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/permissions/platform_admin_provider.dart';
import '../../../../core/permissions/station_access_context.dart';
import '../../../../features/stations/presentation/active_station_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../platform_admin_providers.dart';

class PlatformScopeBanner extends ConsumerWidget {
  const PlatformScopeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final access = ref.watch(stationAccessContextProvider);
    if (!access.isOperatingAsPlatformAdmin) return const SizedBox.shrink();

    const typography = AppTypography();
    final operatingId = access.operatingStationId ??
        ref.watch(platformOperatingStationIdProvider);
    final stations = ref.watch(platformStationsProvider).value ?? const [];
    String stationName = access.activeMembership?.station?.name ?? '';
    if (stationName.isEmpty && operatingId != null) {
      for (final station in stations) {
        if (station.id == operatingId) {
          stationName = station.name;
          break;
        }
      }
    }
    if (stationName.isEmpty) stationName = operatingId ?? '';

    return Material(
      color: AppColors.colorSurfaceBrandSubtle,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space16,
            vertical: AppSpacing.space8,
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.shield,
                  size: 16.0, color: AppColors.colorTextBrand),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  l10n.platformOperatingBanner(stationName),
                  style: typography.caption.copyWith(
                    color: AppColors.colorTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(platformOperatingStationIdProvider.notifier).state =
                      null;
                  ref
                      .read(activeStationIdProvider.notifier)
                      .exitOperatingStation();
                  context.go('/platform');
                },
                child: Text(l10n.platformReturnToPlatform),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
