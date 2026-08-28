import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../core/design_system/tokens/app_typography.dart';
import '../../../core/design_system/components/app_avatar.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_page_header.dart';
import '../../../core/design_system/components/app_status_badge.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/permissions/station_access_context.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../stations/domain/station_membership.dart';
import '../domain/employee_details.dart';
import 'employee_directory_provider.dart';
import 'widgets/create_employee_dialog.dart';
import 'widgets/employee_detail_inspector.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDetailSheet(BuildContext context, EmployeeDetails employee) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.radiusLg)),
          child: EmployeeDetailInspector(
            employee: employee,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final access = ref.watch(stationAccessContextProvider);
    final state = ref.watch(employeeDirectoryProvider);
    final notifier = ref.read(employeeDirectoryProvider.notifier);
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 900.0;
    final isMedium = width >= 900.0 && width <= 1200.0;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            AppPageHeader(
              title: l10n.employeesTitle,
              subtitle: l10n.employeesSubtitle,
              actions: [
                if (access.canCreateEmployees)
                  AppButton(
                    label: l10n.employeesAddButton,
                    icon: LucideIcons.userPlus,
                    size:
                        isCompact ? AppButtonSize.small : AppButtonSize.medium,
                    onPressed: () => CreateEmployeeDialog.show(context),
                  ),
              ],
            ),

            // Search & Filter Controls
            Padding(
              padding: AppSpacing.insetHorizontal16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          hint: l10n.employeesSearchHint,
                          controller: _searchController,
                          onChanged: notifier.onSearchChanged,
                          prefixIcon: const Icon(LucideIcons.search,
                              size: 16.0, color: AppColors.colorTextMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: l10n.employeesFilterAllRoles,
                          isSelected: state.selectedRole == null,
                          onTap: () => notifier.setRoleFilter(null),
                        ),
                        const SizedBox(width: AppSpacing.space8),
                        _buildFilterChip(
                          label: l10n.roleAdmin,
                          isSelected: state.selectedRole == StationRole.admin,
                          onTap: () =>
                              notifier.setRoleFilter(StationRole.admin),
                        ),
                        const SizedBox(width: AppSpacing.space8),
                        _buildFilterChip(
                          label: l10n.roleShiftManager,
                          isSelected:
                              state.selectedRole == StationRole.shiftManager,
                          onTap: () =>
                              notifier.setRoleFilter(StationRole.shiftManager),
                        ),
                        const SizedBox(width: AppSpacing.space8),
                        _buildFilterChip(
                          label: l10n.roleEmployee,
                          isSelected:
                              state.selectedRole == StationRole.employee,
                          onTap: () =>
                              notifier.setRoleFilter(StationRole.employee),
                        ),
                        const SizedBox(width: AppSpacing.space16),
                        Container(
                            width: 1.0,
                            height: 20.0,
                            color: AppColors.colorBorderMedium),
                        const SizedBox(width: AppSpacing.space16),
                        _buildFilterChip(
                          label: l10n.allStatusesFilter,
                          isSelected: state.selectedStatus == null,
                          onTap: () => notifier.setStatusFilter(null),
                        ),
                        const SizedBox(width: AppSpacing.space8),
                        _buildFilterChip(
                          label: l10n.filterStatusActive,
                          isSelected:
                              state.selectedStatus == MembershipStatus.active,
                          onTap: () =>
                              notifier.setStatusFilter(MembershipStatus.active),
                        ),
                        const SizedBox(width: AppSpacing.space8),
                        _buildFilterChip(
                          label: l10n.filterStatusInactive,
                          isSelected:
                              state.selectedStatus == MembershipStatus.inactive,
                          onTap: () => notifier
                              .setStatusFilter(MembershipStatus.inactive),
                        ),
                        const SizedBox(width: AppSpacing.space8),
                        _buildFilterChip(
                          label: l10n.filterStatusSuspended,
                          isSelected: state.selectedStatus ==
                              MembershipStatus.suspended,
                          onTap: () => notifier
                              .setStatusFilter(MembershipStatus.suspended),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space16),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: state.isLoading && state.employees.isEmpty
                  ? const Padding(
                      padding: AppSpacing.insetAll16,
                      child: Column(
                        children: [
                          AppSkeleton(height: 54.0),
                          SizedBox(height: AppSpacing.space8),
                          AppSkeleton(height: 54.0),
                          SizedBox(height: AppSpacing.space8),
                          AppSkeleton(height: 54.0),
                        ],
                      ),
                    )
                  : state.employees.isEmpty
                      ? AppEmptyState(
                          title: l10n.employeesEmptyTitle,
                          description: state.searchQuery.isNotEmpty
                              ? l10n.employeesEmptySearchDesc
                              : l10n.employeesEmptyDesc,
                          icon: LucideIcons.users,
                          actionLabel: access.canCreateEmployees
                              ? l10n.employeesAddButton
                              : null,
                          onAction: access.canCreateEmployees
                              ? () => CreateEmployeeDialog.show(context)
                              : null,
                        )
                      : isCompact
                          ? _buildCompactListView(state.employees, l10n)
                          : isMedium
                              ? _buildMediumMasterDetailView(state, l10n)
                              : _buildExpandedTableView(state, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space12, vertical: AppSpacing.space6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.colorSurfaceBrandAccent
              : AppColors.colorSurfaceRaised,
          borderRadius: AppRadius.borderPill,
          border: Border.all(
            color: isSelected
                ? AppColors.colorTextPrimary
                : AppColors.colorBorderSubtle,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.colorTextPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactListView(
      List<EmployeeDetails> employees, AppLocalizations l10n) {
    const typography = AppTypography();

    return ListView.separated(
      padding: AppSpacing.insetHorizontal16,
      itemCount: employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.space8),
      itemBuilder: (context, index) {
        final emp = employees[index];

        return InkWell(
          onTap: () => _showDetailSheet(context, emp),
          borderRadius: AppRadius.borderMd,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space12, vertical: AppSpacing.space10),
            decoration: BoxDecoration(
              color: AppColors.colorSurfaceRaised,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: AppColors.colorBorderSubtle),
            ),
            child: Row(
              children: [
                AppAvatar(name: emp.fullName, size: 38.0),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        emp.fullName,
                        style: typography.bodyStrong,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        emp.phone ?? emp.employeeCode ?? l10n.noPhoneRegistered,
                        style: typography.caption
                            .copyWith(color: AppColors.colorTextSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.space8),
                _buildRoleBadge(emp.role, l10n),
                const SizedBox(width: AppSpacing.space4),
                const Icon(LucideIcons.chevronRight,
                    size: 16.0, color: AppColors.colorTextMuted),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediumMasterDetailView(
      EmployeeDirectoryState state, AppLocalizations l10n) {
    const typography = AppTypography();
    final notifier = ref.read(employeeDirectoryProvider.notifier);

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: ListView.separated(
            padding: AppSpacing.insetHorizontal16,
            itemCount: state.employees.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.space8),
            itemBuilder: (context, index) {
              final emp = state.employees[index];
              final isSelected =
                  emp.membershipId == state.selectedEmployee?.membershipId;

              return InkWell(
                onTap: () => notifier.selectEmployee(emp),
                borderRadius: AppRadius.borderMd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space12,
                    vertical: AppSpacing.space8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.colorSurfaceBrandSubtle
                        : AppColors.colorSurfaceRaised,
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.colorTextBrand
                          : AppColors.colorBorderSubtle,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      AppAvatar(name: emp.fullName, size: 36.0),
                      const SizedBox(width: AppSpacing.space8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              emp.fullName,
                              style: typography.bodyStrong,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              emp.phone ??
                                  emp.employeeCode ??
                                  l10n.noPhoneRegistered,
                              style: typography.caption.copyWith(
                                color: AppColors.colorTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space6),
                      _buildRoleBadge(emp.role, l10n),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          flex: 5,
          child: state.selectedEmployee != null
              ? EmployeeDetailInspector(
                  employee: state.selectedEmployee!,
                  onClose: () => notifier.selectEmployee(null),
                )
              : Center(
                  child: Text(
                    l10n.selectEmployeePrompt,
                    style: typography.bodyMedium
                        .copyWith(color: AppColors.colorTextSecondary),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildExpandedTableView(
      EmployeeDirectoryState state, AppLocalizations l10n) {
    const typography = AppTypography();
    final notifier = ref.read(employeeDirectoryProvider.notifier);

    return Row(
      children: [
        Expanded(
          flex: state.selectedEmployee != null ? 7 : 10,
          child: Container(
            margin: AppSpacing.insetHorizontal16,
            decoration: BoxDecoration(
              color: AppColors.colorSurfaceRaised,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: AppColors.colorBorderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                      vertical: AppSpacing.space12),
                  decoration: const BoxDecoration(
                    color: AppColors.colorSurfaceMuted,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.radiusMd)),
                    border: Border(
                        bottom: BorderSide(color: AppColors.colorBorderSubtle)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text(l10n.colNameIdentity,
                              style: typography.caption
                                  .copyWith(fontWeight: FontWeight.w700))),
                      Expanded(
                          flex: 2,
                          child: Text(l10n.colStationRole,
                              style: typography.caption
                                  .copyWith(fontWeight: FontWeight.w700))),
                      Expanded(
                          flex: 2,
                          child: Text(l10n.colStatus,
                              style: typography.caption
                                  .copyWith(fontWeight: FontWeight.w700))),
                      Expanded(
                          flex: 2,
                          child: Text(l10n.colPhone,
                              style: typography.caption
                                  .copyWith(fontWeight: FontWeight.w700))),
                      Expanded(
                          flex: 2,
                          child: Text(l10n.colCode,
                              style: typography.caption
                                  .copyWith(fontWeight: FontWeight.w700))),
                      const SizedBox(width: 40.0),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: state.employees.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1.0, color: AppColors.colorBorderSubtle),
                    itemBuilder: (context, index) {
                      final emp = state.employees[index];
                      final isSelected = emp.membershipId ==
                          state.selectedEmployee?.membershipId;

                      return InkWell(
                        onTap: () => notifier.selectEmployee(emp),
                        child: Container(
                          color: isSelected
                              ? AppColors.colorSurfaceBrandSubtle
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.space16,
                              vertical: AppSpacing.space12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    AppAvatar(name: emp.fullName, size: 32.0),
                                    const SizedBox(width: AppSpacing.space12),
                                    Flexible(
                                      child: Text(
                                        emp.fullName,
                                        style: typography.bodyStrong,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                  flex: 2,
                                  child: Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: _buildRoleBadge(emp.role, l10n))),
                              Expanded(
                                  flex: 2,
                                  child: Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child:
                                          _buildStatusBadge(emp.status, l10n))),
                              Expanded(
                                  flex: 2,
                                  child: Text(emp.phone ?? '-',
                                      style: typography.bodyMedium)),
                              Expanded(
                                  flex: 2,
                                  child: Text(emp.employeeCode ?? '-',
                                      style: typography.bodyMedium)),
                              SizedBox(
                                width: 40.0,
                                child: IconButton(
                                  icon: const Icon(LucideIcons.moreVertical,
                                      size: 16.0),
                                  onPressed: () => notifier.selectEmployee(emp),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.selectedEmployee != null)
          Expanded(
            flex: 3,
            child: EmployeeDetailInspector(
              employee: state.selectedEmployee!,
              onClose: () => notifier.selectEmployee(null),
            ),
          ),
      ],
    );
  }

  Widget _buildRoleBadge(StationRole role, AppLocalizations l10n) {
    switch (role) {
      case StationRole.admin:
        return AppStatusBadge(
          label: l10n.roleAdmin,
          variant: AppBadgeVariant.brand,
          icon: LucideIcons.shieldCheck,
        );
      case StationRole.shiftManager:
        return AppStatusBadge(
          label: l10n.roleShiftManager,
          variant: AppBadgeVariant.info,
          icon: LucideIcons.userCheck,
        );
      case StationRole.employee:
        return AppStatusBadge(
          label: l10n.roleEmployee,
          variant: AppBadgeVariant.neutral,
          icon: LucideIcons.user,
        );
    }
  }

  Widget _buildStatusBadge(MembershipStatus status, AppLocalizations l10n) {
    switch (status) {
      case MembershipStatus.active:
        return AppStatusBadge(
          label: l10n.statusActive,
          variant: AppBadgeVariant.success,
        );
      case MembershipStatus.inactive:
        return AppStatusBadge(
          label: l10n.statusInactive,
          variant: AppBadgeVariant.warning,
        );
      case MembershipStatus.suspended:
        return AppStatusBadge(
          label: l10n.statusSuspended,
          variant: AppBadgeVariant.danger,
        );
    }
  }
}
