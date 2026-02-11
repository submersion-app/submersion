// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

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
  String get buddies_action_add => 'Buddy toevoegen';

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
  String get buddies_picker_addNew => 'Nieuwe buddy toevoegen';

  @override
  String get buddies_picker_done => 'Gereed';

  @override
  String get buddies_picker_noBuddiesFound => 'Geen buddies gevonden';

  @override
  String get buddies_picker_noBuddiesYet => 'Nog geen buddies';

  @override
  String get buddies_picker_noneSelected => 'Geen buddies geselecteerd';

  @override
  String get buddies_picker_searchHint => 'Zoek buddies...';

  @override
  String get buddies_picker_selectBuddies => 'Selecteer buddies';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Selecteer rol voor $name';
  }

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
  String get certifications_detail_label_expiryDate => 'Vervaldatum';

  @override
  String get certifications_detail_label_instructorName => 'Naam';

  @override
  String get certifications_detail_label_instructorNumber => 'Instructeur #';

  @override
  String get certifications_detail_label_issueDate => 'Uitgiftedatum';

  @override
  String get certifications_detail_label_level => 'Niveau';

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
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Gecertificeerd door $agency';
  }

  @override
  String get certifications_ecard_label_instructor => 'INSTRUCTEUR';

  @override
  String get certifications_ecard_label_issued => 'UITGEGEVEN';

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
  String get certifications_edit_help_expiryDate =>
      'Laat leeg voor certificeringen die niet verlopen';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Voer certificeringskaartnummer in';

  @override
  String get certifications_edit_hint_certificationName =>
      'bijv. Open Water Diver';

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
  String get certifications_edit_label_certificationName =>
      'Certificeringsnaam *';

  @override
  String get certifications_edit_label_expiryDate => 'Vervaldatum';

  @override
  String get certifications_edit_label_instructorName => 'Instructeurnaam';

  @override
  String get certifications_edit_label_instructorNumber => 'Instructeurnummer';

  @override
  String get certifications_edit_label_issueDate => 'Uitgiftedatum';

  @override
  String get certifications_edit_label_level => 'Niveau';

  @override
  String get certifications_edit_label_notes => 'Notities';

  @override
  String get certifications_edit_level_notSpecified => 'Niet opgegeven';

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
  String get certifications_edit_validation_nameRequired =>
      'Voer een certificeringsnaam in';

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
  String certifications_walletCard_countPlural(Object count) {
    return '$count certificeringen';
  }

  @override
  String certifications_walletCard_countSingular(Object count) {
    return '$count certificering';
  }

  @override
  String get certifications_walletCard_emptyFooter =>
      'Voeg je eerste certificering toe';

  @override
  String get certifications_walletCard_error =>
      'Kan certificeringen niet laden';

  @override
  String get certifications_walletCard_semanticLabel =>
      'Certificeringsportemonnee. Tik om alle certificeringen te bekijken';

  @override
  String get certifications_walletCard_tapToAdd => 'Tik om toe te voegen';

  @override
  String get certifications_walletCard_title => 'Certificeringsportemonnee';

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
  String get common_action_back => 'Terug';

  @override
  String get common_action_cancel => 'Annuleren';

  @override
  String get common_action_close => 'Sluiten';

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
  String get common_label_error => 'Fout';

  @override
  String get common_label_loading => 'Laden';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get courses_action_add => 'Cursus toevoegen';

  @override
  String get courses_action_create => 'Cursus aanmaken';

  @override
  String get courses_action_edit => 'Cursus bewerken';

  @override
  String get courses_action_exportTrainingLog => 'Trainingslogboek exporteren';

  @override
  String get courses_action_markCompleted => 'Markeren als voltooid';

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
  String get courses_field_selectFromBuddies =>
      'Selecteer uit buddies (optioneel)';

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
  String get courses_label_none => '-- Geen --';

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
  String get courses_section_details => 'Cursusdetails';

  @override
  String get courses_section_earnedCertification => 'Behaalde certificering';

  @override
  String get courses_section_instructor => 'Instructeur';

  @override
  String get courses_section_notes => 'Notities';

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
  String get diveCenters_summary_topRated => 'Best beoordeeld';

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
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_tts => 'TTS';

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
  String get diveLog_deco_title => 'Decompressiestatus';

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
  String get diveLog_detail_button_rangeAnalysis => 'Bereikanalyse';

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
  String get diveLog_detail_fullscreen_sampleData => 'Meetgegevens';

  @override
  String get diveLog_detail_fullscreen_tapChartCompact =>
      'Tik op grafiek voor compacte weergave';

  @override
  String get diveLog_detail_fullscreen_tapChartFull =>
      'Tik op grafiek voor volledig scherm weergave';

  @override
  String get diveLog_detail_fullscreen_touchChart =>
      'Raak de grafiek aan om gegevens op dat punt te zien';

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
  String get diveLog_detail_section_decoStatus => 'Decompressiestatus';

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
  String get diveLog_detail_section_sacByCylinder => 'SAC per fles';

  @override
  String get diveLog_detail_section_sacRateBySegment =>
      'SAC-verbruik per segment';

  @override
  String get diveLog_detail_section_tags => 'Tags';

  @override
  String get diveLog_detail_section_tanks => 'Flessen';

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
  String diveLog_detail_tankCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'flessen',
      one: 'fles',
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
  String get diveLog_edit_headerNew => 'Nieuwe duik loggen';

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
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Bodemtijd berekend: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Fout bij opslaan van duik: $error';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'Geen duikprofielgegevens beschikbaar';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Kan bodemtijd niet berekenen uit profiel';

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
  String get diveLog_filter_noTagsYet => 'Nog geen tags aangemaakt';

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
  String get diveLog_filter_showOnlyFavorites => 'Toon alleen favoriete duiken';

  @override
  String get diveLog_filter_startDate => 'Startdatum';

  @override
  String get diveLog_filter_title => 'Duiken filteren';

  @override
  String get diveLog_filter_tooltip_close => 'Filter sluiten';

  @override
  String get diveLog_fullscreenProfile_close => 'Volledig scherm sluiten';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Duik #$number profiel';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Opstijgsnelheid';

  @override
  String get diveLog_legend_label_ceiling => 'Plafond';

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
  String get diveLog_legend_label_surfaceGf => 'Oppervlakte GF';

  @override
  String get diveLog_legend_label_temp => 'Temp';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Duikkaart';

  @override
  String get diveLog_listPage_compactTitle => 'Duiken';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Fout: $error';
  }

  @override
  String get diveLog_listPage_fab_logDive => 'Duik loggen';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Geavanceerd zoeken';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Duiknummering';

  @override
  String get diveLog_listPage_searchFieldLabel => 'Duiken zoeken...';

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
  String get diveLog_profileSelector_badge_primary => 'Primair';

  @override
  String get diveLog_profileSelector_label_diveComputers => 'Duikcomputers';

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
  String get diveLog_rangeStats_header_avg => 'Gem.';

  @override
  String get diveLog_rangeStats_header_max => 'Max';

  @override
  String get diveLog_rangeStats_header_min => 'Min';

  @override
  String get diveLog_rangeStats_label_depth => 'Diepte';

  @override
  String get diveLog_rangeStats_label_heartRate => 'Hartslag';

  @override
  String get diveLog_rangeStats_label_pressure => 'Druk';

  @override
  String get diveLog_rangeStats_label_temp => 'Temp';

  @override
  String get diveLog_rangeStats_title => 'Bereikanalyse';

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
  String get diveLog_search_end => 'Einde';

  @override
  String get diveLog_search_errorLoadingCenters =>
      'Fout bij laden van duikcentra';

  @override
  String get diveLog_search_errorLoadingDiveTypes => 'Fout bij laden duiktypes';

  @override
  String get diveLog_search_errorLoadingTrips => 'Fout bij laden van reizen';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

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
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Gasmengsel';

  @override
  String get diveLog_tank_selectPreset => 'Selecteer voorinstelling...';

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
  String get diveLog_tooltip_ceiling => 'Plafond';

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
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Tijd';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get divePlanner_action_addTank => 'Fles toevoegen';

  @override
  String get divePlanner_action_convertToDive => 'Omzetten naar duik';

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
  String get divePlanner_label_runtime => 'Looptijd';

  @override
  String get divePlanner_label_sacRate => 'SAC tempo:';

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
  String get diveSites_edit_appBar_newSite => 'Nieuwe stek';

  @override
  String get diveSites_edit_appBar_save => 'Opslaan';

  @override
  String get diveSites_edit_button_addSite => 'Stek toevoegen';

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
  String get diveSites_edit_gps_gettingLocation => 'Ophalen...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Kies een locatiemethode - coordinaten vullen automatisch land en regio in';

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
    return '$min-${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Tot ${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '${min}m+';
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
    return 'Weet je zeker dat je $name wilt verwijderen? Alle bijbehorende duiklogs worden losgekoppeld.';
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
  String get enum_buddyRole_buddy => 'Buddy';

  @override
  String get enum_buddyRole_diveGuide => 'Duikgids';

  @override
  String get enum_buddyRole_diveMaster => 'Divemaster';

  @override
  String get enum_buddyRole_instructor => 'Instructeur';

  @override
  String get enum_buddyRole_solo => 'Solo';

  @override
  String get enum_buddyRole_student => 'Leerling';

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
  String get enum_profileEvent_descentEnd => 'Einde afdaling';

  @override
  String get enum_profileEvent_descentStart => 'Begin afdaling';

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
  String get equipment_addSheet_brandHint => 'bijv. Scubapro';

  @override
  String get equipment_addSheet_brandLabel => 'Merk';

  @override
  String get equipment_addSheet_closeTooltip => 'Sluiten';

  @override
  String get equipment_addSheet_currencyLabel => 'Valuta';

  @override
  String get equipment_addSheet_dateLabel => 'Datum';

  @override
  String equipment_addSheet_errorSnackbar(Object error) {
    return 'Fout bij toevoegen van uitrusting: $error';
  }

  @override
  String get equipment_addSheet_modelHint => 'bijv. MK25 EVO';

  @override
  String get equipment_addSheet_modelLabel => 'Model';

  @override
  String get equipment_addSheet_nameHint => 'bijv. Mijn primaire ademautomaat';

  @override
  String get equipment_addSheet_nameLabel => 'Naam';

  @override
  String get equipment_addSheet_nameValidation => 'Voer een naam in';

  @override
  String get equipment_addSheet_notesHint => 'Extra notities...';

  @override
  String get equipment_addSheet_notesLabel => 'Notities';

  @override
  String get equipment_addSheet_priceLabel => 'Prijs';

  @override
  String get equipment_addSheet_purchaseInfoTitle => 'Aankoopinformatie';

  @override
  String get equipment_addSheet_serialNumberLabel => 'Serienummer';

  @override
  String get equipment_addSheet_serviceIntervalHint =>
      'bijv. 365 voor jaarlijks';

  @override
  String get equipment_addSheet_serviceIntervalLabel =>
      'Serviceinterval (dagen)';

  @override
  String get equipment_addSheet_sizeHint => 'bijv. M, L, 42';

  @override
  String get equipment_addSheet_sizeLabel => 'Maat';

  @override
  String get equipment_addSheet_submitButton => 'Uitrusting toevoegen';

  @override
  String get equipment_addSheet_successSnackbar =>
      'Uitrusting succesvol toegevoegd';

  @override
  String get equipment_addSheet_title => 'Uitrusting toevoegen';

  @override
  String get equipment_addSheet_typeLabel => 'Type';

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
  String get gasCalculators_ppO2Limit => 'ppO₂ limiet';

  @override
  String get gasCalculators_resetAll => 'Alle calculators resetten';

  @override
  String get gasCalculators_sacRate => 'SAC tempo';

  @override
  String get gasCalculators_tab_bestMix => 'Beste mengsel';

  @override
  String get gasCalculators_tab_consumption => 'Verbruik';

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
  String get media_diveMediaSection_emptyState => 'Nog geen foto\'s';

  @override
  String get media_diveMediaSection_errorLoading => 'Fout bij laden van media';

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Foto bekijken. Lang indrukken om te ontkoppelen';

  @override
  String get media_diveMediaSection_title => 'Foto\'s & video';

  @override
  String get media_diveMediaSection_unlinkButton => 'Ontkoppelen';

  @override
  String get media_diveMediaSection_unlinkDialogContent =>
      'Deze foto van de duik verwijderen? De foto blijft in je galerij staan.';

  @override
  String get media_diveMediaSection_unlinkDialogTitle => 'Foto ontkoppelen';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Ontkoppelen mislukt: $error';
  }

  @override
  String get media_diveMediaSection_unlinkSuccess => 'Foto ontkoppeld';

  @override
  String get media_gpsBanner_addToSiteButton => 'Toevoegen aan duikstek';

  @override
  String media_gpsBanner_coordinates(Object latitude, Object longitude) {
    return 'Coordinaten: $latitude, $longitude';
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
  String media_import_importedAndFailed(Object imported, Object failed) {
    return '$imported geimporteerd, $failed mislukt';
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
  String get media_miniProfile_headerLabel => 'Duikprofiel';

  @override
  String get media_miniProfile_semanticLabel => 'Mini duikprofielgrafiek';

  @override
  String get media_photoPicker_appBarTitle => 'Foto\'s selecteren';

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
  String get media_photoPicker_grantAccessButton => 'Toegang verlenen';

  @override
  String get media_photoPicker_openSettingsButton => 'Instellingen openen';

  @override
  String get media_photoPicker_openSettingsSnackbar =>
      'Open Instellingen en schakel fototoegang in';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'Toegang tot de fotobibliotheek is geweigerd. Schakel deze in via Instellingen om duikfoto\'s toe te voegen.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion heeft toegang tot je fotobibliotheek nodig om duikfoto\'s toe te voegen.';

  @override
  String get media_photoPicker_permissionTitle => 'Fototoegang vereist';

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
  String get media_photoViewer_noPhotosAvailable => 'Geen foto\'s beschikbaar';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel =>
      'Video afspelen of pauzeren';

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
  String get nav_home => 'Home';

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
  String get onboarding_welcome_createProfile => 'Maak je profiel aan';

  @override
  String get onboarding_welcome_createProfileSubtitle =>
      'Voer je naam in om te beginnen. Je kunt later meer details toevoegen.';

  @override
  String get onboarding_welcome_creating => 'Aanmaken...';

  @override
  String onboarding_welcome_errorCreatingProfile(Object error) {
    return 'Fout bij aanmaken profiel: $error';
  }

  @override
  String get onboarding_welcome_getStarted => 'Aan de slag';

  @override
  String get onboarding_welcome_nameHint => 'Voer je naam in';

  @override
  String get onboarding_welcome_nameLabel => 'Je naam';

  @override
  String get onboarding_welcome_nameValidation => 'Voer je naam in';

  @override
  String get onboarding_welcome_subtitle =>
      'Geavanceerd duiklogboek en analyse';

  @override
  String get onboarding_welcome_title => 'Welkom bij Submersion';

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
  String get settings_about_reportIssue_snackbar =>
      'Ga naar github.com/submersion/submersion';

  @override
  String get settings_about_version => 'Versie 0.1.0';

  @override
  String get settings_appBar_title => 'Instellingen';

  @override
  String get settings_appearance_appLanguage => 'App-taal';

  @override
  String get settings_appearance_depthColoredCards =>
      'Dieptegekleurde duikkaarten';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Toon duikkaarten met oceaangekleurde achtergronden op basis van diepte';

  @override
  String get settings_appearance_gasSwitchMarkers => 'Gaswisselmarkeringen';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'Toon markeringen voor gaswisselingen';

  @override
  String get settings_appearance_header_diveLog => 'Duiklogboek';

  @override
  String get settings_appearance_header_diveProfile => 'Duikprofiel';

  @override
  String get settings_appearance_header_diveSites => 'Duikstekken';

  @override
  String get settings_appearance_header_language => 'Taal';

  @override
  String get settings_appearance_header_theme => 'Thema';

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
  String get settings_appearance_pressureThresholdMarkers =>
      'Drukdrempelmarkeringen';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Toon markeringen wanneer flesdruk drempels overschrijdt';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Toon markeringen wanneer flesdruk de 2/3, 1/2 en 1/3 drempels overschrijdt';

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
  String get settings_backToSettings_tooltip => 'Terug naar instellingen';

  @override
  String get settings_cloudSync_appBar_title => 'Cloudsynchronisatie';

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
  String get settings_cloudSync_header_advanced => 'Geavanceerd';

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
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Synchroniseren via Google Drive';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Synchroniseren via Apple iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Initialisatie van $providerName-provider mislukt';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Niet beschikbaar op dit platform';

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
  String get settings_data_backup => 'Back-up';

  @override
  String get settings_data_backup_subtitle =>
      'Maak een back-up van je gegevens';

  @override
  String get settings_data_cloudSync => 'Cloudsynchronisatie';

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
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Selecteer $presetName conservatismevoorinstelling';
  }

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
  String get settings_manage_tankPresets => 'Flesvoorinstellingen';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Aangepaste flesconfiguraties beheren';

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
  String get settings_notifications_disabled_enableButton => 'Inschakelen';

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
  String surfaceInterval_heSemantics(Object percent) {
    return 'Helium: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Huidig interval';

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
  String get surfaceInterval_secondDive_gasAir => '(Lucht)';

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
  String get tags_hint_addTags => 'Tags toevoegen...';

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
      'Importeer duiken opgenomen op Apple Watch Ultra';

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
  String get transfer_import_autoDetectSemanticLabel =>
      'Gegevens importeren met automatische detectie';

  @override
  String get transfer_import_autoDetectSubtitle =>
      'Detecteert automatisch CSV, UDDF, FIT en meer';

  @override
  String get transfer_import_autoDetectTitle => 'Gegevens importeren';

  @override
  String get transfer_import_byFormatHeader => 'Importeren op formaat';

  @override
  String get transfer_import_csvSubtitle =>
      'Duiken importeren vanuit CSV-bestand';

  @override
  String get transfer_import_csvTitle => 'Importeren vanuit CSV';

  @override
  String get transfer_import_fitSubtitle =>
      'Duiken importeren vanuit Garmin Descent-exportbestanden';

  @override
  String get transfer_import_fitTitle => 'Importeren vanuit FIT-bestand';

  @override
  String get transfer_import_operationCompleted => 'Bewerking voltooid';

  @override
  String transfer_import_operationFailed(Object error) {
    return 'Bewerking mislukt: $error';
  }

  @override
  String get transfer_import_sectionHeader => 'Gegevens importeren';

  @override
  String get transfer_import_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_import_uddfTitle => 'Importeren vanuit UDDF';

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
  String get trips_detail_stat_totalBottomTime => 'Totale bodemtijd';

  @override
  String get trips_detail_stat_totalDives => 'Totaal duiken';

  @override
  String get trips_detail_tooltip_edit => 'Reis bewerken';

  @override
  String get trips_detail_tooltip_editShort => 'Bewerken';

  @override
  String get trips_detail_tooltip_moreOptions => 'Meer opties';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Bekijk op kaart';

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
  String get universalImport_action_selectFile => 'Selecteer bestand';

  @override
  String get universalImport_description_supportedFormats =>
      'Selecteer een duiklogboekbestand om te importeren. Ondersteunde formaten zijn CSV, UDDF, Subsurface XML en Garmin FIT.';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Dit formaat wordt nog niet ondersteund. Exporteer als UDDF of CSV.';

  @override
  String get universalImport_hint_tagDescription =>
      'Tag alle geïmporteerde duiken voor eenvoudig filteren';

  @override
  String get universalImport_hint_tagExample =>
      'bijv. MacDive Import 2026-02-09';

  @override
  String get universalImport_label_columnMapping => 'Kolomtoewijzing';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped van $total kolommen toegewezen';
  }

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
  String get universalImport_label_importComplete => 'Import voltooid';

  @override
  String get universalImport_label_importTag => 'Import tag';

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
  String get universalImport_step_import => 'Importeren';

  @override
  String get universalImport_step_map => 'Toewijzen';

  @override
  String get universalImport_step_review => 'Controleren';

  @override
  String get universalImport_step_select => 'Selecteren';

  @override
  String get universalImport_title => 'Gegevens importeren';

  @override
  String get universalImport_tooltip_clearTag => 'Tag wissen';

  @override
  String get universalImport_tooltip_closeWizard => 'Importwizard sluiten';

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
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... en nog $count meer';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Annuleren';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadFailed => 'Download mislukt';

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
  String get diveComputer_download_newDivesImported =>
      'Nieuwe duiken geimporteerd';

  @override
  String get diveComputer_download_preparing => 'Voorbereiden...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

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
      'Submersion heeft toegang nodig tot je Apple Watch-duikgegevens om duiken te importeren.';

  @override
  String get diveImport_healthkit_accessRequired => 'HealthKit-toegang vereist';

  @override
  String get diveImport_healthkit_closeTooltip => 'Apple Watch-import sluiten';

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
  String get diveImport_healthkit_grantAccess => 'Toegang verlenen';

  @override
  String get diveImport_healthkit_noDivesFound => 'Geen duiken gevonden';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'Geen onderwaterduikactiviteiten gevonden in het geselecteerde datumbereik.';

  @override
  String get diveImport_healthkit_notAvailable => 'Niet beschikbaar';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'Apple Watch-import is alleen beschikbaar op iOS- en macOS-apparaten.';

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
  String get gasCalculators_rockBottom_aboutDescription =>
      'Rock bottom is de minimale gasreserve voor een noodopstijging terwijl je lucht deelt met je buddy.\n\n• Gebruikt verhoogde SAC-waarden (2-3x normaal)\n• Gaat ervan uit dat beide duikers op een fles zitten\n• Inclusief veiligheidsstop indien ingeschakeld\n\nKeer de duik altijd om VOOR je rock bottom bereikt!';

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
  String get gasCalculators_rockBottom_buddySac => 'SAC buddy';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'Gecombineerde stress-SAC';

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
      'Gebruik hogere SAC-waarden om rekening te houden met stress tijdens een noodsituatie';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'Stress-SAC-waarden';

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
  String get gasCalculators_rockBottom_yourSac => 'Jouw SAC';

  @override
  String get maps_heatMap_hide => 'Heatmap verbergen';

  @override
  String get maps_heatMap_overlayOff => 'Heatmap-overlay is uit';

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
  String get tankPresets_customPresets => 'Eigen instellingen';

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
  String get tankPresets_new_title => 'Nieuwe flesinstelling';

  @override
  String get tankPresets_noPresets => 'Geen flesinstellingen beschikbaar';

  @override
  String get tankPresets_title => 'Flesinstellingen';

  @override
  String get tools_deco_description =>
      'Bereken no-decompressielimieten, vereiste decostops en CNS/OTU-blootstelling voor duikprofielen op meerdere niveaus.';

  @override
  String get tools_deco_subtitle => 'Plan duiken met decostops';

  @override
  String get tools_deco_title => 'Decocalculator';

  @override
  String get tools_disclaimer =>
      'Deze calculators zijn alleen bedoeld voor planningsdoeleinden. Controleer berekeningen altijd en volg je duikopleiding.';

  @override
  String get tools_gas_description =>
      'Vier gespecialiseerde gascalculators:\n• MOD - Maximale werkdiepte voor een gasmengsel\n• Beste mix - Ideaal O2% voor een doeldiepte\n• Verbruik - Schatting gasverbruik\n• Rock Bottom - Berekening noodreserve';

  @override
  String get tools_gas_subtitle => 'MOD, Beste mix, Verbruik, Rock Bottom';

  @override
  String get tools_gas_title => 'Gascalculators';

  @override
  String get tools_title => 'Gereedschap';

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
  String get tools_weight_description =>
      'Schat het gewicht dat je nodig hebt op basis van je duikpak, flesmateriaal, watertype en lichaamsgewicht.';

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
  String get tools_weight_subtitle => 'Aanbevolen gewicht voor je opstelling';

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
}
