// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get universalImport_action_importFromGarmin =>
      'Von Garmin-Gerät importieren';

  @override
  String diveLog_edit_flightWindowWarning(String time) {
    return 'Dieser Tauchgang endet nach der letzten sicheren Auftauchzeit für deinen Flug ($time)';
  }

  @override
  String diveLog_edit_geofenceSuggestion_near(String location) {
    return 'In der Nähe von $location';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_title => 'Ausrüstungsvorschlag';

  @override
  String diveLog_edit_geofenceSuggestion_body(String setName) {
    return 'Set \"$setName\" übernehmen?';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_apply => 'Übernehmen';

  @override
  String get common_action_dismiss => 'Verwerfen';

  @override
  String get equipment_setEdit_defaultSwitch_title => 'Standard-Set';

  @override
  String get equipment_setEdit_defaultSwitch_subtitle =>
      'Wird automatisch auf neue Tauchgänge ohne Ausrüstung angewendet';

  @override
  String get equipment_setEdit_geofencesTitle => 'Geofences';

  @override
  String get equipment_setEdit_geofencesSubtitle =>
      'Dieses Set automatisch für Tauchgänge in der Nähe dieser Orte vorschlagen';

  @override
  String get equipment_setEdit_addGeofence => 'Geofence hinzufügen';

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
  String get equipment_geofenceEditor_fromSite => 'Vom Tauchplatz';

  @override
  String get equipment_geofenceEditor_dropPin => 'Pin setzen';

  @override
  String get equipment_geofenceEditor_labelLabel => 'Bezeichnung';

  @override
  String get equipment_geofenceEditor_noCenter => 'Mittelpunkt wählen';

  @override
  String get equipment_geofenceEditor_save => 'Geofence speichern';

  @override
  String get equipment_sets_defaultBadge => 'Standard';

  @override
  String get equipment_setDetail_setAsDefault => 'Als Standard festlegen';

  @override
  String equipment_setDetail_setAsDefaultSnackbar(String name) {
    return '\"$name\" ist jetzt dein Standard-Set';
  }

  @override
  String get equipment_setDetail_geofencesTitle => 'Geofences';

  @override
  String get equipment_setDetail_noGeofences => 'Keine Geofences';

  @override
  String formatter_duration_minutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String formatter_duration_minutesSeconds(Object minutes, Object seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String formatter_duration_seconds(Object seconds) {
    return '$seconds s';
  }

  @override
  String gasCalculators_bestMix_densityCritical(Object limit) {
    return 'Uber der harten Dichtegrenze von $limit g/L.';
  }

  @override
  String get gasCalculators_bestMix_densityLabel => 'Gasdichte auf Tiefe';

  @override
  String gasCalculators_bestMix_densityWarn(Object limit) {
    return 'Uber der empfohlenen Dichtegrenze von $limit g/L.';
  }

  @override
  String gasCalculators_bestMix_endExceeded(Object limit) {
    return 'END uberschreitet dein Limit von $limit.';
  }

  @override
  String get gasCalculators_bestMix_endLabel => 'END auf Tiefe';

  @override
  String get gasCalculators_bestMix_endLimitLabel => 'END-Limit';

  @override
  String gasCalculators_bestMix_heliumAdded(Object limit) {
    return 'Helium zugefugt, damit END innerhalb deines Limits von $limit bleibt.';
  }

  @override
  String get gasCalculators_bestMix_idealLabel => 'Idealer Anteil';

  @override
  String get gasCalculators_bestMix_marginLabel => 'Reserve bis MOD';

  @override
  String gasCalculators_bestMix_modLabel(Object ppO2) {
    return 'MOD bei ppO2 $ppO2';
  }

  @override
  String get gasCalculators_bestMix_nearestStandard =>
      'Nachstes Standardgemisch fur diese Tiefe';

  @override
  String get gasCalculators_bestMix_recommendedMix => 'Empfohlenes Gemisch';

  @override
  String get gasCalculators_bestMix_withoutHelium => 'Ohne Helium';

  @override
  String get gasCalculators_planningCaveat =>
      'Planungswert. Setzt einen direkten Aufstieg voraus. Prufe ihn gegen deine Ausbildung und plane Reserve fur die Bedingungen ein.';

  @override
  String gasCalculators_rockBottom_solveGas(Object depth, Object unit) {
    return 'Gas zur Problemlosung auf $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_solveTime => 'Zeit zur Problemlosung';

  @override
  String get gasCalculators_rockBottom_solveTimeHint =>
      'Zeit auf Tiefe, um den Notfall zu losen, bevor der Aufstieg beginnt.';

  @override
  String o2Toxicity_addedThisDive(Object value) {
    return '+$value dieser Tauchgang';
  }

  @override
  String o2Toxicity_cnsProgressSemantics(Object percent) {
    return 'CNS-Fortschritt $percent Prozent';
  }

  @override
  String get o2Toxicity_daily => 'Taglich';

  @override
  String o2Toxicity_otuSemantics(
    Object label,
    Object value,
    Object limit,
    Object percent,
  ) {
    return '$label: $value von $limit OTU, $percent Prozent';
  }

  @override
  String o2Toxicity_otuValueSemantics(Object label, Object value) {
    return '$label: $value OTU';
  }

  @override
  String o2Toxicity_prior(Object value) {
    return 'Vorher: $value OTU';
  }

  @override
  String o2Toxicity_start(Object value) {
    return 'Start: $value OTU';
  }

  @override
  String get o2Toxicity_thisDive => 'Dieser Tauchgang';

  @override
  String get o2Toxicity_weekly => 'Wochentlich';

  @override
  String trips_story_dayLabel(int number) {
    return 'Tag $number';
  }

  @override
  String get trips_story_surfaceDay => 'Oberflächentag';

  @override
  String get trips_story_today => 'Heute';

  @override
  String trips_story_dayOfTrip(int current, int total) {
    return 'Tag $current von $total';
  }

  @override
  String trips_story_daysUntil(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Noch $days Tage bis zur Abreise',
      one: 'Noch 1 Tag bis zur Abreise',
    );
    return '$_temp0';
  }

  @override
  String trips_story_checklistProgress(int done, int total) {
    return '$done von $total erledigt';
  }

  @override
  String get trips_story_generateItinerary => 'Reiseplan erstellen';

  @override
  String get trips_story_openGallery => 'Reisefotos öffnen';

  @override
  String trips_story_generateItineraryError(String error) {
    return 'Reiseplan konnte nicht erstellt werden: $error';
  }

  @override
  String get trips_dayType_diveDay => 'Tauchtag';

  @override
  String get trips_dayType_seaDay => 'Seetag';

  @override
  String get trips_dayType_portDay => 'Hafentag';

  @override
  String get trips_dayType_embark => 'Einschiffung';

  @override
  String get trips_dayType_disembark => 'Ausschiffung';

  @override
  String get trips_story_planned => 'Geplant';

  @override
  String get trips_story_empty_title => 'Noch keine Tauchgänge oder Reiseplan';

  @override
  String get trips_story_empty_subtitle =>
      'Füge Tauchgänge hinzu oder plane die Tage, um die Story zu sehen.';

  @override
  String trips_story_history_dives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frühere Tauchgänge hier',
      one: '1 früherer Tauchgang hier',
    );
    return '$_temp0';
  }

  @override
  String trips_story_history_avgTemp(String value) {
    return 'Ø $value';
  }

  @override
  String trips_story_history_avgDepth(String value) {
    return 'Ø Tiefe $value';
  }

  @override
  String get trips_story_rhythm_semantics => 'Tauchzeiten an diesem Tag';

  @override
  String get trips_story_map_semantics =>
      'Reisekarte. Die Tauchplätze des sichtbaren Tages sind hervorgehoben.';

  @override
  String get diveLog_bulkEdit_groupRebreather => 'Tauchmodus & Kreislaufgerät';

  @override
  String get diveLog_bulkEdit_fieldSetpointLow => 'Sollwert niedrig';

  @override
  String get diveLog_bulkEdit_fieldSetpointHigh => 'Sollwert hoch';

  @override
  String get diveLog_bulkEdit_fieldSetpointDeco => 'Sollwert Deko';

  @override
  String get diveLog_bulkEdit_fieldScrubberType => 'Absorbertyp';

  @override
  String get diveLog_bulkEdit_fieldScrubberDuration => 'Absorberdauer';

  @override
  String get diveLog_bulkEdit_contradiction =>
      'OC-Modus kann keine Kreislaufgerät-Einstellungen haben. Deaktiviere die Felder oder ändere den Modus.';

  @override
  String diveLog_bulkEdit_appBarTitle(int count) {
    return '$count Tauchgänge bearbeiten';
  }

  @override
  String get diveLog_bulkEdit_groupLogistics => 'Logistik';

  @override
  String get diveLog_bulkEdit_groupWeather => 'Wetter';

  @override
  String get diveLog_bulkEdit_groupCollections => 'Tags, Ausrüstung & Leben';

  @override
  String get diveLog_bulkEdit_fieldFavorite => 'Favorit';

  @override
  String get diveLog_bulkEdit_fieldMyRole => 'Meine Rolle';

  @override
  String get diveLog_bulkEdit_buddyRoleMixed => 'Gemischt';

  @override
  String get diveLog_bulkEdit_collectionWeights => 'Gewichte';

  @override
  String get diveLog_bulkEdit_collectionTanks => 'Flaschen';

  @override
  String get diveLog_bulkEdit_notesSet => 'Setzen';

  @override
  String get diveLog_bulkEdit_notesAppend => 'Anhängen';

  @override
  String get diveLog_bulkEdit_modeAdd => 'Hinzufügen';

  @override
  String get diveLog_bulkEdit_modeRemove => 'Entfernen';

  @override
  String get diveLog_bulkEdit_modeReplace => 'Ersetzen';

  @override
  String get diveLog_bulkEdit_modeUpdate => 'Aktualisieren';

  @override
  String get diveLog_bulkEdit_tankOnlyIfEmpty =>
      'Nur Tauchgänge ohne vorhandene Flasche';

  @override
  String get diveLog_bulkEdit_tankSpecsHint =>
      'Wähle aus, welche Eigenschaften der bereits vorhandenen Flaschen überschrieben werden. Anfangs- und Enddruck werden nie geändert.';

  @override
  String get diveLog_bulkEdit_tankSpecsNoFields =>
      'Wähle mindestens eine Flascheneigenschaft zum Aktualisieren.';

  @override
  String get diveLog_bulkEdit_tankFieldPreset => 'Vorlage';

  @override
  String get diveLog_bulkEdit_tankFieldRole => 'Rolle';

  @override
  String get diveLog_bulkEdit_tankFieldVolume => 'Volumen';

  @override
  String get diveLog_bulkEdit_tankFieldWorkingPressure => 'Arbeitsdruck';

  @override
  String get diveLog_bulkEdit_tankFieldMaterial => 'Material';

  @override
  String get diveLog_bulkEdit_tankFieldGasMix => 'Gasgemisch';

  @override
  String get diveLog_bulkEdit_tankFieldName => 'Name';

  @override
  String diveLog_bulkEdit_tankSpecsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count ausgewählte Tauchgänge haben keine Flaschen und werden übersprungen.',
      one: '1 ausgewählter Tauchgang hat keine Flaschen und wird übersprungen.',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_bulkEdit_confirmTitle => 'Änderungen anwenden?';

  @override
  String get diveLog_bulkEdit_confirmApply => 'Anwenden';

  @override
  String get diveLog_bulkEdit_nothingSelected =>
      'Aktiviere mindestens ein Feld, um Änderungen anzuwenden.';

  @override
  String diveLog_bulkEdit_applied(int count) {
    return '$count Tauchgänge aktualisiert';
  }

  @override
  String get settings_cloudSync_error_icloudSignedOut =>
      'iCloud ist nicht verfügbar. Bitte melde dich in den Geräteeinstellungen bei iCloud an.';

  @override
  String get settings_cloudSync_error_icloudUnknown =>
      'iCloud konnte nicht erreicht werden. Bitte versuche es erneut.';

  @override
  String get settings_cloudSync_error_icloudUnsupported =>
      'iCloud-Synchronisierung ist in diesem Build von Submersion nicht verfügbar. Verwende die S3-Synchronisierung oder die App-Store-Version.';

  @override
  String get settings_cloudSync_provider_icloud_unsupportedSubtitle =>
      'In diesem Build nicht verfügbar – verwende S3 oder die App-Store-Version';

  @override
  String get settings_cloudSync_encryption_title =>
      'Ende-zu-Ende-Verschlüsselung';

  @override
  String get settings_cloudSync_encryption_subtitleOff =>
      'Alle Sync-Daten und Cloud-Backups vor dem Hochladen verschlüsseln';

  @override
  String get settings_cloudSync_encryption_subtitleNeedsProvider =>
      'Zuerst einen Cloud-Anbieter auswählen';

  @override
  String get settings_cloudSync_encryption_statusOff =>
      'Verschlüsselung ist aus';

  @override
  String get settings_cloudSync_encryption_statusOn =>
      'Verschlüsselung ist aktiv';

  @override
  String get settings_cloudSync_encryption_statusOnSubtitle =>
      'Sync-Daten und Cloud-Backups werden vor dem Hochladen verschlüsselt';

  @override
  String get settings_cloudSync_encryption_statusLocked =>
      'Verschlüsselt — Passphrase erforderlich';

  @override
  String get settings_cloudSync_encryption_statusLockedSubtitle =>
      'Passphrase eingeben, um auf diesem Gerät zu synchronisieren';

  @override
  String get settings_cloudSync_encryption_enable =>
      'Verschlüsselung aktivieren';

  @override
  String get settings_cloudSync_encryption_enterPassphrase =>
      'Passphrase eingeben';

  @override
  String get settings_cloudSync_encryption_passphrase => 'Passphrase';

  @override
  String get settings_cloudSync_encryption_passphraseConfirm =>
      'Passphrase bestätigen';

  @override
  String get settings_cloudSync_encryption_passphraseMismatch =>
      'Passphrasen stimmen nicht überein';

  @override
  String get settings_cloudSync_encryption_passphraseTooShort =>
      'Mindestens 8 Zeichen verwenden';

  @override
  String get settings_cloudSync_encryption_wrongPassphrase =>
      'Falsche Passphrase oder falscher Wiederherstellungscode';

  @override
  String get settings_cloudSync_encryption_warnUpdateDevices =>
      'Alle anderen Geräte müssen auf die neueste App-Version aktualisiert werden und laden die Bibliothek erneut herunter.';

  @override
  String get settings_cloudSync_encryption_warnLoss =>
      'Gehen Passphrase und Wiederherstellungscode verloren, können die Daten in der Cloud nicht wiederhergestellt werden. Die Daten auf Ihren Geräten sind nie in Gefahr.';

  @override
  String get settings_cloudSync_encryption_deletePlaintextBackups =>
      'Vorhandene unverschlüsselte Cloud-Backups löschen';

  @override
  String get settings_cloudSync_encryption_recoveryTitle =>
      'Wiederherstellungscode';

  @override
  String get settings_cloudSync_encryption_recoveryExplain =>
      'Notieren Sie diesen Code und bewahren Sie ihn sicher auf. Er ist der einzige Weg zurück, falls Sie die Passphrase vergessen.';

  @override
  String get settings_cloudSync_encryption_recoverySavedConfirm =>
      'Ich habe meinen Wiederherstellungscode gespeichert';

  @override
  String get settings_cloudSync_encryption_changePassphrase =>
      'Passphrase ändern';

  @override
  String get settings_cloudSync_encryption_currentPassphrase =>
      'Aktuelle Passphrase';

  @override
  String get settings_cloudSync_encryption_newPassphrase => 'Neue Passphrase';

  @override
  String get settings_cloudSync_encryption_regenerateRecovery =>
      'Neuen Wiederherstellungscode erzeugen';

  @override
  String get settings_cloudSync_encryption_regenerateRecoveryWarn =>
      'Der alte Wiederherstellungscode wird sofort ungültig.';

  @override
  String get settings_cloudSync_encryption_disable =>
      'Verschlüsselung ausschalten';

  @override
  String get settings_cloudSync_encryption_disableWarn =>
      'Die Bibliothek wird unverschlüsselt neu hochgeladen und andere Geräte laden sie erneut herunter. Vorhandene verschlüsselte Backups bleiben mit der Passphrase wiederherstellbar.';

  @override
  String get settings_cloudSync_encryption_unlockTitle =>
      'Verschlüsselungs-Passphrase eingeben';

  @override
  String get settings_cloudSync_encryption_unlockHint =>
      'Passphrase oder Wiederherstellungscode';

  @override
  String get settings_cloudSync_encryption_unlock => 'Entsperren';

  @override
  String get settings_cloudSync_encryption_continue => 'Weiter';

  @override
  String get settings_cloudSync_encryption_done => 'Fertig';

  @override
  String get settings_cloudSync_encryption_cancel => 'Abbrechen';

  @override
  String get settings_backupEncryption_title => 'Backup-Verschlüsselung';

  @override
  String get settings_backupEncryption_subtitleOff =>
      'Schützen Sie Ihre Backups mit einem Passwort';

  @override
  String get settings_backupEncryption_subtitleOn =>
      'Backups werden mit Ihrem Passwort verschlüsselt';

  @override
  String get settings_backupEncryption_enable => 'Backups verschlüsseln';

  @override
  String get settings_backupEncryption_turnOff =>
      'Verschlüsselung deaktivieren';

  @override
  String get settings_backupEncryption_turnOffTitle =>
      'Backup-Verschlüsselung deaktivieren?';

  @override
  String get settings_backupEncryption_turnOffBody =>
      'Neue Backups werden nicht mehr verschlüsselt. Für die Wiederherstellung bestehender verschlüsselter Backups ist weiterhin Ihr Passwort erforderlich.';

  @override
  String get settings_backupEncryption_changePassword => 'Passwort ändern';

  @override
  String get settings_backupEncryption_regenerateRecovery =>
      'Wiederherstellungscode neu generieren';

  @override
  String get settings_backupEncryption_password => 'Passwort';

  @override
  String get settings_backupEncryption_passwordConfirm => 'Passwort bestätigen';

  @override
  String get settings_backupEncryption_passwordTooShort =>
      'Verwenden Sie mindestens 8 Zeichen';

  @override
  String get settings_backupEncryption_passwordMismatch =>
      'Passwörter stimmen nicht überein';

  @override
  String get settings_backupEncryption_currentPassword => 'Aktuelles Passwort';

  @override
  String get settings_backupEncryption_newPassword => 'Neues Passwort';

  @override
  String get settings_backupEncryption_changePasswordWarn =>
      'Auf einem anderen Gerät lässt sich jedes Backup mit dem Passwort oder Wiederherstellungscode öffnen, das bei seiner Erstellung aktiv war.';

  @override
  String get settings_backupEncryption_warnLoss =>
      'Wenn Sie Ihr Passwort vergessen und den Wiederherstellungscode verlieren, können verschlüsselte Backups nicht wiederhergestellt werden.';

  @override
  String get settings_backupEncryption_recoveryTitle =>
      'Ihr Wiederherstellungscode';

  @override
  String get settings_backupEncryption_recoveryExplain =>
      'Bewahren Sie diesen Code an einem sicheren Ort auf. Er kann Ihre Backups entsperren, falls Sie Ihr Passwort vergessen.';

  @override
  String get settings_backupEncryption_recoverySavedConfirm =>
      'Ich habe meinen Wiederherstellungscode gespeichert';

  @override
  String get settings_backupEncryption_unlockTitle =>
      'Backup-Passwort eingeben';

  @override
  String get settings_backupEncryption_unlockHint =>
      'Geben Sie Ihr Backup-Passwort oder Ihren Wiederherstellungscode ein';

  @override
  String get settings_backupEncryption_restoreUnlockTitle =>
      'Verschlüsseltes Backup entsperren';

  @override
  String get settings_backupEncryption_restoreUnlockHint =>
      'Gib das Passwort oder den Wiederherstellungscode für dieses Backup ein';

  @override
  String get settings_backupEncryption_continue => 'Weiter';

  @override
  String get settings_backupEncryption_cancel => 'Abbrechen';

  @override
  String get settings_backupEncryption_done => 'Fertig';

  @override
  String get settings_backupEncryption_reencryptTitle =>
      'Bestehende Backups verschlüsseln?';

  @override
  String get settings_backupEncryption_reencryptBody =>
      'Ihre bestehenden Backups sind noch unverschlüsselt. Jetzt mit Ihrem neuen Passwort neu verschlüsseln?';

  @override
  String get settings_backupEncryption_reencryptNow =>
      'Jetzt neu verschlüsseln';

  @override
  String get settings_backupEncryption_reencryptNotNow => 'Nicht jetzt';

  @override
  String settings_backupEncryption_reencryptPartial(int done, int failed) {
    return '$done Backups neu verschlüsselt; $failed konnten nicht verschlüsselt werden und sind weiterhin ungeschützt';
  }

  @override
  String settings_backupEncryption_reencryptDone(int count) {
    return '$count Backups neu verschlüsselt';
  }

  @override
  String get settings_backupEncryption_wrongPassword =>
      'Falsches Passwort oder falscher Wiederherstellungscode';

  @override
  String settings_cloudSync_replace_globalBanner(String deviceName) {
    return 'Synchronisierung pausiert — die Bibliothek wurde aus einem Backup auf \"$deviceName\" ersetzt.';
  }

  @override
  String get settings_cloudSync_postRestore_syncing =>
      'Wiederhergestellte Bibliothek wird mit der Cloud synchronisiert…';

  @override
  String get settings_cloudSync_postRestore_synced =>
      'Wiederhergestellte Bibliothek synchronisiert.';

  @override
  String get settings_cloudSync_replace_reviewAction => 'Überprüfen';

  @override
  String get accessibility_dialog_keyboardShortcutsTitle =>
      'Tastenkombinationen';

  @override
  String get accessibility_keyLabel_backspace => 'Rücktaste';

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
  String get accessibility_label_resizeMasterPane =>
      'Hauptbereich in der Groesse aendern';

  @override
  String get accessibility_label_sharedWithAllProfiles =>
      'Mit allen Taucherprofilen geteilt';

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
  String get accessibility_shortcut_closeCancel => 'Schließen / Abbrechen';

  @override
  String get accessibility_shortcut_goBack => 'Zurück';

  @override
  String get accessibility_shortcut_goToDives => 'Zu Tauchgängen';

  @override
  String get accessibility_shortcut_goToEquipment => 'Zur Ausrüstung';

  @override
  String get accessibility_shortcut_goToSettings => 'Zu Einstellungen';

  @override
  String get accessibility_shortcut_goToSites => 'Zu Tauchplätzen';

  @override
  String get accessibility_shortcut_goToStatistics => 'Zu Statistiken';

  @override
  String get accessibility_shortcut_keyboardShortcuts => 'Tastenkombinationen';

  @override
  String get accessibility_shortcut_newDive => 'Neuer Tauchgang';

  @override
  String get accessibility_shortcut_openSettings => 'Einstellungen öffnen';

  @override
  String get accessibility_shortcut_searchDives => 'Tauchgänge suchen';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return 'Sortieren nach $displayName, derzeit ausgewählt';
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
  String get backup_export_bottomSheet_title => 'Sicherung exportieren';

  @override
  String get backup_export_saveToFile => 'In Datei speichern';

  @override
  String get backup_export_saveToFile_subtitle =>
      'Wählen Sie, wo die Sicherungsdatei gespeichert werden soll';

  @override
  String get backup_export_share => 'Teilen';

  @override
  String get backup_export_share_subtitle =>
      'Per AirDrop, E-Mail oder andere Apps senden';

  @override
  String get backup_export_subtitle =>
      'Speichern Sie Ihre Tauchdaten in einer Datei';

  @override
  String get backup_export_success => 'Sicherung erfolgreich exportiert';

  @override
  String get backup_export_title => 'Sicherung exportieren';

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
  String get backup_history_pinAction_pin => 'Backup anheften';

  @override
  String get backup_history_pinAction_unpin => 'Backup lösen';

  @override
  String get backup_history_pinError =>
      'Anheftstatus konnte nicht aktualisiert werden.';

  @override
  String backup_history_preMigrationSubtitle(String size) {
    return 'Vor-Migrations-Backup - $size';
  }

  @override
  String get backup_import_invalidFile =>
      'Diese Datei scheint keine gültige Submersion-Sicherung zu sein';

  @override
  String get backup_import_subtitle =>
      'Sicherung von einem beliebigen Speicherort importieren';

  @override
  String get backup_import_title => 'Aus Datei wiederherstellen';

  @override
  String get backup_import_validating => 'Sicherungsdatei wird validiert...';

  @override
  String get backup_location_change => 'Ändern';

  @override
  String get backup_location_default => 'Standardspeicherort';

  @override
  String get backup_location_title => 'Sicherungsort';

  @override
  String get backup_replaceConfirm_confirm => 'Überall ersetzen';

  @override
  String get backup_replaceConfirm_content =>
      'Die Bibliothek auf allen synchronisierten Geräten wird durch dieses Backup ersetzt. Jedes Gerät erstellt zuerst eine Sicherheitskopie seiner aktuellen Daten. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get backup_replaceConfirm_title => 'Bibliothek überall ersetzen?';

  @override
  String get backup_restore_dialog_cancel => 'Abbrechen';

  @override
  String get backup_restore_dialog_modeMerge_subtitle =>
      'Auf diesem Gerät wiederherstellen. Die nächste Synchronisierung führt die wiederhergestellten Daten mit der Cloud-Bibliothek zusammen.';

  @override
  String get backup_restore_dialog_modeMerge_title =>
      'Bei nächster Synchronisierung zusammenführen';

  @override
  String get backup_restore_dialog_modeReplace_subtitle =>
      'Das Backup wird zur Bibliothek auf diesem Gerät, in der Cloud und auf jedem synchronisierten Gerät.';

  @override
  String get backup_restore_dialog_modeReplace_title => 'Überall ersetzen';

  @override
  String get backup_restore_dialog_restore => 'Wiederherstellen';

  @override
  String get backup_restore_dialog_restoreReplace =>
      'Wiederherstellen und überall ersetzen';

  @override
  String get backup_restore_dialog_safetyNote =>
      'Eine Sicherheitskopie Ihrer aktuellen Daten wird automatisch vor der Wiederherstellung erstellt.';

  @override
  String get backup_restore_dialog_title => 'Sicherung Wiederherstellen';

  @override
  String get backup_restore_dialog_warning =>
      'Dies ersetzt ALLE aktuellen Daten durch die Sicherungsdaten. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String backup_restore_safetyReview_progress(int done, int total) {
    return '$done von $total Tauchgängen analysiert';
  }

  @override
  String get backup_restore_safetyReview_skip => 'Überspringen';

  @override
  String get backup_restore_safetyReview_title => 'Sicherheitsprüfung läuft';

  @override
  String get backup_restoreComplete_continue => 'Weiter';

  @override
  String get backup_restoreComplete_description =>
      'Ihre Daten wurden erfolgreich wiederhergestellt. Tippen Sie auf Weiter, um die App mit Ihren wiederhergestellten Daten neu zu laden.';

  @override
  String get backup_restoreComplete_title => 'Wiederherstellung abgeschlossen';

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
  String get backup_section_auto => 'Automatische Sicherungen';

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
  String get buddies_action_addCertification => 'Zertifizierung hinzufügen';

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
  String get buddies_picker_addCustomRole =>
      'Benutzerdefinierte Rolle hinzufügen...';

  @override
  String get buddies_picker_addNew => 'Neuen Tauchpartner hinzufügen';

  @override
  String get buddies_picker_done => 'Fertig';

  @override
  String get buddies_picker_me => 'Ich';

  @override
  String get buddies_picker_noBuddiesFound => 'Keine Tauchpartner gefunden';

  @override
  String get buddies_picker_noBuddiesYet => 'Noch keine Tauchpartner';

  @override
  String get buddies_picker_noRole => 'Keine Rolle';

  @override
  String get buddies_picker_noneSelected => 'Keine Tauchpartner ausgewählt';

  @override
  String get buddies_picker_searchHint => 'Tauchpartner suchen...';

  @override
  String get buddies_picker_selectBuddies => 'Tauchpartner auswählen';

  @override
  String get buddies_picker_selectMyRole => 'Meine Rolle auswählen';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Rolle für $name auswählen';
  }

  @override
  String get buddies_picker_setMyRole => 'Meine Rolle festlegen';

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
  String get buddies_section_certifications => 'Zertifizierungen';

  @override
  String get buddies_certifications_empty => 'Keine Zertifizierungen';

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
  String get buddies_list_selection_closeTooltip => 'Auswahl schließen';

  @override
  String buddies_list_selection_count(int count) {
    return '$count ausgewählt';
  }

  @override
  String get buddies_list_selection_selectAllTooltip => 'Alle auswählen';

  @override
  String get buddies_list_selection_deselectAllTooltip => 'Alle abwählen';

  @override
  String get buddies_list_selection_mergeTooltip =>
      'Ausgewählte zusammenführen';

  @override
  String get buddies_list_selection_deleteTooltip => 'Ausgewählte löschen';

  @override
  String buddies_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchpartner',
      one: 'Tauchpartner',
    );
    return '$count $_temp0 zusammengeführt';
  }

  @override
  String get buddies_list_merge_undo => 'Rückgängig';

  @override
  String get buddies_list_merge_restored =>
      'Zusammenführung rückgängig gemacht';

  @override
  String get buddies_list_bulkDelete_title => 'Tauchpartner löschen';

  @override
  String buddies_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchpartner',
      one: 'Tauchpartner',
    );
    return 'Möchten Sie wirklich $count $_temp0 löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get buddies_list_bulkDelete_cancel => 'Abbrechen';

  @override
  String get buddies_list_bulkDelete_confirm => 'Löschen';

  @override
  String buddies_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchpartner',
      one: 'Tauchpartner',
    );
    return '$count $_temp0 gelöscht';
  }

  @override
  String get buddies_edit_merge_title => 'Tauchpartner zusammenführen';

  @override
  String get buddies_edit_merge_fieldSourceCycleTooltip =>
      'Wert vom nächsten ausgewählten Tauchpartner verwenden';

  @override
  String buddies_edit_merge_fieldSourceLabel(
    String buddyName,
    int current,
    int total,
  ) {
    return 'Von $buddyName ($current/$total)';
  }

  @override
  String get buddies_edit_merge_confirmTitle => 'Tauchpartner zusammenführen';

  @override
  String buddies_edit_merge_confirmBody(int count) {
    return 'Dabei werden $count Tauchpartner zu einem zusammengeführt. Tauchgangverknüpfungen werden beim verbleibenden Tauchpartner zusammengefasst. Die anderen Tauchpartner werden gelöscht.';
  }

  @override
  String get buddies_edit_merge_loadingErrorTitle =>
      'Tauchpartner zusammenführen';

  @override
  String buddies_edit_merge_loadingErrorBody(String error) {
    return 'Tauchpartner konnten nicht geladen werden: $error';
  }

  @override
  String get buddies_edit_merge_notEnoughTitle => 'Tauchpartner zusammenführen';

  @override
  String get buddies_edit_merge_notEnoughBody =>
      'Nicht genügend Tauchpartner zum Zusammenführen.';

  @override
  String get buddies_instructorPicker_label => 'Tauchlehrer aus Tauchpartnern';

  @override
  String get buddies_instructorPicker_none => 'Keiner (manuelle Eingabe)';

  @override
  String get certifications_appBar_addCertification =>
      'Zertifizierung hinzufügen';

  @override
  String get certifications_appBar_certificationWallet =>
      'Zertifizierungskarten';

  @override
  String get certifications_appBar_editCertification =>
      'Zertifizierung bearbeiten';

  @override
  String get certifications_appBar_title => 'Zertifizierungen';

  @override
  String get certifications_detail_action_delete => 'Löschen';

  @override
  String get certifications_detail_appBar_title => 'Zertifizierung';

  @override
  String get certifications_detail_courseCompleted => 'Abgeschlossen';

  @override
  String get certifications_detail_courseInProgress => 'In Bearbeitung';

  @override
  String get certifications_detail_dialog_cancel => 'Abbrechen';

  @override
  String get certifications_detail_dialog_deleteConfirm => 'Löschen';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return 'Sind Sie sicher, dass Sie \"$name\" löschen möchten?';
  }

  @override
  String get certifications_detail_dialog_deleteTitle =>
      'Zertifizierung löschen?';

  @override
  String get certifications_detail_label_agency => 'Verband';

  @override
  String get certifications_detail_label_cardNumber => 'Kartennummer';

  @override
  String get certifications_detail_label_certification => 'Zertifizierung';

  @override
  String get certifications_detail_label_expiryDate => 'Ablaufdatum';

  @override
  String get certifications_detail_label_instructorName => 'Name';

  @override
  String get certifications_detail_label_instructorNumber => 'Instructor-Nr.';

  @override
  String get certifications_detail_label_issueDate => 'Ausstellungsdatum';

  @override
  String get certifications_detail_label_type => 'Typ';

  @override
  String get certifications_detail_label_validity => 'Gültigkeit';

  @override
  String get certifications_detail_noExpiration => 'Kein Ablaufdatum';

  @override
  String get certifications_detail_notFound => 'Zertifizierung nicht gefunden';

  @override
  String get certifications_detail_photoLabel_back => 'Rückseite';

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
      'Zertifizierung gelöscht';

  @override
  String get certifications_detail_status_expired =>
      'Diese Zertifizierung ist abgelaufen';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return 'Abgelaufen am $date';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return 'Läuft in $days Tagen ab';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return 'Läuft ab am $date';
  }

  @override
  String get certifications_detail_tooltip_edit => 'Zertifizierung bearbeiten';

  @override
  String get certifications_detail_tooltip_editShort => 'Bearbeiten';

  @override
  String get certifications_detail_tooltip_moreOptions => 'Weitere Optionen';

  @override
  String get certifications_ecardStack_empty_subtitle =>
      'Fügen Sie Ihre erste Zertifizierung hinzu, um sie hier zu sehen';

  @override
  String get certifications_ecardStack_empty_title =>
      'Noch keine Zertifizierungen';

  @override
  String get certifications_ecard_label_cardNumber => 'KARTEN-NR.';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Zertifiziert von $agency';
  }

  @override
  String get certifications_ecard_label_diver => 'TAUCHER';

  @override
  String get certifications_ecard_label_instructor => 'INSTRUCTOR';

  @override
  String get certifications_ecard_label_issued => 'AUSGESTELLT';

  @override
  String get certifications_ecard_label_validUntil => 'GÜLTIG BIS';

  @override
  String get certifications_ecard_statusBadge_expired => 'ABGELAUFEN';

  @override
  String get certifications_ecard_statusBadge_expiring => 'LÄUFT AB';

  @override
  String get certifications_edit_appBar_add => 'Zertifizierung hinzufügen';

  @override
  String get certifications_edit_appBar_edit => 'Zertifizierung bearbeiten';

  @override
  String get certifications_edit_button_add => 'Zertifizierung hinzufügen';

  @override
  String get certifications_edit_button_cancel => 'Abbrechen';

  @override
  String get certifications_edit_button_save => 'Speichern';

  @override
  String get certifications_edit_button_update =>
      'Zertifizierung aktualisieren';

  @override
  String get certifications_edit_certification_notSpecified =>
      'Nicht angegeben';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return '$label löschen';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect =>
      'Zum Auswählen tippen';

  @override
  String get certifications_edit_dialog_discard => 'Verwerfen';

  @override
  String get certifications_edit_dialog_discardContent =>
      'Sie haben ungespeicherte Änderungen. Sind Sie sicher, dass Sie die Seite verlassen möchten?';

  @override
  String get certifications_edit_dialog_discardTitle => 'Änderungen verwerfen?';

  @override
  String get certifications_edit_dialog_keepEditing => 'Weiter bearbeiten';

  @override
  String get certifications_edit_group_progression => 'Ausbildungsstufen';

  @override
  String get certifications_edit_group_specialties => 'Spezialkurse';

  @override
  String get certifications_edit_help_expiryDate =>
      'Leer lassen für Zertifizierungen ohne Ablaufdatum';

  @override
  String get certifications_edit_helper_nameOnCard => 'Optional';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Kartennummer der Zertifizierung eingeben';

  @override
  String get certifications_edit_hint_instructorName =>
      'Name des zertifizierenden Instructors';

  @override
  String get certifications_edit_hint_instructorNumber =>
      'Instructor-Zertifizierungsnummer';

  @override
  String get certifications_edit_hint_notes => 'Zusätzliche Notizen';

  @override
  String get certifications_edit_label_agency => 'Verband *';

  @override
  String get certifications_edit_label_cardNumber => 'Kartennummer';

  @override
  String get certifications_edit_label_certification => 'Zertifizierung';

  @override
  String get certifications_edit_label_expiryDate => 'Ablaufdatum';

  @override
  String get certifications_edit_label_instructorName => 'Instructor-Name';

  @override
  String get certifications_edit_label_instructorNumber => 'Instructor-Nummer';

  @override
  String get certifications_edit_label_issueDate => 'Ausstellungsdatum';

  @override
  String get certifications_edit_label_nameOnCard => 'Name auf der Karte';

  @override
  String get certifications_edit_label_notes => 'Notizen';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return '$label-Foto hinzufügen. Tippen Sie zum Auswählen';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return '$label-Foto angehängt. Tippen Sie zum Ändern';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery =>
      'Aus Galerie auswählen';

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
      'Zertifizierung erfolgreich hinzugefügt';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return 'Fehler beim Laden der Zertifizierung: $error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return 'Fehler beim Auswählen des Fotos: $error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return 'Fehler beim Speichern der Zertifizierung: $error';
  }

  @override
  String get certifications_edit_snackBar_updated =>
      'Zertifizierung erfolgreich aktualisiert';

  @override
  String get certifications_edit_validation_certificationOrNameRequired =>
      'Wählen Sie eine Zertifizierung oder geben Sie einen Namen ein';

  @override
  String get certifications_list_button_retry => 'Erneut versuchen';

  @override
  String get certifications_list_empty_button =>
      'Erste Zertifizierung hinzufügen';

  @override
  String get certifications_list_empty_subtitle =>
      'Fügen Sie Ihre Tauchzertifizierungen hinzu, um\nIhre Ausbildung und Qualifikationen zu verfolgen';

  @override
  String get certifications_list_empty_title =>
      'Noch keine Zertifizierungen hinzugefügt';

  @override
  String certifications_list_error_loading(Object error) {
    return 'Fehler beim Laden der Zertifizierungen: $error';
  }

  @override
  String get certifications_list_fab_addCertification =>
      'Zertifizierung hinzufügen';

  @override
  String get certifications_list_section_expired => 'Abgelaufen';

  @override
  String get certifications_list_section_expiringSoon => 'Läuft bald ab';

  @override
  String get certifications_list_section_valid => 'Gültig';

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
      'Zertifizierung hinzufügen';

  @override
  String get certifications_list_tooltip_search =>
      'Zertifizierungen durchsuchen';

  @override
  String get certifications_list_tooltip_sort => 'Sortieren';

  @override
  String get certifications_list_tooltip_walletView => 'Kartenansicht';

  @override
  String get certifications_picker_clearTooltip =>
      'Zertifizierungsauswahl löschen';

  @override
  String get certifications_picker_empty_addButton =>
      'Zertifizierung hinzufügen';

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
      'Tippen, um mit einer erworbenen Zertifizierung zu verknüpfen';

  @override
  String get certifications_picker_newCert => 'Neue Zertifizierung';

  @override
  String get certifications_picker_noSelection =>
      'Keine Zertifizierung ausgewählt';

  @override
  String get certifications_picker_sheetTitle =>
      'Mit Zertifizierung verknüpfen';

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
    return 'Keine Zertifizierungen gefunden für \"$query\"';
  }

  @override
  String get certifications_search_tooltip_back => 'Zurück';

  @override
  String get certifications_search_tooltip_clear => 'Suche löschen';

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
      'Wählen Sie eine Zertifizierung aus der Liste, um Details anzuzeigen';

  @override
  String get certifications_summary_header_title => 'Zertifizierungen';

  @override
  String get certifications_summary_overview_title => 'Übersicht';

  @override
  String get certifications_summary_quickActions_add =>
      'Zertifizierung hinzufügen';

  @override
  String get certifications_summary_quickActions_title => 'Schnellaktionen';

  @override
  String get certifications_summary_recentTitle => 'Neueste Zertifizierungen';

  @override
  String get certifications_summary_stat_expired => 'Abgelaufen';

  @override
  String get certifications_summary_stat_expiringSoon => 'Läuft bald ab';

  @override
  String get certifications_summary_stat_total => 'Gesamt';

  @override
  String get certifications_summary_stat_valid => 'Gültig';

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
  String get certifications_wallet_tooltip_add => 'Zertifizierung hinzufügen';

  @override
  String get certifications_wallet_tooltip_share => 'Zertifizierung teilen';

  @override
  String get checklists_section_title => 'Checkliste';

  @override
  String checklists_progress(int done, int total) {
    return '$done von $total Aufgaben erledigt';
  }

  @override
  String get checklists_empty_upcoming =>
      'Planen Sie Ihre Reise - fügen Sie Aufgaben hinzu oder wenden Sie eine Vorlage an';

  @override
  String get checklists_empty_past => 'Keine Checklisteneinträge';

  @override
  String get checklists_addItem => 'Eintrag hinzufügen';

  @override
  String get checklists_item_titleLabel => 'Titel';

  @override
  String get checklists_item_titleRequired => 'Titel ist erforderlich';

  @override
  String get checklists_item_categoryLabel => 'Kategorie';

  @override
  String get checklists_item_notesLabel => 'Notizen';

  @override
  String get checklists_item_dueDateLabel => 'Fälligkeitsdatum';

  @override
  String get checklists_item_dueOffsetLabel => 'Tage vor Reisebeginn';

  @override
  String get checklists_item_dueOffsetInvalid =>
      'Geben Sie 0 oder mehr Tage ein';

  @override
  String get checklists_item_overdue => 'Überfällig';

  @override
  String get checklists_item_edit => 'Eintrag bearbeiten';

  @override
  String get checklists_item_delete => 'Eintrag löschen';

  @override
  String get checklists_menu_applyTemplate => 'Vorlage anwenden...';

  @override
  String get checklists_menu_saveAsTemplate => 'Als Vorlage speichern...';

  @override
  String get checklists_applySheet_title => 'Vorlage anwenden';

  @override
  String get checklists_applySheet_empty =>
      'Noch keine Vorlagen vorhanden. Erstellen Sie sie in den Einstellungen.';

  @override
  String checklists_applySheet_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String checklists_applySheet_confirmAppend(int added, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added Einträge werden hinzugefügt',
      one: '1 Eintrag wird hinzugefügt',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped Duplikate übersprungen',
      one: '1 Duplikat übersprungen',
      zero: 'keine Duplikate übersprungen',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String checklists_apply_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge hinzugefügt',
      one: '1 Eintrag hinzugefügt',
      zero: 'Keine neuen Einträge hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String get checklists_apply_templateGone => 'Vorlage existiert nicht mehr';

  @override
  String get checklists_saveTemplate_title => 'Als Vorlage speichern';

  @override
  String get checklists_saveTemplate_nameLabel => 'Vorlagenname';

  @override
  String get checklists_saveTemplate_success => 'Vorlage gespeichert';

  @override
  String get checklists_templates_pageTitle => 'Checklistenvorlagen';

  @override
  String get checklists_templates_addTemplate => 'Vorlage hinzufügen';

  @override
  String get checklists_templates_empty => 'Noch keine Vorlagen vorhanden';

  @override
  String get checklists_templates_deleteTitle => 'Vorlage löschen';

  @override
  String checklists_templates_deleteContent(Object name) {
    return '\"$name\" löschen? Reisen, die sie bereits angewendet haben, behalten ihre Einträge.';
  }

  @override
  String get checklists_template_nameLabel => 'Name';

  @override
  String get checklists_template_nameRequired => 'Name ist erforderlich';

  @override
  String get checklists_template_descriptionLabel => 'Beschreibung';

  @override
  String get checklists_template_itemsHeader => 'Einträge';

  @override
  String get checklists_template_addItem => 'Eintrag hinzufügen';

  @override
  String get preDive_templates_title => 'Checklisten vor dem Tauchgang';

  @override
  String get preDive_templates_empty =>
      'Noch keine Checklisten vor dem Tauchgang';

  @override
  String get preDive_templates_builtInBadge => 'Integriert';

  @override
  String get preDive_templates_clone => 'Duplizieren';

  @override
  String get preDive_templates_cloneSuffix => ' (Kopie)';

  @override
  String get preDive_templates_delete => 'Löschen';

  @override
  String get preDive_templates_deleteConfirm =>
      'Diese Checklisten-Vorlage löschen?';

  @override
  String get preDive_templates_strictOrderBadge => 'Feste Reihenfolge';

  @override
  String get preDive_edit_titleNew => 'Neue Checkliste vor dem Tauchgang';

  @override
  String get preDive_edit_titleEdit =>
      'Checkliste vor dem Tauchgang bearbeiten';

  @override
  String get preDive_edit_name => 'Name';

  @override
  String get preDive_edit_description => 'Beschreibung';

  @override
  String get preDive_edit_category => 'Kategorie';

  @override
  String get preDive_edit_strictOrder => 'Feste Reihenfolge';

  @override
  String get preDive_edit_strictOrderHelp =>
      'Einträge müssen von oben nach unten abgearbeitet werden';

  @override
  String get preDive_edit_addItem => 'Eintrag hinzufügen';

  @override
  String get preDive_edit_nameRequired => 'Namen eingeben';

  @override
  String get preDive_item_title => 'Titel';

  @override
  String get preDive_item_section => 'Abschnitt';

  @override
  String get preDive_item_notes => 'Notizen';

  @override
  String get preDive_item_required => 'Erforderlich';

  @override
  String get preDive_item_type_check => 'Kontrollkästchen';

  @override
  String get preDive_item_type_value => 'Erfasster Wert';

  @override
  String get preDive_item_type_equipmentSet =>
      'Einträge aus dem Ausrüstungsset';

  @override
  String get preDive_item_valueLabel => 'Wertbezeichnung';

  @override
  String get preDive_item_valueUnit => 'Einheit';

  @override
  String get preDive_item_valueMin => 'Min. (Warnung)';

  @override
  String get preDive_item_valueMax => 'Max. (Warnung)';

  @override
  String preDive_runner_progress(int done, int total) {
    return '$done von $total';
  }

  @override
  String get preDive_runner_complete => 'Abschließen';

  @override
  String preDive_runner_completeFlagged(int count) {
    return 'Mit $count markierten Einträgen abschließen?';
  }

  @override
  String get preDive_runner_abort => 'Checkliste abbrechen';

  @override
  String get preDive_runner_abortConfirm =>
      'Diese Checkliste abbrechen? Sie wird im Verlauf als abgebrochen gespeichert.';

  @override
  String get preDive_runner_skip => 'Überspringen';

  @override
  String get preDive_runner_flag => 'Markieren';

  @override
  String get preDive_runner_undo => 'Auf ausstehend zurücksetzen';

  @override
  String get preDive_runner_serviceOverdue => 'Wartung überfällig';

  @override
  String get preDive_runner_addNote => 'Notiz hinzufügen';

  @override
  String get preDive_runner_enterValue => 'Wert eingeben';

  @override
  String preDive_runner_flaggedBadge(int count) {
    return '$count markiert';
  }

  @override
  String get preDive_runner_locked => 'Diese Checkliste ist gesperrt';

  @override
  String get preDive_sessions_title => 'Checklisten vor dem Tauchgang';

  @override
  String get preDive_sessions_empty => 'Noch keine Checklisten-Durchläufe';

  @override
  String get preDive_sessions_resume => 'Fortsetzen';

  @override
  String get preDive_sessions_start => 'Checkliste starten';

  @override
  String get preDive_sessions_statusCompleted => 'Abgeschlossen';

  @override
  String get preDive_sessions_statusAborted => 'Abgebrochen';

  @override
  String get preDive_sessions_statusInProgress => 'In Bearbeitung';

  @override
  String get preDive_sessions_linkedDive => 'Verknüpfter Tauchgang';

  @override
  String get preDive_link_linkToDive => 'Mit Tauchgang verknüpfen';

  @override
  String get preDive_link_unlinkDive => 'Tauchgang trennen';

  @override
  String get preDive_link_linkChecklist => 'Checkliste verknüpfen';

  @override
  String get preDive_link_unlinkChecklist => 'Checkliste trennen';

  @override
  String get preDive_link_searchDives => 'Tauchgänge suchen';

  @override
  String get preDive_link_noDives => 'Keine Tauchgänge zum Verknüpfen';

  @override
  String preDive_link_noDivesMatch(String query) {
    return 'Keine Tauchgänge für „$query“';
  }

  @override
  String get preDive_link_noUnlinkedSessions =>
      'Keine unverknüpften Checklisten-Durchläufe';

  @override
  String get preDive_link_linked => 'Checkliste mit diesem Tauchgang verknüpft';

  @override
  String get preDive_link_unlinked =>
      'Checkliste von diesem Tauchgang getrennt';

  @override
  String get preDive_sessions_delete => 'Löschen';

  @override
  String get preDive_sessions_deleteConfirm =>
      'Diesen Checklisten-Eintrag löschen?';

  @override
  String get preDive_sessions_filter => 'Filtern';

  @override
  String get preDive_sessions_filterTitle => 'Checklisten-Durchläufe filtern';

  @override
  String get preDive_sessions_filterChecklist => 'Checkliste';

  @override
  String get preDive_sessions_filterStatus => 'Status';

  @override
  String get preDive_sessions_filterFlaggedOnly => 'Nur markierte Durchläufe';

  @override
  String get preDive_sessions_filterDateRange => 'Zeitraum';

  @override
  String get preDive_sessions_filterAnyDate => 'Beliebiges Datum';

  @override
  String get preDive_sessions_filterClearAll => 'Alle zurücksetzen';

  @override
  String get preDive_sessions_filterApply => 'Anwenden';

  @override
  String get preDive_sessions_filterFlaggedChip => 'Nur markierte';

  @override
  String get preDive_sessions_emptyFiltered =>
      'Keine Checklisten-Durchläufe entsprechen diesen Filtern';

  @override
  String get preDive_sessions_export => 'Nach Excel exportieren';

  @override
  String get preDive_sessions_exportEmpty =>
      'Keine Checklisten-Durchläufe zum Exportieren';

  @override
  String preDive_sessions_exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get preDive_start_title => 'Checkliste vor dem Tauchgang starten';

  @override
  String get preDive_start_template => 'Checkliste';

  @override
  String get preDive_start_equipmentSet => 'Ausrüstungsset';

  @override
  String get preDive_start_noEquipmentSet => 'Keines';

  @override
  String get preDive_start_begin => 'Beginnen';

  @override
  String get diveLog_listPage_bottomSheet_preDiveChecklist =>
      'Checkliste vor dem Tauchgang starten';

  @override
  String get preDive_dashboard_title => 'Check vor dem Tauchgang';

  @override
  String preDive_dashboard_resume(int done, int total) {
    return 'Fortsetzen - $done von $total';
  }

  @override
  String get preDive_dashboard_start => 'Check vor dem Tauchgang starten';

  @override
  String get trips_detail_preDive_action => 'Checkliste vor dem Tauchgang';

  @override
  String get settings_manage_preDiveChecklists =>
      'Checklisten vor dem Tauchgang';

  @override
  String get settings_manage_preDiveChecklists_subtitle =>
      'Buddy-Checks, CCR-Aufbaulisten, Ausrüstungspacken';

  @override
  String get common_action_back => 'Zurück';

  @override
  String get common_action_cancel => 'Abbrechen';

  @override
  String get common_action_close => 'Schließen';

  @override
  String get common_action_continue => 'Fortfahren';

  @override
  String get common_action_delete => 'Löschen';

  @override
  String get common_action_edit => 'Bearbeiten';

  @override
  String get common_action_ok => 'OK';

  @override
  String get common_action_save => 'Speichern';

  @override
  String get common_action_search => 'Suchen';

  @override
  String get common_action_share => 'Teilen';

  @override
  String get common_label_error => 'Fehler';

  @override
  String get common_label_loading => 'Wird geladen';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get common_error_tryAgain =>
      'Etwas ist schiefgelaufen. Bitte erneut versuchen.';

  @override
  String get courses_action_add => 'Kurs hinzufügen';

  @override
  String get courses_action_addFromTemplate => 'Aus Vorlage hinzufügen';

  @override
  String get courses_action_addRequirement => 'Anforderung hinzufügen';

  @override
  String get courses_action_create => 'Kurs erstellen';

  @override
  String get courses_action_deleteRequirement => 'Anforderung löschen';

  @override
  String get courses_action_edit => 'Kurs bearbeiten';

  @override
  String get courses_action_editRequirement => 'Anforderung bearbeiten';

  @override
  String get courses_action_exportTrainingLog =>
      'Ausbildungsprotokoll exportieren';

  @override
  String get courses_action_linkDive => 'Verknüpfen';

  @override
  String get courses_action_markCompleted => 'Als abgeschlossen markieren';

  @override
  String get courses_action_unlinkDive => 'Tauchgang trennen';

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
  String courses_requirement_diveProgress(int count, int target) {
    return '$count von $target Tauchgängen';
  }

  @override
  String get courses_requirement_field_name => 'Name';

  @override
  String get courses_requirement_field_targetCount =>
      'Erforderliche Tauchgänge';

  @override
  String get courses_requirement_kind_checklist => 'Checklistenpunkt';

  @override
  String get courses_requirement_kind_dive => 'Tauchgangsanforderung';

  @override
  String get courses_requirement_suggestions => 'Vorgeschlagene Tauchgänge';

  @override
  String get courses_requirements_empty =>
      'Verfolgen Sie Adventure-Tauchgänge, Voraussetzungen und Checklistenpunkte für diesen Kurs.';

  @override
  String courses_requirements_progress(int satisfied, int total) {
    return '$satisfied von $total abgeschlossen';
  }

  @override
  String get courses_section_details => 'Kursdetails';

  @override
  String get courses_section_earnedCertification => 'Erworbene Zertifizierung';

  @override
  String get courses_section_instructor => 'Tauchlehrer';

  @override
  String get courses_section_notes => 'Notizen';

  @override
  String get courses_section_requirements => 'Anforderungen';

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
  String courses_template_addsCount(int count) {
    return 'Fügt $count Anforderungen hinzu';
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
  String get dashboard_activeCourses_title => 'Laufende Kurse';

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
    return 'Tauchgänge in $year';
  }

  @override
  String get dashboard_activity_divesThisMonth => 'Tauchgänge diesen Monat';

  @override
  String get dashboard_activity_error => 'Fehler';

  @override
  String get dashboard_activity_lastDive => 'Letzter Tauchgang';

  @override
  String get dashboard_activity_loading => 'Wird geladen';

  @override
  String get dashboard_activity_noDivesYet => 'Noch keine Tauchgänge';

  @override
  String get dashboard_activity_today => 'Heute!';

  @override
  String get dashboard_alerts_actionUpdate => 'Aktualisieren';

  @override
  String get dashboard_alerts_actionView => 'Anzeigen';

  @override
  String get dashboard_alerts_checkInsuranceExpiry =>
      'Prüfen Sie Ihr Versicherungsablaufdatum';

  @override
  String get dashboard_alerts_daysOverdueOne => '1 Tag überfällig';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return '$count Tage überfällig';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => 'Fällig in 1 Tag';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return 'Fällig in $count Tagen';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return '$name Wartung fällig';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return '$name Wartung überfällig';
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
    return 'Läuft ab am $date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon =>
      'Versicherung läuft bald ab';

  @override
  String get dashboard_alerts_sectionTitle => 'Hinweise & Erinnerungen';

  @override
  String get dashboard_alerts_serviceDueToday => 'Wartung heute fällig';

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
    return '$count Tauchgänge protokolliert';
  }

  @override
  String get dashboard_hero_divesTotalOne => '1 Tauchgang';

  @override
  String dashboard_hero_divesTotalOther(Object count) {
    return '$count Tauchgänge';
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
  String get dashboard_hero_divesLoggedLabel => 'Tauchgänge';

  @override
  String get dashboard_hero_hoursUnderwaterLabel => 'Stunden unter Wasser';

  @override
  String get dashboard_hero_daysSinceLabel => 'Tage seit letztem Tauchgang';

  @override
  String get dashboard_hero_thisMonthLabel => 'diesen Monat';

  @override
  String get dashboard_hero_thisYearLabel => 'Tauchgänge dieses Jahr';

  @override
  String get dashboard_hero_todayLabel => 'Heute!';

  @override
  String get dashboard_hero_noDivesLabel => 'Noch keine Tauchgänge';

  @override
  String get dashboard_hero_diverFallbackName => 'Taucher';

  @override
  String get dashboard_hero_statDives => 'Tauchgänge';

  @override
  String get dashboard_hero_statHours => 'Stunden';

  @override
  String get dashboard_hero_statSites => 'Tauchplätze';

  @override
  String get dashboard_hero_statCountries => 'Länder';

  @override
  String dashboard_activityStats_divesInYear(String year) {
    return 'Tauchgänge in $year';
  }

  @override
  String get dashboard_semantics_statsBar => 'Tauchstatistik-Zusammenfassung';

  @override
  String get dashboard_gauges_addGear => 'Ausrüstung hinzufügen';

  @override
  String dashboard_gauges_gearOk(String name) {
    return '$name OK';
  }

  @override
  String dashboard_gauges_gearDueIn(String name, int days) {
    return '$name fällig in ${days}T';
  }

  @override
  String dashboard_gauges_gearOverdue(String name) {
    return '$name überfällig';
  }

  @override
  String get dashboard_gauges_insuranceOk => 'Versicherung OK';

  @override
  String dashboard_gauges_insuranceExpires(String date) {
    return 'Versicherung läuft am $date ab';
  }

  @override
  String get dashboard_gauges_insuranceExpired => 'Versicherung abgelaufen';

  @override
  String get dashboard_gauges_noInsurance => 'Keine Versicherung hinterlegt';

  @override
  String get dashboard_gauges_noFlyClear => 'Flugverbot 0:00';

  @override
  String dashboard_gauges_flightWindow(String hours, String minutes) {
    return 'Tauchfenster $hours:$minutes';
  }

  @override
  String get dashboard_gauges_flightWindowClosed =>
      'Kein Tauchen mehr vor dem Flug';

  @override
  String dashboard_gauges_noFlyRemaining(String hours, String minutes) {
    return 'Flugverbot $hours:$minutes';
  }

  @override
  String dashboard_gauges_lastDiveDays(int days) {
    return 'Letzter Tauchgang vor ${days}T';
  }

  @override
  String get dashboard_gauges_lastDiveToday => 'Heute getaucht';

  @override
  String get dashboard_gauges_noDivesYet => 'Noch keine Tauchgänge';

  @override
  String get settings_homeChips_pageTitle => 'Startbildschirm';

  @override
  String get settings_homeChips_description =>
      'Wähle, welche Status-Chips oben im Start-Tab erscheinen.';

  @override
  String get settings_homeChips_sectionTitle => 'Status-Chips';

  @override
  String get settings_homeCards_sectionTitle => 'Startseiten-Karten';

  @override
  String get settings_homeCards_description =>
      'Wähle, welche Karten im Start-Tab erscheinen, und ziehe sie in die gewünschte Reihenfolge.';

  @override
  String get settings_homeCards_autoHides =>
      'Wird automatisch ausgeblendet, wenn leer';

  @override
  String get settings_homeCards_resetToDefault => 'Auf Standard zurücksetzen';

  @override
  String get settings_homeCards_resetDialog_title =>
      'Start-Layout zurücksetzen?';

  @override
  String get settings_homeCards_resetDialog_message =>
      'Stellt die Standardreihenfolge der Karten wieder her und zeigt alle Karten wieder an.';

  @override
  String get settings_homeCards_resetDialog_cancel => 'Abbrechen';

  @override
  String get settings_homeCards_resetDialog_confirm => 'Zurücksetzen';

  @override
  String get settings_homeCards_card_hero => 'Begrüßungsbereich';

  @override
  String get settings_homeCards_card_gaugeStrip => 'Status-Chips';

  @override
  String get settings_homeCards_card_preDive => 'Pre-Dive-Checkliste';

  @override
  String get settings_homeCards_card_recentDives => 'Letzte Tauchgänge';

  @override
  String get settings_homeCards_card_quickActions => 'Schnellaktionen';

  @override
  String get settings_homeCards_card_milestones => 'Meilensteine';

  @override
  String get settings_homeCards_card_photoRibbon => 'Aktuelle Medien';

  @override
  String get settings_homeCards_card_onThisDay => 'An diesem Tag';

  @override
  String get settings_homeCards_card_yearInReview => 'Jahresrückblick';

  @override
  String get settings_homeCards_card_activeCourses => 'Kursfortschritt';

  @override
  String get settings_homeCards_card_recentSitesMap =>
      'Karte der letzten Tauchplätze';

  @override
  String get dashboard_allHidden_message =>
      'Alle Startseiten-Karten sind ausgeblendet.';

  @override
  String get dashboard_allHidden_customize => 'Startseite anpassen';

  @override
  String get settings_homeChips_flightWindow => 'Tauchfenster vor dem Flug';

  @override
  String get settings_homeChips_gear => 'Ausrüstungswartung';

  @override
  String get settings_homeChips_insurance => 'Versicherung';

  @override
  String get settings_homeChips_noFly => 'Flugverbots-Timer';

  @override
  String get settings_homeChips_lastDive => 'Tauchaktualität';

  @override
  String get settings_homeChips_certifications => 'Ablauf von Zertifizierungen';

  @override
  String get settings_homeChips_trip => 'Anstehende Reise';

  @override
  String get settings_homeChips_checklist => 'Aktive Checkliste';

  @override
  String get settings_homeChips_course => 'Kursfortschritt';

  @override
  String get settings_homeChips_uploads => 'Medien-Uploads';

  @override
  String get settings_homeChips_backup => 'Backup-Alter';

  @override
  String get settings_homeChips_sync => 'Synchronisierungsstatus';

  @override
  String get settings_homeChips_dataQuality => 'Datenqualität';

  @override
  String dashboard_gauges_certsExpiring(int count) {
    return '$count Zertifizierungen laufen ab';
  }

  @override
  String dashboard_gauges_tripCountdown(String name, int days) {
    return '$name in ${days}T';
  }

  @override
  String get dashboard_gauges_checklistActive => 'Checkliste in Bearbeitung';

  @override
  String dashboard_gauges_courseProgress(String name, int done, int total) {
    return '$name: $done/$total';
  }

  @override
  String dashboard_gauges_uploadsPending(int count) {
    return '$count Uploads ausstehend';
  }

  @override
  String get dashboard_gauges_backupNone => 'Noch kein Backup';

  @override
  String get dashboard_gauges_backupToday => 'Heute gesichert';

  @override
  String dashboard_gauges_backupDays(int days) {
    return 'Backup vor ${days}T';
  }

  @override
  String dashboard_gauges_syncPending(int count) {
    return '$count nicht synchronisiert';
  }

  @override
  String get dashboard_gauges_synced => 'Synchronisiert';

  @override
  String dashboard_gauges_dataIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Datenprobleme',
      one: '1 Datenproblem',
    );
    return '$_temp0';
  }

  @override
  String get dashboard_gauges_retry =>
      'Status nicht verfügbar - zum Wiederholen tippen';

  @override
  String get dashboard_urgent_title => 'Braucht Aufmerksamkeit';

  @override
  String get dashboard_media_title => 'Aktuelle Medien';

  @override
  String get dashboard_recentSites_title => 'Aktuelle Tauchplätze';

  @override
  String get dashboard_yearInReview_title => 'Dieses Jahr';

  @override
  String dashboard_yearInReview_divesVs(int count, int previous) {
    return '$count Tauchgänge (Vorjahr: $previous)';
  }

  @override
  String dashboard_yearInReview_hours(String hours) {
    return '$hours Stunden unter Wasser';
  }

  @override
  String dashboard_yearInReview_maxDepth(String depth) {
    return 'Tiefste: $depth';
  }

  @override
  String get dashboard_onThisDay_title => 'An diesem Tag';

  @override
  String dashboard_onThisDay_entry(String year, String site) {
    return '$year - $site';
  }

  @override
  String get dashboard_milestones_title => 'Meilensteine';

  @override
  String dashboard_milestones_nextDive(int remaining, int milestone) {
    return 'Noch $remaining Tauchgänge bis Nr. $milestone';
  }

  @override
  String dashboard_milestones_certYears(String name, int years, String month) {
    return '$name: $years Jahre im $month';
  }

  @override
  String get dashboard_personalRecords_coldest => 'Kältester';

  @override
  String get dashboard_personalRecords_deepest => 'Tiefster';

  @override
  String get dashboard_personalRecords_longest => 'Längster';

  @override
  String get dashboard_personalRecords_sectionTitle => 'Persönliche Rekorde';

  @override
  String get dashboard_personalRecords_warmest => 'Wärmster';

  @override
  String get dashboard_quickActions_addSite => 'Tauchplatz hinzufügen';

  @override
  String get dashboard_quickActions_addSiteTooltip =>
      'Neuen Tauchplatz hinzufügen';

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
  String get dashboard_quickStats_countries => 'Länder';

  @override
  String get dashboard_quickStats_countriesSubtitle => 'besucht';

  @override
  String get dashboard_quickStats_sectionTitle => 'Auf einen Blick';

  @override
  String get dashboard_quickStats_species => 'Arten';

  @override
  String get dashboard_quickStats_speciesSubtitle => 'entdeckt';

  @override
  String get dashboard_quickStats_topBuddy => 'Häufigster Tauchpartner';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count Tauchgänge';
  }

  @override
  String get dashboard_recentDives_empty => 'Noch keine Tauchgänge erfasst';

  @override
  String get dashboard_recentDives_errorLoading =>
      'Tauchgänge konnten nicht geladen werden';

  @override
  String get dashboard_recentDives_latestProfileTitle => 'Letztes Tauchprofil';

  @override
  String get dashboard_recentDives_noProfileData =>
      'Keine Profildaten für diesen Tauchgang';

  @override
  String get dashboard_recentDives_profileLoadError =>
      'Tauchprofil konnte nicht geladen werden';

  @override
  String dashboard_recentDives_profileMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String get dashboard_recentDives_logFirst => 'Ersten Tauchgang erfassen';

  @override
  String get dashboard_recentDives_sectionTitle => 'Letzte Tauchgänge';

  @override
  String get dashboard_recentDives_viewAll => 'Alle anzeigen';

  @override
  String get dashboard_recentDives_viewAllTooltip => 'Alle Tauchgänge anzeigen';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count aktive Hinweise';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives =>
      'Fehler: Letzte Tauchgänge konnten nicht geladen werden';

  @override
  String get dashboard_semantics_errorLoadingStatistics =>
      'Fehler: Statistiken konnten nicht geladen werden';

  @override
  String get dashboard_semantics_greetingBanner => 'Dashboard-Begrüßung';

  @override
  String get dashboard_stats_errorLoadingStatistics =>
      'Statistiken konnten nicht geladen werden';

  @override
  String get dashboard_stats_hoursLogged => 'Erfasste Stunden';

  @override
  String get dashboard_stats_maxDepth => 'Max. Tiefe';

  @override
  String get dashboard_stats_sitesVisited => 'Besuchte Tauchplätze';

  @override
  String get dashboard_stats_totalDives => 'Tauchgänge gesamt';

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
  String get decoCalculator_waterType => 'Wassertyp';

  @override
  String get decoCalculator_waterType_standard => 'Standard';

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
    return 'Möchten Sie wirklich $count $_temp0 löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get diveLog_bulkDelete_restored => 'Tauchgänge wiederhergestellt';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgaenge',
      one: 'Tauchgang',
    );
    return '$count $_temp0 gelöscht';
  }

  @override
  String get diveLog_bulkDelete_title => 'Tauchgänge löschen';

  @override
  String get diveLog_bulkDelete_undo => 'Rückgängig';

  @override
  String get diveLog_bulkEdit_addTags => 'Tags hinzufügen';

  @override
  String get diveLog_bulkEdit_addTagsDescription =>
      'Tags zu ausgewählten Tauchgängen hinzufügen';

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
    return '$tagCount $_temp0 zu $diveCount $_temp1 hinzugefügt';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => 'Reise ändern';

  @override
  String get diveLog_bulkEdit_changeTripDescription =>
      'Ausgewählte Tauchgänge einer Reise zuordnen';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips =>
      'Fehler beim Laden der Reisen';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return 'Tags konnten nicht hinzugefügt werden: $error';
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
  String get diveLog_bulkEdit_noTagsAvailable => 'Keine Tags verfügbar.';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate =>
      'Keine Tags verfügbar. Erstellen Sie zuerst Tags.';

  @override
  String get diveLog_bulkEdit_noTrip => 'Keine Reise';

  @override
  String get diveLog_bulkEdit_removeFromTrip => 'Von Reise entfernen';

  @override
  String get diveLog_bulkEdit_removeTags => 'Tags entfernen';

  @override
  String get diveLog_bulkEdit_removeTagsDescription =>
      'Tags von ausgewählten Tauchgängen entfernen';

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
  String get diveLog_bulkEdit_selectTrip => 'Reise auswählen';

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
  String get diveLog_combine_confirm => 'Zu einem Tauchgang kombinieren';

  @override
  String get diveLog_combine_dataNote =>
      'Die Details stammen vom frühesten Tauchgang, wobei Lücken durch spätere Tauchgänge aufgefüllt werden. Notizen werden zusammengeführt. Flaschen, Ausrüstung, Tauchpartner, Tags und Sichtungen bleiben alle erhalten.';

  @override
  String get diveLog_combine_error =>
      'Die Tauchgänge konnten nicht kombiniert werden. Es wurde nichts geändert.';

  @override
  String diveLog_combine_gapLabel(String duration) {
    return 'Oberflächenintervall: $duration';
  }

  @override
  String get diveLog_combine_longSurfaceWarning =>
      'Ein oder mehrere Oberflächenintervalle sind länger als 30 Minuten. Dies könnten separate Tauchgänge sein statt eines durchgehenden Tauchgangs.';

  @override
  String get diveLog_combine_mixedDivers =>
      'Die ausgewählten Tauchgänge gehören zu unterschiedlichen Tauchern und können nicht kombiniert werden.';

  @override
  String get diveLog_combine_profilePreview => 'Kombiniertes Profil';

  @override
  String diveLog_combine_previewIntro(int count) {
    return 'Diese $count Tauchgänge werden zu einem durchgehenden Tauchgang kombiniert. Lücken dazwischen werden zu Oberflächenzeit.';
  }

  @override
  String diveLog_combine_resultSummary(
    String runtime,
    String maxDepth,
    String bottomTime,
  ) {
    return 'Ergebnis: $runtime insgesamt, maximale Tiefe $maxDepth, Grundzeit $bottomTime';
  }

  @override
  String diveLog_combine_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgänge',
      one: 'Tauchgang',
    );
    return '$count $_temp0 kombiniert';
  }

  @override
  String get diveLog_combine_title => 'Tauchgänge kombinieren';

  @override
  String get diveLog_combine_undoError =>
      'Die Kombination konnte nicht rückgängig gemacht werden.';

  @override
  String get diveLog_combine_undone => 'Kombination rückgängig gemacht';

  @override
  String get diveLog_computerSource_badge_primary => 'Primär';

  @override
  String get diveLog_consolidate_confirm =>
      'Als ein Tauchgang mit beiden Computern behalten';

  @override
  String get diveLog_consolidate_error_generic =>
      'Die Tauchgänge konnten nicht zusammengeführt werden. Es wurde nichts geändert.';

  @override
  String get diveLog_consolidate_error_notOverlapping =>
      'Diese Tauchgänge überschneiden sich zeitlich nicht und können daher nicht als derselbe Tauchgang zusammengeführt werden.';

  @override
  String get diveLog_consolidate_error_sameComputer =>
      'Diese Tauchgänge stammen vom selben Tauchcomputer und können auf diese Weise nicht zusammengeführt werden.';

  @override
  String get diveLog_consolidate_selectPrimary => 'Primärer Tauchcomputer';

  @override
  String get diveLog_consolidate_snackbar =>
      'Tauchgang als zusätzlicher Computer zusammengeführt.';

  @override
  String get diveLog_consolidate_undoError =>
      'Die Zusammenführung konnte nicht rückgängig gemacht werden.';

  @override
  String get diveLog_consolidate_undone => 'Zusammenführung rückgängig gemacht';

  @override
  String diveLog_mergeDialog_confirmSubtitle(String time) {
    return 'Der Tauchgang um $time wird mit diesem Tauchgang zusammengeführt.';
  }

  @override
  String get diveLog_mergeDialog_confirmTitle => 'Zusammenführung bestätigen';

  @override
  String get diveLog_mergeDialog_empty =>
      'Keine weiteren Tauchgänge an diesem Tag gefunden.';

  @override
  String get diveLog_mergeDialog_explanation =>
      'Das Profil, die Flaschen, Drücke, Ereignisse, Tags, Tauchpartner und Sichtungen dieses Tauchgangs werden als zusätzliche Computerquelle in diesen Tauchgang eingefügt. Diese Aktion kann mit „Computer trennen“ rückgängig gemacht werden.';

  @override
  String diveLog_mergeDialog_loadError(String error) {
    return 'Fehler beim Laden der Tauchgänge: $error';
  }

  @override
  String get diveLog_mergeDialog_merge => 'Zusammenführen';

  @override
  String get diveLog_mergeDialog_next => 'Weiter';

  @override
  String get diveLog_mergeDialog_subtitle =>
      'Wähle einen Tauchgang vom selben Tag aus, um ihn als zusätzlichen Computer zusammenzuführen.';

  @override
  String get diveLog_mergeDialog_title =>
      'Mit einem anderen Tauchgang zusammenführen';

  @override
  String get diveLog_mergeDialog_whatThisDoes => 'Was das bewirkt';

  @override
  String get diveLog_computerSheet_description =>
      'Wähle, von welchem Computerprofil aus bearbeitet wird.';

  @override
  String get diveLog_computerSheet_title => 'Startprofil wählen';

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return 'Durchschn.: $depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => 'Basis';

  @override
  String get diveLog_cylinderSac_noSac => 'AMV: --';

  @override
  String get diveLog_cylinderSac_tooltip_aiData =>
      'Verwendet AI-Senderdaten für höhere Genauigkeit';

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
  String get diveLog_deco_label_gf99 => 'GF99';

  @override
  String get diveLog_deco_label_surfGf => 'SurfGF';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_time => 'Zeit';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String diveLog_deco_gf_chip(Object low, Object high) {
    return 'GF: $low/$high';
  }

  @override
  String diveLog_deco_gf_chipFromSettings(Object low, Object high) {
    return 'GF: $low/$high · deine Einstellungen';
  }

  @override
  String diveLog_deco_gf_chipRecordedAlgorithm(
    Object algorithm,
    Object low,
    Object high,
  ) {
    return '$algorithm · ausgewertet mit GF $low/$high';
  }

  @override
  String diveLog_deco_gf_semantics(Object low, Object high) {
    return 'Gradientenfaktoren: niedrig $low, hoch $high';
  }

  @override
  String get diveLog_deco_gf_tooltipFromSettings =>
      'Dieser Tauchcomputer hat seine Gradientenfaktoren nicht aufgezeichnet, daher wird dieser Tauchgang mit denen aus deinen Einstellungen ausgewertet.';

  @override
  String diveLog_deco_gf_tooltipRecordedAlgorithm(Object algorithm) {
    return 'Dieser Tauchgang wurde mit $algorithm berechnet, das keine Gradientenfaktoren verwendet. Submersion wertet ihn mit denen aus deinen Einstellungen aus.';
  }

  @override
  String get diveLog_deco_sectionDecoStops => 'Dekostopps';

  @override
  String get diveLog_deco_sectionTissueLoading => 'Gewebesättigung';

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
  String get diveLog_deco_title => 'Dekostatus';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return 'Gesamt: $time';
  }

  @override
  String get diveLog_delete_cancel => 'Abbrechen';

  @override
  String get diveLog_delete_confirm =>
      'Diese Aktion kann nicht rückgängig gemacht werden. Der Tauchgang und alle zugehörigen Daten (Profil, Flaschen, Sichtungen) werden dauerhaft gelöscht.';

  @override
  String get diveLog_delete_delete => 'Löschen';

  @override
  String get diveLog_delete_title => 'Tauchgang löschen?';

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
  String get diveLog_detail_button_rangeAnalysis => 'Bereichsstatistik';

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
  String get diveLog_detail_label_airTemp => 'Lufttemperatur';

  @override
  String get diveLog_detail_label_avgDepth => 'Durchschn. Tiefe';

  @override
  String get diveLog_detail_label_buddy => 'Tauchpartner';

  @override
  String get diveLog_detail_label_currentDirection => 'Strömungsrichtung';

  @override
  String get diveLog_detail_label_currentStrength => 'Strömungsstärke';

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
  String get diveLog_detail_label_elevation => 'Höhe';

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
  String get diveLog_detail_label_height => 'Höhe';

  @override
  String get diveLog_detail_label_highTide => 'Hochwasser';

  @override
  String get diveLog_detail_label_lowTide => 'Niedrigwasser';

  @override
  String get diveLog_detail_label_ppO2AtPoint => 'ppO₂ am ausgewählten Punkt:';

  @override
  String get diveLog_detail_label_rateOfChange => 'Änderungsrate';

  @override
  String get diveLog_detail_label_sacRate => 'AMV';

  @override
  String get diveLog_detail_label_state => 'Zustand';

  @override
  String get diveLog_detail_label_surfaceInterval => 'Oberflächenintervall';

  @override
  String get diveLog_detail_label_surfacePressure => 'Oberflächendruck';

  @override
  String get diveLog_detail_label_swellHeight => 'Wellenhöhe';

  @override
  String get diveLog_detail_label_total => 'Gesamt:';

  @override
  String get diveLog_detail_label_visibility => 'Sichtweite';

  @override
  String get diveLog_detail_label_waterType => 'Wasserart';

  @override
  String get diveLog_detail_menu_delete => 'Löschen';

  @override
  String get diveLog_detail_menu_export => 'Exportieren';

  @override
  String get diveLog_detail_menu_openFullPage => 'Ganze Seite öffnen';

  @override
  String get diveLog_detail_noNotes => 'Keine Notizen für diesen Tauchgang.';

  @override
  String get diveLog_detail_notFound => 'Tauchgang nicht gefunden';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count Punkte';
  }

  @override
  String get diveLog_detail_section_altitudeDive => 'Höhentauchgang';

  @override
  String get diveLog_detail_section_buddies => 'Tauchpartner';

  @override
  String get diveLog_detail_section_conditions => 'Bedingungen';

  @override
  String get diveLog_detail_section_customFields => 'Custom Fields';

  @override
  String get diveLog_detail_section_decoStatus => 'Dekostatus';

  @override
  String get diveLog_detail_section_details => 'Details';

  @override
  String get diveLog_detail_section_diveProfile => 'Tauchprofil';

  @override
  String get diveLog_detail_section_equipment => 'Ausrüstung';

  @override
  String get diveLog_detail_section_marineLife => 'Meeresfauna';

  @override
  String get diveLog_detail_section_notes => 'Notizen';

  @override
  String get diveLog_detail_section_oxygenToxicity => 'Sauerstofftoxizität';

  @override
  String get diveLog_detail_section_sacRateBySegment => 'AMV nach Segment';

  @override
  String get diveLog_detail_section_tags => 'Tags';

  @override
  String get diveLog_detail_section_cylinders => 'Flaschen';

  @override
  String get diveLog_detail_section_tide => 'Gezeiten';

  @override
  String get diveLog_detail_section_trainingSignature =>
      'Ausbildungsunterschrift';

  @override
  String get diveLog_detail_section_weight => 'Gewicht';

  @override
  String get diveLog_detail_signatureDescription =>
      'Tippen Sie, um die Verifizierung des Tauchlehrers für diesen Ausbildungstauchgang hinzuzufügen';

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
  String get diveLog_detail_tideCalculated => 'Berechnet aus Gezeitenmodell';

  @override
  String get diveLog_detail_tooltip_addToFavorites => 'Zu Favoriten hinzufügen';

  @override
  String get diveLog_detail_tooltip_edit => 'Bearbeiten';

  @override
  String get diveLog_detail_tooltip_editDive => 'Tauchgang bearbeiten';

  @override
  String get diveLog_detail_tooltip_previousDive => 'Previous dive';

  @override
  String get diveLog_detail_tooltip_nextDive => 'Next dive';

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
  String get diveLog_diveMode_gaugeDescription =>
      'Nur Tiefe und Zeit; keine Gas- oder Dekompressionsverfolgung';

  @override
  String get diveLog_diveMode_ocDescription =>
      'Standard-Gerätetauchen mit offenem Kreislauf und Flaschen';

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
  String get diveLog_editSighting_notesHint => 'Größe, Verhalten, Fundort...';

  @override
  String get diveLog_editSighting_remove => 'Entfernen';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return '$name von diesem Tauchgang entfernen?';
  }

  @override
  String get diveLog_editSighting_removeTitle => 'Sichtung entfernen?';

  @override
  String get diveLog_editSighting_save => 'Änderungen speichern';

  @override
  String get diveLog_edit_add => 'Hinzufügen';

  @override
  String get diveLog_edit_addCustomField => 'Add Field';

  @override
  String get diveLog_edit_addTank => 'Flasche hinzufügen';

  @override
  String get diveLog_edit_addWeightEntry => 'Gewichtseintrag hinzufügen';

  @override
  String diveLog_edit_addedGps(Object name) {
    return 'GPS zu $name hinzugefügt';
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
      'Tippen Sie auf \"Set verwenden\" oder \"Hinzufügen\" um Ausrüstung auszuwählen';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return 'Fehler beim Laden der Tauchgangsarten: $error';
  }

  @override
  String get diveLog_edit_gettingLocation => 'Standort wird ermittelt...';

  @override
  String get diveLog_edit_group_buddies => 'Buddys';

  @override
  String get diveLog_edit_group_conditions => 'Bedingungen';

  @override
  String get diveLog_edit_group_experience => 'Erlebnis';

  @override
  String get diveLog_edit_group_gasGear => 'Gas & Ausrüstung';

  @override
  String get diveLog_edit_group_theDive => 'Der Tauchgang';

  @override
  String get diveLog_edit_group_trip => 'Reise';

  @override
  String get diveLog_edit_headerNew => 'Neuen Tauchgang erfassen';

  @override
  String get diveLog_edit_invite_buddies => 'Buddys hinzufügen';

  @override
  String get diveLog_edit_invite_conditions =>
      'Bedingungen hinzufügen - Wasser, Sicht, Wetter';

  @override
  String get diveLog_edit_invite_experience =>
      'Bewertung, Sichtungen, Notizen oder Tags hinzufügen';

  @override
  String get diveLog_edit_invite_gasGear =>
      'Gas & Ausrüstung hinzufügen - Modus, Flaschen, Ausrüstung, Blei';

  @override
  String get diveLog_edit_invite_trip => 'Reise oder Tauchbasis hinzufügen';

  @override
  String get diveLog_edit_label_airTemp => 'Lufttemperatur';

  @override
  String get diveLog_edit_label_altitude => 'Höhe';

  @override
  String get diveLog_edit_label_avgDepth => 'Durchschn. Tiefe';

  @override
  String get diveLog_edit_label_bottomTime => 'Grundzeit';

  @override
  String get diveLog_edit_label_currentDirection => 'Strömungsrichtung';

  @override
  String get diveLog_edit_label_currentStrength => 'Strömungsstärke';

  @override
  String get diveLog_edit_label_diveType => 'Tauchgangart';

  @override
  String get diveLog_edit_label_diveTypes => 'Tauchgangstypen';

  @override
  String get diveLog_edit_label_diveNumber => 'Tauchgang-Nr.';

  @override
  String get diveLog_edit_label_diveName => 'Name';

  @override
  String get diveLog_edit_diveNamePlaceholder =>
      'Optionaler Name für diesen Tauchgang';

  @override
  String get diveLog_edit_hint_diveNumber =>
      'Wird automatisch vergeben, wenn leer gelassen';

  @override
  String get diveLog_edit_label_entryMethod => 'Einstiegsmethode';

  @override
  String get diveLog_edit_label_exitMethod => 'Ausstiegsmethode';

  @override
  String get diveLog_edit_label_maxDepth => 'Max. Tiefe';

  @override
  String get diveLog_edit_label_runtime => 'Laufzeit';

  @override
  String get diveLog_edit_label_surfacePressure => 'Oberflächendruck';

  @override
  String get diveLog_edit_label_swellHeight => 'Wellenhöhe';

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
      'Tippen Sie auf \"Hinzufügen\" um Sichtungen zu erfassen';

  @override
  String get diveLog_edit_nearbySitesFirst => 'Nahe Tauchplätze zuerst';

  @override
  String get diveLog_edit_noEquipmentSelected => 'Keine Ausrüstung ausgewählt';

  @override
  String get diveLog_edit_noMarineLife => 'Keine Meeresfauna erfasst';

  @override
  String get diveLog_edit_notSpecified => 'Nicht angegeben';

  @override
  String get diveLog_edit_notesHint =>
      'Notizen zu diesem Tauchgang hinzufügen...';

  @override
  String get diveLog_edit_overline_tanks => 'Flaschen';

  @override
  String get diveLog_edit_profile_draw => 'Profil zeichnen';

  @override
  String get diveLog_edit_profile_none => 'Nicht aufgezeichnet';

  @override
  String diveLog_edit_profile_outliers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mögliche Ausreißer erkannt',
      one: '1 möglicher Ausreißer erkannt',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_profile_points(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Punkte',
      one: '1 Punkt',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_row_addSite => 'Tauchplatz hinzufügen';

  @override
  String get diveLog_edit_row_diveCenter => 'Tauchbasis';

  @override
  String get diveLog_edit_row_diveProfile => 'Tauchprofil';

  @override
  String get diveLog_edit_row_entry => 'Einstieg';

  @override
  String get diveLog_edit_row_exit => 'Ausstieg';

  @override
  String get diveLog_edit_row_notSet => 'Nicht gesetzt';

  @override
  String get diveLog_edit_row_site => 'Tauchplatz';

  @override
  String get diveLog_edit_row_surfaceInterval => 'Oberflächenpause';

  @override
  String get diveLog_edit_row_trip => 'Reise';

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
    return '$count $_temp0 als neues Ausrüstungsset speichern.';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description =>
      'Beschreibung (optional)';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint =>
      'z.B. Leichte Ausrüstung für warmes Wasser';

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
    return 'Ausrüstungsset \"$name\" erstellt';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title =>
      'Als Ausrüstungsset speichern';

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
  String get diveLog_edit_section_equipment => 'Ausrüstung';

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
  String get diveLog_edit_select => 'Auswählen';

  @override
  String get diveLog_edit_selectDiveCenter => 'Tauchbasis auswählen';

  @override
  String get diveLog_edit_selectDiveSite => 'Tauchplatz auswählen';

  @override
  String get diveLog_edit_selectTrip => 'Reise auswählen';

  @override
  String diveLog_edit_snackbar_avgDepthCalculated(Object depth) {
    return 'Durchschnittstiefe berechnet: $depth';
  }

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Grundzeit berechnet: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Fehler beim Speichern des Tauchgangs: $error';
  }

  @override
  String diveLog_edit_snackbar_maxDepthCalculated(Object depth) {
    return 'Maximale Tiefe berechnet: $depth';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'Keine Tauchprofildaten verfügbar';

  @override
  String diveLog_edit_snackbar_runtimeCalculated(Object minutes) {
    return 'Laufzeit berechnet: $minutes min';
  }

  @override
  String get diveLog_edit_snackbar_unableToCalculateAvgDepth =>
      'Durchschnittstiefe konnte nicht aus dem Profil berechnet werden';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Grundzeit konnte nicht aus dem Profil berechnet werden';

  @override
  String get diveLog_edit_snackbar_unableToCalculateMaxDepth =>
      'Maximale Tiefe konnte nicht aus dem Profil berechnet werden';

  @override
  String get diveLog_edit_snackbar_unableToCalculateRuntime =>
      'Laufzeit konnte nicht aus dem Profil berechnet werden';

  @override
  String diveLog_edit_summary_items(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel',
      one: '1 Artikel',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_summary_notes => 'Notizen';

  @override
  String diveLog_edit_summary_species(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Arten',
      one: '1 Art',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_summary_tanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Flaschen',
      one: '1 Flasche',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return 'Oberflächenintervall: $interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint =>
      'Standard: 1013 mbar auf Meereshöhe';

  @override
  String get diveLog_edit_tankCard_done => 'Fertig';

  @override
  String get diveLog_edit_tankCard_edit => 'Bearbeiten';

  @override
  String get diveLog_edit_tankCard_mix => 'Gemisch';

  @override
  String get diveLog_edit_tankCard_pressure => 'Druck';

  @override
  String diveLog_edit_tankCard_title(int number) {
    return 'Flasche $number';
  }

  @override
  String get diveLog_edit_tankCard_volume => 'Volumen';

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
  String get diveLog_edit_tooltip_removeEquipment => 'Ausrüstung entfernen';

  @override
  String get diveLog_edit_tooltip_removeSighting => 'Sichtung entfernen';

  @override
  String get diveLog_edit_tooltip_removeWeight => 'Entfernen';

  @override
  String get diveLog_edit_trainingCourseHint =>
      'Diesen Tauchgang mit einem Ausbildungskurs verknüpfen';

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
  String get diveLog_emptyFiltered_clearFilters => 'Filter zurücksetzen';

  @override
  String get diveLog_emptyFiltered_subtitle =>
      'Versuchen Sie, Ihre Filter anzupassen oder zurückzusetzen';

  @override
  String get diveLog_emptyFiltered_title =>
      'Keine Tauchgänge entsprechen Ihren Filtern';

  @override
  String get diveLog_empty_logFirstDive => 'Ersten Tauchgang erfassen';

  @override
  String get diveLog_empty_subtitle =>
      'Tippen Sie auf die Schaltfläche unten, um Ihren ersten Tauchgang zu erfassen';

  @override
  String get diveLog_empty_title => 'Noch keine Tauchgänge erfasst';

  @override
  String get diveLog_equipmentPicker_addFromTab =>
      'Ausrüstung über den Ausrüstungs-Tab hinzufügen';

  @override
  String get diveLog_equipmentPicker_allSelected =>
      'Gesamte Ausrüstung bereits ausgewählt';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return 'Fehler beim Laden der Ausrüstung: $error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => 'Noch keine Ausrüstung';

  @override
  String get diveLog_equipmentPicker_removeToAdd =>
      'Entfernen Sie Gegenstände, um andere hinzuzufügen';

  @override
  String get diveLog_equipmentPicker_title => 'Ausrüstung hinzufügen';

  @override
  String get diveLog_equipmentSetPicker_createHint =>
      'Sets unter Ausrüstung > Sets erstellen';

  @override
  String get diveLog_equipmentSetPicker_emptySet => 'Leeres Set';

  @override
  String get diveLog_equipmentSetPicker_errorItems =>
      'Fehler beim Laden der Gegenstände';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return 'Fehler beim Laden der Ausrüstungssets: $error';
  }

  @override
  String diveLog_equipmentSetPicker_itemsSummary(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel',
      one: '1 Artikel',
    );
    return '$_temp0: $names';
  }

  @override
  String get diveLog_equipmentSetPicker_loading => 'Wird geladen...';

  @override
  String get diveLog_equipmentSetPicker_noSets => 'Noch keine Ausrüstungssets';

  @override
  String get diveLog_equipmentSetPicker_title => 'Ausrüstungsset verwenden';

  @override
  String get diveLog_error_loadingDives => 'Fehler beim Laden der Tauchgänge';

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
      'Wählen Sie einen Speicherort für die Datei';

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
  String get diveLog_exportImage_shareDescription => 'Über andere Apps teilen';

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
  String get diveLog_filterChip_clearAll => 'Alle zurücksetzen';

  @override
  String get diveLog_filterChip_favorites => 'Favoriten';

  @override
  String diveLog_filterChip_from(Object date) {
    return 'Von $date';
  }

  @override
  String get diveLog_filterChip_noBuddy => 'Kein Buddy';

  @override
  String diveLog_filterChip_until(Object date) {
    return 'Bis $date';
  }

  @override
  String get diveLog_filter_allSites => 'Alle Tauchplätze';

  @override
  String get diveLog_filter_allTypes => 'Alle Typen';

  @override
  String get diveLog_filter_apply => 'Filter anwenden';

  @override
  String get diveLog_filter_buddyHint => 'Nach Tauchpartnername suchen';

  @override
  String get diveLog_filter_buddyName => 'Tauchpartnername';

  @override
  String get diveLog_filter_clearAll => 'Alle zurücksetzen';

  @override
  String get diveLog_filter_clearDates => 'Daten zurücksetzen';

  @override
  String get diveLog_filter_clearRating => 'Bewertungsfilter zurücksetzen';

  @override
  String get diveLog_filter_clearWeekdays => 'Wochentage zurücksetzen';

  @override
  String get diveLog_filter_dateSeparator => 'bis';

  @override
  String get diveLog_filter_endDate => 'Enddatum';

  @override
  String get diveLog_filter_errorLoadingSites =>
      'Fehler beim Laden der Tauchplätze';

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
  String get diveLog_filter_noBuddyOnly => 'Kein Buddy zugewiesen';

  @override
  String get diveLog_filter_noTagsYet => 'Noch keine Tags erstellt';

  @override
  String get diveLog_filter_presetAllTime => 'Gesamter Zeitraum';

  @override
  String get diveLog_filter_presetLast12Months => 'Letzte 12 Monate';

  @override
  String get diveLog_filter_presetLastYear => 'Letztes Jahr';

  @override
  String get diveLog_filter_presetThisYear => 'Dieses Jahr';

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
  String get diveLog_filter_sectionWeekdays => 'Wochentage';

  @override
  String get diveLog_filter_showOnlyFavorites => 'Nur Favoriten anzeigen';

  @override
  String get diveLog_filter_showOnlyNoBuddy =>
      'Nur Tauchgänge ohne Buddy anzeigen';

  @override
  String get diveLog_filter_startDate => 'Startdatum';

  @override
  String get diveLog_filter_title => 'Tauchgänge filtern';

  @override
  String get diveLog_filter_resizeGrip => 'Filterbereich skalieren';

  @override
  String get diveLog_filter_tooltip_close => 'Filter schließen';

  @override
  String get diveLog_fullscreenProfile_close => 'Vollbild schließen';

  @override
  String get diveLog_fullscreenProfile_readoutHint =>
      'Zeiger über das Profil bewegen oder scrubben';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Tauchgang #$number Profil';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Aufstiegsgeschwindigkeit';

  @override
  String get diveLog_legend_label_ascentRateLine =>
      'Aufstiegsgeschwindigkeit (Linie)';

  @override
  String get diveLog_legend_label_ceiling => 'Ceiling';

  @override
  String get diveLog_legend_label_decoStops => 'Deco stops';

  @override
  String get diveLog_legend_label_cns => 'CNS%';

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
  String get diveLog_legend_label_otu => 'OTU';

  @override
  String get diveLog_legend_label_photoMarkers => 'Fotos';

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
  String get diveLog_legend_label_sacRate => 'AMV';

  @override
  String get diveLog_legend_label_showGas => 'Gase';

  @override
  String get diveLog_legend_label_surfaceGf => 'Oberflächenm GF';

  @override
  String get diveLog_legend_label_temp => 'Temp.';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_legend_source_dc => 'DC';

  @override
  String get diveLog_legend_source_calc => 'Ber.';

  @override
  String get diveLog_chartSection_overlays => 'Einblendungen';

  @override
  String get diveLog_chartSection_markers => 'Markierungen';

  @override
  String get diveLog_chartSection_decompression => 'Dekompression';

  @override
  String get diveLog_chartSection_gasAnalysis => 'Gasanalyse';

  @override
  String get diveLog_chartSection_display => 'Anzeige';

  @override
  String get diveLog_chartSection_other => 'Sonstiges';

  @override
  String get diveLog_chartSection_tankPressures => 'Flaschendrucke';

  @override
  String get diveLog_chartOption_metricsFollowViewport =>
      'Einblendungen im Sichtbereich halten';

  @override
  String get diveLog_pressure_estimatedSuffix => '(gesch.)';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Tauchkarte';

  @override
  String get diveLog_listPage_compactTitle => 'Tauchgänge';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get diveLog_listPage_bottomSheet_importFromComputer =>
      'Vom Tauchcomputer importieren';

  @override
  String get diveLog_listPage_bottomSheet_scanPaperLog =>
      'Papier-Logbuch scannen';

  @override
  String get ocrImport_scanPage_processing => 'Seite wird gelesen...';

  @override
  String get ocrImport_scanPage_pickPhoto => 'Foto auswählen';

  @override
  String get ocrImport_scanPage_takePhoto => 'Foto aufnehmen';

  @override
  String get ocrImport_scanPage_nothingRead =>
      'Auf dieser Seite war wenig lesbar - Felder bleiben leer';

  @override
  String get ocrImport_scanPage_engineMissing =>
      'Texterkennung ist nicht verfügbar. Installieren Sie Tesseract, um Papier-Logbücher zu scannen (zum Beispiel: sudo apt install tesseract-ocr).';

  @override
  String get ocrImport_editPage_photoAttachFailed =>
      'Der Tauchgang wurde gespeichert, aber das Anhängen der gescannten Seite ist fehlgeschlagen';

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
  String get diveLog_listPage_menuMatchSites =>
      'Tauchgänge Tauchplätzen zuordnen';

  @override
  String get diveLog_sighting_decreaseCount => 'Anzahl verringern';

  @override
  String get diveLog_sighting_increaseCount => 'Anzahl erhöhen';

  @override
  String diveLog_speciesPicker_errorLoading(String error) {
    return 'Fehler beim Laden der Arten: $error';
  }

  @override
  String get diveRole_builtin_buddy => 'Tauchpartner';

  @override
  String get diveRole_builtin_diveGuide => 'Tauchguide';

  @override
  String get diveRole_builtin_diveMaster => 'Divemaster';

  @override
  String get diveRole_builtin_instructor => 'Tauchlehrer';

  @override
  String get diveRole_builtin_rearGuard => 'Schlusstaucher';

  @override
  String get diveRole_builtin_safetyDiver => 'Sicherungstaucher';

  @override
  String get diveRole_builtin_solo => 'Solo';

  @override
  String get diveRole_builtin_student => 'Tauchschüler';

  @override
  String get diveRole_builtin_supportDiver => 'Support-Taucher';

  @override
  String get diveRoles_addDialog_addButton => 'Hinzufügen';

  @override
  String get diveRoles_addDialog_nameHint => 'z.B. Fotograf';

  @override
  String get diveRoles_addDialog_nameLabel => 'Tauchrollen-Name';

  @override
  String get diveRoles_addDialog_nameValidation =>
      'Bitte geben Sie einen Namen ein';

  @override
  String get diveRoles_addDialog_title =>
      'Benutzerdefinierte Tauchrolle hinzufügen';

  @override
  String get diveRoles_addTooltip => 'Tauchrolle hinzufügen';

  @override
  String get diveRoles_appBar_title => 'Tauchrollen';

  @override
  String get diveRoles_builtInHeader => 'Integrierte Tauchrollen';

  @override
  String get diveRoles_customHeader => 'Benutzerdefinierte Tauchrollen';

  @override
  String diveRoles_deleteDialog_content(Object name) {
    return 'Möchten Sie \"$name\" wirklich löschen?';
  }

  @override
  String get diveRoles_deleteDialog_title => 'Tauchrolle löschen?';

  @override
  String get diveRoles_deleteTooltip => 'Tauchrolle löschen';

  @override
  String get diveRoles_renameDialog_title => 'Tauchrolle umbenennen';

  @override
  String get diveRoles_renameTooltip => 'Tauchrolle umbenennen';

  @override
  String diveRoles_snackbar_added(Object name) {
    return 'Tauchrolle hinzugefügt: $name';
  }

  @override
  String diveRoles_snackbar_cannotDelete(Object name) {
    return '\"$name\" kann nicht gelöscht werden - wird von vorhandenen Tauchgängen verwendet';
  }

  @override
  String diveRoles_snackbar_deleted(Object name) {
    return 'Tauchrolle gelöscht: $name';
  }

  @override
  String diveRoles_snackbar_errorAdding(Object error) {
    return 'Fehler beim Hinzufügen der Tauchrolle: $error';
  }

  @override
  String get diveSites_edit_depth_heroMax => 'Max. Tiefe';

  @override
  String get diveSites_edit_depth_heroMin => 'Min. Tiefe';

  @override
  String get diveSites_edit_group_accessSafety => 'Zugang & Sicherheit';

  @override
  String get diveSites_edit_group_diveInfo => 'Tauchinfo';

  @override
  String get diveSites_edit_group_identity => 'Identität';

  @override
  String get diveSites_edit_group_lifeNotes => 'Leben & Notizen';

  @override
  String get diveSites_edit_group_location => 'Position';

  @override
  String get diveSites_edit_invite_accessSafety =>
      'Zugang, Parken, Mooring oder Gefahren hinzufügen';

  @override
  String get diveSites_edit_invite_diveInfo =>
      'Tiefenbereich, Schwierigkeit oder Bewertung hinzufügen';

  @override
  String get diveSites_edit_invite_lifeNotes =>
      'Meeresleben, Notizen oder Freigabe hinzufügen';

  @override
  String get diveSites_edit_invite_location =>
      'GPS-Position oder Höhe hinzufügen';

  @override
  String get diveSites_edit_summary_shared => 'geteilt';

  @override
  String get forms_addSection_prefix => 'Hinzufügen:';

  @override
  String get forms_cancel => 'Abbrechen';

  @override
  String get forms_discard_body =>
      'Es gibt ungespeicherte Änderungen. Wenn Sie jetzt verlassen, gehen sie verloren.';

  @override
  String get forms_discard_discard => 'Verwerfen';

  @override
  String get forms_discard_keepEditing => 'Weiter bearbeiten';

  @override
  String get forms_discard_title => 'Änderungen verwerfen?';

  @override
  String get forms_save => 'Speichern';

  @override
  String forms_section_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Probleme',
      one: '1 Problem',
    );
    return '$_temp0';
  }

  @override
  String get settings_manage_setupAssistant => 'Einrichtungsassistent';

  @override
  String get settings_manage_setupAssistant_subtitle =>
      'Einheiten, Darstellung und Backup-Einstellungen erneut durchgehen';

  @override
  String get setup_backup_cloudCopy => 'Backups in der Cloud speichern';

  @override
  String get setup_backup_frequency => 'Häufigkeit';

  @override
  String get setup_backup_frequency_daily => 'Täglich';

  @override
  String get setup_backup_frequency_monthly => 'Monatlich';

  @override
  String get setup_backup_frequency_weekly => 'Wöchentlich';

  @override
  String get setup_backup_scheduleSubtitle => 'Ihre Daten regelmäßig sichern';

  @override
  String get setup_backup_scheduleToggle => 'Automatische Sicherungen';

  @override
  String get setup_backup_subtitle =>
      'Schützen Sie Ihre Daten vom ersten Tag an.';

  @override
  String get setup_backup_title => 'Sicherung & Synchronisierung';

  @override
  String get setup_common_back => 'Zurück';

  @override
  String get setup_common_next => 'Weiter';

  @override
  String get setup_common_skip => 'Überspringen';

  @override
  String get setup_existing_folder_subtitle =>
      'Submersion auf einen Ordner verweisen, der bereits eine Bibliothek enthält';

  @override
  String get setup_existing_folder_title => 'Vorhandenen Ordner öffnen';

  @override
  String get setup_existing_restore_subtitle =>
      'Eine aus Submersion exportierte Sicherungsdatei auswählen';

  @override
  String get setup_existing_restore_title => 'Sicherungsdatei wiederherstellen';

  @override
  String get setup_existing_subtitle =>
      'Wählen Sie, wie Ihre vorhandene Submersion-Bibliothek geladen werden soll';

  @override
  String get setup_existing_sync_subtitle =>
      'Ihre Bibliothek aus iCloud, Dropbox oder S3 laden';

  @override
  String get setup_existing_sync_title => 'Cloud-Synchronisierung verbinden';

  @override
  String get setup_existing_title => 'Daten übernehmen';

  @override
  String get setup_finish_applying => 'Wird eingerichtet...';

  @override
  String setup_finish_error(Object error) {
    return 'Einrichtung konnte nicht abgeschlossen werden: $error';
  }

  @override
  String get setup_finish_feature_diveComputer =>
      'Tauchgänge von Ihrem Tauchcomputer herunterladen';

  @override
  String get setup_finish_feature_gear =>
      'Ausrüstung und Wartungsintervalle verwalten';

  @override
  String get setup_finish_feature_import =>
      'Logbücher aus Dateien und anderen Apps importieren';

  @override
  String get setup_finish_feature_sites =>
      'Ihre Tauchplätze auf der Karte anzeigen';

  @override
  String get setup_finish_feature_statistics =>
      'Statistiken zu Ihren Tauchgängen entdecken';

  @override
  String get setup_finish_start => 'Loslegen';

  @override
  String get setup_finish_subtitle => 'Submersion kann außerdem...';

  @override
  String get setup_finish_title => 'Alles bereit';

  @override
  String get setup_folder_notFound_message =>
      'Der ausgewählte Ordner enthält keine Submersion-Datenbank.';

  @override
  String get setup_folder_notFound_title => 'Keine Bibliothek in diesem Ordner';

  @override
  String get setup_folder_pick => 'Ordner auswählen';

  @override
  String get setup_folder_switching => 'Bibliothek wird geöffnet...';

  @override
  String get setup_folder_title => 'Vorhandenen Ordner öffnen';

  @override
  String get setup_profile_nameHint => 'Geben Sie Ihren Namen ein';

  @override
  String get setup_profile_nameLabel => 'Ihr Name';

  @override
  String get setup_profile_nameValidation => 'Bitte geben Sie Ihren Namen ein';

  @override
  String get setup_profile_subtitle =>
      'Geben Sie Ihren Namen ein, um zu beginnen. Sie können später weitere Details hinzufügen.';

  @override
  String get setup_profile_title => 'Erstellen Sie Ihr Profil';

  @override
  String get setup_restore_inProgress => 'Wird wiederhergestellt...';

  @override
  String get setup_restore_pick => 'Sicherungsdatei auswählen';

  @override
  String get setup_restore_title => 'Sicherung wiederherstellen';

  @override
  String get setup_step_backup => 'Sicherung';

  @override
  String get setup_step_finish => 'Fertig';

  @override
  String get setup_step_profile => 'Profil';

  @override
  String get setup_step_units => 'Einheiten';

  @override
  String get setup_syncPull_continue => 'Weiter';

  @override
  String get setup_syncPull_incomplete_message =>
      'Auf diesem Konto liegt eine Submersion-Bibliothek, deren Upload nie abgeschlossen wurde. Lassen Sie Ihr anderes Gerät die Synchronisierung beenden und versuchen Sie es erneut.';

  @override
  String get setup_syncPull_incomplete_retry => 'Erneut prüfen';

  @override
  String get setup_syncPull_incomplete_title =>
      'Bibliothek-Upload unvollständig';

  @override
  String get setup_syncPull_locked_message =>
      'Geben Sie die Verschlüsselungs-Passphrase ein, um diese Bibliothek zu entsperren und auf dieses Gerät zu laden.';

  @override
  String get setup_syncPull_locked_title =>
      'Diese Bibliothek ist verschlüsselt';

  @override
  String get setup_syncPull_noLibrary_message =>
      'Auf diesem Konto wurde keine Submersion-Bibliothek gefunden. Stattdessen neu beginnen? Die Verbindung bleibt bestehen.';

  @override
  String get setup_syncPull_noLibrary_title => 'Keine Bibliothek gefunden';

  @override
  String get setup_syncPull_success => 'Bibliothek übernommen';

  @override
  String get setup_syncPull_syncing => 'Bibliothek wird geladen...';

  @override
  String get setup_syncPull_title => 'Verbinden und laden';

  @override
  String get setup_sync_changeProvider => 'Anbieter wechseln';

  @override
  String setup_sync_connectedTo(String provider) {
    return 'Verbunden mit $provider';
  }

  @override
  String setup_sync_error(Object error) {
    return 'Verbindung fehlgeschlagen: $error';
  }

  @override
  String get setup_sync_header => 'Cloud-Synchronisierung';

  @override
  String get setup_sync_libraryFound_adopt =>
      'Vorhandene Bibliothek übernehmen';

  @override
  String get setup_sync_libraryFound_keepFresh => 'Neu beginnen';

  @override
  String get setup_sync_libraryFound_message =>
      'Dieses Konto enthält bereits eine Submersion-Bibliothek. Diese übernehmen, statt neu zu beginnen?';

  @override
  String get setup_sync_libraryFound_title => 'Vorhandene Bibliothek gefunden';

  @override
  String get setup_sync_manageInSettings => 'In den Einstellungen verwalten';

  @override
  String get setup_sync_notConnected => 'Nicht verbunden';

  @override
  String get setup_sync_subtitle =>
      'Ihre Daten auf allen Geräten synchronisieren';

  @override
  String get setup_units_advanced => 'Einheiten anpassen';

  @override
  String get setup_units_altitude => 'Höhe';

  @override
  String get setup_units_dateFormat => 'Datumsformat';

  @override
  String get setup_units_depth => 'Tiefe';

  @override
  String get setup_units_imperial => 'Imperial';

  @override
  String get setup_units_metric => 'Metrisch';

  @override
  String get setup_units_pressure => 'Druck';

  @override
  String get setup_units_sac => 'AMV';

  @override
  String get setup_units_subtitle =>
      'Wählen Sie, wie Messwerte angezeigt werden. Jede Einheit lässt sich einzeln anpassen.';

  @override
  String get setup_units_temperature => 'Temperatur';

  @override
  String get setup_units_timeFormat => 'Zeitformat';

  @override
  String get setup_units_title => 'Einheiten';

  @override
  String get setup_units_volume => 'Volumen';

  @override
  String get setup_units_weight => 'Gewicht';

  @override
  String get setup_welcome_existingData_subtitle =>
      'Sicherung wiederherstellen, Cloud-Sync verbinden oder vorhandenen Ordner öffnen';

  @override
  String get setup_welcome_existingData_title =>
      'Ich habe bereits Submersion-Daten';

  @override
  String get setup_welcome_skipSetup => 'Einrichtung überspringen';

  @override
  String get setup_welcome_startFresh_subtitle =>
      'Taucherprofil erstellen und die App einrichten';

  @override
  String get setup_welcome_startFresh_title => 'Neues Profil einrichten';

  @override
  String get setup_welcome_subtitle =>
      'Erweiterte Tauchprotokollierung und -analyse';

  @override
  String get setup_welcome_title => 'Willkommen bei Submersion';

  @override
  String get siteMatchReview_title => 'Tauchplätze zuordnen';

  @override
  String siteMatchReview_diveNumber(Object number) {
    return 'Tauchgang #$number';
  }

  @override
  String get siteMatchReview_empty => 'Nichts zuzuordnen.';

  @override
  String siteMatchReview_summary(int selected, int review, int none) {
    return '$selected ausgewählt · $review zu prüfen · $none ohne Treffer';
  }

  @override
  String siteMatchReview_confirm(int count) {
    return '$count Zuordnungen bestätigen';
  }

  @override
  String get siteMatchReview_cancel => 'Abbrechen';

  @override
  String get siteMatchReview_tapToChoose =>
      'Tippen, um einen Tauchplatz zu wählen';

  @override
  String siteMatchReview_awayMeters(int meters) {
    return '$meters m entfernt';
  }

  @override
  String siteMatchReview_depthTo(int meters) {
    return 'bis $meters m';
  }

  @override
  String siteMatchReview_depthRange(int min, int max) {
    return '$min–$max m';
  }

  @override
  String siteMatchReview_appliedSnack(int dives, int sites) {
    return '$dives Tauchgänge verknüpft · $sites Tauchplätze hinzugefügt';
  }

  @override
  String get siteMatchReview_applyError =>
      'Zuordnungen konnten nicht angewendet werden';

  @override
  String get siteMatchReview_discardTitle => 'Zuordnungen verwerfen?';

  @override
  String get siteMatchReview_discardMessage =>
      'Ihre Auswahl wird nicht gespeichert.';

  @override
  String get siteMatchReview_discardConfirm => 'Verwerfen';

  @override
  String get siteMatchReview_keepReviewing => 'Weiter prüfen';

  @override
  String get siteMatchReview_sourceExisting => 'Ihr Tauchplatz';

  @override
  String get siteMatchReview_sourceBundled => 'Import';

  @override
  String get siteMatchReview_noNearbySite => 'Kein Tauchplatz in der Nähe';

  @override
  String importSummary_matchSitesButton(int count) {
    return '$count Tauchgänge Tauchplätzen zuordnen';
  }

  @override
  String get diveLog_listPage_searchFieldLabel => 'Tauchgänge suchen...';

  @override
  String diveLog_listPage_searchLimitNotice(int limit) {
    return 'Die ersten $limit Treffer werden angezeigt. Verfeinern Sie die Suche, um die Ergebnisse einzugrenzen.';
  }

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return 'Keine Tauchgänge gefunden für \"$query\"';
  }

  @override
  String get diveLog_listPage_searchSuggestion =>
      'Nach Tauchplatz, Tauchpartner oder Notizen suchen';

  @override
  String get diveLog_listPage_title => 'Tauchlogbuch';

  @override
  String get diveLog_listPage_tooltip_back => 'Zurück';

  @override
  String get diveLog_listPage_tooltip_backToDiveList =>
      'Zurück zur Tauchgangliste';

  @override
  String get diveLog_listPage_tooltip_clearSearch => 'Suche löschen';

  @override
  String get diveLog_listPage_tooltip_filterDives => 'Tauchgänge filtern';

  @override
  String get diveLog_listPage_tooltip_listView => 'Listenansicht';

  @override
  String get diveLog_listPage_tooltip_mapView => 'Kartenansicht';

  @override
  String get diveLog_listPage_tooltip_searchDives => 'Tauchgänge suchen';

  @override
  String get diveLog_listPage_tooltip_sort => 'Sortieren';

  @override
  String get diveLog_listPage_unknownSite => 'Unbekannter Tauchplatz';

  @override
  String get diveLog_map_emptySubtitle =>
      'Erfassen Sie Tauchgänge mit Standortdaten, um Ihre Aktivität auf der Karte zu sehen';

  @override
  String get diveLog_map_emptyTitle => 'Keine Tauchaktivität zum Anzeigen';

  @override
  String diveLog_map_errorLoading(Object error) {
    return 'Fehler beim Laden der Tauchdaten: $error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => 'Alle Tauchplätze anzeigen';

  @override
  String get diveLog_numbering_actions => 'Aktionen';

  @override
  String get diveLog_numbering_allCorrect =>
      'Alle Tauchgänge korrekt nummeriert';

  @override
  String get diveLog_numbering_assignMissing => 'Fehlende Nummern zuweisen';

  @override
  String get diveLog_numbering_assignMissingDesc =>
      'Nicht nummerierte Tauchgänge ab der letzten vergebenen Nummer nummerieren';

  @override
  String get diveLog_numbering_close => 'Schließen';

  @override
  String get diveLog_numbering_gapsDetected => 'Lücken erkannt';

  @override
  String get diveLog_numbering_issuesDetected => 'Probleme erkannt';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '$count fehlend';
  }

  @override
  String get diveLog_numbering_renumberAll => 'Alle Tauchgänge neu nummerieren';

  @override
  String get diveLog_numbering_renumberAllDesc =>
      'Fortlaufende Nummern basierend auf Datum/Uhrzeit des Tauchgangs zuweisen';

  @override
  String get diveLog_numbering_renumberDialog_cancel => 'Abbrechen';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      'Alle Tauchgänge werden basierend auf dem Einstiegsdatum/-zeit fortlaufend neu nummeriert. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get diveLog_numbering_renumberDialog_renumber => 'Neu nummerieren';

  @override
  String get diveLog_numbering_renumberDialog_startFrom => 'Startnummer';

  @override
  String get diveLog_numbering_renumberDialog_title =>
      'Alle Tauchgänge neu nummerieren';

  @override
  String get diveLog_numbering_snackbar_assigned =>
      'Fehlende Tauchgangnummern zugewiesen';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return 'Alle Tauchgänge ab #$number neu nummeriert';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '$total Tauchgänge gesamt - $numbered nummeriert';
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
  String get diveLog_o2tox_label_timeAbove14 => 'Zeit über 1,4 bar';

  @override
  String get diveLog_o2tox_label_timeAbove16 => 'Zeit über 1,6 bar';

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
      'Kritische Sauerstofftoxizitätswarnung';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return 'Sauerstofftoleranzeinheiten: $value, $percent Prozent des Tageslimits';
  }

  @override
  String get diveLog_o2tox_semantics_warning => 'Sauerstofftoxizitätswarnung';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return 'Start: $value%';
  }

  @override
  String get diveLog_o2tox_title => 'Sauerstofftoxizität';

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
  String get diveLog_playback_tooltip_back10 => '10 Sekunden zurück';

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
      'Rechte Achsenmetrik ändern';

  @override
  String get diveLog_profile_semantics_chart =>
      'Tauchprofildiagramm, zum Zoomen zusammendrücken';

  @override
  String get diveLog_profile_semantics_photoMarker => 'Fotomarkierung';

  @override
  String get diveLog_profile_tooltip_moreOptions => 'Weitere Diagrammoptionen';

  @override
  String get diveLog_profile_tooltip_resetZoom => 'Zoom zurücksetzen';

  @override
  String get diveLog_profile_tooltip_zoomIn => 'Vergrößern';

  @override
  String get diveLog_profile_tooltip_zoomOut => 'Verkleinern';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return 'Zoom: ${level}x - Zum Zoomen zusammendrücken oder scrollen, zum Verschieben ziehen';
  }

  @override
  String get diveLog_rangeSelection_exitRange => 'Bereich beenden';

  @override
  String get diveLog_rangeSelection_selectRange => 'Bereich auswählen';

  @override
  String get diveLog_rangeSelection_semantics_adjust =>
      'Bereichsauswahl anpassen';

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
  String get diveLog_rangeStats_label_sacRate => 'AMV';

  @override
  String get diveLog_rangeStats_title => 'Bereichsstatistik';

  @override
  String get diveLog_rangeStats_tooltip_close => 'Bereichsanalyse schließen';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return 'Berechneter Loop-FO₂: $value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => 'z.B. 0,33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => 'Zumischungsverhältnis';

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
  String get diveLog_scr_label_orificeSize => 'Düsengröße';

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
  String get diveLog_search_clearAll => 'Alles löschen';

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
  String get diveLog_search_filter_any => 'Beliebig';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_deco => 'Dekompression';

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
  String get diveLog_search_section_gasEquipment => 'Gas & Ausrüstung';

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
    return '$count ausgewählt';
  }

  @override
  String get diveLog_selection_tooltip_combine => 'Kombinieren';

  @override
  String get diveLog_selection_tooltip_delete => 'Auswahl löschen';

  @override
  String get diveLog_selection_tooltip_deselectAll => 'Alle abwählen';

  @override
  String get diveLog_selection_tooltip_edit => 'Auswahl bearbeiten';

  @override
  String get diveLog_selection_tooltip_exit => 'Auswahl beenden';

  @override
  String get diveLog_selection_tooltip_export => 'Auswahl exportieren';

  @override
  String get diveLog_selection_tooltip_selectAll => 'Alle auswählen';

  @override
  String get diveLog_selection_tooltip_selectDateRange =>
      'Nach Datumsbereich auswählen';

  @override
  String get diveLog_sighting_add => 'Hinzufügen';

  @override
  String get diveLog_sighting_cancel => 'Abbrechen';

  @override
  String get diveLog_sighting_notesHint => 'z. B. Größe, Verhalten, Ort...';

  @override
  String get diveLog_sighting_notesOptional => 'Notizen (optional)';

  @override
  String get diveLog_sitePicker_addDiveSite => 'Tauchplatz hinzufügen';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return '$distance km entfernt';
  }

  @override
  String diveLog_sitePicker_distanceAway(String distance) {
    return '$distance entfernt';
  }

  @override
  String get diveLog_sitePicker_sortedByDiveDistance =>
      'Nach Entfernung zu diesem Tauchgang sortiert';

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return '$distance m entfernt';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return 'Fehler beim Laden der Plätze: $error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => 'Neuer Tauchplatz';

  @override
  String get diveLog_sitePicker_noSites => 'Noch keine Tauchplätze';

  @override
  String get diveLog_sitePicker_sortedByDistance => 'Nach Entfernung sortiert';

  @override
  String get diveLog_sitePicker_title => 'Tauchplatz auswählen';

  @override
  String get diveLog_sort_title => 'Tauchgänge sortieren';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return '\"$name\" als neue Art hinzufügen';
  }

  @override
  String get diveLog_speciesPicker_noResults => 'Keine Arten gefunden';

  @override
  String get diveLog_speciesPicker_noSpecies => 'Keine Arten verfügbar';

  @override
  String get diveLog_speciesPicker_searchHint => 'Arten suchen...';

  @override
  String get diveLog_speciesPicker_title => 'Meeresbewohner hinzufügen';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch => 'Suche löschen';

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
  String get diveLog_summary_overview => 'Übersicht';

  @override
  String get diveLog_summary_record_coldest => 'Kältester Tauchgang';

  @override
  String get diveLog_summary_record_deepest => 'Tiefster Tauchgang';

  @override
  String get diveLog_summary_record_longest => 'Längster Tauchgang';

  @override
  String get diveLog_summary_record_warmest => 'Wärmster Tauchgang';

  @override
  String get diveLog_summary_section_mostVisited => 'Meistbesuchte Tauchplätze';

  @override
  String get diveLog_summary_section_quickActions => 'Schnellaktionen';

  @override
  String get diveLog_summary_section_records => 'Persönliche Rekorde';

  @override
  String get diveLog_summary_selectDive =>
      'Wählen Sie einen Tauchgang aus der Liste, um Details anzuzeigen';

  @override
  String get diveLog_summary_stat_avgMaxDepth => 'Durchschn. max. Tiefe';

  @override
  String get diveLog_summary_stat_avgWaterTemp => 'Durchschn. Wassertemp.';

  @override
  String get diveLog_summary_stat_diveSites => 'Tauchplätze';

  @override
  String get diveLog_summary_stat_diveTime => 'Tauchzeit';

  @override
  String get diveLog_summary_stat_maxDepth => 'Max. Tiefe';

  @override
  String get diveLog_summary_stat_totalDives => 'Tauchgänge gesamt';

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
  String get diveLog_tank_mndHelper => 'Auf automatische He%-Berechnung setzen';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1,4)';
  }

  @override
  String diveLog_tank_modMndInfo(Object mod, Object mnd) {
    return 'MOD: $mod (ppO₂ 1,4) | MND: $mnd';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Gasgemisch';

  @override
  String get diveLog_tank_selectPreset => 'Vorlage auswählen...';

  @override
  String get diveLog_tank_saveAsPreset => 'Als Vorlage speichern';

  @override
  String get diveLog_tank_saveAsPreset_needSpecs =>
      'Zuerst Volumen und Arbeitsdruck eingeben';

  @override
  String get diveLog_tank_saveAsPreset_nameTitle => 'Flaschenvorlage speichern';

  @override
  String get diveLog_tank_saveAsPreset_nameHint => 'z. B. Meine AL80';

  @override
  String diveLog_tank_saveAsPreset_saved(String name) {
    return 'Vorlage \"$name\" gespeichert';
  }

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
  String get diveLog_tissue_title => 'Gewebesättigung';

  @override
  String get diveLog_tooltip_avgCalculated => '(Durchschn., berechnet)';

  @override
  String get diveLog_tooltip_ceiling => 'Ceiling';

  @override
  String get diveLog_tooltip_decoStop => 'Deco stop';

  @override
  String get diveLog_tooltip_cns => 'CNS';

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
  String get diveLog_tooltip_otu => 'OTU';

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
  String get diveLog_tooltip_sensor => 'Sensor';

  @override
  String get diveLog_legend_label_o2Cells => 'O2-Zellen';

  @override
  String get diveLog_tooltip_o2CellsTight => 'eng';

  @override
  String get diveLog_tooltip_o2CellsDrifting => 'driftet';

  @override
  String get diveLog_tooltip_o2CellsWide => 'weit';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Zeit';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get diveLog_sources_row_metric => 'Messwert';

  @override
  String get diveLog_sources_row_maxDepth => 'Max. Tiefe';

  @override
  String get diveLog_sources_row_avgDepth => 'Ø Tiefe';

  @override
  String get diveLog_sources_row_duration => 'Dauer';

  @override
  String get diveLog_sources_row_waterTemp => 'Wassertemp.';

  @override
  String get diveLog_sources_row_cns => 'CNS';

  @override
  String get diveLog_sources_row_otu => 'OTU';

  @override
  String get diveLog_sources_row_decoAlgorithm => 'Deko-Algorithmus';

  @override
  String get diveLog_sources_row_gf => 'GF';

  @override
  String diveLog_sources_minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Min.',
      one: '1 Min.',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_unknownComputer => 'Unbekannter Computer';

  @override
  String get diveLog_sources_manualEntry => 'Manueller Eintrag';

  @override
  String get diveLog_sources_importedFile => 'Importierte Datei';

  @override
  String get diveLog_sources_editedSuffix => ' (bearbeitet)';

  @override
  String get diveLog_sources_barLabel => 'QUELLEN';

  @override
  String get diveLog_sources_menu_setPrimary => 'Als primär festlegen';

  @override
  String get diveLog_sources_menu_split => 'In separaten Tauchgang aufteilen';

  @override
  String get diveLog_sources_overlayTooltip => 'Im Diagramm überlagern';

  @override
  String get diveLog_sources_splitDialog_title =>
      'In separaten Tauchgang aufteilen?';

  @override
  String get diveLog_sources_splitDialog_body =>
      'Profil, Ereignisse und Flaschen dieser Quelle werden in einen neuen Tauchgang verschoben. Der Logbucheintrag bleibt bei diesem Tauchgang.';

  @override
  String get diveLog_sources_splitDialog_confirm => 'Aufteilen';

  @override
  String get diveLog_sources_splitDone => 'Tauchgang aufgeteilt';

  @override
  String get diveLog_sources_splitFailed => 'Aufteilen fehlgeschlagen';

  @override
  String get divePlanner_action_addTank => 'Flasche hinzufügen';

  @override
  String get divePlanner_action_convertToDive => 'In Tauchgang umwandeln';

  @override
  String get divePlanner_action_deletePlan => 'Plan löschen';

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
  String get divePlanner_error_reserveExceedsTank =>
      'Überschreitet Flaschendruck';

  @override
  String get divePlanner_error_reserveMustBePositive =>
      'Muss größer als 0 sein';

  @override
  String divePlanner_info_reserveDefault(Object unit, Object value) {
    return 'Nicht eingegeben — Annahme $value $unit';
  }

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
  String get divePlanner_field_travelGas => 'Wird auch als Reisegas verwendet';

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
  String get divePlanner_label_reserve => 'Reserve:';

  @override
  String get divePlanner_label_runtime => 'Laufzeit';

  @override
  String get divePlanner_label_sacRate => 'AMV:';

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
  String divePlanner_message_deleteConfirmation(String name) {
    return '\'$name\' löschen?';
  }

  @override
  String get divePlanner_message_planDeleted => 'Plan gelöscht';

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
  String get diveSites_detail_altitude_elevation => 'Höhe';

  @override
  String get diveSites_detail_altitude_pressure => 'Druck';

  @override
  String get diveSites_detail_coordinatesCopied =>
      'Koordinaten in die Zwischenablage kopiert';

  @override
  String get diveSites_detail_deleteDialog_cancel => 'Abbrechen';

  @override
  String get diveSites_detail_deleteDialog_confirm => 'Löschen';

  @override
  String get diveSites_detail_deleteDialog_content =>
      'Sind Sie sicher, dass Sie diesen Tauchplatz löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get diveSites_detail_deleteDialog_title => 'Tauchplatz löschen';

  @override
  String get diveSites_detail_deleteMenu_label => 'Löschen';

  @override
  String get diveSites_detail_deleteSnackbar => 'Tauchplatz gelöscht';

  @override
  String get diveSites_detail_depth_maximum => 'Maximum';

  @override
  String get diveSites_detail_depth_minimum => 'Minimum';

  @override
  String get diveSites_detail_diveCount_one => '1 Tauchgang eingetragen';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '$count Tauchgänge eingetragen';
  }

  @override
  String get diveSites_detail_diveCount_zero =>
      'Noch keine Tauchgänge eingetragen';

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
  String get diveSites_detail_location_city => 'Stadt';

  @override
  String get diveSites_detail_location_island => 'Insel';

  @override
  String get diveSites_detail_location_bodyOfWater => 'Gewässer';

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
  String get diveSites_detail_section_altitude => 'Höhenlage';

  @override
  String get diveSites_detail_section_depthRange => 'Tiefenbereich';

  @override
  String get diveSites_detail_section_description => 'Beschreibung';

  @override
  String get diveSites_detail_section_difficultyLevel => 'Schwierigkeitsgrad';

  @override
  String get diveSites_detail_section_divesAtSite =>
      'Tauchgänge an diesem Platz';

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
      'Tauchgänge an diesem Platz anzeigen';

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
  String get diveSites_difficulty_beginner => 'Anfänger';

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
      'Parkverfügbarkeit, Gebühren, Tipps';

  @override
  String get diveSites_edit_access_parkingInfo_label => 'Parkinformationen';

  @override
  String get diveSites_edit_access_entryMethod_label => 'Einstiegsart';

  @override
  String get diveSites_edit_access_exitMethod_label => 'Ausstiegsart';

  @override
  String diveSites_edit_access_entrySuggestionPair(
    int count,
    String entry,
    String exit,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deine $count Tauchgänge hier: Einstieg $entry, Ausstieg $exit',
      one: 'Dein Tauchgang hier: Einstieg $entry, Ausstieg $exit',
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
      other: 'Deine $count Tauchgänge hier: Einstieg $entry',
      one: 'Dein Tauchgang hier: Einstieg $entry',
    );
    return '$_temp0';
  }

  @override
  String get diveSites_detail_access_entryMethod => 'Einstieg';

  @override
  String get diveSites_detail_access_exitMethod => 'Ausstieg';

  @override
  String get diveSites_edit_altitude_helperText =>
      'Höhe des Tauchplatzes über dem Meeresspiegel (für Bergseetauchen)';

  @override
  String get diveSites_edit_altitude_hint => 'z. B. 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return 'Höhe ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => 'Ungültige Höhe';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => 'Tauchplatz löschen';

  @override
  String get diveSites_edit_appBar_editSite => 'Tauchplatz bearbeiten';

  @override
  String get diveSites_edit_appBar_merge => 'Zusammenführen';

  @override
  String get diveSites_edit_appBar_mergeSites => 'Tauchplätze zusammenführen';

  @override
  String get diveSites_edit_appBar_newSite => 'Neuer Tauchplatz';

  @override
  String get diveSites_edit_appBar_save => 'Speichern';

  @override
  String get diveSites_edit_button_addSite => 'Tauchplatz hinzufügen';

  @override
  String get diveSites_edit_button_mergeSites => 'Tauchplätze zusammenführen';

  @override
  String get diveSites_edit_button_saveChanges => 'Änderungen speichern';

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
      'Sie haben ungespeicherte Änderungen. Sind Sie sicher, dass Sie die Seite verlassen möchten?';

  @override
  String get diveSites_edit_discardDialog_discard => 'Verwerfen';

  @override
  String get diveSites_edit_discardDialog_keepEditing => 'Weiter bearbeiten';

  @override
  String get diveSites_edit_discardDialog_title => 'Änderungen verwerfen?';

  @override
  String get diveSites_edit_field_country_label => 'Land';

  @override
  String get diveSites_edit_field_city_label => 'Stadt';

  @override
  String get diveSites_edit_field_island_label => 'Insel';

  @override
  String get diveSites_edit_field_bodyOfWater_label => 'Gewässer';

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
  String diveSites_similarSite_useHint(Object siteName) {
    return 'Ähnelt vorhandenem Tauchplatz „$siteName“. Zum Verwenden tippen.';
  }

  @override
  String diveSites_similarSite_warning(Object siteName) {
    return 'Ein ähnlicher Tauchplatz existiert bereits: „$siteName“';
  }

  @override
  String get diveSites_edit_gps_gettingLocation => 'Wird ermittelt...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Wählen Sie eine Standortmethode oder suchen Sie die Koordinaten, um Land, Region, Ort und Gewässer automatisch auszufüllen';

  @override
  String get diveSites_edit_gps_latitude_hint => 'z. B. 21,4225';

  @override
  String get diveSites_edit_gps_latitude_label => 'Breitengrad';

  @override
  String get diveSites_edit_gps_latitude_validation => 'Ungültiger Breitengrad';

  @override
  String get diveSites_edit_gps_longitude_hint => 'z. B. -86,7542';

  @override
  String get diveSites_edit_gps_longitude_label => 'Längengrad';

  @override
  String get diveSites_edit_gps_longitude_validation => 'Ungültiger Längengrad';

  @override
  String get diveSites_edit_gps_pickFromMap => 'Auf Karte auswählen';

  @override
  String get diveSites_edit_gps_lookupFromCoordinates =>
      'Aus Koordinaten ermitteln';

  @override
  String get diveSites_edit_snackbar_lookupNothingFound =>
      'Keine Ortsangaben für diese Koordinaten gefunden';

  @override
  String get diveSites_edit_snackbar_lookupFailed =>
      'Ortssuche fehlgeschlagen. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get diveSites_edit_lookupReplace_title => 'Ortsangaben ersetzen?';

  @override
  String get diveSites_edit_lookupReplace_body =>
      'Die Suche hat für diese Felder andere Werte gefunden:';

  @override
  String get diveSites_edit_lookupReplace_replace => 'Ersetzen';

  @override
  String get diveSites_edit_lookupReplace_keep => 'Behalten';

  @override
  String get diveSites_edit_gps_useMyLocation => 'Meinen Standort verwenden';

  @override
  String get diveSites_edit_hazards_helperText =>
      'Listen Sie alle Gefahren oder Sicherheitshinweise auf';

  @override
  String get diveSites_edit_hazards_hint =>
      'z. B. Starke Strömungen, Bootsverkehr, Quallen, scharfe Korallen';

  @override
  String get diveSites_edit_hazards_label => 'Gefahren';

  @override
  String get diveSites_edit_marineLife_addButton => 'Hinzufügen';

  @override
  String get diveSites_edit_marineLife_empty =>
      'Keine erwarteten Arten hinzugefügt';

  @override
  String get diveSites_edit_marineLife_helperText =>
      'Arten, die Sie an diesem Tauchplatz erwarten';

  @override
  String diveSites_edit_merge_confirmBody(int count) {
    return 'Dies wird $count Tauchplätze zu einem zusammenführen. Tauchgänge, Medien und erwartete Arten werden unter dem verbleibenden Tauchplatz zusammengefasst. Die anderen Tauchplätze werden gelöscht.';
  }

  @override
  String get diveSites_edit_merge_confirmTitle => 'Tauchplätze zusammenführen';

  @override
  String get diveSites_edit_merge_fieldSourceCycleTooltip =>
      'Wert vom nächsten ausgewählten Standort verwenden';

  @override
  String diveSites_edit_merge_fieldSourceLabel(
    Object siteName,
    int current,
    int total,
  ) {
    return 'Von $siteName ($current/$total)';
  }

  @override
  String get diveSites_edit_merge_fieldSourceMenuTooltip =>
      'Wert vom ausgewählten Standort auswählen';

  @override
  String get diveSites_edit_merge_marineLifeHelperText =>
      'Zusammengefasst aus allen ausgewählten Tauchplätzen';

  @override
  String diveSites_edit_merge_loadingErrorBody(Object error) {
    return 'Fehler beim Laden der Tauchplätze: $error';
  }

  @override
  String get diveSites_edit_merge_loadingErrorTitle =>
      'Tauchplätze zusammenführen';

  @override
  String get diveSites_edit_merge_notEnoughBody =>
      'Nicht genügend Tauchplätze zum Zusammenführen.';

  @override
  String get diveSites_edit_merge_notEnoughTitle =>
      'Tauchplätze zusammenführen';

  @override
  String get diveSites_edit_rating_clear => 'Bewertung löschen';

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
  String get diveSites_edit_section_altitude => 'Höhenlage';

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
  String get diveSites_edit_section_waterType => 'Gewässertyp';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return 'Fehler beim Löschen des Tauchplatzes: $error';
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
      'Standort von Karte ausgewählt';

  @override
  String get diveSites_edit_snackbar_locationSettings => 'Einstellungen';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      'Standort konnte nicht ermittelt werden. Ortungsdienste sind möglicherweise nicht verfügbar.';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      'Standort konnte nicht ermittelt werden. Bitte überprüfen Sie die Berechtigungen.';

  @override
  String get diveSites_edit_snackbar_siteAdded => 'Tauchplatz hinzugefügt';

  @override
  String get diveSites_edit_snackbar_sitesMerged =>
      'Tauchplätze zusammengeführt';

  @override
  String get diveSites_edit_snackbar_siteUpdated => 'Tauchplatz aktualisiert';

  @override
  String get diveSites_fab_label => 'Tauchplatz hinzufügen';

  @override
  String get diveSites_fab_tooltip => 'Neuen Tauchplatz hinzufügen';

  @override
  String get diveSites_filter_apply => 'Filter anwenden';

  @override
  String get diveSites_filter_cancel => 'Abbrechen';

  @override
  String get diveSites_filter_clearAll => 'Alle löschen';

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
      'Nur Plätze mit GPS-Standort anzeigen';

  @override
  String get diveSites_filter_option_hasCoordinates_title => 'Hat Koordinaten';

  @override
  String get diveSites_filter_option_hasDives_subtitle =>
      'Nur Plätze mit eingetragenen Tauchgängen anzeigen';

  @override
  String get diveSites_filter_option_hasDives_title => 'Hat Tauchgänge';

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
  String get diveSites_filter_title => 'Tauchplätze filtern';

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
      'Zu meinen Tauchplätzen importieren';

  @override
  String diveSites_import_detail_source(Object source) {
    return 'Quelle: $source';
  }

  @override
  String get diveSites_import_empty_description =>
      'Suchen Sie nach Tauchplätzen aus unserer Datenbank beliebter\nTauchziele weltweit.';

  @override
  String get diveSites_import_empty_hint =>
      'Versuchen Sie, nach Tauchplatzname, Land oder Region zu suchen.';

  @override
  String get diveSites_import_empty_title => 'Tauchplätze suchen';

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
    return 'Keine Tauchplätze für \"$query\" gefunden.\nVersuchen Sie einen anderen Suchbegriff.';
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
  String get diveSites_import_search_clearTooltip => 'Suche löschen';

  @override
  String get diveSites_import_search_hint =>
      'Tauchplätze suchen (z. B. \"Blue Hole\", \"Thailand\")';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return 'Aus Datenbank importieren ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return 'Meine Tauchplätze ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return 'Details für $name anzeigen';
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
  String get diveSites_list_activeFilter_clear => 'Löschen';

  @override
  String diveSites_list_activeFilter_country(Object country) {
    return 'Land: $country';
  }

  @override
  String diveSites_list_activeFilter_depthRangeBoth(Object min, Object max) {
    return '$min-$max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Bis zu $max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '$min+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => 'Hat Koordinaten';

  @override
  String get diveSites_list_activeFilter_hasDives => 'Hat Tauchgänge';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return 'Region: $region';
  }

  @override
  String get diveSites_list_appBar_title => 'Tauchplätze';

  @override
  String get diveSites_list_bulkDelete_cancel => 'Abbrechen';

  @override
  String get diveSites_list_bulkDelete_confirm => 'Löschen';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchplaetze',
      one: 'Tauchplatz',
    );
    return 'Sind Sie sicher, dass Sie $count $_temp0 löschen möchten? Diese Aktion kann innerhalb von 5 Sekunden rückgängig gemacht werden.';
  }

  @override
  String get diveSites_list_bulkDelete_restored =>
      'Tauchplätze wiederhergestellt';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchplaetze',
      one: 'Tauchplatz',
    );
    return '$count $_temp0 gelöscht';
  }

  @override
  String get diveSites_list_bulkDelete_title => 'Tauchplätze löschen';

  @override
  String get diveSites_list_bulkDelete_undo => 'Rückgängig';

  @override
  String get diveSites_list_merge_restored =>
      'Zusammenführung rückgängig gemacht';

  @override
  String diveSites_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchplaetze',
      one: 'Tauchplatz',
    );
    return '$count $_temp0 zusammengeführt';
  }

  @override
  String get diveSites_list_merge_undo => 'Rückgängig';

  @override
  String get diveSites_list_emptyFiltered_clearAll => 'Alle Filter löschen';

  @override
  String get diveSites_list_emptyFiltered_subtitle =>
      'Versuchen Sie, Ihre Filter anzupassen oder zu löschen';

  @override
  String get diveSites_list_emptyFiltered_title =>
      'Keine Tauchplätze entsprechen Ihren Filtern';

  @override
  String get diveSites_list_empty_addFirstSite =>
      'Ersten Tauchplatz hinzufügen';

  @override
  String get diveSites_list_empty_import => 'Importieren';

  @override
  String get diveSites_list_empty_subtitle =>
      'Fügen Sie Tauchplätze hinzu, um Ihre Lieblingsorte zu verfolgen';

  @override
  String get diveSites_list_empty_title => 'Noch keine Tauchplätze';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return 'Fehler beim Laden der Tauchplätze: $error';
  }

  @override
  String get diveSites_list_error_retry => 'Erneut versuchen';

  @override
  String get diveSites_list_menu_import => 'Importieren';

  @override
  String get diveSites_list_menu_select => 'Tauchplätze auswählen';

  @override
  String get diveSites_list_menu_fillLocationDetails =>
      'Fehlende Ortsangaben ergänzen';

  @override
  String get diveSites_backfill_confirm_title =>
      'Fehlende Ortsangaben ergänzen?';

  @override
  String diveSites_backfill_confirm_body(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Tauchplätze mit Koordinaten haben kein Land, keine Region, keinen Ort oder kein Gewässer.',
      one:
          '1 Tauchplatz mit Koordinaten hat kein Land, keine Region, keinen Ort oder kein Gewässer.',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes Minuten',
      one: '1 Minute',
    );
    return '$_temp0 Submersion sucht jeden auf OpenStreetMap und füllt nur die leeren Felder aus. Das dauert etwa $_temp1.';
  }

  @override
  String get diveSites_backfill_confirm_start => 'Starten';

  @override
  String get diveSites_backfill_nothingToFill =>
      'Alle Tauchplätze mit Koordinaten haben bereits ihre Ortsangaben.';

  @override
  String get diveSites_backfill_progress_title => 'Ortsangaben werden ergänzt';

  @override
  String diveSites_backfill_progress_count(int done, int total) {
    return '$done von $total';
  }

  @override
  String get diveSites_backfill_cancel => 'Abbrechen';

  @override
  String diveSites_backfill_summary(int updated, int unchanged, int failed) {
    return 'Aktualisiert $updated, unverändert $unchanged, fehlgeschlagen $failed';
  }

  @override
  String get diveSites_backfill_offline =>
      'Die Ortssuche ist nicht verfügbar. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get diveSites_list_search_backTooltip => 'Zurück';

  @override
  String get diveSites_list_search_clearTooltip => 'Suche löschen';

  @override
  String get diveSites_list_search_emptyHint =>
      'Suche nach Tauchplatzname, Land oder Region';

  @override
  String diveSites_list_search_error(Object error) {
    return 'Fehler: $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return 'Keine Tauchplätze für \"$query\" gefunden';
  }

  @override
  String get diveSites_list_search_placeholder => 'Tauchplätze suchen...';

  @override
  String get diveSites_list_selection_closeTooltip => 'Auswahl schließen';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count ausgewählt';
  }

  @override
  String get diveSites_list_selection_deleteTooltip => 'Auswahl löschen';

  @override
  String get diveSites_list_selection_mergeTooltip =>
      'Ausgewählte zusammenführen';

  @override
  String get diveSites_list_selection_deselectAllTooltip => 'Alle abwählen';

  @override
  String get diveSites_list_selection_selectAllTooltip => 'Alle auswählen';

  @override
  String get diveSites_list_sort_title => 'Tauchplätze sortieren';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge',
      one: '1 Tauchgang',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return 'Tauchplatz: $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => 'Tauchplätze filtern';

  @override
  String get diveSites_list_tooltip_mapView => 'Kartenansicht';

  @override
  String get diveSites_list_tooltip_searchSites => 'Tauchplätze suchen';

  @override
  String get diveSites_list_tooltip_sort => 'Sortieren';

  @override
  String get diveSites_locationPicker_appBar_title => 'Standort auswählen';

  @override
  String get diveSites_locationPicker_confirmButton => 'Bestätigen';

  @override
  String get diveSites_locationPicker_confirmTooltip =>
      'Ausgewählten Standort bestätigen';

  @override
  String get diveSites_locationPicker_fab_tooltip =>
      'Meinen Standort verwenden';

  @override
  String get diveSites_locationPicker_instruction_locationSelected =>
      'Standort ausgewählt';

  @override
  String get diveSites_locationPicker_instruction_lookingUp =>
      'Standort wird ermittelt...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect =>
      'Tippen Sie auf die Karte, um einen Standort auszuwählen';

  @override
  String get diveSites_locationPicker_label_latitude => 'Breitengrad';

  @override
  String get diveSites_locationPicker_label_longitude => 'Längengrad';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return 'Ausgewählte Koordinaten: Breitengrad $latitude, Längengrad $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp =>
      'Standort wird ermittelt';

  @override
  String get diveSites_locationPicker_semantics_map =>
      'Interaktive Karte zur Auswahl eines Tauchplatz-Standorts. Tippen Sie auf die Karte, um einen Standort auszuwählen.';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return 'Fehler beim Laden der Tauchplätze: $error';
  }

  @override
  String get diveSites_map_appBar_title => 'Tauchplätze';

  @override
  String get diveSites_map_builtInSites_add =>
      'Zu meinen Tauchplätzen hinzufügen';

  @override
  String get diveSites_map_builtInSites_addError =>
      'Tauchplatz konnte nicht hinzugefügt werden. Bitte erneut versuchen.';

  @override
  String get diveSites_map_builtInSites_added =>
      'Zu Ihren Tauchplätzen hinzugefügt';

  @override
  String get diveSites_map_builtInSites_hide =>
      'Integrierte Tauchplätze ausblenden';

  @override
  String get diveSites_map_builtInSites_off =>
      'Integrierte Tauchplätze ausgeblendet';

  @override
  String get diveSites_map_builtInSites_on =>
      'Integrierte Tauchplätze angezeigt';

  @override
  String get diveSites_map_builtInSites_show =>
      'Integrierte Tauchplätze anzeigen';

  @override
  String get diveSites_map_empty_description =>
      'Fügen Sie Ihren Tauchplätzen Koordinaten hinzu, um sie auf der Karte zu sehen';

  @override
  String get diveSites_map_empty_title => 'Keine Tauchplätze mit Koordinaten';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return 'Fehler beim Laden der Tauchplätze: $error';
  }

  @override
  String get diveSites_map_error_retry => 'Erneut versuchen';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge',
      one: '1 Tauchgang',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_builtInSiteMarker(Object name) {
    return 'Integrierter Tauchplatz: $name';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return 'Tauchplatz: $name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => 'Alle Tauchplätze einpassen';

  @override
  String get diveSites_map_tooltip_listView => 'Listenansicht';

  @override
  String get diveSites_summary_action_addSite => 'Tauchplatz hinzufügen';

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
      'Wählen Sie einen Tauchplatz aus der Liste, um Details anzuzeigen';

  @override
  String get diveSites_summary_header_title => 'Tauchplätze';

  @override
  String get diveSites_summary_section_countriesRegions => 'Länder & Regionen';

  @override
  String get diveSites_summary_section_mostDived => 'Am meisten betaucht';

  @override
  String get diveSites_summary_section_overview => 'Übersicht';

  @override
  String get diveSites_summary_section_quickActions => 'Schnellaktionen';

  @override
  String get diveSites_summary_section_topRated => 'Am besten bewertet';

  @override
  String get diveSites_summary_stat_avgRating => 'Durchschn. Bewertung';

  @override
  String get diveSites_summary_stat_totalDives => 'Tauchgänge gesamt';

  @override
  String get diveSites_summary_stat_totalSites => 'Tauchplätze gesamt';

  @override
  String get diveSites_summary_stat_withGps => 'Mit GPS';

  @override
  String get diveType_builtin_altitude => 'Bergseetauchen';

  @override
  String get diveType_builtin_boat => 'Bootstauchgang';

  @override
  String get diveType_builtin_cave => 'Höhlentauchen';

  @override
  String get diveType_builtin_cavern => 'Cavern';

  @override
  String get diveType_builtin_deep => 'Tieftauchen';

  @override
  String get diveType_builtin_drift => 'Strömungstauchen';

  @override
  String get diveType_builtin_freedive => 'Apnoetauchen';

  @override
  String get diveType_builtin_ice => 'Eistauchen';

  @override
  String get diveType_builtin_liveaboard => 'Tauchsafari';

  @override
  String get diveType_builtin_night => 'Nachttauchen';

  @override
  String get diveType_builtin_recreational => 'Sporttauchen';

  @override
  String get diveType_builtin_shore => 'Ufertauchgang';

  @override
  String get diveType_builtin_technical => 'Technisches Tauchen';

  @override
  String get diveType_builtin_training => 'Ausbildung';

  @override
  String get diveType_builtin_wreck => 'Wracktauchen';

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
  String get divers_detail_deleteButton => 'Löschen';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'This will permanently delete $name and all associated data including dive logs, dive computers, equipment, certifications, and sites.';
  }

  @override
  String get divers_detail_deleteDialogTitle => 'Taucher löschen?';

  @override
  String divers_detail_deleteError(Object error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String get divers_detail_deleteMenuItem => 'Löschen';

  @override
  String get divers_detail_deletedSnackbar => 'Taucher gelöscht';

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
  String get divers_detail_expiresLabel => 'Läuft ab';

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
  String get divers_detail_totalDivesLabel => 'Tauchgänge gesamt';

  @override
  String get divers_detail_unableToLoadStats =>
      'Statistiken konnten nicht geladen werden';

  @override
  String get divers_edit_addButton => 'Taucher hinzufügen';

  @override
  String get divers_edit_addTitle => 'Taucher hinzufügen';

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
      'Versicherungsablaufdatum löschen';

  @override
  String get divers_edit_clearMedicalClearanceTooltip =>
      'Datum der ärztlichen Freigabe löschen';

  @override
  String get divers_edit_contactNameLabel => 'Kontaktname';

  @override
  String get divers_edit_contactPhoneLabel => 'Kontakttelefon';

  @override
  String get divers_edit_discardButton => 'Verwerfen';

  @override
  String get divers_edit_discardDialogContent =>
      'Sie haben ungespeicherte Änderungen. Sind Sie sicher, dass Sie diese verwerfen möchten?';

  @override
  String get divers_edit_discardDialogTitle => 'Änderungen verwerfen?';

  @override
  String get divers_edit_diverAdded => 'Taucher hinzugefügt';

  @override
  String get divers_edit_diverUpdated => 'Taucher aktualisiert';

  @override
  String get divers_edit_editTitle => 'Taucher bearbeiten';

  @override
  String get divers_edit_emailError =>
      'Bitte geben Sie eine gültige E-Mail-Adresse ein';

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
  String get divers_edit_medicalClearanceExpiringSoon => 'Läuft bald ab';

  @override
  String get divers_edit_medicalClearanceNotSet => 'Nicht festgelegt';

  @override
  String get divers_edit_medicalClearanceTitle =>
      'Ablauf der ärztlichen Freigabe';

  @override
  String get divers_edit_medicalInfoSection => 'Medizinische Informationen';

  @override
  String get divers_edit_medicalNotesLabel => 'Medizinische Notizen';

  @override
  String get divers_edit_medicationsHint => 'z.B. Aspirin täglich, EpiPen';

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
  String get divers_edit_personalInfoSection => 'Persönliche Informationen';

  @override
  String get divers_edit_phoneLabel => 'Telefon';

  @override
  String get divers_edit_policyNumberLabel => 'Policennummer';

  @override
  String get divers_edit_primaryContactTitle => 'Primärer Kontakt';

  @override
  String get divers_edit_relationshipHint =>
      'z.B. Ehepartner, Elternteil, Freund';

  @override
  String get divers_edit_relationshipLabel => 'Beziehung';

  @override
  String get divers_edit_saveButton => 'Speichern';

  @override
  String get divers_edit_secondaryContactTitle => 'Sekundärer Kontakt';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip =>
      'Versicherungsablaufdatum auswählen';

  @override
  String get divers_edit_selectMedicalClearanceTooltip =>
      'Datum der ärztlichen Freigabe auswählen';

  @override
  String get divers_edit_updateButton => 'Taucher aktualisieren';

  @override
  String get divers_list_activeBadge => 'Aktiv';

  @override
  String get divers_list_addDiverButton => 'Taucher hinzufügen';

  @override
  String get divers_list_addDiverTooltip => 'Neues Taucherprofil hinzufügen';

  @override
  String get divers_list_appBarTitle => 'Taucherprofile';

  @override
  String get divers_list_compactTitle => 'Taucher';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount Tauchgänge$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle =>
      'Fügen Sie Taucherprofile hinzu, um Tauchprotokolle für mehrere Personen zu verwalten';

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
  String get divers_summary_overviewTitle => 'Übersicht';

  @override
  String get divers_summary_quickActionsTitle => 'Schnellaktionen';

  @override
  String get divers_summary_subtitle =>
      'Wählen Sie einen Taucher aus der Liste, um Details anzuzeigen';

  @override
  String get divers_summary_title => 'Taucherprofile';

  @override
  String get divers_summary_totalDiversLabel => 'Taucher gesamt';

  @override
  String divers_detail_deleteDialogConfirmHint(String name) {
    return 'Type \"Delete $name\" to confirm';
  }

  @override
  String divers_detail_deleteDialogConfirmText(String name) {
    return 'Delete $name';
  }

  @override
  String get enum_altitudeGroup_extreme => 'Extreme Höhe';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => 'Höhengruppe 1';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => 'Höhengruppe 2';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => 'Höhengruppe 3';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => 'Meereshöhe';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => 'Gefahr';

  @override
  String get enum_ascentRate_safe => 'Sicher';

  @override
  String get enum_ascentRate_warning => 'Warnung';

  @override
  String get enum_certificationAgency_bsac => 'BSAC';

  @override
  String get enum_certificationAgency_cmas => 'CMAS';

  @override
  String get enum_certificationAgency_gue => 'GÜ';

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
  String get enum_certificationLevel_cave => 'Höhlentauchen';

  @override
  String get enum_certificationLevel_cavern => 'Kavernentauchen';

  @override
  String get enum_certificationLevel_courseDirector => 'Course Director';

  @override
  String get enum_certificationLevel_decompression => 'Dekompression';

  @override
  String get enum_certificationLevel_diveGuide => 'Tauchguide';

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
  String get enum_currentDirection_south => 'Süd';

  @override
  String get enum_currentDirection_southEast => 'Südost';

  @override
  String get enum_currentDirection_southWest => 'Südwest';

  @override
  String get enum_currentDirection_variable => 'Wechselnd';

  @override
  String get enum_currentDirection_west => 'West';

  @override
  String get enum_currentStrength_light => 'Leicht';

  @override
  String get enum_currentStrength_moderate => 'Mäßig';

  @override
  String get enum_currentStrength_none => 'Keine';

  @override
  String get enum_currentStrength_strong => 'Stark';

  @override
  String get enum_diveMode_ccr => 'Geschlossener Kreislauf Rebreather';

  @override
  String get enum_diveMode_gauge => 'Gauge';

  @override
  String get enum_diveMode_oc => 'Offener Kreislauf';

  @override
  String get enum_diveMode_scr => 'Halbgeschlossener Rebreather';

  @override
  String get enum_diveType_altitude => 'Höhentauchen';

  @override
  String get enum_diveType_boat => 'Boot';

  @override
  String get enum_diveType_cave => 'Höhle';

  @override
  String get enum_diveType_deep => 'Tieftauchen';

  @override
  String get enum_diveType_drift => 'Strömungstauchen';

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
  String get enum_entryMethod_backRoll => 'Rückwärtsrolle';

  @override
  String get enum_entryMethod_boat => 'Bootseinstieg';

  @override
  String get enum_entryMethod_giantStride => 'Großschritt';

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
  String get enum_equipmentType_boots => 'Füßling';

  @override
  String get enum_equipmentType_camera => 'Kamera';

  @override
  String get enum_equipmentType_dpv => 'DPV';

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
      'Vollständige Tauchinformationen mit Notizen und Bewertungen';

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
      'Kompaktes Tabellenformat, viele Tauchgänge pro Seite';

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
  String get enum_profileEvent_decoViolation => 'Deko-Verstoß';

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
  String get enum_profileMetricCategory_primary => 'Primäre Messwerte';

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
  String get enum_profileMetric_sacRate => 'AMV';

  @override
  String get enum_profileMetric_sacRate_short => 'AMV';

  @override
  String get enum_profileMetric_surfaceGf => 'Oberflächenm GF';

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
  String get enum_serviceType_overhaul => 'Generalüberholung';

  @override
  String get enum_serviceType_recall => 'Rückruf/Sicherheit';

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
  String get enum_sortField_dateTaken => 'Aufnahmedatum';

  @override
  String get enum_sortField_difficulty => 'Schwierigkeitsgrad';

  @override
  String get enum_sortField_diveCount => 'Anzahl Tauchgänge';

  @override
  String get enum_sortField_diveNumber => 'Tauchgangnummer';

  @override
  String get enum_sortField_duration => 'Dauer';

  @override
  String get enum_sortField_endDate => 'Enddatum';

  @override
  String get enum_sortField_fileName => 'Dateiname';

  @override
  String get enum_sortField_fileSize => 'Dateigröße';

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
  String get enum_speciesCategory_mammal => 'Säugetier';

  @override
  String get enum_speciesCategory_other => 'Sonstige';

  @override
  String get enum_speciesCategory_plant => 'Pflanze/Alge';

  @override
  String get enum_speciesCategory_ray => 'Rochen';

  @override
  String get enum_speciesCategory_shark => 'Hai';

  @override
  String get enum_speciesCategory_turtle => 'Schildkröte';

  @override
  String get enum_tankMaterial_aluminum => 'Aluminium';

  @override
  String get enum_tankMaterial_carbonFiber => 'Kohlefaser';

  @override
  String get enum_tankMaterial_steel => 'Stahl';

  @override
  String get enum_tankRole_backGas => 'Rückengas';

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
  String get enum_visibility_moderate => 'Mäßig (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => 'Schlecht (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => 'Unbekannt';

  @override
  String get enum_waterType_brackish => 'Brackwasser';

  @override
  String get enum_waterType_fresh => 'Süßwasser';

  @override
  String get enum_waterType_salt => 'Salzwasser';

  @override
  String get enum_weightType_ankleWeights => 'Knöchelgewichte';

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
  String get equipment_appBar_title => 'Ausrüstung';

  @override
  String get equipment_deleteDialog_cancel => 'Abbrechen';

  @override
  String get equipment_deleteDialog_confirm => 'Löschen';

  @override
  String get equipment_deleteDialog_content =>
      'Sind Sie sicher, dass Sie diese Ausrüstung löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get equipment_deleteDialog_title => 'Ausrüstung löschen';

  @override
  String get equipment_detail_brandLabel => 'Marke';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return '$days Tage überfällig';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days Tage bis zur Wartung';
  }

  @override
  String get equipment_detail_detailsTitle => 'Details';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count Tauchgänge';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count Tauchgang';
  }

  @override
  String get equipment_detail_divesLabel => 'Tauchgänge';

  @override
  String get equipment_detail_divesSemanticLabel =>
      'Tauchgänge mit dieser Ausrüstung anzeigen';

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
  String get equipment_detail_editTooltip => 'Ausrüstung bearbeiten';

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
  String get equipment_detail_nextServiceDueLabel => 'Nächste Wartung fällig';

  @override
  String get equipment_detail_notFoundMessage =>
      'Dieser Ausrüstungsgegenstand existiert nicht mehr.';

  @override
  String get equipment_detail_notFoundTitle => 'Ausrüstung nicht gefunden';

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
  String get equipment_serviceClocks_title => 'Wartungsintervalle';

  @override
  String get equipment_serviceClocks_addClock => 'Intervall hinzufügen';

  @override
  String get equipment_serviceClocks_logService => 'Wartung erfassen';

  @override
  String get equipment_serviceClocks_edit => 'Intervalle bearbeiten';

  @override
  String get equipment_serviceClocks_pause => 'Pausieren';

  @override
  String get equipment_serviceClocks_resume => 'Fortsetzen';

  @override
  String get equipment_serviceClocks_remove => 'Entfernen';

  @override
  String get equipment_serviceClocks_paused => 'Pausiert';

  @override
  String get equipment_serviceClocks_empty => 'Keine Wartungsintervalle';

  @override
  String get equipment_serviceClocks_unconfigured =>
      'Kein Intervall festgelegt - zum Konfigurieren tippen';

  @override
  String equipment_serviceClocks_dueOn(String date) {
    return 'Fällig am $date';
  }

  @override
  String equipment_serviceClocks_overdueSince(String date) {
    return 'Überfällig seit $date';
  }

  @override
  String get equipment_serviceClocks_overdue => 'Überfällig';

  @override
  String equipment_serviceClocks_divesLeft(int remaining, int total) {
    return '$remaining von $total Tauchgängen übrig';
  }

  @override
  String get cylinderConfigs_title => 'Flaschenkonfigurationen';

  @override
  String get cylinderConfigs_empty => 'Noch keine Konfigurationen';

  @override
  String get cylinderConfigs_emptyBody =>
      'Diluent- und Bailout-Aufbau einmal speichern und auf jeden Tauchgang anwenden.';

  @override
  String get cylinderConfigs_new => 'Neue Konfiguration';

  @override
  String get cylinderConfigs_name => 'Name';

  @override
  String get cylinderConfigs_nameRequired => 'Namen eingeben';

  @override
  String get cylinderConfigs_forUnit => 'Für Gerät';

  @override
  String get cylinderConfigs_noUnit => 'Allgemeiner Gasplan';

  @override
  String get cylinderConfigs_gasPlans => 'Gaspläne';

  @override
  String get cylinderConfigs_addCylinder => 'Flasche hinzufügen';

  @override
  String get cylinderConfigs_role => 'Rolle';

  @override
  String get cylinderConfigs_startPressure => 'Anfangsdruck';

  @override
  String get cylinderConfigs_label => 'Bezeichnung';

  @override
  String get cylinderConfigs_fromPreset => 'Aus Vorlage';

  @override
  String get cylinderConfigs_deleteTitle => 'Konfiguration löschen?';

  @override
  String get cylinderConfigs_deleteBody =>
      'Bereits angewendete Tauchgänge bleiben unverändert.';

  @override
  String get cylinderConfigs_applyAction => 'Konfiguration anwenden';

  @override
  String cylinderConfigs_applyAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Flaschen hinzugefügt',
      one: '1 Flasche hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String cylinderConfigs_applyKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count beibehalten',
      one: '1 beibehalten',
    );
    return '$_temp0';
  }

  @override
  String get cylinderConfigs_applyNothingToDo =>
      'Dieser Tauchgang entspricht bereits der Konfiguration';

  @override
  String get cylinderConfigs_sectionTitle => 'Konfigurationen';

  @override
  String get equipment_serviceClocks_hoursSource =>
      'Aus der protokollierten Tauchzeit berechnet';

  @override
  String equipment_serviceClocks_hoursLeft(String remaining, String total) {
    return '$remaining von $total Stunden übrig';
  }

  @override
  String get equipment_serviceClocks_manageKinds => 'Wartungsarten verwalten';

  @override
  String get equipment_serviceClocks_appliesToClock => 'Zugehöriges Intervall';

  @override
  String get equipment_serviceClocks_noClockOption =>
      'Keinem Intervall zugeordnet';

  @override
  String get equipment_scheduleDialog_title => 'Intervall bearbeiten';

  @override
  String get equipment_scheduleDialog_intervalDays => 'Intervall (Tage)';

  @override
  String get equipment_scheduleDialog_intervalDives => 'Intervall (Tauchgänge)';

  @override
  String get equipment_scheduleDialog_intervalHours => 'Intervall (Stunden)';

  @override
  String equipment_scheduleDialog_inheritHint(String value) {
    return 'Standard: $value';
  }

  @override
  String get equipment_scheduleDialog_anchorDate => 'Referenzdatum';

  @override
  String get equipment_scheduleDialog_anchorHint =>
      'Wird verwendet, solange noch kein Wartungseintrag dieser Art vorliegt';

  @override
  String get equipment_scheduleDialog_clearAnchor => 'Referenzdatum löschen';

  @override
  String get equipment_scheduleDialog_save => 'Speichern';

  @override
  String get equipment_scheduleDialog_cancel => 'Abbrechen';

  @override
  String get equipment_serviceKinds_title => 'Wartungsarten';

  @override
  String get equipment_serviceKinds_builtIn => 'Integriert';

  @override
  String get equipment_serviceKinds_custom => 'Benutzerdefiniert';

  @override
  String get equipment_serviceKinds_add => 'Wartungsart hinzufügen';

  @override
  String get equipment_serviceKinds_editTitle => 'Wartungsart bearbeiten';

  @override
  String get equipment_serviceKinds_nameLabel => 'Name';

  @override
  String get equipment_serviceKinds_nameRequired => 'Ein Name ist erforderlich';

  @override
  String get equipment_serviceKinds_appliesTo => 'Gilt für';

  @override
  String get equipment_serviceKinds_autoAttach =>
      'Automatisch an neue Ausrüstung anhängen';

  @override
  String get equipment_serviceKinds_deleteConfirmTitle =>
      'Wartungsart löschen?';

  @override
  String get equipment_serviceKinds_deleteConfirmBody =>
      'Wartungsintervalle mit dieser Wartungsart werden entfernt.';

  @override
  String get equipment_serviceKinds_delete => 'Löschen';

  @override
  String get equipment_serviceKinds_cancel => 'Abbrechen';

  @override
  String get equipment_serviceKinds_save => 'Speichern';

  @override
  String get equipment_serviceKinds_emptyCustom =>
      'Noch keine benutzerdefinierten Wartungsarten';

  @override
  String equipment_serviceKinds_everyDays(int days) {
    return 'alle $days Tage';
  }

  @override
  String equipment_serviceKinds_everyDives(int dives) {
    return 'alle $dives Tauchgänge';
  }

  @override
  String equipment_serviceKinds_everyHours(String hours) {
    return 'alle $hours Stunden';
  }

  @override
  String get dashboard_serviceDue_title => 'Wartung fällig';

  @override
  String dashboard_serviceDue_more(int count) {
    return '+$count weitere';
  }

  @override
  String dashboard_alerts_clockDue(String name, String kind) {
    return '$name: $kind fällig';
  }

  @override
  String dashboard_alerts_clockOverdue(String name, String kind) {
    return '$name: $kind überfällig';
  }

  @override
  String equipment_list_worstClock(String kind) {
    return '$kind überfällig';
  }

  @override
  String trips_serviceAlert_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ausrüstungsteile müssen vor dieser Reise gewartet werden',
      one: '1 Ausrüstungsteil muss vor dieser Reise gewartet werden',
    );
    return '$_temp0';
  }

  @override
  String trips_serviceAlert_dueBefore(String kind, String date) {
    return '$kind fällig am $date';
  }

  @override
  String trips_serviceAlert_overdue(String kind) {
    return '$kind überfällig';
  }

  @override
  String get settings_notifications_tripLeadTitle =>
      'Vorlaufzeit für Wartung vor Reisen';

  @override
  String settings_notifications_tripLeadDays(int days) {
    return '$days Tage vor einer Reise';
  }

  @override
  String get equipment_detail_serviceIntervalLabel => 'Wartungsintervall';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days Tage';
  }

  @override
  String get equipment_detail_serviceOverdue => 'Wartung ist überfällig!';

  @override
  String get equipment_detail_sizeLabel => 'Größe';

  @override
  String get equipment_detail_thicknessLabel => 'Dicke';

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
      'Reisen mit dieser Ausrüstung anzeigen';

  @override
  String get equipment_edit_appBar_editTitle => 'Ausrüstung bearbeiten';

  @override
  String get equipment_edit_appBar_newTitle => 'Neue Ausrüstung';

  @override
  String get equipment_edit_appBar_saveButton => 'Speichern';

  @override
  String get equipment_edit_appBar_saveTooltip =>
      'Ausrüstungsänderungen speichern';

  @override
  String get equipment_edit_brandLabel => 'Marke';

  @override
  String get equipment_edit_clearDate => 'Datum löschen';

  @override
  String get equipment_edit_currencyLabel => 'Währung';

  @override
  String get equipment_edit_disableReminders => 'Erinnerungen deaktivieren';

  @override
  String get equipment_edit_disableRemindersSubtitle =>
      'Alle Benachrichtigungen für diesen Gegenstand deaktivieren';

  @override
  String get equipment_edit_discardDialog_content =>
      'Sie haben ungespeicherte Änderungen. Sind Sie sicher, dass Sie die Seite verlassen möchten?';

  @override
  String get equipment_edit_discardDialog_discard => 'Verwerfen';

  @override
  String get equipment_edit_discardDialog_keepEditing => 'Weiter bearbeiten';

  @override
  String get equipment_edit_discardDialog_title => 'Änderungen verwerfen?';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => 'Abbrechen';

  @override
  String get equipment_edit_embeddedHeader_editTitle => 'Ausrüstung bearbeiten';

  @override
  String get equipment_edit_embeddedHeader_newTitle => 'Neue Ausrüstung';

  @override
  String get equipment_edit_embeddedHeader_saveButton => 'Speichern';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit =>
      'Ausrüstungsänderungen speichern';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new =>
      'Neue Ausrüstung hinzufügen';

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
      'Dieser Ausrüstungsgegenstand existiert nicht mehr.';

  @override
  String get equipment_edit_notFoundTitle => 'Ausrüstung nicht gefunden';

  @override
  String get equipment_edit_notesHint =>
      'Zusätzliche Notizen zu dieser Ausrüstung...';

  @override
  String get equipment_edit_notesLabel => 'Notizen';

  @override
  String get equipment_edit_notificationsSubtitle =>
      'Globale Benachrichtigungseinstellungen für diesen Gegenstand überschreiben';

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
  String get equipment_edit_purchasePriceValidation =>
      'Geben Sie einen gültigen Betrag ein';

  @override
  String get equipment_edit_remindMeBeforeServiceDue =>
      'Erinnern Sie mich vor der fälligen Wartung:';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days Tage';
  }

  @override
  String get equipment_edit_saveButton_edit => 'Änderungen speichern';

  @override
  String get equipment_edit_saveButton_new => 'Ausrüstung hinzufügen';

  @override
  String get equipment_edit_saveTooltip_edit =>
      'Ausrüstungsänderungen speichern';

  @override
  String get equipment_edit_saveTooltip_new =>
      'Neuen Ausrüstungsgegenstand hinzufügen';

  @override
  String get equipment_edit_selectDate => 'Datum auswählen';

  @override
  String get equipment_edit_serialNumberLabel => 'Seriennummer';

  @override
  String get equipment_edit_serviceIntervalHint => 'z. B. 365 für jährlich';

  @override
  String get equipment_edit_serviceIntervalLabel => 'Wartungsintervall (Tage)';

  @override
  String get equipment_edit_serviceSettingsTitle => 'Wartungseinstellungen';

  @override
  String get equipment_edit_sizeHint => 'z. B. M, L, 42';

  @override
  String get equipment_edit_sizeLabel => 'Größe';

  @override
  String get equipment_edit_snackbar_added => 'Ausrüstung hinzugefügt';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return 'Fehler beim Speichern der Ausrüstung: $error';
  }

  @override
  String get equipment_edit_snackbar_updated => 'Ausrüstung aktualisiert';

  @override
  String get equipment_edit_statusLabel => 'Status';

  @override
  String get equipment_edit_thicknessDesignationHint => 'z.B. 5, 5/4, 7/5/3';

  @override
  String get equipment_edit_thicknessHint => 'z.B. 5mm, 7mm';

  @override
  String get equipment_edit_thicknessLabel => 'Dicke';

  @override
  String get equipment_edit_typeLabel => 'Typ *';

  @override
  String get equipment_edit_useCustomReminders =>
      'Eigene Erinnerungen verwenden';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'Andere Erinnerungstage für diesen Gegenstand festlegen';

  @override
  String get equipment_fab_addEquipment => 'Ausrüstung hinzufügen';

  @override
  String get equipment_fab_addSet => 'Set hinzufügen';

  @override
  String get equipment_list_emptyState_addFirstButton =>
      'Erste Ausrüstung hinzufügen';

  @override
  String get equipment_list_emptyState_addPrompt =>
      'Fügen Sie Ihre Tauchausrüstung hinzu, um Nutzung und Wartung zu verfolgen';

  @override
  String get equipment_list_emptyState_filterText_equipment => 'Ausrüstung';

  @override
  String get equipment_list_emptyState_filterText_serviceDue =>
      'wartungsfällige Ausrüstung';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return '$status Ausrüstung';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return 'Keine $filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch =>
      'Keine Ausrüstung mit diesem Status';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate =>
      'Alle Ihre Ausrüstungsgegenstände sind wartungstechnisch auf dem neuesten Stand!';

  @override
  String equipment_list_errorLoading(Object error) {
    return 'Fehler beim Laden der Ausrüstung: $error';
  }

  @override
  String get equipment_list_filterAll => 'Gesamte Ausrüstung';

  @override
  String get equipment_list_filterLabel => 'Filter:';

  @override
  String get equipment_list_filterServiceDue => 'Wartung fällig';

  @override
  String get equipment_list_retryButton => 'Erneut versuchen';

  @override
  String get equipment_list_searchTooltip => 'Ausrüstung suchen';

  @override
  String get equipment_list_setsTooltip => 'Ausrüstungssets';

  @override
  String get equipment_list_sortTitle => 'Ausrüstung sortieren';

  @override
  String get equipment_list_sortTooltip => 'Sortieren';

  @override
  String equipment_list_tile_daysCount(Object days) {
    return '$days Tage';
  }

  @override
  String equipment_list_tile_serviceInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Wartung in $days Tage',
      one: 'Wartung in 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get equipment_list_tile_serviceDueChip => 'Wartung fällig';

  @override
  String get equipment_list_tile_serviceIn => 'Wartung in';

  @override
  String get equipment_menu_delete => 'Löschen';

  @override
  String get equipment_menu_markAsServiced => 'Als gewartet markieren';

  @override
  String get equipment_menu_reactivate => 'Reaktivieren';

  @override
  String get equipment_menu_retireEquipment => 'Ausrüstung ausmustern';

  @override
  String get equipment_search_backTooltip => 'Zurück';

  @override
  String get equipment_search_clearTooltip => 'Suche löschen';

  @override
  String get equipment_search_fieldLabel => 'Ausrüstung suchen...';

  @override
  String get equipment_search_hint =>
      'Suche nach Name, Marke, Modell oder Seriennummer';

  @override
  String equipment_search_noResults(Object query) {
    return 'Keine Ausrüstung für \"$query\" gefunden';
  }

  @override
  String get equipment_serviceDialog_addButton => 'Hinzufügen';

  @override
  String get equipment_serviceDialog_addTitle => 'Wartungseintrag hinzufügen';

  @override
  String get equipment_serviceDialog_cancelButton => 'Abbrechen';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip =>
      'Nächstes Wartungsdatum löschen';

  @override
  String get equipment_serviceDialog_costHint => '0,00';

  @override
  String get equipment_serviceDialog_costLabel => 'Kosten';

  @override
  String get equipment_serviceDialog_currencyLabel => 'Währung';

  @override
  String get equipment_serviceDialog_costValidation =>
      'Geben Sie einen gültigen Betrag ein';

  @override
  String get equipment_serviceDialog_editTitle => 'Wartungseintrag bearbeiten';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel =>
      'Nächste Wartung fällig';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel =>
      'Nächstes Wartungsdatum auswählen';

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
      'Wartungsdatum auswählen';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => 'Wartungsart';

  @override
  String get equipment_serviceDialog_serviceTypeHelper =>
      'Das Erfassen setzt den Zähler dieser Wartungsart zurück';

  @override
  String get equipment_serviceDialog_serviceTypeRequired =>
      'Wartungsart auswählen';

  @override
  String get equipment_serviceDialog_serviceTypeNotSet => 'Nicht gesetzt';

  @override
  String get equipment_serviceDialog_categoryHelper =>
      'Für Filter und Export verwendet';

  @override
  String get equipment_serviceDialog_manageServiceTypes =>
      'Wartungsarten verwalten';

  @override
  String get equipment_serviceDialog_categoryLabel => 'Kategorie';

  @override
  String get equipment_serviceDialog_snackbar_added =>
      'Wartungseintrag hinzugefügt';

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
  String get equipment_serviceCategory_annual => 'Jahresservice';

  @override
  String get equipment_serviceCategory_repair => 'Reparatur';

  @override
  String get equipment_serviceCategory_inspection => 'Inspektion';

  @override
  String get equipment_serviceCategory_overhaul => 'Überholung';

  @override
  String get equipment_serviceCategory_replacement => 'Teiletausch';

  @override
  String get equipment_serviceCategory_cleaning => 'Reinigung';

  @override
  String get equipment_serviceCategory_calibration => 'Kalibrierung';

  @override
  String get equipment_serviceCategory_warranty => 'Garantieservice';

  @override
  String get equipment_serviceCategory_recall => 'Rückruf/Sicherheit';

  @override
  String get equipment_serviceCategory_other => 'Sonstiges';

  @override
  String get equipment_service_addButton => 'Hinzufügen';

  @override
  String get equipment_service_deleteDialog_cancel => 'Abbrechen';

  @override
  String get equipment_service_deleteDialog_confirm => 'Löschen';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return 'Sind Sie sicher, dass Sie diesen $serviceType-Eintrag löschen möchten?';
  }

  @override
  String get equipment_service_deleteDialog_title => 'Wartungseintrag löschen?';

  @override
  String get equipment_service_deleteMenuItem => 'Löschen';

  @override
  String get equipment_service_editMenuItem => 'Bearbeiten';

  @override
  String get equipment_service_emptyState => 'Noch keine Wartungseinträge';

  @override
  String get equipment_service_historyTitle => 'Wartungsverlauf';

  @override
  String equipment_service_nextDueLabel(String date) {
    return 'Nächste Fälligkeit $date';
  }

  @override
  String get equipment_service_filterTaskAll => 'Alle Aufgaben';

  @override
  String get equipment_service_filterTypeAll => 'Alle Typen';

  @override
  String get equipment_service_filterYearAll => 'Alle Jahre';

  @override
  String get equipment_service_filterUntagged => 'Keinem Intervall zugeordnet';

  @override
  String get equipment_service_filterClear => 'Filter zurücksetzen';

  @override
  String get equipment_service_filterNoMatches =>
      'Keine Wartung entspricht diesem Filter';

  @override
  String equipment_service_filterMatchCount(int count, int total) {
    return '$count von $total angezeigt';
  }

  @override
  String get equipment_serviceKinds_defaultCategoryLabel => 'Standardkategorie';

  @override
  String get equipment_serviceKinds_defaultCategoryNone => 'Kein Standard';

  @override
  String get equipment_serviceKinds_defaultCostLabel => 'Standardpreis';

  @override
  String get equipment_serviceKinds_defaultCostHint =>
      'Leer lassen für keinen Standardwert';

  @override
  String get equipment_scheduleDialog_defaultCostLabel =>
      'Standardpreis für dieses Teil';

  @override
  String get equipment_serviceKinds_defaultCurrencyLabel => 'Währung';

  @override
  String get equipment_service_exportMenuItem =>
      'Wartungsprotokoll exportieren';

  @override
  String get transfer_export_maintenanceTitle => 'Wartungsprotokoll';

  @override
  String get transfer_export_maintenanceSubtitle =>
      'Serviceverlauf der gesamten Ausrüstung als Tabelle';

  @override
  String get settings_export_progress_maintenance =>
      'Wartungsprotokoll wird exportiert...';

  @override
  String get settings_export_success_maintenance =>
      'Wartungsprotokoll exportiert';

  @override
  String get settings_export_saved_maintenance =>
      'Wartungsprotokoll gespeichert';

  @override
  String get equipment_serviceKinds_defaultCurrencyInherit =>
      'Standardwährung verwenden';

  @override
  String get equipment_scheduleDialog_defaultCurrencyLabel =>
      'Währung für dieses Teil';

  @override
  String get equipment_service_snackbar_deleted => 'Wartungseintrag gelöscht';

  @override
  String get equipment_service_totalCostLabel => 'Gesamte Wartungskosten';

  @override
  String get equipment_setDetail_addEquipmentButton => 'Ausrüstung hinzufügen';

  @override
  String get equipment_setDetail_deleteDialog_cancel => 'Abbrechen';

  @override
  String get equipment_setDetail_deleteDialog_confirm => 'Löschen';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      'Sind Sie sicher, dass Sie dieses Ausrüstungsset löschen möchten? Die enthaltenen Ausrüstungsgegenstände werden nicht gelöscht.';

  @override
  String get equipment_setDetail_deleteDialog_title => 'Ausrüstungsset löschen';

  @override
  String get equipment_setDetail_deleteMenuItem => 'Löschen';

  @override
  String get equipment_setDetail_editTooltip => 'Set bearbeiten';

  @override
  String get equipment_setDetail_emptySet => 'Keine Ausrüstung in diesem Set';

  @override
  String get equipment_setDetail_equipmentInSetTitle =>
      'Ausrüstung in diesem Set';

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
      'Dieses Ausrüstungsset existiert nicht mehr.';

  @override
  String get equipment_setDetail_notFoundTitle => 'Set nicht gefunden';

  @override
  String get equipment_setDetail_snackbar_deleted => 'Ausrüstungsset gelöscht';

  @override
  String get equipment_setEdit_addEquipmentFirst =>
      'Fügen Sie zuerst Ausrüstung hinzu, bevor Sie ein Set erstellen.';

  @override
  String get equipment_setEdit_appBar_editTitle => 'Set bearbeiten';

  @override
  String get equipment_setEdit_appBar_newTitle => 'Neues Ausrüstungsset';

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
      'Keine Ausrüstung verfügbar';

  @override
  String get equipment_setEdit_notFoundMessage =>
      'Dieses Ausrüstungsset existiert nicht mehr.';

  @override
  String get equipment_setEdit_notFoundTitle => 'Set nicht gefunden';

  @override
  String get equipment_setEdit_saveButton_edit => 'Änderungen speichern';

  @override
  String get equipment_setEdit_saveButton_new => 'Set erstellen';

  @override
  String get equipment_setEdit_saveTooltip_edit =>
      'Ausrüstungsset-Änderungen speichern';

  @override
  String get equipment_setEdit_saveTooltip_new =>
      'Neues Ausrüstungsset erstellen';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle =>
      'Wählen Sie die Ausrüstungsgegenstände aus, die in diesem Set enthalten sein sollen.';

  @override
  String get equipment_setEdit_selectEquipmentTitle => 'Ausrüstung auswählen';

  @override
  String get equipment_setEdit_snackbar_created => 'Ausrüstungsset erstellt';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return 'Fehler beim Speichern des Ausrüstungssets: $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated =>
      'Ausrüstungsset aktualisiert';

  @override
  String get equipment_sets_appBar_title => 'Ausrüstungssets';

  @override
  String get equipment_sets_emptyState_createFirstButton =>
      'Erstes Set erstellen';

  @override
  String get equipment_sets_emptyState_description =>
      'Erstellen Sie Ausrüstungssets, um häufig verwendete Ausrüstungskombinationen schnell zu Ihren Tauchgängen hinzuzufügen.';

  @override
  String get equipment_sets_emptyState_title => 'Keine Ausrüstungssets';

  @override
  String equipment_sets_errorLoading(Object error) {
    return 'Fehler beim Laden der Sets: $error';
  }

  @override
  String get equipment_sets_fabTooltip => 'Neues Ausrüstungsset erstellen';

  @override
  String get equipment_sets_fab_createSet => 'Set erstellen';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count Gegenstände';
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
  String get equipment_snackbar_deleted => 'Ausrüstung gelöscht';

  @override
  String get equipment_snackbar_markedAsServiced => 'Als gewartet markiert';

  @override
  String get equipment_snackbar_reactivated => 'Ausrüstung reaktiviert';

  @override
  String get equipment_snackbar_retired => 'Ausrüstung ausgemustert';

  @override
  String get equipment_summary_active => 'Aktiv';

  @override
  String get equipment_summary_addEquipmentButton => 'Ausrüstung hinzufügen';

  @override
  String get equipment_summary_equipmentSetsButton => 'Ausrüstungssets';

  @override
  String get equipment_summary_overviewTitle => 'Übersicht';

  @override
  String get equipment_summary_quickActionsTitle => 'Schnellaktionen';

  @override
  String get equipment_summary_recentEquipmentTitle => 'Letzte Ausrüstung';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name, $type';
  }

  @override
  String get equipment_summary_selectPrompt =>
      'Wählen Sie einen Ausrüstungsgegenstand aus der Liste, um Details anzuzeigen';

  @override
  String get equipment_summary_serviceDue => 'Wartung fällig';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name, $type, Wartung fällig';
  }

  @override
  String get equipment_summary_serviceDueTitle => 'Wartung fällig';

  @override
  String get equipment_summary_title => 'Ausrüstung';

  @override
  String get equipment_summary_totalItems => 'Gegenstände gesamt';

  @override
  String get equipment_summary_totalValue => 'Gesamtwert';

  @override
  String get equipment_tab_equipment => 'Ausrüstung';

  @override
  String get equipment_tab_sets => 'Sets';

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
      'Standard-Luftdiluent für flaches CCR';

  @override
  String get gas_diluentAir_displayName => 'Luft-Diluent';

  @override
  String get gas_diluentTx1070_description =>
      'Hypoxischer Diluent für sehr tiefes CCR';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description =>
      'Hypoxischer Diluent für tiefes CCR';

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
  String get gasCalculators_mnd_depthInput => 'Tiefe';

  @override
  String get gasCalculators_mnd_endAtDepthTitle => 'END bei Tiefe';

  @override
  String get gasCalculators_mnd_endLimit => 'END-Grenze';

  @override
  String get gasCalculators_mnd_hePercent => 'He %';

  @override
  String get gasCalculators_mnd_infoContent =>
      'Die maximale narkotische Tiefe (MND) ist die tiefste Stelle, die Sie erreichen können, bevor die Narkose Ihre END-Grenze überschreitet. Die äquivalente narkotische Tiefe (END) gibt die narkotische Wirkung Ihres Gases in einer bestimmten Tiefe an.\n\nWenn \'O2 ist narkotisch\' aktiviert ist, tragen sowohl Sauerstoff als auch Stickstoff zur Narkose bei (konservativer). Wenn deaktiviert, wird nur Stickstoff als narkotisch betrachtet.';

  @override
  String get gasCalculators_mnd_infoTitle => 'Über MND/END';

  @override
  String get gasCalculators_mnd_unlimited => 'unbegrenzt';

  @override
  String get gasCalculators_mnd_inputParameters =>
      'Gasmischung & Narkose-Einstellungen';

  @override
  String get gasCalculators_mnd_o2Narcotic => 'O2 ist narkotisch';

  @override
  String get gasCalculators_mnd_o2Percent => 'O2 %';

  @override
  String get gasCalculators_mnd_resultTitle => 'Maximale narkotische Tiefe';

  @override
  String get gasCalculators_ppO2Limit => 'ppO₂-Limit';

  @override
  String get gasCalculators_resetAll => 'Alle Rechner zurücksetzen';

  @override
  String get gasCalculators_sacRate => 'AMV';

  @override
  String get gasCalculators_tab_bestMix => 'Bestes Gemisch';

  @override
  String get gasCalculators_tab_consumption => 'Verbrauch';

  @override
  String get gasCalculators_tab_mnd => 'MND/END';

  @override
  String get gasCalculators_tab_blender => 'Trimix-Mischer';

  @override
  String get gasCalculators_blender_cylinder => 'Flasche';

  @override
  String get gasCalculators_blender_startCylinder => 'In der Flasche';

  @override
  String get gasCalculators_blender_targetFill => 'Zielfüllung';

  @override
  String get gasCalculators_blender_fillGases => 'Füllgase';

  @override
  String get gasCalculators_blender_pressure => 'Druck';

  @override
  String get gasCalculators_blender_o2 => 'O₂';

  @override
  String get gasCalculators_blender_he => 'He';

  @override
  String get gasCalculators_blender_air => 'Luft';

  @override
  String get gasCalculators_blender_helium => 'Helium';

  @override
  String get gasCalculators_blender_procedure => 'Füllreihenfolge';

  @override
  String get gasCalculators_blender_amounts => 'Zuzuführendes Gas';

  @override
  String gasCalculators_blender_stepStart(String pressure, String gas) {
    return 'Beginne mit $pressure $gas';
  }

  @override
  String gasCalculators_blender_stepFill(
    String gas,
    String pressure,
    String mix,
  ) {
    return 'Fülle $gas bis $pressure → $mix';
  }

  @override
  String get gasCalculators_blender_error_targetPressure =>
      'Zieldruck muss höher als der Ausgangsdruck sein.';

  @override
  String get gasCalculators_blender_error_invalidMix =>
      'O₂ + He eines Gasgemischs darf 100 % nicht überschreiten.';

  @override
  String get gasCalculators_blender_error_identicalGases =>
      'Die beiden Füllgase sind identisch — nichts zu mischen.';

  @override
  String get gasCalculators_blender_error_linearlyDependent =>
      'Mit diesen Füllgasen ist das Zielgemisch nicht möglich — ein Trimix-Ziel braucht eine Heliumquelle.';

  @override
  String get gasCalculators_blender_error_negativeAmount =>
      'Dieses Gemisch ist mit diesen Gasen nicht erreichbar — es müsste Gas entnommen werden.';

  @override
  String gasCalculators_blender_error_drainTo(String pressure) {
    return 'Zu viel Gas in der Flasche für dieses Gemisch. Zuerst auf $pressure ablassen, dann füllen.';
  }

  @override
  String get gasCalculators_blender_error_drainEmpty =>
      'Das Gas in der Flasche kann für dieses Gemisch nicht verwendet werden. Zuerst vollständig entleeren, dann füllen.';

  @override
  String get gasCalculators_blender_error_cannotRemoveHelium =>
      'Die Flasche enthält Helium, das Zielgemisch nicht. Nachfüllen verdünnt Helium, entfernt es aber nicht: die Flasche muss zuerst entleert werden.';

  @override
  String get gasCalculators_blender_error_insufficientGases =>
      'Ein heliumfreies Ziel braucht zwei heliumfreie Füllgase mit unterschiedlichem O₂-Gehalt.';

  @override
  String get gasCalculators_blender_error_targetNotReached =>
      'Mit diesen Füllgasen wird das Zielgemisch nicht exakt erreicht. Füllgase und ihre Reihenfolge prüfen.';

  @override
  String get gasCalculators_blender_error_implausibleStartMix =>
      'Die Flasche steht unter Druck, enthält aber weder Sauerstoff noch Helium, also reinen Stickstoff. Prüfe die Mischung, die bereits in der Flasche ist.';

  @override
  String get gasCalculators_blender_about => 'Über das Mischen';

  @override
  String get gasCalculators_blender_aboutBody =>
      'Partialdruck-Mischung für die Zielmischung. Gib jedes Füllgas der Reihe nach bis zum angezeigten Druck zu und lass die Flasche danach ruhen. Füllgase und ihre Reihenfolge sind einstellbar: Setzt du das letzte Gas auf 32/0, wird statt mit Luft mit EAN32 aufgefüllt. Analysiere die fertige Mischung immer, bevor du sie tauchst.';

  @override
  String get gasCalculators_blender_conditions => 'Mischbedingungen';

  @override
  String get gasCalculators_blender_fillTemp => 'Fülltemperatur';

  @override
  String get gasCalculators_blender_fillTempHelp =>
      'Die Temperatur der Flasche während des Füllens. Jeder Druck in der Reihenfolge ist der Manometerwert bei dieser Temperatur.';

  @override
  String get gasCalculators_blender_settledTemp => 'Ruhetemperatur';

  @override
  String get gasCalculators_blender_settledTempHelp =>
      'Die Temperatur, die die Flasche am Ende annimmt. Der Zieldruck ist der Wert, den sie dann anzeigt.';

  @override
  String get gasCalculators_blender_gasModel => 'Gasmodell';

  @override
  String get gasCalculators_blender_modelIdeal => 'Ideales Gas';

  @override
  String get gasCalculators_blender_modelVanDerWaals => 'Van der Waals';

  @override
  String get gasCalculators_blender_modelZFactor => 'Reales Gas (Z-Faktor)';

  @override
  String get gasCalculators_blender_modelRecommended => 'Empfohlen';

  @override
  String get gasCalculators_blender_modelHelp =>
      'Reales Gas (Z-Faktor) ist bei Flaschendrücken am genauesten. Ideales Gas entspricht den meisten veröffentlichten Mischtabellen. Van der Waals dient dem Vergleich mit anderer Mischsoftware und weicht bei Fülldruck um mehrere Prozent ab.';

  @override
  String gasCalculators_blender_stepAdd(String gas) {
    return '$gas zugeben';
  }

  @override
  String get gasCalculators_blender_stepStartLabel => 'Start';

  @override
  String gasCalculators_blender_settlesTo(String pressure, String temperature) {
    return 'Endet bei $pressure bei $temperature';
  }

  @override
  String get gasCalculators_blender_templates => 'Vorlagen';

  @override
  String get gasCalculators_blender_templatesTitle =>
      'Vorlagen für Zielmischungen';

  @override
  String get gasCalculators_blender_saveTemplate =>
      'Aktuelle Mischung speichern';

  @override
  String get gasCalculators_blender_manageTemplates => 'Vorlagen verwalten';

  @override
  String gasCalculators_blender_templateSaved(String mix) {
    return '$mix gespeichert';
  }

  @override
  String get gasCalculators_blender_templateExists =>
      'Diese Mischung ist bereits gespeichert.';

  @override
  String get gasCalculators_blender_templateInvalid =>
      'O₂ + He darf 100 % nicht überschreiten.';

  @override
  String get gasCalculators_blender_templateNeedsNumbers =>
      'Gib O₂ und He beide als Zahl ein.';

  @override
  String gasCalculators_blender_templateLimit(int count) {
    return 'Du kannst bis zu $count Vorlagen speichern.';
  }

  @override
  String get gasCalculators_blender_templateNone =>
      'Noch keine Vorlagen. Speichere eine Zielmischung, um sie hier wiederzuverwenden.';

  @override
  String gasCalculators_blender_templateDelete(String mix) {
    return '$mix löschen';
  }

  @override
  String get gasCalculators_blender_templateAdd => 'Vorlage hinzufügen';

  @override
  String get gasCalculators_blender_billing => 'Kosten';

  @override
  String get gasCalculators_blender_cylinderVolume =>
      'Wasservolumen der Flasche';

  @override
  String get gasCalculators_blender_cylinderPresets => 'Voreinstellungen';

  @override
  String gasCalculators_blender_unitPrice(String unit) {
    return 'Preis pro 100 $unit';
  }

  @override
  String get gasCalculators_blender_currency => 'Währung';

  @override
  String get gasCalculators_blender_costTotal => 'Gesamt';

  @override
  String get gasCalculators_blender_costBasis =>
      'Abgerechnet wird der gelieferte Druck (Wasservolumen der Flasche × zugeführte bar), so wie eine Füllstation misst.';

  @override
  String get gasCalculators_blender_costMissingPrice =>
      'Gib für jedes Gas einen Preis ein, um die Summe zu sehen.';

  @override
  String get gasCalculators_blender_saveFill => 'Diese Füllung speichern';

  @override
  String get gasCalculators_blender_billed => 'Abgerechnet';

  @override
  String get gasCalculators_blender_billedNone =>
      'Noch nichts abgerechnet. Schliesse eine Füllung ab und speichere sie hier.';

  @override
  String get gasCalculators_blender_billedTo => 'Rechnung an';

  @override
  String get gasCalculators_blender_addManualLine => 'Position hinzufügen';

  @override
  String get gasCalculators_blender_lineDescription => 'Bezeichnung';

  @override
  String get gasCalculators_blender_lineAmount => 'Betrag';

  @override
  String get gasCalculators_blender_clearBilled => 'Leeren';

  @override
  String get gasCalculators_blender_clearBilledTitle => 'Rechnung leeren?';

  @override
  String gasCalculators_blender_clearBilledBody(int count) {
    return 'Damit werden alle $count gespeicherten Füllungen entfernt.';
  }

  @override
  String gasCalculators_blender_editLine(String label) {
    return '$label bearbeiten';
  }

  @override
  String gasCalculators_blender_deleteLine(String label) {
    return '$label löschen';
  }

  @override
  String gasCalculators_blender_fillAdded(String mix) {
    return '$mix zur Rechnung hinzugefügt';
  }

  @override
  String get gasCalculators_blender_billedIncomplete =>
      'Mindestens eine Position hat keinen Preis, die Summe ist daher unvollständig.';

  @override
  String get gasCalculators_blender_billedTotal => 'Gesamt';

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
      'Keine erwarteten Arten hinzugefügt';

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
  String get marineLife_speciesDetail_backTooltip => 'Zurück';

  @override
  String get marineLife_speciesDetail_depthRangeTitle => 'Tiefenbereich';

  @override
  String get marineLife_speciesDetail_descriptionTitle => 'Beschreibung';

  @override
  String get marineLife_speciesDetail_divesLabel => 'Tauchgänge';

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
  String get marineLife_speciesDetail_sitesLabel => 'Tauchplätze';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return 'Klasse: $className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle => 'Häufigste Tauchplätze';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel =>
      'Sichtungen gesamt';

  @override
  String get marineLife_speciesEdit_addTitle => 'Art hinzufügen';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return '\"$name\" hinzugefügt';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => 'Zurück';

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
  String get marineLife_speciesManage_backTooltip => 'Zurück';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return 'Integrierte Arten ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => 'Abbrechen';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return '\"$name\" kann nicht gelöscht werden - es gibt Sichtungen';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip => 'Suche löschen';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return 'Benutzerdefinierte Arten ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => 'Löschen';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return 'Sind Sie sicher, dass Sie \"$name\" löschen möchten?';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle => 'Art löschen?';

  @override
  String get marineLife_speciesManage_deleteTooltip => 'Art löschen';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return '\"$name\" gelöscht';
  }

  @override
  String get marineLife_speciesManage_editTooltip => 'Art bearbeiten';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return 'Fehler beim Löschen der Art: $error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return 'Fehler beim Zurücksetzen der Arten: $error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound => 'Keine Arten gefunden';

  @override
  String get marineLife_speciesManage_resetButton => 'Zurücksetzen';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      'Dadurch werden alle integrierten Arten auf ihre ursprünglichen Werte zurückgesetzt. Benutzerdefinierte Arten werden nicht beeinflusst. Integrierte Arten mit vorhandenen Sichtungen werden aktualisiert, aber beibehalten.';

  @override
  String get marineLife_speciesManage_resetDialogTitle =>
      'Auf Standardwerte zurücksetzen?';

  @override
  String get marineLife_speciesManage_resetSuccess =>
      'Integrierte Arten auf Standardwerte zurückgesetzt';

  @override
  String get marineLife_speciesManage_resetToDefaults =>
      'Auf Standardwerte zurücksetzen';

  @override
  String get marineLife_speciesManage_searchHint => 'Arten durchsuchen...';

  @override
  String get marineLife_speciesPicker_allFilter => 'Alle';

  @override
  String get marineLife_speciesPicker_cancelButton => 'Abbrechen';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip => 'Suche löschen';

  @override
  String get marineLife_speciesPicker_closeTooltip => 'Artenauswahl schließen';

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
    return '$count ausgewählt';
  }

  @override
  String get marineLife_speciesPicker_title => 'Arten auswählen';

  @override
  String get media_diveMediaSection_addTooltip => 'Foto oder Video hinzufügen';

  @override
  String get media_diveMediaSection_cancelButton => 'Abbrechen';

  @override
  String get media_diveMediaSection_cancelSelectionButton => 'Abbrechen';

  @override
  String get media_diveMediaSection_emptyState => 'Noch keine Fotos';

  @override
  String get media_diveMediaSection_errorLoading =>
      'Fehler beim Laden der Medien';

  @override
  String get media_diveMediaSection_selectAllButton => 'Alle auswählen';

  @override
  String media_diveMediaSection_selectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Foto anzeigen. Lange drücken zum Trennen';

  @override
  String get media_diveMediaSection_title => 'Fotos & Video';

  @override
  String get media_diveMediaSection_replaceButton => 'Neu verknüpfen';

  @override
  String get media_diveMediaSection_replaceEditedContent =>
      'Der Inhalt dieser Datei unterscheidet sich vom Original. Beim Neuverknüpfen wird sie erneut in Ihren Medienspeicher hochgeladen.';

  @override
  String get media_diveMediaSection_replaceEditedTitle =>
      'Dateiinhalt unterscheidet sich';

  @override
  String get media_diveMediaSection_unlinkButton => 'Trennen';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Trennen fehlgeschlagen: $error';
  }

  @override
  String media_diveMediaSection_unlinkSelectedButton(int count) {
    return '$count trennen';
  }

  @override
  String media_diveMediaSection_unlinkSelectedContent(int count) {
    return 'Entfernt $count Medien samt Cloud-Kopien und Miniaturansichten aus deiner Mediathek. Medien, die ein Tauchplatz noch verwendet, bleiben erhalten. Deine Originaldateien bleiben unberührt.';
  }

  @override
  String media_diveMediaSection_unlinkSelectedSuccess(int count) {
    return '$count Elemente getrennt';
  }

  @override
  String media_diveMediaSection_unlinkSelectedTitle(int count) {
    return '$count Elemente trennen?';
  }

  @override
  String media_library_unlinkConfirmTitle(int count) {
    return '$count Elemente trennen?';
  }

  @override
  String media_siteMediaSection_unlinkError(Object error) {
    return 'Trennen fehlgeschlagen: $error';
  }

  @override
  String get media_library_unlinkConfirmBody =>
      'Sie verlassen deine Mediathek, samt Cloud-Kopien und Miniaturansichten. Deine Originaldateien bleiben unberührt. Dies kann nicht rückgängig gemacht werden.';

  @override
  String media_library_unlinkMetadataNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count davon haben eine Bildunterschrift oder Favoritenmarkierung in Submersion, diese Details gehen verloren.',
      one:
          'Eines davon hat eine Bildunterschrift oder Favoritenmarkierung in Submersion, diese Details gehen verloren.',
    );
    return '$_temp0';
  }

  @override
  String get media_siteMediaSection_title => 'Medien des Tauchplatzes';

  @override
  String get media_siteMediaSection_addPhotos => 'Fotos oder Videos hinzufügen';

  @override
  String get media_siteMediaSection_addDocument => 'Dokument hinzufügen';

  @override
  String get media_siteMediaSection_emptyState =>
      'Keine Karten, Fotos oder Dokumente an diesem Tauchplatz angehängt';

  @override
  String media_siteMediaSection_divePhotosGroup(int count) {
    return 'Fotos von Tauchgängen hier ($count)';
  }

  @override
  String get media_siteMediaSection_divePhotoLabel => 'Tauchgangsfoto';

  @override
  String media_siteMediaSection_unlinkSelectedTitle(int count) {
    return '$count Elemente trennen?';
  }

  @override
  String media_siteMediaSection_unlinkSelectedContent(int count) {
    return 'Entfernt $count Elemente aus Ihrer Bibliothek, einschließlich Cloud-Kopien und Vorschaubildern. Medien, die ein Tauchgang noch verwendet, bleiben erhalten. Ihre Originaldateien sind nicht betroffen.';
  }

  @override
  String media_siteMediaSection_unlinkSelectedSuccess(int count) {
    return '$count Elemente getrennt';
  }

  @override
  String get media_documentViewer_title => 'Dokument';

  @override
  String get media_documentViewer_unavailable =>
      'Dieses Dokument ist auf diesem Gerät nicht verfügbar';

  @override
  String get media_documentViewer_availableOnOriginDevice =>
      'Es ist auf dem Gerät verfügbar, von dem es hinzugefügt wurde, oder über einen konfigurierten Medienspeicher.';

  @override
  String media_documentViewer_attached(int count) {
    return '$count Dokumente angehängt';
  }

  @override
  String get media_diveScan_scanTooltip => 'Galerie nach Fotos durchsuchen';

  @override
  String get media_diveScan_noPhotosFound =>
      'Keine neuen Fotos in der Nähe dieses Tauchgangs gefunden';

  @override
  String get media_diveScan_accessDenied =>
      'Zugriff auf die Fotobibliothek ist erforderlich, um nach Fotos zu suchen';

  @override
  String media_diveScan_foundPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos',
      one: '1 Foto',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verknuepfen',
      one: 'Verknuepfen',
    );
    return '$_temp0 in der Nähe dieses Tauchgangs gefunden. $_temp1?';
  }

  @override
  String get media_diveScan_foundTitle => 'Fotos gefunden';

  @override
  String media_diveScan_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fotos',
      one: 'Foto',
    );
    return '$_temp0 verknüpfen';
  }

  @override
  String get media_diveScan_cancelButton => 'Abbrechen';

  @override
  String media_diveScan_error(String error) {
    return 'Fehler beim Durchsuchen der Galerie: $error';
  }

  @override
  String get media_gpsBanner_addToSiteButton => 'Zum Tauchplatz hinzufügen';

  @override
  String media_gpsBanner_coordinates(Object coordinates) {
    return 'Koordinaten: $coordinates';
  }

  @override
  String get media_gpsBanner_createSiteButton => 'Tauchplatz erstellen';

  @override
  String get media_gpsBanner_dismissTooltip => 'GPS-Vorschlag schließen';

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
  String media_import_allAlreadyLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos bereits mit diesem Tauchgang verknüpft',
      one: '1 Foto bereits mit diesem Tauchgang verknüpft',
    );
    return '$_temp0';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return '$imported importiert, $failed fehlgeschlagen';
  }

  @override
  String media_import_importedAndSkipped(int imported, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      imported,
      locale: localeName,
      other: '$imported Fotos importiert',
      one: '1 Foto importiert',
    );
    return '$_temp0 ($skipped bereits verknüpft)';
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
  String get media_lightroom_openInLightroom => 'In Lightroom öffnen';

  @override
  String get media_lightroom_suggestion_accept =>
      'Zu diesem Tauchgang hinzufügen';

  @override
  String get media_lightroom_suggestion_dismiss => 'Verwerfen';

  @override
  String get media_lightroom_suggestions_title => 'Vorschläge aus Lightroom';

  @override
  String get media_miniProfile_headerLabel => 'Tauchprofil';

  @override
  String get media_miniProfile_semanticLabel => 'Mini-Tauchprofildiagramm';

  @override
  String get media_photoPicker_appBarTitle => 'Fotos auswählen';

  @override
  String get media_photoPicker_tab_gallery => 'Galerie';

  @override
  String get media_photoPicker_tab_files => 'Dateien';

  @override
  String get media_photoPicker_tab_url => 'URL';

  @override
  String get media_photoPicker_clearSelectionButton => 'Löschen';

  @override
  String get media_photoPicker_closeTooltip => 'Fotoauswahl schließen';

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
  String get media_photoPicker_grantAccessButton => 'Weiter';

  @override
  String get media_photoPicker_openSettingsButton => 'Einstellungen öffnen';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'Der Zugriff auf die Fotobibliothek wurde verweigert. Bitte aktivieren Sie ihn in den Einstellungen, um Tauchfotos hinzuzufügen.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion benötigt Zugriff auf Ihre Fotobibliothek, um Tauchfotos hinzuzufügen.';

  @override
  String get media_photoPicker_permissionTitle => 'Tauchfotos';

  @override
  String get media_photoPicker_selectAllButton => 'Alle auswählen';

  @override
  String media_photoPicker_selectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return 'Fotos werden angezeigt von $rangeText';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel =>
      'Auswahl für Foto umschalten';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel =>
      'Auswahl für Foto umschalten, ausgewählt';

  @override
  String get media_photoPicker_files_pickFilesButton => 'Dateien auswählen…';

  @override
  String get media_photoPicker_files_pickFolderButton => 'Ordner auswählen…';

  @override
  String get media_photoPicker_files_autoMatchLabel =>
      'Fotos und Videos automatisch nach Datum den Tauchgängen zuordnen';

  @override
  String get media_photoPicker_files_emptyHint =>
      'Wähle Dateien oder einen Ordner aus, um zu beginnen.';

  @override
  String media_photoPicker_files_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente verknüpfen',
      one: '1 Element verknüpfen',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachToSiteButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente diesem Tauchplatz zuordnen',
      one: '1 Element diesem Tauchplatz zuordnen',
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
      other: '$fileCount Dateien',
      one: '1 Datei',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount Tauchgänge',
      one: '1 Tauchgang',
    );
    return '$_temp0, $_temp1, $unmatchedCount nicht zugeordnet';
  }

  @override
  String media_photoPicker_files_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente',
      one: '1 Element',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_diveGroupTitle(String diveId) {
    return 'Tauchgang $diveId';
  }

  @override
  String media_photoPicker_files_groupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_unmatchedGroupTitle => 'Nicht zugeordnet';

  @override
  String media_photoPicker_files_addAllToDive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count zu diesem Tauchgang hinzufügen',
      one: '1 zu diesem Tauchgang hinzufügen',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_addToDiveTooltip =>
      'Zu diesem Tauchgang hinzufügen';

  @override
  String get media_photoPicker_files_chooseDiveTooltip => 'Tauchgang auswählen';

  @override
  String get media_photoPicker_files_removeTooltip =>
      'Aus der Auswahl entfernen';

  @override
  String get media_photoPicker_files_sourceExif => 'aus EXIF';

  @override
  String get media_photoPicker_files_sourceContainer => 'aus Dateimetadaten';

  @override
  String get media_photoPicker_files_sourceFileDate => 'aus Dateidatum';

  @override
  String get media_photoPicker_files_sourceNone => 'kein Datum gefunden';

  @override
  String media_photoPicker_files_shiftedTime(String shifted, String original) {
    return '$shifted (war $original)';
  }

  @override
  String get media_photoPicker_files_reasonNoTimestamp =>
      'Keine Aufnahmezeit lesbar';

  @override
  String media_photoPicker_files_reasonBeforeDive(String gap) {
    return '$gap vor dem nächsten Tauchgang';
  }

  @override
  String media_photoPicker_files_reasonAfterDive(String gap) {
    return '$gap nach dem nächsten Tauchgang';
  }

  @override
  String get media_photoPicker_files_reasonNoDives =>
      'Keine Tauchgänge zum Abgleichen';

  @override
  String get media_photoPicker_files_offsetLabel =>
      'Aufnahmezeiten verschieben um';

  @override
  String get media_photoPicker_files_offsetResetTooltip =>
      'Verschiebung zurücksetzen';

  @override
  String media_photoPicker_files_offsetBackTooltip(String amount) {
    return 'Um $amount früher verschieben';
  }

  @override
  String media_photoPicker_files_offsetForwardTooltip(String amount) {
    return 'Um $amount später verschieben';
  }

  @override
  String media_photoPicker_files_linkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente verknüpft',
      one: '1 Element verknüpft',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachedToSiteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente diesem Tauchplatz zugeordnet',
      one: '1 Element diesem Tauchplatz zugeordnet',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_undo => 'Rückgängig';

  @override
  String get media_photoPicker_thumbnailAlreadyLinkedLabel =>
      'Foto bereits mit diesem Tauchgang verknüpft';

  @override
  String get media_perdixOverlay_labelCns => 'CNS';

  @override
  String get media_perdixOverlay_labelDepth => 'TIEFE';

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
  String get media_perdixOverlay_labelTime => 'ZEIT';

  @override
  String get media_perdixOverlay_labelTts => 'TTS';

  @override
  String get media_perdixOverlay_toggleTooltip => 'Tauchcomputer-Overlay';

  @override
  String get media_photoViewer_cannotShare =>
      'Dieses Foto kann nicht geteilt werden';

  @override
  String get media_photoViewer_cannotWriteMetadata =>
      'Metadaten können nicht geschrieben werden - Medium nicht mit Bibliothek verknüpft';

  @override
  String get media_photoViewer_closeTooltip => 'Fotoanzeige schließen';

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
  String get media_photoViewer_nextTooltip => 'Nächstes Medium';

  @override
  String get media_photoViewer_noPhotosAvailable => 'Keine Fotos verfügbar';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel =>
      'Video abspielen oder pausieren';

  @override
  String get media_photoViewer_previousTooltip => 'Vorheriges Medium';

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
      'Video nicht mit Bibliothek verknüpft';

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
      'Geben Sie einen Namen für diesen Tauchplatz ein';

  @override
  String get media_quickSiteDialog_siteNameLabel => 'Tauchplatzname';

  @override
  String get media_quickSiteDialog_title => 'Tauchplatz erstellen';

  @override
  String get media_scanResults_allPhotosLinked =>
      'Alle Fotos bereits verknüpft';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return 'Alle $count Fotos dieser Reise sind bereits mit Tauchgängen verknüpft.';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count Fotos bereits verknüpft';
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
  String get media_scanResults_linkButton => 'Verknüpfen';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return '$count Fotos verknüpfen';
  }

  @override
  String get media_scanResults_noPhotosFound => 'Keine Fotos gefunden';

  @override
  String get media_scanResults_okButton => 'OK';

  @override
  String get media_scanResults_unknownSite => 'Unbekannter Tauchplatz';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return '$count Fotos konnten keinem Tauchgang zugeordnet werden (außerhalb der Tauchzeiten aufgenommen)';
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
  String get media_unavailablePlaceholder_notOnDevice =>
      'Nicht auf diesem Gerät';

  @override
  String get media_unavailablePlaceholder_signInRequired => 'Sign in to view';

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
  String get media_writeMetadata_livePhotoUnsupported =>
      'Live Photos werden noch nicht unterstützt. Dupliziere dieses Foto als Standbild und schreibe die Tauchdaten dann in die Kopie.';

  @override
  String get media_writeMetadata_noDataAvailable =>
      'Keine Tauchdaten zum Schreiben verfügbar.';

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
      'Dadurch wird das Originalfoto verändert.';

  @override
  String get media_writeMetadata_warningVideoText =>
      'Es wird ein neues Video mit den Metadaten erstellt. Video-Metadaten können nicht direkt verändert werden.';

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
  String get nav_dives => 'Tauchgänge';

  @override
  String get nav_equipment => 'Ausrüstung';

  @override
  String get nav_gpsLog => 'GPS-Log';

  @override
  String get media_console_library => 'Bibliothek';

  @override
  String get media_console_transfers => 'Übertragungen';

  @override
  String get media_console_import => 'Importieren';

  @override
  String get media_import_launch => 'Medien importieren...';

  @override
  String get media_import_review_title => 'Import prüfen';

  @override
  String media_import_review_confirm(int count) {
    return '$count Elemente importieren';
  }

  @override
  String media_import_review_result(int linked, int skipped, int failed) {
    return '$linked verknüpft, $skipped übersprungen, $failed fehlgeschlagen';
  }

  @override
  String get media_import_review_chooseSite => 'Tauchplatz wählen';

  @override
  String get media_import_review_ambiguous => 'Mehrere Tauchgänge passen';

  @override
  String get media_import_review_noMatch => 'Kein passender Tauchgang';

  @override
  String get media_import_review_skipped => 'Nicht importiert';

  @override
  String media_import_review_linkChip(int number) {
    return 'Mit #$number verknüpfen';
  }

  @override
  String get media_import_review_linkToDive => 'Mit Tauchgang verknüpfen';

  @override
  String get media_import_review_linkToSite => 'Mit Tauchplatz verknüpfen';

  @override
  String get media_import_review_chooseDive => 'Tauchgang wählen';

  @override
  String get media_import_intro =>
      'Fotos werden beim Import mit einem Tauchgang oder Tauchplatz verknüpft.';

  @override
  String get media_console_sources => 'Quellen';

  @override
  String get media_sources_browseHeader => 'Nach Quelle durchsuchen';

  @override
  String get media_sources_watchedHeader => 'Überwachte Ordner';

  @override
  String get media_sources_addWatched => 'Ordner hinzufügen...';

  @override
  String get media_sources_scanFailed => 'Scan fehlgeschlagen';

  @override
  String get media_sources_scanNow => 'Jetzt scannen';

  @override
  String get media_sources_autoApply =>
      'Exakte Treffer automatisch neu verknüpfen';

  @override
  String get media_sources_neverScanned => 'Noch nie gescannt';

  @override
  String get media_source_gallery => 'Fotomediathek';

  @override
  String get media_source_localFile => 'Lokale Dateien';

  @override
  String get media_source_networkUrl => 'Weblinks';

  @override
  String get media_source_manifest => 'Abonnements';

  @override
  String get media_source_connector => 'Verbundene Dienste';

  @override
  String get media_source_mediaStore => 'Cloud-Medienspeicher';

  @override
  String get media_source_signature => 'Unterschriften';

  @override
  String get media_repairHistory_title => 'Reparaturverlauf';

  @override
  String get media_repairHistory_empty => 'Noch keine Reparaturen';

  @override
  String get media_repairHistory_action_relink => 'Neu verknüpft';

  @override
  String get media_repairHistory_action_cloudBacked => 'Cloudgestützt';

  @override
  String get media_repairHistory_action_autoRelink =>
      'Automatisch neu verknüpft';

  @override
  String get media_smartAlbum_save => 'Als Album speichern';

  @override
  String get media_smartAlbum_saveTitle => 'Album benennen';

  @override
  String get media_smartAlbum_albums => 'Alben';

  @override
  String get media_smartAlbum_delete => 'Album löschen';

  @override
  String get media_smartAlbum_deleteFailed =>
      'Album konnte nicht gelöscht werden';

  @override
  String get media_smartAlbum_saved => 'Album gespeichert';

  @override
  String media_sources_lastScanned(String date) {
    return 'Zuletzt gescannt $date';
  }

  @override
  String media_sources_scanResult(int indexed, int repaired) {
    return '$indexed Dateien indiziert, $repaired neu verknüpft';
  }

  @override
  String get media_repairHistory_sourceFolder => 'Ordnersuche';

  @override
  String get media_repairHistory_sourcePhotoLibrary => 'Fotomediathek';

  @override
  String get media_repairHistory_sourceStore => 'Cloud-Medienspeicher';

  @override
  String get media_repairHistory_sourceWatcher => 'überwachte Ordner';

  @override
  String get media_repairHistory_sourceManual => 'manuelle Neuverknüpfung';

  @override
  String media_repairHistory_source(String source) {
    return 'über $source';
  }

  @override
  String get media_missing_empty => 'Keine fehlenden Dateien';

  @override
  String media_missing_offlineVolumes(int count) {
    return '$count auf Offline-Laufwerken';
  }

  @override
  String get media_missing_repair => 'Reparieren...';

  @override
  String get media_repair_title => 'Fehlende Dateien reparieren';

  @override
  String get media_repair_addFolder => 'Ordner hinzufügen...';

  @override
  String get media_repair_usePhotoLibrary => 'Fotomediathek durchsuchen';

  @override
  String get media_repair_useStore => 'Cloud-Medienspeicher verwenden';

  @override
  String get media_repair_scan => 'Scannen';

  @override
  String media_repair_prefixMove(String from, String to, int count) {
    return 'Ordnerverschiebung erkannt: $from nach $to deckt $count Dateien ab';
  }

  @override
  String get media_repair_confidence_exact => 'Exakt';

  @override
  String get media_repair_confidence_probable => 'Name und Größe';

  @override
  String get media_repair_confidence_edited => 'Bearbeitete Datei';

  @override
  String get media_repair_confidence_unmatched => 'Kein Kandidat';

  @override
  String get media_repair_unverified => 'Nicht gegen den Speicher verifiziert';

  @override
  String media_repair_apply(int count) {
    return '$count Dateien neu verknüpfen';
  }

  @override
  String media_repair_summary(
    int relinked,
    int cloudBacked,
    int reuploads,
    int failed,
    int skipped,
  ) {
    return '$relinked neu verknüpft, $cloudBacked cloudgestützt, $reuploads erneute Uploads eingereiht, $failed fehlgeschlagen, $skipped übersprungen';
  }

  @override
  String get media_library_empty => 'Noch keine Medien';

  @override
  String get media_library_filter_all => 'Alle';

  @override
  String get media_library_filter_photos => 'Fotos';

  @override
  String get media_library_filter_videos => 'Videos';

  @override
  String get media_library_filter_site => 'Tauchplatz';

  @override
  String get media_library_filter_trip => 'Reise';

  @override
  String get media_library_filter_dates => 'Zeitraum';

  @override
  String get media_library_filter_missing => 'Fehlende Dateien';

  @override
  String media_library_filter_missingCount(int count) {
    return 'Fehlende Dateien ($count)';
  }

  @override
  String get media_library_filter_clear => 'Filter zurücksetzen';

  @override
  String get media_library_filter_any => 'Beliebig';

  @override
  String get media_library_filter_title => 'Medien filtern';

  @override
  String get media_library_filter_apply => 'Übernehmen';

  @override
  String get media_library_sort_title => 'Medien sortieren';

  @override
  String get media_smartAlbum_load => 'Album laden';

  @override
  String get media_divePicker_title => 'Zu Tauchgang verschieben';

  @override
  String get media_divePicker_search => 'Tauchgänge durchsuchen';

  @override
  String get media_library_moveToDive => 'Zu Tauchgang verschieben';

  @override
  String get media_library_unlinkSelected => 'Trennen';

  @override
  String media_library_selectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get media_library_unlinkedHeader => 'Nicht verknüpft';

  @override
  String get media_library_diveHeaderHint => 'Diesen Tauchgang öffnen';

  @override
  String get media_library_untitledDiveHeader => 'Unbenannter Tauchgang';

  @override
  String get media_library_viewMode_byDive => 'Nach Tauchgang';

  @override
  String get media_library_viewMode_grid => 'Raster';

  @override
  String get media_library_viewMode_timeline => 'Zeitleiste';

  @override
  String get media_viewer_goToDive => 'Zum Tauchgang';

  @override
  String get nav_home => 'Startseite';

  @override
  String get nav_media => 'Medien';

  @override
  String get nav_more => 'Mehr';

  @override
  String get nav_planning => 'Planung';

  @override
  String get nav_planningSubtitle => 'Tauchplaner, Rechner';

  @override
  String get nav_settings => 'Einstellungen';

  @override
  String get nav_sites => 'Tauchplätze';

  @override
  String get nav_statistics => 'Statistiken';

  @override
  String get nav_tooltip_closeMenu => 'Menü schließen';

  @override
  String get nav_tooltip_collapseMenu => 'Menü einklappen';

  @override
  String get nav_tooltip_expandMenu => 'Menü ausklappen';

  @override
  String get nav_transfer => 'Übertragung';

  @override
  String get nav_trips => 'Reisen';

  @override
  String plannerCanvas_bailout_available(String liters) {
    return 'Verfügbar $liters';
  }

  @override
  String get plannerCanvas_bailout_insufficient =>
      'Bailout-Gas reicht für den schlimmsten Fall nicht aus';

  @override
  String plannerCanvas_bailout_required(String liters) {
    return 'Benötigt $liters';
  }

  @override
  String get plannerCanvas_bailout_title => 'Bailout (offener Kreislauf)';

  @override
  String plannerCanvas_bailout_tts(String minutes) {
    return 'Bailout-TTS $minutes′';
  }

  @override
  String plannerCanvas_bailout_worstCase(String minutes, String depth) {
    return 'Schlimmster Fall bei $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_ccr_setpointHigh => 'Setpoint hoch (bar)';

  @override
  String get plannerCanvas_ccr_setpointLow => 'Setpoint niedrig (bar)';

  @override
  String get plannerCanvas_ccr_switchDepth => 'Setpoint-Wechseltiefe';

  @override
  String get plannerCanvas_pscr_ratio => 'pSCR-Verhältnis';

  @override
  String get plannerCanvas_pscr_ratio_hint =>
      'Größer = mehr Frischgas, geringerer O₂-Abfall';

  @override
  String plannerCanvas_chip_cns(String value) {
    return 'CNS $value%';
  }

  @override
  String plannerCanvas_chip_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Probleme',
      one: '1 Problem',
    );
    return '$_temp0';
  }

  @override
  String get plannerCanvas_compare_action => 'Vergleichen';

  @override
  String get plannerCanvas_compare_needTwo =>
      'Wähle mindestens zwei Pläne zum Vergleichen';

  @override
  String get plannerCanvas_compare_title => 'Pläne vergleichen';

  @override
  String get plannerCanvas_contingency_base => 'Basis';

  @override
  String get plannerCanvas_contingency_depthDelta => 'Zusatztiefe';

  @override
  String plannerCanvas_contingency_lostGas(String gas) {
    return '$gas verloren';
  }

  @override
  String plannerCanvas_contingency_previewing(String label) {
    return 'Vorschau: $label';
  }

  @override
  String get plannerCanvas_contingency_timeDelta => 'Zusatzminuten';

  @override
  String plannerCanvas_chart_meanDepth(String depth) {
    return 'Mittel $depth';
  }

  @override
  String get plannerCanvas_contingency_title => 'Eventualpläne';

  @override
  String get plannerCanvas_contingency_turnFraction => 'Umkehranteil';

  @override
  String get plannerCanvas_contingency_turnRule => 'Umkehrdruck-Regel';

  @override
  String get plannerCanvas_convert_success => 'Tauchgang aus Plan erstellt';

  @override
  String get plannerCanvas_convert_view => 'Anzeigen';

  @override
  String plannerCanvas_follow_chip(String name) {
    return 'Folgt $name';
  }

  @override
  String get plannerCanvas_follow_empty => 'Noch keine geloggten Tauchgänge';

  @override
  String get plannerCanvas_follow_noTissues =>
      'Keine Profildaten für diesen Tauchgang — Oberflächenpause ohne Gewebesättigung übernommen';

  @override
  String get plannerCanvas_follow_title => 'Einem Tauchgang folgen';

  @override
  String plannerCanvas_gas_minGas(String pressure) {
    return 'Min-Gas $pressure';
  }

  @override
  String plannerCanvas_gas_turnAt(String pressure) {
    return 'Umkehr bei $pressure';
  }

  @override
  String plannerCanvas_issue_gasDensityCritical(String value) {
    return 'Gasdichte $value g/L über hartem Limit';
  }

  @override
  String plannerCanvas_issue_gasDensityHigh(String value) {
    return 'Gasdichte $value g/L über empfohlenem Limit';
  }

  @override
  String plannerCanvas_issue_hypoxic(String depth, String value) {
    return 'Hypoxisches Gas bei $depth (ppO₂ $value bar)';
  }

  @override
  String plannerCanvas_issue_minGas(String pressure) {
    return 'Flasche endet unter dem Rock-Bottom-Minimum von $pressure';
  }

  @override
  String get plannerCanvas_issue_noBailout =>
      'CCR-Dekompressionsplan führt kein Bailout-Gas mit';

  @override
  String get plannerCanvas_issue_noDecoGas =>
      'Dekompression erforderlich, aber kein Deko-Gas mitgeführt';

  @override
  String get plannerCanvas_range_base => 'Basis';

  @override
  String get plannerCanvas_range_legend =>
      'Zellen zeigen die Zeit bis zur Oberfläche; rot = nicht wie geplant tauchbar';

  @override
  String get plannerCanvas_pane_collapse => 'Bereich einklappen';

  @override
  String get plannerCanvas_pane_expand => 'Bereich ausklappen';

  @override
  String get plannerCanvas_tab_setup => 'Einrichtung';

  @override
  String get plannerCanvas_o2Narcotic => 'O₂ als narkotisch behandeln';

  @override
  String get plannerCanvas_rates_ascent => 'Aufstiegsrate';

  @override
  String get plannerCanvas_rates_descent => 'Abstiegsrate';

  @override
  String get plannerCanvas_rates_title => 'Raten';

  @override
  String get plannerCanvas_range_title => 'Bereichstabelle';

  @override
  String get plannerCanvas_results_noDeco => 'Keine Dekompression erforderlich';

  @override
  String plannerCanvas_sac_useLogged(String sac) {
    return 'Geloggten Durchschnitt verwenden ($sac)';
  }

  @override
  String plannerCanvas_saved_deleteConfirmBody(String name) {
    return '„$name“ endgültig löschen?';
  }

  @override
  String get plannerCanvas_saved_deleteConfirmTitle => 'Plan löschen?';

  @override
  String get plannerCanvas_saved_duplicate => 'Duplizieren';

  @override
  String get plannerCanvas_saved_empty => 'Noch keine gespeicherten Pläne';

  @override
  String get plannerCanvas_saved_title => 'Gespeicherte Pläne';

  @override
  String get plannerCanvas_name_dialogTitle => 'Plan benennen';

  @override
  String get plannerCanvas_name_defaultFallback => 'Tauchplan';

  @override
  String plannerCanvas_scrub_bailout(String minutes) {
    return 'BO $minutes′';
  }

  @override
  String plannerCanvas_scrub_readout(String minutes, String depth) {
    return 'RT $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_share_import => 'Importieren';

  @override
  String plannerCanvas_share_importFailed(String reason) {
    return 'Plan konnte nicht importiert werden: $reason';
  }

  @override
  String get plannerCanvas_share_menu => 'Plandatei teilen';

  @override
  String get plannerCanvas_slate_menu => 'Slate exportieren (PDF)';

  @override
  String get plannerCanvas_slate_minGas => 'Min-Gas';

  @override
  String get plannerCanvas_slate_turn => 'Umkehr';

  @override
  String get plannerCanvas_table_depth => 'Tiefe';

  @override
  String get plannerCanvas_table_gas => 'Gas';

  @override
  String get plannerCanvas_table_runtime => 'RT';

  @override
  String get plannerCanvas_table_stop => 'Stopp';

  @override
  String get plannerCanvas_turnRule_allUsable => 'Alles nutzbar';

  @override
  String get plannerCanvas_turnRule_custom => 'Benutzerdefiniert';

  @override
  String get plannerCanvas_turnRule_halves => 'Hälften';

  @override
  String get plannerCanvas_turnRule_none => 'Keine';

  @override
  String get plannerCanvas_turnRule_thirds => 'Drittel';

  @override
  String get planning_appBar_title => 'Planung';

  @override
  String get planning_card_decoCalculator_description =>
      'Berechnen Sie Nullzeitgrenzen, erforderliche Dekostopps und CNS/OTU-Belastung für mehrstufige Tauchprofile.';

  @override
  String get planning_card_decoCalculator_subtitle =>
      'Tauchgänge mit Dekostopps planen';

  @override
  String get planning_card_decoCalculator_title => 'Deko-Rechner';

  @override
  String get planning_card_divePlanner_description =>
      'Planen Sie anspruchsvolle Tauchgänge mit mehreren Tiefenstufen, Gaswechseln und automatischer Dekostopp-Berechnung.';

  @override
  String get planning_card_divePlanner_subtitle =>
      'Mehrstufige Tauchpläne erstellen';

  @override
  String get planning_card_divePlanner_title => 'Tauchplaner';

  @override
  String get planning_card_gasCalculators_description =>
      'Vier spezialisierte Gasrechner:\n- MOD - Maximale Einsatztiefe für ein Gasgemisch\n- Beste Mischung - Idealer O₂-Anteil für eine Zieltiefe\n- Verbrauch - Schätzung des Gasverbrauchs\n- Mindrestreserve - Berechnung der Notfallreserve';

  @override
  String get planning_card_gasCalculators_subtitle =>
      'MOD, Beste Mischung, Verbrauch, Mindrestreserve';

  @override
  String get planning_card_gasCalculators_title => 'Gasrechner';

  @override
  String get planning_card_surfaceInterval_description =>
      'Berechnen Sie das erforderliche Mindestoberflächen-Intervall zwischen Tauchgängen basierend auf der Gewebebelastung. Visualisieren Sie, wie Ihre 16 Gewebekompartimente über die Zeit entsättigen.';

  @override
  String get planning_card_surfaceInterval_subtitle =>
      'Wiederholungstauchgang-Intervalle planen';

  @override
  String get planning_card_surfaceInterval_title => 'Oberflächen-Intervall';

  @override
  String get planning_card_weightCalculator_description =>
      'Schätzen Sie das benötigte Gewicht basierend auf Ihrem Tauchanzug, Flaschenmaterial, Wassertyp und Körpergewicht.';

  @override
  String get planning_card_weightCalculator_subtitle =>
      'Empfohlenes Gewicht für Ihre Konfiguration';

  @override
  String get planning_card_weightCalculator_title => 'Gewichtsrechner';

  @override
  String get planning_info_disclaimer =>
      'Diese Werkzeuge dienen nur der Planung. Überprüfen Sie Berechnungen immer und befolgen Sie Ihre Tauchausbildung.';

  @override
  String get planning_newPlan => 'Neuer Plan';

  @override
  String get planning_section_tools => 'Werkzeuge';

  @override
  String get planning_summary_prompt => 'Wähle ein Werkzeug zum Starten';

  @override
  String get planning_summary_savedPlans => 'Gespeicherte Pläne';

  @override
  String get planning_summary_noPlans => 'Noch keine gespeicherten Pläne';

  @override
  String get planning_sidebar_appBar_title => 'Planung';

  @override
  String get planning_sidebar_decoCalculator_subtitle => 'NDL & Dekostopps';

  @override
  String get planning_sidebar_decoCalculator_title => 'Deko-Rechner';

  @override
  String get planning_sidebar_divePlanner_subtitle => 'Mehrstufige Tauchpläne';

  @override
  String get planning_sidebar_divePlanner_title => 'Tauchplaner';

  @override
  String get planning_sidebar_gasCalculators_subtitle =>
      'MOD, Beste Mischung, mehr';

  @override
  String get planning_sidebar_gasCalculators_title => 'Gasrechner';

  @override
  String get planning_sidebar_info_disclaimer =>
      'Planungswerkzeuge dienen nur als Referenz. Überprüfen Sie Berechnungen immer.';

  @override
  String get planning_sidebar_surfaceInterval_subtitle =>
      'Wiederholungstauchgang-Planung';

  @override
  String get planning_sidebar_surfaceInterval_title => 'Oberflächen-Intervall';

  @override
  String get planning_sidebar_weightCalculator_subtitle =>
      'Empfohlenes Gewicht';

  @override
  String get planning_sidebar_weightCalculator_title => 'Gewichtsrechner';

  @override
  String get planning_welcome_quickTips_title => 'Schnelltipps';

  @override
  String get planning_welcome_subtitle =>
      'Wählen Sie ein Werkzeug aus der Seitenleiste, um zu beginnen';

  @override
  String get planning_welcome_tip_decoCalculator =>
      'Deko-Rechner für NDL und Stoppzeiten';

  @override
  String get planning_welcome_tip_divePlanner =>
      'Tauchplaner für mehrstufige Tauchplanung';

  @override
  String get planning_welcome_tip_gasCalculators =>
      'Gasrechner für MOD und Gasplanung';

  @override
  String get planning_welcome_tip_weightCalculator =>
      'Gewichtsrechner für die Tarierung';

  @override
  String get planning_welcome_title => 'Planungswerkzeuge';

  @override
  String get settings_about_aboutSubmersion => 'Über Submersion';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description =>
      'Verfolgen Sie Ihre Tauchgänge, verwalten Sie Ausrüstung und erkunden Sie Tauchplätze.';

  @override
  String get settings_about_header => 'Über';

  @override
  String get settings_about_openSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get settings_about_reportIssue => 'Problem melden';

  @override
  String get settings_about_reportIssue_copy => 'Link kopieren';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Besuchen Sie github.com/submersion-app/submersion/issues';

  @override
  String settings_about_version(String version) {
    return 'Version $version';
  }

  @override
  String get settings_appBar_title => 'Einstellungen';

  @override
  String get settings_appearance_appLanguage => 'App-Sprache';

  @override
  String get settings_appearance_displaySize => 'Anzeigegröße';

  @override
  String settings_appearance_displaySize_value(int percent) {
    return '$percent%';
  }

  @override
  String get settings_appearance_displaySize_reset => 'Zurücksetzen';

  @override
  String get settings_appearance_displaySize_smaller => 'Kleiner';

  @override
  String get settings_appearance_displaySize_larger => 'Größer';

  @override
  String get settings_appearance_depthColoredCards =>
      'Tiefengefärbte Tauchkarten';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Tauchkarten mit ozeanfarbenen Hintergründen basierend auf der Tiefe anzeigen';

  @override
  String get settings_appearance_cardColorAttribute => 'Karten färben nach';

  @override
  String get settings_appearance_cardColorAttribute_subtitle =>
      'Wählen Sie, welches Attribut die Hintergrundfarbe der Karten bestimmt';

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
      'Wählen Sie den Farbbereich für Kartenhintergründe';

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
      'Markierungen für Gaswechsel anzeigen';

  @override
  String get settings_appearance_gasTimeline => 'Gas-Zeitleiste';

  @override
  String get settings_appearance_gasTimeline_subtitle =>
      'Gasverbrauchsleiste standardmäßig unter dem Tauchprofil anzeigen';

  @override
  String get settings_appearance_header_diveDetails => 'Tauchgang-Details';

  @override
  String get settings_appearance_header_diveLog => 'Tauchlogbuch';

  @override
  String get settings_appearance_header_diveProfile => 'Tauchprofil';

  @override
  String get settings_appearance_header_diveSites => 'Tauchplätze';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility =>
      'Abschnittsreihenfolge &amp; Sichtbarkeit';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility_subtitle =>
      'Auswählen, welche Abschnitte angezeigt werden und in welcher Reihenfolge';

  @override
  String get settings_diveDetailSections_title =>
      'Abschnittsreihenfolge &amp; Sichtbarkeit';

  @override
  String get settings_diveDetailSections_resetToDefault =>
      'Auf Standard zurücksetzen';

  @override
  String get settings_diveDetailSections_fixedSections =>
      'Feste Abschnitte: Kopfzeile, Tauchprofil-Diagramm';

  @override
  String get settings_diveDetailSections_configurableSections =>
      'Konfigurierbare Abschnitte (zum Neuanordnen ziehen)';

  @override
  String get diveDetailSection_decoO2_name => 'Deko-Status / Gewebsauslastung';

  @override
  String get diveDetailSection_decoO2_description =>
      'NDL, Ceiling, Gewebsauslastung, O2-Toxizität';

  @override
  String get diveDetailSection_safetyReview_name => 'Sicherheitsüberprüfung';

  @override
  String get diveDetailSection_safetyReview_description =>
      'Automatische Profilbeobachtungen nach dem Tauchgang';

  @override
  String get safetyReview_sectionTitle => 'Sicherheitsüberprüfung';

  @override
  String safetyReview_findingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Beobachtungen',
      one: '1 Beobachtung',
    );
    return '$_temp0';
  }

  @override
  String safetyReview_rapidAscent_title(String rate, String duration) {
    return 'Aufstieg überschritt $rate für $duration';
  }

  @override
  String safetyReview_missedDecoStop_title(String excess, String duration) {
    return 'Tiefe lag für $duration $excess über dem erforderlichen Deko-Ceiling';
  }

  @override
  String safetyReview_omittedSafetyStop_title(String remaining) {
    return 'Der empfohlene Sicherheitsstopp wurde um $remaining verkürzt';
  }

  @override
  String safetyReview_sawtoothProfile_title(int count) {
    return '$count wiederholte Auf- und Abwärtsbewegungen während des Tauchgangs';
  }

  @override
  String safetyReview_highSurfaceGf_title(String gf, String gfHigh) {
    return 'Aufgetaucht bei Gradientenfaktor $gf, über dem konfigurierten $gfHigh';
  }

  @override
  String safetyReview_timeRange(String start, String end) {
    return 'Bei $start–$end';
  }

  @override
  String get safetyReview_dismiss => 'Ausblenden';

  @override
  String get safetyReview_restore => 'Wiederherstellen';

  @override
  String get safetyReview_dismissAll => 'Alle ausblenden';

  @override
  String get safetyReview_restoreAll => 'Alle wiederherstellen';

  @override
  String get safetySettings_dismissAll => 'Alle Beobachtungen ausblenden';

  @override
  String get safetySettings_dismissAll_subtitle =>
      'Alle Beobachtungen in diesem Logbuch als geprüft markieren';

  @override
  String get safetySettings_dismissAll_confirmTitle =>
      'Alle Beobachtungen ausblenden?';

  @override
  String get safetySettings_dismissAll_confirmBody =>
      'Jede Beobachtung zu jedem analysierten Tauchgang wird als geprüft markiert. Du kannst sie im Abschnitt Sicherheitsüberprüfung eines Tauchgangs einzeln wiederherstellen.';

  @override
  String get safetySettings_dismissAll_confirm => 'Alle ausblenden';

  @override
  String get safetySettings_dismissAll_cancel => 'Abbrechen';

  @override
  String safetySettings_dismissAll_progress(int done, int total) {
    return '$done von $total Tauchgängen geprüft';
  }

  @override
  String safetySettings_dismissAll_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Beobachtungen ausgeblendet',
      one: '1 Beobachtung ausgeblendet',
      zero: 'Keine Beobachtungen zum Ausblenden',
    );
    return '$_temp0';
  }

  @override
  String safetySettings_dismissAll_doneWithErrors(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Beobachtungen ausgeblendet',
      one: '1 Beobachtung ausgeblendet',
      zero: 'Keine Beobachtungen ausgeblendet',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed Tauchgänge konnten nicht aktualisiert werden',
      one: '1 Tauchgang konnte nicht aktualisiert werden',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get safetySettings_dismissAll_failed =>
      'Die Tauchgangsliste konnte nicht gelesen werden. Es wurde nichts geändert.';

  @override
  String get safetySettings_analyzeAll_failed =>
      'Die Tauchgänge konnten nicht analysiert werden.';

  @override
  String get safetyReview_details => 'Details';

  @override
  String get safetyReview_clearHighlight => 'Hervorhebung entfernen';

  @override
  String safetyReview_findingGroupSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sicherheitshinweise',
      one: '1 Sicherheitshinweis',
    );
    return '$_temp0';
  }

  @override
  String get safetySettings_title => 'Sicherheitsüberprüfung';

  @override
  String get safetySettings_entry_subtitle =>
      'Beobachtungen und Regeln nach dem Tauchgang';

  @override
  String get safetySettings_masterToggle =>
      'Sicherheitsüberprüfung nach dem Tauchgang';

  @override
  String get safetySettings_masterToggle_subtitle =>
      'Aufstiegs-, Stopp- und Profilbeobachtungen bei analysierten Tauchgängen automatisch vermerken';

  @override
  String get safetySettings_rulesHeader => 'Regeln';

  @override
  String get safetySettings_rule_rapidAscent => 'Schnelle Aufstiege';

  @override
  String get safetySettings_rule_missedDecoStop =>
      'Ausgelassene oder verkürzte Deko-Stopps';

  @override
  String get safetySettings_rule_omittedSafetyStop =>
      'Ausgelassene Sicherheitsstopps';

  @override
  String get safetySettings_rule_sawtoothProfile => 'Sägezahnprofile';

  @override
  String get safetySettings_rule_highSurfaceGf =>
      'Hoher Gradientenfaktor beim Auftauchen';

  @override
  String get safetySettings_analyzeAll => 'Alle Tauchgänge analysieren';

  @override
  String get safetySettings_analyzeAll_subtitle =>
      'Sicherheitsüberprüfung für alle noch nicht analysierten Tauchgänge mit Profil ausführen';

  @override
  String safetySettings_analyzeAll_progress(int done, int total) {
    return '$done von $total analysiert';
  }

  @override
  String get safetySettings_analyzeAll_done => 'Analyse abgeschlossen';

  @override
  String safetySettings_analyzeAll_doneWithErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge konnten nicht analysiert werden',
      one: '1 Tauchgang konnte nicht analysiert werden',
    );
    return 'Analyse abgeschlossen — $_temp0';
  }

  @override
  String safetyReview_showDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ausgeblendete anzeigen',
      one: '1 Ausgeblendete anzeigen',
    );
    return '$_temp0';
  }

  @override
  String get diveDetailSection_sacSegments_name => 'AMV nach Segment';

  @override
  String get diveDetailSection_sacSegments_description =>
      'AMV-Segmentierung nach Phase/Zeit';

  @override
  String get diveDetailSection_details_name => 'Details';

  @override
  String get diveDetailSection_details_description =>
      'Typ, Ort, Tauchreise, Tauchcenter, Intervall';

  @override
  String get diveDetailSection_environment_name => 'Umgebung';

  @override
  String get diveDetailSection_environment_description =>
      'Luft-/Wassertemperatur, Sichtweite, Strömung';

  @override
  String get diveDetailSection_altitude_name => 'Höhe';

  @override
  String get diveDetailSection_altitude_description =>
      'Höhenangabe, Kategorie, Deko-Anforderung';

  @override
  String get diveDetailSection_tide_name => 'Gezeiten';

  @override
  String get diveDetailSection_tide_description =>
      'Gezeitenzyklusdiagramm und Zeiten';

  @override
  String get diveDetailSection_reefHealth_name => 'Wasserbedingungen';

  @override
  String get diveDetailSection_reefHealth_description =>
      'Satellitengestützte Wasserbedingungen am Tauchdatum';

  @override
  String get diveDetailSection_surfaceGps_name => 'Oberflächen-GPS';

  @override
  String get diveDetailSection_surfaceGps_description =>
      'GPS-Ein-/Ausstiegspunkte und Oberflächendrift';

  @override
  String get diveLog_detail_section_surfaceGps => 'Oberflächen-GPS';

  @override
  String get diveLog_detail_surfaceGps_entry => 'Einstieg';

  @override
  String get diveLog_detail_surfaceGps_exit => 'Ausstieg';

  @override
  String get diveLog_detail_label_drift => 'Drift';

  @override
  String get diveLog_detail_surfaceGps_entryOnly => 'Einstiegspunkt erfasst';

  @override
  String get diveLog_detail_surfaceGps_exitOnly => 'Ausstiegspunkt erfasst';

  @override
  String get diveLog_detail_surfaceGps_site => 'Tauchplatz';

  @override
  String get diveLog_detail_surfaceGps_track => 'Oberflächentrack';

  @override
  String get diveLog_detail_surfaceGps_showFullTrack => 'Ganzer Track';

  @override
  String diveLog_detail_surfaceGps_trackFixes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Punkte',
      one: '1 Punkt',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_detail_locationsMap_title => 'Tauchorte';

  @override
  String get diveLog_detail_coordinatesCopied =>
      'Koordinaten in die Zwischenablage kopiert';

  @override
  String get diveLog_detail_openInMaps => 'In Karten öffnen';

  @override
  String get diveDetailSection_weights_name => 'Gewichte';

  @override
  String get diveDetailSection_weights_description =>
      'Gewichtsaufteilung, Gesamtgewicht';

  @override
  String get diveDetailSection_buoyancy_name => 'Auftrieb';

  @override
  String get diveDetailSection_buoyancy_description =>
      'Auftrieb im Tauchgangverlauf, Schwankung, abwerfbares Blei';

  @override
  String get buoyancy_tooltip =>
      'Modellierter Nettoauftrieb im Tauchgangverlauf aus Profil, Gasverbrauch und Ausrüstung.';

  @override
  String buoyancy_verdictBuoyant(String depth, String amount) {
    return 'Am letzten Stopp (~$depth) hattest du etwa $amount Auftrieb';
  }

  @override
  String buoyancy_verdictHeavy(String depth, String amount) {
    return 'Am letzten Stopp (~$depth) warst du etwa $amount zu schwer';
  }

  @override
  String get buoyancy_verdictNeutral =>
      'Am letzten Stopp war deine Konfiguration nahezu neutral';

  @override
  String get buoyancy_verdictConvention =>
      'Geschätzt an der 5-m-Sicherheitsstopp-Konvention';

  @override
  String get buoyancy_breakdownTitle => 'Term-Aufschlüsselung';

  @override
  String get buoyancy_suitTerm => 'Anzug';

  @override
  String get buoyancy_leadTerm => 'Blei';

  @override
  String get buoyancy_beginNet => 'Tauchgangbeginn';

  @override
  String get buoyancy_endNet => 'Tauchgangende';

  @override
  String get buoyancy_swing => 'Auftriebsschwankung';

  @override
  String get buoyancy_peakLift => 'Max. benötigter Auftrieb';

  @override
  String get buoyancy_wingWarning =>
      'Übersteigt die Nennauftriebskraft deines Wings';

  @override
  String get buoyancy_minDitchable => 'Min. abwerfbares Blei';

  @override
  String get buoyancy_droppable => 'Abwerfbar';

  @override
  String get buoyancy_ditchWarning => 'Mehr als du abwerfen kannst';

  @override
  String get buoyancy_drysuitGas => 'Trocki-Gas zugegeben';

  @override
  String get buoyancy_estimatedPressures => 'Flaschendrücke sind geschätzt';

  @override
  String get buoyancy_linkSuitHint =>
      'Verknüpfe einen Tauchanzug mit diesem Tauchgang für ein vollständigeres Bild';

  @override
  String get buoyancy_noLeadHint =>
      'Kein Blei erfasst: Füge diesem Tauchgang Blei hinzu oder trage bei deiner Bleiausrüstung ein Trockengewicht ein';

  @override
  String get buoyancy_chartNet => 'Netto';

  @override
  String get buoyancy_chartRig => 'Rig + Blei';

  @override
  String get buoyancy_chartMinutes => 'Zeit (min)';

  @override
  String get buoyancy_historyTitle => 'Bleiverlauf';

  @override
  String get buoyancy_historyCarried => 'Getragen';

  @override
  String get buoyancy_historyModeled => 'Modelliert';

  @override
  String buoyancy_historyMore(String delta) {
    return 'Du trägst typischerweise $delta mehr als vom Modell vorgeschlagen';
  }

  @override
  String buoyancy_historyLess(String delta) {
    return 'Du trägst typischerweise $delta weniger als vom Modell vorgeschlagen';
  }

  @override
  String get buoyancy_throughDive => 'Im Tauchgangverlauf';

  @override
  String get buoyancy_adjust => 'Anpassen';

  @override
  String get buoyancy_whatIfTitle => 'Diesen Tauchgang anpassen';

  @override
  String get buoyancy_whatIfLead => 'Blei';

  @override
  String get buoyancy_whatIfSuit => 'Anzugsauftrieb';

  @override
  String get buoyancy_whatIfReset => 'Zurücksetzen';

  @override
  String buoyancy_whatIfDelta(String delta) {
    return '$delta ggü. tatsächlich';
  }

  @override
  String get diveDetailSection_tanks_name => 'Flaschen';

  @override
  String get diveDetailSection_tanks_description =>
      'Flaschenliste, Gasmischungen, Drucke, Flaschen-AMV';

  @override
  String get diveDetailSection_buddies_name => 'Buddies';

  @override
  String get diveDetailSection_buddies_description => 'Buddy-Liste mit Rollen';

  @override
  String get diveDetailSection_signatures_name => 'Signaturen';

  @override
  String get diveDetailSection_signatures_description =>
      'Buddy-/Lehrersignatur anzeigen und erfassen';

  @override
  String get diveDetailSection_equipment_name => 'Ausrüstung';

  @override
  String get diveDetailSection_equipment_description =>
      'Beim Tauchgang verwendete Ausrüstung';

  @override
  String get diveDetailSection_sightings_name => 'Meereslebewesen-Sichtungen';

  @override
  String get diveDetailSection_sightings_description =>
      'Gesichtete Arten, Sichtungsdetails';

  @override
  String get diveDetailSection_media_name => 'Medien';

  @override
  String get diveDetailSection_media_description => 'Foto- und Videogalerie';

  @override
  String get diveDetailSection_tags_name => 'Tags';

  @override
  String get diveDetailSection_tags_description => 'Tauchgang-Tags';

  @override
  String get diveDetailSection_notes_name => 'Notizen';

  @override
  String get diveDetailSection_notes_description =>
      'Tauchnotizen und -beschreibung';

  @override
  String get diveDetailSection_customFields_name => 'Benutzerdefinierte Felder';

  @override
  String get diveDetailSection_customFields_description =>
      'Benutzerdefinierte Felder';

  @override
  String get diveDetailSection_dataSources_name => 'Datenquellen';

  @override
  String get diveDetailSection_dataSources_description =>
      'Verbundene Tauchcomputer, Quellenverwaltung';

  @override
  String get settings_appearance_header_language => 'Sprache';

  @override
  String get settings_appearance_header_theme => 'Design';

  @override
  String get settings_appearance_header_mode => 'Modus';

  @override
  String get settings_themes_title => 'Theme auswählen';

  @override
  String get settings_themes_current => 'Theme';

  @override
  String get theme_submersion => 'Submersion';

  @override
  String get theme_console => 'Konsole';

  @override
  String get theme_tropical => 'Tropisch';

  @override
  String get theme_minimalist => 'Minimalistisch';

  @override
  String get theme_deep => 'Tiefsee';

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
  String get settings_appearance_metric_estimatedTankPressure =>
      'Geschätzter Flaschendruck';

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
  String get settings_appearance_metric_sacRate => 'AMV';

  @override
  String get settings_appearance_metric_surfaceGf => 'Oberflächenfaktor GF';

  @override
  String get settings_appearance_metric_temperature => 'Temperatur';

  @override
  String get settings_appearance_metric_tts => 'TTS (Zeit zur Oberfläche)';

  @override
  String get settings_appearance_metric_cns => 'CNS% (O2-Toxizität)';

  @override
  String get settings_appearance_metric_otu => 'OTU (O2-Toleranzeinheiten)';

  @override
  String get settings_appearance_metric_photoMarkers => 'Fotomarkierungen';

  @override
  String settings_appearance_metricsEnabledCount(int count, int total) {
    return '$count von $total aktiviert';
  }

  @override
  String get settings_appearance_pressureThresholdMarkers =>
      'Druckschwellen-Markierungen';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Markierungen anzeigen, wenn der Flaschendruck Schwellenwerte überschreitet';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Markierungen anzeigen, wenn der Flaschendruck die Schwellenwerte 2/3, 1/2 und 1/3 überschreitet';

  @override
  String get settings_appearance_metricsFollowViewport =>
      'Einblendungen beim Zoomen im Sichtbereich halten';

  @override
  String get settings_appearance_metricsFollowViewport_subtitle =>
      'Einblendungen wie NDL und ppO2 an den sichtbaren Bereich anpassen, statt sie mit der Tiefenachse zu vergrößern';

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
  String get settings_appearance_subsection_standardMetrics =>
      'Standard Metrics';

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
  String get settings_backToSettings_tooltip => 'Zurück zu Einstellungen';

  @override
  String get settings_cloudSync_appBar_title =>
      'Datenbank-Cloud-Synchronisierung';

  @override
  String get settings_cloudSync_autoSync => 'Automatische Synchronisierung';

  @override
  String get settings_cloudSync_autoSync_subtitle =>
      'Nach Änderungen automatisch synchronisieren';

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
      'Die App-verwaltete Cloud-Synchronisierung ist deaktiviert, da Sie einen benutzerdefinierten Speicherordner verwenden. Der Synchronisierungsdienst Ihres Ordners (Dropbox, Google Drive, OneDrive usw.) übernimmt die Synchronisierung.';

  @override
  String get settings_cloudSync_disabledBanner_title =>
      'Cloud-Synchronisierung deaktiviert';

  @override
  String get settings_cloudSync_entry_subtitle =>
      'Synchronisierung über Cloud-Speicher';

  @override
  String get settings_cloudSync_adopt_confirm =>
      'Wiederhergestellte Bibliothek übernehmen';

  @override
  String settings_cloudSync_adopt_dialogContent(
    String deviceName,
    String date,
  ) {
    return 'Die Bibliothek wurde am $date aus einem Backup auf \"$deviceName\" ersetzt. Beim Übernehmen werden die Daten dieses Geräts durch die wiederhergestellte Bibliothek ersetzt. Zuerst wird eine Sicherheitskopie der aktuellen Daten dieses Geräts erstellt.';
  }

  @override
  String get settings_cloudSync_adopt_dialogTitle =>
      'Wiederhergestellte Bibliothek übernehmen?';

  @override
  String get settings_cloudSync_adopt_notNow => 'Nicht jetzt';

  @override
  String get settings_cloudSync_dangerZone => 'Gefahrenbereich';

  @override
  String get settings_cloudSync_replaceLibrary_tile =>
      'Cloud-Bibliothek ersetzen';

  @override
  String get settings_cloudSync_replaceLibrary_tileSubtitle =>
      'Die Bibliothek dieses Geräts für alle Geräte verbindlich machen';

  @override
  String get settings_cloudSync_replaceLibrary_dialogTitle =>
      'Cloud-Bibliothek ersetzen?';

  @override
  String get settings_cloudSync_replaceLibrary_dialogIntro =>
      'Die Bibliothek dieses Geräts wird zu der, die alle Geräte verwenden.';

  @override
  String settings_cloudSync_replaceLibrary_dialogBody(num diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other:
          'Die Cloud-Bibliothek wird gelöscht und durch die $diveCount Tauchgänge dieses Geräts ersetzt.',
      one:
          'Die Cloud-Bibliothek wird gelöscht und durch den 1 Tauchgang dieses Geräts ersetzt.',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_replaceLibrary_peers(num peerCount) {
    String _temp0 = intl.Intl.pluralLogic(
      peerCount,
      locale: localeName,
      other:
          '$peerCount andere Geräte werden zur Übernahme aufgefordert; bis dahin werden ihre Änderungen nicht zusammengeführt.',
      one:
          '1 anderes Gerät wird zur Übernahme aufgefordert; bis dahin werden seine Änderungen nicht zusammengeführt.',
      zero:
          'Es synchronisiert noch kein anderes Gerät, es gibt also nichts zu übernehmen.',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_replaceLibrary_peersUnknown =>
      'Alle anderen Geräte werden zur Übernahme aufgefordert; bis dahin werden ihre Änderungen nicht zusammengeführt.';

  @override
  String get settings_cloudSync_replaceLibrary_backupNote =>
      'Zuvor wird ein Backup dieses Geräts erstellt. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get settings_cloudSync_replaceLibrary_confirmWord => 'Ersetzen';

  @override
  String get settings_cloudSync_replaceLibrary_confirmHint =>
      'Zum Bestätigen \"Ersetzen\" eingeben';

  @override
  String get settings_cloudSync_replaceLibrary_confirm => 'Ersetzen';

  @override
  String get settings_cloudSync_firstSync_banner =>
      'Die erste Synchronisierung wartet auf Bestätigung. Tippen Sie auf \'Jetzt synchronisieren\', um zu prüfen, was zusammengeführt wird.';

  @override
  String get settings_cloudSync_firstSync_dialogConfirm =>
      'Zusammenführen und synchronisieren';

  @override
  String get settings_cloudSync_firstSync_replaceHint =>
      'Wenn stattdessen die Bibliothek dieses Geräts das ersetzen soll, was in der Cloud liegt, brechen Sie ab und verwenden Sie Einstellungen > Cloud-Synchronisierung > Cloud-Bibliothek ersetzen.';

  @override
  String settings_cloudSync_firstSync_dialogContent(
    int deviceCount,
    int diveCount,
  ) {
    return 'In der Cloud wurden vorhandene Synchronisierungsdaten gefunden ($deviceCount Synchronisierungsdatei(en)). Bei der ersten Synchronisierung werden diese Daten mit den $diveCount Tauchgängen auf diesem Gerät zusammengeführt, und zwar auf allen synchronisierten Geräten.\n\nWenn dieselben Tauchgänge auf jedem Gerät separat hinzugefügt wurden, erscheinen sie doppelt.';
  }

  @override
  String get settings_cloudSync_firstSync_dialogTitle =>
      'Bibliotheken zusammenführen?';

  @override
  String settings_cloudSync_replace_banner(String deviceName) {
    return 'Synchronisierung pausiert: Die Bibliothek wurde aus einem Backup auf \"$deviceName\" ersetzt. Tippen Sie auf \"Jetzt synchronisieren\", um sie zu überprüfen.';
  }

  @override
  String get settings_cloudSync_switch_dialogTitle =>
      'Synchronisierungs-Backend wechseln?';

  @override
  String settings_cloudSync_switch_dialogContent(
    String fromName,
    String toName,
  ) {
    return 'Ihre Daten werden nicht von $fromName entfernt – sie bleiben dort, bis Sie sie löschen. Nach dem Wechsel kombiniert die nächste Synchronisierung dieses Geräts seine Daten mit allem, was bereits auf $toName vorhanden ist. Ihre anderen Geräte verwenden weiterhin $fromName, bis Sie auch jedes von ihnen umstellen.';
  }

  @override
  String get settings_cloudSync_switch_confirm => 'Wechseln';

  @override
  String settings_cloudSync_moved_banner(
    String deviceName,
    String destination,
  ) {
    return '$deviceName hat diese Bibliothek nach $destination verschoben. Dieses Backend wird von ihm nicht mehr aktualisiert. Wählen Sie unten $destination, um dem Wechsel zu folgen.';
  }

  @override
  String get settings_cloudSync_moved_dismiss => 'Schließen';

  @override
  String settings_cloudSync_cleanup_banner(String backend) {
    return 'Auf $backend sind noch alte Synchronisierungsdaten aus der Zeit vor dem Backend-Wechsel gespeichert. Sie werden nicht mehr verwendet.';
  }

  @override
  String get settings_cloudSync_cleanup_delete => 'Alte Daten löschen';

  @override
  String get settings_cloudSync_cleanup_keep => 'Behalten';

  @override
  String get settings_cloudSync_header_advanced => 'Erweitert';

  @override
  String get settings_cloudSync_signOut_backupWarning =>
      'Cloud-Backup wird deaktiviert und Sicherungen werden am Standardspeicherort gespeichert.';

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
      other: '$count ausstehende Änderungen',
      one: '1 ausstehende Änderung',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_banner(Object deviceList) {
    return '$deviceList hat noch eine ältere oder unbekannte Bibliotheksversion, daher wurden die Änderungen nicht zusammengeführt. Öffnen Sie Submersion dort, um die aktuelle Bibliothek zu übernehmen.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_bannerPlural(Object deviceList) {
    return '$deviceList haben noch eine ältere oder unbekannte Bibliotheksversion, daher wurden ihre Änderungen nicht zusammengeführt. Öffnen Sie Submersion dort, um die aktuelle Bibliothek zu übernehmen.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_unnamedDevice(Object shortId) {
    return 'Gerät $shortId';
  }

  @override
  String get settings_cloudSync_peerNeedsAdopt_listSeparator => ', ';

  @override
  String get settings_cloudSync_peerNeedsAdopt_listLastSeparator => ' und ';

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamed(Object deviceList) {
    return '$deviceList synchronisiert von einer neueren Version von Submersion, daher werden die neuesten Änderungen vorerst zurückgehalten.';
  }

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(
    Object deviceList,
  ) {
    return '$deviceList synchronisieren von einer neueren Version von Submersion, daher werden ihre neuesten Änderungen vorerst zurückgehalten.';
  }

  @override
  String get settings_cloudSync_peerRequiresUpdate_updateAction =>
      'Aktualisieren Sie dieses Gerät, um sie zu erhalten.';

  @override
  String get settings_cloudSync_peerRequiresUpdate_storeAction =>
      'Sie werden automatisch übernommen, sobald das App-Store-Update für dieses Gerät verfügbar ist; das Update befindet sich möglicherweise noch in der Prüfung.';

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
  String get settings_cloudSync_dropbox_account_title => 'Dropbox-Konto';

  @override
  String get settings_cloudSync_dropbox_connect_browserFailed =>
      'Der Browser konnte nicht geöffnet werden. Versuchen Sie die Schaltfläche „Browser erneut öffnen“.';

  @override
  String get settings_cloudSync_dropbox_connect_codeLabel =>
      'Autorisierungscode';

  @override
  String get settings_cloudSync_dropbox_connect_emptyCode =>
      'Geben Sie den in Ihrem Browser angezeigten Autorisierungscode ein';

  @override
  String settings_cloudSync_dropbox_connect_failed(Object error) {
    return 'Verbindung zu Dropbox fehlgeschlagen: $error';
  }

  @override
  String get settings_cloudSync_dropbox_connect_instructions =>
      'Ihr Browser hat eine Dropbox-Autorisierungsseite geöffnet. Erteilen Sie den Zugriff und fügen Sie dann den von Dropbox angezeigten Code hier ein.';

  @override
  String get settings_cloudSync_dropbox_connect_reopenBrowser =>
      'Browser erneut öffnen';

  @override
  String get settings_cloudSync_dropbox_connect_submit => 'Verbinden';

  @override
  String get settings_cloudSync_dropbox_connect_title => 'Dropbox verbinden';

  @override
  String get settings_cloudSync_dropbox_connected => 'Mit Dropbox verbunden';

  @override
  String settings_cloudSync_dropbox_connectedAs(Object account) {
    return 'Verbunden als $account';
  }

  @override
  String get settings_cloudSync_dropbox_disconnect => 'Trennen';

  @override
  String get settings_cloudSync_provider_dropbox_subtitle =>
      'Synchronisierung über Dropbox (Apps/Submersion)';

  @override
  String get settings_cloudSync_provider_dropbox_title => 'Dropbox';

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Über Google Drive synchronisieren';

  @override
  String get settings_cloudSync_googleDrive_desktopNotConfigured =>
      'In diesem Build nicht verfügbar';

  @override
  String get settings_cloudSync_googleDrive_browserWait_title =>
      'Weiter im Browser';

  @override
  String get settings_cloudSync_googleDrive_browserWait_message =>
      'Schließen Sie die Google-Anmeldung in Ihrem Webbrowser ab und kehren Sie dann zu Submersion zurück.';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return '$providerName-Anbieter konnte nicht initialisiert werden';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Auf dieser Plattform nicht verfügbar';

  @override
  String get settings_cloudSync_provider_s3_edit =>
      'S3-Konfiguration bearbeiten';

  @override
  String get settings_cloudSync_provider_s3_subtitle =>
      'Funktioniert mit jedem S3-kompatiblen Speicherdienst';

  @override
  String get settings_cloudSync_provider_s3_title => 'S3-kompatibler Speicher';

  @override
  String get settings_cloudSync_resetDialog_cancel => 'Abbrechen';

  @override
  String get settings_cloudSync_resetDialog_content =>
      'Dadurch wird der gesamte Synchronisierungsverlauf gelöscht und neu begonnen. Ihre Daten werden nicht gelöscht, aber möglicherweise müssen Sie bei der nächsten Synchronisierung Konflikte lösen.';

  @override
  String get settings_cloudSync_resetDialog_reset => 'Zurücksetzen';

  @override
  String get settings_cloudSync_resetDialog_title =>
      'Synchronisierungsstatus zurücksetzen?';

  @override
  String get settings_cloudSync_resetSuccess =>
      'Synchronisierungsstatus zurückgesetzt';

  @override
  String get settings_cloudSync_resetSyncState =>
      'Synchronisierungsstatus zurücksetzen';

  @override
  String get settings_cloudSync_resetSyncState_subtitle =>
      'Synchronisierungsverlauf löschen und neu beginnen';

  @override
  String get settings_cloudSync_resolveConflicts => 'Konflikte lösen';

  @override
  String get settings_cloudSync_selectProviderHint =>
      'Wählen Sie einen Cloud-Anbieter, um die Synchronisierung zu aktivieren';

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
  String get settings_conflict_chooseResolution => 'Lösung wählen';

  @override
  String get settings_conflict_close => 'Schließen';

  @override
  String get settings_conflict_close_tooltip => 'Konfliktdialog schließen';

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
    return 'Geändert: $time';
  }

  @override
  String get settings_conflict_next_tooltip => 'Nächster Konflikt';

  @override
  String get settings_conflict_noConflicts_message =>
      'Alle Synchronisierungskonflikte wurden gelöst.';

  @override
  String get settings_conflict_noConflicts_title => 'Keine Konflikte';

  @override
  String get settings_conflict_noDataAvailable => 'Keine Daten verfügbar';

  @override
  String get settings_conflict_previous_tooltip => 'Vorheriger Konflikt';

  @override
  String get settings_conflict_ref_buddy => 'Tauchpartner';

  @override
  String get settings_conflict_ref_certification => 'Zertifizierung';

  @override
  String get settings_conflict_ref_checklistTemplate => 'Checklisten-Vorlage';

  @override
  String get settings_conflict_ref_connectedAccount => 'Verbundenes Konto';

  @override
  String get settings_conflict_ref_course => 'Kurs';

  @override
  String get settings_conflict_ref_courseRequirement => 'Kursanforderung';

  @override
  String get settings_conflict_ref_cylinderConfig => 'Flaschenkonfiguration';

  @override
  String get settings_conflict_ref_dataSource => 'Datenquelle';

  @override
  String get settings_conflict_ref_dive => 'Tauchgang';

  @override
  String get settings_conflict_ref_diveCenter => 'Tauchbasis';

  @override
  String get settings_conflict_ref_diveComputer => 'Tauchcomputer';

  @override
  String get settings_conflict_ref_divePlan => 'Tauchplan';

  @override
  String get settings_conflict_ref_diveSite => 'Tauchplatz';

  @override
  String get settings_conflict_ref_diveType => 'Tauchgangart';

  @override
  String get settings_conflict_ref_diver => 'Taucher';

  @override
  String get settings_conflict_ref_equipment => 'Ausrüstung';

  @override
  String get settings_conflict_ref_equipmentSet => 'Ausrüstungsset';

  @override
  String get settings_conflict_ref_finding => 'Befund';

  @override
  String get settings_conflict_ref_instructor => 'Instructor';

  @override
  String get settings_conflict_ref_linkedDive => 'Verknüpfter Tauchgang';

  @override
  String get settings_conflict_ref_media => 'Medien';

  @override
  String get settings_conflict_ref_mediaSubscription => 'Medien-Abonnement';

  @override
  String get settings_conflict_ref_missing => 'Nicht mehr in dieser Bibliothek';

  @override
  String settings_conflict_ref_named(Object name, Object date) {
    return '$name ($date)';
  }

  @override
  String get settings_conflict_ref_plannedTank => 'Geplante Flasche';

  @override
  String get settings_conflict_ref_preDiveChecklistTemplate =>
      'Vorlage für Checkliste vor dem Tauchgang';

  @override
  String get settings_conflict_ref_preDiveSession =>
      'Checkliste vor dem Tauchgang';

  @override
  String get settings_conflict_ref_relatedDive => 'Zugehöriger Tauchgang';

  @override
  String get settings_conflict_ref_serviceKind => 'Wartungsart';

  @override
  String get settings_conflict_ref_sighting => 'Sichtung';

  @override
  String get settings_conflict_ref_signer => 'Unterschrieben von';

  @override
  String get settings_conflict_ref_sourceDive => 'Quell-Tauchgang';

  @override
  String get settings_conflict_ref_species => 'Art';

  @override
  String get settings_conflict_ref_tag => 'Tag';

  @override
  String get settings_conflict_ref_tank => 'Flasche';

  @override
  String get settings_conflict_ref_trip => 'Reise';

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
    return '$_temp0 gelöst';
  }

  @override
  String get settings_conflict_title => 'Konflikte lösen';

  @override
  String get settings_data_appDefaultLocation => 'Standard-App-Speicherort';

  @override
  String get settings_data_backup => 'Sicherung und Wiederherstellung';

  @override
  String get settings_data_backup_subtitle => 'Sicherung Ihrer Daten erstellen';

  @override
  String get settings_data_cloudSync => 'Datenbank-Cloud-Synchronisierung';

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
      'Karten für die Offline-Nutzung herunterladen';

  @override
  String get settings_data_restore => 'Wiederherstellen';

  @override
  String get settings_data_restoreDialog_cancel => 'Abbrechen';

  @override
  String get settings_data_restoreDialog_content =>
      'Warnung: Das Wiederherstellen aus einer Sicherung ersetzt ALLE aktuellen Daten durch die Sicherungsdaten. Diese Aktion kann nicht rückgängig gemacht werden.\n\nSind Sie sicher, dass Sie fortfahren möchten?';

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
      'Gradientenfaktoren (GF) steuern, wie konservativ Ihre Dekompressionsberechnungen sind. GF Low beeinflusst tiefe Stopps, während GF High flache Stopps beeinflusst.\n\nNiedrigere Werte = konservativer = längere Dekostopps\nHöhere Werte = weniger konservativ = kürzere Dekostopps';

  @override
  String get settings_decompression_aboutTitle => 'Über Gradientenfaktoren';

  @override
  String get settings_decompression_currentSettings => 'Aktuelle Einstellungen';

  @override
  String get settings_decompression_dialog_cancel => 'Abbrechen';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      'Niedrigere Werte = konservativer (längere NDL/mehr Deko)';

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
  String get settings_decompression_header_oxygenToxicity =>
      'Sauerstofftoxizität';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Voreinstellung $presetName für Konservativität auswählen';
  }

  @override
  String get settings_decompression_header_narcosis => 'Narkose';

  @override
  String get settings_decompression_o2Narcotic => 'O2 ist narkotisch';

  @override
  String get settings_decompression_o2Narcotic_subtitle =>
      'Wenn aktiviert, werden sowohl O2 als auch N2 als narkotisch betrachtet (konservativer). Wenn deaktiviert, trägt nur N2 zur Narkose bei.';

  @override
  String get settings_decompression_endLimit => 'END-Grenze';

  @override
  String get settings_decompression_endLimit_subtitle =>
      'Maximale äquivalente narkotische Tiefe für MND-Berechnungen';

  @override
  String get settings_decompression_endLimit_dialog_title => 'END-Grenze';

  @override
  String get settings_decompression_cnsMethodTitle => 'CNS-Berechnung';

  @override
  String get settings_decompression_cnsMethodClassic =>
      'NOAA-Tabelle, gestuft (klassisch)';

  @override
  String get settings_decompression_cnsMethodClassicDesc =>
      'Berechnet jedes 0,1-bar-Band mit dem strengeren Rand. Submersions ursprüngliche Methode.';

  @override
  String get settings_decompression_cnsMethodShearwater =>
      'Lineare Interpolation (Shearwater-Stil)';

  @override
  String get settings_decompression_cnsMethodShearwaterDesc =>
      'Interpoliert zwischen den NOAA-Grenzwerten, wie von Shearwater dokumentiert. Entspricht den meisten Tauchcomputern.';

  @override
  String get settings_decompression_cnsMethodSubsurface =>
      'Exponentieller Fit (wie Subsurface)';

  @override
  String get settings_decompression_cnsMethodSubsurfaceDesc =>
      'Glatte Kurvenanpassung an die NOAA-Tabelle. Entspricht dem von Subsurface berechneten CNS.';

  @override
  String get settings_decompression_cnsMethodAboutTitle =>
      'Über diese Methoden';

  @override
  String get settings_decompression_cnsMethodAboutBody =>
      'Alle drei Methoden basieren auf den Sauerstoff-Expositionsgrenzwerten des NOAA Diving Manual (300 Minuten bei einem ppO2 von 1,0 bar, 45 Minuten bei 1,6 bar). Die Tabelle definiert Grenzwerte nur in Schritten von 0,1 bar: Die klassische Methode berechnet alles innerhalb eines Bandes mit dem strengeren Rand des Bandes, was die Exposition zwischen den Einträgen systematisch überschätzt. Die Tauchcomputer von Shearwater dokumentieren eine lineare Interpolation zwischen den NOAA-Grenzwerten, mit festen 15 % pro Minute oberhalb von 1,65 bar. Subsurface ersetzte 2019 seine Tabellensuche durch einen glatten, zweiteiligen exponentiellen Fit an dieselben NOAA-Daten (Robert C. Helling), der sich auch über 1,6 bar hinaus natürlich fortsetzt. Zwischen den Tabelleneinträgen stimmen die beiden glatten Methoden bis auf etwa einen CNS-Punkt überein; die klassische Methode zeigt höhere Werte an.';

  @override
  String get settings_decompression_cnsMethodDisclaimer =>
      'Die Namen beziehen sich auf die veröffentlichten Methoden der jeweiligen Projekte und Hersteller; eine Verbindung oder Befürwortung ist damit nicht impliziert. Berechnete Werte können von den tatsächlichen Anzeigen des Tauchcomputers abweichen.';

  @override
  String get settings_decompression_cnsMethodSourcesTitle => 'Quellen';

  @override
  String get settings_linkOpenFailed =>
      'Der Link konnte nicht geöffnet werden.';

  @override
  String get settings_decompression_cnsMethodSourceNoaa =>
      'NOAA: Diving Program (Herausgeber des NOAA Diving Manual)';

  @override
  String get settings_decompression_cnsMethodSourceShearwater =>
      'Shearwater: Die CNS-Sauerstoffuhr';

  @override
  String get settings_decompression_cnsMethodSourceTheoreticalDiver =>
      'The Theoretical Diver: Berechnung der CNS-Sauerstofftoxizität';

  @override
  String get settings_decompression_cnsMethodSourceSubsurface =>
      'Subsurface: Implementierung (divelist.cpp)';

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
      'Mit Ihrer aktuellen Datenbank überschreiben';

  @override
  String get settings_existingDb_stat_buddies => 'Tauchpartner';

  @override
  String get settings_existingDb_stat_dives => 'Tauchgänge';

  @override
  String get settings_existingDb_stat_sites => 'Tauchplätze';

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
      'Am konservativsten, längere Dekostopps';

  @override
  String get settings_gfPreset_high_name => 'Hoch';

  @override
  String get settings_gfPreset_low_description =>
      'Am wenigsten konservativ, kürzere Deko';

  @override
  String get settings_gfPreset_low_name => 'Niedrig';

  @override
  String get settings_gfPreset_medium_description => 'Ausgewogener Ansatz';

  @override
  String get settings_gfPreset_medium_name => 'Mittel';

  @override
  String get settings_import_cancelButton => 'Import abbrechen';

  @override
  String get settings_import_cancelling => 'Wird abgebrochen...';

  @override
  String get settings_import_dialog_title => 'Daten werden importiert';

  @override
  String get settings_import_doNotClose => 'Bitte schließen Sie die App nicht';

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
  String get settings_import_phase_dives => 'Tauchgänge werden importiert...';

  @override
  String get settings_import_phase_equipment => 'Ausrüstung wird importiert...';

  @override
  String get settings_import_phase_equipmentSets =>
      'Ausrüstungssets werden importiert...';

  @override
  String get settings_import_phase_parsing => 'Datei wird analysiert...';

  @override
  String get settings_import_phase_preparing => 'Wird vorbereitet...';

  @override
  String get settings_import_phase_sites => 'Tauchplätze werden importiert...';

  @override
  String get settings_import_phase_tags => 'Tags werden importiert...';

  @override
  String get settings_import_phase_trips => 'Reisen werden importiert...';

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
    return '$phase, $current von $total';
  }

  @override
  String settings_import_progressPercent(Object percent) {
    return 'Importfortschritt: $percent Prozent';
  }

  @override
  String get settings_language_appBar_title => 'Sprache';

  @override
  String get settings_language_selected => 'Ausgewählt';

  @override
  String get settings_language_systemDefault => 'Systemstandard';

  @override
  String get settings_lightroom_albumFilter_all => 'Gesamter Katalog';

  @override
  String get settings_lightroom_albumFilter_title => 'Zu durchsuchende Alben';

  @override
  String get settings_lightroom_autoPoll_title =>
      'Automatisch nach neuen Fotos suchen';

  @override
  String settings_lightroom_clientId_help(String redirectUri) {
    return 'Erstelle in der Adobe Developer Console eine Integration mit der Lightroom Services API und einem Anmeldetyp, der PKCE unterstützt. Gib unten die Redirect-URI deiner Anmeldedaten ein — Native-App-Anmeldedaten verwenden ein benutzerdefiniertes Schema — oder lass das Feld leer, um $redirectUri zu verwenden.';
  }

  @override
  String get settings_lightroom_clientId_label => 'Adobe Client-ID';

  @override
  String get settings_lightroom_clientSecret_label =>
      'Client-Secret (optional)';

  @override
  String get settings_lightroom_redirectUri_label => 'Redirect-URI (optional)';

  @override
  String get settings_lightroom_connect => 'Lightroom verbinden';

  @override
  String get settings_lightroom_connectEmbedded => 'Mit Adobe verbinden';

  @override
  String get settings_lightroom_advancedByo =>
      'Eigene Adobe-Anmeldedaten verwenden';

  @override
  String get settings_lightroom_connect_codeLabel =>
      'Weitergeleitete URL oder Code';

  @override
  String get settings_lightroom_connect_emptyCode =>
      'Weitergeleitete URL oder Autorisierungscode einfügen';

  @override
  String settings_lightroom_connect_failed(String error) {
    return 'Verbindung zu Lightroom fehlgeschlagen: $error';
  }

  @override
  String get settings_lightroom_connect_instructions =>
      'Melde dich im Browserfenster bei Adobe an und füge dann die vollständige Adresse der Seite ein, auf der du landest (sie enthält den Autorisierungscode).';

  @override
  String get settings_lightroom_connect_reopenBrowser =>
      'Browser erneut öffnen';

  @override
  String get settings_lightroom_connect_submit => 'Verbinden';

  @override
  String get settings_lightroom_connect_title => 'Lightroom verbinden';

  @override
  String settings_lightroom_connected(String name) {
    return 'Verbunden als $name';
  }

  @override
  String get settings_lightroom_disconnect => 'Trennen';

  @override
  String get settings_lightroom_disconnect_confirmBody =>
      'Verknüpfte Fotos bleiben bei deinen Tauchgängen und werden weiterhin aus dem Medienspeicher angezeigt. Neue Fotos werden nicht mehr zugeordnet.';

  @override
  String get settings_lightroom_disconnect_confirmTitle => 'Lightroom trennen?';

  @override
  String settings_lightroom_lastPoll(String when) {
    return 'Zuletzt geprüft: $when';
  }

  @override
  String get settings_lightroom_needsReauth =>
      'Erneute Verbindung erforderlich';

  @override
  String get settings_lightroom_scanNow => 'Lightroom durchsuchen';

  @override
  String get settings_lightroom_scan_running => 'Lightroom wird durchsucht...';

  @override
  String settings_lightroom_scan_summary(
    int attached,
    int suggested,
    int skipped,
  ) {
    return '$attached verknüpft, $suggested vorgeschlagen, $skipped bereits verknüpft';
  }

  @override
  String get settings_lightroom_subtitle =>
      'Fotos und Videos automatisch mit Tauchgängen verknüpfen';

  @override
  String get settings_lightroom_title => 'Adobe Lightroom';

  @override
  String get settings_manage_checklistTemplates => 'Checklistenvorlagen';

  @override
  String get settings_manage_checklistTemplates_subtitle =>
      'Wiederverwendbare Aufgabenlisten für die Reiseplanung';

  @override
  String get settings_manage_diveRoles => 'Tauchrollen';

  @override
  String get settings_manage_diveRoles_subtitle =>
      'Benutzerdefinierte Tauchrollen verwalten';

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
  String get settings_manage_tags => 'Tags';

  @override
  String get settings_manage_tags_subtitle =>
      'Tags verwalten, zusammenführen und löschen';

  @override
  String get settings_manage_tankPresets => 'Flaschenvoreinstellungen';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Benutzerdefinierte Flaschenkonfigurationen verwalten';

  @override
  String get settings_manage_serviceTypes => 'Wartungsarten';

  @override
  String get settings_manage_serviceTypes_subtitle =>
      'Welche Wartung deine Ausrüstung braucht und wie oft';

  @override
  String get settings_migrationProgress_doNotClose =>
      'Bitte schließen Sie die App nicht';

  @override
  String get settings_migration_backupInfo =>
      'Vor dem Verschieben wird eine Sicherung erstellt. Ihre Daten gehen nicht verloren.';

  @override
  String get settings_migration_cancel => 'Abbrechen';

  @override
  String get settings_migration_cloudSyncWarning =>
      'Die App-verwaltete Cloud-Synchronisierung wird deaktiviert. Der Synchronisierungsdienst Ihres Ordners übernimmt die Synchronisierung.';

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
  String get settings_notifications_disabled_continueButton => 'Weiter';

  @override
  String get settings_notifications_disabled_openSettingsButton =>
      'Einstellungen öffnen';

  @override
  String get settings_notifications_disabled_subtitleUnrequested =>
      'Serviceerinnerungen benotigen die Berechtigung fur Mitteilungen';

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
      'Benachrichtigung erhalten, wenn eine Ausrüstungswartung fällig ist';

  @override
  String get settings_notifications_header_reminderSchedule =>
      'Erinnerungszeitplan';

  @override
  String get settings_notifications_header_serviceReminders =>
      'Serviceerinnerungen';

  @override
  String get settings_notifications_howItWorks_content =>
      'Benachrichtigungen werden beim Start der App geplant und regelmäßig im Hintergrund aktualisiert. Sie können Erinnerungen für einzelne Ausrüstungsgegenstände im jeweiligen Bearbeitungsbildschirm anpassen.';

  @override
  String get settings_notifications_howItWorks_title => 'So funktioniert es';

  @override
  String get settings_notifications_permissionRequired =>
      'Bitte aktivieren Sie Benachrichtigungen in den Systemeinstellungen';

  @override
  String get settings_notifications_remindBeforeDue =>
      'Erinnern Sie mich vor Fälligkeit der Wartung:';

  @override
  String get settings_notifications_reminderTime => 'Erinnerungszeit';

  @override
  String get settings_profile_activeDiver_subtitle =>
      'Aktiver Taucher - tippen, um zu wechseln';

  @override
  String get settings_profile_addNewDiver => 'Neuen Taucher hinzufügen';

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
      'Taucherprofile hinzufügen oder bearbeiten';

  @override
  String get settings_profileHub_addNewDiver => 'Neuen Taucher hinzufügen';

  @override
  String get settings_profileHub_cannotDeleteOnly =>
      'Das einzige Taucherprofil kann nicht gelöscht werden';

  @override
  String get settings_profileHub_createDiverTitle => 'Taucher erstellen';

  @override
  String settings_profileHub_deleteConfirmContent(String name) {
    return 'Sind Sie sicher, dass Sie $name löschen möchten? Alle zugehörigen Tauchgänge werden abgetrennt.';
  }

  @override
  String get settings_profileHub_deleteConfirmTitle => 'Taucher löschen?';

  @override
  String get settings_profileHub_deleteDiver => 'Taucher löschen';

  @override
  String get settings_profileHub_deleted => 'Taucher gelöscht';

  @override
  String get settings_profileHub_emergencyContacts => 'Notfallkontakte';

  @override
  String settings_profileHub_emergencyContacts_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kontakte festgelegt',
      one: '1 Kontakt festgelegt',
      zero: 'Nicht festgelegt',
    );
    return '$_temp0';
  }

  @override
  String get settings_profileHub_insurance => 'Versicherung';

  @override
  String get settings_profileHub_insurance_expired => 'Abgelaufen';

  @override
  String get settings_profileHub_insurance_notSet => 'Nicht festgelegt';

  @override
  String get settings_profileHub_medicalInfo => 'Medizinische Informationen';

  @override
  String get settings_profileHub_medicalInfo_notSet => 'Nicht festgelegt';

  @override
  String get settings_profileHub_notes => 'Notizen';

  @override
  String get settings_profileHub_notes_notSet => 'Nicht festgelegt';

  @override
  String get settings_profileHub_personalInfo => 'Persönliche Informationen';

  @override
  String get settings_profileHub_personalInfo_notSet => 'Nicht festgelegt';

  @override
  String get settings_profileHub_saved => 'Änderungen gespeichert';

  @override
  String get settings_profileHub_switchDiver => 'Taucher wechseln';

  @override
  String get settings_s3Config_action_remove => 'Konfiguration entfernen';

  @override
  String get settings_s3Config_action_testConnection => 'Verbindung testen';

  @override
  String get settings_s3Config_advanced_title => 'Erweitert';

  @override
  String get settings_s3Config_appBar_title => 'S3-kompatibler Speicher';

  @override
  String get settings_s3Config_error_secureStorage =>
      'Auf den sicheren Speicher konnte nicht zugegriffen werden';

  @override
  String get settings_s3Config_field_accessKeyId_label => 'Access Key ID';

  @override
  String get settings_s3Config_field_bucket_label => 'Bucket';

  @override
  String get settings_s3Config_field_endpoint_helper =>
      'Zum Beispiel: https://s3.example.com';

  @override
  String get settings_s3Config_field_endpoint_label => 'Endpunkt-URL';

  @override
  String get settings_s3Config_field_pathStyle_label =>
      'Path-Style-Adressierung verwenden';

  @override
  String get settings_s3Config_field_pathStyle_subtitle =>
      'Von den meisten selbst gehosteten Servern benötigt';

  @override
  String get settings_s3Config_field_prefix_label => 'Schlüssel-Präfix';

  @override
  String settings_s3Config_field_region_helperAuto(String region) {
    return 'Automatisch erkannt: $region';
  }

  @override
  String get settings_s3Config_field_region_label => 'Region';

  @override
  String get settings_s3Config_field_secretAccessKey_label =>
      'Secret Access Key';

  @override
  String get settings_s3Config_remove_confirm_action => 'Entfernen';

  @override
  String get settings_s3Config_remove_confirm_body =>
      'Die Synchronisierung über S3 wird auf diesem Gerät beendet. Ihre Daten im Bucket werden nicht gelöscht.';

  @override
  String get settings_s3Config_remove_confirm_title =>
      'S3-Konfiguration entfernen?';

  @override
  String get settings_s3Config_removed => 'S3-Konfiguration entfernt';

  @override
  String get settings_s3Config_saved => 'S3-Konfiguration gespeichert';

  @override
  String settings_s3Config_test_regionDetected(String region) {
    return 'Region erkannt: $region';
  }

  @override
  String get settings_s3Config_test_success => 'Verbindung erfolgreich';

  @override
  String get settings_s3Config_validation_endpointInvalid =>
      'Gültige http://- oder https://-URL eingeben';

  @override
  String get settings_s3Config_validation_endpointPath =>
      'Die Endpunkt-URL darf keinen Pfad enthalten';

  @override
  String get settings_s3Config_validation_required => 'Erforderlich';

  @override
  String get settings_s3Config_warning_http =>
      'Dieser Endpunkt verwendet unverschlüsseltes HTTP. Zugangsdaten und Tauchdaten werden unverschlüsselt übertragen; nur in vertrauenswürdigen Netzwerken verwenden.';

  @override
  String get settings_section_about_subtitle => 'App-Info & Lizenzen';

  @override
  String get settings_section_about_title => 'Über';

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
  String get settings_storage_customFolder_change => 'Ändern';

  @override
  String get settings_storage_customFolder_subtitle =>
      'Wählen Sie einen synchronisierten Ordner (Dropbox, Google Drive usw.)';

  @override
  String get settings_storage_customFolder_subtitleDeviceOnly =>
      'Datenbank in den internen Speicher oder auf die SD-Karte verschieben';

  @override
  String get settings_storage_customFolder_deviceOnly_noCloudSync =>
      'Die app-verwaltete Cloud-Synchronisierung ist deaktiviert, solange die Datenbank auf einem Gerätespeicher liegt. Unter Android kann kein Synchronisierungsdienst diesen Ordner erreichen — nutzen Sie Sicherung und Wiederherstellung, um anderswo Kopien zu behalten.';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize • $diveCount Tauchgänge • $siteCount Tauchplätze';
  }

  @override
  String get settings_storage_dismissError_tooltip => 'Fehler schließen';

  @override
  String get settings_storage_dismissSuccess_tooltip =>
      'Erfolgsmeldung schließen';

  @override
  String get settings_storage_header_storageLocation => 'Speicherort';

  @override
  String get settings_storage_info_customActive =>
      'Die App-verwaltete Cloud-Synchronisierung ist deaktiviert. Der Synchronisierungsdienst Ihres Ordners (Dropbox, Google Drive usw.) übernimmt die Synchronisierung.';

  @override
  String get settings_storage_info_customAvailable =>
      'Die Verwendung eines benutzerdefinierten Ordners deaktiviert die App-verwaltete Cloud-Synchronisierung. Der Synchronisierungsdienst Ihres Ordners übernimmt stattdessen die Synchronisierung.';

  @override
  String get settings_storage_loading => 'Laden...';

  @override
  String get settings_storage_migrating_doNotClose =>
      'Bitte schließen Sie die App nicht';

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
  String get settings_storage_dangerZone => 'Gefahrenzone';

  @override
  String get settings_storage_resetDatabase => 'Datenbank zurücksetzen';

  @override
  String get settings_storage_resetDatabase_subtitle =>
      'Alle Daten auf diesem Gerät löschen und neu beginnen';

  @override
  String get settings_storage_resetDialog_title => 'Datenbank zurücksetzen?';

  @override
  String get settings_storage_resetDialog_body =>
      'Dies löscht dauerhaft alle Daten auf DIESEM Gerät, einschließlich Tauchgänge, Tauchplätze, Ausrüstung und Einstellungen. Vor dem Zurücksetzen wird automatisch eine Sicherung erstellt.\n\nIhre Cloud-Bibliothek wird nicht gelöscht, und andere Geräte behalten ihre Daten. Die Cloud-Synchronisierung wird getrennt, damit das Zurücksetzen nicht rückgängig gemacht wird; Sie können sie unter Einstellungen > Cloud-Synchronisierung wieder verbinden.';

  @override
  String get settings_storage_resetDialog_confirmWord => 'Delete';

  @override
  String get settings_storage_resetDialog_confirmHint =>
      'Geben Sie \"Delete\" zur Bestätigung ein';

  @override
  String get settings_storage_resetDialog_confirmButton => 'Zurücksetzen';

  @override
  String get settings_storage_resetDialog_backupFailed =>
      'Sicherung fehlgeschlagen. Zurücksetzen abgebrochen, um Ihre Daten zu schützen.';

  @override
  String settings_storage_resetDialog_resetFailed(Object error) {
    return 'Zurücksetzen fehlgeschlagen: $error';
  }

  @override
  String get settings_storage_resetComplete_title => 'Datenbank zurückgesetzt';

  @override
  String get settings_storage_resetComplete_description =>
      'Die Daten dieses Geräts wurden gelöscht und eine Sicherung wurde gespeichert. Die Cloud-Synchronisierung ist jetzt getrennt, damit das Zurücksetzen nicht rückgängig gemacht wird; Sie können sie unter Einstellungen > Cloud-Synchronisierung wieder verbinden. Tippen Sie auf Weiter, um die App neu zu laden.';

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
      'Wählen Sie eine Kategorie zum Konfigurieren';

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
      'Tipp: Verwenden Sie den Bereich Daten, um Ihre Tauchprotokolle regelmäßig zu sichern.';

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
  String get settings_units_depth_feet => 'Fuß (ft)';

  @override
  String get settings_units_depth_meters => 'Meter (m)';

  @override
  String get settings_units_dialog_dateFormat => 'Datumsformat';

  @override
  String get settings_units_dialog_depthUnit => 'Tiefeneinheit';

  @override
  String get settings_units_dialog_pressureUnit => 'Druckeinheit';

  @override
  String get settings_units_dialog_sacRateUnit => 'AMV-Einheit';

  @override
  String get settings_units_gasModel => 'Gasberechnungen';

  @override
  String get settings_units_gasModel_real => 'Reales Gas';

  @override
  String get settings_units_gasModel_real_subtitle =>
      'Berücksichtigt die Kompressibilität. Eine 12-l-Flasche mit 200 bar fasst etwa 2317 l.';

  @override
  String get settings_units_gasModel_ideal => 'Ideales Gas';

  @override
  String get settings_units_gasModel_ideal_subtitle =>
      'Entspricht der Handrechnung und den Tauchtabellen. Eine 12-l-Flasche mit 200 bar fasst 2400 l.';

  @override
  String get settings_units_gasModel_explanation =>
      'Wie der Flaschendruck in ein Gasvolumen umgerechnet wird. Dies betrifft das AMV, die Gasstatistik, den Planer und die Gasrechner. Ideales Gas entspricht der von den Verbänden gelehrten Rechnung; reales Gas ist physikalisch genau und ergibt beim AMV etwa 5 % niedrigere Werte.';

  @override
  String get settings_units_dialog_gasModel => 'Gasberechnungen';

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
  String get settings_units_sacRate => 'AMV';

  @override
  String get settings_units_defaultCurrency => 'Standardwährung';

  @override
  String get settings_units_dialog_defaultCurrency => 'Standardwährung';

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
  String get settings_units_volume_cubicFeet => 'Kubikfuß (cuft)';

  @override
  String get settings_units_volume_liters => 'Liter (L)';

  @override
  String get settings_units_weight => 'Gewicht';

  @override
  String get settings_units_weight_kilograms => 'Kilogramm (kg)';

  @override
  String get settings_units_weight_pounds => 'Pfund (lbs)';

  @override
  String get settings_updates_automaticUpdates => 'Automatische Updates';

  @override
  String get settings_updates_automaticUpdatesSubtitle =>
      'Regelmäßig nach Updates suchen';

  @override
  String get settings_updates_betaDialogBody =>
      'Beta-Builds werden aus jeder Änderung veröffentlicht und können die Datenbank Ihres Tauchlogbuchs vor der stabilen Version aktualisieren. Ein späterer Wechsel zurück zu Stabil stuft die App nicht herab, und alle Geräte, die miteinander synchronisieren, sollten denselben Kanal verwenden. Vor jedem Datenbank-Upgrade wird automatisch ein Backup erstellt.';

  @override
  String get settings_updates_betaDialogConfirm => 'Zu Beta wechseln';

  @override
  String get settings_updates_betaDialogTitle => 'Beta-Updates erhalten?';

  @override
  String get settings_updates_channel => 'Update-Kanal';

  @override
  String settings_updates_channelBadgeBeta(String version) {
    return '$version (Beta)';
  }

  @override
  String get settings_updates_channelBeta => 'Beta';

  @override
  String get settings_updates_channelBetaSubtitle =>
      'Neue Builds aus jeder Änderung, vor der stabilen Version';

  @override
  String get settings_updates_channelStable => 'Stabil';

  @override
  String get settings_updates_channelStableSubtitle =>
      'Nur getestete Versionen';

  @override
  String get settings_updates_checkForUpdates => 'Nach Updates suchen';

  @override
  String get settings_updates_checking => 'Wird geprüft...';

  @override
  String settings_updates_downloading(String progress) {
    return 'Wird heruntergeladen... $progress%';
  }

  @override
  String settings_updates_error(String message) {
    return 'Fehler: $message';
  }

  @override
  String get settings_updates_header => 'Updates';

  @override
  String get settings_updates_joinBeta => 'An der Beta teilnehmen';

  @override
  String get settings_updates_joinBetaSubtitle =>
      'Erhalten Sie neue Funktionen frühzeitig über das Beta-Programm';

  @override
  String get settings_updates_lastChecked => 'Zuletzt geprüft';

  @override
  String get settings_updates_never => 'Nie';

  @override
  String settings_updates_readyToInstall(String version) {
    return 'Version $version bereit zur Installation';
  }

  @override
  String get settings_updates_stableSwitchNotice =>
      'Sie bleiben auf dieser Beta, bis die nächste stabile Version neuer ist als diese.';

  @override
  String get settings_updates_upToDate => 'Auf dem neuesten Stand';

  @override
  String settings_updates_versionAvailable(String version) {
    return 'Version $version verfügbar';
  }

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
      'Ausrüstungsnutzung & Gewicht';

  @override
  String get statistics_category_equipment_title => 'Ausrüstung';

  @override
  String get statistics_category_gas_subtitle => 'AMV & Gasgemische';

  @override
  String get statistics_category_gas_title => 'Luftverbrauch';

  @override
  String get statistics_category_geographic_subtitle => 'Länder & Regionen';

  @override
  String get statistics_category_geographic_title => 'Geografie';

  @override
  String get statistics_category_marineLife_subtitle => 'Artensichtungen';

  @override
  String get statistics_category_marineLife_title => 'Meeresbewohner';

  @override
  String get statistics_category_overview_title => 'Overview';

  @override
  String get statistics_category_overview_subtitle =>
      'Totals, records, and breakdowns at a glance';

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
  String get statistics_chart_noBarData => 'Keine Daten verfügbar';

  @override
  String get statistics_chart_noDistributionData =>
      'Keine Verteilungsdaten verfügbar';

  @override
  String get statistics_chart_noTrendData => 'Keine Trenddaten verfügbar';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return 'Trendliniendiagramm mit $count Datenpunkten';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return 'Trendliniendiagramm mit $count Datenpunkten für $yAxisLabel';
  }

  @override
  String get statistics_conditions_appBar_title => 'Bedingungen';

  @override
  String get statistics_conditions_entryMethod_empty =>
      'Keine Einstiegsmethoden-Daten verfügbar';

  @override
  String get statistics_conditions_entryMethod_error =>
      'Einstiegsmethoden-Daten konnten nicht geladen werden';

  @override
  String get statistics_conditions_entryMethod_subtitle => 'Ufer, Boot usw.';

  @override
  String get statistics_conditions_entryMethod_title => 'Einstiegsmethode';

  @override
  String get statistics_conditions_temperature_empty =>
      'Keine Temperaturdaten verfügbar';

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
      'Tauchgänge nach Sichtbedingungen';

  @override
  String get statistics_conditions_visibility_title => 'Sichtverteilung';

  @override
  String get statistics_conditions_waterType_error =>
      'Wassertyp-Daten konnten nicht geladen werden';

  @override
  String get statistics_conditions_waterType_subtitle =>
      'Salz- vs. Süßwasser-Tauchgänge';

  @override
  String get statistics_conditions_waterType_title => 'Wassertyp';

  @override
  String get statistics_equipment_appBar_title => 'Ausrüstung';

  @override
  String get statistics_equipment_mostUsedGear_error =>
      'Ausrüstungsdaten konnten nicht geladen werden';

  @override
  String get statistics_equipment_mostUsedGear_subtitle =>
      'Ausrüstung nach Tauchganganzahl';

  @override
  String get statistics_equipment_mostUsedGear_title =>
      'Meistgenutzte Ausrüstung';

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
  String get statistics_filterBar_clear => 'Filter zurücksetzen';

  @override
  String statistics_filterBar_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge',
      one: '1 Tauchgang',
    );
    return '$_temp0';
  }

  @override
  String get statistics_gas_appBar_title => 'Luftverbrauch';

  @override
  String get statistics_gas_gasMix_error =>
      'Gasgemisch-Daten konnten nicht geladen werden';

  @override
  String get statistics_gas_gasMix_subtitle => 'Tauchgänge nach Gastyp';

  @override
  String get statistics_gas_gasMix_title => 'Gasgemisch-Verteilung';

  @override
  String get statistics_gas_sacByRole_empty =>
      'Keine Multi-Flaschen-Daten verfügbar';

  @override
  String get statistics_gas_sacByRole_error =>
      'AMV nach Rolle konnte nicht geladen werden';

  @override
  String get statistics_gas_sacByRole_subtitle =>
      'Durchschnittlicher Verbrauch nach Flaschentyp';

  @override
  String get statistics_gas_sacByRole_title => 'AMV nach Flaschenrolle';

  @override
  String get statistics_gas_sacRecords_best => 'Bestes AMV';

  @override
  String get statistics_gas_sacRecords_empty =>
      'Noch keine AMV-Daten verfügbar';

  @override
  String get statistics_gas_sacRecords_error =>
      'AMV-Rekorde konnten nicht geladen werden';

  @override
  String get statistics_gas_sacRecords_highest => 'Höchstes AMV';

  @override
  String get statistics_gas_sacRecords_subtitle =>
      'Bester und schlechtester Luftverbrauch';

  @override
  String get statistics_gas_sacRecords_title => 'AMV-Rekorde';

  @override
  String get statistics_gas_sacTrend_error =>
      'AMV-Trend konnte nicht geladen werden';

  @override
  String get statistics_gas_sacTrend_subtitle =>
      'Monatlicher Durchschnitt über 5 Jahre';

  @override
  String get statistics_gas_sacTrend_title => 'AMV-Trend';

  @override
  String get statistics_gas_tankRole_backGas => 'Rückengas';

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
  String get statistics_geographic_countries_empty => 'Keine besuchten Länder';

  @override
  String get statistics_geographic_countries_error =>
      'Länderdaten konnten nicht geladen werden';

  @override
  String get statistics_geographic_countries_subtitle => 'Tauchgänge nach Land';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count Länder. Spitzenreiter: $topName mit $topCount Tauchgängen';
  }

  @override
  String get statistics_geographic_countries_title => 'Besuchte Länder';

  @override
  String get statistics_geographic_regions_empty => 'Keine erkundeten Regionen';

  @override
  String get statistics_geographic_regions_error =>
      'Regionsdaten konnten nicht geladen werden';

  @override
  String get statistics_geographic_regions_subtitle => 'Tauchgänge nach Region';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count Regionen. Spitzenreiter: $topName mit $topCount Tauchgängen';
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
    return '$count Reisen. Spitzenreiter: $topName mit $topCount Tauchgängen';
  }

  @override
  String get statistics_geographic_trips_title => 'Tauchgänge pro Reise';

  @override
  String get statistics_listContent_selectedSuffix => ', ausgewählt';

  @override
  String get statistics_marineLife_appBar_title => 'Meeresbewohner';

  @override
  String get statistics_marineLife_bestSites_empty => 'Keine Platzdaten';

  @override
  String get statistics_marineLife_bestSites_error =>
      'Platzdaten konnten nicht geladen werden';

  @override
  String get statistics_marineLife_bestSites_subtitle =>
      'Plätze mit der größten Artenvielfalt';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count Plätze. Bester: $topName mit $topCount Arten';
  }

  @override
  String get statistics_marineLife_bestSites_title =>
      'Beste Plätze für Meeresbewohner';

  @override
  String get statistics_marineLife_mostCommon_empty => 'Keine Sichtungsdaten';

  @override
  String get statistics_marineLife_mostCommon_error =>
      'Sichtungsdaten konnten nicht geladen werden';

  @override
  String get statistics_marineLife_mostCommon_subtitle =>
      'Am häufigsten gesichtete Arten';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count Arten. Am häufigsten: $topName mit $topCount Sichtungen';
  }

  @override
  String get statistics_marineLife_mostCommon_title => 'Häufigste Sichtungen';

  @override
  String get statistics_marineLife_speciesSpotted => 'Gesichtete Arten';

  @override
  String get statistics_profile_appBar_title => 'Profilanalyse';

  @override
  String get statistics_profile_ascentDescent_empty =>
      'Keine Profildaten verfügbar';

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
  String get statistics_profile_deco_decoDives => 'Deko-Tauchgänge';

  @override
  String get statistics_profile_deco_decoLabel => 'Deko';

  @override
  String get statistics_profile_deco_decoRate => 'Deko-Rate';

  @override
  String get statistics_profile_deco_empty => 'Keine Deko-Daten verfügbar';

  @override
  String get statistics_profile_deco_error =>
      'Deko-Daten konnten nicht geladen werden';

  @override
  String get statistics_profile_deco_noDeco => 'Kein Deko';

  @override
  String get statistics_profile_deco_notRecorded => 'Nicht erfasst';

  @override
  String statistics_profile_deco_notRecordedHint(int count) {
    return '$count Tauchgänge haben keine erfassten oder berechenbaren Deko-Daten und sind von der Rate ausgenommen';
  }

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return 'Dekompressionsrate: $percentage% der Tauchgänge erforderten Deko-Stopps';
  }

  @override
  String get statistics_profile_deco_subtitle => 'Tauchgänge mit Deko-Stopps';

  @override
  String get statistics_profile_deco_title => 'Dekompressionspflicht';

  @override
  String get statistics_profile_timeAtDepth_empty =>
      'Keine Tiefendaten verfügbar';

  @override
  String get statistics_profile_timeAtDepth_error =>
      'Tiefenbereichsdaten konnten nicht geladen werden';

  @override
  String get statistics_profile_timeAtDepth_subtitle =>
      'Ungefähre Zeit auf jeder Tiefe';

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
      'Gesamtzahl der Tauchgänge im Zeitverlauf';

  @override
  String get statistics_progression_cumulative_title =>
      'Kumulative Tauchganganzahl';

  @override
  String get statistics_progression_depthProgression_error =>
      'Tiefenentwicklung konnte nicht geladen werden';

  @override
  String get statistics_progression_depthProgression_subtitle =>
      'Monatliche Maximaltiefe über 5 Jahre';

  @override
  String get statistics_progression_depthProgression_title =>
      'Maximale Tiefenentwicklung';

  @override
  String get statistics_progression_divesPerYear_empty =>
      'Keine Jahresdaten verfügbar';

  @override
  String get statistics_progression_divesPerYear_error =>
      'Jahresdaten konnten nicht geladen werden';

  @override
  String get statistics_progression_divesPerYear_subtitle =>
      'Jährlicher Tauchgangvergleich';

  @override
  String get statistics_progression_divesPerYear_title => 'Tauchgänge pro Jahr';

  @override
  String get statistics_ranking_countLabel_dives => 'Tauchgänge';

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
  String get statistics_records_coldestDive => 'Kältester Tauchgang';

  @override
  String get statistics_records_deepestDive => 'Tiefster Tauchgang';

  @override
  String statistics_records_diveNumber(Object number) {
    return 'Tauchgang #$number';
  }

  @override
  String get statistics_records_emptySubtitle =>
      'Beginnen Sie mit dem Eintragen von Tauchgängen, um Ihre Rekorde hier zu sehen';

  @override
  String get statistics_records_emptyTitle => 'Noch keine Rekorde';

  @override
  String get statistics_records_error => 'Fehler beim Laden der Rekorde';

  @override
  String get statistics_records_firstDive => 'Erster Tauchgang';

  @override
  String get statistics_records_longestDive => 'Längster Tauchgang';

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
  String get statistics_records_warmestDive => 'Wärmster Tauchgang';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return 'Abschnitt $title';
  }

  @override
  String get statistics_social_appBar_title => 'Soziales & Buddies';

  @override
  String get statistics_social_soloVsBuddy_empty =>
      'Keine Tauchgangdaten verfügbar';

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
      'Solo- vs. Buddy-Tauchgänge';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => 'Mit Buddy';

  @override
  String get statistics_social_topBuddies_error =>
      'Buddy-Rangliste konnte nicht geladen werden';

  @override
  String get statistics_social_topBuddies_subtitle => 'Häufigste Tauchpartner';

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
      'Das Diagramm erscheint, wenn Sie Tauchgänge eintragen';

  @override
  String get statistics_summary_depthDistribution_semanticLabel =>
      'Kreisdiagramm der Tiefenverteilung';

  @override
  String get statistics_summary_depthDistribution_title => 'Tiefenverteilung';

  @override
  String get statistics_summary_diveTypes_empty =>
      'Das Diagramm erscheint, wenn Sie Tauchgänge eintragen';

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
      'Das Diagramm erscheint, wenn Sie Tauchgänge eintragen';

  @override
  String get statistics_summary_divesByMonth_semanticLabel =>
      'Balkendiagramm der Tauchgänge nach Monat';

  @override
  String get statistics_summary_divesByMonth_title => 'Tauchgänge nach Monat';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel\n$count Tauchgänge';
  }

  @override
  String get statistics_summary_header_subtitle =>
      'Wählen Sie eine Kategorie, um detaillierte Statistiken zu erkunden';

  @override
  String get statistics_summary_header_title => 'Statistik-Übersicht';

  @override
  String get statistics_summary_maxDepth => 'Max. Tiefe';

  @override
  String get statistics_summary_sitesVisited => 'Besuchte Plätze';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge',
      one: '1 Tauchgang',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty => 'Noch keine Tags erstellt';

  @override
  String get statistics_summary_tagUsage_emptyHint =>
      'Fügen Sie Tauchgängen Tags hinzu, um Statistiken zu sehen';

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
    return '$count Tauchgänge';
  }

  @override
  String get statistics_summary_topDiveSites_empty => 'Noch keine Tauchplätze';

  @override
  String get statistics_summary_topDiveSites_title => 'Top-Tauchplätze';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count insgesamt';
  }

  @override
  String get statistics_summary_totalDives => 'Tauchgänge gesamt';

  @override
  String get statistics_summary_totalTime => 'Gesamtzeit';

  @override
  String get statistics_timePatterns_appBar_title => 'Zeitmuster';

  @override
  String get statistics_timePatterns_dayOfWeek_empty => 'Keine Daten verfügbar';

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
      'Tauchgänge nach Wochentag';

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
  String get statistics_timePatterns_seasonal_empty => 'Keine Daten verfügbar';

  @override
  String get statistics_timePatterns_seasonal_error =>
      'Saisonale Daten konnten nicht geladen werden';

  @override
  String get statistics_timePatterns_seasonal_subtitle =>
      'Tauchgänge nach Monat (alle Jahre)';

  @override
  String get statistics_timePatterns_seasonal_title => 'Saisonale Muster';

  @override
  String get statistics_timePatterns_surfaceInterval_average => 'Durchschnitt';

  @override
  String get statistics_timePatterns_surfaceInterval_empty =>
      'Keine Oberflächenintervall-Daten verfügbar';

  @override
  String get statistics_timePatterns_surfaceInterval_error =>
      'Oberflächenintervall-Daten konnten nicht geladen werden';

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
      'Zeit zwischen Tauchgängen';

  @override
  String get statistics_timePatterns_surfaceInterval_title =>
      'Oberflächenintervall-Statistiken';

  @override
  String get statistics_timePatterns_timeOfDay_error =>
      'Tageszeitdaten konnten nicht geladen werden';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle =>
      'Morgens, nachmittags, abends oder nachts';

  @override
  String get statistics_timePatterns_timeOfDay_title =>
      'Tauchgänge nach Tageszeit';

  @override
  String get statistics_tooltip_diveRecords => 'Tauchrekorde';

  @override
  String get statistics_tooltip_filter => 'Statistiken filtern';

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
  String surfaceInterval_gasWarning_modExceeded(
    Object ppO2,
    Object depth,
    Object limit,
    Object mod,
  ) {
    return 'ppO₂ $ppO2 auf $depth überschreitet $limit. MOD für dieses Gemisch ist $mod.';
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
    return 'Die Wartezeit liegt über den $hours Stunden, die dieser Planer durchsucht. Die Entsättigung geht weiter, ein längeres Oberflächenintervall reicht also aus.';
  }

  @override
  String surfaceInterval_result_beyondHorizonShort(Object hours) {
    return 'Mehr als $hours Stunden';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Aktuelles Intervall';

  @override
  String get surfaceInterval_result_gasUnsafe => 'Gas in dieser Tiefe unsicher';

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
  String surfaceInterval_result_noIntervalHelps(Object minutes) {
    return 'Kein Oberflächenintervall reicht aus. Der längste Nullzeit-Tauchgang in dieser Tiefe mit diesem Gemisch dauert $minutes Min. Zweiten Tauchgang kürzen oder dessen Tiefe reduzieren.';
  }

  @override
  String get surfaceInterval_result_notAchievable =>
      'Mit keinem Oberflächenintervall erreichbar';

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
  String surfaceInterval_secondDive_heSemantics(Object percent) {
    return 'Zweiter Tauchgang Helium: $percent%';
  }

  @override
  String surfaceInterval_secondDive_o2Semantics(Object percent) {
    return 'Zweiter Tauchgang O2: $percent%';
  }

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
  String get tags_action_browse => 'Durchsuchen';

  @override
  String get tags_picker_title => 'Tags auswählen';

  @override
  String get tags_picker_empty =>
      'Noch keine Tags. Gib einen Tag-Namen ein, um deinen ersten zu erstellen.';

  @override
  String tags_picker_errorLoading(String error) {
    return 'Fehler beim Laden der Tags: $error';
  }

  @override
  String get tags_picker_allAdded => 'Alle Tags sind bereits hinzugefügt.';

  @override
  String get tags_picker_noMatches => 'Keine Tags entsprechen deiner Suche.';

  @override
  String tags_picker_addCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tags hinzufügen',
      one: '1 Tag hinzufügen',
      zero: 'Tags hinzufügen',
    );
    return '$_temp0';
  }

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
  String get importWizard_tagsLabel => 'Tags';

  @override
  String get importWizard_photos_stepLabel => 'Fotos';

  @override
  String importWizard_photos_foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos in diesem Logbuch referenziert',
      one: '1 Foto in diesem Logbuch referenziert',
    );
    return '$_temp0';
  }

  @override
  String get importWizard_photos_chooseFolder => 'Fotoordner wählen...';

  @override
  String get importWizard_photos_scanning => 'Ordner wird durchsucht...';

  @override
  String importWizard_photos_matchSummary(
    int matched,
    int byName,
    int missing,
  ) {
    return '$matched zugeordnet, $byName nur über den Dateinamen, $missing nicht gefunden';
  }

  @override
  String get importWizard_photos_skip => 'Fotos überspringen';

  @override
  String get importWizard_photos_mobileUnsupported =>
      'Für den Fotoimport wird ein Ordner auf dem Speicher dieses Geräts benötigt. Führe diesen Import an einem Computer aus, um Fotos einzuschließen. Tauchgänge und Tauchplätze werden normal importiert.';

  @override
  String importWizard_review_olderDivesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count ältere Tauchgänge übersprungen — bereits in deinem Logbuch',
      one: '1 älterer Tauchgang übersprungen — bereits in deinem Logbuch',
    );
    return '$_temp0';
  }

  @override
  String get tags_hint_addTags => 'Tags hinzufügen...';

  @override
  String get tags_manage_title => 'Tags';

  @override
  String get tags_manage_searchHint => 'Tags suchen...';

  @override
  String tags_manage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge',
      one: '1 Tauchgang',
      zero: '0 Tauchgänge',
    );
    return '$_temp0';
  }

  @override
  String get tags_manage_emptyState =>
      'Noch keine Tags. Erstellen Sie einen, um zu beginnen.';

  @override
  String tags_manage_selectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get tags_manage_createTitle => 'Tag erstellen';

  @override
  String get tags_manage_editTitle => 'Tag bearbeiten';

  @override
  String get tags_manage_nameLabel => 'Tag-Name';

  @override
  String get tags_manage_colorLabel => 'Farbe';

  @override
  String get tags_manage_nameRequired => 'Tag-Name ist erforderlich';

  @override
  String get tags_manage_deleteTitle => 'Tag löschen?';

  @override
  String tags_manage_deleteMessage(String tagName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgängen',
      one: '1 Tauchgang',
      zero: '0 Tauchgängen',
    );
    return '\"$tagName\" wird von $_temp0 entfernt. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String tags_manage_bulkDeleteTitle(int count) {
    return '$count Tags löschen?';
  }

  @override
  String tags_manage_bulkDeleteMessage(int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount Tauchgängen',
      one: '1 Tauchgang',
      zero: '0 Tauchgängen',
    );
    return 'Diese Tags werden von insgesamt $_temp0 entfernt. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String tags_manage_mergeTitle(int count) {
    return '$count Tags zusammenführen';
  }

  @override
  String get tags_manage_mergeResultName => 'Resultierender Tag-Name:';

  @override
  String get tags_manage_mergeKeepFrom => 'Oder Namen übernehmen von:';

  @override
  String tags_manage_mergeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge',
      one: '1 Tauchgang',
      zero: '0 Tauchgänge',
    );
    return 'Dies betrifft insgesamt $_temp0.';
  }

  @override
  String get tags_manage_mergeAction => 'Zusammenführen';

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
  String get tank_al80_description => 'Aluminium 80 cuft (am häufigsten)';

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
  String tides_source_noaaStation(String name, String distance) {
    return 'NOAA-Station: $name ($distance)';
  }

  @override
  String get tides_source_modelEstimate => 'Ozeanmodell-Schätzung';

  @override
  String get tides_source_modelCaveat =>
      'Aus Satellitendaten modelliert. Zeiten und Höhen können in der Nähe komplexer Küstenlinien abweichen.';

  @override
  String get tides_source_sheetTitle => 'Quelle der Gezeitendaten';

  @override
  String get tides_source_datumMllw => 'Höhen relativ zu MLLW (Stationsdatum)';

  @override
  String get tides_source_datumMsl =>
      'Höhen relativ zum mittleren Meeresspiegel';

  @override
  String get tides_title => 'Gezeiten';

  @override
  String get transfer_appBar_title => 'Übertragung';

  @override
  String get transfer_computers_aboutContent =>
      'Verbinden Sie Ihren Tauchcomputer über Bluetooth, um Tauchprotokolle direkt in die App herunterzuladen. Unterstützte Computer sind Suunto, Shearwater, Garmin, Mares und viele andere beliebte Marken.\n\nApple Watch Ultra-Benutzer können Tauchdaten direkt aus der Health-App importieren, einschließlich Tiefe, Dauer und Herzfrequenz.';

  @override
  String get transfer_computers_aboutTitle => 'Über Tauchcomputer';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple Watch';

  @override
  String get transfer_computers_appleWatchSubtitle =>
      'Import dives via Apple HealthKit';

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
  String transfer_computers_diveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge',
      one: '1 Tauchgang',
    );
    return '$_temp0';
  }

  @override
  String get transfer_computers_downloadTooltip => 'Tauchgänge herunterladen';

  @override
  String get transfer_computers_knownComputersHeader => 'Bekannte Computer';

  @override
  String transfer_computers_lastDownloadDaysAgo(int days) {
    return 'vor $days Tagen';
  }

  @override
  String transfer_computers_lastDownloadHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'vor $hours Stunden',
      one: 'vor 1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String transfer_computers_lastDownloadMinutesAgo(int minutes) {
    return 'vor $minutes Min.';
  }

  @override
  String get transfer_computers_lastDownloadNever => 'Nie';

  @override
  String get transfer_computers_lastDownloadYesterday => 'Gestern';

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
      'Ausrüstungsinventar und Serviceinformationen exportieren';

  @override
  String get transfer_csvExport_descriptionSites =>
      'Tauchplatzstandorte und Details exportieren';

  @override
  String get transfer_csvExport_dialogTitle => 'CSV exportieren';

  @override
  String get transfer_csvExport_exportButton => 'CSV exportieren';

  @override
  String get transfer_csvExport_optionDivesTitle => 'Tauchgänge CSV';

  @override
  String get transfer_csvExport_optionEquipmentTitle => 'Ausrüstung CSV';

  @override
  String get transfer_csvExport_optionSitesTitle => 'Tauchplätze CSV';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return '$typeName exportieren';
  }

  @override
  String get transfer_csvExport_typeDives => 'Tauchgänge';

  @override
  String get transfer_csvExport_typeEquipment => 'Ausrüstung';

  @override
  String get transfer_csvExport_typeSites => 'Tauchplätze';

  @override
  String get transfer_detail_backTooltip => 'Zurück zur Übertragung';

  @override
  String get transfer_export_aboutContent =>
      'Exportieren Sie Ihre Tauchdaten in verschiedenen Formaten. PDF erstellt ein druckbares Tauchlogbuch. UDDF ist ein universelles Format, das mit den meisten Tauchlog-Programmen kompatibel ist. CSV-Dateien können in Tabellenkalkulationen geöffnet werden.';

  @override
  String get transfer_export_backupLink => 'Zu Sicherung & Wiederherstellung';

  @override
  String get transfer_export_aboutTitle => 'Über Export';

  @override
  String get transfer_export_completed => 'Export abgeschlossen';

  @override
  String get transfer_export_csvSubtitle => 'Tabellenformat';

  @override
  String get transfer_export_csvTitle => 'CSV-Export';

  @override
  String get transfer_export_excelSubtitle =>
      'Alle Daten in einer Datei (Tauchgänge, Tauchplätze, Ausrüstung, Statistiken)';

  @override
  String get transfer_export_excelTitle => 'Excel-Arbeitsmappe';

  @override
  String transfer_export_failed(Object error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get transfer_export_kmlSubtitle =>
      'Tauchplätze auf einem 3D-Globus anzeigen';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => 'Multi-Format-Export';

  @override
  String get transfer_export_optionSaveSubtitle =>
      'Speicherort auf Ihrem Gerät wählen';

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
      'Verwenden Sie \"Daten importieren\" für das beste Ergebnis - das Dateiformat und die Quell-App werden automatisch erkannt. Die einzelnen Formatoptionen unten stehen auch für den direkten Zugriff zur Verfügung.';

  @override
  String get transfer_import_aboutTitle => 'Über Import';

  @override
  String get transfer_import_fileImportSemanticLabel =>
      'Daten mit automatischer Erkennung importieren';

  @override
  String get transfer_import_fileImportSubtitle =>
      'Erkennt automatisch CSV, UDDF, FIT und mehr';

  @override
  String get transfer_import_fileImportTitle => 'Daten importieren';

  @override
  String get transfer_import_sectionHeader => 'Daten importieren';

  @override
  String get transfer_pdfExport_cancelButton => 'Abbrechen';

  @override
  String get transfer_pdfExport_dialogTitle => 'PDF-Logbuch exportieren';

  @override
  String get transfer_pdfExport_exportButton => 'PDF exportieren';

  @override
  String get transfer_pdfExport_includeCertCards =>
      'Zertifizierungskarten einschließen';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle =>
      'Gescannte Zertifizierungskartenbilder zum PDF hinzufügen';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => 'Seitengröße';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Letter';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => 'Detailliert';

  @override
  String get transfer_pdfExport_templateDetailedDesc =>
      'Vollständige Tauchinformationen mit Notizen und Bewertungen';

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
    return 'Vorlage $templateName auswählen';
  }

  @override
  String get transfer_pdfExport_templateSimple => 'Einfach';

  @override
  String get transfer_pdfExport_templateSimpleDesc =>
      'Kompaktes Tabellenformat, viele Tauchgänge pro Seite';

  @override
  String get transfer_section_computersSubtitle => 'Vom Gerät herunterladen';

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
      'Wählen Sie einen Bereich aus der Liste';

  @override
  String get transfer_summary_title => 'Übertragung';

  @override
  String transfer_unknownSection(Object sectionId) {
    return 'Unbekannter Bereich: $sectionId';
  }

  @override
  String get trips_appBar_title => 'Reisen';

  @override
  String get trips_appBar_tripPhotos => 'Reisefotos';

  @override
  String get trips_detail_action_delete => 'Löschen';

  @override
  String get trips_detail_action_export => 'Exportieren';

  @override
  String get trips_detail_appBar_title => 'Reise';

  @override
  String get trips_detail_dialog_cancel => 'Abbrechen';

  @override
  String get trips_detail_dialog_deleteConfirm => 'Löschen';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return 'Sind Sie sicher, dass Sie \"$name\" löschen möchten? Die Reise wird entfernt, aber die Tauchgänge bleiben erhalten.';
  }

  @override
  String get trips_detail_dialog_deleteTitle => 'Reise löschen?';

  @override
  String get trips_detail_dives_empty =>
      'Noch keine Tauchgänge in dieser Reise';

  @override
  String get trips_detail_dives_errorLoading =>
      'Tauchgänge konnten nicht geladen werden';

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
  String get trips_detail_export_csv_subtitle => 'Alle Tauchgänge dieser Reise';

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
      'Fügen Sie zuerst Tauchgänge hinzu, um Fotos zu verknüpfen';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return 'Fehler beim Verknüpfen der Fotos: $error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return 'Fehler beim Scannen: $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return '$count Fotos verknüpft';
  }

  @override
  String get trips_detail_scan_linkingPhotos => 'Fotos werden verknüpft...';

  @override
  String get trips_detail_sectionTitle_details => 'Reisedetails';

  @override
  String get trips_detail_sectionTitle_dives => 'Tauchgänge';

  @override
  String get trips_detail_sectionTitle_notes => 'Notizen';

  @override
  String get trips_detail_sectionTitle_statistics => 'Reisestatistik';

  @override
  String get trips_detail_snackBar_deleted => 'Reise gelöscht';

  @override
  String get trips_detail_stat_avgDepth => 'Durchschn. Tiefe';

  @override
  String get trips_detail_stat_maxDepth => 'Max. Tiefe';

  @override
  String get trips_detail_stat_totalRuntime => 'Gesamte Laufzeit';

  @override
  String get trips_detail_stat_totalDives => 'Tauchgänge gesamt';

  @override
  String get trips_detail_tab_checklist => 'Checkliste';

  @override
  String get trips_detail_tooltip_edit => 'Reise bearbeiten';

  @override
  String get trips_detail_tooltip_editShort => 'Bearbeiten';

  @override
  String get trips_detail_tooltip_moreOptions => 'Weitere Optionen';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Auf Karte anzeigen';

  @override
  String trips_diveScan_addButton(int count) {
    return '$count Tauchgänge hinzufügen';
  }

  @override
  String trips_diveScan_added(int count) {
    return '$count Tauchgänge zur Reise hinzugefügt';
  }

  @override
  String get trips_diveScan_cancel => 'Abbrechen';

  @override
  String trips_diveScan_currentTrip(String tripName) {
    return 'Derzeit in: $tripName';
  }

  @override
  String get trips_diveScan_deselectAll => 'Alle abwählen';

  @override
  String trips_diveScan_error(String error) {
    return 'Fehler beim Suchen nach Tauchgängen: $error';
  }

  @override
  String get trips_diveScan_findButton => 'Passende Tauchgänge finden';

  @override
  String trips_diveScan_groupOtherTrips(int count) {
    return 'In anderen Reisen ($count)';
  }

  @override
  String trips_diveScan_groupUnassigned(int count) {
    return 'Nicht zugewiesen ($count)';
  }

  @override
  String get trips_diveScan_noMatches => 'Keine passenden Tauchgänge gefunden';

  @override
  String get trips_diveScan_noDiver =>
      'Wähle einen aktiven Taucher aus, um nach Tauchgängen zu suchen';

  @override
  String get trips_diveScan_selectAll => 'Alle auswählen';

  @override
  String trips_diveScan_subtitle(int count) {
    return '$count Tauchgänge im Datumsbereich gefunden';
  }

  @override
  String get trips_diveScan_title => 'Tauchgänge zur Reise hinzufügen';

  @override
  String get trips_diveScan_unknownSite => 'Unbekannter Tauchplatz';

  @override
  String get trips_edit_appBar_add => 'Reise hinzufügen';

  @override
  String get trips_edit_appBar_edit => 'Reise bearbeiten';

  @override
  String get trips_edit_button_add => 'Reise hinzufügen';

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
      'Sie haben ungespeicherte Änderungen. Sind Sie sicher, dass Sie die Seite verlassen möchten?';

  @override
  String get trips_edit_dialog_discardTitle => 'Änderungen verwerfen?';

  @override
  String get trips_edit_dialog_keepEditing => 'Weiter bearbeiten';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days Tage';
  }

  @override
  String get trips_edit_hint_liveaboardName => 'z.B. MY Blue Force One';

  @override
  String get trips_edit_hint_location => 'z.B. Ägypten, Rotes Meer';

  @override
  String get trips_edit_hint_notes => 'Zusätzliche Notizen zu dieser Reise';

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
  String get trips_edit_label_returnFlight => 'Rückflug';

  @override
  String get trips_edit_returnFlightClear => 'Rückflug entfernen';

  @override
  String get trips_edit_returnFlightNotSet => 'Nicht festgelegt';

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
  String get trips_edit_snackBar_added => 'Reise erfolgreich hinzugefügt';

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
      'Fügen Sie zuerst Tauchgänge hinzu, um Fotos zu verknüpfen';

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
    return 'Fehler beim Verknüpfen der Fotos: $error';
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
    return '$count Fotos verknüpft';
  }

  @override
  String get trips_gallery_linkingPhotos => 'Fotos werden verknüpft...';

  @override
  String get trips_gallery_tooltip_scan => 'Gerätegalerie durchsuchen';

  @override
  String get trips_gallery_tripNotFound => 'Reise nicht gefunden';

  @override
  String get trips_list_button_retry => 'Erneut versuchen';

  @override
  String trips_list_countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days Tagen',
      one: 'In 1 Tag',
      zero: 'Beginnt heute',
    );
    return '$_temp0';
  }

  @override
  String get trips_list_empty_button => 'Erste Reise hinzufügen';

  @override
  String get trips_list_empty_filtered_subtitle =>
      'Versuchen Sie, Ihre Filter anzupassen oder zurückzusetzen';

  @override
  String get trips_list_empty_filtered_title =>
      'Keine Reisen entsprechen Ihren Filtern';

  @override
  String get trips_list_empty_subtitle =>
      'Erstellen Sie Reisen, um Ihre Tauchgänge nach Reiseziel zu gruppieren';

  @override
  String get trips_list_empty_title => 'Noch keine Reisen hinzugefügt';

  @override
  String trips_list_error_loading(Object error) {
    return 'Fehler beim Laden der Reisen: $error';
  }

  @override
  String get trips_list_fab_addTrip => 'Reise hinzufügen';

  @override
  String get trips_list_filters_clearAll => 'Alle löschen';

  @override
  String get trips_list_inProgress => 'Läuft gerade';

  @override
  String get trips_list_pastSection => 'Vergangene Reisen';

  @override
  String get trips_list_sort_title => 'Reisen sortieren';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count Tauchgänge';
  }

  @override
  String get trips_list_tooltip_addTrip => 'Reise hinzufügen';

  @override
  String get trips_list_tooltip_search => 'Reisen durchsuchen';

  @override
  String get trips_list_tooltip_sort => 'Sortieren';

  @override
  String get trips_list_upcomingSection => 'Bevorstehend';

  @override
  String get trips_photos_empty_scanButton => 'Gerätegalerie durchsuchen';

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
  String get trips_photos_tooltip_scan => 'Gerätegalerie durchsuchen';

  @override
  String get trips_photos_viewAll => 'Alle anzeigen';

  @override
  String get trips_picker_clearTooltip => 'Auswahl löschen';

  @override
  String get trips_picker_empty_createButton => 'Reise erstellen';

  @override
  String get trips_picker_empty_title => 'Noch keine Reisen';

  @override
  String trips_picker_error(Object error) {
    return 'Fehler beim Laden der Reisen: $error';
  }

  @override
  String get trips_picker_hint => 'Tippen, um eine Reise auszuwählen';

  @override
  String get trips_picker_newTrip => 'Neue Reise';

  @override
  String get trips_picker_noSelection => 'Keine Reise ausgewählt';

  @override
  String get trips_picker_sheetTitle => 'Reise auswählen';

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
    return 'Keine Reisen gefunden für \"$query\"';
  }

  @override
  String get trips_search_tooltip_back => 'Zurück';

  @override
  String get trips_search_tooltip_clear => 'Suche löschen';

  @override
  String get trips_summary_header_subtitle =>
      'Wählen Sie eine Reise aus der Liste, um Details anzuzeigen';

  @override
  String get trips_summary_header_title => 'Reisen';

  @override
  String get trips_summary_overview_title => 'Übersicht';

  @override
  String get trips_summary_quickActions_add => 'Reise hinzufügen';

  @override
  String get trips_summary_quickActions_title => 'Schnellaktionen';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date • $count Tauchgänge';
  }

  @override
  String get trips_summary_recentTitle => 'Neueste Reisen';

  @override
  String get trips_summary_stat_daysDiving => 'Tauchtage';

  @override
  String get trips_summary_stat_liveaboards => 'Tauchsafaris';

  @override
  String get trips_summary_stat_totalDives => 'Tauchgänge gesamt';

  @override
  String get trips_summary_stat_totalTrips => 'Reisen gesamt';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date • In $days Tagen';
  }

  @override
  String get trips_summary_upcomingTitle => 'Bevorstehend';

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
  String get units_profileMetric_millivolts => 'mV';

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
  String get universalImport_action_consolidate =>
      'Als zusätzlichen Computer zusammenführen';

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
  String get universalImport_action_changeFile => 'Datei wechseln';

  @override
  String get universalImport_action_selectFile => 'Datei auswählen';

  @override
  String get universalImport_action_selectFiles => 'Dateien auswählen';

  @override
  String get universalImport_action_chooseFolder => 'Ordner auswählen';

  @override
  String get universalImport_triage_title => 'Zu importierende Dateien';

  @override
  String universalImport_triage_readyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien bereit zum Import',
      one: '1 Datei bereit zum Import',
    );
    return '$_temp0';
  }

  @override
  String universalImport_label_filesSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien ausgewählt',
      one: '1 Datei ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_triage_excludedCsv => 'Einzeln importieren (CSV)';

  @override
  String get universalImport_triage_unsupported => 'Nicht unterstütztes Format';

  @override
  String get universalImport_triage_parseFailed =>
      'Konnte nicht gelesen werden';

  @override
  String universalImport_triage_parsing(int current, int total) {
    return 'Datei $current von $total wird gelesen…';
  }

  @override
  String get universalImport_triage_cancelParsing => 'Abbrechen';

  @override
  String get universalImport_triage_allExcluded =>
      'Keine der ausgewählten Dateien kann gemeinsam importiert werden. CSV-Dateien müssen einzeln importiert werden.';

  @override
  String get universalImport_triage_noneImportable =>
      'Keine der ausgewählten Dateien kann importiert werden.';

  @override
  String get universalImport_review_inBatchDuplicate =>
      'Duplikat eines anderen Tauchgangs in diesem Import-Stapel.';

  @override
  String get universalImport_summary_filesTitle => 'Dateien';

  @override
  String get universalImport_summary_noticesTitle => 'Nicht in der Datei';

  @override
  String get universalImport_summary_noticeNoTankPressureTitle =>
      'Flaschendruck nicht aufgezeichnet';

  @override
  String get universalImport_summary_noticeNoTankPressureBody =>
      'Luftverbrauch und AMV können nicht berechnet werden. Anfangs- und Enddruck lassen sich beim Bearbeiten des Tauchgangs ergänzen.';

  @override
  String universalImport_summary_noticeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Betrifft $count Tauchgänge',
      one: 'Betrifft 1 Tauchgang',
    );
    return '$_temp0';
  }

  @override
  String universalImport_summary_fileImported(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge importiert',
      one: '1 Tauchgang importiert',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_summary_fileNeedsIndividualImport =>
      'Muss einzeln importiert werden';

  @override
  String get universalImport_summary_fileUnsupported =>
      'Nicht unterstütztes Format';

  @override
  String get universalImport_summary_fileParseFailed => 'Lesen fehlgeschlagen';

  @override
  String universalImport_bulk_consolidateMatched(int count) {
    return 'Übereinstimmende zusammenführen ($count)';
  }

  @override
  String universalImport_bulk_importAll(int count) {
    return 'Alle importieren ($count)';
  }

  @override
  String universalImport_bulk_importAllAsNew(int count) {
    return 'Alle als neu importieren ($count)';
  }

  @override
  String universalImport_bulk_skipAll(int count) {
    return 'Alle überspringen ($count)';
  }

  @override
  String universalImport_bulk_replaceSourceAll(int count) {
    return 'Alle ersetzen ($count)';
  }

  @override
  String get universalImport_description_supportedFormats =>
      'Wählen Sie eine Tauchprotokoll-Datei zum Importieren aus. Unterstützte Formate sind CSV, UDDF, Subsurface XML und Garmin FIT.';

  @override
  String get universalImport_dive_decideAction => 'Entscheiden';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Dieses Format wird noch nicht unterstützt. Bitte exportieren Sie als UDDF oder CSV.';

  @override
  String get universalImport_label_columnMapping => 'Spaltenzuordnung';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped von $total Spalten zugeordnet';
  }

  @override
  String get universalImport_label_consolidate => 'Zusammenführen';

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
  String get universalImport_label_importAsNew => 'Als neu importieren';

  @override
  String get universalImport_label_importComplete => 'Import abgeschlossen';

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
  String get universalImport_entityAction_linkBadge => 'VERKNÜPFEN';

  @override
  String get universalImport_entityAction_linkExisting =>
      'Mit vorhandenem Eintrag verknüpfen';

  @override
  String get universalImport_entityAction_linkExistingSubtitle =>
      'Vorhandenen Eintrag verwenden';

  @override
  String get universalImport_entityAction_replaceBadge => 'ERSETZEN';

  @override
  String get universalImport_entityAction_replaceExisting =>
      'Vorhandenen ersetzen';

  @override
  String get universalImport_entityAction_replaceExistingSubtitle =>
      'Mit importierten Daten überschreiben';

  @override
  String get universalImport_entityAction_skip => 'Überspringen';

  @override
  String get universalImport_entityAction_skipSubtitle =>
      'Diesen Import verwerfen';

  @override
  String get universalImport_entityAction_importAsNew => 'Als neu importieren';

  @override
  String get universalImport_entityAction_importAsNewSubtitle =>
      'Separaten Eintrag erstellen';

  @override
  String get universalImport_pending_chooseAction => 'Aktion auswählen';

  @override
  String universalImport_pending_gateHint(int count) {
    return '$count Duplikat(e) erfordern eine Entscheidung';
  }

  @override
  String get universalImport_pending_needsDecision =>
      'Entscheidung erforderlich';

  @override
  String get universalImport_pending_reviewAction => 'Prüfen';

  @override
  String get universalImport_rowHint_tapCompareToDecide =>
      'Auf Entscheiden tippen zum Auswählen';

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
  String get universalImport_semantics_needsDecision =>
      'Vermutetes Duplikat, Entscheidung erforderlich';

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
  String universalImport_snackbar_bulkMarkedAs(int count, String action) {
    return '$count markiert als $action';
  }

  @override
  String universalImport_snackbar_markedAs(String action) {
    return 'Markiert als $action';
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
  String get universalImport_summary_decidesRequired =>
      'Jeder Eintrag benötigt vor dem Import eine Entscheidung.';

  @override
  String get universalImport_title => 'Daten importieren';

  @override
  String get universalImport_tooltip_closeWizard =>
      'Import-Assistent schließen';

  @override
  String weather_windFromDirection(Object wind, Object direction) {
    return '$wind aus $direction';
  }

  @override
  String get weather_wind_calm => 'windstill';

  @override
  String get weather_wind_highWind => 'starker Wind';

  @override
  String get weather_wind_lightBreeze => 'leichte Brise';

  @override
  String get weather_wind_moderateBreeze => 'massige Brise';

  @override
  String get weather_wind_strongBreeze => 'frische Brise';

  @override
  String get weather_wmo_clear => 'Klarer Himmel';

  @override
  String get weather_wmo_drizzle => 'Nieselregen';

  @override
  String get weather_wmo_fog => 'Nebel';

  @override
  String get weather_wmo_freezingDrizzle => 'Gefrierender Nieselregen';

  @override
  String get weather_wmo_freezingRain => 'Gefrierender Regen';

  @override
  String get weather_wmo_mainlyClear => 'Uberwiegend klar';

  @override
  String get weather_wmo_overcast => 'Bedeckt';

  @override
  String get weather_wmo_partlyCloudy => 'Teilweise bewolkt';

  @override
  String get weather_wmo_rain => 'Regen';

  @override
  String get weather_wmo_rainShowers => 'Regenschauer';

  @override
  String get weather_wmo_snow => 'Schnee';

  @override
  String get weather_wmo_snowGrains => 'Schneegriesel';

  @override
  String get weather_wmo_snowShowers => 'Schneeschauer';

  @override
  String get weather_wmo_thunderstorm => 'Gewitter';

  @override
  String get weather_wmo_thunderstormHail => 'Gewitter mit Hagel';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return 'Basis ($suitType): $weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return 'Körpergewichtsanpassung: +$adjustment kg';
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
  String get diveComputer_connectionType_ble => 'Bluetooth LE';

  @override
  String get diveComputer_connectionType_bluetooth => 'Bluetooth';

  @override
  String get diveComputer_connectionType_infrared => 'Infrarot';

  @override
  String get diveComputer_connectionType_unknown => 'Unbekannt';

  @override
  String get diveComputer_connectionType_usb => 'USB';

  @override
  String get diveComputer_connectionType_wifi => 'WLAN';

  @override
  String diveComputer_detail_deleteDialogContent(String name) {
    return 'Möchten Sie \"$name\" wirklich entfernen? Dadurch werden keine von diesem Computer importierten Tauchgänge gelöscht.';
  }

  @override
  String get diveComputer_detail_deleteDialogTitle => 'Computer löschen?';

  @override
  String get diveComputer_detail_divesImported => 'Importierte Tauchgänge';

  @override
  String get diveComputer_detail_downloadDivesButton =>
      'Tauchgänge herunterladen';

  @override
  String get diveComputer_detail_editDialogTitle => 'Computer bearbeiten';

  @override
  String get diveComputer_detail_editNameHint => 'z. B. Mein Perdix';

  @override
  String get diveComputer_detail_editNotesHint => 'Optionale Notizen';

  @override
  String get diveComputer_detail_labelConnection => 'Verbindung';

  @override
  String get diveComputer_detail_labelManufacturer => 'Hersteller';

  @override
  String get diveComputer_detail_labelModel => 'Modell';

  @override
  String get diveComputer_detail_labelName => 'Name';

  @override
  String get diveComputer_detail_lastDownload => 'Letzter Download';

  @override
  String get diveComputer_detail_notesTitle => 'Notizen';

  @override
  String get diveComputer_detail_reimportAllButton =>
      'Alle Tauchgänge neu importieren';

  @override
  String diveComputer_detail_reimportDialogBody(String computerName) {
    return 'Lädt jeden Tauchgang von $computerName herunter und gleicht sie mit deinem Logbuch ab. Dies kann mehrere Minuten dauern.';
  }

  @override
  String get diveComputer_detail_reimportDialogTitle =>
      'Alle Tauchgänge neu importieren?';

  @override
  String get diveComputer_detail_statisticsTitle => 'Statistiken';

  @override
  String get diveComputer_detail_unknown => 'Unbekannt';

  @override
  String get diveComputer_detail_viewDivesButton =>
      'Tauchgänge von diesem Computer anzeigen';

  @override
  String get diveComputer_discovery_chooseDifferentDevice =>
      'Anderes Gerät wählen';

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
  String get diveComputer_discovery_deviceNameLabel => 'Gerätename';

  @override
  String get diveComputer_discovery_exitDialogCancel => 'Abbrechen';

  @override
  String get diveComputer_discovery_exitDialogConfirm => 'Beenden';

  @override
  String get diveComputer_discovery_exitDialogContent =>
      'Möchten Sie wirklich beenden? Ihr Fortschritt geht verloren.';

  @override
  String get diveComputer_discovery_exitDialogTitle => 'Einrichtung beenden?';

  @override
  String get diveComputer_discovery_exitTooltip => 'Einrichtung beenden';

  @override
  String get diveComputer_discovery_noDeviceSelected => 'Kein Gerät ausgewählt';

  @override
  String get diveComputer_discovery_pleaseWaitConnection =>
      'Bitte warten, Verbindung wird hergestellt';

  @override
  String get diveComputer_discovery_recognizedDevice => 'Erkanntes Gerät';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      'Dieses Gerät befindet sich in unserer Bibliothek unterstützter Geräte. Der Tauchgangs-Download sollte automatisch funktionieren.';

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
  String get diveComputer_discovery_titleConfirmDevice => 'Gerät bestätigen';

  @override
  String get diveComputer_discovery_titleConnecting =>
      'Verbindung wird hergestellt';

  @override
  String get diveComputer_discovery_titleDownloading => 'Wird heruntergeladen';

  @override
  String get diveComputer_discovery_titleFindDevice => 'Gerät suchen';

  @override
  String get diveComputer_discovery_unknownDevice => 'Unbekanntes Gerät';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      'Dieses Gerät befindet sich nicht in unserer Bibliothek. Wir versuchen eine Verbindung herzustellen, aber der Download funktioniert möglicherweise nicht.';

  @override
  String get diveComputer_discovery_usbInstructions =>
      'Verbinden Sie Ihren Tauchcomputer per USB-Kabel und wählen Sie ihn unten aus.';

  @override
  String diveComputer_discovery_usbNoResults(String query) {
    return 'Keine Geräte für \"$query\"';
  }

  @override
  String get diveComputer_discovery_usbSearchHint =>
      'Nach Hersteller oder Modell suchen...';

  @override
  String get diveComputer_downloadExit_content =>
      'Beim Verlassen wird der aktuelle Download vom Tauchcomputer abgebrochen. Sind Sie sicher?';

  @override
  String get diveComputer_downloadExit_leave => 'Verlassen';

  @override
  String get diveComputer_downloadExit_stay => 'Bleiben';

  @override
  String get diveComputer_downloadExit_title => 'Download läuft';

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
  String get diveComputer_downloadStep_downloadAll =>
      'Alle Tauchgänge herunterladen';

  @override
  String get diveComputer_downloadStep_downloadFailed =>
      'Download fehlgeschlagen';

  @override
  String get diveComputer_downloadStep_downloadNew =>
      'Neue Tauchgänge herunterladen';

  @override
  String get diveComputer_downloadStep_downloadedDives =>
      'Heruntergeladene Tauchgänge';

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
  String get diveComputer_downloadStep_firstSyncBody =>
      'Dein Logbuch enthält bereits Tauchgänge. Du kannst das Herunterladen von Tauchgängen überspringen, die du bereits hast.';

  @override
  String get diveComputer_downloadStep_firstSyncTitle =>
      'Erster Download von diesem Tauchcomputer';

  @override
  String diveComputer_downloadStep_onlyAfterDate(String date) {
    return 'Nur Tauchgänge nach dem $date herunterladen';
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
  String diveComputer_downloadStep_importPartialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heruntergeladene Tauchgänge importieren',
      one: '1 heruntergeladenen Tauchgang importieren',
    );
    return '$_temp0';
  }

  @override
  String get diveComputer_download_cancel => 'Abbrechen';

  @override
  String get diveComputer_download_closeTooltip => 'Schließen';

  @override
  String get diveComputer_download_computerNotFound =>
      'Computer nicht gefunden';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return 'Gerät nicht gefunden. Stellen Sie sicher, dass Ihr $name in der Nähe ist und sich im Übertragungsmodus befindet.';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle =>
      'Gerät nicht gefunden';

  @override
  String get diveComputer_download_divesUpdated => 'Tauchgänge aktualisiert';

  @override
  String get diveComputer_download_done => 'Fertig';

  @override
  String get diveComputer_download_downloadedDives =>
      'Heruntergeladene Tauchgänge';

  @override
  String get diveComputer_download_duplicatesSkipped =>
      'Duplikate übersprungen';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_download_errorOccurred =>
      'Ein Fehler ist aufgetreten';

  @override
  String get diveComputer_download_noSerialPortsFound =>
      'Keine USB-Seriellports gefunden. Ist der Tauchcomputer angeschlossen und eingeschaltet?';

  @override
  String get diveComputer_download_stalePairing =>
      'Die Bluetooth-Kopplung dieses Tauchcomputers ist veraltet. Entfernen Sie den Tauchcomputer in den Bluetooth-Einstellungen Ihres Geräts und koppeln Sie ihn anschließend über das Bluetooth-Menü des Tauchcomputers erneut.';

  @override
  String get diveComputer_download_discoveryStalled =>
      'Der Tauchcomputer wurde verbunden, hat aber vor dem Start des Downloads nicht mehr geantwortet. Meist ist die Bluetooth-Kopplung veraltet: Entfernen Sie den Tauchcomputer in den Bluetooth-Einstellungen Ihres Geräts und versuchen Sie es erneut.';

  @override
  String diveComputer_download_serialConnectFailedWithDetails(Object details) {
    return 'Verbindung zum Tauchcomputer konnte nicht hergestellt werden.\n\nDiagnosedetails (mit Entwicklern teilen):\n$details';
  }

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get diveComputer_download_goBack => 'Zurück';

  @override
  String get diveComputer_download_importFailed => 'Import fehlgeschlagen';

  @override
  String get diveComputer_download_importResults => 'Import-Ergebnisse';

  @override
  String get diveComputer_download_importedDives => 'Importierte Tauchgänge';

  @override
  String diveComputer_download_importingCountDives(int count) {
    return '$count Tauchgänge werden importiert...';
  }

  @override
  String diveComputer_download_importingCountNewDives(int count) {
    return '$count neue Tauchgänge werden importiert...';
  }

  @override
  String get diveComputer_download_newDivesImported =>
      'Neue Tauchgänge importiert';

  @override
  String get diveComputer_download_newDivesOnlySubtitle =>
      'Lädt nur Tauchgänge herunter, die seit der letzten Synchronisierung hinzugefügt wurden';

  @override
  String get diveComputer_download_newDivesOnlyTitle =>
      'Nur neue Tauchgänge herunterladen';

  @override
  String get diveComputer_download_preparing => 'Wird vorbereitet...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_reimportHint =>
      'Suchst du ältere oder gelöschte Tauchgänge? Alle neu importieren';

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
      'Stellen Sie sicher, dass das Gerät in der Nähe ist und sich im Übertragungsmodus befindet';

  @override
  String get diveComputer_download_title => 'Tauchgänge herunterladen';

  @override
  String get diveComputer_download_tryAgain => 'Erneut versuchen';

  @override
  String get diveComputer_download_upToDate =>
      'Keine neuen Tauchgänge gefunden -- Ihr Logbuch ist aktuell';

  @override
  String get diveComputer_list_addComputer => 'Computer hinzufügen';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return 'Tauchcomputer: $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count Tauchgänge';
  }

  @override
  String get diveComputer_list_downloadTooltip => 'Tauchgänge herunterladen';

  @override
  String get diveComputer_list_emptyMessage =>
      'Verbinden Sie Ihren Tauchcomputer, um Tauchgänge direkt in die App herunterzuladen.';

  @override
  String get diveComputer_list_emptyTitle => 'Keine Tauchcomputer';

  @override
  String get diveComputer_list_findComputers => 'Computer suchen';

  @override
  String get diveComputer_list_helpBluetooth =>
      '- Bluetooth LE (die meisten modernen Computer)';

  @override
  String get diveComputer_list_helpBluetoothClassic =>
      '- Bluetooth Classic (ältere Modelle)';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi und über 50 weitere Modelle.';

  @override
  String get diveComputer_list_helpBrandsTitle => 'Unterstützte Marken';

  @override
  String get diveComputer_list_helpConnectionsTitle =>
      'Unterstützte Verbindungen';

  @override
  String get diveComputer_list_helpDialogTitle => 'Tauchcomputer-Hilfe';

  @override
  String get diveComputer_list_helpDismiss => 'Verstanden';

  @override
  String get diveComputer_list_helpTip1 =>
      '- Stellen Sie sicher, dass Ihr Computer im Übertragungsmodus ist';

  @override
  String get diveComputer_list_helpTip2 =>
      '- Halten Sie die Geräte während des Downloads nah beieinander';

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
  String get diveComputer_pinCode_instructions =>
      'Geben Sie den auf Ihrem Tauchcomputer angezeigten Code ein.';

  @override
  String get diveComputer_pinCode_label => 'PIN-Code';

  @override
  String get diveComputer_pinCode_submit => 'Senden';

  @override
  String get diveComputer_pinCode_title => 'PIN-Code erforderlich';

  @override
  String get diveComputer_pinEntry_connectButton => 'Verbinden';

  @override
  String get diveComputer_pinEntry_helperText =>
      'Geben Sie die 4- bis 6-stellige PIN von Ihrem Gerät ein';

  @override
  String get diveComputer_pinEntry_instructionsGeneric =>
      'Prüfen Sie das Display Ihres Tauchcomputers auf den PIN-Code.';

  @override
  String diveComputer_pinEntry_instructionsWithDevice(String deviceName) {
    return 'Prüfen Sie das Display von $deviceName auf den PIN-Code.';
  }

  @override
  String get diveComputer_pinEntry_semanticLabel =>
      'PIN-Code-Eingabe, 4 bis 6 Ziffern';

  @override
  String get diveComputer_pinEntry_title => 'PIN-Code eingeben';

  @override
  String diveComputer_scan_bluetoothSemanticLabel(String name) {
    return 'Bluetooth-Gerät: $name';
  }

  @override
  String get diveComputer_scan_emptyStateInstructions =>
      'Stellen Sie sicher, dass Ihr Tauchcomputer:\n• Eingeschaltet ist\n• Im Bluetooth-Kopplungsmodus ist\n• Sich in der Nähe Ihres Geräts befindet';

  @override
  String get diveComputer_scan_knownBadge => 'Bekannt';

  @override
  String get diveComputer_scan_lookingForDevicesTitle => 'Gerätesuche';

  @override
  String get diveComputer_scan_noUsbDevicesAvailable =>
      'Keine USB-Geräte verfügbar';

  @override
  String get diveComputer_scan_retry => 'Wiederholen';

  @override
  String get diveComputer_scan_scanAgain => 'Erneut suchen';

  @override
  String get diveComputer_scan_scanningStatus => 'Suche nach Tauchcomputern...';

  @override
  String get diveComputer_scan_stopScanning => 'Suche beenden';

  @override
  String get diveComputer_scan_supportedBadge => 'Unterstützt';

  @override
  String get diveComputer_scan_tabBluetooth => 'Bluetooth';

  @override
  String get diveComputer_scan_tabUsb => 'USB-Kabel';

  @override
  String get diveComputer_scan_usbCableLabel => 'USB-Kabel';

  @override
  String diveComputer_scan_usbSemanticLabel(String model) {
    return 'USB-Gerät: $model';
  }

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
      'Übersprungen (Duplikate)';

  @override
  String get diveComputer_summary_title => 'Download abgeschlossen!';

  @override
  String get diveComputer_summary_updated => 'Aktualisiert';

  @override
  String get diveComputer_summary_viewDives => 'Tauchgänge anzeigen';

  @override
  String get diveImport_alreadyImported => 'Bereits importiert';

  @override
  String get diveImport_avgHR => 'Durchschn. HF';

  @override
  String get diveImport_back => 'Zurück';

  @override
  String get diveImport_deselectAll => 'Alle abwählen';

  @override
  String get diveImport_divesImported => 'Tauchgänge importiert';

  @override
  String get diveImport_divesMerged => 'Tauchgänge zusammengeführt';

  @override
  String get diveImport_divesSkipped => 'Tauchgänge übersprungen';

  @override
  String get diveImport_done => 'Fertig';

  @override
  String get diveImport_duration => 'Dauer';

  @override
  String get diveImport_error => 'Fehler';

  @override
  String get diveImport_fit_closeTooltip => 'FIT-Import schließen';

  @override
  String get diveImport_fit_noDivesDescription =>
      'Wählen Sie eine oder mehrere .fit-Dateien, die aus Garmin Connect exportiert oder von einem Garmin Descent-Gerät kopiert wurden.';

  @override
  String get diveImport_fit_noDivesLoaded => 'Keine Tauchgänge geladen';

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
    return '$diveCount $_temp0 aus $fileCount $_temp1 eingelesen ($skippedCount übersprungen)';
  }

  @override
  String get diveImport_fit_parsing => 'Wird eingelesen...';

  @override
  String get diveImport_fit_selectFiles => 'FIT-Dateien auswählen';

  @override
  String get diveImport_fit_title => 'Aus FIT-Datei importieren';

  @override
  String get diveImport_healthkit_accessDescription =>
      'Submersion uses Apple HealthKit to read underwater diving workout data, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get diveImport_healthkit_accessRequired => 'Apple HealthKit';

  @override
  String get diveImport_healthkit_attribution =>
      'Bereitgestellt von Apple HealthKit';

  @override
  String get diveImport_healthkit_closeTooltip =>
      'Apple Watch-Import schließen';

  @override
  String get diveImport_healthkit_dataUsage =>
      'Liest Unterwasser-Tauchaktivitäten aus Apple Health, einschließlich Tiefe, Dauer, Wassertemperatur und Herzfrequenz. Diese Daten werden lokal in Ihrem Tauchlogbuch gespeichert und niemals an Dritte weitergegeben.';

  @override
  String get diveImport_healthkit_dateFrom => 'Von';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return '$label Datumsauswahl';
  }

  @override
  String get diveImport_healthkit_dateTo => 'Bis';

  @override
  String get diveImport_healthkit_fetchDives => 'Tauchgänge abrufen';

  @override
  String get diveImport_healthkit_fetching => 'Wird abgerufen...';

  @override
  String get diveImport_healthkit_grantAccess => 'Weiter';

  @override
  String get diveImport_healthkit_noDivesFound => 'Keine Tauchgänge gefunden';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'Im ausgewählten Zeitraum wurden keine Tauchaktivitäten gefunden.';

  @override
  String get diveImport_healthkit_notAvailable => 'Nicht verfügbar';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'Der Apple-Watch-Import benötigt ein iPhone mit der Health-App.';

  @override
  String get diveImport_healthkit_permissionCheckFailed =>
      'Berechtigungsprüfung fehlgeschlagen';

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
  String get diveImport_possibleDuplicate => 'Mögliches Duplikat';

  @override
  String get diveImport_reviewSelectedDives => 'Ausgewählte Tauchgänge prüfen';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: ', $possibleCount mögliche Duplikate',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: ', $skipCount werden übersprungen',
      zero: '',
    );
    return '$newCount neu$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => 'Alle auswählen';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count ausgewählt';
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
  String get diveImport_step_review => 'Prüfen';

  @override
  String get diveImport_step_select => 'Auswählen';

  @override
  String get diveImport_temp => 'Temp.';

  @override
  String get diveImport_toggleDiveSelection =>
      'Auswahl für Tauchgang umschalten';

  @override
  String get diveImport_uddf_buddies => 'Tauchpartner';

  @override
  String get diveImport_uddf_certifications => 'Zertifizierungen';

  @override
  String get diveImport_uddf_closeTooltip => 'UDDF-Import schließen';

  @override
  String get diveImport_uddf_diveCenters => 'Tauchcenter';

  @override
  String get diveImport_uddf_diveTypes => 'Taucharten';

  @override
  String get diveImport_uddf_dives => 'Tauchgänge';

  @override
  String get diveImport_uddf_duplicate => 'Duplikat';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return '$count Duplikate gefunden und automatisch abgewählt.';
  }

  @override
  String get diveImport_uddf_equipment => 'Ausrüstung';

  @override
  String get diveImport_uddf_equipmentSets => 'Ausrüstungssets';

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
      'Wählen Sie eine .uddf- oder .xml-Datei, die aus einer anderen Tauchlog-Anwendung exportiert wurde.';

  @override
  String get diveImport_uddf_noFileSelected => 'Keine Datei ausgewählt';

  @override
  String get diveImport_uddf_parsing => 'Wird eingelesen...';

  @override
  String get diveImport_uddf_possibleDuplicate => 'Mögliches Duplikat';

  @override
  String get diveImport_uddf_selectFile => 'UDDF-Datei auswählen';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '$selected von $total ausgewählt';
  }

  @override
  String get diveImport_uddf_sites => 'Tauchplätze';

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
  String get diveImport_uddf_tabDives => 'Tauchgänge';

  @override
  String get diveImport_uddf_tabEquipment => 'Ausrüstung';

  @override
  String get diveImport_uddf_tabSets => 'Sets';

  @override
  String get diveImport_uddf_tabSites => 'Plätze';

  @override
  String get diveImport_uddf_tabTags => 'Tags';

  @override
  String get diveImport_uddf_tabTrips => 'Reisen';

  @override
  String get diveImport_uddf_tabTypes => 'Typen';

  @override
  String get diveImport_uddf_tags => 'Tags';

  @override
  String get diveImport_uddf_media => 'Fotos';

  @override
  String get diveImport_uddf_title => 'Aus UDDF importieren';

  @override
  String get diveImport_uddf_toggleDiveSelection =>
      'Auswahl für Tauchgang umschalten';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return 'Auswahl für $name umschalten';
  }

  @override
  String get diveImport_uddf_trips => 'Reisen';

  @override
  String get divePlanner_segmentEditor_addTitle => 'Segment hinzufügen';

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
  String get divePlanner_segmentList_addSegment => 'Segment hinzufügen';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return 'Aufstieg $startDepth -> $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return 'Grundzeit $depth für $minutes min';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return 'Deko $depth für $minutes min';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => 'Segment löschen';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return 'Abstieg $startDepth -> $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => 'Segment bearbeiten';

  @override
  String get divePlanner_segmentList_emptyMessage =>
      'Segmente manuell hinzufügen oder einen Schnellplan erstellen';

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
    return 'Sicherheitsstopp $depth für $minutes min';
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
  String get divePlanner_undo => 'Rückgängig';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'Rock Bottom ist die Mindestgasreserve für einen Notaufstieg bei Luftteilung mit dem Tauchpartner.\n\n- Verwendet erhöhte AMV-Werte (2-3x normal)\n- Geht davon aus, dass beide Taucher eine Flasche nutzen\n- Beinhaltet Sicherheitsstopp wenn aktiviert\n\nDrehen Sie den Tauchgang immer BEVOR Sie Rock Bottom erreichen!';

  @override
  String get gasCalculators_rockBottom_aboutTitle => 'Über Rock Bottom';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired =>
      'Benötigtes Gas für Aufstieg';

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
      'Aufstiegszeit bis zur Oberfläche';

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
      'Höhere AMV-Werte verwenden, um Stress im Notfall zu berücksichtigen';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'Stress-AMV-Werte';

  @override
  String get gasCalculators_rockBottom_tankSize => 'Flaschengröße';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded =>
      'Benötigte Gesamtreserve';

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
  String get gpsLogger_androidNotificationText =>
      'Oberflächen-Track wird aufgezeichnet';

  @override
  String get gpsLogger_androidNotificationTitle => 'Submersion GPS-Logger';

  @override
  String get gpsLogger_deleteTrackMessage =>
      'Entfernt den aufgezeichneten GPS-Track. Bereits auf Tauchgänge übertragene Positionen bleiben erhalten.';

  @override
  String get gpsLogger_deleteTrackTitle => 'Track löschen?';

  @override
  String get gpsLogger_interruptedNotice =>
      'Eine frühere Aufzeichnung wurde unterbrochen. Der Track wurde gespeichert.';

  @override
  String gpsLogger_lastFix(String age, String accuracy) {
    return 'Letzter Fix vor $age ($accuracy)';
  }

  @override
  String get gpsLogger_locationOff => 'Ortungsdienste sind deaktiviert.';

  @override
  String get gpsLogger_matchButton => 'Tauchgänge mit GPS-Logs abgleichen';

  @override
  String gpsLogger_matchResult(int count) {
    return '$count Tauchgänge positioniert';
  }

  @override
  String get gpsLogger_matchResultNone =>
      'Keine Tauchgänge passen zu einem aufgezeichneten Track';

  @override
  String get gpsLogger_noFixYet => 'Warte auf GPS-Fix';

  @override
  String get gpsLogger_noTracks => 'Noch keine GPS-Tracks aufgezeichnet';

  @override
  String get gpsLogger_permissionDenied =>
      'Zur Aufzeichnung eines GPS-Tracks ist die Standortberechtigung erforderlich. Aktiviere sie in den Systemeinstellungen.';

  @override
  String gpsLogger_recordingStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Punkte',
      one: '$count Punkt',
    );
    return 'Aufzeichnung - $_temp0';
  }

  @override
  String get gpsLogger_reviewSites => 'Tauchplatz-Zuordnungen prüfen';

  @override
  String get gpsLogger_startButton => 'Aufzeichnung starten';

  @override
  String get gpsLogger_stopButton => 'Aufzeichnung beenden';

  @override
  String gpsLogger_stripStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Punkte',
      one: '$count Punkt',
    );
    return 'GPS-Track wird aufgezeichnet · $_temp0';
  }

  @override
  String get gpsLogger_summary_tracks => 'Tracks';

  @override
  String get gpsLogger_summary_recordedTime => 'Aufgezeichnete Zeit';

  @override
  String get gpsLogger_summary_divesCovered => 'Erfasste Tauchgänge';

  @override
  String gpsLogger_trackSubtitle(num count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Punkte',
      one: '$count Punkt',
    );
    return '$_temp0, $duration';
  }

  @override
  String gpsLogger_trackSubtitleTrimmed(String duration) {
    return 'Gekürzt, $duration';
  }

  @override
  String get gpsLogger_tracksHeader => 'Aufgezeichnete Tracks';

  @override
  String get gpsTrack_action_trim => 'Zuschneiden...';

  @override
  String get gpsTrack_action_split => 'Teilen...';

  @override
  String get gpsTrack_action_resetTrim => 'Zuschnitt zurücksetzen';

  @override
  String get gpsTrack_edit_applyTrim => 'Zuschnitt übernehmen';

  @override
  String get gpsTrack_edit_confirmSplit => 'Hier teilen';

  @override
  String get gpsTrack_edit_splitWarning =>
      'Beim Teilen entstehen zwei Tracks und das Original wird entfernt. Das kann nicht rückgängig gemacht werden.';

  @override
  String get gpsTrack_edit_cancel => 'Abbrechen';

  @override
  String get gpsTrack_import_action => 'Track importieren...';

  @override
  String get gpsTrack_import_reviewTitle => 'Import prüfen';

  @override
  String get gpsTrack_import_timezone => 'Aufgezeichnet in';

  @override
  String get gpsTrack_import_timezoneHint =>
      'Die Zeiten in der Datei sind UTC. Wähle die Zeitzone der Aufzeichnung, damit sie zu deinen Tauchgängen passt.';

  @override
  String get gpsTrack_import_duplicate =>
      'Dies scheint ein Duplikat eines vorhandenen Tracks zu sein.';

  @override
  String get gpsTrack_import_confirm => 'Importieren';

  @override
  String get gpsTrack_import_csvMapping => 'Spalten zuordnen';

  @override
  String get gpsTrack_import_firstFix => 'Erster Punkt';

  @override
  String gpsTrack_import_fixCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Punkte',
      one: '1 Punkt',
    );
    return '$_temp0';
  }

  @override
  String gpsTrack_import_failed(String reason) {
    return 'Datei konnte nicht gelesen werden: $reason';
  }

  @override
  String get gpsTrack_importError_unsupportedFormat =>
      'Dieser Dateityp wird nicht unterstützt. Importieren Sie eine GPX-, KML-, CSV- oder FIT-Datei.';

  @override
  String get gpsTrack_importError_unreadable =>
      'Diese Datei konnte nicht gelesen werden. Sie ist möglicherweise beschädigt oder unvollständig.';

  @override
  String get gpsTrack_importError_noPositions =>
      'Diese Datei enthält keine GPS-Positionen mit Zeitstempel.';

  @override
  String get gpsTrack_importError_badData =>
      'Diese Datei enthält eine Position oder einen Zeitstempel, die diese App nicht lesen kann.';

  @override
  String get gpsTrack_export_saved => 'Track gespeichert';

  @override
  String get gpsTrack_action_export => 'Exportieren';

  @override
  String get gpsTrack_action_shareGpx => 'Als GPX teilen';

  @override
  String get gpsTrack_action_saveGpx => 'Als GPX speichern...';

  @override
  String get gpsTrack_action_shareKml => 'Als KML teilen';

  @override
  String get gpsTrack_action_saveKml => 'Als KML speichern...';

  @override
  String get gpsTrack_export_failed => 'Export fehlgeschlagen.';

  @override
  String get gpsTrack_map_title => 'Trackkarte';

  @override
  String gpsTrack_map_truncated(int count) {
    return 'Die $count neuesten Tracks werden angezeigt. Grenzen Sie den Datumsfilter ein, um weitere zu sehen.';
  }

  @override
  String get gpsTrack_map_noTracks => 'Keine aufgezeichneten Tracks vorhanden.';

  @override
  String get gpsTrack_map_showMap => 'Karte anzeigen';

  @override
  String get gpsTrack_filter_all => 'Alle Daten';

  @override
  String get gpsTrack_filter_clear => 'Datumsfilter zurücksetzen';

  @override
  String get gpsTrack_inspect_speed => 'Geschwindigkeit';

  @override
  String get gpsTrack_inspect_accuracy => 'Genauigkeit';

  @override
  String get gpsTrack_stats_distance => 'Distanz';

  @override
  String get gpsTrack_stats_duration => 'Dauer';

  @override
  String get gpsTrack_stats_avgSpeed => 'Ø Geschwindigkeit';

  @override
  String get gpsTrack_stats_maxSpeed => 'Max. Geschwindigkeit';

  @override
  String get gpsTrack_stats_fixes => 'Punkte';

  @override
  String get gpsTrack_stats_dives => 'Tauchgänge';

  @override
  String get gpsTrack_colorMode_uniform => 'Einfarbig';

  @override
  String get gpsTrack_colorMode_speed => 'Geschwindigkeit';

  @override
  String get gpsTrack_colorMode_elapsed => 'Zeit';

  @override
  String get gpsTrack_legend_slower => 'Langsamer';

  @override
  String get gpsTrack_legend_faster => 'Schneller';

  @override
  String get gpsTrack_legend_start => 'Start';

  @override
  String get gpsTrack_legend_end => 'Ende';

  @override
  String get gpsTrack_detail_title => 'GPS-Track';

  @override
  String get gpsTrack_detail_notFound =>
      'Dieser Track ist nicht mehr verfügbar.';

  @override
  String get gpsTrack_detail_unreadable =>
      'Track-Daten konnten nicht gelesen werden.';

  @override
  String get gpsTrack_detail_noPoints =>
      'Dieser Track enthält keine aufgezeichneten Positionen.';

  @override
  String get maps_compass_resetLabel =>
      'Kartenausrichtung nach Norden zurücksetzen';

  @override
  String get maps_compass_resetTooltip => 'Norden oben';

  @override
  String get maps_heatMap_hide => 'Heatmap ausblenden';

  @override
  String get maps_heatMap_overlayOff => 'Heatmap-Overlay ist aus';

  @override
  String get maps_depthOverlay_show => 'Tiefen-Overlay anzeigen';

  @override
  String get maps_depthOverlay_hide => 'Tiefen-Overlay ausblenden';

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
  String get maps_offline_clearAll => 'Alle löschen';

  @override
  String get maps_offline_clearAllCache => 'Gesamten Cache löschen';

  @override
  String get maps_offline_clearAllCacheMessage =>
      'Alle heruntergeladenen Kartenregionen und zwischengespeicherten Kacheln löschen?';

  @override
  String get maps_offline_clearAllCacheTitle => 'Gesamten Cache löschen?';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return 'Dies löscht $count Kacheln ($size).';
  }

  @override
  String get maps_offline_created => 'Erstellt';

  @override
  String maps_offline_deleteRegion(Object name) {
    return 'Region $name löschen';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return '\"$name\" und die $count zwischengespeicherten Kacheln löschen?\n\nDies gibt $size Speicherplatz frei.';
  }

  @override
  String get maps_offline_deleteRegionTitle => 'Region löschen?';

  @override
  String get maps_offline_downloadNewRegion => 'Neue Region herunterladen';

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
  String get maps_offline_size => 'Größe';

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
      'Auf der Karte ziehen, um eine Region auszuwählen';

  @override
  String get maps_regionSelector_selectRegion => 'Region auf Karte auswählen';

  @override
  String get maps_regionSelector_selectRegionButton => 'Region auswählen';

  @override
  String get tankPresets_addPreset => 'Flaschenvorlage hinzufügen';

  @override
  String get tankPresets_builtInPresets => 'Integrierte Vorlagen';

  @override
  String get tankPresets_currentDefault => 'Aktueller Standard';

  @override
  String get tankPresets_customPresets => 'Eigene Vorlagen';

  @override
  String get tankPresets_defaultSettings => 'Standardtank';

  @override
  String get tankPresets_defaultSettings_description =>
      'Die mit Stern markierte Vorlage wird als Standardtank beim Erstellen neuer Tauchgänge verwendet.';

  @override
  String tankPresets_deleteDefaultMessage(String name) {
    return 'Möchtest du \"$name\" wirklich löschen? Dies ist deine aktuelle Standardtank-Vorlage und wird auf AL80 zurückgesetzt.';
  }

  @override
  String tankPresets_deleteMessage(Object name) {
    return 'Möchten Sie \"$name\" wirklich löschen?';
  }

  @override
  String get tankPresets_deletePreset => 'Vorlage löschen';

  @override
  String get tankPresets_deleteTitle => 'Flaschenvorlage löschen?';

  @override
  String tankPresets_deleted(Object name) {
    return '\"$name\" gelöscht';
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
    return '- Gaskapazität: $capacity cuft';
  }

  @override
  String get tankPresets_edit_material => 'Material';

  @override
  String get tankPresets_edit_name => 'Name';

  @override
  String get tankPresets_edit_nameHelper =>
      'Ein Name für diese Flaschenvorlage';

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
  String get tankPresets_edit_validPressure => 'Gültigen Druck eingeben';

  @override
  String get tankPresets_edit_validVolume => 'Gültiges Volumen eingeben';

  @override
  String get tankPresets_edit_volume => 'Volumen';

  @override
  String get tankPresets_edit_volumeHelperCuft => 'Gaskapazität (cuft)';

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
    return 'Fehler beim Löschen der Vorlage: $error';
  }

  @override
  String get tankPresets_applyToImports =>
      'Auch auf importierte Tauchgänge anwenden';

  @override
  String get tankPresets_applyToImports_subtitle =>
      'Fehlende Tankdaten bei importierten Tauchgängen mit der Standardvorlage ergänzen';

  @override
  String get tankPresets_new_title => 'Neue Flaschenvorlage';

  @override
  String get tankPresets_noPresets => 'Keine Flaschenvorlagen verfügbar';

  @override
  String get tankPresets_setAsDefault => 'Als Standard festlegen';

  @override
  String get tankPresets_title => 'Flaschenvorlagen';

  @override
  String get tools_gpsLogger_description =>
      'Zeichne deine Position während eines Tauchtags auf und ordne importierte Tauchgänge automatisch GPS-Positionen zu.';

  @override
  String get tools_gpsLogger_subtitle => 'Oberflächen-Track aufzeichnen';

  @override
  String get tools_gpsLogger_title => 'GPS-Logger';

  @override
  String get tools_weight_aluminumImperial =>
      'Auftriebspositiver wenn leer (+4 lbs)';

  @override
  String get tools_weight_aluminumMetric =>
      'Auftriebspositiver wenn leer (+2 kg)';

  @override
  String get tools_weight_bodyWeightOptional => 'Körpergewicht (optional)';

  @override
  String get tools_weight_carbonFiberImperial =>
      'Sehr auftriebspositiv (+7 lbs)';

  @override
  String get tools_weight_carbonFiberMetric => 'Sehr auftriebspositiv (+3 kg)';

  @override
  String get tools_weight_disclaimer =>
      'Dies ist nur eine Schätzung. Führen Sie immer einen Tarierungscheck zu Beginn des Tauchgangs durch und passen Sie bei Bedarf an. Faktoren wie Jacket, persönlicher Auftrieb und Atemverhalten beeinflussen Ihren tatsächlichen Bleibedarf.';

  @override
  String get tools_weight_exposureSuit => 'Tauchanzug';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return '- Gaskapazität: $capacity cuft';
  }

  @override
  String get tools_weight_helperImperial =>
      'Fügt ca. 2 lbs pro 22 lbs über 154 lbs hinzu';

  @override
  String get tools_weight_helperMetric =>
      'Fügt ca. 1 kg pro 10 kg über 70 kg hinzu';

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

  @override
  String get settings_section_dataSources_title => 'Data Sources';

  @override
  String get settings_section_dataSources_subtitle =>
      'Connected services & integrations';

  @override
  String get settings_siteMatch_title => 'Automatische Tauchplatzzuordnung';

  @override
  String get settings_siteMatch_subtitle =>
      'Wie aggressiv heruntergeladene Tauchgänge Tauchplätzen zugeordnet werden';

  @override
  String get settings_siteMatch_strict => 'Streng';

  @override
  String get settings_siteMatch_balanced => 'Ausgewogen';

  @override
  String get settings_siteMatch_relaxed => 'Locker';

  @override
  String get settings_dataSources_header => 'Data Sources';

  @override
  String get settings_dataSources_appleHealth_title => 'Apple Health';

  @override
  String get settings_dataSources_appleHealth_subtitle =>
      'Unterwasser-Tauchdaten';

  @override
  String get settings_dataSources_appleHealth_description =>
      'Submersion reads underwater diving workout data from Apple Health, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get settings_dataSources_appleHealth_dataTypesHeader =>
      'Aus HealthKit gelesene Daten';

  @override
  String get settings_dataSources_appleHealth_dataTypeWorkouts =>
      'Unterwasser-Tauchtrainings - Startzeit, Dauer und Aktivitätsdaten des Tauchgangs';

  @override
  String get settings_dataSources_appleHealth_dataTypeHeartRate =>
      'Herzfrequenz - während Tauchgängen aufgezeichnete Herzfrequenzwerte';

  @override
  String get settings_dataSources_appleHealth_permissionGranted =>
      'HealthKit-Zugriff gewährt';

  @override
  String get settings_dataSources_appleHealth_permissionNotGranted =>
      'HealthKit-Zugriff nicht gewährt';

  @override
  String get settings_dataSources_appleHealth_permissionChecking =>
      'HealthKit-Zugriff wird überprüft...';

  @override
  String get settings_dataSources_appleHealth_importAction =>
      'Import from Apple Watch';

  @override
  String get settings_dataSources_appleHealth_privacy =>
      'Your health data is stored locally and is never shared with third parties.';

  @override
  String get settings_dataSources_appleHealth_poweredBy =>
      'Bereitgestellt von Apple HealthKit';

  @override
  String get settings_dataSources_noSources =>
      'No data source integrations are available on this platform.';

  @override
  String get diveLog_edit_section_environment => 'Umgebung';

  @override
  String get diveLog_edit_subsection_autofill => 'Automatisch ausfüllen';

  @override
  String get diveLog_edit_subsection_weather => 'Wetter';

  @override
  String get diveLog_edit_subsection_diveConditions => 'Tauchbedingungen';

  @override
  String get diveLog_edit_label_windSpeed => 'Windgeschwindigkeit';

  @override
  String get diveLog_edit_label_windDirection => 'Windrichtung';

  @override
  String get diveLog_edit_label_cloudCover => 'Bewölkung';

  @override
  String get diveLog_edit_label_precipitation => 'Niederschlag';

  @override
  String get diveLog_edit_label_humidity => 'Luftfeuchtigkeit';

  @override
  String get diveLog_edit_label_weatherDescription => 'Wetterbeschreibung';

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
  String get diveLog_detail_section_environment => 'Umgebung';

  @override
  String get diveLog_detail_subsection_weather => 'Wetter';

  @override
  String get diveLog_detail_subsection_diveConditions => 'Tauchbedingungen';

  @override
  String get diveLog_detail_label_windSpeed => 'Windgeschwindigkeit';

  @override
  String get diveLog_detail_label_windDirection => 'Windrichtung';

  @override
  String get diveLog_detail_label_cloudCover => 'Bewölkung';

  @override
  String get diveLog_detail_label_precipitation => 'Niederschlag';

  @override
  String get diveLog_detail_label_humidity => 'Luftfeuchtigkeit';

  @override
  String get diveLog_detail_label_weatherDescription => 'Beschreibung';

  @override
  String get diveLog_detail_weatherSourceOpenMeteo => 'via Open-Meteo';

  @override
  String get dropTarget_title => 'Zum Importieren ablegen';

  @override
  String get dropTarget_subtitle =>
      'Loslassen, um den Import-Assistenten zu öffnen';

  @override
  String get dropTarget_error_unsupportedFile => 'Nicht unterstützter Dateityp';

  @override
  String get dropTarget_error_wizardActive =>
      'Aktuellen Import zuerst abschließen';

  @override
  String get dropTarget_error_readFailed => 'Datei konnte nicht gelesen werden';

  @override
  String get enum_cloudCover_clear => 'Klar';

  @override
  String get enum_cloudCover_partlyCloudy => 'Teils bewölkt';

  @override
  String get enum_cloudCover_mostlyCloudy => 'Überwiegend bewölkt';

  @override
  String get enum_cloudCover_overcast => 'Bedeckt';

  @override
  String get enum_precipitation_none => 'Keine';

  @override
  String get enum_precipitation_drizzle => 'Nieselregen';

  @override
  String get enum_precipitation_lightRain => 'Leichter Regen';

  @override
  String get enum_precipitation_rain => 'Regen';

  @override
  String get enum_precipitation_heavyRain => 'Starker Regen';

  @override
  String get enum_precipitation_snow => 'Schnee';

  @override
  String get enum_precipitation_sleet => 'Graupel';

  @override
  String get enum_precipitation_hail => 'Hagel';

  @override
  String get columnConfig_title => 'Tauchdetails-Listenfelder';

  @override
  String get columnConfig_viewMode => 'Ansichtsmodus';

  @override
  String get columnConfig_visibleColumns => 'Sichtbare Spalten';

  @override
  String get columnConfig_availableFields => 'Verfügbare Felder';

  @override
  String get columnConfig_extraFields => 'Zusätzliche Felder';

  @override
  String get columnConfig_extraFields_description =>
      'Unter dem Hauptkarteninhalt angezeigt';

  @override
  String get columnConfig_slotAssignments => 'Slot-Zuweisungen';

  @override
  String get columnConfig_resetToDefault => 'Auf Standard zurücksetzen';

  @override
  String get columnConfig_preset => 'Voreinstellung';

  @override
  String get columnConfig_presetSaveAs => 'Speichern unter';

  @override
  String get columnConfig_presetName => 'Name der Voreinstellung';

  @override
  String get columnConfig_presetNameHint => 'z. B. Technisches Tauchen';

  @override
  String get columnConfig_presetSave => 'Speichern';

  @override
  String get columnConfig_presetCancel => 'Abbrechen';

  @override
  String get columnConfig_columns => 'Spalten';

  @override
  String get columnConfig_done => 'Fertig';

  @override
  String get settings_appearance_columnConfig => 'Tauchdetails-Listenfelder';

  @override
  String get settings_appearance_columnConfig_subtitle =>
      'Angezeigte Felder in Tauchlistenansichten anpassen';

  @override
  String get diveField_category_core => 'Grundlagen';

  @override
  String get diveField_category_environment => 'Umgebung';

  @override
  String get diveField_category_gas => 'Gas';

  @override
  String get diveField_category_tank => 'Flasche';

  @override
  String get diveField_category_weight => 'Gewicht';

  @override
  String get diveField_category_equipment => 'Ausrüstung';

  @override
  String get diveField_category_deco => 'Dekompression';

  @override
  String get diveField_category_physiology => 'Physiologie';

  @override
  String get diveField_category_rebreather => 'Rebreather';

  @override
  String get diveField_category_people => 'Personen';

  @override
  String get diveField_category_location => 'Ort';

  @override
  String get diveField_category_trip => 'Reise';

  @override
  String get diveField_category_rating => 'Bewertung';

  @override
  String get diveField_category_metadata => 'Metadaten';

  @override
  String get listViewMode_table => 'Tabelle';

  @override
  String get settings_appearance_general => 'Allgemein';

  @override
  String get settings_appearance_sections => 'Bereiche';

  @override
  String get settings_appearance_colorAccents => 'Farbakzente';

  @override
  String get settings_appearance_accentNavIcons => 'Farbige Navigationssymbole';

  @override
  String get settings_appearance_accentNavIcons_subtitle =>
      'Hauptmenü-Symbole in der Farbe des jeweiligen Bereichs einfärben';

  @override
  String get settings_appearance_accentSectionHeaders =>
      'Farbige Bereichsüberschriften';

  @override
  String get settings_appearance_accentSectionHeaders_subtitle =>
      'Farbiges Bereichssymbol neben Seitentiteln anzeigen';

  @override
  String get settings_appearance_accentListIcons => 'Farbige Listensymbole';

  @override
  String get settings_appearance_accentListIcons_subtitle =>
      'Symbole in Listen und Einstellungsseiten einfärben';

  @override
  String get settings_appearance_showDetailsPane => 'Detailbereich anzeigen';

  @override
  String get settings_appearance_showDetailsPane_subtitle =>
      'Detailbereich neben der Tabelle anzeigen';

  @override
  String get settings_appearance_showProfilePanel =>
      'Profilbereich in Tabellenansicht anzeigen';

  @override
  String get settings_appearance_showProfilePanel_subtitle =>
      'Tauchprofildiagramm standardmäßig über der Tabelle anzeigen';

  @override
  String get settings_appearance_mapStyle => 'Kartenstil';

  @override
  String get settings_appearance_mapStyle_openStreetMap => 'Straßenkarte';

  @override
  String get settings_appearance_mapStyle_openTopoMap => 'Topografisch';

  @override
  String get settings_appearance_mapStyle_esriSatellite => 'Satellit';

  @override
  String get common_action_reparse => 'Neu auswerten';

  @override
  String get diveComputer_detail_reparseAllButton =>
      'Alle Tauchgänge neu auswerten';

  @override
  String get diveComputer_detail_reparseAllTitle =>
      'Alle Tauchgänge neu auswerten';

  @override
  String diveComputer_detail_reparseAllMessage(int count) {
    return 'Den Tauchgang-Parser für $count Tauchgänge mit gespeicherten Rohdaten erneut ausführen. Dies aktualisiert Profil- und Sensordaten, behält aber Notizen, Tauchplätze, Tauchpartner und andere Bearbeitungen bei.';
  }

  @override
  String diveComputer_detail_reparseAllProgress(int count) {
    return '$count Tauchgänge werden neu ausgewertet...';
  }

  @override
  String diveComputer_detail_reparseAllSuccess(int count) {
    return '$count Tauchgänge erfolgreich neu ausgewertet';
  }

  @override
  String diveComputer_detail_reparseAllPartial(
    int succeeded,
    int total,
    int failed,
  ) {
    return '$succeeded von $total Tauchgängen neu ausgewertet. $failed fehlgeschlagen.';
  }

  @override
  String diveComputer_detail_reparseRawDataCount(int count) {
    return '$count Tauchgänge mit Rohdaten';
  }

  @override
  String diveComputer_detail_reparseRawDataCountWithout(
    int count,
    int without,
  ) {
    return '$count Tauchgänge mit Rohdaten ($without ohne)';
  }

  @override
  String get diveLog_detail_menu_reparseRawData => 'Rohdaten neu auswerten';

  @override
  String get diveLog_detail_reparseSuccess =>
      'Tauchgang erfolgreich neu ausgewertet';

  @override
  String get diveLog_detail_reparseProfilePreserved =>
      'Quelldetails aktualisiert. Dieser Tauchgang wurde aus mehreren Tauchgängen zusammengeführt, daher blieb sein Profil unverändert.';

  @override
  String diveLog_detail_reparseFailed(String error) {
    return 'Neu-Auswertung fehlgeschlagen: $error';
  }

  @override
  String get universalImport_label_replaceSource => 'Quelle ersetzen';

  @override
  String get universalImport_label_replaceSourceSubtitle =>
      'Vom selben Computer aktualisieren';

  @override
  String get universalImport_title_importOptions => 'Importoptionen';

  @override
  String get universalImport_label_options => 'Optionen';

  @override
  String get universalImport_label_retainDiveNumbers =>
      'Tauchgangsnummern aus Quelle beibehalten';

  @override
  String get universalImport_label_retainDiveNumbersSubtitle =>
      'Tauchgangsnummern aus der importierten Datei verwenden, statt automatisch zuzuweisen';

  @override
  String get universalImport_title_successImported => 'Erfolgreich importiert';

  @override
  String get universalImport_title_successUpdated => 'Erfolgreich aktualisiert';

  @override
  String get universalImport_title_successConsolidated =>
      'Erfolgreich konsolidiert';

  @override
  String get universalImport_title_noDivesImported =>
      'Keine Tauchgänge importiert';

  @override
  String get universalImport_label_allDivesSkipped =>
      'Alle Tauchgänge wurden übersprungen.';

  @override
  String get universalImport_label_replacedSourceData => 'Quelldaten ersetzt';

  @override
  String get universalImport_label_consolidated => 'Konsolidiert';

  @override
  String get universalImport_label_photosAttached => 'Fotos angehängt';

  @override
  String get universalImport_label_photosUnmatched =>
      'Fotos keinem Tauchgang zugeordnet';

  @override
  String get common_label_shareWithAllProfiles =>
      'Mit allen Taucherprofilen teilen';

  @override
  String get settings_shareByDefault_title =>
      'Neue Orte und Reisen standardmäßig teilen';

  @override
  String get settings_shareAllSites_title => 'Alle meine Orte teilen';

  @override
  String get settings_shareAllTrips_title => 'Alle meine Reisen teilen';

  @override
  String settings_shareAllSites_confirm(int count) {
    return 'Alle $count deiner Orte für jedes Taucherprofil in dieser App sichtbar machen? Du kannst einzelne Orte später wieder privat machen.';
  }

  @override
  String settings_shareAllTrips_confirm(int count) {
    return 'Alle $count deiner Reisen für jedes Taucherprofil in dieser App sichtbar machen? Du kannst einzelne Reisen später wieder privat machen.';
  }

  @override
  String settings_shareAllSites_snackbar(int count) {
    return '$count Orte mit allen Taucherprofilen geteilt.';
  }

  @override
  String settings_shareAllTrips_snackbar(int count) {
    return '$count Reisen mit allen Taucherprofilen geteilt.';
  }

  @override
  String get settings_shareAll_noneToShare => 'Nichts zu teilen.';

  @override
  String get settings_sharedData_sectionTitle => 'Geteilte Daten';

  @override
  String get settings_sharedData_sectionSubtitle =>
      'Orte und Reisen über Profile hinweg teilen';

  @override
  String get common_action_unshare => 'Teilen aufheben';

  @override
  String get trips_unshareConfirm_title => 'Diese Reise nicht mehr teilen?';

  @override
  String trips_unshareConfirm_body(String name) {
    return '„$name\" wird aus den Ansichten anderer Taucherprofile entfernt. Du kannst die Reise später wieder teilen.';
  }

  @override
  String get sites_unshareConfirm_title => 'Diesen Ort nicht mehr teilen?';

  @override
  String sites_unshareConfirm_body(String name) {
    return '„$name\" wird aus den Ansichten anderer Taucherprofile entfernt. Du kannst den Ort später wieder teilen.';
  }

  @override
  String get trips_deleteShared_title => 'Geteilte Reise löschen?';

  @override
  String trips_deleteShared_body(String name) {
    return '„$name\" wird mit anderen Taucherprofilen geteilt. Löschen entfernt die Reise für alle.';
  }

  @override
  String get sites_deleteShared_title => 'Geteilten Ort löschen?';

  @override
  String sites_deleteShared_body(String name) {
    return '„$name\" wird mit anderen Taucherprofilen geteilt. Löschen entfernt den Ort für alle.';
  }

  @override
  String divers_delete_reassigned_snackbar(int trips, int sites, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      trips,
      locale: localeName,
      other: 'geteilte Reisen',
      one: 'geteilte Reise',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sites,
      locale: localeName,
      other: 'geteilte Orte',
      one: 'geteilter Ort',
    );
    return 'Taucher gelöscht. $trips $_temp0 und $sites $_temp1 wurden $name zugewiesen.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_title =>
      'Doppelte Taucherprofile';

  @override
  String get settings_cloudSync_duplicateDivers_description =>
      'Die Synchronisierung hat mehr als ein Profil mit demselben Namen gefunden. Das passiert normalerweise, wenn jedes Gerät sein eigenes Profil erstellt hat, bevor die Synchronisierung erfolgte. Beim Zusammenführen werden alle Tauchgänge und Daten in ein Profil verschoben.';

  @override
  String settings_cloudSync_duplicateDivers_groupLabel(String name, int count) {
    return '$name ($count Profile)';
  }

  @override
  String get settings_cloudSync_duplicateDivers_mergeButton => 'Zusammenführen';

  @override
  String get settings_cloudSync_duplicateDivers_confirmTitle =>
      'Taucherprofile zusammenführen?';

  @override
  String settings_cloudSync_duplicateDivers_confirmBody(
    int count,
    String name,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doppelten Profilen',
      one: 'einem doppelten Profil',
    );
    return 'Alle Tauchgänge, Zertifizierungen, Ausrüstung und andere Daten aus $_temp0 werden auf \"$name\" verschoben. Dies kann nicht automatisch rückgängig gemacht werden.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_confirmCancel => 'Abbrechen';

  @override
  String get settings_cloudSync_duplicateDivers_confirmAction =>
      'Zusammenführen';

  @override
  String settings_cloudSync_duplicateDivers_successSnack(String name) {
    return 'Zusammengeführt in $name';
  }

  @override
  String settings_cloudSync_duplicateDivers_failureSnack(String error) {
    return 'Zusammenführung fehlgeschlagen: $error';
  }

  @override
  String get settings_cloudSync_duplicateDivers_undo => 'Rückgängig';

  @override
  String get divers_edit_priorExperienceSection => 'Frühere Erfahrung';

  @override
  String get divers_edit_priorExperienceHelp =>
      'Tauchgänge und Zeit aus der Zeit vor deiner Nutzung von Submersion.';

  @override
  String get divers_edit_priorDivesLabel => 'Frühere Tauchgänge';

  @override
  String get divers_edit_priorHoursLabel => 'Frühere Stunden';

  @override
  String get divers_edit_priorMinutesLabel => 'Minuten';

  @override
  String get divers_edit_divingSinceLabel => 'Taucht seit';

  @override
  String get divers_edit_divingSinceNotSet => 'Nicht festgelegt';

  @override
  String get divers_edit_clearDivingSinceTooltip => 'Taucht seit löschen';

  @override
  String get divers_edit_priorInvalidNumber => 'Gib eine gültige Zahl ein';

  @override
  String statistics_priorBreakdown(String logged, String prior) {
    return '$logged erfasst + $prior früher';
  }

  @override
  String statistics_divingSince(int year) {
    return 'Taucht seit $year';
  }

  @override
  String get db_location_choose_volume => 'Speicherort wählen';

  @override
  String get db_location_internal => 'Interner Speicher';

  @override
  String get db_location_sd_card => 'SD-Karte';

  @override
  String get db_location_external_note =>
      'Dateien hier werden entfernt, wenn Sie die App deinstallieren.';

  @override
  String get db_location_backup_note =>
      'Android kann die Datenbank nicht aus einem cloud-synchronisierten Ordner betreiben. Um eine Kopie in Dropbox, Nextcloud oder Google Drive zu behalten, legen Sie unter Sicherung und Wiederherstellung einen Sicherungsort fest.';

  @override
  String diveLog_bulkEdit_membership_onAll(int count) {
    return 'auf allen $count';
  }

  @override
  String diveLog_bulkEdit_membership_onSome(int count, int total) {
    return 'auf $count von $total';
  }

  @override
  String diveLog_bulkEdit_membership_adding(int total) {
    return 'wird zu allen $total hinzugefügt';
  }

  @override
  String get diveLog_bulkEdit_membership_removing => 'wird von allen entfernt';

  @override
  String get diveLog_bulkEdit_membership_empty =>
      'Noch keine Elemente bei den ausgewählten Tauchgängen';

  @override
  String get settings_mediaStorage_entry_title => 'Medienspeicher';

  @override
  String get settings_mediaStorage_entry_subtitle =>
      'Foto- und Video-Originale im eigenen Cloud-Speicher ablegen';

  @override
  String get settings_mediaStorage_status_notConfigured =>
      'Kein Medienspeicher mit diesem Gerät verbunden';

  @override
  String settings_mediaStorage_status_connected(String hint) {
    return 'Verbunden mit $hint';
  }

  @override
  String get settings_mediaStorage_test_success => 'Verbindung erfolgreich';

  @override
  String get settings_mediaStorage_saved => 'Medienspeicher verbunden';

  @override
  String get settings_mediaStorage_action_disconnect => 'Trennen';

  @override
  String get settings_mediaStorage_disconnect_confirm_title =>
      'Medienspeicher trennen?';

  @override
  String get settings_mediaStorage_disconnect_confirm_body =>
      'Dieses Gerät lädt keine Medien mehr hoch oder herunter. In Ihrem Bucket wird nichts gelöscht.';

  @override
  String get settings_mediaStorage_action_copyFromSync =>
      'Einstellungen von Sync übernehmen';

  @override
  String get settings_mediaStorage_transfers_title => 'Übertragungen';

  @override
  String get settings_mediaStorage_transfers_entry => 'Übertragungen anzeigen';

  @override
  String get settings_mediaStorage_transfers_empty => 'Keine Übertragungen';

  @override
  String get settings_mediaStorage_transfers_retry => 'Erneut versuchen';

  @override
  String get settings_mediaStorage_transfers_clearCompleted =>
      'Abgeschlossene entfernen';

  @override
  String get settings_mediaStorage_transfers_state_pending => 'Wartend';

  @override
  String get settings_mediaStorage_transfers_state_transferring =>
      'Wird hochgeladen';

  @override
  String get settings_mediaStorage_transfers_state_deleting =>
      'Wird aus der Cloud entfernt';

  @override
  String get settings_mediaStorage_transfers_state_done => 'Fertig';

  @override
  String get settings_mediaStorage_transfers_state_failed => 'Fehlgeschlagen';

  @override
  String settings_mediaStorage_transfers_queued(int count) {
    return '$count in Warteschlange';
  }

  @override
  String settings_mediaStorage_transfers_waitingRetry(int count) {
    return '$count warten auf Wiederholung';
  }

  @override
  String get settings_mediaStorage_verify_action => 'Bibliothek überprüfen';

  @override
  String get settings_mediaStorage_verify_running =>
      'Medienbibliothek wird überprüft...';

  @override
  String settings_mediaStorage_verify_summary(
    int checked,
    int removed,
    int repaired,
    int aborted,
  ) {
    return '$checked Objekte geprüft: $removed verwaiste entfernt, $repaired Reparaturen eingereiht, $aborted veraltete Uploads abgebrochen';
  }

  @override
  String get settings_mediaStorage_backfill_action =>
      'Vorhandene Bibliothek hochladen';

  @override
  String settings_mediaStorage_backfill_enqueued(int count) {
    return '$count Uploads eingereiht';
  }

  @override
  String get settings_mediaStorage_policy_autoUpload =>
      'Fotos automatisch hochladen';

  @override
  String get settings_mediaStorage_policy_photosOnCellular =>
      'Fotos über Mobilfunk hochladen';

  @override
  String get settings_mediaStorage_provider_label => 'Anbieter';

  @override
  String get settings_mediaStorage_connect_dropbox_hint =>
      'Verwendet Ihre Dropbox-Verbindung aus der Cloud-Synchronisierung. Medien werden im Dropbox-App-Ordner gespeichert.';

  @override
  String get settings_mediaStorage_connect_gdrive_hint =>
      'Meldet sich mit Google an. Medien werden im privaten Drive-Bereich dieser App gespeichert.';

  @override
  String get settings_mediaStorage_connect_icloud_hint =>
      'Medien werden im iCloud-Container dieser App gespeichert und über Ihre Apple-ID synchronisiert.';

  @override
  String settings_mediaStorage_connect_action(String provider) {
    return '$provider verbinden';
  }

  @override
  String get bodyWeight_addEntry => 'Messung hinzufügen';

  @override
  String get bodyWeight_dateLabel => 'Datum';

  @override
  String get bodyWeight_deleteTooltip => 'Eintrag löschen';

  @override
  String get bodyWeight_heightLabel => 'Größe (cm)';

  @override
  String get bodyWeight_heightFeetLabel => 'Größe (ft)';

  @override
  String get bodyWeight_heightInchesLabel => 'Zoll';

  @override
  String bodyWeight_weightLabel(String unit) {
    return 'Gewicht ($unit)';
  }

  @override
  String diveLog_edit_weightFeedback_amount(String unit) {
    return 'Um etwa wie viel ($unit)';
  }

  @override
  String get diveLog_edit_weightFeedback_correct => 'Passte gut';

  @override
  String get diveLog_edit_weightFeedback_label => 'Wie war deine Bleimenge?';

  @override
  String get diveLog_edit_weightFeedback_over => 'Zu viel Blei';

  @override
  String get diveLog_edit_weightFeedback_under => 'Zu wenig Blei';

  @override
  String get diverProfile_bodyWeight_empty => 'Nicht erfasst';

  @override
  String get diverProfile_bodyWeight_title => 'Körpergewicht';

  @override
  String get equipment_edit_advanced_title => 'Erweitert';

  @override
  String get equipment_edit_buoyancyHint_exposure =>
      'Positiv: wie stark es auftreibt';

  @override
  String get equipment_edit_buoyancyHint_generic => 'Negativ, wenn es sinkt';

  @override
  String get equipment_edit_buoyancyHint_tank =>
      'Leer lassen - Flaschen nutzen eigene Spezifikationen';

  @override
  String equipment_edit_buoyancyLabel(String unit) {
    return 'Auftrieb ($unit)';
  }

  @override
  String equipment_edit_dryWeightLabel(String unit) {
    return 'Trockengewicht ($unit)';
  }

  @override
  String equipment_edit_liftCapacityLabel(String unit) {
    return 'Auftriebskapazität ($unit)';
  }

  @override
  String get equipment_edit_liftCapacityHint =>
      'Nennauftrieb von Wing oder Jacket';

  @override
  String get planner_gearWeights_accept => 'Als geplantes Blei übernehmen';

  @override
  String get planner_gearWeights_addGear => 'Ausrüstung hinzufügen';

  @override
  String get planner_gearWeights_empty =>
      'Ausrüstung hinzufügen, um dein Blei vorherzusagen';

  @override
  String planner_gearWeights_planned(String weight) {
    return 'Geplant: $weight';
  }

  @override
  String planner_gearWeights_predicted(String weight) {
    return 'Vorhergesagt: $weight';
  }

  @override
  String get planner_gearWeights_title => 'Ausrüstung & Blei';

  @override
  String get planner_gearWeights_useSet => 'Set verwenden';

  @override
  String get tools_weight_addGear => 'Ausrüstung hinzufügen';

  @override
  String get tools_weight_addTank => 'Flasche hinzufügen';

  @override
  String tools_weight_basedOnDives(int count) {
    return 'Basierend auf $count geloggten Tauchgängen';
  }

  @override
  String get tools_weight_breakdownTitle => 'So wurde das berechnet';

  @override
  String get tools_weight_confidence_high => 'Hohe Zuverlässigkeit';

  @override
  String get tools_weight_confidence_low =>
      'Geringe Zuverlässigkeit - Schätzung';

  @override
  String get tools_weight_confidence_medium => 'Mittlere Zuverlässigkeit';

  @override
  String tools_weight_deltaVsPrevious(String delta) {
    return '$delta ggü. voriger Ausrüstung';
  }

  @override
  String get tools_weight_noGear =>
      'Füge die geplante Ausrüstung hinzu, um die Vorhersage zu personalisieren.';

  @override
  String get tools_weight_personalTerm => 'Persönliche Basis';

  @override
  String get tools_weight_placementTitle => 'Empfohlene Verteilung';

  @override
  String get tools_weight_predictedWeight => 'Vorhergesagtes Blei';

  @override
  String get tools_weight_saveToProfile => 'Gewicht im Profil speichern';

  @override
  String get tools_weight_source_measured => 'aus deinen Tauchgängen gemessen';

  @override
  String get tools_weight_source_physics => 'Physik';

  @override
  String get tools_weight_source_typeDefault => 'Standardschätzung';

  @override
  String get tools_weight_source_userSpec => 'aus deinen Ausrüstungsdaten';

  @override
  String get tools_weight_tanks => 'Flaschen';

  @override
  String get tools_weight_useSet => 'Set verwenden';

  @override
  String get tools_weight_waterTerm => 'Wasserart';

  @override
  String get dive3d_previewTitle => '3D-Ansicht';

  @override
  String get dive3d_previewHint => 'Tippen, um in 3D zu erkunden';

  @override
  String get dive3d_resetView => 'Ansicht zurücksetzen';

  @override
  String get dive3d_zoomIn => 'Vergrößern';

  @override
  String get dive3d_zoomOut => 'Verkleinern';

  @override
  String get dive3d_play => 'Wiedergabe';

  @override
  String get dive3d_pause => 'Pause';

  @override
  String get dive3d_overlays => 'Überlagerungen';

  @override
  String get dive3d_overlay_strata => 'Temperaturschichten';

  @override
  String get dive3d_overlay_ceiling => 'Deko-Ceiling';

  @override
  String get dive3d_overlay_curtain => 'Tiefenvorhang';

  @override
  String get dive3d_overlay_markers => 'Markierungen';

  @override
  String get dive3d_seascape_overlay_paths => 'Tauchgangspfade';

  @override
  String get dive3d_seascape_overlay_contours => 'Tiefenlinien';

  @override
  String get dive3d_seascape_overlay_walls => 'Steilwände';

  @override
  String get dive3d_overlay_water => 'Wasseroberfläche';

  @override
  String get dive3d_seascape_legend_land => 'Land';

  @override
  String get dive3d_seascape_appearance => 'Geländedarstellung';

  @override
  String get dive3d_seascape_chartView => 'Kartenansicht';

  @override
  String get dive3d_seascape_orbitView => '3D-Ansicht';

  @override
  String get dive3d_seascape_appearance_surface => 'Geländeoberfläche';

  @override
  String get dive3d_seascape_appearance_surfaceDepth => 'Tiefenfarben';

  @override
  String get dive3d_seascape_appearance_surfaceImagery => 'Kartenbilder';

  @override
  String get dive3d_seascape_appearance_surfaceBlend => 'Mischung';

  @override
  String get siteFeature_type_wreck => 'Wrack';

  @override
  String get siteFeature_type_mooring => 'Anlegeboje';

  @override
  String get siteFeature_type_entry => 'Einstieg';

  @override
  String get siteFeature_type_exit => 'Ausstieg';

  @override
  String get siteFeature_type_swimThrough => 'Durchschwimmstelle';

  @override
  String get siteFeature_type_hazard => 'Gefahr';

  @override
  String get siteFeature_type_current => 'Strömung';

  @override
  String get siteFeature_sectionTitle => 'Merkmale';

  @override
  String get siteFeature_addAction => 'Merkmal hinzufügen';

  @override
  String get siteFeature_placeHint =>
      'Auf die Karte tippen, um das Merkmal zu platzieren';

  @override
  String get siteFeature_addTitle => 'Merkmal hinzufügen';

  @override
  String get siteFeature_editTitle => 'Merkmal bearbeiten';

  @override
  String get siteFeature_field_name => 'Name';

  @override
  String get siteFeature_field_bearing => 'Peilung (°)';

  @override
  String get siteFeature_field_depth => 'Tiefe';

  @override
  String get siteFeature_field_notes => 'Notizen';

  @override
  String get siteFeature_deleteAction => 'Löschen';

  @override
  String siteFeature_deleteConfirm(String name) {
    return '$name löschen?';
  }

  @override
  String get siteScape_mode2d => 'Karte';

  @override
  String get siteScape_mode3d => '3D';

  @override
  String get dive3d_seascape_appearance_rampRange =>
      'Farbtiefenbereich begrenzen';

  @override
  String get dive3d_seascape_appearance_rampMax => 'Dunkelste Farbe bei';

  @override
  String get dive3d_seascape_appearance_banded => 'Gestufter Verlauf';

  @override
  String get dive3d_seascape_appearance_contours => 'Tiefenlinien';

  @override
  String get dive3d_seascape_appearance_contourAuto => 'Automatisch';

  @override
  String get dive3d_seascape_appearance_contourCustom => 'Benutzerdefiniert';

  @override
  String get dive3d_seascape_appearance_addLevel => 'Linie hinzufügen';

  @override
  String get dive3d_seascape_appearance_defaultColor => 'Standard';

  @override
  String get dive3d_seascape_appearance_wallAngle => 'Steilwand-Winkel';

  @override
  String get dive3d_seascape_appearance_wallAngleNote =>
      'Bathymetriezellen mitteln das Gefälle in ihrem Inneren, echte Wände wirken daher flacher. Deutlich unter 45 Grad bleiben.';

  @override
  String get dive3d_seascape_siteTitle => 'Standort-Seelandschaft';

  @override
  String dive3d_seascape_seafloorSource(String source, String resolution) {
    return 'Meeresboden: $source (~$resolution m)';
  }

  @override
  String get dive3d_seascape_noCoordinates =>
      'Dieser Tauchplatz hat keine GPS-Koordinaten';

  @override
  String get dive3d_seascape_noData =>
      'Keine Bathymetrie für diesen Ort verfügbar';

  @override
  String dive3d_seascape_axis_distance(String unitSymbol) {
    return 'Entfernung ($unitSymbol)';
  }

  @override
  String get settings_about_bathymetryCredit =>
      'Bathymetrie-Daten: GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022';

  @override
  String get dive3d_metric_depth => 'Tiefe';

  @override
  String get dive3d_metric_temperature => 'Temp';

  @override
  String get dive3d_metric_ascentRate => 'Aufstieg';

  @override
  String get dive3d_metric_ppO2 => 'ppO2';

  @override
  String get dive3d_metric_cns => 'ZNS';

  @override
  String get dive3d_metric_heartRate => 'HF';

  @override
  String get dive3d_metric_tankPressure => 'Druck';

  @override
  String get dive3d_zAxis => 'Z-Achse';

  @override
  String get dive3d_zAxis_none => 'Keine';

  @override
  String get dive3d_overlay_shadows => 'Wandschatten';

  @override
  String get dive3d_metric_tts => 'TTS';

  @override
  String dive3d_axis_depth(String unitSymbol) {
    return 'Tiefe ($unitSymbol)';
  }

  @override
  String get dive3d_axis_time => 'Laufzeit (min)';

  @override
  String get dive3d_pose_menu => 'Kamera';

  @override
  String get dive3d_pose_default => 'Standardansicht';

  @override
  String get dive3d_pose_front => 'Vorne (Tiefe vs. Zeit)';

  @override
  String get dive3d_pose_side => 'Seite (Tiefe vs. Messwert)';

  @override
  String get dive3d_pose_top => 'Oben (Messwert vs. Zeit)';

  @override
  String get dive3d_readout_runTime => 'Laufzeit';

  @override
  String get dive3d_readout_ceiling => 'Ceiling';

  @override
  String dive3d_readout_tank(int n) {
    return 'Flasche $n';
  }

  @override
  String get dive3d_scene_dive => 'Tauchgang';

  @override
  String get dive3d_scene_tissue => 'Gewebe';

  @override
  String get dive3d_tissue_gasCombined => 'Kombiniert';

  @override
  String get dive3d_tissue_gasN2 => 'N2';

  @override
  String get dive3d_tissue_gasHe => 'He';

  @override
  String get dive3d_tissue_colorMValue => '% M-Wert';

  @override
  String get dive3d_tissue_colorAbsolute => 'Sättigung';

  @override
  String get dive3d_tissue_controlling => 'Führend';

  @override
  String get dive3d_tissue_surfaceInterval => 'Oberflächenpause';

  @override
  String get dive3d_career_title => '3D-Verlauf';

  @override
  String get dive3d_career_colorRecency => 'Aktualität';

  @override
  String get dive3d_career_colorDepth => 'Tiefe';

  @override
  String get dive3d_career_empty => 'Keine Tauchgänge mit Profilen';

  @override
  String get dive3d_spatial_title => '3D-Unterwasserwelt';

  @override
  String get dive3d_spatial_estimatedPath =>
      'Geschätzter Pfad (Koppelnavigation)';

  @override
  String get dive3d_spatial_synthesizedSeafloor =>
      'Synthetisierter Meeresboden';

  @override
  String get dive3d_spatial_noPath =>
      'Nicht genug Daten zur Pfadrekonstruktion';

  @override
  String get dive3d_tissue_legendHeight => 'Höhe & Farbe: % des M-Wert-Limits';

  @override
  String get dive3d_tissue_legendLimit => 'Rote Ebene = Deko-Limit';

  @override
  String get dive3d_tissue_legendAxes =>
      'Links→rechts: Zeit · Vorn→hinten: schnelle→langsame Gewebe';

  @override
  String get dive3d_tissue_legendDepth => 'Blaue Kurve: deine Tiefe';

  @override
  String get dive3d_tissue_onGassing => 'Aufsättigung';

  @override
  String get dive3d_tissue_offGassing => 'Entsättigung';

  @override
  String dive3d_tissue_tooltipCompartment(int number) {
    return 'Komp. $number';
  }

  @override
  String dive3d_tissue_tooltipHalfTime(int minutes) {
    return '$minutes min N2';
  }

  @override
  String dive3d_tissue_tooltipSaturation(int percent) {
    return 'Sättigung $percent%';
  }

  @override
  String dive3d_tissue_tooltipProgress(int percent) {
    return '$percent% des Tauchgangs';
  }

  @override
  String get dive3d_tissue_stateEquilibrium => 'Gleichgewicht';

  @override
  String get dive3d_tissue_statePastMValue => 'Über M-Wert';

  @override
  String get dive3d_tissue_axisTime => 'Zeit';

  @override
  String get dive3d_tissue_axisSaturation => 'Sättigung %';

  @override
  String get dive3d_tissue_axisCompartment => 'Kompartiment';

  @override
  String get dive3d_compare_computers_title => 'Computer vergleichen';

  @override
  String get dive3d_compare_dives_title => 'Tauchgänge vergleichen';

  @override
  String get dive3d_scene_computers => 'Computer';

  @override
  String get dive3d_compare_layout_sideBySide => 'Nebeneinander';

  @override
  String get dive3d_compare_layout_overlay => 'Überlagern';

  @override
  String get dive3d_compare_empty =>
      'Mindestens 2 Profile mit Tiefendaten zum Vergleichen nötig';

  @override
  String dive3d_compare_showing(Object shown, Object total) {
    return '$shown von $total werden angezeigt';
  }

  @override
  String get dive3d_compare_setReference => 'Als Referenz festlegen';

  @override
  String get diveLog_selection_tooltip_compare3d => 'In 3D vergleichen';

  @override
  String get diveLog_sources_compareIn3d => 'In 3D vergleichen';

  @override
  String get settings_setup_pendingTitle =>
      'Einrichtung dieses Geräts abschließen';

  @override
  String settings_setup_mediaStoreAttach(String hint) {
    return 'Medienspeicher verbinden ($hint)';
  }

  @override
  String settings_setup_accountSignIn(String label) {
    return 'Bei $label anmelden';
  }

  @override
  String get settings_setup_dismiss => 'Ausblenden';

  @override
  String get settings_photosMedia_title => 'Fotos & Medien';

  @override
  String get settings_photosMedia_subtitle => 'Quellen, Speicher & Konten';

  @override
  String get settings_photosMedia_sourcesHeader => 'Woher Fotos kommen';

  @override
  String get settings_photosMedia_storageHeader =>
      'Wo Kopien aufbewahrt werden';

  @override
  String get settings_photosMedia_accountsHeader => 'Konten';

  @override
  String get settings_photosMedia_displayHeader => 'Anzeige';

  @override
  String get settings_photosMedia_guidedSetup => 'Geführte Einrichtung';

  @override
  String get settings_photosMedia_photoSources_title =>
      'Fotobibliothek & Quellen';

  @override
  String get settings_photosMedia_photoSources_subtitle =>
      'Galerie, Dateien und Importoptionen';

  @override
  String get settings_photosMedia_networkSources_title => 'Netzwerkquellen';

  @override
  String get settings_photosMedia_networkSources_subtitle =>
      'URLs und Manifest-Feeds (erweitert)';

  @override
  String get settings_connectedAccounts_title => 'Verbundene Konten';

  @override
  String get settings_connectedAccounts_subtitle =>
      'Cloud- und Dienst-Anmeldungen';

  @override
  String get settings_connectedAccounts_empty => 'Noch keine Konten verbunden';

  @override
  String get settings_connectedAccounts_status_signedIn => 'Angemeldet';

  @override
  String get settings_connectedAccounts_status_needsSignIn =>
      'Anmeldung erforderlich';

  @override
  String get settings_connectedAccounts_status_unavailable =>
      'Auf diesem Gerät nicht verfügbar';

  @override
  String get settings_connectedAccounts_disconnectDevice =>
      'Auf diesem Gerät abmelden';

  @override
  String get settings_connectedAccounts_removeFromLibrary =>
      'Aus der Bibliothek entfernen';

  @override
  String get settings_connectedAccounts_removeConfirmTitle =>
      'Konto entfernen?';

  @override
  String get settings_connectedAccounts_removeConfirmBody =>
      'Das Konto wird von allen synchronisierten Geräten entfernt. Auf anderen Geräten gespeicherte Zugangsdaten werden nicht gelöscht.';

  @override
  String get settings_setupGuide_title => 'Fotos & Medien einrichten';

  @override
  String get settings_setupGuide_intro =>
      'Verbinde die Quellen deiner Fotos und wo Kopien aufbewahrt werden. Du kannst dies jederzeit erneut ausführen.';

  @override
  String get settings_setupGuide_stepSources => 'Fotoquellen';

  @override
  String get settings_setupGuide_stepSources_desc =>
      'Fotos aus deiner Fotobibliothek, Dateien oder Lightroom anhängen.';

  @override
  String get settings_setupGuide_stepStorage => 'Medienspeicher';

  @override
  String get settings_setupGuide_stepStorage_desc =>
      'Bewahre Kopien deiner Fotos in deiner eigenen Cloud auf, damit jedes Gerät sie anzeigen kann.';

  @override
  String get settings_setupGuide_stepSync => 'Cloud-Synchronisierung';

  @override
  String get settings_setupGuide_stepSync_desc =>
      'Tauchdaten zwischen Geräten synchronisieren.';

  @override
  String get settings_setupGuide_statusDone => 'Eingerichtet';

  @override
  String get settings_setupGuide_statusTodo => 'Nicht eingerichtet';

  @override
  String get settings_setupGuide_open => 'Öffnen';

  @override
  String get settings_connectedAccounts_loadError =>
      'Konten konnten nicht geladen werden';

  @override
  String get media_unavailablePlaceholder_volumeOffline =>
      'Volume nicht eingebunden';

  @override
  String get media_unavailablePlaceholder_stillFetching =>
      'Wird noch geladen. Zum Wiederholen tippen.';

  @override
  String get media_unavailablePlaceholder_accessDenied =>
      'Kein Zugriff auf die Fotomediathek';

  @override
  String get attrLabel_size => 'Größe';

  @override
  String get attrLabel_thickness_mm => 'Dicke (mm)';

  @override
  String get attrLabel_suit_style => 'Anzugtyp';

  @override
  String get attrLabel_shell_material => 'Außenmaterial';

  @override
  String get attrLabel_seal_type => 'Manschettentyp';

  @override
  String get attrLabel_volume_l => 'Volumen';

  @override
  String get attrLabel_working_pressure_bar => 'Betriebsdruck';

  @override
  String get attrLabel_tank_material => 'Material';

  @override
  String get attrLabel_valve_type => 'Ventil';

  @override
  String get attrLabel_tank_identifier => 'Kennung';

  @override
  String get attrLabel_last_visual_inspection => 'Letzte Sichtprüfung';

  @override
  String get attrLabel_last_hydro_test => 'Letzte Druckprüfung';

  @override
  String get attrLabel_connection => 'Anschluss';

  @override
  String get attrLabel_cold_water_rated => 'Kaltwassergeeignet';

  @override
  String get attrLabel_bcd_style => 'Bauart';

  @override
  String get attrLabel_lift_capacity_kg => 'Auftriebskapazität';

  @override
  String get attrLabel_heel_type => 'Fersentyp';

  @override
  String get attrLabel_blade_style => 'Blatt';

  @override
  String get attrLabel_mount => 'Befestigung';

  @override
  String get attrLabel_connectivity => 'Konnektivität';

  @override
  String get attrLabel_lens_config => 'Glas';

  @override
  String get attrLabel_prescription => 'Optische Gläser';

  @override
  String get attrLabel_weight_style => 'Bauart';

  @override
  String get attrLabel_lumens => 'Lumen';

  @override
  String get attrLabel_beam_type => 'Lichtkegel';

  @override
  String get attrLabel_depth_rating_m => 'Tiefenbeständigkeit';

  @override
  String get attrLabel_smb_type => 'Typ';

  @override
  String get attrLabel_length_m => 'Länge';

  @override
  String get attrLabel_reel_type => 'Typ';

  @override
  String get attrLabel_line_length_m => 'Leinenlänge';

  @override
  String get attrLabel_blade_material => 'Klingenmaterial';

  @override
  String get attrLabel_tip_type => 'Spitze';

  @override
  String get attrLabel_glove_type => 'Typ';

  @override
  String get attrLabel_sole_type => 'Sohle';

  @override
  String get attrLabel_buoyancy_kg => 'Auftrieb';

  @override
  String get attrLabel_dry_weight_kg => 'Trockengewicht';

  @override
  String get attrLabel_unit_type => 'Gerätetyp';

  @override
  String get attrLabel_mount_configuration => 'Montage';

  @override
  String get attrLabel_scrubber_type => 'Absorbertyp';

  @override
  String get attrLabel_scrubber_duration_h => 'Absorberstandzeit (h)';

  @override
  String get attrLabel_o2_cell_count => 'O2-Zellen';

  @override
  String get attrLabel_diluent_cylinder_l => 'Diluent-Flasche';

  @override
  String get attrLabel_o2_cylinder_l => 'O2-Flasche';

  @override
  String get attrLabel_dpv_style => 'Bauart';

  @override
  String get attrLabel_burn_time_h => 'Laufzeit';

  @override
  String get attrLabel_battery_type => 'Akku';

  @override
  String get attrLabel_battery_capacity_wh => 'Akkukapazität (Wh)';

  @override
  String get attrLabel_motor_type => 'Motor';

  @override
  String get attrLabel_speed_mps => 'Höchstgeschwindigkeit';

  @override
  String get attrChoice_unit_type_eccr => 'Elektronischer CCR (eCCR)';

  @override
  String get attrChoice_unit_type_mccr => 'Manueller CCR (mCCR)';

  @override
  String get attrChoice_unit_type_hccr => 'Hybrid-CCR (hCCR)';

  @override
  String get attrChoice_unit_type_scr_cmf => 'SCR - konstanter Massenstrom';

  @override
  String get attrChoice_unit_type_scr_pascr => 'SCR - passive Zugabe';

  @override
  String get attrChoice_unit_type_scr_escr => 'SCR - elektronisch geregelt';

  @override
  String get attrChoice_mount_configuration_back => 'Rückenmontage';

  @override
  String get attrChoice_mount_configuration_chest => 'Brustmontage';

  @override
  String get attrChoice_mount_configuration_sidemount => 'Seitenmontage';

  @override
  String get attrChoice_scrubber_type_axial => 'Axial';

  @override
  String get attrChoice_scrubber_type_radial => 'Radial';

  @override
  String get attrChoice_suit_style_full => 'Vollanzug';

  @override
  String get attrChoice_suit_style_shorty => 'Shorty';

  @override
  String get attrChoice_suit_style_two_piece => 'Zweiteiler';

  @override
  String get attrChoice_suit_style_semi_dry => 'Halbtrocken';

  @override
  String get attrChoice_shell_material_trilaminate => 'Trilaminat';

  @override
  String get attrChoice_shell_material_neoprene => 'Neopren';

  @override
  String get attrChoice_shell_material_crushed_neoprene =>
      'Komprimiertes Neopren';

  @override
  String get attrChoice_shell_material_vulcanized_rubber =>
      'Vulkanisierter Gummi';

  @override
  String get attrChoice_seal_type_latex => 'Latex';

  @override
  String get attrChoice_seal_type_silicone => 'Silikon';

  @override
  String get attrChoice_seal_type_neoprene => 'Neopren';

  @override
  String get attrChoice_tank_material_aluminum => 'Aluminium';

  @override
  String get attrChoice_tank_material_steel => 'Stahl';

  @override
  String get attrChoice_tank_material_carbon_composite => 'Carbon-Verbund';

  @override
  String get attrChoice_valve_type_din => 'DIN';

  @override
  String get attrChoice_valve_type_yoke => 'Bügel (INT)';

  @override
  String get attrChoice_valve_type_convertible => 'Umrüstbar';

  @override
  String get attrChoice_connection_din => 'DIN';

  @override
  String get attrChoice_connection_yoke => 'Bügel (INT)';

  @override
  String get attrChoice_bcd_style_jacket => 'Jacket';

  @override
  String get attrChoice_bcd_style_back_inflate => 'Back-Inflate';

  @override
  String get attrChoice_bcd_style_wing => 'Wing';

  @override
  String get attrChoice_bcd_style_sidemount => 'Sidemount';

  @override
  String get attrChoice_heel_type_open_heel => 'Offene Ferse';

  @override
  String get attrChoice_heel_type_full_foot => 'Geschlossene Ferse';

  @override
  String get attrChoice_blade_style_paddle => 'Paddel';

  @override
  String get attrChoice_blade_style_split => 'Split';

  @override
  String get attrChoice_blade_style_vented => 'Mit Öffnungen';

  @override
  String get attrChoice_mount_wrist => 'Handgelenk';

  @override
  String get attrChoice_mount_console => 'Konsole';

  @override
  String get attrChoice_mount_hud => 'HUD';

  @override
  String get attrChoice_connectivity_ble => 'Bluetooth (BLE)';

  @override
  String get attrChoice_connectivity_usb => 'USB';

  @override
  String get attrChoice_connectivity_infrared => 'Infrarot';

  @override
  String get attrChoice_connectivity_none => 'Keine';

  @override
  String get attrChoice_lens_config_single => 'Einglas';

  @override
  String get attrChoice_lens_config_twin => 'Zweiglas';

  @override
  String get attrChoice_lens_config_frameless => 'Rahmenlos';

  @override
  String get attrChoice_weight_style_belt => 'Gürtel';

  @override
  String get attrChoice_weight_style_integrated => 'Integriert';

  @override
  String get attrChoice_weight_style_trim => 'Trimm';

  @override
  String get attrChoice_weight_style_ankle => 'Knöchel';

  @override
  String get attrChoice_beam_type_spot => 'Spot';

  @override
  String get attrChoice_beam_type_flood => 'Flood';

  @override
  String get attrChoice_beam_type_adjustable => 'Verstellbar';

  @override
  String get attrChoice_smb_type_open => 'Offen';

  @override
  String get attrChoice_smb_type_closed => 'Geschlossen';

  @override
  String get attrChoice_reel_type_spool => 'Spool';

  @override
  String get attrChoice_reel_type_ratchet => 'Ratschenrolle';

  @override
  String get attrChoice_blade_material_stainless => 'Edelstahl';

  @override
  String get attrChoice_blade_material_titanium => 'Titan';

  @override
  String get attrChoice_tip_type_pointed => 'Spitz';

  @override
  String get attrChoice_tip_type_blunt => 'Stumpf';

  @override
  String get attrChoice_tip_type_line_cutter => 'Leinenschneider';

  @override
  String get attrChoice_glove_type_five_finger => 'Fünffinger';

  @override
  String get attrChoice_glove_type_mitt => 'Fäustling';

  @override
  String get attrChoice_glove_type_dry => 'Trocken';

  @override
  String get attrChoice_sole_type_hard => 'Feste Sohle';

  @override
  String get attrChoice_sole_type_soft => 'Weiche Sohle';

  @override
  String get attrChoice_dpv_style_tow_behind => 'Zum Ziehen';

  @override
  String get attrChoice_dpv_style_ride_on => 'Zum Aufsitzen';

  @override
  String get attrChoice_dpv_style_handheld => 'Handgeführt';

  @override
  String get attrChoice_battery_type_lithium_ion => 'Lithium-Ionen';

  @override
  String get attrChoice_battery_type_nimh => 'NiMH';

  @override
  String get attrChoice_battery_type_lead_acid => 'Blei-Säure';

  @override
  String get attrChoice_motor_type_brushless => 'Bürstenlos';

  @override
  String get attrChoice_motor_type_brushed => 'Mit Bürsten';

  @override
  String get equipment_edit_customFieldsTitle => 'Benutzerdefinierte Felder';

  @override
  String get equipment_edit_addCustomField =>
      'Benutzerdefiniertes Feld hinzufügen';

  @override
  String get attr_flagYes => 'Ja';

  @override
  String get attr_flagNo => 'Nein';

  @override
  String get equipment_edit_invalidThickness => 'Format: 5, 5/4 oder 7/5/3';

  @override
  String get statistics_progression_divesBySuitThickness_title =>
      'Tauchgänge nach Anzugdicke';

  @override
  String get statistics_progression_divesBySuitThickness_subtitle =>
      'Primäre Anzugdicke über deine Tauchgänge';

  @override
  String get statistics_progression_divesBySuitThickness_empty =>
      'Keine Tauchgänge mit erfasster Anzugdicke';

  @override
  String get statistics_progression_divesBySuitThickness_error =>
      'Anzugdicken-Daten konnten nicht geladen werden';

  @override
  String get diveLog_filter_sectionSuitThickness => 'Anzugdicke (mm)';

  @override
  String get diveLog_filter_thicknessMin => 'Min';

  @override
  String get diveLog_filter_thicknessMax => 'Max';

  @override
  String get safetySettings_noFlyHeader => 'Fliegen nach dem Tauchen';

  @override
  String get safetySettings_noFlyPreset_standard => 'Standard (12/18/24 h)';

  @override
  String get safetySettings_noFlyPreset_strict => 'Streng (18/24/48 h)';

  @override
  String get safetySettings_noFlyPreset_subtitle =>
      'Richtwerte nach einem einzelnen Nullzeit-Tauchgang, Wiederholungstauchgängen und Deko-Tauchgängen';

  @override
  String get flightWindow_closed => 'Kein Tauchen mehr vor deinem Flug';

  @override
  String get flightWindow_conflict =>
      'Deine Flugverbotszeit reicht über deinen Abflug hinaus';

  @override
  String flightWindow_departs(String time) {
    return 'Abflug $time';
  }

  @override
  String flightWindow_openTitle(String remaining) {
    return 'Verbleibende Tauchzeit: $remaining';
  }

  @override
  String flightWindow_surfaceBy(String time) {
    return 'Auftauchen bis $time';
  }

  @override
  String safetyHub_noFly_active_title(String remaining) {
    return 'Flugverbot: noch $remaining';
  }

  @override
  String safetyHub_noFly_until(String time) {
    return 'Bis $time';
  }

  @override
  String get safetyHub_noFly_clear_title => 'Keine Flugeinschränkung';

  @override
  String get safetyHub_noFly_clear_subtitle => 'Keine aktive Flugbeschränkung';

  @override
  String safetyHub_noFly_category_single(int hours) {
    return 'Nach einem einzelnen Nullzeit-Tauchgang: $hours h Richtwert';
  }

  @override
  String safetyHub_noFly_category_repetitive(int hours) {
    return 'Nach Wiederholungstauchgängen: $hours h Richtwert';
  }

  @override
  String safetyHub_noFly_category_deco(int hours) {
    return 'Nach einem Deko-Tauchgang: $hours h Richtwert';
  }

  @override
  String get safetyHub_noFly_disclaimer =>
      'DAN/UHMS-Richtwerte ab dem letzten Tauchgang. Kein Ersatz für die Flugverbotszeit Ihres Tauchcomputers.';

  @override
  String get diveLog_detail_altitudeMismatch_title =>
      'Tauchplatz liegt in Höhenlage';

  @override
  String get diveLog_detail_altitudeMismatch_subtitle =>
      'Für diesen Platz ist eine Höhe hinterlegt, der Tauchgang hat jedoch keine, daher ging die Deko-Analyse von Meereshöhe aus. Höhe des Tauchgangs setzen, um dies zu korrigieren.';

  @override
  String diveLog_detail_sacVolumeHint(String unit) {
    return 'Flaschenvolumen eintragen, um den AMV in $unit/min anzuzeigen';
  }

  @override
  String safetyHub_alert_noFly(String remaining) {
    return 'Flugverbot: noch $remaining';
  }

  @override
  String get emergencyCard_title => 'Notfall';

  @override
  String emergencyCard_callDan(String name) {
    return '$name anrufen';
  }

  @override
  String get emergencyCard_callDan_subtitle =>
      'Taucher-Notfallhotline. Zuerst anrufen: sie koordiniert Evakuierung und Kammerzuweisung.';

  @override
  String emergencyCard_ems(String number) {
    return 'Örtlicher Notruf: $number';
  }

  @override
  String get emergencyCard_diverSection => 'Taucher';

  @override
  String emergencyCard_bloodType(String value) {
    return 'Blutgruppe: $value';
  }

  @override
  String emergencyCard_allergies(String value) {
    return 'Allergien: $value';
  }

  @override
  String emergencyCard_medications(String value) {
    return 'Medikamente: $value';
  }

  @override
  String get emergencyCard_contactsSection => 'Notfallkontakte';

  @override
  String get emergencyCard_insuranceSection => 'Tauchversicherung';

  @override
  String emergencyCard_insurancePolicy(String number) {
    return 'Police $number';
  }

  @override
  String get emergencyCard_chambersSection => 'Druckkammern';

  @override
  String get emergencyCard_chambersNote =>
      'Verfügbarkeit ändert sich. Immer zuerst die Taucher-Notfallhotline zur Zuweisung anrufen.';

  @override
  String emergencyCard_chamberVerified(String date) {
    return 'Angaben geprüft $date';
  }

  @override
  String get emergencyCard_chambersNearby => 'Nächstgelegene Druckkammern';

  @override
  String emergencyCard_chamberViewAll(int count) {
    return 'Alle $count Druckkammern anzeigen';
  }

  @override
  String get emergencyCard_chambersNoneNearby =>
      'Keine Druckkammer in Reichweite gelistet. Rufen Sie die Notfall-Hotline für Taucher an: Sie vermittelt Ihnen die nächste Einrichtung, die Sie behandeln kann.';

  @override
  String get emergencyCard_chamberCapability_divingEmergency =>
      'Behandelt Tauchunfälle';

  @override
  String get emergencyCard_chamberCapability_hyperbaricUnit =>
      'Klinische Druckkammer';

  @override
  String get emergencyCard_chamberCapability_elective =>
      'Nur elektive Therapie';

  @override
  String get emergencyCard_chamberCapability_unknown =>
      'Leistungsumfang unbestätigt';

  @override
  String get emergencyCard_chamberAvailability_h24 => '24 Std.';

  @override
  String get emergencyCard_chamberAvailability_onCall => 'Rufbereitschaft';

  @override
  String get emergencyCard_chamberAvailability_businessHours =>
      'Geschäftszeiten';

  @override
  String get emergencyCard_chamberUnverified =>
      'Nicht mit der Einrichtung bestätigt';

  @override
  String get chambersDirectory_title => 'Druckkammern';

  @override
  String get chambersDirectory_search => 'Nach Name, Stadt oder Land suchen';

  @override
  String get chambersDirectory_empty =>
      'Keine Druckkammer entspricht dieser Suche.';

  @override
  String chambersDirectory_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Druckkammern',
      one: '1 Druckkammer',
    );
    return '$_temp0';
  }

  @override
  String get emergencyCard_hideChamber => 'Ausblenden';

  @override
  String get emergencyCard_chamberHidden => 'Kammer ausgeblendet';

  @override
  String get emergencyCard_undo => 'Rückgängig';

  @override
  String get emergencyCard_addChamber => 'Kammer hinzufügen';

  @override
  String get emergencyCard_deleteChamber => 'Löschen';

  @override
  String emergencyCard_regionLabel(String region) {
    return 'Region: $region';
  }

  @override
  String get emergencyCard_regionUnknown =>
      'Region unbekannt - weltweite Hotline wird verwendet';

  @override
  String get emergencyCard_noDiverData =>
      'Keine Taucherprofildaten. Notfallkontakte, medizinische Daten und Versicherung im Taucherprofil hinterlegen.';

  @override
  String get addChamber_title => 'Kammer hinzufügen';

  @override
  String get addChamber_name => 'Name';

  @override
  String get addChamber_country => 'Ländercode (z. B. DE)';

  @override
  String get addChamber_city => 'Stadt';

  @override
  String get addChamber_phone => 'Telefon';

  @override
  String get addChamber_notes => 'Notizen';

  @override
  String get addChamber_save => 'Speichern';

  @override
  String get addChamber_nameRequired => 'Name ist erforderlich';

  @override
  String get addChamber_countryRequired => 'Ländercode ist erforderlich';

  @override
  String get addChamber_phoneRequired => 'Telefonnummer ist erforderlich';

  @override
  String get safetyHub_emergencyCardLink => 'Notfallkarte';

  @override
  String get safetyHub_emergencyCardLink_subtitle =>
      'Offline: Hotline, Notruf, Kammern, deine medizinischen und Versicherungsdaten';

  @override
  String get dashboard_quickAction_emergency => 'Notfallkarte';

  @override
  String get incidents_title => 'Beinahe-Unfall-Log';

  @override
  String get incidents_empty =>
      'Keine Beinahe-Unfälle erfasst. Festzuhalten, was beinahe schiefging - ohne Wertung - macht Muster sichtbar, bevor daraus Unfälle werden.';

  @override
  String get incidents_add => 'Beinahe-Unfall erfassen';

  @override
  String get incidents_linkedDive => 'Mit einem Tauchgang verknüpft';

  @override
  String get incidents_delete_confirm =>
      'Diesen Beinahe-Unfall-Bericht löschen?';

  @override
  String get incidents_notFound => 'Beinahe-Unfall-Bericht nicht gefunden';

  @override
  String get incidentEdit_title_new => 'Beinahe-Unfall erfassen';

  @override
  String get incidentEdit_title_edit => 'Beinahe-Unfall bearbeiten';

  @override
  String get incidentEdit_category => 'Kategorie';

  @override
  String get incidentEdit_severity => 'Schweregrad';

  @override
  String get incidentEdit_severity_minor => 'Gering';

  @override
  String get incidentEdit_severity_moderate => 'Mittel';

  @override
  String get incidentEdit_severity_serious => 'Ernst';

  @override
  String get incidentEdit_date => 'Zeitpunkt';

  @override
  String get incidentEdit_narrative => 'Was ist passiert';

  @override
  String get incidentEdit_narrative_hint =>
      'Nur die Fakten, in eigenen Worten. Das bleibt privat.';

  @override
  String get incidentEdit_narrative_required =>
      'Beschreiben Sie, was passiert ist';

  @override
  String get incidentEdit_contributingFactors =>
      'Was dazu beigetragen hat (optional)';

  @override
  String get incidentEdit_lessonsLearned =>
      'Was beim nächsten Mal helfen würde (optional)';

  @override
  String get incidentEdit_save => 'Speichern';

  @override
  String get incidentEdit_privacyNote =>
      'Beinahe-Unfall-Berichte synchronisieren sich zwischen deinen Geräten und sind in Backups enthalten, aber niemals in Exporten oder geteilten Logbuchseiten.';

  @override
  String get incidentCategory_buoyancy => 'Tarierung';

  @override
  String get incidentCategory_gasSupply => 'Gasversorgung';

  @override
  String get incidentCategory_equipment => 'Ausrüstung';

  @override
  String get incidentCategory_buddySeparation => 'Buddy-Trennung';

  @override
  String get incidentCategory_marineLife => 'Meereslebewesen';

  @override
  String get incidentCategory_boatSurface => 'Boot / Oberfläche';

  @override
  String get incidentCategory_medical => 'Medizinisch';

  @override
  String get incidentCategory_planning => 'Planung';

  @override
  String get incidentCategory_other => 'Sonstiges';

  @override
  String get safetyHub_incidentsLink => 'Beinahe-Unfall-Log';

  @override
  String get safetyHub_incidentsLink_subtitle =>
      'Private, nicht wertende Vorfallnotizen';

  @override
  String get diveLog_detail_menu_logNearMiss => 'Beinahe-Unfall erfassen';

  @override
  String diveLog_detail_linkedIncidents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Beinahe-Unfälle mit diesem Tauchgang verknüpft',
      one: '1 Beinahe-Unfall mit diesem Tauchgang verknüpft',
    );
    return '$_temp0';
  }

  @override
  String get planning_card_noFly_subtitle =>
      'Richtwert-Countdown ab deinen letzten Tauchgängen';

  @override
  String get settings_section_safety_title => 'Sicherheit';

  @override
  String get settings_section_safety_subtitle =>
      'Überprüfungsregeln & Fliegen nach dem Tauchen';

  @override
  String get settings_section_security_title => 'App-Sicherheit';

  @override
  String get settings_section_security_subtitle =>
      'App-Sperre & Datenbankverschlüsselung';

  @override
  String get settings_security_appLock => 'App-Sperre';

  @override
  String get settings_security_appLock_subtitle =>
      'Passwort oder Biometrie zum Öffnen der App erforderlich';

  @override
  String get settings_security_biometrics => 'Mit Biometrie entsperren';

  @override
  String get settings_security_autoLock => 'Automatisch sperren';

  @override
  String get settings_security_autoLock_immediately => 'Sofort';

  @override
  String settings_security_autoLock_minutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Nach $minutes Minuten',
      one: 'Nach 1 Minute',
    );
    return '$_temp0';
  }

  @override
  String get settings_security_autoLock_never => 'Nie';

  @override
  String get settings_security_encryption => 'Datenbank verschlüsseln';

  @override
  String get settings_security_encryption_subtitle =>
      'Schützen Sie Ihre Tauchlog-Datei mit Verschlüsselung im Ruhezustand. Die Verschlüsselung kann die Leistung beeinträchtigen.';

  @override
  String get settings_security_encryption_progress_backup =>
      'Sicherheitskopie wird erstellt...';

  @override
  String get settings_security_encryption_progress_encrypt =>
      'Datenbank wird verschlüsselt...';

  @override
  String get settings_security_encryption_progress_decrypt =>
      'Datenbank wird entschlüsselt...';

  @override
  String get settings_security_encryption_progress_reopen =>
      'Datenbank wird neu geöffnet...';

  @override
  String get settings_security_changePassword => 'Passwort ändern';

  @override
  String get settings_security_regenerateRecovery =>
      'Neuer Wiederherstellungscode';

  @override
  String get settings_security_setPassword => 'App-Passwort festlegen';

  @override
  String get settings_security_password => 'Passwort';

  @override
  String get settings_security_confirmPassword => 'Passwort bestätigen';

  @override
  String get settings_security_currentPassword => 'Aktuelles Passwort';

  @override
  String get settings_security_newPassword => 'Neues Passwort';

  @override
  String get settings_security_passwordTooShort =>
      'Das Passwort muss mindestens 4 Zeichen lang sein.';

  @override
  String get settings_security_passwordMismatch =>
      'Die Passwörter stimmen nicht überein.';

  @override
  String get settings_security_wrongPassword => 'Falsches Passwort.';

  @override
  String get settings_security_recoveryCode_title =>
      'Ihr Wiederherstellungscode';

  @override
  String get settings_security_recoveryCode_explain =>
      'Notieren Sie diesen Code und bewahren Sie ihn sicher auf. Er ist die einzige Möglichkeit, die App zu entsperren, falls Sie Ihr Passwort vergessen, und ersetzt jeden früheren Wiederherstellungscode.';

  @override
  String get settings_security_recoveryCode_savedConfirm =>
      'Ich habe meinen Wiederherstellungscode gespeichert';

  @override
  String get settings_security_disableBlockedByEncryption_title =>
      'Verschlüsselung ist aktiv';

  @override
  String get settings_security_disableBlockedByEncryption_body =>
      'Deaktivieren Sie zuerst die Datenbankverschlüsselung, bevor Sie die App-Sperre ausschalten. Die verschlüsselte Datenbank benötigt Zugangsdaten.';

  @override
  String get settings_security_enableEncryption_title =>
      'Datenbank verschlüsseln?';

  @override
  String get settings_security_enableEncryption_body =>
      'Zuerst wird eine Sicherheitskopie erstellt, dann wird die Datenbankdatei direkt neu verschlüsselt. Bei großen Tauchlogs kann das eine Weile dauern. Die Verschlüsselung kann die Leistung beeinträchtigen.';

  @override
  String get settings_security_disableEncryption_title =>
      'Verschlüsselung ausschalten?';

  @override
  String get settings_security_disableEncryption_body =>
      'Die Datenbankdatei wird wieder unverschlüsselt auf der Festplatte gespeichert.';

  @override
  String get settings_security_turnOffAppLock_title =>
      'App-Sperre ausschalten?';

  @override
  String get settings_security_turnOffAppLock_body =>
      'Die App öffnet sich künftig ohne Passwortabfrage.';

  @override
  String get settings_security_unlock_title => 'Passwort eingeben';

  @override
  String get settings_security_cancel => 'Abbrechen';

  @override
  String get settings_security_continue => 'Weiter';

  @override
  String get settings_security_done => 'Fertig';

  @override
  String get settings_security_turnOff => 'Ausschalten';

  @override
  String get dataQuality_inbox_title => 'Datenqualität';

  @override
  String get dataQuality_badge_tooltip => 'Datenqualitätsprüfung';

  @override
  String get dataQuality_scan_start => 'Bibliothek scannen';

  @override
  String dataQuality_scan_progress(int done, int total) {
    return '$done von $total Tauchgängen geprüft';
  }

  @override
  String get dataQuality_scan_cancel => 'Abbrechen';

  @override
  String dataQuality_scan_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scan abgeschlossen - $count Elemente zu prüfen',
      one: 'Scan abgeschlossen - 1 Element zu prüfen',
      zero: 'Scan abgeschlossen - keine neuen Auffälligkeiten',
    );
    return '$_temp0';
  }

  @override
  String dataQuality_scan_errors(int count) {
    return '$count Tauchgänge konnten nicht vollständig geprüft werden';
  }

  @override
  String dataQuality_lastScan(String when) {
    return 'Letzter Scan: $when';
  }

  @override
  String get dataQuality_neverScanned =>
      'Dein Logbuch wurde noch nicht gescannt';

  @override
  String get dataQuality_empty_title => 'Alles in Ordnung';

  @override
  String get dataQuality_empty_subtitle =>
      'Keine Auffälligkeiten bei der Datenqualität. Scanne deine Bibliothek, um importierte Tauchgänge auf Probleme zu prüfen.';

  @override
  String get dataQuality_banner_newChecks =>
      'Neue Qualitätsprüfungen sind verfügbar';

  @override
  String get dataQuality_banner_rescan => 'Erneut scannen';

  @override
  String get dataQuality_action_dismiss => 'Verwerfen';

  @override
  String get dataQuality_action_dismissFiltered => 'Alle angezeigten verwerfen';

  @override
  String get dataQuality_action_goToDive => 'Zum Tauchgang';

  @override
  String get dataQuality_action_undo => 'Rückgängig';

  @override
  String get dataQuality_repair_applied => 'Korrektur angewendet';

  @override
  String get dataQuality_repair_noChange =>
      'Hier gibt es nichts zu korrigieren';

  @override
  String get dataQuality_repair_needsReview =>
      'Keine automatische Korrektur. Öffne den Tauchgang, um das zu beheben.';

  @override
  String get dataQuality_repair_failed => 'Korrektur fehlgeschlagen';

  @override
  String get dataQuality_chip_all => 'Alle';

  @override
  String get dataQuality_chip_time => 'Zeit';

  @override
  String get dataQuality_chip_profile => 'Profil';

  @override
  String get dataQuality_chip_gas => 'Gas';

  @override
  String get dataQuality_chip_tanks => 'Flaschen';

  @override
  String get dataQuality_chip_duplicates => 'Duplikate';

  @override
  String get dataQuality_chip_sources => 'Quellen';

  @override
  String get dataQuality_detector_clock_offset => 'Uhr & Zeitzone';

  @override
  String get dataQuality_detector_duplicate => 'Wahrscheinliches Duplikat';

  @override
  String get dataQuality_detector_split_pair => 'Versehentliche Aufteilung';

  @override
  String get dataQuality_detector_sample_gap => 'Lücken in den Messpunkten';

  @override
  String get dataQuality_detector_depth_spike => 'Tiefenausreißer';

  @override
  String get dataQuality_detector_impossible_rate => 'Unmögliche Rate';

  @override
  String get dataQuality_detector_temp_anomaly => 'Temperaturanomalie';

  @override
  String get dataQuality_detector_pressure_anomaly => 'Druckanomalie';

  @override
  String get dataQuality_detector_gas_mod => 'Gas/MOD-Widerspruch';

  @override
  String get dataQuality_detector_tank_assignment => 'Falsche Flasche';

  @override
  String get dataQuality_detector_source_conflict => 'Widersprüchliche Quellen';

  @override
  String dataQuality_msg_clock_future(String date) {
    return 'Tauchgang liegt in der Zukunft ($date)';
  }

  @override
  String dataQuality_msg_clock_ancient(String date) {
    return 'Tauchgang ist vor 1950 datiert ($date)';
  }

  @override
  String dataQuality_msg_clock_offset(int hours) {
    return 'Eine Quellenuhr weicht um $hours Stunden ab';
  }

  @override
  String dataQuality_msg_clock_overlap(int minutes) {
    return 'Überschneidet einen anderen Tauchgang um $minutes Min.';
  }

  @override
  String dataQuality_msg_duplicate(int percent, int minutes) {
    return '$percent % Übereinstimmung mit einem Tauchgang im Abstand von $minutes Min.';
  }

  @override
  String dataQuality_msg_split(int minutes) {
    return 'Derselbe Computer wurde nach einem Oberflächenintervall von $minutes Min. fortgesetzt';
  }

  @override
  String dataQuality_msg_gap(int count, String longest) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Lücken in den Messpunkten',
      one: '1 Lücke in den Messpunkten',
    );
    return '$_temp0, längste $longest';
  }

  @override
  String dataQuality_msg_spike(String depth, String time) {
    return 'Tiefenausreißer auf $depth um $time';
  }

  @override
  String dataQuality_msg_negativeDepth(int count) {
    return '$count negative Tiefenmesspunkte';
  }

  @override
  String dataQuality_msg_maxDepthMismatch(String stored, String profile) {
    return 'Erfasste maximale Tiefe $stored, aber das Profil zeigt $profile';
  }

  @override
  String dataQuality_msg_rate(String rate, int seconds) {
    return 'Vertikalrate von $rate über $seconds s gehalten';
  }

  @override
  String dataQuality_msg_tempRange(String min, String max) {
    return 'Wassertemperatur außerhalb des plausiblen Bereichs ($min bis $max)';
  }

  @override
  String get dataQuality_msg_tempUnitBug =>
      'Die Werte deuten auf einen Fehler bei der Temperatureinheit hin';

  @override
  String dataQuality_msg_tempJump(String delta) {
    return 'Temperatur sprang $delta in einem Messpunkt';
  }

  @override
  String dataQuality_msg_tempScalar(String temp) {
    return 'Erfasste Wassertemperatur $temp ist unplausibel';
  }

  @override
  String dataQuality_msg_pressureSwap(String end, String start) {
    return 'Enddruck $end liegt über dem Anfangsdruck $start';
  }

  @override
  String dataQuality_msg_pressureEndpoint(String record, String series) {
    return 'Der Flaschendatensatz nennt $record, aber die Sensorreihe zeigt $series';
  }

  @override
  String dataQuality_msg_pressureRise(String rise) {
    return 'Druck stieg mitten im Tauchgang um $rise ohne Gaswechsel';
  }

  @override
  String dataQuality_msg_sac(String sac) {
    return 'Der abgeleitete Oberflächenverbrauch von $sac ist unplausibel';
  }

  @override
  String dataQuality_msg_ppo2(String ppo2, String gas, String depth) {
    return 'ppO2 erreichte $ppo2 mit $gas auf $depth';
  }

  @override
  String dataQuality_msg_hypoxic(String gas) {
    return 'Hypoxisches Gemisch ($gas) an der Oberfläche in Verwendung angezeigt';
  }

  @override
  String dataQuality_msg_switchMod(String depth, String mod) {
    return 'Gaswechsel auf $depth liegt über der MOD dieses Gases von $mod';
  }

  @override
  String dataQuality_msg_tankInactive(String drop) {
    return 'Diese Flasche verlor $drop, obwohl die Gas-Zeitleiste sie als nicht in Verwendung ausweist';
  }

  @override
  String get dataQuality_msg_twinTanks =>
      'Zwei Flaschen weisen eine nahezu identische Druckreihe auf';

  @override
  String dataQuality_msg_sourceDepth(String primary, String source) {
    return 'Quellen widersprechen sich bei der maximalen Tiefe: $primary vs. $source';
  }

  @override
  String get dataQuality_msg_salinityHint =>
      'Das konstante Verhältnis deutet auf eine unterschiedliche Salz-/Süßwasser-Einstellung hin';

  @override
  String get dataQuality_msg_sourceDuration =>
      'Quellen widersprechen sich bei der Tauchzeit';

  @override
  String get dataQuality_msg_sourceTemp =>
      'Quellen widersprechen sich bei der Wassertemperatur';

  @override
  String dataQuality_repairLabel_shiftTime(String offset) {
    return 'Zeit um $offset verschieben';
  }

  @override
  String get dataQuality_repairLabel_shiftImport =>
      'Alle Tauchgänge aus diesem Import verschieben';

  @override
  String get dataQuality_repairLabel_consolidate => 'Konsolidieren';

  @override
  String get dataQuality_repairLabel_combine =>
      'Zu einem Tauchgang kombinieren';

  @override
  String get dataQuality_repairLabel_despike => 'Ausreißer entfernen';

  @override
  String get dataQuality_repairLabel_clampNegative =>
      'Tiefen über der Oberfläche begrenzen';

  @override
  String get dataQuality_repairLabel_smoothRates => 'Unmögliche Raten glätten';

  @override
  String get dataQuality_repairLabel_fillGaps => 'Lücken füllen';

  @override
  String get dataQuality_repairLabel_smoothTemp => 'Temperatur glätten';

  @override
  String get dataQuality_repairLabel_convertTemp => 'Temperatur umrechnen';

  @override
  String get dataQuality_repairLabel_recompute =>
      'Aus dem Profil neu berechnen';

  @override
  String get dataQuality_repairLabel_swapPressures =>
      'Anfangs-/Enddruck tauschen';

  @override
  String get dataQuality_repairLabel_setFromSeries => 'Sensorwerte verwenden';

  @override
  String get dataQuality_repairLabel_swapSeries => 'Flaschenreihen tauschen';

  @override
  String get dataQuality_repairLabel_reassignSeries =>
      'Reihe einer anderen Flasche zuordnen';

  @override
  String get dataQuality_repairLabel_setPrimary =>
      'Diese Quelle als primär festlegen';

  @override
  String get dataQuality_repairLabel_split =>
      'In separate Tauchgänge aufteilen';

  @override
  String get dataQuality_repairLabel_compare => 'Profile vergleichen';

  @override
  String get dataQuality_settings_title => 'Datenqualität';

  @override
  String get dataQuality_settings_subtitle =>
      'Wählen, welche Prüfungen beim Scannen ausgeführt werden';

  @override
  String dataQuality_summary_flagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente zur Prüfung markiert',
      one: '1 Element zur Prüfung markiert',
    );
    return '$_temp0';
  }

  @override
  String get dataQuality_summary_review => 'Überprüfen';

  @override
  String get dataQuality_detail_chip => 'Überprüfen';

  @override
  String dataQuality_detail_chipCount(int count) {
    return 'Überprüfen ($count)';
  }

  @override
  String get settings_mediaStorage_quality_section => 'Upload-Qualität';

  @override
  String get settings_mediaStorage_quality_photos => 'Fotos';

  @override
  String get settings_mediaStorage_quality_video => 'Video';

  @override
  String get settings_mediaStorage_quality_original => 'Original';

  @override
  String get settings_mediaStorage_quality_high => 'Hoch';

  @override
  String get settings_mediaStorage_quality_balanced => 'Ausgewogen';

  @override
  String get settings_mediaStorage_quality_small => 'Klein';

  @override
  String get settings_mediaStorage_quality_caveat =>
      'Wenn eine Komprimierungsstufe festgelegt ist, werden Originale in voller Auflösung nicht hochgeladen — sie verbleiben nur auf diesem Gerät.';

  @override
  String get settings_mediaStorage_quality_reuploadQueued =>
      'Erneuter Upload in Warteschlange';

  @override
  String get settings_mediaStorage_quality_linuxFfmpegHint =>
      'Installieren Sie ffmpeg, um Videokomprimierung zu aktivieren. Bis dahin werden Originale hochgeladen.';

  @override
  String get settings_mediaStorage_quality_saveFailed =>
      'Die Upload-Qualität konnte nicht gespeichert werden. Bitte erneut versuchen.';

  @override
  String get settings_mediaStorage_quality_noTranscoderHint =>
      'Dieses Gerät kann keine Videos komprimieren. Von ihm werden Originale hochgeladen.';

  @override
  String get reef_section_title => 'Ökosystem';

  @override
  String get reef_section_sourcesTooltip => 'Datenquellen';

  @override
  String get reef_section_loadError =>
      'Ökosystemdaten konnten gerade nicht geladen werden';

  @override
  String get reef_habitat_title => 'Riff-Lebensraum';

  @override
  String get reef_habitat_onReef => 'Auf einem Korallenriff';

  @override
  String reef_habitat_onReefWithThreat(String threat) {
    return 'Auf einem Korallenriff, Gefährdungsstufe $threat';
  }

  @override
  String get reef_habitat_noReef =>
      'Kein kartiertes Korallenriff an diesem Ort';

  @override
  String get reef_habitat_unavailable =>
      'Riff-Lebensraum konnte gerade nicht geprüft werden';

  @override
  String get water_conditions_title => 'Wasserbedingungen';

  @override
  String get water_conditions_unavailable =>
      'Wasserbedingungen konnten gerade nicht geprüft werden';

  @override
  String get water_conditions_noData =>
      'Keine Satelliten-Wasserdaten für diesen Ort';

  @override
  String get water_conditions_freshwater =>
      'Satellitengestützte Wassertemperatur deckt nur Ozeane ab';

  @override
  String water_conditions_anomaly(String value) {
    return 'Anomalie $value';
  }

  @override
  String reef_health_degreeHeatingWeeks(String value) {
    return 'Degree Heating Weeks $value C-Wochen';
  }

  @override
  String reef_health_seaSurface(String value) {
    return 'Wasseroberfläche $value';
  }

  @override
  String reef_health_asOf(String date) {
    return 'Stand $date';
  }

  @override
  String get reef_health_levelNoStress => 'Kein Hitzestress';

  @override
  String get reef_health_levelWatch => 'Bleiche-Beobachtung';

  @override
  String get reef_health_levelWarning => 'Bleiche-Warnung';

  @override
  String get reef_health_levelAlert1 => 'Bleiche-Alarmstufe 1';

  @override
  String get reef_health_levelAlert2 => 'Bleiche-Alarmstufe 2';

  @override
  String get reef_health_levelAlert3 => 'Bleiche-Alarmstufe 3';

  @override
  String get reef_health_levelAlert4 => 'Bleiche-Alarmstufe 4';

  @override
  String get reef_health_levelAlert5 => 'Bleiche-Alarmstufe 5';

  @override
  String get reef_protection_title => 'Schutzgebiet';

  @override
  String get reef_protection_none => 'Nicht in einem Meeresschutzgebiet';

  @override
  String get reef_protection_unavailable =>
      'Schutzstatus konnte gerade nicht geprüft werden';

  @override
  String get reef_protection_viewRegulations => 'Vorschriften ansehen';

  @override
  String reef_protection_iucn(String category) {
    return 'IUCN $category';
  }

  @override
  String get reef_species_recordedNearby => 'In der Nähe erfasst';

  @override
  String get reef_species_addToExpected => 'Zu erwarteten Arten hinzufügen';

  @override
  String reef_species_showAll(int count) {
    return 'Alle $count anzeigen';
  }

  @override
  String get reef_species_showFewer => 'Weniger anzeigen';

  @override
  String get reef_attribution_title => 'Riff-Datenquellen';

  @override
  String get reef_attribution_wri =>
      'Riffvorkommen und Gefährdungsstufe. CC BY 3.0.';

  @override
  String get reef_attribution_noaa =>
      'Wasseroberflächentemperatur und Bleiche-Hitzestress. Gemeinfrei.';

  @override
  String get reef_attribution_gbif =>
      'Artnachweise, gefiltert auf CC0 und CC BY 4.0.';

  @override
  String get reef_attribution_protectedSeas =>
      'Grenzen von Meeresschutzgebieten. CC BY 4.0.';

  @override
  String get enum_visibilityBand_excellent => 'Ausgezeichnet';

  @override
  String get enum_visibilityBand_good => 'Gut';

  @override
  String get enum_visibilityBand_moderate => 'Mäßig';

  @override
  String get enum_visibilityBand_poor => 'Schlecht';

  @override
  String visibility_range_between(String min, String max, String unit) {
    return '$min-$max $unit';
  }

  @override
  String visibility_range_over(String min, String unit) {
    return 'über $min $unit';
  }

  @override
  String visibility_range_under(String max, String unit) {
    return 'unter $max $unit';
  }

  @override
  String get settings_coordinateFormat_title => 'Koordinatenformat';

  @override
  String get settings_coordinateFormat_subtitle =>
      'Wie GPS-Positionen angezeigt und eingegeben werden';

  @override
  String get settings_placeNameLanguage_title => 'Sprache der Ortsnamen';

  @override
  String get settings_placeNameLanguage_subtitle =>
      'Wird verwendet, wenn Land, Region, Ort und Gewässer aus Koordinaten ermittelt werden. Bestehende Tauchplätze werden nicht geändert.';

  @override
  String get settings_coordinateFormat_decimalDegrees => 'Dezimalgrad';

  @override
  String get settings_coordinateFormat_degreesDecimalMinutes =>
      'Grad und Dezimalminuten';

  @override
  String get settings_coordinateFormat_degreesMinutesSeconds =>
      'Grad, Minuten, Sekunden';

  @override
  String get settings_coordinateFormat_utm => 'UTM';

  @override
  String get settings_coordinateFormat_mgrs => 'MGRS';

  @override
  String get settings_visibilityScale_title => 'Sichtweiten-Skala';

  @override
  String get settings_visibilityScale_subtitle =>
      'Welche Entfernungen an deinen Tauchplätzen als gute Sicht gelten';

  @override
  String get settings_visibilityScale_preset_tropical => 'Tropisch';

  @override
  String get settings_visibilityScale_preset_temperate => 'Gemäßigt';

  @override
  String get settings_visibilityScale_preset_coldWater =>
      'Kaltwasser / Binnengewässer';

  @override
  String get settings_visibilityScale_preset_custom => 'Benutzerdefiniert';

  @override
  String get settings_visibilityScale_customExcellent => 'Ausgezeichnet ab';

  @override
  String get settings_visibilityScale_customGood => 'Gut ab';

  @override
  String get settings_visibilityScale_customModerate => 'Mäßig ab';

  @override
  String get settings_visibilityScale_invalidOrder =>
      'Jeder Wert muss kleiner als der darüber und größer als null sein';

  @override
  String statistics_conditions_visibility_legacySuffix(String band) {
    return '$band (vor der Messung erfasst)';
  }

  @override
  String common_selection_countSelected(Object count) {
    return '$count ausgewählt';
  }

  @override
  String get common_selection_enterTooltip => 'Elemente auswählen';

  @override
  String get common_selection_exitTooltip => 'Auswahl beenden';

  @override
  String get common_selection_selectAllTooltip => 'Alle auswählen';

  @override
  String get common_selection_deselectAllTooltip => 'Auswahl aufheben';

  @override
  String common_bulkDelete_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente löschen?',
      one: '$count Element löschen?',
    );
    return '$_temp0';
  }

  @override
  String get common_bulkDelete_body =>
      'Dies kann nicht rückgängig gemacht werden.';

  @override
  String common_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gelöscht',
      one: '$count gelöscht',
    );
    return '$_temp0';
  }

  @override
  String get marineLife_species_delete_confirmTitle => 'Art löschen?';

  @override
  String marineLife_species_delete_confirmBody(String name) {
    return 'Möchten Sie \"$name\" wirklich löschen?';
  }

  @override
  String marineLife_species_delete_inUseError(String name) {
    return '\"$name\" kann nicht gelöscht werden - es gibt Sichtungen';
  }

  @override
  String marineLife_species_delete_snackbar(String name) {
    return '\"$name\" gelöscht';
  }

  @override
  String marineLife_species_delete_error(String error) {
    return 'Fehler beim Löschen der Art: $error';
  }

  @override
  String get enum_diveField_diveNumber => 'Tauchgangnummer';

  @override
  String get enum_diveField_dateTime => 'Datum & Zeit';

  @override
  String get enum_diveField_siteName => 'Tauchplatzname';

  @override
  String get enum_diveField_diveName => 'Tauchgangname';

  @override
  String get enum_diveField_maxDepth => 'Max. Tiefe';

  @override
  String get enum_diveField_avgDepth => 'Durchschnittliche Tiefe';

  @override
  String get enum_diveField_bottomTime => 'Grundzeit';

  @override
  String get enum_diveField_runtime => 'Laufzeit';

  @override
  String get enum_diveField_waterTemp => 'Wassertemperatur';

  @override
  String get enum_diveField_airTemp => 'Lufttemperatur';

  @override
  String get enum_diveField_visibility => 'Sichtweite';

  @override
  String get enum_diveField_currentDirection => 'Strömungsrichtung';

  @override
  String get enum_diveField_currentStrength => 'Strömungsstärke';

  @override
  String get enum_diveField_swellHeight => 'Wellenhöhe';

  @override
  String get enum_diveField_entryMethod => 'Einstiegsmethode';

  @override
  String get enum_diveField_exitMethod => 'Ausstiegsmethode';

  @override
  String get enum_diveField_waterType => 'Wasserart';

  @override
  String get enum_diveField_altitude => 'Höhe';

  @override
  String get enum_diveField_surfacePressure => 'Oberflächendruck';

  @override
  String get enum_diveField_windSpeed => 'Windgeschwindigkeit';

  @override
  String get enum_diveField_cloudCover => 'Bewölkung';

  @override
  String get enum_diveField_precipitation => 'Niederschlag';

  @override
  String get enum_diveField_humidity => 'Luftfeuchtigkeit';

  @override
  String get enum_diveField_weatherDescription => 'Wetter';

  @override
  String get enum_diveField_primaryGas => 'Hauptgas';

  @override
  String get enum_diveField_diluentGas => 'Diluentgas';

  @override
  String get enum_diveField_tankCount => 'Anzahl Flaschen';

  @override
  String get enum_diveField_startPressure => 'Anfangsdruck';

  @override
  String get enum_diveField_endPressure => 'Enddruck';

  @override
  String get enum_diveField_sacRate => 'AMV';

  @override
  String get enum_diveField_gasConsumed => 'Gasverbrauch';

  @override
  String get enum_diveField_totalWeight => 'Gesamtgewicht';

  @override
  String get enum_diveField_diveComputerModel => 'Tauchcomputer';

  @override
  String get enum_diveField_gradientFactorLow => 'GF Niedrig';

  @override
  String get enum_diveField_gradientFactorHigh => 'GF Hoch';

  @override
  String get enum_diveField_decoAlgorithm => 'Deko-Algorithmus';

  @override
  String get enum_diveField_decoConservatism => 'Konservatismus';

  @override
  String get enum_diveField_cnsStart => 'CNS Start';

  @override
  String get enum_diveField_cnsEnd => 'CNS Ende';

  @override
  String get enum_diveField_otu => 'OTU';

  @override
  String get enum_diveField_diveMode => 'Tauchmodus';

  @override
  String get enum_diveField_setpointLow => 'Setpoint niedrig';

  @override
  String get enum_diveField_setpointHigh => 'Setpoint hoch';

  @override
  String get enum_diveField_setpointDeco => 'Setpoint Deko';

  @override
  String get enum_diveField_buddy => 'Tauchpartner';

  @override
  String get enum_diveField_diveMaster => 'Divemaster';

  @override
  String get enum_diveField_siteLocation => 'Tauchplatz-Ort';

  @override
  String get enum_diveField_diveCenterName => 'Tauchbasis';

  @override
  String get enum_diveField_siteLatitude => 'Breitengrad';

  @override
  String get enum_diveField_siteLongitude => 'Längengrad';

  @override
  String get enum_diveField_tripName => 'Reise';

  @override
  String get enum_diveField_ratingStars => 'Bewertung';

  @override
  String get enum_diveField_isFavorite => 'Favorit';

  @override
  String get enum_diveField_notes => 'Notizen';

  @override
  String get enum_diveField_tags => 'Tags';

  @override
  String get enum_diveField_importSource => 'Importquelle';

  @override
  String get enum_diveField_diveTypeName => 'Tauchgangart';

  @override
  String get enum_diveField_surfaceInterval => 'Oberflächenintervall';

  @override
  String get enum_diveField_diveNumber_short => '#';

  @override
  String get enum_diveField_dateTime_short => 'Datum';

  @override
  String get enum_diveField_siteName_short => 'Platz';

  @override
  String get enum_diveField_diveName_short => 'Name';

  @override
  String get enum_diveField_maxDepth_short => 'Max T';

  @override
  String get enum_diveField_avgDepth_short => 'Ø T';

  @override
  String get enum_diveField_bottomTime_short => 'GZ';

  @override
  String get enum_diveField_runtime_short => 'LZ';

  @override
  String get enum_diveField_waterTemp_short => 'W-Temp';

  @override
  String get enum_diveField_airTemp_short => 'L-Temp';

  @override
  String get enum_diveField_visibility_short => 'Sicht';

  @override
  String get enum_diveField_currentDirection_short => 'Str. Ri.';

  @override
  String get enum_diveField_currentStrength_short => 'Str.';

  @override
  String get enum_diveField_swellHeight_short => 'Welle';

  @override
  String get enum_diveField_entryMethod_short => 'Einst.';

  @override
  String get enum_diveField_exitMethod_short => 'Ausst.';

  @override
  String get enum_diveField_waterType_short => 'Wasser';

  @override
  String get enum_diveField_altitude_short => 'Höhe';

  @override
  String get enum_diveField_surfacePressure_short => 'O-Druck';

  @override
  String get enum_diveField_windSpeed_short => 'Wind';

  @override
  String get enum_diveField_cloudCover_short => 'Wolken';

  @override
  String get enum_diveField_precipitation_short => 'Nieders.';

  @override
  String get enum_diveField_humidity_short => 'Luftf.';

  @override
  String get enum_diveField_weatherDescription_short => 'Wetter';

  @override
  String get enum_diveField_primaryGas_short => 'Gas';

  @override
  String get enum_diveField_diluentGas_short => 'Dil';

  @override
  String get enum_diveField_tankCount_short => 'Flaschen';

  @override
  String get enum_diveField_startPressure_short => 'Anf.-Dr.';

  @override
  String get enum_diveField_endPressure_short => 'End-Dr.';

  @override
  String get enum_diveField_sacRate_short => 'AMV';

  @override
  String get enum_diveField_gasConsumed_short => 'Gasverbr.';

  @override
  String get enum_diveField_totalWeight_short => 'Gew.';

  @override
  String get enum_diveField_diveComputerModel_short => 'Computer';

  @override
  String get enum_diveField_gradientFactorLow_short => 'GFL';

  @override
  String get enum_diveField_gradientFactorHigh_short => 'GFH';

  @override
  String get enum_diveField_decoAlgorithm_short => 'Algo';

  @override
  String get enum_diveField_decoConservatism_short => 'Konserv.';

  @override
  String get enum_diveField_cnsStart_short => 'CNS Start';

  @override
  String get enum_diveField_cnsEnd_short => 'CNS Ende';

  @override
  String get enum_diveField_otu_short => 'OTU';

  @override
  String get enum_diveField_diveMode_short => 'Modus';

  @override
  String get enum_diveField_setpointLow_short => 'SP nied.';

  @override
  String get enum_diveField_setpointHigh_short => 'SP hoch';

  @override
  String get enum_diveField_setpointDeco_short => 'SP Deko';

  @override
  String get enum_diveField_buddy_short => 'Partner';

  @override
  String get enum_diveField_diveMaster_short => 'DM';

  @override
  String get enum_diveField_siteLocation_short => 'Ort';

  @override
  String get enum_diveField_diveCenterName_short => 'Basis';

  @override
  String get enum_diveField_siteLatitude_short => 'Breite';

  @override
  String get enum_diveField_siteLongitude_short => 'Länge';

  @override
  String get enum_diveField_tripName_short => 'Reise';

  @override
  String get enum_diveField_ratingStars_short => 'Bew.';

  @override
  String get enum_diveField_isFavorite_short => 'Fav';

  @override
  String get enum_diveField_notes_short => 'Notizen';

  @override
  String get enum_diveField_tags_short => 'Tags';

  @override
  String get enum_diveField_importSource_short => 'Quelle';

  @override
  String get enum_diveField_diveTypeName_short => 'Art';

  @override
  String get enum_diveField_surfaceInterval_short => 'OI';

  @override
  String get enum_siteField_siteName => 'Name';

  @override
  String get enum_siteField_location => 'Ort';

  @override
  String get enum_siteField_country => 'Land';

  @override
  String get enum_siteField_region => 'Region';

  @override
  String get enum_siteField_city => 'Stadt';

  @override
  String get enum_siteField_island => 'Insel';

  @override
  String get enum_siteField_bodyOfWater => 'Gewässer';

  @override
  String get enum_siteField_diveCount => 'Anzahl Tauchgänge';

  @override
  String get enum_siteField_maxDepth => 'Max. Tiefe';

  @override
  String get enum_siteField_minDepth => 'Min. Tiefe';

  @override
  String get enum_siteField_altitude => 'Höhe';

  @override
  String get enum_siteField_waterType => 'Wasserart';

  @override
  String get enum_siteField_typicalVisibility => 'Typische Sichtweite';

  @override
  String get enum_siteField_typicalCurrent => 'Typische Strömung';

  @override
  String get enum_siteField_difficulty => 'Schwierigkeitsgrad';

  @override
  String get enum_siteField_entryType => 'Einstiegsart';

  @override
  String get enum_siteField_bestSeason => 'Beste Saison';

  @override
  String get enum_siteField_mooringNumber => 'Bojen-Nummer';

  @override
  String get enum_siteField_hazards => 'Gefahren';

  @override
  String get enum_siteField_rating => 'Bewertung';

  @override
  String get enum_siteField_notes => 'Notizen';

  @override
  String get enum_siteField_latitude => 'Breitengrad';

  @override
  String get enum_siteField_longitude => 'Längengrad';

  @override
  String get enum_siteField_siteName_short => 'Name';

  @override
  String get enum_siteField_location_short => 'Ort';

  @override
  String get enum_siteField_country_short => 'Land';

  @override
  String get enum_siteField_region_short => 'Region';

  @override
  String get enum_siteField_city_short => 'Stadt';

  @override
  String get enum_siteField_island_short => 'Insel';

  @override
  String get enum_siteField_bodyOfWater_short => 'Gewässer';

  @override
  String get enum_siteField_diveCount_short => 'Tauchg.';

  @override
  String get enum_siteField_maxDepth_short => 'Max T';

  @override
  String get enum_siteField_minDepth_short => 'Min T';

  @override
  String get enum_siteField_altitude_short => 'Höhe';

  @override
  String get enum_siteField_waterType_short => 'Wasser';

  @override
  String get enum_siteField_typicalVisibility_short => 'Sicht';

  @override
  String get enum_siteField_typicalCurrent_short => 'Strömung';

  @override
  String get enum_siteField_difficulty_short => 'Schw.';

  @override
  String get enum_siteField_entryType_short => 'Einst.';

  @override
  String get enum_siteField_exitMethod => 'Ausstiegsart';

  @override
  String get enum_siteField_exitMethod_short => 'Ausstieg';

  @override
  String get enum_siteField_bestSeason_short => 'Saison';

  @override
  String get enum_siteField_mooringNumber_short => 'Boje';

  @override
  String get enum_siteField_hazards_short => 'Gefahren';

  @override
  String get enum_siteField_rating_short => 'Bew.';

  @override
  String get enum_siteField_notes_short => 'Notizen';

  @override
  String get enum_siteField_latitude_short => 'Breite';

  @override
  String get enum_siteField_longitude_short => 'Länge';

  @override
  String get enum_siteField_depthRange => 'Tiefenbereich';

  @override
  String get enum_siteField_depthRange_short => 'Tiefe';

  @override
  String get enum_siteField_lastDived => 'Zuletzt getaucht';

  @override
  String get enum_siteField_lastDived_short => 'Zuletzt';

  @override
  String get enum_siteField_maxDepthReached => 'Deine max. Tiefe';

  @override
  String get enum_siteField_maxDepthReached_short => 'Dein Max.';

  @override
  String get enum_buddyField_buddyName => 'Name';

  @override
  String get enum_buddyField_email => 'E-Mail';

  @override
  String get enum_buddyField_phone => 'Telefon';

  @override
  String get enum_buddyField_certificationLevel => 'Zertifizierungsstufe';

  @override
  String get enum_buddyField_certificationAgency => 'Zertifizierungsverband';

  @override
  String get enum_buddyField_diveCount => 'Anzahl Tauchgänge';

  @override
  String get enum_buddyField_notes => 'Notizen';

  @override
  String get enum_buddyField_buddyName_short => 'Name';

  @override
  String get enum_buddyField_email_short => 'E-Mail';

  @override
  String get enum_buddyField_phone_short => 'Telefon';

  @override
  String get enum_buddyField_certificationLevel_short => 'Stufe';

  @override
  String get enum_buddyField_certificationAgency_short => 'Verband';

  @override
  String get enum_buddyField_diveCount_short => 'Tauchg.';

  @override
  String get enum_buddyField_notes_short => 'Notizen';

  @override
  String get enum_buddyField_lastDive => 'Letzter Tauchgang';

  @override
  String get enum_buddyField_lastDive_short => 'Letzter TG';

  @override
  String get enum_tripField_tripName => 'Name';

  @override
  String get enum_tripField_startDate => 'Startdatum';

  @override
  String get enum_tripField_endDate => 'Enddatum';

  @override
  String get enum_tripField_durationDays => 'Dauer';

  @override
  String get enum_tripField_location => 'Ort';

  @override
  String get enum_tripField_tripType => 'Reiseart';

  @override
  String get enum_tripField_resortName => 'Resort';

  @override
  String get enum_tripField_liveaboardName => 'Tauchsafari';

  @override
  String get enum_tripField_diveCount => 'Anzahl Tauchgänge';

  @override
  String get enum_tripField_totalRuntime => 'Gesamte Laufzeit';

  @override
  String get enum_tripField_maxDepth => 'Max. Tiefe';

  @override
  String get enum_tripField_avgDepth => 'Ø Tiefe';

  @override
  String get enum_tripField_notes => 'Notizen';

  @override
  String get enum_tripField_tripName_short => 'Name';

  @override
  String get enum_tripField_startDate_short => 'Start';

  @override
  String get enum_tripField_endDate_short => 'Ende';

  @override
  String get enum_tripField_durationDays_short => 'Tage';

  @override
  String get enum_tripField_location_short => 'Ort';

  @override
  String get enum_tripField_tripType_short => 'Art';

  @override
  String get enum_tripField_resortName_short => 'Resort';

  @override
  String get enum_tripField_liveaboardName_short => 'Safari';

  @override
  String get enum_tripField_diveCount_short => 'Tauchg.';

  @override
  String get enum_tripField_totalRuntime_short => 'LZ ges.';

  @override
  String get enum_tripField_maxDepth_short => 'Max T';

  @override
  String get enum_tripField_avgDepth_short => 'Ø T';

  @override
  String get enum_tripField_notes_short => 'Notizen';

  @override
  String get enum_equipmentField_itemName => 'Name';

  @override
  String get enum_equipmentField_fullName => 'Vollständiger Name';

  @override
  String get enum_equipmentField_type => 'Typ';

  @override
  String get enum_equipmentField_brand => 'Marke';

  @override
  String get enum_equipmentField_model => 'Modell';

  @override
  String get enum_equipmentField_serialNumber => 'Seriennummer';

  @override
  String get enum_equipmentField_size => 'Größe';

  @override
  String get enum_equipmentField_status => 'Status';

  @override
  String get enum_equipmentField_isActive => 'Aktiv';

  @override
  String get enum_equipmentField_purchaseDate => 'Kaufdatum';

  @override
  String get enum_equipmentField_purchasePrice => 'Kaufpreis';

  @override
  String get enum_equipmentField_lastServiceDate => 'Letzte Wartung';

  @override
  String get enum_equipmentField_nextServiceDue => 'Nächste Wartung fällig';

  @override
  String get enum_equipmentField_daysUntilService => 'Tage bis zur Wartung';

  @override
  String get enum_equipmentField_serviceIntervalDays => 'Wartungsintervall';

  @override
  String get enum_equipmentField_notes => 'Notizen';

  @override
  String get enum_equipmentField_itemName_short => 'Name';

  @override
  String get enum_equipmentField_fullName_short => 'Vollname';

  @override
  String get enum_equipmentField_type_short => 'Typ';

  @override
  String get enum_equipmentField_brand_short => 'Marke';

  @override
  String get enum_equipmentField_model_short => 'Modell';

  @override
  String get enum_equipmentField_serialNumber_short => 'Ser.-Nr.';

  @override
  String get enum_equipmentField_size_short => 'Größe';

  @override
  String get enum_equipmentField_status_short => 'Status';

  @override
  String get enum_equipmentField_isActive_short => 'Aktiv';

  @override
  String get enum_equipmentField_purchaseDate_short => 'Gekauft';

  @override
  String get enum_equipmentField_purchasePrice_short => 'Preis';

  @override
  String get enum_equipmentField_lastServiceDate_short => 'Gewartet';

  @override
  String get enum_equipmentField_nextServiceDue_short => 'Fällig';

  @override
  String get enum_equipmentField_daysUntilService_short => 'Rest-Tage';

  @override
  String get enum_equipmentField_serviceIntervalDays_short => 'Intervall';

  @override
  String get enum_equipmentField_notes_short => 'Notizen';

  @override
  String get enum_diveCenterField_centerName => 'Name';

  @override
  String get enum_diveCenterField_city => 'Stadt';

  @override
  String get enum_diveCenterField_country => 'Land';

  @override
  String get enum_diveCenterField_stateProvince => 'Bundesland / Provinz';

  @override
  String get enum_diveCenterField_street => 'Straße';

  @override
  String get enum_diveCenterField_postalCode => 'Postleitzahl';

  @override
  String get enum_diveCenterField_phone => 'Telefon';

  @override
  String get enum_diveCenterField_email => 'E-Mail';

  @override
  String get enum_diveCenterField_website => 'Website';

  @override
  String get enum_diveCenterField_affiliations => 'Verbindungen';

  @override
  String get enum_diveCenterField_rating => 'Bewertung';

  @override
  String get enum_diveCenterField_latitude => 'Breitengrad';

  @override
  String get enum_diveCenterField_longitude => 'Längengrad';

  @override
  String get enum_diveCenterField_diveCount => 'Anzahl Tauchgänge';

  @override
  String get enum_diveCenterField_notes => 'Notizen';

  @override
  String get enum_diveCenterField_centerName_short => 'Name';

  @override
  String get enum_diveCenterField_city_short => 'Stadt';

  @override
  String get enum_diveCenterField_country_short => 'Land';

  @override
  String get enum_diveCenterField_stateProvince_short => 'Provinz';

  @override
  String get enum_diveCenterField_street_short => 'Straße';

  @override
  String get enum_diveCenterField_postalCode_short => 'PLZ';

  @override
  String get enum_diveCenterField_phone_short => 'Telefon';

  @override
  String get enum_diveCenterField_email_short => 'E-Mail';

  @override
  String get enum_diveCenterField_website_short => 'Website';

  @override
  String get enum_diveCenterField_affiliations_short => 'Verbindungen';

  @override
  String get enum_diveCenterField_rating_short => 'Bew.';

  @override
  String get enum_diveCenterField_latitude_short => 'Breite';

  @override
  String get enum_diveCenterField_longitude_short => 'Länge';

  @override
  String get enum_diveCenterField_diveCount_short => 'Tauchg.';

  @override
  String get enum_diveCenterField_notes_short => 'Notizen';

  @override
  String get enum_certificationField_certName => 'Name';

  @override
  String get enum_certificationField_agency => 'Verband';

  @override
  String get enum_certificationField_level => 'Zertifizierung';

  @override
  String get enum_certificationField_cardNumber => 'Kartennummer';

  @override
  String get enum_certificationField_issueDate => 'Ausstellungsdatum';

  @override
  String get enum_certificationField_expiryDate => 'Ablaufdatum';

  @override
  String get enum_certificationField_instructorName => 'Tauchlehrername';

  @override
  String get enum_certificationField_instructorNumber => 'Tauchlehrernummer';

  @override
  String get enum_certificationField_expiryStatus => 'Ablaufstatus';

  @override
  String get enum_certificationField_notes => 'Notizen';

  @override
  String get enum_certificationField_certName_short => 'Name';

  @override
  String get enum_certificationField_agency_short => 'Verband';

  @override
  String get enum_certificationField_level_short => 'Zertifizierung';

  @override
  String get enum_certificationField_cardNumber_short => 'Kartennr.';

  @override
  String get enum_certificationField_issueDate_short => 'Ausgest.';

  @override
  String get enum_certificationField_expiryDate_short => 'Ablauf';

  @override
  String get enum_certificationField_instructorName_short => 'Tauchlehrer';

  @override
  String get enum_certificationField_instructorNumber_short => 'TL-Nr.';

  @override
  String get enum_certificationField_expiryStatus_short => 'Status';

  @override
  String get enum_certificationField_notes_short => 'Notizen';

  @override
  String get enum_courseField_courseName => 'Name';

  @override
  String get enum_courseField_agency => 'Verband';

  @override
  String get enum_courseField_startDate => 'Startdatum';

  @override
  String get enum_courseField_completionDate => 'Abschlussdatum';

  @override
  String get enum_courseField_durationDays => 'Dauer';

  @override
  String get enum_courseField_instructorName => 'Tauchlehrername';

  @override
  String get enum_courseField_instructorNumber => 'Tauchlehrernummer';

  @override
  String get enum_courseField_location => 'Ort';

  @override
  String get enum_courseField_isCompleted => 'Abgeschlossen';

  @override
  String get enum_courseField_notes => 'Notizen';

  @override
  String get enum_courseField_courseName_short => 'Name';

  @override
  String get enum_courseField_agency_short => 'Verband';

  @override
  String get enum_courseField_startDate_short => 'Beginn';

  @override
  String get enum_courseField_completionDate_short => 'Abschluss';

  @override
  String get enum_courseField_durationDays_short => 'Dauer';

  @override
  String get enum_courseField_instructorName_short => 'Tauchlehrer';

  @override
  String get enum_courseField_instructorNumber_short => 'TL-Nr.';

  @override
  String get enum_courseField_location_short => 'Ort';

  @override
  String get enum_courseField_isCompleted_short => 'Fertig';

  @override
  String get enum_courseField_notes_short => 'Notizen';

  @override
  String get enum_fieldCategory_accommodation => 'Unterkunft';

  @override
  String get enum_fieldCategory_address => 'Adresse';

  @override
  String get enum_fieldCategory_certification => 'Zertifizierung';

  @override
  String get enum_fieldCategory_conditions => 'Bedingungen';

  @override
  String get enum_fieldCategory_contact => 'Kontakt';

  @override
  String get enum_fieldCategory_coordinates => 'Koordinaten';

  @override
  String get enum_fieldCategory_dates => 'Daten';

  @override
  String get enum_fieldCategory_depth => 'Tiefe';

  @override
  String get enum_fieldCategory_details => 'Details';

  @override
  String get enum_fieldCategory_instructor => 'Tauchlehrer';

  @override
  String get enum_fieldCategory_other => 'Sonstige';

  @override
  String get enum_fieldCategory_purchase => 'Kauf';

  @override
  String get enum_fieldCategory_service => 'Wartung';

  @override
  String get enum_fieldCategory_statistics => 'Statistiken';

  @override
  String get species_whale_shark_name => 'Walhai';

  @override
  String get species_whale_shark_desc =>
      'Größter Fisch der Ozeane, ein sanfter Filtrierer mit markantem Punktmuster.';

  @override
  String get species_great_white_shark_name => 'Weißer Hai';

  @override
  String get species_great_white_shark_desc =>
      'Ikonischer Spitzenjäger, den Käfigtaucher gelegentlich in gemäßigten Gewässern zu sehen bekommen.';

  @override
  String get species_great_hammerhead_shark_name => 'Großer Hammerhai';

  @override
  String get species_great_hammerhead_shark_desc =>
      'Größte Hammerhai-Art mit breitem, flachem Kopf und hoher Rückenflosse.';

  @override
  String get species_scalloped_hammerhead_shark_name => 'Bogenstirn-Hammerhai';

  @override
  String get species_scalloped_hammerhead_shark_desc =>
      'Oft in großen Schulen an Seebergen und Putzerstationen zu sehen.';

  @override
  String get species_smooth_hammerhead_shark_name => 'Glatter Hammerhai';

  @override
  String get species_smooth_hammerhead_shark_desc =>
      'Hammerhai mit glattem, abgerundetem Kopfrand, in gemäßigten Meeren verbreitet.';

  @override
  String get species_whitetip_reef_shark_name => 'Weißspitzen-Riffhai';

  @override
  String get species_whitetip_reef_shark_desc =>
      'Friedlicher Riffbewohner, der tagsüber häufig in Höhlen und unter Überhängen ruht.';

  @override
  String get species_blacktip_reef_shark_name => 'Schwarzspitzen-Riffhai';

  @override
  String get species_blacktip_reef_shark_desc =>
      'Häufiger Riffhai des Flachwassers mit auffällig schwarz gespitzten Flossen.';

  @override
  String get species_grey_reef_shark_name => 'Grauer Riffhai';

  @override
  String get species_grey_reef_shark_desc =>
      'Aktiver Riffjäger, dem man oft in Gruppen an Steilwänden und in Kanälen begegnet.';

  @override
  String get species_caribbean_reef_shark_name => 'Karibischer Riffhai';

  @override
  String get species_caribbean_reef_shark_desc =>
      'Der am häufigsten anzutreffende Riffhai der Karibik, kräftig gebaut und neugierig.';

  @override
  String get species_nurse_shark_name => 'Ammenhai';

  @override
  String get species_nurse_shark_desc =>
      'Langsamer Bodenbewohner, der oft unter Korallenüberhängen ruht.';

  @override
  String get species_tawny_nurse_shark_name => 'Großer Ammenhai';

  @override
  String get species_tawny_nurse_shark_desc =>
      'Indopazifischer Bodenbewohner, der in Riffhöhlen und auf Sandflächen ruht.';

  @override
  String get species_bull_shark_name => 'Bullenhai';

  @override
  String get species_bull_shark_desc =>
      'Gedrungener, kräftiger Hai, der weltweit in Küstengewässern und im Süßwasser vorkommt.';

  @override
  String get species_tiger_shark_name => 'Tigerhai';

  @override
  String get species_tiger_shark_desc =>
      'Großer Räuber mit markanter Streifenzeichnung, dem man bei tiefen Riff-Tauchgängen begegnet.';

  @override
  String get species_oceanic_whitetip_shark_name => 'Weißspitzen-Hochseehai';

  @override
  String get species_oceanic_whitetip_shark_desc =>
      'Hochseehai mit abgerundeten, weiß gespitzten Flossen, bei Tauchgängen im offenen Ozean zu sehen.';

  @override
  String get species_thresher_shark_name => 'Fuchshai';

  @override
  String get species_thresher_shark_desc =>
      'An seiner extrem langen Schwanzflosse zu erkennen, gelegentlich an Putzerstationen zu sehen.';

  @override
  String get species_pelagic_thresher_shark_name => 'Pelagischer Fuchshai';

  @override
  String get species_pelagic_thresher_shark_desc =>
      'Kleinste Fuchshai-Art, berühmt für ihre Sichtungen am Monad Shoal auf den Philippinen.';

  @override
  String get species_shortfin_mako_shark_name => 'Kurzflossen-Makohai';

  @override
  String get species_shortfin_mako_shark_desc =>
      'Schnellster Hai der Meere, ein schlanker Freiwasserjäger mit metallisch blauer Färbung.';

  @override
  String get species_blue_shark_name => 'Blauhai';

  @override
  String get species_blue_shark_desc =>
      'Schlanker, tiefblauer Hochseehai, dem man häufig bei Blauwasser-Tauchgängen begegnet.';

  @override
  String get species_spotted_wobbegong_name => 'Gefleckter Teppichhai';

  @override
  String get species_spotted_wobbegong_desc =>
      'Flacher, getarnter Teppichhai, der bewegungslos auf Felsriffen in Australien liegt.';

  @override
  String get species_tasselled_wobbegong_name => 'Fransenteppichhai';

  @override
  String get species_tasselled_wobbegong_desc =>
      'Prächtig gezeichneter Teppichhai mit Hautfransen rund um den Kopf, in Korallenriffen zu Hause.';

  @override
  String get species_epaulette_shark_name => 'Epaulettenhai';

  @override
  String get species_epaulette_shark_desc =>
      'Kleiner Hai, der mit seinen Brustflossen über den Riffboden läuft.';

  @override
  String get species_horn_shark_name => 'Hornhai';

  @override
  String get species_horn_shark_desc =>
      'Nachtaktiver Bodenbewohner mit Wülsten über den Augen, vor Kalifornien verbreitet.';

  @override
  String get species_leopard_shark_name => 'Leopardenhai';

  @override
  String get species_leopard_shark_desc =>
      'Wunderschön gezeichneter Hai in flachen Buchten entlang der US-Pazifikküste.';

  @override
  String get species_pacific_angel_shark_name => 'Pazifischer Engelhai';

  @override
  String get species_pacific_angel_shark_desc =>
      'Flach gebauter Lauerjäger, der eingegraben im Sand des Meeresbodens liegt.';

  @override
  String get species_sand_tiger_shark_name => 'Sandtigerhai';

  @override
  String get species_sand_tiger_shark_desc =>
      'Furchterregend aussehender, aber friedlicher Hai, der oft in Höhlen und Wracks schwebt.';

  @override
  String get species_zebra_shark_name => 'Zebrahai';

  @override
  String get species_zebra_shark_desc =>
      'Gefleckter Riffhai, der auf Sandböden ruht und im Indopazifik häufig ist.';

  @override
  String get species_blacktip_shark_name => 'Schwarzspitzenhai';

  @override
  String get species_blacktip_shark_desc =>
      'Schneller Küstenhai, bekannt für seine Drehsprünge, weltweit in warmen Gewässern verbreitet.';

  @override
  String get species_silvertip_shark_name => 'Silberspitzenhai';

  @override
  String get species_silvertip_shark_desc =>
      'Selbstbewusster Riffhai mit weiß gesäumten Flossen, nahe tiefen Steilwänden und Atollen.';

  @override
  String get species_silky_shark_name => 'Seidenhai';

  @override
  String get species_silky_shark_desc =>
      'Schlanker Hochseehai mit glatter Haut, oft in der Nähe vorgelagerter Riffe.';

  @override
  String get species_lemon_shark_name => 'Zitronenhai';

  @override
  String get species_lemon_shark_desc =>
      'Gelbbrauner Hai, der häufig in flachen Mangroven und auf Sandflächen zu sehen ist.';

  @override
  String get species_galapagos_shark_name => 'Galapagoshai';

  @override
  String get species_galapagos_shark_desc =>
      'Großer Riffhai rund um ozeanische Inseln, Tauchern gegenüber neugierig.';

  @override
  String get species_port_jackson_shark_name => 'Portjackson-Stierkopfhai';

  @override
  String get species_port_jackson_shark_desc =>
      'Nachtaktiver Bodenbewohner mit geschirrartiger Zeichnung, endemisch in Australien.';

  @override
  String get species_bamboo_shark_name => 'Braungebänderter Bambushai';

  @override
  String get species_bamboo_shark_desc =>
      'Kleiner, friedlicher Bodenhai, häufig auf Korallenriffen des Indopazifiks.';

  @override
  String get species_basking_shark_name => 'Riesenhai';

  @override
  String get species_basking_shark_desc =>
      'Zweitgrößter Fisch, ein Filtrierer, den man in gemäßigten Oberflächengewässern sieht.';

  @override
  String get species_greenland_shark_name => 'Grönlandhai';

  @override
  String get species_greenland_shark_desc =>
      'Langsamer Tiefwasserhai und eines der langlebigsten Wirbeltiere der Erde.';

  @override
  String get species_cookiecutter_shark_name => 'Zigarrenhai';

  @override
  String get species_cookiecutter_shark_desc =>
      'Kleiner Tiefwasserhai, der kreisrunde Bissstücke aus größeren Meerestieren herausschneidet.';

  @override
  String get species_sevengill_shark_name => 'Breitnasen-Siebenkiemerhai';

  @override
  String get species_sevengill_shark_desc =>
      'Urtümlicher Hai mit sieben Kiemenspalten, bei Tauchgängen in gemäßigten Kelpwäldern anzutreffen.';

  @override
  String get species_pyjama_shark_name => 'Pyjama-Katzenhai';

  @override
  String get species_pyjama_shark_desc =>
      'Gestreifter Katzenhai, endemisch in Südafrika, in Felsriffen und Kelpwäldern zu finden.';

  @override
  String get species_spiny_dogfish_name => 'Dornhai';

  @override
  String get species_spiny_dogfish_desc =>
      'Kleiner, häufiger Hai mit giftigen Rückenstacheln, in gemäßigten Gewässern verbreitet.';

  @override
  String get species_swell_shark_name => 'Schwellhai';

  @override
  String get species_swell_shark_desc =>
      'Nachtaktiver Katzenhai, der sich bei Gefahr aufbläht, vor Kalifornien verbreitet.';

  @override
  String get species_giant_oceanic_manta_ray_name => 'Riesenmanta';

  @override
  String get species_giant_oceanic_manta_ray_desc =>
      'Größte Rochenart, ein majestätischer Filtrierer mit bis zu 7 Metern Spannweite.';

  @override
  String get species_reef_manta_ray_name => 'Riffmanta';

  @override
  String get species_reef_manta_ray_desc =>
      'Kleinere Mantaart, die häufig an Putzerstationen tropischer Riffe zu sehen ist.';

  @override
  String get species_spotted_eagle_ray_name => 'Gefleckter Adlerrochen';

  @override
  String get species_spotted_eagle_ray_desc =>
      'Eleganter Rochen mit weißen Punkten und langem peitschenartigem Schwanz, oft im Freiwasser.';

  @override
  String get species_common_eagle_ray_name => 'Gemeiner Adlerrochen';

  @override
  String get species_common_eagle_ray_desc =>
      'Rautenförmiger Rochen in den gemäßigten Gewässern des Ostatlantiks und des Mittelmeers.';

  @override
  String get species_blue_spotted_ribbontail_ray_name => 'Blaupunktrochen';

  @override
  String get species_blue_spotted_ribbontail_ray_desc =>
      'Leuchtend gefärbter Rochen mit kräftig blauen Punkten, häufig an Riffen des Indopazifiks.';

  @override
  String get species_blue_spotted_stingray_name => 'Blaupunkt-Stechrochen';

  @override
  String get species_blue_spotted_stingray_desc =>
      'Kleiner Riff-Stechrochen mit verstreuten blauen Punkten, oft in Sandflächen eingegraben.';

  @override
  String get species_southern_stingray_name => 'Südlicher Stechrochen';

  @override
  String get species_southern_stingray_desc =>
      'Großer Stechrochen auf den Sandflächen der Karibik, berühmt aus Stingray City.';

  @override
  String get species_round_stingray_name => 'Rundstechrochen';

  @override
  String get species_round_stingray_desc =>
      'Kleiner, runder Stechrochen, häufig in flachen Sandbereichen des Ostpazifiks.';

  @override
  String get species_short_tail_stingray_name => 'Kurzschwanz-Stechrochen';

  @override
  String get species_short_tail_stingray_desc =>
      'Einer der größten Stechrochen, in gemäßigten Gewässern der Südhalbkugel zu Hause.';

  @override
  String get species_cowtail_stingray_name => 'Kuhschwanz-Stechrochen';

  @override
  String get species_cowtail_stingray_desc =>
      'Großer dunkler Stechrochen mit auffälliger fahnenartiger Schwanzfalte, auf sandigen Riffen.';

  @override
  String get species_atlantic_torpedo_ray_name => 'Atlantischer Zitterrochen';

  @override
  String get species_atlantic_torpedo_ray_desc =>
      'Zitterrochen, der starke Stromschläge erzeugen kann, auf den Sandböden des Atlantiks.';

  @override
  String get species_marbled_electric_ray_name => 'Marmorierter Zitterrochen';

  @override
  String get species_marbled_electric_ray_desc =>
      'Mediterraner Zitterrochen mit marmorierter Zeichnung, der einen spürbaren Stromschlag austeilt.';

  @override
  String get species_giant_guitarfish_name => 'Riesen-Geigenrochen';

  @override
  String get species_giant_guitarfish_desc =>
      'Haiförmiger Rochen auf den Sandböden des Indopazifiks nahe Korallenriffen.';

  @override
  String get species_shovelnose_guitarfish_name => 'Schaufelnasen-Geigenrochen';

  @override
  String get species_shovelnose_guitarfish_desc =>
      'Abgeflachte Mischform aus Rochen und Hai, häufig im sandigen Flachwasser des Ostpazifiks.';

  @override
  String get species_smalltooth_sawfish_name => 'Kleinzahn-Sägefisch';

  @override
  String get species_smalltooth_sawfish_desc =>
      'Vom Aussterben bedrohter Rochen mit bezahntem Rostrum, in tropischen Küstengewässern.';

  @override
  String get species_green_sawfish_name => 'Grüner Sägefisch';

  @override
  String get species_green_sawfish_desc =>
      'Großer Sägefisch mit olivgrünem Körper, der Ästuare des Indo-Westpazifiks bewohnt.';

  @override
  String get species_devil_ray_name => 'Riesenteufelsrochen';

  @override
  String get species_devil_ray_desc =>
      'Großer Mobula-Rochen mit Kopfflossen, der in Gruppen aus dem Wasser springt.';

  @override
  String get species_spinetail_devil_ray_name => 'Stachelschwanz-Teufelsrochen';

  @override
  String get species_spinetail_devil_ray_desc =>
      'Pelagischer Teufelsrochen, der oft in großen Ansammlungen nahe der Oberfläche zu sehen ist.';

  @override
  String get species_lesser_devil_ray_name => 'Zwerg-Teufelsrochen';

  @override
  String get species_lesser_devil_ray_desc =>
      'Kleinste Mobula-Art, bildet große Schulen im Golf von Kalifornien.';

  @override
  String get species_bat_ray_name => 'Fledermausrochen';

  @override
  String get species_bat_ray_desc =>
      'Rautenförmiger Rochen, häufig in Kelpwäldern und sandigen Buchten Kaliforniens.';

  @override
  String get species_undulate_ray_name => 'Marmorrochen';

  @override
  String get species_undulate_ray_desc =>
      'Wunderschön gezeichneter Rochen mit welligen Linien, im Ostatlantik verbreitet.';

  @override
  String get species_thornback_ray_name => 'Nagelrochen';

  @override
  String get species_thornback_ray_desc =>
      'Häufiger europäischer Rochen mit dornigen Stacheln auf Rücken und Schwanz.';

  @override
  String get species_cownose_ray_name => 'Kuhnasenrochen';

  @override
  String get species_cownose_ray_desc =>
      'Auffällig eingekerbter Kopf, oft in großen Schulen während der saisonalen Wanderungen.';

  @override
  String get species_marble_ray_name => 'Marmor-Stechrochen';

  @override
  String get species_marble_ray_desc =>
      'Großer dunkler Stechrochen mit weißen Punkten, häufig an Putzerstationen im Indopazifik.';

  @override
  String get species_ocellate_river_stingray_name => 'Motoro-Stechrochen';

  @override
  String get species_ocellate_river_stingray_desc =>
      'Süßwasser-Stechrochen mit auffälligen orange umrandeten Punkten, heimisch in südamerikanischen Flüssen.';

  @override
  String get species_ocellaris_clownfish_name => 'Falscher Clownfisch';

  @override
  String get species_ocellaris_clownfish_desc =>
      'Kleiner orange-weiß gestreifter Fisch, der auf Korallenriffen in Symbiose mit Seeanemonen lebt.';

  @override
  String get species_clarkii_clownfish_name => 'Clarks Anemonenfisch';

  @override
  String get species_clarkii_clownfish_desc =>
      'Robuster Anemonenfisch mit dunklem Körper und zwei weißen Binden, im gesamten Indopazifik in verschiedenen Anemonenarten.';

  @override
  String get species_tomato_clownfish_name => 'Tomaten-Anemonenfisch';

  @override
  String get species_tomato_clownfish_desc =>
      'Leuchtend rotoranger Anemonenfisch mit einer einzelnen weißen Kopfbinde, häufig an Riffen des Indopazifiks.';

  @override
  String get species_regal_blue_tang_name => 'Paletten-Doktorfisch';

  @override
  String get species_regal_blue_tang_desc =>
      'Leuchtend blauer Doktorfisch mit schwarzer Palettenzeichnung und gelber Schwanzflosse, auf Korallenriffen des Indopazifiks.';

  @override
  String get species_yellow_tang_name => 'Gelber Segelflossen-Doktorfisch';

  @override
  String get species_yellow_tang_desc =>
      'Leuchtend gelber Doktorfisch, häufig an hawaiianischen und pazifischen Riffen, oft in Gruppen beim Abweiden von Algen.';

  @override
  String get species_powder_blue_surgeonfish_name => 'Weißkehl-Doktorfisch';

  @override
  String get species_powder_blue_surgeonfish_desc =>
      'Auffälliger hellblauer Doktorfisch mit schwarzem Gesicht und gelber Rückenflosse, im Indischen Ozean verbreitet.';

  @override
  String get species_sohal_surgeonfish_name => 'Sohal-Doktorfisch';

  @override
  String get species_sohal_surgeonfish_desc =>
      'Markant gestreifter Doktorfisch mit orangefarbenem Skalpelldorn, endemisch an den Riffen des Roten Meeres und des Arabischen Golfs.';

  @override
  String get species_blue_tang_name => 'Blauer Doktorfisch';

  @override
  String get species_blue_tang_desc =>
      'Tiefblauer Doktorfisch, häufig an karibischen Riffen; Jungtiere sind leuchtend gelb.';

  @override
  String get species_emperor_angelfish_name => 'Imperator-Kaiserfisch';

  @override
  String get species_emperor_angelfish_desc =>
      'Großer Kaiserfisch mit auffälligen blauen und gelben Längsstreifen. Jungtiere zeigen konzentrische blau-weiße Ringe.';

  @override
  String get species_french_angelfish_name => 'Franzosen-Kaiserfisch';

  @override
  String get species_french_angelfish_desc =>
      'Großer dunkler Kaiserfisch mit goldgesäumten Schuppen, meist paarweise an Riffen der Karibik und des Westatlantiks.';

  @override
  String get species_queen_angelfish_name => 'Königin-Kaiserfisch';

  @override
  String get species_queen_angelfish_desc =>
      'Prächtiger blau-gelber Kaiserfisch mit markantem Kronenfleck, auf karibischen Korallenriffen.';

  @override
  String get species_regal_angelfish_name => 'Pfauen-Kaiserfisch';

  @override
  String get species_regal_angelfish_desc =>
      'Eleganter Kaiserfisch mit abwechselnd orange-weißen und blauen Querbinden, an Riffen des Indopazifiks.';

  @override
  String get species_rock_beauty_name => 'Dreifarben-Kaiserfisch';

  @override
  String get species_rock_beauty_desc =>
      'Auffälliger karibischer Kaiserfisch mit gelber Vorder- und schwarzer Hinterhälfte, nahe Felsriffen und Überhängen.';

  @override
  String get species_gray_angelfish_name => 'Grauer Kaiserfisch';

  @override
  String get species_gray_angelfish_desc =>
      'Großer grauer Kaiserfisch mit heller Gesichtspartie und gelber Brustflossen-Innenseite, häufig an karibischen Riffen.';

  @override
  String get species_copperband_butterflyfish_name =>
      'Kupferstreifen-Pinzettfisch';

  @override
  String get species_copperband_butterflyfish_desc =>
      'Markanter Falterfisch mit orangefarbenen Querbinden und langgezogener Schnauze, an Riffen des Indopazifiks.';

  @override
  String get species_raccoon_butterflyfish_name => 'Waschbär-Falterfisch';

  @override
  String get species_raccoon_butterflyfish_desc =>
      'Gelber Falterfisch mit dunkler, waschbärartiger Augenmaske, häufig an Riffen des Indopazifiks und Hawaiis.';

  @override
  String get species_longnose_butterflyfish_name => 'Gelber Pinzettfisch';

  @override
  String get species_longnose_butterflyfish_desc =>
      'Leuchtend gelber Falterfisch, der mit extrem langer Schnauze Nahrung aus Spalten der Riffe des Indopazifiks pickt.';

  @override
  String get species_threadfin_butterflyfish_name => 'Fähnchen-Falterfisch';

  @override
  String get species_threadfin_butterflyfish_desc =>
      'Weißer Falterfisch mit Chevronmuster und fadenförmigem Fortsatz an der Rückenflosse, im gesamten Indopazifik verbreitet.';

  @override
  String get species_foureye_butterflyfish_name => 'Vieraugen-Falterfisch';

  @override
  String get species_foureye_butterflyfish_desc =>
      'Heller Falterfisch mit auffälligem falschem Augenfleck nahe der Schwanzwurzel, häufig an karibischen Riffen.';

  @override
  String get species_spotfin_butterflyfish_name => 'Fleckflossen-Falterfisch';

  @override
  String get species_spotfin_butterflyfish_desc =>
      'Weiß-gelber Falterfisch mit kleinem dunklem Fleck an der Rückenflosse, im Westatlantik verbreitet.';

  @override
  String get species_banner_butterflyfish_name => 'Rotmeer-Wimpelfisch';

  @override
  String get species_banner_butterflyfish_desc =>
      'Schwarz-weißer Wimpelfisch mit verlängerter Rückenflosse und gelbem Bauch, endemisch im Roten Meer.';

  @override
  String get species_moorish_idol_name => 'Halfterfisch';

  @override
  String get species_moorish_idol_desc =>
      'Ikonischer Rifffisch mit kräftigen schwarzen, weißen und gelben Binden und langem fadenförmigem Flossenfortsatz.';

  @override
  String get species_green_moray_eel_name => 'Grüne Muräne';

  @override
  String get species_green_moray_eel_desc =>
      'Große grüne Muräne von bis zu 2,5 m, oft mit geöffnetem Maul in Riffspalten des Westatlantiks.';

  @override
  String get species_giant_moray_eel_name => 'Riesenmuräne';

  @override
  String get species_giant_moray_eel_desc =>
      'Die größte Muränenart mit über 3 m Länge und leopardenartiger Fleckung. An Korallenriffen des Indopazifiks.';

  @override
  String get species_spotted_moray_eel_name => 'Gefleckte Muräne';

  @override
  String get species_spotted_moray_eel_desc =>
      'Weiße Muräne mit dunkelbraunen Flecken, die in der Karibik häufig aus Riffhöhlen hervorlugt.';

  @override
  String get species_ribbon_eel_name => 'Bandmuräne';

  @override
  String get species_ribbon_eel_desc =>
      'Schlanke Muräne mit gefransten Nasenlöchern; Männchen sind leuchtend blau, Weibchen gelb. In sandigen Lagunen des Indopazifiks.';

  @override
  String get species_spotted_garden_eel_name => 'Gefleckter Röhrenaal';

  @override
  String get species_spotted_garden_eel_desc =>
      'Dünner weißer Aal mit schwarzen Punkten, der in sandigen Kolonien lebt und sich in der Strömung wiegt, um Plankton zu fangen.';

  @override
  String get species_splendid_garden_eel_name => 'Prächtiger Röhrenaal';

  @override
  String get species_splendid_garden_eel_desc =>
      'Orange-weiß gebänderter Röhrenaal, der im Westpazifik große Kolonien im Sand bildet.';

  @override
  String get species_snowflake_moray_name => 'Schneeflocken-Muräne';

  @override
  String get species_snowflake_moray_desc =>
      'Kleine Muräne mit weißem Körper und schwarzer Schneeflockenzeichnung, häufig im Riffschutt des Indopazifiks.';

  @override
  String get species_mandarin_dragonet_name => 'Mandarinfisch';

  @override
  String get species_mandarin_dragonet_desc =>
      'Winziger, prächtig gefärbter Fisch mit psychedelischen blau-orangen Mustern, in den Geröllzonen des Westpazifiks.';

  @override
  String get species_common_lionfish_name => 'Rotfeuerfisch';

  @override
  String get species_common_lionfish_desc =>
      'Giftiger Skorpionfisch mit fächerartigen Brustflossen und rot-weißen Streifen. In der Karibik invasiv.';

  @override
  String get species_leaf_scorpionfish_name => 'Schaukelfisch';

  @override
  String get species_leaf_scorpionfish_desc =>
      'Stark abgeflachter, blattförmiger Skorpionfisch, der sich in der Strömung wiegt und an Riffen des Indopazifiks Treibgut nachahmt.';

  @override
  String get species_stonefish_name => 'Riff-Steinfisch';

  @override
  String get species_stonefish_desc =>
      'Giftigster Fisch der Welt, perfekt als Stein getarnt auf den Riffböden des Indopazifiks. Äußerst gefährlich.';

  @override
  String get species_painted_frogfish_name => 'Bemalter Anglerfisch';

  @override
  String get species_painted_frogfish_desc =>
      'Gedrungener Lauerjäger mit einer Angel auf dem Kopf und sehr variabler Färbung. An Riffen des Indopazifiks.';

  @override
  String get species_giant_frogfish_name => 'Riesen-Anglerfisch';

  @override
  String get species_giant_frogfish_desc =>
      'Die größte Anglerfischart mit bis zu 40 cm, hervorragend zwischen Schwämmen und Korallenschutt getarnt.';

  @override
  String get species_hairy_frogfish_name => 'Haariger Anglerfisch';

  @override
  String get species_hairy_frogfish_desc =>
      'Anglerfisch, dessen wurmartige Hautanhänge Algen nachahmen, ein begehrtes Motiv für Unterwasserfotografen.';

  @override
  String get species_clown_triggerfish_name => 'Leoparden-Drückerfisch';

  @override
  String get species_clown_triggerfish_desc =>
      'Auffällig gezeichneter Drückerfisch mit großen weißen Flecken auf dunklem Körper und gelben Lippen, an Riffen des Indopazifiks.';

  @override
  String get species_titan_triggerfish_name => 'Riesendrückerfisch';

  @override
  String get species_titan_triggerfish_desc =>
      'Großer aggressiver Drückerfisch, der Taucher in Nestnähe angreift. Häufig an Korallenriffen des Indopazifiks.';

  @override
  String get species_queen_triggerfish_name => 'Königin-Drückerfisch';

  @override
  String get species_queen_triggerfish_desc =>
      'Farbenprächtiger karibischer Drückerfisch mit blauen Gesichtszeichnungen und langen Schwanzfäden.';

  @override
  String get species_picasso_triggerfish_name => 'Picasso-Drückerfisch';

  @override
  String get species_picasso_triggerfish_desc =>
      'Drückerfisch mit abstraktem Muster aus blauen, gelben und schwarzen Streifen, häufig auf den Riffdächern des Indopazifiks.';

  @override
  String get species_yellowmargin_triggerfish_name => 'Gelbsaum-Drückerfisch';

  @override
  String get species_yellowmargin_triggerfish_desc =>
      'Großer beigefarbener Drückerfisch mit gelb gesäumten Flossen, bekannt für aggressive Nestverteidigung an Riffen des Indopazifiks.';

  @override
  String get species_porcupinefish_name => 'Igelfisch';

  @override
  String get species_porcupinefish_desc =>
      'Großer stacheliger Fisch, der sich bei Gefahr zur Kugel aufbläht, an tropischen Riffen weltweit.';

  @override
  String get species_guineafowl_pufferfish_name => 'Perlhuhn-Kugelfisch';

  @override
  String get species_guineafowl_pufferfish_desc =>
      'Dunkler Kugelfisch mit vielen kleinen weißen Punkten, an Riffen des Indopazifiks gelegentlich auch in einer goldgelben Farbphase.';

  @override
  String get species_map_pufferfish_name => 'Landkarten-Kugelfisch';

  @override
  String get species_map_pufferfish_desc =>
      'Großer heller Kugelfisch mit verschlungener dunkler Landkartenzeichnung über den ganzen Körper, an Riffen des Indopazifiks.';

  @override
  String get species_sharpnose_pufferfish_name => 'Spitzkopf-Kugelfisch';

  @override
  String get species_sharpnose_pufferfish_desc =>
      'Winziger Kugelfisch mit blauen Linien im Gesicht und orangefarbener Schwanzflosse, häufig an karibischen Riffen.';

  @override
  String get species_boxfish_name => 'Gelber Kofferfisch';

  @override
  String get species_boxfish_desc =>
      'Jungtiere sind leuchtend gelbe Würfel mit schwarzen Punkten. Adulte färben sich blaugrau. Im gesamten Indopazifik verbreitet.';

  @override
  String get species_cowfish_name => 'Langhorn-Kuhfisch';

  @override
  String get species_cowfish_desc =>
      'Kastenförmiger gelber Fisch mit auffälligen hornartigen Fortsätzen über jedem Auge, an Riffen des Indopazifiks.';

  @override
  String get species_napoleon_wrasse_name => 'Napoleon-Lippfisch';

  @override
  String get species_napoleon_wrasse_desc =>
      'Riesiger Lippfisch von bis zu 2 m mit ausgeprägtem Stirnbuckel. Gefährdet und geschützt, an Riffen des Indopazifiks.';

  @override
  String get species_cleaner_wrasse_name => 'Gewöhnlicher Putzerlippfisch';

  @override
  String get species_cleaner_wrasse_desc =>
      'Kleiner blau gestreifter Lippfisch, der Putzerstationen betreibt und größere Fische an Riffen des Indopazifiks von Parasiten befreit.';

  @override
  String get species_yellowtail_coris_name => 'Gelbschwanz-Junker';

  @override
  String get species_yellowtail_coris_desc =>
      'Farbenprächtiger Lippfisch mit geflecktem Körper und gelber Schwanzflosse; Jungtiere sind leuchtend orangerot mit weißen Zeichnungen.';

  @override
  String get species_bluehead_wrasse_name => 'Blaukopf-Lippfisch';

  @override
  String get species_bluehead_wrasse_desc =>
      'Häufiger karibischer Lippfisch; Terminalmännchen haben einen leuchtend blauen Kopf und grünen Körper mit schwarz-weißen Binden.';

  @override
  String get species_spanish_hogfish_name => 'Spanischer Schweinslippfisch';

  @override
  String get species_spanish_hogfish_desc =>
      'Violett-gelber Lippfisch, häufig an karibischen Riffen; Jungtiere arbeiten als Putzerfische.';

  @override
  String get species_bumphead_parrotfish_name => 'Büffelkopf-Papageifisch';

  @override
  String get species_bumphead_parrotfish_desc =>
      'Größte Papageifischart mit bis zu 1,3 m Länge und mächtigem Stirnbuckel. Zieht in Schulen über die Riffe des Indopazifiks.';

  @override
  String get species_stoplight_parrotfish_name => 'Ampel-Papageifisch';

  @override
  String get species_stoplight_parrotfish_desc =>
      'Häufiger karibischer Papageifisch mit auffälligem Farbwechsel zwischen Initial- und Terminalphase.';

  @override
  String get species_queen_parrotfish_name => 'Königin-Papageifisch';

  @override
  String get species_queen_parrotfish_desc =>
      'Großer blaugrüner Papageifisch an karibischen Riffen, oft beim Abbeißen von Korallen zur Algenaufnahme zu beobachten.';

  @override
  String get species_yellowtail_damselfish_name => 'Gelbschwanz-Riffbarsch';

  @override
  String get species_yellowtail_damselfish_desc =>
      'Dunkelblauer Riffbarsch mit leuchtend gelber Schwanzflosse, häufig auf karibischen Riffdächern und Riffkanten.';

  @override
  String get species_sergeant_major_name => 'Fünfbinden-Riffbarsch';

  @override
  String get species_sergeant_major_desc =>
      'Silbrig-gelber Riffbarsch mit fünf kräftigen schwarzen Binden, in großen Ansammlungen an tropischen Atlantikriffen.';

  @override
  String get species_three_spot_damselfish_name => 'Dreipunkt-Riffbarsch';

  @override
  String get species_three_spot_damselfish_desc =>
      'Dunkelbrauner, territorialer Riffbarsch, der seinen Algengarten an karibischen Riffen energisch verteidigt.';

  @override
  String get species_chromis_viridis_name => 'Blaugrüner Riffbarsch';

  @override
  String get species_chromis_viridis_desc =>
      'Kleiner schillernd grüner Riffbarsch, der in großen Schwärmen über Astkorallen an Riffen des Indopazifiks steht.';

  @override
  String get species_blue_chromis_name => 'Blauer Riffbarsch';

  @override
  String get species_blue_chromis_desc =>
      'Leuchtend blauer, planktonfressender Riffbarsch in großen Ansammlungen im Freiwasser über karibischen Riffwänden.';

  @override
  String get species_nassau_grouper_name => 'Nassau-Zackenbarsch';

  @override
  String get species_nassau_grouper_desc =>
      'Großer karibischer Zackenbarsch mit markantem dunklem Augenstreifen und Bänderzeichnung, durch Überfischung inzwischen gefährdet.';

  @override
  String get species_giant_grouper_name => 'Riesenzackenbarsch';

  @override
  String get species_giant_grouper_desc =>
      'Der größte Knochenfisch der Riffe, bis zu 2,7 m lang und 400 kg schwer. In Höhlen und Wracks im gesamten Indopazifik.';

  @override
  String get species_coral_grouper_name => 'Juwelen-Zackenbarsch';

  @override
  String get species_coral_grouper_desc =>
      'Leuchtend rotoranger Zackenbarsch mit blauen Punkten, eine Leitart der Korallenriffe des Indopazifiks.';

  @override
  String get species_goliath_grouper_name => 'Goliath-Zackenbarsch';

  @override
  String get species_goliath_grouper_desc =>
      'Riesiger atlantischer Zackenbarsch von bis zu 2,5 m, häufig an Wracks und Überhängen in Florida und der Karibik anzutreffen.';

  @override
  String get species_potato_grouper_name => 'Kartoffel-Zackenbarsch';

  @override
  String get species_potato_grouper_desc =>
      'Großer zutraulicher Zackenbarsch mit dunklen kartoffelförmigen Flecken, berühmt aus dem Cod Hole am Great Barrier Reef.';

  @override
  String get species_peacock_grouper_name => 'Pfauen-Zackenbarsch';

  @override
  String get species_peacock_grouper_desc =>
      'Dunkelbrauner Zackenbarsch mit leuchtend blauen Punkten und hellen Querbinden am Körperende, häufig an Riffen des Indopazifiks.';

  @override
  String get species_yellowfin_tuna_name => 'Gelbflossen-Thunfisch';

  @override
  String get species_yellowfin_tuna_desc =>
      'Schneller pelagischer Jäger mit langen gelben Rücken- und Afterflossen, den Taucher gelegentlich an vorgelagerten Plätzen sehen.';

  @override
  String get species_dogtooth_tuna_name => 'Hundszahn-Thunfisch';

  @override
  String get species_dogtooth_tuna_desc =>
      'Kräftiger riffnaher Thunfisch mit auffälligen Zähnen, an tiefen Riffabbrüchen im Indopazifik anzutreffen.';

  @override
  String get species_great_barracuda_name => 'Großer Barrakuda';

  @override
  String get species_great_barracuda_desc =>
      'Schlanker silbriger Jäger von bis zu 1,8 m mit markanten Zähnen, der oft reglos nahe tropischen Riffen steht.';

  @override
  String get species_blackfin_barracuda_name => 'Schwarzflossen-Barrakuda';

  @override
  String get species_blackfin_barracuda_desc =>
      'Indopazifischer Barrakuda, bekannt für gewaltige tornadoartige Schwärme an Tauchplätzen wie Barracuda Point.';

  @override
  String get species_mahi_mahi_name => 'Goldmakrele';

  @override
  String get species_mahi_mahi_desc =>
      'Schillernd blaugrün-goldener Hochseefisch mit stumpfer Stirn, gelegentlich an vorgelagerten Tauchplätzen zu sehen.';

  @override
  String get species_giant_trevally_name => 'Riesen-Stachelmakrele';

  @override
  String get species_giant_trevally_desc =>
      'Kräftiger silbriger Jäger von bis zu 1,7 m, bekannt für seine Jagd in Riffkanälen und an Steilwänden des Indopazifiks.';

  @override
  String get species_bluefin_trevally_name => 'Blaupunkt-Stachelmakrele';

  @override
  String get species_bluefin_trevally_desc =>
      'Schlanke, blau gepunktete Stachelmakrele, die in kleinen Jagdgruppen die Riffkanten des Indopazifiks abpatrouilliert.';

  @override
  String get species_bigeye_trevally_name => 'Großaugen-Stachelmakrele';

  @override
  String get species_bigeye_trevally_desc =>
      'Silbrige Stachelmakrele mit großen Augen, die eindrucksvolle wirbelnde Schwärme an Riffwänden und Putzerstationen bildet.';

  @override
  String get species_bar_jack_name => 'Blaustreifen-Stachelmakrele';

  @override
  String get species_bar_jack_desc =>
      'Schlanke silbrige Stachelmakrele der Karibik mit markantem dunkelblauem Streifen über Rücken und untere Schwanzflosse.';

  @override
  String get species_horse_eye_jack_name => 'Pferdeaugen-Stachelmakrele';

  @override
  String get species_horse_eye_jack_desc =>
      'Silbrige Stachelmakrele mit großen Augen, die in der Karibik und im Westatlantik Schwärme nahe Riffen und Wracks bildet.';

  @override
  String get species_yellowtail_snapper_name => 'Gelbschwanz-Schnapper';

  @override
  String get species_yellowtail_snapper_desc =>
      'Schlanker Schnapper mit gelbem Längsstreifen und gelber Schwanzflosse, oft in Freiwasserschwärmen an karibischen Riffen.';

  @override
  String get species_schoolmaster_snapper_name => 'Schulmeister-Schnapper';

  @override
  String get species_schoolmaster_snapper_desc =>
      'Gelb-silbriger Schnapper mit blauen Linien unter dem Auge, in Gruppen unter Überhängen karibischer Riffe.';

  @override
  String get species_bluestripe_snapper_name => 'Blaustreifen-Schnapper';

  @override
  String get species_bluestripe_snapper_desc =>
      'Leuchtend gelber Schnapper mit vier blauen Längsstreifen, der an Riffen des Indopazifiks dichte Schwärme bildet.';

  @override
  String get species_twinspot_snapper_name => 'Zweifleck-Schnapper';

  @override
  String get species_twinspot_snapper_desc =>
      'Großer roter Schnapper an Außenriffen des Indopazifiks, der an tiefen Wänden und in Kanälen mitunter Schwärme bildet.';

  @override
  String get species_humphead_snapper_name => 'Mitternachts-Schnapper';

  @override
  String get species_humphead_snapper_desc =>
      'Großer dunkler Schnapper in Schwärmen an steilen Abbrüchen des Indopazifiks, Jungtiere sind kontrastreich schwarz-weiß.';

  @override
  String get species_longfin_bannerfish_name => 'Gemeiner Wimpelfisch';

  @override
  String get species_longfin_bannerfish_desc =>
      'Schwarz-weißer Fisch mit langem fadenförmigem Rückenflossenstrahl und gelber Schwanzflosse, oft paarweise an Riffen des Indopazifiks.';

  @override
  String get species_batfish_orbicular_name => 'Rundkopf-Fledermausfisch';

  @override
  String get species_batfish_orbicular_desc =>
      'Silbriger scheibenförmiger Fisch mit hohen Flossen, der sich Tauchern neugierig nähert. Häufig an Wracks und Riffen des Indopazifiks.';

  @override
  String get species_batfish_teira_name => 'Langflossen-Fledermausfisch';

  @override
  String get species_batfish_teira_desc =>
      'Fledermausfisch mit hohen Flossen und einem dunklen Fleck nahe der Brustflosse, oft an Putzerstationen und Wracks zu sehen.';

  @override
  String get species_batfish_pinnatus_name => 'Rotsaum-Fledermausfisch';

  @override
  String get species_batfish_pinnatus_desc =>
      'Jungtiere sind tiefschwarz mit leuchtend orangefarbenen Säumen und ähneln einem giftigen Plattwurm. Im Westpazifik verbreitet.';

  @override
  String get species_banggai_cardinalfish_name => 'Banggai-Kardinalbarsch';

  @override
  String get species_banggai_cardinalfish_desc =>
      'Auffälliger silber-schwarzer Kardinalbarsch mit verlängerten Flossen, endemisch auf den Banggai-Inseln Indonesiens.';

  @override
  String get species_pajama_cardinalfish_name => 'Pyjama-Kardinalbarsch';

  @override
  String get species_pajama_cardinalfish_desc =>
      'Ungewöhnlicher Kardinalbarsch mit gelbem Gesicht, dunklem Gürtelband und geflecktem Hinterkörper, zwischen Korallen im Indopazifik.';

  @override
  String get species_longnose_hawkfish_name => 'Langnasen-Büschelbarsch';

  @override
  String get species_longnose_hawkfish_desc =>
      'Kleiner weißer Fisch mit rotem Gittermuster und langgezogener Schnauze, der auf Gorgonien und Schwarzen Korallen sitzt.';

  @override
  String get species_arc_eye_hawkfish_name => 'Bogenaugen-Büschelbarsch';

  @override
  String get species_arc_eye_hawkfish_desc =>
      'Kleiner Büschelbarsch mit markantem orangefarbenem Bogen hinter dem Auge, häufig auf Korallenstöcken der Riffe des Indopazifiks.';

  @override
  String get species_flame_hawkfish_name => 'Flammen-Büschelbarsch';

  @override
  String get species_flame_hawkfish_desc =>
      'Leuchtend roter Büschelbarsch mit dunklen Augenzeichnungen, der im Westpazifik in Pocillopora-Korallen sitzt.';

  @override
  String get species_fire_goby_name => 'Feuergrundel';

  @override
  String get species_fire_goby_desc =>
      'Elegante weiße Grundel mit hoher erster Rückenflosse und rotoranger Schwanzflosse, die über dem Riffschutt des Indopazifiks schwebt.';

  @override
  String get species_purple_firefish_name => 'Purpur-Feuergrundel';

  @override
  String get species_purple_firefish_desc =>
      'Zierliche Grundel mit violetten Flossen und hohem Rückenflossenstachel, die nahe ihrer Wohnröhre an Außenriffen des Indopazifiks schwebt.';

  @override
  String get species_yellownose_goby_name => 'Gelbnasen-Grundel';

  @override
  String get species_yellownose_goby_desc =>
      'Winzige karibische Putzergrundel mit gelber Schnauze und blauem Längsstreifen, auf Schwämmen und Korallenstöcken.';

  @override
  String get species_citron_goby_name => 'Zitronen-Korallengrundel';

  @override
  String get species_citron_goby_desc =>
      'Winzige leuchtend gelbe Grundel, die zwischen den Ästen von Acropora-Korallen an Riffen des Indopazifiks lebt.';

  @override
  String get species_shrimp_goby_name => 'Steinitz-Partnergrundel';

  @override
  String get species_shrimp_goby_desc =>
      'Sandfarbene Grundel, die auf den Sandflächen des Indopazifiks in einer Lebensgemeinschaft mit Knallkrebsen eine Wohnröhre teilt.';

  @override
  String get species_neon_goby_name => 'Neongrundel';

  @override
  String get species_neon_goby_desc =>
      'Winzige dunkle Grundel mit leuchtend neonblauem Streifen, die auf karibischen Korallenstöcken Putzerstationen betreibt.';

  @override
  String get species_bluestriped_fangblenny_name =>
      'Blaustreifen-Säbelzahnschleimfisch';

  @override
  String get species_bluestriped_fangblenny_desc =>
      'Kleiner blau gestreifter Schleimfisch, der Putzerlippfische nachahmt, um ahnungslosen Fischen Schuppen abzubeißen.';

  @override
  String get species_sailfin_blenny_name => 'Segelflossen-Schleimfisch';

  @override
  String get species_sailfin_blenny_desc =>
      'Winziger karibischer Schleimfisch, der aus seiner Wohnröhre eine große segelartige Rückenflosse aufstellt, um Partner anzulocken.';

  @override
  String get species_bicolor_blenny_name => 'Zweifarben-Schleimfisch';

  @override
  String get species_bicolor_blenny_desc =>
      'Kleiner Schleimfisch mit dunkelbrauner Vorder- und orangefarbener Hinterhälfte, der aus Löchern an Riffen des Indopazifiks lugt.';

  @override
  String get species_redlip_blenny_name => 'Rotlippen-Schleimfisch';

  @override
  String get species_redlip_blenny_desc =>
      'Dunkler Schleimfisch mit auffällig rotorangen Lippen, der Algenflächen auf karibischen Riffkanten verteidigt.';

  @override
  String get species_pygmy_seahorse_name => 'Bargibants Zwergseepferdchen';

  @override
  String get species_pygmy_seahorse_desc =>
      'Winziges Seepferdchen unter 2 cm, das seiner Wirtsgorgonie perfekt gleicht, ein begehrtes Motiv für die Makrofotografie.';

  @override
  String get species_common_seahorse_name => 'Gewöhnliches Seepferdchen';

  @override
  String get species_common_seahorse_desc =>
      'Mittelgroßes Seepferdchen in Seegraswiesen und Korallenschutt des Indopazifiks, in der Färbung sehr variabel.';

  @override
  String get species_thorny_seahorse_name => 'Dorniges Seepferdchen';

  @override
  String get species_thorny_seahorse_desc =>
      'Mit langen Stacheln besetztes Seepferdchen in Seegraswiesen und auf Weichböden des Indopazifiks.';

  @override
  String get species_ornate_ghost_pipefish_name =>
      'Harlekin-Geisterpfeifenfisch';

  @override
  String get species_ornate_ghost_pipefish_desc =>
      'Aufwendig getarnter Pfeifenfisch, der kopfüber nahe Haarsternen und Weichkorallen im Indopazifik schwebt.';

  @override
  String get species_robust_ghost_pipefish_name =>
      'Robuster Geisterpfeifenfisch';

  @override
  String get species_robust_ghost_pipefish_desc =>
      'Großer Geisterpfeifenfisch, der Seegras oder Algen nachahmt und oft paarweise in Küstengewässern des Indopazifiks zu finden ist.';

  @override
  String get species_trumpetfish_name => 'Trompetenfisch';

  @override
  String get species_trumpetfish_desc =>
      'Langer schlanker Fisch, der im Schatten größerer Fische jagt, an karibischen und atlantischen Riffen in verschiedenen Farben.';

  @override
  String get species_cornetfish_name => 'Flötenfisch';

  @override
  String get species_cornetfish_desc =>
      'Extrem langgestreckter Fisch von bis zu 1,5 m mit fadenförmigem Schwanzanhang, der oft über Riffdächer gleitet.';

  @override
  String get species_yellowhead_jawfish_name => 'Gelbkopf-Kieferfisch';

  @override
  String get species_yellowhead_jawfish_desc =>
      'Kleiner Fisch mit blauem Körper und gelbem Kopf, der über seiner Sandröhre an karibischen Riffen schwebt. Männchen tragen die Eier im Maul.';

  @override
  String get species_flamefish_name => 'Flammen-Kardinalbarsch';

  @override
  String get species_flamefish_desc =>
      'Kleiner leuchtend roter Kardinalbarsch mit dunklem Fleck unter der zweiten Rückenflosse, tagsüber in karibischen Riffspalten versteckt.';

  @override
  String get species_longspine_squirrelfish_name => 'Langstachel-Husarenfisch';

  @override
  String get species_longspine_squirrelfish_desc =>
      'Roter nachtaktiver Fisch mit großen Augen und langem Rückenflossenstachel, tagsüber unter Überhängen karibischer Riffe.';

  @override
  String get species_soldierfish_name => 'Großschuppen-Soldatenfisch';

  @override
  String get species_soldierfish_desc =>
      'Roter nachtaktiver Fisch mit riesigen dunklen Augen und großen Schuppen, tagsüber in Gruppen in Höhlen und unter Überhängen.';

  @override
  String get species_flame_angelfish_name => 'Flammen-Zwergkaiserfisch';

  @override
  String get species_flame_angelfish_desc =>
      'Leuchtend rotoranger Zwergkaiserfisch mit schwarzen Querbinden und blau gesäumten Flossen, im gesamten Pazifik verbreitet.';

  @override
  String get species_royal_gramma_name => 'Königs-Feenbarsch';

  @override
  String get species_royal_gramma_desc =>
      'Kleiner zweifarbiger karibischer Feenbarsch mit violetter Vorder- und gelber Hinterhälfte, unter Überhängen zu finden.';

  @override
  String get species_anthias_lyretail_name => 'Juwelen-Fahnenbarsch';

  @override
  String get species_anthias_lyretail_desc =>
      'Häufiger Rifffisch, der große orange und rosa Wolken über den Korallenstöcken des Indopazifiks bildet. Männchen sind violett.';

  @override
  String get species_mediterranean_grouper_name => 'Brauner Zackenbarsch';

  @override
  String get species_mediterranean_grouper_desc =>
      'Großer dunkelbrauner Zackenbarsch mit heller Marmorierung, der ikonische Jäger der Felsriffe des Mittelmeers.';

  @override
  String get species_mediterranean_moray_name => 'Mittelmeer-Muräne';

  @override
  String get species_mediterranean_moray_desc =>
      'Dunkelbraune Muräne mit gelber Marmorierung, die im Mittelmeer häufig aus Felsspalten hervorlugt.';

  @override
  String get species_ornate_wrasse_name => 'Meerpfau';

  @override
  String get species_ornate_wrasse_desc =>
      'Farbenprächtiger grüner Lippfisch mit roten Kopfzeichnungen, einer der häufigsten Lippfische an Mittelmeerriffen.';

  @override
  String get species_red_sea_bannerfish_name => 'Masken-Falterfisch';

  @override
  String get species_red_sea_bannerfish_desc =>
      'Leuchtend gelber Falterfisch mit dunklem Augenfleck, endemisch im Roten Meer. Oft paarweise zu sehen.';

  @override
  String get species_red_sea_anemonefish_name => 'Rotmeer-Anemonenfisch';

  @override
  String get species_red_sea_anemonefish_desc =>
      'Orangegelber Anemonenfisch mit zwei weißen Binden, endemisch im Roten Meer und im Golf von Aden.';

  @override
  String get species_arabian_angelfish_name => 'Arabischer Kaiserfisch';

  @override
  String get species_arabian_angelfish_desc =>
      'Großer dunkelblauer Kaiserfisch mit kräftiger gelber Querbinde und gelber Schwanzflosse, endemisch im westlichen Indischen Ozean.';

  @override
  String get species_king_angelfish_name => 'Königs-Kaiserfisch';

  @override
  String get species_king_angelfish_desc =>
      'Großer dunkelblauer Kaiserfisch mit weißer Querbinde und gelber Schwanzflosse, im Ostpazifik und um Galapagos verbreitet.';

  @override
  String get species_ocean_sunfish_name => 'Mondfisch';

  @override
  String get species_ocean_sunfish_desc =>
      'Der schwerste Knochenfisch mit über 2 Tonnen Gewicht. Gelegentlich von Tauchern an Putzerstationen vor Bali und Galapagos gesichtet.';

  @override
  String get species_lingcod_name => 'Lingcod';

  @override
  String get species_lingcod_desc =>
      'Großer gefleckter Raubgrünling an den Felsriffen des pazifischen Nordwestens, oft beim Bewachen seiner Laichballen.';

  @override
  String get species_wolf_eel_name => 'Wolfsaal';

  @override
  String get species_wolf_eel_desc =>
      'Großer grauer Wolfsaal mit wulstigem Kopf und kräftigen Kiefern, in Felshöhlen des pazifischen Nordwestens.';

  @override
  String get species_giant_sea_bass_name => 'Kalifornischer Riesenbarsch';

  @override
  String get species_giant_sea_bass_desc =>
      'Gewaltiger Barsch von über 2 m und 250 kg, an Felsriffen und in Kelpwäldern vor Südkalifornien.';

  @override
  String get species_garibaldi_name => 'Garibaldi';

  @override
  String get species_garibaldi_desc =>
      'Leuchtend oranger Riffbarsch und offizieller Meeresfisch Kaliforniens, territorial an den Riffen der Kelpwälder.';

  @override
  String get species_sheephead_name => 'Kalifornischer Schafskopf-Lippfisch';

  @override
  String get species_sheephead_desc =>
      'Großer Lippfisch mit schwarzem Kopf und Schwanz, rotem Mittelteil und weißem Kinn. In den Kelpwäldern Kaliforniens.';

  @override
  String get species_copper_rockfish_name => 'Kupfer-Rotbarsch';

  @override
  String get species_copper_rockfish_desc =>
      'Kupferorangefarbener Rotbarsch mit hellen Flecken, ein häufiger Anblick an Felsriffen und in Kelpwäldern des pazifischen Nordwestens.';

  @override
  String get species_oriental_sweetlips_name => 'Orientalische Süßlippe';

  @override
  String get species_oriental_sweetlips_desc =>
      'Großer Rifffisch des Indopazifiks mit kräftigen schwarz-weißen Streifen und gelben Flossen. Jungtiere vollführen einen wackelnden Tanz.';

  @override
  String get species_harlequin_sweetlips_name => 'Harlekin-Süßlippe';

  @override
  String get species_harlequin_sweetlips_desc =>
      'Adulte sind grau mit dunklen Punkten; Jungtiere sind braun mit großen weißen Flecken und schwimmen in wogenden Bewegungen.';

  @override
  String get species_blue_ringed_angelfish_name => 'Blauring-Kaiserfisch';

  @override
  String get species_blue_ringed_angelfish_desc =>
      'Großer brauner Kaiserfisch mit blauen Bogenlinien und einem markanten blauen Ring über dem Kiemendeckel.';

  @override
  String get species_yellowbar_angelfish_name => 'Gelbband-Kaiserfisch';

  @override
  String get species_yellowbar_angelfish_desc =>
      'Großer graublauer Kaiserfisch mit auffälligem gelbem Fleck am Körper, im Roten Meer und im westlichen Indischen Ozean.';

  @override
  String get species_filefish_scrawled_name => 'Gekritzelter Feilenfisch';

  @override
  String get species_filefish_scrawled_desc =>
      'Großer olivbrauner Feilenfisch mit blauen Kritzelzeichnungen und orangefarbenem Kehlsack, an tropischen Riffen weltweit.';

  @override
  String get species_clown_filefish_name => 'Orangepunkt-Feilenfisch';

  @override
  String get species_clown_filefish_desc =>
      'Kleiner grüner Feilenfisch mit orangefarbenen Punkten und langer Schnauze, der sich ausschließlich von Acropora-Korallenpolypen ernährt.';

  @override
  String get species_unicornfish_name => 'Blaudorn-Nasendoktorfisch';

  @override
  String get species_unicornfish_desc =>
      'Grauer Doktorfisch mit markantem Stirnhorn und zwei blauen Schwanzdornen, häufig auf den Riffdächern des Indopazifiks.';

  @override
  String get species_surgeonfish_sailfin_name => 'Segelflossen-Doktorfisch';

  @override
  String get species_surgeonfish_sailfin_desc =>
      'Kräftig gebänderter Doktorfisch mit stark vergrößerter Rücken- und Afterflosse, im gesamten Indopazifik verbreitet.';

  @override
  String get species_achilles_tang_name => 'Achilles-Doktorfisch';

  @override
  String get species_achilles_tang_desc =>
      'Dunkelbrauner Doktorfisch mit auffälligem orangefarbenem Tropfen nahe der Schwanzflosse, in den Brandungszonen des Zentralpazifiks.';

  @override
  String get species_doctorfish_name => 'Karibischer Doktorfisch';

  @override
  String get species_doctorfish_desc =>
      'Graubrauner Doktorfisch mit schwachen dunklen Querbinden und markantem Skalpell am Schwanz, häufig an karibischen Riffen.';

  @override
  String get species_checkerboard_wrasse_name => 'Schachbrett-Lippfisch';

  @override
  String get species_checkerboard_wrasse_desc =>
      'Farbenprächtiger Lippfisch mit einem Schachbrettmuster aus grünen, rosafarbenen und schwarzen Feldern über den ganzen Körper.';

  @override
  String get species_bird_wrasse_name => 'Vogel-Lippfisch';

  @override
  String get species_bird_wrasse_desc =>
      'Lippfisch mit extrem langgezogener, schnabelartiger Schnauze; Männchen sind dunkelgrün, Weibchen braun.';

  @override
  String get species_sling_jaw_wrasse_name => 'Schleuderkiefer-Lippfisch';

  @override
  String get species_sling_jaw_wrasse_desc =>
      'Lippfisch mit ausfahrbarem Kiefer, der zum Beutefang vorschnellt, in gelben oder braunen Farbvarianten.';

  @override
  String get species_peacock_flounder_name => 'Pfauenaugen-Flunder';

  @override
  String get species_peacock_flounder_desc =>
      'Flacher Bodenfisch mit blauen Ringen und Punkten, der seine Färbung dem Meeresboden anpassen kann.';

  @override
  String get species_hogfish_name => 'Schweinslippfisch';

  @override
  String get species_hogfish_desc =>
      'Großer Lippfisch des Westatlantiks mit schweineartiger Schnauze und verlängerten Rückenflossenstacheln, nahe Riffen und Wracks.';

  @override
  String get species_tarpon_name => 'Atlantischer Tarpun';

  @override
  String get species_tarpon_desc =>
      'Riesiger silbriger Fisch mit großen spiegelnden Schuppen, dem Taucher gelegentlich in karibischen Höhlen und Kanälen begegnen.';

  @override
  String get species_permit_name => 'Permit';

  @override
  String get species_permit_desc =>
      'Hochrückige silbrige Stachelmakrele mit dunkler Gabelschwanzflosse, auf karibischen Sandflächen und nahe Riffen.';

  @override
  String get species_spotted_drum_name => 'Gepunkteter Ritterfisch';

  @override
  String get species_spotted_drum_desc =>
      'Auffälliger karibischer Fisch mit hoher, langgezogener Rückenflosse und kräftigem schwarz-weißem Punktmuster.';

  @override
  String get species_jackknife_fish_name => 'Lanzen-Ritterfisch';

  @override
  String get species_jackknife_fish_desc =>
      'Eleganter karibischer Fisch mit hohem schwarzem Rückenflossenstreifen und diagonaler Körperbinde, unter Überhängen zu finden.';

  @override
  String get species_bigeye_name => 'Glasaugenbarsch';

  @override
  String get species_bigeye_desc =>
      'Leuchtend roter nachtaktiver Fisch mit großen reflektierenden Augen, tagsüber in Höhlen karibischer und atlantischer Riffe versteckt.';

  @override
  String get species_remora_name => 'Schiffshalter';

  @override
  String get species_remora_desc =>
      'Schlanker Fisch mit einer Saugscheibe auf dem Kopf, der sich an Haien, Rochen, Schildkröten und anderen großen Tieren anheftet.';

  @override
  String get species_tilefish_sand_name => 'Sand-Ziegelbarsch';

  @override
  String get species_tilefish_sand_desc =>
      'Langgestreckter hellblauer Fisch, der über den Sandflächen karibischer Riffe Hügel aus Geröll aufschichtet.';

  @override
  String get species_weedy_seadragon_name => 'Gemeiner Seedrache';

  @override
  String get species_weedy_seadragon_desc =>
      'Prächtiger Verwandter der Seepferdchen mit blattartigen Anhängen, endemisch in den gemäßigten Gewässern Südaustraliens.';

  @override
  String get species_leafy_seadragon_name => 'Fetzenfisch';

  @override
  String get species_leafy_seadragon_desc =>
      'Spektakulärer Seedrache mit ausladenden blattartigen Fortsätzen, endemisch in Südaustralien. Eine Sichtung für die Wunschliste.';

  @override
  String get species_sailfin_snapper_name => 'Segelflossen-Schnapper';

  @override
  String get species_sailfin_snapper_desc =>
      'Eleganter gelb-blauer Schnapper mit verlängerten Rücken- und Afterflossen, an den Riffhängen des Indopazifiks.';

  @override
  String get species_sweetlip_emperor_name => 'Gefleckte Kaiserbrasse';

  @override
  String get species_sweetlip_emperor_desc =>
      'Große silbrige Kaiserbrasse mit blauen Linien im Gesicht und gelb gesäumten Flossen, häufig über sandigen Riffbereichen des Indopazifiks.';

  @override
  String get species_crocodilefish_name => 'Krokodilfisch';

  @override
  String get species_crocodilefish_desc =>
      'Flachköpfiger Lauerjäger mit kunstvollen Augenfransen, der perfekt getarnt auf den Riffböden des Indopazifiks liegt.';

  @override
  String get species_devil_scorpionfish_name => 'Teufels-Drachenkopf';

  @override
  String get species_devil_scorpionfish_desc =>
      'Gedrungener getarnter Skorpionfisch, der Fressfeinden die farbigen Innenseiten seiner Brustflossen als Warnung zeigt.';

  @override
  String get species_spiny_devilfish_name => 'Teufelsfisch';

  @override
  String get species_spiny_devilfish_desc =>
      'Giftiger Bodenbewohner, der auf umgebildeten Flossenstrahlen läuft und bei Störung leuchtende Brustflossen aufblitzen lässt.';

  @override
  String get species_waspfish_name => 'Kakadu-Wespenfisch';

  @override
  String get species_waspfish_desc =>
      'Kleiner hochrückiger Skorpionfisch, der sich auf den Schlickböden des Indopazifiks wie ein totes Blatt in der Strömung wiegt.';

  @override
  String get species_stargazer_name => 'Weißsaum-Himmelsgucker';

  @override
  String get species_stargazer_desc =>
      'Lauerjäger, der sich bis auf die Augen im Sand eingräbt und Stromschläge austeilen kann. Im Indopazifik verbreitet.';

  @override
  String get species_striped_catfish_name => 'Gestreifter Korallenwels';

  @override
  String get species_striped_catfish_desc =>
      'Wels mit Giftstacheln; Jungtiere bilden dichte kugelförmige Schwärme, die über die Riffböden des Indopazifiks rollen.';

  @override
  String get species_red_emperor_name => 'Kaiserschnapper';

  @override
  String get species_red_emperor_desc =>
      'Großer Schnapper; Adulte sind rosarot, Jungtiere tragen kräftige rot-weiße Binden. An Riffen des Indopazifiks.';

  @override
  String get species_mangrove_snapper_name => 'Mangroven-Schnapper';

  @override
  String get species_mangrove_snapper_desc =>
      'Grauer Schnapper in karibischen Mangroven, Seegraswiesen und Riffen, oft in Ansammlungen nahe Strukturen.';

  @override
  String get species_dottyback_orchid_name => 'Orchideen-Zwergbarsch';

  @override
  String get species_dottyback_orchid_desc =>
      'Kleiner leuchtend violetter Fisch, endemisch im Roten Meer, der an steilen Riffwänden in Spalten hinein- und hinausschießt.';

  @override
  String get species_dottyback_royal_name => 'Königs-Zwergbarsch';

  @override
  String get species_dottyback_royal_desc =>
      'Kleiner zweifarbiger Fisch mit magentafarbener Vorder- und leuchtend gelber Hinterhälfte, an Riffwänden des Indopazifiks.';

  @override
  String get species_coral_trout_name => 'Forellen-Zackenbarsch';

  @override
  String get species_coral_trout_desc =>
      'Begehrter Jäger des Great Barrier Reef mit orangerotem Körper voller blauer Punkte.';

  @override
  String get species_barramundi_cod_name => 'Masken-Zackenbarsch';

  @override
  String get species_barramundi_cod_desc =>
      'Markanter Zackenbarsch mit kleinem Kopf, gebuckeltem Körper und dunklen Tupfen auf hellem Grund.';

  @override
  String get species_spadefish_atlantic_name => 'Atlantischer Fledermausfisch';

  @override
  String get species_spadefish_atlantic_desc =>
      'Silbriger scheibenförmiger Fisch mit dunklen Querbinden, oft in großen Schwärmen an karibischen Wracks.';

  @override
  String get species_fusilier_yellowback_name => 'Gelbrücken-Füsilier';

  @override
  String get species_fusilier_yellowback_desc =>
      'Schlanker blauer Planktonfresser mit gelbem Rücken, der gewaltige Schwärme über den Riffhängen des Indopazifiks bildet.';

  @override
  String get species_fusilier_bluestreak_name => 'Blaustreifen-Füsilier';

  @override
  String get species_fusilier_bluestreak_desc =>
      'Kleiner blauer Füsilier mit dunklem Längsstreifen, in schnellen Schwärmen entlang der Riffwände des Indopazifiks.';

  @override
  String get species_porkfish_name => 'Ferkelfisch';

  @override
  String get species_porkfish_desc =>
      'Farbenprächtiger karibischer Grunzer mit blauen und gelben Streifen und zwei schwarzen Kopfbinden, nahe Riffen und Wracks.';

  @override
  String get species_blue_striped_grunt_name => 'Blaustreifen-Grunzer';

  @override
  String get species_blue_striped_grunt_desc =>
      'Gelber karibischer Grunzer mit kräftigen blauen Längsstreifen, der tagsüber große Ruheschwärme unter Überhängen bildet.';

  @override
  String get species_french_grunt_name => 'Franzosen-Grunzer';

  @override
  String get species_french_grunt_desc =>
      'Kleiner gelb gestreifter Grunzer, der tagsüber dichte Ruheschwärme an karibischen Riffen bildet.';

  @override
  String get species_convict_tang_name => 'Sträflings-Doktorfisch';

  @override
  String get species_convict_tang_desc =>
      'Heller Doktorfisch mit sechs senkrechten schwarzen Binden, oft in großen Schwärmen beim Weiden auf den Riffdächern des Indopazifiks.';

  @override
  String get species_great_hammerhead_name => 'Bogenstirn-Hammerhai';

  @override
  String get species_great_hammerhead_desc =>
      'Markanter Hai mit gebogenem hammerförmigem Kopf, der an Seebergen und vorgelagerten Inseln große Schulen bildet.';

  @override
  String get species_wobbegong_name => 'Gefleckter Teppichhai';

  @override
  String get species_wobbegong_desc =>
      'Flacher, gut getarnter Teppichhai mit Hautfransen rund um das Maul, an den gemäßigten Riffen Australiens.';

  @override
  String get species_manta_ray_name => 'Riffmanta';

  @override
  String get species_manta_ray_desc =>
      'Anmutiger Riese mit bis zu 5 m Spannweite, der Putzerstationen aufsucht und an Riffen des Indopazifiks Plankton frisst.';

  @override
  String get species_oceanic_manta_name => 'Riesenmanta';

  @override
  String get species_oceanic_manta_desc =>
      'Die größte Rochenart mit über 7 m Spannweite, an vorgelagerten Seebergen und Putzerstationen anzutreffen.';

  @override
  String get species_undulated_moray_name => 'Wellenlinien-Muräne';

  @override
  String get species_undulated_moray_desc =>
      'Gelbgrüne Muräne mit dunkler Wellenzeichnung, die nachts häufig an Riffen des Indopazifiks jagt.';

  @override
  String get species_whitemouth_moray_name => 'Weißmaul-Muräne';

  @override
  String get species_whitemouth_moray_desc =>
      'Dunkelbraune Muräne mit kleinen weißen Punkten und auffällig weißem Maulinneren, im gesamten Indopazifik verbreitet.';

  @override
  String get species_dragon_moray_name => 'Drachenmuräne';

  @override
  String get species_dragon_moray_desc =>
      'Auffällige Muräne mit drachenartigen Hörnern über den Nasenlöchern und orangeroten Leopardenflecken, im Indopazifik verbreitet.';

  @override
  String get species_lyretail_grouper_name => 'Mondsichel-Zackenbarsch';

  @override
  String get species_lyretail_grouper_desc =>
      'Rotrosa Zackenbarsch mit blauen Punkten und markanter sichelförmiger Schwanzflosse, an den Außenriffwänden des Indopazifiks.';

  @override
  String get species_banded_butterflyfish_name => 'Gebänderter Falterfisch';

  @override
  String get species_banded_butterflyfish_desc =>
      'Weißer Falterfisch mit vier kräftigen schwarzen Querbinden, einer der häufigsten Falterfische karibischer Riffe.';

  @override
  String get species_ringed_pipefish_name => 'Ringel-Seenadel';

  @override
  String get species_ringed_pipefish_desc =>
      'Schlanke Seenadel mit abwechselnd roten und weißen Ringen, in Höhlen und unter Überhängen an Riffen des Indopazifiks.';

  @override
  String get species_razorfish_name => 'Rasiermesserfisch';

  @override
  String get species_razorfish_desc =>
      'Winziger Fisch, der in Gruppen kopfüber senkrecht schwimmt und sich oft zwischen Seeigelstacheln an Riffen des Indopazifiks versteckt.';

  @override
  String get species_harlequin_tuskfish_name => 'Harlekin-Lippfisch';

  @override
  String get species_harlequin_tuskfish_desc =>
      'Farbenprächtiger Lippfisch mit leuchtend blauen Hauzähnen, rotorangen Binden und weißen Feldern, an Riffen des Westpazifiks.';

  @override
  String get species_blue_groper_name => 'Blauer Riesenlippfisch';

  @override
  String get species_blue_groper_desc =>
      'Großer blauer Lippfisch, endemisch in Ostaustralien, zutraulich und Tauchern an gemäßigten Riffen oft nahe kommend.';

  @override
  String get species_red_lipped_batfish_name => 'Rotlippen-Fledermausfisch';

  @override
  String get species_red_lipped_batfish_desc =>
      'Bizarrer flachgebauter Fisch mit leuchtend roten Lippen, der auf umgebildeten Flossen über den Meeresboden von Galapagos läuft.';

  @override
  String get species_orangeband_surgeonfish_name => 'Orangeband-Doktorfisch';

  @override
  String get species_orangeband_surgeonfish_desc =>
      'Graubrauner Doktorfisch mit orangefarbenem Längsband hinter dem Auge, an den Riffhängen des Pazifiks.';

  @override
  String get species_maori_wrasse_name => 'Maori-Lippfisch';

  @override
  String get species_maori_wrasse_desc =>
      'Mittelgroßer Lippfisch mit dunkler Binde hinter der Brustflosse, häufig an Riffen des Pazifiks und des Indischen Ozeans.';

  @override
  String get species_blue_ringed_octopus_name => 'Blaugeringelter Krake';

  @override
  String get species_blue_ringed_octopus_desc =>
      'Kleiner, aber extrem giftiger Krake mit leuchtend blauen Ringen, die bei Bedrohung aufblitzen.';

  @override
  String get species_common_octopus_name => 'Gewöhnlicher Krake';

  @override
  String get species_common_octopus_desc =>
      'Hochintelligenter Krake, bekannt für schnelle Farbwechsel und seine Fähigkeit, Probleme zu lösen.';

  @override
  String get species_giant_pacific_octopus_name => 'Riesenkrake';

  @override
  String get species_giant_pacific_octopus_desc =>
      'Die größte Krakenart mit Armspannweiten von über 4 Metern in den kalten Gewässern des Pazifiks.';

  @override
  String get species_mimic_octopus_name => 'Mimik-Krake';

  @override
  String get species_mimic_octopus_desc =>
      'Bemerkenswerter Krake, der Aussehen und Verhalten anderer Meerestiere nachahmt.';

  @override
  String get species_coconut_octopus_name => 'Kokosnuss-Krake';

  @override
  String get species_coconut_octopus_desc =>
      'Kleiner Krake, berühmt dafür, Kokosnussschalen mitzutragen und als tragbaren Unterschlupf zu nutzen.';

  @override
  String get species_day_octopus_name => 'Tagkrake';

  @override
  String get species_day_octopus_desc =>
      'Tagaktiver Jäger mit beeindruckenden Tarnfähigkeiten, häufig an Riffen des Indopazifiks.';

  @override
  String get species_wonderpus_octopus_name => 'Wunderpus-Krake';

  @override
  String get species_wonderpus_octopus_desc =>
      'Auffälliger Krake mit einzigartiger weiß-brauner Bänderung, an sandigen Muck-Tauchplätzen zu finden.';

  @override
  String get species_broadclub_cuttlefish_name => 'Breitkeulen-Sepia';

  @override
  String get species_broadclub_cuttlefish_desc =>
      'Große Sepia mit hypnotisierenden Farbspielen, häufig an Riffen des Indopazifiks zu sehen.';

  @override
  String get species_pharaoh_cuttlefish_name => 'Pharao-Sepia';

  @override
  String get species_pharaoh_cuttlefish_desc =>
      'Große Sepia aus dem Indischen Ozean, bekannt für ihre pulsierenden Farbmuster.';

  @override
  String get species_flamboyant_cuttlefish_name => 'Pfeffers Prachtsepia';

  @override
  String get species_flamboyant_cuttlefish_desc =>
      'Winzige Sepia, die über den Meeresboden läuft und dabei kräftige violette, rosa und gelbe Farbwellen zeigt.';

  @override
  String get species_giant_cuttlefish_name => 'Riesensepia';

  @override
  String get species_giant_cuttlefish_desc =>
      'Die größte Sepia der Welt, berühmt für ihre Massenlaichansammlungen in Südaustralien.';

  @override
  String get species_bigfin_reef_squid_name => 'Großflossen-Riffkalmar';

  @override
  String get species_bigfin_reef_squid_desc =>
      'Schwarmbildender Kalmar, dem man häufig bei Nachttauchgängen begegnet, angezogen von Tauchlampen.';

  @override
  String get species_caribbean_reef_squid_name => 'Karibischer Riffkalmar';

  @override
  String get species_caribbean_reef_squid_desc =>
      'Neugieriger Kalmar, der in der Karibik oft in kleinen Gruppen nahe Riffkanten schwebt.';

  @override
  String get species_bobtail_squid_name => 'Zwergtintenfisch';

  @override
  String get species_bobtail_squid_desc =>
      'Winziger nachtaktiver Tintenfisch, der sich tagsüber im Sand eingräbt, ein begehrter Fund beim Muck-Tauchen.';

  @override
  String get species_chambered_nautilus_name => 'Perlboot';

  @override
  String get species_chambered_nautilus_desc =>
      'Urtümliches lebendes Fossil mit gewundener Schale, das Taucher nur selten im tiefen Wasser bei Tagesanbruch sehen.';

  @override
  String get species_spanish_dancer_name => 'Spanische Tänzerin';

  @override
  String get species_spanish_dancer_desc =>
      'Größte Nacktschneckenart, die mit wogendem rotem Mantel schwimmt und dabei an eine Flamencotänzerin erinnert.';

  @override
  String get species_chromodoris_willani_name => 'Willans Sternschnecke';

  @override
  String get species_chromodoris_willani_desc =>
      'Auffällige blau-schwarze Nacktschnecke mit weißem Saum, im Indopazifik häufig.';

  @override
  String get species_chromodoris_lochi_name => 'Lochs Sternschnecke';

  @override
  String get species_chromodoris_lochi_desc =>
      'Blaue Nacktschnecke mit dunklen Linien und weißem Rand, im gesamten tropischen Pazifik verbreitet.';

  @override
  String get species_chromodoris_magnifica_name => 'Prächtige Sternschnecke';

  @override
  String get species_chromodoris_magnifica_desc =>
      'Leuchtend blaue, weiße und orangefarbene Nacktschnecke auf Korallenriffen des Indopazifiks.';

  @override
  String get species_chromodoris_annae_name => 'Annas Sternschnecke';

  @override
  String get species_chromodoris_annae_desc =>
      'Tiefblaue Nacktschnecke mit schwarzen Linien und orange gespitzten Rhinophoren und Kiemen.';

  @override
  String get species_nembrotha_kubaryana_name => 'Variable Neon-Nacktschnecke';

  @override
  String get species_nembrotha_kubaryana_desc =>
      'Dunkelgrüne Nacktschnecke mit leuchtend orangen oder roten Zeichnungen, die sich von Manteltieren ernährt.';

  @override
  String get species_nembrotha_cristata_name => 'Kamm-Nembrotha';

  @override
  String get species_nembrotha_cristata_desc =>
      'Schwarze Nacktschnecke mit leuchtend grünen Pusteln und Streifen, an Riffen des Indopazifiks.';

  @override
  String get species_phyllidia_varicosa_name => 'Warzige Phyllidia';

  @override
  String get species_phyllidia_varicosa_desc =>
      'Blaugraue Nacktschnecke mit erhabenen, gelb gespitzten Höckern, für Fressfeinde giftig.';

  @override
  String get species_phyllidia_ocellata_name => 'Augenfleck-Phyllidia';

  @override
  String get species_phyllidia_ocellata_desc =>
      'Weiße Nacktschnecke mit erhabenen, rosa umringten Höckern, an tropischen Riffen.';

  @override
  String get species_pikachu_nudibranch_name => 'Pikachu-Nacktschnecke';

  @override
  String get species_pikachu_nudibranch_desc =>
      'Winzige gelb-schwarze Meeresschnecke, die einer Zeichentrickfigur ähnelt, im Pazifik verbreitet.';

  @override
  String get species_anna_rosefieldi_name => 'Roboastra-Nacktschnecke';

  @override
  String get species_anna_rosefieldi_desc =>
      'Räuberische Nacktschnecke mit dunklem Körper und leuchtenden Längsstreifen, die andere Schnecken jagt.';

  @override
  String get species_lettuce_sea_slug_name => 'Salat-Meeresschnecke';

  @override
  String get species_lettuce_sea_slug_desc =>
      'Gekräuselte grüne Meeresschnecke, die Chloroplasten aus Algen für die Photosynthese behält.';

  @override
  String get species_blue_dragon_nudibranch_name => 'Blaudrachen-Nacktschnecke';

  @override
  String get species_blue_dragon_nudibranch_desc =>
      'Lange Fadenschnecke mit blau gespitzten Cerata, die symbiotische Zooxanthellen beherbergt.';

  @override
  String get species_gloomy_nudibranch_name => 'Düstere Nacktschnecke';

  @override
  String get species_gloomy_nudibranch_desc =>
      'Dunkel blaugrüne Nacktschnecke mit blau gesäumten Leisten, häufig an Riffen des Indopazifiks.';

  @override
  String get species_ocellined_nudibranch_name => 'Ozellierte Nacktschnecke';

  @override
  String get species_ocellined_nudibranch_desc =>
      'Weiße Nacktschnecke mit orange gesäumten Leisten, die geometrische Muster auf ihrem Mantel bilden.';

  @override
  String get species_glossodoris_cincta_name => 'Glossodoris-Nacktschnecke';

  @override
  String get species_glossodoris_cincta_desc =>
      'Cremefarbene Nacktschnecke mit dunkelbraunem Rand und orangefarbenem Saum am Mantel.';

  @override
  String get species_jorunna_funebris_name => 'Getupfte Nacktschnecke';

  @override
  String get species_jorunna_funebris_desc =>
      'Weiße Nacktschnecke, übersät mit schwarz gespitzten Caryophyllidien, die an ein flauschiges Häschen erinnert.';

  @override
  String get species_ceratosoma_trilobatum_name => 'Dreilappige Nacktschnecke';

  @override
  String get species_ceratosoma_trilobatum_desc =>
      'Große Nacktschnecke mit hohem Rückenhorn und seitlichen Lappen in violetten und gelben Tönen.';

  @override
  String get species_hypselodoris_apolegma_name => 'Violette Hypselodoris';

  @override
  String get species_hypselodoris_apolegma_desc =>
      'Elegante violette Nacktschnecke mit weißem Mantelsaum, an Riffen des Indopazifiks.';

  @override
  String get species_hypselodoris_bullockii_name => 'Bullocks Hypselodoris';

  @override
  String get species_hypselodoris_bullockii_desc =>
      'Rosa-violette Nacktschnecke mit gelb gespitzten Rhinophoren an Riffen des Indopazifiks.';

  @override
  String get species_flabellina_exoptata_name => 'Begehrte Flabellina';

  @override
  String get species_flabellina_exoptata_desc =>
      'Durchscheinende Fadenschnecke mit violett gespitzten orangefarbenen Cerata, in tropischen Gewässern.';

  @override
  String get species_risbecia_tryoni_name => 'Tryons Risbecia';

  @override
  String get species_risbecia_tryoni_desc =>
      'Große braun-blaue Nacktschnecke, oft als Paar an Riffen des Indopazifiks zu finden.';

  @override
  String get species_goniobranchus_kuniei_name => 'Kunies Nacktschnecke';

  @override
  String get species_goniobranchus_kuniei_desc =>
      'Weiße Nacktschnecke mit orangefarbenen Punkten und violettem Mantelsaum, im Westpazifik verbreitet.';

  @override
  String get species_mexichromis_multituberculata_name =>
      'Vielhöckrige Nacktschnecke';

  @override
  String get species_mexichromis_multituberculata_desc =>
      'Violett-weiße Nacktschnecke mit erhabenen Höckern und orange gespitzten Anhängen.';

  @override
  String get species_chromodoris_dianae_name => 'Dianas Sternschnecke';

  @override
  String get species_chromodoris_dianae_desc =>
      'Leuchtend blaue Nacktschnecke mit schwarzen Streifen und orangefarbenen Kiemen, im Westpazifik verbreitet.';

  @override
  String get species_phyllodesmium_poindimiei_name =>
      'Sonnenbetriebene Nacktschnecke';

  @override
  String get species_phyllodesmium_poindimiei_desc =>
      'Durchscheinende Fadenschnecke mit verzweigten Cerata, die Zooxanthellen beherbergt.';

  @override
  String get species_chromodoris_elisabethina_name =>
      'Elisabeths Sternschnecke';

  @override
  String get species_chromodoris_elisabethina_desc =>
      'Blau und gelb gestreifte Nacktschnecke mit weißem Mantelsaum, in Südostasien häufig.';

  @override
  String get species_doridella_batava_name => 'Batavische Doridenschnecke';

  @override
  String get species_doridella_batava_desc =>
      'In der Färbung variable, schwarze bis braune Doridenschnecke unter Steinen und im Geröll an Riffen des Indopazifiks.';

  @override
  String get species_tiger_cowrie_name => 'Tiger-Kaurischnecke';

  @override
  String get species_tiger_cowrie_desc =>
      'Große gefleckte Kaurischnecke tropischer Riffe, oft teilweise vom eigenen Mantel bedeckt.';

  @override
  String get species_tritons_trumpet_name => 'Tritonshorn';

  @override
  String get species_tritons_trumpet_desc =>
      'Große Raubschnecke und natürlicher Feind des Dornenkronenseesterns.';

  @override
  String get species_queen_conch_name => 'Große Fechterschnecke';

  @override
  String get species_queen_conch_desc =>
      'Ikonische große Flügelschnecke der karibischen Seegraswiesen mit markant rosafarbener Mündungslippe.';

  @override
  String get species_banded_coral_shrimp_name => 'Gebänderte Scherengarnele';

  @override
  String get species_banded_coral_shrimp_desc =>
      'Rot-weiß gebänderte Putzergarnele mit langen weißen Fühlern, in Riffspalten zu finden.';

  @override
  String get species_mantis_shrimp_name => 'Pfauen-Fangschreckenkrebs';

  @override
  String get species_mantis_shrimp_desc =>
      'Farbenprächtiger Jäger mit kräftigen keulenartigen Fangbeinen, die Schalen zertrümmern können.';

  @override
  String get species_cleaner_shrimp_name => 'Weißband-Putzergarnele';

  @override
  String get species_cleaner_shrimp_desc =>
      'Leuchtend rot-weiße Garnele, die Putzerstationen einrichtet, um Rifffische zu versorgen.';

  @override
  String get species_pederson_cleaner_shrimp_name => 'Pederson-Putzergarnele';

  @override
  String get species_pederson_cleaner_shrimp_desc =>
      'Durchscheinende karibische Putzergarnele, die zwischen Anemonententakeln lebt.';

  @override
  String get species_harlequin_shrimp_name => 'Harlekingarnele';

  @override
  String get species_harlequin_shrimp_desc =>
      'Auffällig gemusterte Garnele mit flachen Scheren, die sich ausschließlich von Seesternen ernährt.';

  @override
  String get species_coleman_shrimp_name => 'Coleman-Garnele';

  @override
  String get species_coleman_shrimp_desc =>
      'Winzige, paarweise lebende Garnele auf Feuerseeigeln, bei Unterwasserfotografen sehr begehrt.';

  @override
  String get species_emperor_shrimp_name => 'Kaisergarnele';

  @override
  String get species_emperor_shrimp_desc =>
      'Farbenprächtige Kommensalgarnele, die auf Seegurken und Nacktschnecken mitreist.';

  @override
  String get species_sexy_shrimp_name => 'Sexy-Garnele';

  @override
  String get species_sexy_shrimp_desc =>
      'Winzige Anemonengarnele, bekannt für ihren wippenden Schwanztanz, beliebt in der Makrofotografie.';

  @override
  String get species_marble_shrimp_name => 'Marmorgarnele';

  @override
  String get species_marble_shrimp_desc =>
      'Nachtaktive, marmorierte Garnele mit befiederten Beinen, die sich tagsüber in Riffspalten versteckt.';

  @override
  String get species_spiny_lobster_name => 'Karibische Languste';

  @override
  String get species_spiny_lobster_desc =>
      'Große scherenlose Languste mit langen Fühlern, die unter Riffüberhängen Schutz sucht.';

  @override
  String get species_painted_spiny_lobster_name => 'Bunte Languste';

  @override
  String get species_painted_spiny_lobster_desc =>
      'Leuchtend gefärbte Languste mit blau, grün und weiß gestreiften Beinen an Riffen des Indopazifiks.';

  @override
  String get species_slipper_lobster_name => 'Bärenkrebs';

  @override
  String get species_slipper_lobster_desc =>
      'Flachgebauter nachtaktiver Krebs mit breiten Fühlerplatten anstelle langer Peitschenfühler.';

  @override
  String get species_squat_lobster_name => 'Springkrebs';

  @override
  String get species_squat_lobster_desc =>
      'Winziges rosa-violettes Krebstier, das auf riesigen Fassschwämmen lebt, ein Liebling der Makrofotografie.';

  @override
  String get species_hermit_crab_name => 'Blaubein-Einsiedlerkrebs';

  @override
  String get species_hermit_crab_desc =>
      'Kleiner Einsiedlerkrebs mit leuchtend blauen Beinen, häufig an karibischen Riffen.';

  @override
  String get species_orangutan_crab_name => 'Orang-Utan-Krabbe';

  @override
  String get species_orangutan_crab_desc =>
      'Winzige haarige Krabbe, die in Blasenkorallen lebt und nach ihrer Ähnlichkeit mit einem Orang-Utan benannt ist.';

  @override
  String get species_decorator_crab_name => 'Dekorateurkrabbe';

  @override
  String get species_decorator_crab_desc =>
      'Meisterin der Tarnung, die Schwämme, Algen und Hydrozoen auf ihrem Panzer befestigt.';

  @override
  String get species_porcelain_crab_name => 'Anemonen-Porzellankrebs';

  @override
  String get species_porcelain_crab_desc =>
      'Flacher gefleckter Krebs, der in Anemonen lebt und mit befiederten Mundwerkzeugen filtriert.';

  @override
  String get species_arrow_crab_name => 'Pfeilkrabbe';

  @override
  String get species_arrow_crab_desc =>
      'Spinnenartige karibische Krabbe mit langem spitzem Rostrum und gestreiften Beinen.';

  @override
  String get species_channel_clinging_crab_name =>
      'Karibische Riesenspinnenkrabbe';

  @override
  String get species_channel_clinging_crab_desc =>
      'Große karibische Riffkrabbe mit dunklem Körper und rotorangen Scheren, in Spalten zu finden.';

  @override
  String get species_coral_crab_name => 'Korallenwächter-Krabbe';

  @override
  String get species_coral_crab_desc =>
      'Kleine gefleckte Krabbe, die in Symbiose in Pocillopora-Korallen lebt und ihren Wirt verteidigt.';

  @override
  String get species_crown_of_thorns_starfish_name => 'Dornenkronenseestern';

  @override
  String get species_crown_of_thorns_starfish_desc =>
      'Giftiger vielarmiger Seestern, der Korallen frisst und bei Massenvermehrungen ganze Riffe verwüsten kann.';

  @override
  String get species_blue_linckia_starfish_name => 'Blauer Seestern';

  @override
  String get species_blue_linckia_starfish_desc =>
      'Leuchtend blauer Seestern, häufig auf Riffdächern und Riffhängen des Indopazifiks.';

  @override
  String get species_red_knob_starfish_name => 'Rotknoten-Seestern';

  @override
  String get species_red_knob_starfish_desc =>
      'Großer grauer Seestern mit auffälligen rot gespitzten Stacheln in sandigen Riffbereichen.';

  @override
  String get species_chocolate_chip_starfish_name => 'Knotenseestern';

  @override
  String get species_chocolate_chip_starfish_desc =>
      'Beigefarbener Seestern mit dunklen erhabenen Knoten, die an Schokoladenstückchen erinnern, auf sandigem Untergrund.';

  @override
  String get species_cushion_star_name => 'Kissenseestern';

  @override
  String get species_cushion_star_desc =>
      'Aufgeblähter fünfeckiger Seestern mit zurückgebildeten Armen auf den Riffdächern des Indopazifiks.';

  @override
  String get species_fromia_starfish_name => 'Eleganter Seestern';

  @override
  String get species_fromia_starfish_desc =>
      'Kleiner orangeroter Seestern mit hellen Plattenrändern, die ein Fliesenmuster ergeben.';

  @override
  String get species_basket_star_name => 'Gorgonenhaupt';

  @override
  String get species_basket_star_desc =>
      'Kunstvoll verzweigte Arme entfalten sich nachts, um in der Strömung Nahrung zu filtrieren.';

  @override
  String get species_brittle_star_name => 'Gebänderter Schlangenstern';

  @override
  String get species_brittle_star_desc =>
      'Gestreifter Schlangenstern unter Steinen und in Spalten, mit beweglichen, schlangenartigen Armen.';

  @override
  String get species_feather_star_name => 'Haarstern';

  @override
  String get species_feather_star_desc =>
      'Vielarmiger Haarstern, der auf Riffvorsprüngen sitzt und mit befiederten Armen filtriert.';

  @override
  String get species_black_feather_star_name => 'Schwarzer Haarstern';

  @override
  String get species_black_feather_star_desc =>
      'Dunkler Haarstern, der durch rhythmisches Schwingen seiner vielen Arme kurze Strecken schwimmen kann.';

  @override
  String get species_long_spined_sea_urchin_name => 'Langstachel-Seeigel';

  @override
  String get species_long_spined_sea_urchin_desc =>
      'Schwarzer Seeigel mit langen giftigen Stacheln, ein entscheidender Algenweider der karibischen Riffe.';

  @override
  String get species_fire_urchin_name => 'Feuerseeigel';

  @override
  String get species_fire_urchin_desc =>
      'Weichkörperiger Seeigel mit giftigen Stacheln, die bei Berührung schmerzhafte Verletzungen verursachen.';

  @override
  String get species_pencil_urchin_name => 'Griffelseeigel';

  @override
  String get species_pencil_urchin_desc =>
      'Robuster Seeigel mit dicken, stumpfen Stacheln, der sich in Riffspalten verkeilt.';

  @override
  String get species_collector_urchin_name => 'Sammler-Seeigel';

  @override
  String get species_collector_urchin_desc =>
      'Seeigel, der sich zur Tarnung mit Geröll und Algenstücken bedeckt.';

  @override
  String get species_sea_apple_name => 'Seeapfel';

  @override
  String get species_sea_apple_desc =>
      'Leuchtend gefärbte Seegurke mit Mundtentakeln, mit denen sie Nahrung aus dem Wasser filtert.';

  @override
  String get species_pineapple_sea_cucumber_name => 'Ananas-Seegurke';

  @override
  String get species_pineapple_sea_cucumber_desc =>
      'Große orangerote Seegurke mit sternförmigen Papillen an Riffhängen.';

  @override
  String get species_black_sea_cucumber_name => 'Schwarze Seegurke';

  @override
  String get species_black_sea_cucumber_desc =>
      'Häufige schwarze Seegurke auf sandigen Riffdächern im gesamten Indopazifik.';

  @override
  String get species_leopard_sea_cucumber_name => 'Leoparden-Seegurke';

  @override
  String get species_leopard_sea_cucumber_desc =>
      'Gefleckte Seegurke, die bei Störung klebrige weiße Cuvier-Schläuche ausstößt.';

  @override
  String get species_sand_dollar_name => 'Sanddollar';

  @override
  String get species_sand_dollar_desc =>
      'Flacher scheibenförmiger Seeigel, der teilweise eingegraben im Sand liegt.';

  @override
  String get species_moon_jellyfish_name => 'Ohrenqualle';

  @override
  String get species_moon_jellyfish_desc =>
      'Durchscheinende glockenförmige Qualle mit vier hufeisenförmigen Gonaden, die durch den Körper schimmern.';

  @override
  String get species_lions_mane_jellyfish_name => 'Gelbe Haarqualle';

  @override
  String get species_lions_mane_jellyfish_desc =>
      'Eine der größten Quallenarten mit langen nachziehenden Tentakeln in kalten Gewässern.';

  @override
  String get species_box_jellyfish_name => 'Seewespe';

  @override
  String get species_box_jellyfish_desc =>
      'Äußerst gefährliche Qualle mit hochwirksamem Gift, in tropischen Gewässern des Indopazifiks.';

  @override
  String get species_upside_down_jellyfish_name => 'Kopfüber-Qualle';

  @override
  String get species_upside_down_jellyfish_desc =>
      'Ungewöhnliche Qualle, die mit der Glocke nach unten auf Sandböden liegt, damit ihre Algen Photosynthese betreiben können.';

  @override
  String get species_blue_blubber_jellyfish_name => 'Blaue Blubberqualle';

  @override
  String get species_blue_blubber_jellyfish_desc =>
      'Blau-weiße Qualle mit fester Glocke und gekräuselten Mundarmen, häufig in australischen Gewässern.';

  @override
  String get species_fried_egg_jellyfish_name => 'Spiegeleiqualle';

  @override
  String get species_fried_egg_jellyfish_desc =>
      'Mediterrane Qualle mit gelber Kuppel, die an ein Spiegelei erinnert, mit schwachem Nesselgift.';

  @override
  String get species_pacific_sea_nettle_name => 'Pazifische Nesselqualle';

  @override
  String get species_pacific_sea_nettle_desc =>
      'Goldbraune Qualle mit langen nachziehenden Tentakeln entlang der Pazifikküste.';

  @override
  String get species_compass_jellyfish_name => 'Kompassqualle';

  @override
  String get species_compass_jellyfish_desc =>
      'Braun-weiße Qualle mit V-förmigen Zeichnungen, die wie eine Kompassrose ausstrahlen.';

  @override
  String get species_spotted_jellyfish_name => 'Gefleckte Qualle';

  @override
  String get species_spotted_jellyfish_desc =>
      'Goldene Qualle mit weißen Punkten, berühmt dafür, den Jellyfish Lake in Palau zu füllen.';

  @override
  String get species_barrel_jellyfish_name => 'Lungenqualle';

  @override
  String get species_barrel_jellyfish_desc =>
      'Große kuppelförmige Qualle mit gekräuselten Mundarmen und schwachem Nesselgift, im Atlantik häufig.';

  @override
  String get species_persian_carpet_flatworm_name => 'Perserteppich-Plattwurm';

  @override
  String get species_persian_carpet_flatworm_desc =>
      'Kunstvoll gezeichneter schwarzer Plattwurm mit gelborangem Saum, oft für eine Nacktschnecke gehalten.';

  @override
  String get species_leopard_flatworm_name => 'Leoparden-Plattwurm';

  @override
  String get species_leopard_flatworm_desc =>
      'Durchscheinender Plattwurm mit leopardenartigen Flecken, der über Riffuntergründe gleitet.';

  @override
  String get species_divided_flatworm_name => 'Geteilter Plattwurm';

  @override
  String get species_divided_flatworm_desc =>
      'Auffälliger schwarz-oranger Plattwurm, der zum Schutz giftige Nacktschnecken nachahmt.';

  @override
  String get species_blue_pseudoceros_flatworm_name =>
      'Blauer Pseudoceros-Plattwurm';

  @override
  String get species_blue_pseudoceros_flatworm_desc =>
      'Tiefblauer Plattwurm mit orangefarbenem Saum, der über die Riffoberflächen des Indopazifiks gleitet.';

  @override
  String get species_racing_stripe_flatworm_name => 'Rennstreifen-Plattwurm';

  @override
  String get species_racing_stripe_flatworm_desc =>
      'Cremefarbener Plattwurm mit deutlichem dunklem Mittelstreifen und gekräuseltem Rand.';

  @override
  String get species_christmas_tree_worm_name => 'Weihnachtsbaumwurm';

  @override
  String get species_christmas_tree_worm_desc =>
      'Farbenfroher Röhrenwurm mit spiralförmiger Krone in Korallen, der sich bei Annäherung blitzschnell zurückzieht.';

  @override
  String get species_feather_duster_worm_name => 'Federbuschwurm';

  @override
  String get species_feather_duster_worm_desc =>
      'In einer Röhre lebender Wurm mit fächerförmiger Krone aus federartigen Radiolen zum Filtrieren.';

  @override
  String get species_fire_worm_name => 'Bärtiger Feuerwurm';

  @override
  String get species_fire_worm_desc =>
      'Borstenwurm mit weißen Nesselborsten, die bei Berührung schmerzhafte Reizungen verursachen.';

  @override
  String get species_bobbit_worm_name => 'Bobbit-Wurm';

  @override
  String get species_bobbit_worm_desc =>
      'Lauerjäger, der im Sand versteckt liegt und mit kräftigen Kiefern blitzschnell zuschlägt.';

  @override
  String get species_social_feather_duster_name => 'Geselliger Federbuschwurm';

  @override
  String get species_social_feather_duster_desc =>
      'Kolonienbildender Röhrenwurm, der an karibischen Riffen Büschel zarter gebänderter Kronen bildet.';

  @override
  String get species_giant_clam_name => 'Riesenmuschel';

  @override
  String get species_giant_clam_desc =>
      'Die größte lebende Muschel, deren schillerndes Mantelgewebe symbiotische Algen beherbergt.';

  @override
  String get species_boring_clam_name => 'Bohrmuschel';

  @override
  String get species_boring_clam_desc =>
      'Kleine farbenprächtige Muschel, die sich in Korallenfels bohrt und nur ihren leuchtenden Mantel zeigt.';

  @override
  String get species_maxima_clam_name => 'Maxima-Riesenmuschel';

  @override
  String get species_maxima_clam_desc =>
      'Leuchtend gefärbte Muschel im Riffgestein mit elektrisch blauen und grünen Mänteln.';

  @override
  String get species_flame_scallop_name => 'Flammen-Feilenmuschel';

  @override
  String get species_flame_scallop_desc =>
      'Rote Muschel mit blitzendem weißem Lichtband am Mantelrand, in Riffspalten zu finden.';

  @override
  String get species_thorny_oyster_name => 'Stachelauster';

  @override
  String get species_thorny_oyster_desc =>
      'Muschel mit stacheliger Schale, die am Riffgestein festzementiert ist, oft von Schwämmen und Algen überwachsen.';

  @override
  String get species_magnificent_sea_anemone_name => 'Prachtanemone';

  @override
  String get species_magnificent_sea_anemone_desc =>
      'Große farbenprächtige Anemone, die Anemonenfische beherbergt, mit auffälliger Säule und wogenden Tentakeln.';

  @override
  String get species_bubble_tip_anemone_name => 'Blasenanemone';

  @override
  String get species_bubble_tip_anemone_desc =>
      'Beliebter Wirt für Anemonenfische, mit blasenförmig verdickten Tentakelspitzen in Grün-, Braun- oder Rosatönen.';

  @override
  String get species_giant_carpet_anemone_name => 'Riesen-Teppichanemone';

  @override
  String get species_giant_carpet_anemone_desc =>
      'Gewaltige Anemone mit kurzen, klebrigen Tentakeln, die über einen Meter Durchmesser erreichen kann.';

  @override
  String get species_haddon_carpet_anemone_name => 'Haddons Teppichanemone';

  @override
  String get species_haddon_carpet_anemone_desc =>
      'Flache Teppichanemone auf sandigem Untergrund, Wirt für verschiedene Anemonenfische und Porzellankrebse.';

  @override
  String get species_long_tentacle_anemone_name => 'Langtentakel-Anemone';

  @override
  String get species_long_tentacle_anemone_desc =>
      'Anemone sandiger Böden mit langen wogenden Tentakeln, oft mit Anemonenfischen besetzt.';

  @override
  String get species_tube_anemone_name => 'Zylinderrose';

  @override
  String get species_tube_anemone_desc =>
      'Elegante Anemone, die in einer pergamentartigen Röhre im Sand lebt und zwei Tentakelkränze trägt.';

  @override
  String get species_hell_fire_anemone_name => 'Höllenfeuer-Anemone';

  @override
  String get species_hell_fire_anemone_desc =>
      'Stark nesselnde Anemone mit verzweigten Tentakeln, die einer Weichkoralle ähnelt.';

  @override
  String get species_beaded_sea_anemone_name => 'Perlen-Seeanemone';

  @override
  String get species_beaded_sea_anemone_desc =>
      'Anemone mit perlartig verdickten Tentakelspitzen in sandigen Riffbereichen des Indopazifiks.';

  @override
  String get species_condylactis_anemone_name => 'Karibische Riesenanemone';

  @override
  String get species_condylactis_anemone_desc =>
      'Große karibische Anemone mit violett gespitzten Tentakeln auf felsigem Riffuntergrund.';

  @override
  String get species_sand_anemone_name => 'Sandanemone';

  @override
  String get species_sand_anemone_desc =>
      'Zarte Anemone, die teilweise im Sand eingegraben ist und violett gespitzte Tentakel trägt.';

  @override
  String get species_barrel_sponge_name => 'Riesen-Fassschwamm';

  @override
  String get species_barrel_sponge_desc =>
      'Gewaltiger fassförmiger Schwamm, der an karibischen Riffwänden Jahrhunderte alt werden kann.';

  @override
  String get species_azure_vase_sponge_name => 'Azurblauer Vasenschwamm';

  @override
  String get species_azure_vase_sponge_desc =>
      'Leuchtend blauvioletter vasenförmiger Schwamm an karibischen Riffwänden.';

  @override
  String get species_yellow_tube_sponge_name => 'Gelber Röhrenschwamm';

  @override
  String get species_yellow_tube_sponge_desc =>
      'Leuchtend gelber Röhrenschwamm, der in Büscheln an karibischen Riffwänden wächst.';

  @override
  String get species_elephant_ear_sponge_name => 'Elefantenohr-Schwamm';

  @override
  String get species_elephant_ear_sponge_desc =>
      'Großer orangefarbener fächerförmiger Schwamm, der in der Karibik an Wänden und unter Überhängen wächst.';

  @override
  String get species_rope_sponge_name => 'Seilschwamm';

  @override
  String get species_rope_sponge_desc =>
      'Roter aufrecht verzweigter Schwamm, der an karibischen Riffen seilartige Gebilde formt.';

  @override
  String get species_portuguese_man_o_war_name => 'Portugiesische Galeere';

  @override
  String get species_portuguese_man_o_war_desc =>
      'Hydrozoen-Kolonie mit gasgefüllter Schwimmblase und äußerst schmerzhaft nesselnden Schleppfäden.';

  @override
  String get species_fire_coral_name => 'Feuerkoralle';

  @override
  String get species_fire_coral_desc =>
      'Keine echte Koralle, sondern ein Hydrozoon, das Tauchern bei Berührung schmerzhafte Verbrennungen zufügt.';

  @override
  String get species_by_the_wind_sailor_name => 'Segelqualle';

  @override
  String get species_by_the_wind_sailor_desc =>
      'Blaue treibende Hydrozoenkolonie mit einem diagonalen Segel, das den Wind einfängt.';

  @override
  String get species_blue_button_name => 'Blauer Knopf';

  @override
  String get species_blue_button_desc =>
      'Treibende Hydrozoenkolonie mit flacher Scheibe und blauen, tentakelartigen Polypen.';

  @override
  String get species_giant_sea_hare_name => 'Riesen-Seehase';

  @override
  String get species_giant_sea_hare_desc =>
      'Eine der größten Meeresschnecken, dunkelbraun bis schwarz, in Kelpwäldern zu finden.';

  @override
  String get species_sea_hare_name => 'Gefleckter Seehase';

  @override
  String get species_sea_hare_desc =>
      'Großer, grün gefleckter Seehase, der bei Störung violette Tinte ausstößt.';

  @override
  String get species_nudibranch_berghia_name => 'Berghia-Nacktschnecke';

  @override
  String get species_nudibranch_berghia_desc =>
      'Durchscheinende Fadenschnecke mit weiß gespitzten Cerata, die sich von Anemonen ernährt.';

  @override
  String get species_sea_pen_name => 'Seefeder';

  @override
  String get species_sea_pen_desc =>
      'Federförmige Oktokorallen-Kolonie, die im Sand verankert ist und sich bei Störung zurückzieht.';

  @override
  String get species_blue_sea_star_name => 'Vielfarbiger Seestern';

  @override
  String get species_blue_sea_star_desc =>
      'Vielfarbiger Seestern, der sich an Riffen des Indopazifiks aus einzelnen Armstücken regeneriert.';

  @override
  String get species_reef_squid_name => 'Riffkalmar';

  @override
  String get species_reef_squid_desc =>
      'Südlicher Riffkalmar, dem man häufig in den gemäßigten Gewässern Australiens begegnet.';

  @override
  String get species_tiger_shrimp_name => 'Tigergarnele';

  @override
  String get species_tiger_shrimp_desc =>
      'Große gebänderte Garnele auf Sandböden und in Seegraswiesen des Indopazifiks.';

  @override
  String get species_candy_crab_name => 'Bonbonkrabbe';

  @override
  String get species_candy_crab_desc =>
      'Winzige farbige Krabbe, die mit rosa oder gelben Stachelfortsätzen ihrer Wirtsweichkoralle gleicht.';

  @override
  String get species_spider_crab_name => 'Dekorateur-Spinnenkrabbe';

  @override
  String get species_spider_crab_desc =>
      'Langsame Krabbe, die sich zur Tarnung mit angehefteten Schwämmen und Algen bedeckt.';

  @override
  String get species_anemone_shrimp_name => 'Prachtanemonen-Garnele';

  @override
  String get species_anemone_shrimp_desc =>
      'Durchsichtige Garnele mit weißen und violetten Zeichnungen, die zwischen Anemonententakeln lebt.';

  @override
  String get species_snapping_shrimp_name => 'Knallkrebs';

  @override
  String get species_snapping_shrimp_desc =>
      'Kleiner Krebs, der mit seiner übergroßen Schere ein lautes Knallen erzeugt, oft in Partnerschaft mit Grundeln.';

  @override
  String get species_glass_sponge_name => 'Venuskörbchen';

  @override
  String get species_glass_sponge_desc =>
      'Zarter Glasschwamm mit filigranem Kieselskelett, im tiefen Wasser zu finden.';

  @override
  String get species_toxic_sea_urchin_name => 'Blumenseeigel';

  @override
  String get species_toxic_sea_urchin_desc =>
      'Trügerisch hübscher Seeigel, bedeckt mit blütenartigen Pedicellarien und hochwirksamem Gift.';

  @override
  String get species_slate_pencil_urchin_name => 'Schiefergriffel-Seeigel';

  @override
  String get species_slate_pencil_urchin_desc =>
      'Seeigel mit dicken, abgerundeten Stacheln auf Riffuntergründen der Karibik und des Atlantiks.';

  @override
  String get species_spiny_sea_star_name => 'Dorniger Seestern';

  @override
  String get species_spiny_sea_star_desc =>
      'Großer Seestern der gemäßigten Zonen mit auffälligen Stacheln, in europäischen und atlantischen Gewässern.';

  @override
  String get species_bat_star_name => 'Fledermaus-Seestern';

  @override
  String get species_bat_star_desc =>
      'Pazifischer Seestern mit häutig verbundenen Armen in Orange, Rot oder Violett, in Kelpwäldern zu finden.';

  @override
  String get species_sunflower_star_name => 'Sonnenblumenstern';

  @override
  String get species_sunflower_star_desc =>
      'Gewaltiger, schnell kriechender Seestern mit bis zu 24 Armen in den Kelpwäldern des Pazifiks.';

  @override
  String get species_blood_star_name => 'Blutstern';

  @override
  String get species_blood_star_desc =>
      'Leuchtend rotoranger Seestern mit schlanken Armen in den gemäßigten Gewässern des Pazifiks.';

  @override
  String get species_common_cuttlefish_name => 'Gemeine Sepia';

  @override
  String get species_common_cuttlefish_desc =>
      'Meister der Tarnung mit W-förmigen Pupillen, in europäischen Gewässern und im Mittelmeer.';

  @override
  String get species_blue_spotted_crab_name => 'Blaupunkt-Schwimmkrabbe';

  @override
  String get species_blue_spotted_crab_desc =>
      'Bewegliche Schwimmkrabbe mit blauen Punkten auf dem Panzer, auf sandigen Böden des Indopazifiks.';

  @override
  String get species_sponge_crab_name => 'Schwammkrabbe';

  @override
  String get species_sponge_crab_desc =>
      'Krabbe, die sich einen lebenden Schwamm zurechtschneidet und ihn zur Tarnung auf dem Rücken trägt.';

  @override
  String get species_horseshoe_crab_name => 'Pfeilschwanzkrebs';

  @override
  String get species_horseshoe_crab_desc =>
      'Urtümlicher Gliederfüßer aus der Gruppe der Kieferklauenträger mit helmförmigem Panzer, auf Sandböden des Atlantiks.';

  @override
  String get species_sea_spider_name => 'Asselspinne';

  @override
  String get species_sea_spider_desc =>
      'Zarter langbeiniger Meeresgliederfüßer, der auf Hydrozoen und Moostierchen umherkriecht.';

  @override
  String get species_sea_lily_name => 'Seelilie';

  @override
  String get species_sea_lily_desc =>
      'Gestieltes lebendes Fossil aus der Gruppe der Haarsterne, das in tieferem Wasser mit befiederten Armen filtriert.';

  @override
  String get species_mantis_shrimp_lysiosquilla_name =>
      'Speer-Fangschreckenkrebs';

  @override
  String get species_mantis_shrimp_lysiosquilla_desc =>
      'Großer, im Sand grabender Fangschreckenkrebs mit Speerfangbeinen, auf sandigem Untergrund.';

  @override
  String get species_purple_sea_urchin_name => 'Violetter Seeigel';

  @override
  String get species_purple_sea_urchin_desc =>
      'Häufiger violetter Seeigel in den Kelpwäldern und Felstümpeln des Pazifiks.';

  @override
  String get species_crown_jellyfish_name => 'Kronenqualle';

  @override
  String get species_crown_jellyfish_desc =>
      'Tiefviolette Qualle mit kronenartig aufgewölbter Glocke, im Indopazifik verbreitet.';

  @override
  String get species_comb_jelly_name => 'Seestachelbeere';

  @override
  String get species_comb_jelly_desc =>
      'Kleine biolumineszente Rippenqualle mit schillernden Wimpernreihen und zwei langen Tentakeln.';

  @override
  String get species_warty_sea_slug_name => 'Warzige Meeresschnecke';

  @override
  String get species_warty_sea_slug_desc =>
      'Blau-schwarze Nacktschnecke mit gelb gekappten Höckern, häufig an Riffen des Indopazifiks zu sehen.';

  @override
  String get species_doris_nudibranch_name => 'Meereszitrone';

  @override
  String get species_doris_nudibranch_desc =>
      'Gelb gefleckte Doridenschnecke der gemäßigten Pazifikgewässer, die sich von Schwämmen ernährt.';

  @override
  String get species_opalescent_nudibranch_name =>
      'Opalisierende Nacktschnecke';

  @override
  String get species_opalescent_nudibranch_desc =>
      'Durchscheinende Fadenschnecke mit leuchtend orangefarbenen Cerata und blauen Rückenlinien in pazifischen Gewässern.';

  @override
  String get species_clown_nudibranch_name => 'Clown-Nacktschnecke';

  @override
  String get species_clown_nudibranch_desc =>
      'Rosaorange Nacktschnecke mit blauen und weißen Punkten in den gemäßigten Gewässern Australiens.';

  @override
  String get species_bottlenose_dolphin_name => 'Großer Tümmler';

  @override
  String get species_bottlenose_dolphin_desc =>
      'Neugieriger und verspielter Delfin, dem Taucher in tropischen und gemäßigten Gewässern häufig begegnen.';

  @override
  String get species_spinner_dolphin_name => 'Spinnerdelfin';

  @override
  String get species_spinner_dolphin_desc =>
      'Akrobatischer Delfin, bekannt für seine Drehsprünge, oft in großen Schulen nahe Korallenriffen.';

  @override
  String get species_common_dolphin_name => 'Gemeiner Delfin';

  @override
  String get species_common_dolphin_desc =>
      'Schnell schwimmender Delfin mit markanter Sanduhrzeichnung, im offenen Ozean und in Küstengewässern.';

  @override
  String get species_spotted_dolphin_name => 'Atlantischer Fleckendelfin';

  @override
  String get species_spotted_dolphin_desc =>
      'Zutraulicher Fleckendelfin, der sich Tauchern auf den Bahamas und in der Karibik häufig nähert.';

  @override
  String get species_rissos_dolphin_name => 'Rundkopfdelfin';

  @override
  String get species_rissos_dolphin_desc =>
      'Großer Delfin mit stark vernarbtem grauem Körper, weltweit in tiefen Gewässern fernab der Küste.';

  @override
  String get species_humpback_whale_name => 'Buckelwal';

  @override
  String get species_humpback_whale_desc =>
      'Majestätischer Wal, bekannt für seine Sprünge und komplexen Gesänge, auf saisonalen Wanderungen zu sehen.';

  @override
  String get species_grey_whale_name => 'Grauwal';

  @override
  String get species_grey_whale_desc =>
      'Am Boden fressender Bartenwal, der entlang der Pazifikküste wandert und oft mit Seepocken bewachsen ist.';

  @override
  String get species_blue_whale_name => 'Blauwal';

  @override
  String get species_blue_whale_desc =>
      'Das größte Tier, das je gelebt hat, gelegentlich von Tauchern im tiefen Blauwasser angetroffen.';

  @override
  String get species_sperm_whale_name => 'Pottwal';

  @override
  String get species_sperm_whale_desc =>
      'Tieftauchender Wal mit gewaltigem Kopf, der zwischen den Tauchgängen mitunter an der Oberfläche ruht.';

  @override
  String get species_orca_name => 'Schwertwal';

  @override
  String get species_orca_desc =>
      'Spitzenprädator mit markanter schwarz-weißer Zeichnung, in allen Ozeanbecken zu Hause.';

  @override
  String get species_minke_whale_name => 'Zwergwal';

  @override
  String get species_minke_whale_desc =>
      'Kleinerer Bartenwal, der Tauchern gegenüber neugierig ist, besonders am Great Barrier Reef.';

  @override
  String get species_beluga_whale_name => 'Weißwal';

  @override
  String get species_beluga_whale_desc =>
      'Weißer arktischer Wal, bekannt für seine Lautäußerungen und sein geselliges Verhalten in kalten Gewässern.';

  @override
  String get species_pilot_whale_name => 'Kurzflossen-Grindwal';

  @override
  String get species_pilot_whale_desc =>
      'Geselliger, tieftauchender Wal, oft in großen Schulen in tropischen und warmgemäßigten Meeren.';

  @override
  String get species_false_killer_whale_name => 'Kleiner Schwertwal';

  @override
  String get species_false_killer_whale_desc =>
      'Großer Hochseedelfin, der sich Tauchern im Freiwasser gelegentlich nähert.';

  @override
  String get species_dugong_name => 'Dugong';

  @override
  String get species_dugong_desc =>
      'Sanfter Pflanzenfresser, der im Indopazifik Seegraswiesen abweidet, nah verwandt mit den Rundschwanzseekühen.';

  @override
  String get species_west_indian_manatee_name => 'Karibik-Manati';

  @override
  String get species_west_indian_manatee_desc =>
      'Langsamer Pflanzenfresser in warmen Flachgewässern, Ästuaren und Quellen der Karibik.';

  @override
  String get species_sea_otter_name => 'Seeotter';

  @override
  String get species_sea_otter_desc =>
      'Charismatisches Meeressäugetier in den Kelpwäldern entlang der Küste des Nordpazifiks.';

  @override
  String get species_california_sea_lion_name => 'Kalifornischer Seelöwe';

  @override
  String get species_california_sea_lion_desc =>
      'Verspielter und wendiger Robbenverwandter, der entlang der Pazifikküste oft mit Tauchern spielt.';

  @override
  String get species_steller_sea_lion_name => 'Stellerscher Seelöwe';

  @override
  String get species_steller_sea_lion_desc =>
      'Größte Seelöwenart, in den kalten Gewässern des Nordpazifiks nahe felsigen Küsten.';

  @override
  String get species_harbor_seal_name => 'Seehund';

  @override
  String get species_harbor_seal_desc =>
      'Neugierige Robbe in gemäßigten Küstengewässern, die oft auf Felsen nahe Tauchplätzen ruht.';

  @override
  String get species_grey_seal_name => 'Kegelrobbe';

  @override
  String get species_grey_seal_desc =>
      'Große verspielte Robbe des Nordatlantiks, bekannt dafür, sich Tauchern unter Wasser zu nähern.';

  @override
  String get species_northern_elephant_seal_name => 'Nördlicher See-Elefant';

  @override
  String get species_northern_elephant_seal_desc =>
      'Gewaltige, tieftauchende Robbe, deren Männchen einen großen Rüssel tragen. Entlang der ostpazifischen Küste verbreitet.';

  @override
  String get species_hawaiian_monk_seal_name => 'Hawaii-Mönchsrobbe';

  @override
  String get species_hawaiian_monk_seal_desc =>
      'Vom Aussterben bedrohte Robbe, endemisch auf Hawaii, gelegentlich von Tauchern an Riffen gesichtet.';

  @override
  String get species_leopard_seal_name => 'Seeleopard';

  @override
  String get species_leopard_seal_desc =>
      'Kräftiger antarktischer Jäger mit geflecktem Fell, dem Kaltwassertaucher begegnen.';

  @override
  String get species_narwhal_name => 'Narwal';

  @override
  String get species_narwhal_desc =>
      'Arktischer Wal mit langem spiralförmigem Stoßzahn, selten zu sehen, aber ikonisch unter den Meeressäugern.';

  @override
  String get species_green_sea_turtle_name => 'Suppenschildkröte';

  @override
  String get species_green_sea_turtle_desc =>
      'Große Meeresschildkröte, die häufig beim Abweiden von Seegras in tropischen Gewässern zu sehen ist.';

  @override
  String get species_hawksbill_sea_turtle_name => 'Echte Karettschildkröte';

  @override
  String get species_hawksbill_sea_turtle_desc =>
      'Riffbewohnende Schildkröte mit spitzem Schnabel, die zwischen Korallen Schwämme frisst.';

  @override
  String get species_loggerhead_sea_turtle_name => 'Unechte Karettschildkröte';

  @override
  String get species_loggerhead_sea_turtle_desc =>
      'Großköpfige Schildkröte in gemäßigten und tropischen Meeren, oft nahe Felsriffen.';

  @override
  String get species_leatherback_sea_turtle_name => 'Lederschildkröte';

  @override
  String get species_leatherback_sea_turtle_desc =>
      'Größte lebende Schildkröte mit biegsamem Lederpanzer, die in extreme Tiefen taucht.';

  @override
  String get species_olive_ridley_sea_turtle_name => 'Oliv-Bastardschildkröte';

  @override
  String get species_olive_ridley_sea_turtle_desc =>
      'Kleinste Meeresschildkrötenart, bekannt für ihre synchronen Massenablagen, die Arribadas.';

  @override
  String get species_kemps_ridley_sea_turtle_name =>
      'Atlantik-Bastardschildkröte';

  @override
  String get species_kemps_ridley_sea_turtle_desc =>
      'Vom Aussterben bedrohte Meeresschildkröte, die vor allem im Golf von Mexiko vorkommt.';

  @override
  String get species_flatback_sea_turtle_name =>
      'Australische Plattrückenschildkröte';

  @override
  String get species_flatback_sea_turtle_desc =>
      'Endemisch in australischen Gewässern, erkennbar an ihrem flachen Panzer und ihrem küstennahen Lebensraum.';

  @override
  String get species_brain_coral_name => 'Hirnkoralle';

  @override
  String get species_brain_coral_desc =>
      'Massive riffbildende Koralle mit gefurchter Oberfläche, die an ein Gehirn erinnert, häufig an karibischen Riffen.';

  @override
  String get species_staghorn_coral_name => 'Geweihkoralle';

  @override
  String get species_staghorn_coral_desc =>
      'Schnell wachsende verzweigte Koralle, die dichte Dickichte bildet, ein entscheidender Lebensraum für Rifffische.';

  @override
  String get species_elkhorn_coral_name => 'Elchgeweihkoralle';

  @override
  String get species_elkhorn_coral_desc =>
      'Große verzweigte Koralle mit flachen handförmigen Ästen, ein wichtiger Riffbildner der Karibik.';

  @override
  String get species_table_coral_name => 'Tischkoralle';

  @override
  String get species_table_coral_desc =>
      'Flach plattenbildende Koralle an Riffen des Indopazifiks, die vielen Fischarten Schutz bietet.';

  @override
  String get species_mushroom_coral_name => 'Pilzkoralle';

  @override
  String get species_mushroom_coral_desc =>
      'Frei lebende Einzelkoralle in Scheibenform, auf Sandflächen nahe Riffen des Indopazifiks.';

  @override
  String get species_bubble_coral_name => 'Blasenkoralle';

  @override
  String get species_bubble_coral_desc =>
      'Markante Koralle mit traubenartigen Bläschen, die sich tagsüber aufblähen, um Licht einzufangen.';

  @override
  String get species_plate_coral_name => 'Plattenkoralle';

  @override
  String get species_plate_coral_desc =>
      'Dünn plattenbildende Koralle, die gewundene Stufen formt, häufig an den Riffhängen des Indopazifiks.';

  @override
  String get species_pillar_coral_name => 'Säulenkoralle';

  @override
  String get species_pillar_coral_desc =>
      'Seltene aufrecht wachsende Koralle, die hohe Säulen bildet, in der Karibik verbreitet.';

  @override
  String get species_star_coral_name => 'Sternkoralle';

  @override
  String get species_star_coral_desc =>
      'Wichtiger karibischer Riffbildner, der große felsblockartige Kolonien mit sternförmigen Polypen formt.';

  @override
  String get species_lettuce_coral_name => 'Salatkoralle';

  @override
  String get species_lettuce_coral_desc =>
      'Dünn plattenbildende Koralle mit blattartigen Falten, häufig an karibischen Riffwänden und Riffhängen.';

  @override
  String get species_finger_coral_name => 'Fingerkoralle';

  @override
  String get species_finger_coral_desc =>
      'Robuste verzweigte Koralle mit dicken fingerartigen Fortsätzen an flachen Riffen.';

  @override
  String get species_massive_porites_name => 'Massive Porites-Koralle';

  @override
  String get species_massive_porites_desc =>
      'Große Blockkoralle, die Jahrhunderte alt werden kann, ein dominierender Riffbildner im Indopazifik.';

  @override
  String get species_cauliflower_coral_name => 'Blumenkohlkoralle';

  @override
  String get species_cauliflower_coral_desc =>
      'Kompakte verzweigte Koralle in Blumenkohlform, weit verbreitet im flachen Wasser tropischer Riffe.';

  @override
  String get species_flower_pot_coral_name => 'Blumentopfkoralle';

  @override
  String get species_flower_pot_coral_desc =>
      'Kolonie langtentakliger Polypen, die sich tagsüber ausstrecken und an einen Blumenstrauß erinnern.';

  @override
  String get species_cup_coral_name => 'Orange Kelchkoralle';

  @override
  String get species_cup_coral_desc =>
      'Leuchtend orangefarbene, nicht photosynthetische Koralle an Wänden und unter Überhängen tropischer Gewässer.';

  @override
  String get species_scroll_coral_name => 'Schriftrollenkoralle';

  @override
  String get species_scroll_coral_desc =>
      'Koralle, die große eingerollte Platten bildet, häufig an Riffhängen und in Lagunen des Indopazifiks.';

  @override
  String get species_cabbage_coral_name => 'Kohlkoralle';

  @override
  String get species_cabbage_coral_desc =>
      'Scheibenförmig plattenbildende Koralle, die an Kohlblätter erinnert, in geschützten Riffbereichen.';

  @override
  String get species_hammer_coral_name => 'Hammerkoralle';

  @override
  String get species_hammer_coral_desc =>
      'Großpolypige Koralle mit anker- oder hammerförmigen Tentakelspitzen, beliebt an Riffen des Indopazifiks.';

  @override
  String get species_torch_coral_name => 'Fackelkoralle';

  @override
  String get species_torch_coral_desc =>
      'Verzweigte Koralle mit langen wogenden Tentakeln, die in leuchtenden Knollen enden.';

  @override
  String get species_frogspawn_coral_name => 'Froschlaichkoralle';

  @override
  String get species_frogspawn_coral_desc =>
      'Großpolypige Koralle mit verzweigten Tentakelspitzen, die an Froschlaich erinnern.';

  @override
  String get species_sea_fan_name => 'Gemeine Fächergorgonie';

  @override
  String get species_sea_fan_desc =>
      'Flache fächerförmige Gorgonie, quer zur Strömung ausgerichtet, ikonisch an karibischen Riffen.';

  @override
  String get species_venus_sea_fan_name => 'Venus-Fächergorgonie';

  @override
  String get species_venus_sea_fan_desc =>
      'Zarte fächerförmige Gorgonie an flachen karibischen Riffen mit mäßiger Strömung.';

  @override
  String get species_deepwater_sea_fan_name => 'Tiefwasser-Fächergorgonie';

  @override
  String get species_deepwater_sea_fan_desc =>
      'Große buschige Gorgonie an tiefen Riffwänden der Karibik.';

  @override
  String get species_sea_whip_name => 'Peitschengorgonie';

  @override
  String get species_sea_whip_desc =>
      'Schlanke stabförmige Gorgonie, die sich in der Strömung an atlantischen und karibischen Riffen wiegt.';

  @override
  String get species_sea_plume_name => 'Federgorgonie';

  @override
  String get species_sea_plume_desc =>
      'Hohe befiederte Gorgonie, die federbuschartige Kolonien auf karibischen Riffdächern bildet.';

  @override
  String get species_organ_pipe_coral_name => 'Orgelkoralle';

  @override
  String get species_organ_pipe_coral_desc =>
      'Leuchtend rote Skelettröhren mit zarten Polypen, an geschützten Riffen des Indopazifiks.';

  @override
  String get species_leather_coral_name => 'Lederkoralle';

  @override
  String get species_leather_coral_desc =>
      'Weichkoralle mit glatter, lederartiger Oberfläche, die große pilzförmige Kolonien bildet.';

  @override
  String get species_toadstool_leather_coral_name => 'Pilz-Lederkoralle';

  @override
  String get species_toadstool_leather_coral_desc =>
      'Weichkoralle mit dickem Stiel und flachem Schirm, häufig auf den Riffdächern des Indopazifiks.';

  @override
  String get species_pulsing_xenia_name => 'Pulsierende Xenia';

  @override
  String get species_pulsing_xenia_desc =>
      'Weichkoralle mit rhythmisch pulsierenden Polypen, in geschützten Gewässern des Indopazifiks.';

  @override
  String get species_tree_coral_name => 'Baumkoralle';

  @override
  String get species_tree_coral_desc =>
      'Leuchtende Weichkoralle, die an Wänden und unter Überhängen im Roten Meer baumartige Büschel bildet.';

  @override
  String get species_blue_coral_name => 'Blaue Koralle';

  @override
  String get species_blue_coral_desc =>
      'Einzigartige Oktokoralle mit blauem Skelett, auf flachen Riffdächern des Indopazifiks.';

  @override
  String get species_black_coral_name => 'Schwarze Koralle';

  @override
  String get species_black_coral_desc =>
      'Tiefwasserkoralle mit dunklem Skelett, an Wänden und Abbrüchen unterhalb von 30 Metern.';

  @override
  String get species_carnation_coral_name => 'Nelkenkoralle';

  @override
  String get species_carnation_coral_desc =>
      'Leuchtend gefärbte Weichkoralle unter Überhängen und an Wänden im Indopazifik.';

  @override
  String get species_wire_coral_name => 'Drahtkoralle';

  @override
  String get species_wire_coral_desc =>
      'Lange spiralige Schwarze Koralle, die gewundene Peitschen bildet und Grundeln und Garnelen beherbergt.';

  @override
  String get species_dead_mans_fingers_name => 'Tote Meerhand';

  @override
  String get species_dead_mans_fingers_desc =>
      'Fleischige Weichkoralle mit fingerartigen Lappen, häufig an gemäßigten Riffen des Nordatlantiks.';

  @override
  String get species_sun_coral_name => 'Sonnenkoralle';

  @override
  String get species_sun_coral_desc =>
      'Gelborange, nicht photosynthetische Koralle, die nachts an den Wänden des Indopazifiks ihre Polypen öffnet.';

  @override
  String get species_lace_coral_name => 'Spitzenkoralle';

  @override
  String get species_lace_coral_desc =>
      'Zarte rosafarbene Hydrokoralle mit spitzenartigen Ästen, in Spalten und unter Überhängen.';

  @override
  String get species_kenya_tree_coral_name => 'Kenia-Baumkoralle';

  @override
  String get species_kenya_tree_coral_desc =>
      'Robuste Weichkoralle mit baumartigen Ästen, im Indopazifik häufig.';

  @override
  String get species_colt_coral_name => 'Colt-Koralle';

  @override
  String get species_colt_coral_desc =>
      'Weichkoralle mit dicken, gummiartigen Ästen voller kleiner Polypen an Riffen des Indopazifiks.';

  @override
  String get species_turtle_grass_name => 'Schildkrötengras';

  @override
  String get species_turtle_grass_desc =>
      'Vorherrschendes karibisches Seegras mit breiten flachen Halmen, eine wichtige Nahrungsquelle für Meeresschildkröten.';

  @override
  String get species_eelgrass_name => 'Gemeines Seegras';

  @override
  String get species_eelgrass_desc =>
      'Seegras der gemäßigten Zonen, das dichte Unterwasserwiesen bildet und als Kinderstube dient.';

  @override
  String get species_manatee_grass_name => 'Manatigras';

  @override
  String get species_manatee_grass_desc =>
      'Seegras mit zylindrischen Halmen in sandigen Bereichen der Karibik, oft nahe Schildkrötengraswiesen.';

  @override
  String get species_shoal_grass_name => 'Schmalblättriges Seegras';

  @override
  String get species_shoal_grass_desc =>
      'Als Pionier auftretendes Seegras mit schmalen Halmen, das gestörte Sandflächen in der Karibik besiedelt.';

  @override
  String get species_paddle_grass_name => 'Paddelgras';

  @override
  String get species_paddle_grass_desc =>
      'Kleines zartes Seegras mit ovalen Blättern, in tieferen Gewässern der Tropen.';

  @override
  String get species_neptune_grass_name => 'Neptungras';

  @override
  String get species_neptune_grass_desc =>
      'Mediterranes Seegras, das ausgedehnte Wiesen bildet und für die Küstenökosysteme entscheidend ist.';

  @override
  String get species_giant_kelp_name => 'Riesentang';

  @override
  String get species_giant_kelp_desc =>
      'Bildet bis zu 60 Meter hohe Unterwasserwälder und steht sinnbildlich für das Tauchen in Kalifornien.';

  @override
  String get species_bull_kelp_name => 'Riesenblasentang';

  @override
  String get species_bull_kelp_desc =>
      'Pazifischer Tang mit einem einzelnen langen Stiel und blasenförmigem Schwimmkörper, der dichte Kronendächer bildet.';

  @override
  String get species_bladder_wrack_name => 'Blasentang';

  @override
  String get species_bladder_wrack_desc =>
      'Häufige Braunalge mit paarigen Luftblasen, in den Gezeitenzonen des Nordatlantiks.';

  @override
  String get species_sargassum_name => 'Beerentang';

  @override
  String get species_sargassum_desc =>
      'Frei treibende Braunalge, die Teppiche bildet, in denen Jungfische und Wirbellose Schutz finden.';

  @override
  String get species_kelp_forest_ecklonia_name => 'Ecklonia-Kelp';

  @override
  String get species_kelp_forest_ecklonia_desc =>
      'Vorherrschender Kelp in den Gewässern der Südhalbkugel, der bedeutende Unterwasserwälder bildet.';

  @override
  String get species_coralline_algae_name => 'Kalkrotalgen';

  @override
  String get species_coralline_algae_desc =>
      'Hart verkrustende Rotalge, die Riffstrukturen verkittet und den Riffen einen rosafarbenen Ton verleiht.';

  @override
  String get species_irish_moss_name => 'Knorpeltang';

  @override
  String get species_irish_moss_desc =>
      'Fächerförmige Rotalge an den Felsküsten der Gezeitenzone des Nordatlantiks.';

  @override
  String get species_dulse_name => 'Lappentang';

  @override
  String get species_dulse_desc =>
      'Flache rotviolette Alge, die auf Felsen und Kelpstielen in kalten nördlichen Gewässern wächst.';

  @override
  String get species_halimeda_name => 'Halimeda-Kalkalge';

  @override
  String get species_halimeda_desc =>
      'Verkalkte Grünalge mit scheibenförmigen Segmenten, ein wichtiger Lieferant von Riffsand.';

  @override
  String get species_sea_lettuce_name => 'Meersalat';

  @override
  String get species_sea_lettuce_desc =>
      'Leuchtend grüne, blattartige Alge in flachen Küstengewässern weltweit.';

  @override
  String get species_caulerpa_name => 'Meerestraube';

  @override
  String get species_caulerpa_desc =>
      'Kriechende Grünalge mit traubenartigen Wedeln, auf Korallenschutt und Sand tropischer Riffe.';

  @override
  String get species_mermaid_fan_name => 'Meerjungfrauenfächer';

  @override
  String get species_mermaid_fan_desc =>
      'Verkalkte Grünalge in Form eines kleinen Fächers, häufig auf karibischen Sandböden.';

  @override
  String get species_shaving_brush_algae_name => 'Rasierpinselalge';

  @override
  String get species_shaving_brush_algae_desc =>
      'Verkalkte Grünalge mit pinselartigem Büschel auf einem Stiel, auf karibischen Sandböden.';

  @override
  String get species_finger_kelp_name => 'Fingertang';

  @override
  String get species_finger_kelp_desc =>
      'Braunalge mit fingerartigen Wedeln, die in den Küstengewässern des Nordatlantiks Tangwälder bildet.';

  @override
  String get species_banded_sea_krait_name => 'Gebänderter Plattschwanz';

  @override
  String get species_banded_sea_krait_desc =>
      'Giftige Seeschlange mit blaugrauen und schwarzen Binden, friedlich und häufig an Riffen des Indopazifiks zu sehen.';

  @override
  String get species_olive_sea_snake_name => 'Olivgrüne Seeschlange';

  @override
  String get species_olive_sea_snake_desc =>
      'Neugierige Seeschlange an australischen Riffen, bekannt dafür, sich Tauchern zu nähern.';

  @override
  String get species_yellow_bellied_sea_snake_name => 'Gelbbauch-Seeschlange';

  @override
  String get species_yellow_bellied_sea_snake_desc =>
      'Pelagische Seeschlange mit gelber Unterseite, die am weitesten verbreitete Schlangenart der Erde.';

  @override
  String get species_marine_iguana_name => 'Meerechse';

  @override
  String get species_marine_iguana_desc =>
      'Endemisch auf Galapagos, die einzige Echse, die unter Wasser nach Algen sucht.';

  @override
  String get species_saltwater_crocodile_name => 'Leistenkrokodil';

  @override
  String get species_saltwater_crocodile_desc =>
      'Größtes lebendes Reptil, in Küsten- und Ästuargewässern des Indopazifiks.';

  @override
  String get common_action_done => 'Fertig';

  @override
  String get common_action_more => 'Mehr';

  @override
  String get common_label_displayName => 'Anzeigename';

  @override
  String common_relativeTime_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor ${count}T',
      one: 'vor ${count}T',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor ${count}Std',
      one: 'vor ${count}Std',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in ${count}T',
      one: 'in ${count}T',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in ${count}Std',
      one: 'in ${count}Std',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_inLessThanMinute => 'in <1Min';

  @override
  String common_relativeTime_inMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in ${count}Min',
      one: 'in ${count}Min',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_justNow => 'gerade eben';

  @override
  String common_relativeTime_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor ${count}Min',
      one: 'vor ${count}Min',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor ${count}Mon',
      one: 'vor ${count}Mon',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_overdue => 'überfällig';

  @override
  String get media_cache_calculating => 'Cache-Größe wird berechnet…';

  @override
  String get media_cache_cardTitle => 'Cache-Verwaltung';

  @override
  String get media_cache_clearAction => 'Cache leeren';

  @override
  String get media_cache_clearBody =>
      'Entfernt heruntergeladene Miniaturansichten und Netzwerkbilder in voller Größe. Verknüpfte Medieneinträge bleiben erhalten; Bilder werden beim nächsten Anzeigen erneut heruntergeladen.';

  @override
  String get media_cache_clearConfirm => 'Leeren';

  @override
  String media_cache_clearError(String error) {
    return 'Leeren fehlgeschlagen: $error';
  }

  @override
  String get media_cache_clearTitle => 'Netzwerkbild-Cache leeren?';

  @override
  String get media_cache_cleared => 'Cache geleert';

  @override
  String get media_cache_diskCache => 'Festplatten-Cache';

  @override
  String media_cache_error(String error) {
    return 'Fehler: $error';
  }

  @override
  String get media_credentials_actionTest => 'Zugangsdaten testen';

  @override
  String media_credentials_authLabel(String authType) {
    return 'Auth: $authType';
  }

  @override
  String get media_credentials_deleteBody =>
      'Entfernt die gespeicherten Zugangsdaten. Über diesen Host verknüpfte Elemente zeigen „Zum Anzeigen anmelden“, bis du sie erneut hinzufügst.';

  @override
  String media_credentials_deleteError(String error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String media_credentials_deleteTitle(String host) {
    return '$host löschen?';
  }

  @override
  String media_credentials_deleted(String host) {
    return '$host gelöscht';
  }

  @override
  String media_credentials_editTitle(String host) {
    return '$host bearbeiten';
  }

  @override
  String get media_credentials_emptySubtitle =>
      'Host-spezifische Zugangsdaten, die beim URL- oder Manifest-Import hinzugefügt werden, erscheinen hier.';

  @override
  String get media_credentials_emptyTitle => 'Keine gespeicherten Zugangsdaten';

  @override
  String media_credentials_lastUsed(String when) {
    return 'Zuletzt verwendet $when';
  }

  @override
  String get media_credentials_loadError =>
      'Gespeicherte Hosts konnten nicht geladen werden';

  @override
  String get media_credentials_loading =>
      'Gespeicherte Hosts werden geladen...';

  @override
  String media_credentials_saveError(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get media_credentials_savedHostsTitle => 'Gespeicherte Hosts';

  @override
  String media_credentials_testError(String error) {
    return 'Test fehlgeschlagen: $error';
  }

  @override
  String media_credentials_testFailed(String host) {
    return 'Zugangsdaten für $host fehlgeschlagen';
  }

  @override
  String media_credentials_testOk(String host) {
    return 'Zugangsdaten für $host OK';
  }

  @override
  String get media_manifest_actionPollNow => 'Jetzt abrufen';

  @override
  String get media_manifest_cardTitle => 'Manifest-Abonnements';

  @override
  String get media_manifest_deleteBody =>
      'Entfernt das Abonnement. Bereits importierte Einträge bleiben erhalten (du kannst sie über die Warteschlange verwaister Elemente bereinigen).';

  @override
  String media_manifest_deleteError(String error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String media_manifest_deleteTitle(String name) {
    return '$name löschen?';
  }

  @override
  String get media_manifest_editTitle => 'Abonnement bearbeiten';

  @override
  String get media_manifest_emptySubtitle =>
      'Abonniere im URL-Tab ein Atom/RSS-, JSON- oder CSV-Manifest, um deine Mediathek synchron zu halten.';

  @override
  String get media_manifest_emptyTitle => 'Keine Manifest-Abonnements';

  @override
  String media_manifest_lastError(String error) {
    return 'Letzter Fehler: $error';
  }

  @override
  String media_manifest_lastPolled(String when) {
    return 'Zuletzt abgerufen $when';
  }

  @override
  String get media_manifest_loadError =>
      'Abonnements konnten nicht geladen werden';

  @override
  String get media_manifest_loading => 'Abonnements werden geladen...';

  @override
  String get media_manifest_neverPolled => 'Nie abgerufen';

  @override
  String media_manifest_nextPoll(String when) {
    return 'Nächster Abruf $when';
  }

  @override
  String get media_manifest_notFound => 'Abonnement nicht gefunden';

  @override
  String media_manifest_pollError(String error) {
    return 'Abruf fehlgeschlagen: $error';
  }

  @override
  String media_manifest_polled(String name) {
    return '$name abgerufen';
  }

  @override
  String media_manifest_polling(String name) {
    return '$name wird abgerufen...';
  }

  @override
  String media_manifest_saveError(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String media_manifest_updateError(String error) {
    return 'Aktualisierung nicht möglich: $error';
  }

  @override
  String get media_manifest_urlLabel => 'Manifest-URL';

  @override
  String media_scan_failed(String error) {
    return 'Scan fehlgeschlagen: $error';
  }

  @override
  String media_scan_progressItems(int done, int total) {
    return '$done / $total Elemente';
  }

  @override
  String media_scan_progressReachability(int available, int unreachable) {
    return '$available erreichbar  ·  $unreachable nicht erreichbar';
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
          '$total Elemente in ${seconds}s gescannt: $available erreichbar, $unreachable nicht erreichbar',
      one:
          '$total Element in ${seconds}s gescannt: $available erreichbar, $unreachable nicht erreichbar',
    );
    return '$_temp0';
  }

  @override
  String media_scan_summarySkipped(String base, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count übersprungen (keine URL)',
      one: '$count übersprungen (keine URL)',
    );
    return '$base, $_temp0';
  }

  @override
  String get media_scan_title => 'Alle Netzwerkmedien scannen';

  @override
  String get settings_mediaSources_androidUriTitle =>
      'Android-URI-Berechtigungen';

  @override
  String settings_mediaSources_androidUriUsage(int used, int limit) {
    return '$used / $limit dauerhafte URIs in Verwendung';
  }

  @override
  String get settings_mediaSources_counting => 'Wird gezählt…';

  @override
  String settings_mediaSources_error(String error) {
    return 'Fehler: $error';
  }

  @override
  String get settings_mediaSources_loading => 'Wird geladen…';

  @override
  String settings_mediaSources_localFilesCounts(
    int available,
    int unavailable,
  ) {
    return '$available verfügbar, $unavailable nicht verfügbar';
  }

  @override
  String get settings_mediaSources_photoLibrarySubtitle =>
      'Apple Photos / Google Photos / iCloud';

  @override
  String get settings_mediaSources_reverifyAll =>
      'Alle lokalen Dateien erneut prüfen';

  @override
  String settings_mediaSources_reverifyFailed(String error) {
    return 'Erneute Prüfung fehlgeschlagen: $error';
  }

  @override
  String settings_mediaSources_reverifyResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente aktualisiert',
      one: '$count Element aktualisiert',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_checkAll => 'Alle Medien prüfen';

  @override
  String settings_mediaSources_checkAllResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente aktualisiert',
      one: '$count Element aktualisiert',
    );
    return '$_temp0';
  }

  @override
  String settings_mediaSources_checkAllBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Keines der $count Elemente konnte geprüft werden. Ihre Quellen sind derzeit nicht erreichbar.',
      one:
          'Das Element konnte nicht geprüft werden. Seine Quelle ist derzeit nicht erreichbar.',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_title => 'Medienquellen';

  @override
  String get settings_networkSources_scanDescription =>
      'Prüft jedes über URL oder Manifest importierte Foto erneut bei seinem Host. Nicht erreichbare Elemente werden markiert, sodass sie in deiner Mediathek als „fehlend“ erscheinen und bereinigt werden können.';

  @override
  String statistics_conditions_entryMethod_semanticLabel(String description) {
    return 'Balkendiagramm. Einstiegsmethoden. $description';
  }

  @override
  String statistics_conditions_visibility_semanticLabel(String description) {
    return 'Kreisdiagramm. Sichtverteilung. $description';
  }

  @override
  String statistics_conditions_waterType_semanticLabel(String description) {
    return 'Kreisdiagramm. Verteilung der Wasserarten. $description';
  }

  @override
  String statistics_progression_divesBySuitThickness_semanticLabel(
    String description,
  ) {
    return 'Balkendiagramm. Tauchgänge nach Anzugdicke. $description';
  }

  @override
  String statistics_progression_divesPerYear_countInYear(
    int count,
    String year,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge in $year',
      one: '1 Tauchgang in $year',
    );
    return '$_temp0';
  }

  @override
  String statistics_progression_divesPerYear_semanticLabel(String description) {
    return 'Balkendiagramm. Tauchgänge pro Jahr. $description';
  }

  @override
  String get statistics_records_unavailable => 'Rekorde nicht verfügbar';

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
  String get statistics_summary_distributions_title => 'Verteilungen';

  @override
  String get statistics_summary_diveTypes_error =>
      'Daten zu Tauchgangarten können nicht geladen werden';

  @override
  String get statistics_summary_diveTypes_unknown => 'Unbekannt';

  @override
  String get statistics_summary_divesPerMonth => 'Tauchgänge / Monat';

  @override
  String get statistics_summary_divesPerYear => 'Tauchgänge / Jahr';

  @override
  String statistics_timePatterns_dayOfWeek_semanticLabel(String description) {
    return 'Balkendiagramm. Tauchgänge nach Wochentag. $description';
  }

  @override
  String statistics_timePatterns_seasonal_semanticLabel(String description) {
    return 'Balkendiagramm. Tauchgänge nach Monat. $description';
  }

  @override
  String statistics_timePatterns_surfaceInterval_statLabel(
    String label,
    String value,
  ) {
    return 'Oberflächenintervall $label: $value';
  }

  @override
  String get statistics_timePatterns_timeOfDay_afternoon => 'Nachmittag';

  @override
  String get statistics_timePatterns_timeOfDay_evening => 'Abend';

  @override
  String get statistics_timePatterns_timeOfDay_morning => 'Morgen';

  @override
  String get statistics_timePatterns_timeOfDay_night => 'Nacht';

  @override
  String statistics_timePatterns_timeOfDay_semanticLabel(String description) {
    return 'Kreisdiagramm. Tauchgänge nach Tageszeit. $description';
  }

  @override
  String get columnConfig_displayOptions => 'Anzeigeoptionen';

  @override
  String get columnConfig_noExtraFields =>
      'Keine zusätzlichen Felder konfiguriert. Fügen Sie unten Felder hinzu.';

  @override
  String get columnConfig_savePresetTitle => 'Voreinstellung speichern';

  @override
  String get columnConfig_section => 'Abschnitt';

  @override
  String get columnConfig_showTags => 'Tags anzeigen';

  @override
  String get columnConfig_showTags_subtitle =>
      'Tag-Chips auf detaillierten Tauchgangskarten anzeigen';

  @override
  String get columnConfig_slot_date => 'Datum / Untertitel';

  @override
  String get columnConfig_slot_slot1 => 'Slot 1';

  @override
  String get columnConfig_slot_slot2 => 'Slot 2';

  @override
  String get columnConfig_slot_slot3 => 'Slot 3';

  @override
  String get columnConfig_slot_slot4 => 'Slot 4';

  @override
  String get columnConfig_slot_stat1 => 'Kennzahl 1';

  @override
  String get columnConfig_slot_stat2 => 'Kennzahl 2';

  @override
  String get columnConfig_slot_subtitle => 'Untertitel';

  @override
  String get columnConfig_slot_title => 'Titel';

  @override
  String get columnConfig_tooltip_columnSettings => 'Spalteneinstellungen';

  @override
  String get common_action_add => 'Hinzufügen';

  @override
  String get common_action_pin => 'Anheften';

  @override
  String get common_action_remove => 'Entfernen';

  @override
  String get common_action_unpin => 'Lösen';

  @override
  String diveLog_filterChip_dateRange(String end, String start) {
    return '$start - $end';
  }

  @override
  String diveLog_filterChip_equipmentCount(int count) {
    return '$count Ausrüstungsteile';
  }

  @override
  String get diveLog_filter_allComputers => 'Alle Computer';

  @override
  String get diveLog_filter_noComputersRegistered =>
      'Keine Tauchcomputer registriert';

  @override
  String diveLog_filter_sectionDepthRangeUnit(String unit) {
    return 'Tiefenbereich ($unit)';
  }

  @override
  String get diveLog_filter_sectionDiveComputer => 'Tauchcomputer';

  @override
  String diveLog_listPage_semanticsDiveAtSite(int diveNumber, String siteName) {
    return 'Tauchgang $diveNumber bei $siteName';
  }

  @override
  String get enum_listViewMode_compact => 'Kompakt';

  @override
  String get enum_listViewMode_dense => 'Dicht';

  @override
  String get enum_listViewMode_detailed => 'Detailliert';

  @override
  String get enum_listViewMode_table => 'Tabelle';

  @override
  String get enum_profileMetric_ascentRate => 'Aufstiegsgeschwindigkeit';

  @override
  String get enum_profileMetric_cns => 'CNS%';

  @override
  String get enum_profileMetric_otu => 'OTU';

  @override
  String get enum_sortField_bottomTime => 'Grundzeit';

  @override
  String get enum_sortField_serviceDue => 'Wartung fällig';

  @override
  String get listViewMode_tooltip => 'Ansichtsmodus';

  @override
  String marineLife_speciesManage_errorLoading(Object error) {
    return 'Fehler beim Laden der Arten: $error';
  }

  @override
  String get settings_appearance_header_cards => 'Karten';

  @override
  String get settings_appearance_header_listView => 'Listenansicht';

  @override
  String get settings_appearance_header_tableMode => 'Tabellenmodus';

  @override
  String get settings_appearance_listFields_buddies =>
      'Listenfelder für Tauchpartner';

  @override
  String get settings_appearance_listFields_certifications =>
      'Listenfelder für Zertifizierungen';

  @override
  String get settings_appearance_listFields_courses => 'Listenfelder für Kurse';

  @override
  String get settings_appearance_listFields_diveCenters =>
      'Listenfelder für Tauchcenter';

  @override
  String get settings_appearance_listFields_dives =>
      'Listenfelder für Tauchgänge';

  @override
  String get settings_appearance_listFields_equipment =>
      'Listenfelder für Ausrüstung';

  @override
  String get settings_appearance_listFields_sites =>
      'Listenfelder für Tauchplätze';

  @override
  String get settings_appearance_listFields_subtitle =>
      'Felder in Listenansichten anpassen';

  @override
  String get settings_appearance_listFields_trips => 'Listenfelder für Reisen';

  @override
  String get settings_appearance_listView_buddies =>
      'Listenansicht Tauchpartner';

  @override
  String get settings_appearance_listView_buddies_subtitle =>
      'Standardlayout für die Tauchpartnerliste';

  @override
  String get settings_appearance_listView_certifications =>
      'Listenansicht Zertifizierungen';

  @override
  String get settings_appearance_listView_certifications_subtitle =>
      'Standardlayout für die Zertifizierungsliste';

  @override
  String get settings_appearance_listView_courses => 'Listenansicht Kurse';

  @override
  String get settings_appearance_listView_courses_subtitle =>
      'Standardlayout für die Kursliste';

  @override
  String get settings_appearance_listView_diveCenters =>
      'Listenansicht Tauchcenter';

  @override
  String get settings_appearance_listView_diveCenters_subtitle =>
      'Standardlayout für die Tauchcenterliste';

  @override
  String get settings_appearance_listView_dives => 'Listenansicht Tauchgänge';

  @override
  String get settings_appearance_listView_dives_subtitle =>
      'Standardlayout für die Tauchgangsliste';

  @override
  String get settings_appearance_listView_equipment =>
      'Listenansicht Ausrüstung';

  @override
  String get settings_appearance_listView_equipment_subtitle =>
      'Standardlayout für die Ausrüstungsliste';

  @override
  String get settings_appearance_listView_sites => 'Listenansicht Tauchplätze';

  @override
  String get settings_appearance_listView_sites_subtitle =>
      'Standardlayout für die Tauchplatzliste';

  @override
  String get settings_appearance_listView_trips => 'Listenansicht Reisen';

  @override
  String get settings_appearance_listView_trips_subtitle =>
      'Standardlayout für die Reiseliste';

  @override
  String get settings_appearance_showDataSourceBadges =>
      'Datenquellen-Badges anzeigen';

  @override
  String get settings_appearance_showDataSourceBadges_subtitle =>
      'Quellenangabe bei Tauchgangswerten anzeigen';

  @override
  String get settings_appearance_title_buddies => 'Darstellung Tauchpartner';

  @override
  String get settings_appearance_title_certifications =>
      'Darstellung Zertifizierungen';

  @override
  String get settings_appearance_title_courses => 'Darstellung Kurse';

  @override
  String get settings_appearance_title_diveCenters => 'Darstellung Tauchcenter';

  @override
  String get settings_appearance_title_dives => 'Darstellung Tauchgänge';

  @override
  String get settings_appearance_title_equipment => 'Darstellung Ausrüstung';

  @override
  String get settings_appearance_title_sites => 'Darstellung Tauchplätze';

  @override
  String get settings_appearance_title_trips => 'Darstellung Reisen';

  @override
  String get settings_cloudSync_troubleshoot_tileSubtitle =>
      'Hängende Synchronisierung beheben oder Cloud-Speicher freigeben';

  @override
  String get settings_data_header_dataTools => 'Datenwerkzeuge';

  @override
  String get settings_decompression_ascentGasLabel => 'Aufstieg planen mit';

  @override
  String get settings_decompression_ascentGas_allCarried =>
      'Alle mitgeführten Flaschen';

  @override
  String get settings_decompression_ascentGas_decoStage =>
      'Deko-/Stage-Flasche + Rückengas';

  @override
  String get settings_decompression_cnsSource => 'CNS-Quelle';

  @override
  String get settings_decompression_decoStopSource => 'Quelle für Dekostopps';

  @override
  String get settings_decompression_header_ascent => 'Aufstiegsplanung';

  @override
  String get settings_decompression_header_ascent_subtitle =>
      'Auf welche mitgeführten Flaschen der simulierte Aufstieg (TTS, Ceiling und Stopps) in der jeweiligen Tiefe wechseln darf. Berücksichtigt werden nur Gase, die im Tauchgang erfasst sind.';

  @override
  String get settings_decompression_header_dataSources =>
      'Bevorzugte Datenquellen';

  @override
  String get settings_decompression_header_dataSources_subtitle =>
      'Bei der Einstellung Tauchcomputer verwendet die App die vom Tauchcomputer gemeldeten Daten, sofern verfügbar. Liegen keine Computerdaten vor, werden berechnete Werte verwendet.';

  @override
  String get settings_decompression_ndlSource => 'NDL-Quelle';

  @override
  String get settings_decompression_sourceCalculated => 'Berechnet';

  @override
  String get settings_decompression_sourceComputer => 'Tauchcomputer';

  @override
  String get settings_decompression_ttsSource => 'TTS-Quelle';

  @override
  String settings_fixDiveTimes_applied(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgänge',
      one: 'Tauchgang',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'Stunden',
      one: 'Stunde',
    );
    return '$count $_temp0 um $hours $_temp1 angepasst.';
  }

  @override
  String settings_fixDiveTimes_apply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgänge',
      one: 'Tauchgang',
    );
    return 'Auf $count $_temp0 anwenden';
  }

  @override
  String get settings_fixDiveTimes_clearRange => 'Datumsbereich löschen';

  @override
  String get settings_fixDiveTimes_confirmApply => 'Anwenden';

  @override
  String settings_fixDiveTimes_confirmBody(
    int count,
    String hours,
    int hoursAbs,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgänge',
      one: 'Tauchgang',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'Stunden',
      one: 'Stunde',
    );
    return 'Dadurch werden $count $_temp0 um $hours $_temp1 verschoben. Dies kann nicht automatisch rückgängig gemacht werden.';
  }

  @override
  String get settings_fixDiveTimes_confirmTitle => 'Zeitverschiebung anwenden';

  @override
  String get settings_fixDiveTimes_dateRangeFilter => 'Datumsbereichsfilter';

  @override
  String get settings_fixDiveTimes_deselectAll => 'Alle abwählen';

  @override
  String get settings_fixDiveTimes_diveFallback => 'Tauchgang';

  @override
  String settings_fixDiveTimes_diveNumber(int number) {
    return 'Tauchgang Nr. $number';
  }

  @override
  String get settings_fixDiveTimes_empty => 'Keine Tauchgänge gefunden.';

  @override
  String get settings_fixDiveTimes_emptyFiltered =>
      'Keine Tauchgänge in diesem Datumsbereich gefunden.';

  @override
  String get settings_fixDiveTimes_enterOffsetHint =>
      'Geben Sie eine Stundenverschiebung ein';

  @override
  String get settings_fixDiveTimes_from => 'Von';

  @override
  String get settings_fixDiveTimes_hourOffset => 'Stundenverschiebung';

  @override
  String get settings_fixDiveTimes_hoursField => 'Stunden (z. B. +7, -5)';

  @override
  String settings_fixDiveTimes_loadError(String error) {
    return 'Tauchgänge konnten nicht geladen werden: $error';
  }

  @override
  String get settings_fixDiveTimes_noSelection =>
      'Keine Tauchgänge ausgewählt.';

  @override
  String get settings_fixDiveTimes_offsetHint =>
      'Geben Sie eine positive oder negative ganze Zahl ein, um die Tauchzeiten zu verschieben.';

  @override
  String settings_fixDiveTimes_preview(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tauchgänge werden',
      one: 'Tauchgang wird',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'Stunden',
      one: 'Stunde',
    );
    return 'Vorschau: $count $_temp0 um $hours $_temp1 verschoben.';
  }

  @override
  String get settings_fixDiveTimes_selectAll => 'Alle auswählen';

  @override
  String get settings_fixDiveTimes_selectDivesHint =>
      'Tauchgänge zum Anwenden auswählen';

  @override
  String get settings_fixDiveTimes_subtitle =>
      'Zeiten importierter Tauchgänge anpassen';

  @override
  String get settings_fixDiveTimes_title => 'Tauchzeiten korrigieren';

  @override
  String get settings_fixDiveTimes_to => 'Bis';

  @override
  String get settings_fixDiveTimes_zeroOffset =>
      'Die Stundenverschiebung ist 0, es gibt nichts zu ändern.';

  @override
  String get settings_syncDevices_appBar_refreshTooltip => 'Aktualisieren';

  @override
  String get settings_syncDevices_appBar_title => 'Geräte auf diesem Backend';

  @override
  String get settings_syncDevices_empty =>
      'Keine Synchronisierungsdateien auf diesem Backend.';

  @override
  String settings_syncDevices_readError(String error) {
    return 'Das Backend konnte nicht gelesen werden.\n$error';
  }

  @override
  String get settings_syncDevices_removal_noBackend =>
      'Es ist kein Cloud-Backend konfiguriert';

  @override
  String get settings_syncDevices_removal_unreachable =>
      'Das Backend war nicht erreichbar. Es wurde nichts entfernt.';

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
          'Dadurch werden $count Dateien ($size) von $name gelöscht.\n\nDieses Gerät gehört weiterhin zu dieser Synchronisierung. Wenn es wieder online geht, baut es sich aus dem Backend neu auf, statt alte Daten wiederherzustellen, aber alle Änderungen, die es noch nicht veröffentlicht hat, gehen verloren. Ihre Tauchdaten auf DIESEM Gerät sind nicht betroffen.',
      one:
          'Dadurch wird 1 Datei ($size) von $name gelöscht.\n\nDieses Gerät gehört weiterhin zu dieser Synchronisierung. Wenn es wieder online geht, baut es sich aus dem Backend neu auf, statt alte Daten wiederherzustellen, aber alle Änderungen, die es noch nicht veröffentlicht hat, gehen verloren. Ihre Tauchdaten auf DIESEM Gerät sind nicht betroffen.',
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
          'Dadurch werden $count Dateien ($size) von $name gelöscht. Sie stammen noch aus einer Bibliothek, mit der sich kein Gerät mehr synchronisiert. Ihre Tauchdaten sind nicht betroffen.',
      one:
          'Dadurch wird 1 Datei ($size) von $name gelöscht. Sie stammt noch aus einer Bibliothek, mit der sich kein Gerät mehr synchronisiert. Ihre Tauchdaten sind nicht betroffen.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_removeDialog_title(String name) {
    return 'Dateien von $name entfernen?';
  }

  @override
  String settings_syncDevices_removeProgressTitle(String name) {
    return 'Dateien von $name werden entfernt';
  }

  @override
  String get settings_syncDevices_removeTooltip =>
      'Dateien dieses Geräts entfernen';

  @override
  String get settings_syncDevices_state_active => 'Synchronisiert normal';

  @override
  String get settings_syncDevices_state_retired => 'Ausgemustert';

  @override
  String get settings_syncDevices_state_staleEpoch =>
      'Rest einer früheren Bibliothek, kein Gerät liest dies';

  @override
  String get settings_syncDevices_state_thisDevice => 'Dieses Gerät';

  @override
  String get settings_syncDevices_state_unreadable =>
      'Kein lesbares Manifest, ein unvollständiger Upload oder verschlüsselt';

  @override
  String settings_syncDevices_summary(
    int deviceCount,
    int fileCount,
    String size,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      deviceCount,
      locale: localeName,
      other: '$deviceCount Geräte',
      one: '1 Gerät',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: '$fileCount Dateien',
      one: '1 Datei',
    );
    return '$_temp0, $_temp1, $size';
  }

  @override
  String settings_syncDevices_summary_removable(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Reste ersetzter oder ausgemusterter Bibliotheken, belegen $size.',
      one:
          '1 Rest einer ersetzten oder ausgemusterten Bibliothek, belegt $size.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_tile_filesSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
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
      other: '$count Dateien',
      one: '1 Datei',
    );
    return '$_temp0, $size, $when';
  }

  @override
  String settings_syncDevices_unnamedDevice(String shortId) {
    return 'Gerät $shortId';
  }

  @override
  String get settings_syncMaintenance_keepAppOpen =>
      'Lassen Sie die App geöffnet, bis dies abgeschlossen ist. Wenn Sie sie jetzt schließen, bleibt das Backend teilweise geleert und die nächste Synchronisierung muss von vorn beginnen.';

  @override
  String get settings_syncMaintenance_phase_clearingOldFiles =>
      'Alte Dateien werden gelöscht';

  @override
  String get settings_syncMaintenance_phase_deleting => 'Wird gelöscht';

  @override
  String get settings_syncMaintenance_phase_publishingLibrary =>
      'Bibliothek wird veröffentlicht';

  @override
  String get settings_cloudSync_adopt_progressTitle =>
      'Wiederhergestellte Bibliothek wird übernommen';

  @override
  String get settings_cloudSync_replaceLibrary_progressTitle =>
      'Cloud-Bibliothek wird ersetzt';

  @override
  String settings_syncDevices_nameWithId(String name, String shortId) {
    return '$name ($shortId)';
  }

  @override
  String get settings_syncMaintenance_phase_applyingLibrary =>
      'Bibliothek wird angewendet';

  @override
  String get settings_syncMaintenance_phase_backingUp =>
      'Dieses Gerät wird gesichert';

  @override
  String get settings_syncMaintenance_phase_repairing =>
      'Lokaler Sync-Status wird gelöscht';

  @override
  String get settings_troubleshootSync_repair_progressTitle =>
      'Synchronisierung wird repariert';

  @override
  String get settings_syncMaintenance_phase_working => 'Wird ausgeführt...';

  @override
  String settings_syncMaintenance_progress_filesOfTotal(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done von $total Dateien',
      one: '$done von 1 Datei',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_removedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien entfernt',
      one: '1 Datei entfernt',
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
      other:
          '$count Dateien entfernt, aber $trouble. Versuchen Sie es erneut, während Sie online sind.',
      one:
          '1 Datei entfernt, aber $trouble. Versuchen Sie es erneut, während Sie online sind.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_trouble_failed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count konnten nicht gelöscht werden',
      one: '1 konnte nicht gelöscht werden',
    );
    return '$_temp0';
  }

  @override
  String get settings_syncMaintenance_trouble_listIncomplete =>
      'einige Dateien konnten nicht aufgelistet werden';

  @override
  String settings_syncMaintenance_wipedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien gelöscht',
      one: '1 Datei gelöscht',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_wipedFilesPartial(int count, String trouble) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Dateien gelöscht, aber $trouble. Versuchen Sie es erneut, während Sie online sind.',
      one:
          '1 Datei gelöscht, aber $trouble. Versuchen Sie es erneut, während Sie online sind.',
    );
    return '$_temp0';
  }

  @override
  String get settings_troubleshootSync_appBar_title =>
      'Synchronisierungsprobleme beheben';

  @override
  String get settings_troubleshootSync_devices_subtitle =>
      'Sehen Sie jedes Gerät, das hier Dateien hält, wie viel Speicher jedes belegt, und entfernen Sie Reste von Bibliotheken, mit denen sich kein Gerät mehr synchronisiert. Ihre Tauchdaten sind nicht betroffen.';

  @override
  String get settings_troubleshootSync_rebuild_confirm => 'Neu aufbauen';

  @override
  String get settings_troubleshootSync_rebuild_confirmBody =>
      'Dadurch wird die Bibliothek dieses Geräts zur aktuellen Bibliothek auf dem Backend und wird neu veröffentlicht, sodass andere Geräte von Ihnen synchronisieren. Verwenden Sie dies, wenn eine Ersetzung durch ein anderes Gerät hängen bleibt. Ihre Tauchdaten sind nicht betroffen.';

  @override
  String get settings_troubleshootSync_rebuild_confirmTitle =>
      'Backend von diesem Gerät neu aufbauen?';

  @override
  String get settings_troubleshootSync_rebuild_doneSnack =>
      'Backend von diesem Gerät neu aufgebaut';

  @override
  String get settings_troubleshootSync_rebuild_failedSnack =>
      'Neuaufbau fehlgeschlagen';

  @override
  String get settings_troubleshootSync_rebuild_progressTitle =>
      'Backend wird neu aufgebaut';

  @override
  String get settings_troubleshootSync_rebuild_subtitle =>
      'Verwenden Sie dies, wenn die Synchronisierung auf eine Bibliothek wartet, die ein anderes Gerät ersetzt, aber nie fertig hochgeladen hat (dieses Gerät ist möglicherweise offline). Veröffentlicht die Bibliothek dieses Geräts als die aktuelle.';

  @override
  String get settings_troubleshootSync_rebuild_title =>
      'Backend von diesem Gerät neu aufbauen';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmBody =>
      'Dadurch werden nur die Synchronisierungsdateien dieses Geräts vom Backend gelöscht. Andere Geräte synchronisieren weiterhin, und Ihre Tauchdaten sind nicht betroffen.';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmTitle =>
      'Cloud-Dateien dieses Geräts entfernen?';

  @override
  String get settings_troubleshootSync_removeThisDevice_progressTitle =>
      'Cloud-Dateien dieses Geräts werden entfernt';

  @override
  String get settings_troubleshootSync_removeThisDevice_subtitle =>
      'Geben Sie den Speicher dieses Geräts auf dem Backend frei. Andere Geräte synchronisieren weiterhin. Ihre Tauchdaten sind nicht betroffen.';

  @override
  String get settings_troubleshootSync_removeThisDevice_title =>
      'Cloud-Dateien dieses Geräts entfernen';

  @override
  String get settings_troubleshootSync_repair_confirm => 'Reparieren';

  @override
  String get settings_troubleshootSync_repair_confirmBody =>
      'Dadurch wird der gesamte lokale Synchronisierungsstatus gelöscht und dieses Gerät erhält eine neue Synchronisierungsidentität; bei der nächsten Synchronisierung verbindet es sich neu. Ihre Tauchdaten sind sicher und werden nicht gelöscht.';

  @override
  String get settings_troubleshootSync_repair_confirmTitle =>
      'Synchronisierung reparieren?';

  @override
  String get settings_troubleshootSync_repair_doneSnack =>
      'Synchronisierung repariert';

  @override
  String get settings_troubleshootSync_repair_subtitle =>
      'Hängende Synchronisierung beheben. Löscht den Synchronisierungsstatus dieses Geräts und gibt ihm eine neue Synchronisierungsidentität; bei der nächsten Synchronisierung verbindet es sich neu. Ihre Tauchdaten sind nicht betroffen.';

  @override
  String get settings_troubleshootSync_repair_title =>
      'Synchronisierung reparieren';

  @override
  String get settings_troubleshootSync_wipeAll_confirm => 'Alles löschen';

  @override
  String settings_troubleshootSync_wipeAll_confirmBody(String word) {
    return 'Dadurch werden die Synchronisierungsdaten JEDES Geräts von diesem Backend gelöscht, einschließlich der Bibliotheksmarkierungen. Jedes Gerät muss die Synchronisierung von Grund auf neu einrichten. Ihre Tauchdaten sind nicht betroffen.\n\nGeben Sie zur Bestätigung $word ein.';
  }

  @override
  String get settings_troubleshootSync_wipeAll_confirmTitle =>
      'Alle Synchronisierungsdaten löschen?';

  @override
  String get settings_troubleshootSync_wipeAll_progressTitle =>
      'Synchronisierungsdaten werden gelöscht';

  @override
  String get settings_troubleshootSync_wipeAll_subtitle =>
      'Löschen Sie die Synchronisierungsdaten jedes Geräts von diesem Backend, einschließlich der Bibliotheksmarkierungen. Jedes Gerät richtet die Synchronisierung von Grund auf neu ein. Ihre Tauchdaten sind nicht betroffen.';

  @override
  String get settings_troubleshootSync_wipeAll_title =>
      'Alle Synchronisierungsdaten auf diesem Backend löschen';

  @override
  String get tableMode_tooltip_toggleDetailPane => 'Detailbereich umschalten';

  @override
  String get tableMode_tooltip_toggleProfilePanel => 'Profilbereich umschalten';

  @override
  String get maps_regionDownload_title => 'Region herunterladen';

  @override
  String get maps_regionDownload_nameRequired =>
      'Bitte geben Sie einen Namen für diese Region ein';

  @override
  String get maps_regionDownload_nameLabel => 'Regionsname';

  @override
  String get maps_regionDownload_nameHint => 'z.B. Cozumel, Mexiko';

  @override
  String get maps_regionDownload_zoomLevels => 'Zoomstufen';

  @override
  String get maps_regionDownload_zoomHint =>
      'Höherer Zoom = mehr Details, größerer Download';

  @override
  String maps_regionDownload_minZoom(int zoom) {
    return 'Min.: $zoom';
  }

  @override
  String maps_regionDownload_minZoomSemantics(int zoom) {
    return 'Minimaler Zoom: $zoom';
  }

  @override
  String maps_regionDownload_maxZoom(int zoom) {
    return 'Max.: $zoom';
  }

  @override
  String maps_regionDownload_maxZoomSemantics(int zoom) {
    return 'Maximaler Zoom: $zoom';
  }

  @override
  String get maps_regionDownload_estimatingSemantics =>
      'Download-Größe wird geschätzt';

  @override
  String maps_regionDownload_estimateSemantics(int count, Object size) {
    return 'Geschätzter Download: $count Kacheln, $size';
  }

  @override
  String get maps_regionDownload_estimateUnavailableSemantics =>
      'Download-Größe kann nicht geschätzt werden';

  @override
  String get maps_regionDownload_estimating => 'Wird geschätzt...';

  @override
  String maps_regionDownload_tileCount(int count) {
    return '~$count Kacheln';
  }

  @override
  String get maps_regionDownload_estimateUnavailable =>
      'Schätzung nicht möglich';

  @override
  String get maps_regionDownload_largeWarningSemantics =>
      'Warnung: Großer Download. Reduzieren Sie die Zoomstufen oder wählen Sie eine kleinere Region.';

  @override
  String get maps_regionDownload_largeWarning =>
      'Großer Download. Reduzieren Sie die Zoomstufen oder wählen Sie eine kleinere Region.';

  @override
  String get maps_regionDownload_downloadButton => 'Herunterladen';

  @override
  String get diveLog_map_title => 'Tauchaktivität';

  @override
  String diveLog_map_infoCard_minutes(int minutes) {
    return '$minutes Min.';
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
      'Fotovorschau. Tippen, um im Vollbild anzuzeigen';

  @override
  String get trips_gallery_thumbnail_video =>
      'Videovorschau. Tippen, um im Vollbild anzuzeigen';

  @override
  String get trips_gallery_thumbnail_photoMissing =>
      'Fotovorschau, auf dem Gerät nicht vorhanden. Tippen, um im Vollbild anzuzeigen';

  @override
  String get trips_gallery_thumbnail_videoMissing =>
      'Videovorschau, auf dem Gerät nicht vorhanden. Tippen, um im Vollbild anzuzeigen';

  @override
  String get trips_photos_thumbnail_photo =>
      'Fotovorschau. Tippen, um die Galerie zu öffnen';

  @override
  String get trips_photos_thumbnail_video =>
      'Videovorschau. Tippen, um die Galerie zu öffnen';

  @override
  String trips_picker_suggestedSemantics(Object name) {
    return 'Vorgeschlagene Reise: $name. Tippen, um sie zu verwenden';
  }

  @override
  String trips_picker_tileSemantics(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, $startDate bis $endDate';
  }

  @override
  String trips_picker_tileSemanticsSelected(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, $startDate bis $endDate, ausgewählt';
  }

  @override
  String get divePlanner_quickPlan_subtitle =>
      'Ein einfaches rechteckiges Tauchprofil erstellen';

  @override
  String get divePlanner_quickPlan_depthLabel => 'Tiefe:';

  @override
  String divePlanner_quickPlan_depthSemantics(Object depth) {
    return 'Tiefe: $depth';
  }

  @override
  String get divePlanner_quickPlan_timeLabel => 'Zeit:';

  @override
  String divePlanner_quickPlan_bottomTimeSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Grundzeit: $minutes Minuten',
      one: 'Grundzeit: 1 Minute',
    );
    return '$_temp0';
  }

  @override
  String divePlanner_quickPlan_minutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String divePlanner_quickPlan_previewSemantics(Object depth, int minutes) {
    return 'Planvorschau: Abstieg auf $depth, Grundzeit $minutes Minuten, Aufstieg mit Sicherheitsstopp';
  }

  @override
  String get divePlanner_quickPlan_previewTitle => 'Planvorschau:';

  @override
  String divePlanner_quickPlan_previewDescent(Object depth) {
    return 'Abstieg auf $depth';
  }

  @override
  String divePlanner_quickPlan_previewBottomTime(int minutes) {
    return 'Grundzeit: $minutes Min.';
  }

  @override
  String get divePlanner_quickPlan_previewAscent =>
      'Aufstieg mit Sicherheitsstopp';

  @override
  String get divePlanner_quickPlan_create => 'Erstellen';

  @override
  String divePlanner_semantics_sacRate(Object value, Object volumeSymbol) {
    return 'AMV: $value $volumeSymbol pro Minute';
  }

  @override
  String divePlanner_semantics_reservePressure(Object pressureSymbol) {
    return 'Reservedruck in $pressureSymbol';
  }

  @override
  String divePlanner_semantics_altitudeGroup(Object group) {
    return 'Höhengruppe: $group';
  }

  @override
  String diveSites_import_detail_maxDepth(Object depth) {
    return 'Max. $depth';
  }

  @override
  String get autoUpdate_banner_download => 'Herunterladen';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Über Apple iCloud synchronisieren';

  @override
  String get settings_debugLog_search_hint => 'Protokolle durchsuchen...';

  @override
  String get settings_debugLog_appBar_title => 'Debug-Protokolle';

  @override
  String get settings_debugLog_disableDebugMode => 'Debug-Modus deaktivieren';

  @override
  String get settings_debugLog_clearLogs => 'Protokolle löschen';

  @override
  String get settings_debugLog_empty =>
      'Keine Protokolleinträge entsprechen den aktuellen Filtern';

  @override
  String settings_debugLog_loadError(Object error) {
    return 'Fehler beim Laden der Protokolle: $error';
  }

  @override
  String get settings_debugLog_copiedSnack =>
      'Gefilterte Protokolle in die Zwischenablage kopiert';

  @override
  String settings_debugLog_savedSnack(String path) {
    return 'Protokolle gespeichert unter $path';
  }

  @override
  String get common_action_copy => 'Kopieren';

  @override
  String get settings_appearance_customGradient_title => 'Eigener Farbverlauf';

  @override
  String get settings_appearance_customGradient_start => 'Start';

  @override
  String get settings_appearance_customGradient_end => 'Ende';

  @override
  String get settings_appearance_customGradient_hue => 'Farbton';

  @override
  String get settings_appearance_customGradient_saturation => 'Sättigung';

  @override
  String get settings_appearance_customGradient_brightness => 'Helligkeit';

  @override
  String get settings_appearance_customGradient_preview => 'Vorschau';

  @override
  String get common_action_apply => 'Übernehmen';

  @override
  String settings_cloudSync_message_loadStateFailed(Object error) {
    return 'Synchronisierungsstatus konnte nicht geladen werden: $error';
  }

  @override
  String get settings_cloudSync_message_noProviderConfigured =>
      'Kein Cloud-Anbieter konfiguriert';

  @override
  String get settings_cloudSync_message_adopting =>
      'Wiederhergestellte Bibliothek wird übernommen...';

  @override
  String get settings_cloudSync_message_adoptFailed =>
      'Wiederhergestellte Bibliothek konnte nicht übernommen werden';

  @override
  String get settings_cloudSync_message_firstSyncNeedsConfirm =>
      'Die erste Synchronisierung muss bestätigt werden. Tippen Sie auf „Jetzt synchronisieren“, um sie zu prüfen.';

  @override
  String get settings_cloudSync_message_startingSync =>
      'Synchronisierung wird gestartet...';

  @override
  String get settings_cloudSync_message_replacePaused =>
      'Synchronisierung pausiert: Die Bibliothek wurde aus einer Sicherung ersetzt. Tippen Sie auf „Jetzt synchronisieren“, um sie zu prüfen.';

  @override
  String get settings_cloudSync_message_encryptedPaused =>
      'Synchronisierung pausiert: Diese Bibliothek ist verschlüsselt. Geben Sie die Passphrase ein, um fortzufahren.';

  @override
  String get settings_cloudSync_message_completedWithConflicts =>
      'Synchronisierung mit Konflikten abgeschlossen';

  @override
  String get settings_cloudSync_message_completedSuccessfully =>
      'Synchronisierung erfolgreich abgeschlossen';

  @override
  String get settings_cloudSync_message_syncFailed =>
      'Synchronisierung fehlgeschlagen';

  @override
  String get settings_cloudSync_message_phaseDefault => 'Synchronisierung';

  @override
  String settings_cloudSync_message_syncErrorDuring(
    String phase,
    Object error,
  ) {
    return 'Synchronisierungsfehler bei $phase: $error';
  }

  @override
  String get settings_section_debug_title => 'Debug';

  @override
  String get settings_section_debug_subtitle => 'Protokolle & Diagnose';

  @override
  String get settings_debugLog_minSeverityLabel => 'Min. Schweregrad:';

  @override
  String get settings_debugLog_shareSubject => 'Submersion-Debug-Protokolle';

  @override
  String get settings_debugLog_saveDialogTitle => 'Debug-Protokolle speichern';

  @override
  String get universalImport_preset_saveTitle => 'Als Vorlage speichern';

  @override
  String get universalImport_preset_nameLabel => 'Vorlagenname';

  @override
  String get universalImport_preset_nameHint => 'z.B. Mein Tauchlogbuch-CSV';

  @override
  String get universalImport_preset_nameRequired => 'Name ist erforderlich';

  @override
  String get universalImport_preset_sourceAppLabel => 'Quellanwendung';

  @override
  String get universalImport_preset_sourceAppNone => 'Keine';

  @override
  String get universalImport_preset_entityTypesLabel => 'Datentypen';

  @override
  String get universalImport_preset_matchThresholdLabel =>
      'Übereinstimmungsschwelle';

  @override
  String get universalImport_preset_matchThresholdHelp =>
      'Wie genau CSV-Überschriften für die automatische Erkennung übereinstimmen müssen';

  @override
  String universalImport_preset_signatureHeaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Signaturüberschriften aus der aktuellen Datei',
      one: '1 Signaturüberschrift aus der aktuellen Datei',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_preset_selectTitle => 'Vorlage auswählen';

  @override
  String universalImport_preset_loadFailed(String error) {
    return 'Vorlagen konnten nicht geladen werden: $error';
  }

  @override
  String get universalImport_preset_sectionSaved => 'Gespeicherte Vorlagen';

  @override
  String get universalImport_preset_sectionBuiltIn => 'Integrierte Vorlagen';

  @override
  String get universalImport_preset_deleteTitle => 'Vorlage löschen';

  @override
  String universalImport_preset_deleteConfirm(String name) {
    return '„$name“ löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String universalImport_preset_headersMatched(
    int matched,
    int total,
    int percent,
  ) {
    return '$matched/$total Überschriften übereinstimmend ($percent%)';
  }

  @override
  String get universalImport_preset_noSignatureHeaders =>
      'Keine Signaturüberschriften';

  @override
  String get universalImport_preset_deleteTooltip => 'Vorlage löschen';

  @override
  String get universalImport_preset_presetsButton => 'Vorlagen';

  @override
  String universalImport_preset_savedSnackbar(String name) {
    return 'Vorlage „$name“ gespeichert';
  }

  @override
  String get universalImport_step_done => 'Fertig';

  @override
  String get universalImport_cancel_inProgressTitle => 'Wird abgebrochen';

  @override
  String get universalImport_cancel_inProgressBody =>
      'Der aktuelle Tauchgang wird noch abgeschlossen, dann wird gestoppt. Bereits importierte Tauchgänge bleiben erhalten.';

  @override
  String get universalImport_cancel_confirmTitle => 'Import abbrechen?';

  @override
  String get universalImport_cancel_confirmBody =>
      'Nach Abschluss des aktuellen Tauchgangs stoppen. Bereits importierte Tauchgänge bleiben erhalten.';

  @override
  String get universalImport_cancel_keepImporting => 'Weiter importieren';

  @override
  String get universalImport_cancel_confirmAction => 'Import abbrechen';

  @override
  String get universalImport_cancel_discardSelections =>
      'Auswahl verwerfen und abbrechen?';

  @override
  String get universalImport_action_importSelected => 'Auswahl importieren';

  @override
  String get universalImport_action_next => 'Weiter';

  @override
  String get common_action_yes => 'Ja';

  @override
  String get common_action_no => 'Nein';

  @override
  String universalImport_counts_new(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neu',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_merging(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zusammenführen',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_replacing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ersetzen',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_skipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count übersprungen',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_counts_nothingSelected => 'Nichts ausgewählt';

  @override
  String get universalImport_section_potentialDuplicates =>
      'Potenzielle Duplikate';

  @override
  String get universalImport_section_possibleDuplicates => 'Mögliche Duplikate';

  @override
  String universalImport_count_duplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Duplikate',
      one: '1 Duplikat',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_entityAction_importBadge => 'IMPORTIEREN';

  @override
  String get universalImport_entityAction_skipBadge => 'ÜBERSPRINGEN';

  @override
  String get universalImport_compare_existing => 'Vorhanden';

  @override
  String get universalImport_compare_incoming => 'Eingehend';

  @override
  String get universalImport_label_skipped => 'Übersprungen';

  @override
  String get universalImport_action_viewDives => 'Tauchgänge anzeigen';

  @override
  String get diveImport_healthkit_accessGranted => 'HealthKit-Zugriff gewährt';

  @override
  String get diveImport_healthkit_accessGrantedBody =>
      'Sie können mit dem nächsten Schritt fortfahren.';

  @override
  String get diveImport_healthkit_requesting => 'Wird angefragt...';

  @override
  String get diveImport_healthkit_selectDateRange => 'Zeitraum auswählen';

  @override
  String get diveImport_healthkit_selectDateRangeBody =>
      'Wählen Sie den Zeitraum, in dem in Apple Health nach Tauchgängen gesucht werden soll.';

  @override
  String get diveImport_healthkit_fetchingDives =>
      'Tauchgänge werden aus Apple Health abgerufen...';

  @override
  String get diveImport_healthkit_fetchFailed => 'Abruf fehlgeschlagen';

  @override
  String diveImport_healthkit_fetchFailedBody(String error) {
    return 'Tauchgänge konnten nicht abgerufen werden: $error';
  }

  @override
  String diveImport_healthkit_foundDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tauchgänge gefunden',
      one: '1 Tauchgang gefunden',
    );
    return '$_temp0';
  }

  @override
  String get diveImport_healthkit_proceedingToReview =>
      'Weiter zur Überprüfung...';

  @override
  String get importWizard_dc_knownComputer => 'Bekannter Computer';

  @override
  String importWizard_dc_knownComputerBody(String name) {
    return 'Gespeichert als „$name“. Es werden nur neue Tauchgänge heruntergeladen.';
  }

  @override
  String get importWizard_dc_noNewDives =>
      'Keine neuen Tauchgänge zum Herunterladen';

  @override
  String get importWizard_dc_noNewDivesBody =>
      'Alle Tauchgänge von diesem Computer wurden bereits importiert.';

  @override
  String get universalImport_compare_noDiveData =>
      'Tauchdaten für den Vergleich nicht verfügbar.';

  @override
  String get universalImport_entityAction_consolidateBadge => 'ZUSAMMENFÜHREN';

  @override
  String get diveCenters_import_quickSearch_egypt => 'Ägypten';

  @override
  String get diveCenters_import_quickSearch_mexico => 'Mexiko';

  @override
  String get accessibility_shortcut_switchDiver => 'Taucher wechseln';

  @override
  String get lock_recoveryCode_title => 'Wiederherstellungscode verwenden';

  @override
  String get lock_recoveryCode_body =>
      'Geben Sie den 8-Wort-Wiederherstellungscode ein, den Sie beim Einrichten des App-Passworts gespeichert haben.';

  @override
  String get lock_recoveryCode_error => 'Falscher Wiederherstellungscode.';

  @override
  String get lock_forcedReset_title => 'Neues Passwort festlegen';

  @override
  String get lock_forcedReset_body =>
      'Sie haben mit Ihrem Wiederherstellungscode entsperrt, daher gilt Ihr altes Passwort nicht mehr als vertrauenswürdig. Wählen Sie jetzt ein neues.';

  @override
  String get lock_forcedReset_submit => 'Passwort festlegen';

  @override
  String get lock_forcedReset_error =>
      'Das neue Passwort konnte nicht festgelegt werden. Versuchen Sie es erneut.';

  @override
  String get lock_sidecarRepair_title => 'Sicherheitsschlüsseldatei reparieren';

  @override
  String get lock_sidecarRepair_body =>
      'Ihre Sicherheitsschlüsseldatei fehlte, und der Schlüsselbund dieses Geräts enthält den Schlüssel noch. Bestätigen Sie Ihr Passwort, um eine neue Schlüsseldatei zu schreiben. Hinweis: Das hier eingegebene Passwort wird ab sofort zum App-Passwort, und Sie erhalten einen neuen Wiederherstellungscode.';

  @override
  String get lock_sidecarRepair_submit => 'Reparieren';

  @override
  String get lock_sidecarRepair_error =>
      'Reparatur fehlgeschlagen. Versuchen Sie es erneut.';

  @override
  String get lock_newRecoveryCode_title => 'Ihr neuer Wiederherstellungscode';

  @override
  String get lock_startFresh_title => 'Eine andere Datenbank öffnen';

  @override
  String lock_startFresh_body(Object token) {
    return 'Ihre aktuelle Datenbank bleibt auf dem Datenträger, umbenannt mit der Endung .locked; es wird nichts gelöscht. Sie können sie später mit Ihrem Passwort oder über den Support wiederherstellen. Die Cloud-Synchronisierung wird deaktiviert, damit sich die neue Datenbank nicht mit der alten vermischen kann.\n\nDie App startet mit einer neuen, leeren Datenbank. Im Einrichtungsassistenten können Sie eine Sicherung wiederherstellen.\n\nGeben Sie zur Bestätigung $token ein.';
  }

  @override
  String get lock_startFresh_confirm => 'Beiseitelegen und neu beginnen';

  @override
  String get lock_biometric_reason => 'Entsperren Sie Ihr Tauchlogbuch';

  @override
  String startup_migrating_progress(Object currentStep, Object totalSteps) {
    return 'Datenbank wird aktualisiert... Schritt $currentStep von $totalSteps';
  }

  @override
  String get startup_error_title => 'Submersion konnte nicht starten';

  @override
  String get startup_error_body =>
      'Etwas ist schiefgelaufen, bevor Ihr Tauchlogbuch vollständig geöffnet war. Ihre Daten befinden sich weiterhin auf dem Datenträger und eine Neuinstallation ist nicht erforderlich. Starten Sie die App neu; falls das Problem weiterhin besteht, kontaktieren Sie den Support.';

  @override
  String get startup_engineUnavailable_title =>
      'Dieser Build kann keine Datenbank öffnen';

  @override
  String get startup_engineUnavailable_body =>
      'In diesem Build fehlt die Datenbank-Engine von Submersion, daher wurde Ihr Tauchlogbuch nie geöffnet. Auf dem Datenträger hat sich nichts geändert und es sind keine Daten gefährdet.';

  @override
  String get startup_engineUnavailable_guidance =>
      'Eine Neuinstallation oder das Wiederherstellen einer Sicherung hilft hier nicht. Installieren Sie einen funktionierenden Build von Submersion und melden Sie dies bitte: Es ist ein Fehler im App-Paket, nicht in Ihren Daten.';

  @override
  String get startup_migrationFailed_title =>
      'Datenbank-Upgrade fehlgeschlagen';

  @override
  String get startup_migrationFailed_body =>
      'Ihr Tauchlogbuch konnte nicht auf das Format aktualisiert werden, das diese Version benötigt. Vor Beginn des Upgrades wurde eine Sicherungskopie erstellt, es geht also nichts verloren.';

  @override
  String get startup_dataUnreadable_title =>
      'Ihr Tauchlogbuch konnte nicht gelesen werden';

  @override
  String get startup_dataUnreadable_body =>
      'Die Datenbankdatei ist vorhanden, aber Submersion kann sie nicht lesen. Das bedeutet meist, dass die Datei beschädigt ist. Das Wiederherstellen einer Sicherung ist der schnellste Weg zurück.';

  @override
  String get startup_databaseBusy_title => 'Ihr Tauchlogbuch war belegt';

  @override
  String get startup_databaseBusy_body =>
      'Etwas anderes hat die Datenbankdatei noch verwendet, deshalb hat Submersion angehalten, statt hineinzuschreiben. Es wurde nichts geändert und nichts beschädigt. Schließen Sie Submersion vollständig und öffnen Sie es erneut.';

  @override
  String get startup_failure_technicalDetails => 'Technische Details';

  @override
  String get startup_failure_backupAvailable_title =>
      'Eine Sicherung ist verfügbar';

  @override
  String startup_failure_backupAvailable_taken(Object timestamp) {
    return 'Erstellt am $timestamp';
  }

  @override
  String startup_failure_backupAvailable_preMigration(
    Object fromVersion,
    Object toVersion,
  ) {
    return 'Sicherungskopie erstellt vor dem Upgrade von Schema v$fromVersion auf v$toVersion.';
  }

  @override
  String get startup_failure_restoreAction =>
      'Diese Sicherung wiederherstellen';

  @override
  String get startup_failure_restoring =>
      'Tauchlogbuch wird wiederhergestellt ...';

  @override
  String get startup_failure_restoreFailed =>
      'Die Sicherung konnte nicht wiederhergestellt werden. Ihr Tauchlogbuch wurde unverändert gelassen.';

  @override
  String get startup_failure_backupsFolder => 'Ihre Sicherungen liegen in:';

  @override
  String get startup_failure_showBackupsFolder => 'Sicherungsordner anzeigen';

  @override
  String get startup_failure_downgrade_title => 'Zurück zur vorherigen Version';

  @override
  String get startup_failure_downgrade_body =>
      'Wenn das Upgrade weiterhin fehlschlägt, installieren Sie die zuvor verwendete Version von Submersion und stellen Sie die Sicherungskopie aus dieser Version heraus wieder her. Eine Wiederherstellung hier würde nur dasselbe Upgrade erneut ausführen. Submersion führt kein automatisches Downgrade durch: Sie automatisch auf ältere Builds zurückzusetzen würde Sie stillschweigend auf Versionen mit bekannten Problemen halten.';

  @override
  String get startup_failure_downgrade_action => 'Frühere Versionen ansehen';

  @override
  String get startup_recovering_title => 'Datenbank wird wiederhergestellt...';

  @override
  String get startup_recovering_body =>
      'Die unterbrochene Transaktion wird zurückgesetzt. Das dauert normalerweise einige Sekunden.';

  @override
  String get startup_recoveryFailed_title =>
      'Wiederherstellung nicht abgeschlossen';

  @override
  String get startup_recoveryFailed_body =>
      'Die Datenbank konnte nicht automatisch zurückgesetzt werden. Ihre Daten befinden sich weiterhin auf dem Datenträger; kontaktieren Sie den Support, bevor Sie neu installieren, damit wir Ihnen bei der Wiederherstellung helfen können.';

  @override
  String get startup_recoveryRequired_title =>
      'Datenbank muss wiederhergestellt werden';

  @override
  String get startup_recoveryRequired_body =>
      'Eine frühere Sitzung wurde beim Schreiben in die Datenbank unterbrochen. Ihre Daten befinden sich weiterhin auf dem Datenträger; wir müssen nur das Zurücksetzen der abgebrochenen Änderung abschließen, bevor die App geöffnet werden kann.';

  @override
  String startup_recovery_sqliteCode(Object code) {
    return 'SQLite-Code $code';
  }

  @override
  String get startup_recovery_action => 'Datenbank wiederherstellen';

  @override
  String get startup_recovery_closeWithoutRecovering =>
      'Ohne Wiederherstellung schließen';

  @override
  String get common_action_tryAgain => 'Erneut versuchen';

  @override
  String get lock_screen_title => 'Submersion ist gesperrt';

  @override
  String get lock_screen_forgotPassword => 'Passwort vergessen?';

  @override
  String get lock_incorrectPassword =>
      'Falsches Passwort. Versuchen Sie es erneut.';

  @override
  String get startup_backup_semanticsLabel => 'Sicherung läuft';

  @override
  String get startup_backup_title => 'Ihre Daten werden gesichert';

  @override
  String get startup_backup_body =>
      'Wir speichern eine Kopie Ihres Tauchlogbuchs, bevor wir Ihre Datenbank aktualisieren.';

  @override
  String get startup_backupFailed_title =>
      'Ihre Daten konnten nicht gesichert werden';

  @override
  String get startup_backupFailed_body =>
      'Ihr Tauchlogbuch wurde nicht verändert; wir haben es nicht aktualisiert. Geben Sie Speicherplatz frei (oder beheben Sie das Problem) und versuchen Sie es erneut.';

  @override
  String get startup_backupFailed_quit => 'Beenden';

  @override
  String get startup_backupFailed_technicalDetails => 'Technische Details';

  @override
  String get common_action_retry => 'Wiederholen';

  @override
  String get startup_versionMismatch_title => 'Update erforderlich';

  @override
  String startup_versionMismatch_body(
    Object databaseVersion,
    Object appVersion,
  ) {
    return 'Ihre Tauchdaten wurden mit einer neueren Version von Submersion gespeichert (Schema v$databaseVersion). Diese Version unterstützt Schemata nur bis v$appVersion.';
  }

  @override
  String get startup_versionMismatch_instructions =>
      'Bitte aktualisieren Sie Submersion auf die neueste Version. Ihre Daten sind sicher und wurden nicht verändert. Falls vor dem Upgrade eine Sicherung erstellt wurde, liegt sie in Ihrem Ordner Backups und kann nach dem Update wiederhergestellt werden.';

  @override
  String get startup_versionMismatch_storeInstructions =>
      'Diese App wurde aus einem App Store installiert und ist älter als die Version, die Ihre Daten erstellt hat. Ihre Daten sind sicher und wurden nicht verändert. Aktualisieren Sie Submersion, sobald die neue Version im Store erscheint, und öffnen Sie die App dann erneut.';

  @override
  String get startup_versionMismatch_download =>
      'Neueste Version herunterladen';

  @override
  String get startup_versionMismatch_manualLink =>
      'Falls sich dadurch kein Browser öffnet, besuchen Sie:';

  @override
  String get universalImport_compare_downloaded => 'Heruntergeladen';

  @override
  String get universalImport_compare_errorLoading =>
      'Fehler beim Laden der Tauchgangsdaten';

  @override
  String get universalImport_compare_diveNotFound =>
      'Vorhandener Tauchgang nicht gefunden';

  @override
  String universalImport_compare_sameFields(Object fields) {
    return 'Gleich: $fields';
  }

  @override
  String get universalImport_compare_differences => 'UNTERSCHIEDE';

  @override
  String get universalImport_compare_notRecorded => 'nicht erfasst';

  @override
  String universalImport_compare_serial(Object serial) {
    return 'S/N: $serial';
  }

  @override
  String get universalImport_compare_skipSubtitle =>
      'Diesen Download verwerfen';

  @override
  String get universalImport_compare_importAsNewSubtitle =>
      'Als separaten Tauchgang speichern';

  @override
  String get universalImport_compare_consolidateSubtitle =>
      'Als 2. Computermessung hinzufügen';

  @override
  String get diveLog_tooltip_ndlOverMax => '>60 min';

  @override
  String diveLog_tooltip_interpolated(String value) {
    return '$value (interpoliert)';
  }

  @override
  String get enum_profileMetric_ascentRate_short => 'Rate';

  @override
  String get enum_profileMetric_cns_short => 'CNS';

  @override
  String get enum_profileMetric_otu_short => 'OTU';

  @override
  String get diveLog_profileEditor_rangeOperations => 'Bereichsaktionen';

  @override
  String get diveLog_profileEditor_selectRangeHint =>
      'Wählen Sie im Diagramm einen Bereich aus, um Aktionen zu aktivieren';

  @override
  String get diveLog_profileEditor_depthPlusOneMeter => 'Tiefe +1 m';

  @override
  String get diveLog_profileEditor_depthMinusOneMeter => 'Tiefe -1 m';

  @override
  String get diveLog_profileEditor_timePlusFiveSeconds => 'Zeit +5 s';

  @override
  String get diveLog_profileEditor_timeMinusFiveSeconds => 'Zeit -5 s';

  @override
  String get diveLog_profileEditor_smoothing => 'Glättung';

  @override
  String get diveLog_profileEditor_smoothLight => 'Leicht';

  @override
  String get diveLog_profileEditor_smoothMedium => 'Mittel';

  @override
  String get diveLog_profileEditor_smoothHeavy => 'Stark';

  @override
  String get diveLog_profileEditor_applyToAll => 'Auf alle anwenden';

  @override
  String get diveLog_profileEditor_applyToSelection => 'Auf Auswahl anwenden';

  @override
  String get diveLog_profileEditor_outlierDetection => 'Ausreißererkennung';

  @override
  String get diveLog_profileEditor_detect => 'Erkennen';

  @override
  String get diveLog_profileEditor_removeAll => 'Alle entfernen';

  @override
  String diveLog_profileEditor_outliersDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mögliche Ausreißer erkannt',
      one: '$count möglicher Ausreißer erkannt',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_profileEditor_manualDrawing => 'Manuelles Zeichnen';

  @override
  String get diveLog_profileEditor_drawHint =>
      'Tippen Sie auf das Diagramm, um Wegpunkte zu setzen';

  @override
  String get diveLog_profileEditor_clearWaypoints => 'Löschen';

  @override
  String get diveLog_profileEditor_generateProfile => 'Profil erzeugen';

  @override
  String get diveLog_profileEditor_trimMode => 'Zuschneidemodus';

  @override
  String get diveLog_profileEditor_trimHint => 'Profilenden zuschneiden';

  @override
  String get diveLog_profileEditor_trimEnd => 'Ende zuschneiden';

  @override
  String get diveLog_profileEditor_mode_smooth => 'Glätten';

  @override
  String get diveLog_profileEditor_title => 'Profil bearbeiten';

  @override
  String get diveLog_profileEditor_discardBody =>
      'Sie haben nicht gespeicherte Änderungen an diesem Tauchprofil. Möchten Sie diese wirklich verwerfen?';

  @override
  String get diveLog_profileEditor_saveTitle => 'Profil speichern?';

  @override
  String get diveLog_profileEditor_saveBody =>
      'Dadurch wird das bearbeitete Profil als primäres Profil für diesen Tauchgang gespeichert. Das ursprüngliche Profil bleibt erhalten und kann später wiederhergestellt werden.';

  @override
  String diveLog_profileEditor_saveFailed(String error) {
    return 'Profil konnte nicht gespeichert werden: $error';
  }

  @override
  String diveLog_profileEditor_errorLoadingDive(String error) {
    return 'Fehler beim Laden des Tauchgangs: $error';
  }

  @override
  String get diveLog_profileEditor_noProfileData =>
      'Keine Profildaten verfügbar';

  @override
  String get diveLog_profileEditor_undo => 'Rückgängig';

  @override
  String get diveLog_profileEditor_mode_select => 'Auswählen';

  @override
  String get diveLog_profileEditor_mode_outlier => 'Ausreißer';

  @override
  String get diveLog_profileEditor_mode_draw => 'Zeichnen';

  @override
  String get diveLog_profileEditor_mode_trim => 'Zuschneiden';

  @override
  String diveLog_sources_sectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Datenquellen',
      one: 'Datenquelle',
      zero: 'Datenquelle',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_badge_manual => 'Manuell';

  @override
  String get diveLog_sources_badge_viewing => 'Angezeigt';

  @override
  String get diveLog_sources_badge_secondary => 'Sekundär';

  @override
  String diveLog_sources_created(String date) {
    return 'Erstellt $date';
  }

  @override
  String get diveLog_sources_detail_serial => 'Seriennummer';

  @override
  String get diveLog_sources_detail_format => 'Format';

  @override
  String get diveLog_sources_detail_imported => 'Importiert';

  @override
  String diveLog_detail_semantics_viewDiveComputer(String name) {
    return 'Tauchcomputer $name anzeigen';
  }

  @override
  String diveLog_detail_semantics_viewTrip(String name) {
    return 'Reise $name anzeigen';
  }

  @override
  String diveLog_detail_semantics_viewDiveCenter(String name) {
    return 'Tauchbasis $name anzeigen';
  }

  @override
  String diveLog_detail_semantics_viewSpecies(String name) {
    return 'Art $name anzeigen';
  }

  @override
  String diveLog_detail_semantics_viewCourse(String name) {
    return 'Kurs $name anzeigen';
  }

  @override
  String diveLog_detail_serialNumber(String serial) {
    return 'S/N $serial';
  }

  @override
  String diveLog_detail_errorLoadingSignature(String error) {
    return 'Fehler beim Laden der Unterschrift: $error';
  }

  @override
  String get diveLog_profilePanel_selectDive =>
      'Wählen Sie einen Tauchgang, um sein Profil anzuzeigen';

  @override
  String get diveLog_profilePanel_noProfileData =>
      'Keine Profildaten für diesen Tauchgang';

  @override
  String get settings_export_progress_divesCsv =>
      'Tauchgänge werden nach CSV exportiert...';

  @override
  String get settings_export_progress_sitesCsv =>
      'Tauchplätze werden nach CSV exportiert...';

  @override
  String get settings_export_progress_equipmentCsv =>
      'Ausrüstung wird nach CSV exportiert...';

  @override
  String get settings_export_progress_pdf => 'PDF-Logbuch wird erstellt...';

  @override
  String get settings_export_progress_loadingSignatures =>
      'Signaturen werden geladen...';

  @override
  String get settings_export_progress_loadingCertifications =>
      'Zertifizierungen werden geladen...';

  @override
  String get settings_export_progress_loadingFonts =>
      'Schriftarten werden geladen...';

  @override
  String settings_export_progress_templatePdf(String template) {
    return '$template-PDF wird erstellt...';
  }

  @override
  String get settings_export_progress_uddf => 'UDDF-Datei wird erstellt...';

  @override
  String get settings_export_progress_collectingData =>
      'Alle Daten werden gesammelt...';

  @override
  String get settings_export_progress_excel => 'Excel-Datei wird erstellt...';

  @override
  String get settings_export_progress_buildingExcel =>
      'Excel-Arbeitsmappe wird aufgebaut...';

  @override
  String get settings_export_progress_kml => 'KML-Datei wird erstellt...';

  @override
  String get settings_export_progress_buildingKml =>
      'KML-Datei wird aufgebaut...';

  @override
  String get settings_export_progress_preparingExcel =>
      'Excel-Datei wird vorbereitet...';

  @override
  String get settings_export_progress_preparingKml =>
      'KML-Datei wird vorbereitet...';

  @override
  String get settings_export_progress_chooseLocation => 'Speicherort wählen...';

  @override
  String get settings_export_progress_preparingDivesCsv =>
      'Tauchgänge-CSV wird vorbereitet...';

  @override
  String get settings_export_progress_preparingSitesCsv =>
      'Tauchplätze-CSV wird vorbereitet...';

  @override
  String get settings_export_progress_preparingEquipmentCsv =>
      'Ausrüstungs-CSV wird vorbereitet...';

  @override
  String get settings_export_progress_preparingUddf =>
      'UDDF-Datei wird vorbereitet...';

  @override
  String get settings_export_progress_preparingPdf => 'PDF wird vorbereitet...';

  @override
  String get settings_export_progress_selectingBackup =>
      'Sicherungsdatei wird ausgewählt...';

  @override
  String get settings_export_progress_restoringBackup =>
      'Wiederherstellung aus der Sicherung...';

  @override
  String get settings_export_empty_dives => 'Keine Tauchgänge zum Exportieren';

  @override
  String get settings_export_empty_sites => 'Keine Tauchplätze zum Exportieren';

  @override
  String get settings_export_empty_equipment =>
      'Keine Ausrüstung zum Exportieren';

  @override
  String get settings_export_empty_data => 'Keine Daten zum Exportieren';

  @override
  String get settings_export_empty_diveSites =>
      'Keine Tauchplätze zum Exportieren';

  @override
  String settings_export_saveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String settings_export_backupFailed(String error) {
    return 'Sicherung fehlgeschlagen: $error';
  }

  @override
  String settings_export_restoreFailed(String error) {
    return 'Wiederherstellung fehlgeschlagen: $error';
  }

  @override
  String get settings_export_fileUnreadable =>
      'Auf die Datei konnte nicht zugegriffen werden';

  @override
  String get settings_export_notADbFile =>
      'Bitte wählen Sie eine .db-Sicherungsdatei aus';

  @override
  String get settings_export_success_dives =>
      'Tauchgänge erfolgreich exportiert';

  @override
  String get settings_export_success_sites =>
      'Tauchplätze erfolgreich exportiert';

  @override
  String get settings_export_success_equipment =>
      'Ausrüstung erfolgreich exportiert';

  @override
  String get settings_export_success_pdf => 'PDF-Logbuch erfolgreich erstellt';

  @override
  String get settings_export_success_uddf => 'UDDF-Datei erfolgreich erstellt';

  @override
  String get settings_export_success_excel =>
      'Excel-Datei erfolgreich exportiert';

  @override
  String settings_export_success_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'KML-Datei erfolgreich exportiert ($count Tauchplätze ohne Koordinaten übersprungen)',
      one:
          'KML-Datei erfolgreich exportiert (1 Tauchplatz ohne Koordinaten übersprungen)',
      zero: 'KML-Datei erfolgreich exportiert',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_excel =>
      'Excel-Datei erfolgreich gespeichert';

  @override
  String settings_export_saved_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'KML-Datei erfolgreich gespeichert ($count Tauchplätze ohne Koordinaten übersprungen)',
      one:
          'KML-Datei erfolgreich gespeichert (1 Tauchplatz ohne Koordinaten übersprungen)',
      zero: 'KML-Datei erfolgreich gespeichert',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_divesCsv =>
      'Tauchgänge-CSV erfolgreich gespeichert';

  @override
  String get settings_export_saved_sitesCsv =>
      'Tauchplätze-CSV erfolgreich gespeichert';

  @override
  String get settings_export_saved_equipmentCsv =>
      'Ausrüstungs-CSV erfolgreich gespeichert';

  @override
  String get settings_export_saved_uddf => 'UDDF-Datei erfolgreich gespeichert';

  @override
  String get settings_export_saved_pdf => 'PDF erfolgreich gespeichert';

  @override
  String get settings_export_saved_backup =>
      'Sicherung erfolgreich gespeichert';

  @override
  String get settings_export_restoreComplete =>
      'Wiederherstellung abgeschlossen';

  @override
  String get settings_export_cancelled_save => 'Speichern abgebrochen';

  @override
  String get settings_export_cancelled_backup => 'Sicherung abgebrochen';

  @override
  String get settings_export_cancelled_restore =>
      'Wiederherstellung abgebrochen';

  @override
  String get settings_export_pdfDocumentTitle => 'Tauchlogbuch';

  @override
  String get settings_export_saveBackupDialogTitle => 'Sicherung speichern';

  @override
  String backup_operation_created(String size) {
    return 'Sicherung erstellt: $size';
  }

  @override
  String backup_operation_backupFailed(String error) {
    return 'Sicherung fehlgeschlagen: $error';
  }

  @override
  String get backup_operation_restoring =>
      'Sicherung wird wiederhergestellt...';

  @override
  String backup_operation_restoreFailed(String error) {
    return 'Wiederherstellung fehlgeschlagen: $error';
  }

  @override
  String get backup_operation_deleting => 'Sicherung wird gelöscht...';

  @override
  String get backup_operation_deleted => 'Sicherung gelöscht';

  @override
  String backup_operation_deleteFailed(String error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String get backup_operation_exporting => 'Sicherung wird exportiert...';

  @override
  String backup_operation_exported(String size) {
    return 'Sicherung exportiert: $size';
  }

  @override
  String backup_operation_exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get backup_operation_preparingShare =>
      'Sicherung wird zum Teilen vorbereitet...';

  @override
  String get backup_operation_shareReady => 'Sicherung bereit zum Teilen';

  @override
  String backup_operation_upgrading(int step, int total) {
    return 'Datenbank wird aktualisiert (Schritt $step von $total)...';
  }

  @override
  String backup_restore_dialog_counts(int diveCount, int siteCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount Tauchgänge',
      one: '1 Tauchgang',
    );
    String _temp1 = intl.Intl.pluralLogic(
      siteCount,
      locale: localeName,
      other: '$siteCount Tauchplätze',
      one: '1 Tauchplatz',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get backup_restore_preMigration_title =>
      'Vor-Migrations-Backup wiederherstellen';

  @override
  String get backup_restore_preMigration_unknownVersion => 'unbekannte Version';

  @override
  String get backup_restore_preMigration_restoreAnyway =>
      'Trotzdem wiederherstellen';

  @override
  String backup_restore_preMigration_incompleteMetadata(
    String timestamp,
    String appVersion,
  ) {
    return 'Diese Sicherung wurde am $timestamp von App $appVersion erstellt, aber ihre Metadaten zur Datenbankmigration sind unvollständig.\n\nDie App kann nicht überprüfen, ob die Wiederherstellung dieser Sicherung sicher ist, daher ist die Wiederherstellung deaktiviert.';
  }

  @override
  String backup_restore_preMigration_newerApp(
    String timestamp,
    String appVersion,
    int fromVersion,
  ) {
    return 'Diese Sicherung ist neuer als Ihre App. Installieren Sie eine neuere App-Version, um sie wiederherzustellen.\n\nSicherung erstellt am $timestamp von App $appVersion (Datenbank v$fromVersion).';
  }

  @override
  String backup_restore_preMigration_safe(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
  ) {
    return 'Diese Sicherung wurde am $timestamp von App $appVersion erstellt, kurz vor der Aktualisierung der Datenbank von v$fromVersion auf v$toVersion.\n\nDas Datenbankschema Ihrer App stimmt mit dieser Sicherung überein, die Wiederherstellung ist daher sicher.';
  }

  @override
  String backup_restore_preMigration_warning(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
    int currentVersion,
  ) {
    return 'Diese Sicherung wurde am $timestamp von App $appVersion erstellt, kurz vor der Aktualisierung der Datenbank von v$fromVersion auf v$toVersion.\n\nSie verwenden eine neuere App (Datenbank v$currentVersion).\n\nEine Wiederherstellung führt die Datenbankaktualisierung von v$fromVersion auf v$toVersion erneut auf Ihren wiederhergestellten Daten aus, also genau die Aktualisierung, die ursprünglich anstand. Wenn diese Aktualisierung das Problem verursacht hat, tritt es erneut auf.\n\nSo stellen Sie sicher wieder her: Installieren Sie App $appVersion oder älter und stellen Sie diese Sicherung aus dieser älteren App wieder her.';
  }

  @override
  String get settings_cloudSync_progress_preparing =>
      'Synchronisierung wird vorbereitet...';

  @override
  String get settings_cloudSync_progress_pulling =>
      'Änderungen werden abgerufen...';

  @override
  String get settings_cloudSync_progress_publishing =>
      'Änderungen werden veröffentlicht...';

  @override
  String settings_cloudSync_progress_uploadingLibrary(int uploaded, int total) {
    return 'Bibliothek wird hochgeladen ($uploaded von $total)';
  }

  @override
  String get settings_cloudSync_result_noProvider =>
      'Kein Cloud-Anbieter konfiguriert';

  @override
  String get settings_cloudSync_result_notAuthenticated =>
      'Nicht beim Cloud-Anbieter authentifiziert';

  @override
  String get settings_cloudSync_result_timedOut =>
      'Zeitüberschreitung bei der Synchronisierung';

  @override
  String get settings_cloudSync_result_epochMarkerUnreadable =>
      'Der Epochenmarker der Bibliothek konnte nicht gelesen werden';

  @override
  String get settings_cloudSync_result_epochMarkerEncrypted =>
      'Der Epochenmarker der Bibliothek ist verschlüsselt';

  @override
  String get settings_cloudSync_result_libraryReplacedRemotely =>
      'Die Cloud-Bibliothek wurde aus einer Sicherung ersetzt';

  @override
  String get settings_cloudSync_result_noReplacementToRebuild =>
      'Kein Bibliotheksersatz vorhanden, aus dem neu aufgebaut werden könnte';

  @override
  String get settings_cloudSync_result_rebuiltFromThisDevice =>
      'Dieses Backend wurde aus der Bibliothek dieses Geräts neu aufgebaut';

  @override
  String settings_cloudSync_result_rebuildFailed(String error) {
    return 'Neuaufbau fehlgeschlagen: $error';
  }

  @override
  String get settings_cloudSync_result_libraryReplaced => 'Bibliothek ersetzt';

  @override
  String settings_cloudSync_result_libraryReplaceFailed(String error) {
    return 'Ersetzen der Bibliothek fehlgeschlagen: $error';
  }

  @override
  String get settings_cloudSync_result_noReplacementMarker =>
      'Kein Marker für einen Bibliotheksersatz gefunden';

  @override
  String get settings_cloudSync_result_adoptedRestoredLibrary =>
      'Wiederhergestellte Bibliothek übernommen';

  @override
  String settings_cloudSync_result_adoptFailed(String error) {
    return 'Wiederhergestellte Bibliothek konnte nicht übernommen werden: $error';
  }

  @override
  String get settings_cloudSync_result_previousLibraryUnreadable =>
      'Die vorherige Bibliothek konnte nicht gelesen werden; dieses Backend wurde aus der Bibliothek dieses Geräts neu eingerichtet.';

  @override
  String get settings_cloudSync_result_replacementStillUploading =>
      'Die ersetzte Bibliothek wird noch hochgeladen. Versuchen Sie es in Kürze erneut.';

  @override
  String settings_cloudSync_result_recordsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Datensätze konnten nicht angewendet werden',
      one: '1 Datensatz konnte nicht angewendet werden',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_result_adoptedFreshIdentity =>
      'Ein anderes Gerät hat mit der Identität dieses Geräts synchronisiert. Dieses Gerät hat eine neue Identität übernommen und die Cloud-Daten zusammengeführt.';

  @override
  String settings_cloudSync_launchCheck_unavailable(String provider) {
    return '$provider ist auf diesem Gerät nicht verfügbar';
  }

  @override
  String settings_cloudSync_launchCheck_notSignedIn(String provider) {
    return 'Nicht bei $provider angemeldet';
  }

  @override
  String settings_cloudSync_launchCheck_localChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lokale Änderungen zum Hochladen',
      one: '1 lokale Änderung zum Hochladen',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_launchCheck_noRemoteData =>
      'Keine Synchronisierungsdaten in der Cloud gefunden';

  @override
  String get settings_cloudSync_launchCheck_cloudDataAvailable =>
      'Cloud-Daten verfügbar';

  @override
  String get settings_cloudSync_launchCheck_updatesAvailable =>
      'Aktualisierungen aus der Cloud verfügbar';

  @override
  String get settings_cloudSync_launchCheck_upToDate =>
      'Alles ist auf dem neuesten Stand';

  @override
  String settings_cloudSync_launchCheck_failed(String error) {
    return 'Synchronisierungsprüfung fehlgeschlagen: $error';
  }

  @override
  String get diveLog_detail_viewMap => 'Karte';

  @override
  String get diveLog_detail_view3d => '3D';

  @override
  String get setup_sync_icloudUnavailable =>
      'iCloud ist auf diesem Gerät nicht verfügbar';

  @override
  String get media_info_title => 'Medieninfo';

  @override
  String get media_info_fileSection => 'Datei';

  @override
  String get media_info_filename => 'Dateiname';

  @override
  String get media_info_type => 'Typ';

  @override
  String get media_info_dimensions => 'Abmessungen';

  @override
  String get media_info_size => 'Größe';

  @override
  String get media_info_taken => 'Aufgenommen';

  @override
  String get media_info_coordinates => 'Koordinaten';

  @override
  String get media_info_unknown => 'Unbekannt';

  @override
  String get media_info_originSection => 'Herkunft';

  @override
  String get media_info_source => 'Quelle';

  @override
  String get media_info_reference => 'Referenz';

  @override
  String get media_info_linkedOn => 'Verknüpft auf';

  @override
  String get media_info_thisDevice => 'Dieses Gerät';

  @override
  String get media_info_otherDevice => 'Ein anderes Gerät';

  @override
  String get media_info_status => 'Status';

  @override
  String get media_info_statusFound => 'Auf diesem Gerät gefunden';

  @override
  String get media_info_statusMissing => 'Auf diesem Gerät nicht vorhanden';

  @override
  String get media_info_statusUnchecked => 'Noch nicht geprüft';

  @override
  String media_info_lastChecked(String date) {
    return 'Zuletzt geprüft $date';
  }

  @override
  String get media_timeInDive_label => 'Zeitpunkt im Tauchgang';

  @override
  String get media_timeInDive_unknown => 'Zeitpunkt im Tauchgang unbekannt';

  @override
  String get media_timeInDive_setAction => 'Zeitpunkt im Tauchgang festlegen';

  @override
  String media_timeInDive_manual(String time) {
    return '$time (manuell festgelegt)';
  }

  @override
  String get media_timeInDive_fieldLabel => 'Zeit seit Tauchgangsbeginn';

  @override
  String get media_timeInDive_fieldHint => 'mm:ss';

  @override
  String media_timeInDive_range(String max) {
    return 'Zwischen 0:00 und $max';
  }

  @override
  String media_timeInDive_invalid(String max) {
    return 'Gib eine Zeit zwischen 0:00 und $max ein';
  }

  @override
  String get media_timeInDive_save => 'Speichern';

  @override
  String get media_timeInDive_cancel => 'Abbrechen';

  @override
  String get media_timeInDive_reset => 'Auf automatisch zurücksetzen';

  @override
  String get media_info_backupSection => 'Sicherung';

  @override
  String get media_info_store => 'Cloud-Speicher';

  @override
  String get media_info_storeNotConnected => 'Kein Cloud-Speicher verbunden';

  @override
  String get media_info_notEligible =>
      'Diese Quelle kann nicht gesichert werden';

  @override
  String get media_info_backupFull => 'Original hochgeladen';

  @override
  String get media_info_backupThumbOnly =>
      'Nur Miniaturbild, Original nicht gesendet';

  @override
  String get media_info_backupRenditionOnly =>
      'Komprimierte Version hochgeladen';

  @override
  String get media_info_backupNone => 'Nicht gesichert';

  @override
  String media_info_uploadedOn(String date) {
    return 'Hochgeladen $date';
  }

  @override
  String get media_info_queuePending => 'Warten auf Upload';

  @override
  String get media_info_queueTransferring => 'Wird hochgeladen';

  @override
  String media_info_queueFailed(Object error) {
    return 'Upload fehlgeschlagen: $error';
  }

  @override
  String get media_info_servingSection => 'Wird geliefert von';

  @override
  String get media_info_servingUnobserved => 'Noch nicht geladen';

  @override
  String get media_info_servingFailed => 'Konnte nicht geladen werden';

  @override
  String get media_info_servedLocalDisk => 'Lokale Datei auf diesem Gerät';

  @override
  String get media_info_servedGallery => 'Fotomediathek';

  @override
  String get media_info_servedStoreCache =>
      'Lokaler Cache, aus dem Cloud-Speicher';

  @override
  String get media_info_servedStoreNetwork =>
      'Aus dem Cloud-Speicher heruntergeladen';

  @override
  String get media_info_servedNetworkUrl => 'Streaming von einer URL';

  @override
  String get media_info_servedConnectorCache =>
      'Lokaler Cache, vom verbundenen Dienst';

  @override
  String get media_info_servedConnectorNetwork =>
      'Vom verbundenen Dienst heruntergeladen';

  @override
  String get media_info_servedEmbedded => 'In diesem Logbuch gespeichert';

  @override
  String get media_info_servingFallbackNote =>
      'Die ursprüngliche Quelle war nicht erreichbar, daher kam dies aus dem Cloud-Speicher.';

  @override
  String get media_info_servingTierThumbnail => 'Miniaturbild';

  @override
  String get media_info_servingTierRendition => 'Komprimierte Version';

  @override
  String get media_info_typePhoto => 'Foto';

  @override
  String get media_info_typeVideo => 'Video';

  @override
  String get media_info_typeDocument => 'Dokument';

  @override
  String get media_info_typeSignature => 'Unterschrift';

  @override
  String get media_info_actionCheckNow => 'Jetzt prüfen';

  @override
  String get media_info_actionLocate => 'Datei suchen...';

  @override
  String get media_info_actionBackUpNow => 'Jetzt sichern';

  @override
  String get media_info_actionRetryUpload => 'Upload wiederholen';

  @override
  String get media_info_actionReveal => 'Im Dateimanager anzeigen';

  @override
  String get media_info_actionCopyPath => 'Referenz kopieren';

  @override
  String get media_info_referenceCopied => 'Referenz kopiert';

  @override
  String get media_info_checkFound => 'Quelle gefunden';

  @override
  String get media_info_checkMissing => 'Quelle fehlt';

  @override
  String get media_info_checkUnavailable => 'Prüfung derzeit nicht möglich';

  @override
  String get media_info_backupQueued => 'Zum Upload eingereiht';

  @override
  String get enum_profileMetric_o2CellMv => 'O2-Zellen';

  @override
  String get enum_profileMetric_o2CellMv_short => 'Zellen';

  @override
  String get diveLog_o2CellSpread_label => 'O2-Zellenstreuung';

  @override
  String get media_status_broken => 'Fehlt und nicht gesichert';

  @override
  String get media_servedFrom_localDisk => 'Auf diesem Gerät';

  @override
  String get media_servedFrom_platformGallery => 'Fotomediathek';

  @override
  String get media_servedFrom_storeCache =>
      'Cloud-Speicher, hier zwischengespeichert';

  @override
  String get media_servedFrom_storeNetwork => 'Cloud-Speicher';

  @override
  String get media_servedFrom_networkUrl => 'Weblink';

  @override
  String get media_servedFrom_connectorCache =>
      'Verbundener Dienst, hier zwischengespeichert';

  @override
  String get media_servedFrom_connectorNetwork => 'Verbundener Dienst';

  @override
  String get media_servedFrom_embedded => 'In diesem Logbuch gespeichert';

  @override
  String get settings_media_provenanceBadges =>
      'Quellen-Badges auf Miniaturen anzeigen';

  @override
  String get settings_media_provenanceBadgesSubtitle =>
      'Ein kleines Symbol, das zeigt, woher jedes Element geladen wird. Problem-Badges werden immer angezeigt.';

  @override
  String get media_status_transferFailed => 'Upload fehlgeschlagen';

  @override
  String get media_status_transferring => 'Wird hochgeladen';

  @override
  String get media_status_queued => 'Warten auf Upload';

  @override
  String get media_status_cloudOnly => 'Nur in der Cloud gespeichert';

  @override
  String get media_status_notBackedUp => 'Nicht gesichert';

  @override
  String get media_tile_infoMenuItem => 'Medieninfo';

  @override
  String get diveImport_healthkit_accessGrantedHint =>
      'Apple Health teilt Apps nie mit, ob Lesezugriff gewährt wurde. Falls keine Tauchgänge erscheinen, öffne Health, dann Teilen, Apps, Submersion, und aktiviere Workouts, Unterwassertiefe, Wassertemperatur und Herzfrequenz.';

  @override
  String get diveImport_healthkit_foundNoDivesHint =>
      'Keine Tauch-Workouts in diesem Zeitraum. Prüfe, ob die Daten den Tauchgang abdecken und ob unter Health, Teilen, Apps, Submersion die Optionen Workouts und Unterwassertiefe aktiviert sind.';

  @override
  String get settings_dataSources_appleHealth_dataTypeDepth =>
      'Unterwassertiefe - während Tauchgängen aufgezeichnete Tiefenwerte';

  @override
  String get settings_dataSources_appleHealth_dataTypeWaterTemp =>
      'Wassertemperatur - während Tauchgängen aufgezeichnete Temperaturwerte';

  @override
  String get settings_dataSources_appleHealth_permissionManagedInHealth =>
      'Der HealthKit-Zugriff wird in der Health-App verwaltet';

  @override
  String get settings_dataSources_appleHealth_permissionUnsupported =>
      'HealthKit ist auf diesem Gerät nicht verfügbar';
}
