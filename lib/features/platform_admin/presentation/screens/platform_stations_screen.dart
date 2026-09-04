import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_status_badge.dart';
import '../../../../core/design_system/components/app_surface.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../core/permissions/platform_admin_provider.dart';
import '../../../../features/stations/presentation/active_station_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../domain/platform_station_summary.dart';
import '../platform_admin_providers.dart';

class PlatformStationsScreen extends ConsumerWidget {
  const PlatformStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(platformStationsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final useCards = width < 768;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: l10n.platformStationsTitle,
              subtitle: l10n.platformStationsSubtitle,
              actions: [
                AppButton(
                  label: l10n.platformCreateStation,
                  icon: LucideIcons.plus,
                  onPressed: () => context.go('/platform/stations/new'),
                ),
              ],
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(ErrorLocalizer.localize(e, l10n))),
                data: (stations) {
                  if (stations.isEmpty) {
                    return AppEmptyState(
                      title: l10n.platformEmptyStations,
                      description: l10n.platformCreateStationSubtitle,
                      icon: LucideIcons.building2,
                    );
                  }
                  if (useCards) {
                    return ListView.separated(
                      padding: AppSpacing.insetHorizontal16,
                      itemCount: stations.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.space12),
                      itemBuilder: (context, i) =>
                          _StationCard(station: stations[i]),
                    );
                  }
                  return SingleChildScrollView(
                    padding: AppSpacing.insetHorizontal16,
                    child: AppSurface(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(l10n.platformStationName)),
                            DataColumn(label: Text(l10n.platformStationCode)),
                            DataColumn(label: Text(l10n.platformStationStatus)),
                            DataColumn(label: Text(l10n.platformColEmployees)),
                            DataColumn(label: Text(l10n.platformColManagers)),
                            DataColumn(
                                label: Text(l10n.platformColShiftManagers)),
                            DataColumn(label: Text(l10n.platformColNfcTags)),
                            const DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final station in stations)
                              DataRow(cells: [
                                DataCell(Text(station.name)),
                                DataCell(Text(station.code)),
                                DataCell(_statusBadge(station, l10n)),
                                DataCell(Text('${station.activeMembers}')),
                                DataCell(Text('${station.adminCount}')),
                                DataCell(Text('${station.shiftManagerCount}')),
                                DataCell(Text(
                                    '${station.nfcTagsActive}/${station.nfcTagsTotal}')),
                                DataCell(
                                    _rowActions(context, ref, station, l10n)),
                              ]),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(PlatformStationSummary station, AppLocalizations l10n) {
    return AppStatusBadge(
      label: station.isActive
          ? l10n.stationActiveBadge
          : l10n.stationInactiveBadge,
      variant:
          station.isActive ? AppBadgeVariant.success : AppBadgeVariant.neutral,
    );
  }
}

class _StationCard extends ConsumerWidget {
  final PlatformStationSummary station;
  const _StationCard({required this.station});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    const typography = AppTypography();
    return AppSurface(
      child: Padding(
        padding: AppSpacing.insetAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(station.name,
                      style: typography.bodyStrong
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
                AppStatusBadge(
                  label: station.isActive
                      ? l10n.stationActiveBadge
                      : l10n.stationInactiveBadge,
                  variant: station.isActive
                      ? AppBadgeVariant.success
                      : AppBadgeVariant.neutral,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(station.code, style: typography.caption),
            const SizedBox(height: AppSpacing.space12),
            Text(
              '${l10n.platformColEmployees}: ${station.activeMembers} · ${l10n.platformColManagers}: ${station.adminCount} · ${l10n.platformColNfcTags}: ${station.nfcTagsActive}/${station.nfcTagsTotal}',
              style: typography.caption
                  .copyWith(color: AppColors.colorTextSecondary),
            ),
            const SizedBox(height: AppSpacing.space12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  label: l10n.platformOpenStation,
                  size: AppButtonSize.small,
                  onPressed: () => _openStation(context, ref, station),
                ),
                AppButton(
                  label: l10n.platformStationManagers,
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.outline,
                  onPressed: () =>
                      context.go('/platform/stations/${station.id}/managers'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _rowActions(
  BuildContext context,
  WidgetRef ref,
  PlatformStationSummary station,
  AppLocalizations l10n,
) {
  return Row(
    children: [
      TextButton(
        onPressed: () => _openStation(context, ref, station),
        child: Text(l10n.platformOpenStation),
      ),
      TextButton(
        onPressed: () =>
            context.go('/platform/stations/${station.id}/managers'),
        child: Text(l10n.platformStationManagers),
      ),
    ],
  );
}

void _openStation(
  BuildContext context,
  WidgetRef ref,
  PlatformStationSummary station,
) {
  ref.read(platformOperatingStationIdProvider.notifier).state = station.id;
  ref.read(activeStationIdProvider.notifier).operateStation(station.id);
  context.go('/dashboard');
}
