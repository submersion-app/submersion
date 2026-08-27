// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get universalImport_action_importFromGarmin =>
      'Importeren vanaf Garmin-apparaat';

  @override
  String diveLog_edit_flightWindowWarning(String time) {
    return 'Deze duik eindigt na het laatste veilige opstijgmoment voor je vlucht ($time)';
  }

  @override
  String diveLog_edit_geofenceSuggestion_near(String location) {
    return 'Bij $location';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_title => 'Uitrustingssuggestie';

  @override
  String diveLog_edit_geofenceSuggestion_body(String setName) {
    return 'Set \"$setName\" toepassen?';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_apply => 'Toepassen';

  @override
  String get common_action_dismiss => 'Sluiten';

  @override
  String get equipment_setEdit_defaultSwitch_title => 'Standaardset';

  @override
  String get equipment_setEdit_defaultSwitch_subtitle =>
      'Automatisch toegepast op nieuwe duiken zonder uitrusting';

  @override
  String get equipment_setEdit_geofencesTitle => 'Geofences';

  @override
  String get equipment_setEdit_geofencesSubtitle =>
      'Deze set automatisch voorstellen voor duiken bij deze locaties';

  @override
  String get equipment_setEdit_addGeofence => 'Geofence toevoegen';

  @override
  String get equipment_setEdit_editGeofence => 'Edit geofence';

  @override
  String get equipment_setEdit_removeGeofence => 'Remove geofence';

  @override
  String equipment_setEdit_geofenceRadius(String distance) {
    return 'Straal: $distance';
  }

  @override
  String get equipment_geofenceEditor_title => 'Geofence';

  @override
  String get equipment_geofenceEditor_fromSite => 'Van duikstek';

  @override
  String get equipment_geofenceEditor_dropPin => 'Speld plaatsen';

  @override
  String get equipment_geofenceEditor_labelLabel => 'Label';

  @override
  String get equipment_geofenceEditor_noCenter => 'Kies een middelpunt';

  @override
  String get equipment_geofenceEditor_save => 'Geofence opslaan';

  @override
  String get equipment_sets_defaultBadge => 'Standaard';

  @override
  String get equipment_setDetail_setAsDefault => 'Als standaard instellen';

  @override
  String equipment_setDetail_setAsDefaultSnackbar(String name) {
    return '\"$name\" is nu je standaardset';
  }

  @override
  String get equipment_setDetail_geofencesTitle => 'Geofences';

  @override
  String get equipment_setDetail_noGeofences => 'Geen geofences';

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
    return 'Boven de harde dichtheidsgrens van $limit g/L.';
  }

  @override
  String get gasCalculators_bestMix_densityLabel => 'Gasdichtheid op diepte';

  @override
  String gasCalculators_bestMix_densityWarn(Object limit) {
    return 'Boven de aanbevolen dichtheidsgrens van $limit g/L.';
  }

  @override
  String gasCalculators_bestMix_endExceeded(Object limit) {
    return 'END overschrijdt je limiet van $limit.';
  }

  @override
  String get gasCalculators_bestMix_endLabel => 'END op diepte';

  @override
  String get gasCalculators_bestMix_endLimitLabel => 'END-limiet';

  @override
  String gasCalculators_bestMix_heliumAdded(Object limit) {
    return 'Helium toegevoegd om END binnen je limiet van $limit te houden.';
  }

  @override
  String get gasCalculators_bestMix_idealLabel => 'Ideale fractie';

  @override
  String get gasCalculators_bestMix_marginLabel => 'Marge onder MOD';

  @override
  String gasCalculators_bestMix_modLabel(Object ppO2) {
    return 'MOD bij ppO2 $ppO2';
  }

  @override
  String get gasCalculators_bestMix_nearestStandard =>
      'Dichtstbijzijnde standaardmengsel voor deze diepte';

  @override
  String get gasCalculators_bestMix_recommendedMix => 'Aanbevolen mengsel';

  @override
  String get gasCalculators_bestMix_withoutHelium => 'Zonder helium';

  @override
  String get gasCalculators_planningCaveat =>
      'Planningsschatting. Gaat uit van een directe opstijging. Toets aan je opleiding en neem marge voor de omstandigheden.';

  @override
  String gasCalculators_rockBottom_solveGas(Object depth, Object unit) {
    return 'Gas voor probleemoplossing op $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_solveTime =>
      'Tijd voor probleemoplossing';

  @override
  String get gasCalculators_rockBottom_solveTimeHint =>
      'Tijd op diepte om het noodgeval op te lossen voordat de opstijging begint.';

  @override
  String o2Toxicity_addedThisDive(Object value) {
    return '+$value deze duik';
  }

  @override
  String o2Toxicity_cnsProgressSemantics(Object percent) {
    return 'CZS-voortgang $percent procent';
  }

  @override
  String get o2Toxicity_daily => 'Dagelijks';

  @override
  String o2Toxicity_otuSemantics(
    Object label,
    Object value,
    Object limit,
    Object percent,
  ) {
    return '$label: $value van $limit OTU, $percent procent';
  }

  @override
  String o2Toxicity_otuValueSemantics(Object label, Object value) {
    return '$label: $value OTU';
  }

  @override
  String o2Toxicity_prior(Object value) {
    return 'Eerder: $value OTU';
  }

  @override
  String o2Toxicity_start(Object value) {
    return 'Start: $value OTU';
  }

  @override
  String get o2Toxicity_thisDive => 'Deze duik';

  @override
  String get o2Toxicity_weekly => 'Wekelijks';

  @override
  String trips_story_dayLabel(int number) {
    return 'Dag $number';
  }

  @override
  String get trips_story_surfaceDay => 'Oppervlaktedag';

  @override
  String get trips_story_today => 'Vandaag';

  @override
  String trips_story_dayOfTrip(int current, int total) {
    return 'Dag $current van $total';
  }

  @override
  String trips_story_daysUntil(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Nog $days dagen tot vertrek',
      one: 'Nog 1 dag tot vertrek',
    );
    return '$_temp0';
  }

  @override
  String trips_story_checklistProgress(int done, int total) {
    return '$done van $total klaar';
  }

  @override
  String get trips_story_generateItinerary => 'Reisplan genereren';

  @override
  String get trips_story_openGallery => 'Reisfoto\'s openen';

  @override
  String trips_story_generateItineraryError(String error) {
    return 'Kan reisschema niet genereren: $error';
  }

  @override
  String get trips_dayType_diveDay => 'Duikdag';

  @override
  String get trips_dayType_seaDay => 'Zeedag';

  @override
  String get trips_dayType_portDay => 'Havendag';

  @override
  String get trips_dayType_embark => 'Inschepen';

  @override
  String get trips_dayType_disembark => 'Ontschepen';

  @override
  String get trips_story_planned => 'Gepland';

  @override
  String get trips_story_empty_title => 'Nog geen duiken of reisplan';

  @override
  String get trips_story_empty_subtitle =>
      'Voeg duiken toe of plan de dagen om het verhaal te zien.';

  @override
  String trips_story_history_dives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eerdere duiken hier',
      one: '1 eerdere duik hier',
    );
    return '$_temp0';
  }

  @override
  String trips_story_history_avgTemp(String value) {
    return 'gem. $value';
  }

  @override
  String trips_story_history_avgDepth(String value) {
    return 'gem. diepte $value';
  }

  @override
  String get trips_story_rhythm_semantics => 'Duiktijden van deze dag';

  @override
  String get trips_story_map_semantics =>
      'Reiskaart. De stekken van de zichtbare dag zijn gemarkeerd.';

  @override
  String get diveLog_bulkEdit_groupRebreather => 'Duikmodus & rebreather';

  @override
  String get diveLog_bulkEdit_fieldSetpointLow => 'Setpoint laag';

  @override
  String get diveLog_bulkEdit_fieldSetpointHigh => 'Setpoint hoog';

  @override
  String get diveLog_bulkEdit_fieldSetpointDeco => 'Setpoint deco';

  @override
  String get diveLog_bulkEdit_fieldScrubberType => 'Scrubbertype';

  @override
  String get diveLog_bulkEdit_fieldScrubberDuration => 'Scrubberduur';

  @override
  String get diveLog_bulkEdit_contradiction =>
      'OC-modus kan geen rebreather-instellingen hebben. Schakel die velden uit of wijzig de modus.';

  @override
  String diveLog_bulkEdit_appBarTitle(int count) {
    return '$count duiken bewerken';
  }

  @override
  String get diveLog_bulkEdit_groupLogistics => 'Logistiek';

  @override
  String get diveLog_bulkEdit_groupWeather => 'Weer';

  @override
  String get diveLog_bulkEdit_groupCollections => 'Tags, uitrusting & leven';

  @override
  String get diveLog_bulkEdit_fieldFavorite => 'Favoriet';

  @override
  String get diveLog_bulkEdit_fieldMyRole => 'Mijn rol';

  @override
  String get diveLog_bulkEdit_buddyRoleMixed => 'Gemengd';

  @override
  String get diveLog_bulkEdit_collectionWeights => 'Loodgewichten';

  @override
  String get diveLog_bulkEdit_collectionTanks => 'Flessen';

  @override
  String get diveLog_bulkEdit_notesSet => 'Instellen';

  @override
  String get diveLog_bulkEdit_notesAppend => 'Toevoegen aan einde';

  @override
  String get diveLog_bulkEdit_modeAdd => 'Toevoegen';

  @override
  String get diveLog_bulkEdit_modeRemove => 'Verwijderen';

  @override
  String get diveLog_bulkEdit_modeReplace => 'Vervangen';

  @override
  String get diveLog_bulkEdit_modeUpdate => 'Bijwerken';

  @override
  String get diveLog_bulkEdit_tankOnlyIfEmpty =>
      'Alleen duiken zonder bestaande fles';

  @override
  String get diveLog_bulkEdit_tankSpecsHint =>
      'Kies welke eigenschappen worden overschreven op de flessen die deze duiken al hebben. Begin- en einddruk worden nooit gewijzigd.';

  @override
  String get diveLog_bulkEdit_tankSpecsNoFields =>
      'Kies minstens één fleseigenschap om bij te werken.';

  @override
  String get diveLog_bulkEdit_tankFieldPreset => 'Voorinstelling';

  @override
  String get diveLog_bulkEdit_tankFieldRole => 'Rol';

  @override
  String get diveLog_bulkEdit_tankFieldVolume => 'Volume';

  @override
  String get diveLog_bulkEdit_tankFieldWorkingPressure => 'Werkdruk';

  @override
  String get diveLog_bulkEdit_tankFieldMaterial => 'Materiaal';

  @override
  String get diveLog_bulkEdit_tankFieldGasMix => 'Gasmengsel';

  @override
  String get diveLog_bulkEdit_tankFieldName => 'Naam';

  @override
  String diveLog_bulkEdit_tankSpecsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count geselecteerde duiken hebben geen flessen en worden overgeslagen.',
      one: '1 geselecteerde duik heeft geen flessen en wordt overgeslagen.',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_bulkEdit_confirmTitle => 'Wijzigingen toepassen?';

  @override
  String get diveLog_bulkEdit_confirmApply => 'Toepassen';

  @override
  String get diveLog_bulkEdit_nothingSelected =>
      'Schakel minstens één veld in om wijzigingen toe te passen.';

  @override
  String diveLog_bulkEdit_applied(int count) {
    return '$count duiken bijgewerkt';
  }

  @override
  String get settings_cloudSync_error_icloudSignedOut =>
      'iCloud is niet beschikbaar. Log in bij iCloud in de instellingen van je apparaat.';

  @override
  String get settings_cloudSync_error_icloudUnknown =>
      'Kan iCloud niet bereiken. Probeer het opnieuw.';

  @override
  String get settings_cloudSync_error_icloudUnsupported =>
      'iCloud-synchronisatie is niet beschikbaar in deze build van Submersion. Gebruik S3-synchronisatie of de App Store-versie.';

  @override
  String get settings_cloudSync_provider_icloud_unsupportedSubtitle =>
      'Niet beschikbaar in deze build — gebruik S3 of de App Store-versie';

  @override
  String get settings_cloudSync_encryption_title => 'End-to-end-versleuteling';

  @override
  String get settings_cloudSync_encryption_subtitleOff =>
      'Versleutel alle synchronisatiegegevens en cloudback-ups vóór het uploaden';

  @override
  String get settings_cloudSync_encryption_subtitleNeedsProvider =>
      'Selecteer eerst een cloudprovider';

  @override
  String get settings_cloudSync_encryption_statusOff =>
      'Versleuteling staat uit';

  @override
  String get settings_cloudSync_encryption_statusOn =>
      'Versleuteling staat aan';

  @override
  String get settings_cloudSync_encryption_statusOnSubtitle =>
      'Synchronisatiegegevens en cloudback-ups worden vóór het uploaden versleuteld';

  @override
  String get settings_cloudSync_encryption_statusLocked =>
      'Versleuteld — wachtwoordzin vereist';

  @override
  String get settings_cloudSync_encryption_statusLockedSubtitle =>
      'Voer de wachtwoordzin in om op dit apparaat te synchroniseren';

  @override
  String get settings_cloudSync_encryption_enable =>
      'Versleuteling inschakelen';

  @override
  String get settings_cloudSync_encryption_enterPassphrase =>
      'Wachtwoordzin invoeren';

  @override
  String get settings_cloudSync_encryption_passphrase => 'Wachtwoordzin';

  @override
  String get settings_cloudSync_encryption_passphraseConfirm =>
      'Wachtwoordzin bevestigen';

  @override
  String get settings_cloudSync_encryption_passphraseMismatch =>
      'Wachtwoordzinnen komen niet overeen';

  @override
  String get settings_cloudSync_encryption_passphraseTooShort =>
      'Gebruik minstens 8 tekens';

  @override
  String get settings_cloudSync_encryption_wrongPassphrase =>
      'Onjuiste wachtwoordzin of herstelcode';

  @override
  String get settings_cloudSync_encryption_warnUpdateDevices =>
      'Alle andere apparaten moeten naar de nieuwste appversie worden bijgewerkt en downloaden de bibliotheek opnieuw.';

  @override
  String get settings_cloudSync_encryption_warnLoss =>
      'Als u zowel de wachtwoordzin als de herstelcode verliest, zijn de gegevens in de cloud niet te herstellen. De gegevens op uw apparaten lopen nooit gevaar.';

  @override
  String get settings_cloudSync_encryption_deletePlaintextBackups =>
      'Bestaande onversleutelde cloudback-ups verwijderen';

  @override
  String get settings_cloudSync_encryption_recoveryTitle => 'Herstelcode';

  @override
  String get settings_cloudSync_encryption_recoveryExplain =>
      'Noteer deze code en bewaar hem veilig. Het is de enige weg terug als u de wachtwoordzin vergeet.';

  @override
  String get settings_cloudSync_encryption_recoverySavedConfirm =>
      'Ik heb mijn herstelcode opgeslagen';

  @override
  String get settings_cloudSync_encryption_changePassphrase =>
      'Wachtwoordzin wijzigen';

  @override
  String get settings_cloudSync_encryption_currentPassphrase =>
      'Huidige wachtwoordzin';

  @override
  String get settings_cloudSync_encryption_newPassphrase =>
      'Nieuwe wachtwoordzin';

  @override
  String get settings_cloudSync_encryption_regenerateRecovery =>
      'Nieuwe herstelcode genereren';

  @override
  String get settings_cloudSync_encryption_regenerateRecoveryWarn =>
      'De oude herstelcode werkt direct niet meer.';

  @override
  String get settings_cloudSync_encryption_disable =>
      'Versleuteling uitschakelen';

  @override
  String get settings_cloudSync_encryption_disableWarn =>
      'De bibliotheek wordt onversleuteld opnieuw geüpload en andere apparaten downloaden hem opnieuw. Bestaande versleutelde back-ups blijven met de wachtwoordzin te herstellen.';

  @override
  String get settings_cloudSync_encryption_unlockTitle =>
      'Voer uw versleutelings-wachtwoordzin in';

  @override
  String get settings_cloudSync_encryption_unlockHint =>
      'Wachtwoordzin of herstelcode';

  @override
  String get settings_cloudSync_encryption_unlock => 'Ontgrendelen';

  @override
  String get settings_cloudSync_encryption_continue => 'Doorgaan';

  @override
  String get settings_cloudSync_encryption_done => 'Klaar';

  @override
  String get settings_cloudSync_encryption_cancel => 'Annuleren';

  @override
  String get settings_backupEncryption_title => 'Back-upversleuteling';

  @override
  String get settings_backupEncryption_subtitleOff =>
      'Bescherm uw back-ups met een wachtwoord';

  @override
  String get settings_backupEncryption_subtitleOn =>
      'Back-ups worden versleuteld met uw wachtwoord';

  @override
  String get settings_backupEncryption_enable => 'Back-ups versleutelen';

  @override
  String get settings_backupEncryption_turnOff => 'Versleuteling uitschakelen';

  @override
  String get settings_backupEncryption_turnOffTitle =>
      'Back-upversleuteling uitschakelen?';

  @override
  String get settings_backupEncryption_turnOffBody =>
      'Nieuwe back-ups worden niet meer versleuteld. Bestaande versleutelde back-ups hebben nog steeds uw wachtwoord nodig om te herstellen.';

  @override
  String get settings_backupEncryption_changePassword => 'Wachtwoord wijzigen';

  @override
  String get settings_backupEncryption_regenerateRecovery =>
      'Nieuwe herstelcode genereren';

  @override
  String get settings_backupEncryption_password => 'Wachtwoord';

  @override
  String get settings_backupEncryption_passwordConfirm =>
      'Wachtwoord bevestigen';

  @override
  String get settings_backupEncryption_passwordTooShort =>
      'Gebruik minstens 8 tekens';

  @override
  String get settings_backupEncryption_passwordMismatch =>
      'Wachtwoorden komen niet overeen';

  @override
  String get settings_backupEncryption_currentPassword => 'Huidig wachtwoord';

  @override
  String get settings_backupEncryption_newPassword => 'Nieuw wachtwoord';

  @override
  String get settings_backupEncryption_changePasswordWarn =>
      'Op een ander apparaat wordt elke back-up geopend met het wachtwoord of de herstelcode die actief was toen deze werd gemaakt.';

  @override
  String get settings_backupEncryption_warnLoss =>
      'Als u uw wachtwoord vergeet en de herstelcode verliest, kunnen versleutelde back-ups niet worden hersteld.';

  @override
  String get settings_backupEncryption_recoveryTitle => 'Uw herstelcode';

  @override
  String get settings_backupEncryption_recoveryExplain =>
      'Bewaar deze code op een veilige plek. Hij kan uw back-ups ontgrendelen als u uw wachtwoord vergeet.';

  @override
  String get settings_backupEncryption_recoverySavedConfirm =>
      'Ik heb mijn herstelcode opgeslagen';

  @override
  String get settings_backupEncryption_unlockTitle =>
      'Voer uw back-upwachtwoord in';

  @override
  String get settings_backupEncryption_unlockHint =>
      'Voer uw back-upwachtwoord of herstelcode in';

  @override
  String get settings_backupEncryption_restoreUnlockTitle =>
      'Versleutelde back-up ontgrendelen';

  @override
  String get settings_backupEncryption_restoreUnlockHint =>
      'Voer het wachtwoord of de herstelcode voor deze back-up in';

  @override
  String get settings_backupEncryption_continue => 'Doorgaan';

  @override
  String get settings_backupEncryption_cancel => 'Annuleren';

  @override
  String get settings_backupEncryption_done => 'Klaar';

  @override
  String get settings_backupEncryption_reencryptTitle =>
      'Bestaande back-ups versleutelen?';

  @override
  String get settings_backupEncryption_reencryptBody =>
      'Uw bestaande back-ups zijn nog onversleuteld. Wilt u ze nu opnieuw versleutelen met uw nieuwe wachtwoord?';

  @override
  String get settings_backupEncryption_reencryptNow =>
      'Nu opnieuw versleutelen';

  @override
  String get settings_backupEncryption_reencryptNotNow => 'Niet nu';

  @override
  String settings_backupEncryption_reencryptPartial(int done, int failed) {
    return '$done back-ups opnieuw versleuteld; $failed konden niet worden versleuteld en zijn nog onbeschermd';
  }

  @override
  String settings_backupEncryption_reencryptDone(int count) {
    return '$count back-ups opnieuw versleuteld';
  }

  @override
  String get settings_backupEncryption_wrongPassword =>
      'Onjuist wachtwoord of herstelcode';

  @override
  String settings_cloudSync_replace_globalBanner(String deviceName) {
    return 'Synchronisatie onderbroken — de bibliotheek is vervangen vanaf een back-up op \"$deviceName\".';
  }

  @override
  String get settings_cloudSync_postRestore_syncing =>
      'Je herstelde bibliotheek wordt met de cloud gesynchroniseerd…';

  @override
  String get settings_cloudSync_postRestore_synced =>
      'Herstelde bibliotheek gesynchroniseerd.';

  @override
  String get settings_cloudSync_replace_reviewAction => 'Controleren';

  @override
  String get accessibility_dialog_keyboardShortcutsTitle => 'Sneltoetsen';

  @override
  String get accessibility_keyLabel_backspace => 'Backspace';

  @override
  String get accessibility_keyLabel_delete => 'Delete';

  @override
  String get accessibility_keyLabel_down => 'Omlaag';

  @override
  String get accessibility_keyLabel_enter => 'Enter';

  @override
  String get accessibility_keyLabel_esc => 'Esc';

  @override
  String get accessibility_keyLabel_left => 'Links';

  @override
  String get accessibility_keyLabel_right => 'Rechts';

  @override
  String get accessibility_keyLabel_up => 'Omhoog';

  @override
  String accessibility_label_chartSummary(
    Object chartType,
    Object description,
  ) {
    return '$chartType grafiek. $description';
  }

  @override
  String get accessibility_label_createNewItem => 'Nieuw item aanmaken';

  @override
  String get accessibility_label_hideList => 'Lijst verbergen';

  @override
  String get accessibility_label_hideMapView => 'Kaartweergave verbergen';

  @override
  String accessibility_label_listPane(Object title) {
    return '$title lijstpaneel';
  }

  @override
  String accessibility_label_mapPane(Object title) {
    return '$title kaartpaneel';
  }

  @override
  String accessibility_label_mapViewTitle(Object title) {
    return '$title kaartweergave';
  }

  @override
  String get accessibility_label_resizeMasterPane =>
      'Hoofdvenster formaat aanpassen';

  @override
  String get accessibility_label_sharedWithAllProfiles =>
      'Gedeeld met alle duikersprofielen';

  @override
  String get accessibility_label_showList => 'Lijst tonen';

  @override
  String get accessibility_label_showMapView => 'Kaartweergave tonen';

  @override
  String get accessibility_label_viewDetails => 'Details bekijken';

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
  String get accessibility_shortcutCategory_editing => 'Bewerken';

  @override
  String get accessibility_shortcutCategory_general => 'Algemeen';

  @override
  String get accessibility_shortcutCategory_help => 'Help';

  @override
  String get accessibility_shortcutCategory_navigation => 'Navigatie';

  @override
  String get accessibility_shortcutCategory_search => 'Zoeken';

  @override
  String get accessibility_shortcut_closeCancel => 'Sluiten / Annuleren';

  @override
  String get accessibility_shortcut_goBack => 'Ga terug';

  @override
  String get accessibility_shortcut_goToDives => 'Ga naar Duiken';

  @override
  String get accessibility_shortcut_goToEquipment => 'Ga naar Uitrusting';

  @override
  String get accessibility_shortcut_goToSettings => 'Ga naar Instellingen';

  @override
  String get accessibility_shortcut_goToSites => 'Ga naar Duikstekken';

  @override
  String get accessibility_shortcut_goToStatistics => 'Ga naar Statistieken';

  @override
  String get accessibility_shortcut_keyboardShortcuts => 'Sneltoetsen';

  @override
  String get accessibility_shortcut_newDive => 'Nieuwe duik';

  @override
  String get accessibility_shortcut_openSettings => 'Instellingen openen';

  @override
  String get accessibility_shortcut_searchDives => 'Duiken zoeken';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return 'Sorteren op $displayName, momenteel geselecteerd';
  }

  @override
  String accessibility_sort_unselectedLabel(Object displayName) {
    return 'Sorteren op $displayName';
  }

  @override
  String get backup_appBar_title => 'Back-up en Herstel';

  @override
  String get backup_backingUp => 'Back-up maken...';

  @override
  String get backup_backupNow => 'Nu Back-up Maken';

  @override
  String get backup_cloud_enabled => 'Cloud back-up';

  @override
  String get backup_cloud_enabled_subtitle =>
      'Back-ups uploaden naar cloudopslag';

  @override
  String get backup_delete_dialog_cancel => 'Annuleren';

  @override
  String get backup_delete_dialog_content =>
      'Deze back-up wordt permanent verwijderd. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get backup_delete_dialog_delete => 'Verwijderen';

  @override
  String get backup_delete_dialog_title => 'Back-up Verwijderen';

  @override
  String get backup_export_bottomSheet_title => 'Back-up exporteren';

  @override
  String get backup_export_saveToFile => 'Opslaan als bestand';

  @override
  String get backup_export_saveToFile_subtitle =>
      'Kies waar het back-upbestand wordt opgeslagen';

  @override
  String get backup_export_share => 'Delen';

  @override
  String get backup_export_share_subtitle =>
      'Verzenden via AirDrop, e-mail of andere apps';

  @override
  String get backup_export_subtitle => 'Sla je duikgegevens op in een bestand';

  @override
  String get backup_export_success => 'Back-up succesvol geexporteerd';

  @override
  String get backup_export_title => 'Back-up exporteren';

  @override
  String get backup_frequency_daily => 'Dagelijks';

  @override
  String get backup_frequency_monthly => 'Maandelijks';

  @override
  String get backup_frequency_weekly => 'Wekelijks';

  @override
  String get backup_history_action_delete => 'Verwijderen';

  @override
  String get backup_history_action_restore => 'Herstellen';

  @override
  String get backup_history_empty => 'Geen back-ups';

  @override
  String backup_history_error(Object error) {
    return 'Fout bij laden geschiedenis: $error';
  }

  @override
  String get backup_history_pinAction_pin => 'Back-up vastmaken';

  @override
  String get backup_history_pinAction_unpin => 'Back-up losmaken';

  @override
  String get backup_history_pinError => 'Kan vastmaakstatus niet bijwerken.';

  @override
  String backup_history_preMigrationSubtitle(String size) {
    return 'Back-up voor migratie - $size';
  }

  @override
  String get backup_import_invalidFile =>
      'Dit bestand lijkt geen geldige Submersion-back-up te zijn';

  @override
  String get backup_import_subtitle =>
      'Importeer een back-up vanaf elke locatie';

  @override
  String get backup_import_title => 'Herstellen vanuit bestand';

  @override
  String get backup_import_validating => 'Back-upbestand valideren...';

  @override
  String get backup_location_change => 'Wijzigen';

  @override
  String get backup_location_default => 'Standaardlocatie';

  @override
  String get backup_location_title => 'Back-uplocatie';

  @override
  String get backup_replaceConfirm_confirm => 'Overal vervangen';

  @override
  String get backup_replaceConfirm_content =>
      'De bibliotheek op alle gesynchroniseerde apparaten wordt vervangen door deze back-up. Elk apparaat maakt eerst een veiligheidsback-up van zijn huidige gegevens. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get backup_replaceConfirm_title => 'Bibliotheek overal vervangen?';

  @override
  String get backup_restore_dialog_cancel => 'Annuleren';

  @override
  String get backup_restore_dialog_modeMerge_subtitle =>
      'Herstel op dit apparaat. Bij de volgende synchronisatie worden de herstelde gegevens samengevoegd met de cloudbibliotheek.';

  @override
  String get backup_restore_dialog_modeMerge_title =>
      'Samenvoegen bij volgende synchronisatie';

  @override
  String get backup_restore_dialog_modeReplace_subtitle =>
      'De back-up wordt de bibliotheek op dit apparaat, in de cloud en op elk gesynchroniseerd apparaat.';

  @override
  String get backup_restore_dialog_modeReplace_title => 'Overal vervangen';

  @override
  String get backup_restore_dialog_restore => 'Herstellen';

  @override
  String get backup_restore_dialog_restoreReplace =>
      'Herstellen en overal vervangen';

  @override
  String get backup_restore_dialog_safetyNote =>
      'Er wordt automatisch een veiligheidsback-up van uw huidige gegevens gemaakt voor het herstellen.';

  @override
  String get backup_restore_dialog_title => 'Back-up Herstellen';

  @override
  String get backup_restore_dialog_warning =>
      'Dit vervangt ALLE huidige gegevens door de back-upgegevens. Deze actie kan niet ongedaan worden gemaakt.';

  @override
  String backup_restore_safetyReview_progress(int done, int total) {
    return '$done van $total duiken geanalyseerd';
  }

  @override
  String get backup_restore_safetyReview_skip => 'Overslaan';

  @override
  String get backup_restore_safetyReview_title =>
      'Veiligheidscontrole wordt uitgevoerd';

  @override
  String get backup_restoreComplete_continue => 'Doorgaan';

  @override
  String get backup_restoreComplete_description =>
      'Uw gegevens zijn succesvol hersteld. Tik op doorgaan om de app opnieuw te laden met uw herstelde gegevens.';

  @override
  String get backup_restoreComplete_title => 'Herstel Voltooid';

  @override
  String get backup_schedule_enabled => 'Automatische back-ups';

  @override
  String get backup_schedule_enabled_subtitle =>
      'Maak back-ups van uw gegevens volgens schema';

  @override
  String get backup_schedule_frequency => 'Frequentie';

  @override
  String get backup_schedule_retention => 'Back-ups bewaren';

  @override
  String get backup_schedule_retention_subtitle =>
      'Oudere back-ups worden automatisch verwijderd';

  @override
  String get backup_section_auto => 'Automatische back-ups';

  @override
  String get backup_section_cloud => 'Cloud';

  @override
  String get backup_section_history => 'Geschiedenis';

  @override
  String get backup_section_schedule => 'Schema';

  @override
  String get backup_status_disabled => 'Automatische Back-ups Uitgeschakeld';

  @override
  String backup_status_lastBackup(String time) {
    return 'Laatste back-up: $time';
  }

  @override
  String get backup_status_neverBackedUp => 'Nooit Back-up Gemaakt';

  @override
  String get backup_status_noBackupsYet =>
      'Maak uw eerste back-up om uw gegevens te beschermen';

  @override
  String get backup_status_overdue => 'Back-up Achterstallig';

  @override
  String get backup_status_upToDate => 'Back-ups Actueel';

  @override
  String backup_time_daysAgo(int count) {
    return '${count}d geleden';
  }

  @override
  String backup_time_hoursAgo(int count) {
    return '${count}u geleden';
  }

  @override
  String get backup_time_justNow => 'Zojuist';

  @override
  String backup_time_minutesAgo(int count) {
    return '${count}m geleden';
  }

  @override
  String get buddies_action_add => 'Buddy toevoegen';

  @override
  String get buddies_action_addCertification => 'Certificering toevoegen';

  @override
  String get buddies_action_addFirst => 'Voeg je eerste buddy toe';

  @override
  String get buddies_action_addTooltip => 'Nieuwe duikbuddy toevoegen';

  @override
  String get buddies_action_clearSearch => 'Zoekopdracht wissen';

  @override
  String get buddies_action_edit => 'Buddy bewerken';

  @override
  String get buddies_action_importFromContacts => 'Importeren uit contacten';

  @override
  String get buddies_action_moreOptions => 'Meer opties';

  @override
  String get buddies_action_retry => 'Opnieuw proberen';

  @override
  String get buddies_action_search => 'Buddies zoeken';

  @override
  String get buddies_action_shareDives => 'Duiken delen';

  @override
  String get buddies_action_sort => 'Sorteren';

  @override
  String get buddies_action_sortTitle => 'Buddies sorteren';

  @override
  String get buddies_action_update => 'Buddy bijwerken';

  @override
  String buddies_action_viewAll(Object count) {
    return 'Alles bekijken ($count)';
  }

  @override
  String buddies_detail_error(Object error) {
    return 'Fout: $error';
  }

  @override
  String get buddies_detail_noDivesTogether => 'Nog geen duiken samen';

  @override
  String get buddies_detail_notFound => 'Buddy niet gevonden';

  @override
  String buddies_dialog_deleteMessage(Object name) {
    return 'Weet je zeker dat je $name wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.';
  }

  @override
  String get buddies_dialog_deleteTitle => 'Buddy verwijderen?';

  @override
  String get buddies_dialog_discard => 'Verwerpen';

  @override
  String get buddies_dialog_discardMessage =>
      'Je hebt niet-opgeslagen wijzigingen. Weet je zeker dat je deze wilt verwerpen?';

  @override
  String get buddies_dialog_discardTitle => 'Wijzigingen verwerpen?';

  @override
  String get buddies_dialog_keepEditing => 'Doorgaan met bewerken';

  @override
  String get buddies_empty_subtitle =>
      'Voeg je eerste duikbuddy toe om te beginnen';

  @override
  String get buddies_empty_title => 'Nog geen duikbuddies';

  @override
  String buddies_error_loading(Object error) {
    return 'Fout: $error';
  }

  @override
  String get buddies_error_unableToLoadDives => 'Kan duiken niet laden';

  @override
  String get buddies_error_unableToLoadStats => 'Kan statistieken niet laden';

  @override
  String get buddies_field_certificationAgency => 'Certificeringsorganisatie';

  @override
  String get buddies_field_certificationLevel => 'Certificeringsniveau';

  @override
  String get buddies_field_email => 'E-mail';

  @override
  String get buddies_field_emailHint => 'email@voorbeeld.nl';

  @override
  String get buddies_field_nameHint => 'Voer buddy naam in';

  @override
  String get buddies_field_nameRequired => 'Naam *';

  @override
  String get buddies_field_notes => 'Notities';

  @override
  String get buddies_field_notesHint => 'Voeg notities toe over deze buddy...';

  @override
  String get buddies_field_phone => 'Telefoon';

  @override
  String get buddies_field_phoneHint => '+31 6 12345678';

  @override
  String get buddies_label_agency => 'Organisatie';

  @override
  String buddies_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken',
      one: '1 duik',
    );
    return '$_temp0';
  }

  @override
  String get buddies_label_level => 'Niveau';

  @override
  String get buddies_label_notSpecified => 'Niet opgegeven';

  @override
  String get buddies_label_photoComingSoon => 'Foto ondersteuning komt in v2.0';

  @override
  String get buddies_message_added => 'Buddy succesvol toegevoegd';

  @override
  String get buddies_message_contactImportUnavailable =>
      'Contacten importeren is niet beschikbaar op dit platform';

  @override
  String get buddies_message_contactLoadFailed => 'Contacten laden mislukt';

  @override
  String get buddies_message_contactPermissionRequired =>
      'Contacten toegang is vereist om buddies te importeren';

  @override
  String get buddies_message_deleted => 'Buddy verwijderd';

  @override
  String buddies_message_errorImportingContact(Object error) {
    return 'Fout bij importeren contact: $error';
  }

  @override
  String buddies_message_errorLoading(Object error) {
    return 'Fout bij laden buddy: $error';
  }

  @override
  String buddies_message_errorSaving(Object error) {
    return 'Fout bij opslaan buddy: $error';
  }

  @override
  String buddies_message_exportFailed(Object error) {
    return 'Export mislukt: $error';
  }

  @override
  String get buddies_message_noDivesFound =>
      'Geen duiken gevonden om te exporteren';

  @override
  String get buddies_message_noDivesToShare =>
      'Geen duiken om te delen met deze buddy';

  @override
  String get buddies_message_preparingExport => 'Export voorbereiden...';

  @override
  String get buddies_message_updated => 'Buddy succesvol bijgewerkt';

  @override
  String get buddies_picker_add => 'Toevoegen';

  @override
  String get buddies_picker_addCustomRole => 'Aangepaste rol toevoegen...';

  @override
  String get buddies_picker_addNew => 'Nieuwe buddy toevoegen';

  @override
  String get buddies_picker_done => 'Gereed';

  @override
  String get buddies_picker_me => 'Ik';

  @override
  String get buddies_picker_noBuddiesFound => 'Geen buddies gevonden';

  @override
  String get buddies_picker_noBuddiesYet => 'Nog geen buddies';

  @override
  String get buddies_picker_noRole => 'Geen rol';

  @override
  String get buddies_picker_noneSelected => 'Geen buddies geselecteerd';

  @override
  String get buddies_picker_searchHint => 'Zoek buddies...';

  @override
  String get buddies_picker_selectBuddies => 'Selecteer buddies';

  @override
  String get buddies_picker_selectMyRole => 'Selecteer mijn rol';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Selecteer rol voor $name';
  }

  @override
  String get buddies_picker_setMyRole => 'Mijn rol instellen';

  @override
  String get buddies_picker_tapToAdd =>
      'Tik op \'Toevoegen\' om duikbuddies te selecteren';

  @override
  String get buddies_search_hint => 'Zoeken op naam, e-mail of telefoon';

  @override
  String buddies_search_noResults(Object query) {
    return 'Geen buddies gevonden voor \"$query\"';
  }

  @override
  String get buddies_section_certification => 'Certificering';

  @override
  String get buddies_section_certifications => 'Certificeringen';

  @override
  String get buddies_certifications_empty => 'Geen certificeringen';

  @override
  String get buddies_section_contact => 'Contact';

  @override
  String get buddies_section_diveStatistics => 'Duikstatistieken';

  @override
  String get buddies_section_notes => 'Notities';

  @override
  String get buddies_section_sharedDives => 'Gedeelde duiken';

  @override
  String get buddies_stat_divesTogether => 'Duiken samen';

  @override
  String get buddies_stat_favoriteSite => 'Favoriete locatie';

  @override
  String get buddies_stat_firstDive => 'Eerste duik';

  @override
  String get buddies_stat_lastDive => 'Laatste duik';

  @override
  String get buddies_summary_overview => 'Overzicht';

  @override
  String get buddies_summary_quickActions => 'Snelle acties';

  @override
  String get buddies_summary_recentBuddies => 'Recente buddies';

  @override
  String get buddies_summary_selectHint =>
      'Selecteer een buddy uit de lijst om details te bekijken';

  @override
  String get buddies_summary_title => 'Duikbuddies';

  @override
  String get buddies_summary_totalBuddies => 'Totaal buddies';

  @override
  String get buddies_summary_withCertification => 'Met certificering';

  @override
  String get buddies_title => 'Buddies';

  @override
  String get buddies_title_add => 'Buddy toevoegen';

  @override
  String get buddies_title_edit => 'Buddy bewerken';

  @override
  String get buddies_title_singular => 'Buddy';

  @override
  String get buddies_validation_emailInvalid =>
      'Voer een geldig e-mailadres in';

  @override
  String get buddies_validation_nameRequired => 'Voer een naam in';

  @override
  String get buddies_list_selection_closeTooltip => 'Selectie sluiten';

  @override
  String buddies_list_selection_count(int count) {
    return '$count geselecteerd';
  }

  @override
  String get buddies_list_selection_selectAllTooltip => 'Alles selecteren';

  @override
  String get buddies_list_selection_deselectAllTooltip => 'Alles deselecteren';

  @override
  String get buddies_list_selection_mergeTooltip => 'Geselecteerde samenvoegen';

  @override
  String get buddies_list_selection_deleteTooltip =>
      'Geselecteerde verwijderen';

  @override
  String buddies_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'buddies',
      one: 'buddy',
    );
    return '$count $_temp0 samengevoegd';
  }

  @override
  String get buddies_list_merge_undo => 'Ongedaan maken';

  @override
  String get buddies_list_merge_restored => 'Samenvoeging ongedaan gemaakt';

  @override
  String get buddies_list_bulkDelete_title => 'Buddies verwijderen';

  @override
  String buddies_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'buddies',
      one: 'buddy',
    );
    return 'Weet je zeker dat je $count $_temp0 wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.';
  }

  @override
  String get buddies_list_bulkDelete_cancel => 'Annuleren';

  @override
  String get buddies_list_bulkDelete_confirm => 'Verwijderen';

  @override
  String buddies_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'buddies',
      one: 'buddy',
    );
    return '$count $_temp0 verwijderd';
  }

  @override
  String get buddies_edit_merge_title => 'Buddies samenvoegen';

  @override
  String get buddies_edit_merge_fieldSourceCycleTooltip =>
      'Waarde van volgende geselecteerde buddy gebruiken';

  @override
  String buddies_edit_merge_fieldSourceLabel(
    String buddyName,
    int current,
    int total,
  ) {
    return 'Van $buddyName ($current/$total)';
  }

  @override
  String get buddies_edit_merge_confirmTitle => 'Buddies samenvoegen';

  @override
  String buddies_edit_merge_confirmBody(int count) {
    return 'Dit voegt $count buddies samen tot één. Duikassociaties worden gecombineerd onder de overgebleven buddy. De andere buddies worden verwijderd.';
  }

  @override
  String get buddies_edit_merge_loadingErrorTitle => 'Buddies samenvoegen';

  @override
  String buddies_edit_merge_loadingErrorBody(String error) {
    return 'Laden van buddies mislukt: $error';
  }

  @override
  String get buddies_edit_merge_notEnoughTitle => 'Buddies samenvoegen';

  @override
  String get buddies_edit_merge_notEnoughBody =>
      'Niet genoeg buddies om samen te voegen.';

  @override
  String get buddies_instructorPicker_label => 'Instructeur uit buddy\'s';

  @override
  String get buddies_instructorPicker_none => 'Geen (handmatige invoer)';

  @override
  String get certifications_appBar_addCertification =>
      'Certificering toevoegen';

  @override
  String get certifications_appBar_certificationWallet =>
      'Certificeringsportefeuille';

  @override
  String get certifications_appBar_editCertification =>
      'Certificering bewerken';

  @override
  String get certifications_appBar_title => 'Certificeringen';

  @override
  String get certifications_detail_action_delete => 'Verwijderen';

  @override
  String get certifications_detail_appBar_title => 'Certificering';

  @override
  String get certifications_detail_courseCompleted => 'Afgerond';

  @override
  String get certifications_detail_courseInProgress => 'Bezig';

  @override
  String get certifications_detail_dialog_cancel => 'Annuleren';

  @override
  String get certifications_detail_dialog_deleteConfirm => 'Verwijderen';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen?';
  }

  @override
  String get certifications_detail_dialog_deleteTitle =>
      'Certificering verwijderen?';

  @override
  String get certifications_detail_label_agency => 'Organisatie';

  @override
  String get certifications_detail_label_cardNumber => 'Kaartnummer';

  @override
  String get certifications_detail_label_certification => 'Certificering';

  @override
  String get certifications_detail_label_expiryDate => 'Vervaldatum';

  @override
  String get certifications_detail_label_instructorName => 'Naam';

  @override
  String get certifications_detail_label_instructorNumber => 'Instructeur #';

  @override
  String get certifications_detail_label_issueDate => 'Uitgiftedatum';

  @override
  String get certifications_detail_label_type => 'Type';

  @override
  String get certifications_detail_label_validity => 'Geldigheid';

  @override
  String get certifications_detail_noExpiration => 'Geen vervaldatum';

  @override
  String get certifications_detail_notFound => 'Certificering niet gevonden';

  @override
  String get certifications_detail_photoLabel_back => 'Achterkant';

  @override
  String get certifications_detail_photoLabel_front => 'Voorkant';

  @override
  String certifications_detail_photo_fullscreenTitle(
    Object label,
    Object name,
  ) {
    return '$label - $name';
  }

  @override
  String get certifications_detail_photo_unableToLoad =>
      'Kan afbeelding niet laden';

  @override
  String get certifications_detail_sectionTitle_cardPhotos => 'Kaartfoto\'s';

  @override
  String get certifications_detail_sectionTitle_dates => 'Datums';

  @override
  String get certifications_detail_sectionTitle_details =>
      'Certificeringsdetails';

  @override
  String get certifications_detail_sectionTitle_instructor => 'Instructeur';

  @override
  String get certifications_detail_sectionTitle_notes => 'Notities';

  @override
  String get certifications_detail_sectionTitle_trainingCourse =>
      'Opleidingscursus';

  @override
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  ) {
    return '$label-foto van $name. Tik om volledig scherm te bekijken';
  }

  @override
  String get certifications_detail_snackBar_deleted =>
      'Certificering verwijderd';

  @override
  String get certifications_detail_status_expired =>
      'Deze certificering is verlopen';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return 'Verlopen op $date';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return 'Verloopt over $days dagen';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return 'Verloopt op $date';
  }

  @override
  String get certifications_detail_tooltip_edit => 'Certificering bewerken';

  @override
  String get certifications_detail_tooltip_editShort => 'Bewerken';

  @override
  String get certifications_detail_tooltip_moreOptions => 'Meer opties';

  @override
  String get certifications_ecardStack_empty_subtitle =>
      'Voeg je eerste certificering toe om deze hier te zien';

  @override
  String get certifications_ecardStack_empty_title =>
      'Nog geen certificeringen';

  @override
  String get certifications_ecard_label_cardNumber => 'KAARTNR.';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Gecertificeerd door $agency';
  }

  @override
  String get certifications_ecard_label_diver => 'DUIKER';

  @override
  String get certifications_ecard_label_instructor => 'INSTRUCTEUR';

  @override
  String get certifications_ecard_label_issued => 'UITGEGEVEN';

  @override
  String get certifications_ecard_label_validUntil => 'GELDIG TOT';

  @override
  String get certifications_ecard_statusBadge_expired => 'VERLOPEN';

  @override
  String get certifications_ecard_statusBadge_expiring => 'VERLOOPT';

  @override
  String get certifications_edit_appBar_add => 'Certificering toevoegen';

  @override
  String get certifications_edit_appBar_edit => 'Certificering bewerken';

  @override
  String get certifications_edit_button_add => 'Certificering toevoegen';

  @override
  String get certifications_edit_button_cancel => 'Annuleren';

  @override
  String get certifications_edit_button_save => 'Opslaan';

  @override
  String get certifications_edit_button_update => 'Certificering bijwerken';

  @override
  String get certifications_edit_certification_notSpecified => 'Niet opgegeven';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return '$label wissen';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect =>
      'Tik om te selecteren';

  @override
  String get certifications_edit_dialog_discard => 'Verwerpen';

  @override
  String get certifications_edit_dialog_discardContent =>
      'Je hebt niet-opgeslagen wijzigingen. Weet je zeker dat je wilt vertrekken?';

  @override
  String get certifications_edit_dialog_discardTitle =>
      'Wijzigingen verwerpen?';

  @override
  String get certifications_edit_dialog_keepEditing => 'Verder bewerken';

  @override
  String get certifications_edit_group_progression => 'Opleidingslijn';

  @override
  String get certifications_edit_group_specialties => 'Specialisaties';

  @override
  String get certifications_edit_help_expiryDate =>
      'Laat leeg voor certificeringen die niet verlopen';

  @override
  String get certifications_edit_helper_nameOnCard => 'Optioneel';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Voer certificeringskaartnummer in';

  @override
  String get certifications_edit_hint_instructorName =>
      'Naam van certificerende instructeur';

  @override
  String get certifications_edit_hint_instructorNumber =>
      'Certificeringsnummer instructeur';

  @override
  String get certifications_edit_hint_notes => 'Eventuele extra notities';

  @override
  String get certifications_edit_label_agency => 'Organisatie *';

  @override
  String get certifications_edit_label_cardNumber => 'Kaartnummer';

  @override
  String get certifications_edit_label_certification => 'Certificering';

  @override
  String get certifications_edit_label_expiryDate => 'Vervaldatum';

  @override
  String get certifications_edit_label_instructorName => 'Instructeurnaam';

  @override
  String get certifications_edit_label_instructorNumber => 'Instructeurnummer';

  @override
  String get certifications_edit_label_issueDate => 'Uitgiftedatum';

  @override
  String get certifications_edit_label_nameOnCard => 'Naam op de kaart';

  @override
  String get certifications_edit_label_notes => 'Notities';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return '$label-foto toevoegen. Tik om te selecteren';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return '$label-foto bijgevoegd. Tik om te wijzigen';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery => 'Kies uit galerij';

  @override
  String certifications_edit_photo_removeTooltip(Object label) {
    return '$label-foto verwijderen';
  }

  @override
  String get certifications_edit_photo_takePhoto => 'Foto maken';

  @override
  String get certifications_edit_sectionTitle_cardPhotos => 'Kaartfoto\'s';

  @override
  String get certifications_edit_sectionTitle_dates => 'Datums';

  @override
  String get certifications_edit_sectionTitle_instructorInfo =>
      'Instructeurinformatie';

  @override
  String get certifications_edit_sectionTitle_notes => 'Notities';

  @override
  String get certifications_edit_snackBar_added =>
      'Certificering succesvol toegevoegd';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return 'Fout bij laden van certificering: $error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return 'Fout bij kiezen van foto: $error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return 'Fout bij opslaan van certificering: $error';
  }

  @override
  String get certifications_edit_snackBar_updated =>
      'Certificering succesvol bijgewerkt';

  @override
  String get certifications_edit_validation_certificationOrNameRequired =>
      'Kies een certificering of voer een naam in';

  @override
  String get certifications_list_button_retry => 'Opnieuw proberen';

  @override
  String get certifications_list_empty_button =>
      'Voeg je eerste certificering toe';

  @override
  String get certifications_list_empty_subtitle =>
      'Voeg je duikcertificeringen toe om je\nopleidingen en kwalificaties bij te houden';

  @override
  String get certifications_list_empty_title =>
      'Nog geen certificeringen toegevoegd';

  @override
  String certifications_list_error_loading(Object error) {
    return 'Fout bij laden van certificeringen: $error';
  }

  @override
  String get certifications_list_fab_addCertification =>
      'Certificering toevoegen';

  @override
  String get certifications_list_section_expired => 'Verlopen';

  @override
  String get certifications_list_section_expiringSoon => 'Verloopt binnenkort';

  @override
  String get certifications_list_section_valid => 'Geldig';

  @override
  String get certifications_list_sort_title => 'Certificeringen sorteren';

  @override
  String get certifications_list_tile_expired => 'Verlopen';

  @override
  String certifications_list_tile_expiringDays(Object days) {
    return '${days}d';
  }

  @override
  String get certifications_list_tooltip_addCertification =>
      'Certificering toevoegen';

  @override
  String get certifications_list_tooltip_search => 'Certificeringen zoeken';

  @override
  String get certifications_list_tooltip_sort => 'Sorteren';

  @override
  String get certifications_list_tooltip_walletView => 'Portemonneeweergave';

  @override
  String get certifications_picker_clearTooltip =>
      'Certificeringselectie wissen';

  @override
  String get certifications_picker_empty_addButton => 'Certificering toevoegen';

  @override
  String get certifications_picker_empty_title => 'Nog geen certificeringen';

  @override
  String certifications_picker_error(Object error) {
    return 'Fout bij laden van certificeringen: $error';
  }

  @override
  String get certifications_picker_expired => 'Verlopen';

  @override
  String get certifications_picker_hint =>
      'Tik om aan een behaalde certificering te koppelen';

  @override
  String get certifications_picker_newCert => 'Nieuw cert.';

  @override
  String get certifications_picker_noSelection =>
      'Geen certificering geselecteerd';

  @override
  String get certifications_picker_sheetTitle => 'Koppelen aan certificering';

  @override
  String get certifications_renderer_footer => 'Submersion Duiklogboek';

  @override
  String certifications_renderer_label_cardNumber(Object number) {
    return 'Kaartnr.: $number';
  }

  @override
  String get certifications_renderer_label_hasCompletedTraining =>
      'heeft de opleiding afgerond als';

  @override
  String certifications_renderer_label_instructor(Object name) {
    return 'Instructeur: $name';
  }

  @override
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  ) {
    return 'Instructeur: $name ($number)';
  }

  @override
  String certifications_renderer_label_issued(Object date) {
    return 'Uitgegeven: $date';
  }

  @override
  String get certifications_renderer_label_thisCertifies =>
      'Hierbij wordt gecertificeerd dat';

  @override
  String get certifications_search_empty_hint =>
      'Zoek op naam, organisatie of kaartnummer';

  @override
  String get certifications_search_fieldLabel => 'Certificeringen zoeken...';

  @override
  String certifications_search_noResults(Object query) {
    return 'Geen certificeringen gevonden voor \"$query\"';
  }

  @override
  String get certifications_search_tooltip_back => 'Terug';

  @override
  String get certifications_search_tooltip_clear => 'Zoekopdracht wissen';

  @override
  String certifications_share_error_card(Object error) {
    return 'Kaart delen mislukt: $error';
  }

  @override
  String certifications_share_error_certificate(Object error) {
    return 'Certificaat delen mislukt: $error';
  }

  @override
  String get certifications_share_option_card_subtitle =>
      'Certificeringsafbeelding in creditcardformaat';

  @override
  String get certifications_share_option_card_title => 'Delen als kaart';

  @override
  String get certifications_share_option_certificate_subtitle =>
      'Formeel certificaatdocument';

  @override
  String get certifications_share_option_certificate_title =>
      'Delen als certificaat';

  @override
  String get certifications_share_title => 'Certificering delen';

  @override
  String get certifications_summary_header_subtitle =>
      'Selecteer een certificering uit de lijst om details te bekijken';

  @override
  String get certifications_summary_header_title => 'Certificeringen';

  @override
  String get certifications_summary_overview_title => 'Overzicht';

  @override
  String get certifications_summary_quickActions_add =>
      'Certificering toevoegen';

  @override
  String get certifications_summary_quickActions_title => 'Snelle acties';

  @override
  String get certifications_summary_recentTitle => 'Recente certificeringen';

  @override
  String get certifications_summary_stat_expired => 'Verlopen';

  @override
  String get certifications_summary_stat_expiringSoon => 'Verloopt binnenkort';

  @override
  String get certifications_summary_stat_total => 'Totaal';

  @override
  String get certifications_summary_stat_valid => 'Geldig';

  @override
  String get certifications_wallet_appBar_title => 'Certificeringsportemonnee';

  @override
  String get certifications_wallet_error_retry => 'Opnieuw proberen';

  @override
  String get certifications_wallet_error_title =>
      'Kan certificeringen niet laden';

  @override
  String get certifications_wallet_options_edit => 'Bewerken';

  @override
  String get certifications_wallet_options_share => 'Delen';

  @override
  String get certifications_wallet_options_viewDetails => 'Details bekijken';

  @override
  String get certifications_wallet_tooltip_add => 'Certificering toevoegen';

  @override
  String get certifications_wallet_tooltip_share => 'Certificering delen';

  @override
  String get checklists_section_title => 'Checklist';

  @override
  String checklists_progress(int done, int total) {
    return '$done van $total taken voltooid';
  }

  @override
  String get checklists_empty_upcoming =>
      'Plan je reis - voeg taken toe of pas een sjabloon toe';

  @override
  String get checklists_empty_past => 'Geen checklist-items';

  @override
  String get checklists_addItem => 'Item toevoegen';

  @override
  String get checklists_item_titleLabel => 'Titel';

  @override
  String get checklists_item_titleRequired => 'Titel is verplicht';

  @override
  String get checklists_item_categoryLabel => 'Categorie';

  @override
  String get checklists_item_notesLabel => 'Notities';

  @override
  String get checklists_item_dueDateLabel => 'Vervaldatum';

  @override
  String get checklists_item_dueOffsetLabel => 'Dagen voor start reis';

  @override
  String get checklists_item_dueOffsetInvalid => 'Voer 0 of meer dagen in';

  @override
  String get checklists_item_overdue => 'Te laat';

  @override
  String get checklists_item_edit => 'Item bewerken';

  @override
  String get checklists_item_delete => 'Item verwijderen';

  @override
  String get checklists_menu_applyTemplate => 'Sjabloon toepassen...';

  @override
  String get checklists_menu_saveAsTemplate => 'Opslaan als sjabloon...';

  @override
  String get checklists_applySheet_title => 'Sjabloon toepassen';

  @override
  String get checklists_applySheet_empty =>
      'Nog geen sjablonen. Maak ze aan in Instellingen.';

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
      other: '$added items worden toegevoegd',
      one: '1 item wordt toegevoegd',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped duplicaten overgeslagen',
      one: '1 duplicaat overgeslagen',
      zero: 'geen duplicaten overgeslagen',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String checklists_apply_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items toegevoegd',
      one: '1 item toegevoegd',
      zero: 'Geen nieuwe items toegevoegd',
    );
    return '$_temp0';
  }

  @override
  String get checklists_apply_templateGone => 'Sjabloon bestaat niet meer';

  @override
  String get checklists_saveTemplate_title => 'Opslaan als sjabloon';

  @override
  String get checklists_saveTemplate_nameLabel => 'Sjabloonnaam';

  @override
  String get checklists_saveTemplate_success => 'Sjabloon opgeslagen';

  @override
  String get checklists_templates_pageTitle => 'Checklistsjablonen';

  @override
  String get checklists_templates_addTemplate => 'Sjabloon toevoegen';

  @override
  String get checklists_templates_empty => 'Nog geen sjablonen';

  @override
  String get checklists_templates_deleteTitle => 'Sjabloon verwijderen';

  @override
  String checklists_templates_deleteContent(Object name) {
    return '\"$name\" verwijderen? Reizen die dit al hebben toegepast, behouden hun items.';
  }

  @override
  String get checklists_template_nameLabel => 'Naam';

  @override
  String get checklists_template_nameRequired => 'Naam is verplicht';

  @override
  String get checklists_template_descriptionLabel => 'Beschrijving';

  @override
  String get checklists_template_itemsHeader => 'Items';

  @override
  String get checklists_template_addItem => 'Item toevoegen';

  @override
  String get preDive_templates_title => 'Pre-dive checklists';

  @override
  String get preDive_templates_empty => 'Nog geen pre-dive checklists';

  @override
  String get preDive_templates_builtInBadge => 'Ingebouwd';

  @override
  String get preDive_templates_clone => 'Dupliceren';

  @override
  String get preDive_templates_cloneSuffix => ' (kopie)';

  @override
  String get preDive_templates_delete => 'Verwijderen';

  @override
  String get preDive_templates_deleteConfirm =>
      'Dit checklistsjabloon verwijderen?';

  @override
  String get preDive_templates_strictOrderBadge => 'Vaste volgorde';

  @override
  String get preDive_edit_titleNew => 'Nieuwe pre-dive checklist';

  @override
  String get preDive_edit_titleEdit => 'Pre-dive checklist bewerken';

  @override
  String get preDive_edit_name => 'Naam';

  @override
  String get preDive_edit_description => 'Beschrijving';

  @override
  String get preDive_edit_category => 'Categorie';

  @override
  String get preDive_edit_strictOrder => 'Vaste volgorde';

  @override
  String get preDive_edit_strictOrderHelp =>
      'Items moeten van boven naar beneden worden afgewerkt';

  @override
  String get preDive_edit_addItem => 'Item toevoegen';

  @override
  String get preDive_edit_nameRequired => 'Voer een naam in';

  @override
  String get preDive_item_title => 'Titel';

  @override
  String get preDive_item_section => 'Sectie';

  @override
  String get preDive_item_notes => 'Notities';

  @override
  String get preDive_item_required => 'Verplicht';

  @override
  String get preDive_item_type_check => 'Selectievakje';

  @override
  String get preDive_item_type_value => 'Geregistreerde waarde';

  @override
  String get preDive_item_type_equipmentSet => 'Items uit uitrustingsset';

  @override
  String get preDive_item_valueLabel => 'Waardelabel';

  @override
  String get preDive_item_valueUnit => 'Eenheid';

  @override
  String get preDive_item_valueMin => 'Min (waarschuwing)';

  @override
  String get preDive_item_valueMax => 'Max (waarschuwing)';

  @override
  String preDive_runner_progress(int done, int total) {
    return '$done van $total';
  }

  @override
  String get preDive_runner_complete => 'Voltooien';

  @override
  String preDive_runner_completeFlagged(int count) {
    return 'Voltooien met $count gemarkeerde items?';
  }

  @override
  String get preDive_runner_abort => 'Checklist afbreken';

  @override
  String get preDive_runner_abortConfirm =>
      'Deze checklist afbreken? Deze blijft in de geschiedenis bewaard als afgebroken.';

  @override
  String get preDive_runner_skip => 'Overslaan';

  @override
  String get preDive_runner_flag => 'Markeren';

  @override
  String get preDive_runner_undo => 'Terugzetten naar openstaand';

  @override
  String get preDive_runner_serviceOverdue => 'Onderhoud verlopen';

  @override
  String get preDive_runner_addNote => 'Notitie toevoegen';

  @override
  String get preDive_runner_enterValue => 'Waarde invoeren';

  @override
  String preDive_runner_flaggedBadge(int count) {
    return '$count gemarkeerd';
  }

  @override
  String get preDive_runner_locked => 'Deze checklist is vergrendeld';

  @override
  String get preDive_sessions_title => 'Pre-dive checklists';

  @override
  String get preDive_sessions_empty => 'Nog geen uitgevoerde checklists';

  @override
  String get preDive_sessions_resume => 'Hervatten';

  @override
  String get preDive_sessions_start => 'Checklist starten';

  @override
  String get preDive_sessions_statusCompleted => 'Voltooid';

  @override
  String get preDive_sessions_statusAborted => 'Afgebroken';

  @override
  String get preDive_sessions_statusInProgress => 'Bezig';

  @override
  String get preDive_sessions_linkedDive => 'Gekoppelde duik';

  @override
  String get preDive_link_linkToDive => 'Koppelen aan duik';

  @override
  String get preDive_link_unlinkDive => 'Duik ontkoppelen';

  @override
  String get preDive_link_linkChecklist => 'Pre-dive checklist koppelen';

  @override
  String get preDive_link_unlinkChecklist => 'Pre-dive checklist ontkoppelen';

  @override
  String get preDive_link_searchDives => 'Duiken zoeken';

  @override
  String get preDive_link_noDives => 'Geen duiken om te koppelen';

  @override
  String preDive_link_noDivesMatch(String query) {
    return 'Geen duiken komen overeen met \"$query\"';
  }

  @override
  String get preDive_link_noUnlinkedSessions => 'Geen ongekoppelde checklists';

  @override
  String get preDive_link_linked => 'Checklist gekoppeld aan deze duik';

  @override
  String get preDive_link_unlinked => 'Checklist ontkoppeld van deze duik';

  @override
  String get preDive_sessions_delete => 'Verwijderen';

  @override
  String get preDive_sessions_deleteConfirm =>
      'Deze checklistregistratie verwijderen?';

  @override
  String get preDive_sessions_filter => 'Filteren';

  @override
  String get preDive_sessions_filterTitle => 'Checklistsessies filteren';

  @override
  String get preDive_sessions_filterChecklist => 'Checklist';

  @override
  String get preDive_sessions_filterStatus => 'Status';

  @override
  String get preDive_sessions_filterFlaggedOnly => 'Alleen gemarkeerde sessies';

  @override
  String get preDive_sessions_filterDateRange => 'Datumbereik';

  @override
  String get preDive_sessions_filterAnyDate => 'Elke datum';

  @override
  String get preDive_sessions_filterClearAll => 'Alles wissen';

  @override
  String get preDive_sessions_filterApply => 'Toepassen';

  @override
  String get preDive_sessions_filterFlaggedChip => 'Alleen gemarkeerd';

  @override
  String get preDive_sessions_emptyFiltered =>
      'Geen checklistsessies voldoen aan deze filters';

  @override
  String get preDive_sessions_export => 'Exporteren naar Excel';

  @override
  String get preDive_sessions_exportEmpty =>
      'Geen checklistsessies om te exporteren';

  @override
  String preDive_sessions_exportFailed(String error) {
    return 'Exporteren mislukt: $error';
  }

  @override
  String get preDive_start_title => 'Pre-dive checklist starten';

  @override
  String get preDive_start_template => 'Checklist';

  @override
  String get preDive_start_equipmentSet => 'Uitrustingsset';

  @override
  String get preDive_start_noEquipmentSet => 'Geen';

  @override
  String get preDive_start_begin => 'Beginnen';

  @override
  String get diveLog_listPage_bottomSheet_preDiveChecklist =>
      'Pre-dive checklist starten';

  @override
  String get preDive_dashboard_title => 'Pre-dive check';

  @override
  String preDive_dashboard_resume(int done, int total) {
    return 'Hervatten - $done van $total';
  }

  @override
  String get preDive_dashboard_start => 'Pre-dive check starten';

  @override
  String get trips_detail_preDive_action => 'Pre-dive checklist';

  @override
  String get settings_manage_preDiveChecklists => 'Pre-dive checklists';

  @override
  String get settings_manage_preDiveChecklists_subtitle =>
      'Buddychecks, CCR-opbouwlijsten, uitrusting inpakken';

  @override
  String get common_action_back => 'Terug';

  @override
  String get common_action_cancel => 'Annuleren';

  @override
  String get common_action_close => 'Sluiten';

  @override
  String get common_action_continue => 'Doorgaan';

  @override
  String get common_action_delete => 'Verwijderen';

  @override
  String get common_action_edit => 'Bewerken';

  @override
  String get common_action_ok => 'OK';

  @override
  String get common_action_save => 'Opslaan';

  @override
  String get common_action_search => 'Zoeken';

  @override
  String get common_action_share => 'Delen';

  @override
  String get common_label_error => 'Fout';

  @override
  String get common_label_loading => 'Laden';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get common_error_tryAgain =>
      'Er is iets misgegaan. Probeer het opnieuw.';

  @override
  String get courses_action_add => 'Cursus toevoegen';

  @override
  String get courses_action_addFromTemplate => 'Toevoegen vanuit sjabloon';

  @override
  String get courses_action_addRequirement => 'Vereiste toevoegen';

  @override
  String get courses_action_create => 'Cursus aanmaken';

  @override
  String get courses_action_deleteRequirement => 'Vereiste verwijderen';

  @override
  String get courses_action_edit => 'Cursus bewerken';

  @override
  String get courses_action_editRequirement => 'Vereiste bewerken';

  @override
  String get courses_action_exportTrainingLog => 'Trainingslogboek exporteren';

  @override
  String get courses_action_linkDive => 'Koppelen';

  @override
  String get courses_action_markCompleted => 'Markeren als voltooid';

  @override
  String get courses_action_unlinkDive => 'Duik ontkoppelen';

  @override
  String get courses_action_moreOptions => 'Meer opties';

  @override
  String get courses_action_retry => 'Opnieuw proberen';

  @override
  String get courses_action_saveChanges => 'Wijzigingen opslaan';

  @override
  String get courses_action_saveSemantic => 'Cursus opslaan';

  @override
  String get courses_action_sort => 'Sorteren';

  @override
  String get courses_action_sortTitle => 'Cursussen sorteren';

  @override
  String courses_card_instructor(Object name) {
    return 'Instructeur: $name';
  }

  @override
  String courses_card_started(Object date) {
    return 'Gestart $date';
  }

  @override
  String get courses_detail_certificationNotFound =>
      'Certificering niet gevonden';

  @override
  String get courses_detail_noTrainingDives =>
      'Nog geen trainingsduiken gekoppeld';

  @override
  String get courses_detail_notFound => 'Cursus niet gevonden';

  @override
  String get courses_dialog_complete => 'Voltooien';

  @override
  String courses_dialog_deleteMessage(Object name) {
    return 'Weet je zeker dat je $name wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.';
  }

  @override
  String get courses_dialog_deleteTitle => 'Cursus verwijderen?';

  @override
  String get courses_dialog_markCompletedMessage =>
      'Dit markeert de cursus als voltooid met de datum van vandaag. Doorgaan?';

  @override
  String get courses_dialog_markCompletedTitle => 'Markeren als voltooid?';

  @override
  String get courses_empty_button => 'Voeg je eerste trainingscursus toe';

  @override
  String get courses_empty_noCompleted => 'Geen voltooide cursussen';

  @override
  String get courses_empty_noInProgress => 'Geen cursussen bezig';

  @override
  String get courses_empty_subtitle =>
      'Voeg je eerste cursus toe om te beginnen';

  @override
  String get courses_empty_title => 'Nog geen trainingscursussen';

  @override
  String courses_error_generic(Object error) {
    return 'Fout: $error';
  }

  @override
  String get courses_error_loadingCertification =>
      'Fout bij laden certificering';

  @override
  String get courses_error_loadingDives => 'Fout bij laden duiken';

  @override
  String get courses_field_courseName => 'Cursusnaam';

  @override
  String get courses_field_courseNameHint => 'bijv. Open Water Diver';

  @override
  String get courses_field_instructorName => 'Naam instructeur';

  @override
  String get courses_field_instructorNumber => 'Instructeurnummer';

  @override
  String get courses_field_linkCertificationHint =>
      'Koppel een certificering verdiend bij deze cursus';

  @override
  String get courses_field_location => 'Locatie';

  @override
  String get courses_field_notes => 'Notities';

  @override
  String get courses_filter_all => 'Alle';

  @override
  String get courses_label_agency => 'Organisatie';

  @override
  String get courses_label_completed => 'Voltooid';

  @override
  String get courses_label_completionDate => 'Voltooiingsdatum';

  @override
  String get courses_label_courseInProgress => 'Cursus is bezig';

  @override
  String get courses_label_instructorNumber => 'Instructeur #';

  @override
  String get courses_label_location => 'Locatie';

  @override
  String get courses_label_name => 'Naam';

  @override
  String get courses_label_startDate => 'Startdatum';

  @override
  String courses_message_errorSaving(Object error) {
    return 'Fout bij opslaan cursus: $error';
  }

  @override
  String courses_message_exportFailed(Object error) {
    return 'Exporteren trainingslogboek mislukt: $error';
  }

  @override
  String get courses_picker_active => 'Actief';

  @override
  String get courses_picker_clearSelection => 'Selectie wissen';

  @override
  String get courses_picker_createCourse => 'Cursus aanmaken';

  @override
  String courses_picker_errorLoading(Object error) {
    return 'Fout bij laden cursussen: $error';
  }

  @override
  String get courses_picker_newCourse => 'Nieuwe cursus';

  @override
  String get courses_picker_noCourses => 'Nog geen cursussen';

  @override
  String get courses_picker_noneSelected => 'Geen cursus geselecteerd';

  @override
  String get courses_picker_selectTitle => 'Selecteer trainingscursus';

  @override
  String get courses_picker_selected => 'geselecteerd';

  @override
  String get courses_picker_tapToLink =>
      'Tik om te koppelen aan een trainingscursus';

  @override
  String courses_requirement_diveProgress(int count, int target) {
    return '$count van $target duiken';
  }

  @override
  String get courses_requirement_field_name => 'Naam';

  @override
  String get courses_requirement_field_targetCount => 'Vereiste duiken';

  @override
  String get courses_requirement_kind_checklist => 'Afvinkpunt';

  @override
  String get courses_requirement_kind_dive => 'Duikvereiste';

  @override
  String get courses_requirement_suggestions => 'Voorgestelde duiken';

  @override
  String get courses_requirements_empty =>
      'Houd adventure-duiken, voorvereisten en afvinkpunten bij voor deze cursus.';

  @override
  String courses_requirements_progress(int satisfied, int total) {
    return '$satisfied van $total voltooid';
  }

  @override
  String get courses_section_details => 'Cursusdetails';

  @override
  String get courses_section_earnedCertification => 'Behaalde certificering';

  @override
  String get courses_section_instructor => 'Instructeur';

  @override
  String get courses_section_notes => 'Notities';

  @override
  String get courses_section_requirements => 'Vereisten';

  @override
  String get courses_section_trainingDives => 'Trainingsduiken';

  @override
  String get courses_status_completed => 'Voltooid';

  @override
  String courses_status_daysSinceStart(Object days) {
    return '$days dagen sinds start';
  }

  @override
  String courses_status_durationDays(Object days) {
    return '$days dagen';
  }

  @override
  String get courses_status_inProgress => 'Bezig';

  @override
  String courses_status_semanticLabel(Object status, Object duration) {
    return '$status, $duration';
  }

  @override
  String courses_template_addsCount(int count) {
    return 'Voegt $count vereisten toe';
  }

  @override
  String get courses_summary_overview => 'Overzicht';

  @override
  String get courses_summary_quickActions => 'Snelle acties';

  @override
  String get courses_summary_recentCourses => 'Recente cursussen';

  @override
  String get courses_summary_selectHint =>
      'Selecteer een cursus uit de lijst om details te bekijken';

  @override
  String get courses_summary_title => 'Trainingscursussen';

  @override
  String get courses_summary_total => 'Totaal';

  @override
  String get courses_title => 'Trainingscursussen';

  @override
  String get courses_title_edit => 'Cursus bewerken';

  @override
  String get courses_title_new => 'Nieuwe cursus';

  @override
  String get courses_title_singular => 'Cursus';

  @override
  String get courses_validation_nameRequired => 'Voer een cursusnaam in';

  @override
  String get dashboard_activeCourses_title => 'Lopende cursussen';

  @override
  String get dashboard_activity_daySinceDiving => 'Dag sinds laatste duik';

  @override
  String get dashboard_activity_daysSinceDiving => 'Dagen sinds laatste duik';

  @override
  String dashboard_activity_diveInYear(Object year) {
    return 'Duik in $year';
  }

  @override
  String get dashboard_activity_diveThisMonth => 'Duik deze maand';

  @override
  String dashboard_activity_divesInYear(Object year) {
    return 'Duiken in $year';
  }

  @override
  String get dashboard_activity_divesThisMonth => 'Duiken deze maand';

  @override
  String get dashboard_activity_error => 'Fout';

  @override
  String get dashboard_activity_lastDive => 'Laatste duik';

  @override
  String get dashboard_activity_loading => 'Laden';

  @override
  String get dashboard_activity_noDivesYet => 'Nog geen duiken';

  @override
  String get dashboard_activity_today => 'Vandaag!';

  @override
  String get dashboard_alerts_actionUpdate => 'Bijwerken';

  @override
  String get dashboard_alerts_actionView => 'Bekijken';

  @override
  String get dashboard_alerts_checkInsuranceExpiry =>
      'Controleer de vervaldatum van uw verzekering';

  @override
  String get dashboard_alerts_daysOverdueOne => '1 dag te laat';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return '$count dagen te laat';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => 'Binnen 1 dag';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return 'Binnen $count dagen';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return 'Onderhoud $name gepland';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return 'Onderhoud $name achterstallig';
  }

  @override
  String get dashboard_alerts_insuranceExpired => 'Verzekering verlopen';

  @override
  String get dashboard_alerts_insuranceExpiredGeneric =>
      'Uw duikverzekering is verlopen';

  @override
  String dashboard_alerts_insuranceExpiredProvider(Object provider) {
    return '$provider verlopen';
  }

  @override
  String dashboard_alerts_insuranceExpiresDate(Object date) {
    return 'Verloopt op $date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon =>
      'Verzekering verloopt binnenkort';

  @override
  String get dashboard_alerts_sectionTitle => 'Meldingen & Herinneringen';

  @override
  String get dashboard_alerts_serviceDueToday => 'Onderhoud vandaag gepland';

  @override
  String get dashboard_alerts_serviceIntervalReached =>
      'Onderhoudsinterval bereikt';

  @override
  String get dashboard_defaultDiverName => 'Duiker';

  @override
  String get dashboard_greeting_afternoon => 'Goedemiddag';

  @override
  String get dashboard_greeting_evening => 'Goedenavond';

  @override
  String get dashboard_greeting_morning => 'Goedemorgen';

  @override
  String dashboard_greeting_withName(Object greeting, Object name) {
    return '$greeting, $name!';
  }

  @override
  String dashboard_greeting_withoutName(Object greeting) {
    return '$greeting!';
  }

  @override
  String get dashboard_hero_divesLoggedOne => '1 duik gelogd';

  @override
  String dashboard_hero_divesLoggedOther(Object count) {
    return '$count duiken gelogd';
  }

  @override
  String get dashboard_hero_divesTotalOne => '1 duik';

  @override
  String dashboard_hero_divesTotalOther(Object count) {
    return '$count duiken';
  }

  @override
  String get dashboard_hero_error => 'Klaar om de diepte te verkennen?';

  @override
  String dashboard_hero_hoursUnderwater(Object hours) {
    return '$hours uur onder water';
  }

  @override
  String get dashboard_hero_loading => 'Uw duikstatistieken laden...';

  @override
  String dashboard_hero_minutesUnderwater(Object minutes) {
    return '$minutes minuten onder water';
  }

  @override
  String get dashboard_hero_noDives => 'Klaar om uw eerste duik te loggen?';

  @override
  String get dashboard_hero_divesLoggedLabel => 'duiken gelogd';

  @override
  String get dashboard_hero_hoursUnderwaterLabel => 'uren onder water';

  @override
  String get dashboard_hero_daysSinceLabel => 'dagen sinds laatste duik';

  @override
  String get dashboard_hero_thisMonthLabel => 'deze maand';

  @override
  String get dashboard_hero_thisYearLabel => 'duiken dit jaar';

  @override
  String get dashboard_hero_todayLabel => 'vandaag!';

  @override
  String get dashboard_hero_noDivesLabel => 'nog geen duiken';

  @override
  String get dashboard_hero_diverFallbackName => 'Duiker';

  @override
  String get dashboard_hero_statDives => 'duiken';

  @override
  String get dashboard_hero_statHours => 'uur';

  @override
  String get dashboard_hero_statSites => 'stekken';

  @override
  String get dashboard_hero_statCountries => 'landen';

  @override
  String dashboard_activityStats_divesInYear(String year) {
    return 'duiken in $year';
  }

  @override
  String get dashboard_semantics_statsBar => 'Samenvatting duikstatistieken';

  @override
  String get dashboard_gauges_addGear => 'Uitrusting toevoegen';

  @override
  String dashboard_gauges_gearOk(String name) {
    return '$name OK';
  }

  @override
  String dashboard_gauges_gearDueIn(String name, int days) {
    return '$name over ${days}d aan onderhoud toe';
  }

  @override
  String dashboard_gauges_gearOverdue(String name) {
    return '$name over tijd';
  }

  @override
  String get dashboard_gauges_insuranceOk => 'Verzekering OK';

  @override
  String dashboard_gauges_insuranceExpires(String date) {
    return 'Verzekering verloopt $date';
  }

  @override
  String get dashboard_gauges_insuranceExpired => 'Verzekering verlopen';

  @override
  String get dashboard_gauges_noInsurance => 'Geen verzekering geregistreerd';

  @override
  String get dashboard_gauges_noFlyClear => 'Vliegverbod 0:00';

  @override
  String dashboard_gauges_flightWindow(String hours, String minutes) {
    return 'Duikvenster $hours:$minutes';
  }

  @override
  String get dashboard_gauges_flightWindowClosed =>
      'Niet meer duiken vóór de vlucht';

  @override
  String dashboard_gauges_noFlyRemaining(String hours, String minutes) {
    return 'Vliegverbod $hours:$minutes';
  }

  @override
  String dashboard_gauges_lastDiveDays(int days) {
    return 'Laatste duik ${days}d geleden';
  }

  @override
  String get dashboard_gauges_lastDiveToday => 'Vandaag gedoken';

  @override
  String get dashboard_gauges_noDivesYet => 'Nog geen duiken';

  @override
  String get settings_homeChips_pageTitle => 'Startscherm';

  @override
  String get settings_homeChips_description =>
      'Kies welke statuschips bovenaan het tabblad Start verschijnen.';

  @override
  String get settings_homeChips_sectionTitle => 'Statuschips';

  @override
  String get settings_homeCards_sectionTitle => 'Startkaarten';

  @override
  String get settings_homeCards_description =>
      'Kies welke kaarten op het tabblad Start verschijnen en sleep ze om de volgorde te wijzigen.';

  @override
  String get settings_homeCards_autoHides =>
      'Wordt automatisch verborgen wanneer leeg';

  @override
  String get settings_homeCards_resetToDefault => 'Standaardwaarden herstellen';

  @override
  String get settings_homeCards_resetDialog_title =>
      'Startindeling herstellen?';

  @override
  String get settings_homeCards_resetDialog_message =>
      'Herstelt de standaardvolgorde van de kaarten en toont ze allemaal weer.';

  @override
  String get settings_homeCards_resetDialog_cancel => 'Annuleren';

  @override
  String get settings_homeCards_resetDialog_confirm => 'Herstellen';

  @override
  String get settings_homeCards_card_hero => 'Welkomstkop';

  @override
  String get settings_homeCards_card_gaugeStrip => 'Statuschips';

  @override
  String get settings_homeCards_card_preDive => 'Pre-dive checklist';

  @override
  String get settings_homeCards_card_recentDives => 'Recente duiken';

  @override
  String get settings_homeCards_card_quickActions => 'Snelle acties';

  @override
  String get settings_homeCards_card_milestones => 'Mijlpalen';

  @override
  String get settings_homeCards_card_photoRibbon => 'Recente media';

  @override
  String get settings_homeCards_card_onThisDay => 'Op deze dag';

  @override
  String get settings_homeCards_card_yearInReview => 'Jaaroverzicht';

  @override
  String get settings_homeCards_card_activeCourses => 'Cursusvoortgang';

  @override
  String get settings_homeCards_card_recentSitesMap =>
      'Kaart met recente duikstekken';

  @override
  String get dashboard_allHidden_message => 'Alle startkaarten zijn verborgen.';

  @override
  String get dashboard_allHidden_customize => 'Start aanpassen';

  @override
  String get settings_homeChips_flightWindow => 'Duikvenster voor vlucht';

  @override
  String get settings_homeChips_gear => 'Uitrustingsonderhoud';

  @override
  String get settings_homeChips_insurance => 'Verzekering';

  @override
  String get settings_homeChips_noFly => 'Vliegverbod-timer';

  @override
  String get settings_homeChips_lastDive => 'Duikactualiteit';

  @override
  String get settings_homeChips_certifications => 'Verloop van certificeringen';

  @override
  String get settings_homeChips_trip => 'Aankomende reis';

  @override
  String get settings_homeChips_checklist => 'Actieve checklist';

  @override
  String get settings_homeChips_course => 'Cursusvoortgang';

  @override
  String get settings_homeChips_uploads => 'Media-uploads';

  @override
  String get settings_homeChips_backup => 'Back-upleeftijd';

  @override
  String get settings_homeChips_sync => 'Synchronisatiestatus';

  @override
  String get settings_homeChips_dataQuality => 'Datakwaliteit';

  @override
  String dashboard_gauges_certsExpiring(int count) {
    return '$count certificeringen verlopen bijna';
  }

  @override
  String dashboard_gauges_tripCountdown(String name, int days) {
    return '$name over ${days}d';
  }

  @override
  String get dashboard_gauges_checklistActive => 'Checklist actief';

  @override
  String dashboard_gauges_courseProgress(String name, int done, int total) {
    return '$name: $done/$total';
  }

  @override
  String dashboard_gauges_uploadsPending(int count) {
    return '$count uploads in wachtrij';
  }

  @override
  String get dashboard_gauges_backupNone => 'Nog geen back-up';

  @override
  String get dashboard_gauges_backupToday => 'Vandaag geback-upt';

  @override
  String dashboard_gauges_backupDays(int days) {
    return 'Back-up ${days}d geleden';
  }

  @override
  String dashboard_gauges_syncPending(int count) {
    return '$count niet gesynchroniseerd';
  }

  @override
  String get dashboard_gauges_synced => 'Gesynchroniseerd';

  @override
  String dashboard_gauges_dataIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dataproblemen',
      one: '1 dataprobleem',
    );
    return '$_temp0';
  }

  @override
  String get dashboard_gauges_retry =>
      'Status niet beschikbaar - tik om opnieuw te proberen';

  @override
  String get dashboard_urgent_title => 'Vereist aandacht';

  @override
  String get dashboard_media_title => 'Recente media';

  @override
  String get dashboard_recentSites_title => 'Recente stekken';

  @override
  String get dashboard_yearInReview_title => 'Dit jaar';

  @override
  String dashboard_yearInReview_divesVs(int count, int previous) {
    return '$count duiken (vs $previous vorig jaar)';
  }

  @override
  String dashboard_yearInReview_hours(String hours) {
    return '$hours uur onder water';
  }

  @override
  String dashboard_yearInReview_maxDepth(String depth) {
    return 'Diepste: $depth';
  }

  @override
  String get dashboard_onThisDay_title => 'Op deze dag';

  @override
  String dashboard_onThisDay_entry(String year, String site) {
    return '$year - $site';
  }

  @override
  String get dashboard_milestones_title => 'Mijlpalen';

  @override
  String dashboard_milestones_nextDive(int remaining, int milestone) {
    return 'Nog $remaining duiken tot nr. $milestone';
  }

  @override
  String dashboard_milestones_certYears(String name, int years, String month) {
    return '$name: $years jaar in $month';
  }

  @override
  String get dashboard_personalRecords_coldest => 'Koudste';

  @override
  String get dashboard_personalRecords_deepest => 'Diepste';

  @override
  String get dashboard_personalRecords_longest => 'Langste';

  @override
  String get dashboard_personalRecords_sectionTitle => 'Persoonlijke records';

  @override
  String get dashboard_personalRecords_warmest => 'Warmste';

  @override
  String get dashboard_quickActions_addSite => 'Stek toevoegen';

  @override
  String get dashboard_quickActions_addSiteTooltip =>
      'Een nieuwe duikstek toevoegen';

  @override
  String get dashboard_quickActions_logDive => 'Duik loggen';

  @override
  String get dashboard_quickActions_logDiveTooltip => 'Een nieuwe duik loggen';

  @override
  String get dashboard_quickActions_planDive => 'Duik plannen';

  @override
  String get dashboard_quickActions_planDiveTooltip =>
      'Een nieuwe duik plannen';

  @override
  String get dashboard_quickActions_sectionTitle => 'Snelle acties';

  @override
  String get dashboard_quickActions_statistics => 'Statistieken';

  @override
  String get dashboard_quickActions_statisticsTooltip =>
      'Duikstatistieken bekijken';

  @override
  String get dashboard_quickStats_countries => 'Landen';

  @override
  String get dashboard_quickStats_countriesSubtitle => 'bezocht';

  @override
  String get dashboard_quickStats_sectionTitle => 'In een oogopslag';

  @override
  String get dashboard_quickStats_species => 'Soorten';

  @override
  String get dashboard_quickStats_speciesSubtitle => 'ontdekt';

  @override
  String get dashboard_quickStats_topBuddy => 'Vaste buddy';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count duiken';
  }

  @override
  String get dashboard_recentDives_empty => 'Nog geen duiken gelogd';

  @override
  String get dashboard_recentDives_errorLoading => 'Laden van duiken mislukt';

  @override
  String get dashboard_recentDives_latestProfileTitle => 'Laatste duikprofiel';

  @override
  String get dashboard_recentDives_noProfileData =>
      'Geen profielgegevens voor deze duik';

  @override
  String get dashboard_recentDives_profileLoadError =>
      'Kan het duikprofiel niet laden';

  @override
  String dashboard_recentDives_profileMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get dashboard_recentDives_logFirst => 'Log uw eerste duik';

  @override
  String get dashboard_recentDives_sectionTitle => 'Recente duiken';

  @override
  String get dashboard_recentDives_viewAll => 'Alles bekijken';

  @override
  String get dashboard_recentDives_viewAllTooltip => 'Alle duiken bekijken';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count actieve meldingen';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives =>
      'Fout: Laden van recente duiken mislukt';

  @override
  String get dashboard_semantics_errorLoadingStatistics =>
      'Fout: Laden van statistieken mislukt';

  @override
  String get dashboard_semantics_greetingBanner =>
      'Dashboard begroetingsbanner';

  @override
  String get dashboard_stats_errorLoadingStatistics =>
      'Laden van statistieken mislukt';

  @override
  String get dashboard_stats_hoursLogged => 'Uren gelogd';

  @override
  String get dashboard_stats_maxDepth => 'Max diepte';

  @override
  String get dashboard_stats_sitesVisited => 'Bezochte stekken';

  @override
  String get dashboard_stats_totalDives => 'Totaal duiken';

  @override
  String get decoCalculator_addToPlanner => 'Toevoegen aan planner';

  @override
  String decoCalculator_bottomTimeSemantics(Object time) {
    return 'Bodemtijd: $time minuten';
  }

  @override
  String get decoCalculator_createPlanTooltip =>
      'Maak een duikplan aan met huidige parameters';

  @override
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  ) {
    return 'Plan aangemaakt: $depth$depthSymbol voor ${time}min op $gasMixName';
  }

  @override
  String get decoCalculator_customMixTrimix => 'Aangepast mengsel (Trimix)';

  @override
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol) {
    return 'Diepte: $depth $depthSymbol';
  }

  @override
  String get decoCalculator_diveParameters => 'Duikparameters';

  @override
  String get decoCalculator_endCaution => 'Let op';

  @override
  String get decoCalculator_endDanger => 'Gevaar';

  @override
  String get decoCalculator_endSafe => 'Veilig';

  @override
  String get decoCalculator_field_bottomTime => 'Bodemtijd';

  @override
  String get decoCalculator_field_depth => 'Diepte';

  @override
  String get decoCalculator_field_gasMix => 'Gasmengsel';

  @override
  String get decoCalculator_gasSafety => 'Gasveiligheid';

  @override
  String get decoCalculator_hideCustomMix => 'Aangepast mengsel verbergen';

  @override
  String get decoCalculator_hideCustomMixSemantics =>
      'Aangepast gasmengsel verbergen';

  @override
  String get decoCalculator_modExceeded => 'MOD overschreden';

  @override
  String get decoCalculator_modSafe => 'MOD veilig';

  @override
  String get decoCalculator_ppO2Caution => 'ppO2 let op';

  @override
  String get decoCalculator_ppO2Danger => 'ppO2 gevaar';

  @override
  String get decoCalculator_ppO2Hypoxic => 'ppO2 hypoxisch';

  @override
  String get decoCalculator_ppO2Safe => 'ppO2 veilig';

  @override
  String get decoCalculator_resetToDefaults => 'Standaardwaarden herstellen';

  @override
  String get decoCalculator_showCustomMixSemantics =>
      'Aangepast gasmengsel tonen';

  @override
  String decoCalculator_timeValueMin(Object time) {
    return '$time min';
  }

  @override
  String get decoCalculator_title => 'Deco calculator';

  @override
  String get decoCalculator_waterType => 'Watertype';

  @override
  String get decoCalculator_waterType_standard => 'Standaard';

  @override
  String diveCenters_accessibility_markerLabel(Object name) {
    return 'Duikcentrum: $name';
  }

  @override
  String get diveCenters_accessibility_selected => 'geselecteerd';

  @override
  String diveCenters_accessibility_viewDetails(Object name) {
    return 'Bekijk details voor $name';
  }

  @override
  String get diveCenters_accessibility_viewDives =>
      'Bekijk duiken met dit centrum';

  @override
  String get diveCenters_accessibility_viewFullscreenMap =>
      'Bekijk volledig scherm kaart';

  @override
  String diveCenters_accessibility_viewSavedCenter(Object name) {
    return 'Bekijk opgeslagen duikcentrum $name';
  }

  @override
  String get diveCenters_action_addCenter => 'Centrum toevoegen';

  @override
  String get diveCenters_action_addNew => 'Nieuw toevoegen';

  @override
  String get diveCenters_action_clearRating => 'Wissen';

  @override
  String get diveCenters_action_gettingLocation => 'Ophalen...';

  @override
  String get diveCenters_action_import => 'Importeren';

  @override
  String get diveCenters_action_importToMyCenters =>
      'Importeren naar mijn centra';

  @override
  String get diveCenters_action_lookingUp => 'Opzoeken...';

  @override
  String get diveCenters_action_lookupFromAddress => 'Opzoeken vanaf adres';

  @override
  String get diveCenters_action_pickFromMap => 'Kiezen op kaart';

  @override
  String get diveCenters_action_retry => 'Opnieuw proberen';

  @override
  String get diveCenters_action_settings => 'Instellingen';

  @override
  String get diveCenters_action_useMyLocation => 'Gebruik mijn locatie';

  @override
  String get diveCenters_action_view => 'Bekijken';

  @override
  String diveCenters_detail_divesLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken gelogd',
      one: '1 duik gelogd',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_detail_divesWithCenter => 'Duiken met dit centrum';

  @override
  String get diveCenters_detail_noDivesLogged => 'Nog geen duiken gelogd';

  @override
  String diveCenters_dialog_deleteMessage(Object name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen?';
  }

  @override
  String get diveCenters_dialog_deleteTitle => 'Duikcentrum verwijderen';

  @override
  String get diveCenters_dialog_discard => 'Verwerpen';

  @override
  String get diveCenters_dialog_discardMessage =>
      'Je hebt niet-opgeslagen wijzigingen. Weet je zeker dat je deze wilt verwerpen?';

  @override
  String get diveCenters_dialog_discardTitle => 'Wijzigingen verwerpen?';

  @override
  String get diveCenters_dialog_keepEditing => 'Doorgaan met bewerken';

  @override
  String get diveCenters_empty_button => 'Voeg je eerste duikcentrum toe';

  @override
  String get diveCenters_empty_subtitle =>
      'Voeg je favoriete duikwinkels en operators toe';

  @override
  String get diveCenters_empty_title => 'Nog geen duikcentra';

  @override
  String diveCenters_error_generic(Object error) {
    return 'Fout: $error';
  }

  @override
  String get diveCenters_error_geocodeFailed =>
      'Kon geen coördinaten vinden voor dit adres';

  @override
  String get diveCenters_error_importFailed => 'Duikcentrum importeren mislukt';

  @override
  String diveCenters_error_loading(Object error) {
    return 'Fout bij laden duikcentra: $error';
  }

  @override
  String get diveCenters_error_locationPermission =>
      'Kan locatie niet ophalen. Controleer toegangsrechten.';

  @override
  String get diveCenters_error_locationUnavailable =>
      'Kan locatie niet ophalen. Locatieservices zijn mogelijk niet beschikbaar.';

  @override
  String get diveCenters_error_noAddressForLookup =>
      'Voer een adres in om coördinaten op te zoeken';

  @override
  String get diveCenters_error_notFound => 'Duikcentrum niet gevonden';

  @override
  String diveCenters_error_saving(Object error) {
    return 'Fout bij opslaan duikcentrum: $error';
  }

  @override
  String get diveCenters_error_unknown => 'Onbekende fout';

  @override
  String get diveCenters_field_city => 'Plaats';

  @override
  String get diveCenters_field_country => 'Land';

  @override
  String get diveCenters_field_latitude => 'Breedtegraad';

  @override
  String get diveCenters_field_longitude => 'Lengtegraad';

  @override
  String get diveCenters_field_nameRequired => 'Naam *';

  @override
  String get diveCenters_field_postalCode => 'Postcode';

  @override
  String get diveCenters_field_rating => 'Beoordeling';

  @override
  String get diveCenters_field_stateProvince => 'Staat/Provincie';

  @override
  String get diveCenters_field_street => 'Straatnaam';

  @override
  String get diveCenters_hint_addressDescription =>
      'Optioneel straatadres voor navigatie';

  @override
  String get diveCenters_hint_affiliationsDescription =>
      'Selecteer trainingsorganisaties waar dit centrum bij is aangesloten';

  @override
  String get diveCenters_hint_city => 'bijv. Phuket';

  @override
  String get diveCenters_hint_country => 'bijv. Thailand';

  @override
  String get diveCenters_hint_email => 'info@duikcentrum.nl';

  @override
  String get diveCenters_hint_gpsDescription =>
      'Kies een locatiemethode of voer coördinaten handmatig in';

  @override
  String get diveCenters_hint_importSearch =>
      'Zoek duikcentra (bijv. \"PADI\", \"Thailand\")';

  @override
  String get diveCenters_hint_latitude => 'bijv. 10.4613';

  @override
  String get diveCenters_hint_longitude => 'bijv. 99.8359';

  @override
  String get diveCenters_hint_name => 'Voer naam duikcentrum in';

  @override
  String get diveCenters_hint_notes => 'Eventuele aanvullende informatie...';

  @override
  String get diveCenters_hint_phone => '+31 20 1234567';

  @override
  String get diveCenters_hint_postalCode => 'bijv. 83100';

  @override
  String get diveCenters_hint_stateProvince => 'bijv. Phuket';

  @override
  String get diveCenters_hint_street => 'bijv. Strandweg 123';

  @override
  String get diveCenters_hint_website => 'www.duikcentrum.nl';

  @override
  String diveCenters_import_fromDatabase(Object count) {
    return 'Importeren uit database ($count)';
  }

  @override
  String diveCenters_import_myCenters(Object count) {
    return 'Mijn centra ($count)';
  }

  @override
  String get diveCenters_import_noResults => 'Geen resultaten';

  @override
  String diveCenters_import_noResultsMessage(Object query) {
    return 'Geen duikcentra gevonden voor \"$query\". Probeer een andere zoekterm.';
  }

  @override
  String get diveCenters_import_searchDescription =>
      'Zoek naar duikcentra, winkels en clubs uit onze database van operators wereldwijd.';

  @override
  String get diveCenters_import_searchError => 'Zoekfout';

  @override
  String get diveCenters_import_searchHint =>
      'Probeer te zoeken op naam, land of certificeringsorganisatie.';

  @override
  String get diveCenters_import_searchTitle => 'Zoek duikcentra';

  @override
  String get diveCenters_label_alreadyImported => 'Al geïmporteerd';

  @override
  String diveCenters_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken',
      one: '1 duik',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_label_email => 'E-mail';

  @override
  String get diveCenters_label_imported => 'Geïmporteerd';

  @override
  String get diveCenters_label_locationNotSet => 'Locatie niet ingesteld';

  @override
  String get diveCenters_label_locationUnknown => 'Locatie onbekend';

  @override
  String get diveCenters_label_phone => 'Telefoon';

  @override
  String get diveCenters_label_saved => 'Opgeslagen';

  @override
  String diveCenters_label_source(Object source) {
    return 'Bron: $source';
  }

  @override
  String get diveCenters_label_website => 'Website';

  @override
  String get diveCenters_map_addCoordinatesHint =>
      'Voeg coördinaten toe aan je duikcentra om ze op de kaart te zien';

  @override
  String get diveCenters_map_noCoordinates => 'Geen duikcentra met coördinaten';

  @override
  String get diveCenters_picker_newCenter => 'Nieuw duikcentrum';

  @override
  String get diveCenters_picker_title => 'Selecteer duikcentrum';

  @override
  String diveCenters_search_noResults(Object query) {
    return 'Geen resultaten voor \"$query\"';
  }

  @override
  String get diveCenters_search_prompt => 'Zoek duikcentra';

  @override
  String get diveCenters_section_address => 'Adres';

  @override
  String get diveCenters_section_affiliations => 'Aangesloten bij';

  @override
  String get diveCenters_section_basicInfo => 'Basisinformatie';

  @override
  String get diveCenters_section_contact => 'Contact';

  @override
  String get diveCenters_section_contactInfo => 'Contactinformatie';

  @override
  String get diveCenters_section_gpsCoordinates => 'GPS coördinaten';

  @override
  String get diveCenters_section_notes => 'Notities';

  @override
  String get diveCenters_snackbar_coordinatesFound =>
      'Coördinaten gevonden via adres';

  @override
  String get diveCenters_snackbar_copiedToClipboard =>
      'Gekopieerd naar klembord';

  @override
  String diveCenters_snackbar_imported(Object name) {
    return '\"$name\" geïmporteerd';
  }

  @override
  String get diveCenters_snackbar_locationCaptured => 'Locatie vastgelegd';

  @override
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Locatie vastgelegd (±${accuracy}m)';
  }

  @override
  String get diveCenters_snackbar_locationSelectedFromMap =>
      'Locatie geselecteerd op kaart';

  @override
  String get diveCenters_sort_title => 'Duikcentra sorteren';

  @override
  String get diveCenters_summary_countries => 'Landen';

  @override
  String get diveCenters_summary_highestRating => 'Hoogste beoordeling';

  @override
  String get diveCenters_summary_overview => 'Overzicht';

  @override
  String get diveCenters_summary_quickActions => 'Snelle acties';

  @override
  String get diveCenters_summary_recentCenters => 'Recente duikcentra';

  @override
  String get diveCenters_summary_selectPrompt =>
      'Selecteer een duikcentrum uit de lijst om details te bekijken';

  @override
  String get diveCenters_summary_totalCenters => 'Totaal centra';

  @override
  String get diveCenters_summary_withGps => 'Met GPS';

  @override
  String get diveCenters_title => 'Duikcentra';

  @override
  String get diveCenters_title_add => 'Duikcentrum toevoegen';

  @override
  String get diveCenters_title_edit => 'Duikcentrum bewerken';

  @override
  String get diveCenters_title_import => 'Duikcentrum importeren';

  @override
  String get diveCenters_tooltip_addNew => 'Nieuw duikcentrum toevoegen';

  @override
  String get diveCenters_tooltip_clearSearch => 'Zoekopdracht wissen';

  @override
  String get diveCenters_tooltip_edit => 'Duikcentrum bewerken';

  @override
  String get diveCenters_tooltip_fitAllCenters => 'Alle centra tonen';

  @override
  String get diveCenters_tooltip_listView => 'Lijstweergave';

  @override
  String get diveCenters_tooltip_mapView => 'Kaartweergave';

  @override
  String get diveCenters_tooltip_moreOptions => 'Meer opties';

  @override
  String get diveCenters_tooltip_search => 'Zoek duikcentra';

  @override
  String get diveCenters_tooltip_sort => 'Sorteren';

  @override
  String get diveCenters_validation_invalidEmail =>
      'Voer een geldig e-mailadres in';

  @override
  String get diveCenters_validation_invalidLatitude => 'Ongeldige breedtegraad';

  @override
  String get diveCenters_validation_invalidLongitude => 'Ongeldige lengtegraad';

  @override
  String get diveCenters_validation_nameRequired => 'Naam is verplicht';

  @override
  String get diveComputer_action_setFavorite => 'Instellen als favoriet';

  @override
  String diveComputer_error_generic(Object error) {
    return 'Er is een fout opgetreden: $error';
  }

  @override
  String get diveComputer_error_notFound => 'Apparaat niet gevonden';

  @override
  String get diveComputer_status_favorite => 'Favoriete computer';

  @override
  String get diveComputer_title => 'Duikcomputer';

  @override
  String diveLog_bulkDelete_confirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return 'Weet u zeker dat u $count $_temp0 wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.';
  }

  @override
  String get diveLog_bulkDelete_restored => 'Duiken hersteld';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return '$count $_temp0 verwijderd';
  }

  @override
  String get diveLog_bulkDelete_title => 'Duiken verwijderen';

  @override
  String get diveLog_bulkDelete_undo => 'Ongedaan maken';

  @override
  String get diveLog_bulkEdit_addTags => 'Tags toevoegen';

  @override
  String get diveLog_bulkEdit_addTagsDescription =>
      'Tags toevoegen aan geselecteerde duiken';

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
      other: 'duiken',
      one: 'duik',
    );
    return '$tagCount $_temp0 toegevoegd aan $diveCount $_temp1';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => 'Reis wijzigen';

  @override
  String get diveLog_bulkEdit_changeTripDescription =>
      'Geselecteerde duiken naar een reis verplaatsen';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips => 'Fout bij laden van reizen';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return 'Tags toevoegen mislukt: $error';
  }

  @override
  String diveLog_bulkEdit_failedUpdateTrip(Object error) {
    return 'Reis bijwerken mislukt: $error';
  }

  @override
  String diveLog_bulkEdit_movedToTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return '$count $_temp0 verplaatst naar reis';
  }

  @override
  String get diveLog_bulkEdit_noTagsAvailable => 'Geen tags beschikbaar.';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate =>
      'Geen tags beschikbaar. Maak eerst tags aan.';

  @override
  String get diveLog_bulkEdit_noTrip => 'Geen reis';

  @override
  String get diveLog_bulkEdit_removeFromTrip => 'Verwijderen uit reis';

  @override
  String get diveLog_bulkEdit_removeTags => 'Tags verwijderen';

  @override
  String get diveLog_bulkEdit_removeTagsDescription =>
      'Tags verwijderen van geselecteerde duiken';

  @override
  String diveLog_bulkEdit_removedFromTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return '$count $_temp0 verwijderd uit reis';
  }

  @override
  String get diveLog_bulkEdit_selectTrip => 'Reis selecteren';

  @override
  String diveLog_bulkEdit_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return '$count $_temp0 bewerken';
  }

  @override
  String get diveLog_bulkExport_csv => 'CSV';

  @override
  String get diveLog_bulkExport_csvDescription => 'Spreadsheetformaat';

  @override
  String diveLog_bulkExport_failed(Object error) {
    return 'Export mislukt: $error';
  }

  @override
  String get diveLog_bulkExport_pdf => 'PDF Logboek';

  @override
  String get diveLog_bulkExport_pdfDescription => 'Afdrukbare duiklogpagina\'s';

  @override
  String diveLog_bulkExport_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return '$count $_temp0 succesvol geëxporteerd';
  }

  @override
  String diveLog_bulkExport_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return '$count $_temp0 exporteren';
  }

  @override
  String get diveLog_bulkExport_uddf => 'UDDF';

  @override
  String get diveLog_bulkExport_uddfDescription =>
      'Universeel Duikgegevensformaat';

  @override
  String get diveLog_ccr_diluent_air => 'Lucht';

  @override
  String get diveLog_ccr_hint_loopVolume => 'bijv. 6,0';

  @override
  String get diveLog_ccr_hint_type => 'bijv. Sofnolime';

  @override
  String get diveLog_ccr_label_deco => 'Deco';

  @override
  String get diveLog_ccr_label_he => 'He';

  @override
  String get diveLog_ccr_label_highBottom => 'Hoog (bodem)';

  @override
  String get diveLog_ccr_label_loopVolume => 'Loopvolume';

  @override
  String get diveLog_ccr_label_lowDescAsc => 'Laag (Afd./Opst.)';

  @override
  String get diveLog_ccr_label_n2 => 'N₂';

  @override
  String get diveLog_ccr_label_o2 => 'O₂';

  @override
  String get diveLog_ccr_label_rated => 'Nominaal';

  @override
  String get diveLog_ccr_label_remaining => 'Resterend';

  @override
  String get diveLog_ccr_label_type => 'Type';

  @override
  String get diveLog_ccr_sectionDiluentGas => 'Diluent gas';

  @override
  String get diveLog_ccr_sectionScrubber => 'Scrubber';

  @override
  String get diveLog_ccr_sectionSetpoints => 'Setpoints (bar)';

  @override
  String get diveLog_ccr_title => 'CCR-instellingen';

  @override
  String diveLog_collapsible_semantics_collapse(Object title) {
    return 'Sectie $title inklappen';
  }

  @override
  String diveLog_collapsible_semantics_expand(Object title) {
    return 'Sectie $title uitklappen';
  }

  @override
  String get diveLog_combine_confirm => 'Samenvoegen tot één duik';

  @override
  String get diveLog_combine_dataNote =>
      'Details komen van de vroegste duik, met lege velden aangevuld vanuit latere duiken. Notities worden samengevoegd. Flessen, uitrusting, buddy\'s, tags en waarnemingen blijven allemaal behouden.';

  @override
  String get diveLog_combine_error =>
      'Kon de duiken niet samenvoegen. Er is niets gewijzigd.';

  @override
  String diveLog_combine_gapLabel(String duration) {
    return 'Oppervlakte-interval: $duration';
  }

  @override
  String get diveLog_combine_longSurfaceWarning =>
      'Een of meer oppervlakte-intervallen zijn langer dan 30 minuten. Dit kunnen aparte duiken zijn in plaats van één doorlopende duik.';

  @override
  String get diveLog_combine_mixedDivers =>
      'De geselecteerde duiken behoren tot verschillende duikers en kunnen niet worden samengevoegd.';

  @override
  String get diveLog_combine_profilePreview => 'Samengevoegd profiel';

  @override
  String diveLog_combine_previewIntro(int count) {
    return 'Deze $count duiken worden samengevoegd tot één doorlopende duik. Tussenliggende intervallen worden oppervlaktetijd.';
  }

  @override
  String diveLog_combine_resultSummary(
    String runtime,
    String maxDepth,
    String bottomTime,
  ) {
    return 'Resultaat: $runtime totaal, maximale diepte $maxDepth, bodemtijd $bottomTime';
  }

  @override
  String diveLog_combine_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return '$count $_temp0 samengevoegd';
  }

  @override
  String get diveLog_combine_title => 'Duiken samenvoegen';

  @override
  String get diveLog_combine_undoError =>
      'Kon het samenvoegen niet ongedaan maken.';

  @override
  String get diveLog_combine_undone => 'Samenvoeging ongedaan gemaakt';

  @override
  String get diveLog_computerSource_badge_primary => 'Primair';

  @override
  String get diveLog_consolidate_confirm =>
      'Bewaren als één duik met beide computers';

  @override
  String get diveLog_consolidate_error_generic =>
      'Kon de duiken niet samenvoegen. Er is niets gewijzigd.';

  @override
  String get diveLog_consolidate_error_notOverlapping =>
      'Deze duiken overlappen niet in tijd en kunnen daarom niet als dezelfde duik worden samengevoegd.';

  @override
  String get diveLog_consolidate_error_sameComputer =>
      'Deze duiken zijn afkomstig van dezelfde duikcomputer en kunnen op deze manier niet worden samengevoegd.';

  @override
  String get diveLog_consolidate_selectPrimary => 'Primaire duikcomputer';

  @override
  String get diveLog_consolidate_snackbar =>
      'Duik samengevoegd als extra computer.';

  @override
  String get diveLog_consolidate_undoError =>
      'Kon het samenvoegen niet ongedaan maken.';

  @override
  String get diveLog_consolidate_undone => 'Samenvoeging ongedaan gemaakt';

  @override
  String diveLog_mergeDialog_confirmSubtitle(String time) {
    return 'De duik om $time wordt samengevoegd met deze duik.';
  }

  @override
  String get diveLog_mergeDialog_confirmTitle => 'Samenvoegen bevestigen';

  @override
  String get diveLog_mergeDialog_empty =>
      'Geen andere duiken gevonden op deze dag.';

  @override
  String get diveLog_mergeDialog_explanation =>
      'Het profiel, de flessen, drukken, gebeurtenissen, tags, buddy\'s en waarnemingen van deze duik worden samengevoegd in deze duik als extra computerbron. Deze actie kan ongedaan worden gemaakt met \'Computer loskoppelen\'.';

  @override
  String diveLog_mergeDialog_loadError(String error) {
    return 'Fout bij het laden van duiken: $error';
  }

  @override
  String get diveLog_mergeDialog_merge => 'Samenvoegen';

  @override
  String get diveLog_mergeDialog_next => 'Volgende';

  @override
  String get diveLog_mergeDialog_subtitle =>
      'Selecteer een duik van dezelfde dag om samen te voegen als extra computer.';

  @override
  String get diveLog_mergeDialog_title => 'Samenvoegen met een andere duik';

  @override
  String get diveLog_mergeDialog_whatThisDoes => 'Wat dit doet';

  @override
  String get diveLog_computerSheet_description =>
      'Kies vanaf welk computerprofiel je wilt bewerken.';

  @override
  String get diveLog_computerSheet_title => 'Startprofiel kiezen';

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return 'Gem.: $depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => 'Basis';

  @override
  String get diveLog_cylinderSac_noSac => 'SAC: --';

  @override
  String get diveLog_cylinderSac_tooltip_aiData =>
      'AI-zendergegevens gebruikt voor hogere nauwkeurigheid';

  @override
  String get diveLog_cylinderSac_tooltip_basicData =>
      'Berekend op basis van begin-/einddruk';

  @override
  String get diveLog_deco_badge_deco => 'DECO';

  @override
  String get diveLog_deco_badge_noDeco => 'GEEN DECO';

  @override
  String get diveLog_deco_label_ceiling => 'Plafond';

  @override
  String get diveLog_deco_label_leading => 'Leidend';

  @override
  String get diveLog_deco_label_gf99 => 'GF99';

  @override
  String get diveLog_deco_label_surfGf => 'SurfGF';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_time => 'Tijd';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String diveLog_deco_gf_chip(Object low, Object high) {
    return 'GF: $low/$high';
  }

  @override
  String diveLog_deco_gf_chipFromSettings(Object low, Object high) {
    return 'GF: $low/$high · jouw instellingen';
  }

  @override
  String diveLog_deco_gf_chipRecordedAlgorithm(
    Object algorithm,
    Object low,
    Object high,
  ) {
    return '$algorithm · geanalyseerd met GF $low/$high';
  }

  @override
  String diveLog_deco_gf_semantics(Object low, Object high) {
    return 'Gradiëntfactoren: laag $low, hoog $high';
  }

  @override
  String get diveLog_deco_gf_tooltipFromSettings =>
      'Deze duikcomputer heeft zijn gradiëntfactoren niet vastgelegd, dus deze duik wordt geanalyseerd met die uit jouw instellingen.';

  @override
  String diveLog_deco_gf_tooltipRecordedAlgorithm(Object algorithm) {
    return 'Deze duik is berekend met $algorithm, dat geen gradiëntfactoren gebruikt. Submersion analyseert hem met die uit jouw instellingen.';
  }

  @override
  String get diveLog_deco_sectionDecoStops => 'Decostops';

  @override
  String get diveLog_deco_sectionTissueLoading => 'Weefselbelading';

  @override
  String get diveLog_deco_semantics_notRequired => 'Geen decompressie vereist';

  @override
  String get diveLog_deco_semantics_required => 'Decompressie vereist';

  @override
  String get diveLog_deco_tissueFast => 'Snel';

  @override
  String get diveLog_deco_tissueSlow => 'Langzaam';

  @override
  String get diveLog_deco_title => 'Decostatus';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return 'Totaal: $time';
  }

  @override
  String get diveLog_delete_cancel => 'Annuleren';

  @override
  String get diveLog_delete_confirm =>
      'Deze actie kan niet ongedaan worden gemaakt. De duik en alle bijbehorende gegevens (profiel, flessen, waarnemingen) worden permanent verwijderd.';

  @override
  String get diveLog_delete_delete => 'Verwijderen';

  @override
  String get diveLog_delete_title => 'Duik verwijderen?';

  @override
  String get diveLog_detail_appBar => 'Duikdetails';

  @override
  String get diveLog_detail_badge_critical => 'KRITIEK';

  @override
  String get diveLog_detail_badge_deco => 'DECO';

  @override
  String get diveLog_detail_badge_noDeco => 'GEEN DECO';

  @override
  String get diveLog_detail_badge_warning => 'WAARSCHUWING';

  @override
  String diveLog_detail_buddyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'buddy\'s',
      one: 'buddy',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_button_playback => 'Afspelen';

  @override
  String get diveLog_detail_button_rangeAnalysis => 'Bereikstatistieken';

  @override
  String get diveLog_detail_button_showEnd => 'Toon einde';

  @override
  String get diveLog_detail_captureSignature =>
      'Handtekening instructeur vastleggen';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return 'Om $timestamp';
  }

  @override
  String diveLog_detail_collapsed_atTimeInfo(
    Object timestamp,
    Object baseInfo,
  ) {
    return 'Om $timestamp • $baseInfo';
  }

  @override
  String diveLog_detail_collapsed_ceiling(Object value) {
    return 'Plafond: $value';
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
    return 'CNS: $cns • Max ppO₂: $maxPpO2 • Om $timestamp: $ppO2 bar';
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
  String get diveLog_detail_errorLoading => 'Fout bij laden van duik';

  @override
  String get diveLog_detail_label_airTemp => 'Luchttemp.';

  @override
  String get diveLog_detail_label_avgDepth => 'Gem. diepte';

  @override
  String get diveLog_detail_label_buddy => 'Buddy';

  @override
  String get diveLog_detail_label_currentDirection => 'Stromingsrichting';

  @override
  String get diveLog_detail_label_currentStrength => 'Stromingssterkte';

  @override
  String get diveLog_detail_label_diveComputer => 'Duikcomputer';

  @override
  String get diveLog_detail_label_serialNumber => 'Serienummer';

  @override
  String get diveLog_detail_label_firmwareVersion => 'Firmwareversie';

  @override
  String get diveLog_detail_label_diveMaster => 'Divemaster';

  @override
  String get diveLog_detail_label_diveType => 'Duiktype';

  @override
  String get diveLog_detail_label_elevation => 'Hoogte';

  @override
  String get diveLog_detail_label_entry => 'Instap:';

  @override
  String get diveLog_detail_label_entryMethod => 'Instapmethode';

  @override
  String get diveLog_detail_label_exit => 'Uitstap:';

  @override
  String get diveLog_detail_label_exitMethod => 'Uitstapmethode';

  @override
  String get diveLog_detail_label_gradientFactors => 'Gradientfactoren';

  @override
  String get diveLog_detail_label_height => 'Hoogte';

  @override
  String get diveLog_detail_label_highTide => 'Hoog water';

  @override
  String get diveLog_detail_label_lowTide => 'Laag water';

  @override
  String get diveLog_detail_label_ppO2AtPoint => 'ppO₂ op geselecteerd punt:';

  @override
  String get diveLog_detail_label_rateOfChange => 'Wijzigingssnelheid';

  @override
  String get diveLog_detail_label_sacRate => 'SAC-verbruik';

  @override
  String get diveLog_detail_label_state => 'Status';

  @override
  String get diveLog_detail_label_surfaceInterval => 'Oppervlakte-interval';

  @override
  String get diveLog_detail_label_surfacePressure => 'Oppervlaktedruk';

  @override
  String get diveLog_detail_label_swellHeight => 'Deiningsahoogte';

  @override
  String get diveLog_detail_label_total => 'Totaal:';

  @override
  String get diveLog_detail_label_visibility => 'Zicht';

  @override
  String get diveLog_detail_label_waterType => 'Watertype';

  @override
  String get diveLog_detail_menu_delete => 'Verwijderen';

  @override
  String get diveLog_detail_menu_export => 'Exporteren';

  @override
  String get diveLog_detail_menu_openFullPage => 'Volledige pagina openen';

  @override
  String get diveLog_detail_noNotes => 'Geen notities voor deze duik.';

  @override
  String get diveLog_detail_notFound => 'Duik niet gevonden';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count punten';
  }

  @override
  String get diveLog_detail_section_altitudeDive => 'Hoogteduik';

  @override
  String get diveLog_detail_section_buddies => 'Buddy\'s';

  @override
  String get diveLog_detail_section_conditions => 'Omstandigheden';

  @override
  String get diveLog_detail_section_customFields => 'Custom Fields';

  @override
  String get diveLog_detail_section_decoStatus => 'Decostatus';

  @override
  String get diveLog_detail_section_details => 'Details';

  @override
  String get diveLog_detail_section_diveProfile => 'Duikprofiel';

  @override
  String get diveLog_detail_section_equipment => 'Uitrusting';

  @override
  String get diveLog_detail_section_marineLife => 'Onderwaterleven';

  @override
  String get diveLog_detail_section_notes => 'Notities';

  @override
  String get diveLog_detail_section_oxygenToxicity => 'Zuurstoftoxiciteit';

  @override
  String get diveLog_detail_section_sacRateBySegment =>
      'SAC-verbruik per segment';

  @override
  String get diveLog_detail_section_tags => 'Tags';

  @override
  String get diveLog_detail_section_cylinders => 'Flessen';

  @override
  String get diveLog_detail_section_tide => 'Getij';

  @override
  String get diveLog_detail_section_trainingSignature =>
      'Trainingshandtekening';

  @override
  String get diveLog_detail_section_weight => 'Gewicht';

  @override
  String get diveLog_detail_signatureDescription =>
      'Tik om instructeurverificatie toe te voegen voor deze trainingsduik';

  @override
  String get diveLog_detail_soloDive =>
      'Soloduik of geen buddy\'s geregistreerd';

  @override
  String diveLog_detail_speciesCount(Object count) {
    return '$count soorten';
  }

  @override
  String get diveLog_detail_stat_bottomTime => 'Bodemtijd';

  @override
  String get diveLog_detail_stat_maxDepth => 'Max diepte';

  @override
  String get diveLog_detail_stat_runtime => 'Looptijd';

  @override
  String get diveLog_detail_stat_waterTemp => 'Watertemp.';

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
  String get diveLog_detail_tideCalculated =>
      'Berekend op basis van getijmodel';

  @override
  String get diveLog_detail_tooltip_addToFavorites =>
      'Aan favorieten toevoegen';

  @override
  String get diveLog_detail_tooltip_edit => 'Bewerken';

  @override
  String get diveLog_detail_tooltip_editDive => 'Duik bewerken';

  @override
  String get diveLog_detail_tooltip_previousDive => 'Previous dive';

  @override
  String get diveLog_detail_tooltip_nextDive => 'Next dive';

  @override
  String get diveLog_detail_tooltip_exportProfileImage =>
      'Profiel exporteren als afbeelding';

  @override
  String get diveLog_detail_tooltip_removeFromFavorites =>
      'Uit favorieten verwijderen';

  @override
  String get diveLog_detail_tooltip_viewFullscreen =>
      'Volledig scherm bekijken';

  @override
  String get diveLog_detail_viewSite => 'Duikstek bekijken';

  @override
  String get diveLog_diveMode_ccrDescription =>
      'Gesloten circuit rebreather met constante ppO₂';

  @override
  String get diveLog_diveMode_gaugeDescription =>
      'Alleen diepte en tijd; geen gas- of decompressietracking';

  @override
  String get diveLog_diveMode_ocDescription =>
      'Standaard open circuit duiken met flessen';

  @override
  String get diveLog_diveMode_scrDescription =>
      'Semi-gesloten rebreather met variabele ppO₂';

  @override
  String get diveLog_diveMode_title => 'Duikmodus';

  @override
  String get diveLog_editSighting_count => 'Aantal';

  @override
  String get diveLog_editSighting_notes => 'Notities';

  @override
  String get diveLog_editSighting_notesHint => 'Grootte, gedrag, locatie...';

  @override
  String get diveLog_editSighting_remove => 'Verwijderen';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return '$name verwijderen uit deze duik?';
  }

  @override
  String get diveLog_editSighting_removeTitle => 'Waarneming verwijderen?';

  @override
  String get diveLog_editSighting_save => 'Wijzigingen opslaan';

  @override
  String get diveLog_edit_add => 'Toevoegen';

  @override
  String get diveLog_edit_addCustomField => 'Add Field';

  @override
  String get diveLog_edit_addTank => 'Fles toevoegen';

  @override
  String get diveLog_edit_addWeightEntry => 'Gewicht toevoegen';

  @override
  String diveLog_edit_addedGps(Object name) {
    return 'GPS toegevoegd aan $name';
  }

  @override
  String get diveLog_edit_appBarEdit => 'Duik bewerken';

  @override
  String get diveLog_edit_appBarNew => 'Duik loggen';

  @override
  String get diveLog_edit_cancel => 'Annuleren';

  @override
  String get diveLog_edit_clearAllEquipment => 'Alles wissen';

  @override
  String diveLog_edit_createdSite(Object name) {
    return 'Duikstek aangemaakt: $name';
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
    return 'Duur: $minutes min';
  }

  @override
  String get diveLog_edit_equipmentHint =>
      'Tik op \"Set gebruiken\" of \"Toevoegen\" om uitrusting te selecteren';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return 'Fout bij laden van duiktypes: $error';
  }

  @override
  String get diveLog_edit_gettingLocation => 'Locatie ophalen...';

  @override
  String get diveLog_edit_group_buddies => 'Buddy\'s';

  @override
  String get diveLog_edit_group_conditions => 'Omstandigheden';

  @override
  String get diveLog_edit_group_experience => 'Ervaring';

  @override
  String get diveLog_edit_group_gasGear => 'Gas & uitrusting';

  @override
  String get diveLog_edit_group_theDive => 'De duik';

  @override
  String get diveLog_edit_group_trip => 'Reis';

  @override
  String get diveLog_edit_headerNew => 'Nieuwe duik loggen';

  @override
  String get diveLog_edit_invite_buddies => 'Buddy\'s toevoegen';

  @override
  String get diveLog_edit_invite_conditions =>
      'Omstandigheden toevoegen - water, zicht, weer';

  @override
  String get diveLog_edit_invite_experience =>
      'Beoordeling, waarnemingen, notities of tags toevoegen';

  @override
  String get diveLog_edit_invite_gasGear =>
      'Gas & uitrusting toevoegen - modus, flessen, uitrusting, lood';

  @override
  String get diveLog_edit_invite_trip => 'Reis of duikcentrum toevoegen';

  @override
  String get diveLog_edit_label_airTemp => 'Luchttemp.';

  @override
  String get diveLog_edit_label_altitude => 'Hoogte';

  @override
  String get diveLog_edit_label_avgDepth => 'Gem. diepte';

  @override
  String get diveLog_edit_label_bottomTime => 'Bodemtijd';

  @override
  String get diveLog_edit_label_currentDirection => 'Stromingsrichting';

  @override
  String get diveLog_edit_label_currentStrength => 'Stromingssterkte';

  @override
  String get diveLog_edit_label_diveType => 'Duiktype';

  @override
  String get diveLog_edit_label_diveTypes => 'Duiktypes';

  @override
  String get diveLog_edit_label_diveNumber => 'Duik nr.';

  @override
  String get diveLog_edit_label_diveName => 'Naam';

  @override
  String get diveLog_edit_diveNamePlaceholder =>
      'Optionele naam voor deze duik';

  @override
  String get diveLog_edit_hint_diveNumber =>
      'Automatisch toegewezen als leeg gelaten';

  @override
  String get diveLog_edit_label_entryMethod => 'Instapmethode';

  @override
  String get diveLog_edit_label_exitMethod => 'Uitstapmethode';

  @override
  String get diveLog_edit_label_maxDepth => 'Max diepte';

  @override
  String get diveLog_edit_label_runtime => 'Looptijd';

  @override
  String get diveLog_edit_label_surfacePressure => 'Oppervlaktedruk';

  @override
  String get diveLog_edit_label_swellHeight => 'Deiningshoogte';

  @override
  String get diveLog_edit_label_type => 'Type';

  @override
  String get diveLog_edit_label_visibility => 'Zicht';

  @override
  String get diveLog_edit_label_waterTemp => 'Watertemp.';

  @override
  String get diveLog_edit_label_waterType => 'Watertype';

  @override
  String get diveLog_edit_marineLifeHint =>
      'Tik op \"Toevoegen\" om waarnemingen vast te leggen';

  @override
  String get diveLog_edit_nearbySitesFirst => 'Nabijgelegen stekken eerst';

  @override
  String get diveLog_edit_noEquipmentSelected => 'Geen uitrusting geselecteerd';

  @override
  String get diveLog_edit_noMarineLife => 'Geen onderwaterleven gelogd';

  @override
  String get diveLog_edit_notSpecified => 'Niet opgegeven';

  @override
  String get diveLog_edit_notesHint => 'Voeg notities toe over deze duik...';

  @override
  String get diveLog_edit_overline_tanks => 'Flessen';

  @override
  String get diveLog_edit_profile_draw => 'Profiel tekenen';

  @override
  String get diveLog_edit_profile_none => 'Niet vastgelegd';

  @override
  String diveLog_edit_profile_outliers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mogelijke uitschieters gedetecteerd',
      one: '1 mogelijke uitschieter gedetecteerd',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_profile_points(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punten',
      one: '1 punt',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_row_addSite => 'Duikstek toevoegen';

  @override
  String get diveLog_edit_row_diveCenter => 'Duikcentrum';

  @override
  String get diveLog_edit_row_diveProfile => 'Duikprofiel';

  @override
  String get diveLog_edit_row_entry => 'Te water';

  @override
  String get diveLog_edit_row_exit => 'Uit het water';

  @override
  String get diveLog_edit_row_notSet => 'Niet ingesteld';

  @override
  String get diveLog_edit_row_site => 'Duikstek';

  @override
  String get diveLog_edit_row_surfaceInterval => 'Oppervlakte-interval';

  @override
  String get diveLog_edit_row_trip => 'Reis';

  @override
  String get diveLog_edit_save => 'Opslaan';

  @override
  String get diveLog_edit_saveAsSet => 'Opslaan als set';

  @override
  String diveLog_edit_saveAsSetDialog_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return 'Sla $count $_temp0 op als een nieuwe uitrustingsset.';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description =>
      'Beschrijving (optioneel)';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint =>
      'bijv. Lichte uitrusting voor warm water';

  @override
  String diveLog_edit_saveAsSetDialog_error(Object error) {
    return 'Fout bij aanmaken set: $error';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_setName => 'Setnaam';

  @override
  String get diveLog_edit_saveAsSetDialog_setNameHint =>
      'bijv. Tropisch duiken';

  @override
  String diveLog_edit_saveAsSetDialog_success(Object name) {
    return 'Uitrustingsset \"$name\" aangemaakt';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title => 'Opslaan als uitrustingsset';

  @override
  String get diveLog_edit_saveAsSetDialog_validation => 'Voer een setnaam in';

  @override
  String get diveLog_edit_section_conditions => 'Omstandigheden';

  @override
  String get diveLog_edit_section_customFields => 'Custom Fields';

  @override
  String get diveLog_edit_section_depthDuration => 'Diepte & Duur';

  @override
  String get diveLog_edit_section_diveCenter => 'Duikcentrum';

  @override
  String get diveLog_edit_section_diveSite => 'Duikstek';

  @override
  String get diveLog_edit_section_entryTime => 'Tijd van instap';

  @override
  String get diveLog_edit_section_equipment => 'Uitrusting';

  @override
  String get diveLog_edit_section_exitTime => 'Tijd van uitstap';

  @override
  String get diveLog_edit_section_marineLife => 'Onderwaterleven';

  @override
  String get diveLog_edit_section_notes => 'Notities';

  @override
  String get diveLog_edit_section_rating => 'Beoordeling';

  @override
  String get diveLog_edit_section_tags => 'Tags';

  @override
  String diveLog_edit_section_tanks(Object count) {
    return 'Flessen ($count)';
  }

  @override
  String get diveLog_edit_section_trainingCourse => 'Trainingscursus';

  @override
  String get diveLog_edit_section_trip => 'Reis';

  @override
  String get diveLog_edit_section_weight => 'Gewicht';

  @override
  String get diveLog_edit_select => 'Selecteren';

  @override
  String get diveLog_edit_selectDiveCenter => 'Duikcentrum selecteren';

  @override
  String get diveLog_edit_selectDiveSite => 'Duikstek selecteren';

  @override
  String get diveLog_edit_selectTrip => 'Reis selecteren';

  @override
  String diveLog_edit_snackbar_avgDepthCalculated(Object depth) {
    return 'Gem. diepte berekend: $depth';
  }

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Bodemtijd berekend: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Fout bij opslaan van duik: $error';
  }

  @override
  String diveLog_edit_snackbar_maxDepthCalculated(Object depth) {
    return 'Max. diepte berekend: $depth';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'Geen duikprofielgegevens beschikbaar';

  @override
  String diveLog_edit_snackbar_runtimeCalculated(Object minutes) {
    return 'Looptijd berekend: $minutes min';
  }

  @override
  String get diveLog_edit_snackbar_unableToCalculateAvgDepth =>
      'Kan gemiddelde diepte niet berekenen uit profiel';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Kan bodemtijd niet berekenen uit profiel';

  @override
  String get diveLog_edit_snackbar_unableToCalculateMaxDepth =>
      'Kan maximale diepte niet berekenen uit profiel';

  @override
  String get diveLog_edit_snackbar_unableToCalculateRuntime =>
      'Kan looptijd niet berekenen uit profiel';

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
  String get diveLog_edit_summary_notes => 'notities';

  @override
  String diveLog_edit_summary_species(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count soorten',
      one: '1 soort',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_summary_tanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flessen',
      one: '1 fles',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return 'Oppervlakte-interval: $interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint =>
      'Standaard: 1013 mbar op zeeniveau';

  @override
  String get diveLog_edit_tankCard_done => 'Klaar';

  @override
  String get diveLog_edit_tankCard_edit => 'Bewerken';

  @override
  String get diveLog_edit_tankCard_mix => 'Mengsel';

  @override
  String get diveLog_edit_tankCard_pressure => 'Druk';

  @override
  String diveLog_edit_tankCard_title(int number) {
    return 'Fles $number';
  }

  @override
  String get diveLog_edit_tankCard_volume => 'Volume';

  @override
  String get diveLog_edit_tooltip_calculateFromProfile =>
      'Berekenen uit duikprofiel';

  @override
  String get diveLog_edit_tooltip_clearDiveCenter => 'Duikcentrum wissen';

  @override
  String get diveLog_edit_tooltip_clearSite => 'Duikstek wissen';

  @override
  String get diveLog_edit_tooltip_clearTrip => 'Reis wissen';

  @override
  String get diveLog_edit_tooltip_removeEquipment => 'Uitrusting verwijderen';

  @override
  String get diveLog_edit_tooltip_removeSighting => 'Waarneming verwijderen';

  @override
  String get diveLog_edit_tooltip_removeWeight => 'Verwijderen';

  @override
  String get diveLog_edit_trainingCourseHint =>
      'Koppel deze duik aan een trainingscursus';

  @override
  String diveLog_edit_tripSuggested(Object name) {
    return 'Voorgesteld: $name';
  }

  @override
  String get diveLog_edit_tripUse => 'Gebruiken';

  @override
  String get diveLog_edit_useSet => 'Set gebruiken';

  @override
  String diveLog_edit_weightTotal(Object total) {
    return 'Totaal: $total';
  }

  @override
  String get diveLog_emptyFiltered_clearFilters => 'Filters wissen';

  @override
  String get diveLog_emptyFiltered_subtitle =>
      'Probeer uw filters aan te passen of te wissen';

  @override
  String get diveLog_emptyFiltered_title =>
      'Geen duiken komen overeen met uw filters';

  @override
  String get diveLog_empty_logFirstDive => 'Log uw eerste duik';

  @override
  String get diveLog_empty_subtitle =>
      'Tik op de knop hieronder om uw eerste duik te loggen';

  @override
  String get diveLog_empty_title => 'Nog geen duiken gelogd';

  @override
  String get diveLog_equipmentPicker_addFromTab =>
      'Voeg uitrusting toe via het tabblad Uitrusting';

  @override
  String get diveLog_equipmentPicker_allSelected =>
      'Alle uitrusting al geselecteerd';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return 'Fout bij laden van uitrusting: $error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => 'Nog geen uitrusting';

  @override
  String get diveLog_equipmentPicker_removeToAdd =>
      'Verwijder items om andere toe te voegen';

  @override
  String get diveLog_equipmentPicker_title => 'Uitrusting toevoegen';

  @override
  String get diveLog_equipmentSetPicker_createHint =>
      'Maak sets aan via Uitrusting > Sets';

  @override
  String get diveLog_equipmentSetPicker_emptySet => 'Lege set';

  @override
  String get diveLog_equipmentSetPicker_errorItems =>
      'Fout bij laden van items';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return 'Fout bij laden van uitrustingssets: $error';
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
  String get diveLog_equipmentSetPicker_loading => 'Laden...';

  @override
  String get diveLog_equipmentSetPicker_noSets => 'Nog geen uitrustingssets';

  @override
  String get diveLog_equipmentSetPicker_title => 'Uitrustingsset gebruiken';

  @override
  String get diveLog_error_loadingDives => 'Fout bij laden van duiken';

  @override
  String get diveLog_error_retry => 'Opnieuw proberen';

  @override
  String get diveLog_exportImage_captureFailed =>
      'Kon afbeelding niet vastleggen';

  @override
  String get diveLog_exportImage_generateFailed =>
      'Kon afbeelding niet genereren';

  @override
  String get diveLog_exportImage_generatingPdf => 'PDF genereren...';

  @override
  String get diveLog_exportImage_pdfSaved => 'PDF opgeslagen';

  @override
  String get diveLog_exportImage_saveToFiles => 'Opslaan in Bestanden';

  @override
  String get diveLog_exportImage_saveToFilesDescription =>
      'Kies een locatie om het bestand op te slaan';

  @override
  String get diveLog_exportImage_saveToPhotos => 'Opslaan in Foto\'s';

  @override
  String get diveLog_exportImage_saveToPhotosDescription =>
      'Afbeelding opslaan in uw fotobibliotheek';

  @override
  String get diveLog_exportImage_savedToFiles => 'Afbeelding opgeslagen';

  @override
  String get diveLog_exportImage_savedToPhotos =>
      'Afbeelding opgeslagen in Foto\'s';

  @override
  String get diveLog_exportImage_share => 'Delen';

  @override
  String get diveLog_exportImage_shareDescription => 'Delen via andere apps';

  @override
  String get diveLog_exportImage_titleDetails =>
      'Duikdetails als afbeelding exporteren';

  @override
  String get diveLog_exportImage_titlePdf => 'PDF exporteren';

  @override
  String get diveLog_exportImage_titleProfile => 'Profielafbeelding exporteren';

  @override
  String get diveLog_export_csv => 'CSV';

  @override
  String get diveLog_export_csvDescription => 'Spreadsheetformaat';

  @override
  String get diveLog_export_exporting => 'Exporteren...';

  @override
  String diveLog_export_failed(Object error) {
    return 'Export mislukt: $error';
  }

  @override
  String get diveLog_export_pageAsImage => 'Pagina als afbeelding';

  @override
  String get diveLog_export_pageAsImageDescription =>
      'Schermafbeelding van volledige duikdetails';

  @override
  String get diveLog_export_pdfDescription => 'Afdrukbare duiklogpagina';

  @override
  String get diveLog_export_pdfLogbookEntry => 'PDF Logboekvermelding';

  @override
  String get diveLog_export_success => 'Duik succesvol geëxporteerd';

  @override
  String diveLog_export_titleDiveNumber(Object number) {
    return 'Duik #$number exporteren';
  }

  @override
  String get diveLog_export_uddf => 'UDDF';

  @override
  String get diveLog_export_uddfDescription => 'Universeel Duikgegevensformaat';

  @override
  String get diveLog_filterChip_clearAll => 'Alles wissen';

  @override
  String get diveLog_filterChip_favorites => 'Favorieten';

  @override
  String diveLog_filterChip_from(Object date) {
    return 'Van $date';
  }

  @override
  String get diveLog_filterChip_noBuddy => 'Geen buddy';

  @override
  String diveLog_filterChip_until(Object date) {
    return 'Tot $date';
  }

  @override
  String get diveLog_filter_allSites => 'Alle stekken';

  @override
  String get diveLog_filter_allTypes => 'Alle types';

  @override
  String get diveLog_filter_apply => 'Filters toepassen';

  @override
  String get diveLog_filter_buddyHint => 'Zoek op buddynaam';

  @override
  String get diveLog_filter_buddyName => 'Buddynaam';

  @override
  String get diveLog_filter_clearAll => 'Alles wissen';

  @override
  String get diveLog_filter_clearDates => 'Datums wissen';

  @override
  String get diveLog_filter_clearRating => 'Beoordelingsfilter wissen';

  @override
  String get diveLog_filter_clearWeekdays => 'Weekdagen wissen';

  @override
  String get diveLog_filter_dateSeparator => 'tot';

  @override
  String get diveLog_filter_endDate => 'Einddatum';

  @override
  String get diveLog_filter_errorLoadingSites => 'Fout bij laden van stekken';

  @override
  String get diveLog_filter_errorLoadingTags => 'Fout bij laden van tags';

  @override
  String get diveLog_filter_favoritesOnly => 'Alleen favorieten';

  @override
  String get diveLog_filter_gasAir => 'Lucht (21%)';

  @override
  String get diveLog_filter_gasAll => 'Alle';

  @override
  String get diveLog_filter_gasNitrox => 'Nitrox (>21%)';

  @override
  String get diveLog_filter_max => 'Max';

  @override
  String get diveLog_filter_min => 'Min';

  @override
  String get diveLog_filter_noBuddyOnly => 'Geen buddy toegewezen';

  @override
  String get diveLog_filter_noTagsYet => 'Nog geen tags aangemaakt';

  @override
  String get diveLog_filter_presetAllTime => 'Altijd';

  @override
  String get diveLog_filter_presetLast12Months => 'Afgelopen 12 maanden';

  @override
  String get diveLog_filter_presetLastYear => 'Vorig jaar';

  @override
  String get diveLog_filter_presetThisYear => 'Dit jaar';

  @override
  String get diveLog_filter_sectionBuddy => 'Buddy';

  @override
  String get diveLog_filter_sectionDateRange => 'Datumbereik';

  @override
  String get diveLog_filter_sectionDepthRange => 'Dieptebereik (meters)';

  @override
  String get diveLog_filter_sectionDiveSite => 'Duikstek';

  @override
  String get diveLog_filter_sectionDiveType => 'Duiktype';

  @override
  String get diveLog_filter_sectionDuration => 'Duur (minuten)';

  @override
  String get diveLog_filter_sectionGasMix => 'Gasmix (O₂%)';

  @override
  String get diveLog_filter_sectionMinRating => 'Minimale beoordeling';

  @override
  String get diveLog_filter_sectionTags => 'Tags';

  @override
  String get diveLog_filter_sectionWeekdays => 'Weekdagen';

  @override
  String get diveLog_filter_showOnlyFavorites => 'Toon alleen favoriete duiken';

  @override
  String get diveLog_filter_showOnlyNoBuddy =>
      'Toon alleen duiken zonder buddy';

  @override
  String get diveLog_filter_startDate => 'Startdatum';

  @override
  String get diveLog_filter_title => 'Duiken filteren';

  @override
  String get diveLog_filter_resizeGrip => 'Formaat van filterpaneel wijzigen';

  @override
  String get diveLog_filter_tooltip_close => 'Filter sluiten';

  @override
  String get diveLog_fullscreenProfile_close => 'Volledig scherm sluiten';

  @override
  String get diveLog_fullscreenProfile_readoutHint =>
      'Beweeg de muis over het profiel of veeg erover';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Duik #$number profiel';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Opstijgsnelheid';

  @override
  String get diveLog_legend_label_ascentRateLine => 'Opstijgsnelheid (lijn)';

  @override
  String get diveLog_legend_label_ceiling => 'Plafond';

  @override
  String get diveLog_legend_label_decoStops => 'Deco stops';

  @override
  String get diveLog_legend_label_cns => 'CNS%';

  @override
  String get diveLog_legend_label_depth => 'Diepte';

  @override
  String get diveLog_legend_label_events => 'Gebeurtenissen';

  @override
  String get diveLog_legend_label_gasDensity => 'Gasdichtheid';

  @override
  String get diveLog_legend_label_gasSwitches => 'Gaswisselingen';

  @override
  String get diveLog_legend_label_gfPercent => 'GF%';

  @override
  String get diveLog_legend_label_heartRate => 'Hartslag';

  @override
  String get diveLog_legend_label_maxDepth => 'Max diepte';

  @override
  String get diveLog_legend_label_meanDepth => 'Gemiddelde diepte';

  @override
  String get diveLog_legend_label_mod => 'MOD';

  @override
  String get diveLog_legend_label_ndl => 'NDL';

  @override
  String get diveLog_legend_label_otu => 'OTU';

  @override
  String get diveLog_legend_label_photoMarkers => 'Foto\'s';

  @override
  String get diveLog_legend_label_ppHe => 'ppHe';

  @override
  String get diveLog_legend_label_ppN2 => 'ppN2';

  @override
  String get diveLog_legend_label_ppO2 => 'ppO2';

  @override
  String get diveLog_legend_label_pressure => 'Druk';

  @override
  String get diveLog_legend_label_pressureThresholds => 'Drukdrempels';

  @override
  String get diveLog_legend_label_sacRate => 'SAC-verbruik';

  @override
  String get diveLog_legend_label_showGas => 'Gassen';

  @override
  String get diveLog_legend_label_surfaceGf => 'Oppervlakte GF';

  @override
  String get diveLog_legend_label_temp => 'Temp';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_legend_source_dc => 'DC';

  @override
  String get diveLog_legend_source_calc => 'Ber.';

  @override
  String get diveLog_chartSection_overlays => 'Overlays';

  @override
  String get diveLog_chartSection_markers => 'Markeringen';

  @override
  String get diveLog_chartSection_decompression => 'Decompressie';

  @override
  String get diveLog_chartSection_gasAnalysis => 'Gasanalyse';

  @override
  String get diveLog_chartSection_display => 'Weergave';

  @override
  String get diveLog_chartSection_other => 'Overig';

  @override
  String get diveLog_chartSection_tankPressures => 'Flesdrukken';

  @override
  String get diveLog_chartOption_metricsFollowViewport =>
      'Overlays in beeld houden';

  @override
  String get diveLog_pressure_estimatedSuffix => '(gesch.)';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Duikkaart';

  @override
  String get diveLog_listPage_compactTitle => 'Duiken';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Fout: $error';
  }

  @override
  String get diveLog_listPage_bottomSheet_importFromComputer =>
      'Importeren van duikcomputer';

  @override
  String get diveLog_listPage_bottomSheet_scanPaperLog =>
      'Papieren logboek scannen';

  @override
  String get ocrImport_scanPage_processing => 'Pagina wordt gelezen...';

  @override
  String get ocrImport_scanPage_pickPhoto => 'Foto kiezen';

  @override
  String get ocrImport_scanPage_takePhoto => 'Foto maken';

  @override
  String get ocrImport_scanPage_nothingRead =>
      'Er kon weinig van deze pagina worden gelezen - velden blijven leeg';

  @override
  String get ocrImport_scanPage_engineMissing =>
      'Tekstherkenning is niet beschikbaar. Installeer Tesseract om papieren logboeken te scannen (bijvoorbeeld: sudo apt install tesseract-ocr).';

  @override
  String get ocrImport_editPage_photoAttachFailed =>
      'De duik is opgeslagen, maar het bijvoegen van de gescande pagina is mislukt';

  @override
  String get diveLog_listPage_bottomSheet_logManually =>
      'Duik handmatig loggen';

  @override
  String get diveLog_listPage_fab_addDive => 'Duik toevoegen';

  @override
  String get diveLog_listPage_fab_logDive => 'Duik loggen';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Geavanceerd zoeken';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Duiknummering';

  @override
  String get diveLog_listPage_menuMatchSites => 'Duiken aan stekken koppelen';

  @override
  String get diveLog_sighting_decreaseCount => 'Aantal verlagen';

  @override
  String get diveLog_sighting_increaseCount => 'Aantal verhogen';

  @override
  String diveLog_speciesPicker_errorLoading(String error) {
    return 'Fout bij laden van soorten: $error';
  }

  @override
  String get diveRole_builtin_buddy => 'Buddy';

  @override
  String get diveRole_builtin_diveGuide => 'Duikgids';

  @override
  String get diveRole_builtin_diveMaster => 'Divemaster';

  @override
  String get diveRole_builtin_instructor => 'Instructeur';

  @override
  String get diveRole_builtin_rearGuard => 'Hekkensluiter';

  @override
  String get diveRole_builtin_safetyDiver => 'Veiligheidsduiker';

  @override
  String get diveRole_builtin_solo => 'Solo';

  @override
  String get diveRole_builtin_student => 'Leerling';

  @override
  String get diveRole_builtin_supportDiver => 'Supportduiker';

  @override
  String get diveRoles_addDialog_addButton => 'Toevoegen';

  @override
  String get diveRoles_addDialog_nameHint => 'bijv. Fotograaf';

  @override
  String get diveRoles_addDialog_nameLabel => 'Duikrol naam';

  @override
  String get diveRoles_addDialog_nameValidation => 'Voer een naam in';

  @override
  String get diveRoles_addDialog_title => 'Aangepaste duikrol toevoegen';

  @override
  String get diveRoles_addTooltip => 'Duikrol toevoegen';

  @override
  String get diveRoles_appBar_title => 'Duikrollen';

  @override
  String get diveRoles_builtInHeader => 'Ingebouwde duikrollen';

  @override
  String get diveRoles_customHeader => 'Aangepaste duikrollen';

  @override
  String diveRoles_deleteDialog_content(Object name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen?';
  }

  @override
  String get diveRoles_deleteDialog_title => 'Duikrol verwijderen?';

  @override
  String get diveRoles_deleteTooltip => 'Duikrol verwijderen';

  @override
  String get diveRoles_renameDialog_title => 'Duikrol hernoemen';

  @override
  String get diveRoles_renameTooltip => 'Duikrol hernoemen';

  @override
  String diveRoles_snackbar_added(Object name) {
    return 'Duikrol toegevoegd: $name';
  }

  @override
  String diveRoles_snackbar_cannotDelete(Object name) {
    return 'Kan \"$name\" niet verwijderen - wordt gebruikt door bestaande duiken';
  }

  @override
  String diveRoles_snackbar_deleted(Object name) {
    return 'Duikrol verwijderd: $name';
  }

  @override
  String diveRoles_snackbar_errorAdding(Object error) {
    return 'Fout bij toevoegen duikrol: $error';
  }

  @override
  String get diveSites_edit_depth_heroMax => 'Max. diepte';

  @override
  String get diveSites_edit_depth_heroMin => 'Min. diepte';

  @override
  String get diveSites_edit_group_accessSafety => 'Toegang & veiligheid';

  @override
  String get diveSites_edit_group_diveInfo => 'Duikinfo';

  @override
  String get diveSites_edit_group_identity => 'Identiteit';

  @override
  String get diveSites_edit_group_lifeNotes => 'Leven & notities';

  @override
  String get diveSites_edit_group_location => 'Locatie';

  @override
  String get diveSites_edit_invite_accessSafety =>
      'Toegang, parkeren, afmeren of gevaren toevoegen';

  @override
  String get diveSites_edit_invite_diveInfo =>
      'Dieptebereik, moeilijkheid of beoordeling toevoegen';

  @override
  String get diveSites_edit_invite_lifeNotes =>
      'Zeeleven, notities of delen toevoegen';

  @override
  String get diveSites_edit_invite_location =>
      'GPS-positie of hoogte toevoegen';

  @override
  String get diveSites_edit_summary_shared => 'gedeeld';

  @override
  String get forms_addSection_prefix => 'Toevoegen:';

  @override
  String get forms_cancel => 'Annuleren';

  @override
  String get forms_discard_body =>
      'Je hebt niet-opgeslagen wijzigingen. Als je nu weggaat, gaan ze verloren.';

  @override
  String get forms_discard_discard => 'Verwerpen';

  @override
  String get forms_discard_keepEditing => 'Doorgaan met bewerken';

  @override
  String get forms_discard_title => 'Wijzigingen verwerpen?';

  @override
  String get forms_save => 'Opslaan';

  @override
  String forms_section_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemen',
      one: '1 probleem',
    );
    return '$_temp0';
  }

  @override
  String get settings_manage_setupAssistant => 'Configuratie-assistent';

  @override
  String get settings_manage_setupAssistant_subtitle =>
      'Eenheden, weergave en back-upkeuzes opnieuw bekijken';

  @override
  String get setup_backup_cloudCopy => 'Back-ups opslaan in de cloud';

  @override
  String get setup_backup_frequency => 'Frequentie';

  @override
  String get setup_backup_frequency_daily => 'Dagelijks';

  @override
  String get setup_backup_frequency_monthly => 'Maandelijks';

  @override
  String get setup_backup_frequency_weekly => 'Wekelijks';

  @override
  String get setup_backup_scheduleSubtitle =>
      'Maak volgens schema een back-up van je gegevens';

  @override
  String get setup_backup_scheduleToggle => 'Automatische back-ups';

  @override
  String get setup_backup_subtitle => 'Bescherm je gegevens vanaf dag één.';

  @override
  String get setup_backup_title => 'Back-ups en synchronisatie';

  @override
  String get setup_common_back => 'Terug';

  @override
  String get setup_common_next => 'Volgende';

  @override
  String get setup_common_skip => 'Overslaan';

  @override
  String get setup_existing_folder_subtitle =>
      'Wijs Submersion naar een map die al een bibliotheek bevat';

  @override
  String get setup_existing_folder_title => 'Een bestaande map openen';

  @override
  String get setup_existing_restore_subtitle =>
      'Kies een back-upbestand dat uit Submersion is geëxporteerd';

  @override
  String get setup_existing_restore_title => 'Een back-upbestand terugzetten';

  @override
  String get setup_existing_subtitle =>
      'Kies hoe je bestaande Submersion-bibliotheek wordt geladen';

  @override
  String get setup_existing_sync_subtitle =>
      'Haal je bibliotheek op uit iCloud, Dropbox of S3';

  @override
  String get setup_existing_sync_title => 'Cloudsynchronisatie verbinden';

  @override
  String get setup_existing_title => 'Breng je gegevens mee';

  @override
  String get setup_finish_applying => 'Instellen...';

  @override
  String setup_finish_error(Object error) {
    return 'Kon de installatie niet voltooien: $error';
  }

  @override
  String get setup_finish_feature_diveComputer =>
      'Duiken downloaden vanaf je duikcomputer';

  @override
  String get setup_finish_feature_gear =>
      'Uitrusting en onderhoudsintervallen bijhouden';

  @override
  String get setup_finish_feature_import =>
      'Logboeken importeren uit bestanden en andere apps';

  @override
  String get setup_finish_feature_sites => 'Je duikstekken op de kaart zetten';

  @override
  String get setup_finish_feature_statistics =>
      'Statistieken over je duiken verkennen';

  @override
  String get setup_finish_start => 'Aan de slag';

  @override
  String get setup_finish_subtitle => 'Submersion kan ook...';

  @override
  String get setup_finish_title => 'Je bent klaar';

  @override
  String get setup_folder_notFound_message =>
      'De geselecteerde map bevat geen Submersion-database.';

  @override
  String get setup_folder_notFound_title => 'Geen bibliotheek in die map';

  @override
  String get setup_folder_pick => 'Map kiezen';

  @override
  String get setup_folder_switching => 'Bibliotheek openen...';

  @override
  String get setup_folder_title => 'Bestaande map openen';

  @override
  String get setup_profile_nameHint => 'Voer je naam in';

  @override
  String get setup_profile_nameLabel => 'Je naam';

  @override
  String get setup_profile_nameValidation => 'Voer je naam in';

  @override
  String get setup_profile_subtitle =>
      'Voer je naam in om te beginnen. Je kunt later meer details toevoegen.';

  @override
  String get setup_profile_title => 'Maak je profiel aan';

  @override
  String get setup_restore_inProgress => 'Terugzetten...';

  @override
  String get setup_restore_pick => 'Back-upbestand kiezen';

  @override
  String get setup_restore_title => 'Back-up terugzetten';

  @override
  String get setup_step_backup => 'Back-up';

  @override
  String get setup_step_finish => 'Klaar';

  @override
  String get setup_step_profile => 'Profiel';

  @override
  String get setup_step_units => 'Eenheden';

  @override
  String get setup_syncPull_continue => 'Doorgaan';

  @override
  String get setup_syncPull_incomplete_message =>
      'Dit account bevat een Submersion-bibliotheek die nooit volledig is geüpload. Laat je andere apparaat de synchronisatie voltooien en probeer het opnieuw.';

  @override
  String get setup_syncPull_incomplete_retry => 'Opnieuw controleren';

  @override
  String get setup_syncPull_incomplete_title =>
      'Bibliotheek niet volledig geüpload';

  @override
  String get setup_syncPull_locked_message =>
      'Voer de versleutelingswachtwoordzin in om deze bibliotheek te ontgrendelen en naar dit apparaat te downloaden.';

  @override
  String get setup_syncPull_locked_title => 'Deze bibliotheek is versleuteld';

  @override
  String get setup_syncPull_noLibrary_message =>
      'Er is geen Submersion-bibliotheek gevonden op dit account. Opnieuw beginnen? Je verbinding blijft behouden.';

  @override
  String get setup_syncPull_noLibrary_title => 'Geen bibliotheek gevonden';

  @override
  String get setup_syncPull_success => 'Bibliotheek overgenomen';

  @override
  String get setup_syncPull_syncing => 'Bibliotheek ophalen...';

  @override
  String get setup_syncPull_title => 'Verbinden en ophalen';

  @override
  String get setup_sync_changeProvider => 'Provider wijzigen';

  @override
  String setup_sync_connectedTo(String provider) {
    return 'Verbonden met $provider';
  }

  @override
  String setup_sync_error(Object error) {
    return 'Kon geen verbinding maken: $error';
  }

  @override
  String get setup_sync_header => 'Cloudsynchronisatie';

  @override
  String get setup_sync_libraryFound_adopt => 'Bestaande bibliotheek overnemen';

  @override
  String get setup_sync_libraryFound_keepFresh => 'Opnieuw beginnen';

  @override
  String get setup_sync_libraryFound_message =>
      'Dit account bevat al een Submersion-bibliotheek. Deze overnemen in plaats van opnieuw te beginnen?';

  @override
  String get setup_sync_libraryFound_title => 'Bestaande bibliotheek gevonden';

  @override
  String get setup_sync_manageInSettings => 'Beheren in Instellingen';

  @override
  String get setup_sync_notConnected => 'Niet verbonden';

  @override
  String get setup_sync_subtitle =>
      'Synchroniseer je gegevens tussen apparaten';

  @override
  String get setup_units_advanced => 'Eenheden verfijnen';

  @override
  String get setup_units_altitude => 'Hoogte';

  @override
  String get setup_units_dateFormat => 'Datumnotatie';

  @override
  String get setup_units_depth => 'Diepte';

  @override
  String get setup_units_imperial => 'Imperiaal';

  @override
  String get setup_units_metric => 'Metrisch';

  @override
  String get setup_units_pressure => 'Druk';

  @override
  String get setup_units_sac => 'SAC-waarde';

  @override
  String get setup_units_subtitle =>
      'Kies hoe metingen worden weergegeven. Je kunt elke eenheid apart instellen.';

  @override
  String get setup_units_temperature => 'Temperatuur';

  @override
  String get setup_units_timeFormat => 'Tijdnotatie';

  @override
  String get setup_units_title => 'Eenheden';

  @override
  String get setup_units_volume => 'Volume';

  @override
  String get setup_units_weight => 'Gewicht';

  @override
  String get setup_welcome_existingData_subtitle =>
      'Zet een back-up terug, verbind cloudsynchronisatie of open een bestaande map';

  @override
  String get setup_welcome_existingData_title =>
      'Ik heb al Submersion-gegevens';

  @override
  String get setup_welcome_skipSetup => 'Installatie overslaan';

  @override
  String get setup_welcome_startFresh_subtitle =>
      'Maak je duikersprofiel en stel de app in';

  @override
  String get setup_welcome_startFresh_title => 'Een nieuw profiel instellen';

  @override
  String get setup_welcome_subtitle => 'Geavanceerd duiklogboek en analyse';

  @override
  String get setup_welcome_title => 'Welkom bij Submersion';

  @override
  String get siteMatchReview_title => 'Stekken koppelen';

  @override
  String siteMatchReview_diveNumber(Object number) {
    return 'Duik #$number';
  }

  @override
  String get siteMatchReview_empty => 'Niets om te koppelen.';

  @override
  String siteMatchReview_summary(int selected, int review, int none) {
    return '$selected geselecteerd · $review te beoordelen · $none geen match';
  }

  @override
  String siteMatchReview_confirm(int count) {
    return '$count koppelingen bevestigen';
  }

  @override
  String get siteMatchReview_cancel => 'Annuleren';

  @override
  String get siteMatchReview_tapToChoose => 'Tik om een stek te kiezen';

  @override
  String siteMatchReview_awayMeters(int meters) {
    return '$meters m verderop';
  }

  @override
  String siteMatchReview_depthTo(int meters) {
    return 'tot $meters m';
  }

  @override
  String siteMatchReview_depthRange(int min, int max) {
    return '$min–$max m';
  }

  @override
  String siteMatchReview_appliedSnack(int dives, int sites) {
    return '$dives duiken gekoppeld · $sites stekken toegevoegd';
  }

  @override
  String get siteMatchReview_applyError => 'Kan koppelingen niet toepassen';

  @override
  String get siteMatchReview_discardTitle => 'Koppelingen verwerpen?';

  @override
  String get siteMatchReview_discardMessage =>
      'Je selectie wordt niet opgeslagen.';

  @override
  String get siteMatchReview_discardConfirm => 'Verwerpen';

  @override
  String get siteMatchReview_keepReviewing => 'Doorgaan met beoordelen';

  @override
  String get siteMatchReview_sourceExisting => 'jouw stek';

  @override
  String get siteMatchReview_sourceBundled => 'import';

  @override
  String get siteMatchReview_noNearbySite => 'Geen stek in de buurt';

  @override
  String importSummary_matchSitesButton(int count) {
    return '$count duiken aan stekken koppelen';
  }

  @override
  String get diveLog_listPage_searchFieldLabel => 'Duiken zoeken...';

  @override
  String diveLog_listPage_searchLimitNotice(int limit) {
    return 'De eerste $limit resultaten worden getoond. Verfijn je zoekopdracht om de resultaten te beperken.';
  }

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return 'Geen duiken gevonden voor \"$query\"';
  }

  @override
  String get diveLog_listPage_searchSuggestion =>
      'Zoek op stek, buddy of notities';

  @override
  String get diveLog_listPage_title => 'Duiklogboek';

  @override
  String get diveLog_listPage_tooltip_back => 'Terug';

  @override
  String get diveLog_listPage_tooltip_backToDiveList => 'Terug naar duiklijst';

  @override
  String get diveLog_listPage_tooltip_clearSearch => 'Zoekopdracht wissen';

  @override
  String get diveLog_listPage_tooltip_filterDives => 'Duiken filteren';

  @override
  String get diveLog_listPage_tooltip_listView => 'Lijstweergave';

  @override
  String get diveLog_listPage_tooltip_mapView => 'Kaartweergave';

  @override
  String get diveLog_listPage_tooltip_searchDives => 'Duiken zoeken';

  @override
  String get diveLog_listPage_tooltip_sort => 'Sorteren';

  @override
  String get diveLog_listPage_unknownSite => 'Onbekende duikstek';

  @override
  String get diveLog_map_emptySubtitle =>
      'Log duiken met locatiegegevens om uw activiteit op de kaart te zien';

  @override
  String get diveLog_map_emptyTitle => 'Geen duikactiviteit om weer te geven';

  @override
  String diveLog_map_errorLoading(Object error) {
    return 'Fout bij laden van duikgegevens: $error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => 'Alle stekken passend maken';

  @override
  String get diveLog_numbering_actions => 'Acties';

  @override
  String get diveLog_numbering_allCorrect => 'Alle duiken correct genummerd';

  @override
  String get diveLog_numbering_assignMissing => 'Ontbrekende nummers toewijzen';

  @override
  String get diveLog_numbering_assignMissingDesc =>
      'Nummer ongenummerde duiken vanaf na de laatste genummerde duik';

  @override
  String get diveLog_numbering_close => 'Sluiten';

  @override
  String get diveLog_numbering_gapsDetected => 'Gaten gedetecteerd';

  @override
  String get diveLog_numbering_issuesDetected => 'Problemen gedetecteerd';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '$count ontbrekend';
  }

  @override
  String get diveLog_numbering_renumberAll => 'Alle duiken hernummeren';

  @override
  String get diveLog_numbering_renumberAllDesc =>
      'Ken opeenvolgende nummers toe op basis van duikdatum/-tijd';

  @override
  String get diveLog_numbering_renumberDialog_cancel => 'Annuleren';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      'Dit zal alle duiken opeenvolgend hernummeren op basis van de instapdatum/-tijd. Deze actie kan niet ongedaan worden gemaakt.';

  @override
  String get diveLog_numbering_renumberDialog_renumber => 'Hernummeren';

  @override
  String get diveLog_numbering_renumberDialog_startFrom =>
      'Beginnen vanaf nummer';

  @override
  String get diveLog_numbering_renumberDialog_title =>
      'Alle duiken hernummeren';

  @override
  String get diveLog_numbering_snackbar_assigned =>
      'Ontbrekende duiknummers toegewezen';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return 'Alle duiken hernummerd vanaf #$number';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '$total duiken totaal • $numbered genummerd';
  }

  @override
  String get diveLog_numbering_title => 'Duiknummering';

  @override
  String diveLog_numbering_unnumberedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return '$count $_temp0 zonder nummer';
  }

  @override
  String get diveLog_o2tox_badge_critical => 'KRITIEK';

  @override
  String get diveLog_o2tox_badge_warning => 'WAARSCHUWING';

  @override
  String diveLog_o2tox_cnsBadgeLabel(Object value) {
    return 'CNS $value';
  }

  @override
  String get diveLog_o2tox_cnsOxygenClock => 'CNS-zuurstofklok';

  @override
  String diveLog_o2tox_deltaDive(Object value) {
    return '+$value% deze duik';
  }

  @override
  String get diveLog_o2tox_details => 'Details';

  @override
  String get diveLog_o2tox_label_maxPpO2 => 'Max ppO2';

  @override
  String get diveLog_o2tox_label_maxPpO2Depth => 'Max ppO2-diepte';

  @override
  String get diveLog_o2tox_label_timeAbove14 => 'Tijd boven 1,4 bar';

  @override
  String get diveLog_o2tox_label_timeAbove16 => 'Tijd boven 1,6 bar';

  @override
  String get diveLog_o2tox_ofDailyLimit => 'van dagelijks limiet';

  @override
  String get diveLog_o2tox_oxygenToleranceUnits =>
      'Zuurstoftolerantie-eenheden';

  @override
  String diveLog_o2tox_semantics_cnsBadge(Object value) {
    return 'CNS zuurstoftoxiciteit $value';
  }

  @override
  String get diveLog_o2tox_semantics_criticalWarning =>
      'Kritieke waarschuwing zuurstoftoxiciteit';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return 'Oxygen Tolerance Units: $value, $percent procent van dagelijkse limiet';
  }

  @override
  String get diveLog_o2tox_semantics_warning =>
      'Waarschuwing zuurstoftoxiciteit';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return 'Start: $value%';
  }

  @override
  String get diveLog_o2tox_title => 'Zuurstoftoxiciteit';

  @override
  String get diveLog_playbackStats_deco => 'DECO';

  @override
  String get diveLog_playbackStats_depth => 'Diepte';

  @override
  String get diveLog_playbackStats_header => 'Live statistieken';

  @override
  String get diveLog_playbackStats_heartRate => 'Hartslag';

  @override
  String get diveLog_playbackStats_ndl => 'NDL';

  @override
  String get diveLog_playbackStats_ppO2 => 'ppO₂';

  @override
  String get diveLog_playbackStats_pressure => 'Druk';

  @override
  String get diveLog_playbackStats_temp => 'Temp';

  @override
  String get diveLog_playback_sliderLabel => 'Afspeelpositie';

  @override
  String diveLog_playback_speed_label(Object speed) {
    return '${speed}x';
  }

  @override
  String get diveLog_playback_stepThrough => 'Stapsgewijs afspelen';

  @override
  String get diveLog_playback_tooltip_back10 => '10 seconden terug';

  @override
  String get diveLog_playback_tooltip_exit => 'Afspeelmodus verlaten';

  @override
  String get diveLog_playback_tooltip_forward10 => '10 seconden vooruit';

  @override
  String get diveLog_playback_tooltip_pause => 'Pauzeren';

  @override
  String get diveLog_playback_tooltip_play => 'Afspelen';

  @override
  String get diveLog_playback_tooltip_skipEnd => 'Naar einde springen';

  @override
  String get diveLog_playback_tooltip_skipStart => 'Naar begin springen';

  @override
  String get diveLog_playback_tooltip_speed => 'Afspeelsnelheid';

  @override
  String diveLog_profile_axisDepth(Object unit) {
    return 'Diepte ($unit)';
  }

  @override
  String get diveLog_profile_axisTime => 'Tijd (min)';

  @override
  String get diveLog_profile_emptyState => 'Geen duikprofielgegevens';

  @override
  String get diveLog_profile_rightAxis_none => 'Geen';

  @override
  String get diveLog_profile_semantics_changeRightAxis =>
      'Rechter as-meetwaarde wijzigen';

  @override
  String get diveLog_profile_semantics_chart =>
      'Duikprofielgrafiek, knijp om te zoomen';

  @override
  String get diveLog_profile_semantics_photoMarker => 'Fotomarkering';

  @override
  String get diveLog_profile_tooltip_moreOptions => 'Meer grafiekopties';

  @override
  String get diveLog_profile_tooltip_resetZoom => 'Zoom resetten';

  @override
  String get diveLog_profile_tooltip_zoomIn => 'Inzoomen';

  @override
  String get diveLog_profile_tooltip_zoomOut => 'Uitzoomen';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return 'Zoom: ${level}x • Knijp of scroll om te zoomen, sleep om te verplaatsen';
  }

  @override
  String get diveLog_rangeSelection_exitRange => 'Bereik verlaten';

  @override
  String get diveLog_rangeSelection_selectRange => 'Bereik selecteren';

  @override
  String get diveLog_rangeSelection_semantics_adjust =>
      'Bereikselectie aanpassen';

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
  String get diveLog_rangeStats_title => 'Bereikstatistieken';

  @override
  String get diveLog_rangeStats_tooltip_close => 'Bereikanalyse sluiten';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return 'Berekende loop FO₂: $value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => 'bijv. 0,33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => 'Toevoegverhouding';

  @override
  String get diveLog_scr_label_assumedVo2 => 'Aangenomen VO₂';

  @override
  String get diveLog_scr_label_avg => 'Gem.';

  @override
  String get diveLog_scr_label_injectionRate => 'Injectiesnelheid';

  @override
  String get diveLog_scr_label_max => 'Max';

  @override
  String get diveLog_scr_label_min => 'Min';

  @override
  String get diveLog_scr_label_orificeSize => 'Opening grootte';

  @override
  String get diveLog_scr_sectionCmf => 'CMF-parameters';

  @override
  String get diveLog_scr_sectionEscr => 'ESCR-parameters';

  @override
  String get diveLog_scr_sectionMeasuredLoopO2 => 'Gemeten Loop O₂ (optioneel)';

  @override
  String get diveLog_scr_sectionPascr => 'PASCR-parameters';

  @override
  String get diveLog_scr_sectionScrType => 'SCR-type';

  @override
  String get diveLog_scr_sectionSupplyGas => 'Toevoergas';

  @override
  String get diveLog_scr_title => 'SCR-instellingen';

  @override
  String get diveLog_search_allCenters => 'Alle centra';

  @override
  String get diveLog_search_allTrips => 'Alle reizen';

  @override
  String get diveLog_search_appBar => 'Geavanceerd zoeken';

  @override
  String get diveLog_search_cancel => 'Annuleren';

  @override
  String get diveLog_search_clearAll => 'Alles wissen';

  @override
  String get diveLog_search_customFieldKey => 'Custom Field Key';

  @override
  String get diveLog_search_customFieldValue => 'Value contains...';

  @override
  String get diveLog_search_end => 'Einde';

  @override
  String get diveLog_search_errorLoadingCenters =>
      'Fout bij laden van duikcentra';

  @override
  String get diveLog_search_errorLoadingDiveTypes => 'Fout bij laden duiktypes';

  @override
  String get diveLog_search_errorLoadingTrips => 'Fout bij laden van reizen';

  @override
  String get diveLog_search_filter_any => 'Alle';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_deco => 'Decompressie';

  @override
  String get diveLog_search_label_depthRange => 'Dieptebereik (m)';

  @override
  String get diveLog_search_label_diveCenter => 'Duikcentrum';

  @override
  String get diveLog_search_label_diveSite => 'Duikstek';

  @override
  String get diveLog_search_label_diveType => 'Duiktype';

  @override
  String get diveLog_search_label_durationRange => 'Duurbereik (min)';

  @override
  String get diveLog_search_label_trip => 'Reis';

  @override
  String get diveLog_search_search => 'Zoeken';

  @override
  String get diveLog_search_section_conditions => 'Omstandigheden';

  @override
  String get diveLog_search_section_dateRange => 'Datumbereik';

  @override
  String get diveLog_search_section_gasEquipment => 'Gas & uitrusting';

  @override
  String get diveLog_search_section_location => 'Locatie';

  @override
  String get diveLog_search_section_organization => 'Organisatie';

  @override
  String get diveLog_search_section_social => 'Sociaal';

  @override
  String get diveLog_search_start => 'Start';

  @override
  String diveLog_selection_countSelected(Object count) {
    return '$count geselecteerd';
  }

  @override
  String get diveLog_selection_tooltip_combine => 'Samenvoegen';

  @override
  String get diveLog_selection_tooltip_delete => 'Geselecteerde verwijderen';

  @override
  String get diveLog_selection_tooltip_deselectAll => 'Alles deselecteren';

  @override
  String get diveLog_selection_tooltip_edit => 'Geselecteerde bewerken';

  @override
  String get diveLog_selection_tooltip_exit => 'Selectie verlaten';

  @override
  String get diveLog_selection_tooltip_export => 'Geselecteerde exporteren';

  @override
  String get diveLog_selection_tooltip_selectAll => 'Alles selecteren';

  @override
  String get diveLog_selection_tooltip_selectDateRange =>
      'Selecteren op datumbereik';

  @override
  String get diveLog_sighting_add => 'Toevoegen';

  @override
  String get diveLog_sighting_cancel => 'Annuleren';

  @override
  String get diveLog_sighting_notesHint => 'bijv. grootte, gedrag, locatie...';

  @override
  String get diveLog_sighting_notesOptional => 'Notities (optioneel)';

  @override
  String get diveLog_sitePicker_addDiveSite => 'Duikstek toevoegen';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return '$distance km afstand';
  }

  @override
  String diveLog_sitePicker_distanceAway(String distance) {
    return '$distance afstand';
  }

  @override
  String get diveLog_sitePicker_sortedByDiveDistance =>
      'Gesorteerd op afstand tot deze duik';

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return '$distance m afstand';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return 'Fout bij laden van stekken: $error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => 'Nieuwe duikstek';

  @override
  String get diveLog_sitePicker_noSites => 'Nog geen duikstekken';

  @override
  String get diveLog_sitePicker_sortedByDistance => 'Gesorteerd op afstand';

  @override
  String get diveLog_sitePicker_title => 'Selecteer duikstek';

  @override
  String get diveLog_sort_title => 'Duiken sorteren';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return '\"$name\" als nieuwe soort toevoegen';
  }

  @override
  String get diveLog_speciesPicker_noResults => 'Geen soorten gevonden';

  @override
  String get diveLog_speciesPicker_noSpecies => 'Geen soorten beschikbaar';

  @override
  String get diveLog_speciesPicker_searchHint => 'Soorten zoeken...';

  @override
  String get diveLog_speciesPicker_title => 'Zeeleven toevoegen';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch => 'Zoekopdracht wissen';

  @override
  String get diveLog_summary_action_importComputer => 'Importeren van computer';

  @override
  String get diveLog_summary_action_logDive => 'Duik loggen';

  @override
  String get diveLog_summary_action_viewStats => 'Statistieken bekijken';

  @override
  String diveLog_summary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_summary_overview => 'Overzicht';

  @override
  String get diveLog_summary_record_coldest => 'Koudste duik';

  @override
  String get diveLog_summary_record_deepest => 'Diepste duik';

  @override
  String get diveLog_summary_record_longest => 'Langste duik';

  @override
  String get diveLog_summary_record_warmest => 'Warmste duik';

  @override
  String get diveLog_summary_section_mostVisited => 'Meest bezochte stekken';

  @override
  String get diveLog_summary_section_quickActions => 'Snelle acties';

  @override
  String get diveLog_summary_section_records => 'Persoonlijke records';

  @override
  String get diveLog_summary_selectDive =>
      'Selecteer een duik uit de lijst om details te bekijken';

  @override
  String get diveLog_summary_stat_avgMaxDepth => 'Gem. max diepte';

  @override
  String get diveLog_summary_stat_avgWaterTemp => 'Gem. watertemp.';

  @override
  String get diveLog_summary_stat_diveSites => 'Duikstekken';

  @override
  String get diveLog_summary_stat_diveTime => 'Duiktijd';

  @override
  String get diveLog_summary_stat_maxDepth => 'Max diepte';

  @override
  String get diveLog_summary_stat_totalDives => 'Totaal duiken';

  @override
  String get diveLog_summary_title => 'Duiklogoverzicht';

  @override
  String get diveLog_tank_label_endPressure => 'Einddruk';

  @override
  String get diveLog_tank_label_he => 'He';

  @override
  String get diveLog_tank_label_material => 'Materiaal';

  @override
  String get diveLog_tank_label_n2 => 'N2';

  @override
  String get diveLog_tank_label_o2 => 'O2';

  @override
  String get diveLog_tank_label_role => 'Rol';

  @override
  String get diveLog_tank_label_startPressure => 'Begindruk';

  @override
  String get diveLog_tank_label_tankPreset => 'Flesvoorinstelling';

  @override
  String get diveLog_tank_label_volume => 'Volume';

  @override
  String get diveLog_tank_label_workingPressure => 'Werkdruk';

  @override
  String get diveLog_tank_mndHelper =>
      'Instellen op automatische He%-berekening';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String diveLog_tank_modMndInfo(Object mod, Object mnd) {
    return 'MOD: $mod (ppO₂ 1,4) | MND: $mnd';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Gasmengsel';

  @override
  String get diveLog_tank_selectPreset => 'Selecteer voorinstelling...';

  @override
  String get diveLog_tank_saveAsPreset => 'Als voorinstelling opslaan';

  @override
  String get diveLog_tank_saveAsPreset_needSpecs =>
      'Voer eerst een volume en werkdruk in';

  @override
  String get diveLog_tank_saveAsPreset_nameTitle =>
      'Flesvoorinstelling opslaan';

  @override
  String get diveLog_tank_saveAsPreset_nameHint => 'bijv. Mijn AL80';

  @override
  String diveLog_tank_saveAsPreset_saved(String name) {
    return 'Voorinstelling \"$name\" opgeslagen';
  }

  @override
  String diveLog_tank_title(Object number) {
    return 'Fles $number';
  }

  @override
  String get diveLog_tank_tooltip_remove => 'Fles verwijderen';

  @override
  String get diveLog_tissue_label_ceiling => 'Plafond';

  @override
  String get diveLog_tissue_label_gf => 'GF';

  @override
  String get diveLog_tissue_label_ndl => 'NDL';

  @override
  String get diveLog_tissue_label_tts => 'TTS';

  @override
  String get diveLog_tissue_legend_he => 'He';

  @override
  String get diveLog_tissue_legend_mValue => '100% M-waarde';

  @override
  String get diveLog_tissue_legend_n2 => 'N₂';

  @override
  String get diveLog_tissue_title => 'Weefselbelasting';

  @override
  String get diveLog_tooltip_avgCalculated => '(gem., berekend)';

  @override
  String get diveLog_tooltip_ceiling => 'Plafond';

  @override
  String get diveLog_tooltip_decoStop => 'Deco stop';

  @override
  String get diveLog_tooltip_cns => 'CNS';

  @override
  String get diveLog_tooltip_density => 'Dichtheid';

  @override
  String get diveLog_tooltip_depth => 'Diepte';

  @override
  String get diveLog_tooltip_gfPercent => 'GF%';

  @override
  String get diveLog_tooltip_hr => 'HR';

  @override
  String get diveLog_tooltip_marker => 'Markering';

  @override
  String get diveLog_tooltip_mean => 'Gemiddeld';

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
  String get diveLog_tooltip_press => 'Druk';

  @override
  String get diveLog_tooltip_rate => 'Snelheid';

  @override
  String get diveLog_tooltip_sac => 'SAC';

  @override
  String get diveLog_tooltip_sensor => 'Sensor';

  @override
  String get diveLog_legend_label_o2Cells => 'O2-cellen';

  @override
  String get diveLog_tooltip_o2CellsTight => 'strak';

  @override
  String get diveLog_tooltip_o2CellsDrifting => 'driftend';

  @override
  String get diveLog_tooltip_o2CellsWide => 'breed';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Tijd';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get diveLog_sources_row_metric => 'Meting';

  @override
  String get diveLog_sources_row_maxDepth => 'Max diepte';

  @override
  String get diveLog_sources_row_avgDepth => 'Gem. diepte';

  @override
  String get diveLog_sources_row_duration => 'Duur';

  @override
  String get diveLog_sources_row_waterTemp => 'Watertemp.';

  @override
  String get diveLog_sources_row_cns => 'CNS';

  @override
  String get diveLog_sources_row_otu => 'OTU';

  @override
  String get diveLog_sources_row_decoAlgorithm => 'Deco-algoritme';

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
  String get diveLog_sources_unknownComputer => 'Onbekende computer';

  @override
  String get diveLog_sources_manualEntry => 'Handmatige invoer';

  @override
  String get diveLog_sources_importedFile => 'Geïmporteerd bestand';

  @override
  String get diveLog_sources_editedSuffix => ' (bewerkt)';

  @override
  String get diveLog_sources_barLabel => 'BRONNEN';

  @override
  String get diveLog_sources_menu_setPrimary => 'Instellen als primair';

  @override
  String get diveLog_sources_menu_split => 'Splitsen naar aparte duik';

  @override
  String get diveLog_sources_overlayTooltip => 'Overlay op grafiek';

  @override
  String get diveLog_sources_splitDialog_title => 'Splitsen naar aparte duik?';

  @override
  String get diveLog_sources_splitDialog_body =>
      'Het profiel, de gebeurtenissen en de flessen van deze bron worden verplaatst naar een nieuwe duik. De logboekvermelding blijft bij deze duik.';

  @override
  String get diveLog_sources_splitDialog_confirm => 'Splitsen';

  @override
  String get diveLog_sources_splitDone => 'Duik gesplitst';

  @override
  String get diveLog_sources_splitFailed => 'Splitsen mislukt';

  @override
  String get divePlanner_action_addTank => 'Fles toevoegen';

  @override
  String get divePlanner_action_convertToDive => 'Omzetten naar duik';

  @override
  String get divePlanner_action_deletePlan => 'Plan verwijderen';

  @override
  String get divePlanner_action_editTank => 'Fles bewerken';

  @override
  String get divePlanner_action_moreOptions => 'Meer opties';

  @override
  String get divePlanner_action_quickPlan => 'Snel plan';

  @override
  String get divePlanner_action_renamePlan => 'Plan hernoemen';

  @override
  String get divePlanner_action_reset => 'Resetten';

  @override
  String get divePlanner_action_resetPlan => 'Plan resetten';

  @override
  String get divePlanner_action_savePlan => 'Plan opslaan';

  @override
  String get divePlanner_error_cannotConvert =>
      'Kan niet omzetten: plan heeft kritieke waarschuwingen';

  @override
  String get divePlanner_error_reserveExceedsTank => 'Overschrijdt tankdruk';

  @override
  String get divePlanner_error_reserveMustBePositive =>
      'Moet groter zijn dan 0';

  @override
  String divePlanner_info_reserveDefault(Object unit, Object value) {
    return 'Niet ingevoerd — standaard $value $unit';
  }

  @override
  String get divePlanner_field_hePercent => 'He %';

  @override
  String get divePlanner_field_name => 'Naam';

  @override
  String get divePlanner_field_o2Percent => 'O₂ %';

  @override
  String get divePlanner_field_planName => 'Plannaam';

  @override
  String get divePlanner_field_role => 'Rol';

  @override
  String divePlanner_field_startPressure(Object pressureSymbol) {
    return 'Start ($pressureSymbol)';
  }

  @override
  String get divePlanner_field_travelGas => 'Ook gebruikt als reisgas';

  @override
  String divePlanner_field_volume(Object volumeSymbol) {
    return 'Volume ($volumeSymbol)';
  }

  @override
  String get divePlanner_hint_tankName => 'Voer flesnaam in';

  @override
  String get divePlanner_label_altitude => 'Hoogte:';

  @override
  String get divePlanner_label_belowMinReserve => 'Onder minimale reserve';

  @override
  String get divePlanner_label_ceiling => 'Plafond';

  @override
  String get divePlanner_label_consumption => 'Verbruik';

  @override
  String get divePlanner_label_deco => 'DECO';

  @override
  String get divePlanner_label_decoSchedule => 'Decompressieschema';

  @override
  String get divePlanner_label_decompression => 'Decompressie';

  @override
  String divePlanner_label_depthAxis(Object depthSymbol) {
    return 'Diepte ($depthSymbol)';
  }

  @override
  String get divePlanner_label_diveProfile => 'Duikprofiel';

  @override
  String get divePlanner_label_empty => 'LEEG';

  @override
  String get divePlanner_label_gasConsumption => 'Gasverbruik';

  @override
  String get divePlanner_label_gfHigh => 'GF hoog';

  @override
  String get divePlanner_label_gfLow => 'GF laag';

  @override
  String get divePlanner_label_max => 'Max';

  @override
  String get divePlanner_label_ndl => 'NDL';

  @override
  String get divePlanner_label_planSettings => 'Planinstellingen';

  @override
  String get divePlanner_label_remaining => 'Resterend';

  @override
  String get divePlanner_label_reserve => 'Reserve:';

  @override
  String get divePlanner_label_runtime => 'Looptijd';

  @override
  String get divePlanner_label_sacRate => 'RMV:';

  @override
  String get divePlanner_label_status => 'Status';

  @override
  String get divePlanner_label_tanks => 'Flessen';

  @override
  String get divePlanner_label_time => 'Tijd';

  @override
  String get divePlanner_label_timeAxis => 'Tijd (min)';

  @override
  String get divePlanner_label_tts => 'TTS';

  @override
  String get divePlanner_label_used => 'Gebruikt';

  @override
  String get divePlanner_label_warnings => 'Waarschuwingen';

  @override
  String get divePlanner_legend_ascent => 'Opstijgen';

  @override
  String get divePlanner_legend_bottom => 'Bodem';

  @override
  String get divePlanner_legend_deco => 'Deco';

  @override
  String get divePlanner_legend_descent => 'Afdalen';

  @override
  String get divePlanner_legend_safety => 'Veiligheid';

  @override
  String get divePlanner_message_addSegmentsForGas =>
      'Voeg segmenten toe om gasprognoses te zien';

  @override
  String get divePlanner_message_addSegmentsForProfile =>
      'Voeg segmenten toe om het duikprofiel te zien';

  @override
  String get divePlanner_message_convertingPlan => 'Plan omzetten naar duik...';

  @override
  String get divePlanner_message_noProfile => 'Geen profiel om weer te geven';

  @override
  String divePlanner_message_deleteConfirmation(String name) {
    return '\'$name\' verwijderen?';
  }

  @override
  String get divePlanner_message_planDeleted => 'Plan verwijderd';

  @override
  String get divePlanner_message_planSaved => 'Plan opgeslagen';

  @override
  String get divePlanner_message_resetConfirmation =>
      'Weet je zeker dat je het plan wilt resetten?';

  @override
  String divePlanner_semantics_criticalWarning(Object message) {
    return 'Kritieke waarschuwing: $message';
  }

  @override
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  ) {
    return 'Deco stop op $depth voor $duration op $gasMix';
  }

  @override
  String divePlanner_semantics_gasConsumption(
    Object tankName,
    Object gasUsed,
    Object remaining,
    Object percent,
    Object warning,
  ) {
    return '$tankName: $gasUsed gebruikt, $remaining resterend, $percent gebruikt$warning';
  }

  @override
  String divePlanner_semantics_profileChart(
    Object maxDepth,
    Object totalMinutes,
  ) {
    return 'Duikplan, max diepte $maxDepth, totale tijd $totalMinutes minuten';
  }

  @override
  String divePlanner_semantics_warning(Object message) {
    return 'Waarschuwing: $message';
  }

  @override
  String get divePlanner_tab_plan => 'Plan';

  @override
  String get divePlanner_tab_profile => 'Profiel';

  @override
  String get divePlanner_tab_results => 'Resultaten';

  @override
  String get divePlanner_warning_ascentRateHigh =>
      'Opstijgsnelheid overschrijdt veilige limiet';

  @override
  String divePlanner_warning_ascentRateHighWithRate(Object rate) {
    return 'Opstijgsnelheid $rate/min overschrijdt veilige limiet';
  }

  @override
  String divePlanner_warning_belowMinReserve(Object reserve) {
    return 'Onder minimale reserve ($reserve)';
  }

  @override
  String get divePlanner_warning_cnsCritical => 'CNS% overschrijdt 100%';

  @override
  String divePlanner_warning_cnsWarning(Object threshold) {
    return 'CNS% overschrijdt $threshold%';
  }

  @override
  String get divePlanner_warning_endHigh => 'Equivalent Narcotic Depth te hoog';

  @override
  String divePlanner_warning_endHighWithDepth(Object depth) {
    return 'END van $depth overschrijdt veilige limiet';
  }

  @override
  String divePlanner_warning_gasLow(Object threshold) {
    return 'Fles onder $threshold reserve';
  }

  @override
  String get divePlanner_warning_gasOut => 'Fles zal leeg zijn';

  @override
  String get divePlanner_warning_minGasViolation =>
      'Minimale gasreserve niet gehandhaafd';

  @override
  String get divePlanner_warning_modViolation =>
      'Gaswissel geprobeerd boven MOD';

  @override
  String get divePlanner_warning_ndlExceeded =>
      'Duik gaat in decompressieverplichting';

  @override
  String get divePlanner_warning_otuWarning => 'OTU ophoping hoog';

  @override
  String divePlanner_warning_ppO2Critical(Object value) {
    return 'ppO₂ van $value bar overschrijdt kritieke limiet';
  }

  @override
  String divePlanner_warning_ppO2High(Object value) {
    return 'ppO₂ van $value bar overschrijdt werkgrens';
  }

  @override
  String get diveSites_detail_access_accessNotes => 'Toegangsnotities';

  @override
  String get diveSites_detail_access_mooring => 'Aanlegplaats';

  @override
  String get diveSites_detail_access_parking => 'Parkeren';

  @override
  String get diveSites_detail_altitude_elevation => 'Hoogte';

  @override
  String get diveSites_detail_altitude_pressure => 'Druk';

  @override
  String get diveSites_detail_coordinatesCopied =>
      'Coordinaten gekopieerd naar klembord';

  @override
  String get diveSites_detail_deleteDialog_cancel => 'Annuleren';

  @override
  String get diveSites_detail_deleteDialog_confirm => 'Verwijderen';

  @override
  String get diveSites_detail_deleteDialog_content =>
      'Weet je zeker dat je deze stek wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.';

  @override
  String get diveSites_detail_deleteDialog_title => 'Stek verwijderen';

  @override
  String get diveSites_detail_deleteMenu_label => 'Verwijderen';

  @override
  String get diveSites_detail_deleteSnackbar => 'Stek verwijderd';

  @override
  String get diveSites_detail_depth_maximum => 'Maximum';

  @override
  String get diveSites_detail_depth_minimum => 'Minimum';

  @override
  String get diveSites_detail_diveCount_one => '1 duik gelogd';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '$count duiken gelogd';
  }

  @override
  String get diveSites_detail_diveCount_zero => 'Nog geen duiken gelogd';

  @override
  String get diveSites_detail_editTooltip => 'Stek bewerken';

  @override
  String get diveSites_detail_editTooltipShort => 'Bewerken';

  @override
  String diveSites_detail_error_body(Object error) {
    return 'Fout: $error';
  }

  @override
  String get diveSites_detail_error_title => 'Fout';

  @override
  String get diveSites_detail_loading_title => 'Laden...';

  @override
  String get diveSites_detail_location_country => 'Land';

  @override
  String get diveSites_detail_location_city => 'Stad';

  @override
  String get diveSites_detail_location_island => 'Eiland';

  @override
  String get diveSites_detail_location_bodyOfWater => 'Wateroppervlak';

  @override
  String get diveSites_detail_location_gpsCoordinates => 'GPS-coordinaten';

  @override
  String get diveSites_detail_location_notSet => 'Niet ingesteld';

  @override
  String get diveSites_detail_location_region => 'Regio';

  @override
  String get diveSites_detail_noDepthInfo => 'Geen diepte-informatie';

  @override
  String get diveSites_detail_noDescription => 'Geen beschrijving';

  @override
  String get diveSites_detail_noNotes => 'Geen notities';

  @override
  String get diveSites_detail_rating_notRated => 'Niet beoordeeld';

  @override
  String diveSites_detail_rating_value(Object rating) {
    return '$rating van 5';
  }

  @override
  String get diveSites_detail_section_access => 'Toegang & logistiek';

  @override
  String get diveSites_detail_section_altitude => 'Hoogte';

  @override
  String get diveSites_detail_section_depthRange => 'Dieptebereik';

  @override
  String get diveSites_detail_section_description => 'Beschrijving';

  @override
  String get diveSites_detail_section_difficultyLevel => 'Moeilijkheidsgraad';

  @override
  String get diveSites_detail_section_divesAtSite => 'Duiken op deze stek';

  @override
  String get diveSites_detail_section_hazards => 'Gevaren & veiligheid';

  @override
  String get diveSites_detail_section_location => 'Locatie';

  @override
  String get diveSites_detail_section_notes => 'Notities';

  @override
  String get diveSites_detail_section_rating => 'Beoordeling';

  @override
  String diveSites_detail_semantics_copyToClipboard(Object label) {
    return 'Kopieer $label naar klembord';
  }

  @override
  String get diveSites_detail_semantics_viewDivesAtSite =>
      'Bekijk duiken op deze stek';

  @override
  String get diveSites_detail_semantics_viewFullscreenMap =>
      'Bekijk kaart op volledig scherm';

  @override
  String get diveSites_detail_siteNotFound_body =>
      'Deze stek bestaat niet meer.';

  @override
  String get diveSites_detail_siteNotFound_title => 'Stek niet gevonden';

  @override
  String get diveSites_difficulty_advanced => 'Gevorderd';

  @override
  String get diveSites_difficulty_beginner => 'Beginner';

  @override
  String get diveSites_difficulty_intermediate => 'Gemiddeld';

  @override
  String get diveSites_difficulty_technical => 'Technisch';

  @override
  String get diveSites_edit_access_accessNotes_hint =>
      'Hoe je bij de stek komt, in-/uitstappunten, wal-/boottoegang';

  @override
  String get diveSites_edit_access_accessNotes_label => 'Toegangsnotities';

  @override
  String get diveSites_edit_access_mooringNumber_hint => 'bijv. Boei #12';

  @override
  String get diveSites_edit_access_mooringNumber_label => 'Boeinummer';

  @override
  String get diveSites_edit_access_parkingInfo_hint =>
      'Parkeergelegenheid, kosten, tips';

  @override
  String get diveSites_edit_access_parkingInfo_label => 'Parkeerinformatie';

  @override
  String get diveSites_edit_access_entryMethod_label => 'Instapmethode';

  @override
  String get diveSites_edit_access_exitMethod_label => 'Uitstapmethode';

  @override
  String diveSites_edit_access_entrySuggestionPair(
    int count,
    String entry,
    String exit,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Jouw $count duiken hier: instap $entry, uitstap $exit',
      one: 'Jouw duik hier: instap $entry, uitstap $exit',
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
      other: 'Jouw $count duiken hier: instap $entry',
      one: 'Jouw duik hier: instap $entry',
    );
    return '$_temp0';
  }

  @override
  String get diveSites_detail_access_entryMethod => 'Instap';

  @override
  String get diveSites_detail_access_exitMethod => 'Uitstap';

  @override
  String get diveSites_edit_altitude_helperText =>
      'Hoogte van de stek boven zeeniveau (voor hoogteduiken)';

  @override
  String get diveSites_edit_altitude_hint => 'bijv. 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return 'Hoogte ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => 'Ongeldige hoogte';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => 'Stek verwijderen';

  @override
  String get diveSites_edit_appBar_editSite => 'Stek bewerken';

  @override
  String get diveSites_edit_appBar_merge => 'Samenvoegen';

  @override
  String get diveSites_edit_appBar_mergeSites => 'Duiklocaties samenvoegen';

  @override
  String get diveSites_edit_appBar_newSite => 'Nieuwe stek';

  @override
  String get diveSites_edit_appBar_save => 'Opslaan';

  @override
  String get diveSites_edit_button_addSite => 'Stek toevoegen';

  @override
  String get diveSites_edit_button_mergeSites => 'Duiklocaties samenvoegen';

  @override
  String get diveSites_edit_button_saveChanges => 'Wijzigingen opslaan';

  @override
  String get diveSites_edit_cancel => 'Annuleren';

  @override
  String get diveSites_edit_depth_helperText =>
      'Van het ondiepste tot het diepste punt';

  @override
  String get diveSites_edit_depth_maxHint => 'bijv. 30';

  @override
  String diveSites_edit_depth_maxLabel(Object symbol) {
    return 'Maximale diepte ($symbol)';
  }

  @override
  String get diveSites_edit_depth_minHint => 'bijv. 5';

  @override
  String diveSites_edit_depth_minLabel(Object symbol) {
    return 'Minimale diepte ($symbol)';
  }

  @override
  String get diveSites_edit_depth_separator => 'tot';

  @override
  String get diveSites_edit_discardDialog_content =>
      'Je hebt niet-opgeslagen wijzigingen. Weet je zeker dat je wilt vertrekken?';

  @override
  String get diveSites_edit_discardDialog_discard => 'Verwerpen';

  @override
  String get diveSites_edit_discardDialog_keepEditing => 'Verder bewerken';

  @override
  String get diveSites_edit_discardDialog_title => 'Wijzigingen verwerpen?';

  @override
  String get diveSites_edit_field_country_label => 'Land';

  @override
  String get diveSites_edit_field_city_label => 'Stad';

  @override
  String get diveSites_edit_field_island_label => 'Eiland';

  @override
  String get diveSites_edit_field_bodyOfWater_label => 'Wateroppervlak';

  @override
  String get diveSites_edit_field_description_hint =>
      'Korte beschrijving van de stek';

  @override
  String get diveSites_edit_field_description_label => 'Beschrijving';

  @override
  String get diveSites_edit_field_notes_hint =>
      'Overige informatie over deze stek';

  @override
  String get diveSites_edit_field_notes_label => 'Algemene notities';

  @override
  String get diveSites_edit_field_region_label => 'Regio';

  @override
  String get diveSites_edit_field_siteName_hint => 'bijv. Blue Hole';

  @override
  String get diveSites_edit_field_siteName_label => 'Steknaam *';

  @override
  String get diveSites_edit_field_siteName_validation => 'Voer een steknaam in';

  @override
  String diveSites_similarSite_useHint(Object siteName) {
    return 'Vergelijkbaar met bestaande duiklocatie \"$siteName\". Tik om te gebruiken.';
  }

  @override
  String diveSites_similarSite_warning(Object siteName) {
    return 'Er bestaat al een vergelijkbare locatie: \"$siteName\"';
  }

  @override
  String get diveSites_edit_gps_gettingLocation => 'Ophalen...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Kies een locatiemethode of zoek de coördinaten op om land, regio, plaats en water automatisch in te vullen';

  @override
  String get diveSites_edit_gps_latitude_hint => 'bijv. 21.4225';

  @override
  String get diveSites_edit_gps_latitude_label => 'Breedtegraad';

  @override
  String get diveSites_edit_gps_latitude_validation => 'Ongeldige breedtegraad';

  @override
  String get diveSites_edit_gps_longitude_hint => 'bijv. -86.7542';

  @override
  String get diveSites_edit_gps_longitude_label => 'Lengtegraad';

  @override
  String get diveSites_edit_gps_longitude_validation => 'Ongeldige lengtegraad';

  @override
  String get diveSites_edit_gps_pickFromMap => 'Kies op de kaart';

  @override
  String get diveSites_edit_gps_lookupFromCoordinates =>
      'Opzoeken op coördinaten';

  @override
  String get diveSites_edit_snackbar_lookupNothingFound =>
      'Geen locatiegegevens gevonden voor deze coördinaten';

  @override
  String get diveSites_edit_snackbar_lookupFailed =>
      'Locatie opzoeken mislukt. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get diveSites_edit_lookupReplace_title => 'Locatiegegevens vervangen?';

  @override
  String get diveSites_edit_lookupReplace_body =>
      'Het opzoeken vond andere waarden voor deze velden:';

  @override
  String get diveSites_edit_lookupReplace_replace => 'Vervangen';

  @override
  String get diveSites_edit_lookupReplace_keep => 'Behouden';

  @override
  String get diveSites_edit_gps_useMyLocation => 'Gebruik mijn locatie';

  @override
  String get diveSites_edit_hazards_helperText =>
      'Vermeld eventuele gevaren of veiligheidsoverwegingen';

  @override
  String get diveSites_edit_hazards_hint =>
      'bijv. sterke stroming, bootverkeer, kwallen, scherp koraal';

  @override
  String get diveSites_edit_hazards_label => 'Gevaren';

  @override
  String get diveSites_edit_marineLife_addButton => 'Toevoegen';

  @override
  String get diveSites_edit_marineLife_empty =>
      'Geen verwachte soorten toegevoegd';

  @override
  String get diveSites_edit_marineLife_helperText =>
      'Soorten die je op deze stek verwacht te zien';

  @override
  String diveSites_edit_merge_confirmBody(int count) {
    return 'Dit voegt $count locaties samen tot één. Duiken, media en verwachte soorten worden gecombineerd onder de overgebleven locatie. De andere locaties worden verwijderd.';
  }

  @override
  String get diveSites_edit_merge_confirmTitle => 'Duiklocaties samenvoegen';

  @override
  String get diveSites_edit_merge_fieldSourceCycleTooltip =>
      'Waarde gebruiken van volgende geselecteerde locatie';

  @override
  String diveSites_edit_merge_fieldSourceLabel(
    Object siteName,
    int current,
    int total,
  ) {
    return 'Van $siteName ($current/$total)';
  }

  @override
  String get diveSites_edit_merge_fieldSourceMenuTooltip =>
      'Waarde selecteren van geselecteerde locatie';

  @override
  String get diveSites_edit_merge_marineLifeHelperText =>
      'Gecombineerd uit alle geselecteerde locaties';

  @override
  String diveSites_edit_merge_loadingErrorBody(Object error) {
    return 'Kan duiklocaties niet laden: $error';
  }

  @override
  String get diveSites_edit_merge_loadingErrorTitle =>
      'Duiklocaties samenvoegen';

  @override
  String get diveSites_edit_merge_notEnoughBody =>
      'Niet genoeg duiklocaties om samen te voegen.';

  @override
  String get diveSites_edit_merge_notEnoughTitle => 'Duiklocaties samenvoegen';

  @override
  String get diveSites_edit_rating_clear => 'Beoordeling wissen';

  @override
  String diveSites_edit_rating_starTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ren',
      one: '',
    );
    return '$count ster$_temp0';
  }

  @override
  String get diveSites_edit_section_access => 'Toegang & logistiek';

  @override
  String get diveSites_edit_section_altitude => 'Hoogte';

  @override
  String get diveSites_edit_section_depthRange => 'Dieptebereik';

  @override
  String get diveSites_edit_section_difficultyLevel => 'Moeilijkheidsgraad';

  @override
  String get diveSites_edit_section_expectedMarineLife => 'Verwacht zeeleven';

  @override
  String get diveSites_edit_section_gpsCoordinates => 'GPS-coordinaten';

  @override
  String get diveSites_edit_section_hazards => 'Gevaren & veiligheid';

  @override
  String get diveSites_edit_section_rating => 'Beoordeling';

  @override
  String get diveSites_edit_section_waterType => 'Watertype';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return 'Fout bij verwijderen van stek: $error';
  }

  @override
  String diveSites_edit_snackbar_errorSaving(Object error) {
    return 'Fout bij opslaan van stek: $error';
  }

  @override
  String get diveSites_edit_snackbar_locationCaptured => 'Locatie vastgelegd';

  @override
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Locatie vastgelegd (${accuracy}m)';
  }

  @override
  String get diveSites_edit_snackbar_locationSelectedFromMap =>
      'Locatie geselecteerd op de kaart';

  @override
  String get diveSites_edit_snackbar_locationSettings => 'Instellingen';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      'Kan locatie niet ophalen. Locatieservices zijn mogelijk niet beschikbaar.';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      'Kan locatie niet ophalen. Controleer de machtigingen.';

  @override
  String get diveSites_edit_snackbar_siteAdded => 'Stek toegevoegd';

  @override
  String get diveSites_edit_snackbar_sitesMerged => 'Duiklocaties samengevoegd';

  @override
  String get diveSites_edit_snackbar_siteUpdated => 'Stek bijgewerkt';

  @override
  String get diveSites_fab_label => 'Stek toevoegen';

  @override
  String get diveSites_fab_tooltip => 'Een nieuwe duikstek toevoegen';

  @override
  String get diveSites_filter_apply => 'Filters toepassen';

  @override
  String get diveSites_filter_cancel => 'Annuleren';

  @override
  String get diveSites_filter_clearAll => 'Alles wissen';

  @override
  String get diveSites_filter_country_hint => 'bijv. Thailand';

  @override
  String get diveSites_filter_country_label => 'Land';

  @override
  String get diveSites_filter_depth_max_label => 'Max';

  @override
  String get diveSites_filter_depth_min_label => 'Min';

  @override
  String get diveSites_filter_depth_separator => 'tot';

  @override
  String get diveSites_filter_difficulty_any => 'Alle';

  @override
  String get diveSites_filter_option_hasCoordinates_subtitle =>
      'Toon alleen stekken met GPS-locatie';

  @override
  String get diveSites_filter_option_hasCoordinates_title =>
      'Heeft coordinaten';

  @override
  String get diveSites_filter_option_hasDives_subtitle =>
      'Toon alleen stekken met gelogde duiken';

  @override
  String get diveSites_filter_option_hasDives_title => 'Heeft duiken';

  @override
  String diveSites_filter_rating_starsPlus(Object count) {
    return '$count+ sterren';
  }

  @override
  String get diveSites_filter_region_hint => 'bijv. Phuket';

  @override
  String get diveSites_filter_region_label => 'Regio';

  @override
  String get diveSites_filter_section_depthRange => 'Max dieptebereik';

  @override
  String get diveSites_filter_section_difficulty => 'Moeilijkheidsgraad';

  @override
  String get diveSites_filter_section_location => 'Locatie';

  @override
  String get diveSites_filter_section_minRating => 'Minimale beoordeling';

  @override
  String get diveSites_filter_section_options => 'Opties';

  @override
  String get diveSites_filter_title => 'Stekken filteren';

  @override
  String get diveSites_import_appBar_title => 'Duikstek importeren';

  @override
  String get diveSites_import_badge_imported => 'Geimporteerd';

  @override
  String get diveSites_import_badge_saved => 'Opgeslagen';

  @override
  String get diveSites_import_button_import => 'Importeren';

  @override
  String get diveSites_import_detail_alreadyImported => 'Reeds geimporteerd';

  @override
  String get diveSites_import_detail_importToMySites =>
      'Importeren naar mijn stekken';

  @override
  String diveSites_import_detail_source(Object source) {
    return 'Bron: $source';
  }

  @override
  String get diveSites_import_empty_description =>
      'Zoek naar duikstekken uit onze database van populaire\nduikbestemmingen over de hele wereld.';

  @override
  String get diveSites_import_empty_hint =>
      'Probeer te zoeken op steknaam, land of regio.';

  @override
  String get diveSites_import_empty_title => 'Zoek duikstekken';

  @override
  String get diveSites_import_error_retry => 'Opnieuw proberen';

  @override
  String get diveSites_import_error_title => 'Zoekfout';

  @override
  String get diveSites_import_error_unknown => 'Onbekende fout';

  @override
  String get diveSites_import_externalSite_locationUnknown =>
      'Locatie onbekend';

  @override
  String get diveSites_import_label_gps => 'GPS';

  @override
  String get diveSites_import_localSite_locationNotSet =>
      'Locatie niet ingesteld';

  @override
  String diveSites_import_noResults_description(Object query) {
    return 'Geen duikstekken gevonden voor \"$query\".\nProbeer een andere zoekterm.';
  }

  @override
  String get diveSites_import_noResults_title => 'Geen resultaten';

  @override
  String get diveSites_import_quickSearch_caribbean => 'Caribisch gebied';

  @override
  String get diveSites_import_quickSearch_indonesia => 'Indonesie';

  @override
  String get diveSites_import_quickSearch_maldives => 'Malediven';

  @override
  String get diveSites_import_quickSearch_philippines => 'Filipijnen';

  @override
  String get diveSites_import_quickSearch_redSea => 'Rode Zee';

  @override
  String get diveSites_import_quickSearch_thailand => 'Thailand';

  @override
  String get diveSites_import_search_clearTooltip => 'Zoekopdracht wissen';

  @override
  String get diveSites_import_search_hint =>
      'Zoek duikstekken (bijv. \"Blue Hole\", \"Thailand\")';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return 'Importeren uit database ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return 'Mijn stekken ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return 'Details bekijken voor $name';
  }

  @override
  String diveSites_import_semantics_viewSavedSite(Object name) {
    return 'Opgeslagen stek $name bekijken';
  }

  @override
  String get diveSites_import_snackbar_failed => 'Importeren van stek mislukt';

  @override
  String diveSites_import_snackbar_imported(Object name) {
    return '\"$name\" geimporteerd';
  }

  @override
  String get diveSites_import_snackbar_viewAction => 'Bekijken';

  @override
  String get diveSites_list_activeFilter_clear => 'Wissen';

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
    return 'Tot $max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '$min+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => 'Heeft coordinaten';

  @override
  String get diveSites_list_activeFilter_hasDives => 'Heeft duiken';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return 'Regio: $region';
  }

  @override
  String get diveSites_list_appBar_title => 'Duikstekken';

  @override
  String get diveSites_list_bulkDelete_cancel => 'Annuleren';

  @override
  String get diveSites_list_bulkDelete_confirm => 'Verwijderen';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'stekken',
      one: 'stek',
    );
    return 'Weet je zeker dat je $count $_temp0 wilt verwijderen? Deze actie kan binnen 5 seconden ongedaan worden gemaakt.';
  }

  @override
  String get diveSites_list_bulkDelete_restored => 'Stekken hersteld';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'stekken',
      one: 'stek',
    );
    return '$count $_temp0 verwijderd';
  }

  @override
  String get diveSites_list_bulkDelete_title => 'Stekken verwijderen';

  @override
  String get diveSites_list_bulkDelete_undo => 'Ongedaan maken';

  @override
  String get diveSites_list_merge_restored => 'Samenvoeging ongedaan gemaakt';

  @override
  String diveSites_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'stekken',
      one: 'stek',
    );
    return '$count $_temp0 samengevoegd';
  }

  @override
  String get diveSites_list_merge_undo => 'Ongedaan maken';

  @override
  String get diveSites_list_emptyFiltered_clearAll => 'Alle filters wissen';

  @override
  String get diveSites_list_emptyFiltered_subtitle =>
      'Probeer je filters aan te passen of te wissen';

  @override
  String get diveSites_list_emptyFiltered_title =>
      'Geen stekken komen overeen met je filters';

  @override
  String get diveSites_list_empty_addFirstSite => 'Voeg je eerste stek toe';

  @override
  String get diveSites_list_empty_import => 'Importeren';

  @override
  String get diveSites_list_empty_subtitle =>
      'Voeg duikstekken toe om je favoriete locaties bij te houden';

  @override
  String get diveSites_list_empty_title => 'Nog geen duikstekken';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return 'Fout bij laden van stekken: $error';
  }

  @override
  String get diveSites_list_error_retry => 'Opnieuw proberen';

  @override
  String get diveSites_list_menu_import => 'Importeren';

  @override
  String get diveSites_list_menu_select => 'Duikstekken selecteren';

  @override
  String get diveSites_list_menu_fillLocationDetails =>
      'Ontbrekende locatiegegevens aanvullen';

  @override
  String get diveSites_backfill_confirm_title =>
      'Ontbrekende locatiegegevens aanvullen?';

  @override
  String diveSites_backfill_confirm_body(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count duikstekken met coördinaten hebben geen land, regio, plaats of water.',
      one:
          '1 duikstek met coördinaten heeft geen land, regio, plaats of water.',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuten',
      one: '1 minuut',
    );
    return '$_temp0 Submersion zoekt elke stek op via OpenStreetMap en vult alleen lege velden in. Dit duurt ongeveer $_temp1.';
  }

  @override
  String get diveSites_backfill_confirm_start => 'Starten';

  @override
  String get diveSites_backfill_nothingToFill =>
      'Elke duikstek met coördinaten heeft al locatiegegevens.';

  @override
  String get diveSites_backfill_progress_title => 'Locatiegegevens aanvullen';

  @override
  String diveSites_backfill_progress_count(int done, int total) {
    return '$done van $total';
  }

  @override
  String get diveSites_backfill_cancel => 'Annuleren';

  @override
  String diveSites_backfill_summary(int updated, int unchanged, int failed) {
    return 'Bijgewerkt $updated, ongewijzigd $unchanged, mislukt $failed';
  }

  @override
  String get diveSites_backfill_offline =>
      'Locatie opzoeken is niet beschikbaar. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get diveSites_list_search_backTooltip => 'Terug';

  @override
  String get diveSites_list_search_clearTooltip => 'Zoekopdracht wissen';

  @override
  String get diveSites_list_search_emptyHint =>
      'Zoek op steknaam, land of regio';

  @override
  String diveSites_list_search_error(Object error) {
    return 'Fout: $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return 'Geen stekken gevonden voor \"$query\"';
  }

  @override
  String get diveSites_list_search_placeholder => 'Stekken zoeken...';

  @override
  String get diveSites_list_selection_closeTooltip => 'Selectie sluiten';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count geselecteerd';
  }

  @override
  String get diveSites_list_selection_deleteTooltip =>
      'Geselecteerde verwijderen';

  @override
  String get diveSites_list_selection_mergeTooltip =>
      'Geselecteerde samenvoegen';

  @override
  String get diveSites_list_selection_deselectAllTooltip =>
      'Alles deselecteren';

  @override
  String get diveSites_list_selection_selectAllTooltip => 'Alles selecteren';

  @override
  String get diveSites_list_sort_title => 'Stekken sorteren';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken',
      one: '1 duik',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return 'Duikstek: $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => 'Stekken filteren';

  @override
  String get diveSites_list_tooltip_mapView => 'Kaartweergave';

  @override
  String get diveSites_list_tooltip_searchSites => 'Stekken zoeken';

  @override
  String get diveSites_list_tooltip_sort => 'Sorteren';

  @override
  String get diveSites_locationPicker_appBar_title => 'Locatie kiezen';

  @override
  String get diveSites_locationPicker_confirmButton => 'Bevestigen';

  @override
  String get diveSites_locationPicker_confirmTooltip =>
      'Geselecteerde locatie bevestigen';

  @override
  String get diveSites_locationPicker_fab_tooltip => 'Gebruik mijn locatie';

  @override
  String get diveSites_locationPicker_instruction_locationSelected =>
      'Locatie geselecteerd';

  @override
  String get diveSites_locationPicker_instruction_lookingUp =>
      'Locatie opzoeken...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect =>
      'Tik op de kaart om een locatie te selecteren';

  @override
  String get diveSites_locationPicker_label_latitude => 'Breedtegraad';

  @override
  String get diveSites_locationPicker_label_longitude => 'Lengtegraad';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return 'Geselecteerde coordinaten: breedtegraad $latitude, lengtegraad $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp => 'Locatie opzoeken';

  @override
  String get diveSites_locationPicker_semantics_map =>
      'Interactieve kaart om een duiksteklocatie te kiezen. Tik op de kaart om een locatie te selecteren.';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return 'Fout bij laden van duikstekken: $error';
  }

  @override
  String get diveSites_map_appBar_title => 'Duikstekken';

  @override
  String get diveSites_map_builtInSites_add => 'Toevoegen aan mijn stekken';

  @override
  String get diveSites_map_builtInSites_addError =>
      'Kon stek niet toevoegen. Probeer het opnieuw.';

  @override
  String get diveSites_map_builtInSites_added => 'Toegevoegd aan je stekken';

  @override
  String get diveSites_map_builtInSites_hide => 'Ingebouwde stekken verbergen';

  @override
  String get diveSites_map_builtInSites_off => 'Ingebouwde stekken verborgen';

  @override
  String get diveSites_map_builtInSites_on => 'Ingebouwde stekken getoond';

  @override
  String get diveSites_map_builtInSites_show => 'Ingebouwde stekken tonen';

  @override
  String get diveSites_map_empty_description =>
      'Voeg coordinaten toe aan je duikstekken om ze op de kaart te zien';

  @override
  String get diveSites_map_empty_title => 'Geen stekken met coordinaten';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return 'Fout bij laden van stekken: $error';
  }

  @override
  String get diveSites_map_error_retry => 'Opnieuw proberen';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken',
      one: '1 duik',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_builtInSiteMarker(Object name) {
    return 'Ingebouwde duikstek: $name';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return 'Duikstek: $name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => 'Alle stekken tonen';

  @override
  String get diveSites_map_tooltip_listView => 'Lijstweergave';

  @override
  String get diveSites_summary_action_addSite => 'Stek toevoegen';

  @override
  String get diveSites_summary_action_import => 'Importeren';

  @override
  String get diveSites_summary_action_viewMap => 'Kaart bekijken';

  @override
  String diveSites_summary_countriesMore(Object count) {
    return '+ $count meer';
  }

  @override
  String get diveSites_summary_header_subtitle =>
      'Selecteer een stek uit de lijst om details te bekijken';

  @override
  String get diveSites_summary_header_title => 'Duikstekken';

  @override
  String get diveSites_summary_section_countriesRegions => 'Landen & regio\'s';

  @override
  String get diveSites_summary_section_mostDived => 'Meest bedoken';

  @override
  String get diveSites_summary_section_overview => 'Overzicht';

  @override
  String get diveSites_summary_section_quickActions => 'Snelle acties';

  @override
  String get diveSites_summary_section_topRated => 'Hoogst beoordeeld';

  @override
  String get diveSites_summary_stat_avgRating => 'Gem. beoordeling';

  @override
  String get diveSites_summary_stat_totalDives => 'Totaal duiken';

  @override
  String get diveSites_summary_stat_totalSites => 'Totaal stekken';

  @override
  String get diveSites_summary_stat_withGps => 'Met GPS';

  @override
  String get diveType_builtin_altitude => 'Hoogte';

  @override
  String get diveType_builtin_boat => 'Vanaf boot';

  @override
  String get diveType_builtin_cave => 'Grot';

  @override
  String get diveType_builtin_cavern => 'Cavern';

  @override
  String get diveType_builtin_deep => 'Diep';

  @override
  String get diveType_builtin_drift => 'Stroming';

  @override
  String get diveType_builtin_freedive => 'Vrijduiken';

  @override
  String get diveType_builtin_ice => 'IJs';

  @override
  String get diveType_builtin_liveaboard => 'Liveaboard';

  @override
  String get diveType_builtin_night => 'Nacht';

  @override
  String get diveType_builtin_recreational => 'Recreatief';

  @override
  String get diveType_builtin_shore => 'Vanaf de kant';

  @override
  String get diveType_builtin_technical => 'Technisch';

  @override
  String get diveType_builtin_training => 'Opleiding';

  @override
  String get diveType_builtin_wreck => 'Wrak';

  @override
  String get diveTypes_addDialog_addButton => 'Toevoegen';

  @override
  String get diveTypes_addDialog_nameHint => 'bijv. Zoeken & Bergen';

  @override
  String get diveTypes_addDialog_nameLabel => 'Duiktype naam';

  @override
  String get diveTypes_addDialog_nameValidation => 'Voer een naam in';

  @override
  String get diveTypes_addDialog_title => 'Aangepast duiktype toevoegen';

  @override
  String get diveTypes_addTooltip => 'Duiktype toevoegen';

  @override
  String get diveTypes_appBar_title => 'Duiktypes';

  @override
  String get diveTypes_builtIn => 'Ingebouwd';

  @override
  String get diveTypes_builtInHeader => 'Ingebouwde duiktypes';

  @override
  String get diveTypes_custom => 'Aangepast';

  @override
  String get diveTypes_customHeader => 'Aangepaste duiktypes';

  @override
  String diveTypes_deleteDialog_content(Object name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen?';
  }

  @override
  String get diveTypes_deleteDialog_title => 'Duiktype verwijderen?';

  @override
  String get diveTypes_deleteTooltip => 'Duiktype verwijderen';

  @override
  String diveTypes_snackbar_added(Object name) {
    return 'Duiktype toegevoegd: $name';
  }

  @override
  String diveTypes_snackbar_cannotDelete(Object name) {
    return 'Kan \"$name\" niet verwijderen - wordt gebruikt door bestaande duiken';
  }

  @override
  String diveTypes_snackbar_deleted(Object name) {
    return '\"$name\" verwijderd';
  }

  @override
  String diveTypes_snackbar_errorAdding(Object error) {
    return 'Fout bij toevoegen duiktype: $error';
  }

  @override
  String diveTypes_snackbar_errorDeleting(Object error) {
    return 'Fout bij verwijderen duiktype: $error';
  }

  @override
  String get divers_detail_activeDiver => 'Actieve duiker';

  @override
  String get divers_detail_allergiesLabel => 'Allergieen';

  @override
  String get divers_detail_appBarTitle => 'Duiker';

  @override
  String get divers_detail_bloodTypeLabel => 'Bloedgroep';

  @override
  String get divers_detail_bottomTimeLabel => 'Bodemtijd';

  @override
  String get divers_detail_cancelButton => 'Annuleren';

  @override
  String get divers_detail_contactTitle => 'Contact';

  @override
  String get divers_detail_defaultLabel => 'Standaard';

  @override
  String get divers_detail_deleteButton => 'Verwijderen';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'This will permanently delete $name and all associated data including dive logs, dive computers, equipment, certifications, and sites.';
  }

  @override
  String get divers_detail_deleteDialogTitle => 'Duiker verwijderen?';

  @override
  String divers_detail_deleteError(Object error) {
    return 'Verwijderen mislukt: $error';
  }

  @override
  String get divers_detail_deleteMenuItem => 'Verwijderen';

  @override
  String get divers_detail_deletedSnackbar => 'Duiker verwijderd';

  @override
  String get divers_detail_diveInsuranceTitle => 'Duikverzekering';

  @override
  String get divers_detail_diveStatisticsTitle => 'Duikstatistieken';

  @override
  String get divers_detail_editTooltip => 'Duiker bewerken';

  @override
  String get divers_detail_emergencyContactTitle => 'Noodcontact';

  @override
  String divers_detail_errorPrefix(Object error) {
    return 'Fout: $error';
  }

  @override
  String get divers_detail_expiredBadge => 'Verlopen';

  @override
  String get divers_detail_expiresLabel => 'Verloopt';

  @override
  String get divers_detail_medicalInfoTitle => 'Medische informatie';

  @override
  String get divers_detail_medicalNotesLabel => 'Notities';

  @override
  String get divers_detail_notFound => 'Duiker niet gevonden';

  @override
  String get divers_detail_notesTitle => 'Notities';

  @override
  String get divers_detail_policyNumberLabel => 'Polisnr.';

  @override
  String get divers_detail_providerLabel => 'Verzekeraar';

  @override
  String get divers_detail_setAsDefault => 'Instellen als standaard';

  @override
  String divers_detail_setAsDefaultSnackbar(Object name) {
    return '$name ingesteld als standaardduiker';
  }

  @override
  String get divers_detail_switchToTooltip => 'Overschakelen naar deze duiker';

  @override
  String divers_detail_switchedTo(Object name) {
    return 'Overgeschakeld naar $name';
  }

  @override
  String get divers_detail_totalDivesLabel => 'Totaal duiken';

  @override
  String get divers_detail_unableToLoadStats => 'Kan statistieken niet laden';

  @override
  String get divers_edit_addButton => 'Duiker toevoegen';

  @override
  String get divers_edit_addTitle => 'Duiker toevoegen';

  @override
  String get divers_edit_allergiesHint => 'bijv. Penicilline, Schaaldieren';

  @override
  String get divers_edit_allergiesLabel => 'Allergieen';

  @override
  String get divers_edit_bloodTypeHint => 'bijv. O+, A-, B+';

  @override
  String get divers_edit_bloodTypeLabel => 'Bloedgroep';

  @override
  String get divers_edit_cancelButton => 'Annuleren';

  @override
  String get divers_edit_clearInsuranceExpiryTooltip =>
      'Vervaldatum verzekering wissen';

  @override
  String get divers_edit_clearMedicalClearanceTooltip =>
      'Datum medische keuring wissen';

  @override
  String get divers_edit_contactNameLabel => 'Contactnaam';

  @override
  String get divers_edit_contactPhoneLabel => 'Contacttelefoon';

  @override
  String get divers_edit_discardButton => 'Verwerpen';

  @override
  String get divers_edit_discardDialogContent =>
      'Je hebt niet-opgeslagen wijzigingen. Weet je zeker dat je ze wilt verwerpen?';

  @override
  String get divers_edit_discardDialogTitle => 'Wijzigingen verwerpen?';

  @override
  String get divers_edit_diverAdded => 'Duiker toegevoegd';

  @override
  String get divers_edit_diverUpdated => 'Duiker bijgewerkt';

  @override
  String get divers_edit_editTitle => 'Duiker bewerken';

  @override
  String get divers_edit_emailError => 'Voer een geldig e-mailadres in';

  @override
  String get divers_edit_emailLabel => 'E-mail';

  @override
  String get divers_edit_emergencyContactsSection => 'Noodcontacten';

  @override
  String divers_edit_errorLoading(Object error) {
    return 'Fout bij laden van duiker: $error';
  }

  @override
  String divers_edit_errorSaving(Object error) {
    return 'Fout bij opslaan van duiker: $error';
  }

  @override
  String get divers_edit_expiryDateNotSet => 'Niet ingesteld';

  @override
  String get divers_edit_expiryDateTitle => 'Vervaldatum';

  @override
  String get divers_edit_insuranceProviderHint => 'bijv. DAN, DiveAssure';

  @override
  String get divers_edit_insuranceProviderLabel => 'Verzekeraar';

  @override
  String get divers_edit_insuranceSection => 'Duikverzekering';

  @override
  String get divers_edit_keepEditingButton => 'Verder bewerken';

  @override
  String get divers_edit_medicalClearanceExpired => 'Verlopen';

  @override
  String get divers_edit_medicalClearanceExpiringSoon => 'Verloopt binnenkort';

  @override
  String get divers_edit_medicalClearanceNotSet => 'Niet ingesteld';

  @override
  String get divers_edit_medicalClearanceTitle =>
      'Vervaldatum medische keuring';

  @override
  String get divers_edit_medicalInfoSection => 'Medische informatie';

  @override
  String get divers_edit_medicalNotesLabel => 'Medische notities';

  @override
  String get divers_edit_medicationsHint => 'bijv. Aspirine dagelijks, EpiPen';

  @override
  String get divers_edit_medicationsLabel => 'Medicijnen';

  @override
  String get divers_edit_nameError => 'Naam is verplicht';

  @override
  String get divers_edit_nameLabel => 'Naam *';

  @override
  String get divers_edit_notesLabel => 'Notities';

  @override
  String get divers_edit_notesSection => 'Notities';

  @override
  String get divers_edit_personalInfoSection => 'Persoonlijke gegevens';

  @override
  String get divers_edit_phoneLabel => 'Telefoon';

  @override
  String get divers_edit_policyNumberLabel => 'Polisnummer';

  @override
  String get divers_edit_primaryContactTitle => 'Primair contact';

  @override
  String get divers_edit_relationshipHint => 'bijv. Partner, Ouder, Vriend';

  @override
  String get divers_edit_relationshipLabel => 'Relatie';

  @override
  String get divers_edit_saveButton => 'Opslaan';

  @override
  String get divers_edit_secondaryContactTitle => 'Secundair contact';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip =>
      'Vervaldatum verzekering selecteren';

  @override
  String get divers_edit_selectMedicalClearanceTooltip =>
      'Datum medische keuring selecteren';

  @override
  String get divers_edit_updateButton => 'Duiker bijwerken';

  @override
  String get divers_list_activeBadge => 'Actief';

  @override
  String get divers_list_addDiverButton => 'Duiker toevoegen';

  @override
  String get divers_list_addDiverTooltip => 'Nieuw duikersprofiel toevoegen';

  @override
  String get divers_list_appBarTitle => 'Duikersprofielen';

  @override
  String get divers_list_compactTitle => 'Duikers';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount duiken$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle =>
      'Voeg duikersprofielen toe om duiklogs bij te houden voor meerdere personen';

  @override
  String get divers_list_emptyTitle => 'Nog geen duikers';

  @override
  String divers_list_errorLoading(Object error) {
    return 'Fout bij laden van duikers: $error';
  }

  @override
  String get divers_list_errorLoadingStats => 'Fout bij laden van statistieken';

  @override
  String get divers_list_loadingStats => 'Laden...';

  @override
  String get divers_list_retryButton => 'Opnieuw proberen';

  @override
  String divers_list_viewDiverLabel(Object name) {
    return 'Duiker $name bekijken';
  }

  @override
  String get divers_summary_activeDiverTitle => 'Actieve duiker';

  @override
  String get divers_summary_otherDiversTitle => 'Andere duikers';

  @override
  String get divers_summary_overviewTitle => 'Overzicht';

  @override
  String get divers_summary_quickActionsTitle => 'Snelle acties';

  @override
  String get divers_summary_subtitle =>
      'Selecteer een duiker uit de lijst om details te bekijken';

  @override
  String get divers_summary_title => 'Duikersprofielen';

  @override
  String get divers_summary_totalDiversLabel => 'Totaal duikers';

  @override
  String divers_detail_deleteDialogConfirmHint(String name) {
    return 'Type \"Delete $name\" to confirm';
  }

  @override
  String divers_detail_deleteDialogConfirmText(String name) {
    return 'Delete $name';
  }

  @override
  String get enum_altitudeGroup_extreme => 'Extreme hoogte';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => 'Hoogtegroep 1';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => 'Hoogtegroep 2';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => 'Hoogtegroep 3';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => 'Zeeniveau';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => 'Gevaar';

  @override
  String get enum_ascentRate_safe => 'Veilig';

  @override
  String get enum_ascentRate_warning => 'Waarschuwing';

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
  String get enum_certificationAgency_other => 'Overig';

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
  String get enum_certificationLevel_advancedNitrox => 'Gevorderd Nitrox';

  @override
  String get enum_certificationLevel_advancedOpenWater =>
      'Gevorderd Open Water';

  @override
  String get enum_certificationLevel_cave => 'Grotduiken';

  @override
  String get enum_certificationLevel_cavern => 'Cavernduiken';

  @override
  String get enum_certificationLevel_courseDirector => 'Cursusleider';

  @override
  String get enum_certificationLevel_decompression => 'Decompressie';

  @override
  String get enum_certificationLevel_diveGuide => 'Duikgids';

  @override
  String get enum_certificationLevel_diveMaster => 'Divemaster';

  @override
  String get enum_certificationLevel_instructor => 'Instructeur';

  @override
  String get enum_certificationLevel_masterInstructor => 'Master Instructeur';

  @override
  String get enum_certificationLevel_nitrox => 'Nitrox';

  @override
  String get enum_certificationLevel_openWater => 'Open Water';

  @override
  String get enum_certificationLevel_other => 'Overig';

  @override
  String get enum_certificationLevel_rebreather => 'Rebreather';

  @override
  String get enum_certificationLevel_rescue => 'Reddingsduiker';

  @override
  String get enum_certificationLevel_sidemount => 'Sidemount';

  @override
  String get enum_certificationLevel_techDiver => 'Technisch duiker';

  @override
  String get enum_certificationLevel_trimix => 'Trimix';

  @override
  String get enum_certificationLevel_wreck => 'Wrakduiken';

  @override
  String get enum_currentDirection_east => 'Oost';

  @override
  String get enum_currentDirection_none => 'Geen';

  @override
  String get enum_currentDirection_north => 'Noord';

  @override
  String get enum_currentDirection_northEast => 'Noordoost';

  @override
  String get enum_currentDirection_northWest => 'Noordwest';

  @override
  String get enum_currentDirection_south => 'Zuid';

  @override
  String get enum_currentDirection_southEast => 'Zuidoost';

  @override
  String get enum_currentDirection_southWest => 'Zuidwest';

  @override
  String get enum_currentDirection_variable => 'Wisselend';

  @override
  String get enum_currentDirection_west => 'West';

  @override
  String get enum_currentStrength_light => 'Licht';

  @override
  String get enum_currentStrength_moderate => 'Matig';

  @override
  String get enum_currentStrength_none => 'Geen';

  @override
  String get enum_currentStrength_strong => 'Sterk';

  @override
  String get enum_diveMode_ccr => 'Gesloten Circuit Rebreather';

  @override
  String get enum_diveMode_gauge => 'Gauge';

  @override
  String get enum_diveMode_oc => 'Open Circuit';

  @override
  String get enum_diveMode_scr => 'Semi-gesloten Rebreather';

  @override
  String get enum_diveType_altitude => 'Hoogte';

  @override
  String get enum_diveType_boat => 'Boot';

  @override
  String get enum_diveType_cave => 'Grot';

  @override
  String get enum_diveType_deep => 'Diep';

  @override
  String get enum_diveType_drift => 'Drift';

  @override
  String get enum_diveType_freedive => 'Vrijduiken';

  @override
  String get enum_diveType_ice => 'IJs';

  @override
  String get enum_diveType_liveaboard => 'Duiksafari';

  @override
  String get enum_diveType_night => 'Nacht';

  @override
  String get enum_diveType_recreational => 'Recreatief';

  @override
  String get enum_diveType_shore => 'Kant';

  @override
  String get enum_diveType_technical => 'Technisch';

  @override
  String get enum_diveType_training => 'Training';

  @override
  String get enum_diveType_wreck => 'Wrak';

  @override
  String get enum_entryMethod_backRoll => 'Achterwaartse rol';

  @override
  String get enum_entryMethod_boat => 'Instap vanaf boot';

  @override
  String get enum_entryMethod_giantStride => 'Grote stap';

  @override
  String get enum_entryMethod_jetty => 'Steiger/Kade';

  @override
  String get enum_entryMethod_ladder => 'Ladder';

  @override
  String get enum_entryMethod_other => 'Overig';

  @override
  String get enum_entryMethod_platform => 'Platform';

  @override
  String get enum_entryMethod_seatedEntry => 'Zittende instap';

  @override
  String get enum_entryMethod_shore => 'Instap vanaf kant';

  @override
  String get enum_equipmentStatus_active => 'Actief';

  @override
  String get enum_equipmentStatus_inService => 'In onderhoud';

  @override
  String get enum_equipmentStatus_loaned => 'Uitgeleend';

  @override
  String get enum_equipmentStatus_lost => 'Verloren';

  @override
  String get enum_equipmentStatus_needsService => 'Onderhoud nodig';

  @override
  String get enum_equipmentStatus_retired => 'Uit gebruik';

  @override
  String get enum_equipmentType_bcd => 'Trimvest';

  @override
  String get enum_equipmentType_boots => 'Laarzen';

  @override
  String get enum_equipmentType_camera => 'Camera';

  @override
  String get enum_equipmentType_dpv => 'DPV';

  @override
  String get enum_equipmentType_computer => 'Duikcomputer';

  @override
  String get enum_equipmentType_drysuit => 'Droogpak';

  @override
  String get enum_equipmentType_fins => 'Vinnen';

  @override
  String get enum_equipmentType_gloves => 'Handschoenen';

  @override
  String get enum_equipmentType_hood => 'Kap';

  @override
  String get enum_equipmentType_knife => 'Mes';

  @override
  String get enum_equipmentType_light => 'Lamp';

  @override
  String get enum_equipmentType_mask => 'Masker';

  @override
  String get enum_equipmentType_other => 'Overig';

  @override
  String get enum_equipmentType_reel => 'Haspel';

  @override
  String get enum_equipmentType_regulator => 'Ademautomaat';

  @override
  String get enum_equipmentType_smb => 'SMB';

  @override
  String get enum_equipmentType_tank => 'Fles';

  @override
  String get enum_equipmentType_weights => 'Gewichten';

  @override
  String get enum_equipmentType_wetsuit => 'Wetsuit';

  @override
  String get enum_eventSeverity_alert => 'Alarm';

  @override
  String get enum_eventSeverity_info => 'Info';

  @override
  String get enum_eventSeverity_warning => 'Waarschuwing';

  @override
  String get enum_pdfPageSize_a4 => 'A4';

  @override
  String get enum_pdfPageSize_a4_description => '210 x 297 mm';

  @override
  String get enum_pdfPageSize_letter => 'Letter';

  @override
  String get enum_pdfPageSize_letter_description => '8.5 x 11 in';

  @override
  String get enum_pdfTemplate_detailed => 'Gedetailleerd';

  @override
  String get enum_pdfTemplate_detailed_description =>
      'Volledige duikinformatie met notities en beoordelingen';

  @override
  String get enum_pdfTemplate_nauiStyle => 'NAUI Stijl';

  @override
  String get enum_pdfTemplate_nauiStyle_description =>
      'Lay-out volgens NAUI logboekformaat';

  @override
  String get enum_pdfTemplate_padiStyle => 'PADI Stijl';

  @override
  String get enum_pdfTemplate_padiStyle_description =>
      'Lay-out volgens PADI logboekformaat';

  @override
  String get enum_pdfTemplate_professional => 'Professioneel';

  @override
  String get enum_pdfTemplate_professional_description =>
      'Handtekening- en stempelvelden voor verificatie';

  @override
  String get enum_pdfTemplate_simple => 'Eenvoudig';

  @override
  String get enum_pdfTemplate_simple_description =>
      'Compact tabelformaat, veel duiken per pagina';

  @override
  String get enum_profileEvent_alert => 'Alarm';

  @override
  String get enum_profileEvent_ascentRateCritical => 'Opstijgsnelheid kritiek';

  @override
  String get enum_profileEvent_ascentRateWarning =>
      'Waarschuwing opstijgsnelheid';

  @override
  String get enum_profileEvent_ascentStart => 'Begin opstijging';

  @override
  String get enum_profileEvent_bookmark => 'Bladwijzer';

  @override
  String get enum_profileEvent_cnsCritical => 'CNS kritiek';

  @override
  String get enum_profileEvent_cnsWarning => 'CNS waarschuwing';

  @override
  String get enum_profileEvent_decoStopEnd => 'Einde decostop';

  @override
  String get enum_profileEvent_decoStopStart => 'Begin decostop';

  @override
  String get enum_profileEvent_decoViolation => 'Deco-overtreding';

  @override
  String get enum_profileEvent_gasSwitch => 'Gaswisseling';

  @override
  String get enum_profileEvent_lowGas => 'Waarschuwing laag gas';

  @override
  String get enum_profileEvent_maxDepth => 'Max diepte';

  @override
  String get enum_profileEvent_missedStop => 'Gemiste decostop';

  @override
  String get enum_profileEvent_note => 'Notitie';

  @override
  String get enum_profileEvent_ppO2High => 'Hoge ppO2';

  @override
  String get enum_profileEvent_ppO2Low => 'Lage ppO2';

  @override
  String get enum_profileEvent_safetyStopEnd => 'Einde veiligheidsstop';

  @override
  String get enum_profileEvent_safetyStopStart => 'Begin veiligheidsstop';

  @override
  String get enum_profileEvent_setpointChange => 'Setpointwijziging';

  @override
  String get enum_profileMetricCategory_decompression => 'Decompressie';

  @override
  String get enum_profileMetricCategory_gasAnalysis => 'Gasanalyse';

  @override
  String get enum_profileMetricCategory_gradientFactor => 'Gradientfactoren';

  @override
  String get enum_profileMetricCategory_other => 'Overig';

  @override
  String get enum_profileMetricCategory_primary => 'Primaire meetwaarden';

  @override
  String get enum_profileMetric_gasDensity => 'Gasdichtheid';

  @override
  String get enum_profileMetric_gasDensity_short => 'Dichtheid';

  @override
  String get enum_profileMetric_gf => 'GF%';

  @override
  String get enum_profileMetric_gf_short => 'GF%';

  @override
  String get enum_profileMetric_heartRate => 'Hartslag';

  @override
  String get enum_profileMetric_heartRate_short => 'HS';

  @override
  String get enum_profileMetric_meanDepth => 'Gemiddelde diepte';

  @override
  String get enum_profileMetric_meanDepth_short => 'Gem.';

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
  String get enum_profileMetric_pressure => 'Druk';

  @override
  String get enum_profileMetric_pressure_short => 'Druk';

  @override
  String get enum_profileMetric_sacRate => 'SAC-verbruik';

  @override
  String get enum_profileMetric_sacRate_short => 'SAC';

  @override
  String get enum_profileMetric_surfaceGf => 'Oppervlakte GF';

  @override
  String get enum_profileMetric_surfaceGf_short => 'OppGF';

  @override
  String get enum_profileMetric_temperature => 'Temperatuur';

  @override
  String get enum_profileMetric_temperature_short => 'Temp';

  @override
  String get enum_profileMetric_tts => 'TTS';

  @override
  String get enum_profileMetric_tts_short => 'TTS';

  @override
  String get enum_scrType_cmf => 'Constant massadebiet';

  @override
  String get enum_scrType_cmf_short => 'CMF';

  @override
  String get enum_scrType_escr => 'Elektronisch gestuurd';

  @override
  String get enum_scrType_escr_short => 'ESCR';

  @override
  String get enum_scrType_pascr => 'Passieve toevoeging';

  @override
  String get enum_scrType_pascr_short => 'PASCR';

  @override
  String get enum_serviceType_annual => 'Jaarlijks onderhoud';

  @override
  String get enum_serviceType_calibration => 'Kalibratie';

  @override
  String get enum_serviceType_cleaning => 'Reiniging';

  @override
  String get enum_serviceType_inspection => 'Inspectie';

  @override
  String get enum_serviceType_other => 'Overig';

  @override
  String get enum_serviceType_overhaul => 'Revisie';

  @override
  String get enum_serviceType_recall => 'Terugroepactie/Veiligheid';

  @override
  String get enum_serviceType_repair => 'Reparatie';

  @override
  String get enum_serviceType_replacement => 'Onderdeelvervanging';

  @override
  String get enum_serviceType_warranty => 'Garantieonderhoud';

  @override
  String get enum_sortDirection_ascending => 'Oplopend';

  @override
  String get enum_sortDirection_descending => 'Aflopend';

  @override
  String get enum_sortField_agency => 'Organisatie';

  @override
  String get enum_sortField_date => 'Datum';

  @override
  String get enum_sortField_dateIssued => 'Datum uitgegeven';

  @override
  String get enum_sortField_dateTaken => 'Opnamedatum';

  @override
  String get enum_sortField_difficulty => 'Moeilijkheid';

  @override
  String get enum_sortField_diveCount => 'Aantal duiken';

  @override
  String get enum_sortField_diveNumber => 'Duiknummer';

  @override
  String get enum_sortField_duration => 'Duur';

  @override
  String get enum_sortField_endDate => 'Einddatum';

  @override
  String get enum_sortField_fileName => 'Bestandsnaam';

  @override
  String get enum_sortField_fileSize => 'Bestandsgrootte';

  @override
  String get enum_sortField_lastServiceDate => 'Laatste onderhoud';

  @override
  String get enum_sortField_maxDepth => 'Max diepte';

  @override
  String get enum_sortField_name => 'Naam';

  @override
  String get enum_sortField_purchaseDate => 'Aankoopdatum';

  @override
  String get enum_sortField_rating => 'Beoordeling';

  @override
  String get enum_sortField_site => 'Duikstek';

  @override
  String get enum_sortField_startDate => 'Startdatum';

  @override
  String get enum_sortField_status => 'Status';

  @override
  String get enum_sortField_type => 'Type';

  @override
  String get enum_speciesCategory_coral => 'Koraal';

  @override
  String get enum_speciesCategory_fish => 'Vis';

  @override
  String get enum_speciesCategory_invertebrate => 'Ongewervelde';

  @override
  String get enum_speciesCategory_mammal => 'Zoogdier';

  @override
  String get enum_speciesCategory_other => 'Overig';

  @override
  String get enum_speciesCategory_plant => 'Plant/Alg';

  @override
  String get enum_speciesCategory_ray => 'Rog';

  @override
  String get enum_speciesCategory_shark => 'Haai';

  @override
  String get enum_speciesCategory_turtle => 'Schildpad';

  @override
  String get enum_tankMaterial_aluminum => 'Aluminium';

  @override
  String get enum_tankMaterial_carbonFiber => 'Koolstofvezel';

  @override
  String get enum_tankMaterial_steel => 'Staal';

  @override
  String get enum_tankRole_backGas => 'Hoofdgas';

  @override
  String get enum_tankRole_bailout => 'Bailout';

  @override
  String get enum_tankRole_deco => 'Deco';

  @override
  String get enum_tankRole_diluent => 'Diluent';

  @override
  String get enum_tankRole_oxygenSupply => 'O₂-toevoer';

  @override
  String get enum_tankRole_pony => 'Ponyfles';

  @override
  String get enum_tankRole_sidemountLeft => 'Sidemount links';

  @override
  String get enum_tankRole_sidemountRight => 'Sidemount rechts';

  @override
  String get enum_tankRole_stage => 'Stagefles';

  @override
  String get enum_visibility_excellent => 'Uitstekend (>30m / >100ft)';

  @override
  String get enum_visibility_good => 'Goed (15-30m / 50-100ft)';

  @override
  String get enum_visibility_moderate => 'Matig (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => 'Slecht (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => 'Onbekend';

  @override
  String get enum_waterType_brackish => 'Brak';

  @override
  String get enum_waterType_fresh => 'Zoet water';

  @override
  String get enum_waterType_salt => 'Zout water';

  @override
  String get enum_weightType_ankleWeights => 'Enkelgewichten';

  @override
  String get enum_weightType_backplate => 'Backplate-gewichten';

  @override
  String get enum_weightType_belt => 'Loodgordel';

  @override
  String get enum_weightType_integrated => 'Geïntegreerde gewichten';

  @override
  String get enum_weightType_mixed => 'Gemengd/Gecombineerd';

  @override
  String get enum_weightType_trimWeights => 'Trimgewichten';

  @override
  String get equipment_appBar_title => 'Uitrusting';

  @override
  String get equipment_deleteDialog_cancel => 'Annuleren';

  @override
  String get equipment_deleteDialog_confirm => 'Verwijderen';

  @override
  String get equipment_deleteDialog_content =>
      'Weet je zeker dat je deze uitrusting wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.';

  @override
  String get equipment_deleteDialog_title => 'Uitrusting verwijderen';

  @override
  String get equipment_detail_brandLabel => 'Merk';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return '$days dagen achterstallig';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days dagen tot service';
  }

  @override
  String get equipment_detail_detailsTitle => 'Details';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count duiken';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count duik';
  }

  @override
  String get equipment_detail_divesLabel => 'Duiken';

  @override
  String get equipment_detail_divesSemanticLabel =>
      'Bekijk duiken met deze uitrusting';

  @override
  String equipment_detail_durationDays(Object days) {
    return '$days dagen';
  }

  @override
  String equipment_detail_durationMonths(Object months) {
    return '$months maanden';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralPlural(
    Object years,
    Object months,
  ) {
    return '$years jaar, $months maanden';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralSingular(
    Object years,
    Object months,
  ) {
    return '$years jaar, $months maand';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularPlural(
    Object years,
    Object months,
  ) {
    return '$years jaar, $months maanden';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularSingular(
    Object years,
    Object months,
  ) {
    return '$years jaar, $months maand';
  }

  @override
  String equipment_detail_durationYearsPlural(Object years) {
    return '$years jaar';
  }

  @override
  String equipment_detail_durationYearsSingular(Object years) {
    return '$years jaar';
  }

  @override
  String get equipment_detail_editTooltip => 'Uitrusting bewerken';

  @override
  String get equipment_detail_editTooltipShort => 'Bewerken';

  @override
  String equipment_detail_errorMessage(Object error) {
    return 'Fout: $error';
  }

  @override
  String get equipment_detail_errorTitle => 'Fout';

  @override
  String get equipment_detail_lastServiceLabel => 'Laatste service';

  @override
  String get equipment_detail_loadingTitle => 'Laden...';

  @override
  String get equipment_detail_modelLabel => 'Model';

  @override
  String get equipment_detail_nextServiceDueLabel => 'Volgende service gepland';

  @override
  String get equipment_detail_notFoundMessage =>
      'Dit uitrustingsonderdeel bestaat niet meer.';

  @override
  String get equipment_detail_notFoundTitle => 'Uitrusting niet gevonden';

  @override
  String get equipment_detail_notesTitle => 'Notities';

  @override
  String get equipment_detail_ownedForLabel => 'In bezit sinds';

  @override
  String get equipment_detail_purchaseDateLabel => 'Aankoopdatum';

  @override
  String get equipment_detail_purchasePriceLabel => 'Aankoopprijs';

  @override
  String get equipment_detail_retiredChip => 'Buiten gebruik';

  @override
  String get equipment_detail_serialNumberLabel => 'Serienummer';

  @override
  String get equipment_detail_serviceInfoTitle => 'Service-informatie';

  @override
  String get equipment_serviceClocks_title => 'Serviceintervallen';

  @override
  String get equipment_serviceClocks_addClock => 'Interval toevoegen';

  @override
  String get equipment_serviceClocks_logService => 'Service registreren';

  @override
  String get equipment_serviceClocks_edit => 'Intervallen bewerken';

  @override
  String get equipment_serviceClocks_pause => 'Pauzeren';

  @override
  String get equipment_serviceClocks_resume => 'Hervatten';

  @override
  String get equipment_serviceClocks_remove => 'Verwijderen';

  @override
  String get equipment_serviceClocks_paused => 'Gepauzeerd';

  @override
  String get equipment_serviceClocks_empty => 'Geen serviceintervallen';

  @override
  String get equipment_serviceClocks_unconfigured =>
      'Geen interval ingesteld - tik om te configureren';

  @override
  String equipment_serviceClocks_dueOn(String date) {
    return 'Vervalt op $date';
  }

  @override
  String equipment_serviceClocks_overdueSince(String date) {
    return 'Achterstallig sinds $date';
  }

  @override
  String get equipment_serviceClocks_overdue => 'Te laat';

  @override
  String equipment_serviceClocks_divesLeft(int remaining, int total) {
    return '$remaining van $total duiken resterend';
  }

  @override
  String get cylinderConfigs_title => 'Flesconfiguraties';

  @override
  String get cylinderConfigs_empty => 'Nog geen configuraties';

  @override
  String get cylinderConfigs_emptyBody =>
      'Sla een diluent- en bailout-opstelling één keer op en pas hem toe op elke duik.';

  @override
  String get cylinderConfigs_new => 'Nieuwe configuratie';

  @override
  String get cylinderConfigs_name => 'Naam';

  @override
  String get cylinderConfigs_nameRequired => 'Voer een naam in';

  @override
  String get cylinderConfigs_forUnit => 'Voor unit';

  @override
  String get cylinderConfigs_noUnit => 'Algemeen gasplan';

  @override
  String get cylinderConfigs_gasPlans => 'Gasplannen';

  @override
  String get cylinderConfigs_addCylinder => 'Fles toevoegen';

  @override
  String get cylinderConfigs_role => 'Rol';

  @override
  String get cylinderConfigs_startPressure => 'Begindruk';

  @override
  String get cylinderConfigs_label => 'Label';

  @override
  String get cylinderConfigs_fromPreset => 'Uit voorinstelling';

  @override
  String get cylinderConfigs_deleteTitle => 'Configuratie verwijderen?';

  @override
  String get cylinderConfigs_deleteBody =>
      'Duiken waarop hij al is toegepast veranderen niet.';

  @override
  String get cylinderConfigs_applyAction => 'Configuratie toepassen';

  @override
  String cylinderConfigs_applyAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flessen toegevoegd',
      one: '1 fles toegevoegd',
    );
    return '$_temp0';
  }

  @override
  String cylinderConfigs_applyKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count behouden',
      one: '1 behouden',
    );
    return '$_temp0';
  }

  @override
  String get cylinderConfigs_applyNothingToDo =>
      'Deze duik komt al overeen met de configuratie';

  @override
  String get cylinderConfigs_sectionTitle => 'Configuraties';

  @override
  String get equipment_serviceClocks_hoursSource =>
      'Berekend op basis van geregistreerde duiktijd';

  @override
  String equipment_serviceClocks_hoursLeft(String remaining, String total) {
    return '$remaining van $total uur resterend';
  }

  @override
  String get equipment_serviceClocks_manageKinds => 'Servicetypen beheren';

  @override
  String get equipment_serviceClocks_appliesToClock => 'Gekoppeld aan interval';

  @override
  String get equipment_serviceClocks_noClockOption =>
      'Niet aan een interval gekoppeld';

  @override
  String get equipment_scheduleDialog_title => 'Interval bewerken';

  @override
  String get equipment_scheduleDialog_intervalDays => 'Interval (dagen)';

  @override
  String get equipment_scheduleDialog_intervalDives => 'Interval (duiken)';

  @override
  String get equipment_scheduleDialog_intervalHours => 'Interval (uren)';

  @override
  String equipment_scheduleDialog_inheritHint(String value) {
    return 'Standaard: $value';
  }

  @override
  String get equipment_scheduleDialog_anchorDate => 'Referentiedatum';

  @override
  String get equipment_scheduleDialog_anchorHint =>
      'Wordt gebruikt zolang er nog geen servicerecord van dit type bestaat';

  @override
  String get equipment_scheduleDialog_clearAnchor => 'Referentiedatum wissen';

  @override
  String get equipment_scheduleDialog_save => 'Opslaan';

  @override
  String get equipment_scheduleDialog_cancel => 'Annuleren';

  @override
  String get equipment_serviceKinds_title => 'Servicetypen';

  @override
  String get equipment_serviceKinds_builtIn => 'Ingebouwd';

  @override
  String get equipment_serviceKinds_custom => 'Aangepast';

  @override
  String get equipment_serviceKinds_add => 'Servicetype toevoegen';

  @override
  String get equipment_serviceKinds_editTitle => 'Servicetype bewerken';

  @override
  String get equipment_serviceKinds_nameLabel => 'Naam';

  @override
  String get equipment_serviceKinds_nameRequired => 'Een naam is verplicht';

  @override
  String get equipment_serviceKinds_appliesTo => 'Geldt voor';

  @override
  String get equipment_serviceKinds_autoAttach =>
      'Automatisch koppelen aan nieuwe uitrusting';

  @override
  String get equipment_serviceKinds_deleteConfirmTitle =>
      'Servicetype verwijderen?';

  @override
  String get equipment_serviceKinds_deleteConfirmBody =>
      'Intervallen die dit servicetype gebruiken worden verwijderd.';

  @override
  String get equipment_serviceKinds_delete => 'Verwijderen';

  @override
  String get equipment_serviceKinds_cancel => 'Annuleren';

  @override
  String get equipment_serviceKinds_save => 'Opslaan';

  @override
  String get equipment_serviceKinds_emptyCustom =>
      'Nog geen aangepaste servicetypen';

  @override
  String equipment_serviceKinds_everyDays(int days) {
    return 'elke $days dagen';
  }

  @override
  String equipment_serviceKinds_everyDives(int dives) {
    return 'elke $dives duiken';
  }

  @override
  String equipment_serviceKinds_everyHours(String hours) {
    return 'elke $hours uur';
  }

  @override
  String get dashboard_serviceDue_title => 'Service nodig';

  @override
  String dashboard_serviceDue_more(int count) {
    return '+$count meer';
  }

  @override
  String dashboard_alerts_clockDue(String name, String kind) {
    return '$name: $kind nodig';
  }

  @override
  String dashboard_alerts_clockOverdue(String name, String kind) {
    return '$name: $kind achterstallig';
  }

  @override
  String equipment_list_worstClock(String kind) {
    return '$kind achterstallig';
  }

  @override
  String trips_serviceAlert_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items hebben vóór deze reis service nodig',
      one: '1 item heeft vóór deze reis service nodig',
    );
    return '$_temp0';
  }

  @override
  String trips_serviceAlert_dueBefore(String kind, String date) {
    return '$kind vervalt op $date';
  }

  @override
  String trips_serviceAlert_overdue(String kind) {
    return '$kind achterstallig';
  }

  @override
  String get settings_notifications_tripLeadTitle =>
      'Aanlooptijd voor service vóór reizen';

  @override
  String settings_notifications_tripLeadDays(int days) {
    return '$days dagen vóór een reis';
  }

  @override
  String get equipment_detail_serviceIntervalLabel => 'Serviceinterval';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days dagen';
  }

  @override
  String get equipment_detail_serviceOverdue => 'Service is achterstallig!';

  @override
  String get equipment_detail_sizeLabel => 'Maat';

  @override
  String get equipment_detail_thicknessLabel => 'Dikte';

  @override
  String get equipment_detail_statusLabel => 'Status';

  @override
  String equipment_detail_tripsCountPlural(Object count) {
    return '$count reizen';
  }

  @override
  String equipment_detail_tripsCountSingular(Object count) {
    return '$count reis';
  }

  @override
  String get equipment_detail_tripsLabel => 'Reizen';

  @override
  String get equipment_detail_tripsSemanticLabel =>
      'Bekijk reizen met deze uitrusting';

  @override
  String get equipment_edit_appBar_editTitle => 'Uitrusting bewerken';

  @override
  String get equipment_edit_appBar_newTitle => 'Nieuwe uitrusting';

  @override
  String get equipment_edit_appBar_saveButton => 'Opslaan';

  @override
  String get equipment_edit_appBar_saveTooltip =>
      'Wijzigingen in uitrusting opslaan';

  @override
  String get equipment_edit_brandLabel => 'Merk';

  @override
  String get equipment_edit_clearDate => 'Datum wissen';

  @override
  String get equipment_edit_currencyLabel => 'Valuta';

  @override
  String get equipment_edit_disableReminders => 'Herinneringen uitschakelen';

  @override
  String get equipment_edit_disableRemindersSubtitle =>
      'Alle meldingen voor dit onderdeel uitschakelen';

  @override
  String get equipment_edit_discardDialog_content =>
      'Je hebt niet-opgeslagen wijzigingen. Weet je zeker dat je wilt vertrekken?';

  @override
  String get equipment_edit_discardDialog_discard => 'Verwerpen';

  @override
  String get equipment_edit_discardDialog_keepEditing => 'Verder bewerken';

  @override
  String get equipment_edit_discardDialog_title => 'Wijzigingen verwerpen?';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => 'Annuleren';

  @override
  String get equipment_edit_embeddedHeader_editTitle => 'Uitrusting bewerken';

  @override
  String get equipment_edit_embeddedHeader_newTitle => 'Nieuwe uitrusting';

  @override
  String get equipment_edit_embeddedHeader_saveButton => 'Opslaan';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit =>
      'Wijzigingen in uitrusting opslaan';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new =>
      'Nieuwe uitrusting toevoegen';

  @override
  String equipment_edit_errorMessage(Object error) {
    return 'Fout: $error';
  }

  @override
  String get equipment_edit_errorTitle => 'Fout';

  @override
  String get equipment_edit_lastServiceDateLabel => 'Laatste servicedatum';

  @override
  String get equipment_edit_loadingTitle => 'Laden...';

  @override
  String get equipment_edit_modelLabel => 'Model';

  @override
  String get equipment_edit_nameHint => 'bijv. Mijn primaire ademautomaat';

  @override
  String get equipment_edit_nameLabel => 'Naam *';

  @override
  String get equipment_edit_nameValidation => 'Voer een naam in';

  @override
  String get equipment_edit_notFoundMessage =>
      'Dit uitrustingsonderdeel bestaat niet meer.';

  @override
  String get equipment_edit_notFoundTitle => 'Uitrusting niet gevonden';

  @override
  String get equipment_edit_notesHint =>
      'Extra notities over deze uitrusting...';

  @override
  String get equipment_edit_notesLabel => 'Notities';

  @override
  String get equipment_edit_notificationsSubtitle =>
      'Overschrijf globale meldingsinstellingen voor dit onderdeel';

  @override
  String get equipment_edit_notificationsTitle => 'Meldingen (optioneel)';

  @override
  String get equipment_edit_purchaseDateLabel => 'Aankoopdatum';

  @override
  String get equipment_edit_purchaseInfoTitle => 'Aankoopinformatie';

  @override
  String get equipment_edit_purchasePriceLabel => 'Aankoopprijs';

  @override
  String get equipment_edit_purchasePriceValidation =>
      'Voer een geldig bedrag in';

  @override
  String get equipment_edit_remindMeBeforeServiceDue =>
      'Herinner me voordat service nodig is:';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days dagen';
  }

  @override
  String get equipment_edit_saveButton_edit => 'Wijzigingen opslaan';

  @override
  String get equipment_edit_saveButton_new => 'Uitrusting toevoegen';

  @override
  String get equipment_edit_saveTooltip_edit =>
      'Wijzigingen in uitrusting opslaan';

  @override
  String get equipment_edit_saveTooltip_new =>
      'Nieuw uitrustingsonderdeel toevoegen';

  @override
  String get equipment_edit_selectDate => 'Selecteer datum';

  @override
  String get equipment_edit_serialNumberLabel => 'Serienummer';

  @override
  String get equipment_edit_serviceIntervalHint => 'bijv. 365 voor jaarlijks';

  @override
  String get equipment_edit_serviceIntervalLabel => 'Serviceinterval (dagen)';

  @override
  String get equipment_edit_serviceSettingsTitle => 'Service-instellingen';

  @override
  String get equipment_edit_sizeHint => 'bijv. M, L, 42';

  @override
  String get equipment_edit_sizeLabel => 'Maat';

  @override
  String get equipment_edit_snackbar_added => 'Uitrusting toegevoegd';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return 'Fout bij opslaan van uitrusting: $error';
  }

  @override
  String get equipment_edit_snackbar_updated => 'Uitrusting bijgewerkt';

  @override
  String get equipment_edit_statusLabel => 'Status';

  @override
  String get equipment_edit_thicknessDesignationHint => 'bijv. 5, 5/4, 7/5/3';

  @override
  String get equipment_edit_thicknessHint => 'bijv. 5mm, 7mm';

  @override
  String get equipment_edit_thicknessLabel => 'Dikte';

  @override
  String get equipment_edit_typeLabel => 'Type *';

  @override
  String get equipment_edit_useCustomReminders =>
      'Aangepaste herinneringen gebruiken';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'Stel andere herinneringsdagen in voor dit onderdeel';

  @override
  String get equipment_fab_addEquipment => 'Uitrusting toevoegen';

  @override
  String get equipment_fab_addSet => 'Set toevoegen';

  @override
  String get equipment_list_emptyState_addFirstButton =>
      'Voeg je eerste uitrusting toe';

  @override
  String get equipment_list_emptyState_addPrompt =>
      'Voeg je duikuitrusting toe om gebruik en service bij te houden';

  @override
  String get equipment_list_emptyState_filterText_equipment => 'uitrusting';

  @override
  String get equipment_list_emptyState_filterText_serviceDue =>
      'uitrusting die service nodig heeft';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return '$status uitrusting';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return 'Geen $filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch =>
      'Geen uitrusting met deze status';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate =>
      'Al je uitrusting is up-to-date met service!';

  @override
  String equipment_list_errorLoading(Object error) {
    return 'Fout bij laden van uitrusting: $error';
  }

  @override
  String get equipment_list_filterAll => 'Alle uitrusting';

  @override
  String get equipment_list_filterLabel => 'Filter:';

  @override
  String get equipment_list_filterServiceDue => 'Service nodig';

  @override
  String get equipment_list_retryButton => 'Opnieuw proberen';

  @override
  String get equipment_list_searchTooltip => 'Uitrusting zoeken';

  @override
  String get equipment_list_setsTooltip => 'Uitrustingssets';

  @override
  String get equipment_list_sortTitle => 'Uitrusting sorteren';

  @override
  String get equipment_list_sortTooltip => 'Sorteren';

  @override
  String equipment_list_tile_daysCount(Object days) {
    return '$days dagen';
  }

  @override
  String equipment_list_tile_serviceInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Service over $days dagen',
      one: 'Service over 1 dag',
    );
    return '$_temp0';
  }

  @override
  String get equipment_list_tile_serviceDueChip => 'Service nodig';

  @override
  String get equipment_list_tile_serviceIn => 'Service over';

  @override
  String get equipment_menu_delete => 'Verwijderen';

  @override
  String get equipment_menu_markAsServiced => 'Markeren als onderhouden';

  @override
  String get equipment_menu_reactivate => 'Heractiveren';

  @override
  String get equipment_menu_retireEquipment =>
      'Uitrusting buiten gebruik stellen';

  @override
  String get equipment_search_backTooltip => 'Terug';

  @override
  String get equipment_search_clearTooltip => 'Zoekopdracht wissen';

  @override
  String get equipment_search_fieldLabel => 'Uitrusting zoeken...';

  @override
  String get equipment_search_hint =>
      'Zoek op naam, merk, model of serienummer';

  @override
  String equipment_search_noResults(Object query) {
    return 'Geen uitrusting gevonden voor \"$query\"';
  }

  @override
  String get equipment_serviceDialog_addButton => 'Toevoegen';

  @override
  String get equipment_serviceDialog_addTitle => 'Servicerecord toevoegen';

  @override
  String get equipment_serviceDialog_cancelButton => 'Annuleren';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip =>
      'Volgende servicedatum wissen';

  @override
  String get equipment_serviceDialog_costHint => '0,00';

  @override
  String get equipment_serviceDialog_costLabel => 'Kosten';

  @override
  String get equipment_serviceDialog_currencyLabel => 'Valuta';

  @override
  String get equipment_serviceDialog_costValidation =>
      'Voer een geldig bedrag in';

  @override
  String get equipment_serviceDialog_editTitle => 'Servicerecord bewerken';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel =>
      'Volgende service gepland';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel =>
      'Kies volgende servicedatum';

  @override
  String get equipment_serviceDialog_nextServiceNotSet => 'Niet ingesteld';

  @override
  String get equipment_serviceDialog_notesLabel => 'Notities';

  @override
  String get equipment_serviceDialog_providerHint => 'bijv. naam duikwinkel';

  @override
  String get equipment_serviceDialog_providerLabel => 'Aanbieder/winkel';

  @override
  String get equipment_serviceDialog_serviceDateLabel => 'Servicedatum';

  @override
  String get equipment_serviceDialog_serviceDateSemanticLabel =>
      'Kies servicedatum';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => 'Type service';

  @override
  String get equipment_serviceDialog_serviceTypeHelper =>
      'Dit vastleggen zet de teller van dit servicetype terug';

  @override
  String get equipment_serviceDialog_serviceTypeRequired =>
      'Kies een servicetype';

  @override
  String get equipment_serviceDialog_serviceTypeNotSet => 'Niet ingesteld';

  @override
  String get equipment_serviceDialog_categoryHelper =>
      'Gebruikt voor filteren en exporteren';

  @override
  String get equipment_serviceDialog_manageServiceTypes =>
      'Servicetypes beheren';

  @override
  String get equipment_serviceDialog_categoryLabel => 'Categorie';

  @override
  String get equipment_serviceDialog_snackbar_added =>
      'Servicerecord toegevoegd';

  @override
  String equipment_serviceDialog_snackbar_error(Object error) {
    return 'Fout: $error';
  }

  @override
  String get equipment_serviceDialog_snackbar_updated =>
      'Servicerecord bijgewerkt';

  @override
  String get equipment_serviceDialog_updateButton => 'Bijwerken';

  @override
  String get equipment_serviceCategory_annual => 'Jaarlijkse service';

  @override
  String get equipment_serviceCategory_repair => 'Reparatie';

  @override
  String get equipment_serviceCategory_inspection => 'Inspectie';

  @override
  String get equipment_serviceCategory_overhaul => 'Revisie';

  @override
  String get equipment_serviceCategory_replacement => 'Onderdeelvervanging';

  @override
  String get equipment_serviceCategory_cleaning => 'Reiniging';

  @override
  String get equipment_serviceCategory_calibration => 'Kalibratie';

  @override
  String get equipment_serviceCategory_warranty => 'Garantieservice';

  @override
  String get equipment_serviceCategory_recall => 'Terugroepactie/Veiligheid';

  @override
  String get equipment_serviceCategory_other => 'Overig';

  @override
  String get equipment_service_addButton => 'Toevoegen';

  @override
  String get equipment_service_deleteDialog_cancel => 'Annuleren';

  @override
  String get equipment_service_deleteDialog_confirm => 'Verwijderen';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return 'Weet je zeker dat je dit $serviceType-record wilt verwijderen?';
  }

  @override
  String get equipment_service_deleteDialog_title =>
      'Servicerecord verwijderen?';

  @override
  String get equipment_service_deleteMenuItem => 'Verwijderen';

  @override
  String get equipment_service_editMenuItem => 'Bewerken';

  @override
  String get equipment_service_emptyState => 'Nog geen servicerecords';

  @override
  String get equipment_service_historyTitle => 'Servicegeschiedenis';

  @override
  String equipment_service_nextDueLabel(String date) {
    return 'Volgende vervaldatum $date';
  }

  @override
  String get equipment_service_filterTaskAll => 'Alle taken';

  @override
  String get equipment_service_filterTypeAll => 'Alle typen';

  @override
  String get equipment_service_filterYearAll => 'Alle jaren';

  @override
  String get equipment_service_filterUntagged =>
      'Niet aan een interval gekoppeld';

  @override
  String get equipment_service_filterClear => 'Filter wissen';

  @override
  String get equipment_service_filterNoMatches =>
      'Geen onderhoud voldoet aan dit filter';

  @override
  String equipment_service_filterMatchCount(int count, int total) {
    return '$count van $total getoond';
  }

  @override
  String get equipment_serviceKinds_defaultCategoryLabel =>
      'Standaardcategorie';

  @override
  String get equipment_serviceKinds_defaultCategoryNone => 'Geen standaard';

  @override
  String get equipment_serviceKinds_defaultCostLabel => 'Standaardprijs';

  @override
  String get equipment_serviceKinds_defaultCostHint =>
      'Laat leeg voor geen standaardwaarde';

  @override
  String get equipment_scheduleDialog_defaultCostLabel =>
      'Standaardprijs voor dit item';

  @override
  String get equipment_serviceKinds_defaultCurrencyLabel => 'Valuta';

  @override
  String get equipment_service_exportMenuItem => 'Onderhoudslogboek exporteren';

  @override
  String get transfer_export_maintenanceTitle => 'Onderhoudslogboek';

  @override
  String get transfer_export_maintenanceSubtitle =>
      'Servicegeschiedenis van alle uitrusting als spreadsheet';

  @override
  String get settings_export_progress_maintenance =>
      'Onderhoudslogboek exporteren...';

  @override
  String get settings_export_success_maintenance =>
      'Onderhoudslogboek geëxporteerd';

  @override
  String get settings_export_saved_maintenance =>
      'Onderhoudslogboek opgeslagen';

  @override
  String get equipment_serviceKinds_defaultCurrencyInherit =>
      'Standaardvaluta gebruiken';

  @override
  String get equipment_scheduleDialog_defaultCurrencyLabel =>
      'Valuta voor dit item';

  @override
  String get equipment_service_snackbar_deleted => 'Servicerecord verwijderd';

  @override
  String get equipment_service_totalCostLabel => 'Totale servicekosten';

  @override
  String get equipment_setDetail_addEquipmentButton => 'Uitrusting toevoegen';

  @override
  String get equipment_setDetail_deleteDialog_cancel => 'Annuleren';

  @override
  String get equipment_setDetail_deleteDialog_confirm => 'Verwijderen';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      'Weet je zeker dat je deze uitrustingsset wilt verwijderen? De uitrustingsonderdelen in de set worden niet verwijderd.';

  @override
  String get equipment_setDetail_deleteDialog_title =>
      'Uitrustingsset verwijderen';

  @override
  String get equipment_setDetail_deleteMenuItem => 'Verwijderen';

  @override
  String get equipment_setDetail_editTooltip => 'Set bewerken';

  @override
  String get equipment_setDetail_emptySet => 'Geen uitrusting in deze set';

  @override
  String get equipment_setDetail_equipmentInSetTitle =>
      'Uitrusting in deze set';

  @override
  String equipment_setDetail_errorMessage(Object error) {
    return 'Fout: $error';
  }

  @override
  String get equipment_setDetail_errorTitle => 'Fout';

  @override
  String get equipment_setDetail_loadingTitle => 'Laden...';

  @override
  String get equipment_setDetail_notFoundMessage =>
      'Deze uitrustingsset bestaat niet meer.';

  @override
  String get equipment_setDetail_notFoundTitle => 'Set niet gevonden';

  @override
  String get equipment_setDetail_snackbar_deleted =>
      'Uitrustingsset verwijderd';

  @override
  String get equipment_setEdit_addEquipmentFirst =>
      'Voeg eerst uitrusting toe voordat je een set maakt.';

  @override
  String get equipment_setEdit_appBar_editTitle => 'Set bewerken';

  @override
  String get equipment_setEdit_appBar_newTitle => 'Nieuwe uitrustingsset';

  @override
  String get equipment_setEdit_descriptionHint => 'Optionele beschrijving...';

  @override
  String get equipment_setEdit_descriptionLabel => 'Beschrijving';

  @override
  String equipment_setEdit_errorMessage(Object error) {
    return 'Fout: $error';
  }

  @override
  String get equipment_setEdit_errorTitle => 'Fout';

  @override
  String get equipment_setEdit_loadingTitle => 'Laden...';

  @override
  String get equipment_setEdit_nameHint => 'bijv. Warm water opstelling';

  @override
  String get equipment_setEdit_nameLabel => 'Setnaam *';

  @override
  String get equipment_setEdit_nameValidation => 'Voer een naam in';

  @override
  String get equipment_setEdit_noEquipmentAvailable =>
      'Geen uitrusting beschikbaar';

  @override
  String get equipment_setEdit_notFoundMessage =>
      'Deze uitrustingsset bestaat niet meer.';

  @override
  String get equipment_setEdit_notFoundTitle => 'Set niet gevonden';

  @override
  String get equipment_setEdit_saveButton_edit => 'Wijzigingen opslaan';

  @override
  String get equipment_setEdit_saveButton_new => 'Set aanmaken';

  @override
  String get equipment_setEdit_saveTooltip_edit =>
      'Wijzigingen in uitrustingsset opslaan';

  @override
  String get equipment_setEdit_saveTooltip_new =>
      'Nieuwe uitrustingsset aanmaken';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle =>
      'Kies de uitrustingsonderdelen om in deze set op te nemen.';

  @override
  String get equipment_setEdit_selectEquipmentTitle => 'Selecteer uitrusting';

  @override
  String get equipment_setEdit_snackbar_created => 'Uitrustingsset aangemaakt';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return 'Fout bij opslaan van uitrustingsset: $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated => 'Uitrustingsset bijgewerkt';

  @override
  String get equipment_sets_appBar_title => 'Uitrustingssets';

  @override
  String get equipment_sets_emptyState_createFirstButton =>
      'Maak je eerste set aan';

  @override
  String get equipment_sets_emptyState_description =>
      'Maak uitrustingssets om snel veelgebruikte combinaties van uitrusting aan je duiken toe te voegen.';

  @override
  String get equipment_sets_emptyState_title => 'Geen uitrustingssets';

  @override
  String equipment_sets_errorLoading(Object error) {
    return 'Fout bij laden van sets: $error';
  }

  @override
  String get equipment_sets_fabTooltip => 'Een nieuwe uitrustingsset aanmaken';

  @override
  String get equipment_sets_fab_createSet => 'Set aanmaken';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count onderdelen';
  }

  @override
  String equipment_sets_itemCountSemanticLabel(Object count) {
    return '$count in set';
  }

  @override
  String equipment_sets_itemCountSingular(Object count) {
    return '$count onderdeel';
  }

  @override
  String get equipment_sets_retryButton => 'Opnieuw proberen';

  @override
  String get equipment_snackbar_deleted => 'Uitrusting verwijderd';

  @override
  String get equipment_snackbar_markedAsServiced =>
      'Gemarkeerd als onderhouden';

  @override
  String get equipment_snackbar_reactivated => 'Uitrusting geheractiveerd';

  @override
  String get equipment_snackbar_retired => 'Uitrusting buiten gebruik gesteld';

  @override
  String get equipment_summary_active => 'Actief';

  @override
  String get equipment_summary_addEquipmentButton => 'Uitrusting toevoegen';

  @override
  String get equipment_summary_equipmentSetsButton => 'Uitrustingssets';

  @override
  String get equipment_summary_overviewTitle => 'Overzicht';

  @override
  String get equipment_summary_quickActionsTitle => 'Snelle acties';

  @override
  String get equipment_summary_recentEquipmentTitle => 'Recente uitrusting';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name, $type';
  }

  @override
  String get equipment_summary_selectPrompt =>
      'Selecteer uitrusting uit de lijst om details te bekijken';

  @override
  String get equipment_summary_serviceDue => 'Service nodig';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name, $type, service nodig';
  }

  @override
  String get equipment_summary_serviceDueTitle => 'Service nodig';

  @override
  String get equipment_summary_title => 'Uitrusting';

  @override
  String get equipment_summary_totalItems => 'Totaal onderdelen';

  @override
  String get equipment_summary_totalValue => 'Totale waarde';

  @override
  String get equipment_tab_equipment => 'Uitrusting';

  @override
  String get equipment_tab_sets => 'Sets';

  @override
  String get formatter_approximate_prefix => '~';

  @override
  String get formatter_connector_at => 'op';

  @override
  String get formatter_connector_from => 'Van';

  @override
  String get formatter_connector_until => 'Tot';

  @override
  String get gas_air_description => 'Standaard lucht (21% O2)';

  @override
  String get gas_air_displayName => 'Lucht';

  @override
  String get gas_diluentAir_description =>
      'Standaard lucht-diluent voor ondiep CCR';

  @override
  String get gas_diluentAir_displayName => 'Lucht-diluent';

  @override
  String get gas_diluentTx1070_description =>
      'Hypoxisch diluent voor zeer diep CCR';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description => 'Hypoxisch diluent voor diep CCR';

  @override
  String get gas_diluentTx1260_displayName => 'Tx 12/60';

  @override
  String get gas_ean32_description => 'Verrijkte lucht Nitrox 32%';

  @override
  String get gas_ean32_displayName => 'EAN32';

  @override
  String get gas_ean36_description => 'Verrijkte lucht Nitrox 36%';

  @override
  String get gas_ean36_displayName => 'EAN36';

  @override
  String get gas_ean40_description => 'Verrijkte lucht Nitrox 40%';

  @override
  String get gas_ean40_displayName => 'EAN40';

  @override
  String get gas_ean50_description => 'Decogas - 50% O2';

  @override
  String get gas_ean50_displayName => 'EAN50';

  @override
  String get gas_helitrox2525_description =>
      'Helitrox 25/25 (recreatief technisch)';

  @override
  String get gas_helitrox2525_displayName => 'Helitrox 25/25';

  @override
  String get gas_oxygen_description => 'Pure zuurstof (alleen 6m deco)';

  @override
  String get gas_oxygen_displayName => 'Zuurstof';

  @override
  String get gas_scrEan40_description => 'SCR-toevoergas - 40% O2';

  @override
  String get gas_scrEan40_displayName => 'SCR EAN40';

  @override
  String get gas_scrEan50_description => 'SCR-toevoergas - 50% O2';

  @override
  String get gas_scrEan50_displayName => 'SCR EAN50';

  @override
  String get gas_scrEan60_description => 'SCR-toevoergas - 60% O2';

  @override
  String get gas_scrEan60_displayName => 'SCR EAN60';

  @override
  String get gas_tmx1555_description => 'Hypoxisch trimix 15/55 (zeer diep)';

  @override
  String get gas_tmx1555_displayName => 'Tx 15/55';

  @override
  String get gas_tmx1845_description => 'Trimix 18/45 (diep duiken)';

  @override
  String get gas_tmx1845_displayName => 'Tx 18/45';

  @override
  String get gas_tmx2135_description => 'Normoxisch trimix 21/35';

  @override
  String get gas_tmx2135_displayName => 'Tx 21/35';

  @override
  String get gasCalculators_bestMix_bestOxygenMix => 'Beste zuurstofmengsel';

  @override
  String get gasCalculators_bestMix_commonMixesRef =>
      'Veelgebruikte mengsels referentie';

  @override
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2) {
    return 'Lucht MOD overschreden bij ppO₂ $ppO2';
  }

  @override
  String get gasCalculators_bestMix_targetDepth => 'Doeldiepte';

  @override
  String get gasCalculators_bestMix_targetDive => 'Doelduik';

  @override
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  ) {
    return 'Omgevingsdruk op $depth$depthSymbol';
  }

  @override
  String get gasCalculators_consumption_avgDepth => 'Gemiddelde diepte';

  @override
  String get gasCalculators_consumption_breakdown => 'Berekeningsuitsplitsing';

  @override
  String get gasCalculators_consumption_diveTime => 'Duiktijd';

  @override
  String gasCalculators_consumption_exceedsTank(
    Object pressure,
    Object symbol,
  ) {
    return 'Overschrijdt flescapaciteit ($pressure $symbol)';
  }

  @override
  String get gasCalculators_consumption_gasAtDepth => 'Gasverbruik op diepte';

  @override
  String get gasCalculators_consumption_pressure => 'Druk';

  @override
  String get gasCalculators_consumption_remainingGas => 'Resterend gas';

  @override
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  ) {
    return 'Flescapaciteit ($tankSize$volumeSymbol @ $fillPressure $pressureSymbol)';
  }

  @override
  String get gasCalculators_consumption_title => 'Gasverbruik';

  @override
  String gasCalculators_consumption_totalGas(Object time) {
    return 'Totaal gas voor $time minuten';
  }

  @override
  String get gasCalculators_consumption_volume => 'Volume';

  @override
  String get gasCalculators_mod_aboutMod => 'Over MOD';

  @override
  String get gasCalculators_mod_aboutModBody =>
      'Lager O₂ = diepere MOD = kortere NDL';

  @override
  String get gasCalculators_mod_inputParameters => 'Invoerparameters';

  @override
  String get gasCalculators_mod_maximumOperatingDepth => 'Maximale werkdiepte';

  @override
  String get gasCalculators_mod_oxygenO2 => 'Zuurstof (O₂)';

  @override
  String get gasCalculators_mod_ppO2Conservative =>
      'Conservatieve limiet voor verlengde bodemtijd';

  @override
  String get gasCalculators_mod_ppO2Maximum =>
      'Maximale limiet alleen voor decompressiestops';

  @override
  String get gasCalculators_mod_ppO2Standard =>
      'Standaard werkgrens voor recreatief duiken';

  @override
  String get gasCalculators_mnd_depthInput => 'Diepte';

  @override
  String get gasCalculators_mnd_endAtDepthTitle => 'END op diepte';

  @override
  String get gasCalculators_mnd_endLimit => 'END-limiet';

  @override
  String get gasCalculators_mnd_hePercent => 'He %';

  @override
  String get gasCalculators_mnd_infoContent =>
      'Maximale Narcotische Diepte (MND) is de diepste diepte waarop je kunt duiken voordat narcose je END-limiet overschrijdt. Equivalente Narcotische Diepte (END) geeft het narcotische effect van je gas op een bepaalde diepte aan.\n\nWanneer \'O2 is narcotisch\' is ingeschakeld, dragen zowel zuurstof als stikstof bij aan narcose (conservatiever). Wanneer uitgeschakeld, wordt alleen stikstof als narcotisch beschouwd.';

  @override
  String get gasCalculators_mnd_infoTitle => 'Over MND/END';

  @override
  String get gasCalculators_mnd_unlimited => 'onbeperkt';

  @override
  String get gasCalculators_mnd_inputParameters =>
      'Gasmix & narcose-instellingen';

  @override
  String get gasCalculators_mnd_o2Narcotic => 'O2 is narcotisch';

  @override
  String get gasCalculators_mnd_o2Percent => 'O2 %';

  @override
  String get gasCalculators_mnd_resultTitle => 'Maximale narcotische diepte';

  @override
  String get gasCalculators_ppO2Limit => 'ppO₂ limiet';

  @override
  String get gasCalculators_resetAll => 'Alle calculators resetten';

  @override
  String get gasCalculators_sacRate => 'RMV';

  @override
  String get gasCalculators_tab_bestMix => 'Beste mengsel';

  @override
  String get gasCalculators_tab_consumption => 'Verbruik';

  @override
  String get gasCalculators_tab_mnd => 'MND/END';

  @override
  String get gasCalculators_tab_blender => 'Trimix-menger';

  @override
  String get gasCalculators_blender_cylinder => 'Fles';

  @override
  String get gasCalculators_blender_startCylinder => 'In de fles';

  @override
  String get gasCalculators_blender_targetFill => 'Doelvulling';

  @override
  String get gasCalculators_blender_fillGases => 'Vulgassen';

  @override
  String get gasCalculators_blender_pressure => 'Druk';

  @override
  String get gasCalculators_blender_o2 => 'O₂';

  @override
  String get gasCalculators_blender_he => 'He';

  @override
  String get gasCalculators_blender_air => 'Lucht';

  @override
  String get gasCalculators_blender_helium => 'Helium';

  @override
  String get gasCalculators_blender_procedure => 'Vulprocedure';

  @override
  String get gasCalculators_blender_amounts => 'Toe te voegen gas';

  @override
  String gasCalculators_blender_stepStart(String pressure, String gas) {
    return 'Begin met $pressure $gas';
  }

  @override
  String gasCalculators_blender_stepFill(
    String gas,
    String pressure,
    String mix,
  ) {
    return 'Vul $gas tot $pressure → $mix';
  }

  @override
  String get gasCalculators_blender_error_targetPressure =>
      'De doeldruk moet hoger zijn dan de begindruk.';

  @override
  String get gasCalculators_blender_error_invalidMix =>
      'O₂ + He van een mengsel mag niet meer dan 100% zijn.';

  @override
  String get gasCalculators_blender_error_identicalGases =>
      'De twee vulgassen zijn identiek — niets te mengen.';

  @override
  String get gasCalculators_blender_error_linearlyDependent =>
      'Deze vulgassen kunnen het doelmengsel niet maken — een trimix-doel heeft een heliumbron nodig.';

  @override
  String get gasCalculators_blender_error_negativeAmount =>
      'Dit mengsel is met deze gassen niet haalbaar — er zou gas verwijderd moeten worden.';

  @override
  String gasCalculators_blender_error_drainTo(String pressure) {
    return 'Te veel gas in de fles voor dit mengsel. Laat eerst af tot $pressure en vul daarna.';
  }

  @override
  String get gasCalculators_blender_error_drainEmpty =>
      'Het gas in de fles is niet bruikbaar voor dit mengsel. Maak de fles eerst leeg en vul daarna.';

  @override
  String get gasCalculators_blender_error_cannotRemoveHelium =>
      'De fles bevat helium en het doelmengsel niet. Bijvullen verdunt helium maar verwijdert het niet: de fles moet eerst leeg.';

  @override
  String get gasCalculators_blender_error_insufficientGases =>
      'Een heliumvrij doel heeft twee heliumvrije vulgassen met verschillend O₂-gehalte nodig.';

  @override
  String get gasCalculators_blender_error_targetNotReached =>
      'Deze vulgassen bereiken het doelmengsel niet exact. Controleer de vulgassen en hun volgorde.';

  @override
  String get gasCalculators_blender_error_implausibleStartMix =>
      'De fles staat onder druk maar bevat geen zuurstof en geen helium, dus pure stikstof. Controleer het mengsel dat al in de fles zit.';

  @override
  String get gasCalculators_blender_about => 'Over het mengen';

  @override
  String get gasCalculators_blender_aboutBody =>
      'Partiaaldrukmenging voor het doelmengsel. Voeg elk vulgas op volgorde toe tot de getoonde druk en laat de fles daarna stabiliseren. Vulgassen en hun volgorde zijn instelbaar: zet je het laatste gas op 32/0, dan wordt met EAN32 in plaats van lucht afgevuld. Analyseer het uiteindelijke mengsel altijd voordat je ermee duikt.';

  @override
  String get gasCalculators_blender_conditions => 'Mengcondities';

  @override
  String get gasCalculators_blender_fillTemp => 'Vultemperatuur';

  @override
  String get gasCalculators_blender_fillTempHelp =>
      'De temperatuur van de fles tijdens het vullen. Elke druk in de procedure is de manometerwaarde bij deze temperatuur.';

  @override
  String get gasCalculators_blender_settledTemp => 'Rusttemperatuur';

  @override
  String get gasCalculators_blender_settledTempHelp =>
      'De temperatuur waarop de fles uiteindelijk uitkomt. De doeldruk is wat hij dan aangeeft.';

  @override
  String get gasCalculators_blender_gasModel => 'Gasmodel';

  @override
  String get gasCalculators_blender_modelIdeal => 'Ideaal gas';

  @override
  String get gasCalculators_blender_modelVanDerWaals => 'Van der Waals';

  @override
  String get gasCalculators_blender_modelZFactor => 'Reëel gas (Z-factor)';

  @override
  String get gasCalculators_blender_modelRecommended => 'Aanbevolen';

  @override
  String get gasCalculators_blender_modelHelp =>
      'Reëel gas (Z-factor) is het nauwkeurigst bij flesdrukken. Ideaal gas komt overeen met de meeste gepubliceerde mengtabellen. Van der Waals is bedoeld voor vergelijking met andere mengsoftware en wijkt bij vuldruk enkele procenten af.';

  @override
  String gasCalculators_blender_stepAdd(String gas) {
    return '$gas toevoegen';
  }

  @override
  String get gasCalculators_blender_stepStartLabel => 'Start';

  @override
  String gasCalculators_blender_settlesTo(String pressure, String temperature) {
    return 'Stabiliseert op $pressure bij $temperature';
  }

  @override
  String get gasCalculators_blender_templates => 'Sjablonen';

  @override
  String get gasCalculators_blender_templatesTitle =>
      'Sjablonen voor doelmengsels';

  @override
  String get gasCalculators_blender_saveTemplate => 'Huidig mengsel opslaan';

  @override
  String get gasCalculators_blender_manageTemplates => 'Sjablonen beheren';

  @override
  String gasCalculators_blender_templateSaved(String mix) {
    return '$mix opgeslagen';
  }

  @override
  String get gasCalculators_blender_templateExists =>
      'Dat mengsel is al opgeslagen.';

  @override
  String get gasCalculators_blender_templateInvalid =>
      'O₂ + He mag niet meer dan 100% zijn.';

  @override
  String get gasCalculators_blender_templateNeedsNumbers =>
      'Voer zowel O₂ als He als getal in.';

  @override
  String gasCalculators_blender_templateLimit(int count) {
    return 'Je kunt maximaal $count sjablonen opslaan.';
  }

  @override
  String get gasCalculators_blender_templateNone =>
      'Nog geen sjablonen. Sla een doelmengsel op om het hier opnieuw te gebruiken.';

  @override
  String gasCalculators_blender_templateDelete(String mix) {
    return '$mix verwijderen';
  }

  @override
  String get gasCalculators_blender_templateAdd => 'Sjabloon toevoegen';

  @override
  String get gasCalculators_blender_billing => 'Kosten';

  @override
  String get gasCalculators_blender_cylinderVolume => 'Waterinhoud van de fles';

  @override
  String get gasCalculators_blender_cylinderPresets => 'Voorinstellingen';

  @override
  String gasCalculators_blender_unitPrice(String unit) {
    return 'Prijs per 100 $unit';
  }

  @override
  String get gasCalculators_blender_currency => 'Valuta';

  @override
  String get gasCalculators_blender_costTotal => 'Totaal';

  @override
  String get gasCalculators_blender_costBasis =>
      'Er wordt afgerekend op de geleverde druk (waterinhoud van de fles × toegevoegde bar), zoals een vulstation meet.';

  @override
  String get gasCalculators_blender_costMissingPrice =>
      'Voer voor elk gas een prijs in om het totaal te zien.';

  @override
  String get gasCalculators_blender_saveFill => 'Deze vulling opslaan';

  @override
  String get gasCalculators_blender_billed => 'Gefactureerd';

  @override
  String get gasCalculators_blender_billedNone =>
      'Nog niets gefactureerd. Rond een vulling af en sla die hier op.';

  @override
  String get gasCalculators_blender_billedTo => 'Gefactureerd aan';

  @override
  String get gasCalculators_blender_addManualLine => 'Regel toevoegen';

  @override
  String get gasCalculators_blender_lineDescription => 'Omschrijving';

  @override
  String get gasCalculators_blender_lineAmount => 'Bedrag';

  @override
  String get gasCalculators_blender_clearBilled => 'Wissen';

  @override
  String get gasCalculators_blender_clearBilledTitle => 'Factuur wissen?';

  @override
  String gasCalculators_blender_clearBilledBody(int count) {
    return 'Dit verwijdert alle $count opgeslagen vullingen.';
  }

  @override
  String gasCalculators_blender_editLine(String label) {
    return '$label bewerken';
  }

  @override
  String gasCalculators_blender_deleteLine(String label) {
    return '$label verwijderen';
  }

  @override
  String gasCalculators_blender_fillAdded(String mix) {
    return '$mix toegevoegd aan de factuur';
  }

  @override
  String get gasCalculators_blender_billedIncomplete =>
      'Een of meer regels hebben geen prijs, dus dit totaal is onvolledig.';

  @override
  String get gasCalculators_blender_billedTotal => 'Totaal';

  @override
  String get gasCalculators_tab_mod => 'MOD';

  @override
  String get gasCalculators_tab_rockBottom => 'Rock Bottom';

  @override
  String get gasCalculators_tankSize => 'Flesgrootte';

  @override
  String get gasCalculators_title => 'Gascalculators';

  @override
  String get marineLife_siteSection_editExpectedTooltip =>
      'Verwachte soorten bewerken';

  @override
  String get marineLife_siteSection_errorLoadingExpected =>
      'Fout bij laden van verwachte soorten';

  @override
  String get marineLife_siteSection_errorLoadingSightings =>
      'Fout bij laden van waarnemingen';

  @override
  String get marineLife_siteSection_expectedSpecies => 'Verwachte soorten';

  @override
  String get marineLife_siteSection_noExpected =>
      'Geen verwachte soorten toegevoegd';

  @override
  String get marineLife_siteSection_noSpotted =>
      'Nog geen zeeleven waargenomen';

  @override
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  ) {
    return '$name, $count keer gespot';
  }

  @override
  String get marineLife_siteSection_spottedHere => 'Hier waargenomen';

  @override
  String get marineLife_siteSection_title => 'Zeeleven';

  @override
  String get marineLife_speciesDetail_backTooltip => 'Terug';

  @override
  String get marineLife_speciesDetail_depthRangeTitle => 'Dieptebereik';

  @override
  String get marineLife_speciesDetail_descriptionTitle => 'Beschrijving';

  @override
  String get marineLife_speciesDetail_divesLabel => 'Duiken';

  @override
  String get marineLife_speciesDetail_editTooltip => 'Soort bewerken';

  @override
  String marineLife_speciesDetail_errorPrefix(Object error) {
    return 'Fout: $error';
  }

  @override
  String get marineLife_speciesDetail_noSightings =>
      'Nog geen waarnemingen geregistreerd';

  @override
  String get marineLife_speciesDetail_notFound => 'Soort niet gevonden';

  @override
  String marineLife_speciesDetail_sightingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'waarnemingen',
      one: 'waarneming',
    );
    return '$count $_temp0';
  }

  @override
  String get marineLife_speciesDetail_sightingPeriodTitle =>
      'Waarnemingsperiode';

  @override
  String get marineLife_speciesDetail_sightingStatsTitle =>
      'Waarnemingsstatistieken';

  @override
  String get marineLife_speciesDetail_sitesLabel => 'Duikstekken';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return 'Klasse: $className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle => 'Toplocaties';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel =>
      'Totaal waarnemingen';

  @override
  String get marineLife_speciesEdit_addTitle => 'Soort toevoegen';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return '\"$name\" toegevoegd';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => 'Terug';

  @override
  String get marineLife_speciesEdit_categoryLabel => 'Categorie';

  @override
  String get marineLife_speciesEdit_commonNameError =>
      'Voer een gewone naam in';

  @override
  String get marineLife_speciesEdit_commonNameHint => 'bijv. Valse clownvis';

  @override
  String get marineLife_speciesEdit_commonNameLabel => 'Gewone naam';

  @override
  String get marineLife_speciesEdit_descriptionHint =>
      'Korte beschrijving van de soort...';

  @override
  String get marineLife_speciesEdit_descriptionLabel => 'Beschrijving';

  @override
  String get marineLife_speciesEdit_editTitle => 'Soort bewerken';

  @override
  String marineLife_speciesEdit_errorLoading(Object error) {
    return 'Fout bij laden van soort: $error';
  }

  @override
  String marineLife_speciesEdit_errorSaving(Object error) {
    return 'Fout bij opslaan van soort: $error';
  }

  @override
  String get marineLife_speciesEdit_saveButton => 'Opslaan';

  @override
  String get marineLife_speciesEdit_scientificNameHint =>
      'bijv. Amphiprion ocellaris';

  @override
  String get marineLife_speciesEdit_scientificNameLabel =>
      'Wetenschappelijke naam';

  @override
  String get marineLife_speciesEdit_taxonomyClassHint => 'bijv. Actinopterygii';

  @override
  String get marineLife_speciesEdit_taxonomyClassLabel => 'Taxonomische klasse';

  @override
  String marineLife_speciesEdit_updatedSnackbar(Object name) {
    return '\"$name\" bijgewerkt';
  }

  @override
  String get marineLife_speciesManage_allFilter => 'Alle';

  @override
  String get marineLife_speciesManage_appBarTitle => 'Soorten';

  @override
  String get marineLife_speciesManage_backTooltip => 'Terug';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return 'Ingebouwde soorten ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => 'Annuleren';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return 'Kan \"$name\" niet verwijderen - heeft waarnemingen';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip =>
      'Zoekopdracht wissen';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return 'Aangepaste soorten ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => 'Verwijderen';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen?';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle => 'Soort verwijderen?';

  @override
  String get marineLife_speciesManage_deleteTooltip => 'Soort verwijderen';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return '\"$name\" verwijderd';
  }

  @override
  String get marineLife_speciesManage_editTooltip => 'Soort bewerken';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return 'Fout bij verwijderen van soort: $error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return 'Fout bij herstellen van soorten: $error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound => 'Geen soorten gevonden';

  @override
  String get marineLife_speciesManage_resetButton => 'Herstellen';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      'Dit herstelt alle ingebouwde soorten naar hun oorspronkelijke waarden. Aangepaste soorten worden niet beinvloed. Ingebouwde soorten met bestaande waarnemingen worden bijgewerkt maar behouden.';

  @override
  String get marineLife_speciesManage_resetDialogTitle =>
      'Herstellen naar standaard?';

  @override
  String get marineLife_speciesManage_resetSuccess =>
      'Ingebouwde soorten hersteld naar standaardwaarden';

  @override
  String get marineLife_speciesManage_resetToDefaults =>
      'Herstellen naar standaard';

  @override
  String get marineLife_speciesManage_searchHint => 'Soorten zoeken...';

  @override
  String get marineLife_speciesPicker_allFilter => 'Alle';

  @override
  String get marineLife_speciesPicker_cancelButton => 'Annuleren';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip =>
      'Zoekopdracht wissen';

  @override
  String get marineLife_speciesPicker_closeTooltip => 'Soortenkiezer sluiten';

  @override
  String get marineLife_speciesPicker_doneButton => 'Gereed';

  @override
  String marineLife_speciesPicker_error(Object error) {
    return 'Fout: $error';
  }

  @override
  String get marineLife_speciesPicker_noSpeciesFound => 'Geen soorten gevonden';

  @override
  String get marineLife_speciesPicker_searchHint => 'Soorten zoeken...';

  @override
  String marineLife_speciesPicker_selectedCount(Object count) {
    return '$count geselecteerd';
  }

  @override
  String get marineLife_speciesPicker_title => 'Soorten selecteren';

  @override
  String get media_diveMediaSection_addTooltip => 'Foto of video toevoegen';

  @override
  String get media_diveMediaSection_cancelButton => 'Annuleren';

  @override
  String get media_diveMediaSection_cancelSelectionButton => 'Annuleren';

  @override
  String get media_diveMediaSection_emptyState => 'Nog geen foto\'s';

  @override
  String get media_diveMediaSection_errorLoading => 'Fout bij laden van media';

  @override
  String get media_diveMediaSection_selectAllButton => 'Alles selecteren';

  @override
  String media_diveMediaSection_selectedCount(int count) {
    return '$count geselecteerd';
  }

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Foto bekijken. Lang indrukken om te ontkoppelen';

  @override
  String get media_diveMediaSection_title => 'Foto\'s & video';

  @override
  String get media_diveMediaSection_replaceButton => 'Opnieuw koppelen';

  @override
  String get media_diveMediaSection_replaceEditedContent =>
      'De inhoud van dit bestand verschilt van het origineel. Opnieuw koppelen uploadt het opnieuw naar je mediaopslag.';

  @override
  String get media_diveMediaSection_replaceEditedTitle =>
      'Bestandsinhoud verschilt';

  @override
  String get media_diveMediaSection_unlinkButton => 'Ontkoppelen';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Ontkoppelen mislukt: $error';
  }

  @override
  String media_diveMediaSection_unlinkSelectedButton(int count) {
    return '$count ontkoppelen';
  }

  @override
  String media_diveMediaSection_unlinkSelectedContent(int count) {
    return 'Verwijdert $count media-items uit je bibliotheek, samen met hun cloudkopieen en miniaturen. Items die een duikstek nog gebruikt blijven behouden. Je originele bestanden blijven ongemoeid.';
  }

  @override
  String media_diveMediaSection_unlinkSelectedSuccess(int count) {
    return '$count items ontkoppeld';
  }

  @override
  String media_diveMediaSection_unlinkSelectedTitle(int count) {
    return '$count items ontkoppelen?';
  }

  @override
  String media_library_unlinkConfirmTitle(int count) {
    return '$count items ontkoppelen?';
  }

  @override
  String media_siteMediaSection_unlinkError(Object error) {
    return 'Ontkoppelen mislukt: $error';
  }

  @override
  String get media_library_unlinkConfirmBody =>
      'Ze verdwijnen uit je bibliotheek, samen met hun cloudkopieën en miniaturen. Je originele bestanden blijven ongemoeid. Dit kan niet ongedaan worden gemaakt.';

  @override
  String media_library_unlinkMetadataNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count daarvan hebben een bijschrift of favoriet opgeslagen in Submersion, en die details gaan verloren.',
      one:
          'Een daarvan heeft een bijschrift of favoriet opgeslagen in Submersion, en die details gaan verloren.',
    );
    return '$_temp0';
  }

  @override
  String get media_siteMediaSection_title => 'Media van de duikstek';

  @override
  String get media_siteMediaSection_addPhotos =>
      'Foto\'s of video\'s toevoegen';

  @override
  String get media_siteMediaSection_addDocument => 'Document toevoegen';

  @override
  String get media_siteMediaSection_emptyState =>
      'Geen kaarten, foto\'s of documenten aan deze duikstek gekoppeld';

  @override
  String media_siteMediaSection_divePhotosGroup(int count) {
    return 'Foto\'s van duiken hier ($count)';
  }

  @override
  String get media_siteMediaSection_divePhotoLabel => 'Duikfoto';

  @override
  String media_siteMediaSection_unlinkSelectedTitle(int count) {
    return '$count items ontkoppelen?';
  }

  @override
  String media_siteMediaSection_unlinkSelectedContent(int count) {
    return 'Verwijdert $count items uit je bibliotheek, inclusief cloudkopieën en miniaturen. Media die een duik nog gebruikt, blijven bewaard. Je originele bestanden blijven onaangetast.';
  }

  @override
  String media_siteMediaSection_unlinkSelectedSuccess(int count) {
    return '$count items ontkoppeld';
  }

  @override
  String get media_documentViewer_title => 'Document';

  @override
  String get media_documentViewer_unavailable =>
      'Dit document is niet beschikbaar op dit apparaat';

  @override
  String get media_documentViewer_availableOnOriginDevice =>
      'Het is beschikbaar op het apparaat waarmee het is toegevoegd, of via een geconfigureerde mediaopslag.';

  @override
  String media_documentViewer_attached(int count) {
    return '$count documenten toegevoegd';
  }

  @override
  String get media_diveScan_scanTooltip => 'Galerij doorzoeken naar foto\'s';

  @override
  String get media_diveScan_noPhotosFound =>
      'Geen nieuwe foto\'s gevonden bij deze duik';

  @override
  String get media_diveScan_accessDenied =>
      'Toegang tot de fotobibliotheek is vereist om foto\'s te zoeken';

  @override
  String media_diveScan_foundPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto\'s',
      one: '1 foto',
    );
    return '$_temp0 gevonden bij deze duik. Koppelen?';
  }

  @override
  String get media_diveScan_foundTitle => 'Foto\'s gevonden';

  @override
  String media_diveScan_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Foto\'s',
      one: 'Foto',
    );
    return '$_temp0 koppelen';
  }

  @override
  String get media_diveScan_cancelButton => 'Annuleren';

  @override
  String media_diveScan_error(String error) {
    return 'Fout bij het doorzoeken van de galerij: $error';
  }

  @override
  String get media_gpsBanner_addToSiteButton => 'Toevoegen aan duikstek';

  @override
  String media_gpsBanner_coordinates(Object coordinates) {
    return 'Coordinaten: $coordinates';
  }

  @override
  String get media_gpsBanner_createSiteButton => 'Duikstek aanmaken';

  @override
  String get media_gpsBanner_dismissTooltip => 'GPS-suggestie sluiten';

  @override
  String get media_gpsBanner_title => 'GPS gevonden in foto\'s';

  @override
  String media_import_failedToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto\'s',
      one: 'foto',
    );
    return 'Kan $_temp0 niet importeren';
  }

  @override
  String media_import_failedToImportError(Object error) {
    return 'Kan foto\'s niet importeren: $error';
  }

  @override
  String media_import_allAlreadyLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto\'s al gekoppeld aan deze duik',
      one: '1 foto al gekoppeld aan deze duik',
    );
    return '$_temp0';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return '$imported geimporteerd, $failed mislukt';
  }

  @override
  String media_import_importedAndSkipped(int imported, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      imported,
      locale: localeName,
      other: '$imported foto\'s geimporteerd',
      one: '1 foto geimporteerd',
    );
    return '$_temp0 ($skipped al gekoppeld)';
  }

  @override
  String media_import_importedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto\'s',
      one: 'foto',
    );
    return '$count $_temp0 geimporteerd';
  }

  @override
  String media_import_importingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto\'s',
      one: 'foto',
    );
    return '$count $_temp0 importeren...';
  }

  @override
  String get media_lightroom_openInLightroom => 'Openen in Lightroom';

  @override
  String get media_lightroom_suggestion_accept => 'Toevoegen aan deze duik';

  @override
  String get media_lightroom_suggestion_dismiss => 'Negeren';

  @override
  String get media_lightroom_suggestions_title => 'Suggesties uit Lightroom';

  @override
  String get media_miniProfile_headerLabel => 'Duikprofiel';

  @override
  String get media_miniProfile_semanticLabel => 'Mini duikprofielgrafiek';

  @override
  String get media_photoPicker_appBarTitle => 'Foto\'s selecteren';

  @override
  String get media_photoPicker_tab_gallery => 'Galerij';

  @override
  String get media_photoPicker_tab_files => 'Bestanden';

  @override
  String get media_photoPicker_tab_url => 'URL';

  @override
  String get media_photoPicker_clearSelectionButton => 'Wissen';

  @override
  String get media_photoPicker_closeTooltip => 'Fotokiezer sluiten';

  @override
  String get media_photoPicker_doneButton => 'Gereed';

  @override
  String media_photoPicker_doneCountButton(Object count) {
    return 'Gereed ($count)';
  }

  @override
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  ) {
    return 'Er zijn geen foto\'s gevonden tussen $startDate $startTime en $endDate $endTime.';
  }

  @override
  String get media_photoPicker_emptyTitle => 'Geen foto\'s gevonden';

  @override
  String get media_photoPicker_grantAccessButton => 'Doorgaan';

  @override
  String get media_photoPicker_openSettingsButton => 'Instellingen openen';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'Toegang tot de fotobibliotheek is geweigerd. Schakel deze in via Instellingen om duikfoto\'s toe te voegen.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion heeft toegang tot je fotobibliotheek nodig om duikfoto\'s toe te voegen.';

  @override
  String get media_photoPicker_permissionTitle => 'Duikfoto\'s';

  @override
  String get media_photoPicker_selectAllButton => 'Alles selecteren';

  @override
  String media_photoPicker_selectedCount(int count) {
    return '$count geselecteerd';
  }

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return 'Foto\'s worden getoond van $rangeText';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel =>
      'Selectie voor foto aan/uit';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel =>
      'Selectie voor foto aan/uit, geselecteerd';

  @override
  String get media_photoPicker_files_pickFilesButton => 'Bestanden kiezen…';

  @override
  String get media_photoPicker_files_pickFolderButton => 'Een map kiezen…';

  @override
  String get media_photoPicker_files_autoMatchLabel =>
      'Foto\'s en video\'s automatisch op datum aan duiken koppelen';

  @override
  String get media_photoPicker_files_emptyHint =>
      'Kies bestanden of een map om te beginnen.';

  @override
  String media_photoPicker_files_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items koppelen',
      one: '1 item koppelen',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachToSiteButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items aan deze duiklocatie koppelen',
      one: '1 item aan deze duiklocatie koppelen',
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
      other: '$fileCount bestanden',
      one: '1 bestand',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount duiken',
      one: '1 duik',
    );
    return '$_temp0, $_temp1, $unmatchedCount niet gekoppeld';
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
    return 'Duik $diveId';
  }

  @override
  String media_photoPicker_files_groupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bestanden',
      one: '1 bestand',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_unmatchedGroupTitle => 'Niet gekoppeld';

  @override
  String media_photoPicker_files_addAllToDive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count aan deze duik toevoegen',
      one: '1 aan deze duik toevoegen',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_addToDiveTooltip =>
      'Aan deze duik toevoegen';

  @override
  String get media_photoPicker_files_chooseDiveTooltip => 'Een duik kiezen';

  @override
  String get media_photoPicker_files_removeTooltip =>
      'Uit de selectie verwijderen';

  @override
  String get media_photoPicker_files_sourceExif => 'uit EXIF';

  @override
  String get media_photoPicker_files_sourceContainer => 'uit bestandsmetadata';

  @override
  String get media_photoPicker_files_sourceFileDate => 'uit bestandsdatum';

  @override
  String get media_photoPicker_files_sourceNone => 'geen datum gevonden';

  @override
  String media_photoPicker_files_shiftedTime(String shifted, String original) {
    return '$shifted (was $original)';
  }

  @override
  String get media_photoPicker_files_reasonNoTimestamp =>
      'Opnametijd kon niet worden gelezen';

  @override
  String media_photoPicker_files_reasonBeforeDive(String gap) {
    return '$gap voor de dichtstbijzijnde duik';
  }

  @override
  String media_photoPicker_files_reasonAfterDive(String gap) {
    return '$gap na de dichtstbijzijnde duik';
  }

  @override
  String get media_photoPicker_files_reasonNoDives =>
      'Geen duiken om mee te vergelijken';

  @override
  String get media_photoPicker_files_offsetLabel =>
      'Opnametijden verschuiven met';

  @override
  String get media_photoPicker_files_offsetResetTooltip =>
      'Verschuiving herstellen';

  @override
  String media_photoPicker_files_offsetBackTooltip(String amount) {
    return '$amount eerder verschuiven';
  }

  @override
  String media_photoPicker_files_offsetForwardTooltip(String amount) {
    return '$amount later verschuiven';
  }

  @override
  String media_photoPicker_files_linkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items gekoppeld',
      one: '1 item gekoppeld',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachedToSiteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items aan deze duiklocatie gekoppeld',
      one: '1 item aan deze duiklocatie gekoppeld',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_undo => 'Ongedaan maken';

  @override
  String get media_photoPicker_thumbnailAlreadyLinkedLabel =>
      'Foto al gekoppeld aan deze duik';

  @override
  String get media_perdixOverlay_labelCns => 'CNS';

  @override
  String get media_perdixOverlay_labelDepth => 'DIEPTE';

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
  String get media_perdixOverlay_labelTime => 'TIJD';

  @override
  String get media_perdixOverlay_labelTts => 'TTS';

  @override
  String get media_perdixOverlay_toggleTooltip => 'Duikcomputer-overlay';

  @override
  String get media_photoViewer_cannotShare => 'Kan deze foto niet delen';

  @override
  String get media_photoViewer_cannotWriteMetadata =>
      'Kan metadata niet schrijven - media niet gekoppeld aan bibliotheek';

  @override
  String get media_photoViewer_closeTooltip => 'Fotoviewer sluiten';

  @override
  String get media_photoViewer_diveDataWrittenToPhoto =>
      'Duikgegevens naar foto geschreven';

  @override
  String get media_photoViewer_diveDataWrittenToVideo =>
      'Duikgegevens naar video geschreven';

  @override
  String media_photoViewer_errorLoadingPhotos(Object error) {
    return 'Fout bij laden van foto\'s: $error';
  }

  @override
  String get media_photoViewer_failedToLoadImage => 'Kan afbeelding niet laden';

  @override
  String get media_photoViewer_failedToLoadVideo => 'Kan video niet laden';

  @override
  String media_photoViewer_failedToShare(Object error) {
    return 'Delen mislukt: $error';
  }

  @override
  String get media_photoViewer_failedToWriteMetadata =>
      'Kan metadata niet schrijven';

  @override
  String media_photoViewer_failedToWriteMetadataError(Object error) {
    return 'Kan metadata niet schrijven: $error';
  }

  @override
  String get media_photoViewer_nextTooltip => 'Volgende media';

  @override
  String get media_photoViewer_noPhotosAvailable => 'Geen foto\'s beschikbaar';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel =>
      'Video afspelen of pauzeren';

  @override
  String get media_photoViewer_previousTooltip => 'Vorige media';

  @override
  String get media_photoViewer_seekVideoLabel => 'Videopositie zoeken';

  @override
  String get media_photoViewer_shareTooltip => 'Foto delen';

  @override
  String get media_photoViewer_toggleOverlayLabel => 'Foto-overlay aan/uit';

  @override
  String get media_photoViewer_videoFileNotFound =>
      'Videobestand niet gevonden';

  @override
  String get media_photoViewer_videoNotLinked =>
      'Video niet gekoppeld aan bibliotheek';

  @override
  String get media_photoViewer_writeDiveDataTooltip =>
      'Duikgegevens naar foto schrijven';

  @override
  String get media_quickSiteDialog_cancelButton => 'Annuleren';

  @override
  String get media_quickSiteDialog_createButton => 'Duikstek aanmaken';

  @override
  String get media_quickSiteDialog_description =>
      'Maak een nieuwe duikstek aan met GPS-coordinaten uit je foto.';

  @override
  String get media_quickSiteDialog_siteNameError =>
      'Voer een naam voor de duikstek in';

  @override
  String get media_quickSiteDialog_siteNameHint =>
      'Voer een naam in voor deze duikstek';

  @override
  String get media_quickSiteDialog_siteNameLabel => 'Naam duikstek';

  @override
  String get media_quickSiteDialog_title => 'Duikstek aanmaken';

  @override
  String get media_scanResults_allPhotosLinked => 'Alle foto\'s al gekoppeld';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return 'Alle $count foto\'s van deze reis zijn al aan duiken gekoppeld.';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count foto\'s al gekoppeld';
  }

  @override
  String get media_scanResults_cancelButton => 'Annuleren';

  @override
  String media_scanResults_diveNumber(Object number) {
    return 'Duik #$number';
  }

  @override
  String media_scanResults_foundNewPhotos(Object count) {
    return '$count nieuwe foto\'s gevonden';
  }

  @override
  String get media_scanResults_linkButton => 'Koppelen';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return '$count foto\'s koppelen';
  }

  @override
  String get media_scanResults_noPhotosFound => 'Geen foto\'s gevonden';

  @override
  String get media_scanResults_okButton => 'OK';

  @override
  String get media_scanResults_unknownSite => 'Onbekende duikstek';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return '$count foto\'s konden niet aan een duik worden gekoppeld (gemaakt buiten duiktijden)';
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
  String get media_unavailablePlaceholder_notOnDevice => 'Niet op dit apparaat';

  @override
  String get media_unavailablePlaceholder_signInRequired => 'Sign in to view';

  @override
  String get media_writeMetadata_cancelButton => 'Annuleren';

  @override
  String get media_writeMetadata_depthLabel => 'Diepte';

  @override
  String get media_writeMetadata_descriptionPhoto =>
      'De volgende metadata wordt naar de foto geschreven:';

  @override
  String get media_writeMetadata_descriptionVideo =>
      'De volgende metadata wordt naar de video geschreven:';

  @override
  String get media_writeMetadata_diveTimeLabel => 'Duiktijd';

  @override
  String get media_writeMetadata_gpsLabel => 'GPS';

  @override
  String get media_writeMetadata_keepOriginalVideo => 'Originele video bewaren';

  @override
  String get media_writeMetadata_livePhotoUnsupported =>
      'Live Photos worden nog niet ondersteund. Dupliceer deze als stilstaande foto en schrijf de duikgegevens vervolgens naar de kopie.';

  @override
  String get media_writeMetadata_noDataAvailable =>
      'Geen duikgegevens beschikbaar om te schrijven.';

  @override
  String get media_writeMetadata_siteLabel => 'Duikstek';

  @override
  String get media_writeMetadata_temperatureLabel => 'Temperatuur';

  @override
  String get media_writeMetadata_titlePhoto =>
      'Duikgegevens naar foto schrijven';

  @override
  String get media_writeMetadata_titleVideo =>
      'Duikgegevens naar video schrijven';

  @override
  String get media_writeMetadata_warningPhotoText =>
      'Dit wijzigt de originele foto.';

  @override
  String get media_writeMetadata_warningVideoText =>
      'Er wordt een nieuwe video aangemaakt met de metadata. Videometadata kan niet ter plekke worden gewijzigd.';

  @override
  String get media_writeMetadata_writeButton => 'Schrijven';

  @override
  String get nav_buddies => 'Buddy\'s';

  @override
  String get nav_certifications => 'Brevetten';

  @override
  String get nav_courses => 'Cursussen';

  @override
  String get nav_coursesSubtitle => 'Training & Opleiding';

  @override
  String get nav_diveCenters => 'Duikcentra';

  @override
  String get nav_dives => 'Duiken';

  @override
  String get nav_equipment => 'Uitrusting';

  @override
  String get nav_gpsLog => 'GPS-log';

  @override
  String get media_console_library => 'Bibliotheek';

  @override
  String get media_console_transfers => 'Overdrachten';

  @override
  String get media_console_import => 'Importeren';

  @override
  String get media_import_launch => 'Media importeren...';

  @override
  String get media_import_review_title => 'Import controleren';

  @override
  String media_import_review_confirm(int count) {
    return '$count items importeren';
  }

  @override
  String media_import_review_result(int linked, int skipped, int failed) {
    return '$linked gekoppeld, $skipped overgeslagen, $failed mislukt';
  }

  @override
  String get media_import_review_chooseSite => 'Site kiezen';

  @override
  String get media_import_review_ambiguous => 'Meerdere duiken komen overeen';

  @override
  String get media_import_review_noMatch => 'Geen overeenkomende duik';

  @override
  String get media_import_review_skipped => 'Niet geïmporteerd';

  @override
  String media_import_review_linkChip(int number) {
    return 'Koppelen aan #$number';
  }

  @override
  String get media_import_review_linkToDive => 'Aan duik koppelen';

  @override
  String get media_import_review_linkToSite => 'Aan duikstek koppelen';

  @override
  String get media_import_review_chooseDive => 'Duik kiezen';

  @override
  String get media_import_intro =>
      'Foto\'s worden tijdens het importeren aan een duik of duiksite gekoppeld.';

  @override
  String get media_console_sources => 'Bronnen';

  @override
  String get media_sources_browseHeader => 'Bladeren op bron';

  @override
  String get media_sources_watchedHeader => 'Bewaakte mappen';

  @override
  String get media_sources_addWatched => 'Map toevoegen...';

  @override
  String get media_sources_scanFailed => 'Scannen mislukt';

  @override
  String get media_sources_scanNow => 'Nu scannen';

  @override
  String get media_sources_autoApply =>
      'Exacte overeenkomsten automatisch opnieuw koppelen';

  @override
  String get media_sources_neverScanned => 'Nooit gescand';

  @override
  String get media_source_gallery => 'Fotobibliotheek';

  @override
  String get media_source_localFile => 'Lokale bestanden';

  @override
  String get media_source_networkUrl => 'Weblinks';

  @override
  String get media_source_manifest => 'Abonnementen';

  @override
  String get media_source_connector => 'Verbonden services';

  @override
  String get media_source_mediaStore => 'Cloudmediaopslag';

  @override
  String get media_source_signature => 'Handtekeningen';

  @override
  String get media_repairHistory_title => 'Herstelgeschiedenis';

  @override
  String get media_repairHistory_empty => 'Nog geen herstelacties';

  @override
  String get media_repairHistory_action_relink => 'Opnieuw gekoppeld';

  @override
  String get media_repairHistory_action_cloudBacked => 'Cloudgebaseerd';

  @override
  String get media_repairHistory_action_autoRelink =>
      'Automatisch opnieuw gekoppeld';

  @override
  String get media_smartAlbum_save => 'Opslaan als album';

  @override
  String get media_smartAlbum_saveTitle => 'Naam dit album';

  @override
  String get media_smartAlbum_albums => 'Albums';

  @override
  String get media_smartAlbum_delete => 'Album verwijderen';

  @override
  String get media_smartAlbum_deleteFailed => 'Album verwijderen mislukt';

  @override
  String get media_smartAlbum_saved => 'Album opgeslagen';

  @override
  String media_sources_lastScanned(String date) {
    return 'Laatst gescand $date';
  }

  @override
  String media_sources_scanResult(int indexed, int repaired) {
    return '$indexed bestanden geïndexeerd, $repaired opnieuw gekoppeld';
  }

  @override
  String get media_repairHistory_sourceFolder => 'mapscan';

  @override
  String get media_repairHistory_sourcePhotoLibrary => 'fotobibliotheek';

  @override
  String get media_repairHistory_sourceStore => 'cloudmediaopslag';

  @override
  String get media_repairHistory_sourceWatcher => 'bewaakte mappen';

  @override
  String get media_repairHistory_sourceManual => 'handmatig opnieuw koppelen';

  @override
  String media_repairHistory_source(String source) {
    return 'via $source';
  }

  @override
  String get media_missing_empty => 'Geen ontbrekende bestanden';

  @override
  String media_missing_offlineVolumes(int count) {
    return '$count op offline volumes';
  }

  @override
  String get media_missing_repair => 'Herstellen...';

  @override
  String get media_repair_title => 'Ontbrekende bestanden herstellen';

  @override
  String get media_repair_addFolder => 'Map toevoegen...';

  @override
  String get media_repair_usePhotoLibrary => 'Fotobibliotheek doorzoeken';

  @override
  String get media_repair_useStore => 'Cloudmediaopslag gebruiken';

  @override
  String get media_repair_scan => 'Scannen';

  @override
  String media_repair_prefixMove(String from, String to, int count) {
    return 'Mapverplaatsing gedetecteerd: $from naar $to dekt $count bestanden';
  }

  @override
  String get media_repair_confidence_exact => 'Exact';

  @override
  String get media_repair_confidence_probable => 'Naam en grootte';

  @override
  String get media_repair_confidence_edited => 'Bewerkt bestand';

  @override
  String get media_repair_confidence_unmatched => 'Geen kandidaat';

  @override
  String get media_repair_unverified => 'Niet geverifieerd tegen de opslag';

  @override
  String media_repair_apply(int count) {
    return '$count bestanden opnieuw koppelen';
  }

  @override
  String media_repair_summary(
    int relinked,
    int cloudBacked,
    int reuploads,
    int failed,
    int skipped,
  ) {
    return '$relinked opnieuw gekoppeld, $cloudBacked cloudgebaseerd, $reuploads heruploads in wachtrij, $failed mislukt, $skipped overgeslagen';
  }

  @override
  String get media_library_empty => 'Nog geen media';

  @override
  String get media_library_filter_all => 'Alles';

  @override
  String get media_library_filter_photos => 'Foto\'s';

  @override
  String get media_library_filter_videos => 'Video\'s';

  @override
  String get media_library_filter_site => 'Duikstek';

  @override
  String get media_library_filter_trip => 'Reis';

  @override
  String get media_library_filter_dates => 'Datums';

  @override
  String get media_library_filter_missing => 'Ontbrekende bestanden';

  @override
  String media_library_filter_missingCount(int count) {
    return 'Ontbrekende bestanden ($count)';
  }

  @override
  String get media_library_filter_clear => 'Filters wissen';

  @override
  String get media_library_filter_any => 'Alle';

  @override
  String get media_library_filter_title => 'Media filteren';

  @override
  String get media_library_filter_apply => 'Toepassen';

  @override
  String get media_library_sort_title => 'Media sorteren';

  @override
  String get media_smartAlbum_load => 'Album laden';

  @override
  String get media_divePicker_title => 'Naar duik verplaatsen';

  @override
  String get media_divePicker_search => 'Duiken zoeken';

  @override
  String get media_library_moveToDive => 'Naar duik verplaatsen';

  @override
  String get media_library_unlinkSelected => 'Ontkoppelen';

  @override
  String media_library_selectedCount(int count) {
    return '$count geselecteerd';
  }

  @override
  String get media_library_unlinkedHeader => 'Niet gekoppeld';

  @override
  String get media_library_diveHeaderHint => 'Deze duik openen';

  @override
  String get media_library_untitledDiveHeader => 'Naamloze duik';

  @override
  String get media_library_viewMode_byDive => 'Per duik';

  @override
  String get media_library_viewMode_grid => 'Raster';

  @override
  String get media_library_viewMode_timeline => 'Tijdlijn';

  @override
  String get media_viewer_goToDive => 'Naar duik';

  @override
  String get nav_home => 'Home';

  @override
  String get nav_media => 'Media';

  @override
  String get nav_more => 'Meer';

  @override
  String get nav_planning => 'Planning';

  @override
  String get nav_planningSubtitle => 'Duikplanner, Rekenhulpen';

  @override
  String get nav_settings => 'Instellingen';

  @override
  String get nav_sites => 'Duikstekken';

  @override
  String get nav_statistics => 'Statistieken';

  @override
  String get nav_tooltip_closeMenu => 'Menu sluiten';

  @override
  String get nav_tooltip_collapseMenu => 'Menu inklappen';

  @override
  String get nav_tooltip_expandMenu => 'Menu uitklappen';

  @override
  String get nav_transfer => 'Overdracht';

  @override
  String get nav_trips => 'Reizen';

  @override
  String plannerCanvas_bailout_available(String liters) {
    return 'Beschikbaar $liters';
  }

  @override
  String get plannerCanvas_bailout_insufficient =>
      'Bailoutgas onvoldoende voor het slechtste geval';

  @override
  String plannerCanvas_bailout_required(String liters) {
    return 'Nodig $liters';
  }

  @override
  String get plannerCanvas_bailout_title => 'Bailout (open circuit)';

  @override
  String plannerCanvas_bailout_tts(String minutes) {
    return 'Bailout-TTS $minutes′';
  }

  @override
  String plannerCanvas_bailout_worstCase(String minutes, String depth) {
    return 'Slechtste geval op $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_ccr_setpointHigh => 'Setpoint hoog (bar)';

  @override
  String get plannerCanvas_ccr_setpointLow => 'Setpoint laag (bar)';

  @override
  String get plannerCanvas_ccr_switchDepth => 'Setpoint-wisseldiepte';

  @override
  String get plannerCanvas_pscr_ratio => 'pSCR-verhouding';

  @override
  String get plannerCanvas_pscr_ratio_hint =>
      'Groter = meer vers gas, kleinere O₂-daling';

  @override
  String plannerCanvas_chip_cns(String value) {
    return 'CNS $value%';
  }

  @override
  String plannerCanvas_chip_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemen',
      one: '1 probleem',
    );
    return '$_temp0';
  }

  @override
  String get plannerCanvas_compare_action => 'Vergelijken';

  @override
  String get plannerCanvas_compare_needTwo =>
      'Selecteer minstens twee plannen om te vergelijken';

  @override
  String get plannerCanvas_compare_title => 'Plannen vergelijken';

  @override
  String get plannerCanvas_contingency_base => 'Basis';

  @override
  String get plannerCanvas_contingency_depthDelta => 'Extra diepte';

  @override
  String plannerCanvas_contingency_lostGas(String gas) {
    return '$gas verloren';
  }

  @override
  String plannerCanvas_contingency_previewing(String label) {
    return 'Voorbeeld: $label';
  }

  @override
  String get plannerCanvas_contingency_timeDelta => 'Extra minuten';

  @override
  String plannerCanvas_chart_meanDepth(String depth) {
    return 'gem. $depth';
  }

  @override
  String get plannerCanvas_contingency_title => 'Noodplannen';

  @override
  String get plannerCanvas_contingency_turnFraction => 'Keerfractie';

  @override
  String get plannerCanvas_contingency_turnRule => 'Keerdruk-regel';

  @override
  String get plannerCanvas_convert_success => 'Duik aangemaakt vanuit plan';

  @override
  String get plannerCanvas_convert_view => 'Bekijk';

  @override
  String plannerCanvas_follow_chip(String name) {
    return 'Volgt $name';
  }

  @override
  String get plannerCanvas_follow_empty => 'Nog geen gelogde duiken';

  @override
  String get plannerCanvas_follow_noTissues =>
      'Geen profielgegevens voor die duik — oppervlakte-interval ingesteld zonder weefselverzadiging';

  @override
  String get plannerCanvas_follow_title => 'Volg een duik';

  @override
  String plannerCanvas_gas_minGas(String pressure) {
    return 'min. gas $pressure';
  }

  @override
  String plannerCanvas_gas_turnAt(String pressure) {
    return 'keer om bij $pressure';
  }

  @override
  String plannerCanvas_issue_gasDensityCritical(String value) {
    return 'Gasdichtheid $value g/L boven harde limiet';
  }

  @override
  String plannerCanvas_issue_gasDensityHigh(String value) {
    return 'Gasdichtheid $value g/L boven aanbevolen limiet';
  }

  @override
  String plannerCanvas_issue_hypoxic(String depth, String value) {
    return 'Hypoxisch gas op $depth (ppO₂ $value bar)';
  }

  @override
  String plannerCanvas_issue_minGas(String pressure) {
    return 'Fles eindigt onder het rock-bottom-minimum van $pressure';
  }

  @override
  String get plannerCanvas_issue_noBailout =>
      'CCR-decompressieplan heeft geen bailoutgas aan boord';

  @override
  String get plannerCanvas_issue_noDecoGas =>
      'Decompressie vereist maar geen decogas meegenomen';

  @override
  String get plannerCanvas_range_base => 'Basis';

  @override
  String get plannerCanvas_range_legend =>
      'Cellen tonen de tijd naar de oppervlakte; rood = niet duikbaar zoals gepland';

  @override
  String get plannerCanvas_pane_collapse => 'Paneel inklappen';

  @override
  String get plannerCanvas_pane_expand => 'Paneel uitklappen';

  @override
  String get plannerCanvas_tab_setup => 'Instellingen';

  @override
  String get plannerCanvas_o2Narcotic => 'O₂ als narcotisch behandelen';

  @override
  String get plannerCanvas_rates_ascent => 'Stijgsnelheid';

  @override
  String get plannerCanvas_rates_descent => 'Daalsnelheid';

  @override
  String get plannerCanvas_rates_title => 'Snelheden';

  @override
  String get plannerCanvas_range_title => 'Bereiktabel';

  @override
  String get plannerCanvas_results_noDeco => 'Geen decompressie vereist';

  @override
  String plannerCanvas_sac_useLogged(String sac) {
    return 'Gebruik gelogd gemiddelde ($sac)';
  }

  @override
  String plannerCanvas_saved_deleteConfirmBody(String name) {
    return '\'$name\' definitief verwijderen?';
  }

  @override
  String get plannerCanvas_saved_deleteConfirmTitle => 'Plan verwijderen?';

  @override
  String get plannerCanvas_saved_duplicate => 'Dupliceren';

  @override
  String get plannerCanvas_saved_empty => 'Nog geen opgeslagen plannen';

  @override
  String get plannerCanvas_saved_title => 'Opgeslagen plannen';

  @override
  String get plannerCanvas_name_dialogTitle => 'Geef je plan een naam';

  @override
  String get plannerCanvas_name_defaultFallback => 'Duikplan';

  @override
  String plannerCanvas_scrub_bailout(String minutes) {
    return 'BO $minutes′';
  }

  @override
  String plannerCanvas_scrub_readout(String minutes, String depth) {
    return 'RT $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_share_import => 'Importeren';

  @override
  String plannerCanvas_share_importFailed(String reason) {
    return 'Kon plan niet importeren: $reason';
  }

  @override
  String get plannerCanvas_share_menu => 'Planbestand delen';

  @override
  String get plannerCanvas_slate_menu => 'Slate exporteren (PDF)';

  @override
  String get plannerCanvas_slate_minGas => 'Minimum gas';

  @override
  String get plannerCanvas_slate_turn => 'Keerpunt';

  @override
  String get plannerCanvas_table_depth => 'Diepte';

  @override
  String get plannerCanvas_table_gas => 'Gas';

  @override
  String get plannerCanvas_table_runtime => 'RT';

  @override
  String get plannerCanvas_table_stop => 'Stop';

  @override
  String get plannerCanvas_turnRule_allUsable => 'Alles bruikbaar';

  @override
  String get plannerCanvas_turnRule_custom => 'Aangepast';

  @override
  String get plannerCanvas_turnRule_halves => 'Helften';

  @override
  String get plannerCanvas_turnRule_none => 'Geen';

  @override
  String get plannerCanvas_turnRule_thirds => 'Derden';

  @override
  String get planning_appBar_title => 'Planning';

  @override
  String get planning_card_decoCalculator_description =>
      'Bereken no-decompressielimieten, benodigde decostops en CNS/OTU-blootstelling voor duikprofielen met meerdere niveaus.';

  @override
  String get planning_card_decoCalculator_subtitle =>
      'Plan duiken met decompressiestops';

  @override
  String get planning_card_decoCalculator_title => 'Decocalculator';

  @override
  String get planning_card_divePlanner_description =>
      'Plan complexe duiken met meerdere diepteniveaus, gaswisselingen en automatische berekening van decompressiestops.';

  @override
  String get planning_card_divePlanner_subtitle =>
      'Maak duikplannen met meerdere niveaus';

  @override
  String get planning_card_divePlanner_title => 'Duikplanner';

  @override
  String get planning_card_gasCalculators_description =>
      'Vier gespecialiseerde gascalculators:\n• MOD - Maximale werkdiepte voor een gasmengsel\n• Beste mix - Ideaal O₂% voor een doeldiepte\n• Verbruik - Schatting gasverbruik\n• Noodreserve - Berekening noodreserve';

  @override
  String get planning_card_gasCalculators_subtitle =>
      'MOD, Beste mix, Verbruik, Noodreserve';

  @override
  String get planning_card_gasCalculators_title => 'Gascalculators';

  @override
  String get planning_card_surfaceInterval_description =>
      'Bereken het minimale oppervlakte-interval dat nodig is tussen duiken op basis van weefselbelasting. Visualiseer hoe je 16 weefselcompartimenten ontgassen in de tijd.';

  @override
  String get planning_card_surfaceInterval_subtitle =>
      'Plan herhalingsduikintervallen';

  @override
  String get planning_card_surfaceInterval_title => 'Oppervlakte-interval';

  @override
  String get planning_card_weightCalculator_description =>
      'Schat het gewicht dat je nodig hebt op basis van je duikpak, flesmateriaal, watertype en lichaamsgewicht.';

  @override
  String get planning_card_weightCalculator_subtitle =>
      'Aanbevolen gewicht voor je uitrusting';

  @override
  String get planning_card_weightCalculator_title => 'Gewichtscalculator';

  @override
  String get planning_info_disclaimer =>
      'Deze tools zijn alleen voor planningsdoeleinden. Controleer berekeningen altijd en volg je duikopleiding.';

  @override
  String get planning_newPlan => 'Nieuw plan';

  @override
  String get planning_section_tools => 'Gereedschappen';

  @override
  String get planning_summary_prompt => 'Kies een hulpmiddel om te beginnen';

  @override
  String get planning_summary_savedPlans => 'Opgeslagen plannen';

  @override
  String get planning_summary_noPlans => 'Nog geen opgeslagen plannen';

  @override
  String get planning_sidebar_appBar_title => 'Planning';

  @override
  String get planning_sidebar_decoCalculator_subtitle => 'NDL & decostops';

  @override
  String get planning_sidebar_decoCalculator_title => 'Decocalculator';

  @override
  String get planning_sidebar_divePlanner_subtitle =>
      'Duikplannen met meerdere niveaus';

  @override
  String get planning_sidebar_divePlanner_title => 'Duikplanner';

  @override
  String get planning_sidebar_gasCalculators_subtitle => 'MOD, Beste mix, meer';

  @override
  String get planning_sidebar_gasCalculators_title => 'Gascalculators';

  @override
  String get planning_sidebar_info_disclaimer =>
      'Planningstools zijn alleen ter referentie. Controleer berekeningen altijd.';

  @override
  String get planning_sidebar_surfaceInterval_subtitle =>
      'Planning herhalingsduiken';

  @override
  String get planning_sidebar_surfaceInterval_title => 'Oppervlakte-interval';

  @override
  String get planning_sidebar_weightCalculator_subtitle => 'Aanbevolen gewicht';

  @override
  String get planning_sidebar_weightCalculator_title => 'Gewichtscalculator';

  @override
  String get planning_welcome_quickTips_title => 'Snelle tips';

  @override
  String get planning_welcome_subtitle =>
      'Selecteer een tool in de zijbalk om te beginnen';

  @override
  String get planning_welcome_tip_decoCalculator =>
      'Decocalculator voor NDL en stoptijden';

  @override
  String get planning_welcome_tip_divePlanner =>
      'Duikplanner voor duikplannen met meerdere niveaus';

  @override
  String get planning_welcome_tip_gasCalculators =>
      'Gascalculators voor MOD en gasplanning';

  @override
  String get planning_welcome_tip_weightCalculator =>
      'Gewichtscalculator voor triminstelling';

  @override
  String get planning_welcome_title => 'Planningstools';

  @override
  String get settings_about_aboutSubmersion => 'Over Submersion';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description =>
      'Houd je duiken bij, beheer uitrusting en verken duikstekken.';

  @override
  String get settings_about_header => 'Over';

  @override
  String get settings_about_openSourceLicenses => 'Open source-licenties';

  @override
  String get settings_about_reportIssue => 'Probleem melden';

  @override
  String get settings_about_reportIssue_copy => 'Link kopiëren';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Ga naar github.com/submersion-app/submersion/issues';

  @override
  String settings_about_version(String version) {
    return 'Versie $version';
  }

  @override
  String get settings_appBar_title => 'Instellingen';

  @override
  String get settings_appearance_appLanguage => 'App-taal';

  @override
  String get settings_appearance_displaySize => 'Weergavegrootte';

  @override
  String settings_appearance_displaySize_value(int percent) {
    return '$percent%';
  }

  @override
  String get settings_appearance_displaySize_reset => 'Herstellen';

  @override
  String get settings_appearance_displaySize_smaller => 'Kleiner';

  @override
  String get settings_appearance_displaySize_larger => 'Groter';

  @override
  String get settings_appearance_depthColoredCards =>
      'Dieptegekleurde duikkaarten';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Toon duikkaarten met oceaangekleurde achtergronden op basis van diepte';

  @override
  String get settings_appearance_cardColorAttribute => 'Kaarten kleuren op';

  @override
  String get settings_appearance_cardColorAttribute_subtitle =>
      'Kies welk attribuut de achtergrondkleur van kaarten bepaalt';

  @override
  String get settings_appearance_cardColorAttribute_none => 'Geen';

  @override
  String get settings_appearance_cardColorAttribute_depth => 'Diepte';

  @override
  String get settings_appearance_cardColorAttribute_duration => 'Duur';

  @override
  String get settings_appearance_cardColorAttribute_temperature =>
      'Temperatuur';

  @override
  String get settings_appearance_colorGradient => 'Kleurverloop';

  @override
  String get settings_appearance_colorGradient_subtitle =>
      'Kies het kleurbereik voor kaartachtergronden';

  @override
  String get settings_appearance_colorGradient_ocean => 'Oceaan';

  @override
  String get settings_appearance_colorGradient_thermal => 'Thermal';

  @override
  String get settings_appearance_colorGradient_sunset => 'Zonsondergang';

  @override
  String get settings_appearance_colorGradient_forest => 'Bos';

  @override
  String get settings_appearance_colorGradient_monochrome => 'Monochroom';

  @override
  String get settings_appearance_colorGradient_custom => 'Aangepast';

  @override
  String get settings_appearance_gasSwitchMarkers => 'Gaswisselmarkeringen';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'Toon markeringen voor gaswisselingen';

  @override
  String get settings_appearance_gasTimeline => 'Gastijdlijn';

  @override
  String get settings_appearance_gasTimeline_subtitle =>
      'Gasverbruiksstrook standaard onder het duikprofiel weergeven';

  @override
  String get settings_appearance_header_diveDetails => 'Duikdetails';

  @override
  String get settings_appearance_header_diveLog => 'Duiklogboek';

  @override
  String get settings_appearance_header_diveProfile => 'Duikprofiel';

  @override
  String get settings_appearance_header_diveSites => 'Duikstekken';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility =>
      'Sectievolgorde &amp; zichtbaarheid';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility_subtitle =>
      'Kies welke secties worden weergegeven en hun volgorde';

  @override
  String get settings_diveDetailSections_title =>
      'Sectievolgorde &amp; zichtbaarheid';

  @override
  String get settings_diveDetailSections_resetToDefault =>
      'Herstellen naar standaard';

  @override
  String get settings_diveDetailSections_fixedSections =>
      'Vaste secties: koptekst, duikprofielgrafiek';

  @override
  String get settings_diveDetailSections_configurableSections =>
      'Configureerbare secties (sleep om te herordenen)';

  @override
  String get diveDetailSection_decoO2_name => 'Deco-status / weefselbelasting';

  @override
  String get diveDetailSection_decoO2_description =>
      'NDL, plafond, weefsel-heatmap, O2-toxiciteit';

  @override
  String get diveDetailSection_safetyReview_name => 'Veiligheidscontrole';

  @override
  String get diveDetailSection_safetyReview_description =>
      'Automatische profielobservaties na de duik';

  @override
  String get safetyReview_sectionTitle => 'Veiligheidscontrole';

  @override
  String safetyReview_findingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observaties',
      one: '1 observatie',
    );
    return '$_temp0';
  }

  @override
  String safetyReview_rapidAscent_title(String rate, String duration) {
    return 'Opstijging overschreed $rate gedurende $duration';
  }

  @override
  String safetyReview_missedDecoStop_title(String excess, String duration) {
    return 'Diepte lag $excess boven het vereiste stopplafond gedurende $duration';
  }

  @override
  String safetyReview_omittedSafetyStop_title(String remaining) {
    return 'De aanbevolen veiligheidsstop is met $remaining ingekort';
  }

  @override
  String safetyReview_sawtoothProfile_title(int count) {
    return '$count herhaalde op-en-neer dieptewisselingen tijdens de duik';
  }

  @override
  String safetyReview_highSurfaceGf_title(String gf, String gfHigh) {
    return 'Aan de oppervlakte gekomen met gradiëntfactor $gf, boven de ingestelde $gfHigh';
  }

  @override
  String safetyReview_timeRange(String start, String end) {
    return 'Op $start–$end';
  }

  @override
  String get safetyReview_dismiss => 'Negeren';

  @override
  String get safetyReview_restore => 'Herstellen';

  @override
  String get safetyReview_dismissAll => 'Alles negeren';

  @override
  String get safetyReview_restoreAll => 'Alles herstellen';

  @override
  String get safetySettings_dismissAll => 'Alle observaties negeren';

  @override
  String get safetySettings_dismissAll_subtitle =>
      'Alle observaties in dit logboek als beoordeeld markeren';

  @override
  String get safetySettings_dismissAll_confirmTitle =>
      'Alle observaties negeren?';

  @override
  String get safetySettings_dismissAll_confirmBody =>
      'Elke observatie bij elke geanalyseerde duik wordt als beoordeeld gemarkeerd. Je kunt ze per duik herstellen in de sectie veiligheidscontrole.';

  @override
  String get safetySettings_dismissAll_confirm => 'Alles negeren';

  @override
  String get safetySettings_dismissAll_cancel => 'Annuleren';

  @override
  String safetySettings_dismissAll_progress(int done, int total) {
    return '$done van $total duiken gecontroleerd';
  }

  @override
  String safetySettings_dismissAll_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observaties genegeerd',
      one: '1 observatie genegeerd',
      zero: 'Geen observaties om te negeren',
    );
    return '$_temp0';
  }

  @override
  String safetySettings_dismissAll_doneWithErrors(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observaties genegeerd',
      one: '1 observatie genegeerd',
      zero: 'Geen observaties genegeerd',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed duiken konden niet worden bijgewerkt',
      one: '1 duik kon niet worden bijgewerkt',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get safetySettings_dismissAll_failed =>
      'Kan de duiklijst niet lezen. Er is niets gewijzigd.';

  @override
  String get safetySettings_analyzeAll_failed =>
      'Kan de duiken niet analyseren.';

  @override
  String get safetyReview_details => 'Details';

  @override
  String get safetyReview_clearHighlight => 'Markering wissen';

  @override
  String safetyReview_findingGroupSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veiligheidsbevindingen',
      one: '1 veiligheidsbevinding',
    );
    return '$_temp0';
  }

  @override
  String get safetySettings_title => 'Veiligheidscontrole';

  @override
  String get safetySettings_entry_subtitle =>
      'Observaties en regels na de duik';

  @override
  String get safetySettings_masterToggle => 'Veiligheidscontrole na de duik';

  @override
  String get safetySettings_masterToggle_subtitle =>
      'Automatisch observaties over opstijging, stops en profiel noteren bij geanalyseerde duiken';

  @override
  String get safetySettings_rulesHeader => 'Regels';

  @override
  String get safetySettings_rule_rapidAscent => 'Snelle opstijgingen';

  @override
  String get safetySettings_rule_missedDecoStop =>
      'Gemiste of ingekorte decostops';

  @override
  String get safetySettings_rule_omittedSafetyStop =>
      'Overgeslagen veiligheidsstops';

  @override
  String get safetySettings_rule_sawtoothProfile => 'Zaagtandprofielen';

  @override
  String get safetySettings_rule_highSurfaceGf =>
      'Hoge gradiëntfactor bij opduiken';

  @override
  String get safetySettings_analyzeAll => 'Alle duiken analyseren';

  @override
  String get safetySettings_analyzeAll_subtitle =>
      'Voer de veiligheidscontrole uit op alle duiken met een profiel die nog niet geanalyseerd zijn';

  @override
  String safetySettings_analyzeAll_progress(int done, int total) {
    return '$done van $total geanalyseerd';
  }

  @override
  String get safetySettings_analyzeAll_done => 'Analyse voltooid';

  @override
  String safetySettings_analyzeAll_doneWithErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken konden niet worden geanalyseerd',
      one: '1 duik kon niet worden geanalyseerd',
    );
    return 'Analyse voltooid — $_temp0';
  }

  @override
  String safetyReview_showDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Toon $count genegeerde',
      one: 'Toon 1 genegeerde',
    );
    return '$_temp0';
  }

  @override
  String get diveDetailSection_sacSegments_name => 'SAC-snelheid per segment';

  @override
  String get diveDetailSection_sacSegments_description =>
      'SAC-segmentatie per fase/tijd';

  @override
  String get diveDetailSection_details_name => 'Details';

  @override
  String get diveDetailSection_details_description =>
      'Type, locatie, reis, duikcentrum, interval';

  @override
  String get diveDetailSection_environment_name => 'Omgeving';

  @override
  String get diveDetailSection_environment_description =>
      'Lucht-/watertemperatuur, zicht, stroming';

  @override
  String get diveDetailSection_altitude_name => 'Hoogte';

  @override
  String get diveDetailSection_altitude_description =>
      'Hoogtelijnen waarde, categorie, deco-vereiste';

  @override
  String get diveDetailSection_tide_name => 'Getij';

  @override
  String get diveDetailSection_tide_description =>
      'Getijdecyclusgrafiek en timing';

  @override
  String get diveDetailSection_reefHealth_name => 'Wateromstandigheden';

  @override
  String get diveDetailSection_reefHealth_description =>
      'Satellietwateromstandigheden op de duikdatum';

  @override
  String get diveDetailSection_surfaceGps_name => 'Oppervlakte-GPS';

  @override
  String get diveDetailSection_surfaceGps_description =>
      'GPS in-/uitstappunten en oppervlaktedrift';

  @override
  String get diveLog_detail_section_surfaceGps => 'Oppervlakte-GPS';

  @override
  String get diveLog_detail_surfaceGps_entry => 'Te water';

  @override
  String get diveLog_detail_surfaceGps_exit => 'Uit het water';

  @override
  String get diveLog_detail_label_drift => 'Drift';

  @override
  String get diveLog_detail_surfaceGps_entryOnly => 'Instappunt geregistreerd';

  @override
  String get diveLog_detail_surfaceGps_exitOnly => 'Uitstappunt geregistreerd';

  @override
  String get diveLog_detail_surfaceGps_site => 'Duikstek';

  @override
  String get diveLog_detail_surfaceGps_track => 'Oppervlaktetrack';

  @override
  String get diveLog_detail_surfaceGps_showFullTrack => 'Volledige track';

  @override
  String diveLog_detail_surfaceGps_trackFixes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punten',
      one: '1 punt',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_detail_locationsMap_title => 'Duiklocaties';

  @override
  String get diveLog_detail_coordinatesCopied =>
      'Coördinaten gekopieerd naar klembord';

  @override
  String get diveLog_detail_openInMaps => 'Openen in Kaarten';

  @override
  String get diveDetailSection_weights_name => 'Gewichten';

  @override
  String get diveDetailSection_weights_description =>
      'Gewichtsoverzicht, totaalgewicht';

  @override
  String get diveDetailSection_buoyancy_name => 'Drijfvermogen';

  @override
  String get diveDetailSection_buoyancy_description =>
      'Drijfvermogen tijdens de duik, variatie, afwerpbaar lood';

  @override
  String get buoyancy_tooltip =>
      'Gemodelleerd netto drijfvermogen tijdens de duik op basis van profiel, gasverbruik en uitrusting.';

  @override
  String buoyancy_verdictBuoyant(String depth, String amount) {
    return 'Bij je laatste stop (~$depth) had je ongeveer $amount opdrijvend vermogen';
  }

  @override
  String buoyancy_verdictHeavy(String depth, String amount) {
    return 'Bij je laatste stop (~$depth) was je ongeveer $amount te zwaar';
  }

  @override
  String get buoyancy_verdictNeutral =>
      'Je configuratie was bijna neutraal bij de laatste stop';

  @override
  String get buoyancy_verdictConvention =>
      'Geschat volgens de 5 m-veiligheidsstopconventie';

  @override
  String get buoyancy_breakdownTitle => 'Termuitsplitsing';

  @override
  String get buoyancy_suitTerm => 'Pak';

  @override
  String get buoyancy_leadTerm => 'Lood';

  @override
  String get buoyancy_beginNet => 'Begin van de duik';

  @override
  String get buoyancy_endNet => 'Einde van de duik';

  @override
  String get buoyancy_swing => 'Drijfvermogenvariatie';

  @override
  String get buoyancy_peakLift => 'Maximaal benodigde lift';

  @override
  String get buoyancy_wingWarning =>
      'Overschrijdt de nominale lift van je wing';

  @override
  String get buoyancy_minDitchable => 'Min. afwerpbaar lood';

  @override
  String get buoyancy_droppable => 'Je kunt afwerpen';

  @override
  String get buoyancy_ditchWarning => 'Meer dan je kunt afwerpen';

  @override
  String get buoyancy_drysuitGas => 'Droogpakgas toegevoegd';

  @override
  String get buoyancy_estimatedPressures => 'Flesdrukken zijn geschat';

  @override
  String get buoyancy_linkSuitHint =>
      'Koppel een duikpak aan deze duik voor een vollediger beeld';

  @override
  String get buoyancy_noLeadHint =>
      'Geen lood vastgelegd: voeg lood toe aan deze duik of een drooggewicht aan je loodmateriaal';

  @override
  String get buoyancy_chartNet => 'Netto';

  @override
  String get buoyancy_chartRig => 'Uitrusting + lood';

  @override
  String get buoyancy_chartMinutes => 'Tijd (min)';

  @override
  String get buoyancy_historyTitle => 'Loodgeschiedenis';

  @override
  String get buoyancy_historyCarried => 'Gedragen';

  @override
  String get buoyancy_historyModeled => 'Gemodelleerd';

  @override
  String buoyancy_historyMore(String delta) {
    return 'Je draagt doorgaans $delta meer dan het model voorstelt';
  }

  @override
  String buoyancy_historyLess(String delta) {
    return 'Je draagt doorgaans $delta minder dan het model voorstelt';
  }

  @override
  String get buoyancy_throughDive => 'Tijdens de duik';

  @override
  String get buoyancy_adjust => 'Aanpassen';

  @override
  String get buoyancy_whatIfTitle => 'Deze duik aanpassen';

  @override
  String get buoyancy_whatIfLead => 'Lood';

  @override
  String get buoyancy_whatIfSuit => 'Pakdrijfvermogen';

  @override
  String get buoyancy_whatIfReset => 'Herstellen';

  @override
  String buoyancy_whatIfDelta(String delta) {
    return '$delta t.o.v. werkelijk';
  }

  @override
  String get diveDetailSection_tanks_name => 'Flessen';

  @override
  String get diveDetailSection_tanks_description =>
      'Flessenlijst, gasmixen, drukken, SAC per fles';

  @override
  String get diveDetailSection_buddies_name => 'Buddy\'s';

  @override
  String get diveDetailSection_buddies_description => 'Buddylijst met rollen';

  @override
  String get diveDetailSection_signatures_name => 'Handtekeningen';

  @override
  String get diveDetailSection_signatures_description =>
      'Weergave en vastlegging van buddy-/instructeurshandtekening';

  @override
  String get diveDetailSection_equipment_name => 'Uitrusting';

  @override
  String get diveDetailSection_equipment_description =>
      'Gebruikte uitrusting bij de duik';

  @override
  String get diveDetailSection_sightings_name => 'Mariene levens waarnemingen';

  @override
  String get diveDetailSection_sightings_description =>
      'Waargenomen soorten, waarnemingsdetails';

  @override
  String get diveDetailSection_media_name => 'Media';

  @override
  String get diveDetailSection_media_description => 'Foto\'s/video\'s galerij';

  @override
  String get diveDetailSection_tags_name => 'Tags';

  @override
  String get diveDetailSection_tags_description => 'Duiktags';

  @override
  String get diveDetailSection_notes_name => 'Notities';

  @override
  String get diveDetailSection_notes_description => 'Duiknotities/omschrijving';

  @override
  String get diveDetailSection_customFields_name => 'Aangepaste velden';

  @override
  String get diveDetailSection_customFields_description =>
      'Gebruikergedefinieerde aangepaste velden';

  @override
  String get diveDetailSection_dataSources_name => 'Databronnen';

  @override
  String get diveDetailSection_dataSources_description =>
      'Verbonden duikcomputers, bronbeheer';

  @override
  String get settings_appearance_header_language => 'Taal';

  @override
  String get settings_appearance_header_theme => 'Thema';

  @override
  String get settings_appearance_header_mode => 'Modus';

  @override
  String get settings_themes_title => 'Thema kiezen';

  @override
  String get settings_themes_current => 'Thema';

  @override
  String get theme_submersion => 'Submersion';

  @override
  String get theme_console => 'Console';

  @override
  String get theme_tropical => 'Tropisch';

  @override
  String get theme_minimalist => 'Minimalistisch';

  @override
  String get theme_deep => 'Diepzee';

  @override
  String get settings_appearance_mapBackgroundDiveCards =>
      'Kaartachtergrond op duikkaarten';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitle =>
      'Toon duikstekkaart als achtergrond op duikkaarten';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote =>
      'Toon duikstekkaart als achtergrond op duikkaarten (vereist steklocatie)';

  @override
  String get settings_appearance_mapBackgroundSiteCards =>
      'Kaartachtergrond op stekkaarten';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitle =>
      'Toon kaart als achtergrond op duikstekkaarten';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote =>
      'Toon kaart als achtergrond op duikstekkaarten (vereist steklocatie)';

  @override
  String get settings_appearance_maxDepthMarker => 'Maximale dieptemarkering';

  @override
  String get settings_appearance_maxDepthMarker_subtitle =>
      'Toon een markering bij het maximale dieptepunt';

  @override
  String get settings_appearance_maxDepthMarker_subtitleFull =>
      'Toon een markering bij het maximale dieptepunt op duikprofielen';

  @override
  String get settings_appearance_metric_ascentRateColors =>
      'Kleuren opstijgsnelheid';

  @override
  String get settings_appearance_metric_ceiling => 'Plafond';

  @override
  String get settings_appearance_metric_events => 'Gebeurtenissen';

  @override
  String get settings_appearance_metric_estimatedTankPressure =>
      'Geschatte flesdruk';

  @override
  String get settings_appearance_metric_gasDensity => 'Gasdichtheid';

  @override
  String get settings_appearance_metric_gfPercent => 'GF%';

  @override
  String get settings_appearance_metric_heartRate => 'Hartslag';

  @override
  String get settings_appearance_metric_meanDepth => 'Gemiddelde diepte';

  @override
  String get settings_appearance_metric_ndl => 'NDL';

  @override
  String get settings_appearance_metric_ppHe => 'ppHe';

  @override
  String get settings_appearance_metric_ppN2 => 'ppN2';

  @override
  String get settings_appearance_metric_ppO2 => 'ppO2';

  @override
  String get settings_appearance_metric_pressure => 'Druk';

  @override
  String get settings_appearance_metric_sacRate => 'SAC-snelheid';

  @override
  String get settings_appearance_metric_surfaceGf => 'Oppervlakte-GF';

  @override
  String get settings_appearance_metric_temperature => 'Temperatuur';

  @override
  String get settings_appearance_metric_tts => 'TTS (Tijd tot oppervlak)';

  @override
  String get settings_appearance_metric_cns => 'CNS% (O2-toxiciteit)';

  @override
  String get settings_appearance_metric_otu => 'OTU (O2-tolerantie-eenheden)';

  @override
  String get settings_appearance_metric_photoMarkers => 'Fotomarkeringen';

  @override
  String settings_appearance_metricsEnabledCount(int count, int total) {
    return '$count van $total ingeschakeld';
  }

  @override
  String get settings_appearance_pressureThresholdMarkers =>
      'Drukdrempelmarkeringen';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Toon markeringen wanneer flesdruk drempels overschrijdt';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Toon markeringen wanneer flesdruk de 2/3, 1/2 en 1/3 drempels overschrijdt';

  @override
  String get settings_appearance_metricsFollowViewport =>
      'Overlays in beeld houden bij zoomen';

  @override
  String get settings_appearance_metricsFollowViewport_subtitle =>
      'Overlays zoals NDL en ppO2 aanpassen aan het zichtbare gebied in plaats van ze mee te vergroten met de diepteas';

  @override
  String get settings_appearance_rightYAxisMetric => 'Metriek rechter Y-as';

  @override
  String get settings_appearance_rightYAxisMetric_subtitle =>
      'Standaardmetriek getoond op de rechter as';

  @override
  String get settings_appearance_subsection_decompressionMetrics =>
      'Decompressiemetrieken';

  @override
  String get settings_appearance_subsection_defaultVisibleMetrics =>
      'Standaard zichtbare metrieken';

  @override
  String get settings_appearance_subsection_standardMetrics =>
      'Standard Metrics';

  @override
  String get settings_appearance_subsection_gasAnalysisMetrics =>
      'Gasanalysemetrieken';

  @override
  String get settings_appearance_subsection_gradientFactorMetrics =>
      'Gradientfactormetrieken';

  @override
  String get settings_appearance_theme_dark => 'Donker';

  @override
  String get settings_appearance_theme_light => 'Licht';

  @override
  String get settings_appearance_theme_system => 'Systeemstandaard';

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
  String get settings_backToSettings_tooltip => 'Terug naar instellingen';

  @override
  String get settings_cloudSync_appBar_title => 'Database-cloudsynchronisatie';

  @override
  String get settings_cloudSync_autoSync => 'Automatische synchronisatie';

  @override
  String get settings_cloudSync_autoSync_subtitle =>
      'Automatisch synchroniseren na wijzigingen';

  @override
  String settings_cloudSync_conflictItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items vereisen aandacht',
      one: '1 item vereist aandacht',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_disabledBanner_content =>
      'App-beheerde cloudsynchronisatie is uitgeschakeld omdat je een aangepaste opslagmap gebruikt. De synchronisatieservice van je map (Dropbox, Google Drive, OneDrive, enz.) verzorgt de synchronisatie.';

  @override
  String get settings_cloudSync_disabledBanner_title =>
      'Cloudsynchronisatie uitgeschakeld';

  @override
  String get settings_cloudSync_entry_subtitle =>
      'Synchroniseren via cloudopslag';

  @override
  String get settings_cloudSync_adopt_confirm =>
      'Herstelde bibliotheek overnemen';

  @override
  String settings_cloudSync_adopt_dialogContent(
    String deviceName,
    String date,
  ) {
    return 'De bibliotheek is vervangen vanuit een back-up op \"$deviceName\" ($date). Bij overname worden de gegevens van dit apparaat vervangen door de herstelde bibliotheek. Eerst wordt een veiligheidsback-up van de huidige gegevens van dit apparaat gemaakt.';
  }

  @override
  String get settings_cloudSync_adopt_dialogTitle =>
      'Herstelde bibliotheek overnemen?';

  @override
  String get settings_cloudSync_adopt_notNow => 'Niet nu';

  @override
  String get settings_cloudSync_dangerZone => 'Gevarenzone';

  @override
  String get settings_cloudSync_replaceLibrary_tile =>
      'Cloudbibliotheek vervangen';

  @override
  String get settings_cloudSync_replaceLibrary_tileSubtitle =>
      'De bibliotheek van dit apparaat de bibliotheek maken die alle apparaten gebruiken';

  @override
  String get settings_cloudSync_replaceLibrary_dialogTitle =>
      'Cloudbibliotheek vervangen?';

  @override
  String get settings_cloudSync_replaceLibrary_dialogIntro =>
      'De bibliotheek van dit apparaat wordt de bibliotheek die alle apparaten gebruiken.';

  @override
  String settings_cloudSync_replaceLibrary_dialogBody(num diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other:
          'De cloudbibliotheek wordt gewist en vervangen door de $diveCount duiken van dit apparaat.',
      one:
          'De cloudbibliotheek wordt gewist en vervangen door de 1 duik van dit apparaat.',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_replaceLibrary_peers(num peerCount) {
    String _temp0 = intl.Intl.pluralLogic(
      peerCount,
      locale: localeName,
      other:
          '$peerCount andere apparaten worden gevraagd deze over te nemen; tot die tijd worden hun wijzigingen niet samengevoegd.',
      one:
          '1 ander apparaat wordt gevraagd deze over te nemen; tot die tijd worden de wijzigingen niet samengevoegd.',
      zero:
          'Er synchroniseert nog geen ander apparaat, dus er is niets over te nemen.',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_replaceLibrary_peersUnknown =>
      'Alle andere apparaten wordt gevraagd deze over te nemen; tot die tijd worden hun wijzigingen niet samengevoegd.';

  @override
  String get settings_cloudSync_replaceLibrary_backupNote =>
      'Er wordt eerst een back-up van dit apparaat gemaakt. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get settings_cloudSync_replaceLibrary_confirmWord => 'Vervangen';

  @override
  String get settings_cloudSync_replaceLibrary_confirmHint =>
      'Typ \"Vervangen\" om te bevestigen';

  @override
  String get settings_cloudSync_replaceLibrary_confirm => 'Vervangen';

  @override
  String get settings_cloudSync_firstSync_banner =>
      'De eerste synchronisatie wacht op bevestiging. Tik op \'Nu synchroniseren\' om te bekijken wat er wordt samengevoegd.';

  @override
  String get settings_cloudSync_firstSync_dialogConfirm =>
      'Samenvoegen en synchroniseren';

  @override
  String get settings_cloudSync_firstSync_replaceHint =>
      'Als de bibliotheek van dit apparaat juist moet vervangen wat in de cloud staat, annuleer dan en gebruik Instellingen > Cloudsynchronisatie > Cloudbibliotheek vervangen.';

  @override
  String settings_cloudSync_firstSync_dialogContent(
    int deviceCount,
    int diveCount,
  ) {
    return 'Er zijn bestaande synchronisatiegegevens gevonden in de cloud ($deviceCount synchronisatiebestand(en)). Je eerste synchronisatie voegt die gegevens samen met de $diveCount duik(en) op dit apparaat, op alle gesynchroniseerde apparaten.\n\nAls dezelfde duiken op elk apparaat afzonderlijk zijn toegevoegd, verschijnen ze dubbel.';
  }

  @override
  String get settings_cloudSync_firstSync_dialogTitle =>
      'Bibliotheken samenvoegen?';

  @override
  String settings_cloudSync_replace_banner(String deviceName) {
    return 'Synchronisatie gepauzeerd: de bibliotheek is vervangen vanuit een back-up op \"$deviceName\". Tik op Nu synchroniseren om te controleren.';
  }

  @override
  String get settings_cloudSync_switch_dialogTitle =>
      'Synchronisatieprovider wijzigen?';

  @override
  String settings_cloudSync_switch_dialogContent(
    String fromName,
    String toName,
  ) {
    return 'Je gegevens worden niet van $fromName verplaatst — ze blijven daar staan totdat je ze verwijdert. Na het wijzigen voegt de volgende synchronisatie van dit apparaat zijn gegevens samen met wat er al op $toName staat. Je andere apparaten blijven $fromName gebruiken totdat je ze ook elk wijzigt.';
  }

  @override
  String get settings_cloudSync_switch_confirm => 'Wijzigen';

  @override
  String settings_cloudSync_moved_banner(
    String deviceName,
    String destination,
  ) {
    return '$deviceName heeft deze bibliotheek naar $destination verplaatst. Deze provider wordt er niet langer door bijgewerkt. Selecteer $destination hieronder om de verplaatsing te volgen.';
  }

  @override
  String get settings_cloudSync_moved_dismiss => 'Sluiten';

  @override
  String settings_cloudSync_cleanup_banner(String backend) {
    return 'Er staan nog oude synchronisatiegegevens op $backend van voordat je van provider wisselde. Ze worden niet meer gebruikt.';
  }

  @override
  String get settings_cloudSync_cleanup_delete => 'Oude gegevens verwijderen';

  @override
  String get settings_cloudSync_cleanup_keep => 'Behouden';

  @override
  String get settings_cloudSync_header_advanced => 'Geavanceerd';

  @override
  String get settings_cloudSync_signOut_backupWarning =>
      'Cloudback-up wordt uitgeschakeld en back-ups worden op de standaardlocatie opgeslagen.';

  @override
  String get settings_cloudSync_header_cloudProvider => 'Cloudprovider';

  @override
  String settings_cloudSync_header_conflicts(Object count) {
    return 'Conflicten ($count)';
  }

  @override
  String get settings_cloudSync_header_syncBehavior => 'Synchronisatiegedrag';

  @override
  String settings_cloudSync_lastSynced(Object time) {
    return 'Laatst gesynchroniseerd: $time';
  }

  @override
  String settings_cloudSync_pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wachtende wijzigingen',
      one: '1 wachtende wijziging',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_banner(Object deviceList) {
    return '$deviceList heeft nog een oudere of onbekende bibliotheekversie, dus de wijzigingen zijn niet samengevoegd. Open Submersion daar om de huidige bibliotheek over te nemen.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_bannerPlural(Object deviceList) {
    return '$deviceList hebben nog een oudere of onbekende bibliotheekversie, dus hun wijzigingen zijn niet samengevoegd. Open Submersion daar om de huidige bibliotheek over te nemen.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_unnamedDevice(Object shortId) {
    return 'apparaat $shortId';
  }

  @override
  String get settings_cloudSync_peerNeedsAdopt_listSeparator => ', ';

  @override
  String get settings_cloudSync_peerNeedsAdopt_listLastSeparator => ' en ';

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamed(Object deviceList) {
    return '$deviceList synchroniseert vanaf een nieuwere versie van Submersion, dus de nieuwste wijzigingen worden voorlopig vastgehouden.';
  }

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(
    Object deviceList,
  ) {
    return '$deviceList synchroniseren vanaf een nieuwere versie van Submersion, dus hun nieuwste wijzigingen worden voorlopig vastgehouden.';
  }

  @override
  String get settings_cloudSync_peerRequiresUpdate_updateAction =>
      'Werk dit apparaat bij om ze te ontvangen.';

  @override
  String get settings_cloudSync_peerRequiresUpdate_storeAction =>
      'Ze worden automatisch toegepast zodra de appstore-update voor dit apparaat beschikbaar is; de update is mogelijk nog in beoordeling.';

  @override
  String get settings_cloudSync_provider_connected => 'Verbonden';

  @override
  String settings_cloudSync_provider_connectedTo(Object providerName) {
    return 'Verbonden met $providerName';
  }

  @override
  String settings_cloudSync_provider_connectionFailed(
    Object providerName,
    Object error,
  ) {
    return 'Verbinding met $providerName mislukt: $error';
  }

  @override
  String get settings_cloudSync_dropbox_account_title => 'Dropbox-account';

  @override
  String get settings_cloudSync_dropbox_connect_browserFailed =>
      'Kan de browser niet openen. Probeer de knop Browser opnieuw openen.';

  @override
  String get settings_cloudSync_dropbox_connect_codeLabel => 'Autorisatiecode';

  @override
  String get settings_cloudSync_dropbox_connect_emptyCode =>
      'Voer de autorisatiecode in die in je browser wordt weergegeven';

  @override
  String settings_cloudSync_dropbox_connect_failed(Object error) {
    return 'Kan geen verbinding maken met Dropbox: $error';
  }

  @override
  String get settings_cloudSync_dropbox_connect_instructions =>
      'Je browser heeft een Dropbox-autorisatiepagina geopend. Keur de toegang goed en plak daarna hier de code die Dropbox toont.';

  @override
  String get settings_cloudSync_dropbox_connect_reopenBrowser =>
      'Browser opnieuw openen';

  @override
  String get settings_cloudSync_dropbox_connect_submit => 'Verbinden';

  @override
  String get settings_cloudSync_dropbox_connect_title => 'Dropbox verbinden';

  @override
  String get settings_cloudSync_dropbox_connected => 'Verbonden met Dropbox';

  @override
  String settings_cloudSync_dropbox_connectedAs(Object account) {
    return 'Verbonden als $account';
  }

  @override
  String get settings_cloudSync_dropbox_disconnect => 'Verbinding verbreken';

  @override
  String get settings_cloudSync_provider_dropbox_subtitle =>
      'Synchroniseren via Dropbox (Apps/Submersion)';

  @override
  String get settings_cloudSync_provider_dropbox_title => 'Dropbox';

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Synchroniseren via Google Drive';

  @override
  String get settings_cloudSync_googleDrive_desktopNotConfigured =>
      'Niet beschikbaar in deze build';

  @override
  String get settings_cloudSync_googleDrive_browserWait_title =>
      'Ga verder in je browser';

  @override
  String get settings_cloudSync_googleDrive_browserWait_message =>
      'Rond het inloggen bij Google af in je webbrowser en keer dan terug naar Submersion.';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Initialisatie van $providerName-provider mislukt';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Niet beschikbaar op dit platform';

  @override
  String get settings_cloudSync_provider_s3_edit => 'S3-configuratie bewerken';

  @override
  String get settings_cloudSync_provider_s3_subtitle =>
      'Werkt met elke S3-compatibele opslagdienst';

  @override
  String get settings_cloudSync_provider_s3_title => 'S3-compatibele opslag';

  @override
  String get settings_cloudSync_resetDialog_cancel => 'Annuleren';

  @override
  String get settings_cloudSync_resetDialog_content =>
      'Dit wist alle synchronisatiegeschiedenis en start opnieuw. Je gegevens worden niet verwijderd, maar mogelijk moet je conflicten oplossen bij de volgende synchronisatie.';

  @override
  String get settings_cloudSync_resetDialog_reset => 'Herstellen';

  @override
  String get settings_cloudSync_resetDialog_title =>
      'Synchronisatiestatus herstellen?';

  @override
  String get settings_cloudSync_resetSuccess => 'Synchronisatiestatus hersteld';

  @override
  String get settings_cloudSync_resetSyncState =>
      'Synchronisatiestatus herstellen';

  @override
  String get settings_cloudSync_resetSyncState_subtitle =>
      'Synchronisatiegeschiedenis wissen en opnieuw beginnen';

  @override
  String get settings_cloudSync_resolveConflicts => 'Conflicten oplossen';

  @override
  String get settings_cloudSync_selectProviderHint =>
      'Selecteer een cloudprovider om synchronisatie in te schakelen';

  @override
  String get settings_cloudSync_signOut => 'Uitloggen';

  @override
  String get settings_cloudSync_signOutDialog_cancel => 'Annuleren';

  @override
  String get settings_cloudSync_signOutDialog_content =>
      'Dit verbreekt de verbinding met de cloudprovider. Je lokale gegevens blijven intact.';

  @override
  String get settings_cloudSync_signOutDialog_signOut => 'Uitloggen';

  @override
  String get settings_cloudSync_signOutDialog_title => 'Uitloggen?';

  @override
  String get settings_cloudSync_signOutSuccess => 'Uitgelogd bij cloudprovider';

  @override
  String get settings_cloudSync_signOut_subtitle =>
      'Verbinding met cloudprovider verbreken';

  @override
  String get settings_cloudSync_status_conflictsDetected =>
      'Conflicten gedetecteerd';

  @override
  String get settings_cloudSync_status_readyToSync =>
      'Klaar om te synchroniseren';

  @override
  String get settings_cloudSync_status_syncComplete =>
      'Synchronisatie voltooid';

  @override
  String get settings_cloudSync_status_syncError => 'Synchronisatiefout';

  @override
  String get settings_cloudSync_status_syncing => 'Synchroniseren...';

  @override
  String get settings_cloudSync_storageSettings => 'Opslaginstellingen';

  @override
  String get settings_cloudSync_syncNow => 'Nu synchroniseren';

  @override
  String get settings_cloudSync_syncOnLaunch => 'Synchroniseren bij opstarten';

  @override
  String get settings_cloudSync_syncOnLaunch_subtitle =>
      'Controleren op updates bij het opstarten';

  @override
  String get settings_cloudSync_syncOnResume => 'Synchroniseren bij hervatten';

  @override
  String get settings_cloudSync_syncOnResume_subtitle =>
      'Controleren op updates wanneer de app actief wordt';

  @override
  String settings_cloudSync_syncProgressPercent(Object percent) {
    return 'Synchronisatievoortgang: $percent procent';
  }

  @override
  String settings_cloudSync_time_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagen geleden',
      one: '1 dag geleden',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_time_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uur geleden',
      one: '1 uur geleden',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_time_justNow => 'Zojuist';

  @override
  String settings_cloudSync_time_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuten geleden',
      one: '1 minuut geleden',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_applyAll => 'Alles toepassen';

  @override
  String get settings_conflict_cancel => 'Annuleren';

  @override
  String get settings_conflict_chooseResolution => 'Kies oplossing';

  @override
  String get settings_conflict_close => 'Sluiten';

  @override
  String get settings_conflict_close_tooltip => 'Conflictdialoog sluiten';

  @override
  String settings_conflict_counterLabel(Object current, Object total) {
    return 'Conflict $current van $total';
  }

  @override
  String settings_conflict_errorLoading(Object error) {
    return 'Fout bij laden van conflicten: $error';
  }

  @override
  String get settings_conflict_keepBoth => 'Beide bewaren';

  @override
  String get settings_conflict_keepLocal => 'Lokale bewaren';

  @override
  String get settings_conflict_keepRemote => 'Externe bewaren';

  @override
  String get settings_conflict_localVersion => 'Lokale versie';

  @override
  String settings_conflict_modified(Object time) {
    return 'Gewijzigd: $time';
  }

  @override
  String get settings_conflict_next_tooltip => 'Volgend conflict';

  @override
  String get settings_conflict_noConflicts_message =>
      'Alle synchronisatieconflicten zijn opgelost.';

  @override
  String get settings_conflict_noConflicts_title => 'Geen conflicten';

  @override
  String get settings_conflict_noDataAvailable => 'Geen gegevens beschikbaar';

  @override
  String get settings_conflict_previous_tooltip => 'Vorig conflict';

  @override
  String get settings_conflict_ref_buddy => 'Buddy';

  @override
  String get settings_conflict_ref_certification => 'Certificering';

  @override
  String get settings_conflict_ref_checklistTemplate => 'Checklistsjabloon';

  @override
  String get settings_conflict_ref_connectedAccount => 'Gekoppeld account';

  @override
  String get settings_conflict_ref_course => 'Cursus';

  @override
  String get settings_conflict_ref_courseRequirement => 'Cursusvereiste';

  @override
  String get settings_conflict_ref_cylinderConfig => 'Flesconfiguratie';

  @override
  String get settings_conflict_ref_dataSource => 'Gegevensbron';

  @override
  String get settings_conflict_ref_dive => 'Duik';

  @override
  String get settings_conflict_ref_diveCenter => 'Duikcentrum';

  @override
  String get settings_conflict_ref_diveComputer => 'Duikcomputer';

  @override
  String get settings_conflict_ref_divePlan => 'Duikplan';

  @override
  String get settings_conflict_ref_diveSite => 'Duikstek';

  @override
  String get settings_conflict_ref_diveType => 'Duiktype';

  @override
  String get settings_conflict_ref_diver => 'Duiker';

  @override
  String get settings_conflict_ref_equipment => 'Uitrusting';

  @override
  String get settings_conflict_ref_equipmentSet => 'Uitrustingsset';

  @override
  String get settings_conflict_ref_finding => 'Bevinding';

  @override
  String get settings_conflict_ref_instructor => 'Instructeur';

  @override
  String get settings_conflict_ref_linkedDive => 'Gekoppelde duik';

  @override
  String get settings_conflict_ref_media => 'Media';

  @override
  String get settings_conflict_ref_mediaSubscription => 'Media-abonnement';

  @override
  String get settings_conflict_ref_missing => 'Niet meer in deze bibliotheek';

  @override
  String settings_conflict_ref_named(Object name, Object date) {
    return '$name ($date)';
  }

  @override
  String get settings_conflict_ref_plannedTank => 'Geplande fles';

  @override
  String get settings_conflict_ref_preDiveChecklistTemplate =>
      'Sjabloon voor checklist voor de duik';

  @override
  String get settings_conflict_ref_preDiveSession => 'Checklist voor de duik';

  @override
  String get settings_conflict_ref_relatedDive => 'Gerelateerde duik';

  @override
  String get settings_conflict_ref_serviceKind => 'Onderhoudstype';

  @override
  String get settings_conflict_ref_sighting => 'Waarneming';

  @override
  String get settings_conflict_ref_signer => 'Ondertekend door';

  @override
  String get settings_conflict_ref_sourceDive => 'Bronduik';

  @override
  String get settings_conflict_ref_species => 'Soorten';

  @override
  String get settings_conflict_ref_tag => 'Tag';

  @override
  String get settings_conflict_ref_tank => 'Fles';

  @override
  String get settings_conflict_ref_trip => 'Reis';

  @override
  String get settings_conflict_remoteVersion => 'Externe versie';

  @override
  String settings_conflict_resolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conflicten',
      one: '1 conflict',
    );
    return '$_temp0 opgelost';
  }

  @override
  String get settings_conflict_title => 'Conflicten oplossen';

  @override
  String get settings_data_appDefaultLocation => 'Standaard app-locatie';

  @override
  String get settings_data_backup => 'Back-up en herstel';

  @override
  String get settings_data_backup_subtitle =>
      'Maak een back-up van je gegevens';

  @override
  String get settings_data_cloudSync => 'Database-cloudsynchronisatie';

  @override
  String get settings_data_customFolder => 'Aangepaste map';

  @override
  String get settings_data_databaseStorage => 'Database-opslag';

  @override
  String get settings_data_export_completed => 'Export voltooid';

  @override
  String get settings_data_export_exporting => 'Exporteren...';

  @override
  String settings_data_export_failed(Object error) {
    return 'Export mislukt: $error';
  }

  @override
  String get settings_data_header_backupSync => 'Back-up & synchronisatie';

  @override
  String get settings_data_header_storage => 'Opslag';

  @override
  String get settings_data_import_completed => 'Bewerking voltooid';

  @override
  String settings_data_import_failed(Object error) {
    return 'Bewerking mislukt: $error';
  }

  @override
  String get settings_data_offlineMaps => 'Offline kaarten';

  @override
  String get settings_data_offlineMaps_subtitle =>
      'Download kaarten voor offline gebruik';

  @override
  String get settings_data_restore => 'Herstellen';

  @override
  String get settings_data_restoreDialog_cancel => 'Annuleren';

  @override
  String get settings_data_restoreDialog_content =>
      'Waarschuwing: Herstellen vanuit een back-up vervangt ALLE huidige gegevens door de back-upgegevens. Deze actie kan niet ongedaan worden gemaakt.\n\nWeet je zeker dat je wilt doorgaan?';

  @override
  String get settings_data_restoreDialog_restore => 'Herstellen';

  @override
  String get settings_data_restoreDialog_title => 'Back-up herstellen';

  @override
  String get settings_data_restore_subtitle => 'Herstellen vanuit back-up';

  @override
  String settings_data_syncTime_daysAgo(Object count) {
    return '${count}d geleden';
  }

  @override
  String settings_data_syncTime_hoursAgo(Object count) {
    return '${count}u geleden';
  }

  @override
  String get settings_data_syncTime_justNow => 'Zojuist';

  @override
  String settings_data_syncTime_minutesAgo(Object count) {
    return '${count}m geleden';
  }

  @override
  String settings_data_sync_lastSynced(Object time) {
    return 'Laatst gesynchroniseerd: $time';
  }

  @override
  String get settings_data_sync_notConfigured => 'Niet geconfigureerd';

  @override
  String get settings_data_sync_syncing => 'Synchroniseren...';

  @override
  String get settings_decompression_aboutContent =>
      'Gradientfactoren (GF) bepalen hoe conservatief je decompressieberekeningen zijn. GF Low beinvloedt diepe stops, terwijl GF High ondiepe stops beinvloedt.\n\nLagere waarden = conservatiever = langere decostops\nHogere waarden = minder conservatief = kortere decostops';

  @override
  String get settings_decompression_aboutTitle => 'Over gradientfactoren';

  @override
  String get settings_decompression_currentSettings => 'Huidige instellingen';

  @override
  String get settings_decompression_dialog_cancel => 'Annuleren';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      'Lagere waarden = conservatiever (langere NDL/meer deco)';

  @override
  String get settings_decompression_dialog_customValues => 'Aangepaste waarden';

  @override
  String get settings_decompression_dialog_gfHigh => 'GF High';

  @override
  String get settings_decompression_dialog_gfLow => 'GF Low';

  @override
  String get settings_decompression_dialog_info =>
      'GF Low/High bepalen hoe conservatief je NDL- en decoberekeningen zijn.';

  @override
  String get settings_decompression_dialog_presets => 'Voorinstellingen';

  @override
  String get settings_decompression_dialog_save => 'Opslaan';

  @override
  String get settings_decompression_dialog_title => 'Gradientfactoren';

  @override
  String settings_decompression_gfValue(Object gfLow, Object gfHigh) {
    return 'GF $gfLow/$gfHigh';
  }

  @override
  String get settings_decompression_header_gradientFactors =>
      'Gradientfactoren';

  @override
  String get settings_decompression_header_oxygenToxicity =>
      'Zuurstoftoxiciteit';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Selecteer $presetName conservatismevoorinstelling';
  }

  @override
  String get settings_decompression_header_narcosis => 'Narcose';

  @override
  String get settings_decompression_o2Narcotic => 'O2 is narcotisch';

  @override
  String get settings_decompression_o2Narcotic_subtitle =>
      'Wanneer ingeschakeld, worden zowel O2 als N2 als narcotisch beschouwd (conservatiever). Wanneer uitgeschakeld, draagt alleen N2 bij aan narcose.';

  @override
  String get settings_decompression_endLimit => 'END-limiet';

  @override
  String get settings_decompression_endLimit_subtitle =>
      'Maximale equivalente narcotische diepte voor MND-berekeningen';

  @override
  String get settings_decompression_endLimit_dialog_title => 'END-limiet';

  @override
  String get settings_decompression_cnsMethodTitle => 'CNS-berekening';

  @override
  String get settings_decompression_cnsMethodClassic =>
      'NOAA-tabel, getrapt (klassiek)';

  @override
  String get settings_decompression_cnsMethodClassicDesc =>
      'Rekent elke band van 0,1 bar af op de strengere rand. Oorspronkelijke methode van Submersion.';

  @override
  String get settings_decompression_cnsMethodShearwater =>
      'Lineaire interpolatie (Shearwater-stijl)';

  @override
  String get settings_decompression_cnsMethodShearwaterDesc =>
      'Interpoleert lineair tussen de NOAA-grenzen zoals gedocumenteerd door Shearwater. Komt overeen met de meeste duikcomputers.';

  @override
  String get settings_decompression_cnsMethodSubsurface =>
      'Exponentiële fit (zoals Subsurface)';

  @override
  String get settings_decompression_cnsMethodSubsurfaceDesc =>
      'Vloeiende curvefit op de NOAA-tabel. Komt overeen met de door Subsurface berekende CNS.';

  @override
  String get settings_decompression_cnsMethodAboutTitle => 'Over deze methoden';

  @override
  String get settings_decompression_cnsMethodAboutBody =>
      'Alle drie de methoden zijn gebaseerd op de zuurstofblootstellingslimieten van het NOAA Diving Manual (300 minuten bij een ppO2 van 1,0 bar, 45 minuten bij 1,6 bar). De tabel definieert grenzen alleen in stappen van 0,1 bar: de klassieke methode rekent alles binnen een band af op de strengere rand van die band, waardoor de blootstelling tussen de waarden systematisch wordt overschat. De duikcomputers van Shearwater documenteren een lineaire interpolatie tussen de NOAA-grenzen, met een vaste 15% per minuut boven 1,65 bar. Subsurface verving in 2019 zijn tabelopzoeking door een vloeiende exponentiële fit in twee delen op dezelfde NOAA-gegevens (Robert C. Helling), die ook op natuurlijke wijze verder reikt dan 1,6 bar. Tussen de tabelwaarden komen de twee vloeiende methoden overeen tot op ongeveer één CNS-punt; de klassieke methode geeft hogere waarden.';

  @override
  String get settings_decompression_cnsMethodDisclaimer =>
      'De namen verwijzen naar de gepubliceerde methoden van de respectievelijke projecten en fabrikanten; er wordt geen band of goedkeuring gesuggereerd. Berekende waarden kunnen afwijken van de werkelijke aflezingen van de duikcomputer.';

  @override
  String get settings_decompression_cnsMethodSourcesTitle => 'Bronnen';

  @override
  String get settings_linkOpenFailed => 'De link kon niet worden geopend.';

  @override
  String get settings_decompression_cnsMethodSourceNoaa =>
      'NOAA: Diving Program (uitgever van het NOAA Diving Manual)';

  @override
  String get settings_decompression_cnsMethodSourceShearwater =>
      'Shearwater: de CNS-zuurstofklok';

  @override
  String get settings_decompression_cnsMethodSourceTheoreticalDiver =>
      'The Theoretical Diver: berekening van CNS-zuurstoftoxiciteit';

  @override
  String get settings_decompression_cnsMethodSourceSubsurface =>
      'Subsurface: implementatie (divelist.cpp)';

  @override
  String get settings_existingDb_cancel => 'Annuleren';

  @override
  String get settings_existingDb_continue => 'Doorgaan';

  @override
  String get settings_existingDb_current => 'Huidig';

  @override
  String get settings_existingDb_dialog_message =>
      'Er bestaat al een Submersion-database in deze map.';

  @override
  String get settings_existingDb_dialog_title => 'Bestaande database gevonden';

  @override
  String get settings_existingDb_existing => 'Bestaand';

  @override
  String get settings_existingDb_replaceWarning =>
      'Van de bestaande database wordt een back-up gemaakt voordat deze wordt vervangen.';

  @override
  String get settings_existingDb_replaceWithMyData =>
      'Vervangen door mijn gegevens';

  @override
  String get settings_existingDb_replaceWithMyData_subtitle =>
      'Overschrijven met je huidige database';

  @override
  String get settings_existingDb_stat_buddies => 'Buddy\'s';

  @override
  String get settings_existingDb_stat_dives => 'Duiken';

  @override
  String get settings_existingDb_stat_sites => 'Duikstekken';

  @override
  String get settings_existingDb_stat_trips => 'Reizen';

  @override
  String get settings_existingDb_stat_users => 'Gebruikers';

  @override
  String get settings_existingDb_unknown => 'Onbekend';

  @override
  String get settings_existingDb_useExisting => 'Bestaande database gebruiken';

  @override
  String get settings_existingDb_useExisting_subtitle =>
      'Overschakelen naar de database in deze map';

  @override
  String get settings_gfPreset_custom_description => 'Stel je eigen waarden in';

  @override
  String get settings_gfPreset_custom_name => 'Aangepast';

  @override
  String get settings_gfPreset_high_description =>
      'Meest conservatief, langere decostops';

  @override
  String get settings_gfPreset_high_name => 'Hoog';

  @override
  String get settings_gfPreset_low_description =>
      'Minst conservatief, kortere deco';

  @override
  String get settings_gfPreset_low_name => 'Laag';

  @override
  String get settings_gfPreset_medium_description => 'Gebalanceerde aanpak';

  @override
  String get settings_gfPreset_medium_name => 'Middel';

  @override
  String get settings_import_cancelButton => 'Import annuleren';

  @override
  String get settings_import_cancelling => 'Bezig met annuleren...';

  @override
  String get settings_import_dialog_title => 'Gegevens importeren';

  @override
  String get settings_import_doNotClose => 'Sluit de app niet';

  @override
  String settings_import_itemCount(Object current, Object total) {
    return '$current van $total';
  }

  @override
  String get settings_import_phase_buddies => 'Buddy\'s importeren...';

  @override
  String get settings_import_phase_certifications =>
      'Certificeringen importeren...';

  @override
  String get settings_import_phase_complete => 'Afronden...';

  @override
  String get settings_import_phase_diveCenters => 'Duikcentra importeren...';

  @override
  String get settings_import_phase_diveTypes => 'Duiktypes importeren...';

  @override
  String get settings_import_phase_dives => 'Duiken importeren...';

  @override
  String get settings_import_phase_equipment => 'Uitrusting importeren...';

  @override
  String get settings_import_phase_equipmentSets =>
      'Uitrustingssets importeren...';

  @override
  String get settings_import_phase_parsing => 'Bestand verwerken...';

  @override
  String get settings_import_phase_preparing => 'Voorbereiden...';

  @override
  String get settings_import_phase_sites => 'Duikstekken importeren...';

  @override
  String get settings_import_phase_tags => 'Labels importeren...';

  @override
  String get settings_import_phase_trips => 'Reizen importeren...';

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
    return '$phase, $current van $total';
  }

  @override
  String settings_import_progressPercent(Object percent) {
    return 'Importvoortgang: $percent procent';
  }

  @override
  String get settings_language_appBar_title => 'Taal';

  @override
  String get settings_language_selected => 'Geselecteerd';

  @override
  String get settings_language_systemDefault => 'Systeemstandaard';

  @override
  String get settings_lightroom_albumFilter_all => 'Volledige catalogus';

  @override
  String get settings_lightroom_albumFilter_title => 'Te scannen albums';

  @override
  String get settings_lightroom_autoPoll_title =>
      'Automatisch controleren op nieuwe foto\'s';

  @override
  String settings_lightroom_clientId_help(String redirectUri) {
    return 'Maak in de Adobe Developer Console een integratie met de Lightroom Services API en een referentietype dat PKCE ondersteunt. Voer hieronder de redirect-URI van je referentie in — Native App-referenties gebruiken een aangepast schema — of laat het leeg om $redirectUri te gebruiken.';
  }

  @override
  String get settings_lightroom_clientId_label => 'Adobe client-ID';

  @override
  String get settings_lightroom_clientSecret_label =>
      'Client secret (optioneel)';

  @override
  String get settings_lightroom_redirectUri_label => 'Redirect-URI (optioneel)';

  @override
  String get settings_lightroom_connect => 'Lightroom koppelen';

  @override
  String get settings_lightroom_connectEmbedded => 'Verbinden met Adobe';

  @override
  String get settings_lightroom_advancedByo =>
      'Je eigen Adobe-inloggegevens gebruiken';

  @override
  String get settings_lightroom_connect_codeLabel =>
      'Doorgestuurde URL of code';

  @override
  String get settings_lightroom_connect_emptyCode =>
      'Plak de doorgestuurde URL of autorisatiecode';

  @override
  String settings_lightroom_connect_failed(String error) {
    return 'Kan geen verbinding maken met Lightroom: $error';
  }

  @override
  String get settings_lightroom_connect_instructions =>
      'Meld je aan bij Adobe in het browservenster en plak vervolgens het volledige adres van de pagina waarop je terechtkomt (dit bevat de autorisatiecode).';

  @override
  String get settings_lightroom_connect_reopenBrowser =>
      'Browser opnieuw openen';

  @override
  String get settings_lightroom_connect_submit => 'Koppelen';

  @override
  String get settings_lightroom_connect_title => 'Lightroom koppelen';

  @override
  String settings_lightroom_connected(String name) {
    return 'Gekoppeld als $name';
  }

  @override
  String get settings_lightroom_disconnect => 'Ontkoppelen';

  @override
  String get settings_lightroom_disconnect_confirmBody =>
      'Gekoppelde foto\'s blijven bij je duiken en worden nog steeds weergegeven vanuit de mediaopslag. Nieuwe foto\'s worden niet meer gekoppeld.';

  @override
  String get settings_lightroom_disconnect_confirmTitle =>
      'Lightroom ontkoppelen?';

  @override
  String settings_lightroom_lastPoll(String when) {
    return 'Laatst gecontroleerd: $when';
  }

  @override
  String get settings_lightroom_needsReauth => 'Opnieuw verbinden vereist';

  @override
  String get settings_lightroom_scanNow => 'Lightroom scannen';

  @override
  String get settings_lightroom_scan_running => 'Lightroom wordt gescand...';

  @override
  String settings_lightroom_scan_summary(
    int attached,
    int suggested,
    int skipped,
  ) {
    return '$attached gekoppeld, $suggested voorgesteld, $skipped al gekoppeld';
  }

  @override
  String get settings_lightroom_subtitle =>
      'Foto\'s en video\'s automatisch aan duiken koppelen';

  @override
  String get settings_lightroom_title => 'Adobe Lightroom';

  @override
  String get settings_manage_checklistTemplates => 'Checklistsjablonen';

  @override
  String get settings_manage_checklistTemplates_subtitle =>
      'Herbruikbare takenlijsten voor reisplanning';

  @override
  String get settings_manage_diveRoles => 'Duikrollen';

  @override
  String get settings_manage_diveRoles_subtitle =>
      'Aangepaste duikrollen beheren';

  @override
  String get settings_manage_diveTypes => 'Duiktypes';

  @override
  String get settings_manage_diveTypes_subtitle =>
      'Aangepaste duiktypes beheren';

  @override
  String get settings_manage_header_manageData => 'Gegevens beheren';

  @override
  String get settings_manage_species => 'Soorten';

  @override
  String get settings_manage_species_subtitle =>
      'Zeelevensoortencatalogus beheren';

  @override
  String get settings_manage_tags => 'Tags';

  @override
  String get settings_manage_tags_subtitle =>
      'Tags beheren, samenvoegen en verwijderen';

  @override
  String get settings_manage_tankPresets => 'Flesvoorinstellingen';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Aangepaste flesconfiguraties beheren';

  @override
  String get settings_manage_serviceTypes => 'Servicetypes';

  @override
  String get settings_manage_serviceTypes_subtitle =>
      'Welk onderhoud je uitrusting nodig heeft, en hoe vaak';

  @override
  String get settings_migrationProgress_doNotClose => 'Sluit de app niet';

  @override
  String get settings_migration_backupInfo =>
      'Er wordt een back-up gemaakt voor de verplaatsing. Je gegevens gaan niet verloren.';

  @override
  String get settings_migration_cancel => 'Annuleren';

  @override
  String get settings_migration_cloudSyncWarning =>
      'App-beheerde cloudsynchronisatie wordt uitgeschakeld. De synchronisatieservice van je map verzorgt de synchronisatie.';

  @override
  String get settings_migration_dialog_message =>
      'Je database wordt verplaatst:';

  @override
  String get settings_migration_dialog_title => 'Database verplaatsen?';

  @override
  String get settings_migration_from => 'Van';

  @override
  String get settings_migration_moveDatabase => 'Database verplaatsen';

  @override
  String get settings_migration_to => 'Naar';

  @override
  String settings_notifications_days(Object count) {
    return '$count dagen';
  }

  @override
  String get settings_notifications_disabled_continueButton => 'Doorgaan';

  @override
  String get settings_notifications_disabled_openSettingsButton =>
      'Instellingen openen';

  @override
  String get settings_notifications_disabled_subtitleUnrequested =>
      'Serviceherinneringen hebben toestemming nodig om meldingen te sturen';

  @override
  String get settings_notifications_disabled_subtitle =>
      'Schakel in via systeeminstellingen om herinneringen te ontvangen';

  @override
  String get settings_notifications_disabled_title => 'Meldingen uitgeschakeld';

  @override
  String get settings_notifications_enableServiceReminders =>
      'Onderhoudsherinneringen inschakelen';

  @override
  String get settings_notifications_enableServiceReminders_subtitle =>
      'Ontvang een melding wanneer onderhoud aan uitrusting nodig is';

  @override
  String get settings_notifications_header_reminderSchedule =>
      'Herinneringsschema';

  @override
  String get settings_notifications_header_serviceReminders =>
      'Onderhoudsherinneringen';

  @override
  String get settings_notifications_howItWorks_content =>
      'Meldingen worden ingepland wanneer de app opstart en worden periodiek op de achtergrond vernieuwd. Je kunt herinneringen voor individuele uitrustingsitems aanpassen in hun bewerkingsscherm.';

  @override
  String get settings_notifications_howItWorks_title => 'Hoe het werkt';

  @override
  String get settings_notifications_permissionRequired =>
      'Schakel meldingen in via systeeminstellingen';

  @override
  String get settings_notifications_remindBeforeDue =>
      'Herinner mij voordat onderhoud nodig is:';

  @override
  String get settings_notifications_reminderTime => 'Herinneringstijd';

  @override
  String get settings_profile_activeDiver_subtitle =>
      'Actieve duiker - tik om te wisselen';

  @override
  String get settings_profile_addNewDiver => 'Nieuwe duiker toevoegen';

  @override
  String get settings_profile_error_loadingDiver => 'Fout bij laden van duiker';

  @override
  String get settings_profile_header_activeDiver => 'Actieve duiker';

  @override
  String get settings_profile_header_manageDivers => 'Duikers beheren';

  @override
  String get settings_profile_noDiverProfile => 'Geen duikersprofiel';

  @override
  String get settings_profile_noDiverProfile_subtitle =>
      'Tik om je profiel aan te maken';

  @override
  String get settings_profile_switchDiver_title => 'Duiker wisselen';

  @override
  String settings_profile_switchedTo(Object diverName) {
    return 'Overgeschakeld naar $diverName';
  }

  @override
  String get settings_profile_viewAllDivers => 'Alle duikers bekijken';

  @override
  String get settings_profile_viewAllDivers_subtitle =>
      'Duikersprofielen toevoegen of bewerken';

  @override
  String get settings_profileHub_addNewDiver => 'Nieuwe duiker toevoegen';

  @override
  String get settings_profileHub_cannotDeleteOnly =>
      'Kan het enige duikersprofiel niet verwijderen';

  @override
  String get settings_profileHub_createDiverTitle => 'Duiker aanmaken';

  @override
  String settings_profileHub_deleteConfirmContent(String name) {
    return 'Weet je zeker dat je $name wilt verwijderen? Alle bijbehorende duiklogs worden losgekoppeld.';
  }

  @override
  String get settings_profileHub_deleteConfirmTitle => 'Duiker verwijderen?';

  @override
  String get settings_profileHub_deleteDiver => 'Duiker verwijderen';

  @override
  String get settings_profileHub_deleted => 'Duiker verwijderd';

  @override
  String get settings_profileHub_emergencyContacts => 'Noodcontacten';

  @override
  String settings_profileHub_emergencyContacts_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacten ingesteld',
      one: '1 contact ingesteld',
      zero: 'Niet ingesteld',
    );
    return '$_temp0';
  }

  @override
  String get settings_profileHub_insurance => 'Verzekering';

  @override
  String get settings_profileHub_insurance_expired => 'Verlopen';

  @override
  String get settings_profileHub_insurance_notSet => 'Niet ingesteld';

  @override
  String get settings_profileHub_medicalInfo => 'Medische informatie';

  @override
  String get settings_profileHub_medicalInfo_notSet => 'Niet ingesteld';

  @override
  String get settings_profileHub_notes => 'Notities';

  @override
  String get settings_profileHub_notes_notSet => 'Niet ingesteld';

  @override
  String get settings_profileHub_personalInfo => 'Persoonlijke gegevens';

  @override
  String get settings_profileHub_personalInfo_notSet => 'Niet ingesteld';

  @override
  String get settings_profileHub_saved => 'Wijzigingen opgeslagen';

  @override
  String get settings_profileHub_switchDiver => 'Duiker wisselen';

  @override
  String get settings_s3Config_action_remove => 'Configuratie verwijderen';

  @override
  String get settings_s3Config_action_testConnection => 'Verbinding testen';

  @override
  String get settings_s3Config_advanced_title => 'Geavanceerd';

  @override
  String get settings_s3Config_appBar_title => 'S3-compatibele opslag';

  @override
  String get settings_s3Config_error_secureStorage =>
      'Kon geen toegang krijgen tot de beveiligde opslag';

  @override
  String get settings_s3Config_field_accessKeyId_label => 'Access Key ID';

  @override
  String get settings_s3Config_field_bucket_label => 'Bucket';

  @override
  String get settings_s3Config_field_endpoint_helper =>
      'Bijvoorbeeld: https://s3.example.com';

  @override
  String get settings_s3Config_field_endpoint_label => 'Endpoint-URL';

  @override
  String get settings_s3Config_field_pathStyle_label =>
      'Path-style-adressering gebruiken';

  @override
  String get settings_s3Config_field_pathStyle_subtitle =>
      'Vereist door de meeste zelf-gehoste servers';

  @override
  String get settings_s3Config_field_prefix_label => 'Sleutelvoorvoegsel';

  @override
  String settings_s3Config_field_region_helperAuto(String region) {
    return 'Automatisch gedetecteerd: $region';
  }

  @override
  String get settings_s3Config_field_region_label => 'Regio';

  @override
  String get settings_s3Config_field_secretAccessKey_label =>
      'Secret Access Key';

  @override
  String get settings_s3Config_remove_confirm_action => 'Verwijderen';

  @override
  String get settings_s3Config_remove_confirm_body =>
      'Synchronisatie via S3 stopt op dit apparaat. Je gegevens in de bucket worden niet verwijderd.';

  @override
  String get settings_s3Config_remove_confirm_title =>
      'S3-configuratie verwijderen?';

  @override
  String get settings_s3Config_removed => 'S3-configuratie verwijderd';

  @override
  String get settings_s3Config_saved => 'S3-configuratie opgeslagen';

  @override
  String settings_s3Config_test_regionDetected(String region) {
    return 'Regio gedetecteerd: $region';
  }

  @override
  String get settings_s3Config_test_success => 'Verbinding geslaagd';

  @override
  String get settings_s3Config_validation_endpointInvalid =>
      'Voer een geldige http://- of https://-URL in';

  @override
  String get settings_s3Config_validation_endpointPath =>
      'De endpoint-URL mag geen pad bevatten';

  @override
  String get settings_s3Config_validation_required => 'Verplicht';

  @override
  String get settings_s3Config_warning_http =>
      'Dit endpoint gebruikt onversleuteld HTTP. Inloggegevens en duikgegevens worden onversleuteld verzonden; gebruik dit alleen op een vertrouwd netwerk.';

  @override
  String get settings_section_about_subtitle => 'App-info & licenties';

  @override
  String get settings_section_about_title => 'Over';

  @override
  String get settings_section_appearance_subtitle => 'Thema & weergave';

  @override
  String get settings_section_appearance_title => 'Uiterlijk';

  @override
  String get settings_section_data_subtitle => 'Back-up, herstel & opslag';

  @override
  String get settings_section_data_title => 'Gegevens';

  @override
  String get settings_section_decompression_subtitle => 'Gradientfactoren';

  @override
  String get settings_section_decompression_title => 'Decompressie';

  @override
  String get settings_section_diverProfile_subtitle =>
      'Actieve duiker & profielen';

  @override
  String get settings_section_diverProfile_title => 'Duikersprofiel';

  @override
  String get settings_section_manage_subtitle =>
      'Duiktypes & flesvoorinstellingen';

  @override
  String get settings_section_manage_title => 'Beheren';

  @override
  String get settings_section_notifications_subtitle =>
      'Onderhoudsherinneringen';

  @override
  String get settings_section_notifications_title => 'Meldingen';

  @override
  String get settings_section_units_subtitle => 'Meetvoorkeuren';

  @override
  String get settings_section_units_title => 'Eenheden';

  @override
  String get settings_storage_appBar_title => 'Database-opslag';

  @override
  String get settings_storage_appDefault => 'App-standaard';

  @override
  String get settings_storage_appDefaultLocation => 'Standaard app-locatie';

  @override
  String get settings_storage_appDefault_subtitle =>
      'Standaard app-opslaglocatie';

  @override
  String get settings_storage_currentLocation => 'Huidige locatie';

  @override
  String get settings_storage_currentLocation_label => 'Huidige locatie';

  @override
  String get settings_storage_customFolder => 'Aangepaste map';

  @override
  String get settings_storage_customFolder_change => 'Wijzigen';

  @override
  String get settings_storage_customFolder_subtitle =>
      'Kies een gesynchroniseerde map (Dropbox, Google Drive, enz.)';

  @override
  String get settings_storage_customFolder_subtitleDeviceOnly =>
      'Verplaats de database naar interne opslag of een SD-kaart';

  @override
  String get settings_storage_customFolder_deviceOnly_noCloudSync =>
      'Door de app beheerde cloudsynchronisatie is uitgeschakeld zolang de database op een opslagvolume van het apparaat staat. Geen enkele synchronisatiedienst kan die map op Android bereiken; gebruik Back-up en Herstel om elders kopieën te bewaren.';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize • $diveCount duiken • $siteCount stekken';
  }

  @override
  String get settings_storage_dismissError_tooltip => 'Foutmelding sluiten';

  @override
  String get settings_storage_dismissSuccess_tooltip => 'Succesbericht sluiten';

  @override
  String get settings_storage_header_storageLocation => 'Opslaglocatie';

  @override
  String get settings_storage_info_customActive =>
      'App-beheerde cloudsynchronisatie is uitgeschakeld. De synchronisatieservice van je map (Dropbox, Google Drive, enz.) verzorgt de synchronisatie.';

  @override
  String get settings_storage_info_customAvailable =>
      'Het gebruik van een aangepaste map schakelt app-beheerde cloudsynchronisatie uit. De synchronisatieservice van je map verzorgt dan de synchronisatie.';

  @override
  String get settings_storage_loading => 'Laden...';

  @override
  String get settings_storage_migrating_doNotClose => 'Sluit de app niet';

  @override
  String get settings_storage_migrating_movingDatabase =>
      'Database verplaatsen...';

  @override
  String get settings_storage_migrating_movingToAppDefault =>
      'Verplaatsen naar app-standaard...';

  @override
  String get settings_storage_migrating_replacingExisting =>
      'Bestaande database vervangen...';

  @override
  String get settings_storage_migrating_switchingToExisting =>
      'Overschakelen naar bestaande database...';

  @override
  String get settings_storage_notSet => 'Niet ingesteld';

  @override
  String settings_storage_success_backupAt(Object path) {
    return 'Origineel bewaard als back-up op:\n$path';
  }

  @override
  String get settings_storage_success_moved => 'Database succesvol verplaatst';

  @override
  String get settings_storage_dangerZone => 'Gevarenzone';

  @override
  String get settings_storage_resetDatabase => 'Database resetten';

  @override
  String get settings_storage_resetDatabase_subtitle =>
      'Alle gegevens op dit apparaat verwijderen en opnieuw beginnen';

  @override
  String get settings_storage_resetDialog_title => 'Database resetten?';

  @override
  String get settings_storage_resetDialog_body =>
      'Dit verwijdert permanent alle gegevens op DIT apparaat, inclusief duiken, stekken, uitrusting en instellingen. Er wordt automatisch een back-up gemaakt voor het resetten.\n\nJe cloudbibliotheek wordt niet verwijderd en andere apparaten behouden hun gegevens. Cloudsynchronisatie wordt losgekoppeld zodat de reset niet ongedaan wordt gemaakt; je kunt deze opnieuw verbinden via Instellingen > Cloudsynchronisatie.';

  @override
  String get settings_storage_resetDialog_confirmWord => 'Delete';

  @override
  String get settings_storage_resetDialog_confirmHint =>
      'Typ \"Delete\" om te bevestigen';

  @override
  String get settings_storage_resetDialog_confirmButton => 'Resetten';

  @override
  String get settings_storage_resetDialog_backupFailed =>
      'Back-up mislukt. Reset afgebroken om je gegevens te beschermen.';

  @override
  String settings_storage_resetDialog_resetFailed(Object error) {
    return 'Resetten mislukt: $error';
  }

  @override
  String get settings_storage_resetComplete_title => 'Database gereset';

  @override
  String get settings_storage_resetComplete_description =>
      'De gegevens van dit apparaat zijn gewist en er is een back-up opgeslagen. Cloudsynchronisatie is nu losgekoppeld zodat de reset niet ongedaan wordt gemaakt; je kunt deze opnieuw verbinden via Instellingen > Cloudsynchronisatie. Tik op doorgaan om de app opnieuw te laden.';

  @override
  String get settings_summary_activeDiver => 'Actieve duiker';

  @override
  String get settings_summary_currentConfiguration => 'Huidige configuratie';

  @override
  String get settings_summary_depth => 'Diepte';

  @override
  String get settings_summary_error => 'Fout';

  @override
  String get settings_summary_gradientFactors => 'Gradientfactoren';

  @override
  String get settings_summary_loading => 'Laden...';

  @override
  String get settings_summary_notSet => 'Niet ingesteld';

  @override
  String get settings_summary_pressure => 'Druk';

  @override
  String get settings_summary_subtitle =>
      'Selecteer een categorie om in te stellen';

  @override
  String get settings_summary_temperature => 'Temperatuur';

  @override
  String get settings_summary_theme => 'Thema';

  @override
  String get settings_summary_theme_dark => 'Donker';

  @override
  String get settings_summary_theme_light => 'Licht';

  @override
  String get settings_summary_theme_system => 'Systeem';

  @override
  String get settings_summary_tip =>
      'Tip: Gebruik de sectie Gegevens om regelmatig een back-up van je duiklogs te maken.';

  @override
  String get settings_summary_title => 'Instellingen';

  @override
  String get settings_summary_unitPreferences => 'Eenheidsvoorkeuren';

  @override
  String get settings_summary_units => 'Eenheden';

  @override
  String get settings_summary_volume => 'Volume';

  @override
  String get settings_summary_weight => 'Gewicht';

  @override
  String get settings_units_custom => 'Aangepast';

  @override
  String get settings_units_dateFormat => 'Datumnotatie';

  @override
  String get settings_units_depth => 'Diepte';

  @override
  String get settings_units_depth_feet => 'Voet (ft)';

  @override
  String get settings_units_depth_meters => 'Meters (m)';

  @override
  String get settings_units_dialog_dateFormat => 'Datumnotatie';

  @override
  String get settings_units_dialog_depthUnit => 'Diepte-eenheid';

  @override
  String get settings_units_dialog_pressureUnit => 'Drukeenheid';

  @override
  String get settings_units_dialog_sacRateUnit => 'SAC-snelheidseenheid';

  @override
  String get settings_units_gasModel => 'Gasberekeningen';

  @override
  String get settings_units_gasModel_real => 'Reëel gas';

  @override
  String get settings_units_gasModel_real_subtitle =>
      'Houdt rekening met samendrukbaarheid. Een 12 L-fles op 200 bar bevat ongeveer 2317 L.';

  @override
  String get settings_units_gasModel_ideal => 'Ideaal gas';

  @override
  String get settings_units_gasModel_ideal_subtitle =>
      'Komt overeen met handmatige berekening en duiktabellen. Een 12 L-fles op 200 bar bevat 2400 L.';

  @override
  String get settings_units_gasModel_explanation =>
      'Hoe flesdruk wordt omgerekend naar gasvolume. Dit beïnvloedt het RMV, de gasstatistieken, de planner en de gasrekenmachines. Ideaal gas komt overeen met de berekening die opleidingen leren; reëel gas is fysisch nauwkeurig en geeft een ongeveer 5% lager RMV.';

  @override
  String get settings_units_dialog_gasModel => 'Gasberekeningen';

  @override
  String get settings_units_dialog_temperatureUnit => 'Temperatuureenheid';

  @override
  String get settings_units_dialog_timeFormat => 'Tijdnotatie';

  @override
  String get settings_units_dialog_volumeUnit => 'Volume-eenheid';

  @override
  String get settings_units_dialog_weightUnit => 'Gewichtseenheid';

  @override
  String get settings_units_header_individualUnits => 'Individuele eenheden';

  @override
  String get settings_units_header_timeDateFormat => 'Tijd- & datumnotatie';

  @override
  String get settings_units_header_unitSystem => 'Eenhedensysteem';

  @override
  String get settings_units_imperial => 'Imperiaal';

  @override
  String get settings_units_metric => 'Metrisch';

  @override
  String get settings_units_pressure => 'Druk';

  @override
  String get settings_units_pressure_bar => 'Bar';

  @override
  String get settings_units_pressure_psi => 'PSI';

  @override
  String get settings_units_quickSelect => 'Snel selecteren';

  @override
  String get settings_units_sacRate => 'SAC-snelheid';

  @override
  String get settings_units_defaultCurrency => 'Standaardvaluta';

  @override
  String get settings_units_dialog_defaultCurrency => 'Standaardvaluta';

  @override
  String get settings_units_sac_pressurePerMinute => 'Druk per minuut';

  @override
  String get settings_units_sac_pressurePerMinute_subtitle =>
      'Geen flesvolume nodig (bar/min of psi/min)';

  @override
  String get settings_units_sac_volumePerMinute => 'Volume per minuut';

  @override
  String get settings_units_sac_volumePerMinute_subtitle =>
      'Vereist flesvolume (L/min of cuft/min)';

  @override
  String get settings_units_temperature => 'Temperatuur';

  @override
  String get settings_units_temperature_celsius => 'Celsius (°C)';

  @override
  String get settings_units_temperature_fahrenheit => 'Fahrenheit (°F)';

  @override
  String get settings_units_timeFormat => 'Tijdnotatie';

  @override
  String get settings_units_volume => 'Volume';

  @override
  String get settings_units_volume_cubicFeet => 'Kubieke voet (cuft)';

  @override
  String get settings_units_volume_liters => 'Liters (L)';

  @override
  String get settings_units_weight => 'Gewicht';

  @override
  String get settings_units_weight_kilograms => 'Kilogram (kg)';

  @override
  String get settings_units_weight_pounds => 'Pond (lbs)';

  @override
  String get settings_updates_automaticUpdates => 'Automatische updates';

  @override
  String get settings_updates_automaticUpdatesSubtitle =>
      'Periodiek controleren op updates';

  @override
  String get settings_updates_betaDialogBody =>
      'Bètabuilds worden bij elke wijziging gepubliceerd en kunnen de database van je duiklogboek upgraden vóór de stabiele versie. Later terugschakelen naar stabiel zet de app niet terug naar een oudere versie, en alle apparaten die met elkaar synchroniseren moeten hetzelfde kanaal gebruiken. Vóór elke database-upgrade wordt automatisch een back-up gemaakt.';

  @override
  String get settings_updates_betaDialogConfirm => 'Overschakelen naar bèta';

  @override
  String get settings_updates_betaDialogTitle => 'Bèta-updates ontvangen?';

  @override
  String get settings_updates_channel => 'Updatekanaal';

  @override
  String settings_updates_channelBadgeBeta(String version) {
    return '$version (Bèta)';
  }

  @override
  String get settings_updates_channelBeta => 'Bèta';

  @override
  String get settings_updates_channelBetaSubtitle =>
      'Nieuwe builds bij elke wijziging, vóór de stabiele versie';

  @override
  String get settings_updates_channelStable => 'Stabiel';

  @override
  String get settings_updates_channelStableSubtitle =>
      'Alleen geteste releases';

  @override
  String get settings_updates_checkForUpdates => 'Controleren op updates';

  @override
  String get settings_updates_checking => 'Controleren...';

  @override
  String settings_updates_downloading(String progress) {
    return 'Downloaden... $progress%';
  }

  @override
  String settings_updates_error(String message) {
    return 'Fout: $message';
  }

  @override
  String get settings_updates_header => 'Updates';

  @override
  String get settings_updates_joinBeta => 'Doe mee aan de bèta';

  @override
  String get settings_updates_joinBetaSubtitle =>
      'Krijg nieuwe functies eerder via het bètaprogramma';

  @override
  String get settings_updates_lastChecked => 'Laatst gecontroleerd';

  @override
  String get settings_updates_never => 'Nooit';

  @override
  String settings_updates_readyToInstall(String version) {
    return 'Versie $version klaar om te installeren';
  }

  @override
  String get settings_updates_stableSwitchNotice =>
      'Je blijft op deze bèta totdat de volgende stabiele versie nieuwer is.';

  @override
  String get settings_updates_upToDate => 'Up-to-date';

  @override
  String settings_updates_versionAvailable(String version) {
    return 'Versie $version beschikbaar';
  }

  @override
  String get signatures_action_clear => 'Wissen';

  @override
  String get signatures_action_closeSignatureView =>
      'Handtekeningweergave sluiten';

  @override
  String get signatures_action_deleteSignature => 'Handtekening verwijderen';

  @override
  String get signatures_action_done => 'Gereed';

  @override
  String get signatures_action_readyToSign => 'Klaar om te ondertekenen';

  @override
  String get signatures_action_request => 'Aanvragen';

  @override
  String get signatures_action_saveSignature => 'Handtekening opslaan';

  @override
  String signatures_buddyCard_notSignedSemantics(Object name) {
    return '$name handtekening, niet ondertekend';
  }

  @override
  String signatures_buddyCard_signedSemantics(Object name) {
    return '$name handtekening, ondertekend';
  }

  @override
  String get signatures_captureInstructorSignature =>
      'Handtekening instructeur vastleggen';

  @override
  String signatures_deleteDialog_message(Object name) {
    return 'Weet je zeker dat je de handtekening van $name wilt verwijderen? Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String get signatures_deleteDialog_title => 'Handtekening verwijderen?';

  @override
  String get signatures_drawSignatureHint => 'Teken je handtekening hierboven';

  @override
  String get signatures_drawSignatureHintDetailed =>
      'Teken handtekening hierboven met vinger of stylus';

  @override
  String get signatures_drawSignatureSemantics => 'Teken handtekening';

  @override
  String get signatures_error_drawSignature => 'Teken een handtekening';

  @override
  String get signatures_error_enterSignerName =>
      'Voer de naam van de ondertekenaar in';

  @override
  String get signatures_field_instructorName => 'Naam instructeur';

  @override
  String get signatures_field_instructorNameHint => 'Voer naam instructeur in';

  @override
  String get signatures_handoff_title => 'Geef je apparaat aan';

  @override
  String get signatures_instructorSignature => 'Handtekening instructeur';

  @override
  String get signatures_noSignatureImage => 'Geen handtekeningafbeelding';

  @override
  String signatures_signHere(Object name) {
    return '$name - Onderteken hier';
  }

  @override
  String get signatures_signed => 'Ondertekend';

  @override
  String signatures_signedCountSemantics(Object signed, Object total) {
    return '$signed van $total buddies hebben ondertekend';
  }

  @override
  String signatures_signedDate(Object date) {
    return 'Ondertekend $date';
  }

  @override
  String get signatures_title => 'Handtekeningen';

  @override
  String get signatures_viewSignature => 'Handtekening bekijken';

  @override
  String signatures_viewSignatureSemantics(Object name) {
    return 'Bekijk handtekening van $name';
  }

  @override
  String get statistics_appBar_title => 'Statistieken';

  @override
  String statistics_categoryCard_semanticLabel(Object title) {
    return '$title statistiekencategorie';
  }

  @override
  String get statistics_category_conditions_subtitle => 'Zicht & temperatuur';

  @override
  String get statistics_category_conditions_title => 'Omstandigheden';

  @override
  String get statistics_category_equipment_subtitle =>
      'Uitrustingsgebruik & gewicht';

  @override
  String get statistics_category_equipment_title => 'Uitrusting';

  @override
  String get statistics_category_gas_subtitle => 'SAC-waarden & gasmengsels';

  @override
  String get statistics_category_gas_title => 'Luchtverbruik';

  @override
  String get statistics_category_geographic_subtitle => 'Landen & regio\'s';

  @override
  String get statistics_category_geographic_title => 'Geografisch';

  @override
  String get statistics_category_marineLife_subtitle => 'Soortwaarnemingen';

  @override
  String get statistics_category_marineLife_title => 'Zeeleven';

  @override
  String get statistics_category_overview_title => 'Overview';

  @override
  String get statistics_category_overview_subtitle =>
      'Totals, records, and breakdowns at a glance';

  @override
  String get statistics_category_profile_subtitle => 'Opstijgsnelheden & deco';

  @override
  String get statistics_category_profile_title => 'Profielanalyse';

  @override
  String get statistics_category_progression_subtitle => 'Diepte- & tijdtrends';

  @override
  String get statistics_category_progression_title => 'Progressie';

  @override
  String get statistics_category_social_subtitle => 'Buddy\'s & duikcentra';

  @override
  String get statistics_category_social_title => 'Sociaal';

  @override
  String get statistics_category_timePatterns_subtitle => 'Wanneer je duikt';

  @override
  String get statistics_category_timePatterns_title => 'Tijdpatronen';

  @override
  String statistics_chart_barSemanticLabel(Object count) {
    return 'Staafdiagram met $count categorieen';
  }

  @override
  String statistics_chart_distributionSemanticLabel(Object count) {
    return 'Cirkeldiagram met $count segmenten';
  }

  @override
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames) {
    return 'Multi-trend lijndiagram die $seriesNames vergelijkt';
  }

  @override
  String get statistics_chart_noBarData => 'Geen gegevens beschikbaar';

  @override
  String get statistics_chart_noDistributionData =>
      'Geen verdelingsgegevens beschikbaar';

  @override
  String get statistics_chart_noTrendData => 'Geen trendgegevens beschikbaar';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return 'Trendlijndiagram met $count datapunten';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return 'Trendlijndiagram met $count datapunten voor $yAxisLabel';
  }

  @override
  String get statistics_conditions_appBar_title => 'Omstandigheden';

  @override
  String get statistics_conditions_entryMethod_empty =>
      'Geen gegevens over instaptmethode beschikbaar';

  @override
  String get statistics_conditions_entryMethod_error =>
      'Kan gegevens over instapmethode niet laden';

  @override
  String get statistics_conditions_entryMethod_subtitle => 'Wal, boot, enz.';

  @override
  String get statistics_conditions_entryMethod_title => 'Instapmethode';

  @override
  String get statistics_conditions_temperature_empty =>
      'Geen temperatuurgegevens beschikbaar';

  @override
  String get statistics_conditions_temperature_error =>
      'Kan temperatuurgegevens niet laden';

  @override
  String get statistics_conditions_temperature_seriesAvg => 'Gem.';

  @override
  String get statistics_conditions_temperature_seriesMax => 'Max';

  @override
  String get statistics_conditions_temperature_seriesMin => 'Min';

  @override
  String get statistics_conditions_temperature_subtitle =>
      'Min/Gem./Max temperaturen';

  @override
  String get statistics_conditions_temperature_title =>
      'Watertemperatuur per maand';

  @override
  String get statistics_conditions_visibility_error =>
      'Kan zichtgegevens niet laden';

  @override
  String get statistics_conditions_visibility_subtitle =>
      'Duiken per zichtomstandigheid';

  @override
  String get statistics_conditions_visibility_title => 'Zichtverdeling';

  @override
  String get statistics_conditions_waterType_error =>
      'Kan watertypegegevens niet laden';

  @override
  String get statistics_conditions_waterType_subtitle =>
      'Zout- vs zoetwaterduiken';

  @override
  String get statistics_conditions_waterType_title => 'Watertype';

  @override
  String get statistics_equipment_appBar_title => 'Uitrusting';

  @override
  String get statistics_equipment_mostUsedGear_error =>
      'Kan uitrustingsgegevens niet laden';

  @override
  String get statistics_equipment_mostUsedGear_subtitle =>
      'Uitrusting op aantal duiken';

  @override
  String get statistics_equipment_mostUsedGear_title =>
      'Meest gebruikte uitrusting';

  @override
  String get statistics_equipment_weightTrend_error =>
      'Kan gewichtstrend niet laden';

  @override
  String get statistics_equipment_weightTrend_subtitle =>
      'Gemiddeld gewicht over tijd';

  @override
  String get statistics_equipment_weightTrend_title => 'Gewichtstrend';

  @override
  String get statistics_error_loadingStatistics =>
      'Fout bij laden van statistieken';

  @override
  String get statistics_filterBar_clear => 'Filter wissen';

  @override
  String statistics_filterBar_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken',
      one: '1 duik',
    );
    return '$_temp0';
  }

  @override
  String get statistics_gas_appBar_title => 'Luchtverbruik';

  @override
  String get statistics_gas_gasMix_error => 'Kan gasmengselgegevens niet laden';

  @override
  String get statistics_gas_gasMix_subtitle => 'Duiken per gastype';

  @override
  String get statistics_gas_gasMix_title => 'Gasmengselverdeling';

  @override
  String get statistics_gas_sacByRole_empty =>
      'Geen multi-flesgegevens beschikbaar';

  @override
  String get statistics_gas_sacByRole_error => 'Kan SAC per rol niet laden';

  @override
  String get statistics_gas_sacByRole_subtitle =>
      'Gemiddeld verbruik per flestype';

  @override
  String get statistics_gas_sacByRole_title => 'SAC per flesrol';

  @override
  String get statistics_gas_sacRecords_best => 'Beste SAC-waarde';

  @override
  String get statistics_gas_sacRecords_empty =>
      'Nog geen SAC-gegevens beschikbaar';

  @override
  String get statistics_gas_sacRecords_error => 'Kan SAC-records niet laden';

  @override
  String get statistics_gas_sacRecords_highest => 'Hoogste SAC-waarde';

  @override
  String get statistics_gas_sacRecords_subtitle =>
      'Beste en slechtste luchtverbruik';

  @override
  String get statistics_gas_sacRecords_title => 'SAC-records';

  @override
  String get statistics_gas_sacTrend_error => 'Kan SAC-trend niet laden';

  @override
  String get statistics_gas_sacTrend_subtitle =>
      'Maandelijks gemiddelde over 5 jaar';

  @override
  String get statistics_gas_sacTrend_title => 'SAC-trend';

  @override
  String get statistics_gas_tankRole_backGas => 'Achtergas';

  @override
  String get statistics_gas_tankRole_bailout => 'Bailout';

  @override
  String get statistics_gas_tankRole_deco => 'Deco';

  @override
  String get statistics_gas_tankRole_diluent => 'Diluent';

  @override
  String get statistics_gas_tankRole_oxygenSupply => 'O₂-toevoer';

  @override
  String get statistics_gas_tankRole_pony => 'Ponyfles';

  @override
  String get statistics_gas_tankRole_sidemountLeft => 'Sidemount L';

  @override
  String get statistics_gas_tankRole_sidemountRight => 'Sidemount R';

  @override
  String get statistics_gas_tankRole_stage => 'Stagefles';

  @override
  String get statistics_geographic_appBar_title => 'Geografisch';

  @override
  String get statistics_geographic_countries_empty => 'Geen landen bezocht';

  @override
  String get statistics_geographic_countries_error =>
      'Kan landgegevens niet laden';

  @override
  String get statistics_geographic_countries_subtitle => 'Duiken per land';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count landen. Top: $topName met $topCount duiken';
  }

  @override
  String get statistics_geographic_countries_title => 'Bezochte landen';

  @override
  String get statistics_geographic_regions_empty => 'Geen regio\'s verkend';

  @override
  String get statistics_geographic_regions_error =>
      'Kan regiogegevens niet laden';

  @override
  String get statistics_geographic_regions_subtitle => 'Duiken per regio';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count regio\'s. Top: $topName met $topCount duiken';
  }

  @override
  String get statistics_geographic_regions_title => 'Verkende regio\'s';

  @override
  String get statistics_geographic_trips_empty => 'Geen reisgegevens';

  @override
  String get statistics_geographic_trips_error => 'Kan reisgegevens niet laden';

  @override
  String get statistics_geographic_trips_subtitle => 'Meest productieve reizen';

  @override
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count reizen. Top: $topName met $topCount duiken';
  }

  @override
  String get statistics_geographic_trips_title => 'Duiken per reis';

  @override
  String get statistics_listContent_selectedSuffix => ', geselecteerd';

  @override
  String get statistics_marineLife_appBar_title => 'Zeeleven';

  @override
  String get statistics_marineLife_bestSites_empty => 'Geen stekgegevens';

  @override
  String get statistics_marineLife_bestSites_error =>
      'Kan stekgegevens niet laden';

  @override
  String get statistics_marineLife_bestSites_subtitle =>
      'Stekken met meeste soortvariatie';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count stekken. Beste: $topName met $topCount soorten';
  }

  @override
  String get statistics_marineLife_bestSites_title =>
      'Beste stekken voor zeeleven';

  @override
  String get statistics_marineLife_mostCommon_empty =>
      'Geen waarnemingsgegevens';

  @override
  String get statistics_marineLife_mostCommon_error =>
      'Kan waarnemingsgegevens niet laden';

  @override
  String get statistics_marineLife_mostCommon_subtitle =>
      'Meest waargenomen soorten';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count soorten. Meest voorkomend: $topName met $topCount waarnemingen';
  }

  @override
  String get statistics_marineLife_mostCommon_title =>
      'Meest voorkomende waarnemingen';

  @override
  String get statistics_marineLife_speciesSpotted => 'Soorten waargenomen';

  @override
  String get statistics_profile_appBar_title => 'Profielanalyse';

  @override
  String get statistics_profile_ascentDescent_empty =>
      'Geen profielgegevens beschikbaar';

  @override
  String get statistics_profile_ascentDescent_error =>
      'Kan snelheidsgegevens niet laden';

  @override
  String get statistics_profile_ascentDescent_subtitle =>
      'Uit duikprofielgegevens';

  @override
  String get statistics_profile_ascentDescent_title =>
      'Gemiddelde opstijg- & afdalingssnelheden';

  @override
  String get statistics_profile_avgAscent => 'Gem. opstijging';

  @override
  String get statistics_profile_avgDescent => 'Gem. afdaling';

  @override
  String get statistics_profile_deco_decoDives => 'Decoduiken';

  @override
  String get statistics_profile_deco_decoLabel => 'Deco';

  @override
  String get statistics_profile_deco_decoRate => 'Decopercentage';

  @override
  String get statistics_profile_deco_empty => 'Geen decogegevens beschikbaar';

  @override
  String get statistics_profile_deco_error => 'Kan decogegevens niet laden';

  @override
  String get statistics_profile_deco_noDeco => 'Geen deco';

  @override
  String get statistics_profile_deco_notRecorded => 'Niet vastgelegd';

  @override
  String statistics_profile_deco_notRecordedHint(int count) {
    return '$count duiken hebben geen vastgelegde of berekenbare decogegevens en tellen niet mee voor het percentage';
  }

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return 'Decompressiepercentage: $percentage% van de duiken vereiste decostops';
  }

  @override
  String get statistics_profile_deco_subtitle => 'Duiken met decostops';

  @override
  String get statistics_profile_deco_title => 'Decompressieverplichting';

  @override
  String get statistics_profile_timeAtDepth_empty =>
      'Geen dieptegegevens beschikbaar';

  @override
  String get statistics_profile_timeAtDepth_error =>
      'Kan dieptebereikgegevens niet laden';

  @override
  String get statistics_profile_timeAtDepth_subtitle =>
      'Geschatte tijd op elke diepte';

  @override
  String get statistics_profile_timeAtDepth_title => 'Tijd op dieptebereiken';

  @override
  String statistics_profile_timeAtDepth_valueFormat(Object value) {
    return '$value min';
  }

  @override
  String get statistics_progression_appBar_title => 'Duikprogressie';

  @override
  String get statistics_progression_bottomTime_error =>
      'Kan bodemtijdtrend niet laden';

  @override
  String get statistics_progression_bottomTime_subtitle =>
      'Gemiddelde duur per maand';

  @override
  String get statistics_progression_bottomTime_title => 'Bodemtijdtrend';

  @override
  String get statistics_progression_cumulative_error =>
      'Kan cumulatieve gegevens niet laden';

  @override
  String get statistics_progression_cumulative_subtitle =>
      'Totaal duiken over tijd';

  @override
  String get statistics_progression_cumulative_title =>
      'Cumulatief aantal duiken';

  @override
  String get statistics_progression_depthProgression_error =>
      'Kan diepteprogressie niet laden';

  @override
  String get statistics_progression_depthProgression_subtitle =>
      'Maandelijkse max diepte over 5 jaar';

  @override
  String get statistics_progression_depthProgression_title =>
      'Maximale diepteprogressie';

  @override
  String get statistics_progression_divesPerYear_empty =>
      'Geen jaarlijkse gegevens beschikbaar';

  @override
  String get statistics_progression_divesPerYear_error =>
      'Kan jaarlijkse gegevens niet laden';

  @override
  String get statistics_progression_divesPerYear_subtitle =>
      'Jaarlijkse vergelijking van aantal duiken';

  @override
  String get statistics_progression_divesPerYear_title => 'Duiken per jaar';

  @override
  String get statistics_ranking_countLabel_dives => 'duiken';

  @override
  String get statistics_ranking_countLabel_sightings => 'waarnemingen';

  @override
  String get statistics_ranking_countLabel_species => 'soorten';

  @override
  String get statistics_ranking_emptyState => 'Nog geen gegevens';

  @override
  String statistics_ranking_itemCount(Object count, Object label) {
    return '$count $label';
  }

  @override
  String statistics_ranking_moreItems(Object count) {
    return 'en $count meer';
  }

  @override
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  ) {
    return '$name, rang $rank, $count $label';
  }

  @override
  String get statistics_records_appBar_title => 'Duikrecords';

  @override
  String get statistics_records_coldestDive => 'Koudste duik';

  @override
  String get statistics_records_deepestDive => 'Diepste duik';

  @override
  String statistics_records_diveNumber(Object number) {
    return 'Duik #$number';
  }

  @override
  String get statistics_records_emptySubtitle =>
      'Begin met het loggen van duiken om hier je records te zien';

  @override
  String get statistics_records_emptyTitle => 'Nog geen records';

  @override
  String get statistics_records_error => 'Fout bij laden van records';

  @override
  String get statistics_records_firstDive => 'Eerste duik';

  @override
  String get statistics_records_longestDive => 'Langste duik';

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
  String get statistics_records_milestones => 'Mijlpalen';

  @override
  String get statistics_records_mostRecentDive => 'Meest recente duik';

  @override
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  ) {
    return '$title: $value bij $siteName';
  }

  @override
  String get statistics_records_retry => 'Opnieuw proberen';

  @override
  String get statistics_records_shallowestDive => 'Ondiepste duik';

  @override
  String get statistics_records_unknownSite => 'Onbekende stek';

  @override
  String get statistics_records_warmestDive => 'Warmste duik';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return '$title sectie';
  }

  @override
  String get statistics_social_appBar_title => 'Sociaal & buddy\'s';

  @override
  String get statistics_social_soloVsBuddy_empty =>
      'Geen duikgegevens beschikbaar';

  @override
  String get statistics_social_soloVsBuddy_error =>
      'Kan buddygegevens niet laden';

  @override
  String get statistics_social_soloVsBuddy_solo => 'Solo';

  @override
  String get statistics_social_soloVsBuddy_subtitle =>
      'Duiken met of zonder metgezel';

  @override
  String get statistics_social_soloVsBuddy_title => 'Solo- vs buddyduiken';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => 'Met buddy';

  @override
  String get statistics_social_topBuddies_error =>
      'Kan buddyranglijst niet laden';

  @override
  String get statistics_social_topBuddies_subtitle =>
      'Meest frequente duikmaatjes';

  @override
  String get statistics_social_topBuddies_title => 'Top duikbuddy\'s';

  @override
  String get statistics_social_topDiveCenters_error =>
      'Kan duikcentrumranglijst niet laden';

  @override
  String get statistics_social_topDiveCenters_subtitle =>
      'Meest bezochte aanbieders';

  @override
  String get statistics_social_topDiveCenters_title => 'Top duikcentra';

  @override
  String get statistics_summary_avgDepth => 'Gem. diepte';

  @override
  String get statistics_summary_avgTemp => 'Gem. temp.';

  @override
  String get statistics_summary_depthDistribution_empty =>
      'Grafiek verschijnt wanneer je duiken logt';

  @override
  String get statistics_summary_depthDistribution_semanticLabel =>
      'Cirkeldiagram met diepteverdeling';

  @override
  String get statistics_summary_depthDistribution_title => 'Diepteverdeling';

  @override
  String get statistics_summary_diveTypes_empty =>
      'Grafiek verschijnt wanneer je duiken logt';

  @override
  String statistics_summary_diveTypes_moreTypes(Object count) {
    return 'en $count meer types';
  }

  @override
  String get statistics_summary_diveTypes_semanticLabel =>
      'Cirkeldiagram met duiktypeverdeling';

  @override
  String get statistics_summary_diveTypes_title => 'Duiktypes';

  @override
  String get statistics_summary_divesByMonth_empty =>
      'Grafiek verschijnt wanneer je duiken logt';

  @override
  String get statistics_summary_divesByMonth_semanticLabel =>
      'Staafdiagram met duiken per maand';

  @override
  String get statistics_summary_divesByMonth_title => 'Duiken per maand';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel\n$count duiken';
  }

  @override
  String get statistics_summary_header_subtitle =>
      'Selecteer een categorie om gedetailleerde statistieken te bekijken';

  @override
  String get statistics_summary_header_title => 'Statistiekenoverzicht';

  @override
  String get statistics_summary_maxDepth => 'Max diepte';

  @override
  String get statistics_summary_sitesVisited => 'Bezochte stekken';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken',
      one: '1 duik',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty => 'Nog geen tags aangemaakt';

  @override
  String get statistics_summary_tagUsage_emptyHint =>
      'Voeg tags toe aan duiken om statistieken te zien';

  @override
  String statistics_summary_tagUsage_moreTags(Object count) {
    return 'en $count meer tags';
  }

  @override
  String statistics_summary_tagUsage_tagCount(Object count) {
    return '$count tags';
  }

  @override
  String get statistics_summary_tagUsage_title => 'Taggebruik';

  @override
  String statistics_summary_topDiveSites_diveCount(Object count) {
    return '$count duiken';
  }

  @override
  String get statistics_summary_topDiveSites_empty => 'Nog geen duikstekken';

  @override
  String get statistics_summary_topDiveSites_title => 'Top duikstekken';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count totaal';
  }

  @override
  String get statistics_summary_totalDives => 'Totaal duiken';

  @override
  String get statistics_summary_totalTime => 'Totale tijd';

  @override
  String get statistics_timePatterns_appBar_title => 'Tijdpatronen';

  @override
  String get statistics_timePatterns_dayOfWeek_empty =>
      'Geen gegevens beschikbaar';

  @override
  String get statistics_timePatterns_dayOfWeek_error =>
      'Kan daggegevens niet laden';

  @override
  String get statistics_timePatterns_dayOfWeek_fri => 'Vr';

  @override
  String get statistics_timePatterns_dayOfWeek_mon => 'Ma';

  @override
  String get statistics_timePatterns_dayOfWeek_sat => 'Za';

  @override
  String get statistics_timePatterns_dayOfWeek_subtitle =>
      'Wanneer duik je het meest?';

  @override
  String get statistics_timePatterns_dayOfWeek_sun => 'Zo';

  @override
  String get statistics_timePatterns_dayOfWeek_thu => 'Do';

  @override
  String get statistics_timePatterns_dayOfWeek_title =>
      'Duiken per dag van de week';

  @override
  String get statistics_timePatterns_dayOfWeek_tue => 'Di';

  @override
  String get statistics_timePatterns_dayOfWeek_wed => 'Wo';

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
  String get statistics_timePatterns_month_mar => 'Mrt';

  @override
  String get statistics_timePatterns_month_may => 'Mei';

  @override
  String get statistics_timePatterns_month_nov => 'Nov';

  @override
  String get statistics_timePatterns_month_oct => 'Okt';

  @override
  String get statistics_timePatterns_month_sep => 'Sep';

  @override
  String get statistics_timePatterns_seasonal_empty =>
      'Geen gegevens beschikbaar';

  @override
  String get statistics_timePatterns_seasonal_error =>
      'Kan seizoensgegevens niet laden';

  @override
  String get statistics_timePatterns_seasonal_subtitle =>
      'Duiken per maand (alle jaren)';

  @override
  String get statistics_timePatterns_seasonal_title => 'Seizoenspatronen';

  @override
  String get statistics_timePatterns_surfaceInterval_average => 'Gemiddeld';

  @override
  String get statistics_timePatterns_surfaceInterval_empty =>
      'Geen oppervlakte-intervalgegevens beschikbaar';

  @override
  String get statistics_timePatterns_surfaceInterval_error =>
      'Kan oppervlakte-intervalgegevens niet laden';

  @override
  String statistics_timePatterns_surfaceInterval_formatHoursMinutes(
    Object hours,
    Object minutes,
  ) {
    return '${hours}u ${minutes}m';
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
      'Tijd tussen duiken';

  @override
  String get statistics_timePatterns_surfaceInterval_title =>
      'Oppervlakte-intervalstatistieken';

  @override
  String get statistics_timePatterns_timeOfDay_error =>
      'Kan tijdstipgegevens niet laden';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle =>
      'Ochtend, middag, avond of nacht';

  @override
  String get statistics_timePatterns_timeOfDay_title =>
      'Duiken per tijdstip van de dag';

  @override
  String get statistics_tooltip_diveRecords => 'Duikrecords';

  @override
  String get statistics_tooltip_filter => 'Statistieken filteren';

  @override
  String get statistics_tooltip_refreshRecords => 'Records verversen';

  @override
  String get statistics_tooltip_refreshStatistics => 'Statistieken verversen';

  @override
  String statistics_valueCard_semanticLabel(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String get surfaceInterval_aboutTissueLoading_body =>
      'Je lichaam heeft 16 weefselcompartimenten die stikstof absorberen en afgeven met verschillende snelheden. Snelle weefsels (zoals bloed) verzadigen snel maar geven ook snel gas af. Langzame weefsels (zoals bot en vet) hebben langer nodig om zowel te laden als te ontladen. Het \"leidende compartiment\" is het weefsel dat het meest verzadigd is en bepaalt meestal je no-decompression limiet (NDL). Tijdens een oppervlakte-interval geven alle weefsels gas af naar oppervlakteverzadigingsniveaus (~40% belading).';

  @override
  String get surfaceInterval_aboutTissueLoading_title =>
      'Over weefselbelasting';

  @override
  String get surfaceInterval_action_resetDefaults =>
      'Standaardwaarden herstellen';

  @override
  String get surfaceInterval_disclaimer =>
      'Deze tool is alleen voor planningsdoeleinden. Gebruik altijd een duikcomputer en volg je training. Resultaten zijn gebaseerd op het Buhlmann ZH-L16C algoritme en kunnen verschillen van je computer.';

  @override
  String get surfaceInterval_field_depth => 'Diepte';

  @override
  String get surfaceInterval_field_gasMix => 'Gasmengsel: ';

  @override
  String get surfaceInterval_field_he => 'He';

  @override
  String get surfaceInterval_field_o2 => 'O₂';

  @override
  String get surfaceInterval_field_time => 'Tijd';

  @override
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit) {
    return 'Eerste duik diepte: $depth $unit';
  }

  @override
  String surfaceInterval_firstDive_timeSemantics(Object time) {
    return 'Eerste duik tijd: $time minuten';
  }

  @override
  String get surfaceInterval_firstDive_title => 'Eerste duik';

  @override
  String surfaceInterval_format_hours(Object count) {
    return '$count uur';
  }

  @override
  String surfaceInterval_format_minutes(Object count) {
    return '$count min';
  }

  @override
  String get surfaceInterval_gasMix_air => 'Lucht';

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
    return 'ppO₂ $ppO2 op $depth overschrijdt $limit. De MOD voor dit mengsel is $mod.';
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
    return 'De wachttijd valt buiten de $hours uur die deze planner doorzoekt. De ontgassing gaat door, dus een langer oppervlakte-interval volstaat.';
  }

  @override
  String surfaceInterval_result_beyondHorizonShort(Object hours) {
    return 'Meer dan $hours uur';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Huidig interval';

  @override
  String get surfaceInterval_result_gasUnsafe => 'Gas onveilig op deze diepte';

  @override
  String get surfaceInterval_result_inDeco => 'In deco';

  @override
  String get surfaceInterval_result_increaseInterval =>
      'Verhoog oppervlakte-interval of verminder tweede duik diepte/tijd';

  @override
  String get surfaceInterval_result_minimumInterval =>
      'Minimaal oppervlakte-interval';

  @override
  String get surfaceInterval_result_ndlForSecondDive => 'NDL voor 2e duik';

  @override
  String surfaceInterval_result_ndlMinutes(Object minutes) {
    return '$minutes min NDL';
  }

  @override
  String surfaceInterval_result_noIntervalHelps(Object minutes) {
    return 'Geen enkel oppervlakte-interval is voldoende. De langste duik zonder decompressie op deze diepte met dit mengsel duurt $minutes min. Verkort de tweede duik of verminder de diepte.';
  }

  @override
  String get surfaceInterval_result_notAchievable =>
      'Niet haalbaar met welk oppervlakte-interval dan ook';

  @override
  String get surfaceInterval_result_notYetSafe =>
      'Nog niet veilig, verhoog oppervlakte-interval';

  @override
  String get surfaceInterval_result_safeToDive => 'Veilig om te duiken';

  @override
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  ) {
    return 'Minimaal oppervlakte-interval: $interval. Huidig interval: $current. NDL voor tweede duik: $ndl. $status';
  }

  @override
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit) {
    return 'Tweede duik diepte: $depth $unit';
  }

  @override
  String surfaceInterval_secondDive_heSemantics(Object percent) {
    return 'Tweede duik helium: $percent%';
  }

  @override
  String surfaceInterval_secondDive_o2Semantics(Object percent) {
    return 'Tweede duik O2: $percent%';
  }

  @override
  String surfaceInterval_secondDive_timeSemantics(Object time) {
    return 'Tweede duik tijd: $time minuten';
  }

  @override
  String get surfaceInterval_secondDive_title => 'Tweede duik';

  @override
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval) {
    return 'Weefselherstellingsgrafiek met 16 compartimenten gasafgifte over een $interval oppervlakte-interval';
  }

  @override
  String get surfaceInterval_tissueRecovery_compartmentsLabel =>
      'Compartimenten (op halfwaardetijd snelheid)';

  @override
  String get surfaceInterval_tissueRecovery_description =>
      'Toont hoe elk van 16 weefselcompartimenten gas afgeeft tijdens het oppervlakte-interval';

  @override
  String get surfaceInterval_tissueRecovery_fast => 'Snel (C1-5)';

  @override
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number) {
    return 'Leidend compartiment: C$number';
  }

  @override
  String get surfaceInterval_tissueRecovery_loadingPercent => 'Belading %';

  @override
  String get surfaceInterval_tissueRecovery_medium => 'Medium (C6-10)';

  @override
  String get surfaceInterval_tissueRecovery_min => 'Min';

  @override
  String get surfaceInterval_tissueRecovery_now => 'Nu';

  @override
  String get surfaceInterval_tissueRecovery_slow => 'Langzaam (C11-16)';

  @override
  String get surfaceInterval_tissueRecovery_title => 'Weefselsherstel';

  @override
  String get surfaceInterval_title => 'Oppervlakte-interval';

  @override
  String tags_action_createNamed(Object tagName) {
    return 'Maak \"$tagName\" aan';
  }

  @override
  String get tags_action_createTag => 'Tag aanmaken';

  @override
  String get tags_action_browse => 'Bladeren';

  @override
  String get tags_picker_title => 'Tags kiezen';

  @override
  String get tags_picker_empty =>
      'Nog geen tags. Typ een tagnaam om je eerste aan te maken.';

  @override
  String tags_picker_errorLoading(String error) {
    return 'Fout bij het laden van tags: $error';
  }

  @override
  String get tags_picker_allAdded => 'Alle tags zijn al toegevoegd.';

  @override
  String get tags_picker_noMatches =>
      'Geen tags komen overeen met je zoekopdracht.';

  @override
  String tags_picker_addCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags toevoegen',
      one: '1 tag toevoegen',
      zero: 'Tags toevoegen',
    );
    return '$_temp0';
  }

  @override
  String get tags_action_deleteTag => 'Tag verwijderen';

  @override
  String tags_dialog_deleteMessage(Object tagName) {
    return 'Weet je zeker dat je \"$tagName\" wilt verwijderen? Dit verwijdert het van alle duiken.';
  }

  @override
  String get tags_dialog_deleteTitle => 'Tag verwijderen?';

  @override
  String get tags_empty =>
      'Nog geen tags. Maak tags aan bij het bewerken van duiken.';

  @override
  String get tags_hint_addMoreTags => 'Meer tags toevoegen...';

  @override
  String get importWizard_tagsLabel => 'Tags';

  @override
  String get importWizard_photos_stepLabel => 'Foto\'s';

  @override
  String importWizard_photos_foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto\'s waarnaar dit logboek verwijst',
      one: '1 foto waarnaar dit logboek verwijst',
    );
    return '$_temp0';
  }

  @override
  String get importWizard_photos_chooseFolder => 'Fotomap kiezen...';

  @override
  String get importWizard_photos_scanning => 'Map wordt gescand...';

  @override
  String importWizard_photos_matchSummary(
    int matched,
    int byName,
    int missing,
  ) {
    return '$matched gekoppeld, $byName alleen op bestandsnaam, $missing niet gevonden';
  }

  @override
  String get importWizard_photos_skip => 'Foto\'s overslaan';

  @override
  String get importWizard_photos_mobileUnsupported =>
      'Voor het importeren van foto\'s is een map op de schijf van dit apparaat nodig. Voer deze import uit op een computer om ze mee te nemen. Duiken en duikstekken worden normaal geïmporteerd.';

  @override
  String importWizard_review_olderDivesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oudere duiken overgeslagen — al in je logboek',
      one: '1 oudere duik overgeslagen — al in je logboek',
    );
    return '$_temp0';
  }

  @override
  String get tags_hint_addTags => 'Tags toevoegen...';

  @override
  String get tags_manage_title => 'Tags';

  @override
  String get tags_manage_searchHint => 'Tags zoeken...';

  @override
  String tags_manage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken',
      one: '1 duik',
      zero: '0 duiken',
    );
    return '$_temp0';
  }

  @override
  String get tags_manage_emptyState =>
      'Nog geen tags. Maak er een aan om te beginnen.';

  @override
  String tags_manage_selectedCount(int count) {
    return '$count geselecteerd';
  }

  @override
  String get tags_manage_createTitle => 'Tag aanmaken';

  @override
  String get tags_manage_editTitle => 'Tag bewerken';

  @override
  String get tags_manage_nameLabel => 'Tagnaam';

  @override
  String get tags_manage_colorLabel => 'Kleur';

  @override
  String get tags_manage_nameRequired => 'Tagnaam is verplicht';

  @override
  String get tags_manage_deleteTitle => 'Tag verwijderen?';

  @override
  String tags_manage_deleteMessage(String tagName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken',
      one: '1 duik',
      zero: '0 duiken',
    );
    return '\"$tagName\" wordt verwijderd van $_temp0. Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String tags_manage_bulkDeleteTitle(int count) {
    return '$count tags verwijderen?';
  }

  @override
  String tags_manage_bulkDeleteMessage(int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount duiken',
      one: '1 duik',
      zero: '0 duiken',
    );
    return 'Deze tags worden verwijderd van in totaal $_temp0. Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String tags_manage_mergeTitle(int count) {
    return '$count tags samenvoegen';
  }

  @override
  String get tags_manage_mergeResultName => 'Resulterende tagnaam:';

  @override
  String get tags_manage_mergeKeepFrom => 'Of naam overnemen van:';

  @override
  String tags_manage_mergeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken',
      one: '1 duik',
      zero: '0 duiken',
    );
    return 'Dit heeft betrekking op in totaal $_temp0.';
  }

  @override
  String get tags_manage_mergeAction => 'Samenvoegen';

  @override
  String get tags_title_manageTags => 'Tags beheren';

  @override
  String get tank_al30Stage_description => 'Aluminium 30 cu ft stagefles';

  @override
  String get tank_al30Stage_displayName => 'AL30 Stage';

  @override
  String get tank_al40Stage_description => 'Aluminium 40 cu ft stagefles';

  @override
  String get tank_al40Stage_displayName => 'AL40 Stage';

  @override
  String get tank_al40_description => 'Aluminium 40 cu ft (pony)';

  @override
  String get tank_al40_displayName => 'AL40';

  @override
  String get tank_al63_description => 'Aluminium 63 cu ft';

  @override
  String get tank_al63_displayName => 'AL63';

  @override
  String get tank_al80_description => 'Aluminium 80 cu ft (meest gebruikelijk)';

  @override
  String get tank_al80_displayName => 'AL80';

  @override
  String get tank_hp100_description => 'Hogedruk staal 100 cu ft';

  @override
  String get tank_hp100_displayName => 'HP100';

  @override
  String get tank_hp120_description => 'Hogedruk staal 120 cu ft';

  @override
  String get tank_hp120_displayName => 'HP120';

  @override
  String get tank_hp80_description => 'Hogedruk staal 80 cu ft';

  @override
  String get tank_hp80_displayName => 'HP80';

  @override
  String get tank_lp85_description => 'Lagedruk staal 85 cu ft';

  @override
  String get tank_lp85_displayName => 'LP85';

  @override
  String get tank_steel10_description => 'Staal 10 liter (Europa)';

  @override
  String get tank_steel10_displayName => 'Staal 10L';

  @override
  String get tank_steel12_description => 'Staal 12 liter (Europa)';

  @override
  String get tank_steel12_displayName => 'Staal 12L';

  @override
  String get tank_steel15_description => 'Staal 15 liter (Europa)';

  @override
  String get tank_steel15_displayName => 'Staal 15L';

  @override
  String get tides_action_refresh => 'Getijdengegevens verversen';

  @override
  String get tides_chart_24hourForecast => '24-uurs voorspelling';

  @override
  String tides_chart_heightAxis(Object depthSymbol) {
    return 'Hoogte ($depthSymbol)';
  }

  @override
  String get tides_chart_msl => 'MSL';

  @override
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr) {
    return ' Nu $nowTimeStr $nowHeightStr';
  }

  @override
  String get tides_error_unableToLoad => 'Kan getijdengegevens niet laden';

  @override
  String get tides_error_unableToLoadChart => 'Kan grafiek niet laden';

  @override
  String tides_label_ago(Object duration) {
    return '$duration geleden';
  }

  @override
  String tides_label_currentHeight(Object height, Object depthSymbol) {
    return 'Huidig: $height$depthSymbol';
  }

  @override
  String tides_label_fromNow(Object duration) {
    return '$duration vanaf nu';
  }

  @override
  String get tides_label_high => 'Hoog';

  @override
  String get tides_label_highIn => 'Hoog over';

  @override
  String get tides_label_highTide => 'Hoogwater';

  @override
  String get tides_label_low => 'Laag';

  @override
  String get tides_label_lowIn => 'Laag over';

  @override
  String get tides_label_lowTide => 'Laagwater';

  @override
  String tides_label_tideIn(Object duration) {
    return 'over $duration';
  }

  @override
  String get tides_label_tideTimes => 'Getijdentijden';

  @override
  String get tides_label_today => 'Vandaag';

  @override
  String get tides_label_tomorrow => 'Morgen';

  @override
  String get tides_label_upcomingTides => 'Komende getijden';

  @override
  String get tides_legend_highTide => 'Hoogwater';

  @override
  String get tides_legend_lowTide => 'Laagwater';

  @override
  String get tides_legend_now => 'Nu';

  @override
  String get tides_legend_tideLevel => 'Getijdenniveau';

  @override
  String get tides_noDataAvailable => 'Geen getijdengegevens beschikbaar';

  @override
  String get tides_noDataForLocation =>
      'Getijdengegevens niet beschikbaar voor deze locatie';

  @override
  String get tides_noExtremesData => 'Geen extremengegevens';

  @override
  String get tides_noTideTimesAvailable => 'Geen getijdentijden beschikbaar';

  @override
  String tides_semantic_currentTide(
    Object tideState,
    Object height,
    Object depthSymbol,
    Object nextExtreme,
  ) {
    return '$tideState tij, $height$depthSymbol$nextExtreme';
  }

  @override
  String tides_semantic_extremeItem(
    Object typeLabel,
    Object time,
    Object height,
    Object depthSymbol,
  ) {
    return '$typeLabel tij om $time, $height$depthSymbol';
  }

  @override
  String tides_semantic_tideChart(Object extremesSummary) {
    return 'Getijdengrafiek. $extremesSummary';
  }

  @override
  String tides_semantic_tideState(Object state) {
    return 'Getijdenstatus: $state';
  }

  @override
  String tides_source_noaaStation(String name, String distance) {
    return 'NOAA-station: $name ($distance)';
  }

  @override
  String get tides_source_modelEstimate => 'Oceaanmodel-schatting';

  @override
  String get tides_source_modelCaveat =>
      'Gemodelleerd op basis van satellietdata. Tijden en hoogten kunnen afwijken bij complexe kustlijnen.';

  @override
  String get tides_source_sheetTitle => 'Bron getijdendata';

  @override
  String get tides_source_datumMllw =>
      'Hoogten ten opzichte van MLLW (stationsdatum)';

  @override
  String get tides_source_datumMsl =>
      'Hoogten ten opzichte van gemiddeld zeeniveau';

  @override
  String get tides_title => 'Getijden';

  @override
  String get transfer_appBar_title => 'Overdracht';

  @override
  String get transfer_computers_aboutContent =>
      'Verbind je duikcomputer via Bluetooth om duiklogs rechtstreeks naar de app te downloaden. Ondersteunde computers zijn onder andere Suunto, Shearwater, Garmin, Mares en vele andere populaire merken.\n\nApple Watch Ultra-gebruikers kunnen duikgegevens rechtstreeks uit de Gezondheid-app importeren, inclusief diepte, duur en hartslag.';

  @override
  String get transfer_computers_aboutTitle => 'Over duikcomputers';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple Watch';

  @override
  String get transfer_computers_appleWatchSubtitle =>
      'Import dives via Apple HealthKit';

  @override
  String get transfer_computers_appleWatchTitle =>
      'Importeren vanaf Apple Watch';

  @override
  String get transfer_computers_connectSubtitle =>
      'Een duikcomputer zoeken en koppelen';

  @override
  String get transfer_computers_connectTitle => 'Nieuwe computer verbinden';

  @override
  String get transfer_computers_errorLoading => 'Fout bij laden van computers';

  @override
  String get transfer_computers_loading => 'Laden...';

  @override
  String get transfer_computers_manageTitle => 'Computers beheren';

  @override
  String get transfer_computers_noComputersSaved => 'Geen computers opgeslagen';

  @override
  String transfer_computers_diveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken',
      one: '1 duik',
    );
    return '$_temp0';
  }

  @override
  String get transfer_computers_downloadTooltip => 'Duiken downloaden';

  @override
  String get transfer_computers_knownComputersHeader => 'Bekende computers';

  @override
  String transfer_computers_lastDownloadDaysAgo(int days) {
    return '$days dagen geleden';
  }

  @override
  String transfer_computers_lastDownloadHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours uur geleden',
      one: '1 uur geleden',
    );
    return '$_temp0';
  }

  @override
  String transfer_computers_lastDownloadMinutesAgo(int minutes) {
    return '$minutes min geleden';
  }

  @override
  String get transfer_computers_lastDownloadNever => 'Nooit';

  @override
  String get transfer_computers_lastDownloadYesterday => 'Gisteren';

  @override
  String transfer_computers_savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'computers',
      one: 'computer',
    );
    return '$count opgeslagen $_temp0';
  }

  @override
  String get transfer_computers_sectionHeader => 'Duikcomputers';

  @override
  String get transfer_csvExport_cancelButton => 'Annuleren';

  @override
  String get transfer_csvExport_dataTypeHeader => 'Gegevenstype';

  @override
  String get transfer_csvExport_descriptionDives =>
      'Exporteer alle duiklogs als spreadsheet';

  @override
  String get transfer_csvExport_descriptionEquipment =>
      'Exporteer uitrustingsinventaris en onderhoudsinformatie';

  @override
  String get transfer_csvExport_descriptionSites =>
      'Exporteer duiksteklocaties en details';

  @override
  String get transfer_csvExport_dialogTitle => 'CSV exporteren';

  @override
  String get transfer_csvExport_exportButton => 'CSV exporteren';

  @override
  String get transfer_csvExport_optionDivesTitle => 'Duiken CSV';

  @override
  String get transfer_csvExport_optionEquipmentTitle => 'Uitrusting CSV';

  @override
  String get transfer_csvExport_optionSitesTitle => 'Duikstekken CSV';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return 'Exporteer $typeName';
  }

  @override
  String get transfer_csvExport_typeDives => 'Duiken';

  @override
  String get transfer_csvExport_typeEquipment => 'Uitrusting';

  @override
  String get transfer_csvExport_typeSites => 'Duikstekken';

  @override
  String get transfer_detail_backTooltip => 'Terug naar overdracht';

  @override
  String get transfer_export_aboutContent =>
      'Exporteer je duikgegevens in verschillende formaten. PDF maakt een afdrukbaar logboek. UDDF is een universeel formaat dat compatibel is met de meeste duiklogsoftware. CSV-bestanden kunnen worden geopend in spreadsheetapplicaties.';

  @override
  String get transfer_export_backupLink => 'Ga naar Back-up en herstel';

  @override
  String get transfer_export_aboutTitle => 'Over exporteren';

  @override
  String get transfer_export_completed => 'Export voltooid';

  @override
  String get transfer_export_csvSubtitle => 'Spreadsheetformaat';

  @override
  String get transfer_export_csvTitle => 'CSV-export';

  @override
  String get transfer_export_excelSubtitle =>
      'Alle gegevens in een bestand (duiken, stekken, uitrusting, statistieken)';

  @override
  String get transfer_export_excelTitle => 'Excel-werkmap';

  @override
  String transfer_export_failed(Object error) {
    return 'Export mislukt: $error';
  }

  @override
  String get transfer_export_kmlSubtitle =>
      'Bekijk duikstekken op een 3D-globe';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => 'Multi-formaat export';

  @override
  String get transfer_export_optionSaveSubtitle =>
      'Kies waar je wilt opslaan op je apparaat';

  @override
  String get transfer_export_optionSaveTitle => 'Opslaan als bestand';

  @override
  String get transfer_export_optionShareSubtitle =>
      'Verstuur via e-mail, berichten of andere apps';

  @override
  String get transfer_export_optionShareTitle => 'Delen';

  @override
  String get transfer_export_pdfSubtitle => 'Afdrukbaar duiklogboek';

  @override
  String get transfer_export_pdfTitle => 'PDF-logboek';

  @override
  String get transfer_export_progressExporting => 'Exporteren...';

  @override
  String get transfer_export_sectionHeader => 'Gegevens exporteren';

  @override
  String get transfer_export_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_export_uddfTitle => 'UDDF-export';

  @override
  String get transfer_import_aboutContent =>
      'Gebruik \"Gegevens importeren\" voor de beste ervaring -- het detecteert automatisch je bestandsformaat en bronapplicatie. De individuele formaatopties hieronder zijn ook beschikbaar voor directe toegang.';

  @override
  String get transfer_import_aboutTitle => 'Over importeren';

  @override
  String get transfer_import_fileImportSemanticLabel =>
      'Gegevens importeren met automatische detectie';

  @override
  String get transfer_import_fileImportSubtitle =>
      'Detecteert automatisch CSV, UDDF, FIT en meer';

  @override
  String get transfer_import_fileImportTitle => 'Gegevens importeren';

  @override
  String get transfer_import_sectionHeader => 'Gegevens importeren';

  @override
  String get transfer_pdfExport_cancelButton => 'Annuleren';

  @override
  String get transfer_pdfExport_dialogTitle => 'PDF-logboek exporteren';

  @override
  String get transfer_pdfExport_exportButton => 'PDF exporteren';

  @override
  String get transfer_pdfExport_includeCertCards =>
      'Certificeringskaarten opnemen';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle =>
      'Gescande certificeringskaartafbeeldingen aan de PDF toevoegen';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => 'Paginaformaat';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Letter';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => 'Gedetailleerd';

  @override
  String get transfer_pdfExport_templateDetailedDesc =>
      'Volledige duikinformatie met notities en beoordelingen';

  @override
  String get transfer_pdfExport_templateHeader => 'Sjabloon';

  @override
  String get transfer_pdfExport_templateNauiStyle => 'NAUI-stijl';

  @override
  String get transfer_pdfExport_templateNauiStyleDesc =>
      'Lay-out overeenkomstig NAUI-logboekformaat';

  @override
  String get transfer_pdfExport_templatePadiStyle => 'PADI-stijl';

  @override
  String get transfer_pdfExport_templatePadiStyleDesc =>
      'Lay-out overeenkomstig PADI-logboekformaat';

  @override
  String get transfer_pdfExport_templateProfessional => 'Professioneel';

  @override
  String get transfer_pdfExport_templateProfessionalDesc =>
      'Handtekening- en stempelvelden voor verificatie';

  @override
  String transfer_pdfExport_templateSemanticLabel(Object templateName) {
    return 'Selecteer sjabloon $templateName';
  }

  @override
  String get transfer_pdfExport_templateSimple => 'Eenvoudig';

  @override
  String get transfer_pdfExport_templateSimpleDesc =>
      'Compact tabelformaat, veel duiken per pagina';

  @override
  String get transfer_section_computersSubtitle => 'Downloaden van apparaat';

  @override
  String get transfer_section_computersTitle => 'Duikcomputers';

  @override
  String get transfer_section_exportSubtitle => 'CSV, UDDF, PDF-logboek';

  @override
  String get transfer_section_exportTitle => 'Exporteren';

  @override
  String get transfer_section_importSubtitle => 'CSV, UDDF-bestanden';

  @override
  String get transfer_section_importTitle => 'Importeren';

  @override
  String get transfer_summary_description =>
      'Duikgegevens importeren en exporteren';

  @override
  String get transfer_summary_selectSection =>
      'Selecteer een sectie uit de lijst';

  @override
  String get transfer_summary_title => 'Overdracht';

  @override
  String transfer_unknownSection(Object sectionId) {
    return 'Onbekende sectie: $sectionId';
  }

  @override
  String get trips_appBar_title => 'Reizen';

  @override
  String get trips_appBar_tripPhotos => 'Reisfoto\'s';

  @override
  String get trips_detail_action_delete => 'Verwijderen';

  @override
  String get trips_detail_action_export => 'Exporteren';

  @override
  String get trips_detail_appBar_title => 'Reis';

  @override
  String get trips_detail_dialog_cancel => 'Annuleren';

  @override
  String get trips_detail_dialog_deleteConfirm => 'Verwijderen';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen? De reis wordt verwijderd maar de duiken blijven bewaard.';
  }

  @override
  String get trips_detail_dialog_deleteTitle => 'Reis verwijderen?';

  @override
  String get trips_detail_dives_empty => 'Nog geen duiken in deze reis';

  @override
  String get trips_detail_dives_errorLoading => 'Kan duiken niet laden';

  @override
  String get trips_detail_dives_unknownSite => 'Onbekende duikstek';

  @override
  String trips_detail_dives_viewAll(Object count) {
    return 'Alles bekijken ($count)';
  }

  @override
  String trips_detail_durationDays(Object days) {
    return '$days dagen';
  }

  @override
  String get trips_detail_export_csv_comingSoon =>
      'CSV-export binnenkort beschikbaar';

  @override
  String get trips_detail_export_csv_subtitle => 'Alle duiken van deze reis';

  @override
  String get trips_detail_export_csv_title => 'Exporteren naar CSV';

  @override
  String get trips_detail_export_pdf_comingSoon =>
      'PDF-export binnenkort beschikbaar';

  @override
  String get trips_detail_export_pdf_subtitle =>
      'Reisoverzicht met duikdetails';

  @override
  String get trips_detail_export_pdf_title => 'Exporteren naar PDF';

  @override
  String get trips_detail_label_liveaboard => 'Liveaboard';

  @override
  String get trips_detail_label_location => 'Locatie';

  @override
  String get trips_detail_label_resort => 'Resort';

  @override
  String get trips_detail_scan_accessDenied =>
      'Toegang tot fotobibliotheek geweigerd';

  @override
  String get trips_detail_scan_addDivesFirst =>
      'Voeg eerst duiken toe om foto\'s te koppelen';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return 'Fout bij koppelen van foto\'s: $error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return 'Fout bij scannen: $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return '$count foto\'s gekoppeld';
  }

  @override
  String get trips_detail_scan_linkingPhotos => 'Foto\'s koppelen...';

  @override
  String get trips_detail_sectionTitle_details => 'Reisdetails';

  @override
  String get trips_detail_sectionTitle_dives => 'Duiken';

  @override
  String get trips_detail_sectionTitle_notes => 'Notities';

  @override
  String get trips_detail_sectionTitle_statistics => 'Reisstatistieken';

  @override
  String get trips_detail_snackBar_deleted => 'Reis verwijderd';

  @override
  String get trips_detail_stat_avgDepth => 'Gem. diepte';

  @override
  String get trips_detail_stat_maxDepth => 'Max. diepte';

  @override
  String get trips_detail_stat_totalRuntime => 'Totale looptijd';

  @override
  String get trips_detail_stat_totalDives => 'Totaal duiken';

  @override
  String get trips_detail_tab_checklist => 'Checklist';

  @override
  String get trips_detail_tooltip_edit => 'Reis bewerken';

  @override
  String get trips_detail_tooltip_editShort => 'Bewerken';

  @override
  String get trips_detail_tooltip_moreOptions => 'Meer opties';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Bekijk op kaart';

  @override
  String trips_diveScan_addButton(int count) {
    return '$count duiken toevoegen';
  }

  @override
  String trips_diveScan_added(int count) {
    return '$count duiken toegevoegd aan reis';
  }

  @override
  String get trips_diveScan_cancel => 'Annuleren';

  @override
  String trips_diveScan_currentTrip(String tripName) {
    return 'Momenteel in: $tripName';
  }

  @override
  String get trips_diveScan_deselectAll => 'Alles deselecteren';

  @override
  String trips_diveScan_error(String error) {
    return 'Fout bij het zoeken naar duiken: $error';
  }

  @override
  String get trips_diveScan_findButton => 'Zoek overeenkomende duiken';

  @override
  String trips_diveScan_groupOtherTrips(int count) {
    return 'In andere reizen ($count)';
  }

  @override
  String trips_diveScan_groupUnassigned(int count) {
    return 'Niet toegewezen ($count)';
  }

  @override
  String get trips_diveScan_noMatches => 'Geen overeenkomende duiken gevonden';

  @override
  String get trips_diveScan_noDiver =>
      'Selecteer een actieve duiker om naar duiken te zoeken';

  @override
  String get trips_diveScan_selectAll => 'Alles selecteren';

  @override
  String trips_diveScan_subtitle(int count) {
    return '$count duiken gevonden in het datumbereik';
  }

  @override
  String get trips_diveScan_title => 'Duiken toevoegen aan reis';

  @override
  String get trips_diveScan_unknownSite => 'Onbekende duiklocatie';

  @override
  String get trips_edit_appBar_add => 'Reis toevoegen';

  @override
  String get trips_edit_appBar_edit => 'Reis bewerken';

  @override
  String get trips_edit_button_add => 'Reis toevoegen';

  @override
  String get trips_edit_button_cancel => 'Annuleren';

  @override
  String get trips_edit_button_save => 'Opslaan';

  @override
  String get trips_edit_button_update => 'Reis bijwerken';

  @override
  String get trips_edit_dialog_discard => 'Verwerpen';

  @override
  String get trips_edit_dialog_discardContent =>
      'Je hebt niet-opgeslagen wijzigingen. Weet je zeker dat je wilt vertrekken?';

  @override
  String get trips_edit_dialog_discardTitle => 'Wijzigingen verwerpen?';

  @override
  String get trips_edit_dialog_keepEditing => 'Verder bewerken';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days dagen';
  }

  @override
  String get trips_edit_hint_liveaboardName => 'bijv. MY Blue Force One';

  @override
  String get trips_edit_hint_location => 'bijv. Egypte, Rode Zee';

  @override
  String get trips_edit_hint_notes => 'Eventuele extra notities over deze reis';

  @override
  String get trips_edit_hint_resortName => 'bijv. Marsa Shagra';

  @override
  String get trips_edit_hint_tripName => 'bijv. Rode Zee Safari 2024';

  @override
  String get trips_edit_label_endDate => 'Einddatum';

  @override
  String get trips_edit_label_liveaboardName => 'Liveaboard-naam';

  @override
  String get trips_edit_label_location => 'Locatie';

  @override
  String get trips_edit_label_notes => 'Notities';

  @override
  String get trips_edit_label_resortName => 'Resortnaam';

  @override
  String get trips_edit_label_returnFlight => 'Terugvlucht';

  @override
  String get trips_edit_returnFlightClear => 'Terugvlucht wissen';

  @override
  String get trips_edit_returnFlightNotSet => 'Niet ingesteld';

  @override
  String get trips_edit_label_startDate => 'Startdatum';

  @override
  String get trips_edit_label_tripName => 'Reisnaam *';

  @override
  String get trips_edit_sectionTitle_dates => 'Reisdata';

  @override
  String get trips_edit_sectionTitle_location => 'Locatie';

  @override
  String get trips_edit_sectionTitle_notes => 'Notities';

  @override
  String get trips_edit_semanticLabel_save => 'Reis opslaan';

  @override
  String get trips_edit_snackBar_added => 'Reis succesvol toegevoegd';

  @override
  String trips_edit_snackBar_errorLoading(Object error) {
    return 'Fout bij laden van reis: $error';
  }

  @override
  String trips_edit_snackBar_errorSaving(Object error) {
    return 'Fout bij opslaan van reis: $error';
  }

  @override
  String get trips_edit_snackBar_updated => 'Reis succesvol bijgewerkt';

  @override
  String get trips_edit_validation_nameRequired => 'Voer een reisnaam in';

  @override
  String get trips_gallery_accessDenied =>
      'Toegang tot fotobibliotheek geweigerd';

  @override
  String get trips_gallery_addDivesFirst =>
      'Voeg eerst duiken toe om foto\'s te koppelen';

  @override
  String get trips_gallery_appBar_title => 'Reisfoto\'s';

  @override
  String trips_gallery_diveSection_photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto\'s',
      one: 'foto',
    );
    return '$_temp0';
  }

  @override
  String trips_gallery_diveSection_title(Object number, Object site) {
    return 'Duik #$number - $site';
  }

  @override
  String get trips_gallery_empty_subtitle =>
      'Tik op het camerapictogram om je galerij te scannen';

  @override
  String get trips_gallery_empty_title => 'Geen foto\'s in deze reis';

  @override
  String trips_gallery_errorLinking(Object error) {
    return 'Fout bij koppelen van foto\'s: $error';
  }

  @override
  String trips_gallery_errorScanning(Object error) {
    return 'Fout bij scannen: $error';
  }

  @override
  String trips_gallery_error_loading(Object error) {
    return 'Fout bij laden van foto\'s: $error';
  }

  @override
  String trips_gallery_linkedPhotos(Object count) {
    return '$count foto\'s gekoppeld';
  }

  @override
  String get trips_gallery_linkingPhotos => 'Foto\'s koppelen...';

  @override
  String get trips_gallery_tooltip_scan => 'Apparaatgalerij scannen';

  @override
  String get trips_gallery_tripNotFound => 'Reis niet gevonden';

  @override
  String get trips_list_button_retry => 'Opnieuw proberen';

  @override
  String trips_list_countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Over $days dagen',
      one: 'Over 1 dag',
      zero: 'Begint vandaag',
    );
    return '$_temp0';
  }

  @override
  String get trips_list_empty_button => 'Voeg je eerste reis toe';

  @override
  String get trips_list_empty_filtered_subtitle =>
      'Probeer je filters aan te passen of te wissen';

  @override
  String get trips_list_empty_filtered_title =>
      'Geen reizen die aan je filters voldoen';

  @override
  String get trips_list_empty_subtitle =>
      'Maak reizen aan om je duiken per bestemming te groeperen';

  @override
  String get trips_list_empty_title => 'Nog geen reizen toegevoegd';

  @override
  String trips_list_error_loading(Object error) {
    return 'Fout bij laden van reizen: $error';
  }

  @override
  String get trips_list_fab_addTrip => 'Reis toevoegen';

  @override
  String get trips_list_filters_clearAll => 'Alles wissen';

  @override
  String get trips_list_inProgress => 'Bezig';

  @override
  String get trips_list_pastSection => 'Afgelopen reizen';

  @override
  String get trips_list_sort_title => 'Reizen sorteren';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count duiken';
  }

  @override
  String get trips_list_tooltip_addTrip => 'Reis toevoegen';

  @override
  String get trips_list_tooltip_search => 'Reizen zoeken';

  @override
  String get trips_list_tooltip_sort => 'Sorteren';

  @override
  String get trips_list_upcomingSection => 'Binnenkort';

  @override
  String get trips_photos_empty_scanButton => 'Apparaatgalerij scannen';

  @override
  String get trips_photos_empty_title => 'Nog geen foto\'s';

  @override
  String get trips_photos_error_loading => 'Fout bij laden van foto\'s';

  @override
  String trips_photos_moreIndicator(Object count) {
    return '+$count';
  }

  @override
  String trips_photos_moreIndicator_semanticLabel(Object count) {
    return '$count meer foto\'s';
  }

  @override
  String get trips_photos_sectionTitle => 'Foto\'s';

  @override
  String get trips_photos_tooltip_scan => 'Apparaatgalerij scannen';

  @override
  String get trips_photos_viewAll => 'Alles bekijken';

  @override
  String get trips_picker_clearTooltip => 'Selectie wissen';

  @override
  String get trips_picker_empty_createButton => 'Reis aanmaken';

  @override
  String get trips_picker_empty_title => 'Nog geen reizen';

  @override
  String trips_picker_error(Object error) {
    return 'Fout bij laden van reizen: $error';
  }

  @override
  String get trips_picker_hint => 'Tik om een reis te selecteren';

  @override
  String get trips_picker_newTrip => 'Nieuwe reis';

  @override
  String get trips_picker_noSelection => 'Geen reis geselecteerd';

  @override
  String get trips_picker_sheetTitle => 'Reis selecteren';

  @override
  String trips_picker_suggestedPrefix(Object name) {
    return 'Voorgesteld: $name';
  }

  @override
  String get trips_picker_suggestedUse => 'Gebruik';

  @override
  String get trips_search_empty_hint => 'Zoek op naam, locatie of resort';

  @override
  String get trips_search_fieldLabel => 'Reizen zoeken...';

  @override
  String trips_search_noResults(Object query) {
    return 'Geen reizen gevonden voor \"$query\"';
  }

  @override
  String get trips_search_tooltip_back => 'Terug';

  @override
  String get trips_search_tooltip_clear => 'Zoekopdracht wissen';

  @override
  String get trips_summary_header_subtitle =>
      'Selecteer een reis uit de lijst om details te bekijken';

  @override
  String get trips_summary_header_title => 'Reizen';

  @override
  String get trips_summary_overview_title => 'Overzicht';

  @override
  String get trips_summary_quickActions_add => 'Reis toevoegen';

  @override
  String get trips_summary_quickActions_title => 'Snelle acties';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date • $count duiken';
  }

  @override
  String get trips_summary_recentTitle => 'Recente reizen';

  @override
  String get trips_summary_stat_daysDiving => 'Duikdagen';

  @override
  String get trips_summary_stat_liveaboards => 'Liveaboards';

  @override
  String get trips_summary_stat_totalDives => 'Totaal duiken';

  @override
  String get trips_summary_stat_totalTrips => 'Totaal reizen';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date • Over $days dagen';
  }

  @override
  String get trips_summary_upcomingTitle => 'Aankomend';

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
  String get units_sac_pressurePerMin => 'druk/min';

  @override
  String get units_temperature_celsius => 'C';

  @override
  String get units_temperature_fahrenheit => 'F';

  @override
  String get units_timeFormat_twelveHour => '12-uurs';

  @override
  String get units_timeFormat_twentyFourHour => '24-uurs';

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
      'Samenvoegen als extra computer';

  @override
  String get universalImport_action_continue => 'Doorgaan';

  @override
  String get universalImport_action_deselectAll => 'Alles deselecteren';

  @override
  String get universalImport_action_done => 'Gereed';

  @override
  String get universalImport_action_import => 'Importeren';

  @override
  String get universalImport_action_selectAll => 'Alles selecteren';

  @override
  String get universalImport_action_changeFile => 'Bestand wijzigen';

  @override
  String get universalImport_action_selectFile => 'Selecteer bestand';

  @override
  String get universalImport_action_selectFiles => 'Bestanden selecteren';

  @override
  String get universalImport_action_chooseFolder => 'Map kiezen';

  @override
  String get universalImport_triage_title => 'Te importeren bestanden';

  @override
  String universalImport_triage_readyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bestanden klaar voor import',
      one: '1 bestand klaar voor import',
    );
    return '$_temp0';
  }

  @override
  String universalImport_label_filesSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bestanden geselecteerd',
      one: '1 bestand geselecteerd',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_triage_excludedCsv =>
      'Afzonderlijk importeren (CSV)';

  @override
  String get universalImport_triage_unsupported => 'Niet-ondersteund formaat';

  @override
  String get universalImport_triage_parseFailed => 'Kon niet worden gelezen';

  @override
  String universalImport_triage_parsing(int current, int total) {
    return 'Bestand $current van $total wordt verwerkt…';
  }

  @override
  String get universalImport_triage_cancelParsing => 'Annuleren';

  @override
  String get universalImport_triage_allExcluded =>
      'Geen van de geselecteerde bestanden kan samen worden geïmporteerd. CSV-bestanden moeten één voor één worden geïmporteerd.';

  @override
  String get universalImport_triage_noneImportable =>
      'Geen van de geselecteerde bestanden kan worden geïmporteerd.';

  @override
  String get universalImport_review_inBatchDuplicate =>
      'Duplicaat van een andere duik in deze importbatch.';

  @override
  String get universalImport_summary_filesTitle => 'Bestanden';

  @override
  String get universalImport_summary_noticesTitle => 'Niet in het bestand';

  @override
  String get universalImport_summary_noticeNoTankPressureTitle =>
      'Flesdruk niet vastgelegd';

  @override
  String get universalImport_summary_noticeNoTankPressureBody =>
      'Luchtverbruik en SAC kunnen niet worden berekend. Je kunt de begin- en einddruk toevoegen door de duik te bewerken.';

  @override
  String universalImport_summary_noticeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Geldt voor $count duiken',
      one: 'Geldt voor 1 duik',
    );
    return '$_temp0';
  }

  @override
  String universalImport_summary_fileImported(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken geïmporteerd',
      one: '1 duik geïmporteerd',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_summary_fileNeedsIndividualImport =>
      'Afzonderlijke import vereist';

  @override
  String get universalImport_summary_fileUnsupported =>
      'Niet-ondersteund formaat';

  @override
  String get universalImport_summary_fileParseFailed => 'Lezen mislukt';

  @override
  String universalImport_bulk_consolidateMatched(int count) {
    return 'Gematchte consolideren ($count)';
  }

  @override
  String universalImport_bulk_importAll(int count) {
    return 'Alles importeren ($count)';
  }

  @override
  String universalImport_bulk_importAllAsNew(int count) {
    return 'Alles als nieuw importeren ($count)';
  }

  @override
  String universalImport_bulk_skipAll(int count) {
    return 'Alles overslaan ($count)';
  }

  @override
  String universalImport_bulk_replaceSourceAll(int count) {
    return 'Alles vervangen ($count)';
  }

  @override
  String get universalImport_description_supportedFormats =>
      'Selecteer een duiklogboekbestand om te importeren. Ondersteunde formaten zijn CSV, UDDF, Subsurface XML en Garmin FIT.';

  @override
  String get universalImport_dive_decideAction => 'Beslissen';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Dit formaat wordt nog niet ondersteund. Exporteer als UDDF of CSV.';

  @override
  String get universalImport_label_columnMapping => 'Kolomtoewijzing';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped van $total kolommen toegewezen';
  }

  @override
  String get universalImport_label_consolidate => 'Consolideren';

  @override
  String get universalImport_label_detecting => 'Detecteren...';

  @override
  String universalImport_label_diveNumber(Object number) {
    return 'Duik #$number';
  }

  @override
  String get universalImport_label_duplicate => 'Duplicaat';

  @override
  String universalImport_label_duplicatesFound(Object count) {
    return '$count duplicaten gevonden en automatisch gedeselecteerd.';
  }

  @override
  String get universalImport_label_importAsNew => 'Als nieuw importeren';

  @override
  String get universalImport_label_importComplete => 'Import voltooid';

  @override
  String get universalImport_label_importing => 'Importeren';

  @override
  String get universalImport_label_importingEllipsis => 'Importeren...';

  @override
  String universalImport_label_importingProgress(Object current, Object total) {
    return 'Importeren $current van $total';
  }

  @override
  String universalImport_label_percentMatch(Object percent) {
    return '$percent% overeenkomst';
  }

  @override
  String get universalImport_label_possibleMatch => 'Mogelijke overeenkomst';

  @override
  String get universalImport_label_selectCorrectSource =>
      'Niet juist? Selecteer de juiste bron:';

  @override
  String universalImport_label_selected(Object count) {
    return '$count geselecteerd';
  }

  @override
  String get universalImport_label_skip => 'Overslaan';

  @override
  String universalImport_label_taggedAs(Object tag) {
    return 'Getagd als: $tag';
  }

  @override
  String get universalImport_label_unknownDate => 'Onbekende datum';

  @override
  String get universalImport_label_unnamed => 'Naamloos';

  @override
  String universalImport_label_xOfY(Object current, Object total) {
    return '$current van $total';
  }

  @override
  String universalImport_label_xOfYSelected(Object selected, Object total) {
    return '$selected van $total geselecteerd';
  }

  @override
  String get universalImport_entityAction_linkBadge => 'KOPPEL';

  @override
  String get universalImport_entityAction_linkExisting =>
      'Koppelen aan bestaande';

  @override
  String get universalImport_entityAction_linkExistingSubtitle =>
      'Gebruik het overeenkomende record';

  @override
  String get universalImport_entityAction_replaceBadge => 'VERVANGEN';

  @override
  String get universalImport_entityAction_replaceExisting =>
      'Bestaande vervangen';

  @override
  String get universalImport_entityAction_replaceExistingSubtitle =>
      'Overschrijven met geïmporteerde gegevens';

  @override
  String get universalImport_entityAction_skip => 'Overslaan';

  @override
  String get universalImport_entityAction_skipSubtitle =>
      'Deze import verwerpen';

  @override
  String get universalImport_entityAction_importAsNew => 'Als nieuw importeren';

  @override
  String get universalImport_entityAction_importAsNewSubtitle =>
      'Aparte vermelding maken';

  @override
  String get universalImport_pending_chooseAction => 'Kies een actie';

  @override
  String universalImport_pending_gateHint(int count) {
    return '$count duplicaat/duplicaten vereist een beslissing';
  }

  @override
  String get universalImport_pending_needsDecision => 'Beslissing nodig';

  @override
  String get universalImport_pending_reviewAction => 'Bekijken';

  @override
  String get universalImport_rowHint_tapCompareToDecide =>
      'Tik op Beslissen om te kiezen';

  @override
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  ) {
    return '$selected van $total $entityType geselecteerd';
  }

  @override
  String universalImport_semantics_importError(Object error) {
    return 'Importfout: $error';
  }

  @override
  String universalImport_semantics_importProgress(Object percent) {
    return 'Importvoortgang: $percent procent';
  }

  @override
  String universalImport_semantics_itemsSelected(Object count) {
    return '$count items geselecteerd voor import';
  }

  @override
  String get universalImport_semantics_needsDecision =>
      'Vermoedelijk duplicaat, beslissing nodig';

  @override
  String get universalImport_semantics_possibleDuplicate =>
      'Mogelijk duplicaat';

  @override
  String get universalImport_semantics_probableDuplicate =>
      'Waarschijnlijk duplicaat';

  @override
  String universalImport_semantics_sourceDetected(Object description) {
    return 'Bron gedetecteerd: $description';
  }

  @override
  String universalImport_semantics_sourceUncertain(Object description) {
    return 'Bron onzeker: $description';
  }

  @override
  String universalImport_semantics_toggleSelection(Object name) {
    return 'Selectie wisselen voor $name';
  }

  @override
  String universalImport_snackbar_bulkMarkedAs(int count, String action) {
    return '$count gemarkeerd als $action';
  }

  @override
  String universalImport_snackbar_markedAs(String action) {
    return 'Gemarkeerd als $action';
  }

  @override
  String get universalImport_step_import => 'Importeren';

  @override
  String get universalImport_step_map => 'Toewijzen';

  @override
  String get universalImport_step_review => 'Controleren';

  @override
  String get universalImport_step_select => 'Selecteren';

  @override
  String get universalImport_summary_decidesRequired =>
      'Elk vereist een beslissing voor het importeren.';

  @override
  String get universalImport_title => 'Gegevens importeren';

  @override
  String get universalImport_tooltip_closeWizard => 'Importwizard sluiten';

  @override
  String weather_windFromDirection(Object wind, Object direction) {
    return '$wind uit $direction';
  }

  @override
  String get weather_wind_calm => 'windstil';

  @override
  String get weather_wind_highWind => 'harde wind';

  @override
  String get weather_wind_lightBreeze => 'zwakke bries';

  @override
  String get weather_wind_moderateBreeze => 'matige bries';

  @override
  String get weather_wind_strongBreeze => 'krachtige bries';

  @override
  String get weather_wmo_clear => 'Heldere hemel';

  @override
  String get weather_wmo_drizzle => 'Motregen';

  @override
  String get weather_wmo_fog => 'Mist';

  @override
  String get weather_wmo_freezingDrizzle => 'IJzel uit motregen';

  @override
  String get weather_wmo_freezingRain => 'IJzel';

  @override
  String get weather_wmo_mainlyClear => 'Overwegend helder';

  @override
  String get weather_wmo_overcast => 'Bewolkt';

  @override
  String get weather_wmo_partlyCloudy => 'Gedeeltelijk bewolkt';

  @override
  String get weather_wmo_rain => 'Regen';

  @override
  String get weather_wmo_rainShowers => 'Regenbuien';

  @override
  String get weather_wmo_snow => 'Sneeuw';

  @override
  String get weather_wmo_snowGrains => 'Motsneeuw';

  @override
  String get weather_wmo_snowShowers => 'Sneeuwbuien';

  @override
  String get weather_wmo_thunderstorm => 'Onweer';

  @override
  String get weather_wmo_thunderstormHail => 'Onweer met hagel';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return 'Basis ($suitType): $weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return 'Lichaamsgewicht aanpassing: +$adjustment kg';
  }

  @override
  String get weightCalc_suit_drysuit => 'Droogpak';

  @override
  String get weightCalc_suit_none => 'Geen pak';

  @override
  String get weightCalc_suit_rashguard => 'Alleen rashguard';

  @override
  String get weightCalc_suit_semidry => 'Semi-droogpak';

  @override
  String get weightCalc_suit_shorty3mm => '3mm Shorty';

  @override
  String get weightCalc_suit_wetsuit3mm => '3mm Wetsuit';

  @override
  String get weightCalc_suit_wetsuit5mm => '5mm Wetsuit';

  @override
  String get weightCalc_suit_wetsuit7mm => '7mm Wetsuit';

  @override
  String weightCalc_tankLine(Object tankMaterial, Object adjustment) {
    return 'Fles ($tankMaterial): $adjustment kg';
  }

  @override
  String get weightCalc_title => 'Gewichtsberekening:';

  @override
  String weightCalc_total(Object total) {
    return 'Totaal: $total kg';
  }

  @override
  String weightCalc_waterLine(Object waterType, Object adjustment) {
    return 'Water ($waterType): $adjustment kg';
  }

  @override
  String divePlanner_label_resultsWithWarnings(Object count) {
    return 'Resultaten, $count waarschuwingen';
  }

  @override
  String tides_semantic_tideCycle(Object state, Object height) {
    return 'Getijdencyclus, status: $state, hoogte: $height';
  }

  @override
  String get tides_label_agoSuffix => 'geleden';

  @override
  String get tides_label_fromNowSuffix => 'vanaf nu';

  @override
  String get certifications_card_issued => 'UITGEGEVEN';

  @override
  String certifications_certificate_cardNumber(Object number) {
    return 'Kaartnummer: $number';
  }

  @override
  String get certifications_certificate_footer => 'Officieel duikbrevet';

  @override
  String get certifications_certificate_hasCompletedTraining =>
      'heeft de opleiding voltooid als';

  @override
  String certifications_certificate_instructor(Object name) {
    return 'Instructeur: $name';
  }

  @override
  String certifications_certificate_issued(Object date) {
    return 'Uitgegeven: $date';
  }

  @override
  String get certifications_certificate_thisCertifies =>
      'Hierbij wordt verklaard dat';

  @override
  String get diveComputer_connectionType_ble => 'Bluetooth LE';

  @override
  String get diveComputer_connectionType_bluetooth => 'Bluetooth';

  @override
  String get diveComputer_connectionType_infrared => 'Infrarood';

  @override
  String get diveComputer_connectionType_unknown => 'Onbekend';

  @override
  String get diveComputer_connectionType_usb => 'USB';

  @override
  String get diveComputer_connectionType_wifi => 'Wi-Fi';

  @override
  String diveComputer_detail_deleteDialogContent(String name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen? Dit verwijdert geen duiken die van deze computer zijn geimporteerd.';
  }

  @override
  String get diveComputer_detail_deleteDialogTitle => 'Computer verwijderen?';

  @override
  String get diveComputer_detail_divesImported => 'Geimporteerde duiken';

  @override
  String get diveComputer_detail_downloadDivesButton => 'Duiken downloaden';

  @override
  String get diveComputer_detail_editDialogTitle => 'Computer bewerken';

  @override
  String get diveComputer_detail_editNameHint => 'Bijvoorbeeld Mijn Perdix';

  @override
  String get diveComputer_detail_editNotesHint => 'Optionele notities';

  @override
  String get diveComputer_detail_labelConnection => 'Verbinding';

  @override
  String get diveComputer_detail_labelManufacturer => 'Fabrikant';

  @override
  String get diveComputer_detail_labelModel => 'Model';

  @override
  String get diveComputer_detail_labelName => 'Naam';

  @override
  String get diveComputer_detail_lastDownload => 'Laatste download';

  @override
  String get diveComputer_detail_notesTitle => 'Notities';

  @override
  String get diveComputer_detail_reimportAllButton =>
      'Alle duiken opnieuw importeren';

  @override
  String diveComputer_detail_reimportDialogBody(String computerName) {
    return 'Download elke duik van $computerName en vergelijk ze met je logboek. Dit kan enkele minuten duren.';
  }

  @override
  String get diveComputer_detail_reimportDialogTitle =>
      'Alle duiken opnieuw importeren?';

  @override
  String get diveComputer_detail_statisticsTitle => 'Statistieken';

  @override
  String get diveComputer_detail_unknown => 'Onbekend';

  @override
  String get diveComputer_detail_viewDivesButton =>
      'Duiken van deze computer bekijken';

  @override
  String get diveComputer_discovery_chooseDifferentDevice =>
      'Kies een ander apparaat';

  @override
  String get diveComputer_discovery_computer => 'Computer';

  @override
  String get diveComputer_discovery_connectAndDownload =>
      'Verbinden en downloaden';

  @override
  String get diveComputer_discovery_connectingToDevice =>
      'Verbinden met apparaat...';

  @override
  String diveComputer_discovery_deviceNameHint(Object model) {
    return 'bijv. Mijn $model';
  }

  @override
  String get diveComputer_discovery_deviceNameLabel => 'Apparaatnaam';

  @override
  String get diveComputer_discovery_exitDialogCancel => 'Annuleren';

  @override
  String get diveComputer_discovery_exitDialogConfirm => 'Afsluiten';

  @override
  String get diveComputer_discovery_exitDialogContent =>
      'Weet je zeker dat je wilt afsluiten? Je voortgang gaat verloren.';

  @override
  String get diveComputer_discovery_exitDialogTitle => 'Setup afsluiten?';

  @override
  String get diveComputer_discovery_exitTooltip => 'Setup afsluiten';

  @override
  String get diveComputer_discovery_noDeviceSelected =>
      'Geen apparaat geselecteerd';

  @override
  String get diveComputer_discovery_pleaseWaitConnection =>
      'Even geduld terwijl we verbinding maken';

  @override
  String get diveComputer_discovery_recognizedDevice => 'Herkend apparaat';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      'Dit apparaat staat in onze lijst met ondersteunde apparaten. Duiken downloaden zou automatisch moeten werken.';

  @override
  String get diveComputer_discovery_stepConnect => 'Verbinden';

  @override
  String get diveComputer_discovery_stepDone => 'Klaar';

  @override
  String get diveComputer_discovery_stepDownload => 'Downloaden';

  @override
  String get diveComputer_discovery_stepScan => 'Scannen';

  @override
  String get diveComputer_discovery_titleComplete => 'Voltooid';

  @override
  String get diveComputer_discovery_titleConfirmDevice => 'Apparaat bevestigen';

  @override
  String get diveComputer_discovery_titleConnecting => 'Verbinden';

  @override
  String get diveComputer_discovery_titleDownloading => 'Downloaden';

  @override
  String get diveComputer_discovery_titleFindDevice => 'Apparaat zoeken';

  @override
  String get diveComputer_discovery_unknownDevice => 'Onbekend apparaat';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      'Dit apparaat staat niet in onze bibliotheek. We proberen verbinding te maken, maar downloaden werkt mogelijk niet.';

  @override
  String get diveComputer_discovery_usbInstructions =>
      'Sluit uw duikcomputer aan via USB-kabel en selecteer deze hieronder.';

  @override
  String diveComputer_discovery_usbNoResults(String query) {
    return 'Geen apparaten gevonden voor \"$query\"';
  }

  @override
  String get diveComputer_discovery_usbSearchHint =>
      'Zoeken op fabrikant of model...';

  @override
  String get diveComputer_downloadExit_content =>
      'Bij het verlaten wordt de huidige download van je duikcomputer geannuleerd. Zeker weten?';

  @override
  String get diveComputer_downloadExit_leave => 'Verlaten';

  @override
  String get diveComputer_downloadExit_stay => 'Blijven';

  @override
  String get diveComputer_downloadExit_title => 'Download bezig';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... en nog $count meer';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Annuleren';

  @override
  String get diveComputer_downloadStep_cancelled => 'Download geannuleerd';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadAll => 'Alle duiken downloaden';

  @override
  String get diveComputer_downloadStep_downloadFailed => 'Download mislukt';

  @override
  String get diveComputer_downloadStep_downloadNew =>
      'Nieuwe duiken downloaden';

  @override
  String get diveComputer_downloadStep_downloadedDives => 'Gedownloade duiken';

  @override
  String diveComputer_downloadStep_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_downloadStep_errorOccurred =>
      'Er is een fout opgetreden';

  @override
  String diveComputer_downloadStep_errorSemanticLabel(Object error) {
    return 'Downloadfout: $error';
  }

  @override
  String get diveComputer_downloadStep_firstSyncBody =>
      'Je logboek bevat al duiken. Je kunt het downloaden van duiken die je al hebt overslaan.';

  @override
  String get diveComputer_downloadStep_firstSyncTitle =>
      'Eerste download van deze duikcomputer';

  @override
  String diveComputer_downloadStep_onlyAfterDate(String date) {
    return 'Alleen duiken na $date downloaden';
  }

  @override
  String diveComputer_downloadStep_percentAccessibility(Object percent) {
    return ', $percent procent';
  }

  @override
  String get diveComputer_downloadStep_preparing => 'Voorbereiden...';

  @override
  String diveComputer_downloadStep_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String diveComputer_downloadStep_progressSemanticLabel(
    Object status,
    Object percent,
  ) {
    return 'Downloadvoortgang: $status$percent';
  }

  @override
  String get diveComputer_downloadStep_retry => 'Opnieuw proberen';

  @override
  String diveComputer_downloadStep_importPartialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gedownloade duiken importeren',
      one: '1 gedownloade duik importeren',
    );
    return '$_temp0';
  }

  @override
  String get diveComputer_download_cancel => 'Annuleren';

  @override
  String get diveComputer_download_closeTooltip => 'Sluiten';

  @override
  String get diveComputer_download_computerNotFound => 'Computer niet gevonden';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return 'Apparaat niet gevonden. Zorg dat je $name in de buurt is en in overdrachtmodus staat.';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle =>
      'Apparaat niet gevonden';

  @override
  String get diveComputer_download_divesUpdated => 'Duiken bijgewerkt';

  @override
  String get diveComputer_download_done => 'Klaar';

  @override
  String get diveComputer_download_downloadedDives => 'Gedownloade duiken';

  @override
  String get diveComputer_download_duplicatesSkipped =>
      'Duplicaten overgeslagen';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_download_errorOccurred => 'Er is een fout opgetreden';

  @override
  String get diveComputer_download_noSerialPortsFound =>
      'Geen USB-seriële poorten gevonden. Is de duikcomputer aangesloten en ingeschakeld?';

  @override
  String get diveComputer_download_stalePairing =>
      'De Bluetooth-koppeling van deze duikcomputer is verouderd. Vergeet de duikcomputer in de Bluetooth-instellingen van je apparaat en koppel hem daarna opnieuw via het Bluetooth-menu van de duikcomputer.';

  @override
  String get diveComputer_download_discoveryStalled =>
      'Verbonden met de duikcomputer, maar hij reageerde niet meer voordat de download kon beginnen. Meestal betekent dit dat de Bluetooth-koppeling verouderd is: vergeet de duikcomputer in de Bluetooth-instellingen van je apparaat en probeer het opnieuw.';

  @override
  String diveComputer_download_serialConnectFailedWithDetails(Object details) {
    return 'Kan geen verbinding maken met de duikcomputer.\n\nDiagnostische gegevens (deel met ontwikkelaars):\n$details';
  }

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return 'Fout: $error';
  }

  @override
  String get diveComputer_download_goBack => 'Terug';

  @override
  String get diveComputer_download_importFailed => 'Importeren mislukt';

  @override
  String get diveComputer_download_importResults => 'Importresultaten';

  @override
  String get diveComputer_download_importedDives => 'Geimporteerde duiken';

  @override
  String diveComputer_download_importingCountDives(int count) {
    return '$count duiken importeren...';
  }

  @override
  String diveComputer_download_importingCountNewDives(int count) {
    return '$count nieuwe duiken importeren...';
  }

  @override
  String get diveComputer_download_newDivesImported =>
      'Nieuwe duiken geimporteerd';

  @override
  String get diveComputer_download_newDivesOnlySubtitle =>
      'Downloadt alleen duiken die zijn toegevoegd sinds je laatste synchronisatie';

  @override
  String get diveComputer_download_newDivesOnlyTitle =>
      'Alleen nieuwe duiken downloaden';

  @override
  String get diveComputer_download_preparing => 'Voorbereiden...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_reimportHint =>
      'Op zoek naar oudere of verwijderde duiken? Alles opnieuw importeren';

  @override
  String get diveComputer_download_retry => 'Opnieuw proberen';

  @override
  String diveComputer_download_scanError(Object error) {
    return 'Scanfout: $error';
  }

  @override
  String diveComputer_download_searchingForDevice(Object name) {
    return 'Zoeken naar $name...';
  }

  @override
  String get diveComputer_download_searchingInstructions =>
      'Zorg dat het apparaat in de buurt is en in overdrachtmodus staat';

  @override
  String get diveComputer_download_title => 'Duiken downloaden';

  @override
  String get diveComputer_download_tryAgain => 'Opnieuw proberen';

  @override
  String get diveComputer_download_upToDate =>
      'Geen nieuwe duiken gevonden -- je logboek is up-to-date';

  @override
  String get diveComputer_list_addComputer => 'Computer toevoegen';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return 'Duikcomputer: $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count duiken';
  }

  @override
  String get diveComputer_list_downloadTooltip => 'Duiken downloaden';

  @override
  String get diveComputer_list_emptyMessage =>
      'Verbind je duikcomputer om duiken direct in de app te downloaden.';

  @override
  String get diveComputer_list_emptyTitle => 'Geen duikcomputers';

  @override
  String get diveComputer_list_findComputers => 'Computers zoeken';

  @override
  String get diveComputer_list_helpBluetooth =>
      '• Bluetooth LE (de meeste moderne computers)';

  @override
  String get diveComputer_list_helpBluetoothClassic =>
      '• Bluetooth Classic (oudere modellen)';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi en 50+ andere modellen.';

  @override
  String get diveComputer_list_helpBrandsTitle => 'Ondersteunde merken';

  @override
  String get diveComputer_list_helpConnectionsTitle =>
      'Ondersteunde verbindingen';

  @override
  String get diveComputer_list_helpDialogTitle => 'Hulp bij duikcomputers';

  @override
  String get diveComputer_list_helpDismiss => 'Begrepen';

  @override
  String get diveComputer_list_helpTip1 =>
      '• Zorg dat je computer in overdrachtmodus staat';

  @override
  String get diveComputer_list_helpTip2 =>
      '• Houd apparaten dicht bij elkaar tijdens het downloaden';

  @override
  String get diveComputer_list_helpTip3 =>
      '• Zorg dat Bluetooth is ingeschakeld';

  @override
  String get diveComputer_list_helpTipsTitle => 'Tips';

  @override
  String get diveComputer_list_helpTooltip => 'Hulp';

  @override
  String get diveComputer_list_helpUsb => '• USB (alleen desktop)';

  @override
  String get diveComputer_list_loadFailed => 'Laden van duikcomputers mislukt';

  @override
  String get diveComputer_list_retry => 'Opnieuw proberen';

  @override
  String get diveComputer_list_title => 'Duikcomputers';

  @override
  String get diveComputer_pinCode_instructions =>
      'Voer de code in die op je duikcomputer wordt weergegeven.';

  @override
  String get diveComputer_pinCode_label => 'Pincode';

  @override
  String get diveComputer_pinCode_submit => 'Verzenden';

  @override
  String get diveComputer_pinCode_title => 'Pincode vereist';

  @override
  String get diveComputer_pinEntry_connectButton => 'Verbinden';

  @override
  String get diveComputer_pinEntry_helperText =>
      'Voer de 4 tot 6 cijferige pincode in die op je apparaat wordt getoond';

  @override
  String get diveComputer_pinEntry_instructionsGeneric =>
      'Kijk op het scherm van je duikcomputer voor de pincode.';

  @override
  String diveComputer_pinEntry_instructionsWithDevice(String deviceName) {
    return 'Kijk op het scherm van je $deviceName voor de pincode.';
  }

  @override
  String get diveComputer_pinEntry_semanticLabel =>
      'Pincode-invoer, 4 tot 6 cijfers';

  @override
  String get diveComputer_pinEntry_title => 'Pincode invoeren';

  @override
  String diveComputer_scan_bluetoothSemanticLabel(String name) {
    return 'Bluetooth-apparaat: $name';
  }

  @override
  String get diveComputer_scan_emptyStateInstructions =>
      'Zorg ervoor dat je duikcomputer:\n• Is ingeschakeld\n• In Bluetooth-koppelmodus staat\n• In de buurt van je apparaat is';

  @override
  String get diveComputer_scan_knownBadge => 'Bekend';

  @override
  String get diveComputer_scan_lookingForDevicesTitle => 'Apparaten zoeken';

  @override
  String get diveComputer_scan_noUsbDevicesAvailable =>
      'Geen USB-apparaten beschikbaar';

  @override
  String get diveComputer_scan_retry => 'Opnieuw proberen';

  @override
  String get diveComputer_scan_scanAgain => 'Opnieuw zoeken';

  @override
  String get diveComputer_scan_scanningStatus => 'Zoeken naar duikcomputers...';

  @override
  String get diveComputer_scan_stopScanning => 'Zoeken stoppen';

  @override
  String get diveComputer_scan_supportedBadge => 'Ondersteund';

  @override
  String get diveComputer_scan_tabBluetooth => 'Bluetooth';

  @override
  String get diveComputer_scan_tabUsb => 'USB-kabel';

  @override
  String get diveComputer_scan_usbCableLabel => 'USB-kabel';

  @override
  String diveComputer_scan_usbSemanticLabel(String model) {
    return 'USB-apparaat: $model';
  }

  @override
  String get diveComputer_summary_diveComputer => 'duikcomputer';

  @override
  String diveComputer_summary_divesDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return '$count $_temp0 gedownload';
  }

  @override
  String get diveComputer_summary_done => 'Klaar';

  @override
  String get diveComputer_summary_imported => 'Geimporteerd';

  @override
  String diveComputer_summary_semanticLabel(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return '$count $_temp0 gedownload van $name';
  }

  @override
  String get diveComputer_summary_skippedDuplicates =>
      'Overgeslagen (duplicaten)';

  @override
  String get diveComputer_summary_title => 'Download voltooid!';

  @override
  String get diveComputer_summary_updated => 'Bijgewerkt';

  @override
  String get diveComputer_summary_viewDives => 'Duiken bekijken';

  @override
  String get diveImport_alreadyImported => 'Al geimporteerd';

  @override
  String get diveImport_avgHR => 'Gem. HR';

  @override
  String get diveImport_back => 'Terug';

  @override
  String get diveImport_deselectAll => 'Alles deselecteren';

  @override
  String get diveImport_divesImported => 'Duiken geimporteerd';

  @override
  String get diveImport_divesMerged => 'Duiken samengevoegd';

  @override
  String get diveImport_divesSkipped => 'Duiken overgeslagen';

  @override
  String get diveImport_done => 'Klaar';

  @override
  String get diveImport_duration => 'Duur';

  @override
  String get diveImport_error => 'Fout';

  @override
  String get diveImport_fit_closeTooltip => 'FIT-import sluiten';

  @override
  String get diveImport_fit_noDivesDescription =>
      'Selecteer een of meer .fit-bestanden die zijn geexporteerd vanuit Garmin Connect of gekopieerd van een Garmin Descent-apparaat.';

  @override
  String get diveImport_fit_noDivesLoaded => 'Geen duiken geladen';

  @override
  String diveImport_fit_parsed(int diveCount, int fileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'bestanden',
      one: 'bestand',
    );
    return '$diveCount $_temp0 verwerkt uit $fileCount $_temp1';
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
      other: 'duiken',
      one: 'duik',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'bestanden',
      one: 'bestand',
    );
    return '$diveCount $_temp0 verwerkt uit $fileCount $_temp1 ($skippedCount overgeslagen)';
  }

  @override
  String get diveImport_fit_parsing => 'Verwerken...';

  @override
  String get diveImport_fit_selectFiles => 'FIT-bestanden selecteren';

  @override
  String get diveImport_fit_title => 'Importeren vanuit FIT-bestand';

  @override
  String get diveImport_healthkit_accessDescription =>
      'Submersion uses Apple HealthKit to read underwater diving workout data, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get diveImport_healthkit_accessRequired => 'Apple HealthKit';

  @override
  String get diveImport_healthkit_attribution =>
      'Mogelijk gemaakt door Apple HealthKit';

  @override
  String get diveImport_healthkit_closeTooltip => 'Apple Watch-import sluiten';

  @override
  String get diveImport_healthkit_dataUsage =>
      'Leest onderwaterduikactiviteiten uit Apple Health, inclusief diepte, duur, watertemperatuur en hartslag. Deze gegevens worden lokaal opgeslagen in uw duiklogboek en worden nooit gedeeld met derden.';

  @override
  String get diveImport_healthkit_dateFrom => 'Van';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return '$label datumselectie';
  }

  @override
  String get diveImport_healthkit_dateTo => 'Tot';

  @override
  String get diveImport_healthkit_fetchDives => 'Duiken ophalen';

  @override
  String get diveImport_healthkit_fetching => 'Ophalen...';

  @override
  String get diveImport_healthkit_grantAccess => 'Doorgaan';

  @override
  String get diveImport_healthkit_noDivesFound => 'Geen duiken gevonden';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'Geen onderwaterduikactiviteiten gevonden in het geselecteerde datumbereik.';

  @override
  String get diveImport_healthkit_notAvailable => 'Niet beschikbaar';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'Voor importeren vanaf de Apple Watch is een iPhone met de app Gezondheid nodig.';

  @override
  String get diveImport_healthkit_permissionCheckFailed =>
      'Controle van machtigingen mislukt';

  @override
  String get diveImport_healthkit_title => 'Importeren vanuit Apple Watch';

  @override
  String get diveImport_healthkit_watchTitle => 'Importeren vanuit Watch';

  @override
  String get diveImport_import => 'Importeren';

  @override
  String get diveImport_importComplete => 'Import voltooid';

  @override
  String get diveImport_likelyDuplicate => 'Waarschijnlijk duplicaat';

  @override
  String get diveImport_maxDepth => 'Max. diepte';

  @override
  String get diveImport_newDive => 'Nieuwe duik';

  @override
  String get diveImport_next => 'Volgende';

  @override
  String get diveImport_possibleDuplicate => 'Mogelijk duplicaat';

  @override
  String get diveImport_reviewSelectedDives =>
      'Geselecteerde duiken controleren';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: ', $possibleCount mogelijke duplicaten',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: ', $skipCount worden overgeslagen',
      zero: '',
    );
    return '$newCount nieuw$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => 'Alles selecteren';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count geselecteerd';
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
  String get diveImport_step_done => 'Klaar';

  @override
  String get diveImport_step_review => 'Controleren';

  @override
  String get diveImport_step_select => 'Selecteren';

  @override
  String get diveImport_temp => 'Temp';

  @override
  String get diveImport_toggleDiveSelection => 'Duikselectie wisselen';

  @override
  String get diveImport_uddf_buddies => 'Buddy\'s';

  @override
  String get diveImport_uddf_certifications => 'Brevetten';

  @override
  String get diveImport_uddf_closeTooltip => 'UDDF-import sluiten';

  @override
  String get diveImport_uddf_diveCenters => 'Duikcentra';

  @override
  String get diveImport_uddf_diveTypes => 'Duiktypes';

  @override
  String get diveImport_uddf_dives => 'Duiken';

  @override
  String get diveImport_uddf_duplicate => 'Duplicaat';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return '$count duplicaten gevonden en automatisch gedeselecteerd.';
  }

  @override
  String get diveImport_uddf_equipment => 'Uitrusting';

  @override
  String get diveImport_uddf_equipmentSets => 'Uitrustingssets';

  @override
  String diveImport_uddf_importProgress(Object current, Object total) {
    return '$current van $total';
  }

  @override
  String get diveImport_uddf_importing => 'Importeren...';

  @override
  String get diveImport_uddf_likelyDuplicate => 'Waarschijnlijk duplicaat';

  @override
  String get diveImport_uddf_noFileDescription =>
      'Selecteer een .uddf- of .xml-bestand dat is geexporteerd vanuit een andere duiklogapplicatie.';

  @override
  String get diveImport_uddf_noFileSelected => 'Geen bestand geselecteerd';

  @override
  String get diveImport_uddf_parsing => 'Verwerken...';

  @override
  String get diveImport_uddf_possibleDuplicate => 'Mogelijk duplicaat';

  @override
  String get diveImport_uddf_selectFile => 'UDDF-bestand selecteren';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '$selected van $total geselecteerd';
  }

  @override
  String get diveImport_uddf_sites => 'Locaties';

  @override
  String get diveImport_uddf_stepImport => 'Importeren';

  @override
  String get diveImport_uddf_tabBuddies => 'Buddy\'s';

  @override
  String get diveImport_uddf_tabCenters => 'Centra';

  @override
  String get diveImport_uddf_tabCerts => 'Brevetten';

  @override
  String get diveImport_uddf_tabCourses => 'Cursussen';

  @override
  String get diveImport_uddf_tabDives => 'Duiken';

  @override
  String get diveImport_uddf_tabEquipment => 'Uitrusting';

  @override
  String get diveImport_uddf_tabSets => 'Sets';

  @override
  String get diveImport_uddf_tabSites => 'Locaties';

  @override
  String get diveImport_uddf_tabTags => 'Tags';

  @override
  String get diveImport_uddf_tabTrips => 'Reizen';

  @override
  String get diveImport_uddf_tabTypes => 'Types';

  @override
  String get diveImport_uddf_tags => 'Tags';

  @override
  String get diveImport_uddf_media => 'Foto\'s';

  @override
  String get diveImport_uddf_title => 'Importeren vanuit UDDF';

  @override
  String get diveImport_uddf_toggleDiveSelection => 'Duikselectie wisselen';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return 'Selectie wisselen voor $name';
  }

  @override
  String get diveImport_uddf_trips => 'Reizen';

  @override
  String get divePlanner_segmentEditor_addTitle => 'Segment toevoegen';

  @override
  String divePlanner_segmentEditor_ascentRate(Object unit) {
    return 'Stijgsnelheid ($unit/min)';
  }

  @override
  String divePlanner_segmentEditor_descentRate(Object unit) {
    return 'Daalsnelheid ($unit/min)';
  }

  @override
  String get divePlanner_segmentEditor_duration => 'Duur (min)';

  @override
  String get divePlanner_segmentEditor_editTitle => 'Segment bewerken';

  @override
  String divePlanner_segmentEditor_endDepth(Object unit) {
    return 'Einddiepte ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_gasSwitchTime => 'Gaswisseltijd';

  @override
  String get divePlanner_segmentEditor_segmentType => 'Segmenttype';

  @override
  String divePlanner_segmentEditor_startDepth(Object unit) {
    return 'Startdiepte ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_tankGas => 'Fles / Gas';

  @override
  String get divePlanner_segmentList_addSegment => 'Segment toevoegen';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return 'Stijging $startDepth → $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return 'Bodem $depth voor $minutes min';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return 'Deco $depth voor $minutes min';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => 'Segment verwijderen';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return 'Afdaling $startDepth → $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => 'Segment bewerken';

  @override
  String get divePlanner_segmentList_emptyMessage =>
      'Voeg handmatig segmenten toe of maak een snelplan';

  @override
  String get divePlanner_segmentList_emptyTitle => 'Nog geen segmenten';

  @override
  String divePlanner_segmentList_gasSwitch(Object gasName) {
    return 'Gaswissel naar $gasName';
  }

  @override
  String get divePlanner_segmentList_quickPlan => 'Snelplan';

  @override
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes) {
    return 'Veiligheidsstop $depth voor $minutes min';
  }

  @override
  String get divePlanner_segmentList_title => 'Duiksegmenten';

  @override
  String get divePlanner_segmentType_ascent => 'Stijging';

  @override
  String get divePlanner_segmentType_bottomTime => 'Bodemtijd';

  @override
  String get divePlanner_segmentType_decoStop => 'Decostop';

  @override
  String get divePlanner_segmentType_descent => 'Afdaling';

  @override
  String get divePlanner_segmentType_gasSwitch => 'Gaswissel';

  @override
  String get divePlanner_segmentType_safetyStop => 'Veiligheidsstop';

  @override
  String get divePlanner_undo => 'Ongedaan maken';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'Rock bottom is de minimale gasreserve voor een noodopstijging terwijl je lucht deelt met je buddy.\n\n• Gebruikt verhoogde RMV-waarden (2-3x normaal)\n• Gaat ervan uit dat beide duikers op een fles zitten\n• Inclusief veiligheidsstop indien ingeschakeld\n\nKeer de duik altijd om VOOR je rock bottom bereikt!';

  @override
  String get gasCalculators_rockBottom_aboutTitle => 'Over Rock Bottom';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired =>
      'Benodigd gas voor opstijging';

  @override
  String get gasCalculators_rockBottom_ascentRate => 'Stijgsnelheid';

  @override
  String gasCalculators_rockBottom_ascentTimeToDepth(
    Object depth,
    Object unit,
  ) {
    return 'Stijgtijd naar $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_ascentTimeToSurface =>
      'Stijgtijd naar oppervlak';

  @override
  String get gasCalculators_rockBottom_buddySac => 'RMV buddy';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'Gecombineerde stress-RMV';

  @override
  String get gasCalculators_rockBottom_emergencyAscentBreakdown =>
      'Noodopstijging uitsplitsing';

  @override
  String get gasCalculators_rockBottom_emergencyScenario => 'Noodscenario';

  @override
  String get gasCalculators_rockBottom_includeSafetyStop =>
      'Veiligheidsstop meenemen';

  @override
  String get gasCalculators_rockBottom_maximumDepth => 'Maximale diepte';

  @override
  String get gasCalculators_rockBottom_minimumReserve => 'Minimale reserve';

  @override
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  ) {
    return 'Minimale reserve: $pressure $pressureUnit, $volume $volumeUnit. Keer de duik om bij $pressure $pressureUnit resterend';
  }

  @override
  String gasCalculators_rockBottom_safetyStopDuration(
    Object depth,
    Object unit,
  ) {
    return '3 minuten op $depth$unit';
  }

  @override
  String gasCalculators_rockBottom_safetyStopGas(Object depth, Object unit) {
    return 'Gas veiligheidsstop (3 min @ $depth$unit)';
  }

  @override
  String get gasCalculators_rockBottom_stressedSacHint =>
      'Gebruik een hogere RMV om rekening te houden met stress tijdens een noodsituatie';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'Stress-RMV';

  @override
  String get gasCalculators_rockBottom_tankSize => 'Flesgrootte';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded =>
      'Totale benodigde reserve';

  @override
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  ) {
    return 'Keer de duik om bij $pressure $pressureUnit resterend';
  }

  @override
  String get gasCalculators_rockBottom_yourSac => 'Jouw RMV';

  @override
  String get gpsLogger_androidNotificationText =>
      'Je oppervlaktetrack wordt opgenomen';

  @override
  String get gpsLogger_androidNotificationTitle => 'Submersion GPS-logger';

  @override
  String get gpsLogger_deleteTrackMessage =>
      'Verwijdert de opgenomen GPS-track. Posities die al aan duiken zijn toegekend blijven behouden.';

  @override
  String get gpsLogger_deleteTrackTitle => 'Track verwijderen?';

  @override
  String get gpsLogger_interruptedNotice =>
      'Een eerdere opname is onderbroken. De track is opgeslagen.';

  @override
  String gpsLogger_lastFix(String age, String accuracy) {
    return 'Laatste fix $age geleden ($accuracy)';
  }

  @override
  String get gpsLogger_locationOff => 'Locatievoorzieningen staan uit.';

  @override
  String get gpsLogger_matchButton => 'Duiken koppelen aan GPS-logs';

  @override
  String gpsLogger_matchResult(int count) {
    return '$count duiken gepositioneerd';
  }

  @override
  String get gpsLogger_matchResultNone =>
      'Geen duiken komen overeen met een opgenomen track';

  @override
  String get gpsLogger_noFixYet => 'Wachten op GPS-fix';

  @override
  String get gpsLogger_noTracks => 'Nog geen GPS-tracks opgenomen';

  @override
  String get gpsLogger_permissionDenied =>
      'Locatietoestemming is vereist om een GPS-track op te nemen. Schakel deze in bij de systeeminstellingen.';

  @override
  String gpsLogger_recordingStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punten',
      one: '$count punt',
    );
    return 'Opname - $_temp0';
  }

  @override
  String get gpsLogger_reviewSites => 'Duikstek-koppelingen controleren';

  @override
  String get gpsLogger_startButton => 'Opname starten';

  @override
  String get gpsLogger_stopButton => 'Opname stoppen';

  @override
  String gpsLogger_stripStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punten',
      one: '$count punt',
    );
    return 'GPS-track wordt opgenomen · $_temp0';
  }

  @override
  String get gpsLogger_summary_tracks => 'Tracks';

  @override
  String get gpsLogger_summary_recordedTime => 'Opgenomen tijd';

  @override
  String get gpsLogger_summary_divesCovered => 'Gedekte duiken';

  @override
  String gpsLogger_trackSubtitle(num count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punten',
      one: '$count punt',
    );
    return '$_temp0, $duration';
  }

  @override
  String gpsLogger_trackSubtitleTrimmed(String duration) {
    return 'Bijgesneden, $duration';
  }

  @override
  String get gpsLogger_tracksHeader => 'Opgenomen tracks';

  @override
  String get gpsTrack_action_trim => 'Bijsnijden...';

  @override
  String get gpsTrack_action_split => 'Splitsen...';

  @override
  String get gpsTrack_action_resetTrim => 'Bijsnijden ongedaan maken';

  @override
  String get gpsTrack_edit_applyTrim => 'Bijsnijden toepassen';

  @override
  String get gpsTrack_edit_confirmSplit => 'Hier splitsen';

  @override
  String get gpsTrack_edit_splitWarning =>
      'Splitsen maakt twee tracks en verwijdert het origineel. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get gpsTrack_edit_cancel => 'Annuleren';

  @override
  String get gpsTrack_import_action => 'Track importeren...';

  @override
  String get gpsTrack_import_reviewTitle => 'Import controleren';

  @override
  String get gpsTrack_import_timezone => 'Opgenomen in';

  @override
  String get gpsTrack_import_timezoneHint =>
      'De tijden in het bestand zijn UTC. Stel de zone in waarin de track is opgenomen zodat die aansluit op je duiken.';

  @override
  String get gpsTrack_import_duplicate =>
      'Dit lijkt een duplicaat van een bestaande track.';

  @override
  String get gpsTrack_import_confirm => 'Importeren';

  @override
  String get gpsTrack_import_csvMapping => 'Kolommen koppelen';

  @override
  String get gpsTrack_import_firstFix => 'Eerste punt';

  @override
  String gpsTrack_import_fixCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punten',
      one: '1 punt',
    );
    return '$_temp0';
  }

  @override
  String gpsTrack_import_failed(String reason) {
    return 'Kan dat bestand niet lezen: $reason';
  }

  @override
  String get gpsTrack_importError_unsupportedFormat =>
      'Dit bestandstype wordt niet ondersteund. Importeer een GPX-, KML-, CSV- of FIT-bestand.';

  @override
  String get gpsTrack_importError_unreadable =>
      'Dit bestand kon niet worden gelezen. Het is mogelijk beschadigd of onvolledig.';

  @override
  String get gpsTrack_importError_noPositions =>
      'Dit bestand bevat geen GPS-posities met tijdstempel.';

  @override
  String get gpsTrack_importError_badData =>
      'Dit bestand bevat een positie of tijdstempel die deze app niet kan lezen.';

  @override
  String get gpsTrack_export_saved => 'Track opgeslagen';

  @override
  String get gpsTrack_action_export => 'Exporteren';

  @override
  String get gpsTrack_action_shareGpx => 'Delen als GPX';

  @override
  String get gpsTrack_action_saveGpx => 'Opslaan als GPX...';

  @override
  String get gpsTrack_action_shareKml => 'Delen als KML';

  @override
  String get gpsTrack_action_saveKml => 'Opslaan als KML...';

  @override
  String get gpsTrack_export_failed => 'Exporteren mislukt.';

  @override
  String get gpsTrack_map_title => 'Trackkaart';

  @override
  String gpsTrack_map_truncated(int count) {
    return 'De $count meest recente tracks worden getoond. Verfijn het datumfilter om andere te zien.';
  }

  @override
  String get gpsTrack_map_noTracks => 'Geen opgenomen tracks om te tonen.';

  @override
  String get gpsTrack_map_showMap => 'Kaart tonen';

  @override
  String get gpsTrack_filter_all => 'Alle datums';

  @override
  String get gpsTrack_filter_clear => 'Datumfilter wissen';

  @override
  String get gpsTrack_inspect_speed => 'Snelheid';

  @override
  String get gpsTrack_inspect_accuracy => 'Nauwkeurigheid';

  @override
  String get gpsTrack_stats_distance => 'Afstand';

  @override
  String get gpsTrack_stats_duration => 'Duur';

  @override
  String get gpsTrack_stats_avgSpeed => 'Gem. snelheid';

  @override
  String get gpsTrack_stats_maxSpeed => 'Max. snelheid';

  @override
  String get gpsTrack_stats_fixes => 'Punten';

  @override
  String get gpsTrack_stats_dives => 'Duiken';

  @override
  String get gpsTrack_colorMode_uniform => 'Effen';

  @override
  String get gpsTrack_colorMode_speed => 'Snelheid';

  @override
  String get gpsTrack_colorMode_elapsed => 'Tijd';

  @override
  String get gpsTrack_legend_slower => 'Langzamer';

  @override
  String get gpsTrack_legend_faster => 'Sneller';

  @override
  String get gpsTrack_legend_start => 'Start';

  @override
  String get gpsTrack_legend_end => 'Einde';

  @override
  String get gpsTrack_detail_title => 'GPS-track';

  @override
  String get gpsTrack_detail_notFound => 'Deze track is niet meer beschikbaar.';

  @override
  String get gpsTrack_detail_unreadable =>
      'Trackgegevens konden niet worden gelezen.';

  @override
  String get gpsTrack_detail_noPoints =>
      'Deze track bevat geen opgenomen posities.';

  @override
  String get maps_compass_resetLabel =>
      'Kaartoriëntatie terugzetten naar het noorden';

  @override
  String get maps_compass_resetTooltip => 'Noorden boven';

  @override
  String get maps_heatMap_hide => 'Heatmap verbergen';

  @override
  String get maps_heatMap_overlayOff => 'Heatmap-overlay is uit';

  @override
  String get maps_depthOverlay_show => 'Diepte-overlay tonen';

  @override
  String get maps_depthOverlay_hide => 'Diepte-overlay verbergen';

  @override
  String get maps_heatMap_overlayOn => 'Heatmap-overlay is aan';

  @override
  String get maps_heatMap_show => 'Heatmap tonen';

  @override
  String get maps_offline_bounds => 'Grenzen';

  @override
  String maps_offline_cacheHitRateAccessibility(Object rate) {
    return 'Cache-hitpercentage: $rate procent';
  }

  @override
  String get maps_offline_cacheHits => 'Cache-hits';

  @override
  String get maps_offline_cacheMisses => 'Cache-misses';

  @override
  String get maps_offline_cacheStatistics => 'Cachestatistieken';

  @override
  String get maps_offline_cancelDownload => 'Download annuleren';

  @override
  String get maps_offline_clearAll => 'Alles wissen';

  @override
  String get maps_offline_clearAllCache => 'Alle cache wissen';

  @override
  String get maps_offline_clearAllCacheMessage =>
      'Alle gedownloade kaartregio\'s en gecachte tegels verwijderen?';

  @override
  String get maps_offline_clearAllCacheTitle => 'Alle cache wissen?';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return 'Dit verwijdert $count tegels ($size).';
  }

  @override
  String get maps_offline_created => 'Aangemaakt';

  @override
  String maps_offline_deleteRegion(Object name) {
    return 'Regio $name verwijderen';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return '\"$name\" en de $count gecachte tegels verwijderen?\n\nDit maakt $size opslagruimte vrij.';
  }

  @override
  String get maps_offline_deleteRegionTitle => 'Regio verwijderen?';

  @override
  String get maps_offline_downloadNewRegion => 'Nieuwe regio downloaden';

  @override
  String get maps_offline_downloadedRegions => 'Gedownloade regio\'s';

  @override
  String maps_offline_downloading(Object regionName) {
    return 'Downloaden: $regionName';
  }

  @override
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  ) {
    return '$regionName downloaden, $percent procent voltooid, $downloaded van $total tegels';
  }

  @override
  String maps_offline_error(Object error) {
    return 'Fout: $error';
  }

  @override
  String maps_offline_errorLoadingStats(Object error) {
    return 'Fout bij laden statistieken: $error';
  }

  @override
  String maps_offline_failedTiles(Object count) {
    return '$count mislukt';
  }

  @override
  String maps_offline_hitRate(Object rate) {
    return 'Hitpercentage: $rate%';
  }

  @override
  String get maps_offline_lastAccessed => 'Laatst geopend';

  @override
  String get maps_offline_noRegions => 'Geen offline regio\'s';

  @override
  String get maps_offline_noRegionsDescription =>
      'Download kaartregio\'s vanuit de locatiedetailpagina om kaarten offline te gebruiken.';

  @override
  String get maps_offline_refresh => 'Vernieuwen';

  @override
  String get maps_offline_region => 'Regio';

  @override
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size | $count tegels | Zoom $minZoom-$maxZoom';
  }

  @override
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size, $count tegels, zoom $minZoom tot $maxZoom';
  }

  @override
  String get maps_offline_size => 'Grootte';

  @override
  String get maps_offline_tiles => 'Tegels';

  @override
  String maps_offline_tilesPerSecond(Object rate) {
    return '$rate tegels/sec';
  }

  @override
  String maps_offline_tilesProgress(Object downloaded, Object total) {
    return '$downloaded / $total tegels';
  }

  @override
  String get maps_offline_title => 'Offline kaarten';

  @override
  String get maps_offline_zoomRange => 'Zoombereik';

  @override
  String get maps_regionSelector_dragToAdjust =>
      'Sleep om selectie aan te passen';

  @override
  String get maps_regionSelector_dragToSelect =>
      'Sleep op de kaart om een regio te selecteren';

  @override
  String get maps_regionSelector_selectRegion => 'Selecteer regio op kaart';

  @override
  String get maps_regionSelector_selectRegionButton => 'Selecteer regio';

  @override
  String get tankPresets_addPreset => 'Flesinstelling toevoegen';

  @override
  String get tankPresets_builtInPresets => 'Standaard instellingen';

  @override
  String get tankPresets_currentDefault => 'Huidige standaard';

  @override
  String get tankPresets_customPresets => 'Eigen instellingen';

  @override
  String get tankPresets_defaultSettings => 'Standaardfles';

  @override
  String get tankPresets_defaultSettings_description =>
      'De met ster gemarkeerde preset wordt gebruikt als standaardfles bij het registreren van nieuwe duiken.';

  @override
  String tankPresets_deleteDefaultMessage(String name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen? Dit is je huidige standaard flessenpreset en wordt teruggezet naar AL80.';
  }

  @override
  String tankPresets_deleteMessage(Object name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen?';
  }

  @override
  String get tankPresets_deletePreset => 'Instelling verwijderen';

  @override
  String get tankPresets_deleteTitle => 'Flesinstelling verwijderen?';

  @override
  String tankPresets_deleted(Object name) {
    return '\"$name\" verwijderd';
  }

  @override
  String get tankPresets_editPreset => 'Instelling bewerken';

  @override
  String tankPresets_edit_created(Object name) {
    return '\"$name\" aangemaakt';
  }

  @override
  String get tankPresets_edit_descriptionHint =>
      'bijv. Mijn huurcilinder van de duikshop';

  @override
  String get tankPresets_edit_descriptionOptional => 'Beschrijving (optioneel)';

  @override
  String tankPresets_edit_errorLoading(Object error) {
    return 'Fout bij laden instelling: $error';
  }

  @override
  String tankPresets_edit_errorSaving(Object error) {
    return 'Fout bij opslaan instelling: $error';
  }

  @override
  String tankPresets_edit_gasCapacity(Object capacity) {
    return '• Gascapaciteit: $capacity cuft';
  }

  @override
  String get tankPresets_edit_material => 'Materiaal';

  @override
  String get tankPresets_edit_name => 'Naam';

  @override
  String get tankPresets_edit_nameHelper =>
      'Een herkenbare naam voor deze flesinstelling';

  @override
  String get tankPresets_edit_nameHint => 'bijv. Mijn AL80';

  @override
  String get tankPresets_edit_nameRequired => 'Voer een naam in';

  @override
  String get tankPresets_edit_ratedPressure => 'Nominale druk';

  @override
  String get tankPresets_edit_required => 'Verplicht';

  @override
  String get tankPresets_edit_tankSpecifications => 'Flesspecificaties';

  @override
  String get tankPresets_edit_title => 'Flesinstelling bewerken';

  @override
  String tankPresets_edit_updated(Object name) {
    return '\"$name\" bijgewerkt';
  }

  @override
  String get tankPresets_edit_validPressure => 'Voer een geldige druk in';

  @override
  String get tankPresets_edit_validVolume => 'Voer een geldig volume in';

  @override
  String get tankPresets_edit_volume => 'Volume';

  @override
  String get tankPresets_edit_volumeHelperCuft => 'Gascapaciteit (cuft)';

  @override
  String get tankPresets_edit_volumeHelperLiters => 'Watervolume (L)';

  @override
  String tankPresets_edit_waterVolume(Object volume) {
    return '• Watervolume: $volume L';
  }

  @override
  String get tankPresets_edit_workingPressure => 'Werkdruk';

  @override
  String tankPresets_edit_workingPressureBar(Object pressure) {
    return '• Werkdruk: $pressure bar';
  }

  @override
  String tankPresets_error(Object error) {
    return 'Fout: $error';
  }

  @override
  String tankPresets_errorDeleting(Object error) {
    return 'Fout bij verwijderen instelling: $error';
  }

  @override
  String get tankPresets_applyToImports =>
      'Ook toepassen op geïmporteerde duiken';

  @override
  String get tankPresets_applyToImports_subtitle =>
      'Ontbrekende flesgegevens bij geïmporteerde duiken aanvullen met de standaardpreset';

  @override
  String get tankPresets_new_title => 'Nieuwe flesinstelling';

  @override
  String get tankPresets_noPresets => 'Geen flesinstellingen beschikbaar';

  @override
  String get tankPresets_setAsDefault => 'Als standaard instellen';

  @override
  String get tankPresets_title => 'Flesinstellingen';

  @override
  String get tools_gpsLogger_description =>
      'Registreer je positie tijdens een duikdag en koppel geïmporteerde duiken automatisch aan GPS-locaties.';

  @override
  String get tools_gpsLogger_subtitle => 'Neem een oppervlaktetrack op';

  @override
  String get tools_gpsLogger_title => 'GPS-logger';

  @override
  String get tools_weight_aluminumImperial =>
      'Meer drijvend wanneer leeg (+4 lbs)';

  @override
  String get tools_weight_aluminumMetric =>
      'Meer drijvend wanneer leeg (+2 kg)';

  @override
  String get tools_weight_bodyWeightOptional => 'Lichaamsgewicht (optioneel)';

  @override
  String get tools_weight_carbonFiberImperial => 'Zeer drijvend (+7 lbs)';

  @override
  String get tools_weight_carbonFiberMetric => 'Zeer drijvend (+3 kg)';

  @override
  String get tools_weight_disclaimer =>
      'Dit is slechts een schatting. Voer altijd een drijfproef uit aan het begin van je duik en pas aan waar nodig. Factoren zoals trimvest, persoonlijke drijfkracht en adempatronen beinvloeden je werkelijke gewichtsbehoefte.';

  @override
  String get tools_weight_exposureSuit => 'Duikpak';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return '• Gascapaciteit: $capacity cuft';
  }

  @override
  String get tools_weight_helperImperial =>
      'Voegt ~2 lbs toe per 22 lbs boven 154 lbs';

  @override
  String get tools_weight_helperMetric =>
      'Voegt ~1 kg toe per 10 kg boven 70 kg';

  @override
  String get tools_weight_notSpecified => 'Niet opgegeven';

  @override
  String get tools_weight_recommendedWeight => 'Aanbevolen gewicht';

  @override
  String tools_weight_resultAccessibility(Object weight, Object unit) {
    return 'Aanbevolen gewicht: $weight $unit';
  }

  @override
  String get tools_weight_steelImperial => 'Negatief drijvend (-4 lbs)';

  @override
  String get tools_weight_steelMetric => 'Negatief drijvend (-2 kg)';

  @override
  String get tools_weight_tankMaterial => 'Flesmateriaal';

  @override
  String get tools_weight_tankSpecifications => 'Flesspecificaties';

  @override
  String get tools_weight_title => 'Gewichtscalculator';

  @override
  String get tools_weight_waterType => 'Watertype';

  @override
  String tools_weight_waterVolume(Object volume) {
    return '• Watervolume: $volume L';
  }

  @override
  String tools_weight_workingPressure(Object pressure) {
    return '• Werkdruk: $pressure bar';
  }

  @override
  String get tools_weight_yourWeight => 'Jouw gewicht';

  @override
  String get settings_section_dataSources_title => 'Data Sources';

  @override
  String get settings_section_dataSources_subtitle =>
      'Connected services & integrations';

  @override
  String get settings_siteMatch_title => 'Automatisch stekken koppelen';

  @override
  String get settings_siteMatch_subtitle =>
      'Hoe agressief gedownloade duiken aan stekken worden gekoppeld';

  @override
  String get settings_siteMatch_strict => 'Strikt';

  @override
  String get settings_siteMatch_balanced => 'Gebalanceerd';

  @override
  String get settings_siteMatch_relaxed => 'Soepel';

  @override
  String get settings_dataSources_header => 'Data Sources';

  @override
  String get settings_dataSources_appleHealth_title => 'Apple Health';

  @override
  String get settings_dataSources_appleHealth_subtitle =>
      'Onderwaterduikgegevens';

  @override
  String get settings_dataSources_appleHealth_description =>
      'Submersion reads underwater diving workout data from Apple Health, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get settings_dataSources_appleHealth_dataTypesHeader =>
      'Gegevens gelezen uit HealthKit';

  @override
  String get settings_dataSources_appleHealth_dataTypeWorkouts =>
      'Onderwaterduiktrainingen - starttijd, duur en activiteitsgegevens van de duik';

  @override
  String get settings_dataSources_appleHealth_dataTypeHeartRate =>
      'Hartslag - hartslagmetingen vastgelegd tijdens duiken';

  @override
  String get settings_dataSources_appleHealth_permissionGranted =>
      'HealthKit-toegang verleend';

  @override
  String get settings_dataSources_appleHealth_permissionNotGranted =>
      'HealthKit-toegang niet verleend';

  @override
  String get settings_dataSources_appleHealth_permissionChecking =>
      'HealthKit-toegang controleren...';

  @override
  String get settings_dataSources_appleHealth_importAction =>
      'Import from Apple Watch';

  @override
  String get settings_dataSources_appleHealth_privacy =>
      'Your health data is stored locally and is never shared with third parties.';

  @override
  String get settings_dataSources_appleHealth_poweredBy =>
      'Mogelijk gemaakt door Apple HealthKit';

  @override
  String get settings_dataSources_noSources =>
      'No data source integrations are available on this platform.';

  @override
  String get diveLog_edit_section_environment => 'Omgeving';

  @override
  String get diveLog_edit_subsection_autofill => 'Automatisch invullen';

  @override
  String get diveLog_edit_subsection_weather => 'Weer';

  @override
  String get diveLog_edit_subsection_diveConditions => 'Duikomstandigheden';

  @override
  String get diveLog_edit_label_windSpeed => 'Windsnelheid';

  @override
  String get diveLog_edit_label_windDirection => 'Windrichting';

  @override
  String get diveLog_edit_label_cloudCover => 'Bewolking';

  @override
  String get diveLog_edit_label_precipitation => 'Neerslag';

  @override
  String get diveLog_edit_label_humidity => 'Luchtvochtigheid';

  @override
  String get diveLog_edit_label_weatherDescription => 'Weerbeschrijving';

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
  String get diveLog_detail_section_environment => 'Omgeving';

  @override
  String get diveLog_detail_subsection_weather => 'Weer';

  @override
  String get diveLog_detail_subsection_diveConditions => 'Duikomstandigheden';

  @override
  String get diveLog_detail_label_windSpeed => 'Windsnelheid';

  @override
  String get diveLog_detail_label_windDirection => 'Windrichting';

  @override
  String get diveLog_detail_label_cloudCover => 'Bewolking';

  @override
  String get diveLog_detail_label_precipitation => 'Neerslag';

  @override
  String get diveLog_detail_label_humidity => 'Luchtvochtigheid';

  @override
  String get diveLog_detail_label_weatherDescription => 'Beschrijving';

  @override
  String get diveLog_detail_weatherSourceOpenMeteo => 'via Open-Meteo';

  @override
  String get dropTarget_title => 'Sleep om te importeren';

  @override
  String get dropTarget_subtitle => 'Laat los om de importwizard te openen';

  @override
  String get dropTarget_error_unsupportedFile =>
      'Niet-ondersteund bestandstype';

  @override
  String get dropTarget_error_wizardActive => 'Voltooi eerst de huidige import';

  @override
  String get dropTarget_error_readFailed => 'Kan bestand niet lezen';

  @override
  String get enum_cloudCover_clear => 'Helder';

  @override
  String get enum_cloudCover_partlyCloudy => 'Gedeeltelijk bewolkt';

  @override
  String get enum_cloudCover_mostlyCloudy => 'Overwegend bewolkt';

  @override
  String get enum_cloudCover_overcast => 'Zwaar bewolkt';

  @override
  String get enum_precipitation_none => 'Geen';

  @override
  String get enum_precipitation_drizzle => 'Motregen';

  @override
  String get enum_precipitation_lightRain => 'Lichte regen';

  @override
  String get enum_precipitation_rain => 'Regen';

  @override
  String get enum_precipitation_heavyRain => 'Zware regen';

  @override
  String get enum_precipitation_snow => 'Sneeuw';

  @override
  String get enum_precipitation_sleet => 'Natte sneeuw';

  @override
  String get enum_precipitation_hail => 'Hagel';

  @override
  String get columnConfig_title => 'Duikdetails lijstvelden';

  @override
  String get columnConfig_viewMode => 'Weergavemodus';

  @override
  String get columnConfig_visibleColumns => 'Zichtbare kolommen';

  @override
  String get columnConfig_availableFields => 'Beschikbare velden';

  @override
  String get columnConfig_extraFields => 'Extra velden';

  @override
  String get columnConfig_extraFields_description =>
      'Weergegeven onder de hoofdinhoud van de kaart';

  @override
  String get columnConfig_slotAssignments => 'Slottoewijzingen';

  @override
  String get columnConfig_resetToDefault => 'Standaardwaarden herstellen';

  @override
  String get columnConfig_preset => 'Voorinstelling';

  @override
  String get columnConfig_presetSaveAs => 'Opslaan als';

  @override
  String get columnConfig_presetName => 'Naam voorinstelling';

  @override
  String get columnConfig_presetNameHint => 'bijv. Technisch duiken';

  @override
  String get columnConfig_presetSave => 'Opslaan';

  @override
  String get columnConfig_presetCancel => 'Annuleren';

  @override
  String get columnConfig_columns => 'Kolommen';

  @override
  String get columnConfig_done => 'Gereed';

  @override
  String get settings_appearance_columnConfig => 'Duikdetails lijstvelden';

  @override
  String get settings_appearance_columnConfig_subtitle =>
      'Velden in duiklijstweergaven aanpassen';

  @override
  String get diveField_category_core => 'Kern';

  @override
  String get diveField_category_environment => 'Omgeving';

  @override
  String get diveField_category_gas => 'Gas';

  @override
  String get diveField_category_tank => 'Fles';

  @override
  String get diveField_category_weight => 'Gewicht';

  @override
  String get diveField_category_equipment => 'Uitrusting';

  @override
  String get diveField_category_deco => 'Decompressie';

  @override
  String get diveField_category_physiology => 'Fysiologie';

  @override
  String get diveField_category_rebreather => 'Rebreather';

  @override
  String get diveField_category_people => 'Personen';

  @override
  String get diveField_category_location => 'Locatie';

  @override
  String get diveField_category_trip => 'Reis';

  @override
  String get diveField_category_rating => 'Beoordeling';

  @override
  String get diveField_category_metadata => 'Metadata';

  @override
  String get listViewMode_table => 'Tabel';

  @override
  String get settings_appearance_general => 'Algemeen';

  @override
  String get settings_appearance_sections => 'Secties';

  @override
  String get settings_appearance_colorAccents => 'Kleuraccenten';

  @override
  String get settings_appearance_accentNavIcons =>
      'Gekleurde navigatiepictogrammen';

  @override
  String get settings_appearance_accentNavIcons_subtitle =>
      'Pictogrammen in het hoofdmenu kleuren met de kleur van elk onderdeel';

  @override
  String get settings_appearance_accentSectionHeaders =>
      'Gekleurde sectiekoppen';

  @override
  String get settings_appearance_accentSectionHeaders_subtitle =>
      'Een gekleurd sectiepictogram naast paginatitels tonen';

  @override
  String get settings_appearance_accentListIcons =>
      'Gekleurde lijstpictogrammen';

  @override
  String get settings_appearance_accentListIcons_subtitle =>
      'Pictogrammen in lijsten en instellingenpagina\'s kleuren';

  @override
  String get settings_appearance_showDetailsPane => 'Detailvenster tonen';

  @override
  String get settings_appearance_showDetailsPane_subtitle =>
      'Detailvenster naast de tabel weergeven';

  @override
  String get settings_appearance_showProfilePanel =>
      'Profielpaneel tonen in tabelweergave';

  @override
  String get settings_appearance_showProfilePanel_subtitle =>
      'Duikprofielgrafiek standaard boven de tabel weergeven';

  @override
  String get settings_appearance_mapStyle => 'Kaartstijl';

  @override
  String get settings_appearance_mapStyle_openStreetMap => 'Stratenkaart';

  @override
  String get settings_appearance_mapStyle_openTopoMap => 'Topografisch';

  @override
  String get settings_appearance_mapStyle_esriSatellite => 'Satelliet';

  @override
  String get common_action_reparse => 'Opnieuw verwerken';

  @override
  String get diveComputer_detail_reparseAllButton =>
      'Alle duiken opnieuw verwerken';

  @override
  String get diveComputer_detail_reparseAllTitle =>
      'Alle duiken opnieuw verwerken';

  @override
  String diveComputer_detail_reparseAllMessage(int count) {
    return 'Voer de duikparser opnieuw uit voor $count duiken met opgeslagen ruwe data. Dit werkt profiel- en sensordata bij, maar behoudt je notities, locaties, buddy\'s en andere wijzigingen.';
  }

  @override
  String diveComputer_detail_reparseAllProgress(int count) {
    return '$count duiken worden opnieuw verwerkt...';
  }

  @override
  String diveComputer_detail_reparseAllSuccess(int count) {
    return '$count duiken succesvol opnieuw verwerkt';
  }

  @override
  String diveComputer_detail_reparseAllPartial(
    int succeeded,
    int total,
    int failed,
  ) {
    return '$succeeded van $total duiken opnieuw verwerkt. $failed mislukt.';
  }

  @override
  String diveComputer_detail_reparseRawDataCount(int count) {
    return '$count duiken met ruwe data';
  }

  @override
  String diveComputer_detail_reparseRawDataCountWithout(
    int count,
    int without,
  ) {
    return '$count duiken met ruwe data ($without zonder)';
  }

  @override
  String get diveLog_detail_menu_reparseRawData =>
      'Ruwe data opnieuw verwerken';

  @override
  String get diveLog_detail_reparseSuccess => 'Duik succesvol opnieuw verwerkt';

  @override
  String get diveLog_detail_reparseProfilePreserved =>
      'Brongegevens vernieuwd. Deze duik is samengevoegd uit andere duiken, dus het profiel is ongewijzigd gebleven.';

  @override
  String diveLog_detail_reparseFailed(String error) {
    return 'Opnieuw verwerken mislukt: $error';
  }

  @override
  String get universalImport_label_replaceSource => 'Bron vervangen';

  @override
  String get universalImport_label_replaceSourceSubtitle =>
      'Bijwerken vanaf dezelfde computer';

  @override
  String get universalImport_title_importOptions => 'Importopties';

  @override
  String get universalImport_label_options => 'Opties';

  @override
  String get universalImport_label_retainDiveNumbers =>
      'Duiknummers van bron behouden';

  @override
  String get universalImport_label_retainDiveNumbersSubtitle =>
      'Gebruik de duiknummers uit het geïmporteerde bestand in plaats van automatisch toewijzen';

  @override
  String get universalImport_title_successImported => 'Succesvol geïmporteerd';

  @override
  String get universalImport_title_successUpdated => 'Succesvol bijgewerkt';

  @override
  String get universalImport_title_successConsolidated =>
      'Succesvol geconsolideerd';

  @override
  String get universalImport_title_noDivesImported =>
      'Geen duiken geïmporteerd';

  @override
  String get universalImport_label_allDivesSkipped =>
      'Alle duiken zijn overgeslagen.';

  @override
  String get universalImport_label_replacedSourceData =>
      'Brongegevens vervangen';

  @override
  String get universalImport_label_consolidated => 'Geconsolideerd';

  @override
  String get universalImport_label_photosAttached => 'Foto\'s bijgevoegd';

  @override
  String get universalImport_label_photosUnmatched =>
      'Foto\'s niet aan een duik gekoppeld';

  @override
  String get common_label_shareWithAllProfiles =>
      'Delen met alle duikersprofielen';

  @override
  String get settings_shareByDefault_title =>
      'Nieuwe sites en trips standaard delen';

  @override
  String get settings_shareAllSites_title => 'Al mijn sites delen';

  @override
  String get settings_shareAllTrips_title => 'Al mijn trips delen';

  @override
  String settings_shareAllSites_confirm(int count) {
    return 'Al je $count sites zichtbaar maken voor elk duikersprofiel in deze app? Je kunt individuele sites later ontdelen.';
  }

  @override
  String settings_shareAllTrips_confirm(int count) {
    return 'Al je $count trips zichtbaar maken voor elk duikersprofiel in deze app? Je kunt individuele trips later ontdelen.';
  }

  @override
  String settings_shareAllSites_snackbar(int count) {
    return '$count sites gedeeld met alle duikersprofielen.';
  }

  @override
  String settings_shareAllTrips_snackbar(int count) {
    return '$count trips gedeeld met alle duikersprofielen.';
  }

  @override
  String get settings_shareAll_noneToShare => 'Niets om te delen.';

  @override
  String get settings_sharedData_sectionTitle => 'Gedeelde gegevens';

  @override
  String get settings_sharedData_sectionSubtitle =>
      'Sites en trips delen tussen profielen';

  @override
  String get common_action_unshare => 'Delen opheffen';

  @override
  String get trips_unshareConfirm_title => 'Deze trip ontdelen?';

  @override
  String trips_unshareConfirm_body(String name) {
    return 'Hiermee wordt ‘$name’ uit de weergaven van andere duikersprofielen verwijderd. Je kunt het later weer delen.';
  }

  @override
  String get sites_unshareConfirm_title => 'Deze site ontdelen?';

  @override
  String sites_unshareConfirm_body(String name) {
    return 'Hiermee wordt ‘$name’ uit de weergaven van andere duikersprofielen verwijderd. Je kunt het later weer delen.';
  }

  @override
  String get trips_deleteShared_title => 'Gedeelde trip verwijderen?';

  @override
  String trips_deleteShared_body(String name) {
    return '‘$name’ wordt gedeeld met andere duikersprofielen. Hier verwijderen haalt het voor iedereen weg.';
  }

  @override
  String get sites_deleteShared_title => 'Gedeelde site verwijderen?';

  @override
  String sites_deleteShared_body(String name) {
    return '‘$name’ wordt gedeeld met andere duikersprofielen. Hier verwijderen haalt het voor iedereen weg.';
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
    return 'Duiker verwijderd. $trips gedeelde $_temp0 en $sites gedeelde $_temp1 toegewezen aan $name.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_title =>
      'Dubbele duikersprofielen';

  @override
  String get settings_cloudSync_duplicateDivers_description =>
      'De synchronisatie vond meer dan één profiel met dezelfde naam. Dit gebeurt gewoonlijk wanneer elk apparaat zijn eigen profiel heeft aangemaakt vóór de synchronisatie. Door samen te voegen worden alle duiken en gegevens naar één profiel verplaatst.';

  @override
  String settings_cloudSync_duplicateDivers_groupLabel(String name, int count) {
    return '$name ($count profielen)';
  }

  @override
  String get settings_cloudSync_duplicateDivers_mergeButton => 'Samenvoegen';

  @override
  String get settings_cloudSync_duplicateDivers_confirmTitle =>
      'Duikersprofielen samenvoegen?';

  @override
  String settings_cloudSync_duplicateDivers_confirmBody(
    int count,
    String name,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dubbele profielen',
      one: 'één dubbel profiel',
    );
    return 'Alle duiken, certificeringen, uitrusting en andere gegevens van $_temp0 worden verplaatst naar \"$name\". Dit kan niet automatisch ongedaan worden gemaakt.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_confirmCancel => 'Annuleren';

  @override
  String get settings_cloudSync_duplicateDivers_confirmAction => 'Samenvoegen';

  @override
  String settings_cloudSync_duplicateDivers_successSnack(String name) {
    return 'Samengevoegd in $name';
  }

  @override
  String settings_cloudSync_duplicateDivers_failureSnack(String error) {
    return 'Samenvoegen mislukt: $error';
  }

  @override
  String get settings_cloudSync_duplicateDivers_undo => 'Ongedaan maken';

  @override
  String get divers_edit_priorExperienceSection => 'Eerdere Ervaring';

  @override
  String get divers_edit_priorExperienceHelp =>
      'Duiken en tijd van voordat je begon te loggen in Submersion.';

  @override
  String get divers_edit_priorDivesLabel => 'Eerdere duiken';

  @override
  String get divers_edit_priorHoursLabel => 'Eerdere uren';

  @override
  String get divers_edit_priorMinutesLabel => 'Minuten';

  @override
  String get divers_edit_divingSinceLabel => 'Duikt sinds';

  @override
  String get divers_edit_divingSinceNotSet => 'Niet ingesteld';

  @override
  String get divers_edit_clearDivingSinceTooltip => 'Duikt sinds wissen';

  @override
  String get divers_edit_priorInvalidNumber => 'Voer een geldig getal in';

  @override
  String statistics_priorBreakdown(String logged, String prior) {
    return '$logged gelogd + $prior eerder';
  }

  @override
  String statistics_divingSince(int year) {
    return 'Duikt sinds $year';
  }

  @override
  String get db_location_choose_volume => 'Opslaglocatie kiezen';

  @override
  String get db_location_internal => 'Interne opslag';

  @override
  String get db_location_sd_card => 'SD-kaart';

  @override
  String get db_location_external_note =>
      'Bestanden hier worden verwijderd als je de app verwijdert.';

  @override
  String get db_location_backup_note =>
      'Android kan de database niet vanuit een cloudgesynchroniseerde map draaien. Stel een Back-uplocatie in onder Back-up en Herstel om een kopie in Dropbox, Nextcloud of Google Drive te bewaren.';

  @override
  String diveLog_bulkEdit_membership_onAll(int count) {
    return 'op alle $count';
  }

  @override
  String diveLog_bulkEdit_membership_onSome(int count, int total) {
    return 'op $count van $total';
  }

  @override
  String diveLog_bulkEdit_membership_adding(int total) {
    return 'toevoegen aan alle $total';
  }

  @override
  String get diveLog_bulkEdit_membership_removing => 'verwijderen van alle';

  @override
  String get diveLog_bulkEdit_membership_empty =>
      'Nog geen items bij de geselecteerde duiken';

  @override
  String get settings_mediaStorage_entry_title => 'Mediaopslag';

  @override
  String get settings_mediaStorage_entry_subtitle =>
      'Bewaar originele foto\'s en video\'s in je eigen cloudopslag';

  @override
  String get settings_mediaStorage_status_notConfigured =>
      'Geen mediaopslag verbonden op dit apparaat';

  @override
  String settings_mediaStorage_status_connected(String hint) {
    return 'Verbonden met $hint';
  }

  @override
  String get settings_mediaStorage_test_success => 'Verbinding geslaagd';

  @override
  String get settings_mediaStorage_saved => 'Mediaopslag verbonden';

  @override
  String get settings_mediaStorage_action_disconnect => 'Loskoppelen';

  @override
  String get settings_mediaStorage_disconnect_confirm_title =>
      'Mediaopslag loskoppelen?';

  @override
  String get settings_mediaStorage_disconnect_confirm_body =>
      'Dit apparaat stopt met het uploaden en ophalen van media. Er wordt niets uit je bucket verwijderd.';

  @override
  String get settings_mediaStorage_action_copyFromSync =>
      'Instellingen van Sync kopiëren';

  @override
  String get settings_mediaStorage_transfers_title => 'Overdrachten';

  @override
  String get settings_mediaStorage_transfers_entry => 'Overdrachten bekijken';

  @override
  String get settings_mediaStorage_transfers_empty => 'Geen overdrachten';

  @override
  String get settings_mediaStorage_transfers_retry => 'Opnieuw proberen';

  @override
  String get settings_mediaStorage_transfers_clearCompleted =>
      'Voltooide wissen';

  @override
  String get settings_mediaStorage_transfers_state_pending => 'Wachten';

  @override
  String get settings_mediaStorage_transfers_state_transferring => 'Uploaden';

  @override
  String get settings_mediaStorage_transfers_state_deleting =>
      'Verwijderen uit de cloud';

  @override
  String get settings_mediaStorage_transfers_state_done => 'Klaar';

  @override
  String get settings_mediaStorage_transfers_state_failed => 'Mislukt';

  @override
  String settings_mediaStorage_transfers_queued(int count) {
    return '$count in wachtrij';
  }

  @override
  String settings_mediaStorage_transfers_waitingRetry(int count) {
    return '$count wachten op nieuwe poging';
  }

  @override
  String get settings_mediaStorage_verify_action => 'Bibliotheek verifiëren';

  @override
  String get settings_mediaStorage_verify_running =>
      'Mediabibliotheek wordt geverifieerd...';

  @override
  String settings_mediaStorage_verify_summary(
    int checked,
    int removed,
    int repaired,
    int aborted,
  ) {
    return '$checked objecten gecontroleerd: $removed wezen verwijderd, $repaired reparaties in wachtrij, $aborted verouderde uploads afgebroken';
  }

  @override
  String get settings_mediaStorage_backfill_action =>
      'Bestaande bibliotheek uploaden';

  @override
  String settings_mediaStorage_backfill_enqueued(int count) {
    return '$count uploads in wachtrij';
  }

  @override
  String get settings_mediaStorage_policy_autoUpload =>
      'Foto\'s automatisch uploaden';

  @override
  String get settings_mediaStorage_policy_photosOnCellular =>
      'Foto\'s uploaden via mobiel';

  @override
  String get settings_mediaStorage_provider_label => 'Provider';

  @override
  String get settings_mediaStorage_connect_dropbox_hint =>
      'Gebruikt je Dropbox-koppeling uit Cloud Sync. Media wordt opgeslagen in je Dropbox-appmap.';

  @override
  String get settings_mediaStorage_connect_gdrive_hint =>
      'Meldt aan met Google. Media wordt opgeslagen in de privé-Drive-ruimte van deze app.';

  @override
  String get settings_mediaStorage_connect_icloud_hint =>
      'Media wordt opgeslagen in de iCloud-container van deze app en synchroniseert via je Apple ID.';

  @override
  String settings_mediaStorage_connect_action(String provider) {
    return '$provider verbinden';
  }

  @override
  String get bodyWeight_addEntry => 'Meting toevoegen';

  @override
  String get bodyWeight_dateLabel => 'Datum';

  @override
  String get bodyWeight_deleteTooltip => 'Item verwijderen';

  @override
  String get bodyWeight_heightLabel => 'Lengte (cm)';

  @override
  String get bodyWeight_heightFeetLabel => 'Lengte (ft)';

  @override
  String get bodyWeight_heightInchesLabel => 'Inches';

  @override
  String bodyWeight_weightLabel(String unit) {
    return 'Gewicht ($unit)';
  }

  @override
  String diveLog_edit_weightFeedback_amount(String unit) {
    return 'Met ongeveer hoeveel ($unit)';
  }

  @override
  String get diveLog_edit_weightFeedback_correct => 'Voelde goed';

  @override
  String get diveLog_edit_weightFeedback_label => 'Hoe was je lood?';

  @override
  String get diveLog_edit_weightFeedback_over => 'Te zwaar';

  @override
  String get diveLog_edit_weightFeedback_under => 'Te licht';

  @override
  String get diverProfile_bodyWeight_empty => 'Niet vastgelegd';

  @override
  String get diverProfile_bodyWeight_title => 'Lichaamsgewicht';

  @override
  String get equipment_edit_advanced_title => 'Geavanceerd';

  @override
  String get equipment_edit_buoyancyHint_exposure =>
      'Positief: hoeveel het drijft';

  @override
  String get equipment_edit_buoyancyHint_generic => 'Negatief als het zinkt';

  @override
  String get equipment_edit_buoyancyHint_tank =>
      'Leeg laten - flessen gebruiken hun eigen specificaties';

  @override
  String equipment_edit_buoyancyLabel(String unit) {
    return 'Drijfvermogen ($unit)';
  }

  @override
  String equipment_edit_dryWeightLabel(String unit) {
    return 'Drooggewicht ($unit)';
  }

  @override
  String equipment_edit_liftCapacityLabel(String unit) {
    return 'Liftcapaciteit ($unit)';
  }

  @override
  String get equipment_edit_liftCapacityHint =>
      'Nominale liftkracht van wing of trimvest';

  @override
  String get planner_gearWeights_accept => 'Gebruik als gepland lood';

  @override
  String get planner_gearWeights_addGear => 'Uitrusting toevoegen';

  @override
  String get planner_gearWeights_empty =>
      'Voeg uitrusting toe om je lood te voorspellen';

  @override
  String planner_gearWeights_planned(String weight) {
    return 'Gepland: $weight';
  }

  @override
  String planner_gearWeights_predicted(String weight) {
    return 'Voorspeld: $weight';
  }

  @override
  String get planner_gearWeights_title => 'Uitrusting en lood';

  @override
  String get planner_gearWeights_useSet => 'Set gebruiken';

  @override
  String get tools_weight_addGear => 'Uitrusting toevoegen';

  @override
  String get tools_weight_addTank => 'Fles toevoegen';

  @override
  String tools_weight_basedOnDives(int count) {
    return 'Gebaseerd op $count gelogde duiken';
  }

  @override
  String get tools_weight_breakdownTitle => 'Hoe dit is berekend';

  @override
  String get tools_weight_confidence_high => 'Hoge betrouwbaarheid';

  @override
  String get tools_weight_confidence_low => 'Lage betrouwbaarheid - schatting';

  @override
  String get tools_weight_confidence_medium => 'Gemiddelde betrouwbaarheid';

  @override
  String tools_weight_deltaVsPrevious(String delta) {
    return '$delta t.o.v. vorige uitrusting';
  }

  @override
  String get tools_weight_noGear =>
      'Voeg de uitrusting toe waarmee je gaat duiken om de voorspelling te personaliseren.';

  @override
  String get tools_weight_personalTerm => 'Persoonlijke basis';

  @override
  String get tools_weight_placementTitle => 'Voorgestelde verdeling';

  @override
  String get tools_weight_predictedWeight => 'Voorspeld lood';

  @override
  String get tools_weight_saveToProfile => 'Gewicht opslaan in profiel';

  @override
  String get tools_weight_source_measured => 'gemeten uit je duiken';

  @override
  String get tools_weight_source_physics => 'fysica';

  @override
  String get tools_weight_source_typeDefault => 'standaardschatting';

  @override
  String get tools_weight_source_userSpec => 'uit je uitrustingsspecificaties';

  @override
  String get tools_weight_tanks => 'Flessen';

  @override
  String get tools_weight_useSet => 'Set gebruiken';

  @override
  String get tools_weight_waterTerm => 'Watertype';

  @override
  String get dive3d_previewTitle => '3D-weergave';

  @override
  String get dive3d_previewHint => 'Tik om in 3D te verkennen';

  @override
  String get dive3d_resetView => 'Weergave herstellen';

  @override
  String get dive3d_zoomIn => 'Inzoomen';

  @override
  String get dive3d_zoomOut => 'Uitzoomen';

  @override
  String get dive3d_play => 'Afspelen';

  @override
  String get dive3d_pause => 'Pauzeren';

  @override
  String get dive3d_overlays => 'Overlays';

  @override
  String get dive3d_overlay_strata => 'Temperatuurlagen';

  @override
  String get dive3d_overlay_ceiling => 'Decoplafond';

  @override
  String get dive3d_overlay_curtain => 'Dieptegordijn';

  @override
  String get dive3d_overlay_markers => 'Markeringen';

  @override
  String get dive3d_seascape_overlay_paths => 'Duikroutes';

  @override
  String get dive3d_seascape_overlay_contours => 'Dieptelijnen';

  @override
  String get dive3d_seascape_overlay_walls => 'Steile wanden';

  @override
  String get dive3d_overlay_water => 'Wateroppervlak';

  @override
  String get dive3d_seascape_legend_land => 'Land';

  @override
  String get dive3d_seascape_appearance => 'Terreinweergave';

  @override
  String get dive3d_seascape_chartView => 'Kaartweergave';

  @override
  String get dive3d_seascape_orbitView => '3D-weergave';

  @override
  String get dive3d_seascape_appearance_surface => 'Terreinoppervlak';

  @override
  String get dive3d_seascape_appearance_surfaceDepth => 'Dieptekleuren';

  @override
  String get dive3d_seascape_appearance_surfaceImagery => 'Kaartbeelden';

  @override
  String get dive3d_seascape_appearance_surfaceBlend => 'Mengeling';

  @override
  String get siteFeature_type_wreck => 'Wrak';

  @override
  String get siteFeature_type_mooring => 'Meerboei';

  @override
  String get siteFeature_type_entry => 'Instappunt';

  @override
  String get siteFeature_type_exit => 'Uitstappunt';

  @override
  String get siteFeature_type_swimThrough => 'Doorzwemplek';

  @override
  String get siteFeature_type_hazard => 'Gevaar';

  @override
  String get siteFeature_type_current => 'Stroming';

  @override
  String get siteFeature_sectionTitle => 'Kenmerken';

  @override
  String get siteFeature_addAction => 'Kenmerk toevoegen';

  @override
  String get siteFeature_placeHint =>
      'Tik op de kaart om het kenmerk te plaatsen';

  @override
  String get siteFeature_addTitle => 'Kenmerk toevoegen';

  @override
  String get siteFeature_editTitle => 'Kenmerk bewerken';

  @override
  String get siteFeature_field_name => 'Naam';

  @override
  String get siteFeature_field_bearing => 'Peiling (°)';

  @override
  String get siteFeature_field_depth => 'Diepte';

  @override
  String get siteFeature_field_notes => 'Notities';

  @override
  String get siteFeature_deleteAction => 'Verwijderen';

  @override
  String siteFeature_deleteConfirm(String name) {
    return '$name verwijderen?';
  }

  @override
  String get siteScape_mode2d => 'Kaart';

  @override
  String get siteScape_mode3d => '3D';

  @override
  String get dive3d_seascape_appearance_rampRange =>
      'Kleurdieptebereik beperken';

  @override
  String get dive3d_seascape_appearance_rampMax => 'Donkerste kleur op';

  @override
  String get dive3d_seascape_appearance_banded => 'Gradiënt in banden';

  @override
  String get dive3d_seascape_appearance_contours => 'Dieptelijnniveaus';

  @override
  String get dive3d_seascape_appearance_contourAuto => 'Automatisch';

  @override
  String get dive3d_seascape_appearance_contourCustom => 'Aangepast';

  @override
  String get dive3d_seascape_appearance_addLevel => 'Niveau toevoegen';

  @override
  String get dive3d_seascape_appearance_defaultColor => 'Standaard';

  @override
  String get dive3d_seascape_appearance_wallAngle => 'Steile-wandhoek';

  @override
  String get dive3d_seascape_appearance_wallAngleNote =>
      'Bathymetriecellen middelen de helling binnenin, echte wanden ogen dus vlakker. Blijf ruim onder 45 graden.';

  @override
  String get dive3d_seascape_siteTitle => 'Zeelandschap van de duikstek';

  @override
  String dive3d_seascape_seafloorSource(String source, String resolution) {
    return 'Zeebodem: $source (~$resolution m)';
  }

  @override
  String get dive3d_seascape_noCoordinates =>
      'Deze duikstek heeft geen gps-coördinaten';

  @override
  String get dive3d_seascape_noData =>
      'Geen bathymetrie beschikbaar voor deze locatie';

  @override
  String dive3d_seascape_axis_distance(String unitSymbol) {
    return 'Afstand ($unitSymbol)';
  }

  @override
  String get settings_about_bathymetryCredit =>
      'Bathymetriegegevens: GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022';

  @override
  String get dive3d_metric_depth => 'Diepte';

  @override
  String get dive3d_metric_temperature => 'Temp';

  @override
  String get dive3d_metric_ascentRate => 'Opstijging';

  @override
  String get dive3d_metric_ppO2 => 'ppO2';

  @override
  String get dive3d_metric_cns => 'CZS';

  @override
  String get dive3d_metric_heartRate => 'HS';

  @override
  String get dive3d_metric_tankPressure => 'Druk';

  @override
  String get dive3d_zAxis => 'Z-as';

  @override
  String get dive3d_zAxis_none => 'Geen';

  @override
  String get dive3d_overlay_shadows => 'Wandschaduwen';

  @override
  String get dive3d_metric_tts => 'TTS';

  @override
  String dive3d_axis_depth(String unitSymbol) {
    return 'Diepte ($unitSymbol)';
  }

  @override
  String get dive3d_axis_time => 'Duiktijd (min)';

  @override
  String get dive3d_pose_menu => 'Camera';

  @override
  String get dive3d_pose_default => 'Standaardweergave';

  @override
  String get dive3d_pose_front => 'Voor (diepte vs. tijd)';

  @override
  String get dive3d_pose_side => 'Zijkant (diepte vs. meetwaarde)';

  @override
  String get dive3d_pose_top => 'Boven (meetwaarde vs. tijd)';

  @override
  String get dive3d_readout_runTime => 'Duiktijd';

  @override
  String get dive3d_readout_ceiling => 'Plafond';

  @override
  String dive3d_readout_tank(int n) {
    return 'Fles $n';
  }

  @override
  String get dive3d_scene_dive => 'Duik';

  @override
  String get dive3d_scene_tissue => 'Weefsels';

  @override
  String get dive3d_tissue_gasCombined => 'Gecombineerd';

  @override
  String get dive3d_tissue_gasN2 => 'N2';

  @override
  String get dive3d_tissue_gasHe => 'He';

  @override
  String get dive3d_tissue_colorMValue => '% M-waarde';

  @override
  String get dive3d_tissue_colorAbsolute => 'Belasting';

  @override
  String get dive3d_tissue_controlling => 'Leidend';

  @override
  String get dive3d_tissue_surfaceInterval => 'Oppervlakte-interval';

  @override
  String get dive3d_career_title => '3D-geschiedenis';

  @override
  String get dive3d_career_colorRecency => 'Recentheid';

  @override
  String get dive3d_career_colorDepth => 'Diepte';

  @override
  String get dive3d_career_empty => 'Geen duiken met profielen';

  @override
  String get dive3d_spatial_title => '3D-zeegezicht';

  @override
  String get dive3d_spatial_estimatedPath => 'Geschat pad (gegist bestek)';

  @override
  String get dive3d_spatial_synthesizedSeafloor => 'Gesynthetiseerde zeebodem';

  @override
  String get dive3d_spatial_noPath =>
      'Onvoldoende gegevens om het pad te reconstrueren';

  @override
  String get dive3d_tissue_legendHeight =>
      'Hoogte & kleur: % van de M-waardelimiet';

  @override
  String get dive3d_tissue_legendLimit => 'Rood vlak = decolimiet';

  @override
  String get dive3d_tissue_legendAxes =>
      'Links→rechts: tijd · Voor→achter: snelle→trage weefsels';

  @override
  String get dive3d_tissue_legendDepth => 'Blauwe curve: je diepte';

  @override
  String get dive3d_tissue_onGassing => 'Opzadeling';

  @override
  String get dive3d_tissue_offGassing => 'Ontzadeling';

  @override
  String dive3d_tissue_tooltipCompartment(int number) {
    return 'Comp. $number';
  }

  @override
  String dive3d_tissue_tooltipHalfTime(int minutes) {
    return '$minutes min N2';
  }

  @override
  String dive3d_tissue_tooltipSaturation(int percent) {
    return 'Verzadiging $percent%';
  }

  @override
  String dive3d_tissue_tooltipProgress(int percent) {
    return '$percent% van de duik';
  }

  @override
  String get dive3d_tissue_stateEquilibrium => 'Evenwicht';

  @override
  String get dive3d_tissue_statePastMValue => 'Boven M-waarde';

  @override
  String get dive3d_tissue_axisTime => 'Tijd';

  @override
  String get dive3d_tissue_axisSaturation => 'Verzadiging %';

  @override
  String get dive3d_tissue_axisCompartment => 'Compartiment';

  @override
  String get dive3d_compare_computers_title => 'Computers vergelijken';

  @override
  String get dive3d_compare_dives_title => 'Duiken vergelijken';

  @override
  String get dive3d_scene_computers => 'Computers';

  @override
  String get dive3d_compare_layout_sideBySide => 'Naast elkaar';

  @override
  String get dive3d_compare_layout_overlay => 'Over elkaar';

  @override
  String get dive3d_compare_empty =>
      'Minstens 2 profielen met dieptegegevens nodig om te vergelijken';

  @override
  String dive3d_compare_showing(Object shown, Object total) {
    return '$shown van $total weergegeven';
  }

  @override
  String get dive3d_compare_setReference => 'Als referentie instellen';

  @override
  String get diveLog_selection_tooltip_compare3d => 'Vergelijken in 3D';

  @override
  String get diveLog_sources_compareIn3d => 'Vergelijken in 3D';

  @override
  String get settings_setup_pendingTitle =>
      'Voltooi het instellen van dit apparaat';

  @override
  String settings_setup_mediaStoreAttach(String hint) {
    return 'Mediaopslag koppelen ($hint)';
  }

  @override
  String settings_setup_accountSignIn(String label) {
    return 'Aanmelden bij $label';
  }

  @override
  String get settings_setup_dismiss => 'Negeren';

  @override
  String get settings_photosMedia_title => 'Foto\'s en media';

  @override
  String get settings_photosMedia_subtitle => 'Bronnen, opslag en accounts';

  @override
  String get settings_photosMedia_sourcesHeader => 'Waar foto\'s vandaan komen';

  @override
  String get settings_photosMedia_storageHeader =>
      'Waar kopieën worden bewaard';

  @override
  String get settings_photosMedia_accountsHeader => 'Accounts';

  @override
  String get settings_photosMedia_displayHeader => 'Weergave';

  @override
  String get settings_photosMedia_guidedSetup => 'Begeleide installatie';

  @override
  String get settings_photosMedia_photoSources_title =>
      'Fotobibliotheek en bronnen';

  @override
  String get settings_photosMedia_photoSources_subtitle =>
      'Galerij, bestanden en importopties';

  @override
  String get settings_photosMedia_networkSources_title => 'Netwerkbronnen';

  @override
  String get settings_photosMedia_networkSources_subtitle =>
      'URL’s en manifest-feeds (geavanceerd)';

  @override
  String get settings_connectedAccounts_title => 'Gekoppelde accounts';

  @override
  String get settings_connectedAccounts_subtitle =>
      'Cloud- en service-aanmeldingen';

  @override
  String get settings_connectedAccounts_empty => 'Nog geen accounts gekoppeld';

  @override
  String get settings_connectedAccounts_status_signedIn => 'Aangemeld';

  @override
  String get settings_connectedAccounts_status_needsSignIn =>
      'Aanmelden vereist';

  @override
  String get settings_connectedAccounts_status_unavailable =>
      'Niet beschikbaar op dit apparaat';

  @override
  String get settings_connectedAccounts_disconnectDevice =>
      'Afmelden op dit apparaat';

  @override
  String get settings_connectedAccounts_removeFromLibrary =>
      'Uit bibliotheek verwijderen';

  @override
  String get settings_connectedAccounts_removeConfirmTitle =>
      'Account verwijderen?';

  @override
  String get settings_connectedAccounts_removeConfirmBody =>
      'Het account wordt van elk gesynchroniseerd apparaat verwijderd. Op andere apparaten opgeslagen inloggegevens worden niet gewist.';

  @override
  String get settings_setupGuide_title => 'Foto\'s en media instellen';

  @override
  String get settings_setupGuide_intro =>
      'Koppel waar je foto\'s vandaan komen en waar kopieën worden bewaard. Je kunt dit altijd opnieuw uitvoeren.';

  @override
  String get settings_setupGuide_stepSources => 'Fotobronnen';

  @override
  String get settings_setupGuide_stepSources_desc =>
      'Voeg foto\'s toe uit je fotobibliotheek, bestanden of Lightroom.';

  @override
  String get settings_setupGuide_stepStorage => 'Mediaopslag';

  @override
  String get settings_setupGuide_stepStorage_desc =>
      'Bewaar kopieën van je foto\'s in je eigen cloud zodat elk apparaat ze kan tonen.';

  @override
  String get settings_setupGuide_stepSync => 'Cloudsynchronisatie';

  @override
  String get settings_setupGuide_stepSync_desc =>
      'Synchroniseer duikgegevens tussen apparaten.';

  @override
  String get settings_setupGuide_statusDone => 'Ingesteld';

  @override
  String get settings_setupGuide_statusTodo => 'Niet ingesteld';

  @override
  String get settings_setupGuide_open => 'Openen';

  @override
  String get settings_connectedAccounts_loadError =>
      'Accounts konden niet worden geladen';

  @override
  String get media_unavailablePlaceholder_volumeOffline =>
      'Volume niet gekoppeld';

  @override
  String get media_unavailablePlaceholder_stillFetching =>
      'Nog aan het laden. Tik om opnieuw te proberen.';

  @override
  String get media_unavailablePlaceholder_accessDenied =>
      'Geen toegang tot fotobibliotheek';

  @override
  String get attrLabel_size => 'Maat';

  @override
  String get attrLabel_thickness_mm => 'Dikte (mm)';

  @override
  String get attrLabel_suit_style => 'Type pak';

  @override
  String get attrLabel_shell_material => 'Buitenmateriaal';

  @override
  String get attrLabel_seal_type => 'Type seals';

  @override
  String get attrLabel_volume_l => 'Volume';

  @override
  String get attrLabel_working_pressure_bar => 'Werkdruk';

  @override
  String get attrLabel_tank_material => 'Materiaal';

  @override
  String get attrLabel_valve_type => 'Kraan';

  @override
  String get attrLabel_tank_identifier => 'Identificatie';

  @override
  String get attrLabel_last_visual_inspection => 'Laatste visuele inspectie';

  @override
  String get attrLabel_last_hydro_test => 'Laatste hydrostatische test';

  @override
  String get attrLabel_connection => 'Aansluiting';

  @override
  String get attrLabel_cold_water_rated => 'Geschikt voor koud water';

  @override
  String get attrLabel_bcd_style => 'Stijl';

  @override
  String get attrLabel_lift_capacity_kg => 'Liftcapaciteit';

  @override
  String get attrLabel_heel_type => 'Hiel';

  @override
  String get attrLabel_blade_style => 'Blad';

  @override
  String get attrLabel_mount => 'Bevestiging';

  @override
  String get attrLabel_connectivity => 'Connectiviteit';

  @override
  String get attrLabel_lens_config => 'Lens';

  @override
  String get attrLabel_prescription => 'Lenzen op sterkte';

  @override
  String get attrLabel_weight_style => 'Stijl';

  @override
  String get attrLabel_lumens => 'Lumen';

  @override
  String get attrLabel_beam_type => 'Bundel';

  @override
  String get attrLabel_depth_rating_m => 'Dieptewaardering';

  @override
  String get attrLabel_smb_type => 'Type';

  @override
  String get attrLabel_length_m => 'Lengte';

  @override
  String get attrLabel_reel_type => 'Type';

  @override
  String get attrLabel_line_length_m => 'Lijnlengte';

  @override
  String get attrLabel_blade_material => 'Lemmetmateriaal';

  @override
  String get attrLabel_tip_type => 'Punt';

  @override
  String get attrLabel_glove_type => 'Type';

  @override
  String get attrLabel_sole_type => 'Zool';

  @override
  String get attrLabel_buoyancy_kg => 'Drijfvermogen';

  @override
  String get attrLabel_dry_weight_kg => 'Drooggewicht';

  @override
  String get attrLabel_unit_type => 'Type unit';

  @override
  String get attrLabel_mount_configuration => 'Montage';

  @override
  String get attrLabel_scrubber_type => 'Type scrubber';

  @override
  String get attrLabel_scrubber_duration_h => 'Scrubberduur (u)';

  @override
  String get attrLabel_o2_cell_count => 'O2-cellen';

  @override
  String get attrLabel_diluent_cylinder_l => 'Diluentfles';

  @override
  String get attrLabel_o2_cylinder_l => 'O2-fles';

  @override
  String get attrLabel_dpv_style => 'Stijl';

  @override
  String get attrLabel_burn_time_h => 'Looptijd';

  @override
  String get attrLabel_battery_type => 'Accu';

  @override
  String get attrLabel_battery_capacity_wh => 'Accucapaciteit (Wh)';

  @override
  String get attrLabel_motor_type => 'Motor';

  @override
  String get attrLabel_speed_mps => 'Topsnelheid';

  @override
  String get attrChoice_unit_type_eccr => 'Elektronische CCR (eCCR)';

  @override
  String get attrChoice_unit_type_mccr => 'Handmatige CCR (mCCR)';

  @override
  String get attrChoice_unit_type_hccr => 'Hybride CCR (hCCR)';

  @override
  String get attrChoice_unit_type_scr_cmf => 'SCR - constante massastroom';

  @override
  String get attrChoice_unit_type_scr_pascr => 'SCR - passieve toevoeging';

  @override
  String get attrChoice_unit_type_scr_escr => 'SCR - elektronisch geregeld';

  @override
  String get attrChoice_mount_configuration_back => 'Rugmontage';

  @override
  String get attrChoice_mount_configuration_chest => 'Borstmontage';

  @override
  String get attrChoice_mount_configuration_sidemount => 'Sidemount';

  @override
  String get attrChoice_scrubber_type_axial => 'Axiaal';

  @override
  String get attrChoice_scrubber_type_radial => 'Radiaal';

  @override
  String get attrChoice_suit_style_full => 'Volledig pak';

  @override
  String get attrChoice_suit_style_shorty => 'Shorty';

  @override
  String get attrChoice_suit_style_two_piece => 'Tweedelig';

  @override
  String get attrChoice_suit_style_semi_dry => 'Semi-dry';

  @override
  String get attrChoice_shell_material_trilaminate => 'Trilaminaat';

  @override
  String get attrChoice_shell_material_neoprene => 'Neopreen';

  @override
  String get attrChoice_shell_material_crushed_neoprene => 'Geperst neopreen';

  @override
  String get attrChoice_shell_material_vulcanized_rubber =>
      'Gevulkaniseerd rubber';

  @override
  String get attrChoice_seal_type_latex => 'Latex';

  @override
  String get attrChoice_seal_type_silicone => 'Siliconen';

  @override
  String get attrChoice_seal_type_neoprene => 'Neopreen';

  @override
  String get attrChoice_tank_material_aluminum => 'Aluminium';

  @override
  String get attrChoice_tank_material_steel => 'Staal';

  @override
  String get attrChoice_tank_material_carbon_composite => 'Carboncomposiet';

  @override
  String get attrChoice_valve_type_din => 'DIN';

  @override
  String get attrChoice_valve_type_yoke => 'Beugel (INT)';

  @override
  String get attrChoice_valve_type_convertible => 'Ombouwbaar';

  @override
  String get attrChoice_connection_din => 'DIN';

  @override
  String get attrChoice_connection_yoke => 'Beugel (INT)';

  @override
  String get attrChoice_bcd_style_jacket => 'Jacket';

  @override
  String get attrChoice_bcd_style_back_inflate => 'Back-inflate';

  @override
  String get attrChoice_bcd_style_wing => 'Wing';

  @override
  String get attrChoice_bcd_style_sidemount => 'Sidemount';

  @override
  String get attrChoice_heel_type_open_heel => 'Open hiel';

  @override
  String get attrChoice_heel_type_full_foot => 'Gesloten voet';

  @override
  String get attrChoice_blade_style_paddle => 'Paddle';

  @override
  String get attrChoice_blade_style_split => 'Split';

  @override
  String get attrChoice_blade_style_vented => 'Geventileerd';

  @override
  String get attrChoice_mount_wrist => 'Pols';

  @override
  String get attrChoice_mount_console => 'Console';

  @override
  String get attrChoice_mount_hud => 'HUD';

  @override
  String get attrChoice_connectivity_ble => 'Bluetooth (BLE)';

  @override
  String get attrChoice_connectivity_usb => 'USB';

  @override
  String get attrChoice_connectivity_infrared => 'Infrarood';

  @override
  String get attrChoice_connectivity_none => 'Geen';

  @override
  String get attrChoice_lens_config_single => 'Enkel glas';

  @override
  String get attrChoice_lens_config_twin => 'Dubbel glas';

  @override
  String get attrChoice_lens_config_frameless => 'Frameloos';

  @override
  String get attrChoice_weight_style_belt => 'Riem';

  @override
  String get attrChoice_weight_style_integrated => 'Geïntegreerd';

  @override
  String get attrChoice_weight_style_trim => 'Trim';

  @override
  String get attrChoice_weight_style_ankle => 'Enkel';

  @override
  String get attrChoice_beam_type_spot => 'Spot';

  @override
  String get attrChoice_beam_type_flood => 'Flood';

  @override
  String get attrChoice_beam_type_adjustable => 'Verstelbaar';

  @override
  String get attrChoice_smb_type_open => 'Open';

  @override
  String get attrChoice_smb_type_closed => 'Gesloten';

  @override
  String get attrChoice_reel_type_spool => 'Spool';

  @override
  String get attrChoice_reel_type_ratchet => 'Ratelreel';

  @override
  String get attrChoice_blade_material_stainless => 'Roestvrij staal';

  @override
  String get attrChoice_blade_material_titanium => 'Titanium';

  @override
  String get attrChoice_tip_type_pointed => 'Puntig';

  @override
  String get attrChoice_tip_type_blunt => 'Stomp';

  @override
  String get attrChoice_tip_type_line_cutter => 'Lijnsnijder';

  @override
  String get attrChoice_glove_type_five_finger => 'Vijfvinger';

  @override
  String get attrChoice_glove_type_mitt => 'Want';

  @override
  String get attrChoice_glove_type_dry => 'Droog';

  @override
  String get attrChoice_sole_type_hard => 'Harde zool';

  @override
  String get attrChoice_sole_type_soft => 'Zachte zool';

  @override
  String get attrChoice_dpv_style_tow_behind => 'Sleepmodel';

  @override
  String get attrChoice_dpv_style_ride_on => 'Zitmodel';

  @override
  String get attrChoice_dpv_style_handheld => 'Handheld';

  @override
  String get attrChoice_battery_type_lithium_ion => 'Lithium-ion';

  @override
  String get attrChoice_battery_type_nimh => 'NiMH';

  @override
  String get attrChoice_battery_type_lead_acid => 'Loodzuur';

  @override
  String get attrChoice_motor_type_brushless => 'Borstelloos';

  @override
  String get attrChoice_motor_type_brushed => 'Met borstels';

  @override
  String get equipment_edit_customFieldsTitle => 'Aangepaste velden';

  @override
  String get equipment_edit_addCustomField => 'Aangepast veld toevoegen';

  @override
  String get attr_flagYes => 'Ja';

  @override
  String get attr_flagNo => 'Nee';

  @override
  String get equipment_edit_invalidThickness => 'Gebruik 5, 5/4 of 7/5/3';

  @override
  String get statistics_progression_divesBySuitThickness_title =>
      'Duiken per pakdikte';

  @override
  String get statistics_progression_divesBySuitThickness_subtitle =>
      'Primaire pakdikte over je duiken';

  @override
  String get statistics_progression_divesBySuitThickness_empty =>
      'Geen duiken met een geregistreerde pakdikte';

  @override
  String get statistics_progression_divesBySuitThickness_error =>
      'Kan pakdiktegegevens niet laden';

  @override
  String get diveLog_filter_sectionSuitThickness => 'Pakdikte (mm)';

  @override
  String get diveLog_filter_thicknessMin => 'Min';

  @override
  String get diveLog_filter_thicknessMax => 'Max';

  @override
  String get safetySettings_noFlyHeader => 'Vliegen na het duiken';

  @override
  String get safetySettings_noFlyPreset_standard => 'Standaard (12/18/24 u)';

  @override
  String get safetySettings_noFlyPreset_strict => 'Strikt (18/24/48 u)';

  @override
  String get safetySettings_noFlyPreset_subtitle =>
      'Richttijden na een enkele duik zonder deco, herhalingsduiken en decoduiken';

  @override
  String get flightWindow_closed => 'Niet meer duiken vóór je vlucht';

  @override
  String get flightWindow_conflict =>
      'Je no-flytijd loopt door tot na je vertrek';

  @override
  String flightWindow_departs(String time) {
    return 'Vlucht vertrekt $time';
  }

  @override
  String flightWindow_openTitle(String remaining) {
    return 'Resterende duiktijd: $remaining';
  }

  @override
  String flightWindow_surfaceBy(String time) {
    return 'Boven water vóór $time';
  }

  @override
  String safetyHub_noFly_active_title(String remaining) {
    return 'Vliegverbod: nog $remaining';
  }

  @override
  String safetyHub_noFly_until(String time) {
    return 'Tot $time';
  }

  @override
  String get safetyHub_noFly_clear_title => 'Geen vliegbeperking';

  @override
  String get safetyHub_noFly_clear_subtitle => 'Geen actieve vliegbeperking';

  @override
  String safetyHub_noFly_category_single(int hours) {
    return 'Na een enkele duik zonder deco: richtlijn van $hours u';
  }

  @override
  String safetyHub_noFly_category_repetitive(int hours) {
    return 'Na herhalingsduiken: richtlijn van $hours u';
  }

  @override
  String safetyHub_noFly_category_deco(int hours) {
    return 'Na een decompressieduik: richtlijn van $hours u';
  }

  @override
  String get safetyHub_noFly_disclaimer =>
      'DAN/UHMS-richtlijnen vanaf je laatste duik. Geen vervanging voor de no-fly-tijd van je duikcomputer.';

  @override
  String get diveLog_detail_altitudeMismatch_title => 'Duikstek ligt op hoogte';

  @override
  String get diveLog_detail_altitudeMismatch_subtitle =>
      'Deze stek heeft een hoogte geregistreerd maar de duik niet, dus de deco-analyse ging uit van zeeniveau. Stel de hoogte van de duik in om dit te corrigeren.';

  @override
  String diveLog_detail_sacVolumeHint(String unit) {
    return 'Voeg een flesvolume toe om het SAC-verbruik in $unit/min te tonen';
  }

  @override
  String safetyHub_alert_noFly(String remaining) {
    return 'Vliegverbod: nog $remaining';
  }

  @override
  String get emergencyCard_title => 'Noodgeval';

  @override
  String emergencyCard_callDan(String name) {
    return 'Bel $name';
  }

  @override
  String get emergencyCard_callDan_subtitle =>
      'Noodlijn voor duikers. Bel eerst: zij coördineren evacuatie en doorverwijzing naar een kamer.';

  @override
  String emergencyCard_ems(String number) {
    return 'Lokale hulpdiensten: $number';
  }

  @override
  String get emergencyCard_diverSection => 'Duiker';

  @override
  String emergencyCard_bloodType(String value) {
    return 'Bloedgroep: $value';
  }

  @override
  String emergencyCard_allergies(String value) {
    return 'Allergieën: $value';
  }

  @override
  String emergencyCard_medications(String value) {
    return 'Medicatie: $value';
  }

  @override
  String get emergencyCard_contactsSection => 'Noodcontacten';

  @override
  String get emergencyCard_insuranceSection => 'Duikverzekering';

  @override
  String emergencyCard_insurancePolicy(String number) {
    return 'Polis $number';
  }

  @override
  String get emergencyCard_chambersSection => 'Decompressiekamers';

  @override
  String get emergencyCard_chambersNote =>
      'Beschikbaarheid verandert. Bel altijd eerst de noodlijn voor duikers voor doorverwijzing.';

  @override
  String emergencyCard_chamberVerified(String date) {
    return 'Gegevens gecontroleerd $date';
  }

  @override
  String get emergencyCard_chambersNearby => 'Dichtstbijzijnde caissons';

  @override
  String emergencyCard_chamberViewAll(int count) {
    return 'Alle $count caissons bekijken';
  }

  @override
  String get emergencyCard_chambersNoneNearby =>
      'Geen caisson binnen bereik. Bel de duikers-noodlijn: zij verwijzen u door naar de dichtstbijzijnde instelling die u kan behandelen.';

  @override
  String get emergencyCard_chamberCapability_divingEmergency =>
      'Behandelt duikongevallen';

  @override
  String get emergencyCard_chamberCapability_hyperbaricUnit =>
      'Hyperbare afdeling ziekenhuis';

  @override
  String get emergencyCard_chamberCapability_elective =>
      'Alleen electieve therapie';

  @override
  String get emergencyCard_chamberCapability_unknown =>
      'Mogelijkheden niet bevestigd';

  @override
  String get emergencyCard_chamberAvailability_h24 => '24 uur';

  @override
  String get emergencyCard_chamberAvailability_onCall => 'Oproepbaar';

  @override
  String get emergencyCard_chamberAvailability_businessHours => 'Kantooruren';

  @override
  String get emergencyCard_chamberUnverified =>
      'Niet bevestigd bij de instelling';

  @override
  String get chambersDirectory_title => 'Hyperbare caissons';

  @override
  String get chambersDirectory_search => 'Zoeken op naam, stad of land';

  @override
  String get chambersDirectory_empty =>
      'Geen caisson komt overeen met die zoekopdracht.';

  @override
  String chambersDirectory_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count caissons',
      one: '1 caisson',
    );
    return '$_temp0';
  }

  @override
  String get emergencyCard_hideChamber => 'Verbergen';

  @override
  String get emergencyCard_chamberHidden => 'Kamer verborgen';

  @override
  String get emergencyCard_undo => 'Ongedaan maken';

  @override
  String get emergencyCard_addChamber => 'Kamer toevoegen';

  @override
  String get emergencyCard_deleteChamber => 'Verwijderen';

  @override
  String emergencyCard_regionLabel(String region) {
    return 'Regio: $region';
  }

  @override
  String get emergencyCard_regionUnknown =>
      'Regio onbekend - wereldwijde noodlijn wordt gebruikt';

  @override
  String get emergencyCard_noDiverData =>
      'Geen duikersprofielgegevens. Voeg noodcontacten, medische gegevens en verzekering toe in het duikersprofiel.';

  @override
  String get addChamber_title => 'Kamer toevoegen';

  @override
  String get addChamber_name => 'Naam';

  @override
  String get addChamber_country => 'Landcode (bijv. NL)';

  @override
  String get addChamber_city => 'Stad';

  @override
  String get addChamber_phone => 'Telefoon';

  @override
  String get addChamber_notes => 'Notities';

  @override
  String get addChamber_save => 'Opslaan';

  @override
  String get addChamber_nameRequired => 'Naam is verplicht';

  @override
  String get addChamber_countryRequired => 'Landcode is verplicht';

  @override
  String get addChamber_phoneRequired => 'Telefoonnummer is verplicht';

  @override
  String get safetyHub_emergencyCardLink => 'Noodkaart';

  @override
  String get safetyHub_emergencyCardLink_subtitle =>
      'Offline: noodlijn, hulpdiensten, kamers, je medische en verzekeringsgegevens';

  @override
  String get dashboard_quickAction_emergency => 'Noodkaart';

  @override
  String get incidents_title => 'Bijna-ongevallenlog';

  @override
  String get incidents_empty =>
      'Geen bijna-ongevallen vastgelegd. Noteren wat bijna misging - zonder oordeel - maakt patronen zichtbaar voordat het ongelukken worden.';

  @override
  String get incidents_add => 'Bijna-ongeval vastleggen';

  @override
  String get incidents_linkedDive => 'Gekoppeld aan een duik';

  @override
  String get incidents_delete_confirm =>
      'Dit bijna-ongevalrapport verwijderen?';

  @override
  String get incidents_notFound => 'Bijna-ongevalrapport niet gevonden';

  @override
  String get incidentEdit_title_new => 'Bijna-ongeval vastleggen';

  @override
  String get incidentEdit_title_edit => 'Bijna-ongeval bewerken';

  @override
  String get incidentEdit_category => 'Categorie';

  @override
  String get incidentEdit_severity => 'Ernst';

  @override
  String get incidentEdit_severity_minor => 'Licht';

  @override
  String get incidentEdit_severity_moderate => 'Matig';

  @override
  String get incidentEdit_severity_serious => 'Ernstig';

  @override
  String get incidentEdit_date => 'Wanneer het gebeurde';

  @override
  String get incidentEdit_narrative => 'Wat er gebeurde';

  @override
  String get incidentEdit_narrative_hint =>
      'Alleen de feiten, in je eigen woorden. Dit blijft privé.';

  @override
  String get incidentEdit_narrative_required => 'Beschrijf wat er gebeurde';

  @override
  String get incidentEdit_contributingFactors =>
      'Wat eraan bijdroeg (optioneel)';

  @override
  String get incidentEdit_lessonsLearned =>
      'Wat de volgende keer zou helpen (optioneel)';

  @override
  String get incidentEdit_save => 'Opslaan';

  @override
  String get incidentEdit_privacyNote =>
      'Bijna-ongevalrapporten synchroniseren tussen je apparaten en zitten in je back-ups, maar nooit in exports of gedeelde logboekpagina\'s.';

  @override
  String get incidentCategory_buoyancy => 'Trim/drijfvermogen';

  @override
  String get incidentCategory_gasSupply => 'Gastoevoer';

  @override
  String get incidentCategory_equipment => 'Uitrusting';

  @override
  String get incidentCategory_buddySeparation => 'Buddyscheiding';

  @override
  String get incidentCategory_marineLife => 'Zeeleven';

  @override
  String get incidentCategory_boatSurface => 'Boot / oppervlak';

  @override
  String get incidentCategory_medical => 'Medisch';

  @override
  String get incidentCategory_planning => 'Planning';

  @override
  String get incidentCategory_other => 'Overig';

  @override
  String get safetyHub_incidentsLink => 'Bijna-ongevallenlog';

  @override
  String get safetyHub_incidentsLink_subtitle =>
      'Privé, niet-bestraffende incidentnotities';

  @override
  String get diveLog_detail_menu_logNearMiss => 'Bijna-ongeval vastleggen';

  @override
  String diveLog_detail_linkedIncidents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bijna-ongevallen gekoppeld aan deze duik',
      one: '1 bijna-ongeval gekoppeld aan deze duik',
    );
    return '$_temp0';
  }

  @override
  String get planning_card_noFly_subtitle =>
      'Richtlijn-aftelling vanaf je laatste duiken';

  @override
  String get settings_section_safety_title => 'Veiligheid';

  @override
  String get settings_section_safety_subtitle =>
      'Controleregels & vliegen na het duiken';

  @override
  String get settings_section_security_title => 'App-beveiliging';

  @override
  String get settings_section_security_subtitle =>
      'App-vergrendeling & databaseversleuteling';

  @override
  String get settings_security_appLock => 'App-vergrendeling';

  @override
  String get settings_security_appLock_subtitle =>
      'Vereis je wachtwoord of biometrie om de app te openen';

  @override
  String get settings_security_biometrics => 'Ontgrendelen met biometrie';

  @override
  String get settings_security_autoLock => 'Automatisch vergrendelen';

  @override
  String get settings_security_autoLock_immediately => 'Onmiddellijk';

  @override
  String settings_security_autoLock_minutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Na $minutes minuten',
      one: 'Na 1 minuut',
    );
    return '$_temp0';
  }

  @override
  String get settings_security_autoLock_never => 'Nooit';

  @override
  String get settings_security_encryption => 'Database versleutelen';

  @override
  String get settings_security_encryption_subtitle =>
      'Bescherm je duiklogbestand met versleuteling in rust. Versleuteling kan de prestaties beïnvloeden.';

  @override
  String get settings_security_encryption_progress_backup =>
      'Veiligheidsback-up maken...';

  @override
  String get settings_security_encryption_progress_encrypt =>
      'Database versleutelen...';

  @override
  String get settings_security_encryption_progress_decrypt =>
      'Database ontsleutelen...';

  @override
  String get settings_security_encryption_progress_reopen =>
      'Database opnieuw openen...';

  @override
  String get settings_security_changePassword => 'Wachtwoord wijzigen';

  @override
  String get settings_security_regenerateRecovery => 'Nieuwe herstelcode';

  @override
  String get settings_security_setPassword => 'App-wachtwoord instellen';

  @override
  String get settings_security_password => 'Wachtwoord';

  @override
  String get settings_security_confirmPassword => 'Bevestig wachtwoord';

  @override
  String get settings_security_currentPassword => 'Huidig wachtwoord';

  @override
  String get settings_security_newPassword => 'Nieuw wachtwoord';

  @override
  String get settings_security_passwordTooShort =>
      'Het wachtwoord moet minimaal 4 tekens bevatten.';

  @override
  String get settings_security_passwordMismatch =>
      'De wachtwoorden komen niet overeen.';

  @override
  String get settings_security_wrongPassword => 'Onjuist wachtwoord.';

  @override
  String get settings_security_recoveryCode_title => 'Je herstelcode';

  @override
  String get settings_security_recoveryCode_explain =>
      'Schrijf deze op en bewaar hem veilig. Het is de enige manier om de app te ontgrendelen als je je wachtwoord vergeet, en hij vervangt elke eerdere herstelcode.';

  @override
  String get settings_security_recoveryCode_savedConfirm =>
      'Ik heb mijn herstelcode opgeslagen';

  @override
  String get settings_security_disableBlockedByEncryption_title =>
      'Versleuteling is ingeschakeld';

  @override
  String get settings_security_disableBlockedByEncryption_body =>
      'Schakel eerst de databaseversleuteling uit voordat je de app-vergrendeling uitschakelt. De versleutelde database heeft een toegangscode nodig.';

  @override
  String get settings_security_enableEncryption_title =>
      'Database versleutelen?';

  @override
  String get settings_security_enableEncryption_body =>
      'Er wordt eerst een veiligheidsback-up gemaakt, daarna wordt het databasebestand ter plekke opnieuw versleuteld. Dit kan even duren bij grote logboeken. Versleuteling kan de prestaties beïnvloeden.';

  @override
  String get settings_security_disableEncryption_title =>
      'Versleuteling uitschakelen?';

  @override
  String get settings_security_disableEncryption_body =>
      'Het databasebestand wordt weer onversleuteld op schijf opgeslagen.';

  @override
  String get settings_security_turnOffAppLock_title =>
      'App-vergrendeling uitschakelen?';

  @override
  String get settings_security_turnOffAppLock_body =>
      'De app opent voortaan zonder om je wachtwoord te vragen.';

  @override
  String get settings_security_unlock_title => 'Voer je wachtwoord in';

  @override
  String get settings_security_cancel => 'Annuleren';

  @override
  String get settings_security_continue => 'Doorgaan';

  @override
  String get settings_security_done => 'Klaar';

  @override
  String get settings_security_turnOff => 'Uitschakelen';

  @override
  String get dataQuality_inbox_title => 'Datakwaliteit';

  @override
  String get dataQuality_badge_tooltip => 'Controle van datakwaliteit';

  @override
  String get dataQuality_scan_start => 'Bibliotheek scannen';

  @override
  String dataQuality_scan_progress(int done, int total) {
    return '$done van $total duiken gecontroleerd';
  }

  @override
  String get dataQuality_scan_cancel => 'Annuleren';

  @override
  String dataQuality_scan_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scan voltooid - $count items om te bekijken',
      one: 'Scan voltooid - 1 item om te bekijken',
      zero: 'Scan voltooid - geen nieuwe bevindingen',
    );
    return '$_temp0';
  }

  @override
  String dataQuality_scan_errors(int count) {
    return '$count duiken konden niet volledig worden gecontroleerd';
  }

  @override
  String dataQuality_lastScan(String when) {
    return 'Laatste scan: $when';
  }

  @override
  String get dataQuality_neverScanned => 'Je logboek is nog niet gescand';

  @override
  String get dataQuality_empty_title => 'Alles in orde';

  @override
  String get dataQuality_empty_subtitle =>
      'Geen bevindingen over datakwaliteit. Scan je bibliotheek om geïmporteerde duiken op problemen te controleren.';

  @override
  String get dataQuality_banner_newChecks =>
      'Er zijn nieuwe kwaliteitscontroles beschikbaar';

  @override
  String get dataQuality_banner_rescan => 'Opnieuw scannen';

  @override
  String get dataQuality_action_dismiss => 'Negeren';

  @override
  String get dataQuality_action_dismissFiltered => 'Alle getoonde negeren';

  @override
  String get dataQuality_action_goToDive => 'Naar duik';

  @override
  String get dataQuality_action_undo => 'Ongedaan maken';

  @override
  String get dataQuality_repair_applied => 'Herstel toegepast';

  @override
  String get dataQuality_repair_noChange => 'Hier valt niets te herstellen';

  @override
  String get dataQuality_repair_needsReview =>
      'Geen automatische correctie. Open de duik om dit te corrigeren.';

  @override
  String get dataQuality_repair_failed => 'Herstel mislukt';

  @override
  String get dataQuality_chip_all => 'Alle';

  @override
  String get dataQuality_chip_time => 'Tijd';

  @override
  String get dataQuality_chip_profile => 'Profiel';

  @override
  String get dataQuality_chip_gas => 'Gas';

  @override
  String get dataQuality_chip_tanks => 'Flessen';

  @override
  String get dataQuality_chip_duplicates => 'Duplicaten';

  @override
  String get dataQuality_chip_sources => 'Bronnen';

  @override
  String get dataQuality_detector_clock_offset => 'Klok en tijdzone';

  @override
  String get dataQuality_detector_duplicate => 'Waarschijnlijk duplicaat';

  @override
  String get dataQuality_detector_split_pair => 'Onbedoelde splitsing';

  @override
  String get dataQuality_detector_sample_gap => 'Hiaten in metingen';

  @override
  String get dataQuality_detector_depth_spike => 'Dieptepiek';

  @override
  String get dataQuality_detector_impossible_rate => 'Onmogelijke snelheid';

  @override
  String get dataQuality_detector_temp_anomaly => 'Temperatuuranomalie';

  @override
  String get dataQuality_detector_pressure_anomaly => 'Drukanomalie';

  @override
  String get dataQuality_detector_gas_mod => 'Gas/MOD-inconsistentie';

  @override
  String get dataQuality_detector_tank_assignment => 'Verkeerde fles';

  @override
  String get dataQuality_detector_source_conflict => 'Tegenstrijdige bronnen';

  @override
  String dataQuality_msg_clock_future(String date) {
    return 'De duik is gedateerd in de toekomst ($date)';
  }

  @override
  String dataQuality_msg_clock_ancient(String date) {
    return 'De duik is gedateerd voor 1950 ($date)';
  }

  @override
  String dataQuality_msg_clock_offset(int hours) {
    return 'De klok van een bron wijkt $hours uur af';
  }

  @override
  String dataQuality_msg_clock_overlap(int minutes) {
    return 'Overlapt een andere duik met $minutes min';
  }

  @override
  String dataQuality_msg_duplicate(int percent, int minutes) {
    return '$percent% overeenkomst met een duik $minutes min ervandaan';
  }

  @override
  String dataQuality_msg_split(int minutes) {
    return 'Dezelfde computer hervatte na een oppervlakte-interval van $minutes min';
  }

  @override
  String dataQuality_msg_gap(int count, String longest) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hiaten in metingen',
      one: '1 hiaat in metingen',
    );
    return '$_temp0, langste $longest';
  }

  @override
  String dataQuality_msg_spike(String depth, String time) {
    return 'Dieptepiek tot $depth om $time';
  }

  @override
  String dataQuality_msg_negativeDepth(int count) {
    return '$count metingen met negatieve diepte';
  }

  @override
  String dataQuality_msg_maxDepthMismatch(String stored, String profile) {
    return 'Geregistreerde maximale diepte $stored, maar het profiel toont $profile';
  }

  @override
  String dataQuality_msg_rate(String rate, int seconds) {
    return 'Verticale snelheid van $rate aangehouden gedurende $seconds s';
  }

  @override
  String dataQuality_msg_tempRange(String min, String max) {
    return 'Watertemperatuur buiten het aannemelijke bereik ($min tot $max)';
  }

  @override
  String get dataQuality_msg_tempUnitBug =>
      'De waarden lijken op een fout in de temperatuureenheid';

  @override
  String dataQuality_msg_tempJump(String delta) {
    return 'Temperatuur sprong $delta in één meting';
  }

  @override
  String dataQuality_msg_tempScalar(String temp) {
    return 'Geregistreerde watertemperatuur $temp is onaannemelijk';
  }

  @override
  String dataQuality_msg_pressureSwap(String end, String start) {
    return 'Einddruk $end is hoger dan begindruk $start';
  }

  @override
  String dataQuality_msg_pressureEndpoint(String record, String series) {
    return 'Het flesrecord vermeldt $record, maar de sensorreeks toont $series';
  }

  @override
  String dataQuality_msg_pressureRise(String rise) {
    return 'Druk steeg $rise midden in de duik zonder gaswisseling';
  }

  @override
  String dataQuality_msg_sac(String sac) {
    return 'Het afgeleide oppervlakteverbruik van $sac is onaannemelijk';
  }

  @override
  String dataQuality_msg_ppo2(String ppo2, String gas, String depth) {
    return 'ppO2 bereikte $ppo2 op $gas bij $depth';
  }

  @override
  String dataQuality_msg_hypoxic(String gas) {
    return 'Hypoxisch mengsel ($gas) weergegeven als in gebruik aan de oppervlakte';
  }

  @override
  String dataQuality_msg_switchMod(String depth, String mod) {
    return 'Gaswisseling op $depth ligt voorbij de MOD van dat gas van $mod';
  }

  @override
  String dataQuality_msg_tankInactive(String drop) {
    return 'Deze fles verloor $drop terwijl de gastijdlijn aangeeft dat ze niet in gebruik was';
  }

  @override
  String get dataQuality_msg_twinTanks =>
      'Twee flessen hebben een vrijwel identieke drukreeks';

  @override
  String dataQuality_msg_sourceDepth(String primary, String source) {
    return 'Bronnen zijn het oneens over de maximale diepte: $primary versus $source';
  }

  @override
  String get dataQuality_msg_salinityHint =>
      'De constante verhouding wijst op een verschil in de zout-/zoetwaterinstelling';

  @override
  String get dataQuality_msg_sourceDuration =>
      'Bronnen zijn het oneens over de duikduur';

  @override
  String get dataQuality_msg_sourceTemp =>
      'Bronnen zijn het oneens over de watertemperatuur';

  @override
  String dataQuality_repairLabel_shiftTime(String offset) {
    return 'Tijd verschuiven met $offset';
  }

  @override
  String get dataQuality_repairLabel_shiftImport =>
      'Alle duiken uit deze import verschuiven';

  @override
  String get dataQuality_repairLabel_consolidate => 'Consolideren';

  @override
  String get dataQuality_repairLabel_combine => 'Samenvoegen tot één duik';

  @override
  String get dataQuality_repairLabel_despike => 'Piek verwijderen';

  @override
  String get dataQuality_repairLabel_clampNegative =>
      'Diepten boven het oppervlak begrenzen';

  @override
  String get dataQuality_repairLabel_smoothRates =>
      'Onmogelijke snelheden vlak maken';

  @override
  String get dataQuality_repairLabel_fillGaps => 'Hiaten opvullen';

  @override
  String get dataQuality_repairLabel_smoothTemp => 'Temperatuur effenen';

  @override
  String get dataQuality_repairLabel_convertTemp => 'Temperatuur omrekenen';

  @override
  String get dataQuality_repairLabel_recompute =>
      'Opnieuw berekenen op basis van profiel';

  @override
  String get dataQuality_repairLabel_swapPressures =>
      'Begin-/einddruk verwisselen';

  @override
  String get dataQuality_repairLabel_setFromSeries => 'Sensorwaarden gebruiken';

  @override
  String get dataQuality_repairLabel_swapSeries => 'Flesreeksen verwisselen';

  @override
  String get dataQuality_repairLabel_reassignSeries =>
      'Reeks naar een andere fles verplaatsen';

  @override
  String get dataQuality_repairLabel_setPrimary =>
      'Deze bron als primair instellen';

  @override
  String get dataQuality_repairLabel_split =>
      'Splitsen in afzonderlijke duiken';

  @override
  String get dataQuality_repairLabel_compare => 'Profielen vergelijken';

  @override
  String get dataQuality_settings_title => 'Datakwaliteit';

  @override
  String get dataQuality_settings_subtitle =>
      'Kiezen welke controles worden uitgevoerd bij het scannen';

  @override
  String dataQuality_summary_flagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items gemarkeerd voor controle',
      one: '1 item gemarkeerd voor controle',
    );
    return '$_temp0';
  }

  @override
  String get dataQuality_summary_review => 'Controleren';

  @override
  String get dataQuality_detail_chip => 'Controleren';

  @override
  String dataQuality_detail_chipCount(int count) {
    return 'Controleren ($count)';
  }

  @override
  String get settings_mediaStorage_quality_section => 'Uploadkwaliteit';

  @override
  String get settings_mediaStorage_quality_photos => 'Foto\'s';

  @override
  String get settings_mediaStorage_quality_video => 'Video';

  @override
  String get settings_mediaStorage_quality_original => 'Origineel';

  @override
  String get settings_mediaStorage_quality_high => 'Hoog';

  @override
  String get settings_mediaStorage_quality_balanced => 'Gebalanceerd';

  @override
  String get settings_mediaStorage_quality_small => 'Klein';

  @override
  String get settings_mediaStorage_quality_caveat =>
      'Als er een compressieniveau is ingesteld, worden originelen op volledige resolutie niet geüpload; ze blijven alleen op dit apparaat.';

  @override
  String get settings_mediaStorage_quality_reuploadQueued =>
      'Opnieuw uploaden in wachtrij';

  @override
  String get settings_mediaStorage_quality_linuxFfmpegHint =>
      'Installeer ffmpeg om videocompressie in te schakelen. Tot die tijd worden originelen geüpload.';

  @override
  String get settings_mediaStorage_quality_saveFailed =>
      'Kan de uploadkwaliteit niet opslaan. Probeer het opnieuw.';

  @override
  String get settings_mediaStorage_quality_noTranscoderHint =>
      'Dit apparaat kan geen video comprimeren. Vanaf dit apparaat worden originelen geüpload.';

  @override
  String get reef_section_title => 'Ecosysteem';

  @override
  String get reef_section_sourcesTooltip => 'Gegevensbronnen';

  @override
  String get reef_section_loadError =>
      'Ecosysteemgegevens konden nu niet worden geladen';

  @override
  String get reef_habitat_title => 'Rifhabitat';

  @override
  String get reef_habitat_onReef => 'Op een koraalrif';

  @override
  String reef_habitat_onReefWithThreat(String threat) {
    return 'Op een koraalrif, dreigingsniveau $threat';
  }

  @override
  String get reef_habitat_noReef => 'Geen gekarteerd koraalrif op deze locatie';

  @override
  String get reef_habitat_unavailable =>
      'Rifhabitat kon nu niet worden gecontroleerd';

  @override
  String get water_conditions_title => 'Wateromstandigheden';

  @override
  String get water_conditions_unavailable =>
      'Wateromstandigheden konden nu niet worden gecontroleerd';

  @override
  String get water_conditions_noData =>
      'Geen satellietwatergegevens voor deze locatie';

  @override
  String get water_conditions_freshwater =>
      'Satellietwatertemperatuur dekt alleen oceanen';

  @override
  String water_conditions_anomaly(String value) {
    return 'Anomalie $value';
  }

  @override
  String reef_health_degreeHeatingWeeks(String value) {
    return 'Degree Heating Weeks $value C-weken';
  }

  @override
  String reef_health_seaSurface(String value) {
    return 'Zeeoppervlak $value';
  }

  @override
  String reef_health_asOf(String date) {
    return 'Per $date';
  }

  @override
  String get reef_health_levelNoStress => 'Geen hittestress';

  @override
  String get reef_health_levelWatch => 'Verbleking waakzaamheid';

  @override
  String get reef_health_levelWarning => 'Verbleking waarschuwing';

  @override
  String get reef_health_levelAlert1 => 'Verblekingsalarm niveau 1';

  @override
  String get reef_health_levelAlert2 => 'Verblekingsalarm niveau 2';

  @override
  String get reef_health_levelAlert3 => 'Verblekingsalarm niveau 3';

  @override
  String get reef_health_levelAlert4 => 'Verblekingsalarm niveau 4';

  @override
  String get reef_health_levelAlert5 => 'Verblekingsalarm niveau 5';

  @override
  String get reef_protection_title => 'Beschermd gebied';

  @override
  String get reef_protection_none => 'Niet in een beschermd zeegebied';

  @override
  String get reef_protection_unavailable =>
      'Beschermingsstatus kon nu niet worden gecontroleerd';

  @override
  String get reef_protection_viewRegulations => 'Regels bekijken';

  @override
  String reef_protection_iucn(String category) {
    return 'IUCN $category';
  }

  @override
  String get reef_species_recordedNearby => 'In de buurt geregistreerd';

  @override
  String get reef_species_addToExpected => 'Toevoegen aan verwachte soorten';

  @override
  String reef_species_showAll(int count) {
    return 'Alle $count tonen';
  }

  @override
  String get reef_species_showFewer => 'Minder tonen';

  @override
  String get reef_attribution_title => 'Rifgegevensbronnen';

  @override
  String get reef_attribution_wri =>
      'Rifaanwezigheid en dreigingsniveau. CC BY 3.0.';

  @override
  String get reef_attribution_noaa =>
      'Zeeoppervlaktetemperatuur en hittestress. Publiek domein.';

  @override
  String get reef_attribution_gbif =>
      'Waarnemingen van soorten, gefilterd op CC0 en CC BY 4.0.';

  @override
  String get reef_attribution_protectedSeas =>
      'Grenzen van beschermde zeegebieden. CC BY 4.0.';

  @override
  String get enum_visibilityBand_excellent => 'Uitstekend';

  @override
  String get enum_visibilityBand_good => 'Goed';

  @override
  String get enum_visibilityBand_moderate => 'Matig';

  @override
  String get enum_visibilityBand_poor => 'Slecht';

  @override
  String visibility_range_between(String min, String max, String unit) {
    return '$min-$max $unit';
  }

  @override
  String visibility_range_over(String min, String unit) {
    return 'meer dan $min $unit';
  }

  @override
  String visibility_range_under(String max, String unit) {
    return 'minder dan $max $unit';
  }

  @override
  String get settings_coordinateFormat_title => 'Coördinaatformaat';

  @override
  String get settings_coordinateFormat_subtitle =>
      'Hoe GPS-posities worden weergegeven en ingevoerd';

  @override
  String get settings_placeNameLanguage_title => 'Taal van plaatsnamen';

  @override
  String get settings_placeNameLanguage_subtitle =>
      'Gebruikt wanneer land, regio, plaats en water uit coördinaten worden opgezocht. Bestaande duikstekken worden niet gewijzigd.';

  @override
  String get settings_coordinateFormat_decimalDegrees => 'Decimale graden';

  @override
  String get settings_coordinateFormat_degreesDecimalMinutes =>
      'Graden en decimale minuten';

  @override
  String get settings_coordinateFormat_degreesMinutesSeconds =>
      'Graden, minuten, seconden';

  @override
  String get settings_coordinateFormat_utm => 'UTM';

  @override
  String get settings_coordinateFormat_mgrs => 'MGRS';

  @override
  String get settings_visibilityScale_title => 'Zichtschaal';

  @override
  String get settings_visibilityScale_subtitle =>
      'Welke afstanden gelden als goed zicht waar jij duikt';

  @override
  String get settings_visibilityScale_preset_tropical => 'Tropisch';

  @override
  String get settings_visibilityScale_preset_temperate => 'Gematigd';

  @override
  String get settings_visibilityScale_preset_coldWater =>
      'Koud water / Binnenwater';

  @override
  String get settings_visibilityScale_preset_custom => 'Aangepast';

  @override
  String get settings_visibilityScale_customExcellent => 'Uitstekend vanaf';

  @override
  String get settings_visibilityScale_customGood => 'Goed vanaf';

  @override
  String get settings_visibilityScale_customModerate => 'Matig vanaf';

  @override
  String get settings_visibilityScale_invalidOrder =>
      'Elke waarde moet kleiner zijn dan die erboven en groter dan nul';

  @override
  String statistics_conditions_visibility_legacySuffix(String band) {
    return '$band (vastgelegd vóór meting)';
  }

  @override
  String common_selection_countSelected(Object count) {
    return '$count geselecteerd';
  }

  @override
  String get common_selection_enterTooltip => 'Items selecteren';

  @override
  String get common_selection_exitTooltip => 'Selectie beëindigen';

  @override
  String get common_selection_selectAllTooltip => 'Alles selecteren';

  @override
  String get common_selection_deselectAllTooltip => 'Alles deselecteren';

  @override
  String common_bulkDelete_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items verwijderen?',
      one: '$count item verwijderen?',
    );
    return '$_temp0';
  }

  @override
  String get common_bulkDelete_body => 'Dit kan niet ongedaan worden gemaakt.';

  @override
  String common_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verwijderd',
      one: '$count verwijderd',
    );
    return '$_temp0';
  }

  @override
  String get marineLife_species_delete_confirmTitle => 'Soort verwijderen?';

  @override
  String marineLife_species_delete_confirmBody(String name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen?';
  }

  @override
  String marineLife_species_delete_inUseError(String name) {
    return '\"$name\" kan niet worden verwijderd - er zijn waarnemingen';
  }

  @override
  String marineLife_species_delete_snackbar(String name) {
    return '\"$name\" verwijderd';
  }

  @override
  String marineLife_species_delete_error(String error) {
    return 'Fout bij verwijderen van soort: $error';
  }

  @override
  String get enum_diveField_diveNumber => 'Duiknummer';

  @override
  String get enum_diveField_dateTime => 'Datum en tijd';

  @override
  String get enum_diveField_siteName => 'Naam duikstek';

  @override
  String get enum_diveField_diveName => 'Duiknaam';

  @override
  String get enum_diveField_maxDepth => 'Max diepte';

  @override
  String get enum_diveField_avgDepth => 'Gemiddelde diepte';

  @override
  String get enum_diveField_bottomTime => 'Bodemtijd';

  @override
  String get enum_diveField_runtime => 'Looptijd';

  @override
  String get enum_diveField_waterTemp => 'Watertemperatuur';

  @override
  String get enum_diveField_airTemp => 'Luchttemperatuur';

  @override
  String get enum_diveField_visibility => 'Zicht';

  @override
  String get enum_diveField_currentDirection => 'Stromingsrichting';

  @override
  String get enum_diveField_currentStrength => 'Stromingssterkte';

  @override
  String get enum_diveField_swellHeight => 'Deiningshoogte';

  @override
  String get enum_diveField_entryMethod => 'Instapmethode';

  @override
  String get enum_diveField_exitMethod => 'Uitstapmethode';

  @override
  String get enum_diveField_waterType => 'Watertype';

  @override
  String get enum_diveField_altitude => 'Hoogte';

  @override
  String get enum_diveField_surfacePressure => 'Oppervlaktedruk';

  @override
  String get enum_diveField_windSpeed => 'Windsnelheid';

  @override
  String get enum_diveField_cloudCover => 'Bewolking';

  @override
  String get enum_diveField_precipitation => 'Neerslag';

  @override
  String get enum_diveField_humidity => 'Luchtvochtigheid';

  @override
  String get enum_diveField_weatherDescription => 'Weer';

  @override
  String get enum_diveField_primaryGas => 'Hoofdgas';

  @override
  String get enum_diveField_diluentGas => 'Diluent gas';

  @override
  String get enum_diveField_tankCount => 'Aantal flessen';

  @override
  String get enum_diveField_startPressure => 'Begindruk';

  @override
  String get enum_diveField_endPressure => 'Einddruk';

  @override
  String get enum_diveField_sacRate => 'SAC-verbruik';

  @override
  String get enum_diveField_gasConsumed => 'Gasverbruik';

  @override
  String get enum_diveField_totalWeight => 'Totaal gewicht';

  @override
  String get enum_diveField_diveComputerModel => 'Duikcomputer';

  @override
  String get enum_diveField_gradientFactorLow => 'GF laag';

  @override
  String get enum_diveField_gradientFactorHigh => 'GF hoog';

  @override
  String get enum_diveField_decoAlgorithm => 'Deco-algoritme';

  @override
  String get enum_diveField_decoConservatism => 'Conservatisme';

  @override
  String get enum_diveField_cnsStart => 'CNS begin';

  @override
  String get enum_diveField_cnsEnd => 'CNS eind';

  @override
  String get enum_diveField_otu => 'OTU';

  @override
  String get enum_diveField_diveMode => 'Duikmodus';

  @override
  String get enum_diveField_setpointLow => 'Setpoint laag';

  @override
  String get enum_diveField_setpointHigh => 'Setpoint hoog';

  @override
  String get enum_diveField_setpointDeco => 'Setpoint deco';

  @override
  String get enum_diveField_buddy => 'Buddy';

  @override
  String get enum_diveField_diveMaster => 'Divemaster';

  @override
  String get enum_diveField_siteLocation => 'Locatie duikstek';

  @override
  String get enum_diveField_diveCenterName => 'Duikcentrum';

  @override
  String get enum_diveField_siteLatitude => 'Breedtegraad';

  @override
  String get enum_diveField_siteLongitude => 'Lengtegraad';

  @override
  String get enum_diveField_tripName => 'Reis';

  @override
  String get enum_diveField_ratingStars => 'Beoordeling';

  @override
  String get enum_diveField_isFavorite => 'Favoriet';

  @override
  String get enum_diveField_notes => 'Notities';

  @override
  String get enum_diveField_tags => 'Tags';

  @override
  String get enum_diveField_importSource => 'Importbron';

  @override
  String get enum_diveField_diveTypeName => 'Duiktype';

  @override
  String get enum_diveField_surfaceInterval => 'Oppervlakte-interval';

  @override
  String get enum_diveField_diveNumber_short => '#';

  @override
  String get enum_diveField_dateTime_short => 'Datum';

  @override
  String get enum_diveField_siteName_short => 'Stek';

  @override
  String get enum_diveField_diveName_short => 'Naam';

  @override
  String get enum_diveField_maxDepth_short => 'Max D';

  @override
  String get enum_diveField_avgDepth_short => 'Gem D';

  @override
  String get enum_diveField_bottomTime_short => 'BT';

  @override
  String get enum_diveField_runtime_short => 'LT';

  @override
  String get enum_diveField_waterTemp_short => 'W-temp';

  @override
  String get enum_diveField_airTemp_short => 'L-temp';

  @override
  String get enum_diveField_visibility_short => 'Zicht';

  @override
  String get enum_diveField_currentDirection_short => 'Str. ri.';

  @override
  String get enum_diveField_currentStrength_short => 'Str.';

  @override
  String get enum_diveField_swellHeight_short => 'Deining';

  @override
  String get enum_diveField_entryMethod_short => 'Instap';

  @override
  String get enum_diveField_exitMethod_short => 'Uitstap';

  @override
  String get enum_diveField_waterType_short => 'Water';

  @override
  String get enum_diveField_altitude_short => 'Hoogte';

  @override
  String get enum_diveField_surfacePressure_short => 'Opp.druk';

  @override
  String get enum_diveField_windSpeed_short => 'Wind';

  @override
  String get enum_diveField_cloudCover_short => 'Wolken';

  @override
  String get enum_diveField_precipitation_short => 'Neersl.';

  @override
  String get enum_diveField_humidity_short => 'Vocht';

  @override
  String get enum_diveField_weatherDescription_short => 'Weer';

  @override
  String get enum_diveField_primaryGas_short => 'Gas';

  @override
  String get enum_diveField_diluentGas_short => 'Dil';

  @override
  String get enum_diveField_tankCount_short => 'Flessen';

  @override
  String get enum_diveField_startPressure_short => 'Begindr.';

  @override
  String get enum_diveField_endPressure_short => 'Einddr.';

  @override
  String get enum_diveField_sacRate_short => 'SAC';

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
  String get enum_diveField_decoConservatism_short => 'Conserv.';

  @override
  String get enum_diveField_cnsStart_short => 'CNS begin';

  @override
  String get enum_diveField_cnsEnd_short => 'CNS eind';

  @override
  String get enum_diveField_otu_short => 'OTU';

  @override
  String get enum_diveField_diveMode_short => 'Modus';

  @override
  String get enum_diveField_setpointLow_short => 'SP laag';

  @override
  String get enum_diveField_setpointHigh_short => 'SP hoog';

  @override
  String get enum_diveField_setpointDeco_short => 'SP deco';

  @override
  String get enum_diveField_buddy_short => 'Buddy';

  @override
  String get enum_diveField_diveMaster_short => 'DM';

  @override
  String get enum_diveField_siteLocation_short => 'Locatie';

  @override
  String get enum_diveField_diveCenterName_short => 'Centrum';

  @override
  String get enum_diveField_siteLatitude_short => 'Breedte';

  @override
  String get enum_diveField_siteLongitude_short => 'Lengte';

  @override
  String get enum_diveField_tripName_short => 'Reis';

  @override
  String get enum_diveField_ratingStars_short => 'Beoord.';

  @override
  String get enum_diveField_isFavorite_short => 'Fav';

  @override
  String get enum_diveField_notes_short => 'Notities';

  @override
  String get enum_diveField_tags_short => 'Tags';

  @override
  String get enum_diveField_importSource_short => 'Bron';

  @override
  String get enum_diveField_diveTypeName_short => 'Type';

  @override
  String get enum_diveField_surfaceInterval_short => 'OI';

  @override
  String get enum_siteField_siteName => 'Naam';

  @override
  String get enum_siteField_location => 'Locatie';

  @override
  String get enum_siteField_country => 'Land';

  @override
  String get enum_siteField_region => 'Regio';

  @override
  String get enum_siteField_city => 'Stad';

  @override
  String get enum_siteField_island => 'Eiland';

  @override
  String get enum_siteField_bodyOfWater => 'Wateroppervlak';

  @override
  String get enum_siteField_diveCount => 'Aantal duiken';

  @override
  String get enum_siteField_maxDepth => 'Max diepte';

  @override
  String get enum_siteField_minDepth => 'Min diepte';

  @override
  String get enum_siteField_altitude => 'Hoogte';

  @override
  String get enum_siteField_waterType => 'Watertype';

  @override
  String get enum_siteField_typicalVisibility => 'Typisch zicht';

  @override
  String get enum_siteField_typicalCurrent => 'Typische stroming';

  @override
  String get enum_siteField_difficulty => 'Moeilijkheidsgraad';

  @override
  String get enum_siteField_entryType => 'Instaptype';

  @override
  String get enum_siteField_bestSeason => 'Beste seizoen';

  @override
  String get enum_siteField_mooringNumber => 'Boeinummer';

  @override
  String get enum_siteField_hazards => 'Gevaren';

  @override
  String get enum_siteField_rating => 'Beoordeling';

  @override
  String get enum_siteField_notes => 'Notities';

  @override
  String get enum_siteField_latitude => 'Breedtegraad';

  @override
  String get enum_siteField_longitude => 'Lengtegraad';

  @override
  String get enum_siteField_siteName_short => 'Naam';

  @override
  String get enum_siteField_location_short => 'Locatie';

  @override
  String get enum_siteField_country_short => 'Land';

  @override
  String get enum_siteField_region_short => 'Regio';

  @override
  String get enum_siteField_city_short => 'Stad';

  @override
  String get enum_siteField_island_short => 'Eiland';

  @override
  String get enum_siteField_bodyOfWater_short => 'Wateropp.';

  @override
  String get enum_siteField_diveCount_short => 'Duiken';

  @override
  String get enum_siteField_maxDepth_short => 'Max D';

  @override
  String get enum_siteField_minDepth_short => 'Min D';

  @override
  String get enum_siteField_altitude_short => 'Hoogte';

  @override
  String get enum_siteField_waterType_short => 'Water';

  @override
  String get enum_siteField_typicalVisibility_short => 'Zicht';

  @override
  String get enum_siteField_typicalCurrent_short => 'Stroming';

  @override
  String get enum_siteField_difficulty_short => 'Moeil.';

  @override
  String get enum_siteField_entryType_short => 'Instap';

  @override
  String get enum_siteField_exitMethod => 'Uitstapmethode';

  @override
  String get enum_siteField_exitMethod_short => 'Uitstap';

  @override
  String get enum_siteField_bestSeason_short => 'Seizoen';

  @override
  String get enum_siteField_mooringNumber_short => 'Boei';

  @override
  String get enum_siteField_hazards_short => 'Gevaren';

  @override
  String get enum_siteField_rating_short => 'Beoord.';

  @override
  String get enum_siteField_notes_short => 'Notities';

  @override
  String get enum_siteField_latitude_short => 'Breedte';

  @override
  String get enum_siteField_longitude_short => 'Lengte';

  @override
  String get enum_siteField_depthRange => 'Dieptebereik';

  @override
  String get enum_siteField_depthRange_short => 'Diepte';

  @override
  String get enum_siteField_lastDived => 'Laatst gedoken';

  @override
  String get enum_siteField_lastDived_short => 'Laatst';

  @override
  String get enum_siteField_maxDepthReached => 'Jouw max. diepte';

  @override
  String get enum_siteField_maxDepthReached_short => 'Jouw max.';

  @override
  String get enum_buddyField_buddyName => 'Naam';

  @override
  String get enum_buddyField_email => 'E-mail';

  @override
  String get enum_buddyField_phone => 'Telefoon';

  @override
  String get enum_buddyField_certificationLevel => 'Certificeringsniveau';

  @override
  String get enum_buddyField_certificationAgency => 'Certificeringsorganisatie';

  @override
  String get enum_buddyField_diveCount => 'Aantal duiken';

  @override
  String get enum_buddyField_notes => 'Notities';

  @override
  String get enum_buddyField_buddyName_short => 'Naam';

  @override
  String get enum_buddyField_email_short => 'E-mail';

  @override
  String get enum_buddyField_phone_short => 'Tel.';

  @override
  String get enum_buddyField_certificationLevel_short => 'Niveau';

  @override
  String get enum_buddyField_certificationAgency_short => 'Org.';

  @override
  String get enum_buddyField_diveCount_short => 'Duiken';

  @override
  String get enum_buddyField_notes_short => 'Notities';

  @override
  String get enum_buddyField_lastDive => 'Laatste duik';

  @override
  String get enum_buddyField_lastDive_short => 'Laatste';

  @override
  String get enum_tripField_tripName => 'Naam';

  @override
  String get enum_tripField_startDate => 'Startdatum';

  @override
  String get enum_tripField_endDate => 'Einddatum';

  @override
  String get enum_tripField_durationDays => 'Duur';

  @override
  String get enum_tripField_location => 'Locatie';

  @override
  String get enum_tripField_tripType => 'Reistype';

  @override
  String get enum_tripField_resortName => 'Resort';

  @override
  String get enum_tripField_liveaboardName => 'Liveaboard';

  @override
  String get enum_tripField_diveCount => 'Aantal duiken';

  @override
  String get enum_tripField_totalRuntime => 'Totale looptijd';

  @override
  String get enum_tripField_maxDepth => 'Max diepte';

  @override
  String get enum_tripField_avgDepth => 'Gem. diepte';

  @override
  String get enum_tripField_notes => 'Notities';

  @override
  String get enum_tripField_tripName_short => 'Naam';

  @override
  String get enum_tripField_startDate_short => 'Start';

  @override
  String get enum_tripField_endDate_short => 'Eind';

  @override
  String get enum_tripField_durationDays_short => 'Dagen';

  @override
  String get enum_tripField_location_short => 'Locatie';

  @override
  String get enum_tripField_tripType_short => 'Type';

  @override
  String get enum_tripField_resortName_short => 'Resort';

  @override
  String get enum_tripField_liveaboardName_short => 'Liveaboard';

  @override
  String get enum_tripField_diveCount_short => 'Duiken';

  @override
  String get enum_tripField_totalRuntime_short => 'LT totaal';

  @override
  String get enum_tripField_maxDepth_short => 'Max D';

  @override
  String get enum_tripField_avgDepth_short => 'Gem D';

  @override
  String get enum_tripField_notes_short => 'Notities';

  @override
  String get enum_equipmentField_itemName => 'Naam';

  @override
  String get enum_equipmentField_fullName => 'Volledige naam';

  @override
  String get enum_equipmentField_type => 'Type';

  @override
  String get enum_equipmentField_brand => 'Merk';

  @override
  String get enum_equipmentField_model => 'Model';

  @override
  String get enum_equipmentField_serialNumber => 'Serienummer';

  @override
  String get enum_equipmentField_size => 'Maat';

  @override
  String get enum_equipmentField_status => 'Status';

  @override
  String get enum_equipmentField_isActive => 'Actief';

  @override
  String get enum_equipmentField_purchaseDate => 'Aankoopdatum';

  @override
  String get enum_equipmentField_purchasePrice => 'Aankoopprijs';

  @override
  String get enum_equipmentField_lastServiceDate => 'Laatste onderhoud';

  @override
  String get enum_equipmentField_nextServiceDue => 'Volgende onderhoud';

  @override
  String get enum_equipmentField_daysUntilService => 'Dagen tot onderhoud';

  @override
  String get enum_equipmentField_serviceIntervalDays => 'Onderhoudsinterval';

  @override
  String get enum_equipmentField_notes => 'Notities';

  @override
  String get enum_equipmentField_itemName_short => 'Naam';

  @override
  String get enum_equipmentField_fullName_short => 'Voll. naam';

  @override
  String get enum_equipmentField_type_short => 'Type';

  @override
  String get enum_equipmentField_brand_short => 'Merk';

  @override
  String get enum_equipmentField_model_short => 'Model';

  @override
  String get enum_equipmentField_serialNumber_short => 'Serienr.';

  @override
  String get enum_equipmentField_size_short => 'Maat';

  @override
  String get enum_equipmentField_status_short => 'Status';

  @override
  String get enum_equipmentField_isActive_short => 'Actief';

  @override
  String get enum_equipmentField_purchaseDate_short => 'Gekocht';

  @override
  String get enum_equipmentField_purchasePrice_short => 'Prijs';

  @override
  String get enum_equipmentField_lastServiceDate_short => 'Onderh.';

  @override
  String get enum_equipmentField_nextServiceDue_short => 'Volgende';

  @override
  String get enum_equipmentField_daysUntilService_short => 'Resterend';

  @override
  String get enum_equipmentField_serviceIntervalDays_short => 'Interval';

  @override
  String get enum_equipmentField_notes_short => 'Notities';

  @override
  String get enum_diveCenterField_centerName => 'Naam';

  @override
  String get enum_diveCenterField_city => 'Plaats';

  @override
  String get enum_diveCenterField_country => 'Land';

  @override
  String get enum_diveCenterField_stateProvince => 'Staat / Provincie';

  @override
  String get enum_diveCenterField_street => 'Straat';

  @override
  String get enum_diveCenterField_postalCode => 'Postcode';

  @override
  String get enum_diveCenterField_phone => 'Telefoon';

  @override
  String get enum_diveCenterField_email => 'E-mail';

  @override
  String get enum_diveCenterField_website => 'Website';

  @override
  String get enum_diveCenterField_affiliations => 'Aangesloten bij';

  @override
  String get enum_diveCenterField_rating => 'Beoordeling';

  @override
  String get enum_diveCenterField_latitude => 'Breedtegraad';

  @override
  String get enum_diveCenterField_longitude => 'Lengtegraad';

  @override
  String get enum_diveCenterField_diveCount => 'Aantal duiken';

  @override
  String get enum_diveCenterField_notes => 'Notities';

  @override
  String get enum_diveCenterField_centerName_short => 'Naam';

  @override
  String get enum_diveCenterField_city_short => 'Plaats';

  @override
  String get enum_diveCenterField_country_short => 'Land';

  @override
  String get enum_diveCenterField_stateProvince_short => 'Prov.';

  @override
  String get enum_diveCenterField_street_short => 'Straat';

  @override
  String get enum_diveCenterField_postalCode_short => 'Postcode';

  @override
  String get enum_diveCenterField_phone_short => 'Tel.';

  @override
  String get enum_diveCenterField_email_short => 'E-mail';

  @override
  String get enum_diveCenterField_website_short => 'Website';

  @override
  String get enum_diveCenterField_affiliations_short => 'Aangesloten';

  @override
  String get enum_diveCenterField_rating_short => 'Beoord.';

  @override
  String get enum_diveCenterField_latitude_short => 'Breedte';

  @override
  String get enum_diveCenterField_longitude_short => 'Lengte';

  @override
  String get enum_diveCenterField_diveCount_short => 'Duiken';

  @override
  String get enum_diveCenterField_notes_short => 'Notities';

  @override
  String get enum_certificationField_certName => 'Naam';

  @override
  String get enum_certificationField_agency => 'Organisatie';

  @override
  String get enum_certificationField_level => 'Certificering';

  @override
  String get enum_certificationField_cardNumber => 'Kaartnummer';

  @override
  String get enum_certificationField_issueDate => 'Uitgiftedatum';

  @override
  String get enum_certificationField_expiryDate => 'Vervaldatum';

  @override
  String get enum_certificationField_instructorName => 'Naam instructeur';

  @override
  String get enum_certificationField_instructorNumber => 'Instructeurnummer';

  @override
  String get enum_certificationField_expiryStatus => 'Vervalstatus';

  @override
  String get enum_certificationField_notes => 'Notities';

  @override
  String get enum_certificationField_certName_short => 'Naam';

  @override
  String get enum_certificationField_agency_short => 'Org.';

  @override
  String get enum_certificationField_level_short => 'Certificering';

  @override
  String get enum_certificationField_cardNumber_short => 'Kaartnr.';

  @override
  String get enum_certificationField_issueDate_short => 'Uitgifte';

  @override
  String get enum_certificationField_expiryDate_short => 'Verloopt';

  @override
  String get enum_certificationField_instructorName_short => 'Instructeur';

  @override
  String get enum_certificationField_instructorNumber_short => 'Instr.nr.';

  @override
  String get enum_certificationField_expiryStatus_short => 'Status';

  @override
  String get enum_certificationField_notes_short => 'Notities';

  @override
  String get enum_courseField_courseName => 'Naam';

  @override
  String get enum_courseField_agency => 'Organisatie';

  @override
  String get enum_courseField_startDate => 'Startdatum';

  @override
  String get enum_courseField_completionDate => 'Voltooiingsdatum';

  @override
  String get enum_courseField_durationDays => 'Duur';

  @override
  String get enum_courseField_instructorName => 'Naam instructeur';

  @override
  String get enum_courseField_instructorNumber => 'Instructeurnummer';

  @override
  String get enum_courseField_location => 'Locatie';

  @override
  String get enum_courseField_isCompleted => 'Voltooid';

  @override
  String get enum_courseField_notes => 'Notities';

  @override
  String get enum_courseField_courseName_short => 'Naam';

  @override
  String get enum_courseField_agency_short => 'Org.';

  @override
  String get enum_courseField_startDate_short => 'Gestart';

  @override
  String get enum_courseField_completionDate_short => 'Voltooid';

  @override
  String get enum_courseField_durationDays_short => 'Duur';

  @override
  String get enum_courseField_instructorName_short => 'Instructeur';

  @override
  String get enum_courseField_instructorNumber_short => 'Instr.nr.';

  @override
  String get enum_courseField_location_short => 'Locatie';

  @override
  String get enum_courseField_isCompleted_short => 'Klaar';

  @override
  String get enum_courseField_notes_short => 'Notities';

  @override
  String get enum_fieldCategory_accommodation => 'Accommodatie';

  @override
  String get enum_fieldCategory_address => 'Adres';

  @override
  String get enum_fieldCategory_certification => 'Certificering';

  @override
  String get enum_fieldCategory_conditions => 'Omstandigheden';

  @override
  String get enum_fieldCategory_contact => 'Contact';

  @override
  String get enum_fieldCategory_coordinates => 'Coördinaten';

  @override
  String get enum_fieldCategory_dates => 'Datums';

  @override
  String get enum_fieldCategory_depth => 'Diepte';

  @override
  String get enum_fieldCategory_details => 'Details';

  @override
  String get enum_fieldCategory_instructor => 'Instructeur';

  @override
  String get enum_fieldCategory_other => 'Overig';

  @override
  String get enum_fieldCategory_purchase => 'Aankoop';

  @override
  String get enum_fieldCategory_service => 'Onderhoud';

  @override
  String get enum_fieldCategory_statistics => 'Statistieken';

  @override
  String get species_whale_shark_name => 'Walvishaai';

  @override
  String get species_whale_shark_desc =>
      'Grootste vis in de oceaan, een vreedzame filtereter met een kenmerkend gestippeld patroon.';

  @override
  String get species_great_white_shark_name => 'Witte haai';

  @override
  String get species_great_white_shark_desc =>
      'Iconische toppredator die duikers in kooien af en toe in gematigde wateren zien.';

  @override
  String get species_great_hammerhead_shark_name => 'Grote hamerhaai';

  @override
  String get species_great_hammerhead_shark_desc =>
      'Grootste hamerhaaisoort met een brede, platte kop en hoge rugvin.';

  @override
  String get species_scalloped_hammerhead_shark_name => 'Geschulpte hamerhaai';

  @override
  String get species_scalloped_hammerhead_shark_desc =>
      'Wordt vaak in grote scholen gezien bij zeebergen en poetsstations.';

  @override
  String get species_smooth_hammerhead_shark_name => 'Gladde hamerhaai';

  @override
  String get species_smooth_hammerhead_shark_desc =>
      'Hamerhaai met een gladde, afgeronde koprand die in gematigde zeeën voorkomt.';

  @override
  String get species_whitetip_reef_shark_name => 'Witpuntrifhaai';

  @override
  String get species_whitetip_reef_shark_desc =>
      'Rustige rifbewoner die overdag vaak in grotten en onder overhangen ligt te rusten.';

  @override
  String get species_blacktip_reef_shark_name => 'Zwartpuntrifhaai';

  @override
  String get species_blacktip_reef_shark_desc =>
      'Veelvoorkomende rifhaai van ondiep water met kenmerkende zwarte vinpunten.';

  @override
  String get species_grey_reef_shark_name => 'Grijze rifhaai';

  @override
  String get species_grey_reef_shark_desc =>
      'Actieve rifpredator die vaak in groepen langs steilwanden en kanalen wordt gezien.';

  @override
  String get species_caribbean_reef_shark_name => 'Caribische rifhaai';

  @override
  String get species_caribbean_reef_shark_desc =>
      'De meest waargenomen rifhaai van het Caribisch gebied, stevig gebouwd en nieuwsgierig.';

  @override
  String get species_nurse_shark_name => 'Verpleegsterhaai';

  @override
  String get species_nurse_shark_desc =>
      'Traag bewegende bodembewoner die vaak onder koraaloverhangen ligt te rusten.';

  @override
  String get species_tawny_nurse_shark_name => 'Bruine verpleegsterhaai';

  @override
  String get species_tawny_nurse_shark_desc =>
      'Indo-Pacifische bodembewoner die rust in rifgrotten en op zandige plekken.';

  @override
  String get species_bull_shark_name => 'Stierhaai';

  @override
  String get species_bull_shark_desc =>
      'Gedrongen, krachtige haai die wereldwijd in kustwateren en zoet water voorkomt.';

  @override
  String get species_tiger_shark_name => 'Tijgerhaai';

  @override
  String get species_tiger_shark_desc =>
      'Grote predator met een kenmerkend streeppatroon, gezien tijdens diepe rifduiken.';

  @override
  String get species_oceanic_whitetip_shark_name => 'Oceanische witpunthaai';

  @override
  String get species_oceanic_whitetip_shark_desc =>
      'Pelagische haai met ronde, witgepunte vinnen, gezien tijdens duiken op open zee.';

  @override
  String get species_thresher_shark_name => 'Voshaai';

  @override
  String get species_thresher_shark_desc =>
      'Herkenbaar aan de extreem lange staartvin, soms te zien bij poetsstations.';

  @override
  String get species_pelagic_thresher_shark_name => 'Pelagische voshaai';

  @override
  String get species_pelagic_thresher_shark_desc =>
      'Kleinste voshaaisoort, beroemd om de waarnemingen bij Monad Shoal in de Filipijnen.';

  @override
  String get species_shortfin_mako_shark_name => 'Kortvinmakohaai';

  @override
  String get species_shortfin_mako_shark_desc =>
      'Snelste haai van de oceaan, een gestroomlijnde openwaterjager met metaalblauwe kleur.';

  @override
  String get species_blue_shark_name => 'Blauwe haai';

  @override
  String get species_blue_shark_desc =>
      'Slanke, diepblauwe pelagische haai die vaak bij blauwwaterduiken wordt gezien.';

  @override
  String get species_spotted_wobbegong_name => 'Gevlekte wobbegong';

  @override
  String get species_spotted_wobbegong_desc =>
      'Platte, gecamoufleerde tapijthaai die roerloos op rotsriffen in Australië ligt.';

  @override
  String get species_tasselled_wobbegong_name => 'Gefranjerde wobbegong';

  @override
  String get species_tasselled_wobbegong_desc =>
      'Sierlijke tapijthaai met franjeachtige lobben rond de kop, te vinden op koraalriffen.';

  @override
  String get species_epaulette_shark_name => 'Epaulethaai';

  @override
  String get species_epaulette_shark_desc =>
      'Kleine haai die met zijn borstvinnen over de rifbodem loopt.';

  @override
  String get species_horn_shark_name => 'Hoornhaai';

  @override
  String get species_horn_shark_desc =>
      'Nachtactieve bodembewoner met richels boven de ogen, te vinden voor de kust van Californië.';

  @override
  String get species_leopard_shark_name => 'Luipaardhaai';

  @override
  String get species_leopard_shark_desc =>
      'Prachtig getekende haai die voorkomt in ondiepe baaien langs de Amerikaanse Pacifische kust.';

  @override
  String get species_pacific_angel_shark_name => 'Pacifische zee-engel';

  @override
  String get species_pacific_angel_shark_desc =>
      'Platte hinderlaagjager die ingegraven in het zand op de zeebodem ligt.';

  @override
  String get species_sand_tiger_shark_name => 'Zandtijgerhaai';

  @override
  String get species_sand_tiger_shark_desc =>
      'Grimmig ogende maar vreedzame haai die vaak zwevend in grotten en wrakken wordt gezien.';

  @override
  String get species_zebra_shark_name => 'Zebrahaai';

  @override
  String get species_zebra_shark_desc =>
      'Gevlekte rifhaai die op zandbodems rust, algemeen in de Indo-Pacific.';

  @override
  String get species_blacktip_shark_name => 'Zwartpunthaai';

  @override
  String get species_blacktip_shark_desc =>
      'Snelle kusthaai die bekendstaat om zijn draaiende sprongen, wereldwijd in warme wateren.';

  @override
  String get species_silvertip_shark_name => 'Zilverpunthaai';

  @override
  String get species_silvertip_shark_desc =>
      'Brutale rifhaai met witomrande vinnen, te vinden bij diepe steilwanden en atollen.';

  @override
  String get species_silky_shark_name => 'Zijdehaai';

  @override
  String get species_silky_shark_desc =>
      'Gestroomlijnde pelagische haai met gladde huid, vaak nabij riffen in open water.';

  @override
  String get species_lemon_shark_name => 'Citroenhaai';

  @override
  String get species_lemon_shark_desc =>
      'Geelbruine haai die vaak wordt gezien in ondiepe mangroven en op zandvlaktes.';

  @override
  String get species_galapagos_shark_name => 'Galapagoshaai';

  @override
  String get species_galapagos_shark_desc =>
      'Grote rifhaai rond oceanische eilanden, nieuwsgierig naar duikers.';

  @override
  String get species_port_jackson_shark_name => 'Port Jackson-haai';

  @override
  String get species_port_jackson_shark_desc =>
      'Nachtactieve bodembewoner met harnasachtige tekening, endemisch in Australië.';

  @override
  String get species_bamboo_shark_name => 'Bruingebande bamboehaai';

  @override
  String get species_bamboo_shark_desc =>
      'Kleine, rustige bodembewonende haai, algemeen op Indo-Pacifische koraalriffen.';

  @override
  String get species_basking_shark_name => 'Reuzenhaai';

  @override
  String get species_basking_shark_desc =>
      'Op een na grootste vis, een filtereter die in gematigde oppervlaktewateren wordt gezien.';

  @override
  String get species_greenland_shark_name => 'Groenlandse haai';

  @override
  String get species_greenland_shark_desc =>
      'Traag bewegende diepwaterhaai, een van de langstlevende gewervelden op aarde.';

  @override
  String get species_cookiecutter_shark_name => 'Sigaarhaai';

  @override
  String get species_cookiecutter_shark_desc =>
      'Kleine diepwaterhaai die ronde happen uit grotere zeedieren neemt.';

  @override
  String get species_sevengill_shark_name => 'Breedsnuitzevenkieuwshaai';

  @override
  String get species_sevengill_shark_desc =>
      'Primitieve haai met zeven kieuwspleten, te ontmoeten bij duiken in gematigde kelpwouden.';

  @override
  String get species_pyjama_shark_name => 'Pyjamahaai';

  @override
  String get species_pyjama_shark_desc =>
      'Gestreepte kathaai endemisch in Zuid-Afrika, te vinden op rotsriffen en in kelpwouden.';

  @override
  String get species_spiny_dogfish_name => 'Doornhaai';

  @override
  String get species_spiny_dogfish_desc =>
      'Kleine, talrijke haai met giftige rugstekels, voorkomend in gematigde wateren.';

  @override
  String get species_swell_shark_name => 'Zwelhaai';

  @override
  String get species_swell_shark_desc =>
      'Nachtactieve kathaai die zijn lichaam opblaast bij gevaar, voor de kust van Californië.';

  @override
  String get species_giant_oceanic_manta_ray_name => 'Reuzenmanta';

  @override
  String get species_giant_oceanic_manta_ray_desc =>
      'Grootste roggensoort, een majestueuze filtereter met een spanwijdte tot 7 meter.';

  @override
  String get species_reef_manta_ray_name => 'Rifmanta';

  @override
  String get species_reef_manta_ray_desc =>
      'Kleinere mantasoort die vaak bij poetsstations op tropische riffen wordt gezien.';

  @override
  String get species_spotted_eagle_ray_name => 'Gevlekte adelaarsrog';

  @override
  String get species_spotted_eagle_ray_desc =>
      'Elegante rog met witte stippen en een lange zweepachtige staart, vaak in het middenwater.';

  @override
  String get species_common_eagle_ray_name => 'Gewone adelaarsrog';

  @override
  String get species_common_eagle_ray_desc =>
      'Ruitvormige rog uit de gematigde oostelijke Atlantische Oceaan en de Middellandse Zee.';

  @override
  String get species_blue_spotted_ribbontail_ray_name =>
      'Blauwgevlekte pijlstaartrog';

  @override
  String get species_blue_spotted_ribbontail_ray_desc =>
      'Felgekleurde rog met heldere blauwe stippen, algemeen op Indo-Pacifische riffen.';

  @override
  String get species_blue_spotted_stingray_name => 'Blauwgestippelde maskerrog';

  @override
  String get species_blue_spotted_stingray_desc =>
      'Kleine rifrog met verspreide blauwe stippen, vaak ingegraven in zandige plekken.';

  @override
  String get species_southern_stingray_name => 'Zuidelijke pijlstaartrog';

  @override
  String get species_southern_stingray_desc =>
      'Grote pijlstaartrog van Caribische zandvlaktes, beroemd bij Stingray City.';

  @override
  String get species_round_stingray_name => 'Ronde pijlstaartrog';

  @override
  String get species_round_stingray_desc =>
      'Kleine ronde pijlstaartrog, algemeen in ondiepe zandgebieden van de oostelijke Pacific.';

  @override
  String get species_short_tail_stingray_name => 'Kortstaartpijlstaartrog';

  @override
  String get species_short_tail_stingray_desc =>
      'Een van de grootste pijlstaartroggen, voorkomend in gematigde wateren van het zuidelijk halfrond.';

  @override
  String get species_cowtail_stingray_name => 'Koestaartrog';

  @override
  String get species_cowtail_stingray_desc =>
      'Grote donkere pijlstaartrog met een kenmerkende vlagachtige staartplooi, op zandige riffen.';

  @override
  String get species_atlantic_torpedo_ray_name => 'Atlantische sidderrog';

  @override
  String get species_atlantic_torpedo_ray_desc =>
      'Sidderrog die sterke schokken kan afgeven, te vinden op Atlantische zandbodems.';

  @override
  String get species_marbled_electric_ray_name => 'Gemarmerde sidderrog';

  @override
  String get species_marbled_electric_ray_desc =>
      'Mediterrane sidderrog met gemarmerd patroon die een flinke elektrische schok geeft.';

  @override
  String get species_giant_guitarfish_name => 'Reuzengitaarrog';

  @override
  String get species_giant_guitarfish_desc =>
      'Haaivormige rog op Indo-Pacifische zandbodems nabij koraalriffen.';

  @override
  String get species_shovelnose_guitarfish_name => 'Schopneusgitaarrog';

  @override
  String get species_shovelnose_guitarfish_desc =>
      'Afgeplatte vorm tussen rog en haai in, algemeen in zandige ondiepten van de oostelijke Pacific.';

  @override
  String get species_smalltooth_sawfish_name => 'Kleintandzaagvis';

  @override
  String get species_smalltooth_sawfish_desc =>
      'Ernstig bedreigde rog met een getande snuit, voorkomend in tropische kustwateren.';

  @override
  String get species_green_sawfish_name => 'Groene zaagvis';

  @override
  String get species_green_sawfish_desc =>
      'Grote zaagvis met olijfgroen lichaam die in estuaria van de Indo-West-Pacific leeft.';

  @override
  String get species_devil_ray_name => 'Reuzenduivelsrog';

  @override
  String get species_devil_ray_desc =>
      'Grote mobularog met kopvinnen, te zien wanneer groepen uit het water springen.';

  @override
  String get species_spinetail_devil_ray_name => 'Stekelstaartduivelsrog';

  @override
  String get species_spinetail_devil_ray_desc =>
      'Pelagische duivelsrog die vaak in grote groepen vlak onder het oppervlak wordt gezien.';

  @override
  String get species_lesser_devil_ray_name => 'Dwergduivelsrog';

  @override
  String get species_lesser_devil_ray_desc =>
      'Kleinste mobulasoort, vormt grote scholen in de Golf van Californië.';

  @override
  String get species_bat_ray_name => 'Vleermuisrog';

  @override
  String get species_bat_ray_desc =>
      'Ruitvormige rog, algemeen in kelpwouden en zandige baaien van Californië.';

  @override
  String get species_undulate_ray_name => 'Golfrog';

  @override
  String get species_undulate_ray_desc =>
      'Prachtig getekende rog met golvende lijnen, voorkomend in de oostelijke Atlantische Oceaan.';

  @override
  String get species_thornback_ray_name => 'Stekelrog';

  @override
  String get species_thornback_ray_desc =>
      'Algemene Europese rog met doornachtige stekels langs rug en staart.';

  @override
  String get species_cownose_ray_name => 'Koeneusrog';

  @override
  String get species_cownose_ray_desc =>
      'Kenmerkende ingekeepte kop, vaak in grote scholen tijdens seizoenstrek.';

  @override
  String get species_marble_ray_name => 'Gemarmerde pijlstaartrog';

  @override
  String get species_marble_ray_desc =>
      'Grote donkere pijlstaartrog met witte stippen, vaak gezien bij Indo-Pacifische poetsstations.';

  @override
  String get species_ocellate_river_stingray_name => 'Gevlekte zoetwaterrog';

  @override
  String get species_ocellate_river_stingray_desc =>
      'Zoetwaterpijlstaartrog met opvallende oranje omringde vlekken, inheems in Zuid-Amerikaanse rivieren.';

  @override
  String get species_ocellaris_clownfish_name => 'Valse clownvis';

  @override
  String get species_ocellaris_clownfish_desc =>
      'Kleine oranje-wit gestreepte vis die op koraalriffen in symbiose met zeeanemonen leeft.';

  @override
  String get species_clarkii_clownfish_name => 'Clarks anemoonvis';

  @override
  String get species_clarkii_clownfish_desc =>
      'Robuuste anemoonvis met donker lichaam en twee witte banden, in de hele Indo-Pacific in uiteenlopende anemonen.';

  @override
  String get species_tomato_clownfish_name => 'Tomatenanemoonvis';

  @override
  String get species_tomato_clownfish_desc =>
      'Felrood-oranje anemoonvis met één witte kopband, algemeen op Indo-Pacifische riffen.';

  @override
  String get species_regal_blue_tang_name => 'Blauwe doktersvis';

  @override
  String get species_regal_blue_tang_desc =>
      'Felblauwe doktersvis met zwarte palettekening en gele staart, op Indo-Pacifische koraalriffen.';

  @override
  String get species_yellow_tang_name => 'Gele doktersvis';

  @override
  String get species_yellow_tang_desc =>
      'Felgele doktersvis, algemeen op Hawaïaanse en Pacifische riffen, vaak in groepen algen grazend.';

  @override
  String get species_powder_blue_surgeonfish_name => 'Poederblauwe doktersvis';

  @override
  String get species_powder_blue_surgeonfish_desc =>
      'Opvallende lichtblauwe doktersvis met zwart gezicht en gele rugvin, voorkomend in de Indische Oceaan.';

  @override
  String get species_sohal_surgeonfish_name => 'Sohal-doktersvis';

  @override
  String get species_sohal_surgeonfish_desc =>
      'Brutale gestreepte doktersvis met oranje scalpelstekel, endemisch op riffen van de Rode Zee en de Arabische Golf.';

  @override
  String get species_blue_tang_name => 'Blauwe chirurgijnvis';

  @override
  String get species_blue_tang_desc =>
      'Diepblauwe doktersvis, algemeen op Caribische riffen; jongen zijn felgeel.';

  @override
  String get species_emperor_angelfish_name => 'Keizersengelvis';

  @override
  String get species_emperor_angelfish_desc =>
      'Grote engelvis met opvallende blauwe en gele horizontale strepen. Jongen tonen concentrische blauwe en witte ringen.';

  @override
  String get species_french_angelfish_name => 'Franse engelvis';

  @override
  String get species_french_angelfish_desc =>
      'Grote donkere engelvis met goudomrande schubben, meestal in paren op Caribische en West-Atlantische riffen.';

  @override
  String get species_queen_angelfish_name => 'Koninginne-engelvis';

  @override
  String get species_queen_angelfish_desc =>
      'Spectaculaire blauw-gele engelvis met een kenmerkende kroonvlek, te vinden op Caribische koraalriffen.';

  @override
  String get species_regal_angelfish_name => 'Koninklijke engelvis';

  @override
  String get species_regal_angelfish_desc =>
      'Elegante engelvis met afwisselend oranje-witte en blauwe verticale banden, op Indo-Pacifische riffen.';

  @override
  String get species_rock_beauty_name => 'Rotsengelvis';

  @override
  String get species_rock_beauty_desc =>
      'Opvallende Caribische engelvis met gele voorhelft en zwarte achterhelft, bij rotsriffen en overhangen.';

  @override
  String get species_gray_angelfish_name => 'Grijze engelvis';

  @override
  String get species_gray_angelfish_desc =>
      'Grote grijze engelvis met bleek gezicht en gele binnenkant van de borstvin, algemeen op Caribische riffen.';

  @override
  String get species_copperband_butterflyfish_name => 'Koperbandvlindervis';

  @override
  String get species_copperband_butterflyfish_desc =>
      'Kenmerkende vlindervis met oranje verticale banden en langgerekte snuit, op Indo-Pacifische riffen.';

  @override
  String get species_raccoon_butterflyfish_name => 'Wasbeervlindervis';

  @override
  String get species_raccoon_butterflyfish_desc =>
      'Gele vlindervis met een donker wasbeerachtig oogmasker, algemeen op Indo-Pacifische en Hawaïaanse riffen.';

  @override
  String get species_longnose_butterflyfish_name => 'Langsnuitvlindervis';

  @override
  String get species_longnose_butterflyfish_desc =>
      'Felgele vlindervis met een extreem lange snuit om voedsel uit spleten van Indo-Pacifische riffen te pikken.';

  @override
  String get species_threadfin_butterflyfish_name => 'Draadvinvlindervis';

  @override
  String get species_threadfin_butterflyfish_desc =>
      'Witte vlindervis met chevronpatroon en een slepende rugvindraad, wijdverbreid in de Indo-Pacific.';

  @override
  String get species_foureye_butterflyfish_name => 'Vierogenvlindervis';

  @override
  String get species_foureye_butterflyfish_desc =>
      'Bleke vlindervis met een opvallende valse oogvlek bij de staart, algemeen op Caribische riffen.';

  @override
  String get species_spotfin_butterflyfish_name => 'Vlekvinvlindervis';

  @override
  String get species_spotfin_butterflyfish_desc =>
      'Wit-gele vlindervis met een klein donker vlekje op de rugvin, voorkomend in de westelijke Atlantische Oceaan.';

  @override
  String get species_banner_butterflyfish_name => 'Rodezeewimpelvis';

  @override
  String get species_banner_butterflyfish_desc =>
      'Zwart-witte wimpelvis met langgerekte rugvin en gele buik, endemisch in de Rode Zee.';

  @override
  String get species_moorish_idol_name => 'Moorse afgod';

  @override
  String get species_moorish_idol_desc =>
      'Iconische rifvis met markante zwarte, witte en gele banden en een lange slepende rugvindraad.';

  @override
  String get species_green_moray_eel_name => 'Groene murene';

  @override
  String get species_green_moray_eel_desc =>
      'Grote groene murene tot 2,5 m, vaak met open bek in rifspleten in de westelijke Atlantische Oceaan.';

  @override
  String get species_giant_moray_eel_name => 'Reuzenmurene';

  @override
  String get species_giant_moray_eel_desc =>
      'De grootste murenesoort, ruim 3 m lang, met luipaardachtige vlekken. Te vinden op Indo-Pacifische koraalriffen.';

  @override
  String get species_spotted_moray_eel_name => 'Gevlekte murene';

  @override
  String get species_spotted_moray_eel_desc =>
      'Witte murene met donkerbruine vlekken, vaak turend vanuit rifholtes in het Caribisch gebied.';

  @override
  String get species_ribbon_eel_name => 'Lintmurene';

  @override
  String get species_ribbon_eel_desc =>
      'Slanke murene met wijde neusvleugels; mannetjes zijn felblauw, vrouwtjes geel. Te vinden in zandige Indo-Pacifische lagunes.';

  @override
  String get species_spotted_garden_eel_name => 'Gevlekte tuinaal';

  @override
  String get species_spotted_garden_eel_desc =>
      'Dunne witte aal met zwarte stippen die in zandkolonies leeft en meedeint met de stroming om plankton te vangen.';

  @override
  String get species_splendid_garden_eel_name => 'Prachttuinaal';

  @override
  String get species_splendid_garden_eel_desc =>
      'Oranje-wit gebande tuinaal die in grote zandkolonies in de westelijke Pacific leeft.';

  @override
  String get species_snowflake_moray_name => 'Sneeuwvlokmurene';

  @override
  String get species_snowflake_moray_desc =>
      'Kleine murene met wit lichaam en zwarte sneeuwvlokachtige tekening, algemeen in Indo-Pacifisch rifpuin.';

  @override
  String get species_mandarin_dragonet_name => 'Mandarijnvis';

  @override
  String get species_mandarin_dragonet_desc =>
      'Piepkleine, schitterend gekleurde vis met psychedelische blauwe en oranje patronen, in puinzones van de westelijke Pacific.';

  @override
  String get species_common_lionfish_name => 'Koraalduivel';

  @override
  String get species_common_lionfish_desc =>
      'Giftige schorpioenvis met spectaculaire waaiervormige borstvinnen en rood-witte strepen. Invasief in het Caribisch gebied.';

  @override
  String get species_leaf_scorpionfish_name => 'Bladschorpioenvis';

  @override
  String get species_leaf_scorpionfish_desc =>
      'Sterk zijdelings afgeplatte, bladvormige schorpioenvis die met de stroming meedeint om drijfvuil na te bootsen op Indo-Pacifische riffen.';

  @override
  String get species_stonefish_name => 'Steenvis';

  @override
  String get species_stonefish_desc =>
      'Giftigste vis ter wereld, perfect gecamoufleerd als steen op Indo-Pacifische rifbodems. Uiterst gevaarlijk.';

  @override
  String get species_painted_frogfish_name => 'Geschilderde voelsprietvis';

  @override
  String get species_painted_frogfish_desc =>
      'Gedrongen hinderlaagjager met een hengel op de kop, sterk wisselend van kleur. Te vinden op Indo-Pacifische riffen.';

  @override
  String get species_giant_frogfish_name => 'Reuzenvoelsprietvis';

  @override
  String get species_giant_frogfish_desc =>
      'De grootste voelsprietvissoort, tot 40 cm, met uitstekende camouflage tussen sponzen en koraalpuin.';

  @override
  String get species_hairy_frogfish_name => 'Harige voelsprietvis';

  @override
  String get species_hairy_frogfish_desc =>
      'Voelsprietvis bedekt met wormachtige vleesuitsteeksels die algen nabootsen, een geliefde vondst voor onderwaterfotografen.';

  @override
  String get species_clown_triggerfish_name => 'Clowntrekkervis';

  @override
  String get species_clown_triggerfish_desc =>
      'Opvallend getekende trekkervis met grote witte vlekken op een donker lichaam en gele lippen, op Indo-Pacifische riffen.';

  @override
  String get species_titan_triggerfish_name => 'Titaantrekkervis';

  @override
  String get species_titan_triggerfish_desc =>
      'Grote agressieve trekkervis die duikers bij zijn nest kan aanvallen. Algemeen op Indo-Pacifische koraalriffen.';

  @override
  String get species_queen_triggerfish_name => 'Koninginnetrekkervis';

  @override
  String get species_queen_triggerfish_desc =>
      'Kleurrijke Caribische trekkervis met blauwe gezichtstekening en lange staartslierten.';

  @override
  String get species_picasso_triggerfish_name => 'Picassotrekkervis';

  @override
  String get species_picasso_triggerfish_desc =>
      'Trekkervis met een abstract patroon van blauwe, gele en zwarte strepen, algemeen op Indo-Pacifische rifplaten.';

  @override
  String get species_yellowmargin_triggerfish_name => 'Geelrandtrekkervis';

  @override
  String get species_yellowmargin_triggerfish_desc =>
      'Grote lichtbruine trekkervis met geelomrande vinnen, berucht om het agressief bewaken van zijn nest op Indo-Pacifische riffen.';

  @override
  String get species_porcupinefish_name => 'Egelvis';

  @override
  String get species_porcupinefish_desc =>
      'Grote stekelige vis die zich bij gevaar tot een bal opblaast, wereldwijd op tropische riffen.';

  @override
  String get species_guineafowl_pufferfish_name => 'Parelhoenkogelvis';

  @override
  String get species_guineafowl_pufferfish_desc =>
      'Donkere kogelvis bedekt met kleine witte stippen, soms in een goudgele kleurfase op Indo-Pacifische riffen.';

  @override
  String get species_map_pufferfish_name => 'Landkaartkogelvis';

  @override
  String get species_map_pufferfish_desc =>
      'Grote bleke kogelvis met fijne donkere landkaartachtige tekening over het hele lichaam, op Indo-Pacifische riffen.';

  @override
  String get species_sharpnose_pufferfish_name => 'Spitssnuitkogelvis';

  @override
  String get species_sharpnose_pufferfish_desc =>
      'Piepkleine kogelvis met blauwe lijnen op het gezicht en een oranje staart, veel gezien op Caribische riffen.';

  @override
  String get species_boxfish_name => 'Gele koffervis';

  @override
  String get species_boxfish_desc =>
      'Jongen zijn felgele kubusjes met zwarte stippen. Volwassen dieren verkleuren naar blauwgrijs. Voorkomend in de hele Indo-Pacific.';

  @override
  String get species_cowfish_name => 'Langhoornkoffervis';

  @override
  String get species_cowfish_desc =>
      'Hoekige gele vis met kenmerkende hoornachtige uitsteeksels boven elk oog, op Indo-Pacifische riffen.';

  @override
  String get species_napoleon_wrasse_name => 'Napoleonvis';

  @override
  String get species_napoleon_wrasse_desc =>
      'Kolossale lipvis tot 2 m met een prominente kopbult. Bedreigd en beschermd, te vinden op Indo-Pacifische riffen.';

  @override
  String get species_cleaner_wrasse_name => 'Blauwstreeppoetslipvis';

  @override
  String get species_cleaner_wrasse_desc =>
      'Kleine blauwgestreepte lipvis die poetsstations bemant en parasieten van grotere vissen verwijdert op Indo-Pacifische riffen.';

  @override
  String get species_yellowtail_coris_name => 'Geelstaartlipvis';

  @override
  String get species_yellowtail_coris_desc =>
      'Kleurrijke lipvis met gevlekt lichaam en gele staart; jongen zijn feloranjerood met witte tekening.';

  @override
  String get species_bluehead_wrasse_name => 'Blauwkoplipvis';

  @override
  String get species_bluehead_wrasse_desc =>
      'Talrijke Caribische lipvis; mannetjes in de eindfase hebben een felblauwe kop en groen lichaam met zwart-witte banden.';

  @override
  String get species_spanish_hogfish_name => 'Spaanse varkenslipvis';

  @override
  String get species_spanish_hogfish_desc =>
      'Paars-gele lipvis, algemeen op Caribische riffen; jongen gedragen zich als poetsvissen.';

  @override
  String get species_bumphead_parrotfish_name => 'Bultkoppapegaaivis';

  @override
  String get species_bumphead_parrotfish_desc =>
      'Grootste papegaaivissoort tot 1,3 m, met een enorme kopbult. Trekt in scholen over Indo-Pacifische riffen.';

  @override
  String get species_stoplight_parrotfish_name => 'Stoplichtpapegaaivis';

  @override
  String get species_stoplight_parrotfish_desc =>
      'Algemene Caribische papegaaivis met dramatische kleurverschillen tussen begin- en eindfase.';

  @override
  String get species_queen_parrotfish_name => 'Koninginnepapegaaivis';

  @override
  String get species_queen_parrotfish_desc =>
      'Grote blauwgroene papegaaivis op Caribische riffen, vaak te zien terwijl hij koraal afbijt om algen te eten.';

  @override
  String get species_yellowtail_damselfish_name => 'Geelstaartjuffervis';

  @override
  String get species_yellowtail_damselfish_desc =>
      'Donkerblauwe juffervis met een felgele staart, algemeen op Caribische riftoppen en -kammen.';

  @override
  String get species_sergeant_major_name => 'Sergeant-majoor';

  @override
  String get species_sergeant_major_desc =>
      'Zilvergele juffervis met vijf markante zwarte banden, in grote groepen op tropische Atlantische riffen.';

  @override
  String get species_three_spot_damselfish_name => 'Drievlekjuffervis';

  @override
  String get species_three_spot_damselfish_desc =>
      'Donkerbruine territoriale juffervis die zijn algentuin fel verdedigt op Caribische riffen.';

  @override
  String get species_chromis_viridis_name => 'Blauwgroene chromis';

  @override
  String get species_chromis_viridis_desc =>
      'Kleine iriserend groene juffervis die in grote scholen boven vertakte koralen op Indo-Pacifische riffen zweeft.';

  @override
  String get species_blue_chromis_name => 'Blauwe chromis';

  @override
  String get species_blue_chromis_desc =>
      'Schitterend blauwe planktonetende juffervis in grote groepen in het middenwater boven Caribische rifwanden.';

  @override
  String get species_nassau_grouper_name => 'Nassau-tandbaars';

  @override
  String get species_nassau_grouper_desc =>
      'Grote Caribische tandbaars met kenmerkende donkere oogstreep en bandenpatroon, nu bedreigd door overbevissing.';

  @override
  String get species_giant_grouper_name => 'Reuzentandbaars';

  @override
  String get species_giant_grouper_desc =>
      'De grootste beenvis van het rif, tot 2,7 m en 400 kg. Te vinden in grotten en wrakken in de hele Indo-Pacific.';

  @override
  String get species_coral_grouper_name => 'Koraaltandbaars';

  @override
  String get species_coral_grouper_desc =>
      'Felrood-oranje tandbaars bedekt met blauwe stippen, een kenmerkende soort van Indo-Pacifische koraalriffen.';

  @override
  String get species_goliath_grouper_name => 'Goliathtandbaars';

  @override
  String get species_goliath_grouper_desc =>
      'Kolossale Atlantische tandbaars tot 2,5 m, vaak te zien bij wrakken en overhangen in Florida en het Caribisch gebied.';

  @override
  String get species_potato_grouper_name => 'Aardappeltandbaars';

  @override
  String get species_potato_grouper_desc =>
      'Grote, gezellige tandbaars met donkere aardappelvormige vlekken, beroemd bij Cod Hole op het Great Barrier Reef.';

  @override
  String get species_peacock_grouper_name => 'Pauwtandbaars';

  @override
  String get species_peacock_grouper_desc =>
      'Donkerbruine tandbaars met felblauwe stippen en bleke verticale banden achteraan, algemeen op Indo-Pacifische riffen.';

  @override
  String get species_yellowfin_tuna_name => 'Geelvintonijn';

  @override
  String get species_yellowfin_tuna_desc =>
      'Snelle pelagische jager met lange gele rug- en aarsvin, af en toe door duikers gezien op offshore stekken.';

  @override
  String get species_dogtooth_tuna_name => 'Hondstandtonijn';

  @override
  String get species_dogtooth_tuna_desc =>
      'Krachtige rifgebonden tonijn met opvallende tanden, te ontmoeten bij diepe rifsteilwanden in de Indo-Pacific.';

  @override
  String get species_great_barracuda_name => 'Grote barracuda';

  @override
  String get species_great_barracuda_desc =>
      'Gestroomlijnde zilveren jager tot 1,8 m met forse tanden, vaak roerloos zwevend bij tropische riffen.';

  @override
  String get species_blackfin_barracuda_name => 'Zwartvinbarracuda';

  @override
  String get species_blackfin_barracuda_desc =>
      'Indo-Pacifische barracuda die berucht is om de enorme tornado-achtige scholen op stekken als Barracuda Point.';

  @override
  String get species_mahi_mahi_name => 'Goudmakreel';

  @override
  String get species_mahi_mahi_desc =>
      'Oogverblindend blauwgroen-gouden pelagische vis met stomp voorhoofd, soms te zien op offshore duikstekken.';

  @override
  String get species_giant_trevally_name => 'Reuzenmakreel';

  @override
  String get species_giant_trevally_desc =>
      'Krachtige zilveren jager tot 1,7 m, bekend om zijn jachten in rifkanalen en langs steilwanden in de Indo-Pacific.';

  @override
  String get species_bluefin_trevally_name => 'Blauwvinmakreel';

  @override
  String get species_bluefin_trevally_desc =>
      'Gestroomlijnde blauwgestippelde makreel die in kleine jachtgroepen langs Indo-Pacifische rifranden patrouilleert.';

  @override
  String get species_bigeye_trevally_name => 'Grootoogmakreel';

  @override
  String get species_bigeye_trevally_desc =>
      'Zilveren makreel met grote ogen die indrukwekkende wervelende scholen vormt bij rifwanden en poetsstations.';

  @override
  String get species_bar_jack_name => 'Bandmakreel';

  @override
  String get species_bar_jack_desc =>
      'Gestroomlijnde zilveren Caribische makreel met een kenmerkende donkerblauwe streep over de rug tot in de onderste staartlob.';

  @override
  String get species_horse_eye_jack_name => 'Paardenoogmakreel';

  @override
  String get species_horse_eye_jack_desc =>
      'Zilveren makreel met grote ogen die scholen vormt bij riffen en wrakken in het Caribisch gebied en de westelijke Atlantische Oceaan.';

  @override
  String get species_yellowtail_snapper_name => 'Geelstaartsnapper';

  @override
  String get species_yellowtail_snapper_desc =>
      'Gestroomlijnde snapper met een gele zijstreep en staart, vaak in scholen in het middenwater op Caribische riffen.';

  @override
  String get species_schoolmaster_snapper_name => 'Schoolmeestersnapper';

  @override
  String get species_schoolmaster_snapper_desc =>
      'Geel-zilveren snapper met blauwe lijnen onder het oog, in groepen onder overhangen op Caribische riffen.';

  @override
  String get species_bluestripe_snapper_name => 'Blauwstreepsnapper';

  @override
  String get species_bluestripe_snapper_desc =>
      'Felgele snapper met vier blauwe horizontale strepen die dichte scholen vormt op Indo-Pacifische riffen.';

  @override
  String get species_twinspot_snapper_name => 'Tweevleksnapper';

  @override
  String get species_twinspot_snapper_desc =>
      'Grote rode snapper op Indo-Pacifische buitenriffen, soms in scholen langs diepe wanden en kanalen.';

  @override
  String get species_humphead_snapper_name => 'Middernachtsnapper';

  @override
  String get species_humphead_snapper_desc =>
      'Grote donkere snapper in scholen bij steile Indo-Pacifische steilwanden; jongen zijn markant zwart-wit.';

  @override
  String get species_longfin_bannerfish_name => 'Langvinwimpelvis';

  @override
  String get species_longfin_bannerfish_desc =>
      'Zwart-witte vis met een lange slepende rugvin en gele staart, vaak in paren op Indo-Pacifische riffen.';

  @override
  String get species_batfish_orbicular_name => 'Ronde vleermuisvis';

  @override
  String get species_batfish_orbicular_desc =>
      'Zilveren schijfvormige vis met hoge vinnen die nieuwsgierig op duikers afkomt. Algemeen bij Indo-Pacifische wrakken en riffen.';

  @override
  String get species_batfish_teira_name => 'Langvinvleermuisvis';

  @override
  String get species_batfish_teira_desc =>
      'Vleermuisvis met hoge vinnen en een donkere vlek bij de borstvin, vaak te zien bij poetsstations en wrakken.';

  @override
  String get species_batfish_pinnatus_name => 'Geveerde vleermuisvis';

  @override
  String get species_batfish_pinnatus_desc =>
      'Jongen zijn gitzwart met felle oranje randen en lijken op een giftige platworm. Te vinden in de westelijke Pacific.';

  @override
  String get species_banggai_cardinalfish_name => 'Banggai-kardinaalvis';

  @override
  String get species_banggai_cardinalfish_desc =>
      'Opvallende zilver-zwarte kardinaalvis met langgerekte vinnen, endemisch op de Banggai-eilanden van Indonesië.';

  @override
  String get species_pajama_cardinalfish_name => 'Pyjamakardinaalvis';

  @override
  String get species_pajama_cardinalfish_desc =>
      'Bijzondere kardinaalvis met geel gezicht, donkere middenband en gevlekte achterkant, tussen koralen in de Indo-Pacific.';

  @override
  String get species_longnose_hawkfish_name => 'Langsnuitkoraalwachter';

  @override
  String get species_longnose_hawkfish_desc =>
      'Kleine witte vis met rood ruitpatroon en langgerekte snuit, zit vaak op gorgonen en zwarte koralen.';

  @override
  String get species_arc_eye_hawkfish_name => 'Boogoogkoraalwachter';

  @override
  String get species_arc_eye_hawkfish_desc =>
      'Kleine koraalwachter met een kenmerkende oranje boog achter het oog, meestal op koraalkoppen op Indo-Pacifische riffen.';

  @override
  String get species_flame_hawkfish_name => 'Vlamkoraalwachter';

  @override
  String get species_flame_hawkfish_desc =>
      'Schitterend rode koraalwachter met donkere oogtekening, zittend in Pocillopora-koralen in de westelijke Pacific.';

  @override
  String get species_fire_goby_name => 'Vuurgrondel';

  @override
  String get species_fire_goby_desc =>
      'Elegante witte grondel met een hoge eerste rugvin en roodoranje staart, zweeft boven Indo-Pacifisch rifpuin.';

  @override
  String get species_purple_firefish_name => 'Purperen vuurgrondel';

  @override
  String get species_purple_firefish_desc =>
      'Tere grondel met paarse vinnen en een hoge rugvinstekel, zwevend bij holen op Indo-Pacifische buitenriffen.';

  @override
  String get species_yellownose_goby_name => 'Geelsnuitgrondel';

  @override
  String get species_yellownose_goby_desc =>
      'Piepkleine Caribische poetsgrondel met gele snuit en blauwe zijstreep, te vinden op sponzen en koraalkoppen.';

  @override
  String get species_citron_goby_name => 'Citroengrondel';

  @override
  String get species_citron_goby_desc =>
      'Piepkleine felgele grondel die tussen de takken van Acropora-koralen op Indo-Pacifische riffen leeft.';

  @override
  String get species_shrimp_goby_name => 'Steinitz\' garnaalgrondel';

  @override
  String get species_shrimp_goby_desc =>
      'Zandkleurige grondel die op Indo-Pacifische zandvlaktes een hol deelt met alfeïde garnalen in een wederzijds voordelige samenwerking.';

  @override
  String get species_neon_goby_name => 'Neongrondel';

  @override
  String get species_neon_goby_desc =>
      'Piepkleine donkere grondel met een schitterend neonblauwe streep die poetsstations bemant op Caribische koraalkoppen.';

  @override
  String get species_bluestriped_fangblenny_name =>
      'Blauwgestreepte sabeltandslijmvis';

  @override
  String get species_bluestriped_fangblenny_desc =>
      'Kleine blauwgestreepte slijmvis die poetslipvissen nabootst om schubben van nietsvermoedende vissen te bijten.';

  @override
  String get species_sailfin_blenny_name => 'Zeilvinslijmvis';

  @override
  String get species_sailfin_blenny_desc =>
      'Piepkleine Caribische slijmvis die vanuit zijn kokerwoning een grote zeilvormige rugvin opzet om partners te lokken.';

  @override
  String get species_bicolor_blenny_name => 'Tweekleurige slijmvis';

  @override
  String get species_bicolor_blenny_desc =>
      'Kleine slijmvis met donkerbruine voorhelft en oranje achterhelft, turend vanuit holletjes op Indo-Pacifische riffen.';

  @override
  String get species_redlip_blenny_name => 'Roodlipslijmvis';

  @override
  String get species_redlip_blenny_desc =>
      'Donkere slijmvis met opvallende roodoranje lippen die algenplekken op Caribische rifkammen verdedigt.';

  @override
  String get species_pygmy_seahorse_name => 'Bargibants dwergzeepaardje';

  @override
  String get species_pygmy_seahorse_desc =>
      'Piepklein zeepaardje van minder dan 2 cm dat perfect versmelt met zijn gorgoon, een geliefd onderwerp voor macrofotografie.';

  @override
  String get species_common_seahorse_name => 'Gewoon zeepaardje';

  @override
  String get species_common_seahorse_desc =>
      'Middelgroot zeepaardje in zeegrasvelden en koraalpuin in de hele Indo-Pacific, wisselend van kleur.';

  @override
  String get species_thorny_seahorse_name => 'Doornig zeepaardje';

  @override
  String get species_thorny_seahorse_desc =>
      'Zeepaardje bedekt met lange stekels, te vinden in zeegrasvelden en op zachte bodems in de hele Indo-Pacific.';

  @override
  String get species_ornate_ghost_pipefish_name => 'Sierlijke spookzeenaald';

  @override
  String get species_ornate_ghost_pipefish_desc =>
      'Prachtig gecamoufleerde zeenaald die met de kop omlaag zweeft bij haarsterren en zachte koralen in de Indo-Pacific.';

  @override
  String get species_robust_ghost_pipefish_name => 'Robuuste spookzeenaald';

  @override
  String get species_robust_ghost_pipefish_desc =>
      'Grote spookzeenaald die zeegras of algen nabootst, vaak in paren in Indo-Pacifische kustwateren.';

  @override
  String get species_trumpetfish_name => 'Trompetvis';

  @override
  String get species_trumpetfish_desc =>
      'Lange slanke vis die jaagt door zich achter grotere vissen te verschuilen, in diverse kleuren op Caribische en Atlantische riffen.';

  @override
  String get species_cornetfish_name => 'Fluitbekvis';

  @override
  String get species_cornetfish_desc =>
      'Extreem langgerekte vis tot 1,5 m met een slepende staartdraad, vaak glijdend over rifplaten te zien.';

  @override
  String get species_yellowhead_jawfish_name => 'Geelkopkaakvis';

  @override
  String get species_yellowhead_jawfish_desc =>
      'Kleine blauwe vis met gele kop die boven zijn zandhol zweeft op Caribische riffen. Mannetjes broeden de eieren uit in hun bek.';

  @override
  String get species_flamefish_name => 'Vlamkardinaalvis';

  @override
  String get species_flamefish_desc =>
      'Kleine felrode kardinaalvis met een donkere vlek onder de tweede rugvin, overdag verscholen in Caribische rifspleten.';

  @override
  String get species_longspine_squirrelfish_name => 'Langstekeleekhoornvis';

  @override
  String get species_longspine_squirrelfish_desc =>
      'Rode nachtactieve vis met grote ogen en een lange rugvinstekel, overdag onder overhangen op Caribische riffen.';

  @override
  String get species_soldierfish_name => 'Grootschubsoldatenvis';

  @override
  String get species_soldierfish_desc =>
      'Rode nachtactieve vis met enorme donkere ogen en grote schubben, overdag in groepen in grotten en onder overhangen.';

  @override
  String get species_flame_angelfish_name => 'Vlamengelvis';

  @override
  String get species_flame_angelfish_desc =>
      'Schitterend roodoranje dwergengelvis met zwarte verticale banden en blauwgepunte vinnen, voorkomend in de hele Pacific.';

  @override
  String get species_royal_gramma_name => 'Koninklijke gramma';

  @override
  String get species_royal_gramma_desc =>
      'Klein tweekleurig Caribisch baarsje met een paarse voorhelft en gele achterhelft, te vinden onder overhangen.';

  @override
  String get species_anthias_lyretail_name => 'Lierstaartanthias';

  @override
  String get species_anthias_lyretail_desc =>
      'Talrijke rifvis die grote oranje en roze wolken vormt boven Indo-Pacifische koraalformaties. Mannetjes zijn paars.';

  @override
  String get species_mediterranean_grouper_name => 'Bruine tandbaars';

  @override
  String get species_mediterranean_grouper_desc =>
      'Grote donkerbruine tandbaars met bleke vlekken, de iconische jager van mediterrane rotsriffen.';

  @override
  String get species_mediterranean_moray_name => 'Europese murene';

  @override
  String get species_mediterranean_moray_desc =>
      'Donkerbruine murene met gele vlekken, vaak turend vanuit rotsspleten in de Middellandse Zee.';

  @override
  String get species_ornate_wrasse_name => 'Pauwlipvis';

  @override
  String get species_ornate_wrasse_desc =>
      'Kleurrijke groene lipvis met rode koptekening, een van de meest algemene lipvissen op mediterrane riffen.';

  @override
  String get species_red_sea_bannerfish_name => 'Gemaskerde vlindervis';

  @override
  String get species_red_sea_bannerfish_desc =>
      'Felgele vlindervis met een donkere oogvlek, endemisch in de Rode Zee. Vaak in paren te zien.';

  @override
  String get species_red_sea_anemonefish_name => 'Rodezee-anemoonvis';

  @override
  String get species_red_sea_anemonefish_desc =>
      'Oranjegele anemoonvis met twee witte banden, endemisch in de Rode Zee en de Golf van Aden.';

  @override
  String get species_arabian_angelfish_name => 'Arabische engelvis';

  @override
  String get species_arabian_angelfish_desc =>
      'Grote donkerblauwe engelvis met een markante gele verticale band en gele staart, endemisch in de westelijke Indische Oceaan.';

  @override
  String get species_king_angelfish_name => 'Koningsengelvis';

  @override
  String get species_king_angelfish_desc =>
      'Grote donkerblauwe engelvis met een witte verticale band en gele staart, in de oostelijke Pacific en bij de Galapagos.';

  @override
  String get species_ocean_sunfish_name => 'Maanvis';

  @override
  String get species_ocean_sunfish_desc =>
      'De zwaarste beenvis, tot ruim 2 ton. Af en toe door duikers gezien bij poetsstations op Bali en bij de Galapagos.';

  @override
  String get species_lingcod_name => 'Lingcod';

  @override
  String get species_lingcod_desc =>
      'Grote gevlekte roofzuchtige groenling op rotsriffen van de Amerikaanse noordwestkust, vaak eierpakketten bewakend.';

  @override
  String get species_wolf_eel_name => 'Wolfaal';

  @override
  String get species_wolf_eel_desc =>
      'Grote grijze wolfaal met bolle kop en krachtige kaken, te vinden in rotsholen langs de Amerikaanse noordwestkust.';

  @override
  String get species_giant_sea_bass_name => 'Reuzenzeebaars';

  @override
  String get species_giant_sea_bass_desc =>
      'Kolossale baars van ruim 2 m en 250 kg, te vinden op rotsriffen en in kelpwouden voor de kust van Zuid-Californië.';

  @override
  String get species_garibaldi_name => 'Garibaldi';

  @override
  String get species_garibaldi_desc =>
      'Feloranje juffervis en de officiële zeevis van Californië, territoriaal op riffen in kelpwouden.';

  @override
  String get species_sheephead_name => 'Californische schaapskoplipvis';

  @override
  String get species_sheephead_desc =>
      'Grote lipvis met zwarte kop en staart, rood middendeel en witte kin. Te vinden in Californische kelpwouden.';

  @override
  String get species_copper_rockfish_name => 'Koperkleurige roodbaars';

  @override
  String get species_copper_rockfish_desc =>
      'Koperoranje roodbaars met bleke vlekken, een vertrouwde verschijning op rotsriffen en in kelpwouden van de Amerikaanse noordwestkust.';

  @override
  String get species_oriental_sweetlips_name => 'Oosterse zoetlipvis';

  @override
  String get species_oriental_sweetlips_desc =>
      'Grote Indo-Pacifische rifvis met markante zwart-witte strepen en gele vinnen. Jongen voeren een kronkelende dans uit.';

  @override
  String get species_harlequin_sweetlips_name => 'Harlekijnzoetlipvis';

  @override
  String get species_harlequin_sweetlips_desc =>
      'Volwassen dieren zijn grijs met donkere vlekken; jongen zijn bruin met grote witte vlekken en zwemmen met een golvende beweging.';

  @override
  String get species_blue_ringed_angelfish_name => 'Blauwring-engelvis';

  @override
  String get species_blue_ringed_angelfish_desc =>
      'Grote bruine engelvis met blauwe gebogen lijnen en een kenmerkende blauwe ring boven het kieuwdeksel.';

  @override
  String get species_yellowbar_angelfish_name => 'Geelband-engelvis';

  @override
  String get species_yellowbar_angelfish_desc =>
      'Grote grijsblauwe engelvis met een opvallende gele vlek op het lichaam, voorkomend in de Rode Zee en de westelijke Indische Oceaan.';

  @override
  String get species_filefish_scrawled_name => 'Gekrabbelde vijlvis';

  @override
  String get species_filefish_scrawled_desc =>
      'Grote olijfbruine vijlvis met blauwe krabbelachtige tekening en oranje keelzak, wereldwijd op tropische riffen.';

  @override
  String get species_clown_filefish_name => 'Oranjegevlekte vijlvis';

  @override
  String get species_clown_filefish_desc =>
      'Kleine groene vijlvis met oranje stippen en een lange snuit, eet uitsluitend poliepen van Acropora-koraal.';

  @override
  String get species_unicornfish_name => 'Blauwstekeleenhoornvis';

  @override
  String get species_unicornfish_desc =>
      'Grijze doktersvis met een opvallende hoorn op het voorhoofd en twee blauwe staartstekels, algemeen op Indo-Pacifische rifplaten.';

  @override
  String get species_surgeonfish_sailfin_name => 'Zeilvindoktersvis';

  @override
  String get species_surgeonfish_sailfin_desc =>
      'Markant gebande doktersvis met een sterk vergrote rug- en aarsvin, voorkomend in de hele Indo-Pacific.';

  @override
  String get species_achilles_tang_name => 'Achilles-doktersvis';

  @override
  String get species_achilles_tang_desc =>
      'Donkerbruine doktersvis met een felle oranje traanvorm bij de staart, in brandingszones van de centrale Pacific.';

  @override
  String get species_doctorfish_name => 'Caribische doktersvis';

  @override
  String get species_doctorfish_desc =>
      'Grijsbruine doktersvis met vage donkere banden en een opvallend staartscalpel, algemeen op Caribische riffen.';

  @override
  String get species_checkerboard_wrasse_name => 'Schaakbordlipvis';

  @override
  String get species_checkerboard_wrasse_desc =>
      'Kleurrijke lipvis met een schaakbordpatroon van groene, roze en zwarte vlakken over het lichaam.';

  @override
  String get species_bird_wrasse_name => 'Vogellipvis';

  @override
  String get species_bird_wrasse_desc =>
      'Lipvis met een extreem langgerekte snuit als een vogelsnavel; mannetjes zijn donkergroen, vrouwtjes bruin.';

  @override
  String get species_sling_jaw_wrasse_name => 'Slingerkaaklipvis';

  @override
  String get species_sling_jaw_wrasse_desc =>
      'Lipvis met een uitschuifbare kaak die naar voren schiet om prooi te grijpen, in gele of bruine kleurvormen.';

  @override
  String get species_peacock_flounder_name => 'Pauwbot';

  @override
  String get species_peacock_flounder_desc =>
      'Platte bodembewonende vis met blauwe ringen en stippen die van kleur kan veranderen om bij de zeebodem te passen.';

  @override
  String get species_hogfish_name => 'Varkenslipvis';

  @override
  String get species_hogfish_desc =>
      'Grote West-Atlantische lipvis met een varkensachtige snuit en langgerekte rugvinstekels, bij riffen en wrakken.';

  @override
  String get species_tarpon_name => 'Atlantische tarpoen';

  @override
  String get species_tarpon_desc =>
      'Enorme zilveren vis met grote spiegelende schubben, soms door duikers ontmoet in Caribische grotten en kanalen.';

  @override
  String get species_permit_name => 'Grote pompano';

  @override
  String get species_permit_desc =>
      'Hoog gebouwde zilveren makreel met een donkere gevorkte staart, op Caribische zandvlaktes en nabij riffen.';

  @override
  String get species_spotted_drum_name => 'Gevlekte trommelvis';

  @override
  String get species_spotted_drum_desc =>
      'Opvallende Caribische vis met een hoge langgerekte rugvin en een markant zwart-wit gevlekt patroon.';

  @override
  String get species_jackknife_fish_name => 'Zakmesvis';

  @override
  String get species_jackknife_fish_desc =>
      'Elegante Caribische vis met een hoge zwarte rugvinstreep en diagonale lichaamsband, te vinden onder overhangen.';

  @override
  String get species_bigeye_name => 'Glasoog';

  @override
  String get species_bigeye_desc =>
      'Felrode nachtactieve vis met grote weerspiegelende ogen, verscholen in grotten op Caribische en Atlantische riffen.';

  @override
  String get species_remora_name => 'Zuigvis';

  @override
  String get species_remora_desc =>
      'Slanke vis met een zuignap op de kop die meelift met haaien, roggen, schildpadden en andere grote dieren.';

  @override
  String get species_tilefish_sand_name => 'Zandtegelvis';

  @override
  String get species_tilefish_sand_desc =>
      'Langgerekte lichtblauwe vis die puinheuveltjes bouwt op zandige plekken van Caribische riffen.';

  @override
  String get species_weedy_seadragon_name => 'Wierzeedraak';

  @override
  String get species_weedy_seadragon_desc =>
      'Sierlijke verwant van de zeepaardjes met bladachtige aanhangsels, endemisch in de gematigde wateren van Zuid-Australië.';

  @override
  String get species_leafy_seadragon_name => 'Bladzeedraak';

  @override
  String get species_leafy_seadragon_desc =>
      'Spectaculaire zeedraak bedekt met uitbundige bladvormige uitsteeksels, endemisch in Zuid-Australië. Een waarneming voor op je verlanglijst.';

  @override
  String get species_sailfin_snapper_name => 'Zeilvinsnapper';

  @override
  String get species_sailfin_snapper_desc =>
      'Elegante geel-blauwe snapper met langgerekte rug- en aarsvin, te vinden op Indo-Pacifische rifhellingen.';

  @override
  String get species_sweetlip_emperor_name => 'Gespikkelde keizersbaars';

  @override
  String get species_sweetlip_emperor_desc =>
      'Grote zilverachtige keizersbaars met blauwe lijnen op het gezicht en gele vinranden, algemeen boven zandige Indo-Pacifische rifgebieden.';

  @override
  String get species_crocodilefish_name => 'Krokodilvis';

  @override
  String get species_crocodilefish_desc =>
      'Platkoppige hinderlaagjager met sierlijke oogfranjes die perfect gecamoufleerd op Indo-Pacifische rifbodems ligt.';

  @override
  String get species_devil_scorpionfish_name => 'Duivelsschorpioenvis';

  @override
  String get species_devil_scorpionfish_desc =>
      'Gedrongen gecamoufleerde schorpioenvis die kleurrijke binnenzijden van de borstvinnen toont als waarschuwing aan jagers.';

  @override
  String get species_spiny_devilfish_name => 'Duivelsteker';

  @override
  String get species_spiny_devilfish_desc =>
      'Giftige bodembewoner die op omgevormde vinstralen loopt en felle borstvinnen laat flitsen bij verstoring.';

  @override
  String get species_waspfish_name => 'Kaketoewespvis';

  @override
  String get species_waspfish_desc =>
      'Kleine zijdelings afgeplatte schorpioenvis die als een dood blad meedeint met de stroming boven Indo-Pacifische modderbodems.';

  @override
  String get species_stargazer_name => 'Witrandsterrenkijker';

  @override
  String get species_stargazer_desc =>
      'Hinderlaagjager die zich in het zand ingraaft met alleen de ogen zichtbaar en elektrische schokken kan afgeven. Voorkomend in de Indo-Pacific.';

  @override
  String get species_striped_catfish_name => 'Gestreepte koraalmeerval';

  @override
  String get species_striped_catfish_desc =>
      'Meerval met giftige stekels; jongen vormen dichte bolvormige scholen die over Indo-Pacifische rifbodems rollen.';

  @override
  String get species_red_emperor_name => 'Rode keizersnapper';

  @override
  String get species_red_emperor_desc =>
      'Grote snapper; volwassen dieren zijn roze-rood, jongen hebben markante rode en witte banden. Te vinden op Indo-Pacifische riffen.';

  @override
  String get species_mangrove_snapper_name => 'Mangrovesnapper';

  @override
  String get species_mangrove_snapper_desc =>
      'Grijze snapper in Caribische mangroven, zeegras en riffen, vaak samenscholend bij structuren.';

  @override
  String get species_dottyback_orchid_name => 'Orchideebaarsje';

  @override
  String get species_dottyback_orchid_desc =>
      'Klein felpaars visje endemisch in de Rode Zee, dat in en uit spleten van steile rifwanden schiet.';

  @override
  String get species_dottyback_royal_name => 'Koningsbaarsje';

  @override
  String get species_dottyback_royal_desc =>
      'Klein tweekleurig visje met magenta voorkant en felgele achterkant, te vinden op Indo-Pacifische rifwanden.';

  @override
  String get species_coral_trout_name => 'Koraalforel';

  @override
  String get species_coral_trout_desc =>
      'Gewilde jager van het Great Barrier Reef met een oranjerood lichaam vol blauwe stippen.';

  @override
  String get species_barramundi_cod_name => 'Barramundi-tandbaars';

  @override
  String get species_barramundi_cod_desc =>
      'Kenmerkende tandbaars met een kleine kop, gebocheld lichaam en donkere stippen op een bleke ondergrond.';

  @override
  String get species_spadefish_atlantic_name => 'Atlantische spadevis';

  @override
  String get species_spadefish_atlantic_desc =>
      'Zilveren schijfvormige vis met donkere verticale banden, vaak in grote scholen rond Caribische wrakken.';

  @override
  String get species_fusilier_yellowback_name => 'Geelrugfuselier';

  @override
  String get species_fusilier_yellowback_desc =>
      'Gestroomlijnde blauwe planktoneter met gele rug die enorme scholen vormt boven Indo-Pacifische rifhellingen.';

  @override
  String get species_fusilier_bluestreak_name => 'Blauwstreepfuselier';

  @override
  String get species_fusilier_bluestreak_desc =>
      'Kleine blauwe fuselier met een donkere zijstreep, in snel bewegende scholen langs Indo-Pacifische rifwanden.';

  @override
  String get species_porkfish_name => 'Varkensgrommer';

  @override
  String get species_porkfish_desc =>
      'Kleurrijke Caribische grommer met blauwe en gele strepen en twee zwarte kopbanden, bij riffen en wrakken.';

  @override
  String get species_blue_striped_grunt_name => 'Blauwgestreepte grommer';

  @override
  String get species_blue_striped_grunt_desc =>
      'Gele Caribische grommer met heldere blauwe horizontale strepen, vormt overdag grote rustende scholen onder overhangen.';

  @override
  String get species_french_grunt_name => 'Franse grommer';

  @override
  String get species_french_grunt_desc =>
      'Kleine geelgestreepte grommer die overdag dichte rustende scholen vormt op Caribische riffen.';

  @override
  String get species_convict_tang_name => 'Zebradoktersvis';

  @override
  String get species_convict_tang_desc =>
      'Bleke doktersvis met zes verticale zwarte banden, vaak grazend in grote scholen op Indo-Pacifische rifplaten.';

  @override
  String get species_great_hammerhead_name => 'Geschulpte hamerhaai';

  @override
  String get species_great_hammerhead_desc =>
      'Kenmerkende haai met een geschulpte hamervormige kop, vormt grote scholen bij zeebergen en eilanden in open zee.';

  @override
  String get species_wobbegong_name => 'Gevlekte wobbegong';

  @override
  String get species_wobbegong_desc =>
      'Platte, goed gecamoufleerde tapijthaai met franjeachtige lobben rond de bek, op gematigde Australische riffen.';

  @override
  String get species_manta_ray_name => 'Rifmanta';

  @override
  String get species_manta_ray_desc =>
      'Gracieuze reus met een spanwijdte tot 5 m die poetsstations bezoekt en plankton eet op Indo-Pacifische riffen.';

  @override
  String get species_oceanic_manta_name => 'Oceanische manta';

  @override
  String get species_oceanic_manta_desc =>
      'De grootste roggensoort met een spanwijdte van ruim 7 m, te ontmoeten bij zeebergen in open zee en poetsstations.';

  @override
  String get species_undulated_moray_name => 'Gegolfde murene';

  @override
  String get species_undulated_moray_desc =>
      'Geelgroene murene met donkere golvende tekening, \'s nachts vaak jagend op Indo-Pacifische riffen.';

  @override
  String get species_whitemouth_moray_name => 'Witmondmurene';

  @override
  String get species_whitemouth_moray_desc =>
      'Donkerbruine murene met kleine witte stippen en een kenmerkend wit bekinterieur, voorkomend in de hele Indo-Pacific.';

  @override
  String get species_dragon_moray_name => 'Draakmurene';

  @override
  String get species_dragon_moray_desc =>
      'Opvallende murene met drakenachtige hoorns boven de neusgaten en oranjerode luipaardvlekken, voorkomend in de Indo-Pacific.';

  @override
  String get species_lyretail_grouper_name => 'Lierstaarttandbaars';

  @override
  String get species_lyretail_grouper_desc =>
      'Roodroze tandbaars met blauwe stippen en een kenmerkende sikkelvormige staart, op Indo-Pacifische buitenrifwanden.';

  @override
  String get species_banded_butterflyfish_name => 'Gebande vlindervis';

  @override
  String get species_banded_butterflyfish_desc =>
      'Witte vlindervis met vier markante zwarte verticale banden, een van de meest algemene vlindervissen op Caribische riffen.';

  @override
  String get species_ringed_pipefish_name => 'Geringde zeenaald';

  @override
  String get species_ringed_pipefish_desc =>
      'Slanke zeenaald met afwisselend rode en witte ringen, in grotten en onder overhangen op Indo-Pacifische riffen.';

  @override
  String get species_razorfish_name => 'Scheermesvis';

  @override
  String get species_razorfish_desc =>
      'Piepklein visje dat in groepen verticaal met de kop omlaag zwemt, vaak schuilend tussen zee-egelstekels op Indo-Pacifische riffen.';

  @override
  String get species_harlequin_tuskfish_name => 'Harlekijnslagtandlipvis';

  @override
  String get species_harlequin_tuskfish_desc =>
      'Kleurrijke lipvis met felblauwe slagtanden, roodoranje banden en witte vlakken, op riffen in de westelijke Pacific.';

  @override
  String get species_blue_groper_name => 'Australische blauwe lipvis';

  @override
  String get species_blue_groper_desc =>
      'Grote blauwe lipvis endemisch in oost-Australië, aanhankelijk en vaak duikers benaderend op gematigde riffen.';

  @override
  String get species_red_lipped_batfish_name => 'Roodlipvleermuisvis';

  @override
  String get species_red_lipped_batfish_desc =>
      'Bizarre platte vis met felrode lippen die op omgevormde vinnen over de Galapagos-zeebodem loopt.';

  @override
  String get species_orangeband_surgeonfish_name => 'Oranjebanddoktersvis';

  @override
  String get species_orangeband_surgeonfish_desc =>
      'Grijsbruine doktersvis met een oranje horizontale band achter het oog, op Pacifische rifhellingen.';

  @override
  String get species_maori_wrasse_name => 'Maori-lipvis';

  @override
  String get species_maori_wrasse_desc =>
      'Middelgrote lipvis met een donkere band achter de borstvin, algemeen op riffen in de Pacific en de Indische Oceaan.';

  @override
  String get species_blue_ringed_octopus_name => 'Blauwgeringde octopus';

  @override
  String get species_blue_ringed_octopus_desc =>
      'Kleine maar uiterst giftige octopus met felblauwe ringen die oplichten bij dreiging.';

  @override
  String get species_common_octopus_name => 'Gewone octopus';

  @override
  String get species_common_octopus_desc =>
      'Zeer intelligente octopus, bekend om zijn bliksemsnelle kleurwisselingen en probleemoplossend vermogen.';

  @override
  String get species_giant_pacific_octopus_name => 'Reuzenoctopus';

  @override
  String get species_giant_pacific_octopus_desc =>
      'De grootste octopussoort, met een armspanwijdte van ruim 4 meter in koude Pacifische wateren.';

  @override
  String get species_mimic_octopus_name => 'Mimic-octopus';

  @override
  String get species_mimic_octopus_desc =>
      'Opmerkelijke octopus die het uiterlijk en gedrag van andere zeedieren nabootst.';

  @override
  String get species_coconut_octopus_name => 'Kokosnootoctopus';

  @override
  String get species_coconut_octopus_desc =>
      'Kleine octopus die beroemd is om het meedragen van kokosschelpen als verplaatsbare schuilplaats.';

  @override
  String get species_day_octopus_name => 'Dagoctopus';

  @override
  String get species_day_octopus_desc =>
      'Overdag actieve jager, algemeen op Indo-Pacifische riffen, met indrukwekkende camouflagekunsten.';

  @override
  String get species_wonderpus_octopus_name => 'Wonderpus-octopus';

  @override
  String get species_wonderpus_octopus_desc =>
      'Opvallende octopus met een uniek wit-bruin bandpatroon, te vinden op zandige muckstekken.';

  @override
  String get species_broadclub_cuttlefish_name => 'Breedarmzeekat';

  @override
  String get species_broadclub_cuttlefish_desc =>
      'Grote zeekat met hypnotiserende kleurenspelen, veel gezien op Indo-Pacifische riffen.';

  @override
  String get species_pharaoh_cuttlefish_name => 'Faraozeekat';

  @override
  String get species_pharaoh_cuttlefish_desc =>
      'Grote zeekat uit de Indische Oceaan, bekend om zijn pulserende kleurpatronen.';

  @override
  String get species_flamboyant_cuttlefish_name => 'Flamboyante zeekat';

  @override
  String get species_flamboyant_cuttlefish_desc =>
      'Piepkleine zeekat die over de zeebodem loopt en felle paarse, roze en gele pulsen toont.';

  @override
  String get species_giant_cuttlefish_name => 'Reuzenzeekat';

  @override
  String get species_giant_cuttlefish_desc =>
      'De grootste zeekat ter wereld, beroemd om de massale paaiverzamelingen in Zuid-Australië.';

  @override
  String get species_bigfin_reef_squid_name => 'Grootvinrifpijlinktvis';

  @override
  String get species_bigfin_reef_squid_desc =>
      'Scholende pijlinktvis die vaak bij nachtduiken opduikt, aangetrokken door duiklampen.';

  @override
  String get species_caribbean_reef_squid_name => 'Caribische rifpijlinktvis';

  @override
  String get species_caribbean_reef_squid_desc =>
      'Nieuwsgierige pijlinktvis die vaak in kleine groepjes bij rifranden in het Caribisch gebied zweeft.';

  @override
  String get species_bobtail_squid_name => 'Dwerginktvis';

  @override
  String get species_bobtail_squid_desc =>
      'Piepkleine nachtactieve inktvis die zich overdag ingraaft in het zand, een gewilde muckvondst.';

  @override
  String get species_chambered_nautilus_name => 'Parelboot';

  @override
  String get species_chambered_nautilus_desc =>
      'Oeroud levend fossiel met een opgerolde schelp, zelden door duikers gezien in diep water bij dageraad.';

  @override
  String get species_spanish_dancer_name => 'Spaanse danseres';

  @override
  String get species_spanish_dancer_desc =>
      'Grootste zeenaaktslak, die zwemt met een golvende rode mantel als een flamencodanseres.';

  @override
  String get species_chromodoris_willani_name => 'Willans chromodoris';

  @override
  String get species_chromodoris_willani_desc =>
      'Opvallende blauw-zwarte zeenaaktslak met witte rand, algemeen in de Indo-Pacific.';

  @override
  String get species_chromodoris_lochi_name => 'Lochs chromodoris';

  @override
  String get species_chromodoris_lochi_desc =>
      'Blauwe zeenaaktslak met donkere lijnen en witte rand, voorkomend in de hele tropische Pacific.';

  @override
  String get species_chromodoris_magnifica_name => 'Prachtige chromodoris';

  @override
  String get species_chromodoris_magnifica_desc =>
      'Schitterend blauwe, witte en oranje zeenaaktslak op Indo-Pacifische koraalriffen.';

  @override
  String get species_chromodoris_annae_name => 'Anna\'s chromodoris';

  @override
  String get species_chromodoris_annae_desc =>
      'Diepblauwe zeenaaktslak met zwarte lijnen en oranjegepunte rinoforen en kieuwen.';

  @override
  String get species_nembrotha_kubaryana_name => 'Variabele neonslak';

  @override
  String get species_nembrotha_kubaryana_desc =>
      'Donkergroene zeenaaktslak met felle oranje of rode tekening, die zich voedt met zakpijpen.';

  @override
  String get species_nembrotha_cristata_name => 'Gekuifde nembrotha';

  @override
  String get species_nembrotha_cristata_desc =>
      'Zwarte zeenaaktslak met felgroene puistjes en strepen, te vinden op Indo-Pacifische riffen.';

  @override
  String get species_phyllidia_varicosa_name => 'Knobbelige phyllidia';

  @override
  String get species_phyllidia_varicosa_desc =>
      'Blauwgrijze zeenaaktslak met verhoogde geelgepunte knobbels, giftig voor rovers.';

  @override
  String get species_phyllidia_ocellata_name => 'Geoogde phyllidia';

  @override
  String get species_phyllidia_ocellata_desc =>
      'Witte zeenaaktslak met verhoogde, roze omringde knobbels, te vinden op tropische riffen.';

  @override
  String get species_pikachu_nudibranch_name => 'Pikachu-zeenaaktslak';

  @override
  String get species_pikachu_nudibranch_desc =>
      'Piepkleine geel-zwarte zeeslak die op een tekenfilmfiguur lijkt, voorkomend in de Pacific.';

  @override
  String get species_anna_rosefieldi_name => 'Roboastra-zeenaaktslak';

  @override
  String get species_anna_rosefieldi_desc =>
      'Roofzuchtige zeenaaktslak met donker lichaam en felle lengtestrepen die op andere slakken jaagt.';

  @override
  String get species_lettuce_sea_slug_name => 'Slazeeslak';

  @override
  String get species_lettuce_sea_slug_desc =>
      'Gekrulde groene zeeslak die chloroplasten uit algen bewaart om te fotosynthetiseren.';

  @override
  String get species_blue_dragon_nudibranch_name => 'Blauwe drakenslak';

  @override
  String get species_blue_dragon_nudibranch_desc =>
      'Lange aeolide zeenaaktslak met blauwgepunte cerata die symbiotische zoöxanthellen herbergt.';

  @override
  String get species_gloomy_nudibranch_name => 'Sombere zeenaaktslak';

  @override
  String get species_gloomy_nudibranch_desc =>
      'Donker blauwgroene zeenaaktslak met blauwomrande richels, algemeen op Indo-Pacifische riffen.';

  @override
  String get species_ocellined_nudibranch_name => 'Oranjegelijnde zeenaaktslak';

  @override
  String get species_ocellined_nudibranch_desc =>
      'Witte zeenaaktslak met oranje omlijnde richels die geometrische patronen op de mantel vormen.';

  @override
  String get species_glossodoris_cincta_name => 'Glossodoris-zeenaaktslak';

  @override
  String get species_glossodoris_cincta_desc =>
      'Crèmekleurige zeenaaktslak met donkerbruine rand en oranje zoom op de mantel.';

  @override
  String get species_jorunna_funebris_name => 'Gestippelde zeenaaktslak';

  @override
  String get species_jorunna_funebris_desc =>
      'Witte zeenaaktslak bedekt met zwartgepunte caryophyllidia, lijkt op een pluizig konijntje.';

  @override
  String get species_ceratosoma_trilobatum_name => 'Drielobbige zeenaaktslak';

  @override
  String get species_ceratosoma_trilobatum_desc =>
      'Grote zeenaaktslak met een hoge rughoorn en zijlobben in paarse en gele tinten.';

  @override
  String get species_hypselodoris_apolegma_name => 'Paarse hypselodoris';

  @override
  String get species_hypselodoris_apolegma_desc =>
      'Elegante paarse zeenaaktslak met witte mantelrand, te vinden op Indo-Pacifische riffen.';

  @override
  String get species_hypselodoris_bullockii_name => 'Bullocks hypselodoris';

  @override
  String get species_hypselodoris_bullockii_desc =>
      'Roze en paarse zeenaaktslak met geelgepunte rinoforen op Indo-Pacifische riffen.';

  @override
  String get species_flabellina_exoptata_name => 'Sierlijke flabellina';

  @override
  String get species_flabellina_exoptata_desc =>
      'Doorschijnende aeolide zeenaaktslak met paarsgepunte oranje cerata, voorkomend in tropische wateren.';

  @override
  String get species_risbecia_tryoni_name => 'Tryons risbecia';

  @override
  String get species_risbecia_tryoni_desc =>
      'Grote bruin-blauwe zeenaaktslak die vaak in parende paren op Indo-Pacifische riffen wordt gevonden.';

  @override
  String get species_goniobranchus_kuniei_name => 'Kunies zeenaaktslak';

  @override
  String get species_goniobranchus_kuniei_desc =>
      'Witte zeenaaktslak met oranje stippen en paarse mantelrand, voorkomend in de westelijke Pacific.';

  @override
  String get species_mexichromis_multituberculata_name =>
      'Veelknobbelige zeenaaktslak';

  @override
  String get species_mexichromis_multituberculata_desc =>
      'Paars-witte zeenaaktslak met verhoogde knobbels en oranjegepunte aanhangsels.';

  @override
  String get species_chromodoris_dianae_name => 'Diana\'s chromodoris';

  @override
  String get species_chromodoris_dianae_desc =>
      'Felblauwe zeenaaktslak met zwarte strepen en oranje kieuwen, voorkomend in de westelijke Pacific.';

  @override
  String get species_phyllodesmium_poindimiei_name =>
      'Zonne-aangedreven zeenaaktslak';

  @override
  String get species_phyllodesmium_poindimiei_desc =>
      'Doorschijnende aeolide zeenaaktslak met vertakte cerata die zoöxanthellen herbergt.';

  @override
  String get species_chromodoris_elisabethina_name => 'Elisabeths chromodoris';

  @override
  String get species_chromodoris_elisabethina_desc =>
      'Blauwe zeenaaktslak met gele lijnen en een witte mantelrand, algemeen in Zuidoost-Azië.';

  @override
  String get species_doridella_batava_name => 'Bataafse dorisslak';

  @override
  String get species_doridella_batava_desc =>
      'Variabel zwarte tot bruine dorisslak, te vinden onder stenen en puin op Indo-Pacifische riffen.';

  @override
  String get species_tiger_cowrie_name => 'Tijgerkauri';

  @override
  String get species_tiger_cowrie_desc =>
      'Grote gevlekte kaurischelp op tropische riffen, vaak deels bedekt door zijn eigen mantel.';

  @override
  String get species_tritons_trumpet_name => 'Tritonshoorn';

  @override
  String get species_tritons_trumpet_desc =>
      'Grote roofzuchtige zeeslak en natuurlijke vijand van de doornenkroonzeester.';

  @override
  String get species_queen_conch_name => 'Koninginnekinkhoorn';

  @override
  String get species_queen_conch_desc =>
      'Iconische grote kinkhoorn van Caribische zeegrasvelden met een kenmerkende roze binnenlip.';

  @override
  String get species_banded_coral_shrimp_name => 'Gebande koraalgarnaal';

  @override
  String get species_banded_coral_shrimp_desc =>
      'Rood-wit gebande poetsgarnaal met lange witte antennes, te vinden in rifspleten.';

  @override
  String get species_mantis_shrimp_name => 'Pauwbidsprinkhaankreeft';

  @override
  String get species_mantis_shrimp_desc =>
      'Kleurrijke jager met krachtige knotsvormige aanhangsels die schelpen kunnen verbrijzelen.';

  @override
  String get species_cleaner_shrimp_name => 'Scharlaken poetsgarnaal';

  @override
  String get species_cleaner_shrimp_desc =>
      'Felrood-witte garnaal die poetsstations opzet om rifvissen te bedienen.';

  @override
  String get species_pederson_cleaner_shrimp_name => 'Pedersons poetsgarnaal';

  @override
  String get species_pederson_cleaner_shrimp_desc =>
      'Doorschijnende Caribische poetsgarnaal die tussen de tentakels van anemonen leeft.';

  @override
  String get species_harlequin_shrimp_name => 'Harlekijngarnaal';

  @override
  String get species_harlequin_shrimp_desc =>
      'Opvallend getekende garnaal met platte scharen die zich uitsluitend met zeesterren voedt.';

  @override
  String get species_coleman_shrimp_name => 'Colemangarnaal';

  @override
  String get species_coleman_shrimp_desc =>
      'Piepklein garnaalpaar dat op vuurzee-egels leeft, zeer geliefd bij onderwaterfotografen.';

  @override
  String get species_emperor_shrimp_name => 'Keizersgarnaal';

  @override
  String get species_emperor_shrimp_desc =>
      'Kleurrijke commensale garnaal die meelift op zeekomkommers en zeenaaktslakken.';

  @override
  String get species_sexy_shrimp_name => 'Sexy garnaal';

  @override
  String get species_sexy_shrimp_desc =>
      'Piepkleine anemoongarnaal die bekendstaat om zijn wiegende staartdans, populair in de macrofotografie.';

  @override
  String get species_marble_shrimp_name => 'Marmergarnaal';

  @override
  String get species_marble_shrimp_desc =>
      'Nachtactieve gevlekte garnaal met veerachtige poten, overdag verscholen in rifspleten.';

  @override
  String get species_spiny_lobster_name => 'Caribische langoest';

  @override
  String get species_spiny_lobster_desc =>
      'Grote langoest zonder scharen met lange antennes, schuilend onder rifoverhangen.';

  @override
  String get species_painted_spiny_lobster_name => 'Geschilderde langoest';

  @override
  String get species_painted_spiny_lobster_desc =>
      'Felgekleurde langoest met blauw, groen en wit gestreepte poten op Indo-Pacifische riffen.';

  @override
  String get species_slipper_lobster_name => 'Beerkreeft';

  @override
  String get species_slipper_lobster_desc =>
      'Platte nachtactieve kreeft met brede antenneplaten in plaats van lange zwepen.';

  @override
  String get species_squat_lobster_name => 'Galatheakreeftje';

  @override
  String get species_squat_lobster_desc =>
      'Piepklein roze-paars kreeftachtige dat op reuzentonsponzen leeft, een favoriet voor macrofotografie.';

  @override
  String get species_hermit_crab_name => 'Blauwpotige heremietkreeft';

  @override
  String get species_hermit_crab_desc =>
      'Kleine heremietkreeft met felblauwe poten, veel gezien op Caribische riffen.';

  @override
  String get species_orangutan_crab_name => 'Orang-oetankrab';

  @override
  String get species_orangutan_crab_desc =>
      'Piepkleine harige krab die in bellenkoraal leeft, genoemd naar zijn gelijkenis met een orang-oetan.';

  @override
  String get species_decorator_crab_name => 'Decoratiekrab';

  @override
  String get species_decorator_crab_desc =>
      'Meester in vermomming die sponzen, algen en hydroïdpoliepen op zijn rugschild plakt.';

  @override
  String get species_porcelain_crab_name => 'Porseleinen anemoonkrab';

  @override
  String get species_porcelain_crab_desc =>
      'Platte gevlekte krab die in anemonen leeft en met veerachtige monddelen plankton filtert.';

  @override
  String get species_arrow_crab_name => 'Pijlkrab';

  @override
  String get species_arrow_crab_desc =>
      'Spichtige Caribische krab met een lang spits rostrum en gestreepte poten.';

  @override
  String get species_channel_clinging_crab_name => 'Caribische klimkrab';

  @override
  String get species_channel_clinging_crab_desc =>
      'Grote Caribische rifkrab met donker lichaam en roodoranje scharen, te vinden in spleten.';

  @override
  String get species_coral_crab_name => 'Koraalwachterkrab';

  @override
  String get species_coral_crab_desc =>
      'Kleine gevlekte krab die in symbiose in Pocillopora-koralen leeft en zijn gastheer verdedigt.';

  @override
  String get species_crown_of_thorns_starfish_name => 'Doornenkroonzeester';

  @override
  String get species_crown_of_thorns_starfish_desc =>
      'Giftige veelarmige zeester die koraal eet en riffen bij plagen kan verwoesten.';

  @override
  String get species_blue_linckia_starfish_name => 'Blauwe zeester';

  @override
  String get species_blue_linckia_starfish_desc =>
      'Felblauwe zeester die veel wordt gezien op Indo-Pacifische rifplaten en -hellingen.';

  @override
  String get species_red_knob_starfish_name => 'Roodknobbelzeester';

  @override
  String get species_red_knob_starfish_desc =>
      'Grote grijze zeester met opvallende roodgepunte stekels, te vinden op zandige rifgebieden.';

  @override
  String get species_chocolate_chip_starfish_name => 'Chocoladestipzeester';

  @override
  String get species_chocolate_chip_starfish_desc =>
      'Lichtbruine zeester met donkere verhoogde knobbels als chocoladestukjes op zandige bodems.';

  @override
  String get species_cushion_star_name => 'Kussenzeester';

  @override
  String get species_cushion_star_desc =>
      'Gezwollen vijfhoekige zeester met korte armen, te vinden op Indo-Pacifische rifplaten.';

  @override
  String get species_fromia_starfish_name => 'Elegante zeester';

  @override
  String get species_fromia_starfish_desc =>
      'Kleine oranjerode zeester met bleke plaatranden die een tegelachtig patroon vormen.';

  @override
  String get species_basket_star_name => 'Medusahoofd';

  @override
  String get species_basket_star_desc =>
      'Rijk vertakte armen die zich \'s nachts ontvouwen om plankton uit de stroming te filteren.';

  @override
  String get species_brittle_star_name => 'Gebande slangster';

  @override
  String get species_brittle_star_desc =>
      'Gestreepte slangster onder stenen en in spleten, met lenige, slangachtige armen.';

  @override
  String get species_feather_star_name => 'Veerster';

  @override
  String get species_feather_star_desc =>
      'Veelarmige haarster die op uitsteeksels van het rif zit en met veerachtige armen plankton filtert.';

  @override
  String get species_black_feather_star_name => 'Zwarte veerster';

  @override
  String get species_black_feather_star_desc =>
      'Donkere haarster die kort kan zwemmen door zijn vele armen ritmisch te bewegen.';

  @override
  String get species_long_spined_sea_urchin_name => 'Langstekelige zee-egel';

  @override
  String get species_long_spined_sea_urchin_desc =>
      'Zwarte zee-egel met lange giftige stekels, een onmisbare algengrazer op Caribische riffen.';

  @override
  String get species_fire_urchin_name => 'Vuurzee-egel';

  @override
  String get species_fire_urchin_desc =>
      'Zachte zee-egel met giftige stekels die bij aanraking pijnlijke steken veroorzaken.';

  @override
  String get species_pencil_urchin_name => 'Potloodzee-egel';

  @override
  String get species_pencil_urchin_desc =>
      'Stevige zee-egel met dikke stompe stekels, vastgeklemd in rifspleten.';

  @override
  String get species_collector_urchin_name => 'Verzamelaarszee-egel';

  @override
  String get species_collector_urchin_desc =>
      'Zee-egel die zich met puin en algenresten bedekt om zich te camoufleren.';

  @override
  String get species_sea_apple_name => 'Zeeappel';

  @override
  String get species_sea_apple_desc =>
      'Felgekleurde zeekomkommer met mondtentakels waarmee hij voedsel uit het water filtert.';

  @override
  String get species_pineapple_sea_cucumber_name => 'Ananaszeekomkommer';

  @override
  String get species_pineapple_sea_cucumber_desc =>
      'Grote oranjerode zeekomkommer met stervormige papillen, te vinden op rifhellingen.';

  @override
  String get species_black_sea_cucumber_name => 'Zwarte zeekomkommer';

  @override
  String get species_black_sea_cucumber_desc =>
      'Algemene zwarte zeekomkommer op zandige rifplaten in de hele Indo-Pacific.';

  @override
  String get species_leopard_sea_cucumber_name => 'Luipaardzeekomkommer';

  @override
  String get species_leopard_sea_cucumber_desc =>
      'Gevlekte zeekomkommer die bij verstoring kleverige witte cuvierbuisjes uitstoot.';

  @override
  String get species_sand_dollar_name => 'Zanddollar';

  @override
  String get species_sand_dollar_desc =>
      'Platte schijfvormige zee-egel die half ingegraven in zandbodems ligt.';

  @override
  String get species_moon_jellyfish_name => 'Oorkwal';

  @override
  String get species_moon_jellyfish_desc =>
      'Doorschijnende klokvormige kwal met vier hoefijzervormige geslachtsklieren die door het lichaam schemeren.';

  @override
  String get species_lions_mane_jellyfish_name => 'Haarkwal';

  @override
  String get species_lions_mane_jellyfish_desc =>
      'Een van de grootste kwallensoorten, met lange slepende tentakels in koude wateren.';

  @override
  String get species_box_jellyfish_name => 'Kubuskwal';

  @override
  String get species_box_jellyfish_desc =>
      'Uiterst gevaarlijke kwal met krachtig gif, voorkomend in tropische Indo-Pacifische wateren.';

  @override
  String get species_upside_down_jellyfish_name => 'Omgekeerde kwal';

  @override
  String get species_upside_down_jellyfish_desc =>
      'Bijzondere kwal die met de klok omlaag op zandbodems rust zodat zijn algen kunnen fotosynthetiseren.';

  @override
  String get species_blue_blubber_jellyfish_name => 'Blauwe blubberkwal';

  @override
  String get species_blue_blubber_jellyfish_desc =>
      'Blauwwitte kwal met een stevige klok en gekrulde mondarmen, algemeen in Australische wateren.';

  @override
  String get species_fried_egg_jellyfish_name => 'Spiegeleikwal';

  @override
  String get species_fried_egg_jellyfish_desc =>
      'Mediterrane kwal met een gele koepel als een spiegelei en een milde netelbeet.';

  @override
  String get species_pacific_sea_nettle_name => 'Pacifische zeenetel';

  @override
  String get species_pacific_sea_nettle_desc =>
      'Goudbruine kwal met lange slepende tentakels, voorkomend langs de Pacifische kust.';

  @override
  String get species_compass_jellyfish_name => 'Kompaskwal';

  @override
  String get species_compass_jellyfish_desc =>
      'Bruin-witte kwal met V-vormige tekening die uitstraalt als een kompasroos.';

  @override
  String get species_spotted_jellyfish_name => 'Gevlekte kwal';

  @override
  String get species_spotted_jellyfish_desc =>
      'Witgestippelde goudkleurige kwal, beroemd omdat hij het Jellyfish Lake van Palau vult.';

  @override
  String get species_barrel_jellyfish_name => 'Wortelmondkwal';

  @override
  String get species_barrel_jellyfish_desc =>
      'Grote koepelvormige kwal met gekrulde mondarmen en een milde netelbeet, algemeen in de Atlantische Oceaan.';

  @override
  String get species_persian_carpet_flatworm_name => 'Perzischtapijtplatworm';

  @override
  String get species_persian_carpet_flatworm_desc =>
      'Sierlijke zwarte platworm met geeloranje randen, vaak aangezien voor een zeenaaktslak.';

  @override
  String get species_leopard_flatworm_name => 'Luipaardplatworm';

  @override
  String get species_leopard_flatworm_desc =>
      'Doorschijnende platworm met luipaardachtige vlekken die over rifbodems glijdt.';

  @override
  String get species_divided_flatworm_name => 'Gedeelde platworm';

  @override
  String get species_divided_flatworm_desc =>
      'Opvallende zwart-oranje platworm die giftige zeenaaktslakken nabootst als bescherming.';

  @override
  String get species_blue_pseudoceros_flatworm_name =>
      'Blauwe pseudoceros-platworm';

  @override
  String get species_blue_pseudoceros_flatworm_desc =>
      'Diepblauwe platworm met oranje rand, glijdend over Indo-Pacifische rifoppervlakken.';

  @override
  String get species_racing_stripe_flatworm_name => 'Racestreepplatworm';

  @override
  String get species_racing_stripe_flatworm_desc =>
      'Crèmekleurige platworm met een duidelijke donkere middenstreep en gegolfde rand.';

  @override
  String get species_christmas_tree_worm_name => 'Kerstboomworm';

  @override
  String get species_christmas_tree_worm_desc =>
      'Kleurrijke worm met spiraalvormige kroontjes in koraal, die zich razendsnel terugtrekt als je nadert.';

  @override
  String get species_feather_duster_worm_name => 'Plumeauworm';

  @override
  String get species_feather_duster_worm_desc =>
      'Kokerbewonende worm met een waaiervormige kroon van veerachtige radiolen om voedsel te filteren.';

  @override
  String get species_fire_worm_name => 'Bebaarde vuurworm';

  @override
  String get species_fire_worm_desc =>
      'Borstelworm met witte brandharen die bij aanraking pijnlijke irritatie veroorzaken.';

  @override
  String get species_bobbit_worm_name => 'Bobbitworm';

  @override
  String get species_bobbit_worm_desc =>
      'Hinderlaagjager die verscholen in het zand ligt en met krachtige kaken bliksemsnel toeslaat.';

  @override
  String get species_social_feather_duster_name => 'Sociale plumeauworm';

  @override
  String get species_social_feather_duster_desc =>
      'Koloniale kokerworm die op Caribische riffen groepen tere gebande kroontjes vormt.';

  @override
  String get species_giant_clam_name => 'Reuzenschelp';

  @override
  String get species_giant_clam_desc =>
      'De grootste levende tweekleppige, met iriserend mantelweefsel waarin symbiotische algen leven.';

  @override
  String get species_boring_clam_name => 'Borende doopvontschelp';

  @override
  String get species_boring_clam_desc =>
      'Kleine kleurrijke schelp die zich in koraalrots boort en alleen zijn felle mantel laat zien.';

  @override
  String get species_maxima_clam_name => 'Maxima-doopvontschelp';

  @override
  String get species_maxima_clam_desc =>
      'Schitterend gekleurde schelp die in rifrots is ingebed, met elektrisch blauwe en groene mantels.';

  @override
  String get species_flame_scallop_name => 'Vuurschelp';

  @override
  String get species_flame_scallop_desc =>
      'Rode tweekleppige met flitsend wit licht langs de mantelrand, te vinden in rifspleten.';

  @override
  String get species_thorny_oyster_name => 'Stekeloester';

  @override
  String get species_thorny_oyster_desc =>
      'Tweekleppige met stekelige schelp, vastgehecht aan rifrots en vaak begroeid met sponzen en algen.';

  @override
  String get species_magnificent_sea_anemone_name => 'Prachtzeeanemoon';

  @override
  String get species_magnificent_sea_anemone_desc =>
      'Grote kleurrijke anemoon die clownvissen herbergt, met een opvallende zuil en wuivende tentakels.';

  @override
  String get species_bubble_tip_anemone_name => 'Bubbelanemoon';

  @override
  String get species_bubble_tip_anemone_desc =>
      'Populaire gastheer voor clownvissen, met bolgepunte tentakels in groene, bruine of rozerode tinten.';

  @override
  String get species_giant_carpet_anemone_name => 'Reuzentapijtanemoon';

  @override
  String get species_giant_carpet_anemone_desc =>
      'Kolossale anemoon met korte kleverige tentakels die ruim een meter in doorsnede kan worden.';

  @override
  String get species_haddon_carpet_anemone_name => 'Haddons tapijtanemoon';

  @override
  String get species_haddon_carpet_anemone_desc =>
      'Platte tapijtanemoon op zandbodems die diverse clownvissen en porseleinkrabben herbergt.';

  @override
  String get species_long_tentacle_anemone_name => 'Langtentakelanemoon';

  @override
  String get species_long_tentacle_anemone_desc =>
      'Anemoon van zandbodems met lange wuivende tentakels, vaak met clownvissen erin.';

  @override
  String get species_tube_anemone_name => 'Kokeranemoon';

  @override
  String get species_tube_anemone_desc =>
      'Elegante anemoon die in een perkamentachtige koker in het zand leeft, met twee kransen tentakels.';

  @override
  String get species_hell_fire_anemone_name => 'Hellevuuranemoon';

  @override
  String get species_hell_fire_anemone_desc =>
      'Sterk netelende anemoon met vertakte tentakels die op zacht koraal lijken.';

  @override
  String get species_beaded_sea_anemone_name => 'Kralenzeeanemoon';

  @override
  String get species_beaded_sea_anemone_desc =>
      'Anemoon met gezwollen kraalvormige tentakeltoppen, op zandige Indo-Pacifische rifgebieden.';

  @override
  String get species_condylactis_anemone_name => 'Caribische reuzenanemoon';

  @override
  String get species_condylactis_anemone_desc =>
      'Grote Caribische anemoon met paarsgepunte tentakels, te vinden op rotsachtige rifbodems.';

  @override
  String get species_sand_anemone_name => 'Zandanemoon';

  @override
  String get species_sand_anemone_desc =>
      'Tere anemoon die deels in het zand is ingegraven, met paarsgepunte tentakels.';

  @override
  String get species_barrel_sponge_name => 'Reuzentonspons';

  @override
  String get species_barrel_sponge_desc =>
      'Kolossale tonvormige spons die eeuwenlang kan leven op Caribische rifwanden.';

  @override
  String get species_azure_vase_sponge_name => 'Azuurblauwe vaasspons';

  @override
  String get species_azure_vase_sponge_desc =>
      'Levendig blauwpaarse vaasvormige spons, te vinden op Caribische rifwanden.';

  @override
  String get species_yellow_tube_sponge_name => 'Gele buisspons';

  @override
  String get species_yellow_tube_sponge_desc =>
      'Felgele buisvormige spons die in trossen groeit op Caribische rifwanden.';

  @override
  String get species_elephant_ear_sponge_name => 'Olifantsoorspons';

  @override
  String get species_elephant_ear_sponge_desc =>
      'Grote oranje waaiervormige spons die op wanden en overhangen in het Caribisch gebied groeit.';

  @override
  String get species_rope_sponge_name => 'Touwspons';

  @override
  String get species_rope_sponge_desc =>
      'Rode rechtopstaande vertakte spons die touwachtige vormen aanneemt op Caribische riffen.';

  @override
  String get species_portuguese_man_o_war_name => 'Portugees oorlogsschip';

  @override
  String get species_portuguese_man_o_war_desc =>
      'Koloniale hydropoliep met een gasgevuld drijflichaam en uiterst pijnlijke slepende tentakels.';

  @override
  String get species_fire_coral_name => 'Vuurkoraal';

  @override
  String get species_fire_coral_desc =>
      'Geen echt koraal maar een hydropoliep die duikers bij aanraking pijnlijke netelwonden bezorgt.';

  @override
  String get species_by_the_wind_sailor_name => 'Zeilkwal';

  @override
  String get species_by_the_wind_sailor_desc =>
      'Blauwe drijvende hydropoliepkolonie met een diagonaal zeil dat de wind vangt.';

  @override
  String get species_blue_button_name => 'Blauwe knoop';

  @override
  String get species_blue_button_desc =>
      'Drijvende koloniale hydropoliep met een platte schijf en blauwe tentakelachtige poliepen.';

  @override
  String get species_giant_sea_hare_name => 'Reuzenzeehaas';

  @override
  String get species_giant_sea_hare_desc =>
      'Een van de grootste zeeslakken, donkerbruin tot zwart, te vinden in kelpvelden.';

  @override
  String get species_sea_hare_name => 'Gevlekte zeehaas';

  @override
  String get species_sea_hare_desc =>
      'Grote groengevlekte zeehaas die bij verstoring paarse inkt uitstoot.';

  @override
  String get species_nudibranch_berghia_name => 'Berghia-zeenaaktslak';

  @override
  String get species_nudibranch_berghia_desc =>
      'Doorschijnende aeolide zeenaaktslak met witgepunte cerata die zich met anemonen voedt.';

  @override
  String get species_sea_pen_name => 'Zeeveer';

  @override
  String get species_sea_pen_desc =>
      'Veervormige koloniale octokoraal die in het zand is verankerd en zich bij verstoring terugtrekt.';

  @override
  String get species_blue_sea_star_name => 'Blauwe zeester';

  @override
  String get species_blue_sea_star_desc =>
      'Veelkleurige zeester die uit één losse arm kan regenereren, op Indo-Pacifische riffen.';

  @override
  String get species_reef_squid_name => 'Rifpijlinktvis';

  @override
  String get species_reef_squid_desc =>
      'Zuidelijke rifpijlinktvis die veel wordt gezien in gematigde Australische wateren.';

  @override
  String get species_tiger_shrimp_name => 'Tijgergarnaal';

  @override
  String get species_tiger_shrimp_desc =>
      'Grote gebande garnaal op zandbodems en in zeegrasvelden in de Indo-Pacific.';

  @override
  String get species_candy_crab_name => 'Snoepkrab';

  @override
  String get species_candy_crab_desc =>
      'Piepkleine kleurrijke krab die met roze of gele stekelige uitsteeksels bij zijn zachtkoraalgastheer past.';

  @override
  String get species_spider_crab_name => 'Spinnendecoratiekrab';

  @override
  String get species_spider_crab_desc =>
      'Traag bewegende krab bedekt met vastgeplakte sponzen en algen als camouflage.';

  @override
  String get species_anemone_shrimp_name => 'Prachtanemoongarnaal';

  @override
  String get species_anemone_shrimp_desc =>
      'Doorzichtige garnaal met witte en paarse tekening die tussen anemoontentakels leeft.';

  @override
  String get species_snapping_shrimp_name => 'Pistoolgarnaal';

  @override
  String get species_snapping_shrimp_desc =>
      'Kleine garnaal die met zijn buitenmaatse schaar een luide knal produceert, vaak in duo met grondels.';

  @override
  String get species_glass_sponge_name => 'Bloemenmandje van Venus';

  @override
  String get species_glass_sponge_desc =>
      'Tere glasspons met een fijn silicaatskelet, te vinden in diep water.';

  @override
  String get species_toxic_sea_urchin_name => 'Bloemzee-egel';

  @override
  String get species_toxic_sea_urchin_desc =>
      'Bedrieglijk mooie zee-egel bedekt met bloemachtige pedicellariën met krachtig gif.';

  @override
  String get species_slate_pencil_urchin_name => 'Griffelzee-egel';

  @override
  String get species_slate_pencil_urchin_desc =>
      'Zee-egel met dikke afgeronde stekels, te vinden op Caribische en Atlantische rifbodems.';

  @override
  String get species_spiny_sea_star_name => 'Gedoornde zeester';

  @override
  String get species_spiny_sea_star_desc =>
      'Grote zeester van gematigde streken met opvallende stekels, in Europese en Atlantische wateren.';

  @override
  String get species_bat_star_name => 'Vleermuiszeester';

  @override
  String get species_bat_star_desc =>
      'Pacifische zeester met zwemvliesachtige armen in oranje, rood of paars, te vinden in kelpwouden.';

  @override
  String get species_sunflower_star_name => 'Zonnebloemzeester';

  @override
  String get species_sunflower_star_desc =>
      'Kolossale, snel bewegende zeester met tot 24 armen, te vinden in Pacifische kelpwouden.';

  @override
  String get species_blood_star_name => 'Bloedzeester';

  @override
  String get species_blood_star_desc =>
      'Feloranjerode zeester met slanke armen, voorkomend in gematigde Pacifische wateren.';

  @override
  String get species_common_cuttlefish_name => 'Gewone zeekat';

  @override
  String get species_common_cuttlefish_desc =>
      'Meester in camouflage met W-vormige pupillen, voorkomend in Europese en mediterrane wateren.';

  @override
  String get species_blue_spotted_crab_name => 'Blauwgevlekte zwemkrab';

  @override
  String get species_blue_spotted_crab_desc =>
      'Actieve zwemkrab met blauwe stippen op het rugschild, op zandige Indo-Pacifische bodems.';

  @override
  String get species_sponge_crab_name => 'Sponskrab';

  @override
  String get species_sponge_crab_desc =>
      'Krab die een levende spons uitsnijdt en als camouflage op zijn rug meedraagt.';

  @override
  String get species_horseshoe_crab_name => 'Degenkrab';

  @override
  String get species_horseshoe_crab_desc =>
      'Oeroud geleedpotig dier met een helmvormig schild, te vinden op Atlantische zandbodems.';

  @override
  String get species_sea_spider_name => 'Zeespin';

  @override
  String get species_sea_spider_desc =>
      'Teer langpotig zeegeleedpotige dat over hydroïdpoliepen en mosdiertjes kruipt.';

  @override
  String get species_sea_lily_name => 'Zeelelie';

  @override
  String get species_sea_lily_desc =>
      'Gesteeld levend fossiel uit de haarsterrengroep dat in dieper water met veerachtige armen voedsel filtert.';

  @override
  String get species_mantis_shrimp_lysiosquilla_name =>
      'Speerbidsprinkhaankreeft';

  @override
  String get species_mantis_shrimp_lysiosquilla_desc =>
      'Grote gravende bidsprinkhaankreeft met speervormige aanhangsels, te vinden op zandbodems.';

  @override
  String get species_purple_sea_urchin_name => 'Paarse zee-egel';

  @override
  String get species_purple_sea_urchin_desc =>
      'Talrijke paarse zee-egel in Pacifische kelpwouden en rotsige getijdenpoelen.';

  @override
  String get species_crown_jellyfish_name => 'Kroonkwal';

  @override
  String get species_crown_jellyfish_desc =>
      'Dieppaarse kwal met een verhoogde kroonvormige klok, voorkomend in de Indo-Pacific.';

  @override
  String get species_comb_jelly_name => 'Zeedruif';

  @override
  String get species_comb_jelly_desc =>
      'Klein bioluminescent ribkwalletje met iriserende kamrijen en twee lange tentakels.';

  @override
  String get species_warty_sea_slug_name => 'Wrattige zeeslak';

  @override
  String get species_warty_sea_slug_desc =>
      'Blauw-zwarte zeenaaktslak met geelgekapte knobbels, veel gezien op Indo-Pacifische riffen.';

  @override
  String get species_doris_nudibranch_name => 'Zeecitroen';

  @override
  String get species_doris_nudibranch_desc =>
      'Geel gevlekte dorisslak uit gematigde Pacifische wateren die zich met sponzen voedt.';

  @override
  String get species_opalescent_nudibranch_name => 'Opalescerende zeenaaktslak';

  @override
  String get species_opalescent_nudibranch_desc =>
      'Doorschijnende aeolide slak met feloranje cerata en blauwe ruglijnen in Pacifische wateren.';

  @override
  String get species_clown_nudibranch_name => 'Clownzeenaaktslak';

  @override
  String get species_clown_nudibranch_desc =>
      'Roze-oranje zeenaaktslak met blauwe en witte stippen, voorkomend in gematigde Australische wateren.';

  @override
  String get species_bottlenose_dolphin_name => 'Tuimelaar';

  @override
  String get species_bottlenose_dolphin_desc =>
      'Nieuwsgierige en speelse dolfijn die duikers vaak ontmoeten in tropische en gematigde wateren.';

  @override
  String get species_spinner_dolphin_name => 'Langsnuitdolfijn';

  @override
  String get species_spinner_dolphin_desc =>
      'Acrobatische dolfijn die bekendstaat om zijn draaisprongen, vaak in grote scholen bij koraalriffen.';

  @override
  String get species_common_dolphin_name => 'Gewone dolfijn';

  @override
  String get species_common_dolphin_desc =>
      'Snelzwemmende dolfijn met een kenmerkend zandlopermotief, in open oceaan en kustwateren.';

  @override
  String get species_spotted_dolphin_name => 'Atlantische gevlekte dolfijn';

  @override
  String get species_spotted_dolphin_desc =>
      'Vriendelijke gevlekte dolfijn die duikers regelmatig benadert op de Bahama\'s en in het Caribisch gebied.';

  @override
  String get species_rissos_dolphin_name => 'Grijze dolfijn';

  @override
  String get species_rissos_dolphin_desc =>
      'Grote dolfijn met een zwaar bekrast grijs lichaam, wereldwijd in diepe wateren ver uit de kust.';

  @override
  String get species_humpback_whale_name => 'Bultrug';

  @override
  String get species_humpback_whale_desc =>
      'Majestueuze walvis die bekendstaat om zijn sprongen en complexe zang, te zien tijdens de seizoenstrek.';

  @override
  String get species_grey_whale_name => 'Grijze walvis';

  @override
  String get species_grey_whale_desc =>
      'Baleinwalvis die op de bodem foerageert en langs de Pacifische kust trekt, vaak bedekt met zeepokken.';

  @override
  String get species_blue_whale_name => 'Blauwe vinvis';

  @override
  String get species_blue_whale_desc =>
      'Het grootste dier dat ooit heeft geleefd, af en toe door duikers ontmoet in diepblauw water.';

  @override
  String get species_sperm_whale_name => 'Potvis';

  @override
  String get species_sperm_whale_desc =>
      'Diepduikende walvis met een enorme kop, soms rustend aan het oppervlak tussen duiken door.';

  @override
  String get species_orca_name => 'Orka';

  @override
  String get species_orca_desc =>
      'Toppredator met kenmerkende zwart-witte tekening, voorkomend in alle oceanen.';

  @override
  String get species_minke_whale_name => 'Dwergvinvis';

  @override
  String get species_minke_whale_desc =>
      'Kleinere baleinwalvis die nieuwsgierig is naar duikers, vooral bij het Great Barrier Reef.';

  @override
  String get species_beluga_whale_name => 'Beloega';

  @override
  String get species_beluga_whale_desc =>
      'Witte arctische walvis die bekendstaat om zijn geluiden en gezellige gedrag in koude wateren.';

  @override
  String get species_pilot_whale_name => 'Indische griend';

  @override
  String get species_pilot_whale_desc =>
      'Sociale diepduikende walvis, vaak in grote groepen in tropische en warm gematigde zeeën.';

  @override
  String get species_false_killer_whale_name => 'Zwarte zwaardwalvis';

  @override
  String get species_false_killer_whale_desc =>
      'Grote oceanische dolfijn die duikers af en toe in open water benadert.';

  @override
  String get species_dugong_name => 'Doejong';

  @override
  String get species_dugong_desc =>
      'Vreedzame planteneter die zeegrasvelden in de Indo-Pacific afgraast, nauw verwant aan de lamantijnen.';

  @override
  String get species_west_indian_manatee_name => 'Caribische lamantijn';

  @override
  String get species_west_indian_manatee_desc =>
      'Traag bewegende planteneter in warme ondiepe wateren, estuaria en bronnen van het Caribisch gebied.';

  @override
  String get species_sea_otter_name => 'Zeeotter';

  @override
  String get species_sea_otter_desc =>
      'Charismatisch zeezoogdier dat in kelpwouden langs de Noord-Pacifische kust leeft.';

  @override
  String get species_california_sea_lion_name => 'Californische zeeleeuw';

  @override
  String get species_california_sea_lion_desc =>
      'Speelse en behendige zeeleeuw die langs de Pacifische kust vaak met duikers speelt.';

  @override
  String get species_steller_sea_lion_name => 'Stellerzeeleeuw';

  @override
  String get species_steller_sea_lion_desc =>
      'Grootste zeeleeuwensoort, te vinden in koude Noord-Pacifische wateren bij rotsachtige kusten.';

  @override
  String get species_harbor_seal_name => 'Gewone zeehond';

  @override
  String get species_harbor_seal_desc =>
      'Nieuwsgierige zeehond in gematigde kustwateren, vaak rustend op rotsen bij duikstekken.';

  @override
  String get species_grey_seal_name => 'Grijze zeehond';

  @override
  String get species_grey_seal_desc =>
      'Grote speelse zeehond uit de Noord-Atlantische Oceaan, bekend omdat hij duikers onder water opzoekt.';

  @override
  String get species_northern_elephant_seal_name => 'Noordelijke zeeolifant';

  @override
  String get species_northern_elephant_seal_desc =>
      'Kolossale diepduikende zeehond; mannetjes hebben een grote slurf. Te vinden langs de oostelijke Pacifische kust.';

  @override
  String get species_hawaiian_monk_seal_name => 'Hawaïaanse monniksrob';

  @override
  String get species_hawaiian_monk_seal_desc =>
      'Ernstig bedreigde zeehond endemisch op Hawaï, af en toe door duikers op riffen gezien.';

  @override
  String get species_leopard_seal_name => 'Zeeluipaard';

  @override
  String get species_leopard_seal_desc =>
      'Krachtige Antarctische jager met gevlekte vacht, te ontmoeten door koudwaterduikers.';

  @override
  String get species_narwhal_name => 'Narwal';

  @override
  String get species_narwhal_desc =>
      'Arctische walvis met een lange spiraalvormige slagtand, zelden gezien maar iconisch onder de zeezoogdieren.';

  @override
  String get species_green_sea_turtle_name => 'Soepschildpad';

  @override
  String get species_green_sea_turtle_desc =>
      'Grote zeeschildpad die vaak grazend op zeegras in tropische wateren wordt gezien.';

  @override
  String get species_hawksbill_sea_turtle_name => 'Karetschildpad';

  @override
  String get species_hawksbill_sea_turtle_desc =>
      'Rifbewonende schildpad met een spitse snavel die zich met sponzen tussen koraalformaties voedt.';

  @override
  String get species_loggerhead_sea_turtle_name => 'Onechte karetschildpad';

  @override
  String get species_loggerhead_sea_turtle_desc =>
      'Schildpad met een grote kop, voorkomend in gematigde en tropische zeeën, vaak bij rotsriffen.';

  @override
  String get species_leatherback_sea_turtle_name => 'Lederschildpad';

  @override
  String get species_leatherback_sea_turtle_desc =>
      'Grootste levende schildpad met een flexibel leerachtig schild, duikt tot extreme diepten.';

  @override
  String get species_olive_ridley_sea_turtle_name => 'Olijfschildpad';

  @override
  String get species_olive_ridley_sea_turtle_desc =>
      'Kleinste zeeschildpadsoort, bekend om de massale gelijktijdige nestafzet die arribada wordt genoemd.';

  @override
  String get species_kemps_ridley_sea_turtle_name => 'Kemps zeeschildpad';

  @override
  String get species_kemps_ridley_sea_turtle_desc =>
      'Ernstig bedreigde zeeschildpad die vooral in de Golf van Mexico voorkomt.';

  @override
  String get species_flatback_sea_turtle_name =>
      'Australische platrugschildpad';

  @override
  String get species_flatback_sea_turtle_desc =>
      'Endemisch in Australische wateren, herkenbaar aan het platte schild en de kustgebonden leefwijze.';

  @override
  String get species_brain_coral_name => 'Hersenkoraal';

  @override
  String get species_brain_coral_desc =>
      'Massief rifbouwend koraal met een gegroefd oppervlak als een hersenen, algemeen op Caribische riffen.';

  @override
  String get species_staghorn_coral_name => 'Hertshoornkoraal';

  @override
  String get species_staghorn_coral_desc =>
      'Snelgroeiend vertakt koraal dat dichte struiken vormt, een cruciale leefomgeving voor rifvissen.';

  @override
  String get species_elkhorn_coral_name => 'Elandshoornkoraal';

  @override
  String get species_elkhorn_coral_desc =>
      'Groot vertakt koraal met platte handvormige takken, een sleutelbouwer van Caribische riffen.';

  @override
  String get species_table_coral_name => 'Tafelkoraal';

  @override
  String get species_table_coral_desc =>
      'Vlak plaatvormend koraal op Indo-Pacifische riffen dat schuilplaats biedt aan veel vissoorten.';

  @override
  String get species_mushroom_coral_name => 'Paddenstoelkoraal';

  @override
  String get species_mushroom_coral_desc =>
      'Vrijlevend solitair koraal in de vorm van een schijf, op zandige plekken bij Indo-Pacifische riffen.';

  @override
  String get species_bubble_coral_name => 'Bellenkoraal';

  @override
  String get species_bubble_coral_desc =>
      'Kenmerkend koraal met druifachtige blaasjes die zich overdag opblazen om licht te vangen.';

  @override
  String get species_plate_coral_name => 'Plaatkoraal';

  @override
  String get species_plate_coral_desc =>
      'Dun plaatvormend koraal dat spiraalvormige richels vormt, algemeen op Indo-Pacifische rifhellingen.';

  @override
  String get species_pillar_coral_name => 'Pilaarkoraal';

  @override
  String get species_pillar_coral_desc =>
      'Zeldzaam omhoog groeiend koraal dat hoge zuilen vormt, voorkomend in het Caribisch gebied.';

  @override
  String get species_star_coral_name => 'Sterkoraal';

  @override
  String get species_star_coral_desc =>
      'Belangrijke Caribische rifbouwer die grote keivormige kolonies met stervormige poliepen vormt.';

  @override
  String get species_lettuce_coral_name => 'Slakoraal';

  @override
  String get species_lettuce_coral_desc =>
      'Dun plaatvormend koraal met bladachtige plooien, algemeen op Caribische rifwanden en -hellingen.';

  @override
  String get species_finger_coral_name => 'Vingerkoraal';

  @override
  String get species_finger_coral_desc =>
      'Stevig vertakt koraal met dikke vingerachtige uitsteeksels, te vinden op ondiepe riffen.';

  @override
  String get species_massive_porites_name => 'Massief poriteskoraal';

  @override
  String get species_massive_porites_desc =>
      'Groot keikoraal dat eeuwenlang kan doorgroeien, een dominante rifbouwer in de Indo-Pacific.';

  @override
  String get species_cauliflower_coral_name => 'Bloemkoolkoraal';

  @override
  String get species_cauliflower_coral_desc =>
      'Compact vertakt koraal in de vorm van een bloemkool, wijdverbreid in ondiepe tropische riffen.';

  @override
  String get species_flower_pot_coral_name => 'Bloempotkoraal';

  @override
  String get species_flower_pot_coral_desc =>
      'Kolonie van langtentakelige poliepen die zich overdag uitstrekken als een boeket bloemen.';

  @override
  String get species_cup_coral_name => 'Oranje bekerkoraal';

  @override
  String get species_cup_coral_desc =>
      'Feloranje niet-fotosynthetisch koraal op wanden en onder overhangen in tropische wateren.';

  @override
  String get species_scroll_coral_name => 'Rolkoraal';

  @override
  String get species_scroll_coral_desc =>
      'Koraal dat grote opgerolde platen vormt, algemeen op Indo-Pacifische rifhellingen en in lagunes.';

  @override
  String get species_cabbage_coral_name => 'Koolkoraal';

  @override
  String get species_cabbage_coral_desc =>
      'Schijfvormig plaatkoraal dat op koolbladeren lijkt, te vinden in beschutte rifgebieden.';

  @override
  String get species_hammer_coral_name => 'Hamerkoraal';

  @override
  String get species_hammer_coral_desc =>
      'Grootpoliepig koraal met anker- of hamervormige tentakeltoppen, geliefd op Indo-Pacifische riffen.';

  @override
  String get species_torch_coral_name => 'Fakkelkoraal';

  @override
  String get species_torch_coral_desc =>
      'Vertakt koraal met lange wuivende tentakels die eindigen in gloeiende bolletjes.';

  @override
  String get species_frogspawn_coral_name => 'Kikkerdrilkoraal';

  @override
  String get species_frogspawn_coral_desc =>
      'Grootpoliepig koraal met vertakte tentakeltoppen die op kikkerdril lijken.';

  @override
  String get species_sea_fan_name => 'Gewone zeewaaier';

  @override
  String get species_sea_fan_desc =>
      'Platte waaiervormige gorgoon die haaks op de stroming staat, iconisch op Caribische riffen.';

  @override
  String get species_venus_sea_fan_name => 'Venuszeewaaier';

  @override
  String get species_venus_sea_fan_desc =>
      'Tere waaiervormige gorgoon op ondiepe Caribische riffen met matige stroming.';

  @override
  String get species_deepwater_sea_fan_name => 'Diepwaterzeewaaier';

  @override
  String get species_deepwater_sea_fan_desc =>
      'Grote struikachtige gorgoon op diepe rifwanden in het Caribisch gebied.';

  @override
  String get species_sea_whip_name => 'Zeezweep';

  @override
  String get species_sea_whip_desc =>
      'Slanke staafvormige gorgoon die meewuift met de stroming op Atlantische en Caribische riffen.';

  @override
  String get species_sea_plume_name => 'Zeepluim';

  @override
  String get species_sea_plume_desc =>
      'Hoge veerachtige gorgoon die pluimvormige kolonies vormt op Caribische riftoppen.';

  @override
  String get species_organ_pipe_coral_name => 'Orgelpijpkoraal';

  @override
  String get species_organ_pipe_coral_desc =>
      'Felrode skeletbuisjes met tere poliepen, te vinden op beschutte Indo-Pacifische riffen.';

  @override
  String get species_leather_coral_name => 'Leerkoraal';

  @override
  String get species_leather_coral_desc =>
      'Zacht koraal met een glad leerachtig oppervlak dat grote paddenstoelvormige kolonies vormt.';

  @override
  String get species_toadstool_leather_coral_name => 'Paddenstoelleerkoraal';

  @override
  String get species_toadstool_leather_coral_desc =>
      'Zacht koraal met een dikke steel en platte hoed, algemeen op Indo-Pacifische rifplaten.';

  @override
  String get species_pulsing_xenia_name => 'Pulserende xenia';

  @override
  String get species_pulsing_xenia_desc =>
      'Zacht koraal met ritmisch pulserende poliepen, voorkomend in beschutte Indo-Pacifische wateren.';

  @override
  String get species_tree_coral_name => 'Boomkoraal';

  @override
  String get species_tree_coral_desc =>
      'Levendig zacht koraal dat boomachtige groepen vormt op wanden en onder overhangen in de Rode Zee.';

  @override
  String get species_blue_coral_name => 'Blauw koraal';

  @override
  String get species_blue_coral_desc =>
      'Bijzonder octokoraal met een blauw skelet, te vinden op ondiepe Indo-Pacifische rifplaten.';

  @override
  String get species_black_coral_name => 'Zwart koraal';

  @override
  String get species_black_coral_desc =>
      'Diepwaterkoraal met een donker skelet, te vinden op wanden en steilwanden beneden 30 meter.';

  @override
  String get species_carnation_coral_name => 'Anjerkoraal';

  @override
  String get species_carnation_coral_desc =>
      'Felgekleurd zacht koraal onder overhangen en op wanden in de Indo-Pacific.';

  @override
  String get species_wire_coral_name => 'Draadkoraal';

  @override
  String get species_wire_coral_desc =>
      'Lang spiraalvormig zwart koraal dat opgerolde zwepen vormt, gastheer voor grondels en garnalen.';

  @override
  String get species_dead_mans_fingers_name => 'Dodemansduim';

  @override
  String get species_dead_mans_fingers_desc =>
      'Vlezig zacht koraal met vingervormige lobben, algemeen op gematigde Noord-Atlantische riffen.';

  @override
  String get species_sun_coral_name => 'Zonnekoraal';

  @override
  String get species_sun_coral_desc =>
      'Geeloranje niet-fotosynthetisch koraal dat zijn poliepen \'s nachts opent op Indo-Pacifische wanden.';

  @override
  String get species_lace_coral_name => 'Kantkoraal';

  @override
  String get species_lace_coral_desc =>
      'Teer roze hydrokoraal met kantachtige takjes, te vinden in spleten en onder overhangen.';

  @override
  String get species_kenya_tree_coral_name => 'Kenia-boomkoraal';

  @override
  String get species_kenya_tree_coral_desc =>
      'Sterk zacht koraal met boomachtige takken, algemeen in de Indo-Pacific.';

  @override
  String get species_colt_coral_name => 'Coltkoraal';

  @override
  String get species_colt_coral_desc =>
      'Zacht koraal met dikke rubberachtige takken vol kleine poliepen op Indo-Pacifische riffen.';

  @override
  String get species_turtle_grass_name => 'Schildpadgras';

  @override
  String get species_turtle_grass_desc =>
      'Dominant Caribisch zeegras met brede platte bladen, een essentiële voedselbron voor zeeschildpadden.';

  @override
  String get species_eelgrass_name => 'Groot zeegras';

  @override
  String get species_eelgrass_desc =>
      'Zeegras van gematigde streken dat dichte onderwaterweiden vormt en dient als kraamkamer.';

  @override
  String get species_manatee_grass_name => 'Lamantijngras';

  @override
  String get species_manatee_grass_desc =>
      'Zeegras met cilindrische bladen op Caribische zandbodems, vaak vlak bij velden schildpadgras.';

  @override
  String get species_shoal_grass_name => 'Smalbladig zeegras';

  @override
  String get species_shoal_grass_desc =>
      'Pionierzeegras met smalle bladen dat verstoorde zandgebieden in het Caribisch gebied koloniseert.';

  @override
  String get species_paddle_grass_name => 'Peddelgras';

  @override
  String get species_paddle_grass_desc =>
      'Klein teer zeegras met ovale blaadjes, te vinden in dieper water in de hele tropen.';

  @override
  String get species_neptune_grass_name => 'Neptunusgras';

  @override
  String get species_neptune_grass_desc =>
      'Mediterraan zeegras dat uitgestrekte weiden vormt die cruciaal zijn voor kustecosystemen.';

  @override
  String get species_giant_kelp_name => 'Reuzenkelp';

  @override
  String get species_giant_kelp_desc =>
      'Torenhoge onderwaterwoudsoort die tot 60 meter groeit, iconisch voor het duiken in Californië.';

  @override
  String get species_bull_kelp_name => 'Stierkelp';

  @override
  String get species_bull_kelp_desc =>
      'Pacifische kelp met één lange steel en een bolvormig drijflichaam, vormt dichte bladerdakwouden.';

  @override
  String get species_bladder_wrack_name => 'Blaaswier';

  @override
  String get species_bladder_wrack_desc =>
      'Algemeen bruinwier met gepaarde luchtblazen, te vinden in getijdenzones van de Noord-Atlantische Oceaan.';

  @override
  String get species_sargassum_name => 'Sargassowier';

  @override
  String get species_sargassum_desc =>
      'Vrij drijvend bruinwier dat vlotten vormt waarin jonge vissen en ongewervelden schuilen.';

  @override
  String get species_kelp_forest_ecklonia_name => 'Ecklonia-kelp';

  @override
  String get species_kelp_forest_ecklonia_desc =>
      'Dominante kelp in wateren van het zuidelijk halfrond, vormt belangrijke onderwaterwouden.';

  @override
  String get species_coralline_algae_name => 'Kalkroodwier';

  @override
  String get species_coralline_algae_desc =>
      'Hard korstvormend roodwier dat rifstructuren aaneenkit en riffen een roze gloed geeft.';

  @override
  String get species_irish_moss_name => 'Iers mos';

  @override
  String get species_irish_moss_desc =>
      'Waaiervormig roodwier op rotskusten in de getijdenzone van de Noord-Atlantische Oceaan.';

  @override
  String get species_dulse_name => 'Duls';

  @override
  String get species_dulse_desc =>
      'Plat roodpaars wier dat op rotsen en kelpstelen in koude noordelijke wateren groeit.';

  @override
  String get species_halimeda_name => 'Halimeda';

  @override
  String get species_halimeda_desc =>
      'Verkalkt groenwier met schijfvormige segmenten, een belangrijke bron van rifzand.';

  @override
  String get species_sea_lettuce_name => 'Zeesla';

  @override
  String get species_sea_lettuce_desc =>
      'Felgroen bladvormig wier in ondiepe kustwateren wereldwijd.';

  @override
  String get species_caulerpa_name => 'Groen druivenwier';

  @override
  String get species_caulerpa_desc =>
      'Kruipend groenwier met druifachtige loten, te vinden op tropisch rifpuin en zand.';

  @override
  String get species_mermaid_fan_name => 'Zeemeerminwaaier';

  @override
  String get species_mermaid_fan_desc =>
      'Verkalkt groenwier in de vorm van een kleine waaier, algemeen op Caribische zandbodems.';

  @override
  String get species_shaving_brush_algae_name => 'Scheerkwastwier';

  @override
  String get species_shaving_brush_algae_desc =>
      'Verkalkt groenwier met een kwastachtige pluim op een steel, te vinden op Caribische zandbodems.';

  @override
  String get species_finger_kelp_name => 'Vingerwier';

  @override
  String get species_finger_kelp_desc =>
      'Bruinwier met vingervormige bladen dat kelpvelden vormt in Noord-Atlantische kustwateren.';

  @override
  String get species_banded_sea_krait_name => 'Gebande zeekrait';

  @override
  String get species_banded_sea_krait_desc =>
      'Giftige zeeslang met blauwgrijze en zwarte banden, rustig van aard en veel gezien op Indo-Pacifische riffen.';

  @override
  String get species_olive_sea_snake_name => 'Olijfkleurige zeeslang';

  @override
  String get species_olive_sea_snake_desc =>
      'Nieuwsgierige zeeslang op Australische riffen, bekend omdat hij duikers benadert.';

  @override
  String get species_yellow_bellied_sea_snake_name => 'Geelbuikzeeslang';

  @override
  String get species_yellow_bellied_sea_snake_desc =>
      'Pelagische zeeslang met gele onderzijde, de meest wijdverbreide slangensoort op aarde.';

  @override
  String get species_marine_iguana_name => 'Zeeleguaan';

  @override
  String get species_marine_iguana_desc =>
      'Endemisch op de Galapagos, de enige hagedis die onder water op algen foerageert.';

  @override
  String get species_saltwater_crocodile_name => 'Zoutwaterkrokodil';

  @override
  String get species_saltwater_crocodile_desc =>
      'Grootste levende reptiel, voorkomend in kust- en estuariumwateren van de Indo-Pacific.';

  @override
  String get common_action_done => 'Gereed';

  @override
  String get common_action_more => 'Meer';

  @override
  String get common_label_displayName => 'Weergavenaam';

  @override
  String common_relativeTime_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}d geleden',
      one: '${count}d geleden',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}u geleden',
      one: '${count}u geleden',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'over ${count}d',
      one: 'over ${count}d',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'over ${count}u',
      one: 'over ${count}u',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_inLessThanMinute => 'over <1m';

  @override
  String common_relativeTime_inMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'over ${count}m',
      one: 'over ${count}m',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_justNow => 'zojuist';

  @override
  String common_relativeTime_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}m geleden',
      one: '${count}m geleden',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}mnd geleden',
      one: '${count}mnd geleden',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_overdue => 'te laat';

  @override
  String get media_cache_calculating => 'Cachegrootte berekenen…';

  @override
  String get media_cache_cardTitle => 'Cachebeheer';

  @override
  String get media_cache_clearAction => 'Cache wissen';

  @override
  String get media_cache_clearBody =>
      'Verwijdert gedownloade miniaturen en netwerkafbeeldingen op volledige grootte. Gekoppelde media blijven behouden; afbeeldingen worden bij de volgende weergave opnieuw gedownload.';

  @override
  String get media_cache_clearConfirm => 'Wissen';

  @override
  String media_cache_clearError(String error) {
    return 'Wissen mislukt: $error';
  }

  @override
  String get media_cache_clearTitle => 'Cache met netwerkafbeeldingen wissen?';

  @override
  String get media_cache_cleared => 'Cache gewist';

  @override
  String get media_cache_diskCache => 'Schijfcache';

  @override
  String media_cache_error(String error) {
    return 'Fout: $error';
  }

  @override
  String get media_credentials_actionTest => 'Inloggegevens testen';

  @override
  String media_credentials_authLabel(String authType) {
    return 'Auth: $authType';
  }

  @override
  String get media_credentials_deleteBody =>
      'Verwijdert de opgeslagen inloggegevens. Items die via deze host zijn gekoppeld, tonen ‘Log in om te bekijken’ totdat je ze opnieuw toevoegt.';

  @override
  String media_credentials_deleteError(String error) {
    return 'Verwijderen mislukt: $error';
  }

  @override
  String media_credentials_deleteTitle(String host) {
    return '$host verwijderen?';
  }

  @override
  String media_credentials_deleted(String host) {
    return '$host verwijderd';
  }

  @override
  String media_credentials_editTitle(String host) {
    return '$host bewerken';
  }

  @override
  String get media_credentials_emptySubtitle =>
      'Inloggegevens per host die tijdens URL- of manifest-imports zijn toegevoegd, verschijnen hier.';

  @override
  String get media_credentials_emptyTitle => 'Geen opgeslagen inloggegevens';

  @override
  String media_credentials_lastUsed(String when) {
    return 'Laatst gebruikt $when';
  }

  @override
  String get media_credentials_loadError => 'Kan opgeslagen hosts niet laden';

  @override
  String get media_credentials_loading => 'Opgeslagen hosts laden...';

  @override
  String media_credentials_saveError(String error) {
    return 'Opslaan mislukt: $error';
  }

  @override
  String get media_credentials_savedHostsTitle => 'Opgeslagen hosts';

  @override
  String media_credentials_testError(String error) {
    return 'Test mislukt: $error';
  }

  @override
  String media_credentials_testFailed(String host) {
    return 'Inloggegevens geweigerd voor $host';
  }

  @override
  String media_credentials_testOk(String host) {
    return 'Inloggegevens in orde voor $host';
  }

  @override
  String get media_manifest_actionPollNow => 'Nu ophalen';

  @override
  String get media_manifest_cardTitle => 'Manifest-abonnementen';

  @override
  String get media_manifest_deleteBody =>
      'Verwijdert het abonnement. Al geïmporteerde items blijven behouden (je kunt ze opruimen via de wachtrij met wezen).';

  @override
  String media_manifest_deleteError(String error) {
    return 'Verwijderen mislukt: $error';
  }

  @override
  String media_manifest_deleteTitle(String name) {
    return '$name verwijderen?';
  }

  @override
  String get media_manifest_editTitle => 'Abonnement bewerken';

  @override
  String get media_manifest_emptySubtitle =>
      'Abonneer je op het tabblad URL op een Atom/RSS-, JSON- of CSV-manifest om je bibliotheek gesynchroniseerd te houden.';

  @override
  String get media_manifest_emptyTitle => 'Geen manifest-abonnementen';

  @override
  String media_manifest_lastError(String error) {
    return 'Laatste fout: $error';
  }

  @override
  String media_manifest_lastPolled(String when) {
    return 'Laatst opgehaald $when';
  }

  @override
  String get media_manifest_loadError => 'Kan abonnementen niet laden';

  @override
  String get media_manifest_loading => 'Abonnementen laden...';

  @override
  String get media_manifest_neverPolled => 'Nooit opgehaald';

  @override
  String media_manifest_nextPoll(String when) {
    return 'Volgende $when';
  }

  @override
  String get media_manifest_notFound => 'Abonnement niet gevonden';

  @override
  String media_manifest_pollError(String error) {
    return 'Ophalen mislukt: $error';
  }

  @override
  String media_manifest_polled(String name) {
    return '$name opgehaald';
  }

  @override
  String media_manifest_polling(String name) {
    return '$name ophalen...';
  }

  @override
  String media_manifest_saveError(String error) {
    return 'Opslaan mislukt: $error';
  }

  @override
  String media_manifest_updateError(String error) {
    return 'Kan niet bijwerken: $error';
  }

  @override
  String get media_manifest_urlLabel => 'Manifest-URL';

  @override
  String media_scan_failed(String error) {
    return 'Scannen mislukt: $error';
  }

  @override
  String media_scan_progressItems(int done, int total) {
    return '$done / $total items';
  }

  @override
  String media_scan_progressReachability(int available, int unreachable) {
    return '$available bereikbaar  ·  $unreachable onbereikbaar';
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
          '$total items in ${seconds}s gescand: $available bereikbaar, $unreachable onbereikbaar',
      one:
          '$total item in ${seconds}s gescand: $available bereikbaar, $unreachable onbereikbaar',
    );
    return '$_temp0';
  }

  @override
  String media_scan_summarySkipped(String base, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count overgeslagen (geen URL)',
      one: '$count overgeslagen (geen URL)',
    );
    return '$base, $_temp0';
  }

  @override
  String get media_scan_title => 'Alle netwerkmedia scannen';

  @override
  String get settings_mediaSources_androidUriTitle =>
      'Android-URI-machtigingen';

  @override
  String settings_mediaSources_androidUriUsage(int used, int limit) {
    return '$used / $limit permanente URI’s in gebruik';
  }

  @override
  String get settings_mediaSources_counting => 'Tellen…';

  @override
  String settings_mediaSources_error(String error) {
    return 'Fout: $error';
  }

  @override
  String get settings_mediaSources_loading => 'Laden…';

  @override
  String settings_mediaSources_localFilesCounts(
    int available,
    int unavailable,
  ) {
    return '$available beschikbaar, $unavailable niet beschikbaar';
  }

  @override
  String get settings_mediaSources_photoLibrarySubtitle =>
      'Apple Photos / Google Photos / iCloud';

  @override
  String get settings_mediaSources_reverifyAll =>
      'Alle lokale bestanden opnieuw verifiëren';

  @override
  String settings_mediaSources_reverifyFailed(String error) {
    return 'Opnieuw verifiëren mislukt: $error';
  }

  @override
  String settings_mediaSources_reverifyResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items bijgewerkt',
      one: '$count item bijgewerkt',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_checkAll => 'Alle media controleren';

  @override
  String settings_mediaSources_checkAllResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items bijgewerkt',
      one: '$count item bijgewerkt',
    );
    return '$_temp0';
  }

  @override
  String settings_mediaSources_checkAllBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Geen van de $count items kon worden gecontroleerd. Hun bronnen zijn momenteel niet bereikbaar.',
      one:
          'Het item kon niet worden gecontroleerd. De bron is momenteel niet bereikbaar.',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_title => 'Mediabronnen';

  @override
  String get settings_networkSources_scanDescription =>
      'Controleert elke via URL of manifest geïmporteerde foto opnieuw bij de bijbehorende host. Onbereikbare items worden gemarkeerd zodat ze als ‘ontbrekend’ in je bibliotheek verschijnen en kunnen worden opgeruimd.';

  @override
  String statistics_conditions_entryMethod_semanticLabel(String description) {
    return 'Staafdiagram. Instapmethoden. $description';
  }

  @override
  String statistics_conditions_visibility_semanticLabel(String description) {
    return 'Cirkeldiagram. Zichtverdeling. $description';
  }

  @override
  String statistics_conditions_waterType_semanticLabel(String description) {
    return 'Cirkeldiagram. Verdeling van watertypes. $description';
  }

  @override
  String statistics_progression_divesBySuitThickness_semanticLabel(
    String description,
  ) {
    return 'Staafdiagram. Duiken per pakdikte. $description';
  }

  @override
  String statistics_progression_divesPerYear_countInYear(
    int count,
    String year,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken in $year',
      one: '1 duik in $year',
    );
    return '$_temp0';
  }

  @override
  String statistics_progression_divesPerYear_semanticLabel(String description) {
    return 'Staafdiagram. Duiken per jaar. $description';
  }

  @override
  String get statistics_records_unavailable => 'Records niet beschikbaar';

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
  String get statistics_summary_distributions_title => 'Verdelingen';

  @override
  String get statistics_summary_diveTypes_error =>
      'Kan duiktypegegevens niet laden';

  @override
  String get statistics_summary_diveTypes_unknown => 'Onbekend';

  @override
  String get statistics_summary_divesPerMonth => 'Duiken / maand';

  @override
  String get statistics_summary_divesPerYear => 'Duiken / jaar';

  @override
  String statistics_timePatterns_dayOfWeek_semanticLabel(String description) {
    return 'Staafdiagram. Duiken per dag van de week. $description';
  }

  @override
  String statistics_timePatterns_seasonal_semanticLabel(String description) {
    return 'Staafdiagram. Duiken per maand. $description';
  }

  @override
  String statistics_timePatterns_surfaceInterval_statLabel(
    String label,
    String value,
  ) {
    return 'Oppervlakte-interval $label: $value';
  }

  @override
  String get statistics_timePatterns_timeOfDay_afternoon => 'Middag';

  @override
  String get statistics_timePatterns_timeOfDay_evening => 'Avond';

  @override
  String get statistics_timePatterns_timeOfDay_morning => 'Ochtend';

  @override
  String get statistics_timePatterns_timeOfDay_night => 'Nacht';

  @override
  String statistics_timePatterns_timeOfDay_semanticLabel(String description) {
    return 'Cirkeldiagram. Duiken per tijdstip van de dag. $description';
  }

  @override
  String get columnConfig_displayOptions => 'Weergaveopties';

  @override
  String get columnConfig_noExtraFields =>
      'Geen extra velden ingesteld. Voeg hieronder velden toe.';

  @override
  String get columnConfig_savePresetTitle => 'Voorinstelling opslaan';

  @override
  String get columnConfig_section => 'Sectie';

  @override
  String get columnConfig_showTags => 'Tags tonen';

  @override
  String get columnConfig_showTags_subtitle =>
      'Tagchips tonen op gedetailleerde duikkaarten';

  @override
  String get columnConfig_slot_date => 'Datum / Ondertitel';

  @override
  String get columnConfig_slot_slot1 => 'Slot 1';

  @override
  String get columnConfig_slot_slot2 => 'Slot 2';

  @override
  String get columnConfig_slot_slot3 => 'Slot 3';

  @override
  String get columnConfig_slot_slot4 => 'Slot 4';

  @override
  String get columnConfig_slot_stat1 => 'Statistiek 1';

  @override
  String get columnConfig_slot_stat2 => 'Statistiek 2';

  @override
  String get columnConfig_slot_subtitle => 'Ondertitel';

  @override
  String get columnConfig_slot_title => 'Titel';

  @override
  String get columnConfig_tooltip_columnSettings => 'Kolominstellingen';

  @override
  String get common_action_add => 'Toevoegen';

  @override
  String get common_action_pin => 'Vastmaken';

  @override
  String get common_action_remove => 'Verwijderen';

  @override
  String get common_action_unpin => 'Losmaken';

  @override
  String diveLog_filterChip_dateRange(String end, String start) {
    return '$start - $end';
  }

  @override
  String diveLog_filterChip_equipmentCount(int count) {
    return '$count uitrustingsstukken';
  }

  @override
  String get diveLog_filter_allComputers => 'Alle computers';

  @override
  String get diveLog_filter_noComputersRegistered =>
      'Geen duikcomputers geregistreerd';

  @override
  String diveLog_filter_sectionDepthRangeUnit(String unit) {
    return 'Dieptebereik ($unit)';
  }

  @override
  String get diveLog_filter_sectionDiveComputer => 'Duikcomputer';

  @override
  String diveLog_listPage_semanticsDiveAtSite(int diveNumber, String siteName) {
    return 'Duik $diveNumber bij $siteName';
  }

  @override
  String get enum_listViewMode_compact => 'Compact';

  @override
  String get enum_listViewMode_dense => 'Dicht';

  @override
  String get enum_listViewMode_detailed => 'Gedetailleerd';

  @override
  String get enum_listViewMode_table => 'Tabel';

  @override
  String get enum_profileMetric_ascentRate => 'Opstijgsnelheid';

  @override
  String get enum_profileMetric_cns => 'CNS%';

  @override
  String get enum_profileMetric_otu => 'OTU';

  @override
  String get enum_sortField_bottomTime => 'Bodemtijd';

  @override
  String get enum_sortField_serviceDue => 'Service nodig';

  @override
  String get listViewMode_tooltip => 'Weergavemodus';

  @override
  String marineLife_speciesManage_errorLoading(Object error) {
    return 'Fout bij het laden van soorten: $error';
  }

  @override
  String get settings_appearance_header_cards => 'Kaarten';

  @override
  String get settings_appearance_header_listView => 'Lijstweergave';

  @override
  String get settings_appearance_header_tableMode => 'Tabelmodus';

  @override
  String get settings_appearance_listFields_buddies =>
      'Lijstvelden voor buddies';

  @override
  String get settings_appearance_listFields_certifications =>
      'Lijstvelden voor certificeringen';

  @override
  String get settings_appearance_listFields_courses =>
      'Lijstvelden voor cursussen';

  @override
  String get settings_appearance_listFields_diveCenters =>
      'Lijstvelden voor duikcentra';

  @override
  String get settings_appearance_listFields_dives => 'Lijstvelden voor duiken';

  @override
  String get settings_appearance_listFields_equipment =>
      'Lijstvelden voor uitrusting';

  @override
  String get settings_appearance_listFields_sites =>
      'Lijstvelden voor duikstekken';

  @override
  String get settings_appearance_listFields_subtitle =>
      'Pas de velden aan die in lijstweergaven worden getoond';

  @override
  String get settings_appearance_listFields_trips => 'Lijstvelden voor reizen';

  @override
  String get settings_appearance_listView_buddies => 'Lijstweergave buddies';

  @override
  String get settings_appearance_listView_buddies_subtitle =>
      'Standaardindeling voor de lijst met buddies';

  @override
  String get settings_appearance_listView_certifications =>
      'Lijstweergave certificeringen';

  @override
  String get settings_appearance_listView_certifications_subtitle =>
      'Standaardindeling voor de lijst met certificeringen';

  @override
  String get settings_appearance_listView_courses => 'Lijstweergave cursussen';

  @override
  String get settings_appearance_listView_courses_subtitle =>
      'Standaardindeling voor de lijst met cursussen';

  @override
  String get settings_appearance_listView_diveCenters =>
      'Lijstweergave duikcentra';

  @override
  String get settings_appearance_listView_diveCenters_subtitle =>
      'Standaardindeling voor de lijst met duikcentra';

  @override
  String get settings_appearance_listView_dives => 'Lijstweergave duiken';

  @override
  String get settings_appearance_listView_dives_subtitle =>
      'Standaardindeling voor de lijst met duiken';

  @override
  String get settings_appearance_listView_equipment =>
      'Lijstweergave uitrusting';

  @override
  String get settings_appearance_listView_equipment_subtitle =>
      'Standaardindeling voor de lijst met uitrusting';

  @override
  String get settings_appearance_listView_sites => 'Lijstweergave duikstekken';

  @override
  String get settings_appearance_listView_sites_subtitle =>
      'Standaardindeling voor de lijst met duikstekken';

  @override
  String get settings_appearance_listView_trips => 'Lijstweergave reizen';

  @override
  String get settings_appearance_listView_trips_subtitle =>
      'Standaardindeling voor de lijst met reizen';

  @override
  String get settings_appearance_showDataSourceBadges =>
      'Badges voor gegevensbron tonen';

  @override
  String get settings_appearance_showDataSourceBadges_subtitle =>
      'Bronvermelding tonen bij duikgegevens';

  @override
  String get settings_appearance_title_buddies => 'Uiterlijk van buddies';

  @override
  String get settings_appearance_title_certifications =>
      'Uiterlijk van certificeringen';

  @override
  String get settings_appearance_title_courses => 'Uiterlijk van cursussen';

  @override
  String get settings_appearance_title_diveCenters =>
      'Uiterlijk van duikcentra';

  @override
  String get settings_appearance_title_dives => 'Uiterlijk van duiken';

  @override
  String get settings_appearance_title_equipment => 'Uiterlijk van uitrusting';

  @override
  String get settings_appearance_title_sites => 'Uiterlijk van duikstekken';

  @override
  String get settings_appearance_title_trips => 'Uiterlijk van reizen';

  @override
  String get settings_cloudSync_troubleshoot_tileSubtitle =>
      'Een vastgelopen synchronisatie herstellen of cloudruimte vrijmaken';

  @override
  String get settings_data_header_dataTools => 'Gegevenshulpmiddelen';

  @override
  String get settings_decompression_ascentGasLabel => 'Opstijging plannen met';

  @override
  String get settings_decompression_ascentGas_allCarried =>
      'Alle meegenomen flessen';

  @override
  String get settings_decompression_ascentGas_decoStage =>
      'Deco-/stagefles + hoofdgas';

  @override
  String get settings_decompression_cnsSource => 'CNS-bron';

  @override
  String get settings_decompression_decoStopSource => 'Bron van decostops';

  @override
  String get settings_decompression_header_ascent => 'Opstijgplanning';

  @override
  String get settings_decompression_header_ascent_subtitle =>
      'Naar welke meegenomen flessen de gesimuleerde opstijging (TTS, plafond en stops) op elke diepte mag overschakelen. Alleen gassen die bij de duik zijn vastgelegd, worden meegenomen.';

  @override
  String get settings_decompression_header_dataSources =>
      'Voorkeuren voor gegevensbron';

  @override
  String get settings_decompression_header_dataSources_subtitle =>
      'Bij de instelling Duikcomputer gebruikt de app de gegevens die de duikcomputer meldt, als die beschikbaar zijn. Zijn er geen computergegevens, dan gebruikt de app berekende waarden.';

  @override
  String get settings_decompression_ndlSource => 'NDL-bron';

  @override
  String get settings_decompression_sourceCalculated => 'Berekend';

  @override
  String get settings_decompression_sourceComputer => 'Duikcomputer';

  @override
  String get settings_decompression_ttsSource => 'TTS-bron';

  @override
  String settings_fixDiveTimes_applied(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'uur',
      one: 'uur',
    );
    return '$count $_temp0 met $hours $_temp1 bijgewerkt.';
  }

  @override
  String settings_fixDiveTimes_apply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    return 'Toepassen op $count $_temp0';
  }

  @override
  String get settings_fixDiveTimes_clearRange => 'Datumbereik wissen';

  @override
  String get settings_fixDiveTimes_confirmApply => 'Toepassen';

  @override
  String settings_fixDiveTimes_confirmBody(
    int count,
    String hours,
    int hoursAbs,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'worden',
      one: 'wordt',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken',
      one: 'duik',
    );
    String _temp2 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'uur',
      one: 'uur',
    );
    return 'Hiermee $_temp0 $count $_temp1 met $hours $_temp2 verschoven. Dit kan niet automatisch ongedaan worden gemaakt.';
  }

  @override
  String get settings_fixDiveTimes_confirmTitle => 'Tijdverschuiving toepassen';

  @override
  String get settings_fixDiveTimes_dateRangeFilter => 'Filter op datumbereik';

  @override
  String get settings_fixDiveTimes_deselectAll => 'Alles deselecteren';

  @override
  String get settings_fixDiveTimes_diveFallback => 'Duik';

  @override
  String settings_fixDiveTimes_diveNumber(int number) {
    return 'Duik nr. $number';
  }

  @override
  String get settings_fixDiveTimes_empty => 'Geen duiken gevonden.';

  @override
  String get settings_fixDiveTimes_emptyFiltered =>
      'Geen duiken gevonden in dit datumbereik.';

  @override
  String get settings_fixDiveTimes_enterOffsetHint =>
      'Voer een verschuiving in uren in';

  @override
  String get settings_fixDiveTimes_from => 'Van';

  @override
  String get settings_fixDiveTimes_hourOffset => 'Urenverschuiving';

  @override
  String get settings_fixDiveTimes_hoursField => 'Uren (bijv. +7, -5)';

  @override
  String settings_fixDiveTimes_loadError(String error) {
    return 'Duiken laden mislukt: $error';
  }

  @override
  String get settings_fixDiveTimes_noSelection => 'Geen duiken geselecteerd.';

  @override
  String get settings_fixDiveTimes_offsetHint =>
      'Voer een positief of negatief geheel getal in om de duiktijden te verschuiven.';

  @override
  String settings_fixDiveTimes_preview(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duiken worden',
      one: 'duik wordt',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'uur',
      one: 'uur',
    );
    return 'Voorbeeld: $count $_temp0 met $hours $_temp1 verschoven.';
  }

  @override
  String get settings_fixDiveTimes_selectAll => 'Alles selecteren';

  @override
  String get settings_fixDiveTimes_selectDivesHint =>
      'Selecteer de duiken om toe te passen';

  @override
  String get settings_fixDiveTimes_subtitle =>
      'Tijden van geïmporteerde duiken aanpassen';

  @override
  String get settings_fixDiveTimes_title => 'Duiktijden corrigeren';

  @override
  String get settings_fixDiveTimes_to => 'Tot';

  @override
  String get settings_fixDiveTimes_zeroOffset =>
      'De urenverschuiving is 0, er valt niets te wijzigen.';

  @override
  String get settings_syncDevices_appBar_refreshTooltip => 'Vernieuwen';

  @override
  String get settings_syncDevices_appBar_title => 'Apparaten op deze provider';

  @override
  String get settings_syncDevices_empty =>
      'Geen synchronisatiebestanden op deze provider.';

  @override
  String settings_syncDevices_readError(String error) {
    return 'De provider kon niet worden gelezen.\n$error';
  }

  @override
  String get settings_syncDevices_removal_noBackend =>
      'Er is geen cloudprovider ingesteld';

  @override
  String get settings_syncDevices_removal_unreachable =>
      'De provider was niet bereikbaar. Er is niets verwijderd.';

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
          'Hiermee worden $count bestanden ($size) van $name verwijderd.\n\nDat apparaat maakt nog steeds deel uit van deze synchronisatie. Als het weer online komt, bouwt het zichzelf opnieuw op vanaf de provider in plaats van oude gegevens terug te halen, maar alle wijzigingen die het nog niet heeft gepubliceerd gaan verloren. Je duikgegevens op DIT apparaat worden niet aangetast.',
      one:
          'Hiermee wordt 1 bestand ($size) van $name verwijderd.\n\nDat apparaat maakt nog steeds deel uit van deze synchronisatie. Als het weer online komt, bouwt het zichzelf opnieuw op vanaf de provider in plaats van oude gegevens terug te halen, maar alle wijzigingen die het nog niet heeft gepubliceerd gaan verloren. Je duikgegevens op DIT apparaat worden niet aangetast.',
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
          'Hiermee worden $count bestanden ($size) van $name verwijderd. Het zijn restanten van een bibliotheek waarmee geen enkel apparaat nog synchroniseert. Je duikgegevens worden niet aangetast.',
      one:
          'Hiermee wordt 1 bestand ($size) van $name verwijderd. Het is een restant van een bibliotheek waarmee geen enkel apparaat nog synchroniseert. Je duikgegevens worden niet aangetast.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_removeDialog_title(String name) {
    return 'Bestanden van $name verwijderen?';
  }

  @override
  String settings_syncDevices_removeProgressTitle(String name) {
    return 'Bestanden van $name verwijderen';
  }

  @override
  String get settings_syncDevices_removeTooltip =>
      'Bestanden van dit apparaat verwijderen';

  @override
  String get settings_syncDevices_state_active => 'Synchroniseert normaal';

  @override
  String get settings_syncDevices_state_retired => 'Uit gebruik';

  @override
  String get settings_syncDevices_state_staleEpoch =>
      'Restant van een eerdere bibliotheek, geen enkel apparaat leest dit';

  @override
  String get settings_syncDevices_state_thisDevice => 'Dit apparaat';

  @override
  String get settings_syncDevices_state_unreadable =>
      'Geen leesbaar manifest: een onvoltooide upload, of versleuteld';

  @override
  String settings_syncDevices_summary(
    int deviceCount,
    int fileCount,
    String size,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      deviceCount,
      locale: localeName,
      other: '$deviceCount apparaten',
      one: '1 apparaat',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: '$fileCount bestanden',
      one: '1 bestand',
    );
    return '$_temp0, $_temp1, $size';
  }

  @override
  String settings_syncDevices_summary_removable(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count restanten van vervangen of buiten gebruik gestelde bibliotheken, goed voor $size.',
      one:
          '1 restant van een vervangen of buiten gebruik gestelde bibliotheek, goed voor $size.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_tile_filesSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bestanden',
      one: '1 bestand',
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
      other: '$count bestanden',
      one: '1 bestand',
    );
    return '$_temp0, $size, $when';
  }

  @override
  String settings_syncDevices_unnamedDevice(String shortId) {
    return 'Apparaat $shortId';
  }

  @override
  String get settings_syncMaintenance_keepAppOpen =>
      'Houd de app open totdat dit klaar is. Als je hem nu sluit, blijft de provider gedeeltelijk geleegd achter en moet de volgende synchronisatie opnieuw beginnen.';

  @override
  String get settings_syncMaintenance_phase_clearingOldFiles =>
      'Oude bestanden wissen';

  @override
  String get settings_syncMaintenance_phase_deleting => 'Verwijderen';

  @override
  String get settings_syncMaintenance_phase_publishingLibrary =>
      'Bibliotheek publiceren';

  @override
  String get settings_cloudSync_adopt_progressTitle =>
      'Herstelde bibliotheek overnemen';

  @override
  String get settings_cloudSync_replaceLibrary_progressTitle =>
      'Cloudbibliotheek vervangen';

  @override
  String settings_syncDevices_nameWithId(String name, String shortId) {
    return '$name ($shortId)';
  }

  @override
  String get settings_syncMaintenance_phase_applyingLibrary =>
      'Bibliotheek toepassen';

  @override
  String get settings_syncMaintenance_phase_backingUp =>
      'Back-up van dit apparaat maken';

  @override
  String get settings_syncMaintenance_phase_repairing =>
      'Lokale synchronisatiestatus wissen';

  @override
  String get settings_troubleshootSync_repair_progressTitle =>
      'Synchronisatie herstellen';

  @override
  String get settings_syncMaintenance_phase_working => 'Bezig...';

  @override
  String settings_syncMaintenance_progress_filesOfTotal(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done van $total bestanden',
      one: '$done van 1 bestand',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_removedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bestanden verwijderd',
      one: '1 bestand verwijderd',
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
          '$count bestanden verwijderd, maar $trouble. Probeer het opnieuw als je online bent.',
      one:
          '1 bestand verwijderd, maar $trouble. Probeer het opnieuw als je online bent.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_trouble_failed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count konden niet worden verwijderd',
      one: '1 kon niet worden verwijderd',
    );
    return '$_temp0';
  }

  @override
  String get settings_syncMaintenance_trouble_listIncomplete =>
      'sommige bestanden konden niet worden opgesomd';

  @override
  String settings_syncMaintenance_wipedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bestanden gewist',
      one: '1 bestand gewist',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_wipedFilesPartial(int count, String trouble) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count bestanden gewist, maar $trouble. Probeer het opnieuw als je online bent.',
      one:
          '1 bestand gewist, maar $trouble. Probeer het opnieuw als je online bent.',
    );
    return '$_temp0';
  }

  @override
  String get settings_troubleshootSync_appBar_title =>
      'Synchronisatieproblemen oplossen';

  @override
  String get settings_troubleshootSync_devices_subtitle =>
      'Bekijk elk apparaat dat hier bestanden bewaart, hoeveel ruimte elk gebruikt, en verwijder restanten van bibliotheken waarmee geen enkel apparaat nog synchroniseert. Je duikgegevens worden niet aangetast.';

  @override
  String get settings_troubleshootSync_rebuild_confirm => 'Opnieuw opbouwen';

  @override
  String get settings_troubleshootSync_rebuild_confirmBody =>
      'Hiermee wordt de bibliotheek van dit apparaat de huidige bibliotheek op de provider en wordt deze opnieuw gepubliceerd, zodat andere apparaten vanaf jou synchroniseren. Gebruik dit wanneer een vervanging vanaf een ander apparaat is vastgelopen. Je duikgegevens worden niet aangetast.';

  @override
  String get settings_troubleshootSync_rebuild_confirmTitle =>
      'Provider opnieuw opbouwen vanaf dit apparaat?';

  @override
  String get settings_troubleshootSync_rebuild_doneSnack =>
      'Provider opnieuw opgebouwd vanaf dit apparaat';

  @override
  String get settings_troubleshootSync_rebuild_failedSnack =>
      'Opnieuw opbouwen mislukt';

  @override
  String get settings_troubleshootSync_rebuild_progressTitle =>
      'Provider opnieuw opbouwen';

  @override
  String get settings_troubleshootSync_rebuild_subtitle =>
      'Gebruik dit als de synchronisatie vastloopt terwijl er wordt gewacht op een bibliotheek die een ander apparaat heeft vervangen maar nooit volledig heeft geüpload (dat apparaat is mogelijk offline). Publiceert de bibliotheek van dit apparaat als de huidige.';

  @override
  String get settings_troubleshootSync_rebuild_title =>
      'Provider opnieuw opbouwen vanaf dit apparaat';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmBody =>
      'Hiermee worden alleen de synchronisatiebestanden van dit apparaat van de provider verwijderd. Andere apparaten blijven synchroniseren en je duikgegevens worden niet aangetast.';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmTitle =>
      'Cloudbestanden van dit apparaat verwijderen?';

  @override
  String get settings_troubleshootSync_removeThisDevice_progressTitle =>
      'Cloudbestanden van dit apparaat verwijderen';

  @override
  String get settings_troubleshootSync_removeThisDevice_subtitle =>
      'Maak de ruimte van dit apparaat op de provider vrij. Andere apparaten blijven synchroniseren. Je duikgegevens worden niet aangetast.';

  @override
  String get settings_troubleshootSync_removeThisDevice_title =>
      'Cloudbestanden van dit apparaat verwijderen';

  @override
  String get settings_troubleshootSync_repair_confirm => 'Herstellen';

  @override
  String get settings_troubleshootSync_repair_confirmBody =>
      'Hiermee wordt alle lokale synchronisatiestatus gewist en krijgt dit apparaat een nieuwe synchronisatie-identiteit; bij de volgende synchronisatie maakt het opnieuw verbinding. Je duikgegevens zijn veilig en worden niet verwijderd.';

  @override
  String get settings_troubleshootSync_repair_confirmTitle =>
      'Synchronisatie herstellen?';

  @override
  String get settings_troubleshootSync_repair_doneSnack =>
      'Synchronisatie hersteld';

  @override
  String get settings_troubleshootSync_repair_subtitle =>
      'Herstel een vastgelopen synchronisatie. Wist de synchronisatiestatus van dit apparaat en geeft het een nieuwe synchronisatie-identiteit; bij de volgende synchronisatie maakt het opnieuw verbinding. Je duikgegevens worden niet aangetast.';

  @override
  String get settings_troubleshootSync_repair_title =>
      'Synchronisatie herstellen';

  @override
  String get settings_troubleshootSync_wipeAll_confirm => 'Alles wissen';

  @override
  String settings_troubleshootSync_wipeAll_confirmBody(String word) {
    return 'Hiermee worden de synchronisatiegegevens van ELK apparaat van deze provider verwijderd, inclusief de bibliotheekmarkeringen. Elk apparaat moet de synchronisatie helemaal opnieuw opzetten. Je duikgegevens worden niet aangetast.\n\nTyp $word om te bevestigen.';
  }

  @override
  String get settings_troubleshootSync_wipeAll_confirmTitle =>
      'Alle synchronisatiegegevens wissen?';

  @override
  String get settings_troubleshootSync_wipeAll_progressTitle =>
      'Synchronisatiegegevens wissen';

  @override
  String get settings_troubleshootSync_wipeAll_subtitle =>
      'Verwijder de synchronisatiegegevens van elk apparaat van deze provider, inclusief de bibliotheekmarkeringen. Elk apparaat zet de synchronisatie helemaal opnieuw op. Je duikgegevens worden niet aangetast.';

  @override
  String get settings_troubleshootSync_wipeAll_title =>
      'Alle synchronisatiegegevens op deze provider wissen';

  @override
  String get tableMode_tooltip_toggleDetailPane =>
      'Detailpaneel tonen of verbergen';

  @override
  String get tableMode_tooltip_toggleProfilePanel =>
      'Profielpaneel tonen of verbergen';

  @override
  String get maps_regionDownload_title => 'Regio downloaden';

  @override
  String get maps_regionDownload_nameRequired =>
      'Voer een naam in voor deze regio';

  @override
  String get maps_regionDownload_nameLabel => 'Regionaam';

  @override
  String get maps_regionDownload_nameHint => 'bijv. Cozumel, Mexico';

  @override
  String get maps_regionDownload_zoomLevels => 'Zoomniveaus';

  @override
  String get maps_regionDownload_zoomHint =>
      'Hogere zoom = meer detail, grotere download';

  @override
  String maps_regionDownload_minZoom(int zoom) {
    return 'Min: $zoom';
  }

  @override
  String maps_regionDownload_minZoomSemantics(int zoom) {
    return 'Minimale zoom: $zoom';
  }

  @override
  String maps_regionDownload_maxZoom(int zoom) {
    return 'Max: $zoom';
  }

  @override
  String maps_regionDownload_maxZoomSemantics(int zoom) {
    return 'Maximale zoom: $zoom';
  }

  @override
  String get maps_regionDownload_estimatingSemantics =>
      'Downloadgrootte wordt geschat';

  @override
  String maps_regionDownload_estimateSemantics(int count, Object size) {
    return 'Geschatte download: $count tegels, $size';
  }

  @override
  String get maps_regionDownload_estimateUnavailableSemantics =>
      'Kan de downloadgrootte niet schatten';

  @override
  String get maps_regionDownload_estimating => 'Schatten...';

  @override
  String maps_regionDownload_tileCount(int count) {
    return '~$count tegels';
  }

  @override
  String get maps_regionDownload_estimateUnavailable => 'Kan niet schatten';

  @override
  String get maps_regionDownload_largeWarningSemantics =>
      'Waarschuwing: grote download. Verlaag de zoomniveaus of kies een kleinere regio.';

  @override
  String get maps_regionDownload_largeWarning =>
      'Grote download. Verlaag de zoomniveaus of kies een kleinere regio.';

  @override
  String get maps_regionDownload_downloadButton => 'Downloaden';

  @override
  String get diveLog_map_title => 'Duikactiviteit';

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
      'Fotominiatuur. Tik om volledig scherm te bekijken';

  @override
  String get trips_gallery_thumbnail_video =>
      'Videominiatuur. Tik om volledig scherm te bekijken';

  @override
  String get trips_gallery_thumbnail_photoMissing =>
      'Fotominiatuur, ontbreekt op het apparaat. Tik om volledig scherm te bekijken';

  @override
  String get trips_gallery_thumbnail_videoMissing =>
      'Videominiatuur, ontbreekt op het apparaat. Tik om volledig scherm te bekijken';

  @override
  String get trips_photos_thumbnail_photo =>
      'Fotominiatuur. Tik om de galerij te openen';

  @override
  String get trips_photos_thumbnail_video =>
      'Videominiatuur. Tik om de galerij te openen';

  @override
  String trips_picker_suggestedSemantics(Object name) {
    return 'Voorgestelde reis: $name. Tik om te gebruiken';
  }

  @override
  String trips_picker_tileSemantics(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, $startDate tot $endDate';
  }

  @override
  String trips_picker_tileSemanticsSelected(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, $startDate tot $endDate, geselecteerd';
  }

  @override
  String get divePlanner_quickPlan_subtitle =>
      'Maak een eenvoudig rechthoekig duikprofiel';

  @override
  String get divePlanner_quickPlan_depthLabel => 'Diepte:';

  @override
  String divePlanner_quickPlan_depthSemantics(Object depth) {
    return 'Diepte: $depth';
  }

  @override
  String get divePlanner_quickPlan_timeLabel => 'Tijd:';

  @override
  String divePlanner_quickPlan_bottomTimeSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Bodemtijd: $minutes minuten',
      one: 'Bodemtijd: 1 minuut',
    );
    return '$_temp0';
  }

  @override
  String divePlanner_quickPlan_minutes(int minutes) {
    return '$minutes min';
  }

  @override
  String divePlanner_quickPlan_previewSemantics(Object depth, int minutes) {
    return 'Planvoorbeeld: afdaling naar $depth, bodemtijd $minutes minuten, opstijging met veiligheidsstop';
  }

  @override
  String get divePlanner_quickPlan_previewTitle => 'Planvoorbeeld:';

  @override
  String divePlanner_quickPlan_previewDescent(Object depth) {
    return 'Afdaling naar $depth';
  }

  @override
  String divePlanner_quickPlan_previewBottomTime(int minutes) {
    return 'Bodemtijd: $minutes min';
  }

  @override
  String get divePlanner_quickPlan_previewAscent =>
      'Opstijging met veiligheidsstop';

  @override
  String get divePlanner_quickPlan_create => 'Maken';

  @override
  String divePlanner_semantics_sacRate(Object value, Object volumeSymbol) {
    return 'RMV: $value $volumeSymbol per minuut';
  }

  @override
  String divePlanner_semantics_reservePressure(Object pressureSymbol) {
    return 'Reservedruk in $pressureSymbol';
  }

  @override
  String divePlanner_semantics_altitudeGroup(Object group) {
    return 'Hoogtegroep: $group';
  }

  @override
  String diveSites_import_detail_maxDepth(Object depth) {
    return 'Max $depth';
  }

  @override
  String get autoUpdate_banner_download => 'Downloaden';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Synchroniseren via Apple iCloud';

  @override
  String get settings_debugLog_search_hint => 'Logs doorzoeken...';

  @override
  String get settings_debugLog_appBar_title => 'Debuglogs';

  @override
  String get settings_debugLog_disableDebugMode => 'Debugmodus uitschakelen';

  @override
  String get settings_debugLog_clearLogs => 'Logs wissen';

  @override
  String get settings_debugLog_empty =>
      'Geen logregels komen overeen met de huidige filters';

  @override
  String settings_debugLog_loadError(Object error) {
    return 'Fout bij laden van logs: $error';
  }

  @override
  String get settings_debugLog_copiedSnack =>
      'Gefilterde logs gekopieerd naar klembord';

  @override
  String settings_debugLog_savedSnack(String path) {
    return 'Logs opgeslagen in $path';
  }

  @override
  String get common_action_copy => 'Kopiëren';

  @override
  String get settings_appearance_customGradient_title =>
      'Aangepast kleurverloop';

  @override
  String get settings_appearance_customGradient_start => 'Begin';

  @override
  String get settings_appearance_customGradient_end => 'Einde';

  @override
  String get settings_appearance_customGradient_hue => 'Kleurtoon';

  @override
  String get settings_appearance_customGradient_saturation => 'Verzadiging';

  @override
  String get settings_appearance_customGradient_brightness => 'Helderheid';

  @override
  String get settings_appearance_customGradient_preview => 'Voorbeeld';

  @override
  String get common_action_apply => 'Toepassen';

  @override
  String settings_cloudSync_message_loadStateFailed(Object error) {
    return 'Kan synchronisatiestatus niet laden: $error';
  }

  @override
  String get settings_cloudSync_message_noProviderConfigured =>
      'Geen cloudprovider ingesteld';

  @override
  String get settings_cloudSync_message_adopting =>
      'Herstelde bibliotheek wordt overgenomen...';

  @override
  String get settings_cloudSync_message_adoptFailed =>
      'Kan de herstelde bibliotheek niet overnemen';

  @override
  String get settings_cloudSync_message_firstSyncNeedsConfirm =>
      'De eerste synchronisatie moet worden bevestigd. Tik op ‘Nu synchroniseren’ om te controleren.';

  @override
  String get settings_cloudSync_message_startingSync =>
      'Synchronisatie starten...';

  @override
  String get settings_cloudSync_message_replacePaused =>
      'Synchronisatie gepauzeerd: de bibliotheek is vervangen vanuit een back-up. Tik op ‘Nu synchroniseren’ om te controleren.';

  @override
  String get settings_cloudSync_message_encryptedPaused =>
      'Synchronisatie gepauzeerd: deze bibliotheek is versleuteld. Voer de wachtwoordzin in om door te gaan.';

  @override
  String get settings_cloudSync_message_completedWithConflicts =>
      'Synchronisatie voltooid met conflicten';

  @override
  String get settings_cloudSync_message_completedSuccessfully =>
      'Synchronisatie succesvol voltooid';

  @override
  String get settings_cloudSync_message_syncFailed => 'Synchronisatie mislukt';

  @override
  String get settings_cloudSync_message_phaseDefault => 'synchronisatie';

  @override
  String settings_cloudSync_message_syncErrorDuring(
    String phase,
    Object error,
  ) {
    return 'Synchronisatiefout tijdens $phase: $error';
  }

  @override
  String get settings_section_debug_title => 'Debug';

  @override
  String get settings_section_debug_subtitle => 'Logs & diagnostiek';

  @override
  String get settings_debugLog_minSeverityLabel => 'Min. ernst:';

  @override
  String get settings_debugLog_shareSubject => 'Submersion-debuglogs';

  @override
  String get settings_debugLog_saveDialogTitle => 'Debuglogs opslaan';

  @override
  String get universalImport_preset_saveTitle => 'Opslaan als voorinstelling';

  @override
  String get universalImport_preset_nameLabel => 'Naam voorinstelling';

  @override
  String get universalImport_preset_nameHint => 'bijv. Mijn duiklogboek-CSV';

  @override
  String get universalImport_preset_nameRequired => 'Naam is verplicht';

  @override
  String get universalImport_preset_sourceAppLabel => 'Bronapplicatie';

  @override
  String get universalImport_preset_sourceAppNone => 'Geen';

  @override
  String get universalImport_preset_entityTypesLabel => 'Entiteitstypen';

  @override
  String get universalImport_preset_matchThresholdLabel =>
      'Overeenkomstdrempel';

  @override
  String get universalImport_preset_matchThresholdHelp =>
      'Hoe nauw CSV-kopteksten moeten overeenkomen voor automatische detectie';

  @override
  String universalImport_preset_signatureHeaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count handtekeningkopteksten uit het huidige bestand',
      one: '1 handtekeningkoptekst uit het huidige bestand',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_preset_selectTitle => 'Voorinstelling selecteren';

  @override
  String universalImport_preset_loadFailed(String error) {
    return 'Kan voorinstellingen niet laden: $error';
  }

  @override
  String get universalImport_preset_sectionSaved =>
      'Opgeslagen voorinstellingen';

  @override
  String get universalImport_preset_sectionBuiltIn =>
      'Ingebouwde voorinstellingen';

  @override
  String get universalImport_preset_deleteTitle => 'Voorinstelling verwijderen';

  @override
  String universalImport_preset_deleteConfirm(String name) {
    return '‘$name’ verwijderen? Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String universalImport_preset_headersMatched(
    int matched,
    int total,
    int percent,
  ) {
    return '$matched/$total kopteksten komen overeen ($percent%)';
  }

  @override
  String get universalImport_preset_noSignatureHeaders =>
      'Geen handtekeningkopteksten';

  @override
  String get universalImport_preset_deleteTooltip =>
      'Voorinstelling verwijderen';

  @override
  String get universalImport_preset_presetsButton => 'Voorinstellingen';

  @override
  String universalImport_preset_savedSnackbar(String name) {
    return 'Voorinstelling ‘$name’ opgeslagen';
  }

  @override
  String get universalImport_step_done => 'Gereed';

  @override
  String get universalImport_cancel_inProgressTitle => 'Bezig met annuleren';

  @override
  String get universalImport_cancel_inProgressBody =>
      'De huidige duik wordt afgerond voordat er wordt gestopt. Reeds geïmporteerde duiken blijven behouden.';

  @override
  String get universalImport_cancel_confirmTitle => 'Import annuleren?';

  @override
  String get universalImport_cancel_confirmBody =>
      'Stop nadat de huidige duik is afgerond. Reeds geïmporteerde duiken blijven behouden.';

  @override
  String get universalImport_cancel_keepImporting => 'Doorgaan met importeren';

  @override
  String get universalImport_cancel_confirmAction => 'Import annuleren';

  @override
  String get universalImport_cancel_discardSelections =>
      'Selecties verwerpen en annuleren?';

  @override
  String get universalImport_action_importSelected => 'Selectie importeren';

  @override
  String get universalImport_action_next => 'Volgende';

  @override
  String get common_action_yes => 'Ja';

  @override
  String get common_action_no => 'Nee';

  @override
  String universalImport_counts_new(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nieuw',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_merging(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samenvoegen',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_replacing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vervangen',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_skipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count overgeslagen',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_counts_nothingSelected => 'Niets geselecteerd';

  @override
  String get universalImport_section_potentialDuplicates =>
      'Potentiële duplicaten';

  @override
  String get universalImport_section_possibleDuplicates =>
      'Mogelijke duplicaten';

  @override
  String universalImport_count_duplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicaten',
      one: '1 duplicaat',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_entityAction_importBadge => 'IMPORTEREN';

  @override
  String get universalImport_entityAction_skipBadge => 'OVERSLAAN';

  @override
  String get universalImport_compare_existing => 'Bestaand';

  @override
  String get universalImport_compare_incoming => 'Inkomend';

  @override
  String get universalImport_label_skipped => 'Overgeslagen';

  @override
  String get universalImport_action_viewDives => 'Duiken bekijken';

  @override
  String get diveImport_healthkit_accessGranted => 'HealthKit-toegang verleend';

  @override
  String get diveImport_healthkit_accessGrantedBody =>
      'Je kunt doorgaan naar de volgende stap.';

  @override
  String get diveImport_healthkit_requesting => 'Aanvragen...';

  @override
  String get diveImport_healthkit_selectDateRange => 'Datumbereik selecteren';

  @override
  String get diveImport_healthkit_selectDateRangeBody =>
      'Kies het datumbereik om in Apple Health naar duiken te zoeken.';

  @override
  String get diveImport_healthkit_fetchingDives =>
      'Duiken ophalen uit Apple Health...';

  @override
  String get diveImport_healthkit_fetchFailed => 'Ophalen mislukt';

  @override
  String diveImport_healthkit_fetchFailedBody(String error) {
    return 'Kan duiken niet ophalen: $error';
  }

  @override
  String diveImport_healthkit_foundDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duiken gevonden',
      one: '1 duik gevonden',
    );
    return '$_temp0';
  }

  @override
  String get diveImport_healthkit_proceedingToReview =>
      'Doorgaan naar controleren...';

  @override
  String get importWizard_dc_knownComputer => 'Bekende computer';

  @override
  String importWizard_dc_knownComputerBody(String name) {
    return 'Opgeslagen als ‘$name’. Alleen nieuwe duiken worden gedownload.';
  }

  @override
  String get importWizard_dc_noNewDives =>
      'Geen nieuwe duiken om te downloaden';

  @override
  String get importWizard_dc_noNewDivesBody =>
      'Alle duiken van deze computer zijn al geïmporteerd.';

  @override
  String get universalImport_compare_noDiveData =>
      'Duikgegevens niet beschikbaar voor vergelijking.';

  @override
  String get universalImport_entityAction_consolidateBadge => 'CONSOLIDEREN';

  @override
  String get diveCenters_import_quickSearch_egypt => 'Egypte';

  @override
  String get diveCenters_import_quickSearch_mexico => 'Mexico';

  @override
  String get accessibility_shortcut_switchDiver => 'Duiker wisselen';

  @override
  String get lock_recoveryCode_title => 'Herstelcode gebruiken';

  @override
  String get lock_recoveryCode_body =>
      'Voer de herstelcode van 8 woorden in die je hebt opgeslagen toen je het app-wachtwoord instelde.';

  @override
  String get lock_recoveryCode_error => 'Onjuiste herstelcode.';

  @override
  String get lock_forcedReset_title => 'Stel een nieuw wachtwoord in';

  @override
  String get lock_forcedReset_body =>
      'Je hebt ontgrendeld met je herstelcode, dus je oude wachtwoord wordt niet meer vertrouwd. Kies nu een nieuw wachtwoord.';

  @override
  String get lock_forcedReset_submit => 'Wachtwoord instellen';

  @override
  String get lock_forcedReset_error =>
      'Kan het nieuwe wachtwoord niet instellen. Probeer opnieuw.';

  @override
  String get lock_sidecarRepair_title => 'Beveiligingssleutelbestand repareren';

  @override
  String get lock_sidecarRepair_body =>
      'Je beveiligingssleutelbestand ontbrak en de sleutelhanger van dit apparaat bevat de sleutel nog. Bevestig je wachtwoord om een nieuw sleutelbestand te schrijven. Let op: het wachtwoord dat je hier invoert wordt vanaf nu het app-wachtwoord, en je ontvangt een nieuwe herstelcode.';

  @override
  String get lock_sidecarRepair_submit => 'Repareren';

  @override
  String get lock_sidecarRepair_error => 'Reparatie mislukt. Probeer opnieuw.';

  @override
  String get lock_newRecoveryCode_title => 'Je nieuwe herstelcode';

  @override
  String get lock_startFresh_title => 'Een andere database openen';

  @override
  String lock_startFresh_body(Object token) {
    return 'Je huidige database blijft op de schijf staan, hernoemd met het achtervoegsel .locked; er wordt niets verwijderd. Je kunt hem later terughalen met je wachtwoord of door contact op te nemen met de ondersteuning. Cloudsynchronisatie wordt uitgeschakeld zodat de nieuwe database niet vermengd kan raken met de oude.\n\nDe app start met een nieuwe, lege database. Je kunt een back-up terugzetten in de configuratiewizard.\n\nTyp $token om te bevestigen.';
  }

  @override
  String get lock_startFresh_confirm => 'Opzijzetten en opnieuw beginnen';

  @override
  String get lock_biometric_reason => 'Ontgrendel je duiklogboek';

  @override
  String startup_migrating_progress(Object currentStep, Object totalSteps) {
    return 'Database upgraden... stap $currentStep van $totalSteps';
  }

  @override
  String get startup_error_title => 'Submersion kon niet starten';

  @override
  String get startup_error_body =>
      'Er ging iets mis voordat je duiklogboek helemaal geopend was. Je gegevens staan nog op de schijf en een herinstallatie is niet nodig. Probeer de app opnieuw te starten; neem contact op met de ondersteuning als dit blijft gebeuren.';

  @override
  String get startup_engineUnavailable_title =>
      'Deze build kan geen database openen';

  @override
  String get startup_engineUnavailable_body =>
      'In deze build ontbreekt de databasemotor van Submersion, dus je duiklogboek is nooit geopend. Er is niets op de schijf veranderd en er staan geen gegevens op het spel.';

  @override
  String get startup_engineUnavailable_guidance =>
      'Opnieuw installeren of een back-up terugzetten helpt hier niet. Installeer een werkende build van Submersion en meld dit alsjeblieft: het is een fout in het app-pakket, niet in je gegevens.';

  @override
  String get startup_migrationFailed_title => 'Database-upgrade mislukt';

  @override
  String get startup_migrationFailed_body =>
      'Je duiklogboek kon niet worden bijgewerkt naar het formaat dat deze versie nodig heeft. Voordat de upgrade begon is een veiligheidskopie gemaakt, dus er is niets verloren.';

  @override
  String get startup_dataUnreadable_title =>
      'Je duiklogboek kon niet worden gelezen';

  @override
  String get startup_dataUnreadable_body =>
      'Het databasebestand is er wel, maar Submersion kan het niet lezen. Meestal betekent dit dat het bestand beschadigd is. Een back-up terugzetten is de snelste weg terug.';

  @override
  String get startup_databaseBusy_title => 'Je duiklogboek was bezet';

  @override
  String get startup_databaseBusy_body =>
      'Iets anders gebruikte het databasebestand nog, dus Submersion is gestopt in plaats van ernaar te schrijven. Er is niets gewijzigd en niets beschadigd. Sluit Submersion volledig af en open het opnieuw.';

  @override
  String get startup_failure_technicalDetails => 'Technische details';

  @override
  String get startup_failure_backupAvailable_title =>
      'Er is een back-up beschikbaar';

  @override
  String startup_failure_backupAvailable_taken(Object timestamp) {
    return 'Gemaakt op $timestamp';
  }

  @override
  String startup_failure_backupAvailable_preMigration(
    Object fromVersion,
    Object toVersion,
  ) {
    return 'Veiligheidskopie gemaakt vóór de upgrade van schema v$fromVersion naar v$toVersion.';
  }

  @override
  String get startup_failure_restoreAction => 'Deze back-up terugzetten';

  @override
  String get startup_failure_restoring => 'Je duiklogboek wordt teruggezet...';

  @override
  String get startup_failure_restoreFailed =>
      'De back-up kon niet worden teruggezet. Je duiklogboek is precies gelaten zoals het was.';

  @override
  String get startup_failure_backupsFolder => 'Je back-ups staan in:';

  @override
  String get startup_failure_showBackupsFolder => 'Back-upmap tonen';

  @override
  String get startup_failure_downgrade_title => 'Terug naar de vorige versie';

  @override
  String get startup_failure_downgrade_body =>
      'Als de upgrade blijft mislukken, installeer dan de versie van Submersion die je eerder gebruikte en zet de veiligheidskopie vanuit die versie terug. Hier terugzetten zou alleen dezelfde upgrade opnieuw uitvoeren. Submersion zet zichzelf nooit terug naar een oudere versie: je automatisch naar oudere builds verplaatsen zou je stilzwijgend op versies met bekende problemen houden.';

  @override
  String get startup_failure_downgrade_action => 'Vorige versies bekijken';

  @override
  String get startup_recovering_title => 'Database herstellen...';

  @override
  String get startup_recovering_body =>
      'De onderbroken transactie wordt teruggedraaid. Dit duurt meestal een paar seconden.';

  @override
  String get startup_recoveryFailed_title => 'Herstel is niet voltooid';

  @override
  String get startup_recoveryFailed_body =>
      'De database kon niet automatisch worden teruggedraaid. Je gegevens staan nog op de schijf; neem contact op met de ondersteuning voordat je opnieuw installeert, zodat we je kunnen helpen ze terug te halen.';

  @override
  String get startup_recoveryRequired_title => 'Database moet worden hersteld';

  @override
  String get startup_recoveryRequired_body =>
      'Een eerdere sessie is onderbroken tijdens het schrijven naar de database. Je gegevens staan nog op de schijf; we hoeven alleen het terugdraaien van de geannuleerde wijziging af te maken voordat de app kan worden geopend.';

  @override
  String startup_recovery_sqliteCode(Object code) {
    return 'SQLite-code $code';
  }

  @override
  String get startup_recovery_action => 'Database herstellen';

  @override
  String get startup_recovery_closeWithoutRecovering =>
      'Sluiten zonder herstellen';

  @override
  String get common_action_tryAgain => 'Probeer opnieuw';

  @override
  String get lock_screen_title => 'Submersion is vergrendeld';

  @override
  String get lock_screen_forgotPassword => 'Wachtwoord vergeten?';

  @override
  String get lock_incorrectPassword => 'Onjuist wachtwoord. Probeer opnieuw.';

  @override
  String get startup_backup_semanticsLabel => 'Back-up maken';

  @override
  String get startup_backup_title => 'Back-up van je gegevens maken';

  @override
  String get startup_backup_body =>
      'We slaan een kopie van je duiklogboek op voordat we je database bijwerken.';

  @override
  String get startup_backupFailed_title =>
      'Kan geen back-up van je gegevens maken';

  @override
  String get startup_backupFailed_body =>
      'Je duiklogboek is niet gewijzigd: we hebben het niet bijgewerkt. Maak ruimte vrij (of los het probleem op) en probeer opnieuw.';

  @override
  String get startup_backupFailed_quit => 'Afsluiten';

  @override
  String get startup_backupFailed_technicalDetails => 'Technische details';

  @override
  String get common_action_retry => 'Opnieuw proberen';

  @override
  String get startup_versionMismatch_title => 'Update vereist';

  @override
  String startup_versionMismatch_body(
    Object databaseVersion,
    Object appVersion,
  ) {
    return 'Je duikgegevens zijn opgeslagen door een nieuwere versie van Submersion (schema v$databaseVersion). Deze versie ondersteunt schema’s alleen tot v$appVersion.';
  }

  @override
  String get startup_versionMismatch_instructions =>
      'Werk Submersion bij naar de nieuwste versie. Je gegevens zijn veilig en zijn niet gewijzigd. Als er vóór de upgrade een back-up is gemaakt, staat die in je map Backups en kan die na het bijwerken worden teruggezet.';

  @override
  String get startup_versionMismatch_storeInstructions =>
      'Deze app is geïnstalleerd vanuit een appstore en is ouder dan de versie die uw gegevens heeft gemaakt. Uw gegevens zijn veilig en niet gewijzigd. Werk Submersion bij zodra de nieuwe versie in de store verschijnt en open de app daarna opnieuw.';

  @override
  String get startup_versionMismatch_download => 'Nieuwste versie downloaden';

  @override
  String get startup_versionMismatch_manualLink =>
      'Als dat geen browser opent, ga naar:';

  @override
  String get universalImport_compare_downloaded => 'Gedownload';

  @override
  String get universalImport_compare_errorLoading =>
      'Fout bij het laden van duikgegevens';

  @override
  String get universalImport_compare_diveNotFound =>
      'Bestaande duik niet gevonden';

  @override
  String universalImport_compare_sameFields(Object fields) {
    return 'Gelijk: $fields';
  }

  @override
  String get universalImport_compare_differences => 'VERSCHILLEN';

  @override
  String get universalImport_compare_notRecorded => 'niet vastgelegd';

  @override
  String universalImport_compare_serial(Object serial) {
    return 'Serienr.: $serial';
  }

  @override
  String get universalImport_compare_skipSubtitle => 'Deze download verwerpen';

  @override
  String get universalImport_compare_importAsNewSubtitle =>
      'Opslaan als aparte duik';

  @override
  String get universalImport_compare_consolidateSubtitle =>
      'Toevoegen als 2e computermeting';

  @override
  String get diveLog_tooltip_ndlOverMax => '>60 min';

  @override
  String diveLog_tooltip_interpolated(String value) {
    return '$value (geïnterpoleerd)';
  }

  @override
  String get enum_profileMetric_ascentRate_short => 'Snelheid';

  @override
  String get enum_profileMetric_cns_short => 'CNS';

  @override
  String get enum_profileMetric_otu_short => 'OTU';

  @override
  String get diveLog_profileEditor_rangeOperations => 'Bereikbewerkingen';

  @override
  String get diveLog_profileEditor_selectRangeHint =>
      'Selecteer een bereik op de grafiek om bewerkingen in te schakelen';

  @override
  String get diveLog_profileEditor_depthPlusOneMeter => 'Diepte +1 m';

  @override
  String get diveLog_profileEditor_depthMinusOneMeter => 'Diepte -1 m';

  @override
  String get diveLog_profileEditor_timePlusFiveSeconds => 'Tijd +5 s';

  @override
  String get diveLog_profileEditor_timeMinusFiveSeconds => 'Tijd -5 s';

  @override
  String get diveLog_profileEditor_smoothing => 'Afvlakking';

  @override
  String get diveLog_profileEditor_smoothLight => 'Licht';

  @override
  String get diveLog_profileEditor_smoothMedium => 'Gemiddeld';

  @override
  String get diveLog_profileEditor_smoothHeavy => 'Zwaar';

  @override
  String get diveLog_profileEditor_applyToAll => 'Op alles toepassen';

  @override
  String get diveLog_profileEditor_applyToSelection => 'Op selectie toepassen';

  @override
  String get diveLog_profileEditor_outlierDetection => 'Uitschieterdetectie';

  @override
  String get diveLog_profileEditor_detect => 'Detecteren';

  @override
  String get diveLog_profileEditor_removeAll => 'Alles verwijderen';

  @override
  String diveLog_profileEditor_outliersDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mogelijke uitschieters gedetecteerd',
      one: '$count mogelijke uitschieter gedetecteerd',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_profileEditor_manualDrawing => 'Handmatig tekenen';

  @override
  String get diveLog_profileEditor_drawHint =>
      'Tik op de grafiek om routepunten te plaatsen';

  @override
  String get diveLog_profileEditor_clearWaypoints => 'Wissen';

  @override
  String get diveLog_profileEditor_generateProfile => 'Profiel genereren';

  @override
  String get diveLog_profileEditor_trimMode => 'Bijsnijmodus';

  @override
  String get diveLog_profileEditor_trimHint =>
      'Uiteinden van het profiel bijsnijden';

  @override
  String get diveLog_profileEditor_trimEnd => 'Einde bijsnijden';

  @override
  String get diveLog_profileEditor_mode_smooth => 'Afvlakken';

  @override
  String get diveLog_profileEditor_title => 'Profiel bewerken';

  @override
  String get diveLog_profileEditor_discardBody =>
      'Je hebt niet-opgeslagen wijzigingen aan dit duikprofiel. Weet je zeker dat je deze wilt verwerpen?';

  @override
  String get diveLog_profileEditor_saveTitle => 'Profiel opslaan?';

  @override
  String get diveLog_profileEditor_saveBody =>
      'Hiermee wordt het bewerkte profiel opgeslagen als het primaire profiel voor deze duik. Het originele profiel blijft bewaard en kan later worden teruggezet.';

  @override
  String diveLog_profileEditor_saveFailed(String error) {
    return 'Opslaan van profiel mislukt: $error';
  }

  @override
  String diveLog_profileEditor_errorLoadingDive(String error) {
    return 'Fout bij het laden van de duik: $error';
  }

  @override
  String get diveLog_profileEditor_noProfileData =>
      'Geen profielgegevens beschikbaar';

  @override
  String get diveLog_profileEditor_undo => 'Ongedaan maken';

  @override
  String get diveLog_profileEditor_mode_select => 'Selecteren';

  @override
  String get diveLog_profileEditor_mode_outlier => 'Uitschieter';

  @override
  String get diveLog_profileEditor_mode_draw => 'Tekenen';

  @override
  String get diveLog_profileEditor_mode_trim => 'Bijsnijden';

  @override
  String diveLog_sources_sectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Databronnen',
      one: 'Databron',
      zero: 'Databron',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_badge_manual => 'Handmatig';

  @override
  String get diveLog_sources_badge_viewing => 'Wordt bekeken';

  @override
  String get diveLog_sources_badge_secondary => 'Secundair';

  @override
  String diveLog_sources_created(String date) {
    return 'Aangemaakt op $date';
  }

  @override
  String get diveLog_sources_detail_serial => 'Serienummer';

  @override
  String get diveLog_sources_detail_format => 'Formaat';

  @override
  String get diveLog_sources_detail_imported => 'Geïmporteerd';

  @override
  String diveLog_detail_semantics_viewDiveComputer(String name) {
    return 'Duikcomputer $name bekijken';
  }

  @override
  String diveLog_detail_semantics_viewTrip(String name) {
    return 'Reis $name bekijken';
  }

  @override
  String diveLog_detail_semantics_viewDiveCenter(String name) {
    return 'Duikcentrum $name bekijken';
  }

  @override
  String diveLog_detail_semantics_viewSpecies(String name) {
    return 'Soort $name bekijken';
  }

  @override
  String diveLog_detail_semantics_viewCourse(String name) {
    return 'Cursus $name bekijken';
  }

  @override
  String diveLog_detail_serialNumber(String serial) {
    return 'Serienr. $serial';
  }

  @override
  String diveLog_detail_errorLoadingSignature(String error) {
    return 'Fout bij het laden van de handtekening: $error';
  }

  @override
  String get diveLog_profilePanel_selectDive =>
      'Selecteer een duik om het profiel te bekijken';

  @override
  String get diveLog_profilePanel_noProfileData =>
      'Geen profielgegevens voor deze duik';

  @override
  String get settings_export_progress_divesCsv =>
      'Duiken exporteren naar CSV...';

  @override
  String get settings_export_progress_sitesCsv =>
      'Duikstekken exporteren naar CSV...';

  @override
  String get settings_export_progress_equipmentCsv =>
      'Uitrusting exporteren naar CSV...';

  @override
  String get settings_export_progress_pdf => 'PDF-logboek genereren...';

  @override
  String get settings_export_progress_loadingSignatures =>
      'Handtekeningen laden...';

  @override
  String get settings_export_progress_loadingCertifications =>
      'Certificeringen laden...';

  @override
  String get settings_export_progress_loadingFonts => 'Lettertypen laden...';

  @override
  String settings_export_progress_templatePdf(String template) {
    return '$template-PDF genereren...';
  }

  @override
  String get settings_export_progress_uddf => 'UDDF-bestand genereren...';

  @override
  String get settings_export_progress_collectingData =>
      'Alle gegevens verzamelen...';

  @override
  String get settings_export_progress_excel => 'Excel-bestand genereren...';

  @override
  String get settings_export_progress_buildingExcel =>
      'Excel-werkmap opbouwen...';

  @override
  String get settings_export_progress_kml => 'KML-bestand genereren...';

  @override
  String get settings_export_progress_buildingKml => 'KML-bestand opbouwen...';

  @override
  String get settings_export_progress_preparingExcel =>
      'Excel-bestand voorbereiden...';

  @override
  String get settings_export_progress_preparingKml =>
      'KML-bestand voorbereiden...';

  @override
  String get settings_export_progress_chooseLocation =>
      'Kies een opslaglocatie...';

  @override
  String get settings_export_progress_preparingDivesCsv =>
      'Duiken-CSV voorbereiden...';

  @override
  String get settings_export_progress_preparingSitesCsv =>
      'Duikstekken-CSV voorbereiden...';

  @override
  String get settings_export_progress_preparingEquipmentCsv =>
      'Uitrusting-CSV voorbereiden...';

  @override
  String get settings_export_progress_preparingUddf =>
      'UDDF-bestand voorbereiden...';

  @override
  String get settings_export_progress_preparingPdf => 'PDF voorbereiden...';

  @override
  String get settings_export_progress_selectingBackup =>
      'Back-upbestand selecteren...';

  @override
  String get settings_export_progress_restoringBackup =>
      'Herstellen vanuit de back-up...';

  @override
  String get settings_export_empty_dives => 'Geen duiken om te exporteren';

  @override
  String get settings_export_empty_sites => 'Geen duikstekken om te exporteren';

  @override
  String get settings_export_empty_equipment =>
      'Geen uitrusting om te exporteren';

  @override
  String get settings_export_empty_data => 'Geen gegevens om te exporteren';

  @override
  String get settings_export_empty_diveSites =>
      'Geen duikstekken om te exporteren';

  @override
  String settings_export_saveFailed(String error) {
    return 'Opslaan mislukt: $error';
  }

  @override
  String settings_export_backupFailed(String error) {
    return 'Back-up mislukt: $error';
  }

  @override
  String settings_export_restoreFailed(String error) {
    return 'Herstellen mislukt: $error';
  }

  @override
  String get settings_export_fileUnreadable =>
      'Kan geen toegang krijgen tot het bestand';

  @override
  String get settings_export_notADbFile => 'Selecteer een .db-back-upbestand';

  @override
  String get settings_export_success_dives => 'Duiken succesvol geëxporteerd';

  @override
  String get settings_export_success_sites =>
      'Duikstekken succesvol geëxporteerd';

  @override
  String get settings_export_success_equipment =>
      'Uitrusting succesvol geëxporteerd';

  @override
  String get settings_export_success_pdf => 'PDF-logboek succesvol gegenereerd';

  @override
  String get settings_export_success_uddf =>
      'UDDF-bestand succesvol gegenereerd';

  @override
  String get settings_export_success_excel =>
      'Excel-bestand succesvol geëxporteerd';

  @override
  String settings_export_success_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'KML-bestand succesvol geëxporteerd ($count duikstekken zonder coördinaten overgeslagen)',
      one:
          'KML-bestand succesvol geëxporteerd (1 duikstek zonder coördinaten overgeslagen)',
      zero: 'KML-bestand succesvol geëxporteerd',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_excel =>
      'Excel-bestand succesvol opgeslagen';

  @override
  String settings_export_saved_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'KML-bestand succesvol opgeslagen ($count duikstekken zonder coördinaten overgeslagen)',
      one:
          'KML-bestand succesvol opgeslagen (1 duikstek zonder coördinaten overgeslagen)',
      zero: 'KML-bestand succesvol opgeslagen',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_divesCsv =>
      'Duiken-CSV succesvol opgeslagen';

  @override
  String get settings_export_saved_sitesCsv =>
      'Duikstekken-CSV succesvol opgeslagen';

  @override
  String get settings_export_saved_equipmentCsv =>
      'Uitrusting-CSV succesvol opgeslagen';

  @override
  String get settings_export_saved_uddf => 'UDDF-bestand succesvol opgeslagen';

  @override
  String get settings_export_saved_pdf => 'PDF succesvol opgeslagen';

  @override
  String get settings_export_saved_backup => 'Back-up succesvol opgeslagen';

  @override
  String get settings_export_restoreComplete => 'Herstel voltooid';

  @override
  String get settings_export_cancelled_save => 'Opslaan geannuleerd';

  @override
  String get settings_export_cancelled_backup => 'Back-up geannuleerd';

  @override
  String get settings_export_cancelled_restore => 'Herstellen geannuleerd';

  @override
  String get settings_export_pdfDocumentTitle => 'Duiklogboek';

  @override
  String get settings_export_saveBackupDialogTitle => 'Back-up opslaan';

  @override
  String backup_operation_created(String size) {
    return 'Back-up gemaakt: $size';
  }

  @override
  String backup_operation_backupFailed(String error) {
    return 'Back-up mislukt: $error';
  }

  @override
  String get backup_operation_restoring => 'Back-up herstellen...';

  @override
  String backup_operation_restoreFailed(String error) {
    return 'Herstellen mislukt: $error';
  }

  @override
  String get backup_operation_deleting => 'Back-up verwijderen...';

  @override
  String get backup_operation_deleted => 'Back-up verwijderd';

  @override
  String backup_operation_deleteFailed(String error) {
    return 'Verwijderen mislukt: $error';
  }

  @override
  String get backup_operation_exporting => 'Back-up exporteren...';

  @override
  String backup_operation_exported(String size) {
    return 'Back-up geëxporteerd: $size';
  }

  @override
  String backup_operation_exportFailed(String error) {
    return 'Export mislukt: $error';
  }

  @override
  String get backup_operation_preparingShare =>
      'Back-up voorbereiden om te delen...';

  @override
  String get backup_operation_shareReady => 'Back-up klaar om te delen';

  @override
  String backup_operation_upgrading(int step, int total) {
    return 'Database bijwerken (stap $step van $total)...';
  }

  @override
  String backup_restore_dialog_counts(int diveCount, int siteCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount duiken',
      one: '1 duik',
    );
    String _temp1 = intl.Intl.pluralLogic(
      siteCount,
      locale: localeName,
      other: '$siteCount duikstekken',
      one: '1 duikstek',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get backup_restore_preMigration_title =>
      'Back-up voor migratie herstellen';

  @override
  String get backup_restore_preMigration_unknownVersion => 'onbekende versie';

  @override
  String get backup_restore_preMigration_restoreAnyway => 'Toch herstellen';

  @override
  String backup_restore_preMigration_incompleteMetadata(
    String timestamp,
    String appVersion,
  ) {
    return 'Deze back-up is gemaakt op $timestamp door app $appVersion, maar de metagegevens van de databasemigratie zijn onvolledig.\n\nDe app kan niet controleren of het herstellen van deze back-up veilig is, daarom is herstellen uitgeschakeld.';
  }

  @override
  String backup_restore_preMigration_newerApp(
    String timestamp,
    String appVersion,
    int fromVersion,
  ) {
    return 'Deze back-up is nieuwer dan je app. Installeer een nieuwere appversie om hem te herstellen.\n\nBack-up gemaakt op $timestamp door app $appVersion (database v$fromVersion).';
  }

  @override
  String backup_restore_preMigration_safe(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
  ) {
    return 'Deze back-up is gemaakt op $timestamp door app $appVersion, vlak voor het bijwerken van de database van v$fromVersion naar v$toVersion.\n\nHet databaseschema van je app komt overeen met deze back-up, dus herstellen is veilig.';
  }

  @override
  String backup_restore_preMigration_warning(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
    int currentVersion,
  ) {
    return 'Deze back-up is gemaakt op $timestamp door app $appVersion, vlak voor het bijwerken van de database van v$fromVersion naar v$toVersion.\n\nJe gebruikt een nieuwere app (database v$currentVersion).\n\nNu herstellen voert de database-upgrade van v$fromVersion naar v$toVersion opnieuw uit op je herstelde gegevens, precies dezelfde upgrade die oorspronkelijk zou worden uitgevoerd. Als die upgrade het probleem veroorzaakte, loop je er opnieuw tegenaan.\n\nOm veilig te herstellen: installeer app $appVersion of ouder en herstel deze back-up vanuit die oudere app.';
  }

  @override
  String get settings_cloudSync_progress_preparing =>
      'Synchronisatie voorbereiden...';

  @override
  String get settings_cloudSync_progress_pulling => 'Wijzigingen ophalen...';

  @override
  String get settings_cloudSync_progress_publishing =>
      'Wijzigingen publiceren...';

  @override
  String settings_cloudSync_progress_uploadingLibrary(int uploaded, int total) {
    return 'Bibliotheek uploaden ($uploaded van $total)';
  }

  @override
  String get settings_cloudSync_result_noProvider =>
      'Geen cloudprovider ingesteld';

  @override
  String get settings_cloudSync_result_notAuthenticated =>
      'Niet geverifieerd bij de cloudprovider';

  @override
  String get settings_cloudSync_result_timedOut =>
      'Time-out bij de synchronisatie';

  @override
  String get settings_cloudSync_result_epochMarkerUnreadable =>
      'Kan de epochemarkering van de bibliotheek niet lezen';

  @override
  String get settings_cloudSync_result_epochMarkerEncrypted =>
      'De epochemarkering van de bibliotheek is versleuteld';

  @override
  String get settings_cloudSync_result_libraryReplacedRemotely =>
      'De cloudbibliotheek is vervangen vanaf een back-up';

  @override
  String get settings_cloudSync_result_noReplacementToRebuild =>
      'Geen bibliotheekvervanging om vanuit te herbouwen';

  @override
  String get settings_cloudSync_result_rebuiltFromThisDevice =>
      'Deze provider is opnieuw opgebouwd vanuit de bibliotheek van dit apparaat';

  @override
  String settings_cloudSync_result_rebuildFailed(String error) {
    return 'Herbouwen mislukt: $error';
  }

  @override
  String get settings_cloudSync_result_libraryReplaced =>
      'Bibliotheek vervangen';

  @override
  String settings_cloudSync_result_libraryReplaceFailed(String error) {
    return 'Vervangen van de bibliotheek mislukt: $error';
  }

  @override
  String get settings_cloudSync_result_noReplacementMarker =>
      'Geen markering voor bibliotheekvervanging gevonden';

  @override
  String get settings_cloudSync_result_adoptedRestoredLibrary =>
      'Herstelde bibliotheek overgenomen';

  @override
  String settings_cloudSync_result_adoptFailed(String error) {
    return 'Kan de herstelde bibliotheek niet overnemen: $error';
  }

  @override
  String get settings_cloudSync_result_previousLibraryUnreadable =>
      'De vorige bibliotheek kon niet worden gelezen; deze provider is opnieuw ingericht vanuit de bibliotheek van dit apparaat.';

  @override
  String get settings_cloudSync_result_replacementStillUploading =>
      'De vervangen bibliotheek wordt nog geüpload. Probeer het zo meteen opnieuw.';

  @override
  String settings_cloudSync_result_recordsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records konden niet worden toegepast',
      one: '1 record kon niet worden toegepast',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_result_adoptedFreshIdentity =>
      'Een ander apparaat synchroniseerde met de identiteit van dit apparaat. Dit apparaat heeft een nieuwe identiteit overgenomen en de cloudgegevens samengevoegd.';

  @override
  String settings_cloudSync_launchCheck_unavailable(String provider) {
    return '$provider is niet beschikbaar op dit apparaat';
  }

  @override
  String settings_cloudSync_launchCheck_notSignedIn(String provider) {
    return 'Niet aangemeld bij $provider';
  }

  @override
  String settings_cloudSync_launchCheck_localChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lokale wijzigingen om te uploaden',
      one: '1 lokale wijziging om te uploaden',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_launchCheck_noRemoteData =>
      'Geen synchronisatiegegevens gevonden in de cloud';

  @override
  String get settings_cloudSync_launchCheck_cloudDataAvailable =>
      'Cloudgegevens beschikbaar';

  @override
  String get settings_cloudSync_launchCheck_updatesAvailable =>
      'Updates beschikbaar uit de cloud';

  @override
  String get settings_cloudSync_launchCheck_upToDate => 'Alles is up-to-date';

  @override
  String settings_cloudSync_launchCheck_failed(String error) {
    return 'Synchronisatiecontrole mislukt: $error';
  }

  @override
  String get diveLog_detail_viewMap => 'Kaart';

  @override
  String get diveLog_detail_view3d => '3D';

  @override
  String get setup_sync_icloudUnavailable =>
      'iCloud is niet beschikbaar op dit apparaat';

  @override
  String get media_info_title => 'Media-info';

  @override
  String get media_info_fileSection => 'Bestand';

  @override
  String get media_info_filename => 'Bestandsnaam';

  @override
  String get media_info_type => 'Type';

  @override
  String get media_info_dimensions => 'Afmetingen';

  @override
  String get media_info_size => 'Grootte';

  @override
  String get media_info_taken => 'Gemaakt';

  @override
  String get media_info_coordinates => 'Coordinaten';

  @override
  String get media_info_unknown => 'Onbekend';

  @override
  String get media_info_originSection => 'Herkomst';

  @override
  String get media_info_source => 'Bron';

  @override
  String get media_info_reference => 'Referentie';

  @override
  String get media_info_linkedOn => 'Gekoppeld op';

  @override
  String get media_info_thisDevice => 'Dit apparaat';

  @override
  String get media_info_otherDevice => 'Een ander apparaat';

  @override
  String get media_info_status => 'Status';

  @override
  String get media_info_statusFound => 'Gevonden op dit apparaat';

  @override
  String get media_info_statusMissing => 'Ontbreekt op dit apparaat';

  @override
  String get media_info_statusUnchecked => 'Nog niet gecontroleerd';

  @override
  String media_info_lastChecked(String date) {
    return 'Laatst gecontroleerd $date';
  }

  @override
  String get media_timeInDive_label => 'Tijdstip in de duik';

  @override
  String get media_timeInDive_unknown => 'Tijdstip in de duik onbekend';

  @override
  String get media_timeInDive_setAction => 'Tijdstip in de duik instellen';

  @override
  String media_timeInDive_manual(String time) {
    return '$time (handmatig ingesteld)';
  }

  @override
  String get media_timeInDive_fieldLabel => 'Tijd sinds het begin van de duik';

  @override
  String get media_timeInDive_fieldHint => 'mm:ss';

  @override
  String media_timeInDive_range(String max) {
    return 'Tussen 0:00 en $max';
  }

  @override
  String media_timeInDive_invalid(String max) {
    return 'Voer een tijd in tussen 0:00 en $max';
  }

  @override
  String get media_timeInDive_save => 'Opslaan';

  @override
  String get media_timeInDive_cancel => 'Annuleren';

  @override
  String get media_timeInDive_reset => 'Terugzetten naar automatisch';

  @override
  String get media_info_backupSection => 'Back-up';

  @override
  String get media_info_store => 'Cloudopslag';

  @override
  String get media_info_storeNotConnected => 'Geen cloudopslag verbonden';

  @override
  String get media_info_notEligible =>
      'Deze bron komt niet in aanmerking voor back-up';

  @override
  String get media_info_backupFull => 'Origineel geupload';

  @override
  String get media_info_backupThumbOnly =>
      'Alleen miniatuur, origineel niet verzonden';

  @override
  String get media_info_backupRenditionOnly => 'Gecomprimeerde versie geupload';

  @override
  String get media_info_backupNone => 'Geen back-up';

  @override
  String media_info_uploadedOn(String date) {
    return 'Geupload $date';
  }

  @override
  String get media_info_queuePending => 'Wacht op uploaden';

  @override
  String get media_info_queueTransferring => 'Nu aan het uploaden';

  @override
  String media_info_queueFailed(Object error) {
    return 'Uploaden mislukt: $error';
  }

  @override
  String get media_info_servingSection => 'Nu geleverd door';

  @override
  String get media_info_servingUnobserved => 'Nog niet geladen';

  @override
  String get media_info_servingFailed => 'Kon niet worden geladen';

  @override
  String get media_info_servedLocalDisk => 'Lokaal bestand op dit apparaat';

  @override
  String get media_info_servedGallery => 'Fotobibliotheek';

  @override
  String get media_info_servedStoreCache => 'Lokale cache, uit de cloudopslag';

  @override
  String get media_info_servedStoreNetwork => 'Gedownload uit de cloudopslag';

  @override
  String get media_info_servedNetworkUrl => 'Streamen vanaf een URL';

  @override
  String get media_info_servedConnectorCache =>
      'Lokale cache, van de verbonden dienst';

  @override
  String get media_info_servedConnectorNetwork =>
      'Gedownload van de verbonden dienst';

  @override
  String get media_info_servedEmbedded => 'Opgeslagen in dit logboek';

  @override
  String get media_info_servingFallbackNote =>
      'De oorspronkelijke bron was niet bereikbaar, dus leverde de cloudopslag dit.';

  @override
  String get media_info_servingTierThumbnail => 'Miniatuur';

  @override
  String get media_info_servingTierRendition => 'Gecomprimeerde versie';

  @override
  String get media_info_typePhoto => 'Foto';

  @override
  String get media_info_typeVideo => 'Video';

  @override
  String get media_info_typeDocument => 'Document';

  @override
  String get media_info_typeSignature => 'Handtekening';

  @override
  String get media_info_actionCheckNow => 'Nu controleren';

  @override
  String get media_info_actionLocate => 'Bestand zoeken...';

  @override
  String get media_info_actionBackUpNow => 'Nu back-uppen';

  @override
  String get media_info_actionRetryUpload => 'Upload opnieuw proberen';

  @override
  String get media_info_actionReveal => 'Tonen in bestandsbeheer';

  @override
  String get media_info_actionCopyPath => 'Referentie kopiëren';

  @override
  String get media_info_referenceCopied => 'Referentie gekopieerd';

  @override
  String get media_info_checkFound => 'Bron gevonden';

  @override
  String get media_info_checkMissing => 'Bron ontbreekt';

  @override
  String get media_info_checkUnavailable => 'Kon nu niet controleren';

  @override
  String get media_info_backupQueued => 'In wachtrij voor upload';

  @override
  String get enum_profileMetric_o2CellMv => 'O2-cellen';

  @override
  String get enum_profileMetric_o2CellMv_short => 'Cellen';

  @override
  String get diveLog_o2CellSpread_label => 'O2-celspreiding';

  @override
  String get media_status_broken => 'Ontbreekt en geen back-up';

  @override
  String get media_servedFrom_localDisk => 'Op dit apparaat';

  @override
  String get media_servedFrom_platformGallery => 'Fotobibliotheek';

  @override
  String get media_servedFrom_storeCache => 'Cloudopslag, hier in cache';

  @override
  String get media_servedFrom_storeNetwork => 'Cloudopslag';

  @override
  String get media_servedFrom_networkUrl => 'Weblink';

  @override
  String get media_servedFrom_connectorCache =>
      'Verbonden service, hier in cache';

  @override
  String get media_servedFrom_connectorNetwork => 'Verbonden service';

  @override
  String get media_servedFrom_embedded => 'Opgeslagen in dit logboek';

  @override
  String get settings_media_provenanceBadges =>
      'Bronbadges op miniaturen tonen';

  @override
  String get settings_media_provenanceBadgesSubtitle =>
      'Een klein pictogram dat laat zien waar elk item vandaan komt. Probleembadges blijven altijd zichtbaar.';

  @override
  String get media_status_transferFailed => 'Uploaden mislukt';

  @override
  String get media_status_transferring => 'Uploaden';

  @override
  String get media_status_queued => 'Wacht op uploaden';

  @override
  String get media_status_cloudOnly => 'Alleen in de cloud opgeslagen';

  @override
  String get media_status_notBackedUp => 'Geen back-up';

  @override
  String get media_tile_infoMenuItem => 'Media-info';

  @override
  String get diveImport_healthkit_accessGrantedHint =>
      'Apple Gezondheid vertelt apps nooit of leestoegang is verleend. Verschijnen er geen duiken, open dan Gezondheid, vervolgens Delen, Apps, Submersion, en zet Workouts, Waterdiepte, Watertemperatuur en Hartslag aan.';

  @override
  String get diveImport_healthkit_foundNoDivesHint =>
      'Geen duikworkouts in dit bereik. Controleer of de datums de duik omvatten en of bij Gezondheid, Delen, Apps, Submersion de opties Workouts en Waterdiepte aanstaan.';

  @override
  String get settings_dataSources_appleHealth_dataTypeDepth =>
      'Waterdiepte - dieptemetingen die tijdens duiken zijn vastgelegd';

  @override
  String get settings_dataSources_appleHealth_dataTypeWaterTemp =>
      'Watertemperatuur - temperatuurmetingen die tijdens duiken zijn vastgelegd';

  @override
  String get settings_dataSources_appleHealth_permissionManagedInHealth =>
      'HealthKit-toegang beheer je in de app Gezondheid';

  @override
  String get settings_dataSources_appleHealth_permissionUnsupported =>
      'HealthKit is niet beschikbaar op dit apparaat';
}
