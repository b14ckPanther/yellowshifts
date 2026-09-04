import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../../../core/design_system/components/app_surface.dart';
import '../../../../core/design_system/components/app_page_header.dart';
import '../../data/notification_repository.dart';
import '../../domain/models/notification_item.dart';
import '../../domain/models/notification_preferences.dart';
import '../controllers/notifications_controller.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  late Map<NotificationCategory, NotificationCategoryPreference> _localPrefs;

  @override
  void initState() {
    super.initState();
    _localPrefs = {};
  }

  void _syncFromRemote(NotificationPreferences prefs) {
    if (_localPrefs.isEmpty) {
      for (final p in prefs.preferences) {
        _localPrefs[p.category] = p;
      }
    }
  }

  Future<void> _updateCategoryPref(
    NotificationCategory category, {
    bool? inApp,
    bool? push,
    bool? email,
    bool? sms,
  }) async {
    final current = _localPrefs[category] ??
        NotificationCategoryPreference(
          category: category,
          inAppEnabled: true,
          pushEnabled: true,
          emailEnabled: false,
          smsEnabled: false,
        );

    final updated = current.copyWith(
      inAppEnabled: inApp,
      pushEnabled: push,
      emailEnabled: email,
      smsEnabled: sms,
    );

    setState(() {
      _localPrefs[category] = updated;
    });

    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.updatePreferences(
        category: category,
        inApp: updated.inAppEnabled,
        push: updated.pushEnabled,
        email: updated.emailEnabled,
        sms: updated.smsEnabled,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update preference: $e'),
            backgroundColor: AppColors.colorStatusDanger,
          ),
        );
      }
    }
  }

  String _getCategoryTitle(NotificationCategory cat, bool isHe) {
    switch (cat) {
      case NotificationCategory.schedule:
        return isHe ? 'סידור עבודה ושיבוצים' : 'Schedules & Shifts';
      case NotificationCategory.attendance:
        return isHe ? 'נוכחות ואיחורים' : 'Attendance & Lateness';
      case NotificationCategory.availability:
        return isHe ? 'תזכורות ומועדי זמינות' : 'Availability Deadlines';
      case NotificationCategory.operations:
        return isHe ? 'התראות תפעוליות ותגי NFC' : 'Station Operations & NFC Tags';
      case NotificationCategory.system:
        return isHe ? 'הודעות מערכת כלליות' : 'General System Notices';
    }
  }

  String _getCategoryDesc(NotificationCategory cat, bool isHe) {
    switch (cat) {
      case NotificationCategory.schedule:
        return isHe
            ? 'פרסום לוחות שבועיים, שיבוצים ושינויי משמרות'
            : 'Schedule publications, assignments, and roster shifts';
      case NotificationCategory.attendance:
        return isHe
            ? 'אישורי כניסה/יציאה, התראות איחור ותיקוני נוכחות'
            : 'Check-in/out confirmations, lateness, and corrections';
      case NotificationCategory.availability:
        return isHe
            ? 'תזכורות פתיחת וסגירת חלונות הגשת זמינות שבועית'
            : 'Reminders for opening and closing submission deadlines';
      case NotificationCategory.operations:
        return isHe
            ? 'התראות תגי NFC ומצבי פעילות בתחנה'
            : 'NFC tag provisioning, revocations, and station activity';
      case NotificationCategory.system:
        return isHe
            ? 'הודעות תשתית, עדכוני מערכת ואבטחה'
            : 'Infrastructure updates and system maintenance';
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      backgroundColor: AppColors.colorSurfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: isHe
                    ? 'הגדרות ערוצי התראות'
                    : 'Notification Channels & Preferences',
                subtitle: isHe
                    ? 'ניהול ערוצי מסירה והעדפות קבלת הודעות באפליקציה, פוש, מייל ו-SMS'
                    : 'Configure in-app, push, email, and SMS delivery for each category',
              ),
              Padding(
                padding: AppSpacing.insetHorizontal16,
                child: Column(
                  children: [
                    // Mandatory Security Alerts Banner
                    Container(
                      padding: AppSpacing.insetAll16,
                      decoration: BoxDecoration(
                        color: AppColors.colorSurfaceRaised,
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(
                          color:
                              AppColors.colorBrandYellow.withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.shieldAlert,
                            size: 22.0,
                            color: AppColors.colorBrandYellow,
                          ),
                          const SizedBox(width: AppSpacing.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isHe
                                      ? 'התראות אבטחה ותפעול חובה'
                                      : 'Mandatory Compliance & Security Notices',
                                  style: typography.bodyStrong.copyWith(
                                    color: AppColors.colorBrandYellow,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space4),
                                Text(
                                  isHe
                                      ? 'התראות אבטחה קריטיות, חריגות זיהוי ותיקוני נוכחות ידניים נמסרים תמיד בתוך האפליקציה לצורכי בקרה ואבטחה.'
                                      : 'Critical security alerts, manual attendance adjustments, and identity overrides are mandatory and always delivered in-app for auditing.',
                                  style: typography.caption.copyWith(
                                    color: AppColors.colorTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space16),

                    // Preferences Categories Card
                    prefsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(AppSpacing.space32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.colorBrandYellow,
                          ),
                        ),
                      ),
                      error: (err, _) => Center(
                        child: Text(
                          'Error loading preferences: $err',
                          style: const TextStyle(
                              color: AppColors.colorStatusDanger),
                        ),
                      ),
                      data: (prefs) {
                        _syncFromRemote(prefs);

                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isHe ? 'מטריצת ערוצים' : 'Delivery Matrix',
                                style: typography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space4),
                              Text(
                                isHe
                                    ? 'בחר אילו התראות יימסרו בכל ערוץ תקשורת'
                                    : 'Toggle preferred communication channels for each operational category',
                                style: typography.caption.copyWith(
                                  color: AppColors.colorTextMuted,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space16),
                              ...NotificationCategory.values.map((cat) {
                                final pref = _localPrefs[cat] ??
                                    prefs.forCategory(cat) ??
                                    NotificationCategoryPreference(
                                      category: cat,
                                      inAppEnabled: true,
                                      pushEnabled: true,
                                      emailEnabled: false,
                                      smsEnabled: false,
                                    );

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(
                                        color: AppColors.colorBorderSubtle),
                                    const SizedBox(height: AppSpacing.space8),
                                    Text(
                                      _getCategoryTitle(cat, isHe),
                                      style: typography.bodyStrong,
                                    ),
                                    const SizedBox(height: AppSpacing.space2),
                                    Text(
                                      _getCategoryDesc(cat, isHe),
                                      style: typography.caption.copyWith(
                                        color: AppColors.colorTextMuted,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.space8),
                                    Wrap(
                                      spacing: AppSpacing.space8,
                                      runSpacing: AppSpacing.space8,
                                      children: [
                                        _ChannelSwitch(
                                          label: isHe ? 'באפליקציה' : 'In-App',
                                          icon: LucideIcons.appWindow,
                                          value: pref.inAppEnabled,
                                          onChanged: (val) =>
                                              _updateCategoryPref(cat,
                                                  inApp: val),
                                        ),
                                        _ChannelSwitch(
                                          label: isHe ? 'התראת פוש' : 'Push',
                                          icon: LucideIcons.smartphone,
                                          value: pref.pushEnabled,
                                          onChanged: (val) =>
                                              _updateCategoryPref(cat,
                                                  push: val),
                                        ),
                                        _ChannelSwitch(
                                          label: isHe ? 'דוא״ל' : 'Email',
                                          icon: LucideIcons.mail,
                                          value: pref.emailEnabled,
                                          onChanged: (val) =>
                                              _updateCategoryPref(cat,
                                                  email: val),
                                        ),
                                        _ChannelSwitch(
                                          label: isHe ? 'SMS' : 'SMS',
                                          icon: LucideIcons.messageSquare,
                                          value: pref.smsEnabled,
                                          onChanged: (val) =>
                                              _updateCategoryPref(cat,
                                                  sms: val),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.space8),
                                  ],
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.space24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelSwitch extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ChannelSwitch({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.borderSm,
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space10,
            vertical: AppSpacing.space6,
          ),
          decoration: BoxDecoration(
            color: value
                ? AppColors.colorBrandYellow.withValues(alpha: 0.15)
                : AppColors.colorSurfaceBase,
            borderRadius: AppRadius.borderSm,
            border: Border.all(
              color: value
                  ? AppColors.colorBrandYellow
                  : AppColors.colorBorderSubtle,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14.0,
                color: value
                    ? AppColors.colorBrandYellow
                    : AppColors.colorTextMuted,
              ),
              const SizedBox(width: AppSpacing.space6),
              Text(
                label,
                style: typography.caption.copyWith(
                  fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                  color: value
                      ? AppColors.colorTextPrimary
                      : AppColors.colorTextMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.space4),
              Icon(
                value ? LucideIcons.check : LucideIcons.x,
                size: 12.0,
                color: value
                    ? AppColors.colorBrandYellow
                    : AppColors.colorTextMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
