import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../controllers/notifications_controller.dart';

class NotificationBadgeIcon extends ConsumerStatefulWidget {
  final double size;
  final Color? color;

  const NotificationBadgeIcon({
    super.key,
    this.size = 22.0,
    this.color,
  });

  @override
  ConsumerState<NotificationBadgeIcon> createState() =>
      _NotificationBadgeIconState();
}

class _NotificationBadgeIconState extends ConsumerState<NotificationBadgeIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadAsync = ref.watch(unreadNotificationCountProvider);
    final countSummary = unreadAsync.value;
    final unreadCount = countSummary?.unreadCount ?? 0;
    final hasCritical = countSummary?.hasCritical ?? false;

    if (hasCritical && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!hasCritical && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0.0;
    }

    return Tooltip(
      message: unreadCount > 0
          ? '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}'
          : 'Notifications',
      child: InkWell(
        borderRadius: AppRadius.borderPill,
        onTap: () => context.push('/notifications'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space8),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                LucideIcons.bell,
                size: widget.size,
                color: widget.color ?? AppColors.colorTextPrimary,
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -6,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final scale = hasCritical ? _pulseAnimation.value : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5.0,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: hasCritical
                                ? AppColors.colorStatusDanger
                                : AppColors.colorBrandYellow,
                            borderRadius: AppRadius.borderPill,
                            boxShadow: [
                              BoxShadow(
                                color: (hasCritical
                                        ? AppColors.colorStatusDanger
                                        : AppColors.colorBrandYellow)
                                    .withValues(alpha: 0.4),
                                blurRadius: hasCritical ? 6.0 : 3.0,
                                spreadRadius: hasCritical ? 1.0 : 0.0,
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16.0,
                            minHeight: 16.0,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: TextStyle(
                                color: hasCritical
                                    ? Colors.white
                                    : AppColors.colorSurfaceBase,
                                fontSize: 10.0,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
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
      ),
    );
  }
}
