// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'YellowShifts';

  @override
  String get appTagline => 'פלטפורמת תפעול משמרות ועבודה';

  @override
  String get navHome => 'ראשי';

  @override
  String get navSchedule => 'סידור עבודה';

  @override
  String get navAttendance => 'נוכחות';

  @override
  String get navEmployees => 'עובדים';

  @override
  String get navSettings => 'הגדרות';

  @override
  String get navAvailability => 'זמינות';

  @override
  String get navReports => 'דוחות';

  @override
  String get navDesignSystem => 'שפת עיצוב';

  @override
  String get loginTitle => 'התחברות ל-YellowShifts';

  @override
  String get loginSubtitle => 'הזן את פרטי ההתחברות כדי לגשת לניהול התחנה שלך.';

  @override
  String get loginEmailLabel => 'כתובת אימייל';

  @override
  String get loginEmailHint => 'name@yellowshifts.com';

  @override
  String get loginPasswordLabel => 'סיסמה';

  @override
  String get loginPasswordHint => 'הזן את סיסמתך';

  @override
  String get loginButton => 'התחברות למערכת';

  @override
  String get loginLoading => 'מאמת נתונים...';

  @override
  String get loginInvalidCredentials =>
      'כתובת אימייל או סיסמה שגויים. אנא נסה שוב.';

  @override
  String get loginNetworkError => 'לא ניתן להתחבר לשרת. בדוק את חיבור הרשת.';

  @override
  String get loginValidationEmpty => 'נא להזין כתובת אימייל וסיסמה.';

  @override
  String get loginHeroTitle => 'מהירות תפעולית.\nדיוק רב-תחנתי.';

  @override
  String get loginHeroSubtitle =>
      'מערכת ניהול משמרות וכוח אדם מתקדמת לתחנות, מנהלי משמרת ועובדים בסנכרון מלא בזמן אמת.';

  @override
  String get loginHeroBadge => 'מערכת תפעולית • YellowShifts';

  @override
  String get stationSelectTitle => 'בחירת תחנה';

  @override
  String get stationSelectSubtitle =>
      'הינך משויך למספר תחנות. בחר תחנה פעילה להמשך עבודה.';

  @override
  String get stationSelectAction => 'כניסה לתחנה';

  @override
  String get stationActiveBadge => 'פעיל';

  @override
  String get stationInactiveBadge => 'לא פעיל';

  @override
  String get emptyStationsTitle => 'לא נבחרה תחנה פעילה';

  @override
  String get emptyStationsDescription =>
      'אנא בחר תחנה פעילה כדי לגשת למערכות התפעוליות של התחנה.';

  @override
  String get roleAdmin => 'מנהל תחנה';

  @override
  String get roleShiftManager => 'מנהל משמרת';

  @override
  String get roleEmployee => 'עובד';

  @override
  String get dashboardTitle => 'מבט על התחנה';

  @override
  String dashboardWelcome(String name) {
    return 'ברוך הבא, $name';
  }

  @override
  String dashboardActiveStation(String stationName) {
    return 'תחנה פעילה: $stationName';
  }

  @override
  String get dashboardStationCode => 'קוד תחנה';

  @override
  String get dashboardTimezone => 'אזור זמן';

  @override
  String get dashboardRole => 'תפקיד בתחנה';

  @override
  String get dashboardQuickStats => 'דופק תפעולי';

  @override
  String get dashboardRealtimeSync => 'סנכרון בזמן אמת מחובר';

  @override
  String get dashboardActiveMembers => 'כוח אדם פעיל';

  @override
  String get dashboardAdminsCount => 'מנהלי תחנה';

  @override
  String get dashboardManagersCount => 'מנהלי משמרת';

  @override
  String get dashboardEmployeesCount => 'עובדים';

  @override
  String get dashboardEmptyOnboardingTitle => 'ברוכים הבאים לתחנה החדשה';

  @override
  String get dashboardEmptyOnboardingDesc =>
      'התחנה שלך הוגדרה בהצלחה. התחל בהוספת העובד הראשון או בהגדרת פרמטרי התפעול של התחנה.';

  @override
  String get employeesTitle => 'ספר עובדים';

  @override
  String get employeesSubtitle =>
      'ניהול חשבונות כוח אדם, תפקידי תחנה ואבטחת גישה.';

  @override
  String get employeesSearchHint => 'חיפוש לפי שם, טלפון או קוד עובד...';

  @override
  String get employeesFilterAllRoles => 'כל התפקידים';

  @override
  String get employeesFilterAllStatus => 'כל הסטטוסים';

  @override
  String get employeesAddButton => 'עובד חדש';

  @override
  String get employeesEmptyTitle => 'לא נמצאו עובדים';

  @override
  String get employeesEmptyDesc => 'עדיין לא נרשמו עובדים בתחנה זו.';

  @override
  String get employeesEmptySearchDesc =>
      'לא נמצאו רשומות עובדים התואמות את שאילתת החיפוש.';

  @override
  String get employeesColName => 'שם וזהות';

  @override
  String get employeesColRole => 'תפקיד בתחנה';

  @override
  String get employeesColStatus => 'סטטוס';

  @override
  String get employeesColPhone => 'טלפון';

  @override
  String get employeesColCode => 'קוד עובד';

  @override
  String get employeesColActions => 'פעולות';

  @override
  String get createEmployeeTitle => 'הקצאת חשבון עובד';

  @override
  String get createEmployeeSubtitle =>
      'יצירת חשבון כוח אדם חדש או שיוך עובד קיים לתחנה זו.';

  @override
  String get createEmployeeStepIdentity => 'זהות ופרטי קשר';

  @override
  String get createEmployeeStepRole => 'תחנה ותפקיד';

  @override
  String get createEmployeeStepAccess => 'פרטי גישה ראשוניים';

  @override
  String get createEmployeeFirstName => 'שם פרטי';

  @override
  String get createEmployeeLastName => 'שם משפחה';

  @override
  String get createEmployeeEmail => 'כתובת אימייל (אופציונלי)';

  @override
  String get createEmployeePhone => 'מספר טלפון נייד';

  @override
  String get createEmployeeCode => 'קוד עובד בתחנה (אופציונלי)';

  @override
  String get createEmployeeRoleLabel => 'הקצאת תפקיד בתחנה';

  @override
  String get createEmployeeSubmit => 'צור חשבון עובד';

  @override
  String get createEmployeeSuccessTitle => 'החשבון הוקצה בהצלחה';

  @override
  String get createEmployeeSuccessDesc =>
      'חשבון העובד נוצר. מסור את הסיסמה הזמנית החד-פעמית לעובד באופן מאובטח.';

  @override
  String get createEmployeeTempPassword => 'סיסמה זמנית חד-פעמית';

  @override
  String get createEmployeeCopyPassword => 'העתק פרטי גישה';

  @override
  String get createEmployeeCopiedToast => 'פרטי הגישה הזמניים הועתקו ללוח';

  @override
  String get createEmployeeSecurityNotice =>
      'סיסמה זמנית זו מוצגת פעם אחת בלבד ואינה נשמרת בטקסט גלוי.';

  @override
  String get inspectorTitle => 'פרטי עובד';

  @override
  String get inspectorSubtitle => 'ניהול חברות בתחנה והרשאות גישה';

  @override
  String get inspectorContactSection => 'פרטי קשר וזהות';

  @override
  String get inspectorRoleSection => 'תפקיד וסמכויות בתחנה';

  @override
  String get inspectorMembershipSection => 'תפקיד וסמכויות בתחנה';

  @override
  String get inspectorStatusSection => 'סטטוס חברות';

  @override
  String get inspectorSecuritySection => 'פעולות אבטחת חשבון';

  @override
  String get inspectorChangeRole => 'שינוי תפקיד';

  @override
  String get inspectorRoleChange => 'שינוי תפקיד';

  @override
  String get inspectorChangeStatus => 'שינוי סטטוס';

  @override
  String get inspectorResetPassword => 'איפוס סיסמה';

  @override
  String get inspectorResetPasswordConfirm =>
      'להפיק סיסמה זמנית חדשה עבור עובד זה?';

  @override
  String get inspectorRevokeSessions => 'ניתוק כל החיבורים';

  @override
  String get inspectorRevokeSessionsConfirm =>
      'לבצע התנתקות כפויה מכל ההתקנים הפעילים?';

  @override
  String get inspectorLastAdminNotice =>
      'לא ניתן להוריד בדרגה או להשבית את מנהל התחנה הפעיל האחרון.';

  @override
  String get inspectorDeactivate => 'השבת עובד';

  @override
  String get inspectorReactivate => 'הפעל עובד מחדש';

  @override
  String get inspectorActionSuccess => 'הפעולה הושלמה בהצלחה';

  @override
  String get commonCancel => 'ביטול';

  @override
  String get commonClose => 'סגור';

  @override
  String get commonSave => 'שמור';

  @override
  String get stationSettingsTitle => 'פרמטרי תפעול תחנה';

  @override
  String get stationSettingsSubtitle =>
      'ניהול קוד תחנה, אזור זמן, שפה ברירת מחדל ויום תחילת שבוע.';

  @override
  String get stationSettingsName => 'שם התחנה';

  @override
  String get stationSettingsCode => 'קוד תפעולי';

  @override
  String get stationSettingsTimezone => 'אזור זמן תפעולי';

  @override
  String get stationSettingsLocale => 'שפת ברירת מחדל';

  @override
  String get stationSettingsWeekStart => 'תחילת שבוע תפעולי';

  @override
  String get stationSettingsSunday => 'יום ראשון (שבוע ישראלי סטנדרטי)';

  @override
  String get stationSettingsMonday => 'יום שני';

  @override
  String get stationSettingsSave => 'שמור פרמטרים';

  @override
  String get stationSettingsSaved => 'פרמטרי התחנה עודכנו בהצלחה';

  @override
  String get stationSettingsSavedToast => 'פרמטרי התחנה עודכנו בהצלחה';

  @override
  String get shiftsTitle => 'תבניות משמרת';

  @override
  String get shiftsSubtitle =>
      'הגדרת משמרות עבודה בתחנה, שעות פעילות וסדר הופעה.';

  @override
  String get shiftsAddButton => 'תבנית משמרת חדשה';

  @override
  String get shiftsEmptyTitle => 'אין תבניות משמרת';

  @override
  String get shiftsEmptyDesc =>
      'הגדר את תבניות המשמרת של התחנה כדי לאפשר הגשת זמינות שבועית.';

  @override
  String get shiftsColName => 'שם המשמרת';

  @override
  String get shiftsColTimes => 'שעות פעילות';

  @override
  String get shiftsColDuration => 'משך זמן';

  @override
  String get shiftsColStatus => 'סטטוס';

  @override
  String get shiftsCrossMidnight => 'חוצה חצות (+יום למחרת)';

  @override
  String get shiftsDeactivate => 'השבת';

  @override
  String get shiftsReactivate => 'הפעל מחדש';

  @override
  String get shiftsEdit => 'ערוך משמרת';

  @override
  String get shiftsCreateDialogTitle => 'תבנית משמרת חדשה';

  @override
  String get shiftsEditDialogTitle => 'עריכת תבנית משמרת';

  @override
  String get shiftsNameLabel => 'שם המשמרת';

  @override
  String get shiftsNameHint => 'לדוגמה: בוקר, ערב, לילה...';

  @override
  String get shiftsCodeLabel => 'קוד תפעולי (אופציונלי)';

  @override
  String get shiftsCodeHint => 'לדוגמה: MOR, EVE';

  @override
  String get shiftsStartTime => 'שעת התחלה';

  @override
  String get shiftsEndTime => 'שעת סיום';

  @override
  String get shiftsSaveButton => 'שמור תבנית משמרת';

  @override
  String get permissionsTitle => 'סמכויות אחראי משמרת';

  @override
  String get permissionsSubtitle =>
      'הגדרת הרשאות תפעוליות והרשאות ניהול עבור אחראי משמרת בתחנה זו.';

  @override
  String get permissionsSectionTemplates => 'ניהול תבניות משמרת';

  @override
  String get permissionsShiftTemplatesManage =>
      'יצירה, עריכה ושינוי סדר של תבניות משמרת';

  @override
  String get permissionsSectionAvailability => 'תפעול זמינות שבועית';

  @override
  String get permissionsAvailabilityPeriodCreate =>
      'יצירת שבועות זמינות בטיוטה';

  @override
  String get permissionsAvailabilityPeriodOpen => 'פתיחת שבועות להגשת זמינות';

  @override
  String get permissionsAvailabilityPeriodClose =>
      'סגירה ופתיחה מחדש של תקופות זמינות';

  @override
  String get permissionsAvailabilityTeamRead =>
      'צפייה במטריצת זמינות צוות והגשות';

  @override
  String get permissionsSaveButton => 'שמור הגדרות סמכויות';

  @override
  String get permissionsSavedToast => 'סמכויות אחראי המשמרת עודכנו בהצלחה';

  @override
  String get availabilityTitle => 'זמינות שבועית';

  @override
  String get availabilitySubtitle =>
      'הגש את העדפות העבודה שלך למשמרות השבוע הקרוב.';

  @override
  String get availabilityNoPeriodTitle => 'אין שבוע זמינות פתוח';

  @override
  String get availabilityNoPeriodDesc =>
      'כרגע אין שבוע זמינות פתוח להגשה בתחנה זו.';

  @override
  String availabilityDeadlineNotice(String deadline) {
    return 'מועד אחרון להגשה: $deadline';
  }

  @override
  String get availabilityStatusDraft => 'טיוטה';

  @override
  String get availabilityStatusSubmitted => 'הוגש';

  @override
  String get availabilityStatusClosed => 'סגור (קריאה בלבד)';

  @override
  String get availabilityStatusNotStarted => 'טרם התחיל';

  @override
  String availabilityProgress(int answered, int total) {
    return 'נענו $answered מתוך $total משבצות';
  }

  @override
  String get availabilityAvailable => 'זמין';

  @override
  String get availabilityUnavailable => 'לא זמין';

  @override
  String get availabilityUnanswered => 'טרם סומן';

  @override
  String get availabilityAllDayAvailable => 'זמין כל היום';

  @override
  String get availabilityAllDayUnavailable => 'לא זמין כל היום';

  @override
  String get availabilitySubmitButton => 'הגש זמינות';

  @override
  String get availabilityEditNotice =>
      'עריכת משבצת שנענתה תחזיר את ההגשה למצב טיוטה עד להגשה חוזרת.';

  @override
  String availabilitySubmittedConfirmation(String week) {
    return 'הזמינות הוגשה בהצלחה לשבוע $week';
  }

  @override
  String get availabilitySavingDraft => 'שומר טיוטה...';

  @override
  String get availabilityDraftSaved => 'טיוטה נשמרה';

  @override
  String get managerAvailabilityTitle => 'מטריצת זמינות צוות';

  @override
  String get managerAvailabilitySubtitle =>
      'סקירת זמינות כוח אדם, קצב הגשות ומוכנות תפעולית לסידור.';

  @override
  String get managerKpiEligible => 'כוח אדם זכאי';

  @override
  String get managerKpiSubmitted => 'הגישו זמינות';

  @override
  String get managerKpiDraft => 'בתהליך (טיוטה)';

  @override
  String get managerKpiNotStarted => 'טרם התחילו';

  @override
  String get managerKpiNotSubmitted => 'ממתינים להגשה';

  @override
  String get managerFilterAll => 'כל העובדים';

  @override
  String get managerFilterSubmitted => 'הוגש';

  @override
  String get managerFilterDraft => 'טיוטה';

  @override
  String get managerFilterNotStarted => 'לא התחיל';

  @override
  String get managerOpenPeriod => 'פתח הגשות';

  @override
  String get managerClosePeriod => 'סגור הגשות';

  @override
  String get managerReopenPeriod => 'פתח מחדש';

  @override
  String get managerCreatePeriod => 'צור תקופת זמינות';

  @override
  String get managerPeriodHistory => 'שבועות קודמים';

  @override
  String get scheduleTitle => 'לוח משמרות שבועי';

  @override
  String get scheduleSubtitle =>
      'שיבוץ עובדים, איזון איוש ופרסום לוחות רשמיים לתחנה.';

  @override
  String get scheduleDraftStatus => 'טיוטה';

  @override
  String get schedulePublishedStatus => 'רשמי מפורסם';

  @override
  String get schedulePublishAction => 'פרסם לוח';

  @override
  String scheduleStaffingCoverage(String percent) {
    return 'כיסוי איוש: $percent%';
  }

  @override
  String get myShiftsTitle => 'המשמרות שלי';

  @override
  String get myShiftsEmptyDraft => 'טרם פורסם לוח משמרות לשבוע זה';

  @override
  String get myShiftsEmptyAssigned => 'אין לך משמרות משובצות לשבוע זה';

  @override
  String get candidateAssignAction => 'שבץ';

  @override
  String get candidateOverrideAction => 'שבץ עם חריגה';

  @override
  String get candidateAlreadyAssigned => 'משובץ';

  @override
  String get attendanceTitle => 'נוכחות בתחנה';

  @override
  String get attendanceNotCheckedIn => 'טרם נכנסת למשמרת';

  @override
  String get attendanceCurrentlyWorking => 'במשמרת פעילה כעת';

  @override
  String get attendanceScanQrAction => 'סרוק ברקוד תחנה';

  @override
  String get attendanceCheckOutAction => 'סרוק ליציאה ממשמרת';

  @override
  String get attendanceRecentHistory => 'משמרות אחרונות';

  @override
  String get attendanceLiveMonitor => 'נוכחות חיה בתחנה';

  @override
  String get navNotifications => 'התראות';

  @override
  String get notificationsTitle => 'מרכז התראות והודעות';

  @override
  String get notificationsSubtitle =>
      'עדכוני סידור עבודה, נוכחות חיה, תזכורות והתראות תפעוליות בזמן אמת';

  @override
  String get notificationsMarkAllRead => 'סמן הכל כנקרא';

  @override
  String get notificationsEmptyTitle => 'אין התראות להצגה';

  @override
  String get notificationsEmptyDesc =>
      'הכל מעודכן! התראות חדשות על סידורי עבודה ונוכחות יופיעו כאן.';

  @override
  String get notificationsUnreadOnly => 'טרם נקראו בלבד';

  @override
  String get notificationPreferencesTitle => 'הגדרות ערוצי התראות';

  @override
  String get notificationPreferencesSubtitle =>
      'ניהול ערוצי מסירה והעדפות קבלת הודעות באפליקציה, פוש, מייל ו-SMS';

  @override
  String get notificationMandatoryNotice => 'התראות אבטחה ותפעול חובה';

  @override
  String get notificationMandatoryDesc =>
      'התראות אבטחה קריטיות, חריגות זיהוי ותיקוני נוכחות ידניים נמסרים תמיד בתוך האפליקציה לצורכי בקרה ואבטחה.';

  @override
  String get notificationDeliveryMatrix => 'מטריצת ערוצים';

  @override
  String get notificationDeliveryMatrixDesc =>
      'בחר אילו התראות יימסרו בכל ערוץ תקשורת';

  @override
  String get navMyHours => 'השעות שלי';

  @override
  String get myHoursTitle => 'שעות העבודה שלי';

  @override
  String get myHoursSubtitle =>
      'ציר זמן נוכחות אישי, היסטוריית שעות ומשמרות פעילות בכל התחנות';

  @override
  String get reportsTitle => 'דוחות נוכחות ותפעול';

  @override
  String get reportsSubtitle =>
      'ריכוז שעות עבודה מאומתות, מדדי תחנה, פילוח עובדים ולוח משמרות יומי';

  @override
  String get kpiTotalWorked => 'סה״כ שעות עבודה';

  @override
  String get kpiCompletedShifts => 'משמרות שהושלמו';

  @override
  String get kpiLateShifts => 'משמרות באיחור';

  @override
  String get kpiTotalLateTime => 'סה״כ זמן איחור';

  @override
  String get kpiCorrectedRecords => 'רשומות שתוקנו';

  @override
  String get kpiActiveOpenSessions => 'משמרות פעילות כעת';

  @override
  String get kpiRepeatedLateness => 'איחורים חוזרים';

  @override
  String get kpiActiveWorkforce => 'עובדים פעילים בתחנה';

  @override
  String get kpiAverageShift => 'משך משמרת ממוצע';

  @override
  String get kpiOnTimeRate => 'שיעור הגעה בזמן';

  @override
  String get presetToday => 'היום';

  @override
  String get presetCurrentWeek => 'השבוע';

  @override
  String get presetCurrentMonth => 'החודש';

  @override
  String get presetLastMonth => 'חודש שעבר';

  @override
  String get presetCustom => 'טווח מותאם';

  @override
  String get filterAll => 'כל המשמרות';

  @override
  String get filterCompleted => 'הושלמו';

  @override
  String get filterLate => 'איחורים בלבד';

  @override
  String get filterCorrected => 'תוקנו בלבד';

  @override
  String get filterOpen => 'פעילות בלבד';

  @override
  String get tabBreakdown => 'פילוח עובדים';

  @override
  String get tabDailyBoard => 'לוח משמרות יומי';

  @override
  String get searchEmployeesPlaceholder => 'חיפוש לפי שם או קוד עובד...';

  @override
  String get employeeDrilldownTitle => 'פירוט נוכחות ותיקונים';

  @override
  String get correctionLedger => 'יומן תיקונים';

  @override
  String get noAttendanceFound => 'לא נמצאו רשומות נוכחות לתקופה שנבחרה.';

  @override
  String get selectDatePrompt => 'בחר תאריך תפעולי';

  @override
  String get statusActive => 'פעיל';

  @override
  String get statusInactive => 'לא פעיל';

  @override
  String get statusSuspended => 'מושעה';

  @override
  String get navDashboard => 'לוח בקרה';

  @override
  String get navShiftTemplates => 'תבניות משמרת';

  @override
  String get navStationSettings => 'הגדרות תחנה';

  @override
  String get navSectionWorkspace => 'סביבת עבודה אישית';

  @override
  String get navSectionManagement => 'ניהול תחנה';

  @override
  String get navSectionGeneral => 'חשבון ומערכת';

  @override
  String get switchStationContext => 'החלפת תחנה פעילה';

  @override
  String get noPhoneRegistered => 'לא הוזן מספר טלפון';

  @override
  String get noCodeAssigned => 'טרם הוגדר';

  @override
  String get notProvided => 'לא צוין';

  @override
  String get joinedStationLabel => 'הצטרף לתחנה';

  @override
  String get allStatusesFilter => 'כל הסטטוסים';

  @override
  String get filterStatusActive => 'פעילים';

  @override
  String get filterStatusInactive => 'לא פעילים';

  @override
  String get filterStatusSuspended => 'מושעים';

  @override
  String get selectEmployeePrompt => 'בחר עובד מהרשימה לצפייה בפרטים תפעוליים';

  @override
  String get colNameIdentity => 'שם וזהות';

  @override
  String get colStationRole => 'תפקיד בתחנה';

  @override
  String get colStatus => 'סטטוס';

  @override
  String get colPhone => 'טלפון';

  @override
  String get colCode => 'קוד עובד';

  @override
  String get dashboardStationOverview => 'מבט על התחנה';

  @override
  String get dashboardEmployeeNextShift => 'המשמרת הבאה שלך';

  @override
  String get dashboardEmployeeNoShift => 'אין משמרות מתוכננות להיום';

  @override
  String get dashboardEmployeeAttendanceStatus => 'מצב נוכחות היום';

  @override
  String get dashboardEmployeeActiveShift => 'משמרת פעילה כעת';

  @override
  String get dashboardEmployeeNotCheckedIn => 'אינך מדווח נוכחות כעת';

  @override
  String get dashboardEmployeeClockInAction => 'דיווח נוכחות באמצעות QR';

  @override
  String get dashboardEmployeeClockOutAction => 'סיום משמרת ויציאה';

  @override
  String get dashboardEmployeeMyHoursTitle => 'סיכום שעות עבודה';

  @override
  String get dashboardEmployeeAvailabilityTitle => 'זמינות למשמרות';

  @override
  String get dashboardEmployeeAvailabilityOpen => 'הגשת זמינות לשבוע הבא פתוחה';

  @override
  String get dashboardEmployeeAvailabilitySubmitted => 'זמינות הוגשה בהצלחה';

  @override
  String get dashboardEmployeeAvailabilityClosed =>
      'אין תקופת הגשת זמינות פעילה';

  @override
  String get dashboardManagerStaffingTitle => 'איוש מבצעי להיום';

  @override
  String dashboardManagerStaffingRequired(int count) {
    return 'דרושים: $count';
  }

  @override
  String dashboardManagerStaffingAssigned(int count) {
    return 'משובצים: $count';
  }

  @override
  String dashboardManagerStaffingCheckedIn(int count) {
    return 'נוכחים: $count';
  }

  @override
  String dashboardManagerStaffingShortage(int count) {
    return 'חוסר: $count';
  }

  @override
  String get dashboardManagerLiveAttendanceTitle => 'לוח נוכחות חי';

  @override
  String get dashboardManagerAvailabilityOverview => 'סטטוס הגשות זמינות צוות';

  @override
  String get dashboardManagerAlertsTitle => 'התראות תפעוליות';

  @override
  String dashboardManagerLateArrivals(int count) {
    return '$count איחורים';
  }

  @override
  String dashboardManagerLongSessions(int count) {
    return '$count משמרות מעל 16 שעות';
  }

  @override
  String get dashboardAdminPulseTitle => 'סיכום כוח אדם בתחנה';

  @override
  String get dashboardAdminQuickShortcuts => 'קיצורי דרך לניהול';

  @override
  String get dashboardAdminNfcSummary => 'תגי NFC בתחנה';

  @override
  String get dashboardAdminSettingsAction => 'הגדרות תחנה';

  @override
  String get dashboardAdminAddEmployeeAction => 'הוספת עובד';

  @override
  String get employeeEditTitle => 'עריכת פרטי עובד';

  @override
  String get employeeEditSubtitle =>
      'עריכת פרטי חשבון גלובליים והגדרות חברות בתחנה';

  @override
  String get employeeEditGlobalNotice =>
      'שם פרטי, שם משפחה, טלפון ושפה מועדפת חלים על הפרופיל הגלובלי.';

  @override
  String get employeeEditStationNotice =>
      'תפקיד בתחנה, סטטוס חברות וקוד עובד תקפים לתחנה זו בלבד.';

  @override
  String get employeeEditFirstNameLabel => 'שם פרטי';

  @override
  String get employeeEditLastNameLabel => 'שם משפחה';

  @override
  String get employeeEditPhoneLabel => 'מספר טלפון';

  @override
  String get employeeEditEmailLabel => 'כתובת אימייל';

  @override
  String get employeeEditLocaleLabel => 'שפת ממשק מועדפת';

  @override
  String get employeeEditRoleLabel => 'תפקיד בתחנה';

  @override
  String get employeeEditStatusLabel => 'סטטוס חברות';

  @override
  String get employeeEditCodeLabel => 'קוד עובד בתחנה';

  @override
  String get employeeEditSaveButton => 'שמירת שינויים';

  @override
  String get employeeEditSuccessToast => 'פרטי העובד עודכנו בהצלחה';

  @override
  String get employeeEditAction => 'עריכת פרופיל';

  @override
  String get employeeResetPasswordTitle => 'איפוס סיסמת עובד';

  @override
  String employeeResetPasswordConfirm(String name) {
    return 'פעולה זו תיצור סיסמה זמנית חדשה עבור $name ותנתק את כל החיבורים הפעילים.';
  }

  @override
  String get employeeResetPasswordGenerate => 'יצירת סיסמה חדשה';

  @override
  String get employeeResetPasswordSuccessTitle => 'סיסמה זמנית חדשה';

  @override
  String employeeResetPasswordSuccessDesc(String name) {
    return 'הונפקה סיסמה זמנית חדשה עבור $name:';
  }

  @override
  String get employeeResetPasswordNotice =>
      'מסור סיסמה זו לעובד. היא לא תוצג שוב במערכת.';

  @override
  String get employeeRevokeSessionsConfirm => 'ניתוק חיבורים פעילים';

  @override
  String get employeeRevokeSessionsSuccess =>
      'כל החיבורים הפעילים נותקו בהצלחה';

  @override
  String get errorLastAdminRequired =>
      'לא ניתן להסיר או להשבית את מנהל התחנה הפעיל האחרון.';

  @override
  String get errorPermissionDenied =>
      'הגישה נדחתה. אין לך הרשאות מתאימות לפעולה זו.';

  @override
  String get errorDuplicatePhone =>
      'מספר טלפון זה כבר מקושר למשתמש אחר במערכת.';

  @override
  String get errorDuplicateEmail =>
      'כתובת אימייל זו כבר מקושרת למשתמש אחר במערכת.';

  @override
  String get errorInvalidInput =>
      'הנתונים שהוזנו אינם תקינים. אנא בדוק את השדות.';

  @override
  String get errorNotFound => 'הרשומה המבוקשת לא נמצאה.';

  @override
  String get errorGeneric => 'אירעה שגיאה בלתי צפויה. אנא נסה שוב.';

  @override
  String get errorExportExpired =>
      'קישור ההורדה פג תוקף (תוקף של 15 דקות). אנא הפק ייצוא חדש.';

  @override
  String get errorActiveAttendanceBlocksDeactivation =>
      'לא ניתן להשבית תחנה כאשר ישנן משמרות פתוחות או עובדים פעילים בשעון.';

  @override
  String get dialogCancel => 'ביטול';

  @override
  String get copyPassword => 'העתקת סיסמה';

  @override
  String get passwordCopied => 'הסיסמה הועתקה ללוח';

  @override
  String get closeButton => 'סגור';

  @override
  String get navExports => 'ייצוא נתונים';

  @override
  String get navAuditCenter => 'מרכז ביקורת';

  @override
  String get navSystemHealth => 'תקינות מערכת';

  @override
  String get exportCenterTitle => 'מרכז ייצוא תפעולי';

  @override
  String get exportCenterSubtitle =>
      'הפקת קובצי נתונים תפעוליים חתומים ומאובטחים עם הגנה מפני הזרקת נוסחאות';

  @override
  String get exportMyHours => 'ייצוא שעות נוכחות אישיות';

  @override
  String get exportStationAttendanceSummary => 'סיכום נוכחות תחנתי';

  @override
  String get exportStationEmployeeWorkedHours => 'שעות עבודה לפי עובד';

  @override
  String get exportDailyAttendanceReport => 'דוח נוכחות יומי';

  @override
  String get exportAttendanceCorrectionLedger => 'יומן תיקוני נוכחות';

  @override
  String get exportPublishedSchedule => 'סידור עבודה מפורסם';

  @override
  String get exportEmployeeDirectory => 'ספר עובדים ותפקידים';

  @override
  String get exportAvailabilityOverview => 'סקירת זמינות צוות';

  @override
  String get exportFormatCsv => 'CSV (קידוד UTF-8)';

  @override
  String get exportFormatPdf => 'מסמך PDF';

  @override
  String get exportButtonGenerate => 'הפק ייצוא';

  @override
  String get exportGenerating => 'מפיק ייצוא נתונים...';

  @override
  String exportSuccess(int rowCount) {
    return 'הייצוא הופק בהצלחה ($rowCount שורות)';
  }

  @override
  String get exportDownloadButton => 'הורד קובץ';

  @override
  String get exportHistoryTitle => 'היסטוריית קבצים שהופקו';

  @override
  String get exportHistoryEmpty => 'לא נמצאו קובצי ייצוא אחרונים.';

  @override
  String get exportStatusCompleted => 'הושלם';

  @override
  String get exportStatusExpired => 'פג תוקף';

  @override
  String get exportStatusProcessing => 'בתהליך';

  @override
  String get exportStatusFailed => 'נכשל';

  @override
  String get exportExpiryNotice =>
      'קישורי ההורדה פגים אוטומטית לאחר 15 דקות מטעמי אבטחת מידע.';

  @override
  String get auditCenterTitle => 'מרכז ביקורת מנהלים';

  @override
  String get auditCenterSubtitle =>
      'יומן פעולות מנהלתיות בלתי-ניתן לשינוי עם סינון וחיפוש מתקדם';

  @override
  String get auditFilterAll => 'כל הפעילויות';

  @override
  String get auditFilterMemberships => 'עובדים והרשאות';

  @override
  String get auditFilterSchedules => 'סידורי עבודה';

  @override
  String get auditFilterAttendance => 'נוכחות ושעון';

  @override
  String get auditFilterStation => 'הגדרות תחנה';

  @override
  String get auditFilterExports => 'ייצוא נתונים';

  @override
  String get auditFilterAvailability => 'זמינות עובדים';

  @override
  String get auditSearchPlaceholder =>
      'חיפוש לפי מבצע, אימייל, פעולה או יעד...';

  @override
  String get auditEmptyLogs => 'לא נמצאו רשומות ביקורת התואמות את החיפוש.';

  @override
  String get auditMetadataTitle => 'נתוני מטא מאובטחים';

  @override
  String get auditActor => 'מבצע';

  @override
  String get auditAction => 'פעולה';

  @override
  String get auditTarget => 'יעד';

  @override
  String get auditTimestamp => 'זמן ביצוע';

  @override
  String auditPageInfo(int current, int total, int count) {
    return 'עמוד $current מתוך $total ($count אירועים)';
  }

  @override
  String get systemHealthTitle => 'תקינות תפעולית ומערכת';

  @override
  String get systemHealthSubtitle =>
      'טלמטריה חיה, מצב תגי NFC של התחנה וניהול מחזור חיי נתונים';

  @override
  String get systemHealthExportPipeline => 'צינור ייצוא נתונים (24 שעות)';

  @override
  String systemHealthExportsSummary(int count, int failed) {
    return '$count קבצים הופקו ($failed נכשלו)';
  }

  @override
  String get systemHealthAnomalies => 'תקינות והתראות מערכת';

  @override
  String get systemHealthNoAnomalies => 'כל המערכות התחנתיות תקינות';

  @override
  String systemHealthStaleSessions(int count) {
    return '$count משמרות פתוחות חריגות';
  }

  @override
  String systemHealthFailedIdentity(int count) {
    return '$count כשלים באימות זהות';
  }

  @override
  String get dataRetentionTitle => 'מדיניות שימור ומחיקת נתונים';

  @override
  String get dataRetentionSummary =>
      'רשומות נוכחות, משמרות ויומני ביקורת נשמרים לצמיתות. טוקני QR זמניים וקובצי ייצוא שפג תוקפם מנוקים אוטומטית.';

  @override
  String get dataRetentionRunButton => 'הפעל ניקוי מחזור חיים';

  @override
  String dataRetentionSuccess(int exports, int challenges) {
    return 'הניקוי הושלם: $exports קבצים סומנו כפגי תוקף, $challenges טוקני QR נוקו.';
  }

  @override
  String get stationTimezoneLabel => 'אזור זמן תחנתי (IANA)';

  @override
  String get stationTimezoneHelper =>
      'אזור הזמן המשמש לגבולות משמרת ולחישובי נוכחות';

  @override
  String get stationLateGraceMinutes => 'חלון חסד לאיחור (דקות)';

  @override
  String get stationLateGraceHelper =>
      'כניסה בטווח דקות זה תיחשב כהגעה בזמן ללא רישום איחור';

  @override
  String get stationCheckInEarlyMinutes => 'חלון כניסה מוקדמת (דקות)';

  @override
  String get stationCheckInEarlyHelper =>
      'מספר הדקות המותרות לכניסה לפני תחילת המשמרת המתוכננת';

  @override
  String get stationDangerZone => 'פעולות רגישות ומנהלתיות';

  @override
  String get stationDeactivateAction => 'השבת תחנה';

  @override
  String get stationDeactivateNotice =>
      'השבתת התחנה תחסום שעון נוכחות וסידורי עבודה.';

  @override
  String get stationDeactivateBlockedActive =>
      'לא ניתן להשבית תחנה כל עוד ישנן משמרות פתוחות או עובדים פעילים בשעון.';

  @override
  String get stationForceDeactivateConfirm => 'אישור השבתת תחנה בכפייה';

  @override
  String get connectionOnline => 'מחובר לרשת';

  @override
  String get connectionDegraded => 'חיבור איטי / לא יציב';

  @override
  String get connectionReconnecting => 'מתחבר מחדש...';

  @override
  String get connectionOffline => 'ללא חיבור — מצב קריאה בלבד';

  @override
  String get errorOfflineActionBlocked => 'פעולה זו דורשת חיבור אינטרנט פעיל.';

  @override
  String get errorReconcilingAttendance =>
      'מאמת סטטוס נוכחות לאחר פסק זמן ברשת...';

  @override
  String get appUpdateAvailable => 'קיימת גרסה חדשה למערכת YellowShifts.';

  @override
  String get appUpdateReloadNow => 'רענן כעת';

  @override
  String get appUpdateLater => 'מאוחר יותר';

  @override
  String get startupConfigError => 'שגיאת תצורה';

  @override
  String get startupConfigErrorMessage =>
      'אתחול המערכת נכשל עקב תצורת סביבה לא תקינה.';

  @override
  String get startupLoading => 'טוען את המערכת...';

  @override
  String get startupRetry => 'נסה שוב';

  @override
  String get errorRateLimited =>
      'יותר מדי בקשות ברצף. אנא המתן מספר שניות ונסה שוב.';

  @override
  String get errorScheduleConflict => 'זוהתה התנגשות בשיבוץ המשמרת.';

  @override
  String get errorVersionConflict =>
      'לוח המשמרות עודכן על ידי מנהל אחר. אנא רענן את המסך.';

  @override
  String get errorStationDeactivated => 'תחנה זו אינה פעילה כעת.';

  @override
  String get errorMembershipDeactivated =>
      'חברותך בתחנה זו אינה פעילה או הושעתה.';

  @override
  String get errorTimeout => 'פסק זמן לבקשה. אנא בדוק את החיבור לרשת.';

  @override
  String get errorServiceUnavailable =>
      'השרת אינו זמין זמנית. אנא נסה שוב בקרוב.';

  @override
  String get systemHealthHealthy => 'תקין';

  @override
  String get systemHealthDegraded => 'מופחת';

  @override
  String get systemHealthUnavailable => 'לא זמין';

  @override
  String get systemHealthUnknown => 'לא ידוע';

  @override
  String get settingsTitle => 'הגדרות והעדפות';

  @override
  String get settingsSubtitle => 'ניהול זהות משתמש, שפה והגדרות תפעול תחנה';

  @override
  String get settingsUserProfile => 'פרופיל משתמש';

  @override
  String settingsUserPhone(String phone) {
    return 'טלפון: $phone';
  }

  @override
  String get settingsNotifications => 'העדפות התראות';

  @override
  String get settingsNotificationsSubtitle =>
      'הגדרת ערוצי קבלת התראות באפליקציה, פוש, אימייל ו-SMS';

  @override
  String get settingsStationAdmin => 'ניהול תחנה';

  @override
  String get settingsOperationalParams => 'פרמטרים תפעוליים';

  @override
  String get settingsOperationalParamsSubtitle =>
      'אזור זמן, קוד, שפה ותחילת שבוע';

  @override
  String get settingsShiftTemplates => 'תבניות משמרת';

  @override
  String get settingsShiftTemplatesSubtitle =>
      'הגדרת משמרות עבודה, שעות וסדר תצוגה';

  @override
  String get settingsShiftManagerCaps => 'סמכויות מנהל משמרת';

  @override
  String get settingsShiftManagerCapsSubtitle =>
      'החרגות הרשאות ייעודיות לתחנה עבור מנהלי משמרת';

  @override
  String get settingsExportCenter => 'מרכז ייצוא דוחות תפעוליים';

  @override
  String get settingsExportCenterSubtitle =>
      'הפקת קובצי CSV ו-PDF מוסמכים של דוחות תפעול';

  @override
  String get settingsAuditCenter => 'יומן ביקורת תפעולי';

  @override
  String get settingsAuditCenterSubtitle =>
      'בדיקת יומן פעולות ניהול כרונולוגי ובלתי ניתן לשינוי';

  @override
  String get settingsSystemHealth => 'תקינות תפעולית ומחזור חיים';

  @override
  String get settingsSystemHealthSubtitle =>
      'טלמטריה חיה, תקינות תגי NFC של התחנה ותחזוקת נתונים';

  @override
  String get settingsCurrentStationDetails => 'פרטי תחנה נוכחית';

  @override
  String get settingsStationName => 'שם התחנה';

  @override
  String get settingsStationCode => 'קוד תפעולי';

  @override
  String get settingsStationTimezone => 'אזור זמן';

  @override
  String get settingsStationLocale => 'שפת ממשק תחנתית';

  @override
  String get settingsLanguageDirection => 'שפה וכיווניות';

  @override
  String get settingsSignOut => 'התנתק מ-YellowShifts';

  @override
  String get systemHealthDefenseSubtitle => 'הושלם עם הגנת נוסחאות בצד שרת';

  @override
  String get systemHealthStaleSessionsSubtitle =>
      'משמרות פתוחות מעל 16 שעות הדורשות בדיקת מנהל';

  @override
  String get exportPreset7Days => '7 ימים';

  @override
  String get exportPreset30Days => '30 ימים';

  @override
  String get exportPresetThisMonth => 'החודש';

  @override
  String get exportPresetLastMonth => 'חודש שעבר';

  @override
  String get exportPresetCustom => 'מותאם אישית';

  @override
  String get exportFormatLabel => 'פורמט קובץ';

  @override
  String availabilityDeadlineInfo(String deadline, int count) {
    return 'מועד אחרון: $deadline • $count משמרות ביום';
  }

  @override
  String availabilitySlotsAnswered(int answered, int total) {
    return '$answered מתוך $total משבצות סומנו';
  }

  @override
  String get statusOpen => 'פתוח';

  @override
  String get statusClosed => 'סגור';

  @override
  String get statusDraft => 'טיוטה';

  @override
  String get statusSubmitted => 'הוגש';

  @override
  String get statusNotStarted => 'לא התחיל';

  @override
  String get noEmployeeRecordsFound => 'לא נמצאו רשומות עובדים.';

  @override
  String get stationSectionIdentity => 'זהות ופרטי תחנה';

  @override
  String get stationSectionRegional => 'ברירות מחדל אזוריות ולוח שנה';

  @override
  String get stationSectionGrace => 'מדיניות משמרות וחלונות חסד';

  @override
  String get stationActiveStatus => 'תחנה פעילה';

  @override
  String get stationDeactivatedStatus => 'תחנה מושבתת';

  @override
  String get stationActiveDesc =>
      'עמדות קיוסק ושעוני נוכחות פתוחים לפעילות תקינה.';

  @override
  String get stationDeactivatedDesc => 'התחנה מושהית וחסומה מכל פעילות מבצעית.';

  @override
  String get policyOptionDisabledTitle => 'מושבת (קוד QR בלבד)';

  @override
  String get policyOptionDisabledSubtitle =>
      'נוכחות נעשית באמצעות ברקודי QR מתחלפים בלבד.';

  @override
  String get policyOptionCheckInOnlyTitle => 'בכניסה בלבד (מומלץ)';

  @override
  String get policyOptionCheckInOnlySubtitle =>
      'מחייב אימות ביומטרי בכניסה. יציאה באמצעות קוד QR בלבד.';

  @override
  String get policyOptionStrictTitle => 'מחמיר: כניסה ויציאה';

  @override
  String get policyOptionStrictSubtitle =>
      'מחייב אימות ביומטרי הן בכניסה והן ביציאה מהמשמרת.';

  @override
  String get policyApplyAction => 'החל שינוי מדיניות';

  @override
  String get policyTeamReadinessTitle => 'מוכנות ביומטרית של הצוות';

  @override
  String get policyNoMembersRegistered => 'אין עובדים פעילים רשומים בתחנה.';

  @override
  String get kpiWorkingNow => 'עובדים כעת';

  @override
  String get kpiUpcoming => 'משמרות קרובות';

  @override
  String get kpiLate => 'איחורים';

  @override
  String get kpiCompleted => 'הושלמו';

  @override
  String get kpiNotCheckedIn => 'טרם נכנסו';

  @override
  String get attendanceRosterTitle => 'סידור משמרות להיום';

  @override
  String rosterScheduledCount(int count) {
    return '$count משמרות מתוזמנות';
  }

  @override
  String get noEmployeesScheduledToday => 'אין עובדים מתוזמנים להיום.';

  @override
  String get attendanceStatusWorking => 'בעבודה';

  @override
  String get attendanceStatusUpcoming => 'קרובה';

  @override
  String attendanceStatusLate(int minutes) {
    return 'איחור $minutes דק\'';
  }

  @override
  String get attendanceStatusCompleted => 'הושלמה';

  @override
  String get attendanceStatusNotCheckedIn => 'Not Checked In';

  @override
  String get attendanceScanPrompt =>
      'הצמד את הטלפון לתג ה-NFC של התחנה כדי להתחיל את המשמרת';

  @override
  String get attendanceActiveShift => 'משמרת פעילה';

  @override
  String attendanceLateDuration(int minutes) {
    return 'איחור של $minutes דק\'';
  }

  @override
  String get attendanceConfirmCheckIn => 'אישור כניסה למשמרת';

  @override
  String get attendanceConfirmCheckOut => 'אישור יציאה ממשמרת';

  @override
  String get shiftLabel => 'משמרת';

  @override
  String get scheduledShift => 'משמרת מתוזמנת';

  @override
  String get scheduledWindow => 'חלון זמן מתוזמן';

  @override
  String get workedTimeLabel => 'זמן עבודה';

  @override
  String get checkInNowAction => 'היכנס למשמרת עכשיו';

  @override
  String get checkOutNowAction => 'צא ממשמרת עכשיו';

  @override
  String get correctionDialogTitle => 'תיקון דיווח נוכחות';

  @override
  String get correctionReasonLabel => 'סיבת תיקון (חובה)';

  @override
  String get correctionReasonHint =>
      'לדוגמה: עובד שכח לדווח יציאה בטאבלט העמדה';

  @override
  String get correctionSaveAction => 'שמור תיקון';

  @override
  String get checkInLabel => 'כניסה';

  @override
  String get checkOutLabel => 'יציאה';

  @override
  String get attendanceNoHistory => 'אין היסטוריית נוכחות מתועדת עדיין.';

  @override
  String get attendanceWorkShift => 'משמרת עבודה';

  @override
  String get timeNow => 'עכשיו';

  @override
  String get identityVerifyingFace => 'מאמת חיות פנים...';

  @override
  String kpiActiveEmployees(int count) {
    return '$count עובדים פעילים';
  }

  @override
  String kpiActiveOpen(int count) {
    return '$count פעילות כעת';
  }

  @override
  String kpiLateShiftsCount(int count, int minutes) {
    return '$count משמרות באיחור ($minutes דק\')';
  }

  @override
  String get kpiEmployeesLateThreshold => 'עובדים עם 3+ איחורים';

  @override
  String get kpiAttentionBadge => 'לתשומת לב';

  @override
  String get kpiManualAdjustmentsAudited => 'התאמות ידניות מבוקרות';

  @override
  String workforceRecordsTitle(int count) {
    return 'רשומות כוח אדם ($count)';
  }

  @override
  String get tableColEmployee => 'עובד';

  @override
  String get tableColCode => 'קוד';

  @override
  String get tableColWorkedTime => 'שעות עבודה';

  @override
  String get tableColCompleted => 'הושלמו';

  @override
  String get tableColLateShifts => 'איחורים';

  @override
  String get tableColCorrections => 'תיקונים';

  @override
  String get tableColStatus => 'סטטוס';

  @override
  String get repeatedLatenessTag => 'איחורים חוזרים (3+)';

  @override
  String get tableMetricWorked => 'עבודה';

  @override
  String get tableMetricShifts => 'משמרות';

  @override
  String get tableMetricLate => 'איחור';

  @override
  String get tableMetricCorrected => 'תוקן';

  @override
  String get dailyNoRecords => 'אין משמרות מתוזמנות או דיווחי כניסה בתאריך זה.';

  @override
  String dailyScheduledShiftsTitle(int count) {
    return 'משמרות תפעוליות מתוזמנות ($count)';
  }

  @override
  String dailyWalkInTitle(int count) {
    return 'נוכחות לא מתוזמנת ($count)';
  }

  @override
  String dailyRequiredStaff(int count) {
    return 'נדרש: $count';
  }

  @override
  String dailyAssignedStaff(int count) {
    return 'שובצו: $count';
  }

  @override
  String dailyCheckedInStaff(int count) {
    return 'נכנסו: $count';
  }

  @override
  String dailyLateStaff(int count) {
    return 'באיחור: $count';
  }

  @override
  String dailyActiveOpenStaff(int count) {
    return 'פעילות כעת: $count';
  }

  @override
  String get dailyNoShiftRecords =>
      'טרם נרשמו דיווחי נוכחות למשמרת מתוזמנת זו.';

  @override
  String get checkedInLabel => 'כניסה';

  @override
  String lateMinutesLabel(int minutes) {
    return 'איחור $minutes דק\'';
  }

  @override
  String shiftHistoryTitle(int count) {
    return 'היסטוריית משמרות ($count)';
  }

  @override
  String get allStationsFilter => 'כל התחנות';

  @override
  String stationsWorkedCount(int count) {
    return '$count תחנות';
  }

  @override
  String lateTimeDuration(int minutes) {
    return 'זמן איחור $minutes דק\'';
  }

  @override
  String get repeatedBadge => 'חוזר';

  @override
  String get operationalWeekRange => 'טווח שבוע תפעולי';

  @override
  String get submissionDeadline => 'מועד אחרון להגשה';

  @override
  String get operationalNotesOptional => 'הערות תפעוליות (אופציונלי)';

  @override
  String get operationalNotesHint =>
      'לדוגמה: נדרש כיסוי חגים, מינימום 4 משמרות...';

  @override
  String get createPeriodAction => 'צור תקופה';

  @override
  String get submissionDeadlineFutureError =>
      'מועד ההגשה האחרון חייב להיות בעתיד.';

  @override
  String get reportsAccessRestrictedTitle => 'הגישה מוגבלת';

  @override
  String get reportsAccessRestrictedDesc =>
      'עליך להיות מנהל תחנה פעיל או מנהל מערכת כדי לצפות בדוחות תפעוליים.';

  @override
  String get walkInShift => 'משמרת ללא שיבוץ';

  @override
  String get activeShiftInProgress => 'משמרת פעילה כעת';

  @override
  String get shiftExceedsWarning =>
      'המשמרת עולה על 16 שעות. יש לבדוק את סטטוס היציאה.';

  @override
  String get repeatedLatenessPattern =>
      'דפוס איחורים חוזר: 3 או יותר איחורים בתקופת דיווח זו.';

  @override
  String get attendanceCorrectionHistory => 'היסטוריית נוכחות ותיקונים';

  @override
  String get noRecordsInPeriod => 'אין רשומות נוכחות בתקופה זו.';

  @override
  String correctionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תיקונים',
      one: 'תיקון 1',
    );
    return '$_temp0';
  }

  @override
  String correctionByActor(String name) {
    return 'בוצע ע\"י: $name';
  }

  @override
  String correctionDurationChange(String oldDuration, String newDuration) {
    return 'משך זמן: $oldDuration -> $newDuration';
  }

  @override
  String correctionReasonPrefix(String reason) {
    return 'סיבה: \"$reason\"';
  }

  @override
  String get stationLabel => 'תחנה';

  @override
  String get kpiWorkedHours => 'שעות עבודה';

  @override
  String get kpiLateArrivals => 'איחורים';

  @override
  String get statusCorrected => 'תוקן';

  @override
  String get rolePlatformAdmin => 'מנהל פלטפורמה';

  @override
  String get roleStationManager => 'מנהל תחנה';

  @override
  String get platformAdminTitle => 'ניהול הפלטפורמה';

  @override
  String get platformAdminMode => 'מצב פלטפורמה';

  @override
  String get platformOverviewTitle => 'סקירת פלטפורמה';

  @override
  String get platformOverviewSubtitle =>
      'סיכום תפעולי כלל-רשתי למפעילי YellowShifts.';

  @override
  String get platformNavOverview => 'סקירה';

  @override
  String get platformNavStations => 'תחנות';

  @override
  String get platformNavAudit => 'ביקורת / תפעול';

  @override
  String get platformNavHealth => 'בריאות המערכת';

  @override
  String get platformStationsTitle => 'תחנות';

  @override
  String get platformStationsSubtitle =>
      'הקמה, בקרה והפעלה של כל תחנה ברשת YellowShifts.';

  @override
  String get platformCreateStation => 'יצירת תחנה';

  @override
  String get platformCreateStationTitle => 'יצירת תחנה';

  @override
  String get platformCreateStationSubtitle =>
      'הקמת תחנה ושיוך מנהל התחנה הראשוני.';

  @override
  String get platformStationName => 'שם התחנה';

  @override
  String get platformStationCode => 'קוד תחנה';

  @override
  String get platformStationTimezone => 'אזור זמן';

  @override
  String get platformStationLocale => 'שפה';

  @override
  String get platformStationStatus => 'סטטוס';

  @override
  String get platformWeekStart => 'תחילת השבוע';

  @override
  String get platformWeekStartSunday => 'יום ראשון';

  @override
  String get platformWeekStartMonday => 'יום שני';

  @override
  String get platformInitialManager => 'מנהל תחנה ראשוני';

  @override
  String get platformManagerEmail => 'אימייל מנהל';

  @override
  String get platformManagerFirstName => 'שם פרטי';

  @override
  String get platformManagerLastName => 'שם משפחה';

  @override
  String get platformManagerPhone => 'טלפון (אופציונלי)';

  @override
  String get platformAssignManager => 'שיוך מנהל תחנה';

  @override
  String get platformAddManager => 'הוספת מנהל תחנה';

  @override
  String get platformReplaceManager => 'החלפת מנהל תחנה';

  @override
  String get platformRemoveManager => 'הסרת תפקיד מנהל';

  @override
  String get platformDeactivateManager => 'השבתת מנהל תחנה';

  @override
  String get platformReactivateManager => 'הפעלת מנהל תחנה מחדש';

  @override
  String get platformStationManagers => 'מנהלי תחנה';

  @override
  String get platformStationManagersSubtitle =>
      'רק מנהל פלטפורמה יכול להעניק או לבטל הרשאות מנהל תחנה.';

  @override
  String get platformDeactivateStation => 'השבתת תחנה';

  @override
  String get platformReactivateStation => 'הפעלת תחנה מחדש';

  @override
  String get platformOpenStation => 'פתיחת תחנה';

  @override
  String get platformOperatingStation => 'הפעלת תחנה';

  @override
  String platformOperatingBanner(String stationName) {
    return 'מנהל פלטפורמה · מפעיל: $stationName';
  }

  @override
  String get platformReturnToPlatform => 'חזרה לניהול הפלטפורמה';

  @override
  String get platformConfirmDeactivateTitle => 'להשבית את התחנה?';

  @override
  String get platformConfirmDeactivateBody =>
      'גישת התחנה הרגילה תיחסם. היסטוריית נוכחות, סידורים ורשומות ביקורת יישמרו.';

  @override
  String get platformConfirmRemoveManagerTitle => 'להסיר הרשאת מנהל תחנה?';

  @override
  String get platformConfirmRemoveManagerBody =>
      'המשתמש לא יוכל עוד לשמש מנהל תחנה. חייב להישאר מנהל תחנה פעיל אחד לפחות.';

  @override
  String get platformReasonLabel => 'סיבה';

  @override
  String get platformReasonHint => 'תארו מדוע נדרש השינוי';

  @override
  String get platformForceDeactivate => 'השבתה כפויה למרות פעילות פתוחה';

  @override
  String get platformMetricTotalStations => 'סה״כ תחנות';

  @override
  String get platformMetricActiveStations => 'תחנות פעילות';

  @override
  String get platformMetricInactiveStations => 'תחנות מושבתות';

  @override
  String get platformMetricActiveMemberships => 'חברויות פעילות';

  @override
  String get platformMetricStationAdmins => 'מנהלי תחנה';

  @override
  String get platformMetricShiftManagers => 'מנהלי משמרת';

  @override
  String get platformMetricAlerts => 'התרעות תפעול';

  @override
  String get platformColEmployees => 'עובדים פעילים';

  @override
  String get platformColManagers => 'מנהלי תחנה';

  @override
  String get platformColShiftManagers => 'מנהלי משמרת';

  @override
  String get platformHealthSummary => 'בריאות תפעולית';

  @override
  String get platformAuditTitle => 'ביקורת פלטפורמה';

  @override
  String get platformAuditSubtitle =>
      'צפייה באירועי פלטפורמה ותחנות. מנהלי תחנה נשארים בגבולות התחנה בלבד.';

  @override
  String get platformAuditFilterAction => 'פעולה';

  @override
  String get platformHealthTitle => 'בריאות הפלטפורמה';

  @override
  String get platformHealthSubtitle =>
      'אותות מצרפיים של קיוסק, ייצוא, נוכחות והתראות בכל הרשת.';

  @override
  String get platformUnauthorizedTitle => 'ניהול הפלטפורמה אינו זמין';

  @override
  String get platformUnauthorizedBody =>
      'אזור זה מיועד למנהלי פלטפורמה פעילים בלבד.';

  @override
  String get platformEmptyStations => 'עדיין לא הוקמו תחנות.';

  @override
  String get platformCreatedToast => 'התחנה נוצרה בהצלחה';

  @override
  String get platformUpdatedToast => 'התחנה עודכנה';

  @override
  String get platformDeactivatedToast => 'התחנה הושבתה';

  @override
  String get platformReactivatedToast => 'התחנה הופעלה מחדש';

  @override
  String get platformManagerAssignedToast => 'מנהל התחנה שויך';

  @override
  String get platformColNfcTags => 'תגי NFC';

  @override
  String get platformMetricNfcActive => 'תגי NFC פעילים';

  @override
  String get platformMetricNfcTotal => 'סה״כ תגי NFC';

  @override
  String get attendanceScanNfcAction => 'סריקת תג NFC של התחנה';

  @override
  String get settingsNfcTags => 'תגי NFC של התחנה';

  @override
  String get settingsNfcTagsSubtitle =>
      'הקצאה, תכנות וניהול תגי NFC פיזיים של התחנה';

  @override
  String get nfcTagsManagementTitle => 'תגי NFC של התחנה';

  @override
  String get nfcProvisionNewTitle => 'הקצאת תג NFC חדש';

  @override
  String get nfcProvisionDialogDesc =>
      'רישום מזהה תג NFC בשרת והכנתו לצריבה פיזית.';

  @override
  String get nfcTagNameLabel => 'שם התג';

  @override
  String get nfcTagNameHint => 'לדוגמה: תג כניסה ראשית, תג מטבח';

  @override
  String get nfcTagIdLabel => 'מזהה תג';

  @override
  String get nfcStationCodeLabel => 'קוד תחנה';

  @override
  String get nfcReadyToWriteDesc =>
      'לחץ למטה כדי לצרוב פיזית את פרטי התחנה על גבי כרטיס/מדבקת NFC ריקה.';

  @override
  String get nfcCreateTagAction => 'רישום תג';

  @override
  String get nfcWriteToCardAction => 'צריבה לתג NFC';

  @override
  String get nfcHoldToWritePrompt =>
      'הצמד את הטלפון לתג NFC ריק לצריבת נתוני התחנה.';

  @override
  String get nfcTagWrittenSuccess => 'תג NFC נצרב בהצלחה!';

  @override
  String get nfcWriteTagTitle => 'צריבה לתג פיזי';

  @override
  String get nfcTagCreatedServerDesc =>
      'התג נרשם בשרת. הצמד את המכשיר לצריבת התג הפיזי.';

  @override
  String get nfcNoTagsTitle => 'אין תגי NFC בתחנה';

  @override
  String get nfcNoTagsDesc =>
      'הקצה תג NFC פיזי לתחנה זו כדי לאפשר לעובדים לדווח נוכחות.';

  @override
  String get nfcTagStatusActive => 'פעיל';

  @override
  String get nfcTagStatusRevoked => 'מבוטל';

  @override
  String nfcLastScanned(String time) {
    return 'סריקה אחרונה: $time';
  }

  @override
  String get nfcNeverScanned => 'מעולם לא נסרק';

  @override
  String get nfcReplaceAction => 'החלפה';

  @override
  String get nfcRevokeAction => 'ביטול';

  @override
  String get nfcReactivateAction => 'הפעלה מחדש';

  @override
  String get nfcReplaceTagTitle => 'החלפת תג NFC לתחנה';

  @override
  String get nfcReplaceTagWarning =>
      'פעולה זו תבטל לצמיתות את התג הפיזי הנוכחי ותייצר פרטי זיהוי לתג חלופי חדש.';

  @override
  String get nfcNewTagNameLabel => 'שם התג החלופי';

  @override
  String get nfcReplaceTagConfirm => 'החלף תג';

  @override
  String get nfcTagReplacedSuccess => 'התג הוחלף בהצלחה';

  @override
  String get nfcTagRevokedToast => 'תג ה-NFC בוטל';

  @override
  String get nfcTagReactivatedToast => 'תג ה-NFC הופעל מחדש';

  @override
  String get nfcUnavailableError => 'רכיב NFC אינו זמין או מושבת במכשיר זה.';

  @override
  String get nfcScanCheckInPrompt =>
      'הצמד את הטלפון לתג ה-NFC של התחנה לכניסה.';

  @override
  String get nfcScanCheckOutPrompt =>
      'הצמד את הטלפון לתג ה-NFC של התחנה ליציאה.';

  @override
  String get nfcCheckInTitle => 'סריקת תג NFC של התחנה';

  @override
  String get nfcCheckOutTitle => 'סריקת תג NFC של התחנה';

  @override
  String get nfcHoldNearPrompt =>
      'הצמד את המכשיר לתג ה-NFC הפיזי בתחנה לרישום נוכחות.';

  @override
  String get nfcVerifyingPresence => 'מאמת תג תחנה...';

  @override
  String get nfcAuthorizingBackend =>
      'בודק נוכחות פיזית וחוקי משמרת מול השרת...';

  @override
  String get nfcCheckInSuccess => 'כניסה אומתה בהצלחה!';

  @override
  String get nfcCheckOutSuccess => 'יציאה אומתה בהצלחה!';

  @override
  String get nfcVerificationFailed => 'אימות נוכחות נכשל';

  @override
  String get auditFilterNfcTags => 'תגי NFC של התחנה';

  @override
  String get systemHealthNfcFleet => 'תגי NFC בתחנה';

  @override
  String systemHealthNfcActive(int active, int total) {
    return '$active מתוך $total פעילים';
  }

  @override
  String get systemHealthNfcTagsHealthy =>
      'כל תגי ה-NFC של התחנה פעילים ותקינים';

  @override
  String get systemHealthNfcNoActiveTags => 'לא הוגדרו תגי NFC פעילים לתחנה זו';

  @override
  String get platformManagerRemovedToast => 'תפקיד מנהל התחנה הוסר';

  @override
  String get platformManagedByPlatform => 'מנוהל באמצעות ניהול הפלטפורמה';

  @override
  String get platformAdminRoleReadonlyHint =>
      'הרשאות מנהל תחנה משויכות רק על ידי ניהול הפלטפורמה.';

  @override
  String get errorNotPlatformAdmin =>
      'יש להיות מנהל פלטפורמה פעיל כדי לבצע פעולה זו.';

  @override
  String get errorStationCodeConflict => 'קוד תחנה זה כבר בשימוש.';

  @override
  String get errorStationAlreadyInactive => 'התחנה כבר מושבתת.';

  @override
  String get errorStationAlreadyActive => 'התחנה כבר פעילה.';

  @override
  String get errorStationProvisioningFailed =>
      'הקמת התחנה נכשלה. לא נותרה תחנה חלקית פעילה.';

  @override
  String get errorStationAdminRoleForbidden =>
      'מנהלי תחנה אינם יכולים להעניק או לבטל הרשאות מנהל תחנה.';
}
