// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

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
  String get buddies_action_add => 'Aggiungi Compagno';

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
  String get buddies_picker_addNew => 'Aggiungi Nuovo Compagno';

  @override
  String get buddies_picker_done => 'Fatto';

  @override
  String get buddies_picker_noBuddiesFound => 'Nessun compagno trovato';

  @override
  String get buddies_picker_noBuddiesYet => 'Nessun compagno ancora';

  @override
  String get buddies_picker_noneSelected => 'Nessun compagno selezionato';

  @override
  String get buddies_picker_searchHint => 'Cerca compagni...';

  @override
  String get buddies_picker_selectBuddies => 'Seleziona Compagni';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Seleziona Ruolo per $name';
  }

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
  String get certifications_detail_label_expiryDate => 'Data di scadenza';

  @override
  String get certifications_detail_label_instructorName => 'Nome';

  @override
  String get certifications_detail_label_instructorNumber => 'N. istruttore';

  @override
  String get certifications_detail_label_issueDate => 'Data di rilascio';

  @override
  String get certifications_detail_label_level => 'Livello';

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
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Certificato da $agency';
  }

  @override
  String get certifications_ecard_label_instructor => 'ISTRUTTORE';

  @override
  String get certifications_ecard_label_issued => 'RILASCIATO';

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
  String get certifications_edit_help_expiryDate =>
      'Lascia vuoto per certificazioni senza scadenza';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Inserisci il numero della tessera di certificazione';

  @override
  String get certifications_edit_hint_certificationName =>
      'es. Open Water Diver';

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
  String get certifications_edit_label_certificationName =>
      'Nome certificazione *';

  @override
  String get certifications_edit_label_expiryDate => 'Data di scadenza';

  @override
  String get certifications_edit_label_instructorName => 'Nome istruttore';

  @override
  String get certifications_edit_label_instructorNumber => 'Numero istruttore';

  @override
  String get certifications_edit_label_issueDate => 'Data di rilascio';

  @override
  String get certifications_edit_label_level => 'Livello';

  @override
  String get certifications_edit_label_notes => 'Note';

  @override
  String get certifications_edit_level_notSpecified => 'Non specificato';

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
  String get certifications_edit_validation_nameRequired =>
      'Inserisci un nome per la certificazione';

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
  String certifications_walletCard_countPlural(Object count) {
    return '$count certificazioni';
  }

  @override
  String certifications_walletCard_countSingular(Object count) {
    return '$count certificazione';
  }

  @override
  String get certifications_walletCard_emptyFooter =>
      'Aggiungi la tua prima certificazione';

  @override
  String get certifications_walletCard_error =>
      'Impossibile caricare le certificazioni';

  @override
  String get certifications_walletCard_semanticLabel =>
      'Portafoglio certificazioni. Tocca per visualizzare tutte le certificazioni';

  @override
  String get certifications_walletCard_tapToAdd => 'Tocca per aggiungere';

  @override
  String get certifications_walletCard_title => 'Portafoglio certificazioni';

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
  String get common_action_back => 'Indietro';

  @override
  String get common_action_cancel => 'Annulla';

  @override
  String get common_action_close => 'Chiudi';

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
  String get common_label_error => 'Errore';

  @override
  String get common_label_loading => 'Caricamento';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get courses_action_add => 'Aggiungi Corso';

  @override
  String get courses_action_create => 'Crea Corso';

  @override
  String get courses_action_edit => 'Modifica corso';

  @override
  String get courses_action_exportTrainingLog =>
      'Esporta Registro Addestramento';

  @override
  String get courses_action_markCompleted => 'Segna come Completato';

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
  String get courses_field_selectFromBuddies =>
      'Seleziona dai Compagni (Facoltativo)';

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
  String get courses_label_none => '-- Nessuno --';

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
  String get courses_section_details => 'Dettagli Corso';

  @override
  String get courses_section_earnedCertification => 'Certificazione Ottenuta';

  @override
  String get courses_section_instructor => 'Istruttore';

  @override
  String get courses_section_notes => 'Note';

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
  String get diveCenters_summary_topRated => 'Più Votati';

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
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_tts => 'TTS';

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
  String get diveLog_deco_title => 'Stato decompressione';

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
  String get diveLog_detail_button_rangeAnalysis => 'Analisi intervallo';

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
  String get diveLog_detail_fullscreen_sampleData => 'Dati Campione';

  @override
  String get diveLog_detail_fullscreen_tapChartCompact =>
      'Tocca il grafico per vista compatta';

  @override
  String get diveLog_detail_fullscreen_tapChartFull =>
      'Tocca il grafico per vista a schermo intero';

  @override
  String get diveLog_detail_fullscreen_touchChart =>
      'Tocca il grafico per vedere i dati in quel punto';

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
  String get diveLog_detail_section_decoStatus => 'Stato decompressione';

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
  String get diveLog_detail_section_sacByCylinder => 'SAC per bombola';

  @override
  String get diveLog_detail_section_sacRateBySegment =>
      'Consumo SAC per segmento';

  @override
  String get diveLog_detail_section_tags => 'Tag';

  @override
  String get diveLog_detail_section_tanks => 'Bombole';

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
  String diveLog_detail_tankCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bombole',
      one: 'bombola',
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
  String get diveLog_edit_headerNew => 'Registra nuova immersione';

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
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Tempo di fondo calcolato: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Errore nel salvataggio dell\'immersione: $error';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'Nessun dato del profilo immersione disponibile';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Impossibile calcolare il tempo di fondo dal profilo';

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
  String get diveLog_filter_noTagsYet => 'Nessun tag creato';

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
  String get diveLog_filter_showOnlyFavorites =>
      'Mostra solo le immersioni preferite';

  @override
  String get diveLog_filter_startDate => 'Data di inizio';

  @override
  String get diveLog_filter_title => 'Filtra immersioni';

  @override
  String get diveLog_filter_tooltip_close => 'Chiudi filtro';

  @override
  String get diveLog_fullscreenProfile_close => 'Chiudi schermo intero';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Profilo immersione #$number';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Velocita di risalita';

  @override
  String get diveLog_legend_label_ceiling => 'Ceiling';

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
  String get diveLog_legend_label_surfaceGf => 'GF superficie';

  @override
  String get diveLog_legend_label_temp => 'Temp';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Mappa immersioni';

  @override
  String get diveLog_listPage_compactTitle => 'Immersioni';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Errore: $error';
  }

  @override
  String get diveLog_listPage_fab_logDive => 'Registra immersione';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Ricerca avanzata';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Numerazione immersioni';

  @override
  String get diveLog_listPage_searchFieldLabel => 'Cerca immersioni...';

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
  String get diveLog_profileSelector_badge_primary => 'Primario';

  @override
  String get diveLog_profileSelector_label_diveComputers =>
      'Computer subacquei';

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
  String get diveLog_rangeStats_header_avg => 'Media';

  @override
  String get diveLog_rangeStats_header_max => 'Max';

  @override
  String get diveLog_rangeStats_header_min => 'Min';

  @override
  String get diveLog_rangeStats_label_depth => 'Profondita';

  @override
  String get diveLog_rangeStats_label_heartRate => 'Frequenza cardiaca';

  @override
  String get diveLog_rangeStats_label_pressure => 'Pressione';

  @override
  String get diveLog_rangeStats_label_temp => 'Temp';

  @override
  String get diveLog_rangeStats_title => 'Analisi intervallo';

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
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

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
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Miscela gas';

  @override
  String get diveLog_tank_selectPreset => 'Seleziona preset...';

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
  String get diveLog_tooltip_ceiling => 'Ceiling';

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
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Tempo';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get divePlanner_action_addTank => 'Aggiungi Bombola';

  @override
  String get divePlanner_action_convertToDive => 'Converti in Immersione';

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
  String get divePlanner_label_runtime => 'Tempo Totale';

  @override
  String get divePlanner_label_sacRate => 'Velocità SAC:';

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
  String get diveSites_edit_appBar_newSite => 'Nuovo sito';

  @override
  String get diveSites_edit_appBar_save => 'Salva';

  @override
  String get diveSites_edit_button_addSite => 'Aggiungi sito';

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
  String get diveSites_edit_gps_gettingLocation => 'Acquisizione...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Scegli un metodo di localizzazione - le coordinate compileranno automaticamente paese e regione';

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
    return '$min-${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Fino a ${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '${min}m+';
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
    return 'Sei sicuro di voler eliminare $name? Tutti i registri immersione associati saranno disassociati.';
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
  String get enum_buddyRole_buddy => 'Compagno';

  @override
  String get enum_buddyRole_diveGuide => 'Guida subacquea';

  @override
  String get enum_buddyRole_diveMaster => 'Divemaster';

  @override
  String get enum_buddyRole_instructor => 'Istruttore';

  @override
  String get enum_buddyRole_solo => 'Solitario';

  @override
  String get enum_buddyRole_student => 'Allievo';

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
  String get enum_profileEvent_descentEnd => 'Fine discesa';

  @override
  String get enum_profileEvent_descentStart => 'Inizio discesa';

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
  String get equipment_addSheet_brandHint => 'es. Scubapro';

  @override
  String get equipment_addSheet_brandLabel => 'Marca';

  @override
  String get equipment_addSheet_closeTooltip => 'Chiudi';

  @override
  String get equipment_addSheet_currencyLabel => 'Valuta';

  @override
  String get equipment_addSheet_dateLabel => 'Data';

  @override
  String equipment_addSheet_errorSnackbar(Object error) {
    return 'Errore nell\'aggiunta dell\'attrezzatura: $error';
  }

  @override
  String get equipment_addSheet_modelHint => 'es. MK25 EVO';

  @override
  String get equipment_addSheet_modelLabel => 'Modello';

  @override
  String get equipment_addSheet_nameHint => 'es. Il mio erogatore principale';

  @override
  String get equipment_addSheet_nameLabel => 'Nome';

  @override
  String get equipment_addSheet_nameValidation => 'Inserisci un nome';

  @override
  String get equipment_addSheet_notesHint => 'Note aggiuntive...';

  @override
  String get equipment_addSheet_notesLabel => 'Note';

  @override
  String get equipment_addSheet_priceLabel => 'Prezzo';

  @override
  String get equipment_addSheet_purchaseInfoTitle => 'Informazioni acquisto';

  @override
  String get equipment_addSheet_serialNumberLabel => 'Numero di serie';

  @override
  String get equipment_addSheet_serviceIntervalHint => 'es. 365 per annuale';

  @override
  String get equipment_addSheet_serviceIntervalLabel =>
      'Intervallo manutenzione (giorni)';

  @override
  String get equipment_addSheet_sizeHint => 'es. M, L, 42';

  @override
  String get equipment_addSheet_sizeLabel => 'Taglia';

  @override
  String get equipment_addSheet_submitButton => 'Aggiungi attrezzatura';

  @override
  String get equipment_addSheet_successSnackbar =>
      'Attrezzatura aggiunta con successo';

  @override
  String get equipment_addSheet_title => 'Aggiungi attrezzatura';

  @override
  String get equipment_addSheet_typeLabel => 'Tipo';

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
  String get gasCalculators_ppO2Limit => 'Limite ppO₂';

  @override
  String get gasCalculators_resetAll => 'Ripristina tutti i calcolatori';

  @override
  String get gasCalculators_sacRate => 'Velocità SAC';

  @override
  String get gasCalculators_tab_bestMix => 'Miscela Migliore';

  @override
  String get gasCalculators_tab_consumption => 'Consumo';

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
  String get media_diveMediaSection_emptyState => 'Nessuna foto ancora';

  @override
  String get media_diveMediaSection_errorLoading =>
      'Errore nel caricamento dei media';

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Visualizza foto. Premi a lungo per scollegare';

  @override
  String get media_diveMediaSection_title => 'Foto e video';

  @override
  String get media_diveMediaSection_unlinkButton => 'Scollega';

  @override
  String get media_diveMediaSection_unlinkDialogContent =>
      'Rimuovere questa foto dall\'immersione? La foto rimarrà nella tua galleria.';

  @override
  String get media_diveMediaSection_unlinkDialogTitle => 'Scollega foto';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Scollegamento non riuscito: $error';
  }

  @override
  String get media_diveMediaSection_unlinkSuccess => 'Foto scollegata';

  @override
  String get media_gpsBanner_addToSiteButton => 'Aggiungi al sito';

  @override
  String media_gpsBanner_coordinates(Object latitude, Object longitude) {
    return 'Coordinate: $latitude, $longitude';
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
  String media_import_importedAndFailed(Object imported, Object failed) {
    return 'Importate $imported, non riuscite $failed';
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
  String get media_miniProfile_headerLabel => 'Profilo immersione';

  @override
  String get media_miniProfile_semanticLabel =>
      'Grafico mini profilo immersione';

  @override
  String get media_photoPicker_appBarTitle => 'Seleziona foto';

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
  String get media_photoPicker_grantAccessButton => 'Concedi accesso';

  @override
  String get media_photoPicker_openSettingsButton => 'Apri Impostazioni';

  @override
  String get media_photoPicker_openSettingsSnackbar =>
      'Apri Impostazioni e abilita l\'accesso alle foto';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'L\'accesso alla libreria foto è stato negato. Abilitalo nelle Impostazioni per aggiungere foto delle immersioni.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion ha bisogno dell\'accesso alla tua libreria foto per aggiungere foto delle immersioni.';

  @override
  String get media_photoPicker_permissionTitle => 'Accesso alle foto richiesto';

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
  String get media_photoViewer_noPhotosAvailable => 'Nessuna foto disponibile';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel =>
      'Riproduci o metti in pausa il video';

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
  String get nav_home => 'Home';

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
  String get onboarding_welcome_createProfile => 'Crea il Tuo Profilo';

  @override
  String get onboarding_welcome_createProfileSubtitle =>
      'Inserisci il tuo nome per iniziare. Potrai aggiungere altri dettagli in seguito.';

  @override
  String get onboarding_welcome_creating => 'Creazione...';

  @override
  String onboarding_welcome_errorCreatingProfile(Object error) {
    return 'Errore durante la creazione del profilo: $error';
  }

  @override
  String get onboarding_welcome_getStarted => 'Inizia';

  @override
  String get onboarding_welcome_nameHint => 'Inserisci il tuo nome';

  @override
  String get onboarding_welcome_nameLabel => 'Il Tuo Nome';

  @override
  String get onboarding_welcome_nameValidation => 'Inserisci il tuo nome';

  @override
  String get onboarding_welcome_subtitle =>
      'Registrazione e analisi avanzata delle immersioni';

  @override
  String get onboarding_welcome_title => 'Benvenuto in Submersion';

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
  String get settings_about_reportIssue_snackbar =>
      'Visita github.com/submersion/submersion';

  @override
  String get settings_about_version => 'Versione 0.1.0';

  @override
  String get settings_appBar_title => 'Impostazioni';

  @override
  String get settings_appearance_appLanguage => 'Lingua dell\'app';

  @override
  String get settings_appearance_depthColoredCards =>
      'Schede immersione colorate per profondità';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Mostra le schede immersione con sfondi colorati come l\'oceano in base alla profondità';

  @override
  String get settings_appearance_gasSwitchMarkers => 'Marcatori cambio gas';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'Mostra i marcatori per i cambi gas';

  @override
  String get settings_appearance_header_diveLog => 'Registro immersioni';

  @override
  String get settings_appearance_header_diveProfile => 'Profilo immersione';

  @override
  String get settings_appearance_header_diveSites => 'Siti di immersione';

  @override
  String get settings_appearance_header_language => 'Lingua';

  @override
  String get settings_appearance_header_theme => 'Tema';

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
  String get settings_appearance_pressureThresholdMarkers =>
      'Marcatori soglia pressione';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Mostra i marcatori quando la pressione della bombola supera le soglie';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Mostra i marcatori quando la pressione della bombola supera le soglie di 2/3, 1/2 e 1/3';

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
  String get settings_backToSettings_tooltip => 'Torna alle impostazioni';

  @override
  String get settings_cloudSync_appBar_title => 'Sincronizzazione cloud';

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
  String get settings_cloudSync_header_advanced => 'Avanzate';

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
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Sincronizza tramite Google Drive';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Sincronizza tramite Apple iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Inizializzazione del provider $providerName non riuscita';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Non disponibile su questa piattaforma';

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
  String get settings_data_backup => 'Backup';

  @override
  String get settings_data_backup_subtitle => 'Crea un backup dei tuoi dati';

  @override
  String get settings_data_cloudSync => 'Sincronizzazione cloud';

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
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Seleziona preset di conservatismo $presetName';
  }

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
  String get settings_manage_tankPresets => 'Preset bombole';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Gestisci configurazioni bombole personalizzate';

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
  String get settings_notifications_disabled_enableButton => 'Abilita';

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
  String surfaceInterval_heSemantics(Object percent) {
    return 'Elio: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Intervallo Corrente';

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
  String get surfaceInterval_secondDive_gasAir => '(Aria)';

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
  String get tags_hint_addTags => 'Aggiungi tag...';

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
      'Importa immersioni registrate su Apple Watch Ultra';

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
  String get transfer_import_autoDetectSemanticLabel =>
      'Importa dati con rilevamento automatico';

  @override
  String get transfer_import_autoDetectSubtitle =>
      'Rileva automaticamente CSV, UDDF, FIT e altro';

  @override
  String get transfer_import_autoDetectTitle => 'Importa dati';

  @override
  String get transfer_import_byFormatHeader => 'Importa per formato';

  @override
  String get transfer_import_csvSubtitle => 'Importa immersioni da file CSV';

  @override
  String get transfer_import_csvTitle => 'Importa da CSV';

  @override
  String get transfer_import_fitSubtitle =>
      'Importa immersioni da file di esportazione Garmin Descent';

  @override
  String get transfer_import_fitTitle => 'Importa da file FIT';

  @override
  String get transfer_import_operationCompleted => 'Operazione completata';

  @override
  String transfer_import_operationFailed(Object error) {
    return 'Operazione non riuscita: $error';
  }

  @override
  String get transfer_import_sectionHeader => 'Importa dati';

  @override
  String get transfer_import_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_import_uddfTitle => 'Importa da UDDF';

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
  String get trips_detail_stat_totalBottomTime => 'Tempo di fondo totale';

  @override
  String get trips_detail_stat_totalDives => 'Immersioni totali';

  @override
  String get trips_detail_tooltip_edit => 'Modifica viaggio';

  @override
  String get trips_detail_tooltip_editShort => 'Modifica';

  @override
  String get trips_detail_tooltip_moreOptions => 'Altre opzioni';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Visualizza sulla mappa';

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
  String get universalImport_action_selectFile => 'Seleziona File';

  @override
  String get universalImport_description_supportedFormats =>
      'Seleziona un file di registro immersioni da importare. I formati supportati includono CSV, UDDF, Subsurface XML e Garmin FIT.';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Questo formato non è ancora supportato. Esporta come UDDF o CSV.';

  @override
  String get universalImport_hint_tagDescription =>
      'Tagga tutte le immersioni importate per un filtraggio facile';

  @override
  String get universalImport_hint_tagExample =>
      'es., Importazione MacDive 2026-02-09';

  @override
  String get universalImport_label_columnMapping => 'Mappatura Colonne';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped di $total colonne mappate';
  }

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
  String get universalImport_label_importComplete => 'Importazione Completata';

  @override
  String get universalImport_label_importTag => 'Tag Importazione';

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
  String get universalImport_step_import => 'Importa';

  @override
  String get universalImport_step_map => 'Mappa';

  @override
  String get universalImport_step_review => 'Rivedi';

  @override
  String get universalImport_step_select => 'Seleziona';

  @override
  String get universalImport_title => 'Importa Dati';

  @override
  String get universalImport_tooltip_clearTag => 'Cancella tag';

  @override
  String get universalImport_tooltip_closeWizard =>
      'Chiudi procedura guidata importazione';

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
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... e altre $count';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Annulla';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadFailed => 'Download fallito';

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
  String get diveComputer_download_newDivesImported =>
      'Nuove immersioni importate';

  @override
  String get diveComputer_download_preparing => 'Preparazione...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

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
      'Submersion necessita di accesso ai dati di immersione dell\'Apple Watch per importare le immersioni.';

  @override
  String get diveImport_healthkit_accessRequired =>
      'Accesso HealthKit richiesto';

  @override
  String get diveImport_healthkit_closeTooltip =>
      'Chiudi importazione Apple Watch';

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
  String get diveImport_healthkit_grantAccess => 'Concedi accesso';

  @override
  String get diveImport_healthkit_noDivesFound => 'Nessuna immersione trovata';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'Nessuna attività subacquea trovata nell\'intervallo di date selezionato.';

  @override
  String get diveImport_healthkit_notAvailable => 'Non disponibile';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'L\'importazione da Apple Watch è disponibile solo su dispositivi iOS e macOS.';

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
  String get gasCalculators_rockBottom_aboutDescription =>
      'Il rock bottom è la riserva minima di gas per una risalita di emergenza condividendo l\'aria con il compagno.\n\n• Usa consumi SAC da stress (2-3x il normale)\n• Presuppone entrambi i subacquei su una bombola\n• Include la tappa di sicurezza se abilitata\n\nInverti sempre l\'immersione PRIMA di raggiungere il rock bottom!';

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
  String get gasCalculators_rockBottom_buddySac => 'SAC compagno';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'SAC combinato sotto stress';

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
      'Usa valori SAC più alti per tenere conto dello stress durante l\'emergenza';

  @override
  String get gasCalculators_rockBottom_stressedSacRates =>
      'Valori SAC sotto stress';

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
  String get gasCalculators_rockBottom_yourSac => 'Il tuo SAC';

  @override
  String get maps_heatMap_hide => 'Nascondi mappa termica';

  @override
  String get maps_heatMap_overlayOff =>
      'Sovrapposizione mappa termica disattivata';

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
  String get tankPresets_customPresets => 'Preset personalizzati';

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
  String get tankPresets_new_title => 'Nuovo preset bombola';

  @override
  String get tankPresets_noPresets => 'Nessun preset bombola disponibile';

  @override
  String get tankPresets_title => 'Preset bombole';

  @override
  String get tools_deco_description =>
      'Calcola i limiti di non decompressione, le tappe deco richieste e l\'esposizione CNS/OTU per profili multilivello.';

  @override
  String get tools_deco_subtitle => 'Pianifica immersioni con tappe deco';

  @override
  String get tools_deco_title => 'Calcolatore deco';

  @override
  String get tools_disclaimer =>
      'Questi calcolatori sono solo a scopo di pianificazione. Verifica sempre i calcoli e segui la tua formazione subacquea.';

  @override
  String get tools_gas_description =>
      'Quattro calcolatori gas specializzati:\n• MOD - Profondità massima operativa per una miscela\n• Best Mix - O₂% ideale per una profondità target\n• Consumo - Stima del consumo di gas\n• Rock Bottom - Calcolo della riserva di emergenza';

  @override
  String get tools_gas_subtitle => 'MOD, Best Mix, Consumo, Rock Bottom';

  @override
  String get tools_gas_title => 'Calcolatori gas';

  @override
  String get tools_title => 'Strumenti';

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
  String get tools_weight_description =>
      'Stima la zavorra necessaria in base a muta, materiale della bombola, tipo di acqua e peso corporeo.';

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
  String get tools_weight_subtitle =>
      'Zavorra consigliata per la tua configurazione';

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
}
