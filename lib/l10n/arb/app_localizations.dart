import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_he.dart';
import 'app_localizations_hu.dart';
import 'app_localizations_it.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'arb/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('he'),
    Locale('hu'),
    Locale('it'),
    Locale('nl'),
    Locale('pt'),
  ];

  /// Title of the keyboard shortcuts help dialog
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get accessibility_dialog_keyboardShortcutsTitle;

  /// Key label for Backspace key
  ///
  /// In en, this message translates to:
  /// **'Backspace'**
  String get accessibility_keyLabel_backspace;

  /// Key label for Delete key
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get accessibility_keyLabel_delete;

  /// Key label for Down arrow
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get accessibility_keyLabel_down;

  /// Key label for Enter key
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get accessibility_keyLabel_enter;

  /// Key label for Escape key
  ///
  /// In en, this message translates to:
  /// **'Esc'**
  String get accessibility_keyLabel_esc;

  /// Key label for Left arrow
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get accessibility_keyLabel_left;

  /// Key label for Right arrow
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get accessibility_keyLabel_right;

  /// Key label for Up arrow
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get accessibility_keyLabel_up;

  /// Screen reader summary for a chart
  ///
  /// In en, this message translates to:
  /// **'{chartType} chart. {description}'**
  String accessibility_label_chartSummary(Object chartType, Object description);

  /// Semantics label for the FAB create button in master-detail scaffold
  ///
  /// In en, this message translates to:
  /// **'Create new item'**
  String get accessibility_label_createNewItem;

  /// Semantics label on the button that hides the list pane
  ///
  /// In en, this message translates to:
  /// **'Hide list'**
  String get accessibility_label_hideList;

  /// Tooltip for map toggle when map is active
  ///
  /// In en, this message translates to:
  /// **'Hide Map View'**
  String get accessibility_label_hideMapView;

  /// Semantics label for the list pane in a map-list layout
  ///
  /// In en, this message translates to:
  /// **'{title} list pane'**
  String accessibility_label_listPane(Object title);

  /// Semantics label for the map pane in a map-list layout
  ///
  /// In en, this message translates to:
  /// **'{title} map pane'**
  String accessibility_label_mapPane(Object title);

  /// Semantics label for a map view area
  ///
  /// In en, this message translates to:
  /// **'{title} map view'**
  String accessibility_label_mapViewTitle(Object title);

  /// Tooltip for the button that shows the list pane when collapsed
  ///
  /// In en, this message translates to:
  /// **'Show List'**
  String get accessibility_label_showList;

  /// Tooltip for map toggle when map is inactive
  ///
  /// In en, this message translates to:
  /// **'Show Map View'**
  String get accessibility_label_showMapView;

  /// Tooltip for the chevron button to view item details on map info card
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get accessibility_label_viewDetails;

  /// Windows/Linux alt modifier key prefix
  ///
  /// In en, this message translates to:
  /// **'Alt+'**
  String get accessibility_modifierKey_alt;

  /// macOS modifier key prefix
  ///
  /// In en, this message translates to:
  /// **'Cmd+'**
  String get accessibility_modifierKey_cmd;

  /// Control modifier key prefix
  ///
  /// In en, this message translates to:
  /// **'Ctrl+'**
  String get accessibility_modifierKey_ctrl;

  /// macOS alt modifier key prefix
  ///
  /// In en, this message translates to:
  /// **'Option+'**
  String get accessibility_modifierKey_option;

  /// Shift modifier key prefix
  ///
  /// In en, this message translates to:
  /// **'Shift+'**
  String get accessibility_modifierKey_shift;

  /// Linux modifier key prefix
  ///
  /// In en, this message translates to:
  /// **'Super+'**
  String get accessibility_modifierKey_super;

  /// Shortcut category name: Editing
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get accessibility_shortcutCategory_editing;

  /// Shortcut category name: General
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get accessibility_shortcutCategory_general;

  /// Shortcut category name: Help
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get accessibility_shortcutCategory_help;

  /// Shortcut category name: Navigation
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get accessibility_shortcutCategory_navigation;

  /// Shortcut category name: Search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get accessibility_shortcutCategory_search;

  /// Keyboard shortcut label for close or cancel via Escape
  ///
  /// In en, this message translates to:
  /// **'Close / Cancel'**
  String get accessibility_shortcut_closeCancel;

  /// Keyboard shortcut label for going back
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get accessibility_shortcut_goBack;

  /// Keyboard shortcut label for navigating to dives
  ///
  /// In en, this message translates to:
  /// **'Go to Dives'**
  String get accessibility_shortcut_goToDives;

  /// Keyboard shortcut label for navigating to equipment
  ///
  /// In en, this message translates to:
  /// **'Go to Equipment'**
  String get accessibility_shortcut_goToEquipment;

  /// Keyboard shortcut label for navigating to settings
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get accessibility_shortcut_goToSettings;

  /// Keyboard shortcut label for navigating to sites
  ///
  /// In en, this message translates to:
  /// **'Go to Sites'**
  String get accessibility_shortcut_goToSites;

  /// Keyboard shortcut label for navigating to statistics
  ///
  /// In en, this message translates to:
  /// **'Go to Statistics'**
  String get accessibility_shortcut_goToStatistics;

  /// Keyboard shortcut label for opening the shortcuts help
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get accessibility_shortcut_keyboardShortcuts;

  /// Keyboard shortcut label for creating a new dive
  ///
  /// In en, this message translates to:
  /// **'New dive'**
  String get accessibility_shortcut_newDive;

  /// Keyboard shortcut label for opening settings
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get accessibility_shortcut_openSettings;

  /// Keyboard shortcut label for searching dives
  ///
  /// In en, this message translates to:
  /// **'Search dives'**
  String get accessibility_shortcut_searchDives;

  /// Semantics label for a selected sort option
  ///
  /// In en, this message translates to:
  /// **'Sort by {displayName}, currently selected'**
  String accessibility_sort_selectedLabel(Object displayName);

  /// Semantics label for an unselected sort option
  ///
  /// In en, this message translates to:
  /// **'Sort by {displayName}'**
  String accessibility_sort_unselectedLabel(Object displayName);

  /// No description provided for @backup_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backup_appBar_title;

  /// No description provided for @backup_backingUp.
  ///
  /// In en, this message translates to:
  /// **'Backing up...'**
  String get backup_backingUp;

  /// No description provided for @backup_backupNow.
  ///
  /// In en, this message translates to:
  /// **'Backup Now'**
  String get backup_backupNow;

  /// No description provided for @backup_cloud_enabled.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup'**
  String get backup_cloud_enabled;

  /// No description provided for @backup_cloud_enabled_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload backups to cloud storage'**
  String get backup_cloud_enabled_subtitle;

  /// No description provided for @backup_delete_dialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get backup_delete_dialog_cancel;

  /// No description provided for @backup_delete_dialog_content.
  ///
  /// In en, this message translates to:
  /// **'This backup will be permanently deleted. This cannot be undone.'**
  String get backup_delete_dialog_content;

  /// No description provided for @backup_delete_dialog_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get backup_delete_dialog_delete;

  /// No description provided for @backup_delete_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Backup'**
  String get backup_delete_dialog_title;

  /// No description provided for @backup_frequency_daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get backup_frequency_daily;

  /// No description provided for @backup_frequency_monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get backup_frequency_monthly;

  /// No description provided for @backup_frequency_weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get backup_frequency_weekly;

  /// No description provided for @backup_history_action_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get backup_history_action_delete;

  /// No description provided for @backup_history_action_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backup_history_action_restore;

  /// No description provided for @backup_history_empty.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get backup_history_empty;

  /// No description provided for @backup_history_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load history: {error}'**
  String backup_history_error(Object error);

  /// No description provided for @backup_restore_dialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get backup_restore_dialog_cancel;

  /// No description provided for @backup_restore_dialog_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backup_restore_dialog_restore;

  /// No description provided for @backup_restore_dialog_safetyNote.
  ///
  /// In en, this message translates to:
  /// **'A safety backup of your current data will be created automatically before restoring.'**
  String get backup_restore_dialog_safetyNote;

  /// No description provided for @backup_restore_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup'**
  String get backup_restore_dialog_title;

  /// No description provided for @backup_restore_dialog_warning.
  ///
  /// In en, this message translates to:
  /// **'This will replace ALL current data with the backup data. This action cannot be undone.'**
  String get backup_restore_dialog_warning;

  /// No description provided for @backup_schedule_enabled.
  ///
  /// In en, this message translates to:
  /// **'Automatic backups'**
  String get backup_schedule_enabled;

  /// No description provided for @backup_schedule_enabled_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your data on a schedule'**
  String get backup_schedule_enabled_subtitle;

  /// No description provided for @backup_schedule_frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get backup_schedule_frequency;

  /// No description provided for @backup_schedule_retention.
  ///
  /// In en, this message translates to:
  /// **'Keep backups'**
  String get backup_schedule_retention;

  /// No description provided for @backup_schedule_retention_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Older backups are automatically removed'**
  String get backup_schedule_retention_subtitle;

  /// No description provided for @backup_section_cloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get backup_section_cloud;

  /// No description provided for @backup_section_history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get backup_section_history;

  /// No description provided for @backup_section_schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get backup_section_schedule;

  /// No description provided for @backup_status_disabled.
  ///
  /// In en, this message translates to:
  /// **'Automatic Backups Disabled'**
  String get backup_status_disabled;

  /// No description provided for @backup_status_lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {time}'**
  String backup_status_lastBackup(String time);

  /// No description provided for @backup_status_neverBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Never Backed Up'**
  String get backup_status_neverBackedUp;

  /// No description provided for @backup_status_noBackupsYet.
  ///
  /// In en, this message translates to:
  /// **'Create your first backup to protect your data'**
  String get backup_status_noBackupsYet;

  /// No description provided for @backup_status_overdue.
  ///
  /// In en, this message translates to:
  /// **'Backup Overdue'**
  String get backup_status_overdue;

  /// No description provided for @backup_status_upToDate.
  ///
  /// In en, this message translates to:
  /// **'Backups Up to Date'**
  String get backup_status_upToDate;

  /// No description provided for @backup_time_daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String backup_time_daysAgo(int count);

  /// No description provided for @backup_time_hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String backup_time_hoursAgo(int count);

  /// No description provided for @backup_time_justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get backup_time_justNow;

  /// No description provided for @backup_time_minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String backup_time_minutesAgo(int count);

  /// No description provided for @buddies_action_add.
  ///
  /// In en, this message translates to:
  /// **'Add Buddy'**
  String get buddies_action_add;

  /// No description provided for @buddies_action_addFirst.
  ///
  /// In en, this message translates to:
  /// **'Add your first buddy'**
  String get buddies_action_addFirst;

  /// No description provided for @buddies_action_addTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a new dive buddy'**
  String get buddies_action_addTooltip;

  /// No description provided for @buddies_action_clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get buddies_action_clearSearch;

  /// No description provided for @buddies_action_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit buddy'**
  String get buddies_action_edit;

  /// No description provided for @buddies_action_importFromContacts.
  ///
  /// In en, this message translates to:
  /// **'Import from Contacts'**
  String get buddies_action_importFromContacts;

  /// No description provided for @buddies_action_moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get buddies_action_moreOptions;

  /// No description provided for @buddies_action_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get buddies_action_retry;

  /// No description provided for @buddies_action_search.
  ///
  /// In en, this message translates to:
  /// **'Search buddies'**
  String get buddies_action_search;

  /// No description provided for @buddies_action_shareDives.
  ///
  /// In en, this message translates to:
  /// **'Share Dives'**
  String get buddies_action_shareDives;

  /// No description provided for @buddies_action_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get buddies_action_sort;

  /// No description provided for @buddies_action_sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort Buddies'**
  String get buddies_action_sortTitle;

  /// No description provided for @buddies_action_update.
  ///
  /// In en, this message translates to:
  /// **'Update Buddy'**
  String get buddies_action_update;

  /// No description provided for @buddies_action_viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All ({count})'**
  String buddies_action_viewAll(Object count);

  /// No description provided for @buddies_detail_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String buddies_detail_error(Object error);

  /// No description provided for @buddies_detail_noDivesTogether.
  ///
  /// In en, this message translates to:
  /// **'No dives together yet'**
  String get buddies_detail_noDivesTogether;

  /// No description provided for @buddies_detail_notFound.
  ///
  /// In en, this message translates to:
  /// **'Buddy not found'**
  String get buddies_detail_notFound;

  /// No description provided for @buddies_dialog_deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}? This action cannot be undone.'**
  String buddies_dialog_deleteMessage(Object name);

  /// No description provided for @buddies_dialog_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Buddy?'**
  String get buddies_dialog_deleteTitle;

  /// No description provided for @buddies_dialog_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get buddies_dialog_discard;

  /// No description provided for @buddies_dialog_discardMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to discard them?'**
  String get buddies_dialog_discardMessage;

  /// No description provided for @buddies_dialog_discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes?'**
  String get buddies_dialog_discardTitle;

  /// No description provided for @buddies_dialog_keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get buddies_dialog_keepEditing;

  /// No description provided for @buddies_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first dive buddy to get started'**
  String get buddies_empty_subtitle;

  /// No description provided for @buddies_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No dive buddies yet'**
  String get buddies_empty_title;

  /// No description provided for @buddies_error_loading.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String buddies_error_loading(Object error);

  /// No description provided for @buddies_error_unableToLoadDives.
  ///
  /// In en, this message translates to:
  /// **'Unable to load dives'**
  String get buddies_error_unableToLoadDives;

  /// No description provided for @buddies_error_unableToLoadStats.
  ///
  /// In en, this message translates to:
  /// **'Unable to load statistics'**
  String get buddies_error_unableToLoadStats;

  /// No description provided for @buddies_field_certificationAgency.
  ///
  /// In en, this message translates to:
  /// **'Certification Agency'**
  String get buddies_field_certificationAgency;

  /// No description provided for @buddies_field_certificationLevel.
  ///
  /// In en, this message translates to:
  /// **'Certification Level'**
  String get buddies_field_certificationLevel;

  /// No description provided for @buddies_field_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get buddies_field_email;

  /// No description provided for @buddies_field_emailHint.
  ///
  /// In en, this message translates to:
  /// **'email@example.com'**
  String get buddies_field_emailHint;

  /// No description provided for @buddies_field_nameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter buddy name'**
  String get buddies_field_nameHint;

  /// No description provided for @buddies_field_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get buddies_field_nameRequired;

  /// No description provided for @buddies_field_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get buddies_field_notes;

  /// No description provided for @buddies_field_notesHint.
  ///
  /// In en, this message translates to:
  /// **'Add notes about this buddy...'**
  String get buddies_field_notesHint;

  /// No description provided for @buddies_field_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get buddies_field_phone;

  /// No description provided for @buddies_field_phoneHint.
  ///
  /// In en, this message translates to:
  /// **'+1 (555) 123-4567'**
  String get buddies_field_phoneHint;

  /// No description provided for @buddies_label_agency.
  ///
  /// In en, this message translates to:
  /// **'Agency'**
  String get buddies_label_agency;

  /// No description provided for @buddies_label_diveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dive} other{{count} dives}}'**
  String buddies_label_diveCount(int count);

  /// No description provided for @buddies_label_level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get buddies_label_level;

  /// No description provided for @buddies_label_notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get buddies_label_notSpecified;

  /// No description provided for @buddies_label_photoComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Photo support coming in v2.0'**
  String get buddies_label_photoComingSoon;

  /// No description provided for @buddies_message_added.
  ///
  /// In en, this message translates to:
  /// **'Buddy added successfully'**
  String get buddies_message_added;

  /// No description provided for @buddies_message_contactImportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Contact import is not available on this platform'**
  String get buddies_message_contactImportUnavailable;

  /// No description provided for @buddies_message_contactLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load contacts'**
  String get buddies_message_contactLoadFailed;

  /// No description provided for @buddies_message_contactPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Contact permission is required to import buddies'**
  String get buddies_message_contactPermissionRequired;

  /// No description provided for @buddies_message_deleted.
  ///
  /// In en, this message translates to:
  /// **'Buddy deleted'**
  String get buddies_message_deleted;

  /// No description provided for @buddies_message_errorImportingContact.
  ///
  /// In en, this message translates to:
  /// **'Error importing contact: {error}'**
  String buddies_message_errorImportingContact(Object error);

  /// No description provided for @buddies_message_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading buddy: {error}'**
  String buddies_message_errorLoading(Object error);

  /// No description provided for @buddies_message_errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving buddy: {error}'**
  String buddies_message_errorSaving(Object error);

  /// No description provided for @buddies_message_exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String buddies_message_exportFailed(Object error);

  /// No description provided for @buddies_message_noDivesFound.
  ///
  /// In en, this message translates to:
  /// **'No dives found to export'**
  String get buddies_message_noDivesFound;

  /// No description provided for @buddies_message_noDivesToShare.
  ///
  /// In en, this message translates to:
  /// **'No dives to share with this buddy'**
  String get buddies_message_noDivesToShare;

  /// No description provided for @buddies_message_preparingExport.
  ///
  /// In en, this message translates to:
  /// **'Preparing export...'**
  String get buddies_message_preparingExport;

  /// No description provided for @buddies_message_updated.
  ///
  /// In en, this message translates to:
  /// **'Buddy updated successfully'**
  String get buddies_message_updated;

  /// No description provided for @buddies_picker_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get buddies_picker_add;

  /// No description provided for @buddies_picker_addNew.
  ///
  /// In en, this message translates to:
  /// **'Add New Buddy'**
  String get buddies_picker_addNew;

  /// No description provided for @buddies_picker_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get buddies_picker_done;

  /// No description provided for @buddies_picker_noBuddiesFound.
  ///
  /// In en, this message translates to:
  /// **'No buddies found'**
  String get buddies_picker_noBuddiesFound;

  /// No description provided for @buddies_picker_noBuddiesYet.
  ///
  /// In en, this message translates to:
  /// **'No buddies yet'**
  String get buddies_picker_noBuddiesYet;

  /// No description provided for @buddies_picker_noneSelected.
  ///
  /// In en, this message translates to:
  /// **'No buddies selected'**
  String get buddies_picker_noneSelected;

  /// No description provided for @buddies_picker_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search buddies...'**
  String get buddies_picker_searchHint;

  /// No description provided for @buddies_picker_selectBuddies.
  ///
  /// In en, this message translates to:
  /// **'Select Buddies'**
  String get buddies_picker_selectBuddies;

  /// No description provided for @buddies_picker_selectRole.
  ///
  /// In en, this message translates to:
  /// **'Select Role for {name}'**
  String buddies_picker_selectRole(Object name);

  /// No description provided for @buddies_picker_tapToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap \'Add\' to select dive buddies'**
  String get buddies_picker_tapToAdd;

  /// No description provided for @buddies_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, email, or phone'**
  String get buddies_search_hint;

  /// No description provided for @buddies_search_noResults.
  ///
  /// In en, this message translates to:
  /// **'No buddies found for \"{query}\"'**
  String buddies_search_noResults(Object query);

  /// No description provided for @buddies_section_certification.
  ///
  /// In en, this message translates to:
  /// **'Certification'**
  String get buddies_section_certification;

  /// No description provided for @buddies_section_contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get buddies_section_contact;

  /// No description provided for @buddies_section_diveStatistics.
  ///
  /// In en, this message translates to:
  /// **'Dive Statistics'**
  String get buddies_section_diveStatistics;

  /// No description provided for @buddies_section_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get buddies_section_notes;

  /// No description provided for @buddies_section_sharedDives.
  ///
  /// In en, this message translates to:
  /// **'Shared Dives'**
  String get buddies_section_sharedDives;

  /// No description provided for @buddies_stat_divesTogether.
  ///
  /// In en, this message translates to:
  /// **'Dives Together'**
  String get buddies_stat_divesTogether;

  /// No description provided for @buddies_stat_favoriteSite.
  ///
  /// In en, this message translates to:
  /// **'Favorite Site'**
  String get buddies_stat_favoriteSite;

  /// No description provided for @buddies_stat_firstDive.
  ///
  /// In en, this message translates to:
  /// **'First Dive'**
  String get buddies_stat_firstDive;

  /// No description provided for @buddies_stat_lastDive.
  ///
  /// In en, this message translates to:
  /// **'Last Dive'**
  String get buddies_stat_lastDive;

  /// No description provided for @buddies_summary_overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get buddies_summary_overview;

  /// No description provided for @buddies_summary_quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get buddies_summary_quickActions;

  /// No description provided for @buddies_summary_recentBuddies.
  ///
  /// In en, this message translates to:
  /// **'Recent Buddies'**
  String get buddies_summary_recentBuddies;

  /// No description provided for @buddies_summary_selectHint.
  ///
  /// In en, this message translates to:
  /// **'Select a buddy from the list to view details'**
  String get buddies_summary_selectHint;

  /// No description provided for @buddies_summary_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Buddies'**
  String get buddies_summary_title;

  /// No description provided for @buddies_summary_totalBuddies.
  ///
  /// In en, this message translates to:
  /// **'Total Buddies'**
  String get buddies_summary_totalBuddies;

  /// No description provided for @buddies_summary_withCertification.
  ///
  /// In en, this message translates to:
  /// **'With Certification'**
  String get buddies_summary_withCertification;

  /// No description provided for @buddies_title.
  ///
  /// In en, this message translates to:
  /// **'Buddies'**
  String get buddies_title;

  /// No description provided for @buddies_title_add.
  ///
  /// In en, this message translates to:
  /// **'Add Buddy'**
  String get buddies_title_add;

  /// No description provided for @buddies_title_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit Buddy'**
  String get buddies_title_edit;

  /// No description provided for @buddies_title_singular.
  ///
  /// In en, this message translates to:
  /// **'Buddy'**
  String get buddies_title_singular;

  /// No description provided for @buddies_validation_emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get buddies_validation_emailInvalid;

  /// No description provided for @buddies_validation_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get buddies_validation_nameRequired;

  /// No description provided for @certifications_appBar_addCertification.
  ///
  /// In en, this message translates to:
  /// **'Add Certification'**
  String get certifications_appBar_addCertification;

  /// No description provided for @certifications_appBar_certificationWallet.
  ///
  /// In en, this message translates to:
  /// **'Certification Wallet'**
  String get certifications_appBar_certificationWallet;

  /// No description provided for @certifications_appBar_editCertification.
  ///
  /// In en, this message translates to:
  /// **'Edit Certification'**
  String get certifications_appBar_editCertification;

  /// No description provided for @certifications_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Certifications'**
  String get certifications_appBar_title;

  /// No description provided for @certifications_detail_action_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get certifications_detail_action_delete;

  /// No description provided for @certifications_detail_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Certification'**
  String get certifications_detail_appBar_title;

  /// No description provided for @certifications_detail_courseCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get certifications_detail_courseCompleted;

  /// No description provided for @certifications_detail_courseInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get certifications_detail_courseInProgress;

  /// No description provided for @certifications_detail_dialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get certifications_detail_dialog_cancel;

  /// No description provided for @certifications_detail_dialog_deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get certifications_detail_dialog_deleteConfirm;

  /// No description provided for @certifications_detail_dialog_deleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String certifications_detail_dialog_deleteContent(Object name);

  /// No description provided for @certifications_detail_dialog_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Certification?'**
  String get certifications_detail_dialog_deleteTitle;

  /// No description provided for @certifications_detail_label_agency.
  ///
  /// In en, this message translates to:
  /// **'Agency'**
  String get certifications_detail_label_agency;

  /// No description provided for @certifications_detail_label_cardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get certifications_detail_label_cardNumber;

  /// No description provided for @certifications_detail_label_expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get certifications_detail_label_expiryDate;

  /// No description provided for @certifications_detail_label_instructorName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get certifications_detail_label_instructorName;

  /// No description provided for @certifications_detail_label_instructorNumber.
  ///
  /// In en, this message translates to:
  /// **'Instructor #'**
  String get certifications_detail_label_instructorNumber;

  /// No description provided for @certifications_detail_label_issueDate.
  ///
  /// In en, this message translates to:
  /// **'Issue Date'**
  String get certifications_detail_label_issueDate;

  /// No description provided for @certifications_detail_label_level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get certifications_detail_label_level;

  /// No description provided for @certifications_detail_label_type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get certifications_detail_label_type;

  /// No description provided for @certifications_detail_label_validity.
  ///
  /// In en, this message translates to:
  /// **'Validity'**
  String get certifications_detail_label_validity;

  /// No description provided for @certifications_detail_noExpiration.
  ///
  /// In en, this message translates to:
  /// **'No Expiration'**
  String get certifications_detail_noExpiration;

  /// No description provided for @certifications_detail_notFound.
  ///
  /// In en, this message translates to:
  /// **'Certification not found'**
  String get certifications_detail_notFound;

  /// No description provided for @certifications_detail_photoLabel_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get certifications_detail_photoLabel_back;

  /// No description provided for @certifications_detail_photoLabel_front.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get certifications_detail_photoLabel_front;

  /// No description provided for @certifications_detail_photo_fullscreenTitle.
  ///
  /// In en, this message translates to:
  /// **'{label} - {name}'**
  String certifications_detail_photo_fullscreenTitle(Object label, Object name);

  /// No description provided for @certifications_detail_photo_unableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load image'**
  String get certifications_detail_photo_unableToLoad;

  /// No description provided for @certifications_detail_sectionTitle_cardPhotos.
  ///
  /// In en, this message translates to:
  /// **'Card Photos'**
  String get certifications_detail_sectionTitle_cardPhotos;

  /// No description provided for @certifications_detail_sectionTitle_dates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get certifications_detail_sectionTitle_dates;

  /// No description provided for @certifications_detail_sectionTitle_details.
  ///
  /// In en, this message translates to:
  /// **'Certification Details'**
  String get certifications_detail_sectionTitle_details;

  /// No description provided for @certifications_detail_sectionTitle_instructor.
  ///
  /// In en, this message translates to:
  /// **'Instructor'**
  String get certifications_detail_sectionTitle_instructor;

  /// No description provided for @certifications_detail_sectionTitle_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get certifications_detail_sectionTitle_notes;

  /// No description provided for @certifications_detail_sectionTitle_trainingCourse.
  ///
  /// In en, this message translates to:
  /// **'Training Course'**
  String get certifications_detail_sectionTitle_trainingCourse;

  /// No description provided for @certifications_detail_semanticLabel_photoTapToView.
  ///
  /// In en, this message translates to:
  /// **'{label} photo of {name}. Tap to view full screen'**
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  );

  /// No description provided for @certifications_detail_snackBar_deleted.
  ///
  /// In en, this message translates to:
  /// **'Certification deleted'**
  String get certifications_detail_snackBar_deleted;

  /// No description provided for @certifications_detail_status_expired.
  ///
  /// In en, this message translates to:
  /// **'This certification has expired'**
  String get certifications_detail_status_expired;

  /// No description provided for @certifications_detail_status_expiredOn.
  ///
  /// In en, this message translates to:
  /// **'Expired on {date}'**
  String certifications_detail_status_expiredOn(Object date);

  /// No description provided for @certifications_detail_status_expiresInDays.
  ///
  /// In en, this message translates to:
  /// **'Expires in {days} days'**
  String certifications_detail_status_expiresInDays(Object days);

  /// No description provided for @certifications_detail_status_expiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires on {date}'**
  String certifications_detail_status_expiresOn(Object date);

  /// No description provided for @certifications_detail_tooltip_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit certification'**
  String get certifications_detail_tooltip_edit;

  /// No description provided for @certifications_detail_tooltip_editShort.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get certifications_detail_tooltip_editShort;

  /// No description provided for @certifications_detail_tooltip_moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get certifications_detail_tooltip_moreOptions;

  /// No description provided for @certifications_ecardStack_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first certification to see it here'**
  String get certifications_ecardStack_empty_subtitle;

  /// No description provided for @certifications_ecardStack_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No certifications yet'**
  String get certifications_ecardStack_empty_title;

  /// No description provided for @certifications_ecard_label_certifiedBy.
  ///
  /// In en, this message translates to:
  /// **'Certified by {agency}'**
  String certifications_ecard_label_certifiedBy(Object agency);

  /// No description provided for @certifications_ecard_label_instructor.
  ///
  /// In en, this message translates to:
  /// **'INSTRUCTOR'**
  String get certifications_ecard_label_instructor;

  /// No description provided for @certifications_ecard_label_issued.
  ///
  /// In en, this message translates to:
  /// **'ISSUED'**
  String get certifications_ecard_label_issued;

  /// No description provided for @certifications_ecard_statusBadge_expired.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get certifications_ecard_statusBadge_expired;

  /// No description provided for @certifications_ecard_statusBadge_expiring.
  ///
  /// In en, this message translates to:
  /// **'EXPIRING'**
  String get certifications_ecard_statusBadge_expiring;

  /// No description provided for @certifications_edit_appBar_add.
  ///
  /// In en, this message translates to:
  /// **'Add Certification'**
  String get certifications_edit_appBar_add;

  /// No description provided for @certifications_edit_appBar_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit Certification'**
  String get certifications_edit_appBar_edit;

  /// No description provided for @certifications_edit_button_add.
  ///
  /// In en, this message translates to:
  /// **'Add Certification'**
  String get certifications_edit_button_add;

  /// No description provided for @certifications_edit_button_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get certifications_edit_button_cancel;

  /// No description provided for @certifications_edit_button_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get certifications_edit_button_save;

  /// No description provided for @certifications_edit_button_update.
  ///
  /// In en, this message translates to:
  /// **'Update Certification'**
  String get certifications_edit_button_update;

  /// No description provided for @certifications_edit_datePicker_clearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear {label}'**
  String certifications_edit_datePicker_clearTooltip(Object label);

  /// No description provided for @certifications_edit_datePicker_tapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select'**
  String get certifications_edit_datePicker_tapToSelect;

  /// No description provided for @certifications_edit_dialog_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get certifications_edit_dialog_discard;

  /// No description provided for @certifications_edit_dialog_discardContent.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to leave?'**
  String get certifications_edit_dialog_discardContent;

  /// No description provided for @certifications_edit_dialog_discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes?'**
  String get certifications_edit_dialog_discardTitle;

  /// No description provided for @certifications_edit_dialog_keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get certifications_edit_dialog_keepEditing;

  /// No description provided for @certifications_edit_help_expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for certifications that don\'t expire'**
  String get certifications_edit_help_expiryDate;

  /// No description provided for @certifications_edit_hint_cardNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter certification card number'**
  String get certifications_edit_hint_cardNumber;

  /// No description provided for @certifications_edit_hint_certificationName.
  ///
  /// In en, this message translates to:
  /// **'e.g., Open Water Diver'**
  String get certifications_edit_hint_certificationName;

  /// No description provided for @certifications_edit_hint_instructorName.
  ///
  /// In en, this message translates to:
  /// **'Name of certifying instructor'**
  String get certifications_edit_hint_instructorName;

  /// No description provided for @certifications_edit_hint_instructorNumber.
  ///
  /// In en, this message translates to:
  /// **'Instructor certification number'**
  String get certifications_edit_hint_instructorNumber;

  /// No description provided for @certifications_edit_hint_notes.
  ///
  /// In en, this message translates to:
  /// **'Any additional notes'**
  String get certifications_edit_hint_notes;

  /// No description provided for @certifications_edit_label_agency.
  ///
  /// In en, this message translates to:
  /// **'Agency *'**
  String get certifications_edit_label_agency;

  /// No description provided for @certifications_edit_label_cardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get certifications_edit_label_cardNumber;

  /// No description provided for @certifications_edit_label_certificationName.
  ///
  /// In en, this message translates to:
  /// **'Certification Name *'**
  String get certifications_edit_label_certificationName;

  /// No description provided for @certifications_edit_label_expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get certifications_edit_label_expiryDate;

  /// No description provided for @certifications_edit_label_instructorName.
  ///
  /// In en, this message translates to:
  /// **'Instructor Name'**
  String get certifications_edit_label_instructorName;

  /// No description provided for @certifications_edit_label_instructorNumber.
  ///
  /// In en, this message translates to:
  /// **'Instructor Number'**
  String get certifications_edit_label_instructorNumber;

  /// No description provided for @certifications_edit_label_issueDate.
  ///
  /// In en, this message translates to:
  /// **'Issue Date'**
  String get certifications_edit_label_issueDate;

  /// No description provided for @certifications_edit_label_level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get certifications_edit_label_level;

  /// No description provided for @certifications_edit_label_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get certifications_edit_label_notes;

  /// No description provided for @certifications_edit_level_notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get certifications_edit_level_notSpecified;

  /// No description provided for @certifications_edit_photo_addSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Add {label} photo. Tap to select'**
  String certifications_edit_photo_addSemanticLabel(Object label);

  /// No description provided for @certifications_edit_photo_attachedSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{label} photo attached. Tap to change'**
  String certifications_edit_photo_attachedSemanticLabel(Object label);

  /// No description provided for @certifications_edit_photo_chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get certifications_edit_photo_chooseFromGallery;

  /// No description provided for @certifications_edit_photo_removeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove {label} photo'**
  String certifications_edit_photo_removeTooltip(Object label);

  /// No description provided for @certifications_edit_photo_takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get certifications_edit_photo_takePhoto;

  /// No description provided for @certifications_edit_sectionTitle_cardPhotos.
  ///
  /// In en, this message translates to:
  /// **'Card Photos'**
  String get certifications_edit_sectionTitle_cardPhotos;

  /// No description provided for @certifications_edit_sectionTitle_dates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get certifications_edit_sectionTitle_dates;

  /// No description provided for @certifications_edit_sectionTitle_instructorInfo.
  ///
  /// In en, this message translates to:
  /// **'Instructor Information'**
  String get certifications_edit_sectionTitle_instructorInfo;

  /// No description provided for @certifications_edit_sectionTitle_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get certifications_edit_sectionTitle_notes;

  /// No description provided for @certifications_edit_snackBar_added.
  ///
  /// In en, this message translates to:
  /// **'Certification added successfully'**
  String get certifications_edit_snackBar_added;

  /// No description provided for @certifications_edit_snackBar_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading certification: {error}'**
  String certifications_edit_snackBar_errorLoading(Object error);

  /// No description provided for @certifications_edit_snackBar_errorPhoto.
  ///
  /// In en, this message translates to:
  /// **'Error picking photo: {error}'**
  String certifications_edit_snackBar_errorPhoto(Object error);

  /// No description provided for @certifications_edit_snackBar_errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving certification: {error}'**
  String certifications_edit_snackBar_errorSaving(Object error);

  /// No description provided for @certifications_edit_snackBar_updated.
  ///
  /// In en, this message translates to:
  /// **'Certification updated successfully'**
  String get certifications_edit_snackBar_updated;

  /// No description provided for @certifications_edit_validation_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a certification name'**
  String get certifications_edit_validation_nameRequired;

  /// No description provided for @certifications_list_button_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get certifications_list_button_retry;

  /// No description provided for @certifications_list_empty_button.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Certification'**
  String get certifications_list_empty_button;

  /// No description provided for @certifications_list_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your dive certifications to keep track of your training and qualifications'**
  String get certifications_list_empty_subtitle;

  /// No description provided for @certifications_list_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No certifications added yet'**
  String get certifications_list_empty_title;

  /// No description provided for @certifications_list_error_loading.
  ///
  /// In en, this message translates to:
  /// **'Error loading certifications: {error}'**
  String certifications_list_error_loading(Object error);

  /// No description provided for @certifications_list_fab_addCertification.
  ///
  /// In en, this message translates to:
  /// **'Add Certification'**
  String get certifications_list_fab_addCertification;

  /// No description provided for @certifications_list_section_expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get certifications_list_section_expired;

  /// No description provided for @certifications_list_section_expiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get certifications_list_section_expiringSoon;

  /// No description provided for @certifications_list_section_valid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get certifications_list_section_valid;

  /// No description provided for @certifications_list_sort_title.
  ///
  /// In en, this message translates to:
  /// **'Sort Certifications'**
  String get certifications_list_sort_title;

  /// No description provided for @certifications_list_tile_expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get certifications_list_tile_expired;

  /// No description provided for @certifications_list_tile_expiringDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String certifications_list_tile_expiringDays(Object days);

  /// No description provided for @certifications_list_tooltip_addCertification.
  ///
  /// In en, this message translates to:
  /// **'Add Certification'**
  String get certifications_list_tooltip_addCertification;

  /// No description provided for @certifications_list_tooltip_search.
  ///
  /// In en, this message translates to:
  /// **'Search certifications'**
  String get certifications_list_tooltip_search;

  /// No description provided for @certifications_list_tooltip_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get certifications_list_tooltip_sort;

  /// No description provided for @certifications_list_tooltip_walletView.
  ///
  /// In en, this message translates to:
  /// **'Wallet View'**
  String get certifications_list_tooltip_walletView;

  /// No description provided for @certifications_picker_clearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear certification selection'**
  String get certifications_picker_clearTooltip;

  /// No description provided for @certifications_picker_empty_addButton.
  ///
  /// In en, this message translates to:
  /// **'Add Certification'**
  String get certifications_picker_empty_addButton;

  /// No description provided for @certifications_picker_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No certifications yet'**
  String get certifications_picker_empty_title;

  /// No description provided for @certifications_picker_error.
  ///
  /// In en, this message translates to:
  /// **'Error loading certifications: {error}'**
  String certifications_picker_error(Object error);

  /// No description provided for @certifications_picker_expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get certifications_picker_expired;

  /// No description provided for @certifications_picker_hint.
  ///
  /// In en, this message translates to:
  /// **'Tap to link to an earned certification'**
  String get certifications_picker_hint;

  /// No description provided for @certifications_picker_newCert.
  ///
  /// In en, this message translates to:
  /// **'New Cert'**
  String get certifications_picker_newCert;

  /// No description provided for @certifications_picker_noSelection.
  ///
  /// In en, this message translates to:
  /// **'No certification selected'**
  String get certifications_picker_noSelection;

  /// No description provided for @certifications_picker_sheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Link to Certification'**
  String get certifications_picker_sheetTitle;

  /// No description provided for @certifications_renderer_footer.
  ///
  /// In en, this message translates to:
  /// **'Submersion Dive Log'**
  String get certifications_renderer_footer;

  /// No description provided for @certifications_renderer_label_cardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card #: {number}'**
  String certifications_renderer_label_cardNumber(Object number);

  /// No description provided for @certifications_renderer_label_hasCompletedTraining.
  ///
  /// In en, this message translates to:
  /// **'has completed training as'**
  String get certifications_renderer_label_hasCompletedTraining;

  /// No description provided for @certifications_renderer_label_instructor.
  ///
  /// In en, this message translates to:
  /// **'Instructor: {name}'**
  String certifications_renderer_label_instructor(Object name);

  /// No description provided for @certifications_renderer_label_instructorWithNumber.
  ///
  /// In en, this message translates to:
  /// **'Instructor: {name} ({number})'**
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  );

  /// No description provided for @certifications_renderer_label_issued.
  ///
  /// In en, this message translates to:
  /// **'Issued: {date}'**
  String certifications_renderer_label_issued(Object date);

  /// No description provided for @certifications_renderer_label_thisCertifies.
  ///
  /// In en, this message translates to:
  /// **'This certifies that'**
  String get certifications_renderer_label_thisCertifies;

  /// No description provided for @certifications_search_empty_hint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, agency, or card number'**
  String get certifications_search_empty_hint;

  /// No description provided for @certifications_search_fieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Search certifications...'**
  String get certifications_search_fieldLabel;

  /// No description provided for @certifications_search_noResults.
  ///
  /// In en, this message translates to:
  /// **'No certifications found for \"{query}\"'**
  String certifications_search_noResults(Object query);

  /// No description provided for @certifications_search_tooltip_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get certifications_search_tooltip_back;

  /// No description provided for @certifications_search_tooltip_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get certifications_search_tooltip_clear;

  /// No description provided for @certifications_share_error_card.
  ///
  /// In en, this message translates to:
  /// **'Failed to share card: {error}'**
  String certifications_share_error_card(Object error);

  /// No description provided for @certifications_share_error_certificate.
  ///
  /// In en, this message translates to:
  /// **'Failed to share certificate: {error}'**
  String certifications_share_error_certificate(Object error);

  /// No description provided for @certifications_share_option_card_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Credit card-style certification image'**
  String get certifications_share_option_card_subtitle;

  /// No description provided for @certifications_share_option_card_title.
  ///
  /// In en, this message translates to:
  /// **'Share as Card'**
  String get certifications_share_option_card_title;

  /// No description provided for @certifications_share_option_certificate_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Formal certificate document'**
  String get certifications_share_option_certificate_subtitle;

  /// No description provided for @certifications_share_option_certificate_title.
  ///
  /// In en, this message translates to:
  /// **'Share as Certificate'**
  String get certifications_share_option_certificate_title;

  /// No description provided for @certifications_share_title.
  ///
  /// In en, this message translates to:
  /// **'Share Certification'**
  String get certifications_share_title;

  /// No description provided for @certifications_summary_header_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a certification from the list to view details'**
  String get certifications_summary_header_subtitle;

  /// No description provided for @certifications_summary_header_title.
  ///
  /// In en, this message translates to:
  /// **'Certifications'**
  String get certifications_summary_header_title;

  /// No description provided for @certifications_summary_overview_title.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get certifications_summary_overview_title;

  /// No description provided for @certifications_summary_quickActions_add.
  ///
  /// In en, this message translates to:
  /// **'Add Certification'**
  String get certifications_summary_quickActions_add;

  /// No description provided for @certifications_summary_quickActions_title.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get certifications_summary_quickActions_title;

  /// No description provided for @certifications_summary_recentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Certifications'**
  String get certifications_summary_recentTitle;

  /// No description provided for @certifications_summary_stat_expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get certifications_summary_stat_expired;

  /// No description provided for @certifications_summary_stat_expiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get certifications_summary_stat_expiringSoon;

  /// No description provided for @certifications_summary_stat_total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get certifications_summary_stat_total;

  /// No description provided for @certifications_summary_stat_valid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get certifications_summary_stat_valid;

  /// No description provided for @certifications_walletCard_countPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} certifications'**
  String certifications_walletCard_countPlural(Object count);

  /// No description provided for @certifications_walletCard_countSingular.
  ///
  /// In en, this message translates to:
  /// **'{count} certification'**
  String certifications_walletCard_countSingular(Object count);

  /// No description provided for @certifications_walletCard_emptyFooter.
  ///
  /// In en, this message translates to:
  /// **'Add your first certification'**
  String get certifications_walletCard_emptyFooter;

  /// No description provided for @certifications_walletCard_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load certifications'**
  String get certifications_walletCard_error;

  /// No description provided for @certifications_walletCard_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Certification Wallet. Tap to view all certifications'**
  String get certifications_walletCard_semanticLabel;

  /// No description provided for @certifications_walletCard_tapToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap to add'**
  String get certifications_walletCard_tapToAdd;

  /// No description provided for @certifications_walletCard_title.
  ///
  /// In en, this message translates to:
  /// **'Certification Wallet'**
  String get certifications_walletCard_title;

  /// No description provided for @certifications_wallet_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Certification Wallet'**
  String get certifications_wallet_appBar_title;

  /// No description provided for @certifications_wallet_error_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get certifications_wallet_error_retry;

  /// No description provided for @certifications_wallet_error_title.
  ///
  /// In en, this message translates to:
  /// **'Failed to load certifications'**
  String get certifications_wallet_error_title;

  /// No description provided for @certifications_wallet_options_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get certifications_wallet_options_edit;

  /// No description provided for @certifications_wallet_options_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get certifications_wallet_options_share;

  /// No description provided for @certifications_wallet_options_viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get certifications_wallet_options_viewDetails;

  /// No description provided for @certifications_wallet_tooltip_add.
  ///
  /// In en, this message translates to:
  /// **'Add certification'**
  String get certifications_wallet_tooltip_add;

  /// No description provided for @certifications_wallet_tooltip_share.
  ///
  /// In en, this message translates to:
  /// **'Share certification'**
  String get certifications_wallet_tooltip_share;

  /// Back navigation tooltip
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get common_action_back;

  /// Generic cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_action_cancel;

  /// Generic close action used for dialogs, menus, etc.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get common_action_close;

  /// Generic delete action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get common_action_delete;

  /// Generic edit action
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get common_action_edit;

  /// Generic OK action
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get common_action_ok;

  /// Generic save action
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_action_save;

  /// Generic search action
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get common_action_search;

  /// Generic error label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get common_label_error;

  /// Generic loading indicator label
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get common_label_loading;

  /// Placeholder shown when a value is null or unavailable
  ///
  /// In en, this message translates to:
  /// **'--'**
  String get common_placeholder_noValue;

  /// No description provided for @courses_action_add.
  ///
  /// In en, this message translates to:
  /// **'Add Course'**
  String get courses_action_add;

  /// No description provided for @courses_action_create.
  ///
  /// In en, this message translates to:
  /// **'Create Course'**
  String get courses_action_create;

  /// No description provided for @courses_action_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit course'**
  String get courses_action_edit;

  /// No description provided for @courses_action_exportTrainingLog.
  ///
  /// In en, this message translates to:
  /// **'Export Training Log'**
  String get courses_action_exportTrainingLog;

  /// No description provided for @courses_action_markCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark as Completed'**
  String get courses_action_markCompleted;

  /// No description provided for @courses_action_moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get courses_action_moreOptions;

  /// No description provided for @courses_action_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get courses_action_retry;

  /// No description provided for @courses_action_saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get courses_action_saveChanges;

  /// No description provided for @courses_action_saveSemantic.
  ///
  /// In en, this message translates to:
  /// **'Save course'**
  String get courses_action_saveSemantic;

  /// No description provided for @courses_action_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get courses_action_sort;

  /// No description provided for @courses_action_sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort Courses'**
  String get courses_action_sortTitle;

  /// No description provided for @courses_card_instructor.
  ///
  /// In en, this message translates to:
  /// **'Instructor: {name}'**
  String courses_card_instructor(Object name);

  /// No description provided for @courses_card_started.
  ///
  /// In en, this message translates to:
  /// **'Started {date}'**
  String courses_card_started(Object date);

  /// No description provided for @courses_detail_certificationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Certification not found'**
  String get courses_detail_certificationNotFound;

  /// No description provided for @courses_detail_noTrainingDives.
  ///
  /// In en, this message translates to:
  /// **'No training dives linked yet'**
  String get courses_detail_noTrainingDives;

  /// No description provided for @courses_detail_notFound.
  ///
  /// In en, this message translates to:
  /// **'Course not found'**
  String get courses_detail_notFound;

  /// No description provided for @courses_dialog_complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get courses_dialog_complete;

  /// No description provided for @courses_dialog_deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}? This action cannot be undone.'**
  String courses_dialog_deleteMessage(Object name);

  /// No description provided for @courses_dialog_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Course?'**
  String get courses_dialog_deleteTitle;

  /// No description provided for @courses_dialog_markCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'This will mark the course as completed with today\'s date. Continue?'**
  String get courses_dialog_markCompletedMessage;

  /// No description provided for @courses_dialog_markCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as Completed?'**
  String get courses_dialog_markCompletedTitle;

  /// No description provided for @courses_empty_noCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed courses'**
  String get courses_empty_noCompleted;

  /// No description provided for @courses_empty_noInProgress.
  ///
  /// In en, this message translates to:
  /// **'No courses in progress'**
  String get courses_empty_noInProgress;

  /// No description provided for @courses_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first course to get started'**
  String get courses_empty_subtitle;

  /// No description provided for @courses_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No training courses yet'**
  String get courses_empty_title;

  /// No description provided for @courses_error_generic.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String courses_error_generic(Object error);

  /// No description provided for @courses_error_loadingCertification.
  ///
  /// In en, this message translates to:
  /// **'Error loading certification'**
  String get courses_error_loadingCertification;

  /// No description provided for @courses_error_loadingDives.
  ///
  /// In en, this message translates to:
  /// **'Error loading dives'**
  String get courses_error_loadingDives;

  /// No description provided for @courses_field_courseName.
  ///
  /// In en, this message translates to:
  /// **'Course Name'**
  String get courses_field_courseName;

  /// No description provided for @courses_field_courseNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Open Water Diver'**
  String get courses_field_courseNameHint;

  /// No description provided for @courses_field_instructorName.
  ///
  /// In en, this message translates to:
  /// **'Instructor Name'**
  String get courses_field_instructorName;

  /// No description provided for @courses_field_instructorNumber.
  ///
  /// In en, this message translates to:
  /// **'Instructor Number'**
  String get courses_field_instructorNumber;

  /// No description provided for @courses_field_linkCertificationHint.
  ///
  /// In en, this message translates to:
  /// **'Link a certification earned from this course'**
  String get courses_field_linkCertificationHint;

  /// No description provided for @courses_field_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get courses_field_location;

  /// No description provided for @courses_field_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get courses_field_notes;

  /// No description provided for @courses_field_selectFromBuddies.
  ///
  /// In en, this message translates to:
  /// **'Select from Buddies (Optional)'**
  String get courses_field_selectFromBuddies;

  /// No description provided for @courses_filter_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get courses_filter_all;

  /// No description provided for @courses_label_agency.
  ///
  /// In en, this message translates to:
  /// **'Agency'**
  String get courses_label_agency;

  /// No description provided for @courses_label_completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get courses_label_completed;

  /// No description provided for @courses_label_completionDate.
  ///
  /// In en, this message translates to:
  /// **'Completion Date'**
  String get courses_label_completionDate;

  /// No description provided for @courses_label_courseInProgress.
  ///
  /// In en, this message translates to:
  /// **'Course is in progress'**
  String get courses_label_courseInProgress;

  /// No description provided for @courses_label_instructorNumber.
  ///
  /// In en, this message translates to:
  /// **'Instructor #'**
  String get courses_label_instructorNumber;

  /// No description provided for @courses_label_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get courses_label_location;

  /// No description provided for @courses_label_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get courses_label_name;

  /// No description provided for @courses_label_none.
  ///
  /// In en, this message translates to:
  /// **'-- None --'**
  String get courses_label_none;

  /// No description provided for @courses_label_startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get courses_label_startDate;

  /// No description provided for @courses_message_errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving course: {error}'**
  String courses_message_errorSaving(Object error);

  /// No description provided for @courses_message_exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export training log: {error}'**
  String courses_message_exportFailed(Object error);

  /// No description provided for @courses_picker_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get courses_picker_active;

  /// No description provided for @courses_picker_clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get courses_picker_clearSelection;

  /// No description provided for @courses_picker_createCourse.
  ///
  /// In en, this message translates to:
  /// **'Create Course'**
  String get courses_picker_createCourse;

  /// No description provided for @courses_picker_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading courses: {error}'**
  String courses_picker_errorLoading(Object error);

  /// No description provided for @courses_picker_newCourse.
  ///
  /// In en, this message translates to:
  /// **'New Course'**
  String get courses_picker_newCourse;

  /// No description provided for @courses_picker_noCourses.
  ///
  /// In en, this message translates to:
  /// **'No courses yet'**
  String get courses_picker_noCourses;

  /// No description provided for @courses_picker_noneSelected.
  ///
  /// In en, this message translates to:
  /// **'No course selected'**
  String get courses_picker_noneSelected;

  /// No description provided for @courses_picker_selectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Training Course'**
  String get courses_picker_selectTitle;

  /// No description provided for @courses_picker_selected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get courses_picker_selected;

  /// No description provided for @courses_picker_tapToLink.
  ///
  /// In en, this message translates to:
  /// **'Tap to link to a training course'**
  String get courses_picker_tapToLink;

  /// No description provided for @courses_section_details.
  ///
  /// In en, this message translates to:
  /// **'Course Details'**
  String get courses_section_details;

  /// No description provided for @courses_section_earnedCertification.
  ///
  /// In en, this message translates to:
  /// **'Earned Certification'**
  String get courses_section_earnedCertification;

  /// No description provided for @courses_section_instructor.
  ///
  /// In en, this message translates to:
  /// **'Instructor'**
  String get courses_section_instructor;

  /// No description provided for @courses_section_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get courses_section_notes;

  /// No description provided for @courses_section_trainingDives.
  ///
  /// In en, this message translates to:
  /// **'Training Dives'**
  String get courses_section_trainingDives;

  /// No description provided for @courses_status_completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get courses_status_completed;

  /// No description provided for @courses_status_daysSinceStart.
  ///
  /// In en, this message translates to:
  /// **'{days} days since start'**
  String courses_status_daysSinceStart(Object days);

  /// No description provided for @courses_status_durationDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String courses_status_durationDays(Object days);

  /// No description provided for @courses_status_inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get courses_status_inProgress;

  /// No description provided for @courses_status_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{status}, {duration}'**
  String courses_status_semanticLabel(Object status, Object duration);

  /// No description provided for @courses_summary_overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get courses_summary_overview;

  /// No description provided for @courses_summary_quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get courses_summary_quickActions;

  /// No description provided for @courses_summary_recentCourses.
  ///
  /// In en, this message translates to:
  /// **'Recent Courses'**
  String get courses_summary_recentCourses;

  /// No description provided for @courses_summary_selectHint.
  ///
  /// In en, this message translates to:
  /// **'Select a course from the list to view details'**
  String get courses_summary_selectHint;

  /// No description provided for @courses_summary_title.
  ///
  /// In en, this message translates to:
  /// **'Training Courses'**
  String get courses_summary_title;

  /// No description provided for @courses_summary_total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get courses_summary_total;

  /// No description provided for @courses_title.
  ///
  /// In en, this message translates to:
  /// **'Training Courses'**
  String get courses_title;

  /// No description provided for @courses_title_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit Course'**
  String get courses_title_edit;

  /// No description provided for @courses_title_new.
  ///
  /// In en, this message translates to:
  /// **'New Course'**
  String get courses_title_new;

  /// No description provided for @courses_title_singular.
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get courses_title_singular;

  /// No description provided for @courses_validation_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a course name'**
  String get courses_validation_nameRequired;

  /// No description provided for @dashboard_activity_daySinceDiving.
  ///
  /// In en, this message translates to:
  /// **'Day since diving'**
  String get dashboard_activity_daySinceDiving;

  /// No description provided for @dashboard_activity_daysSinceDiving.
  ///
  /// In en, this message translates to:
  /// **'Days since diving'**
  String get dashboard_activity_daysSinceDiving;

  /// No description provided for @dashboard_activity_diveInYear.
  ///
  /// In en, this message translates to:
  /// **'Dive in {year}'**
  String dashboard_activity_diveInYear(Object year);

  /// No description provided for @dashboard_activity_diveThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Dive this month'**
  String get dashboard_activity_diveThisMonth;

  /// No description provided for @dashboard_activity_divesInYear.
  ///
  /// In en, this message translates to:
  /// **'Dives in {year}'**
  String dashboard_activity_divesInYear(Object year);

  /// No description provided for @dashboard_activity_divesThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Dives this month'**
  String get dashboard_activity_divesThisMonth;

  /// No description provided for @dashboard_activity_error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get dashboard_activity_error;

  /// No description provided for @dashboard_activity_lastDive.
  ///
  /// In en, this message translates to:
  /// **'Last dive'**
  String get dashboard_activity_lastDive;

  /// No description provided for @dashboard_activity_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get dashboard_activity_loading;

  /// No description provided for @dashboard_activity_noDivesYet.
  ///
  /// In en, this message translates to:
  /// **'No dives yet'**
  String get dashboard_activity_noDivesYet;

  /// No description provided for @dashboard_activity_today.
  ///
  /// In en, this message translates to:
  /// **'Today!'**
  String get dashboard_activity_today;

  /// No description provided for @dashboard_alerts_actionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get dashboard_alerts_actionUpdate;

  /// No description provided for @dashboard_alerts_actionView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get dashboard_alerts_actionView;

  /// No description provided for @dashboard_alerts_checkInsuranceExpiry.
  ///
  /// In en, this message translates to:
  /// **'Check your insurance expiry date'**
  String get dashboard_alerts_checkInsuranceExpiry;

  /// No description provided for @dashboard_alerts_daysOverdueOne.
  ///
  /// In en, this message translates to:
  /// **'1 day overdue'**
  String get dashboard_alerts_daysOverdueOne;

  /// No description provided for @dashboard_alerts_daysOverdueOther.
  ///
  /// In en, this message translates to:
  /// **'{count} days overdue'**
  String dashboard_alerts_daysOverdueOther(Object count);

  /// No description provided for @dashboard_alerts_dueInDaysOne.
  ///
  /// In en, this message translates to:
  /// **'Due in 1 day'**
  String get dashboard_alerts_dueInDaysOne;

  /// No description provided for @dashboard_alerts_dueInDaysOther.
  ///
  /// In en, this message translates to:
  /// **'Due in {count} days'**
  String dashboard_alerts_dueInDaysOther(Object count);

  /// No description provided for @dashboard_alerts_equipmentServiceDue.
  ///
  /// In en, this message translates to:
  /// **'{name} Service Due'**
  String dashboard_alerts_equipmentServiceDue(Object name);

  /// No description provided for @dashboard_alerts_equipmentServiceOverdue.
  ///
  /// In en, this message translates to:
  /// **'{name} Service Overdue'**
  String dashboard_alerts_equipmentServiceOverdue(Object name);

  /// No description provided for @dashboard_alerts_insuranceExpired.
  ///
  /// In en, this message translates to:
  /// **'Insurance Expired'**
  String get dashboard_alerts_insuranceExpired;

  /// No description provided for @dashboard_alerts_insuranceExpiredGeneric.
  ///
  /// In en, this message translates to:
  /// **'Your dive insurance has expired'**
  String get dashboard_alerts_insuranceExpiredGeneric;

  /// No description provided for @dashboard_alerts_insuranceExpiredProvider.
  ///
  /// In en, this message translates to:
  /// **'{provider} expired'**
  String dashboard_alerts_insuranceExpiredProvider(Object provider);

  /// No description provided for @dashboard_alerts_insuranceExpiresDate.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String dashboard_alerts_insuranceExpiresDate(Object date);

  /// No description provided for @dashboard_alerts_insuranceExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Insurance Expiring Soon'**
  String get dashboard_alerts_insuranceExpiringSoon;

  /// No description provided for @dashboard_alerts_sectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts & Reminders'**
  String get dashboard_alerts_sectionTitle;

  /// No description provided for @dashboard_alerts_serviceDueToday.
  ///
  /// In en, this message translates to:
  /// **'Service due today'**
  String get dashboard_alerts_serviceDueToday;

  /// No description provided for @dashboard_alerts_serviceIntervalReached.
  ///
  /// In en, this message translates to:
  /// **'Service interval reached'**
  String get dashboard_alerts_serviceIntervalReached;

  /// No description provided for @dashboard_defaultDiverName.
  ///
  /// In en, this message translates to:
  /// **'Diver'**
  String get dashboard_defaultDiverName;

  /// No description provided for @dashboard_greeting_afternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get dashboard_greeting_afternoon;

  /// No description provided for @dashboard_greeting_evening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get dashboard_greeting_evening;

  /// No description provided for @dashboard_greeting_morning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get dashboard_greeting_morning;

  /// No description provided for @dashboard_greeting_withName.
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name}!'**
  String dashboard_greeting_withName(Object greeting, Object name);

  /// No description provided for @dashboard_greeting_withoutName.
  ///
  /// In en, this message translates to:
  /// **'{greeting}!'**
  String dashboard_greeting_withoutName(Object greeting);

  /// No description provided for @dashboard_hero_divesLoggedOne.
  ///
  /// In en, this message translates to:
  /// **'1 dive logged'**
  String get dashboard_hero_divesLoggedOne;

  /// No description provided for @dashboard_hero_divesLoggedOther.
  ///
  /// In en, this message translates to:
  /// **'{count} dives logged'**
  String dashboard_hero_divesLoggedOther(Object count);

  /// No description provided for @dashboard_hero_error.
  ///
  /// In en, this message translates to:
  /// **'Ready to explore the depths?'**
  String get dashboard_hero_error;

  /// No description provided for @dashboard_hero_hoursUnderwater.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours underwater'**
  String dashboard_hero_hoursUnderwater(Object hours);

  /// No description provided for @dashboard_hero_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading your dive stats...'**
  String get dashboard_hero_loading;

  /// No description provided for @dashboard_hero_minutesUnderwater.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes underwater'**
  String dashboard_hero_minutesUnderwater(Object minutes);

  /// No description provided for @dashboard_hero_noDives.
  ///
  /// In en, this message translates to:
  /// **'Ready to log your first dive?'**
  String get dashboard_hero_noDives;

  /// No description provided for @dashboard_personalRecords_coldest.
  ///
  /// In en, this message translates to:
  /// **'Coldest'**
  String get dashboard_personalRecords_coldest;

  /// No description provided for @dashboard_personalRecords_deepest.
  ///
  /// In en, this message translates to:
  /// **'Deepest'**
  String get dashboard_personalRecords_deepest;

  /// No description provided for @dashboard_personalRecords_longest.
  ///
  /// In en, this message translates to:
  /// **'Longest'**
  String get dashboard_personalRecords_longest;

  /// No description provided for @dashboard_personalRecords_sectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Records'**
  String get dashboard_personalRecords_sectionTitle;

  /// No description provided for @dashboard_personalRecords_warmest.
  ///
  /// In en, this message translates to:
  /// **'Warmest'**
  String get dashboard_personalRecords_warmest;

  /// No description provided for @dashboard_quickActions_addSite.
  ///
  /// In en, this message translates to:
  /// **'Add Site'**
  String get dashboard_quickActions_addSite;

  /// No description provided for @dashboard_quickActions_addSiteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a new dive site'**
  String get dashboard_quickActions_addSiteTooltip;

  /// No description provided for @dashboard_quickActions_logDive.
  ///
  /// In en, this message translates to:
  /// **'Log Dive'**
  String get dashboard_quickActions_logDive;

  /// No description provided for @dashboard_quickActions_logDiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Log a new dive'**
  String get dashboard_quickActions_logDiveTooltip;

  /// No description provided for @dashboard_quickActions_planDive.
  ///
  /// In en, this message translates to:
  /// **'Plan Dive'**
  String get dashboard_quickActions_planDive;

  /// No description provided for @dashboard_quickActions_planDiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Plan a new dive'**
  String get dashboard_quickActions_planDiveTooltip;

  /// No description provided for @dashboard_quickActions_sectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get dashboard_quickActions_sectionTitle;

  /// No description provided for @dashboard_quickActions_statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get dashboard_quickActions_statistics;

  /// No description provided for @dashboard_quickActions_statisticsTooltip.
  ///
  /// In en, this message translates to:
  /// **'View dive statistics'**
  String get dashboard_quickActions_statisticsTooltip;

  /// No description provided for @dashboard_quickStats_countries.
  ///
  /// In en, this message translates to:
  /// **'Countries'**
  String get dashboard_quickStats_countries;

  /// No description provided for @dashboard_quickStats_countriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'visited'**
  String get dashboard_quickStats_countriesSubtitle;

  /// No description provided for @dashboard_quickStats_sectionTitle.
  ///
  /// In en, this message translates to:
  /// **'At a Glance'**
  String get dashboard_quickStats_sectionTitle;

  /// No description provided for @dashboard_quickStats_species.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get dashboard_quickStats_species;

  /// No description provided for @dashboard_quickStats_speciesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'discovered'**
  String get dashboard_quickStats_speciesSubtitle;

  /// No description provided for @dashboard_quickStats_topBuddy.
  ///
  /// In en, this message translates to:
  /// **'Top Buddy'**
  String get dashboard_quickStats_topBuddy;

  /// No description provided for @dashboard_quickStats_topBuddyDives.
  ///
  /// In en, this message translates to:
  /// **'{count} dives'**
  String dashboard_quickStats_topBuddyDives(Object count);

  /// No description provided for @dashboard_recentDives_empty.
  ///
  /// In en, this message translates to:
  /// **'No dives logged yet'**
  String get dashboard_recentDives_empty;

  /// No description provided for @dashboard_recentDives_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Failed to load dives'**
  String get dashboard_recentDives_errorLoading;

  /// No description provided for @dashboard_recentDives_logFirst.
  ///
  /// In en, this message translates to:
  /// **'Log Your First Dive'**
  String get dashboard_recentDives_logFirst;

  /// No description provided for @dashboard_recentDives_sectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Dives'**
  String get dashboard_recentDives_sectionTitle;

  /// No description provided for @dashboard_recentDives_viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get dashboard_recentDives_viewAll;

  /// No description provided for @dashboard_recentDives_viewAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'View all dives'**
  String get dashboard_recentDives_viewAllTooltip;

  /// No description provided for @dashboard_semantics_activeAlerts.
  ///
  /// In en, this message translates to:
  /// **'{count} active alerts'**
  String dashboard_semantics_activeAlerts(Object count);

  /// No description provided for @dashboard_semantics_errorLoadingRecentDives.
  ///
  /// In en, this message translates to:
  /// **'Error: Failed to load recent dives'**
  String get dashboard_semantics_errorLoadingRecentDives;

  /// No description provided for @dashboard_semantics_errorLoadingStatistics.
  ///
  /// In en, this message translates to:
  /// **'Error: Failed to load statistics'**
  String get dashboard_semantics_errorLoadingStatistics;

  /// No description provided for @dashboard_semantics_greetingBanner.
  ///
  /// In en, this message translates to:
  /// **'Dashboard greeting banner'**
  String get dashboard_semantics_greetingBanner;

  /// No description provided for @dashboard_stats_errorLoadingStatistics.
  ///
  /// In en, this message translates to:
  /// **'Failed to load statistics'**
  String get dashboard_stats_errorLoadingStatistics;

  /// No description provided for @dashboard_stats_hoursLogged.
  ///
  /// In en, this message translates to:
  /// **'Hours Logged'**
  String get dashboard_stats_hoursLogged;

  /// No description provided for @dashboard_stats_maxDepth.
  ///
  /// In en, this message translates to:
  /// **'Max Depth'**
  String get dashboard_stats_maxDepth;

  /// No description provided for @dashboard_stats_sitesVisited.
  ///
  /// In en, this message translates to:
  /// **'Sites Visited'**
  String get dashboard_stats_sitesVisited;

  /// No description provided for @dashboard_stats_totalDives.
  ///
  /// In en, this message translates to:
  /// **'Total Dives'**
  String get dashboard_stats_totalDives;

  /// No description provided for @decoCalculator_addToPlanner.
  ///
  /// In en, this message translates to:
  /// **'Add to Planner'**
  String get decoCalculator_addToPlanner;

  /// No description provided for @decoCalculator_bottomTimeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Bottom time: {time} minutes'**
  String decoCalculator_bottomTimeSemantics(Object time);

  /// No description provided for @decoCalculator_createPlanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create a dive plan from current parameters'**
  String get decoCalculator_createPlanTooltip;

  /// No description provided for @decoCalculator_createdPlanSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Created plan: {depth}{depthSymbol} for {time}min on {gasMixName}'**
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  );

  /// No description provided for @decoCalculator_customMixTrimix.
  ///
  /// In en, this message translates to:
  /// **'Custom Mix (Trimix)'**
  String get decoCalculator_customMixTrimix;

  /// No description provided for @decoCalculator_depthSemantics.
  ///
  /// In en, this message translates to:
  /// **'Depth: {depth} {depthSymbol}'**
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol);

  /// No description provided for @decoCalculator_diveParameters.
  ///
  /// In en, this message translates to:
  /// **'Dive Parameters'**
  String get decoCalculator_diveParameters;

  /// No description provided for @decoCalculator_endCaution.
  ///
  /// In en, this message translates to:
  /// **'Caution'**
  String get decoCalculator_endCaution;

  /// No description provided for @decoCalculator_endDanger.
  ///
  /// In en, this message translates to:
  /// **'Danger'**
  String get decoCalculator_endDanger;

  /// No description provided for @decoCalculator_endSafe.
  ///
  /// In en, this message translates to:
  /// **'Safe'**
  String get decoCalculator_endSafe;

  /// No description provided for @decoCalculator_field_bottomTime.
  ///
  /// In en, this message translates to:
  /// **'Bottom Time'**
  String get decoCalculator_field_bottomTime;

  /// No description provided for @decoCalculator_field_depth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get decoCalculator_field_depth;

  /// No description provided for @decoCalculator_field_gasMix.
  ///
  /// In en, this message translates to:
  /// **'Gas Mix'**
  String get decoCalculator_field_gasMix;

  /// No description provided for @decoCalculator_gasSafety.
  ///
  /// In en, this message translates to:
  /// **'Gas Safety'**
  String get decoCalculator_gasSafety;

  /// No description provided for @decoCalculator_hideCustomMix.
  ///
  /// In en, this message translates to:
  /// **'Hide Custom Mix'**
  String get decoCalculator_hideCustomMix;

  /// No description provided for @decoCalculator_hideCustomMixSemantics.
  ///
  /// In en, this message translates to:
  /// **'Hide custom gas mix selector'**
  String get decoCalculator_hideCustomMixSemantics;

  /// No description provided for @decoCalculator_modExceeded.
  ///
  /// In en, this message translates to:
  /// **'MOD Exceeded'**
  String get decoCalculator_modExceeded;

  /// No description provided for @decoCalculator_modSafe.
  ///
  /// In en, this message translates to:
  /// **'MOD Safe'**
  String get decoCalculator_modSafe;

  /// No description provided for @decoCalculator_ppO2Caution.
  ///
  /// In en, this message translates to:
  /// **'ppO2 Caution'**
  String get decoCalculator_ppO2Caution;

  /// No description provided for @decoCalculator_ppO2Danger.
  ///
  /// In en, this message translates to:
  /// **'ppO2 Danger'**
  String get decoCalculator_ppO2Danger;

  /// No description provided for @decoCalculator_ppO2Hypoxic.
  ///
  /// In en, this message translates to:
  /// **'ppO2 Hypoxic'**
  String get decoCalculator_ppO2Hypoxic;

  /// No description provided for @decoCalculator_ppO2Safe.
  ///
  /// In en, this message translates to:
  /// **'ppO2 Safe'**
  String get decoCalculator_ppO2Safe;

  /// No description provided for @decoCalculator_resetToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get decoCalculator_resetToDefaults;

  /// No description provided for @decoCalculator_showCustomMixSemantics.
  ///
  /// In en, this message translates to:
  /// **'Show custom gas mix selector'**
  String get decoCalculator_showCustomMixSemantics;

  /// No description provided for @decoCalculator_timeValueMin.
  ///
  /// In en, this message translates to:
  /// **'{time} min'**
  String decoCalculator_timeValueMin(Object time);

  /// No description provided for @decoCalculator_title.
  ///
  /// In en, this message translates to:
  /// **'Deco Calculator'**
  String get decoCalculator_title;

  /// No description provided for @diveCenters_accessibility_markerLabel.
  ///
  /// In en, this message translates to:
  /// **'Dive center: {name}'**
  String diveCenters_accessibility_markerLabel(Object name);

  /// No description provided for @diveCenters_accessibility_selected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get diveCenters_accessibility_selected;

  /// No description provided for @diveCenters_accessibility_viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details for {name}'**
  String diveCenters_accessibility_viewDetails(Object name);

  /// No description provided for @diveCenters_accessibility_viewDives.
  ///
  /// In en, this message translates to:
  /// **'View dives with this center'**
  String get diveCenters_accessibility_viewDives;

  /// No description provided for @diveCenters_accessibility_viewFullscreenMap.
  ///
  /// In en, this message translates to:
  /// **'View fullscreen map'**
  String get diveCenters_accessibility_viewFullscreenMap;

  /// No description provided for @diveCenters_accessibility_viewSavedCenter.
  ///
  /// In en, this message translates to:
  /// **'View saved dive center {name}'**
  String diveCenters_accessibility_viewSavedCenter(Object name);

  /// No description provided for @diveCenters_action_addCenter.
  ///
  /// In en, this message translates to:
  /// **'Add Center'**
  String get diveCenters_action_addCenter;

  /// No description provided for @diveCenters_action_addNew.
  ///
  /// In en, this message translates to:
  /// **'Add New'**
  String get diveCenters_action_addNew;

  /// No description provided for @diveCenters_action_clearRating.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get diveCenters_action_clearRating;

  /// No description provided for @diveCenters_action_gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting...'**
  String get diveCenters_action_gettingLocation;

  /// No description provided for @diveCenters_action_import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get diveCenters_action_import;

  /// No description provided for @diveCenters_action_importToMyCenters.
  ///
  /// In en, this message translates to:
  /// **'Import to My Centers'**
  String get diveCenters_action_importToMyCenters;

  /// No description provided for @diveCenters_action_lookingUp.
  ///
  /// In en, this message translates to:
  /// **'Looking up...'**
  String get diveCenters_action_lookingUp;

  /// No description provided for @diveCenters_action_lookupFromAddress.
  ///
  /// In en, this message translates to:
  /// **'Lookup from Address'**
  String get diveCenters_action_lookupFromAddress;

  /// No description provided for @diveCenters_action_pickFromMap.
  ///
  /// In en, this message translates to:
  /// **'Pick from Map'**
  String get diveCenters_action_pickFromMap;

  /// No description provided for @diveCenters_action_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get diveCenters_action_retry;

  /// No description provided for @diveCenters_action_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get diveCenters_action_settings;

  /// No description provided for @diveCenters_action_useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use My Location'**
  String get diveCenters_action_useMyLocation;

  /// No description provided for @diveCenters_action_view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get diveCenters_action_view;

  /// No description provided for @diveCenters_detail_divesLogged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dive logged} other{{count} dives logged}}'**
  String diveCenters_detail_divesLogged(int count);

  /// No description provided for @diveCenters_detail_divesWithCenter.
  ///
  /// In en, this message translates to:
  /// **'Dives with this Center'**
  String get diveCenters_detail_divesWithCenter;

  /// No description provided for @diveCenters_detail_noDivesLogged.
  ///
  /// In en, this message translates to:
  /// **'No dives logged yet'**
  String get diveCenters_detail_noDivesLogged;

  /// No description provided for @diveCenters_dialog_deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String diveCenters_dialog_deleteMessage(Object name);

  /// No description provided for @diveCenters_dialog_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Dive Center'**
  String get diveCenters_dialog_deleteTitle;

  /// No description provided for @diveCenters_dialog_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get diveCenters_dialog_discard;

  /// No description provided for @diveCenters_dialog_discardMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to discard them?'**
  String get diveCenters_dialog_discardMessage;

  /// No description provided for @diveCenters_dialog_discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes?'**
  String get diveCenters_dialog_discardTitle;

  /// No description provided for @diveCenters_dialog_keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get diveCenters_dialog_keepEditing;

  /// No description provided for @diveCenters_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your favorite dive shops and operators'**
  String get diveCenters_empty_subtitle;

  /// No description provided for @diveCenters_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No dive centers yet'**
  String get diveCenters_empty_title;

  /// No description provided for @diveCenters_error_generic.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String diveCenters_error_generic(Object error);

  /// No description provided for @diveCenters_error_geocodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not find coordinates for this address'**
  String get diveCenters_error_geocodeFailed;

  /// No description provided for @diveCenters_error_importFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import dive center'**
  String get diveCenters_error_importFailed;

  /// No description provided for @diveCenters_error_loading.
  ///
  /// In en, this message translates to:
  /// **'Error loading dive centers: {error}'**
  String diveCenters_error_loading(Object error);

  /// No description provided for @diveCenters_error_locationPermission.
  ///
  /// In en, this message translates to:
  /// **'Unable to get location. Please check permissions.'**
  String get diveCenters_error_locationPermission;

  /// No description provided for @diveCenters_error_locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to get location. Location services may not be available.'**
  String get diveCenters_error_locationUnavailable;

  /// No description provided for @diveCenters_error_noAddressForLookup.
  ///
  /// In en, this message translates to:
  /// **'Please enter an address to look up coordinates'**
  String get diveCenters_error_noAddressForLookup;

  /// No description provided for @diveCenters_error_notFound.
  ///
  /// In en, this message translates to:
  /// **'Dive center not found'**
  String get diveCenters_error_notFound;

  /// No description provided for @diveCenters_error_saving.
  ///
  /// In en, this message translates to:
  /// **'Error saving dive center: {error}'**
  String diveCenters_error_saving(Object error);

  /// No description provided for @diveCenters_error_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get diveCenters_error_unknown;

  /// No description provided for @diveCenters_field_city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get diveCenters_field_city;

  /// No description provided for @diveCenters_field_country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get diveCenters_field_country;

  /// No description provided for @diveCenters_field_latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get diveCenters_field_latitude;

  /// No description provided for @diveCenters_field_longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get diveCenters_field_longitude;

  /// No description provided for @diveCenters_field_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get diveCenters_field_nameRequired;

  /// No description provided for @diveCenters_field_postalCode.
  ///
  /// In en, this message translates to:
  /// **'Postal Code'**
  String get diveCenters_field_postalCode;

  /// No description provided for @diveCenters_field_rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get diveCenters_field_rating;

  /// No description provided for @diveCenters_field_stateProvince.
  ///
  /// In en, this message translates to:
  /// **'State/Province'**
  String get diveCenters_field_stateProvince;

  /// No description provided for @diveCenters_field_street.
  ///
  /// In en, this message translates to:
  /// **'Street Address'**
  String get diveCenters_field_street;

  /// No description provided for @diveCenters_hint_addressDescription.
  ///
  /// In en, this message translates to:
  /// **'Optional street address for navigation'**
  String get diveCenters_hint_addressDescription;

  /// No description provided for @diveCenters_hint_affiliationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Select training agencies this center is affiliated with'**
  String get diveCenters_hint_affiliationsDescription;

  /// No description provided for @diveCenters_hint_city.
  ///
  /// In en, this message translates to:
  /// **'e.g., Phuket'**
  String get diveCenters_hint_city;

  /// No description provided for @diveCenters_hint_country.
  ///
  /// In en, this message translates to:
  /// **'e.g., Thailand'**
  String get diveCenters_hint_country;

  /// No description provided for @diveCenters_hint_email.
  ///
  /// In en, this message translates to:
  /// **'info@divecenter.com'**
  String get diveCenters_hint_email;

  /// No description provided for @diveCenters_hint_gpsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a location method or enter coordinates manually'**
  String get diveCenters_hint_gpsDescription;

  /// No description provided for @diveCenters_hint_importSearch.
  ///
  /// In en, this message translates to:
  /// **'Search dive centers (e.g., \"PADI\", \"Thailand\")'**
  String get diveCenters_hint_importSearch;

  /// No description provided for @diveCenters_hint_latitude.
  ///
  /// In en, this message translates to:
  /// **'e.g., 10.4613'**
  String get diveCenters_hint_latitude;

  /// No description provided for @diveCenters_hint_longitude.
  ///
  /// In en, this message translates to:
  /// **'e.g., 99.8359'**
  String get diveCenters_hint_longitude;

  /// No description provided for @diveCenters_hint_name.
  ///
  /// In en, this message translates to:
  /// **'Enter dive center name'**
  String get diveCenters_hint_name;

  /// No description provided for @diveCenters_hint_notes.
  ///
  /// In en, this message translates to:
  /// **'Any additional information...'**
  String get diveCenters_hint_notes;

  /// No description provided for @diveCenters_hint_phone.
  ///
  /// In en, this message translates to:
  /// **'+1 234 567 890'**
  String get diveCenters_hint_phone;

  /// No description provided for @diveCenters_hint_postalCode.
  ///
  /// In en, this message translates to:
  /// **'e.g., 83100'**
  String get diveCenters_hint_postalCode;

  /// No description provided for @diveCenters_hint_stateProvince.
  ///
  /// In en, this message translates to:
  /// **'e.g., Phuket'**
  String get diveCenters_hint_stateProvince;

  /// No description provided for @diveCenters_hint_street.
  ///
  /// In en, this message translates to:
  /// **'e.g., 123 Beach Road'**
  String get diveCenters_hint_street;

  /// No description provided for @diveCenters_hint_website.
  ///
  /// In en, this message translates to:
  /// **'www.divecenter.com'**
  String get diveCenters_hint_website;

  /// No description provided for @diveCenters_import_fromDatabase.
  ///
  /// In en, this message translates to:
  /// **'Import from Database ({count})'**
  String diveCenters_import_fromDatabase(Object count);

  /// No description provided for @diveCenters_import_myCenters.
  ///
  /// In en, this message translates to:
  /// **'My Centers ({count})'**
  String diveCenters_import_myCenters(Object count);

  /// No description provided for @diveCenters_import_noResults.
  ///
  /// In en, this message translates to:
  /// **'No Results'**
  String get diveCenters_import_noResults;

  /// No description provided for @diveCenters_import_noResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'No dive centers found for \"{query}\". Try a different search term.'**
  String diveCenters_import_noResultsMessage(Object query);

  /// No description provided for @diveCenters_import_searchDescription.
  ///
  /// In en, this message translates to:
  /// **'Search for dive centers, shops, and clubs from our database of operators around the world.'**
  String get diveCenters_import_searchDescription;

  /// No description provided for @diveCenters_import_searchError.
  ///
  /// In en, this message translates to:
  /// **'Search Error'**
  String get diveCenters_import_searchError;

  /// No description provided for @diveCenters_import_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Try searching by name, country, or certification agency.'**
  String get diveCenters_import_searchHint;

  /// No description provided for @diveCenters_import_searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Dive Centers'**
  String get diveCenters_import_searchTitle;

  /// No description provided for @diveCenters_label_alreadyImported.
  ///
  /// In en, this message translates to:
  /// **'Already Imported'**
  String get diveCenters_label_alreadyImported;

  /// No description provided for @diveCenters_label_diveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dive} other{{count} dives}}'**
  String diveCenters_label_diveCount(int count);

  /// No description provided for @diveCenters_label_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get diveCenters_label_email;

  /// No description provided for @diveCenters_label_imported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get diveCenters_label_imported;

  /// No description provided for @diveCenters_label_locationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Location not set'**
  String get diveCenters_label_locationNotSet;

  /// No description provided for @diveCenters_label_locationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Location unknown'**
  String get diveCenters_label_locationUnknown;

  /// No description provided for @diveCenters_label_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get diveCenters_label_phone;

  /// No description provided for @diveCenters_label_saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get diveCenters_label_saved;

  /// No description provided for @diveCenters_label_source.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String diveCenters_label_source(Object source);

  /// No description provided for @diveCenters_label_website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get diveCenters_label_website;

  /// No description provided for @diveCenters_map_addCoordinatesHint.
  ///
  /// In en, this message translates to:
  /// **'Add coordinates to your dive centers to see them on the map'**
  String get diveCenters_map_addCoordinatesHint;

  /// No description provided for @diveCenters_map_noCoordinates.
  ///
  /// In en, this message translates to:
  /// **'No dive centers with coordinates'**
  String get diveCenters_map_noCoordinates;

  /// No description provided for @diveCenters_picker_newCenter.
  ///
  /// In en, this message translates to:
  /// **'New Dive Center'**
  String get diveCenters_picker_newCenter;

  /// No description provided for @diveCenters_picker_title.
  ///
  /// In en, this message translates to:
  /// **'Select Dive Center'**
  String get diveCenters_picker_title;

  /// No description provided for @diveCenters_search_noResults.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String diveCenters_search_noResults(Object query);

  /// No description provided for @diveCenters_search_prompt.
  ///
  /// In en, this message translates to:
  /// **'Search dive centers'**
  String get diveCenters_search_prompt;

  /// No description provided for @diveCenters_section_address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get diveCenters_section_address;

  /// No description provided for @diveCenters_section_affiliations.
  ///
  /// In en, this message translates to:
  /// **'Affiliations'**
  String get diveCenters_section_affiliations;

  /// No description provided for @diveCenters_section_basicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get diveCenters_section_basicInfo;

  /// No description provided for @diveCenters_section_contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get diveCenters_section_contact;

  /// No description provided for @diveCenters_section_contactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get diveCenters_section_contactInfo;

  /// No description provided for @diveCenters_section_gpsCoordinates.
  ///
  /// In en, this message translates to:
  /// **'GPS Coordinates'**
  String get diveCenters_section_gpsCoordinates;

  /// No description provided for @diveCenters_section_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get diveCenters_section_notes;

  /// No description provided for @diveCenters_snackbar_coordinatesFound.
  ///
  /// In en, this message translates to:
  /// **'Coordinates found from address'**
  String get diveCenters_snackbar_coordinatesFound;

  /// No description provided for @diveCenters_snackbar_copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get diveCenters_snackbar_copiedToClipboard;

  /// No description provided for @diveCenters_snackbar_imported.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{name}\"'**
  String diveCenters_snackbar_imported(Object name);

  /// No description provided for @diveCenters_snackbar_locationCaptured.
  ///
  /// In en, this message translates to:
  /// **'Location captured'**
  String get diveCenters_snackbar_locationCaptured;

  /// No description provided for @diveCenters_snackbar_locationCapturedWithAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Location captured (±{accuracy}m)'**
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy);

  /// No description provided for @diveCenters_snackbar_locationSelectedFromMap.
  ///
  /// In en, this message translates to:
  /// **'Location selected from map'**
  String get diveCenters_snackbar_locationSelectedFromMap;

  /// No description provided for @diveCenters_sort_title.
  ///
  /// In en, this message translates to:
  /// **'Sort Dive Centers'**
  String get diveCenters_sort_title;

  /// No description provided for @diveCenters_summary_countries.
  ///
  /// In en, this message translates to:
  /// **'Countries'**
  String get diveCenters_summary_countries;

  /// No description provided for @diveCenters_summary_highestRating.
  ///
  /// In en, this message translates to:
  /// **'Highest Rating'**
  String get diveCenters_summary_highestRating;

  /// No description provided for @diveCenters_summary_overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get diveCenters_summary_overview;

  /// No description provided for @diveCenters_summary_quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get diveCenters_summary_quickActions;

  /// No description provided for @diveCenters_summary_recentCenters.
  ///
  /// In en, this message translates to:
  /// **'Recent Dive Centers'**
  String get diveCenters_summary_recentCenters;

  /// No description provided for @diveCenters_summary_selectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a dive center from the list to view details'**
  String get diveCenters_summary_selectPrompt;

  /// No description provided for @diveCenters_summary_topRated.
  ///
  /// In en, this message translates to:
  /// **'Top Rated'**
  String get diveCenters_summary_topRated;

  /// No description provided for @diveCenters_summary_totalCenters.
  ///
  /// In en, this message translates to:
  /// **'Total Centers'**
  String get diveCenters_summary_totalCenters;

  /// No description provided for @diveCenters_summary_withGps.
  ///
  /// In en, this message translates to:
  /// **'With GPS'**
  String get diveCenters_summary_withGps;

  /// No description provided for @diveCenters_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Centers'**
  String get diveCenters_title;

  /// No description provided for @diveCenters_title_add.
  ///
  /// In en, this message translates to:
  /// **'Add Dive Center'**
  String get diveCenters_title_add;

  /// No description provided for @diveCenters_title_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit Dive Center'**
  String get diveCenters_title_edit;

  /// No description provided for @diveCenters_title_import.
  ///
  /// In en, this message translates to:
  /// **'Import Dive Center'**
  String get diveCenters_title_import;

  /// No description provided for @diveCenters_tooltip_addNew.
  ///
  /// In en, this message translates to:
  /// **'Add a new dive center'**
  String get diveCenters_tooltip_addNew;

  /// No description provided for @diveCenters_tooltip_clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get diveCenters_tooltip_clearSearch;

  /// No description provided for @diveCenters_tooltip_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit dive center'**
  String get diveCenters_tooltip_edit;

  /// No description provided for @diveCenters_tooltip_fitAllCenters.
  ///
  /// In en, this message translates to:
  /// **'Fit All Centers'**
  String get diveCenters_tooltip_fitAllCenters;

  /// No description provided for @diveCenters_tooltip_listView.
  ///
  /// In en, this message translates to:
  /// **'List View'**
  String get diveCenters_tooltip_listView;

  /// No description provided for @diveCenters_tooltip_mapView.
  ///
  /// In en, this message translates to:
  /// **'Map View'**
  String get diveCenters_tooltip_mapView;

  /// No description provided for @diveCenters_tooltip_moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get diveCenters_tooltip_moreOptions;

  /// No description provided for @diveCenters_tooltip_search.
  ///
  /// In en, this message translates to:
  /// **'Search dive centers'**
  String get diveCenters_tooltip_search;

  /// No description provided for @diveCenters_tooltip_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get diveCenters_tooltip_sort;

  /// No description provided for @diveCenters_validation_invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get diveCenters_validation_invalidEmail;

  /// No description provided for @diveCenters_validation_invalidLatitude.
  ///
  /// In en, this message translates to:
  /// **'Invalid latitude'**
  String get diveCenters_validation_invalidLatitude;

  /// No description provided for @diveCenters_validation_invalidLongitude.
  ///
  /// In en, this message translates to:
  /// **'Invalid longitude'**
  String get diveCenters_validation_invalidLongitude;

  /// No description provided for @diveCenters_validation_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get diveCenters_validation_nameRequired;

  /// No description provided for @diveComputer_action_setFavorite.
  ///
  /// In en, this message translates to:
  /// **'Set as favorite'**
  String get diveComputer_action_setFavorite;

  /// No description provided for @diveComputer_error_generic.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String diveComputer_error_generic(Object error);

  /// No description provided for @diveComputer_error_notFound.
  ///
  /// In en, this message translates to:
  /// **'Device not found'**
  String get diveComputer_error_notFound;

  /// No description provided for @diveComputer_status_favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite computer'**
  String get diveComputer_status_favorite;

  /// No description provided for @diveComputer_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Computer'**
  String get diveComputer_title;

  /// No description provided for @diveLog_bulkDelete_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} {count, plural, =1{dive} other{dives}}? This action cannot be undone.'**
  String diveLog_bulkDelete_confirm(int count);

  /// No description provided for @diveLog_bulkDelete_restored.
  ///
  /// In en, this message translates to:
  /// **'Dives restored'**
  String get diveLog_bulkDelete_restored;

  /// No description provided for @diveLog_bulkDelete_snackbar.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} {count, plural, =1{dive} other{dives}}'**
  String diveLog_bulkDelete_snackbar(int count);

  /// No description provided for @diveLog_bulkDelete_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Dives'**
  String get diveLog_bulkDelete_title;

  /// No description provided for @diveLog_bulkDelete_undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get diveLog_bulkDelete_undo;

  /// No description provided for @diveLog_bulkEdit_addTags.
  ///
  /// In en, this message translates to:
  /// **'Add Tags'**
  String get diveLog_bulkEdit_addTags;

  /// No description provided for @diveLog_bulkEdit_addTagsDescription.
  ///
  /// In en, this message translates to:
  /// **'Add tags to selected dives'**
  String get diveLog_bulkEdit_addTagsDescription;

  /// No description provided for @diveLog_bulkEdit_addedTags.
  ///
  /// In en, this message translates to:
  /// **'Added {tagCount} {tagCount, plural, =1{tag} other{tags}} to {diveCount} {diveCount, plural, =1{dive} other{dives}}'**
  String diveLog_bulkEdit_addedTags(int tagCount, int diveCount);

  /// No description provided for @diveLog_bulkEdit_changeTrip.
  ///
  /// In en, this message translates to:
  /// **'Change Trip'**
  String get diveLog_bulkEdit_changeTrip;

  /// No description provided for @diveLog_bulkEdit_changeTripDescription.
  ///
  /// In en, this message translates to:
  /// **'Move selected dives to a trip'**
  String get diveLog_bulkEdit_changeTripDescription;

  /// No description provided for @diveLog_bulkEdit_errorLoadingTrips.
  ///
  /// In en, this message translates to:
  /// **'Error loading trips'**
  String get diveLog_bulkEdit_errorLoadingTrips;

  /// No description provided for @diveLog_bulkEdit_failedAddTags.
  ///
  /// In en, this message translates to:
  /// **'Failed to add tags: {error}'**
  String diveLog_bulkEdit_failedAddTags(Object error);

  /// No description provided for @diveLog_bulkEdit_failedUpdateTrip.
  ///
  /// In en, this message translates to:
  /// **'Failed to update trip: {error}'**
  String diveLog_bulkEdit_failedUpdateTrip(Object error);

  /// No description provided for @diveLog_bulkEdit_movedToTrip.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} {count, plural, =1{dive} other{dives}} to trip'**
  String diveLog_bulkEdit_movedToTrip(int count);

  /// No description provided for @diveLog_bulkEdit_noTagsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No tags available.'**
  String get diveLog_bulkEdit_noTagsAvailable;

  /// No description provided for @diveLog_bulkEdit_noTagsAvailableCreate.
  ///
  /// In en, this message translates to:
  /// **'No tags available. Create tags first.'**
  String get diveLog_bulkEdit_noTagsAvailableCreate;

  /// No description provided for @diveLog_bulkEdit_noTrip.
  ///
  /// In en, this message translates to:
  /// **'No Trip'**
  String get diveLog_bulkEdit_noTrip;

  /// No description provided for @diveLog_bulkEdit_removeFromTrip.
  ///
  /// In en, this message translates to:
  /// **'Remove from trip'**
  String get diveLog_bulkEdit_removeFromTrip;

  /// No description provided for @diveLog_bulkEdit_removeTags.
  ///
  /// In en, this message translates to:
  /// **'Remove Tags'**
  String get diveLog_bulkEdit_removeTags;

  /// No description provided for @diveLog_bulkEdit_removeTagsDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove tags from selected dives'**
  String get diveLog_bulkEdit_removeTagsDescription;

  /// No description provided for @diveLog_bulkEdit_removedFromTrip.
  ///
  /// In en, this message translates to:
  /// **'Removed {count} {count, plural, =1{dive} other{dives}} from trip'**
  String diveLog_bulkEdit_removedFromTrip(int count);

  /// No description provided for @diveLog_bulkEdit_selectTrip.
  ///
  /// In en, this message translates to:
  /// **'Select Trip'**
  String get diveLog_bulkEdit_selectTrip;

  /// No description provided for @diveLog_bulkEdit_title.
  ///
  /// In en, this message translates to:
  /// **'Edit {count} {count, plural, =1{Dive} other{Dives}}'**
  String diveLog_bulkEdit_title(int count);

  /// No description provided for @diveLog_bulkExport_csv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get diveLog_bulkExport_csv;

  /// No description provided for @diveLog_bulkExport_csvDescription.
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet format'**
  String get diveLog_bulkExport_csvDescription;

  /// No description provided for @diveLog_bulkExport_failed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String diveLog_bulkExport_failed(Object error);

  /// No description provided for @diveLog_bulkExport_pdf.
  ///
  /// In en, this message translates to:
  /// **'PDF Logbook'**
  String get diveLog_bulkExport_pdf;

  /// No description provided for @diveLog_bulkExport_pdfDescription.
  ///
  /// In en, this message translates to:
  /// **'Printable dive log pages'**
  String get diveLog_bulkExport_pdfDescription;

  /// No description provided for @diveLog_bulkExport_success.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} {count, plural, =1{dive} other{dives}} successfully'**
  String diveLog_bulkExport_success(int count);

  /// No description provided for @diveLog_bulkExport_title.
  ///
  /// In en, this message translates to:
  /// **'Export {count} {count, plural, =1{Dive} other{Dives}}'**
  String diveLog_bulkExport_title(int count);

  /// No description provided for @diveLog_bulkExport_uddf.
  ///
  /// In en, this message translates to:
  /// **'UDDF'**
  String get diveLog_bulkExport_uddf;

  /// No description provided for @diveLog_bulkExport_uddfDescription.
  ///
  /// In en, this message translates to:
  /// **'Universal Dive Data Format'**
  String get diveLog_bulkExport_uddfDescription;

  /// No description provided for @diveLog_ccr_diluent_air.
  ///
  /// In en, this message translates to:
  /// **'Air'**
  String get diveLog_ccr_diluent_air;

  /// No description provided for @diveLog_ccr_hint_loopVolume.
  ///
  /// In en, this message translates to:
  /// **'e.g., 6.0'**
  String get diveLog_ccr_hint_loopVolume;

  /// No description provided for @diveLog_ccr_hint_type.
  ///
  /// In en, this message translates to:
  /// **'e.g., Sofnolime'**
  String get diveLog_ccr_hint_type;

  /// No description provided for @diveLog_ccr_label_deco.
  ///
  /// In en, this message translates to:
  /// **'Deco'**
  String get diveLog_ccr_label_deco;

  /// No description provided for @diveLog_ccr_label_he.
  ///
  /// In en, this message translates to:
  /// **'He'**
  String get diveLog_ccr_label_he;

  /// No description provided for @diveLog_ccr_label_highBottom.
  ///
  /// In en, this message translates to:
  /// **'High (Bottom)'**
  String get diveLog_ccr_label_highBottom;

  /// No description provided for @diveLog_ccr_label_loopVolume.
  ///
  /// In en, this message translates to:
  /// **'Loop Volume'**
  String get diveLog_ccr_label_loopVolume;

  /// No description provided for @diveLog_ccr_label_lowDescAsc.
  ///
  /// In en, this message translates to:
  /// **'Low (Desc/Asc)'**
  String get diveLog_ccr_label_lowDescAsc;

  /// No description provided for @diveLog_ccr_label_n2.
  ///
  /// In en, this message translates to:
  /// **'N₂'**
  String get diveLog_ccr_label_n2;

  /// No description provided for @diveLog_ccr_label_o2.
  ///
  /// In en, this message translates to:
  /// **'O₂'**
  String get diveLog_ccr_label_o2;

  /// No description provided for @diveLog_ccr_label_rated.
  ///
  /// In en, this message translates to:
  /// **'Rated'**
  String get diveLog_ccr_label_rated;

  /// No description provided for @diveLog_ccr_label_remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get diveLog_ccr_label_remaining;

  /// No description provided for @diveLog_ccr_label_type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get diveLog_ccr_label_type;

  /// No description provided for @diveLog_ccr_sectionDiluentGas.
  ///
  /// In en, this message translates to:
  /// **'Diluent Gas'**
  String get diveLog_ccr_sectionDiluentGas;

  /// No description provided for @diveLog_ccr_sectionScrubber.
  ///
  /// In en, this message translates to:
  /// **'Scrubber'**
  String get diveLog_ccr_sectionScrubber;

  /// No description provided for @diveLog_ccr_sectionSetpoints.
  ///
  /// In en, this message translates to:
  /// **'Setpoints (bar)'**
  String get diveLog_ccr_sectionSetpoints;

  /// No description provided for @diveLog_ccr_title.
  ///
  /// In en, this message translates to:
  /// **'CCR Settings'**
  String get diveLog_ccr_title;

  /// No description provided for @diveLog_collapsible_semantics_collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse {title} section'**
  String diveLog_collapsible_semantics_collapse(Object title);

  /// No description provided for @diveLog_collapsible_semantics_expand.
  ///
  /// In en, this message translates to:
  /// **'Expand {title} section'**
  String diveLog_collapsible_semantics_expand(Object title);

  /// No description provided for @diveLog_cylinderSac_avgDepth.
  ///
  /// In en, this message translates to:
  /// **'Avg: {depth}'**
  String diveLog_cylinderSac_avgDepth(Object depth);

  /// No description provided for @diveLog_cylinderSac_badge_ai.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get diveLog_cylinderSac_badge_ai;

  /// No description provided for @diveLog_cylinderSac_badge_basic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get diveLog_cylinderSac_badge_basic;

  /// No description provided for @diveLog_cylinderSac_noSac.
  ///
  /// In en, this message translates to:
  /// **'SAC: --'**
  String get diveLog_cylinderSac_noSac;

  /// No description provided for @diveLog_cylinderSac_tooltip_aiData.
  ///
  /// In en, this message translates to:
  /// **'Using AI transmitter data for higher accuracy'**
  String get diveLog_cylinderSac_tooltip_aiData;

  /// No description provided for @diveLog_cylinderSac_tooltip_basicData.
  ///
  /// In en, this message translates to:
  /// **'Calculated from start/end pressures'**
  String get diveLog_cylinderSac_tooltip_basicData;

  /// No description provided for @diveLog_deco_badge_deco.
  ///
  /// In en, this message translates to:
  /// **'DECO'**
  String get diveLog_deco_badge_deco;

  /// No description provided for @diveLog_deco_badge_noDeco.
  ///
  /// In en, this message translates to:
  /// **'NO DECO'**
  String get diveLog_deco_badge_noDeco;

  /// No description provided for @diveLog_deco_label_ceiling.
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get diveLog_deco_label_ceiling;

  /// No description provided for @diveLog_deco_label_leading.
  ///
  /// In en, this message translates to:
  /// **'Leading'**
  String get diveLog_deco_label_leading;

  /// No description provided for @diveLog_deco_label_ndl.
  ///
  /// In en, this message translates to:
  /// **'NDL'**
  String get diveLog_deco_label_ndl;

  /// No description provided for @diveLog_deco_label_tts.
  ///
  /// In en, this message translates to:
  /// **'TTS'**
  String get diveLog_deco_label_tts;

  /// No description provided for @diveLog_deco_sectionDecoStops.
  ///
  /// In en, this message translates to:
  /// **'Deco Stops'**
  String get diveLog_deco_sectionDecoStops;

  /// No description provided for @diveLog_deco_sectionTissueLoading.
  ///
  /// In en, this message translates to:
  /// **'Tissue Loading'**
  String get diveLog_deco_sectionTissueLoading;

  /// No description provided for @diveLog_deco_semantics_notRequired.
  ///
  /// In en, this message translates to:
  /// **'No decompression required'**
  String get diveLog_deco_semantics_notRequired;

  /// No description provided for @diveLog_deco_semantics_required.
  ///
  /// In en, this message translates to:
  /// **'Decompression required'**
  String get diveLog_deco_semantics_required;

  /// No description provided for @diveLog_deco_tissueFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get diveLog_deco_tissueFast;

  /// No description provided for @diveLog_deco_tissueSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get diveLog_deco_tissueSlow;

  /// No description provided for @diveLog_deco_title.
  ///
  /// In en, this message translates to:
  /// **'Decompression Status'**
  String get diveLog_deco_title;

  /// No description provided for @diveLog_deco_totalDecoTime.
  ///
  /// In en, this message translates to:
  /// **'Total: {time}'**
  String diveLog_deco_totalDecoTime(Object time);

  /// No description provided for @diveLog_delete_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diveLog_delete_cancel;

  /// No description provided for @diveLog_delete_confirm.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. The dive and all associated data (profile, tanks, sightings) will be permanently deleted.'**
  String get diveLog_delete_confirm;

  /// No description provided for @diveLog_delete_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get diveLog_delete_delete;

  /// No description provided for @diveLog_delete_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Dive?'**
  String get diveLog_delete_title;

  /// No description provided for @diveLog_detail_appBar.
  ///
  /// In en, this message translates to:
  /// **'Dive Details'**
  String get diveLog_detail_appBar;

  /// No description provided for @diveLog_detail_badge_critical.
  ///
  /// In en, this message translates to:
  /// **'CRITICAL'**
  String get diveLog_detail_badge_critical;

  /// No description provided for @diveLog_detail_badge_deco.
  ///
  /// In en, this message translates to:
  /// **'DECO'**
  String get diveLog_detail_badge_deco;

  /// No description provided for @diveLog_detail_badge_noDeco.
  ///
  /// In en, this message translates to:
  /// **'NO DECO'**
  String get diveLog_detail_badge_noDeco;

  /// No description provided for @diveLog_detail_badge_warning.
  ///
  /// In en, this message translates to:
  /// **'WARNING'**
  String get diveLog_detail_badge_warning;

  /// No description provided for @diveLog_detail_buddyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{buddy} other{buddies}}'**
  String diveLog_detail_buddyCount(int count);

  /// No description provided for @diveLog_detail_button_playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get diveLog_detail_button_playback;

  /// No description provided for @diveLog_detail_button_rangeAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Range Analysis'**
  String get diveLog_detail_button_rangeAnalysis;

  /// No description provided for @diveLog_detail_button_showEnd.
  ///
  /// In en, this message translates to:
  /// **'Show end'**
  String get diveLog_detail_button_showEnd;

  /// No description provided for @diveLog_detail_captureSignature.
  ///
  /// In en, this message translates to:
  /// **'Capture Instructor Signature'**
  String get diveLog_detail_captureSignature;

  /// No description provided for @diveLog_detail_collapsed_atTime.
  ///
  /// In en, this message translates to:
  /// **'At {timestamp}'**
  String diveLog_detail_collapsed_atTime(Object timestamp);

  /// No description provided for @diveLog_detail_collapsed_atTimeInfo.
  ///
  /// In en, this message translates to:
  /// **'At {timestamp} • {baseInfo}'**
  String diveLog_detail_collapsed_atTimeInfo(Object timestamp, Object baseInfo);

  /// No description provided for @diveLog_detail_collapsed_ceiling.
  ///
  /// In en, this message translates to:
  /// **'Ceiling: {value}'**
  String diveLog_detail_collapsed_ceiling(Object value);

  /// No description provided for @diveLog_detail_collapsed_cnsMaxPpO2.
  ///
  /// In en, this message translates to:
  /// **'CNS: {cns} • Max ppO₂: {maxPpO2}'**
  String diveLog_detail_collapsed_cnsMaxPpO2(Object cns, Object maxPpO2);

  /// No description provided for @diveLog_detail_collapsed_cnsMaxPpO2AtTime.
  ///
  /// In en, this message translates to:
  /// **'CNS: {cns} • Max ppO₂: {maxPpO2} • At {timestamp}: {ppO2} bar'**
  String diveLog_detail_collapsed_cnsMaxPpO2AtTime(
    Object cns,
    Object maxPpO2,
    Object timestamp,
    Object ppO2,
  );

  /// No description provided for @diveLog_detail_collapsed_ndl.
  ///
  /// In en, this message translates to:
  /// **'NDL: {value}'**
  String diveLog_detail_collapsed_ndl(Object value);

  /// No description provided for @diveLog_detail_equipmentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{item} other{items}}'**
  String diveLog_detail_equipmentCount(int count);

  /// No description provided for @diveLog_detail_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading dive'**
  String get diveLog_detail_errorLoading;

  /// No description provided for @diveLog_detail_fullscreen_sampleData.
  ///
  /// In en, this message translates to:
  /// **'Sample Data'**
  String get diveLog_detail_fullscreen_sampleData;

  /// No description provided for @diveLog_detail_fullscreen_tapChartCompact.
  ///
  /// In en, this message translates to:
  /// **'Tap chart for compact view'**
  String get diveLog_detail_fullscreen_tapChartCompact;

  /// No description provided for @diveLog_detail_fullscreen_tapChartFull.
  ///
  /// In en, this message translates to:
  /// **'Tap chart for full-screen view'**
  String get diveLog_detail_fullscreen_tapChartFull;

  /// No description provided for @diveLog_detail_fullscreen_touchChart.
  ///
  /// In en, this message translates to:
  /// **'Touch the chart to see data at that point'**
  String get diveLog_detail_fullscreen_touchChart;

  /// No description provided for @diveLog_detail_label_airTemp.
  ///
  /// In en, this message translates to:
  /// **'Air Temp'**
  String get diveLog_detail_label_airTemp;

  /// No description provided for @diveLog_detail_label_avgDepth.
  ///
  /// In en, this message translates to:
  /// **'Avg Depth'**
  String get diveLog_detail_label_avgDepth;

  /// No description provided for @diveLog_detail_label_buddy.
  ///
  /// In en, this message translates to:
  /// **'Buddy'**
  String get diveLog_detail_label_buddy;

  /// No description provided for @diveLog_detail_label_currentDirection.
  ///
  /// In en, this message translates to:
  /// **'Current Direction'**
  String get diveLog_detail_label_currentDirection;

  /// No description provided for @diveLog_detail_label_currentStrength.
  ///
  /// In en, this message translates to:
  /// **'Current Strength'**
  String get diveLog_detail_label_currentStrength;

  /// No description provided for @diveLog_detail_label_diveComputer.
  ///
  /// In en, this message translates to:
  /// **'Dive Computer'**
  String get diveLog_detail_label_diveComputer;

  /// No description provided for @diveLog_detail_label_diveMaster.
  ///
  /// In en, this message translates to:
  /// **'Dive Master'**
  String get diveLog_detail_label_diveMaster;

  /// No description provided for @diveLog_detail_label_diveType.
  ///
  /// In en, this message translates to:
  /// **'Dive Type'**
  String get diveLog_detail_label_diveType;

  /// No description provided for @diveLog_detail_label_elevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get diveLog_detail_label_elevation;

  /// No description provided for @diveLog_detail_label_entry.
  ///
  /// In en, this message translates to:
  /// **'Entry:'**
  String get diveLog_detail_label_entry;

  /// No description provided for @diveLog_detail_label_entryMethod.
  ///
  /// In en, this message translates to:
  /// **'Entry Method'**
  String get diveLog_detail_label_entryMethod;

  /// No description provided for @diveLog_detail_label_exit.
  ///
  /// In en, this message translates to:
  /// **'Exit:'**
  String get diveLog_detail_label_exit;

  /// No description provided for @diveLog_detail_label_exitMethod.
  ///
  /// In en, this message translates to:
  /// **'Exit Method'**
  String get diveLog_detail_label_exitMethod;

  /// No description provided for @diveLog_detail_label_gradientFactors.
  ///
  /// In en, this message translates to:
  /// **'Gradient Factors'**
  String get diveLog_detail_label_gradientFactors;

  /// No description provided for @diveLog_detail_label_height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get diveLog_detail_label_height;

  /// No description provided for @diveLog_detail_label_highTide.
  ///
  /// In en, this message translates to:
  /// **'High Tide'**
  String get diveLog_detail_label_highTide;

  /// No description provided for @diveLog_detail_label_lowTide.
  ///
  /// In en, this message translates to:
  /// **'Low Tide'**
  String get diveLog_detail_label_lowTide;

  /// No description provided for @diveLog_detail_label_ppO2AtPoint.
  ///
  /// In en, this message translates to:
  /// **'ppO₂ at selected point:'**
  String get diveLog_detail_label_ppO2AtPoint;

  /// No description provided for @diveLog_detail_label_rateOfChange.
  ///
  /// In en, this message translates to:
  /// **'Rate of Change'**
  String get diveLog_detail_label_rateOfChange;

  /// No description provided for @diveLog_detail_label_sacRate.
  ///
  /// In en, this message translates to:
  /// **'SAC Rate'**
  String get diveLog_detail_label_sacRate;

  /// No description provided for @diveLog_detail_label_state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get diveLog_detail_label_state;

  /// No description provided for @diveLog_detail_label_surfaceInterval.
  ///
  /// In en, this message translates to:
  /// **'Surface Interval'**
  String get diveLog_detail_label_surfaceInterval;

  /// No description provided for @diveLog_detail_label_surfacePressure.
  ///
  /// In en, this message translates to:
  /// **'Surface Pressure'**
  String get diveLog_detail_label_surfacePressure;

  /// No description provided for @diveLog_detail_label_swellHeight.
  ///
  /// In en, this message translates to:
  /// **'Swell Height'**
  String get diveLog_detail_label_swellHeight;

  /// No description provided for @diveLog_detail_label_total.
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get diveLog_detail_label_total;

  /// No description provided for @diveLog_detail_label_visibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get diveLog_detail_label_visibility;

  /// No description provided for @diveLog_detail_label_waterType.
  ///
  /// In en, this message translates to:
  /// **'Water Type'**
  String get diveLog_detail_label_waterType;

  /// No description provided for @diveLog_detail_menu_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get diveLog_detail_menu_delete;

  /// No description provided for @diveLog_detail_menu_export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get diveLog_detail_menu_export;

  /// No description provided for @diveLog_detail_menu_openFullPage.
  ///
  /// In en, this message translates to:
  /// **'Open Full Page'**
  String get diveLog_detail_menu_openFullPage;

  /// No description provided for @diveLog_detail_noNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes for this dive.'**
  String get diveLog_detail_noNotes;

  /// No description provided for @diveLog_detail_notFound.
  ///
  /// In en, this message translates to:
  /// **'Dive not found'**
  String get diveLog_detail_notFound;

  /// No description provided for @diveLog_detail_profilePoints.
  ///
  /// In en, this message translates to:
  /// **'{count} points'**
  String diveLog_detail_profilePoints(Object count);

  /// No description provided for @diveLog_detail_section_altitudeDive.
  ///
  /// In en, this message translates to:
  /// **'Altitude Dive'**
  String get diveLog_detail_section_altitudeDive;

  /// No description provided for @diveLog_detail_section_buddies.
  ///
  /// In en, this message translates to:
  /// **'Buddies'**
  String get diveLog_detail_section_buddies;

  /// No description provided for @diveLog_detail_section_conditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get diveLog_detail_section_conditions;

  /// No description provided for @diveLog_detail_section_decoStatus.
  ///
  /// In en, this message translates to:
  /// **'Decompression Status'**
  String get diveLog_detail_section_decoStatus;

  /// No description provided for @diveLog_detail_section_details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get diveLog_detail_section_details;

  /// No description provided for @diveLog_detail_section_diveProfile.
  ///
  /// In en, this message translates to:
  /// **'Dive Profile'**
  String get diveLog_detail_section_diveProfile;

  /// No description provided for @diveLog_detail_section_equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get diveLog_detail_section_equipment;

  /// No description provided for @diveLog_detail_section_marineLife.
  ///
  /// In en, this message translates to:
  /// **'Marine Life'**
  String get diveLog_detail_section_marineLife;

  /// No description provided for @diveLog_detail_section_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get diveLog_detail_section_notes;

  /// No description provided for @diveLog_detail_section_oxygenToxicity.
  ///
  /// In en, this message translates to:
  /// **'Oxygen Toxicity'**
  String get diveLog_detail_section_oxygenToxicity;

  /// No description provided for @diveLog_detail_section_sacByCylinder.
  ///
  /// In en, this message translates to:
  /// **'SAC by Cylinder'**
  String get diveLog_detail_section_sacByCylinder;

  /// No description provided for @diveLog_detail_section_sacRateBySegment.
  ///
  /// In en, this message translates to:
  /// **'SAC Rate by Segment'**
  String get diveLog_detail_section_sacRateBySegment;

  /// No description provided for @diveLog_detail_section_tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get diveLog_detail_section_tags;

  /// No description provided for @diveLog_detail_section_tanks.
  ///
  /// In en, this message translates to:
  /// **'Tanks'**
  String get diveLog_detail_section_tanks;

  /// No description provided for @diveLog_detail_section_tide.
  ///
  /// In en, this message translates to:
  /// **'Tide'**
  String get diveLog_detail_section_tide;

  /// No description provided for @diveLog_detail_section_trainingSignature.
  ///
  /// In en, this message translates to:
  /// **'Training Signature'**
  String get diveLog_detail_section_trainingSignature;

  /// No description provided for @diveLog_detail_section_weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get diveLog_detail_section_weight;

  /// No description provided for @diveLog_detail_signatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap to add instructor verification for this training dive'**
  String get diveLog_detail_signatureDescription;

  /// No description provided for @diveLog_detail_soloDive.
  ///
  /// In en, this message translates to:
  /// **'Solo dive or no buddies recorded'**
  String get diveLog_detail_soloDive;

  /// No description provided for @diveLog_detail_speciesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} species'**
  String diveLog_detail_speciesCount(Object count);

  /// No description provided for @diveLog_detail_stat_bottomTime.
  ///
  /// In en, this message translates to:
  /// **'Bottom Time'**
  String get diveLog_detail_stat_bottomTime;

  /// No description provided for @diveLog_detail_stat_maxDepth.
  ///
  /// In en, this message translates to:
  /// **'Max Depth'**
  String get diveLog_detail_stat_maxDepth;

  /// No description provided for @diveLog_detail_stat_runtime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get diveLog_detail_stat_runtime;

  /// No description provided for @diveLog_detail_stat_waterTemp.
  ///
  /// In en, this message translates to:
  /// **'Water Temp'**
  String get diveLog_detail_stat_waterTemp;

  /// No description provided for @diveLog_detail_tagCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{tag} other{tags}}'**
  String diveLog_detail_tagCount(int count);

  /// No description provided for @diveLog_detail_tankCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{tank} other{tanks}}'**
  String diveLog_detail_tankCount(int count);

  /// No description provided for @diveLog_detail_tideCalculated.
  ///
  /// In en, this message translates to:
  /// **'Calculated from tide model'**
  String get diveLog_detail_tideCalculated;

  /// No description provided for @diveLog_detail_tooltip_addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get diveLog_detail_tooltip_addToFavorites;

  /// No description provided for @diveLog_detail_tooltip_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get diveLog_detail_tooltip_edit;

  /// No description provided for @diveLog_detail_tooltip_editDive.
  ///
  /// In en, this message translates to:
  /// **'Edit dive'**
  String get diveLog_detail_tooltip_editDive;

  /// No description provided for @diveLog_detail_tooltip_exportProfileImage.
  ///
  /// In en, this message translates to:
  /// **'Export profile as image'**
  String get diveLog_detail_tooltip_exportProfileImage;

  /// No description provided for @diveLog_detail_tooltip_removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get diveLog_detail_tooltip_removeFromFavorites;

  /// No description provided for @diveLog_detail_tooltip_viewFullscreen.
  ///
  /// In en, this message translates to:
  /// **'View fullscreen'**
  String get diveLog_detail_tooltip_viewFullscreen;

  /// No description provided for @diveLog_detail_viewSite.
  ///
  /// In en, this message translates to:
  /// **'View Site'**
  String get diveLog_detail_viewSite;

  /// No description provided for @diveLog_diveMode_ccrDescription.
  ///
  /// In en, this message translates to:
  /// **'Closed circuit rebreather with constant ppO₂'**
  String get diveLog_diveMode_ccrDescription;

  /// No description provided for @diveLog_diveMode_ocDescription.
  ///
  /// In en, this message translates to:
  /// **'Standard open circuit scuba with tanks'**
  String get diveLog_diveMode_ocDescription;

  /// No description provided for @diveLog_diveMode_scrDescription.
  ///
  /// In en, this message translates to:
  /// **'Semi-closed rebreather with variable ppO₂'**
  String get diveLog_diveMode_scrDescription;

  /// No description provided for @diveLog_diveMode_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Mode'**
  String get diveLog_diveMode_title;

  /// No description provided for @diveLog_editSighting_count.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get diveLog_editSighting_count;

  /// No description provided for @diveLog_editSighting_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get diveLog_editSighting_notes;

  /// No description provided for @diveLog_editSighting_notesHint.
  ///
  /// In en, this message translates to:
  /// **'Size, behavior, location...'**
  String get diveLog_editSighting_notesHint;

  /// No description provided for @diveLog_editSighting_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get diveLog_editSighting_remove;

  /// No description provided for @diveLog_editSighting_removeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this dive?'**
  String diveLog_editSighting_removeConfirm(Object name);

  /// No description provided for @diveLog_editSighting_removeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Sighting?'**
  String get diveLog_editSighting_removeTitle;

  /// No description provided for @diveLog_editSighting_save.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get diveLog_editSighting_save;

  /// No description provided for @diveLog_edit_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get diveLog_edit_add;

  /// No description provided for @diveLog_edit_addTank.
  ///
  /// In en, this message translates to:
  /// **'Add Tank'**
  String get diveLog_edit_addTank;

  /// No description provided for @diveLog_edit_addWeightEntry.
  ///
  /// In en, this message translates to:
  /// **'Add Weight Entry'**
  String get diveLog_edit_addWeightEntry;

  /// No description provided for @diveLog_edit_addedGps.
  ///
  /// In en, this message translates to:
  /// **'Added GPS to {name}'**
  String diveLog_edit_addedGps(Object name);

  /// No description provided for @diveLog_edit_appBarEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Dive'**
  String get diveLog_edit_appBarEdit;

  /// No description provided for @diveLog_edit_appBarNew.
  ///
  /// In en, this message translates to:
  /// **'Log Dive'**
  String get diveLog_edit_appBarNew;

  /// No description provided for @diveLog_edit_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diveLog_edit_cancel;

  /// No description provided for @diveLog_edit_clearAllEquipment.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get diveLog_edit_clearAllEquipment;

  /// No description provided for @diveLog_edit_createdSite.
  ///
  /// In en, this message translates to:
  /// **'Created site: {name}'**
  String diveLog_edit_createdSite(Object name);

  /// No description provided for @diveLog_edit_durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'Duration: {minutes} min'**
  String diveLog_edit_durationMinutes(Object minutes);

  /// No description provided for @diveLog_edit_equipmentHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Use Set\" or \"Add\" to select equipment'**
  String get diveLog_edit_equipmentHint;

  /// No description provided for @diveLog_edit_errorLoadingDiveTypes.
  ///
  /// In en, this message translates to:
  /// **'Error loading dive types: {error}'**
  String diveLog_edit_errorLoadingDiveTypes(Object error);

  /// No description provided for @diveLog_edit_gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting location...'**
  String get diveLog_edit_gettingLocation;

  /// No description provided for @diveLog_edit_headerNew.
  ///
  /// In en, this message translates to:
  /// **'Log New Dive'**
  String get diveLog_edit_headerNew;

  /// No description provided for @diveLog_edit_label_airTemp.
  ///
  /// In en, this message translates to:
  /// **'Air Temp'**
  String get diveLog_edit_label_airTemp;

  /// No description provided for @diveLog_edit_label_altitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get diveLog_edit_label_altitude;

  /// No description provided for @diveLog_edit_label_avgDepth.
  ///
  /// In en, this message translates to:
  /// **'Avg Depth'**
  String get diveLog_edit_label_avgDepth;

  /// No description provided for @diveLog_edit_label_bottomTime.
  ///
  /// In en, this message translates to:
  /// **'Bottom Time'**
  String get diveLog_edit_label_bottomTime;

  /// No description provided for @diveLog_edit_label_currentDirection.
  ///
  /// In en, this message translates to:
  /// **'Current Direction'**
  String get diveLog_edit_label_currentDirection;

  /// No description provided for @diveLog_edit_label_currentStrength.
  ///
  /// In en, this message translates to:
  /// **'Current Strength'**
  String get diveLog_edit_label_currentStrength;

  /// No description provided for @diveLog_edit_label_diveType.
  ///
  /// In en, this message translates to:
  /// **'Dive Type'**
  String get diveLog_edit_label_diveType;

  /// No description provided for @diveLog_edit_label_entryMethod.
  ///
  /// In en, this message translates to:
  /// **'Entry Method'**
  String get diveLog_edit_label_entryMethod;

  /// No description provided for @diveLog_edit_label_exitMethod.
  ///
  /// In en, this message translates to:
  /// **'Exit Method'**
  String get diveLog_edit_label_exitMethod;

  /// No description provided for @diveLog_edit_label_maxDepth.
  ///
  /// In en, this message translates to:
  /// **'Max Depth'**
  String get diveLog_edit_label_maxDepth;

  /// No description provided for @diveLog_edit_label_runtime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get diveLog_edit_label_runtime;

  /// No description provided for @diveLog_edit_label_surfacePressure.
  ///
  /// In en, this message translates to:
  /// **'Surface Pressure'**
  String get diveLog_edit_label_surfacePressure;

  /// No description provided for @diveLog_edit_label_swellHeight.
  ///
  /// In en, this message translates to:
  /// **'Swell Height'**
  String get diveLog_edit_label_swellHeight;

  /// No description provided for @diveLog_edit_label_type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get diveLog_edit_label_type;

  /// No description provided for @diveLog_edit_label_visibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get diveLog_edit_label_visibility;

  /// No description provided for @diveLog_edit_label_waterTemp.
  ///
  /// In en, this message translates to:
  /// **'Water Temp'**
  String get diveLog_edit_label_waterTemp;

  /// No description provided for @diveLog_edit_label_waterType.
  ///
  /// In en, this message translates to:
  /// **'Water Type'**
  String get diveLog_edit_label_waterType;

  /// No description provided for @diveLog_edit_marineLifeHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add\" to record sightings'**
  String get diveLog_edit_marineLifeHint;

  /// No description provided for @diveLog_edit_nearbySitesFirst.
  ///
  /// In en, this message translates to:
  /// **'Nearby sites first'**
  String get diveLog_edit_nearbySitesFirst;

  /// No description provided for @diveLog_edit_noEquipmentSelected.
  ///
  /// In en, this message translates to:
  /// **'No equipment selected'**
  String get diveLog_edit_noEquipmentSelected;

  /// No description provided for @diveLog_edit_noMarineLife.
  ///
  /// In en, this message translates to:
  /// **'No marine life logged'**
  String get diveLog_edit_noMarineLife;

  /// No description provided for @diveLog_edit_notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get diveLog_edit_notSpecified;

  /// No description provided for @diveLog_edit_notesHint.
  ///
  /// In en, this message translates to:
  /// **'Add notes about this dive...'**
  String get diveLog_edit_notesHint;

  /// No description provided for @diveLog_edit_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get diveLog_edit_save;

  /// No description provided for @diveLog_edit_saveAsSet.
  ///
  /// In en, this message translates to:
  /// **'Save as Set'**
  String get diveLog_edit_saveAsSet;

  /// No description provided for @diveLog_edit_saveAsSetDialog_content.
  ///
  /// In en, this message translates to:
  /// **'Save {count} {count, plural, =1{item} other{items}} as a new equipment set.'**
  String diveLog_edit_saveAsSetDialog_content(int count);

  /// No description provided for @diveLog_edit_saveAsSetDialog_description.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get diveLog_edit_saveAsSetDialog_description;

  /// No description provided for @diveLog_edit_saveAsSetDialog_descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Light gear for warm water'**
  String get diveLog_edit_saveAsSetDialog_descriptionHint;

  /// No description provided for @diveLog_edit_saveAsSetDialog_error.
  ///
  /// In en, this message translates to:
  /// **'Error creating set: {error}'**
  String diveLog_edit_saveAsSetDialog_error(Object error);

  /// No description provided for @diveLog_edit_saveAsSetDialog_setName.
  ///
  /// In en, this message translates to:
  /// **'Set Name'**
  String get diveLog_edit_saveAsSetDialog_setName;

  /// No description provided for @diveLog_edit_saveAsSetDialog_setNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Tropical Diving'**
  String get diveLog_edit_saveAsSetDialog_setNameHint;

  /// No description provided for @diveLog_edit_saveAsSetDialog_success.
  ///
  /// In en, this message translates to:
  /// **'Equipment set \"{name}\" created'**
  String diveLog_edit_saveAsSetDialog_success(Object name);

  /// No description provided for @diveLog_edit_saveAsSetDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Save as Equipment Set'**
  String get diveLog_edit_saveAsSetDialog_title;

  /// No description provided for @diveLog_edit_saveAsSetDialog_validation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a set name'**
  String get diveLog_edit_saveAsSetDialog_validation;

  /// No description provided for @diveLog_edit_section_conditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get diveLog_edit_section_conditions;

  /// No description provided for @diveLog_edit_section_depthDuration.
  ///
  /// In en, this message translates to:
  /// **'Depth & Duration'**
  String get diveLog_edit_section_depthDuration;

  /// No description provided for @diveLog_edit_section_diveCenter.
  ///
  /// In en, this message translates to:
  /// **'Dive Center'**
  String get diveLog_edit_section_diveCenter;

  /// No description provided for @diveLog_edit_section_diveSite.
  ///
  /// In en, this message translates to:
  /// **'Dive Site'**
  String get diveLog_edit_section_diveSite;

  /// No description provided for @diveLog_edit_section_entryTime.
  ///
  /// In en, this message translates to:
  /// **'Entry Time'**
  String get diveLog_edit_section_entryTime;

  /// No description provided for @diveLog_edit_section_equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get diveLog_edit_section_equipment;

  /// No description provided for @diveLog_edit_section_exitTime.
  ///
  /// In en, this message translates to:
  /// **'Exit Time'**
  String get diveLog_edit_section_exitTime;

  /// No description provided for @diveLog_edit_section_marineLife.
  ///
  /// In en, this message translates to:
  /// **'Marine Life'**
  String get diveLog_edit_section_marineLife;

  /// No description provided for @diveLog_edit_section_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get diveLog_edit_section_notes;

  /// No description provided for @diveLog_edit_section_rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get diveLog_edit_section_rating;

  /// No description provided for @diveLog_edit_section_tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get diveLog_edit_section_tags;

  /// No description provided for @diveLog_edit_section_tanks.
  ///
  /// In en, this message translates to:
  /// **'Tanks ({count})'**
  String diveLog_edit_section_tanks(Object count);

  /// No description provided for @diveLog_edit_section_trainingCourse.
  ///
  /// In en, this message translates to:
  /// **'Training Course'**
  String get diveLog_edit_section_trainingCourse;

  /// No description provided for @diveLog_edit_section_trip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get diveLog_edit_section_trip;

  /// No description provided for @diveLog_edit_section_weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get diveLog_edit_section_weight;

  /// No description provided for @diveLog_edit_select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get diveLog_edit_select;

  /// No description provided for @diveLog_edit_selectDiveCenter.
  ///
  /// In en, this message translates to:
  /// **'Select Dive Center'**
  String get diveLog_edit_selectDiveCenter;

  /// No description provided for @diveLog_edit_selectDiveSite.
  ///
  /// In en, this message translates to:
  /// **'Select Dive Site'**
  String get diveLog_edit_selectDiveSite;

  /// No description provided for @diveLog_edit_selectTrip.
  ///
  /// In en, this message translates to:
  /// **'Select Trip'**
  String get diveLog_edit_selectTrip;

  /// No description provided for @diveLog_edit_snackbar_bottomTimeCalculated.
  ///
  /// In en, this message translates to:
  /// **'Bottom time calculated: {minutes} min'**
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes);

  /// No description provided for @diveLog_edit_snackbar_errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving dive: {error}'**
  String diveLog_edit_snackbar_errorSaving(Object error);

  /// No description provided for @diveLog_edit_snackbar_noProfileData.
  ///
  /// In en, this message translates to:
  /// **'No dive profile data available'**
  String get diveLog_edit_snackbar_noProfileData;

  /// No description provided for @diveLog_edit_snackbar_unableToCalculate.
  ///
  /// In en, this message translates to:
  /// **'Unable to calculate bottom time from profile'**
  String get diveLog_edit_snackbar_unableToCalculate;

  /// No description provided for @diveLog_edit_surfaceInterval.
  ///
  /// In en, this message translates to:
  /// **'Surface Interval: {interval}'**
  String diveLog_edit_surfaceInterval(Object interval);

  /// No description provided for @diveLog_edit_surfacePressureDefault.
  ///
  /// In en, this message translates to:
  /// **'1013'**
  String get diveLog_edit_surfacePressureDefault;

  /// No description provided for @diveLog_edit_surfacePressureHint.
  ///
  /// In en, this message translates to:
  /// **'Standard: 1013 mbar at sea level'**
  String get diveLog_edit_surfacePressureHint;

  /// No description provided for @diveLog_edit_tooltip_calculateFromProfile.
  ///
  /// In en, this message translates to:
  /// **'Calculate from dive profile'**
  String get diveLog_edit_tooltip_calculateFromProfile;

  /// No description provided for @diveLog_edit_tooltip_clearDiveCenter.
  ///
  /// In en, this message translates to:
  /// **'Clear dive center'**
  String get diveLog_edit_tooltip_clearDiveCenter;

  /// No description provided for @diveLog_edit_tooltip_clearSite.
  ///
  /// In en, this message translates to:
  /// **'Clear site'**
  String get diveLog_edit_tooltip_clearSite;

  /// No description provided for @diveLog_edit_tooltip_clearTrip.
  ///
  /// In en, this message translates to:
  /// **'Clear trip'**
  String get diveLog_edit_tooltip_clearTrip;

  /// No description provided for @diveLog_edit_tooltip_removeEquipment.
  ///
  /// In en, this message translates to:
  /// **'Remove equipment'**
  String get diveLog_edit_tooltip_removeEquipment;

  /// No description provided for @diveLog_edit_tooltip_removeSighting.
  ///
  /// In en, this message translates to:
  /// **'Remove sighting'**
  String get diveLog_edit_tooltip_removeSighting;

  /// No description provided for @diveLog_edit_tooltip_removeWeight.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get diveLog_edit_tooltip_removeWeight;

  /// No description provided for @diveLog_edit_trainingCourseHint.
  ///
  /// In en, this message translates to:
  /// **'Link this dive to a training course'**
  String get diveLog_edit_trainingCourseHint;

  /// No description provided for @diveLog_edit_tripSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested: {name}'**
  String diveLog_edit_tripSuggested(Object name);

  /// No description provided for @diveLog_edit_tripUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get diveLog_edit_tripUse;

  /// No description provided for @diveLog_edit_useSet.
  ///
  /// In en, this message translates to:
  /// **'Use Set'**
  String get diveLog_edit_useSet;

  /// No description provided for @diveLog_edit_weightTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {total}'**
  String diveLog_edit_weightTotal(Object total);

  /// No description provided for @diveLog_emptyFiltered_clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get diveLog_emptyFiltered_clearFilters;

  /// No description provided for @diveLog_emptyFiltered_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting or clearing your filters'**
  String get diveLog_emptyFiltered_subtitle;

  /// No description provided for @diveLog_emptyFiltered_title.
  ///
  /// In en, this message translates to:
  /// **'No dives match your filters'**
  String get diveLog_emptyFiltered_title;

  /// No description provided for @diveLog_empty_logFirstDive.
  ///
  /// In en, this message translates to:
  /// **'Log Your First Dive'**
  String get diveLog_empty_logFirstDive;

  /// No description provided for @diveLog_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to log your first dive'**
  String get diveLog_empty_subtitle;

  /// No description provided for @diveLog_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No dives logged yet'**
  String get diveLog_empty_title;

  /// No description provided for @diveLog_equipmentPicker_addFromTab.
  ///
  /// In en, this message translates to:
  /// **'Add equipment from the Equipment tab'**
  String get diveLog_equipmentPicker_addFromTab;

  /// No description provided for @diveLog_equipmentPicker_allSelected.
  ///
  /// In en, this message translates to:
  /// **'All equipment already selected'**
  String get diveLog_equipmentPicker_allSelected;

  /// No description provided for @diveLog_equipmentPicker_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading equipment: {error}'**
  String diveLog_equipmentPicker_errorLoading(Object error);

  /// No description provided for @diveLog_equipmentPicker_noEquipment.
  ///
  /// In en, this message translates to:
  /// **'No equipment yet'**
  String get diveLog_equipmentPicker_noEquipment;

  /// No description provided for @diveLog_equipmentPicker_removeToAdd.
  ///
  /// In en, this message translates to:
  /// **'Remove items to add different ones'**
  String get diveLog_equipmentPicker_removeToAdd;

  /// No description provided for @diveLog_equipmentPicker_title.
  ///
  /// In en, this message translates to:
  /// **'Add Equipment'**
  String get diveLog_equipmentPicker_title;

  /// No description provided for @diveLog_equipmentSetPicker_createHint.
  ///
  /// In en, this message translates to:
  /// **'Create sets in Equipment > Sets'**
  String get diveLog_equipmentSetPicker_createHint;

  /// No description provided for @diveLog_equipmentSetPicker_emptySet.
  ///
  /// In en, this message translates to:
  /// **'Empty set'**
  String get diveLog_equipmentSetPicker_emptySet;

  /// No description provided for @diveLog_equipmentSetPicker_errorItems.
  ///
  /// In en, this message translates to:
  /// **'Error loading items'**
  String get diveLog_equipmentSetPicker_errorItems;

  /// No description provided for @diveLog_equipmentSetPicker_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading equipment sets: {error}'**
  String diveLog_equipmentSetPicker_errorLoading(Object error);

  /// No description provided for @diveLog_equipmentSetPicker_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get diveLog_equipmentSetPicker_loading;

  /// No description provided for @diveLog_equipmentSetPicker_noSets.
  ///
  /// In en, this message translates to:
  /// **'No equipment sets yet'**
  String get diveLog_equipmentSetPicker_noSets;

  /// No description provided for @diveLog_equipmentSetPicker_title.
  ///
  /// In en, this message translates to:
  /// **'Use Equipment Set'**
  String get diveLog_equipmentSetPicker_title;

  /// No description provided for @diveLog_error_loadingDives.
  ///
  /// In en, this message translates to:
  /// **'Error loading dives'**
  String get diveLog_error_loadingDives;

  /// No description provided for @diveLog_error_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get diveLog_error_retry;

  /// No description provided for @diveLog_exportImage_captureFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not capture image'**
  String get diveLog_exportImage_captureFailed;

  /// No description provided for @diveLog_exportImage_generateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not generate image'**
  String get diveLog_exportImage_generateFailed;

  /// No description provided for @diveLog_exportImage_generatingPdf.
  ///
  /// In en, this message translates to:
  /// **'Generating PDF...'**
  String get diveLog_exportImage_generatingPdf;

  /// No description provided for @diveLog_exportImage_pdfSaved.
  ///
  /// In en, this message translates to:
  /// **'PDF saved'**
  String get diveLog_exportImage_pdfSaved;

  /// No description provided for @diveLog_exportImage_saveToFiles.
  ///
  /// In en, this message translates to:
  /// **'Save to Files'**
  String get diveLog_exportImage_saveToFiles;

  /// No description provided for @diveLog_exportImage_saveToFilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a location to save the file'**
  String get diveLog_exportImage_saveToFilesDescription;

  /// No description provided for @diveLog_exportImage_saveToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Save to Photos'**
  String get diveLog_exportImage_saveToPhotos;

  /// No description provided for @diveLog_exportImage_saveToPhotosDescription.
  ///
  /// In en, this message translates to:
  /// **'Save image to your photo library'**
  String get diveLog_exportImage_saveToPhotosDescription;

  /// No description provided for @diveLog_exportImage_savedToFiles.
  ///
  /// In en, this message translates to:
  /// **'Image saved'**
  String get diveLog_exportImage_savedToFiles;

  /// No description provided for @diveLog_exportImage_savedToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Image saved to Photos'**
  String get diveLog_exportImage_savedToPhotos;

  /// No description provided for @diveLog_exportImage_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get diveLog_exportImage_share;

  /// No description provided for @diveLog_exportImage_shareDescription.
  ///
  /// In en, this message translates to:
  /// **'Share via other apps'**
  String get diveLog_exportImage_shareDescription;

  /// No description provided for @diveLog_exportImage_titleDetails.
  ///
  /// In en, this message translates to:
  /// **'Export Dive Details Image'**
  String get diveLog_exportImage_titleDetails;

  /// No description provided for @diveLog_exportImage_titlePdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get diveLog_exportImage_titlePdf;

  /// No description provided for @diveLog_exportImage_titleProfile.
  ///
  /// In en, this message translates to:
  /// **'Export Profile Image'**
  String get diveLog_exportImage_titleProfile;

  /// No description provided for @diveLog_export_csv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get diveLog_export_csv;

  /// No description provided for @diveLog_export_csvDescription.
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet format'**
  String get diveLog_export_csvDescription;

  /// No description provided for @diveLog_export_exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get diveLog_export_exporting;

  /// No description provided for @diveLog_export_failed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String diveLog_export_failed(Object error);

  /// No description provided for @diveLog_export_pageAsImage.
  ///
  /// In en, this message translates to:
  /// **'Page as Image'**
  String get diveLog_export_pageAsImage;

  /// No description provided for @diveLog_export_pageAsImageDescription.
  ///
  /// In en, this message translates to:
  /// **'Screenshot of entire dive details'**
  String get diveLog_export_pageAsImageDescription;

  /// No description provided for @diveLog_export_pdfDescription.
  ///
  /// In en, this message translates to:
  /// **'Printable dive log page'**
  String get diveLog_export_pdfDescription;

  /// No description provided for @diveLog_export_pdfLogbookEntry.
  ///
  /// In en, this message translates to:
  /// **'PDF Logbook Entry'**
  String get diveLog_export_pdfLogbookEntry;

  /// No description provided for @diveLog_export_success.
  ///
  /// In en, this message translates to:
  /// **'Dive exported successfully'**
  String get diveLog_export_success;

  /// No description provided for @diveLog_export_titleDiveNumber.
  ///
  /// In en, this message translates to:
  /// **'Export Dive #{number}'**
  String diveLog_export_titleDiveNumber(Object number);

  /// No description provided for @diveLog_export_uddf.
  ///
  /// In en, this message translates to:
  /// **'UDDF'**
  String get diveLog_export_uddf;

  /// No description provided for @diveLog_export_uddfDescription.
  ///
  /// In en, this message translates to:
  /// **'Universal Dive Data Format'**
  String get diveLog_export_uddfDescription;

  /// No description provided for @diveLog_filterChip_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get diveLog_filterChip_clearAll;

  /// No description provided for @diveLog_filterChip_favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get diveLog_filterChip_favorites;

  /// No description provided for @diveLog_filterChip_from.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String diveLog_filterChip_from(Object date);

  /// No description provided for @diveLog_filterChip_until.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String diveLog_filterChip_until(Object date);

  /// No description provided for @diveLog_filter_allSites.
  ///
  /// In en, this message translates to:
  /// **'All sites'**
  String get diveLog_filter_allSites;

  /// No description provided for @diveLog_filter_allTypes.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get diveLog_filter_allTypes;

  /// No description provided for @diveLog_filter_apply.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get diveLog_filter_apply;

  /// No description provided for @diveLog_filter_buddyHint.
  ///
  /// In en, this message translates to:
  /// **'Search by buddy name'**
  String get diveLog_filter_buddyHint;

  /// No description provided for @diveLog_filter_buddyName.
  ///
  /// In en, this message translates to:
  /// **'Buddy Name'**
  String get diveLog_filter_buddyName;

  /// No description provided for @diveLog_filter_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get diveLog_filter_clearAll;

  /// No description provided for @diveLog_filter_clearDates.
  ///
  /// In en, this message translates to:
  /// **'Clear dates'**
  String get diveLog_filter_clearDates;

  /// No description provided for @diveLog_filter_clearRating.
  ///
  /// In en, this message translates to:
  /// **'Clear rating filter'**
  String get diveLog_filter_clearRating;

  /// No description provided for @diveLog_filter_dateSeparator.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get diveLog_filter_dateSeparator;

  /// No description provided for @diveLog_filter_endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get diveLog_filter_endDate;

  /// No description provided for @diveLog_filter_errorLoadingSites.
  ///
  /// In en, this message translates to:
  /// **'Error loading sites'**
  String get diveLog_filter_errorLoadingSites;

  /// No description provided for @diveLog_filter_errorLoadingTags.
  ///
  /// In en, this message translates to:
  /// **'Error loading tags'**
  String get diveLog_filter_errorLoadingTags;

  /// No description provided for @diveLog_filter_favoritesOnly.
  ///
  /// In en, this message translates to:
  /// **'Favorites Only'**
  String get diveLog_filter_favoritesOnly;

  /// No description provided for @diveLog_filter_gasAir.
  ///
  /// In en, this message translates to:
  /// **'Air (21%)'**
  String get diveLog_filter_gasAir;

  /// No description provided for @diveLog_filter_gasAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get diveLog_filter_gasAll;

  /// No description provided for @diveLog_filter_gasNitrox.
  ///
  /// In en, this message translates to:
  /// **'Nitrox (>21%)'**
  String get diveLog_filter_gasNitrox;

  /// No description provided for @diveLog_filter_max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get diveLog_filter_max;

  /// No description provided for @diveLog_filter_min.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get diveLog_filter_min;

  /// No description provided for @diveLog_filter_noTagsYet.
  ///
  /// In en, this message translates to:
  /// **'No tags created yet'**
  String get diveLog_filter_noTagsYet;

  /// No description provided for @diveLog_filter_sectionBuddy.
  ///
  /// In en, this message translates to:
  /// **'Buddy'**
  String get diveLog_filter_sectionBuddy;

  /// No description provided for @diveLog_filter_sectionDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get diveLog_filter_sectionDateRange;

  /// No description provided for @diveLog_filter_sectionDepthRange.
  ///
  /// In en, this message translates to:
  /// **'Depth Range (meters)'**
  String get diveLog_filter_sectionDepthRange;

  /// No description provided for @diveLog_filter_sectionDiveSite.
  ///
  /// In en, this message translates to:
  /// **'Dive Site'**
  String get diveLog_filter_sectionDiveSite;

  /// No description provided for @diveLog_filter_sectionDiveType.
  ///
  /// In en, this message translates to:
  /// **'Dive Type'**
  String get diveLog_filter_sectionDiveType;

  /// No description provided for @diveLog_filter_sectionDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get diveLog_filter_sectionDuration;

  /// No description provided for @diveLog_filter_sectionGasMix.
  ///
  /// In en, this message translates to:
  /// **'Gas Mix (O₂%)'**
  String get diveLog_filter_sectionGasMix;

  /// No description provided for @diveLog_filter_sectionMinRating.
  ///
  /// In en, this message translates to:
  /// **'Minimum Rating'**
  String get diveLog_filter_sectionMinRating;

  /// No description provided for @diveLog_filter_sectionTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get diveLog_filter_sectionTags;

  /// No description provided for @diveLog_filter_showOnlyFavorites.
  ///
  /// In en, this message translates to:
  /// **'Show only favorite dives'**
  String get diveLog_filter_showOnlyFavorites;

  /// No description provided for @diveLog_filter_startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get diveLog_filter_startDate;

  /// No description provided for @diveLog_filter_title.
  ///
  /// In en, this message translates to:
  /// **'Filter Dives'**
  String get diveLog_filter_title;

  /// No description provided for @diveLog_filter_tooltip_close.
  ///
  /// In en, this message translates to:
  /// **'Close filter'**
  String get diveLog_filter_tooltip_close;

  /// No description provided for @diveLog_fullscreenProfile_close.
  ///
  /// In en, this message translates to:
  /// **'Close fullscreen'**
  String get diveLog_fullscreenProfile_close;

  /// No description provided for @diveLog_fullscreenProfile_title.
  ///
  /// In en, this message translates to:
  /// **'Dive #{number} Profile'**
  String diveLog_fullscreenProfile_title(Object number);

  /// No description provided for @diveLog_legend_label_ascentRate.
  ///
  /// In en, this message translates to:
  /// **'Ascent Rate'**
  String get diveLog_legend_label_ascentRate;

  /// No description provided for @diveLog_legend_label_ceiling.
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get diveLog_legend_label_ceiling;

  /// No description provided for @diveLog_legend_label_depth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get diveLog_legend_label_depth;

  /// No description provided for @diveLog_legend_label_events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get diveLog_legend_label_events;

  /// No description provided for @diveLog_legend_label_gasDensity.
  ///
  /// In en, this message translates to:
  /// **'Gas Density'**
  String get diveLog_legend_label_gasDensity;

  /// No description provided for @diveLog_legend_label_gasSwitches.
  ///
  /// In en, this message translates to:
  /// **'Gas Switches'**
  String get diveLog_legend_label_gasSwitches;

  /// No description provided for @diveLog_legend_label_gfPercent.
  ///
  /// In en, this message translates to:
  /// **'GF%'**
  String get diveLog_legend_label_gfPercent;

  /// No description provided for @diveLog_legend_label_heartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get diveLog_legend_label_heartRate;

  /// No description provided for @diveLog_legend_label_maxDepth.
  ///
  /// In en, this message translates to:
  /// **'Max Depth'**
  String get diveLog_legend_label_maxDepth;

  /// No description provided for @diveLog_legend_label_meanDepth.
  ///
  /// In en, this message translates to:
  /// **'Mean Depth'**
  String get diveLog_legend_label_meanDepth;

  /// No description provided for @diveLog_legend_label_mod.
  ///
  /// In en, this message translates to:
  /// **'MOD'**
  String get diveLog_legend_label_mod;

  /// No description provided for @diveLog_legend_label_ndl.
  ///
  /// In en, this message translates to:
  /// **'NDL'**
  String get diveLog_legend_label_ndl;

  /// No description provided for @diveLog_legend_label_ppHe.
  ///
  /// In en, this message translates to:
  /// **'ppHe'**
  String get diveLog_legend_label_ppHe;

  /// No description provided for @diveLog_legend_label_ppN2.
  ///
  /// In en, this message translates to:
  /// **'ppN2'**
  String get diveLog_legend_label_ppN2;

  /// No description provided for @diveLog_legend_label_ppO2.
  ///
  /// In en, this message translates to:
  /// **'ppO2'**
  String get diveLog_legend_label_ppO2;

  /// No description provided for @diveLog_legend_label_pressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get diveLog_legend_label_pressure;

  /// No description provided for @diveLog_legend_label_pressureThresholds.
  ///
  /// In en, this message translates to:
  /// **'Pressure Thresholds'**
  String get diveLog_legend_label_pressureThresholds;

  /// No description provided for @diveLog_legend_label_sacRate.
  ///
  /// In en, this message translates to:
  /// **'SAC Rate'**
  String get diveLog_legend_label_sacRate;

  /// No description provided for @diveLog_legend_label_surfaceGf.
  ///
  /// In en, this message translates to:
  /// **'Surface GF'**
  String get diveLog_legend_label_surfaceGf;

  /// No description provided for @diveLog_legend_label_temp.
  ///
  /// In en, this message translates to:
  /// **'Temp'**
  String get diveLog_legend_label_temp;

  /// No description provided for @diveLog_legend_label_tts.
  ///
  /// In en, this message translates to:
  /// **'TTS'**
  String get diveLog_legend_label_tts;

  /// No description provided for @diveLog_listPage_appBar_diveMap.
  ///
  /// In en, this message translates to:
  /// **'Dive Map'**
  String get diveLog_listPage_appBar_diveMap;

  /// No description provided for @diveLog_listPage_compactTitle.
  ///
  /// In en, this message translates to:
  /// **'Dives'**
  String get diveLog_listPage_compactTitle;

  /// No description provided for @diveLog_listPage_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String diveLog_listPage_errorLoading(Object error);

  /// No description provided for @diveLog_listPage_fab_logDive.
  ///
  /// In en, this message translates to:
  /// **'Log Dive'**
  String get diveLog_listPage_fab_logDive;

  /// No description provided for @diveLog_listPage_menuAdvancedSearch.
  ///
  /// In en, this message translates to:
  /// **'Advanced Search'**
  String get diveLog_listPage_menuAdvancedSearch;

  /// No description provided for @diveLog_listPage_menuDiveNumbering.
  ///
  /// In en, this message translates to:
  /// **'Dive Numbering'**
  String get diveLog_listPage_menuDiveNumbering;

  /// No description provided for @diveLog_listPage_searchFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Search dives...'**
  String get diveLog_listPage_searchFieldLabel;

  /// No description provided for @diveLog_listPage_searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No dives found for \"{query}\"'**
  String diveLog_listPage_searchNoResults(Object query);

  /// No description provided for @diveLog_listPage_searchSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Search by site, buddy, or notes'**
  String get diveLog_listPage_searchSuggestion;

  /// No description provided for @diveLog_listPage_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Log'**
  String get diveLog_listPage_title;

  /// No description provided for @diveLog_listPage_tooltip_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get diveLog_listPage_tooltip_back;

  /// No description provided for @diveLog_listPage_tooltip_backToDiveList.
  ///
  /// In en, this message translates to:
  /// **'Back to dive list'**
  String get diveLog_listPage_tooltip_backToDiveList;

  /// No description provided for @diveLog_listPage_tooltip_clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get diveLog_listPage_tooltip_clearSearch;

  /// No description provided for @diveLog_listPage_tooltip_filterDives.
  ///
  /// In en, this message translates to:
  /// **'Filter dives'**
  String get diveLog_listPage_tooltip_filterDives;

  /// No description provided for @diveLog_listPage_tooltip_listView.
  ///
  /// In en, this message translates to:
  /// **'List View'**
  String get diveLog_listPage_tooltip_listView;

  /// No description provided for @diveLog_listPage_tooltip_mapView.
  ///
  /// In en, this message translates to:
  /// **'Map View'**
  String get diveLog_listPage_tooltip_mapView;

  /// No description provided for @diveLog_listPage_tooltip_searchDives.
  ///
  /// In en, this message translates to:
  /// **'Search dives'**
  String get diveLog_listPage_tooltip_searchDives;

  /// No description provided for @diveLog_listPage_tooltip_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get diveLog_listPage_tooltip_sort;

  /// No description provided for @diveLog_listPage_unknownSite.
  ///
  /// In en, this message translates to:
  /// **'Unknown Site'**
  String get diveLog_listPage_unknownSite;

  /// No description provided for @diveLog_map_emptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log dives with location data to see your activity on the map'**
  String get diveLog_map_emptySubtitle;

  /// No description provided for @diveLog_map_emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No dive activity to display'**
  String get diveLog_map_emptyTitle;

  /// No description provided for @diveLog_map_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading dive data: {error}'**
  String diveLog_map_errorLoading(Object error);

  /// No description provided for @diveLog_map_tooltip_fitAllSites.
  ///
  /// In en, this message translates to:
  /// **'Fit All Sites'**
  String get diveLog_map_tooltip_fitAllSites;

  /// No description provided for @diveLog_numbering_actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get diveLog_numbering_actions;

  /// No description provided for @diveLog_numbering_allCorrect.
  ///
  /// In en, this message translates to:
  /// **'All dives numbered correctly'**
  String get diveLog_numbering_allCorrect;

  /// No description provided for @diveLog_numbering_assignMissing.
  ///
  /// In en, this message translates to:
  /// **'Assign missing numbers'**
  String get diveLog_numbering_assignMissing;

  /// No description provided for @diveLog_numbering_assignMissingDesc.
  ///
  /// In en, this message translates to:
  /// **'Number unnumbered dives starting after the last numbered dive'**
  String get diveLog_numbering_assignMissingDesc;

  /// No description provided for @diveLog_numbering_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get diveLog_numbering_close;

  /// No description provided for @diveLog_numbering_gapsDetected.
  ///
  /// In en, this message translates to:
  /// **'Gaps Detected'**
  String get diveLog_numbering_gapsDetected;

  /// No description provided for @diveLog_numbering_issuesDetected.
  ///
  /// In en, this message translates to:
  /// **'Issues detected'**
  String get diveLog_numbering_issuesDetected;

  /// No description provided for @diveLog_numbering_missingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} missing'**
  String diveLog_numbering_missingCount(Object count);

  /// No description provided for @diveLog_numbering_renumberAll.
  ///
  /// In en, this message translates to:
  /// **'Renumber all dives'**
  String get diveLog_numbering_renumberAll;

  /// No description provided for @diveLog_numbering_renumberAllDesc.
  ///
  /// In en, this message translates to:
  /// **'Assign sequential numbers based on dive date/time'**
  String get diveLog_numbering_renumberAllDesc;

  /// No description provided for @diveLog_numbering_renumberDialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diveLog_numbering_renumberDialog_cancel;

  /// No description provided for @diveLog_numbering_renumberDialog_content.
  ///
  /// In en, this message translates to:
  /// **'This will renumber all dives sequentially based on their entry date/time. This action cannot be undone.'**
  String get diveLog_numbering_renumberDialog_content;

  /// No description provided for @diveLog_numbering_renumberDialog_renumber.
  ///
  /// In en, this message translates to:
  /// **'Renumber'**
  String get diveLog_numbering_renumberDialog_renumber;

  /// No description provided for @diveLog_numbering_renumberDialog_startFrom.
  ///
  /// In en, this message translates to:
  /// **'Start from number'**
  String get diveLog_numbering_renumberDialog_startFrom;

  /// No description provided for @diveLog_numbering_renumberDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Renumber All Dives'**
  String get diveLog_numbering_renumberDialog_title;

  /// No description provided for @diveLog_numbering_snackbar_assigned.
  ///
  /// In en, this message translates to:
  /// **'Missing dive numbers assigned'**
  String get diveLog_numbering_snackbar_assigned;

  /// No description provided for @diveLog_numbering_snackbar_renumbered.
  ///
  /// In en, this message translates to:
  /// **'All dives renumbered starting from #{number}'**
  String diveLog_numbering_snackbar_renumbered(Object number);

  /// No description provided for @diveLog_numbering_summary.
  ///
  /// In en, this message translates to:
  /// **'{total} total dives • {numbered} numbered'**
  String diveLog_numbering_summary(Object total, Object numbered);

  /// No description provided for @diveLog_numbering_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Numbering'**
  String get diveLog_numbering_title;

  /// No description provided for @diveLog_numbering_unnumberedDives.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{dive} other{dives}} without numbers'**
  String diveLog_numbering_unnumberedDives(int count);

  /// No description provided for @diveLog_o2tox_badge_critical.
  ///
  /// In en, this message translates to:
  /// **'CRITICAL'**
  String get diveLog_o2tox_badge_critical;

  /// No description provided for @diveLog_o2tox_badge_warning.
  ///
  /// In en, this message translates to:
  /// **'WARNING'**
  String get diveLog_o2tox_badge_warning;

  /// No description provided for @diveLog_o2tox_cnsBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'CNS {value}'**
  String diveLog_o2tox_cnsBadgeLabel(Object value);

  /// No description provided for @diveLog_o2tox_cnsOxygenClock.
  ///
  /// In en, this message translates to:
  /// **'CNS Oxygen Clock'**
  String get diveLog_o2tox_cnsOxygenClock;

  /// No description provided for @diveLog_o2tox_deltaDive.
  ///
  /// In en, this message translates to:
  /// **'+{value}% this dive'**
  String diveLog_o2tox_deltaDive(Object value);

  /// No description provided for @diveLog_o2tox_details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get diveLog_o2tox_details;

  /// No description provided for @diveLog_o2tox_label_maxPpO2.
  ///
  /// In en, this message translates to:
  /// **'Max ppO2'**
  String get diveLog_o2tox_label_maxPpO2;

  /// No description provided for @diveLog_o2tox_label_maxPpO2Depth.
  ///
  /// In en, this message translates to:
  /// **'Max ppO2 Depth'**
  String get diveLog_o2tox_label_maxPpO2Depth;

  /// No description provided for @diveLog_o2tox_label_timeAbove14.
  ///
  /// In en, this message translates to:
  /// **'Time above 1.4 bar'**
  String get diveLog_o2tox_label_timeAbove14;

  /// No description provided for @diveLog_o2tox_label_timeAbove16.
  ///
  /// In en, this message translates to:
  /// **'Time above 1.6 bar'**
  String get diveLog_o2tox_label_timeAbove16;

  /// No description provided for @diveLog_o2tox_ofDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'of daily limit'**
  String get diveLog_o2tox_ofDailyLimit;

  /// No description provided for @diveLog_o2tox_oxygenToleranceUnits.
  ///
  /// In en, this message translates to:
  /// **'Oxygen Tolerance Units'**
  String get diveLog_o2tox_oxygenToleranceUnits;

  /// No description provided for @diveLog_o2tox_semantics_cnsBadge.
  ///
  /// In en, this message translates to:
  /// **'CNS oxygen toxicity {value}'**
  String diveLog_o2tox_semantics_cnsBadge(Object value);

  /// No description provided for @diveLog_o2tox_semantics_criticalWarning.
  ///
  /// In en, this message translates to:
  /// **'Critical oxygen toxicity warning'**
  String get diveLog_o2tox_semantics_criticalWarning;

  /// No description provided for @diveLog_o2tox_semantics_otu.
  ///
  /// In en, this message translates to:
  /// **'Oxygen Tolerance Units: {value}, {percent} percent of daily limit'**
  String diveLog_o2tox_semantics_otu(Object value, Object percent);

  /// No description provided for @diveLog_o2tox_semantics_warning.
  ///
  /// In en, this message translates to:
  /// **'Oxygen toxicity warning'**
  String get diveLog_o2tox_semantics_warning;

  /// No description provided for @diveLog_o2tox_startPercent.
  ///
  /// In en, this message translates to:
  /// **'Start: {value}%'**
  String diveLog_o2tox_startPercent(Object value);

  /// No description provided for @diveLog_o2tox_title.
  ///
  /// In en, this message translates to:
  /// **'Oxygen Toxicity'**
  String get diveLog_o2tox_title;

  /// No description provided for @diveLog_playbackStats_deco.
  ///
  /// In en, this message translates to:
  /// **'DECO'**
  String get diveLog_playbackStats_deco;

  /// No description provided for @diveLog_playbackStats_depth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get diveLog_playbackStats_depth;

  /// No description provided for @diveLog_playbackStats_header.
  ///
  /// In en, this message translates to:
  /// **'Live Stats'**
  String get diveLog_playbackStats_header;

  /// No description provided for @diveLog_playbackStats_heartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get diveLog_playbackStats_heartRate;

  /// No description provided for @diveLog_playbackStats_ndl.
  ///
  /// In en, this message translates to:
  /// **'NDL'**
  String get diveLog_playbackStats_ndl;

  /// No description provided for @diveLog_playbackStats_ppO2.
  ///
  /// In en, this message translates to:
  /// **'ppO₂'**
  String get diveLog_playbackStats_ppO2;

  /// No description provided for @diveLog_playbackStats_pressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get diveLog_playbackStats_pressure;

  /// No description provided for @diveLog_playbackStats_temp.
  ///
  /// In en, this message translates to:
  /// **'Temp'**
  String get diveLog_playbackStats_temp;

  /// No description provided for @diveLog_playback_sliderLabel.
  ///
  /// In en, this message translates to:
  /// **'Playback position'**
  String get diveLog_playback_sliderLabel;

  /// No description provided for @diveLog_playback_speed_label.
  ///
  /// In en, this message translates to:
  /// **'{speed}x'**
  String diveLog_playback_speed_label(Object speed);

  /// No description provided for @diveLog_playback_stepThrough.
  ///
  /// In en, this message translates to:
  /// **'Step-through Playback'**
  String get diveLog_playback_stepThrough;

  /// No description provided for @diveLog_playback_tooltip_back10.
  ///
  /// In en, this message translates to:
  /// **'Back 10 seconds'**
  String get diveLog_playback_tooltip_back10;

  /// No description provided for @diveLog_playback_tooltip_exit.
  ///
  /// In en, this message translates to:
  /// **'Exit playback mode'**
  String get diveLog_playback_tooltip_exit;

  /// No description provided for @diveLog_playback_tooltip_forward10.
  ///
  /// In en, this message translates to:
  /// **'Forward 10 seconds'**
  String get diveLog_playback_tooltip_forward10;

  /// No description provided for @diveLog_playback_tooltip_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get diveLog_playback_tooltip_pause;

  /// No description provided for @diveLog_playback_tooltip_play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get diveLog_playback_tooltip_play;

  /// No description provided for @diveLog_playback_tooltip_skipEnd.
  ///
  /// In en, this message translates to:
  /// **'Skip to end'**
  String get diveLog_playback_tooltip_skipEnd;

  /// No description provided for @diveLog_playback_tooltip_skipStart.
  ///
  /// In en, this message translates to:
  /// **'Skip to start'**
  String get diveLog_playback_tooltip_skipStart;

  /// No description provided for @diveLog_playback_tooltip_speed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get diveLog_playback_tooltip_speed;

  /// No description provided for @diveLog_profileSelector_badge_primary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get diveLog_profileSelector_badge_primary;

  /// No description provided for @diveLog_profileSelector_label_diveComputers.
  ///
  /// In en, this message translates to:
  /// **'Dive Computers'**
  String get diveLog_profileSelector_label_diveComputers;

  /// No description provided for @diveLog_profile_axisDepth.
  ///
  /// In en, this message translates to:
  /// **'Depth ({unit})'**
  String diveLog_profile_axisDepth(Object unit);

  /// No description provided for @diveLog_profile_axisTime.
  ///
  /// In en, this message translates to:
  /// **'Time (min)'**
  String get diveLog_profile_axisTime;

  /// No description provided for @diveLog_profile_emptyState.
  ///
  /// In en, this message translates to:
  /// **'No dive profile data'**
  String get diveLog_profile_emptyState;

  /// No description provided for @diveLog_profile_rightAxis_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get diveLog_profile_rightAxis_none;

  /// No description provided for @diveLog_profile_semantics_changeRightAxis.
  ///
  /// In en, this message translates to:
  /// **'Change right axis metric'**
  String get diveLog_profile_semantics_changeRightAxis;

  /// No description provided for @diveLog_profile_semantics_chart.
  ///
  /// In en, this message translates to:
  /// **'Dive profile chart, pinch to zoom'**
  String get diveLog_profile_semantics_chart;

  /// No description provided for @diveLog_profile_tooltip_moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More chart options'**
  String get diveLog_profile_tooltip_moreOptions;

  /// No description provided for @diveLog_profile_tooltip_resetZoom.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get diveLog_profile_tooltip_resetZoom;

  /// No description provided for @diveLog_profile_tooltip_zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get diveLog_profile_tooltip_zoomIn;

  /// No description provided for @diveLog_profile_tooltip_zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get diveLog_profile_tooltip_zoomOut;

  /// No description provided for @diveLog_profile_zoomHint.
  ///
  /// In en, this message translates to:
  /// **'Zoom: {level}x • Pinch or scroll to zoom, drag to pan'**
  String diveLog_profile_zoomHint(Object level);

  /// No description provided for @diveLog_rangeSelection_exitRange.
  ///
  /// In en, this message translates to:
  /// **'Exit Range'**
  String get diveLog_rangeSelection_exitRange;

  /// No description provided for @diveLog_rangeSelection_selectRange.
  ///
  /// In en, this message translates to:
  /// **'Select Range'**
  String get diveLog_rangeSelection_selectRange;

  /// No description provided for @diveLog_rangeSelection_semantics_adjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust range selection'**
  String get diveLog_rangeSelection_semantics_adjust;

  /// No description provided for @diveLog_rangeStats_header_avg.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get diveLog_rangeStats_header_avg;

  /// No description provided for @diveLog_rangeStats_header_max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get diveLog_rangeStats_header_max;

  /// No description provided for @diveLog_rangeStats_header_min.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get diveLog_rangeStats_header_min;

  /// No description provided for @diveLog_rangeStats_label_depth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get diveLog_rangeStats_label_depth;

  /// No description provided for @diveLog_rangeStats_label_heartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get diveLog_rangeStats_label_heartRate;

  /// No description provided for @diveLog_rangeStats_label_pressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get diveLog_rangeStats_label_pressure;

  /// No description provided for @diveLog_rangeStats_label_temp.
  ///
  /// In en, this message translates to:
  /// **'Temp'**
  String get diveLog_rangeStats_label_temp;

  /// No description provided for @diveLog_rangeStats_title.
  ///
  /// In en, this message translates to:
  /// **'Range Analysis'**
  String get diveLog_rangeStats_title;

  /// No description provided for @diveLog_rangeStats_tooltip_close.
  ///
  /// In en, this message translates to:
  /// **'Close range analysis'**
  String get diveLog_rangeStats_tooltip_close;

  /// No description provided for @diveLog_scr_calculatedLoopFo2.
  ///
  /// In en, this message translates to:
  /// **'Calculated loop FO₂: {value}%'**
  String diveLog_scr_calculatedLoopFo2(Object value);

  /// No description provided for @diveLog_scr_hint_additionRatio.
  ///
  /// In en, this message translates to:
  /// **'e.g., 0.33 (1:3)'**
  String get diveLog_scr_hint_additionRatio;

  /// No description provided for @diveLog_scr_label_additionRatio.
  ///
  /// In en, this message translates to:
  /// **'Addition Ratio'**
  String get diveLog_scr_label_additionRatio;

  /// No description provided for @diveLog_scr_label_assumedVo2.
  ///
  /// In en, this message translates to:
  /// **'Assumed VO₂'**
  String get diveLog_scr_label_assumedVo2;

  /// No description provided for @diveLog_scr_label_avg.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get diveLog_scr_label_avg;

  /// No description provided for @diveLog_scr_label_injectionRate.
  ///
  /// In en, this message translates to:
  /// **'Injection Rate'**
  String get diveLog_scr_label_injectionRate;

  /// No description provided for @diveLog_scr_label_max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get diveLog_scr_label_max;

  /// No description provided for @diveLog_scr_label_min.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get diveLog_scr_label_min;

  /// No description provided for @diveLog_scr_label_orificeSize.
  ///
  /// In en, this message translates to:
  /// **'Orifice Size'**
  String get diveLog_scr_label_orificeSize;

  /// No description provided for @diveLog_scr_sectionCmf.
  ///
  /// In en, this message translates to:
  /// **'CMF Parameters'**
  String get diveLog_scr_sectionCmf;

  /// No description provided for @diveLog_scr_sectionEscr.
  ///
  /// In en, this message translates to:
  /// **'ESCR Parameters'**
  String get diveLog_scr_sectionEscr;

  /// No description provided for @diveLog_scr_sectionMeasuredLoopO2.
  ///
  /// In en, this message translates to:
  /// **'Measured Loop O₂ (optional)'**
  String get diveLog_scr_sectionMeasuredLoopO2;

  /// No description provided for @diveLog_scr_sectionPascr.
  ///
  /// In en, this message translates to:
  /// **'PASCR Parameters'**
  String get diveLog_scr_sectionPascr;

  /// No description provided for @diveLog_scr_sectionScrType.
  ///
  /// In en, this message translates to:
  /// **'SCR Type'**
  String get diveLog_scr_sectionScrType;

  /// No description provided for @diveLog_scr_sectionSupplyGas.
  ///
  /// In en, this message translates to:
  /// **'Supply Gas'**
  String get diveLog_scr_sectionSupplyGas;

  /// No description provided for @diveLog_scr_title.
  ///
  /// In en, this message translates to:
  /// **'SCR Settings'**
  String get diveLog_scr_title;

  /// No description provided for @diveLog_search_allCenters.
  ///
  /// In en, this message translates to:
  /// **'All centers'**
  String get diveLog_search_allCenters;

  /// No description provided for @diveLog_search_allTrips.
  ///
  /// In en, this message translates to:
  /// **'All trips'**
  String get diveLog_search_allTrips;

  /// No description provided for @diveLog_search_appBar.
  ///
  /// In en, this message translates to:
  /// **'Advanced Search'**
  String get diveLog_search_appBar;

  /// No description provided for @diveLog_search_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diveLog_search_cancel;

  /// No description provided for @diveLog_search_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get diveLog_search_clearAll;

  /// No description provided for @diveLog_search_end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get diveLog_search_end;

  /// No description provided for @diveLog_search_errorLoadingCenters.
  ///
  /// In en, this message translates to:
  /// **'Error loading dive centers'**
  String get diveLog_search_errorLoadingCenters;

  /// No description provided for @diveLog_search_errorLoadingDiveTypes.
  ///
  /// In en, this message translates to:
  /// **'Error loading dive types'**
  String get diveLog_search_errorLoadingDiveTypes;

  /// No description provided for @diveLog_search_errorLoadingTrips.
  ///
  /// In en, this message translates to:
  /// **'Error loading trips'**
  String get diveLog_search_errorLoadingTrips;

  /// No description provided for @diveLog_search_gasTrimix.
  ///
  /// In en, this message translates to:
  /// **'Trimix (<21% O₂)'**
  String get diveLog_search_gasTrimix;

  /// No description provided for @diveLog_search_label_depthRange.
  ///
  /// In en, this message translates to:
  /// **'Depth Range (m)'**
  String get diveLog_search_label_depthRange;

  /// No description provided for @diveLog_search_label_diveCenter.
  ///
  /// In en, this message translates to:
  /// **'Dive Center'**
  String get diveLog_search_label_diveCenter;

  /// No description provided for @diveLog_search_label_diveSite.
  ///
  /// In en, this message translates to:
  /// **'Dive Site'**
  String get diveLog_search_label_diveSite;

  /// No description provided for @diveLog_search_label_diveType.
  ///
  /// In en, this message translates to:
  /// **'Dive Type'**
  String get diveLog_search_label_diveType;

  /// No description provided for @diveLog_search_label_durationRange.
  ///
  /// In en, this message translates to:
  /// **'Duration Range (min)'**
  String get diveLog_search_label_durationRange;

  /// No description provided for @diveLog_search_label_trip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get diveLog_search_label_trip;

  /// No description provided for @diveLog_search_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get diveLog_search_search;

  /// No description provided for @diveLog_search_section_conditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get diveLog_search_section_conditions;

  /// No description provided for @diveLog_search_section_dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get diveLog_search_section_dateRange;

  /// No description provided for @diveLog_search_section_gasEquipment.
  ///
  /// In en, this message translates to:
  /// **'Gas & Equipment'**
  String get diveLog_search_section_gasEquipment;

  /// No description provided for @diveLog_search_section_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get diveLog_search_section_location;

  /// No description provided for @diveLog_search_section_organization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get diveLog_search_section_organization;

  /// No description provided for @diveLog_search_section_social.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get diveLog_search_section_social;

  /// No description provided for @diveLog_search_start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get diveLog_search_start;

  /// No description provided for @diveLog_selection_countSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String diveLog_selection_countSelected(Object count);

  /// No description provided for @diveLog_selection_tooltip_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get diveLog_selection_tooltip_delete;

  /// No description provided for @diveLog_selection_tooltip_deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get diveLog_selection_tooltip_deselectAll;

  /// No description provided for @diveLog_selection_tooltip_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit Selected'**
  String get diveLog_selection_tooltip_edit;

  /// No description provided for @diveLog_selection_tooltip_exit.
  ///
  /// In en, this message translates to:
  /// **'Exit selection'**
  String get diveLog_selection_tooltip_exit;

  /// No description provided for @diveLog_selection_tooltip_export.
  ///
  /// In en, this message translates to:
  /// **'Export Selected'**
  String get diveLog_selection_tooltip_export;

  /// No description provided for @diveLog_selection_tooltip_selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get diveLog_selection_tooltip_selectAll;

  /// No description provided for @diveLog_sighting_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get diveLog_sighting_add;

  /// No description provided for @diveLog_sighting_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diveLog_sighting_cancel;

  /// No description provided for @diveLog_sighting_notesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., size, behavior, location...'**
  String get diveLog_sighting_notesHint;

  /// No description provided for @diveLog_sighting_notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get diveLog_sighting_notesOptional;

  /// No description provided for @diveLog_sitePicker_addDiveSite.
  ///
  /// In en, this message translates to:
  /// **'Add Dive Site'**
  String get diveLog_sitePicker_addDiveSite;

  /// No description provided for @diveLog_sitePicker_distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{distance} km away'**
  String diveLog_sitePicker_distanceKm(Object distance);

  /// No description provided for @diveLog_sitePicker_distanceMeters.
  ///
  /// In en, this message translates to:
  /// **'{distance} m away'**
  String diveLog_sitePicker_distanceMeters(Object distance);

  /// No description provided for @diveLog_sitePicker_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading sites: {error}'**
  String diveLog_sitePicker_errorLoading(Object error);

  /// No description provided for @diveLog_sitePicker_newDiveSite.
  ///
  /// In en, this message translates to:
  /// **'New Dive Site'**
  String get diveLog_sitePicker_newDiveSite;

  /// No description provided for @diveLog_sitePicker_noSites.
  ///
  /// In en, this message translates to:
  /// **'No dive sites yet'**
  String get diveLog_sitePicker_noSites;

  /// No description provided for @diveLog_sitePicker_sortedByDistance.
  ///
  /// In en, this message translates to:
  /// **'Sorted by distance'**
  String get diveLog_sitePicker_sortedByDistance;

  /// No description provided for @diveLog_sitePicker_title.
  ///
  /// In en, this message translates to:
  /// **'Select Dive Site'**
  String get diveLog_sitePicker_title;

  /// No description provided for @diveLog_sort_title.
  ///
  /// In en, this message translates to:
  /// **'Sort Dives'**
  String get diveLog_sort_title;

  /// No description provided for @diveLog_speciesPicker_addNew.
  ///
  /// In en, this message translates to:
  /// **'Add \"{name}\" as new species'**
  String diveLog_speciesPicker_addNew(Object name);

  /// No description provided for @diveLog_speciesPicker_noResults.
  ///
  /// In en, this message translates to:
  /// **'No species found'**
  String get diveLog_speciesPicker_noResults;

  /// No description provided for @diveLog_speciesPicker_noSpecies.
  ///
  /// In en, this message translates to:
  /// **'No species available'**
  String get diveLog_speciesPicker_noSpecies;

  /// No description provided for @diveLog_speciesPicker_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search species...'**
  String get diveLog_speciesPicker_searchHint;

  /// No description provided for @diveLog_speciesPicker_title.
  ///
  /// In en, this message translates to:
  /// **'Add Marine Life'**
  String get diveLog_speciesPicker_title;

  /// No description provided for @diveLog_speciesPicker_tooltip_clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get diveLog_speciesPicker_tooltip_clearSearch;

  /// No description provided for @diveLog_summary_action_importComputer.
  ///
  /// In en, this message translates to:
  /// **'Import from Computer'**
  String get diveLog_summary_action_importComputer;

  /// No description provided for @diveLog_summary_action_logDive.
  ///
  /// In en, this message translates to:
  /// **'Log Dive'**
  String get diveLog_summary_action_logDive;

  /// No description provided for @diveLog_summary_action_viewStats.
  ///
  /// In en, this message translates to:
  /// **'View Statistics'**
  String get diveLog_summary_action_viewStats;

  /// No description provided for @diveLog_summary_diveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{dive} other{dives}}'**
  String diveLog_summary_diveCount(int count);

  /// No description provided for @diveLog_summary_overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get diveLog_summary_overview;

  /// No description provided for @diveLog_summary_record_coldest.
  ///
  /// In en, this message translates to:
  /// **'Coldest Dive'**
  String get diveLog_summary_record_coldest;

  /// No description provided for @diveLog_summary_record_deepest.
  ///
  /// In en, this message translates to:
  /// **'Deepest Dive'**
  String get diveLog_summary_record_deepest;

  /// No description provided for @diveLog_summary_record_longest.
  ///
  /// In en, this message translates to:
  /// **'Longest Dive'**
  String get diveLog_summary_record_longest;

  /// No description provided for @diveLog_summary_record_warmest.
  ///
  /// In en, this message translates to:
  /// **'Warmest Dive'**
  String get diveLog_summary_record_warmest;

  /// No description provided for @diveLog_summary_section_mostVisited.
  ///
  /// In en, this message translates to:
  /// **'Most Visited Sites'**
  String get diveLog_summary_section_mostVisited;

  /// No description provided for @diveLog_summary_section_quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get diveLog_summary_section_quickActions;

  /// No description provided for @diveLog_summary_section_records.
  ///
  /// In en, this message translates to:
  /// **'Personal Records'**
  String get diveLog_summary_section_records;

  /// No description provided for @diveLog_summary_selectDive.
  ///
  /// In en, this message translates to:
  /// **'Select a dive from the list to view details'**
  String get diveLog_summary_selectDive;

  /// No description provided for @diveLog_summary_stat_avgMaxDepth.
  ///
  /// In en, this message translates to:
  /// **'Avg Max Depth'**
  String get diveLog_summary_stat_avgMaxDepth;

  /// No description provided for @diveLog_summary_stat_avgWaterTemp.
  ///
  /// In en, this message translates to:
  /// **'Avg Water Temp'**
  String get diveLog_summary_stat_avgWaterTemp;

  /// No description provided for @diveLog_summary_stat_diveSites.
  ///
  /// In en, this message translates to:
  /// **'Dive Sites'**
  String get diveLog_summary_stat_diveSites;

  /// No description provided for @diveLog_summary_stat_diveTime.
  ///
  /// In en, this message translates to:
  /// **'Dive Time'**
  String get diveLog_summary_stat_diveTime;

  /// No description provided for @diveLog_summary_stat_maxDepth.
  ///
  /// In en, this message translates to:
  /// **'Max Depth'**
  String get diveLog_summary_stat_maxDepth;

  /// No description provided for @diveLog_summary_stat_totalDives.
  ///
  /// In en, this message translates to:
  /// **'Total Dives'**
  String get diveLog_summary_stat_totalDives;

  /// No description provided for @diveLog_summary_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Log Summary'**
  String get diveLog_summary_title;

  /// No description provided for @diveLog_tank_label_endPressure.
  ///
  /// In en, this message translates to:
  /// **'End Pressure'**
  String get diveLog_tank_label_endPressure;

  /// No description provided for @diveLog_tank_label_he.
  ///
  /// In en, this message translates to:
  /// **'He'**
  String get diveLog_tank_label_he;

  /// No description provided for @diveLog_tank_label_material.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get diveLog_tank_label_material;

  /// No description provided for @diveLog_tank_label_n2.
  ///
  /// In en, this message translates to:
  /// **'N2'**
  String get diveLog_tank_label_n2;

  /// No description provided for @diveLog_tank_label_o2.
  ///
  /// In en, this message translates to:
  /// **'O2'**
  String get diveLog_tank_label_o2;

  /// No description provided for @diveLog_tank_label_role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get diveLog_tank_label_role;

  /// No description provided for @diveLog_tank_label_startPressure.
  ///
  /// In en, this message translates to:
  /// **'Start Pressure'**
  String get diveLog_tank_label_startPressure;

  /// No description provided for @diveLog_tank_label_tankPreset.
  ///
  /// In en, this message translates to:
  /// **'Tank Preset'**
  String get diveLog_tank_label_tankPreset;

  /// No description provided for @diveLog_tank_label_volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get diveLog_tank_label_volume;

  /// No description provided for @diveLog_tank_label_workingPressure.
  ///
  /// In en, this message translates to:
  /// **'Working P'**
  String get diveLog_tank_label_workingPressure;

  /// No description provided for @diveLog_tank_modInfo.
  ///
  /// In en, this message translates to:
  /// **'MOD: {depth} (ppO2 1.4)'**
  String diveLog_tank_modInfo(Object depth);

  /// No description provided for @diveLog_tank_section_gasMix.
  ///
  /// In en, this message translates to:
  /// **'Gas Mix'**
  String get diveLog_tank_section_gasMix;

  /// No description provided for @diveLog_tank_selectPreset.
  ///
  /// In en, this message translates to:
  /// **'Select Preset...'**
  String get diveLog_tank_selectPreset;

  /// No description provided for @diveLog_tank_title.
  ///
  /// In en, this message translates to:
  /// **'Tank {number}'**
  String diveLog_tank_title(Object number);

  /// No description provided for @diveLog_tank_tooltip_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove tank'**
  String get diveLog_tank_tooltip_remove;

  /// No description provided for @diveLog_tissue_label_ceiling.
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get diveLog_tissue_label_ceiling;

  /// No description provided for @diveLog_tissue_label_gf.
  ///
  /// In en, this message translates to:
  /// **'GF'**
  String get diveLog_tissue_label_gf;

  /// No description provided for @diveLog_tissue_label_ndl.
  ///
  /// In en, this message translates to:
  /// **'NDL'**
  String get diveLog_tissue_label_ndl;

  /// No description provided for @diveLog_tissue_label_tts.
  ///
  /// In en, this message translates to:
  /// **'TTS'**
  String get diveLog_tissue_label_tts;

  /// No description provided for @diveLog_tissue_legend_he.
  ///
  /// In en, this message translates to:
  /// **'He'**
  String get diveLog_tissue_legend_he;

  /// No description provided for @diveLog_tissue_legend_mValue.
  ///
  /// In en, this message translates to:
  /// **'100% M-value'**
  String get diveLog_tissue_legend_mValue;

  /// No description provided for @diveLog_tissue_legend_n2.
  ///
  /// In en, this message translates to:
  /// **'N₂'**
  String get diveLog_tissue_legend_n2;

  /// No description provided for @diveLog_tissue_title.
  ///
  /// In en, this message translates to:
  /// **'Tissue Loading'**
  String get diveLog_tissue_title;

  /// No description provided for @diveLog_tooltip_ceiling.
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get diveLog_tooltip_ceiling;

  /// No description provided for @diveLog_tooltip_density.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get diveLog_tooltip_density;

  /// No description provided for @diveLog_tooltip_depth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get diveLog_tooltip_depth;

  /// No description provided for @diveLog_tooltip_gfPercent.
  ///
  /// In en, this message translates to:
  /// **'GF%'**
  String get diveLog_tooltip_gfPercent;

  /// No description provided for @diveLog_tooltip_hr.
  ///
  /// In en, this message translates to:
  /// **'HR'**
  String get diveLog_tooltip_hr;

  /// No description provided for @diveLog_tooltip_marker.
  ///
  /// In en, this message translates to:
  /// **'Marker'**
  String get diveLog_tooltip_marker;

  /// No description provided for @diveLog_tooltip_mean.
  ///
  /// In en, this message translates to:
  /// **'Mean'**
  String get diveLog_tooltip_mean;

  /// No description provided for @diveLog_tooltip_mod.
  ///
  /// In en, this message translates to:
  /// **'MOD'**
  String get diveLog_tooltip_mod;

  /// No description provided for @diveLog_tooltip_ndl.
  ///
  /// In en, this message translates to:
  /// **'NDL'**
  String get diveLog_tooltip_ndl;

  /// No description provided for @diveLog_tooltip_ppHe.
  ///
  /// In en, this message translates to:
  /// **'ppHe'**
  String get diveLog_tooltip_ppHe;

  /// No description provided for @diveLog_tooltip_ppN2.
  ///
  /// In en, this message translates to:
  /// **'ppN2'**
  String get diveLog_tooltip_ppN2;

  /// No description provided for @diveLog_tooltip_ppO2.
  ///
  /// In en, this message translates to:
  /// **'ppO2'**
  String get diveLog_tooltip_ppO2;

  /// No description provided for @diveLog_tooltip_press.
  ///
  /// In en, this message translates to:
  /// **'Press'**
  String get diveLog_tooltip_press;

  /// No description provided for @diveLog_tooltip_rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get diveLog_tooltip_rate;

  /// No description provided for @diveLog_tooltip_sac.
  ///
  /// In en, this message translates to:
  /// **'SAC'**
  String get diveLog_tooltip_sac;

  /// No description provided for @diveLog_tooltip_srfGf.
  ///
  /// In en, this message translates to:
  /// **'SrfGF'**
  String get diveLog_tooltip_srfGf;

  /// No description provided for @diveLog_tooltip_temp.
  ///
  /// In en, this message translates to:
  /// **'Temp'**
  String get diveLog_tooltip_temp;

  /// No description provided for @diveLog_tooltip_time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get diveLog_tooltip_time;

  /// No description provided for @diveLog_tooltip_tts.
  ///
  /// In en, this message translates to:
  /// **'TTS'**
  String get diveLog_tooltip_tts;

  /// No description provided for @divePlanner_action_addTank.
  ///
  /// In en, this message translates to:
  /// **'Add Tank'**
  String get divePlanner_action_addTank;

  /// No description provided for @divePlanner_action_convertToDive.
  ///
  /// In en, this message translates to:
  /// **'Convert to Dive'**
  String get divePlanner_action_convertToDive;

  /// No description provided for @divePlanner_action_editTank.
  ///
  /// In en, this message translates to:
  /// **'Edit Tank'**
  String get divePlanner_action_editTank;

  /// No description provided for @divePlanner_action_moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get divePlanner_action_moreOptions;

  /// No description provided for @divePlanner_action_quickPlan.
  ///
  /// In en, this message translates to:
  /// **'Quick Plan'**
  String get divePlanner_action_quickPlan;

  /// No description provided for @divePlanner_action_renamePlan.
  ///
  /// In en, this message translates to:
  /// **'Rename Plan'**
  String get divePlanner_action_renamePlan;

  /// No description provided for @divePlanner_action_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get divePlanner_action_reset;

  /// No description provided for @divePlanner_action_resetPlan.
  ///
  /// In en, this message translates to:
  /// **'Reset Plan'**
  String get divePlanner_action_resetPlan;

  /// No description provided for @divePlanner_action_savePlan.
  ///
  /// In en, this message translates to:
  /// **'Save Plan'**
  String get divePlanner_action_savePlan;

  /// No description provided for @divePlanner_error_cannotConvert.
  ///
  /// In en, this message translates to:
  /// **'Cannot convert: plan has critical warnings'**
  String get divePlanner_error_cannotConvert;

  /// No description provided for @divePlanner_field_hePercent.
  ///
  /// In en, this message translates to:
  /// **'He %'**
  String get divePlanner_field_hePercent;

  /// No description provided for @divePlanner_field_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get divePlanner_field_name;

  /// No description provided for @divePlanner_field_o2Percent.
  ///
  /// In en, this message translates to:
  /// **'O₂ %'**
  String get divePlanner_field_o2Percent;

  /// No description provided for @divePlanner_field_planName.
  ///
  /// In en, this message translates to:
  /// **'Plan Name'**
  String get divePlanner_field_planName;

  /// No description provided for @divePlanner_field_role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get divePlanner_field_role;

  /// No description provided for @divePlanner_field_startPressure.
  ///
  /// In en, this message translates to:
  /// **'Start ({pressureSymbol})'**
  String divePlanner_field_startPressure(Object pressureSymbol);

  /// No description provided for @divePlanner_field_volume.
  ///
  /// In en, this message translates to:
  /// **'Volume ({volumeSymbol})'**
  String divePlanner_field_volume(Object volumeSymbol);

  /// No description provided for @divePlanner_hint_tankName.
  ///
  /// In en, this message translates to:
  /// **'Enter tank name'**
  String get divePlanner_hint_tankName;

  /// No description provided for @divePlanner_label_altitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude:'**
  String get divePlanner_label_altitude;

  /// No description provided for @divePlanner_label_belowMinReserve.
  ///
  /// In en, this message translates to:
  /// **'Below Min Reserve'**
  String get divePlanner_label_belowMinReserve;

  /// No description provided for @divePlanner_label_ceiling.
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get divePlanner_label_ceiling;

  /// No description provided for @divePlanner_label_consumption.
  ///
  /// In en, this message translates to:
  /// **'Consumption'**
  String get divePlanner_label_consumption;

  /// No description provided for @divePlanner_label_deco.
  ///
  /// In en, this message translates to:
  /// **'DECO'**
  String get divePlanner_label_deco;

  /// No description provided for @divePlanner_label_decoSchedule.
  ///
  /// In en, this message translates to:
  /// **'Decompression Schedule'**
  String get divePlanner_label_decoSchedule;

  /// No description provided for @divePlanner_label_decompression.
  ///
  /// In en, this message translates to:
  /// **'Decompression'**
  String get divePlanner_label_decompression;

  /// No description provided for @divePlanner_label_depthAxis.
  ///
  /// In en, this message translates to:
  /// **'Depth ({depthSymbol})'**
  String divePlanner_label_depthAxis(Object depthSymbol);

  /// No description provided for @divePlanner_label_diveProfile.
  ///
  /// In en, this message translates to:
  /// **'Dive Profile'**
  String get divePlanner_label_diveProfile;

  /// No description provided for @divePlanner_label_empty.
  ///
  /// In en, this message translates to:
  /// **'EMPTY'**
  String get divePlanner_label_empty;

  /// No description provided for @divePlanner_label_gasConsumption.
  ///
  /// In en, this message translates to:
  /// **'Gas Consumption'**
  String get divePlanner_label_gasConsumption;

  /// No description provided for @divePlanner_label_gfHigh.
  ///
  /// In en, this message translates to:
  /// **'GF High'**
  String get divePlanner_label_gfHigh;

  /// No description provided for @divePlanner_label_gfLow.
  ///
  /// In en, this message translates to:
  /// **'GF Low'**
  String get divePlanner_label_gfLow;

  /// No description provided for @divePlanner_label_max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get divePlanner_label_max;

  /// No description provided for @divePlanner_label_ndl.
  ///
  /// In en, this message translates to:
  /// **'NDL'**
  String get divePlanner_label_ndl;

  /// No description provided for @divePlanner_label_planSettings.
  ///
  /// In en, this message translates to:
  /// **'Plan Settings'**
  String get divePlanner_label_planSettings;

  /// No description provided for @divePlanner_label_remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get divePlanner_label_remaining;

  /// No description provided for @divePlanner_label_runtime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get divePlanner_label_runtime;

  /// No description provided for @divePlanner_label_sacRate.
  ///
  /// In en, this message translates to:
  /// **'SAC Rate:'**
  String get divePlanner_label_sacRate;

  /// No description provided for @divePlanner_label_status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get divePlanner_label_status;

  /// No description provided for @divePlanner_label_tanks.
  ///
  /// In en, this message translates to:
  /// **'Tanks'**
  String get divePlanner_label_tanks;

  /// No description provided for @divePlanner_label_time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get divePlanner_label_time;

  /// No description provided for @divePlanner_label_timeAxis.
  ///
  /// In en, this message translates to:
  /// **'Time (min)'**
  String get divePlanner_label_timeAxis;

  /// No description provided for @divePlanner_label_tts.
  ///
  /// In en, this message translates to:
  /// **'TTS'**
  String get divePlanner_label_tts;

  /// No description provided for @divePlanner_label_used.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get divePlanner_label_used;

  /// No description provided for @divePlanner_label_warnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get divePlanner_label_warnings;

  /// No description provided for @divePlanner_legend_ascent.
  ///
  /// In en, this message translates to:
  /// **'Ascent'**
  String get divePlanner_legend_ascent;

  /// No description provided for @divePlanner_legend_bottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get divePlanner_legend_bottom;

  /// No description provided for @divePlanner_legend_deco.
  ///
  /// In en, this message translates to:
  /// **'Deco'**
  String get divePlanner_legend_deco;

  /// No description provided for @divePlanner_legend_descent.
  ///
  /// In en, this message translates to:
  /// **'Descent'**
  String get divePlanner_legend_descent;

  /// No description provided for @divePlanner_legend_safety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get divePlanner_legend_safety;

  /// No description provided for @divePlanner_message_addSegmentsForGas.
  ///
  /// In en, this message translates to:
  /// **'Add segments to see gas projections'**
  String get divePlanner_message_addSegmentsForGas;

  /// No description provided for @divePlanner_message_addSegmentsForProfile.
  ///
  /// In en, this message translates to:
  /// **'Add segments to see the dive profile'**
  String get divePlanner_message_addSegmentsForProfile;

  /// No description provided for @divePlanner_message_convertingPlan.
  ///
  /// In en, this message translates to:
  /// **'Converting plan to dive...'**
  String get divePlanner_message_convertingPlan;

  /// No description provided for @divePlanner_message_noProfile.
  ///
  /// In en, this message translates to:
  /// **'No profile to display'**
  String get divePlanner_message_noProfile;

  /// No description provided for @divePlanner_message_planSaved.
  ///
  /// In en, this message translates to:
  /// **'Plan saved'**
  String get divePlanner_message_planSaved;

  /// No description provided for @divePlanner_message_resetConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset the plan?'**
  String get divePlanner_message_resetConfirmation;

  /// No description provided for @divePlanner_semantics_criticalWarning.
  ///
  /// In en, this message translates to:
  /// **'Critical warning: {message}'**
  String divePlanner_semantics_criticalWarning(Object message);

  /// No description provided for @divePlanner_semantics_decoStop.
  ///
  /// In en, this message translates to:
  /// **'Deco stop at {depth} for {duration} on {gasMix}'**
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  );

  /// No description provided for @divePlanner_semantics_gasConsumption.
  ///
  /// In en, this message translates to:
  /// **'{tankName}: {gasUsed} used, {remaining} remaining, {percent} used{warning}'**
  String divePlanner_semantics_gasConsumption(
    Object tankName,
    Object gasUsed,
    Object remaining,
    Object percent,
    Object warning,
  );

  /// No description provided for @divePlanner_semantics_profileChart.
  ///
  /// In en, this message translates to:
  /// **'Dive plan, max depth {maxDepth}, total time {totalMinutes} minutes'**
  String divePlanner_semantics_profileChart(
    Object maxDepth,
    Object totalMinutes,
  );

  /// No description provided for @divePlanner_semantics_warning.
  ///
  /// In en, this message translates to:
  /// **'Warning: {message}'**
  String divePlanner_semantics_warning(Object message);

  /// No description provided for @divePlanner_tab_plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get divePlanner_tab_plan;

  /// No description provided for @divePlanner_tab_profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get divePlanner_tab_profile;

  /// No description provided for @divePlanner_tab_results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get divePlanner_tab_results;

  /// No description provided for @divePlanner_warning_ascentRateHigh.
  ///
  /// In en, this message translates to:
  /// **'Ascent rate exceeds safe limit'**
  String get divePlanner_warning_ascentRateHigh;

  /// No description provided for @divePlanner_warning_ascentRateHighWithRate.
  ///
  /// In en, this message translates to:
  /// **'Ascent rate {rate}/min exceeds safe limit'**
  String divePlanner_warning_ascentRateHighWithRate(Object rate);

  /// No description provided for @divePlanner_warning_belowMinReserve.
  ///
  /// In en, this message translates to:
  /// **'Below minimum reserve ({reserve})'**
  String divePlanner_warning_belowMinReserve(Object reserve);

  /// No description provided for @divePlanner_warning_cnsCritical.
  ///
  /// In en, this message translates to:
  /// **'CNS% exceeds 100%'**
  String get divePlanner_warning_cnsCritical;

  /// No description provided for @divePlanner_warning_cnsWarning.
  ///
  /// In en, this message translates to:
  /// **'CNS% exceeds {threshold}%'**
  String divePlanner_warning_cnsWarning(Object threshold);

  /// No description provided for @divePlanner_warning_endHigh.
  ///
  /// In en, this message translates to:
  /// **'Equivalent Narcotic Depth too high'**
  String get divePlanner_warning_endHigh;

  /// No description provided for @divePlanner_warning_endHighWithDepth.
  ///
  /// In en, this message translates to:
  /// **'END of {depth} exceeds safe limit'**
  String divePlanner_warning_endHighWithDepth(Object depth);

  /// No description provided for @divePlanner_warning_gasLow.
  ///
  /// In en, this message translates to:
  /// **'Tank below {threshold} reserve'**
  String divePlanner_warning_gasLow(Object threshold);

  /// No description provided for @divePlanner_warning_gasOut.
  ///
  /// In en, this message translates to:
  /// **'Tank will be empty'**
  String get divePlanner_warning_gasOut;

  /// No description provided for @divePlanner_warning_minGasViolation.
  ///
  /// In en, this message translates to:
  /// **'Minimum gas reserve not maintained'**
  String get divePlanner_warning_minGasViolation;

  /// No description provided for @divePlanner_warning_modViolation.
  ///
  /// In en, this message translates to:
  /// **'Gas switch attempted above MOD'**
  String get divePlanner_warning_modViolation;

  /// No description provided for @divePlanner_warning_ndlExceeded.
  ///
  /// In en, this message translates to:
  /// **'Dive enters decompression obligation'**
  String get divePlanner_warning_ndlExceeded;

  /// No description provided for @divePlanner_warning_otuWarning.
  ///
  /// In en, this message translates to:
  /// **'OTU accumulation high'**
  String get divePlanner_warning_otuWarning;

  /// No description provided for @divePlanner_warning_ppO2Critical.
  ///
  /// In en, this message translates to:
  /// **'ppO₂ of {value} bar exceeds critical limit'**
  String divePlanner_warning_ppO2Critical(Object value);

  /// No description provided for @divePlanner_warning_ppO2High.
  ///
  /// In en, this message translates to:
  /// **'ppO₂ of {value} bar exceeds working limit'**
  String divePlanner_warning_ppO2High(Object value);

  /// No description provided for @diveSites_detail_access_accessNotes.
  ///
  /// In en, this message translates to:
  /// **'Access Notes'**
  String get diveSites_detail_access_accessNotes;

  /// No description provided for @diveSites_detail_access_mooring.
  ///
  /// In en, this message translates to:
  /// **'Mooring'**
  String get diveSites_detail_access_mooring;

  /// No description provided for @diveSites_detail_access_parking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get diveSites_detail_access_parking;

  /// No description provided for @diveSites_detail_altitude_elevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get diveSites_detail_altitude_elevation;

  /// No description provided for @diveSites_detail_altitude_pressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get diveSites_detail_altitude_pressure;

  /// No description provided for @diveSites_detail_coordinatesCopied.
  ///
  /// In en, this message translates to:
  /// **'Coordinates copied to clipboard'**
  String get diveSites_detail_coordinatesCopied;

  /// No description provided for @diveSites_detail_deleteDialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diveSites_detail_deleteDialog_cancel;

  /// No description provided for @diveSites_detail_deleteDialog_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get diveSites_detail_deleteDialog_confirm;

  /// No description provided for @diveSites_detail_deleteDialog_content.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this site? This action cannot be undone.'**
  String get diveSites_detail_deleteDialog_content;

  /// No description provided for @diveSites_detail_deleteDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Site'**
  String get diveSites_detail_deleteDialog_title;

  /// No description provided for @diveSites_detail_deleteMenu_label.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get diveSites_detail_deleteMenu_label;

  /// No description provided for @diveSites_detail_deleteSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Site deleted'**
  String get diveSites_detail_deleteSnackbar;

  /// No description provided for @diveSites_detail_depth_maximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get diveSites_detail_depth_maximum;

  /// No description provided for @diveSites_detail_depth_minimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get diveSites_detail_depth_minimum;

  /// No description provided for @diveSites_detail_diveCount_one.
  ///
  /// In en, this message translates to:
  /// **'1 dive logged'**
  String get diveSites_detail_diveCount_one;

  /// No description provided for @diveSites_detail_diveCount_other.
  ///
  /// In en, this message translates to:
  /// **'{count} dives logged'**
  String diveSites_detail_diveCount_other(Object count);

  /// No description provided for @diveSites_detail_diveCount_zero.
  ///
  /// In en, this message translates to:
  /// **'No dives logged yet'**
  String get diveSites_detail_diveCount_zero;

  /// No description provided for @diveSites_detail_editTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit Site'**
  String get diveSites_detail_editTooltip;

  /// No description provided for @diveSites_detail_editTooltipShort.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get diveSites_detail_editTooltipShort;

  /// No description provided for @diveSites_detail_error_body.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String diveSites_detail_error_body(Object error);

  /// No description provided for @diveSites_detail_error_title.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get diveSites_detail_error_title;

  /// No description provided for @diveSites_detail_loading_title.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get diveSites_detail_loading_title;

  /// No description provided for @diveSites_detail_location_country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get diveSites_detail_location_country;

  /// No description provided for @diveSites_detail_location_gpsCoordinates.
  ///
  /// In en, this message translates to:
  /// **'GPS Coordinates'**
  String get diveSites_detail_location_gpsCoordinates;

  /// No description provided for @diveSites_detail_location_notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get diveSites_detail_location_notSet;

  /// No description provided for @diveSites_detail_location_region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get diveSites_detail_location_region;

  /// No description provided for @diveSites_detail_noDepthInfo.
  ///
  /// In en, this message translates to:
  /// **'No depth information'**
  String get diveSites_detail_noDepthInfo;

  /// No description provided for @diveSites_detail_noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get diveSites_detail_noDescription;

  /// No description provided for @diveSites_detail_noNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get diveSites_detail_noNotes;

  /// No description provided for @diveSites_detail_rating_notRated.
  ///
  /// In en, this message translates to:
  /// **'Not rated'**
  String get diveSites_detail_rating_notRated;

  /// No description provided for @diveSites_detail_rating_value.
  ///
  /// In en, this message translates to:
  /// **'{rating} out of 5'**
  String diveSites_detail_rating_value(Object rating);

  /// No description provided for @diveSites_detail_section_access.
  ///
  /// In en, this message translates to:
  /// **'Access & Logistics'**
  String get diveSites_detail_section_access;

  /// No description provided for @diveSites_detail_section_altitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get diveSites_detail_section_altitude;

  /// No description provided for @diveSites_detail_section_depthRange.
  ///
  /// In en, this message translates to:
  /// **'Depth Range'**
  String get diveSites_detail_section_depthRange;

  /// No description provided for @diveSites_detail_section_description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get diveSites_detail_section_description;

  /// No description provided for @diveSites_detail_section_difficultyLevel.
  ///
  /// In en, this message translates to:
  /// **'Difficulty Level'**
  String get diveSites_detail_section_difficultyLevel;

  /// No description provided for @diveSites_detail_section_divesAtSite.
  ///
  /// In en, this message translates to:
  /// **'Dives at this Site'**
  String get diveSites_detail_section_divesAtSite;

  /// No description provided for @diveSites_detail_section_hazards.
  ///
  /// In en, this message translates to:
  /// **'Hazards & Safety'**
  String get diveSites_detail_section_hazards;

  /// No description provided for @diveSites_detail_section_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get diveSites_detail_section_location;

  /// No description provided for @diveSites_detail_section_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get diveSites_detail_section_notes;

  /// No description provided for @diveSites_detail_section_rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get diveSites_detail_section_rating;

  /// No description provided for @diveSites_detail_semantics_copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy {label} to clipboard'**
  String diveSites_detail_semantics_copyToClipboard(Object label);

  /// No description provided for @diveSites_detail_semantics_viewDivesAtSite.
  ///
  /// In en, this message translates to:
  /// **'View dives at this site'**
  String get diveSites_detail_semantics_viewDivesAtSite;

  /// No description provided for @diveSites_detail_semantics_viewFullscreenMap.
  ///
  /// In en, this message translates to:
  /// **'View fullscreen map'**
  String get diveSites_detail_semantics_viewFullscreenMap;

  /// No description provided for @diveSites_detail_siteNotFound_body.
  ///
  /// In en, this message translates to:
  /// **'This site no longer exists.'**
  String get diveSites_detail_siteNotFound_body;

  /// No description provided for @diveSites_detail_siteNotFound_title.
  ///
  /// In en, this message translates to:
  /// **'Site Not Found'**
  String get diveSites_detail_siteNotFound_title;

  /// No description provided for @diveSites_difficulty_advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get diveSites_difficulty_advanced;

  /// No description provided for @diveSites_difficulty_beginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get diveSites_difficulty_beginner;

  /// No description provided for @diveSites_difficulty_intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get diveSites_difficulty_intermediate;

  /// No description provided for @diveSites_difficulty_technical.
  ///
  /// In en, this message translates to:
  /// **'Technical'**
  String get diveSites_difficulty_technical;

  /// No description provided for @diveSites_edit_access_accessNotes_hint.
  ///
  /// In en, this message translates to:
  /// **'How to get to the site, entry/exit points, shore/boat access'**
  String get diveSites_edit_access_accessNotes_hint;

  /// No description provided for @diveSites_edit_access_accessNotes_label.
  ///
  /// In en, this message translates to:
  /// **'Access Notes'**
  String get diveSites_edit_access_accessNotes_label;

  /// No description provided for @diveSites_edit_access_mooringNumber_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Buoy #12'**
  String get diveSites_edit_access_mooringNumber_hint;

  /// No description provided for @diveSites_edit_access_mooringNumber_label.
  ///
  /// In en, this message translates to:
  /// **'Mooring Number'**
  String get diveSites_edit_access_mooringNumber_label;

  /// No description provided for @diveSites_edit_access_parkingInfo_hint.
  ///
  /// In en, this message translates to:
  /// **'Parking availability, fees, tips'**
  String get diveSites_edit_access_parkingInfo_hint;

  /// No description provided for @diveSites_edit_access_parkingInfo_label.
  ///
  /// In en, this message translates to:
  /// **'Parking Information'**
  String get diveSites_edit_access_parkingInfo_label;

  /// No description provided for @diveSites_edit_altitude_helperText.
  ///
  /// In en, this message translates to:
  /// **'Site elevation above sea level (for altitude diving)'**
  String get diveSites_edit_altitude_helperText;

  /// No description provided for @diveSites_edit_altitude_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 2000'**
  String get diveSites_edit_altitude_hint;

  /// No description provided for @diveSites_edit_altitude_label.
  ///
  /// In en, this message translates to:
  /// **'Altitude ({symbol})'**
  String diveSites_edit_altitude_label(Object symbol);

  /// No description provided for @diveSites_edit_altitude_validation.
  ///
  /// In en, this message translates to:
  /// **'Invalid altitude'**
  String get diveSites_edit_altitude_validation;

  /// No description provided for @diveSites_edit_appBar_deleteSiteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Site'**
  String get diveSites_edit_appBar_deleteSiteTooltip;

  /// No description provided for @diveSites_edit_appBar_editSite.
  ///
  /// In en, this message translates to:
  /// **'Edit Site'**
  String get diveSites_edit_appBar_editSite;

  /// No description provided for @diveSites_edit_appBar_newSite.
  ///
  /// In en, this message translates to:
  /// **'New Site'**
  String get diveSites_edit_appBar_newSite;

  /// No description provided for @diveSites_edit_appBar_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get diveSites_edit_appBar_save;

  /// No description provided for @diveSites_edit_button_addSite.
  ///
  /// In en, this message translates to:
  /// **'Add Site'**
  String get diveSites_edit_button_addSite;

  /// No description provided for @diveSites_edit_button_saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get diveSites_edit_button_saveChanges;

  /// No description provided for @diveSites_edit_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diveSites_edit_cancel;

  /// No description provided for @diveSites_edit_depth_helperText.
  ///
  /// In en, this message translates to:
  /// **'From the shallowest to the deepest point'**
  String get diveSites_edit_depth_helperText;

  /// No description provided for @diveSites_edit_depth_maxHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 30'**
  String get diveSites_edit_depth_maxHint;

  /// No description provided for @diveSites_edit_depth_maxLabel.
  ///
  /// In en, this message translates to:
  /// **'Maximum Depth ({symbol})'**
  String diveSites_edit_depth_maxLabel(Object symbol);

  /// No description provided for @diveSites_edit_depth_minHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 5'**
  String get diveSites_edit_depth_minHint;

  /// No description provided for @diveSites_edit_depth_minLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimum Depth ({symbol})'**
  String diveSites_edit_depth_minLabel(Object symbol);

  /// No description provided for @diveSites_edit_depth_separator.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get diveSites_edit_depth_separator;

  /// No description provided for @diveSites_edit_discardDialog_content.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to leave?'**
  String get diveSites_edit_discardDialog_content;

  /// No description provided for @diveSites_edit_discardDialog_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get diveSites_edit_discardDialog_discard;

  /// No description provided for @diveSites_edit_discardDialog_keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get diveSites_edit_discardDialog_keepEditing;

  /// No description provided for @diveSites_edit_discardDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes?'**
  String get diveSites_edit_discardDialog_title;

  /// No description provided for @diveSites_edit_field_country_label.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get diveSites_edit_field_country_label;

  /// No description provided for @diveSites_edit_field_description_hint.
  ///
  /// In en, this message translates to:
  /// **'Brief description of the site'**
  String get diveSites_edit_field_description_hint;

  /// No description provided for @diveSites_edit_field_description_label.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get diveSites_edit_field_description_label;

  /// No description provided for @diveSites_edit_field_notes_hint.
  ///
  /// In en, this message translates to:
  /// **'Any other information about this site'**
  String get diveSites_edit_field_notes_hint;

  /// No description provided for @diveSites_edit_field_notes_label.
  ///
  /// In en, this message translates to:
  /// **'General Notes'**
  String get diveSites_edit_field_notes_label;

  /// No description provided for @diveSites_edit_field_region_label.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get diveSites_edit_field_region_label;

  /// No description provided for @diveSites_edit_field_siteName_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Blue Hole'**
  String get diveSites_edit_field_siteName_hint;

  /// No description provided for @diveSites_edit_field_siteName_label.
  ///
  /// In en, this message translates to:
  /// **'Site Name *'**
  String get diveSites_edit_field_siteName_label;

  /// No description provided for @diveSites_edit_field_siteName_validation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a site name'**
  String get diveSites_edit_field_siteName_validation;

  /// No description provided for @diveSites_edit_gps_gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting...'**
  String get diveSites_edit_gps_gettingLocation;

  /// No description provided for @diveSites_edit_gps_helperText.
  ///
  /// In en, this message translates to:
  /// **'Choose a location method - coordinates will auto-fill country and region'**
  String get diveSites_edit_gps_helperText;

  /// No description provided for @diveSites_edit_gps_latitude_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 21.4225'**
  String get diveSites_edit_gps_latitude_hint;

  /// No description provided for @diveSites_edit_gps_latitude_label.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get diveSites_edit_gps_latitude_label;

  /// No description provided for @diveSites_edit_gps_latitude_validation.
  ///
  /// In en, this message translates to:
  /// **'Invalid latitude'**
  String get diveSites_edit_gps_latitude_validation;

  /// No description provided for @diveSites_edit_gps_longitude_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g., -86.7542'**
  String get diveSites_edit_gps_longitude_hint;

  /// No description provided for @diveSites_edit_gps_longitude_label.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get diveSites_edit_gps_longitude_label;

  /// No description provided for @diveSites_edit_gps_longitude_validation.
  ///
  /// In en, this message translates to:
  /// **'Invalid longitude'**
  String get diveSites_edit_gps_longitude_validation;

  /// No description provided for @diveSites_edit_gps_pickFromMap.
  ///
  /// In en, this message translates to:
  /// **'Pick from Map'**
  String get diveSites_edit_gps_pickFromMap;

  /// No description provided for @diveSites_edit_gps_useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use My Location'**
  String get diveSites_edit_gps_useMyLocation;

  /// No description provided for @diveSites_edit_hazards_helperText.
  ///
  /// In en, this message translates to:
  /// **'List any hazards or safety considerations'**
  String get diveSites_edit_hazards_helperText;

  /// No description provided for @diveSites_edit_hazards_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Strong currents, boat traffic, jellyfish, sharp coral'**
  String get diveSites_edit_hazards_hint;

  /// No description provided for @diveSites_edit_hazards_label.
  ///
  /// In en, this message translates to:
  /// **'Hazards'**
  String get diveSites_edit_hazards_label;

  /// No description provided for @diveSites_edit_marineLife_addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get diveSites_edit_marineLife_addButton;

  /// No description provided for @diveSites_edit_marineLife_empty.
  ///
  /// In en, this message translates to:
  /// **'No expected species added'**
  String get diveSites_edit_marineLife_empty;

  /// No description provided for @diveSites_edit_marineLife_helperText.
  ///
  /// In en, this message translates to:
  /// **'Species you expect to see at this site'**
  String get diveSites_edit_marineLife_helperText;

  /// No description provided for @diveSites_edit_rating_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear Rating'**
  String get diveSites_edit_rating_clear;

  /// No description provided for @diveSites_edit_rating_starTooltip.
  ///
  /// In en, this message translates to:
  /// **'{count} star{count, plural, =1{} other{s}}'**
  String diveSites_edit_rating_starTooltip(int count);

  /// No description provided for @diveSites_edit_section_access.
  ///
  /// In en, this message translates to:
  /// **'Access & Logistics'**
  String get diveSites_edit_section_access;

  /// No description provided for @diveSites_edit_section_altitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get diveSites_edit_section_altitude;

  /// No description provided for @diveSites_edit_section_depthRange.
  ///
  /// In en, this message translates to:
  /// **'Depth Range'**
  String get diveSites_edit_section_depthRange;

  /// No description provided for @diveSites_edit_section_difficultyLevel.
  ///
  /// In en, this message translates to:
  /// **'Difficulty Level'**
  String get diveSites_edit_section_difficultyLevel;

  /// No description provided for @diveSites_edit_section_expectedMarineLife.
  ///
  /// In en, this message translates to:
  /// **'Expected Marine Life'**
  String get diveSites_edit_section_expectedMarineLife;

  /// No description provided for @diveSites_edit_section_gpsCoordinates.
  ///
  /// In en, this message translates to:
  /// **'GPS Coordinates'**
  String get diveSites_edit_section_gpsCoordinates;

  /// No description provided for @diveSites_edit_section_hazards.
  ///
  /// In en, this message translates to:
  /// **'Hazards & Safety'**
  String get diveSites_edit_section_hazards;

  /// No description provided for @diveSites_edit_section_rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get diveSites_edit_section_rating;

  /// No description provided for @diveSites_edit_snackbar_errorDeleting.
  ///
  /// In en, this message translates to:
  /// **'Error deleting site: {error}'**
  String diveSites_edit_snackbar_errorDeleting(Object error);

  /// No description provided for @diveSites_edit_snackbar_errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving site: {error}'**
  String diveSites_edit_snackbar_errorSaving(Object error);

  /// No description provided for @diveSites_edit_snackbar_locationCaptured.
  ///
  /// In en, this message translates to:
  /// **'Location captured'**
  String get diveSites_edit_snackbar_locationCaptured;

  /// No description provided for @diveSites_edit_snackbar_locationCapturedWithAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Location captured ({accuracy}m)'**
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy);

  /// No description provided for @diveSites_edit_snackbar_locationSelectedFromMap.
  ///
  /// In en, this message translates to:
  /// **'Location selected from map'**
  String get diveSites_edit_snackbar_locationSelectedFromMap;

  /// No description provided for @diveSites_edit_snackbar_locationSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get diveSites_edit_snackbar_locationSettings;

  /// No description provided for @diveSites_edit_snackbar_locationUnavailableDesktop.
  ///
  /// In en, this message translates to:
  /// **'Unable to get location. Location services may not be available.'**
  String get diveSites_edit_snackbar_locationUnavailableDesktop;

  /// No description provided for @diveSites_edit_snackbar_locationUnavailableMobile.
  ///
  /// In en, this message translates to:
  /// **'Unable to get location. Please check permissions.'**
  String get diveSites_edit_snackbar_locationUnavailableMobile;

  /// No description provided for @diveSites_edit_snackbar_siteAdded.
  ///
  /// In en, this message translates to:
  /// **'Site added'**
  String get diveSites_edit_snackbar_siteAdded;

  /// No description provided for @diveSites_edit_snackbar_siteUpdated.
  ///
  /// In en, this message translates to:
  /// **'Site updated'**
  String get diveSites_edit_snackbar_siteUpdated;

  /// No description provided for @diveSites_fab_label.
  ///
  /// In en, this message translates to:
  /// **'Add Site'**
  String get diveSites_fab_label;

  /// No description provided for @diveSites_fab_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a new dive site'**
  String get diveSites_fab_tooltip;

  /// No description provided for @diveSites_filter_apply.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get diveSites_filter_apply;

  /// No description provided for @diveSites_filter_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diveSites_filter_cancel;

  /// No description provided for @diveSites_filter_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get diveSites_filter_clearAll;

  /// No description provided for @diveSites_filter_country_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Thailand'**
  String get diveSites_filter_country_hint;

  /// No description provided for @diveSites_filter_country_label.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get diveSites_filter_country_label;

  /// No description provided for @diveSites_filter_depth_max_label.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get diveSites_filter_depth_max_label;

  /// No description provided for @diveSites_filter_depth_min_label.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get diveSites_filter_depth_min_label;

  /// No description provided for @diveSites_filter_depth_separator.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get diveSites_filter_depth_separator;

  /// No description provided for @diveSites_filter_difficulty_any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get diveSites_filter_difficulty_any;

  /// No description provided for @diveSites_filter_option_hasCoordinates_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Only show sites with GPS location'**
  String get diveSites_filter_option_hasCoordinates_subtitle;

  /// No description provided for @diveSites_filter_option_hasCoordinates_title.
  ///
  /// In en, this message translates to:
  /// **'Has Coordinates'**
  String get diveSites_filter_option_hasCoordinates_title;

  /// No description provided for @diveSites_filter_option_hasDives_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Only show sites with logged dives'**
  String get diveSites_filter_option_hasDives_subtitle;

  /// No description provided for @diveSites_filter_option_hasDives_title.
  ///
  /// In en, this message translates to:
  /// **'Has Dives'**
  String get diveSites_filter_option_hasDives_title;

  /// No description provided for @diveSites_filter_rating_starsPlus.
  ///
  /// In en, this message translates to:
  /// **'{count}+ stars'**
  String diveSites_filter_rating_starsPlus(Object count);

  /// No description provided for @diveSites_filter_region_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Phuket'**
  String get diveSites_filter_region_hint;

  /// No description provided for @diveSites_filter_region_label.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get diveSites_filter_region_label;

  /// No description provided for @diveSites_filter_section_depthRange.
  ///
  /// In en, this message translates to:
  /// **'Max Depth Range'**
  String get diveSites_filter_section_depthRange;

  /// No description provided for @diveSites_filter_section_difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get diveSites_filter_section_difficulty;

  /// No description provided for @diveSites_filter_section_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get diveSites_filter_section_location;

  /// No description provided for @diveSites_filter_section_minRating.
  ///
  /// In en, this message translates to:
  /// **'Minimum Rating'**
  String get diveSites_filter_section_minRating;

  /// No description provided for @diveSites_filter_section_options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get diveSites_filter_section_options;

  /// No description provided for @diveSites_filter_title.
  ///
  /// In en, this message translates to:
  /// **'Filter Sites'**
  String get diveSites_filter_title;

  /// No description provided for @diveSites_import_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Import Dive Site'**
  String get diveSites_import_appBar_title;

  /// No description provided for @diveSites_import_badge_imported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get diveSites_import_badge_imported;

  /// No description provided for @diveSites_import_badge_saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get diveSites_import_badge_saved;

  /// No description provided for @diveSites_import_button_import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get diveSites_import_button_import;

  /// No description provided for @diveSites_import_detail_alreadyImported.
  ///
  /// In en, this message translates to:
  /// **'Already Imported'**
  String get diveSites_import_detail_alreadyImported;

  /// No description provided for @diveSites_import_detail_importToMySites.
  ///
  /// In en, this message translates to:
  /// **'Import to My Sites'**
  String get diveSites_import_detail_importToMySites;

  /// No description provided for @diveSites_import_detail_source.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String diveSites_import_detail_source(Object source);

  /// No description provided for @diveSites_import_empty_description.
  ///
  /// In en, this message translates to:
  /// **'Search for dive sites from our database of popular dive destinations around the world.'**
  String get diveSites_import_empty_description;

  /// No description provided for @diveSites_import_empty_hint.
  ///
  /// In en, this message translates to:
  /// **'Try searching by site name, country, or region.'**
  String get diveSites_import_empty_hint;

  /// No description provided for @diveSites_import_empty_title.
  ///
  /// In en, this message translates to:
  /// **'Search Dive Sites'**
  String get diveSites_import_empty_title;

  /// No description provided for @diveSites_import_error_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get diveSites_import_error_retry;

  /// No description provided for @diveSites_import_error_title.
  ///
  /// In en, this message translates to:
  /// **'Search Error'**
  String get diveSites_import_error_title;

  /// No description provided for @diveSites_import_error_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get diveSites_import_error_unknown;

  /// No description provided for @diveSites_import_externalSite_locationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Location unknown'**
  String get diveSites_import_externalSite_locationUnknown;

  /// No description provided for @diveSites_import_label_gps.
  ///
  /// In en, this message translates to:
  /// **'GPS'**
  String get diveSites_import_label_gps;

  /// No description provided for @diveSites_import_localSite_locationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Location not set'**
  String get diveSites_import_localSite_locationNotSet;

  /// No description provided for @diveSites_import_noResults_description.
  ///
  /// In en, this message translates to:
  /// **'No dive sites found for \"{query}\". Try a different search term.'**
  String diveSites_import_noResults_description(Object query);

  /// No description provided for @diveSites_import_noResults_title.
  ///
  /// In en, this message translates to:
  /// **'No Results'**
  String get diveSites_import_noResults_title;

  /// No description provided for @diveSites_import_quickSearch_caribbean.
  ///
  /// In en, this message translates to:
  /// **'Caribbean'**
  String get diveSites_import_quickSearch_caribbean;

  /// No description provided for @diveSites_import_quickSearch_indonesia.
  ///
  /// In en, this message translates to:
  /// **'Indonesia'**
  String get diveSites_import_quickSearch_indonesia;

  /// No description provided for @diveSites_import_quickSearch_maldives.
  ///
  /// In en, this message translates to:
  /// **'Maldives'**
  String get diveSites_import_quickSearch_maldives;

  /// No description provided for @diveSites_import_quickSearch_philippines.
  ///
  /// In en, this message translates to:
  /// **'Philippines'**
  String get diveSites_import_quickSearch_philippines;

  /// No description provided for @diveSites_import_quickSearch_redSea.
  ///
  /// In en, this message translates to:
  /// **'Red Sea'**
  String get diveSites_import_quickSearch_redSea;

  /// No description provided for @diveSites_import_quickSearch_thailand.
  ///
  /// In en, this message translates to:
  /// **'Thailand'**
  String get diveSites_import_quickSearch_thailand;

  /// No description provided for @diveSites_import_search_clearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get diveSites_import_search_clearTooltip;

  /// No description provided for @diveSites_import_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search dive sites (e.g., \"Blue Hole\", \"Thailand\")'**
  String get diveSites_import_search_hint;

  /// No description provided for @diveSites_import_section_importFromDatabase.
  ///
  /// In en, this message translates to:
  /// **'Import from Database ({count})'**
  String diveSites_import_section_importFromDatabase(Object count);

  /// No description provided for @diveSites_import_section_mySites.
  ///
  /// In en, this message translates to:
  /// **'My Sites ({count})'**
  String diveSites_import_section_mySites(Object count);

  /// No description provided for @diveSites_import_semantics_viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details for {name}'**
  String diveSites_import_semantics_viewDetails(Object name);

  /// No description provided for @diveSites_import_semantics_viewSavedSite.
  ///
  /// In en, this message translates to:
  /// **'View saved site {name}'**
  String diveSites_import_semantics_viewSavedSite(Object name);

  /// No description provided for @diveSites_import_snackbar_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import site'**
  String get diveSites_import_snackbar_failed;

  /// No description provided for @diveSites_import_snackbar_imported.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{name}\"'**
  String diveSites_import_snackbar_imported(Object name);

  /// No description provided for @diveSites_import_snackbar_viewAction.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get diveSites_import_snackbar_viewAction;

  /// No description provided for @diveSites_list_activeFilter_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get diveSites_list_activeFilter_clear;

  /// No description provided for @diveSites_list_activeFilter_country.
  ///
  /// In en, this message translates to:
  /// **'Country: {country}'**
  String diveSites_list_activeFilter_country(Object country);

  /// No description provided for @diveSites_list_activeFilter_depthRangeBoth.
  ///
  /// In en, this message translates to:
  /// **'{min}-{max}m'**
  String diveSites_list_activeFilter_depthRangeBoth(Object min, Object max);

  /// No description provided for @diveSites_list_activeFilter_depthRangeMax.
  ///
  /// In en, this message translates to:
  /// **'Up to {max}m'**
  String diveSites_list_activeFilter_depthRangeMax(Object max);

  /// No description provided for @diveSites_list_activeFilter_depthRangeMin.
  ///
  /// In en, this message translates to:
  /// **'{min}m+'**
  String diveSites_list_activeFilter_depthRangeMin(Object min);

  /// No description provided for @diveSites_list_activeFilter_hasCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Has coordinates'**
  String get diveSites_list_activeFilter_hasCoordinates;

  /// No description provided for @diveSites_list_activeFilter_hasDives.
  ///
  /// In en, this message translates to:
  /// **'Has dives'**
  String get diveSites_list_activeFilter_hasDives;

  /// No description provided for @diveSites_list_activeFilter_region.
  ///
  /// In en, this message translates to:
  /// **'Region: {region}'**
  String diveSites_list_activeFilter_region(Object region);

  /// No description provided for @diveSites_list_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Sites'**
  String get diveSites_list_appBar_title;

  /// No description provided for @diveSites_list_bulkDelete_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diveSites_list_bulkDelete_cancel;

  /// No description provided for @diveSites_list_bulkDelete_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get diveSites_list_bulkDelete_confirm;

  /// No description provided for @diveSites_list_bulkDelete_content.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} {count, plural, =1{site} other{sites}}? This action can be undone within 5 seconds.'**
  String diveSites_list_bulkDelete_content(int count);

  /// No description provided for @diveSites_list_bulkDelete_restored.
  ///
  /// In en, this message translates to:
  /// **'Sites restored'**
  String get diveSites_list_bulkDelete_restored;

  /// No description provided for @diveSites_list_bulkDelete_snackbar.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} {count, plural, =1{site} other{sites}}'**
  String diveSites_list_bulkDelete_snackbar(int count);

  /// No description provided for @diveSites_list_bulkDelete_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Sites'**
  String get diveSites_list_bulkDelete_title;

  /// No description provided for @diveSites_list_bulkDelete_undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get diveSites_list_bulkDelete_undo;

  /// No description provided for @diveSites_list_emptyFiltered_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All Filters'**
  String get diveSites_list_emptyFiltered_clearAll;

  /// No description provided for @diveSites_list_emptyFiltered_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting or clearing your filters'**
  String get diveSites_list_emptyFiltered_subtitle;

  /// No description provided for @diveSites_list_emptyFiltered_title.
  ///
  /// In en, this message translates to:
  /// **'No sites match your filters'**
  String get diveSites_list_emptyFiltered_title;

  /// No description provided for @diveSites_list_empty_addFirstSite.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Site'**
  String get diveSites_list_empty_addFirstSite;

  /// No description provided for @diveSites_list_empty_import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get diveSites_list_empty_import;

  /// No description provided for @diveSites_list_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Add dive sites to track your favorite locations'**
  String get diveSites_list_empty_subtitle;

  /// No description provided for @diveSites_list_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No dive sites yet'**
  String get diveSites_list_empty_title;

  /// No description provided for @diveSites_list_error_loadingSites.
  ///
  /// In en, this message translates to:
  /// **'Error loading sites: {error}'**
  String diveSites_list_error_loadingSites(Object error);

  /// No description provided for @diveSites_list_error_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get diveSites_list_error_retry;

  /// No description provided for @diveSites_list_menu_import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get diveSites_list_menu_import;

  /// No description provided for @diveSites_list_search_backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get diveSites_list_search_backTooltip;

  /// No description provided for @diveSites_list_search_clearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get diveSites_list_search_clearTooltip;

  /// No description provided for @diveSites_list_search_emptyHint.
  ///
  /// In en, this message translates to:
  /// **'Search by site name, country, or region'**
  String get diveSites_list_search_emptyHint;

  /// No description provided for @diveSites_list_search_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String diveSites_list_search_error(Object error);

  /// No description provided for @diveSites_list_search_noResults.
  ///
  /// In en, this message translates to:
  /// **'No sites found for \"{query}\"'**
  String diveSites_list_search_noResults(Object query);

  /// No description provided for @diveSites_list_search_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Search sites...'**
  String get diveSites_list_search_placeholder;

  /// No description provided for @diveSites_list_selection_closeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close Selection'**
  String get diveSites_list_selection_closeTooltip;

  /// No description provided for @diveSites_list_selection_count.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String diveSites_list_selection_count(Object count);

  /// No description provided for @diveSites_list_selection_deleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get diveSites_list_selection_deleteTooltip;

  /// No description provided for @diveSites_list_selection_deselectAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get diveSites_list_selection_deselectAllTooltip;

  /// No description provided for @diveSites_list_selection_selectAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get diveSites_list_selection_selectAllTooltip;

  /// No description provided for @diveSites_list_sort_title.
  ///
  /// In en, this message translates to:
  /// **'Sort Sites'**
  String get diveSites_list_sort_title;

  /// No description provided for @diveSites_list_tile_diveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dive} other{{count} dives}}'**
  String diveSites_list_tile_diveCount(int count);

  /// No description provided for @diveSites_list_tile_semantics.
  ///
  /// In en, this message translates to:
  /// **'Dive site: {name}'**
  String diveSites_list_tile_semantics(Object name);

  /// No description provided for @diveSites_list_tooltip_filterSites.
  ///
  /// In en, this message translates to:
  /// **'Filter Sites'**
  String get diveSites_list_tooltip_filterSites;

  /// No description provided for @diveSites_list_tooltip_mapView.
  ///
  /// In en, this message translates to:
  /// **'Map View'**
  String get diveSites_list_tooltip_mapView;

  /// No description provided for @diveSites_list_tooltip_searchSites.
  ///
  /// In en, this message translates to:
  /// **'Search Sites'**
  String get diveSites_list_tooltip_searchSites;

  /// No description provided for @diveSites_list_tooltip_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get diveSites_list_tooltip_sort;

  /// No description provided for @diveSites_locationPicker_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Pick Location'**
  String get diveSites_locationPicker_appBar_title;

  /// No description provided for @diveSites_locationPicker_confirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get diveSites_locationPicker_confirmButton;

  /// No description provided for @diveSites_locationPicker_confirmTooltip.
  ///
  /// In en, this message translates to:
  /// **'Confirm selected location'**
  String get diveSites_locationPicker_confirmTooltip;

  /// No description provided for @diveSites_locationPicker_fab_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get diveSites_locationPicker_fab_tooltip;

  /// No description provided for @diveSites_locationPicker_instruction_locationSelected.
  ///
  /// In en, this message translates to:
  /// **'Location selected'**
  String get diveSites_locationPicker_instruction_locationSelected;

  /// No description provided for @diveSites_locationPicker_instruction_lookingUp.
  ///
  /// In en, this message translates to:
  /// **'Looking up location...'**
  String get diveSites_locationPicker_instruction_lookingUp;

  /// No description provided for @diveSites_locationPicker_instruction_tapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap on the map to select a location'**
  String get diveSites_locationPicker_instruction_tapToSelect;

  /// No description provided for @diveSites_locationPicker_label_latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get diveSites_locationPicker_label_latitude;

  /// No description provided for @diveSites_locationPicker_label_longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get diveSites_locationPicker_label_longitude;

  /// No description provided for @diveSites_locationPicker_semantics_coordinates.
  ///
  /// In en, this message translates to:
  /// **'Selected coordinates: latitude {latitude}, longitude {longitude}'**
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  );

  /// No description provided for @diveSites_locationPicker_semantics_lookingUp.
  ///
  /// In en, this message translates to:
  /// **'Looking up location'**
  String get diveSites_locationPicker_semantics_lookingUp;

  /// No description provided for @diveSites_locationPicker_semantics_map.
  ///
  /// In en, this message translates to:
  /// **'Interactive map for picking a dive site location. Tap on the map to select a location.'**
  String get diveSites_locationPicker_semantics_map;

  /// No description provided for @diveSites_mapContent_error_loadingDiveSites.
  ///
  /// In en, this message translates to:
  /// **'Error loading dive sites: {error}'**
  String diveSites_mapContent_error_loadingDiveSites(Object error);

  /// No description provided for @diveSites_map_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Sites'**
  String get diveSites_map_appBar_title;

  /// No description provided for @diveSites_map_empty_description.
  ///
  /// In en, this message translates to:
  /// **'Add coordinates to your dive sites to see them on the map'**
  String get diveSites_map_empty_description;

  /// No description provided for @diveSites_map_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No sites with coordinates'**
  String get diveSites_map_empty_title;

  /// No description provided for @diveSites_map_error_loadingSites.
  ///
  /// In en, this message translates to:
  /// **'Error loading sites: {error}'**
  String diveSites_map_error_loadingSites(Object error);

  /// No description provided for @diveSites_map_error_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get diveSites_map_error_retry;

  /// No description provided for @diveSites_map_infoCard_diveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dive} other{{count} dives}}'**
  String diveSites_map_infoCard_diveCount(int count);

  /// No description provided for @diveSites_map_semantics_diveSiteMarker.
  ///
  /// In en, this message translates to:
  /// **'Dive site: {name}'**
  String diveSites_map_semantics_diveSiteMarker(Object name);

  /// No description provided for @diveSites_map_tooltip_fitAllSites.
  ///
  /// In en, this message translates to:
  /// **'Fit All Sites'**
  String get diveSites_map_tooltip_fitAllSites;

  /// No description provided for @diveSites_map_tooltip_listView.
  ///
  /// In en, this message translates to:
  /// **'List View'**
  String get diveSites_map_tooltip_listView;

  /// No description provided for @diveSites_summary_action_addSite.
  ///
  /// In en, this message translates to:
  /// **'Add Site'**
  String get diveSites_summary_action_addSite;

  /// No description provided for @diveSites_summary_action_import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get diveSites_summary_action_import;

  /// No description provided for @diveSites_summary_action_viewMap.
  ///
  /// In en, this message translates to:
  /// **'View Map'**
  String get diveSites_summary_action_viewMap;

  /// No description provided for @diveSites_summary_countriesMore.
  ///
  /// In en, this message translates to:
  /// **'+ {count} more'**
  String diveSites_summary_countriesMore(Object count);

  /// No description provided for @diveSites_summary_header_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a site from the list to view details'**
  String get diveSites_summary_header_subtitle;

  /// No description provided for @diveSites_summary_header_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Sites'**
  String get diveSites_summary_header_title;

  /// No description provided for @diveSites_summary_section_countriesRegions.
  ///
  /// In en, this message translates to:
  /// **'Countries & Regions'**
  String get diveSites_summary_section_countriesRegions;

  /// No description provided for @diveSites_summary_section_mostDived.
  ///
  /// In en, this message translates to:
  /// **'Most Dived'**
  String get diveSites_summary_section_mostDived;

  /// No description provided for @diveSites_summary_section_overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get diveSites_summary_section_overview;

  /// No description provided for @diveSites_summary_section_quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get diveSites_summary_section_quickActions;

  /// No description provided for @diveSites_summary_section_topRated.
  ///
  /// In en, this message translates to:
  /// **'Top Rated'**
  String get diveSites_summary_section_topRated;

  /// No description provided for @diveSites_summary_stat_avgRating.
  ///
  /// In en, this message translates to:
  /// **'Avg Rating'**
  String get diveSites_summary_stat_avgRating;

  /// No description provided for @diveSites_summary_stat_totalDives.
  ///
  /// In en, this message translates to:
  /// **'Total Dives'**
  String get diveSites_summary_stat_totalDives;

  /// No description provided for @diveSites_summary_stat_totalSites.
  ///
  /// In en, this message translates to:
  /// **'Total Sites'**
  String get diveSites_summary_stat_totalSites;

  /// No description provided for @diveSites_summary_stat_withGps.
  ///
  /// In en, this message translates to:
  /// **'With GPS'**
  String get diveSites_summary_stat_withGps;

  /// No description provided for @diveTypes_addDialog_addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get diveTypes_addDialog_addButton;

  /// No description provided for @diveTypes_addDialog_nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Search & Recovery'**
  String get diveTypes_addDialog_nameHint;

  /// No description provided for @diveTypes_addDialog_nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Dive Type Name'**
  String get diveTypes_addDialog_nameLabel;

  /// No description provided for @diveTypes_addDialog_nameValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get diveTypes_addDialog_nameValidation;

  /// No description provided for @diveTypes_addDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Dive Type'**
  String get diveTypes_addDialog_title;

  /// No description provided for @diveTypes_addTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add dive type'**
  String get diveTypes_addTooltip;

  /// No description provided for @diveTypes_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Types'**
  String get diveTypes_appBar_title;

  /// No description provided for @diveTypes_builtIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get diveTypes_builtIn;

  /// No description provided for @diveTypes_builtInHeader.
  ///
  /// In en, this message translates to:
  /// **'Built-in Dive Types'**
  String get diveTypes_builtInHeader;

  /// No description provided for @diveTypes_custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get diveTypes_custom;

  /// No description provided for @diveTypes_customHeader.
  ///
  /// In en, this message translates to:
  /// **'Custom Dive Types'**
  String get diveTypes_customHeader;

  /// No description provided for @diveTypes_deleteDialog_content.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String diveTypes_deleteDialog_content(Object name);

  /// No description provided for @diveTypes_deleteDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Dive Type?'**
  String get diveTypes_deleteDialog_title;

  /// No description provided for @diveTypes_deleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete dive type'**
  String get diveTypes_deleteTooltip;

  /// No description provided for @diveTypes_snackbar_added.
  ///
  /// In en, this message translates to:
  /// **'Added dive type: {name}'**
  String diveTypes_snackbar_added(Object name);

  /// No description provided for @diveTypes_snackbar_cannotDelete.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete \"{name}\" - it is used by existing dives'**
  String diveTypes_snackbar_cannotDelete(Object name);

  /// No description provided for @diveTypes_snackbar_deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String diveTypes_snackbar_deleted(Object name);

  /// No description provided for @diveTypes_snackbar_errorAdding.
  ///
  /// In en, this message translates to:
  /// **'Error adding dive type: {error}'**
  String diveTypes_snackbar_errorAdding(Object error);

  /// No description provided for @diveTypes_snackbar_errorDeleting.
  ///
  /// In en, this message translates to:
  /// **'Error deleting dive type: {error}'**
  String diveTypes_snackbar_errorDeleting(Object error);

  /// No description provided for @divers_detail_activeDiver.
  ///
  /// In en, this message translates to:
  /// **'Active Diver'**
  String get divers_detail_activeDiver;

  /// No description provided for @divers_detail_allergiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get divers_detail_allergiesLabel;

  /// No description provided for @divers_detail_appBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Diver'**
  String get divers_detail_appBarTitle;

  /// No description provided for @divers_detail_bloodTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood Type'**
  String get divers_detail_bloodTypeLabel;

  /// No description provided for @divers_detail_bottomTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Bottom Time'**
  String get divers_detail_bottomTimeLabel;

  /// No description provided for @divers_detail_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get divers_detail_cancelButton;

  /// No description provided for @divers_detail_contactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get divers_detail_contactTitle;

  /// No description provided for @divers_detail_defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get divers_detail_defaultLabel;

  /// No description provided for @divers_detail_deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get divers_detail_deleteButton;

  /// No description provided for @divers_detail_deleteDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}? All associated dive logs will be unassigned.'**
  String divers_detail_deleteDialogContent(Object name);

  /// No description provided for @divers_detail_deleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Diver?'**
  String get divers_detail_deleteDialogTitle;

  /// No description provided for @divers_detail_deleteError.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String divers_detail_deleteError(Object error);

  /// No description provided for @divers_detail_deleteMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get divers_detail_deleteMenuItem;

  /// No description provided for @divers_detail_deletedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Diver deleted'**
  String get divers_detail_deletedSnackbar;

  /// No description provided for @divers_detail_diveInsuranceTitle.
  ///
  /// In en, this message translates to:
  /// **'Dive Insurance'**
  String get divers_detail_diveInsuranceTitle;

  /// No description provided for @divers_detail_diveStatisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Dive Statistics'**
  String get divers_detail_diveStatisticsTitle;

  /// No description provided for @divers_detail_editTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit diver'**
  String get divers_detail_editTooltip;

  /// No description provided for @divers_detail_emergencyContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact'**
  String get divers_detail_emergencyContactTitle;

  /// No description provided for @divers_detail_errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String divers_detail_errorPrefix(Object error);

  /// No description provided for @divers_detail_expiredBadge.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get divers_detail_expiredBadge;

  /// No description provided for @divers_detail_expiresLabel.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get divers_detail_expiresLabel;

  /// No description provided for @divers_detail_medicalInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Medical Information'**
  String get divers_detail_medicalInfoTitle;

  /// No description provided for @divers_detail_medicalNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get divers_detail_medicalNotesLabel;

  /// No description provided for @divers_detail_notFound.
  ///
  /// In en, this message translates to:
  /// **'Diver not found'**
  String get divers_detail_notFound;

  /// No description provided for @divers_detail_notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get divers_detail_notesTitle;

  /// No description provided for @divers_detail_policyNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Policy #'**
  String get divers_detail_policyNumberLabel;

  /// No description provided for @divers_detail_providerLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get divers_detail_providerLabel;

  /// No description provided for @divers_detail_setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as Default'**
  String get divers_detail_setAsDefault;

  /// No description provided for @divers_detail_setAsDefaultSnackbar.
  ///
  /// In en, this message translates to:
  /// **'{name} set as default diver'**
  String divers_detail_setAsDefaultSnackbar(Object name);

  /// No description provided for @divers_detail_switchToTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to this diver'**
  String get divers_detail_switchToTooltip;

  /// No description provided for @divers_detail_switchedTo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {name}'**
  String divers_detail_switchedTo(Object name);

  /// No description provided for @divers_detail_totalDivesLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Dives'**
  String get divers_detail_totalDivesLabel;

  /// No description provided for @divers_detail_unableToLoadStats.
  ///
  /// In en, this message translates to:
  /// **'Unable to load stats'**
  String get divers_detail_unableToLoadStats;

  /// No description provided for @divers_edit_addButton.
  ///
  /// In en, this message translates to:
  /// **'Add Diver'**
  String get divers_edit_addButton;

  /// No description provided for @divers_edit_addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Diver'**
  String get divers_edit_addTitle;

  /// No description provided for @divers_edit_allergiesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Penicillin, Shellfish'**
  String get divers_edit_allergiesHint;

  /// No description provided for @divers_edit_allergiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get divers_edit_allergiesLabel;

  /// No description provided for @divers_edit_bloodTypeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., O+, A-, B+'**
  String get divers_edit_bloodTypeHint;

  /// No description provided for @divers_edit_bloodTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood Type'**
  String get divers_edit_bloodTypeLabel;

  /// No description provided for @divers_edit_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get divers_edit_cancelButton;

  /// No description provided for @divers_edit_clearInsuranceExpiryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear insurance expiry date'**
  String get divers_edit_clearInsuranceExpiryTooltip;

  /// No description provided for @divers_edit_clearMedicalClearanceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear medical clearance date'**
  String get divers_edit_clearMedicalClearanceTooltip;

  /// No description provided for @divers_edit_contactNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact Name'**
  String get divers_edit_contactNameLabel;

  /// No description provided for @divers_edit_contactPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact Phone'**
  String get divers_edit_contactPhoneLabel;

  /// No description provided for @divers_edit_discardButton.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get divers_edit_discardButton;

  /// No description provided for @divers_edit_discardDialogContent.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to discard them?'**
  String get divers_edit_discardDialogContent;

  /// No description provided for @divers_edit_discardDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes?'**
  String get divers_edit_discardDialogTitle;

  /// No description provided for @divers_edit_diverAdded.
  ///
  /// In en, this message translates to:
  /// **'Diver added'**
  String get divers_edit_diverAdded;

  /// No description provided for @divers_edit_diverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Diver updated'**
  String get divers_edit_diverUpdated;

  /// No description provided for @divers_edit_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Diver'**
  String get divers_edit_editTitle;

  /// No description provided for @divers_edit_emailError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get divers_edit_emailError;

  /// No description provided for @divers_edit_emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get divers_edit_emailLabel;

  /// No description provided for @divers_edit_emergencyContactsSection.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contacts'**
  String get divers_edit_emergencyContactsSection;

  /// No description provided for @divers_edit_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading diver: {error}'**
  String divers_edit_errorLoading(Object error);

  /// No description provided for @divers_edit_errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving diver: {error}'**
  String divers_edit_errorSaving(Object error);

  /// No description provided for @divers_edit_expiryDateNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get divers_edit_expiryDateNotSet;

  /// No description provided for @divers_edit_expiryDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get divers_edit_expiryDateTitle;

  /// No description provided for @divers_edit_insuranceProviderHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., DAN, DiveAssure'**
  String get divers_edit_insuranceProviderHint;

  /// No description provided for @divers_edit_insuranceProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Insurance Provider'**
  String get divers_edit_insuranceProviderLabel;

  /// No description provided for @divers_edit_insuranceSection.
  ///
  /// In en, this message translates to:
  /// **'Dive Insurance'**
  String get divers_edit_insuranceSection;

  /// No description provided for @divers_edit_keepEditingButton.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get divers_edit_keepEditingButton;

  /// No description provided for @divers_edit_medicalClearanceExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get divers_edit_medicalClearanceExpired;

  /// No description provided for @divers_edit_medicalClearanceExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get divers_edit_medicalClearanceExpiringSoon;

  /// No description provided for @divers_edit_medicalClearanceNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get divers_edit_medicalClearanceNotSet;

  /// No description provided for @divers_edit_medicalClearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Medical Clearance Expiry'**
  String get divers_edit_medicalClearanceTitle;

  /// No description provided for @divers_edit_medicalInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Medical Information'**
  String get divers_edit_medicalInfoSection;

  /// No description provided for @divers_edit_medicalNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Medical Notes'**
  String get divers_edit_medicalNotesLabel;

  /// No description provided for @divers_edit_medicationsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Aspirin daily, EpiPen'**
  String get divers_edit_medicationsHint;

  /// No description provided for @divers_edit_medicationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get divers_edit_medicationsLabel;

  /// No description provided for @divers_edit_nameError.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get divers_edit_nameError;

  /// No description provided for @divers_edit_nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get divers_edit_nameLabel;

  /// No description provided for @divers_edit_notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get divers_edit_notesLabel;

  /// No description provided for @divers_edit_notesSection.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get divers_edit_notesSection;

  /// No description provided for @divers_edit_personalInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get divers_edit_personalInfoSection;

  /// No description provided for @divers_edit_phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get divers_edit_phoneLabel;

  /// No description provided for @divers_edit_policyNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Policy Number'**
  String get divers_edit_policyNumberLabel;

  /// No description provided for @divers_edit_primaryContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Primary Contact'**
  String get divers_edit_primaryContactTitle;

  /// No description provided for @divers_edit_relationshipHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Spouse, Parent, Friend'**
  String get divers_edit_relationshipHint;

  /// No description provided for @divers_edit_relationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get divers_edit_relationshipLabel;

  /// No description provided for @divers_edit_saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get divers_edit_saveButton;

  /// No description provided for @divers_edit_secondaryContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Secondary Contact'**
  String get divers_edit_secondaryContactTitle;

  /// No description provided for @divers_edit_selectInsuranceExpiryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select insurance expiry date'**
  String get divers_edit_selectInsuranceExpiryTooltip;

  /// No description provided for @divers_edit_selectMedicalClearanceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select medical clearance date'**
  String get divers_edit_selectMedicalClearanceTooltip;

  /// No description provided for @divers_edit_updateButton.
  ///
  /// In en, this message translates to:
  /// **'Update Diver'**
  String get divers_edit_updateButton;

  /// No description provided for @divers_list_activeBadge.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get divers_list_activeBadge;

  /// No description provided for @divers_list_addDiverButton.
  ///
  /// In en, this message translates to:
  /// **'Add Diver'**
  String get divers_list_addDiverButton;

  /// No description provided for @divers_list_addDiverTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a new diver profile'**
  String get divers_list_addDiverTooltip;

  /// No description provided for @divers_list_appBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Diver Profiles'**
  String get divers_list_appBarTitle;

  /// No description provided for @divers_list_compactTitle.
  ///
  /// In en, this message translates to:
  /// **'Divers'**
  String get divers_list_compactTitle;

  /// No description provided for @divers_list_diverStats.
  ///
  /// In en, this message translates to:
  /// **'{diveCount} dives{bottomTime}'**
  String divers_list_diverStats(Object diveCount, Object bottomTime);

  /// No description provided for @divers_list_emptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add diver profiles to track dive logs for multiple people'**
  String get divers_list_emptySubtitle;

  /// No description provided for @divers_list_emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No divers yet'**
  String get divers_list_emptyTitle;

  /// No description provided for @divers_list_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading divers: {error}'**
  String divers_list_errorLoading(Object error);

  /// No description provided for @divers_list_errorLoadingStats.
  ///
  /// In en, this message translates to:
  /// **'Error loading stats'**
  String get divers_list_errorLoadingStats;

  /// No description provided for @divers_list_loadingStats.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get divers_list_loadingStats;

  /// No description provided for @divers_list_retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get divers_list_retryButton;

  /// No description provided for @divers_list_viewDiverLabel.
  ///
  /// In en, this message translates to:
  /// **'View diver {name}'**
  String divers_list_viewDiverLabel(Object name);

  /// No description provided for @divers_summary_activeDiverTitle.
  ///
  /// In en, this message translates to:
  /// **'Active Diver'**
  String get divers_summary_activeDiverTitle;

  /// No description provided for @divers_summary_otherDiversTitle.
  ///
  /// In en, this message translates to:
  /// **'Other Divers'**
  String get divers_summary_otherDiversTitle;

  /// No description provided for @divers_summary_overviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get divers_summary_overviewTitle;

  /// No description provided for @divers_summary_quickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get divers_summary_quickActionsTitle;

  /// No description provided for @divers_summary_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a diver from the list to view details'**
  String get divers_summary_subtitle;

  /// No description provided for @divers_summary_title.
  ///
  /// In en, this message translates to:
  /// **'Diver Profiles'**
  String get divers_summary_title;

  /// No description provided for @divers_summary_totalDiversLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Divers'**
  String get divers_summary_totalDiversLabel;

  /// No description provided for @enum_altitudeGroup_extreme.
  ///
  /// In en, this message translates to:
  /// **'Extreme Altitude'**
  String get enum_altitudeGroup_extreme;

  /// No description provided for @enum_altitudeGroup_extreme_range.
  ///
  /// In en, this message translates to:
  /// **'>2700m (>8858ft)'**
  String get enum_altitudeGroup_extreme_range;

  /// No description provided for @enum_altitudeGroup_group1.
  ///
  /// In en, this message translates to:
  /// **'Altitude Group 1'**
  String get enum_altitudeGroup_group1;

  /// No description provided for @enum_altitudeGroup_group1_range.
  ///
  /// In en, this message translates to:
  /// **'300-900m (984-2953ft)'**
  String get enum_altitudeGroup_group1_range;

  /// No description provided for @enum_altitudeGroup_group2.
  ///
  /// In en, this message translates to:
  /// **'Altitude Group 2'**
  String get enum_altitudeGroup_group2;

  /// No description provided for @enum_altitudeGroup_group2_range.
  ///
  /// In en, this message translates to:
  /// **'900-1800m (2953-5906ft)'**
  String get enum_altitudeGroup_group2_range;

  /// No description provided for @enum_altitudeGroup_group3.
  ///
  /// In en, this message translates to:
  /// **'Altitude Group 3'**
  String get enum_altitudeGroup_group3;

  /// No description provided for @enum_altitudeGroup_group3_range.
  ///
  /// In en, this message translates to:
  /// **'1800-2700m (5906-8858ft)'**
  String get enum_altitudeGroup_group3_range;

  /// No description provided for @enum_altitudeGroup_seaLevel.
  ///
  /// In en, this message translates to:
  /// **'Sea Level'**
  String get enum_altitudeGroup_seaLevel;

  /// No description provided for @enum_altitudeGroup_seaLevel_range.
  ///
  /// In en, this message translates to:
  /// **'0-300m (0-984ft)'**
  String get enum_altitudeGroup_seaLevel_range;

  /// No description provided for @enum_ascentRate_danger.
  ///
  /// In en, this message translates to:
  /// **'Danger'**
  String get enum_ascentRate_danger;

  /// No description provided for @enum_ascentRate_safe.
  ///
  /// In en, this message translates to:
  /// **'Safe'**
  String get enum_ascentRate_safe;

  /// No description provided for @enum_ascentRate_warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get enum_ascentRate_warning;

  /// No description provided for @enum_buddyRole_buddy.
  ///
  /// In en, this message translates to:
  /// **'Buddy'**
  String get enum_buddyRole_buddy;

  /// No description provided for @enum_buddyRole_diveGuide.
  ///
  /// In en, this message translates to:
  /// **'Dive Guide'**
  String get enum_buddyRole_diveGuide;

  /// No description provided for @enum_buddyRole_diveMaster.
  ///
  /// In en, this message translates to:
  /// **'Divemaster'**
  String get enum_buddyRole_diveMaster;

  /// No description provided for @enum_buddyRole_instructor.
  ///
  /// In en, this message translates to:
  /// **'Instructor'**
  String get enum_buddyRole_instructor;

  /// No description provided for @enum_buddyRole_solo.
  ///
  /// In en, this message translates to:
  /// **'Solo'**
  String get enum_buddyRole_solo;

  /// No description provided for @enum_buddyRole_student.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get enum_buddyRole_student;

  /// No description provided for @enum_certificationAgency_bsac.
  ///
  /// In en, this message translates to:
  /// **'BSAC'**
  String get enum_certificationAgency_bsac;

  /// No description provided for @enum_certificationAgency_cmas.
  ///
  /// In en, this message translates to:
  /// **'CMAS'**
  String get enum_certificationAgency_cmas;

  /// No description provided for @enum_certificationAgency_gue.
  ///
  /// In en, this message translates to:
  /// **'GUE'**
  String get enum_certificationAgency_gue;

  /// No description provided for @enum_certificationAgency_iantd.
  ///
  /// In en, this message translates to:
  /// **'IANTD'**
  String get enum_certificationAgency_iantd;

  /// No description provided for @enum_certificationAgency_naui.
  ///
  /// In en, this message translates to:
  /// **'NAUI'**
  String get enum_certificationAgency_naui;

  /// No description provided for @enum_certificationAgency_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get enum_certificationAgency_other;

  /// No description provided for @enum_certificationAgency_padi.
  ///
  /// In en, this message translates to:
  /// **'PADI'**
  String get enum_certificationAgency_padi;

  /// No description provided for @enum_certificationAgency_psai.
  ///
  /// In en, this message translates to:
  /// **'PSAI'**
  String get enum_certificationAgency_psai;

  /// No description provided for @enum_certificationAgency_raid.
  ///
  /// In en, this message translates to:
  /// **'RAID'**
  String get enum_certificationAgency_raid;

  /// No description provided for @enum_certificationAgency_sdi.
  ///
  /// In en, this message translates to:
  /// **'SDI'**
  String get enum_certificationAgency_sdi;

  /// No description provided for @enum_certificationAgency_ssi.
  ///
  /// In en, this message translates to:
  /// **'SSI'**
  String get enum_certificationAgency_ssi;

  /// No description provided for @enum_certificationAgency_tdi.
  ///
  /// In en, this message translates to:
  /// **'TDI'**
  String get enum_certificationAgency_tdi;

  /// No description provided for @enum_certificationLevel_advancedNitrox.
  ///
  /// In en, this message translates to:
  /// **'Advanced Nitrox'**
  String get enum_certificationLevel_advancedNitrox;

  /// No description provided for @enum_certificationLevel_advancedOpenWater.
  ///
  /// In en, this message translates to:
  /// **'Advanced Open Water'**
  String get enum_certificationLevel_advancedOpenWater;

  /// No description provided for @enum_certificationLevel_cave.
  ///
  /// In en, this message translates to:
  /// **'Cave'**
  String get enum_certificationLevel_cave;

  /// No description provided for @enum_certificationLevel_cavern.
  ///
  /// In en, this message translates to:
  /// **'Cavern'**
  String get enum_certificationLevel_cavern;

  /// No description provided for @enum_certificationLevel_courseDirector.
  ///
  /// In en, this message translates to:
  /// **'Course Director'**
  String get enum_certificationLevel_courseDirector;

  /// No description provided for @enum_certificationLevel_decompression.
  ///
  /// In en, this message translates to:
  /// **'Decompression'**
  String get enum_certificationLevel_decompression;

  /// No description provided for @enum_certificationLevel_diveMaster.
  ///
  /// In en, this message translates to:
  /// **'Divemaster'**
  String get enum_certificationLevel_diveMaster;

  /// No description provided for @enum_certificationLevel_instructor.
  ///
  /// In en, this message translates to:
  /// **'Instructor'**
  String get enum_certificationLevel_instructor;

  /// No description provided for @enum_certificationLevel_masterInstructor.
  ///
  /// In en, this message translates to:
  /// **'Master Instructor'**
  String get enum_certificationLevel_masterInstructor;

  /// No description provided for @enum_certificationLevel_nitrox.
  ///
  /// In en, this message translates to:
  /// **'Nitrox'**
  String get enum_certificationLevel_nitrox;

  /// No description provided for @enum_certificationLevel_openWater.
  ///
  /// In en, this message translates to:
  /// **'Open Water'**
  String get enum_certificationLevel_openWater;

  /// No description provided for @enum_certificationLevel_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get enum_certificationLevel_other;

  /// No description provided for @enum_certificationLevel_rebreather.
  ///
  /// In en, this message translates to:
  /// **'Rebreather'**
  String get enum_certificationLevel_rebreather;

  /// No description provided for @enum_certificationLevel_rescue.
  ///
  /// In en, this message translates to:
  /// **'Rescue Diver'**
  String get enum_certificationLevel_rescue;

  /// No description provided for @enum_certificationLevel_sidemount.
  ///
  /// In en, this message translates to:
  /// **'Sidemount'**
  String get enum_certificationLevel_sidemount;

  /// No description provided for @enum_certificationLevel_techDiver.
  ///
  /// In en, this message translates to:
  /// **'Tech Diver'**
  String get enum_certificationLevel_techDiver;

  /// No description provided for @enum_certificationLevel_trimix.
  ///
  /// In en, this message translates to:
  /// **'Trimix'**
  String get enum_certificationLevel_trimix;

  /// No description provided for @enum_certificationLevel_wreck.
  ///
  /// In en, this message translates to:
  /// **'Wreck'**
  String get enum_certificationLevel_wreck;

  /// No description provided for @enum_currentDirection_east.
  ///
  /// In en, this message translates to:
  /// **'East'**
  String get enum_currentDirection_east;

  /// No description provided for @enum_currentDirection_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get enum_currentDirection_none;

  /// No description provided for @enum_currentDirection_north.
  ///
  /// In en, this message translates to:
  /// **'North'**
  String get enum_currentDirection_north;

  /// No description provided for @enum_currentDirection_northEast.
  ///
  /// In en, this message translates to:
  /// **'North-East'**
  String get enum_currentDirection_northEast;

  /// No description provided for @enum_currentDirection_northWest.
  ///
  /// In en, this message translates to:
  /// **'North-West'**
  String get enum_currentDirection_northWest;

  /// No description provided for @enum_currentDirection_south.
  ///
  /// In en, this message translates to:
  /// **'South'**
  String get enum_currentDirection_south;

  /// No description provided for @enum_currentDirection_southEast.
  ///
  /// In en, this message translates to:
  /// **'South-East'**
  String get enum_currentDirection_southEast;

  /// No description provided for @enum_currentDirection_southWest.
  ///
  /// In en, this message translates to:
  /// **'South-West'**
  String get enum_currentDirection_southWest;

  /// No description provided for @enum_currentDirection_variable.
  ///
  /// In en, this message translates to:
  /// **'Variable'**
  String get enum_currentDirection_variable;

  /// No description provided for @enum_currentDirection_west.
  ///
  /// In en, this message translates to:
  /// **'West'**
  String get enum_currentDirection_west;

  /// No description provided for @enum_currentStrength_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get enum_currentStrength_light;

  /// No description provided for @enum_currentStrength_moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get enum_currentStrength_moderate;

  /// No description provided for @enum_currentStrength_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get enum_currentStrength_none;

  /// No description provided for @enum_currentStrength_strong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get enum_currentStrength_strong;

  /// No description provided for @enum_diveMode_ccr.
  ///
  /// In en, this message translates to:
  /// **'Closed Circuit Rebreather'**
  String get enum_diveMode_ccr;

  /// No description provided for @enum_diveMode_oc.
  ///
  /// In en, this message translates to:
  /// **'Open Circuit'**
  String get enum_diveMode_oc;

  /// No description provided for @enum_diveMode_scr.
  ///
  /// In en, this message translates to:
  /// **'Semi-Closed Rebreather'**
  String get enum_diveMode_scr;

  /// No description provided for @enum_diveType_altitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get enum_diveType_altitude;

  /// No description provided for @enum_diveType_boat.
  ///
  /// In en, this message translates to:
  /// **'Boat'**
  String get enum_diveType_boat;

  /// No description provided for @enum_diveType_cave.
  ///
  /// In en, this message translates to:
  /// **'Cave'**
  String get enum_diveType_cave;

  /// No description provided for @enum_diveType_deep.
  ///
  /// In en, this message translates to:
  /// **'Deep'**
  String get enum_diveType_deep;

  /// No description provided for @enum_diveType_drift.
  ///
  /// In en, this message translates to:
  /// **'Drift'**
  String get enum_diveType_drift;

  /// No description provided for @enum_diveType_freedive.
  ///
  /// In en, this message translates to:
  /// **'Freedive'**
  String get enum_diveType_freedive;

  /// No description provided for @enum_diveType_ice.
  ///
  /// In en, this message translates to:
  /// **'Ice'**
  String get enum_diveType_ice;

  /// No description provided for @enum_diveType_liveaboard.
  ///
  /// In en, this message translates to:
  /// **'Liveaboard'**
  String get enum_diveType_liveaboard;

  /// No description provided for @enum_diveType_night.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get enum_diveType_night;

  /// No description provided for @enum_diveType_recreational.
  ///
  /// In en, this message translates to:
  /// **'Recreational'**
  String get enum_diveType_recreational;

  /// No description provided for @enum_diveType_shore.
  ///
  /// In en, this message translates to:
  /// **'Shore'**
  String get enum_diveType_shore;

  /// No description provided for @enum_diveType_technical.
  ///
  /// In en, this message translates to:
  /// **'Technical'**
  String get enum_diveType_technical;

  /// No description provided for @enum_diveType_training.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get enum_diveType_training;

  /// No description provided for @enum_diveType_wreck.
  ///
  /// In en, this message translates to:
  /// **'Wreck'**
  String get enum_diveType_wreck;

  /// No description provided for @enum_entryMethod_backRoll.
  ///
  /// In en, this message translates to:
  /// **'Back Roll'**
  String get enum_entryMethod_backRoll;

  /// No description provided for @enum_entryMethod_boat.
  ///
  /// In en, this message translates to:
  /// **'Boat Entry'**
  String get enum_entryMethod_boat;

  /// No description provided for @enum_entryMethod_giantStride.
  ///
  /// In en, this message translates to:
  /// **'Giant Stride'**
  String get enum_entryMethod_giantStride;

  /// No description provided for @enum_entryMethod_jetty.
  ///
  /// In en, this message translates to:
  /// **'Jetty/Dock'**
  String get enum_entryMethod_jetty;

  /// No description provided for @enum_entryMethod_ladder.
  ///
  /// In en, this message translates to:
  /// **'Ladder'**
  String get enum_entryMethod_ladder;

  /// No description provided for @enum_entryMethod_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get enum_entryMethod_other;

  /// No description provided for @enum_entryMethod_platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get enum_entryMethod_platform;

  /// No description provided for @enum_entryMethod_seatedEntry.
  ///
  /// In en, this message translates to:
  /// **'Seated Entry'**
  String get enum_entryMethod_seatedEntry;

  /// No description provided for @enum_entryMethod_shore.
  ///
  /// In en, this message translates to:
  /// **'Shore Entry'**
  String get enum_entryMethod_shore;

  /// No description provided for @enum_equipmentStatus_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get enum_equipmentStatus_active;

  /// No description provided for @enum_equipmentStatus_inService.
  ///
  /// In en, this message translates to:
  /// **'In Service'**
  String get enum_equipmentStatus_inService;

  /// No description provided for @enum_equipmentStatus_loaned.
  ///
  /// In en, this message translates to:
  /// **'Loaned Out'**
  String get enum_equipmentStatus_loaned;

  /// No description provided for @enum_equipmentStatus_lost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get enum_equipmentStatus_lost;

  /// No description provided for @enum_equipmentStatus_needsService.
  ///
  /// In en, this message translates to:
  /// **'Needs Service'**
  String get enum_equipmentStatus_needsService;

  /// No description provided for @enum_equipmentStatus_retired.
  ///
  /// In en, this message translates to:
  /// **'Retired'**
  String get enum_equipmentStatus_retired;

  /// No description provided for @enum_equipmentType_bcd.
  ///
  /// In en, this message translates to:
  /// **'BCD'**
  String get enum_equipmentType_bcd;

  /// No description provided for @enum_equipmentType_boots.
  ///
  /// In en, this message translates to:
  /// **'Boots'**
  String get enum_equipmentType_boots;

  /// No description provided for @enum_equipmentType_camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get enum_equipmentType_camera;

  /// No description provided for @enum_equipmentType_computer.
  ///
  /// In en, this message translates to:
  /// **'Dive Computer'**
  String get enum_equipmentType_computer;

  /// No description provided for @enum_equipmentType_drysuit.
  ///
  /// In en, this message translates to:
  /// **'Drysuit'**
  String get enum_equipmentType_drysuit;

  /// No description provided for @enum_equipmentType_fins.
  ///
  /// In en, this message translates to:
  /// **'Fins'**
  String get enum_equipmentType_fins;

  /// No description provided for @enum_equipmentType_gloves.
  ///
  /// In en, this message translates to:
  /// **'Gloves'**
  String get enum_equipmentType_gloves;

  /// No description provided for @enum_equipmentType_hood.
  ///
  /// In en, this message translates to:
  /// **'Hood'**
  String get enum_equipmentType_hood;

  /// No description provided for @enum_equipmentType_knife.
  ///
  /// In en, this message translates to:
  /// **'Knife'**
  String get enum_equipmentType_knife;

  /// No description provided for @enum_equipmentType_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get enum_equipmentType_light;

  /// No description provided for @enum_equipmentType_mask.
  ///
  /// In en, this message translates to:
  /// **'Mask'**
  String get enum_equipmentType_mask;

  /// No description provided for @enum_equipmentType_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get enum_equipmentType_other;

  /// No description provided for @enum_equipmentType_reel.
  ///
  /// In en, this message translates to:
  /// **'Reel'**
  String get enum_equipmentType_reel;

  /// No description provided for @enum_equipmentType_regulator.
  ///
  /// In en, this message translates to:
  /// **'Regulator'**
  String get enum_equipmentType_regulator;

  /// No description provided for @enum_equipmentType_smb.
  ///
  /// In en, this message translates to:
  /// **'SMB'**
  String get enum_equipmentType_smb;

  /// No description provided for @enum_equipmentType_tank.
  ///
  /// In en, this message translates to:
  /// **'Tank'**
  String get enum_equipmentType_tank;

  /// No description provided for @enum_equipmentType_weights.
  ///
  /// In en, this message translates to:
  /// **'Weights'**
  String get enum_equipmentType_weights;

  /// No description provided for @enum_equipmentType_wetsuit.
  ///
  /// In en, this message translates to:
  /// **'Wetsuit'**
  String get enum_equipmentType_wetsuit;

  /// No description provided for @enum_eventSeverity_alert.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get enum_eventSeverity_alert;

  /// No description provided for @enum_eventSeverity_info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get enum_eventSeverity_info;

  /// No description provided for @enum_eventSeverity_warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get enum_eventSeverity_warning;

  /// No description provided for @enum_pdfPageSize_a4.
  ///
  /// In en, this message translates to:
  /// **'A4'**
  String get enum_pdfPageSize_a4;

  /// No description provided for @enum_pdfPageSize_a4_description.
  ///
  /// In en, this message translates to:
  /// **'210 x 297 mm'**
  String get enum_pdfPageSize_a4_description;

  /// No description provided for @enum_pdfPageSize_letter.
  ///
  /// In en, this message translates to:
  /// **'Letter'**
  String get enum_pdfPageSize_letter;

  /// No description provided for @enum_pdfPageSize_letter_description.
  ///
  /// In en, this message translates to:
  /// **'8.5 x 11 in'**
  String get enum_pdfPageSize_letter_description;

  /// No description provided for @enum_pdfTemplate_detailed.
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get enum_pdfTemplate_detailed;

  /// No description provided for @enum_pdfTemplate_detailed_description.
  ///
  /// In en, this message translates to:
  /// **'Full dive information with notes and ratings'**
  String get enum_pdfTemplate_detailed_description;

  /// No description provided for @enum_pdfTemplate_nauiStyle.
  ///
  /// In en, this message translates to:
  /// **'NAUI Style'**
  String get enum_pdfTemplate_nauiStyle;

  /// No description provided for @enum_pdfTemplate_nauiStyle_description.
  ///
  /// In en, this message translates to:
  /// **'Layout matching NAUI logbook format'**
  String get enum_pdfTemplate_nauiStyle_description;

  /// No description provided for @enum_pdfTemplate_padiStyle.
  ///
  /// In en, this message translates to:
  /// **'PADI Style'**
  String get enum_pdfTemplate_padiStyle;

  /// No description provided for @enum_pdfTemplate_padiStyle_description.
  ///
  /// In en, this message translates to:
  /// **'Layout matching PADI logbook format'**
  String get enum_pdfTemplate_padiStyle_description;

  /// No description provided for @enum_pdfTemplate_professional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get enum_pdfTemplate_professional;

  /// No description provided for @enum_pdfTemplate_professional_description.
  ///
  /// In en, this message translates to:
  /// **'Signature and stamp areas for verification'**
  String get enum_pdfTemplate_professional_description;

  /// No description provided for @enum_pdfTemplate_simple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get enum_pdfTemplate_simple;

  /// No description provided for @enum_pdfTemplate_simple_description.
  ///
  /// In en, this message translates to:
  /// **'Compact table format, many dives per page'**
  String get enum_pdfTemplate_simple_description;

  /// No description provided for @enum_profileEvent_alert.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get enum_profileEvent_alert;

  /// No description provided for @enum_profileEvent_ascentRateCritical.
  ///
  /// In en, this message translates to:
  /// **'Ascent Rate Critical'**
  String get enum_profileEvent_ascentRateCritical;

  /// No description provided for @enum_profileEvent_ascentRateWarning.
  ///
  /// In en, this message translates to:
  /// **'Ascent Rate Warning'**
  String get enum_profileEvent_ascentRateWarning;

  /// No description provided for @enum_profileEvent_ascentStart.
  ///
  /// In en, this message translates to:
  /// **'Ascent Start'**
  String get enum_profileEvent_ascentStart;

  /// No description provided for @enum_profileEvent_bookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get enum_profileEvent_bookmark;

  /// No description provided for @enum_profileEvent_cnsCritical.
  ///
  /// In en, this message translates to:
  /// **'CNS Critical'**
  String get enum_profileEvent_cnsCritical;

  /// No description provided for @enum_profileEvent_cnsWarning.
  ///
  /// In en, this message translates to:
  /// **'CNS Warning'**
  String get enum_profileEvent_cnsWarning;

  /// No description provided for @enum_profileEvent_decoStopEnd.
  ///
  /// In en, this message translates to:
  /// **'Deco Stop End'**
  String get enum_profileEvent_decoStopEnd;

  /// No description provided for @enum_profileEvent_decoStopStart.
  ///
  /// In en, this message translates to:
  /// **'Deco Stop Start'**
  String get enum_profileEvent_decoStopStart;

  /// No description provided for @enum_profileEvent_decoViolation.
  ///
  /// In en, this message translates to:
  /// **'Deco Violation'**
  String get enum_profileEvent_decoViolation;

  /// No description provided for @enum_profileEvent_descentEnd.
  ///
  /// In en, this message translates to:
  /// **'Descent End'**
  String get enum_profileEvent_descentEnd;

  /// No description provided for @enum_profileEvent_descentStart.
  ///
  /// In en, this message translates to:
  /// **'Descent Start'**
  String get enum_profileEvent_descentStart;

  /// No description provided for @enum_profileEvent_gasSwitch.
  ///
  /// In en, this message translates to:
  /// **'Gas Switch'**
  String get enum_profileEvent_gasSwitch;

  /// No description provided for @enum_profileEvent_lowGas.
  ///
  /// In en, this message translates to:
  /// **'Low Gas Warning'**
  String get enum_profileEvent_lowGas;

  /// No description provided for @enum_profileEvent_maxDepth.
  ///
  /// In en, this message translates to:
  /// **'Max Depth'**
  String get enum_profileEvent_maxDepth;

  /// No description provided for @enum_profileEvent_missedStop.
  ///
  /// In en, this message translates to:
  /// **'Missed Deco Stop'**
  String get enum_profileEvent_missedStop;

  /// No description provided for @enum_profileEvent_note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get enum_profileEvent_note;

  /// No description provided for @enum_profileEvent_ppO2High.
  ///
  /// In en, this message translates to:
  /// **'High ppO2'**
  String get enum_profileEvent_ppO2High;

  /// No description provided for @enum_profileEvent_ppO2Low.
  ///
  /// In en, this message translates to:
  /// **'Low ppO2'**
  String get enum_profileEvent_ppO2Low;

  /// No description provided for @enum_profileEvent_safetyStopEnd.
  ///
  /// In en, this message translates to:
  /// **'Safety Stop End'**
  String get enum_profileEvent_safetyStopEnd;

  /// No description provided for @enum_profileEvent_safetyStopStart.
  ///
  /// In en, this message translates to:
  /// **'Safety Stop Start'**
  String get enum_profileEvent_safetyStopStart;

  /// No description provided for @enum_profileEvent_setpointChange.
  ///
  /// In en, this message translates to:
  /// **'Setpoint Change'**
  String get enum_profileEvent_setpointChange;

  /// No description provided for @enum_profileMetricCategory_decompression.
  ///
  /// In en, this message translates to:
  /// **'Decompression'**
  String get enum_profileMetricCategory_decompression;

  /// No description provided for @enum_profileMetricCategory_gasAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Gas Analysis'**
  String get enum_profileMetricCategory_gasAnalysis;

  /// No description provided for @enum_profileMetricCategory_gradientFactor.
  ///
  /// In en, this message translates to:
  /// **'Gradient Factors'**
  String get enum_profileMetricCategory_gradientFactor;

  /// No description provided for @enum_profileMetricCategory_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get enum_profileMetricCategory_other;

  /// No description provided for @enum_profileMetricCategory_primary.
  ///
  /// In en, this message translates to:
  /// **'Primary Metrics'**
  String get enum_profileMetricCategory_primary;

  /// No description provided for @enum_profileMetric_gasDensity.
  ///
  /// In en, this message translates to:
  /// **'Gas Density'**
  String get enum_profileMetric_gasDensity;

  /// No description provided for @enum_profileMetric_gasDensity_short.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get enum_profileMetric_gasDensity_short;

  /// No description provided for @enum_profileMetric_gf.
  ///
  /// In en, this message translates to:
  /// **'GF%'**
  String get enum_profileMetric_gf;

  /// No description provided for @enum_profileMetric_gf_short.
  ///
  /// In en, this message translates to:
  /// **'GF%'**
  String get enum_profileMetric_gf_short;

  /// No description provided for @enum_profileMetric_heartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get enum_profileMetric_heartRate;

  /// No description provided for @enum_profileMetric_heartRate_short.
  ///
  /// In en, this message translates to:
  /// **'HR'**
  String get enum_profileMetric_heartRate_short;

  /// No description provided for @enum_profileMetric_meanDepth.
  ///
  /// In en, this message translates to:
  /// **'Mean Depth'**
  String get enum_profileMetric_meanDepth;

  /// No description provided for @enum_profileMetric_meanDepth_short.
  ///
  /// In en, this message translates to:
  /// **'Mean'**
  String get enum_profileMetric_meanDepth_short;

  /// No description provided for @enum_profileMetric_ndl.
  ///
  /// In en, this message translates to:
  /// **'NDL'**
  String get enum_profileMetric_ndl;

  /// No description provided for @enum_profileMetric_ndl_short.
  ///
  /// In en, this message translates to:
  /// **'NDL'**
  String get enum_profileMetric_ndl_short;

  /// No description provided for @enum_profileMetric_ppHe.
  ///
  /// In en, this message translates to:
  /// **'ppHe'**
  String get enum_profileMetric_ppHe;

  /// No description provided for @enum_profileMetric_ppHe_short.
  ///
  /// In en, this message translates to:
  /// **'ppHe'**
  String get enum_profileMetric_ppHe_short;

  /// No description provided for @enum_profileMetric_ppN2.
  ///
  /// In en, this message translates to:
  /// **'ppN2'**
  String get enum_profileMetric_ppN2;

  /// No description provided for @enum_profileMetric_ppN2_short.
  ///
  /// In en, this message translates to:
  /// **'ppN2'**
  String get enum_profileMetric_ppN2_short;

  /// No description provided for @enum_profileMetric_ppO2.
  ///
  /// In en, this message translates to:
  /// **'ppO2'**
  String get enum_profileMetric_ppO2;

  /// No description provided for @enum_profileMetric_ppO2_short.
  ///
  /// In en, this message translates to:
  /// **'ppO2'**
  String get enum_profileMetric_ppO2_short;

  /// No description provided for @enum_profileMetric_pressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get enum_profileMetric_pressure;

  /// No description provided for @enum_profileMetric_pressure_short.
  ///
  /// In en, this message translates to:
  /// **'Press'**
  String get enum_profileMetric_pressure_short;

  /// No description provided for @enum_profileMetric_sacRate.
  ///
  /// In en, this message translates to:
  /// **'SAC Rate'**
  String get enum_profileMetric_sacRate;

  /// No description provided for @enum_profileMetric_sacRate_short.
  ///
  /// In en, this message translates to:
  /// **'SAC'**
  String get enum_profileMetric_sacRate_short;

  /// No description provided for @enum_profileMetric_surfaceGf.
  ///
  /// In en, this message translates to:
  /// **'Surface GF'**
  String get enum_profileMetric_surfaceGf;

  /// No description provided for @enum_profileMetric_surfaceGf_short.
  ///
  /// In en, this message translates to:
  /// **'SrfGF'**
  String get enum_profileMetric_surfaceGf_short;

  /// No description provided for @enum_profileMetric_temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get enum_profileMetric_temperature;

  /// No description provided for @enum_profileMetric_temperature_short.
  ///
  /// In en, this message translates to:
  /// **'Temp'**
  String get enum_profileMetric_temperature_short;

  /// No description provided for @enum_profileMetric_tts.
  ///
  /// In en, this message translates to:
  /// **'TTS'**
  String get enum_profileMetric_tts;

  /// No description provided for @enum_profileMetric_tts_short.
  ///
  /// In en, this message translates to:
  /// **'TTS'**
  String get enum_profileMetric_tts_short;

  /// No description provided for @enum_scrType_cmf.
  ///
  /// In en, this message translates to:
  /// **'Constant Mass Flow'**
  String get enum_scrType_cmf;

  /// No description provided for @enum_scrType_cmf_short.
  ///
  /// In en, this message translates to:
  /// **'CMF'**
  String get enum_scrType_cmf_short;

  /// No description provided for @enum_scrType_escr.
  ///
  /// In en, this message translates to:
  /// **'Electronically Controlled'**
  String get enum_scrType_escr;

  /// No description provided for @enum_scrType_escr_short.
  ///
  /// In en, this message translates to:
  /// **'ESCR'**
  String get enum_scrType_escr_short;

  /// No description provided for @enum_scrType_pascr.
  ///
  /// In en, this message translates to:
  /// **'Passive Addition'**
  String get enum_scrType_pascr;

  /// No description provided for @enum_scrType_pascr_short.
  ///
  /// In en, this message translates to:
  /// **'PASCR'**
  String get enum_scrType_pascr_short;

  /// No description provided for @enum_serviceType_annual.
  ///
  /// In en, this message translates to:
  /// **'Annual Service'**
  String get enum_serviceType_annual;

  /// No description provided for @enum_serviceType_calibration.
  ///
  /// In en, this message translates to:
  /// **'Calibration'**
  String get enum_serviceType_calibration;

  /// No description provided for @enum_serviceType_cleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get enum_serviceType_cleaning;

  /// No description provided for @enum_serviceType_inspection.
  ///
  /// In en, this message translates to:
  /// **'Inspection'**
  String get enum_serviceType_inspection;

  /// No description provided for @enum_serviceType_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get enum_serviceType_other;

  /// No description provided for @enum_serviceType_overhaul.
  ///
  /// In en, this message translates to:
  /// **'Overhaul'**
  String get enum_serviceType_overhaul;

  /// No description provided for @enum_serviceType_recall.
  ///
  /// In en, this message translates to:
  /// **'Recall/Safety'**
  String get enum_serviceType_recall;

  /// No description provided for @enum_serviceType_repair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get enum_serviceType_repair;

  /// No description provided for @enum_serviceType_replacement.
  ///
  /// In en, this message translates to:
  /// **'Part Replacement'**
  String get enum_serviceType_replacement;

  /// No description provided for @enum_serviceType_warranty.
  ///
  /// In en, this message translates to:
  /// **'Warranty Service'**
  String get enum_serviceType_warranty;

  /// No description provided for @enum_sortDirection_ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get enum_sortDirection_ascending;

  /// No description provided for @enum_sortDirection_descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get enum_sortDirection_descending;

  /// No description provided for @enum_sortField_agency.
  ///
  /// In en, this message translates to:
  /// **'Agency'**
  String get enum_sortField_agency;

  /// No description provided for @enum_sortField_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get enum_sortField_date;

  /// No description provided for @enum_sortField_dateIssued.
  ///
  /// In en, this message translates to:
  /// **'Date Issued'**
  String get enum_sortField_dateIssued;

  /// No description provided for @enum_sortField_difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get enum_sortField_difficulty;

  /// No description provided for @enum_sortField_diveCount.
  ///
  /// In en, this message translates to:
  /// **'Dive Count'**
  String get enum_sortField_diveCount;

  /// No description provided for @enum_sortField_diveNumber.
  ///
  /// In en, this message translates to:
  /// **'Dive Number'**
  String get enum_sortField_diveNumber;

  /// No description provided for @enum_sortField_duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get enum_sortField_duration;

  /// No description provided for @enum_sortField_endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get enum_sortField_endDate;

  /// No description provided for @enum_sortField_lastServiceDate.
  ///
  /// In en, this message translates to:
  /// **'Last Service'**
  String get enum_sortField_lastServiceDate;

  /// No description provided for @enum_sortField_maxDepth.
  ///
  /// In en, this message translates to:
  /// **'Max Depth'**
  String get enum_sortField_maxDepth;

  /// No description provided for @enum_sortField_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get enum_sortField_name;

  /// No description provided for @enum_sortField_purchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Purchase Date'**
  String get enum_sortField_purchaseDate;

  /// No description provided for @enum_sortField_rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get enum_sortField_rating;

  /// No description provided for @enum_sortField_site.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get enum_sortField_site;

  /// No description provided for @enum_sortField_startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get enum_sortField_startDate;

  /// No description provided for @enum_sortField_status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get enum_sortField_status;

  /// No description provided for @enum_sortField_type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get enum_sortField_type;

  /// No description provided for @enum_speciesCategory_coral.
  ///
  /// In en, this message translates to:
  /// **'Coral'**
  String get enum_speciesCategory_coral;

  /// No description provided for @enum_speciesCategory_fish.
  ///
  /// In en, this message translates to:
  /// **'Fish'**
  String get enum_speciesCategory_fish;

  /// No description provided for @enum_speciesCategory_invertebrate.
  ///
  /// In en, this message translates to:
  /// **'Invertebrate'**
  String get enum_speciesCategory_invertebrate;

  /// No description provided for @enum_speciesCategory_mammal.
  ///
  /// In en, this message translates to:
  /// **'Mammal'**
  String get enum_speciesCategory_mammal;

  /// No description provided for @enum_speciesCategory_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get enum_speciesCategory_other;

  /// No description provided for @enum_speciesCategory_plant.
  ///
  /// In en, this message translates to:
  /// **'Plant/Algae'**
  String get enum_speciesCategory_plant;

  /// No description provided for @enum_speciesCategory_ray.
  ///
  /// In en, this message translates to:
  /// **'Ray'**
  String get enum_speciesCategory_ray;

  /// No description provided for @enum_speciesCategory_shark.
  ///
  /// In en, this message translates to:
  /// **'Shark'**
  String get enum_speciesCategory_shark;

  /// No description provided for @enum_speciesCategory_turtle.
  ///
  /// In en, this message translates to:
  /// **'Turtle'**
  String get enum_speciesCategory_turtle;

  /// No description provided for @enum_tankMaterial_aluminum.
  ///
  /// In en, this message translates to:
  /// **'Aluminum'**
  String get enum_tankMaterial_aluminum;

  /// No description provided for @enum_tankMaterial_carbonFiber.
  ///
  /// In en, this message translates to:
  /// **'Carbon Fiber'**
  String get enum_tankMaterial_carbonFiber;

  /// No description provided for @enum_tankMaterial_steel.
  ///
  /// In en, this message translates to:
  /// **'Steel'**
  String get enum_tankMaterial_steel;

  /// No description provided for @enum_tankRole_backGas.
  ///
  /// In en, this message translates to:
  /// **'Back Gas'**
  String get enum_tankRole_backGas;

  /// No description provided for @enum_tankRole_bailout.
  ///
  /// In en, this message translates to:
  /// **'Bailout'**
  String get enum_tankRole_bailout;

  /// No description provided for @enum_tankRole_deco.
  ///
  /// In en, this message translates to:
  /// **'Deco'**
  String get enum_tankRole_deco;

  /// No description provided for @enum_tankRole_diluent.
  ///
  /// In en, this message translates to:
  /// **'Diluent'**
  String get enum_tankRole_diluent;

  /// No description provided for @enum_tankRole_oxygenSupply.
  ///
  /// In en, this message translates to:
  /// **'O₂ Supply'**
  String get enum_tankRole_oxygenSupply;

  /// No description provided for @enum_tankRole_pony.
  ///
  /// In en, this message translates to:
  /// **'Pony Bottle'**
  String get enum_tankRole_pony;

  /// No description provided for @enum_tankRole_sidemountLeft.
  ///
  /// In en, this message translates to:
  /// **'Sidemount Left'**
  String get enum_tankRole_sidemountLeft;

  /// No description provided for @enum_tankRole_sidemountRight.
  ///
  /// In en, this message translates to:
  /// **'Sidemount Right'**
  String get enum_tankRole_sidemountRight;

  /// No description provided for @enum_tankRole_stage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get enum_tankRole_stage;

  /// No description provided for @enum_visibility_excellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent (>30m / >100ft)'**
  String get enum_visibility_excellent;

  /// No description provided for @enum_visibility_good.
  ///
  /// In en, this message translates to:
  /// **'Good (15-30m / 50-100ft)'**
  String get enum_visibility_good;

  /// No description provided for @enum_visibility_moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate (5-15m / 15-50ft)'**
  String get enum_visibility_moderate;

  /// No description provided for @enum_visibility_poor.
  ///
  /// In en, this message translates to:
  /// **'Poor (<5m / <15ft)'**
  String get enum_visibility_poor;

  /// No description provided for @enum_visibility_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get enum_visibility_unknown;

  /// No description provided for @enum_waterType_brackish.
  ///
  /// In en, this message translates to:
  /// **'Brackish'**
  String get enum_waterType_brackish;

  /// No description provided for @enum_waterType_fresh.
  ///
  /// In en, this message translates to:
  /// **'Fresh Water'**
  String get enum_waterType_fresh;

  /// No description provided for @enum_waterType_salt.
  ///
  /// In en, this message translates to:
  /// **'Salt Water'**
  String get enum_waterType_salt;

  /// No description provided for @enum_weightType_ankleWeights.
  ///
  /// In en, this message translates to:
  /// **'Ankle Weights'**
  String get enum_weightType_ankleWeights;

  /// No description provided for @enum_weightType_backplate.
  ///
  /// In en, this message translates to:
  /// **'Backplate Weights'**
  String get enum_weightType_backplate;

  /// No description provided for @enum_weightType_belt.
  ///
  /// In en, this message translates to:
  /// **'Weight Belt'**
  String get enum_weightType_belt;

  /// No description provided for @enum_weightType_integrated.
  ///
  /// In en, this message translates to:
  /// **'Integrated Weights'**
  String get enum_weightType_integrated;

  /// No description provided for @enum_weightType_mixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed/Combined'**
  String get enum_weightType_mixed;

  /// No description provided for @enum_weightType_trimWeights.
  ///
  /// In en, this message translates to:
  /// **'Trim Weights'**
  String get enum_weightType_trimWeights;

  /// No description provided for @equipment_addSheet_brandHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Scubapro'**
  String get equipment_addSheet_brandHint;

  /// No description provided for @equipment_addSheet_brandLabel.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get equipment_addSheet_brandLabel;

  /// No description provided for @equipment_addSheet_closeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get equipment_addSheet_closeTooltip;

  /// No description provided for @equipment_addSheet_currencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get equipment_addSheet_currencyLabel;

  /// No description provided for @equipment_addSheet_dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get equipment_addSheet_dateLabel;

  /// No description provided for @equipment_addSheet_errorSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Error adding equipment: {error}'**
  String equipment_addSheet_errorSnackbar(Object error);

  /// No description provided for @equipment_addSheet_modelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., MK25 EVO'**
  String get equipment_addSheet_modelHint;

  /// No description provided for @equipment_addSheet_modelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get equipment_addSheet_modelLabel;

  /// No description provided for @equipment_addSheet_nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., My Primary Regulator'**
  String get equipment_addSheet_nameHint;

  /// No description provided for @equipment_addSheet_nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get equipment_addSheet_nameLabel;

  /// No description provided for @equipment_addSheet_nameValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get equipment_addSheet_nameValidation;

  /// No description provided for @equipment_addSheet_notesHint.
  ///
  /// In en, this message translates to:
  /// **'Additional notes...'**
  String get equipment_addSheet_notesHint;

  /// No description provided for @equipment_addSheet_notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get equipment_addSheet_notesLabel;

  /// No description provided for @equipment_addSheet_priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get equipment_addSheet_priceLabel;

  /// No description provided for @equipment_addSheet_purchaseInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase Information'**
  String get equipment_addSheet_purchaseInfoTitle;

  /// No description provided for @equipment_addSheet_serialNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get equipment_addSheet_serialNumberLabel;

  /// No description provided for @equipment_addSheet_serviceIntervalHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 365 for yearly'**
  String get equipment_addSheet_serviceIntervalHint;

  /// No description provided for @equipment_addSheet_serviceIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Service Interval (days)'**
  String get equipment_addSheet_serviceIntervalLabel;

  /// No description provided for @equipment_addSheet_sizeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., M, L, 42'**
  String get equipment_addSheet_sizeHint;

  /// No description provided for @equipment_addSheet_sizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get equipment_addSheet_sizeLabel;

  /// No description provided for @equipment_addSheet_submitButton.
  ///
  /// In en, this message translates to:
  /// **'Add Equipment'**
  String get equipment_addSheet_submitButton;

  /// No description provided for @equipment_addSheet_successSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Equipment added successfully'**
  String get equipment_addSheet_successSnackbar;

  /// No description provided for @equipment_addSheet_title.
  ///
  /// In en, this message translates to:
  /// **'Add Equipment'**
  String get equipment_addSheet_title;

  /// No description provided for @equipment_addSheet_typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get equipment_addSheet_typeLabel;

  /// No description provided for @equipment_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment_appBar_title;

  /// No description provided for @equipment_deleteDialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get equipment_deleteDialog_cancel;

  /// No description provided for @equipment_deleteDialog_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get equipment_deleteDialog_confirm;

  /// No description provided for @equipment_deleteDialog_content.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this equipment? This action cannot be undone.'**
  String get equipment_deleteDialog_content;

  /// No description provided for @equipment_deleteDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Equipment'**
  String get equipment_deleteDialog_title;

  /// No description provided for @equipment_detail_brandLabel.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get equipment_detail_brandLabel;

  /// No description provided for @equipment_detail_daysOverdue.
  ///
  /// In en, this message translates to:
  /// **'{days} days overdue'**
  String equipment_detail_daysOverdue(Object days);

  /// No description provided for @equipment_detail_daysUntilService.
  ///
  /// In en, this message translates to:
  /// **'{days} days until service'**
  String equipment_detail_daysUntilService(Object days);

  /// No description provided for @equipment_detail_detailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get equipment_detail_detailsTitle;

  /// No description provided for @equipment_detail_divesCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} dives'**
  String equipment_detail_divesCountPlural(Object count);

  /// No description provided for @equipment_detail_divesCountSingular.
  ///
  /// In en, this message translates to:
  /// **'{count} dive'**
  String equipment_detail_divesCountSingular(Object count);

  /// No description provided for @equipment_detail_divesLabel.
  ///
  /// In en, this message translates to:
  /// **'Dives'**
  String get equipment_detail_divesLabel;

  /// No description provided for @equipment_detail_divesSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'View dives using this equipment'**
  String get equipment_detail_divesSemanticLabel;

  /// No description provided for @equipment_detail_durationDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String equipment_detail_durationDays(Object days);

  /// No description provided for @equipment_detail_durationMonths.
  ///
  /// In en, this message translates to:
  /// **'{months} months'**
  String equipment_detail_durationMonths(Object months);

  /// No description provided for @equipment_detail_durationYearsMonthsPluralPlural.
  ///
  /// In en, this message translates to:
  /// **'{years} years, {months} months'**
  String equipment_detail_durationYearsMonthsPluralPlural(
    Object years,
    Object months,
  );

  /// No description provided for @equipment_detail_durationYearsMonthsPluralSingular.
  ///
  /// In en, this message translates to:
  /// **'{years} years, {months} month'**
  String equipment_detail_durationYearsMonthsPluralSingular(
    Object years,
    Object months,
  );

  /// No description provided for @equipment_detail_durationYearsMonthsSingularPlural.
  ///
  /// In en, this message translates to:
  /// **'{years} year, {months} months'**
  String equipment_detail_durationYearsMonthsSingularPlural(
    Object years,
    Object months,
  );

  /// No description provided for @equipment_detail_durationYearsMonthsSingularSingular.
  ///
  /// In en, this message translates to:
  /// **'{years} year, {months} month'**
  String equipment_detail_durationYearsMonthsSingularSingular(
    Object years,
    Object months,
  );

  /// No description provided for @equipment_detail_durationYearsPlural.
  ///
  /// In en, this message translates to:
  /// **'{years} years'**
  String equipment_detail_durationYearsPlural(Object years);

  /// No description provided for @equipment_detail_durationYearsSingular.
  ///
  /// In en, this message translates to:
  /// **'{years} year'**
  String equipment_detail_durationYearsSingular(Object years);

  /// No description provided for @equipment_detail_editTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit Equipment'**
  String get equipment_detail_editTooltip;

  /// No description provided for @equipment_detail_editTooltipShort.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get equipment_detail_editTooltipShort;

  /// No description provided for @equipment_detail_errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String equipment_detail_errorMessage(Object error);

  /// No description provided for @equipment_detail_errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get equipment_detail_errorTitle;

  /// No description provided for @equipment_detail_lastServiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Service'**
  String get equipment_detail_lastServiceLabel;

  /// No description provided for @equipment_detail_loadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get equipment_detail_loadingTitle;

  /// No description provided for @equipment_detail_modelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get equipment_detail_modelLabel;

  /// No description provided for @equipment_detail_nextServiceDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Next Service Due'**
  String get equipment_detail_nextServiceDueLabel;

  /// No description provided for @equipment_detail_notFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This equipment item no longer exists.'**
  String get equipment_detail_notFoundMessage;

  /// No description provided for @equipment_detail_notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Equipment Not Found'**
  String get equipment_detail_notFoundTitle;

  /// No description provided for @equipment_detail_notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get equipment_detail_notesTitle;

  /// No description provided for @equipment_detail_ownedForLabel.
  ///
  /// In en, this message translates to:
  /// **'Owned For'**
  String get equipment_detail_ownedForLabel;

  /// No description provided for @equipment_detail_purchaseDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Purchase Date'**
  String get equipment_detail_purchaseDateLabel;

  /// No description provided for @equipment_detail_purchasePriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Purchase Price'**
  String get equipment_detail_purchasePriceLabel;

  /// No description provided for @equipment_detail_retiredChip.
  ///
  /// In en, this message translates to:
  /// **'Retired'**
  String get equipment_detail_retiredChip;

  /// No description provided for @equipment_detail_serialNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get equipment_detail_serialNumberLabel;

  /// No description provided for @equipment_detail_serviceInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Service Information'**
  String get equipment_detail_serviceInfoTitle;

  /// No description provided for @equipment_detail_serviceIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Service Interval'**
  String get equipment_detail_serviceIntervalLabel;

  /// No description provided for @equipment_detail_serviceIntervalValue.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String equipment_detail_serviceIntervalValue(Object days);

  /// No description provided for @equipment_detail_serviceOverdue.
  ///
  /// In en, this message translates to:
  /// **'Service is overdue!'**
  String get equipment_detail_serviceOverdue;

  /// No description provided for @equipment_detail_sizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get equipment_detail_sizeLabel;

  /// No description provided for @equipment_detail_statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get equipment_detail_statusLabel;

  /// No description provided for @equipment_detail_tripsCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} trips'**
  String equipment_detail_tripsCountPlural(Object count);

  /// No description provided for @equipment_detail_tripsCountSingular.
  ///
  /// In en, this message translates to:
  /// **'{count} trip'**
  String equipment_detail_tripsCountSingular(Object count);

  /// No description provided for @equipment_detail_tripsLabel.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get equipment_detail_tripsLabel;

  /// No description provided for @equipment_detail_tripsSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'View trips using this equipment'**
  String get equipment_detail_tripsSemanticLabel;

  /// No description provided for @equipment_edit_appBar_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Equipment'**
  String get equipment_edit_appBar_editTitle;

  /// No description provided for @equipment_edit_appBar_newTitle.
  ///
  /// In en, this message translates to:
  /// **'New Equipment'**
  String get equipment_edit_appBar_newTitle;

  /// No description provided for @equipment_edit_appBar_saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get equipment_edit_appBar_saveButton;

  /// No description provided for @equipment_edit_appBar_saveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save equipment changes'**
  String get equipment_edit_appBar_saveTooltip;

  /// No description provided for @equipment_edit_brandLabel.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get equipment_edit_brandLabel;

  /// No description provided for @equipment_edit_clearDate.
  ///
  /// In en, this message translates to:
  /// **'Clear Date'**
  String get equipment_edit_clearDate;

  /// No description provided for @equipment_edit_currencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get equipment_edit_currencyLabel;

  /// No description provided for @equipment_edit_disableReminders.
  ///
  /// In en, this message translates to:
  /// **'Disable Reminders'**
  String get equipment_edit_disableReminders;

  /// No description provided for @equipment_edit_disableRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off all notifications for this item'**
  String get equipment_edit_disableRemindersSubtitle;

  /// No description provided for @equipment_edit_discardDialog_content.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to leave?'**
  String get equipment_edit_discardDialog_content;

  /// No description provided for @equipment_edit_discardDialog_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get equipment_edit_discardDialog_discard;

  /// No description provided for @equipment_edit_discardDialog_keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get equipment_edit_discardDialog_keepEditing;

  /// No description provided for @equipment_edit_discardDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes?'**
  String get equipment_edit_discardDialog_title;

  /// No description provided for @equipment_edit_embeddedHeader_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get equipment_edit_embeddedHeader_cancelButton;

  /// No description provided for @equipment_edit_embeddedHeader_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Equipment'**
  String get equipment_edit_embeddedHeader_editTitle;

  /// No description provided for @equipment_edit_embeddedHeader_newTitle.
  ///
  /// In en, this message translates to:
  /// **'New Equipment'**
  String get equipment_edit_embeddedHeader_newTitle;

  /// No description provided for @equipment_edit_embeddedHeader_saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get equipment_edit_embeddedHeader_saveButton;

  /// No description provided for @equipment_edit_embeddedHeader_saveTooltip_edit.
  ///
  /// In en, this message translates to:
  /// **'Save equipment changes'**
  String get equipment_edit_embeddedHeader_saveTooltip_edit;

  /// No description provided for @equipment_edit_embeddedHeader_saveTooltip_new.
  ///
  /// In en, this message translates to:
  /// **'Add new equipment'**
  String get equipment_edit_embeddedHeader_saveTooltip_new;

  /// No description provided for @equipment_edit_errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String equipment_edit_errorMessage(Object error);

  /// No description provided for @equipment_edit_errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get equipment_edit_errorTitle;

  /// No description provided for @equipment_edit_lastServiceDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Service Date'**
  String get equipment_edit_lastServiceDateLabel;

  /// No description provided for @equipment_edit_loadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get equipment_edit_loadingTitle;

  /// No description provided for @equipment_edit_modelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get equipment_edit_modelLabel;

  /// No description provided for @equipment_edit_nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., My Primary Regulator'**
  String get equipment_edit_nameHint;

  /// No description provided for @equipment_edit_nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get equipment_edit_nameLabel;

  /// No description provided for @equipment_edit_nameValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get equipment_edit_nameValidation;

  /// No description provided for @equipment_edit_notFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This equipment item no longer exists.'**
  String get equipment_edit_notFoundMessage;

  /// No description provided for @equipment_edit_notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Equipment Not Found'**
  String get equipment_edit_notFoundTitle;

  /// No description provided for @equipment_edit_notesHint.
  ///
  /// In en, this message translates to:
  /// **'Additional notes about this equipment...'**
  String get equipment_edit_notesHint;

  /// No description provided for @equipment_edit_notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get equipment_edit_notesLabel;

  /// No description provided for @equipment_edit_notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Override global notification settings for this item'**
  String get equipment_edit_notificationsSubtitle;

  /// No description provided for @equipment_edit_notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications (Optional)'**
  String get equipment_edit_notificationsTitle;

  /// No description provided for @equipment_edit_purchaseDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Purchase Date'**
  String get equipment_edit_purchaseDateLabel;

  /// No description provided for @equipment_edit_purchaseInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase Information'**
  String get equipment_edit_purchaseInfoTitle;

  /// No description provided for @equipment_edit_purchasePriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Purchase Price'**
  String get equipment_edit_purchasePriceLabel;

  /// No description provided for @equipment_edit_remindMeBeforeServiceDue.
  ///
  /// In en, this message translates to:
  /// **'Remind me before service is due:'**
  String get equipment_edit_remindMeBeforeServiceDue;

  /// No description provided for @equipment_edit_reminderDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String equipment_edit_reminderDays(Object days);

  /// No description provided for @equipment_edit_saveButton_edit.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get equipment_edit_saveButton_edit;

  /// No description provided for @equipment_edit_saveButton_new.
  ///
  /// In en, this message translates to:
  /// **'Add Equipment'**
  String get equipment_edit_saveButton_new;

  /// No description provided for @equipment_edit_saveTooltip_edit.
  ///
  /// In en, this message translates to:
  /// **'Save equipment changes'**
  String get equipment_edit_saveTooltip_edit;

  /// No description provided for @equipment_edit_saveTooltip_new.
  ///
  /// In en, this message translates to:
  /// **'Add new equipment item'**
  String get equipment_edit_saveTooltip_new;

  /// No description provided for @equipment_edit_selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get equipment_edit_selectDate;

  /// No description provided for @equipment_edit_serialNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get equipment_edit_serialNumberLabel;

  /// No description provided for @equipment_edit_serviceIntervalHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 365 for yearly'**
  String get equipment_edit_serviceIntervalHint;

  /// No description provided for @equipment_edit_serviceIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Service Interval (days)'**
  String get equipment_edit_serviceIntervalLabel;

  /// No description provided for @equipment_edit_serviceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Service Settings'**
  String get equipment_edit_serviceSettingsTitle;

  /// No description provided for @equipment_edit_sizeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., M, L, 42'**
  String get equipment_edit_sizeHint;

  /// No description provided for @equipment_edit_sizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get equipment_edit_sizeLabel;

  /// No description provided for @equipment_edit_snackbar_added.
  ///
  /// In en, this message translates to:
  /// **'Equipment added'**
  String get equipment_edit_snackbar_added;

  /// No description provided for @equipment_edit_snackbar_error.
  ///
  /// In en, this message translates to:
  /// **'Error saving equipment: {error}'**
  String equipment_edit_snackbar_error(Object error);

  /// No description provided for @equipment_edit_snackbar_updated.
  ///
  /// In en, this message translates to:
  /// **'Equipment updated'**
  String get equipment_edit_snackbar_updated;

  /// No description provided for @equipment_edit_statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get equipment_edit_statusLabel;

  /// No description provided for @equipment_edit_typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type *'**
  String get equipment_edit_typeLabel;

  /// No description provided for @equipment_edit_useCustomReminders.
  ///
  /// In en, this message translates to:
  /// **'Use Custom Reminders'**
  String get equipment_edit_useCustomReminders;

  /// No description provided for @equipment_edit_useCustomRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set different reminder days for this item'**
  String get equipment_edit_useCustomRemindersSubtitle;

  /// No description provided for @equipment_fab_addEquipment.
  ///
  /// In en, this message translates to:
  /// **'Add Equipment'**
  String get equipment_fab_addEquipment;

  /// No description provided for @equipment_list_emptyState_addFirstButton.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Equipment'**
  String get equipment_list_emptyState_addFirstButton;

  /// No description provided for @equipment_list_emptyState_addPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add your diving equipment to track usage and service'**
  String get equipment_list_emptyState_addPrompt;

  /// No description provided for @equipment_list_emptyState_filterText_equipment.
  ///
  /// In en, this message translates to:
  /// **'equipment'**
  String get equipment_list_emptyState_filterText_equipment;

  /// No description provided for @equipment_list_emptyState_filterText_serviceDue.
  ///
  /// In en, this message translates to:
  /// **'equipment needing service'**
  String get equipment_list_emptyState_filterText_serviceDue;

  /// No description provided for @equipment_list_emptyState_filterText_status.
  ///
  /// In en, this message translates to:
  /// **'{status} equipment'**
  String equipment_list_emptyState_filterText_status(Object status);

  /// No description provided for @equipment_list_emptyState_noEquipment.
  ///
  /// In en, this message translates to:
  /// **'No {filterText}'**
  String equipment_list_emptyState_noEquipment(Object filterText);

  /// No description provided for @equipment_list_emptyState_noStatusMatch.
  ///
  /// In en, this message translates to:
  /// **'No equipment with this status'**
  String get equipment_list_emptyState_noStatusMatch;

  /// No description provided for @equipment_list_emptyState_serviceDueUpToDate.
  ///
  /// In en, this message translates to:
  /// **'All your equipment is up to date on service!'**
  String get equipment_list_emptyState_serviceDueUpToDate;

  /// No description provided for @equipment_list_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading equipment: {error}'**
  String equipment_list_errorLoading(Object error);

  /// No description provided for @equipment_list_filterAll.
  ///
  /// In en, this message translates to:
  /// **'All Equipment'**
  String get equipment_list_filterAll;

  /// No description provided for @equipment_list_filterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter:'**
  String get equipment_list_filterLabel;

  /// No description provided for @equipment_list_filterServiceDue.
  ///
  /// In en, this message translates to:
  /// **'Service Due'**
  String get equipment_list_filterServiceDue;

  /// No description provided for @equipment_list_retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get equipment_list_retryButton;

  /// No description provided for @equipment_list_searchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search Equipment'**
  String get equipment_list_searchTooltip;

  /// No description provided for @equipment_list_setsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Equipment Sets'**
  String get equipment_list_setsTooltip;

  /// No description provided for @equipment_list_sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort Equipment'**
  String get equipment_list_sortTitle;

  /// No description provided for @equipment_list_sortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get equipment_list_sortTooltip;

  /// No description provided for @equipment_list_tile_daysCount.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String equipment_list_tile_daysCount(Object days);

  /// No description provided for @equipment_list_tile_serviceDueChip.
  ///
  /// In en, this message translates to:
  /// **'Service Due'**
  String get equipment_list_tile_serviceDueChip;

  /// No description provided for @equipment_list_tile_serviceIn.
  ///
  /// In en, this message translates to:
  /// **'Service in'**
  String get equipment_list_tile_serviceIn;

  /// No description provided for @equipment_menu_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get equipment_menu_delete;

  /// No description provided for @equipment_menu_markAsServiced.
  ///
  /// In en, this message translates to:
  /// **'Mark as Serviced'**
  String get equipment_menu_markAsServiced;

  /// No description provided for @equipment_menu_reactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get equipment_menu_reactivate;

  /// No description provided for @equipment_menu_retireEquipment.
  ///
  /// In en, this message translates to:
  /// **'Retire Equipment'**
  String get equipment_menu_retireEquipment;

  /// No description provided for @equipment_search_backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get equipment_search_backTooltip;

  /// No description provided for @equipment_search_clearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get equipment_search_clearTooltip;

  /// No description provided for @equipment_search_fieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Search equipment...'**
  String get equipment_search_fieldLabel;

  /// No description provided for @equipment_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, brand, model, or serial number'**
  String get equipment_search_hint;

  /// No description provided for @equipment_search_noResults.
  ///
  /// In en, this message translates to:
  /// **'No equipment found for \"{query}\"'**
  String equipment_search_noResults(Object query);

  /// No description provided for @equipment_serviceDialog_addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get equipment_serviceDialog_addButton;

  /// No description provided for @equipment_serviceDialog_addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Service Record'**
  String get equipment_serviceDialog_addTitle;

  /// No description provided for @equipment_serviceDialog_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get equipment_serviceDialog_cancelButton;

  /// No description provided for @equipment_serviceDialog_clearNextServiceDateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear Next Service Date'**
  String get equipment_serviceDialog_clearNextServiceDateTooltip;

  /// No description provided for @equipment_serviceDialog_costHint.
  ///
  /// In en, this message translates to:
  /// **'0.00'**
  String get equipment_serviceDialog_costHint;

  /// No description provided for @equipment_serviceDialog_costLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get equipment_serviceDialog_costLabel;

  /// No description provided for @equipment_serviceDialog_costValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get equipment_serviceDialog_costValidation;

  /// No description provided for @equipment_serviceDialog_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Service Record'**
  String get equipment_serviceDialog_editTitle;

  /// No description provided for @equipment_serviceDialog_nextServiceDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Next Service Due'**
  String get equipment_serviceDialog_nextServiceDueLabel;

  /// No description provided for @equipment_serviceDialog_nextServiceDueSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Pick next service due date'**
  String get equipment_serviceDialog_nextServiceDueSemanticLabel;

  /// No description provided for @equipment_serviceDialog_nextServiceNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get equipment_serviceDialog_nextServiceNotSet;

  /// No description provided for @equipment_serviceDialog_notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get equipment_serviceDialog_notesLabel;

  /// No description provided for @equipment_serviceDialog_providerHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Dive Shop Name'**
  String get equipment_serviceDialog_providerHint;

  /// No description provided for @equipment_serviceDialog_providerLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider/Shop'**
  String get equipment_serviceDialog_providerLabel;

  /// No description provided for @equipment_serviceDialog_serviceDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Service Date'**
  String get equipment_serviceDialog_serviceDateLabel;

  /// No description provided for @equipment_serviceDialog_serviceDateSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Pick service date'**
  String get equipment_serviceDialog_serviceDateSemanticLabel;

  /// No description provided for @equipment_serviceDialog_serviceTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Service Type'**
  String get equipment_serviceDialog_serviceTypeLabel;

  /// No description provided for @equipment_serviceDialog_snackbar_added.
  ///
  /// In en, this message translates to:
  /// **'Service record added'**
  String get equipment_serviceDialog_snackbar_added;

  /// No description provided for @equipment_serviceDialog_snackbar_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String equipment_serviceDialog_snackbar_error(Object error);

  /// No description provided for @equipment_serviceDialog_snackbar_updated.
  ///
  /// In en, this message translates to:
  /// **'Service record updated'**
  String get equipment_serviceDialog_snackbar_updated;

  /// No description provided for @equipment_serviceDialog_updateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get equipment_serviceDialog_updateButton;

  /// No description provided for @equipment_service_addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get equipment_service_addButton;

  /// No description provided for @equipment_service_deleteDialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get equipment_service_deleteDialog_cancel;

  /// No description provided for @equipment_service_deleteDialog_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get equipment_service_deleteDialog_confirm;

  /// No description provided for @equipment_service_deleteDialog_content.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this {serviceType} record?'**
  String equipment_service_deleteDialog_content(Object serviceType);

  /// No description provided for @equipment_service_deleteDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Service Record?'**
  String get equipment_service_deleteDialog_title;

  /// No description provided for @equipment_service_deleteMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get equipment_service_deleteMenuItem;

  /// No description provided for @equipment_service_editMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get equipment_service_editMenuItem;

  /// No description provided for @equipment_service_emptyState.
  ///
  /// In en, this message translates to:
  /// **'No service records yet'**
  String get equipment_service_emptyState;

  /// No description provided for @equipment_service_historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Service History'**
  String get equipment_service_historyTitle;

  /// No description provided for @equipment_service_snackbar_deleted.
  ///
  /// In en, this message translates to:
  /// **'Service record deleted'**
  String get equipment_service_snackbar_deleted;

  /// No description provided for @equipment_service_totalCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Service Cost'**
  String get equipment_service_totalCostLabel;

  /// No description provided for @equipment_setDetail_addEquipmentButton.
  ///
  /// In en, this message translates to:
  /// **'Add Equipment'**
  String get equipment_setDetail_addEquipmentButton;

  /// No description provided for @equipment_setDetail_deleteDialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get equipment_setDetail_deleteDialog_cancel;

  /// No description provided for @equipment_setDetail_deleteDialog_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get equipment_setDetail_deleteDialog_confirm;

  /// No description provided for @equipment_setDetail_deleteDialog_content.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this equipment set? The equipment items in the set will not be deleted.'**
  String get equipment_setDetail_deleteDialog_content;

  /// No description provided for @equipment_setDetail_deleteDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Equipment Set'**
  String get equipment_setDetail_deleteDialog_title;

  /// No description provided for @equipment_setDetail_deleteMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get equipment_setDetail_deleteMenuItem;

  /// No description provided for @equipment_setDetail_editTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit Set'**
  String get equipment_setDetail_editTooltip;

  /// No description provided for @equipment_setDetail_emptySet.
  ///
  /// In en, this message translates to:
  /// **'No equipment in this set'**
  String get equipment_setDetail_emptySet;

  /// No description provided for @equipment_setDetail_equipmentInSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Equipment in This Set'**
  String get equipment_setDetail_equipmentInSetTitle;

  /// No description provided for @equipment_setDetail_errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String equipment_setDetail_errorMessage(Object error);

  /// No description provided for @equipment_setDetail_errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get equipment_setDetail_errorTitle;

  /// No description provided for @equipment_setDetail_loadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get equipment_setDetail_loadingTitle;

  /// No description provided for @equipment_setDetail_notFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This equipment set no longer exists.'**
  String get equipment_setDetail_notFoundMessage;

  /// No description provided for @equipment_setDetail_notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Not Found'**
  String get equipment_setDetail_notFoundTitle;

  /// No description provided for @equipment_setDetail_snackbar_deleted.
  ///
  /// In en, this message translates to:
  /// **'Equipment set deleted'**
  String get equipment_setDetail_snackbar_deleted;

  /// No description provided for @equipment_setEdit_addEquipmentFirst.
  ///
  /// In en, this message translates to:
  /// **'Add equipment first before creating a set.'**
  String get equipment_setEdit_addEquipmentFirst;

  /// No description provided for @equipment_setEdit_appBar_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Set'**
  String get equipment_setEdit_appBar_editTitle;

  /// No description provided for @equipment_setEdit_appBar_newTitle.
  ///
  /// In en, this message translates to:
  /// **'New Equipment Set'**
  String get equipment_setEdit_appBar_newTitle;

  /// No description provided for @equipment_setEdit_descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Optional description...'**
  String get equipment_setEdit_descriptionHint;

  /// No description provided for @equipment_setEdit_descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get equipment_setEdit_descriptionLabel;

  /// No description provided for @equipment_setEdit_errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String equipment_setEdit_errorMessage(Object error);

  /// No description provided for @equipment_setEdit_errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get equipment_setEdit_errorTitle;

  /// No description provided for @equipment_setEdit_loadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get equipment_setEdit_loadingTitle;

  /// No description provided for @equipment_setEdit_nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Warm Water Setup'**
  String get equipment_setEdit_nameHint;

  /// No description provided for @equipment_setEdit_nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Set Name *'**
  String get equipment_setEdit_nameLabel;

  /// No description provided for @equipment_setEdit_nameValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get equipment_setEdit_nameValidation;

  /// No description provided for @equipment_setEdit_noEquipmentAvailable.
  ///
  /// In en, this message translates to:
  /// **'No equipment available'**
  String get equipment_setEdit_noEquipmentAvailable;

  /// No description provided for @equipment_setEdit_notFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This equipment set no longer exists.'**
  String get equipment_setEdit_notFoundMessage;

  /// No description provided for @equipment_setEdit_notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Not Found'**
  String get equipment_setEdit_notFoundTitle;

  /// No description provided for @equipment_setEdit_saveButton_edit.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get equipment_setEdit_saveButton_edit;

  /// No description provided for @equipment_setEdit_saveButton_new.
  ///
  /// In en, this message translates to:
  /// **'Create Set'**
  String get equipment_setEdit_saveButton_new;

  /// No description provided for @equipment_setEdit_saveTooltip_edit.
  ///
  /// In en, this message translates to:
  /// **'Save equipment set changes'**
  String get equipment_setEdit_saveTooltip_edit;

  /// No description provided for @equipment_setEdit_saveTooltip_new.
  ///
  /// In en, this message translates to:
  /// **'Create new equipment set'**
  String get equipment_setEdit_saveTooltip_new;

  /// No description provided for @equipment_setEdit_selectEquipmentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the equipment items to include in this set.'**
  String get equipment_setEdit_selectEquipmentSubtitle;

  /// No description provided for @equipment_setEdit_selectEquipmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Equipment'**
  String get equipment_setEdit_selectEquipmentTitle;

  /// No description provided for @equipment_setEdit_snackbar_created.
  ///
  /// In en, this message translates to:
  /// **'Equipment set created'**
  String get equipment_setEdit_snackbar_created;

  /// No description provided for @equipment_setEdit_snackbar_error.
  ///
  /// In en, this message translates to:
  /// **'Error saving equipment set: {error}'**
  String equipment_setEdit_snackbar_error(Object error);

  /// No description provided for @equipment_setEdit_snackbar_updated.
  ///
  /// In en, this message translates to:
  /// **'Equipment set updated'**
  String get equipment_setEdit_snackbar_updated;

  /// No description provided for @equipment_sets_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Equipment Sets'**
  String get equipment_sets_appBar_title;

  /// No description provided for @equipment_sets_emptyState_createFirstButton.
  ///
  /// In en, this message translates to:
  /// **'Create Your First Set'**
  String get equipment_sets_emptyState_createFirstButton;

  /// No description provided for @equipment_sets_emptyState_description.
  ///
  /// In en, this message translates to:
  /// **'Create equipment sets to quickly add commonly used combinations of equipment to your dives.'**
  String get equipment_sets_emptyState_description;

  /// No description provided for @equipment_sets_emptyState_title.
  ///
  /// In en, this message translates to:
  /// **'No Equipment Sets'**
  String get equipment_sets_emptyState_title;

  /// No description provided for @equipment_sets_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading sets: {error}'**
  String equipment_sets_errorLoading(Object error);

  /// No description provided for @equipment_sets_fabTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create a new equipment set'**
  String get equipment_sets_fabTooltip;

  /// No description provided for @equipment_sets_fab_createSet.
  ///
  /// In en, this message translates to:
  /// **'Create Set'**
  String get equipment_sets_fab_createSet;

  /// No description provided for @equipment_sets_itemCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String equipment_sets_itemCountPlural(Object count);

  /// No description provided for @equipment_sets_itemCountSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} in set'**
  String equipment_sets_itemCountSemanticLabel(Object count);

  /// No description provided for @equipment_sets_itemCountSingular.
  ///
  /// In en, this message translates to:
  /// **'{count} item'**
  String equipment_sets_itemCountSingular(Object count);

  /// No description provided for @equipment_sets_retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get equipment_sets_retryButton;

  /// No description provided for @equipment_snackbar_deleted.
  ///
  /// In en, this message translates to:
  /// **'Equipment deleted'**
  String get equipment_snackbar_deleted;

  /// No description provided for @equipment_snackbar_markedAsServiced.
  ///
  /// In en, this message translates to:
  /// **'Marked as serviced'**
  String get equipment_snackbar_markedAsServiced;

  /// No description provided for @equipment_snackbar_reactivated.
  ///
  /// In en, this message translates to:
  /// **'Equipment reactivated'**
  String get equipment_snackbar_reactivated;

  /// No description provided for @equipment_snackbar_retired.
  ///
  /// In en, this message translates to:
  /// **'Equipment retired'**
  String get equipment_snackbar_retired;

  /// No description provided for @equipment_summary_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get equipment_summary_active;

  /// No description provided for @equipment_summary_addEquipmentButton.
  ///
  /// In en, this message translates to:
  /// **'Add Equipment'**
  String get equipment_summary_addEquipmentButton;

  /// No description provided for @equipment_summary_equipmentSetsButton.
  ///
  /// In en, this message translates to:
  /// **'Equipment Sets'**
  String get equipment_summary_equipmentSetsButton;

  /// No description provided for @equipment_summary_overviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get equipment_summary_overviewTitle;

  /// No description provided for @equipment_summary_quickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get equipment_summary_quickActionsTitle;

  /// No description provided for @equipment_summary_recentEquipmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Equipment'**
  String get equipment_summary_recentEquipmentTitle;

  /// No description provided for @equipment_summary_recentSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}, {type}'**
  String equipment_summary_recentSemanticLabel(Object name, Object type);

  /// No description provided for @equipment_summary_selectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select equipment from the list to view details'**
  String get equipment_summary_selectPrompt;

  /// No description provided for @equipment_summary_serviceDue.
  ///
  /// In en, this message translates to:
  /// **'Service Due'**
  String get equipment_summary_serviceDue;

  /// No description provided for @equipment_summary_serviceDueSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}, {type}, service due'**
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type);

  /// No description provided for @equipment_summary_serviceDueTitle.
  ///
  /// In en, this message translates to:
  /// **'Service Due'**
  String get equipment_summary_serviceDueTitle;

  /// No description provided for @equipment_summary_title.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment_summary_title;

  /// No description provided for @equipment_summary_totalItems.
  ///
  /// In en, this message translates to:
  /// **'Total Items'**
  String get equipment_summary_totalItems;

  /// No description provided for @equipment_summary_totalValue.
  ///
  /// In en, this message translates to:
  /// **'Total Value'**
  String get equipment_summary_totalValue;

  /// Prefix for approximate values, e.g. ~80 cuft
  ///
  /// In en, this message translates to:
  /// **'~'**
  String get formatter_approximate_prefix;

  /// Connector word between date and time, e.g. 'Jan 15 at 2:30 PM'
  ///
  /// In en, this message translates to:
  /// **'at'**
  String get formatter_connector_at;

  /// Connector word for date ranges with no end, e.g. 'From Jan 15'
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get formatter_connector_from;

  /// Connector word for date ranges with no start, e.g. 'Until Jan 20'
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get formatter_connector_until;

  /// No description provided for @gas_air_description.
  ///
  /// In en, this message translates to:
  /// **'Standard air (21% O2)'**
  String get gas_air_description;

  /// No description provided for @gas_air_displayName.
  ///
  /// In en, this message translates to:
  /// **'Air'**
  String get gas_air_displayName;

  /// No description provided for @gas_diluentAir_description.
  ///
  /// In en, this message translates to:
  /// **'Standard air diluent for shallow CCR'**
  String get gas_diluentAir_description;

  /// No description provided for @gas_diluentAir_displayName.
  ///
  /// In en, this message translates to:
  /// **'Air Diluent'**
  String get gas_diluentAir_displayName;

  /// No description provided for @gas_diluentTx1070_description.
  ///
  /// In en, this message translates to:
  /// **'Hypoxic diluent for very deep CCR'**
  String get gas_diluentTx1070_description;

  /// No description provided for @gas_diluentTx1070_displayName.
  ///
  /// In en, this message translates to:
  /// **'Tx 10/70'**
  String get gas_diluentTx1070_displayName;

  /// No description provided for @gas_diluentTx1260_description.
  ///
  /// In en, this message translates to:
  /// **'Hypoxic diluent for deep CCR'**
  String get gas_diluentTx1260_description;

  /// No description provided for @gas_diluentTx1260_displayName.
  ///
  /// In en, this message translates to:
  /// **'Tx 12/60'**
  String get gas_diluentTx1260_displayName;

  /// No description provided for @gas_ean32_description.
  ///
  /// In en, this message translates to:
  /// **'Enriched Air Nitrox 32%'**
  String get gas_ean32_description;

  /// No description provided for @gas_ean32_displayName.
  ///
  /// In en, this message translates to:
  /// **'EAN32'**
  String get gas_ean32_displayName;

  /// No description provided for @gas_ean36_description.
  ///
  /// In en, this message translates to:
  /// **'Enriched Air Nitrox 36%'**
  String get gas_ean36_description;

  /// No description provided for @gas_ean36_displayName.
  ///
  /// In en, this message translates to:
  /// **'EAN36'**
  String get gas_ean36_displayName;

  /// No description provided for @gas_ean40_description.
  ///
  /// In en, this message translates to:
  /// **'Enriched Air Nitrox 40%'**
  String get gas_ean40_description;

  /// No description provided for @gas_ean40_displayName.
  ///
  /// In en, this message translates to:
  /// **'EAN40'**
  String get gas_ean40_displayName;

  /// No description provided for @gas_ean50_description.
  ///
  /// In en, this message translates to:
  /// **'Deco gas - 50% O2'**
  String get gas_ean50_description;

  /// No description provided for @gas_ean50_displayName.
  ///
  /// In en, this message translates to:
  /// **'EAN50'**
  String get gas_ean50_displayName;

  /// No description provided for @gas_helitrox2525_description.
  ///
  /// In en, this message translates to:
  /// **'Helitrox 25/25 (recreational tech)'**
  String get gas_helitrox2525_description;

  /// No description provided for @gas_helitrox2525_displayName.
  ///
  /// In en, this message translates to:
  /// **'Helitrox 25/25'**
  String get gas_helitrox2525_displayName;

  /// No description provided for @gas_oxygen_description.
  ///
  /// In en, this message translates to:
  /// **'Pure oxygen (6m deco only)'**
  String get gas_oxygen_description;

  /// No description provided for @gas_oxygen_displayName.
  ///
  /// In en, this message translates to:
  /// **'Oxygen'**
  String get gas_oxygen_displayName;

  /// No description provided for @gas_scrEan40_description.
  ///
  /// In en, this message translates to:
  /// **'SCR supply gas - 40% O2'**
  String get gas_scrEan40_description;

  /// No description provided for @gas_scrEan40_displayName.
  ///
  /// In en, this message translates to:
  /// **'SCR EAN40'**
  String get gas_scrEan40_displayName;

  /// No description provided for @gas_scrEan50_description.
  ///
  /// In en, this message translates to:
  /// **'SCR supply gas - 50% O2'**
  String get gas_scrEan50_description;

  /// No description provided for @gas_scrEan50_displayName.
  ///
  /// In en, this message translates to:
  /// **'SCR EAN50'**
  String get gas_scrEan50_displayName;

  /// No description provided for @gas_scrEan60_description.
  ///
  /// In en, this message translates to:
  /// **'SCR supply gas - 60% O2'**
  String get gas_scrEan60_description;

  /// No description provided for @gas_scrEan60_displayName.
  ///
  /// In en, this message translates to:
  /// **'SCR EAN60'**
  String get gas_scrEan60_displayName;

  /// No description provided for @gas_tmx1555_description.
  ///
  /// In en, this message translates to:
  /// **'Hypoxic trimix 15/55 (very deep)'**
  String get gas_tmx1555_description;

  /// No description provided for @gas_tmx1555_displayName.
  ///
  /// In en, this message translates to:
  /// **'Tx 15/55'**
  String get gas_tmx1555_displayName;

  /// No description provided for @gas_tmx1845_description.
  ///
  /// In en, this message translates to:
  /// **'Trimix 18/45 (deep diving)'**
  String get gas_tmx1845_description;

  /// No description provided for @gas_tmx1845_displayName.
  ///
  /// In en, this message translates to:
  /// **'Tx 18/45'**
  String get gas_tmx1845_displayName;

  /// No description provided for @gas_tmx2135_description.
  ///
  /// In en, this message translates to:
  /// **'Normoxic trimix 21/35'**
  String get gas_tmx2135_description;

  /// No description provided for @gas_tmx2135_displayName.
  ///
  /// In en, this message translates to:
  /// **'Tx 21/35'**
  String get gas_tmx2135_displayName;

  /// No description provided for @gasCalculators_bestMix_bestOxygenMix.
  ///
  /// In en, this message translates to:
  /// **'Best Oxygen Mix'**
  String get gasCalculators_bestMix_bestOxygenMix;

  /// No description provided for @gasCalculators_bestMix_commonMixesRef.
  ///
  /// In en, this message translates to:
  /// **'Common Mixes Reference'**
  String get gasCalculators_bestMix_commonMixesRef;

  /// No description provided for @gasCalculators_bestMix_exceedsAirMod.
  ///
  /// In en, this message translates to:
  /// **'Air MOD exceeded at ppO₂ {ppO2}'**
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2);

  /// No description provided for @gasCalculators_bestMix_targetDepth.
  ///
  /// In en, this message translates to:
  /// **'Target Depth'**
  String get gasCalculators_bestMix_targetDepth;

  /// No description provided for @gasCalculators_bestMix_targetDive.
  ///
  /// In en, this message translates to:
  /// **'Target Dive'**
  String get gasCalculators_bestMix_targetDive;

  /// No description provided for @gasCalculators_consumption_ambientPressure.
  ///
  /// In en, this message translates to:
  /// **'Ambient pressure at {depth}{depthSymbol}'**
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  );

  /// No description provided for @gasCalculators_consumption_avgDepth.
  ///
  /// In en, this message translates to:
  /// **'Average Depth'**
  String get gasCalculators_consumption_avgDepth;

  /// No description provided for @gasCalculators_consumption_breakdown.
  ///
  /// In en, this message translates to:
  /// **'Calculation Breakdown'**
  String get gasCalculators_consumption_breakdown;

  /// No description provided for @gasCalculators_consumption_diveTime.
  ///
  /// In en, this message translates to:
  /// **'Dive Time'**
  String get gasCalculators_consumption_diveTime;

  /// No description provided for @gasCalculators_consumption_exceedsTank.
  ///
  /// In en, this message translates to:
  /// **'Exceeds tank capacity ({pressure} {symbol})'**
  String gasCalculators_consumption_exceedsTank(Object pressure, Object symbol);

  /// No description provided for @gasCalculators_consumption_gasAtDepth.
  ///
  /// In en, this message translates to:
  /// **'Gas consumption at depth'**
  String get gasCalculators_consumption_gasAtDepth;

  /// No description provided for @gasCalculators_consumption_pressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get gasCalculators_consumption_pressure;

  /// No description provided for @gasCalculators_consumption_remainingGas.
  ///
  /// In en, this message translates to:
  /// **'Remaining gas'**
  String get gasCalculators_consumption_remainingGas;

  /// No description provided for @gasCalculators_consumption_tankCapacity.
  ///
  /// In en, this message translates to:
  /// **'Tank capacity ({tankSize}{volumeSymbol} @ {fillPressure} {pressureSymbol})'**
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  );

  /// No description provided for @gasCalculators_consumption_title.
  ///
  /// In en, this message translates to:
  /// **'Gas Consumption'**
  String get gasCalculators_consumption_title;

  /// No description provided for @gasCalculators_consumption_totalGas.
  ///
  /// In en, this message translates to:
  /// **'Total gas for {time} minutes'**
  String gasCalculators_consumption_totalGas(Object time);

  /// No description provided for @gasCalculators_consumption_volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get gasCalculators_consumption_volume;

  /// No description provided for @gasCalculators_mod_aboutMod.
  ///
  /// In en, this message translates to:
  /// **'About MOD'**
  String get gasCalculators_mod_aboutMod;

  /// No description provided for @gasCalculators_mod_aboutModBody.
  ///
  /// In en, this message translates to:
  /// **'Lower O₂ = deeper MOD = shorter NDL'**
  String get gasCalculators_mod_aboutModBody;

  /// No description provided for @gasCalculators_mod_inputParameters.
  ///
  /// In en, this message translates to:
  /// **'Input Parameters'**
  String get gasCalculators_mod_inputParameters;

  /// No description provided for @gasCalculators_mod_maximumOperatingDepth.
  ///
  /// In en, this message translates to:
  /// **'Maximum Operating Depth'**
  String get gasCalculators_mod_maximumOperatingDepth;

  /// No description provided for @gasCalculators_mod_oxygenO2.
  ///
  /// In en, this message translates to:
  /// **'Oxygen (O₂)'**
  String get gasCalculators_mod_oxygenO2;

  /// No description provided for @gasCalculators_mod_ppO2Conservative.
  ///
  /// In en, this message translates to:
  /// **'Conservative limit for extended bottom time'**
  String get gasCalculators_mod_ppO2Conservative;

  /// No description provided for @gasCalculators_mod_ppO2Maximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum limit for decompression stops only'**
  String get gasCalculators_mod_ppO2Maximum;

  /// No description provided for @gasCalculators_mod_ppO2Standard.
  ///
  /// In en, this message translates to:
  /// **'Standard working limit for recreational diving'**
  String get gasCalculators_mod_ppO2Standard;

  /// No description provided for @gasCalculators_ppO2Limit.
  ///
  /// In en, this message translates to:
  /// **'ppO₂ Limit'**
  String get gasCalculators_ppO2Limit;

  /// No description provided for @gasCalculators_resetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all calculators'**
  String get gasCalculators_resetAll;

  /// No description provided for @gasCalculators_sacRate.
  ///
  /// In en, this message translates to:
  /// **'SAC Rate'**
  String get gasCalculators_sacRate;

  /// No description provided for @gasCalculators_tab_bestMix.
  ///
  /// In en, this message translates to:
  /// **'Best Mix'**
  String get gasCalculators_tab_bestMix;

  /// No description provided for @gasCalculators_tab_consumption.
  ///
  /// In en, this message translates to:
  /// **'Consumption'**
  String get gasCalculators_tab_consumption;

  /// No description provided for @gasCalculators_tab_mod.
  ///
  /// In en, this message translates to:
  /// **'MOD'**
  String get gasCalculators_tab_mod;

  /// No description provided for @gasCalculators_tab_rockBottom.
  ///
  /// In en, this message translates to:
  /// **'Rock Bottom'**
  String get gasCalculators_tab_rockBottom;

  /// No description provided for @gasCalculators_tankSize.
  ///
  /// In en, this message translates to:
  /// **'Tank Size'**
  String get gasCalculators_tankSize;

  /// No description provided for @gasCalculators_title.
  ///
  /// In en, this message translates to:
  /// **'Gas Calculators'**
  String get gasCalculators_title;

  /// No description provided for @marineLife_siteSection_editExpectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit expected species'**
  String get marineLife_siteSection_editExpectedTooltip;

  /// No description provided for @marineLife_siteSection_errorLoadingExpected.
  ///
  /// In en, this message translates to:
  /// **'Error loading expected species'**
  String get marineLife_siteSection_errorLoadingExpected;

  /// No description provided for @marineLife_siteSection_errorLoadingSightings.
  ///
  /// In en, this message translates to:
  /// **'Error loading sightings'**
  String get marineLife_siteSection_errorLoadingSightings;

  /// No description provided for @marineLife_siteSection_expectedSpecies.
  ///
  /// In en, this message translates to:
  /// **'Expected Species'**
  String get marineLife_siteSection_expectedSpecies;

  /// No description provided for @marineLife_siteSection_noExpected.
  ///
  /// In en, this message translates to:
  /// **'No expected species added'**
  String get marineLife_siteSection_noExpected;

  /// No description provided for @marineLife_siteSection_noSpotted.
  ///
  /// In en, this message translates to:
  /// **'No marine life spotted yet'**
  String get marineLife_siteSection_noSpotted;

  /// No description provided for @marineLife_siteSection_spottedCountSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, spotted {count} times'**
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  );

  /// No description provided for @marineLife_siteSection_spottedHere.
  ///
  /// In en, this message translates to:
  /// **'Spotted Here'**
  String get marineLife_siteSection_spottedHere;

  /// No description provided for @marineLife_siteSection_title.
  ///
  /// In en, this message translates to:
  /// **'Marine Life'**
  String get marineLife_siteSection_title;

  /// No description provided for @marineLife_speciesDetail_backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get marineLife_speciesDetail_backTooltip;

  /// No description provided for @marineLife_speciesDetail_depthRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Depth Range'**
  String get marineLife_speciesDetail_depthRangeTitle;

  /// No description provided for @marineLife_speciesDetail_descriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get marineLife_speciesDetail_descriptionTitle;

  /// No description provided for @marineLife_speciesDetail_divesLabel.
  ///
  /// In en, this message translates to:
  /// **'Dives'**
  String get marineLife_speciesDetail_divesLabel;

  /// No description provided for @marineLife_speciesDetail_editTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit species'**
  String get marineLife_speciesDetail_editTooltip;

  /// No description provided for @marineLife_speciesDetail_errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String marineLife_speciesDetail_errorPrefix(Object error);

  /// No description provided for @marineLife_speciesDetail_noSightings.
  ///
  /// In en, this message translates to:
  /// **'No sightings recorded yet'**
  String get marineLife_speciesDetail_noSightings;

  /// No description provided for @marineLife_speciesDetail_notFound.
  ///
  /// In en, this message translates to:
  /// **'Species not found'**
  String get marineLife_speciesDetail_notFound;

  /// No description provided for @marineLife_speciesDetail_sightingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{sighting} other{sightings}}'**
  String marineLife_speciesDetail_sightingCount(int count);

  /// No description provided for @marineLife_speciesDetail_sightingPeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'Sighting Period'**
  String get marineLife_speciesDetail_sightingPeriodTitle;

  /// No description provided for @marineLife_speciesDetail_sightingStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sighting Statistics'**
  String get marineLife_speciesDetail_sightingStatsTitle;

  /// No description provided for @marineLife_speciesDetail_sitesLabel.
  ///
  /// In en, this message translates to:
  /// **'Sites'**
  String get marineLife_speciesDetail_sitesLabel;

  /// No description provided for @marineLife_speciesDetail_taxonomyClassLabel.
  ///
  /// In en, this message translates to:
  /// **'Class: {className}'**
  String marineLife_speciesDetail_taxonomyClassLabel(Object className);

  /// No description provided for @marineLife_speciesDetail_topSitesTitle.
  ///
  /// In en, this message translates to:
  /// **'Top Sites'**
  String get marineLife_speciesDetail_topSitesTitle;

  /// No description provided for @marineLife_speciesDetail_totalSightingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Sightings'**
  String get marineLife_speciesDetail_totalSightingsLabel;

  /// No description provided for @marineLife_speciesEdit_addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Species'**
  String get marineLife_speciesEdit_addTitle;

  /// No description provided for @marineLife_speciesEdit_addedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Added \"{name}\"'**
  String marineLife_speciesEdit_addedSnackbar(Object name);

  /// No description provided for @marineLife_speciesEdit_backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get marineLife_speciesEdit_backTooltip;

  /// No description provided for @marineLife_speciesEdit_categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get marineLife_speciesEdit_categoryLabel;

  /// No description provided for @marineLife_speciesEdit_commonNameError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a common name'**
  String get marineLife_speciesEdit_commonNameError;

  /// No description provided for @marineLife_speciesEdit_commonNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Ocellaris Clownfish'**
  String get marineLife_speciesEdit_commonNameHint;

  /// No description provided for @marineLife_speciesEdit_commonNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Common Name'**
  String get marineLife_speciesEdit_commonNameLabel;

  /// No description provided for @marineLife_speciesEdit_descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Brief description of the species...'**
  String get marineLife_speciesEdit_descriptionHint;

  /// No description provided for @marineLife_speciesEdit_descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get marineLife_speciesEdit_descriptionLabel;

  /// No description provided for @marineLife_speciesEdit_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Species'**
  String get marineLife_speciesEdit_editTitle;

  /// No description provided for @marineLife_speciesEdit_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading species: {error}'**
  String marineLife_speciesEdit_errorLoading(Object error);

  /// No description provided for @marineLife_speciesEdit_errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving species: {error}'**
  String marineLife_speciesEdit_errorSaving(Object error);

  /// No description provided for @marineLife_speciesEdit_saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get marineLife_speciesEdit_saveButton;

  /// No description provided for @marineLife_speciesEdit_scientificNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Amphiprion ocellaris'**
  String get marineLife_speciesEdit_scientificNameHint;

  /// No description provided for @marineLife_speciesEdit_scientificNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Scientific Name'**
  String get marineLife_speciesEdit_scientificNameLabel;

  /// No description provided for @marineLife_speciesEdit_taxonomyClassHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Actinopterygii'**
  String get marineLife_speciesEdit_taxonomyClassHint;

  /// No description provided for @marineLife_speciesEdit_taxonomyClassLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxonomy Class'**
  String get marineLife_speciesEdit_taxonomyClassLabel;

  /// No description provided for @marineLife_speciesEdit_updatedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Updated \"{name}\"'**
  String marineLife_speciesEdit_updatedSnackbar(Object name);

  /// No description provided for @marineLife_speciesManage_allFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get marineLife_speciesManage_allFilter;

  /// No description provided for @marineLife_speciesManage_appBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get marineLife_speciesManage_appBarTitle;

  /// No description provided for @marineLife_speciesManage_backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get marineLife_speciesManage_backTooltip;

  /// No description provided for @marineLife_speciesManage_builtInSpeciesHeader.
  ///
  /// In en, this message translates to:
  /// **'Built-in Species ({count})'**
  String marineLife_speciesManage_builtInSpeciesHeader(Object count);

  /// No description provided for @marineLife_speciesManage_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get marineLife_speciesManage_cancelButton;

  /// No description provided for @marineLife_speciesManage_cannotDeleteInUse.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete \"{name}\" - it has sightings'**
  String marineLife_speciesManage_cannotDeleteInUse(Object name);

  /// No description provided for @marineLife_speciesManage_clearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get marineLife_speciesManage_clearSearchTooltip;

  /// No description provided for @marineLife_speciesManage_customSpeciesHeader.
  ///
  /// In en, this message translates to:
  /// **'Custom Species ({count})'**
  String marineLife_speciesManage_customSpeciesHeader(Object count);

  /// No description provided for @marineLife_speciesManage_deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get marineLife_speciesManage_deleteButton;

  /// No description provided for @marineLife_speciesManage_deleteDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String marineLife_speciesManage_deleteDialogContent(Object name);

  /// No description provided for @marineLife_speciesManage_deleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Species?'**
  String get marineLife_speciesManage_deleteDialogTitle;

  /// No description provided for @marineLife_speciesManage_deleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete species'**
  String get marineLife_speciesManage_deleteTooltip;

  /// No description provided for @marineLife_speciesManage_deletedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String marineLife_speciesManage_deletedSnackbar(Object name);

  /// No description provided for @marineLife_speciesManage_editTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit species'**
  String get marineLife_speciesManage_editTooltip;

  /// No description provided for @marineLife_speciesManage_errorDeleting.
  ///
  /// In en, this message translates to:
  /// **'Error deleting species: {error}'**
  String marineLife_speciesManage_errorDeleting(Object error);

  /// No description provided for @marineLife_speciesManage_errorResetting.
  ///
  /// In en, this message translates to:
  /// **'Error resetting species: {error}'**
  String marineLife_speciesManage_errorResetting(Object error);

  /// No description provided for @marineLife_speciesManage_noSpeciesFound.
  ///
  /// In en, this message translates to:
  /// **'No species found'**
  String get marineLife_speciesManage_noSpeciesFound;

  /// No description provided for @marineLife_speciesManage_resetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get marineLife_speciesManage_resetButton;

  /// No description provided for @marineLife_speciesManage_resetDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will restore all built-in species to their original values. Custom species will not be affected. Built-in species with existing sightings will be updated but preserved.'**
  String get marineLife_speciesManage_resetDialogContent;

  /// No description provided for @marineLife_speciesManage_resetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults?'**
  String get marineLife_speciesManage_resetDialogTitle;

  /// No description provided for @marineLife_speciesManage_resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Built-in species restored to defaults'**
  String get marineLife_speciesManage_resetSuccess;

  /// No description provided for @marineLife_speciesManage_resetToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults'**
  String get marineLife_speciesManage_resetToDefaults;

  /// No description provided for @marineLife_speciesManage_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search species...'**
  String get marineLife_speciesManage_searchHint;

  /// No description provided for @marineLife_speciesPicker_allFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get marineLife_speciesPicker_allFilter;

  /// No description provided for @marineLife_speciesPicker_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get marineLife_speciesPicker_cancelButton;

  /// No description provided for @marineLife_speciesPicker_clearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get marineLife_speciesPicker_clearSearchTooltip;

  /// No description provided for @marineLife_speciesPicker_closeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close species picker'**
  String get marineLife_speciesPicker_closeTooltip;

  /// No description provided for @marineLife_speciesPicker_doneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get marineLife_speciesPicker_doneButton;

  /// No description provided for @marineLife_speciesPicker_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String marineLife_speciesPicker_error(Object error);

  /// No description provided for @marineLife_speciesPicker_noSpeciesFound.
  ///
  /// In en, this message translates to:
  /// **'No species found'**
  String get marineLife_speciesPicker_noSpeciesFound;

  /// No description provided for @marineLife_speciesPicker_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search species...'**
  String get marineLife_speciesPicker_searchHint;

  /// No description provided for @marineLife_speciesPicker_selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String marineLife_speciesPicker_selectedCount(Object count);

  /// No description provided for @marineLife_speciesPicker_title.
  ///
  /// In en, this message translates to:
  /// **'Select Species'**
  String get marineLife_speciesPicker_title;

  /// No description provided for @media_diveMediaSection_addTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add photo or video'**
  String get media_diveMediaSection_addTooltip;

  /// No description provided for @media_diveMediaSection_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get media_diveMediaSection_cancelButton;

  /// No description provided for @media_diveMediaSection_emptyState.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get media_diveMediaSection_emptyState;

  /// No description provided for @media_diveMediaSection_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading media'**
  String get media_diveMediaSection_errorLoading;

  /// No description provided for @media_diveMediaSection_thumbnailLabel.
  ///
  /// In en, this message translates to:
  /// **'View photo. Long press to unlink'**
  String get media_diveMediaSection_thumbnailLabel;

  /// No description provided for @media_diveMediaSection_title.
  ///
  /// In en, this message translates to:
  /// **'Photos & Video'**
  String get media_diveMediaSection_title;

  /// No description provided for @media_diveMediaSection_unlinkButton.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get media_diveMediaSection_unlinkButton;

  /// No description provided for @media_diveMediaSection_unlinkDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Remove this photo from the dive? The photo will remain in your gallery.'**
  String get media_diveMediaSection_unlinkDialogContent;

  /// No description provided for @media_diveMediaSection_unlinkDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlink Photo'**
  String get media_diveMediaSection_unlinkDialogTitle;

  /// No description provided for @media_diveMediaSection_unlinkError.
  ///
  /// In en, this message translates to:
  /// **'Failed to unlink: {error}'**
  String media_diveMediaSection_unlinkError(Object error);

  /// No description provided for @media_diveMediaSection_unlinkSuccess.
  ///
  /// In en, this message translates to:
  /// **'Photo unlinked'**
  String get media_diveMediaSection_unlinkSuccess;

  /// No description provided for @media_gpsBanner_addToSiteButton.
  ///
  /// In en, this message translates to:
  /// **'Add to Site'**
  String get media_gpsBanner_addToSiteButton;

  /// No description provided for @media_gpsBanner_coordinates.
  ///
  /// In en, this message translates to:
  /// **'Coordinates: {latitude}, {longitude}'**
  String media_gpsBanner_coordinates(Object latitude, Object longitude);

  /// No description provided for @media_gpsBanner_createSiteButton.
  ///
  /// In en, this message translates to:
  /// **'Create Site'**
  String get media_gpsBanner_createSiteButton;

  /// No description provided for @media_gpsBanner_dismissTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss GPS suggestion'**
  String get media_gpsBanner_dismissTooltip;

  /// No description provided for @media_gpsBanner_title.
  ///
  /// In en, this message translates to:
  /// **'GPS found in photos'**
  String get media_gpsBanner_title;

  /// No description provided for @media_import_failedToImport.
  ///
  /// In en, this message translates to:
  /// **'Failed to import {count, plural, =1{photo} other{photos}}'**
  String media_import_failedToImport(int count);

  /// No description provided for @media_import_failedToImportError.
  ///
  /// In en, this message translates to:
  /// **'Failed to import photos: {error}'**
  String media_import_failedToImportError(Object error);

  /// No description provided for @media_import_importedAndFailed.
  ///
  /// In en, this message translates to:
  /// **'Imported {imported}, failed {failed}'**
  String media_import_importedAndFailed(Object imported, Object failed);

  /// No description provided for @media_import_importedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} {count, plural, =1{photo} other{photos}}'**
  String media_import_importedPhotos(int count);

  /// No description provided for @media_import_importingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Importing {count} {count, plural, =1{photo} other{photos}}...'**
  String media_import_importingPhotos(int count);

  /// No description provided for @media_miniProfile_headerLabel.
  ///
  /// In en, this message translates to:
  /// **'Dive Profile'**
  String get media_miniProfile_headerLabel;

  /// No description provided for @media_miniProfile_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Mini dive profile chart'**
  String get media_miniProfile_semanticLabel;

  /// No description provided for @media_photoPicker_appBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Photos'**
  String get media_photoPicker_appBarTitle;

  /// No description provided for @media_photoPicker_closeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close photo picker'**
  String get media_photoPicker_closeTooltip;

  /// No description provided for @media_photoPicker_doneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get media_photoPicker_doneButton;

  /// No description provided for @media_photoPicker_doneCountButton.
  ///
  /// In en, this message translates to:
  /// **'Done ({count})'**
  String media_photoPicker_doneCountButton(Object count);

  /// No description provided for @media_photoPicker_emptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No photos were found between {startDate} {startTime} and {endDate} {endTime}.'**
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  );

  /// No description provided for @media_photoPicker_emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No photos found'**
  String get media_photoPicker_emptyTitle;

  /// No description provided for @media_photoPicker_grantAccessButton.
  ///
  /// In en, this message translates to:
  /// **'Grant Access'**
  String get media_photoPicker_grantAccessButton;

  /// No description provided for @media_photoPicker_openSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get media_photoPicker_openSettingsButton;

  /// No description provided for @media_photoPicker_openSettingsSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Please open Settings and enable photo access'**
  String get media_photoPicker_openSettingsSnackbar;

  /// No description provided for @media_photoPicker_permissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Photo library access was denied. Please enable it in Settings to add dive photos.'**
  String get media_photoPicker_permissionDeniedMessage;

  /// No description provided for @media_photoPicker_permissionRequestMessage.
  ///
  /// In en, this message translates to:
  /// **'Submersion needs access to your photo library to add dive photos.'**
  String get media_photoPicker_permissionRequestMessage;

  /// No description provided for @media_photoPicker_permissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo Access Required'**
  String get media_photoPicker_permissionTitle;

  /// No description provided for @media_photoPicker_showingPhotosFromRange.
  ///
  /// In en, this message translates to:
  /// **'Showing photos from {rangeText}'**
  String media_photoPicker_showingPhotosFromRange(Object rangeText);

  /// No description provided for @media_photoPicker_thumbnailToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Toggle selection for photo'**
  String get media_photoPicker_thumbnailToggleLabel;

  /// No description provided for @media_photoPicker_thumbnailToggleSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Toggle selection for photo, selected'**
  String get media_photoPicker_thumbnailToggleSelectedLabel;

  /// No description provided for @media_photoViewer_cannotShare.
  ///
  /// In en, this message translates to:
  /// **'Cannot share this photo'**
  String get media_photoViewer_cannotShare;

  /// No description provided for @media_photoViewer_cannotWriteMetadata.
  ///
  /// In en, this message translates to:
  /// **'Cannot write metadata - media not linked to library'**
  String get media_photoViewer_cannotWriteMetadata;

  /// No description provided for @media_photoViewer_closeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close photo viewer'**
  String get media_photoViewer_closeTooltip;

  /// No description provided for @media_photoViewer_diveDataWrittenToPhoto.
  ///
  /// In en, this message translates to:
  /// **'Dive data written to photo'**
  String get media_photoViewer_diveDataWrittenToPhoto;

  /// No description provided for @media_photoViewer_diveDataWrittenToVideo.
  ///
  /// In en, this message translates to:
  /// **'Dive data written to video'**
  String get media_photoViewer_diveDataWrittenToVideo;

  /// No description provided for @media_photoViewer_errorLoadingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Error loading photos: {error}'**
  String media_photoViewer_errorLoadingPhotos(Object error);

  /// No description provided for @media_photoViewer_failedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get media_photoViewer_failedToLoadImage;

  /// No description provided for @media_photoViewer_failedToLoadVideo.
  ///
  /// In en, this message translates to:
  /// **'Failed to load video'**
  String get media_photoViewer_failedToLoadVideo;

  /// No description provided for @media_photoViewer_failedToShare.
  ///
  /// In en, this message translates to:
  /// **'Failed to share: {error}'**
  String media_photoViewer_failedToShare(Object error);

  /// No description provided for @media_photoViewer_failedToWriteMetadata.
  ///
  /// In en, this message translates to:
  /// **'Failed to write metadata'**
  String get media_photoViewer_failedToWriteMetadata;

  /// No description provided for @media_photoViewer_failedToWriteMetadataError.
  ///
  /// In en, this message translates to:
  /// **'Failed to write metadata: {error}'**
  String media_photoViewer_failedToWriteMetadataError(Object error);

  /// No description provided for @media_photoViewer_noPhotosAvailable.
  ///
  /// In en, this message translates to:
  /// **'No photos available'**
  String get media_photoViewer_noPhotosAvailable;

  /// No description provided for @media_photoViewer_pageIndicator.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String media_photoViewer_pageIndicator(Object current, Object total);

  /// No description provided for @media_photoViewer_playPauseVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Play or pause video'**
  String get media_photoViewer_playPauseVideoLabel;

  /// No description provided for @media_photoViewer_seekVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Seek video position'**
  String get media_photoViewer_seekVideoLabel;

  /// No description provided for @media_photoViewer_shareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share photo'**
  String get media_photoViewer_shareTooltip;

  /// No description provided for @media_photoViewer_toggleOverlayLabel.
  ///
  /// In en, this message translates to:
  /// **'Toggle photo overlay'**
  String get media_photoViewer_toggleOverlayLabel;

  /// No description provided for @media_photoViewer_videoFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Video file not found'**
  String get media_photoViewer_videoFileNotFound;

  /// No description provided for @media_photoViewer_videoNotLinked.
  ///
  /// In en, this message translates to:
  /// **'Video not linked to library'**
  String get media_photoViewer_videoNotLinked;

  /// No description provided for @media_photoViewer_writeDiveDataTooltip.
  ///
  /// In en, this message translates to:
  /// **'Write dive data to photo'**
  String get media_photoViewer_writeDiveDataTooltip;

  /// No description provided for @media_quickSiteDialog_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get media_quickSiteDialog_cancelButton;

  /// No description provided for @media_quickSiteDialog_createButton.
  ///
  /// In en, this message translates to:
  /// **'Create Site'**
  String get media_quickSiteDialog_createButton;

  /// No description provided for @media_quickSiteDialog_description.
  ///
  /// In en, this message translates to:
  /// **'Create a new dive site using GPS coordinates from your photo.'**
  String get media_quickSiteDialog_description;

  /// No description provided for @media_quickSiteDialog_siteNameError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a site name'**
  String get media_quickSiteDialog_siteNameError;

  /// No description provided for @media_quickSiteDialog_siteNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this site'**
  String get media_quickSiteDialog_siteNameHint;

  /// No description provided for @media_quickSiteDialog_siteNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Site Name'**
  String get media_quickSiteDialog_siteNameLabel;

  /// No description provided for @media_quickSiteDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Create Dive Site'**
  String get media_quickSiteDialog_title;

  /// No description provided for @media_scanResults_allPhotosLinked.
  ///
  /// In en, this message translates to:
  /// **'All photos already linked'**
  String get media_scanResults_allPhotosLinked;

  /// No description provided for @media_scanResults_allPhotosLinkedDescription.
  ///
  /// In en, this message translates to:
  /// **'All {count} photos from this trip are already linked to dives.'**
  String media_scanResults_allPhotosLinkedDescription(Object count);

  /// No description provided for @media_scanResults_alreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'{count} photos already linked'**
  String media_scanResults_alreadyLinked(Object count);

  /// No description provided for @media_scanResults_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get media_scanResults_cancelButton;

  /// No description provided for @media_scanResults_diveNumber.
  ///
  /// In en, this message translates to:
  /// **'Dive #{number}'**
  String media_scanResults_diveNumber(Object number);

  /// No description provided for @media_scanResults_foundNewPhotos.
  ///
  /// In en, this message translates to:
  /// **'Found {count} new photos'**
  String media_scanResults_foundNewPhotos(Object count);

  /// No description provided for @media_scanResults_linkButton.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get media_scanResults_linkButton;

  /// No description provided for @media_scanResults_linkCountButton.
  ///
  /// In en, this message translates to:
  /// **'Link {count} photos'**
  String media_scanResults_linkCountButton(Object count);

  /// No description provided for @media_scanResults_noPhotosFound.
  ///
  /// In en, this message translates to:
  /// **'No photos found'**
  String get media_scanResults_noPhotosFound;

  /// No description provided for @media_scanResults_okButton.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get media_scanResults_okButton;

  /// No description provided for @media_scanResults_unknownSite.
  ///
  /// In en, this message translates to:
  /// **'Unknown site'**
  String get media_scanResults_unknownSite;

  /// No description provided for @media_scanResults_unmatchedWarning.
  ///
  /// In en, this message translates to:
  /// **'{count} photos could not be matched to any dive (taken outside dive times)'**
  String media_scanResults_unmatchedWarning(Object count);

  /// No description provided for @media_writeMetadata_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get media_writeMetadata_cancelButton;

  /// No description provided for @media_writeMetadata_depthLabel.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get media_writeMetadata_depthLabel;

  /// No description provided for @media_writeMetadata_descriptionPhoto.
  ///
  /// In en, this message translates to:
  /// **'The following metadata will be written to the photo:'**
  String get media_writeMetadata_descriptionPhoto;

  /// No description provided for @media_writeMetadata_descriptionVideo.
  ///
  /// In en, this message translates to:
  /// **'The following metadata will be written to the video:'**
  String get media_writeMetadata_descriptionVideo;

  /// No description provided for @media_writeMetadata_diveTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Dive time'**
  String get media_writeMetadata_diveTimeLabel;

  /// No description provided for @media_writeMetadata_gpsLabel.
  ///
  /// In en, this message translates to:
  /// **'GPS'**
  String get media_writeMetadata_gpsLabel;

  /// No description provided for @media_writeMetadata_keepOriginalVideo.
  ///
  /// In en, this message translates to:
  /// **'Keep original video'**
  String get media_writeMetadata_keepOriginalVideo;

  /// No description provided for @media_writeMetadata_noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No dive data available to write.'**
  String get media_writeMetadata_noDataAvailable;

  /// No description provided for @media_writeMetadata_siteLabel.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get media_writeMetadata_siteLabel;

  /// No description provided for @media_writeMetadata_temperatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get media_writeMetadata_temperatureLabel;

  /// No description provided for @media_writeMetadata_titlePhoto.
  ///
  /// In en, this message translates to:
  /// **'Write Dive Data to Photo'**
  String get media_writeMetadata_titlePhoto;

  /// No description provided for @media_writeMetadata_titleVideo.
  ///
  /// In en, this message translates to:
  /// **'Write Dive Data to Video'**
  String get media_writeMetadata_titleVideo;

  /// No description provided for @media_writeMetadata_warningPhotoText.
  ///
  /// In en, this message translates to:
  /// **'This will modify the original photo.'**
  String get media_writeMetadata_warningPhotoText;

  /// No description provided for @media_writeMetadata_warningVideoText.
  ///
  /// In en, this message translates to:
  /// **'A new video will be created with the metadata. Video metadata cannot be modified in-place.'**
  String get media_writeMetadata_warningVideoText;

  /// No description provided for @media_writeMetadata_writeButton.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get media_writeMetadata_writeButton;

  /// Navigation label for buddies section
  ///
  /// In en, this message translates to:
  /// **'Buddies'**
  String get nav_buddies;

  /// Navigation label for certifications section
  ///
  /// In en, this message translates to:
  /// **'Certifications'**
  String get nav_certifications;

  /// Navigation label for courses section
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get nav_courses;

  /// Subtitle for courses menu item
  ///
  /// In en, this message translates to:
  /// **'Training & Education'**
  String get nav_coursesSubtitle;

  /// Navigation label for dive centers section
  ///
  /// In en, this message translates to:
  /// **'Dive Centers'**
  String get nav_diveCenters;

  /// Navigation label for dives section
  ///
  /// In en, this message translates to:
  /// **'Dives'**
  String get nav_dives;

  /// Navigation label for equipment section
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get nav_equipment;

  /// Navigation label for home/dashboard
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get nav_home;

  /// Navigation label for the 'more' menu on mobile
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get nav_more;

  /// Navigation label for dive planning section
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get nav_planning;

  /// Subtitle for planning menu item
  ///
  /// In en, this message translates to:
  /// **'Dive Planner, Calculators'**
  String get nav_planningSubtitle;

  /// Navigation label for settings section
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get nav_settings;

  /// Navigation label for dive sites section
  ///
  /// In en, this message translates to:
  /// **'Sites'**
  String get nav_sites;

  /// Navigation label for statistics section
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get nav_statistics;

  /// Tooltip for the close button on the more menu
  ///
  /// In en, this message translates to:
  /// **'Close menu'**
  String get nav_tooltip_closeMenu;

  /// Tooltip for the collapse navigation rail button
  ///
  /// In en, this message translates to:
  /// **'Collapse menu'**
  String get nav_tooltip_collapseMenu;

  /// Tooltip for the expand navigation rail button
  ///
  /// In en, this message translates to:
  /// **'Expand menu'**
  String get nav_tooltip_expandMenu;

  /// Navigation label for data transfer section
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get nav_transfer;

  /// Navigation label for trips section
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get nav_trips;

  /// No description provided for @onboarding_welcome_createProfile.
  ///
  /// In en, this message translates to:
  /// **'Create Your Profile'**
  String get onboarding_welcome_createProfile;

  /// No description provided for @onboarding_welcome_createProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your name to get started. You can add more details later.'**
  String get onboarding_welcome_createProfileSubtitle;

  /// No description provided for @onboarding_welcome_creating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get onboarding_welcome_creating;

  /// No description provided for @onboarding_welcome_errorCreatingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error creating profile: {error}'**
  String onboarding_welcome_errorCreatingProfile(Object error);

  /// No description provided for @onboarding_welcome_getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboarding_welcome_getStarted;

  /// No description provided for @onboarding_welcome_nameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get onboarding_welcome_nameHint;

  /// No description provided for @onboarding_welcome_nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get onboarding_welcome_nameLabel;

  /// No description provided for @onboarding_welcome_nameValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get onboarding_welcome_nameValidation;

  /// No description provided for @onboarding_welcome_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced dive logging and analysis'**
  String get onboarding_welcome_subtitle;

  /// No description provided for @onboarding_welcome_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Submersion'**
  String get onboarding_welcome_title;

  /// No description provided for @planning_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get planning_appBar_title;

  /// No description provided for @planning_card_decoCalculator_description.
  ///
  /// In en, this message translates to:
  /// **'Calculate no-decompression limits, required deco stops, and CNS/OTU exposure for multi-level dive profiles.'**
  String get planning_card_decoCalculator_description;

  /// No description provided for @planning_card_decoCalculator_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Plan dives with decompression stops'**
  String get planning_card_decoCalculator_subtitle;

  /// No description provided for @planning_card_decoCalculator_title.
  ///
  /// In en, this message translates to:
  /// **'Deco Calculator'**
  String get planning_card_decoCalculator_title;

  /// No description provided for @planning_card_divePlanner_description.
  ///
  /// In en, this message translates to:
  /// **'Plan complex dives with multiple depth levels, gas switches, and automatic decompression stop calculations.'**
  String get planning_card_divePlanner_description;

  /// No description provided for @planning_card_divePlanner_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create multi-level dive plans'**
  String get planning_card_divePlanner_subtitle;

  /// No description provided for @planning_card_divePlanner_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Planner'**
  String get planning_card_divePlanner_title;

  /// No description provided for @planning_card_gasCalculators_description.
  ///
  /// In en, this message translates to:
  /// **'Four specialized gas calculators: • MOD - Maximum operating depth for a gas mix • Best Mix - Ideal O₂% for a target depth • Consumption - Gas usage estimation • Rock Bottom - Emergency reserve calculation'**
  String get planning_card_gasCalculators_description;

  /// No description provided for @planning_card_gasCalculators_subtitle.
  ///
  /// In en, this message translates to:
  /// **'MOD, Best Mix, Consumption, Rock Bottom'**
  String get planning_card_gasCalculators_subtitle;

  /// No description provided for @planning_card_gasCalculators_title.
  ///
  /// In en, this message translates to:
  /// **'Gas Calculators'**
  String get planning_card_gasCalculators_title;

  /// No description provided for @planning_card_surfaceInterval_description.
  ///
  /// In en, this message translates to:
  /// **'Calculate the minimum surface interval needed between dives based on tissue loading. Visualize how your 16 tissue compartments off-gas over time.'**
  String get planning_card_surfaceInterval_description;

  /// No description provided for @planning_card_surfaceInterval_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Plan repetitive dive intervals'**
  String get planning_card_surfaceInterval_subtitle;

  /// No description provided for @planning_card_surfaceInterval_title.
  ///
  /// In en, this message translates to:
  /// **'Surface Interval'**
  String get planning_card_surfaceInterval_title;

  /// No description provided for @planning_card_weightCalculator_description.
  ///
  /// In en, this message translates to:
  /// **'Estimate the weight you need based on your exposure suit, tank material, water type, and body weight.'**
  String get planning_card_weightCalculator_description;

  /// No description provided for @planning_card_weightCalculator_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended weight for your setup'**
  String get planning_card_weightCalculator_subtitle;

  /// No description provided for @planning_card_weightCalculator_title.
  ///
  /// In en, this message translates to:
  /// **'Weight Calculator'**
  String get planning_card_weightCalculator_title;

  /// No description provided for @planning_info_disclaimer.
  ///
  /// In en, this message translates to:
  /// **'These tools are for planning purposes only. Always verify calculations and follow your dive training.'**
  String get planning_info_disclaimer;

  /// No description provided for @planning_sidebar_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get planning_sidebar_appBar_title;

  /// No description provided for @planning_sidebar_decoCalculator_subtitle.
  ///
  /// In en, this message translates to:
  /// **'NDL & deco stops'**
  String get planning_sidebar_decoCalculator_subtitle;

  /// No description provided for @planning_sidebar_decoCalculator_title.
  ///
  /// In en, this message translates to:
  /// **'Deco Calculator'**
  String get planning_sidebar_decoCalculator_title;

  /// No description provided for @planning_sidebar_divePlanner_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-level dive plans'**
  String get planning_sidebar_divePlanner_subtitle;

  /// No description provided for @planning_sidebar_divePlanner_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Planner'**
  String get planning_sidebar_divePlanner_title;

  /// No description provided for @planning_sidebar_gasCalculators_subtitle.
  ///
  /// In en, this message translates to:
  /// **'MOD, Best Mix, more'**
  String get planning_sidebar_gasCalculators_subtitle;

  /// No description provided for @planning_sidebar_gasCalculators_title.
  ///
  /// In en, this message translates to:
  /// **'Gas Calculators'**
  String get planning_sidebar_gasCalculators_title;

  /// No description provided for @planning_sidebar_info_disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Planning tools are for reference only. Always verify calculations.'**
  String get planning_sidebar_info_disclaimer;

  /// No description provided for @planning_sidebar_surfaceInterval_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Repetitive dive planning'**
  String get planning_sidebar_surfaceInterval_subtitle;

  /// No description provided for @planning_sidebar_surfaceInterval_title.
  ///
  /// In en, this message translates to:
  /// **'Surface Interval'**
  String get planning_sidebar_surfaceInterval_title;

  /// No description provided for @planning_sidebar_weightCalculator_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended weight'**
  String get planning_sidebar_weightCalculator_subtitle;

  /// No description provided for @planning_sidebar_weightCalculator_title.
  ///
  /// In en, this message translates to:
  /// **'Weight Calculator'**
  String get planning_sidebar_weightCalculator_title;

  /// No description provided for @planning_welcome_quickTips_title.
  ///
  /// In en, this message translates to:
  /// **'Quick Tips'**
  String get planning_welcome_quickTips_title;

  /// No description provided for @planning_welcome_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a tool from the sidebar to get started'**
  String get planning_welcome_subtitle;

  /// No description provided for @planning_welcome_tip_decoCalculator.
  ///
  /// In en, this message translates to:
  /// **'Deco Calculator for NDL and stop times'**
  String get planning_welcome_tip_decoCalculator;

  /// No description provided for @planning_welcome_tip_divePlanner.
  ///
  /// In en, this message translates to:
  /// **'Dive Planner for multi-level dive planning'**
  String get planning_welcome_tip_divePlanner;

  /// No description provided for @planning_welcome_tip_gasCalculators.
  ///
  /// In en, this message translates to:
  /// **'Gas Calculators for MOD and gas planning'**
  String get planning_welcome_tip_gasCalculators;

  /// No description provided for @planning_welcome_tip_weightCalculator.
  ///
  /// In en, this message translates to:
  /// **'Weight Calculator for buoyancy setup'**
  String get planning_welcome_tip_weightCalculator;

  /// No description provided for @planning_welcome_title.
  ///
  /// In en, this message translates to:
  /// **'Planning Tools'**
  String get planning_welcome_title;

  /// No description provided for @settings_about_aboutSubmersion.
  ///
  /// In en, this message translates to:
  /// **'About Submersion'**
  String get settings_about_aboutSubmersion;

  /// No description provided for @settings_about_appName.
  ///
  /// In en, this message translates to:
  /// **'Submersion'**
  String get settings_about_appName;

  /// No description provided for @settings_about_description.
  ///
  /// In en, this message translates to:
  /// **'Track your dives, manage gear, and explore dive sites.'**
  String get settings_about_description;

  /// No description provided for @settings_about_header.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settings_about_header;

  /// No description provided for @settings_about_openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get settings_about_openSourceLicenses;

  /// No description provided for @settings_about_reportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an Issue'**
  String get settings_about_reportIssue;

  /// No description provided for @settings_about_reportIssue_snackbar.
  ///
  /// In en, this message translates to:
  /// **'Visit github.com/submersion/submersion'**
  String get settings_about_reportIssue_snackbar;

  /// No description provided for @settings_about_version.
  ///
  /// In en, this message translates to:
  /// **'Version 0.1.0'**
  String get settings_about_version;

  /// No description provided for @settings_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_appBar_title;

  /// No description provided for @settings_appearance_appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settings_appearance_appLanguage;

  /// No description provided for @settings_appearance_depthColoredCards.
  ///
  /// In en, this message translates to:
  /// **'Depth-colored dive cards'**
  String get settings_appearance_depthColoredCards;

  /// No description provided for @settings_appearance_depthColoredCards_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Show dive cards with ocean-colored backgrounds based on depth'**
  String get settings_appearance_depthColoredCards_subtitle;

  /// No description provided for @settings_appearance_gasSwitchMarkers.
  ///
  /// In en, this message translates to:
  /// **'Gas switch markers'**
  String get settings_appearance_gasSwitchMarkers;

  /// No description provided for @settings_appearance_gasSwitchMarkers_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Show markers for gas switches'**
  String get settings_appearance_gasSwitchMarkers_subtitle;

  /// No description provided for @settings_appearance_header_diveLog.
  ///
  /// In en, this message translates to:
  /// **'Dive Log'**
  String get settings_appearance_header_diveLog;

  /// No description provided for @settings_appearance_header_diveProfile.
  ///
  /// In en, this message translates to:
  /// **'Dive Profile'**
  String get settings_appearance_header_diveProfile;

  /// No description provided for @settings_appearance_header_diveSites.
  ///
  /// In en, this message translates to:
  /// **'Dive Sites'**
  String get settings_appearance_header_diveSites;

  /// No description provided for @settings_appearance_header_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_appearance_header_language;

  /// No description provided for @settings_appearance_header_theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settings_appearance_header_theme;

  /// No description provided for @settings_appearance_mapBackgroundDiveCards.
  ///
  /// In en, this message translates to:
  /// **'Map background on dive cards'**
  String get settings_appearance_mapBackgroundDiveCards;

  /// No description provided for @settings_appearance_mapBackgroundDiveCards_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Show dive site map as background on dive cards'**
  String get settings_appearance_mapBackgroundDiveCards_subtitle;

  /// No description provided for @settings_appearance_mapBackgroundDiveCards_subtitleWithNote.
  ///
  /// In en, this message translates to:
  /// **'Show dive site map as background on dive cards (requires site location)'**
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote;

  /// No description provided for @settings_appearance_mapBackgroundSiteCards.
  ///
  /// In en, this message translates to:
  /// **'Map background on site cards'**
  String get settings_appearance_mapBackgroundSiteCards;

  /// No description provided for @settings_appearance_mapBackgroundSiteCards_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Show map as background on dive site cards'**
  String get settings_appearance_mapBackgroundSiteCards_subtitle;

  /// No description provided for @settings_appearance_mapBackgroundSiteCards_subtitleWithNote.
  ///
  /// In en, this message translates to:
  /// **'Show map as background on dive site cards (requires site location)'**
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote;

  /// No description provided for @settings_appearance_maxDepthMarker.
  ///
  /// In en, this message translates to:
  /// **'Max depth marker'**
  String get settings_appearance_maxDepthMarker;

  /// No description provided for @settings_appearance_maxDepthMarker_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Show a marker at the maximum depth point'**
  String get settings_appearance_maxDepthMarker_subtitle;

  /// No description provided for @settings_appearance_maxDepthMarker_subtitleFull.
  ///
  /// In en, this message translates to:
  /// **'Show a marker at the maximum depth point on dive profiles'**
  String get settings_appearance_maxDepthMarker_subtitleFull;

  /// No description provided for @settings_appearance_metric_ascentRateColors.
  ///
  /// In en, this message translates to:
  /// **'Ascent Rate Colors'**
  String get settings_appearance_metric_ascentRateColors;

  /// No description provided for @settings_appearance_metric_ceiling.
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get settings_appearance_metric_ceiling;

  /// No description provided for @settings_appearance_metric_events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get settings_appearance_metric_events;

  /// No description provided for @settings_appearance_metric_gasDensity.
  ///
  /// In en, this message translates to:
  /// **'Gas Density'**
  String get settings_appearance_metric_gasDensity;

  /// No description provided for @settings_appearance_metric_gfPercent.
  ///
  /// In en, this message translates to:
  /// **'GF%'**
  String get settings_appearance_metric_gfPercent;

  /// No description provided for @settings_appearance_metric_heartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get settings_appearance_metric_heartRate;

  /// No description provided for @settings_appearance_metric_meanDepth.
  ///
  /// In en, this message translates to:
  /// **'Mean Depth'**
  String get settings_appearance_metric_meanDepth;

  /// No description provided for @settings_appearance_metric_ndl.
  ///
  /// In en, this message translates to:
  /// **'NDL'**
  String get settings_appearance_metric_ndl;

  /// No description provided for @settings_appearance_metric_ppHe.
  ///
  /// In en, this message translates to:
  /// **'ppHe'**
  String get settings_appearance_metric_ppHe;

  /// No description provided for @settings_appearance_metric_ppN2.
  ///
  /// In en, this message translates to:
  /// **'ppN2'**
  String get settings_appearance_metric_ppN2;

  /// No description provided for @settings_appearance_metric_ppO2.
  ///
  /// In en, this message translates to:
  /// **'ppO2'**
  String get settings_appearance_metric_ppO2;

  /// No description provided for @settings_appearance_metric_pressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get settings_appearance_metric_pressure;

  /// No description provided for @settings_appearance_metric_sacRate.
  ///
  /// In en, this message translates to:
  /// **'SAC Rate'**
  String get settings_appearance_metric_sacRate;

  /// No description provided for @settings_appearance_metric_surfaceGf.
  ///
  /// In en, this message translates to:
  /// **'Surface GF'**
  String get settings_appearance_metric_surfaceGf;

  /// No description provided for @settings_appearance_metric_temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get settings_appearance_metric_temperature;

  /// No description provided for @settings_appearance_metric_tts.
  ///
  /// In en, this message translates to:
  /// **'TTS (Time to Surface)'**
  String get settings_appearance_metric_tts;

  /// No description provided for @settings_appearance_pressureThresholdMarkers.
  ///
  /// In en, this message translates to:
  /// **'Pressure threshold markers'**
  String get settings_appearance_pressureThresholdMarkers;

  /// No description provided for @settings_appearance_pressureThresholdMarkers_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Show markers when tank pressure crosses thresholds'**
  String get settings_appearance_pressureThresholdMarkers_subtitle;

  /// No description provided for @settings_appearance_pressureThresholdMarkers_subtitleFull.
  ///
  /// In en, this message translates to:
  /// **'Show markers when tank pressure crosses 2/3, 1/2, and 1/3 thresholds'**
  String get settings_appearance_pressureThresholdMarkers_subtitleFull;

  /// No description provided for @settings_appearance_rightYAxisMetric.
  ///
  /// In en, this message translates to:
  /// **'Right Y-axis metric'**
  String get settings_appearance_rightYAxisMetric;

  /// No description provided for @settings_appearance_rightYAxisMetric_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Default metric shown on right axis'**
  String get settings_appearance_rightYAxisMetric_subtitle;

  /// No description provided for @settings_appearance_subsection_decompressionMetrics.
  ///
  /// In en, this message translates to:
  /// **'Decompression Metrics'**
  String get settings_appearance_subsection_decompressionMetrics;

  /// No description provided for @settings_appearance_subsection_defaultVisibleMetrics.
  ///
  /// In en, this message translates to:
  /// **'Default Visible Metrics'**
  String get settings_appearance_subsection_defaultVisibleMetrics;

  /// No description provided for @settings_appearance_subsection_gasAnalysisMetrics.
  ///
  /// In en, this message translates to:
  /// **'Gas Analysis Metrics'**
  String get settings_appearance_subsection_gasAnalysisMetrics;

  /// No description provided for @settings_appearance_subsection_gradientFactorMetrics.
  ///
  /// In en, this message translates to:
  /// **'Gradient Factor Metrics'**
  String get settings_appearance_subsection_gradientFactorMetrics;

  /// No description provided for @settings_appearance_theme_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settings_appearance_theme_dark;

  /// No description provided for @settings_appearance_theme_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settings_appearance_theme_light;

  /// No description provided for @settings_appearance_theme_system.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settings_appearance_theme_system;

  /// No description provided for @settings_backToSettings_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Back to settings'**
  String get settings_backToSettings_tooltip;

  /// No description provided for @settings_cloudSync_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get settings_cloudSync_appBar_title;

  /// No description provided for @settings_cloudSync_autoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto Sync'**
  String get settings_cloudSync_autoSync;

  /// No description provided for @settings_cloudSync_autoSync_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync automatically after changes'**
  String get settings_cloudSync_autoSync_subtitle;

  /// No description provided for @settings_cloudSync_conflictItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item needs attention} other{{count} items need attention}}'**
  String settings_cloudSync_conflictItems(int count);

  /// No description provided for @settings_cloudSync_disabledBanner_content.
  ///
  /// In en, this message translates to:
  /// **'App-managed cloud sync is disabled because you\'re using a custom storage folder. Your folder\'s sync service (Dropbox, Google Drive, OneDrive, etc.) handles synchronization.'**
  String get settings_cloudSync_disabledBanner_content;

  /// No description provided for @settings_cloudSync_disabledBanner_title.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync Disabled'**
  String get settings_cloudSync_disabledBanner_title;

  /// No description provided for @settings_cloudSync_header_advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settings_cloudSync_header_advanced;

  /// No description provided for @settings_cloudSync_header_cloudProvider.
  ///
  /// In en, this message translates to:
  /// **'Cloud Provider'**
  String get settings_cloudSync_header_cloudProvider;

  /// No description provided for @settings_cloudSync_header_conflicts.
  ///
  /// In en, this message translates to:
  /// **'Conflicts ({count})'**
  String settings_cloudSync_header_conflicts(Object count);

  /// No description provided for @settings_cloudSync_header_syncBehavior.
  ///
  /// In en, this message translates to:
  /// **'Sync Behavior'**
  String get settings_cloudSync_header_syncBehavior;

  /// No description provided for @settings_cloudSync_lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {time}'**
  String settings_cloudSync_lastSynced(Object time);

  /// No description provided for @settings_cloudSync_pendingChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pending change} other{{count} pending changes}}'**
  String settings_cloudSync_pendingChanges(int count);

  /// No description provided for @settings_cloudSync_provider_connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settings_cloudSync_provider_connected;

  /// No description provided for @settings_cloudSync_provider_connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to {providerName}'**
  String settings_cloudSync_provider_connectedTo(Object providerName);

  /// No description provided for @settings_cloudSync_provider_connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'{providerName} connection failed: {error}'**
  String settings_cloudSync_provider_connectionFailed(
    Object providerName,
    Object error,
  );

  /// No description provided for @settings_cloudSync_provider_googleDrive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get settings_cloudSync_provider_googleDrive;

  /// No description provided for @settings_cloudSync_provider_googleDrive_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync via Google Drive'**
  String get settings_cloudSync_provider_googleDrive_subtitle;

  /// No description provided for @settings_cloudSync_provider_icloud.
  ///
  /// In en, this message translates to:
  /// **'iCloud'**
  String get settings_cloudSync_provider_icloud;

  /// No description provided for @settings_cloudSync_provider_icloud_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync via Apple iCloud'**
  String get settings_cloudSync_provider_icloud_subtitle;

  /// No description provided for @settings_cloudSync_provider_initFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize {providerName} provider'**
  String settings_cloudSync_provider_initFailed(Object providerName);

  /// No description provided for @settings_cloudSync_provider_notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this platform'**
  String get settings_cloudSync_provider_notAvailable;

  /// No description provided for @settings_cloudSync_resetDialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settings_cloudSync_resetDialog_cancel;

  /// No description provided for @settings_cloudSync_resetDialog_content.
  ///
  /// In en, this message translates to:
  /// **'This will clear all sync history and start fresh. Your data will not be deleted, but you may need to resolve conflicts on the next sync.'**
  String get settings_cloudSync_resetDialog_content;

  /// No description provided for @settings_cloudSync_resetDialog_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settings_cloudSync_resetDialog_reset;

  /// No description provided for @settings_cloudSync_resetDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Reset Sync State?'**
  String get settings_cloudSync_resetDialog_title;

  /// No description provided for @settings_cloudSync_resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sync state reset'**
  String get settings_cloudSync_resetSuccess;

  /// No description provided for @settings_cloudSync_resetSyncState.
  ///
  /// In en, this message translates to:
  /// **'Reset Sync State'**
  String get settings_cloudSync_resetSyncState;

  /// No description provided for @settings_cloudSync_resetSyncState_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear sync history and start fresh'**
  String get settings_cloudSync_resetSyncState_subtitle;

  /// No description provided for @settings_cloudSync_resolveConflicts.
  ///
  /// In en, this message translates to:
  /// **'Resolve Conflicts'**
  String get settings_cloudSync_resolveConflicts;

  /// No description provided for @settings_cloudSync_selectProviderHint.
  ///
  /// In en, this message translates to:
  /// **'Select a cloud provider to enable sync'**
  String get settings_cloudSync_selectProviderHint;

  /// No description provided for @settings_cloudSync_signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settings_cloudSync_signOut;

  /// No description provided for @settings_cloudSync_signOutDialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settings_cloudSync_signOutDialog_cancel;

  /// No description provided for @settings_cloudSync_signOutDialog_content.
  ///
  /// In en, this message translates to:
  /// **'This will disconnect from the cloud provider. Your local data will remain intact.'**
  String get settings_cloudSync_signOutDialog_content;

  /// No description provided for @settings_cloudSync_signOutDialog_signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settings_cloudSync_signOutDialog_signOut;

  /// No description provided for @settings_cloudSync_signOutDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Sign Out?'**
  String get settings_cloudSync_signOutDialog_title;

  /// No description provided for @settings_cloudSync_signOutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed out from cloud provider'**
  String get settings_cloudSync_signOutSuccess;

  /// No description provided for @settings_cloudSync_signOut_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect from cloud provider'**
  String get settings_cloudSync_signOut_subtitle;

  /// No description provided for @settings_cloudSync_status_conflictsDetected.
  ///
  /// In en, this message translates to:
  /// **'Conflicts detected'**
  String get settings_cloudSync_status_conflictsDetected;

  /// No description provided for @settings_cloudSync_status_readyToSync.
  ///
  /// In en, this message translates to:
  /// **'Ready to sync'**
  String get settings_cloudSync_status_readyToSync;

  /// No description provided for @settings_cloudSync_status_syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get settings_cloudSync_status_syncComplete;

  /// No description provided for @settings_cloudSync_status_syncError.
  ///
  /// In en, this message translates to:
  /// **'Sync error'**
  String get settings_cloudSync_status_syncError;

  /// No description provided for @settings_cloudSync_status_syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get settings_cloudSync_status_syncing;

  /// No description provided for @settings_cloudSync_storageSettings.
  ///
  /// In en, this message translates to:
  /// **'Storage Settings'**
  String get settings_cloudSync_storageSettings;

  /// No description provided for @settings_cloudSync_syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get settings_cloudSync_syncNow;

  /// No description provided for @settings_cloudSync_syncOnLaunch.
  ///
  /// In en, this message translates to:
  /// **'Sync on Launch'**
  String get settings_cloudSync_syncOnLaunch;

  /// No description provided for @settings_cloudSync_syncOnLaunch_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Check for updates at startup'**
  String get settings_cloudSync_syncOnLaunch_subtitle;

  /// No description provided for @settings_cloudSync_syncOnResume.
  ///
  /// In en, this message translates to:
  /// **'Sync on Resume'**
  String get settings_cloudSync_syncOnResume;

  /// No description provided for @settings_cloudSync_syncOnResume_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Check for updates when app becomes active'**
  String get settings_cloudSync_syncOnResume_subtitle;

  /// No description provided for @settings_cloudSync_syncProgressPercent.
  ///
  /// In en, this message translates to:
  /// **'Sync progress: {percent} percent'**
  String settings_cloudSync_syncProgressPercent(Object percent);

  /// No description provided for @settings_cloudSync_time_daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String settings_cloudSync_time_daysAgo(int count);

  /// No description provided for @settings_cloudSync_time_hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String settings_cloudSync_time_hoursAgo(int count);

  /// No description provided for @settings_cloudSync_time_justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get settings_cloudSync_time_justNow;

  /// No description provided for @settings_cloudSync_time_minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String settings_cloudSync_time_minutesAgo(int count);

  /// No description provided for @settings_conflict_applyAll.
  ///
  /// In en, this message translates to:
  /// **'Apply All'**
  String get settings_conflict_applyAll;

  /// No description provided for @settings_conflict_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settings_conflict_cancel;

  /// No description provided for @settings_conflict_chooseResolution.
  ///
  /// In en, this message translates to:
  /// **'Choose Resolution'**
  String get settings_conflict_chooseResolution;

  /// No description provided for @settings_conflict_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get settings_conflict_close;

  /// No description provided for @settings_conflict_close_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Close conflict dialog'**
  String get settings_conflict_close_tooltip;

  /// No description provided for @settings_conflict_counterLabel.
  ///
  /// In en, this message translates to:
  /// **'Conflict {current} of {total}'**
  String settings_conflict_counterLabel(Object current, Object total);

  /// No description provided for @settings_conflict_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading conflicts: {error}'**
  String settings_conflict_errorLoading(Object error);

  /// No description provided for @settings_conflict_keepBoth.
  ///
  /// In en, this message translates to:
  /// **'Keep Both'**
  String get settings_conflict_keepBoth;

  /// No description provided for @settings_conflict_keepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep Local'**
  String get settings_conflict_keepLocal;

  /// No description provided for @settings_conflict_keepRemote.
  ///
  /// In en, this message translates to:
  /// **'Keep Remote'**
  String get settings_conflict_keepRemote;

  /// No description provided for @settings_conflict_localVersion.
  ///
  /// In en, this message translates to:
  /// **'Local Version'**
  String get settings_conflict_localVersion;

  /// No description provided for @settings_conflict_modified.
  ///
  /// In en, this message translates to:
  /// **'Modified: {time}'**
  String settings_conflict_modified(Object time);

  /// No description provided for @settings_conflict_next_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Next conflict'**
  String get settings_conflict_next_tooltip;

  /// No description provided for @settings_conflict_noConflicts_message.
  ///
  /// In en, this message translates to:
  /// **'All sync conflicts have been resolved.'**
  String get settings_conflict_noConflicts_message;

  /// No description provided for @settings_conflict_noConflicts_title.
  ///
  /// In en, this message translates to:
  /// **'No Conflicts'**
  String get settings_conflict_noConflicts_title;

  /// No description provided for @settings_conflict_noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get settings_conflict_noDataAvailable;

  /// No description provided for @settings_conflict_previous_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous conflict'**
  String get settings_conflict_previous_tooltip;

  /// No description provided for @settings_conflict_remoteVersion.
  ///
  /// In en, this message translates to:
  /// **'Remote Version'**
  String get settings_conflict_remoteVersion;

  /// No description provided for @settings_conflict_resolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved {count, plural, =1{1 conflict} other{{count} conflicts}}'**
  String settings_conflict_resolved(int count);

  /// No description provided for @settings_conflict_title.
  ///
  /// In en, this message translates to:
  /// **'Resolve Conflicts'**
  String get settings_conflict_title;

  /// No description provided for @settings_data_appDefaultLocation.
  ///
  /// In en, this message translates to:
  /// **'App default location'**
  String get settings_data_appDefaultLocation;

  /// No description provided for @settings_data_backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settings_data_backup;

  /// No description provided for @settings_data_backup_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a backup of your data'**
  String get settings_data_backup_subtitle;

  /// No description provided for @settings_data_cloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get settings_data_cloudSync;

  /// No description provided for @settings_data_customFolder.
  ///
  /// In en, this message translates to:
  /// **'Custom folder'**
  String get settings_data_customFolder;

  /// No description provided for @settings_data_databaseStorage.
  ///
  /// In en, this message translates to:
  /// **'Database Storage'**
  String get settings_data_databaseStorage;

  /// No description provided for @settings_data_export_completed.
  ///
  /// In en, this message translates to:
  /// **'Export completed'**
  String get settings_data_export_completed;

  /// No description provided for @settings_data_export_exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get settings_data_export_exporting;

  /// No description provided for @settings_data_export_failed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String settings_data_export_failed(Object error);

  /// No description provided for @settings_data_header_backupSync.
  ///
  /// In en, this message translates to:
  /// **'Backup & Sync'**
  String get settings_data_header_backupSync;

  /// No description provided for @settings_data_header_storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settings_data_header_storage;

  /// No description provided for @settings_data_import_completed.
  ///
  /// In en, this message translates to:
  /// **'Operation completed'**
  String get settings_data_import_completed;

  /// No description provided for @settings_data_import_failed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String settings_data_import_failed(Object error);

  /// No description provided for @settings_data_offlineMaps.
  ///
  /// In en, this message translates to:
  /// **'Offline Maps'**
  String get settings_data_offlineMaps;

  /// No description provided for @settings_data_offlineMaps_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Download maps for offline use'**
  String get settings_data_offlineMaps_subtitle;

  /// No description provided for @settings_data_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get settings_data_restore;

  /// No description provided for @settings_data_restoreDialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settings_data_restoreDialog_cancel;

  /// No description provided for @settings_data_restoreDialog_content.
  ///
  /// In en, this message translates to:
  /// **'Warning: Restoring from a backup will replace ALL current data with the backup data. This action cannot be undone.  Are you sure you want to continue?'**
  String get settings_data_restoreDialog_content;

  /// No description provided for @settings_data_restoreDialog_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get settings_data_restoreDialog_restore;

  /// No description provided for @settings_data_restoreDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup'**
  String get settings_data_restoreDialog_title;

  /// No description provided for @settings_data_restore_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get settings_data_restore_subtitle;

  /// No description provided for @settings_data_syncTime_daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String settings_data_syncTime_daysAgo(Object count);

  /// No description provided for @settings_data_syncTime_hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String settings_data_syncTime_hoursAgo(Object count);

  /// No description provided for @settings_data_syncTime_justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get settings_data_syncTime_justNow;

  /// No description provided for @settings_data_syncTime_minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String settings_data_syncTime_minutesAgo(Object count);

  /// No description provided for @settings_data_sync_lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {time}'**
  String settings_data_sync_lastSynced(Object time);

  /// No description provided for @settings_data_sync_notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get settings_data_sync_notConfigured;

  /// No description provided for @settings_data_sync_syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get settings_data_sync_syncing;

  /// No description provided for @settings_decompression_aboutContent.
  ///
  /// In en, this message translates to:
  /// **'Gradient Factors (GF) control how conservative your decompression calculations are. GF Low affects deep stops, while GF High affects shallow stops.  Lower values = more conservative = longer deco stops Higher values = less conservative = shorter deco stops'**
  String get settings_decompression_aboutContent;

  /// No description provided for @settings_decompression_aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Gradient Factors'**
  String get settings_decompression_aboutTitle;

  /// No description provided for @settings_decompression_currentSettings.
  ///
  /// In en, this message translates to:
  /// **'Current Settings'**
  String get settings_decompression_currentSettings;

  /// No description provided for @settings_decompression_dialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settings_decompression_dialog_cancel;

  /// No description provided for @settings_decompression_dialog_conservatismHint.
  ///
  /// In en, this message translates to:
  /// **'Lower values = more conservative (longer NDL/more deco)'**
  String get settings_decompression_dialog_conservatismHint;

  /// No description provided for @settings_decompression_dialog_customValues.
  ///
  /// In en, this message translates to:
  /// **'Custom Values'**
  String get settings_decompression_dialog_customValues;

  /// No description provided for @settings_decompression_dialog_gfHigh.
  ///
  /// In en, this message translates to:
  /// **'GF High'**
  String get settings_decompression_dialog_gfHigh;

  /// No description provided for @settings_decompression_dialog_gfLow.
  ///
  /// In en, this message translates to:
  /// **'GF Low'**
  String get settings_decompression_dialog_gfLow;

  /// No description provided for @settings_decompression_dialog_info.
  ///
  /// In en, this message translates to:
  /// **'GF Low/High control how conservative your NDL and deco calculations are.'**
  String get settings_decompression_dialog_info;

  /// No description provided for @settings_decompression_dialog_presets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get settings_decompression_dialog_presets;

  /// No description provided for @settings_decompression_dialog_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settings_decompression_dialog_save;

  /// No description provided for @settings_decompression_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Gradient Factors'**
  String get settings_decompression_dialog_title;

  /// No description provided for @settings_decompression_gfValue.
  ///
  /// In en, this message translates to:
  /// **'GF {gfLow}/{gfHigh}'**
  String settings_decompression_gfValue(Object gfLow, Object gfHigh);

  /// No description provided for @settings_decompression_header_gradientFactors.
  ///
  /// In en, this message translates to:
  /// **'Gradient Factors'**
  String get settings_decompression_header_gradientFactors;

  /// No description provided for @settings_decompression_preset_selectLabel.
  ///
  /// In en, this message translates to:
  /// **'Select {presetName} conservatism preset'**
  String settings_decompression_preset_selectLabel(Object presetName);

  /// No description provided for @settings_existingDb_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settings_existingDb_cancel;

  /// No description provided for @settings_existingDb_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get settings_existingDb_continue;

  /// No description provided for @settings_existingDb_current.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get settings_existingDb_current;

  /// No description provided for @settings_existingDb_dialog_message.
  ///
  /// In en, this message translates to:
  /// **'A Submersion database already exists in this folder.'**
  String get settings_existingDb_dialog_message;

  /// No description provided for @settings_existingDb_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Existing Database Found'**
  String get settings_existingDb_dialog_title;

  /// No description provided for @settings_existingDb_existing.
  ///
  /// In en, this message translates to:
  /// **'Existing'**
  String get settings_existingDb_existing;

  /// No description provided for @settings_existingDb_replaceWarning.
  ///
  /// In en, this message translates to:
  /// **'The existing database will be backed up before being replaced.'**
  String get settings_existingDb_replaceWarning;

  /// No description provided for @settings_existingDb_replaceWithMyData.
  ///
  /// In en, this message translates to:
  /// **'Replace with my data'**
  String get settings_existingDb_replaceWithMyData;

  /// No description provided for @settings_existingDb_replaceWithMyData_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Overwrite with your current database'**
  String get settings_existingDb_replaceWithMyData_subtitle;

  /// No description provided for @settings_existingDb_stat_buddies.
  ///
  /// In en, this message translates to:
  /// **'Buddies'**
  String get settings_existingDb_stat_buddies;

  /// No description provided for @settings_existingDb_stat_dives.
  ///
  /// In en, this message translates to:
  /// **'Dives'**
  String get settings_existingDb_stat_dives;

  /// No description provided for @settings_existingDb_stat_sites.
  ///
  /// In en, this message translates to:
  /// **'Sites'**
  String get settings_existingDb_stat_sites;

  /// No description provided for @settings_existingDb_stat_trips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get settings_existingDb_stat_trips;

  /// No description provided for @settings_existingDb_stat_users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get settings_existingDb_stat_users;

  /// No description provided for @settings_existingDb_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get settings_existingDb_unknown;

  /// No description provided for @settings_existingDb_useExisting.
  ///
  /// In en, this message translates to:
  /// **'Use existing database'**
  String get settings_existingDb_useExisting;

  /// No description provided for @settings_existingDb_useExisting_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to the database in this folder'**
  String get settings_existingDb_useExisting_subtitle;

  /// No description provided for @settings_gfPreset_custom_description.
  ///
  /// In en, this message translates to:
  /// **'Set your own values'**
  String get settings_gfPreset_custom_description;

  /// No description provided for @settings_gfPreset_custom_name.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get settings_gfPreset_custom_name;

  /// No description provided for @settings_gfPreset_high_description.
  ///
  /// In en, this message translates to:
  /// **'Most conservative, longer deco stops'**
  String get settings_gfPreset_high_description;

  /// No description provided for @settings_gfPreset_high_name.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get settings_gfPreset_high_name;

  /// No description provided for @settings_gfPreset_low_description.
  ///
  /// In en, this message translates to:
  /// **'Least conservative, shorter deco'**
  String get settings_gfPreset_low_description;

  /// No description provided for @settings_gfPreset_low_name.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get settings_gfPreset_low_name;

  /// No description provided for @settings_gfPreset_medium_description.
  ///
  /// In en, this message translates to:
  /// **'Balanced approach'**
  String get settings_gfPreset_medium_description;

  /// No description provided for @settings_gfPreset_medium_name.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settings_gfPreset_medium_name;

  /// No description provided for @settings_import_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Importing Data'**
  String get settings_import_dialog_title;

  /// No description provided for @settings_import_doNotClose.
  ///
  /// In en, this message translates to:
  /// **'Please do not close the app'**
  String get settings_import_doNotClose;

  /// No description provided for @settings_import_itemCount.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String settings_import_itemCount(Object current, Object total);

  /// No description provided for @settings_import_phase_buddies.
  ///
  /// In en, this message translates to:
  /// **'Importing buddies...'**
  String get settings_import_phase_buddies;

  /// No description provided for @settings_import_phase_certifications.
  ///
  /// In en, this message translates to:
  /// **'Importing certifications...'**
  String get settings_import_phase_certifications;

  /// No description provided for @settings_import_phase_complete.
  ///
  /// In en, this message translates to:
  /// **'Finalizing...'**
  String get settings_import_phase_complete;

  /// No description provided for @settings_import_phase_diveCenters.
  ///
  /// In en, this message translates to:
  /// **'Importing dive centers...'**
  String get settings_import_phase_diveCenters;

  /// No description provided for @settings_import_phase_diveTypes.
  ///
  /// In en, this message translates to:
  /// **'Importing dive types...'**
  String get settings_import_phase_diveTypes;

  /// No description provided for @settings_import_phase_dives.
  ///
  /// In en, this message translates to:
  /// **'Importing dives...'**
  String get settings_import_phase_dives;

  /// No description provided for @settings_import_phase_equipment.
  ///
  /// In en, this message translates to:
  /// **'Importing equipment...'**
  String get settings_import_phase_equipment;

  /// No description provided for @settings_import_phase_equipmentSets.
  ///
  /// In en, this message translates to:
  /// **'Importing equipment sets...'**
  String get settings_import_phase_equipmentSets;

  /// No description provided for @settings_import_phase_parsing.
  ///
  /// In en, this message translates to:
  /// **'Parsing file...'**
  String get settings_import_phase_parsing;

  /// No description provided for @settings_import_phase_preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get settings_import_phase_preparing;

  /// No description provided for @settings_import_phase_sites.
  ///
  /// In en, this message translates to:
  /// **'Importing dive sites...'**
  String get settings_import_phase_sites;

  /// No description provided for @settings_import_phase_tags.
  ///
  /// In en, this message translates to:
  /// **'Importing tags...'**
  String get settings_import_phase_tags;

  /// No description provided for @settings_import_phase_trips.
  ///
  /// In en, this message translates to:
  /// **'Importing trips...'**
  String get settings_import_phase_trips;

  /// No description provided for @settings_import_progressLabel.
  ///
  /// In en, this message translates to:
  /// **'{phase}, {current} of {total}'**
  String settings_import_progressLabel(
    Object phase,
    Object current,
    Object total,
  );

  /// No description provided for @settings_import_progressPercent.
  ///
  /// In en, this message translates to:
  /// **'Import progress: {percent} percent'**
  String settings_import_progressPercent(Object percent);

  /// No description provided for @settings_language_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_language_appBar_title;

  /// No description provided for @settings_language_selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get settings_language_selected;

  /// No description provided for @settings_language_systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get settings_language_systemDefault;

  /// No description provided for @settings_manage_diveTypes.
  ///
  /// In en, this message translates to:
  /// **'Dive Types'**
  String get settings_manage_diveTypes;

  /// No description provided for @settings_manage_diveTypes_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage custom dive types'**
  String get settings_manage_diveTypes_subtitle;

  /// No description provided for @settings_manage_header_manageData.
  ///
  /// In en, this message translates to:
  /// **'Manage Data'**
  String get settings_manage_header_manageData;

  /// No description provided for @settings_manage_species.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get settings_manage_species;

  /// No description provided for @settings_manage_species_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage marine life species catalog'**
  String get settings_manage_species_subtitle;

  /// No description provided for @settings_manage_tankPresets.
  ///
  /// In en, this message translates to:
  /// **'Tank Presets'**
  String get settings_manage_tankPresets;

  /// No description provided for @settings_manage_tankPresets_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage custom tank configurations'**
  String get settings_manage_tankPresets_subtitle;

  /// No description provided for @settings_migrationProgress_doNotClose.
  ///
  /// In en, this message translates to:
  /// **'Please do not close the app'**
  String get settings_migrationProgress_doNotClose;

  /// No description provided for @settings_migration_backupInfo.
  ///
  /// In en, this message translates to:
  /// **'A backup will be created before the move. Your data will not be lost.'**
  String get settings_migration_backupInfo;

  /// No description provided for @settings_migration_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settings_migration_cancel;

  /// No description provided for @settings_migration_cloudSyncWarning.
  ///
  /// In en, this message translates to:
  /// **'App-managed cloud sync will be disabled. Your folder\'s sync service will handle synchronization.'**
  String get settings_migration_cloudSyncWarning;

  /// No description provided for @settings_migration_dialog_message.
  ///
  /// In en, this message translates to:
  /// **'Your database will be moved:'**
  String get settings_migration_dialog_message;

  /// No description provided for @settings_migration_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Move Database?'**
  String get settings_migration_dialog_title;

  /// No description provided for @settings_migration_from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get settings_migration_from;

  /// No description provided for @settings_migration_moveDatabase.
  ///
  /// In en, this message translates to:
  /// **'Move Database'**
  String get settings_migration_moveDatabase;

  /// No description provided for @settings_migration_to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get settings_migration_to;

  /// No description provided for @settings_notifications_days.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String settings_notifications_days(Object count);

  /// No description provided for @settings_notifications_disabled_enableButton.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get settings_notifications_disabled_enableButton;

  /// No description provided for @settings_notifications_disabled_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable in system settings to receive reminders'**
  String get settings_notifications_disabled_subtitle;

  /// No description provided for @settings_notifications_disabled_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications Disabled'**
  String get settings_notifications_disabled_title;

  /// No description provided for @settings_notifications_enableServiceReminders.
  ///
  /// In en, this message translates to:
  /// **'Enable Service Reminders'**
  String get settings_notifications_enableServiceReminders;

  /// No description provided for @settings_notifications_enableServiceReminders_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified when equipment service is due'**
  String get settings_notifications_enableServiceReminders_subtitle;

  /// No description provided for @settings_notifications_header_reminderSchedule.
  ///
  /// In en, this message translates to:
  /// **'Reminder Schedule'**
  String get settings_notifications_header_reminderSchedule;

  /// No description provided for @settings_notifications_header_serviceReminders.
  ///
  /// In en, this message translates to:
  /// **'Service Reminders'**
  String get settings_notifications_header_serviceReminders;

  /// No description provided for @settings_notifications_howItWorks_content.
  ///
  /// In en, this message translates to:
  /// **'Notifications are scheduled when the app launches and refresh periodically in the background. You can customize reminders for individual equipment items in their edit screen.'**
  String get settings_notifications_howItWorks_content;

  /// No description provided for @settings_notifications_howItWorks_title.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get settings_notifications_howItWorks_title;

  /// No description provided for @settings_notifications_permissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enable notifications in system settings'**
  String get settings_notifications_permissionRequired;

  /// No description provided for @settings_notifications_remindBeforeDue.
  ///
  /// In en, this message translates to:
  /// **'Remind me before service is due:'**
  String get settings_notifications_remindBeforeDue;

  /// No description provided for @settings_notifications_reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder Time'**
  String get settings_notifications_reminderTime;

  /// No description provided for @settings_profile_activeDiver_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Active diver - tap to switch'**
  String get settings_profile_activeDiver_subtitle;

  /// No description provided for @settings_profile_addNewDiver.
  ///
  /// In en, this message translates to:
  /// **'Add New Diver'**
  String get settings_profile_addNewDiver;

  /// No description provided for @settings_profile_error_loadingDiver.
  ///
  /// In en, this message translates to:
  /// **'Error loading diver'**
  String get settings_profile_error_loadingDiver;

  /// No description provided for @settings_profile_header_activeDiver.
  ///
  /// In en, this message translates to:
  /// **'Active Diver'**
  String get settings_profile_header_activeDiver;

  /// No description provided for @settings_profile_header_manageDivers.
  ///
  /// In en, this message translates to:
  /// **'Manage Divers'**
  String get settings_profile_header_manageDivers;

  /// No description provided for @settings_profile_noDiverProfile.
  ///
  /// In en, this message translates to:
  /// **'No diver profile'**
  String get settings_profile_noDiverProfile;

  /// No description provided for @settings_profile_noDiverProfile_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to create your profile'**
  String get settings_profile_noDiverProfile_subtitle;

  /// No description provided for @settings_profile_switchDiver_title.
  ///
  /// In en, this message translates to:
  /// **'Switch Diver'**
  String get settings_profile_switchDiver_title;

  /// No description provided for @settings_profile_switchedTo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {diverName}'**
  String settings_profile_switchedTo(Object diverName);

  /// No description provided for @settings_profile_viewAllDivers.
  ///
  /// In en, this message translates to:
  /// **'View All Divers'**
  String get settings_profile_viewAllDivers;

  /// No description provided for @settings_profile_viewAllDivers_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Add or edit diver profiles'**
  String get settings_profile_viewAllDivers_subtitle;

  /// No description provided for @settings_section_about_subtitle.
  ///
  /// In en, this message translates to:
  /// **'App info & licenses'**
  String get settings_section_about_subtitle;

  /// No description provided for @settings_section_about_title.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settings_section_about_title;

  /// No description provided for @settings_section_appearance_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme & display'**
  String get settings_section_appearance_subtitle;

  /// No description provided for @settings_section_appearance_title.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settings_section_appearance_title;

  /// No description provided for @settings_section_data_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Backup, restore & storage'**
  String get settings_section_data_subtitle;

  /// No description provided for @settings_section_data_title.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settings_section_data_title;

  /// No description provided for @settings_section_decompression_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Gradient factors'**
  String get settings_section_decompression_subtitle;

  /// No description provided for @settings_section_decompression_title.
  ///
  /// In en, this message translates to:
  /// **'Decompression'**
  String get settings_section_decompression_title;

  /// No description provided for @settings_section_diverProfile_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Active diver & profiles'**
  String get settings_section_diverProfile_subtitle;

  /// No description provided for @settings_section_diverProfile_title.
  ///
  /// In en, this message translates to:
  /// **'Diver Profile'**
  String get settings_section_diverProfile_title;

  /// No description provided for @settings_section_manage_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Dive types & tank presets'**
  String get settings_section_manage_subtitle;

  /// No description provided for @settings_section_manage_title.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get settings_section_manage_title;

  /// No description provided for @settings_section_notifications_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Service reminders'**
  String get settings_section_notifications_subtitle;

  /// No description provided for @settings_section_notifications_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settings_section_notifications_title;

  /// No description provided for @settings_section_units_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Measurement preferences'**
  String get settings_section_units_subtitle;

  /// No description provided for @settings_section_units_title.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get settings_section_units_title;

  /// No description provided for @settings_storage_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Database Storage'**
  String get settings_storage_appBar_title;

  /// No description provided for @settings_storage_appDefault.
  ///
  /// In en, this message translates to:
  /// **'App Default'**
  String get settings_storage_appDefault;

  /// No description provided for @settings_storage_appDefaultLocation.
  ///
  /// In en, this message translates to:
  /// **'App default location'**
  String get settings_storage_appDefaultLocation;

  /// No description provided for @settings_storage_appDefault_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Standard app storage location'**
  String get settings_storage_appDefault_subtitle;

  /// No description provided for @settings_storage_currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get settings_storage_currentLocation;

  /// No description provided for @settings_storage_currentLocation_label.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get settings_storage_currentLocation_label;

  /// No description provided for @settings_storage_customFolder.
  ///
  /// In en, this message translates to:
  /// **'Custom Folder'**
  String get settings_storage_customFolder;

  /// No description provided for @settings_storage_customFolder_change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get settings_storage_customFolder_change;

  /// No description provided for @settings_storage_customFolder_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a synced folder (Dropbox, Google Drive, etc.)'**
  String get settings_storage_customFolder_subtitle;

  /// No description provided for @settings_storage_dbStats.
  ///
  /// In en, this message translates to:
  /// **'{fileSize} • {diveCount} dives • {siteCount} sites'**
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  );

  /// No description provided for @settings_storage_dismissError_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss error'**
  String get settings_storage_dismissError_tooltip;

  /// No description provided for @settings_storage_dismissSuccess_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss success message'**
  String get settings_storage_dismissSuccess_tooltip;

  /// No description provided for @settings_storage_header_storageLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage Location'**
  String get settings_storage_header_storageLocation;

  /// No description provided for @settings_storage_info_customActive.
  ///
  /// In en, this message translates to:
  /// **'App-managed cloud sync is disabled. Your folder\'s sync service (Dropbox, Google Drive, etc.) handles synchronization.'**
  String get settings_storage_info_customActive;

  /// No description provided for @settings_storage_info_customAvailable.
  ///
  /// In en, this message translates to:
  /// **'Using a custom folder disables app-managed cloud sync. Your folder\'s sync service will handle synchronization instead.'**
  String get settings_storage_info_customAvailable;

  /// No description provided for @settings_storage_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get settings_storage_loading;

  /// No description provided for @settings_storage_migrating_doNotClose.
  ///
  /// In en, this message translates to:
  /// **'Please do not close the app'**
  String get settings_storage_migrating_doNotClose;

  /// No description provided for @settings_storage_migrating_movingDatabase.
  ///
  /// In en, this message translates to:
  /// **'Moving database...'**
  String get settings_storage_migrating_movingDatabase;

  /// No description provided for @settings_storage_migrating_movingToAppDefault.
  ///
  /// In en, this message translates to:
  /// **'Moving to app default...'**
  String get settings_storage_migrating_movingToAppDefault;

  /// No description provided for @settings_storage_migrating_replacingExisting.
  ///
  /// In en, this message translates to:
  /// **'Replacing existing database...'**
  String get settings_storage_migrating_replacingExisting;

  /// No description provided for @settings_storage_migrating_switchingToExisting.
  ///
  /// In en, this message translates to:
  /// **'Switching to existing database...'**
  String get settings_storage_migrating_switchingToExisting;

  /// No description provided for @settings_storage_notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settings_storage_notSet;

  /// No description provided for @settings_storage_success_backupAt.
  ///
  /// In en, this message translates to:
  /// **'Original kept as backup at: {path}'**
  String settings_storage_success_backupAt(Object path);

  /// No description provided for @settings_storage_success_moved.
  ///
  /// In en, this message translates to:
  /// **'Database moved successfully'**
  String get settings_storage_success_moved;

  /// No description provided for @settings_summary_activeDiver.
  ///
  /// In en, this message translates to:
  /// **'Active Diver'**
  String get settings_summary_activeDiver;

  /// No description provided for @settings_summary_currentConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Current Configuration'**
  String get settings_summary_currentConfiguration;

  /// No description provided for @settings_summary_depth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get settings_summary_depth;

  /// No description provided for @settings_summary_error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get settings_summary_error;

  /// No description provided for @settings_summary_gradientFactors.
  ///
  /// In en, this message translates to:
  /// **'Gradient Factors'**
  String get settings_summary_gradientFactors;

  /// No description provided for @settings_summary_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get settings_summary_loading;

  /// No description provided for @settings_summary_notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settings_summary_notSet;

  /// No description provided for @settings_summary_pressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get settings_summary_pressure;

  /// No description provided for @settings_summary_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a category to configure'**
  String get settings_summary_subtitle;

  /// No description provided for @settings_summary_temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get settings_summary_temperature;

  /// No description provided for @settings_summary_theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settings_summary_theme;

  /// No description provided for @settings_summary_theme_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settings_summary_theme_dark;

  /// No description provided for @settings_summary_theme_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settings_summary_theme_light;

  /// No description provided for @settings_summary_theme_system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settings_summary_theme_system;

  /// No description provided for @settings_summary_tip.
  ///
  /// In en, this message translates to:
  /// **'Tip: Use the Data section to backup your dive logs regularly.'**
  String get settings_summary_tip;

  /// No description provided for @settings_summary_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_summary_title;

  /// No description provided for @settings_summary_unitPreferences.
  ///
  /// In en, this message translates to:
  /// **'Unit Preferences'**
  String get settings_summary_unitPreferences;

  /// No description provided for @settings_summary_units.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get settings_summary_units;

  /// No description provided for @settings_summary_volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get settings_summary_volume;

  /// No description provided for @settings_summary_weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get settings_summary_weight;

  /// No description provided for @settings_units_custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get settings_units_custom;

  /// No description provided for @settings_units_dateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date Format'**
  String get settings_units_dateFormat;

  /// No description provided for @settings_units_depth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get settings_units_depth;

  /// No description provided for @settings_units_depth_feet.
  ///
  /// In en, this message translates to:
  /// **'Feet (ft)'**
  String get settings_units_depth_feet;

  /// No description provided for @settings_units_depth_meters.
  ///
  /// In en, this message translates to:
  /// **'Meters (m)'**
  String get settings_units_depth_meters;

  /// No description provided for @settings_units_dialog_dateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date Format'**
  String get settings_units_dialog_dateFormat;

  /// No description provided for @settings_units_dialog_depthUnit.
  ///
  /// In en, this message translates to:
  /// **'Depth Unit'**
  String get settings_units_dialog_depthUnit;

  /// No description provided for @settings_units_dialog_pressureUnit.
  ///
  /// In en, this message translates to:
  /// **'Pressure Unit'**
  String get settings_units_dialog_pressureUnit;

  /// No description provided for @settings_units_dialog_sacRateUnit.
  ///
  /// In en, this message translates to:
  /// **'SAC Rate Unit'**
  String get settings_units_dialog_sacRateUnit;

  /// No description provided for @settings_units_dialog_temperatureUnit.
  ///
  /// In en, this message translates to:
  /// **'Temperature Unit'**
  String get settings_units_dialog_temperatureUnit;

  /// No description provided for @settings_units_dialog_timeFormat.
  ///
  /// In en, this message translates to:
  /// **'Time Format'**
  String get settings_units_dialog_timeFormat;

  /// No description provided for @settings_units_dialog_volumeUnit.
  ///
  /// In en, this message translates to:
  /// **'Volume Unit'**
  String get settings_units_dialog_volumeUnit;

  /// No description provided for @settings_units_dialog_weightUnit.
  ///
  /// In en, this message translates to:
  /// **'Weight Unit'**
  String get settings_units_dialog_weightUnit;

  /// No description provided for @settings_units_header_individualUnits.
  ///
  /// In en, this message translates to:
  /// **'Individual Units'**
  String get settings_units_header_individualUnits;

  /// No description provided for @settings_units_header_timeDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Time & Date Format'**
  String get settings_units_header_timeDateFormat;

  /// No description provided for @settings_units_header_unitSystem.
  ///
  /// In en, this message translates to:
  /// **'Unit System'**
  String get settings_units_header_unitSystem;

  /// No description provided for @settings_units_imperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get settings_units_imperial;

  /// No description provided for @settings_units_metric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get settings_units_metric;

  /// No description provided for @settings_units_pressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get settings_units_pressure;

  /// No description provided for @settings_units_pressure_bar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get settings_units_pressure_bar;

  /// No description provided for @settings_units_pressure_psi.
  ///
  /// In en, this message translates to:
  /// **'PSI'**
  String get settings_units_pressure_psi;

  /// No description provided for @settings_units_quickSelect.
  ///
  /// In en, this message translates to:
  /// **'Quick Select'**
  String get settings_units_quickSelect;

  /// No description provided for @settings_units_sacRate.
  ///
  /// In en, this message translates to:
  /// **'SAC Rate'**
  String get settings_units_sacRate;

  /// No description provided for @settings_units_sac_pressurePerMinute.
  ///
  /// In en, this message translates to:
  /// **'Pressure per minute'**
  String get settings_units_sac_pressurePerMinute;

  /// No description provided for @settings_units_sac_pressurePerMinute_subtitle.
  ///
  /// In en, this message translates to:
  /// **'No tank volume needed (bar/min or psi/min)'**
  String get settings_units_sac_pressurePerMinute_subtitle;

  /// No description provided for @settings_units_sac_volumePerMinute.
  ///
  /// In en, this message translates to:
  /// **'Volume per minute'**
  String get settings_units_sac_volumePerMinute;

  /// No description provided for @settings_units_sac_volumePerMinute_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Requires tank volume (L/min or cuft/min)'**
  String get settings_units_sac_volumePerMinute_subtitle;

  /// No description provided for @settings_units_temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get settings_units_temperature;

  /// No description provided for @settings_units_temperature_celsius.
  ///
  /// In en, this message translates to:
  /// **'Celsius (°C)'**
  String get settings_units_temperature_celsius;

  /// No description provided for @settings_units_temperature_fahrenheit.
  ///
  /// In en, this message translates to:
  /// **'Fahrenheit (°F)'**
  String get settings_units_temperature_fahrenheit;

  /// No description provided for @settings_units_timeFormat.
  ///
  /// In en, this message translates to:
  /// **'Time Format'**
  String get settings_units_timeFormat;

  /// No description provided for @settings_units_volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get settings_units_volume;

  /// No description provided for @settings_units_volume_cubicFeet.
  ///
  /// In en, this message translates to:
  /// **'Cubic Feet (cuft)'**
  String get settings_units_volume_cubicFeet;

  /// No description provided for @settings_units_volume_liters.
  ///
  /// In en, this message translates to:
  /// **'Liters (L)'**
  String get settings_units_volume_liters;

  /// No description provided for @settings_units_weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get settings_units_weight;

  /// No description provided for @settings_units_weight_kilograms.
  ///
  /// In en, this message translates to:
  /// **'Kilograms (kg)'**
  String get settings_units_weight_kilograms;

  /// No description provided for @settings_units_weight_pounds.
  ///
  /// In en, this message translates to:
  /// **'Pounds (lbs)'**
  String get settings_units_weight_pounds;

  /// Button label to clear the signature canvas
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get signatures_action_clear;

  /// Tooltip for close button in the signature full view dialog
  ///
  /// In en, this message translates to:
  /// **'Close signature view'**
  String get signatures_action_closeSignatureView;

  /// Tooltip for delete signature button
  ///
  /// In en, this message translates to:
  /// **'Delete signature'**
  String get signatures_action_deleteSignature;

  /// Button label to finish signing
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get signatures_action_done;

  /// Button label to indicate buddy is ready to sign
  ///
  /// In en, this message translates to:
  /// **'Ready to Sign'**
  String get signatures_action_readyToSign;

  /// Button label to request a buddy signature
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get signatures_action_request;

  /// Button label to save the instructor signature
  ///
  /// In en, this message translates to:
  /// **'Save Signature'**
  String get signatures_action_saveSignature;

  /// Accessibility label for a buddy signature card that has not been signed
  ///
  /// In en, this message translates to:
  /// **'{name} signature, not signed'**
  String signatures_buddyCard_notSignedSemantics(Object name);

  /// Accessibility label for a buddy signature card that has been signed
  ///
  /// In en, this message translates to:
  /// **'{name} signature, signed'**
  String signatures_buddyCard_signedSemantics(Object name);

  /// Title for the instructor signature capture sheet
  ///
  /// In en, this message translates to:
  /// **'Capture Instructor Signature'**
  String get signatures_captureInstructorSignature;

  /// Confirmation message for deleting a signature
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the signature from {name}? This cannot be undone.'**
  String signatures_deleteDialog_message(Object name);

  /// Title for the delete signature confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Signature?'**
  String get signatures_deleteDialog_title;

  /// Helper text below the buddy signature canvas
  ///
  /// In en, this message translates to:
  /// **'Draw your signature above'**
  String get signatures_drawSignatureHint;

  /// Helper text below the instructor signature canvas
  ///
  /// In en, this message translates to:
  /// **'Draw signature above using finger or stylus'**
  String get signatures_drawSignatureHintDetailed;

  /// Accessibility label for the signature drawing canvas
  ///
  /// In en, this message translates to:
  /// **'Draw signature'**
  String get signatures_drawSignatureSemantics;

  /// Error shown when trying to save without drawing a signature
  ///
  /// In en, this message translates to:
  /// **'Please draw a signature'**
  String get signatures_error_drawSignature;

  /// Error shown when trying to save without entering a signer name
  ///
  /// In en, this message translates to:
  /// **'Please enter the signer name'**
  String get signatures_error_enterSignerName;

  /// Label for the instructor name text field
  ///
  /// In en, this message translates to:
  /// **'Instructor Name'**
  String get signatures_field_instructorName;

  /// Hint text for the instructor name text field
  ///
  /// In en, this message translates to:
  /// **'Enter instructor name'**
  String get signatures_field_instructorNameHint;

  /// Instruction text before handing device to buddy for signing
  ///
  /// In en, this message translates to:
  /// **'Hand your device to'**
  String get signatures_handoff_title;

  /// Label for instructor signature section
  ///
  /// In en, this message translates to:
  /// **'Instructor Signature'**
  String get signatures_instructorSignature;

  /// Placeholder text when no signature image is available
  ///
  /// In en, this message translates to:
  /// **'No signature image'**
  String get signatures_noSignatureImage;

  /// Title shown on the signature capture screen with buddy name
  ///
  /// In en, this message translates to:
  /// **'{name} - Sign Here'**
  String signatures_signHere(Object name);

  /// Badge label indicating a dive has been signed
  ///
  /// In en, this message translates to:
  /// **'Signed'**
  String get signatures_signed;

  /// Accessibility label for the signed count badge
  ///
  /// In en, this message translates to:
  /// **'{signed} of {total} buddies have signed'**
  String signatures_signedCountSemantics(Object signed, Object total);

  /// Timestamp showing when a signature was made
  ///
  /// In en, this message translates to:
  /// **'Signed {date}'**
  String signatures_signedDate(Object date);

  /// Section title for buddy signatures
  ///
  /// In en, this message translates to:
  /// **'Signatures'**
  String get signatures_title;

  /// Accessibility label for the signature badge
  ///
  /// In en, this message translates to:
  /// **'View signature'**
  String get signatures_viewSignature;

  /// Accessibility label for viewing a saved signature
  ///
  /// In en, this message translates to:
  /// **'View signature from {name}'**
  String signatures_viewSignatureSemantics(Object name);

  /// No description provided for @statistics_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics_appBar_title;

  /// No description provided for @statistics_categoryCard_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{title} statistics category'**
  String statistics_categoryCard_semanticLabel(Object title);

  /// No description provided for @statistics_category_conditions_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Visibility & temperature'**
  String get statistics_category_conditions_subtitle;

  /// No description provided for @statistics_category_conditions_title.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get statistics_category_conditions_title;

  /// No description provided for @statistics_category_equipment_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Gear usage & weight'**
  String get statistics_category_equipment_subtitle;

  /// No description provided for @statistics_category_equipment_title.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get statistics_category_equipment_title;

  /// No description provided for @statistics_category_gas_subtitle.
  ///
  /// In en, this message translates to:
  /// **'SAC rates & gas mixes'**
  String get statistics_category_gas_subtitle;

  /// No description provided for @statistics_category_gas_title.
  ///
  /// In en, this message translates to:
  /// **'Air Consumption'**
  String get statistics_category_gas_title;

  /// No description provided for @statistics_category_geographic_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Countries & regions'**
  String get statistics_category_geographic_subtitle;

  /// No description provided for @statistics_category_geographic_title.
  ///
  /// In en, this message translates to:
  /// **'Geographic'**
  String get statistics_category_geographic_title;

  /// No description provided for @statistics_category_marineLife_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Species sightings'**
  String get statistics_category_marineLife_subtitle;

  /// No description provided for @statistics_category_marineLife_title.
  ///
  /// In en, this message translates to:
  /// **'Marine Life'**
  String get statistics_category_marineLife_title;

  /// No description provided for @statistics_category_profile_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Ascent rates & deco'**
  String get statistics_category_profile_subtitle;

  /// No description provided for @statistics_category_profile_title.
  ///
  /// In en, this message translates to:
  /// **'Profile Analysis'**
  String get statistics_category_profile_title;

  /// No description provided for @statistics_category_progression_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Depth & time trends'**
  String get statistics_category_progression_subtitle;

  /// No description provided for @statistics_category_progression_title.
  ///
  /// In en, this message translates to:
  /// **'Progression'**
  String get statistics_category_progression_title;

  /// No description provided for @statistics_category_social_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Buddies & dive centers'**
  String get statistics_category_social_subtitle;

  /// No description provided for @statistics_category_social_title.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get statistics_category_social_title;

  /// No description provided for @statistics_category_timePatterns_subtitle.
  ///
  /// In en, this message translates to:
  /// **'When you dive'**
  String get statistics_category_timePatterns_subtitle;

  /// No description provided for @statistics_category_timePatterns_title.
  ///
  /// In en, this message translates to:
  /// **'Time Patterns'**
  String get statistics_category_timePatterns_title;

  /// No description provided for @statistics_chart_barSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Bar chart with {count} categories'**
  String statistics_chart_barSemanticLabel(Object count);

  /// No description provided for @statistics_chart_distributionSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Distribution pie chart with {count} segments'**
  String statistics_chart_distributionSemanticLabel(Object count);

  /// No description provided for @statistics_chart_multiTrendSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Multi-trend line chart comparing {seriesNames}'**
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames);

  /// No description provided for @statistics_chart_noBarData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get statistics_chart_noBarData;

  /// No description provided for @statistics_chart_noDistributionData.
  ///
  /// In en, this message translates to:
  /// **'No distribution data available'**
  String get statistics_chart_noDistributionData;

  /// No description provided for @statistics_chart_noTrendData.
  ///
  /// In en, this message translates to:
  /// **'No trend data available'**
  String get statistics_chart_noTrendData;

  /// No description provided for @statistics_chart_trendSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Trend line chart showing {count} data points'**
  String statistics_chart_trendSemanticLabel(Object count);

  /// No description provided for @statistics_chart_trendSemanticLabelWithAxis.
  ///
  /// In en, this message translates to:
  /// **'Trend line chart showing {count} data points for {yAxisLabel}'**
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  );

  /// No description provided for @statistics_conditions_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get statistics_conditions_appBar_title;

  /// No description provided for @statistics_conditions_entryMethod_empty.
  ///
  /// In en, this message translates to:
  /// **'No entry method data available'**
  String get statistics_conditions_entryMethod_empty;

  /// No description provided for @statistics_conditions_entryMethod_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load entry method data'**
  String get statistics_conditions_entryMethod_error;

  /// No description provided for @statistics_conditions_entryMethod_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shore, boat, etc.'**
  String get statistics_conditions_entryMethod_subtitle;

  /// No description provided for @statistics_conditions_entryMethod_title.
  ///
  /// In en, this message translates to:
  /// **'Entry Method'**
  String get statistics_conditions_entryMethod_title;

  /// No description provided for @statistics_conditions_temperature_empty.
  ///
  /// In en, this message translates to:
  /// **'No temperature data available'**
  String get statistics_conditions_temperature_empty;

  /// No description provided for @statistics_conditions_temperature_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load temperature data'**
  String get statistics_conditions_temperature_error;

  /// No description provided for @statistics_conditions_temperature_seriesAvg.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get statistics_conditions_temperature_seriesAvg;

  /// No description provided for @statistics_conditions_temperature_seriesMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get statistics_conditions_temperature_seriesMax;

  /// No description provided for @statistics_conditions_temperature_seriesMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get statistics_conditions_temperature_seriesMin;

  /// No description provided for @statistics_conditions_temperature_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Min/Avg/Max temperatures'**
  String get statistics_conditions_temperature_subtitle;

  /// No description provided for @statistics_conditions_temperature_title.
  ///
  /// In en, this message translates to:
  /// **'Water Temperature by Month'**
  String get statistics_conditions_temperature_title;

  /// No description provided for @statistics_conditions_visibility_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load visibility data'**
  String get statistics_conditions_visibility_error;

  /// No description provided for @statistics_conditions_visibility_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Dives by visibility condition'**
  String get statistics_conditions_visibility_subtitle;

  /// No description provided for @statistics_conditions_visibility_title.
  ///
  /// In en, this message translates to:
  /// **'Visibility Distribution'**
  String get statistics_conditions_visibility_title;

  /// No description provided for @statistics_conditions_waterType_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load water type data'**
  String get statistics_conditions_waterType_error;

  /// No description provided for @statistics_conditions_waterType_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Salt vs Fresh water dives'**
  String get statistics_conditions_waterType_subtitle;

  /// No description provided for @statistics_conditions_waterType_title.
  ///
  /// In en, this message translates to:
  /// **'Water Type'**
  String get statistics_conditions_waterType_title;

  /// No description provided for @statistics_equipment_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get statistics_equipment_appBar_title;

  /// No description provided for @statistics_equipment_mostUsedGear_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load gear data'**
  String get statistics_equipment_mostUsedGear_error;

  /// No description provided for @statistics_equipment_mostUsedGear_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Equipment by dive count'**
  String get statistics_equipment_mostUsedGear_subtitle;

  /// No description provided for @statistics_equipment_mostUsedGear_title.
  ///
  /// In en, this message translates to:
  /// **'Most Used Gear'**
  String get statistics_equipment_mostUsedGear_title;

  /// No description provided for @statistics_equipment_weightTrend_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load weight trend'**
  String get statistics_equipment_weightTrend_error;

  /// No description provided for @statistics_equipment_weightTrend_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Average weight over time'**
  String get statistics_equipment_weightTrend_subtitle;

  /// No description provided for @statistics_equipment_weightTrend_title.
  ///
  /// In en, this message translates to:
  /// **'Weight Trend'**
  String get statistics_equipment_weightTrend_title;

  /// No description provided for @statistics_error_loadingStatistics.
  ///
  /// In en, this message translates to:
  /// **'Error loading statistics'**
  String get statistics_error_loadingStatistics;

  /// No description provided for @statistics_gas_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Air Consumption'**
  String get statistics_gas_appBar_title;

  /// No description provided for @statistics_gas_gasMix_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load gas mix data'**
  String get statistics_gas_gasMix_error;

  /// No description provided for @statistics_gas_gasMix_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Dives by gas type'**
  String get statistics_gas_gasMix_subtitle;

  /// No description provided for @statistics_gas_gasMix_title.
  ///
  /// In en, this message translates to:
  /// **'Gas Mix Distribution'**
  String get statistics_gas_gasMix_title;

  /// No description provided for @statistics_gas_sacByRole_empty.
  ///
  /// In en, this message translates to:
  /// **'No multi-tank data available'**
  String get statistics_gas_sacByRole_empty;

  /// No description provided for @statistics_gas_sacByRole_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load SAC by role'**
  String get statistics_gas_sacByRole_error;

  /// No description provided for @statistics_gas_sacByRole_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Average consumption by tank type'**
  String get statistics_gas_sacByRole_subtitle;

  /// No description provided for @statistics_gas_sacByRole_title.
  ///
  /// In en, this message translates to:
  /// **'SAC by Tank Role'**
  String get statistics_gas_sacByRole_title;

  /// No description provided for @statistics_gas_sacRecords_best.
  ///
  /// In en, this message translates to:
  /// **'Best SAC Rate'**
  String get statistics_gas_sacRecords_best;

  /// No description provided for @statistics_gas_sacRecords_empty.
  ///
  /// In en, this message translates to:
  /// **'No SAC data available yet'**
  String get statistics_gas_sacRecords_empty;

  /// No description provided for @statistics_gas_sacRecords_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load SAC records'**
  String get statistics_gas_sacRecords_error;

  /// No description provided for @statistics_gas_sacRecords_highest.
  ///
  /// In en, this message translates to:
  /// **'Highest SAC Rate'**
  String get statistics_gas_sacRecords_highest;

  /// No description provided for @statistics_gas_sacRecords_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Best and worst air consumption'**
  String get statistics_gas_sacRecords_subtitle;

  /// No description provided for @statistics_gas_sacRecords_title.
  ///
  /// In en, this message translates to:
  /// **'SAC Rate Records'**
  String get statistics_gas_sacRecords_title;

  /// No description provided for @statistics_gas_sacTrend_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load SAC trend'**
  String get statistics_gas_sacTrend_error;

  /// No description provided for @statistics_gas_sacTrend_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly average over 5 years'**
  String get statistics_gas_sacTrend_subtitle;

  /// No description provided for @statistics_gas_sacTrend_title.
  ///
  /// In en, this message translates to:
  /// **'SAC Rate Trend'**
  String get statistics_gas_sacTrend_title;

  /// No description provided for @statistics_gas_tankRole_backGas.
  ///
  /// In en, this message translates to:
  /// **'Back Gas'**
  String get statistics_gas_tankRole_backGas;

  /// No description provided for @statistics_gas_tankRole_bailout.
  ///
  /// In en, this message translates to:
  /// **'Bailout'**
  String get statistics_gas_tankRole_bailout;

  /// No description provided for @statistics_gas_tankRole_deco.
  ///
  /// In en, this message translates to:
  /// **'Deco'**
  String get statistics_gas_tankRole_deco;

  /// No description provided for @statistics_gas_tankRole_diluent.
  ///
  /// In en, this message translates to:
  /// **'Diluent'**
  String get statistics_gas_tankRole_diluent;

  /// No description provided for @statistics_gas_tankRole_oxygenSupply.
  ///
  /// In en, this message translates to:
  /// **'O₂ Supply'**
  String get statistics_gas_tankRole_oxygenSupply;

  /// No description provided for @statistics_gas_tankRole_pony.
  ///
  /// In en, this message translates to:
  /// **'Pony'**
  String get statistics_gas_tankRole_pony;

  /// No description provided for @statistics_gas_tankRole_sidemountLeft.
  ///
  /// In en, this message translates to:
  /// **'Sidemount L'**
  String get statistics_gas_tankRole_sidemountLeft;

  /// No description provided for @statistics_gas_tankRole_sidemountRight.
  ///
  /// In en, this message translates to:
  /// **'Sidemount R'**
  String get statistics_gas_tankRole_sidemountRight;

  /// No description provided for @statistics_gas_tankRole_stage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get statistics_gas_tankRole_stage;

  /// No description provided for @statistics_geographic_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Geographic'**
  String get statistics_geographic_appBar_title;

  /// No description provided for @statistics_geographic_countries_empty.
  ///
  /// In en, this message translates to:
  /// **'No countries visited'**
  String get statistics_geographic_countries_empty;

  /// No description provided for @statistics_geographic_countries_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load country data'**
  String get statistics_geographic_countries_error;

  /// No description provided for @statistics_geographic_countries_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Dives by country'**
  String get statistics_geographic_countries_subtitle;

  /// No description provided for @statistics_geographic_countries_summary.
  ///
  /// In en, this message translates to:
  /// **'{count} countries. Top: {topName} with {topCount} dives'**
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  );

  /// No description provided for @statistics_geographic_countries_title.
  ///
  /// In en, this message translates to:
  /// **'Countries Visited'**
  String get statistics_geographic_countries_title;

  /// No description provided for @statistics_geographic_regions_empty.
  ///
  /// In en, this message translates to:
  /// **'No regions explored'**
  String get statistics_geographic_regions_empty;

  /// No description provided for @statistics_geographic_regions_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load region data'**
  String get statistics_geographic_regions_error;

  /// No description provided for @statistics_geographic_regions_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Dives by region'**
  String get statistics_geographic_regions_subtitle;

  /// No description provided for @statistics_geographic_regions_summary.
  ///
  /// In en, this message translates to:
  /// **'{count} regions. Top: {topName} with {topCount} dives'**
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  );

  /// No description provided for @statistics_geographic_regions_title.
  ///
  /// In en, this message translates to:
  /// **'Regions Explored'**
  String get statistics_geographic_regions_title;

  /// No description provided for @statistics_geographic_trips_empty.
  ///
  /// In en, this message translates to:
  /// **'No trip data'**
  String get statistics_geographic_trips_empty;

  /// No description provided for @statistics_geographic_trips_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load trip data'**
  String get statistics_geographic_trips_error;

  /// No description provided for @statistics_geographic_trips_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Most productive trips'**
  String get statistics_geographic_trips_subtitle;

  /// No description provided for @statistics_geographic_trips_summary.
  ///
  /// In en, this message translates to:
  /// **'{count} trips. Top: {topName} with {topCount} dives'**
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  );

  /// No description provided for @statistics_geographic_trips_title.
  ///
  /// In en, this message translates to:
  /// **'Dives Per Trip'**
  String get statistics_geographic_trips_title;

  /// No description provided for @statistics_listContent_selectedSuffix.
  ///
  /// In en, this message translates to:
  /// **', selected'**
  String get statistics_listContent_selectedSuffix;

  /// No description provided for @statistics_marineLife_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Marine Life'**
  String get statistics_marineLife_appBar_title;

  /// No description provided for @statistics_marineLife_bestSites_empty.
  ///
  /// In en, this message translates to:
  /// **'No site data'**
  String get statistics_marineLife_bestSites_empty;

  /// No description provided for @statistics_marineLife_bestSites_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load site data'**
  String get statistics_marineLife_bestSites_error;

  /// No description provided for @statistics_marineLife_bestSites_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sites with most species variety'**
  String get statistics_marineLife_bestSites_subtitle;

  /// No description provided for @statistics_marineLife_bestSites_summary.
  ///
  /// In en, this message translates to:
  /// **'{count} sites. Best: {topName} with {topCount} species'**
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  );

  /// No description provided for @statistics_marineLife_bestSites_title.
  ///
  /// In en, this message translates to:
  /// **'Best Sites for Marine Life'**
  String get statistics_marineLife_bestSites_title;

  /// No description provided for @statistics_marineLife_mostCommon_empty.
  ///
  /// In en, this message translates to:
  /// **'No sighting data'**
  String get statistics_marineLife_mostCommon_empty;

  /// No description provided for @statistics_marineLife_mostCommon_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sighting data'**
  String get statistics_marineLife_mostCommon_error;

  /// No description provided for @statistics_marineLife_mostCommon_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Species spotted most often'**
  String get statistics_marineLife_mostCommon_subtitle;

  /// No description provided for @statistics_marineLife_mostCommon_summary.
  ///
  /// In en, this message translates to:
  /// **'{count} species. Most common: {topName} with {topCount} sightings'**
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  );

  /// No description provided for @statistics_marineLife_mostCommon_title.
  ///
  /// In en, this message translates to:
  /// **'Most Common Sightings'**
  String get statistics_marineLife_mostCommon_title;

  /// No description provided for @statistics_marineLife_speciesSpotted.
  ///
  /// In en, this message translates to:
  /// **'Species Spotted'**
  String get statistics_marineLife_speciesSpotted;

  /// No description provided for @statistics_profile_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Profile Analysis'**
  String get statistics_profile_appBar_title;

  /// No description provided for @statistics_profile_ascentDescent_empty.
  ///
  /// In en, this message translates to:
  /// **'No profile data available'**
  String get statistics_profile_ascentDescent_empty;

  /// No description provided for @statistics_profile_ascentDescent_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load rate data'**
  String get statistics_profile_ascentDescent_error;

  /// No description provided for @statistics_profile_ascentDescent_subtitle.
  ///
  /// In en, this message translates to:
  /// **'From dive profile data'**
  String get statistics_profile_ascentDescent_subtitle;

  /// No description provided for @statistics_profile_ascentDescent_title.
  ///
  /// In en, this message translates to:
  /// **'Average Ascent & Descent Rates'**
  String get statistics_profile_ascentDescent_title;

  /// No description provided for @statistics_profile_avgAscent.
  ///
  /// In en, this message translates to:
  /// **'Avg Ascent'**
  String get statistics_profile_avgAscent;

  /// No description provided for @statistics_profile_avgDescent.
  ///
  /// In en, this message translates to:
  /// **'Avg Descent'**
  String get statistics_profile_avgDescent;

  /// No description provided for @statistics_profile_deco_decoDives.
  ///
  /// In en, this message translates to:
  /// **'Deco Dives'**
  String get statistics_profile_deco_decoDives;

  /// No description provided for @statistics_profile_deco_decoLabel.
  ///
  /// In en, this message translates to:
  /// **'Deco'**
  String get statistics_profile_deco_decoLabel;

  /// No description provided for @statistics_profile_deco_decoRate.
  ///
  /// In en, this message translates to:
  /// **'Deco Rate'**
  String get statistics_profile_deco_decoRate;

  /// No description provided for @statistics_profile_deco_empty.
  ///
  /// In en, this message translates to:
  /// **'No deco data available'**
  String get statistics_profile_deco_empty;

  /// No description provided for @statistics_profile_deco_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load deco data'**
  String get statistics_profile_deco_error;

  /// No description provided for @statistics_profile_deco_noDeco.
  ///
  /// In en, this message translates to:
  /// **'No Deco'**
  String get statistics_profile_deco_noDeco;

  /// No description provided for @statistics_profile_deco_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Decompression rate: {percentage}% of dives required deco stops'**
  String statistics_profile_deco_semanticLabel(Object percentage);

  /// No description provided for @statistics_profile_deco_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Dives that incurred deco stops'**
  String get statistics_profile_deco_subtitle;

  /// No description provided for @statistics_profile_deco_title.
  ///
  /// In en, this message translates to:
  /// **'Decompression Obligation'**
  String get statistics_profile_deco_title;

  /// No description provided for @statistics_profile_timeAtDepth_empty.
  ///
  /// In en, this message translates to:
  /// **'No depth data available'**
  String get statistics_profile_timeAtDepth_empty;

  /// No description provided for @statistics_profile_timeAtDepth_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load depth range data'**
  String get statistics_profile_timeAtDepth_error;

  /// No description provided for @statistics_profile_timeAtDepth_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Approximate time spent at each depth'**
  String get statistics_profile_timeAtDepth_subtitle;

  /// No description provided for @statistics_profile_timeAtDepth_title.
  ///
  /// In en, this message translates to:
  /// **'Time at Depth Ranges'**
  String get statistics_profile_timeAtDepth_title;

  /// No description provided for @statistics_profile_timeAtDepth_valueFormat.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String statistics_profile_timeAtDepth_valueFormat(Object value);

  /// No description provided for @statistics_progression_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Progression'**
  String get statistics_progression_appBar_title;

  /// No description provided for @statistics_progression_bottomTime_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load bottom time trend'**
  String get statistics_progression_bottomTime_error;

  /// No description provided for @statistics_progression_bottomTime_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Average duration by month'**
  String get statistics_progression_bottomTime_subtitle;

  /// No description provided for @statistics_progression_bottomTime_title.
  ///
  /// In en, this message translates to:
  /// **'Bottom Time Trend'**
  String get statistics_progression_bottomTime_title;

  /// No description provided for @statistics_progression_cumulative_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load cumulative data'**
  String get statistics_progression_cumulative_error;

  /// No description provided for @statistics_progression_cumulative_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Total dives over time'**
  String get statistics_progression_cumulative_subtitle;

  /// No description provided for @statistics_progression_cumulative_title.
  ///
  /// In en, this message translates to:
  /// **'Cumulative Dive Count'**
  String get statistics_progression_cumulative_title;

  /// No description provided for @statistics_progression_depthProgression_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load depth progression'**
  String get statistics_progression_depthProgression_error;

  /// No description provided for @statistics_progression_depthProgression_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly max depth over 5 years'**
  String get statistics_progression_depthProgression_subtitle;

  /// No description provided for @statistics_progression_depthProgression_title.
  ///
  /// In en, this message translates to:
  /// **'Maximum Depth Progression'**
  String get statistics_progression_depthProgression_title;

  /// No description provided for @statistics_progression_divesPerYear_empty.
  ///
  /// In en, this message translates to:
  /// **'No yearly data available'**
  String get statistics_progression_divesPerYear_empty;

  /// No description provided for @statistics_progression_divesPerYear_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load yearly data'**
  String get statistics_progression_divesPerYear_error;

  /// No description provided for @statistics_progression_divesPerYear_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Annual dive count comparison'**
  String get statistics_progression_divesPerYear_subtitle;

  /// No description provided for @statistics_progression_divesPerYear_title.
  ///
  /// In en, this message translates to:
  /// **'Dives Per Year'**
  String get statistics_progression_divesPerYear_title;

  /// No description provided for @statistics_ranking_countLabel_dives.
  ///
  /// In en, this message translates to:
  /// **'dives'**
  String get statistics_ranking_countLabel_dives;

  /// No description provided for @statistics_ranking_countLabel_sightings.
  ///
  /// In en, this message translates to:
  /// **'sightings'**
  String get statistics_ranking_countLabel_sightings;

  /// No description provided for @statistics_ranking_countLabel_species.
  ///
  /// In en, this message translates to:
  /// **'species'**
  String get statistics_ranking_countLabel_species;

  /// No description provided for @statistics_ranking_emptyState.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get statistics_ranking_emptyState;

  /// No description provided for @statistics_ranking_itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {label}'**
  String statistics_ranking_itemCount(Object count, Object label);

  /// No description provided for @statistics_ranking_moreItems.
  ///
  /// In en, this message translates to:
  /// **'and {count} more'**
  String statistics_ranking_moreItems(Object count);

  /// No description provided for @statistics_ranking_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}, rank {rank}, {count} {label}'**
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  );

  /// No description provided for @statistics_records_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Records'**
  String get statistics_records_appBar_title;

  /// No description provided for @statistics_records_coldestDive.
  ///
  /// In en, this message translates to:
  /// **'Coldest Dive'**
  String get statistics_records_coldestDive;

  /// No description provided for @statistics_records_deepestDive.
  ///
  /// In en, this message translates to:
  /// **'Deepest Dive'**
  String get statistics_records_deepestDive;

  /// No description provided for @statistics_records_diveNumber.
  ///
  /// In en, this message translates to:
  /// **'Dive #{number}'**
  String statistics_records_diveNumber(Object number);

  /// No description provided for @statistics_records_emptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start logging dives to see your records here'**
  String get statistics_records_emptySubtitle;

  /// No description provided for @statistics_records_emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Records Yet'**
  String get statistics_records_emptyTitle;

  /// No description provided for @statistics_records_error.
  ///
  /// In en, this message translates to:
  /// **'Error loading records'**
  String get statistics_records_error;

  /// No description provided for @statistics_records_firstDive.
  ///
  /// In en, this message translates to:
  /// **'First Dive'**
  String get statistics_records_firstDive;

  /// No description provided for @statistics_records_longestDive.
  ///
  /// In en, this message translates to:
  /// **'Longest Dive'**
  String get statistics_records_longestDive;

  /// No description provided for @statistics_records_longestDiveValue.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String statistics_records_longestDiveValue(Object minutes);

  /// No description provided for @statistics_records_milestoneSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{title}: {siteName}'**
  String statistics_records_milestoneSemanticLabel(
    Object title,
    Object siteName,
  );

  /// No description provided for @statistics_records_milestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get statistics_records_milestones;

  /// No description provided for @statistics_records_mostRecentDive.
  ///
  /// In en, this message translates to:
  /// **'Most Recent Dive'**
  String get statistics_records_mostRecentDive;

  /// No description provided for @statistics_records_recordSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{title}: {value} at {siteName}'**
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  );

  /// No description provided for @statistics_records_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get statistics_records_retry;

  /// No description provided for @statistics_records_shallowestDive.
  ///
  /// In en, this message translates to:
  /// **'Shallowest Dive'**
  String get statistics_records_shallowestDive;

  /// No description provided for @statistics_records_unknownSite.
  ///
  /// In en, this message translates to:
  /// **'Unknown Site'**
  String get statistics_records_unknownSite;

  /// No description provided for @statistics_records_warmestDive.
  ///
  /// In en, this message translates to:
  /// **'Warmest Dive'**
  String get statistics_records_warmestDive;

  /// No description provided for @statistics_sectionCard_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{title} section'**
  String statistics_sectionCard_semanticLabel(Object title);

  /// No description provided for @statistics_social_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Social & Buddies'**
  String get statistics_social_appBar_title;

  /// No description provided for @statistics_social_soloVsBuddy_empty.
  ///
  /// In en, this message translates to:
  /// **'No dive data available'**
  String get statistics_social_soloVsBuddy_empty;

  /// No description provided for @statistics_social_soloVsBuddy_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load buddy data'**
  String get statistics_social_soloVsBuddy_error;

  /// No description provided for @statistics_social_soloVsBuddy_solo.
  ///
  /// In en, this message translates to:
  /// **'Solo'**
  String get statistics_social_soloVsBuddy_solo;

  /// No description provided for @statistics_social_soloVsBuddy_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Diving with or without companions'**
  String get statistics_social_soloVsBuddy_subtitle;

  /// No description provided for @statistics_social_soloVsBuddy_title.
  ///
  /// In en, this message translates to:
  /// **'Solo vs Buddy Dives'**
  String get statistics_social_soloVsBuddy_title;

  /// No description provided for @statistics_social_soloVsBuddy_withBuddy.
  ///
  /// In en, this message translates to:
  /// **'With Buddy'**
  String get statistics_social_soloVsBuddy_withBuddy;

  /// No description provided for @statistics_social_topBuddies_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load buddy rankings'**
  String get statistics_social_topBuddies_error;

  /// No description provided for @statistics_social_topBuddies_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Most frequent diving companions'**
  String get statistics_social_topBuddies_subtitle;

  /// No description provided for @statistics_social_topBuddies_title.
  ///
  /// In en, this message translates to:
  /// **'Top Dive Buddies'**
  String get statistics_social_topBuddies_title;

  /// No description provided for @statistics_social_topDiveCenters_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load dive center rankings'**
  String get statistics_social_topDiveCenters_error;

  /// No description provided for @statistics_social_topDiveCenters_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Most visited operators'**
  String get statistics_social_topDiveCenters_subtitle;

  /// No description provided for @statistics_social_topDiveCenters_title.
  ///
  /// In en, this message translates to:
  /// **'Top Dive Centers'**
  String get statistics_social_topDiveCenters_title;

  /// No description provided for @statistics_summary_avgDepth.
  ///
  /// In en, this message translates to:
  /// **'Avg Depth'**
  String get statistics_summary_avgDepth;

  /// No description provided for @statistics_summary_avgTemp.
  ///
  /// In en, this message translates to:
  /// **'Avg Temp'**
  String get statistics_summary_avgTemp;

  /// No description provided for @statistics_summary_depthDistribution_empty.
  ///
  /// In en, this message translates to:
  /// **'Chart will appear when you log dives'**
  String get statistics_summary_depthDistribution_empty;

  /// No description provided for @statistics_summary_depthDistribution_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Pie chart showing depth distribution'**
  String get statistics_summary_depthDistribution_semanticLabel;

  /// No description provided for @statistics_summary_depthDistribution_title.
  ///
  /// In en, this message translates to:
  /// **'Depth Distribution'**
  String get statistics_summary_depthDistribution_title;

  /// No description provided for @statistics_summary_diveTypes_empty.
  ///
  /// In en, this message translates to:
  /// **'Chart will appear when you log dives'**
  String get statistics_summary_diveTypes_empty;

  /// No description provided for @statistics_summary_diveTypes_moreTypes.
  ///
  /// In en, this message translates to:
  /// **'and {count} more types'**
  String statistics_summary_diveTypes_moreTypes(Object count);

  /// No description provided for @statistics_summary_diveTypes_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Pie chart showing dive type distribution'**
  String get statistics_summary_diveTypes_semanticLabel;

  /// No description provided for @statistics_summary_diveTypes_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Types'**
  String get statistics_summary_diveTypes_title;

  /// No description provided for @statistics_summary_divesByMonth_empty.
  ///
  /// In en, this message translates to:
  /// **'Chart will appear when you log dives'**
  String get statistics_summary_divesByMonth_empty;

  /// No description provided for @statistics_summary_divesByMonth_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Bar chart showing dives by month'**
  String get statistics_summary_divesByMonth_semanticLabel;

  /// No description provided for @statistics_summary_divesByMonth_title.
  ///
  /// In en, this message translates to:
  /// **'Dives by Month'**
  String get statistics_summary_divesByMonth_title;

  /// No description provided for @statistics_summary_divesByMonth_tooltip.
  ///
  /// In en, this message translates to:
  /// **'{fullLabel} {count} dives'**
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  );

  /// No description provided for @statistics_summary_header_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a category to explore detailed statistics'**
  String get statistics_summary_header_subtitle;

  /// No description provided for @statistics_summary_header_title.
  ///
  /// In en, this message translates to:
  /// **'Statistics Overview'**
  String get statistics_summary_header_title;

  /// No description provided for @statistics_summary_maxDepth.
  ///
  /// In en, this message translates to:
  /// **'Max Depth'**
  String get statistics_summary_maxDepth;

  /// No description provided for @statistics_summary_sitesVisited.
  ///
  /// In en, this message translates to:
  /// **'Sites Visited'**
  String get statistics_summary_sitesVisited;

  /// No description provided for @statistics_summary_tagUsage_diveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dive} other{{count} dives}}'**
  String statistics_summary_tagUsage_diveCount(int count);

  /// No description provided for @statistics_summary_tagUsage_empty.
  ///
  /// In en, this message translates to:
  /// **'No tags created yet'**
  String get statistics_summary_tagUsage_empty;

  /// No description provided for @statistics_summary_tagUsage_emptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add tags to dives to see statistics'**
  String get statistics_summary_tagUsage_emptyHint;

  /// No description provided for @statistics_summary_tagUsage_moreTags.
  ///
  /// In en, this message translates to:
  /// **'and {count} more tags'**
  String statistics_summary_tagUsage_moreTags(Object count);

  /// No description provided for @statistics_summary_tagUsage_tagCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String statistics_summary_tagUsage_tagCount(Object count);

  /// No description provided for @statistics_summary_tagUsage_title.
  ///
  /// In en, this message translates to:
  /// **'Tag Usage'**
  String get statistics_summary_tagUsage_title;

  /// No description provided for @statistics_summary_topDiveSites_diveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} dives'**
  String statistics_summary_topDiveSites_diveCount(Object count);

  /// No description provided for @statistics_summary_topDiveSites_empty.
  ///
  /// In en, this message translates to:
  /// **'No dive sites yet'**
  String get statistics_summary_topDiveSites_empty;

  /// No description provided for @statistics_summary_topDiveSites_title.
  ///
  /// In en, this message translates to:
  /// **'Top Dive Sites'**
  String get statistics_summary_topDiveSites_title;

  /// No description provided for @statistics_summary_topDiveSites_totalCount.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String statistics_summary_topDiveSites_totalCount(Object count);

  /// No description provided for @statistics_summary_totalDives.
  ///
  /// In en, this message translates to:
  /// **'Total Dives'**
  String get statistics_summary_totalDives;

  /// No description provided for @statistics_summary_totalTime.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get statistics_summary_totalTime;

  /// No description provided for @statistics_timePatterns_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Time Patterns'**
  String get statistics_timePatterns_appBar_title;

  /// No description provided for @statistics_timePatterns_dayOfWeek_empty.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get statistics_timePatterns_dayOfWeek_empty;

  /// No description provided for @statistics_timePatterns_dayOfWeek_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load day of week data'**
  String get statistics_timePatterns_dayOfWeek_error;

  /// No description provided for @statistics_timePatterns_dayOfWeek_fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get statistics_timePatterns_dayOfWeek_fri;

  /// No description provided for @statistics_timePatterns_dayOfWeek_mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get statistics_timePatterns_dayOfWeek_mon;

  /// No description provided for @statistics_timePatterns_dayOfWeek_sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get statistics_timePatterns_dayOfWeek_sat;

  /// No description provided for @statistics_timePatterns_dayOfWeek_subtitle.
  ///
  /// In en, this message translates to:
  /// **'When do you dive most?'**
  String get statistics_timePatterns_dayOfWeek_subtitle;

  /// No description provided for @statistics_timePatterns_dayOfWeek_sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get statistics_timePatterns_dayOfWeek_sun;

  /// No description provided for @statistics_timePatterns_dayOfWeek_thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get statistics_timePatterns_dayOfWeek_thu;

  /// No description provided for @statistics_timePatterns_dayOfWeek_title.
  ///
  /// In en, this message translates to:
  /// **'Dives by Day of Week'**
  String get statistics_timePatterns_dayOfWeek_title;

  /// No description provided for @statistics_timePatterns_dayOfWeek_tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get statistics_timePatterns_dayOfWeek_tue;

  /// No description provided for @statistics_timePatterns_dayOfWeek_wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get statistics_timePatterns_dayOfWeek_wed;

  /// No description provided for @statistics_timePatterns_month_apr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get statistics_timePatterns_month_apr;

  /// No description provided for @statistics_timePatterns_month_aug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get statistics_timePatterns_month_aug;

  /// No description provided for @statistics_timePatterns_month_dec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get statistics_timePatterns_month_dec;

  /// No description provided for @statistics_timePatterns_month_feb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get statistics_timePatterns_month_feb;

  /// No description provided for @statistics_timePatterns_month_jan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get statistics_timePatterns_month_jan;

  /// No description provided for @statistics_timePatterns_month_jul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get statistics_timePatterns_month_jul;

  /// No description provided for @statistics_timePatterns_month_jun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get statistics_timePatterns_month_jun;

  /// No description provided for @statistics_timePatterns_month_mar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get statistics_timePatterns_month_mar;

  /// No description provided for @statistics_timePatterns_month_may.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get statistics_timePatterns_month_may;

  /// No description provided for @statistics_timePatterns_month_nov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get statistics_timePatterns_month_nov;

  /// No description provided for @statistics_timePatterns_month_oct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get statistics_timePatterns_month_oct;

  /// No description provided for @statistics_timePatterns_month_sep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get statistics_timePatterns_month_sep;

  /// No description provided for @statistics_timePatterns_seasonal_empty.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get statistics_timePatterns_seasonal_empty;

  /// No description provided for @statistics_timePatterns_seasonal_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load seasonal data'**
  String get statistics_timePatterns_seasonal_error;

  /// No description provided for @statistics_timePatterns_seasonal_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Dives by month (all years)'**
  String get statistics_timePatterns_seasonal_subtitle;

  /// No description provided for @statistics_timePatterns_seasonal_title.
  ///
  /// In en, this message translates to:
  /// **'Seasonal Patterns'**
  String get statistics_timePatterns_seasonal_title;

  /// No description provided for @statistics_timePatterns_surfaceInterval_average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get statistics_timePatterns_surfaceInterval_average;

  /// No description provided for @statistics_timePatterns_surfaceInterval_empty.
  ///
  /// In en, this message translates to:
  /// **'No surface interval data available'**
  String get statistics_timePatterns_surfaceInterval_empty;

  /// No description provided for @statistics_timePatterns_surfaceInterval_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load surface interval data'**
  String get statistics_timePatterns_surfaceInterval_error;

  /// No description provided for @statistics_timePatterns_surfaceInterval_formatHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String statistics_timePatterns_surfaceInterval_formatHoursMinutes(
    Object hours,
    Object minutes,
  );

  /// No description provided for @statistics_timePatterns_surfaceInterval_formatMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String statistics_timePatterns_surfaceInterval_formatMinutes(Object minutes);

  /// No description provided for @statistics_timePatterns_surfaceInterval_maximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get statistics_timePatterns_surfaceInterval_maximum;

  /// No description provided for @statistics_timePatterns_surfaceInterval_minimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get statistics_timePatterns_surfaceInterval_minimum;

  /// No description provided for @statistics_timePatterns_surfaceInterval_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Time between dives'**
  String get statistics_timePatterns_surfaceInterval_subtitle;

  /// No description provided for @statistics_timePatterns_surfaceInterval_title.
  ///
  /// In en, this message translates to:
  /// **'Surface Interval Statistics'**
  String get statistics_timePatterns_surfaceInterval_title;

  /// No description provided for @statistics_timePatterns_timeOfDay_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to load time of day data'**
  String get statistics_timePatterns_timeOfDay_error;

  /// No description provided for @statistics_timePatterns_timeOfDay_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Morning, afternoon, evening, or night'**
  String get statistics_timePatterns_timeOfDay_subtitle;

  /// No description provided for @statistics_timePatterns_timeOfDay_title.
  ///
  /// In en, this message translates to:
  /// **'Dives by Time of Day'**
  String get statistics_timePatterns_timeOfDay_title;

  /// No description provided for @statistics_tooltip_diveRecords.
  ///
  /// In en, this message translates to:
  /// **'Dive Records'**
  String get statistics_tooltip_diveRecords;

  /// No description provided for @statistics_tooltip_refreshRecords.
  ///
  /// In en, this message translates to:
  /// **'Refresh records'**
  String get statistics_tooltip_refreshRecords;

  /// No description provided for @statistics_tooltip_refreshStatistics.
  ///
  /// In en, this message translates to:
  /// **'Refresh statistics'**
  String get statistics_tooltip_refreshStatistics;

  /// No description provided for @statistics_valueCard_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String statistics_valueCard_semanticLabel(Object label, Object value);

  /// Educational text explaining tissue compartments and nitrogen loading
  ///
  /// In en, this message translates to:
  /// **'Your body has 16 tissue compartments that absorb and release nitrogen at different rates. Fast tissues (like blood) saturate quickly but also off-gas quickly. Slow tissues (like bone and fat) take longer to both load and unload.  The \"leading compartment\" is whichever tissue is most saturated and typically controls your no-decompression limit (NDL). During a surface interval, all tissues off-gas toward surface saturation levels (~40% loading).'**
  String get surfaceInterval_aboutTissueLoading_body;

  /// Title for the tissue loading info card
  ///
  /// In en, this message translates to:
  /// **'About Tissue Loading'**
  String get surfaceInterval_aboutTissueLoading_title;

  /// Tooltip for the reset button on the surface interval tool
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get surfaceInterval_action_resetDefaults;

  /// Disclaimer warning about the surface interval tool
  ///
  /// In en, this message translates to:
  /// **'This tool is for planning purposes only. Always use a dive computer and follow your training. Results are based on the Buhlmann ZH-L16C algorithm and may differ from your computer.'**
  String get surfaceInterval_disclaimer;

  /// Label for depth slider
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get surfaceInterval_field_depth;

  /// Label for gas mix display
  ///
  /// In en, this message translates to:
  /// **'Gas Mix: '**
  String get surfaceInterval_field_gasMix;

  /// Label for helium percentage slider
  ///
  /// In en, this message translates to:
  /// **'He'**
  String get surfaceInterval_field_he;

  /// Label for oxygen percentage slider
  ///
  /// In en, this message translates to:
  /// **'O₂'**
  String get surfaceInterval_field_o2;

  /// Label for time slider
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get surfaceInterval_field_time;

  /// Accessibility label for first dive depth slider
  ///
  /// In en, this message translates to:
  /// **'First dive depth: {depth} {unit}'**
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit);

  /// Accessibility label for first dive time slider
  ///
  /// In en, this message translates to:
  /// **'First dive time: {time} minutes'**
  String surfaceInterval_firstDive_timeSemantics(Object time);

  /// Header for the first (previous) dive input card
  ///
  /// In en, this message translates to:
  /// **'First Dive'**
  String get surfaceInterval_firstDive_title;

  /// Format for hours display
  ///
  /// In en, this message translates to:
  /// **'{count} hours'**
  String surfaceInterval_format_hours(Object count);

  /// Format for minutes display
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String surfaceInterval_format_minutes(Object count);

  /// Gas mix name for standard air (21% O2)
  ///
  /// In en, this message translates to:
  /// **'Air'**
  String get surfaceInterval_gasMix_air;

  /// Gas mix name for enriched air nitrox
  ///
  /// In en, this message translates to:
  /// **'EAN{percent}'**
  String surfaceInterval_gasMix_ean(Object percent);

  /// Gas mix name for trimix
  ///
  /// In en, this message translates to:
  /// **'Trimix {o2}/{he}'**
  String surfaceInterval_gasMix_trimix(Object o2, Object he);

  /// Accessibility label for helium slider
  ///
  /// In en, this message translates to:
  /// **'Helium: {percent}%'**
  String surfaceInterval_heSemantics(Object percent);

  /// Accessibility label for O2 slider
  ///
  /// In en, this message translates to:
  /// **'O2: {percent}%'**
  String surfaceInterval_o2Semantics(Object percent);

  /// Label for the current surface interval column
  ///
  /// In en, this message translates to:
  /// **'Current Interval'**
  String get surfaceInterval_result_currentInterval;

  /// Shown when the second dive would require decompression stops
  ///
  /// In en, this message translates to:
  /// **'In deco'**
  String get surfaceInterval_result_inDeco;

  /// Warning message when the current interval is insufficient
  ///
  /// In en, this message translates to:
  /// **'Increase surface interval or reduce second dive depth/time'**
  String get surfaceInterval_result_increaseInterval;

  /// Title label for the minimum surface interval result
  ///
  /// In en, this message translates to:
  /// **'Minimum Surface Interval'**
  String get surfaceInterval_result_minimumInterval;

  /// Label for the NDL column in the result card
  ///
  /// In en, this message translates to:
  /// **'NDL for 2nd Dive'**
  String get surfaceInterval_result_ndlForSecondDive;

  /// No-decompression limit in minutes for the second dive
  ///
  /// In en, this message translates to:
  /// **'{minutes} min NDL'**
  String surfaceInterval_result_ndlMinutes(Object minutes);

  /// Status message when more surface interval time is needed
  ///
  /// In en, this message translates to:
  /// **'Not yet safe, increase surface interval'**
  String get surfaceInterval_result_notYetSafe;

  /// Status message when the current surface interval is sufficient
  ///
  /// In en, this message translates to:
  /// **'Safe to dive'**
  String get surfaceInterval_result_safeToDive;

  /// Full accessibility label for the surface interval result card
  ///
  /// In en, this message translates to:
  /// **'Minimum surface interval: {interval}. Current interval: {current}. NDL for second dive: {ndl}. {status}'**
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  );

  /// Accessibility label for second dive depth slider
  ///
  /// In en, this message translates to:
  /// **'Second dive depth: {depth} {unit}'**
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit);

  /// Label indicating the second dive uses air
  ///
  /// In en, this message translates to:
  /// **'(Air)'**
  String get surfaceInterval_secondDive_gasAir;

  /// Accessibility label for second dive time slider
  ///
  /// In en, this message translates to:
  /// **'Second dive time: {time} minutes'**
  String surfaceInterval_secondDive_timeSemantics(Object time);

  /// Header for the second (planned) dive input card
  ///
  /// In en, this message translates to:
  /// **'Second Dive'**
  String get surfaceInterval_secondDive_title;

  /// Accessibility label for the tissue recovery chart
  ///
  /// In en, this message translates to:
  /// **'Tissue recovery chart showing 16 compartment off-gassing over a {interval} surface interval'**
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval);

  /// Legend title for the tissue compartment categories
  ///
  /// In en, this message translates to:
  /// **'Compartments (by half-time speed)'**
  String get surfaceInterval_tissueRecovery_compartmentsLabel;

  /// Description text below the tissue recovery chart header
  ///
  /// In en, this message translates to:
  /// **'Showing how each of 16 tissue compartments off-gas during the surface interval'**
  String get surfaceInterval_tissueRecovery_description;

  /// Legend label for fast tissue compartments
  ///
  /// In en, this message translates to:
  /// **'Fast (C1-5)'**
  String get surfaceInterval_tissueRecovery_fast;

  /// Label showing which compartment is the leading (most saturated) one
  ///
  /// In en, this message translates to:
  /// **'Leading compartment: C{number}'**
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number);

  /// Y-axis label for the tissue recovery chart
  ///
  /// In en, this message translates to:
  /// **'Loading %'**
  String get surfaceInterval_tissueRecovery_loadingPercent;

  /// Legend label for medium tissue compartments
  ///
  /// In en, this message translates to:
  /// **'Medium (C6-10)'**
  String get surfaceInterval_tissueRecovery_medium;

  /// Label for the minimum interval marker on the chart
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get surfaceInterval_tissueRecovery_min;

  /// Label for the current time marker on the chart
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get surfaceInterval_tissueRecovery_now;

  /// Legend label for slow tissue compartments
  ///
  /// In en, this message translates to:
  /// **'Slow (C11-16)'**
  String get surfaceInterval_tissueRecovery_slow;

  /// Header for the tissue recovery chart card
  ///
  /// In en, this message translates to:
  /// **'Tissue Recovery'**
  String get surfaceInterval_tissueRecovery_title;

  /// Title for the surface interval tool page and axis label
  ///
  /// In en, this message translates to:
  /// **'Surface Interval'**
  String get surfaceInterval_title;

  /// No description provided for @tags_action_createNamed.
  ///
  /// In en, this message translates to:
  /// **'Create \"{tagName}\"'**
  String tags_action_createNamed(Object tagName);

  /// No description provided for @tags_action_createTag.
  ///
  /// In en, this message translates to:
  /// **'Create tag'**
  String get tags_action_createTag;

  /// No description provided for @tags_action_deleteTag.
  ///
  /// In en, this message translates to:
  /// **'Delete tag'**
  String get tags_action_deleteTag;

  /// No description provided for @tags_dialog_deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{tagName}\"? This will remove it from all dives.'**
  String tags_dialog_deleteMessage(Object tagName);

  /// No description provided for @tags_dialog_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Tag?'**
  String get tags_dialog_deleteTitle;

  /// No description provided for @tags_empty.
  ///
  /// In en, this message translates to:
  /// **'No tags yet. Create tags when editing dives.'**
  String get tags_empty;

  /// No description provided for @tags_hint_addMoreTags.
  ///
  /// In en, this message translates to:
  /// **'Add more tags...'**
  String get tags_hint_addMoreTags;

  /// No description provided for @tags_hint_addTags.
  ///
  /// In en, this message translates to:
  /// **'Add tags...'**
  String get tags_hint_addTags;

  /// No description provided for @tags_title_manageTags.
  ///
  /// In en, this message translates to:
  /// **'Manage Tags'**
  String get tags_title_manageTags;

  /// No description provided for @tank_al30Stage_description.
  ///
  /// In en, this message translates to:
  /// **'Aluminum 30 cu ft stage tank'**
  String get tank_al30Stage_description;

  /// No description provided for @tank_al30Stage_displayName.
  ///
  /// In en, this message translates to:
  /// **'AL30 Stage'**
  String get tank_al30Stage_displayName;

  /// No description provided for @tank_al40Stage_description.
  ///
  /// In en, this message translates to:
  /// **'Aluminum 40 cu ft stage tank'**
  String get tank_al40Stage_description;

  /// No description provided for @tank_al40Stage_displayName.
  ///
  /// In en, this message translates to:
  /// **'AL40 Stage'**
  String get tank_al40Stage_displayName;

  /// No description provided for @tank_al40_description.
  ///
  /// In en, this message translates to:
  /// **'Aluminum 40 cu ft (pony)'**
  String get tank_al40_description;

  /// No description provided for @tank_al40_displayName.
  ///
  /// In en, this message translates to:
  /// **'AL40'**
  String get tank_al40_displayName;

  /// No description provided for @tank_al63_description.
  ///
  /// In en, this message translates to:
  /// **'Aluminum 63 cu ft'**
  String get tank_al63_description;

  /// No description provided for @tank_al63_displayName.
  ///
  /// In en, this message translates to:
  /// **'AL63'**
  String get tank_al63_displayName;

  /// No description provided for @tank_al80_description.
  ///
  /// In en, this message translates to:
  /// **'Aluminum 80 cu ft (most common)'**
  String get tank_al80_description;

  /// No description provided for @tank_al80_displayName.
  ///
  /// In en, this message translates to:
  /// **'AL80'**
  String get tank_al80_displayName;

  /// No description provided for @tank_hp100_description.
  ///
  /// In en, this message translates to:
  /// **'High Pressure Steel 100 cu ft'**
  String get tank_hp100_description;

  /// No description provided for @tank_hp100_displayName.
  ///
  /// In en, this message translates to:
  /// **'HP100'**
  String get tank_hp100_displayName;

  /// No description provided for @tank_hp120_description.
  ///
  /// In en, this message translates to:
  /// **'High Pressure Steel 120 cu ft'**
  String get tank_hp120_description;

  /// No description provided for @tank_hp120_displayName.
  ///
  /// In en, this message translates to:
  /// **'HP120'**
  String get tank_hp120_displayName;

  /// No description provided for @tank_hp80_description.
  ///
  /// In en, this message translates to:
  /// **'High Pressure Steel 80 cu ft'**
  String get tank_hp80_description;

  /// No description provided for @tank_hp80_displayName.
  ///
  /// In en, this message translates to:
  /// **'HP80'**
  String get tank_hp80_displayName;

  /// No description provided for @tank_lp85_description.
  ///
  /// In en, this message translates to:
  /// **'Low Pressure Steel 85 cu ft'**
  String get tank_lp85_description;

  /// No description provided for @tank_lp85_displayName.
  ///
  /// In en, this message translates to:
  /// **'LP85'**
  String get tank_lp85_displayName;

  /// No description provided for @tank_steel10_description.
  ///
  /// In en, this message translates to:
  /// **'Steel 10 liter (Europe)'**
  String get tank_steel10_description;

  /// No description provided for @tank_steel10_displayName.
  ///
  /// In en, this message translates to:
  /// **'Steel 10L'**
  String get tank_steel10_displayName;

  /// No description provided for @tank_steel12_description.
  ///
  /// In en, this message translates to:
  /// **'Steel 12 liter (Europe)'**
  String get tank_steel12_description;

  /// No description provided for @tank_steel12_displayName.
  ///
  /// In en, this message translates to:
  /// **'Steel 12L'**
  String get tank_steel12_displayName;

  /// No description provided for @tank_steel15_description.
  ///
  /// In en, this message translates to:
  /// **'Steel 15 liter (Europe)'**
  String get tank_steel15_description;

  /// No description provided for @tank_steel15_displayName.
  ///
  /// In en, this message translates to:
  /// **'Steel 15L'**
  String get tank_steel15_displayName;

  /// No description provided for @tides_action_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh tide data'**
  String get tides_action_refresh;

  /// No description provided for @tides_chart_24hourForecast.
  ///
  /// In en, this message translates to:
  /// **'24-Hour Forecast'**
  String get tides_chart_24hourForecast;

  /// No description provided for @tides_chart_heightAxis.
  ///
  /// In en, this message translates to:
  /// **'Height ({depthSymbol})'**
  String tides_chart_heightAxis(Object depthSymbol);

  /// No description provided for @tides_chart_msl.
  ///
  /// In en, this message translates to:
  /// **'MSL'**
  String get tides_chart_msl;

  /// No description provided for @tides_chart_nowLabel.
  ///
  /// In en, this message translates to:
  /// **' Now {nowTimeStr} {nowHeightStr}'**
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr);

  /// No description provided for @tides_error_unableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load tide data'**
  String get tides_error_unableToLoad;

  /// No description provided for @tides_error_unableToLoadChart.
  ///
  /// In en, this message translates to:
  /// **'Unable to load chart'**
  String get tides_error_unableToLoadChart;

  /// No description provided for @tides_label_ago.
  ///
  /// In en, this message translates to:
  /// **'{duration} ago'**
  String tides_label_ago(Object duration);

  /// No description provided for @tides_label_currentHeight.
  ///
  /// In en, this message translates to:
  /// **'Current: {height}{depthSymbol}'**
  String tides_label_currentHeight(Object height, Object depthSymbol);

  /// No description provided for @tides_label_fromNow.
  ///
  /// In en, this message translates to:
  /// **'{duration} from now'**
  String tides_label_fromNow(Object duration);

  /// No description provided for @tides_label_high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get tides_label_high;

  /// No description provided for @tides_label_highIn.
  ///
  /// In en, this message translates to:
  /// **'High in'**
  String get tides_label_highIn;

  /// No description provided for @tides_label_highTide.
  ///
  /// In en, this message translates to:
  /// **'High Tide'**
  String get tides_label_highTide;

  /// No description provided for @tides_label_low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get tides_label_low;

  /// No description provided for @tides_label_lowIn.
  ///
  /// In en, this message translates to:
  /// **'Low in'**
  String get tides_label_lowIn;

  /// No description provided for @tides_label_lowTide.
  ///
  /// In en, this message translates to:
  /// **'Low Tide'**
  String get tides_label_lowTide;

  /// No description provided for @tides_label_tideIn.
  ///
  /// In en, this message translates to:
  /// **'in {duration}'**
  String tides_label_tideIn(Object duration);

  /// No description provided for @tides_label_tideTimes.
  ///
  /// In en, this message translates to:
  /// **'Tide Times'**
  String get tides_label_tideTimes;

  /// No description provided for @tides_label_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tides_label_today;

  /// No description provided for @tides_label_tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tides_label_tomorrow;

  /// No description provided for @tides_label_upcomingTides.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Tides'**
  String get tides_label_upcomingTides;

  /// No description provided for @tides_legend_highTide.
  ///
  /// In en, this message translates to:
  /// **'High Tide'**
  String get tides_legend_highTide;

  /// No description provided for @tides_legend_lowTide.
  ///
  /// In en, this message translates to:
  /// **'Low Tide'**
  String get tides_legend_lowTide;

  /// No description provided for @tides_legend_now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get tides_legend_now;

  /// No description provided for @tides_legend_tideLevel.
  ///
  /// In en, this message translates to:
  /// **'Tide Level'**
  String get tides_legend_tideLevel;

  /// No description provided for @tides_noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No tide data available'**
  String get tides_noDataAvailable;

  /// No description provided for @tides_noDataForLocation.
  ///
  /// In en, this message translates to:
  /// **'Tide data not available for this location'**
  String get tides_noDataForLocation;

  /// No description provided for @tides_noExtremesData.
  ///
  /// In en, this message translates to:
  /// **'No extremes data'**
  String get tides_noExtremesData;

  /// No description provided for @tides_noTideTimesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No tide times available'**
  String get tides_noTideTimesAvailable;

  /// No description provided for @tides_semantic_currentTide.
  ///
  /// In en, this message translates to:
  /// **'{tideState} tide, {height}{depthSymbol}{nextExtreme}'**
  String tides_semantic_currentTide(
    Object tideState,
    Object height,
    Object depthSymbol,
    Object nextExtreme,
  );

  /// No description provided for @tides_semantic_extremeItem.
  ///
  /// In en, this message translates to:
  /// **'{typeLabel} tide at {time}, {height}{depthSymbol}'**
  String tides_semantic_extremeItem(
    Object typeLabel,
    Object time,
    Object height,
    Object depthSymbol,
  );

  /// No description provided for @tides_semantic_tideChart.
  ///
  /// In en, this message translates to:
  /// **'Tide chart. {extremesSummary}'**
  String tides_semantic_tideChart(Object extremesSummary);

  /// No description provided for @tides_semantic_tideState.
  ///
  /// In en, this message translates to:
  /// **'Tide state: {state}'**
  String tides_semantic_tideState(Object state);

  /// No description provided for @tides_title.
  ///
  /// In en, this message translates to:
  /// **'Tides'**
  String get tides_title;

  /// No description provided for @transfer_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer_appBar_title;

  /// No description provided for @transfer_computers_aboutContent.
  ///
  /// In en, this message translates to:
  /// **'Connect your dive computer via Bluetooth to download dive logs directly to the app. Supported computers include Suunto, Shearwater, Garmin, Mares, and many other popular brands.  Apple Watch Ultra users can import dive data directly from the Health app, including depth, duration, and heart rate.'**
  String get transfer_computers_aboutContent;

  /// No description provided for @transfer_computers_aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Dive Computers'**
  String get transfer_computers_aboutTitle;

  /// No description provided for @transfer_computers_appleWatchHeader.
  ///
  /// In en, this message translates to:
  /// **'Apple Watch'**
  String get transfer_computers_appleWatchHeader;

  /// No description provided for @transfer_computers_appleWatchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import dives recorded on Apple Watch Ultra'**
  String get transfer_computers_appleWatchSubtitle;

  /// No description provided for @transfer_computers_appleWatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from Apple Watch'**
  String get transfer_computers_appleWatchTitle;

  /// No description provided for @transfer_computers_connectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover and pair a dive computer'**
  String get transfer_computers_connectSubtitle;

  /// No description provided for @transfer_computers_connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect New Computer'**
  String get transfer_computers_connectTitle;

  /// No description provided for @transfer_computers_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading computers'**
  String get transfer_computers_errorLoading;

  /// No description provided for @transfer_computers_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get transfer_computers_loading;

  /// No description provided for @transfer_computers_manageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Computers'**
  String get transfer_computers_manageTitle;

  /// No description provided for @transfer_computers_noComputersSaved.
  ///
  /// In en, this message translates to:
  /// **'No computers saved'**
  String get transfer_computers_noComputersSaved;

  /// No description provided for @transfer_computers_savedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} saved {count, plural, =1{computer} other{computers}}'**
  String transfer_computers_savedCount(int count);

  /// No description provided for @transfer_computers_sectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Dive Computers'**
  String get transfer_computers_sectionHeader;

  /// No description provided for @transfer_csvExport_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get transfer_csvExport_cancelButton;

  /// No description provided for @transfer_csvExport_dataTypeHeader.
  ///
  /// In en, this message translates to:
  /// **'Data Type'**
  String get transfer_csvExport_dataTypeHeader;

  /// No description provided for @transfer_csvExport_descriptionDives.
  ///
  /// In en, this message translates to:
  /// **'Export all dive logs as a spreadsheet'**
  String get transfer_csvExport_descriptionDives;

  /// No description provided for @transfer_csvExport_descriptionEquipment.
  ///
  /// In en, this message translates to:
  /// **'Export equipment inventory and service info'**
  String get transfer_csvExport_descriptionEquipment;

  /// No description provided for @transfer_csvExport_descriptionSites.
  ///
  /// In en, this message translates to:
  /// **'Export dive site locations and details'**
  String get transfer_csvExport_descriptionSites;

  /// No description provided for @transfer_csvExport_dialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get transfer_csvExport_dialogTitle;

  /// No description provided for @transfer_csvExport_exportButton.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get transfer_csvExport_exportButton;

  /// No description provided for @transfer_csvExport_optionDivesTitle.
  ///
  /// In en, this message translates to:
  /// **'Dives CSV'**
  String get transfer_csvExport_optionDivesTitle;

  /// No description provided for @transfer_csvExport_optionEquipmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Equipment CSV'**
  String get transfer_csvExport_optionEquipmentTitle;

  /// No description provided for @transfer_csvExport_optionSitesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sites CSV'**
  String get transfer_csvExport_optionSitesTitle;

  /// No description provided for @transfer_csvExport_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Export {typeName}'**
  String transfer_csvExport_semanticLabel(Object typeName);

  /// No description provided for @transfer_csvExport_typeDives.
  ///
  /// In en, this message translates to:
  /// **'Dives'**
  String get transfer_csvExport_typeDives;

  /// No description provided for @transfer_csvExport_typeEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get transfer_csvExport_typeEquipment;

  /// No description provided for @transfer_csvExport_typeSites.
  ///
  /// In en, this message translates to:
  /// **'Sites'**
  String get transfer_csvExport_typeSites;

  /// No description provided for @transfer_detail_backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back to transfer'**
  String get transfer_detail_backTooltip;

  /// No description provided for @transfer_export_aboutContent.
  ///
  /// In en, this message translates to:
  /// **'Export your dive data in various formats. PDF creates a printable logbook. UDDF is a universal format compatible with most dive logging software. CSV files can be opened in spreadsheet applications.'**
  String get transfer_export_aboutContent;

  /// No description provided for @transfer_export_aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Export'**
  String get transfer_export_aboutTitle;

  /// No description provided for @transfer_export_completed.
  ///
  /// In en, this message translates to:
  /// **'Export completed'**
  String get transfer_export_completed;

  /// No description provided for @transfer_export_csvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet format'**
  String get transfer_export_csvSubtitle;

  /// No description provided for @transfer_export_csvTitle.
  ///
  /// In en, this message translates to:
  /// **'CSV Export'**
  String get transfer_export_csvTitle;

  /// No description provided for @transfer_export_excelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All data in one file (dives, sites, equipment, stats)'**
  String get transfer_export_excelSubtitle;

  /// No description provided for @transfer_export_excelTitle.
  ///
  /// In en, this message translates to:
  /// **'Excel Workbook'**
  String get transfer_export_excelTitle;

  /// No description provided for @transfer_export_failed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String transfer_export_failed(Object error);

  /// No description provided for @transfer_export_kmlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View dive sites on a 3D globe'**
  String get transfer_export_kmlSubtitle;

  /// No description provided for @transfer_export_kmlTitle.
  ///
  /// In en, this message translates to:
  /// **'Google Earth KML'**
  String get transfer_export_kmlTitle;

  /// No description provided for @transfer_export_multiFormatHeader.
  ///
  /// In en, this message translates to:
  /// **'Multi-Format Export'**
  String get transfer_export_multiFormatHeader;

  /// No description provided for @transfer_export_optionSaveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose where to save on your device'**
  String get transfer_export_optionSaveSubtitle;

  /// No description provided for @transfer_export_optionSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save to File'**
  String get transfer_export_optionSaveTitle;

  /// No description provided for @transfer_export_optionShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send via email, messages, or other apps'**
  String get transfer_export_optionShareSubtitle;

  /// No description provided for @transfer_export_optionShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get transfer_export_optionShareTitle;

  /// No description provided for @transfer_export_pdfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Printable dive logbook'**
  String get transfer_export_pdfSubtitle;

  /// No description provided for @transfer_export_pdfTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF Logbook'**
  String get transfer_export_pdfTitle;

  /// No description provided for @transfer_export_progressExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get transfer_export_progressExporting;

  /// No description provided for @transfer_export_sectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get transfer_export_sectionHeader;

  /// No description provided for @transfer_export_uddfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Universal Dive Data Format'**
  String get transfer_export_uddfSubtitle;

  /// No description provided for @transfer_export_uddfTitle.
  ///
  /// In en, this message translates to:
  /// **'UDDF Export'**
  String get transfer_export_uddfTitle;

  /// No description provided for @transfer_import_aboutContent.
  ///
  /// In en, this message translates to:
  /// **'Use \"Import Data\" for the best experience -- it auto-detects your file format and source app. The individual format options below are also available for direct access.'**
  String get transfer_import_aboutContent;

  /// No description provided for @transfer_import_aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Import'**
  String get transfer_import_aboutTitle;

  /// No description provided for @transfer_import_autoDetectSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Import data with auto-detection'**
  String get transfer_import_autoDetectSemanticLabel;

  /// No description provided for @transfer_import_autoDetectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-detects CSV, UDDF, FIT, and more'**
  String get transfer_import_autoDetectSubtitle;

  /// No description provided for @transfer_import_autoDetectTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get transfer_import_autoDetectTitle;

  /// No description provided for @transfer_import_byFormatHeader.
  ///
  /// In en, this message translates to:
  /// **'Import by Format'**
  String get transfer_import_byFormatHeader;

  /// No description provided for @transfer_import_csvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import dives from CSV file'**
  String get transfer_import_csvSubtitle;

  /// No description provided for @transfer_import_csvTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from CSV'**
  String get transfer_import_csvTitle;

  /// No description provided for @transfer_import_fitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import dives from Garmin Descent export files'**
  String get transfer_import_fitSubtitle;

  /// No description provided for @transfer_import_fitTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from FIT File'**
  String get transfer_import_fitTitle;

  /// No description provided for @transfer_import_operationCompleted.
  ///
  /// In en, this message translates to:
  /// **'Operation completed'**
  String get transfer_import_operationCompleted;

  /// No description provided for @transfer_import_operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String transfer_import_operationFailed(Object error);

  /// No description provided for @transfer_import_sectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get transfer_import_sectionHeader;

  /// No description provided for @transfer_import_uddfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Universal Dive Data Format'**
  String get transfer_import_uddfSubtitle;

  /// No description provided for @transfer_import_uddfTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from UDDF'**
  String get transfer_import_uddfTitle;

  /// No description provided for @transfer_pdfExport_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get transfer_pdfExport_cancelButton;

  /// No description provided for @transfer_pdfExport_dialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export PDF Logbook'**
  String get transfer_pdfExport_dialogTitle;

  /// No description provided for @transfer_pdfExport_exportButton.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get transfer_pdfExport_exportButton;

  /// No description provided for @transfer_pdfExport_includeCertCards.
  ///
  /// In en, this message translates to:
  /// **'Include Certification Cards'**
  String get transfer_pdfExport_includeCertCards;

  /// No description provided for @transfer_pdfExport_includeCertCardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add scanned certification card images to the PDF'**
  String get transfer_pdfExport_includeCertCardsSubtitle;

  /// No description provided for @transfer_pdfExport_pageSizeA4.
  ///
  /// In en, this message translates to:
  /// **'A4'**
  String get transfer_pdfExport_pageSizeA4;

  /// No description provided for @transfer_pdfExport_pageSizeA4Desc.
  ///
  /// In en, this message translates to:
  /// **'210 x 297 mm'**
  String get transfer_pdfExport_pageSizeA4Desc;

  /// No description provided for @transfer_pdfExport_pageSizeHeader.
  ///
  /// In en, this message translates to:
  /// **'Page Size'**
  String get transfer_pdfExport_pageSizeHeader;

  /// No description provided for @transfer_pdfExport_pageSizeLetter.
  ///
  /// In en, this message translates to:
  /// **'Letter'**
  String get transfer_pdfExport_pageSizeLetter;

  /// No description provided for @transfer_pdfExport_pageSizeLetterDesc.
  ///
  /// In en, this message translates to:
  /// **'8.5 x 11 in'**
  String get transfer_pdfExport_pageSizeLetterDesc;

  /// No description provided for @transfer_pdfExport_templateDetailed.
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get transfer_pdfExport_templateDetailed;

  /// No description provided for @transfer_pdfExport_templateDetailedDesc.
  ///
  /// In en, this message translates to:
  /// **'Full dive information with notes and ratings'**
  String get transfer_pdfExport_templateDetailedDesc;

  /// No description provided for @transfer_pdfExport_templateHeader.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get transfer_pdfExport_templateHeader;

  /// No description provided for @transfer_pdfExport_templateNauiStyle.
  ///
  /// In en, this message translates to:
  /// **'NAUI Style'**
  String get transfer_pdfExport_templateNauiStyle;

  /// No description provided for @transfer_pdfExport_templateNauiStyleDesc.
  ///
  /// In en, this message translates to:
  /// **'Layout matching NAUI logbook format'**
  String get transfer_pdfExport_templateNauiStyleDesc;

  /// No description provided for @transfer_pdfExport_templatePadiStyle.
  ///
  /// In en, this message translates to:
  /// **'PADI Style'**
  String get transfer_pdfExport_templatePadiStyle;

  /// No description provided for @transfer_pdfExport_templatePadiStyleDesc.
  ///
  /// In en, this message translates to:
  /// **'Layout matching PADI logbook format'**
  String get transfer_pdfExport_templatePadiStyleDesc;

  /// No description provided for @transfer_pdfExport_templateProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get transfer_pdfExport_templateProfessional;

  /// No description provided for @transfer_pdfExport_templateProfessionalDesc.
  ///
  /// In en, this message translates to:
  /// **'Signature and stamp areas for verification'**
  String get transfer_pdfExport_templateProfessionalDesc;

  /// No description provided for @transfer_pdfExport_templateSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Select {templateName} template'**
  String transfer_pdfExport_templateSemanticLabel(Object templateName);

  /// No description provided for @transfer_pdfExport_templateSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get transfer_pdfExport_templateSimple;

  /// No description provided for @transfer_pdfExport_templateSimpleDesc.
  ///
  /// In en, this message translates to:
  /// **'Compact table format, many dives per page'**
  String get transfer_pdfExport_templateSimpleDesc;

  /// No description provided for @transfer_section_computersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download from device'**
  String get transfer_section_computersSubtitle;

  /// No description provided for @transfer_section_computersTitle.
  ///
  /// In en, this message translates to:
  /// **'Dive Computers'**
  String get transfer_section_computersTitle;

  /// No description provided for @transfer_section_exportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'CSV, UDDF, PDF logbook'**
  String get transfer_section_exportSubtitle;

  /// No description provided for @transfer_section_exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get transfer_section_exportTitle;

  /// No description provided for @transfer_section_importSubtitle.
  ///
  /// In en, this message translates to:
  /// **'CSV, UDDF files'**
  String get transfer_section_importSubtitle;

  /// No description provided for @transfer_section_importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get transfer_section_importTitle;

  /// No description provided for @transfer_summary_description.
  ///
  /// In en, this message translates to:
  /// **'Import and export dive data'**
  String get transfer_summary_description;

  /// No description provided for @transfer_summary_selectSection.
  ///
  /// In en, this message translates to:
  /// **'Select a section from the list'**
  String get transfer_summary_selectSection;

  /// No description provided for @transfer_summary_title.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer_summary_title;

  /// No description provided for @transfer_unknownSection.
  ///
  /// In en, this message translates to:
  /// **'Unknown section: {sectionId}'**
  String transfer_unknownSection(Object sectionId);

  /// No description provided for @trips_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get trips_appBar_title;

  /// No description provided for @trips_appBar_tripPhotos.
  ///
  /// In en, this message translates to:
  /// **'Trip Photos'**
  String get trips_appBar_tripPhotos;

  /// No description provided for @trips_detail_action_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get trips_detail_action_delete;

  /// No description provided for @trips_detail_action_export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get trips_detail_action_export;

  /// No description provided for @trips_detail_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get trips_detail_appBar_title;

  /// No description provided for @trips_detail_dialog_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get trips_detail_dialog_cancel;

  /// No description provided for @trips_detail_dialog_deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get trips_detail_dialog_deleteConfirm;

  /// No description provided for @trips_detail_dialog_deleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This will remove the trip but keep the dives.'**
  String trips_detail_dialog_deleteContent(Object name);

  /// No description provided for @trips_detail_dialog_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Trip?'**
  String get trips_detail_dialog_deleteTitle;

  /// No description provided for @trips_detail_dives_empty.
  ///
  /// In en, this message translates to:
  /// **'No dives in this trip yet'**
  String get trips_detail_dives_empty;

  /// No description provided for @trips_detail_dives_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Unable to load dives'**
  String get trips_detail_dives_errorLoading;

  /// No description provided for @trips_detail_dives_unknownSite.
  ///
  /// In en, this message translates to:
  /// **'Unknown Site'**
  String get trips_detail_dives_unknownSite;

  /// No description provided for @trips_detail_dives_viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All ({count})'**
  String trips_detail_dives_viewAll(Object count);

  /// No description provided for @trips_detail_durationDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String trips_detail_durationDays(Object days);

  /// No description provided for @trips_detail_export_csv_comingSoon.
  ///
  /// In en, this message translates to:
  /// **'CSV export coming soon'**
  String get trips_detail_export_csv_comingSoon;

  /// No description provided for @trips_detail_export_csv_subtitle.
  ///
  /// In en, this message translates to:
  /// **'All dives in this trip'**
  String get trips_detail_export_csv_subtitle;

  /// No description provided for @trips_detail_export_csv_title.
  ///
  /// In en, this message translates to:
  /// **'Export to CSV'**
  String get trips_detail_export_csv_title;

  /// No description provided for @trips_detail_export_pdf_comingSoon.
  ///
  /// In en, this message translates to:
  /// **'PDF export coming soon'**
  String get trips_detail_export_pdf_comingSoon;

  /// No description provided for @trips_detail_export_pdf_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Trip summary with dive details'**
  String get trips_detail_export_pdf_subtitle;

  /// No description provided for @trips_detail_export_pdf_title.
  ///
  /// In en, this message translates to:
  /// **'Export to PDF'**
  String get trips_detail_export_pdf_title;

  /// No description provided for @trips_detail_label_liveaboard.
  ///
  /// In en, this message translates to:
  /// **'Liveaboard'**
  String get trips_detail_label_liveaboard;

  /// No description provided for @trips_detail_label_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get trips_detail_label_location;

  /// No description provided for @trips_detail_label_resort.
  ///
  /// In en, this message translates to:
  /// **'Resort'**
  String get trips_detail_label_resort;

  /// No description provided for @trips_detail_scan_accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Photo library access denied'**
  String get trips_detail_scan_accessDenied;

  /// No description provided for @trips_detail_scan_addDivesFirst.
  ///
  /// In en, this message translates to:
  /// **'Add dives first to link photos'**
  String get trips_detail_scan_addDivesFirst;

  /// No description provided for @trips_detail_scan_errorLinking.
  ///
  /// In en, this message translates to:
  /// **'Error linking photos: {error}'**
  String trips_detail_scan_errorLinking(Object error);

  /// No description provided for @trips_detail_scan_errorScanning.
  ///
  /// In en, this message translates to:
  /// **'Error scanning: {error}'**
  String trips_detail_scan_errorScanning(Object error);

  /// No description provided for @trips_detail_scan_linkedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Linked {count} photos'**
  String trips_detail_scan_linkedPhotos(Object count);

  /// No description provided for @trips_detail_scan_linkingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Linking photos...'**
  String get trips_detail_scan_linkingPhotos;

  /// No description provided for @trips_detail_sectionTitle_details.
  ///
  /// In en, this message translates to:
  /// **'Trip Details'**
  String get trips_detail_sectionTitle_details;

  /// No description provided for @trips_detail_sectionTitle_dives.
  ///
  /// In en, this message translates to:
  /// **'Dives'**
  String get trips_detail_sectionTitle_dives;

  /// No description provided for @trips_detail_sectionTitle_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get trips_detail_sectionTitle_notes;

  /// No description provided for @trips_detail_sectionTitle_statistics.
  ///
  /// In en, this message translates to:
  /// **'Trip Statistics'**
  String get trips_detail_sectionTitle_statistics;

  /// No description provided for @trips_detail_snackBar_deleted.
  ///
  /// In en, this message translates to:
  /// **'Trip deleted'**
  String get trips_detail_snackBar_deleted;

  /// No description provided for @trips_detail_stat_avgDepth.
  ///
  /// In en, this message translates to:
  /// **'Avg Depth'**
  String get trips_detail_stat_avgDepth;

  /// No description provided for @trips_detail_stat_maxDepth.
  ///
  /// In en, this message translates to:
  /// **'Max Depth'**
  String get trips_detail_stat_maxDepth;

  /// No description provided for @trips_detail_stat_totalBottomTime.
  ///
  /// In en, this message translates to:
  /// **'Total Bottom Time'**
  String get trips_detail_stat_totalBottomTime;

  /// No description provided for @trips_detail_stat_totalDives.
  ///
  /// In en, this message translates to:
  /// **'Total Dives'**
  String get trips_detail_stat_totalDives;

  /// No description provided for @trips_detail_tooltip_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get trips_detail_tooltip_edit;

  /// No description provided for @trips_detail_tooltip_editShort.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get trips_detail_tooltip_editShort;

  /// No description provided for @trips_detail_tooltip_moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get trips_detail_tooltip_moreOptions;

  /// No description provided for @trips_detail_tooltip_viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on Map'**
  String get trips_detail_tooltip_viewOnMap;

  /// No description provided for @trips_edit_appBar_add.
  ///
  /// In en, this message translates to:
  /// **'Add Trip'**
  String get trips_edit_appBar_add;

  /// No description provided for @trips_edit_appBar_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit Trip'**
  String get trips_edit_appBar_edit;

  /// No description provided for @trips_edit_button_add.
  ///
  /// In en, this message translates to:
  /// **'Add Trip'**
  String get trips_edit_button_add;

  /// No description provided for @trips_edit_button_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get trips_edit_button_cancel;

  /// No description provided for @trips_edit_button_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get trips_edit_button_save;

  /// No description provided for @trips_edit_button_update.
  ///
  /// In en, this message translates to:
  /// **'Update Trip'**
  String get trips_edit_button_update;

  /// No description provided for @trips_edit_dialog_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get trips_edit_dialog_discard;

  /// No description provided for @trips_edit_dialog_discardContent.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to leave?'**
  String get trips_edit_dialog_discardContent;

  /// No description provided for @trips_edit_dialog_discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes?'**
  String get trips_edit_dialog_discardTitle;

  /// No description provided for @trips_edit_dialog_keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get trips_edit_dialog_keepEditing;

  /// No description provided for @trips_edit_durationDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String trips_edit_durationDays(Object days);

  /// No description provided for @trips_edit_hint_liveaboardName.
  ///
  /// In en, this message translates to:
  /// **'e.g., MY Blue Force One'**
  String get trips_edit_hint_liveaboardName;

  /// No description provided for @trips_edit_hint_location.
  ///
  /// In en, this message translates to:
  /// **'e.g., Egypt, Red Sea'**
  String get trips_edit_hint_location;

  /// No description provided for @trips_edit_hint_notes.
  ///
  /// In en, this message translates to:
  /// **'Any additional notes about this trip'**
  String get trips_edit_hint_notes;

  /// No description provided for @trips_edit_hint_resortName.
  ///
  /// In en, this message translates to:
  /// **'e.g., Marsa Shagra'**
  String get trips_edit_hint_resortName;

  /// No description provided for @trips_edit_hint_tripName.
  ///
  /// In en, this message translates to:
  /// **'e.g., Red Sea Safari 2024'**
  String get trips_edit_hint_tripName;

  /// No description provided for @trips_edit_label_endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get trips_edit_label_endDate;

  /// No description provided for @trips_edit_label_liveaboardName.
  ///
  /// In en, this message translates to:
  /// **'Liveaboard Name'**
  String get trips_edit_label_liveaboardName;

  /// No description provided for @trips_edit_label_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get trips_edit_label_location;

  /// No description provided for @trips_edit_label_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get trips_edit_label_notes;

  /// No description provided for @trips_edit_label_resortName.
  ///
  /// In en, this message translates to:
  /// **'Resort Name'**
  String get trips_edit_label_resortName;

  /// No description provided for @trips_edit_label_startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get trips_edit_label_startDate;

  /// No description provided for @trips_edit_label_tripName.
  ///
  /// In en, this message translates to:
  /// **'Trip Name *'**
  String get trips_edit_label_tripName;

  /// No description provided for @trips_edit_sectionTitle_dates.
  ///
  /// In en, this message translates to:
  /// **'Trip Dates'**
  String get trips_edit_sectionTitle_dates;

  /// No description provided for @trips_edit_sectionTitle_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get trips_edit_sectionTitle_location;

  /// No description provided for @trips_edit_sectionTitle_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get trips_edit_sectionTitle_notes;

  /// No description provided for @trips_edit_semanticLabel_save.
  ///
  /// In en, this message translates to:
  /// **'Save trip'**
  String get trips_edit_semanticLabel_save;

  /// No description provided for @trips_edit_snackBar_added.
  ///
  /// In en, this message translates to:
  /// **'Trip added successfully'**
  String get trips_edit_snackBar_added;

  /// No description provided for @trips_edit_snackBar_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading trip: {error}'**
  String trips_edit_snackBar_errorLoading(Object error);

  /// No description provided for @trips_edit_snackBar_errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving trip: {error}'**
  String trips_edit_snackBar_errorSaving(Object error);

  /// No description provided for @trips_edit_snackBar_updated.
  ///
  /// In en, this message translates to:
  /// **'Trip updated successfully'**
  String get trips_edit_snackBar_updated;

  /// No description provided for @trips_edit_validation_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a trip name'**
  String get trips_edit_validation_nameRequired;

  /// No description provided for @trips_gallery_accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Photo library access denied'**
  String get trips_gallery_accessDenied;

  /// No description provided for @trips_gallery_addDivesFirst.
  ///
  /// In en, this message translates to:
  /// **'Add dives first to link photos'**
  String get trips_gallery_addDivesFirst;

  /// No description provided for @trips_gallery_appBar_title.
  ///
  /// In en, this message translates to:
  /// **'Trip Photos'**
  String get trips_gallery_appBar_title;

  /// No description provided for @trips_gallery_diveSection_photoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{photo} other{photos}}'**
  String trips_gallery_diveSection_photoCount(int count);

  /// No description provided for @trips_gallery_diveSection_title.
  ///
  /// In en, this message translates to:
  /// **'Dive #{number} - {site}'**
  String trips_gallery_diveSection_title(Object number, Object site);

  /// No description provided for @trips_gallery_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the camera icon to scan your gallery'**
  String get trips_gallery_empty_subtitle;

  /// No description provided for @trips_gallery_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No photos in this trip'**
  String get trips_gallery_empty_title;

  /// No description provided for @trips_gallery_errorLinking.
  ///
  /// In en, this message translates to:
  /// **'Error linking photos: {error}'**
  String trips_gallery_errorLinking(Object error);

  /// No description provided for @trips_gallery_errorScanning.
  ///
  /// In en, this message translates to:
  /// **'Error scanning: {error}'**
  String trips_gallery_errorScanning(Object error);

  /// No description provided for @trips_gallery_error_loading.
  ///
  /// In en, this message translates to:
  /// **'Error loading photos: {error}'**
  String trips_gallery_error_loading(Object error);

  /// No description provided for @trips_gallery_linkedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Linked {count} photos'**
  String trips_gallery_linkedPhotos(Object count);

  /// No description provided for @trips_gallery_linkingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Linking photos...'**
  String get trips_gallery_linkingPhotos;

  /// No description provided for @trips_gallery_tooltip_scan.
  ///
  /// In en, this message translates to:
  /// **'Scan device gallery'**
  String get trips_gallery_tooltip_scan;

  /// No description provided for @trips_gallery_tripNotFound.
  ///
  /// In en, this message translates to:
  /// **'Trip not found'**
  String get trips_gallery_tripNotFound;

  /// No description provided for @trips_list_button_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get trips_list_button_retry;

  /// No description provided for @trips_list_empty_button.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Trip'**
  String get trips_list_empty_button;

  /// No description provided for @trips_list_empty_filtered_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting or clearing your filters'**
  String get trips_list_empty_filtered_subtitle;

  /// No description provided for @trips_list_empty_filtered_title.
  ///
  /// In en, this message translates to:
  /// **'No trips match your filters'**
  String get trips_list_empty_filtered_title;

  /// No description provided for @trips_list_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create trips to group your dives by destination'**
  String get trips_list_empty_subtitle;

  /// No description provided for @trips_list_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No trips added yet'**
  String get trips_list_empty_title;

  /// No description provided for @trips_list_error_loading.
  ///
  /// In en, this message translates to:
  /// **'Error loading trips: {error}'**
  String trips_list_error_loading(Object error);

  /// No description provided for @trips_list_fab_addTrip.
  ///
  /// In en, this message translates to:
  /// **'Add Trip'**
  String get trips_list_fab_addTrip;

  /// No description provided for @trips_list_filters_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get trips_list_filters_clearAll;

  /// No description provided for @trips_list_sort_title.
  ///
  /// In en, this message translates to:
  /// **'Sort Trips'**
  String get trips_list_sort_title;

  /// No description provided for @trips_list_tile_diveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} dives'**
  String trips_list_tile_diveCount(Object count);

  /// No description provided for @trips_list_tooltip_addTrip.
  ///
  /// In en, this message translates to:
  /// **'Add Trip'**
  String get trips_list_tooltip_addTrip;

  /// No description provided for @trips_list_tooltip_search.
  ///
  /// In en, this message translates to:
  /// **'Search trips'**
  String get trips_list_tooltip_search;

  /// No description provided for @trips_list_tooltip_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get trips_list_tooltip_sort;

  /// No description provided for @trips_photos_empty_scanButton.
  ///
  /// In en, this message translates to:
  /// **'Scan device gallery'**
  String get trips_photos_empty_scanButton;

  /// No description provided for @trips_photos_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get trips_photos_empty_title;

  /// No description provided for @trips_photos_error_loading.
  ///
  /// In en, this message translates to:
  /// **'Error loading photos'**
  String get trips_photos_error_loading;

  /// No description provided for @trips_photos_moreIndicator.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String trips_photos_moreIndicator(Object count);

  /// No description provided for @trips_photos_moreIndicator_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} more photos'**
  String trips_photos_moreIndicator_semanticLabel(Object count);

  /// No description provided for @trips_photos_sectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get trips_photos_sectionTitle;

  /// No description provided for @trips_photos_tooltip_scan.
  ///
  /// In en, this message translates to:
  /// **'Scan device gallery'**
  String get trips_photos_tooltip_scan;

  /// No description provided for @trips_photos_viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get trips_photos_viewAll;

  /// No description provided for @trips_picker_clearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get trips_picker_clearTooltip;

  /// No description provided for @trips_picker_empty_createButton.
  ///
  /// In en, this message translates to:
  /// **'Create Trip'**
  String get trips_picker_empty_createButton;

  /// No description provided for @trips_picker_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get trips_picker_empty_title;

  /// No description provided for @trips_picker_error.
  ///
  /// In en, this message translates to:
  /// **'Error loading trips: {error}'**
  String trips_picker_error(Object error);

  /// No description provided for @trips_picker_hint.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a trip'**
  String get trips_picker_hint;

  /// No description provided for @trips_picker_newTrip.
  ///
  /// In en, this message translates to:
  /// **'New Trip'**
  String get trips_picker_newTrip;

  /// No description provided for @trips_picker_noSelection.
  ///
  /// In en, this message translates to:
  /// **'No trip selected'**
  String get trips_picker_noSelection;

  /// No description provided for @trips_picker_sheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Trip'**
  String get trips_picker_sheetTitle;

  /// No description provided for @trips_picker_suggestedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Suggested: {name}'**
  String trips_picker_suggestedPrefix(Object name);

  /// No description provided for @trips_picker_suggestedUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get trips_picker_suggestedUse;

  /// No description provided for @trips_search_empty_hint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, location, or resort'**
  String get trips_search_empty_hint;

  /// No description provided for @trips_search_fieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Search trips...'**
  String get trips_search_fieldLabel;

  /// No description provided for @trips_search_noResults.
  ///
  /// In en, this message translates to:
  /// **'No trips found for \"{query}\"'**
  String trips_search_noResults(Object query);

  /// No description provided for @trips_search_tooltip_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get trips_search_tooltip_back;

  /// No description provided for @trips_search_tooltip_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get trips_search_tooltip_clear;

  /// No description provided for @trips_summary_header_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a trip from the list to view details'**
  String get trips_summary_header_subtitle;

  /// No description provided for @trips_summary_header_title.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get trips_summary_header_title;

  /// No description provided for @trips_summary_overview_title.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get trips_summary_overview_title;

  /// No description provided for @trips_summary_quickActions_add.
  ///
  /// In en, this message translates to:
  /// **'Add Trip'**
  String get trips_summary_quickActions_add;

  /// No description provided for @trips_summary_quickActions_title.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get trips_summary_quickActions_title;

  /// No description provided for @trips_summary_recentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{date} • {count} dives'**
  String trips_summary_recentSubtitle(Object date, Object count);

  /// No description provided for @trips_summary_recentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Trips'**
  String get trips_summary_recentTitle;

  /// No description provided for @trips_summary_stat_daysDiving.
  ///
  /// In en, this message translates to:
  /// **'Days Diving'**
  String get trips_summary_stat_daysDiving;

  /// No description provided for @trips_summary_stat_liveaboards.
  ///
  /// In en, this message translates to:
  /// **'Liveaboards'**
  String get trips_summary_stat_liveaboards;

  /// No description provided for @trips_summary_stat_totalDives.
  ///
  /// In en, this message translates to:
  /// **'Total Dives'**
  String get trips_summary_stat_totalDives;

  /// No description provided for @trips_summary_stat_totalTrips.
  ///
  /// In en, this message translates to:
  /// **'Total Trips'**
  String get trips_summary_stat_totalTrips;

  /// No description provided for @trips_summary_upcomingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{date} • In {days} days'**
  String trips_summary_upcomingSubtitle(Object date, Object days);

  /// No description provided for @trips_summary_upcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get trips_summary_upcomingTitle;

  /// Symbol for feet altitude unit
  ///
  /// In en, this message translates to:
  /// **'ft'**
  String get units_altitude_feet;

  /// Symbol for meters altitude unit
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get units_altitude_meters;

  /// Unit label for barometric pressure in bar
  ///
  /// In en, this message translates to:
  /// **'bar'**
  String get units_barometric_bar;

  /// Unit label for barometric pressure in millibar
  ///
  /// In en, this message translates to:
  /// **'mbar'**
  String get units_barometric_mbar;

  /// Display name for day-first abbreviated month date format
  ///
  /// In en, this message translates to:
  /// **'D MMM YYYY'**
  String get units_dateFormat_dMMMYYYY;

  /// Display name for day/month/year date format
  ///
  /// In en, this message translates to:
  /// **'DD/MM/YYYY'**
  String get units_dateFormat_ddmmyyyy;

  /// Display name for month/day/year date format
  ///
  /// In en, this message translates to:
  /// **'MM/DD/YYYY'**
  String get units_dateFormat_mmddyyyy;

  /// Display name for abbreviated month date format
  ///
  /// In en, this message translates to:
  /// **'MMM D, YYYY'**
  String get units_dateFormat_mmmDYYYY;

  /// Display name for ISO date format
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD'**
  String get units_dateFormat_yyyymmdd;

  /// Symbol for feet depth unit
  ///
  /// In en, this message translates to:
  /// **'ft'**
  String get units_depth_feet;

  /// Symbol for meters depth unit
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get units_depth_meters;

  /// Symbol for bar pressure unit
  ///
  /// In en, this message translates to:
  /// **'bar'**
  String get units_pressure_bar;

  /// Symbol for PSI pressure unit
  ///
  /// In en, this message translates to:
  /// **'psi'**
  String get units_pressure_psi;

  /// Unit for heart rate in beats per minute
  ///
  /// In en, this message translates to:
  /// **'bpm'**
  String get units_profileMetric_bpm;

  /// Unit for gas density in grams per liter
  ///
  /// In en, this message translates to:
  /// **'g/L'**
  String get units_profileMetric_gPerL;

  /// Unit for time in minutes
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get units_profileMetric_min;

  /// Percent unit symbol
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get units_profileMetric_percent;

  /// Symbol for SAC rate in liters per minute
  ///
  /// In en, this message translates to:
  /// **'L/min'**
  String get units_sac_litersPerMin;

  /// Symbol for SAC rate in pressure units per minute
  ///
  /// In en, this message translates to:
  /// **'pressure/min'**
  String get units_sac_pressurePerMin;

  /// Symbol for Celsius temperature unit
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get units_temperature_celsius;

  /// Symbol for Fahrenheit temperature unit
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get units_temperature_fahrenheit;

  /// Display name for 12-hour time format
  ///
  /// In en, this message translates to:
  /// **'12-hour'**
  String get units_timeFormat_twelveHour;

  /// Display name for 24-hour time format
  ///
  /// In en, this message translates to:
  /// **'24-hour'**
  String get units_timeFormat_twentyFourHour;

  /// Symbol for cubic feet volume unit
  ///
  /// In en, this message translates to:
  /// **'cuft'**
  String get units_volume_cubicFeet;

  /// Symbol for liters volume unit
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get units_volume_liters;

  /// Symbol for kilograms weight unit
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get units_weight_kilograms;

  /// Symbol for pounds weight unit
  ///
  /// In en, this message translates to:
  /// **'lbs'**
  String get units_weight_pounds;

  /// Label for the continue button in the import wizard
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get universalImport_action_continue;

  /// Button label to deselect all items in a tab
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get universalImport_action_deselectAll;

  /// Button label to close the import wizard after completion
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get universalImport_action_done;

  /// Label for the import button in the review step
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get universalImport_action_import;

  /// Button label to select all items in a tab
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get universalImport_action_selectAll;

  /// Button label for the file picker button
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get universalImport_action_selectFile;

  /// Description text on the file selection step listing supported formats
  ///
  /// In en, this message translates to:
  /// **'Select a dive log file to import. Supported formats include CSV, UDDF, Subsurface XML, and Garmin FIT.'**
  String get universalImport_description_supportedFormats;

  /// Error message shown when the detected file format is not supported
  ///
  /// In en, this message translates to:
  /// **'This format is not yet supported. Please export as UDDF or CSV.'**
  String get universalImport_error_unsupportedFormat;

  /// Description text below the import tag label
  ///
  /// In en, this message translates to:
  /// **'Tag all imported dives for easy filtering'**
  String get universalImport_hint_tagDescription;

  /// Hint text placeholder for the batch tag text field
  ///
  /// In en, this message translates to:
  /// **'e.g., MacDive Import 2026-02-09'**
  String get universalImport_hint_tagExample;

  /// Title for the CSV column mapping step
  ///
  /// In en, this message translates to:
  /// **'Column Mapping'**
  String get universalImport_label_columnMapping;

  /// Subtitle showing how many CSV columns are mapped
  ///
  /// In en, this message translates to:
  /// **'{mapped} of {total} columns mapped'**
  String universalImport_label_columnsMapped(Object mapped, Object total);

  /// Button label shown while detecting the file format
  ///
  /// In en, this message translates to:
  /// **'Detecting...'**
  String get universalImport_label_detecting;

  /// Title for a dive card showing its number
  ///
  /// In en, this message translates to:
  /// **'Dive #{number}'**
  String universalImport_label_diveNumber(Object number);

  /// Badge label for a probable duplicate entity
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get universalImport_label_duplicate;

  /// Banner text indicating how many duplicates were found
  ///
  /// In en, this message translates to:
  /// **'{count} duplicates found and auto-deselected.'**
  String universalImport_label_duplicatesFound(Object count);

  /// Headline text shown on the import summary step
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get universalImport_label_importComplete;

  /// Label for the batch tag field in the import review step
  ///
  /// In en, this message translates to:
  /// **'Import Tag'**
  String get universalImport_label_importTag;

  /// Simple importing label when total count is unknown
  ///
  /// In en, this message translates to:
  /// **'Importing'**
  String get universalImport_label_importing;

  /// Headline text shown during import progress
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get universalImport_label_importingEllipsis;

  /// Progress label showing current import count
  ///
  /// In en, this message translates to:
  /// **'Importing {current} of {total}'**
  String universalImport_label_importingProgress(Object current, Object total);

  /// Label showing the duplicate match percentage
  ///
  /// In en, this message translates to:
  /// **'{percent}% match'**
  String universalImport_label_percentMatch(Object percent);

  /// Badge label for a possible duplicate entity
  ///
  /// In en, this message translates to:
  /// **'Possible match'**
  String get universalImport_label_possibleMatch;

  /// Label text above the source app override radio list
  ///
  /// In en, this message translates to:
  /// **'Not right? Select the correct source:'**
  String get universalImport_label_selectCorrectSource;

  /// Text showing how many items are selected
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String universalImport_label_selected(Object count);

  /// Label for skipping a column mapping in the field mapping step
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get universalImport_label_skip;

  /// Text showing the batch tag applied to imported items
  ///
  /// In en, this message translates to:
  /// **'Tagged as: {tag}'**
  String universalImport_label_taggedAs(Object tag);

  /// Fallback text when a dive has no date
  ///
  /// In en, this message translates to:
  /// **'Unknown date'**
  String get universalImport_label_unknownDate;

  /// Fallback name for an entity without a name
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get universalImport_label_unnamed;

  /// Counter text showing current of total items
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String universalImport_label_xOfY(Object current, Object total);

  /// Text showing how many items of a type are selected
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} selected'**
  String universalImport_label_xOfYSelected(Object selected, Object total);

  /// Accessibility label for entity type selection count
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} {entityType} selected'**
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  );

  /// Accessibility label for the import error message
  ///
  /// In en, this message translates to:
  /// **'Import error: {error}'**
  String universalImport_semantics_importError(Object error);

  /// Accessibility label for the import progress bar
  ///
  /// In en, this message translates to:
  /// **'Import progress: {percent} percent'**
  String universalImport_semantics_importProgress(Object percent);

  /// Accessibility label for the total selected items count
  ///
  /// In en, this message translates to:
  /// **'{count} items selected for import'**
  String universalImport_semantics_itemsSelected(Object count);

  /// Accessibility label for the possible duplicate badge
  ///
  /// In en, this message translates to:
  /// **'Possible duplicate'**
  String get universalImport_semantics_possibleDuplicate;

  /// Accessibility label for the probable duplicate badge
  ///
  /// In en, this message translates to:
  /// **'Probable duplicate'**
  String get universalImport_semantics_probableDuplicate;

  /// Accessibility label when the source app is detected with high confidence
  ///
  /// In en, this message translates to:
  /// **'Source detected: {description}'**
  String universalImport_semantics_sourceDetected(Object description);

  /// Accessibility label when the source app detection is uncertain
  ///
  /// In en, this message translates to:
  /// **'Source uncertain: {description}'**
  String universalImport_semantics_sourceUncertain(Object description);

  /// Accessibility label for toggling selection of an import entity
  ///
  /// In en, this message translates to:
  /// **'Toggle selection for {name}'**
  String universalImport_semantics_toggleSelection(Object name);

  /// Step indicator label for the import step
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get universalImport_step_import;

  /// Step indicator label for the field mapping step
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get universalImport_step_map;

  /// Step indicator label for the review step
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get universalImport_step_review;

  /// Step indicator label for the file selection step
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get universalImport_step_select;

  /// Title for the universal import wizard page and file selection heading
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get universalImport_title;

  /// Tooltip for the clear button in the batch tag text field
  ///
  /// In en, this message translates to:
  /// **'Clear tag'**
  String get universalImport_tooltip_clearTag;

  /// Tooltip for the close button on the import wizard app bar
  ///
  /// In en, this message translates to:
  /// **'Close import wizard'**
  String get universalImport_tooltip_closeWizard;

  /// Base weight line in calculation breakdown
  ///
  /// In en, this message translates to:
  /// **'Base ({suitType}): {weight} kg'**
  String weightCalc_baseLine(Object suitType, Object weight);

  /// Body weight adjustment line in calculation breakdown
  ///
  /// In en, this message translates to:
  /// **'Body weight adjustment: +{adjustment} kg'**
  String weightCalc_bodyWeightAdjustment(Object adjustment);

  /// No description provided for @weightCalc_suit_drysuit.
  ///
  /// In en, this message translates to:
  /// **'Drysuit'**
  String get weightCalc_suit_drysuit;

  /// No description provided for @weightCalc_suit_none.
  ///
  /// In en, this message translates to:
  /// **'No Suit'**
  String get weightCalc_suit_none;

  /// No description provided for @weightCalc_suit_rashguard.
  ///
  /// In en, this message translates to:
  /// **'Rashguard Only'**
  String get weightCalc_suit_rashguard;

  /// No description provided for @weightCalc_suit_semidry.
  ///
  /// In en, this message translates to:
  /// **'Semi-dry Suit'**
  String get weightCalc_suit_semidry;

  /// No description provided for @weightCalc_suit_shorty3mm.
  ///
  /// In en, this message translates to:
  /// **'3mm Shorty'**
  String get weightCalc_suit_shorty3mm;

  /// No description provided for @weightCalc_suit_wetsuit3mm.
  ///
  /// In en, this message translates to:
  /// **'3mm Full Wetsuit'**
  String get weightCalc_suit_wetsuit3mm;

  /// No description provided for @weightCalc_suit_wetsuit5mm.
  ///
  /// In en, this message translates to:
  /// **'5mm Wetsuit'**
  String get weightCalc_suit_wetsuit5mm;

  /// No description provided for @weightCalc_suit_wetsuit7mm.
  ///
  /// In en, this message translates to:
  /// **'7mm Wetsuit'**
  String get weightCalc_suit_wetsuit7mm;

  /// Tank adjustment line in calculation breakdown
  ///
  /// In en, this message translates to:
  /// **'Tank ({tankMaterial}): {adjustment} kg'**
  String weightCalc_tankLine(Object tankMaterial, Object adjustment);

  /// Title for the weight calculation breakdown
  ///
  /// In en, this message translates to:
  /// **'Weight Calculation:'**
  String get weightCalc_title;

  /// Total line in weight calculation breakdown
  ///
  /// In en, this message translates to:
  /// **'Total: {total} kg'**
  String weightCalc_total(Object total);

  /// Water type adjustment line in calculation breakdown
  ///
  /// In en, this message translates to:
  /// **'Water ({waterType}): {adjustment} kg'**
  String weightCalc_waterLine(Object waterType, Object adjustment);

  /// No description provided for @divePlanner_label_resultsWithWarnings.
  ///
  /// In en, this message translates to:
  /// **'Results, {count} warnings'**
  String divePlanner_label_resultsWithWarnings(Object count);

  /// No description provided for @tides_semantic_tideCycle.
  ///
  /// In en, this message translates to:
  /// **'Tide cycle, state: {state}, height: {height}'**
  String tides_semantic_tideCycle(Object state, Object height);

  /// Suffix shown after duration for past tides
  ///
  /// In en, this message translates to:
  /// **'ago'**
  String get tides_label_agoSuffix;

  /// Suffix shown after duration for future tides
  ///
  /// In en, this message translates to:
  /// **'from now'**
  String get tides_label_fromNowSuffix;

  /// No description provided for @certifications_card_issued.
  ///
  /// In en, this message translates to:
  /// **'ISSUED'**
  String get certifications_card_issued;

  /// No description provided for @certifications_certificate_cardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number: {number}'**
  String certifications_certificate_cardNumber(Object number);

  /// No description provided for @certifications_certificate_footer.
  ///
  /// In en, this message translates to:
  /// **'Official Scuba Diving Certification'**
  String get certifications_certificate_footer;

  /// No description provided for @certifications_certificate_hasCompletedTraining.
  ///
  /// In en, this message translates to:
  /// **'has completed training as'**
  String get certifications_certificate_hasCompletedTraining;

  /// No description provided for @certifications_certificate_instructor.
  ///
  /// In en, this message translates to:
  /// **'Instructor: {name}'**
  String certifications_certificate_instructor(Object name);

  /// No description provided for @certifications_certificate_issued.
  ///
  /// In en, this message translates to:
  /// **'Issued: {date}'**
  String certifications_certificate_issued(Object date);

  /// No description provided for @certifications_certificate_thisCertifies.
  ///
  /// In en, this message translates to:
  /// **'This certifies that'**
  String get certifications_certificate_thisCertifies;

  /// No description provided for @diveComputer_discovery_chooseDifferentDevice.
  ///
  /// In en, this message translates to:
  /// **'Choose Different Device'**
  String get diveComputer_discovery_chooseDifferentDevice;

  /// No description provided for @diveComputer_discovery_computer.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get diveComputer_discovery_computer;

  /// No description provided for @diveComputer_discovery_connectAndDownload.
  ///
  /// In en, this message translates to:
  /// **'Connect & Download'**
  String get diveComputer_discovery_connectAndDownload;

  /// No description provided for @diveComputer_discovery_connectingToDevice.
  ///
  /// In en, this message translates to:
  /// **'Connecting to device...'**
  String get diveComputer_discovery_connectingToDevice;

  /// No description provided for @diveComputer_discovery_deviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., My {model}'**
  String diveComputer_discovery_deviceNameHint(Object model);

  /// No description provided for @diveComputer_discovery_deviceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get diveComputer_discovery_deviceNameLabel;

  /// No description provided for @diveComputer_discovery_exitDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diveComputer_discovery_exitDialogCancel;

  /// No description provided for @diveComputer_discovery_exitDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get diveComputer_discovery_exitDialogConfirm;

  /// No description provided for @diveComputer_discovery_exitDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit? Your progress will be lost.'**
  String get diveComputer_discovery_exitDialogContent;

  /// No description provided for @diveComputer_discovery_exitDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit Setup?'**
  String get diveComputer_discovery_exitDialogTitle;

  /// No description provided for @diveComputer_discovery_exitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Exit setup'**
  String get diveComputer_discovery_exitTooltip;

  /// No description provided for @diveComputer_discovery_noDeviceSelected.
  ///
  /// In en, this message translates to:
  /// **'No device selected'**
  String get diveComputer_discovery_noDeviceSelected;

  /// No description provided for @diveComputer_discovery_pleaseWaitConnection.
  ///
  /// In en, this message translates to:
  /// **'Please wait while we establish a connection'**
  String get diveComputer_discovery_pleaseWaitConnection;

  /// No description provided for @diveComputer_discovery_recognizedDevice.
  ///
  /// In en, this message translates to:
  /// **'Recognized Device'**
  String get diveComputer_discovery_recognizedDevice;

  /// No description provided for @diveComputer_discovery_recognizedDeviceDescription.
  ///
  /// In en, this message translates to:
  /// **'This device is in our supported devices library. Dive download should work automatically.'**
  String get diveComputer_discovery_recognizedDeviceDescription;

  /// No description provided for @diveComputer_discovery_stepConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get diveComputer_discovery_stepConnect;

  /// No description provided for @diveComputer_discovery_stepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get diveComputer_discovery_stepDone;

  /// No description provided for @diveComputer_discovery_stepDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get diveComputer_discovery_stepDownload;

  /// No description provided for @diveComputer_discovery_stepScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get diveComputer_discovery_stepScan;

  /// No description provided for @diveComputer_discovery_titleComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get diveComputer_discovery_titleComplete;

  /// No description provided for @diveComputer_discovery_titleConfirmDevice.
  ///
  /// In en, this message translates to:
  /// **'Confirm Device'**
  String get diveComputer_discovery_titleConfirmDevice;

  /// No description provided for @diveComputer_discovery_titleConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get diveComputer_discovery_titleConnecting;

  /// No description provided for @diveComputer_discovery_titleDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get diveComputer_discovery_titleDownloading;

  /// No description provided for @diveComputer_discovery_titleFindDevice.
  ///
  /// In en, this message translates to:
  /// **'Find Device'**
  String get diveComputer_discovery_titleFindDevice;

  /// No description provided for @diveComputer_discovery_unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get diveComputer_discovery_unknownDevice;

  /// No description provided for @diveComputer_discovery_unknownDeviceDescription.
  ///
  /// In en, this message translates to:
  /// **'This device is not in our library. We\'ll try to connect, but download may not work.'**
  String get diveComputer_discovery_unknownDeviceDescription;

  /// No description provided for @diveComputer_downloadStep_andMoreDives.
  ///
  /// In en, this message translates to:
  /// **'... and {count} more'**
  String diveComputer_downloadStep_andMoreDives(Object count);

  /// No description provided for @diveComputer_downloadStep_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diveComputer_downloadStep_cancel;

  /// No description provided for @diveComputer_downloadStep_depthMeters.
  ///
  /// In en, this message translates to:
  /// **'{depth}m'**
  String diveComputer_downloadStep_depthMeters(Object depth);

  /// No description provided for @diveComputer_downloadStep_downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get diveComputer_downloadStep_downloadFailed;

  /// No description provided for @diveComputer_downloadStep_downloadedDives.
  ///
  /// In en, this message translates to:
  /// **'Downloaded Dives'**
  String get diveComputer_downloadStep_downloadedDives;

  /// No description provided for @diveComputer_downloadStep_durationMin.
  ///
  /// In en, this message translates to:
  /// **'{duration} min'**
  String diveComputer_downloadStep_durationMin(Object duration);

  /// No description provided for @diveComputer_downloadStep_errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get diveComputer_downloadStep_errorOccurred;

  /// No description provided for @diveComputer_downloadStep_errorSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Download error: {error}'**
  String diveComputer_downloadStep_errorSemanticLabel(Object error);

  /// No description provided for @diveComputer_downloadStep_percentAccessibility.
  ///
  /// In en, this message translates to:
  /// **', {percent} percent'**
  String diveComputer_downloadStep_percentAccessibility(Object percent);

  /// No description provided for @diveComputer_downloadStep_preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get diveComputer_downloadStep_preparing;

  /// No description provided for @diveComputer_downloadStep_progressPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String diveComputer_downloadStep_progressPercent(Object percent);

  /// No description provided for @diveComputer_downloadStep_progressSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Download progress: {status}{percent}'**
  String diveComputer_downloadStep_progressSemanticLabel(
    Object status,
    Object percent,
  );

  /// No description provided for @diveComputer_downloadStep_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get diveComputer_downloadStep_retry;

  /// No description provided for @diveComputer_download_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diveComputer_download_cancel;

  /// No description provided for @diveComputer_download_closeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get diveComputer_download_closeTooltip;

  /// No description provided for @diveComputer_download_computerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Computer not found'**
  String get diveComputer_download_computerNotFound;

  /// No description provided for @diveComputer_download_depthMeters.
  ///
  /// In en, this message translates to:
  /// **'{depth}m'**
  String diveComputer_download_depthMeters(Object depth);

  /// No description provided for @diveComputer_download_deviceNotFoundError.
  ///
  /// In en, this message translates to:
  /// **'Device not found. Make sure your {name} is nearby and in transfer mode.'**
  String diveComputer_download_deviceNotFoundError(Object name);

  /// No description provided for @diveComputer_download_deviceNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Not Found'**
  String get diveComputer_download_deviceNotFoundTitle;

  /// No description provided for @diveComputer_download_divesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Dives updated'**
  String get diveComputer_download_divesUpdated;

  /// No description provided for @diveComputer_download_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get diveComputer_download_done;

  /// No description provided for @diveComputer_download_downloadedDives.
  ///
  /// In en, this message translates to:
  /// **'Downloaded Dives'**
  String get diveComputer_download_downloadedDives;

  /// No description provided for @diveComputer_download_duplicatesSkipped.
  ///
  /// In en, this message translates to:
  /// **'Duplicates skipped'**
  String get diveComputer_download_duplicatesSkipped;

  /// No description provided for @diveComputer_download_durationMin.
  ///
  /// In en, this message translates to:
  /// **'{duration} min'**
  String diveComputer_download_durationMin(Object duration);

  /// No description provided for @diveComputer_download_errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get diveComputer_download_errorOccurred;

  /// No description provided for @diveComputer_download_errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String diveComputer_download_errorWithMessage(Object error);

  /// No description provided for @diveComputer_download_goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get diveComputer_download_goBack;

  /// No description provided for @diveComputer_download_importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get diveComputer_download_importFailed;

  /// No description provided for @diveComputer_download_importResults.
  ///
  /// In en, this message translates to:
  /// **'Import Results'**
  String get diveComputer_download_importResults;

  /// No description provided for @diveComputer_download_importedDives.
  ///
  /// In en, this message translates to:
  /// **'Imported Dives'**
  String get diveComputer_download_importedDives;

  /// No description provided for @diveComputer_download_newDivesImported.
  ///
  /// In en, this message translates to:
  /// **'New dives imported'**
  String get diveComputer_download_newDivesImported;

  /// No description provided for @diveComputer_download_preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get diveComputer_download_preparing;

  /// No description provided for @diveComputer_download_progressPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String diveComputer_download_progressPercent(Object percent);

  /// No description provided for @diveComputer_download_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get diveComputer_download_retry;

  /// No description provided for @diveComputer_download_scanError.
  ///
  /// In en, this message translates to:
  /// **'Scan error: {error}'**
  String diveComputer_download_scanError(Object error);

  /// No description provided for @diveComputer_download_searchingForDevice.
  ///
  /// In en, this message translates to:
  /// **'Searching for {name}...'**
  String diveComputer_download_searchingForDevice(Object name);

  /// No description provided for @diveComputer_download_searchingInstructions.
  ///
  /// In en, this message translates to:
  /// **'Make sure the device is nearby and in transfer mode'**
  String get diveComputer_download_searchingInstructions;

  /// No description provided for @diveComputer_download_title.
  ///
  /// In en, this message translates to:
  /// **'Download Dives'**
  String get diveComputer_download_title;

  /// No description provided for @diveComputer_download_tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get diveComputer_download_tryAgain;

  /// No description provided for @diveComputer_list_addComputer.
  ///
  /// In en, this message translates to:
  /// **'Add Computer'**
  String get diveComputer_list_addComputer;

  /// No description provided for @diveComputer_list_cardSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Dive computer: {name}'**
  String diveComputer_list_cardSemanticLabel(Object name);

  /// No description provided for @diveComputer_list_diveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} dives'**
  String diveComputer_list_diveCount(Object count);

  /// No description provided for @diveComputer_list_downloadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download dives'**
  String get diveComputer_list_downloadTooltip;

  /// No description provided for @diveComputer_list_emptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect your dive computer to download dives directly into the app.'**
  String get diveComputer_list_emptyMessage;

  /// No description provided for @diveComputer_list_emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Dive Computers'**
  String get diveComputer_list_emptyTitle;

  /// No description provided for @diveComputer_list_findComputers.
  ///
  /// In en, this message translates to:
  /// **'Find Computers'**
  String get diveComputer_list_findComputers;

  /// No description provided for @diveComputer_list_helpBluetooth.
  ///
  /// In en, this message translates to:
  /// **'• Bluetooth LE (most modern computers)'**
  String get diveComputer_list_helpBluetooth;

  /// No description provided for @diveComputer_list_helpBluetoothClassic.
  ///
  /// In en, this message translates to:
  /// **'• Bluetooth Classic (older models)'**
  String get diveComputer_list_helpBluetoothClassic;

  /// No description provided for @diveComputer_list_helpBrandsList.
  ///
  /// In en, this message translates to:
  /// **'Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi, and 50+ more models.'**
  String get diveComputer_list_helpBrandsList;

  /// No description provided for @diveComputer_list_helpBrandsTitle.
  ///
  /// In en, this message translates to:
  /// **'Supported Brands'**
  String get diveComputer_list_helpBrandsTitle;

  /// No description provided for @diveComputer_list_helpConnectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Supported Connections'**
  String get diveComputer_list_helpConnectionsTitle;

  /// No description provided for @diveComputer_list_helpDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Dive Computer Help'**
  String get diveComputer_list_helpDialogTitle;

  /// No description provided for @diveComputer_list_helpDismiss.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get diveComputer_list_helpDismiss;

  /// No description provided for @diveComputer_list_helpTip1.
  ///
  /// In en, this message translates to:
  /// **'• Ensure your computer is in transfer mode'**
  String get diveComputer_list_helpTip1;

  /// No description provided for @diveComputer_list_helpTip2.
  ///
  /// In en, this message translates to:
  /// **'• Keep devices close during download'**
  String get diveComputer_list_helpTip2;

  /// No description provided for @diveComputer_list_helpTip3.
  ///
  /// In en, this message translates to:
  /// **'• Make sure Bluetooth is enabled'**
  String get diveComputer_list_helpTip3;

  /// No description provided for @diveComputer_list_helpTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get diveComputer_list_helpTipsTitle;

  /// No description provided for @diveComputer_list_helpTooltip.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get diveComputer_list_helpTooltip;

  /// No description provided for @diveComputer_list_helpUsb.
  ///
  /// In en, this message translates to:
  /// **'• USB (desktop only)'**
  String get diveComputer_list_helpUsb;

  /// No description provided for @diveComputer_list_loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load dive computers'**
  String get diveComputer_list_loadFailed;

  /// No description provided for @diveComputer_list_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get diveComputer_list_retry;

  /// No description provided for @diveComputer_list_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Computers'**
  String get diveComputer_list_title;

  /// No description provided for @diveComputer_summary_diveComputer.
  ///
  /// In en, this message translates to:
  /// **'dive computer'**
  String get diveComputer_summary_diveComputer;

  /// No description provided for @diveComputer_summary_divesDownloaded.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{dive} other{dives}} downloaded'**
  String diveComputer_summary_divesDownloaded(int count);

  /// No description provided for @diveComputer_summary_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get diveComputer_summary_done;

  /// No description provided for @diveComputer_summary_imported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get diveComputer_summary_imported;

  /// No description provided for @diveComputer_summary_semanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{dive} other{dives}} downloaded from {name}'**
  String diveComputer_summary_semanticLabel(int count, Object name);

  /// No description provided for @diveComputer_summary_skippedDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Skipped (duplicates)'**
  String get diveComputer_summary_skippedDuplicates;

  /// No description provided for @diveComputer_summary_title.
  ///
  /// In en, this message translates to:
  /// **'Download Complete!'**
  String get diveComputer_summary_title;

  /// No description provided for @diveComputer_summary_updated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get diveComputer_summary_updated;

  /// No description provided for @diveComputer_summary_viewDives.
  ///
  /// In en, this message translates to:
  /// **'View Dives'**
  String get diveComputer_summary_viewDives;

  /// No description provided for @diveImport_alreadyImported.
  ///
  /// In en, this message translates to:
  /// **'Already imported'**
  String get diveImport_alreadyImported;

  /// No description provided for @diveImport_avgHR.
  ///
  /// In en, this message translates to:
  /// **'Avg HR'**
  String get diveImport_avgHR;

  /// No description provided for @diveImport_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get diveImport_back;

  /// No description provided for @diveImport_deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get diveImport_deselectAll;

  /// No description provided for @diveImport_divesImported.
  ///
  /// In en, this message translates to:
  /// **'Dives imported'**
  String get diveImport_divesImported;

  /// No description provided for @diveImport_divesMerged.
  ///
  /// In en, this message translates to:
  /// **'Dives merged'**
  String get diveImport_divesMerged;

  /// No description provided for @diveImport_divesSkipped.
  ///
  /// In en, this message translates to:
  /// **'Dives skipped'**
  String get diveImport_divesSkipped;

  /// No description provided for @diveImport_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get diveImport_done;

  /// No description provided for @diveImport_duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get diveImport_duration;

  /// No description provided for @diveImport_error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get diveImport_error;

  /// No description provided for @diveImport_fit_closeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close FIT import'**
  String get diveImport_fit_closeTooltip;

  /// No description provided for @diveImport_fit_noDivesDescription.
  ///
  /// In en, this message translates to:
  /// **'Select one or more .fit files exported from Garmin Connect or copied from a Garmin Descent device.'**
  String get diveImport_fit_noDivesDescription;

  /// No description provided for @diveImport_fit_noDivesLoaded.
  ///
  /// In en, this message translates to:
  /// **'No Dives Loaded'**
  String get diveImport_fit_noDivesLoaded;

  /// No description provided for @diveImport_fit_parsed.
  ///
  /// In en, this message translates to:
  /// **'Parsed {diveCount} {diveCount, plural, =1{dive} other{dives}} from {fileCount} {fileCount, plural, =1{file} other{files}}'**
  String diveImport_fit_parsed(int diveCount, int fileCount);

  /// No description provided for @diveImport_fit_parsedWithSkipped.
  ///
  /// In en, this message translates to:
  /// **'Parsed {diveCount} {diveCount, plural, =1{dive} other{dives}} from {fileCount} {fileCount, plural, =1{file} other{files}} ({skippedCount} skipped)'**
  String diveImport_fit_parsedWithSkipped(
    int diveCount,
    int fileCount,
    Object skippedCount,
  );

  /// No description provided for @diveImport_fit_parsing.
  ///
  /// In en, this message translates to:
  /// **'Parsing...'**
  String get diveImport_fit_parsing;

  /// No description provided for @diveImport_fit_selectFiles.
  ///
  /// In en, this message translates to:
  /// **'Select FIT Files'**
  String get diveImport_fit_selectFiles;

  /// No description provided for @diveImport_fit_title.
  ///
  /// In en, this message translates to:
  /// **'Import from FIT File'**
  String get diveImport_fit_title;

  /// No description provided for @diveImport_healthkit_accessDescription.
  ///
  /// In en, this message translates to:
  /// **'Submersion needs access to your Apple Watch dive data to import dives.'**
  String get diveImport_healthkit_accessDescription;

  /// No description provided for @diveImport_healthkit_accessRequired.
  ///
  /// In en, this message translates to:
  /// **'HealthKit Access Required'**
  String get diveImport_healthkit_accessRequired;

  /// No description provided for @diveImport_healthkit_closeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close Apple Watch import'**
  String get diveImport_healthkit_closeTooltip;

  /// No description provided for @diveImport_healthkit_dateFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get diveImport_healthkit_dateFrom;

  /// No description provided for @diveImport_healthkit_dateSelectorLabel.
  ///
  /// In en, this message translates to:
  /// **'{label} date selector'**
  String diveImport_healthkit_dateSelectorLabel(Object label);

  /// No description provided for @diveImport_healthkit_dateTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get diveImport_healthkit_dateTo;

  /// No description provided for @diveImport_healthkit_fetchDives.
  ///
  /// In en, this message translates to:
  /// **'Fetch Dives'**
  String get diveImport_healthkit_fetchDives;

  /// No description provided for @diveImport_healthkit_fetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching...'**
  String get diveImport_healthkit_fetching;

  /// No description provided for @diveImport_healthkit_grantAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant Access'**
  String get diveImport_healthkit_grantAccess;

  /// No description provided for @diveImport_healthkit_noDivesFound.
  ///
  /// In en, this message translates to:
  /// **'No Dives Found'**
  String get diveImport_healthkit_noDivesFound;

  /// No description provided for @diveImport_healthkit_noDivesFoundDescription.
  ///
  /// In en, this message translates to:
  /// **'No underwater diving activities found in the selected date range.'**
  String get diveImport_healthkit_noDivesFoundDescription;

  /// No description provided for @diveImport_healthkit_notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not Available'**
  String get diveImport_healthkit_notAvailable;

  /// No description provided for @diveImport_healthkit_notAvailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Apple Watch import is only available on iOS and macOS devices.'**
  String get diveImport_healthkit_notAvailableDescription;

  /// No description provided for @diveImport_healthkit_permissionCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to check permissions'**
  String get diveImport_healthkit_permissionCheckFailed;

  /// No description provided for @diveImport_healthkit_title.
  ///
  /// In en, this message translates to:
  /// **'Import from Apple Watch'**
  String get diveImport_healthkit_title;

  /// No description provided for @diveImport_healthkit_watchTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from Watch'**
  String get diveImport_healthkit_watchTitle;

  /// No description provided for @diveImport_import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get diveImport_import;

  /// No description provided for @diveImport_importComplete.
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get diveImport_importComplete;

  /// No description provided for @diveImport_likelyDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Likely duplicate'**
  String get diveImport_likelyDuplicate;

  /// No description provided for @diveImport_maxDepth.
  ///
  /// In en, this message translates to:
  /// **'Max Depth'**
  String get diveImport_maxDepth;

  /// No description provided for @diveImport_newDive.
  ///
  /// In en, this message translates to:
  /// **'New dive'**
  String get diveImport_newDive;

  /// No description provided for @diveImport_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get diveImport_next;

  /// No description provided for @diveImport_possibleDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicate'**
  String get diveImport_possibleDuplicate;

  /// No description provided for @diveImport_reviewSelectedDives.
  ///
  /// In en, this message translates to:
  /// **'Review Selected Dives'**
  String get diveImport_reviewSelectedDives;

  /// No description provided for @diveImport_reviewSummary.
  ///
  /// In en, this message translates to:
  /// **'{newCount} new{possibleCount, plural, =0{} other{, {possibleCount} possible duplicates}}{skipCount, plural, =0{} other{, {skipCount} will be skipped}}'**
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  );

  /// No description provided for @diveImport_selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get diveImport_selectAll;

  /// No description provided for @diveImport_selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String diveImport_selectedCount(Object count);

  /// No description provided for @diveImport_sourceGarmin.
  ///
  /// In en, this message translates to:
  /// **'Garmin'**
  String get diveImport_sourceGarmin;

  /// No description provided for @diveImport_sourceSuunto.
  ///
  /// In en, this message translates to:
  /// **'Suunto'**
  String get diveImport_sourceSuunto;

  /// No description provided for @diveImport_sourceUDDF.
  ///
  /// In en, this message translates to:
  /// **'UDDF'**
  String get diveImport_sourceUDDF;

  /// No description provided for @diveImport_sourceWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get diveImport_sourceWatch;

  /// No description provided for @diveImport_step_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get diveImport_step_done;

  /// No description provided for @diveImport_step_review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get diveImport_step_review;

  /// No description provided for @diveImport_step_select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get diveImport_step_select;

  /// No description provided for @diveImport_temp.
  ///
  /// In en, this message translates to:
  /// **'Temp'**
  String get diveImport_temp;

  /// No description provided for @diveImport_toggleDiveSelection.
  ///
  /// In en, this message translates to:
  /// **'Toggle selection for dive'**
  String get diveImport_toggleDiveSelection;

  /// No description provided for @diveImport_uddf_buddies.
  ///
  /// In en, this message translates to:
  /// **'Buddies'**
  String get diveImport_uddf_buddies;

  /// No description provided for @diveImport_uddf_certifications.
  ///
  /// In en, this message translates to:
  /// **'Certifications'**
  String get diveImport_uddf_certifications;

  /// No description provided for @diveImport_uddf_closeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close UDDF import'**
  String get diveImport_uddf_closeTooltip;

  /// No description provided for @diveImport_uddf_diveCenters.
  ///
  /// In en, this message translates to:
  /// **'Dive Centers'**
  String get diveImport_uddf_diveCenters;

  /// No description provided for @diveImport_uddf_diveTypes.
  ///
  /// In en, this message translates to:
  /// **'Dive Types'**
  String get diveImport_uddf_diveTypes;

  /// No description provided for @diveImport_uddf_dives.
  ///
  /// In en, this message translates to:
  /// **'Dives'**
  String get diveImport_uddf_dives;

  /// No description provided for @diveImport_uddf_duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get diveImport_uddf_duplicate;

  /// No description provided for @diveImport_uddf_duplicatesFound.
  ///
  /// In en, this message translates to:
  /// **'{count} duplicates found and auto-deselected.'**
  String diveImport_uddf_duplicatesFound(Object count);

  /// No description provided for @diveImport_uddf_equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get diveImport_uddf_equipment;

  /// No description provided for @diveImport_uddf_equipmentSets.
  ///
  /// In en, this message translates to:
  /// **'Equipment Sets'**
  String get diveImport_uddf_equipmentSets;

  /// No description provided for @diveImport_uddf_importProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String diveImport_uddf_importProgress(Object current, Object total);

  /// No description provided for @diveImport_uddf_importing.
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get diveImport_uddf_importing;

  /// No description provided for @diveImport_uddf_likelyDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Likely duplicate'**
  String get diveImport_uddf_likelyDuplicate;

  /// No description provided for @diveImport_uddf_noFileDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a .uddf or .xml file exported from another dive log application.'**
  String get diveImport_uddf_noFileDescription;

  /// No description provided for @diveImport_uddf_noFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No File Selected'**
  String get diveImport_uddf_noFileSelected;

  /// No description provided for @diveImport_uddf_parsing.
  ///
  /// In en, this message translates to:
  /// **'Parsing...'**
  String get diveImport_uddf_parsing;

  /// No description provided for @diveImport_uddf_possibleDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicate'**
  String get diveImport_uddf_possibleDuplicate;

  /// No description provided for @diveImport_uddf_selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select UDDF File'**
  String get diveImport_uddf_selectFile;

  /// No description provided for @diveImport_uddf_selectedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} selected'**
  String diveImport_uddf_selectedOfTotal(Object selected, Object total);

  /// No description provided for @diveImport_uddf_sites.
  ///
  /// In en, this message translates to:
  /// **'Sites'**
  String get diveImport_uddf_sites;

  /// No description provided for @diveImport_uddf_stepImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get diveImport_uddf_stepImport;

  /// No description provided for @diveImport_uddf_tabBuddies.
  ///
  /// In en, this message translates to:
  /// **'Buddies'**
  String get diveImport_uddf_tabBuddies;

  /// No description provided for @diveImport_uddf_tabCenters.
  ///
  /// In en, this message translates to:
  /// **'Centers'**
  String get diveImport_uddf_tabCenters;

  /// No description provided for @diveImport_uddf_tabCerts.
  ///
  /// In en, this message translates to:
  /// **'Certs'**
  String get diveImport_uddf_tabCerts;

  /// No description provided for @diveImport_uddf_tabCourses.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get diveImport_uddf_tabCourses;

  /// No description provided for @diveImport_uddf_tabDives.
  ///
  /// In en, this message translates to:
  /// **'Dives'**
  String get diveImport_uddf_tabDives;

  /// No description provided for @diveImport_uddf_tabEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get diveImport_uddf_tabEquipment;

  /// No description provided for @diveImport_uddf_tabSets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get diveImport_uddf_tabSets;

  /// No description provided for @diveImport_uddf_tabSites.
  ///
  /// In en, this message translates to:
  /// **'Sites'**
  String get diveImport_uddf_tabSites;

  /// No description provided for @diveImport_uddf_tabTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get diveImport_uddf_tabTags;

  /// No description provided for @diveImport_uddf_tabTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get diveImport_uddf_tabTrips;

  /// No description provided for @diveImport_uddf_tabTypes.
  ///
  /// In en, this message translates to:
  /// **'Types'**
  String get diveImport_uddf_tabTypes;

  /// No description provided for @diveImport_uddf_tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get diveImport_uddf_tags;

  /// No description provided for @diveImport_uddf_title.
  ///
  /// In en, this message translates to:
  /// **'Import from UDDF'**
  String get diveImport_uddf_title;

  /// No description provided for @diveImport_uddf_toggleDiveSelection.
  ///
  /// In en, this message translates to:
  /// **'Toggle selection for dive'**
  String get diveImport_uddf_toggleDiveSelection;

  /// No description provided for @diveImport_uddf_toggleEntitySelection.
  ///
  /// In en, this message translates to:
  /// **'Toggle selection for {name}'**
  String diveImport_uddf_toggleEntitySelection(Object name);

  /// No description provided for @diveImport_uddf_trips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get diveImport_uddf_trips;

  /// No description provided for @divePlanner_segmentEditor_addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Segment'**
  String get divePlanner_segmentEditor_addTitle;

  /// No description provided for @divePlanner_segmentEditor_ascentRate.
  ///
  /// In en, this message translates to:
  /// **'Ascent Rate ({unit}/min)'**
  String divePlanner_segmentEditor_ascentRate(Object unit);

  /// No description provided for @divePlanner_segmentEditor_descentRate.
  ///
  /// In en, this message translates to:
  /// **'Descent Rate ({unit}/min)'**
  String divePlanner_segmentEditor_descentRate(Object unit);

  /// No description provided for @divePlanner_segmentEditor_duration.
  ///
  /// In en, this message translates to:
  /// **'Duration (min)'**
  String get divePlanner_segmentEditor_duration;

  /// No description provided for @divePlanner_segmentEditor_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Segment'**
  String get divePlanner_segmentEditor_editTitle;

  /// No description provided for @divePlanner_segmentEditor_endDepth.
  ///
  /// In en, this message translates to:
  /// **'End Depth ({unit})'**
  String divePlanner_segmentEditor_endDepth(Object unit);

  /// No description provided for @divePlanner_segmentEditor_gasSwitchTime.
  ///
  /// In en, this message translates to:
  /// **'Gas switch time'**
  String get divePlanner_segmentEditor_gasSwitchTime;

  /// No description provided for @divePlanner_segmentEditor_segmentType.
  ///
  /// In en, this message translates to:
  /// **'Segment Type'**
  String get divePlanner_segmentEditor_segmentType;

  /// No description provided for @divePlanner_segmentEditor_startDepth.
  ///
  /// In en, this message translates to:
  /// **'Start Depth ({unit})'**
  String divePlanner_segmentEditor_startDepth(Object unit);

  /// No description provided for @divePlanner_segmentEditor_tankGas.
  ///
  /// In en, this message translates to:
  /// **'Tank / Gas'**
  String get divePlanner_segmentEditor_tankGas;

  /// No description provided for @divePlanner_segmentList_addSegment.
  ///
  /// In en, this message translates to:
  /// **'Add Segment'**
  String get divePlanner_segmentList_addSegment;

  /// No description provided for @divePlanner_segmentList_ascent.
  ///
  /// In en, this message translates to:
  /// **'Ascent {startDepth} → {endDepth}'**
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth);

  /// No description provided for @divePlanner_segmentList_bottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom {depth} for {minutes} min'**
  String divePlanner_segmentList_bottom(Object depth, Object minutes);

  /// No description provided for @divePlanner_segmentList_deco.
  ///
  /// In en, this message translates to:
  /// **'Deco {depth} for {minutes} min'**
  String divePlanner_segmentList_deco(Object depth, Object minutes);

  /// No description provided for @divePlanner_segmentList_deleteSegment.
  ///
  /// In en, this message translates to:
  /// **'Delete segment'**
  String get divePlanner_segmentList_deleteSegment;

  /// No description provided for @divePlanner_segmentList_descent.
  ///
  /// In en, this message translates to:
  /// **'Descent {startDepth} → {endDepth}'**
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth);

  /// No description provided for @divePlanner_segmentList_editSegment.
  ///
  /// In en, this message translates to:
  /// **'Edit segment'**
  String get divePlanner_segmentList_editSegment;

  /// No description provided for @divePlanner_segmentList_emptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add segments manually or create a quick plan'**
  String get divePlanner_segmentList_emptyMessage;

  /// No description provided for @divePlanner_segmentList_emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No segments yet'**
  String get divePlanner_segmentList_emptyTitle;

  /// No description provided for @divePlanner_segmentList_gasSwitch.
  ///
  /// In en, this message translates to:
  /// **'Gas switch to {gasName}'**
  String divePlanner_segmentList_gasSwitch(Object gasName);

  /// No description provided for @divePlanner_segmentList_quickPlan.
  ///
  /// In en, this message translates to:
  /// **'Quick Plan'**
  String get divePlanner_segmentList_quickPlan;

  /// No description provided for @divePlanner_segmentList_safetyStop.
  ///
  /// In en, this message translates to:
  /// **'Safety stop {depth} for {minutes} min'**
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes);

  /// No description provided for @divePlanner_segmentList_title.
  ///
  /// In en, this message translates to:
  /// **'Dive Segments'**
  String get divePlanner_segmentList_title;

  /// No description provided for @divePlanner_segmentType_ascent.
  ///
  /// In en, this message translates to:
  /// **'Ascent'**
  String get divePlanner_segmentType_ascent;

  /// No description provided for @divePlanner_segmentType_bottomTime.
  ///
  /// In en, this message translates to:
  /// **'Bottom Time'**
  String get divePlanner_segmentType_bottomTime;

  /// No description provided for @divePlanner_segmentType_decoStop.
  ///
  /// In en, this message translates to:
  /// **'Deco Stop'**
  String get divePlanner_segmentType_decoStop;

  /// No description provided for @divePlanner_segmentType_descent.
  ///
  /// In en, this message translates to:
  /// **'Descent'**
  String get divePlanner_segmentType_descent;

  /// No description provided for @divePlanner_segmentType_gasSwitch.
  ///
  /// In en, this message translates to:
  /// **'Gas Switch'**
  String get divePlanner_segmentType_gasSwitch;

  /// No description provided for @divePlanner_segmentType_safetyStop.
  ///
  /// In en, this message translates to:
  /// **'Safety Stop'**
  String get divePlanner_segmentType_safetyStop;

  /// No description provided for @gasCalculators_rockBottom_aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Rock bottom is the minimum gas reserve for an emergency ascent while sharing air with your buddy.\n\n• Uses stressed SAC rates (2-3x normal)\n• Assumes both divers on one tank\n• Includes safety stop when enabled\n\nAlways turn the dive BEFORE reaching rock bottom!'**
  String get gasCalculators_rockBottom_aboutDescription;

  /// No description provided for @gasCalculators_rockBottom_aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Rock Bottom'**
  String get gasCalculators_rockBottom_aboutTitle;

  /// No description provided for @gasCalculators_rockBottom_ascentGasRequired.
  ///
  /// In en, this message translates to:
  /// **'Ascent gas required'**
  String get gasCalculators_rockBottom_ascentGasRequired;

  /// No description provided for @gasCalculators_rockBottom_ascentRate.
  ///
  /// In en, this message translates to:
  /// **'Ascent Rate'**
  String get gasCalculators_rockBottom_ascentRate;

  /// No description provided for @gasCalculators_rockBottom_ascentTimeToDepth.
  ///
  /// In en, this message translates to:
  /// **'Ascent time to {depth}{unit}'**
  String gasCalculators_rockBottom_ascentTimeToDepth(Object depth, Object unit);

  /// No description provided for @gasCalculators_rockBottom_ascentTimeToSurface.
  ///
  /// In en, this message translates to:
  /// **'Ascent time to surface'**
  String get gasCalculators_rockBottom_ascentTimeToSurface;

  /// No description provided for @gasCalculators_rockBottom_buddySac.
  ///
  /// In en, this message translates to:
  /// **'Buddy SAC'**
  String get gasCalculators_rockBottom_buddySac;

  /// No description provided for @gasCalculators_rockBottom_combinedStressedSac.
  ///
  /// In en, this message translates to:
  /// **'Combined stressed SAC'**
  String get gasCalculators_rockBottom_combinedStressedSac;

  /// No description provided for @gasCalculators_rockBottom_emergencyAscentBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Emergency Ascent Breakdown'**
  String get gasCalculators_rockBottom_emergencyAscentBreakdown;

  /// No description provided for @gasCalculators_rockBottom_emergencyScenario.
  ///
  /// In en, this message translates to:
  /// **'Emergency Scenario'**
  String get gasCalculators_rockBottom_emergencyScenario;

  /// No description provided for @gasCalculators_rockBottom_includeSafetyStop.
  ///
  /// In en, this message translates to:
  /// **'Include Safety Stop'**
  String get gasCalculators_rockBottom_includeSafetyStop;

  /// No description provided for @gasCalculators_rockBottom_maximumDepth.
  ///
  /// In en, this message translates to:
  /// **'Maximum Depth'**
  String get gasCalculators_rockBottom_maximumDepth;

  /// No description provided for @gasCalculators_rockBottom_minimumReserve.
  ///
  /// In en, this message translates to:
  /// **'Minimum Reserve'**
  String get gasCalculators_rockBottom_minimumReserve;

  /// No description provided for @gasCalculators_rockBottom_resultSemantics.
  ///
  /// In en, this message translates to:
  /// **'Minimum reserve: {pressure} {pressureUnit}, {volume} {volumeUnit}. Turn the dive when reaching {pressure} {pressureUnit} remaining'**
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  );

  /// No description provided for @gasCalculators_rockBottom_safetyStopDuration.
  ///
  /// In en, this message translates to:
  /// **'3 minutes at {depth}{unit}'**
  String gasCalculators_rockBottom_safetyStopDuration(
    Object depth,
    Object unit,
  );

  /// No description provided for @gasCalculators_rockBottom_safetyStopGas.
  ///
  /// In en, this message translates to:
  /// **'Safety stop gas (3 min @ {depth}{unit})'**
  String gasCalculators_rockBottom_safetyStopGas(Object depth, Object unit);

  /// No description provided for @gasCalculators_rockBottom_stressedSacHint.
  ///
  /// In en, this message translates to:
  /// **'Use higher SAC rates to account for stress during emergency'**
  String get gasCalculators_rockBottom_stressedSacHint;

  /// No description provided for @gasCalculators_rockBottom_stressedSacRates.
  ///
  /// In en, this message translates to:
  /// **'Stressed SAC Rates'**
  String get gasCalculators_rockBottom_stressedSacRates;

  /// No description provided for @gasCalculators_rockBottom_tankSize.
  ///
  /// In en, this message translates to:
  /// **'Tank Size'**
  String get gasCalculators_rockBottom_tankSize;

  /// No description provided for @gasCalculators_rockBottom_totalReserveNeeded.
  ///
  /// In en, this message translates to:
  /// **'Total reserve needed'**
  String get gasCalculators_rockBottom_totalReserveNeeded;

  /// No description provided for @gasCalculators_rockBottom_turnDive.
  ///
  /// In en, this message translates to:
  /// **'Turn the dive when reaching {pressure} {pressureUnit} remaining'**
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  );

  /// No description provided for @gasCalculators_rockBottom_yourSac.
  ///
  /// In en, this message translates to:
  /// **'Your SAC'**
  String get gasCalculators_rockBottom_yourSac;

  /// No description provided for @maps_heatMap_hide.
  ///
  /// In en, this message translates to:
  /// **'Hide Heat Map'**
  String get maps_heatMap_hide;

  /// No description provided for @maps_heatMap_overlayOff.
  ///
  /// In en, this message translates to:
  /// **'Heat map overlay is off'**
  String get maps_heatMap_overlayOff;

  /// No description provided for @maps_heatMap_overlayOn.
  ///
  /// In en, this message translates to:
  /// **'Heat map overlay is on'**
  String get maps_heatMap_overlayOn;

  /// No description provided for @maps_heatMap_show.
  ///
  /// In en, this message translates to:
  /// **'Show Heat Map'**
  String get maps_heatMap_show;

  /// No description provided for @maps_offline_bounds.
  ///
  /// In en, this message translates to:
  /// **'Bounds'**
  String get maps_offline_bounds;

  /// No description provided for @maps_offline_cacheHitRateAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Cache hit rate: {rate} percent'**
  String maps_offline_cacheHitRateAccessibility(Object rate);

  /// No description provided for @maps_offline_cacheHits.
  ///
  /// In en, this message translates to:
  /// **'Cache Hits'**
  String get maps_offline_cacheHits;

  /// No description provided for @maps_offline_cacheMisses.
  ///
  /// In en, this message translates to:
  /// **'Cache Misses'**
  String get maps_offline_cacheMisses;

  /// No description provided for @maps_offline_cacheStatistics.
  ///
  /// In en, this message translates to:
  /// **'Cache Statistics'**
  String get maps_offline_cacheStatistics;

  /// No description provided for @maps_offline_cancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel Download'**
  String get maps_offline_cancelDownload;

  /// No description provided for @maps_offline_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get maps_offline_clearAll;

  /// No description provided for @maps_offline_clearAllCache.
  ///
  /// In en, this message translates to:
  /// **'Clear All Cache'**
  String get maps_offline_clearAllCache;

  /// No description provided for @maps_offline_clearAllCacheMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete all downloaded map regions and cached tiles?'**
  String get maps_offline_clearAllCacheMessage;

  /// No description provided for @maps_offline_clearAllCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Cache?'**
  String get maps_offline_clearAllCacheTitle;

  /// No description provided for @maps_offline_clearCacheStats.
  ///
  /// In en, this message translates to:
  /// **'This will delete {count} tiles ({size}).'**
  String maps_offline_clearCacheStats(Object count, Object size);

  /// No description provided for @maps_offline_created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get maps_offline_created;

  /// No description provided for @maps_offline_deleteRegion.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} region'**
  String maps_offline_deleteRegion(Object name);

  /// No description provided for @maps_offline_deleteRegionMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" and its {count} cached tiles?\n\nThis will free up {size} of storage.'**
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  );

  /// No description provided for @maps_offline_deleteRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Region?'**
  String get maps_offline_deleteRegionTitle;

  /// No description provided for @maps_offline_downloadedRegions.
  ///
  /// In en, this message translates to:
  /// **'Downloaded Regions'**
  String get maps_offline_downloadedRegions;

  /// No description provided for @maps_offline_downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading: {regionName}'**
  String maps_offline_downloading(Object regionName);

  /// No description provided for @maps_offline_downloadingAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Downloading {regionName}, {percent} percent complete, {downloaded} of {total} tiles'**
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  );

  /// No description provided for @maps_offline_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String maps_offline_error(Object error);

  /// No description provided for @maps_offline_errorLoadingStats.
  ///
  /// In en, this message translates to:
  /// **'Error loading stats: {error}'**
  String maps_offline_errorLoadingStats(Object error);

  /// No description provided for @maps_offline_failedTiles.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String maps_offline_failedTiles(Object count);

  /// No description provided for @maps_offline_hitRate.
  ///
  /// In en, this message translates to:
  /// **'Hit Rate: {rate}%'**
  String maps_offline_hitRate(Object rate);

  /// No description provided for @maps_offline_lastAccessed.
  ///
  /// In en, this message translates to:
  /// **'Last Accessed'**
  String get maps_offline_lastAccessed;

  /// No description provided for @maps_offline_noRegions.
  ///
  /// In en, this message translates to:
  /// **'No Offline Regions'**
  String get maps_offline_noRegions;

  /// No description provided for @maps_offline_noRegionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Download map regions from the site detail page to use maps while offline.'**
  String get maps_offline_noRegionsDescription;

  /// No description provided for @maps_offline_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get maps_offline_refresh;

  /// No description provided for @maps_offline_region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get maps_offline_region;

  /// No description provided for @maps_offline_regionInfo.
  ///
  /// In en, this message translates to:
  /// **'{size} | {count} tiles | Zoom {minZoom}-{maxZoom}'**
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  );

  /// No description provided for @maps_offline_regionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{size}, {count} tiles, zoom {minZoom} to {maxZoom}'**
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  );

  /// No description provided for @maps_offline_size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get maps_offline_size;

  /// No description provided for @maps_offline_tiles.
  ///
  /// In en, this message translates to:
  /// **'Tiles'**
  String get maps_offline_tiles;

  /// No description provided for @maps_offline_tilesPerSecond.
  ///
  /// In en, this message translates to:
  /// **'{rate} tiles/sec'**
  String maps_offline_tilesPerSecond(Object rate);

  /// No description provided for @maps_offline_tilesProgress.
  ///
  /// In en, this message translates to:
  /// **'{downloaded} / {total} tiles'**
  String maps_offline_tilesProgress(Object downloaded, Object total);

  /// No description provided for @maps_offline_title.
  ///
  /// In en, this message translates to:
  /// **'Offline Maps'**
  String get maps_offline_title;

  /// No description provided for @maps_offline_zoomRange.
  ///
  /// In en, this message translates to:
  /// **'Zoom Range'**
  String get maps_offline_zoomRange;

  /// No description provided for @maps_regionSelector_dragToAdjust.
  ///
  /// In en, this message translates to:
  /// **'Drag to adjust selection'**
  String get maps_regionSelector_dragToAdjust;

  /// No description provided for @maps_regionSelector_dragToSelect.
  ///
  /// In en, this message translates to:
  /// **'Drag on the map to select a region'**
  String get maps_regionSelector_dragToSelect;

  /// No description provided for @maps_regionSelector_selectRegion.
  ///
  /// In en, this message translates to:
  /// **'Select region on map'**
  String get maps_regionSelector_selectRegion;

  /// No description provided for @maps_regionSelector_selectRegionButton.
  ///
  /// In en, this message translates to:
  /// **'Select Region'**
  String get maps_regionSelector_selectRegionButton;

  /// No description provided for @tankPresets_addPreset.
  ///
  /// In en, this message translates to:
  /// **'Add tank preset'**
  String get tankPresets_addPreset;

  /// No description provided for @tankPresets_builtInPresets.
  ///
  /// In en, this message translates to:
  /// **'Built-in Presets'**
  String get tankPresets_builtInPresets;

  /// No description provided for @tankPresets_customPresets.
  ///
  /// In en, this message translates to:
  /// **'Custom Presets'**
  String get tankPresets_customPresets;

  /// No description provided for @tankPresets_deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String tankPresets_deleteMessage(Object name);

  /// No description provided for @tankPresets_deletePreset.
  ///
  /// In en, this message translates to:
  /// **'Delete preset'**
  String get tankPresets_deletePreset;

  /// No description provided for @tankPresets_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Tank Preset?'**
  String get tankPresets_deleteTitle;

  /// No description provided for @tankPresets_deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String tankPresets_deleted(Object name);

  /// No description provided for @tankPresets_editPreset.
  ///
  /// In en, this message translates to:
  /// **'Edit preset'**
  String get tankPresets_editPreset;

  /// No description provided for @tankPresets_edit_created.
  ///
  /// In en, this message translates to:
  /// **'Created \"{name}\"'**
  String tankPresets_edit_created(Object name);

  /// No description provided for @tankPresets_edit_descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., My rental tank from dive shop'**
  String get tankPresets_edit_descriptionHint;

  /// No description provided for @tankPresets_edit_descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get tankPresets_edit_descriptionOptional;

  /// No description provided for @tankPresets_edit_errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading preset: {error}'**
  String tankPresets_edit_errorLoading(Object error);

  /// No description provided for @tankPresets_edit_errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving preset: {error}'**
  String tankPresets_edit_errorSaving(Object error);

  /// No description provided for @tankPresets_edit_gasCapacity.
  ///
  /// In en, this message translates to:
  /// **'• Gas capacity: {capacity} cuft'**
  String tankPresets_edit_gasCapacity(Object capacity);

  /// No description provided for @tankPresets_edit_material.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get tankPresets_edit_material;

  /// No description provided for @tankPresets_edit_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get tankPresets_edit_name;

  /// No description provided for @tankPresets_edit_nameHelper.
  ///
  /// In en, this message translates to:
  /// **'A friendly name for this tank preset'**
  String get tankPresets_edit_nameHelper;

  /// No description provided for @tankPresets_edit_nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., My AL80'**
  String get tankPresets_edit_nameHint;

  /// No description provided for @tankPresets_edit_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get tankPresets_edit_nameRequired;

  /// No description provided for @tankPresets_edit_ratedPressure.
  ///
  /// In en, this message translates to:
  /// **'Rated pressure'**
  String get tankPresets_edit_ratedPressure;

  /// No description provided for @tankPresets_edit_required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get tankPresets_edit_required;

  /// No description provided for @tankPresets_edit_tankSpecifications.
  ///
  /// In en, this message translates to:
  /// **'Tank Specifications'**
  String get tankPresets_edit_tankSpecifications;

  /// No description provided for @tankPresets_edit_title.
  ///
  /// In en, this message translates to:
  /// **'Edit Tank Preset'**
  String get tankPresets_edit_title;

  /// No description provided for @tankPresets_edit_updated.
  ///
  /// In en, this message translates to:
  /// **'Updated \"{name}\"'**
  String tankPresets_edit_updated(Object name);

  /// No description provided for @tankPresets_edit_validPressure.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid pressure'**
  String get tankPresets_edit_validPressure;

  /// No description provided for @tankPresets_edit_validVolume.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid volume'**
  String get tankPresets_edit_validVolume;

  /// No description provided for @tankPresets_edit_volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get tankPresets_edit_volume;

  /// No description provided for @tankPresets_edit_volumeHelperCuft.
  ///
  /// In en, this message translates to:
  /// **'Gas capacity (cuft)'**
  String get tankPresets_edit_volumeHelperCuft;

  /// No description provided for @tankPresets_edit_volumeHelperLiters.
  ///
  /// In en, this message translates to:
  /// **'Water volume (L)'**
  String get tankPresets_edit_volumeHelperLiters;

  /// No description provided for @tankPresets_edit_waterVolume.
  ///
  /// In en, this message translates to:
  /// **'• Water volume: {volume} L'**
  String tankPresets_edit_waterVolume(Object volume);

  /// No description provided for @tankPresets_edit_workingPressure.
  ///
  /// In en, this message translates to:
  /// **'Working Pressure'**
  String get tankPresets_edit_workingPressure;

  /// No description provided for @tankPresets_edit_workingPressureBar.
  ///
  /// In en, this message translates to:
  /// **'• Working pressure: {pressure} bar'**
  String tankPresets_edit_workingPressureBar(Object pressure);

  /// No description provided for @tankPresets_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String tankPresets_error(Object error);

  /// No description provided for @tankPresets_errorDeleting.
  ///
  /// In en, this message translates to:
  /// **'Error deleting preset: {error}'**
  String tankPresets_errorDeleting(Object error);

  /// No description provided for @tankPresets_new_title.
  ///
  /// In en, this message translates to:
  /// **'New Tank Preset'**
  String get tankPresets_new_title;

  /// No description provided for @tankPresets_noPresets.
  ///
  /// In en, this message translates to:
  /// **'No tank presets available'**
  String get tankPresets_noPresets;

  /// No description provided for @tankPresets_title.
  ///
  /// In en, this message translates to:
  /// **'Tank Presets'**
  String get tankPresets_title;

  /// No description provided for @tools_deco_description.
  ///
  /// In en, this message translates to:
  /// **'Calculate no-decompression limits, required deco stops, and CNS/OTU exposure for multi-level dive profiles.'**
  String get tools_deco_description;

  /// No description provided for @tools_deco_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Plan dives with decompression stops'**
  String get tools_deco_subtitle;

  /// No description provided for @tools_deco_title.
  ///
  /// In en, this message translates to:
  /// **'Deco Calculator'**
  String get tools_deco_title;

  /// No description provided for @tools_disclaimer.
  ///
  /// In en, this message translates to:
  /// **'These calculators are for planning purposes only. Always verify calculations and follow your dive training.'**
  String get tools_disclaimer;

  /// No description provided for @tools_gas_description.
  ///
  /// In en, this message translates to:
  /// **'Four specialized gas calculators:\n• MOD - Maximum operating depth for a gas mix\n• Best Mix - Ideal O₂% for a target depth\n• Consumption - Gas usage estimation\n• Rock Bottom - Emergency reserve calculation'**
  String get tools_gas_description;

  /// No description provided for @tools_gas_subtitle.
  ///
  /// In en, this message translates to:
  /// **'MOD, Best Mix, Consumption, Rock Bottom'**
  String get tools_gas_subtitle;

  /// No description provided for @tools_gas_title.
  ///
  /// In en, this message translates to:
  /// **'Gas Calculators'**
  String get tools_gas_title;

  /// No description provided for @tools_title.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools_title;

  /// No description provided for @tools_weight_aluminumImperial.
  ///
  /// In en, this message translates to:
  /// **'More buoyant when empty (+4 lbs)'**
  String get tools_weight_aluminumImperial;

  /// No description provided for @tools_weight_aluminumMetric.
  ///
  /// In en, this message translates to:
  /// **'More buoyant when empty (+2 kg)'**
  String get tools_weight_aluminumMetric;

  /// No description provided for @tools_weight_bodyWeightOptional.
  ///
  /// In en, this message translates to:
  /// **'Body Weight (optional)'**
  String get tools_weight_bodyWeightOptional;

  /// No description provided for @tools_weight_carbonFiberImperial.
  ///
  /// In en, this message translates to:
  /// **'Very buoyant (+7 lbs)'**
  String get tools_weight_carbonFiberImperial;

  /// No description provided for @tools_weight_carbonFiberMetric.
  ///
  /// In en, this message translates to:
  /// **'Very buoyant (+3 kg)'**
  String get tools_weight_carbonFiberMetric;

  /// No description provided for @tools_weight_description.
  ///
  /// In en, this message translates to:
  /// **'Estimate the weight you need based on your exposure suit, tank material, water type, and body weight.'**
  String get tools_weight_description;

  /// No description provided for @tools_weight_disclaimer.
  ///
  /// In en, this message translates to:
  /// **'This is an estimate only. Always perform a buoyancy check at the start of your dive and adjust as needed. Factors like BCD, personal buoyancy, and breathing patterns will affect your actual weight requirements.'**
  String get tools_weight_disclaimer;

  /// No description provided for @tools_weight_exposureSuit.
  ///
  /// In en, this message translates to:
  /// **'Exposure Suit'**
  String get tools_weight_exposureSuit;

  /// No description provided for @tools_weight_gasCapacity.
  ///
  /// In en, this message translates to:
  /// **'• Gas capacity: {capacity} cuft'**
  String tools_weight_gasCapacity(Object capacity);

  /// No description provided for @tools_weight_helperImperial.
  ///
  /// In en, this message translates to:
  /// **'Adds ~2 lbs per 22 lbs over 154 lbs'**
  String get tools_weight_helperImperial;

  /// No description provided for @tools_weight_helperMetric.
  ///
  /// In en, this message translates to:
  /// **'Adds ~1 kg per 10 kg over 70 kg'**
  String get tools_weight_helperMetric;

  /// No description provided for @tools_weight_notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get tools_weight_notSpecified;

  /// No description provided for @tools_weight_recommendedWeight.
  ///
  /// In en, this message translates to:
  /// **'Recommended Weight'**
  String get tools_weight_recommendedWeight;

  /// No description provided for @tools_weight_resultAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Recommended weight: {weight} {unit}'**
  String tools_weight_resultAccessibility(Object weight, Object unit);

  /// No description provided for @tools_weight_steelImperial.
  ///
  /// In en, this message translates to:
  /// **'Negatively buoyant (-4 lbs)'**
  String get tools_weight_steelImperial;

  /// No description provided for @tools_weight_steelMetric.
  ///
  /// In en, this message translates to:
  /// **'Negatively buoyant (-2 kg)'**
  String get tools_weight_steelMetric;

  /// No description provided for @tools_weight_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended weight for your setup'**
  String get tools_weight_subtitle;

  /// No description provided for @tools_weight_tankMaterial.
  ///
  /// In en, this message translates to:
  /// **'Tank Material'**
  String get tools_weight_tankMaterial;

  /// No description provided for @tools_weight_tankSpecifications.
  ///
  /// In en, this message translates to:
  /// **'Tank Specifications'**
  String get tools_weight_tankSpecifications;

  /// No description provided for @tools_weight_title.
  ///
  /// In en, this message translates to:
  /// **'Weight Calculator'**
  String get tools_weight_title;

  /// No description provided for @tools_weight_waterType.
  ///
  /// In en, this message translates to:
  /// **'Water Type'**
  String get tools_weight_waterType;

  /// No description provided for @tools_weight_waterVolume.
  ///
  /// In en, this message translates to:
  /// **'• Water volume: {volume} L'**
  String tools_weight_waterVolume(Object volume);

  /// No description provided for @tools_weight_workingPressure.
  ///
  /// In en, this message translates to:
  /// **'• Working pressure: {pressure} bar'**
  String tools_weight_workingPressure(Object pressure);

  /// No description provided for @tools_weight_yourWeight.
  ///
  /// In en, this message translates to:
  /// **'Your weight'**
  String get tools_weight_yourWeight;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'he',
    'hu',
    'it',
    'nl',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'he':
      return AppLocalizationsHe();
    case 'hu':
      return AppLocalizationsHu();
    case 'it':
      return AppLocalizationsIt();
    case 'nl':
      return AppLocalizationsNl();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
