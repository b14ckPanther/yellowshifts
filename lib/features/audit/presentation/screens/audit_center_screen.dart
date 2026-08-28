import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_surface.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../controllers/audit_center_controller.dart';
import '../../domain/models/audit_log_entry.dart';

class AuditCenterScreen extends ConsumerStatefulWidget {
  const AuditCenterScreen({super.key});

  @override
  ConsumerState<AuditCenterScreen> createState() => _AuditCenterScreenState();
}

class _AuditCenterScreenState extends ConsumerState<AuditCenterScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch(String val) {
    ref.read(auditCenterControllerProvider.notifier).setSearchQuery(val.trim());
  }

  String _getCategoryLabel(String cat, AppLocalizations l10n) {
    switch (cat) {
      case 'ALL':
        return l10n.auditFilterAll;
      case 'MEMBERSHIP':
        return l10n.auditFilterMemberships;
      case 'SCHEDULE':
        return l10n.auditFilterSchedules;
      case 'ATTENDANCE':
        return l10n.auditFilterAttendance;
      case 'KIOSK':
        return l10n.auditFilterKiosks;
      case 'STATION':
        return l10n.auditFilterStation;
      case 'EXPORT':
        return l10n.auditFilterExports;
      case 'AVAILABILITY':
        return l10n.auditFilterAvailability;
      default:
        return cat;
    }
  }

  Color _getActionColor(String action) {
    if (action.contains('DELETE') ||
        action.contains('REVOKE') ||
        action.contains('REMOVE') ||
        action.contains('DEACTIVATE')) {
      return AppColors.colorStatusDanger;
    }
    if (action.contains('CREATE') ||
        action.contains('ASSIGN') ||
        action.contains('PUBLISH') ||
        action.contains('VERIFY')) {
      return AppColors.colorStatusSuccess;
    }
    if (action.contains('UPDATE') ||
        action.contains('RESET') ||
        action.contains('EDIT') ||
        action.contains('CORRECT')) {
      return AppColors.colorStatusInfo;
    }
    return AppColors.colorTextMuted;
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final l10n = AppLocalizations.of(context)!;
    final auditState = ref.watch(auditCenterControllerProvider);
    const categories = [
      'ALL',
      'MEMBERSHIP',
      'SCHEDULE',
      'ATTENDANCE',
      'KIOSK',
      'STATION',
      'EXPORT',
      'AVAILABILITY',
    ];

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(auditCenterControllerProvider.notifier).loadLogs(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.insetAll16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPageHeader(
                      title: l10n.auditCenterTitle,
                      subtitle: l10n.auditCenterSubtitle,
                    ),
                    const SizedBox(height: AppSpacing.space16),

                    // Search and Filter Bar
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: _searchController,
                            hint: l10n.auditSearchPlaceholder,
                            prefixIcon: const Icon(LucideIcons.search,
                                size: 16, color: AppColors.colorTextMuted),
                            onChanged: _handleSearch,
                          ),
                          const SizedBox(height: AppSpacing.space12),

                          // Category Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: categories.map((cat) {
                                final isSelected =
                                    auditState.selectedCategory == cat;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      right: AppSpacing.space8),
                                  child: ChoiceChip(
                                    label: Text(_getCategoryLabel(cat, l10n)),
                                    selected: isSelected,
                                    onSelected: (val) {
                                      if (val) {
                                        ref
                                            .read(auditCenterControllerProvider
                                                .notifier)
                                            .setCategory(cat);
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space16),

                    // Audit Logs List View
                    if (auditState.isLoading)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: AppSpacing.space32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (auditState.items.isEmpty)
                      AppCard(
                        child: Padding(
                          padding: AppSpacing.insetAll32,
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(LucideIcons.fileSearch,
                                    size: 48, color: AppColors.colorTextMuted),
                                const SizedBox(height: AppSpacing.space12),
                                Text(
                                  l10n.auditEmptyLogs,
                                  style: typography.bodyMedium.copyWith(
                                      color: AppColors.colorTextMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: auditState.items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.space8),
                        itemBuilder: (context, index) {
                          final item = auditState.items[index];
                          return _buildAuditLogCard(
                              item, dateFormat, typography, l10n);
                        },
                      ),
                      const SizedBox(height: AppSpacing.space16),

                      // Pagination Controls
                      _buildPaginationFooter(auditState, typography, l10n),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuditLogCard(
    AuditLogEntry item,
    DateFormat dateFormat,
    AppTypography typography,
    AppLocalizations l10n,
  ) {
    final actionColor = _getActionColor(item.action);

    return AppCard(
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(AppSpacing.space8),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.12),
              borderRadius: AppRadius.borderSm,
            ),
            child: Icon(LucideIcons.history, color: actionColor, size: 20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space6, vertical: 2),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.borderSm,
                  border: Border.all(color: actionColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  item.action,
                  style: typography.caption.copyWith(
                    color: actionColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  '${item.actorName} (${item.actorEmail})',
                  style: typography.bodyMedium.copyWith(
                    color: AppColors.colorTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space4),
            child: Text(
              '${dateFormat.format(item.createdAt)} • ${l10n.auditTarget}: ${item.targetType}${item.targetId != null ? " (${item.targetId})" : ""}',
              style:
                  typography.caption.copyWith(color: AppColors.colorTextMuted),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.auditMetadataTitle,
                    style: typography.caption.copyWith(
                      color: AppColors.colorTextMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space6),
                  Container(
                    padding: AppSpacing.insetAll12,
                    decoration: BoxDecoration(
                      color: AppColors.colorSurfaceBase,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: AppColors.colorBorderSubtle),
                    ),
                    child: SelectableText(
                      item.metadata.isEmpty
                          ? '{}'
                          : const JsonEncoder.withIndent('  ')
                              .convert(item.metadata),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.colorTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(
      AuditCenterState state, AppTypography typography, AppLocalizations l10n) {
    final notifier = ref.read(auditCenterControllerProvider.notifier);
    final currentPage = state.page + 1;
    final totalPages = state.totalPages > 0 ? state.totalPages : 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.auditPageInfo(currentPage, totalPages, state.totalCount),
          style: typography.caption.copyWith(color: AppColors.colorTextMuted),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: state.hasPreviousPage ? notifier.previousPage : null,
            ),
            IconButton(
              icon: const Icon(LucideIcons.chevronRight),
              onPressed: state.hasNextPage ? notifier.nextPage : null,
            ),
          ],
        ),
      ],
    );
  }
}
