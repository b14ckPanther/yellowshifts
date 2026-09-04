import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../domain/models/notification_item.dart';
import '../controllers/notifications_controller.dart';
import '../widgets/notification_tile.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationListControllerProvider.notifier).loadMore();
    }
  }

  String _getCategoryLabel(NotificationCategory cat, bool isHe) {
    switch (cat) {
      case NotificationCategory.schedule:
        return isHe ? 'סידור עבודה' : 'Schedule';
      case NotificationCategory.attendance:
        return isHe ? 'נוכחות' : 'Attendance';
      case NotificationCategory.availability:
        return isHe ? 'זמינות' : 'Availability';
      case NotificationCategory.operations:
        return isHe ? 'תפעול' : 'Operations';
      case NotificationCategory.system:
        return isHe ? 'מערכת' : 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final state = ref.watch(notificationListControllerProvider);
    final controller = ref.read(notificationListControllerProvider.notifier);

    final unreadCount = state.items.where((e) => e.isUnread).length;

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: isHe ? 'מרכז התראות והודעות' : 'Notification Center',
              subtitle: isHe
                  ? 'עדכוני סידור עבודה, נוכחות חיה, תזכורות והתראות תפעוליות בזמן אמת'
                  : 'Realtime shift updates, live attendance alerts, reminders, and operational events',
              actions: [
                if (unreadCount > 0)
                  AppButton(
                    label: isHe ? 'סמן הכל כנקרא' : 'Mark all as read',
                    icon: LucideIcons.checkCheck,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => controller.markAllAsRead(),
                  ),
              ],
            ),

            // Filter Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space16,
                vertical: AppSpacing.space8,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // All Category Chip
                    _FilterChip(
                      label: isHe ? 'הכל' : 'All',
                      isSelected: state.selectedCategory == null,
                      onTap: () => controller.setCategory(null),
                    ),
                    const SizedBox(width: AppSpacing.space8),

                    // Categories
                    ...NotificationCategory.values.map((cat) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(right: AppSpacing.space8),
                        child: _FilterChip(
                          label: _getCategoryLabel(cat, isHe),
                          isSelected: state.selectedCategory == cat,
                          onTap: () => controller.setCategory(cat),
                        ),
                      );
                    }),

                    const SizedBox(width: AppSpacing.space8),
                    Container(
                      height: 24.0,
                      width: 1.0,
                      color: AppColors.colorBorderSubtle,
                    ),
                    const SizedBox(width: AppSpacing.space8),

                    // Unread Only Toggle
                    _FilterChip(
                      label: isHe ? 'טרם נקראו בלבד' : 'Unread only',
                      isSelected: state.unreadOnly,
                      icon: LucideIcons.filter,
                      onTap: () => controller.setUnreadOnly(!state.unreadOnly),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(color: AppColors.colorBorderSubtle, height: 1.0),

            // Content Area
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.loadInitial(),
                color: AppColors.colorBrandYellow,
                child: Builder(
                  builder: (context) {
                    if (state.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.colorBrandYellow,
                        ),
                      );
                    }

                    if (state.error != null) {
                      return Center(
                        child: Padding(
                          padding: AppSpacing.insetAll24,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.alertTriangle,
                                size: 40.0,
                                color: AppColors.colorStatusDanger,
                              ),
                              const SizedBox(height: AppSpacing.space12),
                              Text(
                                isHe
                                    ? 'שגיאה בטעינת ההתראות'
                                    : 'Error loading notifications',
                                style: typography.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.space8),
                              Text(
                                state.error!,
                                style: typography.caption.copyWith(
                                  color: AppColors.colorTextMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.space16),
                              AppButton(
                                label: isHe ? 'נסה שוב' : 'Retry',
                                icon: LucideIcons.refreshCw,
                                onPressed: () => controller.loadInitial(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (state.items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: AppSpacing.insetAll24,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72.0,
                                height: 72.0,
                                decoration: const BoxDecoration(
                                  color: AppColors.colorSurfaceRaised,
                                  borderRadius: AppRadius.borderPill,
                                ),
                                child: const Center(
                                  child: Icon(
                                    LucideIcons.bellOff,
                                    size: 32.0,
                                    color: AppColors.colorTextMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space16),
                              Text(
                                state.unreadOnly
                                    ? (isHe
                                        ? 'אין התראות שלא נקראו'
                                        : 'No unread notifications')
                                    : (isHe
                                        ? 'אין התראות להצגה'
                                        : 'No notifications found'),
                                style: typography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space8),
                              Text(
                                isHe
                                    ? 'הכל מעודכן! התראות חדשות על סידורי עבודה ונוכחות יופיעו כאן.'
                                    : 'You are all caught up! New schedule, attendance, and system notices will appear here.',
                                style: typography.bodyMedium.copyWith(
                                  color: AppColors.colorTextMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.space12,
                      ),
                      itemCount: state.items.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.space16,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 24.0,
                                height: 24.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.colorBrandYellow,
                                ),
                              ),
                            ),
                          );
                        }

                        final item = state.items[index];
                        return NotificationTile(
                          item: item,
                          onMarkRead: () => controller.markAsRead(item),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.borderPill,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space12,
            vertical: AppSpacing.space6,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.colorBrandYellow
                : AppColors.colorSurfaceRaised,
            borderRadius: AppRadius.borderPill,
            border: Border.all(
              color: isSelected
                  ? AppColors.colorBrandYellow
                  : AppColors.colorBorderSubtle,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14.0,
                  color: isSelected
                      ? AppColors.colorSurfaceBase
                      : AppColors.colorTextSecondary,
                ),
                const SizedBox(width: AppSpacing.space4),
              ],
              Text(
                label,
                style: typography.caption.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.colorSurfaceBase
                      : AppColors.colorTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
