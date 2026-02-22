// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get accessibility_dialog_keyboardShortcutsTitle =>
      'Tastenkombinationen';

  @override
  String get accessibility_keyLabel_backspace => 'Ruecktaste';

  @override
  String get accessibility_keyLabel_delete => 'Entf';

  @override
  String get accessibility_keyLabel_down => 'Runter';

  @override
  String get accessibility_keyLabel_enter => 'Eingabe';

  @override
  String get accessibility_keyLabel_esc => 'Esc';

  @override
  String get accessibility_keyLabel_left => 'Links';

  @override
  String get accessibility_keyLabel_right => 'Rechts';

  @override
  String get accessibility_keyLabel_up => 'Hoch';

  @override
  String accessibility_label_chartSummary(
    Object chartType,
    Object description,
  ) {
    return '$chartType-Diagramm. $description';
  }

  @override
  String get accessibility_label_createNewItem => 'Neues Element erstellen';

  @override
  String get accessibility_label_hideList => 'Liste ausblenden';

  @override
  String get accessibility_label_hideMapView => 'Kartenansicht ausblenden';

  @override
  String accessibility_label_listPane(Object title) {
    return '$title Listenbereich';
  }

  @override
  String accessibility_label_mapPane(Object title) {
    return '$title Kartenbereich';
  }

  @override
  String accessibility_label_mapViewTitle(Object title) {
    return '$title Kartenansicht';
  }

  @override
  String get accessibility_label_showList => 'Liste anzeigen';

  @override
  String get accessibility_label_showMapView => 'Kartenansicht anzeigen';

  @override
  String get accessibility_label_viewDetails => 'Details anzeigen';

  @override
  String get accessibility_modifierKey_alt => 'Alt+';

  @override
  String get accessibility_modifierKey_cmd => 'Cmd+';

  @override
  String get accessibility_modifierKey_ctrl => 'Strg+';

  @override
  String get accessibility_modifierKey_option => 'Option+';

  @override
  String get accessibility_modifierKey_shift => 'Umschalt+';

  @override
  String get accessibility_modifierKey_super => 'Super+';

  @override
  String get accessibility_shortcutCategory_editing => 'Bearbeitung';

  @override
  String get accessibility_shortcutCategory_general => 'Allgemein';

  @override
  String get accessibility_shortcutCategory_help => 'Hilfe';

  @override
  String get accessibility_shortcutCategory_navigation => 'Navigation';

  @override
  String get accessibility_shortcutCategory_search => 'Suche';

  @override
  String get accessibility_shortcut_closeCancel => 'Schliessen / Abbrechen';

  @override
  String get accessibility_shortcut_goBack => 'Zurueck';

  @override
  String get accessibility_shortcut_goToDives => 'Zu Tauchgaengen';

  @override
  String get accessibility_shortcut_goToEquipment => 'Zur Ausruestung';

  @override
  String get accessibility_shortcut_goToSettings => 'Zu Einstellungen';

  @override
  String get accessibility_shortcut_goToSites => 'Zu Tauchplaetzen';

  @override
  String get accessibility_shortcut_goToStatistics => 'Zu Statistiken';

  @override
  String get accessibility_shortcut_keyboardShortcuts => 'Tastenkombinationen';

  @override
  String get accessibility_shortcut_newDive => 'Neuer Tauchgang';

  @override
  String get accessibility_shortcut_openSettings => 'Einstellungen oeffnen';

  @override
  String get accessibility_shortcut_searchDives => 'Tauchgaenge suchen';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return 'Sortieren nach $displayName, derzeit ausgewaehlt';
  }

  @override
  String accessibility_sort_unselectedLabel(Object displayName) {
    return 'Sortieren nach $displayName';
  }

  @override
  String get backup_appBar_title => 'Sicherung und Wiederherstellung';

  @override
  String get backup_backingUp => 'Sicherung wird erstellt...';

  @override
  String get backup_backupNow => 'Jetzt Sichern';

  @override
  String get backup_cloud_enabled => 'Cloud-Sicherung';

  @override
  String get backup_cloud_enabled_subtitle =>
      'Sicherungen in den Cloud-Speicher hochladen';

  @override
  String get backup_delete_dialog_cancel => 'Abbrechen';

  @override
  String get backup_delete_dialog_content =>
      'Diese Sicherung wird dauerhaft gelöscht. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get backup_delete_dialog_delete => 'Löschen';

  @override
  String get backup_delete_dialog_title => 'Sicherung Löschen';

  @override
  String get backup_frequency_daily => 'Täglich';

  @override
  String get backup_frequency_monthly => 'Monatlich';

  @override
  String get backup_frequency_weekly => 'Wöchentlich';

  @override
  String get backup_history_action_delete => 'Löschen';

  @override
  String get backup_history_action_restore => 'Wiederherstellen';

  @override
  String get backup_history_empty => 'Keine Sicherungen vorhanden';

  @override
  String backup_history_error(Object error) {
    return 'Fehler beim Laden des Verlaufs: $error';
  }

  @override
  String get backup_restore_dialog_cancel => 'Abbrechen';

  @override
  String get backup_restore_dialog_restore => 'Wiederherstellen';

  @override
  String get backup_restore_dialog_safetyNote =>
      'Eine Sicherheitskopie Ihrer aktuellen Daten wird automatisch vor der Wiederherstellung erstellt.';

  @override
  String get backup_restore_dialog_title => 'Sicherung Wiederherstellen';

  @override
  String get backup_restore_dialog_warning =>
      'Dies ersetzt ALLE aktuellen Daten durch die Sicherungsdaten. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get backup_schedule_enabled => 'Automatische Sicherungen';

  @override
  String get backup_schedule_enabled_subtitle => 'Daten nach Zeitplan sichern';

  @override
  String get backup_schedule_frequency => 'Häufigkeit';

  @override
  String get backup_schedule_retention => 'Sicherungen behalten';

  @override
  String get backup_schedule_retention_subtitle =>
      'Ältere Sicherungen werden automatisch entfernt';

  @override
  String get backup_section_cloud => 'Cloud';

  @override
  String get backup_section_history => 'Verlauf';

  @override
  String get backup_section_schedule => 'Zeitplan';

  @override
  String get backup_status_disabled => 'Automatische Sicherungen Deaktiviert';

  @override
  String backup_status_lastBackup(String time) {
    return 'Letzte Sicherung: $time';
  }

  @override
  String get backup_status_neverBackedUp => 'Nie Gesichert';

  @override
  String get backup_status_noBackupsYet =>
      'Erstellen Sie Ihre erste Sicherung, um Ihre Daten zu schützen';

  @override
  String get backup_status_overdue => 'Sicherung Überfällig';

  @override
  String get backup_status_upToDate => 'Sicherungen Aktuell';

  @override
  String backup_time_daysAgo(int count) {
    return 'vor ${count}T';
  }

  @override
  String backup_time_hoursAgo(int count) {
    return 'vor ${count}Std';
  }

  @override
  String get backup_time_justNow => 'Gerade eben';

  @override
  String backup_time_minutesAgo(int count) {
    return 'vor ${count}Min';
  }

  @override
  String get buddies_action_add => 'Tauchpartner hinzufügen';

  @override
  String get buddies_action_addFirst =>
      'Fügen Sie Ihren ersten Tauchpartner hinzu';

  @override
  String get buddies_action_addTooltip => 'Neuen Tauchpartner hinzufügen';

  @override
  String get buddies_action_clearSearch => 'Suche löschen';

  @override
  String get buddies_action_edit => 'Tauchpartner bearbeiten';

  @override
  String get buddies_action_importFromContacts => 'Aus Kontakten importieren';

  @override
  String get buddies_action_moreOptions => 'Weitere Optionen';

  @override
  String get buddies_action_retry => 'Wiederholen';

  @override
  String get buddies_action_search => 'Tauchpartner suchen';

  @override
  String get buddies_action_shareDives => 'Tauchgänge teilen';

  @override
  String get buddies_action_sort => 'Sortieren';

  @override
  String get buddies_action_sortTitle => 'Tauchpartner sortieren';

  @override
  String get buddies_action_update => 'Tauchpartner aktualisieren';

  @override
  String buddies_action_viewAll(Object count) {
    return 'Alle anzeigen ($count)';
  }

  @override
  String buddies_detail_error(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get buddies_detail_noDivesTogether =>
      'Noch keine gemeinsamen Tauchgänge';

  @override
  String get buddies_detail_notFound => 'Tauchpartner nicht gefunden';

  @override
  String buddies_dialog_deleteMessage(Object name) {
    return 'Möchten Sie $name wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get buddies_dialog_deleteTitle => 'Tauchpartner löschen?';

  @override
  String get buddies_dialog_discard => 'Verwerfen';

  @override
  String get buddies_dialog_discardMessage =>
      'Sie haben nicht gespeicherte Änderungen. Möchten Sie diese wirklich verwerfen?';

  @override
  String get buddies_dialog_discardTitle => 'Änderungen verwerfen?';

  @override
  String get buddies_dialog_keepEditing => 'Weiter bearbeiten';

  @override
  String get buddies_empty_subtitle =>
      'Fügen Sie Ihren ersten Tauchpartner hinzu, um zu beginnen';

  @override
  String get buddies_empty_title => 'Noch keine Tauchpartner';

  @override
  String buddies_error_loading(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get buddies_error_unableToLoadDives =>
      'Tauchgänge können nicht geladen werden';

  @override
  String get buddies_error_unableToLoadStats =>
      'Statistiken können nicht geladen werden';

  @override
  String get buddies_field_certificationAgency => 'Zertifizierungsorganisation';

  @override
  String get buddies_field_certificationLevel => 'Zertifizierungsstufe';

  @override
  String get buddies_field_email => 'E-Mail';

  @override
  String get buddies_field_emailHint => 'email@beispiel.de';

  @override
  String get buddies_field_nameHint => 'Tauchpartnername eingeben';

  @override
  String get buddies_field_nameRequired => 'Name *';

  @override
  String get buddies_field_notes => 'Notizen';

  @override
  String get buddies_field_notesHint =>
      'Notizen zu diesem Tauchpartner hinzufügen...';

  @override
  String get buddies_field_phone => 'Telefon';

  @override
  String get buddies_field_phoneHint => '+49 (123) 456-7890';

  @override
  String get buddies_label_agency => 'Organisation';

  @override
  String buddies_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge',
      one: '1 Tauchgang',
    );
    return '$_temp0';
  }

  @override
  String get buddies_label_level => 'Stufe';

  @override
  String get buddies_label_notSpecified => 'Nicht angegeben';

  @override
  String get buddies_label_photoComingSoon => 'Fotounterstützung kommt in v2.0';

  @override
  String get buddies_message_added => 'Tauchpartner erfolgreich hinzugefügt';

  @override
  String get buddies_message_contactImportUnavailable =>
      'Kontaktimport ist auf dieser Plattform nicht verfügbar';

  @override
  String get buddies_message_contactLoadFailed =>
      'Kontakte konnten nicht geladen werden';

  @override
  String get buddies_message_contactPermissionRequired =>
      'Kontaktberechtigung ist erforderlich, um Tauchpartner zu importieren';

  @override
  String get buddies_message_deleted => 'Tauchpartner gelöscht';

  @override
  String buddies_message_errorImportingContact(Object error) {
    return 'Fehler beim Importieren des Kontakts: $error';
  }

  @override
  String buddies_message_errorLoading(Object error) {
    return 'Fehler beim Laden des Tauchpartners: $error';
  }

  @override
  String buddies_message_errorSaving(Object error) {
    return 'Fehler beim Speichern des Tauchpartners: $error';
  }

  @override
  String buddies_message_exportFailed(Object error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get buddies_message_noDivesFound =>
      'Keine Tauchgänge zum Exportieren gefunden';

  @override
  String get buddies_message_noDivesToShare =>
      'Keine Tauchgänge mit diesem Tauchpartner zu teilen';

  @override
  String get buddies_message_preparingExport => 'Export wird vorbereitet...';

  @override
  String get buddies_message_updated => 'Tauchpartner erfolgreich aktualisiert';

  @override
  String get buddies_picker_add => 'Hinzufügen';

  @override
  String get buddies_picker_addNew => 'Neuen Tauchpartner hinzufügen';

  @override
  String get buddies_picker_done => 'Fertig';

  @override
  String get buddies_picker_noBuddiesFound => 'Keine Tauchpartner gefunden';

  @override
  String get buddies_picker_noBuddiesYet => 'Noch keine Tauchpartner';

  @override
  String get buddies_picker_noneSelected => 'Keine Tauchpartner ausgewählt';

  @override
  String get buddies_picker_searchHint => 'Tauchpartner suchen...';

  @override
  String get buddies_picker_selectBuddies => 'Tauchpartner auswählen';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Rolle für $name auswählen';
  }

  @override
  String get buddies_picker_tapToAdd =>
      'Tippen Sie auf \'Hinzufügen\', um Tauchpartner auszuwählen';

  @override
  String get buddies_search_hint => 'Suche nach Name, E-Mail oder Telefon';

  @override
  String buddies_search_noResults(Object query) {
    return 'Keine Tauchpartner für \"$query\" gefunden';
  }

  @override
  String get buddies_section_certification => 'Zertifizierung';

  @override
  String get buddies_section_contact => 'Kontakt';

  @override
  String get buddies_section_diveStatistics => 'Tauchstatistiken';

  @override
  String get buddies_section_notes => 'Notizen';

  @override
  String get buddies_section_sharedDives => 'Gemeinsame Tauchgänge';

  @override
  String get buddies_stat_divesTogether => 'Gemeinsame Tauchgänge';

  @override
  String get buddies_stat_favoriteSite => 'Lieblingsplatz';

  @override
  String get buddies_stat_firstDive => 'Erster Tauchgang';

  @override
  String get buddies_stat_lastDive => 'Letzter Tauchgang';

  @override
  String get buddies_summary_overview => 'Übersicht';

  @override
  String get buddies_summary_quickActions => 'Schnellaktionen';

  @override
  String get buddies_summary_recentBuddies => 'Aktuelle Tauchpartner';

  @override
  String get buddies_summary_selectHint =>
      'Wählen Sie einen Tauchpartner aus der Liste, um Details anzuzeigen';

  @override
  String get buddies_summary_title => 'Tauchpartner';

  @override
  String get buddies_summary_totalBuddies => 'Tauchpartner gesamt';

  @override
  String get buddies_summary_withCertification => 'Mit Zertifizierung';

  @override
  String get buddies_title => 'Tauchpartner';

  @override
  String get buddies_title_add => 'Tauchpartner hinzufügen';

  @override
  String get buddies_title_edit => 'Tauchpartner bearbeiten';

  @override
  String get buddies_title_singular => 'Tauchpartner';

  @override
  String get buddies_validation_emailInvalid =>
      'Bitte geben Sie eine gültige E-Mail-Adresse ein';

  @override
  String get buddies_validation_nameRequired =>
      'Bitte geben Sie einen Namen ein';

  @override
  String get certifications_appBar_addCertification =>
      'Zertifizierung hinzufuegen';

  @override
  String get certifications_appBar_certificationWallet =>
      'Zertifizierungskarten';

  @override
  String get certifications_appBar_editCertification =>
      'Zertifizierung bearbeiten';

  @override
  String get certifications_appBar_title => 'Zertifizierungen';

  @override
  String get certifications_detail_action_delete => 'Loeschen';

  @override
  String get certifications_detail_appBar_title => 'Zertifizierung';

  @override
  String get certifications_detail_courseCompleted => 'Abgeschlossen';

  @override
  String get certifications_detail_courseInProgress => 'In Bearbeitung';

  @override
  String get certifications_detail_dialog_cancel => 'Abbrechen';

  @override
  String get certifications_detail_dialog_deleteConfirm => 'Loeschen';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return 'Sind Sie sicher, dass Sie \"$name\" loeschen moechten?';
  }

  @override
  String get certifications_detail_dialog_deleteTitle =>
      'Zertifizierung loeschen?';

  @override
  String get certifications_detail_label_agency => 'Verband';

  @override
  String get certifications_detail_label_cardNumber => 'Kartennummer';

  @override
  String get certifications_detail_label_expiryDate => 'Ablaufdatum';

  @override
  String get certifications_detail_label_instructorName => 'Name';

  @override
  String get certifications_detail_label_instructorNumber => 'Instructor-Nr.';

  @override
  String get certifications_detail_label_issueDate => 'Ausstellungsdatum';

  @override
  String get certifications_detail_label_level => 'Stufe';

  @override
  String get certifications_detail_label_type => 'Typ';

  @override
  String get certifications_detail_label_validity => 'Gueltigkeit';

  @override
  String get certifications_detail_noExpiration => 'Kein Ablaufdatum';

  @override
  String get certifications_detail_notFound => 'Zertifizierung nicht gefunden';

  @override
  String get certifications_detail_photoLabel_back => 'Rueckseite';

  @override
  String get certifications_detail_photoLabel_front => 'Vorderseite';

  @override
  String certifications_detail_photo_fullscreenTitle(
    Object label,
    Object name,
  ) {
    return '$label - $name';
  }

  @override
  String get certifications_detail_photo_unableToLoad =>
      'Bild konnte nicht geladen werden';

  @override
  String get certifications_detail_sectionTitle_cardPhotos => 'Kartenfotos';

  @override
  String get certifications_detail_sectionTitle_dates => 'Daten';

  @override
  String get certifications_detail_sectionTitle_details =>
      'Zertifizierungsdetails';

  @override
  String get certifications_detail_sectionTitle_instructor => 'Instructor';

  @override
  String get certifications_detail_sectionTitle_notes => 'Notizen';

  @override
  String get certifications_detail_sectionTitle_trainingCourse =>
      'Ausbildungskurs';

  @override
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  ) {
    return '$label-Foto von $name. Tippen Sie, um es im Vollbild anzuzeigen';
  }

  @override
  String get certifications_detail_snackBar_deleted =>
      'Zertifizierung geloescht';

  @override
  String get certifications_detail_status_expired =>
      'Diese Zertifizierung ist abgelaufen';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return 'Abgelaufen am $date';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return 'Laeuft in $days Tagen ab';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return 'Laeuft ab am $date';
  }

  @override
  String get certifications_detail_tooltip_edit => 'Zertifizierung bearbeiten';

  @override
  String get certifications_detail_tooltip_editShort => 'Bearbeiten';

  @override
  String get certifications_detail_tooltip_moreOptions => 'Weitere Optionen';

  @override
  String get certifications_ecardStack_empty_subtitle =>
      'Fuegen Sie Ihre erste Zertifizierung hinzu, um sie hier zu sehen';

  @override
  String get certifications_ecardStack_empty_title =>
      'Noch keine Zertifizierungen';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Zertifiziert von $agency';
  }

  @override
  String get certifications_ecard_label_instructor => 'INSTRUCTOR';

  @override
  String get certifications_ecard_label_issued => 'AUSGESTELLT';

  @override
  String get certifications_ecard_statusBadge_expired => 'ABGELAUFEN';

  @override
  String get certifications_ecard_statusBadge_expiring => 'LAEUFT AB';

  @override
  String get certifications_edit_appBar_add => 'Zertifizierung hinzufuegen';

  @override
  String get certifications_edit_appBar_edit => 'Zertifizierung bearbeiten';

  @override
  String get certifications_edit_button_add => 'Zertifizierung hinzufuegen';

  @override
  String get certifications_edit_button_cancel => 'Abbrechen';

  @override
  String get certifications_edit_button_save => 'Speichern';

  @override
  String get certifications_edit_button_update =>
      'Zertifizierung aktualisieren';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return '$label loeschen';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect =>
      'Zum Auswaehlen tippen';

  @override
  String get certifications_edit_dialog_discard => 'Verwerfen';

  @override
  String get certifications_edit_dialog_discardContent =>
      'Sie haben ungespeicherte Aenderungen. Sind Sie sicher, dass Sie die Seite verlassen moechten?';

  @override
  String get certifications_edit_dialog_discardTitle =>
      'Aenderungen verwerfen?';

  @override
  String get certifications_edit_dialog_keepEditing => 'Weiter bearbeiten';

  @override
  String get certifications_edit_help_expiryDate =>
      'Leer lassen fuer Zertifizierungen ohne Ablaufdatum';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Kartennummer der Zertifizierung eingeben';

  @override
  String get certifications_edit_hint_certificationName =>
      'z. B. Open Water Diver';

  @override
  String get certifications_edit_hint_instructorName =>
      'Name des zertifizierenden Instructors';

  @override
  String get certifications_edit_hint_instructorNumber =>
      'Instructor-Zertifizierungsnummer';

  @override
  String get certifications_edit_hint_notes => 'Zusaetzliche Notizen';

  @override
  String get certifications_edit_label_agency => 'Verband *';

  @override
  String get certifications_edit_label_cardNumber => 'Kartennummer';

  @override
  String get certifications_edit_label_certificationName =>
      'Zertifizierungsname *';

  @override
  String get certifications_edit_label_expiryDate => 'Ablaufdatum';

  @override
  String get certifications_edit_label_instructorName => 'Instructor-Name';

  @override
  String get certifications_edit_label_instructorNumber => 'Instructor-Nummer';

  @override
  String get certifications_edit_label_issueDate => 'Ausstellungsdatum';

  @override
  String get certifications_edit_label_level => 'Stufe';

  @override
  String get certifications_edit_label_notes => 'Notizen';

  @override
  String get certifications_edit_level_notSpecified => 'Nicht angegeben';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return '$label-Foto hinzufuegen. Tippen Sie zum Auswaehlen';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return '$label-Foto angehaengt. Tippen Sie zum Aendern';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery =>
      'Aus Galerie auswaehlen';

  @override
  String certifications_edit_photo_removeTooltip(Object label) {
    return '$label-Foto entfernen';
  }

  @override
  String get certifications_edit_photo_takePhoto => 'Foto aufnehmen';

  @override
  String get certifications_edit_sectionTitle_cardPhotos => 'Kartenfotos';

  @override
  String get certifications_edit_sectionTitle_dates => 'Daten';

  @override
  String get certifications_edit_sectionTitle_instructorInfo =>
      'Instructor-Informationen';

  @override
  String get certifications_edit_sectionTitle_notes => 'Notizen';

  @override
  String get certifications_edit_snackBar_added =>
      'Zertifizierung erfolgreich hinzugefuegt';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return 'Fehler beim Laden der Zertifizierung: $error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return 'Fehler beim Auswaehlen des Fotos: $error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return 'Fehler beim Speichern der Zertifizierung: $error';
  }

  @override
  String get certifications_edit_snackBar_updated =>
      'Zertifizierung erfolgreich aktualisiert';

  @override
  String get certifications_edit_validation_nameRequired =>
      'Bitte geben Sie einen Zertifizierungsnamen ein';

  @override
  String get certifications_list_button_retry => 'Erneut versuchen';

  @override
  String get certifications_list_empty_button =>
      'Erste Zertifizierung hinzufuegen';

  @override
  String get certifications_list_empty_subtitle =>
      'Fuegen Sie Ihre Tauchzertifizierungen hinzu, um\nIhre Ausbildung und Qualifikationen zu verfolgen';

  @override
  String get certifications_list_empty_title =>
      'Noch keine Zertifizierungen hinzugefuegt';

  @override
  String certifications_list_error_loading(Object error) {
    return 'Fehler beim Laden der Zertifizierungen: $error';
  }

  @override
  String get certifications_list_fab_addCertification =>
      'Zertifizierung hinzufuegen';

  @override
  String get certifications_list_section_expired => 'Abgelaufen';

  @override
  String get certifications_list_section_expiringSoon => 'Laeuft bald ab';

  @override
  String get certifications_list_section_valid => 'Gueltig';

  @override
  String get certifications_list_sort_title => 'Zertifizierungen sortieren';

  @override
  String get certifications_list_tile_expired => 'Abgelaufen';

  @override
  String certifications_list_tile_expiringDays(Object days) {
    return '${days}T';
  }

  @override
  String get certifications_list_tooltip_addCertification =>
      'Zertifizierung hinzufuegen';

  @override
  String get certifications_list_tooltip_search =>
      'Zertifizierungen durchsuchen';

  @override
  String get certifications_list_tooltip_sort => 'Sortieren';

  @override
  String get certifications_list_tooltip_walletView => 'Kartenansicht';

  @override
  String get certifications_picker_clearTooltip =>
      'Zertifizierungsauswahl loeschen';

  @override
  String get certifications_picker_empty_addButton =>
      'Zertifizierung hinzufuegen';

  @override
  String get certifications_picker_empty_title => 'Noch keine Zertifizierungen';

  @override
  String certifications_picker_error(Object error) {
    return 'Fehler beim Laden der Zertifizierungen: $error';
  }

  @override
  String get certifications_picker_expired => 'Abgelaufen';

  @override
  String get certifications_picker_hint =>
      'Tippen, um mit einer erworbenen Zertifizierung zu verknuepfen';

  @override
  String get certifications_picker_newCert => 'Neue Zertifizierung';

  @override
  String get certifications_picker_noSelection =>
      'Keine Zertifizierung ausgewaehlt';

  @override
  String get certifications_picker_sheetTitle =>
      'Mit Zertifizierung verknuepfen';

  @override
  String get certifications_renderer_footer => 'Submersion Tauchlogbuch';

  @override
  String certifications_renderer_label_cardNumber(Object number) {
    return 'Karten-Nr.: $number';
  }

  @override
  String get certifications_renderer_label_hasCompletedTraining =>
      'hat die Ausbildung abgeschlossen als';

  @override
  String certifications_renderer_label_instructor(Object name) {
    return 'Tauchlehrer: $name';
  }

  @override
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  ) {
    return 'Tauchlehrer: $name ($number)';
  }

  @override
  String certifications_renderer_label_issued(Object date) {
    return 'Ausgestellt: $date';
  }

  @override
  String get certifications_renderer_label_thisCertifies =>
      'Hiermit wird bescheinigt, dass';

  @override
  String get certifications_search_empty_hint =>
      'Nach Name, Verband oder Kartennummer suchen';

  @override
  String get certifications_search_fieldLabel =>
      'Zertifizierungen durchsuchen...';

  @override
  String certifications_search_noResults(Object query) {
    return 'Keine Zertifizierungen gefunden fuer \"$query\"';
  }

  @override
  String get certifications_search_tooltip_back => 'Zurueck';

  @override
  String get certifications_search_tooltip_clear => 'Suche loeschen';

  @override
  String certifications_share_error_card(Object error) {
    return 'Karte konnte nicht geteilt werden: $error';
  }

  @override
  String certifications_share_error_certificate(Object error) {
    return 'Zertifikat konnte nicht geteilt werden: $error';
  }

  @override
  String get certifications_share_option_card_subtitle =>
      'Zertifizierungsbild im Kreditkartenformat';

  @override
  String get certifications_share_option_card_title => 'Als Karte teilen';

  @override
  String get certifications_share_option_certificate_subtitle =>
      'Formelles Zertifikatsdokument';

  @override
  String get certifications_share_option_certificate_title =>
      'Als Zertifikat teilen';

  @override
  String get certifications_share_title => 'Zertifizierung teilen';

  @override
  String get certifications_summary_header_subtitle =>
      'Waehlen Sie eine Zertifizierung aus der Liste, um Details anzuzeigen';

  @override
  String get certifications_summary_header_title => 'Zertifizierungen';

  @override
  String get certifications_summary_overview_title => 'Uebersicht';

  @override
  String get certifications_summary_quickActions_add =>
      'Zertifizierung hinzufuegen';

  @override
  String get certifications_summary_quickActions_title => 'Schnellaktionen';

  @override
  String get certifications_summary_recentTitle => 'Neueste Zertifizierungen';

  @override
  String get certifications_summary_stat_expired => 'Abgelaufen';

  @override
  String get certifications_summary_stat_expiringSoon => 'Laeuft bald ab';

  @override
  String get certifications_summary_stat_total => 'Gesamt';

  @override
  String get certifications_summary_stat_valid => 'Gueltig';

  @override
  String certifications_walletCard_countPlural(Object count) {
    return '$count Zertifizierungen';
  }

  @override
  String certifications_walletCard_countSingular(Object count) {
    return '$count Zertifizierung';
  }

  @override
  String get certifications_walletCard_emptyFooter =>
      'Fuegen Sie Ihre erste Zertifizierung hinzu';

  @override
  String get certifications_walletCard_error =>
      'Zertifizierungen konnten nicht geladen werden';

  @override
  String get certifications_walletCard_semanticLabel =>
      'Zertifizierungskartei. Tippen, um alle Zertifizierungen anzuzeigen';

  @override
  String get certifications_walletCard_tapToAdd => 'Tippen zum Hinzufuegen';

  @override
  String get certifications_walletCard_title => 'Zertifizierungskartei';

  @override
  String get certifications_wallet_appBar_title => 'Zertifizierungskartei';

  @override
  String get certifications_wallet_error_retry => 'Erneut versuchen';

  @override
  String get certifications_wallet_error_title =>
      'Zertifizierungen konnten nicht geladen werden';

  @override
  String get certifications_wallet_options_edit => 'Bearbeiten';

  @override
  String get certifications_wallet_options_share => 'Teilen';

  @override
  String get certifications_wallet_options_viewDetails => 'Details anzeigen';

  @override
  String get certifications_wallet_tooltip_add => 'Zertifizierung hinzufuegen';

  @override
  String get certifications_wallet_tooltip_share => 'Zertifizierung teilen';

  @override
  String get common_action_back => 'Zurueck';

  @override
  String get common_action_cancel => 'Abbrechen';

  @override
  String get common_action_close => 'Schliessen';

  @override
  String get common_action_delete => 'Loeschen';

  @override
  String get common_action_edit => 'Bearbeiten';

  @override
  String get common_action_ok => 'OK';

  @override
  String get common_action_save => 'Speichern';

  @override
  String get common_action_search => 'Suchen';

  @override
  String get common_label_error => 'Fehler';

  @override
  String get common_label_loading => 'Wird geladen';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get courses_action_add => 'Kurs hinzufügen';

  @override
  String get courses_action_create => 'Kurs erstellen';

  @override
  String get courses_action_edit => 'Kurs bearbeiten';

  @override
  String get courses_action_exportTrainingLog =>
      'Ausbildungsprotokoll exportieren';

  @override
  String get courses_action_markCompleted => 'Als abgeschlossen markieren';

  @override
  String get courses_action_moreOptions => 'Weitere Optionen';

  @override
  String get courses_action_retry => 'Wiederholen';

  @override
  String get courses_action_saveChanges => 'Änderungen speichern';

  @override
  String get courses_action_saveSemantic => 'Kurs speichern';

  @override
  String get courses_action_sort => 'Sortieren';

  @override
  String get courses_action_sortTitle => 'Kurse sortieren';

  @override
  String courses_card_instructor(Object name) {
    return 'Tauchlehrer: $name';
  }

  @override
  String courses_card_started(Object date) {
    return 'Begonnen am $date';
  }

  @override
  String get courses_detail_certificationNotFound =>
      'Zertifizierung nicht gefunden';

  @override
  String get courses_detail_noTrainingDives =>
      'Noch keine Ausbildungstauchgänge verknüpft';

  @override
  String get courses_detail_notFound => 'Kurs nicht gefunden';

  @override
  String get courses_dialog_complete => 'Abschließen';

  @override
  String courses_dialog_deleteMessage(Object name) {
    return 'Möchten Sie $name wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get courses_dialog_deleteTitle => 'Kurs löschen?';

  @override
  String get courses_dialog_markCompletedMessage =>
      'Dies markiert den Kurs als abgeschlossen mit dem heutigen Datum. Fortfahren?';

  @override
  String get courses_dialog_markCompletedTitle =>
      'Als abgeschlossen markieren?';

  @override
  String get courses_empty_button => 'Ersten Ausbildungskurs hinzufügen';

  @override
  String get courses_empty_noCompleted => 'Keine abgeschlossenen Kurse';

  @override
  String get courses_empty_noInProgress => 'Keine laufenden Kurse';

  @override
  String get courses_empty_subtitle =>
      'Fügen Sie Ihren ersten Kurs hinzu, um zu beginnen';

  @override
  String get courses_empty_title => 'Noch keine Ausbildungskurse';

  @override
  String courses_error_generic(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get courses_error_loadingCertification =>
      'Fehler beim Laden der Zertifizierung';

  @override
  String get courses_error_loadingDives => 'Fehler beim Laden der Tauchgänge';

  @override
  String get courses_field_courseName => 'Kursname';

  @override
  String get courses_field_courseNameHint => 'z.B. Open Water Diver';

  @override
  String get courses_field_instructorName => 'Tauchlehrername';

  @override
  String get courses_field_instructorNumber => 'Tauchlehrernummer';

  @override
  String get courses_field_linkCertificationHint =>
      'Verknüpfen Sie eine Zertifizierung, die aus diesem Kurs erworben wurde';

  @override
  String get courses_field_location => 'Ort';

  @override
  String get courses_field_notes => 'Notizen';

  @override
  String get courses_field_selectFromBuddies =>
      'Aus Tauchpartnern auswählen (Optional)';

  @override
  String get courses_filter_all => 'Alle';

  @override
  String get courses_label_agency => 'Organisation';

  @override
  String get courses_label_completed => 'Abgeschlossen';

  @override
  String get courses_label_completionDate => 'Abschlussdatum';

  @override
  String get courses_label_courseInProgress => 'Kurs läuft';

  @override
  String get courses_label_instructorNumber => 'Tauchlehrer-Nr.';

  @override
  String get courses_label_location => 'Ort';

  @override
  String get courses_label_name => 'Name';

  @override
  String get courses_label_none => '-- Keine --';

  @override
  String get courses_label_startDate => 'Startdatum';

  @override
  String courses_message_errorSaving(Object error) {
    return 'Fehler beim Speichern des Kurses: $error';
  }

  @override
  String courses_message_exportFailed(Object error) {
    return 'Export des Ausbildungsprotokolls fehlgeschlagen: $error';
  }

  @override
  String get courses_picker_active => 'Aktiv';

  @override
  String get courses_picker_clearSelection => 'Auswahl aufheben';

  @override
  String get courses_picker_createCourse => 'Kurs erstellen';

  @override
  String courses_picker_errorLoading(Object error) {
    return 'Fehler beim Laden der Kurse: $error';
  }

  @override
  String get courses_picker_newCourse => 'Neuer Kurs';

  @override
  String get courses_picker_noCourses => 'Noch keine Kurse';

  @override
  String get courses_picker_noneSelected => 'Kein Kurs ausgewählt';

  @override
  String get courses_picker_selectTitle => 'Ausbildungskurs auswählen';

  @override
  String get courses_picker_selected => 'ausgewählt';

  @override
  String get courses_picker_tapToLink =>
      'Tippen, um mit einem Ausbildungskurs zu verknüpfen';

  @override
  String get courses_section_details => 'Kursdetails';

  @override
  String get courses_section_earnedCertification => 'Erworbene Zertifizierung';

  @override
  String get courses_section_instructor => 'Tauchlehrer';

  @override
  String get courses_section_notes => 'Notizen';

  @override
  String get courses_section_trainingDives => 'Ausbildungstauchgänge';

  @override
  String get courses_status_completed => 'Abgeschlossen';

  @override
  String courses_status_daysSinceStart(Object days) {
    return '$days Tage seit Beginn';
  }

  @override
  String courses_status_durationDays(Object days) {
    return '$days Tage';
  }

  @override
  String get courses_status_inProgress => 'Läuft';

  @override
  String courses_status_semanticLabel(Object status, Object duration) {
    return '$status, $duration';
  }

  @override
  String get courses_summary_overview => 'Übersicht';

  @override
  String get courses_summary_quickActions => 'Schnellaktionen';

  @override
  String get courses_summary_recentCourses => 'Aktuelle Kurse';

  @override
  String get courses_summary_selectHint =>
      'Wählen Sie einen Kurs aus der Liste, um Details anzuzeigen';

  @override
  String get courses_summary_title => 'Ausbildungskurse';

  @override
  String get courses_summary_total => 'Gesamt';

  @override
  String get courses_title => 'Ausbildungskurse';

  @override
  String get courses_title_edit => 'Kurs bearbeiten';

  @override
  String get courses_title_new => 'Neuer Kurs';

  @override
  String get courses_title_singular => 'Kurs';

  @override
  String get courses_validation_nameRequired =>
      'Bitte geben Sie einen Kursnamen ein';

  @override
  String get dashboard_activity_daySinceDiving =>
      'Tag seit dem letzten Tauchgang';

  @override
  String get dashboard_activity_daysSinceDiving =>
      'Tage seit dem letzten Tauchgang';

  @override
  String dashboard_activity_diveInYear(Object year) {
    return 'Tauchgang in $year';
  }

  @override
  String get dashboard_activity_diveThisMonth => 'Tauchgang diesen Monat';

  @override
  String dashboard_activity_divesInYear(Object year) {
    return 'Tauchgaenge in $year';
  }

  @override
  String get dashboard_activity_divesThisMonth => 'Tauchgaenge diesen Monat';

  @override
  String get dashboard_activity_error => 'Fehler';

  @override
  String get dashboard_activity_lastDive => 'Letzter Tauchgang';

  @override
  String get dashboard_activity_loading => 'Wird geladen';

  @override
  String get dashboard_activity_noDivesYet => 'Noch keine Tauchgaenge';

  @override
  String get dashboard_activity_today => 'Heute!';

  @override
  String get dashboard_alerts_actionUpdate => 'Aktualisieren';

  @override
  String get dashboard_alerts_actionView => 'Anzeigen';

  @override
  String get dashboard_alerts_checkInsuranceExpiry =>
      'Pruefen Sie Ihr Versicherungsablaufdatum';

  @override
  String get dashboard_alerts_daysOverdueOne => '1 Tag ueberfaellig';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return '$count Tage ueberfaellig';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => 'Faellig in 1 Tag';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return 'Faellig in $count Tagen';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return '$name Wartung faellig';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return '$name Wartung ueberfaellig';
  }

  @override
  String get dashboard_alerts_insuranceExpired => 'Versicherung abgelaufen';

  @override
  String get dashboard_alerts_insuranceExpiredGeneric =>
      'Ihre Tauchversicherung ist abgelaufen';

  @override
  String dashboard_alerts_insuranceExpiredProvider(Object provider) {
    return '$provider abgelaufen';
  }

  @override
  String dashboard_alerts_insuranceExpiresDate(Object date) {
    return 'Laeuft ab am $date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon =>
      'Versicherung laeuft bald ab';

  @override
  String get dashboard_alerts_sectionTitle => 'Hinweise & Erinnerungen';

  @override
  String get dashboard_alerts_serviceDueToday => 'Wartung heute faellig';

  @override
  String get dashboard_alerts_serviceIntervalReached =>
      'Wartungsintervall erreicht';

  @override
  String get dashboard_defaultDiverName => 'Taucher';

  @override
  String get dashboard_greeting_afternoon => 'Guten Nachmittag';

  @override
  String get dashboard_greeting_evening => 'Guten Abend';

  @override
  String get dashboard_greeting_morning => 'Guten Morgen';

  @override
  String dashboard_greeting_withName(Object greeting, Object name) {
    return '$greeting, $name!';
  }

  @override
  String dashboard_greeting_withoutName(Object greeting) {
    return '$greeting!';
  }

  @override
  String get dashboard_hero_divesLoggedOne => '1 Tauchgang protokolliert';

  @override
  String dashboard_hero_divesLoggedOther(Object count) {
    return '$count Tauchgaenge protokolliert';
  }

  @override
  String get dashboard_hero_error => 'Bereit, die Tiefen zu erkunden?';

  @override
  String dashboard_hero_hoursUnderwater(Object hours) {
    return '$hours Stunden unter Wasser';
  }

  @override
  String get dashboard_hero_loading =>
      'Ihre Tauchstatistiken werden geladen...';

  @override
  String dashboard_hero_minutesUnderwater(Object minutes) {
    return '$minutes Minuten unter Wasser';
  }

  @override
  String get dashboard_hero_noDives =>
      'Bereit, Ihren ersten Tauchgang zu protokollieren?';

  @override
  String get dashboard_personalRecords_coldest => 'Kaeltester';

  @override
  String get dashboard_personalRecords_deepest => 'Tiefster';

  @override
  String get dashboard_personalRecords_longest => 'Laengster';

  @override
  String get dashboard_personalRecords_sectionTitle => 'Persoenliche Rekorde';

  @override
  String get dashboard_personalRecords_warmest => 'Waermster';

  @override
  String get dashboard_quickActions_addSite => 'Tauchplatz hinzufuegen';

  @override
  String get dashboard_quickActions_addSiteTooltip =>
      'Neuen Tauchplatz hinzufuegen';

  @override
  String get dashboard_quickActions_logDive => 'Tauchgang erfassen';

  @override
  String get dashboard_quickActions_logDiveTooltip =>
      'Neuen Tauchgang erfassen';

  @override
  String get dashboard_quickActions_planDive => 'Tauchgang planen';

  @override
  String get dashboard_quickActions_planDiveTooltip => 'Neuen Tauchgang planen';

  @override
  String get dashboard_quickActions_sectionTitle => 'Schnellaktionen';

  @override
  String get dashboard_quickActions_statistics => 'Statistiken';

  @override
  String get dashboard_quickActions_statisticsTooltip =>
      'Tauchstatistiken anzeigen';

  @override
  String get dashboard_quickStats_countries => 'Laender';

  @override
  String get dashboard_quickStats_countriesSubtitle => 'besucht';

  @override
  String get dashboard_quickStats_sectionTitle => 'Auf einen Blick';

  @override
  String get dashboard_quickStats_species => 'Arten';

  @override
  String get dashboard_quickStats_speciesSubtitle => 'entdeckt';

  @override
  String get dashboard_quickStats_topBuddy => 'Haeufigster Tauchpartner';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count Tauchgaenge';
  }

  @override
  String get dashboard_recentDives_empty => 'Noch keine Tauchgaenge erfasst';

  @override
  String get dashboard_recentDives_errorLoading =>
      'Tauchgaenge konnten nicht geladen werden';

  @override
  String get dashboard_recentDives_logFirst => 'Ersten Tauchgang erfassen';

  @override
  String get dashboard_recentDives_sectionTitle => 'Letzte Tauchgaenge';

  @override
  String get dashboard_recentDives_viewAll => 'Alle anzeigen';

  @override
  String get dashboard_recentDives_viewAllTooltip =>
      'Alle Tauchgaenge anzeigen';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count aktive Hinweise';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives =>
      'Fehler: Letzte Tauchgaenge konnten nicht geladen werden';

  @override
  String get dashboard_semantics_errorLoadingStatistics =>
      'Fehler: Statistiken konnten nicht geladen werden';

  @override
  String get dashboard_semantics_greetingBanner => 'Dashboard-Begruessung';

  @override
  String get dashboard_stats_errorLoadingStatistics =>
      'Statistiken konnten nicht geladen werden';

  @override
  String get dashboard_stats_hoursLogged => 'Erfasste Stunden';

  @override
  String get dashboard_stats_maxDepth => 'Max. Tiefe';

  @override
  String get dashboard_stats_sitesVisited => 'Besuchte Tauchplaetze';

  @override
  String get dashboard_stats_totalDives => 'Tauchgaenge gesamt';

  @override
  String get decoCalculator_addToPlanner => 'Zum Planer hinzufügen';

  @override
  String decoCalculator_bottomTimeSemantics(Object time) {
    return 'Grundzeit: $time Minuten';
  }

  @override
  String get decoCalculator_createPlanTooltip =>
      'Tauchplan aus aktuellen Parametern erstellen';

  @override
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  ) {
    return 'Plan erstellt: $depth$depthSymbol für ${time}min mit $gasMixName';
  }

  @override
  String get decoCalculator_customMixTrimix =>
      'Benutzerdefiniertes Gemisch (Trimix)';

  @override
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol) {
    return 'Tiefe: $depth $depthSymbol';
  }

  @override
  String get decoCalculator_diveParameters => 'Tauchparameter';

  @override
  String get decoCalculator_endCaution => 'Vorsicht';

  @override
  String get decoCalculator_endDanger => 'Gefahr';

  @override
  String get decoCalculator_endSafe => 'Sicher';

  @override
  String get decoCalculator_field_bottomTime => 'Grundzeit';

  @override
  String get decoCalculator_field_depth => 'Tiefe';

  @override
  String get decoCalculator_field_gasMix => 'Gasgemisch';

  @override
  String get decoCalculator_gasSafety => 'Gassicherheit';

  @override
  String get decoCalculator_hideCustomMix =>
      'Benutzerdefiniertes Gemisch ausblenden';

  @override
  String get decoCalculator_hideCustomMixSemantics =>
      'Benutzerdefinierte Gasgemischauswahl ausblenden';

  @override
  String get decoCalculator_modExceeded => 'MOD überschritten';

  @override
  String get decoCalculator_modSafe => 'MOD sicher';

  @override
  String get decoCalculator_ppO2Caution => 'ppO2 Vorsicht';

  @override
  String get decoCalculator_ppO2Danger => 'ppO2 Gefahr';

  @override
  String get decoCalculator_ppO2Hypoxic => 'ppO2 Hypoxisch';

  @override
  String get decoCalculator_ppO2Safe => 'ppO2 sicher';

  @override
  String get decoCalculator_resetToDefaults => 'Auf Standardwerte zurücksetzen';

  @override
  String get decoCalculator_showCustomMixSemantics =>
      'Benutzerdefinierte Gasgemischauswahl anzeigen';

  @override
  String decoCalculator_timeValueMin(Object time) {
    return '$time min';
  }

  @override
  String get decoCalculator_title => 'Deko-Rechner';

  @override
  String diveCenters_accessibility_markerLabel(Object name) {
    return 'Tauchcenter: $name';
  }

  @override
  String get diveCenters_accessibility_selected => 'ausgewählt';

  @override
  String diveCenters_accessibility_viewDetails(Object name) {
    return 'Details für $name anzeigen';
  }

  @override
  String get diveCenters_accessibility_viewDives =>
      'Tauchgänge mit diesem Center anzeigen';

  @override
  String get diveCenters_accessibility_viewFullscreenMap =>
      'Vollbildkarte anzeigen';

  @override
  String diveCenters_accessibility_viewSavedCenter(Object name) {
    return 'Gespeichertes Tauchcenter $name anzeigen';
  }

  @override
  String get diveCenters_action_addCenter => 'Center hinzufügen';

  @override
  String get diveCenters_action_addNew => 'Neu hinzufügen';

  @override
  String get diveCenters_action_clearRating => 'Löschen';

  @override
  String get diveCenters_action_gettingLocation => 'Wird abgerufen...';

  @override
  String get diveCenters_action_import => 'Importieren';

  @override
  String get diveCenters_action_importToMyCenters =>
      'Zu Meine Center importieren';

  @override
  String get diveCenters_action_lookingUp => 'Wird gesucht...';

  @override
  String get diveCenters_action_lookupFromAddress => 'Von Adresse nachschlagen';

  @override
  String get diveCenters_action_pickFromMap => 'Auf Karte auswählen';

  @override
  String get diveCenters_action_retry => 'Wiederholen';

  @override
  String get diveCenters_action_settings => 'Einstellungen';

  @override
  String get diveCenters_action_useMyLocation => 'Meinen Standort verwenden';

  @override
  String get diveCenters_action_view => 'Anzeigen';

  @override
  String diveCenters_detail_divesLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge protokolliert',
      one: '1 Tauchgang protokolliert',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_detail_divesWithCenter =>
      'Tauchgänge mit diesem Center';

  @override
  String get diveCenters_detail_noDivesLogged =>
      'Noch keine Tauchgänge protokolliert';

  @override
  String diveCenters_dialog_deleteMessage(Object name) {
    return 'Möchten Sie \"$name\" wirklich löschen?';
  }

  @override
  String get diveCenters_dialog_deleteTitle => 'Tauchcenter löschen';

  @override
  String get diveCenters_dialog_discard => 'Verwerfen';

  @override
  String get diveCenters_dialog_discardMessage =>
      'Sie haben nicht gespeicherte Änderungen. Möchten Sie diese wirklich verwerfen?';

  @override
  String get diveCenters_dialog_discardTitle => 'Änderungen verwerfen?';

  @override
  String get diveCenters_dialog_keepEditing => 'Weiter bearbeiten';

  @override
  String get diveCenters_empty_button => 'Erstes Tauchcenter hinzufügen';

  @override
  String get diveCenters_empty_subtitle =>
      'Fügen Sie Ihre bevorzugten Tauchshops und -anbieter hinzu';

  @override
  String get diveCenters_empty_title => 'Noch keine Tauchcenter';

  @override
  String diveCenters_error_generic(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get diveCenters_error_geocodeFailed =>
      'Koordinaten für diese Adresse konnten nicht gefunden werden';

  @override
  String get diveCenters_error_importFailed =>
      'Tauchcenter konnte nicht importiert werden';

  @override
  String diveCenters_error_loading(Object error) {
    return 'Fehler beim Laden der Tauchcenter: $error';
  }

  @override
  String get diveCenters_error_locationPermission =>
      'Standort kann nicht abgerufen werden. Bitte prüfen Sie die Berechtigungen.';

  @override
  String get diveCenters_error_locationUnavailable =>
      'Standort kann nicht abgerufen werden. Ortungsdienste sind möglicherweise nicht verfügbar.';

  @override
  String get diveCenters_error_noAddressForLookup =>
      'Bitte geben Sie eine Adresse ein, um Koordinaten nachzuschlagen';

  @override
  String get diveCenters_error_notFound => 'Tauchcenter nicht gefunden';

  @override
  String diveCenters_error_saving(Object error) {
    return 'Fehler beim Speichern des Tauchcenters: $error';
  }

  @override
  String get diveCenters_error_unknown => 'Unbekannter Fehler';

  @override
  String get diveCenters_field_city => 'Stadt';

  @override
  String get diveCenters_field_country => 'Land';

  @override
  String get diveCenters_field_latitude => 'Breitengrad';

  @override
  String get diveCenters_field_longitude => 'Längengrad';

  @override
  String get diveCenters_field_nameRequired => 'Name *';

  @override
  String get diveCenters_field_postalCode => 'Postleitzahl';

  @override
  String get diveCenters_field_rating => 'Bewertung';

  @override
  String get diveCenters_field_stateProvince => 'Bundesland/Provinz';

  @override
  String get diveCenters_field_street => 'Straßenadresse';

  @override
  String get diveCenters_hint_addressDescription =>
      'Optionale Straßenadresse für Navigation';

  @override
  String get diveCenters_hint_affiliationsDescription =>
      'Wählen Sie Ausbildungsorganisationen aus, mit denen dieses Center verbunden ist';

  @override
  String get diveCenters_hint_city => 'z.B. Phuket';

  @override
  String get diveCenters_hint_country => 'z.B. Thailand';

  @override
  String get diveCenters_hint_email => 'info@tauchcenter.de';

  @override
  String get diveCenters_hint_gpsDescription =>
      'Wählen Sie eine Standortmethode oder geben Sie die Koordinaten manuell ein';

  @override
  String get diveCenters_hint_importSearch =>
      'Tauchcenter suchen (z.B. \"PADI\", \"Thailand\")';

  @override
  String get diveCenters_hint_latitude => 'z.B. 10.4613';

  @override
  String get diveCenters_hint_longitude => 'z.B. 99.8359';

  @override
  String get diveCenters_hint_name => 'Tauchcentername eingeben';

  @override
  String get diveCenters_hint_notes => 'Zusätzliche Informationen...';

  @override
  String get diveCenters_hint_phone => '+49 234 567 890';

  @override
  String get diveCenters_hint_postalCode => 'z.B. 83100';

  @override
  String get diveCenters_hint_stateProvince => 'z.B. Bayern';

  @override
  String get diveCenters_hint_street => 'z.B. Strandstraße 123';

  @override
  String get diveCenters_hint_website => 'www.tauchcenter.de';

  @override
  String diveCenters_import_fromDatabase(Object count) {
    return 'Aus Datenbank importieren ($count)';
  }

  @override
  String diveCenters_import_myCenters(Object count) {
    return 'Meine Center ($count)';
  }

  @override
  String get diveCenters_import_noResults => 'Keine Ergebnisse';

  @override
  String diveCenters_import_noResultsMessage(Object query) {
    return 'Keine Tauchcenter für \"$query\" gefunden. Versuchen Sie einen anderen Suchbegriff.';
  }

  @override
  String get diveCenters_import_searchDescription =>
      'Suchen Sie nach Tauchcentern, -shops und -clubs aus unserer Datenbank von Anbietern weltweit.';

  @override
  String get diveCenters_import_searchError => 'Suchfehler';

  @override
  String get diveCenters_import_searchHint =>
      'Versuchen Sie die Suche nach Name, Land oder Zertifizierungsorganisation.';

  @override
  String get diveCenters_import_searchTitle => 'Tauchcenter suchen';

  @override
  String get diveCenters_label_alreadyImported => 'Bereits importiert';

  @override
  String diveCenters_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge',
      one: '1 Tauchgang',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_label_email => 'E-Mail';

  @override
  String get diveCenters_label_imported => 'Importiert';

  @override
  String get diveCenters_label_locationNotSet => 'Standort nicht festgelegt';

  @override
  String get diveCenters_label_locationUnknown => 'Standort unbekannt';

  @override
  String get diveCenters_label_phone => 'Telefon';

  @override
  String get diveCenters_label_saved => 'Gespeichert';

  @override
  String diveCenters_label_source(Object source) {
    return 'Quelle: $source';
  }

  @override
  String get diveCenters_label_website => 'Website';

  @override
  String get diveCenters_map_addCoordinatesHint =>
      'Fügen Sie Ihren Tauchcentern Koordinaten hinzu, um sie auf der Karte zu sehen';

  @override
  String get diveCenters_map_noCoordinates =>
      'Keine Tauchcenter mit Koordinaten';

  @override
  String get diveCenters_picker_newCenter => 'Neues Tauchcenter';

  @override
  String get diveCenters_picker_title => 'Tauchcenter auswählen';

  @override
  String diveCenters_search_noResults(Object query) {
    return 'Keine Ergebnisse für \"$query\"';
  }

  @override
  String get diveCenters_search_prompt => 'Tauchcenter suchen';

  @override
  String get diveCenters_section_address => 'Adresse';

  @override
  String get diveCenters_section_affiliations => 'Verbindungen';

  @override
  String get diveCenters_section_basicInfo => 'Grundinformationen';

  @override
  String get diveCenters_section_contact => 'Kontakt';

  @override
  String get diveCenters_section_contactInfo => 'Kontaktinformationen';

  @override
  String get diveCenters_section_gpsCoordinates => 'GPS-Koordinaten';

  @override
  String get diveCenters_section_notes => 'Notizen';

  @override
  String get diveCenters_snackbar_coordinatesFound =>
      'Koordinaten aus Adresse gefunden';

  @override
  String get diveCenters_snackbar_copiedToClipboard =>
      'In Zwischenablage kopiert';

  @override
  String diveCenters_snackbar_imported(Object name) {
    return '\"$name\" importiert';
  }

  @override
  String get diveCenters_snackbar_locationCaptured => 'Standort erfasst';

  @override
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Standort erfasst (±${accuracy}m)';
  }

  @override
  String get diveCenters_snackbar_locationSelectedFromMap =>
      'Standort von Karte ausgewählt';

  @override
  String get diveCenters_sort_title => 'Tauchcenter sortieren';

  @override
  String get diveCenters_summary_countries => 'Länder';

  @override
  String get diveCenters_summary_highestRating => 'Höchste Bewertung';

  @override
  String get diveCenters_summary_overview => 'Übersicht';

  @override
  String get diveCenters_summary_quickActions => 'Schnellaktionen';

  @override
  String get diveCenters_summary_recentCenters => 'Aktuelle Tauchcenter';

  @override
  String get diveCenters_summary_selectPrompt =>
      'Wählen Sie ein Tauchcenter aus der Liste, um Details anzuzeigen';

  @override
  String get diveCenters_summary_topRated => 'Bestbewertet';

  @override
  String get diveCenters_summary_totalCenters => 'Center gesamt';

  @override
  String get diveCenters_summary_withGps => 'Mit GPS';

  @override
  String get diveCenters_title => 'Tauchcenter';

  @override
  String get diveCenters_title_add => 'Tauchcenter hinzufügen';

  @override
  String get diveCenters_title_edit => 'Tauchcenter bearbeiten';

  @override
  String get diveCenters_title_import => 'Tauchcenter importieren';

  @override
  String get diveCenters_tooltip_addNew => 'Neues Tauchcenter hinzufügen';

  @override
  String get diveCenters_tooltip_clearSearch => 'Suche löschen';

  @override
  String get diveCenters_tooltip_edit => 'Tauchcenter bearbeiten';

  @override
  String get diveCenters_tooltip_fitAllCenters => 'Alle Center anpassen';

  @override
  String get diveCenters_tooltip_listView => 'Listenansicht';

  @override
  String get diveCenters_tooltip_mapView => 'Kartenansicht';

  @override
  String get diveCenters_tooltip_moreOptions => 'Weitere Optionen';

  @override
  String get diveCenters_tooltip_search => 'Tauchcenter suchen';

  @override
  String get diveCenters_tooltip_sort => 'Sortieren';

  @override
  String get diveCenters_validation_invalidEmail =>
      'Bitte geben Sie eine gültige E-Mail-Adresse ein';

  @override
  String get diveCenters_validation_invalidLatitude => 'Ungültiger Breitengrad';

  @override
  String get diveCenters_validation_invalidLongitude => 'Ungültiger Längengrad';

  @override
  String get diveCenters_validation_nameRequired => 'Name ist erforderlich';

  @override
  String get diveComputer_action_setFavorite => 'Als Favorit festlegen';

  @override
  String diveComputer_error_generic(Object error) {
    return 'Ein Fehler ist aufgetreten: $error';
  }

  @override
  String get diveComputer_error_notFound => 'Gerät nicht gefunden';

  @override
  String get diveComputer_status_favorite => 'Favorit-Computer';

  @override
  String get diveComputer_title => 'Tauchcomputer';

  @override
  String diveLog_bulkDelete_confirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    return 'Moechten Sie wirklich $count $_temp0 loeschen? Diese Aktion kann nicht rueckgaengig gemacht werden.';
  }

  @override
  String get diveLog_bulkDelete_restored => 'Tauchgaenge wiederhergestellt';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    return '$count $_temp0 geloescht';
  }

  @override
  String get diveLog_bulkDelete_title => 'Tauchgaenge loeschen';

  @override
  String get diveLog_bulkDelete_undo => 'Rueckgaengig';

  @override
  String get diveLog_bulkEdit_addTags => 'Tags hinzufuegen';

  @override
  String get diveLog_bulkEdit_addTagsDescription =>
      'Tags zu ausgewaehlten Tauchgaengen hinzufuegen';

  @override
  String diveLog_bulkEdit_addedTags(int tagCount, int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: 'Tags',
      one: 'Tag',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'Tauchgaengen',
      one: 'Tauchgang',
    );
    return '$tagCount $_temp0 zu $diveCount $_temp1 hinzugefuegt';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => 'Reise aendern';

  @override
  String get diveLog_bulkEdit_changeTripDescription =>
      'Ausgewaehlte Tauchgaenge einer Reise zuordnen';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips =>
      'Fehler beim Laden der Reisen';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return 'Tags konnten nicht hinzugefuegt werden: $error';
  }

  @override
  String diveLog_bulkEdit_failedUpdateTrip(Object error) {
    return 'Reise konnte nicht aktualisiert werden: $error';
  }

  @override
  String diveLog_bulkEdit_movedToTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    return '$count $_temp0 zur Reise verschoben';
  }

  @override
  String get diveLog_bulkEdit_noTagsAvailable => 'Keine Tags verfuegbar.';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate =>
      'Keine Tags verfuegbar. Erstellen Sie zuerst Tags.';

  @override
  String get diveLog_bulkEdit_noTrip => 'Keine Reise';

  @override
  String get diveLog_bulkEdit_removeFromTrip => 'Von Reise entfernen';

  @override
  String get diveLog_bulkEdit_removeTags => 'Tags entfernen';

  @override
  String get diveLog_bulkEdit_removeTagsDescription =>
      'Tags von ausgewaehlten Tauchgaengen entfernen';

  @override
  String diveLog_bulkEdit_removedFromTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    return '$count $_temp0 von Reise entfernt';
  }

  @override
  String get diveLog_bulkEdit_selectTrip => 'Reise auswaehlen';

  @override
  String diveLog_bulkEdit_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    return '$count $_temp0 bearbeiten';
  }

  @override
  String get diveLog_bulkExport_csv => 'CSV';

  @override
  String get diveLog_bulkExport_csvDescription => 'Tabellenformat';

  @override
  String diveLog_bulkExport_failed(Object error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get diveLog_bulkExport_pdf => 'PDF-Logbuch';

  @override
  String get diveLog_bulkExport_pdfDescription =>
      'Druckbare Tauchlogbuchseiten';

  @override
  String diveLog_bulkExport_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    return '$count $_temp0 erfolgreich exportiert';
  }

  @override
  String diveLog_bulkExport_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    return '$count $_temp0 exportieren';
  }

  @override
  String get diveLog_bulkExport_uddf => 'UDDF';

  @override
  String get diveLog_bulkExport_uddfDescription => 'Universal Dive Data Format';

  @override
  String get diveLog_ccr_diluent_air => 'Luft';

  @override
  String get diveLog_ccr_hint_loopVolume => 'z.B. 6,0';

  @override
  String get diveLog_ccr_hint_type => 'z.B. Sofnolime';

  @override
  String get diveLog_ccr_label_deco => 'Deko';

  @override
  String get diveLog_ccr_label_he => 'He';

  @override
  String get diveLog_ccr_label_highBottom => 'Hoch (Grund)';

  @override
  String get diveLog_ccr_label_loopVolume => 'Loop-Volumen';

  @override
  String get diveLog_ccr_label_lowDescAsc => 'Niedrig (Ab-/Aufstieg)';

  @override
  String get diveLog_ccr_label_n2 => 'N₂';

  @override
  String get diveLog_ccr_label_o2 => 'O₂';

  @override
  String get diveLog_ccr_label_rated => 'Nennwert';

  @override
  String get diveLog_ccr_label_remaining => 'Verbleibend';

  @override
  String get diveLog_ccr_label_type => 'Typ';

  @override
  String get diveLog_ccr_sectionDiluentGas => 'Diluentgas';

  @override
  String get diveLog_ccr_sectionScrubber => 'Atemkalk';

  @override
  String get diveLog_ccr_sectionSetpoints => 'Setpoints (bar)';

  @override
  String get diveLog_ccr_title => 'CCR-Einstellungen';

  @override
  String diveLog_collapsible_semantics_collapse(Object title) {
    return 'Bereich $title einklappen';
  }

  @override
  String diveLog_collapsible_semantics_expand(Object title) {
    return 'Bereich $title ausklappen';
  }

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return 'Durchschn.: $depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => 'Basis';

  @override
  String get diveLog_cylinderSac_noSac => 'SAC: --';

  @override
  String get diveLog_cylinderSac_tooltip_aiData =>
      'Verwendet AI-Senderdaten fuer hoehere Genauigkeit';

  @override
  String get diveLog_cylinderSac_tooltip_basicData =>
      'Berechnet aus Start-/Enddruck';

  @override
  String get diveLog_deco_badge_deco => 'DEKO';

  @override
  String get diveLog_deco_badge_noDeco => 'KEINE DEKO';

  @override
  String get diveLog_deco_label_ceiling => 'Ceiling';

  @override
  String get diveLog_deco_label_leading => 'Leitgewebe';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String get diveLog_deco_sectionDecoStops => 'Dekostopps';

  @override
  String get diveLog_deco_sectionTissueLoading => 'Gewebesaettigung';

  @override
  String get diveLog_deco_semantics_notRequired =>
      'Keine Dekompression erforderlich';

  @override
  String get diveLog_deco_semantics_required => 'Dekompression erforderlich';

  @override
  String get diveLog_deco_tissueFast => 'Schnell';

  @override
  String get diveLog_deco_tissueSlow => 'Langsam';

  @override
  String get diveLog_deco_title => 'Dekompressionsstatus';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return 'Gesamt: $time';
  }

  @override
  String get diveLog_delete_cancel => 'Abbrechen';

  @override
  String get diveLog_delete_confirm =>
      'Diese Aktion kann nicht rueckgaengig gemacht werden. Der Tauchgang und alle zugehoerigen Daten (Profil, Flaschen, Sichtungen) werden dauerhaft geloescht.';

  @override
  String get diveLog_delete_delete => 'Loeschen';

  @override
  String get diveLog_delete_title => 'Tauchgang loeschen?';

  @override
  String get diveLog_detail_appBar => 'Tauchgang-Details';

  @override
  String get diveLog_detail_badge_critical => 'KRITISCH';

  @override
  String get diveLog_detail_badge_deco => 'DEKO';

  @override
  String get diveLog_detail_badge_noDeco => 'KEINE DEKO';

  @override
  String get diveLog_detail_badge_warning => 'WARNUNG';

  @override
  String diveLog_detail_buddyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchpartner',
      one: 'Tauchpartner',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_button_playback => 'Wiedergabe';

  @override
  String get diveLog_detail_button_rangeAnalysis => 'Bereichsanalyse';

  @override
  String get diveLog_detail_button_showEnd => 'Ende anzeigen';

  @override
  String get diveLog_detail_captureSignature =>
      'Unterschrift des Tauchlehrers erfassen';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return 'Um $timestamp';
  }

  @override
  String diveLog_detail_collapsed_atTimeInfo(
    Object timestamp,
    Object baseInfo,
  ) {
    return 'Um $timestamp • $baseInfo';
  }

  @override
  String diveLog_detail_collapsed_ceiling(Object value) {
    return 'Deko-Grenze: $value';
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
    return 'CNS: $cns • Max ppO₂: $maxPpO2 • Um $timestamp: $ppO2 bar';
  }

  @override
  String diveLog_detail_collapsed_ndl(Object value) {
    return 'Nullzeit: $value';
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
      other: 'Gegenstaende',
      one: 'Gegenstand',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_errorLoading => 'Fehler beim Laden des Tauchgangs';

  @override
  String get diveLog_detail_fullscreen_sampleData => 'Messdaten';

  @override
  String get diveLog_detail_fullscreen_tapChartCompact =>
      'Tippen Sie auf das Diagramm für kompakte Ansicht';

  @override
  String get diveLog_detail_fullscreen_tapChartFull =>
      'Tippen Sie auf das Diagramm für Vollbildansicht';

  @override
  String get diveLog_detail_fullscreen_touchChart =>
      'Berühren Sie das Diagramm, um Daten an diesem Punkt zu sehen';

  @override
  String get diveLog_detail_label_airTemp => 'Lufttemperatur';

  @override
  String get diveLog_detail_label_avgDepth => 'Durchschn. Tiefe';

  @override
  String get diveLog_detail_label_buddy => 'Tauchpartner';

  @override
  String get diveLog_detail_label_currentDirection => 'Stroemungsrichtung';

  @override
  String get diveLog_detail_label_currentStrength => 'Stroemungsstaerke';

  @override
  String get diveLog_detail_label_diveComputer => 'Tauchcomputer';

  @override
  String get diveLog_detail_label_serialNumber => 'Seriennummer';

  @override
  String get diveLog_detail_label_firmwareVersion => 'Firmware-Version';

  @override
  String get diveLog_detail_label_diveMaster => 'Divemaster';

  @override
  String get diveLog_detail_label_diveType => 'Tauchgangart';

  @override
  String get diveLog_detail_label_elevation => 'Hoehe';

  @override
  String get diveLog_detail_label_entry => 'Einstieg:';

  @override
  String get diveLog_detail_label_entryMethod => 'Einstiegsmethode';

  @override
  String get diveLog_detail_label_exit => 'Ausstieg:';

  @override
  String get diveLog_detail_label_exitMethod => 'Ausstiegsmethode';

  @override
  String get diveLog_detail_label_gradientFactors => 'Gradientenfaktoren';

  @override
  String get diveLog_detail_label_height => 'Hoehe';

  @override
  String get diveLog_detail_label_highTide => 'Hochwasser';

  @override
  String get diveLog_detail_label_lowTide => 'Niedrigwasser';

  @override
  String get diveLog_detail_label_ppO2AtPoint => 'ppO₂ am ausgewaehlten Punkt:';

  @override
  String get diveLog_detail_label_rateOfChange => 'Aenderungsrate';

  @override
  String get diveLog_detail_label_sacRate => 'SAC-Rate';

  @override
  String get diveLog_detail_label_state => 'Zustand';

  @override
  String get diveLog_detail_label_surfaceInterval => 'Oberflaechenintervall';

  @override
  String get diveLog_detail_label_surfacePressure => 'Oberflaechendruck';

  @override
  String get diveLog_detail_label_swellHeight => 'Wellenhoehe';

  @override
  String get diveLog_detail_label_total => 'Gesamt:';

  @override
  String get diveLog_detail_label_visibility => 'Sichtweite';

  @override
  String get diveLog_detail_label_waterType => 'Wasserart';

  @override
  String get diveLog_detail_menu_delete => 'Loeschen';

  @override
  String get diveLog_detail_menu_export => 'Exportieren';

  @override
  String get diveLog_detail_menu_openFullPage => 'Ganze Seite oeffnen';

  @override
  String get diveLog_detail_noNotes => 'Keine Notizen fuer diesen Tauchgang.';

  @override
  String get diveLog_detail_notFound => 'Tauchgang nicht gefunden';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count Punkte';
  }

  @override
  String get diveLog_detail_section_altitudeDive => 'Hoehentauchgang';

  @override
  String get diveLog_detail_section_buddies => 'Tauchpartner';

  @override
  String get diveLog_detail_section_conditions => 'Bedingungen';

  @override
  String get diveLog_detail_section_customFields => 'Custom Fields';

  @override
  String get diveLog_detail_section_decoStatus => 'Dekompressionsstatus';

  @override
  String get diveLog_detail_section_details => 'Details';

  @override
  String get diveLog_detail_section_diveProfile => 'Tauchprofil';

  @override
  String get diveLog_detail_section_equipment => 'Ausruestung';

  @override
  String get diveLog_detail_section_marineLife => 'Meeresfauna';

  @override
  String get diveLog_detail_section_notes => 'Notizen';

  @override
  String get diveLog_detail_section_oxygenToxicity => 'Sauerstofftoxizitaet';

  @override
  String get diveLog_detail_section_sacByCylinder => 'SAC nach Flasche';

  @override
  String get diveLog_detail_section_sacRateBySegment => 'SAC-Rate nach Segment';

  @override
  String get diveLog_detail_section_tags => 'Tags';

  @override
  String get diveLog_detail_section_tanks => 'Flaschen';

  @override
  String get diveLog_detail_section_tide => 'Gezeiten';

  @override
  String get diveLog_detail_section_trainingSignature =>
      'Ausbildungsunterschrift';

  @override
  String get diveLog_detail_section_weight => 'Gewicht';

  @override
  String get diveLog_detail_signatureDescription =>
      'Tippen Sie, um die Verifizierung des Tauchlehrers fuer diesen Ausbildungstauchgang hinzuzufuegen';

  @override
  String get diveLog_detail_soloDive =>
      'Solotauchgang oder keine Tauchpartner erfasst';

  @override
  String diveLog_detail_speciesCount(Object count) {
    return '$count Arten';
  }

  @override
  String get diveLog_detail_stat_bottomTime => 'Grundzeit';

  @override
  String get diveLog_detail_stat_maxDepth => 'Max. Tiefe';

  @override
  String get diveLog_detail_stat_runtime => 'Laufzeit';

  @override
  String get diveLog_detail_stat_waterTemp => 'Wassertemp.';

  @override
  String diveLog_detail_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tags',
      one: 'Tag',
    );
    return '$count $_temp0';
  }

  @override
  String diveLog_detail_tankCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Flaschen',
      one: 'Flasche',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_tideCalculated => 'Berechnet aus Gezeitenmodell';

  @override
  String get diveLog_detail_tooltip_addToFavorites =>
      'Zu Favoriten hinzufuegen';

  @override
  String get diveLog_detail_tooltip_edit => 'Bearbeiten';

  @override
  String get diveLog_detail_tooltip_editDive => 'Tauchgang bearbeiten';

  @override
  String get diveLog_detail_tooltip_exportProfileImage =>
      'Profil als Bild exportieren';

  @override
  String get diveLog_detail_tooltip_removeFromFavorites =>
      'Aus Favoriten entfernen';

  @override
  String get diveLog_detail_tooltip_viewFullscreen => 'Vollbild anzeigen';

  @override
  String get diveLog_detail_viewSite => 'Tauchplatz anzeigen';

  @override
  String get diveLog_diveMode_ccrDescription =>
      'Geschlossener Kreislauf Rebreather mit konstantem ppO₂';

  @override
  String get diveLog_diveMode_ocDescription =>
      'Standard-Geraetetauchen mit offenem Kreislauf und Flaschen';

  @override
  String get diveLog_diveMode_scrDescription =>
      'Halbgeschlossener Rebreather mit variablem ppO₂';

  @override
  String get diveLog_diveMode_title => 'Tauchmodus';

  @override
  String get diveLog_editSighting_count => 'Anzahl';

  @override
  String get diveLog_editSighting_notes => 'Notizen';

  @override
  String get diveLog_editSighting_notesHint => 'Groesse, Verhalten, Fundort...';

  @override
  String get diveLog_editSighting_remove => 'Entfernen';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return '$name von diesem Tauchgang entfernen?';
  }

  @override
  String get diveLog_editSighting_removeTitle => 'Sichtung entfernen?';

  @override
  String get diveLog_editSighting_save => 'Aenderungen speichern';

  @override
  String get diveLog_edit_add => 'Hinzufuegen';

  @override
  String get diveLog_edit_addCustomField => 'Add Field';

  @override
  String get diveLog_edit_addTank => 'Flasche hinzufuegen';

  @override
  String get diveLog_edit_addWeightEntry => 'Gewichtseintrag hinzufuegen';

  @override
  String diveLog_edit_addedGps(Object name) {
    return 'GPS zu $name hinzugefuegt';
  }

  @override
  String get diveLog_edit_appBarEdit => 'Tauchgang bearbeiten';

  @override
  String get diveLog_edit_appBarNew => 'Tauchgang erfassen';

  @override
  String get diveLog_edit_cancel => 'Abbrechen';

  @override
  String get diveLog_edit_clearAllEquipment => 'Alle entfernen';

  @override
  String diveLog_edit_createdSite(Object name) {
    return 'Tauchplatz erstellt: $name';
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
    return 'Dauer: $minutes min';
  }

  @override
  String get diveLog_edit_equipmentHint =>
      'Tippen Sie auf \"Set verwenden\" oder \"Hinzufuegen\" um Ausruestung auszuwaehlen';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return 'Fehler beim Laden der Tauchgangsarten: $error';
  }

  @override
  String get diveLog_edit_gettingLocation => 'Standort wird ermittelt...';

  @override
  String get diveLog_edit_headerNew => 'Neuen Tauchgang erfassen';

  @override
  String get diveLog_edit_label_airTemp => 'Lufttemperatur';

  @override
  String get diveLog_edit_label_altitude => 'Hoehe';

  @override
  String get diveLog_edit_label_avgDepth => 'Durchschn. Tiefe';

  @override
  String get diveLog_edit_label_bottomTime => 'Grundzeit';

  @override
  String get diveLog_edit_label_currentDirection => 'Stroemungsrichtung';

  @override
  String get diveLog_edit_label_currentStrength => 'Stroemungsstaerke';

  @override
  String get diveLog_edit_label_diveType => 'Tauchgangart';

  @override
  String get diveLog_edit_label_entryMethod => 'Einstiegsmethode';

  @override
  String get diveLog_edit_label_exitMethod => 'Ausstiegsmethode';

  @override
  String get diveLog_edit_label_maxDepth => 'Max. Tiefe';

  @override
  String get diveLog_edit_label_runtime => 'Laufzeit';

  @override
  String get diveLog_edit_label_surfacePressure => 'Oberflaechendruck';

  @override
  String get diveLog_edit_label_swellHeight => 'Wellenhoehe';

  @override
  String get diveLog_edit_label_type => 'Typ';

  @override
  String get diveLog_edit_label_visibility => 'Sichtweite';

  @override
  String get diveLog_edit_label_waterTemp => 'Wassertemp.';

  @override
  String get diveLog_edit_label_waterType => 'Wasserart';

  @override
  String get diveLog_edit_marineLifeHint =>
      'Tippen Sie auf \"Hinzufuegen\" um Sichtungen zu erfassen';

  @override
  String get diveLog_edit_nearbySitesFirst => 'Nahe Tauchplaetze zuerst';

  @override
  String get diveLog_edit_noEquipmentSelected =>
      'Keine Ausruestung ausgewaehlt';

  @override
  String get diveLog_edit_noMarineLife => 'Keine Meeresfauna erfasst';

  @override
  String get diveLog_edit_notSpecified => 'Nicht angegeben';

  @override
  String get diveLog_edit_notesHint =>
      'Notizen zu diesem Tauchgang hinzufuegen...';

  @override
  String get diveLog_edit_save => 'Speichern';

  @override
  String get diveLog_edit_saveAsSet => 'Als Set speichern';

  @override
  String diveLog_edit_saveAsSetDialog_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gegenstaende',
      one: 'Gegenstand',
    );
    return '$count $_temp0 als neues Ausruestungsset speichern.';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description =>
      'Beschreibung (optional)';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint =>
      'z.B. Leichte Ausruestung fuer warmes Wasser';

  @override
  String diveLog_edit_saveAsSetDialog_error(Object error) {
    return 'Fehler beim Erstellen des Sets: $error';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_setName => 'Set-Name';

  @override
  String get diveLog_edit_saveAsSetDialog_setNameHint => 'z.B. Tropentauchen';

  @override
  String diveLog_edit_saveAsSetDialog_success(Object name) {
    return 'Ausruestungsset \"$name\" erstellt';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title =>
      'Als Ausruestungsset speichern';

  @override
  String get diveLog_edit_saveAsSetDialog_validation =>
      'Bitte geben Sie einen Set-Namen ein';

  @override
  String get diveLog_edit_section_conditions => 'Bedingungen';

  @override
  String get diveLog_edit_section_customFields => 'Custom Fields';

  @override
  String get diveLog_edit_section_depthDuration => 'Tiefe & Dauer';

  @override
  String get diveLog_edit_section_diveCenter => 'Tauchbasis';

  @override
  String get diveLog_edit_section_diveSite => 'Tauchplatz';

  @override
  String get diveLog_edit_section_entryTime => 'Einstiegszeit';

  @override
  String get diveLog_edit_section_equipment => 'Ausruestung';

  @override
  String get diveLog_edit_section_exitTime => 'Ausstiegszeit';

  @override
  String get diveLog_edit_section_marineLife => 'Meeresfauna';

  @override
  String get diveLog_edit_section_notes => 'Notizen';

  @override
  String get diveLog_edit_section_rating => 'Bewertung';

  @override
  String get diveLog_edit_section_tags => 'Tags';

  @override
  String diveLog_edit_section_tanks(Object count) {
    return 'Flaschen ($count)';
  }

  @override
  String get diveLog_edit_section_trainingCourse => 'Ausbildungskurs';

  @override
  String get diveLog_edit_section_trip => 'Reise';

  @override
  String get diveLog_edit_section_weight => 'Gewicht';

  @override
  String get diveLog_edit_select => 'Auswaehlen';

  @override
  String get diveLog_edit_selectDiveCenter => 'Tauchbasis auswaehlen';

  @override
  String get diveLog_edit_selectDiveSite => 'Tauchplatz auswaehlen';

  @override
  String get diveLog_edit_selectTrip => 'Reise auswaehlen';

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Grundzeit berechnet: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Fehler beim Speichern des Tauchgangs: $error';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'Keine Tauchprofildaten verfuegbar';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Grundzeit konnte nicht aus dem Profil berechnet werden';

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return 'Oberflaechenintervall: $interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint =>
      'Standard: 1013 mbar auf Meereshoehe';

  @override
  String get diveLog_edit_tooltip_calculateFromProfile =>
      'Aus Tauchprofil berechnen';

  @override
  String get diveLog_edit_tooltip_clearDiveCenter => 'Tauchbasis entfernen';

  @override
  String get diveLog_edit_tooltip_clearSite => 'Tauchplatz entfernen';

  @override
  String get diveLog_edit_tooltip_clearTrip => 'Reise entfernen';

  @override
  String get diveLog_edit_tooltip_removeEquipment => 'Ausruestung entfernen';

  @override
  String get diveLog_edit_tooltip_removeSighting => 'Sichtung entfernen';

  @override
  String get diveLog_edit_tooltip_removeWeight => 'Entfernen';

  @override
  String get diveLog_edit_trainingCourseHint =>
      'Diesen Tauchgang mit einem Ausbildungskurs verknuepfen';

  @override
  String diveLog_edit_tripSuggested(Object name) {
    return 'Vorgeschlagen: $name';
  }

  @override
  String get diveLog_edit_tripUse => 'Verwenden';

  @override
  String get diveLog_edit_useSet => 'Set verwenden';

  @override
  String diveLog_edit_weightTotal(Object total) {
    return 'Gesamt: $total';
  }

  @override
  String get diveLog_emptyFiltered_clearFilters => 'Filter zuruecksetzen';

  @override
  String get diveLog_emptyFiltered_subtitle =>
      'Versuchen Sie, Ihre Filter anzupassen oder zurueckzusetzen';

  @override
  String get diveLog_emptyFiltered_title =>
      'Keine Tauchgaenge entsprechen Ihren Filtern';

  @override
  String get diveLog_empty_logFirstDive => 'Ersten Tauchgang erfassen';

  @override
  String get diveLog_empty_subtitle =>
      'Tippen Sie auf die Schaltflaeche unten, um Ihren ersten Tauchgang zu erfassen';

  @override
  String get diveLog_empty_title => 'Noch keine Tauchgaenge erfasst';

  @override
  String get diveLog_equipmentPicker_addFromTab =>
      'Ausruestung ueber den Ausruestungs-Tab hinzufuegen';

  @override
  String get diveLog_equipmentPicker_allSelected =>
      'Gesamte Ausruestung bereits ausgewaehlt';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return 'Fehler beim Laden der Ausruestung: $error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => 'Noch keine Ausruestung';

  @override
  String get diveLog_equipmentPicker_removeToAdd =>
      'Entfernen Sie Gegenstaende, um andere hinzuzufuegen';

  @override
  String get diveLog_equipmentPicker_title => 'Ausruestung hinzufuegen';

  @override
  String get diveLog_equipmentSetPicker_createHint =>
      'Sets unter Ausruestung > Sets erstellen';

  @override
  String get diveLog_equipmentSetPicker_emptySet => 'Leeres Set';

  @override
  String get diveLog_equipmentSetPicker_errorItems =>
      'Fehler beim Laden der Gegenstaende';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return 'Fehler beim Laden der Ausruestungssets: $error';
  }

  @override
  String get diveLog_equipmentSetPicker_loading => 'Wird geladen...';

  @override
  String get diveLog_equipmentSetPicker_noSets => 'Noch keine Ausruestungssets';

  @override
  String get diveLog_equipmentSetPicker_title => 'Ausruestungsset verwenden';

  @override
  String get diveLog_error_loadingDives => 'Fehler beim Laden der Tauchgaenge';

  @override
  String get diveLog_error_retry => 'Erneut versuchen';

  @override
  String get diveLog_exportImage_captureFailed =>
      'Bild konnte nicht aufgenommen werden';

  @override
  String get diveLog_exportImage_generateFailed =>
      'Bild konnte nicht erstellt werden';

  @override
  String get diveLog_exportImage_generatingPdf => 'PDF wird erstellt...';

  @override
  String get diveLog_exportImage_pdfSaved => 'PDF gespeichert';

  @override
  String get diveLog_exportImage_saveToFiles => 'In Dateien speichern';

  @override
  String get diveLog_exportImage_saveToFilesDescription =>
      'Waehlen Sie einen Speicherort fuer die Datei';

  @override
  String get diveLog_exportImage_saveToPhotos => 'In Fotos speichern';

  @override
  String get diveLog_exportImage_saveToPhotosDescription =>
      'Bild in Ihrer Fotomediathek speichern';

  @override
  String get diveLog_exportImage_savedToFiles => 'Bild gespeichert';

  @override
  String get diveLog_exportImage_savedToPhotos => 'Bild in Fotos gespeichert';

  @override
  String get diveLog_exportImage_share => 'Teilen';

  @override
  String get diveLog_exportImage_shareDescription => 'Ueber andere Apps teilen';

  @override
  String get diveLog_exportImage_titleDetails =>
      'Tauchgang-Details als Bild exportieren';

  @override
  String get diveLog_exportImage_titlePdf => 'PDF exportieren';

  @override
  String get diveLog_exportImage_titleProfile => 'Profilbild exportieren';

  @override
  String get diveLog_export_csv => 'CSV';

  @override
  String get diveLog_export_csvDescription => 'Tabellenformat';

  @override
  String get diveLog_export_exporting => 'Wird exportiert...';

  @override
  String diveLog_export_failed(Object error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get diveLog_export_pageAsImage => 'Seite als Bild';

  @override
  String get diveLog_export_pageAsImageDescription =>
      'Screenshot der gesamten Tauchgang-Details';

  @override
  String get diveLog_export_pdfDescription => 'Druckbare Tauchlogbuchseite';

  @override
  String get diveLog_export_pdfLogbookEntry => 'PDF-Logbucheintrag';

  @override
  String get diveLog_export_success => 'Tauchgang erfolgreich exportiert';

  @override
  String diveLog_export_titleDiveNumber(Object number) {
    return 'Tauchgang #$number exportieren';
  }

  @override
  String get diveLog_export_uddf => 'UDDF';

  @override
  String get diveLog_export_uddfDescription => 'Universal Dive Data Format';

  @override
  String get diveLog_filterChip_clearAll => 'Alle zuruecksetzen';

  @override
  String get diveLog_filterChip_favorites => 'Favoriten';

  @override
  String diveLog_filterChip_from(Object date) {
    return 'Von $date';
  }

  @override
  String diveLog_filterChip_until(Object date) {
    return 'Bis $date';
  }

  @override
  String get diveLog_filter_allSites => 'Alle Tauchplaetze';

  @override
  String get diveLog_filter_allTypes => 'Alle Typen';

  @override
  String get diveLog_filter_apply => 'Filter anwenden';

  @override
  String get diveLog_filter_buddyHint => 'Nach Tauchpartnername suchen';

  @override
  String get diveLog_filter_buddyName => 'Tauchpartnername';

  @override
  String get diveLog_filter_clearAll => 'Alle zuruecksetzen';

  @override
  String get diveLog_filter_clearDates => 'Daten zuruecksetzen';

  @override
  String get diveLog_filter_clearRating => 'Bewertungsfilter zuruecksetzen';

  @override
  String get diveLog_filter_dateSeparator => 'bis';

  @override
  String get diveLog_filter_endDate => 'Enddatum';

  @override
  String get diveLog_filter_errorLoadingSites =>
      'Fehler beim Laden der Tauchplaetze';

  @override
  String get diveLog_filter_errorLoadingTags => 'Fehler beim Laden der Tags';

  @override
  String get diveLog_filter_favoritesOnly => 'Nur Favoriten';

  @override
  String get diveLog_filter_gasAir => 'Luft (21%)';

  @override
  String get diveLog_filter_gasAll => 'Alle';

  @override
  String get diveLog_filter_gasNitrox => 'Nitrox (>21%)';

  @override
  String get diveLog_filter_max => 'Max';

  @override
  String get diveLog_filter_min => 'Min';

  @override
  String get diveLog_filter_noTagsYet => 'Noch keine Tags erstellt';

  @override
  String get diveLog_filter_sectionBuddy => 'Tauchpartner';

  @override
  String get diveLog_filter_sectionDateRange => 'Datumsbereich';

  @override
  String get diveLog_filter_sectionDepthRange => 'Tiefenbereich (Meter)';

  @override
  String get diveLog_filter_sectionDiveSite => 'Tauchplatz';

  @override
  String get diveLog_filter_sectionDiveType => 'Tauchgangart';

  @override
  String get diveLog_filter_sectionDuration => 'Dauer (Minuten)';

  @override
  String get diveLog_filter_sectionGasMix => 'Gasgemisch (O₂%)';

  @override
  String get diveLog_filter_sectionMinRating => 'Mindestbewertung';

  @override
  String get diveLog_filter_sectionTags => 'Tags';

  @override
  String get diveLog_filter_showOnlyFavorites => 'Nur Favoriten anzeigen';

  @override
  String get diveLog_filter_startDate => 'Startdatum';

  @override
  String get diveLog_filter_title => 'Tauchgaenge filtern';

  @override
  String get diveLog_filter_tooltip_close => 'Filter schliessen';

  @override
  String get diveLog_fullscreenProfile_close => 'Vollbild schliessen';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Tauchgang #$number Profil';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Aufstiegsgeschwindigkeit';

  @override
  String get diveLog_legend_label_ceiling => 'Ceiling';

  @override
  String get diveLog_legend_label_depth => 'Tiefe';

  @override
  String get diveLog_legend_label_events => 'Ereignisse';

  @override
  String get diveLog_legend_label_gasDensity => 'Gasdichte';

  @override
  String get diveLog_legend_label_gasSwitches => 'Gaswechsel';

  @override
  String get diveLog_legend_label_gfPercent => 'GF%';

  @override
  String get diveLog_legend_label_heartRate => 'Herzfrequenz';

  @override
  String get diveLog_legend_label_maxDepth => 'Max. Tiefe';

  @override
  String get diveLog_legend_label_meanDepth => 'Durchschnittstiefe';

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
  String get diveLog_legend_label_pressure => 'Druck';

  @override
  String get diveLog_legend_label_pressureThresholds => 'Druckschwellen';

  @override
  String get diveLog_legend_label_sacRate => 'SAC-Rate';

  @override
  String get diveLog_legend_label_surfaceGf => 'Oberflaechenm GF';

  @override
  String get diveLog_legend_label_temp => 'Temp.';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Tauchkarte';

  @override
  String get diveLog_listPage_compactTitle => 'Tauchgaenge';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get diveLog_listPage_bottomSheet_importFromComputer =>
      'Vom Tauchcomputer importieren';

  @override
  String get diveLog_listPage_bottomSheet_logManually =>
      'Tauchgang manuell erfassen';

  @override
  String get diveLog_listPage_fab_addDive => 'Tauchgang hinzufugen';

  @override
  String get diveLog_listPage_fab_logDive => 'Tauchgang erfassen';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Erweiterte Suche';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Tauchgangnummerierung';

  @override
  String get diveLog_listPage_searchFieldLabel => 'Tauchgaenge suchen...';

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return 'Keine Tauchgaenge gefunden fuer \"$query\"';
  }

  @override
  String get diveLog_listPage_searchSuggestion =>
      'Nach Tauchplatz, Tauchpartner oder Notizen suchen';

  @override
  String get diveLog_listPage_title => 'Tauchlogbuch';

  @override
  String get diveLog_listPage_tooltip_back => 'Zurueck';

  @override
  String get diveLog_listPage_tooltip_backToDiveList =>
      'Zurueck zur Tauchgangliste';

  @override
  String get diveLog_listPage_tooltip_clearSearch => 'Suche loeschen';

  @override
  String get diveLog_listPage_tooltip_filterDives => 'Tauchgaenge filtern';

  @override
  String get diveLog_listPage_tooltip_listView => 'Listenansicht';

  @override
  String get diveLog_listPage_tooltip_mapView => 'Kartenansicht';

  @override
  String get diveLog_listPage_tooltip_searchDives => 'Tauchgaenge suchen';

  @override
  String get diveLog_listPage_tooltip_sort => 'Sortieren';

  @override
  String get diveLog_listPage_unknownSite => 'Unbekannter Tauchplatz';

  @override
  String get diveLog_map_emptySubtitle =>
      'Erfassen Sie Tauchgaenge mit Standortdaten, um Ihre Aktivitaet auf der Karte zu sehen';

  @override
  String get diveLog_map_emptyTitle => 'Keine Tauchaktivitaet zum Anzeigen';

  @override
  String diveLog_map_errorLoading(Object error) {
    return 'Fehler beim Laden der Tauchdaten: $error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => 'Alle Tauchplaetze anzeigen';

  @override
  String get diveLog_numbering_actions => 'Aktionen';

  @override
  String get diveLog_numbering_allCorrect =>
      'Alle Tauchgaenge korrekt nummeriert';

  @override
  String get diveLog_numbering_assignMissing => 'Fehlende Nummern zuweisen';

  @override
  String get diveLog_numbering_assignMissingDesc =>
      'Nicht nummerierte Tauchgaenge ab der letzten vergebenen Nummer nummerieren';

  @override
  String get diveLog_numbering_close => 'Schliessen';

  @override
  String get diveLog_numbering_gapsDetected => 'Luecken erkannt';

  @override
  String get diveLog_numbering_issuesDetected => 'Probleme erkannt';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '$count fehlend';
  }

  @override
  String get diveLog_numbering_renumberAll =>
      'Alle Tauchgaenge neu nummerieren';

  @override
  String get diveLog_numbering_renumberAllDesc =>
      'Fortlaufende Nummern basierend auf Datum/Uhrzeit des Tauchgangs zuweisen';

  @override
  String get diveLog_numbering_renumberDialog_cancel => 'Abbrechen';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      'Alle Tauchgaenge werden basierend auf dem Einstiegsdatum/-zeit fortlaufend neu nummeriert. Diese Aktion kann nicht rueckgaengig gemacht werden.';

  @override
  String get diveLog_numbering_renumberDialog_renumber => 'Neu nummerieren';

  @override
  String get diveLog_numbering_renumberDialog_startFrom => 'Startnummer';

  @override
  String get diveLog_numbering_renumberDialog_title =>
      'Alle Tauchgaenge neu nummerieren';

  @override
  String get diveLog_numbering_snackbar_assigned =>
      'Fehlende Tauchgangnummern zugewiesen';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return 'Alle Tauchgaenge ab #$number neu nummeriert';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '$total Tauchgaenge gesamt - $numbered nummeriert';
  }

  @override
  String get diveLog_numbering_title => 'Tauchgangnummerierung';

  @override
  String diveLog_numbering_unnumberedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    return '$count $_temp0 ohne Nummer';
  }

  @override
  String get diveLog_o2tox_badge_critical => 'KRITISCH';

  @override
  String get diveLog_o2tox_badge_warning => 'WARNUNG';

  @override
  String diveLog_o2tox_cnsBadgeLabel(Object value) {
    return 'CNS $value';
  }

  @override
  String get diveLog_o2tox_cnsOxygenClock => 'CNS-Sauerstoffuhr';

  @override
  String diveLog_o2tox_deltaDive(Object value) {
    return '+$value% bei diesem Tauchgang';
  }

  @override
  String get diveLog_o2tox_details => 'Details';

  @override
  String get diveLog_o2tox_label_maxPpO2 => 'Max. ppO2';

  @override
  String get diveLog_o2tox_label_maxPpO2Depth => 'Tiefe bei max. ppO2';

  @override
  String get diveLog_o2tox_label_timeAbove14 => 'Zeit ueber 1,4 bar';

  @override
  String get diveLog_o2tox_label_timeAbove16 => 'Zeit ueber 1,6 bar';

  @override
  String get diveLog_o2tox_ofDailyLimit => 'des Tageslimits';

  @override
  String get diveLog_o2tox_oxygenToleranceUnits =>
      'Sauerstofftoleranzeinheiten';

  @override
  String diveLog_o2tox_semantics_cnsBadge(Object value) {
    return 'CNS-Sauerstofftoxizität $value';
  }

  @override
  String get diveLog_o2tox_semantics_criticalWarning =>
      'Kritische Sauerstofftoxizitaetswarnung';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return 'Sauerstofftoleranzeinheiten: $value, $percent Prozent des Tageslimits';
  }

  @override
  String get diveLog_o2tox_semantics_warning => 'Sauerstofftoxizitaetswarnung';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return 'Start: $value%';
  }

  @override
  String get diveLog_o2tox_title => 'Sauerstofftoxizitaet';

  @override
  String get diveLog_playbackStats_deco => 'DEKO';

  @override
  String get diveLog_playbackStats_depth => 'Tiefe';

  @override
  String get diveLog_playbackStats_header => 'Live-Statistiken';

  @override
  String get diveLog_playbackStats_heartRate => 'Herzfrequenz';

  @override
  String get diveLog_playbackStats_ndl => 'NDL';

  @override
  String get diveLog_playbackStats_ppO2 => 'ppO₂';

  @override
  String get diveLog_playbackStats_pressure => 'Druck';

  @override
  String get diveLog_playbackStats_temp => 'Temp.';

  @override
  String get diveLog_playback_sliderLabel => 'Wiedergabeposition';

  @override
  String diveLog_playback_speed_label(Object speed) {
    return '${speed}x';
  }

  @override
  String get diveLog_playback_stepThrough => 'Schrittweise Wiedergabe';

  @override
  String get diveLog_playback_tooltip_back10 => '10 Sekunden zurueck';

  @override
  String get diveLog_playback_tooltip_exit => 'Wiedergabemodus beenden';

  @override
  String get diveLog_playback_tooltip_forward10 => '10 Sekunden vor';

  @override
  String get diveLog_playback_tooltip_pause => 'Pause';

  @override
  String get diveLog_playback_tooltip_play => 'Abspielen';

  @override
  String get diveLog_playback_tooltip_skipEnd => 'Zum Ende springen';

  @override
  String get diveLog_playback_tooltip_skipStart => 'Zum Anfang springen';

  @override
  String get diveLog_playback_tooltip_speed => 'Wiedergabegeschwindigkeit';

  @override
  String get diveLog_profileSelector_badge_primary => 'Primaer';

  @override
  String get diveLog_profileSelector_label_diveComputers => 'Tauchcomputer';

  @override
  String diveLog_profile_axisDepth(Object unit) {
    return 'Tiefe ($unit)';
  }

  @override
  String get diveLog_profile_axisTime => 'Zeit (min)';

  @override
  String get diveLog_profile_emptyState => 'Keine Tauchprofildaten';

  @override
  String get diveLog_profile_rightAxis_none => 'Keine';

  @override
  String get diveLog_profile_semantics_changeRightAxis =>
      'Rechte Achsenmetrik aendern';

  @override
  String get diveLog_profile_semantics_chart =>
      'Tauchprofildiagramm, zum Zoomen zusammendruecken';

  @override
  String get diveLog_profile_tooltip_moreOptions => 'Weitere Diagrammoptionen';

  @override
  String get diveLog_profile_tooltip_resetZoom => 'Zoom zuruecksetzen';

  @override
  String get diveLog_profile_tooltip_zoomIn => 'Vergroessern';

  @override
  String get diveLog_profile_tooltip_zoomOut => 'Verkleinern';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return 'Zoom: ${level}x - Zum Zoomen zusammendruecken oder scrollen, zum Verschieben ziehen';
  }

  @override
  String get diveLog_rangeSelection_exitRange => 'Bereich beenden';

  @override
  String get diveLog_rangeSelection_selectRange => 'Bereich auswaehlen';

  @override
  String get diveLog_rangeSelection_semantics_adjust =>
      'Bereichsauswahl anpassen';

  @override
  String get diveLog_rangeStats_header_avg => 'Durchschn.';

  @override
  String get diveLog_rangeStats_header_max => 'Max';

  @override
  String get diveLog_rangeStats_header_min => 'Min';

  @override
  String get diveLog_rangeStats_label_depth => 'Tiefe';

  @override
  String get diveLog_rangeStats_label_heartRate => 'Herzfrequenz';

  @override
  String get diveLog_rangeStats_label_pressure => 'Druck';

  @override
  String get diveLog_rangeStats_label_temp => 'Temp.';

  @override
  String get diveLog_rangeStats_title => 'Bereichsanalyse';

  @override
  String get diveLog_rangeStats_tooltip_close => 'Bereichsanalyse schliessen';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return 'Berechneter Loop-FO₂: $value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => 'z.B. 0,33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => 'Zumischungsverhaeltnis';

  @override
  String get diveLog_scr_label_assumedVo2 => 'Angenommener VO₂';

  @override
  String get diveLog_scr_label_avg => 'Durchschn.';

  @override
  String get diveLog_scr_label_injectionRate => 'Injektionsrate';

  @override
  String get diveLog_scr_label_max => 'Max';

  @override
  String get diveLog_scr_label_min => 'Min';

  @override
  String get diveLog_scr_label_orificeSize => 'Duesengroesse';

  @override
  String get diveLog_scr_sectionCmf => 'CMF-Parameter';

  @override
  String get diveLog_scr_sectionEscr => 'ESCR-Parameter';

  @override
  String get diveLog_scr_sectionMeasuredLoopO2 =>
      'Gemessener Loop-O₂ (optional)';

  @override
  String get diveLog_scr_sectionPascr => 'PASCR-Parameter';

  @override
  String get diveLog_scr_sectionScrType => 'SCR-Typ';

  @override
  String get diveLog_scr_sectionSupplyGas => 'Versorgungsgas';

  @override
  String get diveLog_scr_title => 'SCR-Einstellungen';

  @override
  String get diveLog_search_allCenters => 'Alle Tauchbasen';

  @override
  String get diveLog_search_allTrips => 'Alle Reisen';

  @override
  String get diveLog_search_appBar => 'Erweiterte Suche';

  @override
  String get diveLog_search_cancel => 'Abbrechen';

  @override
  String get diveLog_search_clearAll => 'Alles loeschen';

  @override
  String get diveLog_search_customFieldKey => 'Custom Field Key';

  @override
  String get diveLog_search_customFieldValue => 'Value contains...';

  @override
  String get diveLog_search_end => 'Ende';

  @override
  String get diveLog_search_errorLoadingCenters =>
      'Fehler beim Laden der Tauchbasen';

  @override
  String get diveLog_search_errorLoadingDiveTypes =>
      'Fehler beim Laden der Tauchgangstypen';

  @override
  String get diveLog_search_errorLoadingTrips => 'Fehler beim Laden der Reisen';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_depthRange => 'Tiefenbereich (m)';

  @override
  String get diveLog_search_label_diveCenter => 'Tauchbasis';

  @override
  String get diveLog_search_label_diveSite => 'Tauchplatz';

  @override
  String get diveLog_search_label_diveType => 'Tauchgangart';

  @override
  String get diveLog_search_label_durationRange => 'Dauerbereich (min)';

  @override
  String get diveLog_search_label_trip => 'Reise';

  @override
  String get diveLog_search_search => 'Suchen';

  @override
  String get diveLog_search_section_conditions => 'Bedingungen';

  @override
  String get diveLog_search_section_dateRange => 'Zeitraum';

  @override
  String get diveLog_search_section_gasEquipment => 'Gas & Ausruestung';

  @override
  String get diveLog_search_section_location => 'Ort';

  @override
  String get diveLog_search_section_organization => 'Organisation';

  @override
  String get diveLog_search_section_social => 'Soziales';

  @override
  String get diveLog_search_start => 'Start';

  @override
  String diveLog_selection_countSelected(Object count) {
    return '$count ausgewaehlt';
  }

  @override
  String get diveLog_selection_tooltip_delete => 'Auswahl loeschen';

  @override
  String get diveLog_selection_tooltip_deselectAll => 'Alle abwaehlen';

  @override
  String get diveLog_selection_tooltip_edit => 'Auswahl bearbeiten';

  @override
  String get diveLog_selection_tooltip_exit => 'Auswahl beenden';

  @override
  String get diveLog_selection_tooltip_export => 'Auswahl exportieren';

  @override
  String get diveLog_selection_tooltip_selectAll => 'Alle auswaehlen';

  @override
  String get diveLog_sighting_add => 'Hinzufuegen';

  @override
  String get diveLog_sighting_cancel => 'Abbrechen';

  @override
  String get diveLog_sighting_notesHint => 'z. B. Groesse, Verhalten, Ort...';

  @override
  String get diveLog_sighting_notesOptional => 'Notizen (optional)';

  @override
  String get diveLog_sitePicker_addDiveSite => 'Tauchplatz hinzufuegen';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return '$distance km entfernt';
  }

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return '$distance m entfernt';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return 'Fehler beim Laden der Plaetze: $error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => 'Neuer Tauchplatz';

  @override
  String get diveLog_sitePicker_noSites => 'Noch keine Tauchplaetze';

  @override
  String get diveLog_sitePicker_sortedByDistance => 'Nach Entfernung sortiert';

  @override
  String get diveLog_sitePicker_title => 'Tauchplatz auswaehlen';

  @override
  String get diveLog_sort_title => 'Tauchgaenge sortieren';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return '\"$name\" als neue Art hinzufuegen';
  }

  @override
  String get diveLog_speciesPicker_noResults => 'Keine Arten gefunden';

  @override
  String get diveLog_speciesPicker_noSpecies => 'Keine Arten verfuegbar';

  @override
  String get diveLog_speciesPicker_searchHint => 'Arten suchen...';

  @override
  String get diveLog_speciesPicker_title => 'Meeresbewohner hinzufuegen';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch => 'Suche loeschen';

  @override
  String get diveLog_summary_action_importComputer =>
      'Vom Computer importieren';

  @override
  String get diveLog_summary_action_logDive => 'Tauchgang eintragen';

  @override
  String get diveLog_summary_action_viewStats => 'Statistiken anzeigen';

  @override
  String diveLog_summary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_summary_overview => 'Uebersicht';

  @override
  String get diveLog_summary_record_coldest => 'Kaeltester Tauchgang';

  @override
  String get diveLog_summary_record_deepest => 'Tiefster Tauchgang';

  @override
  String get diveLog_summary_record_longest => 'Laengster Tauchgang';

  @override
  String get diveLog_summary_record_warmest => 'Waermster Tauchgang';

  @override
  String get diveLog_summary_section_mostVisited =>
      'Meistbesuchte Tauchplaetze';

  @override
  String get diveLog_summary_section_quickActions => 'Schnellaktionen';

  @override
  String get diveLog_summary_section_records => 'Persoenliche Rekorde';

  @override
  String get diveLog_summary_selectDive =>
      'Waehlen Sie einen Tauchgang aus der Liste, um Details anzuzeigen';

  @override
  String get diveLog_summary_stat_avgMaxDepth => 'Durchschn. max. Tiefe';

  @override
  String get diveLog_summary_stat_avgWaterTemp => 'Durchschn. Wassertemp.';

  @override
  String get diveLog_summary_stat_diveSites => 'Tauchplaetze';

  @override
  String get diveLog_summary_stat_diveTime => 'Tauchzeit';

  @override
  String get diveLog_summary_stat_maxDepth => 'Max. Tiefe';

  @override
  String get diveLog_summary_stat_totalDives => 'Tauchgaenge gesamt';

  @override
  String get diveLog_summary_title => 'Tauchlogbuch-Zusammenfassung';

  @override
  String get diveLog_tank_label_endPressure => 'Enddruck';

  @override
  String get diveLog_tank_label_he => 'He';

  @override
  String get diveLog_tank_label_material => 'Material';

  @override
  String get diveLog_tank_label_n2 => 'N2';

  @override
  String get diveLog_tank_label_o2 => 'O2';

  @override
  String get diveLog_tank_label_role => 'Rolle';

  @override
  String get diveLog_tank_label_startPressure => 'Anfangsdruck';

  @override
  String get diveLog_tank_label_tankPreset => 'Flaschenvorlage';

  @override
  String get diveLog_tank_label_volume => 'Volumen';

  @override
  String get diveLog_tank_label_workingPressure => 'Betriebsdruck';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1,4)';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Gasgemisch';

  @override
  String get diveLog_tank_selectPreset => 'Vorlage auswaehlen...';

  @override
  String diveLog_tank_title(Object number) {
    return 'Flasche $number';
  }

  @override
  String get diveLog_tank_tooltip_remove => 'Flasche entfernen';

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
  String get diveLog_tissue_legend_mValue => '100% M-Wert';

  @override
  String get diveLog_tissue_legend_n2 => 'N₂';

  @override
  String get diveLog_tissue_title => 'Gewebesaettigung';

  @override
  String get diveLog_tooltip_ceiling => 'Ceiling';

  @override
  String get diveLog_tooltip_density => 'Dichte';

  @override
  String get diveLog_tooltip_depth => 'Tiefe';

  @override
  String get diveLog_tooltip_gfPercent => 'GF%';

  @override
  String get diveLog_tooltip_hr => 'HF';

  @override
  String get diveLog_tooltip_marker => 'Marker';

  @override
  String get diveLog_tooltip_mean => 'Mittel';

  @override
  String get diveLog_tooltip_mod => 'MOD';

  @override
  String get diveLog_tooltip_ndl => 'Nullzeit';

  @override
  String get diveLog_tooltip_ppHe => 'ppHe';

  @override
  String get diveLog_tooltip_ppN2 => 'ppN2';

  @override
  String get diveLog_tooltip_ppO2 => 'ppO2';

  @override
  String get diveLog_tooltip_press => 'Druck';

  @override
  String get diveLog_tooltip_rate => 'Rate';

  @override
  String get diveLog_tooltip_sac => 'AMV';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Zeit';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get divePlanner_action_addTank => 'Flasche hinzufügen';

  @override
  String get divePlanner_action_convertToDive => 'In Tauchgang umwandeln';

  @override
  String get divePlanner_action_editTank => 'Flasche bearbeiten';

  @override
  String get divePlanner_action_moreOptions => 'Weitere Optionen';

  @override
  String get divePlanner_action_quickPlan => 'Schnellplanung';

  @override
  String get divePlanner_action_renamePlan => 'Plan umbenennen';

  @override
  String get divePlanner_action_reset => 'Zurücksetzen';

  @override
  String get divePlanner_action_resetPlan => 'Plan zurücksetzen';

  @override
  String get divePlanner_action_savePlan => 'Plan speichern';

  @override
  String get divePlanner_error_cannotConvert =>
      'Kann nicht konvertieren: Plan hat kritische Warnungen';

  @override
  String get divePlanner_field_hePercent => 'He %';

  @override
  String get divePlanner_field_name => 'Name';

  @override
  String get divePlanner_field_o2Percent => 'O₂ %';

  @override
  String get divePlanner_field_planName => 'Planname';

  @override
  String get divePlanner_field_role => 'Rolle';

  @override
  String divePlanner_field_startPressure(Object pressureSymbol) {
    return 'Startdruck ($pressureSymbol)';
  }

  @override
  String divePlanner_field_volume(Object volumeSymbol) {
    return 'Volumen ($volumeSymbol)';
  }

  @override
  String get divePlanner_hint_tankName => 'Flaschenname eingeben';

  @override
  String get divePlanner_label_altitude => 'Höhe:';

  @override
  String get divePlanner_label_belowMinReserve => 'Unter Mindestreserve';

  @override
  String get divePlanner_label_ceiling => 'Deko-Grenze';

  @override
  String get divePlanner_label_consumption => 'Verbrauch';

  @override
  String get divePlanner_label_deco => 'DEKO';

  @override
  String get divePlanner_label_decoSchedule => 'Dekompressionsplan';

  @override
  String get divePlanner_label_decompression => 'Dekompression';

  @override
  String divePlanner_label_depthAxis(Object depthSymbol) {
    return 'Tiefe ($depthSymbol)';
  }

  @override
  String get divePlanner_label_diveProfile => 'Tauchprofil';

  @override
  String get divePlanner_label_empty => 'LEER';

  @override
  String get divePlanner_label_gasConsumption => 'Gasverbrauch';

  @override
  String get divePlanner_label_gfHigh => 'GF Hoch';

  @override
  String get divePlanner_label_gfLow => 'GF Niedrig';

  @override
  String get divePlanner_label_max => 'Max';

  @override
  String get divePlanner_label_ndl => 'Nullzeit';

  @override
  String get divePlanner_label_planSettings => 'Planeinstellungen';

  @override
  String get divePlanner_label_remaining => 'Verbleibend';

  @override
  String get divePlanner_label_runtime => 'Laufzeit';

  @override
  String get divePlanner_label_sacRate => 'AMV-Rate:';

  @override
  String get divePlanner_label_status => 'Status';

  @override
  String get divePlanner_label_tanks => 'Flaschen';

  @override
  String get divePlanner_label_time => 'Zeit';

  @override
  String get divePlanner_label_timeAxis => 'Zeit (min)';

  @override
  String get divePlanner_label_tts => 'TTS';

  @override
  String get divePlanner_label_used => 'Verbraucht';

  @override
  String get divePlanner_label_warnings => 'Warnungen';

  @override
  String get divePlanner_legend_ascent => 'Aufstieg';

  @override
  String get divePlanner_legend_bottom => 'Grund';

  @override
  String get divePlanner_legend_deco => 'Deko';

  @override
  String get divePlanner_legend_descent => 'Abstieg';

  @override
  String get divePlanner_legend_safety => 'Sicherheit';

  @override
  String get divePlanner_message_addSegmentsForGas =>
      'Fügen Sie Segmente hinzu, um Gasprognosen zu sehen';

  @override
  String get divePlanner_message_addSegmentsForProfile =>
      'Fügen Sie Segmente hinzu, um das Tauchprofil zu sehen';

  @override
  String get divePlanner_message_convertingPlan =>
      'Plan wird in Tauchgang umgewandelt...';

  @override
  String get divePlanner_message_noProfile => 'Kein Profil zum Anzeigen';

  @override
  String get divePlanner_message_planSaved => 'Plan gespeichert';

  @override
  String get divePlanner_message_resetConfirmation =>
      'Möchten Sie den Plan wirklich zurücksetzen?';

  @override
  String divePlanner_semantics_criticalWarning(Object message) {
    return 'Kritische Warnung: $message';
  }

  @override
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  ) {
    return 'Deko-Stopp bei $depth für $duration mit $gasMix';
  }

  @override
  String divePlanner_semantics_gasConsumption(
    Object tankName,
    Object gasUsed,
    Object remaining,
    Object percent,
    Object warning,
  ) {
    return '$tankName: $gasUsed verbraucht, $remaining verbleibend, $percent verbraucht$warning';
  }

  @override
  String divePlanner_semantics_profileChart(
    Object maxDepth,
    Object totalMinutes,
  ) {
    return 'Tauchplan, max. Tiefe $maxDepth, Gesamtzeit $totalMinutes Minuten';
  }

  @override
  String divePlanner_semantics_warning(Object message) {
    return 'Warnung: $message';
  }

  @override
  String get divePlanner_tab_plan => 'Plan';

  @override
  String get divePlanner_tab_profile => 'Profil';

  @override
  String get divePlanner_tab_results => 'Ergebnisse';

  @override
  String get divePlanner_warning_ascentRateHigh =>
      'Aufstiegsgeschwindigkeit überschreitet sicheres Limit';

  @override
  String divePlanner_warning_ascentRateHighWithRate(Object rate) {
    return 'Aufstiegsgeschwindigkeit $rate/min überschreitet sicheres Limit';
  }

  @override
  String divePlanner_warning_belowMinReserve(Object reserve) {
    return 'Unter Mindestreserve ($reserve)';
  }

  @override
  String get divePlanner_warning_cnsCritical => 'CNS% überschreitet 100%';

  @override
  String divePlanner_warning_cnsWarning(Object threshold) {
    return 'CNS% überschreitet $threshold%';
  }

  @override
  String get divePlanner_warning_endHigh => 'Äquivalente Narkosetiefe zu hoch';

  @override
  String divePlanner_warning_endHighWithDepth(Object depth) {
    return 'END von $depth überschreitet sicheres Limit';
  }

  @override
  String divePlanner_warning_gasLow(Object threshold) {
    return 'Flasche unter $threshold Reserve';
  }

  @override
  String get divePlanner_warning_gasOut => 'Flasche wird leer sein';

  @override
  String get divePlanner_warning_minGasViolation =>
      'Minimale Gasreserve nicht eingehalten';

  @override
  String get divePlanner_warning_modViolation => 'Gaswechsel über MOD versucht';

  @override
  String get divePlanner_warning_ndlExceeded =>
      'Tauchgang geht in Dekompflicht';

  @override
  String get divePlanner_warning_otuWarning => 'OTU-Akkumulation hoch';

  @override
  String divePlanner_warning_ppO2Critical(Object value) {
    return 'ppO₂ von $value bar überschreitet kritisches Limit';
  }

  @override
  String divePlanner_warning_ppO2High(Object value) {
    return 'ppO₂ von $value bar überschreitet Arbeitslimit';
  }

  @override
  String get diveSites_detail_access_accessNotes => 'Zugangshinweise';

  @override
  String get diveSites_detail_access_mooring => 'Anlegestelle';

  @override
  String get diveSites_detail_access_parking => 'Parken';

  @override
  String get diveSites_detail_altitude_elevation => 'Hoehe';

  @override
  String get diveSites_detail_altitude_pressure => 'Druck';

  @override
  String get diveSites_detail_coordinatesCopied =>
      'Koordinaten in die Zwischenablage kopiert';

  @override
  String get diveSites_detail_deleteDialog_cancel => 'Abbrechen';

  @override
  String get diveSites_detail_deleteDialog_confirm => 'Loeschen';

  @override
  String get diveSites_detail_deleteDialog_content =>
      'Sind Sie sicher, dass Sie diesen Tauchplatz loeschen moechten? Diese Aktion kann nicht rueckgaengig gemacht werden.';

  @override
  String get diveSites_detail_deleteDialog_title => 'Tauchplatz loeschen';

  @override
  String get diveSites_detail_deleteMenu_label => 'Loeschen';

  @override
  String get diveSites_detail_deleteSnackbar => 'Tauchplatz geloescht';

  @override
  String get diveSites_detail_depth_maximum => 'Maximum';

  @override
  String get diveSites_detail_depth_minimum => 'Minimum';

  @override
  String get diveSites_detail_diveCount_one => '1 Tauchgang eingetragen';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '$count Tauchgaenge eingetragen';
  }

  @override
  String get diveSites_detail_diveCount_zero =>
      'Noch keine Tauchgaenge eingetragen';

  @override
  String get diveSites_detail_editTooltip => 'Tauchplatz bearbeiten';

  @override
  String get diveSites_detail_editTooltipShort => 'Bearbeiten';

  @override
  String diveSites_detail_error_body(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get diveSites_detail_error_title => 'Fehler';

  @override
  String get diveSites_detail_loading_title => 'Wird geladen...';

  @override
  String get diveSites_detail_location_country => 'Land';

  @override
  String get diveSites_detail_location_gpsCoordinates => 'GPS-Koordinaten';

  @override
  String get diveSites_detail_location_notSet => 'Nicht festgelegt';

  @override
  String get diveSites_detail_location_region => 'Region';

  @override
  String get diveSites_detail_noDepthInfo => 'Keine Tiefeninformationen';

  @override
  String get diveSites_detail_noDescription => 'Keine Beschreibung';

  @override
  String get diveSites_detail_noNotes => 'Keine Notizen';

  @override
  String get diveSites_detail_rating_notRated => 'Nicht bewertet';

  @override
  String diveSites_detail_rating_value(Object rating) {
    return '$rating von 5';
  }

  @override
  String get diveSites_detail_section_access => 'Zugang & Logistik';

  @override
  String get diveSites_detail_section_altitude => 'Hoehenlage';

  @override
  String get diveSites_detail_section_depthRange => 'Tiefenbereich';

  @override
  String get diveSites_detail_section_description => 'Beschreibung';

  @override
  String get diveSites_detail_section_difficultyLevel => 'Schwierigkeitsgrad';

  @override
  String get diveSites_detail_section_divesAtSite =>
      'Tauchgaenge an diesem Platz';

  @override
  String get diveSites_detail_section_hazards => 'Gefahren & Sicherheit';

  @override
  String get diveSites_detail_section_location => 'Standort';

  @override
  String get diveSites_detail_section_notes => 'Notizen';

  @override
  String get diveSites_detail_section_rating => 'Bewertung';

  @override
  String diveSites_detail_semantics_copyToClipboard(Object label) {
    return '$label in die Zwischenablage kopieren';
  }

  @override
  String get diveSites_detail_semantics_viewDivesAtSite =>
      'Tauchgaenge an diesem Platz anzeigen';

  @override
  String get diveSites_detail_semantics_viewFullscreenMap =>
      'Karte im Vollbild anzeigen';

  @override
  String get diveSites_detail_siteNotFound_body =>
      'Dieser Tauchplatz existiert nicht mehr.';

  @override
  String get diveSites_detail_siteNotFound_title => 'Tauchplatz nicht gefunden';

  @override
  String get diveSites_difficulty_advanced => 'Fortgeschritten';

  @override
  String get diveSites_difficulty_beginner => 'Anfaenger';

  @override
  String get diveSites_difficulty_intermediate => 'Mittel';

  @override
  String get diveSites_difficulty_technical => 'Technisch';

  @override
  String get diveSites_edit_access_accessNotes_hint =>
      'Wie man zum Tauchplatz gelangt, Ein-/Ausstiegspunkte, Ufer-/Bootzugang';

  @override
  String get diveSites_edit_access_accessNotes_label => 'Zugangshinweise';

  @override
  String get diveSites_edit_access_mooringNumber_hint => 'z. B. Boje Nr. 12';

  @override
  String get diveSites_edit_access_mooringNumber_label => 'Bojen-Nummer';

  @override
  String get diveSites_edit_access_parkingInfo_hint =>
      'Parkverfuegbarkeit, Gebuehren, Tipps';

  @override
  String get diveSites_edit_access_parkingInfo_label => 'Parkinformationen';

  @override
  String get diveSites_edit_altitude_helperText =>
      'Hoehe des Tauchplatzes ueber dem Meeresspiegel (fuer Bergseetauchen)';

  @override
  String get diveSites_edit_altitude_hint => 'z. B. 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return 'Hoehe ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => 'Ungueltige Hoehe';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => 'Tauchplatz loeschen';

  @override
  String get diveSites_edit_appBar_editSite => 'Tauchplatz bearbeiten';

  @override
  String get diveSites_edit_appBar_newSite => 'Neuer Tauchplatz';

  @override
  String get diveSites_edit_appBar_save => 'Speichern';

  @override
  String get diveSites_edit_button_addSite => 'Tauchplatz hinzufuegen';

  @override
  String get diveSites_edit_button_saveChanges => 'Aenderungen speichern';

  @override
  String get diveSites_edit_cancel => 'Abbrechen';

  @override
  String get diveSites_edit_depth_helperText =>
      'Von der flachsten bis zur tiefsten Stelle';

  @override
  String get diveSites_edit_depth_maxHint => 'z. B. 30';

  @override
  String diveSites_edit_depth_maxLabel(Object symbol) {
    return 'Maximale Tiefe ($symbol)';
  }

  @override
  String get diveSites_edit_depth_minHint => 'z. B. 5';

  @override
  String diveSites_edit_depth_minLabel(Object symbol) {
    return 'Minimale Tiefe ($symbol)';
  }

  @override
  String get diveSites_edit_depth_separator => 'bis';

  @override
  String get diveSites_edit_discardDialog_content =>
      'Sie haben ungespeicherte Aenderungen. Sind Sie sicher, dass Sie die Seite verlassen moechten?';

  @override
  String get diveSites_edit_discardDialog_discard => 'Verwerfen';

  @override
  String get diveSites_edit_discardDialog_keepEditing => 'Weiter bearbeiten';

  @override
  String get diveSites_edit_discardDialog_title => 'Aenderungen verwerfen?';

  @override
  String get diveSites_edit_field_country_label => 'Land';

  @override
  String get diveSites_edit_field_description_hint =>
      'Kurze Beschreibung des Tauchplatzes';

  @override
  String get diveSites_edit_field_description_label => 'Beschreibung';

  @override
  String get diveSites_edit_field_notes_hint =>
      'Weitere Informationen zu diesem Tauchplatz';

  @override
  String get diveSites_edit_field_notes_label => 'Allgemeine Notizen';

  @override
  String get diveSites_edit_field_region_label => 'Region';

  @override
  String get diveSites_edit_field_siteName_hint => 'z. B. Blue Hole';

  @override
  String get diveSites_edit_field_siteName_label => 'Tauchplatzname *';

  @override
  String get diveSites_edit_field_siteName_validation =>
      'Bitte geben Sie einen Tauchplatznamen ein';

  @override
  String get diveSites_edit_gps_gettingLocation => 'Wird ermittelt...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Waehlen Sie eine Standortmethode - Koordinaten fuellen Land und Region automatisch aus';

  @override
  String get diveSites_edit_gps_latitude_hint => 'z. B. 21,4225';

  @override
  String get diveSites_edit_gps_latitude_label => 'Breitengrad';

  @override
  String get diveSites_edit_gps_latitude_validation =>
      'Ungueltiger Breitengrad';

  @override
  String get diveSites_edit_gps_longitude_hint => 'z. B. -86,7542';

  @override
  String get diveSites_edit_gps_longitude_label => 'Laengengrad';

  @override
  String get diveSites_edit_gps_longitude_validation =>
      'Ungueltiger Laengengrad';

  @override
  String get diveSites_edit_gps_pickFromMap => 'Auf Karte auswaehlen';

  @override
  String get diveSites_edit_gps_useMyLocation => 'Meinen Standort verwenden';

  @override
  String get diveSites_edit_hazards_helperText =>
      'Listen Sie alle Gefahren oder Sicherheitshinweise auf';

  @override
  String get diveSites_edit_hazards_hint =>
      'z. B. Starke Stroemungen, Bootsverkehr, Quallen, scharfe Korallen';

  @override
  String get diveSites_edit_hazards_label => 'Gefahren';

  @override
  String get diveSites_edit_marineLife_addButton => 'Hinzufuegen';

  @override
  String get diveSites_edit_marineLife_empty =>
      'Keine erwarteten Arten hinzugefuegt';

  @override
  String get diveSites_edit_marineLife_helperText =>
      'Arten, die Sie an diesem Tauchplatz erwarten';

  @override
  String get diveSites_edit_rating_clear => 'Bewertung loeschen';

  @override
  String diveSites_edit_rating_starTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'e',
      one: '',
    );
    return '$count Stern$_temp0';
  }

  @override
  String get diveSites_edit_section_access => 'Zugang & Logistik';

  @override
  String get diveSites_edit_section_altitude => 'Hoehenlage';

  @override
  String get diveSites_edit_section_depthRange => 'Tiefenbereich';

  @override
  String get diveSites_edit_section_difficultyLevel => 'Schwierigkeitsgrad';

  @override
  String get diveSites_edit_section_expectedMarineLife =>
      'Erwartete Meeresbewohner';

  @override
  String get diveSites_edit_section_gpsCoordinates => 'GPS-Koordinaten';

  @override
  String get diveSites_edit_section_hazards => 'Gefahren & Sicherheit';

  @override
  String get diveSites_edit_section_rating => 'Bewertung';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return 'Fehler beim Loeschen des Tauchplatzes: $error';
  }

  @override
  String diveSites_edit_snackbar_errorSaving(Object error) {
    return 'Fehler beim Speichern des Tauchplatzes: $error';
  }

  @override
  String get diveSites_edit_snackbar_locationCaptured => 'Standort erfasst';

  @override
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Standort erfasst (${accuracy}m)';
  }

  @override
  String get diveSites_edit_snackbar_locationSelectedFromMap =>
      'Standort von Karte ausgewaehlt';

  @override
  String get diveSites_edit_snackbar_locationSettings => 'Einstellungen';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      'Standort konnte nicht ermittelt werden. Ortungsdienste sind moeglicherweise nicht verfuegbar.';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      'Standort konnte nicht ermittelt werden. Bitte ueberpruefen Sie die Berechtigungen.';

  @override
  String get diveSites_edit_snackbar_siteAdded => 'Tauchplatz hinzugefuegt';

  @override
  String get diveSites_edit_snackbar_siteUpdated => 'Tauchplatz aktualisiert';

  @override
  String get diveSites_fab_label => 'Tauchplatz hinzufuegen';

  @override
  String get diveSites_fab_tooltip => 'Neuen Tauchplatz hinzufuegen';

  @override
  String get diveSites_filter_apply => 'Filter anwenden';

  @override
  String get diveSites_filter_cancel => 'Abbrechen';

  @override
  String get diveSites_filter_clearAll => 'Alle loeschen';

  @override
  String get diveSites_filter_country_hint => 'z. B. Thailand';

  @override
  String get diveSites_filter_country_label => 'Land';

  @override
  String get diveSites_filter_depth_max_label => 'Max';

  @override
  String get diveSites_filter_depth_min_label => 'Min';

  @override
  String get diveSites_filter_depth_separator => 'bis';

  @override
  String get diveSites_filter_difficulty_any => 'Alle';

  @override
  String get diveSites_filter_option_hasCoordinates_subtitle =>
      'Nur Plaetze mit GPS-Standort anzeigen';

  @override
  String get diveSites_filter_option_hasCoordinates_title => 'Hat Koordinaten';

  @override
  String get diveSites_filter_option_hasDives_subtitle =>
      'Nur Plaetze mit eingetragenen Tauchgaengen anzeigen';

  @override
  String get diveSites_filter_option_hasDives_title => 'Hat Tauchgaenge';

  @override
  String diveSites_filter_rating_starsPlus(Object count) {
    return '$count+ Sterne';
  }

  @override
  String get diveSites_filter_region_hint => 'z. B. Phuket';

  @override
  String get diveSites_filter_region_label => 'Region';

  @override
  String get diveSites_filter_section_depthRange => 'Max. Tiefenbereich';

  @override
  String get diveSites_filter_section_difficulty => 'Schwierigkeitsgrad';

  @override
  String get diveSites_filter_section_location => 'Standort';

  @override
  String get diveSites_filter_section_minRating => 'Mindestbewertung';

  @override
  String get diveSites_filter_section_options => 'Optionen';

  @override
  String get diveSites_filter_title => 'Tauchplaetze filtern';

  @override
  String get diveSites_import_appBar_title => 'Tauchplatz importieren';

  @override
  String get diveSites_import_badge_imported => 'Importiert';

  @override
  String get diveSites_import_badge_saved => 'Gespeichert';

  @override
  String get diveSites_import_button_import => 'Importieren';

  @override
  String get diveSites_import_detail_alreadyImported => 'Bereits importiert';

  @override
  String get diveSites_import_detail_importToMySites =>
      'Zu meinen Tauchplaetzen importieren';

  @override
  String diveSites_import_detail_source(Object source) {
    return 'Quelle: $source';
  }

  @override
  String get diveSites_import_empty_description =>
      'Suchen Sie nach Tauchplaetzen aus unserer Datenbank beliebter\nTauchziele weltweit.';

  @override
  String get diveSites_import_empty_hint =>
      'Versuchen Sie, nach Tauchplatzname, Land oder Region zu suchen.';

  @override
  String get diveSites_import_empty_title => 'Tauchplaetze suchen';

  @override
  String get diveSites_import_error_retry => 'Erneut versuchen';

  @override
  String get diveSites_import_error_title => 'Suchfehler';

  @override
  String get diveSites_import_error_unknown => 'Unbekannter Fehler';

  @override
  String get diveSites_import_externalSite_locationUnknown =>
      'Standort unbekannt';

  @override
  String get diveSites_import_label_gps => 'GPS';

  @override
  String get diveSites_import_localSite_locationNotSet =>
      'Standort nicht festgelegt';

  @override
  String diveSites_import_noResults_description(Object query) {
    return 'Keine Tauchplaetze fuer \"$query\" gefunden.\nVersuchen Sie einen anderen Suchbegriff.';
  }

  @override
  String get diveSites_import_noResults_title => 'Keine Ergebnisse';

  @override
  String get diveSites_import_quickSearch_caribbean => 'Karibik';

  @override
  String get diveSites_import_quickSearch_indonesia => 'Indonesien';

  @override
  String get diveSites_import_quickSearch_maldives => 'Malediven';

  @override
  String get diveSites_import_quickSearch_philippines => 'Philippinen';

  @override
  String get diveSites_import_quickSearch_redSea => 'Rotes Meer';

  @override
  String get diveSites_import_quickSearch_thailand => 'Thailand';

  @override
  String get diveSites_import_search_clearTooltip => 'Suche loeschen';

  @override
  String get diveSites_import_search_hint =>
      'Tauchplaetze suchen (z. B. \"Blue Hole\", \"Thailand\")';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return 'Aus Datenbank importieren ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return 'Meine Tauchplaetze ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return 'Details fuer $name anzeigen';
  }

  @override
  String diveSites_import_semantics_viewSavedSite(Object name) {
    return 'Gespeicherten Tauchplatz $name anzeigen';
  }

  @override
  String get diveSites_import_snackbar_failed =>
      'Import des Tauchplatzes fehlgeschlagen';

  @override
  String diveSites_import_snackbar_imported(Object name) {
    return '\"$name\" importiert';
  }

  @override
  String get diveSites_import_snackbar_viewAction => 'Anzeigen';

  @override
  String get diveSites_list_activeFilter_clear => 'Loeschen';

  @override
  String diveSites_list_activeFilter_country(Object country) {
    return 'Land: $country';
  }

  @override
  String diveSites_list_activeFilter_depthRangeBoth(Object min, Object max) {
    return '$min-${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Bis zu ${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '${min}m+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => 'Hat Koordinaten';

  @override
  String get diveSites_list_activeFilter_hasDives => 'Hat Tauchgaenge';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return 'Region: $region';
  }

  @override
  String get diveSites_list_appBar_title => 'Tauchplaetze';

  @override
  String get diveSites_list_bulkDelete_cancel => 'Abbrechen';

  @override
  String get diveSites_list_bulkDelete_confirm => 'Loeschen';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchplaetze',
      one: 'Tauchplatz',
    );
    return 'Sind Sie sicher, dass Sie $count $_temp0 loeschen moechten? Diese Aktion kann innerhalb von 5 Sekunden rueckgaengig gemacht werden.';
  }

  @override
  String get diveSites_list_bulkDelete_restored =>
      'Tauchplaetze wiederhergestellt';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchplaetze',
      one: 'Tauchplatz',
    );
    return '$count $_temp0 geloescht';
  }

  @override
  String get diveSites_list_bulkDelete_title => 'Tauchplaetze loeschen';

  @override
  String get diveSites_list_bulkDelete_undo => 'Rueckgaengig';

  @override
  String get diveSites_list_emptyFiltered_clearAll => 'Alle Filter loeschen';

  @override
  String get diveSites_list_emptyFiltered_subtitle =>
      'Versuchen Sie, Ihre Filter anzupassen oder zu loeschen';

  @override
  String get diveSites_list_emptyFiltered_title =>
      'Keine Tauchplaetze entsprechen Ihren Filtern';

  @override
  String get diveSites_list_empty_addFirstSite =>
      'Ersten Tauchplatz hinzufuegen';

  @override
  String get diveSites_list_empty_import => 'Importieren';

  @override
  String get diveSites_list_empty_subtitle =>
      'Fuegen Sie Tauchplaetze hinzu, um Ihre Lieblingsorte zu verfolgen';

  @override
  String get diveSites_list_empty_title => 'Noch keine Tauchplaetze';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return 'Fehler beim Laden der Tauchplaetze: $error';
  }

  @override
  String get diveSites_list_error_retry => 'Erneut versuchen';

  @override
  String get diveSites_list_menu_import => 'Importieren';

  @override
  String get diveSites_list_search_backTooltip => 'Zurueck';

  @override
  String get diveSites_list_search_clearTooltip => 'Suche loeschen';

  @override
  String get diveSites_list_search_emptyHint =>
      'Suche nach Tauchplatzname, Land oder Region';

  @override
  String diveSites_list_search_error(Object error) {
    return 'Fehler: $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return 'Keine Tauchplaetze fuer \"$query\" gefunden';
  }

  @override
  String get diveSites_list_search_placeholder => 'Tauchplaetze suchen...';

  @override
  String get diveSites_list_selection_closeTooltip => 'Auswahl schliessen';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count ausgewaehlt';
  }

  @override
  String get diveSites_list_selection_deleteTooltip => 'Auswahl loeschen';

  @override
  String get diveSites_list_selection_deselectAllTooltip => 'Alle abwaehlen';

  @override
  String get diveSites_list_selection_selectAllTooltip => 'Alle auswaehlen';

  @override
  String get diveSites_list_sort_title => 'Tauchplaetze sortieren';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgaenge',
      one: '1 Tauchgang',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return 'Tauchplatz: $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => 'Tauchplaetze filtern';

  @override
  String get diveSites_list_tooltip_mapView => 'Kartenansicht';

  @override
  String get diveSites_list_tooltip_searchSites => 'Tauchplaetze suchen';

  @override
  String get diveSites_list_tooltip_sort => 'Sortieren';

  @override
  String get diveSites_locationPicker_appBar_title => 'Standort auswaehlen';

  @override
  String get diveSites_locationPicker_confirmButton => 'Bestaetigen';

  @override
  String get diveSites_locationPicker_confirmTooltip =>
      'Ausgewaehlten Standort bestaetigen';

  @override
  String get diveSites_locationPicker_fab_tooltip =>
      'Meinen Standort verwenden';

  @override
  String get diveSites_locationPicker_instruction_locationSelected =>
      'Standort ausgewaehlt';

  @override
  String get diveSites_locationPicker_instruction_lookingUp =>
      'Standort wird ermittelt...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect =>
      'Tippen Sie auf die Karte, um einen Standort auszuwaehlen';

  @override
  String get diveSites_locationPicker_label_latitude => 'Breitengrad';

  @override
  String get diveSites_locationPicker_label_longitude => 'Laengengrad';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return 'Ausgewaehlte Koordinaten: Breitengrad $latitude, Laengengrad $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp =>
      'Standort wird ermittelt';

  @override
  String get diveSites_locationPicker_semantics_map =>
      'Interaktive Karte zur Auswahl eines Tauchplatz-Standorts. Tippen Sie auf die Karte, um einen Standort auszuwaehlen.';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return 'Fehler beim Laden der Tauchplaetze: $error';
  }

  @override
  String get diveSites_map_appBar_title => 'Tauchplaetze';

  @override
  String get diveSites_map_empty_description =>
      'Fuegen Sie Ihren Tauchplaetzen Koordinaten hinzu, um sie auf der Karte zu sehen';

  @override
  String get diveSites_map_empty_title => 'Keine Tauchplaetze mit Koordinaten';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return 'Fehler beim Laden der Tauchplaetze: $error';
  }

  @override
  String get diveSites_map_error_retry => 'Erneut versuchen';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgaenge',
      one: '1 Tauchgang',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return 'Tauchplatz: $name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => 'Alle Tauchplaetze einpassen';

  @override
  String get diveSites_map_tooltip_listView => 'Listenansicht';

  @override
  String get diveSites_summary_action_addSite => 'Tauchplatz hinzufuegen';

  @override
  String get diveSites_summary_action_import => 'Importieren';

  @override
  String get diveSites_summary_action_viewMap => 'Karte anzeigen';

  @override
  String diveSites_summary_countriesMore(Object count) {
    return '+ $count weitere';
  }

  @override
  String get diveSites_summary_header_subtitle =>
      'Waehlen Sie einen Tauchplatz aus der Liste, um Details anzuzeigen';

  @override
  String get diveSites_summary_header_title => 'Tauchplaetze';

  @override
  String get diveSites_summary_section_countriesRegions => 'Laender & Regionen';

  @override
  String get diveSites_summary_section_mostDived => 'Am meisten betaucht';

  @override
  String get diveSites_summary_section_overview => 'Uebersicht';

  @override
  String get diveSites_summary_section_quickActions => 'Schnellaktionen';

  @override
  String get diveSites_summary_section_topRated => 'Am besten bewertet';

  @override
  String get diveSites_summary_stat_avgRating => 'Durchschn. Bewertung';

  @override
  String get diveSites_summary_stat_totalDives => 'Tauchgaenge gesamt';

  @override
  String get diveSites_summary_stat_totalSites => 'Tauchplaetze gesamt';

  @override
  String get diveSites_summary_stat_withGps => 'Mit GPS';

  @override
  String get diveTypes_addDialog_addButton => 'Hinzufügen';

  @override
  String get diveTypes_addDialog_nameHint => 'z.B. Suche & Bergung';

  @override
  String get diveTypes_addDialog_nameLabel => 'Tauchgangstyp-Name';

  @override
  String get diveTypes_addDialog_nameValidation =>
      'Bitte geben Sie einen Namen ein';

  @override
  String get diveTypes_addDialog_title =>
      'Benutzerdefinierten Tauchgangstyp hinzufügen';

  @override
  String get diveTypes_addTooltip => 'Tauchgangstyp hinzufügen';

  @override
  String get diveTypes_appBar_title => 'Tauchgangstypen';

  @override
  String get diveTypes_builtIn => 'Integriert';

  @override
  String get diveTypes_builtInHeader => 'Integrierte Tauchgangstypen';

  @override
  String get diveTypes_custom => 'Benutzerdefiniert';

  @override
  String get diveTypes_customHeader => 'Benutzerdefinierte Tauchgangstypen';

  @override
  String diveTypes_deleteDialog_content(Object name) {
    return 'Möchten Sie \"$name\" wirklich löschen?';
  }

  @override
  String get diveTypes_deleteDialog_title => 'Tauchgangstyp löschen?';

  @override
  String get diveTypes_deleteTooltip => 'Tauchgangstyp löschen';

  @override
  String diveTypes_snackbar_added(Object name) {
    return 'Tauchgangstyp hinzugefügt: $name';
  }

  @override
  String diveTypes_snackbar_cannotDelete(Object name) {
    return '\"$name\" kann nicht gelöscht werden - wird von vorhandenen Tauchgängen verwendet';
  }

  @override
  String diveTypes_snackbar_deleted(Object name) {
    return '\"$name\" gelöscht';
  }

  @override
  String diveTypes_snackbar_errorAdding(Object error) {
    return 'Fehler beim Hinzufügen des Tauchgangstyps: $error';
  }

  @override
  String diveTypes_snackbar_errorDeleting(Object error) {
    return 'Fehler beim Löschen des Tauchgangstyps: $error';
  }

  @override
  String get divers_detail_activeDiver => 'Aktiver Taucher';

  @override
  String get divers_detail_allergiesLabel => 'Allergien';

  @override
  String get divers_detail_appBarTitle => 'Taucher';

  @override
  String get divers_detail_bloodTypeLabel => 'Blutgruppe';

  @override
  String get divers_detail_bottomTimeLabel => 'Grundzeit';

  @override
  String get divers_detail_cancelButton => 'Abbrechen';

  @override
  String get divers_detail_contactTitle => 'Kontakt';

  @override
  String get divers_detail_defaultLabel => 'Standard';

  @override
  String get divers_detail_deleteButton => 'Loeschen';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'Sind Sie sicher, dass Sie $name loeschen moechten? Alle zugeordneten Tauchprotokolle werden freigegeben.';
  }

  @override
  String get divers_detail_deleteDialogTitle => 'Taucher loeschen?';

  @override
  String divers_detail_deleteError(Object error) {
    return 'Loeschen fehlgeschlagen: $error';
  }

  @override
  String get divers_detail_deleteMenuItem => 'Loeschen';

  @override
  String get divers_detail_deletedSnackbar => 'Taucher geloescht';

  @override
  String get divers_detail_diveInsuranceTitle => 'Tauchversicherung';

  @override
  String get divers_detail_diveStatisticsTitle => 'Tauchstatistik';

  @override
  String get divers_detail_editTooltip => 'Taucher bearbeiten';

  @override
  String get divers_detail_emergencyContactTitle => 'Notfallkontakt';

  @override
  String divers_detail_errorPrefix(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get divers_detail_expiredBadge => 'Abgelaufen';

  @override
  String get divers_detail_expiresLabel => 'Laeuft ab';

  @override
  String get divers_detail_medicalInfoTitle => 'Medizinische Informationen';

  @override
  String get divers_detail_medicalNotesLabel => 'Notizen';

  @override
  String get divers_detail_notFound => 'Taucher nicht gefunden';

  @override
  String get divers_detail_notesTitle => 'Notizen';

  @override
  String get divers_detail_policyNumberLabel => 'Policen-Nr.';

  @override
  String get divers_detail_providerLabel => 'Anbieter';

  @override
  String get divers_detail_setAsDefault => 'Als Standard festlegen';

  @override
  String divers_detail_setAsDefaultSnackbar(Object name) {
    return '$name als Standardtaucher festgelegt';
  }

  @override
  String get divers_detail_switchToTooltip => 'Zu diesem Taucher wechseln';

  @override
  String divers_detail_switchedTo(Object name) {
    return 'Gewechselt zu $name';
  }

  @override
  String get divers_detail_totalDivesLabel => 'Tauchgaenge gesamt';

  @override
  String get divers_detail_unableToLoadStats =>
      'Statistiken konnten nicht geladen werden';

  @override
  String get divers_edit_addButton => 'Taucher hinzufuegen';

  @override
  String get divers_edit_addTitle => 'Taucher hinzufuegen';

  @override
  String get divers_edit_allergiesHint => 'z.B. Penicillin, Schalentiere';

  @override
  String get divers_edit_allergiesLabel => 'Allergien';

  @override
  String get divers_edit_bloodTypeHint => 'z.B. 0+, A-, B+';

  @override
  String get divers_edit_bloodTypeLabel => 'Blutgruppe';

  @override
  String get divers_edit_cancelButton => 'Abbrechen';

  @override
  String get divers_edit_clearInsuranceExpiryTooltip =>
      'Versicherungsablaufdatum loeschen';

  @override
  String get divers_edit_clearMedicalClearanceTooltip =>
      'Datum der aerztlichen Freigabe loeschen';

  @override
  String get divers_edit_contactNameLabel => 'Kontaktname';

  @override
  String get divers_edit_contactPhoneLabel => 'Kontakttelefon';

  @override
  String get divers_edit_discardButton => 'Verwerfen';

  @override
  String get divers_edit_discardDialogContent =>
      'Sie haben ungespeicherte Aenderungen. Sind Sie sicher, dass Sie diese verwerfen moechten?';

  @override
  String get divers_edit_discardDialogTitle => 'Aenderungen verwerfen?';

  @override
  String get divers_edit_diverAdded => 'Taucher hinzugefuegt';

  @override
  String get divers_edit_diverUpdated => 'Taucher aktualisiert';

  @override
  String get divers_edit_editTitle => 'Taucher bearbeiten';

  @override
  String get divers_edit_emailError =>
      'Bitte geben Sie eine gueltige E-Mail-Adresse ein';

  @override
  String get divers_edit_emailLabel => 'E-Mail';

  @override
  String get divers_edit_emergencyContactsSection => 'Notfallkontakte';

  @override
  String divers_edit_errorLoading(Object error) {
    return 'Fehler beim Laden des Tauchers: $error';
  }

  @override
  String divers_edit_errorSaving(Object error) {
    return 'Fehler beim Speichern des Tauchers: $error';
  }

  @override
  String get divers_edit_expiryDateNotSet => 'Nicht festgelegt';

  @override
  String get divers_edit_expiryDateTitle => 'Ablaufdatum';

  @override
  String get divers_edit_insuranceProviderHint => 'z.B. DAN, DiveAssure';

  @override
  String get divers_edit_insuranceProviderLabel => 'Versicherungsanbieter';

  @override
  String get divers_edit_insuranceSection => 'Tauchversicherung';

  @override
  String get divers_edit_keepEditingButton => 'Weiter bearbeiten';

  @override
  String get divers_edit_medicalClearanceExpired => 'Abgelaufen';

  @override
  String get divers_edit_medicalClearanceExpiringSoon => 'Laeuft bald ab';

  @override
  String get divers_edit_medicalClearanceNotSet => 'Nicht festgelegt';

  @override
  String get divers_edit_medicalClearanceTitle =>
      'Ablauf der aerztlichen Freigabe';

  @override
  String get divers_edit_medicalInfoSection => 'Medizinische Informationen';

  @override
  String get divers_edit_medicalNotesLabel => 'Medizinische Notizen';

  @override
  String get divers_edit_medicationsHint => 'z.B. Aspirin taeglich, EpiPen';

  @override
  String get divers_edit_medicationsLabel => 'Medikamente';

  @override
  String get divers_edit_nameError => 'Name ist erforderlich';

  @override
  String get divers_edit_nameLabel => 'Name *';

  @override
  String get divers_edit_notesLabel => 'Notizen';

  @override
  String get divers_edit_notesSection => 'Notizen';

  @override
  String get divers_edit_personalInfoSection => 'Persoenliche Informationen';

  @override
  String get divers_edit_phoneLabel => 'Telefon';

  @override
  String get divers_edit_policyNumberLabel => 'Policennummer';

  @override
  String get divers_edit_primaryContactTitle => 'Primaerer Kontakt';

  @override
  String get divers_edit_relationshipHint =>
      'z.B. Ehepartner, Elternteil, Freund';

  @override
  String get divers_edit_relationshipLabel => 'Beziehung';

  @override
  String get divers_edit_saveButton => 'Speichern';

  @override
  String get divers_edit_secondaryContactTitle => 'Sekundaerer Kontakt';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip =>
      'Versicherungsablaufdatum auswaehlen';

  @override
  String get divers_edit_selectMedicalClearanceTooltip =>
      'Datum der aerztlichen Freigabe auswaehlen';

  @override
  String get divers_edit_updateButton => 'Taucher aktualisieren';

  @override
  String get divers_list_activeBadge => 'Aktiv';

  @override
  String get divers_list_addDiverButton => 'Taucher hinzufuegen';

  @override
  String get divers_list_addDiverTooltip => 'Neues Taucherprofil hinzufuegen';

  @override
  String get divers_list_appBarTitle => 'Taucherprofile';

  @override
  String get divers_list_compactTitle => 'Taucher';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount Tauchgaenge$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle =>
      'Fuegen Sie Taucherprofile hinzu, um Tauchprotokolle fuer mehrere Personen zu verwalten';

  @override
  String get divers_list_emptyTitle => 'Noch keine Taucher';

  @override
  String divers_list_errorLoading(Object error) {
    return 'Fehler beim Laden der Taucher: $error';
  }

  @override
  String get divers_list_errorLoadingStats =>
      'Fehler beim Laden der Statistiken';

  @override
  String get divers_list_loadingStats => 'Laden...';

  @override
  String get divers_list_retryButton => 'Erneut versuchen';

  @override
  String divers_list_viewDiverLabel(Object name) {
    return 'Taucher $name anzeigen';
  }

  @override
  String get divers_summary_activeDiverTitle => 'Aktiver Taucher';

  @override
  String get divers_summary_otherDiversTitle => 'Weitere Taucher';

  @override
  String get divers_summary_overviewTitle => 'Uebersicht';

  @override
  String get divers_summary_quickActionsTitle => 'Schnellaktionen';

  @override
  String get divers_summary_subtitle =>
      'Waehlen Sie einen Taucher aus der Liste, um Details anzuzeigen';

  @override
  String get divers_summary_title => 'Taucherprofile';

  @override
  String get divers_summary_totalDiversLabel => 'Taucher gesamt';

  @override
  String get enum_altitudeGroup_extreme => 'Extreme Hoehe';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => 'Hoehengruppe 1';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => 'Hoehengruppe 2';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => 'Hoehengruppe 3';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => 'Meereshoehe';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => 'Gefahr';

  @override
  String get enum_ascentRate_safe => 'Sicher';

  @override
  String get enum_ascentRate_warning => 'Warnung';

  @override
  String get enum_buddyRole_buddy => 'Tauchpartner';

  @override
  String get enum_buddyRole_diveGuide => 'Tauchguide';

  @override
  String get enum_buddyRole_diveMaster => 'Divemaster';

  @override
  String get enum_buddyRole_instructor => 'Tauchlehrer';

  @override
  String get enum_buddyRole_solo => 'Solo';

  @override
  String get enum_buddyRole_student => 'Tauchschueler';

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
  String get enum_certificationAgency_other => 'Sonstige';

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
  String get enum_certificationLevel_cave => 'Hoehlentauchen';

  @override
  String get enum_certificationLevel_cavern => 'Kavernentauchen';

  @override
  String get enum_certificationLevel_courseDirector => 'Course Director';

  @override
  String get enum_certificationLevel_decompression => 'Dekompression';

  @override
  String get enum_certificationLevel_diveMaster => 'Divemaster';

  @override
  String get enum_certificationLevel_instructor => 'Tauchlehrer';

  @override
  String get enum_certificationLevel_masterInstructor => 'Master Instructor';

  @override
  String get enum_certificationLevel_nitrox => 'Nitrox';

  @override
  String get enum_certificationLevel_openWater => 'Open Water';

  @override
  String get enum_certificationLevel_other => 'Sonstige';

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
  String get enum_certificationLevel_wreck => 'Wracktauchen';

  @override
  String get enum_currentDirection_east => 'Ost';

  @override
  String get enum_currentDirection_none => 'Keine';

  @override
  String get enum_currentDirection_north => 'Nord';

  @override
  String get enum_currentDirection_northEast => 'Nordost';

  @override
  String get enum_currentDirection_northWest => 'Nordwest';

  @override
  String get enum_currentDirection_south => 'Sued';

  @override
  String get enum_currentDirection_southEast => 'Suedost';

  @override
  String get enum_currentDirection_southWest => 'Suedwest';

  @override
  String get enum_currentDirection_variable => 'Wechselnd';

  @override
  String get enum_currentDirection_west => 'West';

  @override
  String get enum_currentStrength_light => 'Leicht';

  @override
  String get enum_currentStrength_moderate => 'Maessig';

  @override
  String get enum_currentStrength_none => 'Keine';

  @override
  String get enum_currentStrength_strong => 'Stark';

  @override
  String get enum_diveMode_ccr => 'Geschlossener Kreislauf Rebreather';

  @override
  String get enum_diveMode_oc => 'Offener Kreislauf';

  @override
  String get enum_diveMode_scr => 'Halbgeschlossener Rebreather';

  @override
  String get enum_diveType_altitude => 'Hoehentauchen';

  @override
  String get enum_diveType_boat => 'Boot';

  @override
  String get enum_diveType_cave => 'Hoehle';

  @override
  String get enum_diveType_deep => 'Tieftauchen';

  @override
  String get enum_diveType_drift => 'Stroemungstauchen';

  @override
  String get enum_diveType_freedive => 'Freitauchen';

  @override
  String get enum_diveType_ice => 'Eistauchen';

  @override
  String get enum_diveType_liveaboard => 'Tauchsafari';

  @override
  String get enum_diveType_night => 'Nachttauchen';

  @override
  String get enum_diveType_recreational => 'Sporttauchen';

  @override
  String get enum_diveType_shore => 'Landtauchgang';

  @override
  String get enum_diveType_technical => 'Technisches Tauchen';

  @override
  String get enum_diveType_training => 'Ausbildung';

  @override
  String get enum_diveType_wreck => 'Wracktauchen';

  @override
  String get enum_entryMethod_backRoll => 'Rueckwaertsrolle';

  @override
  String get enum_entryMethod_boat => 'Bootseinstieg';

  @override
  String get enum_entryMethod_giantStride => 'Grossschritt';

  @override
  String get enum_entryMethod_jetty => 'Steg/Dock';

  @override
  String get enum_entryMethod_ladder => 'Leiter';

  @override
  String get enum_entryMethod_other => 'Sonstige';

  @override
  String get enum_entryMethod_platform => 'Plattform';

  @override
  String get enum_entryMethod_seatedEntry => 'Sitzender Einstieg';

  @override
  String get enum_entryMethod_shore => 'Ufereinstieg';

  @override
  String get enum_equipmentStatus_active => 'Aktiv';

  @override
  String get enum_equipmentStatus_inService => 'In Wartung';

  @override
  String get enum_equipmentStatus_loaned => 'Verliehen';

  @override
  String get enum_equipmentStatus_lost => 'Verloren';

  @override
  String get enum_equipmentStatus_needsService => 'Wartung erforderlich';

  @override
  String get enum_equipmentStatus_retired => 'Ausgemustert';

  @override
  String get enum_equipmentType_bcd => 'Tarierjacket';

  @override
  String get enum_equipmentType_boots => 'Fuessling';

  @override
  String get enum_equipmentType_camera => 'Kamera';

  @override
  String get enum_equipmentType_computer => 'Tauchcomputer';

  @override
  String get enum_equipmentType_drysuit => 'Trockentauchanzug';

  @override
  String get enum_equipmentType_fins => 'Flossen';

  @override
  String get enum_equipmentType_gloves => 'Handschuhe';

  @override
  String get enum_equipmentType_hood => 'Kopfhaube';

  @override
  String get enum_equipmentType_knife => 'Messer';

  @override
  String get enum_equipmentType_light => 'Lampe';

  @override
  String get enum_equipmentType_mask => 'Maske';

  @override
  String get enum_equipmentType_other => 'Sonstige';

  @override
  String get enum_equipmentType_reel => 'Reel';

  @override
  String get enum_equipmentType_regulator => 'Atemregler';

  @override
  String get enum_equipmentType_smb => 'SMB';

  @override
  String get enum_equipmentType_tank => 'Flasche';

  @override
  String get enum_equipmentType_weights => 'Gewichte';

  @override
  String get enum_equipmentType_wetsuit => 'Neoprenanzug';

  @override
  String get enum_eventSeverity_alert => 'Alarm';

  @override
  String get enum_eventSeverity_info => 'Info';

  @override
  String get enum_eventSeverity_warning => 'Warnung';

  @override
  String get enum_pdfPageSize_a4 => 'A4';

  @override
  String get enum_pdfPageSize_a4_description => '210 x 297 mm';

  @override
  String get enum_pdfPageSize_letter => 'Letter';

  @override
  String get enum_pdfPageSize_letter_description => '8,5 x 11 Zoll';

  @override
  String get enum_pdfTemplate_detailed => 'Detailliert';

  @override
  String get enum_pdfTemplate_detailed_description =>
      'Vollstaendige Tauchinformationen mit Notizen und Bewertungen';

  @override
  String get enum_pdfTemplate_nauiStyle => 'NAUI-Stil';

  @override
  String get enum_pdfTemplate_nauiStyle_description =>
      'Layout im NAUI-Logbuchformat';

  @override
  String get enum_pdfTemplate_padiStyle => 'PADI-Stil';

  @override
  String get enum_pdfTemplate_padiStyle_description =>
      'Layout im PADI-Logbuchformat';

  @override
  String get enum_pdfTemplate_professional => 'Professionell';

  @override
  String get enum_pdfTemplate_professional_description =>
      'Unterschrift- und Stempelbereiche zur Verifizierung';

  @override
  String get enum_pdfTemplate_simple => 'Einfach';

  @override
  String get enum_pdfTemplate_simple_description =>
      'Kompaktes Tabellenformat, viele Tauchgaenge pro Seite';

  @override
  String get enum_profileEvent_alert => 'Alarm';

  @override
  String get enum_profileEvent_ascentRateCritical =>
      'Aufstiegsgeschwindigkeit kritisch';

  @override
  String get enum_profileEvent_ascentRateWarning =>
      'Aufstiegsgeschwindigkeit Warnung';

  @override
  String get enum_profileEvent_ascentStart => 'Aufstieg Beginn';

  @override
  String get enum_profileEvent_bookmark => 'Lesezeichen';

  @override
  String get enum_profileEvent_cnsCritical => 'CNS kritisch';

  @override
  String get enum_profileEvent_cnsWarning => 'CNS Warnung';

  @override
  String get enum_profileEvent_decoStopEnd => 'Dekostopp Ende';

  @override
  String get enum_profileEvent_decoStopStart => 'Dekostopp Beginn';

  @override
  String get enum_profileEvent_decoViolation => 'Deko-Verstoss';

  @override
  String get enum_profileEvent_descentEnd => 'Abstieg Ende';

  @override
  String get enum_profileEvent_descentStart => 'Abstieg Beginn';

  @override
  String get enum_profileEvent_gasSwitch => 'Gaswechsel';

  @override
  String get enum_profileEvent_lowGas => 'Warnung niedriger Gasvorrat';

  @override
  String get enum_profileEvent_maxDepth => 'Maximale Tiefe';

  @override
  String get enum_profileEvent_missedStop => 'Verpasster Dekostopp';

  @override
  String get enum_profileEvent_note => 'Notiz';

  @override
  String get enum_profileEvent_ppO2High => 'Hoher ppO2';

  @override
  String get enum_profileEvent_ppO2Low => 'Niedriger ppO2';

  @override
  String get enum_profileEvent_safetyStopEnd => 'Sicherheitsstopp Ende';

  @override
  String get enum_profileEvent_safetyStopStart => 'Sicherheitsstopp Beginn';

  @override
  String get enum_profileEvent_setpointChange => 'Setpoint-Wechsel';

  @override
  String get enum_profileMetricCategory_decompression => 'Dekompression';

  @override
  String get enum_profileMetricCategory_gasAnalysis => 'Gasanalyse';

  @override
  String get enum_profileMetricCategory_gradientFactor => 'Gradientenfaktoren';

  @override
  String get enum_profileMetricCategory_other => 'Sonstige';

  @override
  String get enum_profileMetricCategory_primary => 'Primaere Messwerte';

  @override
  String get enum_profileMetric_gasDensity => 'Gasdichte';

  @override
  String get enum_profileMetric_gasDensity_short => 'Dichte';

  @override
  String get enum_profileMetric_gf => 'GF%';

  @override
  String get enum_profileMetric_gf_short => 'GF%';

  @override
  String get enum_profileMetric_heartRate => 'Herzfrequenz';

  @override
  String get enum_profileMetric_heartRate_short => 'HF';

  @override
  String get enum_profileMetric_meanDepth => 'Durchschnittstiefe';

  @override
  String get enum_profileMetric_meanDepth_short => 'Mittel';

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
  String get enum_profileMetric_pressure => 'Druck';

  @override
  String get enum_profileMetric_pressure_short => 'Druck';

  @override
  String get enum_profileMetric_sacRate => 'SAC-Rate';

  @override
  String get enum_profileMetric_sacRate_short => 'SAC';

  @override
  String get enum_profileMetric_surfaceGf => 'Oberflaechenm GF';

  @override
  String get enum_profileMetric_surfaceGf_short => 'OflGF';

  @override
  String get enum_profileMetric_temperature => 'Temperatur';

  @override
  String get enum_profileMetric_temperature_short => 'Temp';

  @override
  String get enum_profileMetric_tts => 'TTS';

  @override
  String get enum_profileMetric_tts_short => 'TTS';

  @override
  String get enum_scrType_cmf => 'Konstanter Massenstrom';

  @override
  String get enum_scrType_cmf_short => 'CMF';

  @override
  String get enum_scrType_escr => 'Elektronisch gesteuert';

  @override
  String get enum_scrType_escr_short => 'ESCR';

  @override
  String get enum_scrType_pascr => 'Passive Zumischung';

  @override
  String get enum_scrType_pascr_short => 'PASCR';

  @override
  String get enum_serviceType_annual => 'Jahreswartung';

  @override
  String get enum_serviceType_calibration => 'Kalibrierung';

  @override
  String get enum_serviceType_cleaning => 'Reinigung';

  @override
  String get enum_serviceType_inspection => 'Inspektion';

  @override
  String get enum_serviceType_other => 'Sonstige';

  @override
  String get enum_serviceType_overhaul => 'Generalueberholung';

  @override
  String get enum_serviceType_recall => 'Rueckruf/Sicherheit';

  @override
  String get enum_serviceType_repair => 'Reparatur';

  @override
  String get enum_serviceType_replacement => 'Teileaustausch';

  @override
  String get enum_serviceType_warranty => 'Garantieservice';

  @override
  String get enum_sortDirection_ascending => 'Aufsteigend';

  @override
  String get enum_sortDirection_descending => 'Absteigend';

  @override
  String get enum_sortField_agency => 'Verband';

  @override
  String get enum_sortField_date => 'Datum';

  @override
  String get enum_sortField_dateIssued => 'Ausstellungsdatum';

  @override
  String get enum_sortField_difficulty => 'Schwierigkeitsgrad';

  @override
  String get enum_sortField_diveCount => 'Anzahl Tauchgaenge';

  @override
  String get enum_sortField_diveNumber => 'Tauchgangnummer';

  @override
  String get enum_sortField_duration => 'Dauer';

  @override
  String get enum_sortField_endDate => 'Enddatum';

  @override
  String get enum_sortField_lastServiceDate => 'Letzte Wartung';

  @override
  String get enum_sortField_maxDepth => 'Max. Tiefe';

  @override
  String get enum_sortField_name => 'Name';

  @override
  String get enum_sortField_purchaseDate => 'Kaufdatum';

  @override
  String get enum_sortField_rating => 'Bewertung';

  @override
  String get enum_sortField_site => 'Tauchplatz';

  @override
  String get enum_sortField_startDate => 'Startdatum';

  @override
  String get enum_sortField_status => 'Status';

  @override
  String get enum_sortField_type => 'Typ';

  @override
  String get enum_speciesCategory_coral => 'Koralle';

  @override
  String get enum_speciesCategory_fish => 'Fisch';

  @override
  String get enum_speciesCategory_invertebrate => 'Wirbellose';

  @override
  String get enum_speciesCategory_mammal => 'Saeugetier';

  @override
  String get enum_speciesCategory_other => 'Sonstige';

  @override
  String get enum_speciesCategory_plant => 'Pflanze/Alge';

  @override
  String get enum_speciesCategory_ray => 'Rochen';

  @override
  String get enum_speciesCategory_shark => 'Hai';

  @override
  String get enum_speciesCategory_turtle => 'Schildkroete';

  @override
  String get enum_tankMaterial_aluminum => 'Aluminium';

  @override
  String get enum_tankMaterial_carbonFiber => 'Kohlefaser';

  @override
  String get enum_tankMaterial_steel => 'Stahl';

  @override
  String get enum_tankRole_backGas => 'Rueckengas';

  @override
  String get enum_tankRole_bailout => 'Bailout';

  @override
  String get enum_tankRole_deco => 'Deko';

  @override
  String get enum_tankRole_diluent => 'Diluent';

  @override
  String get enum_tankRole_oxygenSupply => 'O₂-Versorgung';

  @override
  String get enum_tankRole_pony => 'Ponyflasche';

  @override
  String get enum_tankRole_sidemountLeft => 'Sidemount Links';

  @override
  String get enum_tankRole_sidemountRight => 'Sidemount Rechts';

  @override
  String get enum_tankRole_stage => 'Stageflasche';

  @override
  String get enum_visibility_excellent => 'Ausgezeichnet (>30m / >100ft)';

  @override
  String get enum_visibility_good => 'Gut (15-30m / 50-100ft)';

  @override
  String get enum_visibility_moderate => 'Maessig (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => 'Schlecht (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => 'Unbekannt';

  @override
  String get enum_waterType_brackish => 'Brackwasser';

  @override
  String get enum_waterType_fresh => 'Suesswasser';

  @override
  String get enum_waterType_salt => 'Salzwasser';

  @override
  String get enum_weightType_ankleWeights => 'Knoechelgewichte';

  @override
  String get enum_weightType_backplate => 'Backplate-Gewichte';

  @override
  String get enum_weightType_belt => 'Bleigurt';

  @override
  String get enum_weightType_integrated => 'Integrierte Gewichte';

  @override
  String get enum_weightType_mixed => 'Gemischt/Kombiniert';

  @override
  String get enum_weightType_trimWeights => 'Trimmgewichte';

  @override
  String get equipment_addSheet_brandHint => 'z. B. Scubapro';

  @override
  String get equipment_addSheet_brandLabel => 'Marke';

  @override
  String get equipment_addSheet_closeTooltip => 'Schliessen';

  @override
  String get equipment_addSheet_currencyLabel => 'Waehrung';

  @override
  String get equipment_addSheet_dateLabel => 'Datum';

  @override
  String equipment_addSheet_errorSnackbar(Object error) {
    return 'Fehler beim Hinzufuegen der Ausruestung: $error';
  }

  @override
  String get equipment_addSheet_modelHint => 'z. B. MK25 EVO';

  @override
  String get equipment_addSheet_modelLabel => 'Modell';

  @override
  String get equipment_addSheet_nameHint => 'z. B. Mein Hauptatemregler';

  @override
  String get equipment_addSheet_nameLabel => 'Name';

  @override
  String get equipment_addSheet_nameValidation =>
      'Bitte geben Sie einen Namen ein';

  @override
  String get equipment_addSheet_notesHint => 'Zusaetzliche Notizen...';

  @override
  String get equipment_addSheet_notesLabel => 'Notizen';

  @override
  String get equipment_addSheet_priceLabel => 'Preis';

  @override
  String get equipment_addSheet_purchaseInfoTitle => 'Kaufinformationen';

  @override
  String get equipment_addSheet_serialNumberLabel => 'Seriennummer';

  @override
  String get equipment_addSheet_serviceIntervalHint =>
      'z. B. 365 fuer jaehrlich';

  @override
  String get equipment_addSheet_serviceIntervalLabel =>
      'Wartungsintervall (Tage)';

  @override
  String get equipment_addSheet_sizeHint => 'z. B. M, L, 42';

  @override
  String get equipment_addSheet_sizeLabel => 'Groesse';

  @override
  String get equipment_addSheet_submitButton => 'Ausruestung hinzufuegen';

  @override
  String get equipment_addSheet_successSnackbar =>
      'Ausruestung erfolgreich hinzugefuegt';

  @override
  String get equipment_addSheet_title => 'Ausruestung hinzufuegen';

  @override
  String get equipment_addSheet_typeLabel => 'Typ';

  @override
  String get equipment_appBar_title => 'Ausruestung';

  @override
  String get equipment_deleteDialog_cancel => 'Abbrechen';

  @override
  String get equipment_deleteDialog_confirm => 'Loeschen';

  @override
  String get equipment_deleteDialog_content =>
      'Sind Sie sicher, dass Sie diese Ausruestung loeschen moechten? Diese Aktion kann nicht rueckgaengig gemacht werden.';

  @override
  String get equipment_deleteDialog_title => 'Ausruestung loeschen';

  @override
  String get equipment_detail_brandLabel => 'Marke';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return '$days Tage ueberfaellig';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days Tage bis zur Wartung';
  }

  @override
  String get equipment_detail_detailsTitle => 'Details';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count Tauchgaenge';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count Tauchgang';
  }

  @override
  String get equipment_detail_divesLabel => 'Tauchgaenge';

  @override
  String get equipment_detail_divesSemanticLabel =>
      'Tauchgaenge mit dieser Ausruestung anzeigen';

  @override
  String equipment_detail_durationDays(Object days) {
    return '$days Tage';
  }

  @override
  String equipment_detail_durationMonths(Object months) {
    return '$months Monate';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralPlural(
    Object years,
    Object months,
  ) {
    return '$years Jahre, $months Monate';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralSingular(
    Object years,
    Object months,
  ) {
    return '$years Jahre, $months Monat';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularPlural(
    Object years,
    Object months,
  ) {
    return '$years Jahr, $months Monate';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularSingular(
    Object years,
    Object months,
  ) {
    return '$years Jahr, $months Monat';
  }

  @override
  String equipment_detail_durationYearsPlural(Object years) {
    return '$years Jahre';
  }

  @override
  String equipment_detail_durationYearsSingular(Object years) {
    return '$years Jahr';
  }

  @override
  String get equipment_detail_editTooltip => 'Ausruestung bearbeiten';

  @override
  String get equipment_detail_editTooltipShort => 'Bearbeiten';

  @override
  String equipment_detail_errorMessage(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get equipment_detail_errorTitle => 'Fehler';

  @override
  String get equipment_detail_lastServiceLabel => 'Letzte Wartung';

  @override
  String get equipment_detail_loadingTitle => 'Wird geladen...';

  @override
  String get equipment_detail_modelLabel => 'Modell';

  @override
  String get equipment_detail_nextServiceDueLabel => 'Naechste Wartung faellig';

  @override
  String get equipment_detail_notFoundMessage =>
      'Dieser Ausruestungsgegenstand existiert nicht mehr.';

  @override
  String get equipment_detail_notFoundTitle => 'Ausruestung nicht gefunden';

  @override
  String get equipment_detail_notesTitle => 'Notizen';

  @override
  String get equipment_detail_ownedForLabel => 'Im Besitz seit';

  @override
  String get equipment_detail_purchaseDateLabel => 'Kaufdatum';

  @override
  String get equipment_detail_purchasePriceLabel => 'Kaufpreis';

  @override
  String get equipment_detail_retiredChip => 'Ausgemustert';

  @override
  String get equipment_detail_serialNumberLabel => 'Seriennummer';

  @override
  String get equipment_detail_serviceInfoTitle => 'Wartungsinformationen';

  @override
  String get equipment_detail_serviceIntervalLabel => 'Wartungsintervall';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days Tage';
  }

  @override
  String get equipment_detail_serviceOverdue => 'Wartung ist ueberfaellig!';

  @override
  String get equipment_detail_sizeLabel => 'Groesse';

  @override
  String get equipment_detail_statusLabel => 'Status';

  @override
  String equipment_detail_tripsCountPlural(Object count) {
    return '$count Reisen';
  }

  @override
  String equipment_detail_tripsCountSingular(Object count) {
    return '$count Reise';
  }

  @override
  String get equipment_detail_tripsLabel => 'Reisen';

  @override
  String get equipment_detail_tripsSemanticLabel =>
      'Reisen mit dieser Ausruestung anzeigen';

  @override
  String get equipment_edit_appBar_editTitle => 'Ausruestung bearbeiten';

  @override
  String get equipment_edit_appBar_newTitle => 'Neue Ausruestung';

  @override
  String get equipment_edit_appBar_saveButton => 'Speichern';

  @override
  String get equipment_edit_appBar_saveTooltip =>
      'Ausruestungsaenderungen speichern';

  @override
  String get equipment_edit_brandLabel => 'Marke';

  @override
  String get equipment_edit_clearDate => 'Datum loeschen';

  @override
  String get equipment_edit_currencyLabel => 'Waehrung';

  @override
  String get equipment_edit_disableReminders => 'Erinnerungen deaktivieren';

  @override
  String get equipment_edit_disableRemindersSubtitle =>
      'Alle Benachrichtigungen fuer diesen Gegenstand deaktivieren';

  @override
  String get equipment_edit_discardDialog_content =>
      'Sie haben ungespeicherte Aenderungen. Sind Sie sicher, dass Sie die Seite verlassen moechten?';

  @override
  String get equipment_edit_discardDialog_discard => 'Verwerfen';

  @override
  String get equipment_edit_discardDialog_keepEditing => 'Weiter bearbeiten';

  @override
  String get equipment_edit_discardDialog_title => 'Aenderungen verwerfen?';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => 'Abbrechen';

  @override
  String get equipment_edit_embeddedHeader_editTitle =>
      'Ausruestung bearbeiten';

  @override
  String get equipment_edit_embeddedHeader_newTitle => 'Neue Ausruestung';

  @override
  String get equipment_edit_embeddedHeader_saveButton => 'Speichern';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit =>
      'Ausruestungsaenderungen speichern';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new =>
      'Neue Ausruestung hinzufuegen';

  @override
  String equipment_edit_errorMessage(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get equipment_edit_errorTitle => 'Fehler';

  @override
  String get equipment_edit_lastServiceDateLabel => 'Letztes Wartungsdatum';

  @override
  String get equipment_edit_loadingTitle => 'Wird geladen...';

  @override
  String get equipment_edit_modelLabel => 'Modell';

  @override
  String get equipment_edit_nameHint => 'z. B. Mein Hauptatemregler';

  @override
  String get equipment_edit_nameLabel => 'Name *';

  @override
  String get equipment_edit_nameValidation => 'Bitte geben Sie einen Namen ein';

  @override
  String get equipment_edit_notFoundMessage =>
      'Dieser Ausruestungsgegenstand existiert nicht mehr.';

  @override
  String get equipment_edit_notFoundTitle => 'Ausruestung nicht gefunden';

  @override
  String get equipment_edit_notesHint =>
      'Zusaetzliche Notizen zu dieser Ausruestung...';

  @override
  String get equipment_edit_notesLabel => 'Notizen';

  @override
  String get equipment_edit_notificationsSubtitle =>
      'Globale Benachrichtigungseinstellungen fuer diesen Gegenstand ueberschreiben';

  @override
  String get equipment_edit_notificationsTitle =>
      'Benachrichtigungen (Optional)';

  @override
  String get equipment_edit_purchaseDateLabel => 'Kaufdatum';

  @override
  String get equipment_edit_purchaseInfoTitle => 'Kaufinformationen';

  @override
  String get equipment_edit_purchasePriceLabel => 'Kaufpreis';

  @override
  String get equipment_edit_remindMeBeforeServiceDue =>
      'Erinnern Sie mich vor der faelligen Wartung:';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days Tage';
  }

  @override
  String get equipment_edit_saveButton_edit => 'Aenderungen speichern';

  @override
  String get equipment_edit_saveButton_new => 'Ausruestung hinzufuegen';

  @override
  String get equipment_edit_saveTooltip_edit =>
      'Ausruestungsaenderungen speichern';

  @override
  String get equipment_edit_saveTooltip_new =>
      'Neuen Ausruestungsgegenstand hinzufuegen';

  @override
  String get equipment_edit_selectDate => 'Datum auswaehlen';

  @override
  String get equipment_edit_serialNumberLabel => 'Seriennummer';

  @override
  String get equipment_edit_serviceIntervalHint => 'z. B. 365 fuer jaehrlich';

  @override
  String get equipment_edit_serviceIntervalLabel => 'Wartungsintervall (Tage)';

  @override
  String get equipment_edit_serviceSettingsTitle => 'Wartungseinstellungen';

  @override
  String get equipment_edit_sizeHint => 'z. B. M, L, 42';

  @override
  String get equipment_edit_sizeLabel => 'Groesse';

  @override
  String get equipment_edit_snackbar_added => 'Ausruestung hinzugefuegt';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return 'Fehler beim Speichern der Ausruestung: $error';
  }

  @override
  String get equipment_edit_snackbar_updated => 'Ausruestung aktualisiert';

  @override
  String get equipment_edit_statusLabel => 'Status';

  @override
  String get equipment_edit_typeLabel => 'Typ *';

  @override
  String get equipment_edit_useCustomReminders =>
      'Eigene Erinnerungen verwenden';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'Andere Erinnerungstage fuer diesen Gegenstand festlegen';

  @override
  String get equipment_fab_addEquipment => 'Ausruestung hinzufuegen';

  @override
  String get equipment_list_emptyState_addFirstButton =>
      'Erste Ausruestung hinzufuegen';

  @override
  String get equipment_list_emptyState_addPrompt =>
      'Fuegen Sie Ihre Tauchausruestung hinzu, um Nutzung und Wartung zu verfolgen';

  @override
  String get equipment_list_emptyState_filterText_equipment => 'Ausruestung';

  @override
  String get equipment_list_emptyState_filterText_serviceDue =>
      'wartungsfaellige Ausruestung';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return '$status Ausruestung';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return 'Keine $filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch =>
      'Keine Ausruestung mit diesem Status';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate =>
      'Alle Ihre Ausruestungsgegenstaende sind wartungstechnisch auf dem neuesten Stand!';

  @override
  String equipment_list_errorLoading(Object error) {
    return 'Fehler beim Laden der Ausruestung: $error';
  }

  @override
  String get equipment_list_filterAll => 'Gesamte Ausruestung';

  @override
  String get equipment_list_filterLabel => 'Filter:';

  @override
  String get equipment_list_filterServiceDue => 'Wartung faellig';

  @override
  String get equipment_list_retryButton => 'Erneut versuchen';

  @override
  String get equipment_list_searchTooltip => 'Ausruestung suchen';

  @override
  String get equipment_list_setsTooltip => 'Ausruestungssets';

  @override
  String get equipment_list_sortTitle => 'Ausruestung sortieren';

  @override
  String get equipment_list_sortTooltip => 'Sortieren';

  @override
  String equipment_list_tile_daysCount(Object days) {
    return '$days Tage';
  }

  @override
  String get equipment_list_tile_serviceDueChip => 'Wartung faellig';

  @override
  String get equipment_list_tile_serviceIn => 'Wartung in';

  @override
  String get equipment_menu_delete => 'Loeschen';

  @override
  String get equipment_menu_markAsServiced => 'Als gewartet markieren';

  @override
  String get equipment_menu_reactivate => 'Reaktivieren';

  @override
  String get equipment_menu_retireEquipment => 'Ausruestung ausmustern';

  @override
  String get equipment_search_backTooltip => 'Zurueck';

  @override
  String get equipment_search_clearTooltip => 'Suche loeschen';

  @override
  String get equipment_search_fieldLabel => 'Ausruestung suchen...';

  @override
  String get equipment_search_hint =>
      'Suche nach Name, Marke, Modell oder Seriennummer';

  @override
  String equipment_search_noResults(Object query) {
    return 'Keine Ausruestung fuer \"$query\" gefunden';
  }

  @override
  String get equipment_serviceDialog_addButton => 'Hinzufuegen';

  @override
  String get equipment_serviceDialog_addTitle => 'Wartungseintrag hinzufuegen';

  @override
  String get equipment_serviceDialog_cancelButton => 'Abbrechen';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip =>
      'Naechstes Wartungsdatum loeschen';

  @override
  String get equipment_serviceDialog_costHint => '0,00';

  @override
  String get equipment_serviceDialog_costLabel => 'Kosten';

  @override
  String get equipment_serviceDialog_costValidation =>
      'Geben Sie einen gueltigen Betrag ein';

  @override
  String get equipment_serviceDialog_editTitle => 'Wartungseintrag bearbeiten';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel =>
      'Naechste Wartung faellig';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel =>
      'Naechstes Wartungsdatum auswaehlen';

  @override
  String get equipment_serviceDialog_nextServiceNotSet => 'Nicht festgelegt';

  @override
  String get equipment_serviceDialog_notesLabel => 'Notizen';

  @override
  String get equipment_serviceDialog_providerHint =>
      'z. B. Name des Tauchshops';

  @override
  String get equipment_serviceDialog_providerLabel => 'Anbieter/Shop';

  @override
  String get equipment_serviceDialog_serviceDateLabel => 'Wartungsdatum';

  @override
  String get equipment_serviceDialog_serviceDateSemanticLabel =>
      'Wartungsdatum auswaehlen';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => 'Wartungsart';

  @override
  String get equipment_serviceDialog_snackbar_added =>
      'Wartungseintrag hinzugefuegt';

  @override
  String equipment_serviceDialog_snackbar_error(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get equipment_serviceDialog_snackbar_updated =>
      'Wartungseintrag aktualisiert';

  @override
  String get equipment_serviceDialog_updateButton => 'Aktualisieren';

  @override
  String get equipment_service_addButton => 'Hinzufuegen';

  @override
  String get equipment_service_deleteDialog_cancel => 'Abbrechen';

  @override
  String get equipment_service_deleteDialog_confirm => 'Loeschen';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return 'Sind Sie sicher, dass Sie diesen $serviceType-Eintrag loeschen moechten?';
  }

  @override
  String get equipment_service_deleteDialog_title =>
      'Wartungseintrag loeschen?';

  @override
  String get equipment_service_deleteMenuItem => 'Loeschen';

  @override
  String get equipment_service_editMenuItem => 'Bearbeiten';

  @override
  String get equipment_service_emptyState => 'Noch keine Wartungseintraege';

  @override
  String get equipment_service_historyTitle => 'Wartungsverlauf';

  @override
  String get equipment_service_snackbar_deleted => 'Wartungseintrag geloescht';

  @override
  String get equipment_service_totalCostLabel => 'Gesamte Wartungskosten';

  @override
  String get equipment_setDetail_addEquipmentButton =>
      'Ausruestung hinzufuegen';

  @override
  String get equipment_setDetail_deleteDialog_cancel => 'Abbrechen';

  @override
  String get equipment_setDetail_deleteDialog_confirm => 'Loeschen';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      'Sind Sie sicher, dass Sie dieses Ausruestungsset loeschen moechten? Die enthaltenen Ausruestungsgegenstaende werden nicht geloescht.';

  @override
  String get equipment_setDetail_deleteDialog_title =>
      'Ausruestungsset loeschen';

  @override
  String get equipment_setDetail_deleteMenuItem => 'Loeschen';

  @override
  String get equipment_setDetail_editTooltip => 'Set bearbeiten';

  @override
  String get equipment_setDetail_emptySet => 'Keine Ausruestung in diesem Set';

  @override
  String get equipment_setDetail_equipmentInSetTitle =>
      'Ausruestung in diesem Set';

  @override
  String equipment_setDetail_errorMessage(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get equipment_setDetail_errorTitle => 'Fehler';

  @override
  String get equipment_setDetail_loadingTitle => 'Wird geladen...';

  @override
  String get equipment_setDetail_notFoundMessage =>
      'Dieses Ausruestungsset existiert nicht mehr.';

  @override
  String get equipment_setDetail_notFoundTitle => 'Set nicht gefunden';

  @override
  String get equipment_setDetail_snackbar_deleted =>
      'Ausruestungsset geloescht';

  @override
  String get equipment_setEdit_addEquipmentFirst =>
      'Fuegen Sie zuerst Ausruestung hinzu, bevor Sie ein Set erstellen.';

  @override
  String get equipment_setEdit_appBar_editTitle => 'Set bearbeiten';

  @override
  String get equipment_setEdit_appBar_newTitle => 'Neues Ausruestungsset';

  @override
  String get equipment_setEdit_descriptionHint => 'Optionale Beschreibung...';

  @override
  String get equipment_setEdit_descriptionLabel => 'Beschreibung';

  @override
  String equipment_setEdit_errorMessage(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get equipment_setEdit_errorTitle => 'Fehler';

  @override
  String get equipment_setEdit_loadingTitle => 'Wird geladen...';

  @override
  String get equipment_setEdit_nameHint => 'z. B. Warmwasser-Setup';

  @override
  String get equipment_setEdit_nameLabel => 'Set-Name *';

  @override
  String get equipment_setEdit_nameValidation =>
      'Bitte geben Sie einen Namen ein';

  @override
  String get equipment_setEdit_noEquipmentAvailable =>
      'Keine Ausruestung verfuegbar';

  @override
  String get equipment_setEdit_notFoundMessage =>
      'Dieses Ausruestungsset existiert nicht mehr.';

  @override
  String get equipment_setEdit_notFoundTitle => 'Set nicht gefunden';

  @override
  String get equipment_setEdit_saveButton_edit => 'Aenderungen speichern';

  @override
  String get equipment_setEdit_saveButton_new => 'Set erstellen';

  @override
  String get equipment_setEdit_saveTooltip_edit =>
      'Ausruestungsset-Aenderungen speichern';

  @override
  String get equipment_setEdit_saveTooltip_new =>
      'Neues Ausruestungsset erstellen';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle =>
      'Waehlen Sie die Ausruestungsgegenstaende aus, die in diesem Set enthalten sein sollen.';

  @override
  String get equipment_setEdit_selectEquipmentTitle => 'Ausruestung auswaehlen';

  @override
  String get equipment_setEdit_snackbar_created => 'Ausruestungsset erstellt';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return 'Fehler beim Speichern des Ausruestungssets: $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated =>
      'Ausruestungsset aktualisiert';

  @override
  String get equipment_sets_appBar_title => 'Ausruestungssets';

  @override
  String get equipment_sets_emptyState_createFirstButton =>
      'Erstes Set erstellen';

  @override
  String get equipment_sets_emptyState_description =>
      'Erstellen Sie Ausruestungssets, um haeufig verwendete Ausruestungskombinationen schnell zu Ihren Tauchgaengen hinzuzufuegen.';

  @override
  String get equipment_sets_emptyState_title => 'Keine Ausruestungssets';

  @override
  String equipment_sets_errorLoading(Object error) {
    return 'Fehler beim Laden der Sets: $error';
  }

  @override
  String get equipment_sets_fabTooltip => 'Neues Ausruestungsset erstellen';

  @override
  String get equipment_sets_fab_createSet => 'Set erstellen';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count Gegenstaende';
  }

  @override
  String equipment_sets_itemCountSemanticLabel(Object count) {
    return '$count im Set';
  }

  @override
  String equipment_sets_itemCountSingular(Object count) {
    return '$count Gegenstand';
  }

  @override
  String get equipment_sets_retryButton => 'Erneut versuchen';

  @override
  String get equipment_snackbar_deleted => 'Ausruestung geloescht';

  @override
  String get equipment_snackbar_markedAsServiced => 'Als gewartet markiert';

  @override
  String get equipment_snackbar_reactivated => 'Ausruestung reaktiviert';

  @override
  String get equipment_snackbar_retired => 'Ausruestung ausgemustert';

  @override
  String get equipment_summary_active => 'Aktiv';

  @override
  String get equipment_summary_addEquipmentButton => 'Ausruestung hinzufuegen';

  @override
  String get equipment_summary_equipmentSetsButton => 'Ausruestungssets';

  @override
  String get equipment_summary_overviewTitle => 'Uebersicht';

  @override
  String get equipment_summary_quickActionsTitle => 'Schnellaktionen';

  @override
  String get equipment_summary_recentEquipmentTitle => 'Letzte Ausruestung';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name, $type';
  }

  @override
  String get equipment_summary_selectPrompt =>
      'Waehlen Sie einen Ausruestungsgegenstand aus der Liste, um Details anzuzeigen';

  @override
  String get equipment_summary_serviceDue => 'Wartung faellig';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name, $type, Wartung faellig';
  }

  @override
  String get equipment_summary_serviceDueTitle => 'Wartung faellig';

  @override
  String get equipment_summary_title => 'Ausruestung';

  @override
  String get equipment_summary_totalItems => 'Gegenstaende gesamt';

  @override
  String get equipment_summary_totalValue => 'Gesamtwert';

  @override
  String get formatter_approximate_prefix => '~';

  @override
  String get formatter_connector_at => 'bei';

  @override
  String get formatter_connector_from => 'Von';

  @override
  String get formatter_connector_until => 'Bis';

  @override
  String get gas_air_description => 'Standardluft (21% O2)';

  @override
  String get gas_air_displayName => 'Luft';

  @override
  String get gas_diluentAir_description =>
      'Standard-Luftdiluent fuer flaches CCR';

  @override
  String get gas_diluentAir_displayName => 'Luft-Diluent';

  @override
  String get gas_diluentTx1070_description =>
      'Hypoxischer Diluent fuer sehr tiefes CCR';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description =>
      'Hypoxischer Diluent fuer tiefes CCR';

  @override
  String get gas_diluentTx1260_displayName => 'Tx 12/60';

  @override
  String get gas_ean32_description => 'Nitrox 32%';

  @override
  String get gas_ean32_displayName => 'EAN32';

  @override
  String get gas_ean36_description => 'Nitrox 36%';

  @override
  String get gas_ean36_displayName => 'EAN36';

  @override
  String get gas_ean40_description => 'Nitrox 40%';

  @override
  String get gas_ean40_displayName => 'EAN40';

  @override
  String get gas_ean50_description => 'Dekogas - 50% O2';

  @override
  String get gas_ean50_displayName => 'EAN50';

  @override
  String get gas_helitrox2525_description =>
      'Helitrox 25/25 (Freizeittechnisch)';

  @override
  String get gas_helitrox2525_displayName => 'Helitrox 25/25';

  @override
  String get gas_oxygen_description => 'Reiner Sauerstoff (nur 6m Deko)';

  @override
  String get gas_oxygen_displayName => 'Sauerstoff';

  @override
  String get gas_scrEan40_description => 'SCR-Versorgungsgas - 40% O2';

  @override
  String get gas_scrEan40_displayName => 'SCR EAN40';

  @override
  String get gas_scrEan50_description => 'SCR-Versorgungsgas - 50% O2';

  @override
  String get gas_scrEan50_displayName => 'SCR EAN50';

  @override
  String get gas_scrEan60_description => 'SCR-Versorgungsgas - 60% O2';

  @override
  String get gas_scrEan60_displayName => 'SCR EAN60';

  @override
  String get gas_tmx1555_description => 'Hypoxisches Trimix 15/55 (sehr tief)';

  @override
  String get gas_tmx1555_displayName => 'Tx 15/55';

  @override
  String get gas_tmx1845_description => 'Trimix 18/45 (Tieftauchen)';

  @override
  String get gas_tmx1845_displayName => 'Tx 18/45';

  @override
  String get gas_tmx2135_description => 'Normoxisches Trimix 21/35';

  @override
  String get gas_tmx2135_displayName => 'Tx 21/35';

  @override
  String get gasCalculators_bestMix_bestOxygenMix => 'Bestes Sauerstoffgemisch';

  @override
  String get gasCalculators_bestMix_commonMixesRef =>
      'Gebräuchliche Gemische - Referenz';

  @override
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2) {
    return 'Luft-MOD bei ppO₂ $ppO2 überschritten';
  }

  @override
  String get gasCalculators_bestMix_targetDepth => 'Zieltiefe';

  @override
  String get gasCalculators_bestMix_targetDive => 'Zieltauchgang';

  @override
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  ) {
    return 'Umgebungsdruck bei $depth$depthSymbol';
  }

  @override
  String get gasCalculators_consumption_avgDepth => 'Durchschnittliche Tiefe';

  @override
  String get gasCalculators_consumption_breakdown =>
      'Berechnungsaufschlüsselung';

  @override
  String get gasCalculators_consumption_diveTime => 'Tauchzeit';

  @override
  String gasCalculators_consumption_exceedsTank(
    Object pressure,
    Object symbol,
  ) {
    return 'Überschreitet Flaschenkapazität ($pressure $symbol)';
  }

  @override
  String get gasCalculators_consumption_gasAtDepth =>
      'Gasverbrauch in der Tiefe';

  @override
  String get gasCalculators_consumption_pressure => 'Druck';

  @override
  String get gasCalculators_consumption_remainingGas => 'Verbleibendes Gas';

  @override
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  ) {
    return 'Flaschenkapazität ($tankSize$volumeSymbol @ $fillPressure $pressureSymbol)';
  }

  @override
  String get gasCalculators_consumption_title => 'Gasverbrauch';

  @override
  String gasCalculators_consumption_totalGas(Object time) {
    return 'Gesamtgas für $time Minuten';
  }

  @override
  String get gasCalculators_consumption_volume => 'Volumen';

  @override
  String get gasCalculators_mod_aboutMod => 'Über MOD';

  @override
  String get gasCalculators_mod_aboutModBody =>
      'Weniger O₂ = tiefere MOD = kürzere Nullzeit';

  @override
  String get gasCalculators_mod_inputParameters => 'Eingabeparameter';

  @override
  String get gasCalculators_mod_maximumOperatingDepth =>
      'Maximale Einsatztiefe';

  @override
  String get gasCalculators_mod_oxygenO2 => 'Sauerstoff (O₂)';

  @override
  String get gasCalculators_mod_ppO2Conservative =>
      'Konservatives Limit für längere Grundzeit';

  @override
  String get gasCalculators_mod_ppO2Maximum =>
      'Maximales Limit nur für Dekostopps';

  @override
  String get gasCalculators_mod_ppO2Standard =>
      'Standard-Arbeitslimit für Sporttauchen';

  @override
  String get gasCalculators_ppO2Limit => 'ppO₂-Limit';

  @override
  String get gasCalculators_resetAll => 'Alle Rechner zurücksetzen';

  @override
  String get gasCalculators_sacRate => 'AMV-Rate';

  @override
  String get gasCalculators_tab_bestMix => 'Bestes Gemisch';

  @override
  String get gasCalculators_tab_consumption => 'Verbrauch';

  @override
  String get gasCalculators_tab_mod => 'MOD';

  @override
  String get gasCalculators_tab_rockBottom => 'Rock Bottom';

  @override
  String get gasCalculators_tankSize => 'Flaschengröße';

  @override
  String get gasCalculators_title => 'Gasrechner';

  @override
  String get marineLife_siteSection_editExpectedTooltip =>
      'Erwartete Arten bearbeiten';

  @override
  String get marineLife_siteSection_errorLoadingExpected =>
      'Fehler beim Laden der erwarteten Arten';

  @override
  String get marineLife_siteSection_errorLoadingSightings =>
      'Fehler beim Laden der Sichtungen';

  @override
  String get marineLife_siteSection_expectedSpecies => 'Erwartete Arten';

  @override
  String get marineLife_siteSection_noExpected =>
      'Keine erwarteten Arten hinzugefuegt';

  @override
  String get marineLife_siteSection_noSpotted =>
      'Noch keine Meeresbewohner gesichtet';

  @override
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  ) {
    return '$name, $count Mal gesichtet';
  }

  @override
  String get marineLife_siteSection_spottedHere => 'Hier gesichtet';

  @override
  String get marineLife_siteSection_title => 'Meeresbewohner';

  @override
  String get marineLife_speciesDetail_backTooltip => 'Zurueck';

  @override
  String get marineLife_speciesDetail_depthRangeTitle => 'Tiefenbereich';

  @override
  String get marineLife_speciesDetail_descriptionTitle => 'Beschreibung';

  @override
  String get marineLife_speciesDetail_divesLabel => 'Tauchgaenge';

  @override
  String get marineLife_speciesDetail_editTooltip => 'Art bearbeiten';

  @override
  String marineLife_speciesDetail_errorPrefix(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get marineLife_speciesDetail_noSightings =>
      'Noch keine Sichtungen erfasst';

  @override
  String get marineLife_speciesDetail_notFound => 'Art nicht gefunden';

  @override
  String marineLife_speciesDetail_sightingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sichtungen',
      one: 'Sichtung',
    );
    return '$count $_temp0';
  }

  @override
  String get marineLife_speciesDetail_sightingPeriodTitle =>
      'Sichtungszeitraum';

  @override
  String get marineLife_speciesDetail_sightingStatsTitle =>
      'Sichtungsstatistik';

  @override
  String get marineLife_speciesDetail_sitesLabel => 'Tauchplaetze';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return 'Klasse: $className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle =>
      'Haeufigste Tauchplaetze';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel =>
      'Sichtungen gesamt';

  @override
  String get marineLife_speciesEdit_addTitle => 'Art hinzufuegen';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return '\"$name\" hinzugefuegt';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => 'Zurueck';

  @override
  String get marineLife_speciesEdit_categoryLabel => 'Kategorie';

  @override
  String get marineLife_speciesEdit_commonNameError =>
      'Bitte geben Sie einen allgemeinen Namen ein';

  @override
  String get marineLife_speciesEdit_commonNameHint =>
      'z.B. Falscher Clownfisch';

  @override
  String get marineLife_speciesEdit_commonNameLabel => 'Allgemeiner Name';

  @override
  String get marineLife_speciesEdit_descriptionHint =>
      'Kurze Beschreibung der Art...';

  @override
  String get marineLife_speciesEdit_descriptionLabel => 'Beschreibung';

  @override
  String get marineLife_speciesEdit_editTitle => 'Art bearbeiten';

  @override
  String marineLife_speciesEdit_errorLoading(Object error) {
    return 'Fehler beim Laden der Art: $error';
  }

  @override
  String marineLife_speciesEdit_errorSaving(Object error) {
    return 'Fehler beim Speichern der Art: $error';
  }

  @override
  String get marineLife_speciesEdit_saveButton => 'Speichern';

  @override
  String get marineLife_speciesEdit_scientificNameHint =>
      'z.B. Amphiprion ocellaris';

  @override
  String get marineLife_speciesEdit_scientificNameLabel =>
      'Wissenschaftlicher Name';

  @override
  String get marineLife_speciesEdit_taxonomyClassHint => 'z.B. Actinopterygii';

  @override
  String get marineLife_speciesEdit_taxonomyClassLabel => 'Taxonomische Klasse';

  @override
  String marineLife_speciesEdit_updatedSnackbar(Object name) {
    return '\"$name\" aktualisiert';
  }

  @override
  String get marineLife_speciesManage_allFilter => 'Alle';

  @override
  String get marineLife_speciesManage_appBarTitle => 'Arten';

  @override
  String get marineLife_speciesManage_backTooltip => 'Zurueck';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return 'Integrierte Arten ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => 'Abbrechen';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return '\"$name\" kann nicht geloescht werden - es gibt Sichtungen';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip => 'Suche loeschen';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return 'Benutzerdefinierte Arten ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => 'Loeschen';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return 'Sind Sie sicher, dass Sie \"$name\" loeschen moechten?';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle => 'Art loeschen?';

  @override
  String get marineLife_speciesManage_deleteTooltip => 'Art loeschen';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return '\"$name\" geloescht';
  }

  @override
  String get marineLife_speciesManage_editTooltip => 'Art bearbeiten';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return 'Fehler beim Loeschen der Art: $error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return 'Fehler beim Zuruecksetzen der Arten: $error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound => 'Keine Arten gefunden';

  @override
  String get marineLife_speciesManage_resetButton => 'Zuruecksetzen';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      'Dadurch werden alle integrierten Arten auf ihre urspruenglichen Werte zurueckgesetzt. Benutzerdefinierte Arten werden nicht beeinflusst. Integrierte Arten mit vorhandenen Sichtungen werden aktualisiert, aber beibehalten.';

  @override
  String get marineLife_speciesManage_resetDialogTitle =>
      'Auf Standardwerte zuruecksetzen?';

  @override
  String get marineLife_speciesManage_resetSuccess =>
      'Integrierte Arten auf Standardwerte zurueckgesetzt';

  @override
  String get marineLife_speciesManage_resetToDefaults =>
      'Auf Standardwerte zuruecksetzen';

  @override
  String get marineLife_speciesManage_searchHint => 'Arten durchsuchen...';

  @override
  String get marineLife_speciesPicker_allFilter => 'Alle';

  @override
  String get marineLife_speciesPicker_cancelButton => 'Abbrechen';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip => 'Suche loeschen';

  @override
  String get marineLife_speciesPicker_closeTooltip => 'Artenauswahl schliessen';

  @override
  String get marineLife_speciesPicker_doneButton => 'Fertig';

  @override
  String marineLife_speciesPicker_error(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get marineLife_speciesPicker_noSpeciesFound => 'Keine Arten gefunden';

  @override
  String get marineLife_speciesPicker_searchHint => 'Arten durchsuchen...';

  @override
  String marineLife_speciesPicker_selectedCount(Object count) {
    return '$count ausgewaehlt';
  }

  @override
  String get marineLife_speciesPicker_title => 'Arten auswaehlen';

  @override
  String get media_diveMediaSection_addTooltip => 'Foto oder Video hinzufuegen';

  @override
  String get media_diveMediaSection_cancelButton => 'Abbrechen';

  @override
  String get media_diveMediaSection_emptyState => 'Noch keine Fotos';

  @override
  String get media_diveMediaSection_errorLoading =>
      'Fehler beim Laden der Medien';

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Foto anzeigen. Lange druecken zum Trennen';

  @override
  String get media_diveMediaSection_title => 'Fotos & Video';

  @override
  String get media_diveMediaSection_unlinkButton => 'Trennen';

  @override
  String get media_diveMediaSection_unlinkDialogContent =>
      'Dieses Foto vom Tauchgang entfernen? Das Foto bleibt in Ihrer Galerie erhalten.';

  @override
  String get media_diveMediaSection_unlinkDialogTitle => 'Foto trennen';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Trennen fehlgeschlagen: $error';
  }

  @override
  String get media_diveMediaSection_unlinkSuccess => 'Foto getrennt';

  @override
  String get media_gpsBanner_addToSiteButton => 'Zum Tauchplatz hinzufuegen';

  @override
  String media_gpsBanner_coordinates(Object latitude, Object longitude) {
    return 'Koordinaten: $latitude, $longitude';
  }

  @override
  String get media_gpsBanner_createSiteButton => 'Tauchplatz erstellen';

  @override
  String get media_gpsBanner_dismissTooltip => 'GPS-Vorschlag schliessen';

  @override
  String get media_gpsBanner_title => 'GPS in Fotos gefunden';

  @override
  String media_import_failedToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fotos',
      one: 'Foto',
    );
    return '$_temp0 konnte nicht importiert werden';
  }

  @override
  String media_import_failedToImportError(Object error) {
    return 'Fotos konnten nicht importiert werden: $error';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return '$imported importiert, $failed fehlgeschlagen';
  }

  @override
  String media_import_importedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fotos',
      one: 'Foto',
    );
    return '$count $_temp0 importiert';
  }

  @override
  String media_import_importingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fotos',
      one: 'Foto',
    );
    return '$count $_temp0 werden importiert...';
  }

  @override
  String get media_miniProfile_headerLabel => 'Tauchprofil';

  @override
  String get media_miniProfile_semanticLabel => 'Mini-Tauchprofildiagramm';

  @override
  String get media_photoPicker_appBarTitle => 'Fotos auswaehlen';

  @override
  String get media_photoPicker_closeTooltip => 'Fotoauswahl schliessen';

  @override
  String get media_photoPicker_doneButton => 'Fertig';

  @override
  String media_photoPicker_doneCountButton(Object count) {
    return 'Fertig ($count)';
  }

  @override
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  ) {
    return 'Es wurden keine Fotos zwischen $startDate $startTime und $endDate $endTime gefunden.';
  }

  @override
  String get media_photoPicker_emptyTitle => 'Keine Fotos gefunden';

  @override
  String get media_photoPicker_grantAccessButton => 'Zugriff erlauben';

  @override
  String get media_photoPicker_openSettingsButton => 'Einstellungen oeffnen';

  @override
  String get media_photoPicker_openSettingsSnackbar =>
      'Bitte oeffnen Sie die Einstellungen und aktivieren Sie den Fotozugriff';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'Der Zugriff auf die Fotobibliothek wurde verweigert. Bitte aktivieren Sie ihn in den Einstellungen, um Tauchfotos hinzuzufuegen.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion benoetigt Zugriff auf Ihre Fotobibliothek, um Tauchfotos hinzuzufuegen.';

  @override
  String get media_photoPicker_permissionTitle => 'Fotozugriff erforderlich';

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return 'Fotos werden angezeigt von $rangeText';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel =>
      'Auswahl fuer Foto umschalten';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel =>
      'Auswahl fuer Foto umschalten, ausgewaehlt';

  @override
  String get media_photoViewer_cannotShare =>
      'Dieses Foto kann nicht geteilt werden';

  @override
  String get media_photoViewer_cannotWriteMetadata =>
      'Metadaten koennen nicht geschrieben werden - Medium nicht mit Bibliothek verknuepft';

  @override
  String get media_photoViewer_closeTooltip => 'Fotoanzeige schliessen';

  @override
  String get media_photoViewer_diveDataWrittenToPhoto =>
      'Tauchdaten in Foto geschrieben';

  @override
  String get media_photoViewer_diveDataWrittenToVideo =>
      'Tauchdaten in Video geschrieben';

  @override
  String media_photoViewer_errorLoadingPhotos(Object error) {
    return 'Fehler beim Laden der Fotos: $error';
  }

  @override
  String get media_photoViewer_failedToLoadImage =>
      'Bild konnte nicht geladen werden';

  @override
  String get media_photoViewer_failedToLoadVideo =>
      'Video konnte nicht geladen werden';

  @override
  String media_photoViewer_failedToShare(Object error) {
    return 'Teilen fehlgeschlagen: $error';
  }

  @override
  String get media_photoViewer_failedToWriteMetadata =>
      'Metadaten konnten nicht geschrieben werden';

  @override
  String media_photoViewer_failedToWriteMetadataError(Object error) {
    return 'Metadaten konnten nicht geschrieben werden: $error';
  }

  @override
  String get media_photoViewer_noPhotosAvailable => 'Keine Fotos verfuegbar';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel =>
      'Video abspielen oder pausieren';

  @override
  String get media_photoViewer_seekVideoLabel => 'Videoposition suchen';

  @override
  String get media_photoViewer_shareTooltip => 'Foto teilen';

  @override
  String get media_photoViewer_toggleOverlayLabel => 'Foto-Overlay umschalten';

  @override
  String get media_photoViewer_videoFileNotFound => 'Videodatei nicht gefunden';

  @override
  String get media_photoViewer_videoNotLinked =>
      'Video nicht mit Bibliothek verknuepft';

  @override
  String get media_photoViewer_writeDiveDataTooltip =>
      'Tauchdaten in Foto schreiben';

  @override
  String get media_quickSiteDialog_cancelButton => 'Abbrechen';

  @override
  String get media_quickSiteDialog_createButton => 'Tauchplatz erstellen';

  @override
  String get media_quickSiteDialog_description =>
      'Erstellen Sie einen neuen Tauchplatz mit GPS-Koordinaten aus Ihrem Foto.';

  @override
  String get media_quickSiteDialog_siteNameError =>
      'Bitte geben Sie einen Tauchplatznamen ein';

  @override
  String get media_quickSiteDialog_siteNameHint =>
      'Geben Sie einen Namen fuer diesen Tauchplatz ein';

  @override
  String get media_quickSiteDialog_siteNameLabel => 'Tauchplatzname';

  @override
  String get media_quickSiteDialog_title => 'Tauchplatz erstellen';

  @override
  String get media_scanResults_allPhotosLinked =>
      'Alle Fotos bereits verknuepft';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return 'Alle $count Fotos dieser Reise sind bereits mit Tauchgaengen verknuepft.';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count Fotos bereits verknuepft';
  }

  @override
  String get media_scanResults_cancelButton => 'Abbrechen';

  @override
  String media_scanResults_diveNumber(Object number) {
    return 'Tauchgang #$number';
  }

  @override
  String media_scanResults_foundNewPhotos(Object count) {
    return '$count neue Fotos gefunden';
  }

  @override
  String get media_scanResults_linkButton => 'Verknuepfen';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return '$count Fotos verknuepfen';
  }

  @override
  String get media_scanResults_noPhotosFound => 'Keine Fotos gefunden';

  @override
  String get media_scanResults_okButton => 'OK';

  @override
  String get media_scanResults_unknownSite => 'Unbekannter Tauchplatz';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return '$count Fotos konnten keinem Tauchgang zugeordnet werden (ausserhalb der Tauchzeiten aufgenommen)';
  }

  @override
  String get media_writeMetadata_cancelButton => 'Abbrechen';

  @override
  String get media_writeMetadata_depthLabel => 'Tiefe';

  @override
  String get media_writeMetadata_descriptionPhoto =>
      'Die folgenden Metadaten werden in das Foto geschrieben:';

  @override
  String get media_writeMetadata_descriptionVideo =>
      'Die folgenden Metadaten werden in das Video geschrieben:';

  @override
  String get media_writeMetadata_diveTimeLabel => 'Tauchzeit';

  @override
  String get media_writeMetadata_gpsLabel => 'GPS';

  @override
  String get media_writeMetadata_keepOriginalVideo =>
      'Originalvideo beibehalten';

  @override
  String get media_writeMetadata_noDataAvailable =>
      'Keine Tauchdaten zum Schreiben verfuegbar.';

  @override
  String get media_writeMetadata_siteLabel => 'Tauchplatz';

  @override
  String get media_writeMetadata_temperatureLabel => 'Temperatur';

  @override
  String get media_writeMetadata_titlePhoto => 'Tauchdaten in Foto schreiben';

  @override
  String get media_writeMetadata_titleVideo => 'Tauchdaten in Video schreiben';

  @override
  String get media_writeMetadata_warningPhotoText =>
      'Dadurch wird das Originalfoto veraendert.';

  @override
  String get media_writeMetadata_warningVideoText =>
      'Es wird ein neues Video mit den Metadaten erstellt. Video-Metadaten koennen nicht direkt veraendert werden.';

  @override
  String get media_writeMetadata_writeButton => 'Schreiben';

  @override
  String get nav_buddies => 'Tauchpartner';

  @override
  String get nav_certifications => 'Brevets';

  @override
  String get nav_courses => 'Kurse';

  @override
  String get nav_coursesSubtitle => 'Ausbildung & Weiterbildung';

  @override
  String get nav_diveCenters => 'Tauchbasen';

  @override
  String get nav_dives => 'Tauchgaenge';

  @override
  String get nav_equipment => 'Ausruestung';

  @override
  String get nav_home => 'Startseite';

  @override
  String get nav_more => 'Mehr';

  @override
  String get nav_planning => 'Planung';

  @override
  String get nav_planningSubtitle => 'Tauchplaner, Rechner';

  @override
  String get nav_settings => 'Einstellungen';

  @override
  String get nav_sites => 'Tauchplaetze';

  @override
  String get nav_statistics => 'Statistiken';

  @override
  String get nav_tooltip_closeMenu => 'Menue schliessen';

  @override
  String get nav_tooltip_collapseMenu => 'Menue einklappen';

  @override
  String get nav_tooltip_expandMenu => 'Menue ausklappen';

  @override
  String get nav_transfer => 'Uebertragung';

  @override
  String get nav_trips => 'Reisen';

  @override
  String get onboarding_welcome_createProfile => 'Erstellen Sie Ihr Profil';

  @override
  String get onboarding_welcome_createProfileSubtitle =>
      'Geben Sie Ihren Namen ein, um zu beginnen. Sie können später weitere Details hinzufügen.';

  @override
  String get onboarding_welcome_creating => 'Wird erstellt...';

  @override
  String onboarding_welcome_errorCreatingProfile(Object error) {
    return 'Fehler beim Erstellen des Profils: $error';
  }

  @override
  String get onboarding_welcome_getStarted => 'Loslegen';

  @override
  String get onboarding_welcome_nameHint => 'Geben Sie Ihren Namen ein';

  @override
  String get onboarding_welcome_nameLabel => 'Ihr Name';

  @override
  String get onboarding_welcome_nameValidation =>
      'Bitte geben Sie Ihren Namen ein';

  @override
  String get onboarding_welcome_subtitle =>
      'Erweiterte Tauchprotokollierung und -analyse';

  @override
  String get onboarding_welcome_title => 'Willkommen bei Submersion';

  @override
  String get planning_appBar_title => 'Planung';

  @override
  String get planning_card_decoCalculator_description =>
      'Berechnen Sie Nullzeitgrenzen, erforderliche Dekostopps und CNS/OTU-Belastung fuer mehrstufige Tauchprofile.';

  @override
  String get planning_card_decoCalculator_subtitle =>
      'Tauchgaenge mit Dekostopps planen';

  @override
  String get planning_card_decoCalculator_title => 'Deko-Rechner';

  @override
  String get planning_card_divePlanner_description =>
      'Planen Sie anspruchsvolle Tauchgaenge mit mehreren Tiefenstufen, Gaswechseln und automatischer Dekostopp-Berechnung.';

  @override
  String get planning_card_divePlanner_subtitle =>
      'Mehrstufige Tauchplaene erstellen';

  @override
  String get planning_card_divePlanner_title => 'Tauchplaner';

  @override
  String get planning_card_gasCalculators_description =>
      'Vier spezialisierte Gasrechner:\n- MOD - Maximale Einsatztiefe fuer ein Gasgemisch\n- Beste Mischung - Idealer O₂-Anteil fuer eine Zieltiefe\n- Verbrauch - Schaetzung des Gasverbrauchs\n- Mindrestreserve - Berechnung der Notfallreserve';

  @override
  String get planning_card_gasCalculators_subtitle =>
      'MOD, Beste Mischung, Verbrauch, Mindrestreserve';

  @override
  String get planning_card_gasCalculators_title => 'Gasrechner';

  @override
  String get planning_card_surfaceInterval_description =>
      'Berechnen Sie das erforderliche Mindestoberflaechen-Intervall zwischen Tauchgaengen basierend auf der Gewebebelastung. Visualisieren Sie, wie Ihre 16 Gewebekompartimente ueber die Zeit entsaettigen.';

  @override
  String get planning_card_surfaceInterval_subtitle =>
      'Wiederholungstauchgang-Intervalle planen';

  @override
  String get planning_card_surfaceInterval_title => 'Oberflaechen-Intervall';

  @override
  String get planning_card_weightCalculator_description =>
      'Schaetzen Sie das benoetigte Gewicht basierend auf Ihrem Tauchanzug, Flaschenmaterial, Wassertyp und Koerpergewicht.';

  @override
  String get planning_card_weightCalculator_subtitle =>
      'Empfohlenes Gewicht fuer Ihre Konfiguration';

  @override
  String get planning_card_weightCalculator_title => 'Gewichtsrechner';

  @override
  String get planning_info_disclaimer =>
      'Diese Werkzeuge dienen nur der Planung. Ueberpruefen Sie Berechnungen immer und befolgen Sie Ihre Tauchausbildung.';

  @override
  String get planning_sidebar_appBar_title => 'Planung';

  @override
  String get planning_sidebar_decoCalculator_subtitle => 'NDL & Dekostopps';

  @override
  String get planning_sidebar_decoCalculator_title => 'Deko-Rechner';

  @override
  String get planning_sidebar_divePlanner_subtitle => 'Mehrstufige Tauchplaene';

  @override
  String get planning_sidebar_divePlanner_title => 'Tauchplaner';

  @override
  String get planning_sidebar_gasCalculators_subtitle =>
      'MOD, Beste Mischung, mehr';

  @override
  String get planning_sidebar_gasCalculators_title => 'Gasrechner';

  @override
  String get planning_sidebar_info_disclaimer =>
      'Planungswerkzeuge dienen nur als Referenz. Ueberpruefen Sie Berechnungen immer.';

  @override
  String get planning_sidebar_surfaceInterval_subtitle =>
      'Wiederholungstauchgang-Planung';

  @override
  String get planning_sidebar_surfaceInterval_title => 'Oberflaechen-Intervall';

  @override
  String get planning_sidebar_weightCalculator_subtitle =>
      'Empfohlenes Gewicht';

  @override
  String get planning_sidebar_weightCalculator_title => 'Gewichtsrechner';

  @override
  String get planning_welcome_quickTips_title => 'Schnelltipps';

  @override
  String get planning_welcome_subtitle =>
      'Waehlen Sie ein Werkzeug aus der Seitenleiste, um zu beginnen';

  @override
  String get planning_welcome_tip_decoCalculator =>
      'Deko-Rechner fuer NDL und Stoppzeiten';

  @override
  String get planning_welcome_tip_divePlanner =>
      'Tauchplaner fuer mehrstufige Tauchplanung';

  @override
  String get planning_welcome_tip_gasCalculators =>
      'Gasrechner fuer MOD und Gasplanung';

  @override
  String get planning_welcome_tip_weightCalculator =>
      'Gewichtsrechner fuer die Tarierung';

  @override
  String get planning_welcome_title => 'Planungswerkzeuge';

  @override
  String get settings_about_aboutSubmersion => 'Ueber Submersion';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description =>
      'Verfolgen Sie Ihre Tauchgaenge, verwalten Sie Ausruestung und erkunden Sie Tauchplaetze.';

  @override
  String get settings_about_header => 'Ueber';

  @override
  String get settings_about_openSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get settings_about_reportIssue => 'Problem melden';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Besuchen Sie github.com/submersion/submersion';

  @override
  String settings_about_version(String version, String buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get settings_appBar_title => 'Einstellungen';

  @override
  String get settings_appearance_appLanguage => 'App-Sprache';

  @override
  String get settings_appearance_depthColoredCards =>
      'Tiefengefaerbte Tauchkarten';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Tauchkarten mit ozeanfarbenen Hintergruenden basierend auf der Tiefe anzeigen';

  @override
  String get settings_appearance_cardColorAttribute => 'Karten faerben nach';

  @override
  String get settings_appearance_cardColorAttribute_subtitle =>
      'Waehlen Sie, welches Attribut die Hintergrundfarbe der Karten bestimmt';

  @override
  String get settings_appearance_cardColorAttribute_none => 'Keine';

  @override
  String get settings_appearance_cardColorAttribute_depth => 'Tiefe';

  @override
  String get settings_appearance_cardColorAttribute_duration => 'Dauer';

  @override
  String get settings_appearance_cardColorAttribute_temperature => 'Temperatur';

  @override
  String get settings_appearance_colorGradient => 'Farbverlauf';

  @override
  String get settings_appearance_colorGradient_subtitle =>
      'Waehlen Sie den Farbbereich fuer Kartenhintergruende';

  @override
  String get settings_appearance_colorGradient_ocean => 'Ozean';

  @override
  String get settings_appearance_colorGradient_thermal => 'Thermal';

  @override
  String get settings_appearance_colorGradient_sunset => 'Sonnenuntergang';

  @override
  String get settings_appearance_colorGradient_forest => 'Wald';

  @override
  String get settings_appearance_colorGradient_monochrome => 'Monochrom';

  @override
  String get settings_appearance_colorGradient_custom => 'Benutzerdefiniert';

  @override
  String get settings_appearance_gasSwitchMarkers => 'Gaswechsel-Markierungen';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'Markierungen fuer Gaswechsel anzeigen';

  @override
  String get settings_appearance_header_diveLog => 'Tauchlogbuch';

  @override
  String get settings_appearance_header_diveProfile => 'Tauchprofil';

  @override
  String get settings_appearance_header_diveSites => 'Tauchplaetze';

  @override
  String get settings_appearance_header_language => 'Sprache';

  @override
  String get settings_appearance_header_theme => 'Design';

  @override
  String get settings_appearance_mapBackgroundDiveCards =>
      'Kartenhintergrund auf Tauchkarten';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitle =>
      'Tauchplatzkarte als Hintergrund auf Tauchkarten anzeigen';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote =>
      'Tauchplatzkarte als Hintergrund auf Tauchkarten anzeigen (erfordert Standort des Tauchplatzes)';

  @override
  String get settings_appearance_mapBackgroundSiteCards =>
      'Kartenhintergrund auf Tauchplatzkarten';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitle =>
      'Karte als Hintergrund auf Tauchplatzkarten anzeigen';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote =>
      'Karte als Hintergrund auf Tauchplatzkarten anzeigen (erfordert Standort des Tauchplatzes)';

  @override
  String get settings_appearance_maxDepthMarker => 'Maximaltiefe-Markierung';

  @override
  String get settings_appearance_maxDepthMarker_subtitle =>
      'Markierung am Punkt der maximalen Tiefe anzeigen';

  @override
  String get settings_appearance_maxDepthMarker_subtitleFull =>
      'Markierung am Punkt der maximalen Tiefe in Tauchprofilen anzeigen';

  @override
  String get settings_appearance_metric_ascentRateColors =>
      'Aufstiegsraten-Farben';

  @override
  String get settings_appearance_metric_ceiling => 'Ceiling';

  @override
  String get settings_appearance_metric_events => 'Ereignisse';

  @override
  String get settings_appearance_metric_gasDensity => 'Gasdichte';

  @override
  String get settings_appearance_metric_gfPercent => 'GF%';

  @override
  String get settings_appearance_metric_heartRate => 'Herzfrequenz';

  @override
  String get settings_appearance_metric_meanDepth => 'Durchschnittliche Tiefe';

  @override
  String get settings_appearance_metric_ndl => 'NDL';

  @override
  String get settings_appearance_metric_ppHe => 'ppHe';

  @override
  String get settings_appearance_metric_ppN2 => 'ppN2';

  @override
  String get settings_appearance_metric_ppO2 => 'ppO2';

  @override
  String get settings_appearance_metric_pressure => 'Druck';

  @override
  String get settings_appearance_metric_sacRate => 'SAC-Rate';

  @override
  String get settings_appearance_metric_surfaceGf => 'Oberflaechenfaktor GF';

  @override
  String get settings_appearance_metric_temperature => 'Temperatur';

  @override
  String get settings_appearance_metric_tts => 'TTS (Zeit zur Oberflaeche)';

  @override
  String get settings_appearance_pressureThresholdMarkers =>
      'Druckschwellen-Markierungen';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Markierungen anzeigen, wenn der Flaschendruck Schwellenwerte ueberschreitet';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Markierungen anzeigen, wenn der Flaschendruck die Schwellenwerte 2/3, 1/2 und 1/3 ueberschreitet';

  @override
  String get settings_appearance_rightYAxisMetric => 'Rechte Y-Achsen-Metrik';

  @override
  String get settings_appearance_rightYAxisMetric_subtitle =>
      'Standardmetrik auf der rechten Achse';

  @override
  String get settings_appearance_subsection_decompressionMetrics =>
      'Dekompressionsmetriken';

  @override
  String get settings_appearance_subsection_defaultVisibleMetrics =>
      'Standard-sichtbare Metriken';

  @override
  String get settings_appearance_subsection_gasAnalysisMetrics =>
      'Gasanalyse-Metriken';

  @override
  String get settings_appearance_subsection_gradientFactorMetrics =>
      'Gradientenfaktor-Metriken';

  @override
  String get settings_appearance_theme_dark => 'Dunkel';

  @override
  String get settings_appearance_theme_light => 'Hell';

  @override
  String get settings_appearance_theme_system => 'Systemstandard';

  @override
  String get settings_backToSettings_tooltip => 'Zurueck zu Einstellungen';

  @override
  String get settings_cloudSync_appBar_title => 'Cloud-Synchronisierung';

  @override
  String get settings_cloudSync_autoSync => 'Automatische Synchronisierung';

  @override
  String get settings_cloudSync_autoSync_subtitle =>
      'Nach Aenderungen automatisch synchronisieren';

  @override
  String settings_cloudSync_conflictItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente erfordern Aufmerksamkeit',
      one: '1 Element erfordert Aufmerksamkeit',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_disabledBanner_content =>
      'Die App-verwaltete Cloud-Synchronisierung ist deaktiviert, da Sie einen benutzerdefinierten Speicherordner verwenden. Der Synchronisierungsdienst Ihres Ordners (Dropbox, Google Drive, OneDrive usw.) uebernimmt die Synchronisierung.';

  @override
  String get settings_cloudSync_disabledBanner_title =>
      'Cloud-Synchronisierung deaktiviert';

  @override
  String get settings_cloudSync_header_advanced => 'Erweitert';

  @override
  String get settings_cloudSync_header_cloudProvider => 'Cloud-Anbieter';

  @override
  String settings_cloudSync_header_conflicts(Object count) {
    return 'Konflikte ($count)';
  }

  @override
  String get settings_cloudSync_header_syncBehavior =>
      'Synchronisierungsverhalten';

  @override
  String settings_cloudSync_lastSynced(Object time) {
    return 'Zuletzt synchronisiert: $time';
  }

  @override
  String settings_cloudSync_pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausstehende Aenderungen',
      one: '1 ausstehende Aenderung',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_provider_connected => 'Verbunden';

  @override
  String settings_cloudSync_provider_connectedTo(Object providerName) {
    return 'Verbunden mit $providerName';
  }

  @override
  String settings_cloudSync_provider_connectionFailed(
    Object providerName,
    Object error,
  ) {
    return 'Verbindung zu $providerName fehlgeschlagen: $error';
  }

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Ueber Google Drive synchronisieren';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Ueber Apple iCloud synchronisieren';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return '$providerName-Anbieter konnte nicht initialisiert werden';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Auf dieser Plattform nicht verfuegbar';

  @override
  String get settings_cloudSync_resetDialog_cancel => 'Abbrechen';

  @override
  String get settings_cloudSync_resetDialog_content =>
      'Dadurch wird der gesamte Synchronisierungsverlauf geloescht und neu begonnen. Ihre Daten werden nicht geloescht, aber moeglicherweise muessen Sie bei der naechsten Synchronisierung Konflikte loesen.';

  @override
  String get settings_cloudSync_resetDialog_reset => 'Zuruecksetzen';

  @override
  String get settings_cloudSync_resetDialog_title =>
      'Synchronisierungsstatus zuruecksetzen?';

  @override
  String get settings_cloudSync_resetSuccess =>
      'Synchronisierungsstatus zurueckgesetzt';

  @override
  String get settings_cloudSync_resetSyncState =>
      'Synchronisierungsstatus zuruecksetzen';

  @override
  String get settings_cloudSync_resetSyncState_subtitle =>
      'Synchronisierungsverlauf loeschen und neu beginnen';

  @override
  String get settings_cloudSync_resolveConflicts => 'Konflikte loesen';

  @override
  String get settings_cloudSync_selectProviderHint =>
      'Waehlen Sie einen Cloud-Anbieter, um die Synchronisierung zu aktivieren';

  @override
  String get settings_cloudSync_signOut => 'Abmelden';

  @override
  String get settings_cloudSync_signOutDialog_cancel => 'Abbrechen';

  @override
  String get settings_cloudSync_signOutDialog_content =>
      'Dadurch wird die Verbindung zum Cloud-Anbieter getrennt. Ihre lokalen Daten bleiben erhalten.';

  @override
  String get settings_cloudSync_signOutDialog_signOut => 'Abmelden';

  @override
  String get settings_cloudSync_signOutDialog_title => 'Abmelden?';

  @override
  String get settings_cloudSync_signOutSuccess =>
      'Vom Cloud-Anbieter abgemeldet';

  @override
  String get settings_cloudSync_signOut_subtitle =>
      'Verbindung zum Cloud-Anbieter trennen';

  @override
  String get settings_cloudSync_status_conflictsDetected => 'Konflikte erkannt';

  @override
  String get settings_cloudSync_status_readyToSync =>
      'Bereit zur Synchronisierung';

  @override
  String get settings_cloudSync_status_syncComplete =>
      'Synchronisierung abgeschlossen';

  @override
  String get settings_cloudSync_status_syncError => 'Synchronisierungsfehler';

  @override
  String get settings_cloudSync_status_syncing => 'Wird synchronisiert...';

  @override
  String get settings_cloudSync_storageSettings => 'Speichereinstellungen';

  @override
  String get settings_cloudSync_syncNow => 'Jetzt synchronisieren';

  @override
  String get settings_cloudSync_syncOnLaunch => 'Beim Start synchronisieren';

  @override
  String get settings_cloudSync_syncOnLaunch_subtitle =>
      'Beim Start nach Aktualisierungen suchen';

  @override
  String get settings_cloudSync_syncOnResume =>
      'Bei Fortsetzung synchronisieren';

  @override
  String get settings_cloudSync_syncOnResume_subtitle =>
      'Nach Aktualisierungen suchen, wenn die App aktiv wird';

  @override
  String settings_cloudSync_syncProgressPercent(Object percent) {
    return 'Synchronisierungsfortschritt: $percent Prozent';
  }

  @override
  String settings_cloudSync_time_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vor $count Tagen',
      one: 'Vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_time_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vor $count Stunden',
      one: 'Vor 1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_time_justNow => 'Gerade eben';

  @override
  String settings_cloudSync_time_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vor $count Minuten',
      one: 'Vor 1 Minute',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_applyAll => 'Alle anwenden';

  @override
  String get settings_conflict_cancel => 'Abbrechen';

  @override
  String get settings_conflict_chooseResolution => 'Loesung waehlen';

  @override
  String get settings_conflict_close => 'Schliessen';

  @override
  String get settings_conflict_close_tooltip => 'Konfliktdialog schliessen';

  @override
  String settings_conflict_counterLabel(Object current, Object total) {
    return 'Konflikt $current von $total';
  }

  @override
  String settings_conflict_errorLoading(Object error) {
    return 'Fehler beim Laden der Konflikte: $error';
  }

  @override
  String get settings_conflict_keepBoth => 'Beide behalten';

  @override
  String get settings_conflict_keepLocal => 'Lokal behalten';

  @override
  String get settings_conflict_keepRemote => 'Remote behalten';

  @override
  String get settings_conflict_localVersion => 'Lokale Version';

  @override
  String settings_conflict_modified(Object time) {
    return 'Geaendert: $time';
  }

  @override
  String get settings_conflict_next_tooltip => 'Naechster Konflikt';

  @override
  String get settings_conflict_noConflicts_message =>
      'Alle Synchronisierungskonflikte wurden geloest.';

  @override
  String get settings_conflict_noConflicts_title => 'Keine Konflikte';

  @override
  String get settings_conflict_noDataAvailable => 'Keine Daten verfuegbar';

  @override
  String get settings_conflict_previous_tooltip => 'Vorheriger Konflikt';

  @override
  String get settings_conflict_remoteVersion => 'Remote-Version';

  @override
  String settings_conflict_resolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konflikte',
      one: '1 Konflikt',
    );
    return '$_temp0 geloest';
  }

  @override
  String get settings_conflict_title => 'Konflikte loesen';

  @override
  String get settings_data_appDefaultLocation => 'Standard-App-Speicherort';

  @override
  String get settings_data_backup => 'Sicherung';

  @override
  String get settings_data_backup_subtitle => 'Sicherung Ihrer Daten erstellen';

  @override
  String get settings_data_cloudSync => 'Cloud-Synchronisierung';

  @override
  String get settings_data_customFolder => 'Benutzerdefinierter Ordner';

  @override
  String get settings_data_databaseStorage => 'Datenbankspeicher';

  @override
  String get settings_data_export_completed => 'Export abgeschlossen';

  @override
  String get settings_data_export_exporting => 'Wird exportiert...';

  @override
  String settings_data_export_failed(Object error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get settings_data_header_backupSync => 'Sicherung & Synchronisierung';

  @override
  String get settings_data_header_storage => 'Speicher';

  @override
  String get settings_data_import_completed => 'Vorgang abgeschlossen';

  @override
  String settings_data_import_failed(Object error) {
    return 'Vorgang fehlgeschlagen: $error';
  }

  @override
  String get settings_data_offlineMaps => 'Offline-Karten';

  @override
  String get settings_data_offlineMaps_subtitle =>
      'Karten fuer die Offline-Nutzung herunterladen';

  @override
  String get settings_data_restore => 'Wiederherstellen';

  @override
  String get settings_data_restoreDialog_cancel => 'Abbrechen';

  @override
  String get settings_data_restoreDialog_content =>
      'Warnung: Das Wiederherstellen aus einer Sicherung ersetzt ALLE aktuellen Daten durch die Sicherungsdaten. Diese Aktion kann nicht rueckgaengig gemacht werden.\n\nSind Sie sicher, dass Sie fortfahren moechten?';

  @override
  String get settings_data_restoreDialog_restore => 'Wiederherstellen';

  @override
  String get settings_data_restoreDialog_title => 'Sicherung wiederherstellen';

  @override
  String get settings_data_restore_subtitle => 'Aus Sicherung wiederherstellen';

  @override
  String settings_data_syncTime_daysAgo(Object count) {
    return 'Vor $count T';
  }

  @override
  String settings_data_syncTime_hoursAgo(Object count) {
    return 'Vor $count Std';
  }

  @override
  String get settings_data_syncTime_justNow => 'Gerade eben';

  @override
  String settings_data_syncTime_minutesAgo(Object count) {
    return 'Vor $count Min';
  }

  @override
  String settings_data_sync_lastSynced(Object time) {
    return 'Zuletzt synchronisiert: $time';
  }

  @override
  String get settings_data_sync_notConfigured => 'Nicht konfiguriert';

  @override
  String get settings_data_sync_syncing => 'Wird synchronisiert...';

  @override
  String get settings_decompression_aboutContent =>
      'Gradientenfaktoren (GF) steuern, wie konservativ Ihre Dekompressionsberechnungen sind. GF Low beeinflusst tiefe Stopps, waehrend GF High flache Stopps beeinflusst.\n\nNiedrigere Werte = konservativer = laengere Dekostopps\nHoehere Werte = weniger konservativ = kuerzere Dekostopps';

  @override
  String get settings_decompression_aboutTitle => 'Ueber Gradientenfaktoren';

  @override
  String get settings_decompression_currentSettings => 'Aktuelle Einstellungen';

  @override
  String get settings_decompression_dialog_cancel => 'Abbrechen';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      'Niedrigere Werte = konservativer (laengere NDL/mehr Deko)';

  @override
  String get settings_decompression_dialog_customValues =>
      'Benutzerdefinierte Werte';

  @override
  String get settings_decompression_dialog_gfHigh => 'GF High';

  @override
  String get settings_decompression_dialog_gfLow => 'GF Low';

  @override
  String get settings_decompression_dialog_info =>
      'GF Low/High steuern, wie konservativ Ihre NDL- und Deko-Berechnungen sind.';

  @override
  String get settings_decompression_dialog_presets => 'Voreinstellungen';

  @override
  String get settings_decompression_dialog_save => 'Speichern';

  @override
  String get settings_decompression_dialog_title => 'Gradientenfaktoren';

  @override
  String settings_decompression_gfValue(Object gfLow, Object gfHigh) {
    return 'GF $gfLow/$gfHigh';
  }

  @override
  String get settings_decompression_header_gradientFactors =>
      'Gradientenfaktoren';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Voreinstellung $presetName fuer Konservativitaet auswaehlen';
  }

  @override
  String get settings_existingDb_cancel => 'Abbrechen';

  @override
  String get settings_existingDb_continue => 'Fortfahren';

  @override
  String get settings_existingDb_current => 'Aktuell';

  @override
  String get settings_existingDb_dialog_message =>
      'In diesem Ordner existiert bereits eine Submersion-Datenbank.';

  @override
  String get settings_existingDb_dialog_title =>
      'Vorhandene Datenbank gefunden';

  @override
  String get settings_existingDb_existing => 'Vorhanden';

  @override
  String get settings_existingDb_replaceWarning =>
      'Die vorhandene Datenbank wird vor dem Ersetzen gesichert.';

  @override
  String get settings_existingDb_replaceWithMyData =>
      'Mit meinen Daten ersetzen';

  @override
  String get settings_existingDb_replaceWithMyData_subtitle =>
      'Mit Ihrer aktuellen Datenbank ueberschreiben';

  @override
  String get settings_existingDb_stat_buddies => 'Tauchpartner';

  @override
  String get settings_existingDb_stat_dives => 'Tauchgaenge';

  @override
  String get settings_existingDb_stat_sites => 'Tauchplaetze';

  @override
  String get settings_existingDb_stat_trips => 'Reisen';

  @override
  String get settings_existingDb_stat_users => 'Benutzer';

  @override
  String get settings_existingDb_unknown => 'Unbekannt';

  @override
  String get settings_existingDb_useExisting =>
      'Vorhandene Datenbank verwenden';

  @override
  String get settings_existingDb_useExisting_subtitle =>
      'Zur Datenbank in diesem Ordner wechseln';

  @override
  String get settings_gfPreset_custom_description => 'Eigene Werte festlegen';

  @override
  String get settings_gfPreset_custom_name => 'Benutzerdefiniert';

  @override
  String get settings_gfPreset_high_description =>
      'Am konservativsten, laengere Dekostopps';

  @override
  String get settings_gfPreset_high_name => 'Hoch';

  @override
  String get settings_gfPreset_low_description =>
      'Am wenigsten konservativ, kuerzere Deko';

  @override
  String get settings_gfPreset_low_name => 'Niedrig';

  @override
  String get settings_gfPreset_medium_description => 'Ausgewogener Ansatz';

  @override
  String get settings_gfPreset_medium_name => 'Mittel';

  @override
  String get settings_import_dialog_title => 'Daten werden importiert';

  @override
  String get settings_import_doNotClose => 'Bitte schliessen Sie die App nicht';

  @override
  String settings_import_itemCount(Object current, Object total) {
    return '$current von $total';
  }

  @override
  String get settings_import_phase_buddies =>
      'Tauchpartner werden importiert...';

  @override
  String get settings_import_phase_certifications =>
      'Zertifizierungen werden importiert...';

  @override
  String get settings_import_phase_complete => 'Wird abgeschlossen...';

  @override
  String get settings_import_phase_diveCenters =>
      'Tauchzentren werden importiert...';

  @override
  String get settings_import_phase_diveTypes =>
      'Taucharten werden importiert...';

  @override
  String get settings_import_phase_dives => 'Tauchgaenge werden importiert...';

  @override
  String get settings_import_phase_equipment =>
      'Ausruestung wird importiert...';

  @override
  String get settings_import_phase_equipmentSets =>
      'Ausruestungssets werden importiert...';

  @override
  String get settings_import_phase_parsing => 'Datei wird analysiert...';

  @override
  String get settings_import_phase_preparing => 'Wird vorbereitet...';

  @override
  String get settings_import_phase_sites => 'Tauchplaetze werden importiert...';

  @override
  String get settings_import_phase_tags => 'Tags werden importiert...';

  @override
  String get settings_import_phase_trips => 'Reisen werden importiert...';

  @override
  String settings_import_progressLabel(
    Object phase,
    Object current,
    Object total,
  ) {
    return '$phase, $current von $total';
  }

  @override
  String settings_import_progressPercent(Object percent) {
    return 'Importfortschritt: $percent Prozent';
  }

  @override
  String get settings_language_appBar_title => 'Sprache';

  @override
  String get settings_language_selected => 'Ausgewaehlt';

  @override
  String get settings_language_systemDefault => 'Systemstandard';

  @override
  String get settings_manage_diveTypes => 'Taucharten';

  @override
  String get settings_manage_diveTypes_subtitle =>
      'Benutzerdefinierte Taucharten verwalten';

  @override
  String get settings_manage_header_manageData => 'Daten verwalten';

  @override
  String get settings_manage_species => 'Arten';

  @override
  String get settings_manage_species_subtitle =>
      'Meeresbewohner-Artenkatalog verwalten';

  @override
  String get settings_manage_tankPresets => 'Flaschenvoreinstellungen';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Benutzerdefinierte Flaschenkonfigurationen verwalten';

  @override
  String get settings_migrationProgress_doNotClose =>
      'Bitte schliessen Sie die App nicht';

  @override
  String get settings_migration_backupInfo =>
      'Vor dem Verschieben wird eine Sicherung erstellt. Ihre Daten gehen nicht verloren.';

  @override
  String get settings_migration_cancel => 'Abbrechen';

  @override
  String get settings_migration_cloudSyncWarning =>
      'Die App-verwaltete Cloud-Synchronisierung wird deaktiviert. Der Synchronisierungsdienst Ihres Ordners uebernimmt die Synchronisierung.';

  @override
  String get settings_migration_dialog_message =>
      'Ihre Datenbank wird verschoben:';

  @override
  String get settings_migration_dialog_title => 'Datenbank verschieben?';

  @override
  String get settings_migration_from => 'Von';

  @override
  String get settings_migration_moveDatabase => 'Datenbank verschieben';

  @override
  String get settings_migration_to => 'Nach';

  @override
  String settings_notifications_days(Object count) {
    return '$count Tage';
  }

  @override
  String get settings_notifications_disabled_enableButton => 'Aktivieren';

  @override
  String get settings_notifications_disabled_subtitle =>
      'Aktivieren Sie in den Systemeinstellungen, um Erinnerungen zu erhalten';

  @override
  String get settings_notifications_disabled_title =>
      'Benachrichtigungen deaktiviert';

  @override
  String get settings_notifications_enableServiceReminders =>
      'Serviceerinnerungen aktivieren';

  @override
  String get settings_notifications_enableServiceReminders_subtitle =>
      'Benachrichtigung erhalten, wenn eine Ausruestungswartung faellig ist';

  @override
  String get settings_notifications_header_reminderSchedule =>
      'Erinnerungszeitplan';

  @override
  String get settings_notifications_header_serviceReminders =>
      'Serviceerinnerungen';

  @override
  String get settings_notifications_howItWorks_content =>
      'Benachrichtigungen werden beim Start der App geplant und regelmaessig im Hintergrund aktualisiert. Sie koennen Erinnerungen fuer einzelne Ausruestungsgegenstaende im jeweiligen Bearbeitungsbildschirm anpassen.';

  @override
  String get settings_notifications_howItWorks_title => 'So funktioniert es';

  @override
  String get settings_notifications_permissionRequired =>
      'Bitte aktivieren Sie Benachrichtigungen in den Systemeinstellungen';

  @override
  String get settings_notifications_remindBeforeDue =>
      'Erinnern Sie mich vor Faelligkeit der Wartung:';

  @override
  String get settings_notifications_reminderTime => 'Erinnerungszeit';

  @override
  String get settings_profile_activeDiver_subtitle =>
      'Aktiver Taucher - tippen, um zu wechseln';

  @override
  String get settings_profile_addNewDiver => 'Neuen Taucher hinzufuegen';

  @override
  String get settings_profile_error_loadingDiver =>
      'Fehler beim Laden des Tauchers';

  @override
  String get settings_profile_header_activeDiver => 'Aktiver Taucher';

  @override
  String get settings_profile_header_manageDivers => 'Taucher verwalten';

  @override
  String get settings_profile_noDiverProfile => 'Kein Taucherprofil';

  @override
  String get settings_profile_noDiverProfile_subtitle =>
      'Tippen, um Ihr Profil zu erstellen';

  @override
  String get settings_profile_switchDiver_title => 'Taucher wechseln';

  @override
  String settings_profile_switchedTo(Object diverName) {
    return 'Gewechselt zu $diverName';
  }

  @override
  String get settings_profile_viewAllDivers => 'Alle Taucher anzeigen';

  @override
  String get settings_profile_viewAllDivers_subtitle =>
      'Taucherprofile hinzufuegen oder bearbeiten';

  @override
  String get settings_section_about_subtitle => 'App-Info & Lizenzen';

  @override
  String get settings_section_about_title => 'Ueber';

  @override
  String get settings_section_appearance_subtitle => 'Design & Anzeige';

  @override
  String get settings_section_appearance_title => 'Darstellung';

  @override
  String get settings_section_data_subtitle =>
      'Sicherung, Wiederherstellung & Speicher';

  @override
  String get settings_section_data_title => 'Daten';

  @override
  String get settings_section_decompression_subtitle => 'Gradientenfaktoren';

  @override
  String get settings_section_decompression_title => 'Dekompression';

  @override
  String get settings_section_diverProfile_subtitle =>
      'Aktiver Taucher & Profile';

  @override
  String get settings_section_diverProfile_title => 'Taucherprofil';

  @override
  String get settings_section_manage_subtitle =>
      'Taucharten & Flaschenvoreinstellungen';

  @override
  String get settings_section_manage_title => 'Verwalten';

  @override
  String get settings_section_notifications_subtitle => 'Serviceerinnerungen';

  @override
  String get settings_section_notifications_title => 'Benachrichtigungen';

  @override
  String get settings_section_units_subtitle => 'Messeinheiten';

  @override
  String get settings_section_units_title => 'Einheiten';

  @override
  String get settings_storage_appBar_title => 'Datenbankspeicher';

  @override
  String get settings_storage_appDefault => 'App-Standard';

  @override
  String get settings_storage_appDefaultLocation => 'Standard-App-Speicherort';

  @override
  String get settings_storage_appDefault_subtitle => 'Standard-App-Speicherort';

  @override
  String get settings_storage_currentLocation => 'Aktueller Speicherort';

  @override
  String get settings_storage_currentLocation_label => 'Aktueller Speicherort';

  @override
  String get settings_storage_customFolder => 'Benutzerdefinierter Ordner';

  @override
  String get settings_storage_customFolder_change => 'Aendern';

  @override
  String get settings_storage_customFolder_subtitle =>
      'Waehlen Sie einen synchronisierten Ordner (Dropbox, Google Drive usw.)';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize • $diveCount Tauchgaenge • $siteCount Tauchplaetze';
  }

  @override
  String get settings_storage_dismissError_tooltip => 'Fehler schliessen';

  @override
  String get settings_storage_dismissSuccess_tooltip =>
      'Erfolgsmeldung schliessen';

  @override
  String get settings_storage_header_storageLocation => 'Speicherort';

  @override
  String get settings_storage_info_customActive =>
      'Die App-verwaltete Cloud-Synchronisierung ist deaktiviert. Der Synchronisierungsdienst Ihres Ordners (Dropbox, Google Drive usw.) uebernimmt die Synchronisierung.';

  @override
  String get settings_storage_info_customAvailable =>
      'Die Verwendung eines benutzerdefinierten Ordners deaktiviert die App-verwaltete Cloud-Synchronisierung. Der Synchronisierungsdienst Ihres Ordners uebernimmt stattdessen die Synchronisierung.';

  @override
  String get settings_storage_loading => 'Laden...';

  @override
  String get settings_storage_migrating_doNotClose =>
      'Bitte schliessen Sie die App nicht';

  @override
  String get settings_storage_migrating_movingDatabase =>
      'Datenbank wird verschoben...';

  @override
  String get settings_storage_migrating_movingToAppDefault =>
      'Wird zum App-Standard verschoben...';

  @override
  String get settings_storage_migrating_replacingExisting =>
      'Vorhandene Datenbank wird ersetzt...';

  @override
  String get settings_storage_migrating_switchingToExisting =>
      'Wird zur vorhandenen Datenbank gewechselt...';

  @override
  String get settings_storage_notSet => 'Nicht festgelegt';

  @override
  String settings_storage_success_backupAt(Object path) {
    return 'Original als Sicherung gespeichert unter:\n$path';
  }

  @override
  String get settings_storage_success_moved =>
      'Datenbank erfolgreich verschoben';

  @override
  String get settings_summary_activeDiver => 'Aktiver Taucher';

  @override
  String get settings_summary_currentConfiguration => 'Aktuelle Konfiguration';

  @override
  String get settings_summary_depth => 'Tiefe';

  @override
  String get settings_summary_error => 'Fehler';

  @override
  String get settings_summary_gradientFactors => 'Gradientenfaktoren';

  @override
  String get settings_summary_loading => 'Laden...';

  @override
  String get settings_summary_notSet => 'Nicht festgelegt';

  @override
  String get settings_summary_pressure => 'Druck';

  @override
  String get settings_summary_subtitle =>
      'Waehlen Sie eine Kategorie zum Konfigurieren';

  @override
  String get settings_summary_temperature => 'Temperatur';

  @override
  String get settings_summary_theme => 'Design';

  @override
  String get settings_summary_theme_dark => 'Dunkel';

  @override
  String get settings_summary_theme_light => 'Hell';

  @override
  String get settings_summary_theme_system => 'System';

  @override
  String get settings_summary_tip =>
      'Tipp: Verwenden Sie den Bereich Daten, um Ihre Tauchprotokolle regelmaessig zu sichern.';

  @override
  String get settings_summary_title => 'Einstellungen';

  @override
  String get settings_summary_unitPreferences => 'Einheiteneinstellungen';

  @override
  String get settings_summary_units => 'Einheiten';

  @override
  String get settings_summary_volume => 'Volumen';

  @override
  String get settings_summary_weight => 'Gewicht';

  @override
  String get settings_units_custom => 'Benutzerdefiniert';

  @override
  String get settings_units_dateFormat => 'Datumsformat';

  @override
  String get settings_units_depth => 'Tiefe';

  @override
  String get settings_units_depth_feet => 'Fuss (ft)';

  @override
  String get settings_units_depth_meters => 'Meter (m)';

  @override
  String get settings_units_dialog_dateFormat => 'Datumsformat';

  @override
  String get settings_units_dialog_depthUnit => 'Tiefeneinheit';

  @override
  String get settings_units_dialog_pressureUnit => 'Druckeinheit';

  @override
  String get settings_units_dialog_sacRateUnit => 'SAC-Raten-Einheit';

  @override
  String get settings_units_dialog_temperatureUnit => 'Temperatureinheit';

  @override
  String get settings_units_dialog_timeFormat => 'Zeitformat';

  @override
  String get settings_units_dialog_volumeUnit => 'Volumeneinheit';

  @override
  String get settings_units_dialog_weightUnit => 'Gewichtseinheit';

  @override
  String get settings_units_header_individualUnits => 'Einzelne Einheiten';

  @override
  String get settings_units_header_timeDateFormat => 'Zeit- & Datumsformat';

  @override
  String get settings_units_header_unitSystem => 'Einheitensystem';

  @override
  String get settings_units_imperial => 'Imperial';

  @override
  String get settings_units_metric => 'Metrisch';

  @override
  String get settings_units_pressure => 'Druck';

  @override
  String get settings_units_pressure_bar => 'Bar';

  @override
  String get settings_units_pressure_psi => 'PSI';

  @override
  String get settings_units_quickSelect => 'Schnellauswahl';

  @override
  String get settings_units_sacRate => 'SAC-Rate';

  @override
  String get settings_units_sac_pressurePerMinute => 'Druck pro Minute';

  @override
  String get settings_units_sac_pressurePerMinute_subtitle =>
      'Kein Flaschenvolumen erforderlich (bar/min oder psi/min)';

  @override
  String get settings_units_sac_volumePerMinute => 'Volumen pro Minute';

  @override
  String get settings_units_sac_volumePerMinute_subtitle =>
      'Erfordert Flaschenvolumen (L/min oder cuft/min)';

  @override
  String get settings_units_temperature => 'Temperatur';

  @override
  String get settings_units_temperature_celsius => 'Celsius (°C)';

  @override
  String get settings_units_temperature_fahrenheit => 'Fahrenheit (°F)';

  @override
  String get settings_units_timeFormat => 'Zeitformat';

  @override
  String get settings_units_volume => 'Volumen';

  @override
  String get settings_units_volume_cubicFeet => 'Kubikfuss (cuft)';

  @override
  String get settings_units_volume_liters => 'Liter (L)';

  @override
  String get settings_units_weight => 'Gewicht';

  @override
  String get settings_units_weight_kilograms => 'Kilogramm (kg)';

  @override
  String get settings_units_weight_pounds => 'Pfund (lbs)';

  @override
  String get signatures_action_clear => 'Löschen';

  @override
  String get signatures_action_closeSignatureView =>
      'Signaturansicht schließen';

  @override
  String get signatures_action_deleteSignature => 'Signatur löschen';

  @override
  String get signatures_action_done => 'Fertig';

  @override
  String get signatures_action_readyToSign => 'Bereit zum Signieren';

  @override
  String get signatures_action_request => 'Anfordern';

  @override
  String get signatures_action_saveSignature => 'Signatur speichern';

  @override
  String signatures_buddyCard_notSignedSemantics(Object name) {
    return '$name Signatur, nicht signiert';
  }

  @override
  String signatures_buddyCard_signedSemantics(Object name) {
    return '$name Signatur, signiert';
  }

  @override
  String get signatures_captureInstructorSignature =>
      'Tauchlehrer-Signatur erfassen';

  @override
  String signatures_deleteDialog_message(Object name) {
    return 'Möchten Sie die Signatur von $name wirklich löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get signatures_deleteDialog_title => 'Signatur löschen?';

  @override
  String get signatures_drawSignatureHint => 'Zeichnen Sie Ihre Signatur oben';

  @override
  String get signatures_drawSignatureHintDetailed =>
      'Zeichnen Sie Signatur oben mit Finger oder Stylus';

  @override
  String get signatures_drawSignatureSemantics => 'Signatur zeichnen';

  @override
  String get signatures_error_drawSignature =>
      'Bitte zeichnen Sie eine Signatur';

  @override
  String get signatures_error_enterSignerName =>
      'Bitte geben Sie den Namen des Unterzeichners ein';

  @override
  String get signatures_field_instructorName => 'Tauchlehrername';

  @override
  String get signatures_field_instructorNameHint => 'Tauchlehrernamen eingeben';

  @override
  String get signatures_handoff_title => 'Geben Sie Ihr Gerät an';

  @override
  String get signatures_instructorSignature => 'Tauchlehrer-Signatur';

  @override
  String get signatures_noSignatureImage => 'Kein Signaturbild';

  @override
  String signatures_signHere(Object name) {
    return '$name - Hier signieren';
  }

  @override
  String get signatures_signed => 'Signiert';

  @override
  String signatures_signedCountSemantics(Object signed, Object total) {
    return '$signed von $total Tauchpartnern haben signiert';
  }

  @override
  String signatures_signedDate(Object date) {
    return 'Signiert am $date';
  }

  @override
  String get signatures_title => 'Signaturen';

  @override
  String get signatures_viewSignature => 'Signatur anzeigen';

  @override
  String signatures_viewSignatureSemantics(Object name) {
    return 'Signatur von $name anzeigen';
  }

  @override
  String get statistics_appBar_title => 'Statistiken';

  @override
  String statistics_categoryCard_semanticLabel(Object title) {
    return 'Statistikkategorie $title';
  }

  @override
  String get statistics_category_conditions_subtitle => 'Sicht & Temperatur';

  @override
  String get statistics_category_conditions_title => 'Bedingungen';

  @override
  String get statistics_category_equipment_subtitle =>
      'Ausruestungsnutzung & Gewicht';

  @override
  String get statistics_category_equipment_title => 'Ausruestung';

  @override
  String get statistics_category_gas_subtitle => 'SAC-Raten & Gasgemische';

  @override
  String get statistics_category_gas_title => 'Luftverbrauch';

  @override
  String get statistics_category_geographic_subtitle => 'Laender & Regionen';

  @override
  String get statistics_category_geographic_title => 'Geografie';

  @override
  String get statistics_category_marineLife_subtitle => 'Artensichtungen';

  @override
  String get statistics_category_marineLife_title => 'Meeresbewohner';

  @override
  String get statistics_category_profile_subtitle => 'Aufstiegsraten & Deko';

  @override
  String get statistics_category_profile_title => 'Profilanalyse';

  @override
  String get statistics_category_progression_subtitle => 'Tiefen- & Zeittrends';

  @override
  String get statistics_category_progression_title => 'Entwicklung';

  @override
  String get statistics_category_social_subtitle => 'Buddies & Tauchbasen';

  @override
  String get statistics_category_social_title => 'Soziales';

  @override
  String get statistics_category_timePatterns_subtitle => 'Wann Sie tauchen';

  @override
  String get statistics_category_timePatterns_title => 'Zeitmuster';

  @override
  String statistics_chart_barSemanticLabel(Object count) {
    return 'Balkendiagramm mit $count Kategorien';
  }

  @override
  String statistics_chart_distributionSemanticLabel(Object count) {
    return 'Kreisdiagramm mit $count Segmenten';
  }

  @override
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames) {
    return 'Mehrzeiliges Trenddiagramm zum Vergleich von $seriesNames';
  }

  @override
  String get statistics_chart_noBarData => 'Keine Daten verfuegbar';

  @override
  String get statistics_chart_noDistributionData =>
      'Keine Verteilungsdaten verfuegbar';

  @override
  String get statistics_chart_noTrendData => 'Keine Trenddaten verfuegbar';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return 'Trendliniendiagramm mit $count Datenpunkten';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return 'Trendliniendiagramm mit $count Datenpunkten fuer $yAxisLabel';
  }

  @override
  String get statistics_conditions_appBar_title => 'Bedingungen';

  @override
  String get statistics_conditions_entryMethod_empty =>
      'Keine Einstiegsmethoden-Daten verfuegbar';

  @override
  String get statistics_conditions_entryMethod_error =>
      'Einstiegsmethoden-Daten konnten nicht geladen werden';

  @override
  String get statistics_conditions_entryMethod_subtitle => 'Ufer, Boot usw.';

  @override
  String get statistics_conditions_entryMethod_title => 'Einstiegsmethode';

  @override
  String get statistics_conditions_temperature_empty =>
      'Keine Temperaturdaten verfuegbar';

  @override
  String get statistics_conditions_temperature_error =>
      'Temperaturdaten konnten nicht geladen werden';

  @override
  String get statistics_conditions_temperature_seriesAvg => 'Durchschn.';

  @override
  String get statistics_conditions_temperature_seriesMax => 'Max';

  @override
  String get statistics_conditions_temperature_seriesMin => 'Min';

  @override
  String get statistics_conditions_temperature_subtitle =>
      'Min/Durchschn./Max Temperaturen';

  @override
  String get statistics_conditions_temperature_title =>
      'Wassertemperatur nach Monat';

  @override
  String get statistics_conditions_visibility_error =>
      'Sichtdaten konnten nicht geladen werden';

  @override
  String get statistics_conditions_visibility_subtitle =>
      'Tauchgaenge nach Sichtbedingungen';

  @override
  String get statistics_conditions_visibility_title => 'Sichtverteilung';

  @override
  String get statistics_conditions_waterType_error =>
      'Wassertyp-Daten konnten nicht geladen werden';

  @override
  String get statistics_conditions_waterType_subtitle =>
      'Salz- vs. Suesswasser-Tauchgaenge';

  @override
  String get statistics_conditions_waterType_title => 'Wassertyp';

  @override
  String get statistics_equipment_appBar_title => 'Ausruestung';

  @override
  String get statistics_equipment_mostUsedGear_error =>
      'Ausruestungsdaten konnten nicht geladen werden';

  @override
  String get statistics_equipment_mostUsedGear_subtitle =>
      'Ausruestung nach Tauchganganzahl';

  @override
  String get statistics_equipment_mostUsedGear_title =>
      'Meistgenutzte Ausruestung';

  @override
  String get statistics_equipment_weightTrend_error =>
      'Gewichtstrend konnte nicht geladen werden';

  @override
  String get statistics_equipment_weightTrend_subtitle =>
      'Durchschnittliches Gewicht im Zeitverlauf';

  @override
  String get statistics_equipment_weightTrend_title => 'Gewichtstrend';

  @override
  String get statistics_error_loadingStatistics =>
      'Fehler beim Laden der Statistiken';

  @override
  String get statistics_gas_appBar_title => 'Luftverbrauch';

  @override
  String get statistics_gas_gasMix_error =>
      'Gasgemisch-Daten konnten nicht geladen werden';

  @override
  String get statistics_gas_gasMix_subtitle => 'Tauchgaenge nach Gastyp';

  @override
  String get statistics_gas_gasMix_title => 'Gasgemisch-Verteilung';

  @override
  String get statistics_gas_sacByRole_empty =>
      'Keine Multi-Flaschen-Daten verfuegbar';

  @override
  String get statistics_gas_sacByRole_error =>
      'SAC nach Rolle konnte nicht geladen werden';

  @override
  String get statistics_gas_sacByRole_subtitle =>
      'Durchschnittlicher Verbrauch nach Flaschentyp';

  @override
  String get statistics_gas_sacByRole_title => 'SAC nach Flaschenrolle';

  @override
  String get statistics_gas_sacRecords_best => 'Beste SAC-Rate';

  @override
  String get statistics_gas_sacRecords_empty =>
      'Noch keine SAC-Daten verfuegbar';

  @override
  String get statistics_gas_sacRecords_error =>
      'SAC-Rekorde konnten nicht geladen werden';

  @override
  String get statistics_gas_sacRecords_highest => 'Hoechste SAC-Rate';

  @override
  String get statistics_gas_sacRecords_subtitle =>
      'Bester und schlechtester Luftverbrauch';

  @override
  String get statistics_gas_sacRecords_title => 'SAC-Raten-Rekorde';

  @override
  String get statistics_gas_sacTrend_error =>
      'SAC-Trend konnte nicht geladen werden';

  @override
  String get statistics_gas_sacTrend_subtitle =>
      'Monatlicher Durchschnitt ueber 5 Jahre';

  @override
  String get statistics_gas_sacTrend_title => 'SAC-Raten-Trend';

  @override
  String get statistics_gas_tankRole_backGas => 'Rueckengas';

  @override
  String get statistics_gas_tankRole_bailout => 'Bailout';

  @override
  String get statistics_gas_tankRole_deco => 'Deko';

  @override
  String get statistics_gas_tankRole_diluent => 'Diluent';

  @override
  String get statistics_gas_tankRole_oxygenSupply => 'O₂-Versorgung';

  @override
  String get statistics_gas_tankRole_pony => 'Pony';

  @override
  String get statistics_gas_tankRole_sidemountLeft => 'Sidemount L';

  @override
  String get statistics_gas_tankRole_sidemountRight => 'Sidemount R';

  @override
  String get statistics_gas_tankRole_stage => 'Stage';

  @override
  String get statistics_geographic_appBar_title => 'Geografie';

  @override
  String get statistics_geographic_countries_empty => 'Keine besuchten Laender';

  @override
  String get statistics_geographic_countries_error =>
      'Laenderdaten konnten nicht geladen werden';

  @override
  String get statistics_geographic_countries_subtitle =>
      'Tauchgaenge nach Land';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count Laender. Spitzenreiter: $topName mit $topCount Tauchgaengen';
  }

  @override
  String get statistics_geographic_countries_title => 'Besuchte Laender';

  @override
  String get statistics_geographic_regions_empty => 'Keine erkundeten Regionen';

  @override
  String get statistics_geographic_regions_error =>
      'Regionsdaten konnten nicht geladen werden';

  @override
  String get statistics_geographic_regions_subtitle =>
      'Tauchgaenge nach Region';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count Regionen. Spitzenreiter: $topName mit $topCount Tauchgaengen';
  }

  @override
  String get statistics_geographic_regions_title => 'Erkundete Regionen';

  @override
  String get statistics_geographic_trips_empty => 'Keine Reisedaten';

  @override
  String get statistics_geographic_trips_error =>
      'Reisedaten konnten nicht geladen werden';

  @override
  String get statistics_geographic_trips_subtitle => 'Produktivste Reisen';

  @override
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count Reisen. Spitzenreiter: $topName mit $topCount Tauchgaengen';
  }

  @override
  String get statistics_geographic_trips_title => 'Tauchgaenge pro Reise';

  @override
  String get statistics_listContent_selectedSuffix => ', ausgewaehlt';

  @override
  String get statistics_marineLife_appBar_title => 'Meeresbewohner';

  @override
  String get statistics_marineLife_bestSites_empty => 'Keine Platzdaten';

  @override
  String get statistics_marineLife_bestSites_error =>
      'Platzdaten konnten nicht geladen werden';

  @override
  String get statistics_marineLife_bestSites_subtitle =>
      'Plaetze mit der groessten Artenvielfalt';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count Plaetze. Bester: $topName mit $topCount Arten';
  }

  @override
  String get statistics_marineLife_bestSites_title =>
      'Beste Plaetze fuer Meeresbewohner';

  @override
  String get statistics_marineLife_mostCommon_empty => 'Keine Sichtungsdaten';

  @override
  String get statistics_marineLife_mostCommon_error =>
      'Sichtungsdaten konnten nicht geladen werden';

  @override
  String get statistics_marineLife_mostCommon_subtitle =>
      'Am haeufigsten gesichtete Arten';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count Arten. Am haeufigsten: $topName mit $topCount Sichtungen';
  }

  @override
  String get statistics_marineLife_mostCommon_title => 'Haeufigste Sichtungen';

  @override
  String get statistics_marineLife_speciesSpotted => 'Gesichtete Arten';

  @override
  String get statistics_profile_appBar_title => 'Profilanalyse';

  @override
  String get statistics_profile_ascentDescent_empty =>
      'Keine Profildaten verfuegbar';

  @override
  String get statistics_profile_ascentDescent_error =>
      'Ratendaten konnten nicht geladen werden';

  @override
  String get statistics_profile_ascentDescent_subtitle =>
      'Aus Tauchprofildaten';

  @override
  String get statistics_profile_ascentDescent_title =>
      'Durchschnittliche Aufstiegs- & Abstiegsraten';

  @override
  String get statistics_profile_avgAscent => 'Durchschn. Aufstieg';

  @override
  String get statistics_profile_avgDescent => 'Durchschn. Abstieg';

  @override
  String get statistics_profile_deco_decoDives => 'Deko-Tauchgaenge';

  @override
  String get statistics_profile_deco_decoLabel => 'Deko';

  @override
  String get statistics_profile_deco_decoRate => 'Deko-Rate';

  @override
  String get statistics_profile_deco_empty => 'Keine Deko-Daten verfuegbar';

  @override
  String get statistics_profile_deco_error =>
      'Deko-Daten konnten nicht geladen werden';

  @override
  String get statistics_profile_deco_noDeco => 'Kein Deko';

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return 'Dekompressionsrate: $percentage% der Tauchgaenge erforderten Deko-Stopps';
  }

  @override
  String get statistics_profile_deco_subtitle => 'Tauchgaenge mit Deko-Stopps';

  @override
  String get statistics_profile_deco_title => 'Dekompressionspflicht';

  @override
  String get statistics_profile_timeAtDepth_empty =>
      'Keine Tiefendaten verfuegbar';

  @override
  String get statistics_profile_timeAtDepth_error =>
      'Tiefenbereichsdaten konnten nicht geladen werden';

  @override
  String get statistics_profile_timeAtDepth_subtitle =>
      'Ungefaehre Zeit auf jeder Tiefe';

  @override
  String get statistics_profile_timeAtDepth_title => 'Zeit in Tiefenbereichen';

  @override
  String statistics_profile_timeAtDepth_valueFormat(Object value) {
    return '$value min';
  }

  @override
  String get statistics_progression_appBar_title => 'Tauchentwicklung';

  @override
  String get statistics_progression_bottomTime_error =>
      'Grundzeit-Trend konnte nicht geladen werden';

  @override
  String get statistics_progression_bottomTime_subtitle =>
      'Durchschnittliche Dauer nach Monat';

  @override
  String get statistics_progression_bottomTime_title => 'Grundzeit-Trend';

  @override
  String get statistics_progression_cumulative_error =>
      'Kumulative Daten konnten nicht geladen werden';

  @override
  String get statistics_progression_cumulative_subtitle =>
      'Gesamtzahl der Tauchgaenge im Zeitverlauf';

  @override
  String get statistics_progression_cumulative_title =>
      'Kumulative Tauchganganzahl';

  @override
  String get statistics_progression_depthProgression_error =>
      'Tiefenentwicklung konnte nicht geladen werden';

  @override
  String get statistics_progression_depthProgression_subtitle =>
      'Monatliche Maximaltiefe ueber 5 Jahre';

  @override
  String get statistics_progression_depthProgression_title =>
      'Maximale Tiefenentwicklung';

  @override
  String get statistics_progression_divesPerYear_empty =>
      'Keine Jahresdaten verfuegbar';

  @override
  String get statistics_progression_divesPerYear_error =>
      'Jahresdaten konnten nicht geladen werden';

  @override
  String get statistics_progression_divesPerYear_subtitle =>
      'Jaehrlicher Tauchgangvergleich';

  @override
  String get statistics_progression_divesPerYear_title =>
      'Tauchgaenge pro Jahr';

  @override
  String get statistics_ranking_countLabel_dives => 'Tauchgaenge';

  @override
  String get statistics_ranking_countLabel_sightings => 'Sichtungen';

  @override
  String get statistics_ranking_countLabel_species => 'Arten';

  @override
  String get statistics_ranking_emptyState => 'Noch keine Daten';

  @override
  String statistics_ranking_itemCount(Object count, Object label) {
    return '$count $label';
  }

  @override
  String statistics_ranking_moreItems(Object count) {
    return 'und $count weitere';
  }

  @override
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  ) {
    return '$name, Rang $rank, $count $label';
  }

  @override
  String get statistics_records_appBar_title => 'Tauchrekorde';

  @override
  String get statistics_records_coldestDive => 'Kaeltester Tauchgang';

  @override
  String get statistics_records_deepestDive => 'Tiefster Tauchgang';

  @override
  String statistics_records_diveNumber(Object number) {
    return 'Tauchgang #$number';
  }

  @override
  String get statistics_records_emptySubtitle =>
      'Beginnen Sie mit dem Eintragen von Tauchgaengen, um Ihre Rekorde hier zu sehen';

  @override
  String get statistics_records_emptyTitle => 'Noch keine Rekorde';

  @override
  String get statistics_records_error => 'Fehler beim Laden der Rekorde';

  @override
  String get statistics_records_firstDive => 'Erster Tauchgang';

  @override
  String get statistics_records_longestDive => 'Laengster Tauchgang';

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
  String get statistics_records_milestones => 'Meilensteine';

  @override
  String get statistics_records_mostRecentDive => 'Letzter Tauchgang';

  @override
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  ) {
    return '$title: $value bei $siteName';
  }

  @override
  String get statistics_records_retry => 'Erneut versuchen';

  @override
  String get statistics_records_shallowestDive => 'Flachster Tauchgang';

  @override
  String get statistics_records_unknownSite => 'Unbekannter Tauchplatz';

  @override
  String get statistics_records_warmestDive => 'Waermster Tauchgang';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return 'Abschnitt $title';
  }

  @override
  String get statistics_social_appBar_title => 'Soziales & Buddies';

  @override
  String get statistics_social_soloVsBuddy_empty =>
      'Keine Tauchgangdaten verfuegbar';

  @override
  String get statistics_social_soloVsBuddy_error =>
      'Buddy-Daten konnten nicht geladen werden';

  @override
  String get statistics_social_soloVsBuddy_solo => 'Solo';

  @override
  String get statistics_social_soloVsBuddy_subtitle =>
      'Mit oder ohne Begleitung tauchen';

  @override
  String get statistics_social_soloVsBuddy_title =>
      'Solo- vs. Buddy-Tauchgaenge';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => 'Mit Buddy';

  @override
  String get statistics_social_topBuddies_error =>
      'Buddy-Rangliste konnte nicht geladen werden';

  @override
  String get statistics_social_topBuddies_subtitle => 'Haeufigste Tauchpartner';

  @override
  String get statistics_social_topBuddies_title => 'Top-Tauchbuddies';

  @override
  String get statistics_social_topDiveCenters_error =>
      'Tauchbasen-Rangliste konnte nicht geladen werden';

  @override
  String get statistics_social_topDiveCenters_subtitle =>
      'Meistbesuchte Anbieter';

  @override
  String get statistics_social_topDiveCenters_title => 'Top-Tauchbasen';

  @override
  String get statistics_summary_avgDepth => 'Durchschn. Tiefe';

  @override
  String get statistics_summary_avgTemp => 'Durchschn. Temp.';

  @override
  String get statistics_summary_depthDistribution_empty =>
      'Das Diagramm erscheint, wenn Sie Tauchgaenge eintragen';

  @override
  String get statistics_summary_depthDistribution_semanticLabel =>
      'Kreisdiagramm der Tiefenverteilung';

  @override
  String get statistics_summary_depthDistribution_title => 'Tiefenverteilung';

  @override
  String get statistics_summary_diveTypes_empty =>
      'Das Diagramm erscheint, wenn Sie Tauchgaenge eintragen';

  @override
  String statistics_summary_diveTypes_moreTypes(Object count) {
    return 'und $count weitere Typen';
  }

  @override
  String get statistics_summary_diveTypes_semanticLabel =>
      'Kreisdiagramm der Tauchgangarten-Verteilung';

  @override
  String get statistics_summary_diveTypes_title => 'Tauchgangarten';

  @override
  String get statistics_summary_divesByMonth_empty =>
      'Das Diagramm erscheint, wenn Sie Tauchgaenge eintragen';

  @override
  String get statistics_summary_divesByMonth_semanticLabel =>
      'Balkendiagramm der Tauchgaenge nach Monat';

  @override
  String get statistics_summary_divesByMonth_title => 'Tauchgaenge nach Monat';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel\n$count Tauchgaenge';
  }

  @override
  String get statistics_summary_header_subtitle =>
      'Waehlen Sie eine Kategorie, um detaillierte Statistiken zu erkunden';

  @override
  String get statistics_summary_header_title => 'Statistik-Uebersicht';

  @override
  String get statistics_summary_maxDepth => 'Max. Tiefe';

  @override
  String get statistics_summary_sitesVisited => 'Besuchte Plaetze';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgaenge',
      one: '1 Tauchgang',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty => 'Noch keine Tags erstellt';

  @override
  String get statistics_summary_tagUsage_emptyHint =>
      'Fuegen Sie Tauchgaengen Tags hinzu, um Statistiken zu sehen';

  @override
  String statistics_summary_tagUsage_moreTags(Object count) {
    return 'und $count weitere Tags';
  }

  @override
  String statistics_summary_tagUsage_tagCount(Object count) {
    return '$count Tags';
  }

  @override
  String get statistics_summary_tagUsage_title => 'Tag-Nutzung';

  @override
  String statistics_summary_topDiveSites_diveCount(Object count) {
    return '$count Tauchgaenge';
  }

  @override
  String get statistics_summary_topDiveSites_empty => 'Noch keine Tauchplaetze';

  @override
  String get statistics_summary_topDiveSites_title => 'Top-Tauchplaetze';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count insgesamt';
  }

  @override
  String get statistics_summary_totalDives => 'Tauchgaenge gesamt';

  @override
  String get statistics_summary_totalTime => 'Gesamtzeit';

  @override
  String get statistics_timePatterns_appBar_title => 'Zeitmuster';

  @override
  String get statistics_timePatterns_dayOfWeek_empty =>
      'Keine Daten verfuegbar';

  @override
  String get statistics_timePatterns_dayOfWeek_error =>
      'Wochentagsdaten konnten nicht geladen werden';

  @override
  String get statistics_timePatterns_dayOfWeek_fri => 'Fr';

  @override
  String get statistics_timePatterns_dayOfWeek_mon => 'Mo';

  @override
  String get statistics_timePatterns_dayOfWeek_sat => 'Sa';

  @override
  String get statistics_timePatterns_dayOfWeek_subtitle =>
      'Wann tauchen Sie am meisten?';

  @override
  String get statistics_timePatterns_dayOfWeek_sun => 'So';

  @override
  String get statistics_timePatterns_dayOfWeek_thu => 'Do';

  @override
  String get statistics_timePatterns_dayOfWeek_title =>
      'Tauchgaenge nach Wochentag';

  @override
  String get statistics_timePatterns_dayOfWeek_tue => 'Di';

  @override
  String get statistics_timePatterns_dayOfWeek_wed => 'Mi';

  @override
  String get statistics_timePatterns_month_apr => 'Apr';

  @override
  String get statistics_timePatterns_month_aug => 'Aug';

  @override
  String get statistics_timePatterns_month_dec => 'Dez';

  @override
  String get statistics_timePatterns_month_feb => 'Feb';

  @override
  String get statistics_timePatterns_month_jan => 'Jan';

  @override
  String get statistics_timePatterns_month_jul => 'Jul';

  @override
  String get statistics_timePatterns_month_jun => 'Jun';

  @override
  String get statistics_timePatterns_month_mar => 'Mär';

  @override
  String get statistics_timePatterns_month_may => 'Mai';

  @override
  String get statistics_timePatterns_month_nov => 'Nov';

  @override
  String get statistics_timePatterns_month_oct => 'Okt';

  @override
  String get statistics_timePatterns_month_sep => 'Sep';

  @override
  String get statistics_timePatterns_seasonal_empty => 'Keine Daten verfuegbar';

  @override
  String get statistics_timePatterns_seasonal_error =>
      'Saisonale Daten konnten nicht geladen werden';

  @override
  String get statistics_timePatterns_seasonal_subtitle =>
      'Tauchgaenge nach Monat (alle Jahre)';

  @override
  String get statistics_timePatterns_seasonal_title => 'Saisonale Muster';

  @override
  String get statistics_timePatterns_surfaceInterval_average => 'Durchschnitt';

  @override
  String get statistics_timePatterns_surfaceInterval_empty =>
      'Keine Oberflaechenintervall-Daten verfuegbar';

  @override
  String get statistics_timePatterns_surfaceInterval_error =>
      'Oberflaechenintervall-Daten konnten nicht geladen werden';

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
      'Zeit zwischen Tauchgaengen';

  @override
  String get statistics_timePatterns_surfaceInterval_title =>
      'Oberflaechenintervall-Statistiken';

  @override
  String get statistics_timePatterns_timeOfDay_error =>
      'Tageszeitdaten konnten nicht geladen werden';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle =>
      'Morgens, nachmittags, abends oder nachts';

  @override
  String get statistics_timePatterns_timeOfDay_title =>
      'Tauchgaenge nach Tageszeit';

  @override
  String get statistics_tooltip_diveRecords => 'Tauchrekorde';

  @override
  String get statistics_tooltip_refreshRecords => 'Rekorde aktualisieren';

  @override
  String get statistics_tooltip_refreshStatistics =>
      'Statistiken aktualisieren';

  @override
  String statistics_valueCard_semanticLabel(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String get surfaceInterval_aboutTissueLoading_body =>
      'Ihr Körper hat 16 Gewebekompartimente, die Stickstoff mit unterschiedlichen Geschwindigkeiten aufnehmen und abgeben. Schnelle Gewebe (wie Blut) sättigen schnell, geben aber auch schnell ab. Langsame Gewebe (wie Knochen und Fett) brauchen länger zum Aufsättigen und Entsättigen. Das \"führende Kompartiment\" ist das am stärksten gesättigte Gewebe und steuert normalerweise Ihre Nullzeit. Während eines Oberflächenintervalls entsättigen alle Gewebe in Richtung Oberflächensättigungsniveaus (~40% Sättigung).';

  @override
  String get surfaceInterval_aboutTissueLoading_title => 'Über Gewebesättigung';

  @override
  String get surfaceInterval_action_resetDefaults =>
      'Auf Standardwerte zurücksetzen';

  @override
  String get surfaceInterval_disclaimer =>
      'Dieses Tool dient nur zu Planungszwecken. Verwenden Sie immer einen Tauchcomputer und folgen Sie Ihrer Ausbildung. Die Ergebnisse basieren auf dem Buhlmann ZH-L16C-Algorithmus und können von Ihrem Computer abweichen.';

  @override
  String get surfaceInterval_field_depth => 'Tiefe';

  @override
  String get surfaceInterval_field_gasMix => 'Gasgemisch: ';

  @override
  String get surfaceInterval_field_he => 'He';

  @override
  String get surfaceInterval_field_o2 => 'O₂';

  @override
  String get surfaceInterval_field_time => 'Zeit';

  @override
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit) {
    return 'Erster Tauchgang Tiefe: $depth $unit';
  }

  @override
  String surfaceInterval_firstDive_timeSemantics(Object time) {
    return 'Erster Tauchgang Zeit: $time Minuten';
  }

  @override
  String get surfaceInterval_firstDive_title => 'Erster Tauchgang';

  @override
  String surfaceInterval_format_hours(Object count) {
    return '$count Stunden';
  }

  @override
  String surfaceInterval_format_minutes(Object count) {
    return '$count Min';
  }

  @override
  String get surfaceInterval_gasMix_air => 'Luft';

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
  String get surfaceInterval_result_currentInterval => 'Aktuelles Intervall';

  @override
  String get surfaceInterval_result_inDeco => 'In Deko';

  @override
  String get surfaceInterval_result_increaseInterval =>
      'Oberflächenintervall erhöhen oder Tiefe/Zeit des zweiten Tauchgangs reduzieren';

  @override
  String get surfaceInterval_result_minimumInterval =>
      'Minimales Oberflächenintervall';

  @override
  String get surfaceInterval_result_ndlForSecondDive =>
      'Nullzeit für 2. Tauchgang';

  @override
  String surfaceInterval_result_ndlMinutes(Object minutes) {
    return '$minutes Min Nullzeit';
  }

  @override
  String get surfaceInterval_result_notYetSafe =>
      'Noch nicht sicher, Oberflächenintervall erhöhen';

  @override
  String get surfaceInterval_result_safeToDive => 'Sicher zu tauchen';

  @override
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  ) {
    return 'Minimales Oberflächenintervall: $interval. Aktuelles Intervall: $current. Nullzeit für zweiten Tauchgang: $ndl. $status';
  }

  @override
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit) {
    return 'Zweiter Tauchgang Tiefe: $depth $unit';
  }

  @override
  String get surfaceInterval_secondDive_gasAir => '(Luft)';

  @override
  String surfaceInterval_secondDive_timeSemantics(Object time) {
    return 'Zweiter Tauchgang Zeit: $time Minuten';
  }

  @override
  String get surfaceInterval_secondDive_title => 'Zweiter Tauchgang';

  @override
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval) {
    return 'Geweberegenerations-Diagramm zeigt Entsättigung von 16 Kompartimenten über ein $interval Oberflächenintervall';
  }

  @override
  String get surfaceInterval_tissueRecovery_compartmentsLabel =>
      'Kompartimente (nach Halbwertszeit-Geschwindigkeit)';

  @override
  String get surfaceInterval_tissueRecovery_description =>
      'Zeigt, wie jedes der 16 Gewebekompartimente während des Oberflächenintervalls entsättigt';

  @override
  String get surfaceInterval_tissueRecovery_fast => 'Schnell (C1-5)';

  @override
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number) {
    return 'Führendes Kompartiment: C$number';
  }

  @override
  String get surfaceInterval_tissueRecovery_loadingPercent => 'Sättigung %';

  @override
  String get surfaceInterval_tissueRecovery_medium => 'Mittel (C6-10)';

  @override
  String get surfaceInterval_tissueRecovery_min => 'Min';

  @override
  String get surfaceInterval_tissueRecovery_now => 'Jetzt';

  @override
  String get surfaceInterval_tissueRecovery_slow => 'Langsam (C11-16)';

  @override
  String get surfaceInterval_tissueRecovery_title => 'Gewebe-Regeneration';

  @override
  String get surfaceInterval_title => 'Oberflächenintervall';

  @override
  String tags_action_createNamed(Object tagName) {
    return '\"$tagName\" erstellen';
  }

  @override
  String get tags_action_createTag => 'Tag erstellen';

  @override
  String get tags_action_deleteTag => 'Tag löschen';

  @override
  String tags_dialog_deleteMessage(Object tagName) {
    return 'Möchten Sie \"$tagName\" wirklich löschen? Dies entfernt es von allen Tauchgängen.';
  }

  @override
  String get tags_dialog_deleteTitle => 'Tag löschen?';

  @override
  String get tags_empty =>
      'Noch keine Tags. Erstellen Sie Tags beim Bearbeiten von Tauchgängen.';

  @override
  String get tags_hint_addMoreTags => 'Weitere Tags hinzufügen...';

  @override
  String get tags_hint_addTags => 'Tags hinzufügen...';

  @override
  String get tags_title_manageTags => 'Tags verwalten';

  @override
  String get tank_al30Stage_description => 'Aluminium 30 cuft Stageflasche';

  @override
  String get tank_al30Stage_displayName => 'AL30 Stage';

  @override
  String get tank_al40Stage_description => 'Aluminium 40 cuft Stageflasche';

  @override
  String get tank_al40Stage_displayName => 'AL40 Stage';

  @override
  String get tank_al40_description => 'Aluminium 40 cuft (Pony)';

  @override
  String get tank_al40_displayName => 'AL40';

  @override
  String get tank_al63_description => 'Aluminium 63 cuft';

  @override
  String get tank_al63_displayName => 'AL63';

  @override
  String get tank_al80_description => 'Aluminium 80 cuft (am haeufigsten)';

  @override
  String get tank_al80_displayName => 'AL80';

  @override
  String get tank_hp100_description => 'Hochdruck-Stahlflasche 100 cuft';

  @override
  String get tank_hp100_displayName => 'HP100';

  @override
  String get tank_hp120_description => 'Hochdruck-Stahlflasche 120 cuft';

  @override
  String get tank_hp120_displayName => 'HP120';

  @override
  String get tank_hp80_description => 'Hochdruck-Stahlflasche 80 cuft';

  @override
  String get tank_hp80_displayName => 'HP80';

  @override
  String get tank_lp85_description => 'Niederdruck-Stahlflasche 85 cuft';

  @override
  String get tank_lp85_displayName => 'LP85';

  @override
  String get tank_steel10_description => 'Stahlflasche 10 Liter (Europa)';

  @override
  String get tank_steel10_displayName => 'Stahl 10L';

  @override
  String get tank_steel12_description => 'Stahlflasche 12 Liter (Europa)';

  @override
  String get tank_steel12_displayName => 'Stahl 12L';

  @override
  String get tank_steel15_description => 'Stahlflasche 15 Liter (Europa)';

  @override
  String get tank_steel15_displayName => 'Stahl 15L';

  @override
  String get tides_action_refresh => 'Gezeitendaten aktualisieren';

  @override
  String get tides_chart_24hourForecast => '24-Stunden-Vorhersage';

  @override
  String tides_chart_heightAxis(Object depthSymbol) {
    return 'Höhe ($depthSymbol)';
  }

  @override
  String get tides_chart_msl => 'NN';

  @override
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr) {
    return ' Jetzt $nowTimeStr $nowHeightStr';
  }

  @override
  String get tides_error_unableToLoad =>
      'Gezeitendaten können nicht geladen werden';

  @override
  String get tides_error_unableToLoadChart =>
      'Diagramm kann nicht geladen werden';

  @override
  String tides_label_ago(Object duration) {
    return 'Vor $duration';
  }

  @override
  String tides_label_currentHeight(Object height, Object depthSymbol) {
    return 'Aktuell: $height$depthSymbol';
  }

  @override
  String tides_label_fromNow(Object duration) {
    return 'In $duration';
  }

  @override
  String get tides_label_high => 'Hoch';

  @override
  String get tides_label_highIn => 'Hochwasser in';

  @override
  String get tides_label_highTide => 'Hochwasser';

  @override
  String get tides_label_low => 'Niedrig';

  @override
  String get tides_label_lowIn => 'Niedrigwasser in';

  @override
  String get tides_label_lowTide => 'Niedrigwasser';

  @override
  String tides_label_tideIn(Object duration) {
    return 'in $duration';
  }

  @override
  String get tides_label_tideTimes => 'Gezeitenzeiten';

  @override
  String get tides_label_today => 'Heute';

  @override
  String get tides_label_tomorrow => 'Morgen';

  @override
  String get tides_label_upcomingTides => 'Kommende Gezeiten';

  @override
  String get tides_legend_highTide => 'Hochwasser';

  @override
  String get tides_legend_lowTide => 'Niedrigwasser';

  @override
  String get tides_legend_now => 'Jetzt';

  @override
  String get tides_legend_tideLevel => 'Gezeitenpegel';

  @override
  String get tides_noDataAvailable => 'Keine Gezeitendaten verfügbar';

  @override
  String get tides_noDataForLocation =>
      'Gezeitendaten für diesen Standort nicht verfügbar';

  @override
  String get tides_noExtremesData => 'Keine Extremwerte-Daten';

  @override
  String get tides_noTideTimesAvailable => 'Keine Gezeitenzeiten verfügbar';

  @override
  String tides_semantic_currentTide(
    Object tideState,
    Object height,
    Object depthSymbol,
    Object nextExtreme,
  ) {
    return '$tideState Gezeit, $height$depthSymbol$nextExtreme';
  }

  @override
  String tides_semantic_extremeItem(
    Object typeLabel,
    Object time,
    Object height,
    Object depthSymbol,
  ) {
    return '$typeLabel um $time, $height$depthSymbol';
  }

  @override
  String tides_semantic_tideChart(Object extremesSummary) {
    return 'Gezeitendiagramm. $extremesSummary';
  }

  @override
  String tides_semantic_tideState(Object state) {
    return 'Gezeitenstatus: $state';
  }

  @override
  String get tides_title => 'Gezeiten';

  @override
  String get transfer_appBar_title => 'Uebertragung';

  @override
  String get transfer_computers_aboutContent =>
      'Verbinden Sie Ihren Tauchcomputer ueber Bluetooth, um Tauchprotokolle direkt in die App herunterzuladen. Unterstuetzte Computer sind Suunto, Shearwater, Garmin, Mares und viele andere beliebte Marken.\n\nApple Watch Ultra-Benutzer koennen Tauchdaten direkt aus der Health-App importieren, einschliesslich Tiefe, Dauer und Herzfrequenz.';

  @override
  String get transfer_computers_aboutTitle => 'Ueber Tauchcomputer';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple Watch';

  @override
  String get transfer_computers_appleWatchSubtitle =>
      'Auf der Apple Watch Ultra aufgezeichnete Tauchgaenge importieren';

  @override
  String get transfer_computers_appleWatchTitle =>
      'Von Apple Watch importieren';

  @override
  String get transfer_computers_connectSubtitle =>
      'Tauchcomputer suchen und koppeln';

  @override
  String get transfer_computers_connectTitle => 'Neuen Computer verbinden';

  @override
  String get transfer_computers_errorLoading =>
      'Fehler beim Laden der Computer';

  @override
  String get transfer_computers_loading => 'Laden...';

  @override
  String get transfer_computers_manageTitle => 'Computer verwalten';

  @override
  String get transfer_computers_noComputersSaved =>
      'Keine Computer gespeichert';

  @override
  String transfer_computers_savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Computer',
      one: 'Computer',
    );
    return '$count gespeicherte $_temp0';
  }

  @override
  String get transfer_computers_sectionHeader => 'Tauchcomputer';

  @override
  String get transfer_csvExport_cancelButton => 'Abbrechen';

  @override
  String get transfer_csvExport_dataTypeHeader => 'Datentyp';

  @override
  String get transfer_csvExport_descriptionDives =>
      'Alle Tauchprotokolle als Tabelle exportieren';

  @override
  String get transfer_csvExport_descriptionEquipment =>
      'Ausruestungsinventar und Serviceinformationen exportieren';

  @override
  String get transfer_csvExport_descriptionSites =>
      'Tauchplatzstandorte und Details exportieren';

  @override
  String get transfer_csvExport_dialogTitle => 'CSV exportieren';

  @override
  String get transfer_csvExport_exportButton => 'CSV exportieren';

  @override
  String get transfer_csvExport_optionDivesTitle => 'Tauchgaenge CSV';

  @override
  String get transfer_csvExport_optionEquipmentTitle => 'Ausruestung CSV';

  @override
  String get transfer_csvExport_optionSitesTitle => 'Tauchplaetze CSV';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return '$typeName exportieren';
  }

  @override
  String get transfer_csvExport_typeDives => 'Tauchgaenge';

  @override
  String get transfer_csvExport_typeEquipment => 'Ausruestung';

  @override
  String get transfer_csvExport_typeSites => 'Tauchplaetze';

  @override
  String get transfer_detail_backTooltip => 'Zurueck zur Uebertragung';

  @override
  String get transfer_export_aboutContent =>
      'Exportieren Sie Ihre Tauchdaten in verschiedenen Formaten. PDF erstellt ein druckbares Tauchlogbuch. UDDF ist ein universelles Format, das mit den meisten Tauchlog-Programmen kompatibel ist. CSV-Dateien koennen in Tabellenkalkulationen geoeffnet werden.';

  @override
  String get transfer_export_aboutTitle => 'Ueber Export';

  @override
  String get transfer_export_completed => 'Export abgeschlossen';

  @override
  String get transfer_export_csvSubtitle => 'Tabellenformat';

  @override
  String get transfer_export_csvTitle => 'CSV-Export';

  @override
  String get transfer_export_excelSubtitle =>
      'Alle Daten in einer Datei (Tauchgaenge, Tauchplaetze, Ausruestung, Statistiken)';

  @override
  String get transfer_export_excelTitle => 'Excel-Arbeitsmappe';

  @override
  String transfer_export_failed(Object error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get transfer_export_kmlSubtitle =>
      'Tauchplaetze auf einem 3D-Globus anzeigen';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => 'Multi-Format-Export';

  @override
  String get transfer_export_optionSaveSubtitle =>
      'Speicherort auf Ihrem Geraet waehlen';

  @override
  String get transfer_export_optionSaveTitle => 'In Datei speichern';

  @override
  String get transfer_export_optionShareSubtitle =>
      'Per E-Mail, Nachrichten oder andere Apps senden';

  @override
  String get transfer_export_optionShareTitle => 'Teilen';

  @override
  String get transfer_export_pdfSubtitle => 'Druckbares Tauchlogbuch';

  @override
  String get transfer_export_pdfTitle => 'PDF-Logbuch';

  @override
  String get transfer_export_progressExporting => 'Wird exportiert...';

  @override
  String get transfer_export_sectionHeader => 'Daten exportieren';

  @override
  String get transfer_export_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_export_uddfTitle => 'UDDF-Export';

  @override
  String get transfer_import_aboutContent =>
      'Verwenden Sie \"Daten importieren\" fuer das beste Ergebnis - das Dateiformat und die Quell-App werden automatisch erkannt. Die einzelnen Formatoptionen unten stehen auch fuer den direkten Zugriff zur Verfuegung.';

  @override
  String get transfer_import_aboutTitle => 'Ueber Import';

  @override
  String get transfer_import_autoDetectSemanticLabel =>
      'Daten mit automatischer Erkennung importieren';

  @override
  String get transfer_import_autoDetectSubtitle =>
      'Erkennt automatisch CSV, UDDF, FIT und mehr';

  @override
  String get transfer_import_autoDetectTitle => 'Daten importieren';

  @override
  String get transfer_import_byFormatHeader => 'Nach Format importieren';

  @override
  String get transfer_import_csvSubtitle =>
      'Tauchgaenge aus CSV-Datei importieren';

  @override
  String get transfer_import_csvTitle => 'Aus CSV importieren';

  @override
  String get transfer_import_fitSubtitle =>
      'Tauchgaenge aus Garmin Descent Exportdateien importieren';

  @override
  String get transfer_import_fitTitle => 'Aus FIT-Datei importieren';

  @override
  String get transfer_import_operationCompleted => 'Vorgang abgeschlossen';

  @override
  String transfer_import_operationFailed(Object error) {
    return 'Vorgang fehlgeschlagen: $error';
  }

  @override
  String get transfer_import_sectionHeader => 'Daten importieren';

  @override
  String get transfer_import_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_import_uddfTitle => 'Aus UDDF importieren';

  @override
  String get transfer_pdfExport_cancelButton => 'Abbrechen';

  @override
  String get transfer_pdfExport_dialogTitle => 'PDF-Logbuch exportieren';

  @override
  String get transfer_pdfExport_exportButton => 'PDF exportieren';

  @override
  String get transfer_pdfExport_includeCertCards =>
      'Zertifizierungskarten einschliessen';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle =>
      'Gescannte Zertifizierungskartenbilder zum PDF hinzufuegen';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => 'Seitengroesse';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Letter';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => 'Detailliert';

  @override
  String get transfer_pdfExport_templateDetailedDesc =>
      'Vollstaendige Tauchinformationen mit Notizen und Bewertungen';

  @override
  String get transfer_pdfExport_templateHeader => 'Vorlage';

  @override
  String get transfer_pdfExport_templateNauiStyle => 'NAUI-Stil';

  @override
  String get transfer_pdfExport_templateNauiStyleDesc =>
      'Layout im NAUI-Logbuchformat';

  @override
  String get transfer_pdfExport_templatePadiStyle => 'PADI-Stil';

  @override
  String get transfer_pdfExport_templatePadiStyleDesc =>
      'Layout im PADI-Logbuchformat';

  @override
  String get transfer_pdfExport_templateProfessional => 'Professionell';

  @override
  String get transfer_pdfExport_templateProfessionalDesc =>
      'Unterschrift- und Stempelbereiche zur Verifizierung';

  @override
  String transfer_pdfExport_templateSemanticLabel(Object templateName) {
    return 'Vorlage $templateName auswaehlen';
  }

  @override
  String get transfer_pdfExport_templateSimple => 'Einfach';

  @override
  String get transfer_pdfExport_templateSimpleDesc =>
      'Kompaktes Tabellenformat, viele Tauchgaenge pro Seite';

  @override
  String get transfer_section_computersSubtitle => 'Vom Geraet herunterladen';

  @override
  String get transfer_section_computersTitle => 'Tauchcomputer';

  @override
  String get transfer_section_exportSubtitle => 'CSV, UDDF, PDF-Logbuch';

  @override
  String get transfer_section_exportTitle => 'Exportieren';

  @override
  String get transfer_section_importSubtitle => 'CSV-, UDDF-Dateien';

  @override
  String get transfer_section_importTitle => 'Importieren';

  @override
  String get transfer_summary_description =>
      'Tauchdaten importieren und exportieren';

  @override
  String get transfer_summary_selectSection =>
      'Waehlen Sie einen Bereich aus der Liste';

  @override
  String get transfer_summary_title => 'Uebertragung';

  @override
  String transfer_unknownSection(Object sectionId) {
    return 'Unbekannter Bereich: $sectionId';
  }

  @override
  String get trips_appBar_title => 'Reisen';

  @override
  String get trips_appBar_tripPhotos => 'Reisefotos';

  @override
  String get trips_detail_action_delete => 'Loeschen';

  @override
  String get trips_detail_action_export => 'Exportieren';

  @override
  String get trips_detail_appBar_title => 'Reise';

  @override
  String get trips_detail_dialog_cancel => 'Abbrechen';

  @override
  String get trips_detail_dialog_deleteConfirm => 'Loeschen';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return 'Sind Sie sicher, dass Sie \"$name\" loeschen moechten? Die Reise wird entfernt, aber die Tauchgaenge bleiben erhalten.';
  }

  @override
  String get trips_detail_dialog_deleteTitle => 'Reise loeschen?';

  @override
  String get trips_detail_dives_empty =>
      'Noch keine Tauchgaenge in dieser Reise';

  @override
  String get trips_detail_dives_errorLoading =>
      'Tauchgaenge konnten nicht geladen werden';

  @override
  String get trips_detail_dives_unknownSite => 'Unbekannter Tauchplatz';

  @override
  String trips_detail_dives_viewAll(Object count) {
    return 'Alle anzeigen ($count)';
  }

  @override
  String trips_detail_durationDays(Object days) {
    return '$days Tage';
  }

  @override
  String get trips_detail_export_csv_comingSoon => 'CSV-Export kommt bald';

  @override
  String get trips_detail_export_csv_subtitle =>
      'Alle Tauchgaenge dieser Reise';

  @override
  String get trips_detail_export_csv_title => 'Als CSV exportieren';

  @override
  String get trips_detail_export_pdf_comingSoon => 'PDF-Export kommt bald';

  @override
  String get trips_detail_export_pdf_subtitle =>
      'Reisezusammenfassung mit Tauchgangsdetails';

  @override
  String get trips_detail_export_pdf_title => 'Als PDF exportieren';

  @override
  String get trips_detail_label_liveaboard => 'Tauchsafari';

  @override
  String get trips_detail_label_location => 'Ort';

  @override
  String get trips_detail_label_resort => 'Resort';

  @override
  String get trips_detail_scan_accessDenied =>
      'Zugriff auf Fotobibliothek verweigert';

  @override
  String get trips_detail_scan_addDivesFirst =>
      'Fuegen Sie zuerst Tauchgaenge hinzu, um Fotos zu verknuepfen';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return 'Fehler beim Verknuepfen der Fotos: $error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return 'Fehler beim Scannen: $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return '$count Fotos verknuepft';
  }

  @override
  String get trips_detail_scan_linkingPhotos => 'Fotos werden verknuepft...';

  @override
  String get trips_detail_sectionTitle_details => 'Reisedetails';

  @override
  String get trips_detail_sectionTitle_dives => 'Tauchgaenge';

  @override
  String get trips_detail_sectionTitle_notes => 'Notizen';

  @override
  String get trips_detail_sectionTitle_statistics => 'Reisestatistik';

  @override
  String get trips_detail_snackBar_deleted => 'Reise geloescht';

  @override
  String get trips_detail_stat_avgDepth => 'Durchschn. Tiefe';

  @override
  String get trips_detail_stat_maxDepth => 'Max. Tiefe';

  @override
  String get trips_detail_stat_totalBottomTime => 'Gesamte Grundzeit';

  @override
  String get trips_detail_stat_totalDives => 'Tauchgaenge gesamt';

  @override
  String get trips_detail_tooltip_edit => 'Reise bearbeiten';

  @override
  String get trips_detail_tooltip_editShort => 'Bearbeiten';

  @override
  String get trips_detail_tooltip_moreOptions => 'Weitere Optionen';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Auf Karte anzeigen';

  @override
  String get trips_edit_appBar_add => 'Reise hinzufuegen';

  @override
  String get trips_edit_appBar_edit => 'Reise bearbeiten';

  @override
  String get trips_edit_button_add => 'Reise hinzufuegen';

  @override
  String get trips_edit_button_cancel => 'Abbrechen';

  @override
  String get trips_edit_button_save => 'Speichern';

  @override
  String get trips_edit_button_update => 'Reise aktualisieren';

  @override
  String get trips_edit_dialog_discard => 'Verwerfen';

  @override
  String get trips_edit_dialog_discardContent =>
      'Sie haben ungespeicherte Aenderungen. Sind Sie sicher, dass Sie die Seite verlassen moechten?';

  @override
  String get trips_edit_dialog_discardTitle => 'Aenderungen verwerfen?';

  @override
  String get trips_edit_dialog_keepEditing => 'Weiter bearbeiten';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days Tage';
  }

  @override
  String get trips_edit_hint_liveaboardName => 'z.B. MY Blue Force One';

  @override
  String get trips_edit_hint_location => 'z.B. Aegypten, Rotes Meer';

  @override
  String get trips_edit_hint_notes => 'Zusaetzliche Notizen zu dieser Reise';

  @override
  String get trips_edit_hint_resortName => 'z.B. Marsa Shagra';

  @override
  String get trips_edit_hint_tripName => 'z.B. Rotes Meer Safari 2024';

  @override
  String get trips_edit_label_endDate => 'Enddatum';

  @override
  String get trips_edit_label_liveaboardName => 'Name der Tauchsafari';

  @override
  String get trips_edit_label_location => 'Ort';

  @override
  String get trips_edit_label_notes => 'Notizen';

  @override
  String get trips_edit_label_resortName => 'Resortname';

  @override
  String get trips_edit_label_startDate => 'Startdatum';

  @override
  String get trips_edit_label_tripName => 'Reisename *';

  @override
  String get trips_edit_sectionTitle_dates => 'Reisedaten';

  @override
  String get trips_edit_sectionTitle_location => 'Ort';

  @override
  String get trips_edit_sectionTitle_notes => 'Notizen';

  @override
  String get trips_edit_semanticLabel_save => 'Reise speichern';

  @override
  String get trips_edit_snackBar_added => 'Reise erfolgreich hinzugefuegt';

  @override
  String trips_edit_snackBar_errorLoading(Object error) {
    return 'Fehler beim Laden der Reise: $error';
  }

  @override
  String trips_edit_snackBar_errorSaving(Object error) {
    return 'Fehler beim Speichern der Reise: $error';
  }

  @override
  String get trips_edit_snackBar_updated => 'Reise erfolgreich aktualisiert';

  @override
  String get trips_edit_validation_nameRequired =>
      'Bitte geben Sie einen Reisenamen ein';

  @override
  String get trips_gallery_accessDenied =>
      'Zugriff auf Fotobibliothek verweigert';

  @override
  String get trips_gallery_addDivesFirst =>
      'Fuegen Sie zuerst Tauchgaenge hinzu, um Fotos zu verknuepfen';

  @override
  String get trips_gallery_appBar_title => 'Reisefotos';

  @override
  String trips_gallery_diveSection_photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fotos',
      one: 'Foto',
    );
    return '$_temp0';
  }

  @override
  String trips_gallery_diveSection_title(Object number, Object site) {
    return 'Tauchgang #$number - $site';
  }

  @override
  String get trips_gallery_empty_subtitle =>
      'Tippen Sie auf das Kamerasymbol, um Ihre Galerie zu durchsuchen';

  @override
  String get trips_gallery_empty_title => 'Keine Fotos in dieser Reise';

  @override
  String trips_gallery_errorLinking(Object error) {
    return 'Fehler beim Verknuepfen der Fotos: $error';
  }

  @override
  String trips_gallery_errorScanning(Object error) {
    return 'Fehler beim Scannen: $error';
  }

  @override
  String trips_gallery_error_loading(Object error) {
    return 'Fehler beim Laden der Fotos: $error';
  }

  @override
  String trips_gallery_linkedPhotos(Object count) {
    return '$count Fotos verknuepft';
  }

  @override
  String get trips_gallery_linkingPhotos => 'Fotos werden verknuepft...';

  @override
  String get trips_gallery_tooltip_scan => 'Geraetegalerie durchsuchen';

  @override
  String get trips_gallery_tripNotFound => 'Reise nicht gefunden';

  @override
  String get trips_list_button_retry => 'Erneut versuchen';

  @override
  String get trips_list_empty_button => 'Erste Reise hinzufuegen';

  @override
  String get trips_list_empty_filtered_subtitle =>
      'Versuchen Sie, Ihre Filter anzupassen oder zurueckzusetzen';

  @override
  String get trips_list_empty_filtered_title =>
      'Keine Reisen entsprechen Ihren Filtern';

  @override
  String get trips_list_empty_subtitle =>
      'Erstellen Sie Reisen, um Ihre Tauchgaenge nach Reiseziel zu gruppieren';

  @override
  String get trips_list_empty_title => 'Noch keine Reisen hinzugefuegt';

  @override
  String trips_list_error_loading(Object error) {
    return 'Fehler beim Laden der Reisen: $error';
  }

  @override
  String get trips_list_fab_addTrip => 'Reise hinzufuegen';

  @override
  String get trips_list_filters_clearAll => 'Alle loeschen';

  @override
  String get trips_list_sort_title => 'Reisen sortieren';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count Tauchgaenge';
  }

  @override
  String get trips_list_tooltip_addTrip => 'Reise hinzufuegen';

  @override
  String get trips_list_tooltip_search => 'Reisen durchsuchen';

  @override
  String get trips_list_tooltip_sort => 'Sortieren';

  @override
  String get trips_photos_empty_scanButton => 'Geraetegalerie durchsuchen';

  @override
  String get trips_photos_empty_title => 'Noch keine Fotos';

  @override
  String get trips_photos_error_loading => 'Fehler beim Laden der Fotos';

  @override
  String trips_photos_moreIndicator(Object count) {
    return '+$count';
  }

  @override
  String trips_photos_moreIndicator_semanticLabel(Object count) {
    return '$count weitere Fotos';
  }

  @override
  String get trips_photos_sectionTitle => 'Fotos';

  @override
  String get trips_photos_tooltip_scan => 'Geraetegalerie durchsuchen';

  @override
  String get trips_photos_viewAll => 'Alle anzeigen';

  @override
  String get trips_picker_clearTooltip => 'Auswahl loeschen';

  @override
  String get trips_picker_empty_createButton => 'Reise erstellen';

  @override
  String get trips_picker_empty_title => 'Noch keine Reisen';

  @override
  String trips_picker_error(Object error) {
    return 'Fehler beim Laden der Reisen: $error';
  }

  @override
  String get trips_picker_hint => 'Tippen, um eine Reise auszuwaehlen';

  @override
  String get trips_picker_newTrip => 'Neue Reise';

  @override
  String get trips_picker_noSelection => 'Keine Reise ausgewaehlt';

  @override
  String get trips_picker_sheetTitle => 'Reise auswaehlen';

  @override
  String trips_picker_suggestedPrefix(Object name) {
    return 'Vorschlag: $name';
  }

  @override
  String get trips_picker_suggestedUse => 'Verwenden';

  @override
  String get trips_search_empty_hint => 'Nach Name, Ort oder Resort suchen';

  @override
  String get trips_search_fieldLabel => 'Reisen durchsuchen...';

  @override
  String trips_search_noResults(Object query) {
    return 'Keine Reisen gefunden fuer \"$query\"';
  }

  @override
  String get trips_search_tooltip_back => 'Zurueck';

  @override
  String get trips_search_tooltip_clear => 'Suche loeschen';

  @override
  String get trips_summary_header_subtitle =>
      'Waehlen Sie eine Reise aus der Liste, um Details anzuzeigen';

  @override
  String get trips_summary_header_title => 'Reisen';

  @override
  String get trips_summary_overview_title => 'Uebersicht';

  @override
  String get trips_summary_quickActions_add => 'Reise hinzufuegen';

  @override
  String get trips_summary_quickActions_title => 'Schnellaktionen';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date • $count Tauchgaenge';
  }

  @override
  String get trips_summary_recentTitle => 'Neueste Reisen';

  @override
  String get trips_summary_stat_daysDiving => 'Tauchtage';

  @override
  String get trips_summary_stat_liveaboards => 'Tauchsafaris';

  @override
  String get trips_summary_stat_totalDives => 'Tauchgaenge gesamt';

  @override
  String get trips_summary_stat_totalTrips => 'Reisen gesamt';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date • In $days Tagen';
  }

  @override
  String get trips_summary_upcomingTitle => 'Bevorstehend';

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
  String get units_dateFormat_ddmmyyyy => 'TT.MM.JJJJ';

  @override
  String get units_dateFormat_mmddyyyy => 'MM/TT/JJJJ';

  @override
  String get units_dateFormat_mmmDYYYY => 'MMM D, YYYY';

  @override
  String get units_dateFormat_yyyymmdd => 'JJJJ-MM-TT';

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
  String get units_sac_pressurePerMin => 'Druck/min';

  @override
  String get units_temperature_celsius => 'C';

  @override
  String get units_temperature_fahrenheit => 'F';

  @override
  String get units_timeFormat_twelveHour => '12-Stunden';

  @override
  String get units_timeFormat_twentyFourHour => '24-Stunden';

  @override
  String get units_volume_cubicFeet => 'cuft';

  @override
  String get units_volume_liters => 'L';

  @override
  String get units_weight_kilograms => 'kg';

  @override
  String get units_weight_pounds => 'lbs';

  @override
  String get universalImport_action_continue => 'Weiter';

  @override
  String get universalImport_action_deselectAll => 'Alle abwählen';

  @override
  String get universalImport_action_done => 'Fertig';

  @override
  String get universalImport_action_import => 'Importieren';

  @override
  String get universalImport_action_selectAll => 'Alle auswählen';

  @override
  String get universalImport_action_selectFile => 'Datei auswählen';

  @override
  String get universalImport_description_supportedFormats =>
      'Wählen Sie eine Tauchprotokoll-Datei zum Importieren aus. Unterstützte Formate sind CSV, UDDF, Subsurface XML und Garmin FIT.';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Dieses Format wird noch nicht unterstützt. Bitte exportieren Sie als UDDF oder CSV.';

  @override
  String get universalImport_hint_tagDescription =>
      'Taggen Sie alle importierten Tauchgänge für einfaches Filtern';

  @override
  String get universalImport_hint_tagExample =>
      'z.B. MacDive Import 2026-02-09';

  @override
  String get universalImport_label_columnMapping => 'Spaltenzuordnung';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped von $total Spalten zugeordnet';
  }

  @override
  String get universalImport_label_detecting => 'Wird erkannt...';

  @override
  String universalImport_label_diveNumber(Object number) {
    return 'Tauchgang #$number';
  }

  @override
  String get universalImport_label_duplicate => 'Duplikat';

  @override
  String universalImport_label_duplicatesFound(Object count) {
    return '$count Duplikate gefunden und automatisch abgewählt.';
  }

  @override
  String get universalImport_label_importComplete => 'Import abgeschlossen';

  @override
  String get universalImport_label_importTag => 'Import-Tag';

  @override
  String get universalImport_label_importing => 'Importieren';

  @override
  String get universalImport_label_importingEllipsis => 'Wird importiert...';

  @override
  String universalImport_label_importingProgress(Object current, Object total) {
    return 'Importieren $current von $total';
  }

  @override
  String universalImport_label_percentMatch(Object percent) {
    return '$percent% Übereinstimmung';
  }

  @override
  String get universalImport_label_possibleMatch => 'Mögliche Übereinstimmung';

  @override
  String get universalImport_label_selectCorrectSource =>
      'Nicht richtig? Wählen Sie die richtige Quelle:';

  @override
  String universalImport_label_selected(Object count) {
    return '$count ausgewählt';
  }

  @override
  String get universalImport_label_skip => 'Überspringen';

  @override
  String universalImport_label_taggedAs(Object tag) {
    return 'Getaggt als: $tag';
  }

  @override
  String get universalImport_label_unknownDate => 'Unbekanntes Datum';

  @override
  String get universalImport_label_unnamed => 'Unbenannt';

  @override
  String universalImport_label_xOfY(Object current, Object total) {
    return '$current von $total';
  }

  @override
  String universalImport_label_xOfYSelected(Object selected, Object total) {
    return '$selected von $total ausgewählt';
  }

  @override
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  ) {
    return '$selected von $total $entityType ausgewählt';
  }

  @override
  String universalImport_semantics_importError(Object error) {
    return 'Importfehler: $error';
  }

  @override
  String universalImport_semantics_importProgress(Object percent) {
    return 'Importfortschritt: $percent Prozent';
  }

  @override
  String universalImport_semantics_itemsSelected(Object count) {
    return '$count Elemente zum Import ausgewählt';
  }

  @override
  String get universalImport_semantics_possibleDuplicate =>
      'Mögliches Duplikat';

  @override
  String get universalImport_semantics_probableDuplicate =>
      'Wahrscheinliches Duplikat';

  @override
  String universalImport_semantics_sourceDetected(Object description) {
    return 'Quelle erkannt: $description';
  }

  @override
  String universalImport_semantics_sourceUncertain(Object description) {
    return 'Quelle unsicher: $description';
  }

  @override
  String universalImport_semantics_toggleSelection(Object name) {
    return 'Auswahl für $name umschalten';
  }

  @override
  String get universalImport_step_import => 'Importieren';

  @override
  String get universalImport_step_map => 'Zuordnen';

  @override
  String get universalImport_step_review => 'Überprüfen';

  @override
  String get universalImport_step_select => 'Auswählen';

  @override
  String get universalImport_title => 'Daten importieren';

  @override
  String get universalImport_tooltip_clearTag => 'Tag löschen';

  @override
  String get universalImport_tooltip_closeWizard =>
      'Import-Assistent schließen';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return 'Basis ($suitType): $weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return 'Koerpergewichtsanpassung: +$adjustment kg';
  }

  @override
  String get weightCalc_suit_drysuit => 'Trockentauchanzug';

  @override
  String get weightCalc_suit_none => 'Kein Anzug';

  @override
  String get weightCalc_suit_rashguard => 'Nur Rashguard';

  @override
  String get weightCalc_suit_semidry => 'Halbtrockenanzug';

  @override
  String get weightCalc_suit_shorty3mm => '3mm Shorty';

  @override
  String get weightCalc_suit_wetsuit3mm => '3mm Neoprenanzug';

  @override
  String get weightCalc_suit_wetsuit5mm => '5mm Neoprenanzug';

  @override
  String get weightCalc_suit_wetsuit7mm => '7mm Neoprenanzug';

  @override
  String weightCalc_tankLine(Object tankMaterial, Object adjustment) {
    return 'Flasche ($tankMaterial): $adjustment kg';
  }

  @override
  String get weightCalc_title => 'Gewichtsberechnung:';

  @override
  String weightCalc_total(Object total) {
    return 'Gesamt: $total kg';
  }

  @override
  String weightCalc_waterLine(Object waterType, Object adjustment) {
    return 'Wasser ($waterType): $adjustment kg';
  }

  @override
  String divePlanner_label_resultsWithWarnings(Object count) {
    return 'Ergebnisse, $count Warnungen';
  }

  @override
  String tides_semantic_tideCycle(Object state, Object height) {
    return 'Gezeitenzyklus, Status: $state, Höhe: $height';
  }

  @override
  String get tides_label_agoSuffix => 'her';

  @override
  String get tides_label_fromNowSuffix => 'ab jetzt';

  @override
  String get certifications_card_issued => 'AUSGESTELLT';

  @override
  String certifications_certificate_cardNumber(Object number) {
    return 'Kartennummer: $number';
  }

  @override
  String get certifications_certificate_footer =>
      'Offizielle Tauchzertifizierung';

  @override
  String get certifications_certificate_hasCompletedTraining =>
      'hat die Ausbildung abgeschlossen als';

  @override
  String certifications_certificate_instructor(Object name) {
    return 'Tauchlehrer: $name';
  }

  @override
  String certifications_certificate_issued(Object date) {
    return 'Ausgestellt: $date';
  }

  @override
  String get certifications_certificate_thisCertifies =>
      'Hiermit wird bescheinigt, dass';

  @override
  String get diveComputer_discovery_chooseDifferentDevice =>
      'Anderes Geraet waehlen';

  @override
  String get diveComputer_discovery_computer => 'Computer';

  @override
  String get diveComputer_discovery_connectAndDownload =>
      'Verbinden & Herunterladen';

  @override
  String get diveComputer_discovery_connectingToDevice =>
      'Verbindung wird hergestellt...';

  @override
  String diveComputer_discovery_deviceNameHint(Object model) {
    return 'z.B. Mein $model';
  }

  @override
  String get diveComputer_discovery_deviceNameLabel => 'Geraetename';

  @override
  String get diveComputer_discovery_exitDialogCancel => 'Abbrechen';

  @override
  String get diveComputer_discovery_exitDialogConfirm => 'Beenden';

  @override
  String get diveComputer_discovery_exitDialogContent =>
      'Moechten Sie wirklich beenden? Ihr Fortschritt geht verloren.';

  @override
  String get diveComputer_discovery_exitDialogTitle => 'Einrichtung beenden?';

  @override
  String get diveComputer_discovery_exitTooltip => 'Einrichtung beenden';

  @override
  String get diveComputer_discovery_noDeviceSelected =>
      'Kein Geraet ausgewaehlt';

  @override
  String get diveComputer_discovery_pleaseWaitConnection =>
      'Bitte warten, Verbindung wird hergestellt';

  @override
  String get diveComputer_discovery_recognizedDevice => 'Erkanntes Geraet';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      'Dieses Geraet befindet sich in unserer Bibliothek unterstuetzter Geraete. Der Tauchgangs-Download sollte automatisch funktionieren.';

  @override
  String get diveComputer_discovery_stepConnect => 'Verbinden';

  @override
  String get diveComputer_discovery_stepDone => 'Fertig';

  @override
  String get diveComputer_discovery_stepDownload => 'Download';

  @override
  String get diveComputer_discovery_stepScan => 'Suchen';

  @override
  String get diveComputer_discovery_titleComplete => 'Abgeschlossen';

  @override
  String get diveComputer_discovery_titleConfirmDevice => 'Geraet bestaetigen';

  @override
  String get diveComputer_discovery_titleConnecting =>
      'Verbindung wird hergestellt';

  @override
  String get diveComputer_discovery_titleDownloading => 'Wird heruntergeladen';

  @override
  String get diveComputer_discovery_titleFindDevice => 'Geraet suchen';

  @override
  String get diveComputer_discovery_unknownDevice => 'Unbekanntes Geraet';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      'Dieses Geraet befindet sich nicht in unserer Bibliothek. Wir versuchen eine Verbindung herzustellen, aber der Download funktioniert moeglicherweise nicht.';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... und $count weitere';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Abbrechen';

  @override
  String get diveComputer_downloadStep_cancelled => 'Download abgebrochen';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadFailed =>
      'Download fehlgeschlagen';

  @override
  String get diveComputer_downloadStep_downloadedDives =>
      'Heruntergeladene Tauchgaenge';

  @override
  String diveComputer_downloadStep_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_downloadStep_errorOccurred =>
      'Ein Fehler ist aufgetreten';

  @override
  String diveComputer_downloadStep_errorSemanticLabel(Object error) {
    return 'Download-Fehler: $error';
  }

  @override
  String diveComputer_downloadStep_percentAccessibility(Object percent) {
    return ', $percent Prozent';
  }

  @override
  String get diveComputer_downloadStep_preparing => 'Wird vorbereitet...';

  @override
  String diveComputer_downloadStep_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String diveComputer_downloadStep_progressSemanticLabel(
    Object status,
    Object percent,
  ) {
    return 'Download-Fortschritt: $status$percent';
  }

  @override
  String get diveComputer_downloadStep_retry => 'Erneut versuchen';

  @override
  String get diveComputer_download_cancel => 'Abbrechen';

  @override
  String get diveComputer_download_closeTooltip => 'Schliessen';

  @override
  String get diveComputer_download_computerNotFound =>
      'Computer nicht gefunden';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return 'Geraet nicht gefunden. Stellen Sie sicher, dass Ihr $name in der Naehe ist und sich im Uebertragungsmodus befindet.';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle =>
      'Geraet nicht gefunden';

  @override
  String get diveComputer_download_divesUpdated => 'Tauchgaenge aktualisiert';

  @override
  String get diveComputer_download_done => 'Fertig';

  @override
  String get diveComputer_download_downloadedDives =>
      'Heruntergeladene Tauchgaenge';

  @override
  String get diveComputer_download_duplicatesSkipped =>
      'Duplikate uebersprungen';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_download_errorOccurred =>
      'Ein Fehler ist aufgetreten';

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get diveComputer_download_goBack => 'Zurueck';

  @override
  String get diveComputer_download_importFailed => 'Import fehlgeschlagen';

  @override
  String get diveComputer_download_importResults => 'Import-Ergebnisse';

  @override
  String get diveComputer_download_importedDives => 'Importierte Tauchgaenge';

  @override
  String get diveComputer_download_newDivesImported =>
      'Neue Tauchgaenge importiert';

  @override
  String get diveComputer_download_preparing => 'Wird vorbereitet...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_retry => 'Erneut versuchen';

  @override
  String diveComputer_download_scanError(Object error) {
    return 'Scan-Fehler: $error';
  }

  @override
  String diveComputer_download_searchingForDevice(Object name) {
    return 'Suche nach $name...';
  }

  @override
  String get diveComputer_download_searchingInstructions =>
      'Stellen Sie sicher, dass das Geraet in der Naehe ist und sich im Uebertragungsmodus befindet';

  @override
  String get diveComputer_download_title => 'Tauchgaenge herunterladen';

  @override
  String get diveComputer_download_tryAgain => 'Erneut versuchen';

  @override
  String get diveComputer_list_addComputer => 'Computer hinzufuegen';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return 'Tauchcomputer: $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count Tauchgaenge';
  }

  @override
  String get diveComputer_list_downloadTooltip => 'Tauchgaenge herunterladen';

  @override
  String get diveComputer_list_emptyMessage =>
      'Verbinden Sie Ihren Tauchcomputer, um Tauchgaenge direkt in die App herunterzuladen.';

  @override
  String get diveComputer_list_emptyTitle => 'Keine Tauchcomputer';

  @override
  String get diveComputer_list_findComputers => 'Computer suchen';

  @override
  String get diveComputer_list_helpBluetooth =>
      '- Bluetooth LE (die meisten modernen Computer)';

  @override
  String get diveComputer_list_helpBluetoothClassic =>
      '- Bluetooth Classic (aeltere Modelle)';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi und ueber 50 weitere Modelle.';

  @override
  String get diveComputer_list_helpBrandsTitle => 'Unterstuetzte Marken';

  @override
  String get diveComputer_list_helpConnectionsTitle =>
      'Unterstuetzte Verbindungen';

  @override
  String get diveComputer_list_helpDialogTitle => 'Tauchcomputer-Hilfe';

  @override
  String get diveComputer_list_helpDismiss => 'Verstanden';

  @override
  String get diveComputer_list_helpTip1 =>
      '- Stellen Sie sicher, dass Ihr Computer im Uebertragungsmodus ist';

  @override
  String get diveComputer_list_helpTip2 =>
      '- Halten Sie die Geraete waehrend des Downloads nah beieinander';

  @override
  String get diveComputer_list_helpTip3 =>
      '- Stellen Sie sicher, dass Bluetooth aktiviert ist';

  @override
  String get diveComputer_list_helpTipsTitle => 'Tipps';

  @override
  String get diveComputer_list_helpTooltip => 'Hilfe';

  @override
  String get diveComputer_list_helpUsb => '- USB (nur Desktop)';

  @override
  String get diveComputer_list_loadFailed =>
      'Tauchcomputer konnten nicht geladen werden';

  @override
  String get diveComputer_list_retry => 'Erneut versuchen';

  @override
  String get diveComputer_list_title => 'Tauchcomputer';

  @override
  String get diveComputer_summary_diveComputer => 'Tauchcomputer';

  @override
  String diveComputer_summary_divesDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    return '$count $_temp0 heruntergeladen';
  }

  @override
  String get diveComputer_summary_done => 'Fertig';

  @override
  String get diveComputer_summary_imported => 'Importiert';

  @override
  String diveComputer_summary_semanticLabel(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    return '$count $_temp0 von $name heruntergeladen';
  }

  @override
  String get diveComputer_summary_skippedDuplicates =>
      'Uebersprungen (Duplikate)';

  @override
  String get diveComputer_summary_title => 'Download abgeschlossen!';

  @override
  String get diveComputer_summary_updated => 'Aktualisiert';

  @override
  String get diveComputer_summary_viewDives => 'Tauchgaenge anzeigen';

  @override
  String get diveImport_alreadyImported => 'Bereits importiert';

  @override
  String get diveImport_avgHR => 'Durchschn. HF';

  @override
  String get diveImport_back => 'Zurueck';

  @override
  String get diveImport_deselectAll => 'Alle abwaehlen';

  @override
  String get diveImport_divesImported => 'Tauchgaenge importiert';

  @override
  String get diveImport_divesMerged => 'Tauchgaenge zusammengefuehrt';

  @override
  String get diveImport_divesSkipped => 'Tauchgaenge uebersprungen';

  @override
  String get diveImport_done => 'Fertig';

  @override
  String get diveImport_duration => 'Dauer';

  @override
  String get diveImport_error => 'Fehler';

  @override
  String get diveImport_fit_closeTooltip => 'FIT-Import schliessen';

  @override
  String get diveImport_fit_noDivesDescription =>
      'Waehlen Sie eine oder mehrere .fit-Dateien, die aus Garmin Connect exportiert oder von einem Garmin Descent-Geraet kopiert wurden.';

  @override
  String get diveImport_fit_noDivesLoaded => 'Keine Tauchgaenge geladen';

  @override
  String diveImport_fit_parsed(int diveCount, int fileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'Dateien',
      one: 'Datei',
    );
    return '$diveCount $_temp0 aus $fileCount $_temp1 eingelesen';
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
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'Dateien',
      one: 'Datei',
    );
    return '$diveCount $_temp0 aus $fileCount $_temp1 eingelesen ($skippedCount uebersprungen)';
  }

  @override
  String get diveImport_fit_parsing => 'Wird eingelesen...';

  @override
  String get diveImport_fit_selectFiles => 'FIT-Dateien auswaehlen';

  @override
  String get diveImport_fit_title => 'Aus FIT-Datei importieren';

  @override
  String get diveImport_healthkit_accessDescription =>
      'Submersion benoetigt Zugriff auf Ihre Apple Watch-Tauchdaten, um Tauchgaenge zu importieren.';

  @override
  String get diveImport_healthkit_accessRequired =>
      'HealthKit-Zugriff erforderlich';

  @override
  String get diveImport_healthkit_closeTooltip =>
      'Apple Watch-Import schliessen';

  @override
  String get diveImport_healthkit_dateFrom => 'Von';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return '$label Datumsauswahl';
  }

  @override
  String get diveImport_healthkit_dateTo => 'Bis';

  @override
  String get diveImport_healthkit_fetchDives => 'Tauchgaenge abrufen';

  @override
  String get diveImport_healthkit_fetching => 'Wird abgerufen...';

  @override
  String get diveImport_healthkit_grantAccess => 'Zugriff gewaehren';

  @override
  String get diveImport_healthkit_noDivesFound => 'Keine Tauchgaenge gefunden';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'Im ausgewaehlten Zeitraum wurden keine Tauchaktivitaeten gefunden.';

  @override
  String get diveImport_healthkit_notAvailable => 'Nicht verfuegbar';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'Apple Watch-Import ist nur auf iOS- und macOS-Geraeten verfuegbar.';

  @override
  String get diveImport_healthkit_permissionCheckFailed =>
      'Berechtigungspruefung fehlgeschlagen';

  @override
  String get diveImport_healthkit_title => 'Von Apple Watch importieren';

  @override
  String get diveImport_healthkit_watchTitle => 'Von Watch importieren';

  @override
  String get diveImport_import => 'Importieren';

  @override
  String get diveImport_importComplete => 'Import abgeschlossen';

  @override
  String get diveImport_likelyDuplicate => 'Wahrscheinliches Duplikat';

  @override
  String get diveImport_maxDepth => 'Max. Tiefe';

  @override
  String get diveImport_newDive => 'Neuer Tauchgang';

  @override
  String get diveImport_next => 'Weiter';

  @override
  String get diveImport_possibleDuplicate => 'Moegliches Duplikat';

  @override
  String get diveImport_reviewSelectedDives =>
      'Ausgewaehlte Tauchgaenge pruefen';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: ', $possibleCount moegliche Duplikate',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: ', $skipCount werden uebersprungen',
      zero: '',
    );
    return '$newCount neu$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => 'Alle auswaehlen';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count ausgewaehlt';
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
  String get diveImport_step_done => 'Fertig';

  @override
  String get diveImport_step_review => 'Pruefen';

  @override
  String get diveImport_step_select => 'Auswaehlen';

  @override
  String get diveImport_temp => 'Temp.';

  @override
  String get diveImport_toggleDiveSelection =>
      'Auswahl fuer Tauchgang umschalten';

  @override
  String get diveImport_uddf_buddies => 'Tauchpartner';

  @override
  String get diveImport_uddf_certifications => 'Zertifizierungen';

  @override
  String get diveImport_uddf_closeTooltip => 'UDDF-Import schliessen';

  @override
  String get diveImport_uddf_diveCenters => 'Tauchcenter';

  @override
  String get diveImport_uddf_diveTypes => 'Taucharten';

  @override
  String get diveImport_uddf_dives => 'Tauchgaenge';

  @override
  String get diveImport_uddf_duplicate => 'Duplikat';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return '$count Duplikate gefunden und automatisch abgewaehlt.';
  }

  @override
  String get diveImport_uddf_equipment => 'Ausruestung';

  @override
  String get diveImport_uddf_equipmentSets => 'Ausruestungssets';

  @override
  String diveImport_uddf_importProgress(Object current, Object total) {
    return '$current von $total';
  }

  @override
  String get diveImport_uddf_importing => 'Wird importiert...';

  @override
  String get diveImport_uddf_likelyDuplicate => 'Wahrscheinliches Duplikat';

  @override
  String get diveImport_uddf_noFileDescription =>
      'Waehlen Sie eine .uddf- oder .xml-Datei, die aus einer anderen Tauchlog-Anwendung exportiert wurde.';

  @override
  String get diveImport_uddf_noFileSelected => 'Keine Datei ausgewaehlt';

  @override
  String get diveImport_uddf_parsing => 'Wird eingelesen...';

  @override
  String get diveImport_uddf_possibleDuplicate => 'Moegliches Duplikat';

  @override
  String get diveImport_uddf_selectFile => 'UDDF-Datei auswaehlen';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '$selected von $total ausgewaehlt';
  }

  @override
  String get diveImport_uddf_sites => 'Tauchplaetze';

  @override
  String get diveImport_uddf_stepImport => 'Importieren';

  @override
  String get diveImport_uddf_tabBuddies => 'Partner';

  @override
  String get diveImport_uddf_tabCenters => 'Center';

  @override
  String get diveImport_uddf_tabCerts => 'Zert.';

  @override
  String get diveImport_uddf_tabCourses => 'Kurse';

  @override
  String get diveImport_uddf_tabDives => 'Tauchgaenge';

  @override
  String get diveImport_uddf_tabEquipment => 'Ausruestung';

  @override
  String get diveImport_uddf_tabSets => 'Sets';

  @override
  String get diveImport_uddf_tabSites => 'Plaetze';

  @override
  String get diveImport_uddf_tabTags => 'Tags';

  @override
  String get diveImport_uddf_tabTrips => 'Reisen';

  @override
  String get diveImport_uddf_tabTypes => 'Typen';

  @override
  String get diveImport_uddf_tags => 'Tags';

  @override
  String get diveImport_uddf_title => 'Aus UDDF importieren';

  @override
  String get diveImport_uddf_toggleDiveSelection =>
      'Auswahl fuer Tauchgang umschalten';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return 'Auswahl fuer $name umschalten';
  }

  @override
  String get diveImport_uddf_trips => 'Reisen';

  @override
  String get divePlanner_segmentEditor_addTitle => 'Segment hinzufuegen';

  @override
  String divePlanner_segmentEditor_ascentRate(Object unit) {
    return 'Aufstiegsgeschwindigkeit ($unit/min)';
  }

  @override
  String divePlanner_segmentEditor_descentRate(Object unit) {
    return 'Abstiegsgeschwindigkeit ($unit/min)';
  }

  @override
  String get divePlanner_segmentEditor_duration => 'Dauer (min)';

  @override
  String get divePlanner_segmentEditor_editTitle => 'Segment bearbeiten';

  @override
  String divePlanner_segmentEditor_endDepth(Object unit) {
    return 'Endtiefe ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_gasSwitchTime => 'Gaswechselzeit';

  @override
  String get divePlanner_segmentEditor_segmentType => 'Segmenttyp';

  @override
  String divePlanner_segmentEditor_startDepth(Object unit) {
    return 'Starttiefe ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_tankGas => 'Flasche / Gas';

  @override
  String get divePlanner_segmentList_addSegment => 'Segment hinzufuegen';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return 'Aufstieg $startDepth -> $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return 'Grundzeit $depth fuer $minutes min';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return 'Deko $depth fuer $minutes min';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => 'Segment loeschen';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return 'Abstieg $startDepth -> $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => 'Segment bearbeiten';

  @override
  String get divePlanner_segmentList_emptyMessage =>
      'Segmente manuell hinzufuegen oder einen Schnellplan erstellen';

  @override
  String get divePlanner_segmentList_emptyTitle => 'Noch keine Segmente';

  @override
  String divePlanner_segmentList_gasSwitch(Object gasName) {
    return 'Gaswechsel zu $gasName';
  }

  @override
  String get divePlanner_segmentList_quickPlan => 'Schnellplan';

  @override
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes) {
    return 'Sicherheitsstopp $depth fuer $minutes min';
  }

  @override
  String get divePlanner_segmentList_title => 'Tauchsegmente';

  @override
  String get divePlanner_segmentType_ascent => 'Aufstieg';

  @override
  String get divePlanner_segmentType_bottomTime => 'Grundzeit';

  @override
  String get divePlanner_segmentType_decoStop => 'Dekostopp';

  @override
  String get divePlanner_segmentType_descent => 'Abstieg';

  @override
  String get divePlanner_segmentType_gasSwitch => 'Gaswechsel';

  @override
  String get divePlanner_segmentType_safetyStop => 'Sicherheitsstopp';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'Rock Bottom ist die Mindestgasreserve fuer einen Notaufstieg bei Luftteilung mit dem Tauchpartner.\n\n- Verwendet erhoehte AMV-Werte (2-3x normal)\n- Geht davon aus, dass beide Taucher eine Flasche nutzen\n- Beinhaltet Sicherheitsstopp wenn aktiviert\n\nDrehen Sie den Tauchgang immer BEVOR Sie Rock Bottom erreichen!';

  @override
  String get gasCalculators_rockBottom_aboutTitle => 'Ueber Rock Bottom';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired =>
      'Benoetigtes Gas fuer Aufstieg';

  @override
  String get gasCalculators_rockBottom_ascentRate => 'Aufstiegsgeschwindigkeit';

  @override
  String gasCalculators_rockBottom_ascentTimeToDepth(
    Object depth,
    Object unit,
  ) {
    return 'Aufstiegszeit bis $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_ascentTimeToSurface =>
      'Aufstiegszeit bis zur Oberflaeche';

  @override
  String get gasCalculators_rockBottom_buddySac => 'AMV Tauchpartner';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'Kombiniertes Stress-AMV';

  @override
  String get gasCalculators_rockBottom_emergencyAscentBreakdown =>
      'Notaufstieg im Detail';

  @override
  String get gasCalculators_rockBottom_emergencyScenario => 'Notfallszenario';

  @override
  String get gasCalculators_rockBottom_includeSafetyStop =>
      'Sicherheitsstopp einbeziehen';

  @override
  String get gasCalculators_rockBottom_maximumDepth => 'Maximale Tiefe';

  @override
  String get gasCalculators_rockBottom_minimumReserve => 'Mindestreserve';

  @override
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  ) {
    return 'Mindestreserve: $pressure $pressureUnit, $volume $volumeUnit. Tauchgang umkehren bei $pressure $pressureUnit Restdruck';
  }

  @override
  String gasCalculators_rockBottom_safetyStopDuration(
    Object depth,
    Object unit,
  ) {
    return '3 Minuten bei $depth$unit';
  }

  @override
  String gasCalculators_rockBottom_safetyStopGas(Object depth, Object unit) {
    return 'Sicherheitsstopp-Gas (3 min @ $depth$unit)';
  }

  @override
  String get gasCalculators_rockBottom_stressedSacHint =>
      'Hoehere AMV-Werte verwenden, um Stress im Notfall zu beruecksichtigen';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'Stress-AMV-Werte';

  @override
  String get gasCalculators_rockBottom_tankSize => 'Flaschengroesse';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded =>
      'Benoetigte Gesamtreserve';

  @override
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  ) {
    return 'Tauchgang umkehren bei $pressure $pressureUnit Restdruck';
  }

  @override
  String get gasCalculators_rockBottom_yourSac => 'Dein AMV';

  @override
  String get maps_heatMap_hide => 'Heatmap ausblenden';

  @override
  String get maps_heatMap_overlayOff => 'Heatmap-Overlay ist aus';

  @override
  String get maps_heatMap_overlayOn => 'Heatmap-Overlay ist an';

  @override
  String get maps_heatMap_show => 'Heatmap anzeigen';

  @override
  String get maps_offline_bounds => 'Grenzen';

  @override
  String maps_offline_cacheHitRateAccessibility(Object rate) {
    return 'Cache-Trefferquote: $rate Prozent';
  }

  @override
  String get maps_offline_cacheHits => 'Cache-Treffer';

  @override
  String get maps_offline_cacheMisses => 'Cache-Fehltreffer';

  @override
  String get maps_offline_cacheStatistics => 'Cache-Statistiken';

  @override
  String get maps_offline_cancelDownload => 'Download abbrechen';

  @override
  String get maps_offline_clearAll => 'Alle loeschen';

  @override
  String get maps_offline_clearAllCache => 'Gesamten Cache loeschen';

  @override
  String get maps_offline_clearAllCacheMessage =>
      'Alle heruntergeladenen Kartenregionen und zwischengespeicherten Kacheln loeschen?';

  @override
  String get maps_offline_clearAllCacheTitle => 'Gesamten Cache loeschen?';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return 'Dies loescht $count Kacheln ($size).';
  }

  @override
  String get maps_offline_created => 'Erstellt';

  @override
  String maps_offline_deleteRegion(Object name) {
    return 'Region $name loeschen';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return '\"$name\" und die $count zwischengespeicherten Kacheln loeschen?\n\nDies gibt $size Speicherplatz frei.';
  }

  @override
  String get maps_offline_deleteRegionTitle => 'Region loeschen?';

  @override
  String get maps_offline_downloadedRegions => 'Heruntergeladene Regionen';

  @override
  String maps_offline_downloading(Object regionName) {
    return 'Wird heruntergeladen: $regionName';
  }

  @override
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  ) {
    return '$regionName wird heruntergeladen, $percent Prozent abgeschlossen, $downloaded von $total Kacheln';
  }

  @override
  String maps_offline_error(Object error) {
    return 'Fehler: $error';
  }

  @override
  String maps_offline_errorLoadingStats(Object error) {
    return 'Fehler beim Laden der Statistiken: $error';
  }

  @override
  String maps_offline_failedTiles(Object count) {
    return '$count fehlgeschlagen';
  }

  @override
  String maps_offline_hitRate(Object rate) {
    return 'Trefferquote: $rate%';
  }

  @override
  String get maps_offline_lastAccessed => 'Letzter Zugriff';

  @override
  String get maps_offline_noRegions => 'Keine Offline-Regionen';

  @override
  String get maps_offline_noRegionsDescription =>
      'Laden Sie Kartenregionen von der Tauchplatz-Detailseite herunter, um Karten offline zu nutzen.';

  @override
  String get maps_offline_refresh => 'Aktualisieren';

  @override
  String get maps_offline_region => 'Region';

  @override
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size | $count Kacheln | Zoom $minZoom-$maxZoom';
  }

  @override
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size, $count Kacheln, Zoom $minZoom bis $maxZoom';
  }

  @override
  String get maps_offline_size => 'Groesse';

  @override
  String get maps_offline_tiles => 'Kacheln';

  @override
  String maps_offline_tilesPerSecond(Object rate) {
    return '$rate Kacheln/Sek.';
  }

  @override
  String maps_offline_tilesProgress(Object downloaded, Object total) {
    return '$downloaded / $total Kacheln';
  }

  @override
  String get maps_offline_title => 'Offline-Karten';

  @override
  String get maps_offline_zoomRange => 'Zoombereich';

  @override
  String get maps_regionSelector_dragToAdjust =>
      'Ziehen, um die Auswahl anzupassen';

  @override
  String get maps_regionSelector_dragToSelect =>
      'Auf der Karte ziehen, um eine Region auszuwaehlen';

  @override
  String get maps_regionSelector_selectRegion => 'Region auf Karte auswaehlen';

  @override
  String get maps_regionSelector_selectRegionButton => 'Region auswaehlen';

  @override
  String get tankPresets_addPreset => 'Flaschenvorlage hinzufuegen';

  @override
  String get tankPresets_builtInPresets => 'Integrierte Vorlagen';

  @override
  String get tankPresets_customPresets => 'Eigene Vorlagen';

  @override
  String tankPresets_deleteMessage(Object name) {
    return 'Moechten Sie \"$name\" wirklich loeschen?';
  }

  @override
  String get tankPresets_deletePreset => 'Vorlage loeschen';

  @override
  String get tankPresets_deleteTitle => 'Flaschenvorlage loeschen?';

  @override
  String tankPresets_deleted(Object name) {
    return '\"$name\" geloescht';
  }

  @override
  String get tankPresets_editPreset => 'Vorlage bearbeiten';

  @override
  String tankPresets_edit_created(Object name) {
    return '\"$name\" erstellt';
  }

  @override
  String get tankPresets_edit_descriptionHint =>
      'z.B. Meine Leihflasche vom Tauchshop';

  @override
  String get tankPresets_edit_descriptionOptional => 'Beschreibung (optional)';

  @override
  String tankPresets_edit_errorLoading(Object error) {
    return 'Fehler beim Laden der Vorlage: $error';
  }

  @override
  String tankPresets_edit_errorSaving(Object error) {
    return 'Fehler beim Speichern der Vorlage: $error';
  }

  @override
  String tankPresets_edit_gasCapacity(Object capacity) {
    return '- Gaskapazitaet: $capacity cuft';
  }

  @override
  String get tankPresets_edit_material => 'Material';

  @override
  String get tankPresets_edit_name => 'Name';

  @override
  String get tankPresets_edit_nameHelper =>
      'Ein Name fuer diese Flaschenvorlage';

  @override
  String get tankPresets_edit_nameHint => 'z.B. Meine AL80';

  @override
  String get tankPresets_edit_nameRequired => 'Bitte einen Namen eingeben';

  @override
  String get tankPresets_edit_ratedPressure => 'Nenndruck';

  @override
  String get tankPresets_edit_required => 'Erforderlich';

  @override
  String get tankPresets_edit_tankSpecifications => 'Flaschenspezifikationen';

  @override
  String get tankPresets_edit_title => 'Flaschenvorlage bearbeiten';

  @override
  String tankPresets_edit_updated(Object name) {
    return '\"$name\" aktualisiert';
  }

  @override
  String get tankPresets_edit_validPressure => 'Gueltigen Druck eingeben';

  @override
  String get tankPresets_edit_validVolume => 'Gueltiges Volumen eingeben';

  @override
  String get tankPresets_edit_volume => 'Volumen';

  @override
  String get tankPresets_edit_volumeHelperCuft => 'Gaskapazitaet (cuft)';

  @override
  String get tankPresets_edit_volumeHelperLiters => 'Wasservolumen (L)';

  @override
  String tankPresets_edit_waterVolume(Object volume) {
    return '- Wasservolumen: $volume L';
  }

  @override
  String get tankPresets_edit_workingPressure => 'Betriebsdruck';

  @override
  String tankPresets_edit_workingPressureBar(Object pressure) {
    return '- Betriebsdruck: $pressure bar';
  }

  @override
  String tankPresets_error(Object error) {
    return 'Fehler: $error';
  }

  @override
  String tankPresets_errorDeleting(Object error) {
    return 'Fehler beim Loeschen der Vorlage: $error';
  }

  @override
  String get tankPresets_new_title => 'Neue Flaschenvorlage';

  @override
  String get tankPresets_noPresets => 'Keine Flaschenvorlagen verfuegbar';

  @override
  String get tankPresets_title => 'Flaschenvorlagen';

  @override
  String get tools_deco_description =>
      'Berechnen Sie Nullzeitgrenzen, erforderliche Dekostopps und CNS/OTU-Belastung fuer mehrstufige Tauchprofile.';

  @override
  String get tools_deco_subtitle => 'Tauchgaenge mit Dekostopps planen';

  @override
  String get tools_deco_title => 'Deko-Rechner';

  @override
  String get tools_disclaimer =>
      'Diese Rechner dienen nur der Planung. Ueberpruefen Sie die Berechnungen immer und folgen Sie Ihrer Tauchausbildung.';

  @override
  String get tools_gas_description =>
      'Vier spezialisierte Gasrechner:\n- MOD - Maximale Einsatztiefe fuer ein Gasgemisch\n- Best Mix - Idealer O2-Anteil fuer eine Zieltiefe\n- Verbrauch - Gasverbrauchsschaetzung\n- Rock Bottom - Notreserve-Berechnung';

  @override
  String get tools_gas_subtitle => 'MOD, Best Mix, Verbrauch, Rock Bottom';

  @override
  String get tools_gas_title => 'Gasrechner';

  @override
  String get tools_title => 'Werkzeuge';

  @override
  String get tools_weight_aluminumImperial =>
      'Auftriebspositiver wenn leer (+4 lbs)';

  @override
  String get tools_weight_aluminumMetric =>
      'Auftriebspositiver wenn leer (+2 kg)';

  @override
  String get tools_weight_bodyWeightOptional => 'Koerpergewicht (optional)';

  @override
  String get tools_weight_carbonFiberImperial =>
      'Sehr auftriebspositiv (+7 lbs)';

  @override
  String get tools_weight_carbonFiberMetric => 'Sehr auftriebspositiv (+3 kg)';

  @override
  String get tools_weight_description =>
      'Schaetzen Sie das benoetigte Blei basierend auf Tauchanzug, Flaschenmaterial, Wassertyp und Koerpergewicht.';

  @override
  String get tools_weight_disclaimer =>
      'Dies ist nur eine Schaetzung. Fuehren Sie immer einen Tarierungscheck zu Beginn des Tauchgangs durch und passen Sie bei Bedarf an. Faktoren wie Jacket, persoenlicher Auftrieb und Atemverhalten beeinflussen Ihren tatsaechlichen Bleibedarf.';

  @override
  String get tools_weight_exposureSuit => 'Tauchanzug';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return '- Gaskapazitaet: $capacity cuft';
  }

  @override
  String get tools_weight_helperImperial =>
      'Fuegt ca. 2 lbs pro 22 lbs ueber 154 lbs hinzu';

  @override
  String get tools_weight_helperMetric =>
      'Fuegt ca. 1 kg pro 10 kg ueber 70 kg hinzu';

  @override
  String get tools_weight_notSpecified => 'Nicht angegeben';

  @override
  String get tools_weight_recommendedWeight => 'Empfohlenes Gewicht';

  @override
  String tools_weight_resultAccessibility(Object weight, Object unit) {
    return 'Empfohlenes Gewicht: $weight $unit';
  }

  @override
  String get tools_weight_steelImperial => 'Auftriebsnegativ (-4 lbs)';

  @override
  String get tools_weight_steelMetric => 'Auftriebsnegativ (-2 kg)';

  @override
  String get tools_weight_subtitle =>
      'Empfohlenes Gewicht fuer Ihre Konfiguration';

  @override
  String get tools_weight_tankMaterial => 'Flaschenmaterial';

  @override
  String get tools_weight_tankSpecifications => 'Flaschenspezifikationen';

  @override
  String get tools_weight_title => 'Gewichtsrechner';

  @override
  String get tools_weight_waterType => 'Wassertyp';

  @override
  String tools_weight_waterVolume(Object volume) {
    return '- Wasservolumen: $volume L';
  }

  @override
  String tools_weight_workingPressure(Object pressure) {
    return '- Betriebsdruck: $pressure bar';
  }

  @override
  String get tools_weight_yourWeight => 'Ihr Gewicht';
}
