// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get accessibility_dialog_keyboardShortcutsTitle =>
      'Billentyuparancsok';

  @override
  String get accessibility_keyLabel_backspace => 'Backspace';

  @override
  String get accessibility_keyLabel_delete => 'Delete';

  @override
  String get accessibility_keyLabel_down => 'Le';

  @override
  String get accessibility_keyLabel_enter => 'Enter';

  @override
  String get accessibility_keyLabel_esc => 'Esc';

  @override
  String get accessibility_keyLabel_left => 'Bal';

  @override
  String get accessibility_keyLabel_right => 'Jobb';

  @override
  String get accessibility_keyLabel_up => 'Fel';

  @override
  String accessibility_label_chartSummary(
    Object chartType,
    Object description,
  ) {
    return '$chartType diagram. $description';
  }

  @override
  String get accessibility_label_createNewItem => 'Uj elem letrehozasa';

  @override
  String get accessibility_label_hideList => 'Lista elrejtese';

  @override
  String get accessibility_label_hideMapView => 'Terkepi nezet elrejtese';

  @override
  String accessibility_label_listPane(Object title) {
    return '$title lista panel';
  }

  @override
  String accessibility_label_mapPane(Object title) {
    return '$title terkep panel';
  }

  @override
  String accessibility_label_mapViewTitle(Object title) {
    return '$title terkepi nezet';
  }

  @override
  String get accessibility_label_showList => 'Lista megjelenitese';

  @override
  String get accessibility_label_showMapView => 'Terkepi nezet megjelenitese';

  @override
  String get accessibility_label_viewDetails => 'Reszletek megtekintese';

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
  String get accessibility_shortcutCategory_editing => 'Szerkesztes';

  @override
  String get accessibility_shortcutCategory_general => 'Altalanos';

  @override
  String get accessibility_shortcutCategory_help => 'Sugo';

  @override
  String get accessibility_shortcutCategory_navigation => 'Navigacio';

  @override
  String get accessibility_shortcutCategory_search => 'Kereses';

  @override
  String get accessibility_shortcut_closeCancel => 'Bezaras / Megse';

  @override
  String get accessibility_shortcut_goBack => 'Vissza';

  @override
  String get accessibility_shortcut_goToDives => 'Ugras a merulesekhez';

  @override
  String get accessibility_shortcut_goToEquipment => 'Ugras a felszereleshez';

  @override
  String get accessibility_shortcut_goToSettings => 'Ugras a beallitasokhoz';

  @override
  String get accessibility_shortcut_goToSites => 'Ugras a merulohelyekhez';

  @override
  String get accessibility_shortcut_goToStatistics => 'Ugras a statisztikakhoz';

  @override
  String get accessibility_shortcut_keyboardShortcuts => 'Billentyuparancsok';

  @override
  String get accessibility_shortcut_newDive => 'Uj merules';

  @override
  String get accessibility_shortcut_openSettings => 'Beallitasok megnyitasa';

  @override
  String get accessibility_shortcut_searchDives => 'Merulesek keresese';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return 'Rendezes: $displayName, jelenleg kivalasztva';
  }

  @override
  String accessibility_sort_unselectedLabel(Object displayName) {
    return 'Rendezes: $displayName';
  }

  @override
  String get backup_appBar_title => 'Biztonsági Mentés és Visszaállítás';

  @override
  String get backup_backingUp => 'Mentés folyamatban...';

  @override
  String get backup_backupNow => 'Mentés Most';

  @override
  String get backup_cloud_enabled => 'Felhő mentés';

  @override
  String get backup_cloud_enabled_subtitle =>
      'Mentések feltöltése a felhőtárhelyre';

  @override
  String get backup_delete_dialog_cancel => 'Mégse';

  @override
  String get backup_delete_dialog_content =>
      'Ez a biztonsági mentés véglegesen törlésre kerül. Ez a művelet nem vonható vissza.';

  @override
  String get backup_delete_dialog_delete => 'Törlés';

  @override
  String get backup_delete_dialog_title => 'Mentés Törlése';

  @override
  String get backup_frequency_daily => 'Napi';

  @override
  String get backup_frequency_monthly => 'Havi';

  @override
  String get backup_frequency_weekly => 'Heti';

  @override
  String get backup_history_action_delete => 'Törlés';

  @override
  String get backup_history_action_restore => 'Visszaállítás';

  @override
  String get backup_history_empty => 'Nincsenek mentések';

  @override
  String backup_history_error(Object error) {
    return 'Hiba az előzmények betöltésekor: $error';
  }

  @override
  String get backup_restore_dialog_cancel => 'Mégse';

  @override
  String get backup_restore_dialog_restore => 'Visszaállítás';

  @override
  String get backup_restore_dialog_safetyNote =>
      'A jelenlegi adatokról automatikusan biztonsági mentés készül a visszaállítás előtt.';

  @override
  String get backup_restore_dialog_title => 'Mentés Visszaállítása';

  @override
  String get backup_restore_dialog_warning =>
      'Ez MINDEN jelenlegi adatot lecserél a mentés adataival. Ez a művelet nem vonható vissza.';

  @override
  String get backup_schedule_enabled => 'Automatikus mentések';

  @override
  String get backup_schedule_enabled_subtitle =>
      'Adatok mentése ütemezés szerint';

  @override
  String get backup_schedule_frequency => 'Gyakoriság';

  @override
  String get backup_schedule_retention => 'Mentések megőrzése';

  @override
  String get backup_schedule_retention_subtitle =>
      'A régebbi mentések automatikusan eltávolításra kerülnek';

  @override
  String get backup_section_cloud => 'Felhő';

  @override
  String get backup_section_history => 'Előzmények';

  @override
  String get backup_section_schedule => 'Ütemezés';

  @override
  String get backup_status_disabled => 'Automatikus Mentések Kikapcsolva';

  @override
  String backup_status_lastBackup(String time) {
    return 'Utolsó mentés: $time';
  }

  @override
  String get backup_status_neverBackedUp => 'Még Nem Készült Mentés';

  @override
  String get backup_status_noBackupsYet =>
      'Hozza létre az első mentést az adatok védelméhez';

  @override
  String get backup_status_overdue => 'Mentés Késésben';

  @override
  String get backup_status_upToDate => 'Mentések Naprakészek';

  @override
  String backup_time_daysAgo(int count) {
    return '$count napja';
  }

  @override
  String backup_time_hoursAgo(int count) {
    return '$count órája';
  }

  @override
  String get backup_time_justNow => 'Éppen most';

  @override
  String backup_time_minutesAgo(int count) {
    return '$count perce';
  }

  @override
  String get buddies_action_add => 'Búvártárs hozzáadása';

  @override
  String get buddies_action_addFirst => 'Add hozzá az első búvártársad';

  @override
  String get buddies_action_addTooltip => 'Új búvártárs hozzáadása';

  @override
  String get buddies_action_clearSearch => 'Keresés törlése';

  @override
  String get buddies_action_edit => 'Búvártárs szerkesztése';

  @override
  String get buddies_action_importFromContacts => 'Importálás névjegyekből';

  @override
  String get buddies_action_moreOptions => 'További lehetőségek';

  @override
  String get buddies_action_retry => 'Újra';

  @override
  String get buddies_action_search => 'Búvártársak keresése';

  @override
  String get buddies_action_shareDives => 'Merülések megosztása';

  @override
  String get buddies_action_sort => 'Rendezés';

  @override
  String get buddies_action_sortTitle => 'Búvártársak rendezése';

  @override
  String get buddies_action_update => 'Búvártárs frissítése';

  @override
  String buddies_action_viewAll(Object count) {
    return 'Összes megtekintése ($count)';
  }

  @override
  String buddies_detail_error(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get buddies_detail_noDivesTogether => 'Még nem merültetek együtt';

  @override
  String get buddies_detail_notFound => 'Búvártárs nem található';

  @override
  String buddies_dialog_deleteMessage(Object name) {
    return 'Biztosan törölni szeretnéd: $name? Ez a művelet nem vonható vissza.';
  }

  @override
  String get buddies_dialog_deleteTitle => 'Búvártárs törlése?';

  @override
  String get buddies_dialog_discard => 'Elvetés';

  @override
  String get buddies_dialog_discardMessage =>
      'Nem mentett módosításaid vannak. Biztosan elveted őket?';

  @override
  String get buddies_dialog_discardTitle => 'Módosítások elvetése?';

  @override
  String get buddies_dialog_keepEditing => 'Szerkesztés folytatása';

  @override
  String get buddies_empty_subtitle =>
      'Add hozzá az első búvártársad a kezdéshez';

  @override
  String get buddies_empty_title => 'Még nincsenek búvártársak';

  @override
  String buddies_error_loading(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get buddies_error_unableToLoadDives =>
      'Nem lehet betölteni a merüléseket';

  @override
  String get buddies_error_unableToLoadStats =>
      'Nem lehet betölteni a statisztikákat';

  @override
  String get buddies_field_certificationAgency => 'Képesítő szervezet';

  @override
  String get buddies_field_certificationLevel => 'Képesítési szint';

  @override
  String get buddies_field_email => 'E-mail';

  @override
  String get buddies_field_emailHint => 'pelda@email.hu';

  @override
  String get buddies_field_nameHint => 'Add meg a búvártárs nevét';

  @override
  String get buddies_field_nameRequired => 'Név *';

  @override
  String get buddies_field_notes => 'Jegyzetek';

  @override
  String get buddies_field_notesHint =>
      'Írj jegyzeteket erről a búvártársról...';

  @override
  String get buddies_field_phone => 'Telefon';

  @override
  String get buddies_field_phoneHint => '+36 30 123 4567';

  @override
  String get buddies_label_agency => 'Szervezet';

  @override
  String buddies_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülés',
      one: '1 merülés',
    );
    return '$_temp0';
  }

  @override
  String get buddies_label_level => 'Szint';

  @override
  String get buddies_label_notSpecified => 'Nincs megadva';

  @override
  String get buddies_label_photoComingSoon => 'Fotó támogatás a v2.0-ban';

  @override
  String get buddies_message_added => 'Búvártárs sikeresen hozzáadva';

  @override
  String get buddies_message_contactImportUnavailable =>
      'Névjegy importálás nem elérhető ezen a platformon';

  @override
  String get buddies_message_contactLoadFailed =>
      'Névjegyek betöltése sikertelen';

  @override
  String get buddies_message_contactPermissionRequired =>
      'Névjegy engedély szükséges a búvártársak importálásához';

  @override
  String get buddies_message_deleted => 'Búvártárs törölve';

  @override
  String buddies_message_errorImportingContact(Object error) {
    return 'Hiba a névjegy importálásakor: $error';
  }

  @override
  String buddies_message_errorLoading(Object error) {
    return 'Hiba a búvártárs betöltésekor: $error';
  }

  @override
  String buddies_message_errorSaving(Object error) {
    return 'Hiba a búvártárs mentésekor: $error';
  }

  @override
  String buddies_message_exportFailed(Object error) {
    return 'Exportálás sikertelen: $error';
  }

  @override
  String get buddies_message_noDivesFound =>
      'Nem találhatók exportálandó merülések';

  @override
  String get buddies_message_noDivesToShare =>
      'Nincsenek megosztható merülések ezzel a búvártárssal';

  @override
  String get buddies_message_preparingExport => 'Exportálás előkészítése...';

  @override
  String get buddies_message_updated => 'Búvártárs sikeresen frissítve';

  @override
  String get buddies_picker_add => 'Hozzáadás';

  @override
  String get buddies_picker_addNew => 'Új búvártárs hozzáadása';

  @override
  String get buddies_picker_done => 'Kész';

  @override
  String get buddies_picker_noBuddiesFound => 'Nem találhatók búvártársak';

  @override
  String get buddies_picker_noBuddiesYet => 'Még nincsenek búvártársak';

  @override
  String get buddies_picker_noneSelected => 'Nincs kiválasztott búvártárs';

  @override
  String get buddies_picker_searchHint => 'Búvártársak keresése...';

  @override
  String get buddies_picker_selectBuddies => 'Búvártársak kiválasztása';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Szerep kiválasztása: $name';
  }

  @override
  String get buddies_picker_tapToAdd =>
      'Koppints a \'Hozzáadás\'-ra a búvártársak kiválasztásához';

  @override
  String get buddies_search_hint => 'Keresés név, e-mail vagy telefon alapján';

  @override
  String buddies_search_noResults(Object query) {
    return 'Nincs találat erre: \"$query\"';
  }

  @override
  String get buddies_section_certification => 'Képesítés';

  @override
  String get buddies_section_contact => 'Kapcsolat';

  @override
  String get buddies_section_diveStatistics => 'Merülési statisztikák';

  @override
  String get buddies_section_notes => 'Jegyzetek';

  @override
  String get buddies_section_sharedDives => 'Közös merülések';

  @override
  String get buddies_stat_divesTogether => 'Közös merülések';

  @override
  String get buddies_stat_favoriteSite => 'Kedvenc hely';

  @override
  String get buddies_stat_firstDive => 'Első merülés';

  @override
  String get buddies_stat_lastDive => 'Utolsó merülés';

  @override
  String get buddies_summary_overview => 'Áttekintés';

  @override
  String get buddies_summary_quickActions => 'Gyors műveletek';

  @override
  String get buddies_summary_recentBuddies => 'Legutóbbi búvártársak';

  @override
  String get buddies_summary_selectHint =>
      'Válassz ki egy búvártársat a listából a részletek megtekintéséhez';

  @override
  String get buddies_summary_title => 'Búvártársak';

  @override
  String get buddies_summary_totalBuddies => 'Összes búvártárs';

  @override
  String get buddies_summary_withCertification => 'Képesítéssel';

  @override
  String get buddies_title => 'Búvártársak';

  @override
  String get buddies_title_add => 'Búvártárs hozzáadása';

  @override
  String get buddies_title_edit => 'Búvártárs szerkesztése';

  @override
  String get buddies_title_singular => 'Búvártárs';

  @override
  String get buddies_validation_emailInvalid => 'Adj meg érvényes e-mail címet';

  @override
  String get buddies_validation_nameRequired => 'Adj meg egy nevet';

  @override
  String get certifications_appBar_addCertification => 'Kepesites hozzaadasa';

  @override
  String get certifications_appBar_certificationWallet => 'Kepesites tarca';

  @override
  String get certifications_appBar_editCertification =>
      'Kepesites szerkesztese';

  @override
  String get certifications_appBar_title => 'Kepesitesek';

  @override
  String get certifications_detail_action_delete => 'Torles';

  @override
  String get certifications_detail_appBar_title => 'Kepesites';

  @override
  String get certifications_detail_courseCompleted => 'Befejezett';

  @override
  String get certifications_detail_courseInProgress => 'Folyamatban';

  @override
  String get certifications_detail_dialog_cancel => 'Megse';

  @override
  String get certifications_detail_dialog_deleteConfirm => 'Torles';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return 'Biztosan torli a kovetkezot: \"$name\"?';
  }

  @override
  String get certifications_detail_dialog_deleteTitle => 'Kepesites torlese?';

  @override
  String get certifications_detail_label_agency => 'Szervezet';

  @override
  String get certifications_detail_label_cardNumber => 'Kartyaszam';

  @override
  String get certifications_detail_label_expiryDate => 'Lejarat datuma';

  @override
  String get certifications_detail_label_instructorName => 'Nev';

  @override
  String get certifications_detail_label_instructorNumber => 'Oktato #';

  @override
  String get certifications_detail_label_issueDate => 'Kiadas datuma';

  @override
  String get certifications_detail_label_level => 'Szint';

  @override
  String get certifications_detail_label_type => 'Tipus';

  @override
  String get certifications_detail_label_validity => 'Ervenyesseg';

  @override
  String get certifications_detail_noExpiration => 'Nincs lejaarat';

  @override
  String get certifications_detail_notFound => 'Kepesites nem talalhato';

  @override
  String get certifications_detail_photoLabel_back => 'Hatlap';

  @override
  String get certifications_detail_photoLabel_front => 'Elolap';

  @override
  String certifications_detail_photo_fullscreenTitle(
    Object label,
    Object name,
  ) {
    return '$label - $name';
  }

  @override
  String get certifications_detail_photo_unableToLoad =>
      'Nem sikerult a kep betoltese';

  @override
  String get certifications_detail_sectionTitle_cardPhotos => 'Kartya fotok';

  @override
  String get certifications_detail_sectionTitle_dates => 'Datumok';

  @override
  String get certifications_detail_sectionTitle_details =>
      'Kepesites reszletek';

  @override
  String get certifications_detail_sectionTitle_instructor => 'Oktato';

  @override
  String get certifications_detail_sectionTitle_notes => 'Megjegyzesek';

  @override
  String get certifications_detail_sectionTitle_trainingCourse =>
      'Kepzesi tanfolyam';

  @override
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  ) {
    return '$name $label fotoja. Koppintson a teljes kepernyon torteno megtekinteshez';
  }

  @override
  String get certifications_detail_snackBar_deleted => 'Kepesites torolve';

  @override
  String get certifications_detail_status_expired => 'Ez a kepesites lejart';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return 'Lejart $date-kor';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return '$days nap mulva jar le';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return 'Lejar $date-kor';
  }

  @override
  String get certifications_detail_tooltip_edit => 'Kepesites szerkesztese';

  @override
  String get certifications_detail_tooltip_editShort => 'Szerkesztes';

  @override
  String get certifications_detail_tooltip_moreOptions => 'Tovabbi lehetosegek';

  @override
  String get certifications_ecardStack_empty_subtitle =>
      'Adja hozza elso kepesiteset, hogy itt megjelenjen';

  @override
  String get certifications_ecardStack_empty_title =>
      'Meg nincsenek kepesitesek';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Kepesitette: $agency';
  }

  @override
  String get certifications_ecard_label_instructor => 'OKTATO';

  @override
  String get certifications_ecard_label_issued => 'KIADAS';

  @override
  String get certifications_ecard_statusBadge_expired => 'LEJART';

  @override
  String get certifications_ecard_statusBadge_expiring => 'LEJAROBAN';

  @override
  String get certifications_edit_appBar_add => 'Kepesites hozzaadasa';

  @override
  String get certifications_edit_appBar_edit => 'Kepesites szerkesztese';

  @override
  String get certifications_edit_button_add => 'Kepesites hozzaadasa';

  @override
  String get certifications_edit_button_cancel => 'Megse';

  @override
  String get certifications_edit_button_save => 'Mentes';

  @override
  String get certifications_edit_button_update => 'Kepesites frissitese';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return '$label torlese';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect =>
      'Koppintson a kivalasztashoz';

  @override
  String get certifications_edit_dialog_discard => 'Eldobas';

  @override
  String get certifications_edit_dialog_discardContent =>
      'Mentetlen valtozasai vannak. Biztosan el akar tavozni?';

  @override
  String get certifications_edit_dialog_discardTitle => 'Valtozasok eldobasa?';

  @override
  String get certifications_edit_dialog_keepEditing => 'Szerkesztes folytatasa';

  @override
  String get certifications_edit_help_expiryDate =>
      'Hagyja uresen a le nem jaro kepesiteseknel';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Adja meg a kepesitesi kartyaszamot';

  @override
  String get certifications_edit_hint_certificationName =>
      'pl. Open Water Diver';

  @override
  String get certifications_edit_hint_instructorName =>
      'A kepesito oktato neve';

  @override
  String get certifications_edit_hint_instructorNumber =>
      'Oktato kepesitesi szama';

  @override
  String get certifications_edit_hint_notes => 'Barmilyen tovabbi megjegyzes';

  @override
  String get certifications_edit_label_agency => 'Szervezet *';

  @override
  String get certifications_edit_label_cardNumber => 'Kartyaszam';

  @override
  String get certifications_edit_label_certificationName => 'Kepesites neve *';

  @override
  String get certifications_edit_label_expiryDate => 'Lejarat datuma';

  @override
  String get certifications_edit_label_instructorName => 'Oktato neve';

  @override
  String get certifications_edit_label_instructorNumber => 'Oktato szama';

  @override
  String get certifications_edit_label_issueDate => 'Kiadas datuma';

  @override
  String get certifications_edit_label_level => 'Szint';

  @override
  String get certifications_edit_label_notes => 'Megjegyzesek';

  @override
  String get certifications_edit_level_notSpecified => 'Nincs megadva';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return '$label foto hozzaadasa. Koppintson a kivalasztashoz';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return '$label foto csatolva. Koppintson a modositashoz';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery =>
      'Valasszon a galeriabol';

  @override
  String certifications_edit_photo_removeTooltip(Object label) {
    return '$label foto eltavolitasa';
  }

  @override
  String get certifications_edit_photo_takePhoto => 'Foto keszitese';

  @override
  String get certifications_edit_sectionTitle_cardPhotos => 'Kartya fotok';

  @override
  String get certifications_edit_sectionTitle_dates => 'Datumok';

  @override
  String get certifications_edit_sectionTitle_instructorInfo =>
      'Oktato informaciok';

  @override
  String get certifications_edit_sectionTitle_notes => 'Megjegyzesek';

  @override
  String get certifications_edit_snackBar_added =>
      'Kepesites sikeresen hozzaadva';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return 'Hiba a kepesites betoltesekor: $error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return 'Hiba a foto kivalasztasakor: $error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return 'Hiba a kepesites mentesekor: $error';
  }

  @override
  String get certifications_edit_snackBar_updated =>
      'Tanusitvany sikeresen frissitve';

  @override
  String get certifications_edit_validation_nameRequired =>
      'Kerem, adja meg a tanusitvany nevet';

  @override
  String get certifications_list_button_retry => 'Ujraproba';

  @override
  String get certifications_list_empty_button =>
      'Adja hozza az elso tanusitvanyt';

  @override
  String get certifications_list_empty_subtitle =>
      'Adja hozza merulesi tanusitványait a kepzesek\nes kepesitesek nyomon kovetésehez';

  @override
  String get certifications_list_empty_title =>
      'Meg nincsenek tanusitványok hozzaadva';

  @override
  String certifications_list_error_loading(Object error) {
    return 'Hiba a tanusitványok betoltesekor: $error';
  }

  @override
  String get certifications_list_fab_addCertification =>
      'Tanusitvany hozzaadasa';

  @override
  String get certifications_list_section_expired => 'Lejart';

  @override
  String get certifications_list_section_expiringSoon => 'Hamarosan lejar';

  @override
  String get certifications_list_section_valid => 'Ervenyes';

  @override
  String get certifications_list_sort_title => 'Tanusitványok rendezese';

  @override
  String get certifications_list_tile_expired => 'Lejart';

  @override
  String certifications_list_tile_expiringDays(Object days) {
    return '${days}n';
  }

  @override
  String get certifications_list_tooltip_addCertification =>
      'Tanusitvany hozzaadasa';

  @override
  String get certifications_list_tooltip_search => 'Tanusitványok keresese';

  @override
  String get certifications_list_tooltip_sort => 'Rendezes';

  @override
  String get certifications_list_tooltip_walletView => 'Kartya nezet';

  @override
  String get certifications_picker_clearTooltip =>
      'Tanusitvany kivalasztas torlese';

  @override
  String get certifications_picker_empty_addButton => 'Tanusitvany hozzaadasa';

  @override
  String get certifications_picker_empty_title => 'Meg nincsenek tanusitványok';

  @override
  String certifications_picker_error(Object error) {
    return 'Hiba a tanusitványok betoltesekor: $error';
  }

  @override
  String get certifications_picker_expired => 'Lejart';

  @override
  String get certifications_picker_hint =>
      'Koppintson egy megszerzett tanusitvany csatolasahoz';

  @override
  String get certifications_picker_newCert => 'Uj tanusitvany';

  @override
  String get certifications_picker_noSelection =>
      'Nincs tanusitvany kivalasztva';

  @override
  String get certifications_picker_sheetTitle => 'Csatolas tanusitványhoz';

  @override
  String get certifications_renderer_footer => 'Submersion merulesi naplo';

  @override
  String certifications_renderer_label_cardNumber(Object number) {
    return 'Kartyaszam: $number';
  }

  @override
  String get certifications_renderer_label_hasCompletedTraining =>
      'elvégezte a kepzest mint';

  @override
  String certifications_renderer_label_instructor(Object name) {
    return 'Oktato: $name';
  }

  @override
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  ) {
    return 'Oktato: $name ($number)';
  }

  @override
  String certifications_renderer_label_issued(Object date) {
    return 'Kiallitva: $date';
  }

  @override
  String get certifications_renderer_label_thisCertifies =>
      'Ezuton igazoljuk, hogy';

  @override
  String get certifications_search_empty_hint =>
      'Kereses nev, szervezet vagy kartyaszam alapjan';

  @override
  String get certifications_search_fieldLabel => 'Tanusitványok keresese...';

  @override
  String certifications_search_noResults(Object query) {
    return 'Nem talalhato tanusitvany a kovetkezore: \"$query\"';
  }

  @override
  String get certifications_search_tooltip_back => 'Vissza';

  @override
  String get certifications_search_tooltip_clear => 'Kereses torlese';

  @override
  String certifications_share_error_card(Object error) {
    return 'Nem sikerult a kartya megosztasa: $error';
  }

  @override
  String certifications_share_error_certificate(Object error) {
    return 'Nem sikerult a tanusitvany megosztasa: $error';
  }

  @override
  String get certifications_share_option_card_subtitle =>
      'Bankkartya meretu tanusitvany kep';

  @override
  String get certifications_share_option_card_title => 'Megosztas kartyakent';

  @override
  String get certifications_share_option_certificate_subtitle =>
      'Hivatalos tanusitvany dokumentum';

  @override
  String get certifications_share_option_certificate_title =>
      'Megosztas oklevélkent';

  @override
  String get certifications_share_title => 'Tanusitvany megosztasa';

  @override
  String get certifications_summary_header_subtitle =>
      'Valasszon egy tanusitvanyt a listabol a reszletek megtekintésehez';

  @override
  String get certifications_summary_header_title => 'Tanusitványok';

  @override
  String get certifications_summary_overview_title => 'Attekintes';

  @override
  String get certifications_summary_quickActions_add =>
      'Tanusitvany hozzaadasa';

  @override
  String get certifications_summary_quickActions_title => 'Gyorsmuveletek';

  @override
  String get certifications_summary_recentTitle => 'Legutobbi tanusitványok';

  @override
  String get certifications_summary_stat_expired => 'Lejart';

  @override
  String get certifications_summary_stat_expiringSoon => 'Hamarosan lejar';

  @override
  String get certifications_summary_stat_total => 'Osszes';

  @override
  String get certifications_summary_stat_valid => 'Ervenyes';

  @override
  String certifications_walletCard_countPlural(Object count) {
    return '$count tanusitvany';
  }

  @override
  String certifications_walletCard_countSingular(Object count) {
    return '$count tanusitvany';
  }

  @override
  String get certifications_walletCard_emptyFooter =>
      'Adja hozza az elso tanusitvanyt';

  @override
  String get certifications_walletCard_error =>
      'Nem sikerult a tanusitványok betoltese';

  @override
  String get certifications_walletCard_semanticLabel =>
      'Tanusitvany tarca. Koppintson az osszes tanusitvany megtekintésehez';

  @override
  String get certifications_walletCard_tapToAdd => 'Koppintson a hozzaadashoz';

  @override
  String get certifications_walletCard_title => 'Tanusitvany tarca';

  @override
  String get certifications_wallet_appBar_title => 'Tanusitvany tarca';

  @override
  String get certifications_wallet_error_retry => 'Ujraproba';

  @override
  String get certifications_wallet_error_title =>
      'Nem sikerult a tanusitványok betoltese';

  @override
  String get certifications_wallet_options_edit => 'Szerkesztes';

  @override
  String get certifications_wallet_options_share => 'Megosztas';

  @override
  String get certifications_wallet_options_viewDetails =>
      'Reszletek megtekintese';

  @override
  String get certifications_wallet_tooltip_add => 'Tanusitvany hozzaadasa';

  @override
  String get certifications_wallet_tooltip_share => 'Tanusitvany megosztasa';

  @override
  String get common_action_back => 'Vissza';

  @override
  String get common_action_cancel => 'Megse';

  @override
  String get common_action_close => 'Bezaras';

  @override
  String get common_action_delete => 'Torles';

  @override
  String get common_action_edit => 'Szerkesztes';

  @override
  String get common_action_ok => 'OK';

  @override
  String get common_action_save => 'Mentes';

  @override
  String get common_action_search => 'Kereses';

  @override
  String get common_label_error => 'Hiba';

  @override
  String get common_label_loading => 'Betoltes';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get courses_action_add => 'Tanfolyam hozzáadása';

  @override
  String get courses_action_create => 'Tanfolyam létrehozása';

  @override
  String get courses_action_edit => 'Tanfolyam szerkesztése';

  @override
  String get courses_action_exportTrainingLog => 'Képzési napló exportálása';

  @override
  String get courses_action_markCompleted => 'Megjelölés befejezettként';

  @override
  String get courses_action_moreOptions => 'További lehetőségek';

  @override
  String get courses_action_retry => 'Újra';

  @override
  String get courses_action_saveChanges => 'Módosítások mentése';

  @override
  String get courses_action_saveSemantic => 'Tanfolyam mentése';

  @override
  String get courses_action_sort => 'Rendezés';

  @override
  String get courses_action_sortTitle => 'Tanfolyamok rendezése';

  @override
  String courses_card_instructor(Object name) {
    return 'Oktató: $name';
  }

  @override
  String courses_card_started(Object date) {
    return 'Kezdés: $date';
  }

  @override
  String get courses_detail_certificationNotFound => 'Képesítés nem található';

  @override
  String get courses_detail_noTrainingDives =>
      'Még nincsenek hozzákapcsolt képzési merülések';

  @override
  String get courses_detail_notFound => 'Tanfolyam nem található';

  @override
  String get courses_dialog_complete => 'Befejezés';

  @override
  String courses_dialog_deleteMessage(Object name) {
    return 'Biztosan törölni szeretnéd: $name? Ez a művelet nem vonható vissza.';
  }

  @override
  String get courses_dialog_deleteTitle => 'Tanfolyam törlése?';

  @override
  String get courses_dialog_markCompletedMessage =>
      'Ez befejezettként jelöli meg a tanfolyamot a mai dátummal. Folytatod?';

  @override
  String get courses_dialog_markCompletedTitle => 'Megjelölés befejezettként?';

  @override
  String get courses_empty_noCompleted => 'Nincsenek befejezett tanfolyamok';

  @override
  String get courses_empty_noInProgress =>
      'Nincsenek folyamatban lévő tanfolyamok';

  @override
  String get courses_empty_subtitle =>
      'Add hozzá az első tanfolyamod a kezdéshez';

  @override
  String get courses_empty_title => 'Még nincsenek képzési tanfolyamok';

  @override
  String courses_error_generic(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get courses_error_loadingCertification =>
      'Hiba a képesítés betöltésekor';

  @override
  String get courses_error_loadingDives => 'Hiba a merülések betöltésekor';

  @override
  String get courses_field_courseName => 'Tanfolyam neve';

  @override
  String get courses_field_courseNameHint => 'pl. Nyíltvízi búvár';

  @override
  String get courses_field_instructorName => 'Oktató neve';

  @override
  String get courses_field_instructorNumber => 'Oktató száma';

  @override
  String get courses_field_linkCertificationHint =>
      'Csatolj egy tanfolyamból szerzett képesítést';

  @override
  String get courses_field_location => 'Helyszín';

  @override
  String get courses_field_notes => 'Jegyzetek';

  @override
  String get courses_field_selectFromBuddies =>
      'Választás búvártársak közül (opcionális)';

  @override
  String get courses_filter_all => 'Összes';

  @override
  String get courses_label_agency => 'Szervezet';

  @override
  String get courses_label_completed => 'Befejezve';

  @override
  String get courses_label_completionDate => 'Befejezés dátuma';

  @override
  String get courses_label_courseInProgress => 'Tanfolyam folyamatban';

  @override
  String get courses_label_instructorNumber => 'Oktató sz.';

  @override
  String get courses_label_location => 'Helyszín';

  @override
  String get courses_label_name => 'Név';

  @override
  String get courses_label_none => '-- Nincs --';

  @override
  String get courses_label_startDate => 'Kezdés dátuma';

  @override
  String courses_message_errorSaving(Object error) {
    return 'Hiba a tanfolyam mentésekor: $error';
  }

  @override
  String courses_message_exportFailed(Object error) {
    return 'Képzési napló exportálása sikertelen: $error';
  }

  @override
  String get courses_picker_active => 'Aktív';

  @override
  String get courses_picker_clearSelection => 'Kijelölés törlése';

  @override
  String get courses_picker_createCourse => 'Tanfolyam létrehozása';

  @override
  String courses_picker_errorLoading(Object error) {
    return 'Hiba a tanfolyamok betöltésekor: $error';
  }

  @override
  String get courses_picker_newCourse => 'Új tanfolyam';

  @override
  String get courses_picker_noCourses => 'Még nincsenek tanfolyamok';

  @override
  String get courses_picker_noneSelected => 'Nincs kiválasztott tanfolyam';

  @override
  String get courses_picker_selectTitle => 'Képzési tanfolyam kiválasztása';

  @override
  String get courses_picker_selected => 'kiválasztva';

  @override
  String get courses_picker_tapToLink =>
      'Koppints a képzési tanfolyamhoz való csatoláshoz';

  @override
  String get courses_section_details => 'Tanfolyam részletei';

  @override
  String get courses_section_earnedCertification => 'Megszerzett képesítés';

  @override
  String get courses_section_instructor => 'Oktató';

  @override
  String get courses_section_notes => 'Jegyzetek';

  @override
  String get courses_section_trainingDives => 'Képzési merülések';

  @override
  String get courses_status_completed => 'Befejezve';

  @override
  String courses_status_daysSinceStart(Object days) {
    return '$days nap a kezdés óta';
  }

  @override
  String courses_status_durationDays(Object days) {
    return '$days nap';
  }

  @override
  String get courses_status_inProgress => 'Folyamatban';

  @override
  String courses_status_semanticLabel(Object status, Object duration) {
    return '$status, $duration';
  }

  @override
  String get courses_summary_overview => 'Áttekintés';

  @override
  String get courses_summary_quickActions => 'Gyors műveletek';

  @override
  String get courses_summary_recentCourses => 'Legutóbbi tanfolyamok';

  @override
  String get courses_summary_selectHint =>
      'Válassz ki egy tanfolyamot a listából a részletek megtekintéséhez';

  @override
  String get courses_summary_title => 'Képzési tanfolyamok';

  @override
  String get courses_summary_total => 'Összesen';

  @override
  String get courses_title => 'Képzési tanfolyamok';

  @override
  String get courses_title_edit => 'Tanfolyam szerkesztése';

  @override
  String get courses_title_new => 'Új tanfolyam';

  @override
  String get courses_title_singular => 'Tanfolyam';

  @override
  String get courses_validation_nameRequired => 'Adj meg tanfolyamnevet';

  @override
  String get dashboard_activity_daySinceDiving => 'Napja nem merult';

  @override
  String get dashboard_activity_daysSinceDiving => 'Napja nem merult';

  @override
  String dashboard_activity_diveInYear(Object year) {
    return 'Merules $year-ben';
  }

  @override
  String get dashboard_activity_diveThisMonth => 'Merules ebben a honapban';

  @override
  String dashboard_activity_divesInYear(Object year) {
    return 'Merules $year-ben';
  }

  @override
  String get dashboard_activity_divesThisMonth => 'Merules ebben a honapban';

  @override
  String get dashboard_activity_error => 'Hiba';

  @override
  String get dashboard_activity_lastDive => 'Utolso merules';

  @override
  String get dashboard_activity_loading => 'Betoltes';

  @override
  String get dashboard_activity_noDivesYet => 'Meg nincs merules';

  @override
  String get dashboard_activity_today => 'Ma!';

  @override
  String get dashboard_alerts_actionUpdate => 'Frissites';

  @override
  String get dashboard_alerts_actionView => 'Megtekintes';

  @override
  String get dashboard_alerts_checkInsuranceExpiry =>
      'Ellenorizze a biztositas lejarati datumat';

  @override
  String get dashboard_alerts_daysOverdueOne => '1 napja lejaart';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return '$count napja lejaart';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => '1 nap mulva esedékes';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return '$count nap mulva esedékes';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return '$name szerviz esedékes';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return '$name szerviz lejaart';
  }

  @override
  String get dashboard_alerts_insuranceExpired => 'Biztositas lejaart';

  @override
  String get dashboard_alerts_insuranceExpiredGeneric =>
      'A merulesi biztositasa lejaart';

  @override
  String dashboard_alerts_insuranceExpiredProvider(Object provider) {
    return '$provider lejaart';
  }

  @override
  String dashboard_alerts_insuranceExpiresDate(Object date) {
    return 'Lejar: $date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon =>
      'Biztositas hamarosan lejar';

  @override
  String get dashboard_alerts_sectionTitle =>
      'Figyelmeztetesek es emlekeztetok';

  @override
  String get dashboard_alerts_serviceDueToday => 'Szerviz ma esedékes';

  @override
  String get dashboard_alerts_serviceIntervalReached => 'Szerviz idokoz elerve';

  @override
  String get dashboard_defaultDiverName => 'Buvar';

  @override
  String get dashboard_greeting_afternoon => 'Jo delutant';

  @override
  String get dashboard_greeting_evening => 'Jo estet';

  @override
  String get dashboard_greeting_morning => 'Jo reggelt';

  @override
  String dashboard_greeting_withName(Object greeting, Object name) {
    return '$greeting, $name!';
  }

  @override
  String dashboard_greeting_withoutName(Object greeting) {
    return '$greeting!';
  }

  @override
  String get dashboard_hero_divesLoggedOne => '1 merules rogzitve';

  @override
  String dashboard_hero_divesLoggedOther(Object count) {
    return '$count merules rogzitve';
  }

  @override
  String get dashboard_hero_error => 'Kesz felfedezni a melyseget?';

  @override
  String dashboard_hero_hoursUnderwater(Object hours) {
    return '$hours ora viz alatt';
  }

  @override
  String get dashboard_hero_loading => 'Merulesi statisztikak betoltese...';

  @override
  String dashboard_hero_minutesUnderwater(Object minutes) {
    return '$minutes perc viz alatt';
  }

  @override
  String get dashboard_hero_noDives => 'Kesz rogziteni az elso meruleset?';

  @override
  String get dashboard_personalRecords_coldest => 'Leghidegebb';

  @override
  String get dashboard_personalRecords_deepest => 'Legmelyebb';

  @override
  String get dashboard_personalRecords_longest => 'Leghosszabb';

  @override
  String get dashboard_personalRecords_sectionTitle => 'Szemelyes rekordok';

  @override
  String get dashboard_personalRecords_warmest => 'Legmelegebb';

  @override
  String get dashboard_quickActions_addSite => 'Merulohely hozzaadasa';

  @override
  String get dashboard_quickActions_addSiteTooltip =>
      'Uj merulohely hozzaadasa';

  @override
  String get dashboard_quickActions_logDive => 'Merules rogzitese';

  @override
  String get dashboard_quickActions_logDiveTooltip => 'Uj merules rogzitese';

  @override
  String get dashboard_quickActions_planDive => 'Merules tervezese';

  @override
  String get dashboard_quickActions_planDiveTooltip => 'Uj merules tervezese';

  @override
  String get dashboard_quickActions_sectionTitle => 'Gyors muveletek';

  @override
  String get dashboard_quickActions_statistics => 'Statisztikak';

  @override
  String get dashboard_quickActions_statisticsTooltip =>
      'Merulesi statisztikak megtekintese';

  @override
  String get dashboard_quickStats_countries => 'Orszagok';

  @override
  String get dashboard_quickStats_countriesSubtitle => 'meglátogatott';

  @override
  String get dashboard_quickStats_sectionTitle => 'Attekintes';

  @override
  String get dashboard_quickStats_species => 'Fajok';

  @override
  String get dashboard_quickStats_speciesSubtitle => 'felfedezett';

  @override
  String get dashboard_quickStats_topBuddy => 'Legjobb buddy';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count merules';
  }

  @override
  String get dashboard_recentDives_empty => 'Meg nincs rogzitett merules';

  @override
  String get dashboard_recentDives_errorLoading =>
      'Nem sikerult betolteni a meruleseket';

  @override
  String get dashboard_recentDives_logFirst => 'Rogzitse az elso meruleset';

  @override
  String get dashboard_recentDives_sectionTitle => 'Legutobbi merulesek';

  @override
  String get dashboard_recentDives_viewAll => 'Osszes megtekintese';

  @override
  String get dashboard_recentDives_viewAllTooltip =>
      'Osszes merules megtekintese';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count aktiv figyelmeztetés';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives =>
      'Hiba: Nem sikerult betolteni a legutobbi meruleseket';

  @override
  String get dashboard_semantics_errorLoadingStatistics =>
      'Hiba: Nem sikerult betolteni a statisztikakat';

  @override
  String get dashboard_semantics_greetingBanner =>
      'Iranyitopult udvozlo banner';

  @override
  String get dashboard_stats_errorLoadingStatistics =>
      'Nem sikerult betolteni a statisztikakat';

  @override
  String get dashboard_stats_hoursLogged => 'Rogzitett orak';

  @override
  String get dashboard_stats_maxDepth => 'Max melyseg';

  @override
  String get dashboard_stats_sitesVisited => 'Meglátogatott helyek';

  @override
  String get dashboard_stats_totalDives => 'Osszes merules';

  @override
  String get decoCalculator_addToPlanner => 'Hozzáadás a tervezőhöz';

  @override
  String decoCalculator_bottomTimeSemantics(Object time) {
    return 'Fenéken töltött idő: $time perc';
  }

  @override
  String get decoCalculator_createPlanTooltip =>
      'Merülési terv létrehozása a jelenlegi paraméterekből';

  @override
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  ) {
    return 'Létrehozott terv: $depth$depthSymbol $time percre $gasMixName keverékkel';
  }

  @override
  String get decoCalculator_customMixTrimix => 'Egyedi keverék (Trimix)';

  @override
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol) {
    return 'Mélység: $depth $depthSymbol';
  }

  @override
  String get decoCalculator_diveParameters => 'Merülési paraméterek';

  @override
  String get decoCalculator_endCaution => 'Óvatosan';

  @override
  String get decoCalculator_endDanger => 'Veszély';

  @override
  String get decoCalculator_endSafe => 'Biztonságos';

  @override
  String get decoCalculator_field_bottomTime => 'Fenéken töltött idő';

  @override
  String get decoCalculator_field_depth => 'Mélység';

  @override
  String get decoCalculator_field_gasMix => 'Gázkeverék';

  @override
  String get decoCalculator_gasSafety => 'Gáz biztonság';

  @override
  String get decoCalculator_hideCustomMix => 'Egyedi keverék elrejtése';

  @override
  String get decoCalculator_hideCustomMixSemantics =>
      'Egyedi gázkeverék választó elrejtése';

  @override
  String get decoCalculator_modExceeded => 'MOD túllépve';

  @override
  String get decoCalculator_modSafe => 'MOD biztonságos';

  @override
  String get decoCalculator_ppO2Caution => 'ppO2 óvatosan';

  @override
  String get decoCalculator_ppO2Danger => 'ppO2 veszély';

  @override
  String get decoCalculator_ppO2Hypoxic => 'ppO2 hipoxikus';

  @override
  String get decoCalculator_ppO2Safe => 'ppO2 biztonságos';

  @override
  String get decoCalculator_resetToDefaults =>
      'Alapértelmezések visszaállítása';

  @override
  String get decoCalculator_showCustomMixSemantics =>
      'Egyedi gázkeverék választó megjelenítése';

  @override
  String decoCalculator_timeValueMin(Object time) {
    return '$time perc';
  }

  @override
  String get decoCalculator_title => 'Dekompressziós kalkulátor';

  @override
  String diveCenters_accessibility_markerLabel(Object name) {
    return 'Búvárközpont: $name';
  }

  @override
  String get diveCenters_accessibility_selected => 'kiválasztva';

  @override
  String diveCenters_accessibility_viewDetails(Object name) {
    return 'Részletek megtekintése: $name';
  }

  @override
  String get diveCenters_accessibility_viewDives =>
      'Merülések megtekintése ezzel a központtal';

  @override
  String get diveCenters_accessibility_viewFullscreenMap =>
      'Teljes képernyős térkép megtekintése';

  @override
  String diveCenters_accessibility_viewSavedCenter(Object name) {
    return 'Mentett búvárközpont megtekintése: $name';
  }

  @override
  String get diveCenters_action_addCenter => 'Központ hozzáadása';

  @override
  String get diveCenters_action_addNew => 'Új hozzáadása';

  @override
  String get diveCenters_action_clearRating => 'Törlés';

  @override
  String get diveCenters_action_gettingLocation => 'Lekérés...';

  @override
  String get diveCenters_action_import => 'Importálás';

  @override
  String get diveCenters_action_importToMyCenters =>
      'Importálás a központjaimhoz';

  @override
  String get diveCenters_action_lookingUp => 'Keresés...';

  @override
  String get diveCenters_action_lookupFromAddress => 'Keresés cím alapján';

  @override
  String get diveCenters_action_pickFromMap => 'Kiválasztás térképről';

  @override
  String get diveCenters_action_retry => 'Újra';

  @override
  String get diveCenters_action_settings => 'Beállítások';

  @override
  String get diveCenters_action_useMyLocation => 'Saját helyzetem használata';

  @override
  String get diveCenters_action_view => 'Megtekintés';

  @override
  String diveCenters_detail_divesLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rögzített merülés',
      one: '1 rögzített merülés',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_detail_divesWithCenter =>
      'Merülések ezzel a központtal';

  @override
  String get diveCenters_detail_noDivesLogged =>
      'Még nincsenek rögzített merülések';

  @override
  String diveCenters_dialog_deleteMessage(Object name) {
    return 'Biztosan törölni szeretnéd: \"$name\"?';
  }

  @override
  String get diveCenters_dialog_deleteTitle => 'Búvárközpont törlése';

  @override
  String get diveCenters_dialog_discard => 'Elvetés';

  @override
  String get diveCenters_dialog_discardMessage =>
      'Nem mentett módosításaid vannak. Biztosan elveted őket?';

  @override
  String get diveCenters_dialog_discardTitle => 'Módosítások elvetése?';

  @override
  String get diveCenters_dialog_keepEditing => 'Szerkesztés folytatása';

  @override
  String get diveCenters_empty_subtitle =>
      'Add hozzá kedvenc búvárüzleteid és szolgáltatóid';

  @override
  String get diveCenters_empty_title => 'Még nincsenek búvárközpontok';

  @override
  String diveCenters_error_generic(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get diveCenters_error_geocodeFailed =>
      'Nem sikerült koordinátákat találni ehhez a címhez';

  @override
  String get diveCenters_error_importFailed =>
      'Búvárközpont importálása sikertelen';

  @override
  String diveCenters_error_loading(Object error) {
    return 'Hiba a búvárközpontok betöltésekor: $error';
  }

  @override
  String get diveCenters_error_locationPermission =>
      'Nem lehet lekérni a helyzetet. Ellenőrizd az engedélyeket.';

  @override
  String get diveCenters_error_locationUnavailable =>
      'Nem lehet lekérni a helyzetet. A helymeghatározás lehet, hogy nem elérhető.';

  @override
  String get diveCenters_error_noAddressForLookup =>
      'Adj meg egy címet a koordináták kereséséhez';

  @override
  String get diveCenters_error_notFound => 'Búvárközpont nem található';

  @override
  String diveCenters_error_saving(Object error) {
    return 'Hiba a búvárközpont mentésekor: $error';
  }

  @override
  String get diveCenters_error_unknown => 'Ismeretlen hiba';

  @override
  String get diveCenters_field_city => 'Város';

  @override
  String get diveCenters_field_country => 'Ország';

  @override
  String get diveCenters_field_latitude => 'Földrajzi szélesség';

  @override
  String get diveCenters_field_longitude => 'Földrajzi hosszúság';

  @override
  String get diveCenters_field_nameRequired => 'Név *';

  @override
  String get diveCenters_field_postalCode => 'Irányítószám';

  @override
  String get diveCenters_field_rating => 'Értékelés';

  @override
  String get diveCenters_field_stateProvince => 'Állam/Megye';

  @override
  String get diveCenters_field_street => 'Utca, házszám';

  @override
  String get diveCenters_hint_addressDescription =>
      'Opcionális utca, házszám navigációhoz';

  @override
  String get diveCenters_hint_affiliationsDescription =>
      'Válaszd ki a képzési szervezeteket, amelyekkel ez a központ kapcsolatban áll';

  @override
  String get diveCenters_hint_city => 'pl. Balaton';

  @override
  String get diveCenters_hint_country => 'pl. Magyarország';

  @override
  String get diveCenters_hint_email => 'info@buvariskola.hu';

  @override
  String get diveCenters_hint_gpsDescription =>
      'Válassz helymeghatározási módszert vagy add meg manuálisan a koordinátákat';

  @override
  String get diveCenters_hint_importSearch =>
      'Búvárközpontok keresése (pl. \"PADI\", \"Thaiföld\")';

  @override
  String get diveCenters_hint_latitude => 'pl. 47.4979';

  @override
  String get diveCenters_hint_longitude => 'pl. 19.0402';

  @override
  String get diveCenters_hint_name => 'Add meg a búvárközpont nevét';

  @override
  String get diveCenters_hint_notes => 'Bármilyen további információ...';

  @override
  String get diveCenters_hint_phone => '+36 30 123 4567';

  @override
  String get diveCenters_hint_postalCode => 'pl. 1234';

  @override
  String get diveCenters_hint_stateProvince => 'pl. Veszprém';

  @override
  String get diveCenters_hint_street => 'pl. Fő utca 123';

  @override
  String get diveCenters_hint_website => 'www.buvariskola.hu';

  @override
  String diveCenters_import_fromDatabase(Object count) {
    return 'Importálás adatbázisból ($count)';
  }

  @override
  String diveCenters_import_myCenters(Object count) {
    return 'Központjaim ($count)';
  }

  @override
  String get diveCenters_import_noResults => 'Nincs találat';

  @override
  String diveCenters_import_noResultsMessage(Object query) {
    return 'Nem találhatók búvárközpontok erre: \"$query\". Próbálj más keresési kifejezést.';
  }

  @override
  String get diveCenters_import_searchDescription =>
      'Keress búvárközpontokat, üzleteket és klubokat a világ körüli szolgáltatók adatbázisából.';

  @override
  String get diveCenters_import_searchError => 'Keresési hiba';

  @override
  String get diveCenters_import_searchHint =>
      'Próbálj név, ország vagy képesítő szervezet alapján keresni.';

  @override
  String get diveCenters_import_searchTitle => 'Búvárközpontok keresése';

  @override
  String get diveCenters_label_alreadyImported => 'Már importálva';

  @override
  String diveCenters_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülés',
      one: '1 merülés',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_label_email => 'E-mail';

  @override
  String get diveCenters_label_imported => 'Importálva';

  @override
  String get diveCenters_label_locationNotSet => 'Helyszín nincs beállítva';

  @override
  String get diveCenters_label_locationUnknown => 'Ismeretlen helyszín';

  @override
  String get diveCenters_label_phone => 'Telefon';

  @override
  String get diveCenters_label_saved => 'Mentve';

  @override
  String diveCenters_label_source(Object source) {
    return 'Forrás: $source';
  }

  @override
  String get diveCenters_label_website => 'Weboldal';

  @override
  String get diveCenters_map_addCoordinatesHint =>
      'Add hozzá a koordinátákat a búvárközpontjaidhoz, hogy lásd őket a térképen';

  @override
  String get diveCenters_map_noCoordinates =>
      'Nincsenek koordinátákkal rendelkező búvárközpontok';

  @override
  String get diveCenters_picker_newCenter => 'Új búvárközpont';

  @override
  String get diveCenters_picker_title => 'Búvárközpont kiválasztása';

  @override
  String diveCenters_search_noResults(Object query) {
    return 'Nincs találat erre: \"$query\"';
  }

  @override
  String get diveCenters_search_prompt => 'Búvárközpontok keresése';

  @override
  String get diveCenters_section_address => 'Cím';

  @override
  String get diveCenters_section_affiliations => 'Kapcsolatok';

  @override
  String get diveCenters_section_basicInfo => 'Alapvető információk';

  @override
  String get diveCenters_section_contact => 'Kapcsolat';

  @override
  String get diveCenters_section_contactInfo => 'Kapcsolati információk';

  @override
  String get diveCenters_section_gpsCoordinates => 'GPS koordináták';

  @override
  String get diveCenters_section_notes => 'Jegyzetek';

  @override
  String get diveCenters_snackbar_coordinatesFound =>
      'Koordináták megtalálva a címből';

  @override
  String get diveCenters_snackbar_copiedToClipboard => 'Vágólapra másolva';

  @override
  String diveCenters_snackbar_imported(Object name) {
    return 'Importálva: \"$name\"';
  }

  @override
  String get diveCenters_snackbar_locationCaptured => 'Helyszín rögzítve';

  @override
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Helyszín rögzítve (±${accuracy}m)';
  }

  @override
  String get diveCenters_snackbar_locationSelectedFromMap =>
      'Helyszín kiválasztva térképről';

  @override
  String get diveCenters_sort_title => 'Búvárközpontok rendezése';

  @override
  String get diveCenters_summary_countries => 'Országok';

  @override
  String get diveCenters_summary_highestRating => 'Legmagasabb értékelés';

  @override
  String get diveCenters_summary_overview => 'Áttekintés';

  @override
  String get diveCenters_summary_quickActions => 'Gyors műveletek';

  @override
  String get diveCenters_summary_recentCenters => 'Legutóbbi búvárközpontok';

  @override
  String get diveCenters_summary_selectPrompt =>
      'Válassz ki egy búvárközpontot a listából a részletek megtekintéséhez';

  @override
  String get diveCenters_summary_topRated => 'Legjobbra értékelt';

  @override
  String get diveCenters_summary_totalCenters => 'Összes központ';

  @override
  String get diveCenters_summary_withGps => 'GPS-szel';

  @override
  String get diveCenters_title => 'Búvárközpontok';

  @override
  String get diveCenters_title_add => 'Búvárközpont hozzáadása';

  @override
  String get diveCenters_title_edit => 'Búvárközpont szerkesztése';

  @override
  String get diveCenters_title_import => 'Búvárközpont importálása';

  @override
  String get diveCenters_tooltip_addNew => 'Új búvárközpont hozzáadása';

  @override
  String get diveCenters_tooltip_clearSearch => 'Keresés törlése';

  @override
  String get diveCenters_tooltip_edit => 'Búvárközpont szerkesztése';

  @override
  String get diveCenters_tooltip_fitAllCenters => 'Összes központ mutatása';

  @override
  String get diveCenters_tooltip_listView => 'Lista nézet';

  @override
  String get diveCenters_tooltip_mapView => 'Térkép nézet';

  @override
  String get diveCenters_tooltip_moreOptions => 'További lehetőségek';

  @override
  String get diveCenters_tooltip_search => 'Búvárközpontok keresése';

  @override
  String get diveCenters_tooltip_sort => 'Rendezés';

  @override
  String get diveCenters_validation_invalidEmail =>
      'Adj meg érvényes e-mail címet';

  @override
  String get diveCenters_validation_invalidLatitude =>
      'Érvénytelen földrajzi szélesség';

  @override
  String get diveCenters_validation_invalidLongitude =>
      'Érvénytelen földrajzi hosszúság';

  @override
  String get diveCenters_validation_nameRequired => 'Név megadása kötelező';

  @override
  String get diveComputer_action_setFavorite => 'Beállítás kedvencként';

  @override
  String diveComputer_error_generic(Object error) {
    return 'Hiba történt: $error';
  }

  @override
  String get diveComputer_error_notFound => 'Eszköz nem található';

  @override
  String get diveComputer_status_favorite => 'Kedvenc számítógép';

  @override
  String get diveComputer_title => 'Búvárcomputer';

  @override
  String diveLog_bulkDelete_confirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merulest',
      one: 'merulest',
    );
    return 'Biztosan torolni szeretne $count $_temp0? Ez a muvelet nem vonhato vissza.';
  }

  @override
  String get diveLog_bulkDelete_restored => 'Merulesek visszaallitva';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 torolve';
  }

  @override
  String get diveLog_bulkDelete_title => 'Merulesek torlese';

  @override
  String get diveLog_bulkDelete_undo => 'Visszavonas';

  @override
  String get diveLog_bulkEdit_addTags => 'Cimkek hozzaadasa';

  @override
  String get diveLog_bulkEdit_addTagsDescription =>
      'Cimkek hozzaadasa a kivalasztott merulesekhez';

  @override
  String diveLog_bulkEdit_addedTags(int tagCount, int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: 'cimke',
      one: 'cimke',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'meruleshez',
      one: 'meruleshez',
    );
    return '$tagCount $_temp0 hozzaadva $diveCount $_temp1';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => 'Ut modositasa';

  @override
  String get diveLog_bulkEdit_changeTripDescription =>
      'Kivalasztott merulesek athelyezese egy utra';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips => 'Hiba az utak betoltesekor';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return 'Nem sikerult hozzaadni a cimkeket: $error';
  }

  @override
  String diveLog_bulkEdit_failedUpdateTrip(Object error) {
    return 'Nem sikerult frissiteni az utat: $error';
  }

  @override
  String diveLog_bulkEdit_movedToTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 athelyezve az utra';
  }

  @override
  String get diveLog_bulkEdit_noTagsAvailable => 'Nincsenek elerheto cimkek.';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate =>
      'Nincsenek elerheto cimkek. Eloszor hozzon letre cimkeket.';

  @override
  String get diveLog_bulkEdit_noTrip => 'Nincs ut';

  @override
  String get diveLog_bulkEdit_removeFromTrip => 'Eltavolitas az utrol';

  @override
  String get diveLog_bulkEdit_removeTags => 'Cimkek eltavolitasa';

  @override
  String get diveLog_bulkEdit_removeTagsDescription =>
      'Cimkek eltavolitasa a kivalasztott merulesekrol';

  @override
  String diveLog_bulkEdit_removedFromTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 eltavolitva az utrol';
  }

  @override
  String get diveLog_bulkEdit_selectTrip => 'Ut kivalasztasa';

  @override
  String diveLog_bulkEdit_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 szerkesztese';
  }

  @override
  String get diveLog_bulkExport_csv => 'CSV';

  @override
  String get diveLog_bulkExport_csvDescription => 'Tablazatkezelo formatum';

  @override
  String diveLog_bulkExport_failed(Object error) {
    return 'Exportalas sikertelen: $error';
  }

  @override
  String get diveLog_bulkExport_pdf => 'PDF naplo';

  @override
  String get diveLog_bulkExport_pdfDescription =>
      'Nyomtathato merulesi naplo oldalak';

  @override
  String diveLog_bulkExport_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 sikeresen exportalva';
  }

  @override
  String diveLog_bulkExport_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 exportalasa';
  }

  @override
  String get diveLog_bulkExport_uddf => 'UDDF';

  @override
  String get diveLog_bulkExport_uddfDescription =>
      'Univerzalis merulesi adatformatum';

  @override
  String get diveLog_ccr_diluent_air => 'Levego';

  @override
  String get diveLog_ccr_hint_loopVolume => 'pl. 6.0';

  @override
  String get diveLog_ccr_hint_type => 'pl. Sofnolime';

  @override
  String get diveLog_ccr_label_deco => 'Deko';

  @override
  String get diveLog_ccr_label_he => 'He';

  @override
  String get diveLog_ccr_label_highBottom => 'Magas (Also)';

  @override
  String get diveLog_ccr_label_loopVolume => 'Hurokban levo terfogat';

  @override
  String get diveLog_ccr_label_lowDescAsc => 'Alacsony (Le/Fel)';

  @override
  String get diveLog_ccr_label_n2 => 'N₂';

  @override
  String get diveLog_ccr_label_o2 => 'O₂';

  @override
  String get diveLog_ccr_label_rated => 'Nevleges';

  @override
  String get diveLog_ccr_label_remaining => 'Maradek';

  @override
  String get diveLog_ccr_label_type => 'Tipus';

  @override
  String get diveLog_ccr_sectionDiluentGas => 'Higigaz';

  @override
  String get diveLog_ccr_sectionScrubber => 'Szorokeszulek';

  @override
  String get diveLog_ccr_sectionSetpoints => 'Setpointok (bar)';

  @override
  String get diveLog_ccr_title => 'CCR beallitasok';

  @override
  String diveLog_collapsible_semantics_collapse(Object title) {
    return '$title szekció osszecsuklasa';
  }

  @override
  String diveLog_collapsible_semantics_expand(Object title) {
    return '$title szekció kinyitasa';
  }

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return 'Atlag: $depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => 'Alap';

  @override
  String get diveLog_cylinderSac_noSac => 'SAC: --';

  @override
  String get diveLog_cylinderSac_tooltip_aiData =>
      'AI adó adatait hasznalja a nagyobb pontossaghoz';

  @override
  String get diveLog_cylinderSac_tooltip_basicData =>
      'Kezdo/veg nyomasokbol szamitva';

  @override
  String get diveLog_deco_badge_deco => 'DEKO';

  @override
  String get diveLog_deco_badge_noDeco => 'NINCS DEKO';

  @override
  String get diveLog_deco_label_ceiling => 'Plafon';

  @override
  String get diveLog_deco_label_leading => 'Vezeto';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String get diveLog_deco_sectionDecoStops => 'Deko megallok';

  @override
  String get diveLog_deco_sectionTissueLoading => 'Szovetterheltseg';

  @override
  String get diveLog_deco_semantics_notRequired =>
      'Dekompresszio nem szukseges';

  @override
  String get diveLog_deco_semantics_required => 'Dekompresszio szukseges';

  @override
  String get diveLog_deco_tissueFast => 'Gyors';

  @override
  String get diveLog_deco_tissueSlow => 'Lassu';

  @override
  String get diveLog_deco_title => 'Dekompresszios allapot';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return 'Osszes: $time';
  }

  @override
  String get diveLog_delete_cancel => 'Megse';

  @override
  String get diveLog_delete_confirm =>
      'Ez a muvelet nem vonhato vissza. A merules es az osszes kapcsolodo adat (profil, palackok, eszlelesek) veglegesen torlodik.';

  @override
  String get diveLog_delete_delete => 'Torles';

  @override
  String get diveLog_delete_title => 'Merules torlese?';

  @override
  String get diveLog_detail_appBar => 'Merules reszletei';

  @override
  String get diveLog_detail_badge_critical => 'KRITIKUS';

  @override
  String get diveLog_detail_badge_deco => 'DEKO';

  @override
  String get diveLog_detail_badge_noDeco => 'NINCS DEKO';

  @override
  String get diveLog_detail_badge_warning => 'FIGYELMEZTETÉS';

  @override
  String diveLog_detail_buddyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'buddy',
      one: 'buddy',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_button_playback => 'Lejatszas';

  @override
  String get diveLog_detail_button_rangeAnalysis => 'Tartomany elemzes';

  @override
  String get diveLog_detail_button_showEnd => 'Veg mutatasa';

  @override
  String get diveLog_detail_captureSignature => 'Oktatoi alairas rogzitese';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return '$timestamp időpontban';
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
    return 'Plafon: $value';
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
    return 'CNS: $cns • Max ppO₂: $maxPpO2 • $timestamp időpontban: $ppO2 bar';
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
      other: 'targy',
      one: 'targy',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_errorLoading => 'Hiba a merules betoltesekor';

  @override
  String get diveLog_detail_fullscreen_sampleData => 'Minta adatok';

  @override
  String get diveLog_detail_fullscreen_tapChartCompact =>
      'Koppints a grafikonra a kompakt nézetért';

  @override
  String get diveLog_detail_fullscreen_tapChartFull =>
      'Koppints a grafikonra a teljes képernyős nézetért';

  @override
  String get diveLog_detail_fullscreen_touchChart =>
      'Érintsd meg a grafikont az adott pont adatainak megtekintéséhez';

  @override
  String get diveLog_detail_label_airTemp => 'Levego hom.';

  @override
  String get diveLog_detail_label_avgDepth => 'Atlag melyseg';

  @override
  String get diveLog_detail_label_buddy => 'Buddy';

  @override
  String get diveLog_detail_label_currentDirection => 'Aramlat iranya';

  @override
  String get diveLog_detail_label_currentStrength => 'Aramlat erossege';

  @override
  String get diveLog_detail_label_diveComputer => 'Merulesszamitogep';

  @override
  String get diveLog_detail_label_serialNumber => 'Serial Number';

  @override
  String get diveLog_detail_label_firmwareVersion => 'Firmware Version';

  @override
  String get diveLog_detail_label_diveMaster => 'Divemaster';

  @override
  String get diveLog_detail_label_diveType => 'Merules tipusa';

  @override
  String get diveLog_detail_label_elevation => 'Magassag';

  @override
  String get diveLog_detail_label_entry => 'Beszallas:';

  @override
  String get diveLog_detail_label_entryMethod => 'Beszallasi mod';

  @override
  String get diveLog_detail_label_exit => 'Kiszallas:';

  @override
  String get diveLog_detail_label_exitMethod => 'Kiszallasi mod';

  @override
  String get diveLog_detail_label_gradientFactors => 'Gradiens faktorok';

  @override
  String get diveLog_detail_label_height => 'Magassag';

  @override
  String get diveLog_detail_label_highTide => 'Dagaly';

  @override
  String get diveLog_detail_label_lowTide => 'Apaly';

  @override
  String get diveLog_detail_label_ppO2AtPoint => 'ppO₂ a kivalasztott pontban:';

  @override
  String get diveLog_detail_label_rateOfChange => 'Valtozasi sebesseg';

  @override
  String get diveLog_detail_label_sacRate => 'SAC ertek';

  @override
  String get diveLog_detail_label_state => 'Allapot';

  @override
  String get diveLog_detail_label_surfaceInterval => 'Felszini szunet';

  @override
  String get diveLog_detail_label_surfacePressure => 'Felszini nyomas';

  @override
  String get diveLog_detail_label_swellHeight => 'Hullammagassag';

  @override
  String get diveLog_detail_label_total => 'Osszes:';

  @override
  String get diveLog_detail_label_visibility => 'Latasvisszonyok';

  @override
  String get diveLog_detail_label_waterType => 'Viz tipusa';

  @override
  String get diveLog_detail_menu_delete => 'Torles';

  @override
  String get diveLog_detail_menu_export => 'Exportalas';

  @override
  String get diveLog_detail_menu_openFullPage => 'Megnyitas teljes oldalon';

  @override
  String get diveLog_detail_noNotes =>
      'Nincsenek jegyzetek ehhez a meruleshez.';

  @override
  String get diveLog_detail_notFound => 'Merules nem talalhato';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count pont';
  }

  @override
  String get diveLog_detail_section_altitudeDive => 'Magassagi merules';

  @override
  String get diveLog_detail_section_buddies => 'Buddyk';

  @override
  String get diveLog_detail_section_conditions => 'Korulmenyek';

  @override
  String get diveLog_detail_section_customFields => 'Custom Fields';

  @override
  String get diveLog_detail_section_decoStatus => 'Dekompresszios allapot';

  @override
  String get diveLog_detail_section_details => 'Reszletek';

  @override
  String get diveLog_detail_section_diveProfile => 'Merulesi profil';

  @override
  String get diveLog_detail_section_equipment => 'Felszereles';

  @override
  String get diveLog_detail_section_marineLife => 'Tengeri elet';

  @override
  String get diveLog_detail_section_notes => 'Jegyzetek';

  @override
  String get diveLog_detail_section_oxygenToxicity => 'Oxigen toxicitas';

  @override
  String get diveLog_detail_section_sacByCylinder => 'SAC palackonkent';

  @override
  String get diveLog_detail_section_sacRateBySegment =>
      'SAC ertek szakaszonkent';

  @override
  String get diveLog_detail_section_tags => 'Cimkek';

  @override
  String get diveLog_detail_section_tanks => 'Palackok';

  @override
  String get diveLog_detail_section_tide => 'Arapaly';

  @override
  String get diveLog_detail_section_trainingSignature => 'Kepzesi alairas';

  @override
  String get diveLog_detail_section_weight => 'Suly';

  @override
  String get diveLog_detail_signatureDescription =>
      'Koppintson az oktatoi ellenorzes hozzaadasahoz ehhez a kepzesi meruleshez';

  @override
  String get diveLog_detail_soloDive =>
      'Solo merules vagy nincsenek buddy-k rogzitve';

  @override
  String diveLog_detail_speciesCount(Object count) {
    return '$count faj';
  }

  @override
  String get diveLog_detail_stat_bottomTime => 'Fenekido';

  @override
  String get diveLog_detail_stat_maxDepth => 'Max melyseg';

  @override
  String get diveLog_detail_stat_runtime => 'Futasido';

  @override
  String get diveLog_detail_stat_waterTemp => 'Viz hom.';

  @override
  String diveLog_detail_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'cimke',
      one: 'cimke',
    );
    return '$count $_temp0';
  }

  @override
  String diveLog_detail_tankCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'palack',
      one: 'palack',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_tideCalculated => 'Arapaly modellbol szamitva';

  @override
  String get diveLog_detail_tooltip_addToFavorites =>
      'Hozzaadas a kedvencekhez';

  @override
  String get diveLog_detail_tooltip_edit => 'Szerkesztes';

  @override
  String get diveLog_detail_tooltip_editDive => 'Merules szerkesztese';

  @override
  String get diveLog_detail_tooltip_exportProfileImage =>
      'Profil exportalasa kepkent';

  @override
  String get diveLog_detail_tooltip_removeFromFavorites =>
      'Eltavolitas a kedvencekbol';

  @override
  String get diveLog_detail_tooltip_viewFullscreen => 'Teljes kepernyo';

  @override
  String get diveLog_detail_viewSite => 'Merulohely megtekintese';

  @override
  String get diveLog_diveMode_ccrDescription =>
      'Zart koru visszalelegezteto allando ppO₂-vel';

  @override
  String get diveLog_diveMode_ocDescription =>
      'Standard nyilt koru buvarmerules palackokkal';

  @override
  String get diveLog_diveMode_scrDescription =>
      'Felig zart visszalelegezteto valtozo ppO₂-vel';

  @override
  String get diveLog_diveMode_title => 'Merulesi mod';

  @override
  String get diveLog_editSighting_count => 'Darab';

  @override
  String get diveLog_editSighting_notes => 'Jegyzetek';

  @override
  String get diveLog_editSighting_notesHint => 'Meret, viselkedes, helyszin...';

  @override
  String get diveLog_editSighting_remove => 'Eltavolitas';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return '$name eltavolitasa errol a merulesrol?';
  }

  @override
  String get diveLog_editSighting_removeTitle => 'Eszleles eltavolitasa?';

  @override
  String get diveLog_editSighting_save => 'Valtozasok mentese';

  @override
  String get diveLog_edit_add => 'Hozzaadas';

  @override
  String get diveLog_edit_addCustomField => 'Add Field';

  @override
  String get diveLog_edit_addTank => 'Palack hozzaadasa';

  @override
  String get diveLog_edit_addWeightEntry => 'Suly bevetel hozzaadasa';

  @override
  String diveLog_edit_addedGps(Object name) {
    return 'GPS hozzaadva: $name';
  }

  @override
  String get diveLog_edit_appBarEdit => 'Merules szerkesztese';

  @override
  String get diveLog_edit_appBarNew => 'Merules rogzitese';

  @override
  String get diveLog_edit_cancel => 'Megse';

  @override
  String get diveLog_edit_clearAllEquipment => 'Osszes torlese';

  @override
  String diveLog_edit_createdSite(Object name) {
    return 'Letrehozott merulohely: $name';
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
    return 'Idotartam: $minutes min';
  }

  @override
  String get diveLog_edit_equipmentHint =>
      'Koppintson a \"Keszlet hasznalata\" vagy \"Hozzaadas\" gombra a felszereles kivalasztasahoz';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return 'Hiba a merules tipusok betoltesekor: $error';
  }

  @override
  String get diveLog_edit_gettingLocation => 'Helymeghatározás...';

  @override
  String get diveLog_edit_headerNew => 'Uj merules rogzitese';

  @override
  String get diveLog_edit_label_airTemp => 'Levego hom.';

  @override
  String get diveLog_edit_label_altitude => 'Magassag';

  @override
  String get diveLog_edit_label_avgDepth => 'Atlag melyseg';

  @override
  String get diveLog_edit_label_bottomTime => 'Fenekido';

  @override
  String get diveLog_edit_label_currentDirection => 'Aramlat iranya';

  @override
  String get diveLog_edit_label_currentStrength => 'Aramlat erossege';

  @override
  String get diveLog_edit_label_diveType => 'Merules tipusa';

  @override
  String get diveLog_edit_label_entryMethod => 'Beszallasi mod';

  @override
  String get diveLog_edit_label_exitMethod => 'Kiszallasi mod';

  @override
  String get diveLog_edit_label_maxDepth => 'Max melyseg';

  @override
  String get diveLog_edit_label_runtime => 'Futasido';

  @override
  String get diveLog_edit_label_surfacePressure => 'Felszini nyomas';

  @override
  String get diveLog_edit_label_swellHeight => 'Hullammagassag';

  @override
  String get diveLog_edit_label_type => 'Tipus';

  @override
  String get diveLog_edit_label_visibility => 'Latasvisszonyok';

  @override
  String get diveLog_edit_label_waterTemp => 'Viz hom.';

  @override
  String get diveLog_edit_label_waterType => 'Viz tipusa';

  @override
  String get diveLog_edit_marineLifeHint =>
      'Koppintson a \"Hozzaadas\" gombra az eszlelesek rogzitesehez';

  @override
  String get diveLog_edit_nearbySitesFirst => 'Kozeli helyek elol';

  @override
  String get diveLog_edit_noEquipmentSelected =>
      'Nincs kivalasztott felszereles';

  @override
  String get diveLog_edit_noMarineLife => 'Nincs rogzitett tengeri elet';

  @override
  String get diveLog_edit_notSpecified => 'Nincs megadva';

  @override
  String get diveLog_edit_notesHint =>
      'Jegyzetek hozzaadasa ehhez a meruleshez...';

  @override
  String get diveLog_edit_save => 'Mentes';

  @override
  String get diveLog_edit_saveAsSet => 'Mentes keszletkent';

  @override
  String diveLog_edit_saveAsSetDialog_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'targy',
      one: 'targy',
    );
    return '$count $_temp0 mentese uj felszereléskészletként.';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description => 'Leiras (opcionalis)';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint =>
      'pl. Konnyu felszereles meleg vizhez';

  @override
  String diveLog_edit_saveAsSetDialog_error(Object error) {
    return 'Hiba a keszlet letrehozasakor: $error';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_setName => 'Keszlet neve';

  @override
  String get diveLog_edit_saveAsSetDialog_setNameHint => 'pl. Tropusi merules';

  @override
  String diveLog_edit_saveAsSetDialog_success(Object name) {
    return '\"$name\" felszereléskészlet letrehozva';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title =>
      'Mentes felszereléskészletként';

  @override
  String get diveLog_edit_saveAsSetDialog_validation =>
      'Kerjuk adjon meg egy keszletnevet';

  @override
  String get diveLog_edit_section_conditions => 'Korulmenyek';

  @override
  String get diveLog_edit_section_customFields => 'Custom Fields';

  @override
  String get diveLog_edit_section_depthDuration => 'Melyseg es idotartam';

  @override
  String get diveLog_edit_section_diveCenter => 'Merulocentrum';

  @override
  String get diveLog_edit_section_diveSite => 'Merulohely';

  @override
  String get diveLog_edit_section_entryTime => 'Beszallas ideje';

  @override
  String get diveLog_edit_section_equipment => 'Felszereles';

  @override
  String get diveLog_edit_section_exitTime => 'Kiszallas ideje';

  @override
  String get diveLog_edit_section_marineLife => 'Tengeri elet';

  @override
  String get diveLog_edit_section_notes => 'Jegyzetek';

  @override
  String get diveLog_edit_section_rating => 'Ertekeles';

  @override
  String get diveLog_edit_section_tags => 'Cimkek';

  @override
  String diveLog_edit_section_tanks(Object count) {
    return 'Palackok ($count)';
  }

  @override
  String get diveLog_edit_section_trainingCourse => 'Kepzesi tanfolyam';

  @override
  String get diveLog_edit_section_trip => 'Ut';

  @override
  String get diveLog_edit_section_weight => 'Suly';

  @override
  String get diveLog_edit_select => 'Kivalasztas';

  @override
  String get diveLog_edit_selectDiveCenter => 'Merulocentrum kivalasztasa';

  @override
  String get diveLog_edit_selectDiveSite => 'Merulohely kivalasztasa';

  @override
  String get diveLog_edit_selectTrip => 'Ut kivalasztasa';

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Fenekido kiszamitva: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Hiba a merules mentesekor: $error';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'Nincs elerheto merulesi profil adat';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Nem sikerult a fenekidot kiszamitani a profilbol';

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return 'Felszini szunet: $interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint =>
      'Standard: 1013 mbar tengerszinten';

  @override
  String get diveLog_edit_tooltip_calculateFromProfile =>
      'Szamitas a merulesi profilbol';

  @override
  String get diveLog_edit_tooltip_clearDiveCenter => 'Merulocentrum torlese';

  @override
  String get diveLog_edit_tooltip_clearSite => 'Merulohely torlese';

  @override
  String get diveLog_edit_tooltip_clearTrip => 'Ut torlese';

  @override
  String get diveLog_edit_tooltip_removeEquipment => 'Felszereles eltavolitasa';

  @override
  String get diveLog_edit_tooltip_removeSighting => 'Eszleles eltavolitasa';

  @override
  String get diveLog_edit_tooltip_removeWeight => 'Eltavolitas';

  @override
  String get diveLog_edit_trainingCourseHint =>
      'Merules osszekapcsolasa egy kepzesi tanfolyammal';

  @override
  String diveLog_edit_tripSuggested(Object name) {
    return 'Javasolt: $name';
  }

  @override
  String get diveLog_edit_tripUse => 'Hasznalas';

  @override
  String get diveLog_edit_useSet => 'Keszlet hasznalata';

  @override
  String diveLog_edit_weightTotal(Object total) {
    return 'Osszes: $total';
  }

  @override
  String get diveLog_emptyFiltered_clearFilters => 'Szurok torlese';

  @override
  String get diveLog_emptyFiltered_subtitle =>
      'Probalja modositani vagy torolni a szuroket';

  @override
  String get diveLog_emptyFiltered_title =>
      'Nincs a szuroknek megfelelo merules';

  @override
  String get diveLog_empty_logFirstDive => 'Rogzitse az elso meruleset';

  @override
  String get diveLog_empty_subtitle =>
      'Koppintson az alabbi gombra az elso merules rogzitesehez';

  @override
  String get diveLog_empty_title => 'Meg nincs rogzitett merules';

  @override
  String get diveLog_equipmentPicker_addFromTab =>
      'Adjon hozza felszerelest a Felszereles fulon';

  @override
  String get diveLog_equipmentPicker_allSelected =>
      'Minden felszereles mar ki van valasztva';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return 'Hiba a felszereles betoltesekor: $error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => 'Meg nincs felszereles';

  @override
  String get diveLog_equipmentPicker_removeToAdd =>
      'Tavolitson el elemeket masok hozzaadasahoz';

  @override
  String get diveLog_equipmentPicker_title => 'Felszereles hozzaadasa';

  @override
  String get diveLog_equipmentSetPicker_createHint =>
      'Keszleteket a Felszereles > Keszletek menuben hozhat letre';

  @override
  String get diveLog_equipmentSetPicker_emptySet => 'Ures keszlet';

  @override
  String get diveLog_equipmentSetPicker_errorItems =>
      'Hiba az elemek betoltesekor';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return 'Hiba a felszereléskészletek betoltesekor: $error';
  }

  @override
  String get diveLog_equipmentSetPicker_loading => 'Betoltes...';

  @override
  String get diveLog_equipmentSetPicker_noSets =>
      'Meg nincsenek felszereléskészletek';

  @override
  String get diveLog_equipmentSetPicker_title =>
      'Felszereléskészlet hasznalata';

  @override
  String get diveLog_error_loadingDives => 'Hiba a merulesek betoltesekor';

  @override
  String get diveLog_error_retry => 'Ujra';

  @override
  String get diveLog_exportImage_captureFailed =>
      'Nem sikerult a kep rogzitese';

  @override
  String get diveLog_exportImage_generateFailed =>
      'Nem sikerult a kep letrehozasa';

  @override
  String get diveLog_exportImage_generatingPdf => 'PDF letrehozasa...';

  @override
  String get diveLog_exportImage_pdfSaved => 'PDF mentve';

  @override
  String get diveLog_exportImage_saveToFiles => 'Mentes fajlokba';

  @override
  String get diveLog_exportImage_saveToFilesDescription =>
      'Valasszon helyet a fajl mentesehez';

  @override
  String get diveLog_exportImage_saveToPhotos => 'Mentes fotokba';

  @override
  String get diveLog_exportImage_saveToPhotosDescription =>
      'Kep mentese a fotokonyvarba';

  @override
  String get diveLog_exportImage_savedToFiles => 'Kep mentve';

  @override
  String get diveLog_exportImage_savedToPhotos => 'Kep mentve a Fotokba';

  @override
  String get diveLog_exportImage_share => 'Megosztas';

  @override
  String get diveLog_exportImage_shareDescription =>
      'Megosztas mas alkalmazasokon keresztul';

  @override
  String get diveLog_exportImage_titleDetails =>
      'Merulesi reszletek kep exportalasa';

  @override
  String get diveLog_exportImage_titlePdf => 'PDF exportalas';

  @override
  String get diveLog_exportImage_titleProfile => 'Profil kep exportalasa';

  @override
  String get diveLog_export_csv => 'CSV';

  @override
  String get diveLog_export_csvDescription => 'Tablazatkezelo formatum';

  @override
  String get diveLog_export_exporting => 'Exportalas...';

  @override
  String diveLog_export_failed(Object error) {
    return 'Exportalas sikertelen: $error';
  }

  @override
  String get diveLog_export_pageAsImage => 'Oldal kepkent';

  @override
  String get diveLog_export_pageAsImageDescription =>
      'Kepernyokep a teljes merulesi reszletekrol';

  @override
  String get diveLog_export_pdfDescription =>
      'Nyomtathato merulesi naplo oldal';

  @override
  String get diveLog_export_pdfLogbookEntry => 'PDF naplo bejegyzes';

  @override
  String get diveLog_export_success => 'Merules sikeresen exportalva';

  @override
  String diveLog_export_titleDiveNumber(Object number) {
    return 'Merules #$number exportalasa';
  }

  @override
  String get diveLog_export_uddf => 'UDDF';

  @override
  String get diveLog_export_uddfDescription =>
      'Univerzalis merulesi adatformatum';

  @override
  String get diveLog_filterChip_clearAll => 'Osszes torlese';

  @override
  String get diveLog_filterChip_favorites => 'Kedvencek';

  @override
  String diveLog_filterChip_from(Object date) {
    return 'Ettol: $date';
  }

  @override
  String diveLog_filterChip_until(Object date) {
    return 'Eddig: $date';
  }

  @override
  String get diveLog_filter_allSites => 'Osszes merulohely';

  @override
  String get diveLog_filter_allTypes => 'Osszes tipus';

  @override
  String get diveLog_filter_apply => 'Szurok alkalmazasa';

  @override
  String get diveLog_filter_buddyHint => 'Kereses buddy nev alapjan';

  @override
  String get diveLog_filter_buddyName => 'Buddy neve';

  @override
  String get diveLog_filter_clearAll => 'Osszes torlese';

  @override
  String get diveLog_filter_clearDates => 'Datumok torlese';

  @override
  String get diveLog_filter_clearRating => 'Ertekeles szuro torlese';

  @override
  String get diveLog_filter_dateSeparator => 'tol';

  @override
  String get diveLog_filter_endDate => 'Zaras datuma';

  @override
  String get diveLog_filter_errorLoadingSites =>
      'Hiba a merulohelyek betoltesekor';

  @override
  String get diveLog_filter_errorLoadingTags => 'Hiba a cimkek betoltesekor';

  @override
  String get diveLog_filter_favoritesOnly => 'Csak kedvencek';

  @override
  String get diveLog_filter_gasAir => 'Levego (21%)';

  @override
  String get diveLog_filter_gasAll => 'Osszes';

  @override
  String get diveLog_filter_gasNitrox => 'Nitrox (>21%)';

  @override
  String get diveLog_filter_max => 'Max';

  @override
  String get diveLog_filter_min => 'Min';

  @override
  String get diveLog_filter_noTagsYet => 'Meg nincsenek letrehozott cimkek';

  @override
  String get diveLog_filter_sectionBuddy => 'Buddy';

  @override
  String get diveLog_filter_sectionDateRange => 'Datumtartomany';

  @override
  String get diveLog_filter_sectionDepthRange => 'Melyseg tartomany (meter)';

  @override
  String get diveLog_filter_sectionDiveSite => 'Merulohely';

  @override
  String get diveLog_filter_sectionDiveType => 'Merules tipusa';

  @override
  String get diveLog_filter_sectionDuration => 'Idotartam (perc)';

  @override
  String get diveLog_filter_sectionGasMix => 'Gazkeverek (O₂%)';

  @override
  String get diveLog_filter_sectionMinRating => 'Minimum ertekeles';

  @override
  String get diveLog_filter_sectionTags => 'Cimkek';

  @override
  String get diveLog_filter_showOnlyFavorites =>
      'Csak kedvenc merulesek mutatasa';

  @override
  String get diveLog_filter_startDate => 'Kezdes datuma';

  @override
  String get diveLog_filter_title => 'Merulesek szurese';

  @override
  String get diveLog_filter_tooltip_close => 'Szuro bezarasa';

  @override
  String get diveLog_fullscreenProfile_close => 'Teljes kepernyo bezarasa';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Merules #$number profil';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Felszallasi sebesseg';

  @override
  String get diveLog_legend_label_ceiling => 'Plafon';

  @override
  String get diveLog_legend_label_depth => 'Melyseg';

  @override
  String get diveLog_legend_label_events => 'Esemenyek';

  @override
  String get diveLog_legend_label_gasDensity => 'Gaz suruseg';

  @override
  String get diveLog_legend_label_gasSwitches => 'Gazcserelesek';

  @override
  String get diveLog_legend_label_gfPercent => 'GF%';

  @override
  String get diveLog_legend_label_heartRate => 'Pulzus';

  @override
  String get diveLog_legend_label_maxDepth => 'Max melyseg';

  @override
  String get diveLog_legend_label_meanDepth => 'Atlag melyseg';

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
  String get diveLog_legend_label_pressure => 'Nyomas';

  @override
  String get diveLog_legend_label_pressureThresholds => 'Nyomas kuszobertek';

  @override
  String get diveLog_legend_label_sacRate => 'SAC ertek';

  @override
  String get diveLog_legend_label_surfaceGf => 'Felszini GF';

  @override
  String get diveLog_legend_label_temp => 'Hom.';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Merulesi terkep';

  @override
  String get diveLog_listPage_compactTitle => 'Merulesek';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get diveLog_listPage_fab_logDive => 'Merules rogzitese';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Specialis kereses';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Merules szamozas';

  @override
  String get diveLog_listPage_searchFieldLabel => 'Merulesek keresese...';

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return 'Nem talalhato merules: \"$query\"';
  }

  @override
  String get diveLog_listPage_searchSuggestion =>
      'Kereses merulohely, buddy vagy jegyzetek alapjan';

  @override
  String get diveLog_listPage_title => 'Merulesi naplo';

  @override
  String get diveLog_listPage_tooltip_back => 'Vissza';

  @override
  String get diveLog_listPage_tooltip_backToDiveList =>
      'Vissza a merulesek listajahoz';

  @override
  String get diveLog_listPage_tooltip_clearSearch => 'Kereses torlese';

  @override
  String get diveLog_listPage_tooltip_filterDives => 'Merulesek szurese';

  @override
  String get diveLog_listPage_tooltip_listView => 'Lista nezet';

  @override
  String get diveLog_listPage_tooltip_mapView => 'Terkep nezet';

  @override
  String get diveLog_listPage_tooltip_searchDives => 'Merulesek keresese';

  @override
  String get diveLog_listPage_tooltip_sort => 'Rendezes';

  @override
  String get diveLog_listPage_unknownSite => 'Ismeretlen merulohely';

  @override
  String get diveLog_map_emptySubtitle =>
      'Rogzitsen meruleseket helyadatokkal, hogy lasson tevekenyseget a terkepen';

  @override
  String get diveLog_map_emptyTitle =>
      'Nincs megjelenitendo merulesi tevekenyseg';

  @override
  String diveLog_map_errorLoading(Object error) {
    return 'Hiba a merulesi adatok betoltesekor: $error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => 'Osszes merulohely mutatasa';

  @override
  String get diveLog_numbering_actions => 'Muveletek';

  @override
  String get diveLog_numbering_allCorrect =>
      'Minden merules helyesen szamozott';

  @override
  String get diveLog_numbering_assignMissing => 'Hianyzo szamok kiosztasa';

  @override
  String get diveLog_numbering_assignMissingDesc =>
      'Szamozatlan merulesek szamozasa az utolso szamozott merules utan';

  @override
  String get diveLog_numbering_close => 'Bezaras';

  @override
  String get diveLog_numbering_gapsDetected => 'Hezagok eszlelve';

  @override
  String get diveLog_numbering_issuesDetected => 'Problemak eszlelve';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '$count hianyzik';
  }

  @override
  String get diveLog_numbering_renumberAll => 'Osszes merules ujraszamozasa';

  @override
  String get diveLog_numbering_renumberAllDesc =>
      'Sorszamok kiosztasa datum/ido alapjan';

  @override
  String get diveLog_numbering_renumberDialog_cancel => 'Megse';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      'Ez az osszes merulest idorendben ujraszamozza a beszallasi datum/ido alapjan. Ez a muvelet nem vonhato vissza.';

  @override
  String get diveLog_numbering_renumberDialog_renumber => 'Ujraszamozas';

  @override
  String get diveLog_numbering_renumberDialog_startFrom => 'Kezdo szam';

  @override
  String get diveLog_numbering_renumberDialog_title =>
      'Osszes merules ujraszamozasa';

  @override
  String get diveLog_numbering_snackbar_assigned =>
      'Hianyzo merulesi szamok kiosztva';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return 'Minden merules ujraszamozva #$number-tol';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '$total osszes merules - $numbered szamozott';
  }

  @override
  String get diveLog_numbering_title => 'Merules szamozas';

  @override
  String diveLog_numbering_unnumberedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 szam nelkul';
  }

  @override
  String get diveLog_o2tox_badge_critical => 'KRITIKUS';

  @override
  String get diveLog_o2tox_badge_warning => 'FIGYELMEZTETÉS';

  @override
  String diveLog_o2tox_cnsBadgeLabel(Object value) {
    return 'CNS $value';
  }

  @override
  String get diveLog_o2tox_cnsOxygenClock => 'CNS oxigen ora';

  @override
  String diveLog_o2tox_deltaDive(Object value) {
    return '+$value% ezen a merulesen';
  }

  @override
  String get diveLog_o2tox_details => 'Reszletek';

  @override
  String get diveLog_o2tox_label_maxPpO2 => 'Max ppO2';

  @override
  String get diveLog_o2tox_label_maxPpO2Depth => 'Max ppO2 melyseg';

  @override
  String get diveLog_o2tox_label_timeAbove14 => '1,4 bar feletti ido';

  @override
  String get diveLog_o2tox_label_timeAbove16 => '1,6 bar feletti ido';

  @override
  String get diveLog_o2tox_ofDailyLimit => 'a napi limitbol';

  @override
  String get diveLog_o2tox_oxygenToleranceUnits => 'Oxigen tolerancia egysegek';

  @override
  String diveLog_o2tox_semantics_cnsBadge(Object value) {
    return 'CNS oxigén toxicitás $value';
  }

  @override
  String get diveLog_o2tox_semantics_criticalWarning =>
      'Kritikus oxigen toxicitas figyelmeztetés';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return 'Oxigén tolerancia egységek: $value, $percent százalék a napi limitből';
  }

  @override
  String get diveLog_o2tox_semantics_warning =>
      'Oxigen toxicitas figyelmeztetés';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return 'Kezdet: $value%';
  }

  @override
  String get diveLog_o2tox_title => 'Oxigen toxicitas';

  @override
  String get diveLog_playbackStats_deco => 'DEKO';

  @override
  String get diveLog_playbackStats_depth => 'Melyseg';

  @override
  String get diveLog_playbackStats_header => 'Elo statisztikak';

  @override
  String get diveLog_playbackStats_heartRate => 'Pulzus';

  @override
  String get diveLog_playbackStats_ndl => 'NDL';

  @override
  String get diveLog_playbackStats_ppO2 => 'ppO₂';

  @override
  String get diveLog_playbackStats_pressure => 'Nyomas';

  @override
  String get diveLog_playbackStats_temp => 'Hom.';

  @override
  String get diveLog_playback_sliderLabel => 'Lejatszasi pozicio';

  @override
  String diveLog_playback_speed_label(Object speed) {
    return '${speed}x';
  }

  @override
  String get diveLog_playback_stepThrough => 'Leptetett lejatszas';

  @override
  String get diveLog_playback_tooltip_back10 => 'Vissza 10 masodpercet';

  @override
  String get diveLog_playback_tooltip_exit => 'Kilépés a lejatszas modbol';

  @override
  String get diveLog_playback_tooltip_forward10 => 'Elore 10 masodpercet';

  @override
  String get diveLog_playback_tooltip_pause => 'Szunet';

  @override
  String get diveLog_playback_tooltip_play => 'Lejatszas';

  @override
  String get diveLog_playback_tooltip_skipEnd => 'Ugras a vegere';

  @override
  String get diveLog_playback_tooltip_skipStart => 'Ugras az elejere';

  @override
  String get diveLog_playback_tooltip_speed => 'Lejatszasi sebesseg';

  @override
  String get diveLog_profileSelector_badge_primary => 'Elsodleges';

  @override
  String get diveLog_profileSelector_label_diveComputers =>
      'Merulesszamitogepek';

  @override
  String diveLog_profile_axisDepth(Object unit) {
    return 'Melyseg ($unit)';
  }

  @override
  String get diveLog_profile_axisTime => 'Ido (min)';

  @override
  String get diveLog_profile_emptyState => 'Nincs merulesi profil adat';

  @override
  String get diveLog_profile_rightAxis_none => 'Nincs';

  @override
  String get diveLog_profile_semantics_changeRightAxis =>
      'Jobb tengely metrika valtoztatasa';

  @override
  String get diveLog_profile_semantics_chart =>
      'Merulesi profil diagram, csipje ossze a nagyitashoz';

  @override
  String get diveLog_profile_tooltip_moreOptions =>
      'Tovabbi diagram lehetosegek';

  @override
  String get diveLog_profile_tooltip_resetZoom => 'Nagyitas visszaallitasa';

  @override
  String get diveLog_profile_tooltip_zoomIn => 'Nagyitas';

  @override
  String get diveLog_profile_tooltip_zoomOut => 'Kicsinyites';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return 'Nagyitas: ${level}x - Csipje ossze vagy gorgetjen a nagyitashoz, huzza a panoramazashoz';
  }

  @override
  String get diveLog_rangeSelection_exitRange => 'Tartomany bezarasa';

  @override
  String get diveLog_rangeSelection_selectRange => 'Tartomany kivalasztasa';

  @override
  String get diveLog_rangeSelection_semantics_adjust =>
      'Tartomany kivalasztas modositasa';

  @override
  String get diveLog_rangeStats_header_avg => 'Atlag';

  @override
  String get diveLog_rangeStats_header_max => 'Max';

  @override
  String get diveLog_rangeStats_header_min => 'Min';

  @override
  String get diveLog_rangeStats_label_depth => 'Melyseg';

  @override
  String get diveLog_rangeStats_label_heartRate => 'Pulzus';

  @override
  String get diveLog_rangeStats_label_pressure => 'Nyomas';

  @override
  String get diveLog_rangeStats_label_temp => 'Hom.';

  @override
  String get diveLog_rangeStats_title => 'Tartomany elemzes';

  @override
  String get diveLog_rangeStats_tooltip_close => 'Tartomany elemzes bezarasa';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return 'Szamitott hurok FO₂: $value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => 'pl. 0,33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => 'Adagolasi arany';

  @override
  String get diveLog_scr_label_assumedVo2 => 'Feltételezett VO₂';

  @override
  String get diveLog_scr_label_avg => 'Atlag';

  @override
  String get diveLog_scr_label_injectionRate => 'Adagolasi sebesseg';

  @override
  String get diveLog_scr_label_max => 'Max';

  @override
  String get diveLog_scr_label_min => 'Min';

  @override
  String get diveLog_scr_label_orificeSize => 'Fuvoka meret';

  @override
  String get diveLog_scr_sectionCmf => 'CMF parameterek';

  @override
  String get diveLog_scr_sectionEscr => 'ESCR parameterek';

  @override
  String get diveLog_scr_sectionMeasuredLoopO2 => 'Mert hurok O₂ (opcionalis)';

  @override
  String get diveLog_scr_sectionPascr => 'PASCR parameterek';

  @override
  String get diveLog_scr_sectionScrType => 'SCR tipus';

  @override
  String get diveLog_scr_sectionSupplyGas => 'Ellato gaz';

  @override
  String get diveLog_scr_title => 'SCR beallitasok';

  @override
  String get diveLog_search_allCenters => 'Osszes kozpont';

  @override
  String get diveLog_search_allTrips => 'Osszes utazas';

  @override
  String get diveLog_search_appBar => 'Reszletes kereses';

  @override
  String get diveLog_search_cancel => 'Megse';

  @override
  String get diveLog_search_clearAll => 'Osszes torlese';

  @override
  String get diveLog_search_customFieldKey => 'Custom Field Key';

  @override
  String get diveLog_search_customFieldValue => 'Value contains...';

  @override
  String get diveLog_search_end => 'Vege';

  @override
  String get diveLog_search_errorLoadingCenters =>
      'Hiba a merulokozpontok betoltesekor';

  @override
  String get diveLog_search_errorLoadingDiveTypes =>
      'Hiba a merülés típusok betöltésekor';

  @override
  String get diveLog_search_errorLoadingTrips =>
      'Hiba az utazasok betoltesekor';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_depthRange => 'Melyseg tartomany (m)';

  @override
  String get diveLog_search_label_diveCenter => 'Merulokozpont';

  @override
  String get diveLog_search_label_diveSite => 'Merulohely';

  @override
  String get diveLog_search_label_diveType => 'Merules tipus';

  @override
  String get diveLog_search_label_durationRange => 'Idotartam tartomany (min)';

  @override
  String get diveLog_search_label_trip => 'Utazas';

  @override
  String get diveLog_search_search => 'Kereses';

  @override
  String get diveLog_search_section_conditions => 'Korulmenyek';

  @override
  String get diveLog_search_section_dateRange => 'Datumtartomany';

  @override
  String get diveLog_search_section_gasEquipment => 'Gaz es felszereles';

  @override
  String get diveLog_search_section_location => 'Helyszin';

  @override
  String get diveLog_search_section_organization => 'Szervezet';

  @override
  String get diveLog_search_section_social => 'Kozossegi';

  @override
  String get diveLog_search_start => 'Kezdes';

  @override
  String diveLog_selection_countSelected(Object count) {
    return '$count kivalasztva';
  }

  @override
  String get diveLog_selection_tooltip_delete => 'Kivalasztottak torlese';

  @override
  String get diveLog_selection_tooltip_deselectAll =>
      'Osszes kivalasztas megszuntetese';

  @override
  String get diveLog_selection_tooltip_edit => 'Kivalasztottak szerkesztese';

  @override
  String get diveLog_selection_tooltip_exit => 'Kivalasztas bezarasa';

  @override
  String get diveLog_selection_tooltip_export => 'Kivalasztottak exportalasa';

  @override
  String get diveLog_selection_tooltip_selectAll => 'Osszes kivalasztasa';

  @override
  String get diveLog_sighting_add => 'Hozzaadas';

  @override
  String get diveLog_sighting_cancel => 'Megse';

  @override
  String get diveLog_sighting_notesHint => 'pl. meret, viselkedes, helyszin...';

  @override
  String get diveLog_sighting_notesOptional => 'Megjegyzesek (opcionalis)';

  @override
  String get diveLog_sitePicker_addDiveSite => 'Merulohely hozzaadasa';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return '$distance km tavolsagra';
  }

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return '$distance m tavolsagra';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return 'Hiba a helyszinek betoltesekor: $error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => 'Uj merulohely';

  @override
  String get diveLog_sitePicker_noSites => 'Meg nincsenek merulohelyek';

  @override
  String get diveLog_sitePicker_sortedByDistance => 'Tavolsag szerint rendezve';

  @override
  String get diveLog_sitePicker_title => 'Merulohely kivalasztasa';

  @override
  String get diveLog_sort_title => 'Merulesek rendezese';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return '\"$name\" hozzaadasa uj fajkent';
  }

  @override
  String get diveLog_speciesPicker_noResults => 'Nem talalhato faj';

  @override
  String get diveLog_speciesPicker_noSpecies => 'Nincsenek elerheto fajok';

  @override
  String get diveLog_speciesPicker_searchHint => 'Fajok keresese...';

  @override
  String get diveLog_speciesPicker_title => 'Tengeri elet hozzaadasa';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch => 'Kereses torlese';

  @override
  String get diveLog_summary_action_importComputer =>
      'Importalas szamitogeproL';

  @override
  String get diveLog_summary_action_logDive => 'Merules rogzitese';

  @override
  String get diveLog_summary_action_viewStats => 'Statisztikak megtekintese';

  @override
  String diveLog_summary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_summary_overview => 'Attekintes';

  @override
  String get diveLog_summary_record_coldest => 'Leghidegebb merules';

  @override
  String get diveLog_summary_record_deepest => 'Legmelyebb merules';

  @override
  String get diveLog_summary_record_longest => 'Leghosszabb merules';

  @override
  String get diveLog_summary_record_warmest => 'Legmelegebb merules';

  @override
  String get diveLog_summary_section_mostVisited =>
      'Leglátogatottabb helyszinek';

  @override
  String get diveLog_summary_section_quickActions => 'Gyorsmuveletek';

  @override
  String get diveLog_summary_section_records => 'Szemelyes rekordok';

  @override
  String get diveLog_summary_selectDive =>
      'Valasszon egy merulest a listabol a reszletek megtekIntesehez';

  @override
  String get diveLog_summary_stat_avgMaxDepth => 'Atl. max melyseg';

  @override
  String get diveLog_summary_stat_avgWaterTemp => 'Atl. vizhomerseklet';

  @override
  String get diveLog_summary_stat_diveSites => 'Merulohelyek';

  @override
  String get diveLog_summary_stat_diveTime => 'Merulesido';

  @override
  String get diveLog_summary_stat_maxDepth => 'Max melyseg';

  @override
  String get diveLog_summary_stat_totalDives => 'Osszes merules';

  @override
  String get diveLog_summary_title => 'Merulesnaplo osszefoglalo';

  @override
  String get diveLog_tank_label_endPressure => 'Vegnyomas';

  @override
  String get diveLog_tank_label_he => 'He';

  @override
  String get diveLog_tank_label_material => 'Anyag';

  @override
  String get diveLog_tank_label_n2 => 'N2';

  @override
  String get diveLog_tank_label_o2 => 'O2';

  @override
  String get diveLog_tank_label_role => 'Szerep';

  @override
  String get diveLog_tank_label_startPressure => 'Kezdonyomas';

  @override
  String get diveLog_tank_label_tankPreset => 'Palack elore beallitas';

  @override
  String get diveLog_tank_label_volume => 'Terfogat';

  @override
  String get diveLog_tank_label_workingPressure => 'Uzemi ny.';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Gazkeverek';

  @override
  String get diveLog_tank_selectPreset => 'Valasszon elore beallitast...';

  @override
  String diveLog_tank_title(Object number) {
    return '$number. palack';
  }

  @override
  String get diveLog_tank_tooltip_remove => 'Palack eltavolitasa';

  @override
  String get diveLog_tissue_label_ceiling => 'Plafon';

  @override
  String get diveLog_tissue_label_gf => 'GF';

  @override
  String get diveLog_tissue_label_ndl => 'NDL';

  @override
  String get diveLog_tissue_label_tts => 'TTS';

  @override
  String get diveLog_tissue_legend_he => 'He';

  @override
  String get diveLog_tissue_legend_mValue => '100% M-ertek';

  @override
  String get diveLog_tissue_legend_n2 => 'N₂';

  @override
  String get diveLog_tissue_title => 'Szovettelitodes';

  @override
  String get diveLog_tooltip_ceiling => 'Plafon';

  @override
  String get diveLog_tooltip_density => 'Suruseg';

  @override
  String get diveLog_tooltip_depth => 'Melyseg';

  @override
  String get diveLog_tooltip_gfPercent => 'GF%';

  @override
  String get diveLog_tooltip_hr => 'Pulzus';

  @override
  String get diveLog_tooltip_marker => 'Jelolo';

  @override
  String get diveLog_tooltip_mean => 'Atlag';

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
  String get diveLog_tooltip_press => 'Nyomas';

  @override
  String get diveLog_tooltip_rate => 'Sebessg';

  @override
  String get diveLog_tooltip_sac => 'SAC';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Hom.';

  @override
  String get diveLog_tooltip_time => 'Ido';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get divePlanner_action_addTank => 'Palack hozzáadása';

  @override
  String get divePlanner_action_convertToDive => 'Átalakítás merüléssé';

  @override
  String get divePlanner_action_editTank => 'Palack szerkesztése';

  @override
  String get divePlanner_action_moreOptions => 'További lehetőségek';

  @override
  String get divePlanner_action_quickPlan => 'Gyors tervezés';

  @override
  String get divePlanner_action_renamePlan => 'Terv átnevezése';

  @override
  String get divePlanner_action_reset => 'Visszaállítás';

  @override
  String get divePlanner_action_resetPlan => 'Terv visszaállítása';

  @override
  String get divePlanner_action_savePlan => 'Terv mentése';

  @override
  String get divePlanner_error_cannotConvert =>
      'Nem lehet átalakítani: a tervnek kritikus figyelmeztetései vannak';

  @override
  String get divePlanner_field_hePercent => 'He %';

  @override
  String get divePlanner_field_name => 'Név';

  @override
  String get divePlanner_field_o2Percent => 'O₂ %';

  @override
  String get divePlanner_field_planName => 'Terv neve';

  @override
  String get divePlanner_field_role => 'Szerep';

  @override
  String divePlanner_field_startPressure(Object pressureSymbol) {
    return 'Kezdő ($pressureSymbol)';
  }

  @override
  String divePlanner_field_volume(Object volumeSymbol) {
    return 'Térfogat ($volumeSymbol)';
  }

  @override
  String get divePlanner_hint_tankName => 'Add meg a palack nevét';

  @override
  String get divePlanner_label_altitude => 'Magasság:';

  @override
  String get divePlanner_label_belowMinReserve => 'Minimum tartalék alatt';

  @override
  String get divePlanner_label_ceiling => 'Plafon';

  @override
  String get divePlanner_label_consumption => 'Fogyasztás';

  @override
  String get divePlanner_label_deco => 'DEKO';

  @override
  String get divePlanner_label_decoSchedule => 'Dekompressziós menetrend';

  @override
  String get divePlanner_label_decompression => 'Dekompresszió';

  @override
  String divePlanner_label_depthAxis(Object depthSymbol) {
    return 'Mélység ($depthSymbol)';
  }

  @override
  String get divePlanner_label_diveProfile => 'Merülési profil';

  @override
  String get divePlanner_label_empty => 'ÜRES';

  @override
  String get divePlanner_label_gasConsumption => 'Gázfogyasztás';

  @override
  String get divePlanner_label_gfHigh => 'GF magas';

  @override
  String get divePlanner_label_gfLow => 'GF alacsony';

  @override
  String get divePlanner_label_max => 'Max';

  @override
  String get divePlanner_label_ndl => 'NDL';

  @override
  String get divePlanner_label_planSettings => 'Terv beállításai';

  @override
  String get divePlanner_label_remaining => 'Maradt';

  @override
  String get divePlanner_label_runtime => 'Futási idő';

  @override
  String get divePlanner_label_sacRate => 'SAC érték:';

  @override
  String get divePlanner_label_status => 'Státusz';

  @override
  String get divePlanner_label_tanks => 'Palackok';

  @override
  String get divePlanner_label_time => 'Idő';

  @override
  String get divePlanner_label_timeAxis => 'Idő (perc)';

  @override
  String get divePlanner_label_tts => 'TTS';

  @override
  String get divePlanner_label_used => 'Felhasznált';

  @override
  String get divePlanner_label_warnings => 'Figyelmeztetések';

  @override
  String get divePlanner_legend_ascent => 'Feljövés';

  @override
  String get divePlanner_legend_bottom => 'Fenék';

  @override
  String get divePlanner_legend_deco => 'Dekó';

  @override
  String get divePlanner_legend_descent => 'Leereszkedés';

  @override
  String get divePlanner_legend_safety => 'Biztonsági';

  @override
  String get divePlanner_message_addSegmentsForGas =>
      'Adj hozzá szakaszokat a gázvetítések megtekintéséhez';

  @override
  String get divePlanner_message_addSegmentsForProfile =>
      'Adj hozzá szakaszokat a merülési profil megtekintéséhez';

  @override
  String get divePlanner_message_convertingPlan =>
      'Terv átalakítása merüléssé...';

  @override
  String get divePlanner_message_noProfile => 'Nincs megjeleníthető profil';

  @override
  String get divePlanner_message_planSaved => 'Terv mentve';

  @override
  String get divePlanner_message_resetConfirmation =>
      'Biztosan vissza szeretnéd állítani a tervet?';

  @override
  String divePlanner_semantics_criticalWarning(Object message) {
    return 'Kritikus figyelmeztetés: $message';
  }

  @override
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  ) {
    return 'Dekó megálló $depth mélységben $duration időtartamra $gasMix keverékkel';
  }

  @override
  String divePlanner_semantics_gasConsumption(
    Object tankName,
    Object gasUsed,
    Object remaining,
    Object percent,
    Object warning,
  ) {
    return '$tankName: $gasUsed felhasznált, $remaining maradt, $percent használva$warning';
  }

  @override
  String divePlanner_semantics_profileChart(
    Object maxDepth,
    Object totalMinutes,
  ) {
    return 'Merülési terv, max mélység $maxDepth, összes idő $totalMinutes perc';
  }

  @override
  String divePlanner_semantics_warning(Object message) {
    return 'Figyelmeztetés: $message';
  }

  @override
  String get divePlanner_tab_plan => 'Terv';

  @override
  String get divePlanner_tab_profile => 'Profil';

  @override
  String get divePlanner_tab_results => 'Eredmények';

  @override
  String get divePlanner_warning_ascentRateHigh =>
      'Feljövési sebesség meghaladja a biztonságos limitet';

  @override
  String divePlanner_warning_ascentRateHighWithRate(Object rate) {
    return 'Feljövési sebesség $rate/perc meghaladja a biztonságos limitet';
  }

  @override
  String divePlanner_warning_belowMinReserve(Object reserve) {
    return 'Minimum tartalék alatt ($reserve)';
  }

  @override
  String get divePlanner_warning_cnsCritical => 'CNS% meghaladja a 100%-ot';

  @override
  String divePlanner_warning_cnsWarning(Object threshold) {
    return 'CNS% meghaladja a $threshold%-ot';
  }

  @override
  String get divePlanner_warning_endHigh =>
      'Ekvivalens narkotikus mélység túl magas';

  @override
  String divePlanner_warning_endHighWithDepth(Object depth) {
    return 'END $depth meghaladja a biztonságos limitet';
  }

  @override
  String divePlanner_warning_gasLow(Object threshold) {
    return 'Palack $threshold tartalék alatt';
  }

  @override
  String get divePlanner_warning_gasOut => 'Palack ki fog ürülni';

  @override
  String get divePlanner_warning_minGasViolation =>
      'Minimum gáz tartalék nem tartható fenn';

  @override
  String get divePlanner_warning_modViolation =>
      'Gázváltás kísérlet MOD felett';

  @override
  String get divePlanner_warning_ndlExceeded =>
      'Merülés dekompressziós kötelezettséggel jár';

  @override
  String get divePlanner_warning_otuWarning => 'OTU felhalmozódás magas';

  @override
  String divePlanner_warning_ppO2Critical(Object value) {
    return 'ppO₂ $value bar meghaladja a kritikus limitet';
  }

  @override
  String divePlanner_warning_ppO2High(Object value) {
    return 'ppO₂ $value bar meghaladja a munkálati limitet';
  }

  @override
  String get diveSites_detail_access_accessNotes =>
      'Megkozelitesi megjegyzesek';

  @override
  String get diveSites_detail_access_mooring => 'Kikotos';

  @override
  String get diveSites_detail_access_parking => 'Parkolas';

  @override
  String get diveSites_detail_altitude_elevation =>
      'Tengerszint feletti magassag';

  @override
  String get diveSites_detail_altitude_pressure => 'Nyomas';

  @override
  String get diveSites_detail_coordinatesCopied =>
      'Koordinatak masolva a vagolapra';

  @override
  String get diveSites_detail_deleteDialog_cancel => 'Megse';

  @override
  String get diveSites_detail_deleteDialog_confirm => 'Torles';

  @override
  String get diveSites_detail_deleteDialog_content =>
      'Biztosan torli ezt a helyszint? Ez a muvelet nem vonhato vissza.';

  @override
  String get diveSites_detail_deleteDialog_title => 'Helyszin torlese';

  @override
  String get diveSites_detail_deleteMenu_label => 'Torles';

  @override
  String get diveSites_detail_deleteSnackbar => 'Helyszin torolve';

  @override
  String get diveSites_detail_depth_maximum => 'Maximum';

  @override
  String get diveSites_detail_depth_minimum => 'Minimum';

  @override
  String get diveSites_detail_diveCount_one => '1 rogzitett merules';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '$count rogzitett merules';
  }

  @override
  String get diveSites_detail_diveCount_zero => 'Meg nincs rogzitett merules';

  @override
  String get diveSites_detail_editTooltip => 'Helyszin szerkesztese';

  @override
  String get diveSites_detail_editTooltipShort => 'Szerkesztes';

  @override
  String diveSites_detail_error_body(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get diveSites_detail_error_title => 'Hiba';

  @override
  String get diveSites_detail_loading_title => 'Betoltes...';

  @override
  String get diveSites_detail_location_country => 'Orszag';

  @override
  String get diveSites_detail_location_gpsCoordinates => 'GPS koordinatak';

  @override
  String get diveSites_detail_location_notSet => 'Nincs megadva';

  @override
  String get diveSites_detail_location_region => 'Regio';

  @override
  String get diveSites_detail_noDepthInfo => 'Nincs melyseg informacio';

  @override
  String get diveSites_detail_noDescription => 'Nincs leiras';

  @override
  String get diveSites_detail_noNotes => 'Nincsenek megjegyzesek';

  @override
  String get diveSites_detail_rating_notRated => 'Nincs ertekelesve';

  @override
  String diveSites_detail_rating_value(Object rating) {
    return '$rating az 5-bol';
  }

  @override
  String get diveSites_detail_section_access => 'Megkozelites es logisztika';

  @override
  String get diveSites_detail_section_altitude =>
      'Tengerszint feletti magassag';

  @override
  String get diveSites_detail_section_depthRange => 'Melyseg tartomany';

  @override
  String get diveSites_detail_section_description => 'Leiras';

  @override
  String get diveSites_detail_section_difficultyLevel => 'Nehezssgi szint';

  @override
  String get diveSites_detail_section_divesAtSite =>
      'Merulesek ezen a helyszinen';

  @override
  String get diveSites_detail_section_hazards => 'Veszelyek es biztonsag';

  @override
  String get diveSites_detail_section_location => 'Helyszin';

  @override
  String get diveSites_detail_section_notes => 'Megjegyzesek';

  @override
  String get diveSites_detail_section_rating => 'Ertekeles';

  @override
  String diveSites_detail_semantics_copyToClipboard(Object label) {
    return '$label masolasa a vagolapra';
  }

  @override
  String get diveSites_detail_semantics_viewDivesAtSite =>
      'Merulesek megtekintese ezen a helyszinen';

  @override
  String get diveSites_detail_semantics_viewFullscreenMap =>
      'Teljes kepernyon terkep megtekintese';

  @override
  String get diveSites_detail_siteNotFound_body =>
      'Ez a helyszin mar nem letezik.';

  @override
  String get diveSites_detail_siteNotFound_title => 'Helyszin nem talalhato';

  @override
  String get diveSites_difficulty_advanced => 'Halado';

  @override
  String get diveSites_difficulty_beginner => 'Kezdo';

  @override
  String get diveSites_difficulty_intermediate => 'Kozepes';

  @override
  String get diveSites_difficulty_technical => 'Technikai';

  @override
  String get diveSites_edit_access_accessNotes_hint =>
      'Hogyan lehet eljutni a helyszinre, be-/kijarat, parti/hajos megkozelites';

  @override
  String get diveSites_edit_access_accessNotes_label =>
      'Megkozelitesi megjegyzesek';

  @override
  String get diveSites_edit_access_mooringNumber_hint => 'pl. Boja #12';

  @override
  String get diveSites_edit_access_mooringNumber_label => 'Kikoto szam';

  @override
  String get diveSites_edit_access_parkingInfo_hint =>
      'Parkolas elerheto, dijak, tippek';

  @override
  String get diveSites_edit_access_parkingInfo_label => 'Parkolasi informaciok';

  @override
  String get diveSites_edit_altitude_helperText =>
      'Helyszin tengerszint feletti magassaga (magassagi meruleshez)';

  @override
  String get diveSites_edit_altitude_hint => 'pl. 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return 'Magassag ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => 'Ervenytelen magassag';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => 'Helyszin torlese';

  @override
  String get diveSites_edit_appBar_editSite => 'Helyszin szerkesztese';

  @override
  String get diveSites_edit_appBar_newSite => 'Uj helyszin';

  @override
  String get diveSites_edit_appBar_save => 'Mentes';

  @override
  String get diveSites_edit_button_addSite => 'Helyszin hozzaadasa';

  @override
  String get diveSites_edit_button_saveChanges => 'Valtozasok mentese';

  @override
  String get diveSites_edit_cancel => 'Megse';

  @override
  String get diveSites_edit_depth_helperText =>
      'A legseklyebb ponttol a legmelyebb pontig';

  @override
  String get diveSites_edit_depth_maxHint => 'pl. 30';

  @override
  String diveSites_edit_depth_maxLabel(Object symbol) {
    return 'Maximalis melyseg ($symbol)';
  }

  @override
  String get diveSites_edit_depth_minHint => 'pl. 5';

  @override
  String diveSites_edit_depth_minLabel(Object symbol) {
    return 'Minimalis melyseg ($symbol)';
  }

  @override
  String get diveSites_edit_depth_separator => '-ig';

  @override
  String get diveSites_edit_discardDialog_content =>
      'Mentetlen valtozasai vannak. Biztosan el akar tavozni?';

  @override
  String get diveSites_edit_discardDialog_discard => 'Eldobas';

  @override
  String get diveSites_edit_discardDialog_keepEditing =>
      'Szerkesztes folytatas';

  @override
  String get diveSites_edit_discardDialog_title => 'Valtozasok eldobasa?';

  @override
  String get diveSites_edit_field_country_label => 'Orszag';

  @override
  String get diveSites_edit_field_description_hint =>
      'A helyszin rovid leirasa';

  @override
  String get diveSites_edit_field_description_label => 'Leiras';

  @override
  String get diveSites_edit_field_notes_hint =>
      'Barmilyen egyeb informacio errol a helyszinrol';

  @override
  String get diveSites_edit_field_notes_label => 'Altalanos megjegyzesek';

  @override
  String get diveSites_edit_field_region_label => 'Regio';

  @override
  String get diveSites_edit_field_siteName_hint => 'pl. Blue Hole';

  @override
  String get diveSites_edit_field_siteName_label => 'Helyszin neve *';

  @override
  String get diveSites_edit_field_siteName_validation =>
      'Kerem adjon meg egy helyszinnevet';

  @override
  String get diveSites_edit_gps_gettingLocation => 'Lekeres...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Valasszon helymeghatarozoasi modszert - a koordinatak automatikusan kitoltik az orszagot es a regiot';

  @override
  String get diveSites_edit_gps_latitude_hint => 'pl. 21.4225';

  @override
  String get diveSites_edit_gps_latitude_label => 'Szelesseg';

  @override
  String get diveSites_edit_gps_latitude_validation => 'Ervenytelen szelesseg';

  @override
  String get diveSites_edit_gps_longitude_hint => 'pl. -86.7542';

  @override
  String get diveSites_edit_gps_longitude_label => 'Hosszusag';

  @override
  String get diveSites_edit_gps_longitude_validation => 'Ervenytelen hosszusag';

  @override
  String get diveSites_edit_gps_pickFromMap => 'Kivalasztas terkeprol';

  @override
  String get diveSites_edit_gps_useMyLocation => 'Sajat helyzet hasznalata';

  @override
  String get diveSites_edit_hazards_helperText =>
      'Soroljon fel veszelyeket vagy biztonsagi megfontolasokat';

  @override
  String get diveSites_edit_hazards_hint =>
      'pl. Eros aramlatok, hajoforgalom, meduzak, eles korallok';

  @override
  String get diveSites_edit_hazards_label => 'Veszelyek';

  @override
  String get diveSites_edit_marineLife_addButton => 'Hozzaadas';

  @override
  String get diveSites_edit_marineLife_empty =>
      'Nincsenek vart fajok hozzaadva';

  @override
  String get diveSites_edit_marineLife_helperText =>
      'Fajok, amelyeket varhatoan lathat ezen a helyszinen';

  @override
  String get diveSites_edit_rating_clear => 'Ertekeles torlese';

  @override
  String diveSites_edit_rating_starTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '',
      one: '',
    );
    return '$count csillag$_temp0';
  }

  @override
  String get diveSites_edit_section_access => 'Megkozelites es logisztika';

  @override
  String get diveSites_edit_section_altitude => 'Tengerszint feletti magassag';

  @override
  String get diveSites_edit_section_depthRange => 'Melyseg tartomany';

  @override
  String get diveSites_edit_section_difficultyLevel => 'Nehezssgi szint';

  @override
  String get diveSites_edit_section_expectedMarineLife =>
      'Varhato tengeri elet';

  @override
  String get diveSites_edit_section_gpsCoordinates => 'GPS koordinatak';

  @override
  String get diveSites_edit_section_hazards => 'Veszelyek es biztonsag';

  @override
  String get diveSites_edit_section_rating => 'Ertekeles';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return 'Hiba a helyszin torlesekor: $error';
  }

  @override
  String diveSites_edit_snackbar_errorSaving(Object error) {
    return 'Hiba a helyszin mentesekor: $error';
  }

  @override
  String get diveSites_edit_snackbar_locationCaptured => 'Helyzet rogzitve';

  @override
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Helyzet rogzitve (${accuracy}m)';
  }

  @override
  String get diveSites_edit_snackbar_locationSelectedFromMap =>
      'Helyszin kivalasztva a terkeprol';

  @override
  String get diveSites_edit_snackbar_locationSettings => 'Beallitasok';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      'Nem sikerult a helyzet lekerdezes. A helymeghatarozoasi szolgaltatasok nem lehetnek elerhetoek.';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      'Nem sikerult a helyzet lekerdezes. Kerem ellenorizze az engedelyeket.';

  @override
  String get diveSites_edit_snackbar_siteAdded => 'Helyszin hozzaadva';

  @override
  String get diveSites_edit_snackbar_siteUpdated => 'Helyszin frissitve';

  @override
  String get diveSites_fab_label => 'Helyszin hozzaadasa';

  @override
  String get diveSites_fab_tooltip => 'Uj merulohely hozzaadasa';

  @override
  String get diveSites_filter_apply => 'Szurok alkalmazasa';

  @override
  String get diveSites_filter_cancel => 'Megse';

  @override
  String get diveSites_filter_clearAll => 'Osszes torlese';

  @override
  String get diveSites_filter_country_hint => 'pl. Thaifold';

  @override
  String get diveSites_filter_country_label => 'Orszag';

  @override
  String get diveSites_filter_depth_max_label => 'Max';

  @override
  String get diveSites_filter_depth_min_label => 'Min';

  @override
  String get diveSites_filter_depth_separator => '-ig';

  @override
  String get diveSites_filter_difficulty_any => 'Barmely';

  @override
  String get diveSites_filter_option_hasCoordinates_subtitle =>
      'Csak GPS hellyel rendelkezo helyszinek mutatasa';

  @override
  String get diveSites_filter_option_hasCoordinates_title => 'Van koordinata';

  @override
  String get diveSites_filter_option_hasDives_subtitle =>
      'Csak rogzitett merulesekkel rendelkezo helyszinek mutatasa';

  @override
  String get diveSites_filter_option_hasDives_title => 'Vannak merulesek';

  @override
  String diveSites_filter_rating_starsPlus(Object count) {
    return '$count+ csillag';
  }

  @override
  String get diveSites_filter_region_hint => 'pl. Phuket';

  @override
  String get diveSites_filter_region_label => 'Regio';

  @override
  String get diveSites_filter_section_depthRange => 'Max melyseg tartomany';

  @override
  String get diveSites_filter_section_difficulty => 'Nehezsseg';

  @override
  String get diveSites_filter_section_location => 'Helyszin';

  @override
  String get diveSites_filter_section_minRating => 'Minimalis ertekeles';

  @override
  String get diveSites_filter_section_options => 'Opciok';

  @override
  String get diveSites_filter_title => 'Helyszinek szurese';

  @override
  String get diveSites_import_appBar_title => 'Merulohely importalasa';

  @override
  String get diveSites_import_badge_imported => 'Importalt';

  @override
  String get diveSites_import_badge_saved => 'Mentett';

  @override
  String get diveSites_import_button_import => 'Importalas';

  @override
  String get diveSites_import_detail_alreadyImported => 'Mar importalva';

  @override
  String get diveSites_import_detail_importToMySites =>
      'Importalas a helyszineimhez';

  @override
  String diveSites_import_detail_source(Object source) {
    return 'Forras: $source';
  }

  @override
  String get diveSites_import_empty_description =>
      'Keressen merulohelyeket a nepszeru\nmerulesi celpontok adatbazisunkbol vilagszerte.';

  @override
  String get diveSites_import_empty_hint =>
      'Probaljon keresni helyszinnev, orszag vagy regio alapjan.';

  @override
  String get diveSites_import_empty_title => 'Merulohelyek keresese';

  @override
  String get diveSites_import_error_retry => 'Ujra';

  @override
  String get diveSites_import_error_title => 'Keresesi hiba';

  @override
  String get diveSites_import_error_unknown => 'Ismeretlen hiba';

  @override
  String get diveSites_import_externalSite_locationUnknown =>
      'Ismeretlen helyszin';

  @override
  String get diveSites_import_label_gps => 'GPS';

  @override
  String get diveSites_import_localSite_locationNotSet =>
      'Helyszin nincs megadva';

  @override
  String diveSites_import_noResults_description(Object query) {
    return 'Nem talalhato merulohely \"$query\" keresesi kifejezesre.\nProbaljon mas keresesi kifejezest.';
  }

  @override
  String get diveSites_import_noResults_title => 'Nincs talalat';

  @override
  String get diveSites_import_quickSearch_caribbean => 'Karib-tenger';

  @override
  String get diveSites_import_quickSearch_indonesia => 'Indonezia';

  @override
  String get diveSites_import_quickSearch_maldives => 'Maldiv-szigetek';

  @override
  String get diveSites_import_quickSearch_philippines => 'Fulop-szigetek';

  @override
  String get diveSites_import_quickSearch_redSea => 'Voros-tenger';

  @override
  String get diveSites_import_quickSearch_thailand => 'Thaifold';

  @override
  String get diveSites_import_search_clearTooltip => 'Kereses torlese';

  @override
  String get diveSites_import_search_hint =>
      'Merulohelyek keresese (pl. \"Blue Hole\", \"Thaifold\")';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return 'Importalas adatbazisbol ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return 'Helyszineim ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return '$name reszleteinek megtekintese';
  }

  @override
  String diveSites_import_semantics_viewSavedSite(Object name) {
    return 'Mentett helyszin megtekintese: $name';
  }

  @override
  String get diveSites_import_snackbar_failed =>
      'Nem sikerult a helyszin importalasa';

  @override
  String diveSites_import_snackbar_imported(Object name) {
    return '\"$name\" importalva';
  }

  @override
  String get diveSites_import_snackbar_viewAction => 'Megtekintes';

  @override
  String get diveSites_list_activeFilter_clear => 'Torles';

  @override
  String diveSites_list_activeFilter_country(Object country) {
    return 'Orszag: $country';
  }

  @override
  String diveSites_list_activeFilter_depthRangeBoth(Object min, Object max) {
    return '$min-${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Legfeljebb ${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '${min}m+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => 'Van koordinata';

  @override
  String get diveSites_list_activeFilter_hasDives => 'Vannak merulesek';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return 'Regio: $region';
  }

  @override
  String get diveSites_list_appBar_title => 'Merulohelyek';

  @override
  String get diveSites_list_bulkDelete_cancel => 'Megse';

  @override
  String get diveSites_list_bulkDelete_confirm => 'Torles';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'helyszint',
      one: 'helyszint',
    );
    return 'Biztosan torolni akarja a(z) $count $_temp0? Ez a muvelet 5 masodpercen belul visszavonhato.';
  }

  @override
  String get diveSites_list_bulkDelete_restored => 'Helyszinek visszaallitva';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'helyszin',
      one: 'helyszin',
    );
    return '$count $_temp0 torolve';
  }

  @override
  String get diveSites_list_bulkDelete_title => 'Helyszinek torlese';

  @override
  String get diveSites_list_bulkDelete_undo => 'Visszavonas';

  @override
  String get diveSites_list_emptyFiltered_clearAll => 'Osszes szuro torlese';

  @override
  String get diveSites_list_emptyFiltered_subtitle =>
      'Probalja modositani vagy torolni a szuroket';

  @override
  String get diveSites_list_emptyFiltered_title =>
      'Nincs a szuroknek megfelelo helyszin';

  @override
  String get diveSites_list_empty_addFirstSite => 'Elso helyszin hozzaadasa';

  @override
  String get diveSites_list_empty_import => 'Importalas';

  @override
  String get diveSites_list_empty_subtitle =>
      'Adjon hozza merulohelyeket kedvenc helyszinei koveTesehez';

  @override
  String get diveSites_list_empty_title => 'Meg nincsenek merulohelyek';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return 'Hiba a helyszinek betoltesekor: $error';
  }

  @override
  String get diveSites_list_error_retry => 'Ujra';

  @override
  String get diveSites_list_menu_import => 'Importalas';

  @override
  String get diveSites_list_search_backTooltip => 'Vissza';

  @override
  String get diveSites_list_search_clearTooltip => 'Kereses torlese';

  @override
  String get diveSites_list_search_emptyHint =>
      'Kereses helyszinnev, orszag vagy regio alapjan';

  @override
  String diveSites_list_search_error(Object error) {
    return 'Hiba: $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return 'Nem talalhato helyszin \"$query\" keresesi kifejezesre';
  }

  @override
  String get diveSites_list_search_placeholder => 'Helyszinek keresese...';

  @override
  String get diveSites_list_selection_closeTooltip => 'Kivalasztas bezarasa';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count kivalasztva';
  }

  @override
  String get diveSites_list_selection_deleteTooltip => 'Kivalasztottak torlese';

  @override
  String get diveSites_list_selection_deselectAllTooltip =>
      'Osszes kivalasztas megszuntetese';

  @override
  String get diveSites_list_selection_selectAllTooltip => 'Osszes kivalasztasa';

  @override
  String get diveSites_list_sort_title => 'Helyszinek rendezese';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merules',
      one: '1 merules',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return 'Merulohely: $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => 'Helyszinek szurese';

  @override
  String get diveSites_list_tooltip_mapView => 'Terkep nezet';

  @override
  String get diveSites_list_tooltip_searchSites => 'Helyszinek keresese';

  @override
  String get diveSites_list_tooltip_sort => 'Rendezes';

  @override
  String get diveSites_locationPicker_appBar_title => 'Helyszin kivalasztasa';

  @override
  String get diveSites_locationPicker_confirmButton => 'Megerosites';

  @override
  String get diveSites_locationPicker_confirmTooltip =>
      'Kivalasztott helyszin megerositese';

  @override
  String get diveSites_locationPicker_fab_tooltip => 'Sajat helyzet hasznalata';

  @override
  String get diveSites_locationPicker_instruction_locationSelected =>
      'Helyszin kivalasztva';

  @override
  String get diveSites_locationPicker_instruction_lookingUp =>
      'Helyszin keresese...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect =>
      'Koppintson a terkepre a helyszin kivalasztasahoz';

  @override
  String get diveSites_locationPicker_label_latitude => 'Szelesseg';

  @override
  String get diveSites_locationPicker_label_longitude => 'Hosszusag';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return 'Kivalasztott koordinatak: szelesseg $latitude, hosszusag $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp =>
      'Helyszin keresese';

  @override
  String get diveSites_locationPicker_semantics_map =>
      'Interaktiv terkep merulohely kivalasztasahoz. Koppintson a terkepre a helyszin kivalasztasahoz.';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return 'Hiba a merulohelyek betoltesekor: $error';
  }

  @override
  String get diveSites_map_appBar_title => 'Merulohelyek';

  @override
  String get diveSites_map_empty_description =>
      'Adjon hozza koordinatakat a merulohelyeihez, hogy lassa oket a terkepen';

  @override
  String get diveSites_map_empty_title =>
      'Nincsenek koordinataval rendelkezo helyszinek';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return 'Hiba a helyszinek betoltesekor: $error';
  }

  @override
  String get diveSites_map_error_retry => 'Ujra';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merules',
      one: '1 merules',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return 'Merulohely: $name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => 'Osszes helyszin illesztese';

  @override
  String get diveSites_map_tooltip_listView => 'Lista nezet';

  @override
  String get diveSites_summary_action_addSite => 'Helyszin hozzaadasa';

  @override
  String get diveSites_summary_action_import => 'Importalas';

  @override
  String get diveSites_summary_action_viewMap => 'Terkep megtekintese';

  @override
  String diveSites_summary_countriesMore(Object count) {
    return '+ $count tovabb';
  }

  @override
  String get diveSites_summary_header_subtitle =>
      'Valasszon helyszint a listabol a reszletek megtekIntesehez';

  @override
  String get diveSites_summary_header_title => 'Merulohelyek';

  @override
  String get diveSites_summary_section_countriesRegions => 'Orszagok es regiok';

  @override
  String get diveSites_summary_section_mostDived => 'Legtobbet merult';

  @override
  String get diveSites_summary_section_overview => 'Attekintes';

  @override
  String get diveSites_summary_section_quickActions => 'Gyorsmuveletek';

  @override
  String get diveSites_summary_section_topRated => 'Legjobban ertekelt';

  @override
  String get diveSites_summary_stat_avgRating => 'Atl. ertekeles';

  @override
  String get diveSites_summary_stat_totalDives => 'Osszes merules';

  @override
  String get diveSites_summary_stat_totalSites => 'Osszes helyszin';

  @override
  String get diveSites_summary_stat_withGps => 'GPS-szel';

  @override
  String get diveTypes_addDialog_addButton => 'Hozzáadás';

  @override
  String get diveTypes_addDialog_nameHint => 'pl. Kutatás és mentés';

  @override
  String get diveTypes_addDialog_nameLabel => 'Merülés típus neve';

  @override
  String get diveTypes_addDialog_nameValidation => 'Adj meg egy nevet';

  @override
  String get diveTypes_addDialog_title => 'Egyedi merülés típus hozzáadása';

  @override
  String get diveTypes_addTooltip => 'Merülés típus hozzáadása';

  @override
  String get diveTypes_appBar_title => 'Merülés típusok';

  @override
  String get diveTypes_builtIn => 'Beépített';

  @override
  String get diveTypes_builtInHeader => 'Beépített merülés típusok';

  @override
  String get diveTypes_custom => 'Egyedi';

  @override
  String get diveTypes_customHeader => 'Egyedi merülés típusok';

  @override
  String diveTypes_deleteDialog_content(Object name) {
    return 'Biztosan törölni szeretnéd: \"$name\"?';
  }

  @override
  String get diveTypes_deleteDialog_title => 'Merülés típus törlése?';

  @override
  String get diveTypes_deleteTooltip => 'Merülés típus törlése';

  @override
  String diveTypes_snackbar_added(Object name) {
    return 'Merülés típus hozzáadva: $name';
  }

  @override
  String diveTypes_snackbar_cannotDelete(Object name) {
    return 'Nem lehet törölni \"$name\" - meglévő merülések használják';
  }

  @override
  String diveTypes_snackbar_deleted(Object name) {
    return 'Törölve: \"$name\"';
  }

  @override
  String diveTypes_snackbar_errorAdding(Object error) {
    return 'Hiba a merülés típus hozzáadásakor: $error';
  }

  @override
  String diveTypes_snackbar_errorDeleting(Object error) {
    return 'Hiba a merülés típus törlésekor: $error';
  }

  @override
  String get divers_detail_activeDiver => 'Aktiv merülo';

  @override
  String get divers_detail_allergiesLabel => 'Allergiak';

  @override
  String get divers_detail_appBarTitle => 'Merülo';

  @override
  String get divers_detail_bloodTypeLabel => 'Vercsoport';

  @override
  String get divers_detail_bottomTimeLabel => 'Fenekido';

  @override
  String get divers_detail_cancelButton => 'Megse';

  @override
  String get divers_detail_contactTitle => 'Kapcsolat';

  @override
  String get divers_detail_defaultLabel => 'Alapertelmezett';

  @override
  String get divers_detail_deleteButton => 'Torles';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'Biztosan torli $name merülot? Az osszes hozzatartozo merülesi naplo hozzarendelese megszunik.';
  }

  @override
  String get divers_detail_deleteDialogTitle => 'Merülo torlese?';

  @override
  String divers_detail_deleteError(Object error) {
    return 'Nem sikerult a torles: $error';
  }

  @override
  String get divers_detail_deleteMenuItem => 'Torles';

  @override
  String get divers_detail_deletedSnackbar => 'Merülo torolve';

  @override
  String get divers_detail_diveInsuranceTitle => 'Merülesi biztositas';

  @override
  String get divers_detail_diveStatisticsTitle => 'Merülesi statisztikak';

  @override
  String get divers_detail_editTooltip => 'Merülo szerkesztese';

  @override
  String get divers_detail_emergencyContactTitle =>
      'Veszhelyzeti kapcsolattarto';

  @override
  String divers_detail_errorPrefix(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get divers_detail_expiredBadge => 'Lejart';

  @override
  String get divers_detail_expiresLabel => 'Lejar';

  @override
  String get divers_detail_medicalInfoTitle => 'Orvosi informaciok';

  @override
  String get divers_detail_medicalNotesLabel => 'Megjegyzesek';

  @override
  String get divers_detail_notFound => 'Merülo nem talalhato';

  @override
  String get divers_detail_notesTitle => 'Megjegyzesek';

  @override
  String get divers_detail_policyNumberLabel => 'Kotveny szama';

  @override
  String get divers_detail_providerLabel => 'Biztosito';

  @override
  String get divers_detail_setAsDefault => 'Beallitas alapertelmezettkent';

  @override
  String divers_detail_setAsDefaultSnackbar(Object name) {
    return '$name beallitva alapertelmezett merülokent';
  }

  @override
  String get divers_detail_switchToTooltip => 'Valtas erre a merülore';

  @override
  String divers_detail_switchedTo(Object name) {
    return 'Valtas: $name';
  }

  @override
  String get divers_detail_totalDivesLabel => 'Osszes merüles';

  @override
  String get divers_detail_unableToLoadStats =>
      'Nem sikerult a statisztikak betoltese';

  @override
  String get divers_edit_addButton => 'Merülo hozzaadasa';

  @override
  String get divers_edit_addTitle => 'Merülo hozzaadasa';

  @override
  String get divers_edit_allergiesHint => 'pl. Penicillin, kagylofele';

  @override
  String get divers_edit_allergiesLabel => 'Allergiak';

  @override
  String get divers_edit_bloodTypeHint => 'pl. 0+, A-, B+';

  @override
  String get divers_edit_bloodTypeLabel => 'Vercsoport';

  @override
  String get divers_edit_cancelButton => 'Megse';

  @override
  String get divers_edit_clearInsuranceExpiryTooltip =>
      'Biztositasi lejarat torlese';

  @override
  String get divers_edit_clearMedicalClearanceTooltip =>
      'Orvosi engedelylejarat torlese';

  @override
  String get divers_edit_contactNameLabel => 'Kapcsolattarto neve';

  @override
  String get divers_edit_contactPhoneLabel => 'Kapcsolattarto telefonszama';

  @override
  String get divers_edit_discardButton => 'Elvetés';

  @override
  String get divers_edit_discardDialogContent =>
      'Nem mentett valtoztatasai vannak. Biztosan elveti oket?';

  @override
  String get divers_edit_discardDialogTitle => 'Valtoztatasok elvetese?';

  @override
  String get divers_edit_diverAdded => 'Merülo hozzaadva';

  @override
  String get divers_edit_diverUpdated => 'Merülo frissitve';

  @override
  String get divers_edit_editTitle => 'Merülo szerkesztese';

  @override
  String get divers_edit_emailError => 'Adjon meg ervenyes e-mail cimet';

  @override
  String get divers_edit_emailLabel => 'E-mail';

  @override
  String get divers_edit_emergencyContactsSection =>
      'Veszhelyzeti kapcsolattartok';

  @override
  String divers_edit_errorLoading(Object error) {
    return 'Hiba a merülo betoltesekor: $error';
  }

  @override
  String divers_edit_errorSaving(Object error) {
    return 'Hiba a merülo mentesekor: $error';
  }

  @override
  String get divers_edit_expiryDateNotSet => 'Nincs megadva';

  @override
  String get divers_edit_expiryDateTitle => 'Lejarat datuma';

  @override
  String get divers_edit_insuranceProviderHint => 'pl. DAN, DiveAssure';

  @override
  String get divers_edit_insuranceProviderLabel => 'Biztosito';

  @override
  String get divers_edit_insuranceSection => 'Merülesi biztositas';

  @override
  String get divers_edit_keepEditingButton => 'Szerkesztes folytatasa';

  @override
  String get divers_edit_medicalClearanceExpired => 'Lejart';

  @override
  String get divers_edit_medicalClearanceExpiringSoon => 'Hamarosan lejar';

  @override
  String get divers_edit_medicalClearanceNotSet => 'Nincs megadva';

  @override
  String get divers_edit_medicalClearanceTitle => 'Orvosi engedelylejarat';

  @override
  String get divers_edit_medicalInfoSection => 'Orvosi informaciok';

  @override
  String get divers_edit_medicalNotesLabel => 'Orvosi megjegyzesek';

  @override
  String get divers_edit_medicationsHint => 'pl. Napi aszpirin, EpiPen';

  @override
  String get divers_edit_medicationsLabel => 'Gyogyszerek';

  @override
  String get divers_edit_nameError => 'A nev megadasa kotelezo';

  @override
  String get divers_edit_nameLabel => 'Nev *';

  @override
  String get divers_edit_notesLabel => 'Megjegyzesek';

  @override
  String get divers_edit_notesSection => 'Megjegyzesek';

  @override
  String get divers_edit_personalInfoSection => 'Szemelyes adatok';

  @override
  String get divers_edit_phoneLabel => 'Telefon';

  @override
  String get divers_edit_policyNumberLabel => 'Kotveny szama';

  @override
  String get divers_edit_primaryContactTitle => 'Elsodleges kapcsolattarto';

  @override
  String get divers_edit_relationshipHint => 'pl. Hazastars, Szülo, Barat';

  @override
  String get divers_edit_relationshipLabel => 'Kapcsolat';

  @override
  String get divers_edit_saveButton => 'Mentes';

  @override
  String get divers_edit_secondaryContactTitle => 'Masodlagos kapcsolattarto';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip =>
      'Biztositasi lejarat valasztasa';

  @override
  String get divers_edit_selectMedicalClearanceTooltip =>
      'Orvosi engedelylejarat valasztasa';

  @override
  String get divers_edit_updateButton => 'Merülo frissitese';

  @override
  String get divers_list_activeBadge => 'Aktiv';

  @override
  String get divers_list_addDiverButton => 'Merülo hozzaadasa';

  @override
  String get divers_list_addDiverTooltip => 'Uj merülo profil hozzaadasa';

  @override
  String get divers_list_appBarTitle => 'Merülo profilok';

  @override
  String get divers_list_compactTitle => 'Merülok';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount merüles$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle =>
      'Adjon hozza merülo profilokat tobb szemely merülesi naploinak követesehez';

  @override
  String get divers_list_emptyTitle => 'Meg nincsenek merülok';

  @override
  String divers_list_errorLoading(Object error) {
    return 'Hiba a merülok betoltesekor: $error';
  }

  @override
  String get divers_list_errorLoadingStats =>
      'Hiba a statisztikak betoltesekor';

  @override
  String get divers_list_loadingStats => 'Betoltes...';

  @override
  String get divers_list_retryButton => 'Ujraproba';

  @override
  String divers_list_viewDiverLabel(Object name) {
    return '$name merülo megtekintese';
  }

  @override
  String get divers_summary_activeDiverTitle => 'Aktiv merülo';

  @override
  String get divers_summary_otherDiversTitle => 'Tobbi merülo';

  @override
  String get divers_summary_overviewTitle => 'Attekintes';

  @override
  String get divers_summary_quickActionsTitle => 'Gyorsmuveletek';

  @override
  String get divers_summary_subtitle =>
      'Valasszon egy merülot a listabol a reszletek megtekintésehez';

  @override
  String get divers_summary_title => 'Merülo profilok';

  @override
  String get divers_summary_totalDiversLabel => 'Osszes merülo';

  @override
  String get enum_altitudeGroup_extreme => 'Extrem magassag';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => '1. magassagi csoport';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => '2. magassagi csoport';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => '3. magassagi csoport';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => 'Tengerszint';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => 'Veszelyes';

  @override
  String get enum_ascentRate_safe => 'Biztonsagos';

  @override
  String get enum_ascentRate_warning => 'Figyelmeztetés';

  @override
  String get enum_buddyRole_buddy => 'Buddy';

  @override
  String get enum_buddyRole_diveGuide => 'Merulesvezeto';

  @override
  String get enum_buddyRole_diveMaster => 'Divemaster';

  @override
  String get enum_buddyRole_instructor => 'Oktato';

  @override
  String get enum_buddyRole_solo => 'Solo';

  @override
  String get enum_buddyRole_student => 'Tanulo';

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
  String get enum_certificationAgency_other => 'Egyeb';

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
  String get enum_certificationLevel_advancedNitrox => 'Halado Nitrox';

  @override
  String get enum_certificationLevel_advancedOpenWater => 'Halado nyiltvizi';

  @override
  String get enum_certificationLevel_cave => 'Barlang';

  @override
  String get enum_certificationLevel_cavern => 'Barlangi eloszoba';

  @override
  String get enum_certificationLevel_courseDirector => 'Tanfolyamigazgato';

  @override
  String get enum_certificationLevel_decompression => 'Dekompresszio';

  @override
  String get enum_certificationLevel_diveMaster => 'Divemaster';

  @override
  String get enum_certificationLevel_instructor => 'Oktato';

  @override
  String get enum_certificationLevel_masterInstructor => 'Mesteroktato';

  @override
  String get enum_certificationLevel_nitrox => 'Nitrox';

  @override
  String get enum_certificationLevel_openWater => 'Nyiltvizi';

  @override
  String get enum_certificationLevel_other => 'Egyeb';

  @override
  String get enum_certificationLevel_rebreather => 'Visszalelegezteto';

  @override
  String get enum_certificationLevel_rescue => 'Mento buvar';

  @override
  String get enum_certificationLevel_sidemount => 'Sidemount';

  @override
  String get enum_certificationLevel_techDiver => 'Technikai buvar';

  @override
  String get enum_certificationLevel_trimix => 'Trimix';

  @override
  String get enum_certificationLevel_wreck => 'Roncs';

  @override
  String get enum_currentDirection_east => 'Kelet';

  @override
  String get enum_currentDirection_none => 'Nincs';

  @override
  String get enum_currentDirection_north => 'Eszak';

  @override
  String get enum_currentDirection_northEast => 'Eszakkelet';

  @override
  String get enum_currentDirection_northWest => 'Eszaknyugat';

  @override
  String get enum_currentDirection_south => 'Del';

  @override
  String get enum_currentDirection_southEast => 'Delkelet';

  @override
  String get enum_currentDirection_southWest => 'Delnyugat';

  @override
  String get enum_currentDirection_variable => 'Valtozo';

  @override
  String get enum_currentDirection_west => 'Nyugat';

  @override
  String get enum_currentStrength_light => 'Gyenge';

  @override
  String get enum_currentStrength_moderate => 'Mersekelt';

  @override
  String get enum_currentStrength_none => 'Nincs';

  @override
  String get enum_currentStrength_strong => 'Eros';

  @override
  String get enum_diveMode_ccr => 'Zart koru visszalelegezteto';

  @override
  String get enum_diveMode_oc => 'Nyilt koru';

  @override
  String get enum_diveMode_scr => 'Felig zart visszalelegezteto';

  @override
  String get enum_diveType_altitude => 'Magassagi';

  @override
  String get enum_diveType_boat => 'Hajos';

  @override
  String get enum_diveType_cave => 'Barlang';

  @override
  String get enum_diveType_deep => 'Mely';

  @override
  String get enum_diveType_drift => 'Sodrodas';

  @override
  String get enum_diveType_freedive => 'Szabadmerules';

  @override
  String get enum_diveType_ice => 'Jeg';

  @override
  String get enum_diveType_liveaboard => 'Hajo szallas';

  @override
  String get enum_diveType_night => 'Ejszakai';

  @override
  String get enum_diveType_recreational => 'Rekreaccios';

  @override
  String get enum_diveType_shore => 'Parti';

  @override
  String get enum_diveType_technical => 'Technikai';

  @override
  String get enum_diveType_training => 'Kepzes';

  @override
  String get enum_diveType_wreck => 'Roncs';

  @override
  String get enum_entryMethod_backRoll => 'Hatragurulas';

  @override
  String get enum_entryMethod_boat => 'Hajos beszallas';

  @override
  String get enum_entryMethod_giantStride => 'Orias lepes';

  @override
  String get enum_entryMethod_jetty => 'Steg/Molo';

  @override
  String get enum_entryMethod_ladder => 'Letra';

  @override
  String get enum_entryMethod_other => 'Egyeb';

  @override
  String get enum_entryMethod_platform => 'Platform';

  @override
  String get enum_entryMethod_seatedEntry => 'Ulos beszallas';

  @override
  String get enum_entryMethod_shore => 'Parti beszallas';

  @override
  String get enum_equipmentStatus_active => 'Aktiv';

  @override
  String get enum_equipmentStatus_inService => 'Szervizben';

  @override
  String get enum_equipmentStatus_loaned => 'Kolcsonadva';

  @override
  String get enum_equipmentStatus_lost => 'Elveszett';

  @override
  String get enum_equipmentStatus_needsService => 'Szerviz szukseges';

  @override
  String get enum_equipmentStatus_retired => 'Kivonva';

  @override
  String get enum_equipmentType_bcd => 'Jacket';

  @override
  String get enum_equipmentType_boots => 'Cipok';

  @override
  String get enum_equipmentType_camera => 'Kamera';

  @override
  String get enum_equipmentType_computer => 'Merulesszamitogep';

  @override
  String get enum_equipmentType_drysuit => 'Szaraz ruha';

  @override
  String get enum_equipmentType_fins => 'Uszonyok';

  @override
  String get enum_equipmentType_gloves => 'Kesztyuk';

  @override
  String get enum_equipmentType_hood => 'Csuklya';

  @override
  String get enum_equipmentType_knife => 'Kes';

  @override
  String get enum_equipmentType_light => 'Lampa';

  @override
  String get enum_equipmentType_mask => 'Maszk';

  @override
  String get enum_equipmentType_other => 'Egyeb';

  @override
  String get enum_equipmentType_reel => 'Orsó';

  @override
  String get enum_equipmentType_regulator => 'Automata';

  @override
  String get enum_equipmentType_smb => 'SMB';

  @override
  String get enum_equipmentType_tank => 'Palack';

  @override
  String get enum_equipmentType_weights => 'Sulyok';

  @override
  String get enum_equipmentType_wetsuit => 'Neopren ruha';

  @override
  String get enum_eventSeverity_alert => 'Riasztas';

  @override
  String get enum_eventSeverity_info => 'Info';

  @override
  String get enum_eventSeverity_warning => 'Figyelmeztetés';

  @override
  String get enum_pdfPageSize_a4 => 'A4';

  @override
  String get enum_pdfPageSize_a4_description => '210 x 297 mm';

  @override
  String get enum_pdfPageSize_letter => 'Letter';

  @override
  String get enum_pdfPageSize_letter_description => '8.5 x 11 in';

  @override
  String get enum_pdfTemplate_detailed => 'Reszletes';

  @override
  String get enum_pdfTemplate_detailed_description =>
      'Teljes merulesi informacio jegyzetekkel es ertekelesekkel';

  @override
  String get enum_pdfTemplate_nauiStyle => 'NAUI stilusu';

  @override
  String get enum_pdfTemplate_nauiStyle_description =>
      'NAUI naplo formatumnak megfelelo elrendezes';

  @override
  String get enum_pdfTemplate_padiStyle => 'PADI stilusu';

  @override
  String get enum_pdfTemplate_padiStyle_description =>
      'PADI naplo formatumnak megfelelo elrendezes';

  @override
  String get enum_pdfTemplate_professional => 'Professzionalis';

  @override
  String get enum_pdfTemplate_professional_description =>
      'Alairas es pecsethely az ellenorzeshez';

  @override
  String get enum_pdfTemplate_simple => 'Egyszeru';

  @override
  String get enum_pdfTemplate_simple_description =>
      'Tomor tablazatos formatum, sok merules oldalankent';

  @override
  String get enum_profileEvent_alert => 'Riasztas';

  @override
  String get enum_profileEvent_ascentRateCritical =>
      'Felszallasi sebesseg kritikus';

  @override
  String get enum_profileEvent_ascentRateWarning =>
      'Felszallasi sebesseg figyelmeztetés';

  @override
  String get enum_profileEvent_ascentStart => 'Felszallas kezdete';

  @override
  String get enum_profileEvent_bookmark => 'Konyvjelzo';

  @override
  String get enum_profileEvent_cnsCritical => 'CNS kritikus';

  @override
  String get enum_profileEvent_cnsWarning => 'CNS figyelmeztetés';

  @override
  String get enum_profileEvent_decoStopEnd => 'Deko megallo vege';

  @override
  String get enum_profileEvent_decoStopStart => 'Deko megallo kezdete';

  @override
  String get enum_profileEvent_decoViolation => 'Deko megszeges';

  @override
  String get enum_profileEvent_descentEnd => 'Lesullyedes vege';

  @override
  String get enum_profileEvent_descentStart => 'Lesullyedes kezdete';

  @override
  String get enum_profileEvent_gasSwitch => 'Gazcsereles';

  @override
  String get enum_profileEvent_lowGas => 'Alacsony gaz figyelmeztetés';

  @override
  String get enum_profileEvent_maxDepth => 'Max melyseg';

  @override
  String get enum_profileEvent_missedStop => 'Kihagyott deko megallo';

  @override
  String get enum_profileEvent_note => 'Jegyzet';

  @override
  String get enum_profileEvent_ppO2High => 'Magas ppO2';

  @override
  String get enum_profileEvent_ppO2Low => 'Alacsony ppO2';

  @override
  String get enum_profileEvent_safetyStopEnd => 'Biztonsagi megallas vege';

  @override
  String get enum_profileEvent_safetyStopStart => 'Biztonsagi megallas kezdete';

  @override
  String get enum_profileEvent_setpointChange => 'Setpoint valtozas';

  @override
  String get enum_profileMetricCategory_decompression => 'Dekompresszio';

  @override
  String get enum_profileMetricCategory_gasAnalysis => 'Gazelemzes';

  @override
  String get enum_profileMetricCategory_gradientFactor => 'Gradiens faktorok';

  @override
  String get enum_profileMetricCategory_other => 'Egyeb';

  @override
  String get enum_profileMetricCategory_primary => 'Elsodleges mutatók';

  @override
  String get enum_profileMetric_gasDensity => 'Gaz suruseg';

  @override
  String get enum_profileMetric_gasDensity_short => 'Suruseg';

  @override
  String get enum_profileMetric_gf => 'GF%';

  @override
  String get enum_profileMetric_gf_short => 'GF%';

  @override
  String get enum_profileMetric_heartRate => 'Pulzus';

  @override
  String get enum_profileMetric_heartRate_short => 'Pulzus';

  @override
  String get enum_profileMetric_meanDepth => 'Atlag melyseg';

  @override
  String get enum_profileMetric_meanDepth_short => 'Atlag';

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
  String get enum_profileMetric_pressure => 'Nyomas';

  @override
  String get enum_profileMetric_pressure_short => 'Nyom';

  @override
  String get enum_profileMetric_sacRate => 'SAC ertek';

  @override
  String get enum_profileMetric_sacRate_short => 'SAC';

  @override
  String get enum_profileMetric_surfaceGf => 'Felszini GF';

  @override
  String get enum_profileMetric_surfaceGf_short => 'FelszGF';

  @override
  String get enum_profileMetric_temperature => 'Homerseklet';

  @override
  String get enum_profileMetric_temperature_short => 'Hom';

  @override
  String get enum_profileMetric_tts => 'TTS';

  @override
  String get enum_profileMetric_tts_short => 'TTS';

  @override
  String get enum_scrType_cmf => 'Allando tomegaram';

  @override
  String get enum_scrType_cmf_short => 'CMF';

  @override
  String get enum_scrType_escr => 'Elektronikusan szabalyozott';

  @override
  String get enum_scrType_escr_short => 'ESCR';

  @override
  String get enum_scrType_pascr => 'Passziv adagolas';

  @override
  String get enum_scrType_pascr_short => 'PASCR';

  @override
  String get enum_serviceType_annual => 'Eves szerviz';

  @override
  String get enum_serviceType_calibration => 'Kalibralas';

  @override
  String get enum_serviceType_cleaning => 'Tisztitas';

  @override
  String get enum_serviceType_inspection => 'Ellenorzes';

  @override
  String get enum_serviceType_other => 'Egyeb';

  @override
  String get enum_serviceType_overhaul => 'Nagyjavitas';

  @override
  String get enum_serviceType_recall => 'Visszahivas/Biztonsag';

  @override
  String get enum_serviceType_repair => 'Javitas';

  @override
  String get enum_serviceType_replacement => 'Alkatresz csere';

  @override
  String get enum_serviceType_warranty => 'Garancialis szerviz';

  @override
  String get enum_sortDirection_ascending => 'Novekvo';

  @override
  String get enum_sortDirection_descending => 'Csokkeno';

  @override
  String get enum_sortField_agency => 'Szervezet';

  @override
  String get enum_sortField_date => 'Datum';

  @override
  String get enum_sortField_dateIssued => 'Kiallitas datuma';

  @override
  String get enum_sortField_difficulty => 'Nehezsegi szint';

  @override
  String get enum_sortField_diveCount => 'Merulesszam';

  @override
  String get enum_sortField_diveNumber => 'Merules szama';

  @override
  String get enum_sortField_duration => 'Idotartam';

  @override
  String get enum_sortField_endDate => 'Zaras datuma';

  @override
  String get enum_sortField_lastServiceDate => 'Utolso szerviz';

  @override
  String get enum_sortField_maxDepth => 'Max melyseg';

  @override
  String get enum_sortField_name => 'Nev';

  @override
  String get enum_sortField_purchaseDate => 'Vasarlas datuma';

  @override
  String get enum_sortField_rating => 'Ertekeles';

  @override
  String get enum_sortField_site => 'Merulohely';

  @override
  String get enum_sortField_startDate => 'Kezdes datuma';

  @override
  String get enum_sortField_status => 'Allapot';

  @override
  String get enum_sortField_type => 'Tipus';

  @override
  String get enum_speciesCategory_coral => 'Korall';

  @override
  String get enum_speciesCategory_fish => 'Hal';

  @override
  String get enum_speciesCategory_invertebrate => 'Gerinctelen';

  @override
  String get enum_speciesCategory_mammal => 'Emlos';

  @override
  String get enum_speciesCategory_other => 'Egyeb';

  @override
  String get enum_speciesCategory_plant => 'Noveny/Alga';

  @override
  String get enum_speciesCategory_ray => 'Raja';

  @override
  String get enum_speciesCategory_shark => 'Capa';

  @override
  String get enum_speciesCategory_turtle => 'Teknosbeka';

  @override
  String get enum_tankMaterial_aluminum => 'Aluminium';

  @override
  String get enum_tankMaterial_carbonFiber => 'Szenalas';

  @override
  String get enum_tankMaterial_steel => 'Acel';

  @override
  String get enum_tankRole_backGas => 'Fo gaz';

  @override
  String get enum_tankRole_bailout => 'Bailout';

  @override
  String get enum_tankRole_deco => 'Deko';

  @override
  String get enum_tankRole_diluent => 'Higigaz';

  @override
  String get enum_tankRole_oxygenSupply => 'O₂ ellatas';

  @override
  String get enum_tankRole_pony => 'Pony palack';

  @override
  String get enum_tankRole_sidemountLeft => 'Sidemount bal';

  @override
  String get enum_tankRole_sidemountRight => 'Sidemount jobb';

  @override
  String get enum_tankRole_stage => 'Stage';

  @override
  String get enum_visibility_excellent => 'Kituno (>30m / >100ft)';

  @override
  String get enum_visibility_good => 'Jo (15-30m / 50-100ft)';

  @override
  String get enum_visibility_moderate => 'Kozepes (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => 'Gyenge (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => 'Ismeretlen';

  @override
  String get enum_waterType_brackish => 'Felsos';

  @override
  String get enum_waterType_fresh => 'Edesviz';

  @override
  String get enum_waterType_salt => 'Sosviz';

  @override
  String get enum_weightType_ankleWeights => 'Boka sulyok';

  @override
  String get enum_weightType_backplate => 'Hatlap sulyok';

  @override
  String get enum_weightType_belt => 'Sulyoev';

  @override
  String get enum_weightType_integrated => 'Beepitett sulyok';

  @override
  String get enum_weightType_mixed => 'Vegyes/Kombinalt';

  @override
  String get enum_weightType_trimWeights => 'Trim sulyok';

  @override
  String get equipment_addSheet_brandHint => 'pl. Scubapro';

  @override
  String get equipment_addSheet_brandLabel => 'Marka';

  @override
  String get equipment_addSheet_closeTooltip => 'Bezaras';

  @override
  String get equipment_addSheet_currencyLabel => 'Penznem';

  @override
  String get equipment_addSheet_dateLabel => 'Datum';

  @override
  String equipment_addSheet_errorSnackbar(Object error) {
    return 'Hiba a felszereles hozzaadasakor: $error';
  }

  @override
  String get equipment_addSheet_modelHint => 'pl. MK25 EVO';

  @override
  String get equipment_addSheet_modelLabel => 'Modell';

  @override
  String get equipment_addSheet_nameHint => 'pl. Elsooleges automata';

  @override
  String get equipment_addSheet_nameLabel => 'Nev';

  @override
  String get equipment_addSheet_nameValidation => 'Kerem adjon meg egy nevet';

  @override
  String get equipment_addSheet_notesHint => 'Tovabbl megjegyzesek...';

  @override
  String get equipment_addSheet_notesLabel => 'Megjegyzesek';

  @override
  String get equipment_addSheet_priceLabel => 'Ar';

  @override
  String get equipment_addSheet_purchaseInfoTitle => 'Vasarlasi informaciok';

  @override
  String get equipment_addSheet_serialNumberLabel => 'Sorozatszam';

  @override
  String get equipment_addSheet_serviceIntervalHint =>
      'pl. 365 az eves szervizhez';

  @override
  String get equipment_addSheet_serviceIntervalLabel =>
      'Szerviz intervallum (nap)';

  @override
  String get equipment_addSheet_sizeHint => 'pl. M, L, 42';

  @override
  String get equipment_addSheet_sizeLabel => 'Meret';

  @override
  String get equipment_addSheet_submitButton => 'Felszereles hozzaadasa';

  @override
  String get equipment_addSheet_successSnackbar =>
      'Felszereles sikeresen hozzaadva';

  @override
  String get equipment_addSheet_title => 'Felszereles hozzaadasa';

  @override
  String get equipment_addSheet_typeLabel => 'Tipus';

  @override
  String get equipment_appBar_title => 'Felszereles';

  @override
  String get equipment_deleteDialog_cancel => 'Megse';

  @override
  String get equipment_deleteDialog_confirm => 'Torles';

  @override
  String get equipment_deleteDialog_content =>
      'Biztosan torli ezt a felszerelest? Ez a muvelet nem vonhato vissza.';

  @override
  String get equipment_deleteDialog_title => 'Felszereles torlese';

  @override
  String get equipment_detail_brandLabel => 'Marka';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return '$days napja lejartt';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days nap a szerviz';
  }

  @override
  String get equipment_detail_detailsTitle => 'Reszletek';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count merules';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count merules';
  }

  @override
  String get equipment_detail_divesLabel => 'Merulesek';

  @override
  String get equipment_detail_divesSemanticLabel =>
      'Merulesek megtekintese ezzel a felszerelessel';

  @override
  String equipment_detail_durationDays(Object days) {
    return '$days nap';
  }

  @override
  String equipment_detail_durationMonths(Object months) {
    return '$months honap';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralPlural(
    Object years,
    Object months,
  ) {
    return '$years ev, $months honap';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralSingular(
    Object years,
    Object months,
  ) {
    return '$years ev, $months honap';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularPlural(
    Object years,
    Object months,
  ) {
    return '$years ev, $months honap';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularSingular(
    Object years,
    Object months,
  ) {
    return '$years ev, $months honap';
  }

  @override
  String equipment_detail_durationYearsPlural(Object years) {
    return '$years ev';
  }

  @override
  String equipment_detail_durationYearsSingular(Object years) {
    return '$years ev';
  }

  @override
  String get equipment_detail_editTooltip => 'Felszereles szerkesztese';

  @override
  String get equipment_detail_editTooltipShort => 'Szerkesztes';

  @override
  String equipment_detail_errorMessage(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get equipment_detail_errorTitle => 'Hiba';

  @override
  String get equipment_detail_lastServiceLabel => 'Utolso szerviz';

  @override
  String get equipment_detail_loadingTitle => 'Betoltes...';

  @override
  String get equipment_detail_modelLabel => 'Modell';

  @override
  String get equipment_detail_nextServiceDueLabel =>
      'Kovetkezo szerviz esedekesseg';

  @override
  String get equipment_detail_notFoundMessage =>
      'Ez a felszereles mar nem letezik.';

  @override
  String get equipment_detail_notFoundTitle => 'Felszereles nem talalhato';

  @override
  String get equipment_detail_notesTitle => 'Megjegyzesek';

  @override
  String get equipment_detail_ownedForLabel => 'Birtoklasi ido';

  @override
  String get equipment_detail_purchaseDateLabel => 'Vasarlas datuma';

  @override
  String get equipment_detail_purchasePriceLabel => 'Vasarlasi ar';

  @override
  String get equipment_detail_retiredChip => 'Kivont';

  @override
  String get equipment_detail_serialNumberLabel => 'Sorozatszam';

  @override
  String get equipment_detail_serviceInfoTitle => 'Szerviz informaciok';

  @override
  String get equipment_detail_serviceIntervalLabel => 'Szerviz intervallum';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days nap';
  }

  @override
  String get equipment_detail_serviceOverdue => 'A szerviz lejartt!';

  @override
  String get equipment_detail_sizeLabel => 'Meret';

  @override
  String get equipment_detail_statusLabel => 'Allapot';

  @override
  String equipment_detail_tripsCountPlural(Object count) {
    return '$count utazas';
  }

  @override
  String equipment_detail_tripsCountSingular(Object count) {
    return '$count utazas';
  }

  @override
  String get equipment_detail_tripsLabel => 'Utazasok';

  @override
  String get equipment_detail_tripsSemanticLabel =>
      'Utazasok megtekintese ezzel a felszerelessel';

  @override
  String get equipment_edit_appBar_editTitle => 'Felszereles szerkesztese';

  @override
  String get equipment_edit_appBar_newTitle => 'Uj felszereles';

  @override
  String get equipment_edit_appBar_saveButton => 'Mentes';

  @override
  String get equipment_edit_appBar_saveTooltip =>
      'Felszereles valtozasainak mentese';

  @override
  String get equipment_edit_brandLabel => 'Marka';

  @override
  String get equipment_edit_clearDate => 'Datum torlese';

  @override
  String get equipment_edit_currencyLabel => 'Penznem';

  @override
  String get equipment_edit_disableReminders => 'Emlekeztetsek kikapcsolasa';

  @override
  String get equipment_edit_disableRemindersSubtitle =>
      'Osszes ertesites kikapcsolasa ehhez az elemhez';

  @override
  String get equipment_edit_discardDialog_content =>
      'Mentetlen valtozasai vannak. Biztosan el akar tavozni?';

  @override
  String get equipment_edit_discardDialog_discard => 'Eldobas';

  @override
  String get equipment_edit_discardDialog_keepEditing =>
      'Szerkesztes folytatasa';

  @override
  String get equipment_edit_discardDialog_title => 'Valtozasok eldobasa?';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => 'Megse';

  @override
  String get equipment_edit_embeddedHeader_editTitle =>
      'Felszereles szerkesztese';

  @override
  String get equipment_edit_embeddedHeader_newTitle => 'Uj felszereles';

  @override
  String get equipment_edit_embeddedHeader_saveButton => 'Mentes';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit =>
      'Felszereles valtozasainak mentese';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new =>
      'Uj felszereles hozzaadasa';

  @override
  String equipment_edit_errorMessage(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get equipment_edit_errorTitle => 'Hiba';

  @override
  String get equipment_edit_lastServiceDateLabel => 'Utolso szerviz datuma';

  @override
  String get equipment_edit_loadingTitle => 'Betoltes...';

  @override
  String get equipment_edit_modelLabel => 'Modell';

  @override
  String get equipment_edit_nameHint => 'pl. Elsodleges automata';

  @override
  String get equipment_edit_nameLabel => 'Nev *';

  @override
  String get equipment_edit_nameValidation => 'Kerem adjon meg egy nevet';

  @override
  String get equipment_edit_notFoundMessage =>
      'Ez a felszereles mar nem letezik.';

  @override
  String get equipment_edit_notFoundTitle => 'Felszereles nem talalhato';

  @override
  String get equipment_edit_notesHint =>
      'Tovabbi megjegyzesek a felszerelesrol...';

  @override
  String get equipment_edit_notesLabel => 'Megjegyzesek';

  @override
  String get equipment_edit_notificationsSubtitle =>
      'Globalis ertesitesi beallitasok felulbiralasa ehhez az elemhez';

  @override
  String get equipment_edit_notificationsTitle => 'Ertesitesek (opcionalis)';

  @override
  String get equipment_edit_purchaseDateLabel => 'Vasarlas datuma';

  @override
  String get equipment_edit_purchaseInfoTitle => 'Vasarlasi informaciok';

  @override
  String get equipment_edit_purchasePriceLabel => 'Vasarlasi ar';

  @override
  String get equipment_edit_remindMeBeforeServiceDue =>
      'Emlekeztetss a szerviz esedekesseg elott:';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days nap';
  }

  @override
  String get equipment_edit_saveButton_edit => 'Valtozasok mentese';

  @override
  String get equipment_edit_saveButton_new => 'Felszereles hozzaadasa';

  @override
  String get equipment_edit_saveTooltip_edit =>
      'Felszereles valtozasainak mentese';

  @override
  String get equipment_edit_saveTooltip_new => 'Uj felszereles hozzaadasa';

  @override
  String get equipment_edit_selectDate => 'Datum kivalasztasa';

  @override
  String get equipment_edit_serialNumberLabel => 'Sorozatszam';

  @override
  String get equipment_edit_serviceIntervalHint => 'pl. 365 az eves szervizhez';

  @override
  String get equipment_edit_serviceIntervalLabel => 'Szerviz intervallum (nap)';

  @override
  String get equipment_edit_serviceSettingsTitle => 'Szerviz beallitasok';

  @override
  String get equipment_edit_sizeHint => 'pl. M, L, 42';

  @override
  String get equipment_edit_sizeLabel => 'Meret';

  @override
  String get equipment_edit_snackbar_added => 'Felszereles hozzaadva';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return 'Hiba a felszereles mentesekor: $error';
  }

  @override
  String get equipment_edit_snackbar_updated => 'Felszereles frissitve';

  @override
  String get equipment_edit_statusLabel => 'Allapot';

  @override
  String get equipment_edit_typeLabel => 'Tipus *';

  @override
  String get equipment_edit_useCustomReminders =>
      'Egyedi emlekeztetsek hasznalata';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'Eltero emlekeztetesi napok beallitasa ehhez az elemhez';

  @override
  String get equipment_fab_addEquipment => 'Felszereles hozzaadasa';

  @override
  String get equipment_list_emptyState_addFirstButton =>
      'Elso felszereles hozzaadasa';

  @override
  String get equipment_list_emptyState_addPrompt =>
      'Adja hozza buvarfelszereleset a hasznalat es szerviz koveTesehez';

  @override
  String get equipment_list_emptyState_filterText_equipment => 'felszereles';

  @override
  String get equipment_list_emptyState_filterText_serviceDue =>
      'szervizre szorulo felszereles';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return '$status felszereles';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return 'Nincs $filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch =>
      'Nincs ilyen allapotu felszereles';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate =>
      'Minden felszerelese naprakesz a szervizzel!';

  @override
  String equipment_list_errorLoading(Object error) {
    return 'Hiba a felszereles betoltesekor: $error';
  }

  @override
  String get equipment_list_filterAll => 'Osszes felszereles';

  @override
  String get equipment_list_filterLabel => 'Szuro:';

  @override
  String get equipment_list_filterServiceDue => 'Szerviz esedek';

  @override
  String get equipment_list_retryButton => 'Ujra';

  @override
  String get equipment_list_searchTooltip => 'Felszereles keresese';

  @override
  String get equipment_list_setsTooltip => 'Felszereles csoportok';

  @override
  String get equipment_list_sortTitle => 'Felszereles rendezese';

  @override
  String get equipment_list_sortTooltip => 'Rendezes';

  @override
  String equipment_list_tile_daysCount(Object days) {
    return '$days nap';
  }

  @override
  String get equipment_list_tile_serviceDueChip => 'Szerviz esedek';

  @override
  String get equipment_list_tile_serviceIn => 'Szerviz';

  @override
  String get equipment_menu_delete => 'Torles';

  @override
  String get equipment_menu_markAsServiced => 'Megjeloles szervizeltkentt';

  @override
  String get equipment_menu_reactivate => 'Ujraaktivalas';

  @override
  String get equipment_menu_retireEquipment => 'Felszereles kivonas';

  @override
  String get equipment_search_backTooltip => 'Vissza';

  @override
  String get equipment_search_clearTooltip => 'Kereses torlese';

  @override
  String get equipment_search_fieldLabel => 'Felszereles keresese...';

  @override
  String get equipment_search_hint =>
      'Kereses nev, marka, modell vagy sorozatszam alapjan';

  @override
  String equipment_search_noResults(Object query) {
    return 'Nem talalhato felszereles \"$query\" keresesi kifejezesre';
  }

  @override
  String get equipment_serviceDialog_addButton => 'Hozzaadas';

  @override
  String get equipment_serviceDialog_addTitle => 'Szervizrekord hozzaadasa';

  @override
  String get equipment_serviceDialog_cancelButton => 'Megse';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip =>
      'Kovetkezo szerviz datum torlese';

  @override
  String get equipment_serviceDialog_costHint => '0.00';

  @override
  String get equipment_serviceDialog_costLabel => 'Koltseg';

  @override
  String get equipment_serviceDialog_costValidation =>
      'Adjon meg ervenyes osszeget';

  @override
  String get equipment_serviceDialog_editTitle => 'Szervizrekord szerkesztese';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel =>
      'Kovetkezo szerviz esedekesseg';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel =>
      'Kovetkezo szerviz datum kivalasztasa';

  @override
  String get equipment_serviceDialog_nextServiceNotSet => 'Nincs megadva';

  @override
  String get equipment_serviceDialog_notesLabel => 'Megjegyzesek';

  @override
  String get equipment_serviceDialog_providerHint => 'pl. Buvaruzlet neve';

  @override
  String get equipment_serviceDialog_providerLabel => 'Szolgaltato/Uzlet';

  @override
  String get equipment_serviceDialog_serviceDateLabel => 'Szerviz datuma';

  @override
  String get equipment_serviceDialog_serviceDateSemanticLabel =>
      'Szerviz datum kivalasztasa';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => 'Szerviz tipus';

  @override
  String get equipment_serviceDialog_snackbar_added =>
      'Szervizrekord hozzaadva';

  @override
  String equipment_serviceDialog_snackbar_error(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get equipment_serviceDialog_snackbar_updated =>
      'Szervizrekord frissitve';

  @override
  String get equipment_serviceDialog_updateButton => 'Frissites';

  @override
  String get equipment_service_addButton => 'Hozzaadas';

  @override
  String get equipment_service_deleteDialog_cancel => 'Megse';

  @override
  String get equipment_service_deleteDialog_confirm => 'Torles';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return 'Biztosan torli ezt a(z) $serviceType rekordot?';
  }

  @override
  String get equipment_service_deleteDialog_title => 'Szervizrekord torlese?';

  @override
  String get equipment_service_deleteMenuItem => 'Torles';

  @override
  String get equipment_service_editMenuItem => 'Szerkesztes';

  @override
  String get equipment_service_emptyState => 'Meg nincsenek szervizrekordok';

  @override
  String get equipment_service_historyTitle => 'Szerviz elozmeny';

  @override
  String get equipment_service_snackbar_deleted => 'Szervizrekord torolve';

  @override
  String get equipment_service_totalCostLabel => 'Osszes szerviz koltseg';

  @override
  String get equipment_setDetail_addEquipmentButton => 'Felszereles hozzaadasa';

  @override
  String get equipment_setDetail_deleteDialog_cancel => 'Megse';

  @override
  String get equipment_setDetail_deleteDialog_confirm => 'Torles';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      'Biztosan torli ezt a felszereles csoportot? A csoportban levo felszerelesek nem lesznek torolve.';

  @override
  String get equipment_setDetail_deleteDialog_title =>
      'Felszereles csoport torlese';

  @override
  String get equipment_setDetail_deleteMenuItem => 'Torles';

  @override
  String get equipment_setDetail_editTooltip => 'Csoport szerkesztese';

  @override
  String get equipment_setDetail_emptySet =>
      'Nincs felszereles ebben a csoportban';

  @override
  String get equipment_setDetail_equipmentInSetTitle =>
      'Felszerelesek ebben a csoportban';

  @override
  String equipment_setDetail_errorMessage(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get equipment_setDetail_errorTitle => 'Hiba';

  @override
  String get equipment_setDetail_loadingTitle => 'Betoltes...';

  @override
  String get equipment_setDetail_notFoundMessage =>
      'Ez a felszereles csoport mar nem letezik.';

  @override
  String get equipment_setDetail_notFoundTitle => 'Csoport nem talalhato';

  @override
  String get equipment_setDetail_snackbar_deleted =>
      'Felszereles csoport torolve';

  @override
  String get equipment_setEdit_addEquipmentFirst =>
      'Elobb adjon hozza felszerelest a csoport letrehozasa elott.';

  @override
  String get equipment_setEdit_appBar_editTitle => 'Csoport szerkesztese';

  @override
  String get equipment_setEdit_appBar_newTitle => 'Uj felszereles csoport';

  @override
  String get equipment_setEdit_descriptionHint => 'Opcionalis leiras...';

  @override
  String get equipment_setEdit_descriptionLabel => 'Leiras';

  @override
  String equipment_setEdit_errorMessage(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get equipment_setEdit_errorTitle => 'Hiba';

  @override
  String get equipment_setEdit_loadingTitle => 'Betoltes...';

  @override
  String get equipment_setEdit_nameHint => 'pl. Meleg vizi felszereles';

  @override
  String get equipment_setEdit_nameLabel => 'Csoport neve *';

  @override
  String get equipment_setEdit_nameValidation => 'Kerem adjon meg egy nevet';

  @override
  String get equipment_setEdit_noEquipmentAvailable =>
      'Nem erheto el felszereles';

  @override
  String get equipment_setEdit_notFoundMessage =>
      'Ez a felszereles csoport mar nem letezik.';

  @override
  String get equipment_setEdit_notFoundTitle => 'Csoport nem talalhato';

  @override
  String get equipment_setEdit_saveButton_edit => 'Valtozasok mentese';

  @override
  String get equipment_setEdit_saveButton_new => 'Csoport letrehozasa';

  @override
  String get equipment_setEdit_saveTooltip_edit =>
      'Felszereles csoport valtozasainak mentese';

  @override
  String get equipment_setEdit_saveTooltip_new =>
      'Uj felszereles csoport letrehozasa';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle =>
      'Valassza ki a csoportba felveendo felszereleseket.';

  @override
  String get equipment_setEdit_selectEquipmentTitle =>
      'Felszereles kivalasztasa';

  @override
  String get equipment_setEdit_snackbar_created =>
      'Felszereles csoport letrehozva';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return 'Hiba a felszereles csoport mentesekor: $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated =>
      'Felszereles csoport frissitve';

  @override
  String get equipment_sets_appBar_title => 'Felszereles csoportok';

  @override
  String get equipment_sets_emptyState_createFirstButton =>
      'Elso csoport letrehozasa';

  @override
  String get equipment_sets_emptyState_description =>
      'Hozzon letre felszereles csoportokat, hogy gyorsan hozzaadhassa a gyakran hasznalt felszereleseket a meruleseihez.';

  @override
  String get equipment_sets_emptyState_title =>
      'Nincsenek felszereles csoportok';

  @override
  String equipment_sets_errorLoading(Object error) {
    return 'Hiba a csoportok betoltesekor: $error';
  }

  @override
  String get equipment_sets_fabTooltip => 'Uj felszereles csoport letrehozasa';

  @override
  String get equipment_sets_fab_createSet => 'Csoport letrehozasa';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count elem';
  }

  @override
  String equipment_sets_itemCountSemanticLabel(Object count) {
    return '$count a csoportban';
  }

  @override
  String equipment_sets_itemCountSingular(Object count) {
    return '$count elem';
  }

  @override
  String get equipment_sets_retryButton => 'Ujra';

  @override
  String get equipment_snackbar_deleted => 'Felszereles torolve';

  @override
  String get equipment_snackbar_markedAsServiced => 'Szervizeltnek jelolve';

  @override
  String get equipment_snackbar_reactivated => 'Felszereles ujraaktivalva';

  @override
  String get equipment_snackbar_retired => 'Felszereles kivonva';

  @override
  String get equipment_summary_active => 'Aktiv';

  @override
  String get equipment_summary_addEquipmentButton => 'Felszereles hozzaadasa';

  @override
  String get equipment_summary_equipmentSetsButton => 'Felszereles csoportok';

  @override
  String get equipment_summary_overviewTitle => 'Attekintes';

  @override
  String get equipment_summary_quickActionsTitle => 'Gyorsmuveletek';

  @override
  String get equipment_summary_recentEquipmentTitle => 'Legutobbl felszereles';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name, $type';
  }

  @override
  String get equipment_summary_selectPrompt =>
      'Valasszon felszerelest a listabol a reszletek megtekIntesehez';

  @override
  String get equipment_summary_serviceDue => 'Szerviz esedek';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name, $type, szerviz esedek';
  }

  @override
  String get equipment_summary_serviceDueTitle => 'Szerviz esedek';

  @override
  String get equipment_summary_title => 'Felszereles';

  @override
  String get equipment_summary_totalItems => 'Osszes elem';

  @override
  String get equipment_summary_totalValue => 'Osszes ertek';

  @override
  String get formatter_approximate_prefix => '~';

  @override
  String get formatter_connector_at => 'helyen';

  @override
  String get formatter_connector_from => 'Ettol';

  @override
  String get formatter_connector_until => 'Eddig';

  @override
  String get gas_air_description => 'Standard levego (21% O2)';

  @override
  String get gas_air_displayName => 'Levego';

  @override
  String get gas_diluentAir_description =>
      'Standard levego higigaz sekely CCR-hez';

  @override
  String get gas_diluentAir_displayName => 'Levego higigaz';

  @override
  String get gas_diluentTx1070_description =>
      'Hipoxikus higigaz nagyon mely CCR-hez';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description => 'Hipoxikus higigaz mely CCR-hez';

  @override
  String get gas_diluentTx1260_displayName => 'Tx 12/60';

  @override
  String get gas_ean32_description => 'Dusitott levego Nitrox 32%';

  @override
  String get gas_ean32_displayName => 'EAN32';

  @override
  String get gas_ean36_description => 'Dusitott levego Nitrox 36%';

  @override
  String get gas_ean36_displayName => 'EAN36';

  @override
  String get gas_ean40_description => 'Dusitott levego Nitrox 40%';

  @override
  String get gas_ean40_displayName => 'EAN40';

  @override
  String get gas_ean50_description => 'Deko gaz - 50% O2';

  @override
  String get gas_ean50_displayName => 'EAN50';

  @override
  String get gas_helitrox2525_description =>
      'Helitrox 25/25 (rekreaccios tech)';

  @override
  String get gas_helitrox2525_displayName => 'Helitrox 25/25';

  @override
  String get gas_oxygen_description => 'Tiszta oxigen (csak 6m deko)';

  @override
  String get gas_oxygen_displayName => 'Oxigen';

  @override
  String get gas_scrEan40_description => 'SCR torlogaz - 40% O2';

  @override
  String get gas_scrEan40_displayName => 'SCR EAN40';

  @override
  String get gas_scrEan50_description => 'SCR torlogaz - 50% O2';

  @override
  String get gas_scrEan50_displayName => 'SCR EAN50';

  @override
  String get gas_scrEan60_description => 'SCR torlogaz - 60% O2';

  @override
  String get gas_scrEan60_displayName => 'SCR EAN60';

  @override
  String get gas_tmx1555_description => 'Hipoxikus trimix 15/55 (nagyon mely)';

  @override
  String get gas_tmx1555_displayName => 'Tx 15/55';

  @override
  String get gas_tmx1845_description => 'Trimix 18/45 (melymerules)';

  @override
  String get gas_tmx1845_displayName => 'Tx 18/45';

  @override
  String get gas_tmx2135_description => 'Normoxikus trimix 21/35';

  @override
  String get gas_tmx2135_displayName => 'Tx 21/35';

  @override
  String get gasCalculators_bestMix_bestOxygenMix => 'Legjobb oxigén keverék';

  @override
  String get gasCalculators_bestMix_commonMixesRef =>
      'Általános keverékek referencia';

  @override
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2) {
    return 'Levegő MOD túllépve ppO₂ $ppO2 mellett';
  }

  @override
  String get gasCalculators_bestMix_targetDepth => 'Célmélység';

  @override
  String get gasCalculators_bestMix_targetDive => 'Célmerülés';

  @override
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  ) {
    return 'Környezeti nyomás $depth$depthSymbol mélységben';
  }

  @override
  String get gasCalculators_consumption_avgDepth => 'Átlagos mélység';

  @override
  String get gasCalculators_consumption_breakdown => 'Számítás részletezése';

  @override
  String get gasCalculators_consumption_diveTime => 'Merülési idő';

  @override
  String gasCalculators_consumption_exceedsTank(
    Object pressure,
    Object symbol,
  ) {
    return 'Meghaladja a palack kapacitását ($pressure $symbol)';
  }

  @override
  String get gasCalculators_consumption_gasAtDepth =>
      'Gázfogyasztás mélységben';

  @override
  String get gasCalculators_consumption_pressure => 'Nyomás';

  @override
  String get gasCalculators_consumption_remainingGas => 'Maradék gáz';

  @override
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  ) {
    return 'Palack kapacitás ($tankSize$volumeSymbol @ $fillPressure $pressureSymbol)';
  }

  @override
  String get gasCalculators_consumption_title => 'Gázfogyasztás';

  @override
  String gasCalculators_consumption_totalGas(Object time) {
    return 'Összes gáz $time percre';
  }

  @override
  String get gasCalculators_consumption_volume => 'Térfogat';

  @override
  String get gasCalculators_mod_aboutMod => 'A MOD-ról';

  @override
  String get gasCalculators_mod_aboutModBody =>
      'Alacsonyabb O₂ = mélyebb MOD = rövidebb NDL';

  @override
  String get gasCalculators_mod_inputParameters => 'Bemeneti paraméterek';

  @override
  String get gasCalculators_mod_maximumOperatingDepth =>
      'Maximum működési mélység';

  @override
  String get gasCalculators_mod_oxygenO2 => 'Oxigén (O₂)';

  @override
  String get gasCalculators_mod_ppO2Conservative =>
      'Konzervatív limit hosszabb fenék időhöz';

  @override
  String get gasCalculators_mod_ppO2Maximum =>
      'Maximum limit csak dekompressziós megállókhoz';

  @override
  String get gasCalculators_mod_ppO2Standard =>
      'Standard munkálati limit szabadidős merüléshez';

  @override
  String get gasCalculators_ppO2Limit => 'ppO₂ limit';

  @override
  String get gasCalculators_resetAll => 'Összes kalkulátor visszaállítása';

  @override
  String get gasCalculators_sacRate => 'SAC érték';

  @override
  String get gasCalculators_tab_bestMix => 'Legjobb keverék';

  @override
  String get gasCalculators_tab_consumption => 'Fogyasztás';

  @override
  String get gasCalculators_tab_mod => 'MOD';

  @override
  String get gasCalculators_tab_rockBottom => 'Tartalék minimum';

  @override
  String get gasCalculators_tankSize => 'Palack méret';

  @override
  String get gasCalculators_title => 'Gáz kalkulátorok';

  @override
  String get marineLife_siteSection_editExpectedTooltip =>
      'Vart fajok szerkesztese';

  @override
  String get marineLife_siteSection_errorLoadingExpected =>
      'Hiba a vart fajok betoltesekor';

  @override
  String get marineLife_siteSection_errorLoadingSightings =>
      'Hiba az eszlelesek betoltesekor';

  @override
  String get marineLife_siteSection_expectedSpecies => 'Vart fajok';

  @override
  String get marineLife_siteSection_noExpected =>
      'Nincsenek vart fajok hozzaadva';

  @override
  String get marineLife_siteSection_noSpotted =>
      'Meg nem eszleltek tengeri elolenyt';

  @override
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  ) {
    return '$name, $count alkalommal észlelve';
  }

  @override
  String get marineLife_siteSection_spottedHere => 'Itt eszlelve';

  @override
  String get marineLife_siteSection_title => 'Tengeri elet';

  @override
  String get marineLife_speciesDetail_backTooltip => 'Vissza';

  @override
  String get marineLife_speciesDetail_depthRangeTitle => 'Melyseg tartomany';

  @override
  String get marineLife_speciesDetail_descriptionTitle => 'Leiras';

  @override
  String get marineLife_speciesDetail_divesLabel => 'Merülesek';

  @override
  String get marineLife_speciesDetail_editTooltip => 'Faj szerkesztese';

  @override
  String marineLife_speciesDetail_errorPrefix(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get marineLife_speciesDetail_noSightings =>
      'Meg nincsenek rogzitett eszlelesek';

  @override
  String get marineLife_speciesDetail_notFound => 'Faj nem talalhato';

  @override
  String marineLife_speciesDetail_sightingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'eszleles',
      one: 'eszleles',
    );
    return '$count $_temp0';
  }

  @override
  String get marineLife_speciesDetail_sightingPeriodTitle =>
      'Eszlelesi idoszak';

  @override
  String get marineLife_speciesDetail_sightingStatsTitle =>
      'Eszlelesi statisztikak';

  @override
  String get marineLife_speciesDetail_sitesLabel => 'Merülohelyek';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return 'Osztaly: $className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle => 'Legjobb merülohelyek';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel => 'Osszes eszleles';

  @override
  String get marineLife_speciesEdit_addTitle => 'Faj hozzaadasa';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return '\"$name\" hozzaadva';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => 'Vissza';

  @override
  String get marineLife_speciesEdit_categoryLabel => 'Kategoria';

  @override
  String get marineLife_speciesEdit_commonNameError =>
      'Kerem, adja meg a köznapi nevet';

  @override
  String get marineLife_speciesEdit_commonNameHint => 'pl. Bohochal';

  @override
  String get marineLife_speciesEdit_commonNameLabel => 'Köznapi nev';

  @override
  String get marineLife_speciesEdit_descriptionHint => 'A faj rovid leirasa...';

  @override
  String get marineLife_speciesEdit_descriptionLabel => 'Leiras';

  @override
  String get marineLife_speciesEdit_editTitle => 'Faj szerkesztese';

  @override
  String marineLife_speciesEdit_errorLoading(Object error) {
    return 'Hiba a faj betoltesekor: $error';
  }

  @override
  String marineLife_speciesEdit_errorSaving(Object error) {
    return 'Hiba a faj mentesekor: $error';
  }

  @override
  String get marineLife_speciesEdit_saveButton => 'Mentes';

  @override
  String get marineLife_speciesEdit_scientificNameHint =>
      'pl. Amphiprion ocellaris';

  @override
  String get marineLife_speciesEdit_scientificNameLabel => 'Tudomanyos nev';

  @override
  String get marineLife_speciesEdit_taxonomyClassHint => 'pl. Actinopterygii';

  @override
  String get marineLife_speciesEdit_taxonomyClassLabel => 'Taxonómiai osztaly';

  @override
  String marineLife_speciesEdit_updatedSnackbar(Object name) {
    return '\"$name\" frissitve';
  }

  @override
  String get marineLife_speciesManage_allFilter => 'Mind';

  @override
  String get marineLife_speciesManage_appBarTitle => 'Fajok';

  @override
  String get marineLife_speciesManage_backTooltip => 'Vissza';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return 'Beepitett fajok ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => 'Megse';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return 'Nem torolheto \"$name\" - vannak eszlelesek hozza';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip => 'Kereses torlese';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return 'Egyedi fajok ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => 'Torles';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return 'Biztosan torli a(z) \"$name\" fajt?';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle => 'Faj torlese?';

  @override
  String get marineLife_speciesManage_deleteTooltip => 'Faj torlese';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return '\"$name\" torolve';
  }

  @override
  String get marineLife_speciesManage_editTooltip => 'Faj szerkesztese';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return 'Hiba a faj torlesekor: $error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return 'Hiba a fajok visszaallitasakor: $error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound => 'Nem talalhato faj';

  @override
  String get marineLife_speciesManage_resetButton => 'Visszaallitas';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      'Ez visszaallitja az osszes beepitett fajt az eredeti ertekekre. Az egyedi fajokat nem erinti. Az eszlelesekkel rendelkezo beepitett fajok frissitesre kerülnek, de megmaradnak.';

  @override
  String get marineLife_speciesManage_resetDialogTitle =>
      'Visszaallitas az alapertekekre?';

  @override
  String get marineLife_speciesManage_resetSuccess =>
      'Beepitett fajok visszaallitva az alapertekekre';

  @override
  String get marineLife_speciesManage_resetToDefaults =>
      'Visszaallitas az alapertekekre';

  @override
  String get marineLife_speciesManage_searchHint => 'Fajok keresese...';

  @override
  String get marineLife_speciesPicker_allFilter => 'Mind';

  @override
  String get marineLife_speciesPicker_cancelButton => 'Megse';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip => 'Kereses torlese';

  @override
  String get marineLife_speciesPicker_closeTooltip => 'Fajvalaszto bezarasa';

  @override
  String get marineLife_speciesPicker_doneButton => 'Kesz';

  @override
  String marineLife_speciesPicker_error(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get marineLife_speciesPicker_noSpeciesFound => 'Nem talalhato faj';

  @override
  String get marineLife_speciesPicker_searchHint => 'Fajok keresese...';

  @override
  String marineLife_speciesPicker_selectedCount(Object count) {
    return '$count kivalasztva';
  }

  @override
  String get marineLife_speciesPicker_title => 'Fajok kivalasztasa';

  @override
  String get media_diveMediaSection_addTooltip => 'Foto vagy video hozzaadasa';

  @override
  String get media_diveMediaSection_cancelButton => 'Megse';

  @override
  String get media_diveMediaSection_emptyState => 'Meg nincsenek fotok';

  @override
  String get media_diveMediaSection_errorLoading => 'Hiba a media betoltesekor';

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Foto megtekintese. Hosszu nyomas a levalasztashoz';

  @override
  String get media_diveMediaSection_title => 'Fotok es videok';

  @override
  String get media_diveMediaSection_unlinkButton => 'Levalasztas';

  @override
  String get media_diveMediaSection_unlinkDialogContent =>
      'Eltavolitja ezt a fotot a merülesrol? A foto megmarad a galeriadjaban.';

  @override
  String get media_diveMediaSection_unlinkDialogTitle => 'Foto levalasztasa';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Nem sikerult a levalasztas: $error';
  }

  @override
  String get media_diveMediaSection_unlinkSuccess => 'Foto levalasztva';

  @override
  String get media_gpsBanner_addToSiteButton => 'Hozzaadas a merülohelyhez';

  @override
  String media_gpsBanner_coordinates(Object latitude, Object longitude) {
    return 'Koordinatak: $latitude, $longitude';
  }

  @override
  String get media_gpsBanner_createSiteButton => 'Merülohely letrehozasa';

  @override
  String get media_gpsBanner_dismissTooltip => 'GPS javaslat elvetese';

  @override
  String get media_gpsBanner_title => 'GPS adat talalhato a fotokban';

  @override
  String media_import_failedToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fotot',
      one: 'fotot',
    );
    return 'Nem sikerult importalni $_temp0';
  }

  @override
  String media_import_failedToImportError(Object error) {
    return 'Nem sikerult a fotok importalasa: $error';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return '$imported importalva, $failed sikertelen';
  }

  @override
  String media_import_importedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto',
      one: 'foto',
    );
    return '$count $_temp0 importalva';
  }

  @override
  String media_import_importingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto',
      one: 'foto',
    );
    return '$count $_temp0 importalasa...';
  }

  @override
  String get media_miniProfile_headerLabel => 'Merülesi profil';

  @override
  String get media_miniProfile_semanticLabel => 'Mini merülesi profil diagram';

  @override
  String get media_photoPicker_appBarTitle => 'Fotok kivalasztasa';

  @override
  String get media_photoPicker_closeTooltip => 'Fotoválaszto bezarasa';

  @override
  String get media_photoPicker_doneButton => 'Kesz';

  @override
  String media_photoPicker_doneCountButton(Object count) {
    return 'Kesz ($count)';
  }

  @override
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  ) {
    return 'Nem talalhatok fotok $startDate $startTime es $endDate $endTime kozott.';
  }

  @override
  String get media_photoPicker_emptyTitle => 'Nincsenek fotok';

  @override
  String get media_photoPicker_grantAccessButton => 'Hozzaferes engedelyezese';

  @override
  String get media_photoPicker_openSettingsButton => 'Beallitasok megnyitasa';

  @override
  String get media_photoPicker_openSettingsSnackbar =>
      'Kerem, nyissa meg a Beallitasokat es engedelyezze a fotohozzaferest';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'A fotogaleriahoz valo hozzaferes megtagadva. Kerem, engedelyezze a Beallitasokban a merülesi fotok hozzaadasahoz.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'A Submersion hozzaferest igenyel a fotogaleriajahoz merülesi fotok hozzaadasahoz.';

  @override
  String get media_photoPicker_permissionTitle => 'Foto hozzaferes szukseges';

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return 'Fotok megjelenites: $rangeText';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel =>
      'Foto kivalasztasanak valtoztatas';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel =>
      'Foto kivalasztasanak valtoztatas, kivalasztva';

  @override
  String get media_photoViewer_cannotShare => 'Nem oszthato meg ez a foto';

  @override
  String get media_photoViewer_cannotWriteMetadata =>
      'Nem irhato metaadat - a media nincs a konyvtarhoz csatolva';

  @override
  String get media_photoViewer_closeTooltip => 'Foto megtekintobezerarasa';

  @override
  String get media_photoViewer_diveDataWrittenToPhoto =>
      'Merülesi adatok irva a fotora';

  @override
  String get media_photoViewer_diveDataWrittenToVideo =>
      'Merülesi adatok irva a videora';

  @override
  String media_photoViewer_errorLoadingPhotos(Object error) {
    return 'Hiba a fotok betoltesekor: $error';
  }

  @override
  String get media_photoViewer_failedToLoadImage =>
      'Nem sikerult a kep betoltese';

  @override
  String get media_photoViewer_failedToLoadVideo =>
      'Nem sikerult a video betoltese';

  @override
  String media_photoViewer_failedToShare(Object error) {
    return 'Nem sikerult a megosztas: $error';
  }

  @override
  String get media_photoViewer_failedToWriteMetadata =>
      'Nem sikerult a metaadat irasa';

  @override
  String media_photoViewer_failedToWriteMetadataError(Object error) {
    return 'Nem sikerult a metaadat irasa: $error';
  }

  @override
  String get media_photoViewer_noPhotosAvailable => 'Nincsenek elerheto fotok';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel =>
      'Video lejatszasa vagy szüneteltetese';

  @override
  String get media_photoViewer_seekVideoLabel => 'Video pozicio keresese';

  @override
  String get media_photoViewer_shareTooltip => 'Foto megosztasa';

  @override
  String get media_photoViewer_toggleOverlayLabel =>
      'Foto feliratok ki/be kapcsolasa';

  @override
  String get media_photoViewer_videoFileNotFound => 'Video fajl nem talalhato';

  @override
  String get media_photoViewer_videoNotLinked =>
      'A video nincs a konyvtarhoz csatolva';

  @override
  String get media_photoViewer_writeDiveDataTooltip =>
      'Merülesi adatok irasa a fotora';

  @override
  String get media_quickSiteDialog_cancelButton => 'Megse';

  @override
  String get media_quickSiteDialog_createButton => 'Merülohely letrehozasa';

  @override
  String get media_quickSiteDialog_description =>
      'Uj merülohely letrehozasa a foto GPS koordinatai alapjan.';

  @override
  String get media_quickSiteDialog_siteNameError =>
      'Kerem, adja meg a merülohely nevet';

  @override
  String get media_quickSiteDialog_siteNameHint =>
      'Adjon meg egy nevet ehhez a merülohelyhez';

  @override
  String get media_quickSiteDialog_siteNameLabel => 'Merülohely neve';

  @override
  String get media_quickSiteDialog_title => 'Merülohely letrehozasa';

  @override
  String get media_scanResults_allPhotosLinked =>
      'Minden foto mar csatolva van';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return 'Az ut mind a(z) $count fotoja mar csatolva van merülesekhez.';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count foto mar csatolva';
  }

  @override
  String get media_scanResults_cancelButton => 'Megse';

  @override
  String media_scanResults_diveNumber(Object number) {
    return '#$number. merüles';
  }

  @override
  String media_scanResults_foundNewPhotos(Object count) {
    return '$count uj foto talalva';
  }

  @override
  String get media_scanResults_linkButton => 'Csatolas';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return '$count foto csatolasa';
  }

  @override
  String get media_scanResults_noPhotosFound => 'Nem talalhatok fotok';

  @override
  String get media_scanResults_okButton => 'OK';

  @override
  String get media_scanResults_unknownSite => 'Ismeretlen merülohely';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return '$count foto nem volt hozzarendelheto egyetlen merüleshez sem (a merülesi idokon kivul keszült)';
  }

  @override
  String get media_writeMetadata_cancelButton => 'Megse';

  @override
  String get media_writeMetadata_depthLabel => 'Melyseg';

  @override
  String get media_writeMetadata_descriptionPhoto =>
      'A kovetkezo metaadatok kerülnek a fotora:';

  @override
  String get media_writeMetadata_descriptionVideo =>
      'A kovetkezo metaadatok kerülnek a videora:';

  @override
  String get media_writeMetadata_diveTimeLabel => 'Merülesi ido';

  @override
  String get media_writeMetadata_gpsLabel => 'GPS';

  @override
  String get media_writeMetadata_keepOriginalVideo =>
      'Eredeti video megtartasa';

  @override
  String get media_writeMetadata_noDataAvailable =>
      'Nincs elerheto merülesi adat az irashoz.';

  @override
  String get media_writeMetadata_siteLabel => 'Merülohely';

  @override
  String get media_writeMetadata_temperatureLabel => 'Homerseklet';

  @override
  String get media_writeMetadata_titlePhoto => 'Merülesi adatok irasa a fotora';

  @override
  String get media_writeMetadata_titleVideo =>
      'Merülesi adatok irasa a videora';

  @override
  String get media_writeMetadata_warningPhotoText =>
      'Ez modositja az eredeti fotot.';

  @override
  String get media_writeMetadata_warningVideoText =>
      'Egy uj video keszül a metaadatokkal. A video metaadatok nem modosithatok helyben.';

  @override
  String get media_writeMetadata_writeButton => 'Iras';

  @override
  String get nav_buddies => 'Buddyk';

  @override
  String get nav_certifications => 'Kepesitesek';

  @override
  String get nav_courses => 'Tanfolyamok';

  @override
  String get nav_coursesSubtitle => 'Kepzes es oktatas';

  @override
  String get nav_diveCenters => 'Merulocentrumok';

  @override
  String get nav_dives => 'Merulesek';

  @override
  String get nav_equipment => 'Felszereles';

  @override
  String get nav_home => 'Fooldal';

  @override
  String get nav_more => 'Tovabb';

  @override
  String get nav_planning => 'Tervezes';

  @override
  String get nav_planningSubtitle => 'Merulestervezo, szamologepek';

  @override
  String get nav_settings => 'Beallitasok';

  @override
  String get nav_sites => 'Merulohelyek';

  @override
  String get nav_statistics => 'Statisztikak';

  @override
  String get nav_tooltip_closeMenu => 'Menu bezarasa';

  @override
  String get nav_tooltip_collapseMenu => 'Menu osszecsuklasa';

  @override
  String get nav_tooltip_expandMenu => 'Menu kinyitasa';

  @override
  String get nav_transfer => 'Atvitel';

  @override
  String get nav_trips => 'Utak';

  @override
  String get onboarding_welcome_createProfile => 'Profil létrehozása';

  @override
  String get onboarding_welcome_createProfileSubtitle =>
      'Add meg a neved a kezdéshez. Később további részleteket adhatsz hozzá.';

  @override
  String get onboarding_welcome_creating => 'Létrehozás...';

  @override
  String onboarding_welcome_errorCreatingProfile(Object error) {
    return 'Hiba a profil létrehozásakor: $error';
  }

  @override
  String get onboarding_welcome_getStarted => 'Kezdés';

  @override
  String get onboarding_welcome_nameHint => 'Add meg a neved';

  @override
  String get onboarding_welcome_nameLabel => 'Neved';

  @override
  String get onboarding_welcome_nameValidation => 'Add meg a neved';

  @override
  String get onboarding_welcome_subtitle => 'Fejlett merülés napló és elemzés';

  @override
  String get onboarding_welcome_title => 'Üdvözöl a Submersion';

  @override
  String get planning_appBar_title => 'Tervezes';

  @override
  String get planning_card_decoCalculator_description =>
      'Szamitsa ki a dekompresszios limiteket, a szükseges deko megalloket es a CNS/OTU terhelest többszintu merülesi profilokhoz.';

  @override
  String get planning_card_decoCalculator_subtitle =>
      'Merülesek tervezese dekompressziós megallokkal';

  @override
  String get planning_card_decoCalculator_title => 'Deko kalkulator';

  @override
  String get planning_card_divePlanner_description =>
      'Tervezzen összetett merüleseket több melysegi szinttel, gazvaltas lehetoseggel es automatikus dekompresszios megallo szamitassal.';

  @override
  String get planning_card_divePlanner_subtitle =>
      'Többszintu merülesi tervek keszitese';

  @override
  String get planning_card_divePlanner_title => 'Merüles tervezo';

  @override
  String get planning_card_gasCalculators_description =>
      'Negy specialis gaz kalkulator:\n• MOD - Maximalis üzemi melyseg egy gazkeverekhez\n• Legjobb keverek - Idealis O₂% egy cel melyseghez\n• Fogyasztas - Gaz felhasznalás becsles\n• Rock Bottom - Veszhelyzeti tartalek szamitas';

  @override
  String get planning_card_gasCalculators_subtitle =>
      'MOD, Legjobb keverek, Fogyasztas, Rock Bottom';

  @override
  String get planning_card_gasCalculators_title => 'Gaz kalkulatorok';

  @override
  String get planning_card_surfaceInterval_description =>
      'Szamitsa ki a merülesek közötti minimalis felszini idot a szöveti terhelés alapjan. Vizualizalja, hogyan gaztalanitodik a 16 szoveti rekesz az ido függvenyében.';

  @override
  String get planning_card_surfaceInterval_subtitle =>
      'Ismetelt merülesek idointervallumainak tervezese';

  @override
  String get planning_card_surfaceInterval_title => 'Felszini idoköz';

  @override
  String get planning_card_weightCalculator_description =>
      'Becsülje meg a szükseges sulyt a merülesi ruha, palack anyag, viztipus es testsuly alapjan.';

  @override
  String get planning_card_weightCalculator_subtitle =>
      'Ajanlott suly az adott felszereleshez';

  @override
  String get planning_card_weightCalculator_title => 'Suly kalkulator';

  @override
  String get planning_info_disclaimer =>
      'Ezek az eszkozök kizarolag tervezesi celokat szolgalnak. Mindig ellenorizze a szamitasokat es kövesse merülesi kepzesenek iranyelveit.';

  @override
  String get planning_sidebar_appBar_title => 'Tervezes';

  @override
  String get planning_sidebar_decoCalculator_subtitle => 'NDL es deko megallok';

  @override
  String get planning_sidebar_decoCalculator_title => 'Deko kalkulator';

  @override
  String get planning_sidebar_divePlanner_subtitle =>
      'Többszintu merülesi tervek';

  @override
  String get planning_sidebar_divePlanner_title => 'Merüles tervezo';

  @override
  String get planning_sidebar_gasCalculators_subtitle =>
      'MOD, Legjobb keverek, tobb';

  @override
  String get planning_sidebar_gasCalculators_title => 'Gaz kalkulatorok';

  @override
  String get planning_sidebar_info_disclaimer =>
      'A tervezo eszkozök csak tajekoztatasi celokat szolgalnak. Mindig ellenorizze a szamitasokat.';

  @override
  String get planning_sidebar_surfaceInterval_subtitle =>
      'Ismetelt merüles tervezes';

  @override
  String get planning_sidebar_surfaceInterval_title => 'Felszini idoköz';

  @override
  String get planning_sidebar_weightCalculator_subtitle => 'Ajanlott suly';

  @override
  String get planning_sidebar_weightCalculator_title => 'Suly kalkulator';

  @override
  String get planning_welcome_quickTips_title => 'Gyors tippek';

  @override
  String get planning_welcome_subtitle =>
      'Valasszon egy eszkozöt az oldalsavbol a kezdeshez';

  @override
  String get planning_welcome_tip_decoCalculator =>
      'Deko kalkulator NDL es megallasi idok szamitasahoz';

  @override
  String get planning_welcome_tip_divePlanner =>
      'Merüles tervezo többszintu merülesek tervezesehez';

  @override
  String get planning_welcome_tip_gasCalculators =>
      'Gaz kalkulatorok MOD es gaz tervezeshez';

  @override
  String get planning_welcome_tip_weightCalculator =>
      'Suly kalkulator a trimm beallitasahoz';

  @override
  String get planning_welcome_title => 'Tervezo eszkozök';

  @override
  String get settings_about_aboutSubmersion => 'A Submersion-rol';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description =>
      'Kövesse nyomon merüleseit, kezelje felszereleset es fedezze fel a merülohelyeket.';

  @override
  String get settings_about_header => 'Rolunk';

  @override
  String get settings_about_openSourceLicenses => 'Nyilt forrasu licencek';

  @override
  String get settings_about_reportIssue => 'Hiba bejelentese';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Latogasson el: github.com/submersion/submersion';

  @override
  String settings_about_version(String version, String buildNumber) {
    return 'Verzio $version ($buildNumber)';
  }

  @override
  String get settings_appBar_title => 'Beallitasok';

  @override
  String get settings_appearance_appLanguage => 'Alkalmazas nyelve';

  @override
  String get settings_appearance_depthColoredCards =>
      'Melyseg szerint szinezett merülesi kartyak';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Merülesi kartyak megjelenites ocean-szinu hatterrel a melyseg alapjan';

  @override
  String get settings_appearance_cardColorAttribute => 'Kartyak szinezese';

  @override
  String get settings_appearance_cardColorAttribute_subtitle =>
      'Valassza ki, melyik jellemzo hatarozza meg a kartya hatterszinet';

  @override
  String get settings_appearance_cardColorAttribute_none => 'Nincs';

  @override
  String get settings_appearance_cardColorAttribute_depth => 'Melyseg';

  @override
  String get settings_appearance_cardColorAttribute_duration => 'Idotartam';

  @override
  String get settings_appearance_cardColorAttribute_temperature =>
      'Homerseklet';

  @override
  String get settings_appearance_colorGradient => 'Szinatlenet';

  @override
  String get settings_appearance_colorGradient_subtitle =>
      'Valassza ki a szintartomanyt a kartya hatterekhez';

  @override
  String get settings_appearance_colorGradient_ocean => 'Ocean';

  @override
  String get settings_appearance_colorGradient_thermal => 'Termikus';

  @override
  String get settings_appearance_colorGradient_sunset => 'Naplemente';

  @override
  String get settings_appearance_colorGradient_forest => 'Erdo';

  @override
  String get settings_appearance_colorGradient_monochrome => 'Monokrom';

  @override
  String get settings_appearance_colorGradient_custom => 'Egyeni';

  @override
  String get settings_appearance_gasSwitchMarkers => 'Gazvaltas jelolok';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'Gazvaltas jelolok megjelenites';

  @override
  String get settings_appearance_header_diveLog => 'Merülesi naplo';

  @override
  String get settings_appearance_header_diveProfile => 'Merülesi profil';

  @override
  String get settings_appearance_header_diveSites => 'Merülohelyek';

  @override
  String get settings_appearance_header_language => 'Nyelv';

  @override
  String get settings_appearance_header_theme => 'Tema';

  @override
  String get settings_appearance_mapBackgroundDiveCards =>
      'Terkep hatter a merülesi kartyakon';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitle =>
      'Merülohely terkep megjelenites hatterkent a merülesi kartyakon';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote =>
      'Merülohely terkep megjelenites hatterkent a merülesi kartyakon (merülohely szükseges)';

  @override
  String get settings_appearance_mapBackgroundSiteCards =>
      'Terkep hatter a merülohely kartyakon';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitle =>
      'Terkep megjelenites hatterkent a merülohely kartyakon';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote =>
      'Terkep megjelenites hatterkent a merülohely kartyakon (merülohely szükseges)';

  @override
  String get settings_appearance_maxDepthMarker => 'Max. melyseg jelolo';

  @override
  String get settings_appearance_maxDepthMarker_subtitle =>
      'Jelolo megjelenites a maximalis melyseg pontjan';

  @override
  String get settings_appearance_maxDepthMarker_subtitleFull =>
      'Jelolo megjelenites a maximalis melyseg pontjan a merülesi profilokon';

  @override
  String get settings_appearance_metric_ascentRateColors =>
      'Felszallasi sebesseg szinek';

  @override
  String get settings_appearance_metric_ceiling => 'Plafon';

  @override
  String get settings_appearance_metric_events => 'Esemenyek';

  @override
  String get settings_appearance_metric_gasDensity => 'Gaz suruseg';

  @override
  String get settings_appearance_metric_gfPercent => 'GF%';

  @override
  String get settings_appearance_metric_heartRate => 'Szivfrekvencia';

  @override
  String get settings_appearance_metric_meanDepth => 'Atlagmelyseg';

  @override
  String get settings_appearance_metric_ndl => 'NDL';

  @override
  String get settings_appearance_metric_ppHe => 'ppHe';

  @override
  String get settings_appearance_metric_ppN2 => 'ppN2';

  @override
  String get settings_appearance_metric_ppO2 => 'ppO2';

  @override
  String get settings_appearance_metric_pressure => 'Nyomas';

  @override
  String get settings_appearance_metric_sacRate => 'SAC ertek';

  @override
  String get settings_appearance_metric_surfaceGf => 'Felszini GF';

  @override
  String get settings_appearance_metric_temperature => 'Homerseklet';

  @override
  String get settings_appearance_metric_tts => 'TTS (Ido a felszinig)';

  @override
  String get settings_appearance_pressureThresholdMarkers =>
      'Nyomas küszöbértek jelolok';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Jelolok megjelenites, amikor a palack nyomas atlepi a küszöbértekeket';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Jelolok megjelenites, amikor a palack nyomas atlepi a 2/3, 1/2 es 1/3 küszöbértekeket';

  @override
  String get settings_appearance_rightYAxisMetric => 'Jobb Y-tengely metrika';

  @override
  String get settings_appearance_rightYAxisMetric_subtitle =>
      'Alapertelmezett metrika a jobb tengelyen';

  @override
  String get settings_appearance_subsection_decompressionMetrics =>
      'Dekompresszios metrikak';

  @override
  String get settings_appearance_subsection_defaultVisibleMetrics =>
      'Alapertelmezett lathato metrikak';

  @override
  String get settings_appearance_subsection_gasAnalysisMetrics =>
      'Gaz elemzesi metrikak';

  @override
  String get settings_appearance_subsection_gradientFactorMetrics =>
      'Gradiens faktor metrikak';

  @override
  String get settings_appearance_theme_dark => 'Sötet';

  @override
  String get settings_appearance_theme_light => 'Vilagos';

  @override
  String get settings_appearance_theme_system => 'Rendszer alapertelmezett';

  @override
  String get settings_backToSettings_tooltip => 'Vissza a beallitasokhoz';

  @override
  String get settings_cloudSync_appBar_title => 'Felho szinkronizalas';

  @override
  String get settings_cloudSync_autoSync => 'Automatikus szinkronizalas';

  @override
  String get settings_cloudSync_autoSync_subtitle =>
      'Automatikus szinkronizalas valtoztatasok utan';

  @override
  String settings_cloudSync_conflictItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem figyelmet igenyel',
      one: '1 elem figyelmet igenyel',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_disabledBanner_content =>
      'Az alkalmazas altal kezelt felho szinkronizalas le van tiltva, mert egyedi tarolasi mappat hasznal. A mappa szinkronizaciós szolgaltatasa (Dropbox, Google Drive, OneDrive stb.) kezeli a szinkronizalast.';

  @override
  String get settings_cloudSync_disabledBanner_title =>
      'Felho szinkronizalas letiltva';

  @override
  String get settings_cloudSync_header_advanced => 'Halado';

  @override
  String get settings_cloudSync_header_cloudProvider => 'Felho szolgaltato';

  @override
  String settings_cloudSync_header_conflicts(Object count) {
    return 'Ütközesek ($count)';
  }

  @override
  String get settings_cloudSync_header_syncBehavior =>
      'Szinkronizalasi viselkedes';

  @override
  String settings_cloudSync_lastSynced(Object time) {
    return 'Utolso szinkronizalas: $time';
  }

  @override
  String settings_cloudSync_pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count függo valtoztatas',
      one: '1 függo valtoztatas',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_provider_connected => 'Csatlakoztatva';

  @override
  String settings_cloudSync_provider_connectedTo(Object providerName) {
    return 'Csatlakoztatva: $providerName';
  }

  @override
  String settings_cloudSync_provider_connectionFailed(
    Object providerName,
    Object error,
  ) {
    return '$providerName csatlakozas sikertelen: $error';
  }

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Szinkronizalas Google Drive-on keresztül';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Szinkronizalas Apple iCloud-on keresztül';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Nem sikerült a(z) $providerName szolgaltato inicializalasa';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Nem erheto el ezen a platformon';

  @override
  String get settings_cloudSync_resetDialog_cancel => 'Megse';

  @override
  String get settings_cloudSync_resetDialog_content =>
      'Ez torli az osszes szinkronizalas-elozmenyeket es ujrakezdi. Az adatok nem törlodnek, de a kovetkezo szinkronizalaskor ütközeseket kell feloldania.';

  @override
  String get settings_cloudSync_resetDialog_reset => 'Visszaallitas';

  @override
  String get settings_cloudSync_resetDialog_title =>
      'Szinkronizalas allapot visszaallitasa?';

  @override
  String get settings_cloudSync_resetSuccess =>
      'Szinkronizalas allapot visszaallitva';

  @override
  String get settings_cloudSync_resetSyncState =>
      'Szinkronizalas allapot visszaallitasa';

  @override
  String get settings_cloudSync_resetSyncState_subtitle =>
      'Szinkronizalas elozmenyeinek torlese es ujrakezdés';

  @override
  String get settings_cloudSync_resolveConflicts => 'Ütközesek feloldasa';

  @override
  String get settings_cloudSync_selectProviderHint =>
      'Valasszon felho szolgaltatot a szinkronizalas engedelyezesehez';

  @override
  String get settings_cloudSync_signOut => 'Kijelentkezes';

  @override
  String get settings_cloudSync_signOutDialog_cancel => 'Megse';

  @override
  String get settings_cloudSync_signOutDialog_content =>
      'Ez levalasztja a felho szolgaltatorol. A helyi adatok sertetetlenek maradnak.';

  @override
  String get settings_cloudSync_signOutDialog_signOut => 'Kijelentkezes';

  @override
  String get settings_cloudSync_signOutDialog_title => 'Kijelentkezes?';

  @override
  String get settings_cloudSync_signOutSuccess =>
      'Kijelentkezve a felho szolgaltatobol';

  @override
  String get settings_cloudSync_signOut_subtitle =>
      'Levalasztas a felho szolgaltatorol';

  @override
  String get settings_cloudSync_status_conflictsDetected =>
      'Ütközesek eszlelve';

  @override
  String get settings_cloudSync_status_readyToSync =>
      'Keszen all a szinkronizalasra';

  @override
  String get settings_cloudSync_status_syncComplete =>
      'Szinkronizalas befejezve';

  @override
  String get settings_cloudSync_status_syncError => 'Szinkronizalasi hiba';

  @override
  String get settings_cloudSync_status_syncing => 'Szinkronizalas...';

  @override
  String get settings_cloudSync_storageSettings => 'Tarolasi beallitasok';

  @override
  String get settings_cloudSync_syncNow => 'Szinkronizalas most';

  @override
  String get settings_cloudSync_syncOnLaunch => 'Szinkronizalas inditaskor';

  @override
  String get settings_cloudSync_syncOnLaunch_subtitle =>
      'Frissitesek ellenorzese inditaskor';

  @override
  String get settings_cloudSync_syncOnResume => 'Szinkronizalas folytatáskor';

  @override
  String get settings_cloudSync_syncOnResume_subtitle =>
      'Frissitesek ellenorzése az alkalmazas aktivalasakor';

  @override
  String settings_cloudSync_syncProgressPercent(Object percent) {
    return 'Szinkronizalas haladasa: $percent szazalek';
  }

  @override
  String settings_cloudSync_time_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count napja',
      one: '1 napja',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_time_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oraja',
      one: '1 oraja',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_time_justNow => 'Most';

  @override
  String settings_cloudSync_time_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perce',
      one: '1 perce',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_applyAll => 'Alkalmaz mindet';

  @override
  String get settings_conflict_cancel => 'Megse';

  @override
  String get settings_conflict_chooseResolution => 'Feloldas valasztasa';

  @override
  String get settings_conflict_close => 'Bezaras';

  @override
  String get settings_conflict_close_tooltip => 'Ütközes párbeszed bezarasa';

  @override
  String settings_conflict_counterLabel(Object current, Object total) {
    return '$current. ütközes a(z) $total közül';
  }

  @override
  String settings_conflict_errorLoading(Object error) {
    return 'Hiba az ütközesek betoltesekor: $error';
  }

  @override
  String get settings_conflict_keepBoth => 'Mindketto megtartasa';

  @override
  String get settings_conflict_keepLocal => 'Helyi megtartasa';

  @override
  String get settings_conflict_keepRemote => 'Tavoli megtartasa';

  @override
  String get settings_conflict_localVersion => 'Helyi valtozat';

  @override
  String settings_conflict_modified(Object time) {
    return 'Modositva: $time';
  }

  @override
  String get settings_conflict_next_tooltip => 'Kovetkezo ütközes';

  @override
  String get settings_conflict_noConflicts_message =>
      'Minden szinkronizalasi ütközes feloldva.';

  @override
  String get settings_conflict_noConflicts_title => 'Nincsenek ütközesek';

  @override
  String get settings_conflict_noDataAvailable => 'Nincs elerheto adat';

  @override
  String get settings_conflict_previous_tooltip => 'Elozo ütközes';

  @override
  String get settings_conflict_remoteVersion => 'Tavoli valtozat';

  @override
  String settings_conflict_resolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ütközes',
      one: '1 ütközes',
    );
    return '$_temp0 feloldva';
  }

  @override
  String get settings_conflict_title => 'Ütközesek feloldasa';

  @override
  String get settings_data_appDefaultLocation =>
      'Alkalmazas alapertelmezett helye';

  @override
  String get settings_data_backup => 'Biztonsagi mentes';

  @override
  String get settings_data_backup_subtitle =>
      'Biztonsagi mentes keszitese az adatokrol';

  @override
  String get settings_data_cloudSync => 'Felho szinkronizalas';

  @override
  String get settings_data_customFolder => 'Egyedi mappa';

  @override
  String get settings_data_databaseStorage => 'Adatbazis tarolas';

  @override
  String get settings_data_export_completed => 'Exportalas befejezve';

  @override
  String get settings_data_export_exporting => 'Exportalas...';

  @override
  String settings_data_export_failed(Object error) {
    return 'Exportalas sikertelen: $error';
  }

  @override
  String get settings_data_header_backupSync =>
      'Biztonsagi mentes es szinkronizalas';

  @override
  String get settings_data_header_storage => 'Tarolas';

  @override
  String get settings_data_import_completed => 'Muvelet befejezve';

  @override
  String settings_data_import_failed(Object error) {
    return 'Muvelet sikertelen: $error';
  }

  @override
  String get settings_data_offlineMaps => 'Offline terkepek';

  @override
  String get settings_data_offlineMaps_subtitle =>
      'Terkepek letöltese offline hasznalathoz';

  @override
  String get settings_data_restore => 'Visszaallitas';

  @override
  String get settings_data_restoreDialog_cancel => 'Megse';

  @override
  String get settings_data_restoreDialog_content =>
      'Figyelmeztetés: A biztonsagi mentesbol valo visszaallitas MINDEN jelenlegi adatot felülir a mentett adatokkal. Ez a muvelet nem vonhato vissza.\n\nBiztosan folytatja?';

  @override
  String get settings_data_restoreDialog_restore => 'Visszaallitas';

  @override
  String get settings_data_restoreDialog_title =>
      'Biztonsagi mentes visszaallitasa';

  @override
  String get settings_data_restore_subtitle =>
      'Visszaallitas biztonsagi mentesbol';

  @override
  String settings_data_syncTime_daysAgo(Object count) {
    return '$count napja';
  }

  @override
  String settings_data_syncTime_hoursAgo(Object count) {
    return '$count oraja';
  }

  @override
  String get settings_data_syncTime_justNow => 'Most';

  @override
  String settings_data_syncTime_minutesAgo(Object count) {
    return '$count perce';
  }

  @override
  String settings_data_sync_lastSynced(Object time) {
    return 'Utolso szinkronizalas: $time';
  }

  @override
  String get settings_data_sync_notConfigured => 'Nincs konfigurálva';

  @override
  String get settings_data_sync_syncing => 'Szinkronizalas...';

  @override
  String get settings_decompression_aboutContent =>
      'A Gradiens Faktorok (GF) szabalyozzak, mennyire konzervatív a dekompressziós szamitas. A GF Low a mely megallokra, mig a GF High a sekely megallokra hat.\n\nAlacsonyabb ertekek = konzervativabb = hosszabb deko megallok\nMagasabb ertekek = kevesbe konzervatív = rovidebb deko megallok';

  @override
  String get settings_decompression_aboutTitle => 'Gradiens Faktorokrol';

  @override
  String get settings_decompression_currentSettings => 'Jelenlegi beallitasok';

  @override
  String get settings_decompression_dialog_cancel => 'Megse';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      'Alacsonyabb ertekek = konzervativabb (hosszabb NDL/tobb deko)';

  @override
  String get settings_decompression_dialog_customValues => 'Egyedi ertekek';

  @override
  String get settings_decompression_dialog_gfHigh => 'GF High';

  @override
  String get settings_decompression_dialog_gfLow => 'GF Low';

  @override
  String get settings_decompression_dialog_info =>
      'A GF Low/High szabalyozza, mennyire konzervativak az NDL es deko szamitasok.';

  @override
  String get settings_decompression_dialog_presets =>
      'Elore beallitott ertekek';

  @override
  String get settings_decompression_dialog_save => 'Mentes';

  @override
  String get settings_decompression_dialog_title => 'Gradiens Faktorok';

  @override
  String settings_decompression_gfValue(Object gfLow, Object gfHigh) {
    return 'GF $gfLow/$gfHigh';
  }

  @override
  String get settings_decompression_header_gradientFactors =>
      'Gradiens Faktorok';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return '$presetName konzervativizmus elore beallitott ertek kivalasztasa';
  }

  @override
  String get settings_existingDb_cancel => 'Megse';

  @override
  String get settings_existingDb_continue => 'Folytatas';

  @override
  String get settings_existingDb_current => 'Jelenlegi';

  @override
  String get settings_existingDb_dialog_message =>
      'Egy Submersion adatbazis mar letezik ebben a mappaban.';

  @override
  String get settings_existingDb_dialog_title => 'Letezo adatbazis talalva';

  @override
  String get settings_existingDb_existing => 'Letezo';

  @override
  String get settings_existingDb_replaceWarning =>
      'A letezo adatbazisrol biztonsagi mentes keszül a csere elott.';

  @override
  String get settings_existingDb_replaceWithMyData =>
      'Csere a sajat adataimmal';

  @override
  String get settings_existingDb_replaceWithMyData_subtitle =>
      'Felüliras a jelenlegi adatbazissal';

  @override
  String get settings_existingDb_stat_buddies => 'Merülopartnerek';

  @override
  String get settings_existingDb_stat_dives => 'Merülesek';

  @override
  String get settings_existingDb_stat_sites => 'Merülohelyek';

  @override
  String get settings_existingDb_stat_trips => 'Utak';

  @override
  String get settings_existingDb_stat_users => 'Felhasznalok';

  @override
  String get settings_existingDb_unknown => 'Ismeretlen';

  @override
  String get settings_existingDb_useExisting => 'Letezo adatbazis hasznalata';

  @override
  String get settings_existingDb_useExisting_subtitle =>
      'Valtas az ebben a mappaban levo adatbazisra';

  @override
  String get settings_gfPreset_custom_description => 'Sajat ertekek megadasa';

  @override
  String get settings_gfPreset_custom_name => 'Egyedi';

  @override
  String get settings_gfPreset_high_description =>
      'Legkonzervativabb, hosszabb deko megallok';

  @override
  String get settings_gfPreset_high_name => 'Magas';

  @override
  String get settings_gfPreset_low_description =>
      'Legkevesbe konzervatív, rovidebb deko';

  @override
  String get settings_gfPreset_low_name => 'Alacsony';

  @override
  String get settings_gfPreset_medium_description =>
      'Kiegyensulyozott megközelites';

  @override
  String get settings_gfPreset_medium_name => 'Közepes';

  @override
  String get settings_import_dialog_title => 'Adatok importalasa';

  @override
  String get settings_import_doNotClose => 'Kerem, ne zarja be az alkalmazast';

  @override
  String settings_import_itemCount(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get settings_import_phase_buddies => 'Merülopartnerek importalasa...';

  @override
  String get settings_import_phase_certifications =>
      'Tanusitványok importalasa...';

  @override
  String get settings_import_phase_complete => 'Befejez...';

  @override
  String get settings_import_phase_diveCenters =>
      'Merülokozpontok importalasa...';

  @override
  String get settings_import_phase_diveTypes =>
      'Merüles tipusok importalasa...';

  @override
  String get settings_import_phase_dives => 'Merülesek importalasa...';

  @override
  String get settings_import_phase_equipment => 'Felszereles importalasa...';

  @override
  String get settings_import_phase_equipmentSets =>
      'Felszereles szettek importalasa...';

  @override
  String get settings_import_phase_parsing => 'Fajl elemzese...';

  @override
  String get settings_import_phase_preparing => 'Elokeszites...';

  @override
  String get settings_import_phase_sites => 'Merülohelyek importalasa...';

  @override
  String get settings_import_phase_tags => 'Cimkek importalasa...';

  @override
  String get settings_import_phase_trips => 'Utak importalasa...';

  @override
  String settings_import_progressLabel(
    Object phase,
    Object current,
    Object total,
  ) {
    return '$phase, $current / $total';
  }

  @override
  String settings_import_progressPercent(Object percent) {
    return 'Importalas haladasa: $percent szazalek';
  }

  @override
  String get settings_language_appBar_title => 'Nyelv';

  @override
  String get settings_language_selected => 'Kivalasztva';

  @override
  String get settings_language_systemDefault => 'Rendszer alapertelmezett';

  @override
  String get settings_manage_diveTypes => 'Merüles tipusok';

  @override
  String get settings_manage_diveTypes_subtitle =>
      'Egyedi merüles tipusok kezelese';

  @override
  String get settings_manage_header_manageData => 'Adatok kezelese';

  @override
  String get settings_manage_species => 'Fajok';

  @override
  String get settings_manage_species_subtitle =>
      'Tengeri elolenyek fajkatalogusanak kezelese';

  @override
  String get settings_manage_tankPresets => 'Palack elore beallitott ertekek';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Egyedi palack konfiguraciok kezelese';

  @override
  String get settings_migrationProgress_doNotClose =>
      'Kerem, ne zarja be az alkalmazast';

  @override
  String get settings_migration_backupInfo =>
      'Az athelyezes elott biztonsagi mentes keszül. Az adatok nem vesznek el.';

  @override
  String get settings_migration_cancel => 'Megse';

  @override
  String get settings_migration_cloudSyncWarning =>
      'Az alkalmazas altal kezelt felho szinkronizalas letiltasra kerül. A mappa szinkronizacios szolgaltatasa kezeli a szinkronizalast.';

  @override
  String get settings_migration_dialog_message =>
      'Az adatbazis athelyezesre kerül:';

  @override
  String get settings_migration_dialog_title => 'Adatbazis athelyezese?';

  @override
  String get settings_migration_from => 'Innen';

  @override
  String get settings_migration_moveDatabase => 'Adatbazis athelyezese';

  @override
  String get settings_migration_to => 'Ide';

  @override
  String settings_notifications_days(Object count) {
    return '$count nap';
  }

  @override
  String get settings_notifications_disabled_enableButton => 'Engedelyezes';

  @override
  String get settings_notifications_disabled_subtitle =>
      'Engedelyezze a rendszerbeallitasokban az emlekeztetok fogadasahoz';

  @override
  String get settings_notifications_disabled_title => 'Ertesitesek letiltva';

  @override
  String get settings_notifications_enableServiceReminders =>
      'Szerviz emlekeztetok engedelyezese';

  @override
  String get settings_notifications_enableServiceReminders_subtitle =>
      'Ertesites, ha felszereles szerviz esedékes';

  @override
  String get settings_notifications_header_reminderSchedule =>
      'Emlekeztetok idoezitese';

  @override
  String get settings_notifications_header_serviceReminders =>
      'Szerviz emlekeztetok';

  @override
  String get settings_notifications_howItWorks_content =>
      'Az ertesitesek az alkalmazas inditasakor kerülnek ütemezeresre, es rendszeresen frissülnek a hatterben. Az egyes felszerelesek emlekeztetoit a szerkesztesi képernyojükön szabhatja testre.';

  @override
  String get settings_notifications_howItWorks_title => 'Hogyan mukodik';

  @override
  String get settings_notifications_permissionRequired =>
      'Kerem, engedelyezze az ertesiteseket a rendszerbeallitasokban';

  @override
  String get settings_notifications_remindBeforeDue =>
      'Emlekeztetés a szerviz esedekessege elott:';

  @override
  String get settings_notifications_reminderTime => 'Emlekeztetesi idopont';

  @override
  String get settings_profile_activeDiver_subtitle =>
      'Aktiv merülo - koppintson a valtashoz';

  @override
  String get settings_profile_addNewDiver => 'Uj merülo hozzaadasa';

  @override
  String get settings_profile_error_loadingDiver =>
      'Hiba a merülo betoltesekor';

  @override
  String get settings_profile_header_activeDiver => 'Aktiv merülo';

  @override
  String get settings_profile_header_manageDivers => 'Merülok kezelese';

  @override
  String get settings_profile_noDiverProfile => 'Nincs merülo profil';

  @override
  String get settings_profile_noDiverProfile_subtitle =>
      'Koppintson a profil letrehozasahoz';

  @override
  String get settings_profile_switchDiver_title => 'Merülo valtas';

  @override
  String settings_profile_switchedTo(Object diverName) {
    return 'Valtas: $diverName';
  }

  @override
  String get settings_profile_viewAllDivers => 'Osszes merülo megtekintese';

  @override
  String get settings_profile_viewAllDivers_subtitle =>
      'Merülo profilok hozzaadasa vagy szerkesztese';

  @override
  String get settings_section_about_subtitle => 'Alkalmazas info es licencek';

  @override
  String get settings_section_about_title => 'Rolunk';

  @override
  String get settings_section_appearance_subtitle => 'Tema es megjelenes';

  @override
  String get settings_section_appearance_title => 'Megjelenes';

  @override
  String get settings_section_data_subtitle =>
      'Biztonsagi mentes, visszaallitas es tarolas';

  @override
  String get settings_section_data_title => 'Adatok';

  @override
  String get settings_section_decompression_subtitle => 'Gradiens faktorok';

  @override
  String get settings_section_decompression_title => 'Dekompresszio';

  @override
  String get settings_section_diverProfile_subtitle =>
      'Aktiv merülo es profilok';

  @override
  String get settings_section_diverProfile_title => 'Merülo profil';

  @override
  String get settings_section_manage_subtitle =>
      'Merüles tipusok es palack elore beallitott ertekek';

  @override
  String get settings_section_manage_title => 'Kezeles';

  @override
  String get settings_section_notifications_subtitle => 'Szerviz emlekeztetok';

  @override
  String get settings_section_notifications_title => 'Ertesitesek';

  @override
  String get settings_section_units_subtitle => 'Mertekegyseg beallitasok';

  @override
  String get settings_section_units_title => 'Mertekegysegek';

  @override
  String get settings_storage_appBar_title => 'Adatbazis tarolas';

  @override
  String get settings_storage_appDefault => 'Alkalmazas alapertelmezett';

  @override
  String get settings_storage_appDefaultLocation =>
      'Alkalmazas alapertelmezett helye';

  @override
  String get settings_storage_appDefault_subtitle =>
      'Szabvanyos alkalmazas tarolasi hely';

  @override
  String get settings_storage_currentLocation => 'Jelenlegi hely';

  @override
  String get settings_storage_currentLocation_label => 'Jelenlegi hely';

  @override
  String get settings_storage_customFolder => 'Egyedi mappa';

  @override
  String get settings_storage_customFolder_change => 'Valtoztatas';

  @override
  String get settings_storage_customFolder_subtitle =>
      'Valasszon szinkronizalt mappat (Dropbox, Google Drive stb.)';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize • $diveCount merüles • $siteCount merülohely';
  }

  @override
  String get settings_storage_dismissError_tooltip => 'Hibaüzenet elvetese';

  @override
  String get settings_storage_dismissSuccess_tooltip => 'Sikerüzenet elvetese';

  @override
  String get settings_storage_header_storageLocation => 'Tarolasi hely';

  @override
  String get settings_storage_info_customActive =>
      'Az alkalmazas altal kezelt felho szinkronizalas le van tiltva. A mappa szinkronizaciós szolgaltatasa (Dropbox, Google Drive stb.) kezeli a szinkronizalast.';

  @override
  String get settings_storage_info_customAvailable =>
      'Egyedi mappa hasznalata letiltja az alkalmazas altal kezelt felho szinkronizalast. A mappa szinkronizaciós szolgaltatasa kezeli helyette a szinkronizalast.';

  @override
  String get settings_storage_loading => 'Betoltes...';

  @override
  String get settings_storage_migrating_doNotClose =>
      'Kerem, ne zarja be az alkalmazast';

  @override
  String get settings_storage_migrating_movingDatabase =>
      'Adatbazis athelyezese...';

  @override
  String get settings_storage_migrating_movingToAppDefault =>
      'Athelyezes az alkalmazas alapertelmezett helyere...';

  @override
  String get settings_storage_migrating_replacingExisting =>
      'Letezo adatbazis csereje...';

  @override
  String get settings_storage_migrating_switchingToExisting =>
      'Valtas a letezo adatbazisra...';

  @override
  String get settings_storage_notSet => 'Nincs megadva';

  @override
  String settings_storage_success_backupAt(Object path) {
    return 'Az eredeti biztonsagi menteskent megmarad:\n$path';
  }

  @override
  String get settings_storage_success_moved => 'Adatbazis sikeresen athelyezve';

  @override
  String get settings_summary_activeDiver => 'Aktiv merülo';

  @override
  String get settings_summary_currentConfiguration => 'Jelenlegi konfiguracoo';

  @override
  String get settings_summary_depth => 'Melyseg';

  @override
  String get settings_summary_error => 'Hiba';

  @override
  String get settings_summary_gradientFactors => 'Gradiens Faktorok';

  @override
  String get settings_summary_loading => 'Betoltes...';

  @override
  String get settings_summary_notSet => 'Nincs megadva';

  @override
  String get settings_summary_pressure => 'Nyomas';

  @override
  String get settings_summary_subtitle =>
      'Valasszon egy kategoriat a konfigurálashoz';

  @override
  String get settings_summary_temperature => 'Homerseklet';

  @override
  String get settings_summary_theme => 'Tema';

  @override
  String get settings_summary_theme_dark => 'Sötet';

  @override
  String get settings_summary_theme_light => 'Vilagos';

  @override
  String get settings_summary_theme_system => 'Rendszer';

  @override
  String get settings_summary_tip =>
      'Tipp: Hasznaja az Adatok szekciót a merülesi naploi rendszeres biztonsagi mentesehez.';

  @override
  String get settings_summary_title => 'Beallitasok';

  @override
  String get settings_summary_unitPreferences => 'Mertekegyseg beallitasok';

  @override
  String get settings_summary_units => 'Mertekegysegek';

  @override
  String get settings_summary_volume => 'Terfogat';

  @override
  String get settings_summary_weight => 'Suly';

  @override
  String get settings_units_custom => 'Egyedi';

  @override
  String get settings_units_dateFormat => 'Datum formatum';

  @override
  String get settings_units_depth => 'Melyseg';

  @override
  String get settings_units_depth_feet => 'Lab (ft)';

  @override
  String get settings_units_depth_meters => 'Meter (m)';

  @override
  String get settings_units_dialog_dateFormat => 'Datum formatum';

  @override
  String get settings_units_dialog_depthUnit => 'Melyseg egyseg';

  @override
  String get settings_units_dialog_pressureUnit => 'Nyomas egyseg';

  @override
  String get settings_units_dialog_sacRateUnit => 'SAC ertek egyseg';

  @override
  String get settings_units_dialog_temperatureUnit => 'Homerseklet egyseg';

  @override
  String get settings_units_dialog_timeFormat => 'Ido formatum';

  @override
  String get settings_units_dialog_volumeUnit => 'Terfogat egyseg';

  @override
  String get settings_units_dialog_weightUnit => 'Suly egyseg';

  @override
  String get settings_units_header_individualUnits => 'Egyedi egysegek';

  @override
  String get settings_units_header_timeDateFormat => 'Ido es datum formatum';

  @override
  String get settings_units_header_unitSystem => 'Mertekegyseg rendszer';

  @override
  String get settings_units_imperial => 'Angolszasz';

  @override
  String get settings_units_metric => 'Metrikus';

  @override
  String get settings_units_pressure => 'Nyomas';

  @override
  String get settings_units_pressure_bar => 'Bar';

  @override
  String get settings_units_pressure_psi => 'PSI';

  @override
  String get settings_units_quickSelect => 'Gyors valasztas';

  @override
  String get settings_units_sacRate => 'SAC ertek';

  @override
  String get settings_units_sac_pressurePerMinute => 'Nyomas percenként';

  @override
  String get settings_units_sac_pressurePerMinute_subtitle =>
      'Nem szükseges palack terfogat (bar/min vagy psi/min)';

  @override
  String get settings_units_sac_volumePerMinute => 'Terfogat percenként';

  @override
  String get settings_units_sac_volumePerMinute_subtitle =>
      'Palack terfogat szükseges (L/min vagy cuft/min)';

  @override
  String get settings_units_temperature => 'Homerseklet';

  @override
  String get settings_units_temperature_celsius => 'Celsius (°C)';

  @override
  String get settings_units_temperature_fahrenheit => 'Fahrenheit (°F)';

  @override
  String get settings_units_timeFormat => 'Ido formatum';

  @override
  String get settings_units_volume => 'Terfogat';

  @override
  String get settings_units_volume_cubicFeet => 'Köblab (cuft)';

  @override
  String get settings_units_volume_liters => 'Liter (L)';

  @override
  String get settings_units_weight => 'Suly';

  @override
  String get settings_units_weight_kilograms => 'Kilogramm (kg)';

  @override
  String get settings_units_weight_pounds => 'Font (lbs)';

  @override
  String get signatures_action_clear => 'Törlés';

  @override
  String get signatures_action_closeSignatureView => 'Aláírás nézet bezárása';

  @override
  String get signatures_action_deleteSignature => 'Aláírás törlése';

  @override
  String get signatures_action_done => 'Kész';

  @override
  String get signatures_action_readyToSign => 'Kész az aláírásra';

  @override
  String get signatures_action_request => 'Kérés';

  @override
  String get signatures_action_saveSignature => 'Aláírás mentése';

  @override
  String signatures_buddyCard_notSignedSemantics(Object name) {
    return '$name aláírás, nincs aláírva';
  }

  @override
  String signatures_buddyCard_signedSemantics(Object name) {
    return '$name aláírás, aláírva';
  }

  @override
  String get signatures_captureInstructorSignature =>
      'Oktató aláírás rögzítése';

  @override
  String signatures_deleteDialog_message(Object name) {
    return 'Biztosan törölni szeretnéd $name aláírását? Ez nem vonható vissza.';
  }

  @override
  String get signatures_deleteDialog_title => 'Aláírás törlése?';

  @override
  String get signatures_drawSignatureHint => 'Rajzold meg az aláírásodat fent';

  @override
  String get signatures_drawSignatureHintDetailed =>
      'Rajzold meg az aláírást fent ujjal vagy tollal';

  @override
  String get signatures_drawSignatureSemantics => 'Aláírás rajzolása';

  @override
  String get signatures_error_drawSignature => 'Rajzolj egy aláírást';

  @override
  String get signatures_error_enterSignerName => 'Add meg az aláíró nevét';

  @override
  String get signatures_field_instructorName => 'Oktató neve';

  @override
  String get signatures_field_instructorNameHint => 'Add meg az oktató nevét';

  @override
  String get signatures_handoff_title => 'Add át az eszközt';

  @override
  String get signatures_instructorSignature => 'Oktató aláírása';

  @override
  String get signatures_noSignatureImage => 'Nincs aláírás kép';

  @override
  String signatures_signHere(Object name) {
    return '$name - Írj alá itt';
  }

  @override
  String get signatures_signed => 'Aláírva';

  @override
  String signatures_signedCountSemantics(Object signed, Object total) {
    return '$signed búvártárs írt alá a(z) $total-ból';
  }

  @override
  String signatures_signedDate(Object date) {
    return 'Aláírva: $date';
  }

  @override
  String get signatures_title => 'Aláírások';

  @override
  String get signatures_viewSignature => 'Aláírás megtekintése';

  @override
  String signatures_viewSignatureSemantics(Object name) {
    return 'Aláírás megtekintése $name-től';
  }

  @override
  String get statistics_appBar_title => 'Statisztikak';

  @override
  String statistics_categoryCard_semanticLabel(Object title) {
    return '$title statisztikai kategoria';
  }

  @override
  String get statistics_category_conditions_subtitle =>
      'Latasi viszonyok es homerseklet';

  @override
  String get statistics_category_conditions_title => 'Korulmenyek';

  @override
  String get statistics_category_equipment_subtitle =>
      'Felszereles hasznalat es suly';

  @override
  String get statistics_category_equipment_title => 'Felszereles';

  @override
  String get statistics_category_gas_subtitle => 'SAC raatak es gazkeverekek';

  @override
  String get statistics_category_gas_title => 'Levegofelhasznalas';

  @override
  String get statistics_category_geographic_subtitle => 'Orszagok es regiok';

  @override
  String get statistics_category_geographic_title => 'Foldrajzi';

  @override
  String get statistics_category_marineLife_subtitle => 'Fajok eszlelesek';

  @override
  String get statistics_category_marineLife_title => 'Tengeri elet';

  @override
  String get statistics_category_profile_subtitle =>
      'Felszallasi sebessg es deko';

  @override
  String get statistics_category_profile_title => 'Profil elemzes';

  @override
  String get statistics_category_progression_subtitle =>
      'Melyseg es ido trendek';

  @override
  String get statistics_category_progression_title => 'Fejlodes';

  @override
  String get statistics_category_social_subtitle =>
      'Merulotarsak es merulokozpontok';

  @override
  String get statistics_category_social_title => 'Kozossegi';

  @override
  String get statistics_category_timePatterns_subtitle => 'Mikor merul';

  @override
  String get statistics_category_timePatterns_title => 'Idomintak';

  @override
  String statistics_chart_barSemanticLabel(Object count) {
    return 'Oszlopdiagram $count kategoriaval';
  }

  @override
  String statistics_chart_distributionSemanticLabel(Object count) {
    return 'Megoszlasi kordiagram $count szegmenssel';
  }

  @override
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames) {
    return 'Tobbszoros trend vonaldiagram, $seriesNames osszehasonlitasa';
  }

  @override
  String get statistics_chart_noBarData => 'Nincsenek elerheto adatok';

  @override
  String get statistics_chart_noDistributionData =>
      'Nincsenek megoszlasi adatok';

  @override
  String get statistics_chart_noTrendData => 'Nincsenek trend adatok';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return 'Trend vonaldiagram $count adatponttal';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return 'Trend vonaldiagram $count adatponttal a(z) $yAxisLabel szamara';
  }

  @override
  String get statistics_conditions_appBar_title => 'Korulmenyek';

  @override
  String get statistics_conditions_entryMethod_empty =>
      'Nincsenek belepesi modszer adatok';

  @override
  String get statistics_conditions_entryMethod_error =>
      'Nem sikerult a belepesi modszer adatok betoltese';

  @override
  String get statistics_conditions_entryMethod_subtitle => 'Parti, hajos stb.';

  @override
  String get statistics_conditions_entryMethod_title => 'Belepesi modszer';

  @override
  String get statistics_conditions_temperature_empty =>
      'Nincsenek homerseklet adatok';

  @override
  String get statistics_conditions_temperature_error =>
      'Nem sikerult a homerseklet adatok betoltese';

  @override
  String get statistics_conditions_temperature_seriesAvg => 'Atl.';

  @override
  String get statistics_conditions_temperature_seriesMax => 'Max';

  @override
  String get statistics_conditions_temperature_seriesMin => 'Min';

  @override
  String get statistics_conditions_temperature_subtitle =>
      'Min/Atl/Max homersekletek';

  @override
  String get statistics_conditions_temperature_title =>
      'Vizhomerseklet honaponkent';

  @override
  String get statistics_conditions_visibility_error =>
      'Nem sikerult a latasi adatok betoltese';

  @override
  String get statistics_conditions_visibility_subtitle =>
      'Merulesek latasi viszonyok szerint';

  @override
  String get statistics_conditions_visibility_title => 'Lathato megoszlas';

  @override
  String get statistics_conditions_waterType_error =>
      'Nem sikerult a viztipus adatok betoltese';

  @override
  String get statistics_conditions_waterType_subtitle =>
      'Sos es edesvizi merulesek';

  @override
  String get statistics_conditions_waterType_title => 'Viztipus';

  @override
  String get statistics_equipment_appBar_title => 'Felszereles';

  @override
  String get statistics_equipment_mostUsedGear_error =>
      'Nem sikerult a felszereles adatok betoltese';

  @override
  String get statistics_equipment_mostUsedGear_subtitle =>
      'Felszereles merulesek szama szerint';

  @override
  String get statistics_equipment_mostUsedGear_title =>
      'Legtobbet hasznalt felszereles';

  @override
  String get statistics_equipment_weightTrend_error =>
      'Nem sikerult a suly trend betoltese';

  @override
  String get statistics_equipment_weightTrend_subtitle =>
      'Atlagos suly az ido fuggvenyeben';

  @override
  String get statistics_equipment_weightTrend_title => 'Suly trend';

  @override
  String get statistics_error_loadingStatistics =>
      'Hiba a statisztikak betoltesekor';

  @override
  String get statistics_gas_appBar_title => 'Levegofelhasznalas';

  @override
  String get statistics_gas_gasMix_error =>
      'Nem sikerult a gazkeverek adatok betoltese';

  @override
  String get statistics_gas_gasMix_subtitle => 'Merulesek gaztipus szerint';

  @override
  String get statistics_gas_gasMix_title => 'Gazkeverek megoszlas';

  @override
  String get statistics_gas_sacByRole_empty => 'Nincsenek tobbpalackos adatok';

  @override
  String get statistics_gas_sacByRole_error =>
      'Nem sikerult a SAC szerep szerinti betoltese';

  @override
  String get statistics_gas_sacByRole_subtitle =>
      'Atlagos felhasznalas palack tipus szerint';

  @override
  String get statistics_gas_sacByRole_title => 'SAC palack szerep szerint';

  @override
  String get statistics_gas_sacRecords_best => 'Legjobb SAC rata';

  @override
  String get statistics_gas_sacRecords_empty => 'Meg nincsenek SAC adatok';

  @override
  String get statistics_gas_sacRecords_error =>
      'Nem sikerult a SAC rekordok betoltese';

  @override
  String get statistics_gas_sacRecords_highest => 'Legmagasabb SAC rata';

  @override
  String get statistics_gas_sacRecords_subtitle =>
      'Legjobb es legrosszabb levegofelhasznalas';

  @override
  String get statistics_gas_sacRecords_title => 'SAC rata rekordok';

  @override
  String get statistics_gas_sacTrend_error =>
      'Nem sikerult a SAC trend betoltese';

  @override
  String get statistics_gas_sacTrend_subtitle => 'Havi atlag 5 even at';

  @override
  String get statistics_gas_sacTrend_title => 'SAC rata trend';

  @override
  String get statistics_gas_tankRole_backGas => 'Hattergaz';

  @override
  String get statistics_gas_tankRole_bailout => 'Bailout';

  @override
  String get statistics_gas_tankRole_deco => 'Deko';

  @override
  String get statistics_gas_tankRole_diluent => 'Higito';

  @override
  String get statistics_gas_tankRole_oxygenSupply => 'O₂ ellatas';

  @override
  String get statistics_gas_tankRole_pony => 'Pony';

  @override
  String get statistics_gas_tankRole_sidemountLeft => 'Sidemount B';

  @override
  String get statistics_gas_tankRole_sidemountRight => 'Sidemount J';

  @override
  String get statistics_gas_tankRole_stage => 'Stage';

  @override
  String get statistics_geographic_appBar_title => 'Foldrajzi';

  @override
  String get statistics_geographic_countries_empty =>
      'Nincsenek latogatott orszagok';

  @override
  String get statistics_geographic_countries_error =>
      'Nem sikerult az orszag adatok betoltese';

  @override
  String get statistics_geographic_countries_subtitle =>
      'Merulesek orszagonkent';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count orszag. Elso: $topName, $topCount merulessel';
  }

  @override
  String get statistics_geographic_countries_title => 'Latogatott orszagok';

  @override
  String get statistics_geographic_regions_empty =>
      'Nincsenek felfedezett regiok';

  @override
  String get statistics_geographic_regions_error =>
      'Nem sikerult a regio adatok betoltese';

  @override
  String get statistics_geographic_regions_subtitle => 'Merulesek regiokent';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count regio. Elso: $topName, $topCount merulessel';
  }

  @override
  String get statistics_geographic_regions_title => 'Felfedezett regiok';

  @override
  String get statistics_geographic_trips_empty => 'Nincsenek utazasi adatok';

  @override
  String get statistics_geographic_trips_error =>
      'Nem sikerult az utazasi adatok betoltese';

  @override
  String get statistics_geographic_trips_subtitle => 'Legproduktivabb utazasok';

  @override
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count utazas. Elso: $topName, $topCount merulessel';
  }

  @override
  String get statistics_geographic_trips_title => 'Merulesek utazasonkent';

  @override
  String get statistics_listContent_selectedSuffix => ', kivalasztva';

  @override
  String get statistics_marineLife_appBar_title => 'Tengeri elet';

  @override
  String get statistics_marineLife_bestSites_empty =>
      'Nincsenek helyszin adatok';

  @override
  String get statistics_marineLife_bestSites_error =>
      'Nem sikerult a helyszin adatok betoltese';

  @override
  String get statistics_marineLife_bestSites_subtitle =>
      'Legtobb fajvalaszteku helyszinek';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count helyszin. Legjobb: $topName, $topCount fajjal';
  }

  @override
  String get statistics_marineLife_bestSites_title =>
      'Legjobb tengeri elet helyszinek';

  @override
  String get statistics_marineLife_mostCommon_empty =>
      'Nincsenek eszlelesi adatok';

  @override
  String get statistics_marineLife_mostCommon_error =>
      'Nem sikerult az eszlelesi adatok betoltese';

  @override
  String get statistics_marineLife_mostCommon_subtitle =>
      'Leggyakrabban lathato fajok';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count faj. Leggyakoribb: $topName, $topCount eszlelessel';
  }

  @override
  String get statistics_marineLife_mostCommon_title =>
      'Leggyakoribb eszlelesek';

  @override
  String get statistics_marineLife_speciesSpotted => 'Eszlelt fajok';

  @override
  String get statistics_profile_appBar_title => 'Profil elemzes';

  @override
  String get statistics_profile_ascentDescent_empty =>
      'Nincsenek elerheto profil adatok';

  @override
  String get statistics_profile_ascentDescent_error =>
      'Nem sikerult a sebessg adatok betoltese';

  @override
  String get statistics_profile_ascentDescent_subtitle =>
      'Merulesi profil adatokbol';

  @override
  String get statistics_profile_ascentDescent_title =>
      'Atlagos felszallasi es lesullyedesi sebesseg';

  @override
  String get statistics_profile_avgAscent => 'Atl. felszallas';

  @override
  String get statistics_profile_avgDescent => 'Atl. lesullyedes';

  @override
  String get statistics_profile_deco_decoDives => 'Deko merulesek';

  @override
  String get statistics_profile_deco_decoLabel => 'Deko';

  @override
  String get statistics_profile_deco_decoRate => 'Deko arany';

  @override
  String get statistics_profile_deco_empty => 'Nincsenek deko adatok';

  @override
  String get statistics_profile_deco_error =>
      'Nem sikerult a deko adatok betoltese';

  @override
  String get statistics_profile_deco_noDeco => 'Nincs deko';

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return 'Dekompresszios arany: $percentage% a meruleseknek deko megalloast igenyelt';
  }

  @override
  String get statistics_profile_deco_subtitle =>
      'Merulesek amelyek deko megalloast igenyeltek';

  @override
  String get statistics_profile_deco_title => 'Dekompresszios kotelezetseg';

  @override
  String get statistics_profile_timeAtDepth_empty => 'Nincsenek melyseg adatok';

  @override
  String get statistics_profile_timeAtDepth_error =>
      'Nem sikerult a melyseg tartomany adatok betoltese';

  @override
  String get statistics_profile_timeAtDepth_subtitle =>
      'Kozelito ido az egyes melysegekben';

  @override
  String get statistics_profile_timeAtDepth_title =>
      'Ido melyseg tartomanyokent';

  @override
  String statistics_profile_timeAtDepth_valueFormat(Object value) {
    return '$value min';
  }

  @override
  String get statistics_progression_appBar_title => 'Merulesi fejlodes';

  @override
  String get statistics_progression_bottomTime_error =>
      'Nem sikerult a fenekido trend betoltese';

  @override
  String get statistics_progression_bottomTime_subtitle =>
      'Atlagos idotartam honaponkent';

  @override
  String get statistics_progression_bottomTime_title => 'Fenekido trend';

  @override
  String get statistics_progression_cumulative_error =>
      'Nem sikerult a kumulativ adatok betoltese';

  @override
  String get statistics_progression_cumulative_subtitle =>
      'Osszes merules az ido fuggvenyeben';

  @override
  String get statistics_progression_cumulative_title =>
      'Kumulativ merulesi szam';

  @override
  String get statistics_progression_depthProgression_error =>
      'Nem sikerult a melyseg fejlodes betoltese';

  @override
  String get statistics_progression_depthProgression_subtitle =>
      'Havi max melyseg 5 even at';

  @override
  String get statistics_progression_depthProgression_title =>
      'Maximalis melyseg fejlodes';

  @override
  String get statistics_progression_divesPerYear_empty =>
      'Nincsenek eves adatok';

  @override
  String get statistics_progression_divesPerYear_error =>
      'Nem sikerult az eves adatok betoltese';

  @override
  String get statistics_progression_divesPerYear_subtitle =>
      'Eves merulesszam osszehasonlitas';

  @override
  String get statistics_progression_divesPerYear_title => 'Merulesek evente';

  @override
  String get statistics_ranking_countLabel_dives => 'merules';

  @override
  String get statistics_ranking_countLabel_sightings => 'eszleles';

  @override
  String get statistics_ranking_countLabel_species => 'faj';

  @override
  String get statistics_ranking_emptyState => 'Meg nincsenek adatok';

  @override
  String statistics_ranking_itemCount(Object count, Object label) {
    return '$count $label';
  }

  @override
  String statistics_ranking_moreItems(Object count) {
    return 'es $count tovabbi';
  }

  @override
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  ) {
    return '$name, $rank. helyezes, $count $label';
  }

  @override
  String get statistics_records_appBar_title => 'Merulesi rekordok';

  @override
  String get statistics_records_coldestDive => 'Leghidegebb merules';

  @override
  String get statistics_records_deepestDive => 'Legmelyebb merules';

  @override
  String statistics_records_diveNumber(Object number) {
    return '#$number. merules';
  }

  @override
  String get statistics_records_emptySubtitle =>
      'Kezdjen el meruleseket rogziteni, hogy lassa rekordJait';

  @override
  String get statistics_records_emptyTitle => 'Meg nincsenek rekordok';

  @override
  String get statistics_records_error => 'Hiba a rekordok betoltesekor';

  @override
  String get statistics_records_firstDive => 'Elso merules';

  @override
  String get statistics_records_longestDive => 'Leghosszabb merules';

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
  String get statistics_records_milestones => 'Merfoldk9vek';

  @override
  String get statistics_records_mostRecentDive => 'Legutobbl merules';

  @override
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  ) {
    return '$title: $value, $siteName';
  }

  @override
  String get statistics_records_retry => 'Ujra';

  @override
  String get statistics_records_shallowestDive => 'Legsekelyebb merules';

  @override
  String get statistics_records_unknownSite => 'Ismeretlen helyszin';

  @override
  String get statistics_records_warmestDive => 'Legmelegebb merules';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return '$title szekcio';
  }

  @override
  String get statistics_social_appBar_title => 'Kozossegi es merulotarsak';

  @override
  String get statistics_social_soloVsBuddy_empty => 'Nincsenek merulesi adatok';

  @override
  String get statistics_social_soloVsBuddy_error =>
      'Nem sikerult a merulotars adatok betoltese';

  @override
  String get statistics_social_soloVsBuddy_solo => 'Egyedulli';

  @override
  String get statistics_social_soloVsBuddy_subtitle =>
      'Merules tarsakkal vagy nelkuluk';

  @override
  String get statistics_social_soloVsBuddy_title => 'Egyedulli vs. tarsakkal';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => 'Merulotarssal';

  @override
  String get statistics_social_topBuddies_error =>
      'Nem sikerult a merulotars rangsor betoltese';

  @override
  String get statistics_social_topBuddies_subtitle =>
      'Leggyakoribb merulotarsak';

  @override
  String get statistics_social_topBuddies_title => 'Legjobb merulotarsak';

  @override
  String get statistics_social_topDiveCenters_error =>
      'Nem sikerult a merulokozpont rangsor betoltese';

  @override
  String get statistics_social_topDiveCenters_subtitle =>
      'Leglátogatottabb szolgaltatok';

  @override
  String get statistics_social_topDiveCenters_title =>
      'Legjobb merulokozpontok';

  @override
  String get statistics_summary_avgDepth => 'Atl. melyseg';

  @override
  String get statistics_summary_avgTemp => 'Atl. homerseklet';

  @override
  String get statistics_summary_depthDistribution_empty =>
      'A diagram megjelenik, ha rogzit meruleseket';

  @override
  String get statistics_summary_depthDistribution_semanticLabel =>
      'Kordiagram a melyseg megoszlasrol';

  @override
  String get statistics_summary_depthDistribution_title => 'Melyseg megoszlas';

  @override
  String get statistics_summary_diveTypes_empty =>
      'A diagram megjelenik, ha rogzit meruleseket';

  @override
  String statistics_summary_diveTypes_moreTypes(Object count) {
    return 'es $count tovabbi tipus';
  }

  @override
  String get statistics_summary_diveTypes_semanticLabel =>
      'Kordiagram a merulesi tipusok megoszlasarol';

  @override
  String get statistics_summary_diveTypes_title => 'Merulesi tipusok';

  @override
  String get statistics_summary_divesByMonth_empty =>
      'A diagram megjelenik, ha rogzit meruleseket';

  @override
  String get statistics_summary_divesByMonth_semanticLabel =>
      'Oszlopdiagram a hayl merulesekrol';

  @override
  String get statistics_summary_divesByMonth_title => 'Merulesek honaponkent';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel\n$count merules';
  }

  @override
  String get statistics_summary_header_subtitle =>
      'Valasszon kategoriat a reszletes statisztikak megtekIntesehez';

  @override
  String get statistics_summary_header_title => 'Statisztikak attekintese';

  @override
  String get statistics_summary_maxDepth => 'Max melyseg';

  @override
  String get statistics_summary_sitesVisited => 'Latogatott helyszinek';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merules',
      one: '1 merules',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty => 'Meg nincsenek cimkek';

  @override
  String get statistics_summary_tagUsage_emptyHint =>
      'Adjon cimkeket a merulesekhez a statisztikak megtekIntesehez';

  @override
  String statistics_summary_tagUsage_moreTags(Object count) {
    return 'es $count tovabbi cimke';
  }

  @override
  String statistics_summary_tagUsage_tagCount(Object count) {
    return '$count cimke';
  }

  @override
  String get statistics_summary_tagUsage_title => 'Cimke hasznalat';

  @override
  String statistics_summary_topDiveSites_diveCount(Object count) {
    return '$count merules';
  }

  @override
  String get statistics_summary_topDiveSites_empty =>
      'Meg nincsenek merulohelyek';

  @override
  String get statistics_summary_topDiveSites_title => 'Legjobb merulohelyek';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count osszesen';
  }

  @override
  String get statistics_summary_totalDives => 'Osszes merules';

  @override
  String get statistics_summary_totalTime => 'Osszes ido';

  @override
  String get statistics_timePatterns_appBar_title => 'Idomintak';

  @override
  String get statistics_timePatterns_dayOfWeek_empty =>
      'Nincsenek elerheto adatok';

  @override
  String get statistics_timePatterns_dayOfWeek_error =>
      'Nem sikerult a heti nap adatok betoltese';

  @override
  String get statistics_timePatterns_dayOfWeek_fri => 'Pe';

  @override
  String get statistics_timePatterns_dayOfWeek_mon => 'He';

  @override
  String get statistics_timePatterns_dayOfWeek_sat => 'Szo';

  @override
  String get statistics_timePatterns_dayOfWeek_subtitle =>
      'Mikor merul a legtobbet?';

  @override
  String get statistics_timePatterns_dayOfWeek_sun => 'V';

  @override
  String get statistics_timePatterns_dayOfWeek_thu => 'Cs';

  @override
  String get statistics_timePatterns_dayOfWeek_title =>
      'Merulesek a het napjai szerint';

  @override
  String get statistics_timePatterns_dayOfWeek_tue => 'K';

  @override
  String get statistics_timePatterns_dayOfWeek_wed => 'Sze';

  @override
  String get statistics_timePatterns_month_apr => 'Apr.';

  @override
  String get statistics_timePatterns_month_aug => 'Aug.';

  @override
  String get statistics_timePatterns_month_dec => 'Dec.';

  @override
  String get statistics_timePatterns_month_feb => 'Feb.';

  @override
  String get statistics_timePatterns_month_jan => 'Jan.';

  @override
  String get statistics_timePatterns_month_jul => 'Jul.';

  @override
  String get statistics_timePatterns_month_jun => 'Jun.';

  @override
  String get statistics_timePatterns_month_mar => 'Mar.';

  @override
  String get statistics_timePatterns_month_may => 'Maj.';

  @override
  String get statistics_timePatterns_month_nov => 'Nov.';

  @override
  String get statistics_timePatterns_month_oct => 'Okt.';

  @override
  String get statistics_timePatterns_month_sep => 'Szept.';

  @override
  String get statistics_timePatterns_seasonal_empty =>
      'Nincsenek elerheto adatok';

  @override
  String get statistics_timePatterns_seasonal_error =>
      'Nem sikerult az evszakos adatok betoltese';

  @override
  String get statistics_timePatterns_seasonal_subtitle =>
      'Merulesek honaponkent (minden ev)';

  @override
  String get statistics_timePatterns_seasonal_title => 'Evszakos mintak';

  @override
  String get statistics_timePatterns_surfaceInterval_average => 'Atlag';

  @override
  String get statistics_timePatterns_surfaceInterval_empty =>
      'Nincsenek felszini intervallum adatok';

  @override
  String get statistics_timePatterns_surfaceInterval_error =>
      'Nem sikerult a felszini intervallum adatok betoltese';

  @override
  String statistics_timePatterns_surfaceInterval_formatHoursMinutes(
    Object hours,
    Object minutes,
  ) {
    return '${hours}o ${minutes}p';
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
      'Ido a merulesek kozott';

  @override
  String get statistics_timePatterns_surfaceInterval_title =>
      'Felszini intervallum statisztikak';

  @override
  String get statistics_timePatterns_timeOfDay_error =>
      'Nem sikerult a napszak adatok betoltese';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle =>
      'Reggel, delutan, este vagy ejszaka';

  @override
  String get statistics_timePatterns_timeOfDay_title =>
      'Merulesek napszak szerint';

  @override
  String get statistics_tooltip_diveRecords => 'Merulesi rekordok';

  @override
  String get statistics_tooltip_refreshRecords => 'Rekordok frissitese';

  @override
  String get statistics_tooltip_refreshStatistics => 'Statisztikak frissitese';

  @override
  String statistics_valueCard_semanticLabel(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String get surfaceInterval_aboutTissueLoading_body =>
      'A testednek 16 szövetkamrája van, amelyek különböző sebességgel nyelik el és adják le a nitrogént. A gyors szövetek (mint a vér) gyorsan telítődnek, de gyorsan is ürülnek. A lassú szövetek (mint a csont és a zsír) tovább tart, hogy mindkettőt betöltsék és kiürüljenek. A \"vezető kamra\" az a szövet, amelyik a legtelítettebb, és általában ez szabályozza a dekompresszió nélküli határidőt (NDL). A felszíni intervallum alatt minden szövet kiürül a felszíni telítettségi szintek felé (~40% telítettség).';

  @override
  String get surfaceInterval_aboutTissueLoading_title =>
      'A szövet telítettségről';

  @override
  String get surfaceInterval_action_resetDefaults =>
      'Alapértelmezések visszaállítása';

  @override
  String get surfaceInterval_disclaimer =>
      'Ez az eszköz csak tervezési célokat szolgál. Mindig használj búvárcomputert és kövesd a képzésed. Az eredmények a Buhlmann ZH-L16C algoritmuson alapulnak és eltérhetnek a computeredétől.';

  @override
  String get surfaceInterval_field_depth => 'Mélység';

  @override
  String get surfaceInterval_field_gasMix => 'Gázkeverék: ';

  @override
  String get surfaceInterval_field_he => 'He';

  @override
  String get surfaceInterval_field_o2 => 'O₂';

  @override
  String get surfaceInterval_field_time => 'Idő';

  @override
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit) {
    return 'Első merülés mélysége: $depth $unit';
  }

  @override
  String surfaceInterval_firstDive_timeSemantics(Object time) {
    return 'Első merülés ideje: $time perc';
  }

  @override
  String get surfaceInterval_firstDive_title => 'Első merülés';

  @override
  String surfaceInterval_format_hours(Object count) {
    return '$count óra';
  }

  @override
  String surfaceInterval_format_minutes(Object count) {
    return '$count perc';
  }

  @override
  String get surfaceInterval_gasMix_air => 'Levegő';

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
    return 'Hélium: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Jelenlegi intervallum';

  @override
  String get surfaceInterval_result_inDeco => 'Dekóban';

  @override
  String get surfaceInterval_result_increaseInterval =>
      'Növeld a felszíni intervallumot vagy csökkentsd a második merülés mélységét/idejét';

  @override
  String get surfaceInterval_result_minimumInterval =>
      'Minimum felszíni intervallum';

  @override
  String get surfaceInterval_result_ndlForSecondDive => 'NDL a 2. merüléshez';

  @override
  String surfaceInterval_result_ndlMinutes(Object minutes) {
    return '$minutes perc NDL';
  }

  @override
  String get surfaceInterval_result_notYetSafe =>
      'Még nem biztonságos, növeld a felszíni intervallumot';

  @override
  String get surfaceInterval_result_safeToDive => 'Biztonságos merülni';

  @override
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  ) {
    return 'Minimum felszíni intervallum: $interval. Jelenlegi intervallum: $current. NDL a második merüléshez: $ndl. $status';
  }

  @override
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit) {
    return 'Második merülés mélysége: $depth $unit';
  }

  @override
  String get surfaceInterval_secondDive_gasAir => '(Levegő)';

  @override
  String surfaceInterval_secondDive_timeSemantics(Object time) {
    return 'Második merülés ideje: $time perc';
  }

  @override
  String get surfaceInterval_secondDive_title => 'Második merülés';

  @override
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval) {
    return 'Szövet helyreállítási grafikon, amely 16 kamra kiürülését mutatja $interval felszíni intervallum alatt';
  }

  @override
  String get surfaceInterval_tissueRecovery_compartmentsLabel =>
      'Kamrák (felezési idő sebesség szerint)';

  @override
  String get surfaceInterval_tissueRecovery_description =>
      '16 szövetkamra kiürülésének mutatása a felszíni intervallum alatt';

  @override
  String get surfaceInterval_tissueRecovery_fast => 'Gyors (C1-5)';

  @override
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number) {
    return 'Vezető kamra: C$number';
  }

  @override
  String get surfaceInterval_tissueRecovery_loadingPercent => 'Telítettség %';

  @override
  String get surfaceInterval_tissueRecovery_medium => 'Közepes (C6-10)';

  @override
  String get surfaceInterval_tissueRecovery_min => 'Perc';

  @override
  String get surfaceInterval_tissueRecovery_now => 'Most';

  @override
  String get surfaceInterval_tissueRecovery_slow => 'Lassú (C11-16)';

  @override
  String get surfaceInterval_tissueRecovery_title => 'Szövet helyreállítás';

  @override
  String get surfaceInterval_title => 'Felszíni intervallum';

  @override
  String tags_action_createNamed(Object tagName) {
    return '\"$tagName\" létrehozása';
  }

  @override
  String get tags_action_createTag => 'Címke létrehozása';

  @override
  String get tags_action_deleteTag => 'Címke törlése';

  @override
  String tags_dialog_deleteMessage(Object tagName) {
    return 'Biztosan törölni szeretnéd: \"$tagName\"? Ez eltávolítja az összes merülésről.';
  }

  @override
  String get tags_dialog_deleteTitle => 'Címke törlése?';

  @override
  String get tags_empty =>
      'Még nincsenek címkék. Hozz létre címkéket a merülések szerkesztésekor.';

  @override
  String get tags_hint_addMoreTags => 'További címkék hozzáadása...';

  @override
  String get tags_hint_addTags => 'Címkék hozzáadása...';

  @override
  String get tags_title_manageTags => 'Címkék kezelése';

  @override
  String get tank_al30Stage_description => 'Aluminium 30 cu ft stage palack';

  @override
  String get tank_al30Stage_displayName => 'AL30 Stage';

  @override
  String get tank_al40Stage_description => 'Aluminium 40 cu ft stage palack';

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
  String get tank_al80_description => 'Aluminium 80 cu ft (legelterjedtebb)';

  @override
  String get tank_al80_displayName => 'AL80';

  @override
  String get tank_hp100_description => 'Nagynyomasu acel 100 cu ft';

  @override
  String get tank_hp100_displayName => 'HP100';

  @override
  String get tank_hp120_description => 'Nagynyomasu acel 120 cu ft';

  @override
  String get tank_hp120_displayName => 'HP120';

  @override
  String get tank_hp80_description => 'Nagynyomasu acel 80 cu ft';

  @override
  String get tank_hp80_displayName => 'HP80';

  @override
  String get tank_lp85_description => 'Kisnyomasu acel 85 cu ft';

  @override
  String get tank_lp85_displayName => 'LP85';

  @override
  String get tank_steel10_description => 'Acel 10 literes (Europa)';

  @override
  String get tank_steel10_displayName => 'Steel 10L';

  @override
  String get tank_steel12_description => 'Acel 12 literes (Europa)';

  @override
  String get tank_steel12_displayName => 'Steel 12L';

  @override
  String get tank_steel15_description => 'Acel 15 literes (Europa)';

  @override
  String get tank_steel15_displayName => 'Steel 15L';

  @override
  String get tides_action_refresh => 'Árapály adatok frissítése';

  @override
  String get tides_chart_24hourForecast => '24 órás előrejelzés';

  @override
  String tides_chart_heightAxis(Object depthSymbol) {
    return 'Magasság ($depthSymbol)';
  }

  @override
  String get tides_chart_msl => 'Tengerszint';

  @override
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr) {
    return ' Most $nowTimeStr $nowHeightStr';
  }

  @override
  String get tides_error_unableToLoad =>
      'Nem lehet betölteni az árapály adatokat';

  @override
  String get tides_error_unableToLoadChart => 'Nem lehet betölteni a grafikont';

  @override
  String tides_label_ago(Object duration) {
    return '$duration ezelőtt';
  }

  @override
  String tides_label_currentHeight(Object height, Object depthSymbol) {
    return 'Jelenlegi: $height$depthSymbol';
  }

  @override
  String tides_label_fromNow(Object duration) {
    return '$duration múlva';
  }

  @override
  String get tides_label_high => 'Dagály';

  @override
  String get tides_label_highIn => 'Dagály';

  @override
  String get tides_label_highTide => 'Dagály';

  @override
  String get tides_label_low => 'Apály';

  @override
  String get tides_label_lowIn => 'Apály';

  @override
  String get tides_label_lowTide => 'Apály';

  @override
  String tides_label_tideIn(Object duration) {
    return '$duration múlva';
  }

  @override
  String get tides_label_tideTimes => 'Árapály időpontok';

  @override
  String get tides_label_today => 'Ma';

  @override
  String get tides_label_tomorrow => 'Holnap';

  @override
  String get tides_label_upcomingTides => 'Közelgő árapályok';

  @override
  String get tides_legend_highTide => 'Dagály';

  @override
  String get tides_legend_lowTide => 'Apály';

  @override
  String get tides_legend_now => 'Most';

  @override
  String get tides_legend_tideLevel => 'Árapály szint';

  @override
  String get tides_noDataAvailable => 'Nincs elérhető árapály adat';

  @override
  String get tides_noDataForLocation =>
      'Árapály adat nem elérhető erre a helyszínre';

  @override
  String get tides_noExtremesData => 'Nincs szélső érték adat';

  @override
  String get tides_noTideTimesAvailable =>
      'Nincsenek elérhető árapály időpontok';

  @override
  String tides_semantic_currentTide(
    Object tideState,
    Object height,
    Object depthSymbol,
    Object nextExtreme,
  ) {
    return '$tideState árapály, $height$depthSymbol$nextExtreme';
  }

  @override
  String tides_semantic_extremeItem(
    Object typeLabel,
    Object time,
    Object height,
    Object depthSymbol,
  ) {
    return '$typeLabel árapály $time időpontban, $height$depthSymbol';
  }

  @override
  String tides_semantic_tideChart(Object extremesSummary) {
    return 'Árapály grafikon. $extremesSummary';
  }

  @override
  String tides_semantic_tideState(Object state) {
    return 'Árapály állapot: $state';
  }

  @override
  String get tides_title => 'Árapály';

  @override
  String get transfer_appBar_title => 'Atvitel';

  @override
  String get transfer_computers_aboutContent =>
      'Csatlakoztassa merülesi szamitogepejet Bluetooth-on keresztül, es toltse le a merülesi naplokat kozvetlenül az alkalmazasba. Tamogatott szamitogepek: Suunto, Shearwater, Garmin, Mares es sok mas nepszeru marka.\n\nAz Apple Watch Ultra felhasznalok kozvetlenül importalhatjak a merülesi adatokat a Health alkalmazasbol, beleertve a melyseg, idotartam es szivfrekvencia adatokat.';

  @override
  String get transfer_computers_aboutTitle => 'Merülesi szamitogepek';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple Watch';

  @override
  String get transfer_computers_appleWatchSubtitle =>
      'Apple Watch Ultra-n rogzitett merülesek importalasa';

  @override
  String get transfer_computers_appleWatchTitle => 'Importalas Apple Watch-rol';

  @override
  String get transfer_computers_connectSubtitle =>
      'Merülesi szamitogep felderitese es parositas';

  @override
  String get transfer_computers_connectTitle => 'Uj szamitogep csatlakoztatasa';

  @override
  String get transfer_computers_errorLoading =>
      'Hiba a szamitogepek betoltesekor';

  @override
  String get transfer_computers_loading => 'Betoltes...';

  @override
  String get transfer_computers_manageTitle => 'Szamitogepek kezelese';

  @override
  String get transfer_computers_noComputersSaved =>
      'Nincsenek mentett szamitogepek';

  @override
  String transfer_computers_savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'szamitogep',
      one: 'szamitogep',
    );
    return '$count mentett $_temp0';
  }

  @override
  String get transfer_computers_sectionHeader => 'Merülesi szamitogepek';

  @override
  String get transfer_csvExport_cancelButton => 'Megse';

  @override
  String get transfer_csvExport_dataTypeHeader => 'Adattipus';

  @override
  String get transfer_csvExport_descriptionDives =>
      'Az osszes merülesi naplo exportalasa tablazatkent';

  @override
  String get transfer_csvExport_descriptionEquipment =>
      'Felszereles leltarazasa es szervizinformaciok exportalasa';

  @override
  String get transfer_csvExport_descriptionSites =>
      'Merülohelyek es reszleteik exportalasa';

  @override
  String get transfer_csvExport_dialogTitle => 'CSV exportalas';

  @override
  String get transfer_csvExport_exportButton => 'CSV exportalas';

  @override
  String get transfer_csvExport_optionDivesTitle => 'Merülesek CSV';

  @override
  String get transfer_csvExport_optionEquipmentTitle => 'Felszereles CSV';

  @override
  String get transfer_csvExport_optionSitesTitle => 'Merülohelyek CSV';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return '$typeName exportalasa';
  }

  @override
  String get transfer_csvExport_typeDives => 'Merülesek';

  @override
  String get transfer_csvExport_typeEquipment => 'Felszereles';

  @override
  String get transfer_csvExport_typeSites => 'Merülohelyek';

  @override
  String get transfer_detail_backTooltip => 'Vissza az atvitelhez';

  @override
  String get transfer_export_aboutContent =>
      'Merülesi adatok exportalasa különbozo formatumokban. A PDF nyomtathato naplokonyvet keszit. Az UDDF egy univerzalis formatum, amely kompatibilis a legtobb merülesi naplo szoftverrel. A CSV fajlokat tablazatkezelo alkalmazasokban nyithatja meg.';

  @override
  String get transfer_export_aboutTitle => 'Az exportalasrol';

  @override
  String get transfer_export_completed => 'Exportalas befejezve';

  @override
  String get transfer_export_csvSubtitle => 'Tablazat formatum';

  @override
  String get transfer_export_csvTitle => 'CSV exportalas';

  @override
  String get transfer_export_excelSubtitle =>
      'Minden adat egy fajlban (merülesek, merülohelyek, felszereles, statisztikak)';

  @override
  String get transfer_export_excelTitle => 'Excel munkafuzet';

  @override
  String transfer_export_failed(Object error) {
    return 'Exportalas sikertelen: $error';
  }

  @override
  String get transfer_export_kmlSubtitle =>
      'Merülohelyek megtekintese 3D foldgombon';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => 'Tobb formatum exportalas';

  @override
  String get transfer_export_optionSaveSubtitle =>
      'Valassza ki a mentesi helyet az eszkozön';

  @override
  String get transfer_export_optionSaveTitle => 'Mentes fajlba';

  @override
  String get transfer_export_optionShareSubtitle =>
      'Küldes e-mailben, üzenetben vagy mas alkalmazassal';

  @override
  String get transfer_export_optionShareTitle => 'Megosztas';

  @override
  String get transfer_export_pdfSubtitle => 'Nyomtathato merülesi naplo';

  @override
  String get transfer_export_pdfTitle => 'PDF naplokonyv';

  @override
  String get transfer_export_progressExporting => 'Exportalas...';

  @override
  String get transfer_export_sectionHeader => 'Adatok exportalasa';

  @override
  String get transfer_export_uddfSubtitle =>
      'Univerzalis merülesi adat formatum';

  @override
  String get transfer_export_uddfTitle => 'UDDF exportalas';

  @override
  String get transfer_import_aboutContent =>
      'Az \"Adatok importalasa\" hasznalata a legjobb elmeny -- automatikusan felismeri a fajlformatumot es a forras alkalmazast. Az egyes formatumok opcio alabb kozvetlenül is elerhetok.';

  @override
  String get transfer_import_aboutTitle => 'Az importalasrol';

  @override
  String get transfer_import_autoDetectSemanticLabel =>
      'Adatok importalasa automatikus falismeréssel';

  @override
  String get transfer_import_autoDetectSubtitle =>
      'Automatikusan felismeri a CSV, UDDF, FIT es mas formatumokat';

  @override
  String get transfer_import_autoDetectTitle => 'Adatok importalasa';

  @override
  String get transfer_import_byFormatHeader => 'Importalas formatum szerint';

  @override
  String get transfer_import_csvSubtitle => 'Merülesek importalasa CSV fajlbol';

  @override
  String get transfer_import_csvTitle => 'Importalas CSV-bol';

  @override
  String get transfer_import_fitSubtitle =>
      'Merülesek importalasa Garmin Descent export fajlokbol';

  @override
  String get transfer_import_fitTitle => 'Importalas FIT fajlbol';

  @override
  String get transfer_import_operationCompleted => 'Muvelet befejezve';

  @override
  String transfer_import_operationFailed(Object error) {
    return 'Muvelet sikertelen: $error';
  }

  @override
  String get transfer_import_sectionHeader => 'Adatok importalasa';

  @override
  String get transfer_import_uddfSubtitle =>
      'Univerzalis merülesi adat formatum';

  @override
  String get transfer_import_uddfTitle => 'Importalas UDDF-bol';

  @override
  String get transfer_pdfExport_cancelButton => 'Megse';

  @override
  String get transfer_pdfExport_dialogTitle => 'PDF naplokonyv exportalasa';

  @override
  String get transfer_pdfExport_exportButton => 'PDF exportalas';

  @override
  String get transfer_pdfExport_includeCertCards =>
      'Tanusitvany kartyak beillesztese';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle =>
      'Beolvasott tanusitvany kartya kepek hozzaadasa a PDF-hez';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => 'Oldalmerret';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Letter';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => 'Reszletes';

  @override
  String get transfer_pdfExport_templateDetailedDesc =>
      'Teljes merülesi informacio jegyzetekkel es ertekelesekkel';

  @override
  String get transfer_pdfExport_templateHeader => 'Sablon';

  @override
  String get transfer_pdfExport_templateNauiStyle => 'NAUI stilusu';

  @override
  String get transfer_pdfExport_templateNauiStyleDesc =>
      'NAUI naplokonyv formatumnak megfelelo elrendezes';

  @override
  String get transfer_pdfExport_templatePadiStyle => 'PADI stilusu';

  @override
  String get transfer_pdfExport_templatePadiStyleDesc =>
      'PADI naplokonyv formatumnak megfelelo elrendezes';

  @override
  String get transfer_pdfExport_templateProfessional => 'Professzionalis';

  @override
  String get transfer_pdfExport_templateProfessionalDesc =>
      'Alairas es pecsethely a hitelesiteshez';

  @override
  String transfer_pdfExport_templateSemanticLabel(Object templateName) {
    return '$templateName sablon kivalasztasa';
  }

  @override
  String get transfer_pdfExport_templateSimple => 'Egyszeru';

  @override
  String get transfer_pdfExport_templateSimpleDesc =>
      'Tömor tablazatos formatum, sok merüles oldalankent';

  @override
  String get transfer_section_computersSubtitle => 'Letoltes eszkozrol';

  @override
  String get transfer_section_computersTitle => 'Merülesi szamitogepek';

  @override
  String get transfer_section_exportSubtitle => 'CSV, UDDF, PDF naplokonyv';

  @override
  String get transfer_section_exportTitle => 'Exportalas';

  @override
  String get transfer_section_importSubtitle => 'CSV, UDDF fajlok';

  @override
  String get transfer_section_importTitle => 'Importalas';

  @override
  String get transfer_summary_description =>
      'Merülesi adatok importalasa es exportalasa';

  @override
  String get transfer_summary_selectSection =>
      'Valasszon egy szekciót a listabol';

  @override
  String get transfer_summary_title => 'Atvitel';

  @override
  String transfer_unknownSection(Object sectionId) {
    return 'Ismeretlen szekció: $sectionId';
  }

  @override
  String get trips_appBar_title => 'Utak';

  @override
  String get trips_appBar_tripPhotos => 'Utifotok';

  @override
  String get trips_detail_action_delete => 'Torles';

  @override
  String get trips_detail_action_export => 'Exportalas';

  @override
  String get trips_detail_appBar_title => 'Ut';

  @override
  String get trips_detail_dialog_cancel => 'Megse';

  @override
  String get trips_detail_dialog_deleteConfirm => 'Torles';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return 'Biztosan torli a(z) \"$name\" utat? Az ut torlodik, de a merülesek megmaradnak.';
  }

  @override
  String get trips_detail_dialog_deleteTitle => 'Ut torlese?';

  @override
  String get trips_detail_dives_empty => 'Meg nincsenek merülesek ezen az uton';

  @override
  String get trips_detail_dives_errorLoading =>
      'Nem sikerult a merülesek betoltese';

  @override
  String get trips_detail_dives_unknownSite => 'Ismeretlen merülohely';

  @override
  String trips_detail_dives_viewAll(Object count) {
    return 'Osszes megtekintese ($count)';
  }

  @override
  String trips_detail_durationDays(Object days) {
    return '$days nap';
  }

  @override
  String get trips_detail_export_csv_comingSoon => 'CSV exportalas hamarosan';

  @override
  String get trips_detail_export_csv_subtitle => 'Az ut osszes merülese';

  @override
  String get trips_detail_export_csv_title => 'Exportalas CSV-be';

  @override
  String get trips_detail_export_pdf_comingSoon => 'PDF exportalas hamarosan';

  @override
  String get trips_detail_export_pdf_subtitle =>
      'Ut osszefoglalo merülesi reszletekkel';

  @override
  String get trips_detail_export_pdf_title => 'Exportalas PDF-be';

  @override
  String get trips_detail_label_liveaboard => 'Hajoszallas';

  @override
  String get trips_detail_label_location => 'Helyszin';

  @override
  String get trips_detail_label_resort => 'Udulohely';

  @override
  String get trips_detail_scan_accessDenied =>
      'Fotogaleriahoz valo hozzaferes megtagadva';

  @override
  String get trips_detail_scan_addDivesFirst =>
      'Elobb adjon hozza merüleseket a fotok csatolasahoz';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return 'Hiba a fotok csatolasakor: $error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return 'Hiba a keresés soran: $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return '$count foto csatolva';
  }

  @override
  String get trips_detail_scan_linkingPhotos => 'Fotok csatolasa...';

  @override
  String get trips_detail_sectionTitle_details => 'Ut reszletei';

  @override
  String get trips_detail_sectionTitle_dives => 'Merülesek';

  @override
  String get trips_detail_sectionTitle_notes => 'Jegyzetek';

  @override
  String get trips_detail_sectionTitle_statistics => 'Ut statisztikak';

  @override
  String get trips_detail_snackBar_deleted => 'Ut torolve';

  @override
  String get trips_detail_stat_avgDepth => 'Atl. melyseg';

  @override
  String get trips_detail_stat_maxDepth => 'Max. melyseg';

  @override
  String get trips_detail_stat_totalBottomTime => 'Osszes fenekido';

  @override
  String get trips_detail_stat_totalDives => 'Osszes merüles';

  @override
  String get trips_detail_tooltip_edit => 'Ut szerkesztese';

  @override
  String get trips_detail_tooltip_editShort => 'Szerkesztes';

  @override
  String get trips_detail_tooltip_moreOptions => 'Tobb lehetoseg';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Megtekindes a terkepen';

  @override
  String get trips_edit_appBar_add => 'Ut hozzaadasa';

  @override
  String get trips_edit_appBar_edit => 'Ut szerkesztese';

  @override
  String get trips_edit_button_add => 'Ut hozzaadasa';

  @override
  String get trips_edit_button_cancel => 'Megse';

  @override
  String get trips_edit_button_save => 'Mentes';

  @override
  String get trips_edit_button_update => 'Ut frissitese';

  @override
  String get trips_edit_dialog_discard => 'Elvetés';

  @override
  String get trips_edit_dialog_discardContent =>
      'Nem mentett valtoztatasai vannak. Biztosan el akar tavozni?';

  @override
  String get trips_edit_dialog_discardTitle => 'Valtoztatasok elvetese?';

  @override
  String get trips_edit_dialog_keepEditing => 'Szerkesztes folytatasa';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days nap';
  }

  @override
  String get trips_edit_hint_liveaboardName => 'pl. MY Blue Force One';

  @override
  String get trips_edit_hint_location => 'pl. Egyiptom, Voros-tenger';

  @override
  String get trips_edit_hint_notes => 'Barmilyen megjegyzes errol az utrol';

  @override
  String get trips_edit_hint_resortName => 'pl. Marsa Shagra';

  @override
  String get trips_edit_hint_tripName => 'pl. Voros-tengeri szafari 2024';

  @override
  String get trips_edit_label_endDate => 'Befejezes datuma';

  @override
  String get trips_edit_label_liveaboardName => 'Hajoszallas neve';

  @override
  String get trips_edit_label_location => 'Helyszin';

  @override
  String get trips_edit_label_notes => 'Jegyzetek';

  @override
  String get trips_edit_label_resortName => 'Udulohely neve';

  @override
  String get trips_edit_label_startDate => 'Kezdes datuma';

  @override
  String get trips_edit_label_tripName => 'Ut neve *';

  @override
  String get trips_edit_sectionTitle_dates => 'Ut datumai';

  @override
  String get trips_edit_sectionTitle_location => 'Helyszin';

  @override
  String get trips_edit_sectionTitle_notes => 'Jegyzetek';

  @override
  String get trips_edit_semanticLabel_save => 'Ut mentese';

  @override
  String get trips_edit_snackBar_added => 'Ut sikeresen hozzaadva';

  @override
  String trips_edit_snackBar_errorLoading(Object error) {
    return 'Hiba az ut betoltesekor: $error';
  }

  @override
  String trips_edit_snackBar_errorSaving(Object error) {
    return 'Hiba az ut mentesekor: $error';
  }

  @override
  String get trips_edit_snackBar_updated => 'Ut sikeresen frissitve';

  @override
  String get trips_edit_validation_nameRequired =>
      'Kerem, adja meg az ut nevet';

  @override
  String get trips_gallery_accessDenied =>
      'Fotogaleriahoz valo hozzaferes megtagadva';

  @override
  String get trips_gallery_addDivesFirst =>
      'Elobb adjon hozza merüleseket a fotok csatolasahoz';

  @override
  String get trips_gallery_appBar_title => 'Utifotok';

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
    return '#$number. merüles - $site';
  }

  @override
  String get trips_gallery_empty_subtitle =>
      'Koppintson a kamera ikonra a galeria atnezesehez';

  @override
  String get trips_gallery_empty_title => 'Nincsenek fotok ezen az uton';

  @override
  String trips_gallery_errorLinking(Object error) {
    return 'Hiba a fotok csatolasakor: $error';
  }

  @override
  String trips_gallery_errorScanning(Object error) {
    return 'Hiba a keresés soran: $error';
  }

  @override
  String trips_gallery_error_loading(Object error) {
    return 'Hiba a fotok betoltesekor: $error';
  }

  @override
  String trips_gallery_linkedPhotos(Object count) {
    return '$count foto csatolva';
  }

  @override
  String get trips_gallery_linkingPhotos => 'Fotok csatolasa...';

  @override
  String get trips_gallery_tooltip_scan => 'Eszköz galeria atnezes';

  @override
  String get trips_gallery_tripNotFound => 'Ut nem talalhato';

  @override
  String get trips_list_button_retry => 'Ujraproba';

  @override
  String get trips_list_empty_button => 'Adja hozza az elso utat';

  @override
  String get trips_list_empty_filtered_subtitle =>
      'Probalja meg modositani vagy torolni a szuroket';

  @override
  String get trips_list_empty_filtered_title =>
      'Nincs a szuroknek megfelelo ut';

  @override
  String get trips_list_empty_subtitle =>
      'Hozzon letre utakat a merülesek cel szerinti csoportositasahoz';

  @override
  String get trips_list_empty_title => 'Meg nincsenek utak hozzaadva';

  @override
  String trips_list_error_loading(Object error) {
    return 'Hiba az utak betoltesekor: $error';
  }

  @override
  String get trips_list_fab_addTrip => 'Ut hozzaadasa';

  @override
  String get trips_list_filters_clearAll => 'Osszes torles';

  @override
  String get trips_list_sort_title => 'Utak rendezese';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count merüles';
  }

  @override
  String get trips_list_tooltip_addTrip => 'Ut hozzaadasa';

  @override
  String get trips_list_tooltip_search => 'Utak keresese';

  @override
  String get trips_list_tooltip_sort => 'Rendezes';

  @override
  String get trips_photos_empty_scanButton => 'Eszköz galeria atnezes';

  @override
  String get trips_photos_empty_title => 'Meg nincsenek fotok';

  @override
  String get trips_photos_error_loading => 'Hiba a fotok betoltesekor';

  @override
  String trips_photos_moreIndicator(Object count) {
    return '+$count';
  }

  @override
  String trips_photos_moreIndicator_semanticLabel(Object count) {
    return '$count tovabbi foto';
  }

  @override
  String get trips_photos_sectionTitle => 'Fotok';

  @override
  String get trips_photos_tooltip_scan => 'Eszköz galeria atnezes';

  @override
  String get trips_photos_viewAll => 'Osszes megtekintese';

  @override
  String get trips_picker_clearTooltip => 'Kivalasztas torlese';

  @override
  String get trips_picker_empty_createButton => 'Ut letrehozasa';

  @override
  String get trips_picker_empty_title => 'Meg nincsenek utak';

  @override
  String trips_picker_error(Object error) {
    return 'Hiba az utak betoltesekor: $error';
  }

  @override
  String get trips_picker_hint => 'Koppintson egy ut kivalasztasahoz';

  @override
  String get trips_picker_newTrip => 'Uj ut';

  @override
  String get trips_picker_noSelection => 'Nincs ut kivalasztva';

  @override
  String get trips_picker_sheetTitle => 'Ut kivalasztasa';

  @override
  String trips_picker_suggestedPrefix(Object name) {
    return 'Javasolt: $name';
  }

  @override
  String get trips_picker_suggestedUse => 'Hasznalat';

  @override
  String get trips_search_empty_hint =>
      'Kereses nev, helyszin vagy udulohely alapjan';

  @override
  String get trips_search_fieldLabel => 'Utak keresese...';

  @override
  String trips_search_noResults(Object query) {
    return 'Nem talalhato ut a kovetkezore: \"$query\"';
  }

  @override
  String get trips_search_tooltip_back => 'Vissza';

  @override
  String get trips_search_tooltip_clear => 'Kereses torlese';

  @override
  String get trips_summary_header_subtitle =>
      'Valasszon egy utat a listabol a reszletek megtekintésehez';

  @override
  String get trips_summary_header_title => 'Utak';

  @override
  String get trips_summary_overview_title => 'Attekintes';

  @override
  String get trips_summary_quickActions_add => 'Ut hozzaadasa';

  @override
  String get trips_summary_quickActions_title => 'Gyorsmuveletek';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date • $count merüles';
  }

  @override
  String get trips_summary_recentTitle => 'Legutobbi utak';

  @override
  String get trips_summary_stat_daysDiving => 'Merülesi napok';

  @override
  String get trips_summary_stat_liveaboards => 'Hajoszallasok';

  @override
  String get trips_summary_stat_totalDives => 'Osszes merüles';

  @override
  String get trips_summary_stat_totalTrips => 'Osszes ut';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date • $days nap mulva';
  }

  @override
  String get trips_summary_upcomingTitle => 'Kozelgo';

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
  String get units_sac_pressurePerMin => 'nyomas/min';

  @override
  String get units_temperature_celsius => 'C';

  @override
  String get units_temperature_fahrenheit => 'F';

  @override
  String get units_timeFormat_twelveHour => '12 oras';

  @override
  String get units_timeFormat_twentyFourHour => '24 oras';

  @override
  String get units_volume_cubicFeet => 'cuft';

  @override
  String get units_volume_liters => 'L';

  @override
  String get units_weight_kilograms => 'kg';

  @override
  String get units_weight_pounds => 'lbs';

  @override
  String get universalImport_action_continue => 'Folytatás';

  @override
  String get universalImport_action_deselectAll => 'Összes kijelölés törlése';

  @override
  String get universalImport_action_done => 'Kész';

  @override
  String get universalImport_action_import => 'Importálás';

  @override
  String get universalImport_action_selectAll => 'Összes kijelölése';

  @override
  String get universalImport_action_selectFile => 'Fájl kiválasztása';

  @override
  String get universalImport_description_supportedFormats =>
      'Válassz egy merülési napló fájlt az importáláshoz. Támogatott formátumok: CSV, UDDF, Subsurface XML és Garmin FIT.';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Ez a formátum még nem támogatott. Exportálj UDDF vagy CSV formátumban.';

  @override
  String get universalImport_hint_tagDescription =>
      'Címkézd meg az összes importált merülést a könnyű szűréshez';

  @override
  String get universalImport_hint_tagExample =>
      'pl. MacDive Importálás 2026-02-09';

  @override
  String get universalImport_label_columnMapping => 'Oszlop leképezés';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped oszlop leképezve a(z) $total-ból';
  }

  @override
  String get universalImport_label_detecting => 'Észlelés...';

  @override
  String universalImport_label_diveNumber(Object number) {
    return 'Merülés #$number';
  }

  @override
  String get universalImport_label_duplicate => 'Duplikátum';

  @override
  String universalImport_label_duplicatesFound(Object count) {
    return '$count duplikátum találva és automatikusan kijelölés törölve.';
  }

  @override
  String get universalImport_label_importComplete => 'Importálás kész';

  @override
  String get universalImport_label_importTag => 'Import címke';

  @override
  String get universalImport_label_importing => 'Importálás';

  @override
  String get universalImport_label_importingEllipsis => 'Importálás...';

  @override
  String universalImport_label_importingProgress(Object current, Object total) {
    return '$current importálása a(z) $total-ból';
  }

  @override
  String universalImport_label_percentMatch(Object percent) {
    return '$percent% egyezés';
  }

  @override
  String get universalImport_label_possibleMatch => 'Lehetséges egyezés';

  @override
  String get universalImport_label_selectCorrectSource =>
      'Nem helyes? Válaszd ki a megfelelő forrást:';

  @override
  String universalImport_label_selected(Object count) {
    return '$count kiválasztva';
  }

  @override
  String get universalImport_label_skip => 'Kihagyás';

  @override
  String universalImport_label_taggedAs(Object tag) {
    return 'Címkézve mint: $tag';
  }

  @override
  String get universalImport_label_unknownDate => 'Ismeretlen dátum';

  @override
  String get universalImport_label_unnamed => 'Névtelen';

  @override
  String universalImport_label_xOfY(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String universalImport_label_xOfYSelected(Object selected, Object total) {
    return '$selected kiválasztva a(z) $total-ból';
  }

  @override
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  ) {
    return '$selected kiválasztva a(z) $total $entityType-ból';
  }

  @override
  String universalImport_semantics_importError(Object error) {
    return 'Import hiba: $error';
  }

  @override
  String universalImport_semantics_importProgress(Object percent) {
    return 'Import előrehaladás: $percent százalék';
  }

  @override
  String universalImport_semantics_itemsSelected(Object count) {
    return '$count elem kiválasztva importálásra';
  }

  @override
  String get universalImport_semantics_possibleDuplicate =>
      'Lehetséges duplikátum';

  @override
  String get universalImport_semantics_probableDuplicate =>
      'Valószínű duplikátum';

  @override
  String universalImport_semantics_sourceDetected(Object description) {
    return 'Forrás észlelve: $description';
  }

  @override
  String universalImport_semantics_sourceUncertain(Object description) {
    return 'Forrás bizonytalan: $description';
  }

  @override
  String universalImport_semantics_toggleSelection(Object name) {
    return 'Kijelölés váltása: $name';
  }

  @override
  String get universalImport_step_import => 'Importálás';

  @override
  String get universalImport_step_map => 'Leképezés';

  @override
  String get universalImport_step_review => 'Áttekintés';

  @override
  String get universalImport_step_select => 'Kiválasztás';

  @override
  String get universalImport_title => 'Adatok importálása';

  @override
  String get universalImport_tooltip_clearTag => 'Címke törlése';

  @override
  String get universalImport_tooltip_closeWizard => 'Import varázsló bezárása';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return 'Alap ($suitType): $weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return 'Testsuly korrekció: +$adjustment kg';
  }

  @override
  String get weightCalc_suit_drysuit => 'Szaraz ruha';

  @override
  String get weightCalc_suit_none => 'Ruha nelkul';

  @override
  String get weightCalc_suit_rashguard => 'Csak rashguard';

  @override
  String get weightCalc_suit_semidry => 'Felig szaraz ruha';

  @override
  String get weightCalc_suit_shorty3mm => '3mm shorty';

  @override
  String get weightCalc_suit_wetsuit3mm => '3mm teljes neopren ruha';

  @override
  String get weightCalc_suit_wetsuit5mm => '5mm neopren ruha';

  @override
  String get weightCalc_suit_wetsuit7mm => '7mm neopren ruha';

  @override
  String weightCalc_tankLine(Object tankMaterial, Object adjustment) {
    return 'Palack ($tankMaterial): $adjustment kg';
  }

  @override
  String get weightCalc_title => 'Sulyszamitas:';

  @override
  String weightCalc_total(Object total) {
    return 'Osszes: $total kg';
  }

  @override
  String weightCalc_waterLine(Object waterType, Object adjustment) {
    return 'Viz ($waterType): $adjustment kg';
  }

  @override
  String divePlanner_label_resultsWithWarnings(Object count) {
    return 'Eredmények, $count figyelmeztetés';
  }

  @override
  String tides_semantic_tideCycle(Object state, Object height) {
    return 'Árapály ciklus, állapot: $state, magasság: $height';
  }

  @override
  String get tides_label_agoSuffix => 'ezelőtt';

  @override
  String get tides_label_fromNowSuffix => 'múlva';

  @override
  String get certifications_card_issued => 'KIALLITVA';

  @override
  String certifications_certificate_cardNumber(Object number) {
    return 'Kartyaszam: $number';
  }

  @override
  String get certifications_certificate_footer =>
      'Hivatalos buvarkepesite tanusitvany';

  @override
  String get certifications_certificate_hasCompletedTraining =>
      'sikeresen elvégezte a kepzest mint';

  @override
  String certifications_certificate_instructor(Object name) {
    return 'Oktato: $name';
  }

  @override
  String certifications_certificate_issued(Object date) {
    return 'Kiallitva: $date';
  }

  @override
  String get certifications_certificate_thisCertifies =>
      'Ezennel tanusitjuk, hogy';

  @override
  String get diveComputer_discovery_chooseDifferentDevice =>
      'Masik eszkoz valasztasa';

  @override
  String get diveComputer_discovery_computer => 'Szamitogep';

  @override
  String get diveComputer_discovery_connectAndDownload =>
      'Csatlakozas es letoltes';

  @override
  String get diveComputer_discovery_connectingToDevice =>
      'Csatlakozas az eszkozhoz...';

  @override
  String diveComputer_discovery_deviceNameHint(Object model) {
    return 'pl. Az en $model';
  }

  @override
  String get diveComputer_discovery_deviceNameLabel => 'Eszkoz neve';

  @override
  String get diveComputer_discovery_exitDialogCancel => 'Megse';

  @override
  String get diveComputer_discovery_exitDialogConfirm => 'Kilepes';

  @override
  String get diveComputer_discovery_exitDialogContent =>
      'Biztosan ki szeretne lepni? A haladas elveszik.';

  @override
  String get diveComputer_discovery_exitDialogTitle =>
      'Kilepes a beallitasbol?';

  @override
  String get diveComputer_discovery_exitTooltip => 'Kilepes a beallitasbol';

  @override
  String get diveComputer_discovery_noDeviceSelected =>
      'Nincs eszkoz kivalasztva';

  @override
  String get diveComputer_discovery_pleaseWaitConnection =>
      'Kerem, varjon, amig letrehozzuk a kapcsolatot';

  @override
  String get diveComputer_discovery_recognizedDevice => 'Felismert eszkoz';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      'Ez az eszkoz szerepel a tamogatott eszkozok konyvtaraban. A merulesek letoltese automatikusan mukodik.';

  @override
  String get diveComputer_discovery_stepConnect => 'Csatlakozas';

  @override
  String get diveComputer_discovery_stepDone => 'Kesz';

  @override
  String get diveComputer_discovery_stepDownload => 'Letoltes';

  @override
  String get diveComputer_discovery_stepScan => 'Kereses';

  @override
  String get diveComputer_discovery_titleComplete => 'Kesz';

  @override
  String get diveComputer_discovery_titleConfirmDevice => 'Eszkoz megerositese';

  @override
  String get diveComputer_discovery_titleConnecting => 'Csatlakozas';

  @override
  String get diveComputer_discovery_titleDownloading => 'Letoltes';

  @override
  String get diveComputer_discovery_titleFindDevice => 'Eszkoz keresese';

  @override
  String get diveComputer_discovery_unknownDevice => 'Ismeretlen eszkoz';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      'Ez az eszkoz nem szerepel a konyvtarunkban. Megprobaljuk csatlakoztatni, de a letoltes nem feltetlen mukodik.';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... es meg $count tovabbi';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Megse';

  @override
  String get diveComputer_downloadStep_cancelled => 'Download cancelled';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadFailed =>
      'A letoltes sikertelen';

  @override
  String get diveComputer_downloadStep_downloadedDives => 'Letoltott merulesek';

  @override
  String diveComputer_downloadStep_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_downloadStep_errorOccurred => 'Hiba tortent';

  @override
  String diveComputer_downloadStep_errorSemanticLabel(Object error) {
    return 'Letoltesi hiba: $error';
  }

  @override
  String diveComputer_downloadStep_percentAccessibility(Object percent) {
    return ', $percent szazalek';
  }

  @override
  String get diveComputer_downloadStep_preparing => 'Elokeszites...';

  @override
  String diveComputer_downloadStep_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String diveComputer_downloadStep_progressSemanticLabel(
    Object status,
    Object percent,
  ) {
    return 'Letoltesi folyamat: $status$percent';
  }

  @override
  String get diveComputer_downloadStep_retry => 'Ujraproba';

  @override
  String get diveComputer_download_cancel => 'Megse';

  @override
  String get diveComputer_download_closeTooltip => 'Bezaras';

  @override
  String get diveComputer_download_computerNotFound =>
      'A szamitogep nem talalhato';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return 'Az eszkoz nem talalhato. Gyozodjon meg rola, hogy a(z) $name a kozelben van es atviteli modban.';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle =>
      'Az eszkoz nem talalhato';

  @override
  String get diveComputer_download_divesUpdated => 'Merulesek frissitve';

  @override
  String get diveComputer_download_done => 'Kesz';

  @override
  String get diveComputer_download_downloadedDives => 'Letoltott merulesek';

  @override
  String get diveComputer_download_duplicatesSkipped => 'Duplikatumok kihagyva';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_download_errorOccurred => 'Hiba tortent';

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get diveComputer_download_goBack => 'Vissza';

  @override
  String get diveComputer_download_importFailed => 'Az importalas sikertelen';

  @override
  String get diveComputer_download_importResults => 'Importalasi eredmenyek';

  @override
  String get diveComputer_download_importedDives => 'Importalt merulesek';

  @override
  String get diveComputer_download_newDivesImported =>
      'Uj merulesek importalva';

  @override
  String get diveComputer_download_preparing => 'Elokeszites...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_retry => 'Ujraproba';

  @override
  String diveComputer_download_scanError(Object error) {
    return 'Keresesi hiba: $error';
  }

  @override
  String diveComputer_download_searchingForDevice(Object name) {
    return 'Kereses: $name...';
  }

  @override
  String get diveComputer_download_searchingInstructions =>
      'Gyozodjon meg rola, hogy az eszkoz a kozelben van es atviteli modban';

  @override
  String get diveComputer_download_title => 'Merulesek letoltese';

  @override
  String get diveComputer_download_tryAgain => 'Probald ujra';

  @override
  String get diveComputer_list_addComputer => 'Szamitogep hozzaadasa';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return 'Merulesszamitogep: $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count merules';
  }

  @override
  String get diveComputer_list_downloadTooltip => 'Merulesek letoltese';

  @override
  String get diveComputer_list_emptyMessage =>
      'Csatlakoztassa merulesszamitogepet, hogy kozvetlenul letolthesse a meruleseket az alkalmazasba.';

  @override
  String get diveComputer_list_emptyTitle => 'Nincsenek merulesszamitogepek';

  @override
  String get diveComputer_list_findComputers => 'Szamitogepek keresese';

  @override
  String get diveComputer_list_helpBluetooth =>
      '- Bluetooth LE (legtobb modern szamitogep)';

  @override
  String get diveComputer_list_helpBluetoothClassic =>
      '- Bluetooth Classic (regebbi modellek)';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi es 50+ tovabbi modell.';

  @override
  String get diveComputer_list_helpBrandsTitle => 'Tamogatott markak';

  @override
  String get diveComputer_list_helpConnectionsTitle => 'Tamogatott kapcsolatok';

  @override
  String get diveComputer_list_helpDialogTitle => 'Merulesszamitogep segitseg';

  @override
  String get diveComputer_list_helpDismiss => 'Rendben';

  @override
  String get diveComputer_list_helpTip1 =>
      '- Gyozodjon meg rola, hogy a szamitogep atviteli modban van';

  @override
  String get diveComputer_list_helpTip2 =>
      '- Tartsa kozel az eszkozoket letoltes kozben';

  @override
  String get diveComputer_list_helpTip3 =>
      '- Gyozodjon meg rola, hogy a Bluetooth be van kapcsolva';

  @override
  String get diveComputer_list_helpTipsTitle => 'Tippek';

  @override
  String get diveComputer_list_helpTooltip => 'Segitseg';

  @override
  String get diveComputer_list_helpUsb => '- USB (csak asztali gep)';

  @override
  String get diveComputer_list_loadFailed =>
      'Nem sikerult a merulesszamitogepek betoltese';

  @override
  String get diveComputer_list_retry => 'Ujraproba';

  @override
  String get diveComputer_list_title => 'Merulesszamitogepek';

  @override
  String get diveComputer_summary_diveComputer => 'merulesszamitogep';

  @override
  String diveComputer_summary_divesDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 letoltve';
  }

  @override
  String get diveComputer_summary_done => 'Kesz';

  @override
  String get diveComputer_summary_imported => 'Importalt';

  @override
  String diveComputer_summary_semanticLabel(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 letoltve innen: $name';
  }

  @override
  String get diveComputer_summary_skippedDuplicates =>
      'Kihagyva (duplikatumok)';

  @override
  String get diveComputer_summary_title => 'Letoltes kesz!';

  @override
  String get diveComputer_summary_updated => 'Frissitve';

  @override
  String get diveComputer_summary_viewDives => 'Merulesek megtekintese';

  @override
  String get diveImport_alreadyImported => 'Mar importalva';

  @override
  String get diveImport_avgHR => 'Atl. szivfrekvencia';

  @override
  String get diveImport_back => 'Vissza';

  @override
  String get diveImport_deselectAll => 'Osszes kijeloles torlese';

  @override
  String get diveImport_divesImported => 'Merulesek importalva';

  @override
  String get diveImport_divesMerged => 'Merulesek osszefuzve';

  @override
  String get diveImport_divesSkipped => 'Merulesek kihagyva';

  @override
  String get diveImport_done => 'Kesz';

  @override
  String get diveImport_duration => 'Idotartam';

  @override
  String get diveImport_error => 'Hiba';

  @override
  String get diveImport_fit_closeTooltip => 'FIT importalas bezarasa';

  @override
  String get diveImport_fit_noDivesDescription =>
      'Valasszon ki egy vagy tobb .fit fajlt, amelyet a Garmin Connect-bol exportalt vagy Garmin Descent eszkozrol masolt.';

  @override
  String get diveImport_fit_noDivesLoaded => 'Nincsenek betoltott merulesek';

  @override
  String diveImport_fit_parsed(int diveCount, int fileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'fajlbol',
      one: 'fajlbol',
    );
    return '$diveCount $_temp0 feldolgozva $fileCount $_temp1';
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
      other: 'merules',
      one: 'merules',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'fajlbol',
      one: 'fajlbol',
    );
    return '$diveCount $_temp0 feldolgozva $fileCount $_temp1 ($skippedCount kihagyva)';
  }

  @override
  String get diveImport_fit_parsing => 'Feldolgozas...';

  @override
  String get diveImport_fit_selectFiles => 'FIT fajlok kivalasztasa';

  @override
  String get diveImport_fit_title => 'Importalas FIT fajlbol';

  @override
  String get diveImport_healthkit_accessDescription =>
      'A Submersion-nek hozzaferesre van szuksege az Apple Watch merulesi adataihoz az importalashoz.';

  @override
  String get diveImport_healthkit_accessRequired =>
      'HealthKit hozzaferes szukseges';

  @override
  String get diveImport_healthkit_closeTooltip =>
      'Apple Watch importalas bezarasa';

  @override
  String get diveImport_healthkit_dateFrom => 'Ettol';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return '$label datum valaszto';
  }

  @override
  String get diveImport_healthkit_dateTo => 'Eddig';

  @override
  String get diveImport_healthkit_fetchDives => 'Merulesek lekerese';

  @override
  String get diveImport_healthkit_fetching => 'Lekeres...';

  @override
  String get diveImport_healthkit_grantAccess => 'Hozzaferes engedelyezese';

  @override
  String get diveImport_healthkit_noDivesFound => 'Nem talalhato merules';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'A kivalasztott idoszakban nem talalhato vizalatti merulesi tevekenyse.';

  @override
  String get diveImport_healthkit_notAvailable => 'Nem elerheto';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'Az Apple Watch importalas csak iOS es macOS eszkozokon erheto el.';

  @override
  String get diveImport_healthkit_permissionCheckFailed =>
      'Nem sikerult az engedelyek ellenorzese';

  @override
  String get diveImport_healthkit_title => 'Importalas Apple Watch-rol';

  @override
  String get diveImport_healthkit_watchTitle => 'Importalas orarol';

  @override
  String get diveImport_import => 'Importalas';

  @override
  String get diveImport_importComplete => 'Importalas kesz';

  @override
  String get diveImport_likelyDuplicate => 'Valoszinuleg duplikatum';

  @override
  String get diveImport_maxDepth => 'Max. melyseg';

  @override
  String get diveImport_newDive => 'Uj merules';

  @override
  String get diveImport_next => 'Kovetkezo';

  @override
  String get diveImport_possibleDuplicate => 'Lehetseges duplikatum';

  @override
  String get diveImport_reviewSelectedDives =>
      'Kivalasztott merulesek attekintese';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: ', $possibleCount lehetseges duplikatum',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: ', $skipCount kihagyasra kerul',
      zero: '',
    );
    return '$newCount uj$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => 'Osszes kijelolese';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count kivalasztva';
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
  String get diveImport_step_done => 'Kesz';

  @override
  String get diveImport_step_review => 'Attekintes';

  @override
  String get diveImport_step_select => 'Kivalasztas';

  @override
  String get diveImport_temp => 'Hom.';

  @override
  String get diveImport_toggleDiveSelection => 'Merules kijelolesenek valtasa';

  @override
  String get diveImport_uddf_buddies => 'Buddyk';

  @override
  String get diveImport_uddf_certifications => 'Tanusitvanyok';

  @override
  String get diveImport_uddf_closeTooltip => 'UDDF importalas bezarasa';

  @override
  String get diveImport_uddf_diveCenters => 'Buvarkoezpontok';

  @override
  String get diveImport_uddf_diveTypes => 'Merulestipusok';

  @override
  String get diveImport_uddf_dives => 'Merulesek';

  @override
  String get diveImport_uddf_duplicate => 'Duplikatum';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return '$count duplikatum talalva es automatikusan kijeloles megszuntetve.';
  }

  @override
  String get diveImport_uddf_equipment => 'Felszereles';

  @override
  String get diveImport_uddf_equipmentSets => 'Felszerelesszettek';

  @override
  String diveImport_uddf_importProgress(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get diveImport_uddf_importing => 'Importalas...';

  @override
  String get diveImport_uddf_likelyDuplicate => 'Valoszinuleg duplikatum';

  @override
  String get diveImport_uddf_noFileDescription =>
      'Valasszon ki egy .uddf vagy .xml fajlt, amelyet masik merulesi naplo alkalmazasbol exportalt.';

  @override
  String get diveImport_uddf_noFileSelected => 'Nincs fajl kivalasztva';

  @override
  String get diveImport_uddf_parsing => 'Feldolgozas...';

  @override
  String get diveImport_uddf_possibleDuplicate => 'Lehetseges duplikatum';

  @override
  String get diveImport_uddf_selectFile => 'UDDF fajl kivalasztasa';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '$selected / $total kivalasztva';
  }

  @override
  String get diveImport_uddf_sites => 'Helyszinek';

  @override
  String get diveImport_uddf_stepImport => 'Importalas';

  @override
  String get diveImport_uddf_tabBuddies => 'Buddyk';

  @override
  String get diveImport_uddf_tabCenters => 'Kozpontok';

  @override
  String get diveImport_uddf_tabCerts => 'Kepesitesek';

  @override
  String get diveImport_uddf_tabCourses => 'Tanfolyamok';

  @override
  String get diveImport_uddf_tabDives => 'Merulesek';

  @override
  String get diveImport_uddf_tabEquipment => 'Felszereles';

  @override
  String get diveImport_uddf_tabSets => 'Szettek';

  @override
  String get diveImport_uddf_tabSites => 'Helyszinek';

  @override
  String get diveImport_uddf_tabTags => 'Cimkek';

  @override
  String get diveImport_uddf_tabTrips => 'Utak';

  @override
  String get diveImport_uddf_tabTypes => 'Tipusok';

  @override
  String get diveImport_uddf_tags => 'Cimkek';

  @override
  String get diveImport_uddf_title => 'Importalas UDDF-bol';

  @override
  String get diveImport_uddf_toggleDiveSelection =>
      'Merules kijelolesenek valtasa';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return '$name kijelolesenek valtasa';
  }

  @override
  String get diveImport_uddf_trips => 'Utak';

  @override
  String get divePlanner_segmentEditor_addTitle => 'Szegmens hozzaadasa';

  @override
  String divePlanner_segmentEditor_ascentRate(Object unit) {
    return 'Emelkedesi sebesseg ($unit/min)';
  }

  @override
  String divePlanner_segmentEditor_descentRate(Object unit) {
    return 'Süllyedesi sebesseg ($unit/min)';
  }

  @override
  String get divePlanner_segmentEditor_duration => 'Idotartam (min)';

  @override
  String get divePlanner_segmentEditor_editTitle => 'Szegmens szerkesztese';

  @override
  String divePlanner_segmentEditor_endDepth(Object unit) {
    return 'Vegmelyseg ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_gasSwitchTime => 'Gazcsere ideje';

  @override
  String get divePlanner_segmentEditor_segmentType => 'Szegmens tipusa';

  @override
  String divePlanner_segmentEditor_startDepth(Object unit) {
    return 'Kezdo melyseg ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_tankGas => 'Palack / Gaz';

  @override
  String get divePlanner_segmentList_addSegment => 'Szegmens hozzaadasa';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return 'Emelkedes $startDepth -> $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return 'Fenek $depth, $minutes min';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return 'Deko $depth, $minutes min';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => 'Szegmens torlese';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return 'Süllyedes $startDepth -> $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => 'Szegmens szerkesztese';

  @override
  String get divePlanner_segmentList_emptyMessage =>
      'Adjon hozza szegmenseket kezzel, vagy hozzon letre egy gyors tervet';

  @override
  String get divePlanner_segmentList_emptyTitle => 'Meg nincsenek szegmensek';

  @override
  String divePlanner_segmentList_gasSwitch(Object gasName) {
    return 'Gazcsere erre: $gasName';
  }

  @override
  String get divePlanner_segmentList_quickPlan => 'Gyors terv';

  @override
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes) {
    return 'Biztonsagi megallo $depth, $minutes min';
  }

  @override
  String get divePlanner_segmentList_title => 'Merulesi szegmensek';

  @override
  String get divePlanner_segmentType_ascent => 'Emelkedes';

  @override
  String get divePlanner_segmentType_bottomTime => 'Fenekido';

  @override
  String get divePlanner_segmentType_decoStop => 'Deko megallo';

  @override
  String get divePlanner_segmentType_descent => 'Süllyedes';

  @override
  String get divePlanner_segmentType_gasSwitch => 'Gazcsere';

  @override
  String get divePlanner_segmentType_safetyStop => 'Biztonsagi megallo';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'A Rock Bottom az a minimalis gaztartalek, ami egy veszelyes helyzetben szukseges a felszinre ereshez, mikozben levegot oszt meg a buddyjaval.\n\n- Stresszes SAC ertekeket hasznal (2-3x normalis)\n- Feltetelezi, hogy mindket merulo egy palackrol sziv\n- Tartalmazza a biztonsagi megallot, ha engedelyezve van\n\nMindig forduljon vissza, mielott eleri a Rock Bottom erteket!';

  @override
  String get gasCalculators_rockBottom_aboutTitle => 'A Rock Bottom-rol';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired =>
      'Emelkedeshez szukseges gaz';

  @override
  String get gasCalculators_rockBottom_ascentRate => 'Emelkedesi sebesseg';

  @override
  String gasCalculators_rockBottom_ascentTimeToDepth(
    Object depth,
    Object unit,
  ) {
    return 'Emelkedesi ido $depth$unit-ig';
  }

  @override
  String get gasCalculators_rockBottom_ascentTimeToSurface =>
      'Emelkedesi ido a felszinig';

  @override
  String get gasCalculators_rockBottom_buddySac => 'Buddy SAC';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'Kombinalt stresszes SAC';

  @override
  String get gasCalculators_rockBottom_emergencyAscentBreakdown =>
      'Veszelyzeti emelkedes reszletei';

  @override
  String get gasCalculators_rockBottom_emergencyScenario =>
      'Veszhelyzeti szcenario';

  @override
  String get gasCalculators_rockBottom_includeSafetyStop =>
      'Biztonsagi megallo beszamitasa';

  @override
  String get gasCalculators_rockBottom_maximumDepth => 'Maximalis melyseg';

  @override
  String get gasCalculators_rockBottom_minimumReserve => 'Minimalis tartalek';

  @override
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  ) {
    return 'Minimalis tartalek: $pressure $pressureUnit, $volume $volumeUnit. Forduljon vissza, ha a hatralevo gaz eleri a(z) $pressure $pressureUnit erteket';
  }

  @override
  String gasCalculators_rockBottom_safetyStopDuration(
    Object depth,
    Object unit,
  ) {
    return '3 perc $depth$unit-on';
  }

  @override
  String gasCalculators_rockBottom_safetyStopGas(Object depth, Object unit) {
    return 'Biztonsagi megallo gaz (3 perc @ $depth$unit)';
  }

  @override
  String get gasCalculators_rockBottom_stressedSacHint =>
      'Hasznaljon magasabb SAC ertekeket a veszhelyzeti stressz figyelembevetelere';

  @override
  String get gasCalculators_rockBottom_stressedSacRates =>
      'Stresszes SAC ertekek';

  @override
  String get gasCalculators_rockBottom_tankSize => 'Palack meret';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded =>
      'Osszes szukseges tartalek';

  @override
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  ) {
    return 'Forduljon vissza, ha a hatralevo gaz eleri a(z) $pressure $pressureUnit erteket';
  }

  @override
  String get gasCalculators_rockBottom_yourSac => 'Sajat SAC';

  @override
  String get maps_heatMap_hide => 'Hoterkep elrejtese';

  @override
  String get maps_heatMap_overlayOff => 'A hoterkep reteg ki van kapcsolva';

  @override
  String get maps_heatMap_overlayOn => 'A hoterkep reteg be van kapcsolva';

  @override
  String get maps_heatMap_show => 'Hoterkep megjelenitese';

  @override
  String get maps_offline_bounds => 'Hatarok';

  @override
  String maps_offline_cacheHitRateAccessibility(Object rate) {
    return 'Gyorstar talalati arany: $rate szazalek';
  }

  @override
  String get maps_offline_cacheHits => 'Gyorstar talalatok';

  @override
  String get maps_offline_cacheMisses => 'Gyorstar hianyok';

  @override
  String get maps_offline_cacheStatistics => 'Gyorstar statisztikak';

  @override
  String get maps_offline_cancelDownload => 'Letoltes megszakitasa';

  @override
  String get maps_offline_clearAll => 'Osszes torlese';

  @override
  String get maps_offline_clearAllCache => 'Teljes gyorstar torlese';

  @override
  String get maps_offline_clearAllCacheMessage =>
      'Torli az osszes letoltott terkepregiit es gyorsitott csempet?';

  @override
  String get maps_offline_clearAllCacheTitle => 'Teljes gyorstar torlese?';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return 'Ez $count csempet ($size) fog torolni.';
  }

  @override
  String get maps_offline_created => 'Letrehozva';

  @override
  String maps_offline_deleteRegion(Object name) {
    return '$name regio torlese';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return 'Torli a(z) \"$name\" regiot es a(z) $count gyorsitott csempejeet?\n\nEz $size tarolot szabadit fel.';
  }

  @override
  String get maps_offline_deleteRegionTitle => 'Regio torlese?';

  @override
  String get maps_offline_downloadedRegions => 'Letoltott regiok';

  @override
  String maps_offline_downloading(Object regionName) {
    return 'Letoltes: $regionName';
  }

  @override
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  ) {
    return '$regionName letoltese, $percent szazalek kesz, $downloaded / $total csempe';
  }

  @override
  String maps_offline_error(Object error) {
    return 'Hiba: $error';
  }

  @override
  String maps_offline_errorLoadingStats(Object error) {
    return 'Hiba a statisztikak betoltesekor: $error';
  }

  @override
  String maps_offline_failedTiles(Object count) {
    return '$count sikertelen';
  }

  @override
  String maps_offline_hitRate(Object rate) {
    return 'Talalati arany: $rate%';
  }

  @override
  String get maps_offline_lastAccessed => 'Utolso hozzaferes';

  @override
  String get maps_offline_noRegions => 'Nincsenek offline regiok';

  @override
  String get maps_offline_noRegionsDescription =>
      'Toltson le terkepregiokat a helyszin reszletes oldalrol, hogy terkepeket hasznalhasson offline.';

  @override
  String get maps_offline_refresh => 'Frissites';

  @override
  String get maps_offline_region => 'Regio';

  @override
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size | $count csempe | Zoom $minZoom-$maxZoom';
  }

  @override
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size, $count csempe, zoom $minZoom-tol $maxZoom-ig';
  }

  @override
  String get maps_offline_size => 'Meret';

  @override
  String get maps_offline_tiles => 'Csempek';

  @override
  String maps_offline_tilesPerSecond(Object rate) {
    return '$rate csempe/mp';
  }

  @override
  String maps_offline_tilesProgress(Object downloaded, Object total) {
    return '$downloaded / $total csempe';
  }

  @override
  String get maps_offline_title => 'Offline terkepek';

  @override
  String get maps_offline_zoomRange => 'Zoom tartomany';

  @override
  String get maps_regionSelector_dragToAdjust =>
      'Huzza a kivalasztas modositasahoz';

  @override
  String get maps_regionSelector_dragToSelect =>
      'Huzza a terkepen egy regio kivalasztasahoz';

  @override
  String get maps_regionSelector_selectRegion =>
      'Regio kivalasztasa a terkepen';

  @override
  String get maps_regionSelector_selectRegionButton => 'Regio kivalasztasa';

  @override
  String get tankPresets_addPreset => 'Palacksablon hozzaadasa';

  @override
  String get tankPresets_builtInPresets => 'Beepitett sablonok';

  @override
  String get tankPresets_customPresets => 'Egyedi sablonok';

  @override
  String tankPresets_deleteMessage(Object name) {
    return 'Biztosan torolni szeretne a(z) \"$name\" sablont?';
  }

  @override
  String get tankPresets_deletePreset => 'Sablon torlese';

  @override
  String get tankPresets_deleteTitle => 'Palacksablon torlese?';

  @override
  String tankPresets_deleted(Object name) {
    return '\"$name\" torolve';
  }

  @override
  String get tankPresets_editPreset => 'Sablon szerkesztese';

  @override
  String tankPresets_edit_created(Object name) {
    return '\"$name\" letrehozva';
  }

  @override
  String get tankPresets_edit_descriptionHint =>
      'pl. Berelt palack a buvaruzletbol';

  @override
  String get tankPresets_edit_descriptionOptional => 'Leiras (opcionalis)';

  @override
  String tankPresets_edit_errorLoading(Object error) {
    return 'Hiba a sablon betoltesekor: $error';
  }

  @override
  String tankPresets_edit_errorSaving(Object error) {
    return 'Hiba a sablon mentesekor: $error';
  }

  @override
  String tankPresets_edit_gasCapacity(Object capacity) {
    return '- Gaz kapacitas: $capacity cuft';
  }

  @override
  String get tankPresets_edit_material => 'Anyag';

  @override
  String get tankPresets_edit_name => 'Nev';

  @override
  String get tankPresets_edit_nameHelper =>
      'Baratságos nev ennek a palacksablonnak';

  @override
  String get tankPresets_edit_nameHint => 'pl. Az en AL80-am';

  @override
  String get tankPresets_edit_nameRequired => 'Kerem, adjon meg egy nevet';

  @override
  String get tankPresets_edit_ratedPressure => 'Nevleges nyomas';

  @override
  String get tankPresets_edit_required => 'Kotelezo';

  @override
  String get tankPresets_edit_tankSpecifications => 'Palack specifikaciok';

  @override
  String get tankPresets_edit_title => 'Palacksablon szerkesztese';

  @override
  String tankPresets_edit_updated(Object name) {
    return '\"$name\" frissitve';
  }

  @override
  String get tankPresets_edit_validPressure => 'Adjon meg ervenyes nyomast';

  @override
  String get tankPresets_edit_validVolume => 'Adjon meg ervenyes terfogatot';

  @override
  String get tankPresets_edit_volume => 'Terfogat';

  @override
  String get tankPresets_edit_volumeHelperCuft => 'Gaz kapacitas (cuft)';

  @override
  String get tankPresets_edit_volumeHelperLiters => 'Vizterfogat (L)';

  @override
  String tankPresets_edit_waterVolume(Object volume) {
    return '- Vizterfogat: $volume L';
  }

  @override
  String get tankPresets_edit_workingPressure => 'Üzemi nyomas';

  @override
  String tankPresets_edit_workingPressureBar(Object pressure) {
    return '- Üzemi nyomas: $pressure bar';
  }

  @override
  String tankPresets_error(Object error) {
    return 'Hiba: $error';
  }

  @override
  String tankPresets_errorDeleting(Object error) {
    return 'Hiba a sablon torlesekor: $error';
  }

  @override
  String get tankPresets_new_title => 'Uj palacksablon';

  @override
  String get tankPresets_noPresets => 'Nincsenek elerheto palacksablonok';

  @override
  String get tankPresets_title => 'Palacksablonok';

  @override
  String get tools_deco_description =>
      'Szamitsa ki a dekompresszio nelküli limiteket, szukseges deko megalokat es a CNS/OTU terhelest többszintu merülesi profilokhoz.';

  @override
  String get tools_deco_subtitle =>
      'Merulesek tervezese dekompressziós megalokkal';

  @override
  String get tools_deco_title => 'Deko szamologep';

  @override
  String get tools_disclaimer =>
      'Ezek a szamologepek csak tervezesi celokat szolgalnak. Mindig ellenorizze a szamitasokat es kovesse a merulesi kepzeset.';

  @override
  String get tools_gas_description =>
      'Negy specialis gaz szamologep:\n- MOD - Maximalis üzemi melyseg egy gazkeverekhez\n- Legjobb keverek - Idealis O₂% egy cel melyseghez\n- Fogyasztas - Gaz felhasznalasi becsles\n- Rock Bottom - Veszhelyzeti tartalek szamitas';

  @override
  String get tools_gas_subtitle =>
      'MOD, Legjobb keverek, Fogyasztas, Rock Bottom';

  @override
  String get tools_gas_title => 'Gaz szamologepek';

  @override
  String get tools_title => 'Eszkozok';

  @override
  String get tools_weight_aluminumImperial => 'Uresbben pozitivabb (+4 lbs)';

  @override
  String get tools_weight_aluminumMetric => 'Uresbben pozitivabb (+2 kg)';

  @override
  String get tools_weight_bodyWeightOptional => 'Testtomeg (opcionalis)';

  @override
  String get tools_weight_carbonFiberImperial => 'Nagyon pozitiv (+7 lbs)';

  @override
  String get tools_weight_carbonFiberMetric => 'Nagyon pozitiv (+3 kg)';

  @override
  String get tools_weight_description =>
      'Becsülje meg a szükseges sülyt az expoziciós ruha, palackanyag, viztipus es testtomeg alapjan.';

  @override
  String get tools_weight_disclaimer =>
      'Ez csak becsles. Mindig vegezzen felhajtoeroprobat a merules elejen, es szukseg szerint modositsa. A BCD, egyeni felhajtoeroe es legzesi szokasok befolyasolhatjak a tenyleges sulyigenyeket.';

  @override
  String get tools_weight_exposureSuit => 'Merulesi ruha';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return '- Gaz kapacitas: $capacity cuft';
  }

  @override
  String get tools_weight_helperImperial =>
      '~2 lbs hozzaadasa minden 22 lbs utan 154 lbs felett';

  @override
  String get tools_weight_helperMetric =>
      '~1 kg hozzaadasa minden 10 kg utan 70 kg felett';

  @override
  String get tools_weight_notSpecified => 'Nincs megadva';

  @override
  String get tools_weight_recommendedWeight => 'Ajanlott suly';

  @override
  String tools_weight_resultAccessibility(Object weight, Object unit) {
    return 'Ajanlott suly: $weight $unit';
  }

  @override
  String get tools_weight_steelImperial => 'Negativ felhajtoeroe (-4 lbs)';

  @override
  String get tools_weight_steelMetric => 'Negativ felhajtoeroe (-2 kg)';

  @override
  String get tools_weight_subtitle => 'Ajanlott suly az összeallitasahoz';

  @override
  String get tools_weight_tankMaterial => 'Palack anyag';

  @override
  String get tools_weight_tankSpecifications => 'Palack specifikaciok';

  @override
  String get tools_weight_title => 'Sulyszamologep';

  @override
  String get tools_weight_waterType => 'Viz tipusa';

  @override
  String tools_weight_waterVolume(Object volume) {
    return '- Vizterfogat: $volume L';
  }

  @override
  String tools_weight_workingPressure(Object pressure) {
    return '- Üzemi nyomas: $pressure bar';
  }

  @override
  String get tools_weight_yourWeight => 'Az Ön sulya';
}
