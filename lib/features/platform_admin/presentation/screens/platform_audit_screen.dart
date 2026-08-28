import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_surface.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/errors/error_localizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../platform_admin_providers.dart';

class PlatformAuditScreen extends ConsumerWidget {
  const PlatformAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    const typography = AppTypography();
    final page = ref.watch(platformAuditProvider);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: l10n.platformAuditTitle,
              subtitle: l10n.platformAuditSubtitle,
            ),
            Padding(
              padding: AppSpacing.insetHorizontal16,
              child: AppTextField(
                label: l10n.platformAuditFilterAction,
                onChanged: (value) {
                  ref.read(platformAuditQueryProvider.notifier).state =
                      ref.read(platformAuditQueryProvider).copyWith(
                            action: value.trim().isEmpty ? null : value.trim(),
                            clearAction: value.trim().isEmpty,
                            offset: 0,
                          );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            Expanded(
              child: page.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(ErrorLocalizer.localize(e, l10n))),
                data: (result) {
                  return ListView.separated(
                    padding: AppSpacing.insetHorizontal16,
                    itemCount: result.entries.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.space8),
                    itemBuilder: (context, i) {
                      final e = result.entries[i];
                      return AppSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.action, style: typography.bodyStrong),
                            const SizedBox(height: 4),
                            Text(
                              '${e.stationName ?? l10n.platformAdminTitle} · ${e.actorName}',
                              style: typography.caption.copyWith(
                                  color: AppColors.colorTextSecondary),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
