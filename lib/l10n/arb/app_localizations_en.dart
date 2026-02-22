// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get accessibility_dialog_keyboardShortcutsTitle =>
      'Keyboard Shortcuts';

  @override
  String get accessibility_keyLabel_backspace => 'Backspace';

  @override
  String get accessibility_keyLabel_delete => 'Delete';

  @override
  String get accessibility_keyLabel_down => 'Down';

  @override
  String get accessibility_keyLabel_enter => 'Enter';

  @override
  String get accessibility_keyLabel_esc => 'Esc';

  @override
  String get accessibility_keyLabel_left => 'Left';

  @override
  String get accessibility_keyLabel_right => 'Right';

  @override
  String get accessibility_keyLabel_up => 'Up';

  @override
  String accessibility_label_chartSummary(
    Object chartType,
    Object description,
  ) {
    return '$chartType chart. $description';
  }

  @override
  String get accessibility_label_createNewItem => 'Create new item';

  @override
  String get accessibility_label_hideList => 'Hide list';

  @override
  String get accessibility_label_hideMapView => 'Hide Map View';

  @override
  String accessibility_label_listPane(Object title) {
    return '$title list pane';
  }

  @override
  String accessibility_label_mapPane(Object title) {
    return '$title map pane';
  }

  @override
  String accessibility_label_mapViewTitle(Object title) {
    return '$title map view';
  }

  @override
  String get accessibility_label_showList => 'Show List';

  @override
  String get accessibility_label_showMapView => 'Show Map View';

  @override
  String get accessibility_label_viewDetails => 'View details';

  @override
  String get accessibility_modifierKey_alt => 'Alt+';

  @override
  String get accessibility_modifierKey_cmd => 'Cmd+';

  @override
  String get accessibility_modifierKey_ctrl => 'Ctrl+';

  @override
  String get accessibility_modifierKey_option => 'Option+';

  @override
  String get accessibility_modifierKey_shift => 'Shift+';

  @override
  String get accessibility_modifierKey_super => 'Super+';

  @override
  String get accessibility_shortcutCategory_editing => 'Editing';

  @override
  String get accessibility_shortcutCategory_general => 'General';

  @override
  String get accessibility_shortcutCategory_help => 'Help';

  @override
  String get accessibility_shortcutCategory_navigation => 'Navigation';

  @override
  String get accessibility_shortcutCategory_search => 'Search';

  @override
  String get accessibility_shortcut_closeCancel => 'Close / Cancel';

  @override
  String get accessibility_shortcut_goBack => 'Go back';

  @override
  String get accessibility_shortcut_goToDives => 'Go to Dives';

  @override
  String get accessibility_shortcut_goToEquipment => 'Go to Equipment';

  @override
  String get accessibility_shortcut_goToSettings => 'Go to Settings';

  @override
  String get accessibility_shortcut_goToSites => 'Go to Sites';

  @override
  String get accessibility_shortcut_goToStatistics => 'Go to Statistics';

  @override
  String get accessibility_shortcut_keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get accessibility_shortcut_newDive => 'New dive';

  @override
  String get accessibility_shortcut_openSettings => 'Open settings';

  @override
  String get accessibility_shortcut_searchDives => 'Search dives';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return 'Sort by $displayName, currently selected';
  }

  @override
  String accessibility_sort_unselectedLabel(Object displayName) {
    return 'Sort by $displayName';
  }

  @override
  String get backup_appBar_title => 'Backup & Restore';

  @override
  String get backup_backingUp => 'Backing up...';

  @override
  String get backup_backupNow => 'Backup Now';

  @override
  String get backup_cloud_enabled => 'Cloud backup';

  @override
  String get backup_cloud_enabled_subtitle => 'Upload backups to cloud storage';

  @override
  String get backup_delete_dialog_cancel => 'Cancel';

  @override
  String get backup_delete_dialog_content =>
      'This backup will be permanently deleted. This cannot be undone.';

  @override
  String get backup_delete_dialog_delete => 'Delete';

  @override
  String get backup_delete_dialog_title => 'Delete Backup';

  @override
  String get backup_frequency_daily => 'Daily';

  @override
  String get backup_frequency_monthly => 'Monthly';

  @override
  String get backup_frequency_weekly => 'Weekly';

  @override
  String get backup_history_action_delete => 'Delete';

  @override
  String get backup_history_action_restore => 'Restore';

  @override
  String get backup_history_empty => 'No backups yet';

  @override
  String backup_history_error(Object error) {
    return 'Failed to load history: $error';
  }

  @override
  String get backup_restore_dialog_cancel => 'Cancel';

  @override
  String get backup_restore_dialog_restore => 'Restore';

  @override
  String get backup_restore_dialog_safetyNote =>
      'A safety backup of your current data will be created automatically before restoring.';

  @override
  String get backup_restore_dialog_title => 'Restore Backup';

  @override
  String get backup_restore_dialog_warning =>
      'This will replace ALL current data with the backup data. This action cannot be undone.';

  @override
  String get backup_schedule_enabled => 'Automatic backups';

  @override
  String get backup_schedule_enabled_subtitle =>
      'Back up your data on a schedule';

  @override
  String get backup_schedule_frequency => 'Frequency';

  @override
  String get backup_schedule_retention => 'Keep backups';

  @override
  String get backup_schedule_retention_subtitle =>
      'Older backups are automatically removed';

  @override
  String get backup_section_cloud => 'Cloud';

  @override
  String get backup_section_history => 'History';

  @override
  String get backup_section_schedule => 'Schedule';

  @override
  String get backup_status_disabled => 'Automatic Backups Disabled';

  @override
  String backup_status_lastBackup(String time) {
    return 'Last backup: $time';
  }

  @override
  String get backup_status_neverBackedUp => 'Never Backed Up';

  @override
  String get backup_status_noBackupsYet =>
      'Create your first backup to protect your data';

  @override
  String get backup_status_overdue => 'Backup Overdue';

  @override
  String get backup_status_upToDate => 'Backups Up to Date';

  @override
  String backup_time_daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String backup_time_hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get backup_time_justNow => 'Just now';

  @override
  String backup_time_minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String get buddies_action_add => 'Add Buddy';

  @override
  String get buddies_action_addFirst => 'Add your first buddy';

  @override
  String get buddies_action_addTooltip => 'Add a new dive buddy';

  @override
  String get buddies_action_clearSearch => 'Clear search';

  @override
  String get buddies_action_edit => 'Edit buddy';

  @override
  String get buddies_action_importFromContacts => 'Import from Contacts';

  @override
  String get buddies_action_moreOptions => 'More options';

  @override
  String get buddies_action_retry => 'Retry';

  @override
  String get buddies_action_search => 'Search buddies';

  @override
  String get buddies_action_shareDives => 'Share Dives';

  @override
  String get buddies_action_sort => 'Sort';

  @override
  String get buddies_action_sortTitle => 'Sort Buddies';

  @override
  String get buddies_action_update => 'Update Buddy';

  @override
  String buddies_action_viewAll(Object count) {
    return 'View All ($count)';
  }

  @override
  String buddies_detail_error(Object error) {
    return 'Error: $error';
  }

  @override
  String get buddies_detail_noDivesTogether => 'No dives together yet';

  @override
  String get buddies_detail_notFound => 'Buddy not found';

  @override
  String buddies_dialog_deleteMessage(Object name) {
    return 'Are you sure you want to delete $name? This action cannot be undone.';
  }

  @override
  String get buddies_dialog_deleteTitle => 'Delete Buddy?';

  @override
  String get buddies_dialog_discard => 'Discard';

  @override
  String get buddies_dialog_discardMessage =>
      'You have unsaved changes. Are you sure you want to discard them?';

  @override
  String get buddies_dialog_discardTitle => 'Discard Changes?';

  @override
  String get buddies_dialog_keepEditing => 'Keep Editing';

  @override
  String get buddies_empty_subtitle =>
      'Add your first dive buddy to get started';

  @override
  String get buddies_empty_title => 'No dive buddies yet';

  @override
  String buddies_error_loading(Object error) {
    return 'Error: $error';
  }

  @override
  String get buddies_error_unableToLoadDives => 'Unable to load dives';

  @override
  String get buddies_error_unableToLoadStats => 'Unable to load statistics';

  @override
  String get buddies_field_certificationAgency => 'Certification Agency';

  @override
  String get buddies_field_certificationLevel => 'Certification Level';

  @override
  String get buddies_field_email => 'Email';

  @override
  String get buddies_field_emailHint => 'email@example.com';

  @override
  String get buddies_field_nameHint => 'Enter buddy name';

  @override
  String get buddies_field_nameRequired => 'Name *';

  @override
  String get buddies_field_notes => 'Notes';

  @override
  String get buddies_field_notesHint => 'Add notes about this buddy...';

  @override
  String get buddies_field_phone => 'Phone';

  @override
  String get buddies_field_phoneHint => '+1 (555) 123-4567';

  @override
  String get buddies_label_agency => 'Agency';

  @override
  String buddies_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives',
      one: '1 dive',
    );
    return '$_temp0';
  }

  @override
  String get buddies_label_level => 'Level';

  @override
  String get buddies_label_notSpecified => 'Not specified';

  @override
  String get buddies_label_photoComingSoon => 'Photo support coming in v2.0';

  @override
  String get buddies_message_added => 'Buddy added successfully';

  @override
  String get buddies_message_contactImportUnavailable =>
      'Contact import is not available on this platform';

  @override
  String get buddies_message_contactLoadFailed => 'Failed to load contacts';

  @override
  String get buddies_message_contactPermissionRequired =>
      'Contact permission is required to import buddies';

  @override
  String get buddies_message_deleted => 'Buddy deleted';

  @override
  String buddies_message_errorImportingContact(Object error) {
    return 'Error importing contact: $error';
  }

  @override
  String buddies_message_errorLoading(Object error) {
    return 'Error loading buddy: $error';
  }

  @override
  String buddies_message_errorSaving(Object error) {
    return 'Error saving buddy: $error';
  }

  @override
  String buddies_message_exportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get buddies_message_noDivesFound => 'No dives found to export';

  @override
  String get buddies_message_noDivesToShare =>
      'No dives to share with this buddy';

  @override
  String get buddies_message_preparingExport => 'Preparing export...';

  @override
  String get buddies_message_updated => 'Buddy updated successfully';

  @override
  String get buddies_picker_add => 'Add';

  @override
  String get buddies_picker_addNew => 'Add New Buddy';

  @override
  String get buddies_picker_done => 'Done';

  @override
  String get buddies_picker_noBuddiesFound => 'No buddies found';

  @override
  String get buddies_picker_noBuddiesYet => 'No buddies yet';

  @override
  String get buddies_picker_noneSelected => 'No buddies selected';

  @override
  String get buddies_picker_searchHint => 'Search buddies...';

  @override
  String get buddies_picker_selectBuddies => 'Select Buddies';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Select Role for $name';
  }

  @override
  String get buddies_picker_tapToAdd => 'Tap \'Add\' to select dive buddies';

  @override
  String get buddies_search_hint => 'Search by name, email, or phone';

  @override
  String buddies_search_noResults(Object query) {
    return 'No buddies found for \"$query\"';
  }

  @override
  String get buddies_section_certification => 'Certification';

  @override
  String get buddies_section_contact => 'Contact';

  @override
  String get buddies_section_diveStatistics => 'Dive Statistics';

  @override
  String get buddies_section_notes => 'Notes';

  @override
  String get buddies_section_sharedDives => 'Shared Dives';

  @override
  String get buddies_stat_divesTogether => 'Dives Together';

  @override
  String get buddies_stat_favoriteSite => 'Favorite Site';

  @override
  String get buddies_stat_firstDive => 'First Dive';

  @override
  String get buddies_stat_lastDive => 'Last Dive';

  @override
  String get buddies_summary_overview => 'Overview';

  @override
  String get buddies_summary_quickActions => 'Quick Actions';

  @override
  String get buddies_summary_recentBuddies => 'Recent Buddies';

  @override
  String get buddies_summary_selectHint =>
      'Select a buddy from the list to view details';

  @override
  String get buddies_summary_title => 'Dive Buddies';

  @override
  String get buddies_summary_totalBuddies => 'Total Buddies';

  @override
  String get buddies_summary_withCertification => 'With Certification';

  @override
  String get buddies_title => 'Buddies';

  @override
  String get buddies_title_add => 'Add Buddy';

  @override
  String get buddies_title_edit => 'Edit Buddy';

  @override
  String get buddies_title_singular => 'Buddy';

  @override
  String get buddies_validation_emailInvalid => 'Please enter a valid email';

  @override
  String get buddies_validation_nameRequired => 'Please enter a name';

  @override
  String get certifications_appBar_addCertification => 'Add Certification';

  @override
  String get certifications_appBar_certificationWallet =>
      'Certification Wallet';

  @override
  String get certifications_appBar_editCertification => 'Edit Certification';

  @override
  String get certifications_appBar_title => 'Certifications';

  @override
  String get certifications_detail_action_delete => 'Delete';

  @override
  String get certifications_detail_appBar_title => 'Certification';

  @override
  String get certifications_detail_courseCompleted => 'Completed';

  @override
  String get certifications_detail_courseInProgress => 'In Progress';

  @override
  String get certifications_detail_dialog_cancel => 'Cancel';

  @override
  String get certifications_detail_dialog_deleteConfirm => 'Delete';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get certifications_detail_dialog_deleteTitle =>
      'Delete Certification?';

  @override
  String get certifications_detail_label_agency => 'Agency';

  @override
  String get certifications_detail_label_cardNumber => 'Card Number';

  @override
  String get certifications_detail_label_expiryDate => 'Expiry Date';

  @override
  String get certifications_detail_label_instructorName => 'Name';

  @override
  String get certifications_detail_label_instructorNumber => 'Instructor #';

  @override
  String get certifications_detail_label_issueDate => 'Issue Date';

  @override
  String get certifications_detail_label_level => 'Level';

  @override
  String get certifications_detail_label_type => 'Type';

  @override
  String get certifications_detail_label_validity => 'Validity';

  @override
  String get certifications_detail_noExpiration => 'No Expiration';

  @override
  String get certifications_detail_notFound => 'Certification not found';

  @override
  String get certifications_detail_photoLabel_back => 'Back';

  @override
  String get certifications_detail_photoLabel_front => 'Front';

  @override
  String certifications_detail_photo_fullscreenTitle(
    Object label,
    Object name,
  ) {
    return '$label - $name';
  }

  @override
  String get certifications_detail_photo_unableToLoad => 'Unable to load image';

  @override
  String get certifications_detail_sectionTitle_cardPhotos => 'Card Photos';

  @override
  String get certifications_detail_sectionTitle_dates => 'Dates';

  @override
  String get certifications_detail_sectionTitle_details =>
      'Certification Details';

  @override
  String get certifications_detail_sectionTitle_instructor => 'Instructor';

  @override
  String get certifications_detail_sectionTitle_notes => 'Notes';

  @override
  String get certifications_detail_sectionTitle_trainingCourse =>
      'Training Course';

  @override
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  ) {
    return '$label photo of $name. Tap to view full screen';
  }

  @override
  String get certifications_detail_snackBar_deleted => 'Certification deleted';

  @override
  String get certifications_detail_status_expired =>
      'This certification has expired';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return 'Expired on $date';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return 'Expires in $days days';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return 'Expires on $date';
  }

  @override
  String get certifications_detail_tooltip_edit => 'Edit certification';

  @override
  String get certifications_detail_tooltip_editShort => 'Edit';

  @override
  String get certifications_detail_tooltip_moreOptions => 'More options';

  @override
  String get certifications_ecardStack_empty_subtitle =>
      'Add your first certification to see it here';

  @override
  String get certifications_ecardStack_empty_title => 'No certifications yet';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Certified by $agency';
  }

  @override
  String get certifications_ecard_label_instructor => 'INSTRUCTOR';

  @override
  String get certifications_ecard_label_issued => 'ISSUED';

  @override
  String get certifications_ecard_statusBadge_expired => 'EXPIRED';

  @override
  String get certifications_ecard_statusBadge_expiring => 'EXPIRING';

  @override
  String get certifications_edit_appBar_add => 'Add Certification';

  @override
  String get certifications_edit_appBar_edit => 'Edit Certification';

  @override
  String get certifications_edit_button_add => 'Add Certification';

  @override
  String get certifications_edit_button_cancel => 'Cancel';

  @override
  String get certifications_edit_button_save => 'Save';

  @override
  String get certifications_edit_button_update => 'Update Certification';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return 'Clear $label';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect => 'Tap to select';

  @override
  String get certifications_edit_dialog_discard => 'Discard';

  @override
  String get certifications_edit_dialog_discardContent =>
      'You have unsaved changes. Are you sure you want to leave?';

  @override
  String get certifications_edit_dialog_discardTitle => 'Discard Changes?';

  @override
  String get certifications_edit_dialog_keepEditing => 'Keep Editing';

  @override
  String get certifications_edit_help_expiryDate =>
      'Leave empty for certifications that don\'t expire';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Enter certification card number';

  @override
  String get certifications_edit_hint_certificationName =>
      'e.g., Open Water Diver';

  @override
  String get certifications_edit_hint_instructorName =>
      'Name of certifying instructor';

  @override
  String get certifications_edit_hint_instructorNumber =>
      'Instructor certification number';

  @override
  String get certifications_edit_hint_notes => 'Any additional notes';

  @override
  String get certifications_edit_label_agency => 'Agency *';

  @override
  String get certifications_edit_label_cardNumber => 'Card Number';

  @override
  String get certifications_edit_label_certificationName =>
      'Certification Name *';

  @override
  String get certifications_edit_label_expiryDate => 'Expiry Date';

  @override
  String get certifications_edit_label_instructorName => 'Instructor Name';

  @override
  String get certifications_edit_label_instructorNumber => 'Instructor Number';

  @override
  String get certifications_edit_label_issueDate => 'Issue Date';

  @override
  String get certifications_edit_label_level => 'Level';

  @override
  String get certifications_edit_label_notes => 'Notes';

  @override
  String get certifications_edit_level_notSpecified => 'Not specified';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return 'Add $label photo. Tap to select';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return '$label photo attached. Tap to change';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery =>
      'Choose from Gallery';

  @override
  String certifications_edit_photo_removeTooltip(Object label) {
    return 'Remove $label photo';
  }

  @override
  String get certifications_edit_photo_takePhoto => 'Take Photo';

  @override
  String get certifications_edit_sectionTitle_cardPhotos => 'Card Photos';

  @override
  String get certifications_edit_sectionTitle_dates => 'Dates';

  @override
  String get certifications_edit_sectionTitle_instructorInfo =>
      'Instructor Information';

  @override
  String get certifications_edit_sectionTitle_notes => 'Notes';

  @override
  String get certifications_edit_snackBar_added =>
      'Certification added successfully';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return 'Error loading certification: $error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return 'Error picking photo: $error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return 'Error saving certification: $error';
  }

  @override
  String get certifications_edit_snackBar_updated =>
      'Certification updated successfully';

  @override
  String get certifications_edit_validation_nameRequired =>
      'Please enter a certification name';

  @override
  String get certifications_list_button_retry => 'Retry';

  @override
  String get certifications_list_empty_button => 'Add Your First Certification';

  @override
  String get certifications_list_empty_subtitle =>
      'Add your dive certifications to keep track of your training and qualifications';

  @override
  String get certifications_list_empty_title => 'No certifications added yet';

  @override
  String certifications_list_error_loading(Object error) {
    return 'Error loading certifications: $error';
  }

  @override
  String get certifications_list_fab_addCertification => 'Add Certification';

  @override
  String get certifications_list_section_expired => 'Expired';

  @override
  String get certifications_list_section_expiringSoon => 'Expiring Soon';

  @override
  String get certifications_list_section_valid => 'Valid';

  @override
  String get certifications_list_sort_title => 'Sort Certifications';

  @override
  String get certifications_list_tile_expired => 'Expired';

  @override
  String certifications_list_tile_expiringDays(Object days) {
    return '${days}d';
  }

  @override
  String get certifications_list_tooltip_addCertification =>
      'Add Certification';

  @override
  String get certifications_list_tooltip_search => 'Search certifications';

  @override
  String get certifications_list_tooltip_sort => 'Sort';

  @override
  String get certifications_list_tooltip_walletView => 'Wallet View';

  @override
  String get certifications_picker_clearTooltip =>
      'Clear certification selection';

  @override
  String get certifications_picker_empty_addButton => 'Add Certification';

  @override
  String get certifications_picker_empty_title => 'No certifications yet';

  @override
  String certifications_picker_error(Object error) {
    return 'Error loading certifications: $error';
  }

  @override
  String get certifications_picker_expired => 'Expired';

  @override
  String get certifications_picker_hint =>
      'Tap to link to an earned certification';

  @override
  String get certifications_picker_newCert => 'New Cert';

  @override
  String get certifications_picker_noSelection => 'No certification selected';

  @override
  String get certifications_picker_sheetTitle => 'Link to Certification';

  @override
  String get certifications_renderer_footer => 'Submersion Dive Log';

  @override
  String certifications_renderer_label_cardNumber(Object number) {
    return 'Card #: $number';
  }

  @override
  String get certifications_renderer_label_hasCompletedTraining =>
      'has completed training as';

  @override
  String certifications_renderer_label_instructor(Object name) {
    return 'Instructor: $name';
  }

  @override
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  ) {
    return 'Instructor: $name ($number)';
  }

  @override
  String certifications_renderer_label_issued(Object date) {
    return 'Issued: $date';
  }

  @override
  String get certifications_renderer_label_thisCertifies =>
      'This certifies that';

  @override
  String get certifications_search_empty_hint =>
      'Search by name, agency, or card number';

  @override
  String get certifications_search_fieldLabel => 'Search certifications...';

  @override
  String certifications_search_noResults(Object query) {
    return 'No certifications found for \"$query\"';
  }

  @override
  String get certifications_search_tooltip_back => 'Back';

  @override
  String get certifications_search_tooltip_clear => 'Clear search';

  @override
  String certifications_share_error_card(Object error) {
    return 'Failed to share card: $error';
  }

  @override
  String certifications_share_error_certificate(Object error) {
    return 'Failed to share certificate: $error';
  }

  @override
  String get certifications_share_option_card_subtitle =>
      'Credit card-style certification image';

  @override
  String get certifications_share_option_card_title => 'Share as Card';

  @override
  String get certifications_share_option_certificate_subtitle =>
      'Formal certificate document';

  @override
  String get certifications_share_option_certificate_title =>
      'Share as Certificate';

  @override
  String get certifications_share_title => 'Share Certification';

  @override
  String get certifications_summary_header_subtitle =>
      'Select a certification from the list to view details';

  @override
  String get certifications_summary_header_title => 'Certifications';

  @override
  String get certifications_summary_overview_title => 'Overview';

  @override
  String get certifications_summary_quickActions_add => 'Add Certification';

  @override
  String get certifications_summary_quickActions_title => 'Quick Actions';

  @override
  String get certifications_summary_recentTitle => 'Recent Certifications';

  @override
  String get certifications_summary_stat_expired => 'Expired';

  @override
  String get certifications_summary_stat_expiringSoon => 'Expiring Soon';

  @override
  String get certifications_summary_stat_total => 'Total';

  @override
  String get certifications_summary_stat_valid => 'Valid';

  @override
  String certifications_walletCard_countPlural(Object count) {
    return '$count certifications';
  }

  @override
  String certifications_walletCard_countSingular(Object count) {
    return '$count certification';
  }

  @override
  String get certifications_walletCard_emptyFooter =>
      'Add your first certification';

  @override
  String get certifications_walletCard_error => 'Failed to load certifications';

  @override
  String get certifications_walletCard_semanticLabel =>
      'Certification Wallet. Tap to view all certifications';

  @override
  String get certifications_walletCard_tapToAdd => 'Tap to add';

  @override
  String get certifications_walletCard_title => 'Certification Wallet';

  @override
  String get certifications_wallet_appBar_title => 'Certification Wallet';

  @override
  String get certifications_wallet_error_retry => 'Retry';

  @override
  String get certifications_wallet_error_title =>
      'Failed to load certifications';

  @override
  String get certifications_wallet_options_edit => 'Edit';

  @override
  String get certifications_wallet_options_share => 'Share';

  @override
  String get certifications_wallet_options_viewDetails => 'View Details';

  @override
  String get certifications_wallet_tooltip_add => 'Add certification';

  @override
  String get certifications_wallet_tooltip_share => 'Share certification';

  @override
  String get common_action_back => 'Back';

  @override
  String get common_action_cancel => 'Cancel';

  @override
  String get common_action_close => 'Close';

  @override
  String get common_action_delete => 'Delete';

  @override
  String get common_action_edit => 'Edit';

  @override
  String get common_action_ok => 'OK';

  @override
  String get common_action_save => 'Save';

  @override
  String get common_action_search => 'Search';

  @override
  String get common_label_error => 'Error';

  @override
  String get common_label_loading => 'Loading';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get courses_action_add => 'Add Course';

  @override
  String get courses_action_create => 'Create Course';

  @override
  String get courses_action_edit => 'Edit course';

  @override
  String get courses_action_exportTrainingLog => 'Export Training Log';

  @override
  String get courses_action_markCompleted => 'Mark as Completed';

  @override
  String get courses_action_moreOptions => 'More options';

  @override
  String get courses_action_retry => 'Retry';

  @override
  String get courses_action_saveChanges => 'Save Changes';

  @override
  String get courses_action_saveSemantic => 'Save course';

  @override
  String get courses_action_sort => 'Sort';

  @override
  String get courses_action_sortTitle => 'Sort Courses';

  @override
  String courses_card_instructor(Object name) {
    return 'Instructor: $name';
  }

  @override
  String courses_card_started(Object date) {
    return 'Started $date';
  }

  @override
  String get courses_detail_certificationNotFound => 'Certification not found';

  @override
  String get courses_detail_noTrainingDives => 'No training dives linked yet';

  @override
  String get courses_detail_notFound => 'Course not found';

  @override
  String get courses_dialog_complete => 'Complete';

  @override
  String courses_dialog_deleteMessage(Object name) {
    return 'Are you sure you want to delete $name? This action cannot be undone.';
  }

  @override
  String get courses_dialog_deleteTitle => 'Delete Course?';

  @override
  String get courses_dialog_markCompletedMessage =>
      'This will mark the course as completed with today\'s date. Continue?';

  @override
  String get courses_dialog_markCompletedTitle => 'Mark as Completed?';

  @override
  String get courses_empty_noCompleted => 'No completed courses';

  @override
  String get courses_empty_noInProgress => 'No courses in progress';

  @override
  String get courses_empty_subtitle => 'Add your first course to get started';

  @override
  String get courses_empty_title => 'No training courses yet';

  @override
  String courses_error_generic(Object error) {
    return 'Error: $error';
  }

  @override
  String get courses_error_loadingCertification =>
      'Error loading certification';

  @override
  String get courses_error_loadingDives => 'Error loading dives';

  @override
  String get courses_field_courseName => 'Course Name';

  @override
  String get courses_field_courseNameHint => 'e.g. Open Water Diver';

  @override
  String get courses_field_instructorName => 'Instructor Name';

  @override
  String get courses_field_instructorNumber => 'Instructor Number';

  @override
  String get courses_field_linkCertificationHint =>
      'Link a certification earned from this course';

  @override
  String get courses_field_location => 'Location';

  @override
  String get courses_field_notes => 'Notes';

  @override
  String get courses_field_selectFromBuddies =>
      'Select from Buddies (Optional)';

  @override
  String get courses_filter_all => 'All';

  @override
  String get courses_label_agency => 'Agency';

  @override
  String get courses_label_completed => 'Completed';

  @override
  String get courses_label_completionDate => 'Completion Date';

  @override
  String get courses_label_courseInProgress => 'Course is in progress';

  @override
  String get courses_label_instructorNumber => 'Instructor #';

  @override
  String get courses_label_location => 'Location';

  @override
  String get courses_label_name => 'Name';

  @override
  String get courses_label_none => '-- None --';

  @override
  String get courses_label_startDate => 'Start Date';

  @override
  String courses_message_errorSaving(Object error) {
    return 'Error saving course: $error';
  }

  @override
  String courses_message_exportFailed(Object error) {
    return 'Failed to export training log: $error';
  }

  @override
  String get courses_picker_active => 'Active';

  @override
  String get courses_picker_clearSelection => 'Clear selection';

  @override
  String get courses_picker_createCourse => 'Create Course';

  @override
  String courses_picker_errorLoading(Object error) {
    return 'Error loading courses: $error';
  }

  @override
  String get courses_picker_newCourse => 'New Course';

  @override
  String get courses_picker_noCourses => 'No courses yet';

  @override
  String get courses_picker_noneSelected => 'No course selected';

  @override
  String get courses_picker_selectTitle => 'Select Training Course';

  @override
  String get courses_picker_selected => 'selected';

  @override
  String get courses_picker_tapToLink => 'Tap to link to a training course';

  @override
  String get courses_section_details => 'Course Details';

  @override
  String get courses_section_earnedCertification => 'Earned Certification';

  @override
  String get courses_section_instructor => 'Instructor';

  @override
  String get courses_section_notes => 'Notes';

  @override
  String get courses_section_trainingDives => 'Training Dives';

  @override
  String get courses_status_completed => 'Completed';

  @override
  String courses_status_daysSinceStart(Object days) {
    return '$days days since start';
  }

  @override
  String courses_status_durationDays(Object days) {
    return '$days days';
  }

  @override
  String get courses_status_inProgress => 'In Progress';

  @override
  String courses_status_semanticLabel(Object status, Object duration) {
    return '$status, $duration';
  }

  @override
  String get courses_summary_overview => 'Overview';

  @override
  String get courses_summary_quickActions => 'Quick Actions';

  @override
  String get courses_summary_recentCourses => 'Recent Courses';

  @override
  String get courses_summary_selectHint =>
      'Select a course from the list to view details';

  @override
  String get courses_summary_title => 'Training Courses';

  @override
  String get courses_summary_total => 'Total';

  @override
  String get courses_title => 'Training Courses';

  @override
  String get courses_title_edit => 'Edit Course';

  @override
  String get courses_title_new => 'New Course';

  @override
  String get courses_title_singular => 'Course';

  @override
  String get courses_validation_nameRequired => 'Please enter a course name';

  @override
  String get dashboard_activity_daySinceDiving => 'Day since diving';

  @override
  String get dashboard_activity_daysSinceDiving => 'Days since diving';

  @override
  String dashboard_activity_diveInYear(Object year) {
    return 'Dive in $year';
  }

  @override
  String get dashboard_activity_diveThisMonth => 'Dive this month';

  @override
  String dashboard_activity_divesInYear(Object year) {
    return 'Dives in $year';
  }

  @override
  String get dashboard_activity_divesThisMonth => 'Dives this month';

  @override
  String get dashboard_activity_error => 'Error';

  @override
  String get dashboard_activity_lastDive => 'Last dive';

  @override
  String get dashboard_activity_loading => 'Loading';

  @override
  String get dashboard_activity_noDivesYet => 'No dives yet';

  @override
  String get dashboard_activity_today => 'Today!';

  @override
  String get dashboard_alerts_actionUpdate => 'Update';

  @override
  String get dashboard_alerts_actionView => 'View';

  @override
  String get dashboard_alerts_checkInsuranceExpiry =>
      'Check your insurance expiry date';

  @override
  String get dashboard_alerts_daysOverdueOne => '1 day overdue';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return '$count days overdue';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => 'Due in 1 day';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return 'Due in $count days';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return '$name Service Due';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return '$name Service Overdue';
  }

  @override
  String get dashboard_alerts_insuranceExpired => 'Insurance Expired';

  @override
  String get dashboard_alerts_insuranceExpiredGeneric =>
      'Your dive insurance has expired';

  @override
  String dashboard_alerts_insuranceExpiredProvider(Object provider) {
    return '$provider expired';
  }

  @override
  String dashboard_alerts_insuranceExpiresDate(Object date) {
    return 'Expires $date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon =>
      'Insurance Expiring Soon';

  @override
  String get dashboard_alerts_sectionTitle => 'Alerts & Reminders';

  @override
  String get dashboard_alerts_serviceDueToday => 'Service due today';

  @override
  String get dashboard_alerts_serviceIntervalReached =>
      'Service interval reached';

  @override
  String get dashboard_defaultDiverName => 'Diver';

  @override
  String get dashboard_greeting_afternoon => 'Good afternoon';

  @override
  String get dashboard_greeting_evening => 'Good evening';

  @override
  String get dashboard_greeting_morning => 'Good morning';

  @override
  String dashboard_greeting_withName(Object greeting, Object name) {
    return '$greeting, $name!';
  }

  @override
  String dashboard_greeting_withoutName(Object greeting) {
    return '$greeting!';
  }

  @override
  String get dashboard_hero_divesLoggedOne => '1 dive logged';

  @override
  String dashboard_hero_divesLoggedOther(Object count) {
    return '$count dives logged';
  }

  @override
  String get dashboard_hero_error => 'Ready to explore the depths?';

  @override
  String dashboard_hero_hoursUnderwater(Object hours) {
    return '$hours hours underwater';
  }

  @override
  String get dashboard_hero_loading => 'Loading your dive stats...';

  @override
  String dashboard_hero_minutesUnderwater(Object minutes) {
    return '$minutes minutes underwater';
  }

  @override
  String get dashboard_hero_noDives => 'Ready to log your first dive?';

  @override
  String get dashboard_personalRecords_coldest => 'Coldest';

  @override
  String get dashboard_personalRecords_deepest => 'Deepest';

  @override
  String get dashboard_personalRecords_longest => 'Longest';

  @override
  String get dashboard_personalRecords_sectionTitle => 'Personal Records';

  @override
  String get dashboard_personalRecords_warmest => 'Warmest';

  @override
  String get dashboard_quickActions_addSite => 'Add Site';

  @override
  String get dashboard_quickActions_addSiteTooltip => 'Add a new dive site';

  @override
  String get dashboard_quickActions_logDive => 'Log Dive';

  @override
  String get dashboard_quickActions_logDiveTooltip => 'Log a new dive';

  @override
  String get dashboard_quickActions_planDive => 'Plan Dive';

  @override
  String get dashboard_quickActions_planDiveTooltip => 'Plan a new dive';

  @override
  String get dashboard_quickActions_sectionTitle => 'Quick Actions';

  @override
  String get dashboard_quickActions_statistics => 'Statistics';

  @override
  String get dashboard_quickActions_statisticsTooltip => 'View dive statistics';

  @override
  String get dashboard_quickStats_countries => 'Countries';

  @override
  String get dashboard_quickStats_countriesSubtitle => 'visited';

  @override
  String get dashboard_quickStats_sectionTitle => 'At a Glance';

  @override
  String get dashboard_quickStats_species => 'Species';

  @override
  String get dashboard_quickStats_speciesSubtitle => 'discovered';

  @override
  String get dashboard_quickStats_topBuddy => 'Top Buddy';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count dives';
  }

  @override
  String get dashboard_recentDives_empty => 'No dives logged yet';

  @override
  String get dashboard_recentDives_errorLoading => 'Failed to load dives';

  @override
  String get dashboard_recentDives_logFirst => 'Log Your First Dive';

  @override
  String get dashboard_recentDives_sectionTitle => 'Recent Dives';

  @override
  String get dashboard_recentDives_viewAll => 'View All';

  @override
  String get dashboard_recentDives_viewAllTooltip => 'View all dives';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count active alerts';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives =>
      'Error: Failed to load recent dives';

  @override
  String get dashboard_semantics_errorLoadingStatistics =>
      'Error: Failed to load statistics';

  @override
  String get dashboard_semantics_greetingBanner => 'Dashboard greeting banner';

  @override
  String get dashboard_stats_errorLoadingStatistics =>
      'Failed to load statistics';

  @override
  String get dashboard_stats_hoursLogged => 'Hours Logged';

  @override
  String get dashboard_stats_maxDepth => 'Max Depth';

  @override
  String get dashboard_stats_sitesVisited => 'Sites Visited';

  @override
  String get dashboard_stats_totalDives => 'Total Dives';

  @override
  String get decoCalculator_addToPlanner => 'Add to Planner';

  @override
  String decoCalculator_bottomTimeSemantics(Object time) {
    return 'Bottom time: $time minutes';
  }

  @override
  String get decoCalculator_createPlanTooltip =>
      'Create a dive plan from current parameters';

  @override
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  ) {
    return 'Created plan: $depth$depthSymbol for ${time}min on $gasMixName';
  }

  @override
  String get decoCalculator_customMixTrimix => 'Custom Mix (Trimix)';

  @override
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol) {
    return 'Depth: $depth $depthSymbol';
  }

  @override
  String get decoCalculator_diveParameters => 'Dive Parameters';

  @override
  String get decoCalculator_endCaution => 'Caution';

  @override
  String get decoCalculator_endDanger => 'Danger';

  @override
  String get decoCalculator_endSafe => 'Safe';

  @override
  String get decoCalculator_field_bottomTime => 'Bottom Time';

  @override
  String get decoCalculator_field_depth => 'Depth';

  @override
  String get decoCalculator_field_gasMix => 'Gas Mix';

  @override
  String get decoCalculator_gasSafety => 'Gas Safety';

  @override
  String get decoCalculator_hideCustomMix => 'Hide Custom Mix';

  @override
  String get decoCalculator_hideCustomMixSemantics =>
      'Hide custom gas mix selector';

  @override
  String get decoCalculator_modExceeded => 'MOD Exceeded';

  @override
  String get decoCalculator_modSafe => 'MOD Safe';

  @override
  String get decoCalculator_ppO2Caution => 'ppO2 Caution';

  @override
  String get decoCalculator_ppO2Danger => 'ppO2 Danger';

  @override
  String get decoCalculator_ppO2Hypoxic => 'ppO2 Hypoxic';

  @override
  String get decoCalculator_ppO2Safe => 'ppO2 Safe';

  @override
  String get decoCalculator_resetToDefaults => 'Reset to defaults';

  @override
  String get decoCalculator_showCustomMixSemantics =>
      'Show custom gas mix selector';

  @override
  String decoCalculator_timeValueMin(Object time) {
    return '$time min';
  }

  @override
  String get decoCalculator_title => 'Deco Calculator';

  @override
  String diveCenters_accessibility_markerLabel(Object name) {
    return 'Dive center: $name';
  }

  @override
  String get diveCenters_accessibility_selected => 'selected';

  @override
  String diveCenters_accessibility_viewDetails(Object name) {
    return 'View details for $name';
  }

  @override
  String get diveCenters_accessibility_viewDives =>
      'View dives with this center';

  @override
  String get diveCenters_accessibility_viewFullscreenMap =>
      'View fullscreen map';

  @override
  String diveCenters_accessibility_viewSavedCenter(Object name) {
    return 'View saved dive center $name';
  }

  @override
  String get diveCenters_action_addCenter => 'Add Center';

  @override
  String get diveCenters_action_addNew => 'Add New';

  @override
  String get diveCenters_action_clearRating => 'Clear';

  @override
  String get diveCenters_action_gettingLocation => 'Getting...';

  @override
  String get diveCenters_action_import => 'Import';

  @override
  String get diveCenters_action_importToMyCenters => 'Import to My Centers';

  @override
  String get diveCenters_action_lookingUp => 'Looking up...';

  @override
  String get diveCenters_action_lookupFromAddress => 'Lookup from Address';

  @override
  String get diveCenters_action_pickFromMap => 'Pick from Map';

  @override
  String get diveCenters_action_retry => 'Retry';

  @override
  String get diveCenters_action_settings => 'Settings';

  @override
  String get diveCenters_action_useMyLocation => 'Use My Location';

  @override
  String get diveCenters_action_view => 'View';

  @override
  String diveCenters_detail_divesLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives logged',
      one: '1 dive logged',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_detail_divesWithCenter => 'Dives with this Center';

  @override
  String get diveCenters_detail_noDivesLogged => 'No dives logged yet';

  @override
  String diveCenters_dialog_deleteMessage(Object name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get diveCenters_dialog_deleteTitle => 'Delete Dive Center';

  @override
  String get diveCenters_dialog_discard => 'Discard';

  @override
  String get diveCenters_dialog_discardMessage =>
      'You have unsaved changes. Are you sure you want to discard them?';

  @override
  String get diveCenters_dialog_discardTitle => 'Discard Changes?';

  @override
  String get diveCenters_dialog_keepEditing => 'Keep Editing';

  @override
  String get diveCenters_empty_subtitle =>
      'Add your favorite dive shops and operators';

  @override
  String get diveCenters_empty_title => 'No dive centers yet';

  @override
  String diveCenters_error_generic(Object error) {
    return 'Error: $error';
  }

  @override
  String get diveCenters_error_geocodeFailed =>
      'Could not find coordinates for this address';

  @override
  String get diveCenters_error_importFailed => 'Failed to import dive center';

  @override
  String diveCenters_error_loading(Object error) {
    return 'Error loading dive centers: $error';
  }

  @override
  String get diveCenters_error_locationPermission =>
      'Unable to get location. Please check permissions.';

  @override
  String get diveCenters_error_locationUnavailable =>
      'Unable to get location. Location services may not be available.';

  @override
  String get diveCenters_error_noAddressForLookup =>
      'Please enter an address to look up coordinates';

  @override
  String get diveCenters_error_notFound => 'Dive center not found';

  @override
  String diveCenters_error_saving(Object error) {
    return 'Error saving dive center: $error';
  }

  @override
  String get diveCenters_error_unknown => 'Unknown error';

  @override
  String get diveCenters_field_city => 'City';

  @override
  String get diveCenters_field_country => 'Country';

  @override
  String get diveCenters_field_latitude => 'Latitude';

  @override
  String get diveCenters_field_longitude => 'Longitude';

  @override
  String get diveCenters_field_nameRequired => 'Name *';

  @override
  String get diveCenters_field_postalCode => 'Postal Code';

  @override
  String get diveCenters_field_rating => 'Rating';

  @override
  String get diveCenters_field_stateProvince => 'State/Province';

  @override
  String get diveCenters_field_street => 'Street Address';

  @override
  String get diveCenters_hint_addressDescription =>
      'Optional street address for navigation';

  @override
  String get diveCenters_hint_affiliationsDescription =>
      'Select training agencies this center is affiliated with';

  @override
  String get diveCenters_hint_city => 'e.g., Phuket';

  @override
  String get diveCenters_hint_country => 'e.g., Thailand';

  @override
  String get diveCenters_hint_email => 'info@divecenter.com';

  @override
  String get diveCenters_hint_gpsDescription =>
      'Choose a location method or enter coordinates manually';

  @override
  String get diveCenters_hint_importSearch =>
      'Search dive centers (e.g., \"PADI\", \"Thailand\")';

  @override
  String get diveCenters_hint_latitude => 'e.g., 10.4613';

  @override
  String get diveCenters_hint_longitude => 'e.g., 99.8359';

  @override
  String get diveCenters_hint_name => 'Enter dive center name';

  @override
  String get diveCenters_hint_notes => 'Any additional information...';

  @override
  String get diveCenters_hint_phone => '+1 234 567 890';

  @override
  String get diveCenters_hint_postalCode => 'e.g., 83100';

  @override
  String get diveCenters_hint_stateProvince => 'e.g., Phuket';

  @override
  String get diveCenters_hint_street => 'e.g., 123 Beach Road';

  @override
  String get diveCenters_hint_website => 'www.divecenter.com';

  @override
  String diveCenters_import_fromDatabase(Object count) {
    return 'Import from Database ($count)';
  }

  @override
  String diveCenters_import_myCenters(Object count) {
    return 'My Centers ($count)';
  }

  @override
  String get diveCenters_import_noResults => 'No Results';

  @override
  String diveCenters_import_noResultsMessage(Object query) {
    return 'No dive centers found for \"$query\". Try a different search term.';
  }

  @override
  String get diveCenters_import_searchDescription =>
      'Search for dive centers, shops, and clubs from our database of operators around the world.';

  @override
  String get diveCenters_import_searchError => 'Search Error';

  @override
  String get diveCenters_import_searchHint =>
      'Try searching by name, country, or certification agency.';

  @override
  String get diveCenters_import_searchTitle => 'Search Dive Centers';

  @override
  String get diveCenters_label_alreadyImported => 'Already Imported';

  @override
  String diveCenters_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives',
      one: '1 dive',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_label_email => 'Email';

  @override
  String get diveCenters_label_imported => 'Imported';

  @override
  String get diveCenters_label_locationNotSet => 'Location not set';

  @override
  String get diveCenters_label_locationUnknown => 'Location unknown';

  @override
  String get diveCenters_label_phone => 'Phone';

  @override
  String get diveCenters_label_saved => 'Saved';

  @override
  String diveCenters_label_source(Object source) {
    return 'Source: $source';
  }

  @override
  String get diveCenters_label_website => 'Website';

  @override
  String get diveCenters_map_addCoordinatesHint =>
      'Add coordinates to your dive centers to see them on the map';

  @override
  String get diveCenters_map_noCoordinates =>
      'No dive centers with coordinates';

  @override
  String get diveCenters_picker_newCenter => 'New Dive Center';

  @override
  String get diveCenters_picker_title => 'Select Dive Center';

  @override
  String diveCenters_search_noResults(Object query) {
    return 'No results for \"$query\"';
  }

  @override
  String get diveCenters_search_prompt => 'Search dive centers';

  @override
  String get diveCenters_section_address => 'Address';

  @override
  String get diveCenters_section_affiliations => 'Affiliations';

  @override
  String get diveCenters_section_basicInfo => 'Basic Information';

  @override
  String get diveCenters_section_contact => 'Contact';

  @override
  String get diveCenters_section_contactInfo => 'Contact Information';

  @override
  String get diveCenters_section_gpsCoordinates => 'GPS Coordinates';

  @override
  String get diveCenters_section_notes => 'Notes';

  @override
  String get diveCenters_snackbar_coordinatesFound =>
      'Coordinates found from address';

  @override
  String get diveCenters_snackbar_copiedToClipboard => 'Copied to clipboard';

  @override
  String diveCenters_snackbar_imported(Object name) {
    return 'Imported \"$name\"';
  }

  @override
  String get diveCenters_snackbar_locationCaptured => 'Location captured';

  @override
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Location captured (±${accuracy}m)';
  }

  @override
  String get diveCenters_snackbar_locationSelectedFromMap =>
      'Location selected from map';

  @override
  String get diveCenters_sort_title => 'Sort Dive Centers';

  @override
  String get diveCenters_summary_countries => 'Countries';

  @override
  String get diveCenters_summary_highestRating => 'Highest Rating';

  @override
  String get diveCenters_summary_overview => 'Overview';

  @override
  String get diveCenters_summary_quickActions => 'Quick Actions';

  @override
  String get diveCenters_summary_recentCenters => 'Recent Dive Centers';

  @override
  String get diveCenters_summary_selectPrompt =>
      'Select a dive center from the list to view details';

  @override
  String get diveCenters_summary_topRated => 'Top Rated';

  @override
  String get diveCenters_summary_totalCenters => 'Total Centers';

  @override
  String get diveCenters_summary_withGps => 'With GPS';

  @override
  String get diveCenters_title => 'Dive Centers';

  @override
  String get diveCenters_title_add => 'Add Dive Center';

  @override
  String get diveCenters_title_edit => 'Edit Dive Center';

  @override
  String get diveCenters_title_import => 'Import Dive Center';

  @override
  String get diveCenters_tooltip_addNew => 'Add a new dive center';

  @override
  String get diveCenters_tooltip_clearSearch => 'Clear search';

  @override
  String get diveCenters_tooltip_edit => 'Edit dive center';

  @override
  String get diveCenters_tooltip_fitAllCenters => 'Fit All Centers';

  @override
  String get diveCenters_tooltip_listView => 'List View';

  @override
  String get diveCenters_tooltip_mapView => 'Map View';

  @override
  String get diveCenters_tooltip_moreOptions => 'More options';

  @override
  String get diveCenters_tooltip_search => 'Search dive centers';

  @override
  String get diveCenters_tooltip_sort => 'Sort';

  @override
  String get diveCenters_validation_invalidEmail =>
      'Please enter a valid email';

  @override
  String get diveCenters_validation_invalidLatitude => 'Invalid latitude';

  @override
  String get diveCenters_validation_invalidLongitude => 'Invalid longitude';

  @override
  String get diveCenters_validation_nameRequired => 'Name is required';

  @override
  String get diveComputer_action_setFavorite => 'Set as favorite';

  @override
  String diveComputer_error_generic(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get diveComputer_error_notFound => 'Device not found';

  @override
  String get diveComputer_status_favorite => 'Favorite computer';

  @override
  String get diveComputer_title => 'Dive Computer';

  @override
  String diveLog_bulkDelete_confirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    return 'Are you sure you want to delete $count $_temp0? This action cannot be undone.';
  }

  @override
  String get diveLog_bulkDelete_restored => 'Dives restored';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    return 'Deleted $count $_temp0';
  }

  @override
  String get diveLog_bulkDelete_title => 'Delete Dives';

  @override
  String get diveLog_bulkDelete_undo => 'Undo';

  @override
  String get diveLog_bulkEdit_addTags => 'Add Tags';

  @override
  String get diveLog_bulkEdit_addTagsDescription =>
      'Add tags to selected dives';

  @override
  String diveLog_bulkEdit_addedTags(int tagCount, int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: 'tags',
      one: 'tag',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    return 'Added $tagCount $_temp0 to $diveCount $_temp1';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => 'Change Trip';

  @override
  String get diveLog_bulkEdit_changeTripDescription =>
      'Move selected dives to a trip';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips => 'Error loading trips';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return 'Failed to add tags: $error';
  }

  @override
  String diveLog_bulkEdit_failedUpdateTrip(Object error) {
    return 'Failed to update trip: $error';
  }

  @override
  String diveLog_bulkEdit_movedToTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    return 'Moved $count $_temp0 to trip';
  }

  @override
  String get diveLog_bulkEdit_noTagsAvailable => 'No tags available.';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate =>
      'No tags available. Create tags first.';

  @override
  String get diveLog_bulkEdit_noTrip => 'No Trip';

  @override
  String get diveLog_bulkEdit_removeFromTrip => 'Remove from trip';

  @override
  String get diveLog_bulkEdit_removeTags => 'Remove Tags';

  @override
  String get diveLog_bulkEdit_removeTagsDescription =>
      'Remove tags from selected dives';

  @override
  String diveLog_bulkEdit_removedFromTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    return 'Removed $count $_temp0 from trip';
  }

  @override
  String get diveLog_bulkEdit_selectTrip => 'Select Trip';

  @override
  String diveLog_bulkEdit_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dives',
      one: 'Dive',
    );
    return 'Edit $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_csv => 'CSV';

  @override
  String get diveLog_bulkExport_csvDescription => 'Spreadsheet format';

  @override
  String diveLog_bulkExport_failed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get diveLog_bulkExport_pdf => 'PDF Logbook';

  @override
  String get diveLog_bulkExport_pdfDescription => 'Printable dive log pages';

  @override
  String diveLog_bulkExport_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    return 'Exported $count $_temp0 successfully';
  }

  @override
  String diveLog_bulkExport_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dives',
      one: 'Dive',
    );
    return 'Export $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_uddf => 'UDDF';

  @override
  String get diveLog_bulkExport_uddfDescription => 'Universal Dive Data Format';

  @override
  String get diveLog_ccr_diluent_air => 'Air';

  @override
  String get diveLog_ccr_hint_loopVolume => 'e.g., 6.0';

  @override
  String get diveLog_ccr_hint_type => 'e.g., Sofnolime';

  @override
  String get diveLog_ccr_label_deco => 'Deco';

  @override
  String get diveLog_ccr_label_he => 'He';

  @override
  String get diveLog_ccr_label_highBottom => 'High (Bottom)';

  @override
  String get diveLog_ccr_label_loopVolume => 'Loop Volume';

  @override
  String get diveLog_ccr_label_lowDescAsc => 'Low (Desc/Asc)';

  @override
  String get diveLog_ccr_label_n2 => 'N₂';

  @override
  String get diveLog_ccr_label_o2 => 'O₂';

  @override
  String get diveLog_ccr_label_rated => 'Rated';

  @override
  String get diveLog_ccr_label_remaining => 'Remaining';

  @override
  String get diveLog_ccr_label_type => 'Type';

  @override
  String get diveLog_ccr_sectionDiluentGas => 'Diluent Gas';

  @override
  String get diveLog_ccr_sectionScrubber => 'Scrubber';

  @override
  String get diveLog_ccr_sectionSetpoints => 'Setpoints (bar)';

  @override
  String get diveLog_ccr_title => 'CCR Settings';

  @override
  String diveLog_collapsible_semantics_collapse(Object title) {
    return 'Collapse $title section';
  }

  @override
  String diveLog_collapsible_semantics_expand(Object title) {
    return 'Expand $title section';
  }

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return 'Avg: $depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => 'Basic';

  @override
  String get diveLog_cylinderSac_noSac => 'SAC: --';

  @override
  String get diveLog_cylinderSac_tooltip_aiData =>
      'Using AI transmitter data for higher accuracy';

  @override
  String get diveLog_cylinderSac_tooltip_basicData =>
      'Calculated from start/end pressures';

  @override
  String get diveLog_deco_badge_deco => 'DECO';

  @override
  String get diveLog_deco_badge_noDeco => 'NO DECO';

  @override
  String get diveLog_deco_label_ceiling => 'Ceiling';

  @override
  String get diveLog_deco_label_leading => 'Leading';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String get diveLog_deco_sectionDecoStops => 'Deco Stops';

  @override
  String get diveLog_deco_sectionTissueLoading => 'Tissue Loading';

  @override
  String get diveLog_deco_semantics_notRequired => 'No decompression required';

  @override
  String get diveLog_deco_semantics_required => 'Decompression required';

  @override
  String get diveLog_deco_tissueFast => 'Fast';

  @override
  String get diveLog_deco_tissueSlow => 'Slow';

  @override
  String get diveLog_deco_title => 'Decompression Status';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return 'Total: $time';
  }

  @override
  String get diveLog_delete_cancel => 'Cancel';

  @override
  String get diveLog_delete_confirm =>
      'This action cannot be undone. The dive and all associated data (profile, tanks, sightings) will be permanently deleted.';

  @override
  String get diveLog_delete_delete => 'Delete';

  @override
  String get diveLog_delete_title => 'Delete Dive?';

  @override
  String get diveLog_detail_appBar => 'Dive Details';

  @override
  String get diveLog_detail_badge_critical => 'CRITICAL';

  @override
  String get diveLog_detail_badge_deco => 'DECO';

  @override
  String get diveLog_detail_badge_noDeco => 'NO DECO';

  @override
  String get diveLog_detail_badge_warning => 'WARNING';

  @override
  String diveLog_detail_buddyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'buddies',
      one: 'buddy',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_button_playback => 'Playback';

  @override
  String get diveLog_detail_button_rangeAnalysis => 'Range Analysis';

  @override
  String get diveLog_detail_button_showEnd => 'Show end';

  @override
  String get diveLog_detail_captureSignature => 'Capture Instructor Signature';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return 'At $timestamp';
  }

  @override
  String diveLog_detail_collapsed_atTimeInfo(
    Object timestamp,
    Object baseInfo,
  ) {
    return 'At $timestamp • $baseInfo';
  }

  @override
  String diveLog_detail_collapsed_ceiling(Object value) {
    return 'Ceiling: $value';
  }

  @override
  String diveLog_detail_collapsed_cnsMaxPpO2(Object cns, Object maxPpO2) {
    return 'CNS: $cns • Max ppO₂: $maxPpO2';
  }

  @override
  String diveLog_detail_collapsed_cnsMaxPpO2AtTime(
    Object cns,
    Object maxPpO2,
    Object timestamp,
    Object ppO2,
  ) {
    return 'CNS: $cns • Max ppO₂: $maxPpO2 • At $timestamp: $ppO2 bar';
  }

  @override
  String diveLog_detail_collapsed_ndl(Object value) {
    return 'NDL: $value';
  }

  @override
  String diveLog_detail_customFieldCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields',
      one: '1 field',
    );
    return '$_temp0';
  }

  @override
  String diveLog_detail_equipmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_errorLoading => 'Error loading dive';

  @override
  String get diveLog_detail_fullscreen_sampleData => 'Sample Data';

  @override
  String get diveLog_detail_fullscreen_tapChartCompact =>
      'Tap chart for compact view';

  @override
  String get diveLog_detail_fullscreen_tapChartFull =>
      'Tap chart for full-screen view';

  @override
  String get diveLog_detail_fullscreen_touchChart =>
      'Touch the chart to see data at that point';

  @override
  String get diveLog_detail_label_airTemp => 'Air Temp';

  @override
  String get diveLog_detail_label_avgDepth => 'Avg Depth';

  @override
  String get diveLog_detail_label_buddy => 'Buddy';

  @override
  String get diveLog_detail_label_currentDirection => 'Current Direction';

  @override
  String get diveLog_detail_label_currentStrength => 'Current Strength';

  @override
  String get diveLog_detail_label_diveComputer => 'Dive Computer';

  @override
  String get diveLog_detail_label_serialNumber => 'Serial Number';

  @override
  String get diveLog_detail_label_firmwareVersion => 'Firmware Version';

  @override
  String get diveLog_detail_label_diveMaster => 'Dive Master';

  @override
  String get diveLog_detail_label_diveType => 'Dive Type';

  @override
  String get diveLog_detail_label_elevation => 'Elevation';

  @override
  String get diveLog_detail_label_entry => 'Entry:';

  @override
  String get diveLog_detail_label_entryMethod => 'Entry Method';

  @override
  String get diveLog_detail_label_exit => 'Exit:';

  @override
  String get diveLog_detail_label_exitMethod => 'Exit Method';

  @override
  String get diveLog_detail_label_gradientFactors => 'Gradient Factors';

  @override
  String get diveLog_detail_label_height => 'Height';

  @override
  String get diveLog_detail_label_highTide => 'High Tide';

  @override
  String get diveLog_detail_label_lowTide => 'Low Tide';

  @override
  String get diveLog_detail_label_ppO2AtPoint => 'ppO₂ at selected point:';

  @override
  String get diveLog_detail_label_rateOfChange => 'Rate of Change';

  @override
  String get diveLog_detail_label_sacRate => 'SAC Rate';

  @override
  String get diveLog_detail_label_state => 'State';

  @override
  String get diveLog_detail_label_surfaceInterval => 'Surface Interval';

  @override
  String get diveLog_detail_label_surfacePressure => 'Surface Pressure';

  @override
  String get diveLog_detail_label_swellHeight => 'Swell Height';

  @override
  String get diveLog_detail_label_total => 'Total:';

  @override
  String get diveLog_detail_label_visibility => 'Visibility';

  @override
  String get diveLog_detail_label_waterType => 'Water Type';

  @override
  String get diveLog_detail_menu_delete => 'Delete';

  @override
  String get diveLog_detail_menu_export => 'Export';

  @override
  String get diveLog_detail_menu_openFullPage => 'Open Full Page';

  @override
  String get diveLog_detail_noNotes => 'No notes for this dive.';

  @override
  String get diveLog_detail_notFound => 'Dive not found';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count points';
  }

  @override
  String get diveLog_detail_section_altitudeDive => 'Altitude Dive';

  @override
  String get diveLog_detail_section_buddies => 'Buddies';

  @override
  String get diveLog_detail_section_conditions => 'Conditions';

  @override
  String get diveLog_detail_section_customFields => 'Custom Fields';

  @override
  String get diveLog_detail_section_decoStatus => 'Decompression Status';

  @override
  String get diveLog_detail_section_details => 'Details';

  @override
  String get diveLog_detail_section_diveProfile => 'Dive Profile';

  @override
  String get diveLog_detail_section_equipment => 'Equipment';

  @override
  String get diveLog_detail_section_marineLife => 'Marine Life';

  @override
  String get diveLog_detail_section_notes => 'Notes';

  @override
  String get diveLog_detail_section_oxygenToxicity => 'Oxygen Toxicity';

  @override
  String get diveLog_detail_section_sacByCylinder => 'SAC by Cylinder';

  @override
  String get diveLog_detail_section_sacRateBySegment => 'SAC Rate by Segment';

  @override
  String get diveLog_detail_section_tags => 'Tags';

  @override
  String get diveLog_detail_section_tanks => 'Tanks';

  @override
  String get diveLog_detail_section_tide => 'Tide';

  @override
  String get diveLog_detail_section_trainingSignature => 'Training Signature';

  @override
  String get diveLog_detail_section_weight => 'Weight';

  @override
  String get diveLog_detail_signatureDescription =>
      'Tap to add instructor verification for this training dive';

  @override
  String get diveLog_detail_soloDive => 'Solo dive or no buddies recorded';

  @override
  String diveLog_detail_speciesCount(Object count) {
    return '$count species';
  }

  @override
  String get diveLog_detail_stat_bottomTime => 'Bottom Time';

  @override
  String get diveLog_detail_stat_maxDepth => 'Max Depth';

  @override
  String get diveLog_detail_stat_runtime => 'Runtime';

  @override
  String get diveLog_detail_stat_waterTemp => 'Water Temp';

  @override
  String diveLog_detail_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tags',
      one: 'tag',
    );
    return '$count $_temp0';
  }

  @override
  String diveLog_detail_tankCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tanks',
      one: 'tank',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_tideCalculated => 'Calculated from tide model';

  @override
  String get diveLog_detail_tooltip_addToFavorites => 'Add to favorites';

  @override
  String get diveLog_detail_tooltip_edit => 'Edit';

  @override
  String get diveLog_detail_tooltip_editDive => 'Edit dive';

  @override
  String get diveLog_detail_tooltip_exportProfileImage =>
      'Export profile as image';

  @override
  String get diveLog_detail_tooltip_removeFromFavorites =>
      'Remove from favorites';

  @override
  String get diveLog_detail_tooltip_viewFullscreen => 'View fullscreen';

  @override
  String get diveLog_detail_viewSite => 'View Site';

  @override
  String get diveLog_diveMode_ccrDescription =>
      'Closed circuit rebreather with constant ppO₂';

  @override
  String get diveLog_diveMode_ocDescription =>
      'Standard open circuit scuba with tanks';

  @override
  String get diveLog_diveMode_scrDescription =>
      'Semi-closed rebreather with variable ppO₂';

  @override
  String get diveLog_diveMode_title => 'Dive Mode';

  @override
  String get diveLog_editSighting_count => 'Count';

  @override
  String get diveLog_editSighting_notes => 'Notes';

  @override
  String get diveLog_editSighting_notesHint => 'Size, behavior, location...';

  @override
  String get diveLog_editSighting_remove => 'Remove';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return 'Remove $name from this dive?';
  }

  @override
  String get diveLog_editSighting_removeTitle => 'Remove Sighting?';

  @override
  String get diveLog_editSighting_save => 'Save Changes';

  @override
  String get diveLog_edit_add => 'Add';

  @override
  String get diveLog_edit_addCustomField => 'Add Field';

  @override
  String get diveLog_edit_addTank => 'Add Tank';

  @override
  String get diveLog_edit_addWeightEntry => 'Add Weight Entry';

  @override
  String diveLog_edit_addedGps(Object name) {
    return 'Added GPS to $name';
  }

  @override
  String get diveLog_edit_appBarEdit => 'Edit Dive';

  @override
  String get diveLog_edit_appBarNew => 'Log Dive';

  @override
  String get diveLog_edit_cancel => 'Cancel';

  @override
  String get diveLog_edit_clearAllEquipment => 'Clear All';

  @override
  String diveLog_edit_createdSite(Object name) {
    return 'Created site: $name';
  }

  @override
  String get diveLog_edit_customFieldKey => 'Key';

  @override
  String get diveLog_edit_customFieldKeyHint => 'e.g., camera_settings';

  @override
  String get diveLog_edit_customFieldValue => 'Value';

  @override
  String get diveLog_edit_customFieldValueHint => 'e.g., f/8 ISO400';

  @override
  String diveLog_edit_durationMinutes(Object minutes) {
    return 'Duration: $minutes min';
  }

  @override
  String get diveLog_edit_equipmentHint =>
      'Tap \"Use Set\" or \"Add\" to select equipment';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return 'Error loading dive types: $error';
  }

  @override
  String get diveLog_edit_gettingLocation => 'Getting location...';

  @override
  String get diveLog_edit_headerNew => 'Log New Dive';

  @override
  String get diveLog_edit_label_airTemp => 'Air Temp';

  @override
  String get diveLog_edit_label_altitude => 'Altitude';

  @override
  String get diveLog_edit_label_avgDepth => 'Avg Depth';

  @override
  String get diveLog_edit_label_bottomTime => 'Bottom Time';

  @override
  String get diveLog_edit_label_currentDirection => 'Current Direction';

  @override
  String get diveLog_edit_label_currentStrength => 'Current Strength';

  @override
  String get diveLog_edit_label_diveType => 'Dive Type';

  @override
  String get diveLog_edit_label_entryMethod => 'Entry Method';

  @override
  String get diveLog_edit_label_exitMethod => 'Exit Method';

  @override
  String get diveLog_edit_label_maxDepth => 'Max Depth';

  @override
  String get diveLog_edit_label_runtime => 'Runtime';

  @override
  String get diveLog_edit_label_surfacePressure => 'Surface Pressure';

  @override
  String get diveLog_edit_label_swellHeight => 'Swell Height';

  @override
  String get diveLog_edit_label_type => 'Type';

  @override
  String get diveLog_edit_label_visibility => 'Visibility';

  @override
  String get diveLog_edit_label_waterTemp => 'Water Temp';

  @override
  String get diveLog_edit_label_waterType => 'Water Type';

  @override
  String get diveLog_edit_marineLifeHint => 'Tap \"Add\" to record sightings';

  @override
  String get diveLog_edit_nearbySitesFirst => 'Nearby sites first';

  @override
  String get diveLog_edit_noEquipmentSelected => 'No equipment selected';

  @override
  String get diveLog_edit_noMarineLife => 'No marine life logged';

  @override
  String get diveLog_edit_notSpecified => 'Not specified';

  @override
  String get diveLog_edit_notesHint => 'Add notes about this dive...';

  @override
  String get diveLog_edit_save => 'Save';

  @override
  String get diveLog_edit_saveAsSet => 'Save as Set';

  @override
  String diveLog_edit_saveAsSetDialog_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return 'Save $count $_temp0 as a new equipment set.';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description =>
      'Description (optional)';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint =>
      'e.g., Light gear for warm water';

  @override
  String diveLog_edit_saveAsSetDialog_error(Object error) {
    return 'Error creating set: $error';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_setName => 'Set Name';

  @override
  String get diveLog_edit_saveAsSetDialog_setNameHint =>
      'e.g., Tropical Diving';

  @override
  String diveLog_edit_saveAsSetDialog_success(Object name) {
    return 'Equipment set \"$name\" created';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title => 'Save as Equipment Set';

  @override
  String get diveLog_edit_saveAsSetDialog_validation =>
      'Please enter a set name';

  @override
  String get diveLog_edit_section_conditions => 'Conditions';

  @override
  String get diveLog_edit_section_customFields => 'Custom Fields';

  @override
  String get diveLog_edit_section_depthDuration => 'Depth & Duration';

  @override
  String get diveLog_edit_section_diveCenter => 'Dive Center';

  @override
  String get diveLog_edit_section_diveSite => 'Dive Site';

  @override
  String get diveLog_edit_section_entryTime => 'Entry Time';

  @override
  String get diveLog_edit_section_equipment => 'Equipment';

  @override
  String get diveLog_edit_section_exitTime => 'Exit Time';

  @override
  String get diveLog_edit_section_marineLife => 'Marine Life';

  @override
  String get diveLog_edit_section_notes => 'Notes';

  @override
  String get diveLog_edit_section_rating => 'Rating';

  @override
  String get diveLog_edit_section_tags => 'Tags';

  @override
  String diveLog_edit_section_tanks(Object count) {
    return 'Tanks ($count)';
  }

  @override
  String get diveLog_edit_section_trainingCourse => 'Training Course';

  @override
  String get diveLog_edit_section_trip => 'Trip';

  @override
  String get diveLog_edit_section_weight => 'Weight';

  @override
  String get diveLog_edit_select => 'Select';

  @override
  String get diveLog_edit_selectDiveCenter => 'Select Dive Center';

  @override
  String get diveLog_edit_selectDiveSite => 'Select Dive Site';

  @override
  String get diveLog_edit_selectTrip => 'Select Trip';

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Bottom time calculated: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Error saving dive: $error';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'No dive profile data available';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Unable to calculate bottom time from profile';

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return 'Surface Interval: $interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint =>
      'Standard: 1013 mbar at sea level';

  @override
  String get diveLog_edit_tooltip_calculateFromProfile =>
      'Calculate from dive profile';

  @override
  String get diveLog_edit_tooltip_clearDiveCenter => 'Clear dive center';

  @override
  String get diveLog_edit_tooltip_clearSite => 'Clear site';

  @override
  String get diveLog_edit_tooltip_clearTrip => 'Clear trip';

  @override
  String get diveLog_edit_tooltip_removeEquipment => 'Remove equipment';

  @override
  String get diveLog_edit_tooltip_removeSighting => 'Remove sighting';

  @override
  String get diveLog_edit_tooltip_removeWeight => 'Remove';

  @override
  String get diveLog_edit_trainingCourseHint =>
      'Link this dive to a training course';

  @override
  String diveLog_edit_tripSuggested(Object name) {
    return 'Suggested: $name';
  }

  @override
  String get diveLog_edit_tripUse => 'Use';

  @override
  String get diveLog_edit_useSet => 'Use Set';

  @override
  String diveLog_edit_weightTotal(Object total) {
    return 'Total: $total';
  }

  @override
  String get diveLog_emptyFiltered_clearFilters => 'Clear Filters';

  @override
  String get diveLog_emptyFiltered_subtitle =>
      'Try adjusting or clearing your filters';

  @override
  String get diveLog_emptyFiltered_title => 'No dives match your filters';

  @override
  String get diveLog_empty_logFirstDive => 'Log Your First Dive';

  @override
  String get diveLog_empty_subtitle =>
      'Tap the button below to log your first dive';

  @override
  String get diveLog_empty_title => 'No dives logged yet';

  @override
  String get diveLog_equipmentPicker_addFromTab =>
      'Add equipment from the Equipment tab';

  @override
  String get diveLog_equipmentPicker_allSelected =>
      'All equipment already selected';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return 'Error loading equipment: $error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => 'No equipment yet';

  @override
  String get diveLog_equipmentPicker_removeToAdd =>
      'Remove items to add different ones';

  @override
  String get diveLog_equipmentPicker_title => 'Add Equipment';

  @override
  String get diveLog_equipmentSetPicker_createHint =>
      'Create sets in Equipment > Sets';

  @override
  String get diveLog_equipmentSetPicker_emptySet => 'Empty set';

  @override
  String get diveLog_equipmentSetPicker_errorItems => 'Error loading items';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return 'Error loading equipment sets: $error';
  }

  @override
  String get diveLog_equipmentSetPicker_loading => 'Loading...';

  @override
  String get diveLog_equipmentSetPicker_noSets => 'No equipment sets yet';

  @override
  String get diveLog_equipmentSetPicker_title => 'Use Equipment Set';

  @override
  String get diveLog_error_loadingDives => 'Error loading dives';

  @override
  String get diveLog_error_retry => 'Retry';

  @override
  String get diveLog_exportImage_captureFailed => 'Could not capture image';

  @override
  String get diveLog_exportImage_generateFailed => 'Could not generate image';

  @override
  String get diveLog_exportImage_generatingPdf => 'Generating PDF...';

  @override
  String get diveLog_exportImage_pdfSaved => 'PDF saved';

  @override
  String get diveLog_exportImage_saveToFiles => 'Save to Files';

  @override
  String get diveLog_exportImage_saveToFilesDescription =>
      'Choose a location to save the file';

  @override
  String get diveLog_exportImage_saveToPhotos => 'Save to Photos';

  @override
  String get diveLog_exportImage_saveToPhotosDescription =>
      'Save image to your photo library';

  @override
  String get diveLog_exportImage_savedToFiles => 'Image saved';

  @override
  String get diveLog_exportImage_savedToPhotos => 'Image saved to Photos';

  @override
  String get diveLog_exportImage_share => 'Share';

  @override
  String get diveLog_exportImage_shareDescription => 'Share via other apps';

  @override
  String get diveLog_exportImage_titleDetails => 'Export Dive Details Image';

  @override
  String get diveLog_exportImage_titlePdf => 'Export PDF';

  @override
  String get diveLog_exportImage_titleProfile => 'Export Profile Image';

  @override
  String get diveLog_export_csv => 'CSV';

  @override
  String get diveLog_export_csvDescription => 'Spreadsheet format';

  @override
  String get diveLog_export_exporting => 'Exporting...';

  @override
  String diveLog_export_failed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get diveLog_export_pageAsImage => 'Page as Image';

  @override
  String get diveLog_export_pageAsImageDescription =>
      'Screenshot of entire dive details';

  @override
  String get diveLog_export_pdfDescription => 'Printable dive log page';

  @override
  String get diveLog_export_pdfLogbookEntry => 'PDF Logbook Entry';

  @override
  String get diveLog_export_success => 'Dive exported successfully';

  @override
  String diveLog_export_titleDiveNumber(Object number) {
    return 'Export Dive #$number';
  }

  @override
  String get diveLog_export_uddf => 'UDDF';

  @override
  String get diveLog_export_uddfDescription => 'Universal Dive Data Format';

  @override
  String get diveLog_filterChip_clearAll => 'Clear all';

  @override
  String get diveLog_filterChip_favorites => 'Favorites';

  @override
  String diveLog_filterChip_from(Object date) {
    return 'From $date';
  }

  @override
  String diveLog_filterChip_until(Object date) {
    return 'Until $date';
  }

  @override
  String get diveLog_filter_allSites => 'All sites';

  @override
  String get diveLog_filter_allTypes => 'All types';

  @override
  String get diveLog_filter_apply => 'Apply Filters';

  @override
  String get diveLog_filter_buddyHint => 'Search by buddy name';

  @override
  String get diveLog_filter_buddyName => 'Buddy Name';

  @override
  String get diveLog_filter_clearAll => 'Clear All';

  @override
  String get diveLog_filter_clearDates => 'Clear dates';

  @override
  String get diveLog_filter_clearRating => 'Clear rating filter';

  @override
  String get diveLog_filter_dateSeparator => 'to';

  @override
  String get diveLog_filter_endDate => 'End Date';

  @override
  String get diveLog_filter_errorLoadingSites => 'Error loading sites';

  @override
  String get diveLog_filter_errorLoadingTags => 'Error loading tags';

  @override
  String get diveLog_filter_favoritesOnly => 'Favorites Only';

  @override
  String get diveLog_filter_gasAir => 'Air (21%)';

  @override
  String get diveLog_filter_gasAll => 'All';

  @override
  String get diveLog_filter_gasNitrox => 'Nitrox (>21%)';

  @override
  String get diveLog_filter_max => 'Max';

  @override
  String get diveLog_filter_min => 'Min';

  @override
  String get diveLog_filter_noTagsYet => 'No tags created yet';

  @override
  String get diveLog_filter_sectionBuddy => 'Buddy';

  @override
  String get diveLog_filter_sectionDateRange => 'Date Range';

  @override
  String get diveLog_filter_sectionDepthRange => 'Depth Range (meters)';

  @override
  String get diveLog_filter_sectionDiveSite => 'Dive Site';

  @override
  String get diveLog_filter_sectionDiveType => 'Dive Type';

  @override
  String get diveLog_filter_sectionDuration => 'Duration (minutes)';

  @override
  String get diveLog_filter_sectionGasMix => 'Gas Mix (O₂%)';

  @override
  String get diveLog_filter_sectionMinRating => 'Minimum Rating';

  @override
  String get diveLog_filter_sectionTags => 'Tags';

  @override
  String get diveLog_filter_showOnlyFavorites => 'Show only favorite dives';

  @override
  String get diveLog_filter_startDate => 'Start Date';

  @override
  String get diveLog_filter_title => 'Filter Dives';

  @override
  String get diveLog_filter_tooltip_close => 'Close filter';

  @override
  String get diveLog_fullscreenProfile_close => 'Close fullscreen';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Dive #$number Profile';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Ascent Rate';

  @override
  String get diveLog_legend_label_ceiling => 'Ceiling';

  @override
  String get diveLog_legend_label_depth => 'Depth';

  @override
  String get diveLog_legend_label_events => 'Events';

  @override
  String get diveLog_legend_label_gasDensity => 'Gas Density';

  @override
  String get diveLog_legend_label_gasSwitches => 'Gas Switches';

  @override
  String get diveLog_legend_label_gfPercent => 'GF%';

  @override
  String get diveLog_legend_label_heartRate => 'Heart Rate';

  @override
  String get diveLog_legend_label_maxDepth => 'Max Depth';

  @override
  String get diveLog_legend_label_meanDepth => 'Mean Depth';

  @override
  String get diveLog_legend_label_mod => 'MOD';

  @override
  String get diveLog_legend_label_ndl => 'NDL';

  @override
  String get diveLog_legend_label_ppHe => 'ppHe';

  @override
  String get diveLog_legend_label_ppN2 => 'ppN2';

  @override
  String get diveLog_legend_label_ppO2 => 'ppO2';

  @override
  String get diveLog_legend_label_pressure => 'Pressure';

  @override
  String get diveLog_legend_label_pressureThresholds => 'Pressure Thresholds';

  @override
  String get diveLog_legend_label_sacRate => 'SAC Rate';

  @override
  String get diveLog_legend_label_surfaceGf => 'Surface GF';

  @override
  String get diveLog_legend_label_temp => 'Temp';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Dive Map';

  @override
  String get diveLog_listPage_compactTitle => 'Dives';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Error: $error';
  }

  @override
  String get diveLog_listPage_bottomSheet_importFromComputer =>
      'Import from Computer';

  @override
  String get diveLog_listPage_bottomSheet_logManually => 'Log Dive Manually';

  @override
  String get diveLog_listPage_fab_addDive => 'Add Dive';

  @override
  String get diveLog_listPage_fab_logDive => 'Log Dive';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Advanced Search';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Dive Numbering';

  @override
  String get diveLog_listPage_searchFieldLabel => 'Search dives...';

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return 'No dives found for \"$query\"';
  }

  @override
  String get diveLog_listPage_searchSuggestion =>
      'Search by site, buddy, or notes';

  @override
  String get diveLog_listPage_title => 'Dive Log';

  @override
  String get diveLog_listPage_tooltip_back => 'Back';

  @override
  String get diveLog_listPage_tooltip_backToDiveList => 'Back to dive list';

  @override
  String get diveLog_listPage_tooltip_clearSearch => 'Clear search';

  @override
  String get diveLog_listPage_tooltip_filterDives => 'Filter dives';

  @override
  String get diveLog_listPage_tooltip_listView => 'List View';

  @override
  String get diveLog_listPage_tooltip_mapView => 'Map View';

  @override
  String get diveLog_listPage_tooltip_searchDives => 'Search dives';

  @override
  String get diveLog_listPage_tooltip_sort => 'Sort';

  @override
  String get diveLog_listPage_unknownSite => 'Unknown Site';

  @override
  String get diveLog_map_emptySubtitle =>
      'Log dives with location data to see your activity on the map';

  @override
  String get diveLog_map_emptyTitle => 'No dive activity to display';

  @override
  String diveLog_map_errorLoading(Object error) {
    return 'Error loading dive data: $error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => 'Fit All Sites';

  @override
  String get diveLog_numbering_actions => 'Actions';

  @override
  String get diveLog_numbering_allCorrect => 'All dives numbered correctly';

  @override
  String get diveLog_numbering_assignMissing => 'Assign missing numbers';

  @override
  String get diveLog_numbering_assignMissingDesc =>
      'Number unnumbered dives starting after the last numbered dive';

  @override
  String get diveLog_numbering_close => 'Close';

  @override
  String get diveLog_numbering_gapsDetected => 'Gaps Detected';

  @override
  String get diveLog_numbering_issuesDetected => 'Issues detected';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '$count missing';
  }

  @override
  String get diveLog_numbering_renumberAll => 'Renumber all dives';

  @override
  String get diveLog_numbering_renumberAllDesc =>
      'Assign sequential numbers based on dive date/time';

  @override
  String get diveLog_numbering_renumberDialog_cancel => 'Cancel';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      'This will renumber all dives sequentially based on their entry date/time. This action cannot be undone.';

  @override
  String get diveLog_numbering_renumberDialog_renumber => 'Renumber';

  @override
  String get diveLog_numbering_renumberDialog_startFrom => 'Start from number';

  @override
  String get diveLog_numbering_renumberDialog_title => 'Renumber All Dives';

  @override
  String get diveLog_numbering_snackbar_assigned =>
      'Missing dive numbers assigned';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return 'All dives renumbered starting from #$number';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '$total total dives • $numbered numbered';
  }

  @override
  String get diveLog_numbering_title => 'Dive Numbering';

  @override
  String diveLog_numbering_unnumberedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    return '$count $_temp0 without numbers';
  }

  @override
  String get diveLog_o2tox_badge_critical => 'CRITICAL';

  @override
  String get diveLog_o2tox_badge_warning => 'WARNING';

  @override
  String diveLog_o2tox_cnsBadgeLabel(Object value) {
    return 'CNS $value';
  }

  @override
  String get diveLog_o2tox_cnsOxygenClock => 'CNS Oxygen Clock';

  @override
  String diveLog_o2tox_deltaDive(Object value) {
    return '+$value% this dive';
  }

  @override
  String get diveLog_o2tox_details => 'Details';

  @override
  String get diveLog_o2tox_label_maxPpO2 => 'Max ppO2';

  @override
  String get diveLog_o2tox_label_maxPpO2Depth => 'Max ppO2 Depth';

  @override
  String get diveLog_o2tox_label_timeAbove14 => 'Time above 1.4 bar';

  @override
  String get diveLog_o2tox_label_timeAbove16 => 'Time above 1.6 bar';

  @override
  String get diveLog_o2tox_ofDailyLimit => 'of daily limit';

  @override
  String get diveLog_o2tox_oxygenToleranceUnits => 'Oxygen Tolerance Units';

  @override
  String diveLog_o2tox_semantics_cnsBadge(Object value) {
    return 'CNS oxygen toxicity $value';
  }

  @override
  String get diveLog_o2tox_semantics_criticalWarning =>
      'Critical oxygen toxicity warning';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return 'Oxygen Tolerance Units: $value, $percent percent of daily limit';
  }

  @override
  String get diveLog_o2tox_semantics_warning => 'Oxygen toxicity warning';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return 'Start: $value%';
  }

  @override
  String get diveLog_o2tox_title => 'Oxygen Toxicity';

  @override
  String get diveLog_playbackStats_deco => 'DECO';

  @override
  String get diveLog_playbackStats_depth => 'Depth';

  @override
  String get diveLog_playbackStats_header => 'Live Stats';

  @override
  String get diveLog_playbackStats_heartRate => 'Heart Rate';

  @override
  String get diveLog_playbackStats_ndl => 'NDL';

  @override
  String get diveLog_playbackStats_ppO2 => 'ppO₂';

  @override
  String get diveLog_playbackStats_pressure => 'Pressure';

  @override
  String get diveLog_playbackStats_temp => 'Temp';

  @override
  String get diveLog_playback_sliderLabel => 'Playback position';

  @override
  String diveLog_playback_speed_label(Object speed) {
    return '${speed}x';
  }

  @override
  String get diveLog_playback_stepThrough => 'Step-through Playback';

  @override
  String get diveLog_playback_tooltip_back10 => 'Back 10 seconds';

  @override
  String get diveLog_playback_tooltip_exit => 'Exit playback mode';

  @override
  String get diveLog_playback_tooltip_forward10 => 'Forward 10 seconds';

  @override
  String get diveLog_playback_tooltip_pause => 'Pause';

  @override
  String get diveLog_playback_tooltip_play => 'Play';

  @override
  String get diveLog_playback_tooltip_skipEnd => 'Skip to end';

  @override
  String get diveLog_playback_tooltip_skipStart => 'Skip to start';

  @override
  String get diveLog_playback_tooltip_speed => 'Playback speed';

  @override
  String get diveLog_profileSelector_badge_primary => 'Primary';

  @override
  String get diveLog_profileSelector_label_diveComputers => 'Dive Computers';

  @override
  String diveLog_profile_axisDepth(Object unit) {
    return 'Depth ($unit)';
  }

  @override
  String get diveLog_profile_axisTime => 'Time (min)';

  @override
  String get diveLog_profile_emptyState => 'No dive profile data';

  @override
  String get diveLog_profile_rightAxis_none => 'None';

  @override
  String get diveLog_profile_semantics_changeRightAxis =>
      'Change right axis metric';

  @override
  String get diveLog_profile_semantics_chart =>
      'Dive profile chart, pinch to zoom';

  @override
  String get diveLog_profile_tooltip_moreOptions => 'More chart options';

  @override
  String get diveLog_profile_tooltip_resetZoom => 'Reset zoom';

  @override
  String get diveLog_profile_tooltip_zoomIn => 'Zoom in';

  @override
  String get diveLog_profile_tooltip_zoomOut => 'Zoom out';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return 'Zoom: ${level}x • Pinch or scroll to zoom, drag to pan';
  }

  @override
  String get diveLog_rangeSelection_exitRange => 'Exit Range';

  @override
  String get diveLog_rangeSelection_selectRange => 'Select Range';

  @override
  String get diveLog_rangeSelection_semantics_adjust =>
      'Adjust range selection';

  @override
  String get diveLog_rangeStats_header_avg => 'Avg';

  @override
  String get diveLog_rangeStats_header_max => 'Max';

  @override
  String get diveLog_rangeStats_header_min => 'Min';

  @override
  String get diveLog_rangeStats_label_depth => 'Depth';

  @override
  String get diveLog_rangeStats_label_heartRate => 'Heart Rate';

  @override
  String get diveLog_rangeStats_label_pressure => 'Pressure';

  @override
  String get diveLog_rangeStats_label_temp => 'Temp';

  @override
  String get diveLog_rangeStats_title => 'Range Analysis';

  @override
  String get diveLog_rangeStats_tooltip_close => 'Close range analysis';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return 'Calculated loop FO₂: $value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => 'e.g., 0.33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => 'Addition Ratio';

  @override
  String get diveLog_scr_label_assumedVo2 => 'Assumed VO₂';

  @override
  String get diveLog_scr_label_avg => 'Avg';

  @override
  String get diveLog_scr_label_injectionRate => 'Injection Rate';

  @override
  String get diveLog_scr_label_max => 'Max';

  @override
  String get diveLog_scr_label_min => 'Min';

  @override
  String get diveLog_scr_label_orificeSize => 'Orifice Size';

  @override
  String get diveLog_scr_sectionCmf => 'CMF Parameters';

  @override
  String get diveLog_scr_sectionEscr => 'ESCR Parameters';

  @override
  String get diveLog_scr_sectionMeasuredLoopO2 => 'Measured Loop O₂ (optional)';

  @override
  String get diveLog_scr_sectionPascr => 'PASCR Parameters';

  @override
  String get diveLog_scr_sectionScrType => 'SCR Type';

  @override
  String get diveLog_scr_sectionSupplyGas => 'Supply Gas';

  @override
  String get diveLog_scr_title => 'SCR Settings';

  @override
  String get diveLog_search_allCenters => 'All centers';

  @override
  String get diveLog_search_allTrips => 'All trips';

  @override
  String get diveLog_search_appBar => 'Advanced Search';

  @override
  String get diveLog_search_cancel => 'Cancel';

  @override
  String get diveLog_search_clearAll => 'Clear All';

  @override
  String get diveLog_search_customFieldKey => 'Custom Field Key';

  @override
  String get diveLog_search_customFieldValue => 'Value contains...';

  @override
  String get diveLog_search_end => 'End';

  @override
  String get diveLog_search_errorLoadingCenters => 'Error loading dive centers';

  @override
  String get diveLog_search_errorLoadingDiveTypes => 'Error loading dive types';

  @override
  String get diveLog_search_errorLoadingTrips => 'Error loading trips';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_depthRange => 'Depth Range (m)';

  @override
  String get diveLog_search_label_diveCenter => 'Dive Center';

  @override
  String get diveLog_search_label_diveSite => 'Dive Site';

  @override
  String get diveLog_search_label_diveType => 'Dive Type';

  @override
  String get diveLog_search_label_durationRange => 'Duration Range (min)';

  @override
  String get diveLog_search_label_trip => 'Trip';

  @override
  String get diveLog_search_search => 'Search';

  @override
  String get diveLog_search_section_conditions => 'Conditions';

  @override
  String get diveLog_search_section_dateRange => 'Date Range';

  @override
  String get diveLog_search_section_gasEquipment => 'Gas & Equipment';

  @override
  String get diveLog_search_section_location => 'Location';

  @override
  String get diveLog_search_section_organization => 'Organization';

  @override
  String get diveLog_search_section_social => 'Social';

  @override
  String get diveLog_search_start => 'Start';

  @override
  String diveLog_selection_countSelected(Object count) {
    return '$count selected';
  }

  @override
  String get diveLog_selection_tooltip_delete => 'Delete Selected';

  @override
  String get diveLog_selection_tooltip_deselectAll => 'Deselect All';

  @override
  String get diveLog_selection_tooltip_edit => 'Edit Selected';

  @override
  String get diveLog_selection_tooltip_exit => 'Exit selection';

  @override
  String get diveLog_selection_tooltip_export => 'Export Selected';

  @override
  String get diveLog_selection_tooltip_selectAll => 'Select All';

  @override
  String get diveLog_sighting_add => 'Add';

  @override
  String get diveLog_sighting_cancel => 'Cancel';

  @override
  String get diveLog_sighting_notesHint => 'e.g., size, behavior, location...';

  @override
  String get diveLog_sighting_notesOptional => 'Notes (optional)';

  @override
  String get diveLog_sitePicker_addDiveSite => 'Add Dive Site';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return '$distance km away';
  }

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return '$distance m away';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return 'Error loading sites: $error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => 'New Dive Site';

  @override
  String get diveLog_sitePicker_noSites => 'No dive sites yet';

  @override
  String get diveLog_sitePicker_sortedByDistance => 'Sorted by distance';

  @override
  String get diveLog_sitePicker_title => 'Select Dive Site';

  @override
  String get diveLog_sort_title => 'Sort Dives';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return 'Add \"$name\" as new species';
  }

  @override
  String get diveLog_speciesPicker_noResults => 'No species found';

  @override
  String get diveLog_speciesPicker_noSpecies => 'No species available';

  @override
  String get diveLog_speciesPicker_searchHint => 'Search species...';

  @override
  String get diveLog_speciesPicker_title => 'Add Marine Life';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch => 'Clear search';

  @override
  String get diveLog_summary_action_importComputer => 'Import from Computer';

  @override
  String get diveLog_summary_action_logDive => 'Log Dive';

  @override
  String get diveLog_summary_action_viewStats => 'View Statistics';

  @override
  String diveLog_summary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_summary_overview => 'Overview';

  @override
  String get diveLog_summary_record_coldest => 'Coldest Dive';

  @override
  String get diveLog_summary_record_deepest => 'Deepest Dive';

  @override
  String get diveLog_summary_record_longest => 'Longest Dive';

  @override
  String get diveLog_summary_record_warmest => 'Warmest Dive';

  @override
  String get diveLog_summary_section_mostVisited => 'Most Visited Sites';

  @override
  String get diveLog_summary_section_quickActions => 'Quick Actions';

  @override
  String get diveLog_summary_section_records => 'Personal Records';

  @override
  String get diveLog_summary_selectDive =>
      'Select a dive from the list to view details';

  @override
  String get diveLog_summary_stat_avgMaxDepth => 'Avg Max Depth';

  @override
  String get diveLog_summary_stat_avgWaterTemp => 'Avg Water Temp';

  @override
  String get diveLog_summary_stat_diveSites => 'Dive Sites';

  @override
  String get diveLog_summary_stat_diveTime => 'Dive Time';

  @override
  String get diveLog_summary_stat_maxDepth => 'Max Depth';

  @override
  String get diveLog_summary_stat_totalDives => 'Total Dives';

  @override
  String get diveLog_summary_title => 'Dive Log Summary';

  @override
  String get diveLog_tank_label_endPressure => 'End Pressure';

  @override
  String get diveLog_tank_label_he => 'He';

  @override
  String get diveLog_tank_label_material => 'Material';

  @override
  String get diveLog_tank_label_n2 => 'N2';

  @override
  String get diveLog_tank_label_o2 => 'O2';

  @override
  String get diveLog_tank_label_role => 'Role';

  @override
  String get diveLog_tank_label_startPressure => 'Start Pressure';

  @override
  String get diveLog_tank_label_tankPreset => 'Tank Preset';

  @override
  String get diveLog_tank_label_volume => 'Volume';

  @override
  String get diveLog_tank_label_workingPressure => 'Working P';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO2 1.4)';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Gas Mix';

  @override
  String get diveLog_tank_selectPreset => 'Select Preset...';

  @override
  String diveLog_tank_title(Object number) {
    return 'Tank $number';
  }

  @override
  String get diveLog_tank_tooltip_remove => 'Remove tank';

  @override
  String get diveLog_tissue_label_ceiling => 'Ceiling';

  @override
  String get diveLog_tissue_label_gf => 'GF';

  @override
  String get diveLog_tissue_label_ndl => 'NDL';

  @override
  String get diveLog_tissue_label_tts => 'TTS';

  @override
  String get diveLog_tissue_legend_he => 'He';

  @override
  String get diveLog_tissue_legend_mValue => '100% M-value';

  @override
  String get diveLog_tissue_legend_n2 => 'N₂';

  @override
  String get diveLog_tissue_title => 'Tissue Loading';

  @override
  String get diveLog_tooltip_ceiling => 'Ceiling';

  @override
  String get diveLog_tooltip_density => 'Density';

  @override
  String get diveLog_tooltip_depth => 'Depth';

  @override
  String get diveLog_tooltip_gfPercent => 'GF%';

  @override
  String get diveLog_tooltip_hr => 'HR';

  @override
  String get diveLog_tooltip_marker => 'Marker';

  @override
  String get diveLog_tooltip_mean => 'Mean';

  @override
  String get diveLog_tooltip_mod => 'MOD';

  @override
  String get diveLog_tooltip_ndl => 'NDL';

  @override
  String get diveLog_tooltip_ppHe => 'ppHe';

  @override
  String get diveLog_tooltip_ppN2 => 'ppN2';

  @override
  String get diveLog_tooltip_ppO2 => 'ppO2';

  @override
  String get diveLog_tooltip_press => 'Press';

  @override
  String get diveLog_tooltip_rate => 'Rate';

  @override
  String get diveLog_tooltip_sac => 'SAC';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Time';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get divePlanner_action_addTank => 'Add Tank';

  @override
  String get divePlanner_action_convertToDive => 'Convert to Dive';

  @override
  String get divePlanner_action_editTank => 'Edit Tank';

  @override
  String get divePlanner_action_moreOptions => 'More options';

  @override
  String get divePlanner_action_quickPlan => 'Quick Plan';

  @override
  String get divePlanner_action_renamePlan => 'Rename Plan';

  @override
  String get divePlanner_action_reset => 'Reset';

  @override
  String get divePlanner_action_resetPlan => 'Reset Plan';

  @override
  String get divePlanner_action_savePlan => 'Save Plan';

  @override
  String get divePlanner_error_cannotConvert =>
      'Cannot convert: plan has critical warnings';

  @override
  String get divePlanner_field_hePercent => 'He %';

  @override
  String get divePlanner_field_name => 'Name';

  @override
  String get divePlanner_field_o2Percent => 'O₂ %';

  @override
  String get divePlanner_field_planName => 'Plan Name';

  @override
  String get divePlanner_field_role => 'Role';

  @override
  String divePlanner_field_startPressure(Object pressureSymbol) {
    return 'Start ($pressureSymbol)';
  }

  @override
  String divePlanner_field_volume(Object volumeSymbol) {
    return 'Volume ($volumeSymbol)';
  }

  @override
  String get divePlanner_hint_tankName => 'Enter tank name';

  @override
  String get divePlanner_label_altitude => 'Altitude:';

  @override
  String get divePlanner_label_belowMinReserve => 'Below Min Reserve';

  @override
  String get divePlanner_label_ceiling => 'Ceiling';

  @override
  String get divePlanner_label_consumption => 'Consumption';

  @override
  String get divePlanner_label_deco => 'DECO';

  @override
  String get divePlanner_label_decoSchedule => 'Decompression Schedule';

  @override
  String get divePlanner_label_decompression => 'Decompression';

  @override
  String divePlanner_label_depthAxis(Object depthSymbol) {
    return 'Depth ($depthSymbol)';
  }

  @override
  String get divePlanner_label_diveProfile => 'Dive Profile';

  @override
  String get divePlanner_label_empty => 'EMPTY';

  @override
  String get divePlanner_label_gasConsumption => 'Gas Consumption';

  @override
  String get divePlanner_label_gfHigh => 'GF High';

  @override
  String get divePlanner_label_gfLow => 'GF Low';

  @override
  String get divePlanner_label_max => 'Max';

  @override
  String get divePlanner_label_ndl => 'NDL';

  @override
  String get divePlanner_label_planSettings => 'Plan Settings';

  @override
  String get divePlanner_label_remaining => 'Remaining';

  @override
  String get divePlanner_label_runtime => 'Runtime';

  @override
  String get divePlanner_label_sacRate => 'SAC Rate:';

  @override
  String get divePlanner_label_status => 'Status';

  @override
  String get divePlanner_label_tanks => 'Tanks';

  @override
  String get divePlanner_label_time => 'Time';

  @override
  String get divePlanner_label_timeAxis => 'Time (min)';

  @override
  String get divePlanner_label_tts => 'TTS';

  @override
  String get divePlanner_label_used => 'Used';

  @override
  String get divePlanner_label_warnings => 'Warnings';

  @override
  String get divePlanner_legend_ascent => 'Ascent';

  @override
  String get divePlanner_legend_bottom => 'Bottom';

  @override
  String get divePlanner_legend_deco => 'Deco';

  @override
  String get divePlanner_legend_descent => 'Descent';

  @override
  String get divePlanner_legend_safety => 'Safety';

  @override
  String get divePlanner_message_addSegmentsForGas =>
      'Add segments to see gas projections';

  @override
  String get divePlanner_message_addSegmentsForProfile =>
      'Add segments to see the dive profile';

  @override
  String get divePlanner_message_convertingPlan => 'Converting plan to dive...';

  @override
  String get divePlanner_message_noProfile => 'No profile to display';

  @override
  String get divePlanner_message_planSaved => 'Plan saved';

  @override
  String get divePlanner_message_resetConfirmation =>
      'Are you sure you want to reset the plan?';

  @override
  String divePlanner_semantics_criticalWarning(Object message) {
    return 'Critical warning: $message';
  }

  @override
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  ) {
    return 'Deco stop at $depth for $duration on $gasMix';
  }

  @override
  String divePlanner_semantics_gasConsumption(
    Object tankName,
    Object gasUsed,
    Object remaining,
    Object percent,
    Object warning,
  ) {
    return '$tankName: $gasUsed used, $remaining remaining, $percent used$warning';
  }

  @override
  String divePlanner_semantics_profileChart(
    Object maxDepth,
    Object totalMinutes,
  ) {
    return 'Dive plan, max depth $maxDepth, total time $totalMinutes minutes';
  }

  @override
  String divePlanner_semantics_warning(Object message) {
    return 'Warning: $message';
  }

  @override
  String get divePlanner_tab_plan => 'Plan';

  @override
  String get divePlanner_tab_profile => 'Profile';

  @override
  String get divePlanner_tab_results => 'Results';

  @override
  String get divePlanner_warning_ascentRateHigh =>
      'Ascent rate exceeds safe limit';

  @override
  String divePlanner_warning_ascentRateHighWithRate(Object rate) {
    return 'Ascent rate $rate/min exceeds safe limit';
  }

  @override
  String divePlanner_warning_belowMinReserve(Object reserve) {
    return 'Below minimum reserve ($reserve)';
  }

  @override
  String get divePlanner_warning_cnsCritical => 'CNS% exceeds 100%';

  @override
  String divePlanner_warning_cnsWarning(Object threshold) {
    return 'CNS% exceeds $threshold%';
  }

  @override
  String get divePlanner_warning_endHigh =>
      'Equivalent Narcotic Depth too high';

  @override
  String divePlanner_warning_endHighWithDepth(Object depth) {
    return 'END of $depth exceeds safe limit';
  }

  @override
  String divePlanner_warning_gasLow(Object threshold) {
    return 'Tank below $threshold reserve';
  }

  @override
  String get divePlanner_warning_gasOut => 'Tank will be empty';

  @override
  String get divePlanner_warning_minGasViolation =>
      'Minimum gas reserve not maintained';

  @override
  String get divePlanner_warning_modViolation =>
      'Gas switch attempted above MOD';

  @override
  String get divePlanner_warning_ndlExceeded =>
      'Dive enters decompression obligation';

  @override
  String get divePlanner_warning_otuWarning => 'OTU accumulation high';

  @override
  String divePlanner_warning_ppO2Critical(Object value) {
    return 'ppO₂ of $value bar exceeds critical limit';
  }

  @override
  String divePlanner_warning_ppO2High(Object value) {
    return 'ppO₂ of $value bar exceeds working limit';
  }

  @override
  String get diveSites_detail_access_accessNotes => 'Access Notes';

  @override
  String get diveSites_detail_access_mooring => 'Mooring';

  @override
  String get diveSites_detail_access_parking => 'Parking';

  @override
  String get diveSites_detail_altitude_elevation => 'Elevation';

  @override
  String get diveSites_detail_altitude_pressure => 'Pressure';

  @override
  String get diveSites_detail_coordinatesCopied =>
      'Coordinates copied to clipboard';

  @override
  String get diveSites_detail_deleteDialog_cancel => 'Cancel';

  @override
  String get diveSites_detail_deleteDialog_confirm => 'Delete';

  @override
  String get diveSites_detail_deleteDialog_content =>
      'Are you sure you want to delete this site? This action cannot be undone.';

  @override
  String get diveSites_detail_deleteDialog_title => 'Delete Site';

  @override
  String get diveSites_detail_deleteMenu_label => 'Delete';

  @override
  String get diveSites_detail_deleteSnackbar => 'Site deleted';

  @override
  String get diveSites_detail_depth_maximum => 'Maximum';

  @override
  String get diveSites_detail_depth_minimum => 'Minimum';

  @override
  String get diveSites_detail_diveCount_one => '1 dive logged';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '$count dives logged';
  }

  @override
  String get diveSites_detail_diveCount_zero => 'No dives logged yet';

  @override
  String get diveSites_detail_editTooltip => 'Edit Site';

  @override
  String get diveSites_detail_editTooltipShort => 'Edit';

  @override
  String diveSites_detail_error_body(Object error) {
    return 'Error: $error';
  }

  @override
  String get diveSites_detail_error_title => 'Error';

  @override
  String get diveSites_detail_loading_title => 'Loading...';

  @override
  String get diveSites_detail_location_country => 'Country';

  @override
  String get diveSites_detail_location_gpsCoordinates => 'GPS Coordinates';

  @override
  String get diveSites_detail_location_notSet => 'Not set';

  @override
  String get diveSites_detail_location_region => 'Region';

  @override
  String get diveSites_detail_noDepthInfo => 'No depth information';

  @override
  String get diveSites_detail_noDescription => 'No description';

  @override
  String get diveSites_detail_noNotes => 'No notes';

  @override
  String get diveSites_detail_rating_notRated => 'Not rated';

  @override
  String diveSites_detail_rating_value(Object rating) {
    return '$rating out of 5';
  }

  @override
  String get diveSites_detail_section_access => 'Access & Logistics';

  @override
  String get diveSites_detail_section_altitude => 'Altitude';

  @override
  String get diveSites_detail_section_depthRange => 'Depth Range';

  @override
  String get diveSites_detail_section_description => 'Description';

  @override
  String get diveSites_detail_section_difficultyLevel => 'Difficulty Level';

  @override
  String get diveSites_detail_section_divesAtSite => 'Dives at this Site';

  @override
  String get diveSites_detail_section_hazards => 'Hazards & Safety';

  @override
  String get diveSites_detail_section_location => 'Location';

  @override
  String get diveSites_detail_section_notes => 'Notes';

  @override
  String get diveSites_detail_section_rating => 'Rating';

  @override
  String diveSites_detail_semantics_copyToClipboard(Object label) {
    return 'Copy $label to clipboard';
  }

  @override
  String get diveSites_detail_semantics_viewDivesAtSite =>
      'View dives at this site';

  @override
  String get diveSites_detail_semantics_viewFullscreenMap =>
      'View fullscreen map';

  @override
  String get diveSites_detail_siteNotFound_body =>
      'This site no longer exists.';

  @override
  String get diveSites_detail_siteNotFound_title => 'Site Not Found';

  @override
  String get diveSites_difficulty_advanced => 'Advanced';

  @override
  String get diveSites_difficulty_beginner => 'Beginner';

  @override
  String get diveSites_difficulty_intermediate => 'Intermediate';

  @override
  String get diveSites_difficulty_technical => 'Technical';

  @override
  String get diveSites_edit_access_accessNotes_hint =>
      'How to get to the site, entry/exit points, shore/boat access';

  @override
  String get diveSites_edit_access_accessNotes_label => 'Access Notes';

  @override
  String get diveSites_edit_access_mooringNumber_hint => 'e.g., Buoy #12';

  @override
  String get diveSites_edit_access_mooringNumber_label => 'Mooring Number';

  @override
  String get diveSites_edit_access_parkingInfo_hint =>
      'Parking availability, fees, tips';

  @override
  String get diveSites_edit_access_parkingInfo_label => 'Parking Information';

  @override
  String get diveSites_edit_altitude_helperText =>
      'Site elevation above sea level (for altitude diving)';

  @override
  String get diveSites_edit_altitude_hint => 'e.g., 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return 'Altitude ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => 'Invalid altitude';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => 'Delete Site';

  @override
  String get diveSites_edit_appBar_editSite => 'Edit Site';

  @override
  String get diveSites_edit_appBar_newSite => 'New Site';

  @override
  String get diveSites_edit_appBar_save => 'Save';

  @override
  String get diveSites_edit_button_addSite => 'Add Site';

  @override
  String get diveSites_edit_button_saveChanges => 'Save Changes';

  @override
  String get diveSites_edit_cancel => 'Cancel';

  @override
  String get diveSites_edit_depth_helperText =>
      'From the shallowest to the deepest point';

  @override
  String get diveSites_edit_depth_maxHint => 'e.g., 30';

  @override
  String diveSites_edit_depth_maxLabel(Object symbol) {
    return 'Maximum Depth ($symbol)';
  }

  @override
  String get diveSites_edit_depth_minHint => 'e.g., 5';

  @override
  String diveSites_edit_depth_minLabel(Object symbol) {
    return 'Minimum Depth ($symbol)';
  }

  @override
  String get diveSites_edit_depth_separator => 'to';

  @override
  String get diveSites_edit_discardDialog_content =>
      'You have unsaved changes. Are you sure you want to leave?';

  @override
  String get diveSites_edit_discardDialog_discard => 'Discard';

  @override
  String get diveSites_edit_discardDialog_keepEditing => 'Keep Editing';

  @override
  String get diveSites_edit_discardDialog_title => 'Discard Changes?';

  @override
  String get diveSites_edit_field_country_label => 'Country';

  @override
  String get diveSites_edit_field_description_hint =>
      'Brief description of the site';

  @override
  String get diveSites_edit_field_description_label => 'Description';

  @override
  String get diveSites_edit_field_notes_hint =>
      'Any other information about this site';

  @override
  String get diveSites_edit_field_notes_label => 'General Notes';

  @override
  String get diveSites_edit_field_region_label => 'Region';

  @override
  String get diveSites_edit_field_siteName_hint => 'e.g., Blue Hole';

  @override
  String get diveSites_edit_field_siteName_label => 'Site Name *';

  @override
  String get diveSites_edit_field_siteName_validation =>
      'Please enter a site name';

  @override
  String get diveSites_edit_gps_gettingLocation => 'Getting...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Choose a location method - coordinates will auto-fill country and region';

  @override
  String get diveSites_edit_gps_latitude_hint => 'e.g., 21.4225';

  @override
  String get diveSites_edit_gps_latitude_label => 'Latitude';

  @override
  String get diveSites_edit_gps_latitude_validation => 'Invalid latitude';

  @override
  String get diveSites_edit_gps_longitude_hint => 'e.g., -86.7542';

  @override
  String get diveSites_edit_gps_longitude_label => 'Longitude';

  @override
  String get diveSites_edit_gps_longitude_validation => 'Invalid longitude';

  @override
  String get diveSites_edit_gps_pickFromMap => 'Pick from Map';

  @override
  String get diveSites_edit_gps_useMyLocation => 'Use My Location';

  @override
  String get diveSites_edit_hazards_helperText =>
      'List any hazards or safety considerations';

  @override
  String get diveSites_edit_hazards_hint =>
      'e.g., Strong currents, boat traffic, jellyfish, sharp coral';

  @override
  String get diveSites_edit_hazards_label => 'Hazards';

  @override
  String get diveSites_edit_marineLife_addButton => 'Add';

  @override
  String get diveSites_edit_marineLife_empty => 'No expected species added';

  @override
  String get diveSites_edit_marineLife_helperText =>
      'Species you expect to see at this site';

  @override
  String get diveSites_edit_rating_clear => 'Clear Rating';

  @override
  String diveSites_edit_rating_starTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count star$_temp0';
  }

  @override
  String get diveSites_edit_section_access => 'Access & Logistics';

  @override
  String get diveSites_edit_section_altitude => 'Altitude';

  @override
  String get diveSites_edit_section_depthRange => 'Depth Range';

  @override
  String get diveSites_edit_section_difficultyLevel => 'Difficulty Level';

  @override
  String get diveSites_edit_section_expectedMarineLife =>
      'Expected Marine Life';

  @override
  String get diveSites_edit_section_gpsCoordinates => 'GPS Coordinates';

  @override
  String get diveSites_edit_section_hazards => 'Hazards & Safety';

  @override
  String get diveSites_edit_section_rating => 'Rating';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return 'Error deleting site: $error';
  }

  @override
  String diveSites_edit_snackbar_errorSaving(Object error) {
    return 'Error saving site: $error';
  }

  @override
  String get diveSites_edit_snackbar_locationCaptured => 'Location captured';

  @override
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Location captured (${accuracy}m)';
  }

  @override
  String get diveSites_edit_snackbar_locationSelectedFromMap =>
      'Location selected from map';

  @override
  String get diveSites_edit_snackbar_locationSettings => 'Settings';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      'Unable to get location. Location services may not be available.';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      'Unable to get location. Please check permissions.';

  @override
  String get diveSites_edit_snackbar_siteAdded => 'Site added';

  @override
  String get diveSites_edit_snackbar_siteUpdated => 'Site updated';

  @override
  String get diveSites_fab_label => 'Add Site';

  @override
  String get diveSites_fab_tooltip => 'Add a new dive site';

  @override
  String get diveSites_filter_apply => 'Apply Filters';

  @override
  String get diveSites_filter_cancel => 'Cancel';

  @override
  String get diveSites_filter_clearAll => 'Clear All';

  @override
  String get diveSites_filter_country_hint => 'e.g., Thailand';

  @override
  String get diveSites_filter_country_label => 'Country';

  @override
  String get diveSites_filter_depth_max_label => 'Max';

  @override
  String get diveSites_filter_depth_min_label => 'Min';

  @override
  String get diveSites_filter_depth_separator => 'to';

  @override
  String get diveSites_filter_difficulty_any => 'Any';

  @override
  String get diveSites_filter_option_hasCoordinates_subtitle =>
      'Only show sites with GPS location';

  @override
  String get diveSites_filter_option_hasCoordinates_title => 'Has Coordinates';

  @override
  String get diveSites_filter_option_hasDives_subtitle =>
      'Only show sites with logged dives';

  @override
  String get diveSites_filter_option_hasDives_title => 'Has Dives';

  @override
  String diveSites_filter_rating_starsPlus(Object count) {
    return '$count+ stars';
  }

  @override
  String get diveSites_filter_region_hint => 'e.g., Phuket';

  @override
  String get diveSites_filter_region_label => 'Region';

  @override
  String get diveSites_filter_section_depthRange => 'Max Depth Range';

  @override
  String get diveSites_filter_section_difficulty => 'Difficulty';

  @override
  String get diveSites_filter_section_location => 'Location';

  @override
  String get diveSites_filter_section_minRating => 'Minimum Rating';

  @override
  String get diveSites_filter_section_options => 'Options';

  @override
  String get diveSites_filter_title => 'Filter Sites';

  @override
  String get diveSites_import_appBar_title => 'Import Dive Site';

  @override
  String get diveSites_import_badge_imported => 'Imported';

  @override
  String get diveSites_import_badge_saved => 'Saved';

  @override
  String get diveSites_import_button_import => 'Import';

  @override
  String get diveSites_import_detail_alreadyImported => 'Already Imported';

  @override
  String get diveSites_import_detail_importToMySites => 'Import to My Sites';

  @override
  String diveSites_import_detail_source(Object source) {
    return 'Source: $source';
  }

  @override
  String get diveSites_import_empty_description =>
      'Search for dive sites from our database of popular dive destinations around the world.';

  @override
  String get diveSites_import_empty_hint =>
      'Try searching by site name, country, or region.';

  @override
  String get diveSites_import_empty_title => 'Search Dive Sites';

  @override
  String get diveSites_import_error_retry => 'Retry';

  @override
  String get diveSites_import_error_title => 'Search Error';

  @override
  String get diveSites_import_error_unknown => 'Unknown error';

  @override
  String get diveSites_import_externalSite_locationUnknown =>
      'Location unknown';

  @override
  String get diveSites_import_label_gps => 'GPS';

  @override
  String get diveSites_import_localSite_locationNotSet => 'Location not set';

  @override
  String diveSites_import_noResults_description(Object query) {
    return 'No dive sites found for \"$query\". Try a different search term.';
  }

  @override
  String get diveSites_import_noResults_title => 'No Results';

  @override
  String get diveSites_import_quickSearch_caribbean => 'Caribbean';

  @override
  String get diveSites_import_quickSearch_indonesia => 'Indonesia';

  @override
  String get diveSites_import_quickSearch_maldives => 'Maldives';

  @override
  String get diveSites_import_quickSearch_philippines => 'Philippines';

  @override
  String get diveSites_import_quickSearch_redSea => 'Red Sea';

  @override
  String get diveSites_import_quickSearch_thailand => 'Thailand';

  @override
  String get diveSites_import_search_clearTooltip => 'Clear search';

  @override
  String get diveSites_import_search_hint =>
      'Search dive sites (e.g., \"Blue Hole\", \"Thailand\")';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return 'Import from Database ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return 'My Sites ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return 'View details for $name';
  }

  @override
  String diveSites_import_semantics_viewSavedSite(Object name) {
    return 'View saved site $name';
  }

  @override
  String get diveSites_import_snackbar_failed => 'Failed to import site';

  @override
  String diveSites_import_snackbar_imported(Object name) {
    return 'Imported \"$name\"';
  }

  @override
  String get diveSites_import_snackbar_viewAction => 'View';

  @override
  String get diveSites_list_activeFilter_clear => 'Clear';

  @override
  String diveSites_list_activeFilter_country(Object country) {
    return 'Country: $country';
  }

  @override
  String diveSites_list_activeFilter_depthRangeBoth(Object min, Object max) {
    return '$min-${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Up to ${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '${min}m+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => 'Has coordinates';

  @override
  String get diveSites_list_activeFilter_hasDives => 'Has dives';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return 'Region: $region';
  }

  @override
  String get diveSites_list_appBar_title => 'Dive Sites';

  @override
  String get diveSites_list_bulkDelete_cancel => 'Cancel';

  @override
  String get diveSites_list_bulkDelete_confirm => 'Delete';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sites',
      one: 'site',
    );
    return 'Are you sure you want to delete $count $_temp0? This action can be undone within 5 seconds.';
  }

  @override
  String get diveSites_list_bulkDelete_restored => 'Sites restored';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sites',
      one: 'site',
    );
    return 'Deleted $count $_temp0';
  }

  @override
  String get diveSites_list_bulkDelete_title => 'Delete Sites';

  @override
  String get diveSites_list_bulkDelete_undo => 'Undo';

  @override
  String get diveSites_list_emptyFiltered_clearAll => 'Clear All Filters';

  @override
  String get diveSites_list_emptyFiltered_subtitle =>
      'Try adjusting or clearing your filters';

  @override
  String get diveSites_list_emptyFiltered_title =>
      'No sites match your filters';

  @override
  String get diveSites_list_empty_addFirstSite => 'Add Your First Site';

  @override
  String get diveSites_list_empty_import => 'Import';

  @override
  String get diveSites_list_empty_subtitle =>
      'Add dive sites to track your favorite locations';

  @override
  String get diveSites_list_empty_title => 'No dive sites yet';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return 'Error loading sites: $error';
  }

  @override
  String get diveSites_list_error_retry => 'Retry';

  @override
  String get diveSites_list_menu_import => 'Import';

  @override
  String get diveSites_list_search_backTooltip => 'Back';

  @override
  String get diveSites_list_search_clearTooltip => 'Clear Search';

  @override
  String get diveSites_list_search_emptyHint =>
      'Search by site name, country, or region';

  @override
  String diveSites_list_search_error(Object error) {
    return 'Error: $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return 'No sites found for \"$query\"';
  }

  @override
  String get diveSites_list_search_placeholder => 'Search sites...';

  @override
  String get diveSites_list_selection_closeTooltip => 'Close Selection';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count selected';
  }

  @override
  String get diveSites_list_selection_deleteTooltip => 'Delete Selected';

  @override
  String get diveSites_list_selection_deselectAllTooltip => 'Deselect All';

  @override
  String get diveSites_list_selection_selectAllTooltip => 'Select All';

  @override
  String get diveSites_list_sort_title => 'Sort Sites';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives',
      one: '1 dive',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return 'Dive site: $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => 'Filter Sites';

  @override
  String get diveSites_list_tooltip_mapView => 'Map View';

  @override
  String get diveSites_list_tooltip_searchSites => 'Search Sites';

  @override
  String get diveSites_list_tooltip_sort => 'Sort';

  @override
  String get diveSites_locationPicker_appBar_title => 'Pick Location';

  @override
  String get diveSites_locationPicker_confirmButton => 'Confirm';

  @override
  String get diveSites_locationPicker_confirmTooltip =>
      'Confirm selected location';

  @override
  String get diveSites_locationPicker_fab_tooltip => 'Use my location';

  @override
  String get diveSites_locationPicker_instruction_locationSelected =>
      'Location selected';

  @override
  String get diveSites_locationPicker_instruction_lookingUp =>
      'Looking up location...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect =>
      'Tap on the map to select a location';

  @override
  String get diveSites_locationPicker_label_latitude => 'Latitude';

  @override
  String get diveSites_locationPicker_label_longitude => 'Longitude';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return 'Selected coordinates: latitude $latitude, longitude $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp =>
      'Looking up location';

  @override
  String get diveSites_locationPicker_semantics_map =>
      'Interactive map for picking a dive site location. Tap on the map to select a location.';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return 'Error loading dive sites: $error';
  }

  @override
  String get diveSites_map_appBar_title => 'Dive Sites';

  @override
  String get diveSites_map_empty_description =>
      'Add coordinates to your dive sites to see them on the map';

  @override
  String get diveSites_map_empty_title => 'No sites with coordinates';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return 'Error loading sites: $error';
  }

  @override
  String get diveSites_map_error_retry => 'Retry';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives',
      one: '1 dive',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return 'Dive site: $name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => 'Fit All Sites';

  @override
  String get diveSites_map_tooltip_listView => 'List View';

  @override
  String get diveSites_summary_action_addSite => 'Add Site';

  @override
  String get diveSites_summary_action_import => 'Import';

  @override
  String get diveSites_summary_action_viewMap => 'View Map';

  @override
  String diveSites_summary_countriesMore(Object count) {
    return '+ $count more';
  }

  @override
  String get diveSites_summary_header_subtitle =>
      'Select a site from the list to view details';

  @override
  String get diveSites_summary_header_title => 'Dive Sites';

  @override
  String get diveSites_summary_section_countriesRegions =>
      'Countries & Regions';

  @override
  String get diveSites_summary_section_mostDived => 'Most Dived';

  @override
  String get diveSites_summary_section_overview => 'Overview';

  @override
  String get diveSites_summary_section_quickActions => 'Quick Actions';

  @override
  String get diveSites_summary_section_topRated => 'Top Rated';

  @override
  String get diveSites_summary_stat_avgRating => 'Avg Rating';

  @override
  String get diveSites_summary_stat_totalDives => 'Total Dives';

  @override
  String get diveSites_summary_stat_totalSites => 'Total Sites';

  @override
  String get diveSites_summary_stat_withGps => 'With GPS';

  @override
  String get diveTypes_addDialog_addButton => 'Add';

  @override
  String get diveTypes_addDialog_nameHint => 'e.g., Search & Recovery';

  @override
  String get diveTypes_addDialog_nameLabel => 'Dive Type Name';

  @override
  String get diveTypes_addDialog_nameValidation => 'Please enter a name';

  @override
  String get diveTypes_addDialog_title => 'Add Custom Dive Type';

  @override
  String get diveTypes_addTooltip => 'Add dive type';

  @override
  String get diveTypes_appBar_title => 'Dive Types';

  @override
  String get diveTypes_builtIn => 'Built-in';

  @override
  String get diveTypes_builtInHeader => 'Built-in Dive Types';

  @override
  String get diveTypes_custom => 'Custom';

  @override
  String get diveTypes_customHeader => 'Custom Dive Types';

  @override
  String diveTypes_deleteDialog_content(Object name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get diveTypes_deleteDialog_title => 'Delete Dive Type?';

  @override
  String get diveTypes_deleteTooltip => 'Delete dive type';

  @override
  String diveTypes_snackbar_added(Object name) {
    return 'Added dive type: $name';
  }

  @override
  String diveTypes_snackbar_cannotDelete(Object name) {
    return 'Cannot delete \"$name\" - it is used by existing dives';
  }

  @override
  String diveTypes_snackbar_deleted(Object name) {
    return 'Deleted \"$name\"';
  }

  @override
  String diveTypes_snackbar_errorAdding(Object error) {
    return 'Error adding dive type: $error';
  }

  @override
  String diveTypes_snackbar_errorDeleting(Object error) {
    return 'Error deleting dive type: $error';
  }

  @override
  String get divers_detail_activeDiver => 'Active Diver';

  @override
  String get divers_detail_allergiesLabel => 'Allergies';

  @override
  String get divers_detail_appBarTitle => 'Diver';

  @override
  String get divers_detail_bloodTypeLabel => 'Blood Type';

  @override
  String get divers_detail_bottomTimeLabel => 'Bottom Time';

  @override
  String get divers_detail_cancelButton => 'Cancel';

  @override
  String get divers_detail_contactTitle => 'Contact';

  @override
  String get divers_detail_defaultLabel => 'Default';

  @override
  String get divers_detail_deleteButton => 'Delete';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'Are you sure you want to delete $name? All associated dive logs will be unassigned.';
  }

  @override
  String get divers_detail_deleteDialogTitle => 'Delete Diver?';

  @override
  String divers_detail_deleteError(Object error) {
    return 'Failed to delete: $error';
  }

  @override
  String get divers_detail_deleteMenuItem => 'Delete';

  @override
  String get divers_detail_deletedSnackbar => 'Diver deleted';

  @override
  String get divers_detail_diveInsuranceTitle => 'Dive Insurance';

  @override
  String get divers_detail_diveStatisticsTitle => 'Dive Statistics';

  @override
  String get divers_detail_editTooltip => 'Edit diver';

  @override
  String get divers_detail_emergencyContactTitle => 'Emergency Contact';

  @override
  String divers_detail_errorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get divers_detail_expiredBadge => 'Expired';

  @override
  String get divers_detail_expiresLabel => 'Expires';

  @override
  String get divers_detail_medicalInfoTitle => 'Medical Information';

  @override
  String get divers_detail_medicalNotesLabel => 'Notes';

  @override
  String get divers_detail_notFound => 'Diver not found';

  @override
  String get divers_detail_notesTitle => 'Notes';

  @override
  String get divers_detail_policyNumberLabel => 'Policy #';

  @override
  String get divers_detail_providerLabel => 'Provider';

  @override
  String get divers_detail_setAsDefault => 'Set as Default';

  @override
  String divers_detail_setAsDefaultSnackbar(Object name) {
    return '$name set as default diver';
  }

  @override
  String get divers_detail_switchToTooltip => 'Switch to this diver';

  @override
  String divers_detail_switchedTo(Object name) {
    return 'Switched to $name';
  }

  @override
  String get divers_detail_totalDivesLabel => 'Total Dives';

  @override
  String get divers_detail_unableToLoadStats => 'Unable to load stats';

  @override
  String get divers_edit_addButton => 'Add Diver';

  @override
  String get divers_edit_addTitle => 'Add Diver';

  @override
  String get divers_edit_allergiesHint => 'e.g., Penicillin, Shellfish';

  @override
  String get divers_edit_allergiesLabel => 'Allergies';

  @override
  String get divers_edit_bloodTypeHint => 'e.g., O+, A-, B+';

  @override
  String get divers_edit_bloodTypeLabel => 'Blood Type';

  @override
  String get divers_edit_cancelButton => 'Cancel';

  @override
  String get divers_edit_clearInsuranceExpiryTooltip =>
      'Clear insurance expiry date';

  @override
  String get divers_edit_clearMedicalClearanceTooltip =>
      'Clear medical clearance date';

  @override
  String get divers_edit_contactNameLabel => 'Contact Name';

  @override
  String get divers_edit_contactPhoneLabel => 'Contact Phone';

  @override
  String get divers_edit_discardButton => 'Discard';

  @override
  String get divers_edit_discardDialogContent =>
      'You have unsaved changes. Are you sure you want to discard them?';

  @override
  String get divers_edit_discardDialogTitle => 'Discard Changes?';

  @override
  String get divers_edit_diverAdded => 'Diver added';

  @override
  String get divers_edit_diverUpdated => 'Diver updated';

  @override
  String get divers_edit_editTitle => 'Edit Diver';

  @override
  String get divers_edit_emailError => 'Enter a valid email';

  @override
  String get divers_edit_emailLabel => 'Email';

  @override
  String get divers_edit_emergencyContactsSection => 'Emergency Contacts';

  @override
  String divers_edit_errorLoading(Object error) {
    return 'Error loading diver: $error';
  }

  @override
  String divers_edit_errorSaving(Object error) {
    return 'Error saving diver: $error';
  }

  @override
  String get divers_edit_expiryDateNotSet => 'Not set';

  @override
  String get divers_edit_expiryDateTitle => 'Expiry Date';

  @override
  String get divers_edit_insuranceProviderHint => 'e.g., DAN, DiveAssure';

  @override
  String get divers_edit_insuranceProviderLabel => 'Insurance Provider';

  @override
  String get divers_edit_insuranceSection => 'Dive Insurance';

  @override
  String get divers_edit_keepEditingButton => 'Keep Editing';

  @override
  String get divers_edit_medicalClearanceExpired => 'Expired';

  @override
  String get divers_edit_medicalClearanceExpiringSoon => 'Expiring Soon';

  @override
  String get divers_edit_medicalClearanceNotSet => 'Not set';

  @override
  String get divers_edit_medicalClearanceTitle => 'Medical Clearance Expiry';

  @override
  String get divers_edit_medicalInfoSection => 'Medical Information';

  @override
  String get divers_edit_medicalNotesLabel => 'Medical Notes';

  @override
  String get divers_edit_medicationsHint => 'e.g., Aspirin daily, EpiPen';

  @override
  String get divers_edit_medicationsLabel => 'Medications';

  @override
  String get divers_edit_nameError => 'Name is required';

  @override
  String get divers_edit_nameLabel => 'Name *';

  @override
  String get divers_edit_notesLabel => 'Notes';

  @override
  String get divers_edit_notesSection => 'Notes';

  @override
  String get divers_edit_personalInfoSection => 'Personal Information';

  @override
  String get divers_edit_phoneLabel => 'Phone';

  @override
  String get divers_edit_policyNumberLabel => 'Policy Number';

  @override
  String get divers_edit_primaryContactTitle => 'Primary Contact';

  @override
  String get divers_edit_relationshipHint => 'e.g., Spouse, Parent, Friend';

  @override
  String get divers_edit_relationshipLabel => 'Relationship';

  @override
  String get divers_edit_saveButton => 'Save';

  @override
  String get divers_edit_secondaryContactTitle => 'Secondary Contact';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip =>
      'Select insurance expiry date';

  @override
  String get divers_edit_selectMedicalClearanceTooltip =>
      'Select medical clearance date';

  @override
  String get divers_edit_updateButton => 'Update Diver';

  @override
  String get divers_list_activeBadge => 'Active';

  @override
  String get divers_list_addDiverButton => 'Add Diver';

  @override
  String get divers_list_addDiverTooltip => 'Add a new diver profile';

  @override
  String get divers_list_appBarTitle => 'Diver Profiles';

  @override
  String get divers_list_compactTitle => 'Divers';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount dives$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle =>
      'Add diver profiles to track dive logs for multiple people';

  @override
  String get divers_list_emptyTitle => 'No divers yet';

  @override
  String divers_list_errorLoading(Object error) {
    return 'Error loading divers: $error';
  }

  @override
  String get divers_list_errorLoadingStats => 'Error loading stats';

  @override
  String get divers_list_loadingStats => 'Loading...';

  @override
  String get divers_list_retryButton => 'Retry';

  @override
  String divers_list_viewDiverLabel(Object name) {
    return 'View diver $name';
  }

  @override
  String get divers_summary_activeDiverTitle => 'Active Diver';

  @override
  String get divers_summary_otherDiversTitle => 'Other Divers';

  @override
  String get divers_summary_overviewTitle => 'Overview';

  @override
  String get divers_summary_quickActionsTitle => 'Quick Actions';

  @override
  String get divers_summary_subtitle =>
      'Select a diver from the list to view details';

  @override
  String get divers_summary_title => 'Diver Profiles';

  @override
  String get divers_summary_totalDiversLabel => 'Total Divers';

  @override
  String get enum_altitudeGroup_extreme => 'Extreme Altitude';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => 'Altitude Group 1';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => 'Altitude Group 2';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => 'Altitude Group 3';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => 'Sea Level';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => 'Danger';

  @override
  String get enum_ascentRate_safe => 'Safe';

  @override
  String get enum_ascentRate_warning => 'Warning';

  @override
  String get enum_buddyRole_buddy => 'Buddy';

  @override
  String get enum_buddyRole_diveGuide => 'Dive Guide';

  @override
  String get enum_buddyRole_diveMaster => 'Divemaster';

  @override
  String get enum_buddyRole_instructor => 'Instructor';

  @override
  String get enum_buddyRole_solo => 'Solo';

  @override
  String get enum_buddyRole_student => 'Student';

  @override
  String get enum_certificationAgency_bsac => 'BSAC';

  @override
  String get enum_certificationAgency_cmas => 'CMAS';

  @override
  String get enum_certificationAgency_gue => 'GUE';

  @override
  String get enum_certificationAgency_iantd => 'IANTD';

  @override
  String get enum_certificationAgency_naui => 'NAUI';

  @override
  String get enum_certificationAgency_other => 'Other';

  @override
  String get enum_certificationAgency_padi => 'PADI';

  @override
  String get enum_certificationAgency_psai => 'PSAI';

  @override
  String get enum_certificationAgency_raid => 'RAID';

  @override
  String get enum_certificationAgency_sdi => 'SDI';

  @override
  String get enum_certificationAgency_ssi => 'SSI';

  @override
  String get enum_certificationAgency_tdi => 'TDI';

  @override
  String get enum_certificationLevel_advancedNitrox => 'Advanced Nitrox';

  @override
  String get enum_certificationLevel_advancedOpenWater => 'Advanced Open Water';

  @override
  String get enum_certificationLevel_cave => 'Cave';

  @override
  String get enum_certificationLevel_cavern => 'Cavern';

  @override
  String get enum_certificationLevel_courseDirector => 'Course Director';

  @override
  String get enum_certificationLevel_decompression => 'Decompression';

  @override
  String get enum_certificationLevel_diveMaster => 'Divemaster';

  @override
  String get enum_certificationLevel_instructor => 'Instructor';

  @override
  String get enum_certificationLevel_masterInstructor => 'Master Instructor';

  @override
  String get enum_certificationLevel_nitrox => 'Nitrox';

  @override
  String get enum_certificationLevel_openWater => 'Open Water';

  @override
  String get enum_certificationLevel_other => 'Other';

  @override
  String get enum_certificationLevel_rebreather => 'Rebreather';

  @override
  String get enum_certificationLevel_rescue => 'Rescue Diver';

  @override
  String get enum_certificationLevel_sidemount => 'Sidemount';

  @override
  String get enum_certificationLevel_techDiver => 'Tech Diver';

  @override
  String get enum_certificationLevel_trimix => 'Trimix';

  @override
  String get enum_certificationLevel_wreck => 'Wreck';

  @override
  String get enum_currentDirection_east => 'East';

  @override
  String get enum_currentDirection_none => 'None';

  @override
  String get enum_currentDirection_north => 'North';

  @override
  String get enum_currentDirection_northEast => 'North-East';

  @override
  String get enum_currentDirection_northWest => 'North-West';

  @override
  String get enum_currentDirection_south => 'South';

  @override
  String get enum_currentDirection_southEast => 'South-East';

  @override
  String get enum_currentDirection_southWest => 'South-West';

  @override
  String get enum_currentDirection_variable => 'Variable';

  @override
  String get enum_currentDirection_west => 'West';

  @override
  String get enum_currentStrength_light => 'Light';

  @override
  String get enum_currentStrength_moderate => 'Moderate';

  @override
  String get enum_currentStrength_none => 'None';

  @override
  String get enum_currentStrength_strong => 'Strong';

  @override
  String get enum_diveMode_ccr => 'Closed Circuit Rebreather';

  @override
  String get enum_diveMode_oc => 'Open Circuit';

  @override
  String get enum_diveMode_scr => 'Semi-Closed Rebreather';

  @override
  String get enum_diveType_altitude => 'Altitude';

  @override
  String get enum_diveType_boat => 'Boat';

  @override
  String get enum_diveType_cave => 'Cave';

  @override
  String get enum_diveType_deep => 'Deep';

  @override
  String get enum_diveType_drift => 'Drift';

  @override
  String get enum_diveType_freedive => 'Freedive';

  @override
  String get enum_diveType_ice => 'Ice';

  @override
  String get enum_diveType_liveaboard => 'Liveaboard';

  @override
  String get enum_diveType_night => 'Night';

  @override
  String get enum_diveType_recreational => 'Recreational';

  @override
  String get enum_diveType_shore => 'Shore';

  @override
  String get enum_diveType_technical => 'Technical';

  @override
  String get enum_diveType_training => 'Training';

  @override
  String get enum_diveType_wreck => 'Wreck';

  @override
  String get enum_entryMethod_backRoll => 'Back Roll';

  @override
  String get enum_entryMethod_boat => 'Boat Entry';

  @override
  String get enum_entryMethod_giantStride => 'Giant Stride';

  @override
  String get enum_entryMethod_jetty => 'Jetty/Dock';

  @override
  String get enum_entryMethod_ladder => 'Ladder';

  @override
  String get enum_entryMethod_other => 'Other';

  @override
  String get enum_entryMethod_platform => 'Platform';

  @override
  String get enum_entryMethod_seatedEntry => 'Seated Entry';

  @override
  String get enum_entryMethod_shore => 'Shore Entry';

  @override
  String get enum_equipmentStatus_active => 'Active';

  @override
  String get enum_equipmentStatus_inService => 'In Service';

  @override
  String get enum_equipmentStatus_loaned => 'Loaned Out';

  @override
  String get enum_equipmentStatus_lost => 'Lost';

  @override
  String get enum_equipmentStatus_needsService => 'Needs Service';

  @override
  String get enum_equipmentStatus_retired => 'Retired';

  @override
  String get enum_equipmentType_bcd => 'BCD';

  @override
  String get enum_equipmentType_boots => 'Boots';

  @override
  String get enum_equipmentType_camera => 'Camera';

  @override
  String get enum_equipmentType_computer => 'Dive Computer';

  @override
  String get enum_equipmentType_drysuit => 'Drysuit';

  @override
  String get enum_equipmentType_fins => 'Fins';

  @override
  String get enum_equipmentType_gloves => 'Gloves';

  @override
  String get enum_equipmentType_hood => 'Hood';

  @override
  String get enum_equipmentType_knife => 'Knife';

  @override
  String get enum_equipmentType_light => 'Light';

  @override
  String get enum_equipmentType_mask => 'Mask';

  @override
  String get enum_equipmentType_other => 'Other';

  @override
  String get enum_equipmentType_reel => 'Reel';

  @override
  String get enum_equipmentType_regulator => 'Regulator';

  @override
  String get enum_equipmentType_smb => 'SMB';

  @override
  String get enum_equipmentType_tank => 'Tank';

  @override
  String get enum_equipmentType_weights => 'Weights';

  @override
  String get enum_equipmentType_wetsuit => 'Wetsuit';

  @override
  String get enum_eventSeverity_alert => 'Alert';

  @override
  String get enum_eventSeverity_info => 'Info';

  @override
  String get enum_eventSeverity_warning => 'Warning';

  @override
  String get enum_pdfPageSize_a4 => 'A4';

  @override
  String get enum_pdfPageSize_a4_description => '210 x 297 mm';

  @override
  String get enum_pdfPageSize_letter => 'Letter';

  @override
  String get enum_pdfPageSize_letter_description => '8.5 x 11 in';

  @override
  String get enum_pdfTemplate_detailed => 'Detailed';

  @override
  String get enum_pdfTemplate_detailed_description =>
      'Full dive information with notes and ratings';

  @override
  String get enum_pdfTemplate_nauiStyle => 'NAUI Style';

  @override
  String get enum_pdfTemplate_nauiStyle_description =>
      'Layout matching NAUI logbook format';

  @override
  String get enum_pdfTemplate_padiStyle => 'PADI Style';

  @override
  String get enum_pdfTemplate_padiStyle_description =>
      'Layout matching PADI logbook format';

  @override
  String get enum_pdfTemplate_professional => 'Professional';

  @override
  String get enum_pdfTemplate_professional_description =>
      'Signature and stamp areas for verification';

  @override
  String get enum_pdfTemplate_simple => 'Simple';

  @override
  String get enum_pdfTemplate_simple_description =>
      'Compact table format, many dives per page';

  @override
  String get enum_profileEvent_alert => 'Alert';

  @override
  String get enum_profileEvent_ascentRateCritical => 'Ascent Rate Critical';

  @override
  String get enum_profileEvent_ascentRateWarning => 'Ascent Rate Warning';

  @override
  String get enum_profileEvent_ascentStart => 'Ascent Start';

  @override
  String get enum_profileEvent_bookmark => 'Bookmark';

  @override
  String get enum_profileEvent_cnsCritical => 'CNS Critical';

  @override
  String get enum_profileEvent_cnsWarning => 'CNS Warning';

  @override
  String get enum_profileEvent_decoStopEnd => 'Deco Stop End';

  @override
  String get enum_profileEvent_decoStopStart => 'Deco Stop Start';

  @override
  String get enum_profileEvent_decoViolation => 'Deco Violation';

  @override
  String get enum_profileEvent_descentEnd => 'Descent End';

  @override
  String get enum_profileEvent_descentStart => 'Descent Start';

  @override
  String get enum_profileEvent_gasSwitch => 'Gas Switch';

  @override
  String get enum_profileEvent_lowGas => 'Low Gas Warning';

  @override
  String get enum_profileEvent_maxDepth => 'Max Depth';

  @override
  String get enum_profileEvent_missedStop => 'Missed Deco Stop';

  @override
  String get enum_profileEvent_note => 'Note';

  @override
  String get enum_profileEvent_ppO2High => 'High ppO2';

  @override
  String get enum_profileEvent_ppO2Low => 'Low ppO2';

  @override
  String get enum_profileEvent_safetyStopEnd => 'Safety Stop End';

  @override
  String get enum_profileEvent_safetyStopStart => 'Safety Stop Start';

  @override
  String get enum_profileEvent_setpointChange => 'Setpoint Change';

  @override
  String get enum_profileMetricCategory_decompression => 'Decompression';

  @override
  String get enum_profileMetricCategory_gasAnalysis => 'Gas Analysis';

  @override
  String get enum_profileMetricCategory_gradientFactor => 'Gradient Factors';

  @override
  String get enum_profileMetricCategory_other => 'Other';

  @override
  String get enum_profileMetricCategory_primary => 'Primary Metrics';

  @override
  String get enum_profileMetric_gasDensity => 'Gas Density';

  @override
  String get enum_profileMetric_gasDensity_short => 'Density';

  @override
  String get enum_profileMetric_gf => 'GF%';

  @override
  String get enum_profileMetric_gf_short => 'GF%';

  @override
  String get enum_profileMetric_heartRate => 'Heart Rate';

  @override
  String get enum_profileMetric_heartRate_short => 'HR';

  @override
  String get enum_profileMetric_meanDepth => 'Mean Depth';

  @override
  String get enum_profileMetric_meanDepth_short => 'Mean';

  @override
  String get enum_profileMetric_ndl => 'NDL';

  @override
  String get enum_profileMetric_ndl_short => 'NDL';

  @override
  String get enum_profileMetric_ppHe => 'ppHe';

  @override
  String get enum_profileMetric_ppHe_short => 'ppHe';

  @override
  String get enum_profileMetric_ppN2 => 'ppN2';

  @override
  String get enum_profileMetric_ppN2_short => 'ppN2';

  @override
  String get enum_profileMetric_ppO2 => 'ppO2';

  @override
  String get enum_profileMetric_ppO2_short => 'ppO2';

  @override
  String get enum_profileMetric_pressure => 'Pressure';

  @override
  String get enum_profileMetric_pressure_short => 'Press';

  @override
  String get enum_profileMetric_sacRate => 'SAC Rate';

  @override
  String get enum_profileMetric_sacRate_short => 'SAC';

  @override
  String get enum_profileMetric_surfaceGf => 'Surface GF';

  @override
  String get enum_profileMetric_surfaceGf_short => 'SrfGF';

  @override
  String get enum_profileMetric_temperature => 'Temperature';

  @override
  String get enum_profileMetric_temperature_short => 'Temp';

  @override
  String get enum_profileMetric_tts => 'TTS';

  @override
  String get enum_profileMetric_tts_short => 'TTS';

  @override
  String get enum_scrType_cmf => 'Constant Mass Flow';

  @override
  String get enum_scrType_cmf_short => 'CMF';

  @override
  String get enum_scrType_escr => 'Electronically Controlled';

  @override
  String get enum_scrType_escr_short => 'ESCR';

  @override
  String get enum_scrType_pascr => 'Passive Addition';

  @override
  String get enum_scrType_pascr_short => 'PASCR';

  @override
  String get enum_serviceType_annual => 'Annual Service';

  @override
  String get enum_serviceType_calibration => 'Calibration';

  @override
  String get enum_serviceType_cleaning => 'Cleaning';

  @override
  String get enum_serviceType_inspection => 'Inspection';

  @override
  String get enum_serviceType_other => 'Other';

  @override
  String get enum_serviceType_overhaul => 'Overhaul';

  @override
  String get enum_serviceType_recall => 'Recall/Safety';

  @override
  String get enum_serviceType_repair => 'Repair';

  @override
  String get enum_serviceType_replacement => 'Part Replacement';

  @override
  String get enum_serviceType_warranty => 'Warranty Service';

  @override
  String get enum_sortDirection_ascending => 'Ascending';

  @override
  String get enum_sortDirection_descending => 'Descending';

  @override
  String get enum_sortField_agency => 'Agency';

  @override
  String get enum_sortField_date => 'Date';

  @override
  String get enum_sortField_dateIssued => 'Date Issued';

  @override
  String get enum_sortField_difficulty => 'Difficulty';

  @override
  String get enum_sortField_diveCount => 'Dive Count';

  @override
  String get enum_sortField_diveNumber => 'Dive Number';

  @override
  String get enum_sortField_duration => 'Duration';

  @override
  String get enum_sortField_endDate => 'End Date';

  @override
  String get enum_sortField_lastServiceDate => 'Last Service';

  @override
  String get enum_sortField_maxDepth => 'Max Depth';

  @override
  String get enum_sortField_name => 'Name';

  @override
  String get enum_sortField_purchaseDate => 'Purchase Date';

  @override
  String get enum_sortField_rating => 'Rating';

  @override
  String get enum_sortField_site => 'Site';

  @override
  String get enum_sortField_startDate => 'Start Date';

  @override
  String get enum_sortField_status => 'Status';

  @override
  String get enum_sortField_type => 'Type';

  @override
  String get enum_speciesCategory_coral => 'Coral';

  @override
  String get enum_speciesCategory_fish => 'Fish';

  @override
  String get enum_speciesCategory_invertebrate => 'Invertebrate';

  @override
  String get enum_speciesCategory_mammal => 'Mammal';

  @override
  String get enum_speciesCategory_other => 'Other';

  @override
  String get enum_speciesCategory_plant => 'Plant/Algae';

  @override
  String get enum_speciesCategory_ray => 'Ray';

  @override
  String get enum_speciesCategory_shark => 'Shark';

  @override
  String get enum_speciesCategory_turtle => 'Turtle';

  @override
  String get enum_tankMaterial_aluminum => 'Aluminum';

  @override
  String get enum_tankMaterial_carbonFiber => 'Carbon Fiber';

  @override
  String get enum_tankMaterial_steel => 'Steel';

  @override
  String get enum_tankRole_backGas => 'Back Gas';

  @override
  String get enum_tankRole_bailout => 'Bailout';

  @override
  String get enum_tankRole_deco => 'Deco';

  @override
  String get enum_tankRole_diluent => 'Diluent';

  @override
  String get enum_tankRole_oxygenSupply => 'O₂ Supply';

  @override
  String get enum_tankRole_pony => 'Pony Bottle';

  @override
  String get enum_tankRole_sidemountLeft => 'Sidemount Left';

  @override
  String get enum_tankRole_sidemountRight => 'Sidemount Right';

  @override
  String get enum_tankRole_stage => 'Stage';

  @override
  String get enum_visibility_excellent => 'Excellent (>30m / >100ft)';

  @override
  String get enum_visibility_good => 'Good (15-30m / 50-100ft)';

  @override
  String get enum_visibility_moderate => 'Moderate (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => 'Poor (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => 'Unknown';

  @override
  String get enum_waterType_brackish => 'Brackish';

  @override
  String get enum_waterType_fresh => 'Fresh Water';

  @override
  String get enum_waterType_salt => 'Salt Water';

  @override
  String get enum_weightType_ankleWeights => 'Ankle Weights';

  @override
  String get enum_weightType_backplate => 'Backplate Weights';

  @override
  String get enum_weightType_belt => 'Weight Belt';

  @override
  String get enum_weightType_integrated => 'Integrated Weights';

  @override
  String get enum_weightType_mixed => 'Mixed/Combined';

  @override
  String get enum_weightType_trimWeights => 'Trim Weights';

  @override
  String get equipment_addSheet_brandHint => 'e.g., Scubapro';

  @override
  String get equipment_addSheet_brandLabel => 'Brand';

  @override
  String get equipment_addSheet_closeTooltip => 'Close';

  @override
  String get equipment_addSheet_currencyLabel => 'Currency';

  @override
  String get equipment_addSheet_dateLabel => 'Date';

  @override
  String equipment_addSheet_errorSnackbar(Object error) {
    return 'Error adding equipment: $error';
  }

  @override
  String get equipment_addSheet_modelHint => 'e.g., MK25 EVO';

  @override
  String get equipment_addSheet_modelLabel => 'Model';

  @override
  String get equipment_addSheet_nameHint => 'e.g., My Primary Regulator';

  @override
  String get equipment_addSheet_nameLabel => 'Name';

  @override
  String get equipment_addSheet_nameValidation => 'Please enter a name';

  @override
  String get equipment_addSheet_notesHint => 'Additional notes...';

  @override
  String get equipment_addSheet_notesLabel => 'Notes';

  @override
  String get equipment_addSheet_priceLabel => 'Price';

  @override
  String get equipment_addSheet_purchaseInfoTitle => 'Purchase Information';

  @override
  String get equipment_addSheet_serialNumberLabel => 'Serial Number';

  @override
  String get equipment_addSheet_serviceIntervalHint => 'e.g., 365 for yearly';

  @override
  String get equipment_addSheet_serviceIntervalLabel =>
      'Service Interval (days)';

  @override
  String get equipment_addSheet_sizeHint => 'e.g., M, L, 42';

  @override
  String get equipment_addSheet_sizeLabel => 'Size';

  @override
  String get equipment_addSheet_submitButton => 'Add Equipment';

  @override
  String get equipment_addSheet_successSnackbar =>
      'Equipment added successfully';

  @override
  String get equipment_addSheet_title => 'Add Equipment';

  @override
  String get equipment_addSheet_typeLabel => 'Type';

  @override
  String get equipment_appBar_title => 'Equipment';

  @override
  String get equipment_deleteDialog_cancel => 'Cancel';

  @override
  String get equipment_deleteDialog_confirm => 'Delete';

  @override
  String get equipment_deleteDialog_content =>
      'Are you sure you want to delete this equipment? This action cannot be undone.';

  @override
  String get equipment_deleteDialog_title => 'Delete Equipment';

  @override
  String get equipment_detail_brandLabel => 'Brand';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return '$days days overdue';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days days until service';
  }

  @override
  String get equipment_detail_detailsTitle => 'Details';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count dives';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count dive';
  }

  @override
  String get equipment_detail_divesLabel => 'Dives';

  @override
  String get equipment_detail_divesSemanticLabel =>
      'View dives using this equipment';

  @override
  String equipment_detail_durationDays(Object days) {
    return '$days days';
  }

  @override
  String equipment_detail_durationMonths(Object months) {
    return '$months months';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralPlural(
    Object years,
    Object months,
  ) {
    return '$years years, $months months';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralSingular(
    Object years,
    Object months,
  ) {
    return '$years years, $months month';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularPlural(
    Object years,
    Object months,
  ) {
    return '$years year, $months months';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularSingular(
    Object years,
    Object months,
  ) {
    return '$years year, $months month';
  }

  @override
  String equipment_detail_durationYearsPlural(Object years) {
    return '$years years';
  }

  @override
  String equipment_detail_durationYearsSingular(Object years) {
    return '$years year';
  }

  @override
  String get equipment_detail_editTooltip => 'Edit Equipment';

  @override
  String get equipment_detail_editTooltipShort => 'Edit';

  @override
  String equipment_detail_errorMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get equipment_detail_errorTitle => 'Error';

  @override
  String get equipment_detail_lastServiceLabel => 'Last Service';

  @override
  String get equipment_detail_loadingTitle => 'Loading...';

  @override
  String get equipment_detail_modelLabel => 'Model';

  @override
  String get equipment_detail_nextServiceDueLabel => 'Next Service Due';

  @override
  String get equipment_detail_notFoundMessage =>
      'This equipment item no longer exists.';

  @override
  String get equipment_detail_notFoundTitle => 'Equipment Not Found';

  @override
  String get equipment_detail_notesTitle => 'Notes';

  @override
  String get equipment_detail_ownedForLabel => 'Owned For';

  @override
  String get equipment_detail_purchaseDateLabel => 'Purchase Date';

  @override
  String get equipment_detail_purchasePriceLabel => 'Purchase Price';

  @override
  String get equipment_detail_retiredChip => 'Retired';

  @override
  String get equipment_detail_serialNumberLabel => 'Serial Number';

  @override
  String get equipment_detail_serviceInfoTitle => 'Service Information';

  @override
  String get equipment_detail_serviceIntervalLabel => 'Service Interval';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days days';
  }

  @override
  String get equipment_detail_serviceOverdue => 'Service is overdue!';

  @override
  String get equipment_detail_sizeLabel => 'Size';

  @override
  String get equipment_detail_statusLabel => 'Status';

  @override
  String equipment_detail_tripsCountPlural(Object count) {
    return '$count trips';
  }

  @override
  String equipment_detail_tripsCountSingular(Object count) {
    return '$count trip';
  }

  @override
  String get equipment_detail_tripsLabel => 'Trips';

  @override
  String get equipment_detail_tripsSemanticLabel =>
      'View trips using this equipment';

  @override
  String get equipment_edit_appBar_editTitle => 'Edit Equipment';

  @override
  String get equipment_edit_appBar_newTitle => 'New Equipment';

  @override
  String get equipment_edit_appBar_saveButton => 'Save';

  @override
  String get equipment_edit_appBar_saveTooltip => 'Save equipment changes';

  @override
  String get equipment_edit_brandLabel => 'Brand';

  @override
  String get equipment_edit_clearDate => 'Clear Date';

  @override
  String get equipment_edit_currencyLabel => 'Currency';

  @override
  String get equipment_edit_disableReminders => 'Disable Reminders';

  @override
  String get equipment_edit_disableRemindersSubtitle =>
      'Turn off all notifications for this item';

  @override
  String get equipment_edit_discardDialog_content =>
      'You have unsaved changes. Are you sure you want to leave?';

  @override
  String get equipment_edit_discardDialog_discard => 'Discard';

  @override
  String get equipment_edit_discardDialog_keepEditing => 'Keep Editing';

  @override
  String get equipment_edit_discardDialog_title => 'Discard Changes?';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => 'Cancel';

  @override
  String get equipment_edit_embeddedHeader_editTitle => 'Edit Equipment';

  @override
  String get equipment_edit_embeddedHeader_newTitle => 'New Equipment';

  @override
  String get equipment_edit_embeddedHeader_saveButton => 'Save';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit =>
      'Save equipment changes';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new =>
      'Add new equipment';

  @override
  String equipment_edit_errorMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get equipment_edit_errorTitle => 'Error';

  @override
  String get equipment_edit_lastServiceDateLabel => 'Last Service Date';

  @override
  String get equipment_edit_loadingTitle => 'Loading...';

  @override
  String get equipment_edit_modelLabel => 'Model';

  @override
  String get equipment_edit_nameHint => 'e.g., My Primary Regulator';

  @override
  String get equipment_edit_nameLabel => 'Name *';

  @override
  String get equipment_edit_nameValidation => 'Please enter a name';

  @override
  String get equipment_edit_notFoundMessage =>
      'This equipment item no longer exists.';

  @override
  String get equipment_edit_notFoundTitle => 'Equipment Not Found';

  @override
  String get equipment_edit_notesHint =>
      'Additional notes about this equipment...';

  @override
  String get equipment_edit_notesLabel => 'Notes';

  @override
  String get equipment_edit_notificationsSubtitle =>
      'Override global notification settings for this item';

  @override
  String get equipment_edit_notificationsTitle => 'Notifications (Optional)';

  @override
  String get equipment_edit_purchaseDateLabel => 'Purchase Date';

  @override
  String get equipment_edit_purchaseInfoTitle => 'Purchase Information';

  @override
  String get equipment_edit_purchasePriceLabel => 'Purchase Price';

  @override
  String get equipment_edit_remindMeBeforeServiceDue =>
      'Remind me before service is due:';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days days';
  }

  @override
  String get equipment_edit_saveButton_edit => 'Save Changes';

  @override
  String get equipment_edit_saveButton_new => 'Add Equipment';

  @override
  String get equipment_edit_saveTooltip_edit => 'Save equipment changes';

  @override
  String get equipment_edit_saveTooltip_new => 'Add new equipment item';

  @override
  String get equipment_edit_selectDate => 'Select Date';

  @override
  String get equipment_edit_serialNumberLabel => 'Serial Number';

  @override
  String get equipment_edit_serviceIntervalHint => 'e.g., 365 for yearly';

  @override
  String get equipment_edit_serviceIntervalLabel => 'Service Interval (days)';

  @override
  String get equipment_edit_serviceSettingsTitle => 'Service Settings';

  @override
  String get equipment_edit_sizeHint => 'e.g., M, L, 42';

  @override
  String get equipment_edit_sizeLabel => 'Size';

  @override
  String get equipment_edit_snackbar_added => 'Equipment added';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return 'Error saving equipment: $error';
  }

  @override
  String get equipment_edit_snackbar_updated => 'Equipment updated';

  @override
  String get equipment_edit_statusLabel => 'Status';

  @override
  String get equipment_edit_typeLabel => 'Type *';

  @override
  String get equipment_edit_useCustomReminders => 'Use Custom Reminders';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'Set different reminder days for this item';

  @override
  String get equipment_fab_addEquipment => 'Add Equipment';

  @override
  String get equipment_list_emptyState_addFirstButton =>
      'Add Your First Equipment';

  @override
  String get equipment_list_emptyState_addPrompt =>
      'Add your diving equipment to track usage and service';

  @override
  String get equipment_list_emptyState_filterText_equipment => 'equipment';

  @override
  String get equipment_list_emptyState_filterText_serviceDue =>
      'equipment needing service';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return '$status equipment';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return 'No $filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch =>
      'No equipment with this status';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate =>
      'All your equipment is up to date on service!';

  @override
  String equipment_list_errorLoading(Object error) {
    return 'Error loading equipment: $error';
  }

  @override
  String get equipment_list_filterAll => 'All Equipment';

  @override
  String get equipment_list_filterLabel => 'Filter:';

  @override
  String get equipment_list_filterServiceDue => 'Service Due';

  @override
  String get equipment_list_retryButton => 'Retry';

  @override
  String get equipment_list_searchTooltip => 'Search Equipment';

  @override
  String get equipment_list_setsTooltip => 'Equipment Sets';

  @override
  String get equipment_list_sortTitle => 'Sort Equipment';

  @override
  String get equipment_list_sortTooltip => 'Sort';

  @override
  String equipment_list_tile_daysCount(Object days) {
    return '$days days';
  }

  @override
  String get equipment_list_tile_serviceDueChip => 'Service Due';

  @override
  String get equipment_list_tile_serviceIn => 'Service in';

  @override
  String get equipment_menu_delete => 'Delete';

  @override
  String get equipment_menu_markAsServiced => 'Mark as Serviced';

  @override
  String get equipment_menu_reactivate => 'Reactivate';

  @override
  String get equipment_menu_retireEquipment => 'Retire Equipment';

  @override
  String get equipment_search_backTooltip => 'Back';

  @override
  String get equipment_search_clearTooltip => 'Clear Search';

  @override
  String get equipment_search_fieldLabel => 'Search equipment...';

  @override
  String get equipment_search_hint =>
      'Search by name, brand, model, or serial number';

  @override
  String equipment_search_noResults(Object query) {
    return 'No equipment found for \"$query\"';
  }

  @override
  String get equipment_serviceDialog_addButton => 'Add';

  @override
  String get equipment_serviceDialog_addTitle => 'Add Service Record';

  @override
  String get equipment_serviceDialog_cancelButton => 'Cancel';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip =>
      'Clear Next Service Date';

  @override
  String get equipment_serviceDialog_costHint => '0.00';

  @override
  String get equipment_serviceDialog_costLabel => 'Cost';

  @override
  String get equipment_serviceDialog_costValidation => 'Enter a valid amount';

  @override
  String get equipment_serviceDialog_editTitle => 'Edit Service Record';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel => 'Next Service Due';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel =>
      'Pick next service due date';

  @override
  String get equipment_serviceDialog_nextServiceNotSet => 'Not set';

  @override
  String get equipment_serviceDialog_notesLabel => 'Notes';

  @override
  String get equipment_serviceDialog_providerHint => 'e.g., Dive Shop Name';

  @override
  String get equipment_serviceDialog_providerLabel => 'Provider/Shop';

  @override
  String get equipment_serviceDialog_serviceDateLabel => 'Service Date';

  @override
  String get equipment_serviceDialog_serviceDateSemanticLabel =>
      'Pick service date';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => 'Service Type';

  @override
  String get equipment_serviceDialog_snackbar_added => 'Service record added';

  @override
  String equipment_serviceDialog_snackbar_error(Object error) {
    return 'Error: $error';
  }

  @override
  String get equipment_serviceDialog_snackbar_updated =>
      'Service record updated';

  @override
  String get equipment_serviceDialog_updateButton => 'Update';

  @override
  String get equipment_service_addButton => 'Add';

  @override
  String get equipment_service_deleteDialog_cancel => 'Cancel';

  @override
  String get equipment_service_deleteDialog_confirm => 'Delete';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return 'Are you sure you want to delete this $serviceType record?';
  }

  @override
  String get equipment_service_deleteDialog_title => 'Delete Service Record?';

  @override
  String get equipment_service_deleteMenuItem => 'Delete';

  @override
  String get equipment_service_editMenuItem => 'Edit';

  @override
  String get equipment_service_emptyState => 'No service records yet';

  @override
  String get equipment_service_historyTitle => 'Service History';

  @override
  String get equipment_service_snackbar_deleted => 'Service record deleted';

  @override
  String get equipment_service_totalCostLabel => 'Total Service Cost';

  @override
  String get equipment_setDetail_addEquipmentButton => 'Add Equipment';

  @override
  String get equipment_setDetail_deleteDialog_cancel => 'Cancel';

  @override
  String get equipment_setDetail_deleteDialog_confirm => 'Delete';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      'Are you sure you want to delete this equipment set? The equipment items in the set will not be deleted.';

  @override
  String get equipment_setDetail_deleteDialog_title => 'Delete Equipment Set';

  @override
  String get equipment_setDetail_deleteMenuItem => 'Delete';

  @override
  String get equipment_setDetail_editTooltip => 'Edit Set';

  @override
  String get equipment_setDetail_emptySet => 'No equipment in this set';

  @override
  String get equipment_setDetail_equipmentInSetTitle => 'Equipment in This Set';

  @override
  String equipment_setDetail_errorMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get equipment_setDetail_errorTitle => 'Error';

  @override
  String get equipment_setDetail_loadingTitle => 'Loading...';

  @override
  String get equipment_setDetail_notFoundMessage =>
      'This equipment set no longer exists.';

  @override
  String get equipment_setDetail_notFoundTitle => 'Set Not Found';

  @override
  String get equipment_setDetail_snackbar_deleted => 'Equipment set deleted';

  @override
  String get equipment_setEdit_addEquipmentFirst =>
      'Add equipment first before creating a set.';

  @override
  String get equipment_setEdit_appBar_editTitle => 'Edit Set';

  @override
  String get equipment_setEdit_appBar_newTitle => 'New Equipment Set';

  @override
  String get equipment_setEdit_descriptionHint => 'Optional description...';

  @override
  String get equipment_setEdit_descriptionLabel => 'Description';

  @override
  String equipment_setEdit_errorMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get equipment_setEdit_errorTitle => 'Error';

  @override
  String get equipment_setEdit_loadingTitle => 'Loading...';

  @override
  String get equipment_setEdit_nameHint => 'e.g., Warm Water Setup';

  @override
  String get equipment_setEdit_nameLabel => 'Set Name *';

  @override
  String get equipment_setEdit_nameValidation => 'Please enter a name';

  @override
  String get equipment_setEdit_noEquipmentAvailable => 'No equipment available';

  @override
  String get equipment_setEdit_notFoundMessage =>
      'This equipment set no longer exists.';

  @override
  String get equipment_setEdit_notFoundTitle => 'Set Not Found';

  @override
  String get equipment_setEdit_saveButton_edit => 'Save Changes';

  @override
  String get equipment_setEdit_saveButton_new => 'Create Set';

  @override
  String get equipment_setEdit_saveTooltip_edit => 'Save equipment set changes';

  @override
  String get equipment_setEdit_saveTooltip_new => 'Create new equipment set';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle =>
      'Choose the equipment items to include in this set.';

  @override
  String get equipment_setEdit_selectEquipmentTitle => 'Select Equipment';

  @override
  String get equipment_setEdit_snackbar_created => 'Equipment set created';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return 'Error saving equipment set: $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated => 'Equipment set updated';

  @override
  String get equipment_sets_appBar_title => 'Equipment Sets';

  @override
  String get equipment_sets_emptyState_createFirstButton =>
      'Create Your First Set';

  @override
  String get equipment_sets_emptyState_description =>
      'Create equipment sets to quickly add commonly used combinations of equipment to your dives.';

  @override
  String get equipment_sets_emptyState_title => 'No Equipment Sets';

  @override
  String equipment_sets_errorLoading(Object error) {
    return 'Error loading sets: $error';
  }

  @override
  String get equipment_sets_fabTooltip => 'Create a new equipment set';

  @override
  String get equipment_sets_fab_createSet => 'Create Set';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count items';
  }

  @override
  String equipment_sets_itemCountSemanticLabel(Object count) {
    return '$count in set';
  }

  @override
  String equipment_sets_itemCountSingular(Object count) {
    return '$count item';
  }

  @override
  String get equipment_sets_retryButton => 'Retry';

  @override
  String get equipment_snackbar_deleted => 'Equipment deleted';

  @override
  String get equipment_snackbar_markedAsServiced => 'Marked as serviced';

  @override
  String get equipment_snackbar_reactivated => 'Equipment reactivated';

  @override
  String get equipment_snackbar_retired => 'Equipment retired';

  @override
  String get equipment_summary_active => 'Active';

  @override
  String get equipment_summary_addEquipmentButton => 'Add Equipment';

  @override
  String get equipment_summary_equipmentSetsButton => 'Equipment Sets';

  @override
  String get equipment_summary_overviewTitle => 'Overview';

  @override
  String get equipment_summary_quickActionsTitle => 'Quick Actions';

  @override
  String get equipment_summary_recentEquipmentTitle => 'Recent Equipment';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name, $type';
  }

  @override
  String get equipment_summary_selectPrompt =>
      'Select equipment from the list to view details';

  @override
  String get equipment_summary_serviceDue => 'Service Due';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name, $type, service due';
  }

  @override
  String get equipment_summary_serviceDueTitle => 'Service Due';

  @override
  String get equipment_summary_title => 'Equipment';

  @override
  String get equipment_summary_totalItems => 'Total Items';

  @override
  String get equipment_summary_totalValue => 'Total Value';

  @override
  String get formatter_approximate_prefix => '~';

  @override
  String get formatter_connector_at => 'at';

  @override
  String get formatter_connector_from => 'From';

  @override
  String get formatter_connector_until => 'Until';

  @override
  String get gas_air_description => 'Standard air (21% O2)';

  @override
  String get gas_air_displayName => 'Air';

  @override
  String get gas_diluentAir_description =>
      'Standard air diluent for shallow CCR';

  @override
  String get gas_diluentAir_displayName => 'Air Diluent';

  @override
  String get gas_diluentTx1070_description =>
      'Hypoxic diluent for very deep CCR';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description => 'Hypoxic diluent for deep CCR';

  @override
  String get gas_diluentTx1260_displayName => 'Tx 12/60';

  @override
  String get gas_ean32_description => 'Enriched Air Nitrox 32%';

  @override
  String get gas_ean32_displayName => 'EAN32';

  @override
  String get gas_ean36_description => 'Enriched Air Nitrox 36%';

  @override
  String get gas_ean36_displayName => 'EAN36';

  @override
  String get gas_ean40_description => 'Enriched Air Nitrox 40%';

  @override
  String get gas_ean40_displayName => 'EAN40';

  @override
  String get gas_ean50_description => 'Deco gas - 50% O2';

  @override
  String get gas_ean50_displayName => 'EAN50';

  @override
  String get gas_helitrox2525_description =>
      'Helitrox 25/25 (recreational tech)';

  @override
  String get gas_helitrox2525_displayName => 'Helitrox 25/25';

  @override
  String get gas_oxygen_description => 'Pure oxygen (6m deco only)';

  @override
  String get gas_oxygen_displayName => 'Oxygen';

  @override
  String get gas_scrEan40_description => 'SCR supply gas - 40% O2';

  @override
  String get gas_scrEan40_displayName => 'SCR EAN40';

  @override
  String get gas_scrEan50_description => 'SCR supply gas - 50% O2';

  @override
  String get gas_scrEan50_displayName => 'SCR EAN50';

  @override
  String get gas_scrEan60_description => 'SCR supply gas - 60% O2';

  @override
  String get gas_scrEan60_displayName => 'SCR EAN60';

  @override
  String get gas_tmx1555_description => 'Hypoxic trimix 15/55 (very deep)';

  @override
  String get gas_tmx1555_displayName => 'Tx 15/55';

  @override
  String get gas_tmx1845_description => 'Trimix 18/45 (deep diving)';

  @override
  String get gas_tmx1845_displayName => 'Tx 18/45';

  @override
  String get gas_tmx2135_description => 'Normoxic trimix 21/35';

  @override
  String get gas_tmx2135_displayName => 'Tx 21/35';

  @override
  String get gasCalculators_bestMix_bestOxygenMix => 'Best Oxygen Mix';

  @override
  String get gasCalculators_bestMix_commonMixesRef => 'Common Mixes Reference';

  @override
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2) {
    return 'Air MOD exceeded at ppO₂ $ppO2';
  }

  @override
  String get gasCalculators_bestMix_targetDepth => 'Target Depth';

  @override
  String get gasCalculators_bestMix_targetDive => 'Target Dive';

  @override
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  ) {
    return 'Ambient pressure at $depth$depthSymbol';
  }

  @override
  String get gasCalculators_consumption_avgDepth => 'Average Depth';

  @override
  String get gasCalculators_consumption_breakdown => 'Calculation Breakdown';

  @override
  String get gasCalculators_consumption_diveTime => 'Dive Time';

  @override
  String gasCalculators_consumption_exceedsTank(
    Object pressure,
    Object symbol,
  ) {
    return 'Exceeds tank capacity ($pressure $symbol)';
  }

  @override
  String get gasCalculators_consumption_gasAtDepth =>
      'Gas consumption at depth';

  @override
  String get gasCalculators_consumption_pressure => 'Pressure';

  @override
  String get gasCalculators_consumption_remainingGas => 'Remaining gas';

  @override
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  ) {
    return 'Tank capacity ($tankSize$volumeSymbol @ $fillPressure $pressureSymbol)';
  }

  @override
  String get gasCalculators_consumption_title => 'Gas Consumption';

  @override
  String gasCalculators_consumption_totalGas(Object time) {
    return 'Total gas for $time minutes';
  }

  @override
  String get gasCalculators_consumption_volume => 'Volume';

  @override
  String get gasCalculators_mod_aboutMod => 'About MOD';

  @override
  String get gasCalculators_mod_aboutModBody =>
      'Lower O₂ = deeper MOD = shorter NDL';

  @override
  String get gasCalculators_mod_inputParameters => 'Input Parameters';

  @override
  String get gasCalculators_mod_maximumOperatingDepth =>
      'Maximum Operating Depth';

  @override
  String get gasCalculators_mod_oxygenO2 => 'Oxygen (O₂)';

  @override
  String get gasCalculators_mod_ppO2Conservative =>
      'Conservative limit for extended bottom time';

  @override
  String get gasCalculators_mod_ppO2Maximum =>
      'Maximum limit for decompression stops only';

  @override
  String get gasCalculators_mod_ppO2Standard =>
      'Standard working limit for recreational diving';

  @override
  String get gasCalculators_ppO2Limit => 'ppO₂ Limit';

  @override
  String get gasCalculators_resetAll => 'Reset all calculators';

  @override
  String get gasCalculators_sacRate => 'SAC Rate';

  @override
  String get gasCalculators_tab_bestMix => 'Best Mix';

  @override
  String get gasCalculators_tab_consumption => 'Consumption';

  @override
  String get gasCalculators_tab_mod => 'MOD';

  @override
  String get gasCalculators_tab_rockBottom => 'Rock Bottom';

  @override
  String get gasCalculators_tankSize => 'Tank Size';

  @override
  String get gasCalculators_title => 'Gas Calculators';

  @override
  String get marineLife_siteSection_editExpectedTooltip =>
      'Edit expected species';

  @override
  String get marineLife_siteSection_errorLoadingExpected =>
      'Error loading expected species';

  @override
  String get marineLife_siteSection_errorLoadingSightings =>
      'Error loading sightings';

  @override
  String get marineLife_siteSection_expectedSpecies => 'Expected Species';

  @override
  String get marineLife_siteSection_noExpected => 'No expected species added';

  @override
  String get marineLife_siteSection_noSpotted => 'No marine life spotted yet';

  @override
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  ) {
    return '$name, spotted $count times';
  }

  @override
  String get marineLife_siteSection_spottedHere => 'Spotted Here';

  @override
  String get marineLife_siteSection_title => 'Marine Life';

  @override
  String get marineLife_speciesDetail_backTooltip => 'Back';

  @override
  String get marineLife_speciesDetail_depthRangeTitle => 'Depth Range';

  @override
  String get marineLife_speciesDetail_descriptionTitle => 'Description';

  @override
  String get marineLife_speciesDetail_divesLabel => 'Dives';

  @override
  String get marineLife_speciesDetail_editTooltip => 'Edit species';

  @override
  String marineLife_speciesDetail_errorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get marineLife_speciesDetail_noSightings =>
      'No sightings recorded yet';

  @override
  String get marineLife_speciesDetail_notFound => 'Species not found';

  @override
  String marineLife_speciesDetail_sightingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sightings',
      one: 'sighting',
    );
    return '$count $_temp0';
  }

  @override
  String get marineLife_speciesDetail_sightingPeriodTitle => 'Sighting Period';

  @override
  String get marineLife_speciesDetail_sightingStatsTitle =>
      'Sighting Statistics';

  @override
  String get marineLife_speciesDetail_sitesLabel => 'Sites';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return 'Class: $className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle => 'Top Sites';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel => 'Total Sightings';

  @override
  String get marineLife_speciesEdit_addTitle => 'Add Species';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return 'Added \"$name\"';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => 'Back';

  @override
  String get marineLife_speciesEdit_categoryLabel => 'Category';

  @override
  String get marineLife_speciesEdit_commonNameError =>
      'Please enter a common name';

  @override
  String get marineLife_speciesEdit_commonNameHint =>
      'e.g., Ocellaris Clownfish';

  @override
  String get marineLife_speciesEdit_commonNameLabel => 'Common Name';

  @override
  String get marineLife_speciesEdit_descriptionHint =>
      'Brief description of the species...';

  @override
  String get marineLife_speciesEdit_descriptionLabel => 'Description';

  @override
  String get marineLife_speciesEdit_editTitle => 'Edit Species';

  @override
  String marineLife_speciesEdit_errorLoading(Object error) {
    return 'Error loading species: $error';
  }

  @override
  String marineLife_speciesEdit_errorSaving(Object error) {
    return 'Error saving species: $error';
  }

  @override
  String get marineLife_speciesEdit_saveButton => 'Save';

  @override
  String get marineLife_speciesEdit_scientificNameHint =>
      'e.g., Amphiprion ocellaris';

  @override
  String get marineLife_speciesEdit_scientificNameLabel => 'Scientific Name';

  @override
  String get marineLife_speciesEdit_taxonomyClassHint => 'e.g., Actinopterygii';

  @override
  String get marineLife_speciesEdit_taxonomyClassLabel => 'Taxonomy Class';

  @override
  String marineLife_speciesEdit_updatedSnackbar(Object name) {
    return 'Updated \"$name\"';
  }

  @override
  String get marineLife_speciesManage_allFilter => 'All';

  @override
  String get marineLife_speciesManage_appBarTitle => 'Species';

  @override
  String get marineLife_speciesManage_backTooltip => 'Back';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return 'Built-in Species ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => 'Cancel';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return 'Cannot delete \"$name\" - it has sightings';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip => 'Clear search';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return 'Custom Species ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => 'Delete';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle => 'Delete Species?';

  @override
  String get marineLife_speciesManage_deleteTooltip => 'Delete species';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get marineLife_speciesManage_editTooltip => 'Edit species';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return 'Error deleting species: $error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return 'Error resetting species: $error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound => 'No species found';

  @override
  String get marineLife_speciesManage_resetButton => 'Reset';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      'This will restore all built-in species to their original values. Custom species will not be affected. Built-in species with existing sightings will be updated but preserved.';

  @override
  String get marineLife_speciesManage_resetDialogTitle => 'Reset to Defaults?';

  @override
  String get marineLife_speciesManage_resetSuccess =>
      'Built-in species restored to defaults';

  @override
  String get marineLife_speciesManage_resetToDefaults => 'Reset to Defaults';

  @override
  String get marineLife_speciesManage_searchHint => 'Search species...';

  @override
  String get marineLife_speciesPicker_allFilter => 'All';

  @override
  String get marineLife_speciesPicker_cancelButton => 'Cancel';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip => 'Clear search';

  @override
  String get marineLife_speciesPicker_closeTooltip => 'Close species picker';

  @override
  String get marineLife_speciesPicker_doneButton => 'Done';

  @override
  String marineLife_speciesPicker_error(Object error) {
    return 'Error: $error';
  }

  @override
  String get marineLife_speciesPicker_noSpeciesFound => 'No species found';

  @override
  String get marineLife_speciesPicker_searchHint => 'Search species...';

  @override
  String marineLife_speciesPicker_selectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get marineLife_speciesPicker_title => 'Select Species';

  @override
  String get media_diveMediaSection_addTooltip => 'Add photo or video';

  @override
  String get media_diveMediaSection_cancelButton => 'Cancel';

  @override
  String get media_diveMediaSection_emptyState => 'No photos yet';

  @override
  String get media_diveMediaSection_errorLoading => 'Error loading media';

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'View photo. Long press to unlink';

  @override
  String get media_diveMediaSection_title => 'Photos & Video';

  @override
  String get media_diveMediaSection_unlinkButton => 'Unlink';

  @override
  String get media_diveMediaSection_unlinkDialogContent =>
      'Remove this photo from the dive? The photo will remain in your gallery.';

  @override
  String get media_diveMediaSection_unlinkDialogTitle => 'Unlink Photo';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Failed to unlink: $error';
  }

  @override
  String get media_diveMediaSection_unlinkSuccess => 'Photo unlinked';

  @override
  String get media_gpsBanner_addToSiteButton => 'Add to Site';

  @override
  String media_gpsBanner_coordinates(Object latitude, Object longitude) {
    return 'Coordinates: $latitude, $longitude';
  }

  @override
  String get media_gpsBanner_createSiteButton => 'Create Site';

  @override
  String get media_gpsBanner_dismissTooltip => 'Dismiss GPS suggestion';

  @override
  String get media_gpsBanner_title => 'GPS found in photos';

  @override
  String media_import_failedToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'photos',
      one: 'photo',
    );
    return 'Failed to import $_temp0';
  }

  @override
  String media_import_failedToImportError(Object error) {
    return 'Failed to import photos: $error';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return 'Imported $imported, failed $failed';
  }

  @override
  String media_import_importedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'photos',
      one: 'photo',
    );
    return 'Imported $count $_temp0';
  }

  @override
  String media_import_importingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'photos',
      one: 'photo',
    );
    return 'Importing $count $_temp0...';
  }

  @override
  String get media_miniProfile_headerLabel => 'Dive Profile';

  @override
  String get media_miniProfile_semanticLabel => 'Mini dive profile chart';

  @override
  String get media_photoPicker_appBarTitle => 'Select Photos';

  @override
  String get media_photoPicker_closeTooltip => 'Close photo picker';

  @override
  String get media_photoPicker_doneButton => 'Done';

  @override
  String media_photoPicker_doneCountButton(Object count) {
    return 'Done ($count)';
  }

  @override
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  ) {
    return 'No photos were found between $startDate $startTime and $endDate $endTime.';
  }

  @override
  String get media_photoPicker_emptyTitle => 'No photos found';

  @override
  String get media_photoPicker_grantAccessButton => 'Grant Access';

  @override
  String get media_photoPicker_openSettingsButton => 'Open Settings';

  @override
  String get media_photoPicker_openSettingsSnackbar =>
      'Please open Settings and enable photo access';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'Photo library access was denied. Please enable it in Settings to add dive photos.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion needs access to your photo library to add dive photos.';

  @override
  String get media_photoPicker_permissionTitle => 'Photo Access Required';

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return 'Showing photos from $rangeText';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel =>
      'Toggle selection for photo';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel =>
      'Toggle selection for photo, selected';

  @override
  String get media_photoViewer_cannotShare => 'Cannot share this photo';

  @override
  String get media_photoViewer_cannotWriteMetadata =>
      'Cannot write metadata - media not linked to library';

  @override
  String get media_photoViewer_closeTooltip => 'Close photo viewer';

  @override
  String get media_photoViewer_diveDataWrittenToPhoto =>
      'Dive data written to photo';

  @override
  String get media_photoViewer_diveDataWrittenToVideo =>
      'Dive data written to video';

  @override
  String media_photoViewer_errorLoadingPhotos(Object error) {
    return 'Error loading photos: $error';
  }

  @override
  String get media_photoViewer_failedToLoadImage => 'Failed to load image';

  @override
  String get media_photoViewer_failedToLoadVideo => 'Failed to load video';

  @override
  String media_photoViewer_failedToShare(Object error) {
    return 'Failed to share: $error';
  }

  @override
  String get media_photoViewer_failedToWriteMetadata =>
      'Failed to write metadata';

  @override
  String media_photoViewer_failedToWriteMetadataError(Object error) {
    return 'Failed to write metadata: $error';
  }

  @override
  String get media_photoViewer_noPhotosAvailable => 'No photos available';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel => 'Play or pause video';

  @override
  String get media_photoViewer_seekVideoLabel => 'Seek video position';

  @override
  String get media_photoViewer_shareTooltip => 'Share photo';

  @override
  String get media_photoViewer_toggleOverlayLabel => 'Toggle photo overlay';

  @override
  String get media_photoViewer_videoFileNotFound => 'Video file not found';

  @override
  String get media_photoViewer_videoNotLinked => 'Video not linked to library';

  @override
  String get media_photoViewer_writeDiveDataTooltip =>
      'Write dive data to photo';

  @override
  String get media_quickSiteDialog_cancelButton => 'Cancel';

  @override
  String get media_quickSiteDialog_createButton => 'Create Site';

  @override
  String get media_quickSiteDialog_description =>
      'Create a new dive site using GPS coordinates from your photo.';

  @override
  String get media_quickSiteDialog_siteNameError => 'Please enter a site name';

  @override
  String get media_quickSiteDialog_siteNameHint => 'Enter a name for this site';

  @override
  String get media_quickSiteDialog_siteNameLabel => 'Site Name';

  @override
  String get media_quickSiteDialog_title => 'Create Dive Site';

  @override
  String get media_scanResults_allPhotosLinked => 'All photos already linked';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return 'All $count photos from this trip are already linked to dives.';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count photos already linked';
  }

  @override
  String get media_scanResults_cancelButton => 'Cancel';

  @override
  String media_scanResults_diveNumber(Object number) {
    return 'Dive #$number';
  }

  @override
  String media_scanResults_foundNewPhotos(Object count) {
    return 'Found $count new photos';
  }

  @override
  String get media_scanResults_linkButton => 'Link';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return 'Link $count photos';
  }

  @override
  String get media_scanResults_noPhotosFound => 'No photos found';

  @override
  String get media_scanResults_okButton => 'OK';

  @override
  String get media_scanResults_unknownSite => 'Unknown site';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return '$count photos could not be matched to any dive (taken outside dive times)';
  }

  @override
  String get media_writeMetadata_cancelButton => 'Cancel';

  @override
  String get media_writeMetadata_depthLabel => 'Depth';

  @override
  String get media_writeMetadata_descriptionPhoto =>
      'The following metadata will be written to the photo:';

  @override
  String get media_writeMetadata_descriptionVideo =>
      'The following metadata will be written to the video:';

  @override
  String get media_writeMetadata_diveTimeLabel => 'Dive time';

  @override
  String get media_writeMetadata_gpsLabel => 'GPS';

  @override
  String get media_writeMetadata_keepOriginalVideo => 'Keep original video';

  @override
  String get media_writeMetadata_noDataAvailable =>
      'No dive data available to write.';

  @override
  String get media_writeMetadata_siteLabel => 'Site';

  @override
  String get media_writeMetadata_temperatureLabel => 'Temperature';

  @override
  String get media_writeMetadata_titlePhoto => 'Write Dive Data to Photo';

  @override
  String get media_writeMetadata_titleVideo => 'Write Dive Data to Video';

  @override
  String get media_writeMetadata_warningPhotoText =>
      'This will modify the original photo.';

  @override
  String get media_writeMetadata_warningVideoText =>
      'A new video will be created with the metadata. Video metadata cannot be modified in-place.';

  @override
  String get media_writeMetadata_writeButton => 'Write';

  @override
  String get nav_buddies => 'Buddies';

  @override
  String get nav_certifications => 'Certifications';

  @override
  String get nav_courses => 'Courses';

  @override
  String get nav_coursesSubtitle => 'Training & Education';

  @override
  String get nav_diveCenters => 'Dive Centers';

  @override
  String get nav_dives => 'Dives';

  @override
  String get nav_equipment => 'Equipment';

  @override
  String get nav_home => 'Home';

  @override
  String get nav_more => 'More';

  @override
  String get nav_planning => 'Planning';

  @override
  String get nav_planningSubtitle => 'Dive Planner, Calculators';

  @override
  String get nav_settings => 'Settings';

  @override
  String get nav_sites => 'Sites';

  @override
  String get nav_statistics => 'Statistics';

  @override
  String get nav_tooltip_closeMenu => 'Close menu';

  @override
  String get nav_tooltip_collapseMenu => 'Collapse menu';

  @override
  String get nav_tooltip_expandMenu => 'Expand menu';

  @override
  String get nav_transfer => 'Transfer';

  @override
  String get nav_trips => 'Trips';

  @override
  String get onboarding_welcome_createProfile => 'Create Your Profile';

  @override
  String get onboarding_welcome_createProfileSubtitle =>
      'Enter your name to get started. You can add more details later.';

  @override
  String get onboarding_welcome_creating => 'Creating...';

  @override
  String onboarding_welcome_errorCreatingProfile(Object error) {
    return 'Error creating profile: $error';
  }

  @override
  String get onboarding_welcome_getStarted => 'Get Started';

  @override
  String get onboarding_welcome_nameHint => 'Enter your name';

  @override
  String get onboarding_welcome_nameLabel => 'Your Name';

  @override
  String get onboarding_welcome_nameValidation => 'Please enter your name';

  @override
  String get onboarding_welcome_subtitle =>
      'Advanced dive logging and analysis';

  @override
  String get onboarding_welcome_title => 'Welcome to Submersion';

  @override
  String get planning_appBar_title => 'Planning';

  @override
  String get planning_card_decoCalculator_description =>
      'Calculate no-decompression limits, required deco stops, and CNS/OTU exposure for multi-level dive profiles.';

  @override
  String get planning_card_decoCalculator_subtitle =>
      'Plan dives with decompression stops';

  @override
  String get planning_card_decoCalculator_title => 'Deco Calculator';

  @override
  String get planning_card_divePlanner_description =>
      'Plan complex dives with multiple depth levels, gas switches, and automatic decompression stop calculations.';

  @override
  String get planning_card_divePlanner_subtitle =>
      'Create multi-level dive plans';

  @override
  String get planning_card_divePlanner_title => 'Dive Planner';

  @override
  String get planning_card_gasCalculators_description =>
      'Four specialized gas calculators: • MOD - Maximum operating depth for a gas mix • Best Mix - Ideal O₂% for a target depth • Consumption - Gas usage estimation • Rock Bottom - Emergency reserve calculation';

  @override
  String get planning_card_gasCalculators_subtitle =>
      'MOD, Best Mix, Consumption, Rock Bottom';

  @override
  String get planning_card_gasCalculators_title => 'Gas Calculators';

  @override
  String get planning_card_surfaceInterval_description =>
      'Calculate the minimum surface interval needed between dives based on tissue loading. Visualize how your 16 tissue compartments off-gas over time.';

  @override
  String get planning_card_surfaceInterval_subtitle =>
      'Plan repetitive dive intervals';

  @override
  String get planning_card_surfaceInterval_title => 'Surface Interval';

  @override
  String get planning_card_weightCalculator_description =>
      'Estimate the weight you need based on your exposure suit, tank material, water type, and body weight.';

  @override
  String get planning_card_weightCalculator_subtitle =>
      'Recommended weight for your setup';

  @override
  String get planning_card_weightCalculator_title => 'Weight Calculator';

  @override
  String get planning_info_disclaimer =>
      'These tools are for planning purposes only. Always verify calculations and follow your dive training.';

  @override
  String get planning_sidebar_appBar_title => 'Planning';

  @override
  String get planning_sidebar_decoCalculator_subtitle => 'NDL & deco stops';

  @override
  String get planning_sidebar_decoCalculator_title => 'Deco Calculator';

  @override
  String get planning_sidebar_divePlanner_subtitle => 'Multi-level dive plans';

  @override
  String get planning_sidebar_divePlanner_title => 'Dive Planner';

  @override
  String get planning_sidebar_gasCalculators_subtitle => 'MOD, Best Mix, more';

  @override
  String get planning_sidebar_gasCalculators_title => 'Gas Calculators';

  @override
  String get planning_sidebar_info_disclaimer =>
      'Planning tools are for reference only. Always verify calculations.';

  @override
  String get planning_sidebar_surfaceInterval_subtitle =>
      'Repetitive dive planning';

  @override
  String get planning_sidebar_surfaceInterval_title => 'Surface Interval';

  @override
  String get planning_sidebar_weightCalculator_subtitle => 'Recommended weight';

  @override
  String get planning_sidebar_weightCalculator_title => 'Weight Calculator';

  @override
  String get planning_welcome_quickTips_title => 'Quick Tips';

  @override
  String get planning_welcome_subtitle =>
      'Select a tool from the sidebar to get started';

  @override
  String get planning_welcome_tip_decoCalculator =>
      'Deco Calculator for NDL and stop times';

  @override
  String get planning_welcome_tip_divePlanner =>
      'Dive Planner for multi-level dive planning';

  @override
  String get planning_welcome_tip_gasCalculators =>
      'Gas Calculators for MOD and gas planning';

  @override
  String get planning_welcome_tip_weightCalculator =>
      'Weight Calculator for buoyancy setup';

  @override
  String get planning_welcome_title => 'Planning Tools';

  @override
  String get settings_about_aboutSubmersion => 'About Submersion';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description =>
      'Track your dives, manage gear, and explore dive sites.';

  @override
  String get settings_about_header => 'About';

  @override
  String get settings_about_openSourceLicenses => 'Open Source Licenses';

  @override
  String get settings_about_reportIssue => 'Report an Issue';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Visit github.com/submersion/submersion';

  @override
  String settings_about_version(String version, String buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get settings_appBar_title => 'Settings';

  @override
  String get settings_appearance_appLanguage => 'App Language';

  @override
  String get settings_appearance_depthColoredCards =>
      'Depth-colored dive cards';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Show dive cards with ocean-colored backgrounds based on depth';

  @override
  String get settings_appearance_cardColorAttribute => 'Color cards by';

  @override
  String get settings_appearance_cardColorAttribute_subtitle =>
      'Choose which attribute determines card background color';

  @override
  String get settings_appearance_cardColorAttribute_none => 'None';

  @override
  String get settings_appearance_cardColorAttribute_depth => 'Depth';

  @override
  String get settings_appearance_cardColorAttribute_duration => 'Duration';

  @override
  String get settings_appearance_cardColorAttribute_temperature =>
      'Temperature';

  @override
  String get settings_appearance_colorGradient => 'Color gradient';

  @override
  String get settings_appearance_colorGradient_subtitle =>
      'Choose the color range for card backgrounds';

  @override
  String get settings_appearance_colorGradient_ocean => 'Ocean';

  @override
  String get settings_appearance_colorGradient_thermal => 'Thermal';

  @override
  String get settings_appearance_colorGradient_sunset => 'Sunset';

  @override
  String get settings_appearance_colorGradient_forest => 'Forest';

  @override
  String get settings_appearance_colorGradient_monochrome => 'Monochrome';

  @override
  String get settings_appearance_colorGradient_custom => 'Custom';

  @override
  String get settings_appearance_gasSwitchMarkers => 'Gas switch markers';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'Show markers for gas switches';

  @override
  String get settings_appearance_header_diveLog => 'Dive Log';

  @override
  String get settings_appearance_header_diveProfile => 'Dive Profile';

  @override
  String get settings_appearance_header_diveSites => 'Dive Sites';

  @override
  String get settings_appearance_header_language => 'Language';

  @override
  String get settings_appearance_header_theme => 'Theme';

  @override
  String get settings_appearance_mapBackgroundDiveCards =>
      'Map background on dive cards';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitle =>
      'Show dive site map as background on dive cards';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote =>
      'Show dive site map as background on dive cards (requires site location)';

  @override
  String get settings_appearance_mapBackgroundSiteCards =>
      'Map background on site cards';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitle =>
      'Show map as background on dive site cards';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote =>
      'Show map as background on dive site cards (requires site location)';

  @override
  String get settings_appearance_maxDepthMarker => 'Max depth marker';

  @override
  String get settings_appearance_maxDepthMarker_subtitle =>
      'Show a marker at the maximum depth point';

  @override
  String get settings_appearance_maxDepthMarker_subtitleFull =>
      'Show a marker at the maximum depth point on dive profiles';

  @override
  String get settings_appearance_metric_ascentRateColors =>
      'Ascent Rate Colors';

  @override
  String get settings_appearance_metric_ceiling => 'Ceiling';

  @override
  String get settings_appearance_metric_events => 'Events';

  @override
  String get settings_appearance_metric_gasDensity => 'Gas Density';

  @override
  String get settings_appearance_metric_gfPercent => 'GF%';

  @override
  String get settings_appearance_metric_heartRate => 'Heart Rate';

  @override
  String get settings_appearance_metric_meanDepth => 'Mean Depth';

  @override
  String get settings_appearance_metric_ndl => 'NDL';

  @override
  String get settings_appearance_metric_ppHe => 'ppHe';

  @override
  String get settings_appearance_metric_ppN2 => 'ppN2';

  @override
  String get settings_appearance_metric_ppO2 => 'ppO2';

  @override
  String get settings_appearance_metric_pressure => 'Pressure';

  @override
  String get settings_appearance_metric_sacRate => 'SAC Rate';

  @override
  String get settings_appearance_metric_surfaceGf => 'Surface GF';

  @override
  String get settings_appearance_metric_temperature => 'Temperature';

  @override
  String get settings_appearance_metric_tts => 'TTS (Time to Surface)';

  @override
  String get settings_appearance_pressureThresholdMarkers =>
      'Pressure threshold markers';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Show markers when tank pressure crosses thresholds';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Show markers when tank pressure crosses 2/3, 1/2, and 1/3 thresholds';

  @override
  String get settings_appearance_rightYAxisMetric => 'Right Y-axis metric';

  @override
  String get settings_appearance_rightYAxisMetric_subtitle =>
      'Default metric shown on right axis';

  @override
  String get settings_appearance_subsection_decompressionMetrics =>
      'Decompression Metrics';

  @override
  String get settings_appearance_subsection_defaultVisibleMetrics =>
      'Default Visible Metrics';

  @override
  String get settings_appearance_subsection_gasAnalysisMetrics =>
      'Gas Analysis Metrics';

  @override
  String get settings_appearance_subsection_gradientFactorMetrics =>
      'Gradient Factor Metrics';

  @override
  String get settings_appearance_theme_dark => 'Dark';

  @override
  String get settings_appearance_theme_light => 'Light';

  @override
  String get settings_appearance_theme_system => 'System default';

  @override
  String get settings_backToSettings_tooltip => 'Back to settings';

  @override
  String get settings_cloudSync_appBar_title => 'Cloud Sync';

  @override
  String get settings_cloudSync_autoSync => 'Auto Sync';

  @override
  String get settings_cloudSync_autoSync_subtitle =>
      'Sync automatically after changes';

  @override
  String settings_cloudSync_conflictItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items need attention',
      one: '1 item needs attention',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_disabledBanner_content =>
      'App-managed cloud sync is disabled because you\'re using a custom storage folder. Your folder\'s sync service (Dropbox, Google Drive, OneDrive, etc.) handles synchronization.';

  @override
  String get settings_cloudSync_disabledBanner_title => 'Cloud Sync Disabled';

  @override
  String get settings_cloudSync_header_advanced => 'Advanced';

  @override
  String get settings_cloudSync_header_cloudProvider => 'Cloud Provider';

  @override
  String settings_cloudSync_header_conflicts(Object count) {
    return 'Conflicts ($count)';
  }

  @override
  String get settings_cloudSync_header_syncBehavior => 'Sync Behavior';

  @override
  String settings_cloudSync_lastSynced(Object time) {
    return 'Last synced: $time';
  }

  @override
  String settings_cloudSync_pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending changes',
      one: '1 pending change',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_provider_connected => 'Connected';

  @override
  String settings_cloudSync_provider_connectedTo(Object providerName) {
    return 'Connected to $providerName';
  }

  @override
  String settings_cloudSync_provider_connectionFailed(
    Object providerName,
    Object error,
  ) {
    return '$providerName connection failed: $error';
  }

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Sync via Google Drive';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Sync via Apple iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Failed to initialize $providerName provider';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Not available on this platform';

  @override
  String get settings_cloudSync_resetDialog_cancel => 'Cancel';

  @override
  String get settings_cloudSync_resetDialog_content =>
      'This will clear all sync history and start fresh. Your data will not be deleted, but you may need to resolve conflicts on the next sync.';

  @override
  String get settings_cloudSync_resetDialog_reset => 'Reset';

  @override
  String get settings_cloudSync_resetDialog_title => 'Reset Sync State?';

  @override
  String get settings_cloudSync_resetSuccess => 'Sync state reset';

  @override
  String get settings_cloudSync_resetSyncState => 'Reset Sync State';

  @override
  String get settings_cloudSync_resetSyncState_subtitle =>
      'Clear sync history and start fresh';

  @override
  String get settings_cloudSync_resolveConflicts => 'Resolve Conflicts';

  @override
  String get settings_cloudSync_selectProviderHint =>
      'Select a cloud provider to enable sync';

  @override
  String get settings_cloudSync_signOut => 'Sign Out';

  @override
  String get settings_cloudSync_signOutDialog_cancel => 'Cancel';

  @override
  String get settings_cloudSync_signOutDialog_content =>
      'This will disconnect from the cloud provider. Your local data will remain intact.';

  @override
  String get settings_cloudSync_signOutDialog_signOut => 'Sign Out';

  @override
  String get settings_cloudSync_signOutDialog_title => 'Sign Out?';

  @override
  String get settings_cloudSync_signOutSuccess =>
      'Signed out from cloud provider';

  @override
  String get settings_cloudSync_signOut_subtitle =>
      'Disconnect from cloud provider';

  @override
  String get settings_cloudSync_status_conflictsDetected =>
      'Conflicts detected';

  @override
  String get settings_cloudSync_status_readyToSync => 'Ready to sync';

  @override
  String get settings_cloudSync_status_syncComplete => 'Sync complete';

  @override
  String get settings_cloudSync_status_syncError => 'Sync error';

  @override
  String get settings_cloudSync_status_syncing => 'Syncing...';

  @override
  String get settings_cloudSync_storageSettings => 'Storage Settings';

  @override
  String get settings_cloudSync_syncNow => 'Sync Now';

  @override
  String get settings_cloudSync_syncOnLaunch => 'Sync on Launch';

  @override
  String get settings_cloudSync_syncOnLaunch_subtitle =>
      'Check for updates at startup';

  @override
  String get settings_cloudSync_syncOnResume => 'Sync on Resume';

  @override
  String get settings_cloudSync_syncOnResume_subtitle =>
      'Check for updates when app becomes active';

  @override
  String settings_cloudSync_syncProgressPercent(Object percent) {
    return 'Sync progress: $percent percent';
  }

  @override
  String settings_cloudSync_time_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_time_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_time_justNow => 'Just now';

  @override
  String settings_cloudSync_time_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_applyAll => 'Apply All';

  @override
  String get settings_conflict_cancel => 'Cancel';

  @override
  String get settings_conflict_chooseResolution => 'Choose Resolution';

  @override
  String get settings_conflict_close => 'Close';

  @override
  String get settings_conflict_close_tooltip => 'Close conflict dialog';

  @override
  String settings_conflict_counterLabel(Object current, Object total) {
    return 'Conflict $current of $total';
  }

  @override
  String settings_conflict_errorLoading(Object error) {
    return 'Error loading conflicts: $error';
  }

  @override
  String get settings_conflict_keepBoth => 'Keep Both';

  @override
  String get settings_conflict_keepLocal => 'Keep Local';

  @override
  String get settings_conflict_keepRemote => 'Keep Remote';

  @override
  String get settings_conflict_localVersion => 'Local Version';

  @override
  String settings_conflict_modified(Object time) {
    return 'Modified: $time';
  }

  @override
  String get settings_conflict_next_tooltip => 'Next conflict';

  @override
  String get settings_conflict_noConflicts_message =>
      'All sync conflicts have been resolved.';

  @override
  String get settings_conflict_noConflicts_title => 'No Conflicts';

  @override
  String get settings_conflict_noDataAvailable => 'No data available';

  @override
  String get settings_conflict_previous_tooltip => 'Previous conflict';

  @override
  String get settings_conflict_remoteVersion => 'Remote Version';

  @override
  String settings_conflict_resolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conflicts',
      one: '1 conflict',
    );
    return 'Resolved $_temp0';
  }

  @override
  String get settings_conflict_title => 'Resolve Conflicts';

  @override
  String get settings_data_appDefaultLocation => 'App default location';

  @override
  String get settings_data_backup => 'Backup';

  @override
  String get settings_data_backup_subtitle => 'Create a backup of your data';

  @override
  String get settings_data_cloudSync => 'Cloud Sync';

  @override
  String get settings_data_customFolder => 'Custom folder';

  @override
  String get settings_data_databaseStorage => 'Database Storage';

  @override
  String get settings_data_export_completed => 'Export completed';

  @override
  String get settings_data_export_exporting => 'Exporting...';

  @override
  String settings_data_export_failed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get settings_data_header_backupSync => 'Backup & Sync';

  @override
  String get settings_data_header_storage => 'Storage';

  @override
  String get settings_data_import_completed => 'Operation completed';

  @override
  String settings_data_import_failed(Object error) {
    return 'Operation failed: $error';
  }

  @override
  String get settings_data_offlineMaps => 'Offline Maps';

  @override
  String get settings_data_offlineMaps_subtitle =>
      'Download maps for offline use';

  @override
  String get settings_data_restore => 'Restore';

  @override
  String get settings_data_restoreDialog_cancel => 'Cancel';

  @override
  String get settings_data_restoreDialog_content =>
      'Warning: Restoring from a backup will replace ALL current data with the backup data. This action cannot be undone.  Are you sure you want to continue?';

  @override
  String get settings_data_restoreDialog_restore => 'Restore';

  @override
  String get settings_data_restoreDialog_title => 'Restore Backup';

  @override
  String get settings_data_restore_subtitle => 'Restore from backup';

  @override
  String settings_data_syncTime_daysAgo(Object count) {
    return '${count}d ago';
  }

  @override
  String settings_data_syncTime_hoursAgo(Object count) {
    return '${count}h ago';
  }

  @override
  String get settings_data_syncTime_justNow => 'Just now';

  @override
  String settings_data_syncTime_minutesAgo(Object count) {
    return '${count}m ago';
  }

  @override
  String settings_data_sync_lastSynced(Object time) {
    return 'Last synced: $time';
  }

  @override
  String get settings_data_sync_notConfigured => 'Not configured';

  @override
  String get settings_data_sync_syncing => 'Syncing...';

  @override
  String get settings_decompression_aboutContent =>
      'Gradient Factors (GF) control how conservative your decompression calculations are. GF Low affects deep stops, while GF High affects shallow stops.  Lower values = more conservative = longer deco stops Higher values = less conservative = shorter deco stops';

  @override
  String get settings_decompression_aboutTitle => 'About Gradient Factors';

  @override
  String get settings_decompression_currentSettings => 'Current Settings';

  @override
  String get settings_decompression_dialog_cancel => 'Cancel';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      'Lower values = more conservative (longer NDL/more deco)';

  @override
  String get settings_decompression_dialog_customValues => 'Custom Values';

  @override
  String get settings_decompression_dialog_gfHigh => 'GF High';

  @override
  String get settings_decompression_dialog_gfLow => 'GF Low';

  @override
  String get settings_decompression_dialog_info =>
      'GF Low/High control how conservative your NDL and deco calculations are.';

  @override
  String get settings_decompression_dialog_presets => 'Presets';

  @override
  String get settings_decompression_dialog_save => 'Save';

  @override
  String get settings_decompression_dialog_title => 'Gradient Factors';

  @override
  String settings_decompression_gfValue(Object gfLow, Object gfHigh) {
    return 'GF $gfLow/$gfHigh';
  }

  @override
  String get settings_decompression_header_gradientFactors =>
      'Gradient Factors';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Select $presetName conservatism preset';
  }

  @override
  String get settings_existingDb_cancel => 'Cancel';

  @override
  String get settings_existingDb_continue => 'Continue';

  @override
  String get settings_existingDb_current => 'Current';

  @override
  String get settings_existingDb_dialog_message =>
      'A Submersion database already exists in this folder.';

  @override
  String get settings_existingDb_dialog_title => 'Existing Database Found';

  @override
  String get settings_existingDb_existing => 'Existing';

  @override
  String get settings_existingDb_replaceWarning =>
      'The existing database will be backed up before being replaced.';

  @override
  String get settings_existingDb_replaceWithMyData => 'Replace with my data';

  @override
  String get settings_existingDb_replaceWithMyData_subtitle =>
      'Overwrite with your current database';

  @override
  String get settings_existingDb_stat_buddies => 'Buddies';

  @override
  String get settings_existingDb_stat_dives => 'Dives';

  @override
  String get settings_existingDb_stat_sites => 'Sites';

  @override
  String get settings_existingDb_stat_trips => 'Trips';

  @override
  String get settings_existingDb_stat_users => 'Users';

  @override
  String get settings_existingDb_unknown => 'Unknown';

  @override
  String get settings_existingDb_useExisting => 'Use existing database';

  @override
  String get settings_existingDb_useExisting_subtitle =>
      'Switch to the database in this folder';

  @override
  String get settings_gfPreset_custom_description => 'Set your own values';

  @override
  String get settings_gfPreset_custom_name => 'Custom';

  @override
  String get settings_gfPreset_high_description =>
      'Most conservative, longer deco stops';

  @override
  String get settings_gfPreset_high_name => 'High';

  @override
  String get settings_gfPreset_low_description =>
      'Least conservative, shorter deco';

  @override
  String get settings_gfPreset_low_name => 'Low';

  @override
  String get settings_gfPreset_medium_description => 'Balanced approach';

  @override
  String get settings_gfPreset_medium_name => 'Medium';

  @override
  String get settings_import_dialog_title => 'Importing Data';

  @override
  String get settings_import_doNotClose => 'Please do not close the app';

  @override
  String settings_import_itemCount(Object current, Object total) {
    return '$current of $total';
  }

  @override
  String get settings_import_phase_buddies => 'Importing buddies...';

  @override
  String get settings_import_phase_certifications =>
      'Importing certifications...';

  @override
  String get settings_import_phase_complete => 'Finalizing...';

  @override
  String get settings_import_phase_diveCenters => 'Importing dive centers...';

  @override
  String get settings_import_phase_diveTypes => 'Importing dive types...';

  @override
  String get settings_import_phase_dives => 'Importing dives...';

  @override
  String get settings_import_phase_equipment => 'Importing equipment...';

  @override
  String get settings_import_phase_equipmentSets =>
      'Importing equipment sets...';

  @override
  String get settings_import_phase_parsing => 'Parsing file...';

  @override
  String get settings_import_phase_preparing => 'Preparing...';

  @override
  String get settings_import_phase_sites => 'Importing dive sites...';

  @override
  String get settings_import_phase_tags => 'Importing tags...';

  @override
  String get settings_import_phase_trips => 'Importing trips...';

  @override
  String settings_import_progressLabel(
    Object phase,
    Object current,
    Object total,
  ) {
    return '$phase, $current of $total';
  }

  @override
  String settings_import_progressPercent(Object percent) {
    return 'Import progress: $percent percent';
  }

  @override
  String get settings_language_appBar_title => 'Language';

  @override
  String get settings_language_selected => 'Selected';

  @override
  String get settings_language_systemDefault => 'System Default';

  @override
  String get settings_manage_diveTypes => 'Dive Types';

  @override
  String get settings_manage_diveTypes_subtitle => 'Manage custom dive types';

  @override
  String get settings_manage_header_manageData => 'Manage Data';

  @override
  String get settings_manage_species => 'Species';

  @override
  String get settings_manage_species_subtitle =>
      'Manage marine life species catalog';

  @override
  String get settings_manage_tankPresets => 'Tank Presets';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Manage custom tank configurations';

  @override
  String get settings_migrationProgress_doNotClose =>
      'Please do not close the app';

  @override
  String get settings_migration_backupInfo =>
      'A backup will be created before the move. Your data will not be lost.';

  @override
  String get settings_migration_cancel => 'Cancel';

  @override
  String get settings_migration_cloudSyncWarning =>
      'App-managed cloud sync will be disabled. Your folder\'s sync service will handle synchronization.';

  @override
  String get settings_migration_dialog_message =>
      'Your database will be moved:';

  @override
  String get settings_migration_dialog_title => 'Move Database?';

  @override
  String get settings_migration_from => 'From';

  @override
  String get settings_migration_moveDatabase => 'Move Database';

  @override
  String get settings_migration_to => 'To';

  @override
  String settings_notifications_days(Object count) {
    return '$count days';
  }

  @override
  String get settings_notifications_disabled_enableButton => 'Enable';

  @override
  String get settings_notifications_disabled_subtitle =>
      'Enable in system settings to receive reminders';

  @override
  String get settings_notifications_disabled_title => 'Notifications Disabled';

  @override
  String get settings_notifications_enableServiceReminders =>
      'Enable Service Reminders';

  @override
  String get settings_notifications_enableServiceReminders_subtitle =>
      'Get notified when equipment service is due';

  @override
  String get settings_notifications_header_reminderSchedule =>
      'Reminder Schedule';

  @override
  String get settings_notifications_header_serviceReminders =>
      'Service Reminders';

  @override
  String get settings_notifications_howItWorks_content =>
      'Notifications are scheduled when the app launches and refresh periodically in the background. You can customize reminders for individual equipment items in their edit screen.';

  @override
  String get settings_notifications_howItWorks_title => 'How it works';

  @override
  String get settings_notifications_permissionRequired =>
      'Please enable notifications in system settings';

  @override
  String get settings_notifications_remindBeforeDue =>
      'Remind me before service is due:';

  @override
  String get settings_notifications_reminderTime => 'Reminder Time';

  @override
  String get settings_profile_activeDiver_subtitle =>
      'Active diver - tap to switch';

  @override
  String get settings_profile_addNewDiver => 'Add New Diver';

  @override
  String get settings_profile_error_loadingDiver => 'Error loading diver';

  @override
  String get settings_profile_header_activeDiver => 'Active Diver';

  @override
  String get settings_profile_header_manageDivers => 'Manage Divers';

  @override
  String get settings_profile_noDiverProfile => 'No diver profile';

  @override
  String get settings_profile_noDiverProfile_subtitle =>
      'Tap to create your profile';

  @override
  String get settings_profile_switchDiver_title => 'Switch Diver';

  @override
  String settings_profile_switchedTo(Object diverName) {
    return 'Switched to $diverName';
  }

  @override
  String get settings_profile_viewAllDivers => 'View All Divers';

  @override
  String get settings_profile_viewAllDivers_subtitle =>
      'Add or edit diver profiles';

  @override
  String get settings_section_about_subtitle => 'App info & licenses';

  @override
  String get settings_section_about_title => 'About';

  @override
  String get settings_section_appearance_subtitle => 'Theme & display';

  @override
  String get settings_section_appearance_title => 'Appearance';

  @override
  String get settings_section_data_subtitle => 'Backup, restore & storage';

  @override
  String get settings_section_data_title => 'Data';

  @override
  String get settings_section_decompression_subtitle => 'Gradient factors';

  @override
  String get settings_section_decompression_title => 'Decompression';

  @override
  String get settings_section_diverProfile_subtitle =>
      'Active diver & profiles';

  @override
  String get settings_section_diverProfile_title => 'Diver Profile';

  @override
  String get settings_section_manage_subtitle => 'Dive types & tank presets';

  @override
  String get settings_section_manage_title => 'Manage';

  @override
  String get settings_section_notifications_subtitle => 'Service reminders';

  @override
  String get settings_section_notifications_title => 'Notifications';

  @override
  String get settings_section_units_subtitle => 'Measurement preferences';

  @override
  String get settings_section_units_title => 'Units';

  @override
  String get settings_storage_appBar_title => 'Database Storage';

  @override
  String get settings_storage_appDefault => 'App Default';

  @override
  String get settings_storage_appDefaultLocation => 'App default location';

  @override
  String get settings_storage_appDefault_subtitle =>
      'Standard app storage location';

  @override
  String get settings_storage_currentLocation => 'Current Location';

  @override
  String get settings_storage_currentLocation_label => 'Current location';

  @override
  String get settings_storage_customFolder => 'Custom Folder';

  @override
  String get settings_storage_customFolder_change => 'Change';

  @override
  String get settings_storage_customFolder_subtitle =>
      'Choose a synced folder (Dropbox, Google Drive, etc.)';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize • $diveCount dives • $siteCount sites';
  }

  @override
  String get settings_storage_dismissError_tooltip => 'Dismiss error';

  @override
  String get settings_storage_dismissSuccess_tooltip =>
      'Dismiss success message';

  @override
  String get settings_storage_header_storageLocation => 'Storage Location';

  @override
  String get settings_storage_info_customActive =>
      'App-managed cloud sync is disabled. Your folder\'s sync service (Dropbox, Google Drive, etc.) handles synchronization.';

  @override
  String get settings_storage_info_customAvailable =>
      'Using a custom folder disables app-managed cloud sync. Your folder\'s sync service will handle synchronization instead.';

  @override
  String get settings_storage_loading => 'Loading...';

  @override
  String get settings_storage_migrating_doNotClose =>
      'Please do not close the app';

  @override
  String get settings_storage_migrating_movingDatabase => 'Moving database...';

  @override
  String get settings_storage_migrating_movingToAppDefault =>
      'Moving to app default...';

  @override
  String get settings_storage_migrating_replacingExisting =>
      'Replacing existing database...';

  @override
  String get settings_storage_migrating_switchingToExisting =>
      'Switching to existing database...';

  @override
  String get settings_storage_notSet => 'Not set';

  @override
  String settings_storage_success_backupAt(Object path) {
    return 'Original kept as backup at: $path';
  }

  @override
  String get settings_storage_success_moved => 'Database moved successfully';

  @override
  String get settings_summary_activeDiver => 'Active Diver';

  @override
  String get settings_summary_currentConfiguration => 'Current Configuration';

  @override
  String get settings_summary_depth => 'Depth';

  @override
  String get settings_summary_error => 'Error';

  @override
  String get settings_summary_gradientFactors => 'Gradient Factors';

  @override
  String get settings_summary_loading => 'Loading...';

  @override
  String get settings_summary_notSet => 'Not set';

  @override
  String get settings_summary_pressure => 'Pressure';

  @override
  String get settings_summary_subtitle => 'Select a category to configure';

  @override
  String get settings_summary_temperature => 'Temperature';

  @override
  String get settings_summary_theme => 'Theme';

  @override
  String get settings_summary_theme_dark => 'Dark';

  @override
  String get settings_summary_theme_light => 'Light';

  @override
  String get settings_summary_theme_system => 'System';

  @override
  String get settings_summary_tip =>
      'Tip: Use the Data section to backup your dive logs regularly.';

  @override
  String get settings_summary_title => 'Settings';

  @override
  String get settings_summary_unitPreferences => 'Unit Preferences';

  @override
  String get settings_summary_units => 'Units';

  @override
  String get settings_summary_volume => 'Volume';

  @override
  String get settings_summary_weight => 'Weight';

  @override
  String get settings_units_custom => 'Custom';

  @override
  String get settings_units_dateFormat => 'Date Format';

  @override
  String get settings_units_depth => 'Depth';

  @override
  String get settings_units_depth_feet => 'Feet (ft)';

  @override
  String get settings_units_depth_meters => 'Meters (m)';

  @override
  String get settings_units_dialog_dateFormat => 'Date Format';

  @override
  String get settings_units_dialog_depthUnit => 'Depth Unit';

  @override
  String get settings_units_dialog_pressureUnit => 'Pressure Unit';

  @override
  String get settings_units_dialog_sacRateUnit => 'SAC Rate Unit';

  @override
  String get settings_units_dialog_temperatureUnit => 'Temperature Unit';

  @override
  String get settings_units_dialog_timeFormat => 'Time Format';

  @override
  String get settings_units_dialog_volumeUnit => 'Volume Unit';

  @override
  String get settings_units_dialog_weightUnit => 'Weight Unit';

  @override
  String get settings_units_header_individualUnits => 'Individual Units';

  @override
  String get settings_units_header_timeDateFormat => 'Time & Date Format';

  @override
  String get settings_units_header_unitSystem => 'Unit System';

  @override
  String get settings_units_imperial => 'Imperial';

  @override
  String get settings_units_metric => 'Metric';

  @override
  String get settings_units_pressure => 'Pressure';

  @override
  String get settings_units_pressure_bar => 'Bar';

  @override
  String get settings_units_pressure_psi => 'PSI';

  @override
  String get settings_units_quickSelect => 'Quick Select';

  @override
  String get settings_units_sacRate => 'SAC Rate';

  @override
  String get settings_units_sac_pressurePerMinute => 'Pressure per minute';

  @override
  String get settings_units_sac_pressurePerMinute_subtitle =>
      'No tank volume needed (bar/min or psi/min)';

  @override
  String get settings_units_sac_volumePerMinute => 'Volume per minute';

  @override
  String get settings_units_sac_volumePerMinute_subtitle =>
      'Requires tank volume (L/min or cuft/min)';

  @override
  String get settings_units_temperature => 'Temperature';

  @override
  String get settings_units_temperature_celsius => 'Celsius (°C)';

  @override
  String get settings_units_temperature_fahrenheit => 'Fahrenheit (°F)';

  @override
  String get settings_units_timeFormat => 'Time Format';

  @override
  String get settings_units_volume => 'Volume';

  @override
  String get settings_units_volume_cubicFeet => 'Cubic Feet (cuft)';

  @override
  String get settings_units_volume_liters => 'Liters (L)';

  @override
  String get settings_units_weight => 'Weight';

  @override
  String get settings_units_weight_kilograms => 'Kilograms (kg)';

  @override
  String get settings_units_weight_pounds => 'Pounds (lbs)';

  @override
  String get signatures_action_clear => 'Clear';

  @override
  String get signatures_action_closeSignatureView => 'Close signature view';

  @override
  String get signatures_action_deleteSignature => 'Delete signature';

  @override
  String get signatures_action_done => 'Done';

  @override
  String get signatures_action_readyToSign => 'Ready to Sign';

  @override
  String get signatures_action_request => 'Request';

  @override
  String get signatures_action_saveSignature => 'Save Signature';

  @override
  String signatures_buddyCard_notSignedSemantics(Object name) {
    return '$name signature, not signed';
  }

  @override
  String signatures_buddyCard_signedSemantics(Object name) {
    return '$name signature, signed';
  }

  @override
  String get signatures_captureInstructorSignature =>
      'Capture Instructor Signature';

  @override
  String signatures_deleteDialog_message(Object name) {
    return 'Are you sure you want to delete the signature from $name? This cannot be undone.';
  }

  @override
  String get signatures_deleteDialog_title => 'Delete Signature?';

  @override
  String get signatures_drawSignatureHint => 'Draw your signature above';

  @override
  String get signatures_drawSignatureHintDetailed =>
      'Draw signature above using finger or stylus';

  @override
  String get signatures_drawSignatureSemantics => 'Draw signature';

  @override
  String get signatures_error_drawSignature => 'Please draw a signature';

  @override
  String get signatures_error_enterSignerName => 'Please enter the signer name';

  @override
  String get signatures_field_instructorName => 'Instructor Name';

  @override
  String get signatures_field_instructorNameHint => 'Enter instructor name';

  @override
  String get signatures_handoff_title => 'Hand your device to';

  @override
  String get signatures_instructorSignature => 'Instructor Signature';

  @override
  String get signatures_noSignatureImage => 'No signature image';

  @override
  String signatures_signHere(Object name) {
    return '$name - Sign Here';
  }

  @override
  String get signatures_signed => 'Signed';

  @override
  String signatures_signedCountSemantics(Object signed, Object total) {
    return '$signed of $total buddies have signed';
  }

  @override
  String signatures_signedDate(Object date) {
    return 'Signed $date';
  }

  @override
  String get signatures_title => 'Signatures';

  @override
  String get signatures_viewSignature => 'View signature';

  @override
  String signatures_viewSignatureSemantics(Object name) {
    return 'View signature from $name';
  }

  @override
  String get statistics_appBar_title => 'Statistics';

  @override
  String statistics_categoryCard_semanticLabel(Object title) {
    return '$title statistics category';
  }

  @override
  String get statistics_category_conditions_subtitle =>
      'Visibility & temperature';

  @override
  String get statistics_category_conditions_title => 'Conditions';

  @override
  String get statistics_category_equipment_subtitle => 'Gear usage & weight';

  @override
  String get statistics_category_equipment_title => 'Equipment';

  @override
  String get statistics_category_gas_subtitle => 'SAC rates & gas mixes';

  @override
  String get statistics_category_gas_title => 'Air Consumption';

  @override
  String get statistics_category_geographic_subtitle => 'Countries & regions';

  @override
  String get statistics_category_geographic_title => 'Geographic';

  @override
  String get statistics_category_marineLife_subtitle => 'Species sightings';

  @override
  String get statistics_category_marineLife_title => 'Marine Life';

  @override
  String get statistics_category_profile_subtitle => 'Ascent rates & deco';

  @override
  String get statistics_category_profile_title => 'Profile Analysis';

  @override
  String get statistics_category_progression_subtitle => 'Depth & time trends';

  @override
  String get statistics_category_progression_title => 'Progression';

  @override
  String get statistics_category_social_subtitle => 'Buddies & dive centers';

  @override
  String get statistics_category_social_title => 'Social';

  @override
  String get statistics_category_timePatterns_subtitle => 'When you dive';

  @override
  String get statistics_category_timePatterns_title => 'Time Patterns';

  @override
  String statistics_chart_barSemanticLabel(Object count) {
    return 'Bar chart with $count categories';
  }

  @override
  String statistics_chart_distributionSemanticLabel(Object count) {
    return 'Distribution pie chart with $count segments';
  }

  @override
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames) {
    return 'Multi-trend line chart comparing $seriesNames';
  }

  @override
  String get statistics_chart_noBarData => 'No data available';

  @override
  String get statistics_chart_noDistributionData =>
      'No distribution data available';

  @override
  String get statistics_chart_noTrendData => 'No trend data available';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return 'Trend line chart showing $count data points';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return 'Trend line chart showing $count data points for $yAxisLabel';
  }

  @override
  String get statistics_conditions_appBar_title => 'Conditions';

  @override
  String get statistics_conditions_entryMethod_empty =>
      'No entry method data available';

  @override
  String get statistics_conditions_entryMethod_error =>
      'Failed to load entry method data';

  @override
  String get statistics_conditions_entryMethod_subtitle => 'Shore, boat, etc.';

  @override
  String get statistics_conditions_entryMethod_title => 'Entry Method';

  @override
  String get statistics_conditions_temperature_empty =>
      'No temperature data available';

  @override
  String get statistics_conditions_temperature_error =>
      'Failed to load temperature data';

  @override
  String get statistics_conditions_temperature_seriesAvg => 'Avg';

  @override
  String get statistics_conditions_temperature_seriesMax => 'Max';

  @override
  String get statistics_conditions_temperature_seriesMin => 'Min';

  @override
  String get statistics_conditions_temperature_subtitle =>
      'Min/Avg/Max temperatures';

  @override
  String get statistics_conditions_temperature_title =>
      'Water Temperature by Month';

  @override
  String get statistics_conditions_visibility_error =>
      'Failed to load visibility data';

  @override
  String get statistics_conditions_visibility_subtitle =>
      'Dives by visibility condition';

  @override
  String get statistics_conditions_visibility_title =>
      'Visibility Distribution';

  @override
  String get statistics_conditions_waterType_error =>
      'Failed to load water type data';

  @override
  String get statistics_conditions_waterType_subtitle =>
      'Salt vs Fresh water dives';

  @override
  String get statistics_conditions_waterType_title => 'Water Type';

  @override
  String get statistics_equipment_appBar_title => 'Equipment';

  @override
  String get statistics_equipment_mostUsedGear_error =>
      'Failed to load gear data';

  @override
  String get statistics_equipment_mostUsedGear_subtitle =>
      'Equipment by dive count';

  @override
  String get statistics_equipment_mostUsedGear_title => 'Most Used Gear';

  @override
  String get statistics_equipment_weightTrend_error =>
      'Failed to load weight trend';

  @override
  String get statistics_equipment_weightTrend_subtitle =>
      'Average weight over time';

  @override
  String get statistics_equipment_weightTrend_title => 'Weight Trend';

  @override
  String get statistics_error_loadingStatistics => 'Error loading statistics';

  @override
  String get statistics_gas_appBar_title => 'Air Consumption';

  @override
  String get statistics_gas_gasMix_error => 'Failed to load gas mix data';

  @override
  String get statistics_gas_gasMix_subtitle => 'Dives by gas type';

  @override
  String get statistics_gas_gasMix_title => 'Gas Mix Distribution';

  @override
  String get statistics_gas_sacByRole_empty => 'No multi-tank data available';

  @override
  String get statistics_gas_sacByRole_error => 'Failed to load SAC by role';

  @override
  String get statistics_gas_sacByRole_subtitle =>
      'Average consumption by tank type';

  @override
  String get statistics_gas_sacByRole_title => 'SAC by Tank Role';

  @override
  String get statistics_gas_sacRecords_best => 'Best SAC Rate';

  @override
  String get statistics_gas_sacRecords_empty => 'No SAC data available yet';

  @override
  String get statistics_gas_sacRecords_error => 'Failed to load SAC records';

  @override
  String get statistics_gas_sacRecords_highest => 'Highest SAC Rate';

  @override
  String get statistics_gas_sacRecords_subtitle =>
      'Best and worst air consumption';

  @override
  String get statistics_gas_sacRecords_title => 'SAC Rate Records';

  @override
  String get statistics_gas_sacTrend_error => 'Failed to load SAC trend';

  @override
  String get statistics_gas_sacTrend_subtitle => 'Monthly average over 5 years';

  @override
  String get statistics_gas_sacTrend_title => 'SAC Rate Trend';

  @override
  String get statistics_gas_tankRole_backGas => 'Back Gas';

  @override
  String get statistics_gas_tankRole_bailout => 'Bailout';

  @override
  String get statistics_gas_tankRole_deco => 'Deco';

  @override
  String get statistics_gas_tankRole_diluent => 'Diluent';

  @override
  String get statistics_gas_tankRole_oxygenSupply => 'O₂ Supply';

  @override
  String get statistics_gas_tankRole_pony => 'Pony';

  @override
  String get statistics_gas_tankRole_sidemountLeft => 'Sidemount L';

  @override
  String get statistics_gas_tankRole_sidemountRight => 'Sidemount R';

  @override
  String get statistics_gas_tankRole_stage => 'Stage';

  @override
  String get statistics_geographic_appBar_title => 'Geographic';

  @override
  String get statistics_geographic_countries_empty => 'No countries visited';

  @override
  String get statistics_geographic_countries_error =>
      'Failed to load country data';

  @override
  String get statistics_geographic_countries_subtitle => 'Dives by country';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count countries. Top: $topName with $topCount dives';
  }

  @override
  String get statistics_geographic_countries_title => 'Countries Visited';

  @override
  String get statistics_geographic_regions_empty => 'No regions explored';

  @override
  String get statistics_geographic_regions_error =>
      'Failed to load region data';

  @override
  String get statistics_geographic_regions_subtitle => 'Dives by region';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count regions. Top: $topName with $topCount dives';
  }

  @override
  String get statistics_geographic_regions_title => 'Regions Explored';

  @override
  String get statistics_geographic_trips_empty => 'No trip data';

  @override
  String get statistics_geographic_trips_error => 'Failed to load trip data';

  @override
  String get statistics_geographic_trips_subtitle => 'Most productive trips';

  @override
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count trips. Top: $topName with $topCount dives';
  }

  @override
  String get statistics_geographic_trips_title => 'Dives Per Trip';

  @override
  String get statistics_listContent_selectedSuffix => ', selected';

  @override
  String get statistics_marineLife_appBar_title => 'Marine Life';

  @override
  String get statistics_marineLife_bestSites_empty => 'No site data';

  @override
  String get statistics_marineLife_bestSites_error =>
      'Failed to load site data';

  @override
  String get statistics_marineLife_bestSites_subtitle =>
      'Sites with most species variety';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count sites. Best: $topName with $topCount species';
  }

  @override
  String get statistics_marineLife_bestSites_title =>
      'Best Sites for Marine Life';

  @override
  String get statistics_marineLife_mostCommon_empty => 'No sighting data';

  @override
  String get statistics_marineLife_mostCommon_error =>
      'Failed to load sighting data';

  @override
  String get statistics_marineLife_mostCommon_subtitle =>
      'Species spotted most often';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count species. Most common: $topName with $topCount sightings';
  }

  @override
  String get statistics_marineLife_mostCommon_title => 'Most Common Sightings';

  @override
  String get statistics_marineLife_speciesSpotted => 'Species Spotted';

  @override
  String get statistics_profile_appBar_title => 'Profile Analysis';

  @override
  String get statistics_profile_ascentDescent_empty =>
      'No profile data available';

  @override
  String get statistics_profile_ascentDescent_error =>
      'Failed to load rate data';

  @override
  String get statistics_profile_ascentDescent_subtitle =>
      'From dive profile data';

  @override
  String get statistics_profile_ascentDescent_title =>
      'Average Ascent & Descent Rates';

  @override
  String get statistics_profile_avgAscent => 'Avg Ascent';

  @override
  String get statistics_profile_avgDescent => 'Avg Descent';

  @override
  String get statistics_profile_deco_decoDives => 'Deco Dives';

  @override
  String get statistics_profile_deco_decoLabel => 'Deco';

  @override
  String get statistics_profile_deco_decoRate => 'Deco Rate';

  @override
  String get statistics_profile_deco_empty => 'No deco data available';

  @override
  String get statistics_profile_deco_error => 'Failed to load deco data';

  @override
  String get statistics_profile_deco_noDeco => 'No Deco';

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return 'Decompression rate: $percentage% of dives required deco stops';
  }

  @override
  String get statistics_profile_deco_subtitle =>
      'Dives that incurred deco stops';

  @override
  String get statistics_profile_deco_title => 'Decompression Obligation';

  @override
  String get statistics_profile_timeAtDepth_empty => 'No depth data available';

  @override
  String get statistics_profile_timeAtDepth_error =>
      'Failed to load depth range data';

  @override
  String get statistics_profile_timeAtDepth_subtitle =>
      'Approximate time spent at each depth';

  @override
  String get statistics_profile_timeAtDepth_title => 'Time at Depth Ranges';

  @override
  String statistics_profile_timeAtDepth_valueFormat(Object value) {
    return '$value min';
  }

  @override
  String get statistics_progression_appBar_title => 'Dive Progression';

  @override
  String get statistics_progression_bottomTime_error =>
      'Failed to load bottom time trend';

  @override
  String get statistics_progression_bottomTime_subtitle =>
      'Average duration by month';

  @override
  String get statistics_progression_bottomTime_title => 'Bottom Time Trend';

  @override
  String get statistics_progression_cumulative_error =>
      'Failed to load cumulative data';

  @override
  String get statistics_progression_cumulative_subtitle =>
      'Total dives over time';

  @override
  String get statistics_progression_cumulative_title => 'Cumulative Dive Count';

  @override
  String get statistics_progression_depthProgression_error =>
      'Failed to load depth progression';

  @override
  String get statistics_progression_depthProgression_subtitle =>
      'Monthly max depth over 5 years';

  @override
  String get statistics_progression_depthProgression_title =>
      'Maximum Depth Progression';

  @override
  String get statistics_progression_divesPerYear_empty =>
      'No yearly data available';

  @override
  String get statistics_progression_divesPerYear_error =>
      'Failed to load yearly data';

  @override
  String get statistics_progression_divesPerYear_subtitle =>
      'Annual dive count comparison';

  @override
  String get statistics_progression_divesPerYear_title => 'Dives Per Year';

  @override
  String get statistics_ranking_countLabel_dives => 'dives';

  @override
  String get statistics_ranking_countLabel_sightings => 'sightings';

  @override
  String get statistics_ranking_countLabel_species => 'species';

  @override
  String get statistics_ranking_emptyState => 'No data yet';

  @override
  String statistics_ranking_itemCount(Object count, Object label) {
    return '$count $label';
  }

  @override
  String statistics_ranking_moreItems(Object count) {
    return 'and $count more';
  }

  @override
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  ) {
    return '$name, rank $rank, $count $label';
  }

  @override
  String get statistics_records_appBar_title => 'Dive Records';

  @override
  String get statistics_records_coldestDive => 'Coldest Dive';

  @override
  String get statistics_records_deepestDive => 'Deepest Dive';

  @override
  String statistics_records_diveNumber(Object number) {
    return 'Dive #$number';
  }

  @override
  String get statistics_records_emptySubtitle =>
      'Start logging dives to see your records here';

  @override
  String get statistics_records_emptyTitle => 'No Records Yet';

  @override
  String get statistics_records_error => 'Error loading records';

  @override
  String get statistics_records_firstDive => 'First Dive';

  @override
  String get statistics_records_longestDive => 'Longest Dive';

  @override
  String statistics_records_longestDiveValue(Object minutes) {
    return '$minutes min';
  }

  @override
  String statistics_records_milestoneSemanticLabel(
    Object title,
    Object siteName,
  ) {
    return '$title: $siteName';
  }

  @override
  String get statistics_records_milestones => 'Milestones';

  @override
  String get statistics_records_mostRecentDive => 'Most Recent Dive';

  @override
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  ) {
    return '$title: $value at $siteName';
  }

  @override
  String get statistics_records_retry => 'Retry';

  @override
  String get statistics_records_shallowestDive => 'Shallowest Dive';

  @override
  String get statistics_records_unknownSite => 'Unknown Site';

  @override
  String get statistics_records_warmestDive => 'Warmest Dive';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return '$title section';
  }

  @override
  String get statistics_social_appBar_title => 'Social & Buddies';

  @override
  String get statistics_social_soloVsBuddy_empty => 'No dive data available';

  @override
  String get statistics_social_soloVsBuddy_error => 'Failed to load buddy data';

  @override
  String get statistics_social_soloVsBuddy_solo => 'Solo';

  @override
  String get statistics_social_soloVsBuddy_subtitle =>
      'Diving with or without companions';

  @override
  String get statistics_social_soloVsBuddy_title => 'Solo vs Buddy Dives';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => 'With Buddy';

  @override
  String get statistics_social_topBuddies_error =>
      'Failed to load buddy rankings';

  @override
  String get statistics_social_topBuddies_subtitle =>
      'Most frequent diving companions';

  @override
  String get statistics_social_topBuddies_title => 'Top Dive Buddies';

  @override
  String get statistics_social_topDiveCenters_error =>
      'Failed to load dive center rankings';

  @override
  String get statistics_social_topDiveCenters_subtitle =>
      'Most visited operators';

  @override
  String get statistics_social_topDiveCenters_title => 'Top Dive Centers';

  @override
  String get statistics_summary_avgDepth => 'Avg Depth';

  @override
  String get statistics_summary_avgTemp => 'Avg Temp';

  @override
  String get statistics_summary_depthDistribution_empty =>
      'Chart will appear when you log dives';

  @override
  String get statistics_summary_depthDistribution_semanticLabel =>
      'Pie chart showing depth distribution';

  @override
  String get statistics_summary_depthDistribution_title => 'Depth Distribution';

  @override
  String get statistics_summary_diveTypes_empty =>
      'Chart will appear when you log dives';

  @override
  String statistics_summary_diveTypes_moreTypes(Object count) {
    return 'and $count more types';
  }

  @override
  String get statistics_summary_diveTypes_semanticLabel =>
      'Pie chart showing dive type distribution';

  @override
  String get statistics_summary_diveTypes_title => 'Dive Types';

  @override
  String get statistics_summary_divesByMonth_empty =>
      'Chart will appear when you log dives';

  @override
  String get statistics_summary_divesByMonth_semanticLabel =>
      'Bar chart showing dives by month';

  @override
  String get statistics_summary_divesByMonth_title => 'Dives by Month';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel $count dives';
  }

  @override
  String get statistics_summary_header_subtitle =>
      'Select a category to explore detailed statistics';

  @override
  String get statistics_summary_header_title => 'Statistics Overview';

  @override
  String get statistics_summary_maxDepth => 'Max Depth';

  @override
  String get statistics_summary_sitesVisited => 'Sites Visited';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives',
      one: '1 dive',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty => 'No tags created yet';

  @override
  String get statistics_summary_tagUsage_emptyHint =>
      'Add tags to dives to see statistics';

  @override
  String statistics_summary_tagUsage_moreTags(Object count) {
    return 'and $count more tags';
  }

  @override
  String statistics_summary_tagUsage_tagCount(Object count) {
    return '$count tags';
  }

  @override
  String get statistics_summary_tagUsage_title => 'Tag Usage';

  @override
  String statistics_summary_topDiveSites_diveCount(Object count) {
    return '$count dives';
  }

  @override
  String get statistics_summary_topDiveSites_empty => 'No dive sites yet';

  @override
  String get statistics_summary_topDiveSites_title => 'Top Dive Sites';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count total';
  }

  @override
  String get statistics_summary_totalDives => 'Total Dives';

  @override
  String get statistics_summary_totalTime => 'Total Time';

  @override
  String get statistics_timePatterns_appBar_title => 'Time Patterns';

  @override
  String get statistics_timePatterns_dayOfWeek_empty => 'No data available';

  @override
  String get statistics_timePatterns_dayOfWeek_error =>
      'Failed to load day of week data';

  @override
  String get statistics_timePatterns_dayOfWeek_fri => 'Fri';

  @override
  String get statistics_timePatterns_dayOfWeek_mon => 'Mon';

  @override
  String get statistics_timePatterns_dayOfWeek_sat => 'Sat';

  @override
  String get statistics_timePatterns_dayOfWeek_subtitle =>
      'When do you dive most?';

  @override
  String get statistics_timePatterns_dayOfWeek_sun => 'Sun';

  @override
  String get statistics_timePatterns_dayOfWeek_thu => 'Thu';

  @override
  String get statistics_timePatterns_dayOfWeek_title => 'Dives by Day of Week';

  @override
  String get statistics_timePatterns_dayOfWeek_tue => 'Tue';

  @override
  String get statistics_timePatterns_dayOfWeek_wed => 'Wed';

  @override
  String get statistics_timePatterns_month_apr => 'Apr';

  @override
  String get statistics_timePatterns_month_aug => 'Aug';

  @override
  String get statistics_timePatterns_month_dec => 'Dec';

  @override
  String get statistics_timePatterns_month_feb => 'Feb';

  @override
  String get statistics_timePatterns_month_jan => 'Jan';

  @override
  String get statistics_timePatterns_month_jul => 'Jul';

  @override
  String get statistics_timePatterns_month_jun => 'Jun';

  @override
  String get statistics_timePatterns_month_mar => 'Mar';

  @override
  String get statistics_timePatterns_month_may => 'May';

  @override
  String get statistics_timePatterns_month_nov => 'Nov';

  @override
  String get statistics_timePatterns_month_oct => 'Oct';

  @override
  String get statistics_timePatterns_month_sep => 'Sep';

  @override
  String get statistics_timePatterns_seasonal_empty => 'No data available';

  @override
  String get statistics_timePatterns_seasonal_error =>
      'Failed to load seasonal data';

  @override
  String get statistics_timePatterns_seasonal_subtitle =>
      'Dives by month (all years)';

  @override
  String get statistics_timePatterns_seasonal_title => 'Seasonal Patterns';

  @override
  String get statistics_timePatterns_surfaceInterval_average => 'Average';

  @override
  String get statistics_timePatterns_surfaceInterval_empty =>
      'No surface interval data available';

  @override
  String get statistics_timePatterns_surfaceInterval_error =>
      'Failed to load surface interval data';

  @override
  String statistics_timePatterns_surfaceInterval_formatHoursMinutes(
    Object hours,
    Object minutes,
  ) {
    return '${hours}h ${minutes}m';
  }

  @override
  String statistics_timePatterns_surfaceInterval_formatMinutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String get statistics_timePatterns_surfaceInterval_maximum => 'Maximum';

  @override
  String get statistics_timePatterns_surfaceInterval_minimum => 'Minimum';

  @override
  String get statistics_timePatterns_surfaceInterval_subtitle =>
      'Time between dives';

  @override
  String get statistics_timePatterns_surfaceInterval_title =>
      'Surface Interval Statistics';

  @override
  String get statistics_timePatterns_timeOfDay_error =>
      'Failed to load time of day data';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle =>
      'Morning, afternoon, evening, or night';

  @override
  String get statistics_timePatterns_timeOfDay_title => 'Dives by Time of Day';

  @override
  String get statistics_tooltip_diveRecords => 'Dive Records';

  @override
  String get statistics_tooltip_refreshRecords => 'Refresh records';

  @override
  String get statistics_tooltip_refreshStatistics => 'Refresh statistics';

  @override
  String statistics_valueCard_semanticLabel(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String get surfaceInterval_aboutTissueLoading_body =>
      'Your body has 16 tissue compartments that absorb and release nitrogen at different rates. Fast tissues (like blood) saturate quickly but also off-gas quickly. Slow tissues (like bone and fat) take longer to both load and unload.  The \"leading compartment\" is whichever tissue is most saturated and typically controls your no-decompression limit (NDL). During a surface interval, all tissues off-gas toward surface saturation levels (~40% loading).';

  @override
  String get surfaceInterval_aboutTissueLoading_title => 'About Tissue Loading';

  @override
  String get surfaceInterval_action_resetDefaults => 'Reset to defaults';

  @override
  String get surfaceInterval_disclaimer =>
      'This tool is for planning purposes only. Always use a dive computer and follow your training. Results are based on the Buhlmann ZH-L16C algorithm and may differ from your computer.';

  @override
  String get surfaceInterval_field_depth => 'Depth';

  @override
  String get surfaceInterval_field_gasMix => 'Gas Mix: ';

  @override
  String get surfaceInterval_field_he => 'He';

  @override
  String get surfaceInterval_field_o2 => 'O₂';

  @override
  String get surfaceInterval_field_time => 'Time';

  @override
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit) {
    return 'First dive depth: $depth $unit';
  }

  @override
  String surfaceInterval_firstDive_timeSemantics(Object time) {
    return 'First dive time: $time minutes';
  }

  @override
  String get surfaceInterval_firstDive_title => 'First Dive';

  @override
  String surfaceInterval_format_hours(Object count) {
    return '$count hours';
  }

  @override
  String surfaceInterval_format_minutes(Object count) {
    return '$count min';
  }

  @override
  String get surfaceInterval_gasMix_air => 'Air';

  @override
  String surfaceInterval_gasMix_ean(Object percent) {
    return 'EAN$percent';
  }

  @override
  String surfaceInterval_gasMix_trimix(Object o2, Object he) {
    return 'Trimix $o2/$he';
  }

  @override
  String surfaceInterval_heSemantics(Object percent) {
    return 'Helium: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Current Interval';

  @override
  String get surfaceInterval_result_inDeco => 'In deco';

  @override
  String get surfaceInterval_result_increaseInterval =>
      'Increase surface interval or reduce second dive depth/time';

  @override
  String get surfaceInterval_result_minimumInterval =>
      'Minimum Surface Interval';

  @override
  String get surfaceInterval_result_ndlForSecondDive => 'NDL for 2nd Dive';

  @override
  String surfaceInterval_result_ndlMinutes(Object minutes) {
    return '$minutes min NDL';
  }

  @override
  String get surfaceInterval_result_notYetSafe =>
      'Not yet safe, increase surface interval';

  @override
  String get surfaceInterval_result_safeToDive => 'Safe to dive';

  @override
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  ) {
    return 'Minimum surface interval: $interval. Current interval: $current. NDL for second dive: $ndl. $status';
  }

  @override
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit) {
    return 'Second dive depth: $depth $unit';
  }

  @override
  String get surfaceInterval_secondDive_gasAir => '(Air)';

  @override
  String surfaceInterval_secondDive_timeSemantics(Object time) {
    return 'Second dive time: $time minutes';
  }

  @override
  String get surfaceInterval_secondDive_title => 'Second Dive';

  @override
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval) {
    return 'Tissue recovery chart showing 16 compartment off-gassing over a $interval surface interval';
  }

  @override
  String get surfaceInterval_tissueRecovery_compartmentsLabel =>
      'Compartments (by half-time speed)';

  @override
  String get surfaceInterval_tissueRecovery_description =>
      'Showing how each of 16 tissue compartments off-gas during the surface interval';

  @override
  String get surfaceInterval_tissueRecovery_fast => 'Fast (C1-5)';

  @override
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number) {
    return 'Leading compartment: C$number';
  }

  @override
  String get surfaceInterval_tissueRecovery_loadingPercent => 'Loading %';

  @override
  String get surfaceInterval_tissueRecovery_medium => 'Medium (C6-10)';

  @override
  String get surfaceInterval_tissueRecovery_min => 'Min';

  @override
  String get surfaceInterval_tissueRecovery_now => 'Now';

  @override
  String get surfaceInterval_tissueRecovery_slow => 'Slow (C11-16)';

  @override
  String get surfaceInterval_tissueRecovery_title => 'Tissue Recovery';

  @override
  String get surfaceInterval_title => 'Surface Interval';

  @override
  String tags_action_createNamed(Object tagName) {
    return 'Create \"$tagName\"';
  }

  @override
  String get tags_action_createTag => 'Create tag';

  @override
  String get tags_action_deleteTag => 'Delete tag';

  @override
  String tags_dialog_deleteMessage(Object tagName) {
    return 'Are you sure you want to delete \"$tagName\"? This will remove it from all dives.';
  }

  @override
  String get tags_dialog_deleteTitle => 'Delete Tag?';

  @override
  String get tags_empty => 'No tags yet. Create tags when editing dives.';

  @override
  String get tags_hint_addMoreTags => 'Add more tags...';

  @override
  String get tags_hint_addTags => 'Add tags...';

  @override
  String get tags_title_manageTags => 'Manage Tags';

  @override
  String get tank_al30Stage_description => 'Aluminum 30 cu ft stage tank';

  @override
  String get tank_al30Stage_displayName => 'AL30 Stage';

  @override
  String get tank_al40Stage_description => 'Aluminum 40 cu ft stage tank';

  @override
  String get tank_al40Stage_displayName => 'AL40 Stage';

  @override
  String get tank_al40_description => 'Aluminum 40 cu ft (pony)';

  @override
  String get tank_al40_displayName => 'AL40';

  @override
  String get tank_al63_description => 'Aluminum 63 cu ft';

  @override
  String get tank_al63_displayName => 'AL63';

  @override
  String get tank_al80_description => 'Aluminum 80 cu ft (most common)';

  @override
  String get tank_al80_displayName => 'AL80';

  @override
  String get tank_hp100_description => 'High Pressure Steel 100 cu ft';

  @override
  String get tank_hp100_displayName => 'HP100';

  @override
  String get tank_hp120_description => 'High Pressure Steel 120 cu ft';

  @override
  String get tank_hp120_displayName => 'HP120';

  @override
  String get tank_hp80_description => 'High Pressure Steel 80 cu ft';

  @override
  String get tank_hp80_displayName => 'HP80';

  @override
  String get tank_lp85_description => 'Low Pressure Steel 85 cu ft';

  @override
  String get tank_lp85_displayName => 'LP85';

  @override
  String get tank_steel10_description => 'Steel 10 liter (Europe)';

  @override
  String get tank_steel10_displayName => 'Steel 10L';

  @override
  String get tank_steel12_description => 'Steel 12 liter (Europe)';

  @override
  String get tank_steel12_displayName => 'Steel 12L';

  @override
  String get tank_steel15_description => 'Steel 15 liter (Europe)';

  @override
  String get tank_steel15_displayName => 'Steel 15L';

  @override
  String get tides_action_refresh => 'Refresh tide data';

  @override
  String get tides_chart_24hourForecast => '24-Hour Forecast';

  @override
  String tides_chart_heightAxis(Object depthSymbol) {
    return 'Height ($depthSymbol)';
  }

  @override
  String get tides_chart_msl => 'MSL';

  @override
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr) {
    return ' Now $nowTimeStr $nowHeightStr';
  }

  @override
  String get tides_error_unableToLoad => 'Unable to load tide data';

  @override
  String get tides_error_unableToLoadChart => 'Unable to load chart';

  @override
  String tides_label_ago(Object duration) {
    return '$duration ago';
  }

  @override
  String tides_label_currentHeight(Object height, Object depthSymbol) {
    return 'Current: $height$depthSymbol';
  }

  @override
  String tides_label_fromNow(Object duration) {
    return '$duration from now';
  }

  @override
  String get tides_label_high => 'High';

  @override
  String get tides_label_highIn => 'High in';

  @override
  String get tides_label_highTide => 'High Tide';

  @override
  String get tides_label_low => 'Low';

  @override
  String get tides_label_lowIn => 'Low in';

  @override
  String get tides_label_lowTide => 'Low Tide';

  @override
  String tides_label_tideIn(Object duration) {
    return 'in $duration';
  }

  @override
  String get tides_label_tideTimes => 'Tide Times';

  @override
  String get tides_label_today => 'Today';

  @override
  String get tides_label_tomorrow => 'Tomorrow';

  @override
  String get tides_label_upcomingTides => 'Upcoming Tides';

  @override
  String get tides_legend_highTide => 'High Tide';

  @override
  String get tides_legend_lowTide => 'Low Tide';

  @override
  String get tides_legend_now => 'Now';

  @override
  String get tides_legend_tideLevel => 'Tide Level';

  @override
  String get tides_noDataAvailable => 'No tide data available';

  @override
  String get tides_noDataForLocation =>
      'Tide data not available for this location';

  @override
  String get tides_noExtremesData => 'No extremes data';

  @override
  String get tides_noTideTimesAvailable => 'No tide times available';

  @override
  String tides_semantic_currentTide(
    Object tideState,
    Object height,
    Object depthSymbol,
    Object nextExtreme,
  ) {
    return '$tideState tide, $height$depthSymbol$nextExtreme';
  }

  @override
  String tides_semantic_extremeItem(
    Object typeLabel,
    Object time,
    Object height,
    Object depthSymbol,
  ) {
    return '$typeLabel tide at $time, $height$depthSymbol';
  }

  @override
  String tides_semantic_tideChart(Object extremesSummary) {
    return 'Tide chart. $extremesSummary';
  }

  @override
  String tides_semantic_tideState(Object state) {
    return 'Tide state: $state';
  }

  @override
  String get tides_title => 'Tides';

  @override
  String get transfer_appBar_title => 'Transfer';

  @override
  String get transfer_computers_aboutContent =>
      'Connect your dive computer via Bluetooth to download dive logs directly to the app. Supported computers include Suunto, Shearwater, Garmin, Mares, and many other popular brands.  Apple Watch Ultra users can import dive data directly from the Health app, including depth, duration, and heart rate.';

  @override
  String get transfer_computers_aboutTitle => 'About Dive Computers';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple Watch';

  @override
  String get transfer_computers_appleWatchSubtitle =>
      'Import dives recorded on Apple Watch Ultra';

  @override
  String get transfer_computers_appleWatchTitle => 'Import from Apple Watch';

  @override
  String get transfer_computers_connectSubtitle =>
      'Discover and pair a dive computer';

  @override
  String get transfer_computers_connectTitle => 'Connect New Computer';

  @override
  String get transfer_computers_errorLoading => 'Error loading computers';

  @override
  String get transfer_computers_loading => 'Loading...';

  @override
  String get transfer_computers_manageTitle => 'Manage Computers';

  @override
  String get transfer_computers_noComputersSaved => 'No computers saved';

  @override
  String transfer_computers_savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'computers',
      one: 'computer',
    );
    return '$count saved $_temp0';
  }

  @override
  String get transfer_computers_sectionHeader => 'Dive Computers';

  @override
  String get transfer_csvExport_cancelButton => 'Cancel';

  @override
  String get transfer_csvExport_dataTypeHeader => 'Data Type';

  @override
  String get transfer_csvExport_descriptionDives =>
      'Export all dive logs as a spreadsheet';

  @override
  String get transfer_csvExport_descriptionEquipment =>
      'Export equipment inventory and service info';

  @override
  String get transfer_csvExport_descriptionSites =>
      'Export dive site locations and details';

  @override
  String get transfer_csvExport_dialogTitle => 'Export CSV';

  @override
  String get transfer_csvExport_exportButton => 'Export CSV';

  @override
  String get transfer_csvExport_optionDivesTitle => 'Dives CSV';

  @override
  String get transfer_csvExport_optionEquipmentTitle => 'Equipment CSV';

  @override
  String get transfer_csvExport_optionSitesTitle => 'Sites CSV';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return 'Export $typeName';
  }

  @override
  String get transfer_csvExport_typeDives => 'Dives';

  @override
  String get transfer_csvExport_typeEquipment => 'Equipment';

  @override
  String get transfer_csvExport_typeSites => 'Sites';

  @override
  String get transfer_detail_backTooltip => 'Back to transfer';

  @override
  String get transfer_export_aboutContent =>
      'Export your dive data in various formats. PDF creates a printable logbook. UDDF is a universal format compatible with most dive logging software. CSV files can be opened in spreadsheet applications.';

  @override
  String get transfer_export_aboutTitle => 'About Export';

  @override
  String get transfer_export_completed => 'Export completed';

  @override
  String get transfer_export_csvSubtitle => 'Spreadsheet format';

  @override
  String get transfer_export_csvTitle => 'CSV Export';

  @override
  String get transfer_export_excelSubtitle =>
      'All data in one file (dives, sites, equipment, stats)';

  @override
  String get transfer_export_excelTitle => 'Excel Workbook';

  @override
  String transfer_export_failed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get transfer_export_kmlSubtitle => 'View dive sites on a 3D globe';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => 'Multi-Format Export';

  @override
  String get transfer_export_optionSaveSubtitle =>
      'Choose where to save on your device';

  @override
  String get transfer_export_optionSaveTitle => 'Save to File';

  @override
  String get transfer_export_optionShareSubtitle =>
      'Send via email, messages, or other apps';

  @override
  String get transfer_export_optionShareTitle => 'Share';

  @override
  String get transfer_export_pdfSubtitle => 'Printable dive logbook';

  @override
  String get transfer_export_pdfTitle => 'PDF Logbook';

  @override
  String get transfer_export_progressExporting => 'Exporting...';

  @override
  String get transfer_export_sectionHeader => 'Export Data';

  @override
  String get transfer_export_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_export_uddfTitle => 'UDDF Export';

  @override
  String get transfer_import_aboutContent =>
      'Use \"Import Data\" for the best experience -- it auto-detects your file format and source app. The individual format options below are also available for direct access.';

  @override
  String get transfer_import_aboutTitle => 'About Import';

  @override
  String get transfer_import_autoDetectSemanticLabel =>
      'Import data with auto-detection';

  @override
  String get transfer_import_autoDetectSubtitle =>
      'Auto-detects CSV, UDDF, FIT, and more';

  @override
  String get transfer_import_autoDetectTitle => 'Import Data';

  @override
  String get transfer_import_byFormatHeader => 'Import by Format';

  @override
  String get transfer_import_csvSubtitle => 'Import dives from CSV file';

  @override
  String get transfer_import_csvTitle => 'Import from CSV';

  @override
  String get transfer_import_fitSubtitle =>
      'Import dives from Garmin Descent export files';

  @override
  String get transfer_import_fitTitle => 'Import from FIT File';

  @override
  String get transfer_import_operationCompleted => 'Operation completed';

  @override
  String transfer_import_operationFailed(Object error) {
    return 'Operation failed: $error';
  }

  @override
  String get transfer_import_sectionHeader => 'Import Data';

  @override
  String get transfer_import_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_import_uddfTitle => 'Import from UDDF';

  @override
  String get transfer_pdfExport_cancelButton => 'Cancel';

  @override
  String get transfer_pdfExport_dialogTitle => 'Export PDF Logbook';

  @override
  String get transfer_pdfExport_exportButton => 'Export PDF';

  @override
  String get transfer_pdfExport_includeCertCards =>
      'Include Certification Cards';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle =>
      'Add scanned certification card images to the PDF';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => 'Page Size';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Letter';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => 'Detailed';

  @override
  String get transfer_pdfExport_templateDetailedDesc =>
      'Full dive information with notes and ratings';

  @override
  String get transfer_pdfExport_templateHeader => 'Template';

  @override
  String get transfer_pdfExport_templateNauiStyle => 'NAUI Style';

  @override
  String get transfer_pdfExport_templateNauiStyleDesc =>
      'Layout matching NAUI logbook format';

  @override
  String get transfer_pdfExport_templatePadiStyle => 'PADI Style';

  @override
  String get transfer_pdfExport_templatePadiStyleDesc =>
      'Layout matching PADI logbook format';

  @override
  String get transfer_pdfExport_templateProfessional => 'Professional';

  @override
  String get transfer_pdfExport_templateProfessionalDesc =>
      'Signature and stamp areas for verification';

  @override
  String transfer_pdfExport_templateSemanticLabel(Object templateName) {
    return 'Select $templateName template';
  }

  @override
  String get transfer_pdfExport_templateSimple => 'Simple';

  @override
  String get transfer_pdfExport_templateSimpleDesc =>
      'Compact table format, many dives per page';

  @override
  String get transfer_section_computersSubtitle => 'Download from device';

  @override
  String get transfer_section_computersTitle => 'Dive Computers';

  @override
  String get transfer_section_exportSubtitle => 'CSV, UDDF, PDF logbook';

  @override
  String get transfer_section_exportTitle => 'Export';

  @override
  String get transfer_section_importSubtitle => 'CSV, UDDF files';

  @override
  String get transfer_section_importTitle => 'Import';

  @override
  String get transfer_summary_description => 'Import and export dive data';

  @override
  String get transfer_summary_selectSection => 'Select a section from the list';

  @override
  String get transfer_summary_title => 'Transfer';

  @override
  String transfer_unknownSection(Object sectionId) {
    return 'Unknown section: $sectionId';
  }

  @override
  String get trips_appBar_title => 'Trips';

  @override
  String get trips_appBar_tripPhotos => 'Trip Photos';

  @override
  String get trips_detail_action_delete => 'Delete';

  @override
  String get trips_detail_action_export => 'Export';

  @override
  String get trips_detail_appBar_title => 'Trip';

  @override
  String get trips_detail_dialog_cancel => 'Cancel';

  @override
  String get trips_detail_dialog_deleteConfirm => 'Delete';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return 'Are you sure you want to delete \"$name\"? This will remove the trip but keep the dives.';
  }

  @override
  String get trips_detail_dialog_deleteTitle => 'Delete Trip?';

  @override
  String get trips_detail_dives_empty => 'No dives in this trip yet';

  @override
  String get trips_detail_dives_errorLoading => 'Unable to load dives';

  @override
  String get trips_detail_dives_unknownSite => 'Unknown Site';

  @override
  String trips_detail_dives_viewAll(Object count) {
    return 'View All ($count)';
  }

  @override
  String trips_detail_durationDays(Object days) {
    return '$days days';
  }

  @override
  String get trips_detail_export_csv_comingSoon => 'CSV export coming soon';

  @override
  String get trips_detail_export_csv_subtitle => 'All dives in this trip';

  @override
  String get trips_detail_export_csv_title => 'Export to CSV';

  @override
  String get trips_detail_export_pdf_comingSoon => 'PDF export coming soon';

  @override
  String get trips_detail_export_pdf_subtitle =>
      'Trip summary with dive details';

  @override
  String get trips_detail_export_pdf_title => 'Export to PDF';

  @override
  String get trips_detail_label_liveaboard => 'Liveaboard';

  @override
  String get trips_detail_label_location => 'Location';

  @override
  String get trips_detail_label_resort => 'Resort';

  @override
  String get trips_detail_scan_accessDenied => 'Photo library access denied';

  @override
  String get trips_detail_scan_addDivesFirst =>
      'Add dives first to link photos';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return 'Error linking photos: $error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return 'Error scanning: $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return 'Linked $count photos';
  }

  @override
  String get trips_detail_scan_linkingPhotos => 'Linking photos...';

  @override
  String get trips_detail_sectionTitle_details => 'Trip Details';

  @override
  String get trips_detail_sectionTitle_dives => 'Dives';

  @override
  String get trips_detail_sectionTitle_notes => 'Notes';

  @override
  String get trips_detail_sectionTitle_statistics => 'Trip Statistics';

  @override
  String get trips_detail_snackBar_deleted => 'Trip deleted';

  @override
  String get trips_detail_stat_avgDepth => 'Avg Depth';

  @override
  String get trips_detail_stat_maxDepth => 'Max Depth';

  @override
  String get trips_detail_stat_totalBottomTime => 'Total Bottom Time';

  @override
  String get trips_detail_stat_totalDives => 'Total Dives';

  @override
  String get trips_detail_tooltip_edit => 'Edit trip';

  @override
  String get trips_detail_tooltip_editShort => 'Edit';

  @override
  String get trips_detail_tooltip_moreOptions => 'More options';

  @override
  String get trips_detail_tooltip_viewOnMap => 'View on Map';

  @override
  String get trips_edit_appBar_add => 'Add Trip';

  @override
  String get trips_edit_appBar_edit => 'Edit Trip';

  @override
  String get trips_edit_button_add => 'Add Trip';

  @override
  String get trips_edit_button_cancel => 'Cancel';

  @override
  String get trips_edit_button_save => 'Save';

  @override
  String get trips_edit_button_update => 'Update Trip';

  @override
  String get trips_edit_dialog_discard => 'Discard';

  @override
  String get trips_edit_dialog_discardContent =>
      'You have unsaved changes. Are you sure you want to leave?';

  @override
  String get trips_edit_dialog_discardTitle => 'Discard Changes?';

  @override
  String get trips_edit_dialog_keepEditing => 'Keep Editing';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days days';
  }

  @override
  String get trips_edit_hint_liveaboardName => 'e.g., MY Blue Force One';

  @override
  String get trips_edit_hint_location => 'e.g., Egypt, Red Sea';

  @override
  String get trips_edit_hint_notes => 'Any additional notes about this trip';

  @override
  String get trips_edit_hint_resortName => 'e.g., Marsa Shagra';

  @override
  String get trips_edit_hint_tripName => 'e.g., Red Sea Safari 2024';

  @override
  String get trips_edit_label_endDate => 'End Date';

  @override
  String get trips_edit_label_liveaboardName => 'Liveaboard Name';

  @override
  String get trips_edit_label_location => 'Location';

  @override
  String get trips_edit_label_notes => 'Notes';

  @override
  String get trips_edit_label_resortName => 'Resort Name';

  @override
  String get trips_edit_label_startDate => 'Start Date';

  @override
  String get trips_edit_label_tripName => 'Trip Name *';

  @override
  String get trips_edit_sectionTitle_dates => 'Trip Dates';

  @override
  String get trips_edit_sectionTitle_location => 'Location';

  @override
  String get trips_edit_sectionTitle_notes => 'Notes';

  @override
  String get trips_edit_semanticLabel_save => 'Save trip';

  @override
  String get trips_edit_snackBar_added => 'Trip added successfully';

  @override
  String trips_edit_snackBar_errorLoading(Object error) {
    return 'Error loading trip: $error';
  }

  @override
  String trips_edit_snackBar_errorSaving(Object error) {
    return 'Error saving trip: $error';
  }

  @override
  String get trips_edit_snackBar_updated => 'Trip updated successfully';

  @override
  String get trips_edit_validation_nameRequired => 'Please enter a trip name';

  @override
  String get trips_gallery_accessDenied => 'Photo library access denied';

  @override
  String get trips_gallery_addDivesFirst => 'Add dives first to link photos';

  @override
  String get trips_gallery_appBar_title => 'Trip Photos';

  @override
  String trips_gallery_diveSection_photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'photos',
      one: 'photo',
    );
    return '$_temp0';
  }

  @override
  String trips_gallery_diveSection_title(Object number, Object site) {
    return 'Dive #$number - $site';
  }

  @override
  String get trips_gallery_empty_subtitle =>
      'Tap the camera icon to scan your gallery';

  @override
  String get trips_gallery_empty_title => 'No photos in this trip';

  @override
  String trips_gallery_errorLinking(Object error) {
    return 'Error linking photos: $error';
  }

  @override
  String trips_gallery_errorScanning(Object error) {
    return 'Error scanning: $error';
  }

  @override
  String trips_gallery_error_loading(Object error) {
    return 'Error loading photos: $error';
  }

  @override
  String trips_gallery_linkedPhotos(Object count) {
    return 'Linked $count photos';
  }

  @override
  String get trips_gallery_linkingPhotos => 'Linking photos...';

  @override
  String get trips_gallery_tooltip_scan => 'Scan device gallery';

  @override
  String get trips_gallery_tripNotFound => 'Trip not found';

  @override
  String get trips_list_button_retry => 'Retry';

  @override
  String get trips_list_empty_button => 'Add Your First Trip';

  @override
  String get trips_list_empty_filtered_subtitle =>
      'Try adjusting or clearing your filters';

  @override
  String get trips_list_empty_filtered_title => 'No trips match your filters';

  @override
  String get trips_list_empty_subtitle =>
      'Create trips to group your dives by destination';

  @override
  String get trips_list_empty_title => 'No trips added yet';

  @override
  String trips_list_error_loading(Object error) {
    return 'Error loading trips: $error';
  }

  @override
  String get trips_list_fab_addTrip => 'Add Trip';

  @override
  String get trips_list_filters_clearAll => 'Clear all';

  @override
  String get trips_list_sort_title => 'Sort Trips';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count dives';
  }

  @override
  String get trips_list_tooltip_addTrip => 'Add Trip';

  @override
  String get trips_list_tooltip_search => 'Search trips';

  @override
  String get trips_list_tooltip_sort => 'Sort';

  @override
  String get trips_photos_empty_scanButton => 'Scan device gallery';

  @override
  String get trips_photos_empty_title => 'No photos yet';

  @override
  String get trips_photos_error_loading => 'Error loading photos';

  @override
  String trips_photos_moreIndicator(Object count) {
    return '+$count';
  }

  @override
  String trips_photos_moreIndicator_semanticLabel(Object count) {
    return '$count more photos';
  }

  @override
  String get trips_photos_sectionTitle => 'Photos';

  @override
  String get trips_photos_tooltip_scan => 'Scan device gallery';

  @override
  String get trips_photos_viewAll => 'View All';

  @override
  String get trips_picker_clearTooltip => 'Clear selection';

  @override
  String get trips_picker_empty_createButton => 'Create Trip';

  @override
  String get trips_picker_empty_title => 'No trips yet';

  @override
  String trips_picker_error(Object error) {
    return 'Error loading trips: $error';
  }

  @override
  String get trips_picker_hint => 'Tap to select a trip';

  @override
  String get trips_picker_newTrip => 'New Trip';

  @override
  String get trips_picker_noSelection => 'No trip selected';

  @override
  String get trips_picker_sheetTitle => 'Select Trip';

  @override
  String trips_picker_suggestedPrefix(Object name) {
    return 'Suggested: $name';
  }

  @override
  String get trips_picker_suggestedUse => 'Use';

  @override
  String get trips_search_empty_hint => 'Search by name, location, or resort';

  @override
  String get trips_search_fieldLabel => 'Search trips...';

  @override
  String trips_search_noResults(Object query) {
    return 'No trips found for \"$query\"';
  }

  @override
  String get trips_search_tooltip_back => 'Back';

  @override
  String get trips_search_tooltip_clear => 'Clear search';

  @override
  String get trips_summary_header_subtitle =>
      'Select a trip from the list to view details';

  @override
  String get trips_summary_header_title => 'Trips';

  @override
  String get trips_summary_overview_title => 'Overview';

  @override
  String get trips_summary_quickActions_add => 'Add Trip';

  @override
  String get trips_summary_quickActions_title => 'Quick Actions';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date • $count dives';
  }

  @override
  String get trips_summary_recentTitle => 'Recent Trips';

  @override
  String get trips_summary_stat_daysDiving => 'Days Diving';

  @override
  String get trips_summary_stat_liveaboards => 'Liveaboards';

  @override
  String get trips_summary_stat_totalDives => 'Total Dives';

  @override
  String get trips_summary_stat_totalTrips => 'Total Trips';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date • In $days days';
  }

  @override
  String get trips_summary_upcomingTitle => 'Upcoming';

  @override
  String get units_altitude_feet => 'ft';

  @override
  String get units_altitude_meters => 'm';

  @override
  String get units_barometric_bar => 'bar';

  @override
  String get units_barometric_mbar => 'mbar';

  @override
  String get units_dateFormat_dMMMYYYY => 'D MMM YYYY';

  @override
  String get units_dateFormat_ddmmyyyy => 'DD/MM/YYYY';

  @override
  String get units_dateFormat_mmddyyyy => 'MM/DD/YYYY';

  @override
  String get units_dateFormat_mmmDYYYY => 'MMM D, YYYY';

  @override
  String get units_dateFormat_yyyymmdd => 'YYYY-MM-DD';

  @override
  String get units_depth_feet => 'ft';

  @override
  String get units_depth_meters => 'm';

  @override
  String get units_pressure_bar => 'bar';

  @override
  String get units_pressure_psi => 'psi';

  @override
  String get units_profileMetric_bpm => 'bpm';

  @override
  String get units_profileMetric_gPerL => 'g/L';

  @override
  String get units_profileMetric_min => 'min';

  @override
  String get units_profileMetric_percent => '%';

  @override
  String get units_sac_litersPerMin => 'L/min';

  @override
  String get units_sac_pressurePerMin => 'pressure/min';

  @override
  String get units_temperature_celsius => 'C';

  @override
  String get units_temperature_fahrenheit => 'F';

  @override
  String get units_timeFormat_twelveHour => '12-hour';

  @override
  String get units_timeFormat_twentyFourHour => '24-hour';

  @override
  String get units_volume_cubicFeet => 'cuft';

  @override
  String get units_volume_liters => 'L';

  @override
  String get units_weight_kilograms => 'kg';

  @override
  String get units_weight_pounds => 'lbs';

  @override
  String get universalImport_action_continue => 'Continue';

  @override
  String get universalImport_action_deselectAll => 'Deselect All';

  @override
  String get universalImport_action_done => 'Done';

  @override
  String get universalImport_action_import => 'Import';

  @override
  String get universalImport_action_selectAll => 'Select All';

  @override
  String get universalImport_action_selectFile => 'Select File';

  @override
  String get universalImport_description_supportedFormats =>
      'Select a dive log file to import. Supported formats include CSV, UDDF, Subsurface XML, and Garmin FIT.';

  @override
  String get universalImport_error_unsupportedFormat =>
      'This format is not yet supported. Please export as UDDF or CSV.';

  @override
  String get universalImport_hint_tagDescription =>
      'Tag all imported dives for easy filtering';

  @override
  String get universalImport_hint_tagExample =>
      'e.g., MacDive Import 2026-02-09';

  @override
  String get universalImport_label_columnMapping => 'Column Mapping';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped of $total columns mapped';
  }

  @override
  String get universalImport_label_detecting => 'Detecting...';

  @override
  String universalImport_label_diveNumber(Object number) {
    return 'Dive #$number';
  }

  @override
  String get universalImport_label_duplicate => 'Duplicate';

  @override
  String universalImport_label_duplicatesFound(Object count) {
    return '$count duplicates found and auto-deselected.';
  }

  @override
  String get universalImport_label_importComplete => 'Import Complete';

  @override
  String get universalImport_label_importTag => 'Import Tag';

  @override
  String get universalImport_label_importing => 'Importing';

  @override
  String get universalImport_label_importingEllipsis => 'Importing...';

  @override
  String universalImport_label_importingProgress(Object current, Object total) {
    return 'Importing $current of $total';
  }

  @override
  String universalImport_label_percentMatch(Object percent) {
    return '$percent% match';
  }

  @override
  String get universalImport_label_possibleMatch => 'Possible match';

  @override
  String get universalImport_label_selectCorrectSource =>
      'Not right? Select the correct source:';

  @override
  String universalImport_label_selected(Object count) {
    return '$count selected';
  }

  @override
  String get universalImport_label_skip => 'Skip';

  @override
  String universalImport_label_taggedAs(Object tag) {
    return 'Tagged as: $tag';
  }

  @override
  String get universalImport_label_unknownDate => 'Unknown date';

  @override
  String get universalImport_label_unnamed => 'Unnamed';

  @override
  String universalImport_label_xOfY(Object current, Object total) {
    return '$current of $total';
  }

  @override
  String universalImport_label_xOfYSelected(Object selected, Object total) {
    return '$selected of $total selected';
  }

  @override
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  ) {
    return '$selected of $total $entityType selected';
  }

  @override
  String universalImport_semantics_importError(Object error) {
    return 'Import error: $error';
  }

  @override
  String universalImport_semantics_importProgress(Object percent) {
    return 'Import progress: $percent percent';
  }

  @override
  String universalImport_semantics_itemsSelected(Object count) {
    return '$count items selected for import';
  }

  @override
  String get universalImport_semantics_possibleDuplicate =>
      'Possible duplicate';

  @override
  String get universalImport_semantics_probableDuplicate =>
      'Probable duplicate';

  @override
  String universalImport_semantics_sourceDetected(Object description) {
    return 'Source detected: $description';
  }

  @override
  String universalImport_semantics_sourceUncertain(Object description) {
    return 'Source uncertain: $description';
  }

  @override
  String universalImport_semantics_toggleSelection(Object name) {
    return 'Toggle selection for $name';
  }

  @override
  String get universalImport_step_import => 'Import';

  @override
  String get universalImport_step_map => 'Map';

  @override
  String get universalImport_step_review => 'Review';

  @override
  String get universalImport_step_select => 'Select';

  @override
  String get universalImport_title => 'Import Data';

  @override
  String get universalImport_tooltip_clearTag => 'Clear tag';

  @override
  String get universalImport_tooltip_closeWizard => 'Close import wizard';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return 'Base ($suitType): $weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return 'Body weight adjustment: +$adjustment kg';
  }

  @override
  String get weightCalc_suit_drysuit => 'Drysuit';

  @override
  String get weightCalc_suit_none => 'No Suit';

  @override
  String get weightCalc_suit_rashguard => 'Rashguard Only';

  @override
  String get weightCalc_suit_semidry => 'Semi-dry Suit';

  @override
  String get weightCalc_suit_shorty3mm => '3mm Shorty';

  @override
  String get weightCalc_suit_wetsuit3mm => '3mm Full Wetsuit';

  @override
  String get weightCalc_suit_wetsuit5mm => '5mm Wetsuit';

  @override
  String get weightCalc_suit_wetsuit7mm => '7mm Wetsuit';

  @override
  String weightCalc_tankLine(Object tankMaterial, Object adjustment) {
    return 'Tank ($tankMaterial): $adjustment kg';
  }

  @override
  String get weightCalc_title => 'Weight Calculation:';

  @override
  String weightCalc_total(Object total) {
    return 'Total: $total kg';
  }

  @override
  String weightCalc_waterLine(Object waterType, Object adjustment) {
    return 'Water ($waterType): $adjustment kg';
  }

  @override
  String divePlanner_label_resultsWithWarnings(Object count) {
    return 'Results, $count warnings';
  }

  @override
  String tides_semantic_tideCycle(Object state, Object height) {
    return 'Tide cycle, state: $state, height: $height';
  }

  @override
  String get tides_label_agoSuffix => 'ago';

  @override
  String get tides_label_fromNowSuffix => 'from now';

  @override
  String get certifications_card_issued => 'ISSUED';

  @override
  String certifications_certificate_cardNumber(Object number) {
    return 'Card Number: $number';
  }

  @override
  String get certifications_certificate_footer =>
      'Official Scuba Diving Certification';

  @override
  String get certifications_certificate_hasCompletedTraining =>
      'has completed training as';

  @override
  String certifications_certificate_instructor(Object name) {
    return 'Instructor: $name';
  }

  @override
  String certifications_certificate_issued(Object date) {
    return 'Issued: $date';
  }

  @override
  String get certifications_certificate_thisCertifies => 'This certifies that';

  @override
  String get diveComputer_discovery_chooseDifferentDevice =>
      'Choose Different Device';

  @override
  String get diveComputer_discovery_computer => 'Computer';

  @override
  String get diveComputer_discovery_connectAndDownload => 'Connect & Download';

  @override
  String get diveComputer_discovery_connectingToDevice =>
      'Connecting to device...';

  @override
  String diveComputer_discovery_deviceNameHint(Object model) {
    return 'e.g., My $model';
  }

  @override
  String get diveComputer_discovery_deviceNameLabel => 'Device Name';

  @override
  String get diveComputer_discovery_exitDialogCancel => 'Cancel';

  @override
  String get diveComputer_discovery_exitDialogConfirm => 'Exit';

  @override
  String get diveComputer_discovery_exitDialogContent =>
      'Are you sure you want to exit? Your progress will be lost.';

  @override
  String get diveComputer_discovery_exitDialogTitle => 'Exit Setup?';

  @override
  String get diveComputer_discovery_exitTooltip => 'Exit setup';

  @override
  String get diveComputer_discovery_noDeviceSelected => 'No device selected';

  @override
  String get diveComputer_discovery_pleaseWaitConnection =>
      'Please wait while we establish a connection';

  @override
  String get diveComputer_discovery_recognizedDevice => 'Recognized Device';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      'This device is in our supported devices library. Dive download should work automatically.';

  @override
  String get diveComputer_discovery_stepConnect => 'Connect';

  @override
  String get diveComputer_discovery_stepDone => 'Done';

  @override
  String get diveComputer_discovery_stepDownload => 'Download';

  @override
  String get diveComputer_discovery_stepScan => 'Scan';

  @override
  String get diveComputer_discovery_titleComplete => 'Complete';

  @override
  String get diveComputer_discovery_titleConfirmDevice => 'Confirm Device';

  @override
  String get diveComputer_discovery_titleConnecting => 'Connecting';

  @override
  String get diveComputer_discovery_titleDownloading => 'Downloading';

  @override
  String get diveComputer_discovery_titleFindDevice => 'Find Device';

  @override
  String get diveComputer_discovery_unknownDevice => 'Unknown Device';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      'This device is not in our library. We\'ll try to connect, but download may not work.';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... and $count more';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Cancel';

  @override
  String get diveComputer_downloadStep_cancelled => 'Download cancelled';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadFailed => 'Download failed';

  @override
  String get diveComputer_downloadStep_downloadedDives => 'Downloaded Dives';

  @override
  String diveComputer_downloadStep_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_downloadStep_errorOccurred => 'An error occurred';

  @override
  String diveComputer_downloadStep_errorSemanticLabel(Object error) {
    return 'Download error: $error';
  }

  @override
  String diveComputer_downloadStep_percentAccessibility(Object percent) {
    return ', $percent percent';
  }

  @override
  String get diveComputer_downloadStep_preparing => 'Preparing...';

  @override
  String diveComputer_downloadStep_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String diveComputer_downloadStep_progressSemanticLabel(
    Object status,
    Object percent,
  ) {
    return 'Download progress: $status$percent';
  }

  @override
  String get diveComputer_downloadStep_retry => 'Retry';

  @override
  String get diveComputer_download_cancel => 'Cancel';

  @override
  String get diveComputer_download_closeTooltip => 'Close';

  @override
  String get diveComputer_download_computerNotFound => 'Computer not found';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return 'Device not found. Make sure your $name is nearby and in transfer mode.';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle => 'Device Not Found';

  @override
  String get diveComputer_download_divesUpdated => 'Dives updated';

  @override
  String get diveComputer_download_done => 'Done';

  @override
  String get diveComputer_download_downloadedDives => 'Downloaded Dives';

  @override
  String get diveComputer_download_duplicatesSkipped => 'Duplicates skipped';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_download_errorOccurred => 'An error occurred';

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get diveComputer_download_goBack => 'Go Back';

  @override
  String get diveComputer_download_importFailed => 'Import failed';

  @override
  String get diveComputer_download_importResults => 'Import Results';

  @override
  String get diveComputer_download_importedDives => 'Imported Dives';

  @override
  String get diveComputer_download_newDivesImported => 'New dives imported';

  @override
  String get diveComputer_download_preparing => 'Preparing...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_retry => 'Retry';

  @override
  String diveComputer_download_scanError(Object error) {
    return 'Scan error: $error';
  }

  @override
  String diveComputer_download_searchingForDevice(Object name) {
    return 'Searching for $name...';
  }

  @override
  String get diveComputer_download_searchingInstructions =>
      'Make sure the device is nearby and in transfer mode';

  @override
  String get diveComputer_download_title => 'Download Dives';

  @override
  String get diveComputer_download_tryAgain => 'Try Again';

  @override
  String get diveComputer_list_addComputer => 'Add Computer';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return 'Dive computer: $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count dives';
  }

  @override
  String get diveComputer_list_downloadTooltip => 'Download dives';

  @override
  String get diveComputer_list_emptyMessage =>
      'Connect your dive computer to download dives directly into the app.';

  @override
  String get diveComputer_list_emptyTitle => 'No Dive Computers';

  @override
  String get diveComputer_list_findComputers => 'Find Computers';

  @override
  String get diveComputer_list_helpBluetooth =>
      '• Bluetooth LE (most modern computers)';

  @override
  String get diveComputer_list_helpBluetoothClassic =>
      '• Bluetooth Classic (older models)';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi, and 50+ more models.';

  @override
  String get diveComputer_list_helpBrandsTitle => 'Supported Brands';

  @override
  String get diveComputer_list_helpConnectionsTitle => 'Supported Connections';

  @override
  String get diveComputer_list_helpDialogTitle => 'Dive Computer Help';

  @override
  String get diveComputer_list_helpDismiss => 'Got it';

  @override
  String get diveComputer_list_helpTip1 =>
      '• Ensure your computer is in transfer mode';

  @override
  String get diveComputer_list_helpTip2 =>
      '• Keep devices close during download';

  @override
  String get diveComputer_list_helpTip3 => '• Make sure Bluetooth is enabled';

  @override
  String get diveComputer_list_helpTipsTitle => 'Tips';

  @override
  String get diveComputer_list_helpTooltip => 'Help';

  @override
  String get diveComputer_list_helpUsb => '• USB (desktop only)';

  @override
  String get diveComputer_list_loadFailed => 'Failed to load dive computers';

  @override
  String get diveComputer_list_retry => 'Retry';

  @override
  String get diveComputer_list_title => 'Dive Computers';

  @override
  String get diveComputer_summary_diveComputer => 'dive computer';

  @override
  String diveComputer_summary_divesDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    return '$count $_temp0 downloaded';
  }

  @override
  String get diveComputer_summary_done => 'Done';

  @override
  String get diveComputer_summary_imported => 'Imported';

  @override
  String diveComputer_summary_semanticLabel(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    return '$count $_temp0 downloaded from $name';
  }

  @override
  String get diveComputer_summary_skippedDuplicates => 'Skipped (duplicates)';

  @override
  String get diveComputer_summary_title => 'Download Complete!';

  @override
  String get diveComputer_summary_updated => 'Updated';

  @override
  String get diveComputer_summary_viewDives => 'View Dives';

  @override
  String get diveImport_alreadyImported => 'Already imported';

  @override
  String get diveImport_avgHR => 'Avg HR';

  @override
  String get diveImport_back => 'Back';

  @override
  String get diveImport_deselectAll => 'Deselect All';

  @override
  String get diveImport_divesImported => 'Dives imported';

  @override
  String get diveImport_divesMerged => 'Dives merged';

  @override
  String get diveImport_divesSkipped => 'Dives skipped';

  @override
  String get diveImport_done => 'Done';

  @override
  String get diveImport_duration => 'Duration';

  @override
  String get diveImport_error => 'Error';

  @override
  String get diveImport_fit_closeTooltip => 'Close FIT import';

  @override
  String get diveImport_fit_noDivesDescription =>
      'Select one or more .fit files exported from Garmin Connect or copied from a Garmin Descent device.';

  @override
  String get diveImport_fit_noDivesLoaded => 'No Dives Loaded';

  @override
  String diveImport_fit_parsed(int diveCount, int fileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'files',
      one: 'file',
    );
    return 'Parsed $diveCount $_temp0 from $fileCount $_temp1';
  }

  @override
  String diveImport_fit_parsedWithSkipped(
    int diveCount,
    int fileCount,
    Object skippedCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'files',
      one: 'file',
    );
    return 'Parsed $diveCount $_temp0 from $fileCount $_temp1 ($skippedCount skipped)';
  }

  @override
  String get diveImport_fit_parsing => 'Parsing...';

  @override
  String get diveImport_fit_selectFiles => 'Select FIT Files';

  @override
  String get diveImport_fit_title => 'Import from FIT File';

  @override
  String get diveImport_healthkit_accessDescription =>
      'Submersion needs access to your Apple Watch dive data to import dives.';

  @override
  String get diveImport_healthkit_accessRequired => 'HealthKit Access Required';

  @override
  String get diveImport_healthkit_closeTooltip => 'Close Apple Watch import';

  @override
  String get diveImport_healthkit_dateFrom => 'From';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return '$label date selector';
  }

  @override
  String get diveImport_healthkit_dateTo => 'To';

  @override
  String get diveImport_healthkit_fetchDives => 'Fetch Dives';

  @override
  String get diveImport_healthkit_fetching => 'Fetching...';

  @override
  String get diveImport_healthkit_grantAccess => 'Grant Access';

  @override
  String get diveImport_healthkit_noDivesFound => 'No Dives Found';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'No underwater diving activities found in the selected date range.';

  @override
  String get diveImport_healthkit_notAvailable => 'Not Available';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'Apple Watch import is only available on iOS and macOS devices.';

  @override
  String get diveImport_healthkit_permissionCheckFailed =>
      'Failed to check permissions';

  @override
  String get diveImport_healthkit_title => 'Import from Apple Watch';

  @override
  String get diveImport_healthkit_watchTitle => 'Import from Watch';

  @override
  String get diveImport_import => 'Import';

  @override
  String get diveImport_importComplete => 'Import Complete';

  @override
  String get diveImport_likelyDuplicate => 'Likely duplicate';

  @override
  String get diveImport_maxDepth => 'Max Depth';

  @override
  String get diveImport_newDive => 'New dive';

  @override
  String get diveImport_next => 'Next';

  @override
  String get diveImport_possibleDuplicate => 'Possible duplicate';

  @override
  String get diveImport_reviewSelectedDives => 'Review Selected Dives';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: ', $possibleCount possible duplicates',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: ', $skipCount will be skipped',
      zero: '',
    );
    return '$newCount new$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => 'Select All';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get diveImport_sourceGarmin => 'Garmin';

  @override
  String get diveImport_sourceSuunto => 'Suunto';

  @override
  String get diveImport_sourceUDDF => 'UDDF';

  @override
  String get diveImport_sourceWatch => 'Watch';

  @override
  String get diveImport_step_done => 'Done';

  @override
  String get diveImport_step_review => 'Review';

  @override
  String get diveImport_step_select => 'Select';

  @override
  String get diveImport_temp => 'Temp';

  @override
  String get diveImport_toggleDiveSelection => 'Toggle selection for dive';

  @override
  String get diveImport_uddf_buddies => 'Buddies';

  @override
  String get diveImport_uddf_certifications => 'Certifications';

  @override
  String get diveImport_uddf_closeTooltip => 'Close UDDF import';

  @override
  String get diveImport_uddf_diveCenters => 'Dive Centers';

  @override
  String get diveImport_uddf_diveTypes => 'Dive Types';

  @override
  String get diveImport_uddf_dives => 'Dives';

  @override
  String get diveImport_uddf_duplicate => 'Duplicate';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return '$count duplicates found and auto-deselected.';
  }

  @override
  String get diveImport_uddf_equipment => 'Equipment';

  @override
  String get diveImport_uddf_equipmentSets => 'Equipment Sets';

  @override
  String diveImport_uddf_importProgress(Object current, Object total) {
    return '$current of $total';
  }

  @override
  String get diveImport_uddf_importing => 'Importing...';

  @override
  String get diveImport_uddf_likelyDuplicate => 'Likely duplicate';

  @override
  String get diveImport_uddf_noFileDescription =>
      'Select a .uddf or .xml file exported from another dive log application.';

  @override
  String get diveImport_uddf_noFileSelected => 'No File Selected';

  @override
  String get diveImport_uddf_parsing => 'Parsing...';

  @override
  String get diveImport_uddf_possibleDuplicate => 'Possible duplicate';

  @override
  String get diveImport_uddf_selectFile => 'Select UDDF File';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '$selected of $total selected';
  }

  @override
  String get diveImport_uddf_sites => 'Sites';

  @override
  String get diveImport_uddf_stepImport => 'Import';

  @override
  String get diveImport_uddf_tabBuddies => 'Buddies';

  @override
  String get diveImport_uddf_tabCenters => 'Centers';

  @override
  String get diveImport_uddf_tabCerts => 'Certs';

  @override
  String get diveImport_uddf_tabCourses => 'Courses';

  @override
  String get diveImport_uddf_tabDives => 'Dives';

  @override
  String get diveImport_uddf_tabEquipment => 'Equipment';

  @override
  String get diveImport_uddf_tabSets => 'Sets';

  @override
  String get diveImport_uddf_tabSites => 'Sites';

  @override
  String get diveImport_uddf_tabTags => 'Tags';

  @override
  String get diveImport_uddf_tabTrips => 'Trips';

  @override
  String get diveImport_uddf_tabTypes => 'Types';

  @override
  String get diveImport_uddf_tags => 'Tags';

  @override
  String get diveImport_uddf_title => 'Import from UDDF';

  @override
  String get diveImport_uddf_toggleDiveSelection => 'Toggle selection for dive';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return 'Toggle selection for $name';
  }

  @override
  String get diveImport_uddf_trips => 'Trips';

  @override
  String get divePlanner_segmentEditor_addTitle => 'Add Segment';

  @override
  String divePlanner_segmentEditor_ascentRate(Object unit) {
    return 'Ascent Rate ($unit/min)';
  }

  @override
  String divePlanner_segmentEditor_descentRate(Object unit) {
    return 'Descent Rate ($unit/min)';
  }

  @override
  String get divePlanner_segmentEditor_duration => 'Duration (min)';

  @override
  String get divePlanner_segmentEditor_editTitle => 'Edit Segment';

  @override
  String divePlanner_segmentEditor_endDepth(Object unit) {
    return 'End Depth ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_gasSwitchTime => 'Gas switch time';

  @override
  String get divePlanner_segmentEditor_segmentType => 'Segment Type';

  @override
  String divePlanner_segmentEditor_startDepth(Object unit) {
    return 'Start Depth ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_tankGas => 'Tank / Gas';

  @override
  String get divePlanner_segmentList_addSegment => 'Add Segment';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return 'Ascent $startDepth → $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return 'Bottom $depth for $minutes min';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return 'Deco $depth for $minutes min';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => 'Delete segment';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return 'Descent $startDepth → $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => 'Edit segment';

  @override
  String get divePlanner_segmentList_emptyMessage =>
      'Add segments manually or create a quick plan';

  @override
  String get divePlanner_segmentList_emptyTitle => 'No segments yet';

  @override
  String divePlanner_segmentList_gasSwitch(Object gasName) {
    return 'Gas switch to $gasName';
  }

  @override
  String get divePlanner_segmentList_quickPlan => 'Quick Plan';

  @override
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes) {
    return 'Safety stop $depth for $minutes min';
  }

  @override
  String get divePlanner_segmentList_title => 'Dive Segments';

  @override
  String get divePlanner_segmentType_ascent => 'Ascent';

  @override
  String get divePlanner_segmentType_bottomTime => 'Bottom Time';

  @override
  String get divePlanner_segmentType_decoStop => 'Deco Stop';

  @override
  String get divePlanner_segmentType_descent => 'Descent';

  @override
  String get divePlanner_segmentType_gasSwitch => 'Gas Switch';

  @override
  String get divePlanner_segmentType_safetyStop => 'Safety Stop';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'Rock bottom is the minimum gas reserve for an emergency ascent while sharing air with your buddy.\n\n• Uses stressed SAC rates (2-3x normal)\n• Assumes both divers on one tank\n• Includes safety stop when enabled\n\nAlways turn the dive BEFORE reaching rock bottom!';

  @override
  String get gasCalculators_rockBottom_aboutTitle => 'About Rock Bottom';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired =>
      'Ascent gas required';

  @override
  String get gasCalculators_rockBottom_ascentRate => 'Ascent Rate';

  @override
  String gasCalculators_rockBottom_ascentTimeToDepth(
    Object depth,
    Object unit,
  ) {
    return 'Ascent time to $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_ascentTimeToSurface =>
      'Ascent time to surface';

  @override
  String get gasCalculators_rockBottom_buddySac => 'Buddy SAC';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'Combined stressed SAC';

  @override
  String get gasCalculators_rockBottom_emergencyAscentBreakdown =>
      'Emergency Ascent Breakdown';

  @override
  String get gasCalculators_rockBottom_emergencyScenario =>
      'Emergency Scenario';

  @override
  String get gasCalculators_rockBottom_includeSafetyStop =>
      'Include Safety Stop';

  @override
  String get gasCalculators_rockBottom_maximumDepth => 'Maximum Depth';

  @override
  String get gasCalculators_rockBottom_minimumReserve => 'Minimum Reserve';

  @override
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  ) {
    return 'Minimum reserve: $pressure $pressureUnit, $volume $volumeUnit. Turn the dive when reaching $pressure $pressureUnit remaining';
  }

  @override
  String gasCalculators_rockBottom_safetyStopDuration(
    Object depth,
    Object unit,
  ) {
    return '3 minutes at $depth$unit';
  }

  @override
  String gasCalculators_rockBottom_safetyStopGas(Object depth, Object unit) {
    return 'Safety stop gas (3 min @ $depth$unit)';
  }

  @override
  String get gasCalculators_rockBottom_stressedSacHint =>
      'Use higher SAC rates to account for stress during emergency';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'Stressed SAC Rates';

  @override
  String get gasCalculators_rockBottom_tankSize => 'Tank Size';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded =>
      'Total reserve needed';

  @override
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  ) {
    return 'Turn the dive when reaching $pressure $pressureUnit remaining';
  }

  @override
  String get gasCalculators_rockBottom_yourSac => 'Your SAC';

  @override
  String get maps_heatMap_hide => 'Hide Heat Map';

  @override
  String get maps_heatMap_overlayOff => 'Heat map overlay is off';

  @override
  String get maps_heatMap_overlayOn => 'Heat map overlay is on';

  @override
  String get maps_heatMap_show => 'Show Heat Map';

  @override
  String get maps_offline_bounds => 'Bounds';

  @override
  String maps_offline_cacheHitRateAccessibility(Object rate) {
    return 'Cache hit rate: $rate percent';
  }

  @override
  String get maps_offline_cacheHits => 'Cache Hits';

  @override
  String get maps_offline_cacheMisses => 'Cache Misses';

  @override
  String get maps_offline_cacheStatistics => 'Cache Statistics';

  @override
  String get maps_offline_cancelDownload => 'Cancel Download';

  @override
  String get maps_offline_clearAll => 'Clear All';

  @override
  String get maps_offline_clearAllCache => 'Clear All Cache';

  @override
  String get maps_offline_clearAllCacheMessage =>
      'Delete all downloaded map regions and cached tiles?';

  @override
  String get maps_offline_clearAllCacheTitle => 'Clear All Cache?';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return 'This will delete $count tiles ($size).';
  }

  @override
  String get maps_offline_created => 'Created';

  @override
  String maps_offline_deleteRegion(Object name) {
    return 'Delete $name region';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return 'Delete \"$name\" and its $count cached tiles?\n\nThis will free up $size of storage.';
  }

  @override
  String get maps_offline_deleteRegionTitle => 'Delete Region?';

  @override
  String get maps_offline_downloadedRegions => 'Downloaded Regions';

  @override
  String maps_offline_downloading(Object regionName) {
    return 'Downloading: $regionName';
  }

  @override
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  ) {
    return 'Downloading $regionName, $percent percent complete, $downloaded of $total tiles';
  }

  @override
  String maps_offline_error(Object error) {
    return 'Error: $error';
  }

  @override
  String maps_offline_errorLoadingStats(Object error) {
    return 'Error loading stats: $error';
  }

  @override
  String maps_offline_failedTiles(Object count) {
    return '$count failed';
  }

  @override
  String maps_offline_hitRate(Object rate) {
    return 'Hit Rate: $rate%';
  }

  @override
  String get maps_offline_lastAccessed => 'Last Accessed';

  @override
  String get maps_offline_noRegions => 'No Offline Regions';

  @override
  String get maps_offline_noRegionsDescription =>
      'Download map regions from the site detail page to use maps while offline.';

  @override
  String get maps_offline_refresh => 'Refresh';

  @override
  String get maps_offline_region => 'Region';

  @override
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size | $count tiles | Zoom $minZoom-$maxZoom';
  }

  @override
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size, $count tiles, zoom $minZoom to $maxZoom';
  }

  @override
  String get maps_offline_size => 'Size';

  @override
  String get maps_offline_tiles => 'Tiles';

  @override
  String maps_offline_tilesPerSecond(Object rate) {
    return '$rate tiles/sec';
  }

  @override
  String maps_offline_tilesProgress(Object downloaded, Object total) {
    return '$downloaded / $total tiles';
  }

  @override
  String get maps_offline_title => 'Offline Maps';

  @override
  String get maps_offline_zoomRange => 'Zoom Range';

  @override
  String get maps_regionSelector_dragToAdjust => 'Drag to adjust selection';

  @override
  String get maps_regionSelector_dragToSelect =>
      'Drag on the map to select a region';

  @override
  String get maps_regionSelector_selectRegion => 'Select region on map';

  @override
  String get maps_regionSelector_selectRegionButton => 'Select Region';

  @override
  String get tankPresets_addPreset => 'Add tank preset';

  @override
  String get tankPresets_builtInPresets => 'Built-in Presets';

  @override
  String get tankPresets_customPresets => 'Custom Presets';

  @override
  String tankPresets_deleteMessage(Object name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get tankPresets_deletePreset => 'Delete preset';

  @override
  String get tankPresets_deleteTitle => 'Delete Tank Preset?';

  @override
  String tankPresets_deleted(Object name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get tankPresets_editPreset => 'Edit preset';

  @override
  String tankPresets_edit_created(Object name) {
    return 'Created \"$name\"';
  }

  @override
  String get tankPresets_edit_descriptionHint =>
      'e.g., My rental tank from dive shop';

  @override
  String get tankPresets_edit_descriptionOptional => 'Description (optional)';

  @override
  String tankPresets_edit_errorLoading(Object error) {
    return 'Error loading preset: $error';
  }

  @override
  String tankPresets_edit_errorSaving(Object error) {
    return 'Error saving preset: $error';
  }

  @override
  String tankPresets_edit_gasCapacity(Object capacity) {
    return '• Gas capacity: $capacity cuft';
  }

  @override
  String get tankPresets_edit_material => 'Material';

  @override
  String get tankPresets_edit_name => 'Name';

  @override
  String get tankPresets_edit_nameHelper =>
      'A friendly name for this tank preset';

  @override
  String get tankPresets_edit_nameHint => 'e.g., My AL80';

  @override
  String get tankPresets_edit_nameRequired => 'Please enter a name';

  @override
  String get tankPresets_edit_ratedPressure => 'Rated pressure';

  @override
  String get tankPresets_edit_required => 'Required';

  @override
  String get tankPresets_edit_tankSpecifications => 'Tank Specifications';

  @override
  String get tankPresets_edit_title => 'Edit Tank Preset';

  @override
  String tankPresets_edit_updated(Object name) {
    return 'Updated \"$name\"';
  }

  @override
  String get tankPresets_edit_validPressure => 'Enter a valid pressure';

  @override
  String get tankPresets_edit_validVolume => 'Enter a valid volume';

  @override
  String get tankPresets_edit_volume => 'Volume';

  @override
  String get tankPresets_edit_volumeHelperCuft => 'Gas capacity (cuft)';

  @override
  String get tankPresets_edit_volumeHelperLiters => 'Water volume (L)';

  @override
  String tankPresets_edit_waterVolume(Object volume) {
    return '• Water volume: $volume L';
  }

  @override
  String get tankPresets_edit_workingPressure => 'Working Pressure';

  @override
  String tankPresets_edit_workingPressureBar(Object pressure) {
    return '• Working pressure: $pressure bar';
  }

  @override
  String tankPresets_error(Object error) {
    return 'Error: $error';
  }

  @override
  String tankPresets_errorDeleting(Object error) {
    return 'Error deleting preset: $error';
  }

  @override
  String get tankPresets_new_title => 'New Tank Preset';

  @override
  String get tankPresets_noPresets => 'No tank presets available';

  @override
  String get tankPresets_title => 'Tank Presets';

  @override
  String get tools_deco_description =>
      'Calculate no-decompression limits, required deco stops, and CNS/OTU exposure for multi-level dive profiles.';

  @override
  String get tools_deco_subtitle => 'Plan dives with decompression stops';

  @override
  String get tools_deco_title => 'Deco Calculator';

  @override
  String get tools_disclaimer =>
      'These calculators are for planning purposes only. Always verify calculations and follow your dive training.';

  @override
  String get tools_gas_description =>
      'Four specialized gas calculators:\n• MOD - Maximum operating depth for a gas mix\n• Best Mix - Ideal O₂% for a target depth\n• Consumption - Gas usage estimation\n• Rock Bottom - Emergency reserve calculation';

  @override
  String get tools_gas_subtitle => 'MOD, Best Mix, Consumption, Rock Bottom';

  @override
  String get tools_gas_title => 'Gas Calculators';

  @override
  String get tools_title => 'Tools';

  @override
  String get tools_weight_aluminumImperial =>
      'More buoyant when empty (+4 lbs)';

  @override
  String get tools_weight_aluminumMetric => 'More buoyant when empty (+2 kg)';

  @override
  String get tools_weight_bodyWeightOptional => 'Body Weight (optional)';

  @override
  String get tools_weight_carbonFiberImperial => 'Very buoyant (+7 lbs)';

  @override
  String get tools_weight_carbonFiberMetric => 'Very buoyant (+3 kg)';

  @override
  String get tools_weight_description =>
      'Estimate the weight you need based on your exposure suit, tank material, water type, and body weight.';

  @override
  String get tools_weight_disclaimer =>
      'This is an estimate only. Always perform a buoyancy check at the start of your dive and adjust as needed. Factors like BCD, personal buoyancy, and breathing patterns will affect your actual weight requirements.';

  @override
  String get tools_weight_exposureSuit => 'Exposure Suit';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return '• Gas capacity: $capacity cuft';
  }

  @override
  String get tools_weight_helperImperial =>
      'Adds ~2 lbs per 22 lbs over 154 lbs';

  @override
  String get tools_weight_helperMetric => 'Adds ~1 kg per 10 kg over 70 kg';

  @override
  String get tools_weight_notSpecified => 'Not specified';

  @override
  String get tools_weight_recommendedWeight => 'Recommended Weight';

  @override
  String tools_weight_resultAccessibility(Object weight, Object unit) {
    return 'Recommended weight: $weight $unit';
  }

  @override
  String get tools_weight_steelImperial => 'Negatively buoyant (-4 lbs)';

  @override
  String get tools_weight_steelMetric => 'Negatively buoyant (-2 kg)';

  @override
  String get tools_weight_subtitle => 'Recommended weight for your setup';

  @override
  String get tools_weight_tankMaterial => 'Tank Material';

  @override
  String get tools_weight_tankSpecifications => 'Tank Specifications';

  @override
  String get tools_weight_title => 'Weight Calculator';

  @override
  String get tools_weight_waterType => 'Water Type';

  @override
  String tools_weight_waterVolume(Object volume) {
    return '• Water volume: $volume L';
  }

  @override
  String tools_weight_workingPressure(Object pressure) {
    return '• Working pressure: $pressure bar';
  }

  @override
  String get tools_weight_yourWeight => 'Your weight';
}
