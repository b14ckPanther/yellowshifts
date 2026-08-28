import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/tokens/app_colors.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_typography.dart';
import '../../domain/models/notification_item.dart';

class NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback? onMarkRead;

  const NotificationTile({
    super.key,
    required this.item,
    this.onMarkRead,
  });

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.schedule:
        return LucideIcons.calendar;
      case NotificationCategory.attendance:
        return LucideIcons.clock;
      case NotificationCategory.availability:
        return LucideIcons.calendarCheck;
      case NotificationCategory.operations:
        return LucideIcons.radio;
      case NotificationCategory.identity:
        return LucideIcons.shieldCheck;
      case NotificationCategory.system:
        return LucideIcons.bell;
    }
  }

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.schedule:
        return const Color(0xFF0284C7); // Sky blue
      case NotificationCategory.attendance:
        return AppColors.colorStatusSuccess; // Emerald
      case NotificationCategory.availability:
        return AppColors.colorBrandYellow; // Amber
      case NotificationCategory.operations:
        return const Color(0xFFF97316); // Orange
      case NotificationCategory.identity:
        return const Color(0xFFA855F7); // Purple
      case NotificationCategory.system:
        return AppColors.colorTextSecondary;
    }
  }

  String _formatTimeAgo(DateTime dt, bool isHe) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 45) {
      return isHe ? 'עכשיו' : 'Just now';
    }
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return isHe ? 'לפני $m דק׳' : '${m}m ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return isHe ? 'לפני $h שעות' : '${h}h ago';
    }
    final d = diff.inDays;
    if (d == 1) {
      return isHe ? 'אתמול' : 'Yesterday';
    }
    return isHe ? 'לפני $d ימים' : '${d}d ago';
  }

  String _resolveTitle(String key, Map<String, dynamic> data, bool isHe) {
    switch (key) {
      case 'notif_schedule_published_title':
        return isHe ? 'לוח משמרות פורסם' : 'Schedule Published';
      case 'notif_schedule_pub_complete_title':
        return isHe ? 'פרסום לוח הושלם' : 'Schedule Published';
      case 'notif_shift_assigned_title':
        return isHe ? 'שובצת למשמרת' : 'Shift Assigned';
      case 'notif_shift_changed_title':
        return isHe ? 'עודכן שיבוץ משמרת' : 'Shift Assignment Changed';
      case 'notif_schedule_revised_title':
        return isHe ? 'עודכן סידור עבודה' : 'Schedule Revised';
      case 'notif_shift_removed_title':
        return isHe ? 'הוסרת ממשמרת' : 'Shift Removed';
      case 'notif_emp_checked_in_title':
        return isHe ? 'כניסה למשמרת' : 'Employee Checked In';
      case 'notif_emp_checked_out_title':
        return isHe ? 'יציאה ממשמרת' : 'Employee Checked Out';
      case 'notif_check_in_confirmed_title':
        return isHe ? 'כניסה אושרה' : 'Check-In Confirmed';
      case 'notif_check_out_confirmed_title':
        return isHe ? 'יציאה אושרה' : 'Check-Out Confirmed';
      case 'notif_emp_late_title':
        return isHe ? 'התראת איחור עובד' : 'Late Check-In Alert';
      case 'notif_emp_missed_check_in_title':
        return isHe ? 'אי-התייצבות למשמרת' : 'Missed Check-In Alert';
      case 'notif_attendance_corrected_title':
        return isHe ? 'תיקון נוכחות ידני' : 'Attendance Adjusted';
      case 'notif_avail_reminder_title':
        return isHe ? 'תזכורת הגשת זמינות' : 'Availability Reminder';
      case 'notif_avail_deadline_title':
        return isHe ? 'מועד הגשת זמינות מתקרב' : 'Availability Deadline';
      case 'notif_avail_submitted_title':
        return isHe ? 'זמינות הוגשה בהצלחה' : 'Availability Submitted';
      case 'notif_avail_missing_title':
        return isHe ? 'עובדים ללא זמינות' : 'Missing Availability Submissions';
      case 'notif_kiosk_offline_title':
        return isHe ? 'קיוסק תחנה מנותק' : 'Kiosk Offline Warning';
      case 'notif_kiosk_recovered_title':
        return isHe ? 'קיוסק תחנה חזר לפעילות' : 'Kiosk Restored Online';
      case 'notif_identity_enroll_req_title':
        return isHe ? 'נדרש רישום זיהוי' : 'Identity Enrollment Required';
      case 'notif_identity_enrolled_title':
        return isHe ? 'רישום זיהוי הושלם' : 'Identity Enrollment Completed';
      case 'notif_identity_override_title':
        return isHe ? 'אישור חריגת זיהוי' : 'Identity Admin Override';
      case 'notif_identity_exception_title':
        return isHe ? 'כשל אימות זהות' : 'Identity Verification Exception';
      case 'notif_identity_revoked_title':
        return isHe ? 'פרופיל זיהוי בוטל' : 'Identity Profile Revoked';
      default:
        return isHe ? 'התראה תפעולית' : 'Operational Notice';
    }
  }

  String _resolveBody(String key, Map<String, dynamic> data, bool isHe) {
    final emp = data['employee_name']?.toString() ?? 'Employee';
    final shift = data['shift_name']?.toString() ?? 'Shift';
    final stName = data['station_name']?.toString() ?? 'Station';
    final minutes = data['minutes_offline']?.toString() ??
        data['late_minutes']?.toString() ??
        data['worked_minutes']?.toString() ??
        '0';
    final hours = data['hours_remaining']?.toString() ?? '24';
    final reason = data['reason']?.toString() ?? '';
    final admin = data['admin_name']?.toString() ?? 'Admin';
    final date = data['operational_date']?.toString() ?? '';
    final ver = data['version']?.toString() ?? '1';
    final missingCount = data['missing_count']?.toString() ?? '0';

    switch (key) {
      case 'notif_schedule_published_body':
        return isHe
            ? 'פורסם סידור עבודה רשמי לשבוע ${data['week_start_date'] ?? ''} (גרסה $ver).'
            : 'Official work schedule published for week ${data['week_start_date'] ?? ''} (v$ver).';
      case 'notif_schedule_revised_body':
        return isHe
            ? 'סידור העבודה בתחנת $stName עודכן לגרסה $ver.'
            : 'Schedule for $stName updated to version $ver.';
      case 'notif_schedule_pub_complete_body':
        return isHe
            ? 'פרסום סידור עבודה גרסה $ver לתחנת $stName הושלם.'
            : 'Schedule v$ver successfully published for $stName.';
      case 'notif_shift_assigned_body':
        return isHe
            ? 'שובצת למשמרת $shift בתאריך $date.'
            : 'You have been assigned to $shift on $date.';
      case 'notif_shift_changed_body':
        return isHe
            ? 'שיבוצך עודכן למשמרת $shift בתחנת $stName.'
            : 'Your shift assignment was moved to $shift at $stName.';
      case 'notif_shift_removed_body':
        return isHe
            ? 'הוסרת משיבוץ משמרת $shift בתאריך $date.'
            : 'You were removed from $shift on $date.';
      case 'notif_emp_checked_in_body':
        return isHe
            ? '$emp נכנס/ה למשמרת $shift בתחנת $stName.'
            : '$emp checked in for $shift at $stName.';
      case 'notif_emp_checked_out_body':
        return isHe
            ? '$emp סיים/ה משמרת $shift ($minutes דקות עבודה).'
            : '$emp checked out from $shift ($minutes min worked).';
      case 'notif_check_in_confirmed_body':
        return isHe
            ? 'נכנסת בהצלחה למשמרת $shift.'
            : 'Checked in successfully for $shift.';
      case 'notif_check_out_confirmed_body':
        return isHe
            ? 'יצאת בהצלחה ממשמרת. סה״כ $minutes דקות עבודה.'
            : 'Checked out successfully. Total: $minutes minutes.';
      case 'notif_emp_late_body':
        return isHe
            ? '$emp מאחר/ת ב-$minutes דקות למשמרת $shift.'
            : '$emp is late by $minutes min for $shift.';
      case 'notif_emp_missed_check_in_body':
        return isHe
            ? '$emp לא ביצע/ה כניסה למשמרת $shift שנקבעה ל-${data['starts_at'] ?? ''}.'
            : '$emp missed check-in for scheduled shift $shift.';
      case 'notif_attendance_corrected_body':
        return isHe
            ? 'נוכחות $emp עודכנה ידנית ($reason).'
            : 'Attendance for $emp was adjusted: $reason.';
      case 'notif_avail_reminder_body':
        return isHe
            ? 'נא להגיש זמינות שבועית עבור תחנת $stName.'
            : 'Please submit your weekly shift availability for $stName.';
      case 'notif_avail_deadline_body':
        return isHe
            ? 'נותרו עוד $hours שעות להגשת זמינות לתחנת $stName!'
            : 'Only $hours hours remaining to submit availability for $stName!';
      case 'notif_avail_submitted_body':
        return isHe
            ? 'טופס הזמינות השבועי שלך לתחנת $stName נקלט בהצלחה.'
            : 'Your availability submission for $stName was received.';
      case 'notif_avail_missing_body':
        return isHe
            ? 'טרם הוגשה זמינות ע״י $missingCount עובדים עבור תחנת $stName.'
            : '$missingCount employees have not submitted availability for $stName.';
      case 'notif_kiosk_offline_body':
        return isHe
            ? 'קיוסק "${data['kiosk_name'] ?? 'Kiosk'}" מנותק כבר $minutes דקות בתחנת $stName.'
            : 'Kiosk "${data['kiosk_name'] ?? 'Kiosk'}" has been offline for $minutes min at $stName.';
      case 'notif_kiosk_recovered_body':
        return isHe
            ? 'קיוסק "${data['kiosk_name'] ?? 'Kiosk'}" חזר לפעילות תקינה.'
            : 'Kiosk "${data['kiosk_name'] ?? 'Kiosk'}" is back online.';
      case 'notif_identity_enroll_req_body':
        return isHe
            ? 'נדרש רישום אימות זהות עבור תחנת $stName.'
            : 'Identity enrollment is required for $stName.';
      case 'notif_identity_enrolled_body':
        return isHe
            ? 'רישום אימות הזהות שלך הושלם בהצלחה בתחנת $stName.'
            : 'Identity enrollment completed for $stName.';
      case 'notif_identity_override_body':
        return isHe
            ? 'מנהל $admin אישר חריגת אימות זהות עבור $emp ($reason).'
            : 'Admin $admin authorized identity override for $emp ($reason).';
      case 'notif_identity_exception_body':
        return isHe
            ? 'התרחש כשל באימות זהות עבור $emp בתחנת $stName.'
            : 'Identity verification failed for $emp at $stName.';
      case 'notif_identity_revoked_body':
        return isHe
            ? 'פרופיל אימות הזהות של $emp בוטל ($reason).'
            : 'Identity profile for $emp was revoked ($reason).';
      default:
        return data['event_type']?.toString() ??
            'System notification received.';
    }
  }

  void _handleAction(BuildContext context) {
    if (onMarkRead != null && item.isUnread) {
      onMarkRead!();
    }

    if (item.actionType == null) return;

    switch (item.actionType) {
      case 'NAVIGATE_SCHEDULE':
        context.go('/schedule');
        break;
      case 'NAVIGATE_ATTENDANCE':
        context.go('/attendance');
        break;
      case 'NAVIGATE_AVAILABILITY':
        context.go('/availability');
        break;
      case 'NAVIGATE_IDENTITY':
        context.go('/identity-verification');
        break;
      case 'NAVIGATE_KIOSK':
        context.go('/settings/kiosks');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const typography = AppTypography();
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final categoryColor = _getCategoryColor(item.category);
    final categoryIcon = _getCategoryIcon(item.category);
    final title = _resolveTitle(item.titleKey, item.renderData, isHe);
    final body = _resolveBody(item.bodyKey, item.renderData, isHe);
    final timeAgo = _formatTimeAgo(item.createdAt, isHe);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space4,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderMd,
          onTap: () => _handleAction(context),
          child: Container(
            padding: AppSpacing.insetAll16,
            decoration: BoxDecoration(
              color: item.isUnread
                  ? AppColors.colorSurfaceRaised
                  : AppColors.colorSurfaceBase,
              borderRadius: AppRadius.borderMd,
              border: Border.all(
                color: item.isCritical
                    ? AppColors.colorStatusDanger
                    : (item.isUnread
                        ? AppColors.colorBorderBrand
                        : AppColors.colorBorderSubtle),
                width: item.isCritical ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon Avatar
                Container(
                  width: 40.0,
                  height: 40.0,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Center(
                    child: Icon(
                      categoryIcon,
                      size: 20.0,
                      color: categoryColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space12),

                // Notification Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: typography.bodyStrong.copyWith(
                                fontWeight: item.isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: item.isUnread
                                    ? AppColors.colorTextPrimary
                                    : AppColors.colorTextSecondary,
                              ),
                            ),
                          ),
                          if (item.priority ==
                              NotificationPriority.critical) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.colorStatusDanger
                                    .withValues(alpha: 0.15),
                                borderRadius: AppRadius.borderSm,
                              ),
                              child: Text(
                                isHe ? 'דחוף' : 'CRITICAL',
                                style: const TextStyle(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.colorStatusDanger,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.space6),
                          ],
                          Text(
                            timeAgo,
                            style: typography.caption.copyWith(
                              color: AppColors.colorTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Text(
                        body,
                        style: typography.bodyMedium.copyWith(
                          color: item.isUnread
                              ? AppColors.colorTextPrimary
                              : AppColors.colorTextSecondary,
                        ),
                      ),
                      if (item.actionType != null) ...[
                        const SizedBox(height: AppSpacing.space8),
                        Row(
                          children: [
                            Text(
                              isHe ? 'הקש למעבר' : 'Tap to open',
                              style: typography.caption.copyWith(
                                color: AppColors.colorBrandYellow,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.space4),
                            const Icon(
                              LucideIcons.arrowUpRight,
                              size: 13.0,
                              color: AppColors.colorBrandYellow,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Unread dot indicator
                if (item.isUnread) ...[
                  const SizedBox(width: AppSpacing.space8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Container(
                      width: 8.0,
                      height: 8.0,
                      decoration: const BoxDecoration(
                        color: AppColors.colorBrandYellow,
                        shape: BoxShape.circle,
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
}
