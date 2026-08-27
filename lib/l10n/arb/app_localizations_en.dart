// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get universalImport_action_importFromGarmin =>
      'Import from Garmin Device';

  @override
  String diveLog_edit_flightWindowWarning(String time) {
    return 'This dive ends after the latest safe surfacing time for your flight ($time)';
  }

  @override
  String diveLog_edit_geofenceSuggestion_near(String location) {
    return 'Near $location';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_title => 'Equipment suggestion';

  @override
  String diveLog_edit_geofenceSuggestion_body(String setName) {
    return 'Apply your \"$setName\" set?';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_apply => 'Apply';

  @override
  String get common_action_dismiss => 'Dismiss';

  @override
  String get equipment_setEdit_defaultSwitch_title => 'Default set';

  @override
  String get equipment_setEdit_defaultSwitch_subtitle =>
      'Auto-applied to new dives that have no equipment yet';

  @override
  String get equipment_setEdit_geofencesTitle => 'Geofences';

  @override
  String get equipment_setEdit_geofencesSubtitle =>
      'Auto-suggest this set for dives near these locations';

  @override
  String get equipment_setEdit_addGeofence => 'Add geofence';

  @override
  String get equipment_setEdit_editGeofence => 'Edit geofence';

  @override
  String get equipment_setEdit_removeGeofence => 'Remove geofence';

  @override
  String equipment_setEdit_geofenceRadius(String distance) {
    return 'Radius: $distance';
  }

  @override
  String get equipment_geofenceEditor_title => 'Geofence';

  @override
  String get equipment_geofenceEditor_fromSite => 'From dive site';

  @override
  String get equipment_geofenceEditor_dropPin => 'Drop a pin';

  @override
  String get equipment_geofenceEditor_labelLabel => 'Label';

  @override
  String get equipment_geofenceEditor_noCenter => 'Choose a center point';

  @override
  String get equipment_geofenceEditor_save => 'Save geofence';

  @override
  String get equipment_sets_defaultBadge => 'Default';

  @override
  String get equipment_setDetail_setAsDefault => 'Set as default';

  @override
  String equipment_setDetail_setAsDefaultSnackbar(String name) {
    return '\"$name\" is now your default set';
  }

  @override
  String get equipment_setDetail_geofencesTitle => 'Geofences';

  @override
  String get equipment_setDetail_noGeofences => 'No geofences';

  @override
  String formatter_duration_minutes(Object minutes) {
    return '${minutes}m';
  }

  @override
  String formatter_duration_minutesSeconds(Object minutes, Object seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String formatter_duration_seconds(Object seconds) {
    return '${seconds}s';
  }

  @override
  String gasCalculators_bestMix_densityCritical(Object limit) {
    return 'Above the $limit g/L hard density ceiling.';
  }

  @override
  String get gasCalculators_bestMix_densityLabel => 'Gas density at depth';

  @override
  String gasCalculators_bestMix_densityWarn(Object limit) {
    return 'Above the recommended $limit g/L density limit.';
  }

  @override
  String gasCalculators_bestMix_endExceeded(Object limit) {
    return 'END exceeds your $limit limit.';
  }

  @override
  String get gasCalculators_bestMix_endLabel => 'END at depth';

  @override
  String get gasCalculators_bestMix_endLimitLabel => 'END limit';

  @override
  String gasCalculators_bestMix_heliumAdded(Object limit) {
    return 'Helium added to keep END within your $limit limit.';
  }

  @override
  String get gasCalculators_bestMix_idealLabel => 'Ideal fraction';

  @override
  String get gasCalculators_bestMix_marginLabel => 'Margin below MOD';

  @override
  String gasCalculators_bestMix_modLabel(Object ppO2) {
    return 'MOD at ppO2 $ppO2';
  }

  @override
  String get gasCalculators_bestMix_nearestStandard =>
      'Nearest standard mix covering this depth';

  @override
  String get gasCalculators_bestMix_recommendedMix => 'Recommended mix';

  @override
  String get gasCalculators_bestMix_withoutHelium => 'Without helium';

  @override
  String get gasCalculators_planningCaveat =>
      'Planning estimate. Assumes a direct ascent. Verify against your training and add margin for conditions.';

  @override
  String gasCalculators_rockBottom_solveGas(Object depth, Object unit) {
    return 'Problem-solving gas at $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_solveTime => 'Problem-solving time';

  @override
  String get gasCalculators_rockBottom_solveTimeHint =>
      'Time spent at depth resolving the emergency before starting the ascent.';

  @override
  String o2Toxicity_addedThisDive(Object value) {
    return '+$value this dive';
  }

  @override
  String o2Toxicity_cnsProgressSemantics(Object percent) {
    return 'CNS progress $percent percent';
  }

  @override
  String get o2Toxicity_daily => 'Daily';

  @override
  String o2Toxicity_otuSemantics(
    Object label,
    Object value,
    Object limit,
    Object percent,
  ) {
    return '$label: $value of $limit OTU, $percent percent';
  }

  @override
  String o2Toxicity_otuValueSemantics(Object label, Object value) {
    return '$label: $value OTU';
  }

  @override
  String o2Toxicity_prior(Object value) {
    return 'Prior: $value OTU';
  }

  @override
  String o2Toxicity_start(Object value) {
    return 'Start: $value OTU';
  }

  @override
  String get o2Toxicity_thisDive => 'This Dive';

  @override
  String get o2Toxicity_weekly => 'Weekly';

  @override
  String trips_story_dayLabel(int number) {
    return 'Day $number';
  }

  @override
  String get trips_story_surfaceDay => 'Surface day';

  @override
  String get trips_story_today => 'Today';

  @override
  String trips_story_dayOfTrip(int current, int total) {
    return 'Day $current of $total';
  }

  @override
  String trips_story_daysUntil(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days until departure',
      one: '1 day until departure',
    );
    return '$_temp0';
  }

  @override
  String trips_story_checklistProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get trips_story_generateItinerary => 'Generate itinerary';

  @override
  String get trips_story_openGallery => 'Open trip photos';

  @override
  String trips_story_generateItineraryError(String error) {
    return 'Couldn\'t generate itinerary: $error';
  }

  @override
  String get trips_dayType_diveDay => 'Dive Day';

  @override
  String get trips_dayType_seaDay => 'Sea Day';

  @override
  String get trips_dayType_portDay => 'Port Day';

  @override
  String get trips_dayType_embark => 'Embark';

  @override
  String get trips_dayType_disembark => 'Disembark';

  @override
  String get trips_story_planned => 'Planned';

  @override
  String get trips_story_empty_title => 'No dives or itinerary yet';

  @override
  String get trips_story_empty_subtitle =>
      'Add dives to this trip or plan its days to see the story.';

  @override
  String trips_story_history_dives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count past dives here',
      one: '1 past dive here',
    );
    return '$_temp0';
  }

  @override
  String trips_story_history_avgTemp(String value) {
    return 'avg $value';
  }

  @override
  String trips_story_history_avgDepth(String value) {
    return 'avg depth $value';
  }

  @override
  String get trips_story_rhythm_semantics => 'Dive times during this day';

  @override
  String get trips_story_map_semantics =>
      'Trip map. Sites for the day in view are highlighted.';

  @override
  String get diveLog_bulkEdit_groupRebreather => 'Dive Mode & Rebreather';

  @override
  String get diveLog_bulkEdit_fieldSetpointLow => 'Setpoint low';

  @override
  String get diveLog_bulkEdit_fieldSetpointHigh => 'Setpoint high';

  @override
  String get diveLog_bulkEdit_fieldSetpointDeco => 'Setpoint deco';

  @override
  String get diveLog_bulkEdit_fieldScrubberType => 'Scrubber type';

  @override
  String get diveLog_bulkEdit_fieldScrubberDuration => 'Scrubber duration';

  @override
  String get diveLog_bulkEdit_contradiction =>
      'OC mode can\'t carry rebreather settings. Turn off those fields or change the mode.';

  @override
  String diveLog_bulkEdit_appBarTitle(int count) {
    return 'Edit $count dives';
  }

  @override
  String get diveLog_bulkEdit_groupLogistics => 'Logistics';

  @override
  String get diveLog_bulkEdit_groupWeather => 'Weather';

  @override
  String get diveLog_bulkEdit_groupCollections => 'Tags, Gear & Life';

  @override
  String get diveLog_bulkEdit_fieldFavorite => 'Favorite';

  @override
  String get diveLog_bulkEdit_fieldMyRole => 'My role';

  @override
  String get diveLog_bulkEdit_buddyRoleMixed => 'Mixed';

  @override
  String get diveLog_bulkEdit_collectionWeights => 'Weights';

  @override
  String get diveLog_bulkEdit_collectionTanks => 'Tanks';

  @override
  String get diveLog_bulkEdit_notesSet => 'Set';

  @override
  String get diveLog_bulkEdit_notesAppend => 'Append';

  @override
  String get diveLog_bulkEdit_modeAdd => 'Add';

  @override
  String get diveLog_bulkEdit_modeRemove => 'Remove';

  @override
  String get diveLog_bulkEdit_modeReplace => 'Replace';

  @override
  String get diveLog_bulkEdit_modeUpdate => 'Update';

  @override
  String get diveLog_bulkEdit_tankOnlyIfEmpty =>
      'Only dives that don\'t already have a tank';

  @override
  String get diveLog_bulkEdit_tankSpecsHint =>
      'Choose which attributes to overwrite on the tanks these dives already have. Start and end pressures are never changed.';

  @override
  String get diveLog_bulkEdit_tankSpecsNoFields =>
      'Choose at least one tank attribute to update.';

  @override
  String get diveLog_bulkEdit_tankFieldPreset => 'Preset';

  @override
  String get diveLog_bulkEdit_tankFieldRole => 'Role';

  @override
  String get diveLog_bulkEdit_tankFieldVolume => 'Volume';

  @override
  String get diveLog_bulkEdit_tankFieldWorkingPressure => 'Working pressure';

  @override
  String get diveLog_bulkEdit_tankFieldMaterial => 'Material';

  @override
  String get diveLog_bulkEdit_tankFieldGasMix => 'Gas mix';

  @override
  String get diveLog_bulkEdit_tankFieldName => 'Name';

  @override
  String diveLog_bulkEdit_tankSpecsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected dives have no tanks and will be skipped.',
      one: '1 selected dive has no tanks and will be skipped.',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_bulkEdit_confirmTitle => 'Apply changes?';

  @override
  String get diveLog_bulkEdit_confirmApply => 'Apply';

  @override
  String get diveLog_bulkEdit_nothingSelected =>
      'Turn on at least one field to apply changes.';

  @override
  String diveLog_bulkEdit_applied(int count) {
    return 'Updated $count dives';
  }

  @override
  String get settings_cloudSync_error_icloudSignedOut =>
      'iCloud is not available. Please sign in to iCloud in your device settings.';

  @override
  String get settings_cloudSync_error_icloudUnknown =>
      'Couldn\'t reach iCloud. Please try again.';

  @override
  String get settings_cloudSync_error_icloudUnsupported =>
      'iCloud sync isn\'t available in this build of Submersion. Use S3 sync, or the App Store version.';

  @override
  String get settings_cloudSync_provider_icloud_unsupportedSubtitle =>
      'Not available in this build — use S3 or the App Store version';

  @override
  String get settings_cloudSync_encryption_title => 'End-to-end encryption';

  @override
  String get settings_cloudSync_encryption_subtitleOff =>
      'Encrypt all sync data and cloud backups before upload';

  @override
  String get settings_cloudSync_encryption_subtitleNeedsProvider =>
      'Select a cloud provider first';

  @override
  String get settings_cloudSync_encryption_statusOff => 'Encryption is off';

  @override
  String get settings_cloudSync_encryption_statusOn => 'Encryption is on';

  @override
  String get settings_cloudSync_encryption_statusOnSubtitle =>
      'Sync data and cloud backups are encrypted before upload';

  @override
  String get settings_cloudSync_encryption_statusLocked =>
      'Encrypted — passphrase needed';

  @override
  String get settings_cloudSync_encryption_statusLockedSubtitle =>
      'Enter the passphrase to sync on this device';

  @override
  String get settings_cloudSync_encryption_enable => 'Enable encryption';

  @override
  String get settings_cloudSync_encryption_enterPassphrase =>
      'Enter passphrase';

  @override
  String get settings_cloudSync_encryption_passphrase => 'Passphrase';

  @override
  String get settings_cloudSync_encryption_passphraseConfirm =>
      'Confirm passphrase';

  @override
  String get settings_cloudSync_encryption_passphraseMismatch =>
      'Passphrases do not match';

  @override
  String get settings_cloudSync_encryption_passphraseTooShort =>
      'Use at least 8 characters';

  @override
  String get settings_cloudSync_encryption_wrongPassphrase =>
      'Incorrect passphrase or recovery code';

  @override
  String get settings_cloudSync_encryption_warnUpdateDevices =>
      'All other devices must be updated to the latest app version and will re-download the library.';

  @override
  String get settings_cloudSync_encryption_warnLoss =>
      'If you lose both the passphrase and the recovery code, data in the cloud cannot be recovered. Data on your devices is never at risk.';

  @override
  String get settings_cloudSync_encryption_deletePlaintextBackups =>
      'Delete existing unencrypted cloud backups';

  @override
  String get settings_cloudSync_encryption_recoveryTitle => 'Recovery code';

  @override
  String get settings_cloudSync_encryption_recoveryExplain =>
      'Write this code down and keep it somewhere safe. It is the only way back in if you forget your passphrase.';

  @override
  String get settings_cloudSync_encryption_recoverySavedConfirm =>
      'I have saved my recovery code';

  @override
  String get settings_cloudSync_encryption_changePassphrase =>
      'Change passphrase';

  @override
  String get settings_cloudSync_encryption_currentPassphrase =>
      'Current passphrase';

  @override
  String get settings_cloudSync_encryption_newPassphrase => 'New passphrase';

  @override
  String get settings_cloudSync_encryption_regenerateRecovery =>
      'Generate new recovery code';

  @override
  String get settings_cloudSync_encryption_regenerateRecoveryWarn =>
      'The old recovery code stops working immediately.';

  @override
  String get settings_cloudSync_encryption_disable => 'Turn off encryption';

  @override
  String get settings_cloudSync_encryption_disableWarn =>
      'The library will be re-uploaded unencrypted, and other devices will re-download it. Existing encrypted backups stay restorable with the passphrase.';

  @override
  String get settings_cloudSync_encryption_unlockTitle =>
      'Enter your encryption passphrase';

  @override
  String get settings_cloudSync_encryption_unlockHint =>
      'Passphrase or recovery code';

  @override
  String get settings_cloudSync_encryption_unlock => 'Unlock';

  @override
  String get settings_cloudSync_encryption_continue => 'Continue';

  @override
  String get settings_cloudSync_encryption_done => 'Done';

  @override
  String get settings_cloudSync_encryption_cancel => 'Cancel';

  @override
  String get settings_backupEncryption_title => 'Backup encryption';

  @override
  String get settings_backupEncryption_subtitleOff =>
      'Protect your backups with a password';

  @override
  String get settings_backupEncryption_subtitleOn =>
      'Backups are encrypted with your password';

  @override
  String get settings_backupEncryption_enable => 'Encrypt backups';

  @override
  String get settings_backupEncryption_turnOff => 'Turn off encryption';

  @override
  String get settings_backupEncryption_turnOffTitle =>
      'Turn off backup encryption?';

  @override
  String get settings_backupEncryption_turnOffBody =>
      'New backups will no longer be encrypted. Existing encrypted backups still need your password to restore.';

  @override
  String get settings_backupEncryption_changePassword => 'Change password';

  @override
  String get settings_backupEncryption_regenerateRecovery =>
      'Regenerate recovery code';

  @override
  String get settings_backupEncryption_password => 'Password';

  @override
  String get settings_backupEncryption_passwordConfirm => 'Confirm password';

  @override
  String get settings_backupEncryption_passwordTooShort =>
      'Use at least 8 characters';

  @override
  String get settings_backupEncryption_passwordMismatch =>
      'Passwords do not match';

  @override
  String get settings_backupEncryption_currentPassword => 'Current password';

  @override
  String get settings_backupEncryption_newPassword => 'New password';

  @override
  String get settings_backupEncryption_changePasswordWarn =>
      'On another device, each backup opens with the password or recovery code that was active when it was created.';

  @override
  String get settings_backupEncryption_warnLoss =>
      'If you forget your password and lose the recovery code, encrypted backups cannot be recovered.';

  @override
  String get settings_backupEncryption_recoveryTitle => 'Your recovery code';

  @override
  String get settings_backupEncryption_recoveryExplain =>
      'Save this code somewhere safe. It can unlock your backups if you forget your password.';

  @override
  String get settings_backupEncryption_recoverySavedConfirm =>
      'I have saved my recovery code';

  @override
  String get settings_backupEncryption_unlockTitle => 'Enter backup password';

  @override
  String get settings_backupEncryption_unlockHint =>
      'Enter your backup password or recovery code';

  @override
  String get settings_backupEncryption_restoreUnlockTitle =>
      'Unlock encrypted backup';

  @override
  String get settings_backupEncryption_restoreUnlockHint =>
      'Enter the password or recovery code for this backup';

  @override
  String get settings_backupEncryption_continue => 'Continue';

  @override
  String get settings_backupEncryption_cancel => 'Cancel';

  @override
  String get settings_backupEncryption_done => 'Done';

  @override
  String get settings_backupEncryption_reencryptTitle =>
      'Encrypt existing backups?';

  @override
  String get settings_backupEncryption_reencryptBody =>
      'Your existing backups are still unencrypted. Re-encrypt them now with your new password?';

  @override
  String get settings_backupEncryption_reencryptNow => 'Re-encrypt now';

  @override
  String get settings_backupEncryption_reencryptNotNow => 'Not now';

  @override
  String settings_backupEncryption_reencryptPartial(int done, int failed) {
    return 'Re-encrypted $done backups; $failed could not be encrypted and are still unprotected';
  }

  @override
  String settings_backupEncryption_reencryptDone(int count) {
    return 'Re-encrypted $count backups';
  }

  @override
  String get settings_backupEncryption_wrongPassword =>
      'Incorrect password or recovery code';

  @override
  String settings_cloudSync_replace_globalBanner(String deviceName) {
    return 'Sync is paused — the library was replaced from a backup on \"$deviceName\".';
  }

  @override
  String get settings_cloudSync_postRestore_syncing =>
      'Syncing your restored library with the cloud…';

  @override
  String get settings_cloudSync_postRestore_synced =>
      'Restored library synced.';

  @override
  String get settings_cloudSync_replace_reviewAction => 'Review';

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
  String get accessibility_label_resizeMasterPane => 'Resize master pane';

  @override
  String get accessibility_label_sharedWithAllProfiles =>
      'Shared with all dive profiles';

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
  String get backup_export_bottomSheet_title => 'Export Backup';

  @override
  String get backup_export_saveToFile => 'Save to File';

  @override
  String get backup_export_saveToFile_subtitle =>
      'Choose where to save the backup file';

  @override
  String get backup_export_share => 'Share';

  @override
  String get backup_export_share_subtitle =>
      'Send via AirDrop, email, or other apps';

  @override
  String get backup_export_subtitle => 'Save your dive data to a file';

  @override
  String get backup_export_success => 'Backup exported successfully';

  @override
  String get backup_export_title => 'Export Backup';

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
  String get backup_history_pinAction_pin => 'Pin backup';

  @override
  String get backup_history_pinAction_unpin => 'Unpin backup';

  @override
  String get backup_history_pinError => 'Could not update pin state.';

  @override
  String backup_history_preMigrationSubtitle(String size) {
    return 'Pre-migration backup - $size';
  }

  @override
  String get backup_import_invalidFile =>
      'This file does not appear to be a valid Submersion backup';

  @override
  String get backup_import_subtitle => 'Import a backup from any location';

  @override
  String get backup_import_title => 'Restore from File';

  @override
  String get backup_import_validating => 'Validating backup file...';

  @override
  String get backup_location_change => 'Change';

  @override
  String get backup_location_default => 'Default location';

  @override
  String get backup_location_title => 'Backup Location';

  @override
  String get backup_replaceConfirm_confirm => 'Replace Everywhere';

  @override
  String get backup_replaceConfirm_content =>
      'The library on all synced devices will be replaced with this backup. Each device creates a safety backup of its current data first. This cannot be undone.';

  @override
  String get backup_replaceConfirm_title => 'Replace Library Everywhere?';

  @override
  String get backup_restore_dialog_cancel => 'Cancel';

  @override
  String get backup_restore_dialog_modeMerge_subtitle =>
      'Restore to this device. Your next sync combines the restored data with the cloud library.';

  @override
  String get backup_restore_dialog_modeMerge_title => 'Merge on next sync';

  @override
  String get backup_restore_dialog_modeReplace_subtitle =>
      'The backup becomes the library on this device, in the cloud, and on every synced device.';

  @override
  String get backup_restore_dialog_modeReplace_title => 'Replace everywhere';

  @override
  String get backup_restore_dialog_restore => 'Restore';

  @override
  String get backup_restore_dialog_restoreReplace =>
      'Restore and Replace Everywhere';

  @override
  String get backup_restore_dialog_safetyNote =>
      'A safety backup of your current data will be created automatically before restoring.';

  @override
  String get backup_restore_dialog_title => 'Restore Backup';

  @override
  String get backup_restore_dialog_warning =>
      'This will replace ALL current data with the backup data. This action cannot be undone.';

  @override
  String backup_restore_safetyReview_progress(int done, int total) {
    return 'Analyzed $done of $total dives';
  }

  @override
  String get backup_restore_safetyReview_skip => 'Skip';

  @override
  String get backup_restore_safetyReview_title => 'Running the safety review';

  @override
  String get backup_restoreComplete_continue => 'Continue';

  @override
  String get backup_restoreComplete_description =>
      'Your data has been restored successfully. Tap continue to reload the app with your restored data.';

  @override
  String get backup_restoreComplete_title => 'Restore Complete';

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
  String get backup_section_auto => 'Automatic Backups';

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
  String get buddies_action_addCertification => 'Add certification';

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
  String get buddies_picker_addCustomRole => 'Add custom role...';

  @override
  String get buddies_picker_addNew => 'Add New Buddy';

  @override
  String get buddies_picker_done => 'Done';

  @override
  String get buddies_picker_me => 'Me';

  @override
  String get buddies_picker_noBuddiesFound => 'No buddies found';

  @override
  String get buddies_picker_noBuddiesYet => 'No buddies yet';

  @override
  String get buddies_picker_noRole => 'No role';

  @override
  String get buddies_picker_noneSelected => 'No buddies selected';

  @override
  String get buddies_picker_searchHint => 'Search buddies...';

  @override
  String get buddies_picker_selectBuddies => 'Select Buddies';

  @override
  String get buddies_picker_selectMyRole => 'Select my role';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Select Role for $name';
  }

  @override
  String get buddies_picker_setMyRole => 'Set my role';

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
  String get buddies_section_certifications => 'Certifications';

  @override
  String get buddies_certifications_empty => 'No certifications';

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
  String get buddies_list_selection_closeTooltip => 'Close Selection';

  @override
  String buddies_list_selection_count(int count) {
    return '$count selected';
  }

  @override
  String get buddies_list_selection_selectAllTooltip => 'Select All';

  @override
  String get buddies_list_selection_deselectAllTooltip => 'Deselect All';

  @override
  String get buddies_list_selection_mergeTooltip => 'Merge Selected';

  @override
  String get buddies_list_selection_deleteTooltip => 'Delete Selected';

  @override
  String buddies_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'buddies',
      one: 'buddy',
    );
    return 'Merged $count $_temp0';
  }

  @override
  String get buddies_list_merge_undo => 'Undo';

  @override
  String get buddies_list_merge_restored => 'Merge undone';

  @override
  String get buddies_list_bulkDelete_title => 'Delete Buddies';

  @override
  String buddies_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'buddies',
      one: 'buddy',
    );
    return 'Are you sure you want to delete $count $_temp0? This action cannot be undone.';
  }

  @override
  String get buddies_list_bulkDelete_cancel => 'Cancel';

  @override
  String get buddies_list_bulkDelete_confirm => 'Delete';

  @override
  String buddies_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'buddies',
      one: 'buddy',
    );
    return 'Deleted $count $_temp0';
  }

  @override
  String get buddies_edit_merge_title => 'Merge Buddies';

  @override
  String get buddies_edit_merge_fieldSourceCycleTooltip =>
      'Use value from next selected buddy';

  @override
  String buddies_edit_merge_fieldSourceLabel(
    String buddyName,
    int current,
    int total,
  ) {
    return 'From $buddyName ($current/$total)';
  }

  @override
  String get buddies_edit_merge_confirmTitle => 'Merge Buddies';

  @override
  String buddies_edit_merge_confirmBody(int count) {
    return 'This will merge $count buddies into one. Dive associations will be combined under the surviving buddy. The other buddies will be deleted.';
  }

  @override
  String get buddies_edit_merge_loadingErrorTitle => 'Merge Buddies';

  @override
  String buddies_edit_merge_loadingErrorBody(String error) {
    return 'Failed to load buddies: $error';
  }

  @override
  String get buddies_edit_merge_notEnoughTitle => 'Merge Buddies';

  @override
  String get buddies_edit_merge_notEnoughBody => 'Not enough buddies to merge.';

  @override
  String get buddies_instructorPicker_label => 'Instructor from buddies';

  @override
  String get buddies_instructorPicker_none => 'None (manual entry)';

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
  String get certifications_detail_label_certification => 'Certification';

  @override
  String get certifications_detail_label_expiryDate => 'Expiry Date';

  @override
  String get certifications_detail_label_instructorName => 'Name';

  @override
  String get certifications_detail_label_instructorNumber => 'Instructor #';

  @override
  String get certifications_detail_label_issueDate => 'Issue Date';

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
  String get certifications_ecard_label_cardNumber => 'CARD NO.';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Certified by $agency';
  }

  @override
  String get certifications_ecard_label_diver => 'DIVER';

  @override
  String get certifications_ecard_label_instructor => 'INSTRUCTOR';

  @override
  String get certifications_ecard_label_issued => 'ISSUED';

  @override
  String get certifications_ecard_label_validUntil => 'VALID UNTIL';

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
  String get certifications_edit_certification_notSpecified => 'Not specified';

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
  String get certifications_edit_group_progression => 'Progression';

  @override
  String get certifications_edit_group_specialties => 'Specialties';

  @override
  String get certifications_edit_help_expiryDate =>
      'Leave empty for certifications that don\'t expire';

  @override
  String get certifications_edit_helper_nameOnCard => 'Optional';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Enter certification card number';

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
  String get certifications_edit_label_certification => 'Certification';

  @override
  String get certifications_edit_label_expiryDate => 'Expiry Date';

  @override
  String get certifications_edit_label_instructorName => 'Instructor Name';

  @override
  String get certifications_edit_label_instructorNumber => 'Instructor Number';

  @override
  String get certifications_edit_label_issueDate => 'Issue Date';

  @override
  String get certifications_edit_label_nameOnCard => 'Name on card';

  @override
  String get certifications_edit_label_notes => 'Notes';

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
  String get certifications_edit_validation_certificationOrNameRequired =>
      'Choose a certification or enter a name';

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
  String get checklists_section_title => 'Checklist';

  @override
  String checklists_progress(int done, int total) {
    return '$done of $total to-dos done';
  }

  @override
  String get checklists_empty_upcoming =>
      'Plan your trip - add to-dos or apply a template';

  @override
  String get checklists_empty_past => 'No checklist items';

  @override
  String get checklists_addItem => 'Add item';

  @override
  String get checklists_item_titleLabel => 'Title';

  @override
  String get checklists_item_titleRequired => 'Title is required';

  @override
  String get checklists_item_categoryLabel => 'Category';

  @override
  String get checklists_item_notesLabel => 'Notes';

  @override
  String get checklists_item_dueDateLabel => 'Due date';

  @override
  String get checklists_item_dueOffsetLabel => 'Days before trip start';

  @override
  String get checklists_item_dueOffsetInvalid => 'Enter 0 or more days';

  @override
  String get checklists_item_overdue => 'Overdue';

  @override
  String get checklists_item_edit => 'Edit item';

  @override
  String get checklists_item_delete => 'Delete item';

  @override
  String get checklists_menu_applyTemplate => 'Apply template...';

  @override
  String get checklists_menu_saveAsTemplate => 'Save as template...';

  @override
  String get checklists_applySheet_title => 'Apply template';

  @override
  String get checklists_applySheet_empty =>
      'No templates yet. Create them in Settings.';

  @override
  String checklists_applySheet_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String checklists_applySheet_confirmAppend(int added, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added items will be added',
      one: '1 item will be added',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped duplicates skipped',
      one: '1 duplicate skipped',
      zero: 'no duplicates skipped',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String checklists_apply_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items added',
      one: '1 item added',
      zero: 'No new items added',
    );
    return '$_temp0';
  }

  @override
  String get checklists_apply_templateGone => 'Template no longer exists';

  @override
  String get checklists_saveTemplate_title => 'Save as template';

  @override
  String get checklists_saveTemplate_nameLabel => 'Template name';

  @override
  String get checklists_saveTemplate_success => 'Template saved';

  @override
  String get checklists_templates_pageTitle => 'Checklist Templates';

  @override
  String get checklists_templates_addTemplate => 'Add Template';

  @override
  String get checklists_templates_empty => 'No templates yet';

  @override
  String get checklists_templates_deleteTitle => 'Delete Template';

  @override
  String checklists_templates_deleteContent(Object name) {
    return 'Delete \"$name\"? Trips that already applied it keep their items.';
  }

  @override
  String get checklists_template_nameLabel => 'Name';

  @override
  String get checklists_template_nameRequired => 'Name is required';

  @override
  String get checklists_template_descriptionLabel => 'Description';

  @override
  String get checklists_template_itemsHeader => 'Items';

  @override
  String get checklists_template_addItem => 'Add item';

  @override
  String get preDive_templates_title => 'Pre-Dive Checklists';

  @override
  String get preDive_templates_empty => 'No pre-dive checklists yet';

  @override
  String get preDive_templates_builtInBadge => 'Built-in';

  @override
  String get preDive_templates_clone => 'Clone';

  @override
  String get preDive_templates_cloneSuffix => ' (copy)';

  @override
  String get preDive_templates_delete => 'Delete';

  @override
  String get preDive_templates_deleteConfirm =>
      'Delete this checklist template?';

  @override
  String get preDive_templates_strictOrderBadge => 'Strict order';

  @override
  String get preDive_edit_titleNew => 'New Pre-Dive Checklist';

  @override
  String get preDive_edit_titleEdit => 'Edit Pre-Dive Checklist';

  @override
  String get preDive_edit_name => 'Name';

  @override
  String get preDive_edit_description => 'Description';

  @override
  String get preDive_edit_category => 'Category';

  @override
  String get preDive_edit_strictOrder => 'Strict order';

  @override
  String get preDive_edit_strictOrderHelp =>
      'Items must be completed top to bottom';

  @override
  String get preDive_edit_addItem => 'Add item';

  @override
  String get preDive_edit_nameRequired => 'Enter a name';

  @override
  String get preDive_item_title => 'Title';

  @override
  String get preDive_item_section => 'Section';

  @override
  String get preDive_item_notes => 'Notes';

  @override
  String get preDive_item_required => 'Required';

  @override
  String get preDive_item_type_check => 'Checkbox';

  @override
  String get preDive_item_type_value => 'Recorded value';

  @override
  String get preDive_item_type_equipmentSet => 'Equipment set items';

  @override
  String get preDive_item_valueLabel => 'Value label';

  @override
  String get preDive_item_valueUnit => 'Unit';

  @override
  String get preDive_item_valueMin => 'Min (warning)';

  @override
  String get preDive_item_valueMax => 'Max (warning)';

  @override
  String preDive_runner_progress(int done, int total) {
    return '$done of $total';
  }

  @override
  String get preDive_runner_complete => 'Complete';

  @override
  String preDive_runner_completeFlagged(int count) {
    return 'Complete with $count flagged items?';
  }

  @override
  String get preDive_runner_abort => 'Abort checklist';

  @override
  String get preDive_runner_abortConfirm =>
      'Abort this checklist? It will be kept in history as aborted.';

  @override
  String get preDive_runner_skip => 'Skip';

  @override
  String get preDive_runner_flag => 'Flag';

  @override
  String get preDive_runner_undo => 'Reset to pending';

  @override
  String get preDive_runner_serviceOverdue => 'Service overdue';

  @override
  String get preDive_runner_addNote => 'Add note';

  @override
  String get preDive_runner_enterValue => 'Enter value';

  @override
  String preDive_runner_flaggedBadge(int count) {
    return '$count flagged';
  }

  @override
  String get preDive_runner_locked => 'This checklist is locked';

  @override
  String get preDive_sessions_title => 'Pre-Dive Checklists';

  @override
  String get preDive_sessions_empty => 'No checklist runs yet';

  @override
  String get preDive_sessions_resume => 'Resume';

  @override
  String get preDive_sessions_start => 'Start checklist';

  @override
  String get preDive_sessions_statusCompleted => 'Completed';

  @override
  String get preDive_sessions_statusAborted => 'Aborted';

  @override
  String get preDive_sessions_statusInProgress => 'In progress';

  @override
  String get preDive_sessions_linkedDive => 'Linked dive';

  @override
  String get preDive_link_linkToDive => 'Link to dive';

  @override
  String get preDive_link_unlinkDive => 'Unlink dive';

  @override
  String get preDive_link_linkChecklist => 'Link pre-dive checklist';

  @override
  String get preDive_link_unlinkChecklist => 'Unlink pre-dive checklist';

  @override
  String get preDive_link_searchDives => 'Search dives';

  @override
  String get preDive_link_noDives => 'No dives to link to';

  @override
  String preDive_link_noDivesMatch(String query) {
    return 'No dives match \"$query\"';
  }

  @override
  String get preDive_link_noUnlinkedSessions => 'No unlinked checklist runs';

  @override
  String get preDive_link_linked => 'Checklist linked to this dive';

  @override
  String get preDive_link_unlinked => 'Checklist unlinked from this dive';

  @override
  String get preDive_sessions_delete => 'Delete';

  @override
  String get preDive_sessions_deleteConfirm => 'Delete this checklist record?';

  @override
  String get preDive_sessions_filter => 'Filter';

  @override
  String get preDive_sessions_filterTitle => 'Filter checklist runs';

  @override
  String get preDive_sessions_filterChecklist => 'Checklist';

  @override
  String get preDive_sessions_filterStatus => 'Status';

  @override
  String get preDive_sessions_filterFlaggedOnly => 'Flagged runs only';

  @override
  String get preDive_sessions_filterDateRange => 'Date range';

  @override
  String get preDive_sessions_filterAnyDate => 'Any date';

  @override
  String get preDive_sessions_filterClearAll => 'Clear all';

  @override
  String get preDive_sessions_filterApply => 'Apply';

  @override
  String get preDive_sessions_filterFlaggedChip => 'Flagged only';

  @override
  String get preDive_sessions_emptyFiltered =>
      'No checklist runs match these filters';

  @override
  String get preDive_sessions_export => 'Export to Excel';

  @override
  String get preDive_sessions_exportEmpty => 'No checklist runs to export';

  @override
  String preDive_sessions_exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get preDive_start_title => 'Start pre-dive checklist';

  @override
  String get preDive_start_template => 'Checklist';

  @override
  String get preDive_start_equipmentSet => 'Equipment set';

  @override
  String get preDive_start_noEquipmentSet => 'None';

  @override
  String get preDive_start_begin => 'Begin';

  @override
  String get diveLog_listPage_bottomSheet_preDiveChecklist =>
      'Start pre-dive checklist';

  @override
  String get preDive_dashboard_title => 'Pre-Dive Check';

  @override
  String preDive_dashboard_resume(int done, int total) {
    return 'Resume - $done of $total';
  }

  @override
  String get preDive_dashboard_start => 'Start pre-dive check';

  @override
  String get trips_detail_preDive_action => 'Pre-dive checklist';

  @override
  String get settings_manage_preDiveChecklists => 'Pre-Dive Checklists';

  @override
  String get settings_manage_preDiveChecklists_subtitle =>
      'Buddy checks, CCR build lists, gear packing';

  @override
  String get common_action_back => 'Back';

  @override
  String get common_action_cancel => 'Cancel';

  @override
  String get common_action_close => 'Close';

  @override
  String get common_action_continue => 'Continue';

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
  String get common_action_share => 'Share';

  @override
  String get common_label_error => 'Error';

  @override
  String get common_label_loading => 'Loading';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get common_error_tryAgain => 'Something went wrong. Please try again.';

  @override
  String get courses_action_add => 'Add Course';

  @override
  String get courses_action_addFromTemplate => 'Add from template';

  @override
  String get courses_action_addRequirement => 'Add requirement';

  @override
  String get courses_action_create => 'Create Course';

  @override
  String get courses_action_deleteRequirement => 'Delete requirement';

  @override
  String get courses_action_edit => 'Edit course';

  @override
  String get courses_action_editRequirement => 'Edit requirement';

  @override
  String get courses_action_exportTrainingLog => 'Export Training Log';

  @override
  String get courses_action_linkDive => 'Link';

  @override
  String get courses_action_markCompleted => 'Mark as Completed';

  @override
  String get courses_action_unlinkDive => 'Unlink dive';

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
  String get courses_empty_button => 'Add Your First Training Course';

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
  String courses_requirement_diveProgress(int count, int target) {
    return '$count of $target dives';
  }

  @override
  String get courses_requirement_field_name => 'Name';

  @override
  String get courses_requirement_field_targetCount => 'Required dives';

  @override
  String get courses_requirement_kind_checklist => 'Check-off item';

  @override
  String get courses_requirement_kind_dive => 'Dive requirement';

  @override
  String get courses_requirement_suggestions => 'Suggested dives';

  @override
  String get courses_requirements_empty =>
      'Track adventure dives, prerequisites, and check-offs for this course.';

  @override
  String courses_requirements_progress(int satisfied, int total) {
    return '$satisfied of $total complete';
  }

  @override
  String get courses_section_details => 'Course Details';

  @override
  String get courses_section_earnedCertification => 'Earned Certification';

  @override
  String get courses_section_instructor => 'Instructor';

  @override
  String get courses_section_notes => 'Notes';

  @override
  String get courses_section_requirements => 'Requirements';

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
  String courses_template_addsCount(int count) {
    return 'Adds $count requirements';
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
  String get dashboard_activeCourses_title => 'Courses in progress';

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
  String get dashboard_hero_divesTotalOne => '1 dive';

  @override
  String dashboard_hero_divesTotalOther(Object count) {
    return '$count dives';
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
  String get dashboard_hero_divesLoggedLabel => 'dives logged';

  @override
  String get dashboard_hero_hoursUnderwaterLabel => 'hours underwater';

  @override
  String get dashboard_hero_daysSinceLabel => 'days since diving';

  @override
  String get dashboard_hero_thisMonthLabel => 'dives this month';

  @override
  String get dashboard_hero_thisYearLabel => 'dives this year';

  @override
  String get dashboard_hero_todayLabel => 'today!';

  @override
  String get dashboard_hero_noDivesLabel => 'no dives yet';

  @override
  String get dashboard_hero_diverFallbackName => 'Diver';

  @override
  String get dashboard_hero_statDives => 'dives';

  @override
  String get dashboard_hero_statHours => 'hours';

  @override
  String get dashboard_hero_statSites => 'sites';

  @override
  String get dashboard_hero_statCountries => 'countries';

  @override
  String dashboard_activityStats_divesInYear(String year) {
    return 'dives in $year';
  }

  @override
  String get dashboard_semantics_statsBar => 'Dive statistics summary';

  @override
  String get dashboard_gauges_addGear => 'Add gear';

  @override
  String dashboard_gauges_gearOk(String name) {
    return '$name OK';
  }

  @override
  String dashboard_gauges_gearDueIn(String name, int days) {
    return '$name due in ${days}d';
  }

  @override
  String dashboard_gauges_gearOverdue(String name) {
    return '$name overdue';
  }

  @override
  String get dashboard_gauges_insuranceOk => 'Insurance OK';

  @override
  String dashboard_gauges_insuranceExpires(String date) {
    return 'Insurance expires $date';
  }

  @override
  String get dashboard_gauges_insuranceExpired => 'Insurance expired';

  @override
  String get dashboard_gauges_noInsurance => 'No insurance on file';

  @override
  String get dashboard_gauges_noFlyClear => 'No-fly 0:00';

  @override
  String dashboard_gauges_flightWindow(String hours, String minutes) {
    return 'Dive window $hours:$minutes';
  }

  @override
  String get dashboard_gauges_flightWindowClosed =>
      'No more diving before flight';

  @override
  String dashboard_gauges_noFlyRemaining(String hours, String minutes) {
    return 'No-fly $hours:$minutes';
  }

  @override
  String dashboard_gauges_lastDiveDays(int days) {
    return 'Last dive ${days}d ago';
  }

  @override
  String get dashboard_gauges_lastDiveToday => 'Dove today';

  @override
  String get dashboard_gauges_noDivesYet => 'No dives yet';

  @override
  String get settings_homeChips_pageTitle => 'Home screen';

  @override
  String get settings_homeChips_description =>
      'Choose which status chips appear at the top of the Home tab.';

  @override
  String get settings_homeChips_sectionTitle => 'Status chips';

  @override
  String get settings_homeCards_sectionTitle => 'Home cards';

  @override
  String get settings_homeCards_description =>
      'Choose which cards appear on the Home tab and drag to reorder them.';

  @override
  String get settings_homeCards_autoHides => 'Hides automatically when empty';

  @override
  String get settings_homeCards_resetToDefault => 'Reset to default';

  @override
  String get settings_homeCards_resetDialog_title => 'Reset Home layout?';

  @override
  String get settings_homeCards_resetDialog_message =>
      'This restores the default card order and shows all cards again.';

  @override
  String get settings_homeCards_resetDialog_cancel => 'Cancel';

  @override
  String get settings_homeCards_resetDialog_confirm => 'Reset';

  @override
  String get settings_homeCards_card_hero => 'Welcome header';

  @override
  String get settings_homeCards_card_gaugeStrip => 'Status chips';

  @override
  String get settings_homeCards_card_preDive => 'Pre-dive checklist';

  @override
  String get settings_homeCards_card_recentDives => 'Recent dives';

  @override
  String get settings_homeCards_card_quickActions => 'Quick actions';

  @override
  String get settings_homeCards_card_milestones => 'Milestones';

  @override
  String get settings_homeCards_card_photoRibbon => 'Recent media';

  @override
  String get settings_homeCards_card_onThisDay => 'On this day';

  @override
  String get settings_homeCards_card_yearInReview => 'Year in review';

  @override
  String get settings_homeCards_card_activeCourses => 'Course progress';

  @override
  String get settings_homeCards_card_recentSitesMap => 'Recent sites map';

  @override
  String get dashboard_allHidden_message => 'All Home cards are hidden.';

  @override
  String get dashboard_allHidden_customize => 'Customize Home';

  @override
  String get settings_homeChips_flightWindow => 'Flight dive window';

  @override
  String get settings_homeChips_gear => 'Gear service';

  @override
  String get settings_homeChips_insurance => 'Insurance';

  @override
  String get settings_homeChips_noFly => 'No-fly timer';

  @override
  String get settings_homeChips_lastDive => 'Dive currency';

  @override
  String get settings_homeChips_certifications => 'Certification expiry';

  @override
  String get settings_homeChips_trip => 'Upcoming trip';

  @override
  String get settings_homeChips_checklist => 'Active checklist';

  @override
  String get settings_homeChips_course => 'Course progress';

  @override
  String get settings_homeChips_uploads => 'Media uploads';

  @override
  String get settings_homeChips_backup => 'Backup age';

  @override
  String get settings_homeChips_sync => 'Sync status';

  @override
  String get settings_homeChips_dataQuality => 'Data quality';

  @override
  String dashboard_gauges_certsExpiring(int count) {
    return '$count certifications expiring';
  }

  @override
  String dashboard_gauges_tripCountdown(String name, int days) {
    return '$name in ${days}d';
  }

  @override
  String get dashboard_gauges_checklistActive => 'Checklist in progress';

  @override
  String dashboard_gauges_courseProgress(String name, int done, int total) {
    return '$name: $done/$total';
  }

  @override
  String dashboard_gauges_uploadsPending(int count) {
    return '$count uploads pending';
  }

  @override
  String get dashboard_gauges_backupNone => 'No backup yet';

  @override
  String get dashboard_gauges_backupToday => 'Backed up today';

  @override
  String dashboard_gauges_backupDays(int days) {
    return 'Backup ${days}d ago';
  }

  @override
  String dashboard_gauges_syncPending(int count) {
    return '$count unsynced';
  }

  @override
  String get dashboard_gauges_synced => 'Synced';

  @override
  String dashboard_gauges_dataIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count data issues',
      one: '1 data issue',
    );
    return '$_temp0';
  }

  @override
  String get dashboard_gauges_retry => 'Status unavailable - tap to retry';

  @override
  String get dashboard_urgent_title => 'Needs attention';

  @override
  String get dashboard_media_title => 'Recent media';

  @override
  String get dashboard_recentSites_title => 'Recent sites';

  @override
  String get dashboard_yearInReview_title => 'This year';

  @override
  String dashboard_yearInReview_divesVs(int count, int previous) {
    return '$count dives (vs $previous last year)';
  }

  @override
  String dashboard_yearInReview_hours(String hours) {
    return '$hours hours underwater';
  }

  @override
  String dashboard_yearInReview_maxDepth(String depth) {
    return 'Deepest: $depth';
  }

  @override
  String get dashboard_onThisDay_title => 'On this day';

  @override
  String dashboard_onThisDay_entry(String year, String site) {
    return '$year - $site';
  }

  @override
  String get dashboard_milestones_title => 'Milestones';

  @override
  String dashboard_milestones_nextDive(int remaining, int milestone) {
    return '$remaining dives to #$milestone';
  }

  @override
  String dashboard_milestones_certYears(String name, int years, String month) {
    return '$name: $years years in $month';
  }

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
  String get dashboard_recentDives_latestProfileTitle => 'Latest dive profile';

  @override
  String get dashboard_recentDives_noProfileData =>
      'No profile data for this dive';

  @override
  String get dashboard_recentDives_profileLoadError =>
      'Couldn\'t load the dive profile';

  @override
  String dashboard_recentDives_profileMinutes(int minutes) {
    return '$minutes min';
  }

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
  String get decoCalculator_waterType => 'Water type';

  @override
  String get decoCalculator_waterType_standard => 'Standard';

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
  String get diveCenters_empty_button => 'Add Your First Dive Center';

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
  String get diveLog_combine_confirm => 'Combine into one dive';

  @override
  String get diveLog_combine_dataNote =>
      'Details come from the earliest dive, with blanks filled from later dives. Notes are combined. Tanks, gear, buddies, tags, and sightings are all kept.';

  @override
  String get diveLog_combine_error =>
      'Couldn\'t combine the dives. Nothing was changed.';

  @override
  String diveLog_combine_gapLabel(String duration) {
    return 'Surface interval: $duration';
  }

  @override
  String get diveLog_combine_longSurfaceWarning =>
      'One or more surface intervals are longer than 30 minutes. These may be separate dives rather than one continuous dive.';

  @override
  String get diveLog_combine_mixedDivers =>
      'The selected dives belong to different divers and can\'t be combined.';

  @override
  String get diveLog_combine_profilePreview => 'Combined profile';

  @override
  String diveLog_combine_previewIntro(int count) {
    return 'These $count dives will be combined into one continuous dive. Gaps between them become surface time.';
  }

  @override
  String diveLog_combine_resultSummary(
    String runtime,
    String maxDepth,
    String bottomTime,
  ) {
    return 'Result: $runtime total, max depth $maxDepth, $bottomTime bottom time';
  }

  @override
  String diveLog_combine_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    return 'Combined $count $_temp0';
  }

  @override
  String get diveLog_combine_title => 'Combine dives';

  @override
  String get diveLog_combine_undoError => 'Couldn\'t undo the combine.';

  @override
  String get diveLog_combine_undone => 'Combine undone';

  @override
  String get diveLog_computerSource_badge_primary => 'Primary';

  @override
  String get diveLog_consolidate_confirm =>
      'Keep as one dive with both computers';

  @override
  String get diveLog_consolidate_error_generic =>
      'Couldn\'t merge the dives. Nothing was changed.';

  @override
  String get diveLog_consolidate_error_notOverlapping =>
      'These dives don\'t overlap in time, so they can\'t be merged as the same dive.';

  @override
  String get diveLog_consolidate_error_sameComputer =>
      'These dives are from the same dive computer and can\'t be merged this way.';

  @override
  String get diveLog_consolidate_selectPrimary => 'Primary dive computer';

  @override
  String get diveLog_consolidate_snackbar =>
      'Dive merged as an additional computer.';

  @override
  String get diveLog_consolidate_undoError => 'Couldn\'t undo the merge.';

  @override
  String get diveLog_consolidate_undone => 'Merge undone';

  @override
  String diveLog_mergeDialog_confirmSubtitle(String time) {
    return 'Merging dive at $time into this dive.';
  }

  @override
  String get diveLog_mergeDialog_confirmTitle => 'Confirm merge';

  @override
  String get diveLog_mergeDialog_empty => 'No other dives found on this day.';

  @override
  String get diveLog_mergeDialog_explanation =>
      'This dive\'s profile, tanks, pressures, events, tags, buddies, and sightings will be folded into this dive as an additional computer source. This action can be reversed with \'Unlink computer\'.';

  @override
  String diveLog_mergeDialog_loadError(String error) {
    return 'Error loading dives: $error';
  }

  @override
  String get diveLog_mergeDialog_merge => 'Merge';

  @override
  String get diveLog_mergeDialog_next => 'Next';

  @override
  String get diveLog_mergeDialog_subtitle =>
      'Select a dive from the same day to merge as an additional computer.';

  @override
  String get diveLog_mergeDialog_title => 'Merge with another dive';

  @override
  String get diveLog_mergeDialog_whatThisDoes => 'What this does';

  @override
  String get diveLog_computerSheet_description =>
      'Select which computer\'s profile to edit from.';

  @override
  String get diveLog_computerSheet_title => 'Choose starting profile';

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
  String get diveLog_deco_label_gf99 => 'GF99';

  @override
  String get diveLog_deco_label_surfGf => 'SurfGF';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_time => 'Time';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String diveLog_deco_gf_chip(Object low, Object high) {
    return 'GF: $low/$high';
  }

  @override
  String diveLog_deco_gf_chipFromSettings(Object low, Object high) {
    return 'GF: $low/$high · your settings';
  }

  @override
  String diveLog_deco_gf_chipRecordedAlgorithm(
    Object algorithm,
    Object low,
    Object high,
  ) {
    return '$algorithm · analyzed at GF $low/$high';
  }

  @override
  String diveLog_deco_gf_semantics(Object low, Object high) {
    return 'Gradient factors: low $low, high $high';
  }

  @override
  String get diveLog_deco_gf_tooltipFromSettings =>
      'This dive computer did not record its gradient factors, so this dive is analyzed with the ones from your settings.';

  @override
  String diveLog_deco_gf_tooltipRecordedAlgorithm(Object algorithm) {
    return 'This dive was computed on $algorithm, which does not use gradient factors. Submersion analyzes it with the ones from your settings.';
  }

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
  String get diveLog_deco_title => 'Deco Status';

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
  String get diveLog_detail_button_rangeAnalysis => 'Range Stats';

  @override
  String get diveLog_detail_button_showEnd => 'Show end';

  @override
  String get diveLog_detail_captureSignature => 'Capture Instructor Signature';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return '$timestamp';
  }

  @override
  String diveLog_detail_collapsed_atTimeInfo(
    Object timestamp,
    Object baseInfo,
  ) {
    return '$timestamp • $baseInfo';
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
  String get diveLog_detail_section_decoStatus => 'Deco Status';

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
  String get diveLog_detail_section_sacRateBySegment => 'SAC Rate by Segment';

  @override
  String get diveLog_detail_section_tags => 'Tags';

  @override
  String get diveLog_detail_section_cylinders => 'Cylinders';

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
  String get diveLog_detail_tideCalculated => 'Calculated from tide model';

  @override
  String get diveLog_detail_tooltip_addToFavorites => 'Add to favorites';

  @override
  String get diveLog_detail_tooltip_edit => 'Edit';

  @override
  String get diveLog_detail_tooltip_editDive => 'Edit dive';

  @override
  String get diveLog_detail_tooltip_previousDive => 'Previous dive';

  @override
  String get diveLog_detail_tooltip_nextDive => 'Next dive';

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
  String get diveLog_diveMode_gaugeDescription =>
      'Depth and time only; no gas or decompression tracking';

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
  String get diveLog_edit_group_buddies => 'Buddies';

  @override
  String get diveLog_edit_group_conditions => 'Conditions';

  @override
  String get diveLog_edit_group_experience => 'Experience';

  @override
  String get diveLog_edit_group_gasGear => 'Gas & Gear';

  @override
  String get diveLog_edit_group_theDive => 'The Dive';

  @override
  String get diveLog_edit_group_trip => 'Trip';

  @override
  String get diveLog_edit_headerNew => 'Log New Dive';

  @override
  String get diveLog_edit_invite_buddies => 'Add buddies';

  @override
  String get diveLog_edit_invite_conditions =>
      'Add conditions - water, visibility, weather';

  @override
  String get diveLog_edit_invite_experience =>
      'Add rating, sightings, notes or tags';

  @override
  String get diveLog_edit_invite_gasGear =>
      'Add gas & gear - mode, tanks, equipment, weight';

  @override
  String get diveLog_edit_invite_trip => 'Add trip or dive center';

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
  String get diveLog_edit_label_diveTypes => 'Dive Types';

  @override
  String get diveLog_edit_label_diveNumber => 'Dive #';

  @override
  String get diveLog_edit_label_diveName => 'Name';

  @override
  String get diveLog_edit_diveNamePlaceholder => 'Optional name for this dive';

  @override
  String get diveLog_edit_hint_diveNumber => 'Auto-assigned if left blank';

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
  String get diveLog_edit_overline_tanks => 'Tanks';

  @override
  String get diveLog_edit_profile_draw => 'Draw a profile';

  @override
  String get diveLog_edit_profile_none => 'Not recorded';

  @override
  String diveLog_edit_profile_outliers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count potential outliers detected',
      one: '1 potential outlier detected',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_profile_points(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_row_addSite => 'Add site';

  @override
  String get diveLog_edit_row_diveCenter => 'Dive center';

  @override
  String get diveLog_edit_row_diveProfile => 'Dive profile';

  @override
  String get diveLog_edit_row_entry => 'Entry';

  @override
  String get diveLog_edit_row_exit => 'Exit';

  @override
  String get diveLog_edit_row_notSet => 'Not set';

  @override
  String get diveLog_edit_row_site => 'Site';

  @override
  String get diveLog_edit_row_surfaceInterval => 'Surface interval';

  @override
  String get diveLog_edit_row_trip => 'Trip';

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
  String diveLog_edit_snackbar_avgDepthCalculated(Object depth) {
    return 'Avg depth calculated: $depth';
  }

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Bottom time calculated: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Error saving dive: $error';
  }

  @override
  String diveLog_edit_snackbar_maxDepthCalculated(Object depth) {
    return 'Max depth calculated: $depth';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'No dive profile data available';

  @override
  String diveLog_edit_snackbar_runtimeCalculated(Object minutes) {
    return 'Runtime calculated: $minutes min';
  }

  @override
  String get diveLog_edit_snackbar_unableToCalculateAvgDepth =>
      'Unable to calculate average depth from profile';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Unable to calculate bottom time from profile';

  @override
  String get diveLog_edit_snackbar_unableToCalculateMaxDepth =>
      'Unable to calculate max depth from profile';

  @override
  String get diveLog_edit_snackbar_unableToCalculateRuntime =>
      'Unable to calculate runtime from profile';

  @override
  String diveLog_edit_summary_items(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_summary_notes => 'notes';

  @override
  String diveLog_edit_summary_species(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count species',
      one: '1 species',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_summary_tanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tanks',
      one: '1 tank',
    );
    return '$_temp0';
  }

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
  String get diveLog_edit_tankCard_done => 'Done';

  @override
  String get diveLog_edit_tankCard_edit => 'Edit';

  @override
  String get diveLog_edit_tankCard_mix => 'Mix';

  @override
  String get diveLog_edit_tankCard_pressure => 'Pressure';

  @override
  String diveLog_edit_tankCard_title(int number) {
    return 'Tank $number';
  }

  @override
  String get diveLog_edit_tankCard_volume => 'Volume';

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
  String diveLog_equipmentSetPicker_itemsSummary(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0: $names';
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
  String get diveLog_filterChip_noBuddy => 'No Buddy';

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
  String get diveLog_filter_clearWeekdays => 'Clear weekdays';

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
  String get diveLog_filter_noBuddyOnly => 'No Buddy Assigned';

  @override
  String get diveLog_filter_noTagsYet => 'No tags created yet';

  @override
  String get diveLog_filter_presetAllTime => 'All time';

  @override
  String get diveLog_filter_presetLast12Months => 'Last 12 months';

  @override
  String get diveLog_filter_presetLastYear => 'Last year';

  @override
  String get diveLog_filter_presetThisYear => 'This year';

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
  String get diveLog_filter_sectionWeekdays => 'Weekdays';

  @override
  String get diveLog_filter_showOnlyFavorites => 'Show only favorite dives';

  @override
  String get diveLog_filter_showOnlyNoBuddy =>
      'Show only dives without a buddy';

  @override
  String get diveLog_filter_startDate => 'Start Date';

  @override
  String get diveLog_filter_title => 'Filter Dives';

  @override
  String get diveLog_filter_resizeGrip => 'Resize filter panel';

  @override
  String get diveLog_filter_tooltip_close => 'Close filter';

  @override
  String get diveLog_fullscreenProfile_close => 'Close fullscreen';

  @override
  String get diveLog_fullscreenProfile_readoutHint =>
      'Hover or scrub the profile';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Dive #$number Profile';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Ascent Rate';

  @override
  String get diveLog_legend_label_ascentRateLine => 'Ascent Rate Line';

  @override
  String get diveLog_legend_label_ceiling => 'Ceiling';

  @override
  String get diveLog_legend_label_decoStops => 'Deco stops';

  @override
  String get diveLog_legend_label_cns => 'CNS%';

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
  String get diveLog_legend_label_otu => 'OTU';

  @override
  String get diveLog_legend_label_photoMarkers => 'Photos';

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
  String get diveLog_legend_label_showGas => 'Gases';

  @override
  String get diveLog_legend_label_surfaceGf => 'Surface GF';

  @override
  String get diveLog_legend_label_temp => 'Temp';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_legend_source_dc => 'DC';

  @override
  String get diveLog_legend_source_calc => 'Calc';

  @override
  String get diveLog_chartSection_overlays => 'Overlays';

  @override
  String get diveLog_chartSection_markers => 'Markers';

  @override
  String get diveLog_chartSection_decompression => 'Decompression';

  @override
  String get diveLog_chartSection_gasAnalysis => 'Gas Analysis';

  @override
  String get diveLog_chartSection_display => 'Display';

  @override
  String get diveLog_chartSection_other => 'Other';

  @override
  String get diveLog_chartSection_tankPressures => 'Tank Pressures';

  @override
  String get diveLog_chartOption_metricsFollowViewport =>
      'Keep overlays in view';

  @override
  String get diveLog_pressure_estimatedSuffix => '(est.)';

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
  String get diveLog_listPage_bottomSheet_scanPaperLog => 'Scan Paper Log';

  @override
  String get ocrImport_scanPage_processing => 'Reading page...';

  @override
  String get ocrImport_scanPage_pickPhoto => 'Choose Photo';

  @override
  String get ocrImport_scanPage_takePhoto => 'Take Photo';

  @override
  String get ocrImport_scanPage_nothingRead =>
      'Couldn\'t read much from this page - fields left blank';

  @override
  String get ocrImport_scanPage_engineMissing =>
      'Text recognition is not available. Install Tesseract to scan paper logs (for example: sudo apt install tesseract-ocr).';

  @override
  String get ocrImport_editPage_photoAttachFailed =>
      'The dive was saved, but attaching the scanned page failed';

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
  String get diveLog_listPage_menuMatchSites => 'Match Dives to Sites';

  @override
  String get diveLog_sighting_decreaseCount => 'Decrease count';

  @override
  String get diveLog_sighting_increaseCount => 'Increase count';

  @override
  String diveLog_speciesPicker_errorLoading(String error) {
    return 'Error loading species: $error';
  }

  @override
  String get diveRole_builtin_buddy => 'Buddy';

  @override
  String get diveRole_builtin_diveGuide => 'Dive Guide';

  @override
  String get diveRole_builtin_diveMaster => 'Divemaster';

  @override
  String get diveRole_builtin_instructor => 'Instructor';

  @override
  String get diveRole_builtin_rearGuard => 'Rear Guard';

  @override
  String get diveRole_builtin_safetyDiver => 'Safety Diver';

  @override
  String get diveRole_builtin_solo => 'Solo';

  @override
  String get diveRole_builtin_student => 'Student';

  @override
  String get diveRole_builtin_supportDiver => 'Support Diver';

  @override
  String get diveRoles_addDialog_addButton => 'Add';

  @override
  String get diveRoles_addDialog_nameHint => 'e.g., Photographer';

  @override
  String get diveRoles_addDialog_nameLabel => 'Dive Role Name';

  @override
  String get diveRoles_addDialog_nameValidation => 'Please enter a name';

  @override
  String get diveRoles_addDialog_title => 'Add Custom Dive Role';

  @override
  String get diveRoles_addTooltip => 'Add dive role';

  @override
  String get diveRoles_appBar_title => 'Dive Roles';

  @override
  String get diveRoles_builtInHeader => 'Built-in Dive Roles';

  @override
  String get diveRoles_customHeader => 'Custom Dive Roles';

  @override
  String diveRoles_deleteDialog_content(Object name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get diveRoles_deleteDialog_title => 'Delete Dive Role?';

  @override
  String get diveRoles_deleteTooltip => 'Delete dive role';

  @override
  String get diveRoles_renameDialog_title => 'Rename Dive Role';

  @override
  String get diveRoles_renameTooltip => 'Rename dive role';

  @override
  String diveRoles_snackbar_added(Object name) {
    return 'Added dive role: $name';
  }

  @override
  String diveRoles_snackbar_cannotDelete(Object name) {
    return 'Cannot delete \"$name\" - it is used by existing dives';
  }

  @override
  String diveRoles_snackbar_deleted(Object name) {
    return 'Deleted dive role: $name';
  }

  @override
  String diveRoles_snackbar_errorAdding(Object error) {
    return 'Error adding dive role: $error';
  }

  @override
  String get diveSites_edit_depth_heroMax => 'Max depth';

  @override
  String get diveSites_edit_depth_heroMin => 'Min depth';

  @override
  String get diveSites_edit_group_accessSafety => 'Access & safety';

  @override
  String get diveSites_edit_group_diveInfo => 'Dive info';

  @override
  String get diveSites_edit_group_identity => 'Identity';

  @override
  String get diveSites_edit_group_lifeNotes => 'Life & notes';

  @override
  String get diveSites_edit_group_location => 'Location';

  @override
  String get diveSites_edit_invite_accessSafety =>
      'Add access, parking, mooring or hazards';

  @override
  String get diveSites_edit_invite_diveInfo =>
      'Add depth range, difficulty or rating';

  @override
  String get diveSites_edit_invite_lifeNotes =>
      'Add marine life, notes or sharing';

  @override
  String get diveSites_edit_invite_location => 'Add GPS position or altitude';

  @override
  String get diveSites_edit_summary_shared => 'shared';

  @override
  String get forms_addSection_prefix => 'Add:';

  @override
  String get forms_cancel => 'Cancel';

  @override
  String get forms_discard_body =>
      'You have unsaved changes. If you leave now they will be lost.';

  @override
  String get forms_discard_discard => 'Discard';

  @override
  String get forms_discard_keepEditing => 'Keep editing';

  @override
  String get forms_discard_title => 'Discard changes?';

  @override
  String get forms_save => 'Save';

  @override
  String forms_section_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count issues',
      one: '1 issue',
    );
    return '$_temp0';
  }

  @override
  String get settings_manage_setupAssistant => 'Setup assistant';

  @override
  String get settings_manage_setupAssistant_subtitle =>
      'Revisit units, appearance, and backup choices';

  @override
  String get setup_backup_cloudCopy => 'Store backups in the cloud';

  @override
  String get setup_backup_frequency => 'Frequency';

  @override
  String get setup_backup_frequency_daily => 'Daily';

  @override
  String get setup_backup_frequency_monthly => 'Monthly';

  @override
  String get setup_backup_frequency_weekly => 'Weekly';

  @override
  String get setup_backup_scheduleSubtitle => 'Back up your data on a schedule';

  @override
  String get setup_backup_scheduleToggle => 'Automatic backups';

  @override
  String get setup_backup_subtitle => 'Protect your data from day one.';

  @override
  String get setup_backup_title => 'Backups & Sync';

  @override
  String get setup_common_back => 'Back';

  @override
  String get setup_common_next => 'Next';

  @override
  String get setup_common_skip => 'Skip';

  @override
  String get setup_existing_folder_subtitle =>
      'Point Submersion at a folder that already contains a library';

  @override
  String get setup_existing_folder_title => 'Open an existing folder';

  @override
  String get setup_existing_restore_subtitle =>
      'Pick a backup file exported from Submersion';

  @override
  String get setup_existing_restore_title => 'Restore a backup file';

  @override
  String get setup_existing_subtitle =>
      'Choose how to load your existing Submersion library';

  @override
  String get setup_existing_sync_subtitle =>
      'Pull your library from iCloud, Dropbox, or S3';

  @override
  String get setup_existing_sync_title => 'Connect cloud sync';

  @override
  String get setup_existing_title => 'Bring your data';

  @override
  String get setup_finish_applying => 'Setting up...';

  @override
  String setup_finish_error(Object error) {
    return 'Could not complete setup: $error';
  }

  @override
  String get setup_finish_feature_diveComputer =>
      'Download dives from your dive computer';

  @override
  String get setup_finish_feature_gear => 'Track gear and service intervals';

  @override
  String get setup_finish_feature_import =>
      'Import logs from files and other apps';

  @override
  String get setup_finish_feature_sites => 'Map your dive sites';

  @override
  String get setup_finish_feature_statistics =>
      'Explore statistics about your diving';

  @override
  String get setup_finish_start => 'Get started';

  @override
  String get setup_finish_subtitle => 'Submersion can also...';

  @override
  String get setup_finish_title => 'You\'re all set';

  @override
  String get setup_folder_notFound_message =>
      'The selected folder does not contain a Submersion database.';

  @override
  String get setup_folder_notFound_title => 'No library in that folder';

  @override
  String get setup_folder_pick => 'Choose folder';

  @override
  String get setup_folder_switching => 'Opening library...';

  @override
  String get setup_folder_title => 'Open existing folder';

  @override
  String get setup_profile_nameHint => 'Enter your name';

  @override
  String get setup_profile_nameLabel => 'Your Name';

  @override
  String get setup_profile_nameValidation => 'Please enter your name';

  @override
  String get setup_profile_subtitle =>
      'Enter your name to get started. You can add more details later.';

  @override
  String get setup_profile_title => 'Create Your Profile';

  @override
  String get setup_restore_inProgress => 'Restoring...';

  @override
  String get setup_restore_pick => 'Choose backup file';

  @override
  String get setup_restore_title => 'Restore backup';

  @override
  String get setup_step_backup => 'Backup';

  @override
  String get setup_step_finish => 'Done';

  @override
  String get setup_step_profile => 'Profile';

  @override
  String get setup_step_units => 'Units';

  @override
  String get setup_syncPull_continue => 'Continue';

  @override
  String get setup_syncPull_incomplete_message =>
      'This account holds a Submersion library that was never finished uploading. Let your other device finish syncing, then try again.';

  @override
  String get setup_syncPull_incomplete_retry => 'Check again';

  @override
  String get setup_syncPull_incomplete_title => 'Library upload unfinished';

  @override
  String get setup_syncPull_locked_message =>
      'Enter the encryption passphrase to unlock this library and download it to this device.';

  @override
  String get setup_syncPull_locked_title => 'This library is encrypted';

  @override
  String get setup_syncPull_noLibrary_message =>
      'No existing Submersion library was found on this account. Start fresh instead? Your connection will be kept.';

  @override
  String get setup_syncPull_noLibrary_title => 'No library found';

  @override
  String get setup_syncPull_success => 'Library adopted';

  @override
  String get setup_syncPull_syncing => 'Pulling your library...';

  @override
  String get setup_syncPull_title => 'Connect and pull';

  @override
  String get setup_sync_changeProvider => 'Change provider';

  @override
  String setup_sync_connectedTo(String provider) {
    return 'Connected to $provider';
  }

  @override
  String setup_sync_error(Object error) {
    return 'Could not connect: $error';
  }

  @override
  String get setup_sync_header => 'Cloud sync';

  @override
  String get setup_sync_libraryFound_adopt => 'Adopt existing library';

  @override
  String get setup_sync_libraryFound_keepFresh => 'Start fresh';

  @override
  String get setup_sync_libraryFound_message =>
      'This account already contains a Submersion library. Adopt it instead of starting fresh?';

  @override
  String get setup_sync_libraryFound_title => 'Existing library found';

  @override
  String get setup_sync_manageInSettings => 'Manage in Settings';

  @override
  String get setup_sync_notConnected => 'Not connected';

  @override
  String get setup_sync_subtitle => 'Sync your data across devices';

  @override
  String get setup_units_advanced => 'Fine-tune units';

  @override
  String get setup_units_altitude => 'Altitude';

  @override
  String get setup_units_dateFormat => 'Date format';

  @override
  String get setup_units_depth => 'Depth';

  @override
  String get setup_units_imperial => 'Imperial';

  @override
  String get setup_units_metric => 'Metric';

  @override
  String get setup_units_pressure => 'Pressure';

  @override
  String get setup_units_sac => 'SAC rate';

  @override
  String get setup_units_subtitle =>
      'Choose how measurements are displayed. You can fine-tune each unit.';

  @override
  String get setup_units_temperature => 'Temperature';

  @override
  String get setup_units_timeFormat => 'Time format';

  @override
  String get setup_units_title => 'Units';

  @override
  String get setup_units_volume => 'Volume';

  @override
  String get setup_units_weight => 'Weight';

  @override
  String get setup_welcome_existingData_subtitle =>
      'Restore a backup, connect cloud sync, or open an existing folder';

  @override
  String get setup_welcome_existingData_title =>
      'I have existing Submersion data';

  @override
  String get setup_welcome_skipSetup => 'Skip setup';

  @override
  String get setup_welcome_startFresh_subtitle =>
      'Create your diver profile and configure the app';

  @override
  String get setup_welcome_startFresh_title => 'Set up a new profile';

  @override
  String get setup_welcome_subtitle => 'Advanced dive logging and analytics';

  @override
  String get setup_welcome_title => 'Welcome to Submersion';

  @override
  String get siteMatchReview_title => 'Match Sites';

  @override
  String siteMatchReview_diveNumber(Object number) {
    return 'Dive #$number';
  }

  @override
  String get siteMatchReview_empty => 'Nothing to match.';

  @override
  String siteMatchReview_summary(int selected, int review, int none) {
    return '$selected selected · $review to review · $none no match';
  }

  @override
  String siteMatchReview_confirm(int count) {
    return 'Confirm $count matches';
  }

  @override
  String get siteMatchReview_cancel => 'Cancel';

  @override
  String get siteMatchReview_tapToChoose => 'Tap to choose a site';

  @override
  String siteMatchReview_awayMeters(int meters) {
    return '$meters m away';
  }

  @override
  String siteMatchReview_depthTo(int meters) {
    return 'to $meters m';
  }

  @override
  String siteMatchReview_depthRange(int min, int max) {
    return '$min–$max m';
  }

  @override
  String siteMatchReview_appliedSnack(int dives, int sites) {
    return 'Linked $dives dives · added $sites sites';
  }

  @override
  String get siteMatchReview_applyError => 'Couldn\'t apply matches';

  @override
  String get siteMatchReview_discardTitle => 'Discard matches?';

  @override
  String get siteMatchReview_discardMessage =>
      'Your selections won\'t be saved.';

  @override
  String get siteMatchReview_discardConfirm => 'Discard';

  @override
  String get siteMatchReview_keepReviewing => 'Keep reviewing';

  @override
  String get siteMatchReview_sourceExisting => 'your site';

  @override
  String get siteMatchReview_sourceBundled => 'import';

  @override
  String get siteMatchReview_noNearbySite => 'No nearby site';

  @override
  String importSummary_matchSitesButton(int count) {
    return 'Match $count dives to sites';
  }

  @override
  String get diveLog_listPage_searchFieldLabel => 'Search dives...';

  @override
  String diveLog_listPage_searchLimitNotice(int limit) {
    return 'Showing the first $limit matches. Refine your search to narrow results.';
  }

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
  String get diveLog_profile_semantics_photoMarker => 'Photo marker';

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
  String get diveLog_rangeStats_label_avgDepth => 'Avg Depth';

  @override
  String get diveLog_rangeStats_label_avgVertSpeed => 'Avg Vert Speed';

  @override
  String get diveLog_rangeStats_label_depthDelta => 'Depth Delta';

  @override
  String get diveLog_rangeStats_label_elapsed => 'Elapsed';

  @override
  String get diveLog_rangeStats_label_gasConsumed => 'Gas Consumed';

  @override
  String get diveLog_rangeStats_label_maxAscent => 'Max Ascent';

  @override
  String get diveLog_rangeStats_label_maxDepth => 'Max Depth';

  @override
  String get diveLog_rangeStats_label_maxDescent => 'Max Descent';

  @override
  String get diveLog_rangeStats_label_maxHR => 'Max HR';

  @override
  String get diveLog_rangeStats_label_maxTemp => 'Max Temp';

  @override
  String get diveLog_rangeStats_label_minDepth => 'Min Depth';

  @override
  String get diveLog_rangeStats_label_minHR => 'Min HR';

  @override
  String get diveLog_rangeStats_label_minTemp => 'Min Temp';

  @override
  String get diveLog_rangeStats_label_sacRate => 'SAC Rate';

  @override
  String get diveLog_rangeStats_title => 'Range Stats';

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
  String get diveLog_search_filter_any => 'Any';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_deco => 'Decompression';

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
  String get diveLog_selection_tooltip_combine => 'Combine';

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
  String get diveLog_selection_tooltip_selectDateRange =>
      'Select by date range';

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
  String diveLog_sitePicker_distanceAway(String distance) {
    return '$distance away';
  }

  @override
  String get diveLog_sitePicker_sortedByDiveDistance =>
      'Sorted by distance from this dive';

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
  String get diveLog_tank_mndHelper => 'Set to auto-calculate He%';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO2 1.4)';
  }

  @override
  String diveLog_tank_modMndInfo(Object mod, Object mnd) {
    return 'MOD: $mod (ppO₂ 1.4) | MND: $mnd';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Gas Mix';

  @override
  String get diveLog_tank_selectPreset => 'Select Preset...';

  @override
  String get diveLog_tank_saveAsPreset => 'Save as preset';

  @override
  String get diveLog_tank_saveAsPreset_needSpecs =>
      'Enter a volume and working pressure first';

  @override
  String get diveLog_tank_saveAsPreset_nameTitle => 'Save tank preset';

  @override
  String get diveLog_tank_saveAsPreset_nameHint => 'e.g. My AL80';

  @override
  String diveLog_tank_saveAsPreset_saved(String name) {
    return 'Saved preset \"$name\"';
  }

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
  String get diveLog_tooltip_avgCalculated => '(avg, calculated)';

  @override
  String get diveLog_tooltip_ceiling => 'Ceiling';

  @override
  String get diveLog_tooltip_decoStop => 'Deco stop';

  @override
  String get diveLog_tooltip_cns => 'CNS';

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
  String get diveLog_tooltip_otu => 'OTU';

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
  String get diveLog_tooltip_sensor => 'Sensor';

  @override
  String get diveLog_legend_label_o2Cells => 'O2 cells';

  @override
  String get diveLog_tooltip_o2CellsTight => 'tight';

  @override
  String get diveLog_tooltip_o2CellsDrifting => 'drifting';

  @override
  String get diveLog_tooltip_o2CellsWide => 'wide';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Time';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get diveLog_sources_row_metric => 'Metric';

  @override
  String get diveLog_sources_row_maxDepth => 'Max Depth';

  @override
  String get diveLog_sources_row_avgDepth => 'Avg Depth';

  @override
  String get diveLog_sources_row_duration => 'Duration';

  @override
  String get diveLog_sources_row_waterTemp => 'Water Temp';

  @override
  String get diveLog_sources_row_cns => 'CNS';

  @override
  String get diveLog_sources_row_otu => 'OTU';

  @override
  String get diveLog_sources_row_decoAlgorithm => 'Deco Algorithm';

  @override
  String get diveLog_sources_row_gf => 'GF';

  @override
  String diveLog_sources_minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_unknownComputer => 'Unknown Computer';

  @override
  String get diveLog_sources_manualEntry => 'Manual Entry';

  @override
  String get diveLog_sources_importedFile => 'Imported File';

  @override
  String get diveLog_sources_editedSuffix => ' (edited)';

  @override
  String get diveLog_sources_barLabel => 'SOURCES';

  @override
  String get diveLog_sources_menu_setPrimary => 'Set as primary';

  @override
  String get diveLog_sources_menu_split => 'Split into separate dive';

  @override
  String get diveLog_sources_overlayTooltip => 'Overlay on chart';

  @override
  String get diveLog_sources_splitDialog_title => 'Split into separate dive?';

  @override
  String get diveLog_sources_splitDialog_body =>
      'This source\'s profile, events, and tanks will move to a new dive. The logbook entry stays on this dive.';

  @override
  String get diveLog_sources_splitDialog_confirm => 'Split';

  @override
  String get diveLog_sources_splitDone => 'Dive split';

  @override
  String get diveLog_sources_splitFailed => 'Split failed';

  @override
  String get divePlanner_action_addTank => 'Add Tank';

  @override
  String get divePlanner_action_convertToDive => 'Convert to Dive';

  @override
  String get divePlanner_action_deletePlan => 'Delete plan';

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
  String get divePlanner_error_reserveExceedsTank => 'Exceeds tank pressure';

  @override
  String get divePlanner_error_reserveMustBePositive =>
      'Must be greater than 0';

  @override
  String divePlanner_info_reserveDefault(Object unit, Object value) {
    return 'Not entered — assuming $value $unit';
  }

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
  String get divePlanner_field_travelGas => 'Also used as travel gas';

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
  String get divePlanner_label_reserve => 'Reserve:';

  @override
  String get divePlanner_label_runtime => 'Runtime';

  @override
  String get divePlanner_label_sacRate => 'RMV:';

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
  String divePlanner_message_deleteConfirmation(String name) {
    return 'Delete \'$name\'?';
  }

  @override
  String get divePlanner_message_planDeleted => 'Plan deleted';

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
  String get diveSites_detail_location_city => 'City';

  @override
  String get diveSites_detail_location_island => 'Island';

  @override
  String get diveSites_detail_location_bodyOfWater => 'Body of Water';

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
  String get diveSites_edit_access_entryMethod_label => 'Entry Method';

  @override
  String get diveSites_edit_access_exitMethod_label => 'Exit Method';

  @override
  String diveSites_edit_access_entrySuggestionPair(
    int count,
    String entry,
    String exit,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your $count dives here: $entry in, $exit out',
      one: 'Your dive here: $entry in, $exit out',
    );
    return '$_temp0';
  }

  @override
  String diveSites_edit_access_entrySuggestionEntryOnly(
    int count,
    String entry,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your $count dives here: $entry',
      one: 'Your dive here: $entry',
    );
    return '$_temp0';
  }

  @override
  String get diveSites_detail_access_entryMethod => 'Entry';

  @override
  String get diveSites_detail_access_exitMethod => 'Exit';

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
  String get diveSites_edit_appBar_merge => 'Merge';

  @override
  String get diveSites_edit_appBar_mergeSites => 'Merge Sites';

  @override
  String get diveSites_edit_appBar_newSite => 'New Site';

  @override
  String get diveSites_edit_appBar_save => 'Save';

  @override
  String get diveSites_edit_button_addSite => 'Add Site';

  @override
  String get diveSites_edit_button_mergeSites => 'Merge Sites';

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
  String get diveSites_edit_field_city_label => 'City';

  @override
  String get diveSites_edit_field_island_label => 'Island';

  @override
  String get diveSites_edit_field_bodyOfWater_label => 'Body of Water';

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
  String diveSites_similarSite_useHint(Object siteName) {
    return 'Similar to existing site \"$siteName\". Tap to use.';
  }

  @override
  String diveSites_similarSite_warning(Object siteName) {
    return 'A similar site already exists: \"$siteName\"';
  }

  @override
  String get diveSites_edit_gps_gettingLocation => 'Getting...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Choose a location method or look up the coordinates to auto-fill country, region, town and body of water';

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
  String get diveSites_edit_gps_lookupFromCoordinates =>
      'Look up from coordinates';

  @override
  String get diveSites_edit_snackbar_lookupNothingFound =>
      'No location details found for these coordinates';

  @override
  String get diveSites_edit_snackbar_lookupFailed =>
      'Location lookup failed. Check your connection and try again.';

  @override
  String get diveSites_edit_lookupReplace_title => 'Replace location details?';

  @override
  String get diveSites_edit_lookupReplace_body =>
      'The lookup found different values for these fields:';

  @override
  String get diveSites_edit_lookupReplace_replace => 'Replace';

  @override
  String get diveSites_edit_lookupReplace_keep => 'Keep';

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
  String diveSites_edit_merge_confirmBody(int count) {
    return 'This will merge $count sites into one. Dives, media, and expected species will be combined under the surviving site. The other sites will be deleted.';
  }

  @override
  String get diveSites_edit_merge_confirmTitle => 'Merge Sites';

  @override
  String get diveSites_edit_merge_fieldSourceCycleTooltip =>
      'Use value from next selected site';

  @override
  String diveSites_edit_merge_fieldSourceLabel(
    Object siteName,
    int current,
    int total,
  ) {
    return 'From $siteName ($current/$total)';
  }

  @override
  String get diveSites_edit_merge_fieldSourceMenuTooltip =>
      'Select value from selected site';

  @override
  String get diveSites_edit_merge_marineLifeHelperText =>
      'Combined from all selected sites';

  @override
  String diveSites_edit_merge_loadingErrorBody(Object error) {
    return 'Failed to load sites: $error';
  }

  @override
  String get diveSites_edit_merge_loadingErrorTitle => 'Merge Sites';

  @override
  String get diveSites_edit_merge_notEnoughBody => 'Not enough sites to merge.';

  @override
  String get diveSites_edit_merge_notEnoughTitle => 'Merge Sites';

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
  String get diveSites_edit_section_waterType => 'Water Type';

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
  String get diveSites_edit_snackbar_sitesMerged => 'Sites merged';

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
    return '$min-$max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Up to $max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '$min+';
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
  String get diveSites_list_merge_restored => 'Merge undone';

  @override
  String diveSites_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sites',
      one: 'site',
    );
    return 'Merged $count $_temp0';
  }

  @override
  String get diveSites_list_merge_undo => 'Undo';

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
  String get diveSites_list_menu_select => 'Select sites';

  @override
  String get diveSites_list_menu_fillLocationDetails =>
      'Fill in missing location details';

  @override
  String get diveSites_backfill_confirm_title =>
      'Fill in missing location details?';

  @override
  String diveSites_backfill_confirm_body(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count sites with coordinates have an empty country, region, town or body of water.',
      one:
          '1 site with coordinates has an empty country, region, town or body of water.',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0 Submersion will look each one up on OpenStreetMap and fill only the empty fields. This takes about $_temp1.';
  }

  @override
  String get diveSites_backfill_confirm_start => 'Start';

  @override
  String get diveSites_backfill_nothingToFill =>
      'Every site with coordinates already has its location details.';

  @override
  String get diveSites_backfill_progress_title => 'Filling in location details';

  @override
  String diveSites_backfill_progress_count(int done, int total) {
    return '$done of $total';
  }

  @override
  String get diveSites_backfill_cancel => 'Cancel';

  @override
  String diveSites_backfill_summary(int updated, int unchanged, int failed) {
    return 'Updated $updated, unchanged $unchanged, failed $failed';
  }

  @override
  String get diveSites_backfill_offline =>
      'Location lookup is unavailable. Check your connection and try again.';

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
  String get diveSites_list_selection_mergeTooltip => 'Merge Selected';

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
  String get diveSites_map_builtInSites_add => 'Add to my sites';

  @override
  String get diveSites_map_builtInSites_addError =>
      'Couldn\'t add site. Please try again.';

  @override
  String get diveSites_map_builtInSites_added => 'Added to your sites';

  @override
  String get diveSites_map_builtInSites_hide => 'Hide built-in sites';

  @override
  String get diveSites_map_builtInSites_off => 'Built-in sites hidden';

  @override
  String get diveSites_map_builtInSites_on => 'Built-in sites shown';

  @override
  String get diveSites_map_builtInSites_show => 'Show built-in sites';

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
  String diveSites_map_semantics_builtInSiteMarker(Object name) {
    return 'Built-in dive site: $name';
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
  String get diveType_builtin_altitude => 'Altitude';

  @override
  String get diveType_builtin_boat => 'Boat';

  @override
  String get diveType_builtin_cave => 'Cave';

  @override
  String get diveType_builtin_cavern => 'Cavern';

  @override
  String get diveType_builtin_deep => 'Deep';

  @override
  String get diveType_builtin_drift => 'Drift';

  @override
  String get diveType_builtin_freedive => 'Freedive';

  @override
  String get diveType_builtin_ice => 'Ice';

  @override
  String get diveType_builtin_liveaboard => 'Liveaboard';

  @override
  String get diveType_builtin_night => 'Night';

  @override
  String get diveType_builtin_recreational => 'Recreational';

  @override
  String get diveType_builtin_shore => 'Shore';

  @override
  String get diveType_builtin_technical => 'Technical';

  @override
  String get diveType_builtin_training => 'Training';

  @override
  String get diveType_builtin_wreck => 'Wreck';

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
    return 'This will permanently delete $name and all associated data including dive logs, dive computers, equipment, certifications, and sites.';
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
  String divers_detail_deleteDialogConfirmHint(String name) {
    return 'Type \"Delete $name\" to confirm';
  }

  @override
  String divers_detail_deleteDialogConfirmText(String name) {
    return 'Delete $name';
  }

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
  String get enum_certificationLevel_diveGuide => 'Dive Guide';

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
  String get enum_diveMode_gauge => 'Gauge';

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
  String get enum_equipmentType_dpv => 'DPV';

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
  String get enum_sortField_dateTaken => 'Date Taken';

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
  String get enum_sortField_fileName => 'File Name';

  @override
  String get enum_sortField_fileSize => 'File Size';

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
  String get equipment_serviceClocks_title => 'Service clocks';

  @override
  String get equipment_serviceClocks_addClock => 'Add clock';

  @override
  String get equipment_serviceClocks_logService => 'Log service';

  @override
  String get equipment_serviceClocks_edit => 'Edit intervals';

  @override
  String get equipment_serviceClocks_pause => 'Pause';

  @override
  String get equipment_serviceClocks_resume => 'Resume';

  @override
  String get equipment_serviceClocks_remove => 'Remove';

  @override
  String get equipment_serviceClocks_paused => 'Paused';

  @override
  String get equipment_serviceClocks_empty => 'No service clocks';

  @override
  String get equipment_serviceClocks_unconfigured =>
      'No interval set - tap to configure';

  @override
  String equipment_serviceClocks_dueOn(String date) {
    return 'Due $date';
  }

  @override
  String equipment_serviceClocks_overdueSince(String date) {
    return 'Overdue since $date';
  }

  @override
  String get equipment_serviceClocks_overdue => 'Overdue';

  @override
  String equipment_serviceClocks_divesLeft(int remaining, int total) {
    return '$remaining of $total dives left';
  }

  @override
  String get cylinderConfigs_title => 'Cylinder configurations';

  @override
  String get cylinderConfigs_empty => 'No configurations yet';

  @override
  String get cylinderConfigs_emptyBody =>
      'Save a diluent and bailout setup once, then apply it to any dive.';

  @override
  String get cylinderConfigs_new => 'New configuration';

  @override
  String get cylinderConfigs_name => 'Name';

  @override
  String get cylinderConfigs_nameRequired => 'Enter a name';

  @override
  String get cylinderConfigs_forUnit => 'For unit';

  @override
  String get cylinderConfigs_noUnit => 'Generic gas plan';

  @override
  String get cylinderConfigs_gasPlans => 'Gas plans';

  @override
  String get cylinderConfigs_addCylinder => 'Add cylinder';

  @override
  String get cylinderConfigs_role => 'Role';

  @override
  String get cylinderConfigs_startPressure => 'Start pressure';

  @override
  String get cylinderConfigs_label => 'Label';

  @override
  String get cylinderConfigs_fromPreset => 'From preset';

  @override
  String get cylinderConfigs_deleteTitle => 'Delete configuration?';

  @override
  String get cylinderConfigs_deleteBody =>
      'This does not change any dive it was already applied to.';

  @override
  String get cylinderConfigs_applyAction => 'Apply configuration';

  @override
  String cylinderConfigs_applyAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count cylinders',
      one: 'Added 1 cylinder',
    );
    return '$_temp0';
  }

  @override
  String cylinderConfigs_applyKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'kept $count',
      one: 'kept 1',
    );
    return '$_temp0';
  }

  @override
  String get cylinderConfigs_applyNothingToDo =>
      'This dive already matches the configuration';

  @override
  String get cylinderConfigs_sectionTitle => 'Configurations';

  @override
  String get equipment_serviceClocks_hoursSource =>
      'Counted from logged dive time';

  @override
  String equipment_serviceClocks_hoursLeft(String remaining, String total) {
    return '$remaining of $total hours left';
  }

  @override
  String get equipment_serviceClocks_manageKinds => 'Manage service types';

  @override
  String get equipment_serviceClocks_appliesToClock => 'Applies to clock';

  @override
  String get equipment_serviceClocks_noClockOption => 'Not tied to a clock';

  @override
  String get equipment_scheduleDialog_title => 'Edit clock';

  @override
  String get equipment_scheduleDialog_intervalDays => 'Interval (days)';

  @override
  String get equipment_scheduleDialog_intervalDives => 'Interval (dives)';

  @override
  String get equipment_scheduleDialog_intervalHours => 'Interval (hours)';

  @override
  String equipment_scheduleDialog_inheritHint(String value) {
    return 'Default: $value';
  }

  @override
  String get equipment_scheduleDialog_anchorDate => 'Baseline date';

  @override
  String get equipment_scheduleDialog_anchorHint =>
      'Used when no service record of this kind exists yet';

  @override
  String get equipment_scheduleDialog_clearAnchor => 'Clear baseline date';

  @override
  String get equipment_scheduleDialog_save => 'Save';

  @override
  String get equipment_scheduleDialog_cancel => 'Cancel';

  @override
  String get equipment_serviceKinds_title => 'Service types';

  @override
  String get equipment_serviceKinds_builtIn => 'Built-in';

  @override
  String get equipment_serviceKinds_custom => 'Custom';

  @override
  String get equipment_serviceKinds_add => 'Add service type';

  @override
  String get equipment_serviceKinds_editTitle => 'Edit service type';

  @override
  String get equipment_serviceKinds_nameLabel => 'Name';

  @override
  String get equipment_serviceKinds_nameRequired => 'A name is required';

  @override
  String get equipment_serviceKinds_appliesTo => 'Applies to';

  @override
  String get equipment_serviceKinds_autoAttach =>
      'Attach automatically to new gear';

  @override
  String get equipment_serviceKinds_deleteConfirmTitle =>
      'Delete service type?';

  @override
  String get equipment_serviceKinds_deleteConfirmBody =>
      'Clocks using this service type will be removed.';

  @override
  String get equipment_serviceKinds_delete => 'Delete';

  @override
  String get equipment_serviceKinds_cancel => 'Cancel';

  @override
  String get equipment_serviceKinds_save => 'Save';

  @override
  String get equipment_serviceKinds_emptyCustom =>
      'No custom service types yet';

  @override
  String equipment_serviceKinds_everyDays(int days) {
    return 'every $days days';
  }

  @override
  String equipment_serviceKinds_everyDives(int dives) {
    return 'every $dives dives';
  }

  @override
  String equipment_serviceKinds_everyHours(String hours) {
    return 'every $hours hours';
  }

  @override
  String get dashboard_serviceDue_title => 'Service due';

  @override
  String dashboard_serviceDue_more(int count) {
    return '+$count more';
  }

  @override
  String dashboard_alerts_clockDue(String name, String kind) {
    return '$name: $kind due';
  }

  @override
  String dashboard_alerts_clockOverdue(String name, String kind) {
    return '$name: $kind overdue';
  }

  @override
  String equipment_list_worstClock(String kind) {
    return '$kind overdue';
  }

  @override
  String trips_serviceAlert_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items need service before this trip',
      one: '1 item needs service before this trip',
    );
    return '$_temp0';
  }

  @override
  String trips_serviceAlert_dueBefore(String kind, String date) {
    return '$kind due $date';
  }

  @override
  String trips_serviceAlert_overdue(String kind) {
    return '$kind overdue';
  }

  @override
  String get settings_notifications_tripLeadTitle => 'Trip service lead time';

  @override
  String settings_notifications_tripLeadDays(int days) {
    return '$days days before a trip';
  }

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
  String get equipment_detail_thicknessLabel => 'Thickness';

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
  String get equipment_edit_purchasePriceValidation => 'Enter a valid amount';

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
  String get equipment_edit_thicknessDesignationHint => 'e.g., 5, 5/4, 7/5/3';

  @override
  String get equipment_edit_thicknessHint => 'e.g., 5mm, 7mm';

  @override
  String get equipment_edit_thicknessLabel => 'Thickness';

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
  String get equipment_fab_addSet => 'Add Set';

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
  String equipment_list_tile_serviceInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Service in $days days',
      one: 'Service in 1 day',
    );
    return '$_temp0';
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
  String get equipment_serviceDialog_currencyLabel => 'Currency';

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
  String get equipment_serviceDialog_serviceTypeLabel => 'Service type';

  @override
  String get equipment_serviceDialog_serviceTypeHelper =>
      'Logging this resets the clock for this service type';

  @override
  String get equipment_serviceDialog_serviceTypeRequired =>
      'Pick a service type';

  @override
  String get equipment_serviceDialog_serviceTypeNotSet => 'Not set';

  @override
  String get equipment_serviceDialog_categoryHelper =>
      'Used for filtering and export';

  @override
  String get equipment_serviceDialog_manageServiceTypes =>
      'Manage service types';

  @override
  String get equipment_serviceDialog_categoryLabel => 'Category';

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
  String get equipment_serviceCategory_annual => 'Annual Service';

  @override
  String get equipment_serviceCategory_repair => 'Repair';

  @override
  String get equipment_serviceCategory_inspection => 'Inspection';

  @override
  String get equipment_serviceCategory_overhaul => 'Overhaul';

  @override
  String get equipment_serviceCategory_replacement => 'Part Replacement';

  @override
  String get equipment_serviceCategory_cleaning => 'Cleaning';

  @override
  String get equipment_serviceCategory_calibration => 'Calibration';

  @override
  String get equipment_serviceCategory_warranty => 'Warranty Service';

  @override
  String get equipment_serviceCategory_recall => 'Recall/Safety';

  @override
  String get equipment_serviceCategory_other => 'Other';

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
  String equipment_service_nextDueLabel(String date) {
    return 'Next due $date';
  }

  @override
  String get equipment_service_filterTaskAll => 'All tasks';

  @override
  String get equipment_service_filterTypeAll => 'All types';

  @override
  String get equipment_service_filterYearAll => 'All years';

  @override
  String get equipment_service_filterUntagged => 'Not tied to a clock';

  @override
  String get equipment_service_filterClear => 'Clear filter';

  @override
  String get equipment_service_filterNoMatches =>
      'No maintenance matches this filter';

  @override
  String equipment_service_filterMatchCount(int count, int total) {
    return '$count of $total shown';
  }

  @override
  String get equipment_serviceKinds_defaultCategoryLabel => 'Default category';

  @override
  String get equipment_serviceKinds_defaultCategoryNone => 'No default';

  @override
  String get equipment_serviceKinds_defaultCostLabel => 'Default price';

  @override
  String get equipment_serviceKinds_defaultCostHint =>
      'Leave blank for no default';

  @override
  String get equipment_scheduleDialog_defaultCostLabel =>
      'Default price for this item';

  @override
  String get equipment_serviceKinds_defaultCurrencyLabel => 'Currency';

  @override
  String get equipment_service_exportMenuItem => 'Export maintenance log';

  @override
  String get transfer_export_maintenanceTitle => 'Maintenance Log';

  @override
  String get transfer_export_maintenanceSubtitle =>
      'Service history for all equipment as a spreadsheet';

  @override
  String get settings_export_progress_maintenance =>
      'Exporting maintenance log...';

  @override
  String get settings_export_success_maintenance => 'Maintenance log exported';

  @override
  String get settings_export_saved_maintenance => 'Maintenance log saved';

  @override
  String get equipment_serviceKinds_defaultCurrencyInherit =>
      'Use default currency';

  @override
  String get equipment_scheduleDialog_defaultCurrencyLabel =>
      'Currency for this item';

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
  String get equipment_tab_equipment => 'Equipment';

  @override
  String get equipment_tab_sets => 'Sets';

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
  String get gasCalculators_mnd_depthInput => 'Depth';

  @override
  String get gasCalculators_mnd_endAtDepthTitle => 'END at Depth';

  @override
  String get gasCalculators_mnd_endLimit => 'END Limit';

  @override
  String get gasCalculators_mnd_hePercent => 'He %';

  @override
  String get gasCalculators_mnd_infoContent =>
      'Maximum Narcotic Depth (MND) is the deepest you can go before narcosis exceeds your END limit. Equivalent Narcotic Depth (END) tells you the narcotic effect of your gas at a given depth.\n\nWhen \'O2 is narcotic\' is enabled, both oxygen and nitrogen contribute to narcosis (more conservative). When disabled, only nitrogen is considered narcotic.';

  @override
  String get gasCalculators_mnd_infoTitle => 'About MND/END';

  @override
  String get gasCalculators_mnd_unlimited => 'unlimited';

  @override
  String get gasCalculators_mnd_inputParameters =>
      'Gas Mix & Narcosis Settings';

  @override
  String get gasCalculators_mnd_o2Narcotic => 'O2 is narcotic';

  @override
  String get gasCalculators_mnd_o2Percent => 'O2 %';

  @override
  String get gasCalculators_mnd_resultTitle => 'Maximum Narcotic Depth';

  @override
  String get gasCalculators_ppO2Limit => 'ppO₂ Limit';

  @override
  String get gasCalculators_resetAll => 'Reset all calculators';

  @override
  String get gasCalculators_sacRate => 'RMV';

  @override
  String get gasCalculators_tab_bestMix => 'Best Mix';

  @override
  String get gasCalculators_tab_consumption => 'Consumption';

  @override
  String get gasCalculators_tab_mnd => 'MND/END';

  @override
  String get gasCalculators_tab_blender => 'Trimix blender';

  @override
  String get gasCalculators_blender_cylinder => 'Cylinder';

  @override
  String get gasCalculators_blender_startCylinder => 'In the cylinder';

  @override
  String get gasCalculators_blender_targetFill => 'Target fill';

  @override
  String get gasCalculators_blender_fillGases => 'Fill gases';

  @override
  String get gasCalculators_blender_pressure => 'Pressure';

  @override
  String get gasCalculators_blender_o2 => 'O₂';

  @override
  String get gasCalculators_blender_he => 'He';

  @override
  String get gasCalculators_blender_air => 'Air';

  @override
  String get gasCalculators_blender_helium => 'Helium';

  @override
  String get gasCalculators_blender_procedure => 'Fill procedure';

  @override
  String get gasCalculators_blender_amounts => 'Gas to add';

  @override
  String gasCalculators_blender_stepStart(String pressure, String gas) {
    return 'Start with $pressure $gas';
  }

  @override
  String gasCalculators_blender_stepFill(
    String gas,
    String pressure,
    String mix,
  ) {
    return 'Fill $gas to $pressure → $mix';
  }

  @override
  String get gasCalculators_blender_error_targetPressure =>
      'Target pressure must be higher than the starting pressure.';

  @override
  String get gasCalculators_blender_error_invalidMix =>
      'A gas mix\'s O₂ + He cannot exceed 100%.';

  @override
  String get gasCalculators_blender_error_identicalGases =>
      'The two fill gases are identical — there is nothing to blend.';

  @override
  String get gasCalculators_blender_error_linearlyDependent =>
      'These fill gases cannot produce the target mix — a trimix target needs a helium source.';

  @override
  String get gasCalculators_blender_error_negativeAmount =>
      'This blend is not achievable with these gases — it would require removing gas.';

  @override
  String gasCalculators_blender_error_drainTo(String pressure) {
    return 'Too much gas in the cylinder for this blend. Drain to $pressure first, then blend.';
  }

  @override
  String get gasCalculators_blender_error_drainEmpty =>
      'None of the gas in the cylinder can be used for this blend. Empty it first, then blend.';

  @override
  String get gasCalculators_blender_error_cannotRemoveHelium =>
      'The cylinder holds helium and the target mix has none. Topping up dilutes helium but cannot remove it, so the cylinder must be emptied first.';

  @override
  String get gasCalculators_blender_error_insufficientGases =>
      'A helium-free target needs two helium-free fill gases with different O₂ content.';

  @override
  String get gasCalculators_blender_error_targetNotReached =>
      'These fill gases cannot reach the target mix exactly. Check the fill gases and their order.';

  @override
  String get gasCalculators_blender_error_implausibleStartMix =>
      'The cylinder is holding pressure but no oxygen and no helium, which would be pure nitrogen. Check the mix already in the cylinder.';

  @override
  String get gasCalculators_blender_about => 'About blending';

  @override
  String get gasCalculators_blender_aboutBody =>
      'Partial-pressure blend for the target mix. Add each fill gas in order, up to the pressure shown, then let the cylinder settle. Fill gases and their order are configurable, so setting the last gas to 32/0 tops off with EAN32 instead of air. Always analyse the finished mix before diving it.';

  @override
  String get gasCalculators_blender_conditions => 'Blending conditions';

  @override
  String get gasCalculators_blender_fillTemp => 'Fill temperature';

  @override
  String get gasCalculators_blender_fillTempHelp =>
      'The cylinder\'s temperature while you fill it. Every pressure in the procedure is the gauge reading at this temperature.';

  @override
  String get gasCalculators_blender_settledTemp => 'Settled temperature';

  @override
  String get gasCalculators_blender_settledTempHelp =>
      'The temperature the cylinder ends up at. The target pressure is what it reads once it gets there.';

  @override
  String get gasCalculators_blender_gasModel => 'Gas model';

  @override
  String get gasCalculators_blender_modelIdeal => 'Ideal gas';

  @override
  String get gasCalculators_blender_modelVanDerWaals => 'Van der Waals';

  @override
  String get gasCalculators_blender_modelZFactor => 'Real gas (Z-factor)';

  @override
  String get gasCalculators_blender_modelRecommended => 'Recommended';

  @override
  String get gasCalculators_blender_modelHelp =>
      'Real gas (Z-factor) is the most accurate at cylinder pressures. Ideal gas matches most published blending tables. Van der Waals is offered for comparison with other blending software and is several percent off at fill pressure.';

  @override
  String gasCalculators_blender_stepAdd(String gas) {
    return 'Add $gas';
  }

  @override
  String get gasCalculators_blender_stepStartLabel => 'Start';

  @override
  String gasCalculators_blender_settlesTo(String pressure, String temperature) {
    return 'Settles to $pressure at $temperature';
  }

  @override
  String get gasCalculators_blender_templates => 'Templates';

  @override
  String get gasCalculators_blender_templatesTitle => 'Target mix templates';

  @override
  String get gasCalculators_blender_saveTemplate => 'Save current mix';

  @override
  String get gasCalculators_blender_manageTemplates => 'Manage templates';

  @override
  String gasCalculators_blender_templateSaved(String mix) {
    return 'Saved $mix';
  }

  @override
  String get gasCalculators_blender_templateExists =>
      'That mix is already saved.';

  @override
  String get gasCalculators_blender_templateInvalid =>
      'O₂ + He cannot exceed 100%.';

  @override
  String get gasCalculators_blender_templateNeedsNumbers =>
      'Enter both O₂ and He as numbers.';

  @override
  String gasCalculators_blender_templateLimit(int count) {
    return 'You can save up to $count templates.';
  }

  @override
  String get gasCalculators_blender_templateNone =>
      'No templates yet. Save a target mix to reuse it here.';

  @override
  String gasCalculators_blender_templateDelete(String mix) {
    return 'Delete $mix';
  }

  @override
  String get gasCalculators_blender_templateAdd => 'Add template';

  @override
  String get gasCalculators_blender_billing => 'Cost';

  @override
  String get gasCalculators_blender_cylinderVolume => 'Cylinder water capacity';

  @override
  String get gasCalculators_blender_cylinderPresets => 'Presets';

  @override
  String gasCalculators_blender_unitPrice(String unit) {
    return 'Price per 100 $unit';
  }

  @override
  String get gasCalculators_blender_currency => 'Currency';

  @override
  String get gasCalculators_blender_costTotal => 'Total';

  @override
  String get gasCalculators_blender_costBasis =>
      'Billed on the pressure delivered (cylinder water capacity × bar added), the way a fill station meters it.';

  @override
  String get gasCalculators_blender_costMissingPrice =>
      'Enter a price for every gas to see the total.';

  @override
  String get gasCalculators_blender_saveFill => 'Save this fill';

  @override
  String get gasCalculators_blender_billed => 'Billed';

  @override
  String get gasCalculators_blender_billedNone =>
      'Nothing billed yet. Finish a fill and save it here.';

  @override
  String get gasCalculators_blender_billedTo => 'Billed to';

  @override
  String get gasCalculators_blender_addManualLine => 'Add a line';

  @override
  String get gasCalculators_blender_lineDescription => 'Description';

  @override
  String get gasCalculators_blender_lineAmount => 'Amount';

  @override
  String get gasCalculators_blender_clearBilled => 'Clear';

  @override
  String get gasCalculators_blender_clearBilledTitle => 'Clear the bill?';

  @override
  String gasCalculators_blender_clearBilledBody(int count) {
    return 'This removes all $count saved fills.';
  }

  @override
  String gasCalculators_blender_editLine(String label) {
    return 'Edit $label';
  }

  @override
  String gasCalculators_blender_deleteLine(String label) {
    return 'Delete $label';
  }

  @override
  String gasCalculators_blender_fillAdded(String mix) {
    return '$mix added to the bill';
  }

  @override
  String get gasCalculators_blender_billedIncomplete =>
      'One or more lines have no price, so this total is incomplete.';

  @override
  String get gasCalculators_blender_billedTotal => 'Total';

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
  String get media_diveMediaSection_cancelSelectionButton => 'Cancel';

  @override
  String get media_diveMediaSection_emptyState => 'No photos yet';

  @override
  String get media_diveMediaSection_errorLoading => 'Error loading media';

  @override
  String get media_diveMediaSection_selectAllButton => 'Select All';

  @override
  String media_diveMediaSection_selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'View photo. Long press to select';

  @override
  String get media_diveMediaSection_title => 'Photos & Video';

  @override
  String get media_diveMediaSection_replaceButton => 'Re-link';

  @override
  String get media_diveMediaSection_replaceEditedContent =>
      'This file\'s contents differ from the original. Re-linking will re-upload it to your media store.';

  @override
  String get media_diveMediaSection_replaceEditedTitle =>
      'File contents differ';

  @override
  String get media_diveMediaSection_unlinkButton => 'Unlink';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Failed to unlink: $error';
  }

  @override
  String media_diveMediaSection_unlinkSelectedButton(int count) {
    return 'Unlink $count';
  }

  @override
  String media_diveMediaSection_unlinkSelectedContent(int count) {
    return 'Removes $count media items from your library, along with their cloud copies and thumbnails. Media a dive site still uses is kept. Your original files are not affected.';
  }

  @override
  String media_diveMediaSection_unlinkSelectedSuccess(int count) {
    return 'Unlinked $count items';
  }

  @override
  String media_diveMediaSection_unlinkSelectedTitle(int count) {
    return 'Unlink $count items?';
  }

  @override
  String media_library_unlinkConfirmTitle(int count) {
    return 'Unlink $count items?';
  }

  @override
  String media_siteMediaSection_unlinkError(Object error) {
    return 'Failed to unlink: $error';
  }

  @override
  String get media_library_unlinkConfirmBody =>
      'They leave your library, along with their cloud copies and thumbnails. Your original files are not affected. This cannot be undone.';

  @override
  String media_library_unlinkMetadataNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count of these have a caption or favorite saved in Submersion, and those details are lost.',
      one:
          '1 of these has a caption or favorite saved in Submersion, and those details are lost.',
    );
    return '$_temp0';
  }

  @override
  String get media_siteMediaSection_title => 'Site Media';

  @override
  String get media_siteMediaSection_addPhotos => 'Add photos or videos';

  @override
  String get media_siteMediaSection_addDocument => 'Add document';

  @override
  String get media_siteMediaSection_emptyState =>
      'No maps, photos, or documents attached to this site';

  @override
  String media_siteMediaSection_divePhotosGroup(int count) {
    return 'Photos from dives here ($count)';
  }

  @override
  String get media_siteMediaSection_divePhotoLabel => 'Dive photo';

  @override
  String media_siteMediaSection_unlinkSelectedTitle(int count) {
    return 'Unlink $count items?';
  }

  @override
  String media_siteMediaSection_unlinkSelectedContent(int count) {
    return 'Removes $count items from your library, along with their cloud copies and thumbnails. Media a dive still uses is kept. Your original files are not affected.';
  }

  @override
  String media_siteMediaSection_unlinkSelectedSuccess(int count) {
    return 'Unlinked $count items';
  }

  @override
  String get media_documentViewer_title => 'Document';

  @override
  String get media_documentViewer_unavailable =>
      'This document is not available on this device';

  @override
  String get media_documentViewer_availableOnOriginDevice =>
      'It is available on the device it was added from, or via a configured media store.';

  @override
  String media_documentViewer_attached(int count) {
    return 'Attached $count documents';
  }

  @override
  String get media_diveScan_scanTooltip => 'Scan gallery for photos';

  @override
  String get media_diveScan_noPhotosFound =>
      'No new photos found near this dive';

  @override
  String get media_diveScan_accessDenied =>
      'Photo library access is required to scan for photos';

  @override
  String media_diveScan_foundPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'photos',
      one: 'photo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'them',
      one: 'it',
    );
    return 'Found $count $_temp0 near this dive. Link $_temp1?';
  }

  @override
  String get media_diveScan_foundTitle => 'Photos Found';

  @override
  String media_diveScan_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Photos',
      one: 'Photo',
    );
    return 'Link $_temp0';
  }

  @override
  String get media_diveScan_cancelButton => 'Cancel';

  @override
  String media_diveScan_error(String error) {
    return 'Error scanning gallery: $error';
  }

  @override
  String get media_gpsBanner_addToSiteButton => 'Add to Site';

  @override
  String media_gpsBanner_coordinates(Object coordinates) {
    return 'Coordinates: $coordinates';
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
  String media_import_allAlreadyLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos already linked to this dive',
      one: '1 photo already linked to this dive',
    );
    return '$_temp0';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return 'Imported $imported, failed $failed';
  }

  @override
  String media_import_importedAndSkipped(int imported, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      imported,
      locale: localeName,
      other: 'Imported $imported photos',
      one: 'Imported 1 photo',
    );
    return '$_temp0 ($skipped already linked)';
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
  String get media_lightroom_openInLightroom => 'Open in Lightroom';

  @override
  String get media_lightroom_suggestion_accept => 'Add to this dive';

  @override
  String get media_lightroom_suggestion_dismiss => 'Dismiss';

  @override
  String get media_lightroom_suggestions_title => 'Suggested from Lightroom';

  @override
  String get media_miniProfile_headerLabel => 'Dive Profile';

  @override
  String get media_miniProfile_semanticLabel => 'Mini dive profile chart';

  @override
  String get media_photoPicker_appBarTitle => 'Select Photos';

  @override
  String get media_photoPicker_tab_gallery => 'Gallery';

  @override
  String get media_photoPicker_tab_files => 'Files';

  @override
  String get media_photoPicker_tab_url => 'URL';

  @override
  String get media_photoPicker_clearSelectionButton => 'Clear';

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
  String get media_photoPicker_grantAccessButton => 'Continue';

  @override
  String get media_photoPicker_openSettingsButton => 'Open Settings';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'Photo library access was denied. Please enable it in Settings to add dive photos.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion needs access to your photo library to add dive photos.';

  @override
  String get media_photoPicker_permissionTitle => 'Dive Photos';

  @override
  String get media_photoPicker_selectAllButton => 'Select All';

  @override
  String media_photoPicker_selectedCount(int count) {
    return '$count selected';
  }

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
  String get media_photoPicker_files_pickFilesButton => 'Pick files…';

  @override
  String get media_photoPicker_files_pickFolderButton => 'Pick a folder…';

  @override
  String get media_photoPicker_files_autoMatchLabel =>
      'Auto-match photos and videos to dives by date';

  @override
  String get media_photoPicker_files_emptyHint =>
      'Pick files or a folder to start.';

  @override
  String media_photoPicker_files_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Link $count items',
      one: 'Link 1 item',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachToSiteButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Attach $count items to this site',
      one: 'Attach 1 item to this site',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_summary(
    int fileCount,
    int diveCount,
    Object unmatchedCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: '$fileCount files',
      one: '1 file',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount dives',
      one: '1 dive',
    );
    return '$_temp0, $_temp1, $unmatchedCount unmatched';
  }

  @override
  String media_photoPicker_files_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_diveGroupTitle(String diveId) {
    return 'Dive $diveId';
  }

  @override
  String media_photoPicker_files_groupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_unmatchedGroupTitle => 'Unmatched';

  @override
  String media_photoPicker_files_addAllToDive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add all $count to this dive',
      one: 'Add 1 to this dive',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_addToDiveTooltip => 'Add to this dive';

  @override
  String get media_photoPicker_files_chooseDiveTooltip => 'Choose a dive';

  @override
  String get media_photoPicker_files_removeTooltip => 'Remove from selection';

  @override
  String get media_photoPicker_files_sourceExif => 'from EXIF';

  @override
  String get media_photoPicker_files_sourceContainer => 'from file metadata';

  @override
  String get media_photoPicker_files_sourceFileDate => 'from file date';

  @override
  String get media_photoPicker_files_sourceNone => 'no date found';

  @override
  String media_photoPicker_files_shiftedTime(String shifted, String original) {
    return '$shifted (was $original)';
  }

  @override
  String get media_photoPicker_files_reasonNoTimestamp =>
      'No capture time could be read';

  @override
  String media_photoPicker_files_reasonBeforeDive(String gap) {
    return '$gap before the nearest dive';
  }

  @override
  String media_photoPicker_files_reasonAfterDive(String gap) {
    return '$gap after the nearest dive';
  }

  @override
  String get media_photoPicker_files_reasonNoDives =>
      'No dives to match against';

  @override
  String get media_photoPicker_files_offsetLabel => 'Shift capture times by';

  @override
  String get media_photoPicker_files_offsetResetTooltip => 'Reset to no shift';

  @override
  String media_photoPicker_files_offsetBackTooltip(String amount) {
    return 'Shift $amount earlier';
  }

  @override
  String media_photoPicker_files_offsetForwardTooltip(String amount) {
    return 'Shift $amount later';
  }

  @override
  String media_photoPicker_files_linkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Linked $count items',
      one: 'Linked 1 item',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachedToSiteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Attached $count items to this site',
      one: 'Attached 1 item to this site',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_undo => 'Undo';

  @override
  String get media_photoPicker_thumbnailAlreadyLinkedLabel =>
      'Photo already linked to this dive';

  @override
  String get media_perdixOverlay_labelCns => 'CNS';

  @override
  String get media_perdixOverlay_labelDepth => 'DEPTH';

  @override
  String get media_perdixOverlay_labelGas => 'GAS';

  @override
  String get media_perdixOverlay_labelMax => 'MAX';

  @override
  String get media_perdixOverlay_labelNdl => 'NDL';

  @override
  String get media_perdixOverlay_labelPpo2 => 'PPO2';

  @override
  String get media_perdixOverlay_labelStop => 'STOP';

  @override
  String get media_perdixOverlay_labelTank => 'TANK';

  @override
  String get media_perdixOverlay_labelTemp => 'TEMP';

  @override
  String get media_perdixOverlay_labelTime => 'TIME';

  @override
  String get media_perdixOverlay_labelTts => 'TTS';

  @override
  String get media_perdixOverlay_toggleTooltip => 'Dive computer overlay';

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
  String get media_photoViewer_nextTooltip => 'Next media';

  @override
  String get media_photoViewer_noPhotosAvailable => 'No photos available';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel => 'Play or pause video';

  @override
  String get media_photoViewer_previousTooltip => 'Previous media';

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
  String get media_unavailablePlaceholder_fileNotFound => 'File not found';

  @override
  String get media_unavailablePlaceholder_fromOtherDevice =>
      'From another device';

  @override
  String media_unavailablePlaceholder_fromOtherDeviceLabel(String device) {
    return 'From $device';
  }

  @override
  String get media_unavailablePlaceholder_networkError => 'Couldn\'t connect';

  @override
  String get media_unavailablePlaceholder_notOnDevice => 'Not on this device';

  @override
  String get media_unavailablePlaceholder_signInRequired => 'Sign in to view';

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
  String get media_writeMetadata_livePhotoUnsupported =>
      'Live Photos are not supported yet. Duplicate this as a still photo, then write the dive data to the copy.';

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
  String get nav_gpsLog => 'GPS Log';

  @override
  String get media_console_library => 'Library';

  @override
  String get media_console_transfers => 'Transfers';

  @override
  String get media_console_import => 'Import';

  @override
  String get media_import_launch => 'Import media...';

  @override
  String get media_import_review_title => 'Review import';

  @override
  String media_import_review_confirm(int count) {
    return 'Import $count items';
  }

  @override
  String media_import_review_result(int linked, int skipped, int failed) {
    return '$linked linked, $skipped skipped, $failed failed';
  }

  @override
  String get media_import_review_chooseSite => 'Choose site';

  @override
  String get media_import_review_ambiguous => 'Several dives match';

  @override
  String get media_import_review_noMatch => 'No matching dive';

  @override
  String get media_import_review_skipped => 'Not imported';

  @override
  String media_import_review_linkChip(int number) {
    return 'Link to #$number';
  }

  @override
  String get media_import_review_linkToDive => 'Link to dive';

  @override
  String get media_import_review_linkToSite => 'Link to site';

  @override
  String get media_import_review_chooseDive => 'Choose dive';

  @override
  String get media_import_intro =>
      'Photos are linked to a dive or a dive site as you import them.';

  @override
  String get media_console_sources => 'Sources';

  @override
  String get media_sources_browseHeader => 'Browse by source';

  @override
  String get media_sources_watchedHeader => 'Watched folders';

  @override
  String get media_sources_addWatched => 'Add folder...';

  @override
  String get media_sources_scanFailed => 'Scan failed';

  @override
  String get media_sources_scanNow => 'Scan now';

  @override
  String get media_sources_autoApply => 'Automatically re-link exact matches';

  @override
  String get media_sources_neverScanned => 'Never scanned';

  @override
  String get media_source_gallery => 'Photo library';

  @override
  String get media_source_localFile => 'Local files';

  @override
  String get media_source_networkUrl => 'Web links';

  @override
  String get media_source_manifest => 'Subscriptions';

  @override
  String get media_source_connector => 'Connected services';

  @override
  String get media_source_mediaStore => 'Cloud media store';

  @override
  String get media_source_signature => 'Signatures';

  @override
  String get media_repairHistory_title => 'Repair history';

  @override
  String get media_repairHistory_empty => 'No repairs yet';

  @override
  String get media_repairHistory_action_relink => 'Re-linked';

  @override
  String get media_repairHistory_action_cloudBacked => 'Cloud-backed';

  @override
  String get media_repairHistory_action_autoRelink => 'Auto re-linked';

  @override
  String get media_smartAlbum_save => 'Save as album';

  @override
  String get media_smartAlbum_saveTitle => 'Name this album';

  @override
  String get media_smartAlbum_albums => 'Albums';

  @override
  String get media_smartAlbum_delete => 'Delete album';

  @override
  String get media_smartAlbum_deleteFailed => 'Could not delete album';

  @override
  String get media_smartAlbum_saved => 'Album saved';

  @override
  String media_sources_lastScanned(String date) {
    return 'Last scanned $date';
  }

  @override
  String media_sources_scanResult(int indexed, int repaired) {
    return '$indexed files indexed, $repaired re-linked';
  }

  @override
  String get media_repairHistory_sourceFolder => 'folder scan';

  @override
  String get media_repairHistory_sourcePhotoLibrary => 'photo library';

  @override
  String get media_repairHistory_sourceStore => 'cloud media store';

  @override
  String get media_repairHistory_sourceWatcher => 'watched folders';

  @override
  String get media_repairHistory_sourceManual => 'manual re-link';

  @override
  String media_repairHistory_source(String source) {
    return 'via $source';
  }

  @override
  String get media_missing_empty => 'No missing files';

  @override
  String media_missing_offlineVolumes(int count) {
    return '$count on offline volumes';
  }

  @override
  String get media_missing_repair => 'Repair...';

  @override
  String get media_repair_title => 'Repair missing files';

  @override
  String get media_repair_addFolder => 'Add folder...';

  @override
  String get media_repair_usePhotoLibrary => 'Search photo library';

  @override
  String get media_repair_useStore => 'Use cloud media store';

  @override
  String get media_repair_scan => 'Scan';

  @override
  String media_repair_prefixMove(String from, String to, int count) {
    return 'Folder move detected: $from to $to covers $count files';
  }

  @override
  String get media_repair_confidence_exact => 'Exact';

  @override
  String get media_repair_confidence_probable => 'Name and size';

  @override
  String get media_repair_confidence_edited => 'Edited file';

  @override
  String get media_repair_confidence_unmatched => 'No candidate';

  @override
  String get media_repair_unverified => 'Not verified against the store';

  @override
  String media_repair_apply(int count) {
    return 'Re-link $count files';
  }

  @override
  String media_repair_summary(
    int relinked,
    int cloudBacked,
    int reuploads,
    int failed,
    int skipped,
  ) {
    return '$relinked re-linked, $cloudBacked cloud-backed, $reuploads re-uploads queued, $failed failed, $skipped skipped';
  }

  @override
  String get media_library_empty => 'No media yet';

  @override
  String get media_library_filter_all => 'All';

  @override
  String get media_library_filter_photos => 'Photos';

  @override
  String get media_library_filter_videos => 'Videos';

  @override
  String get media_library_filter_site => 'Site';

  @override
  String get media_library_filter_trip => 'Trip';

  @override
  String get media_library_filter_dates => 'Dates';

  @override
  String get media_library_filter_missing => 'Missing files';

  @override
  String media_library_filter_missingCount(int count) {
    return 'Missing files ($count)';
  }

  @override
  String get media_library_filter_clear => 'Clear filters';

  @override
  String get media_library_filter_any => 'Any';

  @override
  String get media_library_filter_title => 'Filter media';

  @override
  String get media_library_filter_apply => 'Apply';

  @override
  String get media_library_sort_title => 'Sort media';

  @override
  String get media_smartAlbum_load => 'Load album';

  @override
  String get media_divePicker_title => 'Move to dive';

  @override
  String get media_divePicker_search => 'Search dives';

  @override
  String get media_library_moveToDive => 'Move to dive';

  @override
  String get media_library_unlinkSelected => 'Unlink';

  @override
  String media_library_selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get media_library_unlinkedHeader => 'Unlinked';

  @override
  String get media_library_diveHeaderHint => 'Open this dive';

  @override
  String get media_library_untitledDiveHeader => 'Untitled dive';

  @override
  String get media_library_viewMode_byDive => 'By dive';

  @override
  String get media_library_viewMode_grid => 'Grid';

  @override
  String get media_library_viewMode_timeline => 'Timeline';

  @override
  String get media_viewer_goToDive => 'Go to dive';

  @override
  String get nav_home => 'Home';

  @override
  String get nav_media => 'Media';

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
  String plannerCanvas_bailout_available(String liters) {
    return 'Available $liters';
  }

  @override
  String get plannerCanvas_bailout_insufficient =>
      'Bailout gas insufficient for the worst case';

  @override
  String plannerCanvas_bailout_required(String liters) {
    return 'Required $liters';
  }

  @override
  String get plannerCanvas_bailout_title => 'Bailout (open circuit)';

  @override
  String plannerCanvas_bailout_tts(String minutes) {
    return 'Bailout TTS $minutes′';
  }

  @override
  String plannerCanvas_bailout_worstCase(String minutes, String depth) {
    return 'Worst case at $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_ccr_setpointHigh => 'Setpoint high (bar)';

  @override
  String get plannerCanvas_ccr_setpointLow => 'Setpoint low (bar)';

  @override
  String get plannerCanvas_ccr_switchDepth => 'Setpoint switch depth';

  @override
  String get plannerCanvas_pscr_ratio => 'pSCR ratio';

  @override
  String get plannerCanvas_pscr_ratio_hint =>
      'Larger adds more fresh gas and lowers the O₂ drop';

  @override
  String plannerCanvas_chip_cns(String value) {
    return 'CNS $value%';
  }

  @override
  String plannerCanvas_chip_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count issues',
      one: '1 issue',
    );
    return '$_temp0';
  }

  @override
  String get plannerCanvas_compare_action => 'Compare';

  @override
  String get plannerCanvas_compare_needTwo =>
      'Select at least two plans to compare';

  @override
  String get plannerCanvas_compare_title => 'Compare plans';

  @override
  String get plannerCanvas_contingency_base => 'Base';

  @override
  String get plannerCanvas_contingency_depthDelta => 'Extra depth';

  @override
  String plannerCanvas_contingency_lostGas(String gas) {
    return 'Lost $gas';
  }

  @override
  String plannerCanvas_contingency_previewing(String label) {
    return 'Previewing: $label';
  }

  @override
  String get plannerCanvas_contingency_timeDelta => 'Extra minutes';

  @override
  String plannerCanvas_chart_meanDepth(String depth) {
    return 'mean $depth';
  }

  @override
  String get plannerCanvas_contingency_title => 'Contingencies';

  @override
  String get plannerCanvas_contingency_turnFraction => 'Turn fraction';

  @override
  String get plannerCanvas_contingency_turnRule => 'Turn pressure rule';

  @override
  String get plannerCanvas_convert_success => 'Dive created from plan';

  @override
  String get plannerCanvas_convert_view => 'View';

  @override
  String plannerCanvas_follow_chip(String name) {
    return 'Following $name';
  }

  @override
  String get plannerCanvas_follow_empty => 'No logged dives yet';

  @override
  String get plannerCanvas_follow_noTissues =>
      'No profile data on that dive — surface interval set without tissue seeding';

  @override
  String get plannerCanvas_follow_title => 'Follow a dive';

  @override
  String plannerCanvas_gas_minGas(String pressure) {
    return 'min gas $pressure';
  }

  @override
  String plannerCanvas_gas_turnAt(String pressure) {
    return 'turn @ $pressure';
  }

  @override
  String plannerCanvas_issue_gasDensityCritical(String value) {
    return 'Gas density $value g/L over hard limit';
  }

  @override
  String plannerCanvas_issue_gasDensityHigh(String value) {
    return 'Gas density $value g/L over recommended limit';
  }

  @override
  String plannerCanvas_issue_hypoxic(String depth, String value) {
    return 'Hypoxic gas at $depth (ppO₂ $value bar)';
  }

  @override
  String plannerCanvas_issue_minGas(String pressure) {
    return 'Tank ends below the rock-bottom minimum of $pressure';
  }

  @override
  String get plannerCanvas_issue_noBailout =>
      'CCR decompression plan carries no bailout gas';

  @override
  String get plannerCanvas_issue_noDecoGas =>
      'Decompression required but no deco gas carried';

  @override
  String get plannerCanvas_range_base => 'Base';

  @override
  String get plannerCanvas_range_legend =>
      'Cells show time to surface; red = not diveable as planned';

  @override
  String get plannerCanvas_pane_collapse => 'Collapse panel';

  @override
  String get plannerCanvas_pane_expand => 'Expand panel';

  @override
  String get plannerCanvas_tab_setup => 'Setup';

  @override
  String get plannerCanvas_o2Narcotic => 'Treat O₂ as narcotic';

  @override
  String get plannerCanvas_rates_ascent => 'Ascent rate';

  @override
  String get plannerCanvas_rates_descent => 'Descent rate';

  @override
  String get plannerCanvas_rates_title => 'Rates';

  @override
  String get plannerCanvas_range_title => 'Range table';

  @override
  String get plannerCanvas_results_noDeco => 'No decompression required';

  @override
  String plannerCanvas_sac_useLogged(String sac) {
    return 'Use logged average ($sac)';
  }

  @override
  String plannerCanvas_saved_deleteConfirmBody(String name) {
    return 'Permanently delete \"$name\"?';
  }

  @override
  String get plannerCanvas_saved_deleteConfirmTitle => 'Delete plan?';

  @override
  String get plannerCanvas_saved_duplicate => 'Duplicate';

  @override
  String get plannerCanvas_saved_empty => 'No saved plans yet';

  @override
  String get plannerCanvas_saved_title => 'Saved plans';

  @override
  String get plannerCanvas_name_dialogTitle => 'Name your plan';

  @override
  String get plannerCanvas_name_defaultFallback => 'Dive Plan';

  @override
  String plannerCanvas_scrub_bailout(String minutes) {
    return 'BO $minutes′';
  }

  @override
  String plannerCanvas_scrub_readout(String minutes, String depth) {
    return 'RT $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_share_import => 'Import';

  @override
  String plannerCanvas_share_importFailed(String reason) {
    return 'Couldn\'t import plan: $reason';
  }

  @override
  String get plannerCanvas_share_menu => 'Share plan file';

  @override
  String get plannerCanvas_slate_menu => 'Export slate (PDF)';

  @override
  String get plannerCanvas_slate_minGas => 'Min gas';

  @override
  String get plannerCanvas_slate_turn => 'Turn';

  @override
  String get plannerCanvas_table_depth => 'Depth';

  @override
  String get plannerCanvas_table_gas => 'Gas';

  @override
  String get plannerCanvas_table_runtime => 'RT';

  @override
  String get plannerCanvas_table_stop => 'Stop';

  @override
  String get plannerCanvas_turnRule_allUsable => 'All usable';

  @override
  String get plannerCanvas_turnRule_custom => 'Custom';

  @override
  String get plannerCanvas_turnRule_halves => 'Halves';

  @override
  String get plannerCanvas_turnRule_none => 'None';

  @override
  String get plannerCanvas_turnRule_thirds => 'Thirds';

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
  String get planning_newPlan => 'New plan';

  @override
  String get planning_section_tools => 'Tools';

  @override
  String get planning_summary_prompt => 'Select a tool to get started';

  @override
  String get planning_summary_savedPlans => 'Saved plans';

  @override
  String get planning_summary_noPlans => 'No saved plans yet';

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
  String get settings_about_description => 'Dive deeper.';

  @override
  String get settings_about_header => 'About';

  @override
  String get settings_about_openSourceLicenses => 'Open Source Licenses';

  @override
  String get settings_about_reportIssue => 'Report an Issue';

  @override
  String get settings_about_reportIssue_copy => 'Copy link';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Visit github.com/submersion-app/submersion/issues';

  @override
  String settings_about_version(String version) {
    return 'Version $version';
  }

  @override
  String get settings_appBar_title => 'Settings';

  @override
  String get settings_appearance_appLanguage => 'App Language';

  @override
  String get settings_appearance_displaySize => 'Display size';

  @override
  String settings_appearance_displaySize_value(int percent) {
    return '$percent%';
  }

  @override
  String get settings_appearance_displaySize_reset => 'Reset';

  @override
  String get settings_appearance_displaySize_smaller => 'Smaller';

  @override
  String get settings_appearance_displaySize_larger => 'Larger';

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
  String get settings_appearance_gasTimeline => 'Gas timeline';

  @override
  String get settings_appearance_gasTimeline_subtitle =>
      'Show the gas-usage strip below the dive profile by default';

  @override
  String get settings_appearance_header_diveDetails => 'Dive Details';

  @override
  String get settings_appearance_header_diveLog => 'Dive Log';

  @override
  String get settings_appearance_header_diveProfile => 'Dive Profile';

  @override
  String get settings_appearance_header_diveSites => 'Dive Sites';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility =>
      'Section Order & Visibility';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility_subtitle =>
      'Choose which sections appear and their order';

  @override
  String get settings_diveDetailSections_title => 'Section Order & Visibility';

  @override
  String get settings_diveDetailSections_resetToDefault => 'Reset to Default';

  @override
  String get settings_diveDetailSections_fixedSections =>
      'Fixed sections: Header, Dive Profile Chart';

  @override
  String get settings_diveDetailSections_configurableSections =>
      'Configurable sections (drag to reorder)';

  @override
  String get diveDetailSection_decoO2_name => 'Deco Status / Tissue Loading';

  @override
  String get diveDetailSection_decoO2_description =>
      'NDL, ceiling, tissue heat map, O2 toxicity';

  @override
  String get diveDetailSection_safetyReview_name => 'Safety Review';

  @override
  String get diveDetailSection_safetyReview_description =>
      'Automatic post-dive profile observations';

  @override
  String get safetyReview_sectionTitle => 'Safety review';

  @override
  String safetyReview_findingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observations',
      one: '1 observation',
    );
    return '$_temp0';
  }

  @override
  String safetyReview_rapidAscent_title(String rate, String duration) {
    return 'Ascent exceeded $rate for $duration';
  }

  @override
  String safetyReview_missedDecoStop_title(String excess, String duration) {
    return 'Depth was $excess above the required stop ceiling for $duration';
  }

  @override
  String safetyReview_omittedSafetyStop_title(String remaining) {
    return 'The recommended safety stop was cut short by $remaining';
  }

  @override
  String safetyReview_sawtoothProfile_title(int count) {
    return '$count repeated up-and-down depth changes during the dive';
  }

  @override
  String safetyReview_highSurfaceGf_title(String gf, String gfHigh) {
    return 'Surfaced at gradient factor $gf, above the configured $gfHigh';
  }

  @override
  String safetyReview_timeRange(String start, String end) {
    return 'At $start–$end';
  }

  @override
  String get safetyReview_dismiss => 'Dismiss';

  @override
  String get safetyReview_restore => 'Restore';

  @override
  String get safetyReview_dismissAll => 'Dismiss all';

  @override
  String get safetyReview_restoreAll => 'Restore all';

  @override
  String get safetySettings_dismissAll => 'Dismiss all observations';

  @override
  String get safetySettings_dismissAll_subtitle =>
      'Mark every observation in this logbook as reviewed';

  @override
  String get safetySettings_dismissAll_confirmTitle =>
      'Dismiss all observations?';

  @override
  String get safetySettings_dismissAll_confirmBody =>
      'Every observation on every analyzed dive is marked as reviewed. You can restore them one dive at a time from that dive’s safety review section.';

  @override
  String get safetySettings_dismissAll_confirm => 'Dismiss all';

  @override
  String get safetySettings_dismissAll_cancel => 'Cancel';

  @override
  String safetySettings_dismissAll_progress(int done, int total) {
    return 'Checked $done of $total dives';
  }

  @override
  String safetySettings_dismissAll_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observations dismissed',
      one: '1 observation dismissed',
      zero: 'No observations to dismiss',
    );
    return '$_temp0';
  }

  @override
  String safetySettings_dismissAll_doneWithErrors(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observations dismissed',
      one: '1 observation dismissed',
      zero: 'No observations dismissed',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed dives could not be updated',
      one: '1 dive could not be updated',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get safetySettings_dismissAll_failed =>
      'Could not read your dive list. No dives were changed.';

  @override
  String get safetySettings_analyzeAll_failed =>
      'Could not analyze your dives.';

  @override
  String get safetyReview_details => 'Details';

  @override
  String get safetyReview_clearHighlight => 'Clear highlight';

  @override
  String safetyReview_findingGroupSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count safety observations',
      one: '1 safety observation',
    );
    return '$_temp0';
  }

  @override
  String get safetySettings_title => 'Safety review';

  @override
  String get safetySettings_entry_subtitle =>
      'Post-dive observations and rules';

  @override
  String get safetySettings_masterToggle => 'Post-dive safety review';

  @override
  String get safetySettings_masterToggle_subtitle =>
      'Automatically note ascent, stop, and profile observations on analyzed dives';

  @override
  String get safetySettings_rulesHeader => 'Rules';

  @override
  String get safetySettings_rule_rapidAscent => 'Rapid ascents';

  @override
  String get safetySettings_rule_missedDecoStop =>
      'Missed or shortened deco stops';

  @override
  String get safetySettings_rule_omittedSafetyStop => 'Omitted safety stops';

  @override
  String get safetySettings_rule_sawtoothProfile => 'Sawtooth profiles';

  @override
  String get safetySettings_rule_highSurfaceGf =>
      'High surfacing gradient factor';

  @override
  String get safetySettings_analyzeAll => 'Analyze all dives';

  @override
  String get safetySettings_analyzeAll_subtitle =>
      'Run the safety review over every dive with a profile that has not been analyzed yet';

  @override
  String safetySettings_analyzeAll_progress(int done, int total) {
    return 'Analyzed $done of $total';
  }

  @override
  String get safetySettings_analyzeAll_done => 'Analysis complete';

  @override
  String safetySettings_analyzeAll_doneWithErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives could not be analyzed',
      one: '1 dive could not be analyzed',
    );
    return 'Analysis complete — $_temp0';
  }

  @override
  String safetyReview_showDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count dismissed',
      one: 'Show 1 dismissed',
    );
    return '$_temp0';
  }

  @override
  String get diveDetailSection_sacSegments_name => 'SAC Rate by Segment';

  @override
  String get diveDetailSection_sacSegments_description =>
      'Phase/time SAC segmentation';

  @override
  String get diveDetailSection_details_name => 'Details';

  @override
  String get diveDetailSection_details_description =>
      'Type, location, trip, dive center, interval';

  @override
  String get diveDetailSection_environment_name => 'Environment';

  @override
  String get diveDetailSection_environment_description =>
      'Air/water temp, visibility, current';

  @override
  String get diveDetailSection_altitude_name => 'Altitude';

  @override
  String get diveDetailSection_altitude_description =>
      'Altitude value, category, deco requirement';

  @override
  String get diveDetailSection_tide_name => 'Tide';

  @override
  String get diveDetailSection_tide_description =>
      'Tide cycle graph and timing';

  @override
  String get diveDetailSection_reefHealth_name => 'Water Conditions';

  @override
  String get diveDetailSection_reefHealth_description =>
      'Satellite water conditions on the dive date';

  @override
  String get diveDetailSection_surfaceGps_name => 'Surface GPS';

  @override
  String get diveDetailSection_surfaceGps_description =>
      'GPS entry/exit points and surface drift';

  @override
  String get diveLog_detail_section_surfaceGps => 'Surface GPS';

  @override
  String get diveLog_detail_surfaceGps_entry => 'Entry';

  @override
  String get diveLog_detail_surfaceGps_exit => 'Exit';

  @override
  String get diveLog_detail_label_drift => 'Drift';

  @override
  String get diveLog_detail_surfaceGps_entryOnly => 'Entry point recorded';

  @override
  String get diveLog_detail_surfaceGps_exitOnly => 'Exit point recorded';

  @override
  String get diveLog_detail_surfaceGps_site => 'Site';

  @override
  String get diveLog_detail_surfaceGps_track => 'Surface track';

  @override
  String get diveLog_detail_surfaceGps_showFullTrack => 'Full track';

  @override
  String diveLog_detail_surfaceGps_trackFixes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fixes',
      one: '1 fix',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_detail_locationsMap_title => 'Dive Locations';

  @override
  String get diveLog_detail_coordinatesCopied =>
      'Coordinates copied to clipboard';

  @override
  String get diveLog_detail_openInMaps => 'Open in Maps';

  @override
  String get diveDetailSection_weights_name => 'Weights';

  @override
  String get diveDetailSection_weights_description =>
      'Weight breakdown, total weight';

  @override
  String get diveDetailSection_buoyancy_name => 'Buoyancy';

  @override
  String get diveDetailSection_buoyancy_description =>
      'Buoyancy through the dive, swing, ditchable weight';

  @override
  String get buoyancy_tooltip =>
      'Modeled net buoyancy through the dive from your profile, gas use, and gear.';

  @override
  String buoyancy_verdictBuoyant(String depth, String amount) {
    return 'At your final stop (~$depth) you were about $amount buoyant';
  }

  @override
  String buoyancy_verdictHeavy(String depth, String amount) {
    return 'At your final stop (~$depth) you were about $amount heavy';
  }

  @override
  String get buoyancy_verdictNeutral =>
      'Your rig was close to neutral at the final stop';

  @override
  String get buoyancy_verdictConvention =>
      'Estimated at the 5 m safety-stop convention';

  @override
  String get buoyancy_breakdownTitle => 'Term breakdown';

  @override
  String get buoyancy_suitTerm => 'Suit';

  @override
  String get buoyancy_leadTerm => 'Lead';

  @override
  String get buoyancy_beginNet => 'Start of dive';

  @override
  String get buoyancy_endNet => 'End of dive';

  @override
  String get buoyancy_swing => 'Buoyancy swing';

  @override
  String get buoyancy_peakLift => 'Peak lift needed';

  @override
  String get buoyancy_wingWarning => 'Exceeds your wing\'s rated lift';

  @override
  String get buoyancy_minDitchable => 'Min ditchable weight';

  @override
  String get buoyancy_droppable => 'You can ditch';

  @override
  String get buoyancy_ditchWarning => 'More than you can ditch';

  @override
  String get buoyancy_drysuitGas => 'Drysuit gas added';

  @override
  String get buoyancy_estimatedPressures => 'Tank pressures are estimated';

  @override
  String get buoyancy_linkSuitHint =>
      'Link an exposure suit to this dive for a fuller picture';

  @override
  String get buoyancy_noLeadHint =>
      'No lead recorded: add weights to this dive, or a dry weight to your weights gear';

  @override
  String get buoyancy_chartNet => 'Net';

  @override
  String get buoyancy_chartRig => 'Rig + lead';

  @override
  String get buoyancy_chartMinutes => 'Time (min)';

  @override
  String get buoyancy_historyTitle => 'Weighting history';

  @override
  String get buoyancy_historyCarried => 'Carried';

  @override
  String get buoyancy_historyModeled => 'Modeled';

  @override
  String buoyancy_historyMore(String delta) {
    return 'You typically carry $delta more than the model suggests';
  }

  @override
  String buoyancy_historyLess(String delta) {
    return 'You typically carry $delta less than the model suggests';
  }

  @override
  String get buoyancy_throughDive => 'Through the dive';

  @override
  String get buoyancy_adjust => 'Adjust';

  @override
  String get buoyancy_whatIfTitle => 'Adjust this dive';

  @override
  String get buoyancy_whatIfLead => 'Lead';

  @override
  String get buoyancy_whatIfSuit => 'Suit buoyancy';

  @override
  String get buoyancy_whatIfReset => 'Reset';

  @override
  String buoyancy_whatIfDelta(String delta) {
    return '$delta vs. actual';
  }

  @override
  String get diveDetailSection_tanks_name => 'Cylinders';

  @override
  String get diveDetailSection_tanks_description =>
      'Cylinder list, gas mixes, pressures, MOD/MND, per-tank SAC';

  @override
  String get diveDetailSection_buddies_name => 'Buddies';

  @override
  String get diveDetailSection_buddies_description => 'Buddy list with roles';

  @override
  String get diveDetailSection_signatures_name => 'Signatures';

  @override
  String get diveDetailSection_signatures_description =>
      'Buddy/instructor signature display and capture';

  @override
  String get diveDetailSection_equipment_name => 'Equipment';

  @override
  String get diveDetailSection_equipment_description =>
      'Equipment used in dive';

  @override
  String get diveDetailSection_sightings_name => 'Marine Life Sightings';

  @override
  String get diveDetailSection_sightings_description =>
      'Species spotted, sighting details';

  @override
  String get diveDetailSection_media_name => 'Media';

  @override
  String get diveDetailSection_media_description => 'Photos/videos gallery';

  @override
  String get diveDetailSection_tags_name => 'Tags';

  @override
  String get diveDetailSection_tags_description => 'Dive tags';

  @override
  String get diveDetailSection_notes_name => 'Notes';

  @override
  String get diveDetailSection_notes_description => 'Dive notes/description';

  @override
  String get diveDetailSection_customFields_name => 'Custom Fields';

  @override
  String get diveDetailSection_customFields_description =>
      'User-defined custom fields';

  @override
  String get diveDetailSection_dataSources_name => 'Data Sources';

  @override
  String get diveDetailSection_dataSources_description =>
      'Connected dive computers, source management';

  @override
  String get settings_appearance_header_language => 'Language';

  @override
  String get settings_appearance_header_theme => 'Color Theme';

  @override
  String get settings_appearance_header_mode => 'Mode';

  @override
  String get settings_themes_title => 'Choose Theme';

  @override
  String get settings_themes_current => 'Color Theme';

  @override
  String get theme_submersion => 'Submersion';

  @override
  String get theme_console => 'Console';

  @override
  String get theme_tropical => 'Tropical';

  @override
  String get theme_minimalist => 'Minimalist';

  @override
  String get theme_deep => 'Deep';

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
  String get settings_appearance_metric_estimatedTankPressure =>
      'Estimated Tank Pressure';

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
  String get settings_appearance_metric_cns => 'CNS% (O2 Toxicity)';

  @override
  String get settings_appearance_metric_otu => 'OTU (O2 Tolerance Units)';

  @override
  String get settings_appearance_metric_photoMarkers => 'Photo Markers';

  @override
  String settings_appearance_metricsEnabledCount(int count, int total) {
    return '$count of $total enabled';
  }

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
  String get settings_appearance_metricsFollowViewport =>
      'Keep overlays in view when zooming';

  @override
  String get settings_appearance_metricsFollowViewport_subtitle =>
      'Fit overlays such as NDL and ppO2 to the visible area instead of magnifying them with the depth axis';

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
  String get settings_appearance_subsection_standardMetrics =>
      'Standard Metrics';

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
  String get settings_navCustomization_title => 'Navigation bar';

  @override
  String get settings_navCustomization_description =>
      'Drag items to reorder. The top three appear in your bottom navigation bar.';

  @override
  String get settings_navCustomization_dividerLabel =>
      'Items below appear in the More menu';

  @override
  String get settings_navCustomization_resetButton => 'Reset to defaults';

  @override
  String get settings_navCustomization_pinnedTooltip => 'Always shown';

  @override
  String settings_navCustomization_moveUpLabel(String destination) {
    return 'Move $destination up';
  }

  @override
  String settings_navCustomization_moveDownLabel(String destination) {
    return 'Move $destination down';
  }

  @override
  String settings_navCustomization_subtitlePreview(
    String first,
    String second,
    String third,
  ) {
    return '$first · $second · $third';
  }

  @override
  String get settings_navCustomization_saveError =>
      'Could not save navigation layout. Please try again.';

  @override
  String get settings_backToSettings_tooltip => 'Back to settings';

  @override
  String get settings_cloudSync_appBar_title => 'Database Cloud Sync';

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
  String get settings_cloudSync_entry_subtitle => 'Sync via cloud storage';

  @override
  String get settings_cloudSync_adopt_confirm => 'Adopt Restored Library';

  @override
  String settings_cloudSync_adopt_dialogContent(
    String deviceName,
    String date,
  ) {
    return 'The library was replaced from a backup on \"$deviceName\" ($date). Adopting replaces this device\'s data with the restored library. A safety backup of this device\'s current data will be created first.';
  }

  @override
  String get settings_cloudSync_adopt_dialogTitle => 'Adopt Restored Library?';

  @override
  String get settings_cloudSync_adopt_notNow => 'Not Now';

  @override
  String get settings_cloudSync_dangerZone => 'Danger Zone';

  @override
  String get settings_cloudSync_replaceLibrary_tile => 'Replace cloud library';

  @override
  String get settings_cloudSync_replaceLibrary_tileSubtitle =>
      'Make this device\'s library the one every device uses';

  @override
  String get settings_cloudSync_replaceLibrary_dialogTitle =>
      'Replace Cloud Library?';

  @override
  String get settings_cloudSync_replaceLibrary_dialogIntro =>
      'This device\'s library becomes the one every device uses.';

  @override
  String settings_cloudSync_replaceLibrary_dialogBody(num diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other:
          'The cloud library is erased and replaced with this device\'s $diveCount dives.',
      one:
          'The cloud library is erased and replaced with this device\'s 1 dive.',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_replaceLibrary_peers(num peerCount) {
    String _temp0 = intl.Intl.pluralLogic(
      peerCount,
      locale: localeName,
      other:
          '$peerCount other devices will be asked to adopt it; until they do, their changes are not merged.',
      one:
          '1 other device will be asked to adopt it; until it does, its changes are not merged.',
      zero: 'No other device is syncing yet, so there is nothing to adopt it.',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_replaceLibrary_peersUnknown =>
      'Every other device will be asked to adopt it; until they do, their changes are not merged.';

  @override
  String get settings_cloudSync_replaceLibrary_backupNote =>
      'A backup of this device is created first. This cannot be undone.';

  @override
  String get settings_cloudSync_replaceLibrary_confirmWord => 'Replace';

  @override
  String get settings_cloudSync_replaceLibrary_confirmHint =>
      'Type \"Replace\" to confirm';

  @override
  String get settings_cloudSync_replaceLibrary_confirm => 'Replace';

  @override
  String get settings_cloudSync_firstSync_banner =>
      'First sync is waiting for confirmation. Tap Sync Now to review what will be combined.';

  @override
  String get settings_cloudSync_firstSync_dialogConfirm => 'Merge and Sync';

  @override
  String get settings_cloudSync_firstSync_replaceHint =>
      'If instead this device\'s library should replace what is in the cloud, cancel and use Settings > Cloud Sync > Replace cloud library.';

  @override
  String settings_cloudSync_firstSync_dialogContent(
    int deviceCount,
    int diveCount,
  ) {
    return 'Existing sync data was found in the cloud ($deviceCount sync file(s)). Your first sync will combine that data with the $diveCount dive(s) on this device, across every synced device.\n\nIf the same dives were added separately on each device, they will appear twice.';
  }

  @override
  String get settings_cloudSync_firstSync_dialogTitle => 'Combine Libraries?';

  @override
  String settings_cloudSync_replace_banner(String deviceName) {
    return 'Sync is paused: the library was replaced from a backup on \"$deviceName\". Tap Sync Now to review.';
  }

  @override
  String get settings_cloudSync_switch_dialogTitle => 'Switch sync backend?';

  @override
  String settings_cloudSync_switch_dialogContent(
    String fromName,
    String toName,
  ) {
    return 'Your data will not be moved off $fromName -- it stays there until you delete it. After switching, this device\'s next sync combines its data with whatever already exists on $toName. Your other devices keep using $fromName until you switch each of them too.';
  }

  @override
  String get settings_cloudSync_switch_confirm => 'Switch';

  @override
  String settings_cloudSync_moved_banner(
    String deviceName,
    String destination,
  ) {
    return '$deviceName moved this library to $destination. This backend is no longer being updated by it. Select $destination below to follow the move.';
  }

  @override
  String get settings_cloudSync_moved_dismiss => 'Dismiss';

  @override
  String settings_cloudSync_cleanup_banner(String backend) {
    return 'Old sync data is still stored on $backend from before you switched backends. It is no longer used.';
  }

  @override
  String get settings_cloudSync_cleanup_delete => 'Delete old data';

  @override
  String get settings_cloudSync_cleanup_keep => 'Keep';

  @override
  String get settings_cloudSync_header_advanced => 'Advanced';

  @override
  String get settings_cloudSync_signOut_backupWarning =>
      'Cloud backup will be turned off and backups will be saved to the default location.';

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
  String settings_cloudSync_peerNeedsAdopt_banner(Object deviceList) {
    return '$deviceList still has an older or unknown library version, so its changes were not merged. Open Submersion on it to adopt the current library.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_bannerPlural(Object deviceList) {
    return '$deviceList still have an older or unknown library version, so their changes were not merged. Open Submersion on them to adopt the current library.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_unnamedDevice(Object shortId) {
    return 'device $shortId';
  }

  @override
  String get settings_cloudSync_peerNeedsAdopt_listSeparator => ', ';

  @override
  String get settings_cloudSync_peerNeedsAdopt_listLastSeparator => ' and ';

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamed(Object deviceList) {
    return '$deviceList syncs from a newer version of Submersion, so its latest changes are held for now.';
  }

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(
    Object deviceList,
  ) {
    return '$deviceList sync from a newer version of Submersion, so their latest changes are held for now.';
  }

  @override
  String get settings_cloudSync_peerRequiresUpdate_updateAction =>
      'Update this device to receive them.';

  @override
  String get settings_cloudSync_peerRequiresUpdate_storeAction =>
      'They will apply automatically once this device\'s app store update arrives; the update may still be in review.';

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
  String get settings_cloudSync_dropbox_account_title => 'Dropbox account';

  @override
  String get settings_cloudSync_dropbox_connect_browserFailed =>
      'Could not open your browser. Try the Reopen browser button.';

  @override
  String get settings_cloudSync_dropbox_connect_codeLabel =>
      'Authorization code';

  @override
  String get settings_cloudSync_dropbox_connect_emptyCode =>
      'Enter the authorization code shown in your browser';

  @override
  String settings_cloudSync_dropbox_connect_failed(Object error) {
    return 'Could not connect to Dropbox: $error';
  }

  @override
  String get settings_cloudSync_dropbox_connect_instructions =>
      'Your browser opened a Dropbox authorization page. Approve access, then paste the code Dropbox shows you here.';

  @override
  String get settings_cloudSync_dropbox_connect_reopenBrowser =>
      'Reopen browser';

  @override
  String get settings_cloudSync_dropbox_connect_submit => 'Connect';

  @override
  String get settings_cloudSync_dropbox_connect_title => 'Connect Dropbox';

  @override
  String get settings_cloudSync_dropbox_connected => 'Connected to Dropbox';

  @override
  String settings_cloudSync_dropbox_connectedAs(Object account) {
    return 'Connected as $account';
  }

  @override
  String get settings_cloudSync_dropbox_disconnect => 'Disconnect';

  @override
  String get settings_cloudSync_provider_dropbox_subtitle =>
      'Sync via Dropbox (Apps/Submersion)';

  @override
  String get settings_cloudSync_provider_dropbox_title => 'Dropbox';

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Sync via Google Drive';

  @override
  String get settings_cloudSync_googleDrive_desktopNotConfigured =>
      'Not available in this build';

  @override
  String get settings_cloudSync_googleDrive_browserWait_title =>
      'Continue in your browser';

  @override
  String get settings_cloudSync_googleDrive_browserWait_message =>
      'Finish signing in to Google in your web browser, then return to Submersion.';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Failed to initialize $providerName provider';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Not available on this platform';

  @override
  String get settings_cloudSync_provider_s3_edit => 'Edit S3 configuration';

  @override
  String get settings_cloudSync_provider_s3_subtitle =>
      'Works with any S3-compatible storage service';

  @override
  String get settings_cloudSync_provider_s3_title => 'S3-Compatible Storage';

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
  String get settings_conflict_ref_buddy => 'Buddy';

  @override
  String get settings_conflict_ref_certification => 'Certification';

  @override
  String get settings_conflict_ref_checklistTemplate => 'Checklist template';

  @override
  String get settings_conflict_ref_connectedAccount => 'Connected account';

  @override
  String get settings_conflict_ref_course => 'Course';

  @override
  String get settings_conflict_ref_courseRequirement => 'Course requirement';

  @override
  String get settings_conflict_ref_cylinderConfig => 'Cylinder configuration';

  @override
  String get settings_conflict_ref_dataSource => 'Data source';

  @override
  String get settings_conflict_ref_dive => 'Dive';

  @override
  String get settings_conflict_ref_diveCenter => 'Dive center';

  @override
  String get settings_conflict_ref_diveComputer => 'Dive computer';

  @override
  String get settings_conflict_ref_divePlan => 'Dive plan';

  @override
  String get settings_conflict_ref_diveSite => 'Dive site';

  @override
  String get settings_conflict_ref_diveType => 'Dive type';

  @override
  String get settings_conflict_ref_diver => 'Diver';

  @override
  String get settings_conflict_ref_equipment => 'Equipment';

  @override
  String get settings_conflict_ref_equipmentSet => 'Equipment set';

  @override
  String get settings_conflict_ref_finding => 'Finding';

  @override
  String get settings_conflict_ref_instructor => 'Instructor';

  @override
  String get settings_conflict_ref_linkedDive => 'Linked dive';

  @override
  String get settings_conflict_ref_media => 'Media';

  @override
  String get settings_conflict_ref_mediaSubscription => 'Media subscription';

  @override
  String get settings_conflict_ref_missing => 'No longer in this library';

  @override
  String settings_conflict_ref_named(Object name, Object date) {
    return '$name ($date)';
  }

  @override
  String get settings_conflict_ref_plannedTank => 'Planned tank';

  @override
  String get settings_conflict_ref_preDiveChecklistTemplate =>
      'Pre-dive checklist template';

  @override
  String get settings_conflict_ref_preDiveSession => 'Pre-dive checklist run';

  @override
  String get settings_conflict_ref_relatedDive => 'Related dive';

  @override
  String get settings_conflict_ref_serviceKind => 'Service type';

  @override
  String get settings_conflict_ref_sighting => 'Sighting';

  @override
  String get settings_conflict_ref_signer => 'Signed by';

  @override
  String get settings_conflict_ref_sourceDive => 'Source dive';

  @override
  String get settings_conflict_ref_species => 'Species';

  @override
  String get settings_conflict_ref_tag => 'Tag';

  @override
  String get settings_conflict_ref_tank => 'Tank';

  @override
  String get settings_conflict_ref_trip => 'Trip';

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
  String get settings_data_backup => 'Backup & Restore';

  @override
  String get settings_data_backup_subtitle => 'Create a backup of your data';

  @override
  String get settings_data_cloudSync => 'Database Cloud Sync';

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
  String get settings_decompression_header_oxygenToxicity => 'Oxygen Toxicity';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Select $presetName conservatism preset';
  }

  @override
  String get settings_decompression_header_narcosis => 'Narcosis';

  @override
  String get settings_decompression_o2Narcotic => 'O2 is narcotic';

  @override
  String get settings_decompression_o2Narcotic_subtitle =>
      'When enabled, both O2 and N2 are considered narcotic (more conservative). When disabled, only N2 contributes to narcosis.';

  @override
  String get settings_decompression_endLimit => 'END Limit';

  @override
  String get settings_decompression_endLimit_subtitle =>
      'Maximum equivalent narcotic depth used for MND calculations';

  @override
  String get settings_decompression_endLimit_dialog_title => 'END Limit';

  @override
  String get settings_decompression_cnsMethodTitle => 'CNS calculation';

  @override
  String get settings_decompression_cnsMethodClassic =>
      'NOAA table, stepped (classic)';

  @override
  String get settings_decompression_cnsMethodClassicDesc =>
      'Charges each 0.1 bar band at its harsher edge. Submersion\'s original method.';

  @override
  String get settings_decompression_cnsMethodShearwater =>
      'Linear interpolation (Shearwater-style)';

  @override
  String get settings_decompression_cnsMethodShearwaterDesc =>
      'Interpolates between the NOAA limits as documented by Shearwater. Matches most dive computers.';

  @override
  String get settings_decompression_cnsMethodSubsurface =>
      'Exponential fit (as Subsurface)';

  @override
  String get settings_decompression_cnsMethodSubsurfaceDesc =>
      'Smooth curve fit to the NOAA table. Matches Subsurface\'s calculated CNS.';

  @override
  String get settings_decompression_cnsMethodAboutTitle =>
      'About these methods';

  @override
  String get settings_decompression_cnsMethodAboutBody =>
      'All three methods are built on the oxygen exposure limits of the NOAA Diving Manual (300 minutes at a ppO2 of 1.0 bar, 45 minutes at 1.6 bar). The table only defines limits in 0.1 bar steps: the classic method charges everything in a band at the band\'s harsher edge, which systematically overstates exposure between entries. Shearwater\'s dive computers document interpolating linearly between the NOAA limits, with a fixed 15% per minute above 1.65 bar. Subsurface replaced its table lookup in 2019 with a smooth two-line exponential fit to the same NOAA data (Robert C. Helling), which also extends naturally beyond 1.6 bar. Between table entries the two smooth methods agree within about one CNS point; the classic method reads higher.';

  @override
  String get settings_decompression_cnsMethodDisclaimer =>
      'Names refer to the published methods of the respective projects and manufacturers; no affiliation or endorsement is implied. Computed values may differ from actual dive computer readings.';

  @override
  String get settings_decompression_cnsMethodSourcesTitle => 'Sources';

  @override
  String get settings_linkOpenFailed => 'Could not open the link.';

  @override
  String get settings_decompression_cnsMethodSourceNoaa =>
      'NOAA: Diving Program (publisher of the NOAA Diving Manual)';

  @override
  String get settings_decompression_cnsMethodSourceShearwater =>
      'Shearwater: The CNS Oxygen Clock';

  @override
  String get settings_decompression_cnsMethodSourceTheoreticalDiver =>
      'The Theoretical Diver: Calculating oxygen CNS toxicity';

  @override
  String get settings_decompression_cnsMethodSourceSubsurface =>
      'Subsurface: implementation (divelist.cpp)';

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
  String get settings_import_cancelButton => 'Cancel import';

  @override
  String get settings_import_cancelling => 'Cancelling...';

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
  String get settings_import_phase_courses => 'Importing courses...';

  @override
  String get settings_import_phase_applyingTags => 'Applying tags...';

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
  String get settings_lightroom_albumFilter_all => 'Entire catalog';

  @override
  String get settings_lightroom_albumFilter_title => 'Albums to scan';

  @override
  String get settings_lightroom_autoPoll_title =>
      'Check for new photos automatically';

  @override
  String settings_lightroom_clientId_help(String redirectUri) {
    return 'Create an integration in the Adobe Developer Console with the Lightroom Services API and a credential type that supports PKCE. Enter your credential\'s redirect URI below — Native App credentials use a custom scheme — or leave it blank to use $redirectUri.';
  }

  @override
  String get settings_lightroom_clientId_label => 'Adobe client ID';

  @override
  String get settings_lightroom_clientSecret_label =>
      'Client secret (optional)';

  @override
  String get settings_lightroom_redirectUri_label => 'Redirect URI (optional)';

  @override
  String get settings_lightroom_connect => 'Connect Lightroom';

  @override
  String get settings_lightroom_connectEmbedded => 'Connect with Adobe';

  @override
  String get settings_lightroom_advancedByo => 'Use your own Adobe credentials';

  @override
  String get settings_lightroom_connect_codeLabel => 'Redirected URL or code';

  @override
  String get settings_lightroom_connect_emptyCode =>
      'Paste the redirected URL or authorization code';

  @override
  String settings_lightroom_connect_failed(String error) {
    return 'Could not connect to Lightroom: $error';
  }

  @override
  String get settings_lightroom_connect_instructions =>
      'Sign in to Adobe in the browser window, then paste the full address of the page you land on (it contains the authorization code).';

  @override
  String get settings_lightroom_connect_reopenBrowser => 'Reopen browser';

  @override
  String get settings_lightroom_connect_submit => 'Connect';

  @override
  String get settings_lightroom_connect_title => 'Connect Lightroom';

  @override
  String settings_lightroom_connected(String name) {
    return 'Connected as $name';
  }

  @override
  String get settings_lightroom_disconnect => 'Disconnect';

  @override
  String get settings_lightroom_disconnect_confirmBody =>
      'Linked photos stay on your dives and keep displaying from the media store. New photos will no longer be matched.';

  @override
  String get settings_lightroom_disconnect_confirmTitle =>
      'Disconnect Lightroom?';

  @override
  String settings_lightroom_lastPoll(String when) {
    return 'Last checked: $when';
  }

  @override
  String get settings_lightroom_needsReauth => 'Reconnect needed';

  @override
  String get settings_lightroom_scanNow => 'Scan Lightroom';

  @override
  String get settings_lightroom_scan_running => 'Scanning Lightroom...';

  @override
  String settings_lightroom_scan_summary(
    int attached,
    int suggested,
    int skipped,
  ) {
    return '$attached linked, $suggested suggested, $skipped already linked';
  }

  @override
  String get settings_lightroom_subtitle =>
      'Auto-link photos and videos to dives';

  @override
  String get settings_lightroom_title => 'Adobe Lightroom';

  @override
  String get settings_manage_checklistTemplates => 'Checklist Templates';

  @override
  String get settings_manage_checklistTemplates_subtitle =>
      'Reusable to-do lists for trip planning';

  @override
  String get settings_manage_diveRoles => 'Dive Roles';

  @override
  String get settings_manage_diveRoles_subtitle => 'Manage custom dive roles';

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
  String get settings_manage_tags => 'Tags';

  @override
  String get settings_manage_tags_subtitle => 'Manage, merge, and delete tags';

  @override
  String get settings_manage_tankPresets => 'Tank Presets';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Manage custom tank configurations';

  @override
  String get settings_manage_serviceTypes => 'Service types';

  @override
  String get settings_manage_serviceTypes_subtitle =>
      'Maintenance your gear needs, and how often';

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
  String get settings_notifications_disabled_continueButton => 'Continue';

  @override
  String get settings_notifications_disabled_openSettingsButton =>
      'Open Settings';

  @override
  String get settings_notifications_disabled_subtitleUnrequested =>
      'Service reminders need permission to send notifications';

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
  String get settings_profileHub_addNewDiver => 'Add New Diver';

  @override
  String get settings_profileHub_cannotDeleteOnly =>
      'Cannot delete the only diver profile';

  @override
  String get settings_profileHub_createDiverTitle => 'Create Diver';

  @override
  String settings_profileHub_deleteConfirmContent(String name) {
    return 'Are you sure you want to delete $name? All associated dive logs will be unassigned.';
  }

  @override
  String get settings_profileHub_deleteConfirmTitle => 'Delete Diver?';

  @override
  String get settings_profileHub_deleteDiver => 'Delete Diver';

  @override
  String get settings_profileHub_deleted => 'Diver deleted';

  @override
  String get settings_profileHub_emergencyContacts => 'Emergency Contacts';

  @override
  String settings_profileHub_emergencyContacts_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts set',
      one: '1 contact set',
      zero: 'Not set',
    );
    return '$_temp0';
  }

  @override
  String get settings_profileHub_insurance => 'Insurance';

  @override
  String get settings_profileHub_insurance_expired => 'Expired';

  @override
  String get settings_profileHub_insurance_notSet => 'Not set';

  @override
  String get settings_profileHub_medicalInfo => 'Medical Information';

  @override
  String get settings_profileHub_medicalInfo_notSet => 'Not set';

  @override
  String get settings_profileHub_notes => 'Notes';

  @override
  String get settings_profileHub_notes_notSet => 'Not set';

  @override
  String get settings_profileHub_personalInfo => 'Personal Info';

  @override
  String get settings_profileHub_personalInfo_notSet => 'Not set';

  @override
  String get settings_profileHub_saved => 'Changes saved';

  @override
  String get settings_profileHub_switchDiver => 'Switch Diver';

  @override
  String get settings_s3Config_action_remove => 'Remove Configuration';

  @override
  String get settings_s3Config_action_testConnection => 'Test Connection';

  @override
  String get settings_s3Config_advanced_title => 'Advanced';

  @override
  String get settings_s3Config_appBar_title => 'S3-Compatible Storage';

  @override
  String get settings_s3Config_error_secureStorage =>
      'Could not access secure storage';

  @override
  String get settings_s3Config_field_accessKeyId_label => 'Access Key ID';

  @override
  String get settings_s3Config_field_bucket_label => 'Bucket';

  @override
  String get settings_s3Config_field_endpoint_helper =>
      'For example: https://s3.example.com';

  @override
  String get settings_s3Config_field_endpoint_label => 'Endpoint URL';

  @override
  String get settings_s3Config_field_pathStyle_label =>
      'Use path-style addressing';

  @override
  String get settings_s3Config_field_pathStyle_subtitle =>
      'Required by most self-hosted servers';

  @override
  String get settings_s3Config_field_prefix_label => 'Key prefix';

  @override
  String settings_s3Config_field_region_helperAuto(String region) {
    return 'Auto-detected: $region';
  }

  @override
  String get settings_s3Config_field_region_label => 'Region';

  @override
  String get settings_s3Config_field_secretAccessKey_label =>
      'Secret Access Key';

  @override
  String get settings_s3Config_remove_confirm_action => 'Remove';

  @override
  String get settings_s3Config_remove_confirm_body =>
      'Sync via S3 will stop on this device. Your data in the bucket is not deleted.';

  @override
  String get settings_s3Config_remove_confirm_title =>
      'Remove S3 configuration?';

  @override
  String get settings_s3Config_removed => 'S3 configuration removed';

  @override
  String get settings_s3Config_saved => 'S3 configuration saved';

  @override
  String settings_s3Config_test_regionDetected(String region) {
    return 'Region detected: $region';
  }

  @override
  String get settings_s3Config_test_success => 'Connection successful';

  @override
  String get settings_s3Config_validation_endpointInvalid =>
      'Enter a valid http:// or https:// URL';

  @override
  String get settings_s3Config_validation_endpointPath =>
      'Endpoint URL must not include a path';

  @override
  String get settings_s3Config_validation_required => 'Required';

  @override
  String get settings_s3Config_warning_http =>
      'This endpoint uses plain HTTP. Credentials and dive data will travel unencrypted; use only on a trusted network.';

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
  String get settings_section_decompression_subtitle =>
      'GF, data sources & narcosis';

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
  String get settings_storage_customFolder_subtitleDeviceOnly =>
      'Move the database to internal storage or SD card';

  @override
  String get settings_storage_customFolder_deviceOnly_noCloudSync =>
      'App-managed cloud sync is disabled while the database sits on a device storage volume. No sync service can reach that folder on Android, so use Backup & Restore to keep copies elsewhere.';

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
  String get settings_storage_dangerZone => 'Danger Zone';

  @override
  String get settings_storage_resetDatabase => 'Reset Database';

  @override
  String get settings_storage_resetDatabase_subtitle =>
      'Delete all data on this device and start fresh';

  @override
  String get settings_storage_resetDialog_title => 'Reset Database?';

  @override
  String get settings_storage_resetDialog_body =>
      'This permanently deletes all data on THIS device, including dives, sites, gear, and settings. A backup is created automatically before resetting.\n\nYour cloud library is not deleted, and other devices keep their data. Cloud sync will be disconnected so the reset is not undone; you can reconnect it in Settings > Cloud Sync.';

  @override
  String get settings_storage_resetDialog_confirmWord => 'Delete';

  @override
  String get settings_storage_resetDialog_confirmHint =>
      'Type \"Delete\" to confirm';

  @override
  String get settings_storage_resetDialog_confirmButton => 'Reset';

  @override
  String get settings_storage_resetDialog_backupFailed =>
      'Backup failed. Reset aborted to protect your data.';

  @override
  String settings_storage_resetDialog_resetFailed(Object error) {
    return 'Reset failed: $error';
  }

  @override
  String get settings_storage_resetComplete_title => 'Database Reset';

  @override
  String get settings_storage_resetComplete_description =>
      'This device\'s data has been cleared and a backup was saved. Cloud sync is now disconnected so the reset is not undone; you can reconnect it in Settings > Cloud Sync. Tap continue to reload the app.';

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
  String get settings_units_gasModel => 'Gas calculations';

  @override
  String get settings_units_gasModel_real => 'Real gas';

  @override
  String get settings_units_gasModel_real_subtitle =>
      'Accounts for compressibility. A 12 L cylinder at 200 bar holds about 2317 L.';

  @override
  String get settings_units_gasModel_ideal => 'Ideal gas';

  @override
  String get settings_units_gasModel_ideal_subtitle =>
      'Matches hand calculation and dive tables. A 12 L cylinder at 200 bar holds 2400 L.';

  @override
  String get settings_units_gasModel_explanation =>
      'How cylinder pressure is converted to gas volume. This affects RMV, gas statistics, the planner, and the gas calculators. Ideal gas matches the arithmetic taught by training agencies; real gas is physically accurate and reads roughly 5% lower for RMV.';

  @override
  String get settings_units_dialog_gasModel => 'Gas calculations';

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
  String get settings_units_defaultCurrency => 'Default Currency';

  @override
  String get settings_units_dialog_defaultCurrency => 'Default Currency';

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
  String get settings_updates_automaticUpdates => 'Automatic updates';

  @override
  String get settings_updates_automaticUpdatesSubtitle =>
      'Check for updates periodically';

  @override
  String get settings_updates_betaDialogBody =>
      'Beta builds are published from every change and may upgrade your dive log\'s database before the stable release does. Switching back to stable later will not downgrade the app, and all devices that sync together should use the same channel. A backup is taken automatically before any database upgrade.';

  @override
  String get settings_updates_betaDialogConfirm => 'Switch to Beta';

  @override
  String get settings_updates_betaDialogTitle => 'Receive beta updates?';

  @override
  String get settings_updates_channel => 'Update channel';

  @override
  String settings_updates_channelBadgeBeta(String version) {
    return '$version (Beta)';
  }

  @override
  String get settings_updates_channelBeta => 'Beta';

  @override
  String get settings_updates_channelBetaSubtitle =>
      'New builds from every change, ahead of stable';

  @override
  String get settings_updates_channelStable => 'Stable';

  @override
  String get settings_updates_channelStableSubtitle => 'Tested releases only';

  @override
  String get settings_updates_checkForUpdates => 'Check for Updates';

  @override
  String get settings_updates_checking => 'Checking...';

  @override
  String settings_updates_downloading(String progress) {
    return 'Downloading... $progress%';
  }

  @override
  String settings_updates_error(String message) {
    return 'Error: $message';
  }

  @override
  String get settings_updates_header => 'Updates';

  @override
  String get settings_updates_joinBeta => 'Join the Beta';

  @override
  String get settings_updates_joinBetaSubtitle =>
      'Get new features early through the beta program';

  @override
  String get settings_updates_lastChecked => 'Last checked';

  @override
  String get settings_updates_never => 'Never';

  @override
  String settings_updates_readyToInstall(String version) {
    return 'Version $version ready to install';
  }

  @override
  String get settings_updates_stableSwitchNotice =>
      'You will stay on this beta until the next stable release is newer than it.';

  @override
  String get settings_updates_upToDate => 'Up to date';

  @override
  String settings_updates_versionAvailable(String version) {
    return 'Version $version available';
  }

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
  String get statistics_category_overview_title => 'Overview';

  @override
  String get statistics_category_overview_subtitle =>
      'Totals, records, and breakdowns at a glance';

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
  String get statistics_filterBar_clear => 'Clear filter';

  @override
  String statistics_filterBar_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives',
      one: '1 dive',
    );
    return '$_temp0';
  }

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
  String get statistics_profile_deco_notRecorded => 'Not Recorded';

  @override
  String statistics_profile_deco_notRecordedHint(int count) {
    return '$count dives have no recorded or computable deco data and are excluded from the rate';
  }

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
  String get statistics_tooltip_filter => 'Filter statistics';

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
  String surfaceInterval_gasWarning_modExceeded(
    Object ppO2,
    Object depth,
    Object limit,
    Object mod,
  ) {
    return 'ppO₂ $ppO2 at $depth exceeds $limit. MOD for this mix is $mod.';
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
  String surfaceInterval_result_beyondHorizon(Object hours) {
    return 'The wait runs past the $hours hours this planner searches. Off-gassing continues, so a longer surface interval will get there.';
  }

  @override
  String surfaceInterval_result_beyondHorizonShort(Object hours) {
    return 'More than $hours hours';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Current Interval';

  @override
  String get surfaceInterval_result_gasUnsafe => 'Gas unsafe at this depth';

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
  String surfaceInterval_result_noIntervalHelps(Object minutes) {
    return 'No surface interval is enough. The longest no-stop dive at this depth on this mix is $minutes min. Shorten the second dive or reduce its depth.';
  }

  @override
  String get surfaceInterval_result_notAchievable =>
      'Not achievable at any surface interval';

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
  String surfaceInterval_secondDive_heSemantics(Object percent) {
    return 'Second dive helium: $percent%';
  }

  @override
  String surfaceInterval_secondDive_o2Semantics(Object percent) {
    return 'Second dive O2: $percent%';
  }

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
  String get tags_action_browse => 'Browse';

  @override
  String get tags_picker_title => 'Pick Tags';

  @override
  String get tags_picker_empty =>
      'No tags yet. Type a tag name to create your first one.';

  @override
  String tags_picker_errorLoading(String error) {
    return 'Error loading tags: $error';
  }

  @override
  String get tags_picker_allAdded => 'All tags are already added.';

  @override
  String get tags_picker_noMatches => 'No tags match your search.';

  @override
  String tags_picker_addCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count tags',
      one: 'Add 1 tag',
      zero: 'Add tags',
    );
    return '$_temp0';
  }

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
  String get importWizard_tagsLabel => 'Tags';

  @override
  String get importWizard_photos_stepLabel => 'Photos';

  @override
  String importWizard_photos_foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos referenced in this logbook',
      one: '1 photo referenced in this logbook',
    );
    return '$_temp0';
  }

  @override
  String get importWizard_photos_chooseFolder => 'Choose photo folder...';

  @override
  String get importWizard_photos_scanning => 'Scanning folder...';

  @override
  String importWizard_photos_matchSummary(
    int matched,
    int byName,
    int missing,
  ) {
    return '$matched matched, $byName by filename only, $missing not found';
  }

  @override
  String get importWizard_photos_skip => 'Skip photos';

  @override
  String get importWizard_photos_mobileUnsupported =>
      'Importing photos needs a folder on this device\'s disk. Run this import on a computer to include them. Dives and sites import normally.';

  @override
  String importWizard_review_olderDivesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count older dives skipped — already in your log',
      one: '1 older dive skipped — already in your log',
    );
    return '$_temp0';
  }

  @override
  String get tags_hint_addTags => 'Add tags...';

  @override
  String get tags_manage_title => 'Tags';

  @override
  String get tags_manage_searchHint => 'Search tags...';

  @override
  String tags_manage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives',
      one: '1 dive',
      zero: '0 dives',
    );
    return '$_temp0';
  }

  @override
  String get tags_manage_emptyState =>
      'No tags yet. Create one to get started.';

  @override
  String tags_manage_selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get tags_manage_createTitle => 'Create Tag';

  @override
  String get tags_manage_editTitle => 'Edit Tag';

  @override
  String get tags_manage_nameLabel => 'Tag Name';

  @override
  String get tags_manage_colorLabel => 'Color';

  @override
  String get tags_manage_nameRequired => 'Tag name is required';

  @override
  String get tags_manage_deleteTitle => 'Delete Tag?';

  @override
  String tags_manage_deleteMessage(String tagName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives',
      one: '1 dive',
      zero: '0 dives',
    );
    return '\"$tagName\" will be removed from $_temp0. This cannot be undone.';
  }

  @override
  String tags_manage_bulkDeleteTitle(int count) {
    return 'Delete $count Tags?';
  }

  @override
  String tags_manage_bulkDeleteMessage(int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount dives',
      one: '1 dive',
      zero: '0 dives',
    );
    return 'These tags will be removed from $_temp0 total. This cannot be undone.';
  }

  @override
  String tags_manage_mergeTitle(int count) {
    return 'Merge $count Tags';
  }

  @override
  String get tags_manage_mergeResultName => 'Resulting tag name:';

  @override
  String get tags_manage_mergeKeepFrom => 'Or keep name from:';

  @override
  String tags_manage_mergeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives',
      one: '1 dive',
      zero: '0 dives',
    );
    return 'This will affect $_temp0 total.';
  }

  @override
  String get tags_manage_mergeAction => 'Merge';

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
  String tides_source_noaaStation(String name, String distance) {
    return 'NOAA station: $name ($distance)';
  }

  @override
  String get tides_source_modelEstimate => 'Ocean-model estimate';

  @override
  String get tides_source_modelCaveat =>
      'Modeled from satellite data. Times and heights may differ near complex coastlines.';

  @override
  String get tides_source_sheetTitle => 'Tide data source';

  @override
  String get tides_source_datumMllw =>
      'Heights relative to MLLW (station datum)';

  @override
  String get tides_source_datumMsl => 'Heights relative to mean sea level';

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
      'Import dives via Apple HealthKit';

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
  String transfer_computers_diveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives',
      one: '1 dive',
    );
    return '$_temp0';
  }

  @override
  String get transfer_computers_downloadTooltip => 'Download dives';

  @override
  String get transfer_computers_knownComputersHeader => 'Known Computers';

  @override
  String transfer_computers_lastDownloadDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String transfer_computers_lastDownloadHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String transfer_computers_lastDownloadMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String get transfer_computers_lastDownloadNever => 'Never';

  @override
  String get transfer_computers_lastDownloadYesterday => 'Yesterday';

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
      'Export your dive data in various formats. PDF creates a printable logbook. UDDF is a universal format compatible with most dive logging software. CSV and Excel files can be opened in spreadsheet applications. You can also back up your entire database from Settings > Backup & Restore.';

  @override
  String get transfer_export_backupLink => 'Go to Backup & Restore';

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
      'File Import auto-detects your file format and source app. Supported formats include CSV, UDDF, Subsurface XML, Garmin FIT, and Shearwater Cloud databases.';

  @override
  String get transfer_import_aboutTitle => 'About Import';

  @override
  String get transfer_import_fileImportSemanticLabel =>
      'Import dive data from file';

  @override
  String get transfer_import_fileImportSubtitle =>
      'CSV, UDDF, Subsurface XML, Garmin FIT, Shearwater Cloud';

  @override
  String get transfer_import_fileImportTitle => 'File Import';

  @override
  String get transfer_import_sectionHeader => 'Import Data';

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
  String get trips_detail_stat_totalRuntime => 'Total Runtime';

  @override
  String get trips_detail_stat_totalDives => 'Total Dives';

  @override
  String get trips_detail_tab_checklist => 'Checklist';

  @override
  String get trips_detail_tooltip_edit => 'Edit trip';

  @override
  String get trips_detail_tooltip_editShort => 'Edit';

  @override
  String get trips_detail_tooltip_moreOptions => 'More options';

  @override
  String get trips_detail_tooltip_viewOnMap => 'View on Map';

  @override
  String trips_diveScan_addButton(int count) {
    return 'Add $count Dives';
  }

  @override
  String trips_diveScan_added(int count) {
    return 'Added $count dives to trip';
  }

  @override
  String get trips_diveScan_cancel => 'Cancel';

  @override
  String trips_diveScan_currentTrip(String tripName) {
    return 'Currently on: $tripName';
  }

  @override
  String get trips_diveScan_deselectAll => 'Deselect all';

  @override
  String trips_diveScan_error(String error) {
    return 'Error scanning for dives: $error';
  }

  @override
  String get trips_diveScan_findButton => 'Find matching dives';

  @override
  String trips_diveScan_groupOtherTrips(int count) {
    return 'On other trips ($count)';
  }

  @override
  String trips_diveScan_groupUnassigned(int count) {
    return 'Unassigned ($count)';
  }

  @override
  String get trips_diveScan_noMatches => 'No matching dives found';

  @override
  String get trips_diveScan_noDiver =>
      'Select an active diver to scan for dives';

  @override
  String get trips_diveScan_selectAll => 'Select all';

  @override
  String trips_diveScan_subtitle(int count) {
    return '$count dives found in date range';
  }

  @override
  String get trips_diveScan_title => 'Add Dives to Trip';

  @override
  String get trips_diveScan_unknownSite => 'Unknown Site';

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
  String get trips_edit_label_returnFlight => 'Return Flight';

  @override
  String get trips_edit_returnFlightClear => 'Clear return flight';

  @override
  String get trips_edit_returnFlightNotSet => 'Not set';

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
  String trips_list_countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days days',
      one: 'In 1 day',
      zero: 'Starting today',
    );
    return '$_temp0';
  }

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
  String get trips_list_inProgress => 'In progress';

  @override
  String get trips_list_pastSection => 'Past Trips';

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
  String get trips_list_upcomingSection => 'Upcoming';

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
  String get trips_type_shore => 'Shore';

  @override
  String get trips_type_liveaboard => 'Liveaboard';

  @override
  String get trips_type_resort => 'Resort';

  @override
  String get trips_type_dayTrip => 'Day Trip';

  @override
  String get trips_edit_label_tripType => 'Trip Type';

  @override
  String get trips_edit_sectionTitle_vessel => 'Vessel Details';

  @override
  String get trips_edit_label_vesselName => 'Vessel Name *';

  @override
  String get trips_edit_hint_vesselName => 'e.g. Ocean Explorer';

  @override
  String get trips_edit_label_operatorName => 'Operator / Charter';

  @override
  String get trips_edit_hint_operatorName => 'e.g. Red Sea Divers';

  @override
  String get trips_edit_label_vesselType => 'Vessel Type';

  @override
  String get trips_edit_label_cabinType => 'Cabin Type';

  @override
  String get trips_edit_hint_cabinType => 'e.g. Deluxe Double';

  @override
  String get trips_edit_label_capacity => 'Passenger Capacity';

  @override
  String get trips_edit_sectionTitle_embarkDisembark => 'Embark / Disembark';

  @override
  String get trips_edit_label_embarkPort => 'Embark Port';

  @override
  String get trips_edit_hint_embarkPort => 'e.g. Hurghada Marina';

  @override
  String get trips_edit_label_disembarkPort => 'Disembark Port';

  @override
  String get trips_edit_hint_disembarkPort => 'e.g. Hurghada Marina';

  @override
  String get trips_edit_validation_vesselRequired =>
      'Vessel name is required for liveaboard trips';

  @override
  String get trips_detail_tab_overview => 'Overview';

  @override
  String get trips_detail_tab_itinerary => 'Itinerary';

  @override
  String get trips_detail_tab_photos => 'Photos';

  @override
  String get trips_detail_tab_dives => 'Dives';

  @override
  String get trips_detail_sectionTitle_vessel => 'Vessel';

  @override
  String get trips_detail_label_operator => 'Operator';

  @override
  String get trips_detail_label_vesselType => 'Type';

  @override
  String get trips_detail_label_cabin => 'Cabin';

  @override
  String get trips_detail_label_capacity => 'Capacity';

  @override
  String get trips_detail_label_embark => 'Embark';

  @override
  String get trips_detail_label_disembark => 'Disembark';

  @override
  String get trips_detail_stat_divesPerDay => 'Dives per day';

  @override
  String get trips_detail_stat_diveDays => 'Dive days';

  @override
  String get trips_detail_stat_seaDays => 'Sea days';

  @override
  String get trips_detail_stat_sitesVisited => 'Sites visited';

  @override
  String get trips_detail_stat_speciesSeen => 'Species seen';

  @override
  String get trips_detail_sectionTitle_dailyBreakdown => 'Daily Breakdown';

  @override
  String get trips_breakdown_column_day => 'Day';

  @override
  String get trips_breakdown_column_type => 'Type';

  @override
  String get trips_breakdown_column_dives => 'Dives';

  @override
  String get trips_breakdown_column_bottomTime => 'Bottom Time';

  @override
  String get trips_breakdown_column_sites => 'Sites';

  @override
  String get trips_detail_sectionTitle_voyageMap => 'Voyage Route';

  @override
  String trips_itinerary_dayLabel(int dayNumber) {
    return 'Day $dayNumber';
  }

  @override
  String trips_itinerary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives',
      one: '1 dive',
    );
    return '$_temp0';
  }

  @override
  String get trips_itinerary_editDay => 'Edit Day';

  @override
  String get trips_itinerary_dayType_label => 'Day Type';

  @override
  String get trips_itinerary_portName_label => 'Port / Anchorage';

  @override
  String get trips_itinerary_notes_label => 'Notes';

  @override
  String get trips_itinerary_noDives => 'No dives';

  @override
  String get trips_vesselType_catamaran => 'Catamaran';

  @override
  String get trips_vesselType_motorYacht => 'Motor Yacht';

  @override
  String get trips_vesselType_sailingYacht => 'Sailing Yacht';

  @override
  String get trips_vesselType_other => 'Other';

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
  String get units_profileMetric_millivolts => 'mV';

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
  String get universalImport_action_consolidate =>
      'Consolidate as additional computer';

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
  String get universalImport_action_changeFile => 'Change File';

  @override
  String get universalImport_action_selectFile => 'Select File';

  @override
  String get universalImport_action_selectFiles => 'Select Files';

  @override
  String get universalImport_action_chooseFolder => 'Choose Folder';

  @override
  String get universalImport_triage_title => 'Files to Import';

  @override
  String universalImport_triage_readyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files ready to import',
      one: '1 file ready to import',
    );
    return '$_temp0';
  }

  @override
  String universalImport_label_filesSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files selected',
      one: '1 file selected',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_triage_excludedCsv => 'Import individually (CSV)';

  @override
  String get universalImport_triage_unsupported => 'Unsupported format';

  @override
  String get universalImport_triage_parseFailed => 'Could not be read';

  @override
  String universalImport_triage_parsing(int current, int total) {
    return 'Parsing file $current of $total…';
  }

  @override
  String get universalImport_triage_cancelParsing => 'Cancel';

  @override
  String get universalImport_triage_allExcluded =>
      'None of the selected files can be imported together. CSV files must be imported one at a time.';

  @override
  String get universalImport_triage_noneImportable =>
      'None of the selected files can be imported.';

  @override
  String get universalImport_review_inBatchDuplicate =>
      'Duplicate of another dive in this import batch.';

  @override
  String get universalImport_summary_filesTitle => 'Files';

  @override
  String get universalImport_summary_noticesTitle => 'Not in the file';

  @override
  String get universalImport_summary_noticeNoTankPressureTitle =>
      'Tank pressure not recorded';

  @override
  String get universalImport_summary_noticeNoTankPressureBody =>
      'Air consumption and SAC cannot be calculated. You can add start and end pressure by editing the dive.';

  @override
  String universalImport_summary_noticeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Affects $count dives',
      one: 'Affects 1 dive',
    );
    return '$_temp0';
  }

  @override
  String universalImport_summary_fileImported(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives imported',
      one: '1 dive imported',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_summary_fileNeedsIndividualImport =>
      'Needs individual import';

  @override
  String get universalImport_summary_fileUnsupported => 'Unsupported format';

  @override
  String get universalImport_summary_fileParseFailed => 'Failed to read';

  @override
  String universalImport_bulk_consolidateMatched(int count) {
    return 'Consolidate matched ($count)';
  }

  @override
  String universalImport_bulk_importAll(int count) {
    return 'Import all ($count)';
  }

  @override
  String universalImport_bulk_importAllAsNew(int count) {
    return 'Import all as new ($count)';
  }

  @override
  String universalImport_bulk_skipAll(int count) {
    return 'Skip all ($count)';
  }

  @override
  String universalImport_bulk_replaceSourceAll(int count) {
    return 'Replace all ($count)';
  }

  @override
  String get universalImport_description_supportedFormats =>
      'Select a dive log file to import. Supported formats include CSV, UDDF, Subsurface XML, Garmin FIT, and Shearwater Cloud databases.';

  @override
  String get universalImport_dive_decideAction => 'Decide';

  @override
  String get universalImport_error_unsupportedFormat =>
      'This format is not yet supported. Please export as UDDF or CSV.';

  @override
  String get universalImport_label_columnMapping => 'Column Mapping';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped of $total columns mapped';
  }

  @override
  String get universalImport_label_consolidate => 'Consolidate';

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
  String get universalImport_label_importAsNew => 'Import as New';

  @override
  String get universalImport_label_importComplete => 'Import Complete';

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
  String get universalImport_entityAction_linkBadge => 'LINK';

  @override
  String get universalImport_entityAction_linkExisting => 'Link to existing';

  @override
  String get universalImport_entityAction_linkExistingSubtitle =>
      'Use the matched record';

  @override
  String get universalImport_entityAction_replaceBadge => 'REPLACE';

  @override
  String get universalImport_entityAction_replaceExisting => 'Replace existing';

  @override
  String get universalImport_entityAction_replaceExistingSubtitle =>
      'Overwrite with imported data';

  @override
  String get universalImport_entityAction_skip => 'Skip';

  @override
  String get universalImport_entityAction_skipSubtitle => 'Discard this import';

  @override
  String get universalImport_entityAction_importAsNew => 'Import as New';

  @override
  String get universalImport_entityAction_importAsNewSubtitle =>
      'Create separate entry';

  @override
  String get universalImport_pending_chooseAction => 'Choose an action';

  @override
  String universalImport_pending_gateHint(int count) {
    return '$count duplicate(s) need a decision';
  }

  @override
  String get universalImport_pending_needsDecision => 'Needs decision';

  @override
  String get universalImport_pending_reviewAction => 'Review';

  @override
  String get universalImport_rowHint_tapCompareToDecide =>
      'Tap Decide to choose';

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
  String get universalImport_semantics_needsDecision =>
      'Suspected duplicate, needs decision';

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
  String universalImport_snackbar_bulkMarkedAs(int count, String action) {
    return '$count marked as $action';
  }

  @override
  String universalImport_snackbar_markedAs(String action) {
    return 'Marked as $action';
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
  String get universalImport_summary_decidesRequired =>
      'Each needs a decision before importing.';

  @override
  String get universalImport_title => 'File Import';

  @override
  String get universalImport_tooltip_closeWizard => 'Close import wizard';

  @override
  String weather_windFromDirection(Object wind, Object direction) {
    return '$wind from $direction';
  }

  @override
  String get weather_wind_calm => 'calm';

  @override
  String get weather_wind_highWind => 'high wind';

  @override
  String get weather_wind_lightBreeze => 'light breeze';

  @override
  String get weather_wind_moderateBreeze => 'moderate breeze';

  @override
  String get weather_wind_strongBreeze => 'strong breeze';

  @override
  String get weather_wmo_clear => 'Clear sky';

  @override
  String get weather_wmo_drizzle => 'Drizzle';

  @override
  String get weather_wmo_fog => 'Fog';

  @override
  String get weather_wmo_freezingDrizzle => 'Freezing drizzle';

  @override
  String get weather_wmo_freezingRain => 'Freezing rain';

  @override
  String get weather_wmo_mainlyClear => 'Mainly clear';

  @override
  String get weather_wmo_overcast => 'Overcast';

  @override
  String get weather_wmo_partlyCloudy => 'Partly cloudy';

  @override
  String get weather_wmo_rain => 'Rain';

  @override
  String get weather_wmo_rainShowers => 'Rain showers';

  @override
  String get weather_wmo_snow => 'Snow';

  @override
  String get weather_wmo_snowGrains => 'Snow grains';

  @override
  String get weather_wmo_snowShowers => 'Snow showers';

  @override
  String get weather_wmo_thunderstorm => 'Thunderstorm';

  @override
  String get weather_wmo_thunderstormHail => 'Thunderstorm with hail';

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
  String get diveComputer_connectionType_ble => 'Bluetooth LE';

  @override
  String get diveComputer_connectionType_bluetooth => 'Bluetooth';

  @override
  String get diveComputer_connectionType_infrared => 'Infrared';

  @override
  String get diveComputer_connectionType_unknown => 'Unknown';

  @override
  String get diveComputer_connectionType_usb => 'USB';

  @override
  String get diveComputer_connectionType_wifi => 'Wi-Fi';

  @override
  String diveComputer_detail_deleteDialogContent(String name) {
    return 'Are you sure you want to remove \"$name\"? This will not delete any dives that were imported from this computer.';
  }

  @override
  String get diveComputer_detail_deleteDialogTitle => 'Delete Computer?';

  @override
  String get diveComputer_detail_divesImported => 'Dives Imported';

  @override
  String get diveComputer_detail_downloadDivesButton => 'Download Dives';

  @override
  String get diveComputer_detail_editDialogTitle => 'Edit Computer';

  @override
  String get diveComputer_detail_editNameHint => 'e.g., My Perdix';

  @override
  String get diveComputer_detail_editNotesHint => 'Optional notes';

  @override
  String get diveComputer_detail_labelConnection => 'Connection';

  @override
  String get diveComputer_detail_labelManufacturer => 'Manufacturer';

  @override
  String get diveComputer_detail_labelModel => 'Model';

  @override
  String get diveComputer_detail_labelName => 'Name';

  @override
  String get diveComputer_detail_lastDownload => 'Last Download';

  @override
  String get diveComputer_detail_notesTitle => 'Notes';

  @override
  String get diveComputer_detail_reimportAllButton => 'Re-import all dives';

  @override
  String diveComputer_detail_reimportDialogBody(String computerName) {
    return 'Download every dive from $computerName and review them against your log. This may take several minutes.';
  }

  @override
  String get diveComputer_detail_reimportDialogTitle => 'Re-import all dives?';

  @override
  String get diveComputer_detail_statisticsTitle => 'Statistics';

  @override
  String get diveComputer_detail_unknown => 'Unknown';

  @override
  String get diveComputer_detail_viewDivesButton =>
      'View Dives from This Computer';

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
  String get diveComputer_discovery_usbInstructions =>
      'Connect your dive computer via USB cable, then select it below.';

  @override
  String diveComputer_discovery_usbNoResults(String query) {
    return 'No devices matching \"$query\"';
  }

  @override
  String get diveComputer_discovery_usbSearchHint =>
      'Search by manufacturer or model...';

  @override
  String get diveComputer_downloadExit_content =>
      'Leaving will cancel the current download from your dive computer. Are you sure?';

  @override
  String get diveComputer_downloadExit_leave => 'Leave';

  @override
  String get diveComputer_downloadExit_stay => 'Stay';

  @override
  String get diveComputer_downloadExit_title => 'Download in Progress';

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
  String get diveComputer_downloadStep_downloadAll => 'Download all dives';

  @override
  String get diveComputer_downloadStep_downloadFailed => 'Download failed';

  @override
  String get diveComputer_downloadStep_downloadNew => 'Download new dives';

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
  String get diveComputer_downloadStep_firstSyncBody =>
      'Your logbook already has dives. You can skip downloading dives you already have.';

  @override
  String get diveComputer_downloadStep_firstSyncTitle =>
      'First download from this computer';

  @override
  String diveComputer_downloadStep_onlyAfterDate(String date) {
    return 'Only download dives after $date';
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
  String diveComputer_downloadStep_importPartialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count downloaded dives',
      one: 'Import 1 downloaded dive',
    );
    return '$_temp0';
  }

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
  String get diveComputer_download_noSerialPortsFound =>
      'No USB serial ports found. Is the dive computer connected and powered on?';

  @override
  String get diveComputer_download_stalePairing =>
      'This dive computer\'s Bluetooth pairing is out of date. Forget the dive computer in your device\'s Bluetooth settings, then pair it again from the dive computer\'s Bluetooth menu.';

  @override
  String get diveComputer_download_discoveryStalled =>
      'Connected to the dive computer, but it stopped responding before the download could start. This usually means the Bluetooth pairing is out of date: forget the dive computer in your device\'s Bluetooth settings, then try again.';

  @override
  String diveComputer_download_serialConnectFailedWithDetails(Object details) {
    return 'Could not connect to dive computer.\n\nDiagnostic details (share with developers):\n$details';
  }

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
  String diveComputer_download_importingCountDives(int count) {
    return 'Importing $count dives...';
  }

  @override
  String diveComputer_download_importingCountNewDives(int count) {
    return 'Importing $count new dives...';
  }

  @override
  String get diveComputer_download_newDivesImported => 'New dives imported';

  @override
  String get diveComputer_download_newDivesOnlySubtitle =>
      'Only downloads dives added since your last sync';

  @override
  String get diveComputer_download_newDivesOnlyTitle =>
      'Download new dives only';

  @override
  String get diveComputer_download_preparing => 'Preparing...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_reimportHint =>
      'Looking for older or deleted dives? Re-import all';

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
  String get diveComputer_download_upToDate =>
      'No new dives found -- your log is up to date';

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
  String get diveComputer_pinCode_instructions =>
      'Enter the code displayed on your dive computer.';

  @override
  String get diveComputer_pinCode_label => 'PIN Code';

  @override
  String get diveComputer_pinCode_submit => 'Submit';

  @override
  String get diveComputer_pinCode_title => 'PIN Code Required';

  @override
  String get diveComputer_pinEntry_connectButton => 'Connect';

  @override
  String get diveComputer_pinEntry_helperText =>
      'Enter the 4-6 digit PIN shown on your device';

  @override
  String get diveComputer_pinEntry_instructionsGeneric =>
      'Check your dive computer display for the PIN code.';

  @override
  String diveComputer_pinEntry_instructionsWithDevice(String deviceName) {
    return 'Check your $deviceName display for the PIN code.';
  }

  @override
  String get diveComputer_pinEntry_semanticLabel =>
      'PIN code entry, 4 to 6 digits';

  @override
  String get diveComputer_pinEntry_title => 'Enter PIN Code';

  @override
  String diveComputer_scan_bluetoothSemanticLabel(String name) {
    return 'Bluetooth device: $name';
  }

  @override
  String get diveComputer_scan_emptyStateInstructions =>
      'Make sure your dive computer is:\n• Turned on\n• In Bluetooth pairing mode\n• Close to your device';

  @override
  String get diveComputer_scan_knownBadge => 'Known';

  @override
  String get diveComputer_scan_lookingForDevicesTitle => 'Looking for Devices';

  @override
  String get diveComputer_scan_noUsbDevicesAvailable =>
      'No USB devices available';

  @override
  String get diveComputer_scan_retry => 'Retry';

  @override
  String get diveComputer_scan_scanAgain => 'Scan Again';

  @override
  String get diveComputer_scan_scanningStatus =>
      'Scanning for dive computers...';

  @override
  String get diveComputer_scan_stopScanning => 'Stop Scanning';

  @override
  String get diveComputer_scan_supportedBadge => 'Supported';

  @override
  String get diveComputer_scan_tabBluetooth => 'Bluetooth';

  @override
  String get diveComputer_scan_tabUsb => 'USB Cable';

  @override
  String get diveComputer_scan_usbCableLabel => 'USB Cable';

  @override
  String diveComputer_scan_usbSemanticLabel(String model) {
    return 'USB device: $model';
  }

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
      'Submersion uses Apple HealthKit to read underwater diving workout data, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get diveImport_healthkit_accessRequired => 'Apple HealthKit';

  @override
  String get diveImport_healthkit_attribution => 'Powered by Apple HealthKit';

  @override
  String get diveImport_healthkit_closeTooltip => 'Close Apple Watch import';

  @override
  String get diveImport_healthkit_dataUsage =>
      'Reads underwater diving activities from Apple Health, including depth, duration, water temperature, and heart rate. This data is stored locally in your dive log and is never shared with third parties.';

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
  String get diveImport_healthkit_grantAccess => 'Continue';

  @override
  String get diveImport_healthkit_noDivesFound => 'No Dives Found';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'No underwater diving activities found in the selected date range.';

  @override
  String get diveImport_healthkit_notAvailable => 'Not Available';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'Apple Watch import needs an iPhone with the Health app.';

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
  String get diveImport_uddf_media => 'Photos';

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
  String get divePlanner_undo => 'Undo';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'Rock bottom is the minimum gas reserve for an emergency ascent while sharing air with your buddy.\n\n• Uses a stressed RMV (2-3x normal)\n• Assumes both divers on one tank\n• Includes safety stop when enabled\n\nAlways turn the dive BEFORE reaching rock bottom!';

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
  String get gasCalculators_rockBottom_buddySac => 'Buddy RMV';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'Combined stressed RMV';

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
      'Use a higher RMV to account for stress during an emergency';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'Stressed RMV';

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
  String get gasCalculators_rockBottom_yourSac => 'Your RMV';

  @override
  String get gpsLogger_androidNotificationText =>
      'Recording your surface track';

  @override
  String get gpsLogger_androidNotificationTitle => 'Submersion GPS Logger';

  @override
  String get gpsLogger_deleteTrackMessage =>
      'This removes the recorded GPS track. Positions already stamped on dives are kept.';

  @override
  String get gpsLogger_deleteTrackTitle => 'Delete track?';

  @override
  String get gpsLogger_interruptedNotice =>
      'A previous recording was interrupted. The track was saved.';

  @override
  String gpsLogger_lastFix(String age, String accuracy) {
    return 'Last fix $age ago ($accuracy)';
  }

  @override
  String get gpsLogger_locationOff => 'Location services are turned off.';

  @override
  String get gpsLogger_matchButton => 'Match dives to GPS logs';

  @override
  String gpsLogger_matchResult(int count) {
    return '$count dives positioned';
  }

  @override
  String get gpsLogger_matchResultNone => 'No dives matched a recorded track';

  @override
  String get gpsLogger_noFixYet => 'Waiting for GPS fix';

  @override
  String get gpsLogger_noTracks => 'No GPS tracks recorded yet';

  @override
  String get gpsLogger_permissionDenied =>
      'Location permission is required to record a GPS track. Enable it in system settings.';

  @override
  String gpsLogger_recordingStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '$count point',
    );
    return 'Recording - $_temp0';
  }

  @override
  String get gpsLogger_reviewSites => 'Review site matches';

  @override
  String get gpsLogger_startButton => 'Start logging';

  @override
  String get gpsLogger_stopButton => 'Stop logging';

  @override
  String gpsLogger_stripStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '$count point',
    );
    return 'Recording GPS track · $_temp0';
  }

  @override
  String get gpsLogger_summary_tracks => 'Tracks';

  @override
  String get gpsLogger_summary_recordedTime => 'Recorded time';

  @override
  String get gpsLogger_summary_divesCovered => 'Dives covered';

  @override
  String gpsLogger_trackSubtitle(num count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '$count point',
    );
    return '$_temp0, $duration';
  }

  @override
  String gpsLogger_trackSubtitleTrimmed(String duration) {
    return 'Trimmed, $duration';
  }

  @override
  String get gpsLogger_tracksHeader => 'Recorded tracks';

  @override
  String get gpsTrack_action_trim => 'Trim...';

  @override
  String get gpsTrack_action_split => 'Split...';

  @override
  String get gpsTrack_action_resetTrim => 'Reset trim';

  @override
  String get gpsTrack_edit_applyTrim => 'Apply trim';

  @override
  String get gpsTrack_edit_confirmSplit => 'Split here';

  @override
  String get gpsTrack_edit_splitWarning =>
      'Splitting creates two tracks and removes the original. This cannot be undone.';

  @override
  String get gpsTrack_edit_cancel => 'Cancel';

  @override
  String get gpsTrack_import_action => 'Import track...';

  @override
  String get gpsTrack_import_reviewTitle => 'Review Import';

  @override
  String get gpsTrack_import_timezone => 'Recorded in';

  @override
  String get gpsTrack_import_timezoneHint =>
      'Times in the file are UTC. Set the zone the track was recorded in so it lines up with your dives.';

  @override
  String get gpsTrack_import_duplicate =>
      'This looks like a duplicate of an existing track.';

  @override
  String get gpsTrack_import_confirm => 'Import';

  @override
  String get gpsTrack_import_csvMapping => 'Match the columns';

  @override
  String get gpsTrack_import_firstFix => 'First fix';

  @override
  String gpsTrack_import_fixCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fixes',
      one: '1 fix',
    );
    return '$_temp0';
  }

  @override
  String gpsTrack_import_failed(String reason) {
    return 'Could not read that file: $reason';
  }

  @override
  String get gpsTrack_importError_unsupportedFormat =>
      'That file type is not supported. Import a GPX, KML, CSV, or FIT file.';

  @override
  String get gpsTrack_importError_unreadable =>
      'That file could not be read. It may be damaged or incomplete.';

  @override
  String get gpsTrack_importError_noPositions =>
      'That file has no timestamped GPS positions.';

  @override
  String get gpsTrack_importError_badData =>
      'That file has a position or timestamp this app cannot read.';

  @override
  String get gpsTrack_export_saved => 'Track saved';

  @override
  String get gpsTrack_action_export => 'Export';

  @override
  String get gpsTrack_action_shareGpx => 'Share as GPX';

  @override
  String get gpsTrack_action_saveGpx => 'Save as GPX...';

  @override
  String get gpsTrack_action_shareKml => 'Share as KML';

  @override
  String get gpsTrack_action_saveKml => 'Save as KML...';

  @override
  String get gpsTrack_export_failed => 'Export failed.';

  @override
  String get gpsTrack_map_title => 'Track Map';

  @override
  String gpsTrack_map_truncated(int count) {
    return 'Showing the $count most recent tracks. Narrow the date filter to see others.';
  }

  @override
  String get gpsTrack_map_noTracks => 'No recorded tracks to show.';

  @override
  String get gpsTrack_map_showMap => 'Show map';

  @override
  String get gpsTrack_filter_all => 'All dates';

  @override
  String get gpsTrack_filter_clear => 'Clear date filter';

  @override
  String get gpsTrack_inspect_speed => 'Speed';

  @override
  String get gpsTrack_inspect_accuracy => 'Accuracy';

  @override
  String get gpsTrack_stats_distance => 'Distance';

  @override
  String get gpsTrack_stats_duration => 'Duration';

  @override
  String get gpsTrack_stats_avgSpeed => 'Avg speed';

  @override
  String get gpsTrack_stats_maxSpeed => 'Max speed';

  @override
  String get gpsTrack_stats_fixes => 'Fixes';

  @override
  String get gpsTrack_stats_dives => 'Dives';

  @override
  String get gpsTrack_colorMode_uniform => 'Plain';

  @override
  String get gpsTrack_colorMode_speed => 'Speed';

  @override
  String get gpsTrack_colorMode_elapsed => 'Time';

  @override
  String get gpsTrack_legend_slower => 'Slower';

  @override
  String get gpsTrack_legend_faster => 'Faster';

  @override
  String get gpsTrack_legend_start => 'Start';

  @override
  String get gpsTrack_legend_end => 'End';

  @override
  String get gpsTrack_detail_title => 'GPS Track';

  @override
  String get gpsTrack_detail_notFound => 'This track is no longer available.';

  @override
  String get gpsTrack_detail_unreadable => 'Track data could not be read.';

  @override
  String get gpsTrack_detail_noPoints =>
      'This track has no recorded positions.';

  @override
  String get maps_compass_resetLabel => 'Reset map orientation to north';

  @override
  String get maps_compass_resetTooltip => 'North up';

  @override
  String get maps_heatMap_hide => 'Hide Heat Map';

  @override
  String get maps_heatMap_overlayOff => 'Heat map overlay is off';

  @override
  String get maps_depthOverlay_show => 'Show depth overlay';

  @override
  String get maps_depthOverlay_hide => 'Hide depth overlay';

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
  String get maps_offline_downloadNewRegion => 'Download new region';

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
  String get tankPresets_currentDefault => 'Current default';

  @override
  String get tankPresets_customPresets => 'Custom Presets';

  @override
  String get tankPresets_defaultSettings => 'Default Tank';

  @override
  String get tankPresets_defaultSettings_description =>
      'The starred preset is used as the default tank when logging new dives.';

  @override
  String tankPresets_deleteDefaultMessage(String name) {
    return 'Are you sure you want to delete \"$name\"? This is your current default tank preset and will be reset to AL80.';
  }

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
  String get tankPresets_applyToImports => 'Also apply to imported dives';

  @override
  String get tankPresets_applyToImports_subtitle =>
      'Fill in missing tank data on imported dives using the default preset';

  @override
  String get tankPresets_new_title => 'New Tank Preset';

  @override
  String get tankPresets_noPresets => 'No tank presets available';

  @override
  String get tankPresets_setAsDefault => 'Set as default';

  @override
  String get tankPresets_title => 'Tank Presets';

  @override
  String get tools_gpsLogger_description =>
      'Record your position during a dive day and match imported dives to GPS locations automatically.';

  @override
  String get tools_gpsLogger_subtitle => 'Record a surface track';

  @override
  String get tools_gpsLogger_title => 'GPS Logger';

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

  @override
  String get settings_section_dataSources_title => 'Apple HealthKit';

  @override
  String get settings_section_dataSources_subtitle => 'Health data integration';

  @override
  String get settings_siteMatch_title => 'Auto site matching';

  @override
  String get settings_siteMatch_subtitle =>
      'How aggressively downloaded dives are matched to sites';

  @override
  String get settings_siteMatch_strict => 'Strict';

  @override
  String get settings_siteMatch_balanced => 'Balanced';

  @override
  String get settings_siteMatch_relaxed => 'Relaxed';

  @override
  String get settings_dataSources_header => 'Apple HealthKit Integration';

  @override
  String get settings_dataSources_appleHealth_title => 'Apple HealthKit';

  @override
  String get settings_dataSources_appleHealth_subtitle =>
      'Underwater Diving Data';

  @override
  String get settings_dataSources_appleHealth_description =>
      'Submersion uses Apple HealthKit to read underwater diving workout data from Apple Health. This data is used to create detailed dive logs from your Apple Watch dives.';

  @override
  String get settings_dataSources_appleHealth_dataTypesHeader =>
      'Data Read from HealthKit';

  @override
  String get settings_dataSources_appleHealth_dataTypeWorkouts =>
      'Underwater Diving Workouts - dive start time, duration, and activity data';

  @override
  String get settings_dataSources_appleHealth_dataTypeHeartRate =>
      'Heart Rate - heart rate samples recorded during dives';

  @override
  String get settings_dataSources_appleHealth_permissionGranted =>
      'HealthKit access granted';

  @override
  String get settings_dataSources_appleHealth_permissionNotGranted =>
      'HealthKit access not granted';

  @override
  String get settings_dataSources_appleHealth_permissionChecking =>
      'Checking HealthKit access...';

  @override
  String get settings_dataSources_appleHealth_importAction =>
      'Import Dives from Apple Watch via HealthKit';

  @override
  String get settings_dataSources_appleHealth_privacy =>
      'Your health data is stored locally on this device and is never shared with third parties. Submersion only reads data from Apple HealthKit and does not write any data back to HealthKit.';

  @override
  String get settings_dataSources_appleHealth_poweredBy =>
      'Powered by Apple HealthKit';

  @override
  String get settings_dataSources_noSources =>
      'No data source integrations are available on this platform.';

  @override
  String get diveLog_edit_section_environment => 'Environment';

  @override
  String get diveLog_edit_subsection_autofill => 'Auto-fill';

  @override
  String get diveLog_edit_subsection_weather => 'Weather';

  @override
  String get diveLog_edit_subsection_diveConditions => 'Dive Conditions';

  @override
  String get diveLog_edit_label_windSpeed => 'Wind Speed';

  @override
  String get diveLog_edit_label_windDirection => 'Wind Direction';

  @override
  String get diveLog_edit_label_cloudCover => 'Cloud Cover';

  @override
  String get diveLog_edit_label_precipitation => 'Precipitation';

  @override
  String get diveLog_edit_label_humidity => 'Humidity';

  @override
  String get diveLog_edit_label_weatherDescription => 'Weather Description';

  @override
  String get diveLog_edit_button_fetchWeather => 'Fetch Weather';

  @override
  String get diveLog_edit_fetchingWeather => 'Fetching weather...';

  @override
  String get diveLog_edit_weatherFetched => 'Weather data loaded';

  @override
  String get diveLog_edit_fetchWeatherNoConnection => 'No internet connection';

  @override
  String get diveLog_edit_fetchWeatherUnavailable =>
      'Weather data unavailable for this date';

  @override
  String get diveLog_edit_fetchWeatherNotYetAvailable =>
      'Weather data not yet available for this date';

  @override
  String get diveLog_edit_fetchWeatherHint => 'Add a date and dive site first';

  @override
  String get diveLog_edit_fetchWeatherConfirm =>
      'Replace existing weather data with fetched data?';

  @override
  String get diveLog_detail_section_environment => 'Environment';

  @override
  String get diveLog_detail_subsection_weather => 'Weather';

  @override
  String get diveLog_detail_subsection_diveConditions => 'Dive Conditions';

  @override
  String get diveLog_detail_label_windSpeed => 'Wind Speed';

  @override
  String get diveLog_detail_label_windDirection => 'Wind Direction';

  @override
  String get diveLog_detail_label_cloudCover => 'Cloud Cover';

  @override
  String get diveLog_detail_label_precipitation => 'Precipitation';

  @override
  String get diveLog_detail_label_humidity => 'Humidity';

  @override
  String get diveLog_detail_label_weatherDescription => 'Description';

  @override
  String get diveLog_detail_weatherSourceOpenMeteo => 'via Open-Meteo';

  @override
  String get dropTarget_title => 'Drop to Import';

  @override
  String get dropTarget_subtitle => 'Release to open import wizard';

  @override
  String get dropTarget_error_unsupportedFile => 'Unsupported file type';

  @override
  String get dropTarget_error_wizardActive => 'Finish current import first';

  @override
  String get dropTarget_error_readFailed => 'Could not read file';

  @override
  String get enum_cloudCover_clear => 'Clear';

  @override
  String get enum_cloudCover_partlyCloudy => 'Partly Cloudy';

  @override
  String get enum_cloudCover_mostlyCloudy => 'Mostly Cloudy';

  @override
  String get enum_cloudCover_overcast => 'Overcast';

  @override
  String get enum_precipitation_none => 'None';

  @override
  String get enum_precipitation_drizzle => 'Drizzle';

  @override
  String get enum_precipitation_lightRain => 'Light Rain';

  @override
  String get enum_precipitation_rain => 'Rain';

  @override
  String get enum_precipitation_heavyRain => 'Heavy Rain';

  @override
  String get enum_precipitation_snow => 'Snow';

  @override
  String get enum_precipitation_sleet => 'Sleet';

  @override
  String get enum_precipitation_hail => 'Hail';

  @override
  String get columnConfig_title => 'Dive Details List Fields';

  @override
  String get columnConfig_viewMode => 'View Mode';

  @override
  String get columnConfig_visibleColumns => 'Visible Columns';

  @override
  String get columnConfig_availableFields => 'Available Fields';

  @override
  String get columnConfig_extraFields => 'Extra Fields';

  @override
  String get columnConfig_extraFields_description =>
      'Shown below main card content';

  @override
  String get columnConfig_slotAssignments => 'Slot Assignments';

  @override
  String get columnConfig_resetToDefault => 'Reset to Default';

  @override
  String get columnConfig_preset => 'Preset';

  @override
  String get columnConfig_presetSaveAs => 'Save As';

  @override
  String get columnConfig_presetName => 'Preset Name';

  @override
  String get columnConfig_presetNameHint => 'e.g., Tech Diving';

  @override
  String get columnConfig_presetSave => 'Save';

  @override
  String get columnConfig_presetCancel => 'Cancel';

  @override
  String get columnConfig_columns => 'Columns';

  @override
  String get columnConfig_done => 'Done';

  @override
  String get settings_appearance_columnConfig => 'Dive Details List Fields';

  @override
  String get settings_appearance_columnConfig_subtitle =>
      'Customize fields shown in dive list views';

  @override
  String get diveField_category_core => 'Core';

  @override
  String get diveField_category_environment => 'Environment';

  @override
  String get diveField_category_gas => 'Gas';

  @override
  String get diveField_category_tank => 'Tank';

  @override
  String get diveField_category_weight => 'Weight';

  @override
  String get diveField_category_equipment => 'Equipment';

  @override
  String get diveField_category_deco => 'Decompression';

  @override
  String get diveField_category_physiology => 'Physiology';

  @override
  String get diveField_category_rebreather => 'Rebreather';

  @override
  String get diveField_category_people => 'People';

  @override
  String get diveField_category_location => 'Location';

  @override
  String get diveField_category_trip => 'Trip';

  @override
  String get diveField_category_rating => 'Rating';

  @override
  String get diveField_category_metadata => 'Metadata';

  @override
  String get listViewMode_table => 'Table';

  @override
  String get settings_appearance_general => 'General';

  @override
  String get settings_appearance_sections => 'Sections';

  @override
  String get settings_appearance_colorAccents => 'Color accents';

  @override
  String get settings_appearance_accentNavIcons => 'Colored navigation icons';

  @override
  String get settings_appearance_accentNavIcons_subtitle =>
      'Tint main menu icons with each feature\'s color';

  @override
  String get settings_appearance_accentSectionHeaders =>
      'Colored section headers';

  @override
  String get settings_appearance_accentSectionHeaders_subtitle =>
      'Show a colored feature icon next to page titles';

  @override
  String get settings_appearance_accentListIcons => 'Colored list icons';

  @override
  String get settings_appearance_accentListIcons_subtitle =>
      'Tint icons in lists and settings pages';

  @override
  String get settings_appearance_showDetailsPane => 'Show Details Pane';

  @override
  String get settings_appearance_showDetailsPane_subtitle =>
      'Display details pane alongside table';

  @override
  String get settings_appearance_showProfilePanel =>
      'Show Profile Panel in Table View';

  @override
  String get settings_appearance_showProfilePanel_subtitle =>
      'Display dive profile chart above the table by default';

  @override
  String get settings_appearance_mapStyle => 'Map Style';

  @override
  String get settings_appearance_mapStyle_openStreetMap => 'Street Map';

  @override
  String get settings_appearance_mapStyle_openTopoMap => 'Topographic';

  @override
  String get settings_appearance_mapStyle_esriSatellite => 'Satellite';

  @override
  String get common_action_reparse => 'Re-parse';

  @override
  String get diveComputer_detail_reparseAllButton => 'Re-parse all dives';

  @override
  String get diveComputer_detail_reparseAllTitle => 'Re-parse all dives';

  @override
  String diveComputer_detail_reparseAllMessage(int count) {
    return 'Re-run the dive parser on $count dives that have stored raw data. This updates profile and sensor data but preserves your notes, sites, buddies, and other edits.';
  }

  @override
  String diveComputer_detail_reparseAllProgress(int count) {
    return 'Re-parsing $count dives...';
  }

  @override
  String diveComputer_detail_reparseAllSuccess(int count) {
    return 'Re-parsed $count dives successfully';
  }

  @override
  String diveComputer_detail_reparseAllPartial(
    int succeeded,
    int total,
    int failed,
  ) {
    return 'Re-parsed $succeeded of $total dives. $failed failed.';
  }

  @override
  String diveComputer_detail_reparseRawDataCount(int count) {
    return '$count dives with raw data';
  }

  @override
  String diveComputer_detail_reparseRawDataCountWithout(
    int count,
    int without,
  ) {
    return '$count dives with raw data ($without without)';
  }

  @override
  String get diveLog_detail_menu_reparseRawData => 'Re-parse raw data';

  @override
  String get diveLog_detail_reparseSuccess => 'Dive re-parsed successfully';

  @override
  String get diveLog_detail_reparseProfilePreserved =>
      'Source details refreshed. This dive was combined from other dives, so its profile was left unchanged.';

  @override
  String diveLog_detail_reparseFailed(String error) {
    return 'Re-parse failed: $error';
  }

  @override
  String get universalImport_label_replaceSource => 'Replace Source';

  @override
  String get universalImport_label_replaceSourceSubtitle =>
      'Update from same computer';

  @override
  String get universalImport_title_importOptions => 'Import Options';

  @override
  String get universalImport_label_options => 'Options';

  @override
  String get universalImport_label_retainDiveNumbers =>
      'Retain source dive numbers';

  @override
  String get universalImport_label_retainDiveNumbersSubtitle =>
      'Use dive numbers from the imported file instead of auto-assigning';

  @override
  String get universalImport_title_successImported => 'Successfully Imported';

  @override
  String get universalImport_title_successUpdated => 'Successfully Updated';

  @override
  String get universalImport_title_successConsolidated =>
      'Successfully Consolidated';

  @override
  String get universalImport_title_noDivesImported => 'No Dives Imported';

  @override
  String get universalImport_label_allDivesSkipped => 'All dives were skipped.';

  @override
  String get universalImport_label_replacedSourceData => 'Replaced source data';

  @override
  String get universalImport_label_consolidated => 'Consolidated';

  @override
  String get universalImport_label_photosAttached => 'Photos attached';

  @override
  String get universalImport_label_photosUnmatched =>
      'Photos not matched to a dive';

  @override
  String get common_label_shareWithAllProfiles =>
      'Share with all dive profiles';

  @override
  String get settings_shareByDefault_title =>
      'Share new sites and trips by default';

  @override
  String get settings_shareAllSites_title => 'Share all my sites';

  @override
  String get settings_shareAllTrips_title => 'Share all my trips';

  @override
  String settings_shareAllSites_confirm(int count) {
    return 'Make all $count of your sites visible to every dive profile in this app? You can unshare individual sites later.';
  }

  @override
  String settings_shareAllTrips_confirm(int count) {
    return 'Make all $count of your trips visible to every dive profile in this app? You can unshare individual trips later.';
  }

  @override
  String settings_shareAllSites_snackbar(int count) {
    return 'Shared $count sites with all dive profiles.';
  }

  @override
  String settings_shareAllTrips_snackbar(int count) {
    return 'Shared $count trips with all dive profiles.';
  }

  @override
  String get settings_shareAll_noneToShare => 'Nothing to share.';

  @override
  String get settings_sharedData_sectionTitle => 'Shared data';

  @override
  String get settings_sharedData_sectionSubtitle =>
      'Share sites and trips across profiles';

  @override
  String get common_action_unshare => 'Unshare';

  @override
  String get trips_unshareConfirm_title => 'Unshare this trip?';

  @override
  String trips_unshareConfirm_body(String name) {
    return 'This will remove \'$name\' from other dive profiles\' views. You can re-share it later.';
  }

  @override
  String get sites_unshareConfirm_title => 'Unshare this site?';

  @override
  String sites_unshareConfirm_body(String name) {
    return 'This will remove \'$name\' from other dive profiles\' views. You can re-share it later.';
  }

  @override
  String get trips_deleteShared_title => 'Delete shared trip?';

  @override
  String trips_deleteShared_body(String name) {
    return '\'$name\' is shared with other dive profiles. Deleting it here removes it for everyone.';
  }

  @override
  String get sites_deleteShared_title => 'Delete shared site?';

  @override
  String sites_deleteShared_body(String name) {
    return '\'$name\' is shared with other dive profiles. Deleting it here removes it for everyone.';
  }

  @override
  String divers_delete_reassigned_snackbar(int trips, int sites, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      trips,
      locale: localeName,
      other: 'trips',
      one: 'trip',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sites,
      locale: localeName,
      other: 'sites',
      one: 'site',
    );
    return 'Diver deleted. $trips shared $_temp0 and $sites shared $_temp1 reassigned to $name.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_title =>
      'Duplicate diver profiles';

  @override
  String get settings_cloudSync_duplicateDivers_description =>
      'Sync found more than one profile with the same name. This usually happens when each device created its own profile before syncing. Merging moves all dives and data onto one profile.';

  @override
  String settings_cloudSync_duplicateDivers_groupLabel(String name, int count) {
    return '$name ($count profiles)';
  }

  @override
  String get settings_cloudSync_duplicateDivers_mergeButton => 'Merge';

  @override
  String get settings_cloudSync_duplicateDivers_confirmTitle =>
      'Merge diver profiles?';

  @override
  String settings_cloudSync_duplicateDivers_confirmBody(
    int count,
    String name,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'profiles',
      one: 'profile',
    );
    return 'All dives, certifications, gear, and other data from $count duplicate $_temp0 will be moved onto \"$name\". This cannot be undone automatically.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_confirmCancel => 'Cancel';

  @override
  String get settings_cloudSync_duplicateDivers_confirmAction => 'Merge';

  @override
  String settings_cloudSync_duplicateDivers_successSnack(String name) {
    return 'Merged into $name';
  }

  @override
  String settings_cloudSync_duplicateDivers_failureSnack(String error) {
    return 'Merge failed: $error';
  }

  @override
  String get settings_cloudSync_duplicateDivers_undo => 'Undo';

  @override
  String get divers_edit_priorExperienceSection => 'Prior Experience';

  @override
  String get divers_edit_priorExperienceHelp =>
      'Dives and time from before you started logging in Submersion.';

  @override
  String get divers_edit_priorDivesLabel => 'Prior dives';

  @override
  String get divers_edit_priorHoursLabel => 'Prior hours';

  @override
  String get divers_edit_priorMinutesLabel => 'Minutes';

  @override
  String get divers_edit_divingSinceLabel => 'Diving since';

  @override
  String get divers_edit_divingSinceNotSet => 'Not set';

  @override
  String get divers_edit_clearDivingSinceTooltip => 'Clear diving since';

  @override
  String get divers_edit_priorInvalidNumber => 'Enter a valid number';

  @override
  String statistics_priorBreakdown(String logged, String prior) {
    return '$logged logged + $prior prior';
  }

  @override
  String statistics_divingSince(int year) {
    return 'Diving since $year';
  }

  @override
  String get db_location_choose_volume => 'Choose storage location';

  @override
  String get db_location_internal => 'Internal storage';

  @override
  String get db_location_sd_card => 'SD card';

  @override
  String get db_location_external_note =>
      'Files here are removed if you uninstall the app.';

  @override
  String get db_location_backup_note =>
      'Android cannot run the database from a cloud-synced folder. To keep a copy in Dropbox, Nextcloud, or Google Drive, set a Backup Location under Backup & Restore.';

  @override
  String diveLog_bulkEdit_membership_onAll(int count) {
    return 'on all $count';
  }

  @override
  String diveLog_bulkEdit_membership_onSome(int count, int total) {
    return 'on $count of $total';
  }

  @override
  String diveLog_bulkEdit_membership_adding(int total) {
    return 'adding to all $total';
  }

  @override
  String get diveLog_bulkEdit_membership_removing => 'removing from all';

  @override
  String get diveLog_bulkEdit_membership_empty =>
      'No items on the selected dives yet';

  @override
  String get settings_mediaStorage_entry_title => 'Media Storage';

  @override
  String get settings_mediaStorage_entry_subtitle =>
      'Store photo and video originals in your own cloud storage';

  @override
  String get settings_mediaStorage_status_notConfigured =>
      'No media store connected on this device';

  @override
  String settings_mediaStorage_status_connected(String hint) {
    return 'Connected to $hint';
  }

  @override
  String get settings_mediaStorage_test_success => 'Connection successful';

  @override
  String get settings_mediaStorage_saved => 'Media store connected';

  @override
  String get settings_mediaStorage_action_disconnect => 'Disconnect';

  @override
  String get settings_mediaStorage_disconnect_confirm_title =>
      'Disconnect media store?';

  @override
  String get settings_mediaStorage_disconnect_confirm_body =>
      'This device stops uploading and fetching media. Nothing in your bucket is deleted.';

  @override
  String get settings_mediaStorage_action_copyFromSync =>
      'Copy settings from Sync';

  @override
  String get settings_mediaStorage_transfers_title => 'Transfers';

  @override
  String get settings_mediaStorage_transfers_entry => 'View transfers';

  @override
  String get settings_mediaStorage_transfers_empty => 'No transfers';

  @override
  String get settings_mediaStorage_transfers_retry => 'Retry';

  @override
  String get settings_mediaStorage_transfers_clearCompleted =>
      'Clear completed';

  @override
  String get settings_mediaStorage_transfers_state_pending => 'Waiting';

  @override
  String get settings_mediaStorage_transfers_state_transferring => 'Uploading';

  @override
  String get settings_mediaStorage_transfers_state_deleting =>
      'Removing from cloud';

  @override
  String get settings_mediaStorage_transfers_state_done => 'Done';

  @override
  String get settings_mediaStorage_transfers_state_failed => 'Failed';

  @override
  String settings_mediaStorage_transfers_queued(int count) {
    return '$count queued';
  }

  @override
  String settings_mediaStorage_transfers_waitingRetry(int count) {
    return '$count waiting to retry';
  }

  @override
  String get settings_mediaStorage_verify_action => 'Verify library';

  @override
  String get settings_mediaStorage_verify_running =>
      'Verifying media library...';

  @override
  String settings_mediaStorage_verify_summary(
    int checked,
    int removed,
    int repaired,
    int aborted,
  ) {
    return 'Checked $checked objects: removed $removed orphans, queued $repaired repairs, aborted $aborted stale uploads';
  }

  @override
  String get settings_mediaStorage_backfill_action => 'Upload existing library';

  @override
  String settings_mediaStorage_backfill_enqueued(int count) {
    return '$count uploads queued';
  }

  @override
  String get settings_mediaStorage_policy_autoUpload =>
      'Upload photos automatically';

  @override
  String get settings_mediaStorage_policy_photosOnCellular =>
      'Upload photos on cellular';

  @override
  String get settings_mediaStorage_provider_label => 'Provider';

  @override
  String get settings_mediaStorage_connect_dropbox_hint =>
      'Uses your Dropbox connection from Cloud Sync. Media is stored in your Dropbox app folder.';

  @override
  String get settings_mediaStorage_connect_gdrive_hint =>
      'Signs in with Google. Media is stored in this app\'s private Drive space.';

  @override
  String get settings_mediaStorage_connect_icloud_hint =>
      'Media is stored in this app\'s iCloud container and syncs through your Apple ID.';

  @override
  String settings_mediaStorage_connect_action(String provider) {
    return 'Connect $provider';
  }

  @override
  String get bodyWeight_addEntry => 'Add measurement';

  @override
  String get bodyWeight_dateLabel => 'Date';

  @override
  String get bodyWeight_deleteTooltip => 'Delete entry';

  @override
  String get bodyWeight_heightLabel => 'Height (cm)';

  @override
  String get bodyWeight_heightFeetLabel => 'Height (ft)';

  @override
  String get bodyWeight_heightInchesLabel => 'Inches';

  @override
  String bodyWeight_weightLabel(String unit) {
    return 'Weight ($unit)';
  }

  @override
  String diveLog_edit_weightFeedback_amount(String unit) {
    return 'By about how much ($unit)';
  }

  @override
  String get diveLog_edit_weightFeedback_correct => 'Felt right';

  @override
  String get diveLog_edit_weightFeedback_label => 'How was your weighting?';

  @override
  String get diveLog_edit_weightFeedback_over => 'Overweighted';

  @override
  String get diveLog_edit_weightFeedback_under => 'Underweighted';

  @override
  String get diverProfile_bodyWeight_empty => 'Not recorded';

  @override
  String get diverProfile_bodyWeight_title => 'Body Weight';

  @override
  String get equipment_edit_advanced_title => 'Advanced';

  @override
  String get equipment_edit_buoyancyHint_exposure =>
      'Positive: how much it floats';

  @override
  String get equipment_edit_buoyancyHint_generic => 'Negative if it sinks';

  @override
  String get equipment_edit_buoyancyHint_tank =>
      'Leave empty - tanks use their own specifications';

  @override
  String equipment_edit_buoyancyLabel(String unit) {
    return 'Buoyancy ($unit)';
  }

  @override
  String equipment_edit_dryWeightLabel(String unit) {
    return 'Dry weight ($unit)';
  }

  @override
  String equipment_edit_liftCapacityLabel(String unit) {
    return 'Lift capacity ($unit)';
  }

  @override
  String get equipment_edit_liftCapacityHint => 'Wing or BCD rated lift';

  @override
  String get planner_gearWeights_accept => 'Use as planned weight';

  @override
  String get planner_gearWeights_addGear => 'Add gear';

  @override
  String get planner_gearWeights_empty => 'Add gear to predict your weighting';

  @override
  String planner_gearWeights_planned(String weight) {
    return 'Planned: $weight';
  }

  @override
  String planner_gearWeights_predicted(String weight) {
    return 'Predicted: $weight';
  }

  @override
  String get planner_gearWeights_title => 'Gear & Weights';

  @override
  String get planner_gearWeights_useSet => 'Use set';

  @override
  String get tools_weight_addGear => 'Add gear';

  @override
  String get tools_weight_addTank => 'Add tank';

  @override
  String tools_weight_basedOnDives(int count) {
    return 'Based on $count logged dives';
  }

  @override
  String get tools_weight_breakdownTitle => 'How this was calculated';

  @override
  String get tools_weight_confidence_high => 'High confidence';

  @override
  String get tools_weight_confidence_low => 'Low confidence - estimate';

  @override
  String get tools_weight_confidence_medium => 'Medium confidence';

  @override
  String tools_weight_deltaVsPrevious(String delta) {
    return '$delta vs previous rig';
  }

  @override
  String get tools_weight_noGear =>
      'Add the gear you plan to dive to personalize the prediction.';

  @override
  String get tools_weight_personalTerm => 'Personal baseline';

  @override
  String get tools_weight_placementTitle => 'Suggested placement';

  @override
  String get tools_weight_predictedWeight => 'Predicted weight';

  @override
  String get tools_weight_saveToProfile => 'Save weight to profile';

  @override
  String get tools_weight_source_measured => 'measured from your dives';

  @override
  String get tools_weight_source_physics => 'physics';

  @override
  String get tools_weight_source_typeDefault => 'default estimate';

  @override
  String get tools_weight_source_userSpec => 'from your gear specs';

  @override
  String get tools_weight_tanks => 'Tanks';

  @override
  String get tools_weight_useSet => 'Use set';

  @override
  String get tools_weight_waterTerm => 'Water type';

  @override
  String get dive3d_previewTitle => '3D View';

  @override
  String get dive3d_previewHint => 'Tap to explore in 3D';

  @override
  String get dive3d_resetView => 'Reset view';

  @override
  String get dive3d_zoomIn => 'Zoom in';

  @override
  String get dive3d_zoomOut => 'Zoom out';

  @override
  String get dive3d_play => 'Play';

  @override
  String get dive3d_pause => 'Pause';

  @override
  String get dive3d_overlays => 'Overlays';

  @override
  String get dive3d_overlay_strata => 'Temperature layers';

  @override
  String get dive3d_overlay_ceiling => 'Deco ceiling';

  @override
  String get dive3d_overlay_curtain => 'Depth curtain';

  @override
  String get dive3d_overlay_markers => 'Markers';

  @override
  String get dive3d_seascape_overlay_paths => 'Dive paths';

  @override
  String get dive3d_seascape_overlay_contours => 'Contours';

  @override
  String get dive3d_seascape_overlay_walls => 'Steep walls';

  @override
  String get dive3d_overlay_water => 'Water surface';

  @override
  String get dive3d_seascape_legend_land => 'Land';

  @override
  String get dive3d_seascape_appearance => 'Terrain appearance';

  @override
  String get dive3d_seascape_chartView => 'Chart view';

  @override
  String get dive3d_seascape_orbitView => '3D view';

  @override
  String get dive3d_seascape_appearance_surface => 'Terrain surface';

  @override
  String get dive3d_seascape_appearance_surfaceDepth => 'Depth colors';

  @override
  String get dive3d_seascape_appearance_surfaceImagery => 'Map imagery';

  @override
  String get dive3d_seascape_appearance_surfaceBlend => 'Blend';

  @override
  String get siteFeature_type_wreck => 'Wreck';

  @override
  String get siteFeature_type_mooring => 'Mooring';

  @override
  String get siteFeature_type_entry => 'Entry point';

  @override
  String get siteFeature_type_exit => 'Exit point';

  @override
  String get siteFeature_type_swimThrough => 'Swim-through';

  @override
  String get siteFeature_type_hazard => 'Hazard';

  @override
  String get siteFeature_type_current => 'Current';

  @override
  String get siteFeature_sectionTitle => 'Features';

  @override
  String get siteFeature_addAction => 'Add feature';

  @override
  String get siteFeature_placeHint => 'Tap the map to place the feature';

  @override
  String get siteFeature_addTitle => 'Add feature';

  @override
  String get siteFeature_editTitle => 'Edit feature';

  @override
  String get siteFeature_field_name => 'Name';

  @override
  String get siteFeature_field_bearing => 'Bearing (°)';

  @override
  String get siteFeature_field_depth => 'Depth';

  @override
  String get siteFeature_field_notes => 'Notes';

  @override
  String get siteFeature_deleteAction => 'Delete';

  @override
  String siteFeature_deleteConfirm(String name) {
    return 'Delete $name?';
  }

  @override
  String get siteScape_mode2d => 'Map';

  @override
  String get siteScape_mode3d => '3D';

  @override
  String get dive3d_seascape_appearance_rampRange => 'Limit color depth range';

  @override
  String get dive3d_seascape_appearance_rampMax => 'Deepest color at';

  @override
  String get dive3d_seascape_appearance_banded => 'Banded gradient';

  @override
  String get dive3d_seascape_appearance_contours => 'Contour levels';

  @override
  String get dive3d_seascape_appearance_contourAuto => 'Auto';

  @override
  String get dive3d_seascape_appearance_contourCustom => 'Custom';

  @override
  String get dive3d_seascape_appearance_addLevel => 'Add level';

  @override
  String get dive3d_seascape_appearance_defaultColor => 'Default';

  @override
  String get dive3d_seascape_appearance_wallAngle => 'Steep wall angle';

  @override
  String get dive3d_seascape_appearance_wallAngleNote =>
      'Bathymetry cells average the slope inside them, so real walls read flatter than they are. Keep this well under 45 degrees.';

  @override
  String get dive3d_seascape_siteTitle => 'Site Seascape';

  @override
  String dive3d_seascape_seafloorSource(String source, String resolution) {
    return 'Seafloor: $source (~$resolution m)';
  }

  @override
  String get dive3d_seascape_noCoordinates =>
      'This site has no GPS coordinates';

  @override
  String get dive3d_seascape_noData =>
      'No bathymetry available for this location';

  @override
  String dive3d_seascape_axis_distance(String unitSymbol) {
    return 'Distance ($unitSymbol)';
  }

  @override
  String get settings_about_bathymetryCredit =>
      'Bathymetry data: GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022';

  @override
  String get dive3d_metric_depth => 'Depth';

  @override
  String get dive3d_metric_temperature => 'Temp';

  @override
  String get dive3d_metric_ascentRate => 'Ascent';

  @override
  String get dive3d_metric_ppO2 => 'ppO2';

  @override
  String get dive3d_metric_cns => 'CNS';

  @override
  String get dive3d_metric_heartRate => 'HR';

  @override
  String get dive3d_metric_tankPressure => 'Pressure';

  @override
  String get dive3d_zAxis => 'Z axis';

  @override
  String get dive3d_zAxis_none => 'None';

  @override
  String get dive3d_overlay_shadows => 'Wall shadows';

  @override
  String get dive3d_metric_tts => 'TTS';

  @override
  String dive3d_axis_depth(String unitSymbol) {
    return 'Depth ($unitSymbol)';
  }

  @override
  String get dive3d_axis_time => 'Run time (min)';

  @override
  String get dive3d_pose_menu => 'Camera';

  @override
  String get dive3d_pose_default => 'Default view';

  @override
  String get dive3d_pose_front => 'Front (depth vs time)';

  @override
  String get dive3d_pose_side => 'Side (depth vs metric)';

  @override
  String get dive3d_pose_top => 'Top (metric vs time)';

  @override
  String get dive3d_readout_runTime => 'Run time';

  @override
  String get dive3d_readout_ceiling => 'Ceiling';

  @override
  String dive3d_readout_tank(int n) {
    return 'Tank $n';
  }

  @override
  String get dive3d_scene_dive => 'Dive';

  @override
  String get dive3d_scene_tissue => 'Tissues';

  @override
  String get dive3d_tissue_gasCombined => 'Combined';

  @override
  String get dive3d_tissue_gasN2 => 'N2';

  @override
  String get dive3d_tissue_gasHe => 'He';

  @override
  String get dive3d_tissue_colorMValue => '% M-value';

  @override
  String get dive3d_tissue_colorAbsolute => 'Loading';

  @override
  String get dive3d_tissue_controlling => 'Controlling';

  @override
  String get dive3d_tissue_surfaceInterval => 'Surface interval';

  @override
  String get dive3d_career_title => '3D History';

  @override
  String get dive3d_career_colorRecency => 'Recency';

  @override
  String get dive3d_career_colorDepth => 'Depth';

  @override
  String get dive3d_career_empty => 'No dives with profiles to show';

  @override
  String get dive3d_spatial_title => '3D Seascape';

  @override
  String get dive3d_spatial_estimatedPath => 'Estimated path (dead reckoning)';

  @override
  String get dive3d_spatial_synthesizedSeafloor => 'Synthesized seafloor';

  @override
  String get dive3d_spatial_noPath =>
      'Not enough data to reconstruct the dive path';

  @override
  String get dive3d_tissue_legendHeight =>
      'Height & color: % of the M-value limit';

  @override
  String get dive3d_tissue_legendLimit => 'Red plane = deco limit';

  @override
  String get dive3d_tissue_legendAxes =>
      'Left→right: time · Front→back: fast→slow tissues';

  @override
  String get dive3d_tissue_legendDepth => 'Blue curve: your depth';

  @override
  String get dive3d_tissue_onGassing => 'On-gassing';

  @override
  String get dive3d_tissue_offGassing => 'Off-gassing';

  @override
  String dive3d_tissue_tooltipCompartment(int number) {
    return 'Comp $number';
  }

  @override
  String dive3d_tissue_tooltipHalfTime(int minutes) {
    return '$minutes min N2';
  }

  @override
  String dive3d_tissue_tooltipSaturation(int percent) {
    return 'Saturation $percent%';
  }

  @override
  String dive3d_tissue_tooltipProgress(int percent) {
    return '$percent% of dive';
  }

  @override
  String get dive3d_tissue_stateEquilibrium => 'Equilibrium';

  @override
  String get dive3d_tissue_statePastMValue => 'Past M-value';

  @override
  String get dive3d_tissue_axisTime => 'Time';

  @override
  String get dive3d_tissue_axisSaturation => 'Saturation %';

  @override
  String get dive3d_tissue_axisCompartment => 'Compartment';

  @override
  String get dive3d_compare_computers_title => 'Compare computers';

  @override
  String get dive3d_compare_dives_title => 'Compare dives';

  @override
  String get dive3d_scene_computers => 'Computers';

  @override
  String get dive3d_compare_layout_sideBySide => 'Side by side';

  @override
  String get dive3d_compare_layout_overlay => 'Overlay';

  @override
  String get dive3d_compare_empty =>
      'Need at least 2 profiles with depth data to compare';

  @override
  String dive3d_compare_showing(Object shown, Object total) {
    return 'Showing $shown of $total';
  }

  @override
  String get dive3d_compare_setReference => 'Set as reference';

  @override
  String get diveLog_selection_tooltip_compare3d => 'Compare in 3D';

  @override
  String get diveLog_sources_compareIn3d => 'Compare in 3D';

  @override
  String get settings_setup_pendingTitle => 'Finish setting up this device';

  @override
  String settings_setup_mediaStoreAttach(String hint) {
    return 'Connect media storage ($hint)';
  }

  @override
  String settings_setup_accountSignIn(String label) {
    return 'Sign in to $label';
  }

  @override
  String get settings_setup_dismiss => 'Dismiss';

  @override
  String get settings_photosMedia_title => 'Photos & Media';

  @override
  String get settings_photosMedia_subtitle => 'Sources, storage & accounts';

  @override
  String get settings_photosMedia_sourcesHeader => 'Where photos come from';

  @override
  String get settings_photosMedia_storageHeader => 'Where copies are kept';

  @override
  String get settings_photosMedia_accountsHeader => 'Accounts';

  @override
  String get settings_photosMedia_displayHeader => 'Display';

  @override
  String get settings_photosMedia_guidedSetup => 'Guided setup';

  @override
  String get settings_photosMedia_photoSources_title =>
      'Photo library & sources';

  @override
  String get settings_photosMedia_photoSources_subtitle =>
      'Gallery, files and import options';

  @override
  String get settings_photosMedia_networkSources_title => 'Network sources';

  @override
  String get settings_photosMedia_networkSources_subtitle =>
      'URLs and manifest feeds (advanced)';

  @override
  String get settings_connectedAccounts_title => 'Connected Accounts';

  @override
  String get settings_connectedAccounts_subtitle =>
      'Cloud and service sign-ins';

  @override
  String get settings_connectedAccounts_empty => 'No accounts connected yet';

  @override
  String get settings_connectedAccounts_status_signedIn => 'Signed in';

  @override
  String get settings_connectedAccounts_status_needsSignIn => 'Needs sign-in';

  @override
  String get settings_connectedAccounts_status_unavailable =>
      'Unavailable on this device';

  @override
  String get settings_connectedAccounts_disconnectDevice =>
      'Sign out on this device';

  @override
  String get settings_connectedAccounts_removeFromLibrary =>
      'Remove from library';

  @override
  String get settings_connectedAccounts_removeConfirmTitle => 'Remove account?';

  @override
  String get settings_connectedAccounts_removeConfirmBody =>
      'The account is removed from every synced device. Credentials stored on other devices are not deleted.';

  @override
  String get settings_setupGuide_title => 'Set up photos & media';

  @override
  String get settings_setupGuide_intro =>
      'Connect where your photos come from and where copies are kept. You can re-run this any time.';

  @override
  String get settings_setupGuide_stepSources => 'Photo sources';

  @override
  String get settings_setupGuide_stepSources_desc =>
      'Attach photos from your photo library, files, or Lightroom.';

  @override
  String get settings_setupGuide_stepStorage => 'Media storage';

  @override
  String get settings_setupGuide_stepStorage_desc =>
      'Keep copies of your photos in your own cloud so every device can show them.';

  @override
  String get settings_setupGuide_stepSync => 'Cloud sync';

  @override
  String get settings_setupGuide_stepSync_desc =>
      'Sync dive data between devices.';

  @override
  String get settings_setupGuide_statusDone => 'Set up';

  @override
  String get settings_setupGuide_statusTodo => 'Not set up';

  @override
  String get settings_setupGuide_open => 'Open';

  @override
  String get settings_connectedAccounts_loadError => 'Could not load accounts';

  @override
  String get media_unavailablePlaceholder_volumeOffline => 'Volume not mounted';

  @override
  String get media_unavailablePlaceholder_stillFetching =>
      'Still loading. Tap to retry.';

  @override
  String get media_unavailablePlaceholder_accessDenied =>
      'No photo library access';

  @override
  String get attrLabel_size => 'Size';

  @override
  String get attrLabel_thickness_mm => 'Thickness (mm)';

  @override
  String get attrLabel_suit_style => 'Suit style';

  @override
  String get attrLabel_shell_material => 'Shell material';

  @override
  String get attrLabel_seal_type => 'Seal type';

  @override
  String get attrLabel_volume_l => 'Volume';

  @override
  String get attrLabel_working_pressure_bar => 'Working pressure';

  @override
  String get attrLabel_tank_material => 'Material';

  @override
  String get attrLabel_valve_type => 'Valve';

  @override
  String get attrLabel_tank_identifier => 'Identifier';

  @override
  String get attrLabel_last_visual_inspection => 'Last visual inspection';

  @override
  String get attrLabel_last_hydro_test => 'Last hydrostatic test';

  @override
  String get attrLabel_connection => 'Connection';

  @override
  String get attrLabel_cold_water_rated => 'Cold-water rated';

  @override
  String get attrLabel_bcd_style => 'Style';

  @override
  String get attrLabel_lift_capacity_kg => 'Lift capacity';

  @override
  String get attrLabel_heel_type => 'Heel';

  @override
  String get attrLabel_blade_style => 'Blade';

  @override
  String get attrLabel_mount => 'Mount';

  @override
  String get attrLabel_connectivity => 'Connectivity';

  @override
  String get attrLabel_lens_config => 'Lens';

  @override
  String get attrLabel_prescription => 'Prescription lenses';

  @override
  String get attrLabel_weight_style => 'Style';

  @override
  String get attrLabel_lumens => 'Lumens';

  @override
  String get attrLabel_beam_type => 'Beam';

  @override
  String get attrLabel_depth_rating_m => 'Depth rating';

  @override
  String get attrLabel_smb_type => 'Type';

  @override
  String get attrLabel_length_m => 'Length';

  @override
  String get attrLabel_reel_type => 'Type';

  @override
  String get attrLabel_line_length_m => 'Line length';

  @override
  String get attrLabel_blade_material => 'Blade material';

  @override
  String get attrLabel_tip_type => 'Tip';

  @override
  String get attrLabel_glove_type => 'Type';

  @override
  String get attrLabel_sole_type => 'Sole';

  @override
  String get attrLabel_buoyancy_kg => 'Buoyancy';

  @override
  String get attrLabel_dry_weight_kg => 'Dry weight';

  @override
  String get attrLabel_unit_type => 'Unit type';

  @override
  String get attrLabel_mount_configuration => 'Mount';

  @override
  String get attrLabel_scrubber_type => 'Scrubber type';

  @override
  String get attrLabel_scrubber_duration_h => 'Scrubber duration (h)';

  @override
  String get attrLabel_o2_cell_count => 'O2 cells';

  @override
  String get attrLabel_diluent_cylinder_l => 'Diluent cylinder';

  @override
  String get attrLabel_o2_cylinder_l => 'O2 cylinder';

  @override
  String get attrLabel_dpv_style => 'Style';

  @override
  String get attrLabel_burn_time_h => 'Burn time';

  @override
  String get attrLabel_battery_type => 'Battery';

  @override
  String get attrLabel_battery_capacity_wh => 'Battery capacity (Wh)';

  @override
  String get attrLabel_motor_type => 'Motor';

  @override
  String get attrLabel_speed_mps => 'Top speed';

  @override
  String get attrChoice_unit_type_eccr => 'Electronic CCR (eCCR)';

  @override
  String get attrChoice_unit_type_mccr => 'Manual CCR (mCCR)';

  @override
  String get attrChoice_unit_type_hccr => 'Hybrid CCR (hCCR)';

  @override
  String get attrChoice_unit_type_scr_cmf => 'SCR - constant mass flow';

  @override
  String get attrChoice_unit_type_scr_pascr => 'SCR - passive addition';

  @override
  String get attrChoice_unit_type_scr_escr => 'SCR - electronically controlled';

  @override
  String get attrChoice_mount_configuration_back => 'Back mount';

  @override
  String get attrChoice_mount_configuration_chest => 'Chest mount';

  @override
  String get attrChoice_mount_configuration_sidemount => 'Sidemount';

  @override
  String get attrChoice_scrubber_type_axial => 'Axial';

  @override
  String get attrChoice_scrubber_type_radial => 'Radial';

  @override
  String get attrChoice_suit_style_full => 'Full suit';

  @override
  String get attrChoice_suit_style_shorty => 'Shorty';

  @override
  String get attrChoice_suit_style_two_piece => 'Two-piece';

  @override
  String get attrChoice_suit_style_semi_dry => 'Semi-dry';

  @override
  String get attrChoice_shell_material_trilaminate => 'Trilaminate';

  @override
  String get attrChoice_shell_material_neoprene => 'Neoprene';

  @override
  String get attrChoice_shell_material_crushed_neoprene => 'Crushed neoprene';

  @override
  String get attrChoice_shell_material_vulcanized_rubber => 'Vulcanized rubber';

  @override
  String get attrChoice_seal_type_latex => 'Latex';

  @override
  String get attrChoice_seal_type_silicone => 'Silicone';

  @override
  String get attrChoice_seal_type_neoprene => 'Neoprene';

  @override
  String get attrChoice_tank_material_aluminum => 'Aluminum';

  @override
  String get attrChoice_tank_material_steel => 'Steel';

  @override
  String get attrChoice_tank_material_carbon_composite => 'Carbon composite';

  @override
  String get attrChoice_valve_type_din => 'DIN';

  @override
  String get attrChoice_valve_type_yoke => 'Yoke (INT)';

  @override
  String get attrChoice_valve_type_convertible => 'Convertible';

  @override
  String get attrChoice_connection_din => 'DIN';

  @override
  String get attrChoice_connection_yoke => 'Yoke (INT)';

  @override
  String get attrChoice_bcd_style_jacket => 'Jacket';

  @override
  String get attrChoice_bcd_style_back_inflate => 'Back-inflate';

  @override
  String get attrChoice_bcd_style_wing => 'Wing';

  @override
  String get attrChoice_bcd_style_sidemount => 'Sidemount';

  @override
  String get attrChoice_heel_type_open_heel => 'Open heel';

  @override
  String get attrChoice_heel_type_full_foot => 'Full foot';

  @override
  String get attrChoice_blade_style_paddle => 'Paddle';

  @override
  String get attrChoice_blade_style_split => 'Split';

  @override
  String get attrChoice_blade_style_vented => 'Vented';

  @override
  String get attrChoice_mount_wrist => 'Wrist';

  @override
  String get attrChoice_mount_console => 'Console';

  @override
  String get attrChoice_mount_hud => 'HUD';

  @override
  String get attrChoice_connectivity_ble => 'Bluetooth (BLE)';

  @override
  String get attrChoice_connectivity_usb => 'USB';

  @override
  String get attrChoice_connectivity_infrared => 'Infrared';

  @override
  String get attrChoice_connectivity_none => 'None';

  @override
  String get attrChoice_lens_config_single => 'Single lens';

  @override
  String get attrChoice_lens_config_twin => 'Twin lens';

  @override
  String get attrChoice_lens_config_frameless => 'Frameless';

  @override
  String get attrChoice_weight_style_belt => 'Belt';

  @override
  String get attrChoice_weight_style_integrated => 'Integrated';

  @override
  String get attrChoice_weight_style_trim => 'Trim';

  @override
  String get attrChoice_weight_style_ankle => 'Ankle';

  @override
  String get attrChoice_beam_type_spot => 'Spot';

  @override
  String get attrChoice_beam_type_flood => 'Flood';

  @override
  String get attrChoice_beam_type_adjustable => 'Adjustable';

  @override
  String get attrChoice_smb_type_open => 'Open';

  @override
  String get attrChoice_smb_type_closed => 'Closed';

  @override
  String get attrChoice_reel_type_spool => 'Spool';

  @override
  String get attrChoice_reel_type_ratchet => 'Ratchet';

  @override
  String get attrChoice_blade_material_stainless => 'Stainless steel';

  @override
  String get attrChoice_blade_material_titanium => 'Titanium';

  @override
  String get attrChoice_tip_type_pointed => 'Pointed';

  @override
  String get attrChoice_tip_type_blunt => 'Blunt';

  @override
  String get attrChoice_tip_type_line_cutter => 'Line cutter';

  @override
  String get attrChoice_glove_type_five_finger => 'Five-finger';

  @override
  String get attrChoice_glove_type_mitt => 'Mitt';

  @override
  String get attrChoice_glove_type_dry => 'Dry';

  @override
  String get attrChoice_sole_type_hard => 'Hard sole';

  @override
  String get attrChoice_sole_type_soft => 'Soft sole';

  @override
  String get attrChoice_dpv_style_tow_behind => 'Tow-behind';

  @override
  String get attrChoice_dpv_style_ride_on => 'Ride-on';

  @override
  String get attrChoice_dpv_style_handheld => 'Handheld';

  @override
  String get attrChoice_battery_type_lithium_ion => 'Lithium-ion';

  @override
  String get attrChoice_battery_type_nimh => 'NiMH';

  @override
  String get attrChoice_battery_type_lead_acid => 'Lead-acid';

  @override
  String get attrChoice_motor_type_brushless => 'Brushless';

  @override
  String get attrChoice_motor_type_brushed => 'Brushed';

  @override
  String get equipment_edit_customFieldsTitle => 'Custom fields';

  @override
  String get equipment_edit_addCustomField => 'Add custom field';

  @override
  String get attr_flagYes => 'Yes';

  @override
  String get attr_flagNo => 'No';

  @override
  String get equipment_edit_invalidThickness => 'Use 5, 5/4 or 7/5/3';

  @override
  String get statistics_progression_divesBySuitThickness_title =>
      'Dives by Suit Thickness';

  @override
  String get statistics_progression_divesBySuitThickness_subtitle =>
      'Exposure suit primary thickness across your dives';

  @override
  String get statistics_progression_divesBySuitThickness_empty =>
      'No dives with a suit thickness recorded';

  @override
  String get statistics_progression_divesBySuitThickness_error =>
      'Could not load suit thickness data';

  @override
  String get diveLog_filter_sectionSuitThickness => 'Suit thickness (mm)';

  @override
  String get diveLog_filter_thicknessMin => 'Min';

  @override
  String get diveLog_filter_thicknessMax => 'Max';

  @override
  String get safetySettings_noFlyHeader => 'Flying after diving';

  @override
  String get safetySettings_noFlyPreset_standard => 'Standard (12/18/24 h)';

  @override
  String get safetySettings_noFlyPreset_strict => 'Strict (18/24/48 h)';

  @override
  String get safetySettings_noFlyPreset_subtitle =>
      'Guideline intervals after a single no-deco dive, repetitive dives, and deco dives';

  @override
  String get flightWindow_closed => 'No more diving before your flight';

  @override
  String get flightWindow_conflict =>
      'Your no-fly time extends past your flight departure';

  @override
  String flightWindow_departs(String time) {
    return 'Flight departs $time';
  }

  @override
  String flightWindow_openTitle(String remaining) {
    return 'Time left to dive: $remaining';
  }

  @override
  String flightWindow_surfaceBy(String time) {
    return 'Surface by $time';
  }

  @override
  String safetyHub_noFly_active_title(String remaining) {
    return 'No-fly: $remaining remaining';
  }

  @override
  String safetyHub_noFly_until(String time) {
    return 'Until $time';
  }

  @override
  String get safetyHub_noFly_clear_title => 'No flying restriction';

  @override
  String get safetyHub_noFly_clear_subtitle => 'No active flying restriction';

  @override
  String safetyHub_noFly_category_single(int hours) {
    return 'After a single no-deco dive: $hours h guideline';
  }

  @override
  String safetyHub_noFly_category_repetitive(int hours) {
    return 'After repetitive dives: $hours h guideline';
  }

  @override
  String safetyHub_noFly_category_deco(int hours) {
    return 'After a decompression dive: $hours h guideline';
  }

  @override
  String get safetyHub_noFly_disclaimer =>
      'DAN/UHMS guideline intervals from your last dive. Not a substitute for your dive computer\'s no-fly time.';

  @override
  String get diveLog_detail_altitudeMismatch_title => 'Site is at altitude';

  @override
  String get diveLog_detail_altitudeMismatch_subtitle =>
      'This site records an altitude but the dive has none set, so decompression analysis assumed sea level. Set the dive\'s altitude to correct it.';

  @override
  String diveLog_detail_sacVolumeHint(String unit) {
    return 'Add a cylinder volume to show SAC in $unit/min';
  }

  @override
  String safetyHub_alert_noFly(String remaining) {
    return 'No-fly: $remaining remaining';
  }

  @override
  String get emergencyCard_title => 'Emergency';

  @override
  String emergencyCard_callDan(String name) {
    return 'Call $name';
  }

  @override
  String get emergencyCard_callDan_subtitle =>
      'Diver emergency hotline. Call first: they coordinate evacuation and chamber referral.';

  @override
  String emergencyCard_ems(String number) {
    return 'Local emergency services: $number';
  }

  @override
  String get emergencyCard_diverSection => 'Diver';

  @override
  String emergencyCard_bloodType(String value) {
    return 'Blood type: $value';
  }

  @override
  String emergencyCard_allergies(String value) {
    return 'Allergies: $value';
  }

  @override
  String emergencyCard_medications(String value) {
    return 'Medications: $value';
  }

  @override
  String get emergencyCard_contactsSection => 'Emergency contacts';

  @override
  String get emergencyCard_insuranceSection => 'Dive insurance';

  @override
  String emergencyCard_insurancePolicy(String number) {
    return 'Policy $number';
  }

  @override
  String get emergencyCard_chambersSection => 'Hyperbaric chambers';

  @override
  String get emergencyCard_chambersNote =>
      'Availability changes. Always call the diver emergency hotline first for referral.';

  @override
  String emergencyCard_chamberVerified(String date) {
    return 'Details verified $date';
  }

  @override
  String get emergencyCard_chambersNearby => 'Nearest chambers';

  @override
  String emergencyCard_chamberViewAll(int count) {
    return 'View all $count chambers';
  }

  @override
  String get emergencyCard_chambersNoneNearby =>
      'No chamber listed within range. Call the diver emergency hotline: they will route you to the nearest facility that can treat you.';

  @override
  String get emergencyCard_chamberCapability_divingEmergency =>
      'Treats diving injuries';

  @override
  String get emergencyCard_chamberCapability_hyperbaricUnit =>
      'Hospital hyperbaric unit';

  @override
  String get emergencyCard_chamberCapability_elective =>
      'Elective therapy only';

  @override
  String get emergencyCard_chamberCapability_unknown =>
      'Capability unconfirmed';

  @override
  String get emergencyCard_chamberAvailability_h24 => '24h';

  @override
  String get emergencyCard_chamberAvailability_onCall => 'On call';

  @override
  String get emergencyCard_chamberAvailability_businessHours =>
      'Business hours';

  @override
  String get emergencyCard_chamberUnverified =>
      'Not confirmed with the facility';

  @override
  String get chambersDirectory_title => 'Hyperbaric chambers';

  @override
  String get chambersDirectory_search => 'Search by name, city or country';

  @override
  String get chambersDirectory_empty => 'No chamber matches that search.';

  @override
  String chambersDirectory_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chambers',
      one: '1 chamber',
    );
    return '$_temp0';
  }

  @override
  String get emergencyCard_hideChamber => 'Hide';

  @override
  String get emergencyCard_chamberHidden => 'Chamber hidden';

  @override
  String get emergencyCard_undo => 'Undo';

  @override
  String get emergencyCard_addChamber => 'Add chamber';

  @override
  String get emergencyCard_deleteChamber => 'Delete';

  @override
  String emergencyCard_regionLabel(String region) {
    return 'Region: $region';
  }

  @override
  String get emergencyCard_regionUnknown =>
      'Region unknown - using worldwide hotline';

  @override
  String get emergencyCard_noDiverData =>
      'No diver profile data. Add emergency contacts, medical and insurance details in Diver Profile settings.';

  @override
  String get addChamber_title => 'Add chamber';

  @override
  String get addChamber_name => 'Name';

  @override
  String get addChamber_country => 'Country code (e.g. US)';

  @override
  String get addChamber_city => 'City';

  @override
  String get addChamber_phone => 'Phone';

  @override
  String get addChamber_notes => 'Notes';

  @override
  String get addChamber_save => 'Save';

  @override
  String get addChamber_nameRequired => 'Name is required';

  @override
  String get addChamber_countryRequired => 'Country code is required';

  @override
  String get addChamber_phoneRequired => 'Phone number is required';

  @override
  String get safetyHub_emergencyCardLink => 'Emergency card';

  @override
  String get safetyHub_emergencyCardLink_subtitle =>
      'Offline: hotline, EMS, chambers, your medical and insurance details';

  @override
  String get dashboard_quickAction_emergency => 'Emergency card';

  @override
  String get incidents_title => 'Near-miss log';

  @override
  String get incidents_empty =>
      'No near-misses logged. Recording what almost went wrong - without judgment - is how patterns become visible before they become accidents.';

  @override
  String get incidents_add => 'Log near-miss';

  @override
  String get incidents_linkedDive => 'Linked to a dive';

  @override
  String get incidents_delete_confirm => 'Delete this near-miss report?';

  @override
  String get incidents_notFound => 'Near-miss report not found';

  @override
  String get incidentEdit_title_new => 'Log near-miss';

  @override
  String get incidentEdit_title_edit => 'Edit near-miss';

  @override
  String get incidentEdit_category => 'Category';

  @override
  String get incidentEdit_severity => 'Severity';

  @override
  String get incidentEdit_severity_minor => 'Minor';

  @override
  String get incidentEdit_severity_moderate => 'Moderate';

  @override
  String get incidentEdit_severity_serious => 'Serious';

  @override
  String get incidentEdit_date => 'When it happened';

  @override
  String get incidentEdit_narrative => 'What happened';

  @override
  String get incidentEdit_narrative_hint =>
      'Just the facts, in your own words. This stays private.';

  @override
  String get incidentEdit_narrative_required => 'Describe what happened';

  @override
  String get incidentEdit_contributingFactors => 'What contributed (optional)';

  @override
  String get incidentEdit_lessonsLearned =>
      'What would help next time (optional)';

  @override
  String get incidentEdit_save => 'Save';

  @override
  String get incidentEdit_privacyNote =>
      'Near-miss reports sync between your devices and are included in your backups, but are never included in exports or shared logbook pages.';

  @override
  String get incidentCategory_buoyancy => 'Buoyancy';

  @override
  String get incidentCategory_gasSupply => 'Gas supply';

  @override
  String get incidentCategory_equipment => 'Equipment';

  @override
  String get incidentCategory_buddySeparation => 'Buddy separation';

  @override
  String get incidentCategory_marineLife => 'Marine life';

  @override
  String get incidentCategory_boatSurface => 'Boat / surface';

  @override
  String get incidentCategory_medical => 'Medical';

  @override
  String get incidentCategory_planning => 'Planning';

  @override
  String get incidentCategory_other => 'Other';

  @override
  String get safetyHub_incidentsLink => 'Near-miss log';

  @override
  String get safetyHub_incidentsLink_subtitle =>
      'Private, non-punitive incident notes';

  @override
  String get diveLog_detail_menu_logNearMiss => 'Log near-miss';

  @override
  String diveLog_detail_linkedIncidents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count near-misses linked to this dive',
      one: '1 near-miss linked to this dive',
    );
    return '$_temp0';
  }

  @override
  String get planning_card_noFly_subtitle =>
      'Guideline countdown from your last dives';

  @override
  String get settings_section_safety_title => 'Safety';

  @override
  String get settings_section_safety_subtitle =>
      'Review rules & flying after diving';

  @override
  String get settings_section_security_title => 'App Security';

  @override
  String get settings_section_security_subtitle =>
      'App lock & database encryption';

  @override
  String get settings_security_appLock => 'App Lock';

  @override
  String get settings_security_appLock_subtitle =>
      'Require your password or biometrics to open the app';

  @override
  String get settings_security_biometrics => 'Unlock with biometrics';

  @override
  String get settings_security_autoLock => 'Auto-lock';

  @override
  String get settings_security_autoLock_immediately => 'Immediately';

  @override
  String settings_security_autoLock_minutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'After $minutes minutes',
      one: 'After 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get settings_security_autoLock_never => 'Never';

  @override
  String get settings_security_encryption => 'Encrypt database';

  @override
  String get settings_security_encryption_subtitle =>
      'Protect your dive log file with at-rest encryption. Encryption may affect performance.';

  @override
  String get settings_security_encryption_progress_backup =>
      'Creating safety backup...';

  @override
  String get settings_security_encryption_progress_encrypt =>
      'Encrypting database...';

  @override
  String get settings_security_encryption_progress_decrypt =>
      'Decrypting database...';

  @override
  String get settings_security_encryption_progress_reopen =>
      'Reopening database...';

  @override
  String get settings_security_changePassword => 'Change password';

  @override
  String get settings_security_regenerateRecovery => 'New recovery code';

  @override
  String get settings_security_setPassword => 'Set app password';

  @override
  String get settings_security_password => 'Password';

  @override
  String get settings_security_confirmPassword => 'Confirm password';

  @override
  String get settings_security_currentPassword => 'Current password';

  @override
  String get settings_security_newPassword => 'New password';

  @override
  String get settings_security_passwordTooShort =>
      'Password must be at least 4 characters.';

  @override
  String get settings_security_passwordMismatch => 'Passwords do not match.';

  @override
  String get settings_security_wrongPassword => 'Incorrect password.';

  @override
  String get settings_security_recoveryCode_title => 'Your recovery code';

  @override
  String get settings_security_recoveryCode_explain =>
      'Write this down and keep it safe. It is the only way to unlock the app if you forget your password, and it replaces any previous recovery code.';

  @override
  String get settings_security_recoveryCode_savedConfirm =>
      'I saved my recovery code';

  @override
  String get settings_security_disableBlockedByEncryption_title =>
      'Encryption is on';

  @override
  String get settings_security_disableBlockedByEncryption_body =>
      'Turn off database encryption before turning off App Lock. The encrypted database needs a credential.';

  @override
  String get settings_security_enableEncryption_title => 'Encrypt database?';

  @override
  String get settings_security_enableEncryption_body =>
      'A safety backup is created first, then the database file is re-encrypted in place. This can take a while for large dive logs. Encryption may affect performance.';

  @override
  String get settings_security_disableEncryption_title =>
      'Turn off encryption?';

  @override
  String get settings_security_disableEncryption_body =>
      'The database file will be stored unencrypted on disk again.';

  @override
  String get settings_security_turnOffAppLock_title => 'Turn off App Lock?';

  @override
  String get settings_security_turnOffAppLock_body =>
      'The app will open without asking for your password.';

  @override
  String get settings_security_unlock_title => 'Enter your password';

  @override
  String get settings_security_cancel => 'Cancel';

  @override
  String get settings_security_continue => 'Continue';

  @override
  String get settings_security_done => 'Done';

  @override
  String get settings_security_turnOff => 'Turn off';

  @override
  String get dataQuality_inbox_title => 'Data quality';

  @override
  String get dataQuality_badge_tooltip => 'Data quality review';

  @override
  String get dataQuality_scan_start => 'Scan library';

  @override
  String dataQuality_scan_progress(int done, int total) {
    return 'Checked $done of $total dives';
  }

  @override
  String get dataQuality_scan_cancel => 'Cancel';

  @override
  String dataQuality_scan_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scan complete - $count items to review',
      one: 'Scan complete - 1 item to review',
      zero: 'Scan complete - no new findings',
    );
    return '$_temp0';
  }

  @override
  String dataQuality_scan_errors(int count) {
    return '$count dives could not be fully checked';
  }

  @override
  String dataQuality_lastScan(String when) {
    return 'Last scan: $when';
  }

  @override
  String get dataQuality_neverScanned =>
      'Your logbook has not been scanned yet';

  @override
  String get dataQuality_empty_title => 'All clear';

  @override
  String get dataQuality_empty_subtitle =>
      'No data quality findings. Scan your library to check imported dives for problems.';

  @override
  String get dataQuality_banner_newChecks => 'New quality checks are available';

  @override
  String get dataQuality_banner_rescan => 'Rescan';

  @override
  String get dataQuality_action_dismiss => 'Dismiss';

  @override
  String get dataQuality_action_dismissFiltered => 'Dismiss all shown';

  @override
  String get dataQuality_action_goToDive => 'Go to dive';

  @override
  String get dataQuality_action_undo => 'Undo';

  @override
  String get dataQuality_repair_applied => 'Repair applied';

  @override
  String get dataQuality_repair_noChange => 'Nothing to repair here';

  @override
  String get dataQuality_repair_needsReview =>
      'No automatic fix. Open the dive to correct this.';

  @override
  String get dataQuality_repair_failed => 'Repair failed';

  @override
  String get dataQuality_chip_all => 'All';

  @override
  String get dataQuality_chip_time => 'Time';

  @override
  String get dataQuality_chip_profile => 'Profile';

  @override
  String get dataQuality_chip_gas => 'Gas';

  @override
  String get dataQuality_chip_tanks => 'Tanks';

  @override
  String get dataQuality_chip_duplicates => 'Duplicates';

  @override
  String get dataQuality_chip_sources => 'Sources';

  @override
  String get dataQuality_detector_clock_offset => 'Clock & timezone';

  @override
  String get dataQuality_detector_duplicate => 'Likely duplicate';

  @override
  String get dataQuality_detector_split_pair => 'Accidental split';

  @override
  String get dataQuality_detector_sample_gap => 'Sample gaps';

  @override
  String get dataQuality_detector_depth_spike => 'Depth spike';

  @override
  String get dataQuality_detector_impossible_rate => 'Impossible rate';

  @override
  String get dataQuality_detector_temp_anomaly => 'Temperature anomaly';

  @override
  String get dataQuality_detector_pressure_anomaly => 'Pressure anomaly';

  @override
  String get dataQuality_detector_gas_mod => 'Gas/MOD inconsistency';

  @override
  String get dataQuality_detector_tank_assignment => 'Wrong cylinder';

  @override
  String get dataQuality_detector_source_conflict => 'Conflicting sources';

  @override
  String dataQuality_msg_clock_future(String date) {
    return 'Dive is dated in the future ($date)';
  }

  @override
  String dataQuality_msg_clock_ancient(String date) {
    return 'Dive is dated before 1950 ($date)';
  }

  @override
  String dataQuality_msg_clock_offset(int hours) {
    return 'A source clock differs by $hours hours';
  }

  @override
  String dataQuality_msg_clock_overlap(int minutes) {
    return 'Overlaps another dive by $minutes min';
  }

  @override
  String dataQuality_msg_duplicate(int percent, int minutes) {
    return '$percent% match with a dive $minutes min apart';
  }

  @override
  String dataQuality_msg_split(int minutes) {
    return 'Same computer resumed after a $minutes min surface interval';
  }

  @override
  String dataQuality_msg_gap(int count, String longest) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gaps in samples',
      one: '1 gap in samples',
    );
    return '$_temp0, longest $longest';
  }

  @override
  String dataQuality_msg_spike(String depth, String time) {
    return 'Depth spike to $depth at $time';
  }

  @override
  String dataQuality_msg_negativeDepth(int count) {
    return '$count negative depth samples';
  }

  @override
  String dataQuality_msg_maxDepthMismatch(String stored, String profile) {
    return 'Logged max depth $stored but the profile shows $profile';
  }

  @override
  String dataQuality_msg_rate(String rate, int seconds) {
    return 'Vertical rate of $rate sustained for $seconds s';
  }

  @override
  String dataQuality_msg_tempRange(String min, String max) {
    return 'Water temperature outside the plausible range ($min to $max)';
  }

  @override
  String get dataQuality_msg_tempUnitBug =>
      'Values look like a temperature unit bug';

  @override
  String dataQuality_msg_tempJump(String delta) {
    return 'Temperature jumped $delta in one sample';
  }

  @override
  String dataQuality_msg_tempScalar(String temp) {
    return 'Logged water temperature $temp is implausible';
  }

  @override
  String dataQuality_msg_pressureSwap(String end, String start) {
    return 'End pressure $end is above start pressure $start';
  }

  @override
  String dataQuality_msg_pressureEndpoint(String record, String series) {
    return 'Tank record says $record but the sensor series shows $series';
  }

  @override
  String dataQuality_msg_pressureRise(String rise) {
    return 'Pressure rose $rise mid-dive with no gas switch';
  }

  @override
  String dataQuality_msg_sac(String sac) {
    return 'Implied surface consumption of $sac is implausible';
  }

  @override
  String dataQuality_msg_ppo2(String ppo2, String gas, String depth) {
    return 'ppO2 reached $ppo2 on $gas at $depth';
  }

  @override
  String dataQuality_msg_hypoxic(String gas) {
    return 'Hypoxic mix ($gas) shown in use at the surface';
  }

  @override
  String dataQuality_msg_switchMod(String depth, String mod) {
    return 'Gas switch at $depth is beyond that gas\'s MOD of $mod';
  }

  @override
  String dataQuality_msg_tankInactive(String drop) {
    return 'This tank lost $drop while the gas timeline says it was not in use';
  }

  @override
  String get dataQuality_msg_twinTanks =>
      'Two tanks carry a near-identical pressure series';

  @override
  String dataQuality_msg_sourceDepth(String primary, String source) {
    return 'Sources disagree on max depth: $primary vs $source';
  }

  @override
  String get dataQuality_msg_salinityHint =>
      'The consistent ratio suggests a salt/fresh water setting difference';

  @override
  String get dataQuality_msg_sourceDuration =>
      'Sources disagree on dive duration';

  @override
  String get dataQuality_msg_sourceTemp =>
      'Sources disagree on water temperature';

  @override
  String dataQuality_repairLabel_shiftTime(String offset) {
    return 'Shift time by $offset';
  }

  @override
  String get dataQuality_repairLabel_shiftImport =>
      'Shift all dives from this import';

  @override
  String get dataQuality_repairLabel_consolidate => 'Consolidate';

  @override
  String get dataQuality_repairLabel_combine => 'Combine into one dive';

  @override
  String get dataQuality_repairLabel_despike => 'Remove spike';

  @override
  String get dataQuality_repairLabel_clampNegative =>
      'Clamp above-surface depths';

  @override
  String get dataQuality_repairLabel_smoothRates => 'Smooth impossible rates';

  @override
  String get dataQuality_repairLabel_fillGaps => 'Fill gaps';

  @override
  String get dataQuality_repairLabel_smoothTemp => 'Smooth temperature';

  @override
  String get dataQuality_repairLabel_convertTemp => 'Convert temperature';

  @override
  String get dataQuality_repairLabel_recompute => 'Recalculate from profile';

  @override
  String get dataQuality_repairLabel_swapPressures => 'Swap start/end pressure';

  @override
  String get dataQuality_repairLabel_setFromSeries => 'Use sensor values';

  @override
  String get dataQuality_repairLabel_swapSeries => 'Swap tank series';

  @override
  String get dataQuality_repairLabel_reassignSeries =>
      'Move series to another tank';

  @override
  String get dataQuality_repairLabel_setPrimary => 'Make this source primary';

  @override
  String get dataQuality_repairLabel_split => 'Split into separate dives';

  @override
  String get dataQuality_repairLabel_compare => 'Compare profiles';

  @override
  String get dataQuality_settings_title => 'Data quality';

  @override
  String get dataQuality_settings_subtitle =>
      'Choose which checks run when scanning';

  @override
  String dataQuality_summary_flagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items flagged for review',
      one: '1 item flagged for review',
    );
    return '$_temp0';
  }

  @override
  String get dataQuality_summary_review => 'Review';

  @override
  String get dataQuality_detail_chip => 'Review';

  @override
  String dataQuality_detail_chipCount(int count) {
    return 'Review ($count)';
  }

  @override
  String get settings_mediaStorage_quality_section => 'Upload quality';

  @override
  String get settings_mediaStorage_quality_photos => 'Photos';

  @override
  String get settings_mediaStorage_quality_video => 'Video';

  @override
  String get settings_mediaStorage_quality_original => 'Original';

  @override
  String get settings_mediaStorage_quality_high => 'High';

  @override
  String get settings_mediaStorage_quality_balanced => 'Balanced';

  @override
  String get settings_mediaStorage_quality_small => 'Small';

  @override
  String get settings_mediaStorage_quality_caveat =>
      'With a compression level set, full-resolution originals are not uploaded — they remain only on this device.';

  @override
  String get settings_mediaStorage_quality_reuploadQueued => 'Re-upload queued';

  @override
  String get settings_mediaStorage_quality_linuxFfmpegHint =>
      'Install ffmpeg to enable video compression. Originals are uploaded until then.';

  @override
  String get settings_mediaStorage_quality_saveFailed =>
      'Could not save the upload quality. Try again.';

  @override
  String get settings_mediaStorage_quality_noTranscoderHint =>
      'This device cannot compress video. Originals are uploaded from it.';

  @override
  String get reef_section_title => 'Ecosystem';

  @override
  String get reef_section_sourcesTooltip => 'Data sources';

  @override
  String get reef_section_loadError =>
      'Could not load ecosystem data right now';

  @override
  String get reef_habitat_title => 'Reef habitat';

  @override
  String get reef_habitat_onReef => 'On a coral reef';

  @override
  String reef_habitat_onReefWithThreat(String threat) {
    return 'On a coral reef, threat level $threat';
  }

  @override
  String get reef_habitat_noReef => 'No mapped coral reef at this location';

  @override
  String get reef_habitat_unavailable =>
      'Could not check reef habitat right now';

  @override
  String get water_conditions_title => 'Water conditions';

  @override
  String get water_conditions_unavailable =>
      'Could not check water conditions right now';

  @override
  String get water_conditions_noData =>
      'No satellite water data for this location';

  @override
  String get water_conditions_freshwater =>
      'Satellite water temperature covers oceans only';

  @override
  String water_conditions_anomaly(String value) {
    return 'Anomaly $value';
  }

  @override
  String reef_health_degreeHeatingWeeks(String value) {
    return 'Degree Heating Weeks $value C-weeks';
  }

  @override
  String reef_health_seaSurface(String value) {
    return 'Sea surface $value';
  }

  @override
  String reef_health_asOf(String date) {
    return 'As of $date';
  }

  @override
  String get reef_health_levelNoStress => 'No thermal stress';

  @override
  String get reef_health_levelWatch => 'Bleaching watch';

  @override
  String get reef_health_levelWarning => 'Bleaching warning';

  @override
  String get reef_health_levelAlert1 => 'Bleaching alert level 1';

  @override
  String get reef_health_levelAlert2 => 'Bleaching alert level 2';

  @override
  String get reef_health_levelAlert3 => 'Bleaching alert level 3';

  @override
  String get reef_health_levelAlert4 => 'Bleaching alert level 4';

  @override
  String get reef_health_levelAlert5 => 'Bleaching alert level 5';

  @override
  String get reef_protection_title => 'Protected area';

  @override
  String get reef_protection_none => 'Not in a marine protected area';

  @override
  String get reef_protection_unavailable =>
      'Could not check protected status right now';

  @override
  String get reef_protection_viewRegulations => 'View regulations';

  @override
  String reef_protection_iucn(String category) {
    return 'IUCN $category';
  }

  @override
  String get reef_species_recordedNearby => 'Recorded nearby';

  @override
  String get reef_species_addToExpected => 'Add to expected species';

  @override
  String reef_species_showAll(int count) {
    return 'Show all $count';
  }

  @override
  String get reef_species_showFewer => 'Show fewer';

  @override
  String get reef_attribution_title => 'Reef data sources';

  @override
  String get reef_attribution_wri =>
      'Reef presence and threat level. CC BY 3.0.';

  @override
  String get reef_attribution_noaa =>
      'Sea surface temperature and bleaching heat stress. Public domain.';

  @override
  String get reef_attribution_gbif =>
      'Species occurrence records, filtered to CC0 and CC BY 4.0.';

  @override
  String get reef_attribution_protectedSeas =>
      'Marine protected area boundaries. CC BY 4.0.';

  @override
  String get enum_visibilityBand_excellent => 'Excellent';

  @override
  String get enum_visibilityBand_good => 'Good';

  @override
  String get enum_visibilityBand_moderate => 'Moderate';

  @override
  String get enum_visibilityBand_poor => 'Poor';

  @override
  String visibility_range_between(String min, String max, String unit) {
    return '$min-$max $unit';
  }

  @override
  String visibility_range_over(String min, String unit) {
    return 'over $min $unit';
  }

  @override
  String visibility_range_under(String max, String unit) {
    return 'under $max $unit';
  }

  @override
  String get settings_coordinateFormat_title => 'Coordinate format';

  @override
  String get settings_coordinateFormat_subtitle =>
      'How GPS positions are shown and entered';

  @override
  String get settings_placeNameLanguage_title => 'Place name language';

  @override
  String get settings_placeNameLanguage_subtitle =>
      'Used when country, region, town and body of water are looked up from coordinates. Existing sites are not changed.';

  @override
  String get settings_coordinateFormat_decimalDegrees => 'Decimal degrees';

  @override
  String get settings_coordinateFormat_degreesDecimalMinutes =>
      'Degrees and decimal minutes';

  @override
  String get settings_coordinateFormat_degreesMinutesSeconds =>
      'Degrees, minutes, seconds';

  @override
  String get settings_coordinateFormat_utm => 'UTM';

  @override
  String get settings_coordinateFormat_mgrs => 'MGRS';

  @override
  String get settings_visibilityScale_title => 'Visibility scale';

  @override
  String get settings_visibilityScale_subtitle =>
      'Which distances count as good visibility where you dive';

  @override
  String get settings_visibilityScale_preset_tropical => 'Tropical';

  @override
  String get settings_visibilityScale_preset_temperate => 'Temperate';

  @override
  String get settings_visibilityScale_preset_coldWater => 'Cold water / Inland';

  @override
  String get settings_visibilityScale_preset_custom => 'Custom';

  @override
  String get settings_visibilityScale_customExcellent =>
      'Excellent at or above';

  @override
  String get settings_visibilityScale_customGood => 'Good at or above';

  @override
  String get settings_visibilityScale_customModerate => 'Moderate at or above';

  @override
  String get settings_visibilityScale_invalidOrder =>
      'Each value must be smaller than the one above it, and greater than zero';

  @override
  String statistics_conditions_visibility_legacySuffix(String band) {
    return '$band (logged before measurement)';
  }

  @override
  String common_selection_countSelected(Object count) {
    return '$count selected';
  }

  @override
  String get common_selection_enterTooltip => 'Select items';

  @override
  String get common_selection_exitTooltip => 'Exit selection';

  @override
  String get common_selection_selectAllTooltip => 'Select all';

  @override
  String get common_selection_deselectAllTooltip => 'Deselect all';

  @override
  String common_bulkDelete_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count items?',
      one: 'Delete $count item?',
    );
    return '$_temp0';
  }

  @override
  String get common_bulkDelete_body => 'This cannot be undone.';

  @override
  String common_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deleted',
      one: '$count deleted',
    );
    return '$_temp0';
  }

  @override
  String get marineLife_species_delete_confirmTitle => 'Delete species?';

  @override
  String marineLife_species_delete_confirmBody(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String marineLife_species_delete_inUseError(String name) {
    return 'Cannot delete \"$name\" - it has sightings';
  }

  @override
  String marineLife_species_delete_snackbar(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String marineLife_species_delete_error(String error) {
    return 'Error deleting species: $error';
  }

  @override
  String get enum_diveField_diveNumber => 'Dive Number';

  @override
  String get enum_diveField_dateTime => 'Date & Time';

  @override
  String get enum_diveField_siteName => 'Site Name';

  @override
  String get enum_diveField_diveName => 'Dive Name';

  @override
  String get enum_diveField_maxDepth => 'Max Depth';

  @override
  String get enum_diveField_avgDepth => 'Average Depth';

  @override
  String get enum_diveField_bottomTime => 'Bottom Time';

  @override
  String get enum_diveField_runtime => 'Runtime';

  @override
  String get enum_diveField_waterTemp => 'Water Temperature';

  @override
  String get enum_diveField_airTemp => 'Air Temperature';

  @override
  String get enum_diveField_visibility => 'Visibility';

  @override
  String get enum_diveField_currentDirection => 'Current Direction';

  @override
  String get enum_diveField_currentStrength => 'Current Strength';

  @override
  String get enum_diveField_swellHeight => 'Swell Height';

  @override
  String get enum_diveField_entryMethod => 'Entry Method';

  @override
  String get enum_diveField_exitMethod => 'Exit Method';

  @override
  String get enum_diveField_waterType => 'Water Type';

  @override
  String get enum_diveField_altitude => 'Altitude';

  @override
  String get enum_diveField_surfacePressure => 'Surface Pressure';

  @override
  String get enum_diveField_windSpeed => 'Wind Speed';

  @override
  String get enum_diveField_cloudCover => 'Cloud Cover';

  @override
  String get enum_diveField_precipitation => 'Precipitation';

  @override
  String get enum_diveField_humidity => 'Humidity';

  @override
  String get enum_diveField_weatherDescription => 'Weather';

  @override
  String get enum_diveField_primaryGas => 'Primary Gas';

  @override
  String get enum_diveField_diluentGas => 'Diluent Gas';

  @override
  String get enum_diveField_tankCount => 'Tank Count';

  @override
  String get enum_diveField_startPressure => 'Start Pressure';

  @override
  String get enum_diveField_endPressure => 'End Pressure';

  @override
  String get enum_diveField_sacRate => 'SAC Rate';

  @override
  String get enum_diveField_gasConsumed => 'Gas Consumed';

  @override
  String get enum_diveField_totalWeight => 'Total Weight';

  @override
  String get enum_diveField_diveComputerModel => 'Dive Computer';

  @override
  String get enum_diveField_gradientFactorLow => 'GF Low';

  @override
  String get enum_diveField_gradientFactorHigh => 'GF High';

  @override
  String get enum_diveField_decoAlgorithm => 'Deco Algorithm';

  @override
  String get enum_diveField_decoConservatism => 'Conservatism';

  @override
  String get enum_diveField_cnsStart => 'CNS Start';

  @override
  String get enum_diveField_cnsEnd => 'CNS End';

  @override
  String get enum_diveField_otu => 'OTU';

  @override
  String get enum_diveField_diveMode => 'Dive Mode';

  @override
  String get enum_diveField_setpointLow => 'Setpoint Low';

  @override
  String get enum_diveField_setpointHigh => 'Setpoint High';

  @override
  String get enum_diveField_setpointDeco => 'Setpoint Deco';

  @override
  String get enum_diveField_buddy => 'Buddy';

  @override
  String get enum_diveField_diveMaster => 'Dive Master';

  @override
  String get enum_diveField_siteLocation => 'Site Location';

  @override
  String get enum_diveField_diveCenterName => 'Dive Center';

  @override
  String get enum_diveField_siteLatitude => 'Latitude';

  @override
  String get enum_diveField_siteLongitude => 'Longitude';

  @override
  String get enum_diveField_tripName => 'Trip';

  @override
  String get enum_diveField_ratingStars => 'Rating';

  @override
  String get enum_diveField_isFavorite => 'Favorite';

  @override
  String get enum_diveField_notes => 'Notes';

  @override
  String get enum_diveField_tags => 'Tags';

  @override
  String get enum_diveField_importSource => 'Import Source';

  @override
  String get enum_diveField_diveTypeName => 'Dive Type';

  @override
  String get enum_diveField_surfaceInterval => 'Surface Interval';

  @override
  String get enum_diveField_diveNumber_short => '#';

  @override
  String get enum_diveField_dateTime_short => 'Date';

  @override
  String get enum_diveField_siteName_short => 'Site';

  @override
  String get enum_diveField_diveName_short => 'Name';

  @override
  String get enum_diveField_maxDepth_short => 'Max D';

  @override
  String get enum_diveField_avgDepth_short => 'Avg D';

  @override
  String get enum_diveField_bottomTime_short => 'BT';

  @override
  String get enum_diveField_runtime_short => 'RT';

  @override
  String get enum_diveField_waterTemp_short => 'W Temp';

  @override
  String get enum_diveField_airTemp_short => 'A Temp';

  @override
  String get enum_diveField_visibility_short => 'Vis';

  @override
  String get enum_diveField_currentDirection_short => 'Curr Dir';

  @override
  String get enum_diveField_currentStrength_short => 'Curr';

  @override
  String get enum_diveField_swellHeight_short => 'Swell';

  @override
  String get enum_diveField_entryMethod_short => 'Entry';

  @override
  String get enum_diveField_exitMethod_short => 'Exit';

  @override
  String get enum_diveField_waterType_short => 'Water';

  @override
  String get enum_diveField_altitude_short => 'Alt';

  @override
  String get enum_diveField_surfacePressure_short => 'S Press';

  @override
  String get enum_diveField_windSpeed_short => 'Wind';

  @override
  String get enum_diveField_cloudCover_short => 'Cloud';

  @override
  String get enum_diveField_precipitation_short => 'Precip';

  @override
  String get enum_diveField_humidity_short => 'Humid';

  @override
  String get enum_diveField_weatherDescription_short => 'Weather';

  @override
  String get enum_diveField_primaryGas_short => 'Gas';

  @override
  String get enum_diveField_diluentGas_short => 'Dil';

  @override
  String get enum_diveField_tankCount_short => 'Tanks';

  @override
  String get enum_diveField_startPressure_short => 'Start P';

  @override
  String get enum_diveField_endPressure_short => 'End P';

  @override
  String get enum_diveField_sacRate_short => 'SAC';

  @override
  String get enum_diveField_gasConsumed_short => 'Gas Used';

  @override
  String get enum_diveField_totalWeight_short => 'Wt';

  @override
  String get enum_diveField_diveComputerModel_short => 'Computer';

  @override
  String get enum_diveField_gradientFactorLow_short => 'GFL';

  @override
  String get enum_diveField_gradientFactorHigh_short => 'GFH';

  @override
  String get enum_diveField_decoAlgorithm_short => 'Algo';

  @override
  String get enum_diveField_decoConservatism_short => 'Conserv';

  @override
  String get enum_diveField_cnsStart_short => 'CNS Start';

  @override
  String get enum_diveField_cnsEnd_short => 'CNS End';

  @override
  String get enum_diveField_otu_short => 'OTU';

  @override
  String get enum_diveField_diveMode_short => 'Mode';

  @override
  String get enum_diveField_setpointLow_short => 'SP Lo';

  @override
  String get enum_diveField_setpointHigh_short => 'SP Hi';

  @override
  String get enum_diveField_setpointDeco_short => 'SP Deco';

  @override
  String get enum_diveField_buddy_short => 'Buddy';

  @override
  String get enum_diveField_diveMaster_short => 'DM';

  @override
  String get enum_diveField_siteLocation_short => 'Location';

  @override
  String get enum_diveField_diveCenterName_short => 'Dive Ctr';

  @override
  String get enum_diveField_siteLatitude_short => 'Lat';

  @override
  String get enum_diveField_siteLongitude_short => 'Lng';

  @override
  String get enum_diveField_tripName_short => 'Trip';

  @override
  String get enum_diveField_ratingStars_short => 'Rating';

  @override
  String get enum_diveField_isFavorite_short => 'Fav';

  @override
  String get enum_diveField_notes_short => 'Notes';

  @override
  String get enum_diveField_tags_short => 'Tags';

  @override
  String get enum_diveField_importSource_short => 'Source';

  @override
  String get enum_diveField_diveTypeName_short => 'Type';

  @override
  String get enum_diveField_surfaceInterval_short => 'SI';

  @override
  String get enum_siteField_siteName => 'Name';

  @override
  String get enum_siteField_location => 'Location';

  @override
  String get enum_siteField_country => 'Country';

  @override
  String get enum_siteField_region => 'Region';

  @override
  String get enum_siteField_city => 'City';

  @override
  String get enum_siteField_island => 'Island';

  @override
  String get enum_siteField_bodyOfWater => 'Body of Water';

  @override
  String get enum_siteField_diveCount => 'Dive Count';

  @override
  String get enum_siteField_maxDepth => 'Max Depth';

  @override
  String get enum_siteField_minDepth => 'Min Depth';

  @override
  String get enum_siteField_altitude => 'Altitude';

  @override
  String get enum_siteField_waterType => 'Water Type';

  @override
  String get enum_siteField_typicalVisibility => 'Typical Visibility';

  @override
  String get enum_siteField_typicalCurrent => 'Typical Current';

  @override
  String get enum_siteField_difficulty => 'Difficulty';

  @override
  String get enum_siteField_entryType => 'Entry Type';

  @override
  String get enum_siteField_bestSeason => 'Best Season';

  @override
  String get enum_siteField_mooringNumber => 'Mooring Number';

  @override
  String get enum_siteField_hazards => 'Hazards';

  @override
  String get enum_siteField_rating => 'Rating';

  @override
  String get enum_siteField_notes => 'Notes';

  @override
  String get enum_siteField_latitude => 'Latitude';

  @override
  String get enum_siteField_longitude => 'Longitude';

  @override
  String get enum_siteField_siteName_short => 'Name';

  @override
  String get enum_siteField_location_short => 'Location';

  @override
  String get enum_siteField_country_short => 'Country';

  @override
  String get enum_siteField_region_short => 'Region';

  @override
  String get enum_siteField_city_short => 'City';

  @override
  String get enum_siteField_island_short => 'Island';

  @override
  String get enum_siteField_bodyOfWater_short => 'Water Body';

  @override
  String get enum_siteField_diveCount_short => 'Dives';

  @override
  String get enum_siteField_maxDepth_short => 'Max D';

  @override
  String get enum_siteField_minDepth_short => 'Min D';

  @override
  String get enum_siteField_altitude_short => 'Alt';

  @override
  String get enum_siteField_waterType_short => 'Water';

  @override
  String get enum_siteField_typicalVisibility_short => 'Vis';

  @override
  String get enum_siteField_typicalCurrent_short => 'Current';

  @override
  String get enum_siteField_difficulty_short => 'Diff';

  @override
  String get enum_siteField_entryType_short => 'Entry';

  @override
  String get enum_siteField_exitMethod => 'Exit Method';

  @override
  String get enum_siteField_exitMethod_short => 'Exit';

  @override
  String get enum_siteField_bestSeason_short => 'Season';

  @override
  String get enum_siteField_mooringNumber_short => 'Mooring';

  @override
  String get enum_siteField_hazards_short => 'Hazards';

  @override
  String get enum_siteField_rating_short => 'Rating';

  @override
  String get enum_siteField_notes_short => 'Notes';

  @override
  String get enum_siteField_latitude_short => 'Lat';

  @override
  String get enum_siteField_longitude_short => 'Lon';

  @override
  String get enum_siteField_depthRange => 'Depth Range';

  @override
  String get enum_siteField_depthRange_short => 'Depth';

  @override
  String get enum_siteField_lastDived => 'Last Dived';

  @override
  String get enum_siteField_lastDived_short => 'Last dived';

  @override
  String get enum_siteField_maxDepthReached => 'Your Max Depth';

  @override
  String get enum_siteField_maxDepthReached_short => 'Your max';

  @override
  String get enum_buddyField_buddyName => 'Name';

  @override
  String get enum_buddyField_email => 'Email';

  @override
  String get enum_buddyField_phone => 'Phone';

  @override
  String get enum_buddyField_certificationLevel => 'Certification Level';

  @override
  String get enum_buddyField_certificationAgency => 'Certification Agency';

  @override
  String get enum_buddyField_diveCount => 'Dive Count';

  @override
  String get enum_buddyField_notes => 'Notes';

  @override
  String get enum_buddyField_buddyName_short => 'Name';

  @override
  String get enum_buddyField_email_short => 'Email';

  @override
  String get enum_buddyField_phone_short => 'Phone';

  @override
  String get enum_buddyField_certificationLevel_short => 'Cert Level';

  @override
  String get enum_buddyField_certificationAgency_short => 'Agency';

  @override
  String get enum_buddyField_diveCount_short => 'Dives';

  @override
  String get enum_buddyField_notes_short => 'Notes';

  @override
  String get enum_buddyField_lastDive => 'Last Dive';

  @override
  String get enum_buddyField_lastDive_short => 'Last dive';

  @override
  String get enum_tripField_tripName => 'Name';

  @override
  String get enum_tripField_startDate => 'Start Date';

  @override
  String get enum_tripField_endDate => 'End Date';

  @override
  String get enum_tripField_durationDays => 'Duration';

  @override
  String get enum_tripField_location => 'Location';

  @override
  String get enum_tripField_tripType => 'Trip Type';

  @override
  String get enum_tripField_resortName => 'Resort';

  @override
  String get enum_tripField_liveaboardName => 'Liveaboard';

  @override
  String get enum_tripField_diveCount => 'Dive Count';

  @override
  String get enum_tripField_totalRuntime => 'Total Runtime';

  @override
  String get enum_tripField_maxDepth => 'Max Depth';

  @override
  String get enum_tripField_avgDepth => 'Avg Depth';

  @override
  String get enum_tripField_notes => 'Notes';

  @override
  String get enum_tripField_tripName_short => 'Name';

  @override
  String get enum_tripField_startDate_short => 'Start';

  @override
  String get enum_tripField_endDate_short => 'End';

  @override
  String get enum_tripField_durationDays_short => 'Days';

  @override
  String get enum_tripField_location_short => 'Location';

  @override
  String get enum_tripField_tripType_short => 'Type';

  @override
  String get enum_tripField_resortName_short => 'Resort';

  @override
  String get enum_tripField_liveaboardName_short => 'Liveaboard';

  @override
  String get enum_tripField_diveCount_short => 'Dives';

  @override
  String get enum_tripField_totalRuntime_short => 'RT Total';

  @override
  String get enum_tripField_maxDepth_short => 'Max D';

  @override
  String get enum_tripField_avgDepth_short => 'Avg D';

  @override
  String get enum_tripField_notes_short => 'Notes';

  @override
  String get enum_equipmentField_itemName => 'Name';

  @override
  String get enum_equipmentField_fullName => 'Full Name';

  @override
  String get enum_equipmentField_type => 'Type';

  @override
  String get enum_equipmentField_brand => 'Brand';

  @override
  String get enum_equipmentField_model => 'Model';

  @override
  String get enum_equipmentField_serialNumber => 'Serial Number';

  @override
  String get enum_equipmentField_size => 'Size';

  @override
  String get enum_equipmentField_status => 'Status';

  @override
  String get enum_equipmentField_isActive => 'Active';

  @override
  String get enum_equipmentField_purchaseDate => 'Purchase Date';

  @override
  String get enum_equipmentField_purchasePrice => 'Purchase Price';

  @override
  String get enum_equipmentField_lastServiceDate => 'Last Service';

  @override
  String get enum_equipmentField_nextServiceDue => 'Next Service Due';

  @override
  String get enum_equipmentField_daysUntilService => 'Days Until Service';

  @override
  String get enum_equipmentField_serviceIntervalDays => 'Service Interval';

  @override
  String get enum_equipmentField_notes => 'Notes';

  @override
  String get enum_equipmentField_itemName_short => 'Name';

  @override
  String get enum_equipmentField_fullName_short => 'Full Name';

  @override
  String get enum_equipmentField_type_short => 'Type';

  @override
  String get enum_equipmentField_brand_short => 'Brand';

  @override
  String get enum_equipmentField_model_short => 'Model';

  @override
  String get enum_equipmentField_serialNumber_short => 'Serial #';

  @override
  String get enum_equipmentField_size_short => 'Size';

  @override
  String get enum_equipmentField_status_short => 'Status';

  @override
  String get enum_equipmentField_isActive_short => 'Active';

  @override
  String get enum_equipmentField_purchaseDate_short => 'Purchased';

  @override
  String get enum_equipmentField_purchasePrice_short => 'Price';

  @override
  String get enum_equipmentField_lastServiceDate_short => 'Serviced';

  @override
  String get enum_equipmentField_nextServiceDue_short => 'Next Svc';

  @override
  String get enum_equipmentField_daysUntilService_short => 'Days Left';

  @override
  String get enum_equipmentField_serviceIntervalDays_short => 'Interval';

  @override
  String get enum_equipmentField_notes_short => 'Notes';

  @override
  String get enum_diveCenterField_centerName => 'Name';

  @override
  String get enum_diveCenterField_city => 'City';

  @override
  String get enum_diveCenterField_country => 'Country';

  @override
  String get enum_diveCenterField_stateProvince => 'State / Province';

  @override
  String get enum_diveCenterField_street => 'Street';

  @override
  String get enum_diveCenterField_postalCode => 'Postal Code';

  @override
  String get enum_diveCenterField_phone => 'Phone';

  @override
  String get enum_diveCenterField_email => 'Email';

  @override
  String get enum_diveCenterField_website => 'Website';

  @override
  String get enum_diveCenterField_affiliations => 'Affiliations';

  @override
  String get enum_diveCenterField_rating => 'Rating';

  @override
  String get enum_diveCenterField_latitude => 'Latitude';

  @override
  String get enum_diveCenterField_longitude => 'Longitude';

  @override
  String get enum_diveCenterField_diveCount => 'Dive Count';

  @override
  String get enum_diveCenterField_notes => 'Notes';

  @override
  String get enum_diveCenterField_centerName_short => 'Name';

  @override
  String get enum_diveCenterField_city_short => 'City';

  @override
  String get enum_diveCenterField_country_short => 'Country';

  @override
  String get enum_diveCenterField_stateProvince_short => 'State';

  @override
  String get enum_diveCenterField_street_short => 'Street';

  @override
  String get enum_diveCenterField_postalCode_short => 'ZIP';

  @override
  String get enum_diveCenterField_phone_short => 'Phone';

  @override
  String get enum_diveCenterField_email_short => 'Email';

  @override
  String get enum_diveCenterField_website_short => 'Website';

  @override
  String get enum_diveCenterField_affiliations_short => 'Affiliations';

  @override
  String get enum_diveCenterField_rating_short => 'Rating';

  @override
  String get enum_diveCenterField_latitude_short => 'Lat';

  @override
  String get enum_diveCenterField_longitude_short => 'Lon';

  @override
  String get enum_diveCenterField_diveCount_short => 'Dives';

  @override
  String get enum_diveCenterField_notes_short => 'Notes';

  @override
  String get enum_certificationField_certName => 'Name';

  @override
  String get enum_certificationField_agency => 'Agency';

  @override
  String get enum_certificationField_level => 'Certification';

  @override
  String get enum_certificationField_cardNumber => 'Card Number';

  @override
  String get enum_certificationField_issueDate => 'Issue Date';

  @override
  String get enum_certificationField_expiryDate => 'Expiry Date';

  @override
  String get enum_certificationField_instructorName => 'Instructor Name';

  @override
  String get enum_certificationField_instructorNumber => 'Instructor Number';

  @override
  String get enum_certificationField_expiryStatus => 'Expiry Status';

  @override
  String get enum_certificationField_notes => 'Notes';

  @override
  String get enum_certificationField_certName_short => 'Name';

  @override
  String get enum_certificationField_agency_short => 'Agency';

  @override
  String get enum_certificationField_level_short => 'Certification';

  @override
  String get enum_certificationField_cardNumber_short => 'Card #';

  @override
  String get enum_certificationField_issueDate_short => 'Issued';

  @override
  String get enum_certificationField_expiryDate_short => 'Expires';

  @override
  String get enum_certificationField_instructorName_short => 'Instructor';

  @override
  String get enum_certificationField_instructorNumber_short => 'Instr. #';

  @override
  String get enum_certificationField_expiryStatus_short => 'Status';

  @override
  String get enum_certificationField_notes_short => 'Notes';

  @override
  String get enum_courseField_courseName => 'Name';

  @override
  String get enum_courseField_agency => 'Agency';

  @override
  String get enum_courseField_startDate => 'Start Date';

  @override
  String get enum_courseField_completionDate => 'Completion Date';

  @override
  String get enum_courseField_durationDays => 'Duration';

  @override
  String get enum_courseField_instructorName => 'Instructor Name';

  @override
  String get enum_courseField_instructorNumber => 'Instructor Number';

  @override
  String get enum_courseField_location => 'Location';

  @override
  String get enum_courseField_isCompleted => 'Completed';

  @override
  String get enum_courseField_notes => 'Notes';

  @override
  String get enum_courseField_courseName_short => 'Name';

  @override
  String get enum_courseField_agency_short => 'Agency';

  @override
  String get enum_courseField_startDate_short => 'Started';

  @override
  String get enum_courseField_completionDate_short => 'Completed';

  @override
  String get enum_courseField_durationDays_short => 'Duration';

  @override
  String get enum_courseField_instructorName_short => 'Instructor';

  @override
  String get enum_courseField_instructorNumber_short => 'Instr. #';

  @override
  String get enum_courseField_location_short => 'Location';

  @override
  String get enum_courseField_isCompleted_short => 'Done';

  @override
  String get enum_courseField_notes_short => 'Notes';

  @override
  String get enum_fieldCategory_accommodation => 'Accommodation';

  @override
  String get enum_fieldCategory_address => 'Address';

  @override
  String get enum_fieldCategory_certification => 'Certification';

  @override
  String get enum_fieldCategory_conditions => 'Conditions';

  @override
  String get enum_fieldCategory_contact => 'Contact';

  @override
  String get enum_fieldCategory_coordinates => 'Coordinates';

  @override
  String get enum_fieldCategory_dates => 'Dates';

  @override
  String get enum_fieldCategory_depth => 'Depth';

  @override
  String get enum_fieldCategory_details => 'Details';

  @override
  String get enum_fieldCategory_instructor => 'Instructor';

  @override
  String get enum_fieldCategory_other => 'Other';

  @override
  String get enum_fieldCategory_purchase => 'Purchase';

  @override
  String get enum_fieldCategory_service => 'Service';

  @override
  String get enum_fieldCategory_statistics => 'Statistics';

  @override
  String get species_whale_shark_name => 'Whale Shark';

  @override
  String get species_whale_shark_desc =>
      'Largest fish in the ocean, gentle filter feeder with distinctive spotted pattern.';

  @override
  String get species_great_white_shark_name => 'Great White Shark';

  @override
  String get species_great_white_shark_desc =>
      'Iconic apex predator occasionally seen by cage divers in temperate waters.';

  @override
  String get species_great_hammerhead_shark_name => 'Great Hammerhead Shark';

  @override
  String get species_great_hammerhead_shark_desc =>
      'Largest hammerhead species with a broad, flat head and tall dorsal fin.';

  @override
  String get species_scalloped_hammerhead_shark_name =>
      'Scalloped Hammerhead Shark';

  @override
  String get species_scalloped_hammerhead_shark_desc =>
      'Often seen in large schools at seamounts and cleaning stations.';

  @override
  String get species_smooth_hammerhead_shark_name => 'Smooth Hammerhead Shark';

  @override
  String get species_smooth_hammerhead_shark_desc =>
      'Hammerhead with a smooth, rounded head margin found in temperate seas.';

  @override
  String get species_whitetip_reef_shark_name => 'Whitetip Reef Shark';

  @override
  String get species_whitetip_reef_shark_desc =>
      'Docile reef dweller often found resting in caves and under ledges during the day.';

  @override
  String get species_blacktip_reef_shark_name => 'Blacktip Reef Shark';

  @override
  String get species_blacktip_reef_shark_desc =>
      'Common shallow-water reef shark with distinctive black-tipped fins.';

  @override
  String get species_grey_reef_shark_name => 'Grey Reef Shark';

  @override
  String get species_grey_reef_shark_desc =>
      'Active reef predator often encountered in groups along drop-offs and channels.';

  @override
  String get species_caribbean_reef_shark_name => 'Caribbean Reef Shark';

  @override
  String get species_caribbean_reef_shark_desc =>
      'Most commonly encountered reef shark in the Caribbean, robust and curious.';

  @override
  String get species_nurse_shark_name => 'Nurse Shark';

  @override
  String get species_nurse_shark_desc =>
      'Slow-moving bottom dweller often found resting under coral ledges.';

  @override
  String get species_tawny_nurse_shark_name => 'Tawny Nurse Shark';

  @override
  String get species_tawny_nurse_shark_desc =>
      'Indo-Pacific bottom dweller found resting in reef caves and sandy areas.';

  @override
  String get species_bull_shark_name => 'Bull Shark';

  @override
  String get species_bull_shark_desc =>
      'Stocky, powerful shark found in coastal and freshwater environments worldwide.';

  @override
  String get species_tiger_shark_name => 'Tiger Shark';

  @override
  String get species_tiger_shark_desc =>
      'Large predator with distinctive striped pattern, encountered on deep reef dives.';

  @override
  String get species_oceanic_whitetip_shark_name => 'Oceanic Whitetip Shark';

  @override
  String get species_oceanic_whitetip_shark_desc =>
      'Pelagic shark with rounded white-tipped fins, seen on open ocean dives.';

  @override
  String get species_thresher_shark_name => 'Thresher Shark';

  @override
  String get species_thresher_shark_desc =>
      'Recognizable by its extremely long tail fin, sometimes seen at cleaning stations.';

  @override
  String get species_pelagic_thresher_shark_name => 'Pelagic Thresher Shark';

  @override
  String get species_pelagic_thresher_shark_desc =>
      'Smallest thresher species, famously seen at Monad Shoal in the Philippines.';

  @override
  String get species_shortfin_mako_shark_name => 'Shortfin Mako Shark';

  @override
  String get species_shortfin_mako_shark_desc =>
      'Fastest shark in the ocean, a sleek open-water predator with metallic blue coloring.';

  @override
  String get species_blue_shark_name => 'Blue Shark';

  @override
  String get species_blue_shark_desc =>
      'Slender, deep blue pelagic shark often encountered on blue-water dives.';

  @override
  String get species_spotted_wobbegong_name => 'Spotted Wobbegong';

  @override
  String get species_spotted_wobbegong_desc =>
      'Flat, camouflaged carpet shark that lies motionless on rocky reefs in Australia.';

  @override
  String get species_tasselled_wobbegong_name => 'Tasselled Wobbegong';

  @override
  String get species_tasselled_wobbegong_desc =>
      'Ornate carpet shark with fringed lobes around its head, found in coral reefs.';

  @override
  String get species_epaulette_shark_name => 'Epaulette Shark';

  @override
  String get species_epaulette_shark_desc =>
      'Small shark that walks along the reef floor using its pectoral fins.';

  @override
  String get species_horn_shark_name => 'Horn Shark';

  @override
  String get species_horn_shark_desc =>
      'Nocturnal bottom dweller with ridges above its eyes, found off California.';

  @override
  String get species_leopard_shark_name => 'Leopard Shark';

  @override
  String get species_leopard_shark_desc =>
      'Beautifully patterned shark found in shallow bays along the US Pacific coast.';

  @override
  String get species_pacific_angel_shark_name => 'Pacific Angel Shark';

  @override
  String get species_pacific_angel_shark_desc =>
      'Flat-bodied ambush predator that lies buried in sand on the seafloor.';

  @override
  String get species_sand_tiger_shark_name => 'Sand Tiger Shark';

  @override
  String get species_sand_tiger_shark_desc =>
      'Fierce-looking but docile shark often seen hovering in caves and shipwrecks.';

  @override
  String get species_zebra_shark_name => 'Zebra Shark';

  @override
  String get species_zebra_shark_desc =>
      'Spotted reef shark that rests on sandy bottoms, common in the Indo-Pacific.';

  @override
  String get species_blacktip_shark_name => 'Blacktip Shark';

  @override
  String get species_blacktip_shark_desc =>
      'Fast coastal shark known for spinning leaps, found in warm waters worldwide.';

  @override
  String get species_silvertip_shark_name => 'Silvertip Shark';

  @override
  String get species_silvertip_shark_desc =>
      'Bold reef shark with white-edged fins, found near deep drop-offs and atolls.';

  @override
  String get species_silky_shark_name => 'Silky Shark';

  @override
  String get species_silky_shark_desc =>
      'Sleek pelagic shark with smooth skin, often found near offshore reefs.';

  @override
  String get species_lemon_shark_name => 'Lemon Shark';

  @override
  String get species_lemon_shark_desc =>
      'Yellowish-brown shark commonly seen in shallow mangroves and sandy flats.';

  @override
  String get species_galapagos_shark_name => 'Galapagos Shark';

  @override
  String get species_galapagos_shark_desc =>
      'Large reef shark found around oceanic islands, inquisitive toward divers.';

  @override
  String get species_port_jackson_shark_name => 'Port Jackson Shark';

  @override
  String get species_port_jackson_shark_desc =>
      'Nocturnal bottom dweller with harness-like markings, endemic to Australia.';

  @override
  String get species_bamboo_shark_name => 'Brownbanded Bamboo Shark';

  @override
  String get species_bamboo_shark_desc =>
      'Small, docile bottom-dwelling shark common on Indo-Pacific coral reefs.';

  @override
  String get species_basking_shark_name => 'Basking Shark';

  @override
  String get species_basking_shark_desc =>
      'Second-largest fish, a filter feeder seen in temperate surface waters.';

  @override
  String get species_greenland_shark_name => 'Greenland Shark';

  @override
  String get species_greenland_shark_desc =>
      'Slow-moving deep-water shark, one of the longest-lived vertebrates on Earth.';

  @override
  String get species_cookiecutter_shark_name => 'Cookiecutter Shark';

  @override
  String get species_cookiecutter_shark_desc =>
      'Small deep-water shark that takes circular bites from larger marine animals.';

  @override
  String get species_sevengill_shark_name => 'Broadnose Sevengill Shark';

  @override
  String get species_sevengill_shark_desc =>
      'Primitive shark with seven gill slits, encountered on temperate kelp dives.';

  @override
  String get species_pyjama_shark_name => 'Pyjama Shark';

  @override
  String get species_pyjama_shark_desc =>
      'Striped catshark endemic to South Africa, found in rocky reefs and kelp forests.';

  @override
  String get species_spiny_dogfish_name => 'Spiny Dogfish';

  @override
  String get species_spiny_dogfish_desc =>
      'Small, abundant shark with venomous dorsal spines, found in temperate waters.';

  @override
  String get species_swell_shark_name => 'Swell Shark';

  @override
  String get species_swell_shark_desc =>
      'Nocturnal catshark that inflates its body when threatened, found off California.';

  @override
  String get species_giant_oceanic_manta_ray_name => 'Giant Oceanic Manta Ray';

  @override
  String get species_giant_oceanic_manta_ray_desc =>
      'Largest ray species, majestic filter feeder with wingspans up to 7 meters.';

  @override
  String get species_reef_manta_ray_name => 'Reef Manta Ray';

  @override
  String get species_reef_manta_ray_desc =>
      'Smaller manta species commonly seen at cleaning stations on tropical reefs.';

  @override
  String get species_spotted_eagle_ray_name => 'Spotted Eagle Ray';

  @override
  String get species_spotted_eagle_ray_desc =>
      'Elegant ray with white spots and a long whip-like tail, often seen mid-water.';

  @override
  String get species_common_eagle_ray_name => 'Common Eagle Ray';

  @override
  String get species_common_eagle_ray_desc =>
      'Diamond-shaped ray found in temperate eastern Atlantic and Mediterranean waters.';

  @override
  String get species_blue_spotted_ribbontail_ray_name =>
      'Blue-spotted Ribbontail Ray';

  @override
  String get species_blue_spotted_ribbontail_ray_desc =>
      'Brightly colored ray with vivid blue spots, common on Indo-Pacific reefs.';

  @override
  String get species_blue_spotted_stingray_name => 'Bluespotted Stingray';

  @override
  String get species_blue_spotted_stingray_desc =>
      'Small reef stingray with scattered blue spots, often buried in sandy patches.';

  @override
  String get species_southern_stingray_name => 'Southern Stingray';

  @override
  String get species_southern_stingray_desc =>
      'Large stingray found on Caribbean sand flats, famous at Stingray City.';

  @override
  String get species_round_stingray_name => 'Round Stingray';

  @override
  String get species_round_stingray_desc =>
      'Small circular stingray common in shallow sandy areas of the eastern Pacific.';

  @override
  String get species_short_tail_stingray_name => 'Short-tail Stingray';

  @override
  String get species_short_tail_stingray_desc =>
      'One of the largest stingrays, found in temperate waters of the southern hemisphere.';

  @override
  String get species_cowtail_stingray_name => 'Cowtail Stingray';

  @override
  String get species_cowtail_stingray_desc =>
      'Large dark stingray with a distinctive flag-like tail fold, found on sandy reefs.';

  @override
  String get species_atlantic_torpedo_ray_name => 'Atlantic Torpedo Ray';

  @override
  String get species_atlantic_torpedo_ray_desc =>
      'Electric ray capable of producing strong shocks, found on Atlantic sandy bottoms.';

  @override
  String get species_marbled_electric_ray_name => 'Marbled Electric Ray';

  @override
  String get species_marbled_electric_ray_desc =>
      'Mediterranean electric ray with marbled pattern, delivers a notable electric shock.';

  @override
  String get species_giant_guitarfish_name => 'Giant Guitarfish';

  @override
  String get species_giant_guitarfish_desc =>
      'Shark-shaped ray found on Indo-Pacific sandy bottoms near coral reefs.';

  @override
  String get species_shovelnose_guitarfish_name => 'Shovelnose Guitarfish';

  @override
  String get species_shovelnose_guitarfish_desc =>
      'Flattened ray-shark hybrid shape, common in sandy shallows of the eastern Pacific.';

  @override
  String get species_smalltooth_sawfish_name => 'Smalltooth Sawfish';

  @override
  String get species_smalltooth_sawfish_desc =>
      'Critically endangered ray with a toothed rostrum, found in tropical coastal waters.';

  @override
  String get species_green_sawfish_name => 'Green Sawfish';

  @override
  String get species_green_sawfish_desc =>
      'Large sawfish with an olive-green body, inhabiting Indo-West Pacific estuaries.';

  @override
  String get species_devil_ray_name => 'Giant Devil Ray';

  @override
  String get species_devil_ray_desc =>
      'Large mobula ray with cephalic fins, seen leaping from the water in groups.';

  @override
  String get species_spinetail_devil_ray_name => 'Spinetail Devil Ray';

  @override
  String get species_spinetail_devil_ray_desc =>
      'Pelagic devil ray often seen in large aggregations near the surface.';

  @override
  String get species_lesser_devil_ray_name => 'Pygmy Devil Ray';

  @override
  String get species_lesser_devil_ray_desc =>
      'Smallest mobula species, forms large schools in the Gulf of California.';

  @override
  String get species_bat_ray_name => 'Bat Ray';

  @override
  String get species_bat_ray_desc =>
      'Diamond-shaped ray common in kelp forests and sandy bays of California.';

  @override
  String get species_undulate_ray_name => 'Undulate Ray';

  @override
  String get species_undulate_ray_desc =>
      'Beautifully patterned skate with wavy lines, found in the eastern Atlantic.';

  @override
  String get species_thornback_ray_name => 'Thornback Ray';

  @override
  String get species_thornback_ray_desc =>
      'Common European skate with thorny spines along its back and tail.';

  @override
  String get species_cownose_ray_name => 'Cownose Ray';

  @override
  String get species_cownose_ray_desc =>
      'Distinctive notched head, often seen in large schools during seasonal migrations.';

  @override
  String get species_marble_ray_name => 'Marble Ray';

  @override
  String get species_marble_ray_desc =>
      'Large dark stingray with white spots, frequently seen at Indo-Pacific cleaning stations.';

  @override
  String get species_ocellate_river_stingray_name => 'Ocellate River Stingray';

  @override
  String get species_ocellate_river_stingray_desc =>
      'Freshwater stingray with striking orange-ringed spots, native to South American rivers.';

  @override
  String get species_ocellaris_clownfish_name => 'Ocellaris Clownfish';

  @override
  String get species_ocellaris_clownfish_desc =>
      'Small orange and white striped fish commonly found living symbiotically in sea anemones on coral reefs.';

  @override
  String get species_clarkii_clownfish_name => 'Clark\'s Clownfish';

  @override
  String get species_clarkii_clownfish_desc =>
      'Hardy anemonefish with dark body and two white bars, found across the Indo-Pacific in various anemone species.';

  @override
  String get species_tomato_clownfish_name => 'Tomato Clownfish';

  @override
  String get species_tomato_clownfish_desc =>
      'Bright red-orange anemonefish with a single white head bar, common on Indo-Pacific reefs.';

  @override
  String get species_regal_blue_tang_name => 'Regal Blue Tang';

  @override
  String get species_regal_blue_tang_desc =>
      'Vivid blue surgeonfish with a black palette marking and yellow tail, found on Indo-Pacific coral reefs.';

  @override
  String get species_yellow_tang_name => 'Yellow Tang';

  @override
  String get species_yellow_tang_desc =>
      'Bright yellow surgeonfish common on Hawaiian and Pacific reefs, often seen grazing algae in groups.';

  @override
  String get species_powder_blue_surgeonfish_name => 'Powder Blue Surgeonfish';

  @override
  String get species_powder_blue_surgeonfish_desc =>
      'Striking pale blue surgeonfish with black face and yellow dorsal fin, found in the Indian Ocean.';

  @override
  String get species_sohal_surgeonfish_name => 'Sohal Surgeonfish';

  @override
  String get species_sohal_surgeonfish_desc =>
      'Bold striped surgeonfish with orange scalpel spine, endemic to the Red Sea and Arabian Gulf reefs.';

  @override
  String get species_blue_tang_name => 'Blue Tang';

  @override
  String get species_blue_tang_desc =>
      'Deep blue surgeonfish common on Caribbean reefs, juveniles are bright yellow.';

  @override
  String get species_emperor_angelfish_name => 'Emperor Angelfish';

  @override
  String get species_emperor_angelfish_desc =>
      'Large angelfish with striking blue and yellow horizontal stripes. Juveniles display concentric blue and white circles.';

  @override
  String get species_french_angelfish_name => 'French Angelfish';

  @override
  String get species_french_angelfish_desc =>
      'Large dark angelfish with golden-edged scales, commonly seen in pairs on Caribbean and western Atlantic reefs.';

  @override
  String get species_queen_angelfish_name => 'Queen Angelfish';

  @override
  String get species_queen_angelfish_desc =>
      'Spectacular blue and yellow angelfish with a distinctive crown spot, found on Caribbean coral reefs.';

  @override
  String get species_regal_angelfish_name => 'Regal Angelfish';

  @override
  String get species_regal_angelfish_desc =>
      'Elegant angelfish with alternating orange-white and blue vertical bands, found on Indo-Pacific reefs.';

  @override
  String get species_rock_beauty_name => 'Rock Beauty';

  @override
  String get species_rock_beauty_desc =>
      'Striking Caribbean angelfish with a yellow front half and black rear half, found near rocky reefs and ledges.';

  @override
  String get species_gray_angelfish_name => 'Gray Angelfish';

  @override
  String get species_gray_angelfish_desc =>
      'Large gray angelfish with pale face and yellow inner pectoral fin, common on Caribbean reefs.';

  @override
  String get species_copperband_butterflyfish_name =>
      'Copperband Butterflyfish';

  @override
  String get species_copperband_butterflyfish_desc =>
      'Distinctive butterflyfish with orange vertical bands and elongated snout, found on Indo-Pacific reefs.';

  @override
  String get species_raccoon_butterflyfish_name => 'Raccoon Butterflyfish';

  @override
  String get species_raccoon_butterflyfish_desc =>
      'Yellow butterflyfish with a dark raccoon-like eye mask, common on Indo-Pacific and Hawaiian reefs.';

  @override
  String get species_longnose_butterflyfish_name => 'Longnose Butterflyfish';

  @override
  String get species_longnose_butterflyfish_desc =>
      'Bright yellow butterflyfish with an extremely long snout used to pick food from crevices on Indo-Pacific reefs.';

  @override
  String get species_threadfin_butterflyfish_name => 'Threadfin Butterflyfish';

  @override
  String get species_threadfin_butterflyfish_desc =>
      'White butterflyfish with chevron pattern and trailing dorsal filament, widespread across the Indo-Pacific.';

  @override
  String get species_foureye_butterflyfish_name => 'Foureye Butterflyfish';

  @override
  String get species_foureye_butterflyfish_desc =>
      'Pale butterflyfish with a prominent false eyespot near the tail, common on Caribbean reefs.';

  @override
  String get species_spotfin_butterflyfish_name => 'Spotfin Butterflyfish';

  @override
  String get species_spotfin_butterflyfish_desc =>
      'White and yellow butterflyfish with a small dark spot on the dorsal fin, found in the western Atlantic.';

  @override
  String get species_banner_butterflyfish_name => 'Red Sea Bannerfish';

  @override
  String get species_banner_butterflyfish_desc =>
      'Black and white bannerfish with an elongated dorsal fin and yellow belly, endemic to the Red Sea.';

  @override
  String get species_moorish_idol_name => 'Moorish Idol';

  @override
  String get species_moorish_idol_desc =>
      'Iconic reef fish with bold black, white, and yellow bands and a long trailing dorsal filament.';

  @override
  String get species_green_moray_eel_name => 'Green Moray Eel';

  @override
  String get species_green_moray_eel_desc =>
      'Large green moray reaching 2.5m, often seen with mouth agape in reef crevices across the western Atlantic.';

  @override
  String get species_giant_moray_eel_name => 'Giant Moray Eel';

  @override
  String get species_giant_moray_eel_desc =>
      'The largest moray species, reaching over 3m, with leopard-like spots. Found on Indo-Pacific coral reefs.';

  @override
  String get species_spotted_moray_eel_name => 'Spotted Moray Eel';

  @override
  String get species_spotted_moray_eel_desc =>
      'White moray with dark brown spots, commonly encountered peering from reef holes in the Caribbean.';

  @override
  String get species_ribbon_eel_name => 'Ribbon Eel';

  @override
  String get species_ribbon_eel_desc =>
      'Slender eel with flared nostrils; males are vivid blue, females are yellow. Found in Indo-Pacific sandy lagoons.';

  @override
  String get species_spotted_garden_eel_name => 'Spotted Garden Eel';

  @override
  String get species_spotted_garden_eel_desc =>
      'Thin white eel with black spots that lives in sandy colonies, swaying in the current to catch plankton.';

  @override
  String get species_splendid_garden_eel_name => 'Splendid Garden Eel';

  @override
  String get species_splendid_garden_eel_desc =>
      'Orange and white banded garden eel found in large sandy colonies in the western Pacific.';

  @override
  String get species_snowflake_moray_name => 'Snowflake Moray Eel';

  @override
  String get species_snowflake_moray_desc =>
      'Small moray with white body and black snowflake-like markings, common in Indo-Pacific reef rubble.';

  @override
  String get species_mandarin_dragonet_name => 'Mandarin Dragonet';

  @override
  String get species_mandarin_dragonet_desc =>
      'Tiny, brilliantly colored fish with psychedelic blue and orange patterns, found in western Pacific rubble zones.';

  @override
  String get species_common_lionfish_name => 'Common Lionfish';

  @override
  String get species_common_lionfish_desc =>
      'Venomous scorpionfish with dramatic fan-like pectoral fins and red-white stripes. Invasive in the Caribbean.';

  @override
  String get species_leaf_scorpionfish_name => 'Leaf Scorpionfish';

  @override
  String get species_leaf_scorpionfish_desc =>
      'Highly compressed, leaf-shaped scorpionfish that sways with the current to mimic debris on Indo-Pacific reefs.';

  @override
  String get species_stonefish_name => 'Reef Stonefish';

  @override
  String get species_stonefish_desc =>
      'World\'s most venomous fish, perfectly camouflaged as a rock on Indo-Pacific reef floors. Extremely dangerous.';

  @override
  String get species_painted_frogfish_name => 'Painted Frogfish';

  @override
  String get species_painted_frogfish_desc =>
      'Chunky ambush predator with a lure on its head, highly variable in color. Found on Indo-Pacific reefs.';

  @override
  String get species_giant_frogfish_name => 'Giant Frogfish';

  @override
  String get species_giant_frogfish_desc =>
      'The largest frogfish species, reaching 40cm, with excellent camouflage in sponges and coral rubble.';

  @override
  String get species_hairy_frogfish_name => 'Hairy Frogfish';

  @override
  String get species_hairy_frogfish_desc =>
      'Frogfish covered in worm-like fleshy appendages that mimic algae, a prized find for underwater photographers.';

  @override
  String get species_clown_triggerfish_name => 'Clown Triggerfish';

  @override
  String get species_clown_triggerfish_desc =>
      'Boldly patterned triggerfish with large white spots on a dark body and yellow lips, found on Indo-Pacific reefs.';

  @override
  String get species_titan_triggerfish_name => 'Titan Triggerfish';

  @override
  String get species_titan_triggerfish_desc =>
      'Large aggressive triggerfish known to charge divers near its nest. Common on Indo-Pacific coral reefs.';

  @override
  String get species_queen_triggerfish_name => 'Queen Triggerfish';

  @override
  String get species_queen_triggerfish_desc =>
      'Colorful Caribbean triggerfish with blue facial markings and long tail streamers.';

  @override
  String get species_picasso_triggerfish_name => 'Picasso Triggerfish';

  @override
  String get species_picasso_triggerfish_desc =>
      'Triggerfish with an abstract pattern of blue, yellow, and black stripes, common on Indo-Pacific reef flats.';

  @override
  String get species_yellowmargin_triggerfish_name =>
      'Yellowmargin Triggerfish';

  @override
  String get species_yellowmargin_triggerfish_desc =>
      'Large tan triggerfish with yellow-edged fins, known for aggressive nest guarding on Indo-Pacific reefs.';

  @override
  String get species_porcupinefish_name => 'Porcupinefish';

  @override
  String get species_porcupinefish_desc =>
      'Large spiny fish that inflates into a ball when threatened, found on tropical reefs worldwide.';

  @override
  String get species_guineafowl_pufferfish_name => 'Guineafowl Pufferfish';

  @override
  String get species_guineafowl_pufferfish_desc =>
      'Dark pufferfish covered in small white spots, sometimes found in a golden-yellow color phase on Indo-Pacific reefs.';

  @override
  String get species_map_pufferfish_name => 'Map Pufferfish';

  @override
  String get species_map_pufferfish_desc =>
      'Large pale pufferfish with intricate dark map-like markings across its body, found on Indo-Pacific reefs.';

  @override
  String get species_sharpnose_pufferfish_name => 'Sharpnose Pufferfish';

  @override
  String get species_sharpnose_pufferfish_desc =>
      'Tiny pufferfish with blue lines on the face and orange tail, commonly seen on Caribbean reefs.';

  @override
  String get species_boxfish_name => 'Yellow Boxfish';

  @override
  String get species_boxfish_desc =>
      'Juveniles are bright yellow cubes with black spots. Adults darken to blue-gray. Found across the Indo-Pacific.';

  @override
  String get species_cowfish_name => 'Longhorn Cowfish';

  @override
  String get species_cowfish_desc =>
      'Boxy yellow fish with distinctive horn-like projections above each eye, found on Indo-Pacific reefs.';

  @override
  String get species_napoleon_wrasse_name => 'Napoleon Wrasse';

  @override
  String get species_napoleon_wrasse_desc =>
      'Massive wrasse reaching 2m with a prominent forehead bump. Endangered and protected, found on Indo-Pacific reefs.';

  @override
  String get species_cleaner_wrasse_name => 'Bluestreak Cleaner Wrasse';

  @override
  String get species_cleaner_wrasse_desc =>
      'Small blue-striped wrasse that operates cleaning stations, removing parasites from larger fish on Indo-Pacific reefs.';

  @override
  String get species_yellowtail_coris_name => 'Yellowtail Coris';

  @override
  String get species_yellowtail_coris_desc =>
      'Colorful wrasse with spotted body and yellow tail, juveniles are bright orange-red with white markings.';

  @override
  String get species_bluehead_wrasse_name => 'Bluehead Wrasse';

  @override
  String get species_bluehead_wrasse_desc =>
      'Abundant Caribbean wrasse; terminal males have a vivid blue head and green body with black-white bars.';

  @override
  String get species_spanish_hogfish_name => 'Spanish Hogfish';

  @override
  String get species_spanish_hogfish_desc =>
      'Purple and yellow wrasse common on Caribbean reefs; juveniles act as cleaner fish.';

  @override
  String get species_bumphead_parrotfish_name => 'Bumphead Parrotfish';

  @override
  String get species_bumphead_parrotfish_desc =>
      'Largest parrotfish species reaching 1.3m, with a massive forehead bump. Travels in schools on Indo-Pacific reefs.';

  @override
  String get species_stoplight_parrotfish_name => 'Stoplight Parrotfish';

  @override
  String get species_stoplight_parrotfish_desc =>
      'Common Caribbean parrotfish with dramatic color changes between initial and terminal phases.';

  @override
  String get species_queen_parrotfish_name => 'Queen Parrotfish';

  @override
  String get species_queen_parrotfish_desc =>
      'Large blue-green parrotfish found on Caribbean reefs, often seen biting coral to feed on algae.';

  @override
  String get species_yellowtail_damselfish_name => 'Yellowtail Damselfish';

  @override
  String get species_yellowtail_damselfish_desc =>
      'Dark blue damselfish with a bright yellow tail, common on Caribbean reef tops and crests.';

  @override
  String get species_sergeant_major_name => 'Sergeant Major';

  @override
  String get species_sergeant_major_desc =>
      'Silver-yellow damselfish with five bold black bars, found in large aggregations on tropical Atlantic reefs.';

  @override
  String get species_three_spot_damselfish_name => 'Threespot Damselfish';

  @override
  String get species_three_spot_damselfish_desc =>
      'Dark brown territorial damselfish that aggressively defends its algae garden on Caribbean reefs.';

  @override
  String get species_chromis_viridis_name => 'Blue-Green Chromis';

  @override
  String get species_chromis_viridis_desc =>
      'Small iridescent green damselfish seen in large schools hovering above branching corals on Indo-Pacific reefs.';

  @override
  String get species_blue_chromis_name => 'Blue Chromis';

  @override
  String get species_blue_chromis_desc =>
      'Brilliant blue planktivorous damselfish found in large midwater aggregations above Caribbean reef walls.';

  @override
  String get species_nassau_grouper_name => 'Nassau Grouper';

  @override
  String get species_nassau_grouper_desc =>
      'Large Caribbean grouper with distinctive dark eye stripe and banded pattern, now endangered due to overfishing.';

  @override
  String get species_giant_grouper_name => 'Giant Grouper';

  @override
  String get species_giant_grouper_desc =>
      'The largest bony reef fish, reaching 2.7m and 400kg. Found in caves and wrecks across the Indo-Pacific.';

  @override
  String get species_coral_grouper_name => 'Coral Grouper';

  @override
  String get species_coral_grouper_desc =>
      'Bright red-orange grouper covered in blue spots, a signature species of Indo-Pacific coral reefs.';

  @override
  String get species_goliath_grouper_name => 'Goliath Grouper';

  @override
  String get species_goliath_grouper_desc =>
      'Massive Atlantic grouper reaching 2.5m, often encountered near wrecks and ledges in Florida and the Caribbean.';

  @override
  String get species_potato_grouper_name => 'Potato Grouper';

  @override
  String get species_potato_grouper_desc =>
      'Large friendly grouper with dark potato-shaped blotches, famous at the Great Barrier Reef\'s Cod Hole.';

  @override
  String get species_peacock_grouper_name => 'Peacock Grouper';

  @override
  String get species_peacock_grouper_desc =>
      'Dark brown grouper with bright blue spots and pale vertical bars at the rear, common on Indo-Pacific reefs.';

  @override
  String get species_yellowfin_tuna_name => 'Yellowfin Tuna';

  @override
  String get species_yellowfin_tuna_desc =>
      'Fast pelagic predator with long yellow dorsal and anal fins, occasionally seen by divers at offshore sites.';

  @override
  String get species_dogtooth_tuna_name => 'Dogtooth Tuna';

  @override
  String get species_dogtooth_tuna_desc =>
      'Powerful reef-associated tuna with prominent teeth, encountered at deep reef drop-offs in the Indo-Pacific.';

  @override
  String get species_great_barracuda_name => 'Great Barracuda';

  @override
  String get species_great_barracuda_desc =>
      'Sleek silver predator up to 1.8m with prominent teeth, often seen hovering motionless near tropical reefs.';

  @override
  String get species_blackfin_barracuda_name => 'Blackfin Barracuda';

  @override
  String get species_blackfin_barracuda_desc =>
      'Indo-Pacific barracuda known for forming massive tornado-like schools at dive sites like Barracuda Point.';

  @override
  String get species_mahi_mahi_name => 'Mahi-Mahi';

  @override
  String get species_mahi_mahi_desc =>
      'Dazzling blue-green and gold pelagic fish with a blunt forehead, occasionally seen at offshore dive sites.';

  @override
  String get species_giant_trevally_name => 'Giant Trevally';

  @override
  String get species_giant_trevally_desc =>
      'Powerful silver predator up to 1.7m, known for hunting on reef channels and drop-offs across the Indo-Pacific.';

  @override
  String get species_bluefin_trevally_name => 'Bluefin Trevally';

  @override
  String get species_bluefin_trevally_desc =>
      'Sleek blue-spotted jack commonly seen patrolling Indo-Pacific reef edges in small hunting groups.';

  @override
  String get species_bigeye_trevally_name => 'Bigeye Trevally';

  @override
  String get species_bigeye_trevally_desc =>
      'Silver jack with large eyes that forms impressive swirling schools near reef walls and cleaning stations.';

  @override
  String get species_bar_jack_name => 'Bar Jack';

  @override
  String get species_bar_jack_desc =>
      'Sleek silver Caribbean jack with a distinctive dark blue stripe along the back and onto the lower tail.';

  @override
  String get species_horse_eye_jack_name => 'Horse-Eye Jack';

  @override
  String get species_horse_eye_jack_desc =>
      'Large-eyed silver jack that forms schools near reefs and wrecks in the Caribbean and western Atlantic.';

  @override
  String get species_yellowtail_snapper_name => 'Yellowtail Snapper';

  @override
  String get species_yellowtail_snapper_desc =>
      'Sleek snapper with a yellow lateral stripe and tail, often seen in midwater schools on Caribbean reefs.';

  @override
  String get species_schoolmaster_snapper_name => 'Schoolmaster Snapper';

  @override
  String get species_schoolmaster_snapper_desc =>
      'Yellow-silver snapper with blue lines under the eye, found in groups under ledges on Caribbean reefs.';

  @override
  String get species_bluestripe_snapper_name => 'Bluestripe Snapper';

  @override
  String get species_bluestripe_snapper_desc =>
      'Bright yellow snapper with four blue horizontal stripes, forming dense schools on Indo-Pacific reefs.';

  @override
  String get species_twinspot_snapper_name => 'Twinspot Snapper';

  @override
  String get species_twinspot_snapper_desc =>
      'Large red snapper found on Indo-Pacific outer reefs, sometimes forming schools on deep walls and channels.';

  @override
  String get species_humphead_snapper_name => 'Midnight Snapper';

  @override
  String get species_humphead_snapper_desc =>
      'Large dark snapper found in schools near steep Indo-Pacific drop-offs, juveniles are boldly black and white.';

  @override
  String get species_longfin_bannerfish_name => 'Longfin Bannerfish';

  @override
  String get species_longfin_bannerfish_desc =>
      'Black and white fish with a long trailing dorsal fin and yellow tail, often seen in pairs on Indo-Pacific reefs.';

  @override
  String get species_batfish_orbicular_name => 'Orbicular Batfish';

  @override
  String get species_batfish_orbicular_desc =>
      'Silver disc-shaped fish with tall fins that approaches divers curiously. Common on Indo-Pacific wrecks and reefs.';

  @override
  String get species_batfish_teira_name => 'Longfin Batfish';

  @override
  String get species_batfish_teira_desc =>
      'Tall-finned batfish with a dark blotch near the pectoral fin, often seen at cleaning stations and wrecks.';

  @override
  String get species_batfish_pinnatus_name => 'Pinnate Batfish';

  @override
  String get species_batfish_pinnatus_desc =>
      'Juveniles are jet black with vivid orange borders resembling a toxic flatworm. Found in the western Pacific.';

  @override
  String get species_banggai_cardinalfish_name => 'Banggai Cardinalfish';

  @override
  String get species_banggai_cardinalfish_desc =>
      'Striking silver and black cardinalfish with elongated fins, endemic to the Banggai Islands of Indonesia.';

  @override
  String get species_pajama_cardinalfish_name => 'Pajama Cardinalfish';

  @override
  String get species_pajama_cardinalfish_desc =>
      'Unusual cardinalfish with yellow face, dark waist band, and spotted rear, found among corals in the Indo-Pacific.';

  @override
  String get species_longnose_hawkfish_name => 'Longnose Hawkfish';

  @override
  String get species_longnose_hawkfish_desc =>
      'Small white fish with red crosshatch pattern and elongated snout, perches on gorgonians and black corals.';

  @override
  String get species_arc_eye_hawkfish_name => 'Arc-Eye Hawkfish';

  @override
  String get species_arc_eye_hawkfish_desc =>
      'Small hawkfish with distinctive orange arc behind the eye, commonly perched on coral heads on Indo-Pacific reefs.';

  @override
  String get species_flame_hawkfish_name => 'Flame Hawkfish';

  @override
  String get species_flame_hawkfish_desc =>
      'Brilliant red hawkfish with dark eye markings, found perching in Pocillopora corals across the western Pacific.';

  @override
  String get species_fire_goby_name => 'Fire Goby';

  @override
  String get species_fire_goby_desc =>
      'Elegant white goby with a tall first dorsal fin and red-orange tail, hovers above Indo-Pacific reef rubble.';

  @override
  String get species_purple_firefish_name => 'Purple Firefish';

  @override
  String get species_purple_firefish_desc =>
      'Delicate goby with purple fins and a tall dorsal spike, found hovering near burrows on Indo-Pacific outer reefs.';

  @override
  String get species_yellownose_goby_name => 'Yellownose Goby';

  @override
  String get species_yellownose_goby_desc =>
      'Tiny Caribbean cleaner goby with a yellow snout and blue lateral stripe, found on sponges and coral heads.';

  @override
  String get species_citron_goby_name => 'Citron Goby';

  @override
  String get species_citron_goby_desc =>
      'Tiny bright yellow goby that lives among the branches of Acropora corals on Indo-Pacific reefs.';

  @override
  String get species_shrimp_goby_name => 'Steinitz\'s Shrimp Goby';

  @override
  String get species_shrimp_goby_desc =>
      'Sandy-colored goby that shares a burrow with alpheid shrimp in a mutualistic relationship on Indo-Pacific sand flats.';

  @override
  String get species_neon_goby_name => 'Neon Goby';

  @override
  String get species_neon_goby_desc =>
      'Tiny dark goby with a brilliant neon blue stripe, operates cleaning stations on Caribbean coral heads.';

  @override
  String get species_bluestriped_fangblenny_name => 'Bluestriped Fangblenny';

  @override
  String get species_bluestriped_fangblenny_desc =>
      'Small blue-striped blenny that mimics cleaner wrasses to bite scales from unsuspecting fish.';

  @override
  String get species_sailfin_blenny_name => 'Sailfin Blenny';

  @override
  String get species_sailfin_blenny_desc =>
      'Tiny Caribbean blenny that raises a large sail-like dorsal fin from its tube home to attract mates.';

  @override
  String get species_bicolor_blenny_name => 'Bicolor Blenny';

  @override
  String get species_bicolor_blenny_desc =>
      'Small blenny with dark brown front half and orange rear half, peers from holes on Indo-Pacific reefs.';

  @override
  String get species_redlip_blenny_name => 'Redlip Blenny';

  @override
  String get species_redlip_blenny_desc =>
      'Dark blenny with prominent red-orange lips that defends algae patches on Caribbean reef crests.';

  @override
  String get species_pygmy_seahorse_name => 'Bargibant\'s Pygmy Seahorse';

  @override
  String get species_pygmy_seahorse_desc =>
      'Tiny seahorse under 2cm that perfectly matches its host gorgonian coral, a prized macro photography subject.';

  @override
  String get species_common_seahorse_name => 'Common Seahorse';

  @override
  String get species_common_seahorse_desc =>
      'Medium-sized seahorse found in seagrass beds and coral rubble across the Indo-Pacific, variable in color.';

  @override
  String get species_thorny_seahorse_name => 'Thorny Seahorse';

  @override
  String get species_thorny_seahorse_desc =>
      'Seahorse covered in long spines found in seagrass beds and soft bottom habitats across the Indo-Pacific.';

  @override
  String get species_ornate_ghost_pipefish_name => 'Ornate Ghost Pipefish';

  @override
  String get species_ornate_ghost_pipefish_desc =>
      'Elaborately camouflaged pipefish that hovers head-down near crinoids and soft corals in the Indo-Pacific.';

  @override
  String get species_robust_ghost_pipefish_name => 'Robust Ghost Pipefish';

  @override
  String get species_robust_ghost_pipefish_desc =>
      'Large ghost pipefish that mimics seagrass or algae, often found in pairs in Indo-Pacific coastal waters.';

  @override
  String get species_trumpetfish_name => 'Trumpetfish';

  @override
  String get species_trumpetfish_desc =>
      'Long slender fish that hunts by shadowing larger fish, found on Caribbean and Atlantic reefs in various colors.';

  @override
  String get species_cornetfish_name => 'Cornetfish';

  @override
  String get species_cornetfish_desc =>
      'Extremely elongated fish up to 1.5m with a trailing tail filament, often seen gliding over reef flats.';

  @override
  String get species_yellowhead_jawfish_name => 'Yellowhead Jawfish';

  @override
  String get species_yellowhead_jawfish_desc =>
      'Small blue-bodied fish with a yellow head that hovers above its sand burrow on Caribbean reefs. Males brood eggs in their mouth.';

  @override
  String get species_flamefish_name => 'Flamefish';

  @override
  String get species_flamefish_desc =>
      'Small bright red cardinalfish with a dark spot below the second dorsal fin, hides in Caribbean reef crevices by day.';

  @override
  String get species_longspine_squirrelfish_name => 'Longspine Squirrelfish';

  @override
  String get species_longspine_squirrelfish_desc =>
      'Red nocturnal fish with large eyes and a long dorsal spine, found under ledges on Caribbean reefs by day.';

  @override
  String get species_soldierfish_name => 'Bigscale Soldierfish';

  @override
  String get species_soldierfish_desc =>
      'Red nocturnal fish with enormous dark eyes and large scales, forms groups in caves and overhangs by day.';

  @override
  String get species_flame_angelfish_name => 'Flame Angelfish';

  @override
  String get species_flame_angelfish_desc =>
      'Brilliant red-orange dwarf angelfish with black vertical bars and blue-tipped fins, found across the Pacific.';

  @override
  String get species_royal_gramma_name => 'Royal Gramma';

  @override
  String get species_royal_gramma_desc =>
      'Small bicolored Caribbean basslet with a purple front half and yellow rear half, found under ledges.';

  @override
  String get species_anthias_lyretail_name => 'Lyretail Anthias';

  @override
  String get species_anthias_lyretail_desc =>
      'Abundant reef fish forming large orange and pink clouds above Indo-Pacific coral formations. Males are purple.';

  @override
  String get species_mediterranean_grouper_name => 'Dusky Grouper';

  @override
  String get species_mediterranean_grouper_desc =>
      'Large dark brown grouper with pale mottling, the iconic predator of Mediterranean rocky reefs.';

  @override
  String get species_mediterranean_moray_name => 'Mediterranean Moray';

  @override
  String get species_mediterranean_moray_desc =>
      'Dark brown moray eel with yellow mottling, commonly seen peering from rocky crevices in the Mediterranean.';

  @override
  String get species_ornate_wrasse_name => 'Ornate Wrasse';

  @override
  String get species_ornate_wrasse_desc =>
      'Colorful green wrasse with red head markings, one of the most common wrasses on Mediterranean reefs.';

  @override
  String get species_red_sea_bannerfish_name => 'Masked Butterflyfish';

  @override
  String get species_red_sea_bannerfish_desc =>
      'Bright yellow butterflyfish with a dark eye patch, endemic to the Red Sea. Often seen in pairs.';

  @override
  String get species_red_sea_anemonefish_name => 'Red Sea Anemonefish';

  @override
  String get species_red_sea_anemonefish_desc =>
      'Orange-yellow anemonefish with two white bars, endemic to the Red Sea and Gulf of Aden.';

  @override
  String get species_arabian_angelfish_name => 'Arabian Angelfish';

  @override
  String get species_arabian_angelfish_desc =>
      'Large dark blue angelfish with a bold yellow vertical bar and tail, endemic to the western Indian Ocean.';

  @override
  String get species_king_angelfish_name => 'King Angelfish';

  @override
  String get species_king_angelfish_desc =>
      'Large dark blue angelfish with a white vertical bar and yellow tail, found in the eastern Pacific and Galapagos.';

  @override
  String get species_ocean_sunfish_name => 'Ocean Sunfish';

  @override
  String get species_ocean_sunfish_desc =>
      'The heaviest bony fish, reaching over 2 tons. Occasionally seen by divers at cleaning stations in Bali and the Galapagos.';

  @override
  String get species_lingcod_name => 'Lingcod';

  @override
  String get species_lingcod_desc =>
      'Large mottled predatory greenling found on rocky reefs of the Pacific Northwest, often guarding egg masses.';

  @override
  String get species_wolf_eel_name => 'Wolf-Eel';

  @override
  String get species_wolf_eel_desc =>
      'Large gray wolf-eel with a bulbous head and powerful jaws, found in rocky dens in the Pacific Northwest.';

  @override
  String get species_giant_sea_bass_name => 'Giant Sea Bass';

  @override
  String get species_giant_sea_bass_desc =>
      'Massive bass reaching over 2m and 250kg, found on rocky reefs and kelp forests off southern California.';

  @override
  String get species_garibaldi_name => 'Garibaldi';

  @override
  String get species_garibaldi_desc =>
      'Bright orange damselfish and California\'s state marine fish, territorial on kelp forest reefs.';

  @override
  String get species_sheephead_name => 'California Sheephead';

  @override
  String get species_sheephead_desc =>
      'Large wrasse with black head and tail, red midsection, and white chin. Found in California kelp forests.';

  @override
  String get species_copper_rockfish_name => 'Copper Rockfish';

  @override
  String get species_copper_rockfish_desc =>
      'Coppery-orange rockfish with pale patches, a common sight on Pacific Northwest rocky reefs and kelp forests.';

  @override
  String get species_oriental_sweetlips_name => 'Oriental Sweetlips';

  @override
  String get species_oriental_sweetlips_desc =>
      'Large Indo-Pacific reef fish with bold black and white stripes and yellow fins. Juveniles perform a wriggling dance.';

  @override
  String get species_harlequin_sweetlips_name => 'Harlequin Sweetlips';

  @override
  String get species_harlequin_sweetlips_desc =>
      'Adults are gray with dark spots; juveniles are brown with large white spots and swim with an undulating motion.';

  @override
  String get species_blue_ringed_angelfish_name => 'Blue-Ringed Angelfish';

  @override
  String get species_blue_ringed_angelfish_desc =>
      'Large brown angelfish with blue curved lines and a distinctive blue ring above the gill cover.';

  @override
  String get species_yellowbar_angelfish_name => 'Yellowbar Angelfish';

  @override
  String get species_yellowbar_angelfish_desc =>
      'Large gray-blue angelfish with a prominent yellow body patch, found in the Red Sea and western Indian Ocean.';

  @override
  String get species_filefish_scrawled_name => 'Scrawled Filefish';

  @override
  String get species_filefish_scrawled_desc =>
      'Large olive-brown filefish with blue scribble-like markings and orange dewlap, found on tropical reefs worldwide.';

  @override
  String get species_clown_filefish_name => 'Orangespotted Filefish';

  @override
  String get species_clown_filefish_desc =>
      'Small green filefish with orange spots and a long snout, feeds exclusively on Acropora coral polyps.';

  @override
  String get species_unicornfish_name => 'Bluespine Unicornfish';

  @override
  String get species_unicornfish_desc =>
      'Gray surgeonfish with a prominent forehead horn and two blue tail spines, common on Indo-Pacific reef flats.';

  @override
  String get species_surgeonfish_sailfin_name => 'Sailfin Tang';

  @override
  String get species_surgeonfish_sailfin_desc =>
      'Boldly banded surgeonfish with a greatly expanded dorsal and anal fin, found across the Indo-Pacific.';

  @override
  String get species_achilles_tang_name => 'Achilles Tang';

  @override
  String get species_achilles_tang_desc =>
      'Dark brown surgeonfish with a bold orange teardrop near the tail, found in surge zones of the central Pacific.';

  @override
  String get species_doctorfish_name => 'Doctorfish';

  @override
  String get species_doctorfish_desc =>
      'Grayish-brown surgeonfish with faint dark bars and a prominent tail scalpel, common on Caribbean reefs.';

  @override
  String get species_checkerboard_wrasse_name => 'Checkerboard Wrasse';

  @override
  String get species_checkerboard_wrasse_desc =>
      'Colorful wrasse with a checkerboard pattern of green, pink, and black squares across the body.';

  @override
  String get species_bird_wrasse_name => 'Bird Wrasse';

  @override
  String get species_bird_wrasse_desc =>
      'Wrasse with an extremely elongated snout resembling a bird\'s beak, males are dark green, females are brown.';

  @override
  String get species_sling_jaw_wrasse_name => 'Sling-Jaw Wrasse';

  @override
  String get species_sling_jaw_wrasse_desc =>
      'Wrasse with an extendable jaw that shoots forward to capture prey, found in yellow or brown color morphs.';

  @override
  String get species_peacock_flounder_name => 'Peacock Flounder';

  @override
  String get species_peacock_flounder_desc =>
      'Flat bottom-dwelling fish with blue rings and spots that can change color to match the seafloor.';

  @override
  String get species_hogfish_name => 'Hogfish';

  @override
  String get species_hogfish_desc =>
      'Large western Atlantic wrasse with a pig-like snout and elongated dorsal spines, found near reefs and wrecks.';

  @override
  String get species_tarpon_name => 'Atlantic Tarpon';

  @override
  String get species_tarpon_desc =>
      'Huge silver fish with large mirror-like scales, sometimes encountered by divers in Caribbean caves and channels.';

  @override
  String get species_permit_name => 'Permit';

  @override
  String get species_permit_desc =>
      'Deep-bodied silver jack with a dark forked tail, found on Caribbean sand flats and near reefs.';

  @override
  String get species_spotted_drum_name => 'Spotted Drum';

  @override
  String get species_spotted_drum_desc =>
      'Striking Caribbean fish with a tall elongated dorsal fin and bold black and white spotted pattern.';

  @override
  String get species_jackknife_fish_name => 'Jackknife Fish';

  @override
  String get species_jackknife_fish_desc =>
      'Elegant Caribbean fish with a tall black dorsal fin stripe and diagonal body band, found under ledges.';

  @override
  String get species_bigeye_name => 'Glasseye';

  @override
  String get species_bigeye_desc =>
      'Bright red nocturnal fish with large reflective eyes, found hiding in caves on Caribbean and Atlantic reefs.';

  @override
  String get species_remora_name => 'Remora';

  @override
  String get species_remora_desc =>
      'Slender fish with a suction disc on its head that hitchhikes on sharks, rays, turtles, and other large animals.';

  @override
  String get species_tilefish_sand_name => 'Sand Tilefish';

  @override
  String get species_tilefish_sand_desc =>
      'Elongated pale blue fish that builds rubble mounds over sandy areas on Caribbean reefs.';

  @override
  String get species_weedy_seadragon_name => 'Weedy Seadragon';

  @override
  String get species_weedy_seadragon_desc =>
      'Ornate relative of seahorses with leaf-like appendages, endemic to temperate southern Australian waters.';

  @override
  String get species_leafy_seadragon_name => 'Leafy Seadragon';

  @override
  String get species_leafy_seadragon_desc =>
      'Spectacular seadragon covered in elaborate leaf-like projections, endemic to southern Australia. A bucket-list dive sighting.';

  @override
  String get species_sailfin_snapper_name => 'Sailfin Snapper';

  @override
  String get species_sailfin_snapper_desc =>
      'Elegant yellow and blue snapper with elongated dorsal and anal fins, found on Indo-Pacific reef slopes.';

  @override
  String get species_sweetlip_emperor_name => 'Spangled Emperor';

  @override
  String get species_sweetlip_emperor_desc =>
      'Large silvery emperor with blue lines on the face and yellow fin edges, common over Indo-Pacific sandy reef areas.';

  @override
  String get species_crocodilefish_name => 'Crocodilefish';

  @override
  String get species_crocodilefish_desc =>
      'Flat-headed ambush predator with elaborate eye fringes, lies perfectly camouflaged on Indo-Pacific reef floors.';

  @override
  String get species_devil_scorpionfish_name => 'Devil Scorpionfish';

  @override
  String get species_devil_scorpionfish_desc =>
      'Stout camouflaged scorpionfish with colorful inner pectoral fins flashed as a warning to predators.';

  @override
  String get species_spiny_devilfish_name => 'Demon Stinger';

  @override
  String get species_spiny_devilfish_desc =>
      'Venomous bottom-dweller that walks on modified fin rays and flashes bright pectoral fins when disturbed.';

  @override
  String get species_waspfish_name => 'Cockatoo Waspfish';

  @override
  String get species_waspfish_desc =>
      'Small compressed scorpionfish that sways like a dead leaf in the current on Indo-Pacific muddy bottoms.';

  @override
  String get species_stargazer_name => 'Whitemargin Stargazer';

  @override
  String get species_stargazer_desc =>
      'Ambush predator that buries in sand with only eyes exposed, can deliver electric shocks. Found in the Indo-Pacific.';

  @override
  String get species_striped_catfish_name => 'Striped Catfish';

  @override
  String get species_striped_catfish_desc =>
      'Venomous-spined catfish; juveniles form dense ball-shaped schools that roll across Indo-Pacific reef floors.';

  @override
  String get species_red_emperor_name => 'Red Emperor';

  @override
  String get species_red_emperor_desc =>
      'Large snapper; adults are pinkish-red, juveniles have bold red and white bands. Found on Indo-Pacific reefs.';

  @override
  String get species_mangrove_snapper_name => 'Mangrove Snapper';

  @override
  String get species_mangrove_snapper_desc =>
      'Gray snapper found in Caribbean mangroves, seagrass, and reefs, often aggregating near structure.';

  @override
  String get species_dottyback_orchid_name => 'Orchid Dottyback';

  @override
  String get species_dottyback_orchid_desc =>
      'Small vivid purple fish endemic to the Red Sea, darting in and out of crevices on steep reef walls.';

  @override
  String get species_dottyback_royal_name => 'Royal Dottyback';

  @override
  String get species_dottyback_royal_desc =>
      'Small bicolored fish with a magenta front and bright yellow rear, found on Indo-Pacific reef walls.';

  @override
  String get species_coral_trout_name => 'Coral Trout';

  @override
  String get species_coral_trout_desc =>
      'Prized Great Barrier Reef predator with an orange-red body covered in blue spots.';

  @override
  String get species_barramundi_cod_name => 'Barramundi Cod';

  @override
  String get species_barramundi_cod_desc =>
      'Distinctive grouper with a small head, humped body, and dark polka dots on a pale background.';

  @override
  String get species_spadefish_atlantic_name => 'Atlantic Spadefish';

  @override
  String get species_spadefish_atlantic_desc =>
      'Silver disc-shaped fish with dark vertical bars, often seen in large schools around Caribbean wrecks.';

  @override
  String get species_fusilier_yellowback_name => 'Yellowback Fusilier';

  @override
  String get species_fusilier_yellowback_desc =>
      'Sleek blue planktivorous fish with a yellow back, forming massive schools above Indo-Pacific reef slopes.';

  @override
  String get species_fusilier_bluestreak_name => 'Bluestreak Fusilier';

  @override
  String get species_fusilier_bluestreak_desc =>
      'Small blue fusilier with a dark lateral stripe, seen in fast-moving schools along Indo-Pacific reef walls.';

  @override
  String get species_porkfish_name => 'Porkfish';

  @override
  String get species_porkfish_desc =>
      'Colorful Caribbean grunt with blue and yellow stripes and two black head bars, found near reefs and wrecks.';

  @override
  String get species_blue_striped_grunt_name => 'Blue-Striped Grunt';

  @override
  String get species_blue_striped_grunt_desc =>
      'Yellow Caribbean grunt with vivid blue horizontal stripes, forms large resting schools under ledges by day.';

  @override
  String get species_french_grunt_name => 'French Grunt';

  @override
  String get species_french_grunt_desc =>
      'Small yellow-striped grunt that forms dense resting schools on Caribbean reefs during daylight hours.';

  @override
  String get species_convict_tang_name => 'Convict Tang';

  @override
  String get species_convict_tang_desc =>
      'Pale surgeonfish with six vertical black bars, often seen grazing in large schools on Indo-Pacific reef flats.';

  @override
  String get species_great_hammerhead_name => 'Scalloped Hammerhead';

  @override
  String get species_great_hammerhead_desc =>
      'Distinctive shark with a scalloped hammer-shaped head, forms large schools at seamounts and offshore islands.';

  @override
  String get species_wobbegong_name => 'Spotted Wobbegong';

  @override
  String get species_wobbegong_desc =>
      'Flat, well-camouflaged carpet shark with fringed lobes around the mouth, found on Australian temperate reefs.';

  @override
  String get species_manta_ray_name => 'Reef Manta Ray';

  @override
  String get species_manta_ray_desc =>
      'Graceful giant reaching 5m wingspan that visits cleaning stations and feeds on plankton at Indo-Pacific reefs.';

  @override
  String get species_oceanic_manta_name => 'Oceanic Manta Ray';

  @override
  String get species_oceanic_manta_desc =>
      'The largest ray species with wingspans exceeding 7m, encountered at offshore seamounts and cleaning stations.';

  @override
  String get species_undulated_moray_name => 'Undulated Moray Eel';

  @override
  String get species_undulated_moray_desc =>
      'Yellowish-green moray with dark wavy markings, commonly seen hunting on Indo-Pacific reefs at night.';

  @override
  String get species_whitemouth_moray_name => 'Whitemouth Moray Eel';

  @override
  String get species_whitemouth_moray_desc =>
      'Dark brown moray with small white spots and a distinctive white mouth interior, found across the Indo-Pacific.';

  @override
  String get species_dragon_moray_name => 'Dragon Moray Eel';

  @override
  String get species_dragon_moray_desc =>
      'Striking moray with dragon-like horns above its nostrils and orange-red leopard spots, found in the Indo-Pacific.';

  @override
  String get species_lyretail_grouper_name => 'Lyretail Grouper';

  @override
  String get species_lyretail_grouper_desc =>
      'Red-pink grouper with blue spots and a distinctive crescent-shaped tail, found on Indo-Pacific outer reef walls.';

  @override
  String get species_banded_butterflyfish_name => 'Banded Butterflyfish';

  @override
  String get species_banded_butterflyfish_desc =>
      'White butterflyfish with four bold black vertical bands, one of the most common butterflies on Caribbean reefs.';

  @override
  String get species_ringed_pipefish_name => 'Ringed Pipefish';

  @override
  String get species_ringed_pipefish_desc =>
      'Slender pipefish with alternating red and white rings, found in caves and under ledges on Indo-Pacific reefs.';

  @override
  String get species_razorfish_name => 'Razorfish';

  @override
  String get species_razorfish_desc =>
      'Tiny fish that swims vertically head-down in groups, often hiding among sea urchin spines on Indo-Pacific reefs.';

  @override
  String get species_harlequin_tuskfish_name => 'Harlequin Tuskfish';

  @override
  String get species_harlequin_tuskfish_desc =>
      'Colorful wrasse with bright blue tusks, red-orange bars, and white patches, found on western Pacific reefs.';

  @override
  String get species_blue_groper_name => 'Blue Groper';

  @override
  String get species_blue_groper_desc =>
      'Large blue wrasse endemic to eastern Australia, friendly and often approaches divers on temperate reefs.';

  @override
  String get species_red_lipped_batfish_name => 'Red-Lipped Batfish';

  @override
  String get species_red_lipped_batfish_desc =>
      'Bizarre flat-bodied fish with bright red lips that walks on modified fins on the Galapagos seafloor.';

  @override
  String get species_orangeband_surgeonfish_name => 'Orangeband Surgeonfish';

  @override
  String get species_orangeband_surgeonfish_desc =>
      'Gray-brown surgeonfish with an orange horizontal band behind the eye, found on Pacific reef slopes.';

  @override
  String get species_maori_wrasse_name => 'Maori Wrasse';

  @override
  String get species_maori_wrasse_desc =>
      'Medium-sized wrasse with a dark band behind the pectoral fin, common on Pacific and Indian Ocean reefs.';

  @override
  String get species_blue_ringed_octopus_name => 'Blue-ringed Octopus';

  @override
  String get species_blue_ringed_octopus_desc =>
      'Small but extremely venomous octopus with bright blue rings that flash when threatened.';

  @override
  String get species_common_octopus_name => 'Common Octopus';

  @override
  String get species_common_octopus_desc =>
      'Highly intelligent octopus known for rapid color changes and problem-solving abilities.';

  @override
  String get species_giant_pacific_octopus_name => 'Giant Pacific Octopus';

  @override
  String get species_giant_pacific_octopus_desc =>
      'The largest octopus species, with arm spans reaching over 4 meters in cold Pacific waters.';

  @override
  String get species_mimic_octopus_name => 'Mimic Octopus';

  @override
  String get species_mimic_octopus_desc =>
      'Remarkable octopus that imitates the appearance and behavior of other marine species.';

  @override
  String get species_coconut_octopus_name => 'Coconut Octopus';

  @override
  String get species_coconut_octopus_desc =>
      'Small octopus famous for carrying coconut shells and using them as portable shelters.';

  @override
  String get species_day_octopus_name => 'Day Octopus';

  @override
  String get species_day_octopus_desc =>
      'Active daytime hunter common on Indo-Pacific reefs with impressive camouflage abilities.';

  @override
  String get species_wonderpus_octopus_name => 'Wonderpus Octopus';

  @override
  String get species_wonderpus_octopus_desc =>
      'Striking octopus with unique white and brown banding found on sandy muck dive sites.';

  @override
  String get species_broadclub_cuttlefish_name => 'Broadclub Cuttlefish';

  @override
  String get species_broadclub_cuttlefish_desc =>
      'Large cuttlefish with mesmerizing color displays, commonly seen on Indo-Pacific reefs.';

  @override
  String get species_pharaoh_cuttlefish_name => 'Pharaoh Cuttlefish';

  @override
  String get species_pharaoh_cuttlefish_desc =>
      'Large cuttlefish found across the Indian Ocean, known for pulsating color patterns.';

  @override
  String get species_flamboyant_cuttlefish_name => 'Flamboyant Cuttlefish';

  @override
  String get species_flamboyant_cuttlefish_desc =>
      'Tiny cuttlefish that walks on the seafloor displaying vivid purple, pink, and yellow pulses.';

  @override
  String get species_giant_cuttlefish_name => 'Giant Cuttlefish';

  @override
  String get species_giant_cuttlefish_desc =>
      'The world\'s largest cuttlefish, famous for mass spawning aggregations in South Australia.';

  @override
  String get species_bigfin_reef_squid_name => 'Bigfin Reef Squid';

  @override
  String get species_bigfin_reef_squid_desc =>
      'Schooling squid frequently encountered on night dives, attracted to dive lights.';

  @override
  String get species_caribbean_reef_squid_name => 'Caribbean Reef Squid';

  @override
  String get species_caribbean_reef_squid_desc =>
      'Curious squid often hovering in small groups near reef edges in the Caribbean.';

  @override
  String get species_bobtail_squid_name => 'Bobtail Squid';

  @override
  String get species_bobtail_squid_desc =>
      'Tiny nocturnal squid that buries in sand by day, a prized muck diving find.';

  @override
  String get species_chambered_nautilus_name => 'Chambered Nautilus';

  @override
  String get species_chambered_nautilus_desc =>
      'Ancient living fossil with a coiled shell, rarely seen by divers in deep water at dawn.';

  @override
  String get species_spanish_dancer_name => 'Spanish Dancer';

  @override
  String get species_spanish_dancer_desc =>
      'Largest nudibranch species that swims with undulating red mantle resembling a flamenco dancer.';

  @override
  String get species_chromodoris_willani_name => 'Willan\'s Chromodoris';

  @override
  String get species_chromodoris_willani_desc =>
      'Striking blue and black nudibranch with white margin, common in the Indo-Pacific.';

  @override
  String get species_chromodoris_lochi_name => 'Loch\'s Chromodoris';

  @override
  String get species_chromodoris_lochi_desc =>
      'Blue nudibranch with dark lines and white border found throughout the tropical Pacific.';

  @override
  String get species_chromodoris_magnifica_name => 'Magnificent Chromodoris';

  @override
  String get species_chromodoris_magnifica_desc =>
      'Brilliant blue, white, and orange nudibranch found on Indo-Pacific coral reefs.';

  @override
  String get species_chromodoris_annae_name => 'Anna\'s Chromodoris';

  @override
  String get species_chromodoris_annae_desc =>
      'Deep blue nudibranch with black lines and orange-tipped rhinophores and gills.';

  @override
  String get species_nembrotha_kubaryana_name => 'Variable Neon Slug';

  @override
  String get species_nembrotha_kubaryana_desc =>
      'Dark green nudibranch with vivid orange or red markings, feeds on tunicates.';

  @override
  String get species_nembrotha_cristata_name => 'Crested Nembrotha';

  @override
  String get species_nembrotha_cristata_desc =>
      'Black nudibranch with bright green pustules and striping found on Indo-Pacific reefs.';

  @override
  String get species_phyllidia_varicosa_name => 'Varicose Phyllidia';

  @override
  String get species_phyllidia_varicosa_desc =>
      'Blue-grey nudibranch with raised yellow-tipped tubercles, toxic to predators.';

  @override
  String get species_phyllidia_ocellata_name => 'Ocellated Phyllidia';

  @override
  String get species_phyllidia_ocellata_desc =>
      'White nudibranch with raised pink-ringed tubercles found on tropical reefs.';

  @override
  String get species_pikachu_nudibranch_name => 'Pikachu Nudibranch';

  @override
  String get species_pikachu_nudibranch_desc =>
      'Tiny yellow and black sea slug resembling a cartoon character, found in the Pacific.';

  @override
  String get species_anna_rosefieldi_name => 'Roboastra Nudibranch';

  @override
  String get species_anna_rosefieldi_desc =>
      'Predatory nudibranch with dark body and bright longitudinal stripes that hunts other slugs.';

  @override
  String get species_lettuce_sea_slug_name => 'Lettuce Sea Slug';

  @override
  String get species_lettuce_sea_slug_desc =>
      'Ruffled green sea slug that retains chloroplasts from algae for photosynthesis.';

  @override
  String get species_blue_dragon_nudibranch_name => 'Blue Dragon Nudibranch';

  @override
  String get species_blue_dragon_nudibranch_desc =>
      'Long aeolid nudibranch with blue-tipped cerata that harbors symbiotic zooxanthellae.';

  @override
  String get species_gloomy_nudibranch_name => 'Gloomy Nudibranch';

  @override
  String get species_gloomy_nudibranch_desc =>
      'Dark blue-green nudibranch with blue-edged ridges common on Indo-Pacific reefs.';

  @override
  String get species_ocellined_nudibranch_name => 'Ocellined Nudibranch';

  @override
  String get species_ocellined_nudibranch_desc =>
      'White nudibranch with orange-lined ridges forming geometric patterns on its mantle.';

  @override
  String get species_glossodoris_cincta_name => 'Glossodoris Nudibranch';

  @override
  String get species_glossodoris_cincta_desc =>
      'Cream-colored nudibranch with dark brown border and orange margin on the mantle.';

  @override
  String get species_jorunna_funebris_name => 'Dotted Nudibranch';

  @override
  String get species_jorunna_funebris_desc =>
      'White nudibranch covered in black-tipped caryophyllidia, resembling a fuzzy bunny.';

  @override
  String get species_ceratosoma_trilobatum_name => 'Trilobate Nudibranch';

  @override
  String get species_ceratosoma_trilobatum_desc =>
      'Large nudibranch with tall dorsal horn and lateral lobes in purple and yellow hues.';

  @override
  String get species_hypselodoris_apolegma_name => 'Purple Hypselodoris';

  @override
  String get species_hypselodoris_apolegma_desc =>
      'Elegant purple nudibranch with white mantle border found on Indo-Pacific reefs.';

  @override
  String get species_hypselodoris_bullockii_name => 'Bullock\'s Hypselodoris';

  @override
  String get species_hypselodoris_bullockii_desc =>
      'Pink and purple nudibranch with yellow-tipped rhinophores on Indo-Pacific reefs.';

  @override
  String get species_flabellina_exoptata_name => 'Desirable Flabellina';

  @override
  String get species_flabellina_exoptata_desc =>
      'Translucent aeolid nudibranch with purple-tipped orange cerata found in tropical waters.';

  @override
  String get species_risbecia_tryoni_name => 'Tryon\'s Risbecia';

  @override
  String get species_risbecia_tryoni_desc =>
      'Large brown and blue nudibranch often found in mating pairs on Indo-Pacific reefs.';

  @override
  String get species_goniobranchus_kuniei_name => 'Kunie\'s Nudibranch';

  @override
  String get species_goniobranchus_kuniei_desc =>
      'Orange-spotted white nudibranch with purple mantle margin found in the western Pacific.';

  @override
  String get species_mexichromis_multituberculata_name =>
      'Multi-tuberculated Nudibranch';

  @override
  String get species_mexichromis_multituberculata_desc =>
      'Purple and white nudibranch with raised tubercles and orange-tipped appendages.';

  @override
  String get species_chromodoris_dianae_name => 'Diana\'s Chromodoris';

  @override
  String get species_chromodoris_dianae_desc =>
      'Bright blue nudibranch with black stripes and orange gills found in the western Pacific.';

  @override
  String get species_phyllodesmium_poindimiei_name =>
      'Solar-powered Nudibranch';

  @override
  String get species_phyllodesmium_poindimiei_desc =>
      'Translucent aeolid nudibranch with branching cerata that harbors zooxanthellae.';

  @override
  String get species_chromodoris_elisabethina_name =>
      'Elizabeth\'s Chromodoris';

  @override
  String get species_chromodoris_elisabethina_desc =>
      'Blue and yellow-lined nudibranch with a white mantle border, common in Southeast Asia.';

  @override
  String get species_doridella_batava_name => 'Batavian Dorid';

  @override
  String get species_doridella_batava_desc =>
      'Variable black to brown dorid nudibranch found under rocks and rubble on Indo-Pacific reefs.';

  @override
  String get species_tiger_cowrie_name => 'Tiger Cowrie';

  @override
  String get species_tiger_cowrie_desc =>
      'Large spotted cowrie shell found on tropical reefs, often partially covered by its mantle.';

  @override
  String get species_tritons_trumpet_name => 'Triton\'s Trumpet';

  @override
  String get species_tritons_trumpet_desc =>
      'Large predatory snail and natural enemy of the crown-of-thorns starfish.';

  @override
  String get species_queen_conch_name => 'Queen Conch';

  @override
  String get species_queen_conch_desc =>
      'Iconic large conch of Caribbean seagrass beds with a distinctive pink inner lip.';

  @override
  String get species_banded_coral_shrimp_name => 'Banded Coral Shrimp';

  @override
  String get species_banded_coral_shrimp_desc =>
      'Red and white banded cleaner shrimp with long white antennae found in reef crevices.';

  @override
  String get species_mantis_shrimp_name => 'Peacock Mantis Shrimp';

  @override
  String get species_mantis_shrimp_desc =>
      'Colorful predator with powerful club-like appendages that can smash through shells.';

  @override
  String get species_cleaner_shrimp_name => 'Scarlet Cleaner Shrimp';

  @override
  String get species_cleaner_shrimp_desc =>
      'Bright red and white shrimp that sets up cleaning stations to service reef fish.';

  @override
  String get species_pederson_cleaner_shrimp_name => 'Pederson Cleaner Shrimp';

  @override
  String get species_pederson_cleaner_shrimp_desc =>
      'Translucent Caribbean cleaner shrimp living among anemone tentacles.';

  @override
  String get species_harlequin_shrimp_name => 'Harlequin Shrimp';

  @override
  String get species_harlequin_shrimp_desc =>
      'Strikingly patterned shrimp with flat claws that feeds exclusively on sea stars.';

  @override
  String get species_coleman_shrimp_name => 'Coleman Shrimp';

  @override
  String get species_coleman_shrimp_desc =>
      'Tiny paired shrimp living on fire urchins, highly prized by underwater photographers.';

  @override
  String get species_emperor_shrimp_name => 'Emperor Shrimp';

  @override
  String get species_emperor_shrimp_desc =>
      'Colorful commensal shrimp that rides on sea cucumbers and nudibranchs.';

  @override
  String get species_sexy_shrimp_name => 'Sexy Shrimp';

  @override
  String get species_sexy_shrimp_desc =>
      'Tiny anemone shrimp known for its tail-waving dance, popular in macro photography.';

  @override
  String get species_marble_shrimp_name => 'Marble Shrimp';

  @override
  String get species_marble_shrimp_desc =>
      'Nocturnal mottled shrimp with feathery legs found hiding in reef crevices by day.';

  @override
  String get species_spiny_lobster_name => 'Caribbean Spiny Lobster';

  @override
  String get species_spiny_lobster_desc =>
      'Large clawless lobster with long antennae found sheltering under reef ledges.';

  @override
  String get species_painted_spiny_lobster_name => 'Painted Spiny Lobster';

  @override
  String get species_painted_spiny_lobster_desc =>
      'Vibrantly colored lobster with blue, green, and white striped legs on Indo-Pacific reefs.';

  @override
  String get species_slipper_lobster_name => 'Slipper Lobster';

  @override
  String get species_slipper_lobster_desc =>
      'Flat-bodied nocturnal lobster with wide antennae plates instead of long whips.';

  @override
  String get species_squat_lobster_name => 'Squat Lobster';

  @override
  String get species_squat_lobster_desc =>
      'Tiny pink-purple crustacean living on giant barrel sponges, a macro photography favorite.';

  @override
  String get species_hermit_crab_name => 'Blue-legged Hermit Crab';

  @override
  String get species_hermit_crab_desc =>
      'Small hermit crab with bright blue legs commonly seen on Caribbean reefs.';

  @override
  String get species_orangutan_crab_name => 'Orangutan Crab';

  @override
  String get species_orangutan_crab_desc =>
      'Tiny hairy crab living in bubble coral, named for its resemblance to an orangutan.';

  @override
  String get species_decorator_crab_name => 'Decorator Crab';

  @override
  String get species_decorator_crab_desc =>
      'Master of disguise that attaches sponges, algae, and hydroids to its carapace.';

  @override
  String get species_porcelain_crab_name => 'Porcelain Anemone Crab';

  @override
  String get species_porcelain_crab_desc =>
      'Flat spotted crab living in anemones, filter-feeding with feathery mouthparts.';

  @override
  String get species_arrow_crab_name => 'Arrow Crab';

  @override
  String get species_arrow_crab_desc =>
      'Spindly Caribbean crab with long pointed rostrum and striped legs.';

  @override
  String get species_channel_clinging_crab_name => 'Channel Clinging Crab';

  @override
  String get species_channel_clinging_crab_desc =>
      'Large Caribbean reef crab with dark body and red-orange claws found in crevices.';

  @override
  String get species_coral_crab_name => 'Coral Guard Crab';

  @override
  String get species_coral_crab_desc =>
      'Small spotted crab living symbiotically in Pocillopora corals, defending its host.';

  @override
  String get species_crown_of_thorns_starfish_name =>
      'Crown-of-thorns Starfish';

  @override
  String get species_crown_of_thorns_starfish_desc =>
      'Venomous multi-armed starfish that feeds on coral and can devastate reefs in outbreaks.';

  @override
  String get species_blue_linckia_starfish_name => 'Blue Linckia Starfish';

  @override
  String get species_blue_linckia_starfish_desc =>
      'Vivid blue sea star commonly seen on Indo-Pacific reef flats and slopes.';

  @override
  String get species_red_knob_starfish_name => 'Red Knob Starfish';

  @override
  String get species_red_knob_starfish_desc =>
      'Large grey starfish with prominent red-tipped spines found on sandy reef areas.';

  @override
  String get species_chocolate_chip_starfish_name => 'Chocolate Chip Starfish';

  @override
  String get species_chocolate_chip_starfish_desc =>
      'Tan starfish with dark raised nodules resembling chocolate chips on sandy substrates.';

  @override
  String get species_cushion_star_name => 'Cushion Star';

  @override
  String get species_cushion_star_desc =>
      'Puffy pentagonal starfish with reduced arms found on Indo-Pacific reef flats.';

  @override
  String get species_fromia_starfish_name => 'Elegant Starfish';

  @override
  String get species_fromia_starfish_desc =>
      'Small orange-red starfish with pale plate margins creating a tiled pattern.';

  @override
  String get species_basket_star_name => 'Basket Star';

  @override
  String get species_basket_star_desc =>
      'Elaborately branched arms unfurl at night to filter-feed in the current.';

  @override
  String get species_brittle_star_name => 'Banded Brittle Star';

  @override
  String get species_brittle_star_desc =>
      'Striped brittle star found under rocks and in crevices with agile, snake-like arms.';

  @override
  String get species_feather_star_name => 'Feather Star';

  @override
  String get species_feather_star_desc =>
      'Multi-armed crinoid perched on reef prominences, filter-feeding with feathery arms.';

  @override
  String get species_black_feather_star_name => 'Black Feather Star';

  @override
  String get species_black_feather_star_desc =>
      'Dark crinoid that can swim briefly by rhythmically waving its many arms.';

  @override
  String get species_long_spined_sea_urchin_name => 'Long-spined Sea Urchin';

  @override
  String get species_long_spined_sea_urchin_desc =>
      'Black urchin with long venomous spines, a critical reef grazer in the Caribbean.';

  @override
  String get species_fire_urchin_name => 'Fire Urchin';

  @override
  String get species_fire_urchin_desc =>
      'Soft-bodied urchin with venomous spines that cause painful stings on contact.';

  @override
  String get species_pencil_urchin_name => 'Pencil Urchin';

  @override
  String get species_pencil_urchin_desc =>
      'Robust urchin with thick blunt spines found wedged into reef crevices.';

  @override
  String get species_collector_urchin_name => 'Collector Urchin';

  @override
  String get species_collector_urchin_desc =>
      'Urchin that covers itself with debris and algae fragments for camouflage.';

  @override
  String get species_sea_apple_name => 'Sea Apple';

  @override
  String get species_sea_apple_desc =>
      'Brightly colored sea cucumber with oral tentacles used for filter feeding.';

  @override
  String get species_pineapple_sea_cucumber_name => 'Pineapple Sea Cucumber';

  @override
  String get species_pineapple_sea_cucumber_desc =>
      'Large orange-red sea cucumber with star-shaped papillae found on reef slopes.';

  @override
  String get species_black_sea_cucumber_name => 'Black Sea Cucumber';

  @override
  String get species_black_sea_cucumber_desc =>
      'Common black sea cucumber found on sandy reef flats throughout the Indo-Pacific.';

  @override
  String get species_leopard_sea_cucumber_name => 'Leopard Sea Cucumber';

  @override
  String get species_leopard_sea_cucumber_desc =>
      'Spotted sea cucumber that ejects sticky white Cuvierian tubules when disturbed.';

  @override
  String get species_sand_dollar_name => 'Sand Dollar';

  @override
  String get species_sand_dollar_desc =>
      'Flat disc-shaped urchin found partially buried in sandy substrates.';

  @override
  String get species_moon_jellyfish_name => 'Moon Jellyfish';

  @override
  String get species_moon_jellyfish_desc =>
      'Translucent bell-shaped jellyfish with four horseshoe-shaped gonads visible through its body.';

  @override
  String get species_lions_mane_jellyfish_name => 'Lion\'s Mane Jellyfish';

  @override
  String get species_lions_mane_jellyfish_desc =>
      'One of the largest jellyfish species with long trailing tentacles in cold waters.';

  @override
  String get species_box_jellyfish_name => 'Box Jellyfish';

  @override
  String get species_box_jellyfish_desc =>
      'Extremely dangerous jellyfish with potent venom found in Indo-Pacific tropical waters.';

  @override
  String get species_upside_down_jellyfish_name => 'Upside-down Jellyfish';

  @override
  String get species_upside_down_jellyfish_desc =>
      'Unusual jellyfish that rests bell-down on sandy bottoms to photosynthesize algae.';

  @override
  String get species_blue_blubber_jellyfish_name => 'Blue Blubber Jellyfish';

  @override
  String get species_blue_blubber_jellyfish_desc =>
      'Blue-white jellyfish with a firm bell and frilly oral arms common in Australian waters.';

  @override
  String get species_fried_egg_jellyfish_name => 'Fried Egg Jellyfish';

  @override
  String get species_fried_egg_jellyfish_desc =>
      'Mediterranean jellyfish with a yellow dome resembling a fried egg and mild sting.';

  @override
  String get species_pacific_sea_nettle_name => 'Pacific Sea Nettle';

  @override
  String get species_pacific_sea_nettle_desc =>
      'Golden-brown jellyfish with long trailing tentacles found along the Pacific coast.';

  @override
  String get species_compass_jellyfish_name => 'Compass Jellyfish';

  @override
  String get species_compass_jellyfish_desc =>
      'Brown and white jellyfish with V-shaped markings radiating like a compass rose.';

  @override
  String get species_spotted_jellyfish_name => 'Spotted Jellyfish';

  @override
  String get species_spotted_jellyfish_desc =>
      'White-spotted golden jellyfish famous for filling Palau\'s Jellyfish Lake.';

  @override
  String get species_barrel_jellyfish_name => 'Barrel Jellyfish';

  @override
  String get species_barrel_jellyfish_desc =>
      'Large dome-shaped jellyfish with frilly oral arms and a mild sting, common in the Atlantic.';

  @override
  String get species_persian_carpet_flatworm_name => 'Persian Carpet Flatworm';

  @override
  String get species_persian_carpet_flatworm_desc =>
      'Ornate black flatworm with yellow-orange margins often mistaken for a nudibranch.';

  @override
  String get species_leopard_flatworm_name => 'Leopard Flatworm';

  @override
  String get species_leopard_flatworm_desc =>
      'Translucent flatworm with leopard-like spots gliding across reef substrates.';

  @override
  String get species_divided_flatworm_name => 'Divided Flatworm';

  @override
  String get species_divided_flatworm_desc =>
      'Striking black and orange flatworm that mimics toxic nudibranchs for protection.';

  @override
  String get species_blue_pseudoceros_flatworm_name =>
      'Blue Pseudoceros Flatworm';

  @override
  String get species_blue_pseudoceros_flatworm_desc =>
      'Deep blue flatworm with orange margin found gliding over Indo-Pacific reef surfaces.';

  @override
  String get species_racing_stripe_flatworm_name => 'Racing Stripe Flatworm';

  @override
  String get species_racing_stripe_flatworm_desc =>
      'Cream-colored flatworm with a distinct dark central stripe and ruffled margin.';

  @override
  String get species_christmas_tree_worm_name => 'Christmas Tree Worm';

  @override
  String get species_christmas_tree_worm_desc =>
      'Colorful spiral-crowned worm embedded in coral that retracts instantly when approached.';

  @override
  String get species_feather_duster_worm_name => 'Feather Duster Worm';

  @override
  String get species_feather_duster_worm_desc =>
      'Tube-dwelling worm with a fan-shaped crown of feathery radioles for filter feeding.';

  @override
  String get species_fire_worm_name => 'Bearded Fire Worm';

  @override
  String get species_fire_worm_desc =>
      'Bristle worm with white stinging chaetae that cause painful irritation on contact.';

  @override
  String get species_bobbit_worm_name => 'Bobbit Worm';

  @override
  String get species_bobbit_worm_desc =>
      'Ambush predator hiding in sand with powerful jaws that strike at lightning speed.';

  @override
  String get species_social_feather_duster_name => 'Social Feather Duster';

  @override
  String get species_social_feather_duster_desc =>
      'Colonial tube worm forming clusters of delicate banded crowns on Caribbean reefs.';

  @override
  String get species_giant_clam_name => 'Giant Clam';

  @override
  String get species_giant_clam_desc =>
      'The largest living bivalve, with iridescent mantle tissue harboring symbiotic algae.';

  @override
  String get species_boring_clam_name => 'Boring Clam';

  @override
  String get species_boring_clam_desc =>
      'Small colorful clam that bores into coral rock showing only its vivid mantle.';

  @override
  String get species_maxima_clam_name => 'Maxima Clam';

  @override
  String get species_maxima_clam_desc =>
      'Brilliantly colored clam embedded in reef rock with electric blue and green mantles.';

  @override
  String get species_flame_scallop_name => 'Flame Scallop';

  @override
  String get species_flame_scallop_desc =>
      'Red bivalve with flashing white light along its mantle edge found in reef crevices.';

  @override
  String get species_thorny_oyster_name => 'Thorny Oyster';

  @override
  String get species_thorny_oyster_desc =>
      'Spiny-shelled bivalve cemented to reef rock, often encrusted with sponges and algae.';

  @override
  String get species_magnificent_sea_anemone_name => 'Magnificent Sea Anemone';

  @override
  String get species_magnificent_sea_anemone_desc =>
      'Large colorful anemone hosting clownfish, with a prominent column and flowing tentacles.';

  @override
  String get species_bubble_tip_anemone_name => 'Bubble Tip Anemone';

  @override
  String get species_bubble_tip_anemone_desc =>
      'Popular clownfish host with bulbous-tipped tentacles in green, brown, or rose colors.';

  @override
  String get species_giant_carpet_anemone_name => 'Giant Carpet Anemone';

  @override
  String get species_giant_carpet_anemone_desc =>
      'Massive anemone with short sticky tentacles that can reach over one meter across.';

  @override
  String get species_haddon_carpet_anemone_name => 'Haddon\'s Carpet Anemone';

  @override
  String get species_haddon_carpet_anemone_desc =>
      'Flat carpet anemone on sandy substrates hosting various clownfish and porcelain crabs.';

  @override
  String get species_long_tentacle_anemone_name => 'Long Tentacle Anemone';

  @override
  String get species_long_tentacle_anemone_desc =>
      'Sandy-bottom anemone with long flowing tentacles, often hosting clownfish.';

  @override
  String get species_tube_anemone_name => 'Tube Anemone';

  @override
  String get species_tube_anemone_desc =>
      'Elegant anemone dwelling in a parchment tube in sand with two rings of tentacles.';

  @override
  String get species_hell_fire_anemone_name => 'Hell\'s Fire Anemone';

  @override
  String get species_hell_fire_anemone_desc =>
      'Highly stinging anemone with branched tentacles resembling soft coral.';

  @override
  String get species_beaded_sea_anemone_name => 'Beaded Sea Anemone';

  @override
  String get species_beaded_sea_anemone_desc =>
      'Anemone with swollen bead-like tentacle tips found on sandy Indo-Pacific reef areas.';

  @override
  String get species_condylactis_anemone_name => 'Giant Caribbean Anemone';

  @override
  String get species_condylactis_anemone_desc =>
      'Large Caribbean anemone with purple-tipped tentacles found on rocky reef substrates.';

  @override
  String get species_sand_anemone_name => 'Sand Anemone';

  @override
  String get species_sand_anemone_desc =>
      'Delicate anemone partially buried in sand with purple-tipped tentacles.';

  @override
  String get species_barrel_sponge_name => 'Giant Barrel Sponge';

  @override
  String get species_barrel_sponge_desc =>
      'Massive barrel-shaped sponge that can live for centuries on Caribbean reef walls.';

  @override
  String get species_azure_vase_sponge_name => 'Azure Vase Sponge';

  @override
  String get species_azure_vase_sponge_desc =>
      'Vibrant blue-purple vase-shaped sponge found on Caribbean reef walls.';

  @override
  String get species_yellow_tube_sponge_name => 'Yellow Tube Sponge';

  @override
  String get species_yellow_tube_sponge_desc =>
      'Bright yellow tubular sponge growing in clusters on Caribbean reef walls.';

  @override
  String get species_elephant_ear_sponge_name => 'Elephant Ear Sponge';

  @override
  String get species_elephant_ear_sponge_desc =>
      'Large orange fan-shaped sponge growing on walls and overhangs in the Caribbean.';

  @override
  String get species_rope_sponge_name => 'Rope Sponge';

  @override
  String get species_rope_sponge_desc =>
      'Red erect branching sponge growing in rope-like formations on Caribbean reefs.';

  @override
  String get species_portuguese_man_o_war_name => 'Portuguese Man o\' War';

  @override
  String get species_portuguese_man_o_war_desc =>
      'Colonial hydrozoan with a gas-filled float and extremely painful trailing tentacles.';

  @override
  String get species_fire_coral_name => 'Fire Coral';

  @override
  String get species_fire_coral_desc =>
      'Not a true coral but a hydrozoan that delivers painful stings to divers on contact.';

  @override
  String get species_by_the_wind_sailor_name => 'By-the-wind Sailor';

  @override
  String get species_by_the_wind_sailor_desc =>
      'Blue floating hydrozoan colony with a diagonal sail that catches the wind.';

  @override
  String get species_blue_button_name => 'Blue Button';

  @override
  String get species_blue_button_desc =>
      'Floating colonial hydrozoan with a flat disc and blue tentacle-like hydroids.';

  @override
  String get species_giant_sea_hare_name => 'Giant Sea Hare';

  @override
  String get species_giant_sea_hare_desc =>
      'One of the largest sea slugs, dark brown to black, found in kelp beds.';

  @override
  String get species_sea_hare_name => 'Spotted Sea Hare';

  @override
  String get species_sea_hare_desc =>
      'Large green-spotted sea hare that releases purple ink when disturbed.';

  @override
  String get species_nudibranch_berghia_name => 'Berghia Nudibranch';

  @override
  String get species_nudibranch_berghia_desc =>
      'Translucent aeolid nudibranch with white-tipped cerata that feeds on anemones.';

  @override
  String get species_sea_pen_name => 'Sea Pen';

  @override
  String get species_sea_pen_desc =>
      'Feather-shaped colonial octocoral anchored in sand that retracts when disturbed.';

  @override
  String get species_blue_sea_star_name => 'Blue Sea Star';

  @override
  String get species_blue_sea_star_desc =>
      'Multi-colored sea star that regenerates from single arm fragments on Indo-Pacific reefs.';

  @override
  String get species_reef_squid_name => 'Reef Squid';

  @override
  String get species_reef_squid_desc =>
      'Southern reef squid commonly encountered in temperate Australian waters.';

  @override
  String get species_tiger_shrimp_name => 'Tiger Shrimp';

  @override
  String get species_tiger_shrimp_desc =>
      'Large banded shrimp found on sandy bottoms and seagrass beds in the Indo-Pacific.';

  @override
  String get species_candy_crab_name => 'Candy Crab';

  @override
  String get species_candy_crab_desc =>
      'Tiny colorful crab matching its soft coral host with pink or yellow spiny projections.';

  @override
  String get species_spider_crab_name => 'Spider Decorator Crab';

  @override
  String get species_spider_crab_desc =>
      'Slow-moving crab covered in attached sponges and algae for camouflage.';

  @override
  String get species_anemone_shrimp_name => 'Magnificent Anemone Shrimp';

  @override
  String get species_anemone_shrimp_desc =>
      'Transparent shrimp with white and purple markings living among anemone tentacles.';

  @override
  String get species_snapping_shrimp_name => 'Snapping Shrimp';

  @override
  String get species_snapping_shrimp_desc =>
      'Small shrimp producing a loud snap with its oversized claw, often paired with gobies.';

  @override
  String get species_glass_sponge_name => 'Venus Flower Basket';

  @override
  String get species_glass_sponge_desc =>
      'Delicate glass sponge with an intricate silica skeleton found in deep water.';

  @override
  String get species_toxic_sea_urchin_name => 'Flower Urchin';

  @override
  String get species_toxic_sea_urchin_desc =>
      'Deceptively attractive urchin covered in flower-like pedicellariae with potent venom.';

  @override
  String get species_slate_pencil_urchin_name => 'Slate Pencil Urchin';

  @override
  String get species_slate_pencil_urchin_desc =>
      'Urchin with thick rounded spines found on Caribbean and Atlantic reef substrates.';

  @override
  String get species_spiny_sea_star_name => 'Spiny Sea Star';

  @override
  String get species_spiny_sea_star_desc =>
      'Large temperate sea star with prominent spines found in European and Atlantic waters.';

  @override
  String get species_bat_star_name => 'Bat Star';

  @override
  String get species_bat_star_desc =>
      'Webbed-armed Pacific sea star in orange, red, or purple found in kelp forests.';

  @override
  String get species_sunflower_star_name => 'Sunflower Star';

  @override
  String get species_sunflower_star_desc =>
      'Massive fast-moving sea star with up to 24 arms found in Pacific kelp forests.';

  @override
  String get species_blood_star_name => 'Blood Star';

  @override
  String get species_blood_star_desc =>
      'Bright red-orange slender-armed sea star found in Pacific temperate waters.';

  @override
  String get species_common_cuttlefish_name => 'Common Cuttlefish';

  @override
  String get species_common_cuttlefish_desc =>
      'Master of camouflage found in European and Mediterranean waters with W-shaped pupils.';

  @override
  String get species_blue_spotted_crab_name => 'Blue-spotted Swimming Crab';

  @override
  String get species_blue_spotted_crab_desc =>
      'Active swimming crab with blue spots on carapace found on sandy Indo-Pacific substrates.';

  @override
  String get species_sponge_crab_name => 'Sponge Crab';

  @override
  String get species_sponge_crab_desc =>
      'Crab that carves and carries a living sponge on its back for camouflage.';

  @override
  String get species_horseshoe_crab_name => 'Horseshoe Crab';

  @override
  String get species_horseshoe_crab_desc =>
      'Ancient chelicerate arthropod with a helmet-shaped shell found on Atlantic sandy bottoms.';

  @override
  String get species_sea_spider_name => 'Sea Spider';

  @override
  String get species_sea_spider_desc =>
      'Delicate long-legged marine arthropod found crawling on hydroids and bryozoans.';

  @override
  String get species_sea_lily_name => 'Sea Lily';

  @override
  String get species_sea_lily_desc =>
      'Stalked crinoid living fossil found in deeper waters, filter feeding with feathery arms.';

  @override
  String get species_mantis_shrimp_lysiosquilla_name => 'Spearer Mantis Shrimp';

  @override
  String get species_mantis_shrimp_lysiosquilla_desc =>
      'Large burrowing mantis shrimp with spearing appendages found on sandy substrates.';

  @override
  String get species_purple_sea_urchin_name => 'Purple Sea Urchin';

  @override
  String get species_purple_sea_urchin_desc =>
      'Abundant purple urchin found in Pacific kelp forests and rocky tidepools.';

  @override
  String get species_crown_jellyfish_name => 'Crown Jellyfish';

  @override
  String get species_crown_jellyfish_desc =>
      'Deep purple jellyfish with a raised crown-like bell found in the Indo-Pacific.';

  @override
  String get species_comb_jelly_name => 'Sea Gooseberry';

  @override
  String get species_comb_jelly_desc =>
      'Small bioluminescent ctenophore with iridescent comb rows and two long tentacles.';

  @override
  String get species_warty_sea_slug_name => 'Warty Sea Slug';

  @override
  String get species_warty_sea_slug_desc =>
      'Blue and black nudibranch with yellow-capped tubercles commonly seen on Indo-Pacific reefs.';

  @override
  String get species_doris_nudibranch_name => 'Sea Lemon';

  @override
  String get species_doris_nudibranch_desc =>
      'Yellow spotted dorid nudibranch found in temperate Pacific waters feeding on sponges.';

  @override
  String get species_opalescent_nudibranch_name => 'Opalescent Nudibranch';

  @override
  String get species_opalescent_nudibranch_desc =>
      'Translucent aeolid with bright orange cerata and blue dorsal lines in Pacific waters.';

  @override
  String get species_clown_nudibranch_name => 'Clown Nudibranch';

  @override
  String get species_clown_nudibranch_desc =>
      'Pink-orange nudibranch with blue and white spots found in temperate Australian waters.';

  @override
  String get species_bottlenose_dolphin_name => 'Bottlenose Dolphin';

  @override
  String get species_bottlenose_dolphin_desc =>
      'Curious and playful dolphin frequently encountered by divers in tropical and temperate waters.';

  @override
  String get species_spinner_dolphin_name => 'Spinner Dolphin';

  @override
  String get species_spinner_dolphin_desc =>
      'Acrobatic dolphin known for aerial spins, often seen in large pods near coral reefs.';

  @override
  String get species_common_dolphin_name => 'Common Dolphin';

  @override
  String get species_common_dolphin_desc =>
      'Fast-swimming dolphin with distinctive hourglass pattern, found in open ocean and coastal waters.';

  @override
  String get species_spotted_dolphin_name => 'Atlantic Spotted Dolphin';

  @override
  String get species_spotted_dolphin_desc =>
      'Friendly spotted dolphin that frequently approaches divers in the Bahamas and Caribbean.';

  @override
  String get species_rissos_dolphin_name => 'Risso\'s Dolphin';

  @override
  String get species_rissos_dolphin_desc =>
      'Large dolphin with heavily scarred grey body, found in deep offshore waters worldwide.';

  @override
  String get species_humpback_whale_name => 'Humpback Whale';

  @override
  String get species_humpback_whale_desc =>
      'Majestic whale known for breaching and complex songs, seen on seasonal migrations.';

  @override
  String get species_grey_whale_name => 'Grey Whale';

  @override
  String get species_grey_whale_desc =>
      'Bottom-feeding baleen whale that migrates along the Pacific coast, often barnacle-covered.';

  @override
  String get species_blue_whale_name => 'Blue Whale';

  @override
  String get species_blue_whale_desc =>
      'The largest animal ever to live, occasionally encountered by divers in deep blue water.';

  @override
  String get species_sperm_whale_name => 'Sperm Whale';

  @override
  String get species_sperm_whale_desc =>
      'Deep-diving whale with massive head, sometimes seen resting at the surface between dives.';

  @override
  String get species_orca_name => 'Orca';

  @override
  String get species_orca_desc =>
      'Apex predator with distinctive black and white markings, found in all ocean basins.';

  @override
  String get species_minke_whale_name => 'Minke Whale';

  @override
  String get species_minke_whale_desc =>
      'Smaller baleen whale that is curious around divers, especially in the Great Barrier Reef.';

  @override
  String get species_beluga_whale_name => 'Beluga Whale';

  @override
  String get species_beluga_whale_desc =>
      'White arctic whale known for its vocalizations and sociable behavior in cold waters.';

  @override
  String get species_pilot_whale_name => 'Short-finned Pilot Whale';

  @override
  String get species_pilot_whale_desc =>
      'Social deep-diving whale often seen in large pods in tropical and warm temperate seas.';

  @override
  String get species_false_killer_whale_name => 'False Killer Whale';

  @override
  String get species_false_killer_whale_desc =>
      'Large oceanic dolphin that occasionally approaches divers in open water.';

  @override
  String get species_dugong_name => 'Dugong';

  @override
  String get species_dugong_desc =>
      'Gentle herbivore that grazes on seagrass beds in the Indo-Pacific, closely related to manatees.';

  @override
  String get species_west_indian_manatee_name => 'West Indian Manatee';

  @override
  String get species_west_indian_manatee_desc =>
      'Slow-moving herbivore found in warm shallow waters, estuaries, and springs of the Caribbean.';

  @override
  String get species_sea_otter_name => 'Sea Otter';

  @override
  String get species_sea_otter_desc =>
      'Charismatic marine mammal found in kelp forests along the North Pacific coast.';

  @override
  String get species_california_sea_lion_name => 'California Sea Lion';

  @override
  String get species_california_sea_lion_desc =>
      'Playful and agile pinniped that often interacts with divers along the Pacific coast.';

  @override
  String get species_steller_sea_lion_name => 'Steller Sea Lion';

  @override
  String get species_steller_sea_lion_desc =>
      'Largest sea lion species, found in cold North Pacific waters near rocky coastlines.';

  @override
  String get species_harbor_seal_name => 'Harbor Seal';

  @override
  String get species_harbor_seal_desc =>
      'Curious seal commonly seen in temperate coastal waters, often resting on rocks near dive sites.';

  @override
  String get species_grey_seal_name => 'Grey Seal';

  @override
  String get species_grey_seal_desc =>
      'Large playful seal found in the North Atlantic, known for approaching divers underwater.';

  @override
  String get species_northern_elephant_seal_name => 'Northern Elephant Seal';

  @override
  String get species_northern_elephant_seal_desc =>
      'Massive deep-diving seal, males have a large proboscis. Found along the eastern Pacific coast.';

  @override
  String get species_hawaiian_monk_seal_name => 'Hawaiian Monk Seal';

  @override
  String get species_hawaiian_monk_seal_desc =>
      'Critically endangered seal endemic to Hawaii, occasionally seen by divers on reefs.';

  @override
  String get species_leopard_seal_name => 'Leopard Seal';

  @override
  String get species_leopard_seal_desc =>
      'Powerful Antarctic predator with spotted coat, encountered by cold-water divers.';

  @override
  String get species_narwhal_name => 'Narwhal';

  @override
  String get species_narwhal_desc =>
      'Arctic whale with a long spiral tusk, rarely seen but iconic among marine mammals.';

  @override
  String get species_green_sea_turtle_name => 'Green Sea Turtle';

  @override
  String get species_green_sea_turtle_desc =>
      'Large sea turtle commonly seen grazing on seagrass in tropical waters.';

  @override
  String get species_hawksbill_sea_turtle_name => 'Hawksbill Sea Turtle';

  @override
  String get species_hawksbill_sea_turtle_desc =>
      'Reef-dwelling turtle with a pointed beak, feeds on sponges among coral formations.';

  @override
  String get species_loggerhead_sea_turtle_name => 'Loggerhead Sea Turtle';

  @override
  String get species_loggerhead_sea_turtle_desc =>
      'Large-headed turtle found in temperate and tropical seas, often near rocky reefs.';

  @override
  String get species_leatherback_sea_turtle_name => 'Leatherback Sea Turtle';

  @override
  String get species_leatherback_sea_turtle_desc =>
      'Largest living turtle with a flexible leathery shell, dives to extreme depths.';

  @override
  String get species_olive_ridley_sea_turtle_name => 'Olive Ridley Sea Turtle';

  @override
  String get species_olive_ridley_sea_turtle_desc =>
      'Smallest sea turtle species known for synchronized mass nesting events called arribadas.';

  @override
  String get species_kemps_ridley_sea_turtle_name =>
      'Kemp\'s Ridley Sea Turtle';

  @override
  String get species_kemps_ridley_sea_turtle_desc =>
      'Critically endangered sea turtle found primarily in the Gulf of Mexico.';

  @override
  String get species_flatback_sea_turtle_name => 'Flatback Sea Turtle';

  @override
  String get species_flatback_sea_turtle_desc =>
      'Endemic to Australian waters, distinguished by its flat carapace and coastal habitat.';

  @override
  String get species_brain_coral_name => 'Brain Coral';

  @override
  String get species_brain_coral_desc =>
      'Massive reef-building coral with grooved surface resembling a brain, common on Caribbean reefs.';

  @override
  String get species_staghorn_coral_name => 'Staghorn Coral';

  @override
  String get species_staghorn_coral_desc =>
      'Fast-growing branching coral that forms dense thickets, critical habitat for reef fish.';

  @override
  String get species_elkhorn_coral_name => 'Elkhorn Coral';

  @override
  String get species_elkhorn_coral_desc =>
      'Large branching coral with flat palmate branches, a key reef builder in the Caribbean.';

  @override
  String get species_table_coral_name => 'Table Coral';

  @override
  String get species_table_coral_desc =>
      'Flat plate-forming coral found on Indo-Pacific reefs, provides shelter for many fish species.';

  @override
  String get species_mushroom_coral_name => 'Mushroom Coral';

  @override
  String get species_mushroom_coral_desc =>
      'Free-living solitary coral shaped like a disc, found on sandy areas near Indo-Pacific reefs.';

  @override
  String get species_bubble_coral_name => 'Bubble Coral';

  @override
  String get species_bubble_coral_desc =>
      'Distinctive coral with grape-like vesicles that inflate during the day to capture light.';

  @override
  String get species_plate_coral_name => 'Plate Coral';

  @override
  String get species_plate_coral_desc =>
      'Thin plating coral forming whorled shelves, common on Indo-Pacific reef slopes.';

  @override
  String get species_pillar_coral_name => 'Pillar Coral';

  @override
  String get species_pillar_coral_desc =>
      'Rare upward-growing coral forming tall columns, found in the Caribbean.';

  @override
  String get species_star_coral_name => 'Star Coral';

  @override
  String get species_star_coral_desc =>
      'Major Caribbean reef builder forming large boulder-shaped colonies with star-shaped polyps.';

  @override
  String get species_lettuce_coral_name => 'Lettuce Coral';

  @override
  String get species_lettuce_coral_desc =>
      'Thin plating coral with leaf-like folds, common on Caribbean reef walls and slopes.';

  @override
  String get species_finger_coral_name => 'Finger Coral';

  @override
  String get species_finger_coral_desc =>
      'Sturdy branching coral with thick finger-like projections found on shallow reefs.';

  @override
  String get species_massive_porites_name => 'Massive Porites Coral';

  @override
  String get species_massive_porites_desc =>
      'Large boulder coral that can grow for centuries, a dominant reef builder in the Indo-Pacific.';

  @override
  String get species_cauliflower_coral_name => 'Cauliflower Coral';

  @override
  String get species_cauliflower_coral_desc =>
      'Compact branching coral with a cauliflower shape, widespread in tropical reef shallows.';

  @override
  String get species_flower_pot_coral_name => 'Flowerpot Coral';

  @override
  String get species_flower_pot_coral_desc =>
      'Colony of long-tentacled polyps that extend during the day, resembling a bouquet of flowers.';

  @override
  String get species_cup_coral_name => 'Orange Cup Coral';

  @override
  String get species_cup_coral_desc =>
      'Bright orange non-photosynthetic coral found on walls and overhangs in tropical waters.';

  @override
  String get species_scroll_coral_name => 'Scroll Coral';

  @override
  String get species_scroll_coral_desc =>
      'Coral forming large scrolling plates, common on Indo-Pacific reef slopes and lagoons.';

  @override
  String get species_cabbage_coral_name => 'Cabbage Coral';

  @override
  String get species_cabbage_coral_desc =>
      'Disc-shaped plating coral resembling cabbage leaves, found in sheltered reef areas.';

  @override
  String get species_hammer_coral_name => 'Hammer Coral';

  @override
  String get species_hammer_coral_desc =>
      'Large-polyped coral with anchor or hammer-shaped tentacle tips, popular on Indo-Pacific reefs.';

  @override
  String get species_torch_coral_name => 'Torch Coral';

  @override
  String get species_torch_coral_desc =>
      'Branching coral with long flowing tentacles tipped with glowing bulbs.';

  @override
  String get species_frogspawn_coral_name => 'Frogspawn Coral';

  @override
  String get species_frogspawn_coral_desc =>
      'Large-polyped coral with branching tentacle tips resembling frog eggs.';

  @override
  String get species_sea_fan_name => 'Common Sea Fan';

  @override
  String get species_sea_fan_desc =>
      'Flat fan-shaped gorgonian oriented perpendicular to currents, iconic on Caribbean reefs.';

  @override
  String get species_venus_sea_fan_name => 'Venus Sea Fan';

  @override
  String get species_venus_sea_fan_desc =>
      'Delicate fan-shaped gorgonian found on shallow Caribbean reefs in moderate current areas.';

  @override
  String get species_deepwater_sea_fan_name => 'Deepwater Sea Fan';

  @override
  String get species_deepwater_sea_fan_desc =>
      'Large bushy gorgonian found on deep reef walls in the Caribbean.';

  @override
  String get species_sea_whip_name => 'Sea Whip';

  @override
  String get species_sea_whip_desc =>
      'Slender rod-shaped gorgonian found swaying in currents on Atlantic and Caribbean reefs.';

  @override
  String get species_sea_plume_name => 'Sea Plume';

  @override
  String get species_sea_plume_desc =>
      'Tall feathery gorgonian forming plume-like colonies on Caribbean reef tops.';

  @override
  String get species_organ_pipe_coral_name => 'Organ Pipe Coral';

  @override
  String get species_organ_pipe_coral_desc =>
      'Bright red skeletal tubes with delicate polyps, found on sheltered Indo-Pacific reefs.';

  @override
  String get species_leather_coral_name => 'Leather Coral';

  @override
  String get species_leather_coral_desc =>
      'Soft coral with a smooth leathery surface that forms large mushroom-shaped colonies.';

  @override
  String get species_toadstool_leather_coral_name => 'Toadstool Leather Coral';

  @override
  String get species_toadstool_leather_coral_desc =>
      'Soft coral with a thick stalk and flat cap, common on Indo-Pacific reef flats.';

  @override
  String get species_pulsing_xenia_name => 'Pulsing Xenia';

  @override
  String get species_pulsing_xenia_desc =>
      'Soft coral with rhythmically pulsing polyps, found in sheltered Indo-Pacific waters.';

  @override
  String get species_tree_coral_name => 'Tree Coral';

  @override
  String get species_tree_coral_desc =>
      'Vibrant soft coral forming tree-like clusters on walls and overhangs in the Red Sea.';

  @override
  String get species_blue_coral_name => 'Blue Coral';

  @override
  String get species_blue_coral_desc =>
      'Unique octocoral with a blue skeleton, found on shallow Indo-Pacific reef flats.';

  @override
  String get species_black_coral_name => 'Black Coral';

  @override
  String get species_black_coral_desc =>
      'Deep-water coral with a dark skeleton, found on walls and drop-offs below 30 meters.';

  @override
  String get species_carnation_coral_name => 'Carnation Coral';

  @override
  String get species_carnation_coral_desc =>
      'Brightly colored soft coral found under ledges and on walls in the Indo-Pacific.';

  @override
  String get species_wire_coral_name => 'Wire Coral';

  @override
  String get species_wire_coral_desc =>
      'Long spiral black coral forming coiled whips, host to gobies and shrimp.';

  @override
  String get species_dead_mans_fingers_name => 'Dead Man\'s Fingers';

  @override
  String get species_dead_mans_fingers_desc =>
      'Fleshy soft coral with finger-like lobes, common on temperate North Atlantic reefs.';

  @override
  String get species_sun_coral_name => 'Sun Coral';

  @override
  String get species_sun_coral_desc =>
      'Yellow-orange non-photosynthetic coral that opens its polyps at night on Indo-Pacific walls.';

  @override
  String get species_lace_coral_name => 'Lace Coral';

  @override
  String get species_lace_coral_desc =>
      'Delicate pink hydrocoral with lace-like branches found in crevices and under ledges.';

  @override
  String get species_kenya_tree_coral_name => 'Kenya Tree Coral';

  @override
  String get species_kenya_tree_coral_desc =>
      'Hardy soft coral with tree-like branches, common in the Indo-Pacific.';

  @override
  String get species_colt_coral_name => 'Colt Coral';

  @override
  String get species_colt_coral_desc =>
      'Soft coral with thick rubbery branches covered in small polyps on Indo-Pacific reefs.';

  @override
  String get species_turtle_grass_name => 'Turtle Grass';

  @override
  String get species_turtle_grass_desc =>
      'Dominant Caribbean seagrass with wide flat blades, vital food source for sea turtles.';

  @override
  String get species_eelgrass_name => 'Eelgrass';

  @override
  String get species_eelgrass_desc =>
      'Temperate seagrass forming dense underwater meadows that serve as nursery habitat.';

  @override
  String get species_manatee_grass_name => 'Manatee Grass';

  @override
  String get species_manatee_grass_desc =>
      'Cylindrical-bladed seagrass found in Caribbean sandy areas, often near turtle grass beds.';

  @override
  String get species_shoal_grass_name => 'Shoal Grass';

  @override
  String get species_shoal_grass_desc =>
      'Pioneer seagrass with narrow blades, colonizes disturbed sandy areas in the Caribbean.';

  @override
  String get species_paddle_grass_name => 'Paddle Grass';

  @override
  String get species_paddle_grass_desc =>
      'Small delicate seagrass with oval leaves, found in deeper waters across the tropics.';

  @override
  String get species_neptune_grass_name => 'Neptune Grass';

  @override
  String get species_neptune_grass_desc =>
      'Mediterranean seagrass forming vast meadows critical for coastal marine ecosystems.';

  @override
  String get species_giant_kelp_name => 'Giant Kelp';

  @override
  String get species_giant_kelp_desc =>
      'Towering underwater forest species growing up to 60 meters, iconic for California diving.';

  @override
  String get species_bull_kelp_name => 'Bull Kelp';

  @override
  String get species_bull_kelp_desc =>
      'Pacific kelp with a single long stipe and bulbous float, forms dense canopy forests.';

  @override
  String get species_bladder_wrack_name => 'Bladder Wrack';

  @override
  String get species_bladder_wrack_desc =>
      'Common brown alga with paired air bladders, found in intertidal zones of the North Atlantic.';

  @override
  String get species_sargassum_name => 'Sargassum';

  @override
  String get species_sargassum_desc =>
      'Free-floating brown alga forming rafts that shelter juvenile fish and invertebrates.';

  @override
  String get species_kelp_forest_ecklonia_name => 'Ecklonia Kelp';

  @override
  String get species_kelp_forest_ecklonia_desc =>
      'Dominant kelp in southern hemisphere waters, forming important underwater forests.';

  @override
  String get species_coralline_algae_name => 'Coralline Algae';

  @override
  String get species_coralline_algae_desc =>
      'Hard encrusting red alga that cements reef structures and gives reefs a pink hue.';

  @override
  String get species_irish_moss_name => 'Irish Moss';

  @override
  String get species_irish_moss_desc =>
      'Fan-shaped red alga found on rocky shores of the North Atlantic intertidal zone.';

  @override
  String get species_dulse_name => 'Dulse';

  @override
  String get species_dulse_desc =>
      'Flat reddish-purple alga growing on rocks and kelp stipes in cold northern waters.';

  @override
  String get species_halimeda_name => 'Halimeda';

  @override
  String get species_halimeda_desc =>
      'Calcified green alga with disc-shaped segments, major contributor to reef sand.';

  @override
  String get species_sea_lettuce_name => 'Sea Lettuce';

  @override
  String get species_sea_lettuce_desc =>
      'Bright green sheet-like alga found in shallow coastal waters worldwide.';

  @override
  String get species_caulerpa_name => 'Green Grape Algae';

  @override
  String get species_caulerpa_desc =>
      'Creeping green alga with grape-like fronds, found on tropical reef rubble and sand.';

  @override
  String get species_mermaid_fan_name => 'Mermaid\'s Fan';

  @override
  String get species_mermaid_fan_desc =>
      'Calcified green alga shaped like a small fan, common on Caribbean sandy bottoms.';

  @override
  String get species_shaving_brush_algae_name => 'Shaving Brush Algae';

  @override
  String get species_shaving_brush_algae_desc =>
      'Calcified green alga with a brush-like tuft on a stalk, found on Caribbean sandy bottoms.';

  @override
  String get species_finger_kelp_name => 'Oarweed';

  @override
  String get species_finger_kelp_desc =>
      'Brown alga with finger-like fronds forming kelp beds in North Atlantic coastal waters.';

  @override
  String get species_banded_sea_krait_name => 'Banded Sea Krait';

  @override
  String get species_banded_sea_krait_desc =>
      'Venomous sea snake with blue-grey and black bands, docile and commonly seen on Indo-Pacific reefs.';

  @override
  String get species_olive_sea_snake_name => 'Olive Sea Snake';

  @override
  String get species_olive_sea_snake_desc =>
      'Curious sea snake found on Australian reefs, known for approaching divers.';

  @override
  String get species_yellow_bellied_sea_snake_name =>
      'Yellow-bellied Sea Snake';

  @override
  String get species_yellow_bellied_sea_snake_desc =>
      'Pelagic sea snake with yellow underside, the most widespread snake species on Earth.';

  @override
  String get species_marine_iguana_name => 'Marine Iguana';

  @override
  String get species_marine_iguana_desc =>
      'Endemic to the Galapagos, the only lizard that forages underwater on algae.';

  @override
  String get species_saltwater_crocodile_name => 'Saltwater Crocodile';

  @override
  String get species_saltwater_crocodile_desc =>
      'Largest living reptile, found in coastal and estuarine waters of the Indo-Pacific.';

  @override
  String get common_action_done => 'Done';

  @override
  String get common_action_more => 'More';

  @override
  String get common_label_displayName => 'Display name';

  @override
  String common_relativeTime_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}d ago',
      one: '${count}d ago',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}h ago',
      one: '${count}h ago',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in ${count}d',
      one: 'in ${count}d',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in ${count}h',
      one: 'in ${count}h',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_inLessThanMinute => 'in <1m';

  @override
  String common_relativeTime_inMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in ${count}m',
      one: 'in ${count}m',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_justNow => 'just now';

  @override
  String common_relativeTime_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}m ago',
      one: '${count}m ago',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}mo ago',
      one: '${count}mo ago',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_overdue => 'overdue';

  @override
  String get media_cache_calculating => 'Calculating cache size…';

  @override
  String get media_cache_cardTitle => 'Cache management';

  @override
  String get media_cache_clearAction => 'Clear cache';

  @override
  String get media_cache_clearBody =>
      'Removes downloaded thumbnails and full-size network images. Linked media rows are kept; images will re-download on next view.';

  @override
  String get media_cache_clearConfirm => 'Clear';

  @override
  String media_cache_clearError(String error) {
    return 'Clear failed: $error';
  }

  @override
  String get media_cache_clearTitle => 'Clear network image cache?';

  @override
  String get media_cache_cleared => 'Cache cleared';

  @override
  String get media_cache_diskCache => 'Disk cache';

  @override
  String media_cache_error(String error) {
    return 'Error: $error';
  }

  @override
  String get media_credentials_actionTest => 'Test credentials';

  @override
  String media_credentials_authLabel(String authType) {
    return 'Auth: $authType';
  }

  @override
  String get media_credentials_deleteBody =>
      'Removes the saved credentials. Items linked through this host will start showing \"Sign in required\" until you re-add them.';

  @override
  String media_credentials_deleteError(String error) {
    return 'Delete failed: $error';
  }

  @override
  String media_credentials_deleteTitle(String host) {
    return 'Delete $host?';
  }

  @override
  String media_credentials_deleted(String host) {
    return 'Deleted $host';
  }

  @override
  String media_credentials_editTitle(String host) {
    return 'Edit $host';
  }

  @override
  String get media_credentials_emptySubtitle =>
      'Per-host credentials added during URL or manifest imports show up here.';

  @override
  String get media_credentials_emptyTitle => 'No saved credentials';

  @override
  String media_credentials_lastUsed(String when) {
    return 'Last used $when';
  }

  @override
  String get media_credentials_loadError => 'Could not load saved hosts';

  @override
  String get media_credentials_loading => 'Loading saved hosts...';

  @override
  String media_credentials_saveError(String error) {
    return 'Save failed: $error';
  }

  @override
  String get media_credentials_savedHostsTitle => 'Saved hosts';

  @override
  String media_credentials_testError(String error) {
    return 'Test failed: $error';
  }

  @override
  String media_credentials_testFailed(String host) {
    return 'Credentials failed for $host';
  }

  @override
  String media_credentials_testOk(String host) {
    return 'Credentials OK for $host';
  }

  @override
  String get media_manifest_actionPollNow => 'Poll now';

  @override
  String get media_manifest_cardTitle => 'Manifest subscriptions';

  @override
  String get media_manifest_deleteBody =>
      'Removes the subscription. Already-imported entries will remain (you can clean them up via the orphan queue).';

  @override
  String media_manifest_deleteError(String error) {
    return 'Delete failed: $error';
  }

  @override
  String media_manifest_deleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get media_manifest_editTitle => 'Edit subscription';

  @override
  String get media_manifest_emptySubtitle =>
      'Subscribe to an Atom/RSS, JSON, or CSV manifest from the URL tab to keep your library in sync.';

  @override
  String get media_manifest_emptyTitle => 'No manifest subscriptions';

  @override
  String media_manifest_lastError(String error) {
    return 'Last error: $error';
  }

  @override
  String media_manifest_lastPolled(String when) {
    return 'Last polled $when';
  }

  @override
  String get media_manifest_loadError => 'Could not load subscriptions';

  @override
  String get media_manifest_loading => 'Loading subscriptions...';

  @override
  String get media_manifest_neverPolled => 'Never polled';

  @override
  String media_manifest_nextPoll(String when) {
    return 'Next $when';
  }

  @override
  String get media_manifest_notFound => 'Subscription not found';

  @override
  String media_manifest_pollError(String error) {
    return 'Poll failed: $error';
  }

  @override
  String media_manifest_polled(String name) {
    return 'Polled $name';
  }

  @override
  String media_manifest_polling(String name) {
    return 'Polling $name...';
  }

  @override
  String media_manifest_saveError(String error) {
    return 'Save failed: $error';
  }

  @override
  String media_manifest_updateError(String error) {
    return 'Could not update: $error';
  }

  @override
  String get media_manifest_urlLabel => 'Manifest URL';

  @override
  String media_scan_failed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String media_scan_progressItems(int done, int total) {
    return '$done / $total items';
  }

  @override
  String media_scan_progressReachability(int available, int unreachable) {
    return '$available reachable  ·  $unreachable unreachable';
  }

  @override
  String media_scan_summary(
    int total,
    String seconds,
    int available,
    int unreachable,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other:
          'Scanned $total items in ${seconds}s: $available reachable, $unreachable unreachable',
      one:
          'Scanned $total item in ${seconds}s: $available reachable, $unreachable unreachable',
    );
    return '$_temp0';
  }

  @override
  String media_scan_summarySkipped(String base, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skipped (no URL)',
      one: '$count skipped (no URL)',
    );
    return '$base, $_temp0';
  }

  @override
  String get media_scan_title => 'Scan all network media';

  @override
  String get settings_mediaSources_androidUriTitle => 'Android URI permissions';

  @override
  String settings_mediaSources_androidUriUsage(int used, int limit) {
    return '$used / $limit persistable URIs in use';
  }

  @override
  String get settings_mediaSources_counting => 'Counting…';

  @override
  String settings_mediaSources_error(String error) {
    return 'Error: $error';
  }

  @override
  String get settings_mediaSources_loading => 'Loading…';

  @override
  String settings_mediaSources_localFilesCounts(
    int available,
    int unavailable,
  ) {
    return '$available available, $unavailable unavailable';
  }

  @override
  String get settings_mediaSources_photoLibrarySubtitle =>
      'Apple Photos / Google Photos / iCloud';

  @override
  String get settings_mediaSources_reverifyAll => 'Re-verify all local files';

  @override
  String settings_mediaSources_reverifyFailed(String error) {
    return 'Re-verify failed: $error';
  }

  @override
  String settings_mediaSources_reverifyResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items updated',
      one: '$count item updated',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_checkAll => 'Check all media';

  @override
  String settings_mediaSources_checkAllResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items updated',
      one: '$count item updated',
    );
    return '$_temp0';
  }

  @override
  String settings_mediaSources_checkAllBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Could not check any of the $count items. Their sources are not reachable right now.',
      one: 'Could not check the item. Its source is not reachable right now.',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_title => 'Media Sources';

  @override
  String get settings_networkSources_scanDescription =>
      'Re-checks every URL- or manifest-imported photo against its host. Marks unreachable items so they show \"missing\" in your library and can be cleaned up.';

  @override
  String statistics_conditions_entryMethod_semanticLabel(String description) {
    return 'Bar chart. Entry methods. $description';
  }

  @override
  String statistics_conditions_visibility_semanticLabel(String description) {
    return 'Pie chart. Visibility distribution. $description';
  }

  @override
  String statistics_conditions_waterType_semanticLabel(String description) {
    return 'Pie chart. Water type distribution. $description';
  }

  @override
  String statistics_progression_divesBySuitThickness_semanticLabel(
    String description,
  ) {
    return 'Bar chart. Dives by suit thickness. $description';
  }

  @override
  String statistics_progression_divesPerYear_countInYear(
    int count,
    String year,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dives in $year',
      one: '1 dive in $year',
    );
    return '$_temp0';
  }

  @override
  String statistics_progression_divesPerYear_semanticLabel(String description) {
    return 'Bar chart. Dives per year. $description';
  }

  @override
  String get statistics_records_unavailable => 'Records unavailable';

  @override
  String statistics_summary_depthBucket_over(String min, String unit) {
    return '$min$unit+';
  }

  @override
  String statistics_summary_depthBucket_range(
    String min,
    String max,
    String unit,
  ) {
    return '$min-$max$unit';
  }

  @override
  String get statistics_summary_distributions_title => 'Distributions';

  @override
  String get statistics_summary_diveTypes_error =>
      'Unable to load dive type data';

  @override
  String get statistics_summary_diveTypes_unknown => 'Unknown';

  @override
  String get statistics_summary_divesPerMonth => 'Dives / Month';

  @override
  String get statistics_summary_divesPerYear => 'Dives / Year';

  @override
  String statistics_timePatterns_dayOfWeek_semanticLabel(String description) {
    return 'Bar chart. Dives by day of week. $description';
  }

  @override
  String statistics_timePatterns_seasonal_semanticLabel(String description) {
    return 'Bar chart. Dives by month. $description';
  }

  @override
  String statistics_timePatterns_surfaceInterval_statLabel(
    String label,
    String value,
  ) {
    return '$label surface interval: $value';
  }

  @override
  String get statistics_timePatterns_timeOfDay_afternoon => 'Afternoon';

  @override
  String get statistics_timePatterns_timeOfDay_evening => 'Evening';

  @override
  String get statistics_timePatterns_timeOfDay_morning => 'Morning';

  @override
  String get statistics_timePatterns_timeOfDay_night => 'Night';

  @override
  String statistics_timePatterns_timeOfDay_semanticLabel(String description) {
    return 'Pie chart. Dives by time of day. $description';
  }

  @override
  String get columnConfig_displayOptions => 'Display Options';

  @override
  String get columnConfig_noExtraFields =>
      'No extra fields configured. Add fields below.';

  @override
  String get columnConfig_savePresetTitle => 'Save Preset';

  @override
  String get columnConfig_section => 'Section';

  @override
  String get columnConfig_showTags => 'Show tags';

  @override
  String get columnConfig_showTags_subtitle =>
      'Display tag chips on detailed dive cards';

  @override
  String get columnConfig_slot_date => 'Date / Subtitle';

  @override
  String get columnConfig_slot_slot1 => 'Slot 1';

  @override
  String get columnConfig_slot_slot2 => 'Slot 2';

  @override
  String get columnConfig_slot_slot3 => 'Slot 3';

  @override
  String get columnConfig_slot_slot4 => 'Slot 4';

  @override
  String get columnConfig_slot_stat1 => 'Stat 1';

  @override
  String get columnConfig_slot_stat2 => 'Stat 2';

  @override
  String get columnConfig_slot_subtitle => 'Subtitle';

  @override
  String get columnConfig_slot_title => 'Title';

  @override
  String get columnConfig_tooltip_columnSettings => 'Column settings';

  @override
  String get common_action_add => 'Add';

  @override
  String get common_action_pin => 'Pin';

  @override
  String get common_action_remove => 'Remove';

  @override
  String get common_action_unpin => 'Unpin';

  @override
  String diveLog_filterChip_dateRange(String end, String start) {
    return '$start - $end';
  }

  @override
  String diveLog_filterChip_equipmentCount(int count) {
    return '$count Equipment';
  }

  @override
  String get diveLog_filter_allComputers => 'All computers';

  @override
  String get diveLog_filter_noComputersRegistered =>
      'No dive computers registered';

  @override
  String diveLog_filter_sectionDepthRangeUnit(String unit) {
    return 'Depth Range ($unit)';
  }

  @override
  String get diveLog_filter_sectionDiveComputer => 'Dive Computer';

  @override
  String diveLog_listPage_semanticsDiveAtSite(int diveNumber, String siteName) {
    return 'Dive $diveNumber at $siteName';
  }

  @override
  String get enum_listViewMode_compact => 'Compact';

  @override
  String get enum_listViewMode_dense => 'Dense';

  @override
  String get enum_listViewMode_detailed => 'Detailed';

  @override
  String get enum_listViewMode_table => 'Table';

  @override
  String get enum_profileMetric_ascentRate => 'Ascent Rate';

  @override
  String get enum_profileMetric_cns => 'CNS%';

  @override
  String get enum_profileMetric_otu => 'OTU';

  @override
  String get enum_sortField_bottomTime => 'Bottom Time';

  @override
  String get enum_sortField_serviceDue => 'Service Due';

  @override
  String get listViewMode_tooltip => 'View mode';

  @override
  String marineLife_speciesManage_errorLoading(Object error) {
    return 'Error loading species: $error';
  }

  @override
  String get settings_appearance_header_cards => 'Cards';

  @override
  String get settings_appearance_header_listView => 'List View';

  @override
  String get settings_appearance_header_tableMode => 'Table Mode';

  @override
  String get settings_appearance_listFields_buddies => 'Buddy List Fields';

  @override
  String get settings_appearance_listFields_certifications =>
      'Certification List Fields';

  @override
  String get settings_appearance_listFields_courses => 'Course List Fields';

  @override
  String get settings_appearance_listFields_diveCenters =>
      'Dive Center List Fields';

  @override
  String get settings_appearance_listFields_dives => 'Dive List Fields';

  @override
  String get settings_appearance_listFields_equipment =>
      'Equipment List Fields';

  @override
  String get settings_appearance_listFields_sites => 'Site List Fields';

  @override
  String get settings_appearance_listFields_subtitle =>
      'Customize fields shown in list views';

  @override
  String get settings_appearance_listFields_trips => 'Trip List Fields';

  @override
  String get settings_appearance_listView_buddies => 'Buddies List View';

  @override
  String get settings_appearance_listView_buddies_subtitle =>
      'Default layout for the buddies list';

  @override
  String get settings_appearance_listView_certifications =>
      'Certifications List View';

  @override
  String get settings_appearance_listView_certifications_subtitle =>
      'Default layout for the certifications list';

  @override
  String get settings_appearance_listView_courses => 'Courses List View';

  @override
  String get settings_appearance_listView_courses_subtitle =>
      'Default layout for the courses list';

  @override
  String get settings_appearance_listView_diveCenters =>
      'Dive Centers List View';

  @override
  String get settings_appearance_listView_diveCenters_subtitle =>
      'Default layout for the dive centers list';

  @override
  String get settings_appearance_listView_dives => 'Dives List View';

  @override
  String get settings_appearance_listView_dives_subtitle =>
      'Default layout for the dives list';

  @override
  String get settings_appearance_listView_equipment => 'Equipment List View';

  @override
  String get settings_appearance_listView_equipment_subtitle =>
      'Default layout for the equipment list';

  @override
  String get settings_appearance_listView_sites => 'Sites List View';

  @override
  String get settings_appearance_listView_sites_subtitle =>
      'Default layout for the sites list';

  @override
  String get settings_appearance_listView_trips => 'Trips List View';

  @override
  String get settings_appearance_listView_trips_subtitle =>
      'Default layout for the trips list';

  @override
  String get settings_appearance_showDataSourceBadges =>
      'Show data source badges';

  @override
  String get settings_appearance_showDataSourceBadges_subtitle =>
      'Display source attribution on dive metrics';

  @override
  String get settings_appearance_title_buddies => 'Buddies Appearance';

  @override
  String get settings_appearance_title_certifications =>
      'Certifications Appearance';

  @override
  String get settings_appearance_title_courses => 'Courses Appearance';

  @override
  String get settings_appearance_title_diveCenters => 'Dive Centers Appearance';

  @override
  String get settings_appearance_title_dives => 'Dives Appearance';

  @override
  String get settings_appearance_title_equipment => 'Equipment Appearance';

  @override
  String get settings_appearance_title_sites => 'Sites Appearance';

  @override
  String get settings_appearance_title_trips => 'Trips Appearance';

  @override
  String get settings_cloudSync_troubleshoot_tileSubtitle =>
      'Fix a stuck sync or free cloud space';

  @override
  String get settings_data_header_dataTools => 'Data Tools';

  @override
  String get settings_decompression_ascentGasLabel => 'Plan ascent with';

  @override
  String get settings_decompression_ascentGas_allCarried =>
      'All carried cylinders';

  @override
  String get settings_decompression_ascentGas_decoStage =>
      'Deco/stage + back gas';

  @override
  String get settings_decompression_cnsSource => 'CNS Source';

  @override
  String get settings_decompression_decoStopSource => 'Deco Stop Source';

  @override
  String get settings_decompression_header_ascent => 'Ascent planning';

  @override
  String get settings_decompression_header_ascent_subtitle =>
      'Which carried cylinders the simulated ascent (TTS, ceiling and stops) may switch to at each depth. Only gases recorded on the dive are considered.';

  @override
  String get settings_decompression_header_dataSources =>
      'Data Source Preferences';

  @override
  String get settings_decompression_header_dataSources_subtitle =>
      'When set to Dive Computer, the app uses data reported by the dive computer when available. Falls back to calculated values when computer data is not present.';

  @override
  String get settings_decompression_ndlSource => 'NDL Source';

  @override
  String get settings_decompression_sourceCalculated => 'Calculated';

  @override
  String get settings_decompression_sourceComputer => 'Dive Computer';

  @override
  String get settings_decompression_ttsSource => 'TTS Source';

  @override
  String settings_fixDiveTimes_applied(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'hours',
      one: 'hour',
    );
    return 'Updated $count $_temp0 by $hours $_temp1.';
  }

  @override
  String settings_fixDiveTimes_apply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    return 'Apply to $count $_temp0';
  }

  @override
  String get settings_fixDiveTimes_clearRange => 'Clear date range';

  @override
  String get settings_fixDiveTimes_confirmApply => 'Apply';

  @override
  String settings_fixDiveTimes_confirmBody(
    int count,
    String hours,
    int hoursAbs,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'hours',
      one: 'hour',
    );
    return 'This will shift $count $_temp0 by $hours $_temp1. This cannot be undone automatically.';
  }

  @override
  String get settings_fixDiveTimes_confirmTitle => 'Apply Time Offset';

  @override
  String get settings_fixDiveTimes_dateRangeFilter => 'Date Range Filter';

  @override
  String get settings_fixDiveTimes_deselectAll => 'Deselect All';

  @override
  String get settings_fixDiveTimes_diveFallback => 'Dive';

  @override
  String settings_fixDiveTimes_diveNumber(int number) {
    return 'Dive #$number';
  }

  @override
  String get settings_fixDiveTimes_empty => 'No dives found.';

  @override
  String get settings_fixDiveTimes_emptyFiltered =>
      'No dives found in this date range.';

  @override
  String get settings_fixDiveTimes_enterOffsetHint => 'Enter an hour offset';

  @override
  String get settings_fixDiveTimes_from => 'From';

  @override
  String get settings_fixDiveTimes_hourOffset => 'Hour Offset';

  @override
  String get settings_fixDiveTimes_hoursField => 'Hours (e.g. +7, -5)';

  @override
  String settings_fixDiveTimes_loadError(String error) {
    return 'Failed to load dives: $error';
  }

  @override
  String get settings_fixDiveTimes_noSelection => 'No dives selected.';

  @override
  String get settings_fixDiveTimes_offsetHint =>
      'Enter a positive or negative integer to shift dive times.';

  @override
  String settings_fixDiveTimes_preview(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dives',
      one: 'dive',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'hours',
      one: 'hour',
    );
    return 'Preview: $count $_temp0 will shift by $hours $_temp1.';
  }

  @override
  String get settings_fixDiveTimes_selectAll => 'Select All';

  @override
  String get settings_fixDiveTimes_selectDivesHint => 'Select dives to apply';

  @override
  String get settings_fixDiveTimes_subtitle =>
      'Adjust times for imported dives';

  @override
  String get settings_fixDiveTimes_title => 'Fix Dive Times';

  @override
  String get settings_fixDiveTimes_to => 'To';

  @override
  String get settings_fixDiveTimes_zeroOffset =>
      'Hour offset is 0, nothing to change.';

  @override
  String get settings_syncDevices_appBar_refreshTooltip => 'Refresh';

  @override
  String get settings_syncDevices_appBar_title => 'Devices on this backend';

  @override
  String get settings_syncDevices_empty => 'No sync files on this backend.';

  @override
  String settings_syncDevices_readError(String error) {
    return 'Could not read the backend.\n$error';
  }

  @override
  String get settings_syncDevices_removal_noBackend =>
      'No cloud backend is configured';

  @override
  String get settings_syncDevices_removal_unreachable =>
      'Could not reach the backend. Nothing was removed.';

  @override
  String settings_syncDevices_removeDialog_bodyRisky(
    int count,
    String name,
    String size,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This deletes $count files ($size) belonging to $name.\n\nThat device is still part of this sync. If it comes back online it will rebuild from the backend rather than resurrect old data, but any changes it has not yet published will be lost. Your dive data on THIS device is not affected.',
      one:
          'This deletes 1 file ($size) belonging to $name.\n\nThat device is still part of this sync. If it comes back online it will rebuild from the backend rather than resurrect old data, but any changes it has not yet published will be lost. Your dive data on THIS device is not affected.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_removeDialog_bodySafe(
    int count,
    String name,
    String size,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This deletes $count files ($size) belonging to $name. They are left over from a library no device syncs from any more. Your dive data is not affected.',
      one:
          'This deletes 1 file ($size) belonging to $name. It is left over from a library no device syncs from any more. Your dive data is not affected.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_removeDialog_title(String name) {
    return 'Remove $name’s files?';
  }

  @override
  String settings_syncDevices_removeProgressTitle(String name) {
    return 'Removing $name’s files';
  }

  @override
  String get settings_syncDevices_removeTooltip => 'Remove this device’s files';

  @override
  String get settings_syncDevices_state_active => 'Syncing normally';

  @override
  String get settings_syncDevices_state_retired => 'Retired';

  @override
  String get settings_syncDevices_state_staleEpoch =>
      'Left over from an earlier library - no device reads this';

  @override
  String get settings_syncDevices_state_thisDevice => 'This device';

  @override
  String get settings_syncDevices_state_unreadable =>
      'No readable manifest - an unfinished upload, or encrypted';

  @override
  String settings_syncDevices_summary(
    int deviceCount,
    int fileCount,
    String size,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      deviceCount,
      locale: localeName,
      other: '$deviceCount devices',
      one: '1 device',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: '$fileCount files',
      one: '1 file',
    );
    return '$_temp0, $_temp1, $size';
  }

  @override
  String settings_syncDevices_summary_removable(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count left over from a replaced or retired library, holding $size.',
      one: '1 left over from a replaced or retired library, holding $size.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_tile_filesSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0, $size';
  }

  @override
  String settings_syncDevices_tile_filesSizeSeen(
    int count,
    String size,
    String when,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0, $size - $when';
  }

  @override
  String settings_syncDevices_unnamedDevice(String shortId) {
    return 'Device $shortId';
  }

  @override
  String get settings_syncMaintenance_keepAppOpen =>
      'Keep the app open until this finishes. Closing it now leaves the backend partly cleared, and the next sync has to start over.';

  @override
  String get settings_syncMaintenance_phase_clearingOldFiles =>
      'Clearing old files';

  @override
  String get settings_syncMaintenance_phase_deleting => 'Deleting';

  @override
  String get settings_syncMaintenance_phase_publishingLibrary =>
      'Publishing library';

  @override
  String get settings_cloudSync_adopt_progressTitle =>
      'Adopting the restored library';

  @override
  String get settings_cloudSync_replaceLibrary_progressTitle =>
      'Replacing the cloud library';

  @override
  String settings_syncDevices_nameWithId(String name, String shortId) {
    return '$name ($shortId)';
  }

  @override
  String get settings_syncMaintenance_phase_applyingLibrary =>
      'Applying the library';

  @override
  String get settings_syncMaintenance_phase_backingUp =>
      'Backing up this device';

  @override
  String get settings_syncMaintenance_phase_repairing =>
      'Clearing local sync state';

  @override
  String get settings_troubleshootSync_repair_progressTitle => 'Repairing sync';

  @override
  String get settings_syncMaintenance_phase_working => 'Working...';

  @override
  String settings_syncMaintenance_progress_filesOfTotal(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done of $total files',
      one: '$done of 1 file',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_removedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count files',
      one: 'Removed 1 file',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_removedFilesPartial(
    int count,
    String trouble,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count files, but $trouble. Try again while online.',
      one: 'Removed 1 file, but $trouble. Try again while online.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_trouble_failed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count could not be deleted',
      one: '1 could not be deleted',
    );
    return '$_temp0';
  }

  @override
  String get settings_syncMaintenance_trouble_listIncomplete =>
      'some files could not be listed';

  @override
  String settings_syncMaintenance_wipedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wiped $count files',
      one: 'Wiped 1 file',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_wipedFilesPartial(int count, String trouble) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wiped $count files, but $trouble. Try again while online.',
      one: 'Wiped 1 file, but $trouble. Try again while online.',
    );
    return '$_temp0';
  }

  @override
  String get settings_troubleshootSync_appBar_title => 'Troubleshoot Sync';

  @override
  String get settings_troubleshootSync_devices_subtitle =>
      'See every device holding files here, how much space each uses, and remove leftovers from libraries no device syncs from any more. Your dive data is not affected.';

  @override
  String get settings_troubleshootSync_rebuild_confirm => 'Rebuild';

  @override
  String get settings_troubleshootSync_rebuild_confirmBody =>
      'This makes this device’s library the current one on the backend and republishes it, so other devices sync from you. Use it when a replacement from another device is stuck. Your dive data is not affected.';

  @override
  String get settings_troubleshootSync_rebuild_confirmTitle =>
      'Rebuild backend from this device?';

  @override
  String get settings_troubleshootSync_rebuild_doneSnack =>
      'Rebuilt backend from this device';

  @override
  String get settings_troubleshootSync_rebuild_failedSnack => 'Rebuild failed';

  @override
  String get settings_troubleshootSync_rebuild_progressTitle =>
      'Rebuilding backend';

  @override
  String get settings_troubleshootSync_rebuild_subtitle =>
      'Use if sync is stuck waiting on a library that another device replaced but never finished uploading (that device may be offline). Publishes this device’s library as the current one.';

  @override
  String get settings_troubleshootSync_rebuild_title =>
      'Rebuild backend from this device';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmBody =>
      'This deletes only this device’s sync files from the backend. Other devices keep syncing, and your dive data is not affected.';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmTitle =>
      'Remove this device’s cloud files?';

  @override
  String get settings_troubleshootSync_removeThisDevice_progressTitle =>
      'Removing this device’s cloud files';

  @override
  String get settings_troubleshootSync_removeThisDevice_subtitle =>
      'Free this device’s space on the backend. Other devices keep syncing. Your dive data is not affected.';

  @override
  String get settings_troubleshootSync_removeThisDevice_title =>
      'Remove this device’s cloud files';

  @override
  String get settings_troubleshootSync_repair_confirm => 'Repair';

  @override
  String get settings_troubleshootSync_repair_confirmBody =>
      'This clears all local sync state and gives this device a new sync identity, then reconnects fresh on the next sync. Your dive data is safe and is not deleted.';

  @override
  String get settings_troubleshootSync_repair_confirmTitle => 'Repair Sync?';

  @override
  String get settings_troubleshootSync_repair_doneSnack => 'Sync repaired';

  @override
  String get settings_troubleshootSync_repair_subtitle =>
      'Fix a stuck sync. Clears this device’s sync state and gives it a fresh sync identity, then reconnects on the next sync. Your dive data is not affected.';

  @override
  String get settings_troubleshootSync_repair_title => 'Repair Sync';

  @override
  String get settings_troubleshootSync_wipeAll_confirm => 'Wipe everything';

  @override
  String settings_troubleshootSync_wipeAll_confirmBody(String word) {
    return 'This deletes EVERY device’s sync data from this backend, including the library markers. Every device must re-establish sync from scratch. Your dive data is not affected.\n\nType $word to confirm.';
  }

  @override
  String get settings_troubleshootSync_wipeAll_confirmTitle =>
      'Wipe all sync data?';

  @override
  String get settings_troubleshootSync_wipeAll_progressTitle =>
      'Wiping sync data';

  @override
  String get settings_troubleshootSync_wipeAll_subtitle =>
      'Delete every device’s sync data from this backend, including the library markers. Every device re-establishes from scratch. Your dive data is not affected.';

  @override
  String get settings_troubleshootSync_wipeAll_title =>
      'Wipe all sync data on this backend';

  @override
  String get tableMode_tooltip_toggleDetailPane => 'Toggle detail pane';

  @override
  String get tableMode_tooltip_toggleProfilePanel => 'Toggle profile panel';

  @override
  String get maps_regionDownload_title => 'Download Region';

  @override
  String get maps_regionDownload_nameRequired =>
      'Please enter a name for this region';

  @override
  String get maps_regionDownload_nameLabel => 'Region Name';

  @override
  String get maps_regionDownload_nameHint => 'e.g., Cozumel, Mexico';

  @override
  String get maps_regionDownload_zoomLevels => 'Zoom Levels';

  @override
  String get maps_regionDownload_zoomHint =>
      'Higher zoom = more detail, larger download';

  @override
  String maps_regionDownload_minZoom(int zoom) {
    return 'Min: $zoom';
  }

  @override
  String maps_regionDownload_minZoomSemantics(int zoom) {
    return 'Minimum zoom: $zoom';
  }

  @override
  String maps_regionDownload_maxZoom(int zoom) {
    return 'Max: $zoom';
  }

  @override
  String maps_regionDownload_maxZoomSemantics(int zoom) {
    return 'Maximum zoom: $zoom';
  }

  @override
  String get maps_regionDownload_estimatingSemantics =>
      'Estimating download size';

  @override
  String maps_regionDownload_estimateSemantics(int count, Object size) {
    return 'Estimated download: $count tiles, $size';
  }

  @override
  String get maps_regionDownload_estimateUnavailableSemantics =>
      'Unable to estimate download size';

  @override
  String get maps_regionDownload_estimating => 'Estimating...';

  @override
  String maps_regionDownload_tileCount(int count) {
    return '~$count tiles';
  }

  @override
  String get maps_regionDownload_estimateUnavailable => 'Unable to estimate';

  @override
  String get maps_regionDownload_largeWarningSemantics =>
      'Warning: Large download. Consider reducing zoom levels or selecting a smaller region.';

  @override
  String get maps_regionDownload_largeWarning =>
      'Large download. Consider reducing zoom levels or selecting a smaller region.';

  @override
  String get maps_regionDownload_downloadButton => 'Download';

  @override
  String get diveLog_map_title => 'Dive Activity';

  @override
  String diveLog_map_infoCard_minutes(int minutes) {
    return '$minutes min';
  }

  @override
  String trips_gallery_diveSection_subtitle(
    Object date,
    int count,
    Object photoLabel,
  ) {
    return '$date ($count $photoLabel)';
  }

  @override
  String get trips_gallery_thumbnail_photo =>
      'Photo thumbnail. Tap to view full screen';

  @override
  String get trips_gallery_thumbnail_video =>
      'Video thumbnail. Tap to view full screen';

  @override
  String get trips_gallery_thumbnail_photoMissing =>
      'Photo thumbnail, missing from device. Tap to view full screen';

  @override
  String get trips_gallery_thumbnail_videoMissing =>
      'Video thumbnail, missing from device. Tap to view full screen';

  @override
  String get trips_photos_thumbnail_photo =>
      'Photo thumbnail. Tap to open gallery';

  @override
  String get trips_photos_thumbnail_video =>
      'Video thumbnail. Tap to open gallery';

  @override
  String trips_picker_suggestedSemantics(Object name) {
    return 'Suggested trip: $name. Tap to use';
  }

  @override
  String trips_picker_tileSemantics(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, $startDate to $endDate';
  }

  @override
  String trips_picker_tileSemanticsSelected(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, $startDate to $endDate, selected';
  }

  @override
  String get divePlanner_quickPlan_subtitle =>
      'Create a simple rectangular dive profile';

  @override
  String get divePlanner_quickPlan_depthLabel => 'Depth:';

  @override
  String divePlanner_quickPlan_depthSemantics(Object depth) {
    return 'Depth: $depth';
  }

  @override
  String get divePlanner_quickPlan_timeLabel => 'Time:';

  @override
  String divePlanner_quickPlan_bottomTimeSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Bottom time: $minutes minutes',
      one: 'Bottom time: 1 minute',
    );
    return '$_temp0';
  }

  @override
  String divePlanner_quickPlan_minutes(int minutes) {
    return '$minutes min';
  }

  @override
  String divePlanner_quickPlan_previewSemantics(Object depth, int minutes) {
    return 'Plan preview: Descent to $depth, bottom time $minutes minutes, ascent with safety stop';
  }

  @override
  String get divePlanner_quickPlan_previewTitle => 'Plan Preview:';

  @override
  String divePlanner_quickPlan_previewDescent(Object depth) {
    return 'Descent to $depth';
  }

  @override
  String divePlanner_quickPlan_previewBottomTime(int minutes) {
    return 'Bottom time: $minutes min';
  }

  @override
  String get divePlanner_quickPlan_previewAscent => 'Ascent with safety stop';

  @override
  String get divePlanner_quickPlan_create => 'Create';

  @override
  String divePlanner_semantics_sacRate(Object value, Object volumeSymbol) {
    return 'RMV: $value $volumeSymbol per minute';
  }

  @override
  String divePlanner_semantics_reservePressure(Object pressureSymbol) {
    return 'Reserve pressure in $pressureSymbol';
  }

  @override
  String divePlanner_semantics_altitudeGroup(Object group) {
    return 'Altitude group: $group';
  }

  @override
  String diveSites_import_detail_maxDepth(Object depth) {
    return 'Max $depth';
  }

  @override
  String get autoUpdate_banner_download => 'Download';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Sync via Apple iCloud';

  @override
  String get settings_debugLog_search_hint => 'Search logs...';

  @override
  String get settings_debugLog_appBar_title => 'Debug Logs';

  @override
  String get settings_debugLog_disableDebugMode => 'Disable Debug Mode';

  @override
  String get settings_debugLog_clearLogs => 'Clear Logs';

  @override
  String get settings_debugLog_empty =>
      'No log entries match the current filters';

  @override
  String settings_debugLog_loadError(Object error) {
    return 'Error loading logs: $error';
  }

  @override
  String get settings_debugLog_copiedSnack =>
      'Filtered logs copied to clipboard';

  @override
  String settings_debugLog_savedSnack(String path) {
    return 'Logs saved to $path';
  }

  @override
  String get common_action_copy => 'Copy';

  @override
  String get settings_appearance_customGradient_title => 'Custom Gradient';

  @override
  String get settings_appearance_customGradient_start => 'Start';

  @override
  String get settings_appearance_customGradient_end => 'End';

  @override
  String get settings_appearance_customGradient_hue => 'Hue';

  @override
  String get settings_appearance_customGradient_saturation => 'Saturation';

  @override
  String get settings_appearance_customGradient_brightness => 'Brightness';

  @override
  String get settings_appearance_customGradient_preview => 'Preview';

  @override
  String get common_action_apply => 'Apply';

  @override
  String settings_cloudSync_message_loadStateFailed(Object error) {
    return 'Failed to load sync state: $error';
  }

  @override
  String get settings_cloudSync_message_noProviderConfigured =>
      'No cloud provider configured';

  @override
  String get settings_cloudSync_message_adopting =>
      'Adopting the restored library...';

  @override
  String get settings_cloudSync_message_adoptFailed =>
      'Failed to adopt the restored library';

  @override
  String get settings_cloudSync_message_firstSyncNeedsConfirm =>
      'First sync needs confirmation. Tap Sync Now to review.';

  @override
  String get settings_cloudSync_message_startingSync => 'Starting sync...';

  @override
  String get settings_cloudSync_message_replacePaused =>
      'Sync paused: the library was replaced from a backup. Tap Sync Now to review.';

  @override
  String get settings_cloudSync_message_encryptedPaused =>
      'Sync paused: this library is encrypted. Enter the passphrase to continue.';

  @override
  String get settings_cloudSync_message_completedWithConflicts =>
      'Sync completed with conflicts';

  @override
  String get settings_cloudSync_message_completedSuccessfully =>
      'Sync completed successfully';

  @override
  String get settings_cloudSync_message_syncFailed => 'Sync failed';

  @override
  String get settings_cloudSync_message_phaseDefault => 'sync';

  @override
  String settings_cloudSync_message_syncErrorDuring(
    String phase,
    Object error,
  ) {
    return 'Sync error during $phase: $error';
  }

  @override
  String get settings_section_debug_title => 'Debug';

  @override
  String get settings_section_debug_subtitle => 'Logs & diagnostics';

  @override
  String get settings_debugLog_minSeverityLabel => 'Min severity:';

  @override
  String get settings_debugLog_shareSubject => 'Submersion Debug Logs';

  @override
  String get settings_debugLog_saveDialogTitle => 'Save Debug Logs';

  @override
  String get universalImport_preset_saveTitle => 'Save as Preset';

  @override
  String get universalImport_preset_nameLabel => 'Preset Name';

  @override
  String get universalImport_preset_nameHint => 'e.g., My Dive Log CSV';

  @override
  String get universalImport_preset_nameRequired => 'Name is required';

  @override
  String get universalImport_preset_sourceAppLabel => 'Source Application';

  @override
  String get universalImport_preset_sourceAppNone => 'None';

  @override
  String get universalImport_preset_entityTypesLabel => 'Entity Types';

  @override
  String get universalImport_preset_matchThresholdLabel => 'Match Threshold';

  @override
  String get universalImport_preset_matchThresholdHelp =>
      'How closely CSV headers must match for auto-detection';

  @override
  String universalImport_preset_signatureHeaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count signature headers from current file',
      one: '1 signature header from current file',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_preset_selectTitle => 'Select Preset';

  @override
  String universalImport_preset_loadFailed(String error) {
    return 'Failed to load presets: $error';
  }

  @override
  String get universalImport_preset_sectionSaved => 'Saved Presets';

  @override
  String get universalImport_preset_sectionBuiltIn => 'Built-in Presets';

  @override
  String get universalImport_preset_deleteTitle => 'Delete Preset';

  @override
  String universalImport_preset_deleteConfirm(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String universalImport_preset_headersMatched(
    int matched,
    int total,
    int percent,
  ) {
    return '$matched/$total headers matched ($percent%)';
  }

  @override
  String get universalImport_preset_noSignatureHeaders =>
      'No signature headers';

  @override
  String get universalImport_preset_deleteTooltip => 'Delete preset';

  @override
  String get universalImport_preset_presetsButton => 'Presets';

  @override
  String universalImport_preset_savedSnackbar(String name) {
    return 'Preset \"$name\" saved';
  }

  @override
  String get universalImport_step_done => 'Done';

  @override
  String get universalImport_cancel_inProgressTitle => 'Cancelling';

  @override
  String get universalImport_cancel_inProgressBody =>
      'Finishing the current dive before stopping. Already-imported dives are kept.';

  @override
  String get universalImport_cancel_confirmTitle => 'Cancel import?';

  @override
  String get universalImport_cancel_confirmBody =>
      'Stop after the current dive finishes. Already-imported dives will be kept.';

  @override
  String get universalImport_cancel_keepImporting => 'Keep importing';

  @override
  String get universalImport_cancel_confirmAction => 'Cancel import';

  @override
  String get universalImport_cancel_discardSelections =>
      'Discard selections and cancel?';

  @override
  String get universalImport_action_importSelected => 'Import Selected';

  @override
  String get universalImport_action_next => 'Next';

  @override
  String get common_action_yes => 'Yes';

  @override
  String get common_action_no => 'No';

  @override
  String universalImport_counts_new(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_merging(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merging',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_replacing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replacing',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_skipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skipped',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_counts_nothingSelected => 'Nothing selected';

  @override
  String get universalImport_section_potentialDuplicates =>
      'Potential Duplicates';

  @override
  String get universalImport_section_possibleDuplicates =>
      'Possible Duplicates';

  @override
  String universalImport_count_duplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicates',
      one: '1 duplicate',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_entityAction_importBadge => 'IMPORT';

  @override
  String get universalImport_entityAction_skipBadge => 'SKIP';

  @override
  String get universalImport_compare_existing => 'Existing';

  @override
  String get universalImport_compare_incoming => 'Incoming';

  @override
  String get universalImport_label_skipped => 'Skipped';

  @override
  String get universalImport_action_viewDives => 'View Dives';

  @override
  String get diveImport_healthkit_accessGranted => 'HealthKit Access Granted';

  @override
  String get diveImport_healthkit_accessGrantedBody =>
      'You can proceed to the next step.';

  @override
  String get diveImport_healthkit_requesting => 'Requesting...';

  @override
  String get diveImport_healthkit_selectDateRange => 'Select Date Range';

  @override
  String get diveImport_healthkit_selectDateRangeBody =>
      'Choose the date range to search for dives in Apple Health.';

  @override
  String get diveImport_healthkit_fetchingDives =>
      'Fetching dives from Apple Health...';

  @override
  String get diveImport_healthkit_fetchFailed => 'Fetch Failed';

  @override
  String diveImport_healthkit_fetchFailedBody(String error) {
    return 'Failed to fetch dives: $error';
  }

  @override
  String diveImport_healthkit_foundDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count dives',
      one: 'Found 1 dive',
    );
    return '$_temp0';
  }

  @override
  String get diveImport_healthkit_proceedingToReview =>
      'Proceeding to review...';

  @override
  String get importWizard_dc_knownComputer => 'Known Computer';

  @override
  String importWizard_dc_knownComputerBody(String name) {
    return 'Saved as \"$name\". Only new dives will be downloaded.';
  }

  @override
  String get importWizard_dc_noNewDives => 'No new dives to download';

  @override
  String get importWizard_dc_noNewDivesBody =>
      'All dives from this computer have already been imported.';

  @override
  String get universalImport_compare_noDiveData =>
      'Dive data not available for comparison.';

  @override
  String get universalImport_entityAction_consolidateBadge => 'CONSOLIDATE';

  @override
  String get diveCenters_import_quickSearch_egypt => 'Egypt';

  @override
  String get diveCenters_import_quickSearch_mexico => 'Mexico';

  @override
  String get accessibility_shortcut_switchDiver => 'Switch diver';

  @override
  String get lock_recoveryCode_title => 'Use recovery code';

  @override
  String get lock_recoveryCode_body =>
      'Enter the 8-word recovery code you saved when you set up the app password.';

  @override
  String get lock_recoveryCode_error => 'Incorrect recovery code.';

  @override
  String get lock_forcedReset_title => 'Set a new password';

  @override
  String get lock_forcedReset_body =>
      'You unlocked with your recovery code, so your old password is no longer trusted. Choose a new one now.';

  @override
  String get lock_forcedReset_submit => 'Set password';

  @override
  String get lock_forcedReset_error =>
      'Could not set the new password. Try again.';

  @override
  String get lock_sidecarRepair_title => 'Repair security key file';

  @override
  String get lock_sidecarRepair_body =>
      'Your security key file was missing and this device\'s keychain still holds the key. Confirm your password to write a new key file. Note: the password you enter here becomes the app password going forward, and you will receive a new recovery code.';

  @override
  String get lock_sidecarRepair_submit => 'Repair';

  @override
  String get lock_sidecarRepair_error => 'Repair failed. Try again.';

  @override
  String get lock_newRecoveryCode_title => 'Your new recovery code';

  @override
  String get lock_startFresh_title => 'Open a different database';

  @override
  String lock_startFresh_body(Object token) {
    return 'Your current database stays on disk, renamed with a .locked suffix; nothing is deleted. You can recover it later with your password or by contacting support. Cloud sync will be turned off so the new database cannot mix with the old one.\n\nThe app will start with a fresh, empty database. You can restore from a backup in the setup wizard.\n\nType $token to confirm.';
  }

  @override
  String get lock_startFresh_confirm => 'Set aside and start fresh';

  @override
  String get lock_biometric_reason => 'Unlock your dive log';

  @override
  String startup_migrating_progress(Object currentStep, Object totalSteps) {
    return 'Upgrading database... step $currentStep of $totalSteps';
  }

  @override
  String get startup_error_title => 'Submersion could not start';

  @override
  String get startup_error_body =>
      'Something went wrong before your dive log finished opening. Your data is still on disk and does not require a reinstall. Try restarting the app; if this persists, contact support.';

  @override
  String get startup_engineUnavailable_title =>
      'This build can\'t open a database';

  @override
  String get startup_engineUnavailable_body =>
      'Submersion\'s database engine is missing from this build, so your dive log was never opened. Nothing on disk has changed and no data is at risk.';

  @override
  String get startup_engineUnavailable_guidance =>
      'Reinstalling or restoring a backup will not help. Install a working build of Submersion, and please report this: it is a fault in the app package, not in your data.';

  @override
  String get startup_migrationFailed_title => 'Database upgrade failed';

  @override
  String get startup_migrationFailed_body =>
      'Your dive log could not be upgraded to the format this version needs. A safety copy was taken before the upgrade started, so nothing is lost.';

  @override
  String get startup_dataUnreadable_title => 'Your dive log could not be read';

  @override
  String get startup_dataUnreadable_body =>
      'The database file is there, but Submersion cannot read it. This usually means the file is damaged. Restoring a backup is the fastest way back.';

  @override
  String get startup_databaseBusy_title => 'Your dive log was busy';

  @override
  String get startup_databaseBusy_body =>
      'Something else was still using the database file, so Submersion stopped rather than write to it. Nothing was changed and nothing is damaged. Close Submersion completely, then open it again.';

  @override
  String get startup_failure_technicalDetails => 'Technical details';

  @override
  String get startup_failure_backupAvailable_title => 'A backup is available';

  @override
  String startup_failure_backupAvailable_taken(Object timestamp) {
    return 'Taken $timestamp';
  }

  @override
  String startup_failure_backupAvailable_preMigration(
    Object fromVersion,
    Object toVersion,
  ) {
    return 'Safety copy taken before the upgrade from schema v$fromVersion to v$toVersion.';
  }

  @override
  String get startup_failure_restoreAction => 'Restore this backup';

  @override
  String get startup_failure_restoring => 'Restoring your dive log...';

  @override
  String get startup_failure_restoreFailed =>
      'The backup could not be restored. Your dive log has been left exactly as it was.';

  @override
  String get startup_failure_backupsFolder => 'Your backups are in:';

  @override
  String get startup_failure_showBackupsFolder => 'Show backup folder';

  @override
  String get startup_failure_downgrade_title =>
      'Going back to the previous version';

  @override
  String get startup_failure_downgrade_body =>
      'If the upgrade keeps failing, install the version of Submersion you were running before, then restore the safety copy from inside that version. Restoring it here would only run the same upgrade again. Submersion does not downgrade itself: moving you onto older builds automatically would quietly keep you on versions with known problems.';

  @override
  String get startup_failure_downgrade_action => 'View previous releases';

  @override
  String get startup_recovering_title => 'Recovering database...';

  @override
  String get startup_recovering_body =>
      'Rolling back the interrupted transaction. This usually takes a few seconds.';

  @override
  String get startup_recoveryFailed_title => 'Recovery did not complete';

  @override
  String get startup_recoveryFailed_body =>
      'The database could not be rolled back automatically. Your data is still on disk; contact support before reinstalling so we can help you recover it.';

  @override
  String get startup_recoveryRequired_title => 'Database needs recovery';

  @override
  String get startup_recoveryRequired_body =>
      'A previous session was interrupted while writing to the database. Your data is still on disk; we just need to finish rolling back the cancelled change before the app can open.';

  @override
  String startup_recovery_sqliteCode(Object code) {
    return 'SQLite code $code';
  }

  @override
  String get startup_recovery_action => 'Recover database';

  @override
  String get startup_recovery_closeWithoutRecovering =>
      'Close without recovering';

  @override
  String get common_action_tryAgain => 'Try again';

  @override
  String get lock_screen_title => 'Submersion is locked';

  @override
  String get lock_screen_forgotPassword => 'Forgot password?';

  @override
  String get lock_incorrectPassword => 'Incorrect password. Try again.';

  @override
  String get startup_backup_semanticsLabel => 'Backing up';

  @override
  String get startup_backup_title => 'Backing up your data';

  @override
  String get startup_backup_body =>
      'We\'re saving a copy of your dive log before updating your database.';

  @override
  String get startup_backupFailed_title => 'Couldn\'t back up your data';

  @override
  String get startup_backupFailed_body =>
      'Your dive log hasn\'t changed, so we didn\'t update it. Free up space (or fix the issue) and try again.';

  @override
  String get startup_backupFailed_quit => 'Quit';

  @override
  String get startup_backupFailed_technicalDetails => 'Technical details';

  @override
  String get common_action_retry => 'Retry';

  @override
  String get startup_versionMismatch_title => 'Update Required';

  @override
  String startup_versionMismatch_body(
    Object databaseVersion,
    Object appVersion,
  ) {
    return 'Your dive data was saved by a newer version of Submersion (schema v$databaseVersion). This version only supports up to schema v$appVersion.';
  }

  @override
  String get startup_versionMismatch_instructions =>
      'Please update Submersion to the latest version. Your data is safe and has not been modified. If a backup was taken before the upgrade, it is in your Backups folder and can be restored after updating.';

  @override
  String get startup_versionMismatch_storeInstructions =>
      'This app was installed from an app store and is older than the version that created your data. Your data is safe and has not been modified. Update Submersion when the new version appears in the store, then reopen it.';

  @override
  String get startup_versionMismatch_download => 'Download Latest Version';

  @override
  String get startup_versionMismatch_manualLink =>
      'If that does not open a browser, visit:';

  @override
  String get universalImport_compare_downloaded => 'Downloaded';

  @override
  String get universalImport_compare_errorLoading => 'Error loading dive data';

  @override
  String get universalImport_compare_diveNotFound => 'Existing dive not found';

  @override
  String universalImport_compare_sameFields(Object fields) {
    return 'Same: $fields';
  }

  @override
  String get universalImport_compare_differences => 'DIFFERENCES';

  @override
  String get universalImport_compare_notRecorded => 'not recorded';

  @override
  String universalImport_compare_serial(Object serial) {
    return 'S/N: $serial';
  }

  @override
  String get universalImport_compare_skipSubtitle => 'Discard this download';

  @override
  String get universalImport_compare_importAsNewSubtitle =>
      'Save as separate dive';

  @override
  String get universalImport_compare_consolidateSubtitle =>
      'Add as 2nd computer reading';

  @override
  String get diveLog_tooltip_ndlOverMax => '>60 min';

  @override
  String diveLog_tooltip_interpolated(String value) {
    return '$value (interpolated)';
  }

  @override
  String get enum_profileMetric_ascentRate_short => 'Rate';

  @override
  String get enum_profileMetric_cns_short => 'CNS';

  @override
  String get enum_profileMetric_otu_short => 'OTU';

  @override
  String get diveLog_profileEditor_rangeOperations => 'Range Operations';

  @override
  String get diveLog_profileEditor_selectRangeHint =>
      'Select a range on the chart to enable operations';

  @override
  String get diveLog_profileEditor_depthPlusOneMeter => 'Depth +1m';

  @override
  String get diveLog_profileEditor_depthMinusOneMeter => 'Depth -1m';

  @override
  String get diveLog_profileEditor_timePlusFiveSeconds => 'Time +5s';

  @override
  String get diveLog_profileEditor_timeMinusFiveSeconds => 'Time -5s';

  @override
  String get diveLog_profileEditor_smoothing => 'Smoothing';

  @override
  String get diveLog_profileEditor_smoothLight => 'Light';

  @override
  String get diveLog_profileEditor_smoothMedium => 'Medium';

  @override
  String get diveLog_profileEditor_smoothHeavy => 'Heavy';

  @override
  String get diveLog_profileEditor_applyToAll => 'Apply to All';

  @override
  String get diveLog_profileEditor_applyToSelection => 'Apply to Selection';

  @override
  String get diveLog_profileEditor_outlierDetection => 'Outlier Detection';

  @override
  String get diveLog_profileEditor_detect => 'Detect';

  @override
  String get diveLog_profileEditor_removeAll => 'Remove All';

  @override
  String diveLog_profileEditor_outliersDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count potential outliers detected',
      one: '1 potential outlier detected',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_profileEditor_manualDrawing => 'Manual Drawing';

  @override
  String get diveLog_profileEditor_drawHint =>
      'Tap on the chart to place waypoints';

  @override
  String get diveLog_profileEditor_clearWaypoints => 'Clear';

  @override
  String get diveLog_profileEditor_generateProfile => 'Generate Profile';

  @override
  String get diveLog_profileEditor_trimMode => 'Trim Mode';

  @override
  String get diveLog_profileEditor_trimHint => 'Trim profile endpoints';

  @override
  String get diveLog_profileEditor_trimEnd => 'Trim End';

  @override
  String get diveLog_profileEditor_mode_smooth => 'Smooth';

  @override
  String get diveLog_profileEditor_title => 'Edit Profile';

  @override
  String get diveLog_profileEditor_discardBody =>
      'You have unsaved changes to this dive profile. Are you sure you want to discard them?';

  @override
  String get diveLog_profileEditor_saveTitle => 'Save profile?';

  @override
  String get diveLog_profileEditor_saveBody =>
      'This will save the edited profile as the primary profile for this dive. The original profile will be preserved and can be restored later.';

  @override
  String diveLog_profileEditor_saveFailed(String error) {
    return 'Failed to save profile: $error';
  }

  @override
  String diveLog_profileEditor_errorLoadingDive(String error) {
    return 'Error loading dive: $error';
  }

  @override
  String get diveLog_profileEditor_noProfileData => 'No profile data available';

  @override
  String get diveLog_profileEditor_undo => 'Undo';

  @override
  String get diveLog_profileEditor_mode_select => 'Select';

  @override
  String get diveLog_profileEditor_mode_outlier => 'Outlier';

  @override
  String get diveLog_profileEditor_mode_draw => 'Draw';

  @override
  String get diveLog_profileEditor_mode_trim => 'Trim';

  @override
  String diveLog_sources_sectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Data Sources',
      one: 'Data Source',
      zero: 'Data Source',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_badge_manual => 'Manual';

  @override
  String get diveLog_sources_badge_viewing => 'Viewing';

  @override
  String get diveLog_sources_badge_secondary => 'Secondary';

  @override
  String diveLog_sources_created(String date) {
    return 'Created $date';
  }

  @override
  String get diveLog_sources_detail_serial => 'Serial';

  @override
  String get diveLog_sources_detail_format => 'Format';

  @override
  String get diveLog_sources_detail_imported => 'Imported';

  @override
  String diveLog_detail_semantics_viewDiveComputer(String name) {
    return 'View dive computer $name';
  }

  @override
  String diveLog_detail_semantics_viewTrip(String name) {
    return 'View trip $name';
  }

  @override
  String diveLog_detail_semantics_viewDiveCenter(String name) {
    return 'View dive center $name';
  }

  @override
  String diveLog_detail_semantics_viewSpecies(String name) {
    return 'View species $name';
  }

  @override
  String diveLog_detail_semantics_viewCourse(String name) {
    return 'View course $name';
  }

  @override
  String diveLog_detail_serialNumber(String serial) {
    return 'S/N $serial';
  }

  @override
  String diveLog_detail_errorLoadingSignature(String error) {
    return 'Error loading signature: $error';
  }

  @override
  String get diveLog_profilePanel_selectDive =>
      'Select a dive to view its profile';

  @override
  String get diveLog_profilePanel_noProfileData =>
      'No profile data for this dive';

  @override
  String get settings_export_progress_divesCsv => 'Exporting dives to CSV...';

  @override
  String get settings_export_progress_sitesCsv => 'Exporting sites to CSV...';

  @override
  String get settings_export_progress_equipmentCsv =>
      'Exporting equipment to CSV...';

  @override
  String get settings_export_progress_pdf => 'Generating PDF logbook...';

  @override
  String get settings_export_progress_loadingSignatures =>
      'Loading signatures...';

  @override
  String get settings_export_progress_loadingCertifications =>
      'Loading certifications...';

  @override
  String get settings_export_progress_loadingFonts => 'Loading fonts...';

  @override
  String settings_export_progress_templatePdf(String template) {
    return 'Generating $template PDF...';
  }

  @override
  String get settings_export_progress_uddf => 'Generating UDDF file...';

  @override
  String get settings_export_progress_collectingData =>
      'Collecting all data...';

  @override
  String get settings_export_progress_excel => 'Generating Excel file...';

  @override
  String get settings_export_progress_buildingExcel =>
      'Building Excel workbook...';

  @override
  String get settings_export_progress_kml => 'Generating KML file...';

  @override
  String get settings_export_progress_buildingKml => 'Building KML file...';

  @override
  String get settings_export_progress_preparingExcel =>
      'Preparing Excel file...';

  @override
  String get settings_export_progress_preparingKml => 'Preparing KML file...';

  @override
  String get settings_export_progress_chooseLocation =>
      'Choose save location...';

  @override
  String get settings_export_progress_preparingDivesCsv =>
      'Preparing dives CSV...';

  @override
  String get settings_export_progress_preparingSitesCsv =>
      'Preparing sites CSV...';

  @override
  String get settings_export_progress_preparingEquipmentCsv =>
      'Preparing equipment CSV...';

  @override
  String get settings_export_progress_preparingUddf => 'Preparing UDDF file...';

  @override
  String get settings_export_progress_preparingPdf => 'Preparing PDF...';

  @override
  String get settings_export_progress_selectingBackup =>
      'Selecting backup file...';

  @override
  String get settings_export_progress_restoringBackup =>
      'Restoring from backup...';

  @override
  String get settings_export_empty_dives => 'No dives to export';

  @override
  String get settings_export_empty_sites => 'No sites to export';

  @override
  String get settings_export_empty_equipment => 'No equipment to export';

  @override
  String get settings_export_empty_data => 'No data to export';

  @override
  String get settings_export_empty_diveSites => 'No dive sites to export';

  @override
  String settings_export_saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String settings_export_backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String settings_export_restoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get settings_export_fileUnreadable => 'Could not access file';

  @override
  String get settings_export_notADbFile => 'Please select a .db backup file';

  @override
  String get settings_export_success_dives => 'Dives exported successfully';

  @override
  String get settings_export_success_sites => 'Sites exported successfully';

  @override
  String get settings_export_success_equipment =>
      'Equipment exported successfully';

  @override
  String get settings_export_success_pdf =>
      'PDF logbook generated successfully';

  @override
  String get settings_export_success_uddf => 'UDDF file generated successfully';

  @override
  String get settings_export_success_excel =>
      'Excel file exported successfully';

  @override
  String settings_export_success_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'KML file exported successfully ($count sites without coordinates skipped)',
      one:
          'KML file exported successfully (1 site without coordinates skipped)',
      zero: 'KML file exported successfully',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_excel => 'Excel file saved successfully';

  @override
  String settings_export_saved_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'KML file saved successfully ($count sites without coordinates skipped)',
      one: 'KML file saved successfully (1 site without coordinates skipped)',
      zero: 'KML file saved successfully',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_divesCsv => 'Dives CSV saved successfully';

  @override
  String get settings_export_saved_sitesCsv => 'Sites CSV saved successfully';

  @override
  String get settings_export_saved_equipmentCsv =>
      'Equipment CSV saved successfully';

  @override
  String get settings_export_saved_uddf => 'UDDF file saved successfully';

  @override
  String get settings_export_saved_pdf => 'PDF saved successfully';

  @override
  String get settings_export_saved_backup => 'Backup saved successfully';

  @override
  String get settings_export_restoreComplete => 'Restore complete';

  @override
  String get settings_export_cancelled_save => 'Save cancelled';

  @override
  String get settings_export_cancelled_backup => 'Backup cancelled';

  @override
  String get settings_export_cancelled_restore => 'Restore cancelled';

  @override
  String get settings_export_pdfDocumentTitle => 'Dive Logbook';

  @override
  String get settings_export_saveBackupDialogTitle => 'Save Backup';

  @override
  String backup_operation_created(String size) {
    return 'Backup created: $size';
  }

  @override
  String backup_operation_backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get backup_operation_restoring => 'Restoring backup...';

  @override
  String backup_operation_restoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get backup_operation_deleting => 'Deleting backup...';

  @override
  String get backup_operation_deleted => 'Backup deleted';

  @override
  String backup_operation_deleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get backup_operation_exporting => 'Exporting backup...';

  @override
  String backup_operation_exported(String size) {
    return 'Backup exported: $size';
  }

  @override
  String backup_operation_exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get backup_operation_preparingShare =>
      'Preparing backup for sharing...';

  @override
  String get backup_operation_shareReady => 'Backup ready for sharing';

  @override
  String backup_operation_upgrading(int step, int total) {
    return 'Upgrading database (step $step of $total)...';
  }

  @override
  String backup_restore_dialog_counts(int diveCount, int siteCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount dives',
      one: '1 dive',
    );
    String _temp1 = intl.Intl.pluralLogic(
      siteCount,
      locale: localeName,
      other: '$siteCount sites',
      one: '1 site',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get backup_restore_preMigration_title =>
      'Restore pre-migration backup';

  @override
  String get backup_restore_preMigration_unknownVersion => 'unknown version';

  @override
  String get backup_restore_preMigration_restoreAnyway => 'Restore anyway';

  @override
  String backup_restore_preMigration_incompleteMetadata(
    String timestamp,
    String appVersion,
  ) {
    return 'This backup was made on $timestamp by app $appVersion, but its database migration metadata is incomplete.\n\nThe app cannot verify whether restoring this backup is safe, so restore is disabled.';
  }

  @override
  String backup_restore_preMigration_newerApp(
    String timestamp,
    String appVersion,
    int fromVersion,
  ) {
    return 'This backup is newer than your app. Install a newer app version to restore it.\n\nBackup made on $timestamp by app $appVersion (database v$fromVersion).';
  }

  @override
  String backup_restore_preMigration_safe(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
  ) {
    return 'This backup was made on $timestamp by app $appVersion, just before upgrading the database from v$fromVersion to v$toVersion.\n\nYour app\'s database schema matches this backup, so restore is safe.';
  }

  @override
  String backup_restore_preMigration_warning(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
    int currentVersion,
  ) {
    return 'This backup was made on $timestamp by app $appVersion, just before upgrading the database from v$fromVersion to v$toVersion.\n\nYou are running a newer app (database v$currentVersion).\n\nRestoring now will re-run the v$fromVersion to v$toVersion database upgrade on your restored data, the same upgrade that was about to run originally. If that upgrade caused the problem, you will hit the same issue again.\n\nTo restore safely: install app $appVersion or earlier, then restore this backup from that older app.';
  }

  @override
  String get settings_cloudSync_progress_preparing => 'Preparing sync...';

  @override
  String get settings_cloudSync_progress_pulling => 'Pulling changes...';

  @override
  String get settings_cloudSync_progress_publishing => 'Publishing changes...';

  @override
  String settings_cloudSync_progress_uploadingLibrary(int uploaded, int total) {
    return 'Uploading library ($uploaded of $total)';
  }

  @override
  String get settings_cloudSync_result_noProvider =>
      'No cloud provider configured';

  @override
  String get settings_cloudSync_result_notAuthenticated =>
      'Not authenticated with cloud provider';

  @override
  String get settings_cloudSync_result_timedOut => 'Sync timed out';

  @override
  String get settings_cloudSync_result_epochMarkerUnreadable =>
      'Could not read the library epoch marker';

  @override
  String get settings_cloudSync_result_epochMarkerEncrypted =>
      'The library epoch marker is encrypted';

  @override
  String get settings_cloudSync_result_libraryReplacedRemotely =>
      'The cloud library was replaced from a backup';

  @override
  String get settings_cloudSync_result_noReplacementToRebuild =>
      'No library replacement to rebuild from';

  @override
  String get settings_cloudSync_result_rebuiltFromThisDevice =>
      'Rebuilt this backend from this device’s library';

  @override
  String settings_cloudSync_result_rebuildFailed(String error) {
    return 'Rebuild failed: $error';
  }

  @override
  String get settings_cloudSync_result_libraryReplaced => 'Library replaced';

  @override
  String settings_cloudSync_result_libraryReplaceFailed(String error) {
    return 'Library replace failed: $error';
  }

  @override
  String get settings_cloudSync_result_noReplacementMarker =>
      'No library replacement marker found';

  @override
  String get settings_cloudSync_result_adoptedRestoredLibrary =>
      'Adopted the restored library';

  @override
  String settings_cloudSync_result_adoptFailed(String error) {
    return 'Failed to adopt the restored library: $error';
  }

  @override
  String get settings_cloudSync_result_previousLibraryUnreadable =>
      'The previous library could not be read; re-established this backend from this device\'s library.';

  @override
  String get settings_cloudSync_result_replacementStillUploading =>
      'The replaced library is still uploading. Try again shortly.';

  @override
  String settings_cloudSync_result_recordsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records failed to apply',
      one: '1 record failed to apply',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_result_adoptedFreshIdentity =>
      'Another device was syncing with this device\'s identity. This device adopted a new identity and merged the cloud data.';

  @override
  String settings_cloudSync_launchCheck_unavailable(String provider) {
    return '$provider is not available on this device';
  }

  @override
  String settings_cloudSync_launchCheck_notSignedIn(String provider) {
    return 'Not signed in to $provider';
  }

  @override
  String settings_cloudSync_launchCheck_localChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count local changes to upload',
      one: '1 local change to upload',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_launchCheck_noRemoteData =>
      'No sync data found in cloud';

  @override
  String get settings_cloudSync_launchCheck_cloudDataAvailable =>
      'Cloud data available';

  @override
  String get settings_cloudSync_launchCheck_updatesAvailable =>
      'Updates available from cloud';

  @override
  String get settings_cloudSync_launchCheck_upToDate =>
      'Everything is up to date';

  @override
  String settings_cloudSync_launchCheck_failed(String error) {
    return 'Sync check failed: $error';
  }

  @override
  String get diveLog_detail_viewMap => 'Map';

  @override
  String get diveLog_detail_view3d => '3D';

  @override
  String get setup_sync_icloudUnavailable =>
      'iCloud is not available on this device';

  @override
  String get media_info_title => 'Media info';

  @override
  String get media_info_fileSection => 'File';

  @override
  String get media_info_filename => 'Filename';

  @override
  String get media_info_type => 'Type';

  @override
  String get media_info_dimensions => 'Dimensions';

  @override
  String get media_info_size => 'Size';

  @override
  String get media_info_taken => 'Taken';

  @override
  String get media_info_coordinates => 'Coordinates';

  @override
  String get media_info_unknown => 'Unknown';

  @override
  String get media_info_originSection => 'Origin';

  @override
  String get media_info_source => 'Source';

  @override
  String get media_info_reference => 'Reference';

  @override
  String get media_info_linkedOn => 'Linked on';

  @override
  String get media_info_thisDevice => 'This device';

  @override
  String get media_info_otherDevice => 'Another device';

  @override
  String get media_info_status => 'Status';

  @override
  String get media_info_statusFound => 'Found on this device';

  @override
  String get media_info_statusMissing => 'Missing from this device';

  @override
  String get media_info_statusUnchecked => 'Not checked yet';

  @override
  String media_info_lastChecked(String date) {
    return 'Last checked $date';
  }

  @override
  String get media_timeInDive_label => 'Time in dive';

  @override
  String get media_timeInDive_unknown => 'Time in dive unknown';

  @override
  String get media_timeInDive_setAction => 'Set time in dive';

  @override
  String media_timeInDive_manual(String time) {
    return '$time (set manually)';
  }

  @override
  String get media_timeInDive_fieldLabel => 'Time from dive start';

  @override
  String get media_timeInDive_fieldHint => 'mm:ss';

  @override
  String media_timeInDive_range(String max) {
    return 'Between 0:00 and $max';
  }

  @override
  String media_timeInDive_invalid(String max) {
    return 'Enter a time between 0:00 and $max';
  }

  @override
  String get media_timeInDive_save => 'Save';

  @override
  String get media_timeInDive_cancel => 'Cancel';

  @override
  String get media_timeInDive_reset => 'Reset to automatic';

  @override
  String get media_info_backupSection => 'Backup';

  @override
  String get media_info_store => 'Cloud store';

  @override
  String get media_info_storeNotConnected => 'No cloud store connected';

  @override
  String get media_info_notEligible => 'This source is not eligible for backup';

  @override
  String get media_info_backupFull => 'Original uploaded';

  @override
  String get media_info_backupThumbOnly => 'Thumbnail only, original not sent';

  @override
  String get media_info_backupRenditionOnly => 'Compressed version uploaded';

  @override
  String get media_info_backupNone => 'Not backed up';

  @override
  String media_info_uploadedOn(String date) {
    return 'Uploaded $date';
  }

  @override
  String get media_info_queuePending => 'Waiting to upload';

  @override
  String get media_info_queueTransferring => 'Uploading now';

  @override
  String media_info_queueFailed(Object error) {
    return 'Upload failed: $error';
  }

  @override
  String get media_info_servingSection => 'Serving now';

  @override
  String get media_info_servingUnobserved => 'Not loaded yet';

  @override
  String get media_info_servingFailed => 'Could not be loaded';

  @override
  String get media_info_servedLocalDisk => 'Local file on this device';

  @override
  String get media_info_servedGallery => 'Photo library';

  @override
  String get media_info_servedStoreCache => 'Local cache, from the cloud store';

  @override
  String get media_info_servedStoreNetwork => 'Downloaded from the cloud store';

  @override
  String get media_info_servedNetworkUrl => 'Streaming from a URL';

  @override
  String get media_info_servedConnectorCache =>
      'Local cache, from the connected service';

  @override
  String get media_info_servedConnectorNetwork =>
      'Downloaded from the connected service';

  @override
  String get media_info_servedEmbedded => 'Stored inside this logbook';

  @override
  String get media_info_servingFallbackNote =>
      'The original source could not be reached, so the cloud store served this.';

  @override
  String get media_info_servingTierThumbnail => 'Thumbnail';

  @override
  String get media_info_servingTierRendition => 'Compressed version';

  @override
  String get media_info_typePhoto => 'Photo';

  @override
  String get media_info_typeVideo => 'Video';

  @override
  String get media_info_typeDocument => 'Document';

  @override
  String get media_info_typeSignature => 'Signature';

  @override
  String get media_info_actionCheckNow => 'Check now';

  @override
  String get media_info_actionLocate => 'Locate file...';

  @override
  String get media_info_actionBackUpNow => 'Back up now';

  @override
  String get media_info_actionRetryUpload => 'Retry upload';

  @override
  String get media_info_actionReveal => 'Show in file manager';

  @override
  String get media_info_actionCopyPath => 'Copy reference';

  @override
  String get media_info_referenceCopied => 'Reference copied';

  @override
  String get media_info_checkFound => 'Source found';

  @override
  String get media_info_checkMissing => 'Source is missing';

  @override
  String get media_info_checkUnavailable => 'Could not check right now';

  @override
  String get media_info_backupQueued => 'Queued for upload';

  @override
  String get enum_profileMetric_o2CellMv => 'O2 Cells';

  @override
  String get enum_profileMetric_o2CellMv_short => 'Cells';

  @override
  String get diveLog_o2CellSpread_label => 'O2 Cell Spread';

  @override
  String get media_status_broken => 'Missing and not backed up';

  @override
  String get media_servedFrom_localDisk => 'On this device';

  @override
  String get media_servedFrom_platformGallery => 'Photo library';

  @override
  String get media_servedFrom_storeCache => 'Cloud store, cached here';

  @override
  String get media_servedFrom_storeNetwork => 'Cloud store';

  @override
  String get media_servedFrom_networkUrl => 'Web link';

  @override
  String get media_servedFrom_connectorCache =>
      'Connected service, cached here';

  @override
  String get media_servedFrom_connectorNetwork => 'Connected service';

  @override
  String get media_servedFrom_embedded => 'Stored in this logbook';

  @override
  String get settings_media_provenanceBadges =>
      'Show source badges on thumbnails';

  @override
  String get settings_media_provenanceBadgesSubtitle =>
      'A small glyph showing where each item is served from. Problem badges always show.';

  @override
  String get media_status_transferFailed => 'Upload failed';

  @override
  String get media_status_transferring => 'Uploading';

  @override
  String get media_status_queued => 'Waiting to upload';

  @override
  String get media_status_cloudOnly => 'Stored in the cloud only';

  @override
  String get media_status_notBackedUp => 'Not backed up';

  @override
  String get media_tile_infoMenuItem => 'Media info';

  @override
  String get diveImport_healthkit_accessGrantedHint =>
      'Apple Health never tells apps whether read access was granted. If no dives turn up, open Health, then Sharing, Apps, Submersion, and turn on Workouts, Underwater Depth, Water Temperature, and Heart Rate.';

  @override
  String get diveImport_healthkit_foundNoDivesHint =>
      'No underwater diving workouts in this range. Check that the dates cover the dive, and that Health, Sharing, Apps, Submersion has Workouts and Underwater Depth turned on.';

  @override
  String get settings_dataSources_appleHealth_dataTypeDepth =>
      'Underwater Depth - depth samples recorded during dives';

  @override
  String get settings_dataSources_appleHealth_dataTypeWaterTemp =>
      'Water Temperature - water temperature samples recorded during dives';

  @override
  String get settings_dataSources_appleHealth_permissionManagedInHealth =>
      'HealthKit access is managed in the Health app';

  @override
  String get settings_dataSources_appleHealth_permissionUnsupported =>
      'HealthKit is not available on this device';
}
