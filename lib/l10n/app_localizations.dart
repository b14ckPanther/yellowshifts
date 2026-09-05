import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'YellowShifts'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Workforce Operations Platform'**
  String get appTagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get navSchedule;

  /// No description provided for @navAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get navAttendance;

  /// No description provided for @navEmployees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get navEmployees;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get navAvailability;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navDesignSystem.
  ///
  /// In en, this message translates to:
  /// **'Design System'**
  String get navDesignSystem;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In to YellowShifts'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your credentials to access your station operations.'**
  String get loginSubtitle;

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get loginEmailLabel;

  /// No description provided for @loginEmailHint.
  ///
  /// In en, this message translates to:
  /// **'name@yellowshifts.com'**
  String get loginEmailHint;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get loginPasswordHint;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In to Operations'**
  String get loginButton;

  /// No description provided for @loginLoading.
  ///
  /// In en, this message translates to:
  /// **'Authenticating...'**
  String get loginLoading;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password. Please verify and try again.'**
  String get loginInvalidCredentials;

  /// No description provided for @loginNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the server. Check your network connection.'**
  String get loginNetworkError;

  /// No description provided for @loginValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter both your email address and password.'**
  String get loginValidationEmpty;

  /// No description provided for @loginHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Operational Velocity.\nMulti-Station Precision.'**
  String get loginHeroTitle;

  /// No description provided for @loginHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A modern workforce operations engine designed for stations, shift managers, and field staff with real-time synchronization.'**
  String get loginHeroSubtitle;

  /// No description provided for @loginHeroBadge.
  ///
  /// In en, this message translates to:
  /// **'YellowShifts Operations • Supabase Verified'**
  String get loginHeroBadge;

  /// No description provided for @stationSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Station'**
  String get stationSelectTitle;

  /// No description provided for @stationSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You belong to multiple stations. Choose an active station to proceed.'**
  String get stationSelectSubtitle;

  /// No description provided for @stationSelectAction.
  ///
  /// In en, this message translates to:
  /// **'Enter Station'**
  String get stationSelectAction;

  /// No description provided for @stationActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get stationActiveBadge;

  /// No description provided for @stationInactiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get stationInactiveBadge;

  /// No description provided for @emptyStationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Active Station Selected'**
  String get emptyStationsTitle;

  /// No description provided for @emptyStationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Please select or request access to a station to access operational features.'**
  String get emptyStationsDescription;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get roleAdmin;

  /// No description provided for @roleShiftManager.
  ///
  /// In en, this message translates to:
  /// **'Shift Manager'**
  String get roleShiftManager;

  /// No description provided for @roleEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get roleEmployee;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Station Overview'**
  String get dashboardTitle;

  /// No description provided for @dashboardWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String dashboardWelcome(String name);

  /// No description provided for @dashboardActiveStation.
  ///
  /// In en, this message translates to:
  /// **'Current Station: {stationName}'**
  String dashboardActiveStation(String stationName);

  /// No description provided for @dashboardStationCode.
  ///
  /// In en, this message translates to:
  /// **'Station Code'**
  String get dashboardStationCode;

  /// No description provided for @dashboardTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get dashboardTimezone;

  /// No description provided for @dashboardRole.
  ///
  /// In en, this message translates to:
  /// **'Your Role'**
  String get dashboardRole;

  /// No description provided for @dashboardQuickStats.
  ///
  /// In en, this message translates to:
  /// **'Operational Pulse'**
  String get dashboardQuickStats;

  /// No description provided for @dashboardRealtimeSync.
  ///
  /// In en, this message translates to:
  /// **'Realtime Connected'**
  String get dashboardRealtimeSync;

  /// No description provided for @dashboardActiveMembers.
  ///
  /// In en, this message translates to:
  /// **'Active Workforce'**
  String get dashboardActiveMembers;

  /// No description provided for @dashboardAdminsCount.
  ///
  /// In en, this message translates to:
  /// **'Administrators'**
  String get dashboardAdminsCount;

  /// No description provided for @dashboardManagersCount.
  ///
  /// In en, this message translates to:
  /// **'Shift Managers'**
  String get dashboardManagersCount;

  /// No description provided for @dashboardEmployeesCount.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get dashboardEmployeesCount;

  /// No description provided for @dashboardEmptyOnboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Your New Station'**
  String get dashboardEmptyOnboardingTitle;

  /// No description provided for @dashboardEmptyOnboardingDesc.
  ///
  /// In en, this message translates to:
  /// **'Your station has been provisioned. Begin by adding your first employee or configuring station operating parameters.'**
  String get dashboardEmptyOnboardingDesc;

  /// No description provided for @employeesTitle.
  ///
  /// In en, this message translates to:
  /// **'Employee Directory'**
  String get employeesTitle;

  /// No description provided for @employeesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage workforce accounts, station roles, and access security.'**
  String get employeesSubtitle;

  /// No description provided for @employeesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, phone, or employee code...'**
  String get employeesSearchHint;

  /// No description provided for @employeesFilterAllRoles.
  ///
  /// In en, this message translates to:
  /// **'All Roles'**
  String get employeesFilterAllRoles;

  /// No description provided for @employeesFilterAllStatus.
  ///
  /// In en, this message translates to:
  /// **'All Statuses'**
  String get employeesFilterAllStatus;

  /// No description provided for @employeesAddButton.
  ///
  /// In en, this message translates to:
  /// **'New Employee'**
  String get employeesAddButton;

  /// No description provided for @employeesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Employees Found'**
  String get employeesEmptyTitle;

  /// No description provided for @employeesEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'No employees have been registered in this station yet.'**
  String get employeesEmptyDesc;

  /// No description provided for @employeesEmptySearchDesc.
  ///
  /// In en, this message translates to:
  /// **'No workforce records matched your search query.'**
  String get employeesEmptySearchDesc;

  /// No description provided for @employeesColName.
  ///
  /// In en, this message translates to:
  /// **'Name & Identity'**
  String get employeesColName;

  /// No description provided for @employeesColRole.
  ///
  /// In en, this message translates to:
  /// **'Station Role'**
  String get employeesColRole;

  /// No description provided for @employeesColStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get employeesColStatus;

  /// No description provided for @employeesColPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get employeesColPhone;

  /// No description provided for @employeesColCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get employeesColCode;

  /// No description provided for @employeesColActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get employeesColActions;

  /// No description provided for @createEmployeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Provision Employee Account'**
  String get createEmployeeTitle;

  /// No description provided for @createEmployeeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new workforce account or assign an existing member to this station.'**
  String get createEmployeeSubtitle;

  /// No description provided for @createEmployeeStepIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity & Contact'**
  String get createEmployeeStepIdentity;

  /// No description provided for @createEmployeeStepRole.
  ///
  /// In en, this message translates to:
  /// **'Station & Role'**
  String get createEmployeeStepRole;

  /// No description provided for @createEmployeeStepAccess.
  ///
  /// In en, this message translates to:
  /// **'Access Credentials'**
  String get createEmployeeStepAccess;

  /// No description provided for @createEmployeeFirstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get createEmployeeFirstName;

  /// No description provided for @createEmployeeLastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get createEmployeeLastName;

  /// No description provided for @createEmployeeEmail.
  ///
  /// In en, this message translates to:
  /// **'Email Address (Optional)'**
  String get createEmployeeEmail;

  /// No description provided for @createEmployeePhone.
  ///
  /// In en, this message translates to:
  /// **'Mobile Phone Number'**
  String get createEmployeePhone;

  /// No description provided for @createEmployeeCode.
  ///
  /// In en, this message translates to:
  /// **'Station Employee Code (Optional)'**
  String get createEmployeeCode;

  /// No description provided for @createEmployeeRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Assign Station Role'**
  String get createEmployeeRoleLabel;

  /// No description provided for @createEmployeeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create Employee Account'**
  String get createEmployeeSubmit;

  /// No description provided for @createEmployeeSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Provisioned Successfully'**
  String get createEmployeeSuccessTitle;

  /// No description provided for @createEmployeeSuccessDesc.
  ///
  /// In en, this message translates to:
  /// **'The employee account has been created. Provide the one-time temporary credentials to the employee securely.'**
  String get createEmployeeSuccessDesc;

  /// No description provided for @createEmployeeTempPassword.
  ///
  /// In en, this message translates to:
  /// **'One-Time Temporary Password'**
  String get createEmployeeTempPassword;

  /// No description provided for @createEmployeeCopyPassword.
  ///
  /// In en, this message translates to:
  /// **'Copy Credentials'**
  String get createEmployeeCopyPassword;

  /// No description provided for @createEmployeeCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Temporary credentials copied to clipboard'**
  String get createEmployeeCopiedToast;

  /// No description provided for @createEmployeeSecurityNotice.
  ///
  /// In en, this message translates to:
  /// **'This temporary password is only displayed once and is never stored in plaintext.'**
  String get createEmployeeSecurityNotice;

  /// No description provided for @inspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Employee Details'**
  String get inspectorTitle;

  /// No description provided for @inspectorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Station membership and access management'**
  String get inspectorSubtitle;

  /// No description provided for @inspectorContactSection.
  ///
  /// In en, this message translates to:
  /// **'Contact & Identity'**
  String get inspectorContactSection;

  /// No description provided for @inspectorRoleSection.
  ///
  /// In en, this message translates to:
  /// **'Station Role & Authority'**
  String get inspectorRoleSection;

  /// No description provided for @inspectorMembershipSection.
  ///
  /// In en, this message translates to:
  /// **'Station Role & Authority'**
  String get inspectorMembershipSection;

  /// No description provided for @inspectorStatusSection.
  ///
  /// In en, this message translates to:
  /// **'Membership Status'**
  String get inspectorStatusSection;

  /// No description provided for @inspectorSecuritySection.
  ///
  /// In en, this message translates to:
  /// **'Account Security Actions'**
  String get inspectorSecuritySection;

  /// No description provided for @inspectorChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change Role'**
  String get inspectorChangeRole;

  /// No description provided for @inspectorRoleChange.
  ///
  /// In en, this message translates to:
  /// **'Change Role'**
  String get inspectorRoleChange;

  /// No description provided for @inspectorChangeStatus.
  ///
  /// In en, this message translates to:
  /// **'Change Status'**
  String get inspectorChangeStatus;

  /// No description provided for @inspectorResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get inspectorResetPassword;

  /// No description provided for @inspectorResetPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Generate new temporary credentials for this employee?'**
  String get inspectorResetPasswordConfirm;

  /// No description provided for @inspectorRevokeSessions.
  ///
  /// In en, this message translates to:
  /// **'Revoke All Sessions'**
  String get inspectorRevokeSessions;

  /// No description provided for @inspectorRevokeSessionsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Force sign-out all active sessions for this user?'**
  String get inspectorRevokeSessionsConfirm;

  /// No description provided for @inspectorLastAdminNotice.
  ///
  /// In en, this message translates to:
  /// **'Cannot demote or deactivate the last Administrator of this station.'**
  String get inspectorLastAdminNotice;

  /// No description provided for @inspectorDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Employee'**
  String get inspectorDeactivate;

  /// No description provided for @inspectorReactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate Employee'**
  String get inspectorReactivate;

  /// No description provided for @inspectorActionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Operation completed successfully'**
  String get inspectorActionSuccess;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @dialogOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get dialogOk;

  /// No description provided for @stationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Station Operational Parameters'**
  String get stationSettingsTitle;

  /// No description provided for @stationSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage station code, timezone, locale, and operational week start.'**
  String get stationSettingsSubtitle;

  /// No description provided for @stationSettingsName.
  ///
  /// In en, this message translates to:
  /// **'Station Name'**
  String get stationSettingsName;

  /// No description provided for @stationSettingsCode.
  ///
  /// In en, this message translates to:
  /// **'Operational Code'**
  String get stationSettingsCode;

  /// No description provided for @stationSettingsTimezone.
  ///
  /// In en, this message translates to:
  /// **'Operational Timezone'**
  String get stationSettingsTimezone;

  /// No description provided for @stationSettingsLocale.
  ///
  /// In en, this message translates to:
  /// **'Default Locale'**
  String get stationSettingsLocale;

  /// No description provided for @stationSettingsWeekStart.
  ///
  /// In en, this message translates to:
  /// **'Operational Week Starts On'**
  String get stationSettingsWeekStart;

  /// No description provided for @stationSettingsSunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday (Standard Israeli Week)'**
  String get stationSettingsSunday;

  /// No description provided for @stationSettingsMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get stationSettingsMonday;

  /// No description provided for @stationSettingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save Station Parameters'**
  String get stationSettingsSave;

  /// No description provided for @stationSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Station parameters updated successfully'**
  String get stationSettingsSaved;

  /// No description provided for @stationSettingsSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Station parameters updated successfully'**
  String get stationSettingsSavedToast;

  /// No description provided for @shiftsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Templates'**
  String get shiftsTitle;

  /// No description provided for @shiftsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure station working shifts, operational hours, and ordering.'**
  String get shiftsSubtitle;

  /// No description provided for @shiftsAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Shift Template'**
  String get shiftsAddButton;

  /// No description provided for @shiftsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Shift Templates'**
  String get shiftsEmptyTitle;

  /// No description provided for @shiftsEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Define your station\'s shift templates to enable weekly availability submissions.'**
  String get shiftsEmptyDesc;

  /// No description provided for @shiftsColName.
  ///
  /// In en, this message translates to:
  /// **'Shift Name'**
  String get shiftsColName;

  /// No description provided for @shiftsColTimes.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get shiftsColTimes;

  /// No description provided for @shiftsColDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get shiftsColDuration;

  /// No description provided for @shiftsColStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get shiftsColStatus;

  /// No description provided for @shiftsCrossMidnight.
  ///
  /// In en, this message translates to:
  /// **'Crosses Midnight (+1 day)'**
  String get shiftsCrossMidnight;

  /// No description provided for @shiftsDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get shiftsDeactivate;

  /// No description provided for @shiftsReactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get shiftsReactivate;

  /// No description provided for @shiftsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Shift'**
  String get shiftsEdit;

  /// No description provided for @shiftsCreateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New Shift Template'**
  String get shiftsCreateDialogTitle;

  /// No description provided for @shiftsEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Shift Template'**
  String get shiftsEditDialogTitle;

  /// No description provided for @shiftsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift Name'**
  String get shiftsNameLabel;

  /// No description provided for @shiftsNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Morning, Evening, Night...'**
  String get shiftsNameHint;

  /// No description provided for @shiftsCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Operational Code (Optional)'**
  String get shiftsCodeLabel;

  /// No description provided for @shiftsCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. MOR, EVE'**
  String get shiftsCodeHint;

  /// No description provided for @shiftsStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get shiftsStartTime;

  /// No description provided for @shiftsEndTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get shiftsEndTime;

  /// No description provided for @shiftsSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Shift Template'**
  String get shiftsSaveButton;

  /// No description provided for @permissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Manager Capabilities'**
  String get permissionsTitle;

  /// No description provided for @permissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure operational permissions and management overrides for Shift Managers.'**
  String get permissionsSubtitle;

  /// No description provided for @permissionsSectionTemplates.
  ///
  /// In en, this message translates to:
  /// **'Shift Templates Management'**
  String get permissionsSectionTemplates;

  /// No description provided for @permissionsShiftTemplatesManage.
  ///
  /// In en, this message translates to:
  /// **'Create, edit, and reorder shift templates'**
  String get permissionsShiftTemplatesManage;

  /// No description provided for @permissionsSectionAvailability.
  ///
  /// In en, this message translates to:
  /// **'Weekly Availability Operations'**
  String get permissionsSectionAvailability;

  /// No description provided for @permissionsAvailabilityPeriodCreate.
  ///
  /// In en, this message translates to:
  /// **'Create draft weekly availability periods'**
  String get permissionsAvailabilityPeriodCreate;

  /// No description provided for @permissionsAvailabilityPeriodOpen.
  ///
  /// In en, this message translates to:
  /// **'Open availability submission periods'**
  String get permissionsAvailabilityPeriodOpen;

  /// No description provided for @permissionsAvailabilityPeriodClose.
  ///
  /// In en, this message translates to:
  /// **'Close and reopen availability periods'**
  String get permissionsAvailabilityPeriodClose;

  /// No description provided for @permissionsAvailabilityTeamRead.
  ///
  /// In en, this message translates to:
  /// **'View team availability matrix and submissions'**
  String get permissionsAvailabilityTeamRead;

  /// No description provided for @permissionsSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Capability Overrides'**
  String get permissionsSaveButton;

  /// No description provided for @permissionsSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Shift Manager permissions updated successfully'**
  String get permissionsSavedToast;

  /// No description provided for @availabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Availability'**
  String get availabilityTitle;

  /// No description provided for @availabilitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit your working preferences for upcoming station shifts.'**
  String get availabilitySubtitle;

  /// No description provided for @availabilityNoPeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'No Open Availability Request'**
  String get availabilityNoPeriodTitle;

  /// No description provided for @availabilityNoPeriodDesc.
  ///
  /// In en, this message translates to:
  /// **'There is currently no open availability period for this station.'**
  String get availabilityNoPeriodDesc;

  /// No description provided for @availabilityDeadlineNotice.
  ///
  /// In en, this message translates to:
  /// **'Submission Deadline: {deadline}'**
  String availabilityDeadlineNotice(String deadline);

  /// No description provided for @availabilityStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get availabilityStatusDraft;

  /// No description provided for @availabilityStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get availabilityStatusSubmitted;

  /// No description provided for @availabilityStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed (Read Only)'**
  String get availabilityStatusClosed;

  /// No description provided for @availabilityStatusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get availabilityStatusNotStarted;

  /// No description provided for @availabilityProgress.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} slots answered'**
  String availabilityProgress(int answered, int total);

  /// No description provided for @availabilityAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availabilityAvailable;

  /// No description provided for @availabilityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get availabilityUnavailable;

  /// No description provided for @availabilityUnanswered.
  ///
  /// In en, this message translates to:
  /// **'Unanswered'**
  String get availabilityUnanswered;

  /// No description provided for @availabilityAllDayAvailable.
  ///
  /// In en, this message translates to:
  /// **'All Day Available'**
  String get availabilityAllDayAvailable;

  /// No description provided for @availabilityAllDayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'All Day Unavailable'**
  String get availabilityAllDayUnavailable;

  /// No description provided for @availabilitySubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Availability'**
  String get availabilitySubmitButton;

  /// No description provided for @availabilityEditNotice.
  ///
  /// In en, this message translates to:
  /// **'Editing an answered slot will return your submission to Draft until resubmitted.'**
  String get availabilityEditNotice;

  /// No description provided for @availabilitySubmittedConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Availability submitted successfully for {week}'**
  String availabilitySubmittedConfirmation(String week);

  /// No description provided for @availabilitySavingDraft.
  ///
  /// In en, this message translates to:
  /// **'Saving draft...'**
  String get availabilitySavingDraft;

  /// No description provided for @availabilityDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get availabilityDraftSaved;

  /// No description provided for @managerAvailabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Team Availability Matrix'**
  String get managerAvailabilityTitle;

  /// No description provided for @managerAvailabilitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review submitted workforce availability, submission progress, and operational readiness.'**
  String get managerAvailabilitySubtitle;

  /// No description provided for @managerKpiEligible.
  ///
  /// In en, this message translates to:
  /// **'Eligible Workforce'**
  String get managerKpiEligible;

  /// No description provided for @managerKpiSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get managerKpiSubmitted;

  /// No description provided for @managerKpiDraft.
  ///
  /// In en, this message translates to:
  /// **'In Draft'**
  String get managerKpiDraft;

  /// No description provided for @managerKpiNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get managerKpiNotStarted;

  /// No description provided for @managerKpiNotSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Pending Submission'**
  String get managerKpiNotSubmitted;

  /// No description provided for @managerFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All Members'**
  String get managerFilterAll;

  /// No description provided for @managerFilterSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get managerFilterSubmitted;

  /// No description provided for @managerFilterDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get managerFilterDraft;

  /// No description provided for @managerFilterNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get managerFilterNotStarted;

  /// No description provided for @managerOpenPeriod.
  ///
  /// In en, this message translates to:
  /// **'Open Submissions'**
  String get managerOpenPeriod;

  /// No description provided for @managerClosePeriod.
  ///
  /// In en, this message translates to:
  /// **'Close Submissions'**
  String get managerClosePeriod;

  /// No description provided for @managerReopenPeriod.
  ///
  /// In en, this message translates to:
  /// **'Reopen Submissions'**
  String get managerReopenPeriod;

  /// No description provided for @managerCreatePeriod.
  ///
  /// In en, this message translates to:
  /// **'Create Period'**
  String get managerCreatePeriod;

  /// No description provided for @managerPeriodHistory.
  ///
  /// In en, this message translates to:
  /// **'Past Periods'**
  String get managerPeriodHistory;

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Shift Schedule'**
  String get scheduleTitle;

  /// No description provided for @scheduleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Assign employees, balance shift staffing, and publish official station schedules.'**
  String get scheduleSubtitle;

  /// No description provided for @scheduleDraftStatus.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get scheduleDraftStatus;

  /// No description provided for @schedulePublishedStatus.
  ///
  /// In en, this message translates to:
  /// **'Official Published'**
  String get schedulePublishedStatus;

  /// No description provided for @schedulePublishAction.
  ///
  /// In en, this message translates to:
  /// **'Publish Schedule'**
  String get schedulePublishAction;

  /// No description provided for @scheduleStaffingCoverage.
  ///
  /// In en, this message translates to:
  /// **'Staffing Coverage: {percent}%'**
  String scheduleStaffingCoverage(String percent);

  /// No description provided for @myShiftsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Shifts'**
  String get myShiftsTitle;

  /// No description provided for @myShiftsEmptyDraft.
  ///
  /// In en, this message translates to:
  /// **'No official schedule published for this week'**
  String get myShiftsEmptyDraft;

  /// No description provided for @myShiftsEmptyAssigned.
  ///
  /// In en, this message translates to:
  /// **'You have no assigned shifts for this week'**
  String get myShiftsEmptyAssigned;

  /// No description provided for @candidateAssignAction.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get candidateAssignAction;

  /// No description provided for @candidateOverrideAction.
  ///
  /// In en, this message translates to:
  /// **'Assign with Override'**
  String get candidateOverrideAction;

  /// No description provided for @candidateAlreadyAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get candidateAlreadyAssigned;

  /// No description provided for @attendanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Station Attendance'**
  String get attendanceTitle;

  /// No description provided for @attendanceNotCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Not Checked In'**
  String get attendanceNotCheckedIn;

  /// No description provided for @attendanceCurrentlyWorking.
  ///
  /// In en, this message translates to:
  /// **'CURRENTLY WORKING'**
  String get attendanceCurrentlyWorking;

  /// No description provided for @attendanceScanQrAction.
  ///
  /// In en, this message translates to:
  /// **'Scan Station QR'**
  String get attendanceScanQrAction;

  /// No description provided for @attendanceCheckOutAction.
  ///
  /// In en, this message translates to:
  /// **'Check Out'**
  String get attendanceCheckOutAction;

  /// No description provided for @attendanceRecentHistory.
  ///
  /// In en, this message translates to:
  /// **'Recent Shifts'**
  String get attendanceRecentHistory;

  /// No description provided for @attendanceLiveMonitor.
  ///
  /// In en, this message translates to:
  /// **'Live Attendance'**
  String get attendanceLiveMonitor;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Center'**
  String get notificationsTitle;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Realtime shift updates, live attendance alerts, reminders, and operational events'**
  String get notificationsSubtitle;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications found'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'You are all caught up! New schedule, attendance, and system notices will appear here.'**
  String get notificationsEmptyDesc;

  /// No description provided for @notificationsUnreadOnly.
  ///
  /// In en, this message translates to:
  /// **'Unread only'**
  String get notificationsUnreadOnly;

  /// No description provided for @notificationPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Channels & Preferences'**
  String get notificationPreferencesTitle;

  /// No description provided for @notificationPreferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure in-app, push, email, and SMS delivery for each category'**
  String get notificationPreferencesSubtitle;

  /// No description provided for @notificationMandatoryNotice.
  ///
  /// In en, this message translates to:
  /// **'Mandatory Compliance & Security Notices'**
  String get notificationMandatoryNotice;

  /// No description provided for @notificationMandatoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Critical security alerts, manual attendance adjustments, and identity overrides are mandatory and always delivered in-app for auditing.'**
  String get notificationMandatoryDesc;

  /// No description provided for @notificationDeliveryMatrix.
  ///
  /// In en, this message translates to:
  /// **'Delivery Matrix'**
  String get notificationDeliveryMatrix;

  /// No description provided for @notificationDeliveryMatrixDesc.
  ///
  /// In en, this message translates to:
  /// **'Toggle preferred communication channels for each operational category'**
  String get notificationDeliveryMatrixDesc;

  /// No description provided for @navMyHours.
  ///
  /// In en, this message translates to:
  /// **'My Hours'**
  String get navMyHours;

  /// No description provided for @myHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'My Worked Hours'**
  String get myHoursTitle;

  /// No description provided for @myHoursSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personal attendance timeline, shift duration history, and active sessions across all stations'**
  String get myHoursSubtitle;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Station Operational Reports'**
  String get reportsTitle;

  /// No description provided for @reportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Authoritative time records, station metrics, employee breakdowns, and daily shift rosters'**
  String get reportsSubtitle;

  /// No description provided for @kpiTotalWorked.
  ///
  /// In en, this message translates to:
  /// **'Total Worked Time'**
  String get kpiTotalWorked;

  /// No description provided for @kpiCompletedShifts.
  ///
  /// In en, this message translates to:
  /// **'Completed Shifts'**
  String get kpiCompletedShifts;

  /// No description provided for @kpiLateShifts.
  ///
  /// In en, this message translates to:
  /// **'Late Shifts'**
  String get kpiLateShifts;

  /// No description provided for @kpiTotalLateTime.
  ///
  /// In en, this message translates to:
  /// **'Total Late Time'**
  String get kpiTotalLateTime;

  /// No description provided for @kpiCorrectedRecords.
  ///
  /// In en, this message translates to:
  /// **'Corrected Records'**
  String get kpiCorrectedRecords;

  /// No description provided for @kpiActiveOpenSessions.
  ///
  /// In en, this message translates to:
  /// **'Active Open Shifts'**
  String get kpiActiveOpenSessions;

  /// No description provided for @kpiRepeatedLateness.
  ///
  /// In en, this message translates to:
  /// **'Repeated Lateness'**
  String get kpiRepeatedLateness;

  /// No description provided for @kpiActiveWorkforce.
  ///
  /// In en, this message translates to:
  /// **'Active Station Workforce'**
  String get kpiActiveWorkforce;

  /// No description provided for @kpiAverageShift.
  ///
  /// In en, this message translates to:
  /// **'Avg Shift Duration'**
  String get kpiAverageShift;

  /// No description provided for @kpiOnTimeRate.
  ///
  /// In en, this message translates to:
  /// **'On-Time Rate'**
  String get kpiOnTimeRate;

  /// No description provided for @presetToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get presetToday;

  /// No description provided for @presetCurrentWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get presetCurrentWeek;

  /// No description provided for @presetCurrentMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get presetCurrentMonth;

  /// No description provided for @presetLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get presetLastMonth;

  /// No description provided for @presetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Range'**
  String get presetCustom;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All Shifts'**
  String get filterAll;

  /// No description provided for @filterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get filterCompleted;

  /// No description provided for @filterLate.
  ///
  /// In en, this message translates to:
  /// **'Late Only'**
  String get filterLate;

  /// No description provided for @filterCorrected.
  ///
  /// In en, this message translates to:
  /// **'Corrected'**
  String get filterCorrected;

  /// No description provided for @filterOpen.
  ///
  /// In en, this message translates to:
  /// **'Active Open'**
  String get filterOpen;

  /// No description provided for @tabBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Workforce Breakdown'**
  String get tabBreakdown;

  /// No description provided for @tabDailyBoard.
  ///
  /// In en, this message translates to:
  /// **'Daily Operational Board'**
  String get tabDailyBoard;

  /// No description provided for @searchEmployeesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search by name or employee code...'**
  String get searchEmployeesPlaceholder;

  /// No description provided for @employeeDrilldownTitle.
  ///
  /// In en, this message translates to:
  /// **'Employee Attendance & History'**
  String get employeeDrilldownTitle;

  /// No description provided for @correctionLedger.
  ///
  /// In en, this message translates to:
  /// **'Correction Ledger'**
  String get correctionLedger;

  /// No description provided for @noAttendanceFound.
  ///
  /// In en, this message translates to:
  /// **'No attendance records found for this selected period.'**
  String get noAttendanceFound;

  /// No description provided for @selectDatePrompt.
  ///
  /// In en, this message translates to:
  /// **'Select Operational Date'**
  String get selectDatePrompt;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get statusInactive;

  /// No description provided for @statusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get statusSuspended;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navShiftTemplates.
  ///
  /// In en, this message translates to:
  /// **'Shift Templates'**
  String get navShiftTemplates;

  /// No description provided for @navStationSettings.
  ///
  /// In en, this message translates to:
  /// **'Station Settings'**
  String get navStationSettings;

  /// No description provided for @navSectionWorkspace.
  ///
  /// In en, this message translates to:
  /// **'My Workspace'**
  String get navSectionWorkspace;

  /// No description provided for @navSectionManagement.
  ///
  /// In en, this message translates to:
  /// **'Station Management'**
  String get navSectionManagement;

  /// No description provided for @navSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'Account & System'**
  String get navSectionGeneral;

  /// No description provided for @switchStationContext.
  ///
  /// In en, this message translates to:
  /// **'Switch Station Context'**
  String get switchStationContext;

  /// No description provided for @noPhoneRegistered.
  ///
  /// In en, this message translates to:
  /// **'No phone registered'**
  String get noPhoneRegistered;

  /// No description provided for @noCodeAssigned.
  ///
  /// In en, this message translates to:
  /// **'None assigned'**
  String get noCodeAssigned;

  /// No description provided for @notProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notProvided;

  /// No description provided for @joinedStationLabel.
  ///
  /// In en, this message translates to:
  /// **'Joined Station'**
  String get joinedStationLabel;

  /// No description provided for @allStatusesFilter.
  ///
  /// In en, this message translates to:
  /// **'All Statuses'**
  String get allStatusesFilter;

  /// No description provided for @filterStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get filterStatusActive;

  /// No description provided for @filterStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get filterStatusInactive;

  /// No description provided for @filterStatusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get filterStatusSuspended;

  /// No description provided for @selectEmployeePrompt.
  ///
  /// In en, this message translates to:
  /// **'Select an employee to view operational details'**
  String get selectEmployeePrompt;

  /// No description provided for @colNameIdentity.
  ///
  /// In en, this message translates to:
  /// **'NAME & IDENTITY'**
  String get colNameIdentity;

  /// No description provided for @colStationRole.
  ///
  /// In en, this message translates to:
  /// **'STATION ROLE'**
  String get colStationRole;

  /// No description provided for @colStatus.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get colStatus;

  /// No description provided for @colPhone.
  ///
  /// In en, this message translates to:
  /// **'PHONE'**
  String get colPhone;

  /// No description provided for @colCode.
  ///
  /// In en, this message translates to:
  /// **'CODE'**
  String get colCode;

  /// No description provided for @dashboardStationOverview.
  ///
  /// In en, this message translates to:
  /// **'Station Overview'**
  String get dashboardStationOverview;

  /// No description provided for @dashboardEmployeeNextShift.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Shift'**
  String get dashboardEmployeeNextShift;

  /// No description provided for @dashboardEmployeeNoShift.
  ///
  /// In en, this message translates to:
  /// **'No shifts scheduled for today'**
  String get dashboardEmployeeNoShift;

  /// No description provided for @dashboardEmployeeAttendanceStatus.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Attendance Status'**
  String get dashboardEmployeeAttendanceStatus;

  /// No description provided for @dashboardEmployeeActiveShift.
  ///
  /// In en, this message translates to:
  /// **'Shift In Progress'**
  String get dashboardEmployeeActiveShift;

  /// No description provided for @dashboardEmployeeNotCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Not Clocked In'**
  String get dashboardEmployeeNotCheckedIn;

  /// No description provided for @dashboardEmployeeClockInAction.
  ///
  /// In en, this message translates to:
  /// **'Clock In with QR'**
  String get dashboardEmployeeClockInAction;

  /// No description provided for @dashboardEmployeeClockOutAction.
  ///
  /// In en, this message translates to:
  /// **'Clock Out'**
  String get dashboardEmployeeClockOutAction;

  /// No description provided for @dashboardEmployeeMyHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Worked Hours Summary'**
  String get dashboardEmployeeMyHoursTitle;

  /// No description provided for @dashboardEmployeeAvailabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Availability'**
  String get dashboardEmployeeAvailabilityTitle;

  /// No description provided for @dashboardEmployeeAvailabilityOpen.
  ///
  /// In en, this message translates to:
  /// **'Availability submission is open'**
  String get dashboardEmployeeAvailabilityOpen;

  /// No description provided for @dashboardEmployeeAvailabilitySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Availability successfully submitted'**
  String get dashboardEmployeeAvailabilitySubmitted;

  /// No description provided for @dashboardEmployeeAvailabilityClosed.
  ///
  /// In en, this message translates to:
  /// **'No active submission period'**
  String get dashboardEmployeeAvailabilityClosed;

  /// No description provided for @dashboardManagerStaffingTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Operational Staffing'**
  String get dashboardManagerStaffingTitle;

  /// No description provided for @dashboardManagerStaffingRequired.
  ///
  /// In en, this message translates to:
  /// **'Required: {count}'**
  String dashboardManagerStaffingRequired(int count);

  /// No description provided for @dashboardManagerStaffingAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned: {count}'**
  String dashboardManagerStaffingAssigned(int count);

  /// No description provided for @dashboardManagerStaffingCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked In: {count}'**
  String dashboardManagerStaffingCheckedIn(int count);

  /// No description provided for @dashboardManagerStaffingShortage.
  ///
  /// In en, this message translates to:
  /// **'Shortage: {count}'**
  String dashboardManagerStaffingShortage(int count);

  /// No description provided for @dashboardManagerLiveAttendanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Attendance Roster'**
  String get dashboardManagerLiveAttendanceTitle;

  /// No description provided for @dashboardManagerAvailabilityOverview.
  ///
  /// In en, this message translates to:
  /// **'Team Availability Progress'**
  String get dashboardManagerAvailabilityOverview;

  /// No description provided for @dashboardManagerAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Operational Alerts'**
  String get dashboardManagerAlertsTitle;

  /// No description provided for @dashboardManagerLateArrivals.
  ///
  /// In en, this message translates to:
  /// **'{count} Late Arrivals'**
  String dashboardManagerLateArrivals(int count);

  /// No description provided for @dashboardManagerLongSessions.
  ///
  /// In en, this message translates to:
  /// **'{count} Shifts Exceeding 16h'**
  String dashboardManagerLongSessions(int count);

  /// No description provided for @dashboardAdminPulseTitle.
  ///
  /// In en, this message translates to:
  /// **'Station Workforce Summary'**
  String get dashboardAdminPulseTitle;

  /// No description provided for @dashboardAdminQuickShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Administrative Shortcuts'**
  String get dashboardAdminQuickShortcuts;

  /// No description provided for @dashboardAdminNfcSummary.
  ///
  /// In en, this message translates to:
  /// **'NFC Tags Fleet'**
  String get dashboardAdminNfcSummary;

  /// No description provided for @dashboardAdminSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Station Settings'**
  String get dashboardAdminSettingsAction;

  /// No description provided for @dashboardAdminAddEmployeeAction.
  ///
  /// In en, this message translates to:
  /// **'Add Employee'**
  String get dashboardAdminAddEmployeeAction;

  /// No description provided for @employeeEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Employee Profile'**
  String get employeeEditTitle;

  /// No description provided for @employeeEditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Modify profile and station membership properties'**
  String get employeeEditSubtitle;

  /// No description provided for @employeeEditGlobalNotice.
  ///
  /// In en, this message translates to:
  /// **'First Name, Last Name, Phone, and Preferred Locale update globally across all stations.'**
  String get employeeEditGlobalNotice;

  /// No description provided for @employeeEditStationNotice.
  ///
  /// In en, this message translates to:
  /// **'Station Role, Membership Status, and Employee Code apply strictly to this station.'**
  String get employeeEditStationNotice;

  /// No description provided for @employeeEditFirstNameLabel.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get employeeEditFirstNameLabel;

  /// No description provided for @employeeEditLastNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get employeeEditLastNameLabel;

  /// No description provided for @employeeEditPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get employeeEditPhoneLabel;

  /// No description provided for @employeeEditEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get employeeEditEmailLabel;

  /// No description provided for @employeeEditLocaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Preferred Language'**
  String get employeeEditLocaleLabel;

  /// No description provided for @employeeEditRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Station Role'**
  String get employeeEditRoleLabel;

  /// No description provided for @employeeEditStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Membership Status'**
  String get employeeEditStatusLabel;

  /// No description provided for @employeeEditCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Station Employee Code'**
  String get employeeEditCodeLabel;

  /// No description provided for @employeeEditSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get employeeEditSaveButton;

  /// No description provided for @employeeEditSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Employee details updated successfully'**
  String get employeeEditSuccessToast;

  /// No description provided for @employeeEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get employeeEditAction;

  /// No description provided for @employeeResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Employee Password'**
  String get employeeResetPasswordTitle;

  /// No description provided for @employeeResetPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will generate a new temporary password for {name} and invalidate all active sessions.'**
  String employeeResetPasswordConfirm(String name);

  /// No description provided for @employeeResetPasswordGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate New Password'**
  String get employeeResetPasswordGenerate;

  /// No description provided for @employeeResetPasswordSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'New Temporary Password'**
  String get employeeResetPasswordSuccessTitle;

  /// No description provided for @employeeResetPasswordSuccessDesc.
  ///
  /// In en, this message translates to:
  /// **'A new temporary password has been issued for {name}:'**
  String employeeResetPasswordSuccessDesc(String name);

  /// No description provided for @employeeResetPasswordNotice.
  ///
  /// In en, this message translates to:
  /// **'Provide this password to the employee. It will not be shown again.'**
  String get employeeResetPasswordNotice;

  /// No description provided for @employeeRevokeSessionsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Revoke Active Sessions'**
  String get employeeRevokeSessionsConfirm;

  /// No description provided for @employeeRevokeSessionsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Active sessions revoked successfully'**
  String get employeeRevokeSessionsSuccess;

  /// No description provided for @errorLastAdminRequired.
  ///
  /// In en, this message translates to:
  /// **'Cannot demote or deactivate the last active Administrator of this station.'**
  String get errorLastAdminRequired;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied. You do not have permission for this action.'**
  String get errorPermissionDenied;

  /// No description provided for @errorDuplicatePhone.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already registered to another user.'**
  String get errorDuplicatePhone;

  /// No description provided for @errorDuplicateEmail.
  ///
  /// In en, this message translates to:
  /// **'This email address is already registered to another user.'**
  String get errorDuplicateEmail;

  /// No description provided for @errorInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Please verify the entered details.'**
  String get errorInvalidInput;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'The requested record was not found.'**
  String get errorNotFound;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorExportExpired.
  ///
  /// In en, this message translates to:
  /// **'This export link has expired (15-minute validity). Please request a new export.'**
  String get errorExportExpired;

  /// No description provided for @errorActiveAttendanceBlocksDeactivation.
  ///
  /// In en, this message translates to:
  /// **'Cannot deactivate station while active attendance sessions or scheduled shifts are open.'**
  String get errorActiveAttendanceBlocksDeactivation;

  /// No description provided for @dialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dialogCancel;

  /// No description provided for @copyPassword.
  ///
  /// In en, this message translates to:
  /// **'Copy Password'**
  String get copyPassword;

  /// No description provided for @passwordCopied.
  ///
  /// In en, this message translates to:
  /// **'Password copied to clipboard'**
  String get passwordCopied;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @navExports.
  ///
  /// In en, this message translates to:
  /// **'Exports'**
  String get navExports;

  /// No description provided for @navAuditCenter.
  ///
  /// In en, this message translates to:
  /// **'Audit Center'**
  String get navAuditCenter;

  /// No description provided for @navSystemHealth.
  ///
  /// In en, this message translates to:
  /// **'System Health'**
  String get navSystemHealth;

  /// No description provided for @exportCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Operational Export Center'**
  String get exportCenterTitle;

  /// No description provided for @exportCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate certified server-side operational data artifacts with spreadsheet formula defense'**
  String get exportCenterSubtitle;

  /// No description provided for @exportMyHours.
  ///
  /// In en, this message translates to:
  /// **'Export My Attendance Hours'**
  String get exportMyHours;

  /// No description provided for @exportStationAttendanceSummary.
  ///
  /// In en, this message translates to:
  /// **'Station Attendance Summary'**
  String get exportStationAttendanceSummary;

  /// No description provided for @exportStationEmployeeWorkedHours.
  ///
  /// In en, this message translates to:
  /// **'Employee Worked Hours'**
  String get exportStationEmployeeWorkedHours;

  /// No description provided for @exportDailyAttendanceReport.
  ///
  /// In en, this message translates to:
  /// **'Daily Attendance Report'**
  String get exportDailyAttendanceReport;

  /// No description provided for @exportAttendanceCorrectionLedger.
  ///
  /// In en, this message translates to:
  /// **'Attendance Correction Ledger'**
  String get exportAttendanceCorrectionLedger;

  /// No description provided for @exportPublishedSchedule.
  ///
  /// In en, this message translates to:
  /// **'Published Schedule Roster'**
  String get exportPublishedSchedule;

  /// No description provided for @exportEmployeeDirectory.
  ///
  /// In en, this message translates to:
  /// **'Employee Directory & Roster'**
  String get exportEmployeeDirectory;

  /// No description provided for @exportAvailabilityOverview.
  ///
  /// In en, this message translates to:
  /// **'Team Availability Overview'**
  String get exportAvailabilityOverview;

  /// No description provided for @exportFormatCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV (UTF-8 BOM)'**
  String get exportFormatCsv;

  /// No description provided for @exportFormatPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF Document'**
  String get exportFormatPdf;

  /// No description provided for @exportButtonGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate Export'**
  String get exportButtonGenerate;

  /// No description provided for @exportGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating Export...'**
  String get exportGenerating;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Export generated successfully ({rowCount} rows)'**
  String exportSuccess(int rowCount);

  /// No description provided for @exportDownloadButton.
  ///
  /// In en, this message translates to:
  /// **'Download File'**
  String get exportDownloadButton;

  /// No description provided for @exportHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Export Artifacts'**
  String get exportHistoryTitle;

  /// No description provided for @exportHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recent export artifacts found.'**
  String get exportHistoryEmpty;

  /// No description provided for @exportStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get exportStatusCompleted;

  /// No description provided for @exportStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get exportStatusExpired;

  /// No description provided for @exportStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get exportStatusProcessing;

  /// No description provided for @exportStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get exportStatusFailed;

  /// No description provided for @exportExpiryNotice.
  ///
  /// In en, this message translates to:
  /// **'Download links expire automatically after 15 minutes for data security.'**
  String get exportExpiryNotice;

  /// No description provided for @auditCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Administrative Audit Center'**
  String get auditCenterTitle;

  /// No description provided for @auditCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Immutable chronological ledger of administrative mutations and operational actions'**
  String get auditCenterSubtitle;

  /// No description provided for @auditFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All Activities'**
  String get auditFilterAll;

  /// No description provided for @auditFilterMemberships.
  ///
  /// In en, this message translates to:
  /// **'Memberships & Roles'**
  String get auditFilterMemberships;

  /// No description provided for @auditFilterSchedules.
  ///
  /// In en, this message translates to:
  /// **'Schedules & Shifts'**
  String get auditFilterSchedules;

  /// No description provided for @auditFilterAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance & Clock-In'**
  String get auditFilterAttendance;

  /// No description provided for @auditFilterStation.
  ///
  /// In en, this message translates to:
  /// **'Station Configuration'**
  String get auditFilterStation;

  /// No description provided for @auditFilterExports.
  ///
  /// In en, this message translates to:
  /// **'Data Exports'**
  String get auditFilterExports;

  /// No description provided for @auditFilterAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get auditFilterAvailability;

  /// No description provided for @auditSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search by actor, email, action or target...'**
  String get auditSearchPlaceholder;

  /// No description provided for @auditEmptyLogs.
  ///
  /// In en, this message translates to:
  /// **'No audit records found matching criteria.'**
  String get auditEmptyLogs;

  /// No description provided for @auditMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Sanitized Metadata'**
  String get auditMetadataTitle;

  /// No description provided for @auditActor.
  ///
  /// In en, this message translates to:
  /// **'Actor'**
  String get auditActor;

  /// No description provided for @auditAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get auditAction;

  /// No description provided for @auditTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get auditTarget;

  /// No description provided for @auditTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get auditTimestamp;

  /// No description provided for @auditPageInfo.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total} ({count} events)'**
  String auditPageInfo(int current, int total, int count);

  /// No description provided for @systemHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Station Operational Health'**
  String get systemHealthTitle;

  /// No description provided for @systemHealthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live telemetry, station NFC tag fleet status, and data lifecycle management'**
  String get systemHealthSubtitle;

  /// No description provided for @systemHealthExportPipeline.
  ///
  /// In en, this message translates to:
  /// **'Export Pipeline (24h)'**
  String get systemHealthExportPipeline;

  /// No description provided for @systemHealthExportsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} Exports ({failed} Failed)'**
  String systemHealthExportsSummary(int count, int failed);

  /// No description provided for @systemHealthAnomalies.
  ///
  /// In en, this message translates to:
  /// **'System Health & Anomalies'**
  String get systemHealthAnomalies;

  /// No description provided for @systemHealthNoAnomalies.
  ///
  /// In en, this message translates to:
  /// **'All station systems operational'**
  String get systemHealthNoAnomalies;

  /// No description provided for @systemHealthStaleSessions.
  ///
  /// In en, this message translates to:
  /// **'{count} Stale Open Attendance Sessions'**
  String systemHealthStaleSessions(int count);

  /// No description provided for @systemHealthFailedIdentity.
  ///
  /// In en, this message translates to:
  /// **'{count} Identity Verification Failures'**
  String systemHealthFailedIdentity(int count);

  /// No description provided for @dataRetentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Lifecycle & Retention'**
  String get dataRetentionTitle;

  /// No description provided for @dataRetentionSummary.
  ///
  /// In en, this message translates to:
  /// **'Historical attendance records, shifts, and audit logs are permanently retained. Ephemeral QR challenge tokens and expired file artifacts are automatically scrubbed.'**
  String get dataRetentionSummary;

  /// No description provided for @dataRetentionRunButton.
  ///
  /// In en, this message translates to:
  /// **'Run Lifecycle Cleanup'**
  String get dataRetentionRunButton;

  /// No description provided for @dataRetentionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cleanup completed: {exports} expired exports marked, {challenges} QR tokens cleared.'**
  String dataRetentionSuccess(int exports, int challenges);

  /// No description provided for @stationTimezoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Station Timezone (IANA)'**
  String get stationTimezoneLabel;

  /// No description provided for @stationTimezoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Timezone used for shift boundaries and timestamp formatting'**
  String get stationTimezoneHelper;

  /// No description provided for @stationLateGraceMinutes.
  ///
  /// In en, this message translates to:
  /// **'Late Grace Period (Minutes)'**
  String get stationLateGraceMinutes;

  /// No description provided for @stationLateGraceHelper.
  ///
  /// In en, this message translates to:
  /// **'Arrivals within this grace period are recorded as on-time'**
  String get stationLateGraceHelper;

  /// No description provided for @stationCheckInEarlyMinutes.
  ///
  /// In en, this message translates to:
  /// **'Early Check-in Window (Minutes)'**
  String get stationCheckInEarlyMinutes;

  /// No description provided for @stationCheckInEarlyHelper.
  ///
  /// In en, this message translates to:
  /// **'Allow employees to clock-in before scheduled shift starts'**
  String get stationCheckInEarlyHelper;

  /// No description provided for @stationDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Sensitive Station Controls'**
  String get stationDangerZone;

  /// No description provided for @stationDeactivateAction.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Station'**
  String get stationDeactivateAction;

  /// No description provided for @stationDeactivateNotice.
  ///
  /// In en, this message translates to:
  /// **'Deactivating the station will prevent all employee clock-ins and scheduling activities.'**
  String get stationDeactivateNotice;

  /// No description provided for @stationDeactivateBlockedActive.
  ///
  /// In en, this message translates to:
  /// **'Cannot deactivate station while active attendance sessions or open shifts exist.'**
  String get stationDeactivateBlockedActive;

  /// No description provided for @stationForceDeactivateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Force Station Deactivation'**
  String get stationForceDeactivateConfirm;

  /// No description provided for @connectionOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get connectionOnline;

  /// No description provided for @connectionDegraded.
  ///
  /// In en, this message translates to:
  /// **'Degraded Connection'**
  String get connectionDegraded;

  /// No description provided for @connectionReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get connectionReconnecting;

  /// No description provided for @connectionOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline — Read Only'**
  String get connectionOffline;

  /// No description provided for @errorOfflineActionBlocked.
  ///
  /// In en, this message translates to:
  /// **'Active internet connection is required to complete this action.'**
  String get errorOfflineActionBlocked;

  /// No description provided for @errorReconcilingAttendance.
  ///
  /// In en, this message translates to:
  /// **'Verifying attendance status after network timeout...'**
  String get errorReconcilingAttendance;

  /// No description provided for @appUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'A new version of YellowShifts is available.'**
  String get appUpdateAvailable;

  /// No description provided for @appUpdateReloadNow.
  ///
  /// In en, this message translates to:
  /// **'Reload Now'**
  String get appUpdateReloadNow;

  /// No description provided for @appUpdateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get appUpdateLater;

  /// No description provided for @startupConfigError.
  ///
  /// In en, this message translates to:
  /// **'Configuration Error'**
  String get startupConfigError;

  /// No description provided for @startupConfigErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Application failed to initialize due to invalid configuration.'**
  String get startupConfigErrorMessage;

  /// No description provided for @startupLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading YellowShifts...'**
  String get startupLoading;

  /// No description provided for @startupRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry Initialization'**
  String get startupRetry;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please slow down and try again shortly.'**
  String get errorRateLimited;

  /// No description provided for @errorScheduleConflict.
  ///
  /// In en, this message translates to:
  /// **'Schedule assignment conflict detected.'**
  String get errorScheduleConflict;

  /// No description provided for @errorVersionConflict.
  ///
  /// In en, this message translates to:
  /// **'Schedule was updated by another manager. Please refresh.'**
  String get errorVersionConflict;

  /// No description provided for @errorStationDeactivated.
  ///
  /// In en, this message translates to:
  /// **'This station is currently inactive.'**
  String get errorStationDeactivated;

  /// No description provided for @errorMembershipDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Your station membership is inactive or suspended.'**
  String get errorMembershipDeactivated;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please check your connection.'**
  String get errorTimeout;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server is temporarily unavailable. Please try again soon.'**
  String get errorServiceUnavailable;

  /// No description provided for @systemHealthHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get systemHealthHealthy;

  /// No description provided for @systemHealthDegraded.
  ///
  /// In en, this message translates to:
  /// **'Degraded'**
  String get systemHealthDegraded;

  /// No description provided for @systemHealthUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get systemHealthUnavailable;

  /// No description provided for @systemHealthUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get systemHealthUnknown;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings & Preferences'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage user identity, language, and station operational settings'**
  String get settingsSubtitle;

  /// No description provided for @settingsUserProfile.
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get settingsUserProfile;

  /// No description provided for @settingsUserPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String settingsUserPhone(String phone);

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure in-app, push, email, and SMS alert delivery channels'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsStationAdmin.
  ///
  /// In en, this message translates to:
  /// **'Station Administration'**
  String get settingsStationAdmin;

  /// No description provided for @settingsOperationalParams.
  ///
  /// In en, this message translates to:
  /// **'Operational Parameters'**
  String get settingsOperationalParams;

  /// No description provided for @settingsOperationalParamsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Timezone, code, locale, and week start'**
  String get settingsOperationalParamsSubtitle;

  /// No description provided for @settingsShiftTemplates.
  ///
  /// In en, this message translates to:
  /// **'Shift Templates'**
  String get settingsShiftTemplates;

  /// No description provided for @settingsShiftTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure working shifts, hours, and sort order'**
  String get settingsShiftTemplatesSubtitle;

  /// No description provided for @settingsShiftManagerCaps.
  ///
  /// In en, this message translates to:
  /// **'Shift Manager Capabilities'**
  String get settingsShiftManagerCaps;

  /// No description provided for @settingsShiftManagerCapsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Station-specific permission overrides for Shift Managers'**
  String get settingsShiftManagerCapsSubtitle;

  /// No description provided for @settingsExportCenter.
  ///
  /// In en, this message translates to:
  /// **'Operational Export Center'**
  String get settingsExportCenter;

  /// No description provided for @settingsExportCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate certified CSV and PDF operational report artifacts'**
  String get settingsExportCenterSubtitle;

  /// No description provided for @settingsAuditCenter.
  ///
  /// In en, this message translates to:
  /// **'Audit Center'**
  String get settingsAuditCenter;

  /// No description provided for @settingsAuditCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect immutable chronological administrative activity ledger'**
  String get settingsAuditCenterSubtitle;

  /// No description provided for @settingsSystemHealth.
  ///
  /// In en, this message translates to:
  /// **'Operational Health & Lifecycle'**
  String get settingsSystemHealth;

  /// No description provided for @settingsSystemHealthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live telemetry, station NFC tag fleet health, and data retention maintenance'**
  String get settingsSystemHealthSubtitle;

  /// No description provided for @settingsCurrentStationDetails.
  ///
  /// In en, this message translates to:
  /// **'Current Station Details'**
  String get settingsCurrentStationDetails;

  /// No description provided for @settingsStationName.
  ///
  /// In en, this message translates to:
  /// **'Station Name'**
  String get settingsStationName;

  /// No description provided for @settingsStationCode.
  ///
  /// In en, this message translates to:
  /// **'Operational Code'**
  String get settingsStationCode;

  /// No description provided for @settingsStationTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get settingsStationTimezone;

  /// No description provided for @settingsStationLocale.
  ///
  /// In en, this message translates to:
  /// **'Station Locale'**
  String get settingsStationLocale;

  /// No description provided for @settingsLanguageDirection.
  ///
  /// In en, this message translates to:
  /// **'Language & Directionality'**
  String get settingsLanguageDirection;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out from YellowShifts'**
  String get settingsSignOut;

  /// No description provided for @systemHealthDefenseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completed with server-side formula defense'**
  String get systemHealthDefenseSubtitle;

  /// No description provided for @systemHealthStaleSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions open for > 16 hours requiring manager review'**
  String get systemHealthStaleSessionsSubtitle;

  /// No description provided for @exportPreset7Days.
  ///
  /// In en, this message translates to:
  /// **'7 Days'**
  String get exportPreset7Days;

  /// No description provided for @exportPreset30Days.
  ///
  /// In en, this message translates to:
  /// **'30 Days'**
  String get exportPreset30Days;

  /// No description provided for @exportPresetThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get exportPresetThisMonth;

  /// No description provided for @exportPresetLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get exportPresetLastMonth;

  /// No description provided for @exportPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get exportPresetCustom;

  /// No description provided for @exportFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get exportFormatLabel;

  /// No description provided for @availabilityDeadlineInfo.
  ///
  /// In en, this message translates to:
  /// **'Deadline: {deadline} • {count} shifts / day'**
  String availabilityDeadlineInfo(String deadline, int count);

  /// No description provided for @availabilitySlotsAnswered.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} slots answered'**
  String availabilitySlotsAnswered(int answered, int total);

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get statusOpen;

  /// No description provided for @statusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get statusClosed;

  /// No description provided for @statusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// No description provided for @statusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get statusSubmitted;

  /// No description provided for @statusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get statusNotStarted;

  /// No description provided for @noEmployeeRecordsFound.
  ///
  /// In en, this message translates to:
  /// **'No employee records found.'**
  String get noEmployeeRecordsFound;

  /// No description provided for @stationSectionIdentity.
  ///
  /// In en, this message translates to:
  /// **'Operational Identity'**
  String get stationSectionIdentity;

  /// No description provided for @stationSectionRegional.
  ///
  /// In en, this message translates to:
  /// **'Regional & Calendar Defaults'**
  String get stationSectionRegional;

  /// No description provided for @stationSectionGrace.
  ///
  /// In en, this message translates to:
  /// **'Shift & Grace Policies'**
  String get stationSectionGrace;

  /// No description provided for @stationActiveStatus.
  ///
  /// In en, this message translates to:
  /// **'Station Active'**
  String get stationActiveStatus;

  /// No description provided for @stationDeactivatedStatus.
  ///
  /// In en, this message translates to:
  /// **'Station Deactivated'**
  String get stationDeactivatedStatus;

  /// No description provided for @stationActiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Kiosks and employee clock-ins are currently accepting operations.'**
  String get stationActiveDesc;

  /// No description provided for @stationDeactivatedDesc.
  ///
  /// In en, this message translates to:
  /// **'Station is paused and blocked from active operations.'**
  String get stationDeactivatedDesc;

  /// No description provided for @policyOptionDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Disabled (QR Only)'**
  String get policyOptionDisabledTitle;

  /// No description provided for @policyOptionDisabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance uses Phase 4 rotating QR challenges only.'**
  String get policyOptionDisabledSubtitle;

  /// No description provided for @policyOptionCheckInOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Check-In Only (Recommended)'**
  String get policyOptionCheckInOnlyTitle;

  /// No description provided for @policyOptionCheckInOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requires biometric verification on check-in. Check-out is QR only.'**
  String get policyOptionCheckInOnlySubtitle;

  /// No description provided for @policyOptionStrictTitle.
  ///
  /// In en, this message translates to:
  /// **'Strict: Check-In & Check-Out'**
  String get policyOptionStrictTitle;

  /// No description provided for @policyOptionStrictSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requires biometric verification for both check-in and check-out.'**
  String get policyOptionStrictSubtitle;

  /// No description provided for @policyApplyAction.
  ///
  /// In en, this message translates to:
  /// **'Apply Policy Change'**
  String get policyApplyAction;

  /// No description provided for @policyTeamReadinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Team Biometric Readiness'**
  String get policyTeamReadinessTitle;

  /// No description provided for @policyNoMembersRegistered.
  ///
  /// In en, this message translates to:
  /// **'No active team members registered.'**
  String get policyNoMembersRegistered;

  /// No description provided for @kpiWorkingNow.
  ///
  /// In en, this message translates to:
  /// **'Working Now'**
  String get kpiWorkingNow;

  /// No description provided for @kpiUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get kpiUpcoming;

  /// No description provided for @kpiLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get kpiLate;

  /// No description provided for @kpiCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get kpiCompleted;

  /// No description provided for @kpiNotCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Not Checked In'**
  String get kpiNotCheckedIn;

  /// No description provided for @attendanceRosterTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Shift Roster'**
  String get attendanceRosterTitle;

  /// No description provided for @rosterScheduledCount.
  ///
  /// In en, this message translates to:
  /// **'{count} scheduled'**
  String rosterScheduledCount(int count);

  /// No description provided for @noEmployeesScheduledToday.
  ///
  /// In en, this message translates to:
  /// **'No employees scheduled for today.'**
  String get noEmployeesScheduledToday;

  /// No description provided for @attendanceStatusWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get attendanceStatusWorking;

  /// No description provided for @attendanceStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get attendanceStatusUpcoming;

  /// No description provided for @attendanceStatusLate.
  ///
  /// In en, this message translates to:
  /// **'Late {minutes}m'**
  String attendanceStatusLate(int minutes);

  /// No description provided for @attendanceStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get attendanceStatusCompleted;

  /// No description provided for @attendanceStatusNotCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Not Checked In'**
  String get attendanceStatusNotCheckedIn;

  /// No description provided for @attendanceScanPrompt.
  ///
  /// In en, this message translates to:
  /// **'Hold your phone near the station NFC tag to record attendance'**
  String get attendanceScanPrompt;

  /// No description provided for @attendanceActiveShift.
  ///
  /// In en, this message translates to:
  /// **'Active Shift'**
  String get attendanceActiveShift;

  /// No description provided for @attendanceLateDuration.
  ///
  /// In en, this message translates to:
  /// **'Late {minutes} min'**
  String attendanceLateDuration(int minutes);

  /// No description provided for @attendanceConfirmCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Confirm Check-In'**
  String get attendanceConfirmCheckIn;

  /// No description provided for @attendanceConfirmCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Confirm Check-Out'**
  String get attendanceConfirmCheckOut;

  /// No description provided for @shiftLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get shiftLabel;

  /// No description provided for @scheduledShift.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Shift'**
  String get scheduledShift;

  /// No description provided for @scheduledWindow.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Window'**
  String get scheduledWindow;

  /// No description provided for @workedTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Worked Time'**
  String get workedTimeLabel;

  /// No description provided for @checkInNowAction.
  ///
  /// In en, this message translates to:
  /// **'Check In Now'**
  String get checkInNowAction;

  /// No description provided for @checkOutNowAction.
  ///
  /// In en, this message translates to:
  /// **'Check Out Now'**
  String get checkOutNowAction;

  /// No description provided for @correctionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Correct Attendance'**
  String get correctionDialogTitle;

  /// No description provided for @correctionReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason for correction (required)'**
  String get correctionReasonLabel;

  /// No description provided for @correctionReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Employee forgot to clock out on station tablet'**
  String get correctionReasonHint;

  /// No description provided for @correctionSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save Correction'**
  String get correctionSaveAction;

  /// No description provided for @checkInLabel.
  ///
  /// In en, this message translates to:
  /// **'Check In'**
  String get checkInLabel;

  /// No description provided for @checkOutLabel.
  ///
  /// In en, this message translates to:
  /// **'Check Out'**
  String get checkOutLabel;

  /// No description provided for @attendanceNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No attendance history recorded yet.'**
  String get attendanceNoHistory;

  /// No description provided for @attendanceWorkShift.
  ///
  /// In en, this message translates to:
  /// **'Work Shift'**
  String get attendanceWorkShift;

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get timeNow;

  /// No description provided for @identityVerifyingFace.
  ///
  /// In en, this message translates to:
  /// **'Verifying face liveness...'**
  String get identityVerifyingFace;

  /// No description provided for @kpiActiveEmployees.
  ///
  /// In en, this message translates to:
  /// **'{count} active employees'**
  String kpiActiveEmployees(int count);

  /// No description provided for @kpiActiveOpen.
  ///
  /// In en, this message translates to:
  /// **'{count} active open'**
  String kpiActiveOpen(int count);

  /// No description provided for @kpiLateShiftsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} late shifts ({minutes}m)'**
  String kpiLateShiftsCount(int count, int minutes);

  /// No description provided for @kpiEmployeesLateThreshold.
  ///
  /// In en, this message translates to:
  /// **'employees with >= 3 late shifts'**
  String get kpiEmployeesLateThreshold;

  /// No description provided for @kpiAttentionBadge.
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get kpiAttentionBadge;

  /// No description provided for @kpiManualAdjustmentsAudited.
  ///
  /// In en, this message translates to:
  /// **'manual adjustments audited'**
  String get kpiManualAdjustmentsAudited;

  /// No description provided for @workforceRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Workforce Records ({count})'**
  String workforceRecordsTitle(int count);

  /// No description provided for @tableColEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get tableColEmployee;

  /// No description provided for @tableColCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get tableColCode;

  /// No description provided for @tableColWorkedTime.
  ///
  /// In en, this message translates to:
  /// **'Worked Time'**
  String get tableColWorkedTime;

  /// No description provided for @tableColCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tableColCompleted;

  /// No description provided for @tableColLateShifts.
  ///
  /// In en, this message translates to:
  /// **'Late Shifts'**
  String get tableColLateShifts;

  /// No description provided for @tableColCorrections.
  ///
  /// In en, this message translates to:
  /// **'Corrections'**
  String get tableColCorrections;

  /// No description provided for @tableColStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get tableColStatus;

  /// No description provided for @repeatedLatenessTag.
  ///
  /// In en, this message translates to:
  /// **'Repeated Lateness (>=3)'**
  String get repeatedLatenessTag;

  /// No description provided for @tableMetricWorked.
  ///
  /// In en, this message translates to:
  /// **'Worked'**
  String get tableMetricWorked;

  /// No description provided for @tableMetricShifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get tableMetricShifts;

  /// No description provided for @tableMetricLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get tableMetricLate;

  /// No description provided for @tableMetricCorrected.
  ///
  /// In en, this message translates to:
  /// **'Corrected'**
  String get tableMetricCorrected;

  /// No description provided for @dailyNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No scheduled shifts or walk-in records on this date.'**
  String get dailyNoRecords;

  /// No description provided for @dailyScheduledShiftsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Operational Shifts ({count})'**
  String dailyScheduledShiftsTitle(int count);

  /// No description provided for @dailyWalkInTitle.
  ///
  /// In en, this message translates to:
  /// **'Unscheduled Walk-In Attendance ({count})'**
  String dailyWalkInTitle(int count);

  /// No description provided for @dailyRequiredStaff.
  ///
  /// In en, this message translates to:
  /// **'Required: {count}'**
  String dailyRequiredStaff(int count);

  /// No description provided for @dailyAssignedStaff.
  ///
  /// In en, this message translates to:
  /// **'Assigned: {count}'**
  String dailyAssignedStaff(int count);

  /// No description provided for @dailyCheckedInStaff.
  ///
  /// In en, this message translates to:
  /// **'Checked In: {count}'**
  String dailyCheckedInStaff(int count);

  /// No description provided for @dailyLateStaff.
  ///
  /// In en, this message translates to:
  /// **'Late: {count}'**
  String dailyLateStaff(int count);

  /// No description provided for @dailyActiveOpenStaff.
  ///
  /// In en, this message translates to:
  /// **'Active Open: {count}'**
  String dailyActiveOpenStaff(int count);

  /// No description provided for @dailyNoShiftRecords.
  ///
  /// In en, this message translates to:
  /// **'No attendance records checked in for this scheduled shift.'**
  String get dailyNoShiftRecords;

  /// No description provided for @checkedInLabel.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get checkedInLabel;

  /// No description provided for @lateMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'Late {minutes}m'**
  String lateMinutesLabel(int minutes);

  /// No description provided for @shiftHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift History ({count})'**
  String shiftHistoryTitle(int count);

  /// No description provided for @allStationsFilter.
  ///
  /// In en, this message translates to:
  /// **'All Stations'**
  String get allStationsFilter;

  /// No description provided for @stationsWorkedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} stations'**
  String stationsWorkedCount(int count);

  /// No description provided for @lateTimeDuration.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m late time'**
  String lateTimeDuration(int minutes);

  /// No description provided for @repeatedBadge.
  ///
  /// In en, this message translates to:
  /// **'Repeated'**
  String get repeatedBadge;

  /// No description provided for @operationalWeekRange.
  ///
  /// In en, this message translates to:
  /// **'Operational Week Range'**
  String get operationalWeekRange;

  /// No description provided for @submissionDeadline.
  ///
  /// In en, this message translates to:
  /// **'Submission Deadline'**
  String get submissionDeadline;

  /// No description provided for @operationalNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Operational Notes (Optional)'**
  String get operationalNotesOptional;

  /// No description provided for @operationalNotesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Holiday coverage required, minimum 4 shifts...'**
  String get operationalNotesHint;

  /// No description provided for @createPeriodAction.
  ///
  /// In en, this message translates to:
  /// **'Create Period'**
  String get createPeriodAction;

  /// No description provided for @submissionDeadlineFutureError.
  ///
  /// In en, this message translates to:
  /// **'Submission deadline must be in the future.'**
  String get submissionDeadlineFutureError;

  /// No description provided for @reportsAccessRestrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'Access Restricted'**
  String get reportsAccessRestrictedTitle;

  /// No description provided for @reportsAccessRestrictedDesc.
  ///
  /// In en, this message translates to:
  /// **'You must be an active station manager or administrator to view operational reporting.'**
  String get reportsAccessRestrictedDesc;

  /// No description provided for @walkInShift.
  ///
  /// In en, this message translates to:
  /// **'Walk-In Shift'**
  String get walkInShift;

  /// No description provided for @activeShiftInProgress.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE SHIFT IN PROGRESS'**
  String get activeShiftInProgress;

  /// No description provided for @shiftExceedsWarning.
  ///
  /// In en, this message translates to:
  /// **'Shift exceeds 16 hours. Review checkout status.'**
  String get shiftExceedsWarning;

  /// No description provided for @repeatedLatenessPattern.
  ///
  /// In en, this message translates to:
  /// **'Repeated Lateness Pattern: 3 or more late shifts in this reporting period.'**
  String get repeatedLatenessPattern;

  /// No description provided for @attendanceCorrectionHistory.
  ///
  /// In en, this message translates to:
  /// **'Attendance & Correction History'**
  String get attendanceCorrectionHistory;

  /// No description provided for @noRecordsInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No attendance records in period.'**
  String get noRecordsInPeriod;

  /// No description provided for @correctionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 correction} other{{count} corrections}}'**
  String correctionsCount(int count);

  /// No description provided for @correctionByActor.
  ///
  /// In en, this message translates to:
  /// **'By: {name}'**
  String correctionByActor(String name);

  /// No description provided for @correctionDurationChange.
  ///
  /// In en, this message translates to:
  /// **'Duration: {oldDuration} -> {newDuration}'**
  String correctionDurationChange(String oldDuration, String newDuration);

  /// No description provided for @correctionReasonPrefix.
  ///
  /// In en, this message translates to:
  /// **'Reason: \"{reason}\"'**
  String correctionReasonPrefix(String reason);

  /// No description provided for @stationLabel.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get stationLabel;

  /// No description provided for @kpiWorkedHours.
  ///
  /// In en, this message translates to:
  /// **'Worked Hours'**
  String get kpiWorkedHours;

  /// No description provided for @kpiLateArrivals.
  ///
  /// In en, this message translates to:
  /// **'Late Arrivals'**
  String get kpiLateArrivals;

  /// No description provided for @statusCorrected.
  ///
  /// In en, this message translates to:
  /// **'Corrected'**
  String get statusCorrected;

  /// No description provided for @rolePlatformAdmin.
  ///
  /// In en, this message translates to:
  /// **'Platform Admin'**
  String get rolePlatformAdmin;

  /// No description provided for @roleStationManager.
  ///
  /// In en, this message translates to:
  /// **'Station Manager'**
  String get roleStationManager;

  /// No description provided for @platformAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Administration'**
  String get platformAdminTitle;

  /// No description provided for @platformAdminMode.
  ///
  /// In en, this message translates to:
  /// **'Platform Mode'**
  String get platformAdminMode;

  /// No description provided for @platformOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Overview'**
  String get platformOverviewTitle;

  /// No description provided for @platformOverviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Network-wide operational summary for YellowShifts operators.'**
  String get platformOverviewSubtitle;

  /// No description provided for @platformNavOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get platformNavOverview;

  /// No description provided for @platformNavStations.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get platformNavStations;

  /// No description provided for @platformNavAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit / Operations'**
  String get platformNavAudit;

  /// No description provided for @platformNavHealth.
  ///
  /// In en, this message translates to:
  /// **'System Health'**
  String get platformNavHealth;

  /// No description provided for @platformStationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get platformStationsTitle;

  /// No description provided for @platformStationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Provision, inspect, and operate every station in the YellowShifts network.'**
  String get platformStationsSubtitle;

  /// No description provided for @platformCreateStation.
  ///
  /// In en, this message translates to:
  /// **'Create Station'**
  String get platformCreateStation;

  /// No description provided for @platformCreateStationTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Station'**
  String get platformCreateStationTitle;

  /// No description provided for @platformCreateStationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Provision a station and assign the initial Station Manager.'**
  String get platformCreateStationSubtitle;

  /// No description provided for @platformStationName.
  ///
  /// In en, this message translates to:
  /// **'Station Name'**
  String get platformStationName;

  /// No description provided for @platformStationCode.
  ///
  /// In en, this message translates to:
  /// **'Station Code'**
  String get platformStationCode;

  /// No description provided for @platformStationTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get platformStationTimezone;

  /// No description provided for @platformStationLocale.
  ///
  /// In en, this message translates to:
  /// **'Locale'**
  String get platformStationLocale;

  /// No description provided for @platformStationStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get platformStationStatus;

  /// No description provided for @platformWeekStart.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get platformWeekStart;

  /// No description provided for @platformWeekStartSunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get platformWeekStartSunday;

  /// No description provided for @platformWeekStartMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get platformWeekStartMonday;

  /// No description provided for @platformInitialManager.
  ///
  /// In en, this message translates to:
  /// **'Initial Station Manager'**
  String get platformInitialManager;

  /// No description provided for @platformManagerEmail.
  ///
  /// In en, this message translates to:
  /// **'Manager email'**
  String get platformManagerEmail;

  /// No description provided for @platformManagerFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get platformManagerFirstName;

  /// No description provided for @platformManagerLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get platformManagerLastName;

  /// No description provided for @platformManagerPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get platformManagerPhone;

  /// No description provided for @platformAssignManager.
  ///
  /// In en, this message translates to:
  /// **'Assign Manager'**
  String get platformAssignManager;

  /// No description provided for @platformAddManager.
  ///
  /// In en, this message translates to:
  /// **'Add Station Manager'**
  String get platformAddManager;

  /// No description provided for @platformReplaceManager.
  ///
  /// In en, this message translates to:
  /// **'Replace Station Manager'**
  String get platformReplaceManager;

  /// No description provided for @platformRemoveManager.
  ///
  /// In en, this message translates to:
  /// **'Remove Manager role'**
  String get platformRemoveManager;

  /// No description provided for @platformDeactivateManager.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Station Manager'**
  String get platformDeactivateManager;

  /// No description provided for @platformReactivateManager.
  ///
  /// In en, this message translates to:
  /// **'Reactivate Station Manager'**
  String get platformReactivateManager;

  /// No description provided for @platformStationManagers.
  ///
  /// In en, this message translates to:
  /// **'Station Managers'**
  String get platformStationManagers;

  /// No description provided for @platformStationManagersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only Platform Admins can grant or revoke Station Manager access.'**
  String get platformStationManagersSubtitle;

  /// No description provided for @platformDeactivateStation.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Station'**
  String get platformDeactivateStation;

  /// No description provided for @platformReactivateStation.
  ///
  /// In en, this message translates to:
  /// **'Reactivate Station'**
  String get platformReactivateStation;

  /// No description provided for @platformOpenStation.
  ///
  /// In en, this message translates to:
  /// **'Open Station'**
  String get platformOpenStation;

  /// No description provided for @platformOperatingStation.
  ///
  /// In en, this message translates to:
  /// **'Operating Station'**
  String get platformOperatingStation;

  /// No description provided for @platformOperatingBanner.
  ///
  /// In en, this message translates to:
  /// **'Platform Admin · Operating: {stationName}'**
  String platformOperatingBanner(String stationName);

  /// No description provided for @platformReturnToPlatform.
  ///
  /// In en, this message translates to:
  /// **'Return to Platform Administration'**
  String get platformReturnToPlatform;

  /// No description provided for @platformWorkspaceSwitch.
  ///
  /// In en, this message translates to:
  /// **'Station Workspace'**
  String get platformWorkspaceSwitch;

  /// No description provided for @platformLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get platformLogoutConfirm;

  /// No description provided for @platformSuperAdminRole.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get platformSuperAdminRole;

  /// No description provided for @platformConfirmDeactivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate this station?'**
  String get platformConfirmDeactivateTitle;

  /// No description provided for @platformConfirmDeactivateBody.
  ///
  /// In en, this message translates to:
  /// **'Ordinary station access will fail closed. Historical attendance, schedules, and audit records are preserved.'**
  String get platformConfirmDeactivateBody;

  /// No description provided for @platformConfirmRemoveManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Station Manager access?'**
  String get platformConfirmRemoveManagerTitle;

  /// No description provided for @platformConfirmRemoveManagerBody.
  ///
  /// In en, this message translates to:
  /// **'This person will no longer be a Station Manager. The station must retain at least one active Station Manager.'**
  String get platformConfirmRemoveManagerBody;

  /// No description provided for @platformReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get platformReasonLabel;

  /// No description provided for @platformReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Describe why this change is required'**
  String get platformReasonHint;

  /// No description provided for @platformForceDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Force deactivate despite active operations'**
  String get platformForceDeactivate;

  /// No description provided for @platformMetricTotalStations.
  ///
  /// In en, this message translates to:
  /// **'Total stations'**
  String get platformMetricTotalStations;

  /// No description provided for @platformMetricActiveStations.
  ///
  /// In en, this message translates to:
  /// **'Active stations'**
  String get platformMetricActiveStations;

  /// No description provided for @platformMetricInactiveStations.
  ///
  /// In en, this message translates to:
  /// **'Inactive stations'**
  String get platformMetricInactiveStations;

  /// No description provided for @platformMetricActiveMemberships.
  ///
  /// In en, this message translates to:
  /// **'Active memberships'**
  String get platformMetricActiveMemberships;

  /// No description provided for @platformMetricStationAdmins.
  ///
  /// In en, this message translates to:
  /// **'Station Managers'**
  String get platformMetricStationAdmins;

  /// No description provided for @platformMetricShiftManagers.
  ///
  /// In en, this message translates to:
  /// **'Shift Managers'**
  String get platformMetricShiftManagers;

  /// No description provided for @platformMetricAlerts.
  ///
  /// In en, this message translates to:
  /// **'Operational alerts'**
  String get platformMetricAlerts;

  /// No description provided for @platformColEmployees.
  ///
  /// In en, this message translates to:
  /// **'Active employees'**
  String get platformColEmployees;

  /// No description provided for @platformColManagers.
  ///
  /// In en, this message translates to:
  /// **'Station Managers'**
  String get platformColManagers;

  /// No description provided for @platformColShiftManagers.
  ///
  /// In en, this message translates to:
  /// **'Shift Managers'**
  String get platformColShiftManagers;

  /// No description provided for @platformHealthSummary.
  ///
  /// In en, this message translates to:
  /// **'Operational health'**
  String get platformHealthSummary;

  /// No description provided for @platformAuditTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Audit'**
  String get platformAuditTitle;

  /// No description provided for @platformAuditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect platform and station operations. Station Admins remain tenant-scoped.'**
  String get platformAuditSubtitle;

  /// No description provided for @platformAuditFilterAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get platformAuditFilterAction;

  /// No description provided for @platformHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Health'**
  String get platformHealthTitle;

  /// No description provided for @platformHealthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Aggregated NFC tags, export, attendance, and notification signals across the network.'**
  String get platformHealthSubtitle;

  /// No description provided for @platformUnauthorizedTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Administration unavailable'**
  String get platformUnauthorizedTitle;

  /// No description provided for @platformUnauthorizedBody.
  ///
  /// In en, this message translates to:
  /// **'This area is restricted to active Platform Admins.'**
  String get platformUnauthorizedBody;

  /// No description provided for @platformEmptyStations.
  ///
  /// In en, this message translates to:
  /// **'No stations have been provisioned yet.'**
  String get platformEmptyStations;

  /// No description provided for @platformCreatedToast.
  ///
  /// In en, this message translates to:
  /// **'Station created successfully'**
  String get platformCreatedToast;

  /// No description provided for @platformUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Station updated'**
  String get platformUpdatedToast;

  /// No description provided for @platformDeactivatedToast.
  ///
  /// In en, this message translates to:
  /// **'Station deactivated'**
  String get platformDeactivatedToast;

  /// No description provided for @platformReactivatedToast.
  ///
  /// In en, this message translates to:
  /// **'Station reactivated'**
  String get platformReactivatedToast;

  /// No description provided for @platformManagerAssignedToast.
  ///
  /// In en, this message translates to:
  /// **'Station Manager assigned'**
  String get platformManagerAssignedToast;

  /// No description provided for @platformColNfcTags.
  ///
  /// In en, this message translates to:
  /// **'NFC Tags'**
  String get platformColNfcTags;

  /// No description provided for @platformMetricNfcActive.
  ///
  /// In en, this message translates to:
  /// **'Active NFC tags'**
  String get platformMetricNfcActive;

  /// No description provided for @platformMetricNfcTotal.
  ///
  /// In en, this message translates to:
  /// **'Total NFC tags'**
  String get platformMetricNfcTotal;

  /// No description provided for @attendanceScanNfcAction.
  ///
  /// In en, this message translates to:
  /// **'Scan Station NFC Tag'**
  String get attendanceScanNfcAction;

  /// No description provided for @settingsNfcTags.
  ///
  /// In en, this message translates to:
  /// **'Station NFC Tags'**
  String get settingsNfcTags;

  /// No description provided for @settingsNfcTagsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Provision, program, and manage physical station NFC tags'**
  String get settingsNfcTagsSubtitle;

  /// No description provided for @nfcTagsManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Station NFC Tags'**
  String get nfcTagsManagementTitle;

  /// No description provided for @nfcProvisionNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Provision New NFC Tag'**
  String get nfcProvisionNewTitle;

  /// No description provided for @nfcProvisionDialogDesc.
  ///
  /// In en, this message translates to:
  /// **'Register an NFC tag identifier on the server and prepare it for writing.'**
  String get nfcProvisionDialogDesc;

  /// No description provided for @nfcTagNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag Name'**
  String get nfcTagNameLabel;

  /// No description provided for @nfcTagNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Front Entrance Tag, Kitchen Tag'**
  String get nfcTagNameHint;

  /// No description provided for @nfcTagIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag ID'**
  String get nfcTagIdLabel;

  /// No description provided for @nfcStationCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Station Code'**
  String get nfcStationCodeLabel;

  /// No description provided for @nfcReadyToWriteDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap below to physically write this station configuration onto a blank NFC tag.'**
  String get nfcReadyToWriteDesc;

  /// No description provided for @nfcCreateTagAction.
  ///
  /// In en, this message translates to:
  /// **'Register Tag'**
  String get nfcCreateTagAction;

  /// No description provided for @nfcWriteToCardAction.
  ///
  /// In en, this message translates to:
  /// **'Write to NFC Tag'**
  String get nfcWriteToCardAction;

  /// No description provided for @nfcHoldToWritePrompt.
  ///
  /// In en, this message translates to:
  /// **'Hold phone near blank NFC tag to write station data.'**
  String get nfcHoldToWritePrompt;

  /// No description provided for @nfcTagWrittenSuccess.
  ///
  /// In en, this message translates to:
  /// **'NFC Tag programmed successfully!'**
  String get nfcTagWrittenSuccess;

  /// No description provided for @nfcWriteTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Write to Physical Tag'**
  String get nfcWriteTagTitle;

  /// No description provided for @nfcTagCreatedServerDesc.
  ///
  /// In en, this message translates to:
  /// **'Tag registered on server. Hold your device to write to the physical tag.'**
  String get nfcTagCreatedServerDesc;

  /// No description provided for @nfcNoTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Station NFC Tags'**
  String get nfcNoTagsTitle;

  /// No description provided for @nfcNoTagsDesc.
  ///
  /// In en, this message translates to:
  /// **'Provision a physical NFC tag at this station to enable employee attendance check-in.'**
  String get nfcNoTagsDesc;

  /// No description provided for @nfcTagStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get nfcTagStatusActive;

  /// No description provided for @nfcTagStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get nfcTagStatusRevoked;

  /// No description provided for @nfcLastScanned.
  ///
  /// In en, this message translates to:
  /// **'Last scan: {time}'**
  String nfcLastScanned(String time);

  /// No description provided for @nfcNeverScanned.
  ///
  /// In en, this message translates to:
  /// **'Never scanned'**
  String get nfcNeverScanned;

  /// No description provided for @nfcReplaceAction.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get nfcReplaceAction;

  /// No description provided for @nfcRevokeAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get nfcRevokeAction;

  /// No description provided for @nfcReactivateAction.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get nfcReactivateAction;

  /// No description provided for @nfcReplaceTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace Station NFC Tag'**
  String get nfcReplaceTagTitle;

  /// No description provided for @nfcReplaceTagWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently revoke the current physical tag and generate credentials for a new replacement tag.'**
  String get nfcReplaceTagWarning;

  /// No description provided for @nfcNewTagNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Replacement Tag Name'**
  String get nfcNewTagNameLabel;

  /// No description provided for @nfcReplaceTagConfirm.
  ///
  /// In en, this message translates to:
  /// **'Replace Tag'**
  String get nfcReplaceTagConfirm;

  /// No description provided for @nfcTagReplacedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Tag replaced successfully'**
  String get nfcTagReplacedSuccess;

  /// No description provided for @nfcTagRevokedToast.
  ///
  /// In en, this message translates to:
  /// **'NFC Tag revoked'**
  String get nfcTagRevokedToast;

  /// No description provided for @nfcTagReactivatedToast.
  ///
  /// In en, this message translates to:
  /// **'NFC Tag reactivated'**
  String get nfcTagReactivatedToast;

  /// No description provided for @nfcUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'NFC is unavailable or disabled on this device.'**
  String get nfcUnavailableError;

  /// No description provided for @nfcScanCheckInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Hold phone near station NFC tag to clock in.'**
  String get nfcScanCheckInPrompt;

  /// No description provided for @nfcScanCheckOutPrompt.
  ///
  /// In en, this message translates to:
  /// **'Hold phone near station NFC tag to clock out.'**
  String get nfcScanCheckOutPrompt;

  /// No description provided for @nfcCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Station NFC Tag'**
  String get nfcCheckInTitle;

  /// No description provided for @nfcCheckOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Station NFC Tag'**
  String get nfcCheckOutTitle;

  /// No description provided for @nfcHoldNearPrompt.
  ///
  /// In en, this message translates to:
  /// **'Hold your phone close to the physical station NFC tag to record your attendance.'**
  String get nfcHoldNearPrompt;

  /// No description provided for @nfcVerifyingPresence.
  ///
  /// In en, this message translates to:
  /// **'Verifying Station Tag...'**
  String get nfcVerifyingPresence;

  /// No description provided for @nfcAuthorizingBackend.
  ///
  /// In en, this message translates to:
  /// **'Validating physical presence and attendance rules on the server...'**
  String get nfcAuthorizingBackend;

  /// No description provided for @nfcCheckInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check-In Verified!'**
  String get nfcCheckInSuccess;

  /// No description provided for @nfcCheckOutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check-Out Verified!'**
  String get nfcCheckOutSuccess;

  /// No description provided for @nfcVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Attendance Verification Failed'**
  String get nfcVerificationFailed;

  /// No description provided for @auditFilterNfcTags.
  ///
  /// In en, this message translates to:
  /// **'NFC Station Tags'**
  String get auditFilterNfcTags;

  /// No description provided for @systemHealthNfcFleet.
  ///
  /// In en, this message translates to:
  /// **'NFC Station Tags'**
  String get systemHealthNfcFleet;

  /// No description provided for @systemHealthNfcActive.
  ///
  /// In en, this message translates to:
  /// **'{active} of {total} Active'**
  String systemHealthNfcActive(int active, int total);

  /// No description provided for @systemHealthNfcTagsHealthy.
  ///
  /// In en, this message translates to:
  /// **'All station NFC tags active and operational'**
  String get systemHealthNfcTagsHealthy;

  /// No description provided for @systemHealthNfcNoActiveTags.
  ///
  /// In en, this message translates to:
  /// **'No active NFC tags configured for this station'**
  String get systemHealthNfcNoActiveTags;

  /// No description provided for @platformManagerRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'Station Manager role removed'**
  String get platformManagerRemovedToast;

  /// No description provided for @platformManagedByPlatform.
  ///
  /// In en, this message translates to:
  /// **'Managed by Platform Administration'**
  String get platformManagedByPlatform;

  /// No description provided for @platformAdminRoleReadonlyHint.
  ///
  /// In en, this message translates to:
  /// **'Station Manager access is assigned only by Platform Administration.'**
  String get platformAdminRoleReadonlyHint;

  /// No description provided for @errorNotPlatformAdmin.
  ///
  /// In en, this message translates to:
  /// **'You must be an active Platform Admin to perform this action.'**
  String get errorNotPlatformAdmin;

  /// No description provided for @errorStationCodeConflict.
  ///
  /// In en, this message translates to:
  /// **'This station code is already in use.'**
  String get errorStationCodeConflict;

  /// No description provided for @errorStationAlreadyInactive.
  ///
  /// In en, this message translates to:
  /// **'This station is already inactive.'**
  String get errorStationAlreadyInactive;

  /// No description provided for @errorStationAlreadyActive.
  ///
  /// In en, this message translates to:
  /// **'This station is already active.'**
  String get errorStationAlreadyActive;

  /// No description provided for @errorStationProvisioningFailed.
  ///
  /// In en, this message translates to:
  /// **'Station provisioning failed. No partial station was left active.'**
  String get errorStationProvisioningFailed;

  /// No description provided for @errorStationAdminRoleForbidden.
  ///
  /// In en, this message translates to:
  /// **'Station Managers cannot grant or revoke Station Manager access.'**
  String get errorStationAdminRoleForbidden;

  /// No description provided for @nfcTagUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'NFC Tag URL'**
  String get nfcTagUrlLabel;

  /// No description provided for @nfcCopyUrlAction.
  ///
  /// In en, this message translates to:
  /// **'Copy NFC URL'**
  String get nfcCopyUrlAction;

  /// No description provided for @nfcUrlCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'NFC URL copied to clipboard'**
  String get nfcUrlCopiedToast;

  /// No description provided for @nfcRegenerateTokenAction.
  ///
  /// In en, this message translates to:
  /// **'Regenerate Token'**
  String get nfcRegenerateTokenAction;

  /// No description provided for @nfcRegenerateTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Regenerate Station Tag Token'**
  String get nfcRegenerateTokenTitle;

  /// No description provided for @nfcRegenerateTokenDesc.
  ///
  /// In en, this message translates to:
  /// **'This will invalidate the previous NFC URL. Any physical tag with the old URL must be reprogrammed with the new URL.'**
  String get nfcRegenerateTokenDesc;

  /// No description provided for @nfcRegenerateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get nfcRegenerateConfirm;

  /// No description provided for @nfcRegeneratedSuccess.
  ///
  /// In en, this message translates to:
  /// **'NFC token regenerated successfully'**
  String get nfcRegeneratedSuccess;

  /// No description provided for @nfcNdefWriteInstructions.
  ///
  /// In en, this message translates to:
  /// **'Write this exact URL as an NDEF URI/URL record to your physical NFC tag using any standard NFC writer app (e.g. NFC Tools on iOS/Android).'**
  String get nfcNdefWriteInstructions;

  /// No description provided for @nfcVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'NFC Check-In Verification'**
  String get nfcVerificationTitle;

  /// No description provided for @nfcVerifyingStation.
  ///
  /// In en, this message translates to:
  /// **'Verifying NFC Station...'**
  String get nfcVerifyingStation;

  /// No description provided for @nfcEmployeeDetected.
  ///
  /// In en, this message translates to:
  /// **'Authenticated Employee'**
  String get nfcEmployeeDetected;

  /// No description provided for @nfcProcessingPunch.
  ///
  /// In en, this message translates to:
  /// **'Recording attendance with server...'**
  String get nfcProcessingPunch;

  /// No description provided for @nfcCheckInSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Started Successfully'**
  String get nfcCheckInSuccessTitle;

  /// No description provided for @nfcCheckOutSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Ended Successfully'**
  String get nfcCheckOutSuccessTitle;

  /// No description provided for @nfcStationLabel.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get nfcStationLabel;

  /// No description provided for @nfcTimeConfirmedLabel.
  ///
  /// In en, this message translates to:
  /// **'Server Time Confirmed'**
  String get nfcTimeConfirmedLabel;

  /// No description provided for @nfcWorkedDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Worked Duration'**
  String get nfcWorkedDurationLabel;

  /// No description provided for @nfcReturnToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to Dashboard'**
  String get nfcReturnToDashboard;

  /// No description provided for @nfcTapPhysicalPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tap the physical NFC tag at your workplace with your phone to start or end your shift.'**
  String get nfcTapPhysicalPrompt;

  /// No description provided for @nfcErrorInvalidToken.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired NFC tag token.'**
  String get nfcErrorInvalidToken;

  /// No description provided for @nfcErrorInactiveStation.
  ///
  /// In en, this message translates to:
  /// **'The station for this NFC tag is currently inactive.'**
  String get nfcErrorInactiveStation;

  /// No description provided for @nfcErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'You are not authorized for this station.'**
  String get nfcErrorUnauthorized;

  /// No description provided for @nfcErrorDuplicatePunch.
  ///
  /// In en, this message translates to:
  /// **'Duplicate punch detected. Please wait a moment before tapping again.'**
  String get nfcErrorDuplicatePunch;

  /// No description provided for @stationSelectSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get stationSelectSignOut;

  /// No description provided for @stationSelectRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get stationSelectRefresh;

  /// No description provided for @stationSelectNoStationActionHint.
  ///
  /// In en, this message translates to:
  /// **'You are not assigned to an active station yet. Contact your station manager to get assigned, or sign out to switch accounts.'**
  String get stationSelectNoStationActionHint;

  /// No description provided for @stationSelectSwitchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch Account'**
  String get stationSelectSwitchAccount;

  /// No description provided for @loginErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Account does not exist or incorrect password. Please check your credentials.'**
  String get loginErrorInvalidCredentials;

  /// No description provided for @loginErrorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email address is not verified yet. Please check your inbox.'**
  String get loginErrorEmailNotConfirmed;

  /// No description provided for @loginErrorAccountSuspended.
  ///
  /// In en, this message translates to:
  /// **'This account is inactive or has been suspended. Please contact your station manager.'**
  String get loginErrorAccountSuspended;

  /// No description provided for @loginErrorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many login attempts. Please wait a moment and try again.'**
  String get loginErrorTooManyAttempts;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
