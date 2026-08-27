// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get universalImport_action_importFromGarmin =>
      'Importa da dispositivo Garmin';

  @override
  String diveLog_edit_flightWindowWarning(String time) {
    return 'Questa immersione termina dopo l\'ultimo orario sicuro di riemersione per il tuo volo ($time)';
  }

  @override
  String diveLog_edit_geofenceSuggestion_near(String location) {
    return 'Vicino a $location';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_title =>
      'Suggerimento attrezzatura';

  @override
  String diveLog_edit_geofenceSuggestion_body(String setName) {
    return 'Applicare il set \"$setName\"?';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_apply => 'Applica';

  @override
  String get common_action_dismiss => 'Ignora';

  @override
  String get equipment_setEdit_defaultSwitch_title => 'Set predefinito';

  @override
  String get equipment_setEdit_defaultSwitch_subtitle =>
      'Applicato automaticamente alle nuove immersioni senza attrezzatura';

  @override
  String get equipment_setEdit_geofencesTitle => 'Geofence';

  @override
  String get equipment_setEdit_geofencesSubtitle =>
      'Suggerisci automaticamente questo set per le immersioni vicino a queste posizioni';

  @override
  String get equipment_setEdit_addGeofence => 'Aggiungi geofence';

  @override
  String get equipment_setEdit_editGeofence => 'Edit geofence';

  @override
  String get equipment_setEdit_removeGeofence => 'Remove geofence';

  @override
  String equipment_setEdit_geofenceRadius(String distance) {
    return 'Raggio: $distance';
  }

  @override
  String get equipment_geofenceEditor_title => 'Geofence';

  @override
  String get equipment_geofenceEditor_fromSite => 'Da sito di immersione';

  @override
  String get equipment_geofenceEditor_dropPin => 'Posiziona un segnaposto';

  @override
  String get equipment_geofenceEditor_labelLabel => 'Etichetta';

  @override
  String get equipment_geofenceEditor_noCenter => 'Scegli un punto centrale';

  @override
  String get equipment_geofenceEditor_save => 'Salva geofence';

  @override
  String get equipment_sets_defaultBadge => 'Predefinito';

  @override
  String get equipment_setDetail_setAsDefault => 'Imposta come predefinito';

  @override
  String equipment_setDetail_setAsDefaultSnackbar(String name) {
    return '\"$name\" è ora il tuo set predefinito';
  }

  @override
  String get equipment_setDetail_geofencesTitle => 'Geofence';

  @override
  String get equipment_setDetail_noGeofences => 'Nessun geofence';

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
    return 'Oltre il limite massimo di densita di $limit g/L.';
  }

  @override
  String get gasCalculators_bestMix_densityLabel =>
      'Densita del gas alla quota';

  @override
  String gasCalculators_bestMix_densityWarn(Object limit) {
    return 'Oltre il limite di densita raccomandato di $limit g/L.';
  }

  @override
  String gasCalculators_bestMix_endExceeded(Object limit) {
    return 'L\'END supera il tuo limite di $limit.';
  }

  @override
  String get gasCalculators_bestMix_endLabel => 'END alla quota';

  @override
  String get gasCalculators_bestMix_endLimitLabel => 'Limite END';

  @override
  String gasCalculators_bestMix_heliumAdded(Object limit) {
    return 'Elio aggiunto per mantenere l\'END entro il tuo limite di $limit.';
  }

  @override
  String get gasCalculators_bestMix_idealLabel => 'Frazione ideale';

  @override
  String get gasCalculators_bestMix_marginLabel => 'Margine sotto la MOD';

  @override
  String gasCalculators_bestMix_modLabel(Object ppO2) {
    return 'MOD a ppO2 $ppO2';
  }

  @override
  String get gasCalculators_bestMix_nearestStandard =>
      'Miscela standard piu vicina che copre questa quota';

  @override
  String get gasCalculators_bestMix_recommendedMix => 'Miscela consigliata';

  @override
  String get gasCalculators_bestMix_withoutHelium => 'Senza elio';

  @override
  String get gasCalculators_planningCaveat =>
      'Stima di pianificazione. Presuppone una risalita diretta. Verifica in base al tuo addestramento e aggiungi margine per le condizioni.';

  @override
  String gasCalculators_rockBottom_solveGas(Object depth, Object unit) {
    return 'Gas per risolvere il problema a $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_solveTime =>
      'Tempo di risoluzione del problema';

  @override
  String get gasCalculators_rockBottom_solveTimeHint =>
      'Tempo speso in quota a risolvere l\'emergenza prima di iniziare la risalita.';

  @override
  String o2Toxicity_addedThisDive(Object value) {
    return '+$value questa immersione';
  }

  @override
  String o2Toxicity_cnsProgressSemantics(Object percent) {
    return 'Progresso SNC $percent percento';
  }

  @override
  String get o2Toxicity_daily => 'Giornaliero';

  @override
  String o2Toxicity_otuSemantics(
    Object label,
    Object value,
    Object limit,
    Object percent,
  ) {
    return '$label: $value su $limit OTU, $percent percento';
  }

  @override
  String o2Toxicity_otuValueSemantics(Object label, Object value) {
    return '$label: $value OTU';
  }

  @override
  String o2Toxicity_prior(Object value) {
    return 'Precedente: $value OTU';
  }

  @override
  String o2Toxicity_start(Object value) {
    return 'Inizio: $value OTU';
  }

  @override
  String get o2Toxicity_thisDive => 'Questa immersione';

  @override
  String get o2Toxicity_weekly => 'Settimanale';

  @override
  String trips_story_dayLabel(int number) {
    return 'Giorno $number';
  }

  @override
  String get trips_story_surfaceDay => 'Giorno di superficie';

  @override
  String get trips_story_today => 'Oggi';

  @override
  String trips_story_dayOfTrip(int current, int total) {
    return 'Giorno $current di $total';
  }

  @override
  String trips_story_daysUntil(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni alla partenza',
      one: '1 giorno alla partenza',
    );
    return '$_temp0';
  }

  @override
  String trips_story_checklistProgress(int done, int total) {
    return '$done di $total completati';
  }

  @override
  String get trips_story_generateItinerary => 'Genera itinerario';

  @override
  String get trips_story_openGallery => 'Apri le foto del viaggio';

  @override
  String trips_story_generateItineraryError(String error) {
    return 'Impossibile generare l\'itinerario: $error';
  }

  @override
  String get trips_dayType_diveDay => 'Giorno di immersione';

  @override
  String get trips_dayType_seaDay => 'Giorno in mare';

  @override
  String get trips_dayType_portDay => 'Giorno in porto';

  @override
  String get trips_dayType_embark => 'Imbarco';

  @override
  String get trips_dayType_disembark => 'Sbarco';

  @override
  String get trips_story_planned => 'Pianificato';

  @override
  String get trips_story_empty_title => 'Nessuna immersione o itinerario';

  @override
  String get trips_story_empty_subtitle =>
      'Aggiungi immersioni o pianifica i giorni per vedere la storia.';

  @override
  String trips_story_history_dives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni passate qui',
      one: '1 immersione passata qui',
    );
    return '$_temp0';
  }

  @override
  String trips_story_history_avgTemp(String value) {
    return 'media $value';
  }

  @override
  String trips_story_history_avgDepth(String value) {
    return 'prof. media $value';
  }

  @override
  String get trips_story_rhythm_semantics =>
      'Orari delle immersioni del giorno';

  @override
  String get trips_story_map_semantics =>
      'Mappa del viaggio. I siti del giorno visibile sono evidenziati.';

  @override
  String get diveLog_bulkEdit_groupRebreather => 'Modalità e rebreather';

  @override
  String get diveLog_bulkEdit_fieldSetpointLow => 'Setpoint basso';

  @override
  String get diveLog_bulkEdit_fieldSetpointHigh => 'Setpoint alto';

  @override
  String get diveLog_bulkEdit_fieldSetpointDeco => 'Setpoint deco';

  @override
  String get diveLog_bulkEdit_fieldScrubberType => 'Tipo di calce';

  @override
  String get diveLog_bulkEdit_fieldScrubberDuration => 'Durata calce';

  @override
  String get diveLog_bulkEdit_contradiction =>
      'La modalità OC non può avere impostazioni rebreather. Disattiva quei campi o cambia modalità.';

  @override
  String diveLog_bulkEdit_appBarTitle(int count) {
    return 'Modifica $count immersioni';
  }

  @override
  String get diveLog_bulkEdit_groupLogistics => 'Logistica';

  @override
  String get diveLog_bulkEdit_groupWeather => 'Meteo';

  @override
  String get diveLog_bulkEdit_groupCollections => 'Tag, attrezzatura e vita';

  @override
  String get diveLog_bulkEdit_fieldFavorite => 'Preferito';

  @override
  String get diveLog_bulkEdit_fieldMyRole => 'Il mio ruolo';

  @override
  String get diveLog_bulkEdit_buddyRoleMixed => 'Misto';

  @override
  String get diveLog_bulkEdit_collectionWeights => 'Zavorre';

  @override
  String get diveLog_bulkEdit_collectionTanks => 'Bombole';

  @override
  String get diveLog_bulkEdit_notesSet => 'Imposta';

  @override
  String get diveLog_bulkEdit_notesAppend => 'Aggiungi in fondo';

  @override
  String get diveLog_bulkEdit_modeAdd => 'Aggiungi';

  @override
  String get diveLog_bulkEdit_modeRemove => 'Rimuovi';

  @override
  String get diveLog_bulkEdit_modeReplace => 'Sostituisci';

  @override
  String get diveLog_bulkEdit_modeUpdate => 'Aggiorna';

  @override
  String get diveLog_bulkEdit_tankOnlyIfEmpty =>
      'Solo immersioni senza bombola esistente';

  @override
  String get diveLog_bulkEdit_tankSpecsHint =>
      'Scegli quali attributi sovrascrivere sulle bombole che queste immersioni hanno già. Le pressioni iniziale e finale non vengono mai modificate.';

  @override
  String get diveLog_bulkEdit_tankSpecsNoFields =>
      'Scegli almeno un attributo della bombola da aggiornare.';

  @override
  String get diveLog_bulkEdit_tankFieldPreset => 'Preimpostazione';

  @override
  String get diveLog_bulkEdit_tankFieldRole => 'Ruolo';

  @override
  String get diveLog_bulkEdit_tankFieldVolume => 'Volume';

  @override
  String get diveLog_bulkEdit_tankFieldWorkingPressure =>
      'Pressione di esercizio';

  @override
  String get diveLog_bulkEdit_tankFieldMaterial => 'Materiale';

  @override
  String get diveLog_bulkEdit_tankFieldGasMix => 'Miscela';

  @override
  String get diveLog_bulkEdit_tankFieldName => 'Nome';

  @override
  String diveLog_bulkEdit_tankSpecsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count immersioni selezionate non hanno bombole e verranno saltate.',
      one: '1 immersione selezionata non ha bombole e verrà saltata.',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_bulkEdit_confirmTitle => 'Applicare le modifiche?';

  @override
  String get diveLog_bulkEdit_confirmApply => 'Applica';

  @override
  String get diveLog_bulkEdit_nothingSelected =>
      'Attiva almeno un campo per applicare le modifiche.';

  @override
  String diveLog_bulkEdit_applied(int count) {
    return '$count immersioni aggiornate';
  }

  @override
  String get settings_cloudSync_error_icloudSignedOut =>
      'iCloud non è disponibile. Accedi a iCloud nelle impostazioni del dispositivo.';

  @override
  String get settings_cloudSync_error_icloudUnknown =>
      'Impossibile raggiungere iCloud. Riprova.';

  @override
  String get settings_cloudSync_error_icloudUnsupported =>
      'La sincronizzazione iCloud non è disponibile in questa build di Submersion. Usa la sincronizzazione S3 o la versione dell\'App Store.';

  @override
  String get settings_cloudSync_provider_icloud_unsupportedSubtitle =>
      'Non disponibile in questa build: usa S3 o la versione dell\'App Store';

  @override
  String get settings_cloudSync_encryption_title => 'Crittografia end-to-end';

  @override
  String get settings_cloudSync_encryption_subtitleOff =>
      'Cripta tutti i dati di sincronizzazione e i backup cloud prima del caricamento';

  @override
  String get settings_cloudSync_encryption_subtitleNeedsProvider =>
      'Seleziona prima un provider cloud';

  @override
  String get settings_cloudSync_encryption_statusOff =>
      'La crittografia è disattivata';

  @override
  String get settings_cloudSync_encryption_statusOn =>
      'La crittografia è attiva';

  @override
  String get settings_cloudSync_encryption_statusOnSubtitle =>
      'I dati di sincronizzazione e i backup cloud vengono criptati prima del caricamento';

  @override
  String get settings_cloudSync_encryption_statusLocked =>
      'Criptato — serve la passphrase';

  @override
  String get settings_cloudSync_encryption_statusLockedSubtitle =>
      'Inserisci la passphrase per sincronizzare su questo dispositivo';

  @override
  String get settings_cloudSync_encryption_enable => 'Attiva la crittografia';

  @override
  String get settings_cloudSync_encryption_enterPassphrase =>
      'Inserisci la passphrase';

  @override
  String get settings_cloudSync_encryption_passphrase => 'Passphrase';

  @override
  String get settings_cloudSync_encryption_passphraseConfirm =>
      'Conferma la passphrase';

  @override
  String get settings_cloudSync_encryption_passphraseMismatch =>
      'Le passphrase non coincidono';

  @override
  String get settings_cloudSync_encryption_passphraseTooShort =>
      'Usa almeno 8 caratteri';

  @override
  String get settings_cloudSync_encryption_wrongPassphrase =>
      'Passphrase o codice di recupero errati';

  @override
  String get settings_cloudSync_encryption_warnUpdateDevices =>
      'Tutti gli altri dispositivi devono essere aggiornati all\'ultima versione dell\'app e scaricheranno di nuovo la libreria.';

  @override
  String get settings_cloudSync_encryption_warnLoss =>
      'Se perdi sia la passphrase sia il codice di recupero, i dati nel cloud non potranno essere recuperati. I dati sui tuoi dispositivi non sono mai a rischio.';

  @override
  String get settings_cloudSync_encryption_deletePlaintextBackups =>
      'Elimina i backup cloud non criptati esistenti';

  @override
  String get settings_cloudSync_encryption_recoveryTitle =>
      'Codice di recupero';

  @override
  String get settings_cloudSync_encryption_recoveryExplain =>
      'Annota questo codice e conservalo al sicuro. È l\'unico modo per rientrare se dimentichi la passphrase.';

  @override
  String get settings_cloudSync_encryption_recoverySavedConfirm =>
      'Ho salvato il mio codice di recupero';

  @override
  String get settings_cloudSync_encryption_changePassphrase =>
      'Cambia passphrase';

  @override
  String get settings_cloudSync_encryption_currentPassphrase =>
      'Passphrase attuale';

  @override
  String get settings_cloudSync_encryption_newPassphrase => 'Nuova passphrase';

  @override
  String get settings_cloudSync_encryption_regenerateRecovery =>
      'Genera un nuovo codice di recupero';

  @override
  String get settings_cloudSync_encryption_regenerateRecoveryWarn =>
      'Il vecchio codice di recupero smette subito di funzionare.';

  @override
  String get settings_cloudSync_encryption_disable =>
      'Disattiva la crittografia';

  @override
  String get settings_cloudSync_encryption_disableWarn =>
      'La libreria verrà ricaricata non criptata e gli altri dispositivi la scaricheranno di nuovo. I backup criptati esistenti restano ripristinabili con la passphrase.';

  @override
  String get settings_cloudSync_encryption_unlockTitle =>
      'Inserisci la passphrase di crittografia';

  @override
  String get settings_cloudSync_encryption_unlockHint =>
      'Passphrase o codice di recupero';

  @override
  String get settings_cloudSync_encryption_unlock => 'Sblocca';

  @override
  String get settings_cloudSync_encryption_continue => 'Continua';

  @override
  String get settings_cloudSync_encryption_done => 'Fatto';

  @override
  String get settings_cloudSync_encryption_cancel => 'Annulla';

  @override
  String get settings_backupEncryption_title => 'Crittografia dei backup';

  @override
  String get settings_backupEncryption_subtitleOff =>
      'Proteggi i tuoi backup con una password';

  @override
  String get settings_backupEncryption_subtitleOn =>
      'I backup sono crittografati con la tua password';

  @override
  String get settings_backupEncryption_enable => 'Crittografa i backup';

  @override
  String get settings_backupEncryption_turnOff => 'Disattiva la crittografia';

  @override
  String get settings_backupEncryption_turnOffTitle =>
      'Disattivare la crittografia dei backup?';

  @override
  String get settings_backupEncryption_turnOffBody =>
      'I nuovi backup non saranno più crittografati. Per ripristinare i backup già crittografati sarà comunque necessaria la tua password.';

  @override
  String get settings_backupEncryption_changePassword => 'Cambia password';

  @override
  String get settings_backupEncryption_regenerateRecovery =>
      'Rigenera il codice di recupero';

  @override
  String get settings_backupEncryption_password => 'Password';

  @override
  String get settings_backupEncryption_passwordConfirm => 'Conferma password';

  @override
  String get settings_backupEncryption_passwordTooShort =>
      'Usa almeno 8 caratteri';

  @override
  String get settings_backupEncryption_passwordMismatch =>
      'Le password non corrispondono';

  @override
  String get settings_backupEncryption_currentPassword => 'Password attuale';

  @override
  String get settings_backupEncryption_newPassword => 'Nuova password';

  @override
  String get settings_backupEncryption_changePasswordWarn =>
      'Su un altro dispositivo, ogni backup si apre con la password o il codice di recupero attivo al momento della sua creazione.';

  @override
  String get settings_backupEncryption_warnLoss =>
      'Se dimentichi la password e perdi il codice di recupero, i backup crittografati non potranno essere recuperati.';

  @override
  String get settings_backupEncryption_recoveryTitle =>
      'Il tuo codice di recupero';

  @override
  String get settings_backupEncryption_recoveryExplain =>
      'Conserva questo codice in un luogo sicuro. Può sbloccare i tuoi backup se dimentichi la password.';

  @override
  String get settings_backupEncryption_recoverySavedConfirm =>
      'Ho salvato il mio codice di recupero';

  @override
  String get settings_backupEncryption_unlockTitle =>
      'Inserisci la password del backup';

  @override
  String get settings_backupEncryption_unlockHint =>
      'Inserisci la password del backup o il codice di recupero';

  @override
  String get settings_backupEncryption_restoreUnlockTitle =>
      'Sblocca il backup crittografato';

  @override
  String get settings_backupEncryption_restoreUnlockHint =>
      'Inserisci la password o il codice di recupero di questo backup';

  @override
  String get settings_backupEncryption_continue => 'Continua';

  @override
  String get settings_backupEncryption_cancel => 'Annulla';

  @override
  String get settings_backupEncryption_done => 'Fatto';

  @override
  String get settings_backupEncryption_reencryptTitle =>
      'Crittografare i backup esistenti?';

  @override
  String get settings_backupEncryption_reencryptBody =>
      'I tuoi backup esistenti non sono ancora crittografati. Vuoi crittografarli ora con la tua nuova password?';

  @override
  String get settings_backupEncryption_reencryptNow => 'Crittografa ora';

  @override
  String get settings_backupEncryption_reencryptNotNow => 'Non ora';

  @override
  String settings_backupEncryption_reencryptPartial(int done, int failed) {
    return '$done backup crittografati di nuovo; $failed non è stato possibile crittografarli e restano non protetti';
  }

  @override
  String settings_backupEncryption_reencryptDone(int count) {
    return '$count backup crittografati di nuovo';
  }

  @override
  String get settings_backupEncryption_wrongPassword =>
      'Password o codice di recupero non corretti';

  @override
  String settings_cloudSync_replace_globalBanner(String deviceName) {
    return 'Sincronizzazione in pausa: la libreria è stata sostituita da un backup su \"$deviceName\".';
  }

  @override
  String get settings_cloudSync_postRestore_syncing =>
      'Sincronizzazione della libreria ripristinata con il cloud…';

  @override
  String get settings_cloudSync_postRestore_synced =>
      'Libreria ripristinata sincronizzata.';

  @override
  String get settings_cloudSync_replace_reviewAction => 'Rivedi';

  @override
  String get accessibility_dialog_keyboardShortcutsTitle =>
      'Scorciatoie da tastiera';

  @override
  String get accessibility_keyLabel_backspace => 'Backspace';

  @override
  String get accessibility_keyLabel_delete => 'Canc';

  @override
  String get accessibility_keyLabel_down => 'Giu';

  @override
  String get accessibility_keyLabel_enter => 'Invio';

  @override
  String get accessibility_keyLabel_esc => 'Esc';

  @override
  String get accessibility_keyLabel_left => 'Sinistra';

  @override
  String get accessibility_keyLabel_right => 'Destra';

  @override
  String get accessibility_keyLabel_up => 'Su';

  @override
  String accessibility_label_chartSummary(
    Object chartType,
    Object description,
  ) {
    return 'Grafico $chartType. $description';
  }

  @override
  String get accessibility_label_createNewItem => 'Crea nuovo elemento';

  @override
  String get accessibility_label_hideList => 'Nascondi elenco';

  @override
  String get accessibility_label_hideMapView => 'Nascondi vista mappa';

  @override
  String accessibility_label_listPane(Object title) {
    return 'Pannello elenco $title';
  }

  @override
  String accessibility_label_mapPane(Object title) {
    return 'Pannello mappa $title';
  }

  @override
  String accessibility_label_mapViewTitle(Object title) {
    return 'Vista mappa $title';
  }

  @override
  String get accessibility_label_resizeMasterPane =>
      'Ridimensiona riquadro principale';

  @override
  String get accessibility_label_sharedWithAllProfiles =>
      'Condiviso con tutti i profili subacquei';

  @override
  String get accessibility_label_showList => 'Mostra elenco';

  @override
  String get accessibility_label_showMapView => 'Mostra vista mappa';

  @override
  String get accessibility_label_viewDetails => 'Visualizza dettagli';

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
  String get accessibility_shortcutCategory_editing => 'Modifica';

  @override
  String get accessibility_shortcutCategory_general => 'Generale';

  @override
  String get accessibility_shortcutCategory_help => 'Aiuto';

  @override
  String get accessibility_shortcutCategory_navigation => 'Navigazione';

  @override
  String get accessibility_shortcutCategory_search => 'Cerca';

  @override
  String get accessibility_shortcut_closeCancel => 'Chiudi / Annulla';

  @override
  String get accessibility_shortcut_goBack => 'Torna indietro';

  @override
  String get accessibility_shortcut_goToDives => 'Vai a Immersioni';

  @override
  String get accessibility_shortcut_goToEquipment => 'Vai ad Attrezzatura';

  @override
  String get accessibility_shortcut_goToSettings => 'Vai a Impostazioni';

  @override
  String get accessibility_shortcut_goToSites => 'Vai a Siti';

  @override
  String get accessibility_shortcut_goToStatistics => 'Vai a Statistiche';

  @override
  String get accessibility_shortcut_keyboardShortcuts =>
      'Scorciatoie da tastiera';

  @override
  String get accessibility_shortcut_newDive => 'Nuova immersione';

  @override
  String get accessibility_shortcut_openSettings => 'Apri impostazioni';

  @override
  String get accessibility_shortcut_searchDives => 'Cerca immersioni';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return 'Ordina per $displayName, attualmente selezionato';
  }

  @override
  String accessibility_sort_unselectedLabel(Object displayName) {
    return 'Ordina per $displayName';
  }

  @override
  String get backup_appBar_title => 'Backup e Ripristino';

  @override
  String get backup_backingUp => 'Backup in corso...';

  @override
  String get backup_backupNow => 'Esegui Backup Ora';

  @override
  String get backup_cloud_enabled => 'Backup cloud';

  @override
  String get backup_cloud_enabled_subtitle =>
      'Carica i backup nell\'archivio cloud';

  @override
  String get backup_delete_dialog_cancel => 'Annulla';

  @override
  String get backup_delete_dialog_content =>
      'Questo backup verrà eliminato permanentemente. Questa azione non può essere annullata.';

  @override
  String get backup_delete_dialog_delete => 'Elimina';

  @override
  String get backup_delete_dialog_title => 'Elimina Backup';

  @override
  String get backup_export_bottomSheet_title => 'Esporta backup';

  @override
  String get backup_export_saveToFile => 'Salva su file';

  @override
  String get backup_export_saveToFile_subtitle =>
      'Scegli dove salvare il file di backup';

  @override
  String get backup_export_share => 'Condividi';

  @override
  String get backup_export_share_subtitle =>
      'Invia tramite AirDrop, e-mail o altre app';

  @override
  String get backup_export_subtitle =>
      'Salva i tuoi dati di immersione in un file';

  @override
  String get backup_export_success => 'Backup esportato con successo';

  @override
  String get backup_export_title => 'Esporta backup';

  @override
  String get backup_frequency_daily => 'Giornaliero';

  @override
  String get backup_frequency_monthly => 'Mensile';

  @override
  String get backup_frequency_weekly => 'Settimanale';

  @override
  String get backup_history_action_delete => 'Elimina';

  @override
  String get backup_history_action_restore => 'Ripristina';

  @override
  String get backup_history_empty => 'Nessun backup';

  @override
  String backup_history_error(Object error) {
    return 'Errore nel caricamento della cronologia: $error';
  }

  @override
  String get backup_history_pinAction_pin => 'Fissa backup';

  @override
  String get backup_history_pinAction_unpin => 'Rimuovi fissaggio backup';

  @override
  String get backup_history_pinError =>
      'Impossibile aggiornare lo stato di fissaggio.';

  @override
  String backup_history_preMigrationSubtitle(String size) {
    return 'Backup pre-migrazione - $size';
  }

  @override
  String get backup_import_invalidFile =>
      'Questo file non sembra essere un backup Submersion valido';

  @override
  String get backup_import_subtitle =>
      'Importa un backup da qualsiasi posizione';

  @override
  String get backup_import_title => 'Ripristina da file';

  @override
  String get backup_import_validating => 'Validazione del file di backup...';

  @override
  String get backup_location_change => 'Cambia';

  @override
  String get backup_location_default => 'Posizione predefinita';

  @override
  String get backup_location_title => 'Posizione di backup';

  @override
  String get backup_replaceConfirm_confirm => 'Sostituisci ovunque';

  @override
  String get backup_replaceConfirm_content =>
      'La libreria su tutti i dispositivi sincronizzati verrà sostituita con questo backup. Ogni dispositivo crea prima un backup di sicurezza dei propri dati attuali. Questa operazione non può essere annullata.';

  @override
  String get backup_replaceConfirm_title => 'Sostituire la libreria ovunque?';

  @override
  String get backup_restore_dialog_cancel => 'Annulla';

  @override
  String get backup_restore_dialog_modeMerge_subtitle =>
      'Ripristina su questo dispositivo. La prossima sincronizzazione combinerà i dati ripristinati con la libreria nel cloud.';

  @override
  String get backup_restore_dialog_modeMerge_title =>
      'Unisci alla prossima sincronizzazione';

  @override
  String get backup_restore_dialog_modeReplace_subtitle =>
      'Il backup diventa la libreria su questo dispositivo, nel cloud e su ogni dispositivo sincronizzato.';

  @override
  String get backup_restore_dialog_modeReplace_title => 'Sostituisci ovunque';

  @override
  String get backup_restore_dialog_restore => 'Ripristina';

  @override
  String get backup_restore_dialog_restoreReplace =>
      'Ripristina e sostituisci ovunque';

  @override
  String get backup_restore_dialog_safetyNote =>
      'Un backup di sicurezza dei dati correnti verrà creato automaticamente prima del ripristino.';

  @override
  String get backup_restore_dialog_title => 'Ripristina Backup';

  @override
  String get backup_restore_dialog_warning =>
      'Questo sostituirà TUTTI i dati correnti con i dati del backup. Questa azione non può essere annullata.';

  @override
  String backup_restore_safetyReview_progress(int done, int total) {
    return 'Analizzate $done di $total immersioni';
  }

  @override
  String get backup_restore_safetyReview_skip => 'Salta';

  @override
  String get backup_restore_safetyReview_title =>
      'Revisione di sicurezza in corso';

  @override
  String get backup_restoreComplete_continue => 'Continua';

  @override
  String get backup_restoreComplete_description =>
      'I tuoi dati sono stati ripristinati con successo. Tocca continua per ricaricare l\'app con i dati ripristinati.';

  @override
  String get backup_restoreComplete_title => 'Ripristino Completato';

  @override
  String get backup_schedule_enabled => 'Backup automatici';

  @override
  String get backup_schedule_enabled_subtitle =>
      'Esegui il backup dei dati secondo una pianificazione';

  @override
  String get backup_schedule_frequency => 'Frequenza';

  @override
  String get backup_schedule_retention => 'Conserva backup';

  @override
  String get backup_schedule_retention_subtitle =>
      'I backup più vecchi vengono rimossi automaticamente';

  @override
  String get backup_section_auto => 'Backup automatici';

  @override
  String get backup_section_cloud => 'Cloud';

  @override
  String get backup_section_history => 'Cronologia';

  @override
  String get backup_section_schedule => 'Pianificazione';

  @override
  String get backup_status_disabled => 'Backup Automatici Disattivati';

  @override
  String backup_status_lastBackup(String time) {
    return 'Ultimo backup: $time';
  }

  @override
  String get backup_status_neverBackedUp => 'Mai Eseguito il Backup';

  @override
  String get backup_status_noBackupsYet =>
      'Crea il tuo primo backup per proteggere i tuoi dati';

  @override
  String get backup_status_overdue => 'Backup in Ritardo';

  @override
  String get backup_status_upToDate => 'Backup Aggiornati';

  @override
  String backup_time_daysAgo(int count) {
    return '${count}g fa';
  }

  @override
  String backup_time_hoursAgo(int count) {
    return '${count}h fa';
  }

  @override
  String get backup_time_justNow => 'Adesso';

  @override
  String backup_time_minutesAgo(int count) {
    return '${count}m fa';
  }

  @override
  String get buddies_action_add => 'Aggiungi Compagno';

  @override
  String get buddies_action_addCertification => 'Aggiungi certificazione';

  @override
  String get buddies_action_addFirst => 'Aggiungi il tuo primo compagno';

  @override
  String get buddies_action_addTooltip =>
      'Aggiungi un nuovo compagno di immersione';

  @override
  String get buddies_action_clearSearch => 'Cancella ricerca';

  @override
  String get buddies_action_edit => 'Modifica compagno';

  @override
  String get buddies_action_importFromContacts => 'Importa da Contatti';

  @override
  String get buddies_action_moreOptions => 'Altre opzioni';

  @override
  String get buddies_action_retry => 'Riprova';

  @override
  String get buddies_action_search => 'Cerca compagni';

  @override
  String get buddies_action_shareDives => 'Condividi Immersioni';

  @override
  String get buddies_action_sort => 'Ordina';

  @override
  String get buddies_action_sortTitle => 'Ordina Compagni';

  @override
  String get buddies_action_update => 'Aggiorna Compagno';

  @override
  String buddies_action_viewAll(Object count) {
    return 'Mostra Tutti ($count)';
  }

  @override
  String buddies_detail_error(Object error) {
    return 'Errore: $error';
  }

  @override
  String get buddies_detail_noDivesTogether =>
      'Nessuna immersione insieme ancora';

  @override
  String get buddies_detail_notFound => 'Compagno non trovato';

  @override
  String buddies_dialog_deleteMessage(Object name) {
    return 'Sei sicuro di voler eliminare $name? Questa azione non può essere annullata.';
  }

  @override
  String get buddies_dialog_deleteTitle => 'Eliminare Compagno?';

  @override
  String get buddies_dialog_discard => 'Scarta';

  @override
  String get buddies_dialog_discardMessage =>
      'Hai modifiche non salvate. Sei sicuro di volerle scartare?';

  @override
  String get buddies_dialog_discardTitle => 'Scartare Modifiche?';

  @override
  String get buddies_dialog_keepEditing => 'Continua Modifica';

  @override
  String get buddies_empty_subtitle =>
      'Aggiungi il tuo primo compagno di immersione per iniziare';

  @override
  String get buddies_empty_title => 'Nessun compagno di immersione ancora';

  @override
  String buddies_error_loading(Object error) {
    return 'Errore: $error';
  }

  @override
  String get buddies_error_unableToLoadDives =>
      'Impossibile caricare le immersioni';

  @override
  String get buddies_error_unableToLoadStats =>
      'Impossibile caricare le statistiche';

  @override
  String get buddies_field_certificationAgency => 'Agenzia di Certificazione';

  @override
  String get buddies_field_certificationLevel => 'Livello di Certificazione';

  @override
  String get buddies_field_email => 'Email';

  @override
  String get buddies_field_emailHint => 'email@esempio.com';

  @override
  String get buddies_field_nameHint => 'Inserisci nome compagno';

  @override
  String get buddies_field_nameRequired => 'Nome *';

  @override
  String get buddies_field_notes => 'Note';

  @override
  String get buddies_field_notesHint => 'Aggiungi note su questo compagno...';

  @override
  String get buddies_field_phone => 'Telefono';

  @override
  String get buddies_field_phoneHint => '+39 123 456 7890';

  @override
  String get buddies_label_agency => 'Agenzia';

  @override
  String buddies_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni',
      one: '1 immersione',
    );
    return '$_temp0';
  }

  @override
  String get buddies_label_level => 'Livello';

  @override
  String get buddies_label_notSpecified => 'Non specificato';

  @override
  String get buddies_label_photoComingSoon =>
      'Supporto foto in arrivo nella v2.0';

  @override
  String get buddies_message_added => 'Compagno aggiunto con successo';

  @override
  String get buddies_message_contactImportUnavailable =>
      'L\'importazione dei contatti non è disponibile su questa piattaforma';

  @override
  String get buddies_message_contactLoadFailed =>
      'Impossibile caricare i contatti';

  @override
  String get buddies_message_contactPermissionRequired =>
      'È richiesto il permesso dei contatti per importare i compagni';

  @override
  String get buddies_message_deleted => 'Compagno eliminato';

  @override
  String buddies_message_errorImportingContact(Object error) {
    return 'Errore durante l\'importazione del contatto: $error';
  }

  @override
  String buddies_message_errorLoading(Object error) {
    return 'Errore durante il caricamento del compagno: $error';
  }

  @override
  String buddies_message_errorSaving(Object error) {
    return 'Errore durante il salvataggio del compagno: $error';
  }

  @override
  String buddies_message_exportFailed(Object error) {
    return 'Esportazione fallita: $error';
  }

  @override
  String get buddies_message_noDivesFound =>
      'Nessuna immersione trovata da esportare';

  @override
  String get buddies_message_noDivesToShare =>
      'Nessuna immersione da condividere con questo compagno';

  @override
  String get buddies_message_preparingExport => 'Preparazione esportazione...';

  @override
  String get buddies_message_updated => 'Compagno aggiornato con successo';

  @override
  String get buddies_picker_add => 'Aggiungi';

  @override
  String get buddies_picker_addCustomRole => 'Aggiungi ruolo personalizzato...';

  @override
  String get buddies_picker_addNew => 'Aggiungi Nuovo Compagno';

  @override
  String get buddies_picker_done => 'Fatto';

  @override
  String get buddies_picker_me => 'Io';

  @override
  String get buddies_picker_noBuddiesFound => 'Nessun compagno trovato';

  @override
  String get buddies_picker_noBuddiesYet => 'Nessun compagno ancora';

  @override
  String get buddies_picker_noRole => 'Nessun ruolo';

  @override
  String get buddies_picker_noneSelected => 'Nessun compagno selezionato';

  @override
  String get buddies_picker_searchHint => 'Cerca compagni...';

  @override
  String get buddies_picker_selectBuddies => 'Seleziona Compagni';

  @override
  String get buddies_picker_selectMyRole => 'Seleziona il mio ruolo';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Seleziona Ruolo per $name';
  }

  @override
  String get buddies_picker_setMyRole => 'Imposta il mio ruolo';

  @override
  String get buddies_picker_tapToAdd =>
      'Tocca \'Aggiungi\' per selezionare i compagni di immersione';

  @override
  String get buddies_search_hint => 'Cerca per nome, email o telefono';

  @override
  String buddies_search_noResults(Object query) {
    return 'Nessun compagno trovato per \"$query\"';
  }

  @override
  String get buddies_section_certification => 'Certificazione';

  @override
  String get buddies_section_certifications => 'Certificazioni';

  @override
  String get buddies_certifications_empty => 'Nessuna certificazione';

  @override
  String get buddies_section_contact => 'Contatto';

  @override
  String get buddies_section_diveStatistics => 'Statistiche Immersioni';

  @override
  String get buddies_section_notes => 'Note';

  @override
  String get buddies_section_sharedDives => 'Immersioni Condivise';

  @override
  String get buddies_stat_divesTogether => 'Immersioni Insieme';

  @override
  String get buddies_stat_favoriteSite => 'Sito Preferito';

  @override
  String get buddies_stat_firstDive => 'Prima Immersione';

  @override
  String get buddies_stat_lastDive => 'Ultima Immersione';

  @override
  String get buddies_summary_overview => 'Panoramica';

  @override
  String get buddies_summary_quickActions => 'Azioni Rapide';

  @override
  String get buddies_summary_recentBuddies => 'Compagni Recenti';

  @override
  String get buddies_summary_selectHint =>
      'Seleziona un compagno dalla lista per vedere i dettagli';

  @override
  String get buddies_summary_title => 'Compagni di Immersione';

  @override
  String get buddies_summary_totalBuddies => 'Compagni Totali';

  @override
  String get buddies_summary_withCertification => 'Con Certificazione';

  @override
  String get buddies_title => 'Compagni';

  @override
  String get buddies_title_add => 'Aggiungi Compagno';

  @override
  String get buddies_title_edit => 'Modifica Compagno';

  @override
  String get buddies_title_singular => 'Compagno';

  @override
  String get buddies_validation_emailInvalid => 'Inserisci un\'email valida';

  @override
  String get buddies_validation_nameRequired => 'Inserisci un nome';

  @override
  String get buddies_list_selection_closeTooltip => 'Chiudi selezione';

  @override
  String buddies_list_selection_count(int count) {
    return '$count selezionato/i';
  }

  @override
  String get buddies_list_selection_selectAllTooltip => 'Seleziona tutto';

  @override
  String get buddies_list_selection_deselectAllTooltip => 'Deseleziona tutto';

  @override
  String get buddies_list_selection_mergeTooltip => 'Unisci selezionati';

  @override
  String get buddies_list_selection_deleteTooltip => 'Elimina selezionati';

  @override
  String buddies_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'compagni',
      one: 'compagno',
    );
    return '$count $_temp0 uniti';
  }

  @override
  String get buddies_list_merge_undo => 'Annulla';

  @override
  String get buddies_list_merge_restored => 'Unione annullata';

  @override
  String get buddies_list_bulkDelete_title => 'Elimina compagni';

  @override
  String buddies_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'compagni',
      one: 'compagno',
    );
    return 'Sei sicuro di voler eliminare $count $_temp0? Questa azione non può essere annullata.';
  }

  @override
  String get buddies_list_bulkDelete_cancel => 'Annulla';

  @override
  String get buddies_list_bulkDelete_confirm => 'Elimina';

  @override
  String buddies_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'compagni',
      one: 'compagno',
    );
    return '$count $_temp0 eliminati';
  }

  @override
  String get buddies_edit_merge_title => 'Unisci compagni';

  @override
  String get buddies_edit_merge_fieldSourceCycleTooltip =>
      'Usa il valore del compagno selezionato successivo';

  @override
  String buddies_edit_merge_fieldSourceLabel(
    String buddyName,
    int current,
    int total,
  ) {
    return 'Da $buddyName ($current/$total)';
  }

  @override
  String get buddies_edit_merge_confirmTitle => 'Unisci compagni';

  @override
  String buddies_edit_merge_confirmBody(int count) {
    return 'Questo unirà $count compagni in uno. Le associazioni delle immersioni saranno combinate sotto il compagno risultante. Gli altri compagni saranno eliminati.';
  }

  @override
  String get buddies_edit_merge_loadingErrorTitle => 'Unisci compagni';

  @override
  String buddies_edit_merge_loadingErrorBody(String error) {
    return 'Impossibile caricare i compagni: $error';
  }

  @override
  String get buddies_edit_merge_notEnoughTitle => 'Unisci compagni';

  @override
  String get buddies_edit_merge_notEnoughBody =>
      'Compagni insufficienti per l\'unione.';

  @override
  String get buddies_instructorPicker_label => 'Istruttore dai compagni';

  @override
  String get buddies_instructorPicker_none => 'Nessuno (inserimento manuale)';

  @override
  String get certifications_appBar_addCertification =>
      'Aggiungi certificazione';

  @override
  String get certifications_appBar_certificationWallet =>
      'Portafoglio certificazioni';

  @override
  String get certifications_appBar_editCertification =>
      'Modifica certificazione';

  @override
  String get certifications_appBar_title => 'Certificazioni';

  @override
  String get certifications_detail_action_delete => 'Elimina';

  @override
  String get certifications_detail_appBar_title => 'Certificazione';

  @override
  String get certifications_detail_courseCompleted => 'Completato';

  @override
  String get certifications_detail_courseInProgress => 'In corso';

  @override
  String get certifications_detail_dialog_cancel => 'Annulla';

  @override
  String get certifications_detail_dialog_deleteConfirm => 'Elimina';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return 'Sei sicuro di voler eliminare \"$name\"?';
  }

  @override
  String get certifications_detail_dialog_deleteTitle =>
      'Eliminare certificazione?';

  @override
  String get certifications_detail_label_agency => 'Ente';

  @override
  String get certifications_detail_label_cardNumber => 'Numero tessera';

  @override
  String get certifications_detail_label_certification => 'Certificazione';

  @override
  String get certifications_detail_label_expiryDate => 'Data di scadenza';

  @override
  String get certifications_detail_label_instructorName => 'Nome';

  @override
  String get certifications_detail_label_instructorNumber => 'N. istruttore';

  @override
  String get certifications_detail_label_issueDate => 'Data di rilascio';

  @override
  String get certifications_detail_label_type => 'Tipo';

  @override
  String get certifications_detail_label_validity => 'Validita';

  @override
  String get certifications_detail_noExpiration => 'Nessuna scadenza';

  @override
  String get certifications_detail_notFound => 'Certificazione non trovata';

  @override
  String get certifications_detail_photoLabel_back => 'Retro';

  @override
  String get certifications_detail_photoLabel_front => 'Fronte';

  @override
  String certifications_detail_photo_fullscreenTitle(
    Object label,
    Object name,
  ) {
    return '$label - $name';
  }

  @override
  String get certifications_detail_photo_unableToLoad =>
      'Impossibile caricare l\'immagine';

  @override
  String get certifications_detail_sectionTitle_cardPhotos => 'Foto tessera';

  @override
  String get certifications_detail_sectionTitle_dates => 'Date';

  @override
  String get certifications_detail_sectionTitle_details =>
      'Dettagli certificazione';

  @override
  String get certifications_detail_sectionTitle_instructor => 'Istruttore';

  @override
  String get certifications_detail_sectionTitle_notes => 'Note';

  @override
  String get certifications_detail_sectionTitle_trainingCourse =>
      'Corso di formazione';

  @override
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  ) {
    return 'Foto $label di $name. Tocca per visualizzare a schermo intero';
  }

  @override
  String get certifications_detail_snackBar_deleted =>
      'Certificazione eliminata';

  @override
  String get certifications_detail_status_expired =>
      'Questa certificazione e scaduta';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return 'Scaduta il $date';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return 'Scade tra $days giorni';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return 'Scade il $date';
  }

  @override
  String get certifications_detail_tooltip_edit => 'Modifica certificazione';

  @override
  String get certifications_detail_tooltip_editShort => 'Modifica';

  @override
  String get certifications_detail_tooltip_moreOptions => 'Altre opzioni';

  @override
  String get certifications_ecardStack_empty_subtitle =>
      'Aggiungi la tua prima certificazione per vederla qui';

  @override
  String get certifications_ecardStack_empty_title =>
      'Nessuna certificazione ancora';

  @override
  String get certifications_ecard_label_cardNumber => 'N. TESSERA';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Certificato da $agency';
  }

  @override
  String get certifications_ecard_label_diver => 'SUBACQUEO';

  @override
  String get certifications_ecard_label_instructor => 'ISTRUTTORE';

  @override
  String get certifications_ecard_label_issued => 'RILASCIATO';

  @override
  String get certifications_ecard_label_validUntil => 'VALIDA FINO AL';

  @override
  String get certifications_ecard_statusBadge_expired => 'SCADUTO';

  @override
  String get certifications_ecard_statusBadge_expiring => 'IN SCADENZA';

  @override
  String get certifications_edit_appBar_add => 'Aggiungi certificazione';

  @override
  String get certifications_edit_appBar_edit => 'Modifica certificazione';

  @override
  String get certifications_edit_button_add => 'Aggiungi certificazione';

  @override
  String get certifications_edit_button_cancel => 'Annulla';

  @override
  String get certifications_edit_button_save => 'Salva';

  @override
  String get certifications_edit_button_update => 'Aggiorna certificazione';

  @override
  String get certifications_edit_certification_notSpecified =>
      'Non specificato';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return 'Cancella $label';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect =>
      'Tocca per selezionare';

  @override
  String get certifications_edit_dialog_discard => 'Scarta';

  @override
  String get certifications_edit_dialog_discardContent =>
      'Hai modifiche non salvate. Sei sicuro di voler uscire?';

  @override
  String get certifications_edit_dialog_discardTitle =>
      'Scartare le modifiche?';

  @override
  String get certifications_edit_dialog_keepEditing => 'Continua a modificare';

  @override
  String get certifications_edit_group_progression => 'Progressione';

  @override
  String get certifications_edit_group_specialties => 'Specialità';

  @override
  String get certifications_edit_help_expiryDate =>
      'Lascia vuoto per certificazioni senza scadenza';

  @override
  String get certifications_edit_helper_nameOnCard => 'Facoltativo';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Inserisci il numero della tessera di certificazione';

  @override
  String get certifications_edit_hint_instructorName =>
      'Nome dell\'istruttore certificante';

  @override
  String get certifications_edit_hint_instructorNumber =>
      'Numero di certificazione dell\'istruttore';

  @override
  String get certifications_edit_hint_notes => 'Eventuali note aggiuntive';

  @override
  String get certifications_edit_label_agency => 'Ente *';

  @override
  String get certifications_edit_label_cardNumber => 'Numero tessera';

  @override
  String get certifications_edit_label_certification => 'Certificazione';

  @override
  String get certifications_edit_label_expiryDate => 'Data di scadenza';

  @override
  String get certifications_edit_label_instructorName => 'Nome istruttore';

  @override
  String get certifications_edit_label_instructorNumber => 'Numero istruttore';

  @override
  String get certifications_edit_label_issueDate => 'Data di rilascio';

  @override
  String get certifications_edit_label_nameOnCard => 'Nome sulla tessera';

  @override
  String get certifications_edit_label_notes => 'Note';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return 'Aggiungi foto $label. Tocca per selezionare';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return 'Foto $label allegata. Tocca per cambiare';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery =>
      'Scegli dalla galleria';

  @override
  String certifications_edit_photo_removeTooltip(Object label) {
    return 'Rimuovi foto $label';
  }

  @override
  String get certifications_edit_photo_takePhoto => 'Scatta foto';

  @override
  String get certifications_edit_sectionTitle_cardPhotos => 'Foto tessera';

  @override
  String get certifications_edit_sectionTitle_dates => 'Date';

  @override
  String get certifications_edit_sectionTitle_instructorInfo =>
      'Informazioni istruttore';

  @override
  String get certifications_edit_sectionTitle_notes => 'Note';

  @override
  String get certifications_edit_snackBar_added =>
      'Certificazione aggiunta con successo';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return 'Errore nel caricamento della certificazione: $error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return 'Errore nella selezione della foto: $error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return 'Errore nel salvataggio della certificazione: $error';
  }

  @override
  String get certifications_edit_snackBar_updated =>
      'Certificazione aggiornata con successo';

  @override
  String get certifications_edit_validation_certificationOrNameRequired =>
      'Scegli una certificazione o inserisci un nome';

  @override
  String get certifications_list_button_retry => 'Riprova';

  @override
  String get certifications_list_empty_button =>
      'Aggiungi la tua prima certificazione';

  @override
  String get certifications_list_empty_subtitle =>
      'Aggiungi le tue certificazioni subacquee per tenere traccia\ndella tua formazione e qualifiche';

  @override
  String get certifications_list_empty_title =>
      'Nessuna certificazione aggiunta';

  @override
  String certifications_list_error_loading(Object error) {
    return 'Errore nel caricamento delle certificazioni: $error';
  }

  @override
  String get certifications_list_fab_addCertification =>
      'Aggiungi certificazione';

  @override
  String get certifications_list_section_expired => 'Scadute';

  @override
  String get certifications_list_section_expiringSoon => 'In scadenza';

  @override
  String get certifications_list_section_valid => 'Valide';

  @override
  String get certifications_list_sort_title => 'Ordina certificazioni';

  @override
  String get certifications_list_tile_expired => 'Scaduta';

  @override
  String certifications_list_tile_expiringDays(Object days) {
    return '${days}g';
  }

  @override
  String get certifications_list_tooltip_addCertification =>
      'Aggiungi certificazione';

  @override
  String get certifications_list_tooltip_search => 'Cerca certificazioni';

  @override
  String get certifications_list_tooltip_sort => 'Ordina';

  @override
  String get certifications_list_tooltip_walletView => 'Vista portafoglio';

  @override
  String get certifications_picker_clearTooltip =>
      'Cancella selezione certificazione';

  @override
  String get certifications_picker_empty_addButton => 'Aggiungi certificazione';

  @override
  String get certifications_picker_empty_title =>
      'Nessuna certificazione ancora';

  @override
  String certifications_picker_error(Object error) {
    return 'Errore nel caricamento delle certificazioni: $error';
  }

  @override
  String get certifications_picker_expired => 'Scaduta';

  @override
  String get certifications_picker_hint =>
      'Tocca per collegare a una certificazione ottenuta';

  @override
  String get certifications_picker_newCert => 'Nuova cert.';

  @override
  String get certifications_picker_noSelection =>
      'Nessuna certificazione selezionata';

  @override
  String get certifications_picker_sheetTitle => 'Collega a certificazione';

  @override
  String get certifications_renderer_footer => 'Submersion Dive Log';

  @override
  String certifications_renderer_label_cardNumber(Object number) {
    return 'N. tessera: $number';
  }

  @override
  String get certifications_renderer_label_hasCompletedTraining =>
      'ha completato la formazione come';

  @override
  String certifications_renderer_label_instructor(Object name) {
    return 'Istruttore: $name';
  }

  @override
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  ) {
    return 'Istruttore: $name ($number)';
  }

  @override
  String certifications_renderer_label_issued(Object date) {
    return 'Rilasciata: $date';
  }

  @override
  String get certifications_renderer_label_thisCertifies => 'Si certifica che';

  @override
  String get certifications_search_empty_hint =>
      'Cerca per nome, agenzia o numero tessera';

  @override
  String get certifications_search_fieldLabel => 'Cerca certificazioni...';

  @override
  String certifications_search_noResults(Object query) {
    return 'Nessuna certificazione trovata per \"$query\"';
  }

  @override
  String get certifications_search_tooltip_back => 'Indietro';

  @override
  String get certifications_search_tooltip_clear => 'Cancella ricerca';

  @override
  String certifications_share_error_card(Object error) {
    return 'Condivisione tessera non riuscita: $error';
  }

  @override
  String certifications_share_error_certificate(Object error) {
    return 'Condivisione certificato non riuscita: $error';
  }

  @override
  String get certifications_share_option_card_subtitle =>
      'Immagine della certificazione in formato tessera';

  @override
  String get certifications_share_option_card_title => 'Condividi come tessera';

  @override
  String get certifications_share_option_certificate_subtitle =>
      'Documento di certificazione formale';

  @override
  String get certifications_share_option_certificate_title =>
      'Condividi come certificato';

  @override
  String get certifications_share_title => 'Condividi certificazione';

  @override
  String get certifications_summary_header_subtitle =>
      'Seleziona una certificazione dalla lista per visualizzare i dettagli';

  @override
  String get certifications_summary_header_title => 'Certificazioni';

  @override
  String get certifications_summary_overview_title => 'Panoramica';

  @override
  String get certifications_summary_quickActions_add =>
      'Aggiungi certificazione';

  @override
  String get certifications_summary_quickActions_title => 'Azioni rapide';

  @override
  String get certifications_summary_recentTitle => 'Certificazioni recenti';

  @override
  String get certifications_summary_stat_expired => 'Scadute';

  @override
  String get certifications_summary_stat_expiringSoon => 'In scadenza';

  @override
  String get certifications_summary_stat_total => 'Totale';

  @override
  String get certifications_summary_stat_valid => 'Valide';

  @override
  String get certifications_wallet_appBar_title => 'Portafoglio certificazioni';

  @override
  String get certifications_wallet_error_retry => 'Riprova';

  @override
  String get certifications_wallet_error_title =>
      'Impossibile caricare le certificazioni';

  @override
  String get certifications_wallet_options_edit => 'Modifica';

  @override
  String get certifications_wallet_options_share => 'Condividi';

  @override
  String get certifications_wallet_options_viewDetails => 'Visualizza dettagli';

  @override
  String get certifications_wallet_tooltip_add => 'Aggiungi certificazione';

  @override
  String get certifications_wallet_tooltip_share => 'Condividi certificazione';

  @override
  String get checklists_section_title => 'Lista di controllo';

  @override
  String checklists_progress(int done, int total) {
    return '$done di $total attività completate';
  }

  @override
  String get checklists_empty_upcoming =>
      'Pianifica il tuo viaggio: aggiungi attività o applica un modello';

  @override
  String get checklists_empty_past =>
      'Nessun elemento nella lista di controllo';

  @override
  String get checklists_addItem => 'Aggiungi elemento';

  @override
  String get checklists_item_titleLabel => 'Titolo';

  @override
  String get checklists_item_titleRequired => 'Il titolo è obbligatorio';

  @override
  String get checklists_item_categoryLabel => 'Categoria';

  @override
  String get checklists_item_notesLabel => 'Note';

  @override
  String get checklists_item_dueDateLabel => 'Data di scadenza';

  @override
  String get checklists_item_dueOffsetLabel =>
      'Giorni prima dell\'inizio del viaggio';

  @override
  String get checklists_item_dueOffsetInvalid => 'Inserisci 0 o più giorni';

  @override
  String get checklists_item_overdue => 'In ritardo';

  @override
  String get checklists_item_edit => 'Modifica elemento';

  @override
  String get checklists_item_delete => 'Elimina elemento';

  @override
  String get checklists_menu_applyTemplate => 'Applica modello...';

  @override
  String get checklists_menu_saveAsTemplate => 'Salva come modello...';

  @override
  String get checklists_applySheet_title => 'Applica modello';

  @override
  String get checklists_applySheet_empty =>
      'Nessun modello disponibile. Creane uno nelle Impostazioni.';

  @override
  String checklists_applySheet_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String checklists_applySheet_confirmAppend(int added, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Verranno aggiunti $added elementi',
      one: 'Verrà aggiunto 1 elemento',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped duplicati ignorati',
      one: '1 duplicato ignorato',
      zero: 'nessun duplicato ignorato',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String checklists_apply_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi aggiunti',
      one: '1 elemento aggiunto',
      zero: 'Nessun nuovo elemento aggiunto',
    );
    return '$_temp0';
  }

  @override
  String get checklists_apply_templateGone => 'Il modello non esiste più';

  @override
  String get checklists_saveTemplate_title => 'Salva come modello';

  @override
  String get checklists_saveTemplate_nameLabel => 'Nome del modello';

  @override
  String get checklists_saveTemplate_success => 'Modello salvato';

  @override
  String get checklists_templates_pageTitle => 'Modelli di liste di controllo';

  @override
  String get checklists_templates_addTemplate => 'Aggiungi modello';

  @override
  String get checklists_templates_empty => 'Nessun modello disponibile';

  @override
  String get checklists_templates_deleteTitle => 'Elimina modello';

  @override
  String checklists_templates_deleteContent(Object name) {
    return 'Eliminare \"$name\"? I viaggi che lo hanno già applicato manterranno i loro elementi.';
  }

  @override
  String get checklists_template_nameLabel => 'Nome';

  @override
  String get checklists_template_nameRequired => 'Il nome è obbligatorio';

  @override
  String get checklists_template_descriptionLabel => 'Descrizione';

  @override
  String get checklists_template_itemsHeader => 'Elementi';

  @override
  String get checklists_template_addItem => 'Aggiungi elemento';

  @override
  String get preDive_templates_title => 'Checklist pre-immersione';

  @override
  String get preDive_templates_empty =>
      'Ancora nessuna checklist pre-immersione';

  @override
  String get preDive_templates_builtInBadge => 'Predefinita';

  @override
  String get preDive_templates_clone => 'Duplica';

  @override
  String get preDive_templates_cloneSuffix => ' (copia)';

  @override
  String get preDive_templates_delete => 'Elimina';

  @override
  String get preDive_templates_deleteConfirm =>
      'Eliminare questo modello di checklist?';

  @override
  String get preDive_templates_strictOrderBadge => 'Ordine rigoroso';

  @override
  String get preDive_edit_titleNew => 'Nuova checklist pre-immersione';

  @override
  String get preDive_edit_titleEdit => 'Modifica checklist pre-immersione';

  @override
  String get preDive_edit_name => 'Nome';

  @override
  String get preDive_edit_description => 'Descrizione';

  @override
  String get preDive_edit_category => 'Categoria';

  @override
  String get preDive_edit_strictOrder => 'Ordine rigoroso';

  @override
  String get preDive_edit_strictOrderHelp =>
      'Gli elementi devono essere completati dall\'alto verso il basso';

  @override
  String get preDive_edit_addItem => 'Aggiungi elemento';

  @override
  String get preDive_edit_nameRequired => 'Inserisci un nome';

  @override
  String get preDive_item_title => 'Titolo';

  @override
  String get preDive_item_section => 'Sezione';

  @override
  String get preDive_item_notes => 'Note';

  @override
  String get preDive_item_required => 'Obbligatorio';

  @override
  String get preDive_item_type_check => 'Casella di controllo';

  @override
  String get preDive_item_type_value => 'Valore registrato';

  @override
  String get preDive_item_type_equipmentSet =>
      'Elementi del set di attrezzatura';

  @override
  String get preDive_item_valueLabel => 'Etichetta del valore';

  @override
  String get preDive_item_valueUnit => 'Unità';

  @override
  String get preDive_item_valueMin => 'Min (avviso)';

  @override
  String get preDive_item_valueMax => 'Max (avviso)';

  @override
  String preDive_runner_progress(int done, int total) {
    return '$done di $total';
  }

  @override
  String get preDive_runner_complete => 'Completa';

  @override
  String preDive_runner_completeFlagged(int count) {
    return 'Completare con $count elementi segnalati?';
  }

  @override
  String get preDive_runner_abort => 'Interrompi checklist';

  @override
  String get preDive_runner_abortConfirm =>
      'Interrompere questa checklist? Verrà conservata nella cronologia come interrotta.';

  @override
  String get preDive_runner_skip => 'Salta';

  @override
  String get preDive_runner_flag => 'Segnala';

  @override
  String get preDive_runner_undo => 'Reimposta come in sospeso';

  @override
  String get preDive_runner_serviceOverdue => 'Manutenzione scaduta';

  @override
  String get preDive_runner_addNote => 'Aggiungi nota';

  @override
  String get preDive_runner_enterValue => 'Inserisci valore';

  @override
  String preDive_runner_flaggedBadge(int count) {
    return '$count segnalati';
  }

  @override
  String get preDive_runner_locked => 'Questa checklist è bloccata';

  @override
  String get preDive_sessions_title => 'Checklist pre-immersione';

  @override
  String get preDive_sessions_empty => 'Ancora nessuna esecuzione di checklist';

  @override
  String get preDive_sessions_resume => 'Riprendi';

  @override
  String get preDive_sessions_start => 'Avvia checklist';

  @override
  String get preDive_sessions_statusCompleted => 'Completata';

  @override
  String get preDive_sessions_statusAborted => 'Interrotta';

  @override
  String get preDive_sessions_statusInProgress => 'In corso';

  @override
  String get preDive_sessions_linkedDive => 'Immersione collegata';

  @override
  String get preDive_link_linkToDive => 'Collega a immersione';

  @override
  String get preDive_link_unlinkDive => 'Scollega immersione';

  @override
  String get preDive_link_linkChecklist => 'Collega checklist pre-immersione';

  @override
  String get preDive_link_unlinkChecklist =>
      'Scollega checklist pre-immersione';

  @override
  String get preDive_link_searchDives => 'Cerca immersioni';

  @override
  String get preDive_link_noDives => 'Nessuna immersione da collegare';

  @override
  String preDive_link_noDivesMatch(String query) {
    return 'Nessuna immersione corrisponde a \"$query\"';
  }

  @override
  String get preDive_link_noUnlinkedSessions =>
      'Nessuna checklist non collegata';

  @override
  String get preDive_link_linked => 'Checklist collegata a questa immersione';

  @override
  String get preDive_link_unlinked =>
      'Checklist scollegata da questa immersione';

  @override
  String get preDive_sessions_delete => 'Elimina';

  @override
  String get preDive_sessions_deleteConfirm =>
      'Eliminare questo record di checklist?';

  @override
  String get preDive_sessions_filter => 'Filtra';

  @override
  String get preDive_sessions_filterTitle => 'Filtra le checklist eseguite';

  @override
  String get preDive_sessions_filterChecklist => 'Checklist';

  @override
  String get preDive_sessions_filterStatus => 'Stato';

  @override
  String get preDive_sessions_filterFlaggedOnly => 'Solo con segnalazioni';

  @override
  String get preDive_sessions_filterDateRange => 'Intervallo di date';

  @override
  String get preDive_sessions_filterAnyDate => 'Qualsiasi data';

  @override
  String get preDive_sessions_filterClearAll => 'Cancella tutto';

  @override
  String get preDive_sessions_filterApply => 'Applica';

  @override
  String get preDive_sessions_filterFlaggedChip => 'Solo segnalazioni';

  @override
  String get preDive_sessions_emptyFiltered =>
      'Nessuna checklist corrisponde a questi filtri';

  @override
  String get preDive_sessions_export => 'Esporta in Excel';

  @override
  String get preDive_sessions_exportEmpty => 'Nessuna checklist da esportare';

  @override
  String preDive_sessions_exportFailed(String error) {
    return 'Esportazione non riuscita: $error';
  }

  @override
  String get preDive_start_title => 'Avvia checklist pre-immersione';

  @override
  String get preDive_start_template => 'Checklist';

  @override
  String get preDive_start_equipmentSet => 'Set di attrezzatura';

  @override
  String get preDive_start_noEquipmentSet => 'Nessuno';

  @override
  String get preDive_start_begin => 'Inizia';

  @override
  String get diveLog_listPage_bottomSheet_preDiveChecklist =>
      'Avvia checklist pre-immersione';

  @override
  String get preDive_dashboard_title => 'Controllo pre-immersione';

  @override
  String preDive_dashboard_resume(int done, int total) {
    return 'Riprendi - $done di $total';
  }

  @override
  String get preDive_dashboard_start => 'Avvia controllo pre-immersione';

  @override
  String get trips_detail_preDive_action => 'Checklist pre-immersione';

  @override
  String get settings_manage_preDiveChecklists => 'Checklist pre-immersione';

  @override
  String get settings_manage_preDiveChecklists_subtitle =>
      'Buddy check, liste di montaggio CCR, preparazione attrezzatura';

  @override
  String get common_action_back => 'Indietro';

  @override
  String get common_action_cancel => 'Annulla';

  @override
  String get common_action_close => 'Chiudi';

  @override
  String get common_action_continue => 'Continua';

  @override
  String get common_action_delete => 'Elimina';

  @override
  String get common_action_edit => 'Modifica';

  @override
  String get common_action_ok => 'OK';

  @override
  String get common_action_save => 'Salva';

  @override
  String get common_action_search => 'Cerca';

  @override
  String get common_action_share => 'Condividi';

  @override
  String get common_label_error => 'Errore';

  @override
  String get common_label_loading => 'Caricamento';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get common_error_tryAgain => 'Qualcosa è andato storto. Riprova.';

  @override
  String get courses_action_add => 'Aggiungi Corso';

  @override
  String get courses_action_addFromTemplate => 'Aggiungi da modello';

  @override
  String get courses_action_addRequirement => 'Aggiungi requisito';

  @override
  String get courses_action_create => 'Crea Corso';

  @override
  String get courses_action_deleteRequirement => 'Elimina requisito';

  @override
  String get courses_action_edit => 'Modifica corso';

  @override
  String get courses_action_editRequirement => 'Modifica requisito';

  @override
  String get courses_action_exportTrainingLog =>
      'Esporta Registro Addestramento';

  @override
  String get courses_action_linkDive => 'Collega';

  @override
  String get courses_action_markCompleted => 'Segna come Completato';

  @override
  String get courses_action_unlinkDive => 'Scollega immersione';

  @override
  String get courses_action_moreOptions => 'Altre opzioni';

  @override
  String get courses_action_retry => 'Riprova';

  @override
  String get courses_action_saveChanges => 'Salva Modifiche';

  @override
  String get courses_action_saveSemantic => 'Salva corso';

  @override
  String get courses_action_sort => 'Ordina';

  @override
  String get courses_action_sortTitle => 'Ordina Corsi';

  @override
  String courses_card_instructor(Object name) {
    return 'Istruttore: $name';
  }

  @override
  String courses_card_started(Object date) {
    return 'Iniziato il $date';
  }

  @override
  String get courses_detail_certificationNotFound =>
      'Certificazione non trovata';

  @override
  String get courses_detail_noTrainingDives =>
      'Nessuna immersione di addestramento collegata ancora';

  @override
  String get courses_detail_notFound => 'Corso non trovato';

  @override
  String get courses_dialog_complete => 'Completa';

  @override
  String courses_dialog_deleteMessage(Object name) {
    return 'Sei sicuro di voler eliminare $name? Questa azione non può essere annullata.';
  }

  @override
  String get courses_dialog_deleteTitle => 'Eliminare Corso?';

  @override
  String get courses_dialog_markCompletedMessage =>
      'Questo segnerà il corso come completato con la data odierna. Continuare?';

  @override
  String get courses_dialog_markCompletedTitle => 'Segnare come Completato?';

  @override
  String get courses_empty_button =>
      'Aggiungi il tuo primo corso di addestramento';

  @override
  String get courses_empty_noCompleted => 'Nessun corso completato';

  @override
  String get courses_empty_noInProgress => 'Nessun corso in corso';

  @override
  String get courses_empty_subtitle =>
      'Aggiungi il tuo primo corso per iniziare';

  @override
  String get courses_empty_title => 'Nessun corso di addestramento ancora';

  @override
  String courses_error_generic(Object error) {
    return 'Errore: $error';
  }

  @override
  String get courses_error_loadingCertification =>
      'Errore durante il caricamento della certificazione';

  @override
  String get courses_error_loadingDives =>
      'Errore durante il caricamento delle immersioni';

  @override
  String get courses_field_courseName => 'Nome Corso';

  @override
  String get courses_field_courseNameHint => 'es. Open Water Diver';

  @override
  String get courses_field_instructorName => 'Nome Istruttore';

  @override
  String get courses_field_instructorNumber => 'Numero Istruttore';

  @override
  String get courses_field_linkCertificationHint =>
      'Collega una certificazione ottenuta da questo corso';

  @override
  String get courses_field_location => 'Località';

  @override
  String get courses_field_notes => 'Note';

  @override
  String get courses_filter_all => 'Tutti';

  @override
  String get courses_label_agency => 'Agenzia';

  @override
  String get courses_label_completed => 'Completato';

  @override
  String get courses_label_completionDate => 'Data Completamento';

  @override
  String get courses_label_courseInProgress => 'Corso in corso';

  @override
  String get courses_label_instructorNumber => 'N. Istruttore';

  @override
  String get courses_label_location => 'Località';

  @override
  String get courses_label_name => 'Nome';

  @override
  String get courses_label_startDate => 'Data Inizio';

  @override
  String courses_message_errorSaving(Object error) {
    return 'Errore durante il salvataggio del corso: $error';
  }

  @override
  String courses_message_exportFailed(Object error) {
    return 'Esportazione del registro addestramento fallita: $error';
  }

  @override
  String get courses_picker_active => 'Attivo';

  @override
  String get courses_picker_clearSelection => 'Cancella selezione';

  @override
  String get courses_picker_createCourse => 'Crea Corso';

  @override
  String courses_picker_errorLoading(Object error) {
    return 'Errore durante il caricamento dei corsi: $error';
  }

  @override
  String get courses_picker_newCourse => 'Nuovo Corso';

  @override
  String get courses_picker_noCourses => 'Nessun corso ancora';

  @override
  String get courses_picker_noneSelected => 'Nessun corso selezionato';

  @override
  String get courses_picker_selectTitle => 'Seleziona Corso di Addestramento';

  @override
  String get courses_picker_selected => 'selezionato';

  @override
  String get courses_picker_tapToLink =>
      'Tocca per collegare a un corso di addestramento';

  @override
  String courses_requirement_diveProgress(int count, int target) {
    return '$count di $target immersioni';
  }

  @override
  String get courses_requirement_field_name => 'Nome';

  @override
  String get courses_requirement_field_targetCount => 'Immersioni richieste';

  @override
  String get courses_requirement_kind_checklist => 'Elemento da spuntare';

  @override
  String get courses_requirement_kind_dive => 'Requisito di immersione';

  @override
  String get courses_requirement_suggestions => 'Immersioni suggerite';

  @override
  String get courses_requirements_empty =>
      'Tieni traccia delle immersioni adventure, dei prerequisiti e degli elementi da spuntare per questo corso.';

  @override
  String courses_requirements_progress(int satisfied, int total) {
    return '$satisfied di $total completati';
  }

  @override
  String get courses_section_details => 'Dettagli Corso';

  @override
  String get courses_section_earnedCertification => 'Certificazione Ottenuta';

  @override
  String get courses_section_instructor => 'Istruttore';

  @override
  String get courses_section_notes => 'Note';

  @override
  String get courses_section_requirements => 'Requisiti';

  @override
  String get courses_section_trainingDives => 'Immersioni di Addestramento';

  @override
  String get courses_status_completed => 'Completato';

  @override
  String courses_status_daysSinceStart(Object days) {
    return '$days giorni dall\'inizio';
  }

  @override
  String courses_status_durationDays(Object days) {
    return '$days giorni';
  }

  @override
  String get courses_status_inProgress => 'In Corso';

  @override
  String courses_status_semanticLabel(Object status, Object duration) {
    return '$status, $duration';
  }

  @override
  String courses_template_addsCount(int count) {
    return 'Aggiunge $count requisiti';
  }

  @override
  String get courses_summary_overview => 'Panoramica';

  @override
  String get courses_summary_quickActions => 'Azioni Rapide';

  @override
  String get courses_summary_recentCourses => 'Corsi Recenti';

  @override
  String get courses_summary_selectHint =>
      'Seleziona un corso dalla lista per vedere i dettagli';

  @override
  String get courses_summary_title => 'Corsi di Addestramento';

  @override
  String get courses_summary_total => 'Totale';

  @override
  String get courses_title => 'Corsi di Addestramento';

  @override
  String get courses_title_edit => 'Modifica Corso';

  @override
  String get courses_title_new => 'Nuovo Corso';

  @override
  String get courses_title_singular => 'Corso';

  @override
  String get courses_validation_nameRequired => 'Inserisci un nome corso';

  @override
  String get dashboard_activeCourses_title => 'Corsi in corso';

  @override
  String get dashboard_activity_daySinceDiving =>
      'Giorno dall\'ultima immersione';

  @override
  String get dashboard_activity_daysSinceDiving =>
      'Giorni dall\'ultima immersione';

  @override
  String dashboard_activity_diveInYear(Object year) {
    return 'Immersione nel $year';
  }

  @override
  String get dashboard_activity_diveThisMonth => 'Immersione questo mese';

  @override
  String dashboard_activity_divesInYear(Object year) {
    return 'Immersioni nel $year';
  }

  @override
  String get dashboard_activity_divesThisMonth => 'Immersioni questo mese';

  @override
  String get dashboard_activity_error => 'Errore';

  @override
  String get dashboard_activity_lastDive => 'Ultima immersione';

  @override
  String get dashboard_activity_loading => 'Caricamento';

  @override
  String get dashboard_activity_noDivesYet => 'Nessuna immersione';

  @override
  String get dashboard_activity_today => 'Oggi!';

  @override
  String get dashboard_alerts_actionUpdate => 'Aggiorna';

  @override
  String get dashboard_alerts_actionView => 'Visualizza';

  @override
  String get dashboard_alerts_checkInsuranceExpiry =>
      'Controlla la scadenza della tua assicurazione';

  @override
  String get dashboard_alerts_daysOverdueOne => '1 giorno di ritardo';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return '$count giorni di ritardo';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => 'Scade tra 1 giorno';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return 'Scade tra $count giorni';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return 'Revisione $name in scadenza';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return 'Revisione $name scaduta';
  }

  @override
  String get dashboard_alerts_insuranceExpired => 'Assicurazione scaduta';

  @override
  String get dashboard_alerts_insuranceExpiredGeneric =>
      'La tua assicurazione subacquea e scaduta';

  @override
  String dashboard_alerts_insuranceExpiredProvider(Object provider) {
    return '$provider scaduta';
  }

  @override
  String dashboard_alerts_insuranceExpiresDate(Object date) {
    return 'Scade il $date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon =>
      'Assicurazione in scadenza';

  @override
  String get dashboard_alerts_sectionTitle => 'Avvisi e promemoria';

  @override
  String get dashboard_alerts_serviceDueToday => 'Revisione prevista per oggi';

  @override
  String get dashboard_alerts_serviceIntervalReached =>
      'Intervallo di revisione raggiunto';

  @override
  String get dashboard_defaultDiverName => 'Subacqueo';

  @override
  String get dashboard_greeting_afternoon => 'Buon pomeriggio';

  @override
  String get dashboard_greeting_evening => 'Buonasera';

  @override
  String get dashboard_greeting_morning => 'Buongiorno';

  @override
  String dashboard_greeting_withName(Object greeting, Object name) {
    return '$greeting, $name!';
  }

  @override
  String dashboard_greeting_withoutName(Object greeting) {
    return '$greeting!';
  }

  @override
  String get dashboard_hero_divesLoggedOne => '1 immersione registrata';

  @override
  String dashboard_hero_divesLoggedOther(Object count) {
    return '$count immersioni registrate';
  }

  @override
  String get dashboard_hero_divesTotalOne => '1 immersione';

  @override
  String dashboard_hero_divesTotalOther(Object count) {
    return '$count immersioni';
  }

  @override
  String get dashboard_hero_error => 'Pronti a esplorare le profondita?';

  @override
  String dashboard_hero_hoursUnderwater(Object hours) {
    return '$hours ore sott\'acqua';
  }

  @override
  String get dashboard_hero_loading => 'Caricamento statistiche immersioni...';

  @override
  String dashboard_hero_minutesUnderwater(Object minutes) {
    return '$minutes minuti sott\'acqua';
  }

  @override
  String get dashboard_hero_noDives =>
      'Pronto a registrare la tua prima immersione?';

  @override
  String get dashboard_hero_divesLoggedLabel => 'immersioni registrate';

  @override
  String get dashboard_hero_hoursUnderwaterLabel => 'ore sott\'acqua';

  @override
  String get dashboard_hero_daysSinceLabel => 'giorni dall\'ultima immersione';

  @override
  String get dashboard_hero_thisMonthLabel => 'questo mese';

  @override
  String get dashboard_hero_thisYearLabel => 'immersioni quest\'anno';

  @override
  String get dashboard_hero_todayLabel => 'oggi!';

  @override
  String get dashboard_hero_noDivesLabel => 'nessuna immersione';

  @override
  String get dashboard_hero_diverFallbackName => 'Subacqueo';

  @override
  String get dashboard_hero_statDives => 'immersioni';

  @override
  String get dashboard_hero_statHours => 'ore';

  @override
  String get dashboard_hero_statSites => 'siti';

  @override
  String get dashboard_hero_statCountries => 'paesi';

  @override
  String dashboard_activityStats_divesInYear(String year) {
    return 'immersioni nel $year';
  }

  @override
  String get dashboard_semantics_statsBar => 'Riepilogo statistiche immersioni';

  @override
  String get dashboard_gauges_addGear => 'Aggiungi attrezzatura';

  @override
  String dashboard_gauges_gearOk(String name) {
    return '$name OK';
  }

  @override
  String dashboard_gauges_gearDueIn(String name, int days) {
    return '$name in scadenza tra ${days}g';
  }

  @override
  String dashboard_gauges_gearOverdue(String name) {
    return '$name in ritardo';
  }

  @override
  String get dashboard_gauges_insuranceOk => 'Assicurazione OK';

  @override
  String dashboard_gauges_insuranceExpires(String date) {
    return 'Assicurazione scade il $date';
  }

  @override
  String get dashboard_gauges_insuranceExpired => 'Assicurazione scaduta';

  @override
  String get dashboard_gauges_noInsurance => 'Nessuna assicurazione registrata';

  @override
  String get dashboard_gauges_noFlyClear => 'No-fly 0:00';

  @override
  String dashboard_gauges_flightWindow(String hours, String minutes) {
    return 'Finestra di immersione $hours:$minutes';
  }

  @override
  String get dashboard_gauges_flightWindowClosed =>
      'Niente più immersioni prima del volo';

  @override
  String dashboard_gauges_noFlyRemaining(String hours, String minutes) {
    return 'No-fly $hours:$minutes';
  }

  @override
  String dashboard_gauges_lastDiveDays(int days) {
    return 'Ultima immersione ${days}g fa';
  }

  @override
  String get dashboard_gauges_lastDiveToday => 'Immersione oggi';

  @override
  String get dashboard_gauges_noDivesYet => 'Nessuna immersione';

  @override
  String get settings_homeChips_pageTitle => 'Schermata Home';

  @override
  String get settings_homeChips_description =>
      'Scegli quali chip di stato compaiono in cima alla scheda Home.';

  @override
  String get settings_homeChips_sectionTitle => 'Chip di stato';

  @override
  String get settings_homeCards_sectionTitle => 'Schede della Home';

  @override
  String get settings_homeCards_description =>
      'Scegli quali schede compaiono nella Home e trascinale per riordinarle.';

  @override
  String get settings_homeCards_autoHides =>
      'Si nasconde automaticamente quando è vuota';

  @override
  String get settings_homeCards_resetToDefault => 'Ripristina predefiniti';

  @override
  String get settings_homeCards_resetDialog_title =>
      'Ripristinare il layout della Home?';

  @override
  String get settings_homeCards_resetDialog_message =>
      'Ripristina l\'ordine predefinito delle schede e le mostra tutte di nuovo.';

  @override
  String get settings_homeCards_resetDialog_cancel => 'Annulla';

  @override
  String get settings_homeCards_resetDialog_confirm => 'Ripristina';

  @override
  String get settings_homeCards_card_hero => 'Intestazione di benvenuto';

  @override
  String get settings_homeCards_card_gaugeStrip => 'Chip di stato';

  @override
  String get settings_homeCards_card_preDive => 'Checklist pre-immersione';

  @override
  String get settings_homeCards_card_recentDives => 'Immersioni recenti';

  @override
  String get settings_homeCards_card_quickActions => 'Azioni rapide';

  @override
  String get settings_homeCards_card_milestones => 'Traguardi';

  @override
  String get settings_homeCards_card_photoRibbon => 'Media recenti';

  @override
  String get settings_homeCards_card_onThisDay => 'In questo giorno';

  @override
  String get settings_homeCards_card_yearInReview => 'Anno in rassegna';

  @override
  String get settings_homeCards_card_activeCourses => 'Avanzamento corsi';

  @override
  String get settings_homeCards_card_recentSitesMap => 'Mappa dei siti recenti';

  @override
  String get dashboard_allHidden_message =>
      'Tutte le schede della Home sono nascoste.';

  @override
  String get dashboard_allHidden_customize => 'Personalizza Home';

  @override
  String get settings_homeChips_flightWindow =>
      'Finestra di immersione pre-volo';

  @override
  String get settings_homeChips_gear => 'Manutenzione attrezzatura';

  @override
  String get settings_homeChips_insurance => 'Assicurazione';

  @override
  String get settings_homeChips_noFly => 'Timer no-fly';

  @override
  String get settings_homeChips_lastDive => 'Attualità delle immersioni';

  @override
  String get settings_homeChips_certifications => 'Scadenza certificazioni';

  @override
  String get settings_homeChips_trip => 'Prossimo viaggio';

  @override
  String get settings_homeChips_checklist => 'Checklist attiva';

  @override
  String get settings_homeChips_course => 'Progresso del corso';

  @override
  String get settings_homeChips_uploads => 'Caricamenti media';

  @override
  String get settings_homeChips_backup => 'Età del backup';

  @override
  String get settings_homeChips_sync => 'Stato sincronizzazione';

  @override
  String get settings_homeChips_dataQuality => 'Qualità dei dati';

  @override
  String dashboard_gauges_certsExpiring(int count) {
    return '$count certificazioni in scadenza';
  }

  @override
  String dashboard_gauges_tripCountdown(String name, int days) {
    return '$name tra ${days}g';
  }

  @override
  String get dashboard_gauges_checklistActive => 'Checklist in corso';

  @override
  String dashboard_gauges_courseProgress(String name, int done, int total) {
    return '$name: $done/$total';
  }

  @override
  String dashboard_gauges_uploadsPending(int count) {
    return '$count caricamenti in sospeso';
  }

  @override
  String get dashboard_gauges_backupNone => 'Nessun backup';

  @override
  String get dashboard_gauges_backupToday => 'Backup di oggi';

  @override
  String dashboard_gauges_backupDays(int days) {
    return 'Backup ${days}g fa';
  }

  @override
  String dashboard_gauges_syncPending(int count) {
    return '$count non sincronizzati';
  }

  @override
  String get dashboard_gauges_synced => 'Sincronizzato';

  @override
  String dashboard_gauges_dataIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemi nei dati',
      one: '1 problema nei dati',
    );
    return '$_temp0';
  }

  @override
  String get dashboard_gauges_retry =>
      'Stato non disponibile - tocca per riprovare';

  @override
  String get dashboard_urgent_title => 'Richiede attenzione';

  @override
  String get dashboard_media_title => 'Media recenti';

  @override
  String get dashboard_recentSites_title => 'Siti recenti';

  @override
  String get dashboard_yearInReview_title => 'Quest\'anno';

  @override
  String dashboard_yearInReview_divesVs(int count, int previous) {
    return '$count immersioni (contro $previous l\'anno scorso)';
  }

  @override
  String dashboard_yearInReview_hours(String hours) {
    return '$hours ore sott\'acqua';
  }

  @override
  String dashboard_yearInReview_maxDepth(String depth) {
    return 'Massima: $depth';
  }

  @override
  String get dashboard_onThisDay_title => 'In questo giorno';

  @override
  String dashboard_onThisDay_entry(String year, String site) {
    return '$year - $site';
  }

  @override
  String get dashboard_milestones_title => 'Traguardi';

  @override
  String dashboard_milestones_nextDive(int remaining, int milestone) {
    return '$remaining immersioni alla n. $milestone';
  }

  @override
  String dashboard_milestones_certYears(String name, int years, String month) {
    return '$name: $years anni a $month';
  }

  @override
  String get dashboard_personalRecords_coldest => 'Piu fredda';

  @override
  String get dashboard_personalRecords_deepest => 'Piu profonda';

  @override
  String get dashboard_personalRecords_longest => 'Piu lunga';

  @override
  String get dashboard_personalRecords_sectionTitle => 'Record personali';

  @override
  String get dashboard_personalRecords_warmest => 'Piu calda';

  @override
  String get dashboard_quickActions_addSite => 'Aggiungi sito';

  @override
  String get dashboard_quickActions_addSiteTooltip =>
      'Aggiungi un nuovo sito di immersione';

  @override
  String get dashboard_quickActions_logDive => 'Registra immersione';

  @override
  String get dashboard_quickActions_logDiveTooltip =>
      'Registra una nuova immersione';

  @override
  String get dashboard_quickActions_planDive => 'Pianifica immersione';

  @override
  String get dashboard_quickActions_planDiveTooltip =>
      'Pianifica una nuova immersione';

  @override
  String get dashboard_quickActions_sectionTitle => 'Azioni rapide';

  @override
  String get dashboard_quickActions_statistics => 'Statistiche';

  @override
  String get dashboard_quickActions_statisticsTooltip =>
      'Visualizza statistiche immersioni';

  @override
  String get dashboard_quickStats_countries => 'Paesi';

  @override
  String get dashboard_quickStats_countriesSubtitle => 'visitati';

  @override
  String get dashboard_quickStats_sectionTitle => 'In sintesi';

  @override
  String get dashboard_quickStats_species => 'Specie';

  @override
  String get dashboard_quickStats_speciesSubtitle => 'scoperte';

  @override
  String get dashboard_quickStats_topBuddy => 'Compagno preferito';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count immersioni';
  }

  @override
  String get dashboard_recentDives_empty => 'Nessuna immersione registrata';

  @override
  String get dashboard_recentDives_errorLoading =>
      'Impossibile caricare le immersioni';

  @override
  String get dashboard_recentDives_latestProfileTitle =>
      'Profilo dell\'ultima immersione';

  @override
  String get dashboard_recentDives_noProfileData =>
      'Nessun dato di profilo per questa immersione';

  @override
  String get dashboard_recentDives_profileLoadError =>
      'Impossibile caricare il profilo dell\'immersione';

  @override
  String dashboard_recentDives_profileMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get dashboard_recentDives_logFirst =>
      'Registra la tua prima immersione';

  @override
  String get dashboard_recentDives_sectionTitle => 'Immersioni recenti';

  @override
  String get dashboard_recentDives_viewAll => 'Vedi tutte';

  @override
  String get dashboard_recentDives_viewAllTooltip =>
      'Visualizza tutte le immersioni';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count avvisi attivi';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives =>
      'Errore: impossibile caricare le immersioni recenti';

  @override
  String get dashboard_semantics_errorLoadingStatistics =>
      'Errore: impossibile caricare le statistiche';

  @override
  String get dashboard_semantics_greetingBanner =>
      'Banner di benvenuto della dashboard';

  @override
  String get dashboard_stats_errorLoadingStatistics =>
      'Impossibile caricare le statistiche';

  @override
  String get dashboard_stats_hoursLogged => 'Ore registrate';

  @override
  String get dashboard_stats_maxDepth => 'Profondita massima';

  @override
  String get dashboard_stats_sitesVisited => 'Siti visitati';

  @override
  String get dashboard_stats_totalDives => 'Immersioni totali';

  @override
  String get decoCalculator_addToPlanner => 'Aggiungi al Pianificatore';

  @override
  String decoCalculator_bottomTimeSemantics(Object time) {
    return 'Tempo di fondo: $time minuti';
  }

  @override
  String get decoCalculator_createPlanTooltip =>
      'Crea un piano di immersione dai parametri correnti';

  @override
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  ) {
    return 'Piano creato: $depth$depthSymbol per ${time}min con $gasMixName';
  }

  @override
  String get decoCalculator_customMixTrimix =>
      'Miscela Personalizzata (Trimix)';

  @override
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol) {
    return 'Profondità: $depth $depthSymbol';
  }

  @override
  String get decoCalculator_diveParameters => 'Parametri Immersione';

  @override
  String get decoCalculator_endCaution => 'Attenzione';

  @override
  String get decoCalculator_endDanger => 'Pericolo';

  @override
  String get decoCalculator_endSafe => 'Sicuro';

  @override
  String get decoCalculator_field_bottomTime => 'Tempo di Fondo';

  @override
  String get decoCalculator_field_depth => 'Profondità';

  @override
  String get decoCalculator_field_gasMix => 'Miscela Gas';

  @override
  String get decoCalculator_gasSafety => 'Sicurezza Gas';

  @override
  String get decoCalculator_hideCustomMix => 'Nascondi Miscela Personalizzata';

  @override
  String get decoCalculator_hideCustomMixSemantics =>
      'Nascondi selettore miscela gas personalizzata';

  @override
  String get decoCalculator_modExceeded => 'MOD Superata';

  @override
  String get decoCalculator_modSafe => 'MOD Sicura';

  @override
  String get decoCalculator_ppO2Caution => 'ppO2 Attenzione';

  @override
  String get decoCalculator_ppO2Danger => 'ppO2 Pericolo';

  @override
  String get decoCalculator_ppO2Hypoxic => 'ppO2 Ipossica';

  @override
  String get decoCalculator_ppO2Safe => 'ppO2 Sicura';

  @override
  String get decoCalculator_resetToDefaults => 'Ripristina predefiniti';

  @override
  String get decoCalculator_showCustomMixSemantics =>
      'Mostra selettore miscela gas personalizzata';

  @override
  String decoCalculator_timeValueMin(Object time) {
    return '$time min';
  }

  @override
  String get decoCalculator_title => 'Calcolatore Deco';

  @override
  String get decoCalculator_waterType => 'Tipo di acqua';

  @override
  String get decoCalculator_waterType_standard => 'Standard';

  @override
  String diveCenters_accessibility_markerLabel(Object name) {
    return 'Centro immersioni: $name';
  }

  @override
  String get diveCenters_accessibility_selected => 'selezionato';

  @override
  String diveCenters_accessibility_viewDetails(Object name) {
    return 'Visualizza dettagli per $name';
  }

  @override
  String get diveCenters_accessibility_viewDives =>
      'Visualizza immersioni con questo centro';

  @override
  String get diveCenters_accessibility_viewFullscreenMap =>
      'Visualizza mappa a schermo intero';

  @override
  String diveCenters_accessibility_viewSavedCenter(Object name) {
    return 'Visualizza centro immersioni salvato $name';
  }

  @override
  String get diveCenters_action_addCenter => 'Aggiungi Centro';

  @override
  String get diveCenters_action_addNew => 'Aggiungi Nuovo';

  @override
  String get diveCenters_action_clearRating => 'Cancella';

  @override
  String get diveCenters_action_gettingLocation => 'Acquisizione...';

  @override
  String get diveCenters_action_import => 'Importa';

  @override
  String get diveCenters_action_importToMyCenters => 'Importa nei Miei Centri';

  @override
  String get diveCenters_action_lookingUp => 'Ricerca...';

  @override
  String get diveCenters_action_lookupFromAddress => 'Cerca da Indirizzo';

  @override
  String get diveCenters_action_pickFromMap => 'Scegli dalla Mappa';

  @override
  String get diveCenters_action_retry => 'Riprova';

  @override
  String get diveCenters_action_settings => 'Impostazioni';

  @override
  String get diveCenters_action_useMyLocation => 'Usa la Mia Posizione';

  @override
  String get diveCenters_action_view => 'Visualizza';

  @override
  String diveCenters_detail_divesLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni registrate',
      one: '1 immersione registrata',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_detail_divesWithCenter =>
      'Immersioni con questo Centro';

  @override
  String get diveCenters_detail_noDivesLogged =>
      'Nessuna immersione registrata ancora';

  @override
  String diveCenters_dialog_deleteMessage(Object name) {
    return 'Sei sicuro di voler eliminare \"$name\"?';
  }

  @override
  String get diveCenters_dialog_deleteTitle => 'Eliminare Centro Immersioni';

  @override
  String get diveCenters_dialog_discard => 'Scarta';

  @override
  String get diveCenters_dialog_discardMessage =>
      'Hai modifiche non salvate. Sei sicuro di volerle scartare?';

  @override
  String get diveCenters_dialog_discardTitle => 'Scartare Modifiche?';

  @override
  String get diveCenters_dialog_keepEditing => 'Continua Modifica';

  @override
  String get diveCenters_empty_button =>
      'Aggiungi il tuo primo centro immersioni';

  @override
  String get diveCenters_empty_subtitle =>
      'Aggiungi i tuoi diving center e operatori preferiti';

  @override
  String get diveCenters_empty_title => 'Nessun centro immersioni ancora';

  @override
  String diveCenters_error_generic(Object error) {
    return 'Errore: $error';
  }

  @override
  String get diveCenters_error_geocodeFailed =>
      'Impossibile trovare le coordinate per questo indirizzo';

  @override
  String get diveCenters_error_importFailed =>
      'Importazione del centro immersioni fallita';

  @override
  String diveCenters_error_loading(Object error) {
    return 'Errore durante il caricamento dei centri immersioni: $error';
  }

  @override
  String get diveCenters_error_locationPermission =>
      'Impossibile ottenere la posizione. Controlla i permessi.';

  @override
  String get diveCenters_error_locationUnavailable =>
      'Impossibile ottenere la posizione. I servizi di localizzazione potrebbero non essere disponibili.';

  @override
  String get diveCenters_error_noAddressForLookup =>
      'Inserisci un indirizzo per cercare le coordinate';

  @override
  String get diveCenters_error_notFound => 'Centro immersioni non trovato';

  @override
  String diveCenters_error_saving(Object error) {
    return 'Errore durante il salvataggio del centro immersioni: $error';
  }

  @override
  String get diveCenters_error_unknown => 'Errore sconosciuto';

  @override
  String get diveCenters_field_city => 'Città';

  @override
  String get diveCenters_field_country => 'Paese';

  @override
  String get diveCenters_field_latitude => 'Latitudine';

  @override
  String get diveCenters_field_longitude => 'Longitudine';

  @override
  String get diveCenters_field_nameRequired => 'Nome *';

  @override
  String get diveCenters_field_postalCode => 'Codice Postale';

  @override
  String get diveCenters_field_rating => 'Valutazione';

  @override
  String get diveCenters_field_stateProvince => 'Stato/Provincia';

  @override
  String get diveCenters_field_street => 'Indirizzo';

  @override
  String get diveCenters_hint_addressDescription =>
      'Indirizzo opzionale per la navigazione';

  @override
  String get diveCenters_hint_affiliationsDescription =>
      'Seleziona le agenzie di addestramento con cui questo centro è affiliato';

  @override
  String get diveCenters_hint_city => 'es., Phuket';

  @override
  String get diveCenters_hint_country => 'es., Thailandia';

  @override
  String get diveCenters_hint_email => 'info@centroimmersioni.com';

  @override
  String get diveCenters_hint_gpsDescription =>
      'Scegli un metodo di posizione o inserisci le coordinate manualmente';

  @override
  String get diveCenters_hint_importSearch =>
      'Cerca centri immersioni (es., \"PADI\", \"Thailandia\")';

  @override
  String get diveCenters_hint_latitude => 'es., 10.4613';

  @override
  String get diveCenters_hint_longitude => 'es., 99.8359';

  @override
  String get diveCenters_hint_name => 'Inserisci nome centro immersioni';

  @override
  String get diveCenters_hint_notes => 'Eventuali informazioni aggiuntive...';

  @override
  String get diveCenters_hint_phone => '+39 123 456 789';

  @override
  String get diveCenters_hint_postalCode => 'es., 83100';

  @override
  String get diveCenters_hint_stateProvince => 'es., Phuket';

  @override
  String get diveCenters_hint_street => 'es., Via Spiaggia 123';

  @override
  String get diveCenters_hint_website => 'www.centroimmersioni.com';

  @override
  String diveCenters_import_fromDatabase(Object count) {
    return 'Importa dal Database ($count)';
  }

  @override
  String diveCenters_import_myCenters(Object count) {
    return 'I Miei Centri ($count)';
  }

  @override
  String get diveCenters_import_noResults => 'Nessun Risultato';

  @override
  String diveCenters_import_noResultsMessage(Object query) {
    return 'Nessun centro immersioni trovato per \"$query\". Prova un termine di ricerca diverso.';
  }

  @override
  String get diveCenters_import_searchDescription =>
      'Cerca centri immersioni, negozi e club dal nostro database di operatori in tutto il mondo.';

  @override
  String get diveCenters_import_searchError => 'Errore di Ricerca';

  @override
  String get diveCenters_import_searchHint =>
      'Prova a cercare per nome, paese o agenzia di certificazione.';

  @override
  String get diveCenters_import_searchTitle => 'Cerca Centri Immersioni';

  @override
  String get diveCenters_label_alreadyImported => 'Già Importato';

  @override
  String diveCenters_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni',
      one: '1 immersione',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_label_email => 'Email';

  @override
  String get diveCenters_label_imported => 'Importato';

  @override
  String get diveCenters_label_locationNotSet => 'Posizione non impostata';

  @override
  String get diveCenters_label_locationUnknown => 'Posizione sconosciuta';

  @override
  String get diveCenters_label_phone => 'Telefono';

  @override
  String get diveCenters_label_saved => 'Salvato';

  @override
  String diveCenters_label_source(Object source) {
    return 'Fonte: $source';
  }

  @override
  String get diveCenters_label_website => 'Sito Web';

  @override
  String get diveCenters_map_addCoordinatesHint =>
      'Aggiungi coordinate ai tuoi centri immersioni per vederli sulla mappa';

  @override
  String get diveCenters_map_noCoordinates =>
      'Nessun centro immersioni con coordinate';

  @override
  String get diveCenters_picker_newCenter => 'Nuovo Centro Immersioni';

  @override
  String get diveCenters_picker_title => 'Seleziona Centro Immersioni';

  @override
  String diveCenters_search_noResults(Object query) {
    return 'Nessun risultato per \"$query\"';
  }

  @override
  String get diveCenters_search_prompt => 'Cerca centri immersioni';

  @override
  String get diveCenters_section_address => 'Indirizzo';

  @override
  String get diveCenters_section_affiliations => 'Affiliazioni';

  @override
  String get diveCenters_section_basicInfo => 'Informazioni di Base';

  @override
  String get diveCenters_section_contact => 'Contatto';

  @override
  String get diveCenters_section_contactInfo => 'Informazioni di Contatto';

  @override
  String get diveCenters_section_gpsCoordinates => 'Coordinate GPS';

  @override
  String get diveCenters_section_notes => 'Note';

  @override
  String get diveCenters_snackbar_coordinatesFound =>
      'Coordinate trovate dall\'indirizzo';

  @override
  String get diveCenters_snackbar_copiedToClipboard => 'Copiato negli appunti';

  @override
  String diveCenters_snackbar_imported(Object name) {
    return 'Importato \"$name\"';
  }

  @override
  String get diveCenters_snackbar_locationCaptured => 'Posizione acquisita';

  @override
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Posizione acquisita (±${accuracy}m)';
  }

  @override
  String get diveCenters_snackbar_locationSelectedFromMap =>
      'Posizione selezionata dalla mappa';

  @override
  String get diveCenters_sort_title => 'Ordina Centri Immersioni';

  @override
  String get diveCenters_summary_countries => 'Paesi';

  @override
  String get diveCenters_summary_highestRating => 'Valutazione Più Alta';

  @override
  String get diveCenters_summary_overview => 'Panoramica';

  @override
  String get diveCenters_summary_quickActions => 'Azioni Rapide';

  @override
  String get diveCenters_summary_recentCenters => 'Centri Immersioni Recenti';

  @override
  String get diveCenters_summary_selectPrompt =>
      'Seleziona un centro immersioni dalla lista per vedere i dettagli';

  @override
  String get diveCenters_summary_totalCenters => 'Centri Totali';

  @override
  String get diveCenters_summary_withGps => 'Con GPS';

  @override
  String get diveCenters_title => 'Centri Immersioni';

  @override
  String get diveCenters_title_add => 'Aggiungi Centro Immersioni';

  @override
  String get diveCenters_title_edit => 'Modifica Centro Immersioni';

  @override
  String get diveCenters_title_import => 'Importa Centro Immersioni';

  @override
  String get diveCenters_tooltip_addNew =>
      'Aggiungi un nuovo centro immersioni';

  @override
  String get diveCenters_tooltip_clearSearch => 'Cancella ricerca';

  @override
  String get diveCenters_tooltip_edit => 'Modifica centro immersioni';

  @override
  String get diveCenters_tooltip_fitAllCenters => 'Adatta Tutti i Centri';

  @override
  String get diveCenters_tooltip_listView => 'Vista Elenco';

  @override
  String get diveCenters_tooltip_mapView => 'Vista Mappa';

  @override
  String get diveCenters_tooltip_moreOptions => 'Altre opzioni';

  @override
  String get diveCenters_tooltip_search => 'Cerca centri immersioni';

  @override
  String get diveCenters_tooltip_sort => 'Ordina';

  @override
  String get diveCenters_validation_invalidEmail =>
      'Inserisci un\'email valida';

  @override
  String get diveCenters_validation_invalidLatitude => 'Latitudine non valida';

  @override
  String get diveCenters_validation_invalidLongitude =>
      'Longitudine non valida';

  @override
  String get diveCenters_validation_nameRequired => 'Il nome è obbligatorio';

  @override
  String get diveComputer_action_setFavorite => 'Imposta come preferito';

  @override
  String diveComputer_error_generic(Object error) {
    return 'Si è verificato un errore: $error';
  }

  @override
  String get diveComputer_error_notFound => 'Dispositivo non trovato';

  @override
  String get diveComputer_status_favorite => 'Computer preferito';

  @override
  String get diveComputer_title => 'Computer Subacqueo';

  @override
  String diveLog_bulkDelete_confirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni',
      one: 'immersione',
    );
    return 'Sei sicuro di voler eliminare $count $_temp0? Questa azione non puo essere annullata.';
  }

  @override
  String get diveLog_bulkDelete_restored => 'Immersioni ripristinate';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni eliminate',
      one: 'immersione eliminata',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_bulkDelete_title => 'Elimina immersioni';

  @override
  String get diveLog_bulkDelete_undo => 'Annulla';

  @override
  String get diveLog_bulkEdit_addTags => 'Aggiungi tag';

  @override
  String get diveLog_bulkEdit_addTagsDescription =>
      'Aggiungi tag alle immersioni selezionate';

  @override
  String diveLog_bulkEdit_addedTags(int tagCount, int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: 'Aggiunti $tagCount tag',
      one: 'Aggiunto $tagCount tag',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'immersioni',
      one: 'immersione',
    );
    return '$_temp0 a $diveCount $_temp1';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => 'Cambia viaggio';

  @override
  String get diveLog_bulkEdit_changeTripDescription =>
      'Sposta le immersioni selezionate in un viaggio';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips =>
      'Errore nel caricamento dei viaggi';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return 'Impossibile aggiungere i tag: $error';
  }

  @override
  String diveLog_bulkEdit_failedUpdateTrip(Object error) {
    return 'Impossibile aggiornare il viaggio: $error';
  }

  @override
  String diveLog_bulkEdit_movedToTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Spostate $count immersioni',
      one: 'Spostata $count immersione',
    );
    return '$_temp0 nel viaggio';
  }

  @override
  String get diveLog_bulkEdit_noTagsAvailable => 'Nessun tag disponibile.';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate =>
      'Nessun tag disponibile. Crea prima dei tag.';

  @override
  String get diveLog_bulkEdit_noTrip => 'Nessun viaggio';

  @override
  String get diveLog_bulkEdit_removeFromTrip => 'Rimuovi dal viaggio';

  @override
  String get diveLog_bulkEdit_removeTags => 'Rimuovi tag';

  @override
  String get diveLog_bulkEdit_removeTagsDescription =>
      'Rimuovi tag dalle immersioni selezionate';

  @override
  String diveLog_bulkEdit_removedFromTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rimosse $count immersioni',
      one: 'Rimossa $count immersione',
    );
    return '$_temp0 dal viaggio';
  }

  @override
  String get diveLog_bulkEdit_selectTrip => 'Seleziona viaggio';

  @override
  String diveLog_bulkEdit_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni',
      one: 'immersione',
    );
    return 'Modifica $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_csv => 'CSV';

  @override
  String get diveLog_bulkExport_csvDescription => 'Formato foglio di calcolo';

  @override
  String diveLog_bulkExport_failed(Object error) {
    return 'Esportazione fallita: $error';
  }

  @override
  String get diveLog_bulkExport_pdf => 'Logbook PDF';

  @override
  String get diveLog_bulkExport_pdfDescription =>
      'Pagine stampabili del diario immersioni';

  @override
  String diveLog_bulkExport_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Esportate $count immersioni',
      one: 'Esportata $count immersione',
    );
    return '$_temp0 con successo';
  }

  @override
  String diveLog_bulkExport_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni',
      one: 'immersione',
    );
    return 'Esporta $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_uddf => 'UDDF';

  @override
  String get diveLog_bulkExport_uddfDescription => 'Universal Dive Data Format';

  @override
  String get diveLog_ccr_diluent_air => 'Aria';

  @override
  String get diveLog_ccr_hint_loopVolume => 'es. 6,0';

  @override
  String get diveLog_ccr_hint_type => 'es. Sofnolime';

  @override
  String get diveLog_ccr_label_deco => 'Deco';

  @override
  String get diveLog_ccr_label_he => 'He';

  @override
  String get diveLog_ccr_label_highBottom => 'Alto (fondo)';

  @override
  String get diveLog_ccr_label_loopVolume => 'Volume del circuito';

  @override
  String get diveLog_ccr_label_lowDescAsc => 'Basso (discesa/risalita)';

  @override
  String get diveLog_ccr_label_n2 => 'N2';

  @override
  String get diveLog_ccr_label_o2 => 'O2';

  @override
  String get diveLog_ccr_label_rated => 'Nominale';

  @override
  String get diveLog_ccr_label_remaining => 'Rimanente';

  @override
  String get diveLog_ccr_label_type => 'Tipo';

  @override
  String get diveLog_ccr_sectionDiluentGas => 'Gas diluente';

  @override
  String get diveLog_ccr_sectionScrubber => 'Scrubber';

  @override
  String get diveLog_ccr_sectionSetpoints => 'Setpoint (bar)';

  @override
  String get diveLog_ccr_title => 'Impostazioni CCR';

  @override
  String diveLog_collapsible_semantics_collapse(Object title) {
    return 'Comprimi sezione $title';
  }

  @override
  String diveLog_collapsible_semantics_expand(Object title) {
    return 'Espandi sezione $title';
  }

  @override
  String get diveLog_combine_confirm => 'Unisci in un\'immersione';

  @override
  String get diveLog_combine_dataNote =>
      'I dettagli provengono dall\'immersione più vecchia, con gli spazi vuoti completati dalle immersioni successive. Le note vengono unite. Bombole, attrezzatura, compagni, tag e avvistamenti vengono tutti mantenuti.';

  @override
  String get diveLog_combine_error =>
      'Impossibile unire le immersioni. Non è stato modificato nulla.';

  @override
  String diveLog_combine_gapLabel(String duration) {
    return 'Intervallo di superficie: $duration';
  }

  @override
  String get diveLog_combine_longSurfaceWarning =>
      'Uno o più intervalli di superficie superano i 30 minuti. Potrebbero essere immersioni separate anziché un\'unica immersione continua.';

  @override
  String get diveLog_combine_mixedDivers =>
      'Le immersioni selezionate appartengono a subacquei diversi e non possono essere unite.';

  @override
  String get diveLog_combine_profilePreview => 'Profilo combinato';

  @override
  String diveLog_combine_previewIntro(int count) {
    return 'Queste $count immersioni verranno unite in un\'unica immersione continua. Gli intervalli tra loro diventeranno tempo in superficie.';
  }

  @override
  String diveLog_combine_resultSummary(
    String runtime,
    String maxDepth,
    String bottomTime,
  ) {
    return 'Risultato: $runtime totali, profondità massima $maxDepth, tempo di fondo $bottomTime';
  }

  @override
  String diveLog_combine_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni unite',
      one: 'immersione unita',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_combine_title => 'Unisci immersioni';

  @override
  String get diveLog_combine_undoError => 'Impossibile annullare l\'unione.';

  @override
  String get diveLog_combine_undone => 'Unione annullata';

  @override
  String get diveLog_computerSource_badge_primary => 'Primario';

  @override
  String get diveLog_consolidate_confirm =>
      'Mantieni come un\'unica immersione con entrambi i computer';

  @override
  String get diveLog_consolidate_error_generic =>
      'Impossibile unire le immersioni. Non è stato modificato nulla.';

  @override
  String get diveLog_consolidate_error_notOverlapping =>
      'Queste immersioni non si sovrappongono nel tempo, quindi non possono essere unite come la stessa immersione.';

  @override
  String get diveLog_consolidate_error_sameComputer =>
      'Queste immersioni provengono dallo stesso computer subacqueo e non possono essere unite in questo modo.';

  @override
  String get diveLog_consolidate_selectPrimary =>
      'Computer subacqueo principale';

  @override
  String get diveLog_consolidate_snackbar =>
      'Immersione unita come computer aggiuntivo.';

  @override
  String get diveLog_consolidate_undoError =>
      'Impossibile annullare l\'unione.';

  @override
  String get diveLog_consolidate_undone => 'Unione annullata';

  @override
  String diveLog_mergeDialog_confirmSubtitle(String time) {
    return 'L\'immersione delle $time verrà unita a questa immersione.';
  }

  @override
  String get diveLog_mergeDialog_confirmTitle => 'Conferma unione';

  @override
  String get diveLog_mergeDialog_empty =>
      'Nessun\'altra immersione trovata in questo giorno.';

  @override
  String get diveLog_mergeDialog_explanation =>
      'Il profilo, le bombole, le pressioni, gli eventi, i tag, i compagni e gli avvistamenti di questa immersione verranno incorporati in questa immersione come fonte di un computer aggiuntivo. Questa azione può essere annullata con \'Scollega computer\'.';

  @override
  String diveLog_mergeDialog_loadError(String error) {
    return 'Errore durante il caricamento delle immersioni: $error';
  }

  @override
  String get diveLog_mergeDialog_merge => 'Unisci';

  @override
  String get diveLog_mergeDialog_next => 'Avanti';

  @override
  String get diveLog_mergeDialog_subtitle =>
      'Seleziona un\'immersione dello stesso giorno da unire come computer aggiuntivo.';

  @override
  String get diveLog_mergeDialog_title => 'Unisci a un\'altra immersione';

  @override
  String get diveLog_mergeDialog_whatThisDoes => 'Cosa fa questa azione';

  @override
  String get diveLog_computerSheet_description =>
      'Seleziona da quale profilo del computer modificare.';

  @override
  String get diveLog_computerSheet_title => 'Scegli profilo di partenza';

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return 'Media: $depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => 'Base';

  @override
  String get diveLog_cylinderSac_noSac => 'SAC: --';

  @override
  String get diveLog_cylinderSac_tooltip_aiData =>
      'Utilizzo dati trasmettitore AI per maggiore precisione';

  @override
  String get diveLog_cylinderSac_tooltip_basicData =>
      'Calcolato dalle pressioni iniziale/finale';

  @override
  String get diveLog_deco_badge_deco => 'DECO';

  @override
  String get diveLog_deco_badge_noDeco => 'NO DECO';

  @override
  String get diveLog_deco_label_ceiling => 'Ceiling';

  @override
  String get diveLog_deco_label_leading => 'Principale';

  @override
  String get diveLog_deco_label_gf99 => 'GF99';

  @override
  String get diveLog_deco_label_surfGf => 'SurfGF';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_time => 'Tempo';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String diveLog_deco_gf_chip(Object low, Object high) {
    return 'GF: $low/$high';
  }

  @override
  String diveLog_deco_gf_chipFromSettings(Object low, Object high) {
    return 'GF: $low/$high · le tue impostazioni';
  }

  @override
  String diveLog_deco_gf_chipRecordedAlgorithm(
    Object algorithm,
    Object low,
    Object high,
  ) {
    return '$algorithm · analizzata con GF $low/$high';
  }

  @override
  String diveLog_deco_gf_semantics(Object low, Object high) {
    return 'Fattori di gradiente: basso $low, alto $high';
  }

  @override
  String get diveLog_deco_gf_tooltipFromSettings =>
      'Questo computer subacqueo non ha registrato i suoi fattori di gradiente, quindi questa immersione viene analizzata con quelli delle tue impostazioni.';

  @override
  String diveLog_deco_gf_tooltipRecordedAlgorithm(Object algorithm) {
    return 'Questa immersione è stata calcolata con $algorithm, che non usa i fattori di gradiente. Submersion la analizza con quelli delle tue impostazioni.';
  }

  @override
  String get diveLog_deco_sectionDecoStops => 'Soste deco';

  @override
  String get diveLog_deco_sectionTissueLoading => 'Carico tissutale';

  @override
  String get diveLog_deco_semantics_notRequired =>
      'Decompressione non richiesta';

  @override
  String get diveLog_deco_semantics_required => 'Decompressione richiesta';

  @override
  String get diveLog_deco_tissueFast => 'Veloce';

  @override
  String get diveLog_deco_tissueSlow => 'Lento';

  @override
  String get diveLog_deco_title => 'Stato deco';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return 'Totale: $time';
  }

  @override
  String get diveLog_delete_cancel => 'Annulla';

  @override
  String get diveLog_delete_confirm =>
      'Questa azione non puo essere annullata. L\'immersione e tutti i dati associati (profilo, bombole, avvistamenti) saranno eliminati definitivamente.';

  @override
  String get diveLog_delete_delete => 'Elimina';

  @override
  String get diveLog_delete_title => 'Eliminare l\'immersione?';

  @override
  String get diveLog_detail_appBar => 'Dettagli immersione';

  @override
  String get diveLog_detail_badge_critical => 'CRITICO';

  @override
  String get diveLog_detail_badge_deco => 'DECO';

  @override
  String get diveLog_detail_badge_noDeco => 'NO DECO';

  @override
  String get diveLog_detail_badge_warning => 'ATTENZIONE';

  @override
  String diveLog_detail_buddyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'compagni',
      one: 'compagno',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_button_playback => 'Riproduzione';

  @override
  String get diveLog_detail_button_rangeAnalysis => 'Stats intervallo';

  @override
  String get diveLog_detail_button_showEnd => 'Mostra fine';

  @override
  String get diveLog_detail_captureSignature => 'Acquisisci firma istruttore';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return 'A $timestamp';
  }

  @override
  String diveLog_detail_collapsed_atTimeInfo(
    Object timestamp,
    Object baseInfo,
  ) {
    return 'A $timestamp • $baseInfo';
  }

  @override
  String diveLog_detail_collapsed_ceiling(Object value) {
    return 'Tetto: $value';
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
    return 'CNS: $cns • Max ppO₂: $maxPpO2 • A $timestamp: $ppO2 bar';
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
      other: 'elementi',
      one: 'elemento',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_errorLoading =>
      'Errore nel caricamento dell\'immersione';

  @override
  String get diveLog_detail_label_airTemp => 'Temp. aria';

  @override
  String get diveLog_detail_label_avgDepth => 'Profondita media';

  @override
  String get diveLog_detail_label_buddy => 'Compagno';

  @override
  String get diveLog_detail_label_currentDirection => 'Direzione corrente';

  @override
  String get diveLog_detail_label_currentStrength => 'Intensita corrente';

  @override
  String get diveLog_detail_label_diveComputer => 'Computer subacqueo';

  @override
  String get diveLog_detail_label_serialNumber => 'Numero di serie';

  @override
  String get diveLog_detail_label_firmwareVersion => 'Versione firmware';

  @override
  String get diveLog_detail_label_diveMaster => 'Divemaster';

  @override
  String get diveLog_detail_label_diveType => 'Tipo di immersione';

  @override
  String get diveLog_detail_label_elevation => 'Altitudine';

  @override
  String get diveLog_detail_label_entry => 'Ingresso:';

  @override
  String get diveLog_detail_label_entryMethod => 'Metodo di ingresso';

  @override
  String get diveLog_detail_label_exit => 'Uscita:';

  @override
  String get diveLog_detail_label_exitMethod => 'Metodo di uscita';

  @override
  String get diveLog_detail_label_gradientFactors => 'Fattori di gradiente';

  @override
  String get diveLog_detail_label_height => 'Altezza';

  @override
  String get diveLog_detail_label_highTide => 'Alta marea';

  @override
  String get diveLog_detail_label_lowTide => 'Bassa marea';

  @override
  String get diveLog_detail_label_ppO2AtPoint => 'ppO2 al punto selezionato:';

  @override
  String get diveLog_detail_label_rateOfChange => 'Tasso di variazione';

  @override
  String get diveLog_detail_label_sacRate => 'Consumo SAC';

  @override
  String get diveLog_detail_label_state => 'Stato';

  @override
  String get diveLog_detail_label_surfaceInterval => 'Intervallo di superficie';

  @override
  String get diveLog_detail_label_surfacePressure => 'Pressione di superficie';

  @override
  String get diveLog_detail_label_swellHeight => 'Altezza onde';

  @override
  String get diveLog_detail_label_total => 'Totale:';

  @override
  String get diveLog_detail_label_visibility => 'Visibilita';

  @override
  String get diveLog_detail_label_waterType => 'Tipo di acqua';

  @override
  String get diveLog_detail_menu_delete => 'Elimina';

  @override
  String get diveLog_detail_menu_export => 'Esporta';

  @override
  String get diveLog_detail_menu_openFullPage => 'Apri pagina intera';

  @override
  String get diveLog_detail_noNotes => 'Nessuna nota per questa immersione.';

  @override
  String get diveLog_detail_notFound => 'Immersione non trovata';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count punti';
  }

  @override
  String get diveLog_detail_section_altitudeDive => 'Immersione in quota';

  @override
  String get diveLog_detail_section_buddies => 'Compagni';

  @override
  String get diveLog_detail_section_conditions => 'Condizioni';

  @override
  String get diveLog_detail_section_customFields => 'Custom Fields';

  @override
  String get diveLog_detail_section_decoStatus => 'Stato deco';

  @override
  String get diveLog_detail_section_details => 'Dettagli';

  @override
  String get diveLog_detail_section_diveProfile => 'Profilo immersione';

  @override
  String get diveLog_detail_section_equipment => 'Attrezzatura';

  @override
  String get diveLog_detail_section_marineLife => 'Vita marina';

  @override
  String get diveLog_detail_section_notes => 'Note';

  @override
  String get diveLog_detail_section_oxygenToxicity =>
      'Tossicita dell\'ossigeno';

  @override
  String get diveLog_detail_section_sacRateBySegment =>
      'Consumo SAC per segmento';

  @override
  String get diveLog_detail_section_tags => 'Tag';

  @override
  String get diveLog_detail_section_cylinders => 'Bombole';

  @override
  String get diveLog_detail_section_tide => 'Marea';

  @override
  String get diveLog_detail_section_trainingSignature => 'Firma addestramento';

  @override
  String get diveLog_detail_section_weight => 'Zavorra';

  @override
  String get diveLog_detail_signatureDescription =>
      'Tocca per aggiungere la verifica dell\'istruttore per questa immersione di addestramento';

  @override
  String get diveLog_detail_soloDive =>
      'Immersione in solitaria o nessun compagno registrato';

  @override
  String diveLog_detail_speciesCount(Object count) {
    return '$count specie';
  }

  @override
  String get diveLog_detail_stat_bottomTime => 'Tempo di fondo';

  @override
  String get diveLog_detail_stat_maxDepth => 'Profondita massima';

  @override
  String get diveLog_detail_stat_runtime => 'Tempo totale';

  @override
  String get diveLog_detail_stat_waterTemp => 'Temp. acqua';

  @override
  String diveLog_detail_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tag',
      one: 'tag',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_tideCalculated => 'Calcolato dal modello di marea';

  @override
  String get diveLog_detail_tooltip_addToFavorites => 'Aggiungi ai preferiti';

  @override
  String get diveLog_detail_tooltip_edit => 'Modifica';

  @override
  String get diveLog_detail_tooltip_editDive => 'Modifica immersione';

  @override
  String get diveLog_detail_tooltip_previousDive => 'Previous dive';

  @override
  String get diveLog_detail_tooltip_nextDive => 'Next dive';

  @override
  String get diveLog_detail_tooltip_exportProfileImage =>
      'Esporta profilo come immagine';

  @override
  String get diveLog_detail_tooltip_removeFromFavorites =>
      'Rimuovi dai preferiti';

  @override
  String get diveLog_detail_tooltip_viewFullscreen =>
      'Visualizza a schermo intero';

  @override
  String get diveLog_detail_viewSite => 'Visualizza sito';

  @override
  String get diveLog_diveMode_ccrDescription =>
      'Rebreather a circuito chiuso con ppO2 costante';

  @override
  String get diveLog_diveMode_gaugeDescription =>
      'Solo profondità e tempo; nessun tracciamento di gas o decompressione';

  @override
  String get diveLog_diveMode_ocDescription =>
      'Scuba standard a circuito aperto con bombole';

  @override
  String get diveLog_diveMode_scrDescription =>
      'Rebreather semi-chiuso con ppO2 variabile';

  @override
  String get diveLog_diveMode_title => 'Modalita immersione';

  @override
  String get diveLog_editSighting_count => 'Quantita';

  @override
  String get diveLog_editSighting_notes => 'Note';

  @override
  String get diveLog_editSighting_notesHint =>
      'Dimensione, comportamento, posizione...';

  @override
  String get diveLog_editSighting_remove => 'Rimuovi';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return 'Rimuovere $name da questa immersione?';
  }

  @override
  String get diveLog_editSighting_removeTitle => 'Rimuovere avvistamento?';

  @override
  String get diveLog_editSighting_save => 'Salva modifiche';

  @override
  String get diveLog_edit_add => 'Aggiungi';

  @override
  String get diveLog_edit_addCustomField => 'Add Field';

  @override
  String get diveLog_edit_addTank => 'Aggiungi bombola';

  @override
  String get diveLog_edit_addWeightEntry => 'Aggiungi voce zavorra';

  @override
  String diveLog_edit_addedGps(Object name) {
    return 'GPS aggiunto a $name';
  }

  @override
  String get diveLog_edit_appBarEdit => 'Modifica immersione';

  @override
  String get diveLog_edit_appBarNew => 'Registra immersione';

  @override
  String get diveLog_edit_cancel => 'Annulla';

  @override
  String get diveLog_edit_clearAllEquipment => 'Rimuovi tutto';

  @override
  String diveLog_edit_createdSite(Object name) {
    return 'Sito creato: $name';
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
    return 'Durata: $minutes min';
  }

  @override
  String get diveLog_edit_equipmentHint =>
      'Tocca \"Usa set\" o \"Aggiungi\" per selezionare l\'attrezzatura';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return 'Errore nel caricamento dei tipi di immersione: $error';
  }

  @override
  String get diveLog_edit_gettingLocation => 'Acquisizione posizione...';

  @override
  String get diveLog_edit_group_buddies => 'Compagni';

  @override
  String get diveLog_edit_group_conditions => 'Condizioni';

  @override
  String get diveLog_edit_group_experience => 'Esperienza';

  @override
  String get diveLog_edit_group_gasGear => 'Gas e attrezzatura';

  @override
  String get diveLog_edit_group_theDive => 'L\'immersione';

  @override
  String get diveLog_edit_group_trip => 'Viaggio';

  @override
  String get diveLog_edit_headerNew => 'Registra nuova immersione';

  @override
  String get diveLog_edit_invite_buddies => 'Aggiungi compagni';

  @override
  String get diveLog_edit_invite_conditions =>
      'Aggiungi condizioni: acqua, visibilità, meteo';

  @override
  String get diveLog_edit_invite_experience =>
      'Aggiungi valutazione, avvistamenti, note o tag';

  @override
  String get diveLog_edit_invite_gasGear =>
      'Aggiungi gas e attrezzatura: modalità, bombole, attrezzatura, zavorra';

  @override
  String get diveLog_edit_invite_trip => 'Aggiungi viaggio o diving center';

  @override
  String get diveLog_edit_label_airTemp => 'Temp. aria';

  @override
  String get diveLog_edit_label_altitude => 'Altitudine';

  @override
  String get diveLog_edit_label_avgDepth => 'Profondita media';

  @override
  String get diveLog_edit_label_bottomTime => 'Tempo di fondo';

  @override
  String get diveLog_edit_label_currentDirection => 'Direzione corrente';

  @override
  String get diveLog_edit_label_currentStrength => 'Intensita corrente';

  @override
  String get diveLog_edit_label_diveType => 'Tipo di immersione';

  @override
  String get diveLog_edit_label_diveTypes => 'Tipi di immersione';

  @override
  String get diveLog_edit_label_diveNumber => 'N. immersione';

  @override
  String get diveLog_edit_label_diveName => 'Nome';

  @override
  String get diveLog_edit_diveNamePlaceholder =>
      'Nome facoltativo per questa immersione';

  @override
  String get diveLog_edit_hint_diveNumber =>
      'Assegnato automaticamente se lasciato vuoto';

  @override
  String get diveLog_edit_label_entryMethod => 'Metodo di ingresso';

  @override
  String get diveLog_edit_label_exitMethod => 'Metodo di uscita';

  @override
  String get diveLog_edit_label_maxDepth => 'Profondita massima';

  @override
  String get diveLog_edit_label_runtime => 'Tempo totale';

  @override
  String get diveLog_edit_label_surfacePressure => 'Pressione di superficie';

  @override
  String get diveLog_edit_label_swellHeight => 'Altezza onde';

  @override
  String get diveLog_edit_label_type => 'Tipo';

  @override
  String get diveLog_edit_label_visibility => 'Visibilita';

  @override
  String get diveLog_edit_label_waterTemp => 'Temp. acqua';

  @override
  String get diveLog_edit_label_waterType => 'Tipo di acqua';

  @override
  String get diveLog_edit_marineLifeHint =>
      'Tocca \"Aggiungi\" per registrare gli avvistamenti';

  @override
  String get diveLog_edit_nearbySitesFirst => 'Prima i siti piu vicini';

  @override
  String get diveLog_edit_noEquipmentSelected =>
      'Nessuna attrezzatura selezionata';

  @override
  String get diveLog_edit_noMarineLife => 'Nessuna vita marina registrata';

  @override
  String get diveLog_edit_notSpecified => 'Non specificato';

  @override
  String get diveLog_edit_notesHint => 'Aggiungi note su questa immersione...';

  @override
  String get diveLog_edit_overline_tanks => 'Bombole';

  @override
  String get diveLog_edit_profile_draw => 'Disegna un profilo';

  @override
  String get diveLog_edit_profile_none => 'Non registrato';

  @override
  String diveLog_edit_profile_outliers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count possibili valori anomali rilevati',
      one: '1 possibile valore anomalo rilevato',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_profile_points(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punti',
      one: '1 punto',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_row_addSite => 'Aggiungi sito';

  @override
  String get diveLog_edit_row_diveCenter => 'Diving center';

  @override
  String get diveLog_edit_row_diveProfile => 'Profilo di immersione';

  @override
  String get diveLog_edit_row_entry => 'Entrata';

  @override
  String get diveLog_edit_row_exit => 'Uscita';

  @override
  String get diveLog_edit_row_notSet => 'Non impostato';

  @override
  String get diveLog_edit_row_site => 'Sito';

  @override
  String get diveLog_edit_row_surfaceInterval => 'Intervallo di superficie';

  @override
  String get diveLog_edit_row_trip => 'Viaggio';

  @override
  String get diveLog_edit_save => 'Salva';

  @override
  String get diveLog_edit_saveAsSet => 'Salva come set';

  @override
  String diveLog_edit_saveAsSetDialog_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'elementi',
      one: 'elemento',
    );
    return 'Salva $count $_temp0 come nuovo set di attrezzatura.';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description =>
      'Descrizione (opzionale)';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint =>
      'es. Attrezzatura leggera per acque calde';

  @override
  String diveLog_edit_saveAsSetDialog_error(Object error) {
    return 'Errore nella creazione del set: $error';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_setName => 'Nome del set';

  @override
  String get diveLog_edit_saveAsSetDialog_setNameHint =>
      'es. Immersione tropicale';

  @override
  String diveLog_edit_saveAsSetDialog_success(Object name) {
    return 'Set di attrezzatura \"$name\" creato';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title =>
      'Salva come set di attrezzatura';

  @override
  String get diveLog_edit_saveAsSetDialog_validation =>
      'Inserisci un nome per il set';

  @override
  String get diveLog_edit_section_conditions => 'Condizioni';

  @override
  String get diveLog_edit_section_customFields => 'Custom Fields';

  @override
  String get diveLog_edit_section_depthDuration => 'Profondita e durata';

  @override
  String get diveLog_edit_section_diveCenter => 'Centro immersioni';

  @override
  String get diveLog_edit_section_diveSite => 'Sito di immersione';

  @override
  String get diveLog_edit_section_entryTime => 'Ora di ingresso';

  @override
  String get diveLog_edit_section_equipment => 'Attrezzatura';

  @override
  String get diveLog_edit_section_exitTime => 'Ora di uscita';

  @override
  String get diveLog_edit_section_marineLife => 'Vita marina';

  @override
  String get diveLog_edit_section_notes => 'Note';

  @override
  String get diveLog_edit_section_rating => 'Valutazione';

  @override
  String get diveLog_edit_section_tags => 'Tag';

  @override
  String diveLog_edit_section_tanks(Object count) {
    return 'Bombole ($count)';
  }

  @override
  String get diveLog_edit_section_trainingCourse => 'Corso di addestramento';

  @override
  String get diveLog_edit_section_trip => 'Viaggio';

  @override
  String get diveLog_edit_section_weight => 'Zavorra';

  @override
  String get diveLog_edit_select => 'Seleziona';

  @override
  String get diveLog_edit_selectDiveCenter => 'Seleziona centro immersioni';

  @override
  String get diveLog_edit_selectDiveSite => 'Seleziona sito di immersione';

  @override
  String get diveLog_edit_selectTrip => 'Seleziona viaggio';

  @override
  String diveLog_edit_snackbar_avgDepthCalculated(Object depth) {
    return 'Profondita media calcolata: $depth';
  }

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Tempo di fondo calcolato: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Errore nel salvataggio dell\'immersione: $error';
  }

  @override
  String diveLog_edit_snackbar_maxDepthCalculated(Object depth) {
    return 'Profondita max calcolata: $depth';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'Nessun dato del profilo immersione disponibile';

  @override
  String diveLog_edit_snackbar_runtimeCalculated(Object minutes) {
    return 'Durata calcolata: $minutes min';
  }

  @override
  String get diveLog_edit_snackbar_unableToCalculateAvgDepth =>
      'Impossibile calcolare la profondita media dal profilo';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Impossibile calcolare il tempo di fondo dal profilo';

  @override
  String get diveLog_edit_snackbar_unableToCalculateMaxDepth =>
      'Impossibile calcolare la profondita max dal profilo';

  @override
  String get diveLog_edit_snackbar_unableToCalculateRuntime =>
      'Impossibile calcolare la durata dal profilo';

  @override
  String diveLog_edit_summary_items(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_summary_notes => 'note';

  @override
  String diveLog_edit_summary_species(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count specie',
      one: '1 specie',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_summary_tanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bombole',
      one: '1 bombola',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return 'Intervallo di superficie: $interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint =>
      'Standard: 1013 mbar al livello del mare';

  @override
  String get diveLog_edit_tankCard_done => 'Fine';

  @override
  String get diveLog_edit_tankCard_edit => 'Modifica';

  @override
  String get diveLog_edit_tankCard_mix => 'Miscela';

  @override
  String get diveLog_edit_tankCard_pressure => 'Pressione';

  @override
  String diveLog_edit_tankCard_title(int number) {
    return 'Bombola $number';
  }

  @override
  String get diveLog_edit_tankCard_volume => 'Volume';

  @override
  String get diveLog_edit_tooltip_calculateFromProfile =>
      'Calcola dal profilo immersione';

  @override
  String get diveLog_edit_tooltip_clearDiveCenter =>
      'Cancella centro immersioni';

  @override
  String get diveLog_edit_tooltip_clearSite => 'Cancella sito';

  @override
  String get diveLog_edit_tooltip_clearTrip => 'Cancella viaggio';

  @override
  String get diveLog_edit_tooltip_removeEquipment => 'Rimuovi attrezzatura';

  @override
  String get diveLog_edit_tooltip_removeSighting => 'Rimuovi avvistamento';

  @override
  String get diveLog_edit_tooltip_removeWeight => 'Rimuovi';

  @override
  String get diveLog_edit_trainingCourseHint =>
      'Collega questa immersione a un corso di addestramento';

  @override
  String diveLog_edit_tripSuggested(Object name) {
    return 'Suggerito: $name';
  }

  @override
  String get diveLog_edit_tripUse => 'Usa';

  @override
  String get diveLog_edit_useSet => 'Usa set';

  @override
  String diveLog_edit_weightTotal(Object total) {
    return 'Totale: $total';
  }

  @override
  String get diveLog_emptyFiltered_clearFilters => 'Cancella filtri';

  @override
  String get diveLog_emptyFiltered_subtitle =>
      'Prova a modificare o cancellare i filtri';

  @override
  String get diveLog_emptyFiltered_title =>
      'Nessuna immersione corrisponde ai filtri';

  @override
  String get diveLog_empty_logFirstDive => 'Registra la tua prima immersione';

  @override
  String get diveLog_empty_subtitle =>
      'Tocca il pulsante qui sotto per registrare la tua prima immersione';

  @override
  String get diveLog_empty_title => 'Nessuna immersione registrata';

  @override
  String get diveLog_equipmentPicker_addFromTab =>
      'Aggiungi attrezzatura dalla scheda Attrezzatura';

  @override
  String get diveLog_equipmentPicker_allSelected =>
      'Tutta l\'attrezzatura gia selezionata';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return 'Errore nel caricamento dell\'attrezzatura: $error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => 'Nessuna attrezzatura';

  @override
  String get diveLog_equipmentPicker_removeToAdd =>
      'Rimuovi elementi per aggiungerne altri';

  @override
  String get diveLog_equipmentPicker_title => 'Aggiungi attrezzatura';

  @override
  String get diveLog_equipmentSetPicker_createHint =>
      'Crea set in Attrezzatura > Set';

  @override
  String get diveLog_equipmentSetPicker_emptySet => 'Set vuoto';

  @override
  String get diveLog_equipmentSetPicker_errorItems =>
      'Errore nel caricamento degli elementi';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return 'Errore nel caricamento dei set di attrezzatura: $error';
  }

  @override
  String diveLog_equipmentSetPicker_itemsSummary(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '1 elemento',
    );
    return '$_temp0: $names';
  }

  @override
  String get diveLog_equipmentSetPicker_loading => 'Caricamento...';

  @override
  String get diveLog_equipmentSetPicker_noSets => 'Nessun set di attrezzatura';

  @override
  String get diveLog_equipmentSetPicker_title => 'Usa set di attrezzatura';

  @override
  String get diveLog_error_loadingDives =>
      'Errore nel caricamento delle immersioni';

  @override
  String get diveLog_error_retry => 'Riprova';

  @override
  String get diveLog_exportImage_captureFailed =>
      'Impossibile acquisire l\'immagine';

  @override
  String get diveLog_exportImage_generateFailed =>
      'Impossibile generare l\'immagine';

  @override
  String get diveLog_exportImage_generatingPdf => 'Generazione PDF...';

  @override
  String get diveLog_exportImage_pdfSaved => 'PDF salvato';

  @override
  String get diveLog_exportImage_saveToFiles => 'Salva nei file';

  @override
  String get diveLog_exportImage_saveToFilesDescription =>
      'Scegli una posizione per salvare il file';

  @override
  String get diveLog_exportImage_saveToPhotos => 'Salva nelle foto';

  @override
  String get diveLog_exportImage_saveToPhotosDescription =>
      'Salva l\'immagine nella libreria foto';

  @override
  String get diveLog_exportImage_savedToFiles => 'Immagine salvata';

  @override
  String get diveLog_exportImage_savedToPhotos => 'Immagine salvata nelle foto';

  @override
  String get diveLog_exportImage_share => 'Condividi';

  @override
  String get diveLog_exportImage_shareDescription =>
      'Condividi tramite altre app';

  @override
  String get diveLog_exportImage_titleDetails =>
      'Esporta immagine dettagli immersione';

  @override
  String get diveLog_exportImage_titlePdf => 'Esporta PDF';

  @override
  String get diveLog_exportImage_titleProfile => 'Esporta immagine profilo';

  @override
  String get diveLog_export_csv => 'CSV';

  @override
  String get diveLog_export_csvDescription => 'Formato foglio di calcolo';

  @override
  String get diveLog_export_exporting => 'Esportazione...';

  @override
  String diveLog_export_failed(Object error) {
    return 'Esportazione fallita: $error';
  }

  @override
  String get diveLog_export_pageAsImage => 'Pagina come immagine';

  @override
  String get diveLog_export_pageAsImageDescription =>
      'Screenshot dell\'intera pagina dettagli immersione';

  @override
  String get diveLog_export_pdfDescription =>
      'Pagina stampabile del diario immersioni';

  @override
  String get diveLog_export_pdfLogbookEntry => 'Voce logbook PDF';

  @override
  String get diveLog_export_success => 'Immersione esportata con successo';

  @override
  String diveLog_export_titleDiveNumber(Object number) {
    return 'Esporta immersione #$number';
  }

  @override
  String get diveLog_export_uddf => 'UDDF';

  @override
  String get diveLog_export_uddfDescription => 'Universal Dive Data Format';

  @override
  String get diveLog_filterChip_clearAll => 'Cancella tutto';

  @override
  String get diveLog_filterChip_favorites => 'Preferiti';

  @override
  String diveLog_filterChip_from(Object date) {
    return 'Da $date';
  }

  @override
  String get diveLog_filterChip_noBuddy => 'Senza compagno';

  @override
  String diveLog_filterChip_until(Object date) {
    return 'Fino al $date';
  }

  @override
  String get diveLog_filter_allSites => 'Tutti i siti';

  @override
  String get diveLog_filter_allTypes => 'Tutti i tipi';

  @override
  String get diveLog_filter_apply => 'Applica filtri';

  @override
  String get diveLog_filter_buddyHint => 'Cerca per nome compagno';

  @override
  String get diveLog_filter_buddyName => 'Nome compagno';

  @override
  String get diveLog_filter_clearAll => 'Cancella tutto';

  @override
  String get diveLog_filter_clearDates => 'Cancella date';

  @override
  String get diveLog_filter_clearRating => 'Cancella filtro valutazione';

  @override
  String get diveLog_filter_clearWeekdays => 'Cancella giorni della settimana';

  @override
  String get diveLog_filter_dateSeparator => 'a';

  @override
  String get diveLog_filter_endDate => 'Data di fine';

  @override
  String get diveLog_filter_errorLoadingSites =>
      'Errore nel caricamento dei siti';

  @override
  String get diveLog_filter_errorLoadingTags =>
      'Errore nel caricamento dei tag';

  @override
  String get diveLog_filter_favoritesOnly => 'Solo preferiti';

  @override
  String get diveLog_filter_gasAir => 'Aria (21%)';

  @override
  String get diveLog_filter_gasAll => 'Tutti';

  @override
  String get diveLog_filter_gasNitrox => 'Nitrox (>21%)';

  @override
  String get diveLog_filter_max => 'Max';

  @override
  String get diveLog_filter_min => 'Min';

  @override
  String get diveLog_filter_noBuddyOnly => 'Nessun compagno assegnato';

  @override
  String get diveLog_filter_noTagsYet => 'Nessun tag creato';

  @override
  String get diveLog_filter_presetAllTime => 'Tutto il periodo';

  @override
  String get diveLog_filter_presetLast12Months => 'Ultimi 12 mesi';

  @override
  String get diveLog_filter_presetLastYear => 'Anno scorso';

  @override
  String get diveLog_filter_presetThisYear => 'Quest\'anno';

  @override
  String get diveLog_filter_sectionBuddy => 'Compagno';

  @override
  String get diveLog_filter_sectionDateRange => 'Intervallo date';

  @override
  String get diveLog_filter_sectionDepthRange =>
      'Intervallo profondita (metri)';

  @override
  String get diveLog_filter_sectionDiveSite => 'Sito di immersione';

  @override
  String get diveLog_filter_sectionDiveType => 'Tipo di immersione';

  @override
  String get diveLog_filter_sectionDuration => 'Durata (minuti)';

  @override
  String get diveLog_filter_sectionGasMix => 'Miscela gas (O2%)';

  @override
  String get diveLog_filter_sectionMinRating => 'Valutazione minima';

  @override
  String get diveLog_filter_sectionTags => 'Tag';

  @override
  String get diveLog_filter_sectionWeekdays => 'Giorni della settimana';

  @override
  String get diveLog_filter_showOnlyFavorites =>
      'Mostra solo le immersioni preferite';

  @override
  String get diveLog_filter_showOnlyNoBuddy =>
      'Mostra solo le immersioni senza compagno';

  @override
  String get diveLog_filter_startDate => 'Data di inizio';

  @override
  String get diveLog_filter_title => 'Filtra immersioni';

  @override
  String get diveLog_filter_resizeGrip => 'Ridimensiona il pannello dei filtri';

  @override
  String get diveLog_filter_tooltip_close => 'Chiudi filtro';

  @override
  String get diveLog_fullscreenProfile_close => 'Chiudi schermo intero';

  @override
  String get diveLog_fullscreenProfile_readoutHint =>
      'Passa il cursore o scorri sul profilo';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Profilo immersione #$number';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Velocita di risalita';

  @override
  String get diveLog_legend_label_ascentRateLine =>
      'Linea velocita di risalita';

  @override
  String get diveLog_legend_label_ceiling => 'Ceiling';

  @override
  String get diveLog_legend_label_decoStops => 'Deco stops';

  @override
  String get diveLog_legend_label_cns => 'CNS%';

  @override
  String get diveLog_legend_label_depth => 'Profondita';

  @override
  String get diveLog_legend_label_events => 'Eventi';

  @override
  String get diveLog_legend_label_gasDensity => 'Densita del gas';

  @override
  String get diveLog_legend_label_gasSwitches => 'Cambi gas';

  @override
  String get diveLog_legend_label_gfPercent => 'GF%';

  @override
  String get diveLog_legend_label_heartRate => 'Frequenza cardiaca';

  @override
  String get diveLog_legend_label_maxDepth => 'Profondita massima';

  @override
  String get diveLog_legend_label_meanDepth => 'Profondita media';

  @override
  String get diveLog_legend_label_mod => 'MOD';

  @override
  String get diveLog_legend_label_ndl => 'NDL';

  @override
  String get diveLog_legend_label_otu => 'OTU';

  @override
  String get diveLog_legend_label_photoMarkers => 'Foto';

  @override
  String get diveLog_legend_label_ppHe => 'ppHe';

  @override
  String get diveLog_legend_label_ppN2 => 'ppN2';

  @override
  String get diveLog_legend_label_ppO2 => 'ppO2';

  @override
  String get diveLog_legend_label_pressure => 'Pressione';

  @override
  String get diveLog_legend_label_pressureThresholds => 'Soglie di pressione';

  @override
  String get diveLog_legend_label_sacRate => 'Consumo SAC';

  @override
  String get diveLog_legend_label_showGas => 'Gas';

  @override
  String get diveLog_legend_label_surfaceGf => 'GF superficie';

  @override
  String get diveLog_legend_label_temp => 'Temp';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_legend_source_dc => 'DC';

  @override
  String get diveLog_legend_source_calc => 'Calc.';

  @override
  String get diveLog_chartSection_overlays => 'Sovrapposizioni';

  @override
  String get diveLog_chartSection_markers => 'Marcatori';

  @override
  String get diveLog_chartSection_decompression => 'Decompressione';

  @override
  String get diveLog_chartSection_gasAnalysis => 'Analisi dei gas';

  @override
  String get diveLog_chartSection_display => 'Visualizzazione';

  @override
  String get diveLog_chartSection_other => 'Altro';

  @override
  String get diveLog_chartSection_tankPressures => 'Pressioni delle bombole';

  @override
  String get diveLog_chartOption_metricsFollowViewport =>
      'Mantieni le sovrapposizioni in vista';

  @override
  String get diveLog_pressure_estimatedSuffix => '(stim.)';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Mappa immersioni';

  @override
  String get diveLog_listPage_compactTitle => 'Immersioni';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Errore: $error';
  }

  @override
  String get diveLog_listPage_bottomSheet_importFromComputer =>
      'Importa dal computer subacqueo';

  @override
  String get diveLog_listPage_bottomSheet_scanPaperLog =>
      'Scansiona logbook cartaceo';

  @override
  String get ocrImport_scanPage_processing => 'Lettura della pagina...';

  @override
  String get ocrImport_scanPage_pickPhoto => 'Scegli foto';

  @override
  String get ocrImport_scanPage_takePhoto => 'Scatta foto';

  @override
  String get ocrImport_scanPage_nothingRead =>
      'Non è stato possibile leggere molto da questa pagina - campi lasciati vuoti';

  @override
  String get ocrImport_scanPage_engineMissing =>
      'Il riconoscimento del testo non è disponibile. Installa Tesseract per scansionare i logbook cartacei (ad esempio: sudo apt install tesseract-ocr).';

  @override
  String get ocrImport_editPage_photoAttachFailed =>
      'L\'immersione è stata salvata, ma non è stato possibile allegare la pagina scansionata';

  @override
  String get diveLog_listPage_bottomSheet_logManually =>
      'Registra immersione manualmente';

  @override
  String get diveLog_listPage_fab_addDive => 'Aggiungi immersione';

  @override
  String get diveLog_listPage_fab_logDive => 'Registra immersione';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Ricerca avanzata';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Numerazione immersioni';

  @override
  String get diveLog_listPage_menuMatchSites => 'Associa le immersioni ai siti';

  @override
  String get diveLog_sighting_decreaseCount => 'Diminuisci conteggio';

  @override
  String get diveLog_sighting_increaseCount => 'Aumenta conteggio';

  @override
  String diveLog_speciesPicker_errorLoading(String error) {
    return 'Errore nel caricamento delle specie: $error';
  }

  @override
  String get diveRole_builtin_buddy => 'Compagno';

  @override
  String get diveRole_builtin_diveGuide => 'Guida subacquea';

  @override
  String get diveRole_builtin_diveMaster => 'Divemaster';

  @override
  String get diveRole_builtin_instructor => 'Istruttore';

  @override
  String get diveRole_builtin_rearGuard => 'Chiudifila';

  @override
  String get diveRole_builtin_safetyDiver => 'Subacqueo di sicurezza';

  @override
  String get diveRole_builtin_solo => 'Solitario';

  @override
  String get diveRole_builtin_student => 'Allievo';

  @override
  String get diveRole_builtin_supportDiver => 'Subacqueo di supporto';

  @override
  String get diveRoles_addDialog_addButton => 'Aggiungi';

  @override
  String get diveRoles_addDialog_nameHint => 'es., Fotografo';

  @override
  String get diveRoles_addDialog_nameLabel => 'Nome Ruolo di Immersione';

  @override
  String get diveRoles_addDialog_nameValidation => 'Inserisci un nome';

  @override
  String get diveRoles_addDialog_title =>
      'Aggiungi Ruolo di Immersione Personalizzato';

  @override
  String get diveRoles_addTooltip => 'Aggiungi ruolo di immersione';

  @override
  String get diveRoles_appBar_title => 'Ruoli di Immersione';

  @override
  String get diveRoles_builtInHeader => 'Ruoli di Immersione Predefiniti';

  @override
  String get diveRoles_customHeader => 'Ruoli di Immersione Personalizzati';

  @override
  String diveRoles_deleteDialog_content(Object name) {
    return 'Sei sicuro di voler eliminare \"$name\"?';
  }

  @override
  String get diveRoles_deleteDialog_title => 'Eliminare Ruolo di Immersione?';

  @override
  String get diveRoles_deleteTooltip => 'Elimina ruolo di immersione';

  @override
  String get diveRoles_renameDialog_title => 'Rinomina Ruolo di Immersione';

  @override
  String get diveRoles_renameTooltip => 'Rinomina ruolo di immersione';

  @override
  String diveRoles_snackbar_added(Object name) {
    return 'Ruolo di immersione aggiunto: $name';
  }

  @override
  String diveRoles_snackbar_cannotDelete(Object name) {
    return 'Impossibile eliminare \"$name\" - è usato da immersioni esistenti';
  }

  @override
  String diveRoles_snackbar_deleted(Object name) {
    return 'Ruolo di immersione eliminato: $name';
  }

  @override
  String diveRoles_snackbar_errorAdding(Object error) {
    return 'Errore durante l\'aggiunta del ruolo di immersione: $error';
  }

  @override
  String get diveSites_edit_depth_heroMax => 'Prof. max';

  @override
  String get diveSites_edit_depth_heroMin => 'Prof. min';

  @override
  String get diveSites_edit_group_accessSafety => 'Accesso e sicurezza';

  @override
  String get diveSites_edit_group_diveInfo => 'Info immersione';

  @override
  String get diveSites_edit_group_identity => 'Identità';

  @override
  String get diveSites_edit_group_lifeNotes => 'Vita marina e note';

  @override
  String get diveSites_edit_group_location => 'Posizione';

  @override
  String get diveSites_edit_invite_accessSafety =>
      'Aggiungi accesso, parcheggio, ormeggio o pericoli';

  @override
  String get diveSites_edit_invite_diveInfo =>
      'Aggiungi profondità, difficoltà o valutazione';

  @override
  String get diveSites_edit_invite_lifeNotes =>
      'Aggiungi vita marina, note o condivisione';

  @override
  String get diveSites_edit_invite_location =>
      'Aggiungi posizione GPS o altitudine';

  @override
  String get diveSites_edit_summary_shared => 'condiviso';

  @override
  String get forms_addSection_prefix => 'Aggiungi:';

  @override
  String get forms_cancel => 'Annulla';

  @override
  String get forms_discard_body =>
      'Ci sono modifiche non salvate. Se esci ora andranno perse.';

  @override
  String get forms_discard_discard => 'Scarta';

  @override
  String get forms_discard_keepEditing => 'Continua a modificare';

  @override
  String get forms_discard_title => 'Scartare le modifiche?';

  @override
  String get forms_save => 'Salva';

  @override
  String forms_section_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemi',
      one: '1 problema',
    );
    return '$_temp0';
  }

  @override
  String get settings_manage_setupAssistant => 'Assistente di configurazione';

  @override
  String get settings_manage_setupAssistant_subtitle =>
      'Rivedi unità, aspetto e opzioni di backup';

  @override
  String get setup_backup_cloudCopy => 'Archivia i backup nel cloud';

  @override
  String get setup_backup_frequency => 'Frequenza';

  @override
  String get setup_backup_frequency_daily => 'Giornaliera';

  @override
  String get setup_backup_frequency_monthly => 'Mensile';

  @override
  String get setup_backup_frequency_weekly => 'Settimanale';

  @override
  String get setup_backup_scheduleSubtitle =>
      'Esegui il backup dei tuoi dati a intervalli regolari';

  @override
  String get setup_backup_scheduleToggle => 'Backup automatici';

  @override
  String get setup_backup_subtitle =>
      'Proteggi i tuoi dati fin dal primo giorno.';

  @override
  String get setup_backup_title => 'Backup e sincronizzazione';

  @override
  String get setup_common_back => 'Indietro';

  @override
  String get setup_common_next => 'Avanti';

  @override
  String get setup_common_skip => 'Salta';

  @override
  String get setup_existing_folder_subtitle =>
      'Indica a Submersion una cartella che contiene già una libreria';

  @override
  String get setup_existing_folder_title => 'Apri una cartella esistente';

  @override
  String get setup_existing_restore_subtitle =>
      'Scegli un file di backup esportato da Submersion';

  @override
  String get setup_existing_restore_title => 'Ripristina un file di backup';

  @override
  String get setup_existing_subtitle =>
      'Scegli come caricare la tua libreria Submersion esistente';

  @override
  String get setup_existing_sync_subtitle =>
      'Scarica la tua libreria da iCloud, Dropbox o S3';

  @override
  String get setup_existing_sync_title => 'Collega la sincronizzazione cloud';

  @override
  String get setup_existing_title => 'Porta i tuoi dati';

  @override
  String get setup_finish_applying => 'Configurazione...';

  @override
  String setup_finish_error(Object error) {
    return 'Impossibile completare la configurazione: $error';
  }

  @override
  String get setup_finish_feature_diveComputer =>
      'Scarica le immersioni dal tuo computer subacqueo';

  @override
  String get setup_finish_feature_gear =>
      'Tieni traccia dell\'attrezzatura e delle scadenze di manutenzione';

  @override
  String get setup_finish_feature_import =>
      'Importa registri da file e altre app';

  @override
  String get setup_finish_feature_sites =>
      'Visualizza i tuoi punti di immersione sulla mappa';

  @override
  String get setup_finish_feature_statistics =>
      'Esplora le statistiche delle tue immersioni';

  @override
  String get setup_finish_start => 'Inizia';

  @override
  String get setup_finish_subtitle => 'Submersion può anche...';

  @override
  String get setup_finish_title => 'Tutto pronto';

  @override
  String get setup_folder_notFound_message =>
      'La cartella selezionata non contiene un database Submersion.';

  @override
  String get setup_folder_notFound_title =>
      'Nessuna libreria in quella cartella';

  @override
  String get setup_folder_pick => 'Scegli cartella';

  @override
  String get setup_folder_switching => 'Apertura della libreria...';

  @override
  String get setup_folder_title => 'Apri cartella esistente';

  @override
  String get setup_profile_nameHint => 'Inserisci il tuo nome';

  @override
  String get setup_profile_nameLabel => 'Il Tuo Nome';

  @override
  String get setup_profile_nameValidation => 'Inserisci il tuo nome';

  @override
  String get setup_profile_subtitle =>
      'Inserisci il tuo nome per iniziare. Potrai aggiungere altri dettagli in seguito.';

  @override
  String get setup_profile_title => 'Crea il Tuo Profilo';

  @override
  String get setup_restore_inProgress => 'Ripristino...';

  @override
  String get setup_restore_pick => 'Scegli file di backup';

  @override
  String get setup_restore_title => 'Ripristina backup';

  @override
  String get setup_step_backup => 'Backup';

  @override
  String get setup_step_finish => 'Fine';

  @override
  String get setup_step_profile => 'Profilo';

  @override
  String get setup_step_units => 'Unità';

  @override
  String get setup_syncPull_continue => 'Continua';

  @override
  String get setup_syncPull_incomplete_message =>
      'Questo account contiene una libreria Submersion il cui caricamento non è mai stato completato. Lascia che l\'altro dispositivo finisca la sincronizzazione, poi riprova.';

  @override
  String get setup_syncPull_incomplete_retry => 'Controlla di nuovo';

  @override
  String get setup_syncPull_incomplete_title =>
      'Caricamento della libreria incompleto';

  @override
  String get setup_syncPull_locked_message =>
      'Inserisci la passphrase di crittografia per sbloccare questa libreria e scaricarla su questo dispositivo.';

  @override
  String get setup_syncPull_locked_title => 'Questa libreria è crittografata';

  @override
  String get setup_syncPull_noLibrary_message =>
      'Nessuna libreria Submersion trovata su questo account. Iniziare da zero? La connessione verrà mantenuta.';

  @override
  String get setup_syncPull_noLibrary_title => 'Nessuna libreria trovata';

  @override
  String get setup_syncPull_success => 'Libreria adottata';

  @override
  String get setup_syncPull_syncing => 'Download della libreria...';

  @override
  String get setup_syncPull_title => 'Connetti e scarica';

  @override
  String get setup_sync_changeProvider => 'Cambia provider';

  @override
  String setup_sync_connectedTo(String provider) {
    return 'Connesso a $provider';
  }

  @override
  String setup_sync_error(Object error) {
    return 'Impossibile connettersi: $error';
  }

  @override
  String get setup_sync_header => 'Sincronizzazione cloud';

  @override
  String get setup_sync_libraryFound_adopt => 'Adotta la libreria esistente';

  @override
  String get setup_sync_libraryFound_keepFresh => 'Inizia da zero';

  @override
  String get setup_sync_libraryFound_message =>
      'Questo account contiene già una libreria Submersion. Adottarla invece di iniziare da zero?';

  @override
  String get setup_sync_libraryFound_title => 'Trovata libreria esistente';

  @override
  String get setup_sync_manageInSettings => 'Gestisci nelle impostazioni';

  @override
  String get setup_sync_notConnected => 'Non connesso';

  @override
  String get setup_sync_subtitle =>
      'Sincronizza i tuoi dati su tutti i dispositivi';

  @override
  String get setup_units_advanced => 'Regola le unità';

  @override
  String get setup_units_altitude => 'Altitudine';

  @override
  String get setup_units_dateFormat => 'Formato data';

  @override
  String get setup_units_depth => 'Profondità';

  @override
  String get setup_units_imperial => 'Imperiale';

  @override
  String get setup_units_metric => 'Metrico';

  @override
  String get setup_units_pressure => 'Pressione';

  @override
  String get setup_units_sac => 'Tasso SAC';

  @override
  String get setup_units_subtitle =>
      'Scegli come visualizzare le misure. Puoi regolare ogni unità.';

  @override
  String get setup_units_temperature => 'Temperatura';

  @override
  String get setup_units_timeFormat => 'Formato ora';

  @override
  String get setup_units_title => 'Unità';

  @override
  String get setup_units_volume => 'Volume';

  @override
  String get setup_units_weight => 'Peso';

  @override
  String get setup_welcome_existingData_subtitle =>
      'Ripristina un backup, collega la sincronizzazione o apri una cartella esistente';

  @override
  String get setup_welcome_existingData_title => 'Ho già dati di Submersion';

  @override
  String get setup_welcome_skipSetup => 'Salta configurazione';

  @override
  String get setup_welcome_startFresh_subtitle =>
      'Crea il tuo profilo subacqueo e configura l\'app';

  @override
  String get setup_welcome_startFresh_title => 'Configura un nuovo profilo';

  @override
  String get setup_welcome_subtitle =>
      'Registrazione e analisi avanzata delle immersioni';

  @override
  String get setup_welcome_title => 'Benvenuto in Submersion';

  @override
  String get siteMatchReview_title => 'Associa siti';

  @override
  String siteMatchReview_diveNumber(Object number) {
    return 'Immersione #$number';
  }

  @override
  String get siteMatchReview_empty => 'Niente da associare.';

  @override
  String siteMatchReview_summary(int selected, int review, int none) {
    return '$selected selezionate · $review da rivedere · $none senza corrispondenza';
  }

  @override
  String siteMatchReview_confirm(int count) {
    return 'Conferma $count associazioni';
  }

  @override
  String get siteMatchReview_cancel => 'Annulla';

  @override
  String get siteMatchReview_tapToChoose => 'Tocca per scegliere un sito';

  @override
  String siteMatchReview_awayMeters(int meters) {
    return 'a $meters m';
  }

  @override
  String siteMatchReview_depthTo(int meters) {
    return 'fino a $meters m';
  }

  @override
  String siteMatchReview_depthRange(int min, int max) {
    return '$min–$max m';
  }

  @override
  String siteMatchReview_appliedSnack(int dives, int sites) {
    return '$dives immersioni associate · $sites siti aggiunti';
  }

  @override
  String get siteMatchReview_applyError =>
      'Impossibile applicare le associazioni';

  @override
  String get siteMatchReview_discardTitle => 'Scartare le associazioni?';

  @override
  String get siteMatchReview_discardMessage =>
      'La tua selezione non verrà salvata.';

  @override
  String get siteMatchReview_discardConfirm => 'Scarta';

  @override
  String get siteMatchReview_keepReviewing => 'Continua a rivedere';

  @override
  String get siteMatchReview_sourceExisting => 'il tuo sito';

  @override
  String get siteMatchReview_sourceBundled => 'importato';

  @override
  String get siteMatchReview_noNearbySite => 'Nessun sito nelle vicinanze';

  @override
  String importSummary_matchSitesButton(int count) {
    return 'Associa $count immersioni ai siti';
  }

  @override
  String get diveLog_listPage_searchFieldLabel => 'Cerca immersioni...';

  @override
  String diveLog_listPage_searchLimitNotice(int limit) {
    return 'Vengono mostrate le prime $limit corrispondenze. Affina la ricerca per restringere i risultati.';
  }

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return 'Nessuna immersione trovata per \"$query\"';
  }

  @override
  String get diveLog_listPage_searchSuggestion =>
      'Cerca per sito, compagno o note';

  @override
  String get diveLog_listPage_title => 'Diario immersioni';

  @override
  String get diveLog_listPage_tooltip_back => 'Indietro';

  @override
  String get diveLog_listPage_tooltip_backToDiveList =>
      'Torna all\'elenco immersioni';

  @override
  String get diveLog_listPage_tooltip_clearSearch => 'Cancella ricerca';

  @override
  String get diveLog_listPage_tooltip_filterDives => 'Filtra immersioni';

  @override
  String get diveLog_listPage_tooltip_listView => 'Vista elenco';

  @override
  String get diveLog_listPage_tooltip_mapView => 'Vista mappa';

  @override
  String get diveLog_listPage_tooltip_searchDives => 'Cerca immersioni';

  @override
  String get diveLog_listPage_tooltip_sort => 'Ordina';

  @override
  String get diveLog_listPage_unknownSite => 'Sito sconosciuto';

  @override
  String get diveLog_map_emptySubtitle =>
      'Registra immersioni con dati di posizione per vedere la tua attivita sulla mappa';

  @override
  String get diveLog_map_emptyTitle =>
      'Nessuna attivita di immersione da visualizzare';

  @override
  String diveLog_map_errorLoading(Object error) {
    return 'Errore nel caricamento dei dati immersione: $error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => 'Adatta a tutti i siti';

  @override
  String get diveLog_numbering_actions => 'Azioni';

  @override
  String get diveLog_numbering_allCorrect =>
      'Tutte le immersioni numerate correttamente';

  @override
  String get diveLog_numbering_assignMissing => 'Assegna numeri mancanti';

  @override
  String get diveLog_numbering_assignMissingDesc =>
      'Numera le immersioni senza numero a partire dall\'ultima numerata';

  @override
  String get diveLog_numbering_close => 'Chiudi';

  @override
  String get diveLog_numbering_gapsDetected => 'Lacune rilevate';

  @override
  String get diveLog_numbering_issuesDetected => 'Problemi rilevati';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '$count mancanti';
  }

  @override
  String get diveLog_numbering_renumberAll => 'Rinumera tutte le immersioni';

  @override
  String get diveLog_numbering_renumberAllDesc =>
      'Assegna numeri sequenziali in base a data/ora dell\'immersione';

  @override
  String get diveLog_numbering_renumberDialog_cancel => 'Annulla';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      'Tutte le immersioni saranno rinumerate in modo sequenziale in base alla data/ora di ingresso. Questa azione non puo essere annullata.';

  @override
  String get diveLog_numbering_renumberDialog_renumber => 'Rinumera';

  @override
  String get diveLog_numbering_renumberDialog_startFrom => 'Inizia dal numero';

  @override
  String get diveLog_numbering_renumberDialog_title =>
      'Rinumera tutte le immersioni';

  @override
  String get diveLog_numbering_snackbar_assigned =>
      'Numeri immersione mancanti assegnati';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return 'Tutte le immersioni rinumerate a partire da #$number';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '$total immersioni totali - $numbered numerate';
  }

  @override
  String get diveLog_numbering_title => 'Numerazione immersioni';

  @override
  String diveLog_numbering_unnumberedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni',
      one: 'immersione',
    );
    return '$count $_temp0 senza numero';
  }

  @override
  String get diveLog_o2tox_badge_critical => 'CRITICO';

  @override
  String get diveLog_o2tox_badge_warning => 'ATTENZIONE';

  @override
  String diveLog_o2tox_cnsBadgeLabel(Object value) {
    return 'CNS $value';
  }

  @override
  String get diveLog_o2tox_cnsOxygenClock => 'Orologio ossigeno CNS';

  @override
  String diveLog_o2tox_deltaDive(Object value) {
    return '+$value% questa immersione';
  }

  @override
  String get diveLog_o2tox_details => 'Dettagli';

  @override
  String get diveLog_o2tox_label_maxPpO2 => 'ppO2 massimo';

  @override
  String get diveLog_o2tox_label_maxPpO2Depth => 'Profondita ppO2 massimo';

  @override
  String get diveLog_o2tox_label_timeAbove14 => 'Tempo sopra 1,4 bar';

  @override
  String get diveLog_o2tox_label_timeAbove16 => 'Tempo sopra 1,6 bar';

  @override
  String get diveLog_o2tox_ofDailyLimit => 'del limite giornaliero';

  @override
  String get diveLog_o2tox_oxygenToleranceUnits =>
      'Unita di tolleranza all\'ossigeno';

  @override
  String diveLog_o2tox_semantics_cnsBadge(Object value) {
    return 'Tossicità ossigeno CNS $value';
  }

  @override
  String get diveLog_o2tox_semantics_criticalWarning =>
      'Avviso critico tossicita dell\'ossigeno';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return 'Unità Tolleranza Ossigeno: $value, $percent percento del limite giornaliero';
  }

  @override
  String get diveLog_o2tox_semantics_warning =>
      'Avviso tossicita dell\'ossigeno';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return 'Inizio: $value%';
  }

  @override
  String get diveLog_o2tox_title => 'Tossicita dell\'ossigeno';

  @override
  String get diveLog_playbackStats_deco => 'DECO';

  @override
  String get diveLog_playbackStats_depth => 'Profondita';

  @override
  String get diveLog_playbackStats_header => 'Statistiche in tempo reale';

  @override
  String get diveLog_playbackStats_heartRate => 'Frequenza cardiaca';

  @override
  String get diveLog_playbackStats_ndl => 'NDL';

  @override
  String get diveLog_playbackStats_ppO2 => 'ppO2';

  @override
  String get diveLog_playbackStats_pressure => 'Pressione';

  @override
  String get diveLog_playbackStats_temp => 'Temp';

  @override
  String get diveLog_playback_sliderLabel => 'Posizione riproduzione';

  @override
  String diveLog_playback_speed_label(Object speed) {
    return '${speed}x';
  }

  @override
  String get diveLog_playback_stepThrough => 'Riproduzione passo-passo';

  @override
  String get diveLog_playback_tooltip_back10 => 'Indietro 10 secondi';

  @override
  String get diveLog_playback_tooltip_exit =>
      'Esci dalla modalita riproduzione';

  @override
  String get diveLog_playback_tooltip_forward10 => 'Avanti 10 secondi';

  @override
  String get diveLog_playback_tooltip_pause => 'Pausa';

  @override
  String get diveLog_playback_tooltip_play => 'Riproduci';

  @override
  String get diveLog_playback_tooltip_skipEnd => 'Vai alla fine';

  @override
  String get diveLog_playback_tooltip_skipStart => 'Vai all\'inizio';

  @override
  String get diveLog_playback_tooltip_speed => 'Velocita di riproduzione';

  @override
  String diveLog_profile_axisDepth(Object unit) {
    return 'Profondita ($unit)';
  }

  @override
  String get diveLog_profile_axisTime => 'Tempo (min)';

  @override
  String get diveLog_profile_emptyState => 'Nessun dato del profilo immersione';

  @override
  String get diveLog_profile_rightAxis_none => 'Nessuno';

  @override
  String get diveLog_profile_semantics_changeRightAxis =>
      'Cambia metrica asse destro';

  @override
  String get diveLog_profile_semantics_chart =>
      'Grafico profilo immersione, pizzica per zoomare';

  @override
  String get diveLog_profile_semantics_photoMarker => 'Indicatore foto';

  @override
  String get diveLog_profile_tooltip_moreOptions => 'Altre opzioni del grafico';

  @override
  String get diveLog_profile_tooltip_resetZoom => 'Reimposta zoom';

  @override
  String get diveLog_profile_tooltip_zoomIn => 'Zoom avanti';

  @override
  String get diveLog_profile_tooltip_zoomOut => 'Zoom indietro';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return 'Zoom: ${level}x - Pizzica o scorri per zoomare, trascina per spostare';
  }

  @override
  String get diveLog_rangeSelection_exitRange => 'Esci dall\'intervallo';

  @override
  String get diveLog_rangeSelection_selectRange => 'Seleziona intervallo';

  @override
  String get diveLog_rangeSelection_semantics_adjust =>
      'Regola selezione intervallo';

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
  String get diveLog_rangeStats_title => 'Stats intervallo';

  @override
  String get diveLog_rangeStats_tooltip_close => 'Chiudi analisi intervallo';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return 'FO2 circuito calcolato: $value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => 'es. 0,33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => 'Rapporto di addizione';

  @override
  String get diveLog_scr_label_assumedVo2 => 'VO2 stimato';

  @override
  String get diveLog_scr_label_avg => 'Media';

  @override
  String get diveLog_scr_label_injectionRate => 'Tasso di iniezione';

  @override
  String get diveLog_scr_label_max => 'Max';

  @override
  String get diveLog_scr_label_min => 'Min';

  @override
  String get diveLog_scr_label_orificeSize => 'Dimensione orifizio';

  @override
  String get diveLog_scr_sectionCmf => 'Parametri CMF';

  @override
  String get diveLog_scr_sectionEscr => 'Parametri ESCR';

  @override
  String get diveLog_scr_sectionMeasuredLoopO2 =>
      'O₂ circuito misurato (opzionale)';

  @override
  String get diveLog_scr_sectionPascr => 'Parametri PASCR';

  @override
  String get diveLog_scr_sectionScrType => 'Tipo SCR';

  @override
  String get diveLog_scr_sectionSupplyGas => 'Gas di alimentazione';

  @override
  String get diveLog_scr_title => 'Impostazioni SCR';

  @override
  String get diveLog_search_allCenters => 'Tutti i centri';

  @override
  String get diveLog_search_allTrips => 'Tutti i viaggi';

  @override
  String get diveLog_search_appBar => 'Ricerca avanzata';

  @override
  String get diveLog_search_cancel => 'Annulla';

  @override
  String get diveLog_search_clearAll => 'Cancella tutto';

  @override
  String get diveLog_search_customFieldKey => 'Custom Field Key';

  @override
  String get diveLog_search_customFieldValue => 'Value contains...';

  @override
  String get diveLog_search_end => 'Fine';

  @override
  String get diveLog_search_errorLoadingCenters =>
      'Errore nel caricamento dei centri immersione';

  @override
  String get diveLog_search_errorLoadingDiveTypes =>
      'Errore durante il caricamento dei tipi di immersione';

  @override
  String get diveLog_search_errorLoadingTrips =>
      'Errore nel caricamento dei viaggi';

  @override
  String get diveLog_search_filter_any => 'Qualsiasi';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_deco => 'Decompressione';

  @override
  String get diveLog_search_label_depthRange => 'Intervallo profondita (m)';

  @override
  String get diveLog_search_label_diveCenter => 'Centro immersioni';

  @override
  String get diveLog_search_label_diveSite => 'Sito di immersione';

  @override
  String get diveLog_search_label_diveType => 'Tipo di immersione';

  @override
  String get diveLog_search_label_durationRange => 'Intervallo durata (min)';

  @override
  String get diveLog_search_label_trip => 'Viaggio';

  @override
  String get diveLog_search_search => 'Cerca';

  @override
  String get diveLog_search_section_conditions => 'Condizioni';

  @override
  String get diveLog_search_section_dateRange => 'Intervallo date';

  @override
  String get diveLog_search_section_gasEquipment => 'Gas e attrezzatura';

  @override
  String get diveLog_search_section_location => 'Localita';

  @override
  String get diveLog_search_section_organization => 'Organizzazione';

  @override
  String get diveLog_search_section_social => 'Sociale';

  @override
  String get diveLog_search_start => 'Inizio';

  @override
  String diveLog_selection_countSelected(Object count) {
    return '$count selezionati';
  }

  @override
  String get diveLog_selection_tooltip_combine => 'Unisci';

  @override
  String get diveLog_selection_tooltip_delete => 'Elimina selezionati';

  @override
  String get diveLog_selection_tooltip_deselectAll => 'Deseleziona tutto';

  @override
  String get diveLog_selection_tooltip_edit => 'Modifica selezionati';

  @override
  String get diveLog_selection_tooltip_exit => 'Esci dalla selezione';

  @override
  String get diveLog_selection_tooltip_export => 'Esporta selezionati';

  @override
  String get diveLog_selection_tooltip_selectAll => 'Seleziona tutto';

  @override
  String get diveLog_selection_tooltip_selectDateRange =>
      'Seleziona per intervallo di date';

  @override
  String get diveLog_sighting_add => 'Aggiungi';

  @override
  String get diveLog_sighting_cancel => 'Annulla';

  @override
  String get diveLog_sighting_notesHint =>
      'es. dimensione, comportamento, posizione...';

  @override
  String get diveLog_sighting_notesOptional => 'Note (opzionale)';

  @override
  String get diveLog_sitePicker_addDiveSite => 'Aggiungi sito di immersione';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return '$distance km di distanza';
  }

  @override
  String diveLog_sitePicker_distanceAway(String distance) {
    return '$distance di distanza';
  }

  @override
  String get diveLog_sitePicker_sortedByDiveDistance =>
      'Ordinati per distanza da questa immersione';

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return '$distance m di distanza';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return 'Errore nel caricamento dei siti: $error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => 'Nuovo sito di immersione';

  @override
  String get diveLog_sitePicker_noSites => 'Nessun sito di immersione';

  @override
  String get diveLog_sitePicker_sortedByDistance => 'Ordinati per distanza';

  @override
  String get diveLog_sitePicker_title => 'Seleziona sito di immersione';

  @override
  String get diveLog_sort_title => 'Ordina immersioni';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return 'Aggiungi \"$name\" come nuova specie';
  }

  @override
  String get diveLog_speciesPicker_noResults => 'Nessuna specie trovata';

  @override
  String get diveLog_speciesPicker_noSpecies => 'Nessuna specie disponibile';

  @override
  String get diveLog_speciesPicker_searchHint => 'Cerca specie...';

  @override
  String get diveLog_speciesPicker_title => 'Aggiungi vita marina';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch => 'Cancella ricerca';

  @override
  String get diveLog_summary_action_importComputer => 'Importa da computer';

  @override
  String get diveLog_summary_action_logDive => 'Registra immersione';

  @override
  String get diveLog_summary_action_viewStats => 'Visualizza statistiche';

  @override
  String diveLog_summary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni',
      one: 'immersione',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_summary_overview => 'Panoramica';

  @override
  String get diveLog_summary_record_coldest => 'Immersione piu fredda';

  @override
  String get diveLog_summary_record_deepest => 'Immersione piu profonda';

  @override
  String get diveLog_summary_record_longest => 'Immersione piu lunga';

  @override
  String get diveLog_summary_record_warmest => 'Immersione piu calda';

  @override
  String get diveLog_summary_section_mostVisited => 'Siti piu visitati';

  @override
  String get diveLog_summary_section_quickActions => 'Azioni rapide';

  @override
  String get diveLog_summary_section_records => 'Record personali';

  @override
  String get diveLog_summary_selectDive =>
      'Seleziona un\'immersione dalla lista per visualizzare i dettagli';

  @override
  String get diveLog_summary_stat_avgMaxDepth => 'Profondita max media';

  @override
  String get diveLog_summary_stat_avgWaterTemp => 'Temp. acqua media';

  @override
  String get diveLog_summary_stat_diveSites => 'Siti di immersione';

  @override
  String get diveLog_summary_stat_diveTime => 'Tempo di immersione';

  @override
  String get diveLog_summary_stat_maxDepth => 'Profondita max';

  @override
  String get diveLog_summary_stat_totalDives => 'Immersioni totali';

  @override
  String get diveLog_summary_title => 'Riepilogo registro immersioni';

  @override
  String get diveLog_tank_label_endPressure => 'Pressione finale';

  @override
  String get diveLog_tank_label_he => 'He';

  @override
  String get diveLog_tank_label_material => 'Materiale';

  @override
  String get diveLog_tank_label_n2 => 'N2';

  @override
  String get diveLog_tank_label_o2 => 'O2';

  @override
  String get diveLog_tank_label_role => 'Ruolo';

  @override
  String get diveLog_tank_label_startPressure => 'Pressione iniziale';

  @override
  String get diveLog_tank_label_tankPreset => 'Preset bombola';

  @override
  String get diveLog_tank_label_volume => 'Volume';

  @override
  String get diveLog_tank_label_workingPressure => 'P di esercizio';

  @override
  String get diveLog_tank_mndHelper =>
      'Imposta per calcolare automaticamente He%';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String diveLog_tank_modMndInfo(Object mod, Object mnd) {
    return 'MOD: $mod (ppO₂ 1.4) | MND: $mnd';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Miscela gas';

  @override
  String get diveLog_tank_selectPreset => 'Seleziona preset...';

  @override
  String get diveLog_tank_saveAsPreset => 'Salva come preset';

  @override
  String get diveLog_tank_saveAsPreset_needSpecs =>
      'Inserisci prima volume e pressione di esercizio';

  @override
  String get diveLog_tank_saveAsPreset_nameTitle => 'Salva preset bombola';

  @override
  String get diveLog_tank_saveAsPreset_nameHint => 'es. La mia AL80';

  @override
  String diveLog_tank_saveAsPreset_saved(String name) {
    return 'Preset \"$name\" salvato';
  }

  @override
  String diveLog_tank_title(Object number) {
    return 'Bombola $number';
  }

  @override
  String get diveLog_tank_tooltip_remove => 'Rimuovi bombola';

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
  String get diveLog_tissue_title => 'Carico tissutale';

  @override
  String get diveLog_tooltip_avgCalculated => '(media, calcolato)';

  @override
  String get diveLog_tooltip_ceiling => 'Ceiling';

  @override
  String get diveLog_tooltip_decoStop => 'Deco stop';

  @override
  String get diveLog_tooltip_cns => 'CNS';

  @override
  String get diveLog_tooltip_density => 'Densita';

  @override
  String get diveLog_tooltip_depth => 'Profondita';

  @override
  String get diveLog_tooltip_gfPercent => 'GF%';

  @override
  String get diveLog_tooltip_hr => 'FC';

  @override
  String get diveLog_tooltip_marker => 'Marcatore';

  @override
  String get diveLog_tooltip_mean => 'Media';

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
  String get diveLog_tooltip_rate => 'Velocita';

  @override
  String get diveLog_tooltip_sac => 'SAC';

  @override
  String get diveLog_tooltip_sensor => 'Sensore';

  @override
  String get diveLog_legend_label_o2Cells => 'Celle O2';

  @override
  String get diveLog_tooltip_o2CellsTight => 'stretta';

  @override
  String get diveLog_tooltip_o2CellsDrifting => 'in deriva';

  @override
  String get diveLog_tooltip_o2CellsWide => 'ampia';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Tempo';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get diveLog_sources_row_metric => 'Misura';

  @override
  String get diveLog_sources_row_maxDepth => 'Profondità max';

  @override
  String get diveLog_sources_row_avgDepth => 'Profondità media';

  @override
  String get diveLog_sources_row_duration => 'Durata';

  @override
  String get diveLog_sources_row_waterTemp => 'Temp. acqua';

  @override
  String get diveLog_sources_row_cns => 'CNS';

  @override
  String get diveLog_sources_row_otu => 'OTU';

  @override
  String get diveLog_sources_row_decoAlgorithm => 'Algoritmo deco';

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
  String get diveLog_sources_unknownComputer => 'Computer sconosciuto';

  @override
  String get diveLog_sources_manualEntry => 'Inserimento manuale';

  @override
  String get diveLog_sources_importedFile => 'File importato';

  @override
  String get diveLog_sources_editedSuffix => ' (modificato)';

  @override
  String get diveLog_sources_barLabel => 'FONTI';

  @override
  String get diveLog_sources_menu_setPrimary => 'Imposta come principale';

  @override
  String get diveLog_sources_menu_split => 'Dividi in immersione separata';

  @override
  String get diveLog_sources_overlayTooltip => 'Sovrapponi sul grafico';

  @override
  String get diveLog_sources_splitDialog_title =>
      'Dividere in immersione separata?';

  @override
  String get diveLog_sources_splitDialog_body =>
      'Il profilo, gli eventi e le bombole di questa fonte verranno spostati in una nuova immersione. La voce del logbook resta su questa immersione.';

  @override
  String get diveLog_sources_splitDialog_confirm => 'Dividi';

  @override
  String get diveLog_sources_splitDone => 'Immersione divisa';

  @override
  String get diveLog_sources_splitFailed => 'Divisione non riuscita';

  @override
  String get divePlanner_action_addTank => 'Aggiungi Bombola';

  @override
  String get divePlanner_action_convertToDive => 'Converti in Immersione';

  @override
  String get divePlanner_action_deletePlan => 'Elimina piano';

  @override
  String get divePlanner_action_editTank => 'Modifica Bombola';

  @override
  String get divePlanner_action_moreOptions => 'Altre opzioni';

  @override
  String get divePlanner_action_quickPlan => 'Piano Rapido';

  @override
  String get divePlanner_action_renamePlan => 'Rinomina Piano';

  @override
  String get divePlanner_action_reset => 'Ripristina';

  @override
  String get divePlanner_action_resetPlan => 'Ripristina Piano';

  @override
  String get divePlanner_action_savePlan => 'Salva Piano';

  @override
  String get divePlanner_error_cannotConvert =>
      'Impossibile convertire: il piano ha avvisi critici';

  @override
  String get divePlanner_error_reserveExceedsTank =>
      'Supera la pressione della bombola';

  @override
  String get divePlanner_error_reserveMustBePositive =>
      'Deve essere maggiore di 0';

  @override
  String divePlanner_info_reserveDefault(Object unit, Object value) {
    return 'Non inserito — valore predefinito $value $unit';
  }

  @override
  String get divePlanner_field_hePercent => 'He %';

  @override
  String get divePlanner_field_name => 'Nome';

  @override
  String get divePlanner_field_o2Percent => 'O₂ %';

  @override
  String get divePlanner_field_planName => 'Nome Piano';

  @override
  String get divePlanner_field_role => 'Ruolo';

  @override
  String divePlanner_field_startPressure(Object pressureSymbol) {
    return 'Inizio ($pressureSymbol)';
  }

  @override
  String get divePlanner_field_travelGas => 'Usato anche come gas da viaggio';

  @override
  String divePlanner_field_volume(Object volumeSymbol) {
    return 'Volume ($volumeSymbol)';
  }

  @override
  String get divePlanner_hint_tankName => 'Inserisci nome bombola';

  @override
  String get divePlanner_label_altitude => 'Altitudine:';

  @override
  String get divePlanner_label_belowMinReserve => 'Sotto Riserva Minima';

  @override
  String get divePlanner_label_ceiling => 'Tetto';

  @override
  String get divePlanner_label_consumption => 'Consumo';

  @override
  String get divePlanner_label_deco => 'DECO';

  @override
  String get divePlanner_label_decoSchedule => 'Programma Decompressione';

  @override
  String get divePlanner_label_decompression => 'Decompressione';

  @override
  String divePlanner_label_depthAxis(Object depthSymbol) {
    return 'Profondità ($depthSymbol)';
  }

  @override
  String get divePlanner_label_diveProfile => 'Profilo Immersione';

  @override
  String get divePlanner_label_empty => 'VUOTA';

  @override
  String get divePlanner_label_gasConsumption => 'Consumo Gas';

  @override
  String get divePlanner_label_gfHigh => 'GF Alto';

  @override
  String get divePlanner_label_gfLow => 'GF Basso';

  @override
  String get divePlanner_label_max => 'Max';

  @override
  String get divePlanner_label_ndl => 'NDL';

  @override
  String get divePlanner_label_planSettings => 'Impostazioni Piano';

  @override
  String get divePlanner_label_remaining => 'Rimanente';

  @override
  String get divePlanner_label_reserve => 'Riserva:';

  @override
  String get divePlanner_label_runtime => 'Tempo Totale';

  @override
  String get divePlanner_label_sacRate => 'RMV:';

  @override
  String get divePlanner_label_status => 'Stato';

  @override
  String get divePlanner_label_tanks => 'Bombole';

  @override
  String get divePlanner_label_time => 'Tempo';

  @override
  String get divePlanner_label_timeAxis => 'Tempo (min)';

  @override
  String get divePlanner_label_tts => 'TTS';

  @override
  String get divePlanner_label_used => 'Usato';

  @override
  String get divePlanner_label_warnings => 'Avvisi';

  @override
  String get divePlanner_legend_ascent => 'Risalita';

  @override
  String get divePlanner_legend_bottom => 'Fondo';

  @override
  String get divePlanner_legend_deco => 'Deco';

  @override
  String get divePlanner_legend_descent => 'Discesa';

  @override
  String get divePlanner_legend_safety => 'Sicurezza';

  @override
  String get divePlanner_message_addSegmentsForGas =>
      'Aggiungi segmenti per vedere le proiezioni gas';

  @override
  String get divePlanner_message_addSegmentsForProfile =>
      'Aggiungi segmenti per vedere il profilo di immersione';

  @override
  String get divePlanner_message_convertingPlan =>
      'Conversione piano in immersione...';

  @override
  String get divePlanner_message_noProfile => 'Nessun profilo da visualizzare';

  @override
  String divePlanner_message_deleteConfirmation(String name) {
    return 'Eliminare \'$name\'?';
  }

  @override
  String get divePlanner_message_planDeleted => 'Piano eliminato';

  @override
  String get divePlanner_message_planSaved => 'Piano salvato';

  @override
  String get divePlanner_message_resetConfirmation =>
      'Sei sicuro di voler ripristinare il piano?';

  @override
  String divePlanner_semantics_criticalWarning(Object message) {
    return 'Avviso critico: $message';
  }

  @override
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  ) {
    return 'Tappa deco a $depth per $duration con $gasMix';
  }

  @override
  String divePlanner_semantics_gasConsumption(
    Object tankName,
    Object gasUsed,
    Object remaining,
    Object percent,
    Object warning,
  ) {
    return '$tankName: $gasUsed usato, $remaining rimanente, $percent usato$warning';
  }

  @override
  String divePlanner_semantics_profileChart(
    Object maxDepth,
    Object totalMinutes,
  ) {
    return 'Piano immersione, profondità max $maxDepth, tempo totale $totalMinutes minuti';
  }

  @override
  String divePlanner_semantics_warning(Object message) {
    return 'Avviso: $message';
  }

  @override
  String get divePlanner_tab_plan => 'Piano';

  @override
  String get divePlanner_tab_profile => 'Profilo';

  @override
  String get divePlanner_tab_results => 'Risultati';

  @override
  String get divePlanner_warning_ascentRateHigh =>
      'Velocità di risalita supera il limite sicuro';

  @override
  String divePlanner_warning_ascentRateHighWithRate(Object rate) {
    return 'Velocità di risalita $rate/min supera il limite sicuro';
  }

  @override
  String divePlanner_warning_belowMinReserve(Object reserve) {
    return 'Sotto la riserva minima ($reserve)';
  }

  @override
  String get divePlanner_warning_cnsCritical => 'CNS% supera il 100%';

  @override
  String divePlanner_warning_cnsWarning(Object threshold) {
    return 'CNS% supera $threshold%';
  }

  @override
  String get divePlanner_warning_endHigh =>
      'Profondità Narcotica Equivalente troppo alta';

  @override
  String divePlanner_warning_endHighWithDepth(Object depth) {
    return 'END di $depth supera il limite sicuro';
  }

  @override
  String divePlanner_warning_gasLow(Object threshold) {
    return 'Bombola sotto $threshold di riserva';
  }

  @override
  String get divePlanner_warning_gasOut => 'La bombola sarà vuota';

  @override
  String get divePlanner_warning_minGasViolation =>
      'Riserva gas minima non mantenuta';

  @override
  String get divePlanner_warning_modViolation => 'Cambio gas tentato sopra MOD';

  @override
  String get divePlanner_warning_ndlExceeded =>
      'L\'immersione entra in obbligo di decompressione';

  @override
  String get divePlanner_warning_otuWarning => 'Accumulo OTU alto';

  @override
  String divePlanner_warning_ppO2Critical(Object value) {
    return 'ppO₂ di $value bar supera il limite critico';
  }

  @override
  String divePlanner_warning_ppO2High(Object value) {
    return 'ppO₂ di $value bar supera il limite di lavoro';
  }

  @override
  String get diveSites_detail_access_accessNotes => 'Note di accesso';

  @override
  String get diveSites_detail_access_mooring => 'Ormeggio';

  @override
  String get diveSites_detail_access_parking => 'Parcheggio';

  @override
  String get diveSites_detail_altitude_elevation => 'Altitudine';

  @override
  String get diveSites_detail_altitude_pressure => 'Pressione';

  @override
  String get diveSites_detail_coordinatesCopied =>
      'Coordinate copiate negli appunti';

  @override
  String get diveSites_detail_deleteDialog_cancel => 'Annulla';

  @override
  String get diveSites_detail_deleteDialog_confirm => 'Elimina';

  @override
  String get diveSites_detail_deleteDialog_content =>
      'Sei sicuro di voler eliminare questo sito? Questa azione non puo essere annullata.';

  @override
  String get diveSites_detail_deleteDialog_title => 'Elimina sito';

  @override
  String get diveSites_detail_deleteMenu_label => 'Elimina';

  @override
  String get diveSites_detail_deleteSnackbar => 'Sito eliminato';

  @override
  String get diveSites_detail_depth_maximum => 'Massima';

  @override
  String get diveSites_detail_depth_minimum => 'Minima';

  @override
  String get diveSites_detail_diveCount_one => '1 immersione registrata';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '$count immersioni registrate';
  }

  @override
  String get diveSites_detail_diveCount_zero => 'Nessuna immersione registrata';

  @override
  String get diveSites_detail_editTooltip => 'Modifica sito';

  @override
  String get diveSites_detail_editTooltipShort => 'Modifica';

  @override
  String diveSites_detail_error_body(Object error) {
    return 'Errore: $error';
  }

  @override
  String get diveSites_detail_error_title => 'Errore';

  @override
  String get diveSites_detail_loading_title => 'Caricamento...';

  @override
  String get diveSites_detail_location_country => 'Paese';

  @override
  String get diveSites_detail_location_city => 'Città';

  @override
  String get diveSites_detail_location_island => 'Isola';

  @override
  String get diveSites_detail_location_bodyOfWater => 'Specchio d\'acqua';

  @override
  String get diveSites_detail_location_gpsCoordinates => 'Coordinate GPS';

  @override
  String get diveSites_detail_location_notSet => 'Non impostato';

  @override
  String get diveSites_detail_location_region => 'Regione';

  @override
  String get diveSites_detail_noDepthInfo =>
      'Nessuna informazione sulla profondita';

  @override
  String get diveSites_detail_noDescription => 'Nessuna descrizione';

  @override
  String get diveSites_detail_noNotes => 'Nessuna nota';

  @override
  String get diveSites_detail_rating_notRated => 'Non valutato';

  @override
  String diveSites_detail_rating_value(Object rating) {
    return '$rating su 5';
  }

  @override
  String get diveSites_detail_section_access => 'Accesso e logistica';

  @override
  String get diveSites_detail_section_altitude => 'Altitudine';

  @override
  String get diveSites_detail_section_depthRange => 'Intervallo profondita';

  @override
  String get diveSites_detail_section_description => 'Descrizione';

  @override
  String get diveSites_detail_section_difficultyLevel =>
      'Livello di difficolta';

  @override
  String get diveSites_detail_section_divesAtSite =>
      'Immersioni in questo sito';

  @override
  String get diveSites_detail_section_hazards => 'Pericoli e sicurezza';

  @override
  String get diveSites_detail_section_location => 'Localita';

  @override
  String get diveSites_detail_section_notes => 'Note';

  @override
  String get diveSites_detail_section_rating => 'Valutazione';

  @override
  String diveSites_detail_semantics_copyToClipboard(Object label) {
    return 'Copia $label negli appunti';
  }

  @override
  String get diveSites_detail_semantics_viewDivesAtSite =>
      'Visualizza immersioni in questo sito';

  @override
  String get diveSites_detail_semantics_viewFullscreenMap =>
      'Visualizza mappa a schermo intero';

  @override
  String get diveSites_detail_siteNotFound_body =>
      'Questo sito non esiste piu.';

  @override
  String get diveSites_detail_siteNotFound_title => 'Sito non trovato';

  @override
  String get diveSites_difficulty_advanced => 'Avanzato';

  @override
  String get diveSites_difficulty_beginner => 'Principiante';

  @override
  String get diveSites_difficulty_intermediate => 'Intermedio';

  @override
  String get diveSites_difficulty_technical => 'Tecnico';

  @override
  String get diveSites_edit_access_accessNotes_hint =>
      'Come raggiungere il sito, punti di entrata/uscita, accesso da riva/barca';

  @override
  String get diveSites_edit_access_accessNotes_label => 'Note di accesso';

  @override
  String get diveSites_edit_access_mooringNumber_hint => 'es. Boa #12';

  @override
  String get diveSites_edit_access_mooringNumber_label => 'Numero ormeggio';

  @override
  String get diveSites_edit_access_parkingInfo_hint =>
      'Disponibilita parcheggio, tariffe, consigli';

  @override
  String get diveSites_edit_access_parkingInfo_label =>
      'Informazioni parcheggio';

  @override
  String get diveSites_edit_access_entryMethod_label => 'Metodo di entrata';

  @override
  String get diveSites_edit_access_exitMethod_label => 'Metodo di uscita';

  @override
  String diveSites_edit_access_entrySuggestionPair(
    int count,
    String entry,
    String exit,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Le tue $count immersioni qui: entrata $entry, uscita $exit',
      one: 'La tua immersione qui: entrata $entry, uscita $exit',
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
      other: 'Le tue $count immersioni qui: entrata $entry',
      one: 'La tua immersione qui: entrata $entry',
    );
    return '$_temp0';
  }

  @override
  String get diveSites_detail_access_entryMethod => 'Entrata';

  @override
  String get diveSites_detail_access_exitMethod => 'Uscita';

  @override
  String get diveSites_edit_altitude_helperText =>
      'Altitudine del sito sul livello del mare (per immersioni in quota)';

  @override
  String get diveSites_edit_altitude_hint => 'es. 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return 'Altitudine ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => 'Altitudine non valida';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => 'Elimina sito';

  @override
  String get diveSites_edit_appBar_editSite => 'Modifica sito';

  @override
  String get diveSites_edit_appBar_merge => 'Unisci';

  @override
  String get diveSites_edit_appBar_mergeSites => 'Unisci siti di immersione';

  @override
  String get diveSites_edit_appBar_newSite => 'Nuovo sito';

  @override
  String get diveSites_edit_appBar_save => 'Salva';

  @override
  String get diveSites_edit_button_addSite => 'Aggiungi sito';

  @override
  String get diveSites_edit_button_mergeSites => 'Unisci siti di immersione';

  @override
  String get diveSites_edit_button_saveChanges => 'Salva modifiche';

  @override
  String get diveSites_edit_cancel => 'Annulla';

  @override
  String get diveSites_edit_depth_helperText =>
      'Dal punto meno profondo al punto piu profondo';

  @override
  String get diveSites_edit_depth_maxHint => 'es. 30';

  @override
  String diveSites_edit_depth_maxLabel(Object symbol) {
    return 'Profondita massima ($symbol)';
  }

  @override
  String get diveSites_edit_depth_minHint => 'es. 5';

  @override
  String diveSites_edit_depth_minLabel(Object symbol) {
    return 'Profondita minima ($symbol)';
  }

  @override
  String get diveSites_edit_depth_separator => 'a';

  @override
  String get diveSites_edit_discardDialog_content =>
      'Hai modifiche non salvate. Sei sicuro di voler uscire?';

  @override
  String get diveSites_edit_discardDialog_discard => 'Scarta';

  @override
  String get diveSites_edit_discardDialog_keepEditing =>
      'Continua a modificare';

  @override
  String get diveSites_edit_discardDialog_title => 'Scartare le modifiche?';

  @override
  String get diveSites_edit_field_country_label => 'Paese';

  @override
  String get diveSites_edit_field_city_label => 'Città';

  @override
  String get diveSites_edit_field_island_label => 'Isola';

  @override
  String get diveSites_edit_field_bodyOfWater_label => 'Specchio d\'acqua';

  @override
  String get diveSites_edit_field_description_hint =>
      'Breve descrizione del sito';

  @override
  String get diveSites_edit_field_description_label => 'Descrizione';

  @override
  String get diveSites_edit_field_notes_hint =>
      'Qualsiasi altra informazione su questo sito';

  @override
  String get diveSites_edit_field_notes_label => 'Note generali';

  @override
  String get diveSites_edit_field_region_label => 'Regione';

  @override
  String get diveSites_edit_field_siteName_hint => 'es. Blue Hole';

  @override
  String get diveSites_edit_field_siteName_label => 'Nome del sito *';

  @override
  String get diveSites_edit_field_siteName_validation =>
      'Inserisci un nome per il sito';

  @override
  String diveSites_similarSite_useHint(Object siteName) {
    return 'Simile a un sito di immersione esistente \"$siteName\". Tocca per usare.';
  }

  @override
  String diveSites_similarSite_warning(Object siteName) {
    return 'Esiste già un sito simile: \"$siteName\"';
  }

  @override
  String get diveSites_edit_gps_gettingLocation => 'Acquisizione...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Scegli un metodo di localizzazione o cerca le coordinate per compilare paese, regione, città e specchio d\'acqua';

  @override
  String get diveSites_edit_gps_latitude_hint => 'es. 21.4225';

  @override
  String get diveSites_edit_gps_latitude_label => 'Latitudine';

  @override
  String get diveSites_edit_gps_latitude_validation => 'Latitudine non valida';

  @override
  String get diveSites_edit_gps_longitude_hint => 'es. -86.7542';

  @override
  String get diveSites_edit_gps_longitude_label => 'Longitudine';

  @override
  String get diveSites_edit_gps_longitude_validation =>
      'Longitudine non valida';

  @override
  String get diveSites_edit_gps_pickFromMap => 'Scegli dalla mappa';

  @override
  String get diveSites_edit_gps_lookupFromCoordinates =>
      'Cerca dalle coordinate';

  @override
  String get diveSites_edit_snackbar_lookupNothingFound =>
      'Nessun dettaglio di località trovato per queste coordinate';

  @override
  String get diveSites_edit_snackbar_lookupFailed =>
      'Ricerca della località non riuscita. Controlla la connessione e riprova.';

  @override
  String get diveSites_edit_lookupReplace_title =>
      'Sostituire i dettagli di località?';

  @override
  String get diveSites_edit_lookupReplace_body =>
      'La ricerca ha trovato valori diversi per questi campi:';

  @override
  String get diveSites_edit_lookupReplace_replace => 'Sostituisci';

  @override
  String get diveSites_edit_lookupReplace_keep => 'Mantieni';

  @override
  String get diveSites_edit_gps_useMyLocation => 'Usa la mia posizione';

  @override
  String get diveSites_edit_hazards_helperText =>
      'Elenca eventuali pericoli o considerazioni sulla sicurezza';

  @override
  String get diveSites_edit_hazards_hint =>
      'es. Correnti forti, traffico nautico, meduse, coralli taglienti';

  @override
  String get diveSites_edit_hazards_label => 'Pericoli';

  @override
  String get diveSites_edit_marineLife_addButton => 'Aggiungi';

  @override
  String get diveSites_edit_marineLife_empty =>
      'Nessuna specie prevista aggiunta';

  @override
  String get diveSites_edit_marineLife_helperText =>
      'Specie che prevedi di vedere in questo sito';

  @override
  String diveSites_edit_merge_confirmBody(int count) {
    return 'Questa operazione unirà $count siti in uno solo. Le immersioni, i media e le specie previste verranno combinati sotto il sito superstite. Gli altri siti verranno eliminati.';
  }

  @override
  String get diveSites_edit_merge_confirmTitle => 'Unisci siti di immersione';

  @override
  String get diveSites_edit_merge_fieldSourceCycleTooltip =>
      'Usa il valore dal prossimo sito selezionato';

  @override
  String diveSites_edit_merge_fieldSourceLabel(
    Object siteName,
    int current,
    int total,
  ) {
    return 'Da $siteName ($current/$total)';
  }

  @override
  String get diveSites_edit_merge_fieldSourceMenuTooltip =>
      'Seleziona il valore dal sito selezionato';

  @override
  String get diveSites_edit_merge_marineLifeHelperText =>
      'Combinato da tutti i siti selezionati';

  @override
  String diveSites_edit_merge_loadingErrorBody(Object error) {
    return 'Impossibile caricare i siti: $error';
  }

  @override
  String get diveSites_edit_merge_loadingErrorTitle =>
      'Unisci siti di immersione';

  @override
  String get diveSites_edit_merge_notEnoughBody =>
      'Non ci sono abbastanza siti da unire.';

  @override
  String get diveSites_edit_merge_notEnoughTitle => 'Unisci siti di immersione';

  @override
  String get diveSites_edit_rating_clear => 'Cancella valutazione';

  @override
  String diveSites_edit_rating_starTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'stelle',
      one: 'stella',
    );
    return '$count $_temp0';
  }

  @override
  String get diveSites_edit_section_access => 'Accesso e logistica';

  @override
  String get diveSites_edit_section_altitude => 'Altitudine';

  @override
  String get diveSites_edit_section_depthRange => 'Intervallo profondita';

  @override
  String get diveSites_edit_section_difficultyLevel => 'Livello di difficolta';

  @override
  String get diveSites_edit_section_expectedMarineLife =>
      'Vita marina prevista';

  @override
  String get diveSites_edit_section_gpsCoordinates => 'Coordinate GPS';

  @override
  String get diveSites_edit_section_hazards => 'Pericoli e sicurezza';

  @override
  String get diveSites_edit_section_rating => 'Valutazione';

  @override
  String get diveSites_edit_section_waterType => 'Tipo di acqua';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return 'Errore nell\'eliminazione del sito: $error';
  }

  @override
  String diveSites_edit_snackbar_errorSaving(Object error) {
    return 'Errore nel salvataggio del sito: $error';
  }

  @override
  String get diveSites_edit_snackbar_locationCaptured => 'Posizione acquisita';

  @override
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Posizione acquisita (${accuracy}m)';
  }

  @override
  String get diveSites_edit_snackbar_locationSelectedFromMap =>
      'Posizione selezionata dalla mappa';

  @override
  String get diveSites_edit_snackbar_locationSettings => 'Impostazioni';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      'Impossibile ottenere la posizione. I servizi di localizzazione potrebbero non essere disponibili.';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      'Impossibile ottenere la posizione. Controlla i permessi.';

  @override
  String get diveSites_edit_snackbar_siteAdded => 'Sito aggiunto';

  @override
  String get diveSites_edit_snackbar_sitesMerged => 'Siti di immersione uniti';

  @override
  String get diveSites_edit_snackbar_siteUpdated => 'Sito aggiornato';

  @override
  String get diveSites_fab_label => 'Aggiungi sito';

  @override
  String get diveSites_fab_tooltip => 'Aggiungi un nuovo sito di immersione';

  @override
  String get diveSites_filter_apply => 'Applica filtri';

  @override
  String get diveSites_filter_cancel => 'Annulla';

  @override
  String get diveSites_filter_clearAll => 'Cancella tutto';

  @override
  String get diveSites_filter_country_hint => 'es. Thailandia';

  @override
  String get diveSites_filter_country_label => 'Paese';

  @override
  String get diveSites_filter_depth_max_label => 'Max';

  @override
  String get diveSites_filter_depth_min_label => 'Min';

  @override
  String get diveSites_filter_depth_separator => 'a';

  @override
  String get diveSites_filter_difficulty_any => 'Qualsiasi';

  @override
  String get diveSites_filter_option_hasCoordinates_subtitle =>
      'Mostra solo i siti con posizione GPS';

  @override
  String get diveSites_filter_option_hasCoordinates_title => 'Ha coordinate';

  @override
  String get diveSites_filter_option_hasDives_subtitle =>
      'Mostra solo i siti con immersioni registrate';

  @override
  String get diveSites_filter_option_hasDives_title => 'Ha immersioni';

  @override
  String diveSites_filter_rating_starsPlus(Object count) {
    return '$count+ stelle';
  }

  @override
  String get diveSites_filter_region_hint => 'es. Phuket';

  @override
  String get diveSites_filter_region_label => 'Regione';

  @override
  String get diveSites_filter_section_depthRange =>
      'Intervallo profondita massima';

  @override
  String get diveSites_filter_section_difficulty => 'Difficolta';

  @override
  String get diveSites_filter_section_location => 'Localita';

  @override
  String get diveSites_filter_section_minRating => 'Valutazione minima';

  @override
  String get diveSites_filter_section_options => 'Opzioni';

  @override
  String get diveSites_filter_title => 'Filtra siti';

  @override
  String get diveSites_import_appBar_title => 'Importa sito di immersione';

  @override
  String get diveSites_import_badge_imported => 'Importato';

  @override
  String get diveSites_import_badge_saved => 'Salvato';

  @override
  String get diveSites_import_button_import => 'Importa';

  @override
  String get diveSites_import_detail_alreadyImported => 'Gia importato';

  @override
  String get diveSites_import_detail_importToMySites => 'Importa nei miei siti';

  @override
  String diveSites_import_detail_source(Object source) {
    return 'Fonte: $source';
  }

  @override
  String get diveSites_import_empty_description =>
      'Cerca siti di immersione dal nostro database di\ndestinazioni subacquee famose in tutto il mondo.';

  @override
  String get diveSites_import_empty_hint =>
      'Prova a cercare per nome del sito, paese o regione.';

  @override
  String get diveSites_import_empty_title => 'Cerca siti di immersione';

  @override
  String get diveSites_import_error_retry => 'Riprova';

  @override
  String get diveSites_import_error_title => 'Errore di ricerca';

  @override
  String get diveSites_import_error_unknown => 'Errore sconosciuto';

  @override
  String get diveSites_import_externalSite_locationUnknown =>
      'Posizione sconosciuta';

  @override
  String get diveSites_import_label_gps => 'GPS';

  @override
  String get diveSites_import_localSite_locationNotSet =>
      'Posizione non impostata';

  @override
  String diveSites_import_noResults_description(Object query) {
    return 'Nessun sito di immersione trovato per \"$query\".\nProva un termine di ricerca diverso.';
  }

  @override
  String get diveSites_import_noResults_title => 'Nessun risultato';

  @override
  String get diveSites_import_quickSearch_caribbean => 'Caraibi';

  @override
  String get diveSites_import_quickSearch_indonesia => 'Indonesia';

  @override
  String get diveSites_import_quickSearch_maldives => 'Maldive';

  @override
  String get diveSites_import_quickSearch_philippines => 'Filippine';

  @override
  String get diveSites_import_quickSearch_redSea => 'Mar Rosso';

  @override
  String get diveSites_import_quickSearch_thailand => 'Thailandia';

  @override
  String get diveSites_import_search_clearTooltip => 'Cancella ricerca';

  @override
  String get diveSites_import_search_hint =>
      'Cerca siti di immersione (es. \"Blue Hole\", \"Thailandia\")';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return 'Importa dal database ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return 'I miei siti ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return 'Visualizza dettagli per $name';
  }

  @override
  String diveSites_import_semantics_viewSavedSite(Object name) {
    return 'Visualizza sito salvato $name';
  }

  @override
  String get diveSites_import_snackbar_failed =>
      'Importazione del sito fallita';

  @override
  String diveSites_import_snackbar_imported(Object name) {
    return '\"$name\" importato';
  }

  @override
  String get diveSites_import_snackbar_viewAction => 'Visualizza';

  @override
  String get diveSites_list_activeFilter_clear => 'Cancella';

  @override
  String diveSites_list_activeFilter_country(Object country) {
    return 'Paese: $country';
  }

  @override
  String diveSites_list_activeFilter_depthRangeBoth(Object min, Object max) {
    return '$min-$max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Fino a $max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '$min+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => 'Ha coordinate';

  @override
  String get diveSites_list_activeFilter_hasDives => 'Ha immersioni';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return 'Regione: $region';
  }

  @override
  String get diveSites_list_appBar_title => 'Siti di immersione';

  @override
  String get diveSites_list_bulkDelete_cancel => 'Annulla';

  @override
  String get diveSites_list_bulkDelete_confirm => 'Elimina';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'siti',
      one: 'sito',
    );
    return 'Sei sicuro di voler eliminare $count $_temp0? Questa azione puo essere annullata entro 5 secondi.';
  }

  @override
  String get diveSites_list_bulkDelete_restored => 'Siti ripristinati';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'siti eliminati',
      one: 'sito eliminato',
    );
    return '$count $_temp0';
  }

  @override
  String get diveSites_list_bulkDelete_title => 'Elimina siti';

  @override
  String get diveSites_list_bulkDelete_undo => 'Annulla';

  @override
  String get diveSites_list_merge_restored => 'Unione annullata';

  @override
  String diveSites_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'siti uniti',
      one: 'sito unito',
    );
    return '$count $_temp0';
  }

  @override
  String get diveSites_list_merge_undo => 'Annulla';

  @override
  String get diveSites_list_emptyFiltered_clearAll => 'Cancella tutti i filtri';

  @override
  String get diveSites_list_emptyFiltered_subtitle =>
      'Prova a modificare o cancellare i filtri';

  @override
  String get diveSites_list_emptyFiltered_title =>
      'Nessun sito corrisponde ai filtri';

  @override
  String get diveSites_list_empty_addFirstSite => 'Aggiungi il tuo primo sito';

  @override
  String get diveSites_list_empty_import => 'Importa';

  @override
  String get diveSites_list_empty_subtitle =>
      'Aggiungi siti di immersione per tenere traccia delle tue localita preferite';

  @override
  String get diveSites_list_empty_title => 'Nessun sito di immersione';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return 'Errore nel caricamento dei siti: $error';
  }

  @override
  String get diveSites_list_error_retry => 'Riprova';

  @override
  String get diveSites_list_menu_import => 'Importa';

  @override
  String get diveSites_list_menu_select => 'Seleziona siti';

  @override
  String get diveSites_list_menu_fillLocationDetails =>
      'Completa i dettagli di località mancanti';

  @override
  String get diveSites_backfill_confirm_title =>
      'Completare i dettagli di località mancanti?';

  @override
  String diveSites_backfill_confirm_body(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count siti con coordinate non hanno paese, regione, città o specchio d\'acqua.',
      one:
          '1 sito con coordinate non ha paese, regione, città o specchio d\'acqua.',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuti',
      one: '1 minuto',
    );
    return '$_temp0 Submersion cercherà ciascuno su OpenStreetMap e compilerà solo i campi vuoti. Richiede circa $_temp1.';
  }

  @override
  String get diveSites_backfill_confirm_start => 'Avvia';

  @override
  String get diveSites_backfill_nothingToFill =>
      'Tutti i siti con coordinate hanno già i dettagli di località.';

  @override
  String get diveSites_backfill_progress_title =>
      'Completamento dei dettagli di località';

  @override
  String diveSites_backfill_progress_count(int done, int total) {
    return '$done di $total';
  }

  @override
  String get diveSites_backfill_cancel => 'Annulla';

  @override
  String diveSites_backfill_summary(int updated, int unchanged, int failed) {
    return 'Aggiornati $updated, invariati $unchanged, falliti $failed';
  }

  @override
  String get diveSites_backfill_offline =>
      'La ricerca della località non è disponibile. Controlla la connessione e riprova.';

  @override
  String get diveSites_list_search_backTooltip => 'Indietro';

  @override
  String get diveSites_list_search_clearTooltip => 'Cancella ricerca';

  @override
  String get diveSites_list_search_emptyHint =>
      'Cerca per nome del sito, paese o regione';

  @override
  String diveSites_list_search_error(Object error) {
    return 'Errore: $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return 'Nessun sito trovato per \"$query\"';
  }

  @override
  String get diveSites_list_search_placeholder => 'Cerca siti...';

  @override
  String get diveSites_list_selection_closeTooltip => 'Chiudi selezione';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count selezionati';
  }

  @override
  String get diveSites_list_selection_deleteTooltip => 'Elimina selezionati';

  @override
  String get diveSites_list_selection_mergeTooltip => 'Unisci selezionati';

  @override
  String get diveSites_list_selection_deselectAllTooltip => 'Deseleziona tutto';

  @override
  String get diveSites_list_selection_selectAllTooltip => 'Seleziona tutto';

  @override
  String get diveSites_list_sort_title => 'Ordina siti';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni',
      one: '1 immersione',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return 'Sito di immersione: $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => 'Filtra siti';

  @override
  String get diveSites_list_tooltip_mapView => 'Vista mappa';

  @override
  String get diveSites_list_tooltip_searchSites => 'Cerca siti';

  @override
  String get diveSites_list_tooltip_sort => 'Ordina';

  @override
  String get diveSites_locationPicker_appBar_title => 'Scegli posizione';

  @override
  String get diveSites_locationPicker_confirmButton => 'Conferma';

  @override
  String get diveSites_locationPicker_confirmTooltip =>
      'Conferma posizione selezionata';

  @override
  String get diveSites_locationPicker_fab_tooltip => 'Usa la mia posizione';

  @override
  String get diveSites_locationPicker_instruction_locationSelected =>
      'Posizione selezionata';

  @override
  String get diveSites_locationPicker_instruction_lookingUp =>
      'Ricerca posizione...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect =>
      'Tocca la mappa per selezionare una posizione';

  @override
  String get diveSites_locationPicker_label_latitude => 'Latitudine';

  @override
  String get diveSites_locationPicker_label_longitude => 'Longitudine';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return 'Coordinate selezionate: latitudine $latitude, longitudine $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp =>
      'Ricerca posizione in corso';

  @override
  String get diveSites_locationPicker_semantics_map =>
      'Mappa interattiva per scegliere la posizione di un sito di immersione. Tocca la mappa per selezionare una posizione.';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return 'Errore nel caricamento dei siti di immersione: $error';
  }

  @override
  String get diveSites_map_appBar_title => 'Siti di immersione';

  @override
  String get diveSites_map_builtInSites_add => 'Aggiungi ai miei siti';

  @override
  String get diveSites_map_builtInSites_addError =>
      'Impossibile aggiungere il sito. Riprova.';

  @override
  String get diveSites_map_builtInSites_added => 'Aggiunto ai tuoi siti';

  @override
  String get diveSites_map_builtInSites_hide => 'Nascondi siti predefiniti';

  @override
  String get diveSites_map_builtInSites_off => 'Siti predefiniti nascosti';

  @override
  String get diveSites_map_builtInSites_on => 'Siti predefiniti visibili';

  @override
  String get diveSites_map_builtInSites_show => 'Mostra siti predefiniti';

  @override
  String get diveSites_map_empty_description =>
      'Aggiungi coordinate ai tuoi siti di immersione per vederli sulla mappa';

  @override
  String get diveSites_map_empty_title => 'Nessun sito con coordinate';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return 'Errore nel caricamento dei siti: $error';
  }

  @override
  String get diveSites_map_error_retry => 'Riprova';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni',
      one: '1 immersione',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_builtInSiteMarker(Object name) {
    return 'Sito di immersione predefinito: $name';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return 'Sito di immersione: $name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => 'Mostra tutti i siti';

  @override
  String get diveSites_map_tooltip_listView => 'Vista elenco';

  @override
  String get diveSites_summary_action_addSite => 'Aggiungi sito';

  @override
  String get diveSites_summary_action_import => 'Importa';

  @override
  String get diveSites_summary_action_viewMap => 'Visualizza mappa';

  @override
  String diveSites_summary_countriesMore(Object count) {
    return '+ $count altri';
  }

  @override
  String get diveSites_summary_header_subtitle =>
      'Seleziona un sito dalla lista per visualizzare i dettagli';

  @override
  String get diveSites_summary_header_title => 'Siti di immersione';

  @override
  String get diveSites_summary_section_countriesRegions => 'Paesi e regioni';

  @override
  String get diveSites_summary_section_mostDived => 'Piu visitati';

  @override
  String get diveSites_summary_section_overview => 'Panoramica';

  @override
  String get diveSites_summary_section_quickActions => 'Azioni rapide';

  @override
  String get diveSites_summary_section_topRated => 'Piu votati';

  @override
  String get diveSites_summary_stat_avgRating => 'Valutazione media';

  @override
  String get diveSites_summary_stat_totalDives => 'Immersioni totali';

  @override
  String get diveSites_summary_stat_totalSites => 'Siti totali';

  @override
  String get diveSites_summary_stat_withGps => 'Con GPS';

  @override
  String get diveType_builtin_altitude => 'Altitudine';

  @override
  String get diveType_builtin_boat => 'Da barca';

  @override
  String get diveType_builtin_cave => 'Grotta';

  @override
  String get diveType_builtin_cavern => 'Caverna';

  @override
  String get diveType_builtin_deep => 'Profonda';

  @override
  String get diveType_builtin_drift => 'Corrente';

  @override
  String get diveType_builtin_freedive => 'Apnea';

  @override
  String get diveType_builtin_ice => 'Sotto ghiaccio';

  @override
  String get diveType_builtin_liveaboard => 'Crociera subacquea';

  @override
  String get diveType_builtin_night => 'Notturna';

  @override
  String get diveType_builtin_recreational => 'Ricreativa';

  @override
  String get diveType_builtin_shore => 'Da riva';

  @override
  String get diveType_builtin_technical => 'Tecnica';

  @override
  String get diveType_builtin_training => 'Addestramento';

  @override
  String get diveType_builtin_wreck => 'Relitto';

  @override
  String get diveTypes_addDialog_addButton => 'Aggiungi';

  @override
  String get diveTypes_addDialog_nameHint => 'es., Ricerca e Recupero';

  @override
  String get diveTypes_addDialog_nameLabel => 'Nome Tipo Immersione';

  @override
  String get diveTypes_addDialog_nameValidation => 'Inserisci un nome';

  @override
  String get diveTypes_addDialog_title =>
      'Aggiungi Tipo Immersione Personalizzato';

  @override
  String get diveTypes_addTooltip => 'Aggiungi tipo immersione';

  @override
  String get diveTypes_appBar_title => 'Tipi di Immersione';

  @override
  String get diveTypes_builtIn => 'Predefiniti';

  @override
  String get diveTypes_builtInHeader => 'Tipi di Immersione Predefiniti';

  @override
  String get diveTypes_custom => 'Personalizzati';

  @override
  String get diveTypes_customHeader => 'Tipi di Immersione Personalizzati';

  @override
  String diveTypes_deleteDialog_content(Object name) {
    return 'Sei sicuro di voler eliminare \"$name\"?';
  }

  @override
  String get diveTypes_deleteDialog_title => 'Eliminare Tipo Immersione?';

  @override
  String get diveTypes_deleteTooltip => 'Elimina tipo immersione';

  @override
  String diveTypes_snackbar_added(Object name) {
    return 'Tipo immersione aggiunto: $name';
  }

  @override
  String diveTypes_snackbar_cannotDelete(Object name) {
    return 'Impossibile eliminare \"$name\" - è usato da immersioni esistenti';
  }

  @override
  String diveTypes_snackbar_deleted(Object name) {
    return 'Eliminato \"$name\"';
  }

  @override
  String diveTypes_snackbar_errorAdding(Object error) {
    return 'Errore durante l\'aggiunta del tipo immersione: $error';
  }

  @override
  String diveTypes_snackbar_errorDeleting(Object error) {
    return 'Errore durante l\'eliminazione del tipo immersione: $error';
  }

  @override
  String get divers_detail_activeDiver => 'Subacqueo attivo';

  @override
  String get divers_detail_allergiesLabel => 'Allergie';

  @override
  String get divers_detail_appBarTitle => 'Subacqueo';

  @override
  String get divers_detail_bloodTypeLabel => 'Gruppo sanguigno';

  @override
  String get divers_detail_bottomTimeLabel => 'Tempo di fondo';

  @override
  String get divers_detail_cancelButton => 'Annulla';

  @override
  String get divers_detail_contactTitle => 'Contatto';

  @override
  String get divers_detail_defaultLabel => 'Predefinito';

  @override
  String get divers_detail_deleteButton => 'Elimina';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'This will permanently delete $name and all associated data including dive logs, dive computers, equipment, certifications, and sites.';
  }

  @override
  String get divers_detail_deleteDialogTitle => 'Eliminare il subacqueo?';

  @override
  String divers_detail_deleteError(Object error) {
    return 'Eliminazione non riuscita: $error';
  }

  @override
  String get divers_detail_deleteMenuItem => 'Elimina';

  @override
  String get divers_detail_deletedSnackbar => 'Subacqueo eliminato';

  @override
  String get divers_detail_diveInsuranceTitle => 'Assicurazione subacquea';

  @override
  String get divers_detail_diveStatisticsTitle => 'Statistiche immersioni';

  @override
  String get divers_detail_editTooltip => 'Modifica subacqueo';

  @override
  String get divers_detail_emergencyContactTitle => 'Contatto di emergenza';

  @override
  String divers_detail_errorPrefix(Object error) {
    return 'Errore: $error';
  }

  @override
  String get divers_detail_expiredBadge => 'Scaduta';

  @override
  String get divers_detail_expiresLabel => 'Scadenza';

  @override
  String get divers_detail_medicalInfoTitle => 'Informazioni mediche';

  @override
  String get divers_detail_medicalNotesLabel => 'Note';

  @override
  String get divers_detail_notFound => 'Subacqueo non trovato';

  @override
  String get divers_detail_notesTitle => 'Note';

  @override
  String get divers_detail_policyNumberLabel => 'N. polizza';

  @override
  String get divers_detail_providerLabel => 'Fornitore';

  @override
  String get divers_detail_setAsDefault => 'Imposta come predefinito';

  @override
  String divers_detail_setAsDefaultSnackbar(Object name) {
    return '$name impostato come subacqueo predefinito';
  }

  @override
  String get divers_detail_switchToTooltip => 'Passa a questo subacqueo';

  @override
  String divers_detail_switchedTo(Object name) {
    return 'Passato a $name';
  }

  @override
  String get divers_detail_totalDivesLabel => 'Immersioni totali';

  @override
  String get divers_detail_unableToLoadStats =>
      'Impossibile caricare le statistiche';

  @override
  String get divers_edit_addButton => 'Aggiungi subacqueo';

  @override
  String get divers_edit_addTitle => 'Aggiungi subacqueo';

  @override
  String get divers_edit_allergiesHint => 'es. Penicillina, Crostacei';

  @override
  String get divers_edit_allergiesLabel => 'Allergie';

  @override
  String get divers_edit_bloodTypeHint => 'es. 0+, A-, B+';

  @override
  String get divers_edit_bloodTypeLabel => 'Gruppo sanguigno';

  @override
  String get divers_edit_cancelButton => 'Annulla';

  @override
  String get divers_edit_clearInsuranceExpiryTooltip =>
      'Cancella data scadenza assicurazione';

  @override
  String get divers_edit_clearMedicalClearanceTooltip =>
      'Cancella data idoneità medica';

  @override
  String get divers_edit_contactNameLabel => 'Nome contatto';

  @override
  String get divers_edit_contactPhoneLabel => 'Telefono contatto';

  @override
  String get divers_edit_discardButton => 'Scarta';

  @override
  String get divers_edit_discardDialogContent =>
      'Hai modifiche non salvate. Sei sicuro di volerle scartare?';

  @override
  String get divers_edit_discardDialogTitle => 'Scartare le modifiche?';

  @override
  String get divers_edit_diverAdded => 'Subacqueo aggiunto';

  @override
  String get divers_edit_diverUpdated => 'Subacqueo aggiornato';

  @override
  String get divers_edit_editTitle => 'Modifica subacqueo';

  @override
  String get divers_edit_emailError => 'Inserisci un\'email valida';

  @override
  String get divers_edit_emailLabel => 'Email';

  @override
  String get divers_edit_emergencyContactsSection => 'Contatti di emergenza';

  @override
  String divers_edit_errorLoading(Object error) {
    return 'Errore nel caricamento del subacqueo: $error';
  }

  @override
  String divers_edit_errorSaving(Object error) {
    return 'Errore nel salvataggio del subacqueo: $error';
  }

  @override
  String get divers_edit_expiryDateNotSet => 'Non impostata';

  @override
  String get divers_edit_expiryDateTitle => 'Data di scadenza';

  @override
  String get divers_edit_insuranceProviderHint => 'es. DAN, DiveAssure';

  @override
  String get divers_edit_insuranceProviderLabel => 'Fornitore assicurazione';

  @override
  String get divers_edit_insuranceSection => 'Assicurazione subacquea';

  @override
  String get divers_edit_keepEditingButton => 'Continua a modificare';

  @override
  String get divers_edit_medicalClearanceExpired => 'Scaduta';

  @override
  String get divers_edit_medicalClearanceExpiringSoon => 'In scadenza';

  @override
  String get divers_edit_medicalClearanceNotSet => 'Non impostata';

  @override
  String get divers_edit_medicalClearanceTitle => 'Scadenza idoneità medica';

  @override
  String get divers_edit_medicalInfoSection => 'Informazioni mediche';

  @override
  String get divers_edit_medicalNotesLabel => 'Note mediche';

  @override
  String get divers_edit_medicationsHint => 'es. Aspirina giornaliera, EpiPen';

  @override
  String get divers_edit_medicationsLabel => 'Farmaci';

  @override
  String get divers_edit_nameError => 'Il nome è obbligatorio';

  @override
  String get divers_edit_nameLabel => 'Nome *';

  @override
  String get divers_edit_notesLabel => 'Note';

  @override
  String get divers_edit_notesSection => 'Note';

  @override
  String get divers_edit_personalInfoSection => 'Informazioni personali';

  @override
  String get divers_edit_phoneLabel => 'Telefono';

  @override
  String get divers_edit_policyNumberLabel => 'Numero polizza';

  @override
  String get divers_edit_primaryContactTitle => 'Contatto principale';

  @override
  String get divers_edit_relationshipHint => 'es. Coniuge, Genitore, Amico';

  @override
  String get divers_edit_relationshipLabel => 'Parentela';

  @override
  String get divers_edit_saveButton => 'Salva';

  @override
  String get divers_edit_secondaryContactTitle => 'Contatto secondario';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip =>
      'Seleziona data scadenza assicurazione';

  @override
  String get divers_edit_selectMedicalClearanceTooltip =>
      'Seleziona data idoneità medica';

  @override
  String get divers_edit_updateButton => 'Aggiorna subacqueo';

  @override
  String get divers_list_activeBadge => 'Attivo';

  @override
  String get divers_list_addDiverButton => 'Aggiungi subacqueo';

  @override
  String get divers_list_addDiverTooltip =>
      'Aggiungi un nuovo profilo subacqueo';

  @override
  String get divers_list_appBarTitle => 'Profili subacquei';

  @override
  String get divers_list_compactTitle => 'Subacquei';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount immersioni$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle =>
      'Aggiungi profili subacquei per tracciare i registri immersione di più persone';

  @override
  String get divers_list_emptyTitle => 'Nessun subacqueo ancora';

  @override
  String divers_list_errorLoading(Object error) {
    return 'Errore nel caricamento dei subacquei: $error';
  }

  @override
  String get divers_list_errorLoadingStats =>
      'Errore nel caricamento delle statistiche';

  @override
  String get divers_list_loadingStats => 'Caricamento...';

  @override
  String get divers_list_retryButton => 'Riprova';

  @override
  String divers_list_viewDiverLabel(Object name) {
    return 'Visualizza subacqueo $name';
  }

  @override
  String get divers_summary_activeDiverTitle => 'Subacqueo attivo';

  @override
  String get divers_summary_otherDiversTitle => 'Altri subacquei';

  @override
  String get divers_summary_overviewTitle => 'Panoramica';

  @override
  String get divers_summary_quickActionsTitle => 'Azioni rapide';

  @override
  String get divers_summary_subtitle =>
      'Seleziona un subacqueo dalla lista per visualizzare i dettagli';

  @override
  String get divers_summary_title => 'Profili subacquei';

  @override
  String get divers_summary_totalDiversLabel => 'Subacquei totali';

  @override
  String divers_detail_deleteDialogConfirmHint(String name) {
    return 'Type \"Delete $name\" to confirm';
  }

  @override
  String divers_detail_deleteDialogConfirmText(String name) {
    return 'Delete $name';
  }

  @override
  String get enum_altitudeGroup_extreme => 'Altitudine estrema';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => 'Gruppo altitudine 1';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => 'Gruppo altitudine 2';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => 'Gruppo altitudine 3';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => 'Livello del mare';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => 'Pericolo';

  @override
  String get enum_ascentRate_safe => 'Sicuro';

  @override
  String get enum_ascentRate_warning => 'Attenzione';

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
  String get enum_certificationAgency_other => 'Altro';

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
  String get enum_certificationLevel_advancedNitrox => 'Nitrox avanzato';

  @override
  String get enum_certificationLevel_advancedOpenWater =>
      'Acque libere avanzato';

  @override
  String get enum_certificationLevel_cave => 'Grotta';

  @override
  String get enum_certificationLevel_cavern => 'Caverna';

  @override
  String get enum_certificationLevel_courseDirector => 'Course Director';

  @override
  String get enum_certificationLevel_decompression => 'Decompressione';

  @override
  String get enum_certificationLevel_diveGuide => 'Guida subacquea';

  @override
  String get enum_certificationLevel_diveMaster => 'Divemaster';

  @override
  String get enum_certificationLevel_instructor => 'Istruttore';

  @override
  String get enum_certificationLevel_masterInstructor => 'Master Instructor';

  @override
  String get enum_certificationLevel_nitrox => 'Nitrox';

  @override
  String get enum_certificationLevel_openWater => 'Acque libere';

  @override
  String get enum_certificationLevel_other => 'Altro';

  @override
  String get enum_certificationLevel_rebreather => 'Rebreather';

  @override
  String get enum_certificationLevel_rescue => 'Soccorso subacqueo';

  @override
  String get enum_certificationLevel_sidemount => 'Sidemount';

  @override
  String get enum_certificationLevel_techDiver => 'Subacqueo tecnico';

  @override
  String get enum_certificationLevel_trimix => 'Trimix';

  @override
  String get enum_certificationLevel_wreck => 'Relitto';

  @override
  String get enum_currentDirection_east => 'Est';

  @override
  String get enum_currentDirection_none => 'Nessuna';

  @override
  String get enum_currentDirection_north => 'Nord';

  @override
  String get enum_currentDirection_northEast => 'Nord-Est';

  @override
  String get enum_currentDirection_northWest => 'Nord-Ovest';

  @override
  String get enum_currentDirection_south => 'Sud';

  @override
  String get enum_currentDirection_southEast => 'Sud-Est';

  @override
  String get enum_currentDirection_southWest => 'Sud-Ovest';

  @override
  String get enum_currentDirection_variable => 'Variabile';

  @override
  String get enum_currentDirection_west => 'Ovest';

  @override
  String get enum_currentStrength_light => 'Leggera';

  @override
  String get enum_currentStrength_moderate => 'Moderata';

  @override
  String get enum_currentStrength_none => 'Nessuna';

  @override
  String get enum_currentStrength_strong => 'Forte';

  @override
  String get enum_diveMode_ccr => 'Rebreather a circuito chiuso';

  @override
  String get enum_diveMode_gauge => 'Gauge';

  @override
  String get enum_diveMode_oc => 'Circuito aperto';

  @override
  String get enum_diveMode_scr => 'Rebreather semi-chiuso';

  @override
  String get enum_diveType_altitude => 'Altitudine';

  @override
  String get enum_diveType_boat => 'Barca';

  @override
  String get enum_diveType_cave => 'Grotta';

  @override
  String get enum_diveType_deep => 'Profonda';

  @override
  String get enum_diveType_drift => 'Corrente';

  @override
  String get enum_diveType_freedive => 'Apnea';

  @override
  String get enum_diveType_ice => 'Ghiaccio';

  @override
  String get enum_diveType_liveaboard => 'Crociera';

  @override
  String get enum_diveType_night => 'Notturna';

  @override
  String get enum_diveType_recreational => 'Ricreativa';

  @override
  String get enum_diveType_shore => 'Da riva';

  @override
  String get enum_diveType_technical => 'Tecnica';

  @override
  String get enum_diveType_training => 'Addestramento';

  @override
  String get enum_diveType_wreck => 'Relitto';

  @override
  String get enum_entryMethod_backRoll => 'Caduta all\'indietro';

  @override
  String get enum_entryMethod_boat => 'Ingresso da barca';

  @override
  String get enum_entryMethod_giantStride => 'Passo del gigante';

  @override
  String get enum_entryMethod_jetty => 'Pontile/Molo';

  @override
  String get enum_entryMethod_ladder => 'Scaletta';

  @override
  String get enum_entryMethod_other => 'Altro';

  @override
  String get enum_entryMethod_platform => 'Piattaforma';

  @override
  String get enum_entryMethod_seatedEntry => 'Ingresso da seduti';

  @override
  String get enum_entryMethod_shore => 'Ingresso da riva';

  @override
  String get enum_equipmentStatus_active => 'Attivo';

  @override
  String get enum_equipmentStatus_inService => 'In assistenza';

  @override
  String get enum_equipmentStatus_loaned => 'In prestito';

  @override
  String get enum_equipmentStatus_lost => 'Perso';

  @override
  String get enum_equipmentStatus_needsService => 'Richiede assistenza';

  @override
  String get enum_equipmentStatus_retired => 'Dismesso';

  @override
  String get enum_equipmentType_bcd => 'Jacket';

  @override
  String get enum_equipmentType_boots => 'Calzari';

  @override
  String get enum_equipmentType_camera => 'Fotocamera';

  @override
  String get enum_equipmentType_dpv => 'DPV';

  @override
  String get enum_equipmentType_computer => 'Computer subacqueo';

  @override
  String get enum_equipmentType_drysuit => 'Muta stagna';

  @override
  String get enum_equipmentType_fins => 'Pinne';

  @override
  String get enum_equipmentType_gloves => 'Guanti';

  @override
  String get enum_equipmentType_hood => 'Cappuccio';

  @override
  String get enum_equipmentType_knife => 'Coltello';

  @override
  String get enum_equipmentType_light => 'Torcia';

  @override
  String get enum_equipmentType_mask => 'Maschera';

  @override
  String get enum_equipmentType_other => 'Altro';

  @override
  String get enum_equipmentType_reel => 'Reel';

  @override
  String get enum_equipmentType_regulator => 'Erogatore';

  @override
  String get enum_equipmentType_smb => 'SMB';

  @override
  String get enum_equipmentType_tank => 'Bombola';

  @override
  String get enum_equipmentType_weights => 'Zavorra';

  @override
  String get enum_equipmentType_wetsuit => 'Muta';

  @override
  String get enum_eventSeverity_alert => 'Allarme';

  @override
  String get enum_eventSeverity_info => 'Info';

  @override
  String get enum_eventSeverity_warning => 'Attenzione';

  @override
  String get enum_pdfPageSize_a4 => 'A4';

  @override
  String get enum_pdfPageSize_a4_description => '210 x 297 mm';

  @override
  String get enum_pdfPageSize_letter => 'Letter';

  @override
  String get enum_pdfPageSize_letter_description => '8.5 x 11 in';

  @override
  String get enum_pdfTemplate_detailed => 'Dettagliato';

  @override
  String get enum_pdfTemplate_detailed_description =>
      'Informazioni complete con note e valutazioni';

  @override
  String get enum_pdfTemplate_nauiStyle => 'Stile NAUI';

  @override
  String get enum_pdfTemplate_nauiStyle_description =>
      'Layout conforme al formato logbook NAUI';

  @override
  String get enum_pdfTemplate_padiStyle => 'Stile PADI';

  @override
  String get enum_pdfTemplate_padiStyle_description =>
      'Layout conforme al formato logbook PADI';

  @override
  String get enum_pdfTemplate_professional => 'Professionale';

  @override
  String get enum_pdfTemplate_professional_description =>
      'Aree per firma e timbro per la verifica';

  @override
  String get enum_pdfTemplate_simple => 'Semplice';

  @override
  String get enum_pdfTemplate_simple_description =>
      'Formato tabella compatto, molte immersioni per pagina';

  @override
  String get enum_profileEvent_alert => 'Allarme';

  @override
  String get enum_profileEvent_ascentRateCritical =>
      'Velocita di risalita critica';

  @override
  String get enum_profileEvent_ascentRateWarning =>
      'Attenzione velocita di risalita';

  @override
  String get enum_profileEvent_ascentStart => 'Inizio risalita';

  @override
  String get enum_profileEvent_bookmark => 'Segnalibro';

  @override
  String get enum_profileEvent_cnsCritical => 'CNS critico';

  @override
  String get enum_profileEvent_cnsWarning => 'Attenzione CNS';

  @override
  String get enum_profileEvent_decoStopEnd => 'Fine sosta deco';

  @override
  String get enum_profileEvent_decoStopStart => 'Inizio sosta deco';

  @override
  String get enum_profileEvent_decoViolation => 'Violazione deco';

  @override
  String get enum_profileEvent_gasSwitch => 'Cambio gas';

  @override
  String get enum_profileEvent_lowGas => 'Avviso gas scarso';

  @override
  String get enum_profileEvent_maxDepth => 'Profondita massima';

  @override
  String get enum_profileEvent_missedStop => 'Sosta deco mancata';

  @override
  String get enum_profileEvent_note => 'Nota';

  @override
  String get enum_profileEvent_ppO2High => 'ppO2 alto';

  @override
  String get enum_profileEvent_ppO2Low => 'ppO2 basso';

  @override
  String get enum_profileEvent_safetyStopEnd => 'Fine sosta di sicurezza';

  @override
  String get enum_profileEvent_safetyStopStart => 'Inizio sosta di sicurezza';

  @override
  String get enum_profileEvent_setpointChange => 'Cambio setpoint';

  @override
  String get enum_profileMetricCategory_decompression => 'Decompressione';

  @override
  String get enum_profileMetricCategory_gasAnalysis => 'Analisi gas';

  @override
  String get enum_profileMetricCategory_gradientFactor =>
      'Fattori di gradiente';

  @override
  String get enum_profileMetricCategory_other => 'Altro';

  @override
  String get enum_profileMetricCategory_primary => 'Metriche principali';

  @override
  String get enum_profileMetric_gasDensity => 'Densita del gas';

  @override
  String get enum_profileMetric_gasDensity_short => 'Densita';

  @override
  String get enum_profileMetric_gf => 'GF%';

  @override
  String get enum_profileMetric_gf_short => 'GF%';

  @override
  String get enum_profileMetric_heartRate => 'Frequenza cardiaca';

  @override
  String get enum_profileMetric_heartRate_short => 'FC';

  @override
  String get enum_profileMetric_meanDepth => 'Profondita media';

  @override
  String get enum_profileMetric_meanDepth_short => 'Media';

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
  String get enum_profileMetric_pressure => 'Pressione';

  @override
  String get enum_profileMetric_pressure_short => 'Press';

  @override
  String get enum_profileMetric_sacRate => 'Consumo SAC';

  @override
  String get enum_profileMetric_sacRate_short => 'SAC';

  @override
  String get enum_profileMetric_surfaceGf => 'GF superficie';

  @override
  String get enum_profileMetric_surfaceGf_short => 'SrfGF';

  @override
  String get enum_profileMetric_temperature => 'Temperatura';

  @override
  String get enum_profileMetric_temperature_short => 'Temp';

  @override
  String get enum_profileMetric_tts => 'TTS';

  @override
  String get enum_profileMetric_tts_short => 'TTS';

  @override
  String get enum_scrType_cmf => 'Flusso di massa costante';

  @override
  String get enum_scrType_cmf_short => 'CMF';

  @override
  String get enum_scrType_escr => 'Controllo elettronico';

  @override
  String get enum_scrType_escr_short => 'ESCR';

  @override
  String get enum_scrType_pascr => 'Addizione passiva';

  @override
  String get enum_scrType_pascr_short => 'PASCR';

  @override
  String get enum_serviceType_annual => 'Revisione annuale';

  @override
  String get enum_serviceType_calibration => 'Calibrazione';

  @override
  String get enum_serviceType_cleaning => 'Pulizia';

  @override
  String get enum_serviceType_inspection => 'Ispezione';

  @override
  String get enum_serviceType_other => 'Altro';

  @override
  String get enum_serviceType_overhaul => 'Revisione completa';

  @override
  String get enum_serviceType_recall => 'Richiamo/Sicurezza';

  @override
  String get enum_serviceType_repair => 'Riparazione';

  @override
  String get enum_serviceType_replacement => 'Sostituzione componente';

  @override
  String get enum_serviceType_warranty => 'Assistenza in garanzia';

  @override
  String get enum_sortDirection_ascending => 'Crescente';

  @override
  String get enum_sortDirection_descending => 'Decrescente';

  @override
  String get enum_sortField_agency => 'Agenzia';

  @override
  String get enum_sortField_date => 'Data';

  @override
  String get enum_sortField_dateIssued => 'Data di rilascio';

  @override
  String get enum_sortField_dateTaken => 'Data dello scatto';

  @override
  String get enum_sortField_difficulty => 'Difficolta';

  @override
  String get enum_sortField_diveCount => 'Numero di immersioni';

  @override
  String get enum_sortField_diveNumber => 'Numero immersione';

  @override
  String get enum_sortField_duration => 'Durata';

  @override
  String get enum_sortField_endDate => 'Data di fine';

  @override
  String get enum_sortField_fileName => 'Nome file';

  @override
  String get enum_sortField_fileSize => 'Dimensione file';

  @override
  String get enum_sortField_lastServiceDate => 'Ultima revisione';

  @override
  String get enum_sortField_maxDepth => 'Profondita massima';

  @override
  String get enum_sortField_name => 'Nome';

  @override
  String get enum_sortField_purchaseDate => 'Data di acquisto';

  @override
  String get enum_sortField_rating => 'Valutazione';

  @override
  String get enum_sortField_site => 'Sito';

  @override
  String get enum_sortField_startDate => 'Data di inizio';

  @override
  String get enum_sortField_status => 'Stato';

  @override
  String get enum_sortField_type => 'Tipo';

  @override
  String get enum_speciesCategory_coral => 'Corallo';

  @override
  String get enum_speciesCategory_fish => 'Pesce';

  @override
  String get enum_speciesCategory_invertebrate => 'Invertebrato';

  @override
  String get enum_speciesCategory_mammal => 'Mammifero';

  @override
  String get enum_speciesCategory_other => 'Altro';

  @override
  String get enum_speciesCategory_plant => 'Pianta/Alga';

  @override
  String get enum_speciesCategory_ray => 'Razza';

  @override
  String get enum_speciesCategory_shark => 'Squalo';

  @override
  String get enum_speciesCategory_turtle => 'Tartaruga';

  @override
  String get enum_tankMaterial_aluminum => 'Alluminio';

  @override
  String get enum_tankMaterial_carbonFiber => 'Fibra di carbonio';

  @override
  String get enum_tankMaterial_steel => 'Acciaio';

  @override
  String get enum_tankRole_backGas => 'Gas principale';

  @override
  String get enum_tankRole_bailout => 'Bailout';

  @override
  String get enum_tankRole_deco => 'Deco';

  @override
  String get enum_tankRole_diluent => 'Diluente';

  @override
  String get enum_tankRole_oxygenSupply => 'Riserva O2';

  @override
  String get enum_tankRole_pony => 'Pony bottle';

  @override
  String get enum_tankRole_sidemountLeft => 'Sidemount sinistra';

  @override
  String get enum_tankRole_sidemountRight => 'Sidemount destra';

  @override
  String get enum_tankRole_stage => 'Stage';

  @override
  String get enum_visibility_excellent => 'Eccellente (>30m / >100ft)';

  @override
  String get enum_visibility_good => 'Buona (15-30m / 50-100ft)';

  @override
  String get enum_visibility_moderate => 'Moderata (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => 'Scarsa (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => 'Sconosciuta';

  @override
  String get enum_waterType_brackish => 'Salmastra';

  @override
  String get enum_waterType_fresh => 'Acqua dolce';

  @override
  String get enum_waterType_salt => 'Acqua salata';

  @override
  String get enum_weightType_ankleWeights => 'Pesi alle caviglie';

  @override
  String get enum_weightType_backplate => 'Pesi sulla piastra dorsale';

  @override
  String get enum_weightType_belt => 'Cintura di zavorra';

  @override
  String get enum_weightType_integrated => 'Zavorra integrata';

  @override
  String get enum_weightType_mixed => 'Mista/Combinata';

  @override
  String get enum_weightType_trimWeights => 'Pesi di trim';

  @override
  String get equipment_appBar_title => 'Attrezzatura';

  @override
  String get equipment_deleteDialog_cancel => 'Annulla';

  @override
  String get equipment_deleteDialog_confirm => 'Elimina';

  @override
  String get equipment_deleteDialog_content =>
      'Sei sicuro di voler eliminare questa attrezzatura? Questa azione non puo essere annullata.';

  @override
  String get equipment_deleteDialog_title => 'Elimina attrezzatura';

  @override
  String get equipment_detail_brandLabel => 'Marca';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return '$days giorni di ritardo';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days giorni alla manutenzione';
  }

  @override
  String get equipment_detail_detailsTitle => 'Dettagli';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count immersioni';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count immersione';
  }

  @override
  String get equipment_detail_divesLabel => 'Immersioni';

  @override
  String get equipment_detail_divesSemanticLabel =>
      'Visualizza immersioni con questa attrezzatura';

  @override
  String equipment_detail_durationDays(Object days) {
    return '$days giorni';
  }

  @override
  String equipment_detail_durationMonths(Object months) {
    return '$months mesi';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralPlural(
    Object years,
    Object months,
  ) {
    return '$years anni, $months mesi';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralSingular(
    Object years,
    Object months,
  ) {
    return '$years anni, $months mese';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularPlural(
    Object years,
    Object months,
  ) {
    return '$years anno, $months mesi';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularSingular(
    Object years,
    Object months,
  ) {
    return '$years anno, $months mese';
  }

  @override
  String equipment_detail_durationYearsPlural(Object years) {
    return '$years anni';
  }

  @override
  String equipment_detail_durationYearsSingular(Object years) {
    return '$years anno';
  }

  @override
  String get equipment_detail_editTooltip => 'Modifica attrezzatura';

  @override
  String get equipment_detail_editTooltipShort => 'Modifica';

  @override
  String equipment_detail_errorMessage(Object error) {
    return 'Errore: $error';
  }

  @override
  String get equipment_detail_errorTitle => 'Errore';

  @override
  String get equipment_detail_lastServiceLabel => 'Ultima manutenzione';

  @override
  String get equipment_detail_loadingTitle => 'Caricamento...';

  @override
  String get equipment_detail_modelLabel => 'Modello';

  @override
  String get equipment_detail_nextServiceDueLabel =>
      'Prossima manutenzione prevista';

  @override
  String get equipment_detail_notFoundMessage =>
      'Questa attrezzatura non esiste piu.';

  @override
  String get equipment_detail_notFoundTitle => 'Attrezzatura non trovata';

  @override
  String get equipment_detail_notesTitle => 'Note';

  @override
  String get equipment_detail_ownedForLabel => 'Posseduto da';

  @override
  String get equipment_detail_purchaseDateLabel => 'Data di acquisto';

  @override
  String get equipment_detail_purchasePriceLabel => 'Prezzo di acquisto';

  @override
  String get equipment_detail_retiredChip => 'Ritirato';

  @override
  String get equipment_detail_serialNumberLabel => 'Numero di serie';

  @override
  String get equipment_detail_serviceInfoTitle => 'Informazioni manutenzione';

  @override
  String get equipment_serviceClocks_title => 'Scadenze di manutenzione';

  @override
  String get equipment_serviceClocks_addClock => 'Aggiungi scadenza';

  @override
  String get equipment_serviceClocks_logService => 'Registra manutenzione';

  @override
  String get equipment_serviceClocks_edit => 'Modifica intervalli';

  @override
  String get equipment_serviceClocks_pause => 'Sospendi';

  @override
  String get equipment_serviceClocks_resume => 'Riprendi';

  @override
  String get equipment_serviceClocks_remove => 'Rimuovi';

  @override
  String get equipment_serviceClocks_paused => 'In pausa';

  @override
  String get equipment_serviceClocks_empty =>
      'Nessuna scadenza di manutenzione';

  @override
  String get equipment_serviceClocks_unconfigured =>
      'Nessun intervallo impostato - tocca per configurare';

  @override
  String equipment_serviceClocks_dueOn(String date) {
    return 'Scade il $date';
  }

  @override
  String equipment_serviceClocks_overdueSince(String date) {
    return 'In ritardo dal $date';
  }

  @override
  String get equipment_serviceClocks_overdue => 'In ritardo';

  @override
  String equipment_serviceClocks_divesLeft(int remaining, int total) {
    return '$remaining immersioni rimanenti su $total';
  }

  @override
  String get cylinderConfigs_title => 'Configurazioni bombole';

  @override
  String get cylinderConfigs_empty => 'Nessuna configurazione';

  @override
  String get cylinderConfigs_emptyBody =>
      'Salva una volta un assetto diluente e bailout, poi applicalo a qualsiasi immersione.';

  @override
  String get cylinderConfigs_new => 'Nuova configurazione';

  @override
  String get cylinderConfigs_name => 'Nome';

  @override
  String get cylinderConfigs_nameRequired => 'Inserisci un nome';

  @override
  String get cylinderConfigs_forUnit => 'Per unità';

  @override
  String get cylinderConfigs_noUnit => 'Piano gas generico';

  @override
  String get cylinderConfigs_gasPlans => 'Piani gas';

  @override
  String get cylinderConfigs_addCylinder => 'Aggiungi bombola';

  @override
  String get cylinderConfigs_role => 'Ruolo';

  @override
  String get cylinderConfigs_startPressure => 'Pressione iniziale';

  @override
  String get cylinderConfigs_label => 'Etichetta';

  @override
  String get cylinderConfigs_fromPreset => 'Da preimpostazione';

  @override
  String get cylinderConfigs_deleteTitle => 'Eliminare la configurazione?';

  @override
  String get cylinderConfigs_deleteBody =>
      'Le immersioni a cui è già stata applicata non cambiano.';

  @override
  String get cylinderConfigs_applyAction => 'Applica configurazione';

  @override
  String cylinderConfigs_applyAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bombole aggiunte',
      one: '1 bombola aggiunta',
    );
    return '$_temp0';
  }

  @override
  String cylinderConfigs_applyKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mantenute',
      one: '1 mantenuta',
    );
    return '$_temp0';
  }

  @override
  String get cylinderConfigs_applyNothingToDo =>
      'Questa immersione corrisponde già alla configurazione';

  @override
  String get cylinderConfigs_sectionTitle => 'Configurazioni';

  @override
  String get equipment_serviceClocks_hoursSource =>
      'Calcolato dal tempo di immersione registrato';

  @override
  String equipment_serviceClocks_hoursLeft(String remaining, String total) {
    return '$remaining ore rimanenti su $total';
  }

  @override
  String get equipment_serviceClocks_manageKinds =>
      'Gestisci tipi di manutenzione';

  @override
  String get equipment_serviceClocks_appliesToClock =>
      'Si applica alla scadenza';

  @override
  String get equipment_serviceClocks_noClockOption =>
      'Non collegato a una scadenza';

  @override
  String get equipment_scheduleDialog_title => 'Modifica scadenza';

  @override
  String get equipment_scheduleDialog_intervalDays => 'Intervallo (giorni)';

  @override
  String get equipment_scheduleDialog_intervalDives =>
      'Intervallo (immersioni)';

  @override
  String get equipment_scheduleDialog_intervalHours => 'Intervallo (ore)';

  @override
  String equipment_scheduleDialog_inheritHint(String value) {
    return 'Predefinito: $value';
  }

  @override
  String get equipment_scheduleDialog_anchorDate => 'Data di riferimento';

  @override
  String get equipment_scheduleDialog_anchorHint =>
      'Usata quando non esiste ancora alcuna registrazione di manutenzione di questo tipo';

  @override
  String get equipment_scheduleDialog_clearAnchor =>
      'Cancella data di riferimento';

  @override
  String get equipment_scheduleDialog_save => 'Salva';

  @override
  String get equipment_scheduleDialog_cancel => 'Annulla';

  @override
  String get equipment_serviceKinds_title => 'Tipi di manutenzione';

  @override
  String get equipment_serviceKinds_builtIn => 'Predefiniti';

  @override
  String get equipment_serviceKinds_custom => 'Personalizzati';

  @override
  String get equipment_serviceKinds_add => 'Aggiungi tipo di manutenzione';

  @override
  String get equipment_serviceKinds_editTitle =>
      'Modifica tipo di manutenzione';

  @override
  String get equipment_serviceKinds_nameLabel => 'Nome';

  @override
  String get equipment_serviceKinds_nameRequired => 'Il nome è obbligatorio';

  @override
  String get equipment_serviceKinds_appliesTo => 'Si applica a';

  @override
  String get equipment_serviceKinds_autoAttach =>
      'Associa automaticamente alla nuova attrezzatura';

  @override
  String get equipment_serviceKinds_deleteConfirmTitle =>
      'Eliminare il tipo di manutenzione?';

  @override
  String get equipment_serviceKinds_deleteConfirmBody =>
      'Le scadenze che usano questo tipo di manutenzione verranno rimosse.';

  @override
  String get equipment_serviceKinds_delete => 'Elimina';

  @override
  String get equipment_serviceKinds_cancel => 'Annulla';

  @override
  String get equipment_serviceKinds_save => 'Salva';

  @override
  String get equipment_serviceKinds_emptyCustom =>
      'Ancora nessun tipo di manutenzione personalizzato';

  @override
  String equipment_serviceKinds_everyDays(int days) {
    return 'ogni $days giorni';
  }

  @override
  String equipment_serviceKinds_everyDives(int dives) {
    return 'ogni $dives immersioni';
  }

  @override
  String equipment_serviceKinds_everyHours(String hours) {
    return 'ogni $hours ore';
  }

  @override
  String get dashboard_serviceDue_title => 'Manutenzione in scadenza';

  @override
  String dashboard_serviceDue_more(int count) {
    return '+$count altri';
  }

  @override
  String dashboard_alerts_clockDue(String name, String kind) {
    return '$name: $kind in scadenza';
  }

  @override
  String dashboard_alerts_clockOverdue(String name, String kind) {
    return '$name: $kind in ritardo';
  }

  @override
  String equipment_list_worstClock(String kind) {
    return '$kind in ritardo';
  }

  @override
  String trips_serviceAlert_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count attrezzature necessitano di manutenzione prima di questo viaggio',
      one: '1 attrezzatura necessita di manutenzione prima di questo viaggio',
    );
    return '$_temp0';
  }

  @override
  String trips_serviceAlert_dueBefore(String kind, String date) {
    return '$kind in scadenza il $date';
  }

  @override
  String trips_serviceAlert_overdue(String kind) {
    return '$kind in ritardo';
  }

  @override
  String get settings_notifications_tripLeadTitle =>
      'Preavviso di manutenzione per i viaggi';

  @override
  String settings_notifications_tripLeadDays(int days) {
    return '$days giorni prima di un viaggio';
  }

  @override
  String get equipment_detail_serviceIntervalLabel => 'Intervallo manutenzione';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days giorni';
  }

  @override
  String get equipment_detail_serviceOverdue => 'Manutenzione scaduta!';

  @override
  String get equipment_detail_sizeLabel => 'Taglia';

  @override
  String get equipment_detail_thicknessLabel => 'Spessore';

  @override
  String get equipment_detail_statusLabel => 'Stato';

  @override
  String equipment_detail_tripsCountPlural(Object count) {
    return '$count viaggi';
  }

  @override
  String equipment_detail_tripsCountSingular(Object count) {
    return '$count viaggio';
  }

  @override
  String get equipment_detail_tripsLabel => 'Viaggi';

  @override
  String get equipment_detail_tripsSemanticLabel =>
      'Visualizza viaggi con questa attrezzatura';

  @override
  String get equipment_edit_appBar_editTitle => 'Modifica attrezzatura';

  @override
  String get equipment_edit_appBar_newTitle => 'Nuova attrezzatura';

  @override
  String get equipment_edit_appBar_saveButton => 'Salva';

  @override
  String get equipment_edit_appBar_saveTooltip =>
      'Salva modifiche attrezzatura';

  @override
  String get equipment_edit_brandLabel => 'Marca';

  @override
  String get equipment_edit_clearDate => 'Cancella data';

  @override
  String get equipment_edit_currencyLabel => 'Valuta';

  @override
  String get equipment_edit_disableReminders => 'Disabilita promemoria';

  @override
  String get equipment_edit_disableRemindersSubtitle =>
      'Disattiva tutte le notifiche per questo articolo';

  @override
  String get equipment_edit_discardDialog_content =>
      'Hai modifiche non salvate. Sei sicuro di voler uscire?';

  @override
  String get equipment_edit_discardDialog_discard => 'Scarta';

  @override
  String get equipment_edit_discardDialog_keepEditing =>
      'Continua a modificare';

  @override
  String get equipment_edit_discardDialog_title => 'Scartare le modifiche?';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => 'Annulla';

  @override
  String get equipment_edit_embeddedHeader_editTitle => 'Modifica attrezzatura';

  @override
  String get equipment_edit_embeddedHeader_newTitle => 'Nuova attrezzatura';

  @override
  String get equipment_edit_embeddedHeader_saveButton => 'Salva';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit =>
      'Salva modifiche attrezzatura';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new =>
      'Aggiungi nuova attrezzatura';

  @override
  String equipment_edit_errorMessage(Object error) {
    return 'Errore: $error';
  }

  @override
  String get equipment_edit_errorTitle => 'Errore';

  @override
  String get equipment_edit_lastServiceDateLabel => 'Data ultima manutenzione';

  @override
  String get equipment_edit_loadingTitle => 'Caricamento...';

  @override
  String get equipment_edit_modelLabel => 'Modello';

  @override
  String get equipment_edit_nameHint => 'es. Il mio erogatore principale';

  @override
  String get equipment_edit_nameLabel => 'Nome *';

  @override
  String get equipment_edit_nameValidation => 'Inserisci un nome';

  @override
  String get equipment_edit_notFoundMessage =>
      'Questa attrezzatura non esiste piu.';

  @override
  String get equipment_edit_notFoundTitle => 'Attrezzatura non trovata';

  @override
  String get equipment_edit_notesHint =>
      'Note aggiuntive su questa attrezzatura...';

  @override
  String get equipment_edit_notesLabel => 'Note';

  @override
  String get equipment_edit_notificationsSubtitle =>
      'Sovrascrivi le impostazioni globali delle notifiche per questo articolo';

  @override
  String get equipment_edit_notificationsTitle => 'Notifiche (opzionale)';

  @override
  String get equipment_edit_purchaseDateLabel => 'Data di acquisto';

  @override
  String get equipment_edit_purchaseInfoTitle => 'Informazioni acquisto';

  @override
  String get equipment_edit_purchasePriceLabel => 'Prezzo di acquisto';

  @override
  String get equipment_edit_purchasePriceValidation =>
      'Inserisci un importo valido';

  @override
  String get equipment_edit_remindMeBeforeServiceDue =>
      'Ricordami prima della scadenza della manutenzione:';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days giorni';
  }

  @override
  String get equipment_edit_saveButton_edit => 'Salva modifiche';

  @override
  String get equipment_edit_saveButton_new => 'Aggiungi attrezzatura';

  @override
  String get equipment_edit_saveTooltip_edit => 'Salva modifiche attrezzatura';

  @override
  String get equipment_edit_saveTooltip_new =>
      'Aggiungi nuovo articolo di attrezzatura';

  @override
  String get equipment_edit_selectDate => 'Seleziona data';

  @override
  String get equipment_edit_serialNumberLabel => 'Numero di serie';

  @override
  String get equipment_edit_serviceIntervalHint => 'es. 365 per annuale';

  @override
  String get equipment_edit_serviceIntervalLabel =>
      'Intervallo manutenzione (giorni)';

  @override
  String get equipment_edit_serviceSettingsTitle => 'Impostazioni manutenzione';

  @override
  String get equipment_edit_sizeHint => 'es. M, L, 42';

  @override
  String get equipment_edit_sizeLabel => 'Taglia';

  @override
  String get equipment_edit_snackbar_added => 'Attrezzatura aggiunta';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return 'Errore nel salvataggio dell\'attrezzatura: $error';
  }

  @override
  String get equipment_edit_snackbar_updated => 'Attrezzatura aggiornata';

  @override
  String get equipment_edit_statusLabel => 'Stato';

  @override
  String get equipment_edit_thicknessDesignationHint => 'es: 5, 5/4, 7/5/3';

  @override
  String get equipment_edit_thicknessHint => 'es: 5mm, 7mm';

  @override
  String get equipment_edit_thicknessLabel => 'Spessore';

  @override
  String get equipment_edit_typeLabel => 'Tipo *';

  @override
  String get equipment_edit_useCustomReminders =>
      'Usa promemoria personalizzati';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'Imposta giorni di promemoria diversi per questo articolo';

  @override
  String get equipment_fab_addEquipment => 'Aggiungi attrezzatura';

  @override
  String get equipment_fab_addSet => 'Aggiungi set';

  @override
  String get equipment_list_emptyState_addFirstButton =>
      'Aggiungi la tua prima attrezzatura';

  @override
  String get equipment_list_emptyState_addPrompt =>
      'Aggiungi la tua attrezzatura subacquea per monitorare utilizzo e manutenzione';

  @override
  String get equipment_list_emptyState_filterText_equipment => 'attrezzatura';

  @override
  String get equipment_list_emptyState_filterText_serviceDue =>
      'attrezzatura che necessita manutenzione';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return 'attrezzatura $status';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return 'Nessuna $filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch =>
      'Nessuna attrezzatura con questo stato';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate =>
      'Tutta la tua attrezzatura e in regola con la manutenzione!';

  @override
  String equipment_list_errorLoading(Object error) {
    return 'Errore nel caricamento dell\'attrezzatura: $error';
  }

  @override
  String get equipment_list_filterAll => 'Tutta l\'attrezzatura';

  @override
  String get equipment_list_filterLabel => 'Filtro:';

  @override
  String get equipment_list_filterServiceDue => 'Manutenzione prevista';

  @override
  String get equipment_list_retryButton => 'Riprova';

  @override
  String get equipment_list_searchTooltip => 'Cerca attrezzatura';

  @override
  String get equipment_list_setsTooltip => 'Set di attrezzatura';

  @override
  String get equipment_list_sortTitle => 'Ordina attrezzatura';

  @override
  String get equipment_list_sortTooltip => 'Ordina';

  @override
  String equipment_list_tile_daysCount(Object days) {
    return '$days giorni';
  }

  @override
  String equipment_list_tile_serviceInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Manutenzione tra $days giorni',
      one: 'Manutenzione tra 1 giorno',
    );
    return '$_temp0';
  }

  @override
  String get equipment_list_tile_serviceDueChip => 'Manutenzione prevista';

  @override
  String get equipment_list_tile_serviceIn => 'Manutenzione tra';

  @override
  String get equipment_menu_delete => 'Elimina';

  @override
  String get equipment_menu_markAsServiced => 'Segna come revisionato';

  @override
  String get equipment_menu_reactivate => 'Riattiva';

  @override
  String get equipment_menu_retireEquipment => 'Ritira attrezzatura';

  @override
  String get equipment_search_backTooltip => 'Indietro';

  @override
  String get equipment_search_clearTooltip => 'Cancella ricerca';

  @override
  String get equipment_search_fieldLabel => 'Cerca attrezzatura...';

  @override
  String get equipment_search_hint =>
      'Cerca per nome, marca, modello o numero di serie';

  @override
  String equipment_search_noResults(Object query) {
    return 'Nessuna attrezzatura trovata per \"$query\"';
  }

  @override
  String get equipment_serviceDialog_addButton => 'Aggiungi';

  @override
  String get equipment_serviceDialog_addTitle =>
      'Aggiungi registro manutenzione';

  @override
  String get equipment_serviceDialog_cancelButton => 'Annulla';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip =>
      'Cancella data prossima manutenzione';

  @override
  String get equipment_serviceDialog_costHint => '0.00';

  @override
  String get equipment_serviceDialog_costLabel => 'Costo';

  @override
  String get equipment_serviceDialog_currencyLabel => 'Valuta';

  @override
  String get equipment_serviceDialog_costValidation =>
      'Inserisci un importo valido';

  @override
  String get equipment_serviceDialog_editTitle =>
      'Modifica registro manutenzione';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel =>
      'Prossima manutenzione prevista';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel =>
      'Seleziona data prossima manutenzione';

  @override
  String get equipment_serviceDialog_nextServiceNotSet => 'Non impostata';

  @override
  String get equipment_serviceDialog_notesLabel => 'Note';

  @override
  String get equipment_serviceDialog_providerHint => 'es. Nome del centro sub';

  @override
  String get equipment_serviceDialog_providerLabel => 'Fornitore/Negozio';

  @override
  String get equipment_serviceDialog_serviceDateLabel => 'Data manutenzione';

  @override
  String get equipment_serviceDialog_serviceDateSemanticLabel =>
      'Seleziona data manutenzione';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => 'Tipo di manutenzione';

  @override
  String get equipment_serviceDialog_serviceTypeHelper =>
      'Registrarla azzera il contatore di questo tipo di manutenzione';

  @override
  String get equipment_serviceDialog_serviceTypeRequired =>
      'Scegli un tipo di manutenzione';

  @override
  String get equipment_serviceDialog_serviceTypeNotSet => 'Non impostato';

  @override
  String get equipment_serviceDialog_categoryHelper =>
      'Usata per filtri ed esportazione';

  @override
  String get equipment_serviceDialog_manageServiceTypes =>
      'Gestisci tipi di manutenzione';

  @override
  String get equipment_serviceDialog_categoryLabel => 'Categoria';

  @override
  String get equipment_serviceDialog_snackbar_added =>
      'Registro manutenzione aggiunto';

  @override
  String equipment_serviceDialog_snackbar_error(Object error) {
    return 'Errore: $error';
  }

  @override
  String get equipment_serviceDialog_snackbar_updated =>
      'Registro manutenzione aggiornato';

  @override
  String get equipment_serviceDialog_updateButton => 'Aggiorna';

  @override
  String get equipment_serviceCategory_annual => 'Manutenzione annuale';

  @override
  String get equipment_serviceCategory_repair => 'Riparazione';

  @override
  String get equipment_serviceCategory_inspection => 'Ispezione';

  @override
  String get equipment_serviceCategory_overhaul => 'Revisione generale';

  @override
  String get equipment_serviceCategory_replacement => 'Sostituzione ricambi';

  @override
  String get equipment_serviceCategory_cleaning => 'Pulizia';

  @override
  String get equipment_serviceCategory_calibration => 'Calibrazione';

  @override
  String get equipment_serviceCategory_warranty => 'Assistenza in garanzia';

  @override
  String get equipment_serviceCategory_recall => 'Richiamo/Sicurezza';

  @override
  String get equipment_serviceCategory_other => 'Altro';

  @override
  String get equipment_service_addButton => 'Aggiungi';

  @override
  String get equipment_service_deleteDialog_cancel => 'Annulla';

  @override
  String get equipment_service_deleteDialog_confirm => 'Elimina';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return 'Sei sicuro di voler eliminare questo registro di $serviceType?';
  }

  @override
  String get equipment_service_deleteDialog_title =>
      'Eliminare registro manutenzione?';

  @override
  String get equipment_service_deleteMenuItem => 'Elimina';

  @override
  String get equipment_service_editMenuItem => 'Modifica';

  @override
  String get equipment_service_emptyState => 'Nessun registro manutenzione';

  @override
  String get equipment_service_historyTitle => 'Storico manutenzioni';

  @override
  String equipment_service_nextDueLabel(String date) {
    return 'Prossima scadenza $date';
  }

  @override
  String get equipment_service_filterTaskAll => 'Tutte le attività';

  @override
  String get equipment_service_filterTypeAll => 'Tutti i tipi';

  @override
  String get equipment_service_filterYearAll => 'Tutti gli anni';

  @override
  String get equipment_service_filterUntagged =>
      'Non associato a un intervallo';

  @override
  String get equipment_service_filterClear => 'Azzera filtro';

  @override
  String get equipment_service_filterNoMatches =>
      'Nessuna manutenzione corrisponde a questo filtro';

  @override
  String equipment_service_filterMatchCount(int count, int total) {
    return '$count di $total mostrati';
  }

  @override
  String get equipment_serviceKinds_defaultCategoryLabel =>
      'Categoria predefinita';

  @override
  String get equipment_serviceKinds_defaultCategoryNone =>
      'Nessuna predefinita';

  @override
  String get equipment_serviceKinds_defaultCostLabel => 'Prezzo predefinito';

  @override
  String get equipment_serviceKinds_defaultCostHint =>
      'Lascia vuoto per nessun valore predefinito';

  @override
  String get equipment_scheduleDialog_defaultCostLabel =>
      'Prezzo predefinito per questa attrezzatura';

  @override
  String get equipment_serviceKinds_defaultCurrencyLabel => 'Valuta';

  @override
  String get equipment_service_exportMenuItem =>
      'Esporta registro di manutenzione';

  @override
  String get transfer_export_maintenanceTitle => 'Registro di manutenzione';

  @override
  String get transfer_export_maintenanceSubtitle =>
      'Cronologia di manutenzione di tutta l\'attrezzatura come foglio di calcolo';

  @override
  String get settings_export_progress_maintenance =>
      'Esportazione del registro di manutenzione...';

  @override
  String get settings_export_success_maintenance =>
      'Registro di manutenzione esportato';

  @override
  String get settings_export_saved_maintenance =>
      'Registro di manutenzione salvato';

  @override
  String get equipment_serviceKinds_defaultCurrencyInherit =>
      'Usa la valuta predefinita';

  @override
  String get equipment_scheduleDialog_defaultCurrencyLabel =>
      'Valuta per questa attrezzatura';

  @override
  String get equipment_service_snackbar_deleted =>
      'Registro manutenzione eliminato';

  @override
  String get equipment_service_totalCostLabel => 'Costo totale manutenzione';

  @override
  String get equipment_setDetail_addEquipmentButton => 'Aggiungi attrezzatura';

  @override
  String get equipment_setDetail_deleteDialog_cancel => 'Annulla';

  @override
  String get equipment_setDetail_deleteDialog_confirm => 'Elimina';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      'Sei sicuro di voler eliminare questo set di attrezzatura? Gli articoli nel set non verranno eliminati.';

  @override
  String get equipment_setDetail_deleteDialog_title =>
      'Elimina set di attrezzatura';

  @override
  String get equipment_setDetail_deleteMenuItem => 'Elimina';

  @override
  String get equipment_setDetail_editTooltip => 'Modifica set';

  @override
  String get equipment_setDetail_emptySet =>
      'Nessuna attrezzatura in questo set';

  @override
  String get equipment_setDetail_equipmentInSetTitle =>
      'Attrezzatura in questo set';

  @override
  String equipment_setDetail_errorMessage(Object error) {
    return 'Errore: $error';
  }

  @override
  String get equipment_setDetail_errorTitle => 'Errore';

  @override
  String get equipment_setDetail_loadingTitle => 'Caricamento...';

  @override
  String get equipment_setDetail_notFoundMessage =>
      'Questo set di attrezzatura non esiste piu.';

  @override
  String get equipment_setDetail_notFoundTitle => 'Set non trovato';

  @override
  String get equipment_setDetail_snackbar_deleted =>
      'Set di attrezzatura eliminato';

  @override
  String get equipment_setEdit_addEquipmentFirst =>
      'Aggiungi prima dell\'attrezzatura prima di creare un set.';

  @override
  String get equipment_setEdit_appBar_editTitle => 'Modifica set';

  @override
  String get equipment_setEdit_appBar_newTitle => 'Nuovo set di attrezzatura';

  @override
  String get equipment_setEdit_descriptionHint => 'Descrizione opzionale...';

  @override
  String get equipment_setEdit_descriptionLabel => 'Descrizione';

  @override
  String equipment_setEdit_errorMessage(Object error) {
    return 'Errore: $error';
  }

  @override
  String get equipment_setEdit_errorTitle => 'Errore';

  @override
  String get equipment_setEdit_loadingTitle => 'Caricamento...';

  @override
  String get equipment_setEdit_nameHint => 'es. Configurazione acque calde';

  @override
  String get equipment_setEdit_nameLabel => 'Nome del set *';

  @override
  String get equipment_setEdit_nameValidation => 'Inserisci un nome';

  @override
  String get equipment_setEdit_noEquipmentAvailable =>
      'Nessuna attrezzatura disponibile';

  @override
  String get equipment_setEdit_notFoundMessage =>
      'Questo set di attrezzatura non esiste piu.';

  @override
  String get equipment_setEdit_notFoundTitle => 'Set non trovato';

  @override
  String get equipment_setEdit_saveButton_edit => 'Salva modifiche';

  @override
  String get equipment_setEdit_saveButton_new => 'Crea set';

  @override
  String get equipment_setEdit_saveTooltip_edit =>
      'Salva modifiche al set di attrezzatura';

  @override
  String get equipment_setEdit_saveTooltip_new =>
      'Crea nuovo set di attrezzatura';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle =>
      'Scegli gli articoli di attrezzatura da includere in questo set.';

  @override
  String get equipment_setEdit_selectEquipmentTitle => 'Seleziona attrezzatura';

  @override
  String get equipment_setEdit_snackbar_created => 'Set di attrezzatura creato';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return 'Errore nel salvataggio del set di attrezzatura: $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated =>
      'Set di attrezzatura aggiornato';

  @override
  String get equipment_sets_appBar_title => 'Set di attrezzatura';

  @override
  String get equipment_sets_emptyState_createFirstButton =>
      'Crea il tuo primo set';

  @override
  String get equipment_sets_emptyState_description =>
      'Crea set di attrezzatura per aggiungere rapidamente combinazioni di attrezzatura usate frequentemente alle tue immersioni.';

  @override
  String get equipment_sets_emptyState_title => 'Nessun set di attrezzatura';

  @override
  String equipment_sets_errorLoading(Object error) {
    return 'Errore nel caricamento dei set: $error';
  }

  @override
  String get equipment_sets_fabTooltip => 'Crea un nuovo set di attrezzatura';

  @override
  String get equipment_sets_fab_createSet => 'Crea set';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count articoli';
  }

  @override
  String equipment_sets_itemCountSemanticLabel(Object count) {
    return '$count nel set';
  }

  @override
  String equipment_sets_itemCountSingular(Object count) {
    return '$count articolo';
  }

  @override
  String get equipment_sets_retryButton => 'Riprova';

  @override
  String get equipment_snackbar_deleted => 'Attrezzatura eliminata';

  @override
  String get equipment_snackbar_markedAsServiced => 'Segnato come revisionato';

  @override
  String get equipment_snackbar_reactivated => 'Attrezzatura riattivata';

  @override
  String get equipment_snackbar_retired => 'Attrezzatura ritirata';

  @override
  String get equipment_summary_active => 'Attivo';

  @override
  String get equipment_summary_addEquipmentButton => 'Aggiungi attrezzatura';

  @override
  String get equipment_summary_equipmentSetsButton => 'Set di attrezzatura';

  @override
  String get equipment_summary_overviewTitle => 'Panoramica';

  @override
  String get equipment_summary_quickActionsTitle => 'Azioni rapide';

  @override
  String get equipment_summary_recentEquipmentTitle => 'Attrezzatura recente';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name, $type';
  }

  @override
  String get equipment_summary_selectPrompt =>
      'Seleziona un\'attrezzatura dalla lista per visualizzare i dettagli';

  @override
  String get equipment_summary_serviceDue => 'Manutenzione prevista';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name, $type, manutenzione prevista';
  }

  @override
  String get equipment_summary_serviceDueTitle => 'Manutenzione prevista';

  @override
  String get equipment_summary_title => 'Attrezzatura';

  @override
  String get equipment_summary_totalItems => 'Articoli totali';

  @override
  String get equipment_summary_totalValue => 'Valore totale';

  @override
  String get equipment_tab_equipment => 'Attrezzatura';

  @override
  String get equipment_tab_sets => 'Set';

  @override
  String get formatter_approximate_prefix => '~';

  @override
  String get formatter_connector_at => 'a';

  @override
  String get formatter_connector_from => 'Da';

  @override
  String get formatter_connector_until => 'Fino a';

  @override
  String get gas_air_description => 'Aria standard (21% O2)';

  @override
  String get gas_air_displayName => 'Aria';

  @override
  String get gas_diluentAir_description =>
      'Diluente aria standard per CCR poco profondo';

  @override
  String get gas_diluentAir_displayName => 'Diluente aria';

  @override
  String get gas_diluentTx1070_description =>
      'Diluente ipossico per CCR molto profondo';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description =>
      'Diluente ipossico per CCR profondo';

  @override
  String get gas_diluentTx1260_displayName => 'Tx 12/60';

  @override
  String get gas_ean32_description => 'Aria arricchita Nitrox 32%';

  @override
  String get gas_ean32_displayName => 'EAN32';

  @override
  String get gas_ean36_description => 'Aria arricchita Nitrox 36%';

  @override
  String get gas_ean36_displayName => 'EAN36';

  @override
  String get gas_ean40_description => 'Aria arricchita Nitrox 40%';

  @override
  String get gas_ean40_displayName => 'EAN40';

  @override
  String get gas_ean50_description => 'Gas deco - 50% O2';

  @override
  String get gas_ean50_displayName => 'EAN50';

  @override
  String get gas_helitrox2525_description =>
      'Helitrox 25/25 (tecnica ricreativa)';

  @override
  String get gas_helitrox2525_displayName => 'Helitrox 25/25';

  @override
  String get gas_oxygen_description => 'Ossigeno puro (solo deco a 6m)';

  @override
  String get gas_oxygen_displayName => 'Ossigeno';

  @override
  String get gas_scrEan40_description => 'Gas di alimentazione SCR - 40% O2';

  @override
  String get gas_scrEan40_displayName => 'SCR EAN40';

  @override
  String get gas_scrEan50_description => 'Gas di alimentazione SCR - 50% O2';

  @override
  String get gas_scrEan50_displayName => 'SCR EAN50';

  @override
  String get gas_scrEan60_description => 'Gas di alimentazione SCR - 60% O2';

  @override
  String get gas_scrEan60_displayName => 'SCR EAN60';

  @override
  String get gas_tmx1555_description =>
      'Trimix ipossico 15/55 (molto profondo)';

  @override
  String get gas_tmx1555_displayName => 'Tx 15/55';

  @override
  String get gas_tmx1845_description => 'Trimix 18/45 (immersione profonda)';

  @override
  String get gas_tmx1845_displayName => 'Tx 18/45';

  @override
  String get gas_tmx2135_description => 'Trimix normossico 21/35';

  @override
  String get gas_tmx2135_displayName => 'Tx 21/35';

  @override
  String get gasCalculators_bestMix_bestOxygenMix =>
      'Migliore Miscela Ossigeno';

  @override
  String get gasCalculators_bestMix_commonMixesRef =>
      'Riferimento Miscele Comuni';

  @override
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2) {
    return 'MOD aria superata a ppO₂ $ppO2';
  }

  @override
  String get gasCalculators_bestMix_targetDepth => 'Profondità Target';

  @override
  String get gasCalculators_bestMix_targetDive => 'Immersione Target';

  @override
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  ) {
    return 'Pressione ambiente a $depth$depthSymbol';
  }

  @override
  String get gasCalculators_consumption_avgDepth => 'Profondità Media';

  @override
  String get gasCalculators_consumption_breakdown => 'Riepilogo Calcolo';

  @override
  String get gasCalculators_consumption_diveTime => 'Tempo Immersione';

  @override
  String gasCalculators_consumption_exceedsTank(
    Object pressure,
    Object symbol,
  ) {
    return 'Supera la capacità della bombola ($pressure $symbol)';
  }

  @override
  String get gasCalculators_consumption_gasAtDepth =>
      'Consumo gas in profondità';

  @override
  String get gasCalculators_consumption_pressure => 'Pressione';

  @override
  String get gasCalculators_consumption_remainingGas => 'Gas rimanente';

  @override
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  ) {
    return 'Capacità bombola ($tankSize$volumeSymbol @ $fillPressure $pressureSymbol)';
  }

  @override
  String get gasCalculators_consumption_title => 'Consumo Gas';

  @override
  String gasCalculators_consumption_totalGas(Object time) {
    return 'Gas totale per $time minuti';
  }

  @override
  String get gasCalculators_consumption_volume => 'Volume';

  @override
  String get gasCalculators_mod_aboutMod => 'Informazioni su MOD';

  @override
  String get gasCalculators_mod_aboutModBody =>
      'Meno O₂ = MOD più profonda = NDL più breve';

  @override
  String get gasCalculators_mod_inputParameters => 'Parametri di Input';

  @override
  String get gasCalculators_mod_maximumOperatingDepth =>
      'Profondità Operativa Massima';

  @override
  String get gasCalculators_mod_oxygenO2 => 'Ossigeno (O₂)';

  @override
  String get gasCalculators_mod_ppO2Conservative =>
      'Limite conservativo per tempo di fondo prolungato';

  @override
  String get gasCalculators_mod_ppO2Maximum =>
      'Limite massimo solo per tappe di decompressione';

  @override
  String get gasCalculators_mod_ppO2Standard =>
      'Limite di lavoro standard per immersioni ricreative';

  @override
  String get gasCalculators_mnd_depthInput => 'Profondita';

  @override
  String get gasCalculators_mnd_endAtDepthTitle => 'END alla profondita';

  @override
  String get gasCalculators_mnd_endLimit => 'Limite END';

  @override
  String get gasCalculators_mnd_hePercent => 'He %';

  @override
  String get gasCalculators_mnd_infoContent =>
      'La profondita narcotica massima (MND) e la profondita massima a cui puoi scendere prima che la narcosi superi il tuo limite END. La profondita narcotica equivalente (END) indica l\'effetto narcotico del tuo gas a una data profondita.\n\nQuando \"O2 e narcotico\" e attivato, sia l\'ossigeno che l\'azoto contribuiscono alla narcosi (piu conservativo). Quando disattivato, solo l\'azoto e considerato narcotico.';

  @override
  String get gasCalculators_mnd_infoTitle => 'Informazioni su MND/END';

  @override
  String get gasCalculators_mnd_unlimited => 'illimitata';

  @override
  String get gasCalculators_mnd_inputParameters =>
      'Miscela gas e impostazioni narcosi';

  @override
  String get gasCalculators_mnd_o2Narcotic => 'O2 e narcotico';

  @override
  String get gasCalculators_mnd_o2Percent => 'O2 %';

  @override
  String get gasCalculators_mnd_resultTitle => 'Profondita narcotica massima';

  @override
  String get gasCalculators_ppO2Limit => 'Limite ppO₂';

  @override
  String get gasCalculators_resetAll => 'Ripristina tutti i calcolatori';

  @override
  String get gasCalculators_sacRate => 'RMV';

  @override
  String get gasCalculators_tab_bestMix => 'Miscela Migliore';

  @override
  String get gasCalculators_tab_consumption => 'Consumo';

  @override
  String get gasCalculators_tab_mnd => 'MND/END';

  @override
  String get gasCalculators_tab_blender => 'Miscelatore trimix';

  @override
  String get gasCalculators_blender_cylinder => 'Bombola';

  @override
  String get gasCalculators_blender_startCylinder => 'Nella bombola';

  @override
  String get gasCalculators_blender_targetFill => 'Riempimento target';

  @override
  String get gasCalculators_blender_fillGases => 'Gas di riempimento';

  @override
  String get gasCalculators_blender_pressure => 'Pressione';

  @override
  String get gasCalculators_blender_o2 => 'O₂';

  @override
  String get gasCalculators_blender_he => 'He';

  @override
  String get gasCalculators_blender_air => 'Aria';

  @override
  String get gasCalculators_blender_helium => 'Elio';

  @override
  String get gasCalculators_blender_procedure => 'Procedura di riempimento';

  @override
  String get gasCalculators_blender_amounts => 'Gas da aggiungere';

  @override
  String gasCalculators_blender_stepStart(String pressure, String gas) {
    return 'Inizia con $pressure $gas';
  }

  @override
  String gasCalculators_blender_stepFill(
    String gas,
    String pressure,
    String mix,
  ) {
    return 'Riempi $gas fino a $pressure → $mix';
  }

  @override
  String get gasCalculators_blender_error_targetPressure =>
      'La pressione target deve essere maggiore di quella iniziale.';

  @override
  String get gasCalculators_blender_error_invalidMix =>
      'O₂ + He di una miscela non può superare il 100%.';

  @override
  String get gasCalculators_blender_error_identicalGases =>
      'I due gas di riempimento sono identici: niente da miscelare.';

  @override
  String get gasCalculators_blender_error_linearlyDependent =>
      'Questi gas non possono produrre la miscela target: un target trimix richiede una fonte di elio.';

  @override
  String get gasCalculators_blender_error_negativeAmount =>
      'Questa miscela non è realizzabile con questi gas: richiederebbe di rimuovere gas.';

  @override
  String gasCalculators_blender_error_drainTo(String pressure) {
    return 'Troppo gas nella bombola per questa miscela: scarica fino a $pressure, poi riempi.';
  }

  @override
  String get gasCalculators_blender_error_drainEmpty =>
      'Il gas presente nella bombola non è utilizzabile per questa miscela: svuotala completamente, poi riempi.';

  @override
  String get gasCalculators_blender_error_cannotRemoveHelium =>
      'La bombola contiene elio mentre la miscela target no. Il rabbocco diluisce l\'elio ma non lo rimuove: la bombola va prima svuotata.';

  @override
  String get gasCalculators_blender_error_insufficientGases =>
      'Un target senza elio richiede due gas di riempimento senza elio con contenuto di O₂ diverso.';

  @override
  String get gasCalculators_blender_error_targetNotReached =>
      'Questi gas di riempimento non raggiungono esattamente la miscela target. Controlla i gas e il loro ordine.';

  @override
  String get gasCalculators_blender_error_implausibleStartMix =>
      'La bombola è in pressione ma non contiene né ossigeno né elio, quindi azoto puro. Controlla la miscela già presente nella bombola.';

  @override
  String get gasCalculators_blender_about => 'Informazioni sulla miscelazione';

  @override
  String get gasCalculators_blender_aboutBody =>
      'Miscelazione a pressioni parziali per la miscela target. Aggiungi ogni gas di riempimento nell\'ordine, fino alla pressione indicata, poi lascia stabilizzare la bombola. I gas di riempimento e il loro ordine sono configurabili: impostando l\'ultimo gas su 32/0 il rabbocco avviene con EAN32 invece che con aria. Analizza sempre la miscela finale prima di immergerti.';

  @override
  String get gasCalculators_blender_conditions => 'Condizioni di miscelazione';

  @override
  String get gasCalculators_blender_fillTemp => 'Temperatura di riempimento';

  @override
  String get gasCalculators_blender_fillTempHelp =>
      'La temperatura della bombola mentre la riempi. Ogni pressione della procedura è il valore al manometro a questa temperatura.';

  @override
  String get gasCalculators_blender_settledTemp => 'Temperatura a riposo';

  @override
  String get gasCalculators_blender_settledTempHelp =>
      'La temperatura che la bombola raggiunge a riposo. La pressione target è quella che segna una volta stabilizzata.';

  @override
  String get gasCalculators_blender_gasModel => 'Modello di gas';

  @override
  String get gasCalculators_blender_modelIdeal => 'Gas ideale';

  @override
  String get gasCalculators_blender_modelVanDerWaals => 'Van der Waals';

  @override
  String get gasCalculators_blender_modelZFactor => 'Gas reale (fattore Z)';

  @override
  String get gasCalculators_blender_modelRecommended => 'Consigliato';

  @override
  String get gasCalculators_blender_modelHelp =>
      'Il gas reale (fattore Z) è il più accurato alle pressioni di bombola. Il gas ideale corrisponde alla maggior parte delle tabelle di miscelazione pubblicate. Van der Waals è offerto per il confronto con altri software di miscelazione e si discosta di alcuni punti percentuali alla pressione di riempimento.';

  @override
  String gasCalculators_blender_stepAdd(String gas) {
    return 'Aggiungi $gas';
  }

  @override
  String get gasCalculators_blender_stepStartLabel => 'Inizio';

  @override
  String gasCalculators_blender_settlesTo(String pressure, String temperature) {
    return 'Si stabilizza a $pressure a $temperature';
  }

  @override
  String get gasCalculators_blender_templates => 'Modelli';

  @override
  String get gasCalculators_blender_templatesTitle =>
      'Modelli di miscela target';

  @override
  String get gasCalculators_blender_saveTemplate => 'Salva la miscela corrente';

  @override
  String get gasCalculators_blender_manageTemplates => 'Gestisci modelli';

  @override
  String gasCalculators_blender_templateSaved(String mix) {
    return '$mix salvata';
  }

  @override
  String get gasCalculators_blender_templateExists =>
      'Questa miscela è già salvata.';

  @override
  String get gasCalculators_blender_templateInvalid =>
      'O₂ + He non può superare il 100%.';

  @override
  String get gasCalculators_blender_templateNeedsNumbers =>
      'Inserisci sia O₂ sia He come numeri.';

  @override
  String gasCalculators_blender_templateLimit(int count) {
    return 'Puoi salvare fino a $count modelli.';
  }

  @override
  String get gasCalculators_blender_templateNone =>
      'Nessun modello. Salva una miscela target per riutilizzarla qui.';

  @override
  String gasCalculators_blender_templateDelete(String mix) {
    return 'Elimina $mix';
  }

  @override
  String get gasCalculators_blender_templateAdd => 'Aggiungi modello';

  @override
  String get gasCalculators_blender_billing => 'Costo';

  @override
  String get gasCalculators_blender_cylinderVolume =>
      'Volume d\'acqua della bombola';

  @override
  String get gasCalculators_blender_cylinderPresets => 'Preimpostazioni';

  @override
  String gasCalculators_blender_unitPrice(String unit) {
    return 'Prezzo per 100 $unit';
  }

  @override
  String get gasCalculators_blender_currency => 'Valuta';

  @override
  String get gasCalculators_blender_costTotal => 'Totale';

  @override
  String get gasCalculators_blender_costBasis =>
      'Fatturato sulla pressione erogata (volume d\'acqua della bombola × bar aggiunti), come la misura una stazione di ricarica.';

  @override
  String get gasCalculators_blender_costMissingPrice =>
      'Inserisci un prezzo per ogni gas per vedere il totale.';

  @override
  String get gasCalculators_blender_saveFill => 'Salva questo riempimento';

  @override
  String get gasCalculators_blender_billed => 'Fatturato';

  @override
  String get gasCalculators_blender_billedNone =>
      'Ancora nulla da fatturare. Completa un riempimento e salvalo qui.';

  @override
  String get gasCalculators_blender_billedTo => 'Intestato a';

  @override
  String get gasCalculators_blender_addManualLine => 'Aggiungi una voce';

  @override
  String get gasCalculators_blender_lineDescription => 'Descrizione';

  @override
  String get gasCalculators_blender_lineAmount => 'Importo';

  @override
  String get gasCalculators_blender_clearBilled => 'Svuota';

  @override
  String get gasCalculators_blender_clearBilledTitle => 'Svuotare la fattura?';

  @override
  String gasCalculators_blender_clearBilledBody(int count) {
    return 'Rimuove tutti i $count riempimenti salvati.';
  }

  @override
  String gasCalculators_blender_editLine(String label) {
    return 'Modifica $label';
  }

  @override
  String gasCalculators_blender_deleteLine(String label) {
    return 'Elimina $label';
  }

  @override
  String gasCalculators_blender_fillAdded(String mix) {
    return '$mix aggiunto alla fattura';
  }

  @override
  String get gasCalculators_blender_billedIncomplete =>
      'Almeno una voce non ha prezzo, quindi il totale è incompleto.';

  @override
  String get gasCalculators_blender_billedTotal => 'Totale';

  @override
  String get gasCalculators_tab_mod => 'MOD';

  @override
  String get gasCalculators_tab_rockBottom => 'Rock Bottom';

  @override
  String get gasCalculators_tankSize => 'Dimensione Bombola';

  @override
  String get gasCalculators_title => 'Calcolatori Gas';

  @override
  String get marineLife_siteSection_editExpectedTooltip =>
      'Modifica specie previste';

  @override
  String get marineLife_siteSection_errorLoadingExpected =>
      'Errore nel caricamento delle specie previste';

  @override
  String get marineLife_siteSection_errorLoadingSightings =>
      'Errore nel caricamento degli avvistamenti';

  @override
  String get marineLife_siteSection_expectedSpecies => 'Specie previste';

  @override
  String get marineLife_siteSection_noExpected =>
      'Nessuna specie prevista aggiunta';

  @override
  String get marineLife_siteSection_noSpotted =>
      'Nessuna vita marina avvistata ancora';

  @override
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  ) {
    return '$name, avvistato $count volte';
  }

  @override
  String get marineLife_siteSection_spottedHere => 'Avvistate qui';

  @override
  String get marineLife_siteSection_title => 'Vita marina';

  @override
  String get marineLife_speciesDetail_backTooltip => 'Indietro';

  @override
  String get marineLife_speciesDetail_depthRangeTitle =>
      'Intervallo di profondità';

  @override
  String get marineLife_speciesDetail_descriptionTitle => 'Descrizione';

  @override
  String get marineLife_speciesDetail_divesLabel => 'Immersioni';

  @override
  String get marineLife_speciesDetail_editTooltip => 'Modifica specie';

  @override
  String marineLife_speciesDetail_errorPrefix(Object error) {
    return 'Errore: $error';
  }

  @override
  String get marineLife_speciesDetail_noSightings =>
      'Nessun avvistamento registrato ancora';

  @override
  String get marineLife_speciesDetail_notFound => 'Specie non trovata';

  @override
  String marineLife_speciesDetail_sightingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'avvistamenti',
      one: 'avvistamento',
    );
    return '$count $_temp0';
  }

  @override
  String get marineLife_speciesDetail_sightingPeriodTitle =>
      'Periodo di avvistamento';

  @override
  String get marineLife_speciesDetail_sightingStatsTitle =>
      'Statistiche avvistamenti';

  @override
  String get marineLife_speciesDetail_sitesLabel => 'Siti';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return 'Classe: $className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle => 'Siti principali';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel =>
      'Avvistamenti totali';

  @override
  String get marineLife_speciesEdit_addTitle => 'Aggiungi specie';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return 'Aggiunta \"$name\"';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => 'Indietro';

  @override
  String get marineLife_speciesEdit_categoryLabel => 'Categoria';

  @override
  String get marineLife_speciesEdit_commonNameError =>
      'Inserisci un nome comune';

  @override
  String get marineLife_speciesEdit_commonNameHint => 'es. Pesce pagliaccio';

  @override
  String get marineLife_speciesEdit_commonNameLabel => 'Nome comune';

  @override
  String get marineLife_speciesEdit_descriptionHint =>
      'Breve descrizione della specie...';

  @override
  String get marineLife_speciesEdit_descriptionLabel => 'Descrizione';

  @override
  String get marineLife_speciesEdit_editTitle => 'Modifica specie';

  @override
  String marineLife_speciesEdit_errorLoading(Object error) {
    return 'Errore nel caricamento della specie: $error';
  }

  @override
  String marineLife_speciesEdit_errorSaving(Object error) {
    return 'Errore nel salvataggio della specie: $error';
  }

  @override
  String get marineLife_speciesEdit_saveButton => 'Salva';

  @override
  String get marineLife_speciesEdit_scientificNameHint =>
      'es. Amphiprion ocellaris';

  @override
  String get marineLife_speciesEdit_scientificNameLabel => 'Nome scientifico';

  @override
  String get marineLife_speciesEdit_taxonomyClassHint => 'es. Actinopterygii';

  @override
  String get marineLife_speciesEdit_taxonomyClassLabel => 'Classe tassonomica';

  @override
  String marineLife_speciesEdit_updatedSnackbar(Object name) {
    return 'Aggiornata \"$name\"';
  }

  @override
  String get marineLife_speciesManage_allFilter => 'Tutte';

  @override
  String get marineLife_speciesManage_appBarTitle => 'Specie';

  @override
  String get marineLife_speciesManage_backTooltip => 'Indietro';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return 'Specie predefinite ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => 'Annulla';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return 'Impossibile eliminare \"$name\" - ha degli avvistamenti';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip => 'Cancella ricerca';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return 'Specie personalizzate ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => 'Elimina';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return 'Sei sicuro di voler eliminare \"$name\"?';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle =>
      'Eliminare la specie?';

  @override
  String get marineLife_speciesManage_deleteTooltip => 'Elimina specie';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return 'Eliminata \"$name\"';
  }

  @override
  String get marineLife_speciesManage_editTooltip => 'Modifica specie';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return 'Errore nell\'eliminazione della specie: $error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return 'Errore nel ripristino delle specie: $error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound =>
      'Nessuna specie trovata';

  @override
  String get marineLife_speciesManage_resetButton => 'Ripristina';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      'Questo ripristinerà tutte le specie predefinite ai valori originali. Le specie personalizzate non saranno modificate. Le specie predefinite con avvistamenti esistenti saranno aggiornate ma conservate.';

  @override
  String get marineLife_speciesManage_resetDialogTitle =>
      'Ripristinare i valori predefiniti?';

  @override
  String get marineLife_speciesManage_resetSuccess =>
      'Specie predefinite ripristinate ai valori originali';

  @override
  String get marineLife_speciesManage_resetToDefaults =>
      'Ripristina predefiniti';

  @override
  String get marineLife_speciesManage_searchHint => 'Cerca specie...';

  @override
  String get marineLife_speciesPicker_allFilter => 'Tutte';

  @override
  String get marineLife_speciesPicker_cancelButton => 'Annulla';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip => 'Cancella ricerca';

  @override
  String get marineLife_speciesPicker_closeTooltip => 'Chiudi selettore specie';

  @override
  String get marineLife_speciesPicker_doneButton => 'Fatto';

  @override
  String marineLife_speciesPicker_error(Object error) {
    return 'Errore: $error';
  }

  @override
  String get marineLife_speciesPicker_noSpeciesFound =>
      'Nessuna specie trovata';

  @override
  String get marineLife_speciesPicker_searchHint => 'Cerca specie...';

  @override
  String marineLife_speciesPicker_selectedCount(Object count) {
    return '$count selezionate';
  }

  @override
  String get marineLife_speciesPicker_title => 'Seleziona specie';

  @override
  String get media_diveMediaSection_addTooltip => 'Aggiungi foto o video';

  @override
  String get media_diveMediaSection_cancelButton => 'Annulla';

  @override
  String get media_diveMediaSection_cancelSelectionButton => 'Annulla';

  @override
  String get media_diveMediaSection_emptyState => 'Nessuna foto ancora';

  @override
  String get media_diveMediaSection_errorLoading =>
      'Errore nel caricamento dei media';

  @override
  String get media_diveMediaSection_selectAllButton => 'Seleziona tutto';

  @override
  String media_diveMediaSection_selectedCount(int count) {
    return '$count selezionati';
  }

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Visualizza foto. Premi a lungo per scollegare';

  @override
  String get media_diveMediaSection_title => 'Foto e video';

  @override
  String get media_diveMediaSection_replaceButton => 'Ricollega';

  @override
  String get media_diveMediaSection_replaceEditedContent =>
      'Il contenuto di questo file differisce dall\'originale. Ricollegarlo lo ricaricherà nel tuo archivio multimediale.';

  @override
  String get media_diveMediaSection_replaceEditedTitle =>
      'Il contenuto del file differisce';

  @override
  String get media_diveMediaSection_unlinkButton => 'Scollega';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Scollegamento non riuscito: $error';
  }

  @override
  String media_diveMediaSection_unlinkSelectedButton(int count) {
    return 'Scollega $count';
  }

  @override
  String media_diveMediaSection_unlinkSelectedContent(int count) {
    return 'Rimuove $count elementi multimediali dalla libreria, insieme alle copie nel cloud e alle miniature. Gli elementi ancora usati da un sito di immersione vengono mantenuti. I file originali non vengono toccati.';
  }

  @override
  String media_diveMediaSection_unlinkSelectedSuccess(int count) {
    return '$count elementi scollegati';
  }

  @override
  String media_diveMediaSection_unlinkSelectedTitle(int count) {
    return 'Scollegare $count elementi?';
  }

  @override
  String media_library_unlinkConfirmTitle(int count) {
    return 'Scollegare $count elementi?';
  }

  @override
  String media_siteMediaSection_unlinkError(Object error) {
    return 'Scollegamento non riuscito: $error';
  }

  @override
  String get media_library_unlinkConfirmBody =>
      'Escono dalla tua libreria, insieme alle copie nel cloud e alle miniature. I file originali non vengono toccati. Non può essere annullato.';

  @override
  String media_library_unlinkMetadataNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count di questi hanno una didascalia o un preferito salvati in Submersion, e quei dettagli vanno persi.',
      one:
          'Uno di questi ha una didascalia o un preferito salvati in Submersion, e quei dettagli vanno persi.',
    );
    return '$_temp0';
  }

  @override
  String get media_siteMediaSection_title => 'Media del sito';

  @override
  String get media_siteMediaSection_addPhotos => 'Aggiungi foto o video';

  @override
  String get media_siteMediaSection_addDocument => 'Aggiungi documento';

  @override
  String get media_siteMediaSection_emptyState =>
      'Nessuna mappa, foto o documento allegato a questo sito';

  @override
  String media_siteMediaSection_divePhotosGroup(int count) {
    return 'Foto dalle immersioni qui ($count)';
  }

  @override
  String get media_siteMediaSection_divePhotoLabel => 'Foto dell\'immersione';

  @override
  String media_siteMediaSection_unlinkSelectedTitle(int count) {
    return 'Scollegare $count elementi?';
  }

  @override
  String media_siteMediaSection_unlinkSelectedContent(int count) {
    return 'Rimuove $count elementi dalla libreria, insieme alle copie cloud e alle miniature. I media ancora usati da un\'immersione vengono conservati. I file originali non vengono toccati.';
  }

  @override
  String media_siteMediaSection_unlinkSelectedSuccess(int count) {
    return '$count elementi scollegati';
  }

  @override
  String get media_documentViewer_title => 'Documento';

  @override
  String get media_documentViewer_unavailable =>
      'Questo documento non è disponibile su questo dispositivo';

  @override
  String get media_documentViewer_availableOnOriginDevice =>
      'È disponibile sul dispositivo da cui è stato aggiunto, oppure tramite un archivio media configurato.';

  @override
  String media_documentViewer_attached(int count) {
    return '$count documenti allegati';
  }

  @override
  String get media_diveScan_scanTooltip => 'Cerca foto nella galleria';

  @override
  String get media_diveScan_noPhotosFound =>
      'Nessuna nuova foto trovata vicino a questa immersione';

  @override
  String get media_diveScan_accessDenied =>
      'L\'accesso alla libreria foto e necessario per cercare le foto';

  @override
  String media_diveScan_foundPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Trovate $count foto',
      one: 'Trovata 1 foto',
    );
    return '$_temp0 vicino a questa immersione. Collegare?';
  }

  @override
  String get media_diveScan_foundTitle => 'Foto trovate';

  @override
  String media_diveScan_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto',
      one: 'foto',
    );
    return 'Collega $_temp0';
  }

  @override
  String get media_diveScan_cancelButton => 'Annulla';

  @override
  String media_diveScan_error(String error) {
    return 'Errore durante la ricerca nella galleria: $error';
  }

  @override
  String get media_gpsBanner_addToSiteButton => 'Aggiungi al sito';

  @override
  String media_gpsBanner_coordinates(Object coordinates) {
    return 'Coordinate: $coordinates';
  }

  @override
  String get media_gpsBanner_createSiteButton => 'Crea sito';

  @override
  String get media_gpsBanner_dismissTooltip => 'Ignora suggerimento GPS';

  @override
  String get media_gpsBanner_title => 'GPS trovato nelle foto';

  @override
  String media_import_failedToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto',
      one: 'foto',
    );
    return 'Impossibile importare $_temp0';
  }

  @override
  String media_import_failedToImportError(Object error) {
    return 'Impossibile importare le foto: $error';
  }

  @override
  String media_import_allAlreadyLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto gia collegate a questa immersione',
      one: '1 foto gia collegata a questa immersione',
    );
    return '$_temp0';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return 'Importate $imported, non riuscite $failed';
  }

  @override
  String media_import_importedAndSkipped(int imported, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      imported,
      locale: localeName,
      other: 'Importate $imported foto',
      one: 'Importata 1 foto',
    );
    return '$_temp0 ($skipped gia collegate)';
  }

  @override
  String media_import_importedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importate $count foto',
      one: 'Importata $count foto',
    );
    return '$_temp0';
  }

  @override
  String media_import_importingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto',
      one: 'foto',
    );
    return 'Importazione di $count $_temp0 in corso...';
  }

  @override
  String get media_lightroom_openInLightroom => 'Apri in Lightroom';

  @override
  String get media_lightroom_suggestion_accept =>
      'Aggiungi a questa immersione';

  @override
  String get media_lightroom_suggestion_dismiss => 'Ignora';

  @override
  String get media_lightroom_suggestions_title => 'Suggerimenti da Lightroom';

  @override
  String get media_miniProfile_headerLabel => 'Profilo immersione';

  @override
  String get media_miniProfile_semanticLabel =>
      'Grafico mini profilo immersione';

  @override
  String get media_photoPicker_appBarTitle => 'Seleziona foto';

  @override
  String get media_photoPicker_tab_gallery => 'Galleria';

  @override
  String get media_photoPicker_tab_files => 'File';

  @override
  String get media_photoPicker_tab_url => 'URL';

  @override
  String get media_photoPicker_clearSelectionButton => 'Cancella';

  @override
  String get media_photoPicker_closeTooltip => 'Chiudi selettore foto';

  @override
  String get media_photoPicker_doneButton => 'Fatto';

  @override
  String media_photoPicker_doneCountButton(Object count) {
    return 'Fatto ($count)';
  }

  @override
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  ) {
    return 'Nessuna foto trovata tra $startDate $startTime e $endDate $endTime.';
  }

  @override
  String get media_photoPicker_emptyTitle => 'Nessuna foto trovata';

  @override
  String get media_photoPicker_grantAccessButton => 'Continua';

  @override
  String get media_photoPicker_openSettingsButton => 'Apri Impostazioni';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'L\'accesso alla libreria foto è stato negato. Abilitalo nelle Impostazioni per aggiungere foto delle immersioni.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion ha bisogno dell\'accesso alla tua libreria foto per aggiungere foto delle immersioni.';

  @override
  String get media_photoPicker_permissionTitle => 'Foto delle immersioni';

  @override
  String get media_photoPicker_selectAllButton => 'Seleziona tutto';

  @override
  String media_photoPicker_selectedCount(int count) {
    return '$count selezionati';
  }

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return 'Foto mostrate dal periodo $rangeText';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel =>
      'Attiva/disattiva selezione foto';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel =>
      'Attiva/disattiva selezione foto, selezionata';

  @override
  String get media_photoPicker_files_pickFilesButton => 'Scegli file…';

  @override
  String get media_photoPicker_files_pickFolderButton => 'Scegli una cartella…';

  @override
  String get media_photoPicker_files_autoMatchLabel =>
      'Associa automaticamente foto e video alle immersioni per data';

  @override
  String get media_photoPicker_files_emptyHint =>
      'Scegli file o una cartella per iniziare.';

  @override
  String media_photoPicker_files_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Collega $count elementi',
      one: 'Collega 1 elemento',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachToSiteButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Allega $count elementi a questo sito',
      one: 'Allega 1 elemento a questo sito',
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
      other: '$fileCount file',
      one: '1 file',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount immersioni',
      one: '1 immersione',
    );
    return '$_temp0, $_temp1, $unmatchedCount non associati';
  }

  @override
  String media_photoPicker_files_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_diveGroupTitle(String diveId) {
    return 'Immersione $diveId';
  }

  @override
  String media_photoPicker_files_groupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_unmatchedGroupTitle => 'Non associati';

  @override
  String media_photoPicker_files_addAllToDive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aggiungi tutti i $count a questa immersione',
      one: 'Aggiungi 1 a questa immersione',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_addToDiveTooltip =>
      'Aggiungi a questa immersione';

  @override
  String get media_photoPicker_files_chooseDiveTooltip =>
      'Scegli un\'immersione';

  @override
  String get media_photoPicker_files_removeTooltip => 'Rimuovi dalla selezione';

  @override
  String get media_photoPicker_files_sourceExif => 'da EXIF';

  @override
  String get media_photoPicker_files_sourceContainer => 'dai metadati del file';

  @override
  String get media_photoPicker_files_sourceFileDate => 'dalla data del file';

  @override
  String get media_photoPicker_files_sourceNone => 'nessuna data trovata';

  @override
  String media_photoPicker_files_shiftedTime(String shifted, String original) {
    return '$shifted (era $original)';
  }

  @override
  String get media_photoPicker_files_reasonNoTimestamp =>
      'Impossibile leggere l\'ora di scatto';

  @override
  String media_photoPicker_files_reasonBeforeDive(String gap) {
    return '$gap prima dell\'immersione più vicina';
  }

  @override
  String media_photoPicker_files_reasonAfterDive(String gap) {
    return '$gap dopo l\'immersione più vicina';
  }

  @override
  String get media_photoPicker_files_reasonNoDives =>
      'Nessuna immersione con cui confrontare';

  @override
  String get media_photoPicker_files_offsetLabel =>
      'Sposta gli orari di scatto di';

  @override
  String get media_photoPicker_files_offsetResetTooltip =>
      'Azzera lo spostamento';

  @override
  String media_photoPicker_files_offsetBackTooltip(String amount) {
    return 'Sposta di $amount prima';
  }

  @override
  String media_photoPicker_files_offsetForwardTooltip(String amount) {
    return 'Sposta di $amount dopo';
  }

  @override
  String media_photoPicker_files_linkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi collegati',
      one: '1 elemento collegato',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachedToSiteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi allegati a questo sito',
      one: '1 elemento allegato a questo sito',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_undo => 'Annulla';

  @override
  String get media_photoPicker_thumbnailAlreadyLinkedLabel =>
      'Foto gia collegata a questa immersione';

  @override
  String get media_perdixOverlay_labelCns => 'CNS';

  @override
  String get media_perdixOverlay_labelDepth => 'PROF';

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
  String get media_perdixOverlay_labelTime => 'TEMPO';

  @override
  String get media_perdixOverlay_labelTts => 'TTS';

  @override
  String get media_perdixOverlay_toggleTooltip => 'Overlay computer subacqueo';

  @override
  String get media_photoViewer_cannotShare =>
      'Impossibile condividere questa foto';

  @override
  String get media_photoViewer_cannotWriteMetadata =>
      'Impossibile scrivere i metadati - media non collegato alla libreria';

  @override
  String get media_photoViewer_closeTooltip => 'Chiudi visualizzatore foto';

  @override
  String get media_photoViewer_diveDataWrittenToPhoto =>
      'Dati immersione scritti nella foto';

  @override
  String get media_photoViewer_diveDataWrittenToVideo =>
      'Dati immersione scritti nel video';

  @override
  String media_photoViewer_errorLoadingPhotos(Object error) {
    return 'Errore nel caricamento delle foto: $error';
  }

  @override
  String get media_photoViewer_failedToLoadImage =>
      'Impossibile caricare l\'immagine';

  @override
  String get media_photoViewer_failedToLoadVideo =>
      'Impossibile caricare il video';

  @override
  String media_photoViewer_failedToShare(Object error) {
    return 'Condivisione non riuscita: $error';
  }

  @override
  String get media_photoViewer_failedToWriteMetadata =>
      'Impossibile scrivere i metadati';

  @override
  String media_photoViewer_failedToWriteMetadataError(Object error) {
    return 'Impossibile scrivere i metadati: $error';
  }

  @override
  String get media_photoViewer_nextTooltip => 'Elemento successivo';

  @override
  String get media_photoViewer_noPhotosAvailable => 'Nessuna foto disponibile';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel =>
      'Riproduci o metti in pausa il video';

  @override
  String get media_photoViewer_previousTooltip => 'Elemento precedente';

  @override
  String get media_photoViewer_seekVideoLabel => 'Cerca posizione nel video';

  @override
  String get media_photoViewer_shareTooltip => 'Condividi foto';

  @override
  String get media_photoViewer_toggleOverlayLabel =>
      'Attiva/disattiva sovrapposizione foto';

  @override
  String get media_photoViewer_videoFileNotFound => 'File video non trovato';

  @override
  String get media_photoViewer_videoNotLinked =>
      'Video non collegato alla libreria';

  @override
  String get media_photoViewer_writeDiveDataTooltip =>
      'Scrivi dati immersione nella foto';

  @override
  String get media_quickSiteDialog_cancelButton => 'Annulla';

  @override
  String get media_quickSiteDialog_createButton => 'Crea sito';

  @override
  String get media_quickSiteDialog_description =>
      'Crea un nuovo sito di immersione utilizzando le coordinate GPS dalla tua foto.';

  @override
  String get media_quickSiteDialog_siteNameError =>
      'Inserisci un nome per il sito';

  @override
  String get media_quickSiteDialog_siteNameHint =>
      'Inserisci un nome per questo sito';

  @override
  String get media_quickSiteDialog_siteNameLabel => 'Nome sito';

  @override
  String get media_quickSiteDialog_title => 'Crea sito di immersione';

  @override
  String get media_scanResults_allPhotosLinked => 'Tutte le foto già collegate';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return 'Tutte le $count foto di questo viaggio sono già collegate alle immersioni.';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count foto già collegate';
  }

  @override
  String get media_scanResults_cancelButton => 'Annulla';

  @override
  String media_scanResults_diveNumber(Object number) {
    return 'Immersione #$number';
  }

  @override
  String media_scanResults_foundNewPhotos(Object count) {
    return 'Trovate $count nuove foto';
  }

  @override
  String get media_scanResults_linkButton => 'Collega';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return 'Collega $count foto';
  }

  @override
  String get media_scanResults_noPhotosFound => 'Nessuna foto trovata';

  @override
  String get media_scanResults_okButton => 'OK';

  @override
  String get media_scanResults_unknownSite => 'Sito sconosciuto';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return '$count foto non corrispondono a nessuna immersione (scattate al di fuori dei tempi di immersione)';
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
      'Non su questo dispositivo';

  @override
  String get media_unavailablePlaceholder_signInRequired => 'Sign in to view';

  @override
  String get media_writeMetadata_cancelButton => 'Annulla';

  @override
  String get media_writeMetadata_depthLabel => 'Profondità';

  @override
  String get media_writeMetadata_descriptionPhoto =>
      'I seguenti metadati verranno scritti nella foto:';

  @override
  String get media_writeMetadata_descriptionVideo =>
      'I seguenti metadati verranno scritti nel video:';

  @override
  String get media_writeMetadata_diveTimeLabel => 'Tempo di immersione';

  @override
  String get media_writeMetadata_gpsLabel => 'GPS';

  @override
  String get media_writeMetadata_keepOriginalVideo =>
      'Mantieni video originale';

  @override
  String get media_writeMetadata_livePhotoUnsupported =>
      'Le Live Photo non sono ancora supportate. Duplica questa foto come immagine statica, poi scrivi i dati dell\'immersione sulla copia.';

  @override
  String get media_writeMetadata_noDataAvailable =>
      'Nessun dato immersione disponibile da scrivere.';

  @override
  String get media_writeMetadata_siteLabel => 'Sito';

  @override
  String get media_writeMetadata_temperatureLabel => 'Temperatura';

  @override
  String get media_writeMetadata_titlePhoto =>
      'Scrivi dati immersione nella foto';

  @override
  String get media_writeMetadata_titleVideo =>
      'Scrivi dati immersione nel video';

  @override
  String get media_writeMetadata_warningPhotoText =>
      'Questa operazione modificherà la foto originale.';

  @override
  String get media_writeMetadata_warningVideoText =>
      'Verrà creato un nuovo video con i metadati. I metadati del video non possono essere modificati in loco.';

  @override
  String get media_writeMetadata_writeButton => 'Scrivi';

  @override
  String get nav_buddies => 'Compagni';

  @override
  String get nav_certifications => 'Brevetti';

  @override
  String get nav_courses => 'Corsi';

  @override
  String get nav_coursesSubtitle => 'Formazione e addestramento';

  @override
  String get nav_diveCenters => 'Centri immersione';

  @override
  String get nav_dives => 'Immersioni';

  @override
  String get nav_equipment => 'Attrezzatura';

  @override
  String get nav_gpsLog => 'Registro GPS';

  @override
  String get media_console_library => 'Libreria';

  @override
  String get media_console_transfers => 'Trasferimenti';

  @override
  String get media_console_import => 'Importa';

  @override
  String get media_import_launch => 'Importa contenuti...';

  @override
  String get media_import_review_title => 'Rivedi importazione';

  @override
  String media_import_review_confirm(int count) {
    return 'Importa $count elementi';
  }

  @override
  String media_import_review_result(int linked, int skipped, int failed) {
    return '$linked collegati, $skipped saltati, $failed falliti';
  }

  @override
  String get media_import_review_chooseSite => 'Scegli sito';

  @override
  String get media_import_review_ambiguous => 'Più immersioni corrispondono';

  @override
  String get media_import_review_noMatch => 'Nessuna immersione corrispondente';

  @override
  String get media_import_review_skipped => 'Non importato';

  @override
  String media_import_review_linkChip(int number) {
    return 'Collega a #$number';
  }

  @override
  String get media_import_review_linkToDive => 'Collega a un\'immersione';

  @override
  String get media_import_review_linkToSite => 'Collega a un sito';

  @override
  String get media_import_review_chooseDive => 'Scegli immersione';

  @override
  String get media_import_intro =>
      'Le foto vengono collegate a un\'immersione o a un sito durante l\'importazione.';

  @override
  String get media_console_sources => 'Origini';

  @override
  String get media_sources_browseHeader => 'Sfoglia per origine';

  @override
  String get media_sources_watchedHeader => 'Cartelle monitorate';

  @override
  String get media_sources_addWatched => 'Aggiungi cartella...';

  @override
  String get media_sources_scanFailed => 'Scansione non riuscita';

  @override
  String get media_sources_scanNow => 'Scansiona ora';

  @override
  String get media_sources_autoApply =>
      'Ricollega automaticamente le corrispondenze esatte';

  @override
  String get media_sources_neverScanned => 'Mai scansionata';

  @override
  String get media_source_gallery => 'Libreria foto';

  @override
  String get media_source_localFile => 'File locali';

  @override
  String get media_source_networkUrl => 'Link web';

  @override
  String get media_source_manifest => 'Abbonamenti';

  @override
  String get media_source_connector => 'Servizi collegati';

  @override
  String get media_source_mediaStore => 'Archivio multimediale cloud';

  @override
  String get media_source_signature => 'Firme';

  @override
  String get media_repairHistory_title => 'Cronologia riparazioni';

  @override
  String get media_repairHistory_empty => 'Nessuna riparazione';

  @override
  String get media_repairHistory_action_relink => 'Ricollegato';

  @override
  String get media_repairHistory_action_cloudBacked => 'Su cloud';

  @override
  String get media_repairHistory_action_autoRelink =>
      'Ricollegato automaticamente';

  @override
  String get media_smartAlbum_save => 'Salva come album';

  @override
  String get media_smartAlbum_saveTitle => 'Assegna un nome';

  @override
  String get media_smartAlbum_albums => 'Album';

  @override
  String get media_smartAlbum_delete => 'Elimina album';

  @override
  String get media_smartAlbum_deleteFailed => 'Impossibile eliminare l\'album';

  @override
  String get media_smartAlbum_saved => 'Album salvato';

  @override
  String media_sources_lastScanned(String date) {
    return 'Ultima scansione $date';
  }

  @override
  String media_sources_scanResult(int indexed, int repaired) {
    return '$indexed file indicizzati, $repaired ricollegati';
  }

  @override
  String get media_repairHistory_sourceFolder => 'scansione cartelle';

  @override
  String get media_repairHistory_sourcePhotoLibrary => 'libreria foto';

  @override
  String get media_repairHistory_sourceStore => 'archivio multimediale cloud';

  @override
  String get media_repairHistory_sourceWatcher => 'cartelle monitorate';

  @override
  String get media_repairHistory_sourceManual => 'ricollegamento manuale';

  @override
  String media_repairHistory_source(String source) {
    return 'via $source';
  }

  @override
  String get media_missing_empty => 'Nessun file mancante';

  @override
  String media_missing_offlineVolumes(int count) {
    return '$count su volumi non in linea';
  }

  @override
  String get media_missing_repair => 'Ripara...';

  @override
  String get media_repair_title => 'Ripara i file mancanti';

  @override
  String get media_repair_addFolder => 'Aggiungi cartella...';

  @override
  String get media_repair_usePhotoLibrary => 'Cerca nella libreria foto';

  @override
  String get media_repair_useStore => 'Usa l\'archivio multimediale cloud';

  @override
  String get media_repair_scan => 'Scansiona';

  @override
  String media_repair_prefixMove(String from, String to, int count) {
    return 'Spostamento cartella rilevato: $from a $to copre $count file';
  }

  @override
  String get media_repair_confidence_exact => 'Esatto';

  @override
  String get media_repair_confidence_probable => 'Nome e dimensione';

  @override
  String get media_repair_confidence_edited => 'File modificato';

  @override
  String get media_repair_confidence_unmatched => 'Nessun candidato';

  @override
  String get media_repair_unverified => 'Non verificato con l\'archivio';

  @override
  String media_repair_apply(int count) {
    return 'Ricollega $count file';
  }

  @override
  String media_repair_summary(
    int relinked,
    int cloudBacked,
    int reuploads,
    int failed,
    int skipped,
  ) {
    return '$relinked ricollegati, $cloudBacked su cloud, $reuploads ricaricamenti in coda, $failed falliti, $skipped saltati';
  }

  @override
  String get media_library_empty => 'Ancora nessun contenuto multimediale';

  @override
  String get media_library_filter_all => 'Tutti';

  @override
  String get media_library_filter_photos => 'Foto';

  @override
  String get media_library_filter_videos => 'Video';

  @override
  String get media_library_filter_site => 'Sito';

  @override
  String get media_library_filter_trip => 'Viaggio';

  @override
  String get media_library_filter_dates => 'Date';

  @override
  String get media_library_filter_missing => 'File mancanti';

  @override
  String media_library_filter_missingCount(int count) {
    return 'File mancanti ($count)';
  }

  @override
  String get media_library_filter_clear => 'Cancella filtri';

  @override
  String get media_library_filter_any => 'Qualsiasi';

  @override
  String get media_library_filter_title => 'Filtra media';

  @override
  String get media_library_filter_apply => 'Applica';

  @override
  String get media_library_sort_title => 'Ordina media';

  @override
  String get media_smartAlbum_load => 'Carica album';

  @override
  String get media_divePicker_title => 'Sposta in un\'immersione';

  @override
  String get media_divePicker_search => 'Cerca immersioni';

  @override
  String get media_library_moveToDive => 'Sposta in un\'immersione';

  @override
  String get media_library_unlinkSelected => 'Scollega';

  @override
  String media_library_selectedCount(int count) {
    return '$count selezionati';
  }

  @override
  String get media_library_unlinkedHeader => 'Non collegati';

  @override
  String get media_library_diveHeaderHint => 'Apri questa immersione';

  @override
  String get media_library_untitledDiveHeader => 'Immersione senza titolo';

  @override
  String get media_library_viewMode_byDive => 'Per immersione';

  @override
  String get media_library_viewMode_grid => 'Griglia';

  @override
  String get media_library_viewMode_timeline => 'Cronologia';

  @override
  String get media_viewer_goToDive => 'Vai all\'immersione';

  @override
  String get nav_home => 'Home';

  @override
  String get nav_media => 'Media';

  @override
  String get nav_more => 'Altro';

  @override
  String get nav_planning => 'Pianificazione';

  @override
  String get nav_planningSubtitle => 'Pianificatore immersioni, calcolatori';

  @override
  String get nav_settings => 'Impostazioni';

  @override
  String get nav_sites => 'Siti';

  @override
  String get nav_statistics => 'Statistiche';

  @override
  String get nav_tooltip_closeMenu => 'Chiudi menu';

  @override
  String get nav_tooltip_collapseMenu => 'Comprimi menu';

  @override
  String get nav_tooltip_expandMenu => 'Espandi menu';

  @override
  String get nav_transfer => 'Trasferimento';

  @override
  String get nav_trips => 'Viaggi';

  @override
  String plannerCanvas_bailout_available(String liters) {
    return 'Disponibile $liters';
  }

  @override
  String get plannerCanvas_bailout_insufficient =>
      'Gas di bailout insufficiente per il caso peggiore';

  @override
  String plannerCanvas_bailout_required(String liters) {
    return 'Necessario $liters';
  }

  @override
  String get plannerCanvas_bailout_title => 'Bailout (circuito aperto)';

  @override
  String plannerCanvas_bailout_tts(String minutes) {
    return 'TTS bailout $minutes′';
  }

  @override
  String plannerCanvas_bailout_worstCase(String minutes, String depth) {
    return 'Caso peggiore a $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_ccr_setpointHigh => 'Setpoint alto (bar)';

  @override
  String get plannerCanvas_ccr_setpointLow => 'Setpoint basso (bar)';

  @override
  String get plannerCanvas_ccr_switchDepth => 'Profondità di cambio setpoint';

  @override
  String get plannerCanvas_pscr_ratio => 'Rapporto pSCR';

  @override
  String get plannerCanvas_pscr_ratio_hint =>
      'Maggiore = più gas fresco, minore calo di O₂';

  @override
  String plannerCanvas_chip_cns(String value) {
    return 'CNS $value%';
  }

  @override
  String plannerCanvas_chip_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemi',
      one: '1 problema',
    );
    return '$_temp0';
  }

  @override
  String get plannerCanvas_compare_action => 'Confronta';

  @override
  String get plannerCanvas_compare_needTwo =>
      'Seleziona almeno due piani da confrontare';

  @override
  String get plannerCanvas_compare_title => 'Confronta piani';

  @override
  String get plannerCanvas_contingency_base => 'Base';

  @override
  String get plannerCanvas_contingency_depthDelta => 'Profondità extra';

  @override
  String plannerCanvas_contingency_lostGas(String gas) {
    return '$gas perso';
  }

  @override
  String plannerCanvas_contingency_previewing(String label) {
    return 'Anteprima: $label';
  }

  @override
  String get plannerCanvas_contingency_timeDelta => 'Minuti extra';

  @override
  String plannerCanvas_chart_meanDepth(String depth) {
    return 'media $depth';
  }

  @override
  String get plannerCanvas_contingency_title => 'Contingenze';

  @override
  String get plannerCanvas_contingency_turnFraction => 'Frazione di rientro';

  @override
  String get plannerCanvas_contingency_turnRule =>
      'Regola pressione di rientro';

  @override
  String get plannerCanvas_convert_success => 'Immersione creata dal piano';

  @override
  String get plannerCanvas_convert_view => 'Vedi';

  @override
  String plannerCanvas_follow_chip(String name) {
    return 'Segue $name';
  }

  @override
  String get plannerCanvas_follow_empty => 'Nessuna immersione registrata';

  @override
  String get plannerCanvas_follow_noTissues =>
      'Nessun dato di profilo per quell\'immersione — intervallo di superficie impostato senza saturazione dei tessuti';

  @override
  String get plannerCanvas_follow_title => 'Segui un\'immersione';

  @override
  String plannerCanvas_gas_minGas(String pressure) {
    return 'gas minimo $pressure';
  }

  @override
  String plannerCanvas_gas_turnAt(String pressure) {
    return 'rientro a $pressure';
  }

  @override
  String plannerCanvas_issue_gasDensityCritical(String value) {
    return 'Densità del gas $value g/L oltre il limite massimo';
  }

  @override
  String plannerCanvas_issue_gasDensityHigh(String value) {
    return 'Densità del gas $value g/L oltre il limite consigliato';
  }

  @override
  String plannerCanvas_issue_hypoxic(String depth, String value) {
    return 'Gas ipossico a $depth (ppO₂ $value bar)';
  }

  @override
  String plannerCanvas_issue_minGas(String pressure) {
    return 'La bombola termina sotto il minimo rock bottom di $pressure';
  }

  @override
  String get plannerCanvas_issue_noBailout =>
      'Il piano di decompressione CCR non prevede gas di bailout';

  @override
  String get plannerCanvas_issue_noDecoGas =>
      'Decompressione necessaria ma nessun gas deco a bordo';

  @override
  String get plannerCanvas_range_base => 'Base';

  @override
  String get plannerCanvas_range_legend =>
      'Le celle mostrano il tempo di risalita; rosso = non immergibile come pianificato';

  @override
  String get plannerCanvas_pane_collapse => 'Comprimi pannello';

  @override
  String get plannerCanvas_pane_expand => 'Espandi pannello';

  @override
  String get plannerCanvas_tab_setup => 'Configurazione';

  @override
  String get plannerCanvas_o2Narcotic => 'Tratta l\'O₂ come narcotico';

  @override
  String get plannerCanvas_rates_ascent => 'Velocità di risalita';

  @override
  String get plannerCanvas_rates_descent => 'Velocità di discesa';

  @override
  String get plannerCanvas_rates_title => 'Velocità';

  @override
  String get plannerCanvas_range_title => 'Tabella di variazione';

  @override
  String get plannerCanvas_results_noDeco =>
      'Nessuna decompressione necessaria';

  @override
  String plannerCanvas_sac_useLogged(String sac) {
    return 'Usa media registrata ($sac)';
  }

  @override
  String plannerCanvas_saved_deleteConfirmBody(String name) {
    return 'Eliminare definitivamente «$name»?';
  }

  @override
  String get plannerCanvas_saved_deleteConfirmTitle => 'Eliminare il piano?';

  @override
  String get plannerCanvas_saved_duplicate => 'Duplica';

  @override
  String get plannerCanvas_saved_empty => 'Nessun piano salvato';

  @override
  String get plannerCanvas_saved_title => 'Piani salvati';

  @override
  String get plannerCanvas_name_dialogTitle => 'Dai un nome al piano';

  @override
  String get plannerCanvas_name_defaultFallback => 'Piano di immersione';

  @override
  String plannerCanvas_scrub_bailout(String minutes) {
    return 'BO $minutes′';
  }

  @override
  String plannerCanvas_scrub_readout(String minutes, String depth) {
    return 'RT $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_share_import => 'Importa';

  @override
  String plannerCanvas_share_importFailed(String reason) {
    return 'Impossibile importare il piano: $reason';
  }

  @override
  String get plannerCanvas_share_menu => 'Condividi file del piano';

  @override
  String get plannerCanvas_slate_menu => 'Esporta lavagnetta (PDF)';

  @override
  String get plannerCanvas_slate_minGas => 'Gas minimo';

  @override
  String get plannerCanvas_slate_turn => 'Rientro';

  @override
  String get plannerCanvas_table_depth => 'Profondità';

  @override
  String get plannerCanvas_table_gas => 'Gas';

  @override
  String get plannerCanvas_table_runtime => 'RT';

  @override
  String get plannerCanvas_table_stop => 'Sosta';

  @override
  String get plannerCanvas_turnRule_allUsable => 'Tutto utilizzabile';

  @override
  String get plannerCanvas_turnRule_custom => 'Personalizzata';

  @override
  String get plannerCanvas_turnRule_halves => 'Metà';

  @override
  String get plannerCanvas_turnRule_none => 'Nessuna';

  @override
  String get plannerCanvas_turnRule_thirds => 'Terzi';

  @override
  String get planning_appBar_title => 'Pianificazione';

  @override
  String get planning_card_decoCalculator_description =>
      'Calcola i limiti di non decompressione, le soste deco necessarie e l\'esposizione CNS/OTU per profili di immersione multilivello.';

  @override
  String get planning_card_decoCalculator_subtitle =>
      'Pianifica immersioni con soste di decompressione';

  @override
  String get planning_card_decoCalculator_title => 'Calcolatore deco';

  @override
  String get planning_card_divePlanner_description =>
      'Pianifica immersioni complesse con livelli di profondità multipli, cambi gas e calcolo automatico delle soste di decompressione.';

  @override
  String get planning_card_divePlanner_subtitle =>
      'Crea piani di immersione multilivello';

  @override
  String get planning_card_divePlanner_title => 'Pianificatore immersioni';

  @override
  String get planning_card_gasCalculators_description =>
      'Quattro calcolatori gas specializzati:\n• MOD - Profondità massima operativa per una miscela\n• Best Mix - O₂% ideale per una profondità target\n• Consumo - Stima del consumo gas\n• Rock Bottom - Calcolo della riserva di emergenza';

  @override
  String get planning_card_gasCalculators_subtitle =>
      'MOD, Best Mix, Consumo, Rock Bottom';

  @override
  String get planning_card_gasCalculators_title => 'Calcolatori gas';

  @override
  String get planning_card_surfaceInterval_description =>
      'Calcola l\'intervallo di superficie minimo necessario tra le immersioni in base al carico tessutale. Visualizza come i tuoi 16 compartimenti tessutali rilasciano gas nel tempo.';

  @override
  String get planning_card_surfaceInterval_subtitle =>
      'Pianifica intervalli per immersioni ripetitive';

  @override
  String get planning_card_surfaceInterval_title => 'Intervallo di superficie';

  @override
  String get planning_card_weightCalculator_description =>
      'Stima la zavorra necessaria in base alla muta, al materiale della bombola, al tipo di acqua e al peso corporeo.';

  @override
  String get planning_card_weightCalculator_subtitle =>
      'Zavorra raccomandata per la tua configurazione';

  @override
  String get planning_card_weightCalculator_title => 'Calcolatore zavorra';

  @override
  String get planning_info_disclaimer =>
      'Questi strumenti sono solo per la pianificazione. Verifica sempre i calcoli e segui la tua formazione subacquea.';

  @override
  String get planning_newPlan => 'Nuovo piano';

  @override
  String get planning_section_tools => 'Strumenti';

  @override
  String get planning_summary_prompt => 'Seleziona uno strumento per iniziare';

  @override
  String get planning_summary_savedPlans => 'Piani salvati';

  @override
  String get planning_summary_noPlans => 'Nessun piano salvato';

  @override
  String get planning_sidebar_appBar_title => 'Pianificazione';

  @override
  String get planning_sidebar_decoCalculator_subtitle => 'NDL e soste deco';

  @override
  String get planning_sidebar_decoCalculator_title => 'Calcolatore deco';

  @override
  String get planning_sidebar_divePlanner_subtitle =>
      'Piani di immersione multilivello';

  @override
  String get planning_sidebar_divePlanner_title => 'Pianificatore immersioni';

  @override
  String get planning_sidebar_gasCalculators_subtitle =>
      'MOD, Best Mix e altro';

  @override
  String get planning_sidebar_gasCalculators_title => 'Calcolatori gas';

  @override
  String get planning_sidebar_info_disclaimer =>
      'Gli strumenti di pianificazione sono solo a scopo di riferimento. Verifica sempre i calcoli.';

  @override
  String get planning_sidebar_surfaceInterval_subtitle =>
      'Pianificazione immersioni ripetitive';

  @override
  String get planning_sidebar_surfaceInterval_title =>
      'Intervallo di superficie';

  @override
  String get planning_sidebar_weightCalculator_subtitle =>
      'Zavorra raccomandata';

  @override
  String get planning_sidebar_weightCalculator_title => 'Calcolatore zavorra';

  @override
  String get planning_welcome_quickTips_title => 'Suggerimenti rapidi';

  @override
  String get planning_welcome_subtitle =>
      'Seleziona uno strumento dalla barra laterale per iniziare';

  @override
  String get planning_welcome_tip_decoCalculator =>
      'Calcolatore deco per NDL e tempi delle soste';

  @override
  String get planning_welcome_tip_divePlanner =>
      'Pianificatore immersioni per pianificazione multilivello';

  @override
  String get planning_welcome_tip_gasCalculators =>
      'Calcolatori gas per MOD e pianificazione gas';

  @override
  String get planning_welcome_tip_weightCalculator =>
      'Calcolatore zavorra per assetto';

  @override
  String get planning_welcome_title => 'Strumenti di pianificazione';

  @override
  String get settings_about_aboutSubmersion => 'Informazioni su Submersion';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description =>
      'Registra le tue immersioni, gestisci l\'attrezzatura ed esplora i siti di immersione.';

  @override
  String get settings_about_header => 'Informazioni';

  @override
  String get settings_about_openSourceLicenses => 'Licenze open source';

  @override
  String get settings_about_reportIssue => 'Segnala un problema';

  @override
  String get settings_about_reportIssue_copy => 'Copia link';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Visita github.com/submersion-app/submersion/issues';

  @override
  String settings_about_version(String version) {
    return 'Versione $version';
  }

  @override
  String get settings_appBar_title => 'Impostazioni';

  @override
  String get settings_appearance_appLanguage => 'Lingua dell\'app';

  @override
  String get settings_appearance_displaySize => 'Dimensione di visualizzazione';

  @override
  String settings_appearance_displaySize_value(int percent) {
    return '$percent%';
  }

  @override
  String get settings_appearance_displaySize_reset => 'Reimposta';

  @override
  String get settings_appearance_displaySize_smaller => 'Più piccolo';

  @override
  String get settings_appearance_displaySize_larger => 'Più grande';

  @override
  String get settings_appearance_depthColoredCards =>
      'Schede immersione colorate per profondità';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Mostra le schede immersione con sfondi colorati come l\'oceano in base alla profondità';

  @override
  String get settings_appearance_cardColorAttribute => 'Colora schede per';

  @override
  String get settings_appearance_cardColorAttribute_subtitle =>
      'Scegli quale attributo determina il colore di sfondo delle schede';

  @override
  String get settings_appearance_cardColorAttribute_none => 'Nessuno';

  @override
  String get settings_appearance_cardColorAttribute_depth => 'Profondità';

  @override
  String get settings_appearance_cardColorAttribute_duration => 'Durata';

  @override
  String get settings_appearance_cardColorAttribute_temperature =>
      'Temperatura';

  @override
  String get settings_appearance_colorGradient => 'Gradiente di colore';

  @override
  String get settings_appearance_colorGradient_subtitle =>
      'Scegli la gamma di colori per gli sfondi delle schede';

  @override
  String get settings_appearance_colorGradient_ocean => 'Oceano';

  @override
  String get settings_appearance_colorGradient_thermal => 'Thermal';

  @override
  String get settings_appearance_colorGradient_sunset => 'Tramonto';

  @override
  String get settings_appearance_colorGradient_forest => 'Foresta';

  @override
  String get settings_appearance_colorGradient_monochrome => 'Monocromo';

  @override
  String get settings_appearance_colorGradient_custom => 'Personalizzato';

  @override
  String get settings_appearance_gasSwitchMarkers => 'Marcatori cambio gas';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'Mostra i marcatori per i cambi gas';

  @override
  String get settings_appearance_gasTimeline => 'Cronologia del gas';

  @override
  String get settings_appearance_gasTimeline_subtitle =>
      'Visualizza la striscia di consumo del gas sotto il profilo di immersione per impostazione predefinita';

  @override
  String get settings_appearance_header_diveDetails => 'Dettagli immersione';

  @override
  String get settings_appearance_header_diveLog => 'Registro immersioni';

  @override
  String get settings_appearance_header_diveProfile => 'Profilo immersione';

  @override
  String get settings_appearance_header_diveSites => 'Siti di immersione';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility =>
      'Ordine e visibilità sezioni';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility_subtitle =>
      'Scegli quali sezioni visualizzare e il loro ordine';

  @override
  String get settings_diveDetailSections_title => 'Ordine e visibilità sezioni';

  @override
  String get settings_diveDetailSections_resetToDefault =>
      'Ripristina predefiniti';

  @override
  String get settings_diveDetailSections_fixedSections =>
      'Sezioni fisse: Intestazione, Grafico profilo immersione';

  @override
  String get settings_diveDetailSections_configurableSections =>
      'Sezioni configurabili (trascina per riordinare)';

  @override
  String get diveDetailSection_decoO2_name => 'Stato deco / Carico tessuti';

  @override
  String get diveDetailSection_decoO2_description =>
      'NDL, ceiling, mappa termica tessuti, tossicità O2';

  @override
  String get diveDetailSection_safetyReview_name => 'Revisione di sicurezza';

  @override
  String get diveDetailSection_safetyReview_description =>
      'Osservazioni automatiche del profilo dopo l\'immersione';

  @override
  String get safetyReview_sectionTitle => 'Revisione di sicurezza';

  @override
  String safetyReview_findingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count osservazioni',
      one: '1 osservazione',
    );
    return '$_temp0';
  }

  @override
  String safetyReview_rapidAscent_title(String rate, String duration) {
    return 'La risalita ha superato $rate per $duration';
  }

  @override
  String safetyReview_missedDecoStop_title(String excess, String duration) {
    return 'La profondità è rimasta $excess sopra il ceiling di tappa richiesto per $duration';
  }

  @override
  String safetyReview_omittedSafetyStop_title(String remaining) {
    return 'La tappa di sicurezza consigliata è stata accorciata di $remaining';
  }

  @override
  String safetyReview_sawtoothProfile_title(int count) {
    return '$count variazioni ripetute di profondità su e giù durante l\'immersione';
  }

  @override
  String safetyReview_highSurfaceGf_title(String gf, String gfHigh) {
    return 'Emersione con fattore di gradiente $gf, oltre il $gfHigh configurato';
  }

  @override
  String safetyReview_timeRange(String start, String end) {
    return 'A $start–$end';
  }

  @override
  String get safetyReview_dismiss => 'Ignora';

  @override
  String get safetyReview_restore => 'Ripristina';

  @override
  String get safetyReview_dismissAll => 'Ignora tutto';

  @override
  String get safetyReview_restoreAll => 'Ripristina tutto';

  @override
  String get safetySettings_dismissAll => 'Ignora tutte le osservazioni';

  @override
  String get safetySettings_dismissAll_subtitle =>
      'Contrassegna come riviste tutte le osservazioni di questo diario';

  @override
  String get safetySettings_dismissAll_confirmTitle =>
      'Ignorare tutte le osservazioni?';

  @override
  String get safetySettings_dismissAll_confirmBody =>
      'Tutte le osservazioni di ogni immersione analizzata verranno contrassegnate come riviste. Puoi ripristinarle una immersione alla volta dalla sua sezione revisione di sicurezza.';

  @override
  String get safetySettings_dismissAll_confirm => 'Ignora tutto';

  @override
  String get safetySettings_dismissAll_cancel => 'Annulla';

  @override
  String safetySettings_dismissAll_progress(int done, int total) {
    return '$done di $total immersioni controllate';
  }

  @override
  String safetySettings_dismissAll_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count osservazioni ignorate',
      one: '1 osservazione ignorata',
      zero: 'Nessuna osservazione da ignorare',
    );
    return '$_temp0';
  }

  @override
  String safetySettings_dismissAll_doneWithErrors(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count osservazioni ignorate',
      one: '1 osservazione ignorata',
      zero: 'Nessuna osservazione ignorata',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed immersioni non sono state aggiornate',
      one: '1 immersione non è stata aggiornata',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get safetySettings_dismissAll_failed =>
      'Impossibile leggere l’elenco delle immersioni. Nulla è stato modificato.';

  @override
  String get safetySettings_analyzeAll_failed =>
      'Impossibile analizzare le immersioni.';

  @override
  String get safetyReview_details => 'Dettagli';

  @override
  String get safetyReview_clearHighlight => 'Rimuovi evidenziazione';

  @override
  String safetyReview_findingGroupSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rilievi di sicurezza',
      one: '1 rilievo di sicurezza',
    );
    return '$_temp0';
  }

  @override
  String get safetySettings_title => 'Revisione di sicurezza';

  @override
  String get safetySettings_entry_subtitle =>
      'Osservazioni e regole post-immersione';

  @override
  String get safetySettings_masterToggle =>
      'Revisione di sicurezza post-immersione';

  @override
  String get safetySettings_masterToggle_subtitle =>
      'Annota automaticamente osservazioni su risalita, tappe e profilo nelle immersioni analizzate';

  @override
  String get safetySettings_rulesHeader => 'Regole';

  @override
  String get safetySettings_rule_rapidAscent => 'Risalite rapide';

  @override
  String get safetySettings_rule_missedDecoStop =>
      'Tappe deco saltate o accorciate';

  @override
  String get safetySettings_rule_omittedSafetyStop =>
      'Tappe di sicurezza omesse';

  @override
  String get safetySettings_rule_sawtoothProfile => 'Profili a dente di sega';

  @override
  String get safetySettings_rule_highSurfaceGf =>
      'Fattore di gradiente alto in emersione';

  @override
  String get safetySettings_analyzeAll => 'Analizza tutte le immersioni';

  @override
  String get safetySettings_analyzeAll_subtitle =>
      'Esegui la revisione di sicurezza su tutte le immersioni con profilo non ancora analizzate';

  @override
  String safetySettings_analyzeAll_progress(int done, int total) {
    return 'Analizzate $done di $total';
  }

  @override
  String get safetySettings_analyzeAll_done => 'Analisi completata';

  @override
  String safetySettings_analyzeAll_doneWithErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Impossibile analizzare $count immersioni',
      one: 'Impossibile analizzare 1 immersione',
    );
    return 'Analisi completata — $_temp0';
  }

  @override
  String safetyReview_showDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostra $count ignorate',
      one: 'Mostra 1 ignorata',
    );
    return '$_temp0';
  }

  @override
  String get diveDetailSection_sacSegments_name => 'SAC Rate per segmento';

  @override
  String get diveDetailSection_sacSegments_description =>
      'Segmentazione SAC per fase/tempo';

  @override
  String get diveDetailSection_details_name => 'Dettagli';

  @override
  String get diveDetailSection_details_description =>
      'Tipo, posizione, viaggio, centro subacqueo, intervallo';

  @override
  String get diveDetailSection_environment_name => 'Ambiente';

  @override
  String get diveDetailSection_environment_description =>
      'Temperatura aria/acqua, visibilità, corrente';

  @override
  String get diveDetailSection_altitude_name => 'Altitudine';

  @override
  String get diveDetailSection_altitude_description =>
      'Valore altitudine, categoria, requisito deco';

  @override
  String get diveDetailSection_tide_name => 'Marea';

  @override
  String get diveDetailSection_tide_description =>
      'Grafico ciclo marea e tempi';

  @override
  String get diveDetailSection_reefHealth_name => 'Condizioni dell\'acqua';

  @override
  String get diveDetailSection_reefHealth_description =>
      'Condizioni dell\'acqua da satellite alla data dell\'immersione';

  @override
  String get diveDetailSection_surfaceGps_name => 'GPS di superficie';

  @override
  String get diveDetailSection_surfaceGps_description =>
      'Punti GPS di entrata/uscita e deriva in superficie';

  @override
  String get diveLog_detail_section_surfaceGps => 'GPS di superficie';

  @override
  String get diveLog_detail_surfaceGps_entry => 'Entrata';

  @override
  String get diveLog_detail_surfaceGps_exit => 'Uscita';

  @override
  String get diveLog_detail_label_drift => 'Deriva';

  @override
  String get diveLog_detail_surfaceGps_entryOnly =>
      'Punto di entrata registrato';

  @override
  String get diveLog_detail_surfaceGps_exitOnly => 'Punto di uscita registrato';

  @override
  String get diveLog_detail_surfaceGps_site => 'Sito';

  @override
  String get diveLog_detail_surfaceGps_track => 'Traccia di superficie';

  @override
  String get diveLog_detail_surfaceGps_showFullTrack => 'Traccia completa';

  @override
  String diveLog_detail_surfaceGps_trackFixes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punti',
      one: '1 punto',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_detail_locationsMap_title => 'Posizioni dell\'immersione';

  @override
  String get diveLog_detail_coordinatesCopied =>
      'Coordinate copiate negli appunti';

  @override
  String get diveLog_detail_openInMaps => 'Apri in Mappe';

  @override
  String get diveDetailSection_weights_name => 'Zavorra';

  @override
  String get diveDetailSection_weights_description =>
      'Ripartizione pesi, peso totale';

  @override
  String get diveDetailSection_buoyancy_name => 'Assetto';

  @override
  String get diveDetailSection_buoyancy_description =>
      'Assetto durante l\'immersione, variazione, zavorra sganciabile';

  @override
  String get buoyancy_tooltip =>
      'Assetto netto modellato durante l\'immersione da profilo, consumo di gas ed equipaggiamento.';

  @override
  String buoyancy_verdictBuoyant(String depth, String amount) {
    return 'Alla tua ultima sosta (~$depth) avevi circa $amount di spinta';
  }

  @override
  String buoyancy_verdictHeavy(String depth, String amount) {
    return 'Alla tua ultima sosta (~$depth) eri circa $amount troppo pesante';
  }

  @override
  String get buoyancy_verdictNeutral =>
      'La tua configurazione era quasi neutra all\'ultima sosta';

  @override
  String get buoyancy_verdictConvention =>
      'Stimato secondo la convenzione della sosta di sicurezza a 5 m';

  @override
  String get buoyancy_breakdownTitle => 'Dettaglio dei termini';

  @override
  String get buoyancy_suitTerm => 'Muta';

  @override
  String get buoyancy_leadTerm => 'Zavorra';

  @override
  String get buoyancy_beginNet => 'Inizio immersione';

  @override
  String get buoyancy_endNet => 'Fine immersione';

  @override
  String get buoyancy_swing => 'Variazione di assetto';

  @override
  String get buoyancy_peakLift => 'Spinta massima necessaria';

  @override
  String get buoyancy_wingWarning => 'Supera la portanza nominale del tuo GAV';

  @override
  String get buoyancy_minDitchable => 'Zavorra sganciabile minima';

  @override
  String get buoyancy_droppable => 'Puoi sganciare';

  @override
  String get buoyancy_ditchWarning => 'Più di quanto puoi sganciare';

  @override
  String get buoyancy_drysuitGas => 'Gas muta stagna aggiunto';

  @override
  String get buoyancy_estimatedPressures =>
      'Le pressioni delle bombole sono stimate';

  @override
  String get buoyancy_linkSuitHint =>
      'Associa una muta a questa immersione per un quadro più completo';

  @override
  String get buoyancy_noLeadHint =>
      'Nessuna zavorra registrata: aggiungi zavorra a questa immersione o un peso a secco alla tua attrezzatura di zavorra';

  @override
  String get buoyancy_chartNet => 'Netto';

  @override
  String get buoyancy_chartRig => 'Attrezzatura + zavorra';

  @override
  String get buoyancy_chartMinutes => 'Tempo (min)';

  @override
  String get buoyancy_historyTitle => 'Cronologia zavorra';

  @override
  String get buoyancy_historyCarried => 'Portato';

  @override
  String get buoyancy_historyModeled => 'Modellato';

  @override
  String buoyancy_historyMore(String delta) {
    return 'Di solito porti $delta in più rispetto al modello';
  }

  @override
  String buoyancy_historyLess(String delta) {
    return 'Di solito porti $delta in meno rispetto al modello';
  }

  @override
  String get buoyancy_throughDive => 'Durante l\'immersione';

  @override
  String get buoyancy_adjust => 'Regola';

  @override
  String get buoyancy_whatIfTitle => 'Regola questa immersione';

  @override
  String get buoyancy_whatIfLead => 'Zavorra';

  @override
  String get buoyancy_whatIfSuit => 'Spinta della muta';

  @override
  String get buoyancy_whatIfReset => 'Ripristina';

  @override
  String buoyancy_whatIfDelta(String delta) {
    return '$delta vs reale';
  }

  @override
  String get diveDetailSection_tanks_name => 'Bombole';

  @override
  String get diveDetailSection_tanks_description =>
      'Elenco bombole, miscele gas, pressioni, SAC per bombola';

  @override
  String get diveDetailSection_buddies_name => 'Buddy';

  @override
  String get diveDetailSection_buddies_description => 'Elenco buddy con ruoli';

  @override
  String get diveDetailSection_signatures_name => 'Firme';

  @override
  String get diveDetailSection_signatures_description =>
      'Visualizzazione e acquisizione firma buddy/istruttore';

  @override
  String get diveDetailSection_equipment_name => 'Attrezzatura';

  @override
  String get diveDetailSection_equipment_description =>
      'Attrezzatura utilizzata nell\'immersione';

  @override
  String get diveDetailSection_sightings_name => 'Avvistamenti vita marina';

  @override
  String get diveDetailSection_sightings_description =>
      'Specie avvistate, dettagli avvistamento';

  @override
  String get diveDetailSection_media_name => 'Media';

  @override
  String get diveDetailSection_media_description => 'Galleria foto/video';

  @override
  String get diveDetailSection_tags_name => 'Tag';

  @override
  String get diveDetailSection_tags_description => 'Tag immersione';

  @override
  String get diveDetailSection_notes_name => 'Note';

  @override
  String get diveDetailSection_notes_description =>
      'Note/descrizione immersione';

  @override
  String get diveDetailSection_customFields_name => 'Campi personalizzati';

  @override
  String get diveDetailSection_customFields_description =>
      'Campi personalizzati definiti dall\'utente';

  @override
  String get diveDetailSection_dataSources_name => 'Sorgenti dati';

  @override
  String get diveDetailSection_dataSources_description =>
      'Computer subacquei collegati, gestione sorgenti';

  @override
  String get settings_appearance_header_language => 'Lingua';

  @override
  String get settings_appearance_header_theme => 'Tema';

  @override
  String get settings_appearance_header_mode => 'Modalita';

  @override
  String get settings_themes_title => 'Scegli tema';

  @override
  String get settings_themes_current => 'Tema';

  @override
  String get theme_submersion => 'Submersion';

  @override
  String get theme_console => 'Console';

  @override
  String get theme_tropical => 'Tropicale';

  @override
  String get theme_minimalist => 'Minimalista';

  @override
  String get theme_deep => 'Abissale';

  @override
  String get settings_appearance_mapBackgroundDiveCards =>
      'Mappa di sfondo sulle schede immersione';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitle =>
      'Mostra la mappa del sito di immersione come sfondo sulle schede immersione';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote =>
      'Mostra la mappa del sito di immersione come sfondo sulle schede immersione (richiede la posizione del sito)';

  @override
  String get settings_appearance_mapBackgroundSiteCards =>
      'Mappa di sfondo sulle schede sito';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitle =>
      'Mostra la mappa come sfondo sulle schede dei siti di immersione';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote =>
      'Mostra la mappa come sfondo sulle schede dei siti di immersione (richiede la posizione del sito)';

  @override
  String get settings_appearance_maxDepthMarker =>
      'Marcatore profondità massima';

  @override
  String get settings_appearance_maxDepthMarker_subtitle =>
      'Mostra un marcatore nel punto di profondità massima';

  @override
  String get settings_appearance_maxDepthMarker_subtitleFull =>
      'Mostra un marcatore nel punto di profondità massima sui profili immersione';

  @override
  String get settings_appearance_metric_ascentRateColors =>
      'Colori velocità di risalita';

  @override
  String get settings_appearance_metric_ceiling => 'Ceiling';

  @override
  String get settings_appearance_metric_events => 'Eventi';

  @override
  String get settings_appearance_metric_estimatedTankPressure =>
      'Pressione stimata della bombola';

  @override
  String get settings_appearance_metric_gasDensity => 'Densità gas';

  @override
  String get settings_appearance_metric_gfPercent => 'GF%';

  @override
  String get settings_appearance_metric_heartRate => 'Frequenza cardiaca';

  @override
  String get settings_appearance_metric_meanDepth => 'Profondità media';

  @override
  String get settings_appearance_metric_ndl => 'NDL';

  @override
  String get settings_appearance_metric_ppHe => 'ppHe';

  @override
  String get settings_appearance_metric_ppN2 => 'ppN2';

  @override
  String get settings_appearance_metric_ppO2 => 'ppO2';

  @override
  String get settings_appearance_metric_pressure => 'Pressione';

  @override
  String get settings_appearance_metric_sacRate => 'SAC Rate';

  @override
  String get settings_appearance_metric_surfaceGf => 'GF in superficie';

  @override
  String get settings_appearance_metric_temperature => 'Temperatura';

  @override
  String get settings_appearance_metric_tts => 'TTS (Tempo per la superficie)';

  @override
  String get settings_appearance_metric_cns => 'CNS% (Tossicita O2)';

  @override
  String get settings_appearance_metric_otu => 'OTU (Unita di tolleranza O2)';

  @override
  String get settings_appearance_metric_photoMarkers => 'Indicatori foto';

  @override
  String settings_appearance_metricsEnabledCount(int count, int total) {
    return '$count di $total abilitati';
  }

  @override
  String get settings_appearance_pressureThresholdMarkers =>
      'Marcatori soglia pressione';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Mostra i marcatori quando la pressione della bombola supera le soglie';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Mostra i marcatori quando la pressione della bombola supera le soglie di 2/3, 1/2 e 1/3';

  @override
  String get settings_appearance_metricsFollowViewport =>
      'Mantieni le sovrapposizioni in vista durante lo zoom';

  @override
  String get settings_appearance_metricsFollowViewport_subtitle =>
      'Adatta le sovrapposizioni come NDL e ppO2 all\'area visibile invece di ingrandirle con l\'asse della profondità';

  @override
  String get settings_appearance_rightYAxisMetric => 'Metrica asse Y destro';

  @override
  String get settings_appearance_rightYAxisMetric_subtitle =>
      'Metrica predefinita mostrata sull\'asse destro';

  @override
  String get settings_appearance_subsection_decompressionMetrics =>
      'Metriche di decompressione';

  @override
  String get settings_appearance_subsection_defaultVisibleMetrics =>
      'Metriche visibili predefinite';

  @override
  String get settings_appearance_subsection_standardMetrics =>
      'Standard Metrics';

  @override
  String get settings_appearance_subsection_gasAnalysisMetrics =>
      'Metriche di analisi gas';

  @override
  String get settings_appearance_subsection_gradientFactorMetrics =>
      'Metriche fattori di gradiente';

  @override
  String get settings_appearance_theme_dark => 'Scuro';

  @override
  String get settings_appearance_theme_light => 'Chiaro';

  @override
  String get settings_appearance_theme_system => 'Predefinito di sistema';

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
  String get settings_backToSettings_tooltip => 'Torna alle impostazioni';

  @override
  String get settings_cloudSync_appBar_title =>
      'Sincronizzazione cloud del database';

  @override
  String get settings_cloudSync_autoSync => 'Sincronizzazione automatica';

  @override
  String get settings_cloudSync_autoSync_subtitle =>
      'Sincronizza automaticamente dopo le modifiche';

  @override
  String settings_cloudSync_conflictItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi richiedono attenzione',
      one: '1 elemento richiede attenzione',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_disabledBanner_content =>
      'La sincronizzazione cloud gestita dall\'app è disabilitata perché stai utilizzando una cartella personalizzata. Il servizio di sincronizzazione della tua cartella (Dropbox, Google Drive, OneDrive, ecc.) gestisce la sincronizzazione.';

  @override
  String get settings_cloudSync_disabledBanner_title =>
      'Sincronizzazione cloud disabilitata';

  @override
  String get settings_cloudSync_entry_subtitle =>
      'Sincronizzazione tramite archiviazione cloud';

  @override
  String get settings_cloudSync_adopt_confirm =>
      'Adotta la libreria ripristinata';

  @override
  String settings_cloudSync_adopt_dialogContent(
    String deviceName,
    String date,
  ) {
    return 'La libreria è stata sostituita da un backup su \"$deviceName\" ($date). Adottandola, i dati di questo dispositivo verranno sostituiti con la libreria ripristinata. Prima verrà creato un backup di sicurezza dei dati attuali di questo dispositivo.';
  }

  @override
  String get settings_cloudSync_adopt_dialogTitle =>
      'Adottare la libreria ripristinata?';

  @override
  String get settings_cloudSync_adopt_notNow => 'Non ora';

  @override
  String get settings_cloudSync_dangerZone => 'Zona pericolosa';

  @override
  String get settings_cloudSync_replaceLibrary_tile =>
      'Sostituisci la libreria cloud';

  @override
  String get settings_cloudSync_replaceLibrary_tileSubtitle =>
      'Rendi la libreria di questo dispositivo quella usata da tutti i dispositivi';

  @override
  String get settings_cloudSync_replaceLibrary_dialogTitle =>
      'Sostituire la libreria cloud?';

  @override
  String get settings_cloudSync_replaceLibrary_dialogIntro =>
      'La libreria di questo dispositivo diventa quella usata da tutti i dispositivi.';

  @override
  String settings_cloudSync_replaceLibrary_dialogBody(num diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other:
          'La libreria cloud viene cancellata e sostituita con le $diveCount immersioni di questo dispositivo.',
      one:
          'La libreria cloud viene cancellata e sostituita con la 1 immersione di questo dispositivo.',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_replaceLibrary_peers(num peerCount) {
    String _temp0 = intl.Intl.pluralLogic(
      peerCount,
      locale: localeName,
      other:
          'A $peerCount altri dispositivi verrà chiesto di adottarla; fino ad allora le loro modifiche non vengono unite.',
      one:
          'A 1 altro dispositivo verrà chiesto di adottarla; fino ad allora le sue modifiche non vengono unite.',
      zero:
          'Nessun altro dispositivo si sincronizza ancora, quindi non c\'è nulla da adottare.',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_replaceLibrary_peersUnknown =>
      'A tutti gli altri dispositivi verrà chiesto di adottarla; fino ad allora le loro modifiche non vengono unite.';

  @override
  String get settings_cloudSync_replaceLibrary_backupNote =>
      'Prima viene creato un backup di questo dispositivo. L\'operazione non può essere annullata.';

  @override
  String get settings_cloudSync_replaceLibrary_confirmWord => 'Sostituisci';

  @override
  String get settings_cloudSync_replaceLibrary_confirmHint =>
      'Digita \"Sostituisci\" per confermare';

  @override
  String get settings_cloudSync_replaceLibrary_confirm => 'Sostituisci';

  @override
  String get settings_cloudSync_firstSync_banner =>
      'La prima sincronizzazione è in attesa di conferma. Tocca \'Sincronizza ora\' per controllare cosa verrà combinato.';

  @override
  String get settings_cloudSync_firstSync_dialogConfirm =>
      'Unisci e sincronizza';

  @override
  String get settings_cloudSync_firstSync_replaceHint =>
      'Se invece la libreria di questo dispositivo deve sostituire quella nel cloud, annulla e usa Impostazioni > Sincronizzazione cloud > Sostituisci la libreria cloud.';

  @override
  String settings_cloudSync_firstSync_dialogContent(
    int deviceCount,
    int diveCount,
  ) {
    return 'Nel cloud sono stati trovati dati di sincronizzazione esistenti ($deviceCount file di sincronizzazione). La prima sincronizzazione combinerà quei dati con le $diveCount immersioni presenti su questo dispositivo, su tutti i dispositivi sincronizzati.\n\nSe le stesse immersioni sono state aggiunte separatamente su ogni dispositivo, appariranno due volte.';
  }

  @override
  String get settings_cloudSync_firstSync_dialogTitle =>
      'Combinare le librerie?';

  @override
  String settings_cloudSync_replace_banner(String deviceName) {
    return 'Sincronizzazione in pausa: la libreria è stata sostituita da un backup su \"$deviceName\". Tocca Sincronizza ora per controllare.';
  }

  @override
  String get settings_cloudSync_switch_dialogTitle =>
      'Cambiare servizio di sincronizzazione?';

  @override
  String settings_cloudSync_switch_dialogContent(
    String fromName,
    String toName,
  ) {
    return 'I tuoi dati non verranno spostati da $fromName: rimangono lì finché non li elimini. Dopo il cambio, la prossima sincronizzazione di questo dispositivo combina i suoi dati con quanto già presente su $toName. Gli altri tuoi dispositivi continuano a usare $fromName finché non cambi anche ciascuno di essi.';
  }

  @override
  String get settings_cloudSync_switch_confirm => 'Cambia';

  @override
  String settings_cloudSync_moved_banner(
    String deviceName,
    String destination,
  ) {
    return '$deviceName ha spostato questa libreria su $destination. Questo servizio non viene più aggiornato da esso. Seleziona $destination qui sotto per seguire lo spostamento.';
  }

  @override
  String get settings_cloudSync_moved_dismiss => 'Ignora';

  @override
  String settings_cloudSync_cleanup_banner(String backend) {
    return 'Su $backend sono ancora archiviati vecchi dati di sincronizzazione da prima del cambio di servizio. Non vengono più utilizzati.';
  }

  @override
  String get settings_cloudSync_cleanup_delete => 'Elimina vecchi dati';

  @override
  String get settings_cloudSync_cleanup_keep => 'Mantieni';

  @override
  String get settings_cloudSync_header_advanced => 'Avanzate';

  @override
  String get settings_cloudSync_signOut_backupWarning =>
      'Il backup cloud verrà disattivato e i backup verranno salvati nella posizione predefinita.';

  @override
  String get settings_cloudSync_header_cloudProvider => 'Provider cloud';

  @override
  String settings_cloudSync_header_conflicts(Object count) {
    return 'Conflitti ($count)';
  }

  @override
  String get settings_cloudSync_header_syncBehavior =>
      'Comportamento sincronizzazione';

  @override
  String settings_cloudSync_lastSynced(Object time) {
    return 'Ultima sincronizzazione: $time';
  }

  @override
  String settings_cloudSync_pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifiche in sospeso',
      one: '1 modifica in sospeso',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_banner(Object deviceList) {
    return '$deviceList ha ancora una versione della libreria più vecchia o sconosciuta, quindi le sue modifiche non sono state unite. Apri Submersion su di esso per adottare la libreria attuale.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_bannerPlural(Object deviceList) {
    return '$deviceList hanno ancora una versione della libreria più vecchia o sconosciuta, quindi le loro modifiche non sono state unite. Apri Submersion su di essi per adottare la libreria attuale.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_unnamedDevice(Object shortId) {
    return 'dispositivo $shortId';
  }

  @override
  String get settings_cloudSync_peerNeedsAdopt_listSeparator => ', ';

  @override
  String get settings_cloudSync_peerNeedsAdopt_listLastSeparator => ' e ';

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamed(Object deviceList) {
    return '$deviceList si sincronizza da una versione più recente di Submersion, quindi le sue ultime modifiche sono per ora trattenute.';
  }

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(
    Object deviceList,
  ) {
    return '$deviceList si sincronizzano da una versione più recente di Submersion, quindi le loro ultime modifiche sono per ora trattenute.';
  }

  @override
  String get settings_cloudSync_peerRequiresUpdate_updateAction =>
      'Aggiorna questo dispositivo per riceverle.';

  @override
  String get settings_cloudSync_peerRequiresUpdate_storeAction =>
      'Verranno applicate automaticamente quando arriverà l\'aggiornamento dell\'app store per questo dispositivo; l\'aggiornamento potrebbe essere ancora in revisione.';

  @override
  String get settings_cloudSync_provider_connected => 'Connesso';

  @override
  String settings_cloudSync_provider_connectedTo(Object providerName) {
    return 'Connesso a $providerName';
  }

  @override
  String settings_cloudSync_provider_connectionFailed(
    Object providerName,
    Object error,
  ) {
    return 'Connessione a $providerName non riuscita: $error';
  }

  @override
  String get settings_cloudSync_dropbox_account_title => 'Account Dropbox';

  @override
  String get settings_cloudSync_dropbox_connect_browserFailed =>
      'Impossibile aprire il browser. Prova il pulsante Riapri browser.';

  @override
  String get settings_cloudSync_dropbox_connect_codeLabel =>
      'Codice di autorizzazione';

  @override
  String get settings_cloudSync_dropbox_connect_emptyCode =>
      'Inserisci il codice di autorizzazione mostrato nel tuo browser';

  @override
  String settings_cloudSync_dropbox_connect_failed(Object error) {
    return 'Impossibile connettersi a Dropbox: $error';
  }

  @override
  String get settings_cloudSync_dropbox_connect_instructions =>
      'Il tuo browser ha aperto una pagina di autorizzazione Dropbox. Approva l\'accesso, poi incolla qui il codice mostrato da Dropbox.';

  @override
  String get settings_cloudSync_dropbox_connect_reopenBrowser =>
      'Riapri browser';

  @override
  String get settings_cloudSync_dropbox_connect_submit => 'Connetti';

  @override
  String get settings_cloudSync_dropbox_connect_title => 'Connetti Dropbox';

  @override
  String get settings_cloudSync_dropbox_connected => 'Connesso a Dropbox';

  @override
  String settings_cloudSync_dropbox_connectedAs(Object account) {
    return 'Connesso come $account';
  }

  @override
  String get settings_cloudSync_dropbox_disconnect => 'Disconnetti';

  @override
  String get settings_cloudSync_provider_dropbox_subtitle =>
      'Sincronizza tramite Dropbox (Apps/Submersion)';

  @override
  String get settings_cloudSync_provider_dropbox_title => 'Dropbox';

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Sincronizza tramite Google Drive';

  @override
  String get settings_cloudSync_googleDrive_desktopNotConfigured =>
      'Non disponibile in questa build';

  @override
  String get settings_cloudSync_googleDrive_browserWait_title =>
      'Continua nel browser';

  @override
  String get settings_cloudSync_googleDrive_browserWait_message =>
      'Completa l\'accesso a Google nel tuo browser web, poi torna a Submersion.';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Inizializzazione del provider $providerName non riuscita';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Non disponibile su questa piattaforma';

  @override
  String get settings_cloudSync_provider_s3_edit =>
      'Modifica configurazione S3';

  @override
  String get settings_cloudSync_provider_s3_subtitle =>
      'Funziona con qualsiasi servizio di archiviazione compatibile con S3';

  @override
  String get settings_cloudSync_provider_s3_title =>
      'Archiviazione compatibile S3';

  @override
  String get settings_cloudSync_resetDialog_cancel => 'Annulla';

  @override
  String get settings_cloudSync_resetDialog_content =>
      'Questo cancellerà tutta la cronologia di sincronizzazione e ricomincerà da capo. I tuoi dati non verranno eliminati, ma potresti dover risolvere conflitti alla prossima sincronizzazione.';

  @override
  String get settings_cloudSync_resetDialog_reset => 'Ripristina';

  @override
  String get settings_cloudSync_resetDialog_title =>
      'Ripristinare lo stato di sincronizzazione?';

  @override
  String get settings_cloudSync_resetSuccess =>
      'Stato di sincronizzazione ripristinato';

  @override
  String get settings_cloudSync_resetSyncState =>
      'Ripristina stato sincronizzazione';

  @override
  String get settings_cloudSync_resetSyncState_subtitle =>
      'Cancella cronologia sincronizzazione e ricomincia';

  @override
  String get settings_cloudSync_resolveConflicts => 'Risolvi conflitti';

  @override
  String get settings_cloudSync_selectProviderHint =>
      'Seleziona un provider cloud per abilitare la sincronizzazione';

  @override
  String get settings_cloudSync_signOut => 'Disconnetti';

  @override
  String get settings_cloudSync_signOutDialog_cancel => 'Annulla';

  @override
  String get settings_cloudSync_signOutDialog_content =>
      'Questo disconnetterà dal provider cloud. I tuoi dati locali rimarranno intatti.';

  @override
  String get settings_cloudSync_signOutDialog_signOut => 'Disconnetti';

  @override
  String get settings_cloudSync_signOutDialog_title => 'Disconnettersi?';

  @override
  String get settings_cloudSync_signOutSuccess =>
      'Disconnesso dal provider cloud';

  @override
  String get settings_cloudSync_signOut_subtitle =>
      'Disconnetti dal provider cloud';

  @override
  String get settings_cloudSync_status_conflictsDetected =>
      'Conflitti rilevati';

  @override
  String get settings_cloudSync_status_readyToSync =>
      'Pronto per la sincronizzazione';

  @override
  String get settings_cloudSync_status_syncComplete =>
      'Sincronizzazione completata';

  @override
  String get settings_cloudSync_status_syncError =>
      'Errore di sincronizzazione';

  @override
  String get settings_cloudSync_status_syncing =>
      'Sincronizzazione in corso...';

  @override
  String get settings_cloudSync_storageSettings => 'Impostazioni archiviazione';

  @override
  String get settings_cloudSync_syncNow => 'Sincronizza ora';

  @override
  String get settings_cloudSync_syncOnLaunch => 'Sincronizza all\'avvio';

  @override
  String get settings_cloudSync_syncOnLaunch_subtitle =>
      'Controlla gli aggiornamenti all\'avvio';

  @override
  String get settings_cloudSync_syncOnResume => 'Sincronizza alla ripresa';

  @override
  String get settings_cloudSync_syncOnResume_subtitle =>
      'Controlla gli aggiornamenti quando l\'app diventa attiva';

  @override
  String settings_cloudSync_syncProgressPercent(Object percent) {
    return 'Progresso sincronizzazione: $percent percento';
  }

  @override
  String settings_cloudSync_time_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni fa',
      one: '1 giorno fa',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_time_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ore fa',
      one: '1 ora fa',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_time_justNow => 'Proprio ora';

  @override
  String settings_cloudSync_time_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuti fa',
      one: '1 minuto fa',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_applyAll => 'Applica a tutti';

  @override
  String get settings_conflict_cancel => 'Annulla';

  @override
  String get settings_conflict_chooseResolution => 'Scegli risoluzione';

  @override
  String get settings_conflict_close => 'Chiudi';

  @override
  String get settings_conflict_close_tooltip => 'Chiudi finestra conflitti';

  @override
  String settings_conflict_counterLabel(Object current, Object total) {
    return 'Conflitto $current di $total';
  }

  @override
  String settings_conflict_errorLoading(Object error) {
    return 'Errore nel caricamento dei conflitti: $error';
  }

  @override
  String get settings_conflict_keepBoth => 'Mantieni entrambi';

  @override
  String get settings_conflict_keepLocal => 'Mantieni locale';

  @override
  String get settings_conflict_keepRemote => 'Mantieni remoto';

  @override
  String get settings_conflict_localVersion => 'Versione locale';

  @override
  String settings_conflict_modified(Object time) {
    return 'Modificato: $time';
  }

  @override
  String get settings_conflict_next_tooltip => 'Conflitto successivo';

  @override
  String get settings_conflict_noConflicts_message =>
      'Tutti i conflitti di sincronizzazione sono stati risolti.';

  @override
  String get settings_conflict_noConflicts_title => 'Nessun conflitto';

  @override
  String get settings_conflict_noDataAvailable => 'Nessun dato disponibile';

  @override
  String get settings_conflict_previous_tooltip => 'Conflitto precedente';

  @override
  String get settings_conflict_ref_buddy => 'Compagno';

  @override
  String get settings_conflict_ref_certification => 'Certificazione';

  @override
  String get settings_conflict_ref_checklistTemplate =>
      'Modello di lista di controllo';

  @override
  String get settings_conflict_ref_connectedAccount => 'Account collegato';

  @override
  String get settings_conflict_ref_course => 'Corso';

  @override
  String get settings_conflict_ref_courseRequirement => 'Requisito del corso';

  @override
  String get settings_conflict_ref_cylinderConfig => 'Configurazione bombole';

  @override
  String get settings_conflict_ref_dataSource => 'Origine dati';

  @override
  String get settings_conflict_ref_dive => 'Immersione';

  @override
  String get settings_conflict_ref_diveCenter => 'Centro immersioni';

  @override
  String get settings_conflict_ref_diveComputer => 'Computer subacqueo';

  @override
  String get settings_conflict_ref_divePlan => 'Piano di immersione';

  @override
  String get settings_conflict_ref_diveSite => 'Sito di immersione';

  @override
  String get settings_conflict_ref_diveType => 'Tipo di immersione';

  @override
  String get settings_conflict_ref_diver => 'Subacqueo';

  @override
  String get settings_conflict_ref_equipment => 'Attrezzatura';

  @override
  String get settings_conflict_ref_equipmentSet => 'Set di attrezzatura';

  @override
  String get settings_conflict_ref_finding => 'Rilievo';

  @override
  String get settings_conflict_ref_instructor => 'Istruttore';

  @override
  String get settings_conflict_ref_linkedDive => 'Immersione collegata';

  @override
  String get settings_conflict_ref_media => 'Media';

  @override
  String get settings_conflict_ref_mediaSubscription => 'Abbonamento media';

  @override
  String get settings_conflict_ref_missing => 'Non è più in questa libreria';

  @override
  String settings_conflict_ref_named(Object name, Object date) {
    return '$name ($date)';
  }

  @override
  String get settings_conflict_ref_plannedTank => 'Bombola pianificata';

  @override
  String get settings_conflict_ref_preDiveChecklistTemplate =>
      'Modello di lista pre-immersione';

  @override
  String get settings_conflict_ref_preDiveSession => 'Lista pre-immersione';

  @override
  String get settings_conflict_ref_relatedDive => 'Immersione correlata';

  @override
  String get settings_conflict_ref_serviceKind => 'Tipo di revisione';

  @override
  String get settings_conflict_ref_sighting => 'Avvistamento';

  @override
  String get settings_conflict_ref_signer => 'Firmato da';

  @override
  String get settings_conflict_ref_sourceDive => 'Immersione di origine';

  @override
  String get settings_conflict_ref_species => 'Specie';

  @override
  String get settings_conflict_ref_tag => 'Tag';

  @override
  String get settings_conflict_ref_tank => 'Bombola';

  @override
  String get settings_conflict_ref_trip => 'Viaggio';

  @override
  String get settings_conflict_remoteVersion => 'Versione remota';

  @override
  String settings_conflict_resolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conflitti risolti',
      one: '1 conflitto risolto',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_title => 'Risolvi conflitti';

  @override
  String get settings_data_appDefaultLocation =>
      'Posizione predefinita dell\'app';

  @override
  String get settings_data_backup => 'Backup e ripristino';

  @override
  String get settings_data_backup_subtitle => 'Crea un backup dei tuoi dati';

  @override
  String get settings_data_cloudSync => 'Sincronizzazione cloud del database';

  @override
  String get settings_data_customFolder => 'Cartella personalizzata';

  @override
  String get settings_data_databaseStorage => 'Archiviazione database';

  @override
  String get settings_data_export_completed => 'Esportazione completata';

  @override
  String get settings_data_export_exporting => 'Esportazione in corso...';

  @override
  String settings_data_export_failed(Object error) {
    return 'Esportazione non riuscita: $error';
  }

  @override
  String get settings_data_header_backupSync => 'Backup e sincronizzazione';

  @override
  String get settings_data_header_storage => 'Archiviazione';

  @override
  String get settings_data_import_completed => 'Operazione completata';

  @override
  String settings_data_import_failed(Object error) {
    return 'Operazione non riuscita: $error';
  }

  @override
  String get settings_data_offlineMaps => 'Mappe offline';

  @override
  String get settings_data_offlineMaps_subtitle =>
      'Scarica mappe per l\'uso offline';

  @override
  String get settings_data_restore => 'Ripristina';

  @override
  String get settings_data_restoreDialog_cancel => 'Annulla';

  @override
  String get settings_data_restoreDialog_content =>
      'Attenzione: il ripristino da un backup sostituirà TUTTI i dati attuali con i dati del backup. Questa azione non può essere annullata.\n\nSei sicuro di voler continuare?';

  @override
  String get settings_data_restoreDialog_restore => 'Ripristina';

  @override
  String get settings_data_restoreDialog_title => 'Ripristina backup';

  @override
  String get settings_data_restore_subtitle => 'Ripristina da backup';

  @override
  String settings_data_syncTime_daysAgo(Object count) {
    return '${count}g fa';
  }

  @override
  String settings_data_syncTime_hoursAgo(Object count) {
    return '${count}h fa';
  }

  @override
  String get settings_data_syncTime_justNow => 'Proprio ora';

  @override
  String settings_data_syncTime_minutesAgo(Object count) {
    return '${count}m fa';
  }

  @override
  String settings_data_sync_lastSynced(Object time) {
    return 'Ultima sincronizzazione: $time';
  }

  @override
  String get settings_data_sync_notConfigured => 'Non configurato';

  @override
  String get settings_data_sync_syncing => 'Sincronizzazione in corso...';

  @override
  String get settings_decompression_aboutContent =>
      'I fattori di gradiente (GF) controllano quanto conservative sono le tue decompressioni. GF Low influenza le soste profonde, mentre GF High influenza le soste poco profonde.\n\nValori più bassi = più conservativo = soste deco più lunghe\nValori più alti = meno conservativo = soste deco più brevi';

  @override
  String get settings_decompression_aboutTitle =>
      'Informazioni sui fattori di gradiente';

  @override
  String get settings_decompression_currentSettings => 'Impostazioni attuali';

  @override
  String get settings_decompression_dialog_cancel => 'Annulla';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      'Valori più bassi = più conservativo (NDL più lungo/più deco)';

  @override
  String get settings_decompression_dialog_customValues =>
      'Valori personalizzati';

  @override
  String get settings_decompression_dialog_gfHigh => 'GF High';

  @override
  String get settings_decompression_dialog_gfLow => 'GF Low';

  @override
  String get settings_decompression_dialog_info =>
      'GF Low/High controllano quanto conservativi sono i calcoli NDL e deco.';

  @override
  String get settings_decompression_dialog_presets => 'Preset';

  @override
  String get settings_decompression_dialog_save => 'Salva';

  @override
  String get settings_decompression_dialog_title => 'Fattori di gradiente';

  @override
  String settings_decompression_gfValue(Object gfLow, Object gfHigh) {
    return 'GF $gfLow/$gfHigh';
  }

  @override
  String get settings_decompression_header_gradientFactors =>
      'Fattori di gradiente';

  @override
  String get settings_decompression_header_oxygenToxicity =>
      'Tossicità dell\'ossigeno';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Seleziona preset di conservatismo $presetName';
  }

  @override
  String get settings_decompression_header_narcosis => 'Narcosi';

  @override
  String get settings_decompression_o2Narcotic => 'O2 e narcotico';

  @override
  String get settings_decompression_o2Narcotic_subtitle =>
      'Quando attivato, sia O2 che N2 sono considerati narcotici (piu conservativo). Quando disattivato, solo N2 contribuisce alla narcosi.';

  @override
  String get settings_decompression_endLimit => 'Limite END';

  @override
  String get settings_decompression_endLimit_subtitle =>
      'Profondita narcotica equivalente massima utilizzata per i calcoli MND';

  @override
  String get settings_decompression_endLimit_dialog_title => 'Limite END';

  @override
  String get settings_decompression_cnsMethodTitle => 'Calcolo del CNS';

  @override
  String get settings_decompression_cnsMethodClassic =>
      'Tabella NOAA, a gradini (classico)';

  @override
  String get settings_decompression_cnsMethodClassicDesc =>
      'Calcola ogni banda di 0,1 bar al suo estremo più severo. Metodo originale di Submersion.';

  @override
  String get settings_decompression_cnsMethodShearwater =>
      'Interpolazione lineare (stile Shearwater)';

  @override
  String get settings_decompression_cnsMethodShearwaterDesc =>
      'Interpola tra i limiti NOAA come documentato da Shearwater. Corrisponde alla maggior parte dei computer subacquei.';

  @override
  String get settings_decompression_cnsMethodSubsurface =>
      'Adattamento esponenziale (come Subsurface)';

  @override
  String get settings_decompression_cnsMethodSubsurfaceDesc =>
      'Adattamento a curva liscia sulla tabella NOAA. Corrisponde al CNS calcolato da Subsurface.';

  @override
  String get settings_decompression_cnsMethodAboutTitle =>
      'Informazioni su questi metodi';

  @override
  String get settings_decompression_cnsMethodAboutBody =>
      'Tutti e tre i metodi si basano sui limiti di esposizione all\'ossigeno del NOAA Diving Manual (300 minuti a un ppO2 di 1,0 bar, 45 minuti a 1,6 bar). La tabella definisce i limiti solo a passi di 0,1 bar: il metodo classico calcola tutto ciò che rientra in una banda al suo estremo più severo, sovrastimando sistematicamente l\'esposizione tra le voci. I computer subacquei Shearwater documentano un\'interpolazione lineare tra i limiti NOAA, con un valore fisso del 15 % al minuto oltre 1,65 bar. Nel 2019 Subsurface ha sostituito la ricerca in tabella con un adattamento esponenziale liscio a due segmenti sugli stessi dati NOAA (Robert C. Helling), che si estende in modo naturale anche oltre 1,6 bar. Tra le voci della tabella i due metodi lisci concordano entro circa un punto CNS; il metodo classico mostra valori più alti.';

  @override
  String get settings_decompression_cnsMethodDisclaimer =>
      'I nomi si riferiscono ai metodi pubblicati dei rispettivi progetti e produttori; non è implicata alcuna affiliazione o approvazione. I valori calcolati possono differire dalle letture effettive del computer subacqueo.';

  @override
  String get settings_decompression_cnsMethodSourcesTitle => 'Fonti';

  @override
  String get settings_linkOpenFailed => 'Impossibile aprire il link.';

  @override
  String get settings_decompression_cnsMethodSourceNoaa =>
      'NOAA: Diving Program (editore del NOAA Diving Manual)';

  @override
  String get settings_decompression_cnsMethodSourceShearwater =>
      'Shearwater: l\'orologio dell\'ossigeno CNS';

  @override
  String get settings_decompression_cnsMethodSourceTheoreticalDiver =>
      'The Theoretical Diver: calcolo della tossicità CNS dell\'ossigeno';

  @override
  String get settings_decompression_cnsMethodSourceSubsurface =>
      'Subsurface: implementazione (divelist.cpp)';

  @override
  String get settings_existingDb_cancel => 'Annulla';

  @override
  String get settings_existingDb_continue => 'Continua';

  @override
  String get settings_existingDb_current => 'Attuale';

  @override
  String get settings_existingDb_dialog_message =>
      'Un database Submersion esiste già in questa cartella.';

  @override
  String get settings_existingDb_dialog_title => 'Database esistente trovato';

  @override
  String get settings_existingDb_existing => 'Esistente';

  @override
  String get settings_existingDb_replaceWarning =>
      'Il database esistente verrà salvato come backup prima di essere sostituito.';

  @override
  String get settings_existingDb_replaceWithMyData =>
      'Sostituisci con i miei dati';

  @override
  String get settings_existingDb_replaceWithMyData_subtitle =>
      'Sovrascrivi con il tuo database attuale';

  @override
  String get settings_existingDb_stat_buddies => 'Compagni';

  @override
  String get settings_existingDb_stat_dives => 'Immersioni';

  @override
  String get settings_existingDb_stat_sites => 'Siti';

  @override
  String get settings_existingDb_stat_trips => 'Viaggi';

  @override
  String get settings_existingDb_stat_users => 'Utenti';

  @override
  String get settings_existingDb_unknown => 'Sconosciuto';

  @override
  String get settings_existingDb_useExisting => 'Usa database esistente';

  @override
  String get settings_existingDb_useExisting_subtitle =>
      'Passa al database in questa cartella';

  @override
  String get settings_gfPreset_custom_description => 'Imposta i tuoi valori';

  @override
  String get settings_gfPreset_custom_name => 'Personalizzato';

  @override
  String get settings_gfPreset_high_description =>
      'Più conservativo, soste deco più lunghe';

  @override
  String get settings_gfPreset_high_name => 'Alto';

  @override
  String get settings_gfPreset_low_description =>
      'Meno conservativo, deco più breve';

  @override
  String get settings_gfPreset_low_name => 'Basso';

  @override
  String get settings_gfPreset_medium_description => 'Approccio bilanciato';

  @override
  String get settings_gfPreset_medium_name => 'Medio';

  @override
  String get settings_import_cancelButton => 'Annulla importazione';

  @override
  String get settings_import_cancelling => 'Annullamento...';

  @override
  String get settings_import_dialog_title => 'Importazione dati';

  @override
  String get settings_import_doNotClose => 'Non chiudere l\'app';

  @override
  String settings_import_itemCount(Object current, Object total) {
    return '$current di $total';
  }

  @override
  String get settings_import_phase_buddies => 'Importazione compagni...';

  @override
  String get settings_import_phase_certifications =>
      'Importazione certificazioni...';

  @override
  String get settings_import_phase_complete => 'Finalizzazione...';

  @override
  String get settings_import_phase_diveCenters =>
      'Importazione centri immersione...';

  @override
  String get settings_import_phase_diveTypes =>
      'Importazione tipi di immersione...';

  @override
  String get settings_import_phase_dives => 'Importazione immersioni...';

  @override
  String get settings_import_phase_equipment => 'Importazione attrezzatura...';

  @override
  String get settings_import_phase_equipmentSets =>
      'Importazione set attrezzatura...';

  @override
  String get settings_import_phase_parsing => 'Analisi file...';

  @override
  String get settings_import_phase_preparing => 'Preparazione...';

  @override
  String get settings_import_phase_sites =>
      'Importazione siti di immersione...';

  @override
  String get settings_import_phase_tags => 'Importazione tag...';

  @override
  String get settings_import_phase_trips => 'Importazione viaggi...';

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
    return '$phase, $current di $total';
  }

  @override
  String settings_import_progressPercent(Object percent) {
    return 'Progresso importazione: $percent percento';
  }

  @override
  String get settings_language_appBar_title => 'Lingua';

  @override
  String get settings_language_selected => 'Selezionata';

  @override
  String get settings_language_systemDefault => 'Predefinito di sistema';

  @override
  String get settings_lightroom_albumFilter_all => 'Intero catalogo';

  @override
  String get settings_lightroom_albumFilter_title => 'Album da scansionare';

  @override
  String get settings_lightroom_autoPoll_title =>
      'Cerca automaticamente nuove foto';

  @override
  String settings_lightroom_clientId_help(String redirectUri) {
    return 'Crea un\'integrazione nella Adobe Developer Console con l\'API Lightroom Services e un tipo di credenziale che supporti PKCE. Inserisci qui sotto l\'URI di reindirizzamento della tua credenziale — le credenziali Native App usano uno schema personalizzato — oppure lascialo vuoto per usare $redirectUri.';
  }

  @override
  String get settings_lightroom_clientId_label => 'ID client Adobe';

  @override
  String get settings_lightroom_clientSecret_label =>
      'Segreto client (facoltativo)';

  @override
  String get settings_lightroom_redirectUri_label =>
      'URI di reindirizzamento (facoltativo)';

  @override
  String get settings_lightroom_connect => 'Collega Lightroom';

  @override
  String get settings_lightroom_connectEmbedded => 'Connetti con Adobe';

  @override
  String get settings_lightroom_advancedByo => 'Usa le tue credenziali Adobe';

  @override
  String get settings_lightroom_connect_codeLabel =>
      'URL reindirizzato o codice';

  @override
  String get settings_lightroom_connect_emptyCode =>
      'Incolla l\'URL reindirizzato o il codice di autorizzazione';

  @override
  String settings_lightroom_connect_failed(String error) {
    return 'Impossibile connettersi a Lightroom: $error';
  }

  @override
  String get settings_lightroom_connect_instructions =>
      'Accedi ad Adobe nella finestra del browser, poi incolla l\'indirizzo completo della pagina su cui arrivi (contiene il codice di autorizzazione).';

  @override
  String get settings_lightroom_connect_reopenBrowser => 'Riapri il browser';

  @override
  String get settings_lightroom_connect_submit => 'Collega';

  @override
  String get settings_lightroom_connect_title => 'Collega Lightroom';

  @override
  String settings_lightroom_connected(String name) {
    return 'Collegato come $name';
  }

  @override
  String get settings_lightroom_disconnect => 'Disconnetti';

  @override
  String get settings_lightroom_disconnect_confirmBody =>
      'Le foto collegate restano nelle tue immersioni e continuano a essere mostrate dall\'archivio multimediale. Le nuove foto non verranno più abbinate.';

  @override
  String get settings_lightroom_disconnect_confirmTitle =>
      'Disconnettere Lightroom?';

  @override
  String settings_lightroom_lastPoll(String when) {
    return 'Ultimo controllo: $when';
  }

  @override
  String get settings_lightroom_needsReauth => 'Riconnessione necessaria';

  @override
  String get settings_lightroom_scanNow => 'Scansiona Lightroom';

  @override
  String get settings_lightroom_scan_running => 'Scansione di Lightroom...';

  @override
  String settings_lightroom_scan_summary(
    int attached,
    int suggested,
    int skipped,
  ) {
    return '$attached collegate, $suggested suggerite, $skipped già collegate';
  }

  @override
  String get settings_lightroom_subtitle =>
      'Collega automaticamente foto e video alle immersioni';

  @override
  String get settings_lightroom_title => 'Adobe Lightroom';

  @override
  String get settings_manage_checklistTemplates =>
      'Modelli di liste di controllo';

  @override
  String get settings_manage_checklistTemplates_subtitle =>
      'Liste di controllo riutilizzabili per pianificare i viaggi';

  @override
  String get settings_manage_diveRoles => 'Ruoli di immersione';

  @override
  String get settings_manage_diveRoles_subtitle =>
      'Gestisci ruoli di immersione personalizzati';

  @override
  String get settings_manage_diveTypes => 'Tipi di immersione';

  @override
  String get settings_manage_diveTypes_subtitle =>
      'Gestisci tipi di immersione personalizzati';

  @override
  String get settings_manage_header_manageData => 'Gestisci dati';

  @override
  String get settings_manage_species => 'Specie';

  @override
  String get settings_manage_species_subtitle =>
      'Gestisci catalogo specie marine';

  @override
  String get settings_manage_tags => 'Tag';

  @override
  String get settings_manage_tags_subtitle => 'Gestisci, unisci ed elimina tag';

  @override
  String get settings_manage_tankPresets => 'Preset bombole';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Gestisci configurazioni bombole personalizzate';

  @override
  String get settings_manage_serviceTypes => 'Tipi di manutenzione';

  @override
  String get settings_manage_serviceTypes_subtitle =>
      'La manutenzione che serve alla tua attrezzatura, e ogni quanto';

  @override
  String get settings_migrationProgress_doNotClose => 'Non chiudere l\'app';

  @override
  String get settings_migration_backupInfo =>
      'Verrà creato un backup prima dello spostamento. I tuoi dati non andranno persi.';

  @override
  String get settings_migration_cancel => 'Annulla';

  @override
  String get settings_migration_cloudSyncWarning =>
      'La sincronizzazione cloud gestita dall\'app sarà disabilitata. Il servizio di sincronizzazione della tua cartella gestirà la sincronizzazione.';

  @override
  String get settings_migration_dialog_message =>
      'Il tuo database verrà spostato:';

  @override
  String get settings_migration_dialog_title => 'Spostare il database?';

  @override
  String get settings_migration_from => 'Da';

  @override
  String get settings_migration_moveDatabase => 'Sposta database';

  @override
  String get settings_migration_to => 'A';

  @override
  String settings_notifications_days(Object count) {
    return '$count giorni';
  }

  @override
  String get settings_notifications_disabled_continueButton => 'Continua';

  @override
  String get settings_notifications_disabled_openSettingsButton =>
      'Apri Impostazioni';

  @override
  String get settings_notifications_disabled_subtitleUnrequested =>
      'I promemoria di manutenzione richiedono l\'autorizzazione a inviare notifiche';

  @override
  String get settings_notifications_disabled_subtitle =>
      'Abilita nelle impostazioni di sistema per ricevere promemoria';

  @override
  String get settings_notifications_disabled_title => 'Notifiche disabilitate';

  @override
  String get settings_notifications_enableServiceReminders =>
      'Abilita promemoria manutenzione';

  @override
  String get settings_notifications_enableServiceReminders_subtitle =>
      'Ricevi notifiche quando la manutenzione dell\'attrezzatura è in scadenza';

  @override
  String get settings_notifications_header_reminderSchedule =>
      'Programmazione promemoria';

  @override
  String get settings_notifications_header_serviceReminders =>
      'Promemoria manutenzione';

  @override
  String get settings_notifications_howItWorks_content =>
      'Le notifiche vengono pianificate all\'avvio dell\'app e si aggiornano periodicamente in background. Puoi personalizzare i promemoria per i singoli elementi dell\'attrezzatura nella schermata di modifica.';

  @override
  String get settings_notifications_howItWorks_title => 'Come funziona';

  @override
  String get settings_notifications_permissionRequired =>
      'Abilita le notifiche nelle impostazioni di sistema';

  @override
  String get settings_notifications_remindBeforeDue =>
      'Ricordami prima della scadenza della manutenzione:';

  @override
  String get settings_notifications_reminderTime => 'Orario promemoria';

  @override
  String get settings_profile_activeDiver_subtitle =>
      'Subacqueo attivo - tocca per cambiare';

  @override
  String get settings_profile_addNewDiver => 'Aggiungi nuovo subacqueo';

  @override
  String get settings_profile_error_loadingDiver =>
      'Errore nel caricamento del subacqueo';

  @override
  String get settings_profile_header_activeDiver => 'Subacqueo attivo';

  @override
  String get settings_profile_header_manageDivers => 'Gestisci subacquei';

  @override
  String get settings_profile_noDiverProfile => 'Nessun profilo subacqueo';

  @override
  String get settings_profile_noDiverProfile_subtitle =>
      'Tocca per creare il tuo profilo';

  @override
  String get settings_profile_switchDiver_title => 'Cambia subacqueo';

  @override
  String settings_profile_switchedTo(Object diverName) {
    return 'Passato a $diverName';
  }

  @override
  String get settings_profile_viewAllDivers => 'Visualizza tutti i subacquei';

  @override
  String get settings_profile_viewAllDivers_subtitle =>
      'Aggiungi o modifica profili subacquei';

  @override
  String get settings_profileHub_addNewDiver => 'Aggiungi nuovo subacqueo';

  @override
  String get settings_profileHub_cannotDeleteOnly =>
      'Impossibile eliminare l\'unico profilo subacqueo';

  @override
  String get settings_profileHub_createDiverTitle => 'Crea subacqueo';

  @override
  String settings_profileHub_deleteConfirmContent(String name) {
    return 'Sei sicuro di voler eliminare $name? Tutti i registri di immersione associati verranno disassegnati.';
  }

  @override
  String get settings_profileHub_deleteConfirmTitle =>
      'Eliminare il subacqueo?';

  @override
  String get settings_profileHub_deleteDiver => 'Elimina subacqueo';

  @override
  String get settings_profileHub_deleted => 'Subacqueo eliminato';

  @override
  String get settings_profileHub_emergencyContacts => 'Contatti di emergenza';

  @override
  String settings_profileHub_emergencyContacts_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contatti impostati',
      one: '1 contatto impostato',
      zero: 'Non impostato',
    );
    return '$_temp0';
  }

  @override
  String get settings_profileHub_insurance => 'Assicurazione';

  @override
  String get settings_profileHub_insurance_expired => 'Scaduta';

  @override
  String get settings_profileHub_insurance_notSet => 'Non impostato';

  @override
  String get settings_profileHub_medicalInfo => 'Informazioni mediche';

  @override
  String get settings_profileHub_medicalInfo_notSet => 'Non impostato';

  @override
  String get settings_profileHub_notes => 'Note';

  @override
  String get settings_profileHub_notes_notSet => 'Non impostato';

  @override
  String get settings_profileHub_personalInfo => 'Informazioni personali';

  @override
  String get settings_profileHub_personalInfo_notSet => 'Non impostato';

  @override
  String get settings_profileHub_saved => 'Modifiche salvate';

  @override
  String get settings_profileHub_switchDiver => 'Cambia subacqueo';

  @override
  String get settings_s3Config_action_remove => 'Rimuovi configurazione';

  @override
  String get settings_s3Config_action_testConnection => 'Prova connessione';

  @override
  String get settings_s3Config_advanced_title => 'Avanzate';

  @override
  String get settings_s3Config_appBar_title => 'Archiviazione compatibile S3';

  @override
  String get settings_s3Config_error_secureStorage =>
      'Impossibile accedere all\'archivio sicuro';

  @override
  String get settings_s3Config_field_accessKeyId_label => 'Access Key ID';

  @override
  String get settings_s3Config_field_bucket_label => 'Bucket';

  @override
  String get settings_s3Config_field_endpoint_helper =>
      'Ad esempio: https://s3.example.com';

  @override
  String get settings_s3Config_field_endpoint_label => 'URL endpoint';

  @override
  String get settings_s3Config_field_pathStyle_label =>
      'Usa indirizzamento path-style';

  @override
  String get settings_s3Config_field_pathStyle_subtitle =>
      'Richiesto dalla maggior parte dei server self-hosted';

  @override
  String get settings_s3Config_field_prefix_label => 'Prefisso delle chiavi';

  @override
  String settings_s3Config_field_region_helperAuto(String region) {
    return 'Rilevato automaticamente: $region';
  }

  @override
  String get settings_s3Config_field_region_label => 'Regione';

  @override
  String get settings_s3Config_field_secretAccessKey_label =>
      'Secret Access Key';

  @override
  String get settings_s3Config_remove_confirm_action => 'Rimuovi';

  @override
  String get settings_s3Config_remove_confirm_body =>
      'La sincronizzazione tramite S3 si interromperà su questo dispositivo. I dati nel bucket non vengono eliminati.';

  @override
  String get settings_s3Config_remove_confirm_title =>
      'Rimuovere la configurazione S3?';

  @override
  String get settings_s3Config_removed => 'Configurazione S3 rimossa';

  @override
  String get settings_s3Config_saved => 'Configurazione S3 salvata';

  @override
  String settings_s3Config_test_regionDetected(String region) {
    return 'Regione rilevata: $region';
  }

  @override
  String get settings_s3Config_test_success => 'Connessione riuscita';

  @override
  String get settings_s3Config_validation_endpointInvalid =>
      'Inserisci un URL http:// o https:// valido';

  @override
  String get settings_s3Config_validation_endpointPath =>
      'L\'URL dell\'endpoint non deve includere un percorso';

  @override
  String get settings_s3Config_validation_required => 'Obbligatorio';

  @override
  String get settings_s3Config_warning_http =>
      'Questo endpoint usa HTTP non cifrato. Credenziali e dati delle immersioni viaggeranno in chiaro; usalo solo su una rete affidabile.';

  @override
  String get settings_section_about_subtitle => 'Informazioni app e licenze';

  @override
  String get settings_section_about_title => 'Informazioni';

  @override
  String get settings_section_appearance_subtitle => 'Tema e visualizzazione';

  @override
  String get settings_section_appearance_title => 'Aspetto';

  @override
  String get settings_section_data_subtitle =>
      'Backup, ripristino e archiviazione';

  @override
  String get settings_section_data_title => 'Dati';

  @override
  String get settings_section_decompression_subtitle => 'Fattori di gradiente';

  @override
  String get settings_section_decompression_title => 'Decompressione';

  @override
  String get settings_section_diverProfile_subtitle =>
      'Subacqueo attivo e profili';

  @override
  String get settings_section_diverProfile_title => 'Profilo subacqueo';

  @override
  String get settings_section_manage_subtitle =>
      'Tipi di immersione e preset bombole';

  @override
  String get settings_section_manage_title => 'Gestisci';

  @override
  String get settings_section_notifications_subtitle =>
      'Promemoria manutenzione';

  @override
  String get settings_section_notifications_title => 'Notifiche';

  @override
  String get settings_section_units_subtitle => 'Preferenze di misurazione';

  @override
  String get settings_section_units_title => 'Unità';

  @override
  String get settings_storage_appBar_title => 'Archiviazione database';

  @override
  String get settings_storage_appDefault => 'Predefinito app';

  @override
  String get settings_storage_appDefaultLocation =>
      'Posizione predefinita dell\'app';

  @override
  String get settings_storage_appDefault_subtitle =>
      'Posizione di archiviazione standard dell\'app';

  @override
  String get settings_storage_currentLocation => 'Posizione attuale';

  @override
  String get settings_storage_currentLocation_label => 'Posizione attuale';

  @override
  String get settings_storage_customFolder => 'Cartella personalizzata';

  @override
  String get settings_storage_customFolder_change => 'Cambia';

  @override
  String get settings_storage_customFolder_subtitle =>
      'Scegli una cartella sincronizzata (Dropbox, Google Drive, ecc.)';

  @override
  String get settings_storage_customFolder_subtitleDeviceOnly =>
      'Sposta il database nella memoria interna o sulla scheda SD';

  @override
  String get settings_storage_customFolder_deviceOnly_noCloudSync =>
      'La sincronizzazione cloud gestita dall\'app è disattivata finché il database si trova su un volume di archiviazione del dispositivo. Su Android nessun servizio di sincronizzazione può raggiungere quella cartella: usa Backup e Ripristino per conservare copie altrove.';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize • $diveCount immersioni • $siteCount siti';
  }

  @override
  String get settings_storage_dismissError_tooltip => 'Ignora errore';

  @override
  String get settings_storage_dismissSuccess_tooltip =>
      'Ignora messaggio di successo';

  @override
  String get settings_storage_header_storageLocation =>
      'Posizione archiviazione';

  @override
  String get settings_storage_info_customActive =>
      'La sincronizzazione cloud gestita dall\'app è disabilitata. Il servizio di sincronizzazione della tua cartella (Dropbox, Google Drive, ecc.) gestisce la sincronizzazione.';

  @override
  String get settings_storage_info_customAvailable =>
      'L\'uso di una cartella personalizzata disabilita la sincronizzazione cloud gestita dall\'app. Il servizio di sincronizzazione della tua cartella gestirà la sincronizzazione.';

  @override
  String get settings_storage_loading => 'Caricamento...';

  @override
  String get settings_storage_migrating_doNotClose => 'Non chiudere l\'app';

  @override
  String get settings_storage_migrating_movingDatabase =>
      'Spostamento database...';

  @override
  String get settings_storage_migrating_movingToAppDefault =>
      'Spostamento nella posizione predefinita...';

  @override
  String get settings_storage_migrating_replacingExisting =>
      'Sostituzione database esistente...';

  @override
  String get settings_storage_migrating_switchingToExisting =>
      'Passaggio al database esistente...';

  @override
  String get settings_storage_notSet => 'Non impostato';

  @override
  String settings_storage_success_backupAt(Object path) {
    return 'Originale conservato come backup in:\n$path';
  }

  @override
  String get settings_storage_success_moved => 'Database spostato con successo';

  @override
  String get settings_storage_dangerZone => 'Zona pericolosa';

  @override
  String get settings_storage_resetDatabase => 'Reimposta database';

  @override
  String get settings_storage_resetDatabase_subtitle =>
      'Elimina tutti i dati su questo dispositivo e ricomincia da zero';

  @override
  String get settings_storage_resetDialog_title => 'Reimpostare il database?';

  @override
  String get settings_storage_resetDialog_body =>
      'Questo elimina permanentemente tutti i dati su QUESTO dispositivo, incluse immersioni, siti, attrezzatura e impostazioni. Un backup viene creato automaticamente prima del reset.\n\nLa tua libreria cloud non viene eliminata e gli altri dispositivi conservano i loro dati. La sincronizzazione cloud verrà disconnessa affinché il reset non venga annullato; puoi riconnetterla in Impostazioni > Sincronizzazione cloud.';

  @override
  String get settings_storage_resetDialog_confirmWord => 'Elimina';

  @override
  String get settings_storage_resetDialog_confirmHint =>
      'Digita \"Elimina\" per confermare';

  @override
  String get settings_storage_resetDialog_confirmButton => 'Reimposta';

  @override
  String get settings_storage_resetDialog_backupFailed =>
      'Backup non riuscito. Il reset e stato annullato per proteggere i tuoi dati.';

  @override
  String settings_storage_resetDialog_resetFailed(Object error) {
    return 'Reset non riuscito: $error';
  }

  @override
  String get settings_storage_resetComplete_title => 'Reset del database';

  @override
  String get settings_storage_resetComplete_description =>
      'I dati di questo dispositivo sono stati cancellati ed è stato salvato un backup. La sincronizzazione cloud ora è disconnessa affinché il ripristino non venga annullato; puoi riconnetterla in Impostazioni > Sincronizzazione cloud. Tocca continua per ricaricare l\'app.';

  @override
  String get settings_summary_activeDiver => 'Subacqueo attivo';

  @override
  String get settings_summary_currentConfiguration => 'Configurazione attuale';

  @override
  String get settings_summary_depth => 'Profondità';

  @override
  String get settings_summary_error => 'Errore';

  @override
  String get settings_summary_gradientFactors => 'Fattori di gradiente';

  @override
  String get settings_summary_loading => 'Caricamento...';

  @override
  String get settings_summary_notSet => 'Non impostato';

  @override
  String get settings_summary_pressure => 'Pressione';

  @override
  String get settings_summary_subtitle =>
      'Seleziona una categoria da configurare';

  @override
  String get settings_summary_temperature => 'Temperatura';

  @override
  String get settings_summary_theme => 'Tema';

  @override
  String get settings_summary_theme_dark => 'Scuro';

  @override
  String get settings_summary_theme_light => 'Chiaro';

  @override
  String get settings_summary_theme_system => 'Sistema';

  @override
  String get settings_summary_tip =>
      'Suggerimento: usa la sezione Dati per eseguire regolarmente il backup dei tuoi registri immersione.';

  @override
  String get settings_summary_title => 'Impostazioni';

  @override
  String get settings_summary_unitPreferences => 'Preferenze unità';

  @override
  String get settings_summary_units => 'Unità';

  @override
  String get settings_summary_volume => 'Volume';

  @override
  String get settings_summary_weight => 'Peso';

  @override
  String get settings_units_custom => 'Personalizzato';

  @override
  String get settings_units_dateFormat => 'Formato data';

  @override
  String get settings_units_depth => 'Profondità';

  @override
  String get settings_units_depth_feet => 'Piedi (ft)';

  @override
  String get settings_units_depth_meters => 'Metri (m)';

  @override
  String get settings_units_dialog_dateFormat => 'Formato data';

  @override
  String get settings_units_dialog_depthUnit => 'Unità di profondità';

  @override
  String get settings_units_dialog_pressureUnit => 'Unità di pressione';

  @override
  String get settings_units_dialog_sacRateUnit => 'Unità SAC Rate';

  @override
  String get settings_units_gasModel => 'Calcoli del gas';

  @override
  String get settings_units_gasModel_real => 'Gas reale';

  @override
  String get settings_units_gasModel_real_subtitle =>
      'Tiene conto della comprimibilità. Una bombola da 12 L a 200 bar contiene circa 2317 L.';

  @override
  String get settings_units_gasModel_ideal => 'Gas ideale';

  @override
  String get settings_units_gasModel_ideal_subtitle =>
      'Corrisponde al calcolo manuale e alle tabelle. Una bombola da 12 L a 200 bar contiene 2400 L.';

  @override
  String get settings_units_gasModel_explanation =>
      'Come la pressione della bombola viene convertita in volume di gas. Riguarda l\'RMV, le statistiche del gas, il pianificatore e i calcolatori. Il gas ideale corrisponde al calcolo insegnato dalle didattiche; il gas reale è fisicamente accurato e restituisce un RMV inferiore di circa il 5%.';

  @override
  String get settings_units_dialog_gasModel => 'Calcoli del gas';

  @override
  String get settings_units_dialog_temperatureUnit => 'Unità di temperatura';

  @override
  String get settings_units_dialog_timeFormat => 'Formato ora';

  @override
  String get settings_units_dialog_volumeUnit => 'Unità di volume';

  @override
  String get settings_units_dialog_weightUnit => 'Unità di peso';

  @override
  String get settings_units_header_individualUnits => 'Unità individuali';

  @override
  String get settings_units_header_timeDateFormat => 'Formato ora e data';

  @override
  String get settings_units_header_unitSystem => 'Sistema di unità';

  @override
  String get settings_units_imperial => 'Imperiale';

  @override
  String get settings_units_metric => 'Metrico';

  @override
  String get settings_units_pressure => 'Pressione';

  @override
  String get settings_units_pressure_bar => 'Bar';

  @override
  String get settings_units_pressure_psi => 'PSI';

  @override
  String get settings_units_quickSelect => 'Selezione rapida';

  @override
  String get settings_units_sacRate => 'SAC Rate';

  @override
  String get settings_units_defaultCurrency => 'Valuta predefinita';

  @override
  String get settings_units_dialog_defaultCurrency => 'Valuta predefinita';

  @override
  String get settings_units_sac_pressurePerMinute => 'Pressione al minuto';

  @override
  String get settings_units_sac_pressurePerMinute_subtitle =>
      'Nessun volume bombola necessario (bar/min o psi/min)';

  @override
  String get settings_units_sac_volumePerMinute => 'Volume al minuto';

  @override
  String get settings_units_sac_volumePerMinute_subtitle =>
      'Richiede volume bombola (L/min o cuft/min)';

  @override
  String get settings_units_temperature => 'Temperatura';

  @override
  String get settings_units_temperature_celsius => 'Celsius (°C)';

  @override
  String get settings_units_temperature_fahrenheit => 'Fahrenheit (°F)';

  @override
  String get settings_units_timeFormat => 'Formato ora';

  @override
  String get settings_units_volume => 'Volume';

  @override
  String get settings_units_volume_cubicFeet => 'Piedi cubi (cuft)';

  @override
  String get settings_units_volume_liters => 'Litri (L)';

  @override
  String get settings_units_weight => 'Peso';

  @override
  String get settings_units_weight_kilograms => 'Chilogrammi (kg)';

  @override
  String get settings_units_weight_pounds => 'Libbre (lbs)';

  @override
  String get settings_updates_automaticUpdates => 'Aggiornamenti automatici';

  @override
  String get settings_updates_automaticUpdatesSubtitle =>
      'Controlla periodicamente gli aggiornamenti';

  @override
  String get settings_updates_betaDialogBody =>
      'Le build beta vengono pubblicate a ogni modifica e possono aggiornare il database del tuo diario immersioni prima della versione stabile. Tornare in seguito al canale stabile non riporterà l\'app a una versione precedente, e tutti i dispositivi che si sincronizzano tra loro dovrebbero usare lo stesso canale. Prima di ogni aggiornamento del database viene eseguito automaticamente un backup.';

  @override
  String get settings_updates_betaDialogConfirm => 'Passa alla Beta';

  @override
  String get settings_updates_betaDialogTitle => 'Ricevere aggiornamenti beta?';

  @override
  String get settings_updates_channel => 'Canale di aggiornamento';

  @override
  String settings_updates_channelBadgeBeta(String version) {
    return '$version (Beta)';
  }

  @override
  String get settings_updates_channelBeta => 'Beta';

  @override
  String get settings_updates_channelBetaSubtitle =>
      'Nuove build a ogni modifica, in anticipo sulla stabile';

  @override
  String get settings_updates_channelStable => 'Stabile';

  @override
  String get settings_updates_channelStableSubtitle => 'Solo versioni testate';

  @override
  String get settings_updates_checkForUpdates => 'Controlla aggiornamenti';

  @override
  String get settings_updates_checking => 'Controllo in corso...';

  @override
  String settings_updates_downloading(String progress) {
    return 'Download in corso... $progress%';
  }

  @override
  String settings_updates_error(String message) {
    return 'Errore: $message';
  }

  @override
  String get settings_updates_header => 'Aggiornamenti';

  @override
  String get settings_updates_joinBeta => 'Partecipa alla Beta';

  @override
  String get settings_updates_joinBetaSubtitle =>
      'Ricevi in anteprima le nuove funzionalità tramite il programma beta';

  @override
  String get settings_updates_lastChecked => 'Ultimo controllo';

  @override
  String get settings_updates_never => 'Mai';

  @override
  String settings_updates_readyToInstall(String version) {
    return 'Versione $version pronta per l\'installazione';
  }

  @override
  String get settings_updates_stableSwitchNotice =>
      'Rimarrai su questa beta finché la prossima versione stabile non sarà più recente di essa.';

  @override
  String get settings_updates_upToDate => 'Aggiornato';

  @override
  String settings_updates_versionAvailable(String version) {
    return 'Versione $version disponibile';
  }

  @override
  String get signatures_action_clear => 'Cancella';

  @override
  String get signatures_action_closeSignatureView => 'Chiudi vista firma';

  @override
  String get signatures_action_deleteSignature => 'Elimina firma';

  @override
  String get signatures_action_done => 'Fatto';

  @override
  String get signatures_action_readyToSign => 'Pronto per Firmare';

  @override
  String get signatures_action_request => 'Richiedi';

  @override
  String get signatures_action_saveSignature => 'Salva Firma';

  @override
  String signatures_buddyCard_notSignedSemantics(Object name) {
    return 'Firma di $name, non firmato';
  }

  @override
  String signatures_buddyCard_signedSemantics(Object name) {
    return 'Firma di $name, firmato';
  }

  @override
  String get signatures_captureInstructorSignature =>
      'Acquisisci Firma Istruttore';

  @override
  String signatures_deleteDialog_message(Object name) {
    return 'Sei sicuro di voler eliminare la firma di $name? Questa azione non può essere annullata.';
  }

  @override
  String get signatures_deleteDialog_title => 'Eliminare Firma?';

  @override
  String get signatures_drawSignatureHint => 'Disegna la tua firma sopra';

  @override
  String get signatures_drawSignatureHintDetailed =>
      'Disegna la firma sopra usando il dito o lo stilo';

  @override
  String get signatures_drawSignatureSemantics => 'Disegna firma';

  @override
  String get signatures_error_drawSignature => 'Disegna una firma';

  @override
  String get signatures_error_enterSignerName =>
      'Inserisci il nome del firmatario';

  @override
  String get signatures_field_instructorName => 'Nome Istruttore';

  @override
  String get signatures_field_instructorNameHint => 'Inserisci nome istruttore';

  @override
  String get signatures_handoff_title => 'Passa il dispositivo a';

  @override
  String get signatures_instructorSignature => 'Firma Istruttore';

  @override
  String get signatures_noSignatureImage => 'Nessuna immagine firma';

  @override
  String signatures_signHere(Object name) {
    return '$name - Firma Qui';
  }

  @override
  String get signatures_signed => 'Firmato';

  @override
  String signatures_signedCountSemantics(Object signed, Object total) {
    return '$signed di $total compagni hanno firmato';
  }

  @override
  String signatures_signedDate(Object date) {
    return 'Firmato il $date';
  }

  @override
  String get signatures_title => 'Firme';

  @override
  String get signatures_viewSignature => 'Visualizza firma';

  @override
  String signatures_viewSignatureSemantics(Object name) {
    return 'Visualizza firma di $name';
  }

  @override
  String get statistics_appBar_title => 'Statistiche';

  @override
  String statistics_categoryCard_semanticLabel(Object title) {
    return 'Categoria statistiche $title';
  }

  @override
  String get statistics_category_conditions_subtitle =>
      'Visibilita e temperatura';

  @override
  String get statistics_category_conditions_title => 'Condizioni';

  @override
  String get statistics_category_equipment_subtitle =>
      'Utilizzo attrezzatura e zavorra';

  @override
  String get statistics_category_equipment_title => 'Attrezzatura';

  @override
  String get statistics_category_gas_subtitle => 'Consumi SAC e miscele gas';

  @override
  String get statistics_category_gas_title => 'Consumo aria';

  @override
  String get statistics_category_geographic_subtitle => 'Paesi e regioni';

  @override
  String get statistics_category_geographic_title => 'Geografiche';

  @override
  String get statistics_category_marineLife_subtitle =>
      'Avvistamenti di specie';

  @override
  String get statistics_category_marineLife_title => 'Vita marina';

  @override
  String get statistics_category_overview_title => 'Overview';

  @override
  String get statistics_category_overview_subtitle =>
      'Totals, records, and breakdowns at a glance';

  @override
  String get statistics_category_profile_subtitle =>
      'Velocita di risalita e deco';

  @override
  String get statistics_category_profile_title => 'Analisi profilo';

  @override
  String get statistics_category_progression_subtitle =>
      'Tendenze profondita e tempo';

  @override
  String get statistics_category_progression_title => 'Progressione';

  @override
  String get statistics_category_social_subtitle =>
      'Compagni e centri immersioni';

  @override
  String get statistics_category_social_title => 'Sociale';

  @override
  String get statistics_category_timePatterns_subtitle => 'Quando ti immergi';

  @override
  String get statistics_category_timePatterns_title =>
      'Distribuzioni temporali';

  @override
  String statistics_chart_barSemanticLabel(Object count) {
    return 'Grafico a barre con $count categorie';
  }

  @override
  String statistics_chart_distributionSemanticLabel(Object count) {
    return 'Grafico a torta con $count segmenti';
  }

  @override
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames) {
    return 'Grafico a linee multiple che confronta $seriesNames';
  }

  @override
  String get statistics_chart_noBarData => 'Nessun dato disponibile';

  @override
  String get statistics_chart_noDistributionData =>
      'Nessun dato di distribuzione disponibile';

  @override
  String get statistics_chart_noTrendData =>
      'Nessun dato di tendenza disponibile';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return 'Grafico di tendenza con $count punti dati';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return 'Grafico di tendenza con $count punti dati per $yAxisLabel';
  }

  @override
  String get statistics_conditions_appBar_title => 'Condizioni';

  @override
  String get statistics_conditions_entryMethod_empty =>
      'Nessun dato sul metodo di ingresso disponibile';

  @override
  String get statistics_conditions_entryMethod_error =>
      'Impossibile caricare i dati sul metodo di ingresso';

  @override
  String get statistics_conditions_entryMethod_subtitle => 'Riva, barca, ecc.';

  @override
  String get statistics_conditions_entryMethod_title => 'Metodo di ingresso';

  @override
  String get statistics_conditions_temperature_empty =>
      'Nessun dato sulla temperatura disponibile';

  @override
  String get statistics_conditions_temperature_error =>
      'Impossibile caricare i dati sulla temperatura';

  @override
  String get statistics_conditions_temperature_seriesAvg => 'Media';

  @override
  String get statistics_conditions_temperature_seriesMax => 'Max';

  @override
  String get statistics_conditions_temperature_seriesMin => 'Min';

  @override
  String get statistics_conditions_temperature_subtitle =>
      'Temperature min/media/max';

  @override
  String get statistics_conditions_temperature_title =>
      'Temperatura dell\'acqua per mese';

  @override
  String get statistics_conditions_visibility_error =>
      'Impossibile caricare i dati sulla visibilita';

  @override
  String get statistics_conditions_visibility_subtitle =>
      'Immersioni per condizione di visibilita';

  @override
  String get statistics_conditions_visibility_title =>
      'Distribuzione visibilita';

  @override
  String get statistics_conditions_waterType_error =>
      'Impossibile caricare i dati sul tipo di acqua';

  @override
  String get statistics_conditions_waterType_subtitle =>
      'Immersioni in acqua salata vs dolce';

  @override
  String get statistics_conditions_waterType_title => 'Tipo di acqua';

  @override
  String get statistics_equipment_appBar_title => 'Attrezzatura';

  @override
  String get statistics_equipment_mostUsedGear_error =>
      'Impossibile caricare i dati sull\'attrezzatura';

  @override
  String get statistics_equipment_mostUsedGear_subtitle =>
      'Attrezzatura per numero di immersioni';

  @override
  String get statistics_equipment_mostUsedGear_title =>
      'Attrezzatura piu usata';

  @override
  String get statistics_equipment_weightTrend_error =>
      'Impossibile caricare la tendenza della zavorra';

  @override
  String get statistics_equipment_weightTrend_subtitle =>
      'Peso medio della zavorra nel tempo';

  @override
  String get statistics_equipment_weightTrend_title => 'Tendenza zavorra';

  @override
  String get statistics_error_loadingStatistics =>
      'Errore nel caricamento delle statistiche';

  @override
  String get statistics_filterBar_clear => 'Cancella filtro';

  @override
  String statistics_filterBar_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni',
      one: '1 immersione',
    );
    return '$_temp0';
  }

  @override
  String get statistics_gas_appBar_title => 'Consumo aria';

  @override
  String get statistics_gas_gasMix_error =>
      'Impossibile caricare i dati sulle miscele gas';

  @override
  String get statistics_gas_gasMix_subtitle => 'Immersioni per tipo di gas';

  @override
  String get statistics_gas_gasMix_title => 'Distribuzione miscele gas';

  @override
  String get statistics_gas_sacByRole_empty =>
      'Nessun dato multi-bombola disponibile';

  @override
  String get statistics_gas_sacByRole_error =>
      'Impossibile caricare SAC per ruolo';

  @override
  String get statistics_gas_sacByRole_subtitle =>
      'Consumo medio per tipo di bombola';

  @override
  String get statistics_gas_sacByRole_title => 'SAC per ruolo bombola';

  @override
  String get statistics_gas_sacRecords_best => 'Miglior SAC';

  @override
  String get statistics_gas_sacRecords_empty => 'Nessun dato SAC disponibile';

  @override
  String get statistics_gas_sacRecords_error =>
      'Impossibile caricare i record SAC';

  @override
  String get statistics_gas_sacRecords_highest => 'SAC piu alto';

  @override
  String get statistics_gas_sacRecords_subtitle =>
      'Miglior e peggior consumo d\'aria';

  @override
  String get statistics_gas_sacRecords_title => 'Record SAC';

  @override
  String get statistics_gas_sacTrend_error =>
      'Impossibile caricare la tendenza SAC';

  @override
  String get statistics_gas_sacTrend_subtitle => 'Media mensile su 5 anni';

  @override
  String get statistics_gas_sacTrend_title => 'Tendenza SAC';

  @override
  String get statistics_gas_tankRole_backGas => 'Gas principale';

  @override
  String get statistics_gas_tankRole_bailout => 'Bailout';

  @override
  String get statistics_gas_tankRole_deco => 'Deco';

  @override
  String get statistics_gas_tankRole_diluent => 'Diluente';

  @override
  String get statistics_gas_tankRole_oxygenSupply => 'Riserva O₂';

  @override
  String get statistics_gas_tankRole_pony => 'Pony';

  @override
  String get statistics_gas_tankRole_sidemountLeft => 'Sidemount S';

  @override
  String get statistics_gas_tankRole_sidemountRight => 'Sidemount D';

  @override
  String get statistics_gas_tankRole_stage => 'Stage';

  @override
  String get statistics_geographic_appBar_title => 'Geografiche';

  @override
  String get statistics_geographic_countries_empty => 'Nessun paese visitato';

  @override
  String get statistics_geographic_countries_error =>
      'Impossibile caricare i dati sui paesi';

  @override
  String get statistics_geographic_countries_subtitle => 'Immersioni per paese';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count paesi. Primo: $topName con $topCount immersioni';
  }

  @override
  String get statistics_geographic_countries_title => 'Paesi visitati';

  @override
  String get statistics_geographic_regions_empty => 'Nessuna regione esplorata';

  @override
  String get statistics_geographic_regions_error =>
      'Impossibile caricare i dati sulle regioni';

  @override
  String get statistics_geographic_regions_subtitle => 'Immersioni per regione';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count regioni. Prima: $topName con $topCount immersioni';
  }

  @override
  String get statistics_geographic_regions_title => 'Regioni esplorate';

  @override
  String get statistics_geographic_trips_empty => 'Nessun dato sui viaggi';

  @override
  String get statistics_geographic_trips_error =>
      'Impossibile caricare i dati sui viaggi';

  @override
  String get statistics_geographic_trips_subtitle => 'Viaggi piu produttivi';

  @override
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count viaggi. Primo: $topName con $topCount immersioni';
  }

  @override
  String get statistics_geographic_trips_title => 'Immersioni per viaggio';

  @override
  String get statistics_listContent_selectedSuffix => ', selezionato';

  @override
  String get statistics_marineLife_appBar_title => 'Vita marina';

  @override
  String get statistics_marineLife_bestSites_empty => 'Nessun dato sui siti';

  @override
  String get statistics_marineLife_bestSites_error =>
      'Impossibile caricare i dati sui siti';

  @override
  String get statistics_marineLife_bestSites_subtitle =>
      'Siti con maggiore varieta di specie';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count siti. Migliore: $topName con $topCount specie';
  }

  @override
  String get statistics_marineLife_bestSites_title =>
      'Migliori siti per vita marina';

  @override
  String get statistics_marineLife_mostCommon_empty =>
      'Nessun dato sugli avvistamenti';

  @override
  String get statistics_marineLife_mostCommon_error =>
      'Impossibile caricare i dati sugli avvistamenti';

  @override
  String get statistics_marineLife_mostCommon_subtitle =>
      'Specie avvistate piu spesso';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count specie. Piu comune: $topName con $topCount avvistamenti';
  }

  @override
  String get statistics_marineLife_mostCommon_title =>
      'Avvistamenti piu comuni';

  @override
  String get statistics_marineLife_speciesSpotted => 'Specie avvistate';

  @override
  String get statistics_profile_appBar_title => 'Analisi profilo';

  @override
  String get statistics_profile_ascentDescent_empty =>
      'Nessun dato sul profilo disponibile';

  @override
  String get statistics_profile_ascentDescent_error =>
      'Impossibile caricare i dati sulle velocita';

  @override
  String get statistics_profile_ascentDescent_subtitle =>
      'Dai dati del profilo immersione';

  @override
  String get statistics_profile_ascentDescent_title =>
      'Velocita medie di risalita e discesa';

  @override
  String get statistics_profile_avgAscent => 'Risalita media';

  @override
  String get statistics_profile_avgDescent => 'Discesa media';

  @override
  String get statistics_profile_deco_decoDives => 'Immersioni deco';

  @override
  String get statistics_profile_deco_decoLabel => 'Deco';

  @override
  String get statistics_profile_deco_decoRate => 'Percentuale deco';

  @override
  String get statistics_profile_deco_empty => 'Nessun dato deco disponibile';

  @override
  String get statistics_profile_deco_error =>
      'Impossibile caricare i dati deco';

  @override
  String get statistics_profile_deco_noDeco => 'No deco';

  @override
  String get statistics_profile_deco_notRecorded => 'Non registrato';

  @override
  String statistics_profile_deco_notRecordedHint(int count) {
    return '$count immersioni non hanno dati di decompressione registrati o calcolabili e sono escluse dal tasso';
  }

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return 'Percentuale decompressione: $percentage% delle immersioni ha richiesto soste deco';
  }

  @override
  String get statistics_profile_deco_subtitle =>
      'Immersioni con obbligo di decompressione';

  @override
  String get statistics_profile_deco_title => 'Obbligo di decompressione';

  @override
  String get statistics_profile_timeAtDepth_empty =>
      'Nessun dato sulla profondita disponibile';

  @override
  String get statistics_profile_timeAtDepth_error =>
      'Impossibile caricare i dati sugli intervalli di profondita';

  @override
  String get statistics_profile_timeAtDepth_subtitle =>
      'Tempo approssimativo trascorso a ogni profondita';

  @override
  String get statistics_profile_timeAtDepth_title =>
      'Tempo per intervalli di profondita';

  @override
  String statistics_profile_timeAtDepth_valueFormat(Object value) {
    return '$value min';
  }

  @override
  String get statistics_progression_appBar_title => 'Progressione immersioni';

  @override
  String get statistics_progression_bottomTime_error =>
      'Impossibile caricare la tendenza del tempo di fondo';

  @override
  String get statistics_progression_bottomTime_subtitle =>
      'Durata media per mese';

  @override
  String get statistics_progression_bottomTime_title =>
      'Tendenza tempo di fondo';

  @override
  String get statistics_progression_cumulative_error =>
      'Impossibile caricare i dati cumulativi';

  @override
  String get statistics_progression_cumulative_subtitle =>
      'Immersioni totali nel tempo';

  @override
  String get statistics_progression_cumulative_title =>
      'Conteggio cumulativo immersioni';

  @override
  String get statistics_progression_depthProgression_error =>
      'Impossibile caricare la progressione di profondita';

  @override
  String get statistics_progression_depthProgression_subtitle =>
      'Profondita massima mensile su 5 anni';

  @override
  String get statistics_progression_depthProgression_title =>
      'Progressione profondita massima';

  @override
  String get statistics_progression_divesPerYear_empty =>
      'Nessun dato annuale disponibile';

  @override
  String get statistics_progression_divesPerYear_error =>
      'Impossibile caricare i dati annuali';

  @override
  String get statistics_progression_divesPerYear_subtitle =>
      'Confronto annuale del numero di immersioni';

  @override
  String get statistics_progression_divesPerYear_title => 'Immersioni per anno';

  @override
  String get statistics_ranking_countLabel_dives => 'immersioni';

  @override
  String get statistics_ranking_countLabel_sightings => 'avvistamenti';

  @override
  String get statistics_ranking_countLabel_species => 'specie';

  @override
  String get statistics_ranking_emptyState => 'Nessun dato disponibile';

  @override
  String statistics_ranking_itemCount(Object count, Object label) {
    return '$count $label';
  }

  @override
  String statistics_ranking_moreItems(Object count) {
    return 'e $count altri';
  }

  @override
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  ) {
    return '$name, posizione $rank, $count $label';
  }

  @override
  String get statistics_records_appBar_title => 'Record immersioni';

  @override
  String get statistics_records_coldestDive => 'Immersione piu fredda';

  @override
  String get statistics_records_deepestDive => 'Immersione piu profonda';

  @override
  String statistics_records_diveNumber(Object number) {
    return 'Immersione #$number';
  }

  @override
  String get statistics_records_emptySubtitle =>
      'Inizia a registrare immersioni per vedere i tuoi record qui';

  @override
  String get statistics_records_emptyTitle => 'Nessun record ancora';

  @override
  String get statistics_records_error => 'Errore nel caricamento dei record';

  @override
  String get statistics_records_firstDive => 'Prima immersione';

  @override
  String get statistics_records_longestDive => 'Immersione piu lunga';

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
  String get statistics_records_milestones => 'Traguardi';

  @override
  String get statistics_records_mostRecentDive => 'Immersione piu recente';

  @override
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  ) {
    return '$title: $value a $siteName';
  }

  @override
  String get statistics_records_retry => 'Riprova';

  @override
  String get statistics_records_shallowestDive => 'Immersione meno profonda';

  @override
  String get statistics_records_unknownSite => 'Sito sconosciuto';

  @override
  String get statistics_records_warmestDive => 'Immersione piu calda';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return 'Sezione $title';
  }

  @override
  String get statistics_social_appBar_title => 'Sociale e compagni';

  @override
  String get statistics_social_soloVsBuddy_empty =>
      'Nessun dato sulle immersioni disponibile';

  @override
  String get statistics_social_soloVsBuddy_error =>
      'Impossibile caricare i dati sui compagni';

  @override
  String get statistics_social_soloVsBuddy_solo => 'Solitaria';

  @override
  String get statistics_social_soloVsBuddy_subtitle =>
      'Immersioni con o senza compagni';

  @override
  String get statistics_social_soloVsBuddy_title =>
      'Immersioni solitarie vs con compagno';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => 'Con compagno';

  @override
  String get statistics_social_topBuddies_error =>
      'Impossibile caricare la classifica dei compagni';

  @override
  String get statistics_social_topBuddies_subtitle =>
      'Compagni di immersione piu frequenti';

  @override
  String get statistics_social_topBuddies_title =>
      'Migliori compagni di immersione';

  @override
  String get statistics_social_topDiveCenters_error =>
      'Impossibile caricare la classifica dei centri immersioni';

  @override
  String get statistics_social_topDiveCenters_subtitle =>
      'Operatori piu visitati';

  @override
  String get statistics_social_topDiveCenters_title =>
      'Migliori centri immersioni';

  @override
  String get statistics_summary_avgDepth => 'Profondita media';

  @override
  String get statistics_summary_avgTemp => 'Temp. media';

  @override
  String get statistics_summary_depthDistribution_empty =>
      'Il grafico apparira quando registrerai immersioni';

  @override
  String get statistics_summary_depthDistribution_semanticLabel =>
      'Grafico a torta che mostra la distribuzione della profondita';

  @override
  String get statistics_summary_depthDistribution_title =>
      'Distribuzione profondita';

  @override
  String get statistics_summary_diveTypes_empty =>
      'Il grafico apparira quando registrerai immersioni';

  @override
  String statistics_summary_diveTypes_moreTypes(Object count) {
    return 'e $count altri tipi';
  }

  @override
  String get statistics_summary_diveTypes_semanticLabel =>
      'Grafico a torta che mostra la distribuzione dei tipi di immersione';

  @override
  String get statistics_summary_diveTypes_title => 'Tipi di immersione';

  @override
  String get statistics_summary_divesByMonth_empty =>
      'Il grafico apparira quando registrerai immersioni';

  @override
  String get statistics_summary_divesByMonth_semanticLabel =>
      'Grafico a barre che mostra le immersioni per mese';

  @override
  String get statistics_summary_divesByMonth_title => 'Immersioni per mese';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel\n$count immersioni';
  }

  @override
  String get statistics_summary_header_subtitle =>
      'Seleziona una categoria per esplorare le statistiche dettagliate';

  @override
  String get statistics_summary_header_title => 'Panoramica statistiche';

  @override
  String get statistics_summary_maxDepth => 'Profondita max';

  @override
  String get statistics_summary_sitesVisited => 'Siti visitati';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni',
      one: '1 immersione',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty => 'Nessun tag ancora creato';

  @override
  String get statistics_summary_tagUsage_emptyHint =>
      'Aggiungi tag alle immersioni per vedere le statistiche';

  @override
  String statistics_summary_tagUsage_moreTags(Object count) {
    return 'e $count altri tag';
  }

  @override
  String statistics_summary_tagUsage_tagCount(Object count) {
    return '$count tag';
  }

  @override
  String get statistics_summary_tagUsage_title => 'Utilizzo tag';

  @override
  String statistics_summary_topDiveSites_diveCount(Object count) {
    return '$count immersioni';
  }

  @override
  String get statistics_summary_topDiveSites_empty =>
      'Nessun sito di immersione ancora';

  @override
  String get statistics_summary_topDiveSites_title =>
      'Migliori siti di immersione';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count totali';
  }

  @override
  String get statistics_summary_totalDives => 'Immersioni totali';

  @override
  String get statistics_summary_totalTime => 'Tempo totale';

  @override
  String get statistics_timePatterns_appBar_title => 'Distribuzioni temporali';

  @override
  String get statistics_timePatterns_dayOfWeek_empty =>
      'Nessun dato disponibile';

  @override
  String get statistics_timePatterns_dayOfWeek_error =>
      'Impossibile caricare i dati per giorno della settimana';

  @override
  String get statistics_timePatterns_dayOfWeek_fri => 'Ven';

  @override
  String get statistics_timePatterns_dayOfWeek_mon => 'Lun';

  @override
  String get statistics_timePatterns_dayOfWeek_sat => 'Sab';

  @override
  String get statistics_timePatterns_dayOfWeek_subtitle =>
      'Quando ti immergi di piu?';

  @override
  String get statistics_timePatterns_dayOfWeek_sun => 'Dom';

  @override
  String get statistics_timePatterns_dayOfWeek_thu => 'Gio';

  @override
  String get statistics_timePatterns_dayOfWeek_title =>
      'Immersioni per giorno della settimana';

  @override
  String get statistics_timePatterns_dayOfWeek_tue => 'Mar';

  @override
  String get statistics_timePatterns_dayOfWeek_wed => 'Mer';

  @override
  String get statistics_timePatterns_month_apr => 'Apr';

  @override
  String get statistics_timePatterns_month_aug => 'Ago';

  @override
  String get statistics_timePatterns_month_dec => 'Dic';

  @override
  String get statistics_timePatterns_month_feb => 'Feb';

  @override
  String get statistics_timePatterns_month_jan => 'Gen';

  @override
  String get statistics_timePatterns_month_jul => 'Lug';

  @override
  String get statistics_timePatterns_month_jun => 'Giu';

  @override
  String get statistics_timePatterns_month_mar => 'Mar';

  @override
  String get statistics_timePatterns_month_may => 'Mag';

  @override
  String get statistics_timePatterns_month_nov => 'Nov';

  @override
  String get statistics_timePatterns_month_oct => 'Ott';

  @override
  String get statistics_timePatterns_month_sep => 'Set';

  @override
  String get statistics_timePatterns_seasonal_empty =>
      'Nessun dato disponibile';

  @override
  String get statistics_timePatterns_seasonal_error =>
      'Impossibile caricare i dati stagionali';

  @override
  String get statistics_timePatterns_seasonal_subtitle =>
      'Immersioni per mese (tutti gli anni)';

  @override
  String get statistics_timePatterns_seasonal_title =>
      'Distribuzioni stagionali';

  @override
  String get statistics_timePatterns_surfaceInterval_average => 'Media';

  @override
  String get statistics_timePatterns_surfaceInterval_empty =>
      'Nessun dato sull\'intervallo di superficie disponibile';

  @override
  String get statistics_timePatterns_surfaceInterval_error =>
      'Impossibile caricare i dati sull\'intervallo di superficie';

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
  String get statistics_timePatterns_surfaceInterval_maximum => 'Massimo';

  @override
  String get statistics_timePatterns_surfaceInterval_minimum => 'Minimo';

  @override
  String get statistics_timePatterns_surfaceInterval_subtitle =>
      'Tempo tra le immersioni';

  @override
  String get statistics_timePatterns_surfaceInterval_title =>
      'Statistiche intervallo di superficie';

  @override
  String get statistics_timePatterns_timeOfDay_error =>
      'Impossibile caricare i dati sull\'ora del giorno';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle =>
      'Mattina, pomeriggio, sera o notte';

  @override
  String get statistics_timePatterns_timeOfDay_title =>
      'Immersioni per ora del giorno';

  @override
  String get statistics_tooltip_diveRecords => 'Record immersioni';

  @override
  String get statistics_tooltip_filter => 'Filtra statistiche';

  @override
  String get statistics_tooltip_refreshRecords => 'Aggiorna record';

  @override
  String get statistics_tooltip_refreshStatistics => 'Aggiorna statistiche';

  @override
  String statistics_valueCard_semanticLabel(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String get surfaceInterval_aboutTissueLoading_body =>
      'Il tuo corpo ha 16 compartimenti tissutali che assorbono e rilasciano azoto a velocità diverse. I tessuti veloci (come il sangue) si saturano rapidamente ma si desaturano anche rapidamente. I tessuti lenti (come ossa e grasso) richiedono più tempo sia per caricarsi che per scaricarsi. Il \"compartimento principale\" è quello più saturo e tipicamente controlla il limite di non decompressione (NDL). Durante un intervallo di superficie, tutti i tessuti si desaturano verso i livelli di saturazione di superficie (~40% di carico).';

  @override
  String get surfaceInterval_aboutTissueLoading_title =>
      'Informazioni sul Carico Tissutale';

  @override
  String get surfaceInterval_action_resetDefaults => 'Ripristina predefiniti';

  @override
  String get surfaceInterval_disclaimer =>
      'Questo strumento è solo a scopo di pianificazione. Usa sempre un computer subacqueo e segui la tua formazione. I risultati si basano sull\'algoritmo Buhlmann ZH-L16C e possono differire dal tuo computer.';

  @override
  String get surfaceInterval_field_depth => 'Profondità';

  @override
  String get surfaceInterval_field_gasMix => 'Miscela Gas: ';

  @override
  String get surfaceInterval_field_he => 'He';

  @override
  String get surfaceInterval_field_o2 => 'O₂';

  @override
  String get surfaceInterval_field_time => 'Tempo';

  @override
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit) {
    return 'Profondità prima immersione: $depth $unit';
  }

  @override
  String surfaceInterval_firstDive_timeSemantics(Object time) {
    return 'Tempo prima immersione: $time minuti';
  }

  @override
  String get surfaceInterval_firstDive_title => 'Prima Immersione';

  @override
  String surfaceInterval_format_hours(Object count) {
    return '$count ore';
  }

  @override
  String surfaceInterval_format_minutes(Object count) {
    return '$count min';
  }

  @override
  String get surfaceInterval_gasMix_air => 'Aria';

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
    return 'ppO₂ $ppO2 a $depth supera $limit. La MOD di questa miscela è $mod.';
  }

  @override
  String surfaceInterval_heSemantics(Object percent) {
    return 'Elio: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String surfaceInterval_result_beyondHorizon(Object hours) {
    return 'L\'attesa supera le $hours ore esplorate da questo pianificatore. La desaturazione continua, quindi un intervallo di superficie più lungo sarà sufficiente.';
  }

  @override
  String surfaceInterval_result_beyondHorizonShort(Object hours) {
    return 'Più di $hours ore';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Intervallo Corrente';

  @override
  String get surfaceInterval_result_gasUnsafe =>
      'Miscela non sicura a questa profondità';

  @override
  String get surfaceInterval_result_inDeco => 'In deco';

  @override
  String get surfaceInterval_result_increaseInterval =>
      'Aumenta l\'intervallo di superficie o riduci profondità/tempo della seconda immersione';

  @override
  String get surfaceInterval_result_minimumInterval =>
      'Intervallo di Superficie Minimo';

  @override
  String get surfaceInterval_result_ndlForSecondDive => 'NDL per 2ª Immersione';

  @override
  String surfaceInterval_result_ndlMinutes(Object minutes) {
    return '$minutes min NDL';
  }

  @override
  String surfaceInterval_result_noIntervalHelps(Object minutes) {
    return 'Nessun intervallo di superficie è sufficiente. L\'immersione senza decompressione più lunga a questa profondità con questa miscela è di $minutes min. Accorcia la seconda immersione o riducine la profondità.';
  }

  @override
  String get surfaceInterval_result_notAchievable =>
      'Non raggiungibile con alcun intervallo di superficie';

  @override
  String get surfaceInterval_result_notYetSafe =>
      'Non ancora sicuro, aumenta l\'intervallo di superficie';

  @override
  String get surfaceInterval_result_safeToDive => 'Sicuro per immergersi';

  @override
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  ) {
    return 'Intervallo di superficie minimo: $interval. Intervallo corrente: $current. NDL per seconda immersione: $ndl. $status';
  }

  @override
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit) {
    return 'Profondità seconda immersione: $depth $unit';
  }

  @override
  String surfaceInterval_secondDive_heSemantics(Object percent) {
    return 'Elio seconda immersione: $percent%';
  }

  @override
  String surfaceInterval_secondDive_o2Semantics(Object percent) {
    return 'O2 seconda immersione: $percent%';
  }

  @override
  String surfaceInterval_secondDive_timeSemantics(Object time) {
    return 'Tempo seconda immersione: $time minuti';
  }

  @override
  String get surfaceInterval_secondDive_title => 'Seconda Immersione';

  @override
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval) {
    return 'Grafico recupero tissutale che mostra la desaturazione di 16 compartimenti durante un intervallo di superficie di $interval';
  }

  @override
  String get surfaceInterval_tissueRecovery_compartmentsLabel =>
      'Compartimenti (per velocità di emitempo)';

  @override
  String get surfaceInterval_tissueRecovery_description =>
      'Mostra come ogni compartimento tissutale dei 16 si desatura durante l\'intervallo di superficie';

  @override
  String get surfaceInterval_tissueRecovery_fast => 'Veloci (C1-5)';

  @override
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number) {
    return 'Compartimento principale: C$number';
  }

  @override
  String get surfaceInterval_tissueRecovery_loadingPercent => 'Carico %';

  @override
  String get surfaceInterval_tissueRecovery_medium => 'Medi (C6-10)';

  @override
  String get surfaceInterval_tissueRecovery_min => 'Min';

  @override
  String get surfaceInterval_tissueRecovery_now => 'Ora';

  @override
  String get surfaceInterval_tissueRecovery_slow => 'Lenti (C11-16)';

  @override
  String get surfaceInterval_tissueRecovery_title => 'Recupero Tissutale';

  @override
  String get surfaceInterval_title => 'Intervallo di Superficie';

  @override
  String tags_action_createNamed(Object tagName) {
    return 'Crea \"$tagName\"';
  }

  @override
  String get tags_action_createTag => 'Crea tag';

  @override
  String get tags_action_browse => 'Sfoglia';

  @override
  String get tags_picker_title => 'Scegli tag';

  @override
  String get tags_picker_empty =>
      'Nessun tag. Digita un nome per creare il primo.';

  @override
  String tags_picker_errorLoading(String error) {
    return 'Errore durante il caricamento dei tag: $error';
  }

  @override
  String get tags_picker_allAdded => 'Tutti i tag sono già stati aggiunti.';

  @override
  String get tags_picker_noMatches => 'Nessun tag corrisponde alla ricerca.';

  @override
  String tags_picker_addCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aggiungi $count tag',
      one: 'Aggiungi 1 tag',
      zero: 'Aggiungi tag',
    );
    return '$_temp0';
  }

  @override
  String get tags_action_deleteTag => 'Elimina tag';

  @override
  String tags_dialog_deleteMessage(Object tagName) {
    return 'Sei sicuro di voler eliminare \"$tagName\"? Questo lo rimuoverà da tutte le immersioni.';
  }

  @override
  String get tags_dialog_deleteTitle => 'Eliminare Tag?';

  @override
  String get tags_empty =>
      'Nessun tag ancora. Crea tag quando modifichi le immersioni.';

  @override
  String get tags_hint_addMoreTags => 'Aggiungi altri tag...';

  @override
  String get importWizard_tagsLabel => 'Tags';

  @override
  String get importWizard_photos_stepLabel => 'Foto';

  @override
  String importWizard_photos_foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto referenziate in questo diario',
      one: '1 foto referenziata in questo diario',
    );
    return '$_temp0';
  }

  @override
  String get importWizard_photos_chooseFolder =>
      'Scegli la cartella delle foto...';

  @override
  String get importWizard_photos_scanning => 'Scansione della cartella...';

  @override
  String importWizard_photos_matchSummary(
    int matched,
    int byName,
    int missing,
  ) {
    return '$matched associate, $byName solo per nome file, $missing non trovate';
  }

  @override
  String get importWizard_photos_skip => 'Salta le foto';

  @override
  String get importWizard_photos_mobileUnsupported =>
      'L\'importazione delle foto richiede una cartella sul disco di questo dispositivo. Esegui questa importazione su un computer per includerle. Immersioni e siti vengono importati normalmente.';

  @override
  String importWizard_review_olderDivesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni precedenti ignorate — già nel tuo libro',
      one: '1 immersione precedente ignorata — già nel tuo libro',
    );
    return '$_temp0';
  }

  @override
  String get tags_hint_addTags => 'Aggiungi tag...';

  @override
  String get tags_manage_title => 'Tag';

  @override
  String get tags_manage_searchHint => 'Cerca tag...';

  @override
  String tags_manage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni',
      one: '1 immersione',
      zero: '0 immersioni',
    );
    return '$_temp0';
  }

  @override
  String get tags_manage_emptyState =>
      'Nessun tag ancora. Creane uno per iniziare.';

  @override
  String tags_manage_selectedCount(int count) {
    return '$count selezionati';
  }

  @override
  String get tags_manage_createTitle => 'Crea tag';

  @override
  String get tags_manage_editTitle => 'Modifica tag';

  @override
  String get tags_manage_nameLabel => 'Nome tag';

  @override
  String get tags_manage_colorLabel => 'Colore';

  @override
  String get tags_manage_nameRequired => 'Il nome del tag e obbligatorio';

  @override
  String get tags_manage_deleteTitle => 'Eliminare il tag?';

  @override
  String tags_manage_deleteMessage(String tagName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni',
      one: '1 immersione',
      zero: '0 immersioni',
    );
    return '\"$tagName\" verra rimosso da $_temp0. Questa azione non puo essere annullata.';
  }

  @override
  String tags_manage_bulkDeleteTitle(int count) {
    return 'Eliminare $count tag?';
  }

  @override
  String tags_manage_bulkDeleteMessage(int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount immersioni',
      one: '1 immersione',
      zero: '0 immersioni',
    );
    return 'Questi tag verranno rimossi da $_temp0 in totale. Questa azione non puo essere annullata.';
  }

  @override
  String tags_manage_mergeTitle(int count) {
    return 'Unisci $count tag';
  }

  @override
  String get tags_manage_mergeResultName => 'Nome tag risultante:';

  @override
  String get tags_manage_mergeKeepFrom => 'Oppure mantieni il nome da:';

  @override
  String tags_manage_mergeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni',
      one: '1 immersione',
      zero: '0 immersioni',
    );
    return 'Questo influenzera $_temp0 in totale.';
  }

  @override
  String get tags_manage_mergeAction => 'Unisci';

  @override
  String get tags_title_manageTags => 'Gestisci Tag';

  @override
  String get tank_al30Stage_description =>
      'Bombola stage in alluminio da 30 cu ft';

  @override
  String get tank_al30Stage_displayName => 'AL30 Stage';

  @override
  String get tank_al40Stage_description =>
      'Bombola stage in alluminio da 40 cu ft';

  @override
  String get tank_al40Stage_displayName => 'AL40 Stage';

  @override
  String get tank_al40_description => 'Alluminio 40 cu ft (pony)';

  @override
  String get tank_al40_displayName => 'AL40';

  @override
  String get tank_al63_description => 'Alluminio 63 cu ft';

  @override
  String get tank_al63_displayName => 'AL63';

  @override
  String get tank_al80_description => 'Alluminio 80 cu ft (la piu comune)';

  @override
  String get tank_al80_displayName => 'AL80';

  @override
  String get tank_hp100_description => 'Acciaio alta pressione 100 cu ft';

  @override
  String get tank_hp100_displayName => 'HP100';

  @override
  String get tank_hp120_description => 'Acciaio alta pressione 120 cu ft';

  @override
  String get tank_hp120_displayName => 'HP120';

  @override
  String get tank_hp80_description => 'Acciaio alta pressione 80 cu ft';

  @override
  String get tank_hp80_displayName => 'HP80';

  @override
  String get tank_lp85_description => 'Acciaio bassa pressione 85 cu ft';

  @override
  String get tank_lp85_displayName => 'LP85';

  @override
  String get tank_steel10_description => 'Acciaio 10 litri (Europa)';

  @override
  String get tank_steel10_displayName => 'Acciaio 10L';

  @override
  String get tank_steel12_description => 'Acciaio 12 litri (Europa)';

  @override
  String get tank_steel12_displayName => 'Acciaio 12L';

  @override
  String get tank_steel15_description => 'Acciaio 15 litri (Europa)';

  @override
  String get tank_steel15_displayName => 'Acciaio 15L';

  @override
  String get tides_action_refresh => 'Aggiorna dati maree';

  @override
  String get tides_chart_24hourForecast => 'Previsione 24 Ore';

  @override
  String tides_chart_heightAxis(Object depthSymbol) {
    return 'Altezza ($depthSymbol)';
  }

  @override
  String get tides_chart_msl => 'LMM';

  @override
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr) {
    return ' Ora $nowTimeStr $nowHeightStr';
  }

  @override
  String get tides_error_unableToLoad =>
      'Impossibile caricare i dati delle maree';

  @override
  String get tides_error_unableToLoadChart => 'Impossibile caricare il grafico';

  @override
  String tides_label_ago(Object duration) {
    return '$duration fa';
  }

  @override
  String tides_label_currentHeight(Object height, Object depthSymbol) {
    return 'Corrente: $height$depthSymbol';
  }

  @override
  String tides_label_fromNow(Object duration) {
    return '$duration da ora';
  }

  @override
  String get tides_label_high => 'Alta';

  @override
  String get tides_label_highIn => 'Alta tra';

  @override
  String get tides_label_highTide => 'Marea Alta';

  @override
  String get tides_label_low => 'Bassa';

  @override
  String get tides_label_lowIn => 'Bassa tra';

  @override
  String get tides_label_lowTide => 'Marea Bassa';

  @override
  String tides_label_tideIn(Object duration) {
    return 'tra $duration';
  }

  @override
  String get tides_label_tideTimes => 'Orari Maree';

  @override
  String get tides_label_today => 'Oggi';

  @override
  String get tides_label_tomorrow => 'Domani';

  @override
  String get tides_label_upcomingTides => 'Maree in Arrivo';

  @override
  String get tides_legend_highTide => 'Marea Alta';

  @override
  String get tides_legend_lowTide => 'Marea Bassa';

  @override
  String get tides_legend_now => 'Ora';

  @override
  String get tides_legend_tideLevel => 'Livello Marea';

  @override
  String get tides_noDataAvailable => 'Nessun dato maree disponibile';

  @override
  String get tides_noDataForLocation =>
      'Dati maree non disponibili per questa posizione';

  @override
  String get tides_noExtremesData => 'Nessun dato estremi';

  @override
  String get tides_noTideTimesAvailable => 'Nessun orario maree disponibile';

  @override
  String tides_semantic_currentTide(
    Object tideState,
    Object height,
    Object depthSymbol,
    Object nextExtreme,
  ) {
    return 'Marea $tideState, $height$depthSymbol$nextExtreme';
  }

  @override
  String tides_semantic_extremeItem(
    Object typeLabel,
    Object time,
    Object height,
    Object depthSymbol,
  ) {
    return 'Marea $typeLabel alle $time, $height$depthSymbol';
  }

  @override
  String tides_semantic_tideChart(Object extremesSummary) {
    return 'Grafico maree. $extremesSummary';
  }

  @override
  String tides_semantic_tideState(Object state) {
    return 'Stato marea: $state';
  }

  @override
  String tides_source_noaaStation(String name, String distance) {
    return 'Stazione NOAA: $name ($distance)';
  }

  @override
  String get tides_source_modelEstimate => 'Stima da modello oceanico';

  @override
  String get tides_source_modelCaveat =>
      'Modellato da dati satellitari. Orari e altezze possono differire vicino a coste complesse.';

  @override
  String get tides_source_sheetTitle => 'Fonte dei dati di marea';

  @override
  String get tides_source_datumMllw =>
      'Altezze rispetto al MLLW (datum della stazione)';

  @override
  String get tides_source_datumMsl =>
      'Altezze rispetto al livello medio del mare';

  @override
  String get tides_title => 'Maree';

  @override
  String get transfer_appBar_title => 'Trasferimento';

  @override
  String get transfer_computers_aboutContent =>
      'Collega il tuo dive computer via Bluetooth per scaricare i registri immersione direttamente nell\'app. I computer supportati includono Suunto, Shearwater, Garmin, Mares e molte altre marche popolari.\n\nGli utenti di Apple Watch Ultra possono importare i dati delle immersioni direttamente dall\'app Salute, inclusi profondità, durata e frequenza cardiaca.';

  @override
  String get transfer_computers_aboutTitle => 'Informazioni sui dive computer';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple Watch';

  @override
  String get transfer_computers_appleWatchSubtitle =>
      'Import dives via Apple HealthKit';

  @override
  String get transfer_computers_appleWatchTitle => 'Importa da Apple Watch';

  @override
  String get transfer_computers_connectSubtitle =>
      'Scopri e associa un dive computer';

  @override
  String get transfer_computers_connectTitle => 'Collega nuovo computer';

  @override
  String get transfer_computers_errorLoading =>
      'Errore nel caricamento dei computer';

  @override
  String get transfer_computers_loading => 'Caricamento...';

  @override
  String get transfer_computers_manageTitle => 'Gestisci computer';

  @override
  String get transfer_computers_noComputersSaved => 'Nessun computer salvato';

  @override
  String transfer_computers_diveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni',
      one: '1 immersione',
    );
    return '$_temp0';
  }

  @override
  String get transfer_computers_downloadTooltip => 'Scarica immersioni';

  @override
  String get transfer_computers_knownComputersHeader => 'Computer conosciuti';

  @override
  String transfer_computers_lastDownloadDaysAgo(int days) {
    return '$days giorni fa';
  }

  @override
  String transfer_computers_lastDownloadHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours ore fa',
      one: '1 ora fa',
    );
    return '$_temp0';
  }

  @override
  String transfer_computers_lastDownloadMinutesAgo(int minutes) {
    return '$minutes min fa';
  }

  @override
  String get transfer_computers_lastDownloadNever => 'Mai';

  @override
  String get transfer_computers_lastDownloadYesterday => 'Ieri';

  @override
  String transfer_computers_savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'computer salvati',
      one: 'computer salvato',
    );
    return '$count $_temp0';
  }

  @override
  String get transfer_computers_sectionHeader => 'Dive computer';

  @override
  String get transfer_csvExport_cancelButton => 'Annulla';

  @override
  String get transfer_csvExport_dataTypeHeader => 'Tipo di dati';

  @override
  String get transfer_csvExport_descriptionDives =>
      'Esporta tutti i registri immersione come foglio di calcolo';

  @override
  String get transfer_csvExport_descriptionEquipment =>
      'Esporta inventario attrezzatura e informazioni sulla manutenzione';

  @override
  String get transfer_csvExport_descriptionSites =>
      'Esporta località e dettagli dei siti di immersione';

  @override
  String get transfer_csvExport_dialogTitle => 'Esporta CSV';

  @override
  String get transfer_csvExport_exportButton => 'Esporta CSV';

  @override
  String get transfer_csvExport_optionDivesTitle => 'CSV Immersioni';

  @override
  String get transfer_csvExport_optionEquipmentTitle => 'CSV Attrezzatura';

  @override
  String get transfer_csvExport_optionSitesTitle => 'CSV Siti';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return 'Esporta $typeName';
  }

  @override
  String get transfer_csvExport_typeDives => 'Immersioni';

  @override
  String get transfer_csvExport_typeEquipment => 'Attrezzatura';

  @override
  String get transfer_csvExport_typeSites => 'Siti';

  @override
  String get transfer_detail_backTooltip => 'Torna al trasferimento';

  @override
  String get transfer_export_aboutContent =>
      'Esporta i tuoi dati di immersione in vari formati. Il PDF crea un logbook stampabile. L\'UDDF è un formato universale compatibile con la maggior parte dei software di registrazione immersioni. I file CSV possono essere aperti nelle applicazioni di fogli di calcolo.';

  @override
  String get transfer_export_backupLink => 'Vai a Backup e ripristino';

  @override
  String get transfer_export_aboutTitle => 'Informazioni sull\'esportazione';

  @override
  String get transfer_export_completed => 'Esportazione completata';

  @override
  String get transfer_export_csvSubtitle => 'Formato foglio di calcolo';

  @override
  String get transfer_export_csvTitle => 'Esportazione CSV';

  @override
  String get transfer_export_excelSubtitle =>
      'Tutti i dati in un unico file (immersioni, siti, attrezzatura, statistiche)';

  @override
  String get transfer_export_excelTitle => 'Cartella di lavoro Excel';

  @override
  String transfer_export_failed(Object error) {
    return 'Esportazione non riuscita: $error';
  }

  @override
  String get transfer_export_kmlSubtitle =>
      'Visualizza i siti di immersione su un globo 3D';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => 'Esportazione multi-formato';

  @override
  String get transfer_export_optionSaveSubtitle =>
      'Scegli dove salvare sul tuo dispositivo';

  @override
  String get transfer_export_optionSaveTitle => 'Salva su file';

  @override
  String get transfer_export_optionShareSubtitle =>
      'Invia tramite email, messaggi o altre app';

  @override
  String get transfer_export_optionShareTitle => 'Condividi';

  @override
  String get transfer_export_pdfSubtitle => 'Logbook immersioni stampabile';

  @override
  String get transfer_export_pdfTitle => 'Logbook PDF';

  @override
  String get transfer_export_progressExporting => 'Esportazione in corso...';

  @override
  String get transfer_export_sectionHeader => 'Esporta dati';

  @override
  String get transfer_export_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_export_uddfTitle => 'Esportazione UDDF';

  @override
  String get transfer_import_aboutContent =>
      'Usa \"Importa dati\" per la migliore esperienza -- rileva automaticamente il formato del file e l\'app di origine. Le opzioni per i singoli formati qui sotto sono disponibili anche per l\'accesso diretto.';

  @override
  String get transfer_import_aboutTitle => 'Informazioni sull\'importazione';

  @override
  String get transfer_import_fileImportSemanticLabel =>
      'Importa dati con rilevamento automatico';

  @override
  String get transfer_import_fileImportSubtitle =>
      'Rileva automaticamente CSV, UDDF, FIT e altro';

  @override
  String get transfer_import_fileImportTitle => 'Importa dati';

  @override
  String get transfer_import_sectionHeader => 'Importa dati';

  @override
  String get transfer_pdfExport_cancelButton => 'Annulla';

  @override
  String get transfer_pdfExport_dialogTitle => 'Esporta logbook PDF';

  @override
  String get transfer_pdfExport_exportButton => 'Esporta PDF';

  @override
  String get transfer_pdfExport_includeCertCards =>
      'Includi tessere certificazione';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle =>
      'Aggiungi le immagini delle tessere certificazione scansionate al PDF';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => 'Dimensione pagina';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Letter';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => 'Dettagliato';

  @override
  String get transfer_pdfExport_templateDetailedDesc =>
      'Informazioni complete sull\'immersione con note e valutazioni';

  @override
  String get transfer_pdfExport_templateHeader => 'Modello';

  @override
  String get transfer_pdfExport_templateNauiStyle => 'Stile NAUI';

  @override
  String get transfer_pdfExport_templateNauiStyleDesc =>
      'Layout corrispondente al formato logbook NAUI';

  @override
  String get transfer_pdfExport_templatePadiStyle => 'Stile PADI';

  @override
  String get transfer_pdfExport_templatePadiStyleDesc =>
      'Layout corrispondente al formato logbook PADI';

  @override
  String get transfer_pdfExport_templateProfessional => 'Professionale';

  @override
  String get transfer_pdfExport_templateProfessionalDesc =>
      'Aree per firma e timbro per la verifica';

  @override
  String transfer_pdfExport_templateSemanticLabel(Object templateName) {
    return 'Seleziona modello $templateName';
  }

  @override
  String get transfer_pdfExport_templateSimple => 'Semplice';

  @override
  String get transfer_pdfExport_templateSimpleDesc =>
      'Formato tabella compatto, molte immersioni per pagina';

  @override
  String get transfer_section_computersSubtitle => 'Scarica dal dispositivo';

  @override
  String get transfer_section_computersTitle => 'Dive computer';

  @override
  String get transfer_section_exportSubtitle => 'CSV, UDDF, logbook PDF';

  @override
  String get transfer_section_exportTitle => 'Esporta';

  @override
  String get transfer_section_importSubtitle => 'File CSV, UDDF';

  @override
  String get transfer_section_importTitle => 'Importa';

  @override
  String get transfer_summary_description =>
      'Importa ed esporta dati immersione';

  @override
  String get transfer_summary_selectSection =>
      'Seleziona una sezione dalla lista';

  @override
  String get transfer_summary_title => 'Trasferimento';

  @override
  String transfer_unknownSection(Object sectionId) {
    return 'Sezione sconosciuta: $sectionId';
  }

  @override
  String get trips_appBar_title => 'Viaggi';

  @override
  String get trips_appBar_tripPhotos => 'Foto del viaggio';

  @override
  String get trips_detail_action_delete => 'Elimina';

  @override
  String get trips_detail_action_export => 'Esporta';

  @override
  String get trips_detail_appBar_title => 'Viaggio';

  @override
  String get trips_detail_dialog_cancel => 'Annulla';

  @override
  String get trips_detail_dialog_deleteConfirm => 'Elimina';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return 'Sei sicuro di voler eliminare \"$name\"? Il viaggio verrà rimosso ma le immersioni saranno mantenute.';
  }

  @override
  String get trips_detail_dialog_deleteTitle => 'Eliminare il viaggio?';

  @override
  String get trips_detail_dives_empty =>
      'Nessuna immersione in questo viaggio ancora';

  @override
  String get trips_detail_dives_errorLoading =>
      'Impossibile caricare le immersioni';

  @override
  String get trips_detail_dives_unknownSite => 'Sito sconosciuto';

  @override
  String trips_detail_dives_viewAll(Object count) {
    return 'Visualizza tutte ($count)';
  }

  @override
  String trips_detail_durationDays(Object days) {
    return '$days giorni';
  }

  @override
  String get trips_detail_export_csv_comingSoon => 'Esportazione CSV in arrivo';

  @override
  String get trips_detail_export_csv_subtitle =>
      'Tutte le immersioni di questo viaggio';

  @override
  String get trips_detail_export_csv_title => 'Esporta in CSV';

  @override
  String get trips_detail_export_pdf_comingSoon => 'Esportazione PDF in arrivo';

  @override
  String get trips_detail_export_pdf_subtitle =>
      'Riepilogo del viaggio con dettagli delle immersioni';

  @override
  String get trips_detail_export_pdf_title => 'Esporta in PDF';

  @override
  String get trips_detail_label_liveaboard => 'Crociera subacquea';

  @override
  String get trips_detail_label_location => 'Località';

  @override
  String get trips_detail_label_resort => 'Resort';

  @override
  String get trips_detail_scan_accessDenied =>
      'Accesso alla libreria foto negato';

  @override
  String get trips_detail_scan_addDivesFirst =>
      'Aggiungi prima le immersioni per collegare le foto';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return 'Errore nel collegamento delle foto: $error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return 'Errore nella scansione: $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return 'Collegate $count foto';
  }

  @override
  String get trips_detail_scan_linkingPhotos => 'Collegamento foto in corso...';

  @override
  String get trips_detail_sectionTitle_details => 'Dettagli viaggio';

  @override
  String get trips_detail_sectionTitle_dives => 'Immersioni';

  @override
  String get trips_detail_sectionTitle_notes => 'Note';

  @override
  String get trips_detail_sectionTitle_statistics => 'Statistiche viaggio';

  @override
  String get trips_detail_snackBar_deleted => 'Viaggio eliminato';

  @override
  String get trips_detail_stat_avgDepth => 'Profondità media';

  @override
  String get trips_detail_stat_maxDepth => 'Profondità massima';

  @override
  String get trips_detail_stat_totalRuntime => 'Tempo totale';

  @override
  String get trips_detail_stat_totalDives => 'Immersioni totali';

  @override
  String get trips_detail_tab_checklist => 'Lista di controllo';

  @override
  String get trips_detail_tooltip_edit => 'Modifica viaggio';

  @override
  String get trips_detail_tooltip_editShort => 'Modifica';

  @override
  String get trips_detail_tooltip_moreOptions => 'Altre opzioni';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Visualizza sulla mappa';

  @override
  String trips_diveScan_addButton(int count) {
    return 'Aggiungi $count immersioni';
  }

  @override
  String trips_diveScan_added(int count) {
    return '$count immersioni aggiunte al viaggio';
  }

  @override
  String get trips_diveScan_cancel => 'Annulla';

  @override
  String trips_diveScan_currentTrip(String tripName) {
    return 'Attualmente in: $tripName';
  }

  @override
  String get trips_diveScan_deselectAll => 'Deseleziona tutto';

  @override
  String trips_diveScan_error(String error) {
    return 'Errore nella ricerca delle immersioni: $error';
  }

  @override
  String get trips_diveScan_findButton => 'Trova immersioni corrispondenti';

  @override
  String trips_diveScan_groupOtherTrips(int count) {
    return 'In altri viaggi ($count)';
  }

  @override
  String trips_diveScan_groupUnassigned(int count) {
    return 'Non assegnate ($count)';
  }

  @override
  String get trips_diveScan_noMatches =>
      'Nessuna immersione corrispondente trovata';

  @override
  String get trips_diveScan_noDiver =>
      'Seleziona un subacqueo attivo per cercare le immersioni';

  @override
  String get trips_diveScan_selectAll => 'Seleziona tutto';

  @override
  String trips_diveScan_subtitle(int count) {
    return '$count immersioni trovate nell\'intervallo di date';
  }

  @override
  String get trips_diveScan_title => 'Aggiungi immersioni al viaggio';

  @override
  String get trips_diveScan_unknownSite => 'Sito sconosciuto';

  @override
  String get trips_edit_appBar_add => 'Aggiungi viaggio';

  @override
  String get trips_edit_appBar_edit => 'Modifica viaggio';

  @override
  String get trips_edit_button_add => 'Aggiungi viaggio';

  @override
  String get trips_edit_button_cancel => 'Annulla';

  @override
  String get trips_edit_button_save => 'Salva';

  @override
  String get trips_edit_button_update => 'Aggiorna viaggio';

  @override
  String get trips_edit_dialog_discard => 'Scarta';

  @override
  String get trips_edit_dialog_discardContent =>
      'Hai modifiche non salvate. Sei sicuro di voler uscire?';

  @override
  String get trips_edit_dialog_discardTitle => 'Scartare le modifiche?';

  @override
  String get trips_edit_dialog_keepEditing => 'Continua a modificare';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days giorni';
  }

  @override
  String get trips_edit_hint_liveaboardName => 'es. MY Blue Force One';

  @override
  String get trips_edit_hint_location => 'es. Egitto, Mar Rosso';

  @override
  String get trips_edit_hint_notes =>
      'Eventuali note aggiuntive su questo viaggio';

  @override
  String get trips_edit_hint_resortName => 'es. Marsa Shagra';

  @override
  String get trips_edit_hint_tripName => 'es. Safari Mar Rosso 2024';

  @override
  String get trips_edit_label_endDate => 'Data di fine';

  @override
  String get trips_edit_label_liveaboardName => 'Nome crociera subacquea';

  @override
  String get trips_edit_label_location => 'Località';

  @override
  String get trips_edit_label_notes => 'Note';

  @override
  String get trips_edit_label_resortName => 'Nome resort';

  @override
  String get trips_edit_label_returnFlight => 'Volo di ritorno';

  @override
  String get trips_edit_returnFlightClear => 'Rimuovi volo di ritorno';

  @override
  String get trips_edit_returnFlightNotSet => 'Non impostato';

  @override
  String get trips_edit_label_startDate => 'Data di inizio';

  @override
  String get trips_edit_label_tripName => 'Nome viaggio *';

  @override
  String get trips_edit_sectionTitle_dates => 'Date del viaggio';

  @override
  String get trips_edit_sectionTitle_location => 'Località';

  @override
  String get trips_edit_sectionTitle_notes => 'Note';

  @override
  String get trips_edit_semanticLabel_save => 'Salva viaggio';

  @override
  String get trips_edit_snackBar_added => 'Viaggio aggiunto con successo';

  @override
  String trips_edit_snackBar_errorLoading(Object error) {
    return 'Errore nel caricamento del viaggio: $error';
  }

  @override
  String trips_edit_snackBar_errorSaving(Object error) {
    return 'Errore nel salvataggio del viaggio: $error';
  }

  @override
  String get trips_edit_snackBar_updated => 'Viaggio aggiornato con successo';

  @override
  String get trips_edit_validation_nameRequired =>
      'Inserisci un nome per il viaggio';

  @override
  String get trips_gallery_accessDenied => 'Accesso alla libreria foto negato';

  @override
  String get trips_gallery_addDivesFirst =>
      'Aggiungi prima le immersioni per collegare le foto';

  @override
  String get trips_gallery_appBar_title => 'Foto del viaggio';

  @override
  String trips_gallery_diveSection_photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto',
      one: 'foto',
    );
    return '$_temp0';
  }

  @override
  String trips_gallery_diveSection_title(Object number, Object site) {
    return 'Immersione #$number - $site';
  }

  @override
  String get trips_gallery_empty_subtitle =>
      'Tocca l\'icona della fotocamera per scansionare la tua galleria';

  @override
  String get trips_gallery_empty_title => 'Nessuna foto in questo viaggio';

  @override
  String trips_gallery_errorLinking(Object error) {
    return 'Errore nel collegamento delle foto: $error';
  }

  @override
  String trips_gallery_errorScanning(Object error) {
    return 'Errore nella scansione: $error';
  }

  @override
  String trips_gallery_error_loading(Object error) {
    return 'Errore nel caricamento delle foto: $error';
  }

  @override
  String trips_gallery_linkedPhotos(Object count) {
    return 'Collegate $count foto';
  }

  @override
  String get trips_gallery_linkingPhotos => 'Collegamento foto in corso...';

  @override
  String get trips_gallery_tooltip_scan => 'Scansiona galleria del dispositivo';

  @override
  String get trips_gallery_tripNotFound => 'Viaggio non trovato';

  @override
  String get trips_list_button_retry => 'Riprova';

  @override
  String trips_list_countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Tra $days giorni',
      one: 'Tra 1 giorno',
      zero: 'Inizia oggi',
    );
    return '$_temp0';
  }

  @override
  String get trips_list_empty_button => 'Aggiungi il tuo primo viaggio';

  @override
  String get trips_list_empty_filtered_subtitle =>
      'Prova a modificare o cancellare i filtri';

  @override
  String get trips_list_empty_filtered_title =>
      'Nessun viaggio corrisponde ai filtri';

  @override
  String get trips_list_empty_subtitle =>
      'Crea viaggi per raggruppare le immersioni per destinazione';

  @override
  String get trips_list_empty_title => 'Nessun viaggio aggiunto ancora';

  @override
  String trips_list_error_loading(Object error) {
    return 'Errore nel caricamento dei viaggi: $error';
  }

  @override
  String get trips_list_fab_addTrip => 'Aggiungi viaggio';

  @override
  String get trips_list_filters_clearAll => 'Cancella tutti';

  @override
  String get trips_list_inProgress => 'In corso';

  @override
  String get trips_list_pastSection => 'Viaggi passati';

  @override
  String get trips_list_sort_title => 'Ordina viaggi';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count immersioni';
  }

  @override
  String get trips_list_tooltip_addTrip => 'Aggiungi viaggio';

  @override
  String get trips_list_tooltip_search => 'Cerca viaggi';

  @override
  String get trips_list_tooltip_sort => 'Ordina';

  @override
  String get trips_list_upcomingSection => 'In programma';

  @override
  String get trips_photos_empty_scanButton =>
      'Scansiona galleria del dispositivo';

  @override
  String get trips_photos_empty_title => 'Nessuna foto ancora';

  @override
  String get trips_photos_error_loading => 'Errore nel caricamento delle foto';

  @override
  String trips_photos_moreIndicator(Object count) {
    return '+$count';
  }

  @override
  String trips_photos_moreIndicator_semanticLabel(Object count) {
    return 'Altre $count foto';
  }

  @override
  String get trips_photos_sectionTitle => 'Foto';

  @override
  String get trips_photos_tooltip_scan => 'Scansiona galleria del dispositivo';

  @override
  String get trips_photos_viewAll => 'Visualizza tutte';

  @override
  String get trips_picker_clearTooltip => 'Cancella selezione';

  @override
  String get trips_picker_empty_createButton => 'Crea viaggio';

  @override
  String get trips_picker_empty_title => 'Nessun viaggio ancora';

  @override
  String trips_picker_error(Object error) {
    return 'Errore nel caricamento dei viaggi: $error';
  }

  @override
  String get trips_picker_hint => 'Tocca per selezionare un viaggio';

  @override
  String get trips_picker_newTrip => 'Nuovo viaggio';

  @override
  String get trips_picker_noSelection => 'Nessun viaggio selezionato';

  @override
  String get trips_picker_sheetTitle => 'Seleziona viaggio';

  @override
  String trips_picker_suggestedPrefix(Object name) {
    return 'Suggerito: $name';
  }

  @override
  String get trips_picker_suggestedUse => 'Usa';

  @override
  String get trips_search_empty_hint => 'Cerca per nome, località o resort';

  @override
  String get trips_search_fieldLabel => 'Cerca viaggi...';

  @override
  String trips_search_noResults(Object query) {
    return 'Nessun viaggio trovato per \"$query\"';
  }

  @override
  String get trips_search_tooltip_back => 'Indietro';

  @override
  String get trips_search_tooltip_clear => 'Cancella ricerca';

  @override
  String get trips_summary_header_subtitle =>
      'Seleziona un viaggio dalla lista per visualizzare i dettagli';

  @override
  String get trips_summary_header_title => 'Viaggi';

  @override
  String get trips_summary_overview_title => 'Panoramica';

  @override
  String get trips_summary_quickActions_add => 'Aggiungi viaggio';

  @override
  String get trips_summary_quickActions_title => 'Azioni rapide';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date • $count immersioni';
  }

  @override
  String get trips_summary_recentTitle => 'Viaggi recenti';

  @override
  String get trips_summary_stat_daysDiving => 'Giorni di immersione';

  @override
  String get trips_summary_stat_liveaboards => 'Crociere subacquee';

  @override
  String get trips_summary_stat_totalDives => 'Immersioni totali';

  @override
  String get trips_summary_stat_totalTrips => 'Viaggi totali';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date • Tra $days giorni';
  }

  @override
  String get trips_summary_upcomingTitle => 'In programma';

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
  String get units_sac_pressurePerMin => 'pressione/min';

  @override
  String get units_temperature_celsius => 'C';

  @override
  String get units_temperature_fahrenheit => 'F';

  @override
  String get units_timeFormat_twelveHour => '12 ore';

  @override
  String get units_timeFormat_twentyFourHour => '24 ore';

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
      'Consolida come computer aggiuntivo';

  @override
  String get universalImport_action_continue => 'Continua';

  @override
  String get universalImport_action_deselectAll => 'Deseleziona Tutto';

  @override
  String get universalImport_action_done => 'Fatto';

  @override
  String get universalImport_action_import => 'Importa';

  @override
  String get universalImport_action_selectAll => 'Seleziona Tutto';

  @override
  String get universalImport_action_changeFile => 'Cambia file';

  @override
  String get universalImport_action_selectFile => 'Seleziona File';

  @override
  String get universalImport_action_selectFiles => 'Seleziona file';

  @override
  String get universalImport_action_chooseFolder => 'Scegli cartella';

  @override
  String get universalImport_triage_title => 'File da importare';

  @override
  String universalImport_triage_readyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file pronti per l\'importazione',
      one: '1 file pronto per l\'importazione',
    );
    return '$_temp0';
  }

  @override
  String universalImport_label_filesSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file selezionati',
      one: '1 file selezionato',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_triage_excludedCsv =>
      'Importa singolarmente (CSV)';

  @override
  String get universalImport_triage_unsupported => 'Formato non supportato';

  @override
  String get universalImport_triage_parseFailed => 'Impossibile leggere';

  @override
  String universalImport_triage_parsing(int current, int total) {
    return 'Analisi del file $current di $total…';
  }

  @override
  String get universalImport_triage_cancelParsing => 'Annulla';

  @override
  String get universalImport_triage_allExcluded =>
      'Nessuno dei file selezionati può essere importato insieme. I file CSV devono essere importati uno alla volta.';

  @override
  String get universalImport_triage_noneImportable =>
      'Nessuno dei file selezionati può essere importato.';

  @override
  String get universalImport_review_inBatchDuplicate =>
      'Duplicato di un\'altra immersione in questo lotto di importazione.';

  @override
  String get universalImport_summary_filesTitle => 'File';

  @override
  String get universalImport_summary_noticesTitle => 'Non presente nel file';

  @override
  String get universalImport_summary_noticeNoTankPressureTitle =>
      'Pressione della bombola non registrata';

  @override
  String get universalImport_summary_noticeNoTankPressureBody =>
      'Non è possibile calcolare il consumo d\'aria e il SAC. Puoi inserire la pressione iniziale e finale modificando l\'immersione.';

  @override
  String universalImport_summary_noticeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Riguarda $count immersioni',
      one: 'Riguarda 1 immersione',
    );
    return '$_temp0';
  }

  @override
  String universalImport_summary_fileImported(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni importate',
      one: '1 immersione importata',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_summary_fileNeedsIndividualImport =>
      'Richiede importazione singola';

  @override
  String get universalImport_summary_fileUnsupported =>
      'Formato non supportato';

  @override
  String get universalImport_summary_fileParseFailed => 'Lettura non riuscita';

  @override
  String universalImport_bulk_consolidateMatched(int count) {
    return 'Consolida corrispondenti ($count)';
  }

  @override
  String universalImport_bulk_importAll(int count) {
    return 'Importa tutto ($count)';
  }

  @override
  String universalImport_bulk_importAllAsNew(int count) {
    return 'Importa tutto come nuovo ($count)';
  }

  @override
  String universalImport_bulk_skipAll(int count) {
    return 'Salta tutto ($count)';
  }

  @override
  String universalImport_bulk_replaceSourceAll(int count) {
    return 'Sostituisci tutto ($count)';
  }

  @override
  String get universalImport_description_supportedFormats =>
      'Seleziona un file di registro immersioni da importare. I formati supportati includono CSV, UDDF, Subsurface XML e Garmin FIT.';

  @override
  String get universalImport_dive_decideAction => 'Decidi';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Questo formato non è ancora supportato. Esporta come UDDF o CSV.';

  @override
  String get universalImport_label_columnMapping => 'Mappatura Colonne';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped di $total colonne mappate';
  }

  @override
  String get universalImport_label_consolidate => 'Consolida';

  @override
  String get universalImport_label_detecting => 'Rilevamento...';

  @override
  String universalImport_label_diveNumber(Object number) {
    return 'Immersione #$number';
  }

  @override
  String get universalImport_label_duplicate => 'Duplicato';

  @override
  String universalImport_label_duplicatesFound(Object count) {
    return '$count duplicati trovati e deselezionati automaticamente.';
  }

  @override
  String get universalImport_label_importAsNew => 'Importa come nuovo';

  @override
  String get universalImport_label_importComplete => 'Importazione Completata';

  @override
  String get universalImport_label_importing => 'Importazione';

  @override
  String get universalImport_label_importingEllipsis => 'Importazione...';

  @override
  String universalImport_label_importingProgress(Object current, Object total) {
    return 'Importazione $current di $total';
  }

  @override
  String universalImport_label_percentMatch(Object percent) {
    return '$percent% corrispondenza';
  }

  @override
  String get universalImport_label_possibleMatch => 'Possibile corrispondenza';

  @override
  String get universalImport_label_selectCorrectSource =>
      'Non è giusto? Seleziona la fonte corretta:';

  @override
  String universalImport_label_selected(Object count) {
    return '$count selezionati';
  }

  @override
  String get universalImport_label_skip => 'Salta';

  @override
  String universalImport_label_taggedAs(Object tag) {
    return 'Taggato come: $tag';
  }

  @override
  String get universalImport_label_unknownDate => 'Data sconosciuta';

  @override
  String get universalImport_label_unnamed => 'Senza nome';

  @override
  String universalImport_label_xOfY(Object current, Object total) {
    return '$current di $total';
  }

  @override
  String universalImport_label_xOfYSelected(Object selected, Object total) {
    return '$selected di $total selezionati';
  }

  @override
  String get universalImport_entityAction_linkBadge => 'COLLEGA';

  @override
  String get universalImport_entityAction_linkExisting =>
      'Collega all\'esistente';

  @override
  String get universalImport_entityAction_linkExistingSubtitle =>
      'Usa il record corrispondente';

  @override
  String get universalImport_entityAction_replaceBadge => 'SOSTITUISCI';

  @override
  String get universalImport_entityAction_replaceExisting =>
      'Sostituisci esistente';

  @override
  String get universalImport_entityAction_replaceExistingSubtitle =>
      'Sovrascrivi con i dati importati';

  @override
  String get universalImport_entityAction_skip => 'Salta';

  @override
  String get universalImport_entityAction_skipSubtitle =>
      'Scarta questa importazione';

  @override
  String get universalImport_entityAction_importAsNew => 'Importa come nuovo';

  @override
  String get universalImport_entityAction_importAsNewSubtitle =>
      'Crea una voce separata';

  @override
  String get universalImport_pending_chooseAction => 'Scegli un\'azione';

  @override
  String universalImport_pending_gateHint(int count) {
    return '$count duplicato/i richiedono una decisione';
  }

  @override
  String get universalImport_pending_needsDecision => 'Decisione richiesta';

  @override
  String get universalImport_pending_reviewAction => 'Rivedi';

  @override
  String get universalImport_rowHint_tapCompareToDecide =>
      'Tocca Decidi per scegliere';

  @override
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  ) {
    return '$selected di $total $entityType selezionati';
  }

  @override
  String universalImport_semantics_importError(Object error) {
    return 'Errore di importazione: $error';
  }

  @override
  String universalImport_semantics_importProgress(Object percent) {
    return 'Progresso importazione: $percent percento';
  }

  @override
  String universalImport_semantics_itemsSelected(Object count) {
    return '$count elementi selezionati per l\'importazione';
  }

  @override
  String get universalImport_semantics_needsDecision =>
      'Probabile duplicato, decisione richiesta';

  @override
  String get universalImport_semantics_possibleDuplicate =>
      'Possibile duplicato';

  @override
  String get universalImport_semantics_probableDuplicate =>
      'Probabile duplicato';

  @override
  String universalImport_semantics_sourceDetected(Object description) {
    return 'Fonte rilevata: $description';
  }

  @override
  String universalImport_semantics_sourceUncertain(Object description) {
    return 'Fonte incerta: $description';
  }

  @override
  String universalImport_semantics_toggleSelection(Object name) {
    return 'Attiva/disattiva selezione per $name';
  }

  @override
  String universalImport_snackbar_bulkMarkedAs(int count, String action) {
    return '$count contrassegnati come $action';
  }

  @override
  String universalImport_snackbar_markedAs(String action) {
    return 'Contrassegnato come $action';
  }

  @override
  String get universalImport_step_import => 'Importa';

  @override
  String get universalImport_step_map => 'Mappa';

  @override
  String get universalImport_step_review => 'Rivedi';

  @override
  String get universalImport_step_select => 'Seleziona';

  @override
  String get universalImport_summary_decidesRequired =>
      'Ognuno richiede una decisione prima dell\'importazione.';

  @override
  String get universalImport_title => 'Importa Dati';

  @override
  String get universalImport_tooltip_closeWizard =>
      'Chiudi procedura guidata importazione';

  @override
  String weather_windFromDirection(Object wind, Object direction) {
    return '$wind da $direction';
  }

  @override
  String get weather_wind_calm => 'calmo';

  @override
  String get weather_wind_highWind => 'vento forte';

  @override
  String get weather_wind_lightBreeze => 'brezza leggera';

  @override
  String get weather_wind_moderateBreeze => 'brezza moderata';

  @override
  String get weather_wind_strongBreeze => 'brezza tesa';

  @override
  String get weather_wmo_clear => 'Cielo sereno';

  @override
  String get weather_wmo_drizzle => 'Pioviggine';

  @override
  String get weather_wmo_fog => 'Nebbia';

  @override
  String get weather_wmo_freezingDrizzle => 'Pioviggine gelata';

  @override
  String get weather_wmo_freezingRain => 'Pioggia gelata';

  @override
  String get weather_wmo_mainlyClear => 'Prevalentemente sereno';

  @override
  String get weather_wmo_overcast => 'Coperto';

  @override
  String get weather_wmo_partlyCloudy => 'Parzialmente nuvoloso';

  @override
  String get weather_wmo_rain => 'Pioggia';

  @override
  String get weather_wmo_rainShowers => 'Rovesci di pioggia';

  @override
  String get weather_wmo_snow => 'Neve';

  @override
  String get weather_wmo_snowGrains => 'Granuli di neve';

  @override
  String get weather_wmo_snowShowers => 'Rovesci di neve';

  @override
  String get weather_wmo_thunderstorm => 'Temporale';

  @override
  String get weather_wmo_thunderstormHail => 'Temporale con grandine';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return 'Base ($suitType): $weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return 'Regolazione peso corporeo: +$adjustment kg';
  }

  @override
  String get weightCalc_suit_drysuit => 'Muta stagna';

  @override
  String get weightCalc_suit_none => 'Senza muta';

  @override
  String get weightCalc_suit_rashguard => 'Solo rashguard';

  @override
  String get weightCalc_suit_semidry => 'Muta semistagna';

  @override
  String get weightCalc_suit_shorty3mm => 'Shorty 3mm';

  @override
  String get weightCalc_suit_wetsuit3mm => 'Muta umida 3mm';

  @override
  String get weightCalc_suit_wetsuit5mm => 'Muta 5mm';

  @override
  String get weightCalc_suit_wetsuit7mm => 'Muta 7mm';

  @override
  String weightCalc_tankLine(Object tankMaterial, Object adjustment) {
    return 'Bombola ($tankMaterial): $adjustment kg';
  }

  @override
  String get weightCalc_title => 'Calcolo zavorra:';

  @override
  String weightCalc_total(Object total) {
    return 'Totale: $total kg';
  }

  @override
  String weightCalc_waterLine(Object waterType, Object adjustment) {
    return 'Acqua ($waterType): $adjustment kg';
  }

  @override
  String divePlanner_label_resultsWithWarnings(Object count) {
    return 'Risultati, $count avvisi';
  }

  @override
  String tides_semantic_tideCycle(Object state, Object height) {
    return 'Ciclo maree, stato: $state, altezza: $height';
  }

  @override
  String get tides_label_agoSuffix => 'fa';

  @override
  String get tides_label_fromNowSuffix => 'da ora';

  @override
  String get certifications_card_issued => 'RILASCIATO';

  @override
  String certifications_certificate_cardNumber(Object number) {
    return 'Numero tessera: $number';
  }

  @override
  String get certifications_certificate_footer =>
      'Certificazione ufficiale di immersione subacquea';

  @override
  String get certifications_certificate_hasCompletedTraining =>
      'ha completato la formazione come';

  @override
  String certifications_certificate_instructor(Object name) {
    return 'Istruttore: $name';
  }

  @override
  String certifications_certificate_issued(Object date) {
    return 'Rilasciato: $date';
  }

  @override
  String get certifications_certificate_thisCertifies => 'Si certifica che';

  @override
  String get diveComputer_connectionType_ble => 'Bluetooth LE';

  @override
  String get diveComputer_connectionType_bluetooth => 'Bluetooth';

  @override
  String get diveComputer_connectionType_infrared => 'Infrarossi';

  @override
  String get diveComputer_connectionType_unknown => 'Sconosciuto';

  @override
  String get diveComputer_connectionType_usb => 'USB';

  @override
  String get diveComputer_connectionType_wifi => 'Wi-Fi';

  @override
  String diveComputer_detail_deleteDialogContent(String name) {
    return 'Vuoi davvero rimuovere \"$name\"? Le immersioni importate da questo computer non verranno eliminate.';
  }

  @override
  String get diveComputer_detail_deleteDialogTitle => 'Eliminare il computer?';

  @override
  String get diveComputer_detail_divesImported => 'Immersioni importate';

  @override
  String get diveComputer_detail_downloadDivesButton => 'Scarica immersioni';

  @override
  String get diveComputer_detail_editDialogTitle => 'Modifica computer';

  @override
  String get diveComputer_detail_editNameHint => 'Ad esempio, Il mio Perdix';

  @override
  String get diveComputer_detail_editNotesHint => 'Note facoltative';

  @override
  String get diveComputer_detail_labelConnection => 'Connessione';

  @override
  String get diveComputer_detail_labelManufacturer => 'Produttore';

  @override
  String get diveComputer_detail_labelModel => 'Modello';

  @override
  String get diveComputer_detail_labelName => 'Nome';

  @override
  String get diveComputer_detail_lastDownload => 'Ultimo download';

  @override
  String get diveComputer_detail_notesTitle => 'Note';

  @override
  String get diveComputer_detail_reimportAllButton =>
      'Reimporta tutte le immersioni';

  @override
  String diveComputer_detail_reimportDialogBody(String computerName) {
    return 'Scarica ogni immersione da $computerName e confrontale con il tuo log. Questa operazione può richiedere diversi minuti.';
  }

  @override
  String get diveComputer_detail_reimportDialogTitle =>
      'Reimportare tutte le immersioni?';

  @override
  String get diveComputer_detail_statisticsTitle => 'Statistiche';

  @override
  String get diveComputer_detail_unknown => 'Sconosciuto';

  @override
  String get diveComputer_detail_viewDivesButton =>
      'Visualizza immersioni da questo computer';

  @override
  String get diveComputer_discovery_chooseDifferentDevice =>
      'Scegli un altro dispositivo';

  @override
  String get diveComputer_discovery_computer => 'Computer';

  @override
  String get diveComputer_discovery_connectAndDownload => 'Connetti e scarica';

  @override
  String get diveComputer_discovery_connectingToDevice =>
      'Connessione al dispositivo...';

  @override
  String diveComputer_discovery_deviceNameHint(Object model) {
    return 'es. Il mio $model';
  }

  @override
  String get diveComputer_discovery_deviceNameLabel => 'Nome dispositivo';

  @override
  String get diveComputer_discovery_exitDialogCancel => 'Annulla';

  @override
  String get diveComputer_discovery_exitDialogConfirm => 'Esci';

  @override
  String get diveComputer_discovery_exitDialogContent =>
      'Vuoi davvero uscire? I progressi andranno persi.';

  @override
  String get diveComputer_discovery_exitDialogTitle =>
      'Uscire dalla configurazione?';

  @override
  String get diveComputer_discovery_exitTooltip => 'Esci dalla configurazione';

  @override
  String get diveComputer_discovery_noDeviceSelected =>
      'Nessun dispositivo selezionato';

  @override
  String get diveComputer_discovery_pleaseWaitConnection =>
      'Attendi mentre stabiliamo la connessione';

  @override
  String get diveComputer_discovery_recognizedDevice =>
      'Dispositivo riconosciuto';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      'Questo dispositivo si trova nella nostra libreria di dispositivi supportati. Il download delle immersioni dovrebbe funzionare automaticamente.';

  @override
  String get diveComputer_discovery_stepConnect => 'Connetti';

  @override
  String get diveComputer_discovery_stepDone => 'Fatto';

  @override
  String get diveComputer_discovery_stepDownload => 'Scarica';

  @override
  String get diveComputer_discovery_stepScan => 'Scansione';

  @override
  String get diveComputer_discovery_titleComplete => 'Completato';

  @override
  String get diveComputer_discovery_titleConfirmDevice =>
      'Conferma dispositivo';

  @override
  String get diveComputer_discovery_titleConnecting => 'Connessione';

  @override
  String get diveComputer_discovery_titleDownloading => 'Download in corso';

  @override
  String get diveComputer_discovery_titleFindDevice => 'Cerca dispositivo';

  @override
  String get diveComputer_discovery_unknownDevice => 'Dispositivo sconosciuto';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      'Questo dispositivo non si trova nella nostra libreria. Tenteremo la connessione, ma il download potrebbe non funzionare.';

  @override
  String get diveComputer_discovery_usbInstructions =>
      'Collega il tuo computer subacqueo tramite cavo USB, quindi selezionalo qui sotto.';

  @override
  String diveComputer_discovery_usbNoResults(String query) {
    return 'Nessun dispositivo corrispondente a \"$query\"';
  }

  @override
  String get diveComputer_discovery_usbSearchHint =>
      'Cerca per produttore o modello...';

  @override
  String get diveComputer_downloadExit_content =>
      'Uscendo verra annullato il download in corso dal computer da sub. Sei sicuro?';

  @override
  String get diveComputer_downloadExit_leave => 'Esci';

  @override
  String get diveComputer_downloadExit_stay => 'Rimani';

  @override
  String get diveComputer_downloadExit_title => 'Download in corso';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... e altre $count';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Annulla';

  @override
  String get diveComputer_downloadStep_cancelled => 'Download annullato';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadAll =>
      'Scarica tutte le immersioni';

  @override
  String get diveComputer_downloadStep_downloadFailed => 'Download fallito';

  @override
  String get diveComputer_downloadStep_downloadNew =>
      'Scarica le nuove immersioni';

  @override
  String get diveComputer_downloadStep_downloadedDives =>
      'Immersioni scaricate';

  @override
  String diveComputer_downloadStep_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_downloadStep_errorOccurred =>
      'Si è verificato un errore';

  @override
  String diveComputer_downloadStep_errorSemanticLabel(Object error) {
    return 'Errore di download: $error';
  }

  @override
  String get diveComputer_downloadStep_firstSyncBody =>
      'Il tuo diario ha già delle immersioni. Puoi saltare il download delle immersioni che hai già.';

  @override
  String get diveComputer_downloadStep_firstSyncTitle =>
      'Primo download da questo computer subacqueo';

  @override
  String diveComputer_downloadStep_onlyAfterDate(String date) {
    return 'Scarica solo le immersioni dopo il $date';
  }

  @override
  String diveComputer_downloadStep_percentAccessibility(Object percent) {
    return ', $percent percento';
  }

  @override
  String get diveComputer_downloadStep_preparing => 'Preparazione...';

  @override
  String diveComputer_downloadStep_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String diveComputer_downloadStep_progressSemanticLabel(
    Object status,
    Object percent,
  ) {
    return 'Avanzamento download: $status$percent';
  }

  @override
  String get diveComputer_downloadStep_retry => 'Riprova';

  @override
  String diveComputer_downloadStep_importPartialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importa $count immersioni scaricate',
      one: 'Importa 1 immersione scaricata',
    );
    return '$_temp0';
  }

  @override
  String get diveComputer_download_cancel => 'Annulla';

  @override
  String get diveComputer_download_closeTooltip => 'Chiudi';

  @override
  String get diveComputer_download_computerNotFound => 'Computer non trovato';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return 'Dispositivo non trovato. Assicurati che il tuo $name sia vicino e in modalità trasferimento.';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle =>
      'Dispositivo non trovato';

  @override
  String get diveComputer_download_divesUpdated => 'Immersioni aggiornate';

  @override
  String get diveComputer_download_done => 'Fatto';

  @override
  String get diveComputer_download_downloadedDives => 'Immersioni scaricate';

  @override
  String get diveComputer_download_duplicatesSkipped => 'Duplicati saltati';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_download_errorOccurred => 'Si è verificato un errore';

  @override
  String get diveComputer_download_noSerialPortsFound =>
      'Nessuna porta seriale USB trovata. Il computer subacqueo è collegato e acceso?';

  @override
  String get diveComputer_download_stalePairing =>
      'L\'associazione Bluetooth di questo computer subacqueo non è più valida. Dimentica il computer subacqueo nelle impostazioni Bluetooth del tuo dispositivo, quindi associalo di nuovo dal menu Bluetooth del computer subacqueo.';

  @override
  String get diveComputer_download_discoveryStalled =>
      'Connessione al computer subacqueo riuscita, ma ha smesso di rispondere prima dell\'avvio del download. Di solito significa che l\'associazione Bluetooth non è più valida: dimentica il computer subacqueo nelle impostazioni Bluetooth del tuo dispositivo e riprova.';

  @override
  String diveComputer_download_serialConnectFailedWithDetails(Object details) {
    return 'Impossibile connettersi al computer subacqueo.\n\nDettagli diagnostici (da condividere con gli sviluppatori):\n$details';
  }

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return 'Errore: $error';
  }

  @override
  String get diveComputer_download_goBack => 'Torna indietro';

  @override
  String get diveComputer_download_importFailed => 'Importazione fallita';

  @override
  String get diveComputer_download_importResults => 'Risultati importazione';

  @override
  String get diveComputer_download_importedDives => 'Immersioni importate';

  @override
  String diveComputer_download_importingCountDives(int count) {
    return 'Importazione di $count immersioni...';
  }

  @override
  String diveComputer_download_importingCountNewDives(int count) {
    return 'Importazione di $count nuove immersioni...';
  }

  @override
  String get diveComputer_download_newDivesImported =>
      'Nuove immersioni importate';

  @override
  String get diveComputer_download_newDivesOnlySubtitle =>
      'Scarica solo le immersioni aggiunte dall\'ultima sincronizzazione';

  @override
  String get diveComputer_download_newDivesOnlyTitle =>
      'Scarica solo le nuove immersioni';

  @override
  String get diveComputer_download_preparing => 'Preparazione...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_reimportHint =>
      'Cerchi immersioni vecchie o eliminate? Reimportale tutte';

  @override
  String get diveComputer_download_retry => 'Riprova';

  @override
  String diveComputer_download_scanError(Object error) {
    return 'Errore scansione: $error';
  }

  @override
  String diveComputer_download_searchingForDevice(Object name) {
    return 'Ricerca di $name...';
  }

  @override
  String get diveComputer_download_searchingInstructions =>
      'Assicurati che il dispositivo sia vicino e in modalità trasferimento';

  @override
  String get diveComputer_download_title => 'Scarica immersioni';

  @override
  String get diveComputer_download_tryAgain => 'Riprova';

  @override
  String get diveComputer_download_upToDate =>
      'Nessuna nuova immersione trovata -- il tuo registro è aggiornato';

  @override
  String get diveComputer_list_addComputer => 'Aggiungi computer';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return 'Computer subacqueo: $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count immersioni';
  }

  @override
  String get diveComputer_list_downloadTooltip => 'Scarica immersioni';

  @override
  String get diveComputer_list_emptyMessage =>
      'Collega il tuo computer subacqueo per scaricare le immersioni direttamente nell\'app.';

  @override
  String get diveComputer_list_emptyTitle => 'Nessun computer subacqueo';

  @override
  String get diveComputer_list_findComputers => 'Cerca computer';

  @override
  String get diveComputer_list_helpBluetooth =>
      '• Bluetooth LE (computer moderni)';

  @override
  String get diveComputer_list_helpBluetoothClassic =>
      '• Bluetooth Classic (modelli precedenti)';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi e oltre 50 modelli.';

  @override
  String get diveComputer_list_helpBrandsTitle => 'Marchi supportati';

  @override
  String get diveComputer_list_helpConnectionsTitle => 'Connessioni supportate';

  @override
  String get diveComputer_list_helpDialogTitle => 'Guida computer subacqueo';

  @override
  String get diveComputer_list_helpDismiss => 'Capito';

  @override
  String get diveComputer_list_helpTip1 =>
      '• Assicurati che il computer sia in modalità trasferimento';

  @override
  String get diveComputer_list_helpTip2 =>
      '• Tieni i dispositivi vicini durante il download';

  @override
  String get diveComputer_list_helpTip3 =>
      '• Assicurati che il Bluetooth sia attivo';

  @override
  String get diveComputer_list_helpTipsTitle => 'Suggerimenti';

  @override
  String get diveComputer_list_helpTooltip => 'Aiuto';

  @override
  String get diveComputer_list_helpUsb => '• USB (solo desktop)';

  @override
  String get diveComputer_list_loadFailed =>
      'Caricamento computer subacquei fallito';

  @override
  String get diveComputer_list_retry => 'Riprova';

  @override
  String get diveComputer_list_title => 'Computer subacquei';

  @override
  String get diveComputer_pinCode_instructions =>
      'Inserisci il codice mostrato sul tuo computer da sub.';

  @override
  String get diveComputer_pinCode_label => 'Codice PIN';

  @override
  String get diveComputer_pinCode_submit => 'Invia';

  @override
  String get diveComputer_pinCode_title => 'Codice PIN richiesto';

  @override
  String get diveComputer_pinEntry_connectButton => 'Connetti';

  @override
  String get diveComputer_pinEntry_helperText =>
      'Inserisci il PIN di 4-6 cifre mostrato sul tuo dispositivo';

  @override
  String get diveComputer_pinEntry_instructionsGeneric =>
      'Controlla il display del tuo computer da sub per il codice PIN.';

  @override
  String diveComputer_pinEntry_instructionsWithDevice(String deviceName) {
    return 'Controlla il display del tuo $deviceName per il codice PIN.';
  }

  @override
  String get diveComputer_pinEntry_semanticLabel =>
      'Inserimento codice PIN, da 4 a 6 cifre';

  @override
  String get diveComputer_pinEntry_title => 'Inserisci codice PIN';

  @override
  String diveComputer_scan_bluetoothSemanticLabel(String name) {
    return 'Dispositivo Bluetooth: $name';
  }

  @override
  String get diveComputer_scan_emptyStateInstructions =>
      'Assicurati che il tuo computer da sub sia:\n• Acceso\n• In modalita di abbinamento Bluetooth\n• Vicino al tuo dispositivo';

  @override
  String get diveComputer_scan_knownBadge => 'Conosciuto';

  @override
  String get diveComputer_scan_lookingForDevicesTitle => 'Ricerca dispositivi';

  @override
  String get diveComputer_scan_noUsbDevicesAvailable =>
      'Nessun dispositivo USB disponibile';

  @override
  String get diveComputer_scan_retry => 'Riprova';

  @override
  String get diveComputer_scan_scanAgain => 'Ricerca di nuovo';

  @override
  String get diveComputer_scan_scanningStatus =>
      'Ricerca di computer da sub...';

  @override
  String get diveComputer_scan_stopScanning => 'Interrompi ricerca';

  @override
  String get diveComputer_scan_supportedBadge => 'Supportato';

  @override
  String get diveComputer_scan_tabBluetooth => 'Bluetooth';

  @override
  String get diveComputer_scan_tabUsb => 'Cavo USB';

  @override
  String get diveComputer_scan_usbCableLabel => 'Cavo USB';

  @override
  String diveComputer_scan_usbSemanticLabel(String model) {
    return 'Dispositivo USB: $model';
  }

  @override
  String get diveComputer_summary_diveComputer => 'computer subacqueo';

  @override
  String diveComputer_summary_divesDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni scaricate',
      one: 'immersione scaricata',
    );
    return '$count $_temp0';
  }

  @override
  String get diveComputer_summary_done => 'Fatto';

  @override
  String get diveComputer_summary_imported => 'Importate';

  @override
  String diveComputer_summary_semanticLabel(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni scaricate',
      one: 'immersione scaricata',
    );
    return '$count $_temp0 da $name';
  }

  @override
  String get diveComputer_summary_skippedDuplicates => 'Saltate (duplicati)';

  @override
  String get diveComputer_summary_title => 'Download completato!';

  @override
  String get diveComputer_summary_updated => 'Aggiornate';

  @override
  String get diveComputer_summary_viewDives => 'Visualizza immersioni';

  @override
  String get diveImport_alreadyImported => 'Già importata';

  @override
  String get diveImport_avgHR => 'FC media';

  @override
  String get diveImport_back => 'Indietro';

  @override
  String get diveImport_deselectAll => 'Deseleziona tutto';

  @override
  String get diveImport_divesImported => 'Immersioni importate';

  @override
  String get diveImport_divesMerged => 'Immersioni unite';

  @override
  String get diveImport_divesSkipped => 'Immersioni saltate';

  @override
  String get diveImport_done => 'Fatto';

  @override
  String get diveImport_duration => 'Durata';

  @override
  String get diveImport_error => 'Errore';

  @override
  String get diveImport_fit_closeTooltip => 'Chiudi importazione FIT';

  @override
  String get diveImport_fit_noDivesDescription =>
      'Seleziona uno o più file .fit esportati da Garmin Connect o copiati da un dispositivo Garmin Descent.';

  @override
  String get diveImport_fit_noDivesLoaded => 'Nessuna immersione caricata';

  @override
  String diveImport_fit_parsed(int diveCount, int fileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'immersioni',
      one: 'immersione',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'file',
      one: 'file',
    );
    return 'Analizzate $diveCount $_temp0 da $fileCount $_temp1';
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
      other: 'immersioni',
      one: 'immersione',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'file',
      one: 'file',
    );
    return 'Analizzate $diveCount $_temp0 da $fileCount $_temp1 ($skippedCount saltate)';
  }

  @override
  String get diveImport_fit_parsing => 'Analisi in corso...';

  @override
  String get diveImport_fit_selectFiles => 'Seleziona file FIT';

  @override
  String get diveImport_fit_title => 'Importa da file FIT';

  @override
  String get diveImport_healthkit_accessDescription =>
      'Submersion uses Apple HealthKit to read underwater diving workout data, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get diveImport_healthkit_accessRequired => 'Apple HealthKit';

  @override
  String get diveImport_healthkit_attribution => 'Fornito da Apple HealthKit';

  @override
  String get diveImport_healthkit_closeTooltip =>
      'Chiudi importazione Apple Watch';

  @override
  String get diveImport_healthkit_dataUsage =>
      'Legge le attivita di immersione subacquea da Apple Health, inclusi profondita, durata, temperatura dell\'acqua e frequenza cardiaca. Questi dati vengono archiviati localmente nel tuo registro immersioni e non vengono mai condivisi con terze parti.';

  @override
  String get diveImport_healthkit_dateFrom => 'Da';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return 'Selettore data $label';
  }

  @override
  String get diveImport_healthkit_dateTo => 'A';

  @override
  String get diveImport_healthkit_fetchDives => 'Recupera immersioni';

  @override
  String get diveImport_healthkit_fetching => 'Recupero in corso...';

  @override
  String get diveImport_healthkit_grantAccess => 'Continua';

  @override
  String get diveImport_healthkit_noDivesFound => 'Nessuna immersione trovata';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'Nessuna attività subacquea trovata nell\'intervallo di date selezionato.';

  @override
  String get diveImport_healthkit_notAvailable => 'Non disponibile';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'L\'importazione da Apple Watch richiede un iPhone con l\'app Salute.';

  @override
  String get diveImport_healthkit_permissionCheckFailed =>
      'Verifica dei permessi fallita';

  @override
  String get diveImport_healthkit_title => 'Importa da Apple Watch';

  @override
  String get diveImport_healthkit_watchTitle => 'Importa da Watch';

  @override
  String get diveImport_import => 'Importa';

  @override
  String get diveImport_importComplete => 'Importazione completata';

  @override
  String get diveImport_likelyDuplicate => 'Probabile duplicato';

  @override
  String get diveImport_maxDepth => 'Prof. max';

  @override
  String get diveImport_newDive => 'Nuova immersione';

  @override
  String get diveImport_next => 'Avanti';

  @override
  String get diveImport_possibleDuplicate => 'Possibile duplicato';

  @override
  String get diveImport_reviewSelectedDives =>
      'Revisiona immersioni selezionate';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: ', $possibleCount possibili duplicati',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: ', $skipCount saranno saltate',
      zero: '',
    );
    return '$newCount nuove$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => 'Seleziona tutto';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count selezionate';
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
  String get diveImport_step_done => 'Fatto';

  @override
  String get diveImport_step_review => 'Revisione';

  @override
  String get diveImport_step_select => 'Selezione';

  @override
  String get diveImport_temp => 'Temp';

  @override
  String get diveImport_toggleDiveSelection =>
      'Seleziona/deseleziona immersione';

  @override
  String get diveImport_uddf_buddies => 'Compagni';

  @override
  String get diveImport_uddf_certifications => 'Certificazioni';

  @override
  String get diveImport_uddf_closeTooltip => 'Chiudi importazione UDDF';

  @override
  String get diveImport_uddf_diveCenters => 'Centri immersione';

  @override
  String get diveImport_uddf_diveTypes => 'Tipi di immersione';

  @override
  String get diveImport_uddf_dives => 'Immersioni';

  @override
  String get diveImport_uddf_duplicate => 'Duplicato';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return '$count duplicati trovati e deselezionati automaticamente.';
  }

  @override
  String get diveImport_uddf_equipment => 'Attrezzatura';

  @override
  String get diveImport_uddf_equipmentSets => 'Kit attrezzatura';

  @override
  String diveImport_uddf_importProgress(Object current, Object total) {
    return '$current di $total';
  }

  @override
  String get diveImport_uddf_importing => 'Importazione...';

  @override
  String get diveImport_uddf_likelyDuplicate => 'Probabile duplicato';

  @override
  String get diveImport_uddf_noFileDescription =>
      'Seleziona un file .uddf o .xml esportato da un\'altra applicazione di logbook.';

  @override
  String get diveImport_uddf_noFileSelected => 'Nessun file selezionato';

  @override
  String get diveImport_uddf_parsing => 'Analisi in corso...';

  @override
  String get diveImport_uddf_possibleDuplicate => 'Possibile duplicato';

  @override
  String get diveImport_uddf_selectFile => 'Seleziona file UDDF';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '$selected di $total selezionate';
  }

  @override
  String get diveImport_uddf_sites => 'Siti';

  @override
  String get diveImport_uddf_stepImport => 'Importa';

  @override
  String get diveImport_uddf_tabBuddies => 'Compagni';

  @override
  String get diveImport_uddf_tabCenters => 'Centri';

  @override
  String get diveImport_uddf_tabCerts => 'Brevetti';

  @override
  String get diveImport_uddf_tabCourses => 'Corsi';

  @override
  String get diveImport_uddf_tabDives => 'Immersioni';

  @override
  String get diveImport_uddf_tabEquipment => 'Attrezzatura';

  @override
  String get diveImport_uddf_tabSets => 'Kit';

  @override
  String get diveImport_uddf_tabSites => 'Siti';

  @override
  String get diveImport_uddf_tabTags => 'Tag';

  @override
  String get diveImport_uddf_tabTrips => 'Viaggi';

  @override
  String get diveImport_uddf_tabTypes => 'Tipi';

  @override
  String get diveImport_uddf_tags => 'Tag';

  @override
  String get diveImport_uddf_media => 'Foto';

  @override
  String get diveImport_uddf_title => 'Importa da UDDF';

  @override
  String get diveImport_uddf_toggleDiveSelection =>
      'Seleziona/deseleziona immersione';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return 'Seleziona/deseleziona $name';
  }

  @override
  String get diveImport_uddf_trips => 'Viaggi';

  @override
  String get divePlanner_segmentEditor_addTitle => 'Aggiungi segmento';

  @override
  String divePlanner_segmentEditor_ascentRate(Object unit) {
    return 'Velocità di risalita ($unit/min)';
  }

  @override
  String divePlanner_segmentEditor_descentRate(Object unit) {
    return 'Velocità di discesa ($unit/min)';
  }

  @override
  String get divePlanner_segmentEditor_duration => 'Durata (min)';

  @override
  String get divePlanner_segmentEditor_editTitle => 'Modifica segmento';

  @override
  String divePlanner_segmentEditor_endDepth(Object unit) {
    return 'Profondità finale ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_gasSwitchTime => 'Tempo cambio gas';

  @override
  String get divePlanner_segmentEditor_segmentType => 'Tipo di segmento';

  @override
  String divePlanner_segmentEditor_startDepth(Object unit) {
    return 'Profondità iniziale ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_tankGas => 'Bombola / Gas';

  @override
  String get divePlanner_segmentList_addSegment => 'Aggiungi segmento';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return 'Risalita $startDepth → $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return 'Fondo $depth per $minutes min';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return 'Deco $depth per $minutes min';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => 'Elimina segmento';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return 'Discesa $startDepth → $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => 'Modifica segmento';

  @override
  String get divePlanner_segmentList_emptyMessage =>
      'Aggiungi segmenti manualmente o crea un piano rapido';

  @override
  String get divePlanner_segmentList_emptyTitle => 'Nessun segmento';

  @override
  String divePlanner_segmentList_gasSwitch(Object gasName) {
    return 'Cambio gas a $gasName';
  }

  @override
  String get divePlanner_segmentList_quickPlan => 'Piano rapido';

  @override
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes) {
    return 'Tappa di sicurezza $depth per $minutes min';
  }

  @override
  String get divePlanner_segmentList_title => 'Segmenti immersione';

  @override
  String get divePlanner_segmentType_ascent => 'Risalita';

  @override
  String get divePlanner_segmentType_bottomTime => 'Tempo di fondo';

  @override
  String get divePlanner_segmentType_decoStop => 'Tappa deco';

  @override
  String get divePlanner_segmentType_descent => 'Discesa';

  @override
  String get divePlanner_segmentType_gasSwitch => 'Cambio gas';

  @override
  String get divePlanner_segmentType_safetyStop => 'Tappa di sicurezza';

  @override
  String get divePlanner_undo => 'Annulla';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'Il rock bottom è la riserva minima di gas per una risalita di emergenza condividendo l\'aria con il compagno.\n\n• Usa consumi RMV da stress (2-3x il normale)\n• Presuppone entrambi i subacquei su una bombola\n• Include la tappa di sicurezza se abilitata\n\nInverti sempre l\'immersione PRIMA di raggiungere il rock bottom!';

  @override
  String get gasCalculators_rockBottom_aboutTitle =>
      'Informazioni sul Rock Bottom';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired =>
      'Gas richiesto per la risalita';

  @override
  String get gasCalculators_rockBottom_ascentRate => 'Velocità di risalita';

  @override
  String gasCalculators_rockBottom_ascentTimeToDepth(
    Object depth,
    Object unit,
  ) {
    return 'Tempo di risalita a $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_ascentTimeToSurface =>
      'Tempo di risalita in superficie';

  @override
  String get gasCalculators_rockBottom_buddySac => 'RMV compagno';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'RMV combinato sotto stress';

  @override
  String get gasCalculators_rockBottom_emergencyAscentBreakdown =>
      'Dettaglio risalita di emergenza';

  @override
  String get gasCalculators_rockBottom_emergencyScenario =>
      'Scenario di emergenza';

  @override
  String get gasCalculators_rockBottom_includeSafetyStop =>
      'Includi tappa di sicurezza';

  @override
  String get gasCalculators_rockBottom_maximumDepth => 'Profondità massima';

  @override
  String get gasCalculators_rockBottom_minimumReserve => 'Riserva minima';

  @override
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  ) {
    return 'Riserva minima: $pressure $pressureUnit, $volume $volumeUnit. Inverti l\'immersione al raggiungimento di $pressure $pressureUnit rimanenti';
  }

  @override
  String gasCalculators_rockBottom_safetyStopDuration(
    Object depth,
    Object unit,
  ) {
    return '3 minuti a $depth$unit';
  }

  @override
  String gasCalculators_rockBottom_safetyStopGas(Object depth, Object unit) {
    return 'Gas tappa di sicurezza (3 min @ $depth$unit)';
  }

  @override
  String get gasCalculators_rockBottom_stressedSacHint =>
      'Usa un RMV più alto per tenere conto dello stress durante l\'emergenza';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'RMV sotto stress';

  @override
  String get gasCalculators_rockBottom_tankSize => 'Dimensione bombola';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded =>
      'Riserva totale necessaria';

  @override
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  ) {
    return 'Inverti l\'immersione al raggiungimento di $pressure $pressureUnit rimanenti';
  }

  @override
  String get gasCalculators_rockBottom_yourSac => 'Il tuo RMV';

  @override
  String get gpsLogger_androidNotificationText =>
      'Registrazione della traccia di superficie';

  @override
  String get gpsLogger_androidNotificationTitle =>
      'Registratore GPS Submersion';

  @override
  String get gpsLogger_deleteTrackMessage =>
      'Rimuove la traccia GPS registrata. Le posizioni già assegnate alle immersioni vengono mantenute.';

  @override
  String get gpsLogger_deleteTrackTitle => 'Eliminare la traccia?';

  @override
  String get gpsLogger_interruptedNotice =>
      'Una registrazione precedente è stata interrotta. La traccia è stata salvata.';

  @override
  String gpsLogger_lastFix(String age, String accuracy) {
    return 'Ultima posizione $age fa ($accuracy)';
  }

  @override
  String get gpsLogger_locationOff =>
      'I servizi di localizzazione sono disattivati.';

  @override
  String get gpsLogger_matchButton => 'Abbina le immersioni ai registri GPS';

  @override
  String gpsLogger_matchResult(int count) {
    return '$count immersioni posizionate';
  }

  @override
  String get gpsLogger_matchResultNone =>
      'Nessuna immersione corrisponde a una traccia registrata';

  @override
  String get gpsLogger_noFixYet => 'In attesa del segnale GPS';

  @override
  String get gpsLogger_noTracks => 'Nessuna traccia GPS registrata';

  @override
  String get gpsLogger_permissionDenied =>
      'Per registrare una traccia GPS è necessaria l\'autorizzazione alla localizzazione. Attivala nelle impostazioni di sistema.';

  @override
  String gpsLogger_recordingStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punti',
      one: '$count punto',
    );
    return 'Registrazione - $_temp0';
  }

  @override
  String get gpsLogger_reviewSites => 'Rivedi le corrispondenze dei siti';

  @override
  String get gpsLogger_startButton => 'Avvia registrazione';

  @override
  String get gpsLogger_stopButton => 'Interrompi registrazione';

  @override
  String gpsLogger_stripStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punti',
      one: '$count punto',
    );
    return 'Registrazione traccia GPS · $_temp0';
  }

  @override
  String get gpsLogger_summary_tracks => 'Tracce';

  @override
  String get gpsLogger_summary_recordedTime => 'Tempo registrato';

  @override
  String get gpsLogger_summary_divesCovered => 'Immersioni coperte';

  @override
  String gpsLogger_trackSubtitle(num count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punti',
      one: '$count punto',
    );
    return '$_temp0, $duration';
  }

  @override
  String gpsLogger_trackSubtitleTrimmed(String duration) {
    return 'Ritagliata, $duration';
  }

  @override
  String get gpsLogger_tracksHeader => 'Tracce registrate';

  @override
  String get gpsTrack_action_trim => 'Ritaglia...';

  @override
  String get gpsTrack_action_split => 'Dividi...';

  @override
  String get gpsTrack_action_resetTrim => 'Annulla ritaglio';

  @override
  String get gpsTrack_edit_applyTrim => 'Applica ritaglio';

  @override
  String get gpsTrack_edit_confirmSplit => 'Dividi qui';

  @override
  String get gpsTrack_edit_splitWarning =>
      'La divisione crea due tracce e rimuove l\'originale. Non è reversibile.';

  @override
  String get gpsTrack_edit_cancel => 'Annulla';

  @override
  String get gpsTrack_import_action => 'Importa traccia...';

  @override
  String get gpsTrack_import_reviewTitle => 'Verifica importazione';

  @override
  String get gpsTrack_import_timezone => 'Registrata in';

  @override
  String get gpsTrack_import_timezoneHint =>
      'Gli orari nel file sono UTC. Imposta il fuso in cui è stata registrata la traccia perché coincida con le tue immersioni.';

  @override
  String get gpsTrack_import_duplicate =>
      'Sembra un duplicato di una traccia esistente.';

  @override
  String get gpsTrack_import_confirm => 'Importa';

  @override
  String get gpsTrack_import_csvMapping => 'Abbina le colonne';

  @override
  String get gpsTrack_import_firstFix => 'Primo punto';

  @override
  String gpsTrack_import_fixCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punti',
      one: '1 punto',
    );
    return '$_temp0';
  }

  @override
  String gpsTrack_import_failed(String reason) {
    return 'Impossibile leggere il file: $reason';
  }

  @override
  String get gpsTrack_importError_unsupportedFormat =>
      'Questo tipo di file non è supportato. Importa un file GPX, KML, CSV o FIT.';

  @override
  String get gpsTrack_importError_unreadable =>
      'Impossibile leggere il file. Potrebbe essere danneggiato o incompleto.';

  @override
  String get gpsTrack_importError_noPositions =>
      'Il file non contiene posizioni GPS con marca temporale.';

  @override
  String get gpsTrack_importError_badData =>
      'Il file contiene una posizione o una marca temporale che l\'app non riesce a leggere.';

  @override
  String get gpsTrack_export_saved => 'Traccia salvata';

  @override
  String get gpsTrack_action_export => 'Esporta';

  @override
  String get gpsTrack_action_shareGpx => 'Condividi come GPX';

  @override
  String get gpsTrack_action_saveGpx => 'Salva come GPX...';

  @override
  String get gpsTrack_action_shareKml => 'Condividi come KML';

  @override
  String get gpsTrack_action_saveKml => 'Salva come KML...';

  @override
  String get gpsTrack_export_failed => 'Esportazione non riuscita.';

  @override
  String get gpsTrack_map_title => 'Mappa tracce';

  @override
  String gpsTrack_map_truncated(int count) {
    return 'Vengono mostrate le $count tracce più recenti. Restringi il filtro per data per vedere le altre.';
  }

  @override
  String get gpsTrack_map_noTracks => 'Nessuna traccia registrata da mostrare.';

  @override
  String get gpsTrack_map_showMap => 'Mostra mappa';

  @override
  String get gpsTrack_filter_all => 'Tutte le date';

  @override
  String get gpsTrack_filter_clear => 'Rimuovi filtro date';

  @override
  String get gpsTrack_inspect_speed => 'Velocità';

  @override
  String get gpsTrack_inspect_accuracy => 'Precisione';

  @override
  String get gpsTrack_stats_distance => 'Distanza';

  @override
  String get gpsTrack_stats_duration => 'Durata';

  @override
  String get gpsTrack_stats_avgSpeed => 'Vel. media';

  @override
  String get gpsTrack_stats_maxSpeed => 'Vel. max';

  @override
  String get gpsTrack_stats_fixes => 'Punti';

  @override
  String get gpsTrack_stats_dives => 'Immersioni';

  @override
  String get gpsTrack_colorMode_uniform => 'Tinta unita';

  @override
  String get gpsTrack_colorMode_speed => 'Velocità';

  @override
  String get gpsTrack_colorMode_elapsed => 'Tempo';

  @override
  String get gpsTrack_legend_slower => 'Più lento';

  @override
  String get gpsTrack_legend_faster => 'Più veloce';

  @override
  String get gpsTrack_legend_start => 'Inizio';

  @override
  String get gpsTrack_legend_end => 'Fine';

  @override
  String get gpsTrack_detail_title => 'Traccia GPS';

  @override
  String get gpsTrack_detail_notFound =>
      'Questa traccia non è più disponibile.';

  @override
  String get gpsTrack_detail_unreadable =>
      'Impossibile leggere i dati della traccia.';

  @override
  String get gpsTrack_detail_noPoints =>
      'Questa traccia non contiene posizioni registrate.';

  @override
  String get maps_compass_resetLabel =>
      'Reimposta l\'orientamento della mappa a nord';

  @override
  String get maps_compass_resetTooltip => 'Nord in alto';

  @override
  String get maps_heatMap_hide => 'Nascondi mappa termica';

  @override
  String get maps_heatMap_overlayOff =>
      'Sovrapposizione mappa termica disattivata';

  @override
  String get maps_depthOverlay_show => 'Mostra sovrapposizione di profondità';

  @override
  String get maps_depthOverlay_hide => 'Nascondi sovrapposizione di profondità';

  @override
  String get maps_heatMap_overlayOn => 'Sovrapposizione mappa termica attivata';

  @override
  String get maps_heatMap_show => 'Mostra mappa termica';

  @override
  String get maps_offline_bounds => 'Limiti';

  @override
  String maps_offline_cacheHitRateAccessibility(Object rate) {
    return 'Percentuale di successo cache: $rate percento';
  }

  @override
  String get maps_offline_cacheHits => 'Successi cache';

  @override
  String get maps_offline_cacheMisses => 'Errori cache';

  @override
  String get maps_offline_cacheStatistics => 'Statistiche cache';

  @override
  String get maps_offline_cancelDownload => 'Annulla download';

  @override
  String get maps_offline_clearAll => 'Cancella tutto';

  @override
  String get maps_offline_clearAllCache => 'Cancella tutta la cache';

  @override
  String get maps_offline_clearAllCacheMessage =>
      'Eliminare tutte le regioni scaricate e i tile nella cache?';

  @override
  String get maps_offline_clearAllCacheTitle => 'Cancellare tutta la cache?';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return 'Verranno eliminati $count tile ($size).';
  }

  @override
  String get maps_offline_created => 'Creata';

  @override
  String maps_offline_deleteRegion(Object name) {
    return 'Elimina regione $name';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return 'Eliminare \"$name\" e i suoi $count tile nella cache?\n\nQuesto libererà $size di spazio.';
  }

  @override
  String get maps_offline_deleteRegionTitle => 'Eliminare la regione?';

  @override
  String get maps_offline_downloadNewRegion => 'Scarica nuova regione';

  @override
  String get maps_offline_downloadedRegions => 'Regioni scaricate';

  @override
  String maps_offline_downloading(Object regionName) {
    return 'Download: $regionName';
  }

  @override
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  ) {
    return 'Download di $regionName, $percent percento completato, $downloaded di $total tile';
  }

  @override
  String maps_offline_error(Object error) {
    return 'Errore: $error';
  }

  @override
  String maps_offline_errorLoadingStats(Object error) {
    return 'Errore caricamento statistiche: $error';
  }

  @override
  String maps_offline_failedTiles(Object count) {
    return '$count falliti';
  }

  @override
  String maps_offline_hitRate(Object rate) {
    return 'Percentuale successi: $rate%';
  }

  @override
  String get maps_offline_lastAccessed => 'Ultimo accesso';

  @override
  String get maps_offline_noRegions => 'Nessuna regione offline';

  @override
  String get maps_offline_noRegionsDescription =>
      'Scarica le regioni della mappa dalla pagina dettaglio sito per usare le mappe offline.';

  @override
  String get maps_offline_refresh => 'Aggiorna';

  @override
  String get maps_offline_region => 'Regione';

  @override
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size | $count tile | Zoom $minZoom-$maxZoom';
  }

  @override
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size, $count tile, zoom da $minZoom a $maxZoom';
  }

  @override
  String get maps_offline_size => 'Dimensione';

  @override
  String get maps_offline_tiles => 'Tile';

  @override
  String maps_offline_tilesPerSecond(Object rate) {
    return '$rate tile/sec';
  }

  @override
  String maps_offline_tilesProgress(Object downloaded, Object total) {
    return '$downloaded / $total tile';
  }

  @override
  String get maps_offline_title => 'Mappe offline';

  @override
  String get maps_offline_zoomRange => 'Intervallo zoom';

  @override
  String get maps_regionSelector_dragToAdjust =>
      'Trascina per regolare la selezione';

  @override
  String get maps_regionSelector_dragToSelect =>
      'Trascina sulla mappa per selezionare una regione';

  @override
  String get maps_regionSelector_selectRegion =>
      'Seleziona regione sulla mappa';

  @override
  String get maps_regionSelector_selectRegionButton => 'Seleziona regione';

  @override
  String get tankPresets_addPreset => 'Aggiungi preset bombola';

  @override
  String get tankPresets_builtInPresets => 'Preset predefiniti';

  @override
  String get tankPresets_currentDefault => 'Predefinito attuale';

  @override
  String get tankPresets_customPresets => 'Preset personalizzati';

  @override
  String get tankPresets_defaultSettings => 'Bombola predefinita';

  @override
  String get tankPresets_defaultSettings_description =>
      'Il preset contrassegnato con la stella viene usato come bombola predefinita quando si registrano nuove immersioni.';

  @override
  String tankPresets_deleteDefaultMessage(String name) {
    return 'Sei sicuro di voler eliminare \"$name\"? Questo è il tuo preset bombola predefinito attuale e verrà reimpostato su AL80.';
  }

  @override
  String tankPresets_deleteMessage(Object name) {
    return 'Vuoi davvero eliminare \"$name\"?';
  }

  @override
  String get tankPresets_deletePreset => 'Elimina preset';

  @override
  String get tankPresets_deleteTitle => 'Eliminare il preset bombola?';

  @override
  String tankPresets_deleted(Object name) {
    return '\"$name\" eliminato';
  }

  @override
  String get tankPresets_editPreset => 'Modifica preset';

  @override
  String tankPresets_edit_created(Object name) {
    return '\"$name\" creato';
  }

  @override
  String get tankPresets_edit_descriptionHint =>
      'es. La mia bombola a noleggio dal diving';

  @override
  String get tankPresets_edit_descriptionOptional => 'Descrizione (opzionale)';

  @override
  String tankPresets_edit_errorLoading(Object error) {
    return 'Errore caricamento preset: $error';
  }

  @override
  String tankPresets_edit_errorSaving(Object error) {
    return 'Errore salvataggio preset: $error';
  }

  @override
  String tankPresets_edit_gasCapacity(Object capacity) {
    return '• Capacità gas: $capacity cuft';
  }

  @override
  String get tankPresets_edit_material => 'Materiale';

  @override
  String get tankPresets_edit_name => 'Nome';

  @override
  String get tankPresets_edit_nameHelper =>
      'Un nome descrittivo per questo preset bombola';

  @override
  String get tankPresets_edit_nameHint => 'es. La mia AL80';

  @override
  String get tankPresets_edit_nameRequired => 'Inserisci un nome';

  @override
  String get tankPresets_edit_ratedPressure => 'Pressione nominale';

  @override
  String get tankPresets_edit_required => 'Obbligatorio';

  @override
  String get tankPresets_edit_tankSpecifications => 'Specifiche bombola';

  @override
  String get tankPresets_edit_title => 'Modifica preset bombola';

  @override
  String tankPresets_edit_updated(Object name) {
    return '\"$name\" aggiornato';
  }

  @override
  String get tankPresets_edit_validPressure => 'Inserisci una pressione valida';

  @override
  String get tankPresets_edit_validVolume => 'Inserisci un volume valido';

  @override
  String get tankPresets_edit_volume => 'Volume';

  @override
  String get tankPresets_edit_volumeHelperCuft => 'Capacità gas (cuft)';

  @override
  String get tankPresets_edit_volumeHelperLiters => 'Volume acqua (L)';

  @override
  String tankPresets_edit_waterVolume(Object volume) {
    return '• Volume acqua: $volume L';
  }

  @override
  String get tankPresets_edit_workingPressure => 'Pressione di esercizio';

  @override
  String tankPresets_edit_workingPressureBar(Object pressure) {
    return '• Pressione di esercizio: $pressure bar';
  }

  @override
  String tankPresets_error(Object error) {
    return 'Errore: $error';
  }

  @override
  String tankPresets_errorDeleting(Object error) {
    return 'Errore eliminazione preset: $error';
  }

  @override
  String get tankPresets_applyToImports =>
      'Applica anche alle immersioni importate';

  @override
  String get tankPresets_applyToImports_subtitle =>
      'Completa i dati bombola mancanti nelle immersioni importate usando il preset predefinito';

  @override
  String get tankPresets_new_title => 'Nuovo preset bombola';

  @override
  String get tankPresets_noPresets => 'Nessun preset bombola disponibile';

  @override
  String get tankPresets_setAsDefault => 'Imposta come predefinito';

  @override
  String get tankPresets_title => 'Preset bombole';

  @override
  String get tools_gpsLogger_description =>
      'Registra la tua posizione durante una giornata di immersioni e abbina automaticamente le immersioni importate alle posizioni GPS.';

  @override
  String get tools_gpsLogger_subtitle => 'Registra una traccia di superficie';

  @override
  String get tools_gpsLogger_title => 'Registratore GPS';

  @override
  String get tools_weight_aluminumImperial =>
      'Più galleggiante da vuota (+4 lbs)';

  @override
  String get tools_weight_aluminumMetric => 'Più galleggiante da vuota (+2 kg)';

  @override
  String get tools_weight_bodyWeightOptional => 'Peso corporeo (opzionale)';

  @override
  String get tools_weight_carbonFiberImperial => 'Molto galleggiante (+7 lbs)';

  @override
  String get tools_weight_carbonFiberMetric => 'Molto galleggiante (+3 kg)';

  @override
  String get tools_weight_disclaimer =>
      'Questa è solo una stima. Esegui sempre un controllo dell\'assetto a inizio immersione e regola di conseguenza. Fattori come GAV, galleggiabilità personale e respirazione influenzano i requisiti effettivi di zavorra.';

  @override
  String get tools_weight_exposureSuit => 'Muta';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return '• Capacità gas: $capacity cuft';
  }

  @override
  String get tools_weight_helperImperial =>
      'Aggiunge ~2 lbs ogni 22 lbs oltre 154 lbs';

  @override
  String get tools_weight_helperMetric =>
      'Aggiunge ~1 kg ogni 10 kg oltre 70 kg';

  @override
  String get tools_weight_notSpecified => 'Non specificato';

  @override
  String get tools_weight_recommendedWeight => 'Zavorra consigliata';

  @override
  String tools_weight_resultAccessibility(Object weight, Object unit) {
    return 'Zavorra consigliata: $weight $unit';
  }

  @override
  String get tools_weight_steelImperial => 'Galleggiabilità negativa (-4 lbs)';

  @override
  String get tools_weight_steelMetric => 'Galleggiabilità negativa (-2 kg)';

  @override
  String get tools_weight_tankMaterial => 'Materiale bombola';

  @override
  String get tools_weight_tankSpecifications => 'Specifiche bombola';

  @override
  String get tools_weight_title => 'Calcolatore zavorra';

  @override
  String get tools_weight_waterType => 'Tipo di acqua';

  @override
  String tools_weight_waterVolume(Object volume) {
    return '• Volume acqua: $volume L';
  }

  @override
  String tools_weight_workingPressure(Object pressure) {
    return '• Pressione di esercizio: $pressure bar';
  }

  @override
  String get tools_weight_yourWeight => 'Il tuo peso';

  @override
  String get settings_section_dataSources_title => 'Data Sources';

  @override
  String get settings_section_dataSources_subtitle =>
      'Connected services & integrations';

  @override
  String get settings_siteMatch_title => 'Associazione automatica dei siti';

  @override
  String get settings_siteMatch_subtitle =>
      'Con quanta intensità le immersioni scaricate vengono associate ai siti';

  @override
  String get settings_siteMatch_strict => 'Rigoroso';

  @override
  String get settings_siteMatch_balanced => 'Bilanciato';

  @override
  String get settings_siteMatch_relaxed => 'Rilassato';

  @override
  String get settings_dataSources_header => 'Data Sources';

  @override
  String get settings_dataSources_appleHealth_title => 'Apple Health';

  @override
  String get settings_dataSources_appleHealth_subtitle =>
      'Dati di immersione subacquea';

  @override
  String get settings_dataSources_appleHealth_description =>
      'Submersion reads underwater diving workout data from Apple Health, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get settings_dataSources_appleHealth_dataTypesHeader =>
      'Dati letti da HealthKit';

  @override
  String get settings_dataSources_appleHealth_dataTypeWorkouts =>
      'Allenamenti di immersione subacquea - orario di inizio, durata e dati di attivita dell\'immersione';

  @override
  String get settings_dataSources_appleHealth_dataTypeHeartRate =>
      'Frequenza cardiaca - campioni di frequenza cardiaca registrati durante le immersioni';

  @override
  String get settings_dataSources_appleHealth_permissionGranted =>
      'Accesso a HealthKit concesso';

  @override
  String get settings_dataSources_appleHealth_permissionNotGranted =>
      'Accesso a HealthKit non concesso';

  @override
  String get settings_dataSources_appleHealth_permissionChecking =>
      'Verifica dell\'accesso a HealthKit...';

  @override
  String get settings_dataSources_appleHealth_importAction =>
      'Import from Apple Watch';

  @override
  String get settings_dataSources_appleHealth_privacy =>
      'Your health data is stored locally and is never shared with third parties.';

  @override
  String get settings_dataSources_appleHealth_poweredBy =>
      'Fornito da Apple HealthKit';

  @override
  String get settings_dataSources_noSources =>
      'No data source integrations are available on this platform.';

  @override
  String get diveLog_edit_section_environment => 'Ambiente';

  @override
  String get diveLog_edit_subsection_autofill => 'Compilazione automatica';

  @override
  String get diveLog_edit_subsection_weather => 'Meteo';

  @override
  String get diveLog_edit_subsection_diveConditions =>
      'Condizioni di immersione';

  @override
  String get diveLog_edit_label_windSpeed => 'Velocità del vento';

  @override
  String get diveLog_edit_label_windDirection => 'Direzione del vento';

  @override
  String get diveLog_edit_label_cloudCover => 'Copertura nuvolosa';

  @override
  String get diveLog_edit_label_precipitation => 'Precipitazioni';

  @override
  String get diveLog_edit_label_humidity => 'Umidità';

  @override
  String get diveLog_edit_label_weatherDescription => 'Descrizione meteo';

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
  String get diveLog_detail_section_environment => 'Ambiente';

  @override
  String get diveLog_detail_subsection_weather => 'Meteo';

  @override
  String get diveLog_detail_subsection_diveConditions =>
      'Condizioni di immersione';

  @override
  String get diveLog_detail_label_windSpeed => 'Velocità del vento';

  @override
  String get diveLog_detail_label_windDirection => 'Direzione del vento';

  @override
  String get diveLog_detail_label_cloudCover => 'Copertura nuvolosa';

  @override
  String get diveLog_detail_label_precipitation => 'Precipitazioni';

  @override
  String get diveLog_detail_label_humidity => 'Umidità';

  @override
  String get diveLog_detail_label_weatherDescription => 'Descrizione';

  @override
  String get diveLog_detail_weatherSourceOpenMeteo => 'via Open-Meteo';

  @override
  String get dropTarget_title => 'Rilascia per importare';

  @override
  String get dropTarget_subtitle =>
      'Rilascia per aprire la procedura di importazione';

  @override
  String get dropTarget_error_unsupportedFile => 'Tipo di file non supportato';

  @override
  String get dropTarget_error_wizardActive =>
      'Completa prima l\'importazione in corso';

  @override
  String get dropTarget_error_readFailed => 'Impossibile leggere il file';

  @override
  String get enum_cloudCover_clear => 'Sereno';

  @override
  String get enum_cloudCover_partlyCloudy => 'Parzialmente nuvoloso';

  @override
  String get enum_cloudCover_mostlyCloudy => 'Prevalentemente nuvoloso';

  @override
  String get enum_cloudCover_overcast => 'Coperto';

  @override
  String get enum_precipitation_none => 'Nessuna';

  @override
  String get enum_precipitation_drizzle => 'Pioviggine';

  @override
  String get enum_precipitation_lightRain => 'Pioggia leggera';

  @override
  String get enum_precipitation_rain => 'Pioggia';

  @override
  String get enum_precipitation_heavyRain => 'Pioggia intensa';

  @override
  String get enum_precipitation_snow => 'Neve';

  @override
  String get enum_precipitation_sleet => 'Nevischio';

  @override
  String get enum_precipitation_hail => 'Grandine';

  @override
  String get columnConfig_title => 'Campi elenco dettagli immersioni';

  @override
  String get columnConfig_viewMode => 'Modalità di visualizzazione';

  @override
  String get columnConfig_visibleColumns => 'Colonne visibili';

  @override
  String get columnConfig_availableFields => 'Campi disponibili';

  @override
  String get columnConfig_extraFields => 'Campi extra';

  @override
  String get columnConfig_extraFields_description =>
      'Mostrati sotto il contenuto principale della scheda';

  @override
  String get columnConfig_slotAssignments => 'Assegnazione posizioni';

  @override
  String get columnConfig_resetToDefault => 'Ripristina predefiniti';

  @override
  String get columnConfig_preset => 'Preimpostazione';

  @override
  String get columnConfig_presetSaveAs => 'Salva come';

  @override
  String get columnConfig_presetName => 'Nome preimpostazione';

  @override
  String get columnConfig_presetNameHint => 'es. Immersione tecnica';

  @override
  String get columnConfig_presetSave => 'Salva';

  @override
  String get columnConfig_presetCancel => 'Annulla';

  @override
  String get columnConfig_columns => 'Colonne';

  @override
  String get columnConfig_done => 'Fatto';

  @override
  String get settings_appearance_columnConfig =>
      'Campi elenco dettagli immersioni';

  @override
  String get settings_appearance_columnConfig_subtitle =>
      'Personalizza i campi mostrati nelle viste elenco immersioni';

  @override
  String get diveField_category_core => 'Essenziale';

  @override
  String get diveField_category_environment => 'Ambiente';

  @override
  String get diveField_category_gas => 'Gas';

  @override
  String get diveField_category_tank => 'Bombola';

  @override
  String get diveField_category_weight => 'Zavorra';

  @override
  String get diveField_category_equipment => 'Attrezzatura';

  @override
  String get diveField_category_deco => 'Decompressione';

  @override
  String get diveField_category_physiology => 'Fisiologia';

  @override
  String get diveField_category_rebreather => 'Rebreather';

  @override
  String get diveField_category_people => 'Persone';

  @override
  String get diveField_category_location => 'Posizione';

  @override
  String get diveField_category_trip => 'Viaggio';

  @override
  String get diveField_category_rating => 'Valutazione';

  @override
  String get diveField_category_metadata => 'Metadati';

  @override
  String get listViewMode_table => 'Tabella';

  @override
  String get settings_appearance_general => 'Generale';

  @override
  String get settings_appearance_sections => 'Sezioni';

  @override
  String get settings_appearance_colorAccents => 'Accenti di colore';

  @override
  String get settings_appearance_accentNavIcons =>
      'Icone di navigazione colorate';

  @override
  String get settings_appearance_accentNavIcons_subtitle =>
      'Colora le icone del menu principale con il colore di ogni sezione';

  @override
  String get settings_appearance_accentSectionHeaders =>
      'Intestazioni di sezione colorate';

  @override
  String get settings_appearance_accentSectionHeaders_subtitle =>
      'Mostra un\'icona di sezione colorata accanto ai titoli delle pagine';

  @override
  String get settings_appearance_accentListIcons =>
      'Icone degli elenchi colorate';

  @override
  String get settings_appearance_accentListIcons_subtitle =>
      'Colora le icone negli elenchi e nelle pagine delle impostazioni';

  @override
  String get settings_appearance_showDetailsPane => 'Mostra pannello dettagli';

  @override
  String get settings_appearance_showDetailsPane_subtitle =>
      'Visualizza il pannello dettagli accanto alla tabella';

  @override
  String get settings_appearance_showProfilePanel =>
      'Mostra pannello profilo nella vista tabella';

  @override
  String get settings_appearance_showProfilePanel_subtitle =>
      'Visualizza il grafico del profilo di immersione sopra la tabella per impostazione predefinita';

  @override
  String get settings_appearance_mapStyle => 'Stile della mappa';

  @override
  String get settings_appearance_mapStyle_openStreetMap => 'Mappa stradale';

  @override
  String get settings_appearance_mapStyle_openTopoMap => 'Topografica';

  @override
  String get settings_appearance_mapStyle_esriSatellite => 'Satellite';

  @override
  String get common_action_reparse => 'Rianalizza';

  @override
  String get diveComputer_detail_reparseAllButton =>
      'Rianalizza tutte le immersioni';

  @override
  String get diveComputer_detail_reparseAllTitle =>
      'Rianalizza tutte le immersioni';

  @override
  String diveComputer_detail_reparseAllMessage(int count) {
    return 'Riesegui il parser delle immersioni su $count immersioni con dati grezzi salvati. Questa azione aggiorna i dati di profilo e dei sensori, ma conserva note, siti, compagni e altre modifiche.';
  }

  @override
  String diveComputer_detail_reparseAllProgress(int count) {
    return 'Rianalisi di $count immersioni in corso...';
  }

  @override
  String diveComputer_detail_reparseAllSuccess(int count) {
    return '$count immersioni rianalizzate con successo';
  }

  @override
  String diveComputer_detail_reparseAllPartial(
    int succeeded,
    int total,
    int failed,
  ) {
    return 'Rianalizzate $succeeded su $total immersioni. $failed non riuscite.';
  }

  @override
  String diveComputer_detail_reparseRawDataCount(int count) {
    return '$count immersioni con dati grezzi';
  }

  @override
  String diveComputer_detail_reparseRawDataCountWithout(
    int count,
    int without,
  ) {
    return '$count immersioni con dati grezzi ($without senza)';
  }

  @override
  String get diveLog_detail_menu_reparseRawData => 'Rianalizza dati grezzi';

  @override
  String get diveLog_detail_reparseSuccess =>
      'Immersione rianalizzata con successo';

  @override
  String get diveLog_detail_reparseProfilePreserved =>
      'Dettagli della sorgente aggiornati. Questa immersione è stata combinata da altre immersioni, quindi il suo profilo è rimasto invariato.';

  @override
  String diveLog_detail_reparseFailed(String error) {
    return 'Rianalisi non riuscita: $error';
  }

  @override
  String get universalImport_label_replaceSource => 'Sostituisci sorgente';

  @override
  String get universalImport_label_replaceSourceSubtitle =>
      'Aggiorna dallo stesso computer';

  @override
  String get universalImport_title_importOptions => 'Opzioni di importazione';

  @override
  String get universalImport_label_options => 'Opzioni';

  @override
  String get universalImport_label_retainDiveNumbers =>
      'Mantieni i numeri di immersione di origine';

  @override
  String get universalImport_label_retainDiveNumbersSubtitle =>
      'Usa i numeri di immersione dal file importato invece di assegnarli automaticamente';

  @override
  String get universalImport_title_successImported => 'Importazione riuscita';

  @override
  String get universalImport_title_successUpdated => 'Aggiornamento riuscito';

  @override
  String get universalImport_title_successConsolidated =>
      'Consolidamento riuscito';

  @override
  String get universalImport_title_noDivesImported =>
      'Nessuna immersione importata';

  @override
  String get universalImport_label_allDivesSkipped =>
      'Tutte le immersioni sono state saltate.';

  @override
  String get universalImport_label_replacedSourceData =>
      'Dati sorgente sostituiti';

  @override
  String get universalImport_label_consolidated => 'Consolidate';

  @override
  String get universalImport_label_photosAttached => 'Foto allegate';

  @override
  String get universalImport_label_photosUnmatched =>
      'Foto senza immersione corrispondente';

  @override
  String get common_label_shareWithAllProfiles =>
      'Condividi con tutti i profili subacquei';

  @override
  String get settings_shareByDefault_title =>
      'Condividi i nuovi siti e viaggi per impostazione predefinita';

  @override
  String get settings_shareAllSites_title => 'Condividi tutti i miei siti';

  @override
  String get settings_shareAllTrips_title => 'Condividi tutti i miei viaggi';

  @override
  String settings_shareAllSites_confirm(int count) {
    return 'Rendere i tuoi $count siti visibili a tutti i profili subacquei di questa app? Potrai annullare la condivisione dei singoli siti in seguito.';
  }

  @override
  String settings_shareAllTrips_confirm(int count) {
    return 'Rendere i tuoi $count viaggi visibili a tutti i profili subacquei di questa app? Potrai annullare la condivisione dei singoli viaggi in seguito.';
  }

  @override
  String settings_shareAllSites_snackbar(int count) {
    return '$count siti condivisi con tutti i profili subacquei.';
  }

  @override
  String settings_shareAllTrips_snackbar(int count) {
    return '$count viaggi condivisi con tutti i profili subacquei.';
  }

  @override
  String get settings_shareAll_noneToShare => 'Niente da condividere.';

  @override
  String get settings_sharedData_sectionTitle => 'Dati condivisi';

  @override
  String get settings_sharedData_sectionSubtitle =>
      'Condividi siti e viaggi tra i profili';

  @override
  String get common_action_unshare => 'Annulla condivisione';

  @override
  String get trips_unshareConfirm_title =>
      'Annullare la condivisione di questo viaggio?';

  @override
  String trips_unshareConfirm_body(String name) {
    return 'Verrà rimosso «$name» dalle viste degli altri profili subacquei. Potrai condividerlo di nuovo in seguito.';
  }

  @override
  String get sites_unshareConfirm_title =>
      'Annullare la condivisione di questo sito?';

  @override
  String sites_unshareConfirm_body(String name) {
    return 'Verrà rimosso «$name» dalle viste degli altri profili subacquei. Potrai condividerlo di nuovo in seguito.';
  }

  @override
  String get trips_deleteShared_title => 'Eliminare il viaggio condiviso?';

  @override
  String trips_deleteShared_body(String name) {
    return '«$name» è condiviso con altri profili subacquei. Eliminandolo qui verrà rimosso per tutti.';
  }

  @override
  String get sites_deleteShared_title => 'Eliminare il sito condiviso?';

  @override
  String sites_deleteShared_body(String name) {
    return '«$name» è condiviso con altri profili subacquei. Eliminandolo qui verrà rimosso per tutti.';
  }

  @override
  String divers_delete_reassigned_snackbar(int trips, int sites, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      trips,
      locale: localeName,
      other: 'viaggi condivisi',
      one: 'viaggio condiviso',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sites,
      locale: localeName,
      other: 'siti condivisi',
      one: 'sito condiviso',
    );
    return 'Subacqueo eliminato. $trips $_temp0 e $sites $_temp1 riassegnati a $name.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_title =>
      'Profili subacquei duplicati';

  @override
  String get settings_cloudSync_duplicateDivers_description =>
      'La sincronizzazione ha trovato più di un profilo con lo stesso nome. Ciò accade di solito quando ogni dispositivo ha creato il proprio profilo prima della sincronizzazione. L\'unione sposta tutte le immersioni e i dati su un unico profilo.';

  @override
  String settings_cloudSync_duplicateDivers_groupLabel(String name, int count) {
    return '$name ($count profili)';
  }

  @override
  String get settings_cloudSync_duplicateDivers_mergeButton => 'Unisci';

  @override
  String get settings_cloudSync_duplicateDivers_confirmTitle =>
      'Unire i profili subacquei?';

  @override
  String settings_cloudSync_duplicateDivers_confirmBody(
    int count,
    String name,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profili duplicati',
      one: 'un profilo duplicato',
    );
    return 'Tutte le immersioni, le certificazioni, l\'attrezzatura e gli altri dati di $_temp0 verranno spostati su \"$name\". Questa operazione non può essere annullata automaticamente.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_confirmCancel => 'Annulla';

  @override
  String get settings_cloudSync_duplicateDivers_confirmAction => 'Unisci';

  @override
  String settings_cloudSync_duplicateDivers_successSnack(String name) {
    return 'Unito in $name';
  }

  @override
  String settings_cloudSync_duplicateDivers_failureSnack(String error) {
    return 'Unione non riuscita: $error';
  }

  @override
  String get settings_cloudSync_duplicateDivers_undo => 'Annulla';

  @override
  String get divers_edit_priorExperienceSection => 'Esperienza Precedente';

  @override
  String get divers_edit_priorExperienceHelp =>
      'Immersioni e tempo prima di iniziare a registrare in Submersion.';

  @override
  String get divers_edit_priorDivesLabel => 'Immersioni precedenti';

  @override
  String get divers_edit_priorHoursLabel => 'Ore precedenti';

  @override
  String get divers_edit_priorMinutesLabel => 'Minuti';

  @override
  String get divers_edit_divingSinceLabel => 'Immersioni dal';

  @override
  String get divers_edit_divingSinceNotSet => 'Non impostato';

  @override
  String get divers_edit_clearDivingSinceTooltip => 'Cancella immersioni dal';

  @override
  String get divers_edit_priorInvalidNumber => 'Inserisci un numero valido';

  @override
  String statistics_priorBreakdown(String logged, String prior) {
    return '$logged registrate + $prior precedenti';
  }

  @override
  String statistics_divingSince(int year) {
    return 'Immersioni dal $year';
  }

  @override
  String get db_location_choose_volume => 'Scegli posizione di archiviazione';

  @override
  String get db_location_internal => 'Memoria interna';

  @override
  String get db_location_sd_card => 'Scheda SD';

  @override
  String get db_location_external_note =>
      'I file qui vengono rimossi se disinstalli l\'app.';

  @override
  String get db_location_backup_note =>
      'Android non può eseguire il database da una cartella sincronizzata nel cloud. Per conservarne una copia in Dropbox, Nextcloud o Google Drive, imposta la Posizione di backup in Backup e Ripristino.';

  @override
  String diveLog_bulkEdit_membership_onAll(int count) {
    return 'su tutte le $count';
  }

  @override
  String diveLog_bulkEdit_membership_onSome(int count, int total) {
    return 'su $count di $total';
  }

  @override
  String diveLog_bulkEdit_membership_adding(int total) {
    return 'aggiunta a tutte le $total';
  }

  @override
  String get diveLog_bulkEdit_membership_removing => 'rimozione da tutte';

  @override
  String get diveLog_bulkEdit_membership_empty =>
      'Ancora nessun elemento nelle immersioni selezionate';

  @override
  String get settings_mediaStorage_entry_title => 'Archiviazione media';

  @override
  String get settings_mediaStorage_entry_subtitle =>
      'Conserva gli originali di foto e video nel tuo cloud personale';

  @override
  String get settings_mediaStorage_status_notConfigured =>
      'Nessun archivio media collegato su questo dispositivo';

  @override
  String settings_mediaStorage_status_connected(String hint) {
    return 'Collegato a $hint';
  }

  @override
  String get settings_mediaStorage_test_success => 'Connessione riuscita';

  @override
  String get settings_mediaStorage_saved => 'Archivio media collegato';

  @override
  String get settings_mediaStorage_action_disconnect => 'Disconnetti';

  @override
  String get settings_mediaStorage_disconnect_confirm_title =>
      'Disconnettere l\'archivio media?';

  @override
  String get settings_mediaStorage_disconnect_confirm_body =>
      'Questo dispositivo smette di caricare e scaricare i media. Nulla viene eliminato dal tuo bucket.';

  @override
  String get settings_mediaStorage_action_copyFromSync =>
      'Copia impostazioni da Sync';

  @override
  String get settings_mediaStorage_transfers_title => 'Trasferimenti';

  @override
  String get settings_mediaStorage_transfers_entry => 'Vedi trasferimenti';

  @override
  String get settings_mediaStorage_transfers_empty => 'Nessun trasferimento';

  @override
  String get settings_mediaStorage_transfers_retry => 'Riprova';

  @override
  String get settings_mediaStorage_transfers_clearCompleted =>
      'Rimuovi completati';

  @override
  String get settings_mediaStorage_transfers_state_pending => 'In attesa';

  @override
  String get settings_mediaStorage_transfers_state_transferring =>
      'Caricamento';

  @override
  String get settings_mediaStorage_transfers_state_deleting =>
      'Rimozione dal cloud';

  @override
  String get settings_mediaStorage_transfers_state_done => 'Completato';

  @override
  String get settings_mediaStorage_transfers_state_failed => 'Non riuscito';

  @override
  String settings_mediaStorage_transfers_queued(int count) {
    return '$count in coda';
  }

  @override
  String settings_mediaStorage_transfers_waitingRetry(int count) {
    return '$count in attesa di riprovare';
  }

  @override
  String get settings_mediaStorage_verify_action => 'Verifica libreria';

  @override
  String get settings_mediaStorage_verify_running =>
      'Verifica della libreria multimediale...';

  @override
  String settings_mediaStorage_verify_summary(
    int checked,
    int removed,
    int repaired,
    int aborted,
  ) {
    return 'Controllati $checked oggetti: $removed orfani rimossi, $repaired riparazioni in coda, $aborted caricamenti obsoleti annullati';
  }

  @override
  String get settings_mediaStorage_backfill_action =>
      'Carica libreria esistente';

  @override
  String settings_mediaStorage_backfill_enqueued(int count) {
    return '$count caricamenti in coda';
  }

  @override
  String get settings_mediaStorage_policy_autoUpload =>
      'Carica foto automaticamente';

  @override
  String get settings_mediaStorage_policy_photosOnCellular =>
      'Carica foto su rete mobile';

  @override
  String get settings_mediaStorage_provider_label => 'Provider';

  @override
  String get settings_mediaStorage_connect_dropbox_hint =>
      'Usa la tua connessione Dropbox della sincronizzazione cloud. I media sono archiviati nella cartella app di Dropbox.';

  @override
  String get settings_mediaStorage_connect_gdrive_hint =>
      'Accede con Google. I media sono archiviati nello spazio Drive privato di questa app.';

  @override
  String get settings_mediaStorage_connect_icloud_hint =>
      'I media sono archiviati nel contenitore iCloud di questa app e si sincronizzano tramite il tuo ID Apple.';

  @override
  String settings_mediaStorage_connect_action(String provider) {
    return 'Collega $provider';
  }

  @override
  String get bodyWeight_addEntry => 'Aggiungi misurazione';

  @override
  String get bodyWeight_dateLabel => 'Data';

  @override
  String get bodyWeight_deleteTooltip => 'Elimina voce';

  @override
  String get bodyWeight_heightLabel => 'Altezza (cm)';

  @override
  String get bodyWeight_heightFeetLabel => 'Altezza (ft)';

  @override
  String get bodyWeight_heightInchesLabel => 'Pollici';

  @override
  String bodyWeight_weightLabel(String unit) {
    return 'Peso ($unit)';
  }

  @override
  String diveLog_edit_weightFeedback_amount(String unit) {
    return 'Di quanto circa ($unit)';
  }

  @override
  String get diveLog_edit_weightFeedback_correct => 'Corretto';

  @override
  String get diveLog_edit_weightFeedback_label => 'Com\'era la tua zavorra?';

  @override
  String get diveLog_edit_weightFeedback_over => 'Troppa zavorra';

  @override
  String get diveLog_edit_weightFeedback_under => 'Poca zavorra';

  @override
  String get diverProfile_bodyWeight_empty => 'Non registrato';

  @override
  String get diverProfile_bodyWeight_title => 'Peso corporeo';

  @override
  String get equipment_edit_advanced_title => 'Avanzate';

  @override
  String get equipment_edit_buoyancyHint_exposure =>
      'Positivo: quanto galleggia';

  @override
  String get equipment_edit_buoyancyHint_generic => 'Negativo se affonda';

  @override
  String get equipment_edit_buoyancyHint_tank =>
      'Lasciare vuoto: le bombole usano le proprie specifiche';

  @override
  String equipment_edit_buoyancyLabel(String unit) {
    return 'Galleggiabilità ($unit)';
  }

  @override
  String equipment_edit_dryWeightLabel(String unit) {
    return 'Peso a secco ($unit)';
  }

  @override
  String equipment_edit_liftCapacityLabel(String unit) {
    return 'Capacità di sollevamento ($unit)';
  }

  @override
  String get equipment_edit_liftCapacityHint =>
      'Portanza nominale di GAV o sacco';

  @override
  String get planner_gearWeights_accept => 'Usa come zavorra pianificata';

  @override
  String get planner_gearWeights_addGear => 'Aggiungi attrezzatura';

  @override
  String get planner_gearWeights_empty =>
      'Aggiungi attrezzatura per prevedere la zavorra';

  @override
  String planner_gearWeights_planned(String weight) {
    return 'Pianificato: $weight';
  }

  @override
  String planner_gearWeights_predicted(String weight) {
    return 'Previsto: $weight';
  }

  @override
  String get planner_gearWeights_title => 'Attrezzatura e zavorra';

  @override
  String get planner_gearWeights_useSet => 'Usa set';

  @override
  String get tools_weight_addGear => 'Aggiungi attrezzatura';

  @override
  String get tools_weight_addTank => 'Aggiungi bombola';

  @override
  String tools_weight_basedOnDives(int count) {
    return 'Basato su $count immersioni registrate';
  }

  @override
  String get tools_weight_breakdownTitle => 'Come è stato calcolato';

  @override
  String get tools_weight_confidence_high => 'Affidabilità alta';

  @override
  String get tools_weight_confidence_low => 'Affidabilità bassa - stima';

  @override
  String get tools_weight_confidence_medium => 'Affidabilità media';

  @override
  String tools_weight_deltaVsPrevious(String delta) {
    return '$delta rispetto alla configurazione precedente';
  }

  @override
  String get tools_weight_noGear =>
      'Aggiungi l\'attrezzatura con cui ti immergerai per personalizzare la previsione.';

  @override
  String get tools_weight_personalTerm => 'Base personale';

  @override
  String get tools_weight_placementTitle => 'Posizionamento suggerito';

  @override
  String get tools_weight_predictedWeight => 'Zavorra prevista';

  @override
  String get tools_weight_saveToProfile => 'Salva il peso nel profilo';

  @override
  String get tools_weight_source_measured => 'misurato dalle tue immersioni';

  @override
  String get tools_weight_source_physics => 'fisica';

  @override
  String get tools_weight_source_typeDefault => 'stima predefinita';

  @override
  String get tools_weight_source_userSpec =>
      'dalle specifiche della tua attrezzatura';

  @override
  String get tools_weight_tanks => 'Bombole';

  @override
  String get tools_weight_useSet => 'Usa set';

  @override
  String get tools_weight_waterTerm => 'Tipo di acqua';

  @override
  String get dive3d_previewTitle => 'Vista 3D';

  @override
  String get dive3d_previewHint => 'Tocca per esplorare in 3D';

  @override
  String get dive3d_resetView => 'Reimposta vista';

  @override
  String get dive3d_zoomIn => 'Ingrandisci';

  @override
  String get dive3d_zoomOut => 'Riduci';

  @override
  String get dive3d_play => 'Riproduci';

  @override
  String get dive3d_pause => 'Pausa';

  @override
  String get dive3d_overlays => 'Sovrapposizioni';

  @override
  String get dive3d_overlay_strata => 'Strati di temperatura';

  @override
  String get dive3d_overlay_ceiling => 'Soffitto deco';

  @override
  String get dive3d_overlay_curtain => 'Tenda di profondità';

  @override
  String get dive3d_overlay_markers => 'Indicatori';

  @override
  String get dive3d_seascape_overlay_paths => 'Percorsi delle immersioni';

  @override
  String get dive3d_seascape_overlay_contours => 'Isobate';

  @override
  String get dive3d_seascape_overlay_walls => 'Pareti ripide';

  @override
  String get dive3d_overlay_water => 'Superficie dell\'acqua';

  @override
  String get dive3d_seascape_legend_land => 'Terra';

  @override
  String get dive3d_seascape_appearance => 'Aspetto del terreno';

  @override
  String get dive3d_seascape_chartView => 'Vista carta';

  @override
  String get dive3d_seascape_orbitView => 'Vista 3D';

  @override
  String get dive3d_seascape_appearance_surface => 'Superficie del terreno';

  @override
  String get dive3d_seascape_appearance_surfaceDepth => 'Colori di profondità';

  @override
  String get dive3d_seascape_appearance_surfaceImagery =>
      'Immagini della mappa';

  @override
  String get dive3d_seascape_appearance_surfaceBlend => 'Miscela';

  @override
  String get siteFeature_type_wreck => 'Relitto';

  @override
  String get siteFeature_type_mooring => 'Boa di ormeggio';

  @override
  String get siteFeature_type_entry => 'Punto d\'ingresso';

  @override
  String get siteFeature_type_exit => 'Punto d\'uscita';

  @override
  String get siteFeature_type_swimThrough => 'Passaggio';

  @override
  String get siteFeature_type_hazard => 'Pericolo';

  @override
  String get siteFeature_type_current => 'Corrente';

  @override
  String get siteFeature_sectionTitle => 'Elementi';

  @override
  String get siteFeature_addAction => 'Aggiungi elemento';

  @override
  String get siteFeature_placeHint =>
      'Tocca la mappa per posizionare l\'elemento';

  @override
  String get siteFeature_addTitle => 'Aggiungi elemento';

  @override
  String get siteFeature_editTitle => 'Modifica elemento';

  @override
  String get siteFeature_field_name => 'Nome';

  @override
  String get siteFeature_field_bearing => 'Rilevamento (°)';

  @override
  String get siteFeature_field_depth => 'Profondità';

  @override
  String get siteFeature_field_notes => 'Note';

  @override
  String get siteFeature_deleteAction => 'Elimina';

  @override
  String siteFeature_deleteConfirm(String name) {
    return 'Eliminare $name?';
  }

  @override
  String get siteScape_mode2d => 'Mappa';

  @override
  String get siteScape_mode3d => '3D';

  @override
  String get dive3d_seascape_appearance_rampRange =>
      'Limita l\'intervallo di profondità dei colori';

  @override
  String get dive3d_seascape_appearance_rampMax => 'Colore più scuro a';

  @override
  String get dive3d_seascape_appearance_banded => 'Gradiente a bande';

  @override
  String get dive3d_seascape_appearance_contours => 'Livelli delle isobate';

  @override
  String get dive3d_seascape_appearance_contourAuto => 'Automatico';

  @override
  String get dive3d_seascape_appearance_contourCustom => 'Personalizzato';

  @override
  String get dive3d_seascape_appearance_addLevel => 'Aggiungi livello';

  @override
  String get dive3d_seascape_appearance_defaultColor => 'Predefinito';

  @override
  String get dive3d_seascape_appearance_wallAngle => 'Angolo di parete ripida';

  @override
  String get dive3d_seascape_appearance_wallAngleNote =>
      'Le celle batimetriche mediano la pendenza interna, quindi le pareti reali sembrano meno ripide. Restare ben sotto i 45 gradi.';

  @override
  String get dive3d_seascape_siteTitle => 'Paesaggio marino del sito';

  @override
  String dive3d_seascape_seafloorSource(String source, String resolution) {
    return 'Fondale: $source (~$resolution m)';
  }

  @override
  String get dive3d_seascape_noCoordinates =>
      'Questo sito non ha coordinate GPS';

  @override
  String get dive3d_seascape_noData =>
      'Nessuna batimetria disponibile per questa posizione';

  @override
  String dive3d_seascape_axis_distance(String unitSymbol) {
    return 'Distanza ($unitSymbol)';
  }

  @override
  String get settings_about_bathymetryCredit =>
      'Dati batimetrici: GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022';

  @override
  String get dive3d_metric_depth => 'Profondità';

  @override
  String get dive3d_metric_temperature => 'Temp';

  @override
  String get dive3d_metric_ascentRate => 'Risalita';

  @override
  String get dive3d_metric_ppO2 => 'ppO2';

  @override
  String get dive3d_metric_cns => 'SNC';

  @override
  String get dive3d_metric_heartRate => 'FC';

  @override
  String get dive3d_metric_tankPressure => 'Pressione';

  @override
  String get dive3d_zAxis => 'Asse Z';

  @override
  String get dive3d_zAxis_none => 'Nessuno';

  @override
  String get dive3d_overlay_shadows => 'Ombre sulle pareti';

  @override
  String get dive3d_metric_tts => 'TTS';

  @override
  String dive3d_axis_depth(String unitSymbol) {
    return 'Profondità ($unitSymbol)';
  }

  @override
  String get dive3d_axis_time => 'Tempo di immersione (min)';

  @override
  String get dive3d_pose_menu => 'Camera';

  @override
  String get dive3d_pose_default => 'Vista predefinita';

  @override
  String get dive3d_pose_front => 'Frontale (profondità / tempo)';

  @override
  String get dive3d_pose_side => 'Laterale (profondità / metrica)';

  @override
  String get dive3d_pose_top => 'Dall\'alto (metrica / tempo)';

  @override
  String get dive3d_readout_runTime => 'Tempo di immersione';

  @override
  String get dive3d_readout_ceiling => 'Soffitto';

  @override
  String dive3d_readout_tank(int n) {
    return 'Bombola $n';
  }

  @override
  String get dive3d_scene_dive => 'Immersione';

  @override
  String get dive3d_scene_tissue => 'Tessuti';

  @override
  String get dive3d_tissue_gasCombined => 'Combinato';

  @override
  String get dive3d_tissue_gasN2 => 'N2';

  @override
  String get dive3d_tissue_gasHe => 'He';

  @override
  String get dive3d_tissue_colorMValue => '% valore M';

  @override
  String get dive3d_tissue_colorAbsolute => 'Carico';

  @override
  String get dive3d_tissue_controlling => 'Controllo';

  @override
  String get dive3d_tissue_surfaceInterval => 'Intervallo di superficie';

  @override
  String get dive3d_career_title => 'Cronologia 3D';

  @override
  String get dive3d_career_colorRecency => 'Recenza';

  @override
  String get dive3d_career_colorDepth => 'Profondità';

  @override
  String get dive3d_career_empty => 'Nessuna immersione con profilo';

  @override
  String get dive3d_spatial_title => 'Paesaggio marino 3D';

  @override
  String get dive3d_spatial_estimatedPath =>
      'Percorso stimato (navigazione stimata)';

  @override
  String get dive3d_spatial_synthesizedSeafloor => 'Fondale sintetizzato';

  @override
  String get dive3d_spatial_noPath =>
      'Dati insufficienti per ricostruire il percorso';

  @override
  String get dive3d_tissue_legendHeight =>
      'Altezza e colore: % del limite del valore M';

  @override
  String get dive3d_tissue_legendLimit => 'Piano rosso = limite deco';

  @override
  String get dive3d_tissue_legendAxes =>
      'Sx→dx: tempo · Avanti→dietro: tessuti veloci→lenti';

  @override
  String get dive3d_tissue_legendDepth => 'Curva blu: la tua profondità';

  @override
  String get dive3d_tissue_onGassing => 'Assorbimento';

  @override
  String get dive3d_tissue_offGassing => 'Rilascio';

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
    return 'Saturazione $percent%';
  }

  @override
  String dive3d_tissue_tooltipProgress(int percent) {
    return '$percent% dell\'immersione';
  }

  @override
  String get dive3d_tissue_stateEquilibrium => 'Equilibrio';

  @override
  String get dive3d_tissue_statePastMValue => 'Oltre il valore M';

  @override
  String get dive3d_tissue_axisTime => 'Tempo';

  @override
  String get dive3d_tissue_axisSaturation => 'Saturazione %';

  @override
  String get dive3d_tissue_axisCompartment => 'Compartimento';

  @override
  String get dive3d_compare_computers_title => 'Confronta computer';

  @override
  String get dive3d_compare_dives_title => 'Confronta immersioni';

  @override
  String get dive3d_scene_computers => 'Computer';

  @override
  String get dive3d_compare_layout_sideBySide => 'Affiancati';

  @override
  String get dive3d_compare_layout_overlay => 'Sovrapposti';

  @override
  String get dive3d_compare_empty =>
      'Servono almeno 2 profili con dati di profondità per il confronto';

  @override
  String dive3d_compare_showing(Object shown, Object total) {
    return 'Visualizzati $shown di $total';
  }

  @override
  String get dive3d_compare_setReference => 'Imposta come riferimento';

  @override
  String get diveLog_selection_tooltip_compare3d => 'Confronta in 3D';

  @override
  String get diveLog_sources_compareIn3d => 'Confronta in 3D';

  @override
  String get settings_setup_pendingTitle =>
      'Completa la configurazione di questo dispositivo';

  @override
  String settings_setup_mediaStoreAttach(String hint) {
    return 'Collega archiviazione multimediale ($hint)';
  }

  @override
  String settings_setup_accountSignIn(String label) {
    return 'Accedi a $label';
  }

  @override
  String get settings_setup_dismiss => 'Ignora';

  @override
  String get settings_photosMedia_title => 'Foto e media';

  @override
  String get settings_photosMedia_subtitle =>
      'Sorgenti, archiviazione e account';

  @override
  String get settings_photosMedia_sourcesHeader => 'Da dove arrivano le foto';

  @override
  String get settings_photosMedia_storageHeader =>
      'Dove sono conservate le copie';

  @override
  String get settings_photosMedia_accountsHeader => 'Account';

  @override
  String get settings_photosMedia_displayHeader => 'Visualizzazione';

  @override
  String get settings_photosMedia_guidedSetup => 'Configurazione guidata';

  @override
  String get settings_photosMedia_photoSources_title =>
      'Libreria foto e sorgenti';

  @override
  String get settings_photosMedia_photoSources_subtitle =>
      'Galleria, file e opzioni di importazione';

  @override
  String get settings_photosMedia_networkSources_title => 'Sorgenti di rete';

  @override
  String get settings_photosMedia_networkSources_subtitle =>
      'URL e feed manifest (avanzato)';

  @override
  String get settings_connectedAccounts_title => 'Account collegati';

  @override
  String get settings_connectedAccounts_subtitle => 'Accessi cloud e servizi';

  @override
  String get settings_connectedAccounts_empty => 'Nessun account collegato';

  @override
  String get settings_connectedAccounts_status_signedIn => 'Accesso effettuato';

  @override
  String get settings_connectedAccounts_status_needsSignIn =>
      'Accesso richiesto';

  @override
  String get settings_connectedAccounts_status_unavailable =>
      'Non disponibile su questo dispositivo';

  @override
  String get settings_connectedAccounts_disconnectDevice =>
      'Esci su questo dispositivo';

  @override
  String get settings_connectedAccounts_removeFromLibrary =>
      'Rimuovi dalla libreria';

  @override
  String get settings_connectedAccounts_removeConfirmTitle =>
      'Rimuovere l\'account?';

  @override
  String get settings_connectedAccounts_removeConfirmBody =>
      'L\'account viene rimosso da tutti i dispositivi sincronizzati. Le credenziali salvate su altri dispositivi non vengono eliminate.';

  @override
  String get settings_setupGuide_title => 'Configura foto e media';

  @override
  String get settings_setupGuide_intro =>
      'Collega le sorgenti delle tue foto e dove conservare le copie. Puoi rieseguirlo in qualsiasi momento.';

  @override
  String get settings_setupGuide_stepSources => 'Sorgenti foto';

  @override
  String get settings_setupGuide_stepSources_desc =>
      'Allega foto dalla libreria, dai file o da Lightroom.';

  @override
  String get settings_setupGuide_stepStorage => 'Archiviazione media';

  @override
  String get settings_setupGuide_stepStorage_desc =>
      'Conserva copie delle tue foto nel tuo cloud così ogni dispositivo può mostrarle.';

  @override
  String get settings_setupGuide_stepSync => 'Sincronizzazione cloud';

  @override
  String get settings_setupGuide_stepSync_desc =>
      'Sincronizza i dati delle immersioni tra dispositivi.';

  @override
  String get settings_setupGuide_statusDone => 'Configurato';

  @override
  String get settings_setupGuide_statusTodo => 'Non configurato';

  @override
  String get settings_setupGuide_open => 'Apri';

  @override
  String get settings_connectedAccounts_loadError =>
      'Impossibile caricare gli account';

  @override
  String get media_unavailablePlaceholder_volumeOffline => 'Volume non montato';

  @override
  String get media_unavailablePlaceholder_stillFetching =>
      'Ancora in caricamento. Tocca per riprovare.';

  @override
  String get media_unavailablePlaceholder_accessDenied =>
      'Nessun accesso alla libreria foto';

  @override
  String get attrLabel_size => 'Taglia';

  @override
  String get attrLabel_thickness_mm => 'Spessore (mm)';

  @override
  String get attrLabel_suit_style => 'Tipo di muta';

  @override
  String get attrLabel_shell_material => 'Materiale esterno';

  @override
  String get attrLabel_seal_type => 'Tipo di guarnizioni';

  @override
  String get attrLabel_volume_l => 'Volume';

  @override
  String get attrLabel_working_pressure_bar => 'Pressione di esercizio';

  @override
  String get attrLabel_tank_material => 'Materiale';

  @override
  String get attrLabel_valve_type => 'Rubinetto';

  @override
  String get attrLabel_tank_identifier => 'Identificativo';

  @override
  String get attrLabel_last_visual_inspection => 'Ultima ispezione visiva';

  @override
  String get attrLabel_last_hydro_test => 'Ultimo test idrostatico';

  @override
  String get attrLabel_connection => 'Attacco';

  @override
  String get attrLabel_cold_water_rated => 'Adatto ad acque fredde';

  @override
  String get attrLabel_bcd_style => 'Stile';

  @override
  String get attrLabel_lift_capacity_kg => 'Capacità di sollevamento';

  @override
  String get attrLabel_heel_type => 'Tallone';

  @override
  String get attrLabel_blade_style => 'Pala';

  @override
  String get attrLabel_mount => 'Montaggio';

  @override
  String get attrLabel_connectivity => 'Connettività';

  @override
  String get attrLabel_lens_config => 'Lente';

  @override
  String get attrLabel_prescription => 'Lenti graduate';

  @override
  String get attrLabel_weight_style => 'Stile';

  @override
  String get attrLabel_lumens => 'Lumen';

  @override
  String get attrLabel_beam_type => 'Fascio';

  @override
  String get attrLabel_depth_rating_m => 'Profondità massima';

  @override
  String get attrLabel_smb_type => 'Tipo';

  @override
  String get attrLabel_length_m => 'Lunghezza';

  @override
  String get attrLabel_reel_type => 'Tipo';

  @override
  String get attrLabel_line_length_m => 'Lunghezza sagola';

  @override
  String get attrLabel_blade_material => 'Materiale della lama';

  @override
  String get attrLabel_tip_type => 'Punta';

  @override
  String get attrLabel_glove_type => 'Tipo';

  @override
  String get attrLabel_sole_type => 'Suola';

  @override
  String get attrLabel_buoyancy_kg => 'Galleggiabilità';

  @override
  String get attrLabel_dry_weight_kg => 'Peso a secco';

  @override
  String get attrLabel_unit_type => 'Tipo di unità';

  @override
  String get attrLabel_mount_configuration => 'Montaggio';

  @override
  String get attrLabel_scrubber_type => 'Tipo di calce';

  @override
  String get attrLabel_scrubber_duration_h => 'Durata calce (h)';

  @override
  String get attrLabel_o2_cell_count => 'Celle O2';

  @override
  String get attrLabel_diluent_cylinder_l => 'Bombola diluente';

  @override
  String get attrLabel_o2_cylinder_l => 'Bombola O2';

  @override
  String get attrLabel_dpv_style => 'Stile';

  @override
  String get attrLabel_burn_time_h => 'Autonomia';

  @override
  String get attrLabel_battery_type => 'Batteria';

  @override
  String get attrLabel_battery_capacity_wh => 'Capacità batteria (Wh)';

  @override
  String get attrLabel_motor_type => 'Motore';

  @override
  String get attrLabel_speed_mps => 'Velocità massima';

  @override
  String get attrChoice_unit_type_eccr => 'CCR elettronico (eCCR)';

  @override
  String get attrChoice_unit_type_mccr => 'CCR manuale (mCCR)';

  @override
  String get attrChoice_unit_type_hccr => 'CCR ibrido (hCCR)';

  @override
  String get attrChoice_unit_type_scr_cmf => 'SCR - flusso di massa costante';

  @override
  String get attrChoice_unit_type_scr_pascr => 'SCR - addizione passiva';

  @override
  String get attrChoice_unit_type_scr_escr => 'SCR - controllo elettronico';

  @override
  String get attrChoice_mount_configuration_back => 'Montaggio dorsale';

  @override
  String get attrChoice_mount_configuration_chest => 'Montaggio frontale';

  @override
  String get attrChoice_mount_configuration_sidemount => 'Sidemount';

  @override
  String get attrChoice_scrubber_type_axial => 'Assiale';

  @override
  String get attrChoice_scrubber_type_radial => 'Radiale';

  @override
  String get attrChoice_suit_style_full => 'Muta intera';

  @override
  String get attrChoice_suit_style_shorty => 'Shorty';

  @override
  String get attrChoice_suit_style_two_piece => 'Due pezzi';

  @override
  String get attrChoice_suit_style_semi_dry => 'Semistagna';

  @override
  String get attrChoice_shell_material_trilaminate => 'Trilaminato';

  @override
  String get attrChoice_shell_material_neoprene => 'Neoprene';

  @override
  String get attrChoice_shell_material_crushed_neoprene => 'Neoprene compresso';

  @override
  String get attrChoice_shell_material_vulcanized_rubber =>
      'Gomma vulcanizzata';

  @override
  String get attrChoice_seal_type_latex => 'Lattice';

  @override
  String get attrChoice_seal_type_silicone => 'Silicone';

  @override
  String get attrChoice_seal_type_neoprene => 'Neoprene';

  @override
  String get attrChoice_tank_material_aluminum => 'Alluminio';

  @override
  String get attrChoice_tank_material_steel => 'Acciaio';

  @override
  String get attrChoice_tank_material_carbon_composite =>
      'Composito di carbonio';

  @override
  String get attrChoice_valve_type_din => 'DIN';

  @override
  String get attrChoice_valve_type_yoke => 'Staffa (INT)';

  @override
  String get attrChoice_valve_type_convertible => 'Convertibile';

  @override
  String get attrChoice_connection_din => 'DIN';

  @override
  String get attrChoice_connection_yoke => 'Staffa (INT)';

  @override
  String get attrChoice_bcd_style_jacket => 'Jacket';

  @override
  String get attrChoice_bcd_style_back_inflate => 'Back-inflate';

  @override
  String get attrChoice_bcd_style_wing => 'Wing';

  @override
  String get attrChoice_bcd_style_sidemount => 'Sidemount';

  @override
  String get attrChoice_heel_type_open_heel => 'Tallone aperto';

  @override
  String get attrChoice_heel_type_full_foot => 'Piede intero';

  @override
  String get attrChoice_blade_style_paddle => 'Pala piena';

  @override
  String get attrChoice_blade_style_split => 'Split';

  @override
  String get attrChoice_blade_style_vented => 'Ventilata';

  @override
  String get attrChoice_mount_wrist => 'Polso';

  @override
  String get attrChoice_mount_console => 'Consolle';

  @override
  String get attrChoice_mount_hud => 'HUD';

  @override
  String get attrChoice_connectivity_ble => 'Bluetooth (BLE)';

  @override
  String get attrChoice_connectivity_usb => 'USB';

  @override
  String get attrChoice_connectivity_infrared => 'Infrarossi';

  @override
  String get attrChoice_connectivity_none => 'Nessuna';

  @override
  String get attrChoice_lens_config_single => 'Monolente';

  @override
  String get attrChoice_lens_config_twin => 'Bilente';

  @override
  String get attrChoice_lens_config_frameless => 'Senza telaio';

  @override
  String get attrChoice_weight_style_belt => 'Cintura';

  @override
  String get attrChoice_weight_style_integrated => 'Integrato';

  @override
  String get attrChoice_weight_style_trim => 'Trim';

  @override
  String get attrChoice_weight_style_ankle => 'Caviglia';

  @override
  String get attrChoice_beam_type_spot => 'Spot';

  @override
  String get attrChoice_beam_type_flood => 'Diffuso';

  @override
  String get attrChoice_beam_type_adjustable => 'Regolabile';

  @override
  String get attrChoice_smb_type_open => 'Aperta';

  @override
  String get attrChoice_smb_type_closed => 'Chiusa';

  @override
  String get attrChoice_reel_type_spool => 'Spool';

  @override
  String get attrChoice_reel_type_ratchet => 'Mulinello a cricchetto';

  @override
  String get attrChoice_blade_material_stainless => 'Acciaio inox';

  @override
  String get attrChoice_blade_material_titanium => 'Titanio';

  @override
  String get attrChoice_tip_type_pointed => 'Appuntita';

  @override
  String get attrChoice_tip_type_blunt => 'Smussata';

  @override
  String get attrChoice_tip_type_line_cutter => 'Tagliacime';

  @override
  String get attrChoice_glove_type_five_finger => 'Cinque dita';

  @override
  String get attrChoice_glove_type_mitt => 'Muffola';

  @override
  String get attrChoice_glove_type_dry => 'Stagno';

  @override
  String get attrChoice_sole_type_hard => 'Suola rigida';

  @override
  String get attrChoice_sole_type_soft => 'Suola morbida';

  @override
  String get attrChoice_dpv_style_tow_behind => 'A traino';

  @override
  String get attrChoice_dpv_style_ride_on => 'Cavalcabile';

  @override
  String get attrChoice_dpv_style_handheld => 'A mano';

  @override
  String get attrChoice_battery_type_lithium_ion => 'Ioni di litio';

  @override
  String get attrChoice_battery_type_nimh => 'NiMH';

  @override
  String get attrChoice_battery_type_lead_acid => 'Piombo-acido';

  @override
  String get attrChoice_motor_type_brushless => 'Brushless';

  @override
  String get attrChoice_motor_type_brushed => 'Con spazzole';

  @override
  String get equipment_edit_customFieldsTitle => 'Campi personalizzati';

  @override
  String get equipment_edit_addCustomField => 'Aggiungi campo personalizzato';

  @override
  String get attr_flagYes => 'Sì';

  @override
  String get attr_flagNo => 'No';

  @override
  String get equipment_edit_invalidThickness => 'Usa 5, 5/4 o 7/5/3';

  @override
  String get statistics_progression_divesBySuitThickness_title =>
      'Immersioni per spessore della muta';

  @override
  String get statistics_progression_divesBySuitThickness_subtitle =>
      'Spessore principale della muta nelle tue immersioni';

  @override
  String get statistics_progression_divesBySuitThickness_empty =>
      'Nessuna immersione con spessore della muta registrato';

  @override
  String get statistics_progression_divesBySuitThickness_error =>
      'Impossibile caricare i dati sullo spessore';

  @override
  String get diveLog_filter_sectionSuitThickness => 'Spessore della muta (mm)';

  @override
  String get diveLog_filter_thicknessMin => 'Min';

  @override
  String get diveLog_filter_thicknessMax => 'Max';

  @override
  String get safetySettings_noFlyHeader => 'Volare dopo l\'immersione';

  @override
  String get safetySettings_noFlyPreset_standard => 'Standard (12/18/24 h)';

  @override
  String get safetySettings_noFlyPreset_strict => 'Rigoroso (18/24/48 h)';

  @override
  String get safetySettings_noFlyPreset_subtitle =>
      'Intervalli indicativi dopo una singola immersione senza deco, immersioni ripetitive e immersioni con deco';

  @override
  String get flightWindow_closed => 'Niente più immersioni prima del volo';

  @override
  String get flightWindow_conflict =>
      'Il tuo tempo di no-fly si estende oltre la partenza del volo';

  @override
  String flightWindow_departs(String time) {
    return 'Il volo parte $time';
  }

  @override
  String flightWindow_openTitle(String remaining) {
    return 'Tempo di immersione rimanente: $remaining';
  }

  @override
  String flightWindow_surfaceBy(String time) {
    return 'Riemergere entro $time';
  }

  @override
  String safetyHub_noFly_active_title(String remaining) {
    return 'No-fly: mancano $remaining';
  }

  @override
  String safetyHub_noFly_until(String time) {
    return 'Fino alle $time';
  }

  @override
  String get safetyHub_noFly_clear_title => 'Nessuna restrizione di volo';

  @override
  String get safetyHub_noFly_clear_subtitle =>
      'Nessuna restrizione di volo attiva';

  @override
  String safetyHub_noFly_category_single(int hours) {
    return 'Dopo una singola immersione senza deco: linea guida di $hours h';
  }

  @override
  String safetyHub_noFly_category_repetitive(int hours) {
    return 'Dopo immersioni ripetitive: linea guida di $hours h';
  }

  @override
  String safetyHub_noFly_category_deco(int hours) {
    return 'Dopo un\'immersione con decompressione: linea guida di $hours h';
  }

  @override
  String get safetyHub_noFly_disclaimer =>
      'Linee guida DAN/UHMS dall\'ultima immersione. Non sostituisce il tempo no-fly del tuo computer subacqueo.';

  @override
  String get diveLog_detail_altitudeMismatch_title => 'Il sito è in quota';

  @override
  String get diveLog_detail_altitudeMismatch_subtitle =>
      'Questo sito registra un\'altitudine ma l\'immersione non ne ha una, quindi l\'analisi di decompressione ha assunto il livello del mare. Imposta l\'altitudine dell\'immersione per correggere.';

  @override
  String diveLog_detail_sacVolumeHint(String unit) {
    return 'Aggiungi il volume della bombola per mostrare il consumo SAC in $unit/min';
  }

  @override
  String safetyHub_alert_noFly(String remaining) {
    return 'No-fly: mancano $remaining';
  }

  @override
  String get emergencyCard_title => 'Emergenza';

  @override
  String emergencyCard_callDan(String name) {
    return 'Chiama $name';
  }

  @override
  String get emergencyCard_callDan_subtitle =>
      'Linea di emergenza subacquei. Chiama prima: coordinano evacuazione e invio in camera iperbarica.';

  @override
  String emergencyCard_ems(String number) {
    return 'Emergenze locali: $number';
  }

  @override
  String get emergencyCard_diverSection => 'Subacqueo';

  @override
  String emergencyCard_bloodType(String value) {
    return 'Gruppo sanguigno: $value';
  }

  @override
  String emergencyCard_allergies(String value) {
    return 'Allergie: $value';
  }

  @override
  String emergencyCard_medications(String value) {
    return 'Farmaci: $value';
  }

  @override
  String get emergencyCard_contactsSection => 'Contatti di emergenza';

  @override
  String get emergencyCard_insuranceSection => 'Assicurazione subacquea';

  @override
  String emergencyCard_insurancePolicy(String number) {
    return 'Polizza $number';
  }

  @override
  String get emergencyCard_chambersSection => 'Camere iperbariche';

  @override
  String get emergencyCard_chambersNote =>
      'La disponibilità cambia. Chiama sempre prima la linea di emergenza subacquei per l\'invio.';

  @override
  String emergencyCard_chamberVerified(String date) {
    return 'Dati verificati $date';
  }

  @override
  String get emergencyCard_chambersNearby => 'Camere più vicine';

  @override
  String emergencyCard_chamberViewAll(int count) {
    return 'Vedi tutte le $count camere';
  }

  @override
  String get emergencyCard_chambersNoneNearby =>
      'Nessuna camera nel raggio disponibile. Chiama la linea di emergenza per subacquei: ti indirizzerà al centro più vicino in grado di trattarti.';

  @override
  String get emergencyCard_chamberCapability_divingEmergency =>
      'Tratta gli incidenti subacquei';

  @override
  String get emergencyCard_chamberCapability_hyperbaricUnit =>
      'Unità iperbarica ospedaliera';

  @override
  String get emergencyCard_chamberCapability_elective =>
      'Solo terapia elettiva';

  @override
  String get emergencyCard_chamberCapability_unknown =>
      'Capacità non confermata';

  @override
  String get emergencyCard_chamberAvailability_h24 => '24 h';

  @override
  String get emergencyCard_chamberAvailability_onCall => 'Reperibilità';

  @override
  String get emergencyCard_chamberAvailability_businessHours =>
      'Orario di servizio';

  @override
  String get emergencyCard_chamberUnverified => 'Non confermato con il centro';

  @override
  String get chambersDirectory_title => 'Camere iperbariche';

  @override
  String get chambersDirectory_search => 'Cerca per nome, città o paese';

  @override
  String get chambersDirectory_empty =>
      'Nessuna camera corrisponde alla ricerca.';

  @override
  String chambersDirectory_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count camere',
      one: '1 camera',
    );
    return '$_temp0';
  }

  @override
  String get emergencyCard_hideChamber => 'Nascondi';

  @override
  String get emergencyCard_chamberHidden => 'Camera nascosta';

  @override
  String get emergencyCard_undo => 'Annulla';

  @override
  String get emergencyCard_addChamber => 'Aggiungi camera';

  @override
  String get emergencyCard_deleteChamber => 'Elimina';

  @override
  String emergencyCard_regionLabel(String region) {
    return 'Regione: $region';
  }

  @override
  String get emergencyCard_regionUnknown =>
      'Regione sconosciuta: si usa la linea mondiale';

  @override
  String get emergencyCard_noDiverData =>
      'Nessun dato del profilo subacqueo. Aggiungi contatti di emergenza, dati medici e assicurazione nel profilo subacqueo.';

  @override
  String get addChamber_title => 'Aggiungi camera';

  @override
  String get addChamber_name => 'Nome';

  @override
  String get addChamber_country => 'Codice paese (es. IT)';

  @override
  String get addChamber_city => 'Città';

  @override
  String get addChamber_phone => 'Telefono';

  @override
  String get addChamber_notes => 'Note';

  @override
  String get addChamber_save => 'Salva';

  @override
  String get addChamber_nameRequired => 'Il nome è obbligatorio';

  @override
  String get addChamber_countryRequired => 'Il codice paese è obbligatorio';

  @override
  String get addChamber_phoneRequired => 'Il numero di telefono è obbligatorio';

  @override
  String get safetyHub_emergencyCardLink => 'Scheda di emergenza';

  @override
  String get safetyHub_emergencyCardLink_subtitle =>
      'Offline: linea diretta, emergenze, camere, i tuoi dati medici e assicurativi';

  @override
  String get dashboard_quickAction_emergency => 'Scheda di emergenza';

  @override
  String get incidents_title => 'Registro dei quasi incidenti';

  @override
  String get incidents_empty =>
      'Nessun quasi incidente registrato. Annotare cosa è quasi andato storto - senza giudizio - rende visibili gli schemi prima che diventino incidenti.';

  @override
  String get incidents_add => 'Registra quasi incidente';

  @override
  String get incidents_linkedDive => 'Collegato a un\'immersione';

  @override
  String get incidents_delete_confirm =>
      'Eliminare questo rapporto di quasi incidente?';

  @override
  String get incidents_notFound =>
      'Segnalazione di quasi incidente non trovata';

  @override
  String get incidentEdit_title_new => 'Registra quasi incidente';

  @override
  String get incidentEdit_title_edit => 'Modifica quasi incidente';

  @override
  String get incidentEdit_category => 'Categoria';

  @override
  String get incidentEdit_severity => 'Gravità';

  @override
  String get incidentEdit_severity_minor => 'Lieve';

  @override
  String get incidentEdit_severity_moderate => 'Moderato';

  @override
  String get incidentEdit_severity_serious => 'Serio';

  @override
  String get incidentEdit_date => 'Quando è successo';

  @override
  String get incidentEdit_narrative => 'Cosa è successo';

  @override
  String get incidentEdit_narrative_hint =>
      'Solo i fatti, con parole tue. Resta privato.';

  @override
  String get incidentEdit_narrative_required => 'Descrivi cosa è successo';

  @override
  String get incidentEdit_contributingFactors =>
      'Cosa ha contribuito (facoltativo)';

  @override
  String get incidentEdit_lessonsLearned =>
      'Cosa aiuterebbe la prossima volta (facoltativo)';

  @override
  String get incidentEdit_save => 'Salva';

  @override
  String get incidentEdit_privacyNote =>
      'I rapporti di quasi incidente si sincronizzano tra i tuoi dispositivi e sono inclusi nei backup, ma mai nelle esportazioni o nelle pagine condivise del logbook.';

  @override
  String get incidentCategory_buoyancy => 'Assetto';

  @override
  String get incidentCategory_gasSupply => 'Erogazione gas';

  @override
  String get incidentCategory_equipment => 'Attrezzatura';

  @override
  String get incidentCategory_buddySeparation => 'Separazione dal compagno';

  @override
  String get incidentCategory_marineLife => 'Vita marina';

  @override
  String get incidentCategory_boatSurface => 'Barca / superficie';

  @override
  String get incidentCategory_medical => 'Medico';

  @override
  String get incidentCategory_planning => 'Pianificazione';

  @override
  String get incidentCategory_other => 'Altro';

  @override
  String get safetyHub_incidentsLink => 'Registro dei quasi incidenti';

  @override
  String get safetyHub_incidentsLink_subtitle =>
      'Note private e non punitive sugli incidenti';

  @override
  String get diveLog_detail_menu_logNearMiss => 'Registra quasi incidente';

  @override
  String diveLog_detail_linkedIncidents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quasi incidenti collegati a questa immersione',
      one: '1 quasi incidente collegato a questa immersione',
    );
    return '$_temp0';
  }

  @override
  String get planning_card_noFly_subtitle =>
      'Conto alla rovescia indicativo dalle ultime immersioni';

  @override
  String get settings_section_safety_title => 'Sicurezza';

  @override
  String get settings_section_safety_subtitle =>
      'Regole di revisione e volo dopo l\'immersione';

  @override
  String get settings_section_security_title => 'Sicurezza dell\'app';

  @override
  String get settings_section_security_subtitle =>
      'Blocco app e crittografia del database';

  @override
  String get settings_security_appLock => 'Blocco app';

  @override
  String get settings_security_appLock_subtitle =>
      'Richiedi la password o la biometria per aprire l\'app';

  @override
  String get settings_security_biometrics => 'Sblocca con la biometria';

  @override
  String get settings_security_autoLock => 'Blocco automatico';

  @override
  String get settings_security_autoLock_immediately => 'Immediatamente';

  @override
  String settings_security_autoLock_minutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Dopo $minutes minuti',
      one: 'Dopo 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get settings_security_autoLock_never => 'Mai';

  @override
  String get settings_security_encryption => 'Crittografa database';

  @override
  String get settings_security_encryption_subtitle =>
      'Proteggi il file del tuo diario di immersioni con la crittografia a riposo. La crittografia può influire sulle prestazioni.';

  @override
  String get settings_security_encryption_progress_backup =>
      'Creazione del backup di sicurezza...';

  @override
  String get settings_security_encryption_progress_encrypt =>
      'Crittografia del database...';

  @override
  String get settings_security_encryption_progress_decrypt =>
      'Decrittografia del database...';

  @override
  String get settings_security_encryption_progress_reopen =>
      'Riapertura del database...';

  @override
  String get settings_security_changePassword => 'Cambia password';

  @override
  String get settings_security_regenerateRecovery => 'Nuovo codice di recupero';

  @override
  String get settings_security_setPassword => 'Imposta la password dell\'app';

  @override
  String get settings_security_password => 'Password';

  @override
  String get settings_security_confirmPassword => 'Conferma password';

  @override
  String get settings_security_currentPassword => 'Password attuale';

  @override
  String get settings_security_newPassword => 'Nuova password';

  @override
  String get settings_security_passwordTooShort =>
      'La password deve contenere almeno 4 caratteri.';

  @override
  String get settings_security_passwordMismatch =>
      'Le password non coincidono.';

  @override
  String get settings_security_wrongPassword => 'Password errata.';

  @override
  String get settings_security_recoveryCode_title =>
      'Il tuo codice di recupero';

  @override
  String get settings_security_recoveryCode_explain =>
      'Annotalo e conservalo in un luogo sicuro. È l\'unico modo per sbloccare l\'app se dimentichi la password e sostituisce qualsiasi codice di recupero precedente.';

  @override
  String get settings_security_recoveryCode_savedConfirm =>
      'Ho salvato il mio codice di recupero';

  @override
  String get settings_security_disableBlockedByEncryption_title =>
      'La crittografia è attiva';

  @override
  String get settings_security_disableBlockedByEncryption_body =>
      'Disattiva prima la crittografia del database, poi il blocco app. Il database crittografato richiede una credenziale.';

  @override
  String get settings_security_enableEncryption_title =>
      'Crittografare il database?';

  @override
  String get settings_security_enableEncryption_body =>
      'Prima viene creato un backup di sicurezza, poi il file del database viene ricrittografato sul posto. Con diari grandi può richiedere tempo. La crittografia può influire sulle prestazioni.';

  @override
  String get settings_security_disableEncryption_title =>
      'Disattivare la crittografia?';

  @override
  String get settings_security_disableEncryption_body =>
      'Il file del database tornerà a essere salvato non crittografato su disco.';

  @override
  String get settings_security_turnOffAppLock_title =>
      'Disattivare il blocco app?';

  @override
  String get settings_security_turnOffAppLock_body =>
      'L\'app si aprirà senza chiedere la password.';

  @override
  String get settings_security_unlock_title => 'Inserisci la password';

  @override
  String get settings_security_cancel => 'Annulla';

  @override
  String get settings_security_continue => 'Continua';

  @override
  String get settings_security_done => 'Fatto';

  @override
  String get settings_security_turnOff => 'Disattiva';

  @override
  String get dataQuality_inbox_title => 'Qualità dei dati';

  @override
  String get dataQuality_badge_tooltip => 'Controllo della qualità dei dati';

  @override
  String get dataQuality_scan_start => 'Analizza la libreria';

  @override
  String dataQuality_scan_progress(int done, int total) {
    return 'Controllate $done immersioni su $total';
  }

  @override
  String get dataQuality_scan_cancel => 'Annulla';

  @override
  String dataQuality_scan_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scansione completata - $count elementi da rivedere',
      one: 'Scansione completata - 1 elemento da rivedere',
      zero: 'Scansione completata - nessun nuovo rilievo',
    );
    return '$_temp0';
  }

  @override
  String dataQuality_scan_errors(int count) {
    return 'Non è stato possibile controllare completamente $count immersioni';
  }

  @override
  String dataQuality_lastScan(String when) {
    return 'Ultima scansione: $when';
  }

  @override
  String get dataQuality_neverScanned =>
      'Il tuo logbook non è ancora stato analizzato';

  @override
  String get dataQuality_empty_title => 'Tutto a posto';

  @override
  String get dataQuality_empty_subtitle =>
      'Nessun rilievo sulla qualità dei dati. Analizza la libreria per controllare le immersioni importate.';

  @override
  String get dataQuality_banner_newChecks =>
      'Sono disponibili nuovi controlli di qualità';

  @override
  String get dataQuality_banner_rescan => 'Analizza di nuovo';

  @override
  String get dataQuality_action_dismiss => 'Ignora';

  @override
  String get dataQuality_action_dismissFiltered =>
      'Ignora tutti quelli mostrati';

  @override
  String get dataQuality_action_goToDive => 'Vai all\'immersione';

  @override
  String get dataQuality_action_undo => 'Annulla';

  @override
  String get dataQuality_repair_applied => 'Correzione applicata';

  @override
  String get dataQuality_repair_noChange => 'Non c\'è nulla da correggere';

  @override
  String get dataQuality_repair_needsReview =>
      'Nessuna correzione automatica. Apri l\'immersione per correggerla.';

  @override
  String get dataQuality_repair_failed => 'Correzione non riuscita';

  @override
  String get dataQuality_chip_all => 'Tutti';

  @override
  String get dataQuality_chip_time => 'Ora';

  @override
  String get dataQuality_chip_profile => 'Profilo';

  @override
  String get dataQuality_chip_gas => 'Gas';

  @override
  String get dataQuality_chip_tanks => 'Bombole';

  @override
  String get dataQuality_chip_duplicates => 'Duplicati';

  @override
  String get dataQuality_chip_sources => 'Fonti';

  @override
  String get dataQuality_detector_clock_offset => 'Orologio e fuso orario';

  @override
  String get dataQuality_detector_duplicate => 'Probabile duplicato';

  @override
  String get dataQuality_detector_split_pair => 'Divisione accidentale';

  @override
  String get dataQuality_detector_sample_gap => 'Interruzioni nei campioni';

  @override
  String get dataQuality_detector_depth_spike => 'Picco di profondità';

  @override
  String get dataQuality_detector_impossible_rate => 'Velocità impossibile';

  @override
  String get dataQuality_detector_temp_anomaly => 'Anomalia di temperatura';

  @override
  String get dataQuality_detector_pressure_anomaly => 'Anomalia di pressione';

  @override
  String get dataQuality_detector_gas_mod => 'Incongruenza gas/MOD';

  @override
  String get dataQuality_detector_tank_assignment => 'Bombola errata';

  @override
  String get dataQuality_detector_source_conflict => 'Fonti in conflitto';

  @override
  String dataQuality_msg_clock_future(String date) {
    return 'L\'immersione è datata nel futuro ($date)';
  }

  @override
  String dataQuality_msg_clock_ancient(String date) {
    return 'L\'immersione è datata prima del 1950 ($date)';
  }

  @override
  String dataQuality_msg_clock_offset(int hours) {
    return 'L\'orologio di una fonte differisce di $hours ore';
  }

  @override
  String dataQuality_msg_clock_overlap(int minutes) {
    return 'Si sovrappone a un\'altra immersione di $minutes min';
  }

  @override
  String dataQuality_msg_duplicate(int percent, int minutes) {
    return '$percent% di corrispondenza con un\'immersione distante $minutes min';
  }

  @override
  String dataQuality_msg_split(int minutes) {
    return 'Lo stesso computer è ripreso dopo un intervallo di superficie di $minutes min';
  }

  @override
  String dataQuality_msg_gap(int count, String longest) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count interruzioni nei campioni',
      one: '1 interruzione nei campioni',
    );
    return '$_temp0, la più lunga $longest';
  }

  @override
  String dataQuality_msg_spike(String depth, String time) {
    return 'Picco di profondità fino a $depth alle $time';
  }

  @override
  String dataQuality_msg_negativeDepth(int count) {
    return '$count campioni di profondità negativa';
  }

  @override
  String dataQuality_msg_maxDepthMismatch(String stored, String profile) {
    return 'Profondità massima registrata $stored, ma il profilo mostra $profile';
  }

  @override
  String dataQuality_msg_rate(String rate, int seconds) {
    return 'Velocità verticale di $rate mantenuta per $seconds s';
  }

  @override
  String dataQuality_msg_tempRange(String min, String max) {
    return 'Temperatura dell\'acqua fuori dall\'intervallo plausibile ($min a $max)';
  }

  @override
  String get dataQuality_msg_tempUnitBug =>
      'I valori sembrano un errore di unità di temperatura';

  @override
  String dataQuality_msg_tempJump(String delta) {
    return 'La temperatura è saltata di $delta in un solo campione';
  }

  @override
  String dataQuality_msg_tempScalar(String temp) {
    return 'La temperatura dell\'acqua registrata $temp non è plausibile';
  }

  @override
  String dataQuality_msg_pressureSwap(String end, String start) {
    return 'La pressione finale $end è superiore alla pressione iniziale $start';
  }

  @override
  String dataQuality_msg_pressureEndpoint(String record, String series) {
    return 'Il record della bombola indica $record, ma la serie del sensore mostra $series';
  }

  @override
  String dataQuality_msg_pressureRise(String rise) {
    return 'La pressione è aumentata di $rise durante l\'immersione senza cambio gas';
  }

  @override
  String dataQuality_msg_sac(String sac) {
    return 'Il consumo in superficie implicito di $sac non è plausibile';
  }

  @override
  String dataQuality_msg_ppo2(String ppo2, String gas, String depth) {
    return 'La ppO2 ha raggiunto $ppo2 con $gas a $depth';
  }

  @override
  String dataQuality_msg_hypoxic(String gas) {
    return 'Miscela ipossica ($gas) indicata in uso in superficie';
  }

  @override
  String dataQuality_msg_switchMod(String depth, String mod) {
    return 'Il cambio gas a $depth supera la MOD di quel gas di $mod';
  }

  @override
  String dataQuality_msg_tankInactive(String drop) {
    return 'Questa bombola ha perso $drop mentre la cronologia dei gas la indica come non in uso';
  }

  @override
  String get dataQuality_msg_twinTanks =>
      'Due bombole presentano una serie di pressione quasi identica';

  @override
  String dataQuality_msg_sourceDepth(String primary, String source) {
    return 'Le fonti non concordano sulla profondità massima: $primary contro $source';
  }

  @override
  String get dataQuality_msg_salinityHint =>
      'Il rapporto costante suggerisce una differenza nell\'impostazione acqua salata/dolce';

  @override
  String get dataQuality_msg_sourceDuration =>
      'Le fonti non concordano sulla durata dell\'immersione';

  @override
  String get dataQuality_msg_sourceTemp =>
      'Le fonti non concordano sulla temperatura dell\'acqua';

  @override
  String dataQuality_repairLabel_shiftTime(String offset) {
    return 'Sposta l\'orario di $offset';
  }

  @override
  String get dataQuality_repairLabel_shiftImport =>
      'Sposta tutte le immersioni di questa importazione';

  @override
  String get dataQuality_repairLabel_consolidate => 'Consolida';

  @override
  String get dataQuality_repairLabel_combine => 'Unisci in un\'immersione';

  @override
  String get dataQuality_repairLabel_despike => 'Rimuovi picco';

  @override
  String get dataQuality_repairLabel_clampNegative =>
      'Azzera le profondità sopra la superficie';

  @override
  String get dataQuality_repairLabel_smoothRates =>
      'Attenua le velocità impossibili';

  @override
  String get dataQuality_repairLabel_fillGaps => 'Colma le interruzioni';

  @override
  String get dataQuality_repairLabel_smoothTemp => 'Attenua la temperatura';

  @override
  String get dataQuality_repairLabel_convertTemp => 'Converti la temperatura';

  @override
  String get dataQuality_repairLabel_recompute => 'Ricalcola dal profilo';

  @override
  String get dataQuality_repairLabel_swapPressures =>
      'Scambia pressione iniziale/finale';

  @override
  String get dataQuality_repairLabel_setFromSeries =>
      'Usa i valori del sensore';

  @override
  String get dataQuality_repairLabel_swapSeries =>
      'Scambia le serie delle bombole';

  @override
  String get dataQuality_repairLabel_reassignSeries =>
      'Sposta la serie su un\'altra bombola';

  @override
  String get dataQuality_repairLabel_setPrimary =>
      'Rendi questa fonte principale';

  @override
  String get dataQuality_repairLabel_split => 'Dividi in immersioni separate';

  @override
  String get dataQuality_repairLabel_compare => 'Confronta i profili';

  @override
  String get dataQuality_settings_title => 'Qualità dei dati';

  @override
  String get dataQuality_settings_subtitle =>
      'Scegli quali controlli eseguire durante la scansione';

  @override
  String dataQuality_summary_flagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi segnalati da rivedere',
      one: '1 elemento segnalato da rivedere',
    );
    return '$_temp0';
  }

  @override
  String get dataQuality_summary_review => 'Rivedi';

  @override
  String get dataQuality_detail_chip => 'Rivedi';

  @override
  String dataQuality_detail_chipCount(int count) {
    return 'Rivedi ($count)';
  }

  @override
  String get settings_mediaStorage_quality_section => 'Qualità di caricamento';

  @override
  String get settings_mediaStorage_quality_photos => 'Foto';

  @override
  String get settings_mediaStorage_quality_video => 'Video';

  @override
  String get settings_mediaStorage_quality_original => 'Originale';

  @override
  String get settings_mediaStorage_quality_high => 'Alta';

  @override
  String get settings_mediaStorage_quality_balanced => 'Bilanciata';

  @override
  String get settings_mediaStorage_quality_small => 'Piccola';

  @override
  String get settings_mediaStorage_quality_caveat =>
      'Con un livello di compressione impostato, gli originali a piena risoluzione non vengono caricati: rimangono solo su questo dispositivo.';

  @override
  String get settings_mediaStorage_quality_reuploadQueued =>
      'Ricaricamento in coda';

  @override
  String get settings_mediaStorage_quality_linuxFfmpegHint =>
      'Installa ffmpeg per abilitare la compressione video. Fino ad allora vengono caricati gli originali.';

  @override
  String get settings_mediaStorage_quality_saveFailed =>
      'Impossibile salvare la qualità di caricamento. Riprova.';

  @override
  String get settings_mediaStorage_quality_noTranscoderHint =>
      'Questo dispositivo non può comprimere i video. Da esso vengono caricati gli originali.';

  @override
  String get reef_section_title => 'Ecosistema';

  @override
  String get reef_section_sourcesTooltip => 'Fonti dei dati';

  @override
  String get reef_section_loadError =>
      'Impossibile caricare i dati dell\'ecosistema al momento';

  @override
  String get reef_habitat_title => 'Habitat della barriera';

  @override
  String get reef_habitat_onReef => 'Su una barriera corallina';

  @override
  String reef_habitat_onReefWithThreat(String threat) {
    return 'Su una barriera corallina, livello di minaccia $threat';
  }

  @override
  String get reef_habitat_noReef =>
      'Nessuna barriera corallina mappata in questa posizione';

  @override
  String get reef_habitat_unavailable =>
      'Impossibile verificare l\'habitat della barriera in questo momento';

  @override
  String get water_conditions_title => 'Condizioni dell\'acqua';

  @override
  String get water_conditions_unavailable =>
      'Impossibile verificare le condizioni dell\'acqua al momento';

  @override
  String get water_conditions_noData =>
      'Nessun dato satellitare sull\'acqua per questa posizione';

  @override
  String get water_conditions_freshwater =>
      'La temperatura dell\'acqua da satellite copre solo gli oceani';

  @override
  String water_conditions_anomaly(String value) {
    return 'Anomalia $value';
  }

  @override
  String reef_health_degreeHeatingWeeks(String value) {
    return 'Settimane di riscaldamento $value C-settimane';
  }

  @override
  String reef_health_seaSurface(String value) {
    return 'Superficie del mare $value';
  }

  @override
  String reef_health_asOf(String date) {
    return 'Al $date';
  }

  @override
  String get reef_health_levelNoStress => 'Nessuno stress termico';

  @override
  String get reef_health_levelWatch => 'Sorveglianza sbiancamento';

  @override
  String get reef_health_levelWarning => 'Avviso di sbiancamento';

  @override
  String get reef_health_levelAlert1 => 'Allerta sbiancamento livello 1';

  @override
  String get reef_health_levelAlert2 => 'Allerta sbiancamento livello 2';

  @override
  String get reef_health_levelAlert3 => 'Allerta sbiancamento livello 3';

  @override
  String get reef_health_levelAlert4 => 'Allerta sbiancamento livello 4';

  @override
  String get reef_health_levelAlert5 => 'Allerta sbiancamento livello 5';

  @override
  String get reef_protection_title => 'Area protetta';

  @override
  String get reef_protection_none => 'Non in un\'area marina protetta';

  @override
  String get reef_protection_unavailable =>
      'Impossibile verificare lo stato di protezione in questo momento';

  @override
  String get reef_protection_viewRegulations => 'Vedi normativa';

  @override
  String reef_protection_iucn(String category) {
    return 'IUCN $category';
  }

  @override
  String get reef_species_recordedNearby => 'Registrato nelle vicinanze';

  @override
  String get reef_species_addToExpected => 'Aggiungi alle specie attese';

  @override
  String reef_species_showAll(int count) {
    return 'Mostra tutte ($count)';
  }

  @override
  String get reef_species_showFewer => 'Mostra meno';

  @override
  String get reef_attribution_title => 'Fonti dei dati sulla barriera';

  @override
  String get reef_attribution_wri =>
      'Presenza della barriera e livello di minaccia. CC BY 3.0.';

  @override
  String get reef_attribution_noaa =>
      'Temperatura superficiale del mare e stress termico. Dominio pubblico.';

  @override
  String get reef_attribution_gbif =>
      'Dati di presenza delle specie, filtrati a CC0 e CC BY 4.0.';

  @override
  String get reef_attribution_protectedSeas =>
      'Confini delle aree marine protette. CC BY 4.0.';

  @override
  String get enum_visibilityBand_excellent => 'Eccellente';

  @override
  String get enum_visibilityBand_good => 'Buona';

  @override
  String get enum_visibilityBand_moderate => 'Moderata';

  @override
  String get enum_visibilityBand_poor => 'Scarsa';

  @override
  String visibility_range_between(String min, String max, String unit) {
    return '$min-$max $unit';
  }

  @override
  String visibility_range_over(String min, String unit) {
    return 'oltre $min $unit';
  }

  @override
  String visibility_range_under(String max, String unit) {
    return 'meno di $max $unit';
  }

  @override
  String get settings_coordinateFormat_title => 'Formato delle coordinate';

  @override
  String get settings_coordinateFormat_subtitle =>
      'Come vengono mostrate e inserite le posizioni GPS';

  @override
  String get settings_placeNameLanguage_title => 'Lingua dei nomi dei luoghi';

  @override
  String get settings_placeNameLanguage_subtitle =>
      'Usata quando paese, regione, città e specchio d\'acqua vengono ricavati dalle coordinate. I siti esistenti non vengono modificati.';

  @override
  String get settings_coordinateFormat_decimalDegrees => 'Gradi decimali';

  @override
  String get settings_coordinateFormat_degreesDecimalMinutes =>
      'Gradi e minuti decimali';

  @override
  String get settings_coordinateFormat_degreesMinutesSeconds =>
      'Gradi, minuti, secondi';

  @override
  String get settings_coordinateFormat_utm => 'UTM';

  @override
  String get settings_coordinateFormat_mgrs => 'MGRS';

  @override
  String get settings_visibilityScale_title => 'Scala di visibilità';

  @override
  String get settings_visibilityScale_subtitle =>
      'Quali distanze contano come buona visibilità dove ti immergi';

  @override
  String get settings_visibilityScale_preset_tropical => 'Tropicale';

  @override
  String get settings_visibilityScale_preset_temperate => 'Temperata';

  @override
  String get settings_visibilityScale_preset_coldWater =>
      'Acque fredde / Interne';

  @override
  String get settings_visibilityScale_preset_custom => 'Personalizzata';

  @override
  String get settings_visibilityScale_customExcellent => 'Eccellente da';

  @override
  String get settings_visibilityScale_customGood => 'Buona da';

  @override
  String get settings_visibilityScale_customModerate => 'Moderata da';

  @override
  String get settings_visibilityScale_invalidOrder =>
      'Ogni valore deve essere inferiore a quello sopra e maggiore di zero';

  @override
  String statistics_conditions_visibility_legacySuffix(String band) {
    return '$band (registrato prima della misurazione)';
  }

  @override
  String common_selection_countSelected(Object count) {
    return '$count selezionati';
  }

  @override
  String get common_selection_enterTooltip => 'Seleziona elementi';

  @override
  String get common_selection_exitTooltip => 'Esci dalla selezione';

  @override
  String get common_selection_selectAllTooltip => 'Seleziona tutto';

  @override
  String get common_selection_deselectAllTooltip => 'Deseleziona tutto';

  @override
  String common_bulkDelete_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminare $count elementi?',
      one: 'Eliminare $count elemento?',
    );
    return '$_temp0';
  }

  @override
  String get common_bulkDelete_body =>
      'Questa azione non può essere annullata.';

  @override
  String common_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eliminati',
      one: '$count eliminato',
    );
    return '$_temp0';
  }

  @override
  String get marineLife_species_delete_confirmTitle => 'Eliminare la specie?';

  @override
  String marineLife_species_delete_confirmBody(String name) {
    return 'Vuoi davvero eliminare \"$name\"?';
  }

  @override
  String marineLife_species_delete_inUseError(String name) {
    return 'Impossibile eliminare \"$name\" - ha avvistamenti';
  }

  @override
  String marineLife_species_delete_snackbar(String name) {
    return '\"$name\" eliminata';
  }

  @override
  String marineLife_species_delete_error(String error) {
    return 'Errore durante l\'eliminazione della specie: $error';
  }

  @override
  String get enum_diveField_diveNumber => 'Numero immersione';

  @override
  String get enum_diveField_dateTime => 'Data e ora';

  @override
  String get enum_diveField_siteName => 'Nome sito';

  @override
  String get enum_diveField_diveName => 'Nome immersione';

  @override
  String get enum_diveField_maxDepth => 'Profondità massima';

  @override
  String get enum_diveField_avgDepth => 'Profondità media';

  @override
  String get enum_diveField_bottomTime => 'Tempo di fondo';

  @override
  String get enum_diveField_runtime => 'Tempo totale';

  @override
  String get enum_diveField_waterTemp => 'Temperatura dell\'acqua';

  @override
  String get enum_diveField_airTemp => 'Temperatura dell\'aria';

  @override
  String get enum_diveField_visibility => 'Visibilità';

  @override
  String get enum_diveField_currentDirection => 'Direzione corrente';

  @override
  String get enum_diveField_currentStrength => 'Intensità corrente';

  @override
  String get enum_diveField_swellHeight => 'Altezza onde';

  @override
  String get enum_diveField_entryMethod => 'Metodo di ingresso';

  @override
  String get enum_diveField_exitMethod => 'Metodo di uscita';

  @override
  String get enum_diveField_waterType => 'Tipo di acqua';

  @override
  String get enum_diveField_altitude => 'Altitudine';

  @override
  String get enum_diveField_surfacePressure => 'Pressione di superficie';

  @override
  String get enum_diveField_windSpeed => 'Velocità del vento';

  @override
  String get enum_diveField_cloudCover => 'Copertura nuvolosa';

  @override
  String get enum_diveField_precipitation => 'Precipitazioni';

  @override
  String get enum_diveField_humidity => 'Umidità';

  @override
  String get enum_diveField_weatherDescription => 'Meteo';

  @override
  String get enum_diveField_primaryGas => 'Gas principale';

  @override
  String get enum_diveField_diluentGas => 'Gas diluente';

  @override
  String get enum_diveField_tankCount => 'Numero di bombole';

  @override
  String get enum_diveField_startPressure => 'Pressione iniziale';

  @override
  String get enum_diveField_endPressure => 'Pressione finale';

  @override
  String get enum_diveField_sacRate => 'Consumo SAC';

  @override
  String get enum_diveField_gasConsumed => 'Gas consumato';

  @override
  String get enum_diveField_totalWeight => 'Zavorra totale';

  @override
  String get enum_diveField_diveComputerModel => 'Computer subacqueo';

  @override
  String get enum_diveField_gradientFactorLow => 'GF basso';

  @override
  String get enum_diveField_gradientFactorHigh => 'GF alto';

  @override
  String get enum_diveField_decoAlgorithm => 'Algoritmo deco';

  @override
  String get enum_diveField_decoConservatism => 'Conservatorismo';

  @override
  String get enum_diveField_cnsStart => 'CNS iniziale';

  @override
  String get enum_diveField_cnsEnd => 'CNS finale';

  @override
  String get enum_diveField_otu => 'OTU';

  @override
  String get enum_diveField_diveMode => 'Modalità immersione';

  @override
  String get enum_diveField_setpointLow => 'Setpoint basso';

  @override
  String get enum_diveField_setpointHigh => 'Setpoint alto';

  @override
  String get enum_diveField_setpointDeco => 'Setpoint deco';

  @override
  String get enum_diveField_buddy => 'Compagno';

  @override
  String get enum_diveField_diveMaster => 'Divemaster';

  @override
  String get enum_diveField_siteLocation => 'Località del sito';

  @override
  String get enum_diveField_diveCenterName => 'Centro immersioni';

  @override
  String get enum_diveField_siteLatitude => 'Latitudine';

  @override
  String get enum_diveField_siteLongitude => 'Longitudine';

  @override
  String get enum_diveField_tripName => 'Viaggio';

  @override
  String get enum_diveField_ratingStars => 'Valutazione';

  @override
  String get enum_diveField_isFavorite => 'Preferito';

  @override
  String get enum_diveField_notes => 'Note';

  @override
  String get enum_diveField_tags => 'Tag';

  @override
  String get enum_diveField_importSource => 'Origine importazione';

  @override
  String get enum_diveField_diveTypeName => 'Tipo di immersione';

  @override
  String get enum_diveField_surfaceInterval => 'Intervallo di superficie';

  @override
  String get enum_diveField_diveNumber_short => '#';

  @override
  String get enum_diveField_dateTime_short => 'Data';

  @override
  String get enum_diveField_siteName_short => 'Sito';

  @override
  String get enum_diveField_diveName_short => 'Nome';

  @override
  String get enum_diveField_maxDepth_short => 'P max';

  @override
  String get enum_diveField_avgDepth_short => 'P med';

  @override
  String get enum_diveField_bottomTime_short => 'TF';

  @override
  String get enum_diveField_runtime_short => 'TT';

  @override
  String get enum_diveField_waterTemp_short => 'T acqua';

  @override
  String get enum_diveField_airTemp_short => 'T aria';

  @override
  String get enum_diveField_visibility_short => 'Vis';

  @override
  String get enum_diveField_currentDirection_short => 'Dir corr.';

  @override
  String get enum_diveField_currentStrength_short => 'Corr.';

  @override
  String get enum_diveField_swellHeight_short => 'Onde';

  @override
  String get enum_diveField_entryMethod_short => 'Ingr.';

  @override
  String get enum_diveField_exitMethod_short => 'Usc.';

  @override
  String get enum_diveField_waterType_short => 'Acqua';

  @override
  String get enum_diveField_altitude_short => 'Alt';

  @override
  String get enum_diveField_surfacePressure_short => 'P sup.';

  @override
  String get enum_diveField_windSpeed_short => 'Vento';

  @override
  String get enum_diveField_cloudCover_short => 'Nuvole';

  @override
  String get enum_diveField_precipitation_short => 'Precip.';

  @override
  String get enum_diveField_humidity_short => 'Umid.';

  @override
  String get enum_diveField_weatherDescription_short => 'Meteo';

  @override
  String get enum_diveField_primaryGas_short => 'Gas';

  @override
  String get enum_diveField_diluentGas_short => 'Dil';

  @override
  String get enum_diveField_tankCount_short => 'Bombole';

  @override
  String get enum_diveField_startPressure_short => 'P iniz.';

  @override
  String get enum_diveField_endPressure_short => 'P fin.';

  @override
  String get enum_diveField_sacRate_short => 'SAC';

  @override
  String get enum_diveField_gasConsumed_short => 'Gas cons.';

  @override
  String get enum_diveField_totalWeight_short => 'Zav.';

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
  String get enum_diveField_cnsStart_short => 'CNS iniz.';

  @override
  String get enum_diveField_cnsEnd_short => 'CNS fin.';

  @override
  String get enum_diveField_otu_short => 'OTU';

  @override
  String get enum_diveField_diveMode_short => 'Modo';

  @override
  String get enum_diveField_setpointLow_short => 'SP basso';

  @override
  String get enum_diveField_setpointHigh_short => 'SP alto';

  @override
  String get enum_diveField_setpointDeco_short => 'SP deco';

  @override
  String get enum_diveField_buddy_short => 'Comp.';

  @override
  String get enum_diveField_diveMaster_short => 'DM';

  @override
  String get enum_diveField_siteLocation_short => 'Località';

  @override
  String get enum_diveField_diveCenterName_short => 'Centro';

  @override
  String get enum_diveField_siteLatitude_short => 'Lat';

  @override
  String get enum_diveField_siteLongitude_short => 'Long';

  @override
  String get enum_diveField_tripName_short => 'Viaggio';

  @override
  String get enum_diveField_ratingStars_short => 'Valut.';

  @override
  String get enum_diveField_isFavorite_short => 'Pref.';

  @override
  String get enum_diveField_notes_short => 'Note';

  @override
  String get enum_diveField_tags_short => 'Tag';

  @override
  String get enum_diveField_importSource_short => 'Origine';

  @override
  String get enum_diveField_diveTypeName_short => 'Tipo';

  @override
  String get enum_diveField_surfaceInterval_short => 'IS';

  @override
  String get enum_siteField_siteName => 'Nome';

  @override
  String get enum_siteField_location => 'Località';

  @override
  String get enum_siteField_country => 'Paese';

  @override
  String get enum_siteField_region => 'Regione';

  @override
  String get enum_siteField_city => 'Città';

  @override
  String get enum_siteField_island => 'Isola';

  @override
  String get enum_siteField_bodyOfWater => 'Specchio d\'acqua';

  @override
  String get enum_siteField_diveCount => 'Numero di immersioni';

  @override
  String get enum_siteField_maxDepth => 'Profondità massima';

  @override
  String get enum_siteField_minDepth => 'Profondità minima';

  @override
  String get enum_siteField_altitude => 'Altitudine';

  @override
  String get enum_siteField_waterType => 'Tipo di acqua';

  @override
  String get enum_siteField_typicalVisibility => 'Visibilità tipica';

  @override
  String get enum_siteField_typicalCurrent => 'Corrente tipica';

  @override
  String get enum_siteField_difficulty => 'Difficoltà';

  @override
  String get enum_siteField_entryType => 'Tipo di ingresso';

  @override
  String get enum_siteField_bestSeason => 'Stagione migliore';

  @override
  String get enum_siteField_mooringNumber => 'Numero ormeggio';

  @override
  String get enum_siteField_hazards => 'Pericoli';

  @override
  String get enum_siteField_rating => 'Valutazione';

  @override
  String get enum_siteField_notes => 'Note';

  @override
  String get enum_siteField_latitude => 'Latitudine';

  @override
  String get enum_siteField_longitude => 'Longitudine';

  @override
  String get enum_siteField_siteName_short => 'Nome';

  @override
  String get enum_siteField_location_short => 'Località';

  @override
  String get enum_siteField_country_short => 'Paese';

  @override
  String get enum_siteField_region_short => 'Regione';

  @override
  String get enum_siteField_city_short => 'Città';

  @override
  String get enum_siteField_island_short => 'Isola';

  @override
  String get enum_siteField_bodyOfWater_short => 'Specchio';

  @override
  String get enum_siteField_diveCount_short => 'Immers.';

  @override
  String get enum_siteField_maxDepth_short => 'P max';

  @override
  String get enum_siteField_minDepth_short => 'P min';

  @override
  String get enum_siteField_altitude_short => 'Alt';

  @override
  String get enum_siteField_waterType_short => 'Acqua';

  @override
  String get enum_siteField_typicalVisibility_short => 'Vis';

  @override
  String get enum_siteField_typicalCurrent_short => 'Corrente';

  @override
  String get enum_siteField_difficulty_short => 'Diff.';

  @override
  String get enum_siteField_entryType_short => 'Ingr.';

  @override
  String get enum_siteField_exitMethod => 'Metodo di uscita';

  @override
  String get enum_siteField_exitMethod_short => 'Uscita';

  @override
  String get enum_siteField_bestSeason_short => 'Stagione';

  @override
  String get enum_siteField_mooringNumber_short => 'Ormeggio';

  @override
  String get enum_siteField_hazards_short => 'Pericoli';

  @override
  String get enum_siteField_rating_short => 'Valut.';

  @override
  String get enum_siteField_notes_short => 'Note';

  @override
  String get enum_siteField_latitude_short => 'Lat';

  @override
  String get enum_siteField_longitude_short => 'Long';

  @override
  String get enum_siteField_depthRange => 'Intervallo di profondità';

  @override
  String get enum_siteField_depthRange_short => 'Prof.';

  @override
  String get enum_siteField_lastDived => 'Ultima immersione';

  @override
  String get enum_siteField_lastDived_short => 'Ultima';

  @override
  String get enum_siteField_maxDepthReached => 'La tua prof. max';

  @override
  String get enum_siteField_maxDepthReached_short => 'Tuo max';

  @override
  String get enum_buddyField_buddyName => 'Nome';

  @override
  String get enum_buddyField_email => 'Email';

  @override
  String get enum_buddyField_phone => 'Telefono';

  @override
  String get enum_buddyField_certificationLevel => 'Livello di certificazione';

  @override
  String get enum_buddyField_certificationAgency => 'Agenzia di certificazione';

  @override
  String get enum_buddyField_diveCount => 'Numero di immersioni';

  @override
  String get enum_buddyField_notes => 'Note';

  @override
  String get enum_buddyField_buddyName_short => 'Nome';

  @override
  String get enum_buddyField_email_short => 'Email';

  @override
  String get enum_buddyField_phone_short => 'Tel.';

  @override
  String get enum_buddyField_certificationLevel_short => 'Livello';

  @override
  String get enum_buddyField_certificationAgency_short => 'Agenzia';

  @override
  String get enum_buddyField_diveCount_short => 'Immers.';

  @override
  String get enum_buddyField_notes_short => 'Note';

  @override
  String get enum_buddyField_lastDive => 'Ultima immersione';

  @override
  String get enum_buddyField_lastDive_short => 'Ultima';

  @override
  String get enum_tripField_tripName => 'Nome';

  @override
  String get enum_tripField_startDate => 'Data di inizio';

  @override
  String get enum_tripField_endDate => 'Data di fine';

  @override
  String get enum_tripField_durationDays => 'Durata';

  @override
  String get enum_tripField_location => 'Località';

  @override
  String get enum_tripField_tripType => 'Tipo di viaggio';

  @override
  String get enum_tripField_resortName => 'Resort';

  @override
  String get enum_tripField_liveaboardName => 'Crociera';

  @override
  String get enum_tripField_diveCount => 'Numero di immersioni';

  @override
  String get enum_tripField_totalRuntime => 'Tempo totale cumulato';

  @override
  String get enum_tripField_maxDepth => 'Profondità massima';

  @override
  String get enum_tripField_avgDepth => 'Profondità media';

  @override
  String get enum_tripField_notes => 'Note';

  @override
  String get enum_tripField_tripName_short => 'Nome';

  @override
  String get enum_tripField_startDate_short => 'Inizio';

  @override
  String get enum_tripField_endDate_short => 'Fine';

  @override
  String get enum_tripField_durationDays_short => 'Giorni';

  @override
  String get enum_tripField_location_short => 'Località';

  @override
  String get enum_tripField_tripType_short => 'Tipo';

  @override
  String get enum_tripField_resortName_short => 'Resort';

  @override
  String get enum_tripField_liveaboardName_short => 'Crociera';

  @override
  String get enum_tripField_diveCount_short => 'Immers.';

  @override
  String get enum_tripField_totalRuntime_short => 'TT cumul.';

  @override
  String get enum_tripField_maxDepth_short => 'P max';

  @override
  String get enum_tripField_avgDepth_short => 'P med';

  @override
  String get enum_tripField_notes_short => 'Note';

  @override
  String get enum_equipmentField_itemName => 'Nome';

  @override
  String get enum_equipmentField_fullName => 'Nome completo';

  @override
  String get enum_equipmentField_type => 'Tipo';

  @override
  String get enum_equipmentField_brand => 'Marca';

  @override
  String get enum_equipmentField_model => 'Modello';

  @override
  String get enum_equipmentField_serialNumber => 'Numero di serie';

  @override
  String get enum_equipmentField_size => 'Taglia';

  @override
  String get enum_equipmentField_status => 'Stato';

  @override
  String get enum_equipmentField_isActive => 'Attivo';

  @override
  String get enum_equipmentField_purchaseDate => 'Data di acquisto';

  @override
  String get enum_equipmentField_purchasePrice => 'Prezzo di acquisto';

  @override
  String get enum_equipmentField_lastServiceDate => 'Ultima revisione';

  @override
  String get enum_equipmentField_nextServiceDue => 'Prossima revisione';

  @override
  String get enum_equipmentField_daysUntilService => 'Giorni alla revisione';

  @override
  String get enum_equipmentField_serviceIntervalDays =>
      'Intervallo di revisione';

  @override
  String get enum_equipmentField_notes => 'Note';

  @override
  String get enum_equipmentField_itemName_short => 'Nome';

  @override
  String get enum_equipmentField_fullName_short => 'Nome compl.';

  @override
  String get enum_equipmentField_type_short => 'Tipo';

  @override
  String get enum_equipmentField_brand_short => 'Marca';

  @override
  String get enum_equipmentField_model_short => 'Modello';

  @override
  String get enum_equipmentField_serialNumber_short => 'N. serie';

  @override
  String get enum_equipmentField_size_short => 'Taglia';

  @override
  String get enum_equipmentField_status_short => 'Stato';

  @override
  String get enum_equipmentField_isActive_short => 'Attivo';

  @override
  String get enum_equipmentField_purchaseDate_short => 'Acquisto';

  @override
  String get enum_equipmentField_purchasePrice_short => 'Prezzo';

  @override
  String get enum_equipmentField_lastServiceDate_short => 'Revisione';

  @override
  String get enum_equipmentField_nextServiceDue_short => 'Prossima';

  @override
  String get enum_equipmentField_daysUntilService_short => 'Giorni';

  @override
  String get enum_equipmentField_serviceIntervalDays_short => 'Interv.';

  @override
  String get enum_equipmentField_notes_short => 'Note';

  @override
  String get enum_diveCenterField_centerName => 'Nome';

  @override
  String get enum_diveCenterField_city => 'Città';

  @override
  String get enum_diveCenterField_country => 'Paese';

  @override
  String get enum_diveCenterField_stateProvince => 'Stato / Provincia';

  @override
  String get enum_diveCenterField_street => 'Via';

  @override
  String get enum_diveCenterField_postalCode => 'Codice postale';

  @override
  String get enum_diveCenterField_phone => 'Telefono';

  @override
  String get enum_diveCenterField_email => 'Email';

  @override
  String get enum_diveCenterField_website => 'Sito web';

  @override
  String get enum_diveCenterField_affiliations => 'Affiliazioni';

  @override
  String get enum_diveCenterField_rating => 'Valutazione';

  @override
  String get enum_diveCenterField_latitude => 'Latitudine';

  @override
  String get enum_diveCenterField_longitude => 'Longitudine';

  @override
  String get enum_diveCenterField_diveCount => 'Numero di immersioni';

  @override
  String get enum_diveCenterField_notes => 'Note';

  @override
  String get enum_diveCenterField_centerName_short => 'Nome';

  @override
  String get enum_diveCenterField_city_short => 'Città';

  @override
  String get enum_diveCenterField_country_short => 'Paese';

  @override
  String get enum_diveCenterField_stateProvince_short => 'Prov.';

  @override
  String get enum_diveCenterField_street_short => 'Via';

  @override
  String get enum_diveCenterField_postalCode_short => 'CAP';

  @override
  String get enum_diveCenterField_phone_short => 'Tel.';

  @override
  String get enum_diveCenterField_email_short => 'Email';

  @override
  String get enum_diveCenterField_website_short => 'Sito web';

  @override
  String get enum_diveCenterField_affiliations_short => 'Affiliazioni';

  @override
  String get enum_diveCenterField_rating_short => 'Valut.';

  @override
  String get enum_diveCenterField_latitude_short => 'Lat';

  @override
  String get enum_diveCenterField_longitude_short => 'Long';

  @override
  String get enum_diveCenterField_diveCount_short => 'Immers.';

  @override
  String get enum_diveCenterField_notes_short => 'Note';

  @override
  String get enum_certificationField_certName => 'Nome';

  @override
  String get enum_certificationField_agency => 'Agenzia';

  @override
  String get enum_certificationField_level => 'Certificazione';

  @override
  String get enum_certificationField_cardNumber => 'Numero tessera';

  @override
  String get enum_certificationField_issueDate => 'Data di rilascio';

  @override
  String get enum_certificationField_expiryDate => 'Data di scadenza';

  @override
  String get enum_certificationField_instructorName => 'Nome istruttore';

  @override
  String get enum_certificationField_instructorNumber => 'Numero istruttore';

  @override
  String get enum_certificationField_expiryStatus => 'Stato di scadenza';

  @override
  String get enum_certificationField_notes => 'Note';

  @override
  String get enum_certificationField_certName_short => 'Nome';

  @override
  String get enum_certificationField_agency_short => 'Agenzia';

  @override
  String get enum_certificationField_level_short => 'Certificazione';

  @override
  String get enum_certificationField_cardNumber_short => 'Tessera';

  @override
  String get enum_certificationField_issueDate_short => 'Rilascio';

  @override
  String get enum_certificationField_expiryDate_short => 'Scadenza';

  @override
  String get enum_certificationField_instructorName_short => 'Istruttore';

  @override
  String get enum_certificationField_instructorNumber_short => 'N. istr.';

  @override
  String get enum_certificationField_expiryStatus_short => 'Stato';

  @override
  String get enum_certificationField_notes_short => 'Note';

  @override
  String get enum_courseField_courseName => 'Nome';

  @override
  String get enum_courseField_agency => 'Agenzia';

  @override
  String get enum_courseField_startDate => 'Data di inizio';

  @override
  String get enum_courseField_completionDate => 'Data di completamento';

  @override
  String get enum_courseField_durationDays => 'Durata';

  @override
  String get enum_courseField_instructorName => 'Nome istruttore';

  @override
  String get enum_courseField_instructorNumber => 'Numero istruttore';

  @override
  String get enum_courseField_location => 'Località';

  @override
  String get enum_courseField_isCompleted => 'Completato';

  @override
  String get enum_courseField_notes => 'Note';

  @override
  String get enum_courseField_courseName_short => 'Nome';

  @override
  String get enum_courseField_agency_short => 'Agenzia';

  @override
  String get enum_courseField_startDate_short => 'Inizio';

  @override
  String get enum_courseField_completionDate_short => 'Completato';

  @override
  String get enum_courseField_durationDays_short => 'Durata';

  @override
  String get enum_courseField_instructorName_short => 'Istruttore';

  @override
  String get enum_courseField_instructorNumber_short => 'N. istr.';

  @override
  String get enum_courseField_location_short => 'Località';

  @override
  String get enum_courseField_isCompleted_short => 'Fatto';

  @override
  String get enum_courseField_notes_short => 'Note';

  @override
  String get enum_fieldCategory_accommodation => 'Alloggio';

  @override
  String get enum_fieldCategory_address => 'Indirizzo';

  @override
  String get enum_fieldCategory_certification => 'Certificazione';

  @override
  String get enum_fieldCategory_conditions => 'Condizioni';

  @override
  String get enum_fieldCategory_contact => 'Contatto';

  @override
  String get enum_fieldCategory_coordinates => 'Coordinate';

  @override
  String get enum_fieldCategory_dates => 'Date';

  @override
  String get enum_fieldCategory_depth => 'Profondità';

  @override
  String get enum_fieldCategory_details => 'Dettagli';

  @override
  String get enum_fieldCategory_instructor => 'Istruttore';

  @override
  String get enum_fieldCategory_other => 'Altro';

  @override
  String get enum_fieldCategory_purchase => 'Acquisto';

  @override
  String get enum_fieldCategory_service => 'Revisione';

  @override
  String get enum_fieldCategory_statistics => 'Statistiche';

  @override
  String get species_whale_shark_name => 'Squalo balena';

  @override
  String get species_whale_shark_desc =>
      'Il pesce più grande dell\'oceano, un placido filtratore con un caratteristico disegno a pois.';

  @override
  String get species_great_white_shark_name => 'Squalo bianco';

  @override
  String get species_great_white_shark_desc =>
      'Iconico superpredatore, avvistato occasionalmente dai subacquei in gabbia nelle acque temperate.';

  @override
  String get species_great_hammerhead_shark_name => 'Squalo martello maggiore';

  @override
  String get species_great_hammerhead_shark_desc =>
      'La più grande specie di squalo martello, con testa larga e piatta e pinna dorsale alta.';

  @override
  String get species_scalloped_hammerhead_shark_name =>
      'Squalo martello smerlato';

  @override
  String get species_scalloped_hammerhead_shark_desc =>
      'Spesso avvistato in grandi banchi presso montagne sottomarine e stazioni di pulizia.';

  @override
  String get species_smooth_hammerhead_shark_name => 'Squalo martello liscio';

  @override
  String get species_smooth_hammerhead_shark_desc =>
      'Squalo martello con il margine della testa liscio e arrotondato, presente nei mari temperati.';

  @override
  String get species_whitetip_reef_shark_name => 'Squalo pinna bianca del reef';

  @override
  String get species_whitetip_reef_shark_desc =>
      'Docile abitante della barriera, spesso trovato a riposo in grotte e sotto le sporgenze durante il giorno.';

  @override
  String get species_blacktip_reef_shark_name => 'Squalo pinna nera del reef';

  @override
  String get species_blacktip_reef_shark_desc =>
      'Comune squalo di barriera delle acque basse, riconoscibile per le pinne dalla punta nera.';

  @override
  String get species_grey_reef_shark_name => 'Squalo grigio del reef';

  @override
  String get species_grey_reef_shark_desc =>
      'Predatore attivo della barriera, spesso incontrato in gruppo lungo pareti e canali.';

  @override
  String get species_caribbean_reef_shark_name => 'Squalo del reef caraibico';

  @override
  String get species_caribbean_reef_shark_desc =>
      'Lo squalo di barriera più comune nei Caraibi, robusto e curioso.';

  @override
  String get species_nurse_shark_name => 'Squalo nutrice';

  @override
  String get species_nurse_shark_desc =>
      'Abitante del fondo dai movimenti lenti, spesso trovato a riposo sotto le sporgenze coralline.';

  @override
  String get species_tawny_nurse_shark_name => 'Squalo nutrice fulvo';

  @override
  String get species_tawny_nurse_shark_desc =>
      'Abitante dei fondali indo-pacifici, riposa nelle grotte del reef e sulle distese sabbiose.';

  @override
  String get species_bull_shark_name => 'Squalo leuca';

  @override
  String get species_bull_shark_desc =>
      'Squalo tozzo e potente, presente in ambienti costieri e d\'acqua dolce in tutto il mondo.';

  @override
  String get species_tiger_shark_name => 'Squalo tigre';

  @override
  String get species_tiger_shark_desc =>
      'Grande predatore dal caratteristico disegno a strisce, incontrato nelle immersioni profonde sul reef.';

  @override
  String get species_oceanic_whitetip_shark_name => 'Squalo longimano';

  @override
  String get species_oceanic_whitetip_shark_desc =>
      'Squalo pelagico con pinne arrotondate dalla punta bianca, avvistato nelle immersioni in mare aperto.';

  @override
  String get species_thresher_shark_name => 'Squalo volpe';

  @override
  String get species_thresher_shark_desc =>
      'Riconoscibile per la pinna caudale estremamente lunga, a volte visibile presso le stazioni di pulizia.';

  @override
  String get species_pelagic_thresher_shark_name => 'Squalo volpe pelagico';

  @override
  String get species_pelagic_thresher_shark_desc =>
      'La più piccola delle volpi di mare, celebre per gli avvistamenti a Monad Shoal nelle Filippine.';

  @override
  String get species_shortfin_mako_shark_name => 'Squalo mako';

  @override
  String get species_shortfin_mako_shark_desc =>
      'Lo squalo più veloce dell\'oceano, un elegante predatore d\'altura dai riflessi blu metallico.';

  @override
  String get species_blue_shark_name => 'Verdesca';

  @override
  String get species_blue_shark_desc =>
      'Squalo pelagico slanciato di un blu intenso, spesso incontrato nelle immersioni in acqua blu.';

  @override
  String get species_spotted_wobbegong_name => 'Wobbegong maculato';

  @override
  String get species_spotted_wobbegong_desc =>
      'Squalo tappeto piatto e mimetico che giace immobile sulle scogliere rocciose australiane.';

  @override
  String get species_tasselled_wobbegong_name => 'Wobbegong frangiato';

  @override
  String get species_tasselled_wobbegong_desc =>
      'Squalo tappeto ornato, con lobi frangiati attorno alla testa, presente nelle barriere coralline.';

  @override
  String get species_epaulette_shark_name => 'Squalo epaulette';

  @override
  String get species_epaulette_shark_desc =>
      'Piccolo squalo che cammina sul fondo della barriera usando le pinne pettorali.';

  @override
  String get species_horn_shark_name => 'Squalo cornuto';

  @override
  String get species_horn_shark_desc =>
      'Abitante notturno del fondo, con creste sopra gli occhi, presente al largo della California.';

  @override
  String get species_leopard_shark_name => 'Squalo leopardo';

  @override
  String get species_leopard_shark_desc =>
      'Squalo dal bellissimo disegno, presente nelle baie poco profonde della costa pacifica statunitense.';

  @override
  String get species_pacific_angel_shark_name => 'Squalo angelo del Pacifico';

  @override
  String get species_pacific_angel_shark_desc =>
      'Predatore d\'agguato dal corpo appiattito che resta sepolto nella sabbia del fondale.';

  @override
  String get species_sand_tiger_shark_name => 'Squalo toro';

  @override
  String get species_sand_tiger_shark_desc =>
      'Squalo dall\'aspetto feroce ma docile, spesso visto sospeso in grotte e relitti.';

  @override
  String get species_zebra_shark_name => 'Squalo zebra';

  @override
  String get species_zebra_shark_desc =>
      'Squalo di barriera maculato che riposa sui fondali sabbiosi, comune nell\'Indo-Pacifico.';

  @override
  String get species_blacktip_shark_name => 'Squalo pinna nera';

  @override
  String get species_blacktip_shark_desc =>
      'Veloce squalo costiero noto per i salti rotanti, presente nelle acque calde di tutto il mondo.';

  @override
  String get species_silvertip_shark_name => 'Squalo pinna d\'argento';

  @override
  String get species_silvertip_shark_desc =>
      'Squalo di barriera intraprendente con pinne bordate di bianco, presente vicino a pareti profonde e atolli.';

  @override
  String get species_silky_shark_name => 'Squalo seta';

  @override
  String get species_silky_shark_desc =>
      'Elegante squalo pelagico dalla pelle liscia, spesso presente vicino alle scogliere al largo.';

  @override
  String get species_lemon_shark_name => 'Squalo limone';

  @override
  String get species_lemon_shark_desc =>
      'Squalo bruno-giallastro comunemente avvistato tra le mangrovie e sulle distese sabbiose poco profonde.';

  @override
  String get species_galapagos_shark_name => 'Squalo delle Galapagos';

  @override
  String get species_galapagos_shark_desc =>
      'Grande squalo di barriera presente attorno alle isole oceaniche, curioso nei confronti dei subacquei.';

  @override
  String get species_port_jackson_shark_name => 'Squalo di Port Jackson';

  @override
  String get species_port_jackson_shark_desc =>
      'Abitante notturno del fondo con marcature simili a bretelle, endemico dell\'Australia.';

  @override
  String get species_bamboo_shark_name => 'Squalo bambù dalle bande brune';

  @override
  String get species_bamboo_shark_desc =>
      'Piccolo squalo docile di fondo, comune nelle barriere coralline indo-pacifiche.';

  @override
  String get species_basking_shark_name => 'Squalo elefante';

  @override
  String get species_basking_shark_desc =>
      'Il secondo pesce più grande, un filtratore che si osserva nelle acque superficiali temperate.';

  @override
  String get species_greenland_shark_name => 'Squalo della Groenlandia';

  @override
  String get species_greenland_shark_desc =>
      'Squalo di profondità dai movimenti lenti, uno dei vertebrati più longevi della Terra.';

  @override
  String get species_cookiecutter_shark_name => 'Squalo tagliabiscotti';

  @override
  String get species_cookiecutter_shark_desc =>
      'Piccolo squalo di profondità che asporta morsi circolari da animali marini più grandi.';

  @override
  String get species_sevengill_shark_name => 'Squalo manzo';

  @override
  String get species_sevengill_shark_desc =>
      'Squalo primitivo con sette fessure branchiali, incontrato nelle immersioni temperate tra le foreste di kelp.';

  @override
  String get species_pyjama_shark_name => 'Gattuccio pigiama';

  @override
  String get species_pyjama_shark_desc =>
      'Gattuccio striato endemico del Sudafrica, presente su scogliere rocciose e foreste di kelp.';

  @override
  String get species_spiny_dogfish_name => 'Spinarolo';

  @override
  String get species_spiny_dogfish_desc =>
      'Piccolo squalo molto abbondante, con spine dorsali velenose, presente nelle acque temperate.';

  @override
  String get species_swell_shark_name => 'Gattuccio gonfiatore';

  @override
  String get species_swell_shark_desc =>
      'Gattuccio notturno che gonfia il corpo quando è minacciato, presente al largo della California.';

  @override
  String get species_giant_oceanic_manta_ray_name => 'Manta gigante';

  @override
  String get species_giant_oceanic_manta_ray_desc =>
      'La razza più grande, maestoso filtratore con un\'apertura alare fino a 7 metri.';

  @override
  String get species_reef_manta_ray_name => 'Manta di barriera';

  @override
  String get species_reef_manta_ray_desc =>
      'Specie di manta più piccola, comunemente osservata alle stazioni di pulizia delle barriere tropicali.';

  @override
  String get species_spotted_eagle_ray_name => 'Aquila di mare maculata';

  @override
  String get species_spotted_eagle_ray_desc =>
      'Razza elegante con macchie bianche e lunga coda a frusta, spesso avvistata in acqua libera.';

  @override
  String get species_common_eagle_ray_name => 'Aquila di mare comune';

  @override
  String get species_common_eagle_ray_desc =>
      'Razza dal corpo romboidale presente nell\'Atlantico orientale temperato e nel Mediterraneo.';

  @override
  String get species_blue_spotted_ribbontail_ray_name =>
      'Trigone a macchie blu';

  @override
  String get species_blue_spotted_ribbontail_ray_desc =>
      'Razza dai colori vivaci con brillanti macchie blu, comune nelle barriere indo-pacifiche.';

  @override
  String get species_blue_spotted_stingray_name => 'Pastinaca maculata di blu';

  @override
  String get species_blue_spotted_stingray_desc =>
      'Piccola pastinaca di barriera con macchie blu sparse, spesso sepolta nelle chiazze di sabbia.';

  @override
  String get species_southern_stingray_name => 'Trigone americano';

  @override
  String get species_southern_stingray_desc =>
      'Grande pastinaca dei fondali sabbiosi caraibici, celebre a Stingray City.';

  @override
  String get species_round_stingray_name => 'Trigone rotondo';

  @override
  String get species_round_stingray_desc =>
      'Piccola pastinaca circolare, comune nelle zone sabbiose poco profonde del Pacifico orientale.';

  @override
  String get species_short_tail_stingray_name => 'Trigone dalla coda corta';

  @override
  String get species_short_tail_stingray_desc =>
      'Una delle pastinache più grandi, presente nelle acque temperate dell\'emisfero australe.';

  @override
  String get species_cowtail_stingray_name => 'Trigone dalla coda a bandiera';

  @override
  String get species_cowtail_stingray_desc =>
      'Grande pastinaca scura con una caratteristica piega caudale a bandiera, presente su fondali sabbiosi vicino al reef.';

  @override
  String get species_atlantic_torpedo_ray_name => 'Torpedine atlantica';

  @override
  String get species_atlantic_torpedo_ray_desc =>
      'Torpedine capace di produrre scariche elettriche potenti, presente sui fondali sabbiosi dell\'Atlantico.';

  @override
  String get species_marbled_electric_ray_name => 'Torpedine marezzata';

  @override
  String get species_marbled_electric_ray_desc =>
      'Torpedine mediterranea dal disegno marmorizzato, capace di infliggere una scarica elettrica notevole.';

  @override
  String get species_giant_guitarfish_name => 'Pesce chitarra gigante';

  @override
  String get species_giant_guitarfish_desc =>
      'Razza dalla sagoma di squalo, presente sui fondali sabbiosi indo-pacifici vicino alle barriere coralline.';

  @override
  String get species_shovelnose_guitarfish_name =>
      'Pesce chitarra dal muso a pala';

  @override
  String get species_shovelnose_guitarfish_desc =>
      'Sagoma appiattita a metà tra razza e squalo, comune nelle secche sabbiose del Pacifico orientale.';

  @override
  String get species_smalltooth_sawfish_name => 'Pesce sega dai denti piccoli';

  @override
  String get species_smalltooth_sawfish_desc =>
      'Razza in pericolo critico con rostro dentato, presente nelle acque costiere tropicali.';

  @override
  String get species_green_sawfish_name => 'Pesce sega verde';

  @override
  String get species_green_sawfish_desc =>
      'Grande pesce sega dal corpo verde oliva, abita gli estuari dell\'Indo-Pacifico occidentale.';

  @override
  String get species_devil_ray_name => 'Diavolo di mare';

  @override
  String get species_devil_ray_desc =>
      'Grande mobula con pinne cefaliche, osservata mentre salta fuori dall\'acqua in gruppo.';

  @override
  String get species_spinetail_devil_ray_name => 'Mobula dalla coda spinosa';

  @override
  String get species_spinetail_devil_ray_desc =>
      'Mobula pelagica spesso avvistata in grandi aggregazioni vicino alla superficie.';

  @override
  String get species_lesser_devil_ray_name => 'Mobula pigmea';

  @override
  String get species_lesser_devil_ray_desc =>
      'La più piccola delle mobule, forma grandi banchi nel Golfo di California.';

  @override
  String get species_bat_ray_name => 'Razza pipistrello';

  @override
  String get species_bat_ray_desc =>
      'Razza romboidale comune nelle foreste di kelp e nelle baie sabbiose della California.';

  @override
  String get species_undulate_ray_name => 'Razza ondulata';

  @override
  String get species_undulate_ray_desc =>
      'Razza dal bellissimo disegno a linee ondulate, presente nell\'Atlantico orientale.';

  @override
  String get species_thornback_ray_name => 'Razza chiodata';

  @override
  String get species_thornback_ray_desc =>
      'Comune razza europea, con spine appuntite lungo il dorso e la coda.';

  @override
  String get species_cownose_ray_name => 'Razza dal muso di vacca';

  @override
  String get species_cownose_ray_desc =>
      'Testa caratteristicamente incavata, spesso avvistata in grandi banchi durante le migrazioni stagionali.';

  @override
  String get species_marble_ray_name => 'Trigone marmorizzato';

  @override
  String get species_marble_ray_desc =>
      'Grande pastinaca scura con macchie bianche, spesso presente alle stazioni di pulizia indo-pacifiche.';

  @override
  String get species_ocellate_river_stingray_name =>
      'Pastinaca fluviale ocellata';

  @override
  String get species_ocellate_river_stingray_desc =>
      'Pastinaca d\'acqua dolce con vistose macchie cerchiate di arancione, originaria dei fiumi sudamericani.';

  @override
  String get species_ocellaris_clownfish_name => 'Pesce pagliaccio ocellaris';

  @override
  String get species_ocellaris_clownfish_desc =>
      'Piccolo pesce a strisce arancioni e bianche, vive in simbiosi con gli anemoni di mare sulle barriere coralline.';

  @override
  String get species_clarkii_clownfish_name => 'Pesce pagliaccio di Clark';

  @override
  String get species_clarkii_clownfish_desc =>
      'Robusto pesce degli anemoni dal corpo scuro con due bande bianche, diffuso nell\'Indo-Pacifico in diverse specie di anemone.';

  @override
  String get species_tomato_clownfish_name => 'Pesce pagliaccio pomodoro';

  @override
  String get species_tomato_clownfish_desc =>
      'Pesce degli anemoni rosso-arancio brillante con un\'unica banda bianca sul capo, comune nelle barriere indo-pacifiche.';

  @override
  String get species_regal_blue_tang_name => 'Pesce chirurgo blu';

  @override
  String get species_regal_blue_tang_desc =>
      'Pesce chirurgo di un blu intenso con una macchia nera a forma di tavolozza e coda gialla, presente nelle barriere coralline indo-pacifiche.';

  @override
  String get species_yellow_tang_name => 'Pesce chirurgo giallo';

  @override
  String get species_yellow_tang_desc =>
      'Pesce chirurgo giallo brillante, comune nelle barriere hawaiane e del Pacifico, spesso visto brucare alghe in gruppo.';

  @override
  String get species_powder_blue_surgeonfish_name =>
      'Pesce chirurgo azzurro polvere';

  @override
  String get species_powder_blue_surgeonfish_desc =>
      'Splendido pesce chirurgo azzurro pallido con muso nero e pinna dorsale gialla, presente nell\'Oceano Indiano.';

  @override
  String get species_sohal_surgeonfish_name => 'Pesce chirurgo sohal';

  @override
  String get species_sohal_surgeonfish_desc =>
      'Vistoso pesce chirurgo a strisce con spina a scalpello arancione, endemico delle barriere del Mar Rosso e del Golfo Arabico.';

  @override
  String get species_blue_tang_name => 'Pesce chirurgo blu dei Caraibi';

  @override
  String get species_blue_tang_desc =>
      'Pesce chirurgo blu scuro comune nelle barriere caraibiche; i giovani sono giallo brillante.';

  @override
  String get species_emperor_angelfish_name => 'Pesce angelo imperatore';

  @override
  String get species_emperor_angelfish_desc =>
      'Grande pesce angelo con vistose strisce orizzontali blu e gialle. I giovani mostrano cerchi concentrici blu e bianchi.';

  @override
  String get species_french_angelfish_name => 'Pesce angelo francese';

  @override
  String get species_french_angelfish_desc =>
      'Grande pesce angelo scuro con squame bordate d\'oro, spesso avvistato in coppia nelle barriere caraibiche e dell\'Atlantico occidentale.';

  @override
  String get species_queen_angelfish_name => 'Pesce angelo regina';

  @override
  String get species_queen_angelfish_desc =>
      'Spettacolare pesce angelo blu e giallo con una caratteristica macchia a corona, presente nelle barriere coralline caraibiche.';

  @override
  String get species_regal_angelfish_name => 'Pesce angelo regale';

  @override
  String get species_regal_angelfish_desc =>
      'Elegante pesce angelo con bande verticali alternate arancio-bianche e blu, presente nelle barriere indo-pacifiche.';

  @override
  String get species_rock_beauty_name => 'Pesce angelo tricolore';

  @override
  String get species_rock_beauty_desc =>
      'Vistoso pesce angelo caraibico con la metà anteriore gialla e quella posteriore nera, presente presso scogliere rocciose e sporgenze.';

  @override
  String get species_gray_angelfish_name => 'Pesce angelo grigio';

  @override
  String get species_gray_angelfish_desc =>
      'Grande pesce angelo grigio con muso chiaro e parte interna delle pettorali gialla, comune nelle barriere caraibiche.';

  @override
  String get species_copperband_butterflyfish_name =>
      'Pesce farfalla dalle bande ramate';

  @override
  String get species_copperband_butterflyfish_desc =>
      'Caratteristico pesce farfalla con bande verticali arancioni e muso allungato, presente nelle barriere indo-pacifiche.';

  @override
  String get species_raccoon_butterflyfish_name => 'Pesce farfalla procione';

  @override
  String get species_raccoon_butterflyfish_desc =>
      'Pesce farfalla giallo con una mascherina scura attorno agli occhi, comune nelle barriere indo-pacifiche e hawaiane.';

  @override
  String get species_longnose_butterflyfish_name =>
      'Pesce farfalla dal muso lungo';

  @override
  String get species_longnose_butterflyfish_desc =>
      'Pesce farfalla giallo brillante con muso estremamente allungato, usato per estrarre il cibo dalle fessure delle barriere indo-pacifiche.';

  @override
  String get species_threadfin_butterflyfish_name =>
      'Pesce farfalla filamentoso';

  @override
  String get species_threadfin_butterflyfish_desc =>
      'Pesce farfalla bianco con disegno a galloni e filamento dorsale allungato, diffuso in tutto l\'Indo-Pacifico.';

  @override
  String get species_foureye_butterflyfish_name => 'Pesce farfalla quattrocchi';

  @override
  String get species_foureye_butterflyfish_desc =>
      'Pesce farfalla chiaro con un vistoso falso occhio vicino alla coda, comune nelle barriere caraibiche.';

  @override
  String get species_spotfin_butterflyfish_name =>
      'Pesce farfalla dalla pinna macchiata';

  @override
  String get species_spotfin_butterflyfish_desc =>
      'Pesce farfalla bianco e giallo con una piccola macchia scura sulla pinna dorsale, presente nell\'Atlantico occidentale.';

  @override
  String get species_banner_butterflyfish_name =>
      'Pesce bandiera del Mar Rosso';

  @override
  String get species_banner_butterflyfish_desc =>
      'Pesce bandiera bianco e nero con pinna dorsale allungata e ventre giallo, endemico del Mar Rosso.';

  @override
  String get species_moorish_idol_name => 'Idolo moresco';

  @override
  String get species_moorish_idol_desc =>
      'Iconico pesce di barriera con marcate bande nere, bianche e gialle e un lungo filamento dorsale.';

  @override
  String get species_green_moray_eel_name => 'Murena verde';

  @override
  String get species_green_moray_eel_desc =>
      'Grande murena verde che raggiunge i 2,5 m, spesso vista con la bocca spalancata nelle fessure delle barriere dell\'Atlantico occidentale.';

  @override
  String get species_giant_moray_eel_name => 'Murena gigante';

  @override
  String get species_giant_moray_eel_desc =>
      'La più grande specie di murena, supera i 3 m ed è ricoperta di macchie leopardate. Vive nelle barriere coralline indo-pacifiche.';

  @override
  String get species_spotted_moray_eel_name => 'Murena maculata';

  @override
  String get species_spotted_moray_eel_desc =>
      'Murena bianca con macchie bruno scuro, comunemente vista sbucare dalle tane del reef nei Caraibi.';

  @override
  String get species_ribbon_eel_name => 'Murena nastro';

  @override
  String get species_ribbon_eel_desc =>
      'Murena slanciata con narici a ventaglio; i maschi sono blu vivo, le femmine gialle. Vive nelle lagune sabbiose indo-pacifiche.';

  @override
  String get species_spotted_garden_eel_name => 'Anguilla giardiniera maculata';

  @override
  String get species_spotted_garden_eel_desc =>
      'Sottile anguilla bianca a macchie nere che vive in colonie sulla sabbia, ondeggiando nella corrente per catturare il plancton.';

  @override
  String get species_splendid_garden_eel_name =>
      'Anguilla giardiniera splendida';

  @override
  String get species_splendid_garden_eel_desc =>
      'Anguilla giardiniera a bande arancioni e bianche, presente in grandi colonie sabbiose del Pacifico occidentale.';

  @override
  String get species_snowflake_moray_name => 'Murena fiocco di neve';

  @override
  String get species_snowflake_moray_desc =>
      'Piccola murena dal corpo bianco con marcature nere simili a fiocchi di neve, comune tra i detriti corallini indo-pacifici.';

  @override
  String get species_mandarin_dragonet_name => 'Pesce mandarino';

  @override
  String get species_mandarin_dragonet_desc =>
      'Pesciolino dai colori brillanti con disegni psichedelici blu e arancioni, presente nelle zone detritiche del Pacifico occidentale.';

  @override
  String get species_common_lionfish_name => 'Pesce leone';

  @override
  String get species_common_lionfish_desc =>
      'Scorfano velenoso con spettacolari pinne pettorali a ventaglio e strisce rosse e bianche. Invasivo nei Caraibi.';

  @override
  String get species_leaf_scorpionfish_name => 'Scorfano foglia';

  @override
  String get species_leaf_scorpionfish_desc =>
      'Scorfano fortemente compresso a forma di foglia, ondeggia con la corrente per imitare i detriti sulle barriere indo-pacifiche.';

  @override
  String get species_stonefish_name => 'Pesce pietra';

  @override
  String get species_stonefish_desc =>
      'Il pesce più velenoso al mondo, perfettamente mimetizzato tra le rocce dei fondali indo-pacifici. Estremamente pericoloso.';

  @override
  String get species_painted_frogfish_name => 'Pesce rana dipinto';

  @override
  String get species_painted_frogfish_desc =>
      'Tozzo predatore d\'agguato con un\'esca sul capo, dal colore molto variabile. Vive nelle barriere indo-pacifiche.';

  @override
  String get species_giant_frogfish_name => 'Pesce rana gigante';

  @override
  String get species_giant_frogfish_desc =>
      'La più grande specie di pesce rana, raggiunge i 40 cm e si mimetizza alla perfezione tra spugne e detriti corallini.';

  @override
  String get species_hairy_frogfish_name => 'Pesce rana peloso';

  @override
  String get species_hairy_frogfish_desc =>
      'Pesce rana ricoperto di appendici carnose simili a vermi che imitano le alghe, un soggetto ambito dai fotografi subacquei.';

  @override
  String get species_clown_triggerfish_name => 'Pesce balestra pagliaccio';

  @override
  String get species_clown_triggerfish_desc =>
      'Pesce balestra dal disegno vistoso, con grandi macchie bianche su corpo scuro e labbra gialle, presente nelle barriere indo-pacifiche.';

  @override
  String get species_titan_triggerfish_name => 'Pesce balestra titano';

  @override
  String get species_titan_triggerfish_desc =>
      'Grande pesce balestra aggressivo, noto per caricare i subacquei vicino al nido. Comune nelle barriere coralline indo-pacifiche.';

  @override
  String get species_queen_triggerfish_name => 'Pesce balestra regina';

  @override
  String get species_queen_triggerfish_desc =>
      'Colorato pesce balestra caraibico con marcature blu sul muso e lunghi filamenti caudali.';

  @override
  String get species_picasso_triggerfish_name => 'Pesce balestra Picasso';

  @override
  String get species_picasso_triggerfish_desc =>
      'Pesce balestra con un disegno astratto di strisce blu, gialle e nere, comune sui pianori corallini indo-pacifici.';

  @override
  String get species_yellowmargin_triggerfish_name =>
      'Pesce balestra dal margine giallo';

  @override
  String get species_yellowmargin_triggerfish_desc =>
      'Grande pesce balestra beige con pinne bordate di giallo, noto per la difesa aggressiva del nido nelle barriere indo-pacifiche.';

  @override
  String get species_porcupinefish_name => 'Pesce istrice';

  @override
  String get species_porcupinefish_desc =>
      'Grande pesce spinoso che si gonfia a palla quando è minacciato, presente nelle barriere tropicali di tutto il mondo.';

  @override
  String get species_guineafowl_pufferfish_name => 'Pesce palla faraona';

  @override
  String get species_guineafowl_pufferfish_desc =>
      'Pesce palla scuro ricoperto di piccole macchie bianche, talvolta presente in una fase di colore giallo dorato nelle barriere indo-pacifiche.';

  @override
  String get species_map_pufferfish_name => 'Pesce palla mappa';

  @override
  String get species_map_pufferfish_desc =>
      'Grande pesce palla chiaro con intricate marcature scure simili a una mappa su tutto il corpo, presente nelle barriere indo-pacifiche.';

  @override
  String get species_sharpnose_pufferfish_name => 'Pesce palla dal muso aguzzo';

  @override
  String get species_sharpnose_pufferfish_desc =>
      'Minuscolo pesce palla con linee blu sul muso e coda arancione, comunemente avvistato nelle barriere caraibiche.';

  @override
  String get species_boxfish_name => 'Pesce scatola giallo';

  @override
  String get species_boxfish_desc =>
      'I giovani sono cubi giallo brillante con macchie nere. Gli adulti scuriscono verso il grigio-blu. Diffuso in tutto l\'Indo-Pacifico.';

  @override
  String get species_cowfish_name => 'Pesce mucca dalle lunghe corna';

  @override
  String get species_cowfish_desc =>
      'Pesce giallo dal corpo squadrato con caratteristiche protuberanze a corno sopra ciascun occhio, presente nelle barriere indo-pacifiche.';

  @override
  String get species_napoleon_wrasse_name => 'Pesce napoleone';

  @override
  String get species_napoleon_wrasse_desc =>
      'Enorme labride che raggiunge i 2 m, con una vistosa protuberanza frontale. Specie in pericolo e protetta, vive nelle barriere indo-pacifiche.';

  @override
  String get species_cleaner_wrasse_name => 'Labride pulitore';

  @override
  String get species_cleaner_wrasse_desc =>
      'Piccolo labride a striscia blu che gestisce le stazioni di pulizia, liberando dai parassiti i pesci più grandi nelle barriere indo-pacifiche.';

  @override
  String get species_yellowtail_coris_name => 'Coris dalla coda gialla';

  @override
  String get species_yellowtail_coris_desc =>
      'Labride colorato dal corpo maculato e coda gialla; i giovani sono arancio-rossi brillanti con marcature bianche.';

  @override
  String get species_bluehead_wrasse_name => 'Labride testablu';

  @override
  String get species_bluehead_wrasse_desc =>
      'Labride caraibico molto abbondante; i maschi terminali hanno la testa blu vivo e il corpo verde con bande bianche e nere.';

  @override
  String get species_spanish_hogfish_name => 'Pesce porco spagnolo';

  @override
  String get species_spanish_hogfish_desc =>
      'Labride viola e giallo comune nelle barriere caraibiche; i giovani si comportano da pesci pulitori.';

  @override
  String get species_bumphead_parrotfish_name =>
      'Pesce pappagallo dalla fronte bombata';

  @override
  String get species_bumphead_parrotfish_desc =>
      'La più grande specie di pesce pappagallo, raggiunge 1,3 m e ha un\'enorme protuberanza frontale. Si sposta in banchi nelle barriere indo-pacifiche.';

  @override
  String get species_stoplight_parrotfish_name => 'Pesce pappagallo semaforo';

  @override
  String get species_stoplight_parrotfish_desc =>
      'Comune pesce pappagallo caraibico, con spettacolari cambi di colore tra la fase iniziale e quella terminale.';

  @override
  String get species_queen_parrotfish_name => 'Pesce pappagallo regina';

  @override
  String get species_queen_parrotfish_desc =>
      'Grande pesce pappagallo blu-verde delle barriere caraibiche, spesso visto mordere il corallo per nutrirsi di alghe.';

  @override
  String get species_yellowtail_damselfish_name =>
      'Castagnola dalla coda gialla';

  @override
  String get species_yellowtail_damselfish_desc =>
      'Castagnola blu scuro con la coda giallo brillante, comune sulle sommità e sulle creste delle barriere caraibiche.';

  @override
  String get species_sergeant_major_name => 'Sergente maggiore';

  @override
  String get species_sergeant_major_desc =>
      'Castagnola argento e gialla con cinque marcate bande nere, presente in grandi aggregazioni nelle barriere dell\'Atlantico tropicale.';

  @override
  String get species_three_spot_damselfish_name => 'Castagnola a tre macchie';

  @override
  String get species_three_spot_damselfish_desc =>
      'Castagnola territoriale bruno scuro che difende aggressivamente il proprio orto di alghe nelle barriere caraibiche.';

  @override
  String get species_chromis_viridis_name => 'Castagnola verde-azzurra';

  @override
  String get species_chromis_viridis_desc =>
      'Piccola castagnola verde iridescente, osservata in grandi banchi sospesi sopra i coralli ramificati delle barriere indo-pacifiche.';

  @override
  String get species_blue_chromis_name => 'Castagnola blu';

  @override
  String get species_blue_chromis_desc =>
      'Castagnola planctofaga di un blu brillante, presente in grandi aggregazioni in acqua libera sopra le pareti caraibiche.';

  @override
  String get species_nassau_grouper_name => 'Cernia di Nassau';

  @override
  String get species_nassau_grouper_desc =>
      'Grande cernia caraibica con una caratteristica striscia scura sull\'occhio e disegno a bande, oggi in pericolo a causa della pesca eccessiva.';

  @override
  String get species_giant_grouper_name => 'Cernia gigante';

  @override
  String get species_giant_grouper_desc =>
      'Il più grande pesce osseo di barriera, raggiunge 2,7 m e 400 kg. Vive in grotte e relitti di tutto l\'Indo-Pacifico.';

  @override
  String get species_coral_grouper_name => 'Cernia corallina';

  @override
  String get species_coral_grouper_desc =>
      'Cernia rosso-arancio brillante ricoperta di macchie blu, specie simbolo delle barriere coralline indo-pacifiche.';

  @override
  String get species_goliath_grouper_name => 'Cernia golia';

  @override
  String get species_goliath_grouper_desc =>
      'Enorme cernia atlantica che raggiunge i 2,5 m, spesso incontrata vicino a relitti e sporgenze in Florida e nei Caraibi.';

  @override
  String get species_potato_grouper_name => 'Cernia patata';

  @override
  String get species_potato_grouper_desc =>
      'Grande cernia socievole con macchie scure a forma di patata, celebre al Cod Hole della Grande Barriera Corallina.';

  @override
  String get species_peacock_grouper_name => 'Cernia pavone';

  @override
  String get species_peacock_grouper_desc =>
      'Cernia bruno scuro con macchie blu brillanti e barre verticali chiare sulla parte posteriore, comune nelle barriere indo-pacifiche.';

  @override
  String get species_yellowfin_tuna_name => 'Tonno pinna gialla';

  @override
  String get species_yellowfin_tuna_desc =>
      'Veloce predatore pelagico con lunghe pinne dorsale e anale gialle, avvistato occasionalmente dai subacquei nei siti al largo.';

  @override
  String get species_dogtooth_tuna_name => 'Tonno dai denti di cane';

  @override
  String get species_dogtooth_tuna_desc =>
      'Potente tonno legato alla barriera, con denti prominenti, incontrato lungo le pareti profonde dell\'Indo-Pacifico.';

  @override
  String get species_great_barracuda_name => 'Barracuda gigante';

  @override
  String get species_great_barracuda_desc =>
      'Elegante predatore argenteo fino a 1,8 m con denti prominenti, spesso visto immobile vicino alle barriere tropicali.';

  @override
  String get species_blackfin_barracuda_name => 'Barracuda pinna nera';

  @override
  String get species_blackfin_barracuda_desc =>
      'Barracuda indo-pacifico noto per formare enormi banchi a tornado in siti come Barracuda Point.';

  @override
  String get species_mahi_mahi_name => 'Lampuga';

  @override
  String get species_mahi_mahi_desc =>
      'Sgargiante pesce pelagico blu-verde e oro con la fronte tozza, avvistato occasionalmente nei siti al largo.';

  @override
  String get species_giant_trevally_name => 'Carangide gigante';

  @override
  String get species_giant_trevally_desc =>
      'Potente predatore argenteo fino a 1,7 m, noto per cacciare nei canali e lungo le pareti di tutto l\'Indo-Pacifico.';

  @override
  String get species_bluefin_trevally_name => 'Carangide pinna blu';

  @override
  String get species_bluefin_trevally_desc =>
      'Elegante carangide a macchie blu, spesso visto pattugliare i bordi delle barriere indo-pacifiche in piccoli gruppi di caccia.';

  @override
  String get species_bigeye_trevally_name => 'Carangide occhi grandi';

  @override
  String get species_bigeye_trevally_desc =>
      'Carangide argenteo dai grandi occhi che forma imponenti banchi vorticosi vicino alle pareti e alle stazioni di pulizia.';

  @override
  String get species_bar_jack_name => 'Carangide barrato';

  @override
  String get species_bar_jack_desc =>
      'Elegante carangide argenteo dei Caraibi, con una caratteristica striscia blu scuro lungo il dorso che prosegue sul lobo caudale inferiore.';

  @override
  String get species_horse_eye_jack_name => 'Carangide occhio di cavallo';

  @override
  String get species_horse_eye_jack_desc =>
      'Carangide argenteo dagli occhi grandi che forma banchi vicino a barriere e relitti nei Caraibi e nell\'Atlantico occidentale.';

  @override
  String get species_yellowtail_snapper_name => 'Lutiano dalla coda gialla';

  @override
  String get species_yellowtail_snapper_desc =>
      'Lutiano slanciato con striscia laterale e coda gialle, spesso visto in banchi a mezz\'acqua sulle barriere caraibiche.';

  @override
  String get species_schoolmaster_snapper_name => 'Lutiano capobranco';

  @override
  String get species_schoolmaster_snapper_desc =>
      'Lutiano giallo-argenteo con linee blu sotto l\'occhio, presente in gruppi sotto le sporgenze delle barriere caraibiche.';

  @override
  String get species_bluestripe_snapper_name => 'Lutiano dalle strisce blu';

  @override
  String get species_bluestripe_snapper_desc =>
      'Lutiano giallo brillante con quattro strisce orizzontali blu, forma banchi fitti nelle barriere indo-pacifiche.';

  @override
  String get species_twinspot_snapper_name => 'Lutiano bimaculato';

  @override
  String get species_twinspot_snapper_desc =>
      'Grande lutiano rosso delle barriere esterne indo-pacifiche, forma talvolta banchi su pareti profonde e canali.';

  @override
  String get species_humphead_snapper_name => 'Lutiano di mezzanotte';

  @override
  String get species_humphead_snapper_desc =>
      'Grande lutiano scuro presente in banchi vicino alle ripide pareti indo-pacifiche; i giovani sono vistosamente bianchi e neri.';

  @override
  String get species_longfin_bannerfish_name => 'Pesce bandiera pinna lunga';

  @override
  String get species_longfin_bannerfish_desc =>
      'Pesce bianco e nero con una lunga pinna dorsale filamentosa e coda gialla, spesso visto in coppia nelle barriere indo-pacifiche.';

  @override
  String get species_batfish_orbicular_name => 'Pesce pipistrello orbicolare';

  @override
  String get species_batfish_orbicular_desc =>
      'Pesce argenteo a forma di disco con pinne alte, si avvicina ai subacquei per curiosità. Comune su relitti e barriere indo-pacifici.';

  @override
  String get species_batfish_teira_name => 'Pesce pipistrello pinna lunga';

  @override
  String get species_batfish_teira_desc =>
      'Pesce pipistrello dalle pinne alte con una macchia scura vicino alla pettorale, spesso visto alle stazioni di pulizia e sui relitti.';

  @override
  String get species_batfish_pinnatus_name => 'Pesce pipistrello pinnato';

  @override
  String get species_batfish_pinnatus_desc =>
      'I giovani sono nero corvino con bordi arancione vivo che ricordano un verme piatto tossico. Presente nel Pacifico occidentale.';

  @override
  String get species_banggai_cardinalfish_name => 'Pesce cardinale di Banggai';

  @override
  String get species_banggai_cardinalfish_desc =>
      'Vistoso pesce cardinale argento e nero con pinne allungate, endemico delle isole Banggai in Indonesia.';

  @override
  String get species_pajama_cardinalfish_name => 'Pesce cardinale pigiama';

  @override
  String get species_pajama_cardinalfish_desc =>
      'Insolito pesce cardinale con muso giallo, fascia scura al centro del corpo e parte posteriore maculata, vive tra i coralli dell\'Indo-Pacifico.';

  @override
  String get species_longnose_hawkfish_name => 'Pesce falco dal muso lungo';

  @override
  String get species_longnose_hawkfish_desc =>
      'Piccolo pesce bianco con un reticolo rosso e muso allungato, si appollaia su gorgonie e coralli neri.';

  @override
  String get species_arc_eye_hawkfish_name => 'Pesce falco dall\'arco oculare';

  @override
  String get species_arc_eye_hawkfish_desc =>
      'Piccolo pesce falco con un caratteristico arco arancione dietro l\'occhio, spesso appollaiato sulle formazioni coralline indo-pacifiche.';

  @override
  String get species_flame_hawkfish_name => 'Pesce falco fiamma';

  @override
  String get species_flame_hawkfish_desc =>
      'Pesce falco rosso brillante con marcature scure attorno agli occhi, si appollaia tra i coralli Pocillopora del Pacifico occidentale.';

  @override
  String get species_fire_goby_name => 'Ghiozzo di fuoco';

  @override
  String get species_fire_goby_desc =>
      'Elegante ghiozzo bianco con la prima pinna dorsale alta e coda rosso-arancio, resta sospeso sopra i detriti corallini indo-pacifici.';

  @override
  String get species_purple_firefish_name => 'Ghiozzo di fuoco viola';

  @override
  String get species_purple_firefish_desc =>
      'Delicato ghiozzo con pinne viola e un alto spuntone dorsale, resta sospeso vicino alla tana sulle barriere esterne indo-pacifiche.';

  @override
  String get species_yellownose_goby_name => 'Ghiozzo dal muso giallo';

  @override
  String get species_yellownose_goby_desc =>
      'Minuscolo ghiozzo pulitore caraibico con muso giallo e striscia laterale blu, vive su spugne e formazioni coralline.';

  @override
  String get species_citron_goby_name => 'Ghiozzo citrino';

  @override
  String get species_citron_goby_desc =>
      'Minuscolo ghiozzo giallo brillante che vive tra i rami dei coralli Acropora nelle barriere indo-pacifiche.';

  @override
  String get species_shrimp_goby_name => 'Ghiozzo dei gamberi di Steinitz';

  @override
  String get species_shrimp_goby_desc =>
      'Ghiozzo color sabbia che condivide la tana con un gambero alfeide in un rapporto di mutualismo sui fondali sabbiosi indo-pacifici.';

  @override
  String get species_neon_goby_name => 'Ghiozzo neon';

  @override
  String get species_neon_goby_desc =>
      'Minuscolo ghiozzo scuro con una brillante striscia blu neon, gestisce stazioni di pulizia sulle formazioni coralline caraibiche.';

  @override
  String get species_bluestriped_fangblenny_name => 'Bavosa dalle strisce blu';

  @override
  String get species_bluestriped_fangblenny_desc =>
      'Piccola bavosa a strisce blu che imita i labridi pulitori per strappare le squame ai pesci ignari.';

  @override
  String get species_sailfin_blenny_name => 'Bavosa velifera';

  @override
  String get species_sailfin_blenny_desc =>
      'Minuscola bavosa caraibica che solleva un\'ampia pinna dorsale a vela dalla propria tana per attirare le femmine.';

  @override
  String get species_bicolor_blenny_name => 'Bavosa bicolore';

  @override
  String get species_bicolor_blenny_desc =>
      'Piccola bavosa con la metà anteriore bruno scuro e quella posteriore arancione, sbuca dai fori delle barriere indo-pacifiche.';

  @override
  String get species_redlip_blenny_name => 'Bavosa dalle labbra rosse';

  @override
  String get species_redlip_blenny_desc =>
      'Bavosa scura con vistose labbra rosso-arancio, difende le chiazze di alghe sulle creste delle barriere caraibiche.';

  @override
  String get species_pygmy_seahorse_name => 'Cavalluccio pigmeo di Bargibant';

  @override
  String get species_pygmy_seahorse_desc =>
      'Minuscolo cavalluccio di meno di 2 cm che si confonde perfettamente con la gorgonia ospite, soggetto ambito della fotografia macro.';

  @override
  String get species_common_seahorse_name => 'Cavalluccio marino comune';

  @override
  String get species_common_seahorse_desc =>
      'Cavalluccio di taglia media presente nelle praterie di fanerogame e nei detriti corallini dell\'Indo-Pacifico, dal colore variabile.';

  @override
  String get species_thorny_seahorse_name => 'Cavalluccio spinoso';

  @override
  String get species_thorny_seahorse_desc =>
      'Cavalluccio ricoperto di lunghe spine, presente nelle praterie di fanerogame e sui fondali molli dell\'Indo-Pacifico.';

  @override
  String get species_ornate_ghost_pipefish_name => 'Pesce ago fantasma ornato';

  @override
  String get species_ornate_ghost_pipefish_desc =>
      'Pesce ago fantasma dal camuffamento elaborato, resta sospeso a testa in giù vicino a crinoidi e coralli molli dell\'Indo-Pacifico.';

  @override
  String get species_robust_ghost_pipefish_name => 'Pesce ago fantasma robusto';

  @override
  String get species_robust_ghost_pipefish_desc =>
      'Grande pesce ago fantasma che imita le fanerogame o le alghe, spesso avvistato in coppia nelle acque costiere indo-pacifiche.';

  @override
  String get species_trumpetfish_name => 'Pesce trombetta';

  @override
  String get species_trumpetfish_desc =>
      'Pesce lungo e sottile che caccia seguendo l\'ombra di pesci più grandi, presente in vari colori nelle barriere caraibiche e atlantiche.';

  @override
  String get species_cornetfish_name => 'Pesce flauto';

  @override
  String get species_cornetfish_desc =>
      'Pesce estremamente allungato, fino a 1,5 m, con un filamento caudale, spesso visto planare sui pianori corallini.';

  @override
  String get species_yellowhead_jawfish_name =>
      'Pesce mandibola dalla testa gialla';

  @override
  String get species_yellowhead_jawfish_desc =>
      'Piccolo pesce dal corpo blu e testa gialla che resta sospeso sopra la propria tana nella sabbia delle barriere caraibiche. I maschi covano le uova in bocca.';

  @override
  String get species_flamefish_name => 'Pesce cardinale fiamma';

  @override
  String get species_flamefish_desc =>
      'Piccolo pesce cardinale rosso vivo con una macchia scura sotto la seconda pinna dorsale, di giorno si nasconde nelle fessure delle barriere caraibiche.';

  @override
  String get species_longspine_squirrelfish_name =>
      'Pesce scoiattolo dalla spina lunga';

  @override
  String get species_longspine_squirrelfish_desc =>
      'Pesce notturno rosso con grandi occhi e una lunga spina dorsale, di giorno si osserva sotto le sporgenze delle barriere caraibiche.';

  @override
  String get species_soldierfish_name => 'Pesce soldato dalle grandi squame';

  @override
  String get species_soldierfish_desc =>
      'Pesce notturno rosso con enormi occhi scuri e grandi squame, di giorno forma gruppi in grotte e sotto gli strapiombi.';

  @override
  String get species_flame_angelfish_name => 'Pesce angelo fiamma';

  @override
  String get species_flame_angelfish_desc =>
      'Pesce angelo nano rosso-arancio brillante con barre verticali nere e pinne dalla punta blu, diffuso in tutto il Pacifico.';

  @override
  String get species_royal_gramma_name => 'Gramma reale';

  @override
  String get species_royal_gramma_desc =>
      'Piccolo basslet caraibico bicolore, con la metà anteriore viola e quella posteriore gialla, vive sotto le sporgenze.';

  @override
  String get species_anthias_lyretail_name => 'Anthias dalla coda a lira';

  @override
  String get species_anthias_lyretail_desc =>
      'Pesce di barriera molto abbondante, forma grandi nuvole arancioni e rosa sopra le formazioni coralline indo-pacifiche. I maschi sono viola.';

  @override
  String get species_mediterranean_grouper_name => 'Cernia bruna';

  @override
  String get species_mediterranean_grouper_desc =>
      'Grande cernia bruno scuro con marezzature chiare, predatore simbolo delle scogliere rocciose del Mediterraneo.';

  @override
  String get species_mediterranean_moray_name => 'Murena mediterranea';

  @override
  String get species_mediterranean_moray_desc =>
      'Murena bruno scuro con marezzature gialle, comunemente vista sbucare dalle fessure rocciose del Mediterraneo.';

  @override
  String get species_ornate_wrasse_name => 'Donzella pavonina';

  @override
  String get species_ornate_wrasse_desc =>
      'Colorato labride verde con marcature rosse sul capo, uno dei labridi più comuni delle scogliere mediterranee.';

  @override
  String get species_red_sea_bannerfish_name => 'Pesce farfalla mascherato';

  @override
  String get species_red_sea_bannerfish_desc =>
      'Pesce farfalla giallo brillante con una macchia scura sull\'occhio, endemico del Mar Rosso. Spesso avvistato in coppia.';

  @override
  String get species_red_sea_anemonefish_name =>
      'Pesce pagliaccio del Mar Rosso';

  @override
  String get species_red_sea_anemonefish_desc =>
      'Pesce degli anemoni arancio-giallo con due bande bianche, endemico del Mar Rosso e del Golfo di Aden.';

  @override
  String get species_arabian_angelfish_name => 'Pesce angelo arabo';

  @override
  String get species_arabian_angelfish_desc =>
      'Grande pesce angelo blu scuro con una vistosa barra verticale gialla e coda gialla, endemico dell\'Oceano Indiano occidentale.';

  @override
  String get species_king_angelfish_name => 'Pesce angelo re';

  @override
  String get species_king_angelfish_desc =>
      'Grande pesce angelo blu scuro con una barra verticale bianca e coda gialla, presente nel Pacifico orientale e alle Galapagos.';

  @override
  String get species_ocean_sunfish_name => 'Pesce luna';

  @override
  String get species_ocean_sunfish_desc =>
      'Il pesce osseo più pesante, supera le 2 tonnellate. Avvistato occasionalmente dai subacquei alle stazioni di pulizia di Bali e delle Galapagos.';

  @override
  String get species_lingcod_name => 'Lingcod';

  @override
  String get species_lingcod_desc =>
      'Grande predatore marezzato delle scogliere rocciose del Pacifico nordoccidentale, spesso visto sorvegliare le masse di uova.';

  @override
  String get species_wolf_eel_name => 'Anguilla lupo';

  @override
  String get species_wolf_eel_desc =>
      'Grande anguilla lupo grigia con testa bulbosa e mascelle potenti, vive nelle tane rocciose del Pacifico nordoccidentale.';

  @override
  String get species_giant_sea_bass_name => 'Cernia gigante della California';

  @override
  String get species_giant_sea_bass_desc =>
      'Enorme serranide che supera i 2 m e i 250 kg, presente su scogliere rocciose e foreste di kelp della California meridionale.';

  @override
  String get species_garibaldi_name => 'Garibaldi';

  @override
  String get species_garibaldi_desc =>
      'Castagnola arancione brillante, pesce marino simbolo della California, molto territoriale nelle foreste di kelp.';

  @override
  String get species_sheephead_name => 'Labride della California';

  @override
  String get species_sheephead_desc =>
      'Grande labride con testa e coda nere, parte centrale rossa e mento bianco. Vive nelle foreste di kelp della California.';

  @override
  String get species_copper_rockfish_name => 'Scorfano ramato';

  @override
  String get species_copper_rockfish_desc =>
      'Scorfano arancione ramato con chiazze chiare, presenza comune sulle scogliere rocciose e nelle foreste di kelp del Pacifico nordoccidentale.';

  @override
  String get species_oriental_sweetlips_name => 'Pesce labbra dolci orientale';

  @override
  String get species_oriental_sweetlips_desc =>
      'Grande pesce di barriera indo-pacifico con marcate strisce bianche e nere e pinne gialle. I giovani eseguono una danza ondeggiante.';

  @override
  String get species_harlequin_sweetlips_name =>
      'Pesce labbra dolci arlecchino';

  @override
  String get species_harlequin_sweetlips_desc =>
      'Gli adulti sono grigi con macchie scure; i giovani sono bruni con grandi macchie bianche e nuotano con un movimento ondulato.';

  @override
  String get species_blue_ringed_angelfish_name =>
      'Pesce angelo dall\'anello blu';

  @override
  String get species_blue_ringed_angelfish_desc =>
      'Grande pesce angelo bruno con linee blu ricurve e un caratteristico anello blu sopra l\'opercolo branchiale.';

  @override
  String get species_yellowbar_angelfish_name =>
      'Pesce angelo dalla barra gialla';

  @override
  String get species_yellowbar_angelfish_desc =>
      'Grande pesce angelo grigio-blu con una vistosa macchia gialla sul corpo, presente nel Mar Rosso e nell\'Oceano Indiano occidentale.';

  @override
  String get species_filefish_scrawled_name => 'Pesce lima scarabocchiato';

  @override
  String get species_filefish_scrawled_desc =>
      'Grande pesce lima bruno oliva con marcature blu a scarabocchio e giogaia arancione, presente nelle barriere tropicali di tutto il mondo.';

  @override
  String get species_clown_filefish_name => 'Pesce lima a macchie arancioni';

  @override
  String get species_clown_filefish_desc =>
      'Piccolo pesce lima verde con macchie arancioni e muso allungato, si nutre esclusivamente dei polipi dei coralli Acropora.';

  @override
  String get species_unicornfish_name => 'Pesce unicorno dalla spina blu';

  @override
  String get species_unicornfish_desc =>
      'Pesce chirurgo grigio con un corno frontale prominente e due spine caudali blu, comune sui pianori corallini indo-pacifici.';

  @override
  String get species_surgeonfish_sailfin_name => 'Pesce chirurgo velifero';

  @override
  String get species_surgeonfish_sailfin_desc =>
      'Pesce chirurgo dalle bande marcate, con pinne dorsale e anale molto sviluppate, diffuso in tutto l\'Indo-Pacifico.';

  @override
  String get species_achilles_tang_name => 'Pesce chirurgo di Achille';

  @override
  String get species_achilles_tang_desc =>
      'Pesce chirurgo bruno scuro con una vistosa goccia arancione vicino alla coda, presente nelle zone di risacca del Pacifico centrale.';

  @override
  String get species_doctorfish_name => 'Pesce dottore';

  @override
  String get species_doctorfish_desc =>
      'Pesce chirurgo bruno-grigiastro con deboli barre scure e un vistoso bisturi caudale, comune nelle barriere caraibiche.';

  @override
  String get species_checkerboard_wrasse_name => 'Labride scacchiera';

  @override
  String get species_checkerboard_wrasse_desc =>
      'Labride colorato con un disegno a scacchiera di quadrati verdi, rosa e neri su tutto il corpo.';

  @override
  String get species_bird_wrasse_name => 'Labride uccello';

  @override
  String get species_bird_wrasse_desc =>
      'Labride con muso estremamente allungato simile a un becco; i maschi sono verde scuro, le femmine brune.';

  @override
  String get species_sling_jaw_wrasse_name => 'Labride dalla mascella a fionda';

  @override
  String get species_sling_jaw_wrasse_desc =>
      'Labride con una mascella estensibile che scatta in avanti per catturare le prede, presente in forme di colore gialle o brune.';

  @override
  String get species_peacock_flounder_name => 'Passera pavone';

  @override
  String get species_peacock_flounder_desc =>
      'Pesce piatto di fondo con anelli e macchie blu, capace di cambiare colore per confondersi con il fondale.';

  @override
  String get species_hogfish_name => 'Pesce porco';

  @override
  String get species_hogfish_desc =>
      'Grande labride dell\'Atlantico occidentale con muso a grugno e spine dorsali allungate, presente vicino a barriere e relitti.';

  @override
  String get species_tarpon_name => 'Tarpone atlantico';

  @override
  String get species_tarpon_desc =>
      'Enorme pesce argenteo con grandi squame simili a specchi, a volte incontrato dai subacquei nelle grotte e nei canali caraibici.';

  @override
  String get species_permit_name => 'Leccia permit';

  @override
  String get species_permit_desc =>
      'Carangide argenteo dal corpo alto e coda forcuta scura, presente sulle distese sabbiose caraibiche e vicino alle barriere.';

  @override
  String get species_spotted_drum_name => 'Tamburo maculato';

  @override
  String get species_spotted_drum_desc =>
      'Vistoso pesce caraibico con un\'alta pinna dorsale allungata e un marcato disegno a macchie bianche e nere.';

  @override
  String get species_jackknife_fish_name => 'Pesce a serramanico';

  @override
  String get species_jackknife_fish_desc =>
      'Elegante pesce caraibico con un\'alta striscia dorsale nera e una banda diagonale sul corpo, vive sotto le sporgenze.';

  @override
  String get species_bigeye_name => 'Pesce occhio di vetro';

  @override
  String get species_bigeye_desc =>
      'Pesce notturno rosso vivo con grandi occhi riflettenti, si nasconde nelle grotte delle barriere caraibiche e atlantiche.';

  @override
  String get species_remora_name => 'Remora';

  @override
  String get species_remora_desc =>
      'Pesce slanciato con un disco adesivo sul capo, si fa trasportare da squali, razze, tartarughe e altri grandi animali.';

  @override
  String get species_tilefish_sand_name => 'Tilefish della sabbia';

  @override
  String get species_tilefish_sand_desc =>
      'Pesce allungato azzurro pallido che costruisce cumuli di detriti sui fondali sabbiosi delle barriere caraibiche.';

  @override
  String get species_weedy_seadragon_name => 'Dragone di mare comune';

  @override
  String get species_weedy_seadragon_desc =>
      'Elaborato parente dei cavallucci marini con appendici a forma di foglia, endemico delle acque temperate dell\'Australia meridionale.';

  @override
  String get species_leafy_seadragon_name => 'Dragone di mare foglioso';

  @override
  String get species_leafy_seadragon_desc =>
      'Spettacolare dragone di mare ricoperto di elaborate escrescenze fogliformi, endemico dell\'Australia meridionale. Un avvistamento da sogno per ogni subacqueo.';

  @override
  String get species_sailfin_snapper_name => 'Lutiano velifero';

  @override
  String get species_sailfin_snapper_desc =>
      'Elegante lutiano giallo e blu con pinne dorsale e anale allungate, presente sui pendii corallini indo-pacifici.';

  @override
  String get species_sweetlip_emperor_name => 'Imperatore macchiettato';

  @override
  String get species_sweetlip_emperor_desc =>
      'Grande lethrinide argenteo con linee blu sul muso e bordi delle pinne gialli, comune sulle zone sabbiose delle barriere indo-pacifiche.';

  @override
  String get species_crocodilefish_name => 'Pesce coccodrillo';

  @override
  String get species_crocodilefish_desc =>
      'Predatore d\'agguato dalla testa appiattita con elaborate frange oculari, giace perfettamente mimetizzato sui fondali delle barriere indo-pacifiche.';

  @override
  String get species_devil_scorpionfish_name => 'Scorfano diavolo';

  @override
  String get species_devil_scorpionfish_desc =>
      'Scorfano tozzo e mimetico che mostra le colorate pinne pettorali interne come avvertimento ai predatori.';

  @override
  String get species_spiny_devilfish_name => 'Pesce diavolo spinoso';

  @override
  String get species_spiny_devilfish_desc =>
      'Abitante velenoso del fondo che cammina su raggi delle pinne modificati e mostra pettorali sgargianti quando è disturbato.';

  @override
  String get species_waspfish_name => 'Pesce vespa cacatua';

  @override
  String get species_waspfish_desc =>
      'Piccolo scorfano compresso che ondeggia come una foglia morta nella corrente sui fondali fangosi indo-pacifici.';

  @override
  String get species_stargazer_name => 'Pesce prete dal margine bianco';

  @override
  String get species_stargazer_desc =>
      'Predatore d\'agguato che si seppellisce nella sabbia lasciando fuori solo gli occhi e può emettere scariche elettriche. Presente nell\'Indo-Pacifico.';

  @override
  String get species_striped_catfish_name => 'Pesce gatto striato';

  @override
  String get species_striped_catfish_desc =>
      'Pesce gatto con spine velenose; i giovani formano fitti banchi a palla che rotolano sui fondali delle barriere indo-pacifiche.';

  @override
  String get species_red_emperor_name => 'Imperatore rosso';

  @override
  String get species_red_emperor_desc =>
      'Grande lutiano; gli adulti sono rosa-rossi, i giovani hanno marcate bande rosse e bianche. Presente nelle barriere indo-pacifiche.';

  @override
  String get species_mangrove_snapper_name => 'Lutiano delle mangrovie';

  @override
  String get species_mangrove_snapper_desc =>
      'Lutiano grigio presente nelle mangrovie, nelle praterie di fanerogame e nelle barriere caraibiche, spesso in aggregazioni presso le strutture.';

  @override
  String get species_dottyback_orchid_name => 'Dottyback orchidea';

  @override
  String get species_dottyback_orchid_desc =>
      'Piccolo pesce viola intenso endemico del Mar Rosso, sfreccia dentro e fuori dalle fessure delle pareti ripide.';

  @override
  String get species_dottyback_royal_name => 'Dottyback reale';

  @override
  String get species_dottyback_royal_desc =>
      'Piccolo pesce bicolore con la parte anteriore magenta e quella posteriore giallo brillante, presente sulle pareti coralline indo-pacifiche.';

  @override
  String get species_coral_trout_name => 'Cernia trota corallina';

  @override
  String get species_coral_trout_desc =>
      'Ambito predatore della Grande Barriera Corallina, con corpo rosso-arancio ricoperto di macchie blu.';

  @override
  String get species_barramundi_cod_name => 'Cernia barramundi';

  @override
  String get species_barramundi_cod_desc =>
      'Cernia inconfondibile con testa piccola, corpo gibboso e pois scuri su fondo chiaro.';

  @override
  String get species_spadefish_atlantic_name => 'Pesce pipistrello atlantico';

  @override
  String get species_spadefish_atlantic_desc =>
      'Pesce argenteo a forma di disco con barre verticali scure, spesso avvistato in grandi banchi attorno ai relitti caraibici.';

  @override
  String get species_fusilier_yellowback_name => 'Fuciliere dal dorso giallo';

  @override
  String get species_fusilier_yellowback_desc =>
      'Elegante pesce planctofago blu con il dorso giallo, forma banchi enormi sopra i pendii corallini indo-pacifici.';

  @override
  String get species_fusilier_bluestreak_name => 'Fuciliere dalla striscia blu';

  @override
  String get species_fusilier_bluestreak_desc =>
      'Piccolo fuciliere blu con una striscia laterale scura, avvistato in banchi veloci lungo le pareti indo-pacifiche.';

  @override
  String get species_porkfish_name => 'Grugnitore porcello';

  @override
  String get species_porkfish_desc =>
      'Colorato grugnitore caraibico con strisce blu e gialle e due barre nere sul capo, presente vicino a barriere e relitti.';

  @override
  String get species_blue_striped_grunt_name => 'Grugnitore dalle strisce blu';

  @override
  String get species_blue_striped_grunt_desc =>
      'Grugnitore caraibico giallo con vivaci strisce orizzontali blu, forma grandi banchi in riposo sotto le sporgenze durante il giorno.';

  @override
  String get species_french_grunt_name => 'Grugnitore francese';

  @override
  String get species_french_grunt_desc =>
      'Piccolo grugnitore a strisce gialle che forma fitti banchi in riposo nelle barriere caraibiche durante le ore diurne.';

  @override
  String get species_convict_tang_name => 'Pesce chirurgo forzato';

  @override
  String get species_convict_tang_desc =>
      'Pesce chirurgo chiaro con sei barre verticali nere, spesso visto brucare in grandi banchi sui pianori corallini indo-pacifici.';

  @override
  String get species_great_hammerhead_name => 'Squalo martello smerlato';

  @override
  String get species_great_hammerhead_desc =>
      'Squalo inconfondibile con la testa a martello dal bordo smerlato, forma grandi banchi presso montagne sottomarine e isole al largo.';

  @override
  String get species_wobbegong_name => 'Wobbegong maculato';

  @override
  String get species_wobbegong_desc =>
      'Squalo tappeto piatto e ben mimetizzato, con lobi frangiati attorno alla bocca, presente nelle scogliere temperate australiane.';

  @override
  String get species_manta_ray_name => 'Manta di barriera';

  @override
  String get species_manta_ray_desc =>
      'Gigante aggraziato con un\'apertura alare fino a 5 m, frequenta le stazioni di pulizia e si nutre di plancton nelle barriere indo-pacifiche.';

  @override
  String get species_oceanic_manta_name => 'Manta oceanica';

  @override
  String get species_oceanic_manta_desc =>
      'La più grande specie di razza, con apertura alare superiore ai 7 m, incontrata presso montagne sottomarine al largo e stazioni di pulizia.';

  @override
  String get species_undulated_moray_name => 'Murena ondulata';

  @override
  String get species_undulated_moray_desc =>
      'Murena verde-giallastra con marcature scure ondulate, comunemente vista cacciare di notte nelle barriere indo-pacifiche.';

  @override
  String get species_whitemouth_moray_name => 'Murena dalla bocca bianca';

  @override
  String get species_whitemouth_moray_desc =>
      'Murena bruno scuro con piccole macchie bianche e l\'interno della bocca bianco, diffusa in tutto l\'Indo-Pacifico.';

  @override
  String get species_dragon_moray_name => 'Murena drago';

  @override
  String get species_dragon_moray_desc =>
      'Murena vistosa con corni simili a quelli di un drago sopra le narici e macchie leopardate rosso-arancio, presente nell\'Indo-Pacifico.';

  @override
  String get species_lyretail_grouper_name => 'Cernia dalla coda a lira';

  @override
  String get species_lyretail_grouper_desc =>
      'Cernia rosso-rosata con macchie blu e una caratteristica coda a mezzaluna, presente sulle pareti esterne indo-pacifiche.';

  @override
  String get species_banded_butterflyfish_name => 'Pesce farfalla fasciato';

  @override
  String get species_banded_butterflyfish_desc =>
      'Pesce farfalla bianco con quattro marcate bande verticali nere, uno dei più comuni delle barriere caraibiche.';

  @override
  String get species_ringed_pipefish_name => 'Pesce ago anellato';

  @override
  String get species_ringed_pipefish_desc =>
      'Pesce ago slanciato con anelli rossi e bianchi alternati, presente in grotte e sotto le sporgenze delle barriere indo-pacifiche.';

  @override
  String get species_razorfish_name => 'Pesce rasoio';

  @override
  String get species_razorfish_desc =>
      'Pesciolino che nuota in verticale a testa in giù in gruppo, spesso nascosto tra gli aculei dei ricci di mare nelle barriere indo-pacifiche.';

  @override
  String get species_harlequin_tuskfish_name => 'Labride arlecchino';

  @override
  String get species_harlequin_tuskfish_desc =>
      'Labride colorato con zanne blu brillanti, barre rosso-arancio e chiazze bianche, presente nelle barriere del Pacifico occidentale.';

  @override
  String get species_blue_groper_name => 'Labride blu australiano';

  @override
  String get species_blue_groper_desc =>
      'Grande labride blu endemico dell\'Australia orientale, socievole e spesso si avvicina ai subacquei nelle scogliere temperate.';

  @override
  String get species_red_lipped_batfish_name =>
      'Pesce pipistrello dalle labbra rosse';

  @override
  String get species_red_lipped_batfish_desc =>
      'Bizzarro pesce dal corpo appiattito con labbra rosso vivo, cammina su pinne modificate sui fondali delle Galapagos.';

  @override
  String get species_orangeband_surgeonfish_name =>
      'Pesce chirurgo dalla banda arancione';

  @override
  String get species_orangeband_surgeonfish_desc =>
      'Pesce chirurgo bruno-grigio con una banda orizzontale arancione dietro l\'occhio, presente sui pendii corallini del Pacifico.';

  @override
  String get species_maori_wrasse_name => 'Labride maori';

  @override
  String get species_maori_wrasse_desc =>
      'Labride di taglia media con una banda scura dietro la pinna pettorale, comune nelle barriere del Pacifico e dell\'Oceano Indiano.';

  @override
  String get species_blue_ringed_octopus_name => 'Polpo dagli anelli blu';

  @override
  String get species_blue_ringed_octopus_desc =>
      'Polpo piccolo ma estremamente velenoso, con anelli blu brillanti che lampeggiano quando è minacciato.';

  @override
  String get species_common_octopus_name => 'Polpo comune';

  @override
  String get species_common_octopus_desc =>
      'Polpo molto intelligente, noto per i rapidi cambi di colore e la capacità di risolvere problemi.';

  @override
  String get species_giant_pacific_octopus_name => 'Polpo gigante del Pacifico';

  @override
  String get species_giant_pacific_octopus_desc =>
      'La più grande specie di polpo, con un\'apertura delle braccia che supera i 4 metri nelle fredde acque del Pacifico.';

  @override
  String get species_mimic_octopus_name => 'Polpo mimetico';

  @override
  String get species_mimic_octopus_desc =>
      'Straordinario polpo che imita l\'aspetto e il comportamento di altre specie marine.';

  @override
  String get species_coconut_octopus_name => 'Polpo del cocco';

  @override
  String get species_coconut_octopus_desc =>
      'Piccolo polpo famoso per trasportare gusci di cocco e usarli come rifugi portatili.';

  @override
  String get species_day_octopus_name => 'Polpo diurno';

  @override
  String get species_day_octopus_desc =>
      'Cacciatore attivo di giorno, comune nelle barriere indo-pacifiche, con notevoli capacità mimetiche.';

  @override
  String get species_wonderpus_octopus_name => 'Polpo wonderpus';

  @override
  String get species_wonderpus_octopus_desc =>
      'Vistoso polpo con inconfondibili bande bianche e brune, presente nei siti di muck diving sabbiosi.';

  @override
  String get species_broadclub_cuttlefish_name => 'Seppia dalle braccia larghe';

  @override
  String get species_broadclub_cuttlefish_desc =>
      'Grande seppia dagli ipnotici giochi di colore, comunemente osservata nelle barriere indo-pacifiche.';

  @override
  String get species_pharaoh_cuttlefish_name => 'Seppia faraone';

  @override
  String get species_pharaoh_cuttlefish_desc =>
      'Grande seppia diffusa in tutto l\'Oceano Indiano, nota per i disegni di colore pulsanti.';

  @override
  String get species_flamboyant_cuttlefish_name => 'Seppia fiammeggiante';

  @override
  String get species_flamboyant_cuttlefish_desc =>
      'Minuscola seppia che cammina sul fondale mostrando vivide pulsazioni viola, rosa e gialle.';

  @override
  String get species_giant_cuttlefish_name => 'Seppia gigante';

  @override
  String get species_giant_cuttlefish_desc =>
      'La seppia più grande al mondo, celebre per le imponenti aggregazioni riproduttive dell\'Australia meridionale.';

  @override
  String get species_bigfin_reef_squid_name =>
      'Calamaro di barriera dalle grandi pinne';

  @override
  String get species_bigfin_reef_squid_desc =>
      'Calamaro gregario spesso incontrato nelle immersioni notturne, attratto dalle torce dei subacquei.';

  @override
  String get species_caribbean_reef_squid_name =>
      'Calamaro di barriera caraibico';

  @override
  String get species_caribbean_reef_squid_desc =>
      'Calamaro curioso, spesso sospeso in piccoli gruppi vicino ai bordi della barriera nei Caraibi.';

  @override
  String get species_bobtail_squid_name => 'Seppiola';

  @override
  String get species_bobtail_squid_desc =>
      'Minuscolo cefalopode notturno che di giorno si seppellisce nella sabbia, un ritrovamento ambito nel muck diving.';

  @override
  String get species_chambered_nautilus_name => 'Nautilus';

  @override
  String get species_chambered_nautilus_desc =>
      'Antico fossile vivente dalla conchiglia a spirale, raramente visto dai subacquei in acque profonde all\'alba.';

  @override
  String get species_spanish_dancer_name => 'Ballerina spagnola';

  @override
  String get species_spanish_dancer_desc =>
      'Il nudibranco più grande, nuota ondeggiando il mantello rosso come una ballerina di flamenco.';

  @override
  String get species_chromodoris_willani_name => 'Chromodoris di Willan';

  @override
  String get species_chromodoris_willani_desc =>
      'Vistoso nudibranco blu e nero con il margine bianco, comune nell\'Indo-Pacifico.';

  @override
  String get species_chromodoris_lochi_name => 'Chromodoris di Loch';

  @override
  String get species_chromodoris_lochi_desc =>
      'Nudibranco blu con linee scure e bordo bianco, diffuso in tutto il Pacifico tropicale.';

  @override
  String get species_chromodoris_magnifica_name => 'Chromodoris magnifica';

  @override
  String get species_chromodoris_magnifica_desc =>
      'Nudibranco dai brillanti colori blu, bianco e arancione, presente nelle barriere coralline indo-pacifiche.';

  @override
  String get species_chromodoris_annae_name => 'Chromodoris di Anna';

  @override
  String get species_chromodoris_annae_desc =>
      'Nudibranco blu intenso con linee nere e rinofori e branchie dalla punta arancione.';

  @override
  String get species_nembrotha_kubaryana_name => 'Lumaca neon variabile';

  @override
  String get species_nembrotha_kubaryana_desc =>
      'Nudibranco verde scuro con vivaci marcature arancioni o rosse, si nutre di tunicati.';

  @override
  String get species_nembrotha_cristata_name => 'Nembrotha crestata';

  @override
  String get species_nembrotha_cristata_desc =>
      'Nudibranco nero con pustole e striature verde brillante, presente nelle barriere indo-pacifiche.';

  @override
  String get species_phyllidia_varicosa_name => 'Phyllidia varicosa';

  @override
  String get species_phyllidia_varicosa_desc =>
      'Nudibranco grigio-blu con tubercoli rilevati dalla punta gialla, tossico per i predatori.';

  @override
  String get species_phyllidia_ocellata_name => 'Phyllidia ocellata';

  @override
  String get species_phyllidia_ocellata_desc =>
      'Nudibranco bianco con tubercoli rilevati cerchiati di rosa, presente nelle barriere tropicali.';

  @override
  String get species_pikachu_nudibranch_name => 'Nudibranco Pikachu';

  @override
  String get species_pikachu_nudibranch_desc =>
      'Minuscola lumaca di mare gialla e nera che ricorda un personaggio dei cartoni animati, presente nel Pacifico.';

  @override
  String get species_anna_rosefieldi_name => 'Nudibranco Roboastra';

  @override
  String get species_anna_rosefieldi_desc =>
      'Nudibranco predatore dal corpo scuro con vivaci strisce longitudinali, caccia altre lumache di mare.';

  @override
  String get species_lettuce_sea_slug_name => 'Lumaca di mare lattuga';

  @override
  String get species_lettuce_sea_slug_desc =>
      'Lumaca di mare verde e arricciata che trattiene i cloroplasti delle alghe per fotosintetizzare.';

  @override
  String get species_blue_dragon_nudibranch_name => 'Nudibranco drago blu';

  @override
  String get species_blue_dragon_nudibranch_desc =>
      'Lungo nudibranco eolidiaceo con cerata dalla punta blu che ospita zooxantelle simbionti.';

  @override
  String get species_gloomy_nudibranch_name => 'Nudibranco cupo';

  @override
  String get species_gloomy_nudibranch_desc =>
      'Nudibranco blu-verde scuro con creste bordate di blu, comune nelle barriere indo-pacifiche.';

  @override
  String get species_ocellined_nudibranch_name => 'Nudibranco ocellinato';

  @override
  String get species_ocellined_nudibranch_desc =>
      'Nudibranco bianco con creste bordate di arancione che formano disegni geometrici sul mantello.';

  @override
  String get species_glossodoris_cincta_name => 'Nudibranco Glossodoris';

  @override
  String get species_glossodoris_cincta_desc =>
      'Nudibranco color crema con bordo bruno scuro e margine arancione sul mantello.';

  @override
  String get species_jorunna_funebris_name => 'Nudibranco punteggiato';

  @override
  String get species_jorunna_funebris_desc =>
      'Nudibranco bianco ricoperto di cariofillidi dalla punta nera, somiglia a un coniglietto peloso.';

  @override
  String get species_ceratosoma_trilobatum_name => 'Nudibranco trilobato';

  @override
  String get species_ceratosoma_trilobatum_desc =>
      'Grande nudibranco con un alto corno dorsale e lobi laterali nelle tonalità del viola e del giallo.';

  @override
  String get species_hypselodoris_apolegma_name => 'Hypselodoris viola';

  @override
  String get species_hypselodoris_apolegma_desc =>
      'Elegante nudibranco viola con il bordo del mantello bianco, presente nelle barriere indo-pacifiche.';

  @override
  String get species_hypselodoris_bullockii_name => 'Hypselodoris di Bullock';

  @override
  String get species_hypselodoris_bullockii_desc =>
      'Nudibranco rosa e viola con rinofori dalla punta gialla, nelle barriere indo-pacifiche.';

  @override
  String get species_flabellina_exoptata_name => 'Flabellina desiderabile';

  @override
  String get species_flabellina_exoptata_desc =>
      'Nudibranco eolidiaceo traslucido con cerata arancioni dalla punta viola, presente nelle acque tropicali.';

  @override
  String get species_risbecia_tryoni_name => 'Risbecia di Tryon';

  @override
  String get species_risbecia_tryoni_desc =>
      'Grande nudibranco bruno e blu, spesso avvistato in coppie di accoppiamento nelle barriere indo-pacifiche.';

  @override
  String get species_goniobranchus_kuniei_name => 'Nudibranco di Kunie';

  @override
  String get species_goniobranchus_kuniei_desc =>
      'Nudibranco bianco a macchie arancioni con il margine del mantello viola, presente nel Pacifico occidentale.';

  @override
  String get species_mexichromis_multituberculata_name =>
      'Nudibranco multitubercolato';

  @override
  String get species_mexichromis_multituberculata_desc =>
      'Nudibranco viola e bianco con tubercoli rilevati e appendici dalla punta arancione.';

  @override
  String get species_chromodoris_dianae_name => 'Chromodoris di Diana';

  @override
  String get species_chromodoris_dianae_desc =>
      'Nudibranco blu brillante con strisce nere e branchie arancioni, presente nel Pacifico occidentale.';

  @override
  String get species_phyllodesmium_poindimiei_name => 'Nudibranco solare';

  @override
  String get species_phyllodesmium_poindimiei_desc =>
      'Nudibranco eolidiaceo traslucido con cerata ramificate che ospita zooxantelle.';

  @override
  String get species_chromodoris_elisabethina_name =>
      'Chromodoris di Elisabetta';

  @override
  String get species_chromodoris_elisabethina_desc =>
      'Nudibranco con linee blu e gialle e bordo del mantello bianco, comune nel Sud-est asiatico.';

  @override
  String get species_doridella_batava_name => 'Doride di Batavia';

  @override
  String get species_doridella_batava_desc =>
      'Nudibranco doride di colore variabile dal nero al bruno, si trova sotto rocce e detriti nelle barriere indo-pacifiche.';

  @override
  String get species_tiger_cowrie_name => 'Ciprea tigre';

  @override
  String get species_tiger_cowrie_desc =>
      'Grande ciprea maculata delle barriere tropicali, spesso parzialmente coperta dal proprio mantello.';

  @override
  String get species_tritons_trumpet_name => 'Tromba di Tritone';

  @override
  String get species_tritons_trumpet_desc =>
      'Grande gasteropode predatore e nemico naturale della stella corona di spine.';

  @override
  String get species_queen_conch_name => 'Strombo gigante';

  @override
  String get species_queen_conch_desc =>
      'Iconico grande strombo delle praterie di fanerogame caraibiche, con il caratteristico labbro interno rosa.';

  @override
  String get species_banded_coral_shrimp_name => 'Gambero pulitore fasciato';

  @override
  String get species_banded_coral_shrimp_desc =>
      'Gambero pulitore a bande rosse e bianche con lunghe antenne bianche, vive nelle fessure della barriera.';

  @override
  String get species_mantis_shrimp_name => 'Canocchia pavone';

  @override
  String get species_mantis_shrimp_desc =>
      'Predatore variopinto con potenti appendici a clava capaci di frantumare i gusci.';

  @override
  String get species_cleaner_shrimp_name => 'Gambero pulitore scarlatto';

  @override
  String get species_cleaner_shrimp_desc =>
      'Gambero rosso e bianco brillante che allestisce stazioni di pulizia al servizio dei pesci di barriera.';

  @override
  String get species_pederson_cleaner_shrimp_name =>
      'Gambero pulitore di Pederson';

  @override
  String get species_pederson_cleaner_shrimp_desc =>
      'Gambero pulitore caraibico traslucido che vive tra i tentacoli degli anemoni.';

  @override
  String get species_harlequin_shrimp_name => 'Gambero arlecchino';

  @override
  String get species_harlequin_shrimp_desc =>
      'Gambero dal disegno vistoso con chele appiattite, si nutre esclusivamente di stelle marine.';

  @override
  String get species_coleman_shrimp_name => 'Gambero di Coleman';

  @override
  String get species_coleman_shrimp_desc =>
      'Minuscolo gambero che vive in coppia sui ricci di fuoco, molto ambito dai fotografi subacquei.';

  @override
  String get species_emperor_shrimp_name => 'Gambero imperatore';

  @override
  String get species_emperor_shrimp_desc =>
      'Colorato gambero commensale che viaggia su oloturie e nudibranchi.';

  @override
  String get species_sexy_shrimp_name => 'Gambero sexy';

  @override
  String get species_sexy_shrimp_desc =>
      'Minuscolo gambero degli anemoni noto per la danza con cui agita la coda, molto amato nella fotografia macro.';

  @override
  String get species_marble_shrimp_name => 'Gambero marmorizzato';

  @override
  String get species_marble_shrimp_desc =>
      'Gambero notturno marezzato con zampe piumose, di giorno si nasconde nelle fessure della barriera.';

  @override
  String get species_spiny_lobster_name => 'Aragosta caraibica';

  @override
  String get species_spiny_lobster_desc =>
      'Grande aragosta priva di chele con lunghe antenne, si rifugia sotto le sporgenze della barriera.';

  @override
  String get species_painted_spiny_lobster_name => 'Aragosta dipinta';

  @override
  String get species_painted_spiny_lobster_desc =>
      'Aragosta dai colori vivaci con zampe striate di blu, verde e bianco, nelle barriere indo-pacifiche.';

  @override
  String get species_slipper_lobster_name => 'Magnosa';

  @override
  String get species_slipper_lobster_desc =>
      'Aragosta notturna dal corpo appiattito, con ampie placche antennali al posto delle lunghe antenne a frusta.';

  @override
  String get species_squat_lobster_name => 'Galatea';

  @override
  String get species_squat_lobster_desc =>
      'Minuscolo crostaceo rosa-viola che vive sulle grandi spugne a barile, un soggetto prediletto della fotografia macro.';

  @override
  String get species_hermit_crab_name => 'Paguro dalle zampe blu';

  @override
  String get species_hermit_crab_desc =>
      'Piccolo paguro con zampe blu brillante, comunemente avvistato nelle barriere caraibiche.';

  @override
  String get species_orangutan_crab_name => 'Granchio orango';

  @override
  String get species_orangutan_crab_desc =>
      'Minuscolo granchio peloso che vive nei coralli a bolle, chiamato così per la somiglianza con un orango.';

  @override
  String get species_decorator_crab_name => 'Granchio decoratore';

  @override
  String get species_decorator_crab_desc =>
      'Maestro del travestimento, fissa spugne, alghe e idrozoi sul proprio carapace.';

  @override
  String get species_porcelain_crab_name => 'Granchio porcellana degli anemoni';

  @override
  String get species_porcelain_crab_desc =>
      'Granchio piatto e maculato che vive negli anemoni, filtra il cibo con appendici boccali piumose.';

  @override
  String get species_arrow_crab_name => 'Granchio freccia';

  @override
  String get species_arrow_crab_desc =>
      'Granchio caraibico dalle zampe sottili, con un lungo rostro appuntito e zampe striate.';

  @override
  String get species_channel_clinging_crab_name => 'Granchio dei canali';

  @override
  String get species_channel_clinging_crab_desc =>
      'Grande granchio di barriera caraibico dal corpo scuro e chele rosso-arancio, vive nelle fessure.';

  @override
  String get species_coral_crab_name => 'Granchio guardiano del corallo';

  @override
  String get species_coral_crab_desc =>
      'Piccolo granchio maculato che vive in simbiosi nei coralli Pocillopora, difendendo il proprio ospite.';

  @override
  String get species_crown_of_thorns_starfish_name => 'Stella corona di spine';

  @override
  String get species_crown_of_thorns_starfish_desc =>
      'Stella marina velenosa dalle molte braccia che si nutre di corallo e può devastare le barriere durante le esplosioni demografiche.';

  @override
  String get species_blue_linckia_starfish_name => 'Stella marina blu';

  @override
  String get species_blue_linckia_starfish_desc =>
      'Stella marina blu intenso, comunemente osservata sui pianori e sui pendii delle barriere indo-pacifiche.';

  @override
  String get species_red_knob_starfish_name =>
      'Stella marina dai bottoni rossi';

  @override
  String get species_red_knob_starfish_desc =>
      'Grande stella marina grigia con vistose spine dalla punta rossa, presente nelle zone sabbiose della barriera.';

  @override
  String get species_chocolate_chip_starfish_name =>
      'Stella marina gocce di cioccolato';

  @override
  String get species_chocolate_chip_starfish_desc =>
      'Stella marina beige con noduli scuri rilevati simili a gocce di cioccolato, vive sui fondali sabbiosi.';

  @override
  String get species_cushion_star_name => 'Stella cuscino';

  @override
  String get species_cushion_star_desc =>
      'Stella marina pentagonale e rigonfia con braccia ridotte, presente sui pianori corallini indo-pacifici.';

  @override
  String get species_fromia_starfish_name => 'Stella marina elegante';

  @override
  String get species_fromia_starfish_desc =>
      'Piccola stella marina rosso-arancio con i margini delle placche più chiari, che creano un disegno a piastrelle.';

  @override
  String get species_basket_star_name => 'Stella gorgone';

  @override
  String get species_basket_star_desc =>
      'Le braccia finemente ramificate si dispiegano di notte per filtrare il cibo dalla corrente.';

  @override
  String get species_brittle_star_name => 'Ofiura fasciata';

  @override
  String get species_brittle_star_desc =>
      'Ofiura striata che vive sotto le rocce e nelle fessure, con braccia agili e serpentine.';

  @override
  String get species_feather_star_name => 'Giglio di mare';

  @override
  String get species_feather_star_desc =>
      'Crinoide dalle molte braccia appollaiato sulle sporgenze della barriera, filtra il cibo con le braccia piumate.';

  @override
  String get species_black_feather_star_name => 'Giglio di mare nero';

  @override
  String get species_black_feather_star_desc =>
      'Crinoide scuro capace di nuotare per brevi tratti agitando ritmicamente le sue numerose braccia.';

  @override
  String get species_long_spined_sea_urchin_name => 'Riccio dalle lunghe spine';

  @override
  String get species_long_spined_sea_urchin_desc =>
      'Riccio nero con lunghe spine velenose, brucatore fondamentale per le barriere caraibiche.';

  @override
  String get species_fire_urchin_name => 'Riccio di fuoco';

  @override
  String get species_fire_urchin_desc =>
      'Riccio dal corpo molle con spine velenose che provocano punture dolorose al contatto.';

  @override
  String get species_pencil_urchin_name => 'Riccio matita';

  @override
  String get species_pencil_urchin_desc =>
      'Riccio robusto con spine spesse e smussate, si incastra nelle fessure della barriera.';

  @override
  String get species_collector_urchin_name => 'Riccio collezionista';

  @override
  String get species_collector_urchin_desc =>
      'Riccio che si ricopre di detriti e frammenti di alghe per mimetizzarsi.';

  @override
  String get species_sea_apple_name => 'Mela di mare';

  @override
  String get species_sea_apple_desc =>
      'Oloturia dai colori vivaci con tentacoli orali usati per filtrare il cibo.';

  @override
  String get species_pineapple_sea_cucumber_name => 'Oloturia ananas';

  @override
  String get species_pineapple_sea_cucumber_desc =>
      'Grande oloturia rosso-arancio con papille a forma di stella, presente sui pendii della barriera.';

  @override
  String get species_black_sea_cucumber_name => 'Oloturia nera';

  @override
  String get species_black_sea_cucumber_desc =>
      'Comune oloturia nera dei pianori sabbiosi delle barriere di tutto l\'Indo-Pacifico.';

  @override
  String get species_leopard_sea_cucumber_name => 'Oloturia leopardo';

  @override
  String get species_leopard_sea_cucumber_desc =>
      'Oloturia maculata che espelle appiccicosi tubuli di Cuvier bianchi quando è disturbata.';

  @override
  String get species_sand_dollar_name => 'Dollaro di sabbia';

  @override
  String get species_sand_dollar_desc =>
      'Riccio piatto a forma di disco, parzialmente sepolto nei fondali sabbiosi.';

  @override
  String get species_moon_jellyfish_name => 'Medusa luna';

  @override
  String get species_moon_jellyfish_desc =>
      'Medusa traslucida a campana con quattro gonadi a ferro di cavallo visibili attraverso il corpo.';

  @override
  String get species_lions_mane_jellyfish_name => 'Medusa criniera di leone';

  @override
  String get species_lions_mane_jellyfish_desc =>
      'Una delle specie di medusa più grandi, con lunghi tentacoli fluttuanti nelle acque fredde.';

  @override
  String get species_box_jellyfish_name => 'Cubomedusa';

  @override
  String get species_box_jellyfish_desc =>
      'Medusa estremamente pericolosa dal veleno potente, presente nelle acque tropicali indo-pacifiche.';

  @override
  String get species_upside_down_jellyfish_name => 'Medusa capovolta';

  @override
  String get species_upside_down_jellyfish_desc =>
      'Medusa insolita che riposa con la campana rivolta verso il basso sui fondali sabbiosi per far fotosintetizzare le proprie alghe.';

  @override
  String get species_blue_blubber_jellyfish_name => 'Medusa blu australiana';

  @override
  String get species_blue_blubber_jellyfish_desc =>
      'Medusa bianco-azzurra con campana soda e braccia orali arricciate, comune nelle acque australiane.';

  @override
  String get species_fried_egg_jellyfish_name => 'Medusa uovo fritto';

  @override
  String get species_fried_egg_jellyfish_desc =>
      'Medusa mediterranea con una cupola gialla che ricorda un uovo fritto e dalla puntura lieve.';

  @override
  String get species_pacific_sea_nettle_name => 'Ortica di mare del Pacifico';

  @override
  String get species_pacific_sea_nettle_desc =>
      'Medusa bruno-dorata con lunghi tentacoli fluttuanti, presente lungo la costa del Pacifico.';

  @override
  String get species_compass_jellyfish_name => 'Medusa bussola';

  @override
  String get species_compass_jellyfish_desc =>
      'Medusa bruna e bianca con marcature a V che si irradiano come una rosa dei venti.';

  @override
  String get species_spotted_jellyfish_name => 'Medusa maculata';

  @override
  String get species_spotted_jellyfish_desc =>
      'Medusa dorata a macchie bianche, celebre per popolare il Jellyfish Lake di Palau.';

  @override
  String get species_barrel_jellyfish_name => 'Polmone di mare';

  @override
  String get species_barrel_jellyfish_desc =>
      'Grande medusa a cupola con braccia orali arricciate e puntura lieve, comune nell\'Atlantico.';

  @override
  String get species_persian_carpet_flatworm_name =>
      'Verme piatto tappeto persiano';

  @override
  String get species_persian_carpet_flatworm_desc =>
      'Verme piatto nero riccamente ornato con margini giallo-arancio, spesso scambiato per un nudibranco.';

  @override
  String get species_leopard_flatworm_name => 'Verme piatto leopardo';

  @override
  String get species_leopard_flatworm_desc =>
      'Verme piatto traslucido con macchie leopardate che scivola sui substrati della barriera.';

  @override
  String get species_divided_flatworm_name => 'Verme piatto diviso';

  @override
  String get species_divided_flatworm_desc =>
      'Vistoso verme piatto nero e arancione che imita i nudibranchi tossici per difendersi.';

  @override
  String get species_blue_pseudoceros_flatworm_name =>
      'Verme piatto Pseudoceros blu';

  @override
  String get species_blue_pseudoceros_flatworm_desc =>
      'Verme piatto blu intenso con il margine arancione, scivola sulle superfici delle barriere indo-pacifiche.';

  @override
  String get species_racing_stripe_flatworm_name =>
      'Verme piatto a striscia da corsa';

  @override
  String get species_racing_stripe_flatworm_desc =>
      'Verme piatto color crema con una netta striscia scura centrale e il margine arricciato.';

  @override
  String get species_christmas_tree_worm_name => 'Verme albero di Natale';

  @override
  String get species_christmas_tree_worm_desc =>
      'Verme colorato dalla corona a spirale incastonato nel corallo, si ritira all\'istante quando ci si avvicina.';

  @override
  String get species_feather_duster_worm_name => 'Verme piumino';

  @override
  String get species_feather_duster_worm_desc =>
      'Verme tubicolo con una corona a ventaglio di radioli piumati usata per filtrare il cibo.';

  @override
  String get species_fire_worm_name => 'Verme di fuoco barbuto';

  @override
  String get species_fire_worm_desc =>
      'Verme setoloso con chete urticanti bianche che provocano un\'irritazione dolorosa al contatto.';

  @override
  String get species_bobbit_worm_name => 'Verme bobbit';

  @override
  String get species_bobbit_worm_desc =>
      'Predatore d\'agguato nascosto nella sabbia, con mascelle potenti che scattano a velocità fulminea.';

  @override
  String get species_social_feather_duster_name => 'Verme piumino sociale';

  @override
  String get species_social_feather_duster_desc =>
      'Verme tubicolo coloniale che forma ciuffi di delicate corone fasciate nelle barriere caraibiche.';

  @override
  String get species_giant_clam_name => 'Tridacna gigante';

  @override
  String get species_giant_clam_desc =>
      'Il più grande bivalve vivente, con il tessuto del mantello iridescente che ospita alghe simbionti.';

  @override
  String get species_boring_clam_name => 'Tridacna perforante';

  @override
  String get species_boring_clam_desc =>
      'Piccola tridacna colorata che si scava una nicchia nella roccia corallina lasciando visibile solo il mantello sgargiante.';

  @override
  String get species_maxima_clam_name => 'Tridacna maxima';

  @override
  String get species_maxima_clam_desc =>
      'Tridacna dai colori brillanti incastonata nella roccia della barriera, con mantelli blu e verde elettrico.';

  @override
  String get species_flame_scallop_name => 'Cappasanta fiamma';

  @override
  String get species_flame_scallop_desc =>
      'Bivalve rosso con lampi di luce bianca lungo il bordo del mantello, vive nelle fessure della barriera.';

  @override
  String get species_thorny_oyster_name => 'Ostrica spinosa';

  @override
  String get species_thorny_oyster_desc =>
      'Bivalve dalla conchiglia spinosa cementato alla roccia della barriera, spesso incrostato di spugne e alghe.';

  @override
  String get species_magnificent_sea_anemone_name =>
      'Anemone di mare magnifico';

  @override
  String get species_magnificent_sea_anemone_desc =>
      'Grande anemone colorato che ospita i pesci pagliaccio, con una colonna vistosa e tentacoli fluttuanti.';

  @override
  String get species_bubble_tip_anemone_name => 'Anemone dalla punta a bolla';

  @override
  String get species_bubble_tip_anemone_desc =>
      'Ospite molto diffuso dei pesci pagliaccio, con tentacoli dalla punta bulbosa di colore verde, bruno o rosato.';

  @override
  String get species_giant_carpet_anemone_name => 'Anemone tappeto gigante';

  @override
  String get species_giant_carpet_anemone_desc =>
      'Enorme anemone con tentacoli corti e appiccicosi, può superare il metro di diametro.';

  @override
  String get species_haddon_carpet_anemone_name => 'Anemone tappeto di Haddon';

  @override
  String get species_haddon_carpet_anemone_desc =>
      'Anemone tappeto piatto dei fondali sabbiosi, ospita vari pesci pagliaccio e granchi porcellana.';

  @override
  String get species_long_tentacle_anemone_name =>
      'Anemone dai tentacoli lunghi';

  @override
  String get species_long_tentacle_anemone_desc =>
      'Anemone dei fondali sabbiosi con lunghi tentacoli fluttuanti, ospita spesso i pesci pagliaccio.';

  @override
  String get species_tube_anemone_name => 'Cerianto';

  @override
  String get species_tube_anemone_desc =>
      'Elegante anemone che vive in un tubo pergamenaceo infisso nella sabbia, con due corone di tentacoli.';

  @override
  String get species_hell_fire_anemone_name => 'Anemone fuoco infernale';

  @override
  String get species_hell_fire_anemone_desc =>
      'Anemone fortemente urticante con tentacoli ramificati che ricordano un corallo molle.';

  @override
  String get species_beaded_sea_anemone_name => 'Anemone perlato';

  @override
  String get species_beaded_sea_anemone_desc =>
      'Anemone con le punte dei tentacoli rigonfie a perlina, presente nelle zone sabbiose delle barriere indo-pacifiche.';

  @override
  String get species_condylactis_anemone_name => 'Anemone gigante dei Caraibi';

  @override
  String get species_condylactis_anemone_desc =>
      'Grande anemone caraibico con tentacoli dalla punta viola, vive sui substrati rocciosi della barriera.';

  @override
  String get species_sand_anemone_name => 'Anemone di sabbia';

  @override
  String get species_sand_anemone_desc =>
      'Delicato anemone parzialmente sepolto nella sabbia, con tentacoli dalla punta viola.';

  @override
  String get species_barrel_sponge_name => 'Spugna a barile gigante';

  @override
  String get species_barrel_sponge_desc =>
      'Enorme spugna a forma di barile che può vivere per secoli sulle pareti delle barriere caraibiche.';

  @override
  String get species_azure_vase_sponge_name => 'Spugna a vaso azzurra';

  @override
  String get species_azure_vase_sponge_desc =>
      'Vivace spugna a forma di vaso blu-violacea, presente sulle pareti delle barriere caraibiche.';

  @override
  String get species_yellow_tube_sponge_name => 'Spugna tubo gialla';

  @override
  String get species_yellow_tube_sponge_desc =>
      'Spugna tubolare giallo brillante che cresce a gruppi sulle pareti delle barriere caraibiche.';

  @override
  String get species_elephant_ear_sponge_name => 'Spugna orecchio di elefante';

  @override
  String get species_elephant_ear_sponge_desc =>
      'Grande spugna arancione a ventaglio che cresce su pareti e strapiombi dei Caraibi.';

  @override
  String get species_rope_sponge_name => 'Spugna corda';

  @override
  String get species_rope_sponge_desc =>
      'Spugna rossa eretta e ramificata che cresce in formazioni simili a corde nelle barriere caraibiche.';

  @override
  String get species_portuguese_man_o_war_name => 'Caravella portoghese';

  @override
  String get species_portuguese_man_o_war_desc =>
      'Idrozoo coloniale con un galleggiante pieno di gas e tentacoli fluttuanti estremamente dolorosi.';

  @override
  String get species_fire_coral_name => 'Corallo di fuoco';

  @override
  String get species_fire_coral_desc =>
      'Non è un vero corallo ma un idrozoo che infligge ai subacquei punture dolorose al contatto.';

  @override
  String get species_by_the_wind_sailor_name => 'Velella';

  @override
  String get species_by_the_wind_sailor_desc =>
      'Colonia galleggiante di idrozoi blu con una vela diagonale che cattura il vento.';

  @override
  String get species_blue_button_name => 'Bottone blu';

  @override
  String get species_blue_button_desc =>
      'Idrozoo coloniale galleggiante con un disco piatto e idroidi blu simili a tentacoli.';

  @override
  String get species_giant_sea_hare_name => 'Lepre di mare gigante';

  @override
  String get species_giant_sea_hare_desc =>
      'Una delle lumache di mare più grandi, da bruno scuro a nera, vive nei fondali a kelp.';

  @override
  String get species_sea_hare_name => 'Lepre di mare maculata';

  @override
  String get species_sea_hare_desc =>
      'Grande lepre di mare a macchie verdi che rilascia inchiostro viola quando è disturbata.';

  @override
  String get species_nudibranch_berghia_name => 'Nudibranco Berghia';

  @override
  String get species_nudibranch_berghia_desc =>
      'Nudibranco eolidiaceo traslucido con cerata dalla punta bianca, si nutre di anemoni.';

  @override
  String get species_sea_pen_name => 'Penna di mare';

  @override
  String get species_sea_pen_desc =>
      'Ottocorallo coloniale a forma di piuma ancorato nella sabbia, si ritrae quando è disturbato.';

  @override
  String get species_blue_sea_star_name => 'Stella marina azzurra';

  @override
  String get species_blue_sea_star_desc =>
      'Stella marina dai colori variabili che si rigenera da un singolo frammento di braccio nelle barriere indo-pacifiche.';

  @override
  String get species_reef_squid_name => 'Calamaro di barriera';

  @override
  String get species_reef_squid_desc =>
      'Calamaro di barriera meridionale comunemente incontrato nelle acque temperate australiane.';

  @override
  String get species_tiger_shrimp_name => 'Gambero tigre';

  @override
  String get species_tiger_shrimp_desc =>
      'Grande gambero fasciato presente sui fondali sabbiosi e nelle praterie di fanerogame dell\'Indo-Pacifico.';

  @override
  String get species_candy_crab_name => 'Granchio caramella';

  @override
  String get species_candy_crab_desc =>
      'Minuscolo granchio colorato che riprende i toni del corallo molle ospite, con escrescenze spinose rosa o gialle.';

  @override
  String get species_spider_crab_name => 'Granchio ragno decoratore';

  @override
  String get species_spider_crab_desc =>
      'Granchio dai movimenti lenti, ricoperto di spugne e alghe che vi fissa sopra per mimetizzarsi.';

  @override
  String get species_anemone_shrimp_name => 'Gambero degli anemoni magnifico';

  @override
  String get species_anemone_shrimp_desc =>
      'Gambero trasparente con marcature bianche e viola che vive tra i tentacoli degli anemoni.';

  @override
  String get species_snapping_shrimp_name => 'Gambero pistola';

  @override
  String get species_snapping_shrimp_desc =>
      'Piccolo gambero che produce uno schiocco fortissimo con la chela sovradimensionata, spesso in coppia con i ghiozzi.';

  @override
  String get species_glass_sponge_name => 'Cesto di Venere';

  @override
  String get species_glass_sponge_desc =>
      'Delicata spugna di vetro con un intricato scheletro siliceo, presente in acque profonde.';

  @override
  String get species_toxic_sea_urchin_name => 'Riccio fiore';

  @override
  String get species_toxic_sea_urchin_desc =>
      'Riccio ingannevolmente attraente, ricoperto di pedicellarie simili a fiori dal veleno potente.';

  @override
  String get species_slate_pencil_urchin_name => 'Riccio matita d\'ardesia';

  @override
  String get species_slate_pencil_urchin_desc =>
      'Riccio con spine spesse e arrotondate, presente sui substrati delle barriere caraibiche e atlantiche.';

  @override
  String get species_spiny_sea_star_name => 'Stella marina spinosa';

  @override
  String get species_spiny_sea_star_desc =>
      'Grande stella marina delle acque temperate con spine prominenti, presente nelle acque europee e atlantiche.';

  @override
  String get species_bat_star_name => 'Stella pipistrello';

  @override
  String get species_bat_star_desc =>
      'Stella marina del Pacifico dalle braccia palmate, di colore arancione, rosso o viola, vive nelle foreste di kelp.';

  @override
  String get species_sunflower_star_name => 'Stella girasole';

  @override
  String get species_sunflower_star_desc =>
      'Enorme stella marina dai movimenti rapidi, con un massimo di 24 braccia, presente nelle foreste di kelp del Pacifico.';

  @override
  String get species_blood_star_name => 'Stella di sangue';

  @override
  String get species_blood_star_desc =>
      'Stella marina rosso-arancio brillante dalle braccia sottili, presente nelle acque temperate del Pacifico.';

  @override
  String get species_common_cuttlefish_name => 'Seppia comune';

  @override
  String get species_common_cuttlefish_desc =>
      'Maestra del mimetismo delle acque europee e mediterranee, riconoscibile per le pupille a forma di W.';

  @override
  String get species_blue_spotted_crab_name =>
      'Granchio nuotatore a macchie blu';

  @override
  String get species_blue_spotted_crab_desc =>
      'Attivo granchio nuotatore con macchie blu sul carapace, presente sui substrati sabbiosi indo-pacifici.';

  @override
  String get species_sponge_crab_name => 'Granchio spugna';

  @override
  String get species_sponge_crab_desc =>
      'Granchio che ritaglia e trasporta una spugna viva sul dorso per mimetizzarsi.';

  @override
  String get species_horseshoe_crab_name => 'Limulo';

  @override
  String get species_horseshoe_crab_desc =>
      'Antico artropode chelicerato con un carapace a forma di elmo, presente sui fondali sabbiosi dell\'Atlantico.';

  @override
  String get species_sea_spider_name => 'Ragno di mare';

  @override
  String get species_sea_spider_desc =>
      'Delicato artropode marino dalle lunghe zampe, si osserva mentre cammina su idrozoi e briozoi.';

  @override
  String get species_sea_lily_name => 'Giglio di mare peduncolato';

  @override
  String get species_sea_lily_desc =>
      'Crinoide peduncolato, fossile vivente delle acque più profonde, filtra il cibo con le braccia piumate.';

  @override
  String get species_mantis_shrimp_lysiosquilla_name =>
      'Canocchia arpionatrice';

  @override
  String get species_mantis_shrimp_lysiosquilla_desc =>
      'Grande canocchia scavatrice con appendici ad arpione, presente sui substrati sabbiosi.';

  @override
  String get species_purple_sea_urchin_name => 'Riccio di mare viola';

  @override
  String get species_purple_sea_urchin_desc =>
      'Riccio viola molto abbondante nelle foreste di kelp e nelle pozze di marea rocciose del Pacifico.';

  @override
  String get species_crown_jellyfish_name => 'Medusa corona';

  @override
  String get species_crown_jellyfish_desc =>
      'Medusa viola intenso con la campana sormontata da una corona rilevata, presente nell\'Indo-Pacifico.';

  @override
  String get species_comb_jelly_name => 'Uva di mare';

  @override
  String get species_comb_jelly_desc =>
      'Piccolo ctenoforo bioluminescente con file di ciglia iridescenti e due lunghi tentacoli.';

  @override
  String get species_warty_sea_slug_name => 'Lumaca di mare verrucosa';

  @override
  String get species_warty_sea_slug_desc =>
      'Nudibranco blu e nero con tubercoli dalla sommità gialla, comunemente osservato nelle barriere indo-pacifiche.';

  @override
  String get species_doris_nudibranch_name => 'Limone di mare';

  @override
  String get species_doris_nudibranch_desc =>
      'Nudibranco doride giallo e maculato delle acque temperate del Pacifico, si nutre di spugne.';

  @override
  String get species_opalescent_nudibranch_name => 'Nudibranco opalescente';

  @override
  String get species_opalescent_nudibranch_desc =>
      'Eolidiaceo traslucido con cerata arancione brillante e linee dorsali blu, nelle acque del Pacifico.';

  @override
  String get species_clown_nudibranch_name => 'Nudibranco pagliaccio';

  @override
  String get species_clown_nudibranch_desc =>
      'Nudibranco rosa-arancio con macchie blu e bianche, presente nelle acque temperate australiane.';

  @override
  String get species_bottlenose_dolphin_name => 'Tursiope';

  @override
  String get species_bottlenose_dolphin_desc =>
      'Delfino curioso e giocoso, frequentemente incontrato dai subacquei nelle acque tropicali e temperate.';

  @override
  String get species_spinner_dolphin_name => 'Stenella dal lungo rostro';

  @override
  String get species_spinner_dolphin_desc =>
      'Delfino acrobatico noto per le piroette in aria, spesso avvistato in grandi branchi vicino alle barriere coralline.';

  @override
  String get species_common_dolphin_name => 'Delfino comune';

  @override
  String get species_common_dolphin_desc =>
      'Delfino dal nuoto veloce con un caratteristico disegno a clessidra, presente in mare aperto e nelle acque costiere.';

  @override
  String get species_spotted_dolphin_name => 'Stenella maculata atlantica';

  @override
  String get species_spotted_dolphin_desc =>
      'Delfino maculato e socievole che si avvicina spesso ai subacquei alle Bahamas e nei Caraibi.';

  @override
  String get species_rissos_dolphin_name => 'Grampo';

  @override
  String get species_rissos_dolphin_desc =>
      'Grande delfino dal corpo grigio coperto di cicatrici, presente nelle acque profonde al largo in tutto il mondo.';

  @override
  String get species_humpback_whale_name => 'Megattera';

  @override
  String get species_humpback_whale_desc =>
      'Balena maestosa nota per i salti fuori dall\'acqua e per i canti complessi, avvistata durante le migrazioni stagionali.';

  @override
  String get species_grey_whale_name => 'Balena grigia';

  @override
  String get species_grey_whale_desc =>
      'Misticete che si nutre sul fondo e migra lungo la costa del Pacifico, spesso ricoperto di cirripedi.';

  @override
  String get species_blue_whale_name => 'Balenottera azzurra';

  @override
  String get species_blue_whale_desc =>
      'L\'animale più grande mai esistito, occasionalmente incontrato dai subacquei nelle acque blu profonde.';

  @override
  String get species_sperm_whale_name => 'Capodoglio';

  @override
  String get species_sperm_whale_desc =>
      'Cetaceo dalle immersioni profonde con un\'enorme testa, a volte visto riposare in superficie tra un\'immersione e l\'altra.';

  @override
  String get species_orca_name => 'Orca';

  @override
  String get species_orca_desc =>
      'Superpredatore con inconfondibili marcature bianche e nere, presente in tutti i bacini oceanici.';

  @override
  String get species_minke_whale_name => 'Balenottera minore';

  @override
  String get species_minke_whale_desc =>
      'Misticete di taglia ridotta e curioso verso i subacquei, soprattutto nella Grande Barriera Corallina.';

  @override
  String get species_beluga_whale_name => 'Beluga';

  @override
  String get species_beluga_whale_desc =>
      'Cetaceo artico bianco noto per le vocalizzazioni e per il comportamento socievole nelle acque fredde.';

  @override
  String get species_pilot_whale_name => 'Globicefalo di Gray';

  @override
  String get species_pilot_whale_desc =>
      'Cetaceo socievole dalle immersioni profonde, spesso avvistato in grandi branchi nei mari tropicali e temperati caldi.';

  @override
  String get species_false_killer_whale_name => 'Pseudorca';

  @override
  String get species_false_killer_whale_desc =>
      'Grande delfino oceanico che occasionalmente si avvicina ai subacquei in acqua libera.';

  @override
  String get species_dugong_name => 'Dugongo';

  @override
  String get species_dugong_desc =>
      'Placido erbivoro che pascola nelle praterie di fanerogame dell\'Indo-Pacifico, parente stretto dei lamantini.';

  @override
  String get species_west_indian_manatee_name => 'Lamantino dei Caraibi';

  @override
  String get species_west_indian_manatee_desc =>
      'Erbivoro dai movimenti lenti, presente nelle acque calde e basse, negli estuari e nelle sorgenti dei Caraibi.';

  @override
  String get species_sea_otter_name => 'Lontra marina';

  @override
  String get species_sea_otter_desc =>
      'Carismatico mammifero marino delle foreste di kelp lungo la costa del Pacifico settentrionale.';

  @override
  String get species_california_sea_lion_name =>
      'Leone marino della California';

  @override
  String get species_california_sea_lion_desc =>
      'Pinnipede giocoso e agile che interagisce spesso con i subacquei lungo la costa del Pacifico.';

  @override
  String get species_steller_sea_lion_name => 'Leone marino di Steller';

  @override
  String get species_steller_sea_lion_desc =>
      'La più grande specie di leone marino, presente nelle fredde acque del Pacifico settentrionale vicino alle coste rocciose.';

  @override
  String get species_harbor_seal_name => 'Foca comune';

  @override
  String get species_harbor_seal_desc =>
      'Foca curiosa comunemente avvistata nelle acque costiere temperate, spesso in riposo sugli scogli vicino ai siti di immersione.';

  @override
  String get species_grey_seal_name => 'Foca grigia';

  @override
  String get species_grey_seal_desc =>
      'Grande foca giocosa dell\'Atlantico settentrionale, nota per avvicinarsi ai subacquei sott\'acqua.';

  @override
  String get species_northern_elephant_seal_name =>
      'Elefante marino settentrionale';

  @override
  String get species_northern_elephant_seal_desc =>
      'Enorme foca dalle immersioni profonde; i maschi hanno una grande proboscide. Presente lungo la costa del Pacifico orientale.';

  @override
  String get species_hawaiian_monk_seal_name => 'Foca monaca delle Hawaii';

  @override
  String get species_hawaiian_monk_seal_desc =>
      'Foca in pericolo critico endemica delle Hawaii, occasionalmente avvistata dai subacquei sulle barriere.';

  @override
  String get species_leopard_seal_name => 'Foca leopardo';

  @override
  String get species_leopard_seal_desc =>
      'Potente predatore antartico dal manto maculato, incontrato dai subacquei in acque fredde.';

  @override
  String get species_narwhal_name => 'Narvalo';

  @override
  String get species_narwhal_desc =>
      'Cetaceo artico con una lunga zanna a spirale, raramente avvistato ma iconico tra i mammiferi marini.';

  @override
  String get species_green_sea_turtle_name => 'Tartaruga verde';

  @override
  String get species_green_sea_turtle_desc =>
      'Grande tartaruga marina comunemente avvistata mentre pascola nelle praterie di fanerogame delle acque tropicali.';

  @override
  String get species_hawksbill_sea_turtle_name => 'Tartaruga embricata';

  @override
  String get species_hawksbill_sea_turtle_desc =>
      'Tartaruga di barriera dal becco appuntito, si nutre di spugne tra le formazioni coralline.';

  @override
  String get species_loggerhead_sea_turtle_name => 'Tartaruga caretta';

  @override
  String get species_loggerhead_sea_turtle_desc =>
      'Tartaruga dalla testa grande, presente nei mari temperati e tropicali, spesso vicino alle scogliere rocciose.';

  @override
  String get species_leatherback_sea_turtle_name => 'Tartaruga liuto';

  @override
  String get species_leatherback_sea_turtle_desc =>
      'La più grande tartaruga vivente, con un carapace coriaceo e flessibile, si immerge a profondità estreme.';

  @override
  String get species_olive_ridley_sea_turtle_name => 'Tartaruga olivacea';

  @override
  String get species_olive_ridley_sea_turtle_desc =>
      'La più piccola specie di tartaruga marina, nota per le nidificazioni di massa sincronizzate dette arribadas.';

  @override
  String get species_kemps_ridley_sea_turtle_name => 'Tartaruga di Kemp';

  @override
  String get species_kemps_ridley_sea_turtle_desc =>
      'Tartaruga marina in pericolo critico, presente soprattutto nel Golfo del Messico.';

  @override
  String get species_flatback_sea_turtle_name => 'Tartaruga dal dorso piatto';

  @override
  String get species_flatback_sea_turtle_desc =>
      'Endemica delle acque australiane, si distingue per il carapace piatto e per l\'habitat costiero.';

  @override
  String get species_brain_coral_name => 'Corallo cervello';

  @override
  String get species_brain_coral_desc =>
      'Massiccio corallo costruttore di barriera dalla superficie solcata che ricorda un cervello, comune nelle barriere caraibiche.';

  @override
  String get species_staghorn_coral_name => 'Corallo corna di cervo';

  @override
  String get species_staghorn_coral_desc =>
      'Corallo ramificato a crescita rapida che forma fitti boschetti, habitat fondamentale per i pesci di barriera.';

  @override
  String get species_elkhorn_coral_name => 'Corallo corna d\'alce';

  @override
  String get species_elkhorn_coral_desc =>
      'Grande corallo ramificato con rami piatti e palmati, costruttore chiave delle barriere caraibiche.';

  @override
  String get species_table_coral_name => 'Corallo a tavolo';

  @override
  String get species_table_coral_desc =>
      'Corallo che forma piatti orizzontali nelle barriere indo-pacifiche, offre rifugio a molte specie di pesci.';

  @override
  String get species_mushroom_coral_name => 'Corallo fungo';

  @override
  String get species_mushroom_coral_desc =>
      'Corallo solitario a vita libera a forma di disco, presente nelle zone sabbiose vicino alle barriere indo-pacifiche.';

  @override
  String get species_bubble_coral_name => 'Corallo a bolle';

  @override
  String get species_bubble_coral_desc =>
      'Corallo inconfondibile con vescicole simili ad acini d\'uva che si gonfiano di giorno per catturare la luce.';

  @override
  String get species_plate_coral_name => 'Corallo a piatto';

  @override
  String get species_plate_coral_desc =>
      'Corallo laminare sottile che forma mensole a spirale, comune sui pendii delle barriere indo-pacifiche.';

  @override
  String get species_pillar_coral_name => 'Corallo a pilastro';

  @override
  String get species_pillar_coral_desc =>
      'Raro corallo a crescita verticale che forma alte colonne, presente nei Caraibi.';

  @override
  String get species_star_coral_name => 'Corallo stella';

  @override
  String get species_star_coral_desc =>
      'Importante costruttore delle barriere caraibiche, forma grandi colonie a masso con polipi a forma di stella.';

  @override
  String get species_lettuce_coral_name => 'Corallo lattuga';

  @override
  String get species_lettuce_coral_desc =>
      'Corallo laminare sottile con pieghe simili a foglie, comune sulle pareti e sui pendii delle barriere caraibiche.';

  @override
  String get species_finger_coral_name => 'Corallo a dita';

  @override
  String get species_finger_coral_desc =>
      'Robusto corallo ramificato con spesse escrescenze a forma di dita, presente nelle barriere poco profonde.';

  @override
  String get species_massive_porites_name => 'Corallo Porites massiccio';

  @override
  String get species_massive_porites_desc =>
      'Grande corallo a masso che può crescere per secoli, costruttore dominante delle barriere indo-pacifiche.';

  @override
  String get species_cauliflower_coral_name => 'Corallo cavolfiore';

  @override
  String get species_cauliflower_coral_desc =>
      'Corallo ramificato compatto a forma di cavolfiore, diffuso nelle acque basse delle barriere tropicali.';

  @override
  String get species_flower_pot_coral_name => 'Corallo vaso di fiori';

  @override
  String get species_flower_pot_coral_desc =>
      'Colonia di polipi dai lunghi tentacoli che si estendono di giorno, simile a un mazzo di fiori.';

  @override
  String get species_cup_coral_name => 'Corallo a coppa arancione';

  @override
  String get species_cup_coral_desc =>
      'Corallo arancione brillante non fotosintetico, presente su pareti e strapiombi delle acque tropicali.';

  @override
  String get species_scroll_coral_name => 'Corallo a voluta';

  @override
  String get species_scroll_coral_desc =>
      'Corallo che forma ampie lamine arrotolate, comune sui pendii e nelle lagune delle barriere indo-pacifiche.';

  @override
  String get species_cabbage_coral_name => 'Corallo cavolo';

  @override
  String get species_cabbage_coral_desc =>
      'Corallo laminare a forma di disco che ricorda le foglie di cavolo, presente nelle zone riparate della barriera.';

  @override
  String get species_hammer_coral_name => 'Corallo martello';

  @override
  String get species_hammer_coral_desc =>
      'Corallo a polipi grandi con le punte dei tentacoli a forma di ancora o di martello, molto diffuso nelle barriere indo-pacifiche.';

  @override
  String get species_torch_coral_name => 'Corallo torcia';

  @override
  String get species_torch_coral_desc =>
      'Corallo ramificato con lunghi tentacoli fluttuanti terminanti in bulbi luminosi.';

  @override
  String get species_frogspawn_coral_name => 'Corallo uova di rana';

  @override
  String get species_frogspawn_coral_desc =>
      'Corallo a polipi grandi con le punte dei tentacoli ramificate, simili a uova di rana.';

  @override
  String get species_sea_fan_name => 'Gorgonia a ventaglio comune';

  @override
  String get species_sea_fan_desc =>
      'Gorgonia piatta a ventaglio orientata perpendicolarmente alle correnti, iconica delle barriere caraibiche.';

  @override
  String get species_venus_sea_fan_name => 'Ventaglio di Venere';

  @override
  String get species_venus_sea_fan_desc =>
      'Delicata gorgonia a ventaglio presente nelle barriere caraibiche poco profonde, in zone di corrente moderata.';

  @override
  String get species_deepwater_sea_fan_name => 'Gorgonia di profondità';

  @override
  String get species_deepwater_sea_fan_desc =>
      'Grande gorgonia cespugliosa presente sulle pareti profonde delle barriere caraibiche.';

  @override
  String get species_sea_whip_name => 'Gorgonia a frusta';

  @override
  String get species_sea_whip_desc =>
      'Gorgonia sottile a forma di bastoncino, ondeggia nelle correnti delle barriere atlantiche e caraibiche.';

  @override
  String get species_sea_plume_name => 'Gorgonia piumata';

  @override
  String get species_sea_plume_desc =>
      'Alta gorgonia piumosa che forma colonie a pennacchio sulle sommità delle barriere caraibiche.';

  @override
  String get species_organ_pipe_coral_name => 'Corallo canna d\'organo';

  @override
  String get species_organ_pipe_coral_desc =>
      'Tubi scheletrici rosso brillante con delicati polipi, presente nelle barriere indo-pacifiche riparate.';

  @override
  String get species_leather_coral_name => 'Corallo cuoio';

  @override
  String get species_leather_coral_desc =>
      'Corallo molle dalla superficie liscia e coriacea che forma grandi colonie a fungo.';

  @override
  String get species_toadstool_leather_coral_name => 'Corallo cuoio a fungo';

  @override
  String get species_toadstool_leather_coral_desc =>
      'Corallo molle con un peduncolo spesso e un cappello piatto, comune sui pianori corallini indo-pacifici.';

  @override
  String get species_pulsing_xenia_name => 'Xenia pulsante';

  @override
  String get species_pulsing_xenia_desc =>
      'Corallo molle con polipi che pulsano ritmicamente, presente nelle acque riparate dell\'Indo-Pacifico.';

  @override
  String get species_tree_coral_name => 'Corallo albero';

  @override
  String get species_tree_coral_desc =>
      'Vivace corallo molle che forma cespi arborescenti su pareti e strapiombi del Mar Rosso.';

  @override
  String get species_blue_coral_name => 'Corallo blu';

  @override
  String get species_blue_coral_desc =>
      'Ottocorallo unico dallo scheletro blu, presente sui pianori corallini poco profondi dell\'Indo-Pacifico.';

  @override
  String get species_black_coral_name => 'Corallo nero';

  @override
  String get species_black_coral_desc =>
      'Corallo di profondità dallo scheletro scuro, presente su pareti e salti sotto i 30 metri.';

  @override
  String get species_carnation_coral_name => 'Corallo garofano';

  @override
  String get species_carnation_coral_desc =>
      'Corallo molle dai colori brillanti, presente sotto le sporgenze e sulle pareti dell\'Indo-Pacifico.';

  @override
  String get species_wire_coral_name => 'Corallo filo';

  @override
  String get species_wire_coral_desc =>
      'Lungo corallo nero a spirale che forma fruste avvolte, ospita ghiozzi e gamberi.';

  @override
  String get species_dead_mans_fingers_name => 'Dita di uomo morto';

  @override
  String get species_dead_mans_fingers_desc =>
      'Corallo molle carnoso con lobi a forma di dita, comune nelle barriere temperate dell\'Atlantico settentrionale.';

  @override
  String get species_sun_coral_name => 'Corallo sole';

  @override
  String get species_sun_coral_desc =>
      'Corallo giallo-arancio non fotosintetico che apre i polipi di notte sulle pareti indo-pacifiche.';

  @override
  String get species_lace_coral_name => 'Corallo merletto';

  @override
  String get species_lace_coral_desc =>
      'Delicato idrocorallo rosa con rami a merletto, presente nelle fessure e sotto le sporgenze.';

  @override
  String get species_kenya_tree_coral_name => 'Corallo albero del Kenya';

  @override
  String get species_kenya_tree_coral_desc =>
      'Robusto corallo molle con rami arborescenti, comune nell\'Indo-Pacifico.';

  @override
  String get species_colt_coral_name => 'Corallo colt';

  @override
  String get species_colt_coral_desc =>
      'Corallo molle con rami spessi e gommosi ricoperti di piccoli polipi nelle barriere indo-pacifiche.';

  @override
  String get species_turtle_grass_name => 'Erba tartaruga';

  @override
  String get species_turtle_grass_desc =>
      'Fanerogama dominante dei Caraibi con foglie larghe e piatte, fonte di cibo vitale per le tartarughe marine.';

  @override
  String get species_eelgrass_name => 'Zostera';

  @override
  String get species_eelgrass_desc =>
      'Fanerogama delle acque temperate che forma fitte praterie sottomarine usate come area di nursery.';

  @override
  String get species_manatee_grass_name => 'Erba dei lamantini';

  @override
  String get species_manatee_grass_desc =>
      'Fanerogama dalle foglie cilindriche presente nelle zone sabbiose caraibiche, spesso vicino alle praterie di erba tartaruga.';

  @override
  String get species_shoal_grass_name => 'Erba di secca';

  @override
  String get species_shoal_grass_desc =>
      'Fanerogama pioniera dalle foglie strette, colonizza le zone sabbiose disturbate dei Caraibi.';

  @override
  String get species_paddle_grass_name => 'Erba a pagaia';

  @override
  String get species_paddle_grass_desc =>
      'Piccola e delicata fanerogama dalle foglie ovali, presente nelle acque più profonde di tutti i tropici.';

  @override
  String get species_neptune_grass_name => 'Posidonia';

  @override
  String get species_neptune_grass_desc =>
      'Fanerogama mediterranea che forma vaste praterie fondamentali per gli ecosistemi marini costieri.';

  @override
  String get species_giant_kelp_name => 'Kelp gigante';

  @override
  String get species_giant_kelp_desc =>
      'Specie che forma imponenti foreste sottomarine alte fino a 60 metri, simbolo delle immersioni in California.';

  @override
  String get species_bull_kelp_name => 'Kelp toro';

  @override
  String get species_bull_kelp_desc =>
      'Kelp del Pacifico con un unico lungo stipite e un galleggiante bulboso, forma fitte foreste con chioma superficiale.';

  @override
  String get species_bladder_wrack_name => 'Fuco vescicoloso';

  @override
  String get species_bladder_wrack_desc =>
      'Alga bruna comune con vescicole d\'aria appaiate, presente nelle zone intertidali dell\'Atlantico settentrionale.';

  @override
  String get species_sargassum_name => 'Sargasso';

  @override
  String get species_sargassum_desc =>
      'Alga bruna galleggiante che forma zattere in cui si rifugiano pesci giovanili e invertebrati.';

  @override
  String get species_kelp_forest_ecklonia_name => 'Kelp Ecklonia';

  @override
  String get species_kelp_forest_ecklonia_desc =>
      'Kelp dominante nelle acque dell\'emisfero australe, forma importanti foreste sottomarine.';

  @override
  String get species_coralline_algae_name => 'Alghe coralline';

  @override
  String get species_coralline_algae_desc =>
      'Alga rossa incrostante e dura che cementa le strutture della barriera e dona alle scogliere una tonalità rosata.';

  @override
  String get species_irish_moss_name => 'Muschio d\'Irlanda';

  @override
  String get species_irish_moss_desc =>
      'Alga rossa a ventaglio presente sulle coste rocciose della zona intertidale dell\'Atlantico settentrionale.';

  @override
  String get species_dulse_name => 'Dulse';

  @override
  String get species_dulse_desc =>
      'Alga piatta rosso-violacea che cresce su rocce e stipiti di kelp nelle fredde acque settentrionali.';

  @override
  String get species_halimeda_name => 'Halimeda';

  @override
  String get species_halimeda_desc =>
      'Alga verde calcificata con segmenti a forma di disco, contribuisce in gran parte alla sabbia della barriera.';

  @override
  String get species_sea_lettuce_name => 'Lattuga di mare';

  @override
  String get species_sea_lettuce_desc =>
      'Alga verde brillante a lamina, presente nelle acque costiere poco profonde di tutto il mondo.';

  @override
  String get species_caulerpa_name => 'Alga a grappolo verde';

  @override
  String get species_caulerpa_desc =>
      'Alga verde strisciante con fronde simili ad acini d\'uva, presente sui detriti corallini e sulla sabbia delle barriere tropicali.';

  @override
  String get species_mermaid_fan_name => 'Ventaglio di sirena';

  @override
  String get species_mermaid_fan_desc =>
      'Alga verde calcificata a forma di piccolo ventaglio, comune sui fondali sabbiosi caraibici.';

  @override
  String get species_shaving_brush_algae_name => 'Alga pennello da barba';

  @override
  String get species_shaving_brush_algae_desc =>
      'Alga verde calcificata con un ciuffo a pennello su un peduncolo, presente sui fondali sabbiosi caraibici.';

  @override
  String get species_finger_kelp_name => 'Laminaria digitata';

  @override
  String get species_finger_kelp_desc =>
      'Alga bruna con fronde a forma di dita che forma praterie di kelp nelle acque costiere dell\'Atlantico settentrionale.';

  @override
  String get species_banded_sea_krait_name => 'Serpente marino fasciato';

  @override
  String get species_banded_sea_krait_desc =>
      'Serpente marino velenoso con bande grigio-blu e nere, docile e comunemente avvistato nelle barriere indo-pacifiche.';

  @override
  String get species_olive_sea_snake_name => 'Serpente marino olivastro';

  @override
  String get species_olive_sea_snake_desc =>
      'Serpente marino curioso delle barriere australiane, noto per avvicinarsi ai subacquei.';

  @override
  String get species_yellow_bellied_sea_snake_name =>
      'Serpente marino dal ventre giallo';

  @override
  String get species_yellow_bellied_sea_snake_desc =>
      'Serpente marino pelagico dal ventre giallo, la specie di serpente più diffusa sulla Terra.';

  @override
  String get species_marine_iguana_name => 'Iguana marina';

  @override
  String get species_marine_iguana_desc =>
      'Endemica delle Galapagos, è l\'unica lucertola che si nutre di alghe sott\'acqua.';

  @override
  String get species_saltwater_crocodile_name => 'Coccodrillo marino';

  @override
  String get species_saltwater_crocodile_desc =>
      'Il più grande rettile vivente, presente nelle acque costiere e negli estuari dell\'Indo-Pacifico.';

  @override
  String get common_action_done => 'Fatto';

  @override
  String get common_action_more => 'Altro';

  @override
  String get common_label_displayName => 'Nome visualizzato';

  @override
  String common_relativeTime_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}g fa',
      one: '${count}g fa',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}h fa',
      one: '${count}h fa',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tra ${count}g',
      one: 'tra ${count}g',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tra ${count}h',
      one: 'tra ${count}h',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_inLessThanMinute => 'tra <1m';

  @override
  String common_relativeTime_inMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tra ${count}m',
      one: 'tra ${count}m',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_justNow => 'adesso';

  @override
  String common_relativeTime_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}m fa',
      one: '${count}m fa',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}mesi fa',
      one: '${count}mese fa',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_overdue => 'in ritardo';

  @override
  String get media_cache_calculating => 'Calcolo della dimensione della cache…';

  @override
  String get media_cache_cardTitle => 'Gestione della cache';

  @override
  String get media_cache_clearAction => 'Svuota la cache';

  @override
  String get media_cache_clearBody =>
      'Rimuove le miniature e le immagini di rete a piena risoluzione scaricate. I media collegati vengono mantenuti; le immagini verranno scaricate di nuovo alla prossima visualizzazione.';

  @override
  String get media_cache_clearConfirm => 'Svuota';

  @override
  String media_cache_clearError(String error) {
    return 'Svuotamento non riuscito: $error';
  }

  @override
  String get media_cache_clearTitle =>
      'Svuotare la cache delle immagini di rete?';

  @override
  String get media_cache_cleared => 'Cache svuotata';

  @override
  String get media_cache_diskCache => 'Cache su disco';

  @override
  String media_cache_error(String error) {
    return 'Errore: $error';
  }

  @override
  String get media_credentials_actionTest => 'Prova le credenziali';

  @override
  String media_credentials_authLabel(String authType) {
    return 'Auth: $authType';
  }

  @override
  String get media_credentials_deleteBody =>
      'Rimuove le credenziali salvate. Gli elementi collegati tramite questo host mostreranno «Accedi per visualizzare» finché non li aggiungi di nuovo.';

  @override
  String media_credentials_deleteError(String error) {
    return 'Eliminazione non riuscita: $error';
  }

  @override
  String media_credentials_deleteTitle(String host) {
    return 'Eliminare $host?';
  }

  @override
  String media_credentials_deleted(String host) {
    return '$host eliminato';
  }

  @override
  String media_credentials_editTitle(String host) {
    return 'Modifica $host';
  }

  @override
  String get media_credentials_emptySubtitle =>
      'Le credenziali per host aggiunte durante le importazioni da URL o da manifest compaiono qui.';

  @override
  String get media_credentials_emptyTitle => 'Nessuna credenziale salvata';

  @override
  String media_credentials_lastUsed(String when) {
    return 'Ultimo utilizzo $when';
  }

  @override
  String get media_credentials_loadError =>
      'Impossibile caricare gli host salvati';

  @override
  String get media_credentials_loading => 'Caricamento degli host salvati...';

  @override
  String media_credentials_saveError(String error) {
    return 'Salvataggio non riuscito: $error';
  }

  @override
  String get media_credentials_savedHostsTitle => 'Host salvati';

  @override
  String media_credentials_testError(String error) {
    return 'Prova non riuscita: $error';
  }

  @override
  String media_credentials_testFailed(String host) {
    return 'Credenziali non valide per $host';
  }

  @override
  String media_credentials_testOk(String host) {
    return 'Credenziali valide per $host';
  }

  @override
  String get media_manifest_actionPollNow => 'Interroga ora';

  @override
  String get media_manifest_cardTitle => 'Abbonamenti ai manifest';

  @override
  String get media_manifest_deleteBody =>
      'Rimuove l’abbonamento. Le voci già importate restano (puoi ripulirle dalla coda degli orfani).';

  @override
  String media_manifest_deleteError(String error) {
    return 'Eliminazione non riuscita: $error';
  }

  @override
  String media_manifest_deleteTitle(String name) {
    return 'Eliminare $name?';
  }

  @override
  String get media_manifest_editTitle => 'Modifica abbonamento';

  @override
  String get media_manifest_emptySubtitle =>
      'Abbonati a un manifest Atom/RSS, JSON o CSV dalla scheda URL per mantenere sincronizzata la tua libreria.';

  @override
  String get media_manifest_emptyTitle => 'Nessun abbonamento ai manifest';

  @override
  String media_manifest_lastError(String error) {
    return 'Ultimo errore: $error';
  }

  @override
  String media_manifest_lastPolled(String when) {
    return 'Ultima interrogazione $when';
  }

  @override
  String get media_manifest_loadError => 'Impossibile caricare gli abbonamenti';

  @override
  String get media_manifest_loading => 'Caricamento degli abbonamenti...';

  @override
  String get media_manifest_neverPolled => 'Mai interrogato';

  @override
  String media_manifest_nextPoll(String when) {
    return 'Prossima $when';
  }

  @override
  String get media_manifest_notFound => 'Abbonamento non trovato';

  @override
  String media_manifest_pollError(String error) {
    return 'Interrogazione non riuscita: $error';
  }

  @override
  String media_manifest_polled(String name) {
    return '$name interrogato';
  }

  @override
  String media_manifest_polling(String name) {
    return 'Interrogazione di $name...';
  }

  @override
  String media_manifest_saveError(String error) {
    return 'Salvataggio non riuscito: $error';
  }

  @override
  String media_manifest_updateError(String error) {
    return 'Impossibile aggiornare: $error';
  }

  @override
  String get media_manifest_urlLabel => 'URL del manifest';

  @override
  String media_scan_failed(String error) {
    return 'Scansione non riuscita: $error';
  }

  @override
  String media_scan_progressItems(int done, int total) {
    return '$done / $total elementi';
  }

  @override
  String media_scan_progressReachability(int available, int unreachable) {
    return '$available raggiungibili  ·  $unreachable non raggiungibili';
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
          'Scansionati $total elementi in ${seconds}s: $available raggiungibili, $unreachable non raggiungibili',
      one:
          'Scansionato $total elemento in ${seconds}s: $available raggiungibile, $unreachable non raggiungibile',
    );
    return '$_temp0';
  }

  @override
  String media_scan_summarySkipped(String base, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saltati (nessun URL)',
      one: '$count saltato (nessun URL)',
    );
    return '$base, $_temp0';
  }

  @override
  String get media_scan_title => 'Scansiona tutti i media di rete';

  @override
  String get settings_mediaSources_androidUriTitle =>
      'Autorizzazioni URI Android';

  @override
  String settings_mediaSources_androidUriUsage(int used, int limit) {
    return '$used / $limit URI persistenti in uso';
  }

  @override
  String get settings_mediaSources_counting => 'Conteggio…';

  @override
  String settings_mediaSources_error(String error) {
    return 'Errore: $error';
  }

  @override
  String get settings_mediaSources_loading => 'Caricamento…';

  @override
  String settings_mediaSources_localFilesCounts(
    int available,
    int unavailable,
  ) {
    return '$available disponibili, $unavailable non disponibili';
  }

  @override
  String get settings_mediaSources_photoLibrarySubtitle =>
      'Apple Photos / Google Photos / iCloud';

  @override
  String get settings_mediaSources_reverifyAll =>
      'Riverifica tutti i file locali';

  @override
  String settings_mediaSources_reverifyFailed(String error) {
    return 'Riverifica non riuscita: $error';
  }

  @override
  String settings_mediaSources_reverifyResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi aggiornati',
      one: '$count elemento aggiornato',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_checkAll => 'Controlla tutti i media';

  @override
  String settings_mediaSources_checkAllResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi aggiornati',
      one: '$count elemento aggiornato',
    );
    return '$_temp0';
  }

  @override
  String settings_mediaSources_checkAllBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Impossibile controllare nessuno dei $count elementi. Le loro origini non sono raggiungibili al momento.',
      one:
          'Impossibile controllare l’elemento. La sua origine non è raggiungibile al momento.',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_title => 'Sorgenti media';

  @override
  String get settings_networkSources_scanDescription =>
      'Ricontrolla presso il relativo host ogni foto importata da URL o da manifest. Contrassegna gli elementi non raggiungibili in modo che risultino «mancanti» nella libreria e possano essere ripuliti.';

  @override
  String statistics_conditions_entryMethod_semanticLabel(String description) {
    return 'Grafico a barre. Metodi di ingresso. $description';
  }

  @override
  String statistics_conditions_visibility_semanticLabel(String description) {
    return 'Grafico a torta. Distribuzione della visibilità. $description';
  }

  @override
  String statistics_conditions_waterType_semanticLabel(String description) {
    return 'Grafico a torta. Distribuzione dei tipi di acqua. $description';
  }

  @override
  String statistics_progression_divesBySuitThickness_semanticLabel(
    String description,
  ) {
    return 'Grafico a barre. Immersioni per spessore della muta. $description';
  }

  @override
  String statistics_progression_divesPerYear_countInYear(
    int count,
    String year,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni nel $year',
      one: '1 immersione nel $year',
    );
    return '$_temp0';
  }

  @override
  String statistics_progression_divesPerYear_semanticLabel(String description) {
    return 'Grafico a barre. Immersioni per anno. $description';
  }

  @override
  String get statistics_records_unavailable => 'Record non disponibili';

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
  String get statistics_summary_distributions_title => 'Distribuzioni';

  @override
  String get statistics_summary_diveTypes_error =>
      'Impossibile caricare i dati sui tipi di immersione';

  @override
  String get statistics_summary_diveTypes_unknown => 'Sconosciuto';

  @override
  String get statistics_summary_divesPerMonth => 'Immersioni / mese';

  @override
  String get statistics_summary_divesPerYear => 'Immersioni / anno';

  @override
  String statistics_timePatterns_dayOfWeek_semanticLabel(String description) {
    return 'Grafico a barre. Immersioni per giorno della settimana. $description';
  }

  @override
  String statistics_timePatterns_seasonal_semanticLabel(String description) {
    return 'Grafico a barre. Immersioni per mese. $description';
  }

  @override
  String statistics_timePatterns_surfaceInterval_statLabel(
    String label,
    String value,
  ) {
    return 'Intervallo di superficie $label: $value';
  }

  @override
  String get statistics_timePatterns_timeOfDay_afternoon => 'Pomeriggio';

  @override
  String get statistics_timePatterns_timeOfDay_evening => 'Sera';

  @override
  String get statistics_timePatterns_timeOfDay_morning => 'Mattina';

  @override
  String get statistics_timePatterns_timeOfDay_night => 'Notte';

  @override
  String statistics_timePatterns_timeOfDay_semanticLabel(String description) {
    return 'Grafico a torta. Immersioni per fascia oraria. $description';
  }

  @override
  String get columnConfig_displayOptions => 'Opzioni di visualizzazione';

  @override
  String get columnConfig_noExtraFields =>
      'Nessun campo extra configurato. Aggiungi campi qui sotto.';

  @override
  String get columnConfig_savePresetTitle => 'Salva preimpostazione';

  @override
  String get columnConfig_section => 'Sezione';

  @override
  String get columnConfig_showTags => 'Mostra tag';

  @override
  String get columnConfig_showTags_subtitle =>
      'Mostra i tag sulle schede immersione dettagliate';

  @override
  String get columnConfig_slot_date => 'Data / Sottotitolo';

  @override
  String get columnConfig_slot_slot1 => 'Posizione 1';

  @override
  String get columnConfig_slot_slot2 => 'Posizione 2';

  @override
  String get columnConfig_slot_slot3 => 'Posizione 3';

  @override
  String get columnConfig_slot_slot4 => 'Posizione 4';

  @override
  String get columnConfig_slot_stat1 => 'Statistica 1';

  @override
  String get columnConfig_slot_stat2 => 'Statistica 2';

  @override
  String get columnConfig_slot_subtitle => 'Sottotitolo';

  @override
  String get columnConfig_slot_title => 'Titolo';

  @override
  String get columnConfig_tooltip_columnSettings => 'Impostazioni colonne';

  @override
  String get common_action_add => 'Aggiungi';

  @override
  String get common_action_pin => 'Fissa';

  @override
  String get common_action_remove => 'Rimuovi';

  @override
  String get common_action_unpin => 'Rimuovi fissaggio';

  @override
  String diveLog_filterChip_dateRange(String end, String start) {
    return '$start - $end';
  }

  @override
  String diveLog_filterChip_equipmentCount(int count) {
    return '$count attrezzature';
  }

  @override
  String get diveLog_filter_allComputers => 'Tutti i computer';

  @override
  String get diveLog_filter_noComputersRegistered =>
      'Nessun computer subacqueo registrato';

  @override
  String diveLog_filter_sectionDepthRangeUnit(String unit) {
    return 'Intervallo di profondità ($unit)';
  }

  @override
  String get diveLog_filter_sectionDiveComputer => 'Computer subacqueo';

  @override
  String diveLog_listPage_semanticsDiveAtSite(int diveNumber, String siteName) {
    return 'Immersione $diveNumber presso $siteName';
  }

  @override
  String get enum_listViewMode_compact => 'Compatta';

  @override
  String get enum_listViewMode_dense => 'Densa';

  @override
  String get enum_listViewMode_detailed => 'Dettagliata';

  @override
  String get enum_listViewMode_table => 'Tabella';

  @override
  String get enum_profileMetric_ascentRate => 'Velocità di risalita';

  @override
  String get enum_profileMetric_cns => 'CNS%';

  @override
  String get enum_profileMetric_otu => 'OTU';

  @override
  String get enum_sortField_bottomTime => 'Tempo di fondo';

  @override
  String get enum_sortField_serviceDue => 'Manutenzione prevista';

  @override
  String get listViewMode_tooltip => 'Modalità di visualizzazione';

  @override
  String marineLife_speciesManage_errorLoading(Object error) {
    return 'Errore nel caricamento delle specie: $error';
  }

  @override
  String get settings_appearance_header_cards => 'Schede';

  @override
  String get settings_appearance_header_listView => 'Vista elenco';

  @override
  String get settings_appearance_header_tableMode => 'Modalità tabella';

  @override
  String get settings_appearance_listFields_buddies => 'Campi elenco compagni';

  @override
  String get settings_appearance_listFields_certifications =>
      'Campi elenco certificazioni';

  @override
  String get settings_appearance_listFields_courses => 'Campi elenco corsi';

  @override
  String get settings_appearance_listFields_diveCenters =>
      'Campi elenco centri immersioni';

  @override
  String get settings_appearance_listFields_dives => 'Campi elenco immersioni';

  @override
  String get settings_appearance_listFields_equipment =>
      'Campi elenco attrezzatura';

  @override
  String get settings_appearance_listFields_sites => 'Campi elenco siti';

  @override
  String get settings_appearance_listFields_subtitle =>
      'Personalizza i campi mostrati nelle viste elenco';

  @override
  String get settings_appearance_listFields_trips => 'Campi elenco viaggi';

  @override
  String get settings_appearance_listView_buddies => 'Vista elenco compagni';

  @override
  String get settings_appearance_listView_buddies_subtitle =>
      'Layout predefinito dell’elenco dei compagni';

  @override
  String get settings_appearance_listView_certifications =>
      'Vista elenco certificazioni';

  @override
  String get settings_appearance_listView_certifications_subtitle =>
      'Layout predefinito dell’elenco delle certificazioni';

  @override
  String get settings_appearance_listView_courses => 'Vista elenco corsi';

  @override
  String get settings_appearance_listView_courses_subtitle =>
      'Layout predefinito dell’elenco dei corsi';

  @override
  String get settings_appearance_listView_diveCenters =>
      'Vista elenco centri immersioni';

  @override
  String get settings_appearance_listView_diveCenters_subtitle =>
      'Layout predefinito dell’elenco dei centri immersioni';

  @override
  String get settings_appearance_listView_dives => 'Vista elenco immersioni';

  @override
  String get settings_appearance_listView_dives_subtitle =>
      'Layout predefinito dell’elenco delle immersioni';

  @override
  String get settings_appearance_listView_equipment =>
      'Vista elenco attrezzatura';

  @override
  String get settings_appearance_listView_equipment_subtitle =>
      'Layout predefinito dell’elenco dell’attrezzatura';

  @override
  String get settings_appearance_listView_sites => 'Vista elenco siti';

  @override
  String get settings_appearance_listView_sites_subtitle =>
      'Layout predefinito dell’elenco dei siti';

  @override
  String get settings_appearance_listView_trips => 'Vista elenco viaggi';

  @override
  String get settings_appearance_listView_trips_subtitle =>
      'Layout predefinito dell’elenco dei viaggi';

  @override
  String get settings_appearance_showDataSourceBadges =>
      'Mostra i badge della fonte dei dati';

  @override
  String get settings_appearance_showDataSourceBadges_subtitle =>
      'Mostra l’attribuzione della fonte sui valori dell’immersione';

  @override
  String get settings_appearance_title_buddies => 'Aspetto dei compagni';

  @override
  String get settings_appearance_title_certifications =>
      'Aspetto delle certificazioni';

  @override
  String get settings_appearance_title_courses => 'Aspetto dei corsi';

  @override
  String get settings_appearance_title_diveCenters =>
      'Aspetto dei centri immersioni';

  @override
  String get settings_appearance_title_dives => 'Aspetto delle immersioni';

  @override
  String get settings_appearance_title_equipment => 'Aspetto dell’attrezzatura';

  @override
  String get settings_appearance_title_sites => 'Aspetto dei siti';

  @override
  String get settings_appearance_title_trips => 'Aspetto dei viaggi';

  @override
  String get settings_cloudSync_troubleshoot_tileSubtitle =>
      'Risolvi una sincronizzazione bloccata o libera spazio nel cloud';

  @override
  String get settings_data_header_dataTools => 'Strumenti per i dati';

  @override
  String get settings_decompression_ascentGasLabel =>
      'Pianifica la risalita con';

  @override
  String get settings_decompression_ascentGas_allCarried =>
      'Tutte le bombole trasportate';

  @override
  String get settings_decompression_ascentGas_decoStage =>
      'Bombola deco/stage + gas principale';

  @override
  String get settings_decompression_cnsSource => 'Fonte CNS';

  @override
  String get settings_decompression_decoStopSource => 'Fonte delle soste deco';

  @override
  String get settings_decompression_header_ascent =>
      'Pianificazione della risalita';

  @override
  String get settings_decompression_header_ascent_subtitle =>
      'A quali bombole trasportate può passare la risalita simulata (TTS, ceiling e soste) a ciascuna profondità. Vengono considerati solo i gas registrati nell’immersione.';

  @override
  String get settings_decompression_header_dataSources =>
      'Preferenze sulle fonti dei dati';

  @override
  String get settings_decompression_header_dataSources_subtitle =>
      'Se impostato su Computer subacqueo, l’app usa i dati riportati dal computer subacqueo quando sono disponibili. In mancanza dei dati del computer, ricorre ai valori calcolati.';

  @override
  String get settings_decompression_ndlSource => 'Fonte NDL';

  @override
  String get settings_decompression_sourceCalculated => 'Calcolato';

  @override
  String get settings_decompression_sourceComputer => 'Computer subacqueo';

  @override
  String get settings_decompression_ttsSource => 'Fonte TTS';

  @override
  String settings_fixDiveTimes_applied(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni aggiornate',
      one: 'immersione aggiornata',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'ore',
      one: 'ora',
    );
    return '$count $_temp0 di $hours $_temp1.';
  }

  @override
  String settings_fixDiveTimes_apply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni',
      one: 'immersione',
    );
    return 'Applica a $count $_temp0';
  }

  @override
  String get settings_fixDiveTimes_clearRange => 'Cancella intervallo date';

  @override
  String get settings_fixDiveTimes_confirmApply => 'Applica';

  @override
  String settings_fixDiveTimes_confirmBody(
    int count,
    String hours,
    int hoursAbs,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni',
      one: 'immersione',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'ore',
      one: 'ora',
    );
    return 'Questa operazione sposterà $count $_temp0 di $hours $_temp1. Non può essere annullata automaticamente.';
  }

  @override
  String get settings_fixDiveTimes_confirmTitle =>
      'Applica lo scostamento orario';

  @override
  String get settings_fixDiveTimes_dateRangeFilter =>
      'Filtro per intervallo di date';

  @override
  String get settings_fixDiveTimes_deselectAll => 'Deseleziona tutto';

  @override
  String get settings_fixDiveTimes_diveFallback => 'Immersione';

  @override
  String settings_fixDiveTimes_diveNumber(int number) {
    return 'Immersione n. $number';
  }

  @override
  String get settings_fixDiveTimes_empty => 'Nessuna immersione trovata.';

  @override
  String get settings_fixDiveTimes_emptyFiltered =>
      'Nessuna immersione trovata in questo intervallo di date.';

  @override
  String get settings_fixDiveTimes_enterOffsetHint =>
      'Inserisci uno scostamento in ore';

  @override
  String get settings_fixDiveTimes_from => 'Da';

  @override
  String get settings_fixDiveTimes_hourOffset => 'Scostamento orario';

  @override
  String get settings_fixDiveTimes_hoursField => 'Ore (es. +7, -5)';

  @override
  String settings_fixDiveTimes_loadError(String error) {
    return 'Impossibile caricare le immersioni: $error';
  }

  @override
  String get settings_fixDiveTimes_noSelection =>
      'Nessuna immersione selezionata.';

  @override
  String get settings_fixDiveTimes_offsetHint =>
      'Inserisci un numero intero positivo o negativo per spostare gli orari delle immersioni.';

  @override
  String settings_fixDiveTimes_preview(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'immersioni verranno spostate',
      one: 'immersione verrà spostata',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'ore',
      one: 'ora',
    );
    return 'Anteprima: $count $_temp0 di $hours $_temp1.';
  }

  @override
  String get settings_fixDiveTimes_selectAll => 'Seleziona tutto';

  @override
  String get settings_fixDiveTimes_selectDivesHint =>
      'Seleziona le immersioni a cui applicarlo';

  @override
  String get settings_fixDiveTimes_subtitle =>
      'Regola gli orari delle immersioni importate';

  @override
  String get settings_fixDiveTimes_title =>
      'Correggi gli orari delle immersioni';

  @override
  String get settings_fixDiveTimes_to => 'A';

  @override
  String get settings_fixDiveTimes_zeroOffset =>
      'Lo scostamento orario è 0, non c’è nulla da cambiare.';

  @override
  String get settings_syncDevices_appBar_refreshTooltip => 'Aggiorna';

  @override
  String get settings_syncDevices_appBar_title =>
      'Dispositivi su questo servizio';

  @override
  String get settings_syncDevices_empty =>
      'Nessun file di sincronizzazione su questo servizio.';

  @override
  String settings_syncDevices_readError(String error) {
    return 'Impossibile leggere il servizio.\n$error';
  }

  @override
  String get settings_syncDevices_removal_noBackend =>
      'Nessun servizio cloud configurato';

  @override
  String get settings_syncDevices_removal_unreachable =>
      'Impossibile raggiungere il servizio. Non è stato rimosso nulla.';

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
          'Questa operazione elimina $count file ($size) appartenenti a $name.\n\nQuel dispositivo fa ancora parte di questa sincronizzazione. Se torna online si ricostruirà dal servizio invece di far risorgere vecchi dati, ma tutte le modifiche che non ha ancora pubblicato andranno perse. I tuoi dati delle immersioni su QUESTO dispositivo non sono interessati.',
      one:
          'Questa operazione elimina 1 file ($size) appartenente a $name.\n\nQuel dispositivo fa ancora parte di questa sincronizzazione. Se torna online si ricostruirà dal servizio invece di far risorgere vecchi dati, ma tutte le modifiche che non ha ancora pubblicato andranno perse. I tuoi dati delle immersioni su QUESTO dispositivo non sono interessati.',
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
          'Questa operazione elimina $count file ($size) appartenenti a $name. Sono residui di una libreria con cui nessun dispositivo si sincronizza più. I tuoi dati delle immersioni non sono interessati.',
      one:
          'Questa operazione elimina 1 file ($size) appartenente a $name. È un residuo di una libreria con cui nessun dispositivo si sincronizza più. I tuoi dati delle immersioni non sono interessati.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_removeDialog_title(String name) {
    return 'Rimuovere i file di $name?';
  }

  @override
  String settings_syncDevices_removeProgressTitle(String name) {
    return 'Rimozione dei file di $name';
  }

  @override
  String get settings_syncDevices_removeTooltip =>
      'Rimuovi i file di questo dispositivo';

  @override
  String get settings_syncDevices_state_active => 'Sincronizza normalmente';

  @override
  String get settings_syncDevices_state_retired => 'Dismesso';

  @override
  String get settings_syncDevices_state_staleEpoch =>
      'Residuo di una libreria precedente, nessun dispositivo lo legge';

  @override
  String get settings_syncDevices_state_thisDevice => 'Questo dispositivo';

  @override
  String get settings_syncDevices_state_unreadable =>
      'Nessun manifesto leggibile: un caricamento incompleto oppure criptato';

  @override
  String settings_syncDevices_summary(
    int deviceCount,
    int fileCount,
    String size,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      deviceCount,
      locale: localeName,
      other: '$deviceCount dispositivi',
      one: '1 dispositivo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: '$fileCount file',
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
          '$count residui di librerie sostituite o dismesse, occupano $size.',
      one: '1 residuo di una libreria sostituita o dismessa, occupa $size.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_tile_filesSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file',
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
      other: '$count file',
      one: '1 file',
    );
    return '$_temp0, $size, $when';
  }

  @override
  String settings_syncDevices_unnamedDevice(String shortId) {
    return 'Dispositivo $shortId';
  }

  @override
  String get settings_syncMaintenance_keepAppOpen =>
      'Tieni l’app aperta finché l’operazione non è terminata. Chiuderla adesso lascia il servizio svuotato solo in parte e la sincronizzazione successiva deve ricominciare da capo.';

  @override
  String get settings_syncMaintenance_phase_clearingOldFiles =>
      'Eliminazione dei vecchi file';

  @override
  String get settings_syncMaintenance_phase_deleting => 'Eliminazione';

  @override
  String get settings_syncMaintenance_phase_publishingLibrary =>
      'Pubblicazione della libreria';

  @override
  String get settings_cloudSync_adopt_progressTitle =>
      'Adozione della libreria ripristinata';

  @override
  String get settings_cloudSync_replaceLibrary_progressTitle =>
      'Sostituzione della libreria cloud';

  @override
  String settings_syncDevices_nameWithId(String name, String shortId) {
    return '$name ($shortId)';
  }

  @override
  String get settings_syncMaintenance_phase_applyingLibrary =>
      'Applicazione della libreria';

  @override
  String get settings_syncMaintenance_phase_backingUp =>
      'Backup di questo dispositivo';

  @override
  String get settings_syncMaintenance_phase_repairing =>
      'Eliminazione dello stato di sincronizzazione locale';

  @override
  String get settings_troubleshootSync_repair_progressTitle =>
      'Riparazione della sincronizzazione';

  @override
  String get settings_syncMaintenance_phase_working => 'Operazione in corso...';

  @override
  String settings_syncMaintenance_progress_filesOfTotal(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done di $total file',
      one: '$done di 1 file',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_removedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file rimossi',
      one: '1 file rimosso',
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
      other: '$count file rimossi, ma $trouble. Riprova quando sei online.',
      one: '1 file rimosso, ma $trouble. Riprova quando sei online.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_trouble_failed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non sono stati eliminati',
      one: '1 non è stato eliminato',
    );
    return '$_temp0';
  }

  @override
  String get settings_syncMaintenance_trouble_listIncomplete =>
      'alcuni file non sono stati elencati';

  @override
  String settings_syncMaintenance_wipedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file cancellati',
      one: '1 file cancellato',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_wipedFilesPartial(int count, String trouble) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file cancellati, ma $trouble. Riprova quando sei online.',
      one: '1 file cancellato, ma $trouble. Riprova quando sei online.',
    );
    return '$_temp0';
  }

  @override
  String get settings_troubleshootSync_appBar_title =>
      'Risoluzione dei problemi di sincronizzazione';

  @override
  String get settings_troubleshootSync_devices_subtitle =>
      'Vedi ogni dispositivo che conserva file qui, quanto spazio occupa ciascuno, e rimuovi i residui di librerie con cui nessun dispositivo si sincronizza più. I tuoi dati delle immersioni non sono interessati.';

  @override
  String get settings_troubleshootSync_rebuild_confirm => 'Ricostruisci';

  @override
  String get settings_troubleshootSync_rebuild_confirmBody =>
      'Questa operazione rende la libreria di questo dispositivo quella attuale sul servizio e la ripubblica, in modo che gli altri dispositivi si sincronizzino da te. Usala quando una sostituzione proveniente da un altro dispositivo è bloccata. I tuoi dati delle immersioni non sono interessati.';

  @override
  String get settings_troubleshootSync_rebuild_confirmTitle =>
      'Ricostruire il servizio da questo dispositivo?';

  @override
  String get settings_troubleshootSync_rebuild_doneSnack =>
      'Servizio ricostruito da questo dispositivo';

  @override
  String get settings_troubleshootSync_rebuild_failedSnack =>
      'Ricostruzione non riuscita';

  @override
  String get settings_troubleshootSync_rebuild_progressTitle =>
      'Ricostruzione del servizio';

  @override
  String get settings_troubleshootSync_rebuild_subtitle =>
      'Usala se la sincronizzazione è bloccata in attesa di una libreria che un altro dispositivo ha sostituito ma non ha mai finito di caricare (quel dispositivo potrebbe essere offline). Pubblica la libreria di questo dispositivo come quella attuale.';

  @override
  String get settings_troubleshootSync_rebuild_title =>
      'Ricostruisci il servizio da questo dispositivo';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmBody =>
      'Questa operazione elimina dal servizio solo i file di sincronizzazione di questo dispositivo. Gli altri dispositivi continuano a sincronizzarsi e i tuoi dati delle immersioni non sono interessati.';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmTitle =>
      'Rimuovere i file cloud di questo dispositivo?';

  @override
  String get settings_troubleshootSync_removeThisDevice_progressTitle =>
      'Rimozione dei file cloud di questo dispositivo';

  @override
  String get settings_troubleshootSync_removeThisDevice_subtitle =>
      'Libera lo spazio occupato da questo dispositivo sul servizio. Gli altri dispositivi continuano a sincronizzarsi. I tuoi dati delle immersioni non sono interessati.';

  @override
  String get settings_troubleshootSync_removeThisDevice_title =>
      'Rimuovi i file cloud di questo dispositivo';

  @override
  String get settings_troubleshootSync_repair_confirm => 'Ripara';

  @override
  String get settings_troubleshootSync_repair_confirmBody =>
      'Questa operazione cancella tutto lo stato di sincronizzazione locale e assegna a questo dispositivo una nuova identità di sincronizzazione, poi alla sincronizzazione successiva si riconnette da zero. I tuoi dati delle immersioni sono al sicuro e non vengono eliminati.';

  @override
  String get settings_troubleshootSync_repair_confirmTitle =>
      'Riparare la sincronizzazione?';

  @override
  String get settings_troubleshootSync_repair_doneSnack =>
      'Sincronizzazione riparata';

  @override
  String get settings_troubleshootSync_repair_subtitle =>
      'Risolvi una sincronizzazione bloccata. Cancella lo stato di sincronizzazione di questo dispositivo e gli assegna una nuova identità di sincronizzazione, poi si riconnette alla sincronizzazione successiva. I tuoi dati delle immersioni non sono interessati.';

  @override
  String get settings_troubleshootSync_repair_title =>
      'Ripara la sincronizzazione';

  @override
  String get settings_troubleshootSync_wipeAll_confirm => 'Cancella tutto';

  @override
  String settings_troubleshootSync_wipeAll_confirmBody(String word) {
    return 'Questa operazione elimina da questo servizio i dati di sincronizzazione di OGNI dispositivo, compresi i marcatori della libreria. Ogni dispositivo dovrà ristabilire la sincronizzazione da zero. I tuoi dati delle immersioni non sono interessati.\n\nDigita $word per confermare.';
  }

  @override
  String get settings_troubleshootSync_wipeAll_confirmTitle =>
      'Cancellare tutti i dati di sincronizzazione?';

  @override
  String get settings_troubleshootSync_wipeAll_progressTitle =>
      'Cancellazione dei dati di sincronizzazione';

  @override
  String get settings_troubleshootSync_wipeAll_subtitle =>
      'Elimina da questo servizio i dati di sincronizzazione di ogni dispositivo, compresi i marcatori della libreria. Ogni dispositivo ristabilisce la sincronizzazione da zero. I tuoi dati delle immersioni non sono interessati.';

  @override
  String get settings_troubleshootSync_wipeAll_title =>
      'Cancella tutti i dati di sincronizzazione su questo servizio';

  @override
  String get tableMode_tooltip_toggleDetailPane =>
      'Mostra o nascondi il pannello dettagli';

  @override
  String get tableMode_tooltip_toggleProfilePanel =>
      'Mostra o nascondi il pannello profilo';

  @override
  String get maps_regionDownload_title => 'Scarica regione';

  @override
  String get maps_regionDownload_nameRequired =>
      'Inserisci un nome per questa regione';

  @override
  String get maps_regionDownload_nameLabel => 'Nome della regione';

  @override
  String get maps_regionDownload_nameHint => 'es. Cozumel, Messico';

  @override
  String get maps_regionDownload_zoomLevels => 'Livelli di zoom';

  @override
  String get maps_regionDownload_zoomHint =>
      'Zoom maggiore = più dettaglio, download più grande';

  @override
  String maps_regionDownload_minZoom(int zoom) {
    return 'Min: $zoom';
  }

  @override
  String maps_regionDownload_minZoomSemantics(int zoom) {
    return 'Zoom minimo: $zoom';
  }

  @override
  String maps_regionDownload_maxZoom(int zoom) {
    return 'Max: $zoom';
  }

  @override
  String maps_regionDownload_maxZoomSemantics(int zoom) {
    return 'Zoom massimo: $zoom';
  }

  @override
  String get maps_regionDownload_estimatingSemantics =>
      'Stima delle dimensioni del download';

  @override
  String maps_regionDownload_estimateSemantics(int count, Object size) {
    return 'Download stimato: $count tile, $size';
  }

  @override
  String get maps_regionDownload_estimateUnavailableSemantics =>
      'Impossibile stimare le dimensioni del download';

  @override
  String get maps_regionDownload_estimating => 'Stima in corso...';

  @override
  String maps_regionDownload_tileCount(int count) {
    return '~$count tile';
  }

  @override
  String get maps_regionDownload_estimateUnavailable => 'Impossibile stimare';

  @override
  String get maps_regionDownload_largeWarningSemantics =>
      'Attenzione: download di grandi dimensioni. Riduci i livelli di zoom o seleziona una regione più piccola.';

  @override
  String get maps_regionDownload_largeWarning =>
      'Download di grandi dimensioni. Riduci i livelli di zoom o seleziona una regione più piccola.';

  @override
  String get maps_regionDownload_downloadButton => 'Scarica';

  @override
  String get diveLog_map_title => 'Attività di immersione';

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
      'Miniatura foto. Tocca per visualizzare a schermo intero';

  @override
  String get trips_gallery_thumbnail_video =>
      'Miniatura video. Tocca per visualizzare a schermo intero';

  @override
  String get trips_gallery_thumbnail_photoMissing =>
      'Miniatura foto, assente dal dispositivo. Tocca per visualizzare a schermo intero';

  @override
  String get trips_gallery_thumbnail_videoMissing =>
      'Miniatura video, assente dal dispositivo. Tocca per visualizzare a schermo intero';

  @override
  String get trips_photos_thumbnail_photo =>
      'Miniatura foto. Tocca per aprire la galleria';

  @override
  String get trips_photos_thumbnail_video =>
      'Miniatura video. Tocca per aprire la galleria';

  @override
  String trips_picker_suggestedSemantics(Object name) {
    return 'Viaggio suggerito: $name. Tocca per usarlo';
  }

  @override
  String trips_picker_tileSemantics(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, dal $startDate al $endDate';
  }

  @override
  String trips_picker_tileSemanticsSelected(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, dal $startDate al $endDate, selezionato';
  }

  @override
  String get divePlanner_quickPlan_subtitle =>
      'Crea un semplice profilo di immersione rettangolare';

  @override
  String get divePlanner_quickPlan_depthLabel => 'Profondità:';

  @override
  String divePlanner_quickPlan_depthSemantics(Object depth) {
    return 'Profondità: $depth';
  }

  @override
  String get divePlanner_quickPlan_timeLabel => 'Tempo:';

  @override
  String divePlanner_quickPlan_bottomTimeSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Tempo di fondo: $minutes minuti',
      one: 'Tempo di fondo: 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String divePlanner_quickPlan_minutes(int minutes) {
    return '$minutes min';
  }

  @override
  String divePlanner_quickPlan_previewSemantics(Object depth, int minutes) {
    return 'Anteprima del piano: discesa a $depth, tempo di fondo $minutes minuti, risalita con sosta di sicurezza';
  }

  @override
  String get divePlanner_quickPlan_previewTitle => 'Anteprima del piano:';

  @override
  String divePlanner_quickPlan_previewDescent(Object depth) {
    return 'Discesa a $depth';
  }

  @override
  String divePlanner_quickPlan_previewBottomTime(int minutes) {
    return 'Tempo di fondo: $minutes min';
  }

  @override
  String get divePlanner_quickPlan_previewAscent =>
      'Risalita con sosta di sicurezza';

  @override
  String get divePlanner_quickPlan_create => 'Crea';

  @override
  String divePlanner_semantics_sacRate(Object value, Object volumeSymbol) {
    return 'RMV: $value $volumeSymbol al minuto';
  }

  @override
  String divePlanner_semantics_reservePressure(Object pressureSymbol) {
    return 'Pressione di riserva in $pressureSymbol';
  }

  @override
  String divePlanner_semantics_altitudeGroup(Object group) {
    return 'Gruppo altitudine: $group';
  }

  @override
  String diveSites_import_detail_maxDepth(Object depth) {
    return 'Max $depth';
  }

  @override
  String get autoUpdate_banner_download => 'Scarica';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Sincronizza tramite Apple iCloud';

  @override
  String get settings_debugLog_search_hint => 'Cerca nei log...';

  @override
  String get settings_debugLog_appBar_title => 'Log di debug';

  @override
  String get settings_debugLog_disableDebugMode =>
      'Disattiva la modalità debug';

  @override
  String get settings_debugLog_clearLogs => 'Cancella i log';

  @override
  String get settings_debugLog_empty =>
      'Nessuna voce di log corrisponde ai filtri attuali';

  @override
  String settings_debugLog_loadError(Object error) {
    return 'Errore nel caricamento dei log: $error';
  }

  @override
  String get settings_debugLog_copiedSnack =>
      'Log filtrati copiati negli appunti';

  @override
  String settings_debugLog_savedSnack(String path) {
    return 'Log salvati in $path';
  }

  @override
  String get common_action_copy => 'Copia';

  @override
  String get settings_appearance_customGradient_title =>
      'Gradiente personalizzato';

  @override
  String get settings_appearance_customGradient_start => 'Inizio';

  @override
  String get settings_appearance_customGradient_end => 'Fine';

  @override
  String get settings_appearance_customGradient_hue => 'Tonalità';

  @override
  String get settings_appearance_customGradient_saturation => 'Saturazione';

  @override
  String get settings_appearance_customGradient_brightness => 'Luminosità';

  @override
  String get settings_appearance_customGradient_preview => 'Anteprima';

  @override
  String get common_action_apply => 'Applica';

  @override
  String settings_cloudSync_message_loadStateFailed(Object error) {
    return 'Impossibile caricare lo stato di sincronizzazione: $error';
  }

  @override
  String get settings_cloudSync_message_noProviderConfigured =>
      'Nessun provider cloud configurato';

  @override
  String get settings_cloudSync_message_adopting =>
      'Adozione della libreria ripristinata...';

  @override
  String get settings_cloudSync_message_adoptFailed =>
      'Impossibile adottare la libreria ripristinata';

  @override
  String get settings_cloudSync_message_firstSyncNeedsConfirm =>
      'La prima sincronizzazione richiede conferma. Tocca «Sincronizza ora» per rivederla.';

  @override
  String get settings_cloudSync_message_startingSync =>
      'Avvio della sincronizzazione...';

  @override
  String get settings_cloudSync_message_replacePaused =>
      'Sincronizzazione in pausa: la libreria è stata sostituita da un backup. Tocca «Sincronizza ora» per rivederla.';

  @override
  String get settings_cloudSync_message_encryptedPaused =>
      'Sincronizzazione in pausa: questa libreria è criptata. Inserisci la passphrase per continuare.';

  @override
  String get settings_cloudSync_message_completedWithConflicts =>
      'Sincronizzazione completata con conflitti';

  @override
  String get settings_cloudSync_message_completedSuccessfully =>
      'Sincronizzazione completata correttamente';

  @override
  String get settings_cloudSync_message_syncFailed =>
      'Sincronizzazione non riuscita';

  @override
  String get settings_cloudSync_message_phaseDefault => 'sincronizzazione';

  @override
  String settings_cloudSync_message_syncErrorDuring(
    String phase,
    Object error,
  ) {
    return 'Errore di sincronizzazione durante $phase: $error';
  }

  @override
  String get settings_section_debug_title => 'Debug';

  @override
  String get settings_section_debug_subtitle => 'Log e diagnostica';

  @override
  String get settings_debugLog_minSeverityLabel => 'Gravità min.:';

  @override
  String get settings_debugLog_shareSubject => 'Log di debug di Submersion';

  @override
  String get settings_debugLog_saveDialogTitle => 'Salva i log di debug';

  @override
  String get universalImport_preset_saveTitle => 'Salva come preset';

  @override
  String get universalImport_preset_nameLabel => 'Nome del preset';

  @override
  String get universalImport_preset_nameHint =>
      'es. Il mio CSV del diario immersioni';

  @override
  String get universalImport_preset_nameRequired => 'Il nome è obbligatorio';

  @override
  String get universalImport_preset_sourceAppLabel => 'Applicazione di origine';

  @override
  String get universalImport_preset_sourceAppNone => 'Nessuna';

  @override
  String get universalImport_preset_entityTypesLabel => 'Tipi di entità';

  @override
  String get universalImport_preset_matchThresholdLabel =>
      'Soglia di corrispondenza';

  @override
  String get universalImport_preset_matchThresholdHelp =>
      'Quanto devono corrispondere le intestazioni CSV per il rilevamento automatico';

  @override
  String universalImport_preset_signatureHeaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count intestazioni di firma dal file corrente',
      one: '1 intestazione di firma dal file corrente',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_preset_selectTitle => 'Seleziona preset';

  @override
  String universalImport_preset_loadFailed(String error) {
    return 'Impossibile caricare i preset: $error';
  }

  @override
  String get universalImport_preset_sectionSaved => 'Preset salvati';

  @override
  String get universalImport_preset_sectionBuiltIn => 'Preset predefiniti';

  @override
  String get universalImport_preset_deleteTitle => 'Elimina preset';

  @override
  String universalImport_preset_deleteConfirm(String name) {
    return 'Eliminare «$name»? L’operazione non può essere annullata.';
  }

  @override
  String universalImport_preset_headersMatched(
    int matched,
    int total,
    int percent,
  ) {
    return '$matched/$total intestazioni corrispondenti ($percent%)';
  }

  @override
  String get universalImport_preset_noSignatureHeaders =>
      'Nessuna intestazione di firma';

  @override
  String get universalImport_preset_deleteTooltip => 'Elimina preset';

  @override
  String get universalImport_preset_presetsButton => 'Preset';

  @override
  String universalImport_preset_savedSnackbar(String name) {
    return 'Preset «$name» salvato';
  }

  @override
  String get universalImport_step_done => 'Fatto';

  @override
  String get universalImport_cancel_inProgressTitle => 'Annullamento';

  @override
  String get universalImport_cancel_inProgressBody =>
      'L’immersione in corso verrà completata prima di interrompere. Le immersioni già importate vengono mantenute.';

  @override
  String get universalImport_cancel_confirmTitle => 'Annullare l’importazione?';

  @override
  String get universalImport_cancel_confirmBody =>
      'Interrompi al termine dell’immersione in corso. Le immersioni già importate verranno mantenute.';

  @override
  String get universalImport_cancel_keepImporting => 'Continua a importare';

  @override
  String get universalImport_cancel_confirmAction => 'Annulla importazione';

  @override
  String get universalImport_cancel_discardSelections =>
      'Scartare le selezioni e annullare?';

  @override
  String get universalImport_action_importSelected => 'Importa selezionati';

  @override
  String get universalImport_action_next => 'Avanti';

  @override
  String get common_action_yes => 'Sì';

  @override
  String get common_action_no => 'No';

  @override
  String universalImport_counts_new(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuovi',
      one: '$count nuovo',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_merging(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count da consolidare',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_replacing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count da sostituire',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_skipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saltati',
      one: '$count saltato',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_counts_nothingSelected => 'Nessuna selezione';

  @override
  String get universalImport_section_potentialDuplicates =>
      'Potenziali duplicati';

  @override
  String get universalImport_section_possibleDuplicates =>
      'Possibili duplicati';

  @override
  String universalImport_count_duplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicati',
      one: '1 duplicato',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_entityAction_importBadge => 'IMPORTA';

  @override
  String get universalImport_entityAction_skipBadge => 'SALTA';

  @override
  String get universalImport_compare_existing => 'Esistente';

  @override
  String get universalImport_compare_incoming => 'In arrivo';

  @override
  String get universalImport_label_skipped => 'Saltato';

  @override
  String get universalImport_action_viewDives => 'Visualizza immersioni';

  @override
  String get diveImport_healthkit_accessGranted =>
      'Accesso a HealthKit concesso';

  @override
  String get diveImport_healthkit_accessGrantedBody =>
      'Puoi procedere al passaggio successivo.';

  @override
  String get diveImport_healthkit_requesting => 'Richiesta in corso...';

  @override
  String get diveImport_healthkit_selectDateRange =>
      'Seleziona l’intervallo di date';

  @override
  String get diveImport_healthkit_selectDateRangeBody =>
      'Scegli l’intervallo di date in cui cercare le immersioni in Apple Health.';

  @override
  String get diveImport_healthkit_fetchingDives =>
      'Recupero delle immersioni da Apple Health...';

  @override
  String get diveImport_healthkit_fetchFailed => 'Recupero non riuscito';

  @override
  String diveImport_healthkit_fetchFailedBody(String error) {
    return 'Impossibile recuperare le immersioni: $error';
  }

  @override
  String diveImport_healthkit_foundDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count immersioni trovate',
      one: '1 immersione trovata',
    );
    return '$_temp0';
  }

  @override
  String get diveImport_healthkit_proceedingToReview =>
      'Passaggio alla revisione...';

  @override
  String get importWizard_dc_knownComputer => 'Computer conosciuto';

  @override
  String importWizard_dc_knownComputerBody(String name) {
    return 'Salvato come «$name». Verranno scaricate solo le nuove immersioni.';
  }

  @override
  String get importWizard_dc_noNewDives =>
      'Nessuna nuova immersione da scaricare';

  @override
  String get importWizard_dc_noNewDivesBody =>
      'Tutte le immersioni di questo computer sono già state importate.';

  @override
  String get universalImport_compare_noDiveData =>
      'Dati di immersione non disponibili per il confronto.';

  @override
  String get universalImport_entityAction_consolidateBadge => 'CONSOLIDA';

  @override
  String get diveCenters_import_quickSearch_egypt => 'Egitto';

  @override
  String get diveCenters_import_quickSearch_mexico => 'Messico';

  @override
  String get accessibility_shortcut_switchDiver => 'Cambia subacqueo';

  @override
  String get lock_recoveryCode_title => 'Usa il codice di recupero';

  @override
  String get lock_recoveryCode_body =>
      'Inserisci il codice di recupero di 8 parole che hai salvato quando hai impostato la password dell’app.';

  @override
  String get lock_recoveryCode_error => 'Codice di recupero errato.';

  @override
  String get lock_forcedReset_title => 'Imposta una nuova password';

  @override
  String get lock_forcedReset_body =>
      'Hai sbloccato con il codice di recupero, quindi la vecchia password non è più considerata attendibile. Scegline una nuova adesso.';

  @override
  String get lock_forcedReset_submit => 'Imposta password';

  @override
  String get lock_forcedReset_error =>
      'Impossibile impostare la nuova password. Riprova.';

  @override
  String get lock_sidecarRepair_title =>
      'Ripara il file della chiave di sicurezza';

  @override
  String get lock_sidecarRepair_body =>
      'Il file della chiave di sicurezza mancava e il portachiavi di questo dispositivo contiene ancora la chiave. Conferma la password per scrivere un nuovo file della chiave. Nota: la password che inserisci qui diventa da ora in poi la password dell’app e riceverai un nuovo codice di recupero.';

  @override
  String get lock_sidecarRepair_submit => 'Ripara';

  @override
  String get lock_sidecarRepair_error => 'Riparazione non riuscita. Riprova.';

  @override
  String get lock_newRecoveryCode_title => 'Il tuo nuovo codice di recupero';

  @override
  String get lock_startFresh_title => 'Apri un altro database';

  @override
  String lock_startFresh_body(Object token) {
    return 'Il database attuale resta sul disco, rinominato con il suffisso .locked; non viene eliminato nulla. Potrai recuperarlo in seguito con la tua password o contattando l’assistenza. La sincronizzazione cloud verrà disattivata affinché il nuovo database non possa mescolarsi con quello vecchio.\n\nL’app si avvierà con un database nuovo e vuoto. Puoi ripristinare un backup nella procedura guidata di configurazione.\n\nDigita $token per confermare.';
  }

  @override
  String get lock_startFresh_confirm => 'Metti da parte e ricomincia da zero';

  @override
  String get lock_biometric_reason => 'Sblocca il tuo diario immersioni';

  @override
  String startup_migrating_progress(Object currentStep, Object totalSteps) {
    return 'Aggiornamento del database... passaggio $currentStep di $totalSteps';
  }

  @override
  String get startup_error_title => 'Submersion non è riuscito ad avviarsi';

  @override
  String get startup_error_body =>
      'Qualcosa è andato storto prima che il tuo diario di immersione fosse aperto del tutto. I tuoi dati sono ancora sul disco e non richiedono una reinstallazione. Prova a riavviare l\'app; se il problema persiste, contatta l\'assistenza.';

  @override
  String get startup_engineUnavailable_title =>
      'Questa build non può aprire un database';

  @override
  String get startup_engineUnavailable_body =>
      'In questa build manca il motore di database di Submersion, quindi il tuo diario di immersione non è mai stato aperto. Sul disco non è cambiato nulla e nessun dato è a rischio.';

  @override
  String get startup_engineUnavailable_guidance =>
      'Reinstallare o ripristinare un backup non servirà. Installa una build funzionante di Submersion e segnalaci il problema: è un difetto del pacchetto dell\'app, non dei tuoi dati.';

  @override
  String get startup_migrationFailed_title =>
      'Aggiornamento del database non riuscito';

  @override
  String get startup_migrationFailed_body =>
      'Non è stato possibile aggiornare il tuo diario di immersione al formato richiesto da questa versione. Prima dell\'aggiornamento è stata creata una copia di sicurezza, quindi non è andato perso nulla.';

  @override
  String get startup_dataUnreadable_title =>
      'Non è stato possibile leggere il tuo diario di immersione';

  @override
  String get startup_dataUnreadable_body =>
      'Il file del database c\'è, ma Submersion non riesce a leggerlo. Di solito significa che il file è danneggiato. Ripristinare un backup è il modo più rapido per ripartire.';

  @override
  String get startup_databaseBusy_title =>
      'Il tuo diario di immersione era occupato';

  @override
  String get startup_databaseBusy_body =>
      'Qualcos’altro stava ancora usando il file del database, quindi Submersion si è fermato invece di scriverci. Non è stato modificato nulla e nulla è danneggiato. Chiudi completamente Submersion, poi riaprilo.';

  @override
  String get startup_failure_technicalDetails => 'Dettagli tecnici';

  @override
  String get startup_failure_backupAvailable_title => 'È disponibile un backup';

  @override
  String startup_failure_backupAvailable_taken(Object timestamp) {
    return 'Creato il $timestamp';
  }

  @override
  String startup_failure_backupAvailable_preMigration(
    Object fromVersion,
    Object toVersion,
  ) {
    return 'Copia di sicurezza creata prima dell\'aggiornamento dallo schema v$fromVersion a v$toVersion.';
  }

  @override
  String get startup_failure_restoreAction => 'Ripristina questo backup';

  @override
  String get startup_failure_restoring =>
      'Ripristino del diario di immersione...';

  @override
  String get startup_failure_restoreFailed =>
      'Non è stato possibile ripristinare il backup. Il tuo diario di immersione è stato lasciato esattamente com\'era.';

  @override
  String get startup_failure_backupsFolder => 'I tuoi backup si trovano in:';

  @override
  String get startup_failure_showBackupsFolder => 'Mostra cartella dei backup';

  @override
  String get startup_failure_downgrade_title =>
      'Tornare alla versione precedente';

  @override
  String get startup_failure_downgrade_body =>
      'Se l\'aggiornamento continua a fallire, installa la versione di Submersion che usavi prima e ripristina la copia di sicurezza da quella versione. Ripristinarla qui rieseguirebbe soltanto lo stesso aggiornamento. Submersion non torna da solo a versioni precedenti: spostarti automaticamente su build più vecchie ti terrebbe in silenzio su versioni con problemi noti.';

  @override
  String get startup_failure_downgrade_action => 'Vedi le versioni precedenti';

  @override
  String get startup_recovering_title => 'Recupero del database...';

  @override
  String get startup_recovering_body =>
      'Annullamento della transazione interrotta. Di solito richiede pochi secondi.';

  @override
  String get startup_recoveryFailed_title =>
      'Il recupero non è stato completato';

  @override
  String get startup_recoveryFailed_body =>
      'Non è stato possibile annullare automaticamente le modifiche al database. I tuoi dati sono ancora sul disco; contatta l’assistenza prima di reinstallare, così potremo aiutarti a recuperarli.';

  @override
  String get startup_recoveryRequired_title =>
      'Il database necessita di recupero';

  @override
  String get startup_recoveryRequired_body =>
      'Una sessione precedente è stata interrotta durante la scrittura sul database. I tuoi dati sono ancora sul disco; dobbiamo solo completare l’annullamento della modifica interrotta prima che l’app possa aprirsi.';

  @override
  String startup_recovery_sqliteCode(Object code) {
    return 'Codice SQLite $code';
  }

  @override
  String get startup_recovery_action => 'Recupera database';

  @override
  String get startup_recovery_closeWithoutRecovering =>
      'Chiudi senza recuperare';

  @override
  String get common_action_tryAgain => 'Riprova';

  @override
  String get lock_screen_title => 'Submersion è bloccato';

  @override
  String get lock_screen_forgotPassword => 'Password dimenticata?';

  @override
  String get lock_incorrectPassword => 'Password errata. Riprova.';

  @override
  String get startup_backup_semanticsLabel => 'Backup in corso';

  @override
  String get startup_backup_title => 'Backup dei tuoi dati in corso';

  @override
  String get startup_backup_body =>
      'Stiamo salvando una copia del tuo diario immersioni prima di aggiornare il database.';

  @override
  String get startup_backupFailed_title =>
      'Impossibile eseguire il backup dei tuoi dati';

  @override
  String get startup_backupFailed_body =>
      'Il tuo diario immersioni non è cambiato: non lo abbiamo aggiornato. Libera spazio (o risolvi il problema) e riprova.';

  @override
  String get startup_backupFailed_quit => 'Esci';

  @override
  String get startup_backupFailed_technicalDetails => 'Dettagli tecnici';

  @override
  String get common_action_retry => 'Riprova';

  @override
  String get startup_versionMismatch_title => 'Aggiornamento necessario';

  @override
  String startup_versionMismatch_body(
    Object databaseVersion,
    Object appVersion,
  ) {
    return 'I tuoi dati di immersione sono stati salvati da una versione più recente di Submersion (schema v$databaseVersion). Questa versione supporta lo schema solo fino a v$appVersion.';
  }

  @override
  String get startup_versionMismatch_instructions =>
      'Aggiorna Submersion all’ultima versione. I tuoi dati sono al sicuro e non sono stati modificati. Se prima dell’aggiornamento è stato eseguito un backup, si trova nella cartella Backups e può essere ripristinato dopo l’aggiornamento.';

  @override
  String get startup_versionMismatch_storeInstructions =>
      'Questa app è stata installata da un app store ed è più vecchia della versione che ha creato i tuoi dati. I tuoi dati sono al sicuro e non sono stati modificati. Aggiorna Submersion quando la nuova versione appare nello store, poi riaprila.';

  @override
  String get startup_versionMismatch_download => 'Scarica l’ultima versione';

  @override
  String get startup_versionMismatch_manualLink =>
      'Se non si apre un browser, visita:';

  @override
  String get universalImport_compare_downloaded => 'Scaricata';

  @override
  String get universalImport_compare_errorLoading =>
      'Errore nel caricamento dei dati dell’immersione';

  @override
  String get universalImport_compare_diveNotFound =>
      'Immersione esistente non trovata';

  @override
  String universalImport_compare_sameFields(Object fields) {
    return 'Uguali: $fields';
  }

  @override
  String get universalImport_compare_differences => 'DIFFERENZE';

  @override
  String get universalImport_compare_notRecorded => 'non registrato';

  @override
  String universalImport_compare_serial(Object serial) {
    return 'N. serie: $serial';
  }

  @override
  String get universalImport_compare_skipSubtitle => 'Scarta questo download';

  @override
  String get universalImport_compare_importAsNewSubtitle =>
      'Salva come immersione separata';

  @override
  String get universalImport_compare_consolidateSubtitle =>
      'Aggiungi come 2ª lettura del computer';

  @override
  String get diveLog_tooltip_ndlOverMax => '>60 min';

  @override
  String diveLog_tooltip_interpolated(String value) {
    return '$value (interpolato)';
  }

  @override
  String get enum_profileMetric_ascentRate_short => 'Velocità';

  @override
  String get enum_profileMetric_cns_short => 'CNS';

  @override
  String get enum_profileMetric_otu_short => 'OTU';

  @override
  String get diveLog_profileEditor_rangeOperations =>
      'Operazioni sull’intervallo';

  @override
  String get diveLog_profileEditor_selectRangeHint =>
      'Seleziona un intervallo sul grafico per abilitare le operazioni';

  @override
  String get diveLog_profileEditor_depthPlusOneMeter => 'Prof. +1 m';

  @override
  String get diveLog_profileEditor_depthMinusOneMeter => 'Prof. -1 m';

  @override
  String get diveLog_profileEditor_timePlusFiveSeconds => 'Tempo +5 s';

  @override
  String get diveLog_profileEditor_timeMinusFiveSeconds => 'Tempo -5 s';

  @override
  String get diveLog_profileEditor_smoothing => 'Smussatura';

  @override
  String get diveLog_profileEditor_smoothLight => 'Lieve';

  @override
  String get diveLog_profileEditor_smoothMedium => 'Media';

  @override
  String get diveLog_profileEditor_smoothHeavy => 'Forte';

  @override
  String get diveLog_profileEditor_applyToAll => 'Applica a tutto';

  @override
  String get diveLog_profileEditor_applyToSelection => 'Applica alla selezione';

  @override
  String get diveLog_profileEditor_outlierDetection =>
      'Rilevamento valori anomali';

  @override
  String get diveLog_profileEditor_detect => 'Rileva';

  @override
  String get diveLog_profileEditor_removeAll => 'Rimuovi tutto';

  @override
  String diveLog_profileEditor_outliersDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count possibili valori anomali rilevati',
      one: '$count possibile valore anomalo rilevato',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_profileEditor_manualDrawing => 'Disegno manuale';

  @override
  String get diveLog_profileEditor_drawHint =>
      'Tocca il grafico per posizionare i punti di riferimento';

  @override
  String get diveLog_profileEditor_clearWaypoints => 'Cancella';

  @override
  String get diveLog_profileEditor_generateProfile => 'Genera profilo';

  @override
  String get diveLog_profileEditor_trimMode => 'Modalità ritaglio';

  @override
  String get diveLog_profileEditor_trimHint =>
      'Ritaglia le estremità del profilo';

  @override
  String get diveLog_profileEditor_trimEnd => 'Ritaglia la fine';

  @override
  String get diveLog_profileEditor_mode_smooth => 'Smussa';

  @override
  String get diveLog_profileEditor_title => 'Modifica profilo';

  @override
  String get diveLog_profileEditor_discardBody =>
      'Hai modifiche non salvate per questo profilo di immersione. Sei sicuro di volerle scartare?';

  @override
  String get diveLog_profileEditor_saveTitle => 'Salvare il profilo?';

  @override
  String get diveLog_profileEditor_saveBody =>
      'Il profilo modificato verrà salvato come profilo principale di questa immersione. Il profilo originale sarà conservato e potrà essere ripristinato in seguito.';

  @override
  String diveLog_profileEditor_saveFailed(String error) {
    return 'Salvataggio del profilo non riuscito: $error';
  }

  @override
  String diveLog_profileEditor_errorLoadingDive(String error) {
    return 'Errore nel caricamento dell’immersione: $error';
  }

  @override
  String get diveLog_profileEditor_noProfileData =>
      'Nessun dato di profilo disponibile';

  @override
  String get diveLog_profileEditor_undo => 'Annulla';

  @override
  String get diveLog_profileEditor_mode_select => 'Seleziona';

  @override
  String get diveLog_profileEditor_mode_outlier => 'Anomalo';

  @override
  String get diveLog_profileEditor_mode_draw => 'Disegna';

  @override
  String get diveLog_profileEditor_mode_trim => 'Ritaglia';

  @override
  String diveLog_sources_sectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sorgenti dati',
      one: 'Sorgente dati',
      zero: 'Sorgente dati',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_badge_manual => 'Manuale';

  @override
  String get diveLog_sources_badge_viewing => 'In visualizzazione';

  @override
  String get diveLog_sources_badge_secondary => 'Secondaria';

  @override
  String diveLog_sources_created(String date) {
    return 'Creata il $date';
  }

  @override
  String get diveLog_sources_detail_serial => 'Numero di serie';

  @override
  String get diveLog_sources_detail_format => 'Formato';

  @override
  String get diveLog_sources_detail_imported => 'Importata';

  @override
  String diveLog_detail_semantics_viewDiveComputer(String name) {
    return 'Visualizza computer subacqueo $name';
  }

  @override
  String diveLog_detail_semantics_viewTrip(String name) {
    return 'Visualizza viaggio $name';
  }

  @override
  String diveLog_detail_semantics_viewDiveCenter(String name) {
    return 'Visualizza centro immersioni $name';
  }

  @override
  String diveLog_detail_semantics_viewSpecies(String name) {
    return 'Visualizza specie $name';
  }

  @override
  String diveLog_detail_semantics_viewCourse(String name) {
    return 'Visualizza corso $name';
  }

  @override
  String diveLog_detail_serialNumber(String serial) {
    return 'N. serie $serial';
  }

  @override
  String diveLog_detail_errorLoadingSignature(String error) {
    return 'Errore nel caricamento della firma: $error';
  }

  @override
  String get diveLog_profilePanel_selectDive =>
      'Seleziona un’immersione per vederne il profilo';

  @override
  String get diveLog_profilePanel_noProfileData =>
      'Nessun dato di profilo per questa immersione';

  @override
  String get settings_export_progress_divesCsv =>
      'Esportazione delle immersioni in CSV...';

  @override
  String get settings_export_progress_sitesCsv =>
      'Esportazione dei siti in CSV...';

  @override
  String get settings_export_progress_equipmentCsv =>
      'Esportazione dell’attrezzatura in CSV...';

  @override
  String get settings_export_progress_pdf => 'Generazione del logbook PDF...';

  @override
  String get settings_export_progress_loadingSignatures =>
      'Caricamento delle firme...';

  @override
  String get settings_export_progress_loadingCertifications =>
      'Caricamento delle certificazioni...';

  @override
  String get settings_export_progress_loadingFonts =>
      'Caricamento dei caratteri...';

  @override
  String settings_export_progress_templatePdf(String template) {
    return 'Generazione del PDF $template...';
  }

  @override
  String get settings_export_progress_uddf => 'Generazione del file UDDF...';

  @override
  String get settings_export_progress_collectingData =>
      'Raccolta di tutti i dati...';

  @override
  String get settings_export_progress_excel => 'Generazione del file Excel...';

  @override
  String get settings_export_progress_buildingExcel =>
      'Creazione della cartella di lavoro Excel...';

  @override
  String get settings_export_progress_kml => 'Generazione del file KML...';

  @override
  String get settings_export_progress_buildingKml =>
      'Creazione del file KML...';

  @override
  String get settings_export_progress_preparingExcel =>
      'Preparazione del file Excel...';

  @override
  String get settings_export_progress_preparingKml =>
      'Preparazione del file KML...';

  @override
  String get settings_export_progress_chooseLocation =>
      'Scegli la posizione di salvataggio...';

  @override
  String get settings_export_progress_preparingDivesCsv =>
      'Preparazione del CSV immersioni...';

  @override
  String get settings_export_progress_preparingSitesCsv =>
      'Preparazione del CSV siti...';

  @override
  String get settings_export_progress_preparingEquipmentCsv =>
      'Preparazione del CSV attrezzatura...';

  @override
  String get settings_export_progress_preparingUddf =>
      'Preparazione del file UDDF...';

  @override
  String get settings_export_progress_preparingPdf => 'Preparazione del PDF...';

  @override
  String get settings_export_progress_selectingBackup =>
      'Selezione del file di backup...';

  @override
  String get settings_export_progress_restoringBackup =>
      'Ripristino dal backup...';

  @override
  String get settings_export_empty_dives => 'Nessuna immersione da esportare';

  @override
  String get settings_export_empty_sites => 'Nessun sito da esportare';

  @override
  String get settings_export_empty_equipment =>
      'Nessuna attrezzatura da esportare';

  @override
  String get settings_export_empty_data => 'Nessun dato da esportare';

  @override
  String get settings_export_empty_diveSites =>
      'Nessun sito di immersione da esportare';

  @override
  String settings_export_saveFailed(String error) {
    return 'Salvataggio non riuscito: $error';
  }

  @override
  String settings_export_backupFailed(String error) {
    return 'Backup non riuscito: $error';
  }

  @override
  String settings_export_restoreFailed(String error) {
    return 'Ripristino non riuscito: $error';
  }

  @override
  String get settings_export_fileUnreadable => 'Impossibile accedere al file';

  @override
  String get settings_export_notADbFile => 'Seleziona un file di backup .db';

  @override
  String get settings_export_success_dives =>
      'Immersioni esportate con successo';

  @override
  String get settings_export_success_sites => 'Siti esportati con successo';

  @override
  String get settings_export_success_equipment =>
      'Attrezzatura esportata con successo';

  @override
  String get settings_export_success_pdf => 'Logbook PDF generato con successo';

  @override
  String get settings_export_success_uddf => 'File UDDF generato con successo';

  @override
  String get settings_export_success_excel =>
      'File Excel esportato con successo';

  @override
  String settings_export_success_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'File KML esportato con successo ($count siti senza coordinate ignorati)',
      one: 'File KML esportato con successo (1 sito senza coordinate ignorato)',
      zero: 'File KML esportato con successo',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_excel => 'File Excel salvato con successo';

  @override
  String settings_export_saved_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'File KML salvato con successo ($count siti senza coordinate ignorati)',
      one: 'File KML salvato con successo (1 sito senza coordinate ignorato)',
      zero: 'File KML salvato con successo',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_divesCsv =>
      'CSV immersioni salvato con successo';

  @override
  String get settings_export_saved_sitesCsv => 'CSV siti salvato con successo';

  @override
  String get settings_export_saved_equipmentCsv =>
      'CSV attrezzatura salvato con successo';

  @override
  String get settings_export_saved_uddf => 'File UDDF salvato con successo';

  @override
  String get settings_export_saved_pdf => 'PDF salvato con successo';

  @override
  String get settings_export_saved_backup => 'Backup salvato con successo';

  @override
  String get settings_export_restoreComplete => 'Ripristino completato';

  @override
  String get settings_export_cancelled_save => 'Salvataggio annullato';

  @override
  String get settings_export_cancelled_backup => 'Backup annullato';

  @override
  String get settings_export_cancelled_restore => 'Ripristino annullato';

  @override
  String get settings_export_pdfDocumentTitle => 'Diario delle immersioni';

  @override
  String get settings_export_saveBackupDialogTitle => 'Salva backup';

  @override
  String backup_operation_created(String size) {
    return 'Backup creato: $size';
  }

  @override
  String backup_operation_backupFailed(String error) {
    return 'Backup non riuscito: $error';
  }

  @override
  String get backup_operation_restoring => 'Ripristino del backup in corso...';

  @override
  String backup_operation_restoreFailed(String error) {
    return 'Ripristino non riuscito: $error';
  }

  @override
  String get backup_operation_deleting => 'Eliminazione del backup...';

  @override
  String get backup_operation_deleted => 'Backup eliminato';

  @override
  String backup_operation_deleteFailed(String error) {
    return 'Eliminazione non riuscita: $error';
  }

  @override
  String get backup_operation_exporting => 'Esportazione del backup...';

  @override
  String backup_operation_exported(String size) {
    return 'Backup esportato: $size';
  }

  @override
  String backup_operation_exportFailed(String error) {
    return 'Esportazione non riuscita: $error';
  }

  @override
  String get backup_operation_preparingShare =>
      'Preparazione del backup per la condivisione...';

  @override
  String get backup_operation_shareReady => 'Backup pronto per la condivisione';

  @override
  String backup_operation_upgrading(int step, int total) {
    return 'Aggiornamento del database (passaggio $step di $total)...';
  }

  @override
  String backup_restore_dialog_counts(int diveCount, int siteCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount immersioni',
      one: '1 immersione',
    );
    String _temp1 = intl.Intl.pluralLogic(
      siteCount,
      locale: localeName,
      other: '$siteCount siti',
      one: '1 sito',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get backup_restore_preMigration_title =>
      'Ripristina il backup pre-migrazione';

  @override
  String get backup_restore_preMigration_unknownVersion =>
      'versione sconosciuta';

  @override
  String get backup_restore_preMigration_restoreAnyway => 'Ripristina comunque';

  @override
  String backup_restore_preMigration_incompleteMetadata(
    String timestamp,
    String appVersion,
  ) {
    return 'Questo backup è stato creato il $timestamp dall’app $appVersion, ma i suoi metadati di migrazione del database sono incompleti.\n\nL’app non può verificare se il ripristino di questo backup sia sicuro, quindi il ripristino è disattivato.';
  }

  @override
  String backup_restore_preMigration_newerApp(
    String timestamp,
    String appVersion,
    int fromVersion,
  ) {
    return 'Questo backup è più recente della tua app. Installa una versione più recente dell’app per ripristinarlo.\n\nBackup creato il $timestamp dall’app $appVersion (database v$fromVersion).';
  }

  @override
  String backup_restore_preMigration_safe(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
  ) {
    return 'Questo backup è stato creato il $timestamp dall’app $appVersion, poco prima dell’aggiornamento del database da v$fromVersion a v$toVersion.\n\nLo schema del database della tua app corrisponde a questo backup, quindi il ripristino è sicuro.';
  }

  @override
  String backup_restore_preMigration_warning(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
    int currentVersion,
  ) {
    return 'Questo backup è stato creato il $timestamp dall’app $appVersion, poco prima dell’aggiornamento del database da v$fromVersion a v$toVersion.\n\nStai usando un’app più recente (database v$currentVersion).\n\nRipristinando ora, l’aggiornamento del database da v$fromVersion a v$toVersion verrà eseguito di nuovo sui dati ripristinati, cioè lo stesso aggiornamento che stava per essere eseguito in origine. Se è stato quell’aggiornamento a causare il problema, lo incontrerai di nuovo.\n\nPer ripristinare in sicurezza: installa l’app $appVersion o una precedente, poi ripristina questo backup da quell’app più vecchia.';
  }

  @override
  String get settings_cloudSync_progress_preparing =>
      'Preparazione della sincronizzazione...';

  @override
  String get settings_cloudSync_progress_pulling =>
      'Recupero delle modifiche...';

  @override
  String get settings_cloudSync_progress_publishing =>
      'Pubblicazione delle modifiche...';

  @override
  String settings_cloudSync_progress_uploadingLibrary(int uploaded, int total) {
    return 'Caricamento della libreria ($uploaded di $total)';
  }

  @override
  String get settings_cloudSync_result_noProvider =>
      'Nessun provider cloud configurato';

  @override
  String get settings_cloudSync_result_notAuthenticated =>
      'Non autenticato con il provider cloud';

  @override
  String get settings_cloudSync_result_timedOut =>
      'Sincronizzazione scaduta per timeout';

  @override
  String get settings_cloudSync_result_epochMarkerUnreadable =>
      'Impossibile leggere il marcatore di epoca della libreria';

  @override
  String get settings_cloudSync_result_epochMarkerEncrypted =>
      'Il marcatore di epoca della libreria è crittografato';

  @override
  String get settings_cloudSync_result_libraryReplacedRemotely =>
      'La libreria cloud è stata sostituita da un backup';

  @override
  String get settings_cloudSync_result_noReplacementToRebuild =>
      'Nessuna sostituzione della libreria da cui ricostruire';

  @override
  String get settings_cloudSync_result_rebuiltFromThisDevice =>
      'Questo servizio è stato ricostruito dalla libreria di questo dispositivo';

  @override
  String settings_cloudSync_result_rebuildFailed(String error) {
    return 'Ricostruzione non riuscita: $error';
  }

  @override
  String get settings_cloudSync_result_libraryReplaced => 'Libreria sostituita';

  @override
  String settings_cloudSync_result_libraryReplaceFailed(String error) {
    return 'Sostituzione della libreria non riuscita: $error';
  }

  @override
  String get settings_cloudSync_result_noReplacementMarker =>
      'Nessun marcatore di sostituzione della libreria trovato';

  @override
  String get settings_cloudSync_result_adoptedRestoredLibrary =>
      'Libreria ripristinata adottata';

  @override
  String settings_cloudSync_result_adoptFailed(String error) {
    return 'Impossibile adottare la libreria ripristinata: $error';
  }

  @override
  String get settings_cloudSync_result_previousLibraryUnreadable =>
      'Non è stato possibile leggere la libreria precedente; questo servizio è stato ristabilito dalla libreria di questo dispositivo.';

  @override
  String get settings_cloudSync_result_replacementStillUploading =>
      'La libreria sostituita è ancora in fase di caricamento. Riprova tra poco.';

  @override
  String settings_cloudSync_result_recordsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count record non sono stati applicati',
      one: '1 record non è stato applicato',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_result_adoptedFreshIdentity =>
      'Un altro dispositivo si stava sincronizzando con l’identità di questo dispositivo. Questo dispositivo ha adottato una nuova identità e ha unito i dati del cloud.';

  @override
  String settings_cloudSync_launchCheck_unavailable(String provider) {
    return '$provider non è disponibile su questo dispositivo';
  }

  @override
  String settings_cloudSync_launchCheck_notSignedIn(String provider) {
    return 'Accesso a $provider non effettuato';
  }

  @override
  String settings_cloudSync_launchCheck_localChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifiche locali da caricare',
      one: '1 modifica locale da caricare',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_launchCheck_noRemoteData =>
      'Nessun dato di sincronizzazione trovato nel cloud';

  @override
  String get settings_cloudSync_launchCheck_cloudDataAvailable =>
      'Dati cloud disponibili';

  @override
  String get settings_cloudSync_launchCheck_updatesAvailable =>
      'Aggiornamenti disponibili dal cloud';

  @override
  String get settings_cloudSync_launchCheck_upToDate => 'È tutto aggiornato';

  @override
  String settings_cloudSync_launchCheck_failed(String error) {
    return 'Controllo della sincronizzazione non riuscito: $error';
  }

  @override
  String get diveLog_detail_viewMap => 'Mappa';

  @override
  String get diveLog_detail_view3d => '3D';

  @override
  String get setup_sync_icloudUnavailable =>
      'iCloud non è disponibile su questo dispositivo';

  @override
  String get media_info_title => 'Info media';

  @override
  String get media_info_fileSection => 'File';

  @override
  String get media_info_filename => 'Nome file';

  @override
  String get media_info_type => 'Tipo';

  @override
  String get media_info_dimensions => 'Dimensioni';

  @override
  String get media_info_size => 'Dimensione';

  @override
  String get media_info_taken => 'Scattata';

  @override
  String get media_info_coordinates => 'Coordinate';

  @override
  String get media_info_unknown => 'Sconosciuto';

  @override
  String get media_info_originSection => 'Origine';

  @override
  String get media_info_source => 'Sorgente';

  @override
  String get media_info_reference => 'Riferimento';

  @override
  String get media_info_linkedOn => 'Collegata su';

  @override
  String get media_info_thisDevice => 'Questo dispositivo';

  @override
  String get media_info_otherDevice => 'Un altro dispositivo';

  @override
  String get media_info_status => 'Stato';

  @override
  String get media_info_statusFound => 'Trovata su questo dispositivo';

  @override
  String get media_info_statusMissing => 'Assente da questo dispositivo';

  @override
  String get media_info_statusUnchecked => 'Non ancora verificata';

  @override
  String media_info_lastChecked(String date) {
    return 'Ultimo controllo $date';
  }

  @override
  String get media_timeInDive_label => 'Momento dell\'immersione';

  @override
  String get media_timeInDive_unknown => 'Momento dell\'immersione sconosciuto';

  @override
  String get media_timeInDive_setAction =>
      'Imposta il momento dell\'immersione';

  @override
  String media_timeInDive_manual(String time) {
    return '$time (impostato manualmente)';
  }

  @override
  String get media_timeInDive_fieldLabel =>
      'Tempo dall\'inizio dell\'immersione';

  @override
  String get media_timeInDive_fieldHint => 'mm:ss';

  @override
  String media_timeInDive_range(String max) {
    return 'Tra 0:00 e $max';
  }

  @override
  String media_timeInDive_invalid(String max) {
    return 'Inserisci un tempo tra 0:00 e $max';
  }

  @override
  String get media_timeInDive_save => 'Salva';

  @override
  String get media_timeInDive_cancel => 'Annulla';

  @override
  String get media_timeInDive_reset => 'Ripristina automatico';

  @override
  String get media_info_backupSection => 'Backup';

  @override
  String get media_info_store => 'Archivio cloud';

  @override
  String get media_info_storeNotConnected => 'Nessun archivio cloud collegato';

  @override
  String get media_info_notEligible =>
      'Questa sorgente non può essere sottoposta a backup';

  @override
  String get media_info_backupFull => 'Originale caricato';

  @override
  String get media_info_backupThumbOnly =>
      'Solo miniatura, originale non inviato';

  @override
  String get media_info_backupRenditionOnly => 'Versione compressa caricata';

  @override
  String get media_info_backupNone => 'Nessun backup';

  @override
  String media_info_uploadedOn(String date) {
    return 'Caricata $date';
  }

  @override
  String get media_info_queuePending => 'In attesa di caricamento';

  @override
  String get media_info_queueTransferring => 'Caricamento in corso';

  @override
  String media_info_queueFailed(Object error) {
    return 'Caricamento non riuscito: $error';
  }

  @override
  String get media_info_servingSection => 'In uso ora';

  @override
  String get media_info_servingUnobserved => 'Non ancora caricata';

  @override
  String get media_info_servingFailed => 'Impossibile caricare';

  @override
  String get media_info_servedLocalDisk => 'File locale su questo dispositivo';

  @override
  String get media_info_servedGallery => 'Libreria foto';

  @override
  String get media_info_servedStoreCache =>
      'Cache locale, dall\'archivio cloud';

  @override
  String get media_info_servedStoreNetwork => 'Scaricata dall\'archivio cloud';

  @override
  String get media_info_servedNetworkUrl => 'Streaming da un URL';

  @override
  String get media_info_servedConnectorCache =>
      'Cache locale, dal servizio collegato';

  @override
  String get media_info_servedConnectorNetwork =>
      'Scaricata dal servizio collegato';

  @override
  String get media_info_servedEmbedded => 'Salvata in questo diario';

  @override
  String get media_info_servingFallbackNote =>
      'La sorgente originale non era raggiungibile, quindi ha risposto l\'archivio cloud.';

  @override
  String get media_info_servingTierThumbnail => 'Miniatura';

  @override
  String get media_info_servingTierRendition => 'Versione compressa';

  @override
  String get media_info_typePhoto => 'Foto';

  @override
  String get media_info_typeVideo => 'Video';

  @override
  String get media_info_typeDocument => 'Documento';

  @override
  String get media_info_typeSignature => 'Firma';

  @override
  String get media_info_actionCheckNow => 'Verifica ora';

  @override
  String get media_info_actionLocate => 'Trova file...';

  @override
  String get media_info_actionBackUpNow => 'Esegui backup ora';

  @override
  String get media_info_actionRetryUpload => 'Riprova caricamento';

  @override
  String get media_info_actionReveal => 'Mostra nel gestore file';

  @override
  String get media_info_actionCopyPath => 'Copia riferimento';

  @override
  String get media_info_referenceCopied => 'Riferimento copiato';

  @override
  String get media_info_checkFound => 'Sorgente trovata';

  @override
  String get media_info_checkMissing => 'Sorgente mancante';

  @override
  String get media_info_checkUnavailable => 'Impossibile verificare ora';

  @override
  String get media_info_backupQueued => 'In coda per il caricamento';

  @override
  String get enum_profileMetric_o2CellMv => 'Celle O2';

  @override
  String get enum_profileMetric_o2CellMv_short => 'Celle';

  @override
  String get diveLog_o2CellSpread_label => 'Dispersione delle celle O2';

  @override
  String get media_status_broken => 'Mancante e senza backup';

  @override
  String get media_servedFrom_localDisk => 'Su questo dispositivo';

  @override
  String get media_servedFrom_platformGallery => 'Libreria foto';

  @override
  String get media_servedFrom_storeCache => 'Archivio cloud, in cache qui';

  @override
  String get media_servedFrom_storeNetwork => 'Archivio cloud';

  @override
  String get media_servedFrom_networkUrl => 'Link web';

  @override
  String get media_servedFrom_connectorCache =>
      'Servizio collegato, in cache qui';

  @override
  String get media_servedFrom_connectorNetwork => 'Servizio collegato';

  @override
  String get media_servedFrom_embedded => 'Salvato in questo diario';

  @override
  String get settings_media_provenanceBadges =>
      'Mostra i badge di origine sulle miniature';

  @override
  String get settings_media_provenanceBadgesSubtitle =>
      'Una piccola icona che indica da dove proviene ogni elemento. I badge di problema sono sempre visibili.';

  @override
  String get media_status_transferFailed => 'Caricamento non riuscito';

  @override
  String get media_status_transferring => 'Caricamento in corso';

  @override
  String get media_status_queued => 'In attesa di caricamento';

  @override
  String get media_status_cloudOnly => 'Salvato solo nel cloud';

  @override
  String get media_status_notBackedUp => 'Nessun backup';

  @override
  String get media_tile_infoMenuItem => 'Info media';

  @override
  String get diveImport_healthkit_accessGrantedHint =>
      'Apple Salute non comunica mai alle app se l\'accesso in lettura è stato concesso. Se non compare nessuna immersione, apri Salute, poi Condivisione, App, Submersion, e attiva Allenamenti, Profondità subacquea, Temperatura dell\'acqua e Frequenza cardiaca.';

  @override
  String get diveImport_healthkit_foundNoDivesHint =>
      'Nessun allenamento di immersione in questo intervallo. Verifica che le date coprano l\'immersione e che in Salute, Condivisione, App, Submersion siano attivi Allenamenti e Profondità subacquea.';

  @override
  String get settings_dataSources_appleHealth_dataTypeDepth =>
      'Profondità subacquea - campioni di profondità registrati durante le immersioni';

  @override
  String get settings_dataSources_appleHealth_dataTypeWaterTemp =>
      'Temperatura dell\'acqua - campioni di temperatura registrati durante le immersioni';

  @override
  String get settings_dataSources_appleHealth_permissionManagedInHealth =>
      'L\'accesso a HealthKit si gestisce nell\'app Salute';

  @override
  String get settings_dataSources_appleHealth_permissionUnsupported =>
      'HealthKit non è disponibile su questo dispositivo';
}
