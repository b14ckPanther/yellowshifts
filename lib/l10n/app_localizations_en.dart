// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'YellowShifts';

  @override
  String get appTagline => 'Workforce Operations Platform';

  @override
  String get navHome => 'Home';

  @override
  String get navSchedule => 'Schedule';

  @override
  String get navAttendance => 'Attendance';

  @override
  String get navEmployees => 'Employees';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAvailability => 'Availability';

  @override
  String get navReports => 'Reports';

  @override
  String get navDesignSystem => 'Design System';

  @override
  String get loginTitle => 'Sign In to YellowShifts';

  @override
  String get loginSubtitle =>
      'Enter your credentials to access your station operations.';

  @override
  String get loginEmailLabel => 'Email Address';

  @override
  String get loginEmailHint => 'name@yellowshifts.com';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginPasswordHint => 'Enter your password';

  @override
  String get loginButton => 'Sign In to Operations';

  @override
  String get loginLoading => 'Authenticating...';

  @override
  String get loginInvalidCredentials =>
      'Invalid email or password. Please verify and try again.';

  @override
  String get loginNetworkError =>
      'Unable to connect to the server. Check your network connection.';

  @override
  String get loginValidationEmpty =>
      'Please enter both your email address and password.';

  @override
  String get loginHeroTitle =>
      'Operational Velocity.\nMulti-Station Precision.';

  @override
  String get loginHeroSubtitle =>
      'A modern workforce operations engine designed for stations, shift managers, and field staff with real-time synchronization.';

  @override
  String get loginHeroBadge => 'YellowShifts Operations • Supabase Verified';

  @override
  String get stationSelectTitle => 'Select Station';

  @override
  String get stationSelectSubtitle =>
      'You belong to multiple stations. Choose an active station to proceed.';

  @override
  String get stationSelectAction => 'Enter Station';

  @override
  String get stationActiveBadge => 'Active';

  @override
  String get stationInactiveBadge => 'Inactive';

  @override
  String get emptyStationsTitle => 'No Active Station Selected';

  @override
  String get emptyStationsDescription =>
      'Please select or request access to a station to access operational features.';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleShiftManager => 'Shift Manager';

  @override
  String get roleEmployee => 'Employee';

  @override
  String get dashboardTitle => 'Station Overview';

  @override
  String dashboardWelcome(String name) {
    return 'Welcome back, $name';
  }

  @override
  String dashboardActiveStation(String stationName) {
    return 'Current Station: $stationName';
  }

  @override
  String get dashboardStationCode => 'Station Code';

  @override
  String get dashboardTimezone => 'Timezone';

  @override
  String get dashboardRole => 'Your Role';

  @override
  String get dashboardQuickStats => 'Operational Pulse';

  @override
  String get dashboardRealtimeSync => 'Realtime Connected';

  @override
  String get dashboardActiveMembers => 'Active Workforce';

  @override
  String get dashboardAdminsCount => 'Administrators';

  @override
  String get dashboardManagersCount => 'Shift Managers';

  @override
  String get dashboardEmployeesCount => 'Employees';

  @override
  String get dashboardEmptyOnboardingTitle => 'Welcome to Your New Station';

  @override
  String get dashboardEmptyOnboardingDesc =>
      'Your station has been provisioned. Begin by adding your first employee or configuring station operating parameters.';

  @override
  String get employeesTitle => 'Employee Directory';

  @override
  String get employeesSubtitle =>
      'Manage workforce accounts, station roles, and access security.';

  @override
  String get employeesSearchHint =>
      'Search by name, phone, or employee code...';

  @override
  String get employeesFilterAllRoles => 'All Roles';

  @override
  String get employeesFilterAllStatus => 'All Statuses';

  @override
  String get employeesAddButton => 'New Employee';

  @override
  String get employeesEmptyTitle => 'No Employees Found';

  @override
  String get employeesEmptyDesc =>
      'No employees have been registered in this station yet.';

  @override
  String get employeesEmptySearchDesc =>
      'No workforce records matched your search query.';

  @override
  String get employeesColName => 'Name & Identity';

  @override
  String get employeesColRole => 'Station Role';

  @override
  String get employeesColStatus => 'Status';

  @override
  String get employeesColPhone => 'Phone';

  @override
  String get employeesColCode => 'Code';

  @override
  String get employeesColActions => 'Actions';

  @override
  String get createEmployeeTitle => 'Provision Employee Account';

  @override
  String get createEmployeeSubtitle =>
      'Create a new workforce account or assign an existing member to this station.';

  @override
  String get createEmployeeStepIdentity => 'Identity & Contact';

  @override
  String get createEmployeeStepRole => 'Station & Role';

  @override
  String get createEmployeeStepAccess => 'Access Credentials';

  @override
  String get createEmployeeFirstName => 'First Name';

  @override
  String get createEmployeeLastName => 'Last Name';

  @override
  String get createEmployeeEmail => 'Email Address (Optional)';

  @override
  String get createEmployeePhone => 'Mobile Phone Number';

  @override
  String get createEmployeeCode => 'Station Employee Code (Optional)';

  @override
  String get createEmployeeRoleLabel => 'Assign Station Role';

  @override
  String get createEmployeeSubmit => 'Create Employee Account';

  @override
  String get createEmployeeSuccessTitle => 'Account Provisioned Successfully';

  @override
  String get createEmployeeSuccessDesc =>
      'The employee account has been created. Provide the one-time temporary credentials to the employee securely.';

  @override
  String get createEmployeeTempPassword => 'One-Time Temporary Password';

  @override
  String get createEmployeeCopyPassword => 'Copy Credentials';

  @override
  String get createEmployeeCopiedToast =>
      'Temporary credentials copied to clipboard';

  @override
  String get createEmployeeSecurityNotice =>
      'This temporary password is only displayed once and is never stored in plaintext.';

  @override
  String get inspectorTitle => 'Employee Details';

  @override
  String get inspectorSubtitle => 'Station membership and access management';

  @override
  String get inspectorContactSection => 'Contact & Identity';

  @override
  String get inspectorRoleSection => 'Station Role & Authority';

  @override
  String get inspectorMembershipSection => 'Station Role & Authority';

  @override
  String get inspectorStatusSection => 'Membership Status';

  @override
  String get inspectorSecuritySection => 'Account Security Actions';

  @override
  String get inspectorChangeRole => 'Change Role';

  @override
  String get inspectorRoleChange => 'Change Role';

  @override
  String get inspectorChangeStatus => 'Change Status';

  @override
  String get inspectorResetPassword => 'Reset Password';

  @override
  String get inspectorResetPasswordConfirm =>
      'Generate new temporary credentials for this employee?';

  @override
  String get inspectorRevokeSessions => 'Revoke All Sessions';

  @override
  String get inspectorRevokeSessionsConfirm =>
      'Force sign-out all active sessions for this user?';

  @override
  String get inspectorLastAdminNotice =>
      'Cannot demote or deactivate the last Administrator of this station.';

  @override
  String get inspectorDeactivate => 'Deactivate Employee';

  @override
  String get inspectorReactivate => 'Reactivate Employee';

  @override
  String get inspectorActionSuccess => 'Operation completed successfully';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonDone => 'Done';

  @override
  String get dialogOk => 'OK';

  @override
  String get stationSettingsTitle => 'Station Operational Parameters';

  @override
  String get stationSettingsSubtitle =>
      'Manage station code, timezone, locale, and operational week start.';

  @override
  String get stationSettingsName => 'Station Name';

  @override
  String get stationSettingsCode => 'Operational Code';

  @override
  String get stationSettingsTimezone => 'Operational Timezone';

  @override
  String get stationSettingsLocale => 'Default Locale';

  @override
  String get stationSettingsWeekStart => 'Operational Week Starts On';

  @override
  String get stationSettingsSunday => 'Sunday (Standard Israeli Week)';

  @override
  String get stationSettingsMonday => 'Monday';

  @override
  String get stationSettingsSave => 'Save Station Parameters';

  @override
  String get stationSettingsSaved => 'Station parameters updated successfully';

  @override
  String get stationSettingsSavedToast =>
      'Station parameters updated successfully';

  @override
  String get shiftsTitle => 'Shift Templates';

  @override
  String get shiftsSubtitle =>
      'Configure station working shifts, operational hours, and ordering.';

  @override
  String get shiftsAddButton => 'Add Shift Template';

  @override
  String get shiftsEmptyTitle => 'No Shift Templates';

  @override
  String get shiftsEmptyDesc =>
      'Define your station\'s shift templates to enable weekly availability submissions.';

  @override
  String get shiftsColName => 'Shift Name';

  @override
  String get shiftsColTimes => 'Hours';

  @override
  String get shiftsColDuration => 'Duration';

  @override
  String get shiftsColStatus => 'Status';

  @override
  String get shiftsCrossMidnight => 'Crosses Midnight (+1 day)';

  @override
  String get shiftsDeactivate => 'Deactivate';

  @override
  String get shiftsReactivate => 'Reactivate';

  @override
  String get shiftsEdit => 'Edit Shift';

  @override
  String get shiftsCreateDialogTitle => 'New Shift Template';

  @override
  String get shiftsEditDialogTitle => 'Edit Shift Template';

  @override
  String get shiftsNameLabel => 'Shift Name';

  @override
  String get shiftsNameHint => 'e.g. Morning, Evening, Night...';

  @override
  String get shiftsCodeLabel => 'Operational Code (Optional)';

  @override
  String get shiftsCodeHint => 'e.g. MOR, EVE';

  @override
  String get shiftsStartTime => 'Start Time';

  @override
  String get shiftsEndTime => 'End Time';

  @override
  String get shiftsSaveButton => 'Save Shift Template';

  @override
  String get permissionsTitle => 'Shift Manager Capabilities';

  @override
  String get permissionsSubtitle =>
      'Configure operational permissions and management overrides for Shift Managers.';

  @override
  String get permissionsSectionTemplates => 'Shift Templates Management';

  @override
  String get permissionsShiftTemplatesManage =>
      'Create, edit, and reorder shift templates';

  @override
  String get permissionsSectionAvailability => 'Weekly Availability Operations';

  @override
  String get permissionsAvailabilityPeriodCreate =>
      'Create draft weekly availability periods';

  @override
  String get permissionsAvailabilityPeriodOpen =>
      'Open availability submission periods';

  @override
  String get permissionsAvailabilityPeriodClose =>
      'Close and reopen availability periods';

  @override
  String get permissionsAvailabilityTeamRead =>
      'View team availability matrix and submissions';

  @override
  String get permissionsSaveButton => 'Save Capability Overrides';

  @override
  String get permissionsSavedToast =>
      'Shift Manager permissions updated successfully';

  @override
  String get availabilityTitle => 'Weekly Availability';

  @override
  String get availabilitySubtitle =>
      'Submit your working preferences for upcoming station shifts.';

  @override
  String get availabilityNoPeriodTitle => 'No Open Availability Request';

  @override
  String get availabilityNoPeriodDesc =>
      'There is currently no open availability period for this station.';

  @override
  String availabilityDeadlineNotice(String deadline) {
    return 'Submission Deadline: $deadline';
  }

  @override
  String get availabilityStatusDraft => 'Draft';

  @override
  String get availabilityStatusSubmitted => 'Submitted';

  @override
  String get availabilityStatusClosed => 'Closed (Read Only)';

  @override
  String get availabilityStatusNotStarted => 'Not Started';

  @override
  String availabilityProgress(int answered, int total) {
    return '$answered of $total slots answered';
  }

  @override
  String get availabilityAvailable => 'Available';

  @override
  String get availabilityUnavailable => 'Unavailable';

  @override
  String get availabilityUnanswered => 'Unanswered';

  @override
  String get availabilityAllDayAvailable => 'All Day Available';

  @override
  String get availabilityAllDayUnavailable => 'All Day Unavailable';

  @override
  String get availabilitySubmitButton => 'Submit Availability';

  @override
  String get availabilityEditNotice =>
      'Editing an answered slot will return your submission to Draft until resubmitted.';

  @override
  String availabilitySubmittedConfirmation(String week) {
    return 'Availability submitted successfully for $week';
  }

  @override
  String get availabilitySavingDraft => 'Saving draft...';

  @override
  String get availabilityDraftSaved => 'Draft saved';

  @override
  String get managerAvailabilityTitle => 'Team Availability Matrix';

  @override
  String get managerAvailabilitySubtitle =>
      'Review submitted workforce availability, submission progress, and operational readiness.';

  @override
  String get managerKpiEligible => 'Eligible Workforce';

  @override
  String get managerKpiSubmitted => 'Submitted';

  @override
  String get managerKpiDraft => 'In Draft';

  @override
  String get managerKpiNotStarted => 'Not Started';

  @override
  String get managerKpiNotSubmitted => 'Pending Submission';

  @override
  String get managerFilterAll => 'All Members';

  @override
  String get managerFilterSubmitted => 'Submitted';

  @override
  String get managerFilterDraft => 'Draft';

  @override
  String get managerFilterNotStarted => 'Not Started';

  @override
  String get managerOpenPeriod => 'Open Submissions';

  @override
  String get managerClosePeriod => 'Close Submissions';

  @override
  String get managerReopenPeriod => 'Reopen Submissions';

  @override
  String get managerCreatePeriod => 'Create Period';

  @override
  String get managerPeriodHistory => 'Past Periods';

  @override
  String get scheduleTitle => 'Weekly Shift Schedule';

  @override
  String get scheduleSubtitle =>
      'Assign employees, balance shift staffing, and publish official station schedules.';

  @override
  String get scheduleDraftStatus => 'Draft';

  @override
  String get schedulePublishedStatus => 'Official Published';

  @override
  String get schedulePublishAction => 'Publish Schedule';

  @override
  String scheduleStaffingCoverage(String percent) {
    return 'Staffing Coverage: $percent%';
  }

  @override
  String get myShiftsTitle => 'My Shifts';

  @override
  String get myShiftsEmptyDraft =>
      'No official schedule published for this week';

  @override
  String get myShiftsEmptyAssigned =>
      'You have no assigned shifts for this week';

  @override
  String get candidateAssignAction => 'Assign';

  @override
  String get candidateOverrideAction => 'Assign with Override';

  @override
  String get candidateAlreadyAssigned => 'Assigned';

  @override
  String get attendanceTitle => 'Station Attendance';

  @override
  String get attendanceNotCheckedIn => 'Not Checked In';

  @override
  String get attendanceCurrentlyWorking => 'CURRENTLY WORKING';

  @override
  String get attendanceScanQrAction => 'Scan Station QR';

  @override
  String get attendanceCheckOutAction => 'Check Out';

  @override
  String get attendanceRecentHistory => 'Recent Shifts';

  @override
  String get attendanceLiveMonitor => 'Live Attendance';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get notificationsTitle => 'Notification Center';

  @override
  String get notificationsSubtitle =>
      'Realtime shift updates, live attendance alerts, reminders, and operational events';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsEmptyTitle => 'No notifications found';

  @override
  String get notificationsEmptyDesc =>
      'You are all caught up! New schedule, attendance, and system notices will appear here.';

  @override
  String get notificationsUnreadOnly => 'Unread only';

  @override
  String get notificationPreferencesTitle =>
      'Notification Channels & Preferences';

  @override
  String get notificationPreferencesSubtitle =>
      'Configure in-app, push, email, and SMS delivery for each category';

  @override
  String get notificationMandatoryNotice =>
      'Mandatory Compliance & Security Notices';

  @override
  String get notificationMandatoryDesc =>
      'Critical security alerts, manual attendance adjustments, and identity overrides are mandatory and always delivered in-app for auditing.';

  @override
  String get notificationDeliveryMatrix => 'Delivery Matrix';

  @override
  String get notificationDeliveryMatrixDesc =>
      'Toggle preferred communication channels for each operational category';

  @override
  String get navMyHours => 'My Hours';

  @override
  String get myHoursTitle => 'My Worked Hours';

  @override
  String get myHoursSubtitle =>
      'Personal attendance timeline, shift duration history, and active sessions across all stations';

  @override
  String get reportsTitle => 'Station Operational Reports';

  @override
  String get reportsSubtitle =>
      'Authoritative time records, station metrics, employee breakdowns, and daily shift rosters';

  @override
  String get kpiTotalWorked => 'Total Worked Time';

  @override
  String get kpiCompletedShifts => 'Completed Shifts';

  @override
  String get kpiLateShifts => 'Late Shifts';

  @override
  String get kpiTotalLateTime => 'Total Late Time';

  @override
  String get kpiCorrectedRecords => 'Corrected Records';

  @override
  String get kpiActiveOpenSessions => 'Active Open Shifts';

  @override
  String get kpiRepeatedLateness => 'Repeated Lateness';

  @override
  String get kpiActiveWorkforce => 'Active Station Workforce';

  @override
  String get kpiAverageShift => 'Avg Shift Duration';

  @override
  String get kpiOnTimeRate => 'On-Time Rate';

  @override
  String get presetToday => 'Today';

  @override
  String get presetCurrentWeek => 'This Week';

  @override
  String get presetCurrentMonth => 'This Month';

  @override
  String get presetLastMonth => 'Last Month';

  @override
  String get presetCustom => 'Custom Range';

  @override
  String get filterAll => 'All Shifts';

  @override
  String get filterCompleted => 'Completed';

  @override
  String get filterLate => 'Late Only';

  @override
  String get filterCorrected => 'Corrected';

  @override
  String get filterOpen => 'Active Open';

  @override
  String get tabBreakdown => 'Workforce Breakdown';

  @override
  String get tabDailyBoard => 'Daily Operational Board';

  @override
  String get searchEmployeesPlaceholder => 'Search by name or employee code...';

  @override
  String get employeeDrilldownTitle => 'Employee Attendance & History';

  @override
  String get correctionLedger => 'Correction Ledger';

  @override
  String get noAttendanceFound =>
      'No attendance records found for this selected period.';

  @override
  String get selectDatePrompt => 'Select Operational Date';

  @override
  String get statusActive => 'Active';

  @override
  String get statusInactive => 'Inactive';

  @override
  String get statusSuspended => 'Suspended';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navShiftTemplates => 'Shift Templates';

  @override
  String get navStationSettings => 'Station Settings';

  @override
  String get navSectionWorkspace => 'My Workspace';

  @override
  String get navSectionManagement => 'Station Management';

  @override
  String get navSectionGeneral => 'Account & System';

  @override
  String get switchStationContext => 'Switch Station Context';

  @override
  String get noPhoneRegistered => 'No phone registered';

  @override
  String get noCodeAssigned => 'None assigned';

  @override
  String get notProvided => 'Not provided';

  @override
  String get joinedStationLabel => 'Joined Station';

  @override
  String get allStatusesFilter => 'All Statuses';

  @override
  String get filterStatusActive => 'Active';

  @override
  String get filterStatusInactive => 'Inactive';

  @override
  String get filterStatusSuspended => 'Suspended';

  @override
  String get selectEmployeePrompt =>
      'Select an employee to view operational details';

  @override
  String get colNameIdentity => 'NAME & IDENTITY';

  @override
  String get colStationRole => 'STATION ROLE';

  @override
  String get colStatus => 'STATUS';

  @override
  String get colPhone => 'PHONE';

  @override
  String get colCode => 'CODE';

  @override
  String get dashboardStationOverview => 'Station Overview';

  @override
  String get dashboardEmployeeNextShift => 'Upcoming Shift';

  @override
  String get dashboardEmployeeNoShift => 'No shifts scheduled for today';

  @override
  String get dashboardEmployeeAttendanceStatus => 'Today\'s Attendance Status';

  @override
  String get dashboardEmployeeActiveShift => 'Shift In Progress';

  @override
  String get dashboardEmployeeNotCheckedIn => 'Not Clocked In';

  @override
  String get dashboardEmployeeClockInAction => 'Clock In with QR';

  @override
  String get dashboardEmployeeClockOutAction => 'Clock Out';

  @override
  String get dashboardEmployeeMyHoursTitle => 'Worked Hours Summary';

  @override
  String get dashboardEmployeeAvailabilityTitle => 'Shift Availability';

  @override
  String get dashboardEmployeeAvailabilityOpen =>
      'Availability submission is open';

  @override
  String get dashboardEmployeeAvailabilitySubmitted =>
      'Availability successfully submitted';

  @override
  String get dashboardEmployeeAvailabilityClosed =>
      'No active submission period';

  @override
  String get dashboardManagerStaffingTitle => 'Today\'s Operational Staffing';

  @override
  String dashboardManagerStaffingRequired(int count) {
    return 'Required: $count';
  }

  @override
  String dashboardManagerStaffingAssigned(int count) {
    return 'Assigned: $count';
  }

  @override
  String dashboardManagerStaffingCheckedIn(int count) {
    return 'Checked In: $count';
  }

  @override
  String dashboardManagerStaffingShortage(int count) {
    return 'Shortage: $count';
  }

  @override
  String get dashboardManagerLiveAttendanceTitle => 'Live Attendance Roster';

  @override
  String get dashboardManagerAvailabilityOverview =>
      'Team Availability Progress';

  @override
  String get dashboardManagerAlertsTitle => 'Operational Alerts';

  @override
  String dashboardManagerLateArrivals(int count) {
    return '$count Late Arrivals';
  }

  @override
  String dashboardManagerLongSessions(int count) {
    return '$count Shifts Exceeding 16h';
  }

  @override
  String get dashboardAdminPulseTitle => 'Station Workforce Summary';

  @override
  String get dashboardAdminQuickShortcuts => 'Administrative Shortcuts';

  @override
  String get dashboardAdminNfcSummary => 'NFC Tags Fleet';

  @override
  String get dashboardAdminSettingsAction => 'Station Settings';

  @override
  String get dashboardAdminAddEmployeeAction => 'Add Employee';

  @override
  String get employeeEditTitle => 'Edit Employee Profile';

  @override
  String get employeeEditSubtitle =>
      'Modify profile and station membership properties';

  @override
  String get employeeEditGlobalNotice =>
      'First Name, Last Name, Phone, and Preferred Locale update globally across all stations.';

  @override
  String get employeeEditStationNotice =>
      'Station Role, Membership Status, and Employee Code apply strictly to this station.';

  @override
  String get employeeEditFirstNameLabel => 'First Name';

  @override
  String get employeeEditLastNameLabel => 'Last Name';

  @override
  String get employeeEditPhoneLabel => 'Phone Number';

  @override
  String get employeeEditEmailLabel => 'Email Address';

  @override
  String get employeeEditLocaleLabel => 'Preferred Language';

  @override
  String get employeeEditRoleLabel => 'Station Role';

  @override
  String get employeeEditStatusLabel => 'Membership Status';

  @override
  String get employeeEditCodeLabel => 'Station Employee Code';

  @override
  String get employeeEditSaveButton => 'Save Changes';

  @override
  String get employeeEditSuccessToast =>
      'Employee details updated successfully';

  @override
  String get employeeEditAction => 'Edit Profile';

  @override
  String get employeeResetPasswordTitle => 'Reset Employee Password';

  @override
  String employeeResetPasswordConfirm(String name) {
    return 'This will generate a new temporary password for $name and invalidate all active sessions.';
  }

  @override
  String get employeeResetPasswordGenerate => 'Generate New Password';

  @override
  String get employeeResetPasswordSuccessTitle => 'New Temporary Password';

  @override
  String employeeResetPasswordSuccessDesc(String name) {
    return 'A new temporary password has been issued for $name:';
  }

  @override
  String get employeeResetPasswordNotice =>
      'Provide this password to the employee. It will not be shown again.';

  @override
  String get employeeRevokeSessionsConfirm => 'Revoke Active Sessions';

  @override
  String get employeeRevokeSessionsSuccess =>
      'Active sessions revoked successfully';

  @override
  String get errorLastAdminRequired =>
      'Cannot demote or deactivate the last active Administrator of this station.';

  @override
  String get errorPermissionDenied =>
      'Access denied. You do not have permission for this action.';

  @override
  String get errorDuplicatePhone =>
      'This phone number is already registered to another user.';

  @override
  String get errorDuplicateEmail =>
      'This email address is already registered to another user.';

  @override
  String get errorInvalidInput => 'Please verify the entered details.';

  @override
  String get errorNotFound => 'The requested record was not found.';

  @override
  String get errorGeneric => 'An unexpected error occurred. Please try again.';

  @override
  String get errorExportExpired =>
      'This export link has expired (15-minute validity). Please request a new export.';

  @override
  String get errorActiveAttendanceBlocksDeactivation =>
      'Cannot deactivate station while active attendance sessions or scheduled shifts are open.';

  @override
  String get dialogCancel => 'Cancel';

  @override
  String get copyPassword => 'Copy Password';

  @override
  String get passwordCopied => 'Password copied to clipboard';

  @override
  String get closeButton => 'Close';

  @override
  String get navExports => 'Exports';

  @override
  String get navAuditCenter => 'Audit Center';

  @override
  String get navSystemHealth => 'System Health';

  @override
  String get exportCenterTitle => 'Operational Export Center';

  @override
  String get exportCenterSubtitle =>
      'Generate certified server-side operational data artifacts with spreadsheet formula defense';

  @override
  String get exportMyHours => 'Export My Attendance Hours';

  @override
  String get exportStationAttendanceSummary => 'Station Attendance Summary';

  @override
  String get exportStationEmployeeWorkedHours => 'Employee Worked Hours';

  @override
  String get exportDailyAttendanceReport => 'Daily Attendance Report';

  @override
  String get exportAttendanceCorrectionLedger => 'Attendance Correction Ledger';

  @override
  String get exportPublishedSchedule => 'Published Schedule Roster';

  @override
  String get exportEmployeeDirectory => 'Employee Directory & Roster';

  @override
  String get exportAvailabilityOverview => 'Team Availability Overview';

  @override
  String get exportFormatCsv => 'CSV (UTF-8 BOM)';

  @override
  String get exportFormatPdf => 'PDF Document';

  @override
  String get exportButtonGenerate => 'Generate Export';

  @override
  String get exportGenerating => 'Generating Export...';

  @override
  String exportSuccess(int rowCount) {
    return 'Export generated successfully ($rowCount rows)';
  }

  @override
  String get exportDownloadButton => 'Download File';

  @override
  String get exportHistoryTitle => 'Recent Export Artifacts';

  @override
  String get exportHistoryEmpty => 'No recent export artifacts found.';

  @override
  String get exportStatusCompleted => 'Completed';

  @override
  String get exportStatusExpired => 'Expired';

  @override
  String get exportStatusProcessing => 'Processing';

  @override
  String get exportStatusFailed => 'Failed';

  @override
  String get exportExpiryNotice =>
      'Download links expire automatically after 15 minutes for data security.';

  @override
  String get auditCenterTitle => 'Administrative Audit Center';

  @override
  String get auditCenterSubtitle =>
      'Immutable chronological ledger of administrative mutations and operational actions';

  @override
  String get auditFilterAll => 'All Activities';

  @override
  String get auditFilterMemberships => 'Memberships & Roles';

  @override
  String get auditFilterSchedules => 'Schedules & Shifts';

  @override
  String get auditFilterAttendance => 'Attendance & Clock-In';

  @override
  String get auditFilterStation => 'Station Configuration';

  @override
  String get auditFilterExports => 'Data Exports';

  @override
  String get auditFilterAvailability => 'Availability';

  @override
  String get auditSearchPlaceholder =>
      'Search by actor, email, action or target...';

  @override
  String get auditEmptyLogs => 'No audit records found matching criteria.';

  @override
  String get auditMetadataTitle => 'Sanitized Metadata';

  @override
  String get auditActor => 'Actor';

  @override
  String get auditAction => 'Action';

  @override
  String get auditTarget => 'Target';

  @override
  String get auditTimestamp => 'Timestamp';

  @override
  String auditPageInfo(int current, int total, int count) {
    return 'Page $current of $total ($count events)';
  }

  @override
  String get systemHealthTitle => 'Station Operational Health';

  @override
  String get systemHealthSubtitle =>
      'Live telemetry, station NFC tag fleet status, and data lifecycle management';

  @override
  String get systemHealthExportPipeline => 'Export Pipeline (24h)';

  @override
  String systemHealthExportsSummary(int count, int failed) {
    return '$count Exports ($failed Failed)';
  }

  @override
  String get systemHealthAnomalies => 'System Health & Anomalies';

  @override
  String get systemHealthNoAnomalies => 'All station systems operational';

  @override
  String systemHealthStaleSessions(int count) {
    return '$count Stale Open Attendance Sessions';
  }

  @override
  String systemHealthFailedIdentity(int count) {
    return '$count Identity Verification Failures';
  }

  @override
  String get dataRetentionTitle => 'Data Lifecycle & Retention';

  @override
  String get dataRetentionSummary =>
      'Historical attendance records, shifts, and audit logs are permanently retained. Ephemeral QR challenge tokens and expired file artifacts are automatically scrubbed.';

  @override
  String get dataRetentionRunButton => 'Run Lifecycle Cleanup';

  @override
  String dataRetentionSuccess(int exports, int challenges) {
    return 'Cleanup completed: $exports expired exports marked, $challenges QR tokens cleared.';
  }

  @override
  String get stationTimezoneLabel => 'Station Timezone (IANA)';

  @override
  String get stationTimezoneHelper =>
      'Timezone used for shift boundaries and timestamp formatting';

  @override
  String get stationLateGraceMinutes => 'Late Grace Period (Minutes)';

  @override
  String get stationLateGraceHelper =>
      'Arrivals within this grace period are recorded as on-time';

  @override
  String get stationCheckInEarlyMinutes => 'Early Check-in Window (Minutes)';

  @override
  String get stationCheckInEarlyHelper =>
      'Allow employees to clock-in before scheduled shift starts';

  @override
  String get stationDangerZone => 'Sensitive Station Controls';

  @override
  String get stationDeactivateAction => 'Deactivate Station';

  @override
  String get stationDeactivateNotice =>
      'Deactivating the station will prevent all employee clock-ins and scheduling activities.';

  @override
  String get stationDeactivateBlockedActive =>
      'Cannot deactivate station while active attendance sessions or open shifts exist.';

  @override
  String get stationForceDeactivateConfirm => 'Force Station Deactivation';

  @override
  String get connectionOnline => 'Online';

  @override
  String get connectionDegraded => 'Degraded Connection';

  @override
  String get connectionReconnecting => 'Reconnecting...';

  @override
  String get connectionOffline => 'Offline — Read Only';

  @override
  String get errorOfflineActionBlocked =>
      'Active internet connection is required to complete this action.';

  @override
  String get errorReconcilingAttendance =>
      'Verifying attendance status after network timeout...';

  @override
  String get appUpdateAvailable =>
      'A new version of YellowShifts is available.';

  @override
  String get appUpdateReloadNow => 'Reload Now';

  @override
  String get appUpdateLater => 'Later';

  @override
  String get startupConfigError => 'Configuration Error';

  @override
  String get startupConfigErrorMessage =>
      'Application failed to initialize due to invalid configuration.';

  @override
  String get startupLoading => 'Loading YellowShifts...';

  @override
  String get startupRetry => 'Retry Initialization';

  @override
  String get errorRateLimited =>
      'Too many requests. Please slow down and try again shortly.';

  @override
  String get errorScheduleConflict => 'Schedule assignment conflict detected.';

  @override
  String get errorVersionConflict =>
      'Schedule was updated by another manager. Please refresh.';

  @override
  String get errorStationDeactivated => 'This station is currently inactive.';

  @override
  String get errorMembershipDeactivated =>
      'Your station membership is inactive or suspended.';

  @override
  String get errorTimeout =>
      'The request timed out. Please check your connection.';

  @override
  String get errorServiceUnavailable =>
      'Server is temporarily unavailable. Please try again soon.';

  @override
  String get systemHealthHealthy => 'Healthy';

  @override
  String get systemHealthDegraded => 'Degraded';

  @override
  String get systemHealthUnavailable => 'Unavailable';

  @override
  String get systemHealthUnknown => 'Unknown';

  @override
  String get settingsTitle => 'Settings & Preferences';

  @override
  String get settingsSubtitle =>
      'Manage user identity, language, and station operational settings';

  @override
  String get settingsUserProfile => 'User Profile';

  @override
  String settingsUserPhone(String phone) {
    return 'Phone: $phone';
  }

  @override
  String get settingsNotifications => 'Notification Preferences';

  @override
  String get settingsNotificationsSubtitle =>
      'Configure in-app, push, email, and SMS alert delivery channels';

  @override
  String get settingsStationAdmin => 'Station Administration';

  @override
  String get settingsOperationalParams => 'Operational Parameters';

  @override
  String get settingsOperationalParamsSubtitle =>
      'Timezone, code, locale, and week start';

  @override
  String get settingsShiftTemplates => 'Shift Templates';

  @override
  String get settingsShiftTemplatesSubtitle =>
      'Configure working shifts, hours, and sort order';

  @override
  String get settingsShiftManagerCaps => 'Shift Manager Capabilities';

  @override
  String get settingsShiftManagerCapsSubtitle =>
      'Station-specific permission overrides for Shift Managers';

  @override
  String get settingsExportCenter => 'Operational Export Center';

  @override
  String get settingsExportCenterSubtitle =>
      'Generate certified CSV and PDF operational report artifacts';

  @override
  String get settingsAuditCenter => 'Audit Center';

  @override
  String get settingsAuditCenterSubtitle =>
      'Inspect immutable chronological administrative activity ledger';

  @override
  String get settingsSystemHealth => 'Operational Health & Lifecycle';

  @override
  String get settingsSystemHealthSubtitle =>
      'Live telemetry, station NFC tag fleet health, and data retention maintenance';

  @override
  String get settingsCurrentStationDetails => 'Current Station Details';

  @override
  String get settingsStationName => 'Station Name';

  @override
  String get settingsStationCode => 'Operational Code';

  @override
  String get settingsStationTimezone => 'Timezone';

  @override
  String get settingsStationLocale => 'Station Locale';

  @override
  String get settingsLanguageDirection => 'Language & Directionality';

  @override
  String get settingsSignOut => 'Sign Out from YellowShifts';

  @override
  String get systemHealthDefenseSubtitle =>
      'Completed with server-side formula defense';

  @override
  String get systemHealthStaleSessionsSubtitle =>
      'Sessions open for > 16 hours requiring manager review';

  @override
  String get exportPreset7Days => '7 Days';

  @override
  String get exportPreset30Days => '30 Days';

  @override
  String get exportPresetThisMonth => 'This Month';

  @override
  String get exportPresetLastMonth => 'Last Month';

  @override
  String get exportPresetCustom => 'Custom';

  @override
  String get exportFormatLabel => 'Format';

  @override
  String availabilityDeadlineInfo(String deadline, int count) {
    return 'Deadline: $deadline • $count shifts / day';
  }

  @override
  String availabilitySlotsAnswered(int answered, int total) {
    return '$answered of $total slots answered';
  }

  @override
  String get statusOpen => 'Open';

  @override
  String get statusClosed => 'Closed';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusSubmitted => 'Submitted';

  @override
  String get statusNotStarted => 'Not Started';

  @override
  String get noEmployeeRecordsFound => 'No employee records found.';

  @override
  String get stationSectionIdentity => 'Operational Identity';

  @override
  String get stationSectionRegional => 'Regional & Calendar Defaults';

  @override
  String get stationSectionGrace => 'Shift & Grace Policies';

  @override
  String get stationActiveStatus => 'Station Active';

  @override
  String get stationDeactivatedStatus => 'Station Deactivated';

  @override
  String get stationActiveDesc =>
      'Kiosks and employee clock-ins are currently accepting operations.';

  @override
  String get stationDeactivatedDesc =>
      'Station is paused and blocked from active operations.';

  @override
  String get policyOptionDisabledTitle => 'Disabled (QR Only)';

  @override
  String get policyOptionDisabledSubtitle =>
      'Attendance uses Phase 4 rotating QR challenges only.';

  @override
  String get policyOptionCheckInOnlyTitle => 'Check-In Only (Recommended)';

  @override
  String get policyOptionCheckInOnlySubtitle =>
      'Requires biometric verification on check-in. Check-out is QR only.';

  @override
  String get policyOptionStrictTitle => 'Strict: Check-In & Check-Out';

  @override
  String get policyOptionStrictSubtitle =>
      'Requires biometric verification for both check-in and check-out.';

  @override
  String get policyApplyAction => 'Apply Policy Change';

  @override
  String get policyTeamReadinessTitle => 'Team Biometric Readiness';

  @override
  String get policyNoMembersRegistered => 'No active team members registered.';

  @override
  String get kpiWorkingNow => 'Working Now';

  @override
  String get kpiUpcoming => 'Upcoming';

  @override
  String get kpiLate => 'Late';

  @override
  String get kpiCompleted => 'Completed';

  @override
  String get kpiNotCheckedIn => 'Not Checked In';

  @override
  String get attendanceRosterTitle => 'Today\'s Shift Roster';

  @override
  String rosterScheduledCount(int count) {
    return '$count scheduled';
  }

  @override
  String get noEmployeesScheduledToday => 'No employees scheduled for today.';

  @override
  String get attendanceStatusWorking => 'Working';

  @override
  String get attendanceStatusUpcoming => 'Upcoming';

  @override
  String attendanceStatusLate(int minutes) {
    return 'Late ${minutes}m';
  }

  @override
  String get attendanceStatusCompleted => 'Completed';

  @override
  String get attendanceStatusNotCheckedIn => 'Not Checked In';

  @override
  String get attendanceScanPrompt =>
      'Hold your phone near the station NFC tag to record attendance';

  @override
  String get attendanceActiveShift => 'Active Shift';

  @override
  String attendanceLateDuration(int minutes) {
    return 'Late $minutes min';
  }

  @override
  String get attendanceConfirmCheckIn => 'Confirm Check-In';

  @override
  String get attendanceConfirmCheckOut => 'Confirm Check-Out';

  @override
  String get shiftLabel => 'Shift';

  @override
  String get scheduledShift => 'Scheduled Shift';

  @override
  String get scheduledWindow => 'Scheduled Window';

  @override
  String get workedTimeLabel => 'Worked Time';

  @override
  String get checkInNowAction => 'Check In Now';

  @override
  String get checkOutNowAction => 'Check Out Now';

  @override
  String get correctionDialogTitle => 'Correct Attendance';

  @override
  String get correctionReasonLabel => 'Reason for correction (required)';

  @override
  String get correctionReasonHint =>
      'e.g. Employee forgot to clock out on station tablet';

  @override
  String get correctionSaveAction => 'Save Correction';

  @override
  String get checkInLabel => 'Check In';

  @override
  String get checkOutLabel => 'Check Out';

  @override
  String get attendanceNoHistory => 'No attendance history recorded yet.';

  @override
  String get attendanceWorkShift => 'Work Shift';

  @override
  String get timeNow => 'Now';

  @override
  String get identityVerifyingFace => 'Verifying face liveness...';

  @override
  String kpiActiveEmployees(int count) {
    return '$count active employees';
  }

  @override
  String kpiActiveOpen(int count) {
    return '$count active open';
  }

  @override
  String kpiLateShiftsCount(int count, int minutes) {
    return '$count late shifts (${minutes}m)';
  }

  @override
  String get kpiEmployeesLateThreshold => 'employees with >= 3 late shifts';

  @override
  String get kpiAttentionBadge => 'Attention';

  @override
  String get kpiManualAdjustmentsAudited => 'manual adjustments audited';

  @override
  String workforceRecordsTitle(int count) {
    return 'Workforce Records ($count)';
  }

  @override
  String get tableColEmployee => 'Employee';

  @override
  String get tableColCode => 'Code';

  @override
  String get tableColWorkedTime => 'Worked Time';

  @override
  String get tableColCompleted => 'Completed';

  @override
  String get tableColLateShifts => 'Late Shifts';

  @override
  String get tableColCorrections => 'Corrections';

  @override
  String get tableColStatus => 'Status';

  @override
  String get repeatedLatenessTag => 'Repeated Lateness (>=3)';

  @override
  String get tableMetricWorked => 'Worked';

  @override
  String get tableMetricShifts => 'Shifts';

  @override
  String get tableMetricLate => 'Late';

  @override
  String get tableMetricCorrected => 'Corrected';

  @override
  String get dailyNoRecords =>
      'No scheduled shifts or walk-in records on this date.';

  @override
  String dailyScheduledShiftsTitle(int count) {
    return 'Scheduled Operational Shifts ($count)';
  }

  @override
  String dailyWalkInTitle(int count) {
    return 'Unscheduled Walk-In Attendance ($count)';
  }

  @override
  String dailyRequiredStaff(int count) {
    return 'Required: $count';
  }

  @override
  String dailyAssignedStaff(int count) {
    return 'Assigned: $count';
  }

  @override
  String dailyCheckedInStaff(int count) {
    return 'Checked In: $count';
  }

  @override
  String dailyLateStaff(int count) {
    return 'Late: $count';
  }

  @override
  String dailyActiveOpenStaff(int count) {
    return 'Active Open: $count';
  }

  @override
  String get dailyNoShiftRecords =>
      'No attendance records checked in for this scheduled shift.';

  @override
  String get checkedInLabel => 'Checked in';

  @override
  String lateMinutesLabel(int minutes) {
    return 'Late ${minutes}m';
  }

  @override
  String shiftHistoryTitle(int count) {
    return 'Shift History ($count)';
  }

  @override
  String get allStationsFilter => 'All Stations';

  @override
  String stationsWorkedCount(int count) {
    return '$count stations';
  }

  @override
  String lateTimeDuration(int minutes) {
    return '${minutes}m late time';
  }

  @override
  String get repeatedBadge => 'Repeated';

  @override
  String get operationalWeekRange => 'Operational Week Range';

  @override
  String get submissionDeadline => 'Submission Deadline';

  @override
  String get operationalNotesOptional => 'Operational Notes (Optional)';

  @override
  String get operationalNotesHint =>
      'e.g. Holiday coverage required, minimum 4 shifts...';

  @override
  String get createPeriodAction => 'Create Period';

  @override
  String get submissionDeadlineFutureError =>
      'Submission deadline must be in the future.';

  @override
  String get reportsAccessRestrictedTitle => 'Access Restricted';

  @override
  String get reportsAccessRestrictedDesc =>
      'You must be an active station manager or administrator to view operational reporting.';

  @override
  String get walkInShift => 'Walk-In Shift';

  @override
  String get activeShiftInProgress => 'ACTIVE SHIFT IN PROGRESS';

  @override
  String get shiftExceedsWarning =>
      'Shift exceeds 16 hours. Review checkout status.';

  @override
  String get repeatedLatenessPattern =>
      'Repeated Lateness Pattern: 3 or more late shifts in this reporting period.';

  @override
  String get attendanceCorrectionHistory => 'Attendance & Correction History';

  @override
  String get noRecordsInPeriod => 'No attendance records in period.';

  @override
  String correctionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count corrections',
      one: '1 correction',
    );
    return '$_temp0';
  }

  @override
  String correctionByActor(String name) {
    return 'By: $name';
  }

  @override
  String correctionDurationChange(String oldDuration, String newDuration) {
    return 'Duration: $oldDuration -> $newDuration';
  }

  @override
  String correctionReasonPrefix(String reason) {
    return 'Reason: \"$reason\"';
  }

  @override
  String get stationLabel => 'Station';

  @override
  String get kpiWorkedHours => 'Worked Hours';

  @override
  String get kpiLateArrivals => 'Late Arrivals';

  @override
  String get statusCorrected => 'Corrected';

  @override
  String get rolePlatformAdmin => 'Platform Admin';

  @override
  String get roleStationManager => 'Station Manager';

  @override
  String get platformAdminTitle => 'Platform Administration';

  @override
  String get platformAdminMode => 'Platform Mode';

  @override
  String get platformOverviewTitle => 'Platform Overview';

  @override
  String get platformOverviewSubtitle =>
      'Network-wide operational summary for YellowShifts operators.';

  @override
  String get platformNavOverview => 'Overview';

  @override
  String get platformNavStations => 'Stations';

  @override
  String get platformNavAudit => 'Audit / Operations';

  @override
  String get platformNavHealth => 'System Health';

  @override
  String get platformStationsTitle => 'Stations';

  @override
  String get platformStationsSubtitle =>
      'Provision, inspect, and operate every station in the YellowShifts network.';

  @override
  String get platformCreateStation => 'Create Station';

  @override
  String get platformCreateStationTitle => 'Create Station';

  @override
  String get platformCreateStationSubtitle =>
      'Provision a station and assign the initial Station Manager.';

  @override
  String get platformStationName => 'Station Name';

  @override
  String get platformStationCode => 'Station Code';

  @override
  String get platformStationTimezone => 'Timezone';

  @override
  String get platformStationLocale => 'Locale';

  @override
  String get platformStationStatus => 'Status';

  @override
  String get platformWeekStart => 'Week starts on';

  @override
  String get platformWeekStartSunday => 'Sunday';

  @override
  String get platformWeekStartMonday => 'Monday';

  @override
  String get platformInitialManager => 'Initial Station Manager';

  @override
  String get platformManagerEmail => 'Manager email';

  @override
  String get platformManagerFirstName => 'First name';

  @override
  String get platformManagerLastName => 'Last name';

  @override
  String get platformManagerPhone => 'Phone (optional)';

  @override
  String get platformAssignManager => 'Assign Manager';

  @override
  String get platformAddManager => 'Add Station Manager';

  @override
  String get platformReplaceManager => 'Replace Station Manager';

  @override
  String get platformRemoveManager => 'Remove Manager role';

  @override
  String get platformDeactivateManager => 'Deactivate Station Manager';

  @override
  String get platformReactivateManager => 'Reactivate Station Manager';

  @override
  String get platformStationManagers => 'Station Managers';

  @override
  String get platformStationManagersSubtitle =>
      'Only Platform Admins can grant or revoke Station Manager access.';

  @override
  String get platformDeactivateStation => 'Deactivate Station';

  @override
  String get platformReactivateStation => 'Reactivate Station';

  @override
  String get platformOpenStation => 'Open Station';

  @override
  String get platformOperatingStation => 'Operating Station';

  @override
  String platformOperatingBanner(String stationName) {
    return 'Platform Admin · Operating: $stationName';
  }

  @override
  String get platformReturnToPlatform => 'Return to Platform Administration';

  @override
  String get platformWorkspaceSwitch => 'Station Workspace';

  @override
  String get platformLogoutConfirm => 'Are you sure you want to sign out?';

  @override
  String get platformSuperAdminRole => 'Super Admin';

  @override
  String get platformConfirmDeactivateTitle => 'Deactivate this station?';

  @override
  String get platformConfirmDeactivateBody =>
      'Ordinary station access will fail closed. Historical attendance, schedules, and audit records are preserved.';

  @override
  String get platformConfirmRemoveManagerTitle =>
      'Remove Station Manager access?';

  @override
  String get platformConfirmRemoveManagerBody =>
      'This person will no longer be a Station Manager. The station must retain at least one active Station Manager.';

  @override
  String get platformReasonLabel => 'Reason';

  @override
  String get platformReasonHint => 'Describe why this change is required';

  @override
  String get platformForceDeactivate =>
      'Force deactivate despite active operations';

  @override
  String get platformMetricTotalStations => 'Total stations';

  @override
  String get platformMetricActiveStations => 'Active stations';

  @override
  String get platformMetricInactiveStations => 'Inactive stations';

  @override
  String get platformMetricActiveMemberships => 'Active memberships';

  @override
  String get platformMetricStationAdmins => 'Station Managers';

  @override
  String get platformMetricShiftManagers => 'Shift Managers';

  @override
  String get platformMetricAlerts => 'Operational alerts';

  @override
  String get platformColEmployees => 'Active employees';

  @override
  String get platformColManagers => 'Station Managers';

  @override
  String get platformColShiftManagers => 'Shift Managers';

  @override
  String get platformHealthSummary => 'Operational health';

  @override
  String get platformAuditTitle => 'Platform Audit';

  @override
  String get platformAuditSubtitle =>
      'Inspect platform and station operations. Station Admins remain tenant-scoped.';

  @override
  String get platformAuditFilterAction => 'Action';

  @override
  String get platformHealthTitle => 'Platform Health';

  @override
  String get platformHealthSubtitle =>
      'Aggregated NFC tags, export, attendance, and notification signals across the network.';

  @override
  String get platformUnauthorizedTitle => 'Platform Administration unavailable';

  @override
  String get platformUnauthorizedBody =>
      'This area is restricted to active Platform Admins.';

  @override
  String get platformEmptyStations => 'No stations have been provisioned yet.';

  @override
  String get platformCreatedToast => 'Station created successfully';

  @override
  String get platformUpdatedToast => 'Station updated';

  @override
  String get platformDeactivatedToast => 'Station deactivated';

  @override
  String get platformReactivatedToast => 'Station reactivated';

  @override
  String get platformManagerAssignedToast => 'Station Manager assigned';

  @override
  String get platformColNfcTags => 'NFC Tags';

  @override
  String get platformMetricNfcActive => 'Active NFC tags';

  @override
  String get platformMetricNfcTotal => 'Total NFC tags';

  @override
  String get attendanceScanNfcAction => 'Scan Station NFC Tag';

  @override
  String get settingsNfcTags => 'Station NFC Tags';

  @override
  String get settingsNfcTagsSubtitle =>
      'Provision, program, and manage physical station NFC tags';

  @override
  String get nfcTagsManagementTitle => 'Station NFC Tags';

  @override
  String get nfcProvisionNewTitle => 'Provision New NFC Tag';

  @override
  String get nfcProvisionDialogDesc =>
      'Register an NFC tag identifier on the server and prepare it for writing.';

  @override
  String get nfcTagNameLabel => 'Tag Name';

  @override
  String get nfcTagNameHint => 'e.g. Front Entrance Tag, Kitchen Tag';

  @override
  String get nfcTagIdLabel => 'Tag ID';

  @override
  String get nfcStationCodeLabel => 'Station Code';

  @override
  String get nfcReadyToWriteDesc =>
      'Tap below to physically write this station configuration onto a blank NFC tag.';

  @override
  String get nfcCreateTagAction => 'Register Tag';

  @override
  String get nfcWriteToCardAction => 'Write to NFC Tag';

  @override
  String get nfcHoldToWritePrompt =>
      'Hold phone near blank NFC tag to write station data.';

  @override
  String get nfcTagWrittenSuccess => 'NFC Tag programmed successfully!';

  @override
  String get nfcWriteTagTitle => 'Write to Physical Tag';

  @override
  String get nfcTagCreatedServerDesc =>
      'Tag registered on server. Hold your device to write to the physical tag.';

  @override
  String get nfcNoTagsTitle => 'No Station NFC Tags';

  @override
  String get nfcNoTagsDesc =>
      'Provision a physical NFC tag at this station to enable employee attendance check-in.';

  @override
  String get nfcTagStatusActive => 'Active';

  @override
  String get nfcTagStatusRevoked => 'Revoked';

  @override
  String nfcLastScanned(String time) {
    return 'Last scan: $time';
  }

  @override
  String get nfcNeverScanned => 'Never scanned';

  @override
  String get nfcReplaceAction => 'Replace';

  @override
  String get nfcRevokeAction => 'Revoke';

  @override
  String get nfcReactivateAction => 'Reactivate';

  @override
  String get nfcReplaceTagTitle => 'Replace Station NFC Tag';

  @override
  String get nfcReplaceTagWarning =>
      'This will permanently revoke the current physical tag and generate credentials for a new replacement tag.';

  @override
  String get nfcNewTagNameLabel => 'Replacement Tag Name';

  @override
  String get nfcReplaceTagConfirm => 'Replace Tag';

  @override
  String get nfcTagReplacedSuccess => 'Tag replaced successfully';

  @override
  String get nfcTagRevokedToast => 'NFC Tag revoked';

  @override
  String get nfcTagReactivatedToast => 'NFC Tag reactivated';

  @override
  String get nfcUnavailableError =>
      'NFC is unavailable or disabled on this device.';

  @override
  String get nfcScanCheckInPrompt =>
      'Hold phone near station NFC tag to clock in.';

  @override
  String get nfcScanCheckOutPrompt =>
      'Hold phone near station NFC tag to clock out.';

  @override
  String get nfcCheckInTitle => 'Scan Station NFC Tag';

  @override
  String get nfcCheckOutTitle => 'Scan Station NFC Tag';

  @override
  String get nfcHoldNearPrompt =>
      'Hold your phone close to the physical station NFC tag to record your attendance.';

  @override
  String get nfcVerifyingPresence => 'Verifying Station Tag...';

  @override
  String get nfcAuthorizingBackend =>
      'Validating physical presence and attendance rules on the server...';

  @override
  String get nfcCheckInSuccess => 'Check-In Verified!';

  @override
  String get nfcCheckOutSuccess => 'Check-Out Verified!';

  @override
  String get nfcVerificationFailed => 'Attendance Verification Failed';

  @override
  String get auditFilterNfcTags => 'NFC Station Tags';

  @override
  String get systemHealthNfcFleet => 'NFC Station Tags';

  @override
  String systemHealthNfcActive(int active, int total) {
    return '$active of $total Active';
  }

  @override
  String get systemHealthNfcTagsHealthy =>
      'All station NFC tags active and operational';

  @override
  String get systemHealthNfcNoActiveTags =>
      'No active NFC tags configured for this station';

  @override
  String get platformManagerRemovedToast => 'Station Manager role removed';

  @override
  String get platformManagedByPlatform => 'Managed by Platform Administration';

  @override
  String get platformAdminRoleReadonlyHint =>
      'Station Manager access is assigned only by Platform Administration.';

  @override
  String get errorNotPlatformAdmin =>
      'You must be an active Platform Admin to perform this action.';

  @override
  String get errorStationCodeConflict => 'This station code is already in use.';

  @override
  String get errorStationAlreadyInactive => 'This station is already inactive.';

  @override
  String get errorStationAlreadyActive => 'This station is already active.';

  @override
  String get errorStationProvisioningFailed =>
      'Station provisioning failed. No partial station was left active.';

  @override
  String get errorStationAdminRoleForbidden =>
      'Station Managers cannot grant or revoke Station Manager access.';

  @override
  String get nfcTagUrlLabel => 'NFC Tag URL';

  @override
  String get nfcCopyUrlAction => 'Copy NFC URL';

  @override
  String get nfcUrlCopiedToast => 'NFC URL copied to clipboard';

  @override
  String get nfcRegenerateTokenAction => 'Regenerate Token';

  @override
  String get nfcRegenerateTokenTitle => 'Regenerate Station Tag Token';

  @override
  String get nfcRegenerateTokenDesc =>
      'This will invalidate the previous NFC URL. Any physical tag with the old URL must be reprogrammed with the new URL.';

  @override
  String get nfcRegenerateConfirm => 'Regenerate';

  @override
  String get nfcRegeneratedSuccess => 'NFC token regenerated successfully';

  @override
  String get nfcNdefWriteInstructions =>
      'Write this exact URL as an NDEF URI/URL record to your physical NFC tag using any standard NFC writer app (e.g. NFC Tools on iOS/Android).';

  @override
  String get nfcVerificationTitle => 'NFC Check-In Verification';

  @override
  String get nfcVerifyingStation => 'Verifying NFC Station...';

  @override
  String get nfcEmployeeDetected => 'Authenticated Employee';

  @override
  String get nfcProcessingPunch => 'Recording attendance with server...';

  @override
  String get nfcCheckInSuccessTitle => 'Shift Started Successfully';

  @override
  String get nfcCheckOutSuccessTitle => 'Shift Ended Successfully';

  @override
  String get nfcStationLabel => 'Station';

  @override
  String get nfcTimeConfirmedLabel => 'Server Time Confirmed';

  @override
  String get nfcWorkedDurationLabel => 'Worked Duration';

  @override
  String get nfcReturnToDashboard => 'Go to Dashboard';

  @override
  String get nfcTapPhysicalPrompt =>
      'Tap the physical NFC tag at your workplace with your phone to start or end your shift.';

  @override
  String get nfcErrorInvalidToken => 'Invalid or expired NFC tag token.';

  @override
  String get nfcErrorInactiveStation =>
      'The station for this NFC tag is currently inactive.';

  @override
  String get nfcErrorUnauthorized => 'You are not authorized for this station.';

  @override
  String get nfcErrorDuplicatePunch =>
      'Duplicate punch detected. Please wait a moment before tapping again.';

  @override
  String get stationSelectSignOut => 'Sign Out';

  @override
  String get stationSelectRefresh => 'Refresh';

  @override
  String get stationSelectNoStationActionHint =>
      'You are not assigned to an active station yet. Contact your station manager to get assigned, or sign out to switch accounts.';

  @override
  String get stationSelectSwitchAccount => 'Switch Account';
}
