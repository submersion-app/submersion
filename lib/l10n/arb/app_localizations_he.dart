// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get accessibility_dialog_keyboardShortcutsTitle => 'קיצורי מקלדת';

  @override
  String get accessibility_keyLabel_backspace => 'Backspace';

  @override
  String get accessibility_keyLabel_delete => 'Delete';

  @override
  String get accessibility_keyLabel_down => 'למטה';

  @override
  String get accessibility_keyLabel_enter => 'Enter';

  @override
  String get accessibility_keyLabel_esc => 'Esc';

  @override
  String get accessibility_keyLabel_left => 'שמאלה';

  @override
  String get accessibility_keyLabel_right => 'ימינה';

  @override
  String get accessibility_keyLabel_up => 'למעלה';

  @override
  String accessibility_label_chartSummary(
    Object chartType,
    Object description,
  ) {
    return 'תרשים $chartType. $description';
  }

  @override
  String get accessibility_label_createNewItem => 'יצירת פריט חדש';

  @override
  String get accessibility_label_hideList => 'הסתרת רשימה';

  @override
  String get accessibility_label_hideMapView => 'הסתרת תצוגת מפה';

  @override
  String accessibility_label_listPane(Object title) {
    return 'חלונית רשימת $title';
  }

  @override
  String accessibility_label_mapPane(Object title) {
    return 'חלונית מפת $title';
  }

  @override
  String accessibility_label_mapViewTitle(Object title) {
    return 'תצוגת מפה של $title';
  }

  @override
  String get accessibility_label_showList => 'הצגת רשימה';

  @override
  String get accessibility_label_showMapView => 'הצגת תצוגת מפה';

  @override
  String get accessibility_label_viewDetails => 'הצגת פרטים';

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
  String get accessibility_shortcutCategory_editing => 'עריכה';

  @override
  String get accessibility_shortcutCategory_general => 'כללי';

  @override
  String get accessibility_shortcutCategory_help => 'עזרה';

  @override
  String get accessibility_shortcutCategory_navigation => 'ניווט';

  @override
  String get accessibility_shortcutCategory_search => 'חיפוש';

  @override
  String get accessibility_shortcut_closeCancel => 'סגירה / ביטול';

  @override
  String get accessibility_shortcut_goBack => 'חזרה אחורה';

  @override
  String get accessibility_shortcut_goToDives => 'מעבר לצלילות';

  @override
  String get accessibility_shortcut_goToEquipment => 'מעבר לציוד';

  @override
  String get accessibility_shortcut_goToSettings => 'מעבר להגדרות';

  @override
  String get accessibility_shortcut_goToSites => 'מעבר לאתרים';

  @override
  String get accessibility_shortcut_goToStatistics => 'מעבר לסטטיסטיקות';

  @override
  String get accessibility_shortcut_keyboardShortcuts => 'קיצורי מקלדת';

  @override
  String get accessibility_shortcut_newDive => 'צלילה חדשה';

  @override
  String get accessibility_shortcut_openSettings => 'פתיחת הגדרות';

  @override
  String get accessibility_shortcut_searchDives => 'חיפוש צלילות';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return 'מיון לפי $displayName, נבחר כעת';
  }

  @override
  String accessibility_sort_unselectedLabel(Object displayName) {
    return 'מיון לפי $displayName';
  }

  @override
  String get backup_appBar_title => 'גיבוי ושחזור';

  @override
  String get backup_backingUp => 'מגבה...';

  @override
  String get backup_backupNow => 'גבה עכשיו';

  @override
  String get backup_cloud_enabled => 'גיבוי ענן';

  @override
  String get backup_cloud_enabled_subtitle => 'העלה גיבויים לאחסון ענן';

  @override
  String get backup_delete_dialog_cancel => 'ביטול';

  @override
  String get backup_delete_dialog_content =>
      'גיבוי זה יימחק לצמיתות. לא ניתן לבטל פעולה זו.';

  @override
  String get backup_delete_dialog_delete => 'מחיקה';

  @override
  String get backup_delete_dialog_title => 'מחיקת גיבוי';

  @override
  String get backup_frequency_daily => 'יומי';

  @override
  String get backup_frequency_monthly => 'חודשי';

  @override
  String get backup_frequency_weekly => 'שבועי';

  @override
  String get backup_history_action_delete => 'מחיקה';

  @override
  String get backup_history_action_restore => 'שחזור';

  @override
  String get backup_history_empty => 'אין גיבויים';

  @override
  String backup_history_error(Object error) {
    return 'שגיאה בטעינת היסטוריה: $error';
  }

  @override
  String get backup_restore_dialog_cancel => 'ביטול';

  @override
  String get backup_restore_dialog_restore => 'שחזור';

  @override
  String get backup_restore_dialog_safetyNote =>
      'גיבוי בטיחות של הנתונים הנוכחיים שלך ייווצר אוטומטית לפני השחזור.';

  @override
  String get backup_restore_dialog_title => 'שחזור גיבוי';

  @override
  String get backup_restore_dialog_warning =>
      'פעולה זו תחליף את כל הנתונים הנוכחיים בנתוני הגיבוי. לא ניתן לבטל פעולה זו.';

  @override
  String get backup_schedule_enabled => 'גיבויים אוטומטיים';

  @override
  String get backup_schedule_enabled_subtitle => 'גבה את הנתונים לפי לוח זמנים';

  @override
  String get backup_schedule_frequency => 'תדירות';

  @override
  String get backup_schedule_retention => 'שמור גיבויים';

  @override
  String get backup_schedule_retention_subtitle =>
      'גיבויים ישנים יותר מוסרים אוטומטית';

  @override
  String get backup_section_cloud => 'ענן';

  @override
  String get backup_section_history => 'היסטוריה';

  @override
  String get backup_section_schedule => 'תזמון';

  @override
  String get backup_status_disabled => 'גיבויים אוטומטיים מושבתים';

  @override
  String backup_status_lastBackup(String time) {
    return 'גיבוי אחרון: $time';
  }

  @override
  String get backup_status_neverBackedUp => 'מעולם לא גובה';

  @override
  String get backup_status_noBackupsYet =>
      'צור את הגיבוי הראשון שלך כדי להגן על הנתונים שלך';

  @override
  String get backup_status_overdue => 'גיבוי באיחור';

  @override
  String get backup_status_upToDate => 'גיבויים מעודכנים';

  @override
  String backup_time_daysAgo(int count) {
    return 'לפני $count ימים';
  }

  @override
  String backup_time_hoursAgo(int count) {
    return 'לפני $count שעות';
  }

  @override
  String get backup_time_justNow => 'הרגע';

  @override
  String backup_time_minutesAgo(int count) {
    return 'לפני $count דקות';
  }

  @override
  String get buddies_action_add => 'הוסף חבר צוללים';

  @override
  String get buddies_action_addFirst => 'הוסף את חבר הצוללים הראשון שלך';

  @override
  String get buddies_action_addTooltip => 'הוסף חבר צוללים חדש';

  @override
  String get buddies_action_clearSearch => 'נקה חיפוש';

  @override
  String get buddies_action_edit => 'ערוך חבר צוללים';

  @override
  String get buddies_action_importFromContacts => 'ייבא מאנשי קשר';

  @override
  String get buddies_action_moreOptions => 'אפשרויות נוספות';

  @override
  String get buddies_action_retry => 'נסה שוב';

  @override
  String get buddies_action_search => 'חפש חברי צוללים';

  @override
  String get buddies_action_shareDives => 'שתף צלילות';

  @override
  String get buddies_action_sort => 'מיין';

  @override
  String get buddies_action_sortTitle => 'מיין חברי צוללים';

  @override
  String get buddies_action_update => 'עדכן חבר צוללים';

  @override
  String buddies_action_viewAll(Object count) {
    return 'הצג הכל ($count)';
  }

  @override
  String buddies_detail_error(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get buddies_detail_noDivesTogether => 'עדיין אין צלילות משותפות';

  @override
  String get buddies_detail_notFound => 'חבר צוללים לא נמצא';

  @override
  String buddies_dialog_deleteMessage(Object name) {
    return 'האם אתה בטוח שברצונך למחוק את $name? פעולה זו אינה ניתנת לביטול.';
  }

  @override
  String get buddies_dialog_deleteTitle => 'למחוק חבר צוללים?';

  @override
  String get buddies_dialog_discard => 'בטל';

  @override
  String get buddies_dialog_discardMessage =>
      'יש לך שינויים שלא נשמרו. האם אתה בטוח שברצונך לבטל אותם?';

  @override
  String get buddies_dialog_discardTitle => 'לבטל שינויים?';

  @override
  String get buddies_dialog_keepEditing => 'המשך עריכה';

  @override
  String get buddies_empty_subtitle =>
      'הוסף את חבר הצוללים הראשון שלך כדי להתחיל';

  @override
  String get buddies_empty_title => 'עדיין אין חברי צוללים';

  @override
  String buddies_error_loading(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get buddies_error_unableToLoadDives => 'לא ניתן לטעון צלילות';

  @override
  String get buddies_error_unableToLoadStats => 'לא ניתן לטעון סטטיסטיקות';

  @override
  String get buddies_field_certificationAgency => 'גוף הסמכה';

  @override
  String get buddies_field_certificationLevel => 'רמת הסמכה';

  @override
  String get buddies_field_email => 'דוא\"ל';

  @override
  String get buddies_field_emailHint => 'email@example.com';

  @override
  String get buddies_field_nameHint => 'הזן שם חבר צוללים';

  @override
  String get buddies_field_nameRequired => 'שם *';

  @override
  String get buddies_field_notes => 'הערות';

  @override
  String get buddies_field_notesHint => 'הוסף הערות על חבר צוללים זה...';

  @override
  String get buddies_field_phone => 'טלפון';

  @override
  String get buddies_field_phoneHint => '+972-50-123-4567';

  @override
  String get buddies_label_agency => 'גוף הסמכה';

  @override
  String buddies_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות',
      one: 'צלילה אחת',
    );
    return '$_temp0';
  }

  @override
  String get buddies_label_level => 'רמה';

  @override
  String get buddies_label_notSpecified => 'לא צוין';

  @override
  String get buddies_label_photoComingSoon => 'תמיכה בתמונה תגיע ב-v2.0';

  @override
  String get buddies_message_added => 'חבר צוללים נוסף בהצלחה';

  @override
  String get buddies_message_contactImportUnavailable =>
      'ייבוא אנשי קשר אינו זמין בפלטפורמה זו';

  @override
  String get buddies_message_contactLoadFailed => 'נכשל בטעינת אנשי קשר';

  @override
  String get buddies_message_contactPermissionRequired =>
      'נדרשת הרשאת אנשי קשר לייבוא חברי צוללים';

  @override
  String get buddies_message_deleted => 'חבר צוללים נמחק';

  @override
  String buddies_message_errorImportingContact(Object error) {
    return 'שגיאה בייבוא איש קשר: $error';
  }

  @override
  String buddies_message_errorLoading(Object error) {
    return 'שגיאה בטעינת חבר צוללים: $error';
  }

  @override
  String buddies_message_errorSaving(Object error) {
    return 'שגיאה בשמירת חבר צוללים: $error';
  }

  @override
  String buddies_message_exportFailed(Object error) {
    return 'ייצוא נכשל: $error';
  }

  @override
  String get buddies_message_noDivesFound => 'לא נמצאו צלילות לייצוא';

  @override
  String get buddies_message_noDivesToShare =>
      'אין צלילות לשיתוף עם חבר צוללים זה';

  @override
  String get buddies_message_preparingExport => 'מכין ייצוא...';

  @override
  String get buddies_message_updated => 'חבר צוללים עודכן בהצלחה';

  @override
  String get buddies_picker_add => 'הוסף';

  @override
  String get buddies_picker_addNew => 'הוסף חבר צוללים חדש';

  @override
  String get buddies_picker_done => 'סיום';

  @override
  String get buddies_picker_noBuddiesFound => 'לא נמצאו חברי צוללים';

  @override
  String get buddies_picker_noBuddiesYet => 'עדיין אין חברי צוללים';

  @override
  String get buddies_picker_noneSelected => 'לא נבחרו חברי צוללים';

  @override
  String get buddies_picker_searchHint => 'חפש חברי צוללים...';

  @override
  String get buddies_picker_selectBuddies => 'בחר חברי צוללים';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'בחר תפקיד עבור $name';
  }

  @override
  String get buddies_picker_tapToAdd => 'לחץ על \'הוסף\' כדי לבחור חברי צוללים';

  @override
  String get buddies_search_hint => 'חפש לפי שם, דוא\"ל או טלפון';

  @override
  String buddies_search_noResults(Object query) {
    return 'לא נמצאו חברי צוללים עבור \"$query\"';
  }

  @override
  String get buddies_section_certification => 'הסמכה';

  @override
  String get buddies_section_contact => 'יצירת קשר';

  @override
  String get buddies_section_diveStatistics => 'סטטיסטיקות צלילה';

  @override
  String get buddies_section_notes => 'הערות';

  @override
  String get buddies_section_sharedDives => 'צלילות משותפות';

  @override
  String get buddies_stat_divesTogether => 'צלילות ביחד';

  @override
  String get buddies_stat_favoriteSite => 'אתר מועדף';

  @override
  String get buddies_stat_firstDive => 'צלילה ראשונה';

  @override
  String get buddies_stat_lastDive => 'צלילה אחרונה';

  @override
  String get buddies_summary_overview => 'סקירה כללית';

  @override
  String get buddies_summary_quickActions => 'פעולות מהירות';

  @override
  String get buddies_summary_recentBuddies => 'חברי צוללים אחרונים';

  @override
  String get buddies_summary_selectHint =>
      'בחר חבר צוללים מהרשימה כדי להציג פרטים';

  @override
  String get buddies_summary_title => 'חברי צוללים';

  @override
  String get buddies_summary_totalBuddies => 'סה\"כ חברי צוללים';

  @override
  String get buddies_summary_withCertification => 'עם הסמכה';

  @override
  String get buddies_title => 'חברי צוללים';

  @override
  String get buddies_title_add => 'הוסף חבר צוללים';

  @override
  String get buddies_title_edit => 'ערוך חבר צוללים';

  @override
  String get buddies_title_singular => 'חבר צוללים';

  @override
  String get buddies_validation_emailInvalid => 'נא להזין כתובת דוא\"ל תקינה';

  @override
  String get buddies_validation_nameRequired => 'נא להזין שם';

  @override
  String get certifications_appBar_addCertification => 'הוסף הסמכה';

  @override
  String get certifications_appBar_certificationWallet => 'ארנק הסמכות';

  @override
  String get certifications_appBar_editCertification => 'ערוך הסמכה';

  @override
  String get certifications_appBar_title => 'הסמכות';

  @override
  String get certifications_detail_action_delete => 'מחק';

  @override
  String get certifications_detail_appBar_title => 'הסמכה';

  @override
  String get certifications_detail_courseCompleted => 'הושלם';

  @override
  String get certifications_detail_courseInProgress => 'בתהליך';

  @override
  String get certifications_detail_dialog_cancel => 'ביטול';

  @override
  String get certifications_detail_dialog_deleteConfirm => 'מחק';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return 'האם אתה בטוח שברצונך למחוק את \"$name\"?';
  }

  @override
  String get certifications_detail_dialog_deleteTitle => 'למחוק הסמכה?';

  @override
  String get certifications_detail_label_agency => 'סוכנות';

  @override
  String get certifications_detail_label_cardNumber => 'מספר כרטיס';

  @override
  String get certifications_detail_label_expiryDate => 'תאריך תפוגה';

  @override
  String get certifications_detail_label_instructorName => 'שם';

  @override
  String get certifications_detail_label_instructorNumber => 'מספר מדריך';

  @override
  String get certifications_detail_label_issueDate => 'תאריך הנפקה';

  @override
  String get certifications_detail_label_level => 'רמה';

  @override
  String get certifications_detail_label_type => 'סוג';

  @override
  String get certifications_detail_label_validity => 'תוקף';

  @override
  String get certifications_detail_noExpiration => 'ללא תפוגה';

  @override
  String get certifications_detail_notFound => 'ההסמכה לא נמצאה';

  @override
  String get certifications_detail_photoLabel_back => 'אחורי';

  @override
  String get certifications_detail_photoLabel_front => 'קדמי';

  @override
  String certifications_detail_photo_fullscreenTitle(
    Object label,
    Object name,
  ) {
    return '$label - $name';
  }

  @override
  String get certifications_detail_photo_unableToLoad => 'לא ניתן לטעון תמונה';

  @override
  String get certifications_detail_sectionTitle_cardPhotos => 'תמונות כרטיס';

  @override
  String get certifications_detail_sectionTitle_dates => 'תאריכים';

  @override
  String get certifications_detail_sectionTitle_details => 'פרטי הסמכה';

  @override
  String get certifications_detail_sectionTitle_instructor => 'מדריך';

  @override
  String get certifications_detail_sectionTitle_notes => 'הערות';

  @override
  String get certifications_detail_sectionTitle_trainingCourse => 'קורס הכשרה';

  @override
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  ) {
    return 'תמונת $label של $name. הקש לצפייה במסך מלא';
  }

  @override
  String get certifications_detail_snackBar_deleted => 'ההסמכה נמחקה';

  @override
  String get certifications_detail_status_expired => 'הסמכה זו פגה';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return 'פגה ב-$date';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return 'פגה בעוד $days ימים';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return 'פגה ב-$date';
  }

  @override
  String get certifications_detail_tooltip_edit => 'ערוך הסמכה';

  @override
  String get certifications_detail_tooltip_editShort => 'ערוך';

  @override
  String get certifications_detail_tooltip_moreOptions => 'אפשרויות נוספות';

  @override
  String get certifications_ecardStack_empty_subtitle =>
      'הוסף את ההסמכה הראשונה שלך כדי לראות אותה כאן';

  @override
  String get certifications_ecardStack_empty_title => 'אין עדיין הסמכות';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'הוסמך על ידי $agency';
  }

  @override
  String get certifications_ecard_label_instructor => 'מדריך';

  @override
  String get certifications_ecard_label_issued => 'הונפק';

  @override
  String get certifications_ecard_statusBadge_expired => 'פג תוקף';

  @override
  String get certifications_ecard_statusBadge_expiring => 'עומד לפוג';

  @override
  String get certifications_edit_appBar_add => 'הוסף הסמכה';

  @override
  String get certifications_edit_appBar_edit => 'ערוך הסמכה';

  @override
  String get certifications_edit_button_add => 'הוסף הסמכה';

  @override
  String get certifications_edit_button_cancel => 'ביטול';

  @override
  String get certifications_edit_button_save => 'שמור';

  @override
  String get certifications_edit_button_update => 'עדכן הסמכה';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return 'נקה $label';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect => 'הקש לבחירה';

  @override
  String get certifications_edit_dialog_discard => 'מחק';

  @override
  String get certifications_edit_dialog_discardContent =>
      'יש לך שינויים שלא נשמרו. האם אתה בטוח שברצונך לצאת?';

  @override
  String get certifications_edit_dialog_discardTitle => 'למחוק שינויים?';

  @override
  String get certifications_edit_dialog_keepEditing => 'המשך עריכה';

  @override
  String get certifications_edit_help_expiryDate =>
      'השאר ריק להסמכות ללא תפוגה';

  @override
  String get certifications_edit_hint_cardNumber => 'הזן מספר כרטיס הסמכה';

  @override
  String get certifications_edit_hint_certificationName =>
      'לדוגמה, Open Water Diver';

  @override
  String get certifications_edit_hint_instructorName => 'שם המדריך המסמיך';

  @override
  String get certifications_edit_hint_instructorNumber => 'מספר הסמכת המדריך';

  @override
  String get certifications_edit_hint_notes => 'הערות נוספות';

  @override
  String get certifications_edit_label_agency => 'סוכנות *';

  @override
  String get certifications_edit_label_cardNumber => 'מספר כרטיס';

  @override
  String get certifications_edit_label_certificationName => 'שם הסמכה *';

  @override
  String get certifications_edit_label_expiryDate => 'תאריך תפוגה';

  @override
  String get certifications_edit_label_instructorName => 'שם המדריך';

  @override
  String get certifications_edit_label_instructorNumber => 'מספר המדריך';

  @override
  String get certifications_edit_label_issueDate => 'תאריך הנפקה';

  @override
  String get certifications_edit_label_level => 'רמה';

  @override
  String get certifications_edit_label_notes => 'הערות';

  @override
  String get certifications_edit_level_notSpecified => 'לא צוין';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return 'הוסף תמונת $label. הקש לבחירה';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return 'תמונת $label מצורפת. הקש לשינוי';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery => 'בחר מהגלריה';

  @override
  String certifications_edit_photo_removeTooltip(Object label) {
    return 'הסר תמונת $label';
  }

  @override
  String get certifications_edit_photo_takePhoto => 'צלם תמונה';

  @override
  String get certifications_edit_sectionTitle_cardPhotos => 'תמונות כרטיס';

  @override
  String get certifications_edit_sectionTitle_dates => 'תאריכים';

  @override
  String get certifications_edit_sectionTitle_instructorInfo => 'פרטי מדריך';

  @override
  String get certifications_edit_sectionTitle_notes => 'הערות';

  @override
  String get certifications_edit_snackBar_added => 'ההסמכה נוספה בהצלחה';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return 'שגיאה בטעינת הסמכה: $error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return 'שגיאה בבחירת תמונה: $error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return 'שגיאה בשמירת הסמכה: $error';
  }

  @override
  String get certifications_edit_snackBar_updated => 'ההסמכה עודכנה בהצלחה';

  @override
  String get certifications_edit_validation_nameRequired => 'נא להזין שם הסמכה';

  @override
  String get certifications_list_button_retry => 'נסה שוב';

  @override
  String get certifications_list_empty_button => 'הוסף את ההסמכה הראשונה שלך';

  @override
  String get certifications_list_empty_subtitle =>
      'הוסף את הסמכות הצלילה שלך כדי לעקוב\nאחר ההכשרה והכישורים שלך';

  @override
  String get certifications_list_empty_title => 'עדיין לא נוספו הסמכות';

  @override
  String certifications_list_error_loading(Object error) {
    return 'שגיאה בטעינת הסמכות: $error';
  }

  @override
  String get certifications_list_fab_addCertification => 'הוסף הסמכה';

  @override
  String get certifications_list_section_expired => 'פג תוקף';

  @override
  String get certifications_list_section_expiringSoon => 'תוקף פג בקרוב';

  @override
  String get certifications_list_section_valid => 'בתוקף';

  @override
  String get certifications_list_sort_title => 'מיון הסמכות';

  @override
  String get certifications_list_tile_expired => 'פג תוקף';

  @override
  String certifications_list_tile_expiringDays(Object days) {
    return '$daysי';
  }

  @override
  String get certifications_list_tooltip_addCertification => 'הוסף הסמכה';

  @override
  String get certifications_list_tooltip_search => 'חיפוש הסמכות';

  @override
  String get certifications_list_tooltip_sort => 'מיון';

  @override
  String get certifications_list_tooltip_walletView => 'תצוגת ארנק';

  @override
  String get certifications_picker_clearTooltip => 'נקה בחירת הסמכה';

  @override
  String get certifications_picker_empty_addButton => 'הוסף הסמכה';

  @override
  String get certifications_picker_empty_title => 'עדיין אין הסמכות';

  @override
  String certifications_picker_error(Object error) {
    return 'שגיאה בטעינת הסמכות: $error';
  }

  @override
  String get certifications_picker_expired => 'פג תוקף';

  @override
  String get certifications_picker_hint => 'הקש כדי לקשר להסמכה שהושגה';

  @override
  String get certifications_picker_newCert => 'הסמכה חדשה';

  @override
  String get certifications_picker_noSelection => 'לא נבחרה הסמכה';

  @override
  String get certifications_picker_sheetTitle => 'קישור להסמכה';

  @override
  String get certifications_renderer_footer => 'יומן צלילות Submersion';

  @override
  String certifications_renderer_label_cardNumber(Object number) {
    return 'מספר כרטיס: $number';
  }

  @override
  String get certifications_renderer_label_hasCompletedTraining =>
      'השלים/ה הכשרה בתור';

  @override
  String certifications_renderer_label_instructor(Object name) {
    return 'מדריך: $name';
  }

  @override
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  ) {
    return 'מדריך: $name ($number)';
  }

  @override
  String certifications_renderer_label_issued(Object date) {
    return 'הונפק: $date';
  }

  @override
  String get certifications_renderer_label_thisCertifies => 'בזאת מאושר כי';

  @override
  String get certifications_search_empty_hint =>
      'חיפוש לפי שם, ארגון או מספר כרטיס';

  @override
  String get certifications_search_fieldLabel => 'חיפוש הסמכות...';

  @override
  String certifications_search_noResults(Object query) {
    return 'לא נמצאו הסמכות עבור \"$query\"';
  }

  @override
  String get certifications_search_tooltip_back => 'חזרה';

  @override
  String get certifications_search_tooltip_clear => 'נקה חיפוש';

  @override
  String certifications_share_error_card(Object error) {
    return 'שיתוף הכרטיס נכשל: $error';
  }

  @override
  String certifications_share_error_certificate(Object error) {
    return 'שיתוף התעודה נכשל: $error';
  }

  @override
  String get certifications_share_option_card_subtitle =>
      'תמונת הסמכה בסגנון כרטיס אשראי';

  @override
  String get certifications_share_option_card_title => 'שתף ככרטיס';

  @override
  String get certifications_share_option_certificate_subtitle =>
      'מסמך תעודה רשמי';

  @override
  String get certifications_share_option_certificate_title => 'שתף כתעודה';

  @override
  String get certifications_share_title => 'שיתוף הסמכה';

  @override
  String get certifications_summary_header_subtitle =>
      'בחר הסמכה מהרשימה כדי לצפות בפרטים';

  @override
  String get certifications_summary_header_title => 'הסמכות';

  @override
  String get certifications_summary_overview_title => 'סקירה כללית';

  @override
  String get certifications_summary_quickActions_add => 'הוסף הסמכה';

  @override
  String get certifications_summary_quickActions_title => 'פעולות מהירות';

  @override
  String get certifications_summary_recentTitle => 'הסמכות אחרונות';

  @override
  String get certifications_summary_stat_expired => 'פג תוקף';

  @override
  String get certifications_summary_stat_expiringSoon => 'תוקף פג בקרוב';

  @override
  String get certifications_summary_stat_total => 'סה\"כ';

  @override
  String get certifications_summary_stat_valid => 'בתוקף';

  @override
  String certifications_walletCard_countPlural(Object count) {
    return '$count הסמכות';
  }

  @override
  String certifications_walletCard_countSingular(Object count) {
    return 'הסמכה $count';
  }

  @override
  String get certifications_walletCard_emptyFooter =>
      'הוסף את ההסמכה הראשונה שלך';

  @override
  String get certifications_walletCard_error => 'טעינת ההסמכות נכשלה';

  @override
  String get certifications_walletCard_semanticLabel =>
      'ארנק הסמכות. הקש כדי לצפות בכל ההסמכות';

  @override
  String get certifications_walletCard_tapToAdd => 'הקש להוספה';

  @override
  String get certifications_walletCard_title => 'ארנק הסמכות';

  @override
  String get certifications_wallet_appBar_title => 'ארנק הסמכות';

  @override
  String get certifications_wallet_error_retry => 'נסה שוב';

  @override
  String get certifications_wallet_error_title => 'טעינת ההסמכות נכשלה';

  @override
  String get certifications_wallet_options_edit => 'עריכה';

  @override
  String get certifications_wallet_options_share => 'שיתוף';

  @override
  String get certifications_wallet_options_viewDetails => 'צפייה בפרטים';

  @override
  String get certifications_wallet_tooltip_add => 'הוסף הסמכה';

  @override
  String get certifications_wallet_tooltip_share => 'שתף הסמכה';

  @override
  String get common_action_back => 'חזרה';

  @override
  String get common_action_cancel => 'ביטול';

  @override
  String get common_action_close => 'סגירה';

  @override
  String get common_action_delete => 'מחיקה';

  @override
  String get common_action_edit => 'עריכה';

  @override
  String get common_action_ok => 'אישור';

  @override
  String get common_action_save => 'שמירה';

  @override
  String get common_action_search => 'חיפוש';

  @override
  String get common_label_error => 'שגיאה';

  @override
  String get common_label_loading => 'טוען';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get courses_action_add => 'הוסף קורס';

  @override
  String get courses_action_create => 'צור קורס';

  @override
  String get courses_action_edit => 'ערוך קורס';

  @override
  String get courses_action_exportTrainingLog => 'ייצא יומן אימונים';

  @override
  String get courses_action_markCompleted => 'סמן כהושלם';

  @override
  String get courses_action_moreOptions => 'אפשרויות נוספות';

  @override
  String get courses_action_retry => 'נסה שוב';

  @override
  String get courses_action_saveChanges => 'שמור שינויים';

  @override
  String get courses_action_saveSemantic => 'שמור קורס';

  @override
  String get courses_action_sort => 'מיין';

  @override
  String get courses_action_sortTitle => 'מיין קורסים';

  @override
  String courses_card_instructor(Object name) {
    return 'מדריך: $name';
  }

  @override
  String courses_card_started(Object date) {
    return 'התחיל ב-$date';
  }

  @override
  String get courses_detail_certificationNotFound => 'הסמכה לא נמצאה';

  @override
  String get courses_detail_noTrainingDives => 'עדיין אין צלילות אימון מקושרות';

  @override
  String get courses_detail_notFound => 'קורס לא נמצא';

  @override
  String get courses_dialog_complete => 'השלם';

  @override
  String courses_dialog_deleteMessage(Object name) {
    return 'האם אתה בטוח שברצונך למחוק את $name? פעולה זו אינה ניתנת לביטול.';
  }

  @override
  String get courses_dialog_deleteTitle => 'למחוק קורס?';

  @override
  String get courses_dialog_markCompletedMessage =>
      'פעולה זו תסמן את הקורס כהושלם עם תאריך היום. להמשיך?';

  @override
  String get courses_dialog_markCompletedTitle => 'לסמן כהושלם?';

  @override
  String get courses_empty_noCompleted => 'אין קורסים שהושלמו';

  @override
  String get courses_empty_noInProgress => 'אין קורסים בתהליך';

  @override
  String get courses_empty_subtitle => 'הוסף את הקורס הראשון שלך כדי להתחיל';

  @override
  String get courses_empty_title => 'עדיין אין קורסי אימון';

  @override
  String courses_error_generic(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get courses_error_loadingCertification => 'שגיאה בטעינת הסמכה';

  @override
  String get courses_error_loadingDives => 'שגיאה בטעינת צלילות';

  @override
  String get courses_field_courseName => 'שם הקורס';

  @override
  String get courses_field_courseNameHint => 'לדוגמה: צולל מים פתוחים';

  @override
  String get courses_field_instructorName => 'שם המדריך';

  @override
  String get courses_field_instructorNumber => 'מספר מדריך';

  @override
  String get courses_field_linkCertificationHint => 'קשר הסמכה שהושגה מקורס זה';

  @override
  String get courses_field_location => 'מיקום';

  @override
  String get courses_field_notes => 'הערות';

  @override
  String get courses_field_selectFromBuddies => 'בחר מחברי צוללים (אופציונלי)';

  @override
  String get courses_filter_all => 'הכל';

  @override
  String get courses_label_agency => 'גוף הסמכה';

  @override
  String get courses_label_completed => 'הושלם';

  @override
  String get courses_label_completionDate => 'תאריך השלמה';

  @override
  String get courses_label_courseInProgress => 'הקורס בתהליך';

  @override
  String get courses_label_instructorNumber => 'מדריך מס\'';

  @override
  String get courses_label_location => 'מיקום';

  @override
  String get courses_label_name => 'שם';

  @override
  String get courses_label_none => '-- ללא --';

  @override
  String get courses_label_startDate => 'תאריך התחלה';

  @override
  String courses_message_errorSaving(Object error) {
    return 'שגיאה בשמירת קורס: $error';
  }

  @override
  String courses_message_exportFailed(Object error) {
    return 'נכשל בייצוא יומן אימונים: $error';
  }

  @override
  String get courses_picker_active => 'פעיל';

  @override
  String get courses_picker_clearSelection => 'נקה בחירה';

  @override
  String get courses_picker_createCourse => 'צור קורס';

  @override
  String courses_picker_errorLoading(Object error) {
    return 'שגיאה בטעינת קורסים: $error';
  }

  @override
  String get courses_picker_newCourse => 'קורס חדש';

  @override
  String get courses_picker_noCourses => 'עדיין אין קורסים';

  @override
  String get courses_picker_noneSelected => 'לא נבחר קורס';

  @override
  String get courses_picker_selectTitle => 'בחר קורס אימון';

  @override
  String get courses_picker_selected => 'נבחר';

  @override
  String get courses_picker_tapToLink => 'לחץ כדי לקשר לקורס אימון';

  @override
  String get courses_section_details => 'פרטי הקורס';

  @override
  String get courses_section_earnedCertification => 'הסמכה שהושגה';

  @override
  String get courses_section_instructor => 'מדריך';

  @override
  String get courses_section_notes => 'הערות';

  @override
  String get courses_section_trainingDives => 'צלילות אימון';

  @override
  String get courses_status_completed => 'הושלם';

  @override
  String courses_status_daysSinceStart(Object days) {
    return '$days ימים מאז ההתחלה';
  }

  @override
  String courses_status_durationDays(Object days) {
    return '$days ימים';
  }

  @override
  String get courses_status_inProgress => 'בתהליך';

  @override
  String courses_status_semanticLabel(Object status, Object duration) {
    return '$status, $duration';
  }

  @override
  String get courses_summary_overview => 'סקירה כללית';

  @override
  String get courses_summary_quickActions => 'פעולות מהירות';

  @override
  String get courses_summary_recentCourses => 'קורסים אחרונים';

  @override
  String get courses_summary_selectHint => 'בחר קורס מהרשימה כדי להציג פרטים';

  @override
  String get courses_summary_title => 'קורסי אימון';

  @override
  String get courses_summary_total => 'סה\"כ';

  @override
  String get courses_title => 'קורסי אימון';

  @override
  String get courses_title_edit => 'ערוך קורס';

  @override
  String get courses_title_new => 'קורס חדש';

  @override
  String get courses_title_singular => 'קורס';

  @override
  String get courses_validation_nameRequired => 'נא להזין שם קורס';

  @override
  String get dashboard_activity_daySinceDiving => 'יום מאז הצלילה האחרונה';

  @override
  String get dashboard_activity_daysSinceDiving => 'ימים מאז הצלילה האחרונה';

  @override
  String dashboard_activity_diveInYear(Object year) {
    return 'צלילה ב-$year';
  }

  @override
  String get dashboard_activity_diveThisMonth => 'צלילה החודש';

  @override
  String dashboard_activity_divesInYear(Object year) {
    return 'צלילות ב-$year';
  }

  @override
  String get dashboard_activity_divesThisMonth => 'צלילות החודש';

  @override
  String get dashboard_activity_error => 'שגיאה';

  @override
  String get dashboard_activity_lastDive => 'צלילה אחרונה';

  @override
  String get dashboard_activity_loading => 'טוען';

  @override
  String get dashboard_activity_noDivesYet => 'אין צלילות עדיין';

  @override
  String get dashboard_activity_today => 'היום!';

  @override
  String get dashboard_alerts_actionUpdate => 'עדכון';

  @override
  String get dashboard_alerts_actionView => 'הצגה';

  @override
  String get dashboard_alerts_checkInsuranceExpiry =>
      'בדוק את תאריך תפוגת הביטוח';

  @override
  String get dashboard_alerts_daysOverdueOne => 'יום אחד באיחור';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return '$count ימים באיחור';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => 'נותר יום אחד';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return 'נותרו $count ימים';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return 'טיפול נדרש ל-$name';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return 'טיפול באיחור ל-$name';
  }

  @override
  String get dashboard_alerts_insuranceExpired => 'הביטוח פג תוקף';

  @override
  String get dashboard_alerts_insuranceExpiredGeneric =>
      'ביטוח הצלילה שלך פג תוקף';

  @override
  String dashboard_alerts_insuranceExpiredProvider(Object provider) {
    return '$provider פג תוקף';
  }

  @override
  String dashboard_alerts_insuranceExpiresDate(Object date) {
    return 'פג תוקף ב-$date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon => 'הביטוח עומד לפוג בקרוב';

  @override
  String get dashboard_alerts_sectionTitle => 'התראות ותזכורות';

  @override
  String get dashboard_alerts_serviceDueToday => 'טיפול נדרש היום';

  @override
  String get dashboard_alerts_serviceIntervalReached => 'מרווח הטיפול הושג';

  @override
  String get dashboard_defaultDiverName => 'צולל';

  @override
  String get dashboard_greeting_afternoon => 'צהריים טובים';

  @override
  String get dashboard_greeting_evening => 'ערב טוב';

  @override
  String get dashboard_greeting_morning => 'בוקר טוב';

  @override
  String dashboard_greeting_withName(Object greeting, Object name) {
    return '$greeting, $name!';
  }

  @override
  String dashboard_greeting_withoutName(Object greeting) {
    return '$greeting!';
  }

  @override
  String get dashboard_hero_divesLoggedOne => 'צלילה אחת רשומה';

  @override
  String dashboard_hero_divesLoggedOther(Object count) {
    return '$count צלילות רשומות';
  }

  @override
  String get dashboard_hero_error => 'מוכן לחקור את המעמקים?';

  @override
  String dashboard_hero_hoursUnderwater(Object hours) {
    return '$hours שעות מתחת למים';
  }

  @override
  String get dashboard_hero_loading => 'טוען את נתוני הצלילה שלך...';

  @override
  String dashboard_hero_minutesUnderwater(Object minutes) {
    return '$minutes דקות מתחת למים';
  }

  @override
  String get dashboard_hero_noDives => 'מוכן לרשום את הצלילה הראשונה?';

  @override
  String get dashboard_personalRecords_coldest => 'הקרה ביותר';

  @override
  String get dashboard_personalRecords_deepest => 'העמוקה ביותר';

  @override
  String get dashboard_personalRecords_longest => 'הארוכה ביותר';

  @override
  String get dashboard_personalRecords_sectionTitle => 'שיאים אישיים';

  @override
  String get dashboard_personalRecords_warmest => 'החמה ביותר';

  @override
  String get dashboard_quickActions_addSite => 'הוספת אתר';

  @override
  String get dashboard_quickActions_addSiteTooltip => 'הוספת אתר צלילה חדש';

  @override
  String get dashboard_quickActions_logDive => 'רישום צלילה';

  @override
  String get dashboard_quickActions_logDiveTooltip => 'רישום צלילה חדשה';

  @override
  String get dashboard_quickActions_planDive => 'תכנון צלילה';

  @override
  String get dashboard_quickActions_planDiveTooltip => 'תכנון צלילה חדשה';

  @override
  String get dashboard_quickActions_sectionTitle => 'פעולות מהירות';

  @override
  String get dashboard_quickActions_statistics => 'סטטיסטיקות';

  @override
  String get dashboard_quickActions_statisticsTooltip =>
      'הצגת סטטיסטיקות צלילה';

  @override
  String get dashboard_quickStats_countries => 'מדינות';

  @override
  String get dashboard_quickStats_countriesSubtitle => 'שבוקרו';

  @override
  String get dashboard_quickStats_sectionTitle => 'במבט חטוף';

  @override
  String get dashboard_quickStats_species => 'מינים';

  @override
  String get dashboard_quickStats_speciesSubtitle => 'שהתגלו';

  @override
  String get dashboard_quickStats_topBuddy => 'שותף מוביל';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count צלילות';
  }

  @override
  String get dashboard_recentDives_empty => 'אין צלילות רשומות עדיין';

  @override
  String get dashboard_recentDives_errorLoading => 'נכשל טעינת צלילות';

  @override
  String get dashboard_recentDives_logFirst => 'רשום את הצלילה הראשונה';

  @override
  String get dashboard_recentDives_sectionTitle => 'צלילות אחרונות';

  @override
  String get dashboard_recentDives_viewAll => 'הצג הכל';

  @override
  String get dashboard_recentDives_viewAllTooltip => 'הצגת כל הצלילות';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count התראות פעילות';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives =>
      'שגיאה: נכשל טעינת צלילות אחרונות';

  @override
  String get dashboard_semantics_errorLoadingStatistics =>
      'שגיאה: נכשל טעינת סטטיסטיקות';

  @override
  String get dashboard_semantics_greetingBanner => 'באנר ברכה בלוח המחוונים';

  @override
  String get dashboard_stats_errorLoadingStatistics => 'נכשל טעינת סטטיסטיקות';

  @override
  String get dashboard_stats_hoursLogged => 'שעות רשומות';

  @override
  String get dashboard_stats_maxDepth => 'עומק מרבי';

  @override
  String get dashboard_stats_sitesVisited => 'אתרים שבוקרו';

  @override
  String get dashboard_stats_totalDives => 'סה\"כ צלילות';

  @override
  String get decoCalculator_addToPlanner => 'הוסף למתכנן';

  @override
  String decoCalculator_bottomTimeSemantics(Object time) {
    return 'זמן תחתית: $time דקות';
  }

  @override
  String get decoCalculator_createPlanTooltip =>
      'צור תכנית צלילה מהפרמטרים הנוכחיים';

  @override
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  ) {
    return 'נוצרה תכנית: $depth$depthSymbol למשך $time דקות על $gasMixName';
  }

  @override
  String get decoCalculator_customMixTrimix => 'תערובת מותאמת (טרימיקס)';

  @override
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol) {
    return 'עומק: $depth $depthSymbol';
  }

  @override
  String get decoCalculator_diveParameters => 'פרמטרי צלילה';

  @override
  String get decoCalculator_endCaution => 'זהירות';

  @override
  String get decoCalculator_endDanger => 'סכנה';

  @override
  String get decoCalculator_endSafe => 'בטוח';

  @override
  String get decoCalculator_field_bottomTime => 'זמן תחתית';

  @override
  String get decoCalculator_field_depth => 'עומק';

  @override
  String get decoCalculator_field_gasMix => 'תערובת גז';

  @override
  String get decoCalculator_gasSafety => 'בטיחות גז';

  @override
  String get decoCalculator_hideCustomMix => 'הסתר תערובת מותאמת';

  @override
  String get decoCalculator_hideCustomMixSemantics =>
      'הסתר בורר תערובת גז מותאמת';

  @override
  String get decoCalculator_modExceeded => 'MOD חרג';

  @override
  String get decoCalculator_modSafe => 'MOD בטוח';

  @override
  String get decoCalculator_ppO2Caution => 'ppO2 זהירות';

  @override
  String get decoCalculator_ppO2Danger => 'ppO2 סכנה';

  @override
  String get decoCalculator_ppO2Hypoxic => 'ppO2 היפוקסי';

  @override
  String get decoCalculator_ppO2Safe => 'ppO2 בטוח';

  @override
  String get decoCalculator_resetToDefaults => 'אפס לברירת מחדל';

  @override
  String get decoCalculator_showCustomMixSemantics =>
      'הצג בורר תערובת גז מותאמת';

  @override
  String decoCalculator_timeValueMin(Object time) {
    return '$time דקות';
  }

  @override
  String get decoCalculator_title => 'מחשבון דקומפרסיה';

  @override
  String diveCenters_accessibility_markerLabel(Object name) {
    return 'מרכז צלילה: $name';
  }

  @override
  String get diveCenters_accessibility_selected => 'נבחר';

  @override
  String diveCenters_accessibility_viewDetails(Object name) {
    return 'הצג פרטים עבור $name';
  }

  @override
  String get diveCenters_accessibility_viewDives => 'הצג צלילות עם מרכז זה';

  @override
  String get diveCenters_accessibility_viewFullscreenMap => 'הצג מפה במסך מלא';

  @override
  String diveCenters_accessibility_viewSavedCenter(Object name) {
    return 'הצג מרכז צלילה שמור $name';
  }

  @override
  String get diveCenters_action_addCenter => 'הוסף מרכז';

  @override
  String get diveCenters_action_addNew => 'הוסף חדש';

  @override
  String get diveCenters_action_clearRating => 'נקה';

  @override
  String get diveCenters_action_gettingLocation => 'מאתר...';

  @override
  String get diveCenters_action_import => 'ייבא';

  @override
  String get diveCenters_action_importToMyCenters => 'ייבא למרכזים שלי';

  @override
  String get diveCenters_action_lookingUp => 'מחפש...';

  @override
  String get diveCenters_action_lookupFromAddress => 'חפש מכתובת';

  @override
  String get diveCenters_action_pickFromMap => 'בחר ממפה';

  @override
  String get diveCenters_action_retry => 'נסה שוב';

  @override
  String get diveCenters_action_settings => 'הגדרות';

  @override
  String get diveCenters_action_useMyLocation => 'השתמש במיקום שלי';

  @override
  String get diveCenters_action_view => 'הצג';

  @override
  String diveCenters_detail_divesLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות נרשמו',
      one: 'צלילה אחת נרשמה',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_detail_divesWithCenter => 'צלילות עם מרכז זה';

  @override
  String get diveCenters_detail_noDivesLogged => 'עדיין לא נרשמו צלילות';

  @override
  String diveCenters_dialog_deleteMessage(Object name) {
    return 'האם אתה בטוח שברצונך למחוק את \"$name\"?';
  }

  @override
  String get diveCenters_dialog_deleteTitle => 'למחוק מרכז צלילה';

  @override
  String get diveCenters_dialog_discard => 'בטל';

  @override
  String get diveCenters_dialog_discardMessage =>
      'יש לך שינויים שלא נשמרו. האם אתה בטוח שברצונך לבטל אותם?';

  @override
  String get diveCenters_dialog_discardTitle => 'לבטל שינויים?';

  @override
  String get diveCenters_dialog_keepEditing => 'המשך עריכה';

  @override
  String get diveCenters_empty_subtitle =>
      'הוסף את חנויות הצלילה והמפעילים המועדפים עליך';

  @override
  String get diveCenters_empty_title => 'עדיין אין מרכזי צלילה';

  @override
  String diveCenters_error_generic(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get diveCenters_error_geocodeFailed =>
      'לא ניתן למצוא קואורדינטות עבור כתובת זו';

  @override
  String get diveCenters_error_importFailed => 'נכשל בייבוא מרכז צלילה';

  @override
  String diveCenters_error_loading(Object error) {
    return 'שגיאה בטעינת מרכזי צלילה: $error';
  }

  @override
  String get diveCenters_error_locationPermission =>
      'לא ניתן לקבל מיקום. נא לבדוק הרשאות.';

  @override
  String get diveCenters_error_locationUnavailable =>
      'לא ניתן לקבל מיקום. שירותי מיקום עשויים להיות לא זמינים.';

  @override
  String get diveCenters_error_noAddressForLookup =>
      'נא להזין כתובת כדי לחפש קואורדינטות';

  @override
  String get diveCenters_error_notFound => 'מרכז צלילה לא נמצא';

  @override
  String diveCenters_error_saving(Object error) {
    return 'שגיאה בשמירת מרכז צלילה: $error';
  }

  @override
  String get diveCenters_error_unknown => 'שגיאה לא ידועה';

  @override
  String get diveCenters_field_city => 'עיר';

  @override
  String get diveCenters_field_country => 'מדינה';

  @override
  String get diveCenters_field_latitude => 'קו רוחב';

  @override
  String get diveCenters_field_longitude => 'קו אורך';

  @override
  String get diveCenters_field_nameRequired => 'שם *';

  @override
  String get diveCenters_field_postalCode => 'מיקוד';

  @override
  String get diveCenters_field_rating => 'דירוג';

  @override
  String get diveCenters_field_stateProvince => 'מדינה/מחוז';

  @override
  String get diveCenters_field_street => 'כתובת רחוב';

  @override
  String get diveCenters_hint_addressDescription =>
      'כתובת רחוב אופציונלית לניווט';

  @override
  String get diveCenters_hint_affiliationsDescription =>
      'בחר גופי הכשרה שהמרכז מזוהה איתם';

  @override
  String get diveCenters_hint_city => 'לדוגמה: פוקט';

  @override
  String get diveCenters_hint_country => 'לדוגמה: תאילנד';

  @override
  String get diveCenters_hint_email => 'info@divecenter.com';

  @override
  String get diveCenters_hint_gpsDescription =>
      'בחר שיטת מיקום או הזן קואורדינטות ידנית';

  @override
  String get diveCenters_hint_importSearch =>
      'חפש מרכזי צלילה (לדוגמה: \"PADI\", \"תאילנד\")';

  @override
  String get diveCenters_hint_latitude => 'לדוגמה: 10.4613';

  @override
  String get diveCenters_hint_longitude => 'לדוגמה: 99.8359';

  @override
  String get diveCenters_hint_name => 'הזן שם מרכז צלילה';

  @override
  String get diveCenters_hint_notes => 'כל מידע נוסף...';

  @override
  String get diveCenters_hint_phone => '+972-50-123-4567';

  @override
  String get diveCenters_hint_postalCode => 'לדוגמה: 83100';

  @override
  String get diveCenters_hint_stateProvince => 'לדוגמה: פוקט';

  @override
  String get diveCenters_hint_street => 'לדוגמה: דרך החוף 123';

  @override
  String get diveCenters_hint_website => 'www.divecenter.com';

  @override
  String diveCenters_import_fromDatabase(Object count) {
    return 'ייבא ממאגר נתונים ($count)';
  }

  @override
  String diveCenters_import_myCenters(Object count) {
    return 'המרכזים שלי ($count)';
  }

  @override
  String get diveCenters_import_noResults => 'אין תוצאות';

  @override
  String diveCenters_import_noResultsMessage(Object query) {
    return 'לא נמצאו מרכזי צלילה עבור \"$query\". נסה מונח חיפוש אחר.';
  }

  @override
  String get diveCenters_import_searchDescription =>
      'חפש מרכזי צלילה, חנויות ומועדונים ממאגר הנתונים שלנו של מפעילים ברחבי העולם.';

  @override
  String get diveCenters_import_searchError => 'שגיאת חיפוש';

  @override
  String get diveCenters_import_searchHint =>
      'נסה לחפש לפי שם, מדינה או גוף הסמכה.';

  @override
  String get diveCenters_import_searchTitle => 'חפש מרכזי צלילה';

  @override
  String get diveCenters_label_alreadyImported => 'כבר יובא';

  @override
  String diveCenters_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות',
      one: 'צלילה אחת',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_label_email => 'דוא\"ל';

  @override
  String get diveCenters_label_imported => 'יובא';

  @override
  String get diveCenters_label_locationNotSet => 'מיקום לא הוגדר';

  @override
  String get diveCenters_label_locationUnknown => 'מיקום לא ידוע';

  @override
  String get diveCenters_label_phone => 'טלפון';

  @override
  String get diveCenters_label_saved => 'נשמר';

  @override
  String diveCenters_label_source(Object source) {
    return 'מקור: $source';
  }

  @override
  String get diveCenters_label_website => 'אתר אינטרנט';

  @override
  String get diveCenters_map_addCoordinatesHint =>
      'הוסף קואורדינטות למרכזי הצלילה שלך כדי לראות אותם במפה';

  @override
  String get diveCenters_map_noCoordinates => 'אין מרכזי צלילה עם קואורדינטות';

  @override
  String get diveCenters_picker_newCenter => 'מרכז צלילה חדש';

  @override
  String get diveCenters_picker_title => 'בחר מרכז צלילה';

  @override
  String diveCenters_search_noResults(Object query) {
    return 'אין תוצאות עבור \"$query\"';
  }

  @override
  String get diveCenters_search_prompt => 'חפש מרכזי צלילה';

  @override
  String get diveCenters_section_address => 'כתובת';

  @override
  String get diveCenters_section_affiliations => 'השתייכויות';

  @override
  String get diveCenters_section_basicInfo => 'מידע בסיסי';

  @override
  String get diveCenters_section_contact => 'יצירת קשר';

  @override
  String get diveCenters_section_contactInfo => 'פרטי קשר';

  @override
  String get diveCenters_section_gpsCoordinates => 'קואורדינטות GPS';

  @override
  String get diveCenters_section_notes => 'הערות';

  @override
  String get diveCenters_snackbar_coordinatesFound =>
      'קואורדינטות נמצאו מהכתובת';

  @override
  String get diveCenters_snackbar_copiedToClipboard => 'הועתק ללוח';

  @override
  String diveCenters_snackbar_imported(Object name) {
    return 'יובא \"$name\"';
  }

  @override
  String get diveCenters_snackbar_locationCaptured => 'מיקום נקלט';

  @override
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'מיקום נקלט (±$accuracyמ\')';
  }

  @override
  String get diveCenters_snackbar_locationSelectedFromMap => 'מיקום נבחר מהמפה';

  @override
  String get diveCenters_sort_title => 'מיין מרכזי צלילה';

  @override
  String get diveCenters_summary_countries => 'מדינות';

  @override
  String get diveCenters_summary_highestRating => 'דירוג הגבוה ביותר';

  @override
  String get diveCenters_summary_overview => 'סקירה כללית';

  @override
  String get diveCenters_summary_quickActions => 'פעולות מהירות';

  @override
  String get diveCenters_summary_recentCenters => 'מרכזי צלילה אחרונים';

  @override
  String get diveCenters_summary_selectPrompt =>
      'בחר מרכז צלילה מהרשימה כדי להציג פרטים';

  @override
  String get diveCenters_summary_topRated => 'מדורג ביותר';

  @override
  String get diveCenters_summary_totalCenters => 'סה\"כ מרכזים';

  @override
  String get diveCenters_summary_withGps => 'עם GPS';

  @override
  String get diveCenters_title => 'מרכזי צלילה';

  @override
  String get diveCenters_title_add => 'הוסף מרכז צלילה';

  @override
  String get diveCenters_title_edit => 'ערוך מרכז צלילה';

  @override
  String get diveCenters_title_import => 'ייבא מרכז צלילה';

  @override
  String get diveCenters_tooltip_addNew => 'הוסף מרכז צלילה חדש';

  @override
  String get diveCenters_tooltip_clearSearch => 'נקה חיפוש';

  @override
  String get diveCenters_tooltip_edit => 'ערוך מרכז צלילה';

  @override
  String get diveCenters_tooltip_fitAllCenters => 'התאם כל המרכזים';

  @override
  String get diveCenters_tooltip_listView => 'תצוגת רשימה';

  @override
  String get diveCenters_tooltip_mapView => 'תצוגת מפה';

  @override
  String get diveCenters_tooltip_moreOptions => 'אפשרויות נוספות';

  @override
  String get diveCenters_tooltip_search => 'חפש מרכזי צלילה';

  @override
  String get diveCenters_tooltip_sort => 'מיין';

  @override
  String get diveCenters_validation_invalidEmail =>
      'נא להזין כתובת דוא\"ל תקינה';

  @override
  String get diveCenters_validation_invalidLatitude => 'קו רוחב לא תקין';

  @override
  String get diveCenters_validation_invalidLongitude => 'קו אורך לא תקין';

  @override
  String get diveCenters_validation_nameRequired => 'שם נדרש';

  @override
  String get diveComputer_action_setFavorite => 'הגדר כמועדף';

  @override
  String diveComputer_error_generic(Object error) {
    return 'אירעה שגיאה: $error';
  }

  @override
  String get diveComputer_error_notFound => 'מכשיר לא נמצא';

  @override
  String get diveComputer_status_favorite => 'מחשב צלילה מועדף';

  @override
  String get diveComputer_title => 'מחשב צלילה';

  @override
  String diveLog_bulkDelete_confirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צלילות',
      one: 'צלילה',
    );
    return 'האם אתה בטוח שברצונך למחוק $count $_temp0? פעולה זו אינה ניתנת לביטול.';
  }

  @override
  String get diveLog_bulkDelete_restored => 'הצלילות שוחזרו';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צלילות נמחקו',
      one: 'צלילה נמחקה',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_bulkDelete_title => 'מחיקת צלילות';

  @override
  String get diveLog_bulkDelete_undo => 'ביטול';

  @override
  String get diveLog_bulkEdit_addTags => 'הוספת תגיות';

  @override
  String get diveLog_bulkEdit_addTagsDescription =>
      'הוספת תגיות לצלילות שנבחרו';

  @override
  String diveLog_bulkEdit_addedTags(int tagCount, int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: 'תגיות',
      one: 'תגית',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'צלילות',
      one: 'צלילה',
    );
    return 'נוספו $tagCount $_temp0 ל-$diveCount $_temp1';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => 'שינוי טיול';

  @override
  String get diveLog_bulkEdit_changeTripDescription =>
      'העברת צלילות שנבחרו לטיול';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips => 'שגיאה בטעינת טיולים';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return 'נכשל הוספת תגיות: $error';
  }

  @override
  String diveLog_bulkEdit_failedUpdateTrip(Object error) {
    return 'נכשל עדכון טיול: $error';
  }

  @override
  String diveLog_bulkEdit_movedToTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צלילות הועברו',
      one: 'צלילה הועברה',
    );
    return '$count $_temp0 לטיול';
  }

  @override
  String get diveLog_bulkEdit_noTagsAvailable => 'אין תגיות זמינות.';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate =>
      'אין תגיות זמינות. צור תגיות תחילה.';

  @override
  String get diveLog_bulkEdit_noTrip => 'ללא טיול';

  @override
  String get diveLog_bulkEdit_removeFromTrip => 'הסרה מטיול';

  @override
  String get diveLog_bulkEdit_removeTags => 'הסרת תגיות';

  @override
  String get diveLog_bulkEdit_removeTagsDescription =>
      'הסרת תגיות מצלילות שנבחרו';

  @override
  String diveLog_bulkEdit_removedFromTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צלילות הוסרו',
      one: 'צלילה הוסרה',
    );
    return '$count $_temp0 מהטיול';
  }

  @override
  String get diveLog_bulkEdit_selectTrip => 'בחירת טיול';

  @override
  String diveLog_bulkEdit_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צלילות',
      one: 'צלילה',
    );
    return 'עריכת $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_csv => 'CSV';

  @override
  String get diveLog_bulkExport_csvDescription => 'פורמט גיליון אלקטרוני';

  @override
  String diveLog_bulkExport_failed(Object error) {
    return 'הייצוא נכשל: $error';
  }

  @override
  String get diveLog_bulkExport_pdf => 'יומן PDF';

  @override
  String get diveLog_bulkExport_pdfDescription => 'דפי יומן צלילה להדפסה';

  @override
  String diveLog_bulkExport_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צלילות יוצאו',
      one: 'צלילה יוצאה',
    );
    return '$count $_temp0 בהצלחה';
  }

  @override
  String diveLog_bulkExport_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צלילות',
      one: 'צלילה',
    );
    return 'ייצוא $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_uddf => 'UDDF';

  @override
  String get diveLog_bulkExport_uddfDescription =>
      'פורמט נתוני צלילה אוניברסלי';

  @override
  String get diveLog_ccr_diluent_air => 'אוויר';

  @override
  String get diveLog_ccr_hint_loopVolume => 'למשל, 6.0';

  @override
  String get diveLog_ccr_hint_type => 'למשל, Sofnolime';

  @override
  String get diveLog_ccr_label_deco => 'דקו';

  @override
  String get diveLog_ccr_label_he => 'He';

  @override
  String get diveLog_ccr_label_highBottom => 'גבוה (תחתית)';

  @override
  String get diveLog_ccr_label_loopVolume => 'נפח מעגל';

  @override
  String get diveLog_ccr_label_lowDescAsc => 'נמוך (ירידה/עלייה)';

  @override
  String get diveLog_ccr_label_n2 => 'N₂';

  @override
  String get diveLog_ccr_label_o2 => 'O₂';

  @override
  String get diveLog_ccr_label_rated => 'נומינלי';

  @override
  String get diveLog_ccr_label_remaining => 'נותר';

  @override
  String get diveLog_ccr_label_type => 'סוג';

  @override
  String get diveLog_ccr_sectionDiluentGas => 'גז מדלל';

  @override
  String get diveLog_ccr_sectionScrubber => 'סקראבר';

  @override
  String get diveLog_ccr_sectionSetpoints => 'נקודות כוונון (bar)';

  @override
  String get diveLog_ccr_title => 'הגדרות CCR';

  @override
  String diveLog_collapsible_semantics_collapse(Object title) {
    return 'כיווץ חלק $title';
  }

  @override
  String diveLog_collapsible_semantics_expand(Object title) {
    return 'הרחבת חלק $title';
  }

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return 'ממוצע: $depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => 'בסיסי';

  @override
  String get diveLog_cylinderSac_noSac => 'SAC: --';

  @override
  String get diveLog_cylinderSac_tooltip_aiData =>
      'שימוש בנתוני משדר AI לדיוק גבוה יותר';

  @override
  String get diveLog_cylinderSac_tooltip_basicData => 'חושב מלחצי התחלה/סיום';

  @override
  String get diveLog_deco_badge_deco => 'דקו';

  @override
  String get diveLog_deco_badge_noDeco => 'ללא דקו';

  @override
  String get diveLog_deco_label_ceiling => 'תקרה';

  @override
  String get diveLog_deco_label_leading => 'מוביל';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String get diveLog_deco_sectionDecoStops => 'עצירות דקו';

  @override
  String get diveLog_deco_sectionTissueLoading => 'עומס רקמות';

  @override
  String get diveLog_deco_semantics_notRequired => 'דקומפרסיה אינה נדרשת';

  @override
  String get diveLog_deco_semantics_required => 'דקומפרסיה נדרשת';

  @override
  String get diveLog_deco_tissueFast => 'מהירה';

  @override
  String get diveLog_deco_tissueSlow => 'איטית';

  @override
  String get diveLog_deco_title => 'מצב דקומפרסיה';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return 'סה\"כ: $time';
  }

  @override
  String get diveLog_delete_cancel => 'ביטול';

  @override
  String get diveLog_delete_confirm =>
      'פעולה זו אינה ניתנת לביטול. הצלילה וכל הנתונים המשויכים (פרופיל, בלונים, תצפיות) יימחקו לצמיתות.';

  @override
  String get diveLog_delete_delete => 'מחיקה';

  @override
  String get diveLog_delete_title => 'למחוק צלילה?';

  @override
  String get diveLog_detail_appBar => 'פרטי צלילה';

  @override
  String get diveLog_detail_badge_critical => 'קריטי';

  @override
  String get diveLog_detail_badge_deco => 'דקו';

  @override
  String get diveLog_detail_badge_noDeco => 'ללא דקו';

  @override
  String get diveLog_detail_badge_warning => 'אזהרה';

  @override
  String diveLog_detail_buddyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'שותפים',
      one: 'שותף',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_button_playback => 'הפעלה';

  @override
  String get diveLog_detail_button_rangeAnalysis => 'ניתוח טווח';

  @override
  String get diveLog_detail_button_showEnd => 'הצגת סיום';

  @override
  String get diveLog_detail_captureSignature => 'קליטת חתימת מדריך';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return 'ב-$timestamp';
  }

  @override
  String diveLog_detail_collapsed_atTimeInfo(
    Object timestamp,
    Object baseInfo,
  ) {
    return 'ב-$timestamp • $baseInfo';
  }

  @override
  String diveLog_detail_collapsed_ceiling(Object value) {
    return 'תקרה: $value';
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
    return 'CNS: $cns • Max ppO₂: $maxPpO2 • ב-$timestamp: $ppO2 בר';
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
      other: 'פריטים',
      one: 'פריט',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_errorLoading => 'שגיאה בטעינת צלילה';

  @override
  String get diveLog_detail_fullscreen_sampleData => 'נתוני דגימה';

  @override
  String get diveLog_detail_fullscreen_tapChartCompact =>
      'לחץ על התרשים לתצוגה קומפקטית';

  @override
  String get diveLog_detail_fullscreen_tapChartFull =>
      'לחץ על התרשים לתצוגה במסך מלא';

  @override
  String get diveLog_detail_fullscreen_touchChart =>
      'גע בתרשים כדי לראות נתונים באותה נקודה';

  @override
  String get diveLog_detail_label_airTemp => 'טמפ\' אוויר';

  @override
  String get diveLog_detail_label_avgDepth => 'עומק ממוצע';

  @override
  String get diveLog_detail_label_buddy => 'שותף';

  @override
  String get diveLog_detail_label_currentDirection => 'כיוון זרם';

  @override
  String get diveLog_detail_label_currentStrength => 'עוצמת זרם';

  @override
  String get diveLog_detail_label_diveComputer => 'מחשב צלילה';

  @override
  String get diveLog_detail_label_diveMaster => 'דייבמאסטר';

  @override
  String get diveLog_detail_label_diveType => 'סוג צלילה';

  @override
  String get diveLog_detail_label_elevation => 'גובה';

  @override
  String get diveLog_detail_label_entry => 'כניסה:';

  @override
  String get diveLog_detail_label_entryMethod => 'שיטת כניסה';

  @override
  String get diveLog_detail_label_exit => 'יציאה:';

  @override
  String get diveLog_detail_label_exitMethod => 'שיטת יציאה';

  @override
  String get diveLog_detail_label_gradientFactors => 'מקדמי שיפוע';

  @override
  String get diveLog_detail_label_height => 'גובה';

  @override
  String get diveLog_detail_label_highTide => 'גאות';

  @override
  String get diveLog_detail_label_lowTide => 'שפל';

  @override
  String get diveLog_detail_label_ppO2AtPoint => 'ppO₂ בנקודה הנבחרת:';

  @override
  String get diveLog_detail_label_rateOfChange => 'קצב שינוי';

  @override
  String get diveLog_detail_label_sacRate => 'קצב SAC';

  @override
  String get diveLog_detail_label_state => 'מצב';

  @override
  String get diveLog_detail_label_surfaceInterval => 'מרווח פני שטח';

  @override
  String get diveLog_detail_label_surfacePressure => 'לחץ פני שטח';

  @override
  String get diveLog_detail_label_swellHeight => 'גובה גלים';

  @override
  String get diveLog_detail_label_total => 'סה\"כ:';

  @override
  String get diveLog_detail_label_visibility => 'ראות';

  @override
  String get diveLog_detail_label_waterType => 'סוג מים';

  @override
  String get diveLog_detail_menu_delete => 'מחיקה';

  @override
  String get diveLog_detail_menu_export => 'ייצוא';

  @override
  String get diveLog_detail_menu_openFullPage => 'פתיחה בעמוד מלא';

  @override
  String get diveLog_detail_noNotes => 'אין הערות לצלילה זו.';

  @override
  String get diveLog_detail_notFound => 'הצלילה לא נמצאה';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count נקודות';
  }

  @override
  String get diveLog_detail_section_altitudeDive => 'צלילת גובה';

  @override
  String get diveLog_detail_section_buddies => 'שותפים';

  @override
  String get diveLog_detail_section_conditions => 'תנאים';

  @override
  String get diveLog_detail_section_customFields => 'Custom Fields';

  @override
  String get diveLog_detail_section_decoStatus => 'מצב דקומפרסיה';

  @override
  String get diveLog_detail_section_details => 'פרטים';

  @override
  String get diveLog_detail_section_diveProfile => 'פרופיל צלילה';

  @override
  String get diveLog_detail_section_equipment => 'ציוד';

  @override
  String get diveLog_detail_section_marineLife => 'חיים ימיים';

  @override
  String get diveLog_detail_section_notes => 'הערות';

  @override
  String get diveLog_detail_section_oxygenToxicity => 'רעילות חמצן';

  @override
  String get diveLog_detail_section_sacByCylinder => 'SAC לפי בלון';

  @override
  String get diveLog_detail_section_sacRateBySegment => 'קצב SAC לפי מקטע';

  @override
  String get diveLog_detail_section_tags => 'תגיות';

  @override
  String get diveLog_detail_section_tanks => 'בלונים';

  @override
  String get diveLog_detail_section_tide => 'גאות ושפל';

  @override
  String get diveLog_detail_section_trainingSignature => 'חתימת הכשרה';

  @override
  String get diveLog_detail_section_weight => 'משקולות';

  @override
  String get diveLog_detail_signatureDescription =>
      'הקש להוספת אימות מדריך לצלילת הכשרה זו';

  @override
  String get diveLog_detail_soloDive => 'צלילה יחידה או ללא שותפים רשומים';

  @override
  String diveLog_detail_speciesCount(Object count) {
    return '$count מינים';
  }

  @override
  String get diveLog_detail_stat_bottomTime => 'זמן תחתית';

  @override
  String get diveLog_detail_stat_maxDepth => 'עומק מרבי';

  @override
  String get diveLog_detail_stat_runtime => 'זמן ריצה';

  @override
  String get diveLog_detail_stat_waterTemp => 'טמפ\' מים';

  @override
  String diveLog_detail_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'תגיות',
      one: 'תגית',
    );
    return '$count $_temp0';
  }

  @override
  String diveLog_detail_tankCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'בלונים',
      one: 'בלון',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_tideCalculated => 'חושב ממודל גאות ושפל';

  @override
  String get diveLog_detail_tooltip_addToFavorites => 'הוספה למועדפים';

  @override
  String get diveLog_detail_tooltip_edit => 'עריכה';

  @override
  String get diveLog_detail_tooltip_editDive => 'עריכת צלילה';

  @override
  String get diveLog_detail_tooltip_exportProfileImage => 'ייצוא פרופיל כתמונה';

  @override
  String get diveLog_detail_tooltip_removeFromFavorites => 'הסרה מהמועדפים';

  @override
  String get diveLog_detail_tooltip_viewFullscreen => 'הצגה במסך מלא';

  @override
  String get diveLog_detail_viewSite => 'הצגת אתר';

  @override
  String get diveLog_diveMode_ccrDescription =>
      'ריברידר מעגל סגור עם ppO₂ קבוע';

  @override
  String get diveLog_diveMode_ocDescription =>
      'סקובה מעגל פתוח סטנדרטי עם בלונים';

  @override
  String get diveLog_diveMode_scrDescription =>
      'ריברידר חצי סגור עם ppO₂ משתנה';

  @override
  String get diveLog_diveMode_title => 'מצב צלילה';

  @override
  String get diveLog_editSighting_count => 'כמות';

  @override
  String get diveLog_editSighting_notes => 'הערות';

  @override
  String get diveLog_editSighting_notesHint => 'גודל, התנהגות, מיקום...';

  @override
  String get diveLog_editSighting_remove => 'הסרה';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return 'להסיר את $name מצלילה זו?';
  }

  @override
  String get diveLog_editSighting_removeTitle => 'הסרת תצפית?';

  @override
  String get diveLog_editSighting_save => 'שמירת שינויים';

  @override
  String get diveLog_edit_add => 'הוספה';

  @override
  String get diveLog_edit_addCustomField => 'Add Field';

  @override
  String get diveLog_edit_addTank => 'הוספת בלון';

  @override
  String get diveLog_edit_addWeightEntry => 'הוספת רשומת משקל';

  @override
  String diveLog_edit_addedGps(Object name) {
    return 'GPS נוסף ל-$name';
  }

  @override
  String get diveLog_edit_appBarEdit => 'עריכת צלילה';

  @override
  String get diveLog_edit_appBarNew => 'רישום צלילה';

  @override
  String get diveLog_edit_cancel => 'ביטול';

  @override
  String get diveLog_edit_clearAllEquipment => 'ניקוי הכל';

  @override
  String diveLog_edit_createdSite(Object name) {
    return 'אתר נוצר: $name';
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
    return 'משך: $minutes min';
  }

  @override
  String get diveLog_edit_equipmentHint =>
      'הקש \"שימוש בסט\" או \"הוספה\" לבחירת ציוד';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return 'שגיאה בטעינת סוגי צלילה: $error';
  }

  @override
  String get diveLog_edit_gettingLocation => 'מקבל מיקום...';

  @override
  String get diveLog_edit_headerNew => 'רישום צלילה חדשה';

  @override
  String get diveLog_edit_label_airTemp => 'טמפ\' אוויר';

  @override
  String get diveLog_edit_label_altitude => 'גובה';

  @override
  String get diveLog_edit_label_avgDepth => 'עומק ממוצע';

  @override
  String get diveLog_edit_label_bottomTime => 'זמן תחתית';

  @override
  String get diveLog_edit_label_currentDirection => 'כיוון זרם';

  @override
  String get diveLog_edit_label_currentStrength => 'עוצמת זרם';

  @override
  String get diveLog_edit_label_diveType => 'סוג צלילה';

  @override
  String get diveLog_edit_label_entryMethod => 'שיטת כניסה';

  @override
  String get diveLog_edit_label_exitMethod => 'שיטת יציאה';

  @override
  String get diveLog_edit_label_maxDepth => 'עומק מרבי';

  @override
  String get diveLog_edit_label_runtime => 'זמן ריצה';

  @override
  String get diveLog_edit_label_surfacePressure => 'לחץ פני שטח';

  @override
  String get diveLog_edit_label_swellHeight => 'גובה גלים';

  @override
  String get diveLog_edit_label_type => 'סוג';

  @override
  String get diveLog_edit_label_visibility => 'ראות';

  @override
  String get diveLog_edit_label_waterTemp => 'טמפ\' מים';

  @override
  String get diveLog_edit_label_waterType => 'סוג מים';

  @override
  String get diveLog_edit_marineLifeHint => 'הקש \"הוספה\" לרישום תצפיות';

  @override
  String get diveLog_edit_nearbySitesFirst => 'אתרים קרובים תחילה';

  @override
  String get diveLog_edit_noEquipmentSelected => 'לא נבחר ציוד';

  @override
  String get diveLog_edit_noMarineLife => 'לא נרשמו חיים ימיים';

  @override
  String get diveLog_edit_notSpecified => 'לא צוין';

  @override
  String get diveLog_edit_notesHint => 'הוסף הערות לצלילה זו...';

  @override
  String get diveLog_edit_save => 'שמירה';

  @override
  String get diveLog_edit_saveAsSet => 'שמירה כסט';

  @override
  String diveLog_edit_saveAsSetDialog_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'פריטים',
      one: 'פריט',
    );
    return 'שמירת $count $_temp0 כסט ציוד חדש.';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description => 'תיאור (אופציונלי)';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint =>
      'למשל, ציוד קל למים חמים';

  @override
  String diveLog_edit_saveAsSetDialog_error(Object error) {
    return 'שגיאה ביצירת סט: $error';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_setName => 'שם הסט';

  @override
  String get diveLog_edit_saveAsSetDialog_setNameHint => 'למשל, צלילה טרופית';

  @override
  String diveLog_edit_saveAsSetDialog_success(Object name) {
    return 'סט הציוד \"$name\" נוצר';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title => 'שמירה כסט ציוד';

  @override
  String get diveLog_edit_saveAsSetDialog_validation => 'נא להזין שם לסט';

  @override
  String get diveLog_edit_section_conditions => 'תנאים';

  @override
  String get diveLog_edit_section_customFields => 'Custom Fields';

  @override
  String get diveLog_edit_section_depthDuration => 'עומק ומשך';

  @override
  String get diveLog_edit_section_diveCenter => 'מועדון צלילה';

  @override
  String get diveLog_edit_section_diveSite => 'אתר צלילה';

  @override
  String get diveLog_edit_section_entryTime => 'שעת כניסה';

  @override
  String get diveLog_edit_section_equipment => 'ציוד';

  @override
  String get diveLog_edit_section_exitTime => 'שעת יציאה';

  @override
  String get diveLog_edit_section_marineLife => 'חיים ימיים';

  @override
  String get diveLog_edit_section_notes => 'הערות';

  @override
  String get diveLog_edit_section_rating => 'דירוג';

  @override
  String get diveLog_edit_section_tags => 'תגיות';

  @override
  String diveLog_edit_section_tanks(Object count) {
    return 'בלונים ($count)';
  }

  @override
  String get diveLog_edit_section_trainingCourse => 'קורס הכשרה';

  @override
  String get diveLog_edit_section_trip => 'טיול';

  @override
  String get diveLog_edit_section_weight => 'משקולות';

  @override
  String get diveLog_edit_select => 'בחירה';

  @override
  String get diveLog_edit_selectDiveCenter => 'בחירת מועדון צלילה';

  @override
  String get diveLog_edit_selectDiveSite => 'בחירת אתר צלילה';

  @override
  String get diveLog_edit_selectTrip => 'בחירת טיול';

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'זמן תחתית חושב: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'שגיאה בשמירת צלילה: $error';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'אין נתוני פרופיל צלילה זמינים';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'לא ניתן לחשב זמן תחתית מהפרופיל';

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return 'מרווח פני שטח: $interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint =>
      'סטנדרטי: 1013 mbar בגובה פני הים';

  @override
  String get diveLog_edit_tooltip_calculateFromProfile =>
      'חישוב מפרופיל הצלילה';

  @override
  String get diveLog_edit_tooltip_clearDiveCenter => 'ניקוי מועדון צלילה';

  @override
  String get diveLog_edit_tooltip_clearSite => 'ניקוי אתר';

  @override
  String get diveLog_edit_tooltip_clearTrip => 'ניקוי טיול';

  @override
  String get diveLog_edit_tooltip_removeEquipment => 'הסרת ציוד';

  @override
  String get diveLog_edit_tooltip_removeSighting => 'הסרת תצפית';

  @override
  String get diveLog_edit_tooltip_removeWeight => 'הסרה';

  @override
  String get diveLog_edit_trainingCourseHint => 'קישור צלילה זו לקורס הכשרה';

  @override
  String diveLog_edit_tripSuggested(Object name) {
    return 'מוצע: $name';
  }

  @override
  String get diveLog_edit_tripUse => 'שימוש';

  @override
  String get diveLog_edit_useSet => 'שימוש בסט';

  @override
  String diveLog_edit_weightTotal(Object total) {
    return 'סה\"כ: $total';
  }

  @override
  String get diveLog_emptyFiltered_clearFilters => 'ניקוי מסננים';

  @override
  String get diveLog_emptyFiltered_subtitle => 'נסה לשנות או לנקות את המסננים';

  @override
  String get diveLog_emptyFiltered_title => 'אין צלילות התואמות את המסננים';

  @override
  String get diveLog_empty_logFirstDive => 'רשום את הצלילה הראשונה';

  @override
  String get diveLog_empty_subtitle =>
      'הקש על הכפתור למטה לרישום הצלילה הראשונה';

  @override
  String get diveLog_empty_title => 'אין צלילות רשומות עדיין';

  @override
  String get diveLog_equipmentPicker_addFromTab => 'הוסף ציוד מלשונית הציוד';

  @override
  String get diveLog_equipmentPicker_allSelected => 'כל הציוד כבר נבחר';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return 'שגיאה בטעינת ציוד: $error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => 'אין ציוד עדיין';

  @override
  String get diveLog_equipmentPicker_removeToAdd => 'הסר פריטים להוספת אחרים';

  @override
  String get diveLog_equipmentPicker_title => 'הוספת ציוד';

  @override
  String get diveLog_equipmentSetPicker_createHint => 'צור סטים בציוד > סטים';

  @override
  String get diveLog_equipmentSetPicker_emptySet => 'סט ריק';

  @override
  String get diveLog_equipmentSetPicker_errorItems => 'שגיאה בטעינת פריטים';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return 'שגיאה בטעינת סטי ציוד: $error';
  }

  @override
  String get diveLog_equipmentSetPicker_loading => 'טוען...';

  @override
  String get diveLog_equipmentSetPicker_noSets => 'אין סטי ציוד עדיין';

  @override
  String get diveLog_equipmentSetPicker_title => 'שימוש בסט ציוד';

  @override
  String get diveLog_error_loadingDives => 'שגיאה בטעינת צלילות';

  @override
  String get diveLog_error_retry => 'ניסיון חוזר';

  @override
  String get diveLog_exportImage_captureFailed => 'לא ניתן ללכוד תמונה';

  @override
  String get diveLog_exportImage_generateFailed => 'לא ניתן ליצור תמונה';

  @override
  String get diveLog_exportImage_generatingPdf => 'מייצר PDF...';

  @override
  String get diveLog_exportImage_pdfSaved => 'PDF נשמר';

  @override
  String get diveLog_exportImage_saveToFiles => 'שמירה לקבצים';

  @override
  String get diveLog_exportImage_saveToFilesDescription =>
      'בחר מיקום לשמירת הקובץ';

  @override
  String get diveLog_exportImage_saveToPhotos => 'שמירה לתמונות';

  @override
  String get diveLog_exportImage_saveToPhotosDescription =>
      'שמירת תמונה לספריית התמונות';

  @override
  String get diveLog_exportImage_savedToFiles => 'התמונה נשמרה';

  @override
  String get diveLog_exportImage_savedToPhotos => 'התמונה נשמרה לתמונות';

  @override
  String get diveLog_exportImage_share => 'שיתוף';

  @override
  String get diveLog_exportImage_shareDescription =>
      'שיתוף דרך אפליקציות אחרות';

  @override
  String get diveLog_exportImage_titleDetails => 'ייצוא תמונת פרטי צלילה';

  @override
  String get diveLog_exportImage_titlePdf => 'ייצוא PDF';

  @override
  String get diveLog_exportImage_titleProfile => 'ייצוא תמונת פרופיל';

  @override
  String get diveLog_export_csv => 'CSV';

  @override
  String get diveLog_export_csvDescription => 'פורמט גיליון אלקטרוני';

  @override
  String get diveLog_export_exporting => 'מייצא...';

  @override
  String diveLog_export_failed(Object error) {
    return 'הייצוא נכשל: $error';
  }

  @override
  String get diveLog_export_pageAsImage => 'עמוד כתמונה';

  @override
  String get diveLog_export_pageAsImageDescription =>
      'צילום מסך של כל פרטי הצלילה';

  @override
  String get diveLog_export_pdfDescription => 'דף יומן צלילה להדפסה';

  @override
  String get diveLog_export_pdfLogbookEntry => 'רשומת יומן PDF';

  @override
  String get diveLog_export_success => 'הצלילה יוצאה בהצלחה';

  @override
  String diveLog_export_titleDiveNumber(Object number) {
    return 'ייצוא צלילה #$number';
  }

  @override
  String get diveLog_export_uddf => 'UDDF';

  @override
  String get diveLog_export_uddfDescription => 'פורמט נתוני צלילה אוניברסלי';

  @override
  String get diveLog_filterChip_clearAll => 'ניקוי הכל';

  @override
  String get diveLog_filterChip_favorites => 'מועדפים';

  @override
  String diveLog_filterChip_from(Object date) {
    return 'מ-$date';
  }

  @override
  String diveLog_filterChip_until(Object date) {
    return 'עד $date';
  }

  @override
  String get diveLog_filter_allSites => 'כל האתרים';

  @override
  String get diveLog_filter_allTypes => 'כל הסוגים';

  @override
  String get diveLog_filter_apply => 'החלת מסננים';

  @override
  String get diveLog_filter_buddyHint => 'חיפוש לפי שם שותף';

  @override
  String get diveLog_filter_buddyName => 'שם שותף';

  @override
  String get diveLog_filter_clearAll => 'ניקוי הכל';

  @override
  String get diveLog_filter_clearDates => 'ניקוי תאריכים';

  @override
  String get diveLog_filter_clearRating => 'ניקוי מסנן דירוג';

  @override
  String get diveLog_filter_dateSeparator => 'עד';

  @override
  String get diveLog_filter_endDate => 'תאריך סיום';

  @override
  String get diveLog_filter_errorLoadingSites => 'שגיאה בטעינת אתרים';

  @override
  String get diveLog_filter_errorLoadingTags => 'שגיאה בטעינת תגיות';

  @override
  String get diveLog_filter_favoritesOnly => 'מועדפים בלבד';

  @override
  String get diveLog_filter_gasAir => 'אוויר (21%)';

  @override
  String get diveLog_filter_gasAll => 'הכל';

  @override
  String get diveLog_filter_gasNitrox => 'ניטרוקס (>21%)';

  @override
  String get diveLog_filter_max => 'מרבי';

  @override
  String get diveLog_filter_min => 'מזערי';

  @override
  String get diveLog_filter_noTagsYet => 'לא נוצרו תגיות עדיין';

  @override
  String get diveLog_filter_sectionBuddy => 'שותף';

  @override
  String get diveLog_filter_sectionDateRange => 'טווח תאריכים';

  @override
  String get diveLog_filter_sectionDepthRange => 'טווח עומק (מטרים)';

  @override
  String get diveLog_filter_sectionDiveSite => 'אתר צלילה';

  @override
  String get diveLog_filter_sectionDiveType => 'סוג צלילה';

  @override
  String get diveLog_filter_sectionDuration => 'משך (דקות)';

  @override
  String get diveLog_filter_sectionGasMix => 'תערובת גזים (O₂%)';

  @override
  String get diveLog_filter_sectionMinRating => 'דירוג מינימלי';

  @override
  String get diveLog_filter_sectionTags => 'תגיות';

  @override
  String get diveLog_filter_showOnlyFavorites => 'הצגת צלילות מועדפות בלבד';

  @override
  String get diveLog_filter_startDate => 'תאריך התחלה';

  @override
  String get diveLog_filter_title => 'סינון צלילות';

  @override
  String get diveLog_filter_tooltip_close => 'סגירת מסנן';

  @override
  String get diveLog_fullscreenProfile_close => 'סגירת מסך מלא';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'פרופיל צלילה #$number';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'קצב עלייה';

  @override
  String get diveLog_legend_label_ceiling => 'תקרה';

  @override
  String get diveLog_legend_label_depth => 'עומק';

  @override
  String get diveLog_legend_label_events => 'אירועים';

  @override
  String get diveLog_legend_label_gasDensity => 'צפיפות גז';

  @override
  String get diveLog_legend_label_gasSwitches => 'החלפות גז';

  @override
  String get diveLog_legend_label_gfPercent => 'GF%';

  @override
  String get diveLog_legend_label_heartRate => 'קצב לב';

  @override
  String get diveLog_legend_label_maxDepth => 'עומק מרבי';

  @override
  String get diveLog_legend_label_meanDepth => 'עומק ממוצע';

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
  String get diveLog_legend_label_pressure => 'לחץ';

  @override
  String get diveLog_legend_label_pressureThresholds => 'ספי לחץ';

  @override
  String get diveLog_legend_label_sacRate => 'קצב SAC';

  @override
  String get diveLog_legend_label_surfaceGf => 'GF פני השטח';

  @override
  String get diveLog_legend_label_temp => 'טמפ\'';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_listPage_appBar_diveMap => 'מפת צלילות';

  @override
  String get diveLog_listPage_compactTitle => 'צלילות';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get diveLog_listPage_fab_logDive => 'רישום צלילה';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'חיפוש מתקדם';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'מספור צלילות';

  @override
  String get diveLog_listPage_searchFieldLabel => 'חיפוש צלילות...';

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return 'לא נמצאו צלילות עבור \"$query\"';
  }

  @override
  String get diveLog_listPage_searchSuggestion =>
      'חיפוש לפי אתר, שותף או הערות';

  @override
  String get diveLog_listPage_title => 'יומן צלילה';

  @override
  String get diveLog_listPage_tooltip_back => 'חזרה';

  @override
  String get diveLog_listPage_tooltip_backToDiveList => 'חזרה לרשימת צלילות';

  @override
  String get diveLog_listPage_tooltip_clearSearch => 'ניקוי חיפוש';

  @override
  String get diveLog_listPage_tooltip_filterDives => 'סינון צלילות';

  @override
  String get diveLog_listPage_tooltip_listView => 'תצוגת רשימה';

  @override
  String get diveLog_listPage_tooltip_mapView => 'תצוגת מפה';

  @override
  String get diveLog_listPage_tooltip_searchDives => 'חיפוש צלילות';

  @override
  String get diveLog_listPage_tooltip_sort => 'מיון';

  @override
  String get diveLog_listPage_unknownSite => 'אתר לא ידוע';

  @override
  String get diveLog_map_emptySubtitle =>
      'רשום צלילות עם נתוני מיקום כדי לראות את הפעילות שלך על המפה';

  @override
  String get diveLog_map_emptyTitle => 'אין פעילות צלילה להצגה';

  @override
  String diveLog_map_errorLoading(Object error) {
    return 'שגיאה בטעינת נתוני צלילה: $error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => 'התאמה לכל האתרים';

  @override
  String get diveLog_numbering_actions => 'פעולות';

  @override
  String get diveLog_numbering_allCorrect => 'כל הצלילות ממוספרות נכון';

  @override
  String get diveLog_numbering_assignMissing => 'הקצאת מספרים חסרים';

  @override
  String get diveLog_numbering_assignMissingDesc =>
      'מספור צלילות ללא מספר החל מאחרי הצלילה הממוספרת האחרונה';

  @override
  String get diveLog_numbering_close => 'סגירה';

  @override
  String get diveLog_numbering_gapsDetected => 'זוהו פערים';

  @override
  String get diveLog_numbering_issuesDetected => 'זוהו בעיות';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '$count חסרים';
  }

  @override
  String get diveLog_numbering_renumberAll => 'מספור מחדש של כל הצלילות';

  @override
  String get diveLog_numbering_renumberAllDesc =>
      'הקצאת מספרים רציפים על פי תאריך/שעת הצלילה';

  @override
  String get diveLog_numbering_renumberDialog_cancel => 'ביטול';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      'פעולה זו תמספר מחדש את כל הצלילות ברצף לפי תאריך/שעת הכניסה. פעולה זו אינה ניתנת לביטול.';

  @override
  String get diveLog_numbering_renumberDialog_renumber => 'מספור מחדש';

  @override
  String get diveLog_numbering_renumberDialog_startFrom => 'התחל ממספר';

  @override
  String get diveLog_numbering_renumberDialog_title =>
      'מספור מחדש של כל הצלילות';

  @override
  String get diveLog_numbering_snackbar_assigned => 'מספרי צלילה חסרים הוקצו';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return 'כל הצלילות מוספרו מחדש החל מ-#$number';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '$total צלילות סה\"כ • $numbered ממוספרות';
  }

  @override
  String get diveLog_numbering_title => 'מספור צלילות';

  @override
  String diveLog_numbering_unnumberedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צלילות',
      one: 'צלילה',
    );
    return '$count $_temp0 ללא מספר';
  }

  @override
  String get diveLog_o2tox_badge_critical => 'קריטי';

  @override
  String get diveLog_o2tox_badge_warning => 'אזהרה';

  @override
  String diveLog_o2tox_cnsBadgeLabel(Object value) {
    return 'CNS $value';
  }

  @override
  String get diveLog_o2tox_cnsOxygenClock => 'שעון חמצן CNS';

  @override
  String diveLog_o2tox_deltaDive(Object value) {
    return '+$value% בצלילה זו';
  }

  @override
  String get diveLog_o2tox_details => 'פרטים';

  @override
  String get diveLog_o2tox_label_maxPpO2 => 'ppO2 מרבי';

  @override
  String get diveLog_o2tox_label_maxPpO2Depth => 'עומק ppO2 מרבי';

  @override
  String get diveLog_o2tox_label_timeAbove14 => 'זמן מעל 1.4 bar';

  @override
  String get diveLog_o2tox_label_timeAbove16 => 'זמן מעל 1.6 bar';

  @override
  String get diveLog_o2tox_ofDailyLimit => 'מהמגבלה היומית';

  @override
  String get diveLog_o2tox_oxygenToleranceUnits => 'יחידות סבילות חמצן';

  @override
  String diveLog_o2tox_semantics_cnsBadge(Object value) {
    return 'רעילות חמצן CNS $value';
  }

  @override
  String get diveLog_o2tox_semantics_criticalWarning =>
      'אזהרת רעילות חמצן קריטית';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return 'יחידות סבילות חמצן: $value, $percent אחוזים מהמגבלה היומית';
  }

  @override
  String get diveLog_o2tox_semantics_warning => 'אזהרת רעילות חמצן';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return 'התחלה: $value%';
  }

  @override
  String get diveLog_o2tox_title => 'רעילות חמצן';

  @override
  String get diveLog_playbackStats_deco => 'דקו';

  @override
  String get diveLog_playbackStats_depth => 'עומק';

  @override
  String get diveLog_playbackStats_header => 'נתונים חיים';

  @override
  String get diveLog_playbackStats_heartRate => 'קצב לב';

  @override
  String get diveLog_playbackStats_ndl => 'NDL';

  @override
  String get diveLog_playbackStats_ppO2 => 'ppO₂';

  @override
  String get diveLog_playbackStats_pressure => 'לחץ';

  @override
  String get diveLog_playbackStats_temp => 'טמפ\'';

  @override
  String get diveLog_playback_sliderLabel => 'מיקום הפעלה';

  @override
  String diveLog_playback_speed_label(Object speed) {
    return '${speed}x';
  }

  @override
  String get diveLog_playback_stepThrough => 'הפעלה צעד אחר צעד';

  @override
  String get diveLog_playback_tooltip_back10 => '10 שניות אחורה';

  @override
  String get diveLog_playback_tooltip_exit => 'יציאה ממצב הפעלה';

  @override
  String get diveLog_playback_tooltip_forward10 => '10 שניות קדימה';

  @override
  String get diveLog_playback_tooltip_pause => 'השהייה';

  @override
  String get diveLog_playback_tooltip_play => 'הפעלה';

  @override
  String get diveLog_playback_tooltip_skipEnd => 'דלג לסוף';

  @override
  String get diveLog_playback_tooltip_skipStart => 'דלג להתחלה';

  @override
  String get diveLog_playback_tooltip_speed => 'מהירות הפעלה';

  @override
  String get diveLog_profileSelector_badge_primary => 'ראשי';

  @override
  String get diveLog_profileSelector_label_diveComputers => 'מחשבי צלילה';

  @override
  String diveLog_profile_axisDepth(Object unit) {
    return 'עומק ($unit)';
  }

  @override
  String get diveLog_profile_axisTime => 'זמן (min)';

  @override
  String get diveLog_profile_emptyState => 'אין נתוני פרופיל צלילה';

  @override
  String get diveLog_profile_rightAxis_none => 'ללא';

  @override
  String get diveLog_profile_semantics_changeRightAxis => 'שינוי מדד ציר ימני';

  @override
  String get diveLog_profile_semantics_chart => 'תרשים פרופיל צלילה, צבוט לזום';

  @override
  String get diveLog_profile_tooltip_moreOptions => 'אפשרויות תרשים נוספות';

  @override
  String get diveLog_profile_tooltip_resetZoom => 'איפוס זום';

  @override
  String get diveLog_profile_tooltip_zoomIn => 'הגדלה';

  @override
  String get diveLog_profile_tooltip_zoomOut => 'הקטנה';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return 'זום: ${level}x • צבוט או גלול לזום, גרור לגלילה';
  }

  @override
  String get diveLog_rangeSelection_exitRange => 'יציאה מטווח';

  @override
  String get diveLog_rangeSelection_selectRange => 'בחירת טווח';

  @override
  String get diveLog_rangeSelection_semantics_adjust => 'התאמת בחירת טווח';

  @override
  String get diveLog_rangeStats_header_avg => 'ממוצע';

  @override
  String get diveLog_rangeStats_header_max => 'מרבי';

  @override
  String get diveLog_rangeStats_header_min => 'מזערי';

  @override
  String get diveLog_rangeStats_label_depth => 'עומק';

  @override
  String get diveLog_rangeStats_label_heartRate => 'קצב לב';

  @override
  String get diveLog_rangeStats_label_pressure => 'לחץ';

  @override
  String get diveLog_rangeStats_label_temp => 'טמפ\'';

  @override
  String get diveLog_rangeStats_title => 'ניתוח טווח';

  @override
  String get diveLog_rangeStats_tooltip_close => 'סגירת ניתוח טווח';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return 'FO₂ מעגל מחושב: $value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => 'למשל, 0.33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => 'יחס הוספה';

  @override
  String get diveLog_scr_label_assumedVo2 => 'VO₂ משוער';

  @override
  String get diveLog_scr_label_avg => 'ממוצע';

  @override
  String get diveLog_scr_label_injectionRate => 'קצב הזרקה';

  @override
  String get diveLog_scr_label_max => 'מקסימום';

  @override
  String get diveLog_scr_label_min => 'מינימום';

  @override
  String get diveLog_scr_label_orificeSize => 'גודל פתח';

  @override
  String get diveLog_scr_sectionCmf => 'פרמטרי CMF';

  @override
  String get diveLog_scr_sectionEscr => 'פרמטרי ESCR';

  @override
  String get diveLog_scr_sectionMeasuredLoopO2 => 'מדידת O₂ בלולאה (אופציונלי)';

  @override
  String get diveLog_scr_sectionPascr => 'פרמטרי PASCR';

  @override
  String get diveLog_scr_sectionScrType => 'סוג SCR';

  @override
  String get diveLog_scr_sectionSupplyGas => 'גז אספקה';

  @override
  String get diveLog_scr_title => 'הגדרות SCR';

  @override
  String get diveLog_search_allCenters => 'כל המרכזים';

  @override
  String get diveLog_search_allTrips => 'כל הטיולים';

  @override
  String get diveLog_search_appBar => 'חיפוש מתקדם';

  @override
  String get diveLog_search_cancel => 'ביטול';

  @override
  String get diveLog_search_clearAll => 'נקה הכל';

  @override
  String get diveLog_search_customFieldKey => 'Custom Field Key';

  @override
  String get diveLog_search_customFieldValue => 'Value contains...';

  @override
  String get diveLog_search_end => 'סיום';

  @override
  String get diveLog_search_errorLoadingCenters => 'שגיאה בטעינת מרכזי צלילה';

  @override
  String get diveLog_search_errorLoadingDiveTypes => 'שגיאה בטעינת סוגי צלילה';

  @override
  String get diveLog_search_errorLoadingTrips => 'שגיאה בטעינת טיולים';

  @override
  String get diveLog_search_gasTrimix => 'טריימיקס (<21% O₂)';

  @override
  String get diveLog_search_label_depthRange => 'טווח עומק (m)';

  @override
  String get diveLog_search_label_diveCenter => 'מרכז צלילה';

  @override
  String get diveLog_search_label_diveSite => 'אתר צלילה';

  @override
  String get diveLog_search_label_diveType => 'סוג צלילה';

  @override
  String get diveLog_search_label_durationRange => 'טווח משך (min)';

  @override
  String get diveLog_search_label_trip => 'טיול';

  @override
  String get diveLog_search_search => 'חיפוש';

  @override
  String get diveLog_search_section_conditions => 'תנאים';

  @override
  String get diveLog_search_section_dateRange => 'טווח תאריכים';

  @override
  String get diveLog_search_section_gasEquipment => 'גז וציוד';

  @override
  String get diveLog_search_section_location => 'מיקום';

  @override
  String get diveLog_search_section_organization => 'ארגון';

  @override
  String get diveLog_search_section_social => 'חברתי';

  @override
  String get diveLog_search_start => 'התחלה';

  @override
  String diveLog_selection_countSelected(Object count) {
    return '$count נבחרו';
  }

  @override
  String get diveLog_selection_tooltip_delete => 'מחק נבחרים';

  @override
  String get diveLog_selection_tooltip_deselectAll => 'בטל בחירת הכל';

  @override
  String get diveLog_selection_tooltip_edit => 'ערוך נבחרים';

  @override
  String get diveLog_selection_tooltip_exit => 'צא מבחירה';

  @override
  String get diveLog_selection_tooltip_export => 'ייצא נבחרים';

  @override
  String get diveLog_selection_tooltip_selectAll => 'בחר הכל';

  @override
  String get diveLog_sighting_add => 'הוסף';

  @override
  String get diveLog_sighting_cancel => 'ביטול';

  @override
  String get diveLog_sighting_notesHint => 'לדוגמה, גודל, התנהגות, מיקום...';

  @override
  String get diveLog_sighting_notesOptional => 'הערות (אופציונלי)';

  @override
  String get diveLog_sitePicker_addDiveSite => 'הוסף אתר צלילה';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return '$distance km משם';
  }

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return '$distance m משם';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return 'שגיאה בטעינת אתרים: $error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => 'אתר צלילה חדש';

  @override
  String get diveLog_sitePicker_noSites => 'אין עדיין אתרי צלילה';

  @override
  String get diveLog_sitePicker_sortedByDistance => 'ממוין לפי מרחק';

  @override
  String get diveLog_sitePicker_title => 'בחר אתר צלילה';

  @override
  String get diveLog_sort_title => 'מיין צלילות';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return 'הוסף \"$name\" כמין חדש';
  }

  @override
  String get diveLog_speciesPicker_noResults => 'לא נמצאו מינים';

  @override
  String get diveLog_speciesPicker_noSpecies => 'אין מינים זמינים';

  @override
  String get diveLog_speciesPicker_searchHint => 'חפש מינים...';

  @override
  String get diveLog_speciesPicker_title => 'הוסף חיים ימיים';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch => 'נקה חיפוש';

  @override
  String get diveLog_summary_action_importComputer => 'ייבא ממחשב';

  @override
  String get diveLog_summary_action_logDive => 'רשום צלילה';

  @override
  String get diveLog_summary_action_viewStats => 'הצג סטטיסטיקות';

  @override
  String diveLog_summary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צלילות',
      one: 'צלילה',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_summary_overview => 'סקירה כללית';

  @override
  String get diveLog_summary_record_coldest => 'הצלילה הקרה ביותר';

  @override
  String get diveLog_summary_record_deepest => 'הצלילה העמוקה ביותר';

  @override
  String get diveLog_summary_record_longest => 'הצלילה הארוכה ביותר';

  @override
  String get diveLog_summary_record_warmest => 'הצלילה החמה ביותר';

  @override
  String get diveLog_summary_section_mostVisited => 'האתרים הנצפים ביותר';

  @override
  String get diveLog_summary_section_quickActions => 'פעולות מהירות';

  @override
  String get diveLog_summary_section_records => 'שיאים אישיים';

  @override
  String get diveLog_summary_selectDive => 'בחר צלילה מהרשימה כדי לצפות בפרטים';

  @override
  String get diveLog_summary_stat_avgMaxDepth => 'עומק מקסימלי ממוצע';

  @override
  String get diveLog_summary_stat_avgWaterTemp => 'טמפרטורת מים ממוצעת';

  @override
  String get diveLog_summary_stat_diveSites => 'אתרי צלילה';

  @override
  String get diveLog_summary_stat_diveTime => 'זמן צלילה';

  @override
  String get diveLog_summary_stat_maxDepth => 'עומק מקסימלי';

  @override
  String get diveLog_summary_stat_totalDives => 'סה\"כ צלילות';

  @override
  String get diveLog_summary_title => 'סיכום יומן צלילה';

  @override
  String get diveLog_tank_label_endPressure => 'לחץ סיום';

  @override
  String get diveLog_tank_label_he => 'He';

  @override
  String get diveLog_tank_label_material => 'חומר';

  @override
  String get diveLog_tank_label_n2 => 'N2';

  @override
  String get diveLog_tank_label_o2 => 'O2';

  @override
  String get diveLog_tank_label_role => 'תפקיד';

  @override
  String get diveLog_tank_label_startPressure => 'לחץ התחלה';

  @override
  String get diveLog_tank_label_tankPreset => 'תבנית בלון';

  @override
  String get diveLog_tank_label_volume => 'נפח';

  @override
  String get diveLog_tank_label_workingPressure => 'לחץ עבודה';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String get diveLog_tank_section_gasMix => 'תערובת גזים';

  @override
  String get diveLog_tank_selectPreset => 'בחר תבנית...';

  @override
  String diveLog_tank_title(Object number) {
    return 'בלון $number';
  }

  @override
  String get diveLog_tank_tooltip_remove => 'הסר בלון';

  @override
  String get diveLog_tissue_label_ceiling => 'תקרה';

  @override
  String get diveLog_tissue_label_gf => 'GF';

  @override
  String get diveLog_tissue_label_ndl => 'NDL';

  @override
  String get diveLog_tissue_label_tts => 'TTS';

  @override
  String get diveLog_tissue_legend_he => 'He';

  @override
  String get diveLog_tissue_legend_mValue => '100% ערך M';

  @override
  String get diveLog_tissue_legend_n2 => 'N₂';

  @override
  String get diveLog_tissue_title => 'עומס רקמות';

  @override
  String get diveLog_tooltip_ceiling => 'תקרה';

  @override
  String get diveLog_tooltip_density => 'צפיפות';

  @override
  String get diveLog_tooltip_depth => 'עומק';

  @override
  String get diveLog_tooltip_gfPercent => 'GF%';

  @override
  String get diveLog_tooltip_hr => 'HR';

  @override
  String get diveLog_tooltip_marker => 'סמן';

  @override
  String get diveLog_tooltip_mean => 'ממוצע';

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
  String get diveLog_tooltip_press => 'לחץ';

  @override
  String get diveLog_tooltip_rate => 'קצב';

  @override
  String get diveLog_tooltip_sac => 'SAC';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'טמפ\'';

  @override
  String get diveLog_tooltip_time => 'זמן';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get divePlanner_action_addTank => 'הוסף מיכל';

  @override
  String get divePlanner_action_convertToDive => 'המר לצלילה';

  @override
  String get divePlanner_action_editTank => 'ערוך מיכל';

  @override
  String get divePlanner_action_moreOptions => 'אפשרויות נוספות';

  @override
  String get divePlanner_action_quickPlan => 'תכנון מהיר';

  @override
  String get divePlanner_action_renamePlan => 'שנה שם תכנית';

  @override
  String get divePlanner_action_reset => 'אפס';

  @override
  String get divePlanner_action_resetPlan => 'אפס תכנית';

  @override
  String get divePlanner_action_savePlan => 'שמור תכנית';

  @override
  String get divePlanner_error_cannotConvert =>
      'לא ניתן להמיר: לתכנית יש אזהרות קריטיות';

  @override
  String get divePlanner_field_hePercent => 'He %';

  @override
  String get divePlanner_field_name => 'שם';

  @override
  String get divePlanner_field_o2Percent => 'O₂ %';

  @override
  String get divePlanner_field_planName => 'שם התכנית';

  @override
  String get divePlanner_field_role => 'תפקיד';

  @override
  String divePlanner_field_startPressure(Object pressureSymbol) {
    return 'לחץ התחלתי ($pressureSymbol)';
  }

  @override
  String divePlanner_field_volume(Object volumeSymbol) {
    return 'נפח ($volumeSymbol)';
  }

  @override
  String get divePlanner_hint_tankName => 'הזן שם מיכל';

  @override
  String get divePlanner_label_altitude => 'גובה:';

  @override
  String get divePlanner_label_belowMinReserve => 'מתחת למינימום מילואים';

  @override
  String get divePlanner_label_ceiling => 'תקרה';

  @override
  String get divePlanner_label_consumption => 'צריכה';

  @override
  String get divePlanner_label_deco => 'DECO';

  @override
  String get divePlanner_label_decoSchedule => 'לוח דקומפרסיה';

  @override
  String get divePlanner_label_decompression => 'דקומפרסיה';

  @override
  String divePlanner_label_depthAxis(Object depthSymbol) {
    return 'עומק ($depthSymbol)';
  }

  @override
  String get divePlanner_label_diveProfile => 'פרופיל צלילה';

  @override
  String get divePlanner_label_empty => 'ריק';

  @override
  String get divePlanner_label_gasConsumption => 'צריכת גז';

  @override
  String get divePlanner_label_gfHigh => 'GF גבוה';

  @override
  String get divePlanner_label_gfLow => 'GF נמוך';

  @override
  String get divePlanner_label_max => 'מקסימום';

  @override
  String get divePlanner_label_ndl => 'NDL';

  @override
  String get divePlanner_label_planSettings => 'הגדרות תכנית';

  @override
  String get divePlanner_label_remaining => 'נותר';

  @override
  String get divePlanner_label_runtime => 'זמן ריצה';

  @override
  String get divePlanner_label_sacRate => 'קצב SAC:';

  @override
  String get divePlanner_label_status => 'סטטוס';

  @override
  String get divePlanner_label_tanks => 'מיכלים';

  @override
  String get divePlanner_label_time => 'זמן';

  @override
  String get divePlanner_label_timeAxis => 'זמן (דקות)';

  @override
  String get divePlanner_label_tts => 'TTS';

  @override
  String get divePlanner_label_used => 'נוצל';

  @override
  String get divePlanner_label_warnings => 'אזהרות';

  @override
  String get divePlanner_legend_ascent => 'עלייה';

  @override
  String get divePlanner_legend_bottom => 'תחתית';

  @override
  String get divePlanner_legend_deco => 'דקו';

  @override
  String get divePlanner_legend_descent => 'ירידה';

  @override
  String get divePlanner_legend_safety => 'בטיחות';

  @override
  String get divePlanner_message_addSegmentsForGas =>
      'הוסף קטעים כדי לראות תחזיות גז';

  @override
  String get divePlanner_message_addSegmentsForProfile =>
      'הוסף קטעים כדי לראות את פרופיל הצלילה';

  @override
  String get divePlanner_message_convertingPlan => 'ממיר תכנית לצלילה...';

  @override
  String get divePlanner_message_noProfile => 'אין פרופיל להצגה';

  @override
  String get divePlanner_message_planSaved => 'תכנית נשמרה';

  @override
  String get divePlanner_message_resetConfirmation =>
      'האם אתה בטוח שברצונך לאפס את התכנית?';

  @override
  String divePlanner_semantics_criticalWarning(Object message) {
    return 'אזהרה קריטית: $message';
  }

  @override
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  ) {
    return 'עצירת דקו ב-$depth למשך $duration על $gasMix';
  }

  @override
  String divePlanner_semantics_gasConsumption(
    Object tankName,
    Object gasUsed,
    Object remaining,
    Object percent,
    Object warning,
  ) {
    return '$tankName: $gasUsed נוצל, $remaining נותר, $percent נוצל$warning';
  }

  @override
  String divePlanner_semantics_profileChart(
    Object maxDepth,
    Object totalMinutes,
  ) {
    return 'תכנית צלילה, עומק מקסימלי $maxDepth, זמן כולל $totalMinutes דקות';
  }

  @override
  String divePlanner_semantics_warning(Object message) {
    return 'אזהרה: $message';
  }

  @override
  String get divePlanner_tab_plan => 'תכנית';

  @override
  String get divePlanner_tab_profile => 'פרופיל';

  @override
  String get divePlanner_tab_results => 'תוצאות';

  @override
  String get divePlanner_warning_ascentRateHigh =>
      'קצב עלייה חורג מהמגבלה הבטוחה';

  @override
  String divePlanner_warning_ascentRateHighWithRate(Object rate) {
    return 'קצב עלייה $rate/דקה חורג מהמגבלה הבטוחה';
  }

  @override
  String divePlanner_warning_belowMinReserve(Object reserve) {
    return 'מתחת למינימום מילואים ($reserve)';
  }

  @override
  String get divePlanner_warning_cnsCritical => 'CNS% חורג מ-100%';

  @override
  String divePlanner_warning_cnsWarning(Object threshold) {
    return 'CNS% חורג מ-$threshold%';
  }

  @override
  String get divePlanner_warning_endHigh => 'עומק נרקוטי שווה ערך גבוה מדי';

  @override
  String divePlanner_warning_endHighWithDepth(Object depth) {
    return 'END של $depth חורג מהמגבלה הבטוחה';
  }

  @override
  String divePlanner_warning_gasLow(Object threshold) {
    return 'מיכל מתחת למילואי $threshold';
  }

  @override
  String get divePlanner_warning_gasOut => 'המיכל יהיה ריק';

  @override
  String get divePlanner_warning_minGasViolation => 'מילואי גז מינימלי לא נשמר';

  @override
  String get divePlanner_warning_modViolation => 'ניסיון החלפת גז מעל MOD';

  @override
  String get divePlanner_warning_ndlExceeded => 'הצלילה נכנסת לחובת דקומפרסיה';

  @override
  String get divePlanner_warning_otuWarning => 'הצטברות OTU גבוהה';

  @override
  String divePlanner_warning_ppO2Critical(Object value) {
    return 'ppO₂ של $value בר חורג מהמגבלה הקריטית';
  }

  @override
  String divePlanner_warning_ppO2High(Object value) {
    return 'ppO₂ של $value בר חורג ממגבלת העבודה';
  }

  @override
  String get diveSites_detail_access_accessNotes => 'הערות גישה';

  @override
  String get diveSites_detail_access_mooring => 'עגינה';

  @override
  String get diveSites_detail_access_parking => 'חניה';

  @override
  String get diveSites_detail_altitude_elevation => 'גובה';

  @override
  String get diveSites_detail_altitude_pressure => 'לחץ';

  @override
  String get diveSites_detail_coordinatesCopied => 'הקואורדינטות הועתקו ללוח';

  @override
  String get diveSites_detail_deleteDialog_cancel => 'ביטול';

  @override
  String get diveSites_detail_deleteDialog_confirm => 'מחק';

  @override
  String get diveSites_detail_deleteDialog_content =>
      'האם אתה בטוח שברצונך למחוק אתר זה? פעולה זו אינה ניתנת לביטול.';

  @override
  String get diveSites_detail_deleteDialog_title => 'מחק אתר';

  @override
  String get diveSites_detail_deleteMenu_label => 'מחק';

  @override
  String get diveSites_detail_deleteSnackbar => 'האתר נמחק';

  @override
  String get diveSites_detail_depth_maximum => 'מקסימום';

  @override
  String get diveSites_detail_depth_minimum => 'מינימום';

  @override
  String get diveSites_detail_diveCount_one => 'צלילה אחת רשומה';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '$count צלילות רשומות';
  }

  @override
  String get diveSites_detail_diveCount_zero => 'אין עדיין צלילות רשומות';

  @override
  String get diveSites_detail_editTooltip => 'ערוך אתר';

  @override
  String get diveSites_detail_editTooltipShort => 'ערוך';

  @override
  String diveSites_detail_error_body(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get diveSites_detail_error_title => 'שגיאה';

  @override
  String get diveSites_detail_loading_title => 'טוען...';

  @override
  String get diveSites_detail_location_country => 'מדינה';

  @override
  String get diveSites_detail_location_gpsCoordinates => 'קואורדינטות GPS';

  @override
  String get diveSites_detail_location_notSet => 'לא הוגדר';

  @override
  String get diveSites_detail_location_region => 'אזור';

  @override
  String get diveSites_detail_noDepthInfo => 'אין מידע על עומק';

  @override
  String get diveSites_detail_noDescription => 'אין תיאור';

  @override
  String get diveSites_detail_noNotes => 'אין הערות';

  @override
  String get diveSites_detail_rating_notRated => 'ללא דירוג';

  @override
  String diveSites_detail_rating_value(Object rating) {
    return '$rating מתוך 5';
  }

  @override
  String get diveSites_detail_section_access => 'גישה ולוגיסטיקה';

  @override
  String get diveSites_detail_section_altitude => 'גובה';

  @override
  String get diveSites_detail_section_depthRange => 'טווח עומק';

  @override
  String get diveSites_detail_section_description => 'תיאור';

  @override
  String get diveSites_detail_section_difficultyLevel => 'רמת קושי';

  @override
  String get diveSites_detail_section_divesAtSite => 'צלילות באתר זה';

  @override
  String get diveSites_detail_section_hazards => 'סכנות ובטיחות';

  @override
  String get diveSites_detail_section_location => 'מיקום';

  @override
  String get diveSites_detail_section_notes => 'הערות';

  @override
  String get diveSites_detail_section_rating => 'דירוג';

  @override
  String diveSites_detail_semantics_copyToClipboard(Object label) {
    return 'העתק $label ללוח';
  }

  @override
  String get diveSites_detail_semantics_viewDivesAtSite =>
      'צפה בצלילות באתר זה';

  @override
  String get diveSites_detail_semantics_viewFullscreenMap =>
      'צפה במפה במסך מלא';

  @override
  String get diveSites_detail_siteNotFound_body => 'אתר זה כבר לא קיים.';

  @override
  String get diveSites_detail_siteNotFound_title => 'האתר לא נמצא';

  @override
  String get diveSites_difficulty_advanced => 'מתקדם';

  @override
  String get diveSites_difficulty_beginner => 'מתחיל';

  @override
  String get diveSites_difficulty_intermediate => 'בינוני';

  @override
  String get diveSites_difficulty_technical => 'טכני';

  @override
  String get diveSites_edit_access_accessNotes_hint =>
      'איך להגיע לאתר, נקודות כניסה/יציאה, גישה מהחוף/מסירה';

  @override
  String get diveSites_edit_access_accessNotes_label => 'הערות גישה';

  @override
  String get diveSites_edit_access_mooringNumber_hint => 'לדוגמה, מצוף #12';

  @override
  String get diveSites_edit_access_mooringNumber_label => 'מספר עגינה';

  @override
  String get diveSites_edit_access_parkingInfo_hint =>
      'זמינות חניה, עלויות, טיפים';

  @override
  String get diveSites_edit_access_parkingInfo_label => 'מידע על חניה';

  @override
  String get diveSites_edit_altitude_helperText =>
      'גובה האתר מעל פני הים (לצלילת גובה)';

  @override
  String get diveSites_edit_altitude_hint => 'לדוגמה, 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return 'גובה ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => 'גובה לא חוקי';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => 'מחק אתר';

  @override
  String get diveSites_edit_appBar_editSite => 'ערוך אתר';

  @override
  String get diveSites_edit_appBar_newSite => 'אתר חדש';

  @override
  String get diveSites_edit_appBar_save => 'שמור';

  @override
  String get diveSites_edit_button_addSite => 'הוסף אתר';

  @override
  String get diveSites_edit_button_saveChanges => 'שמור שינויים';

  @override
  String get diveSites_edit_cancel => 'ביטול';

  @override
  String get diveSites_edit_depth_helperText =>
      'מהנקודה הרדודה ביותר עד העמוקה ביותר';

  @override
  String get diveSites_edit_depth_maxHint => 'לדוגמה, 30';

  @override
  String diveSites_edit_depth_maxLabel(Object symbol) {
    return 'עומק מקסימלי ($symbol)';
  }

  @override
  String get diveSites_edit_depth_minHint => 'לדוגמה, 5';

  @override
  String diveSites_edit_depth_minLabel(Object symbol) {
    return 'עומק מינימלי ($symbol)';
  }

  @override
  String get diveSites_edit_depth_separator => 'עד';

  @override
  String get diveSites_edit_discardDialog_content =>
      'יש לך שינויים שלא נשמרו. האם אתה בטוח שברצונך לצאת?';

  @override
  String get diveSites_edit_discardDialog_discard => 'מחק';

  @override
  String get diveSites_edit_discardDialog_keepEditing => 'המשך עריכה';

  @override
  String get diveSites_edit_discardDialog_title => 'למחוק שינויים?';

  @override
  String get diveSites_edit_field_country_label => 'מדינה';

  @override
  String get diveSites_edit_field_description_hint => 'תיאור קצר של האתר';

  @override
  String get diveSites_edit_field_description_label => 'תיאור';

  @override
  String get diveSites_edit_field_notes_hint => 'מידע נוסף על האתר';

  @override
  String get diveSites_edit_field_notes_label => 'הערות כלליות';

  @override
  String get diveSites_edit_field_region_label => 'אזור';

  @override
  String get diveSites_edit_field_siteName_hint => 'לדוגמה, Blue Hole';

  @override
  String get diveSites_edit_field_siteName_label => 'שם האתר *';

  @override
  String get diveSites_edit_field_siteName_validation => 'נא להזין שם אתר';

  @override
  String get diveSites_edit_gps_gettingLocation => 'מאתר...';

  @override
  String get diveSites_edit_gps_helperText =>
      'בחר שיטת מיקום - הקואורדינטות ימלאו אוטומטית את המדינה והאזור';

  @override
  String get diveSites_edit_gps_latitude_hint => 'לדוגמה, 21.4225';

  @override
  String get diveSites_edit_gps_latitude_label => 'קו רוחב';

  @override
  String get diveSites_edit_gps_latitude_validation => 'קו רוחב לא חוקי';

  @override
  String get diveSites_edit_gps_longitude_hint => 'לדוגמה, -86.7542';

  @override
  String get diveSites_edit_gps_longitude_label => 'קו אורך';

  @override
  String get diveSites_edit_gps_longitude_validation => 'קו אורך לא חוקי';

  @override
  String get diveSites_edit_gps_pickFromMap => 'בחר מהמפה';

  @override
  String get diveSites_edit_gps_useMyLocation => 'השתמש במיקום שלי';

  @override
  String get diveSites_edit_hazards_helperText => 'רשום סכנות או שיקולי בטיחות';

  @override
  String get diveSites_edit_hazards_hint =>
      'לדוגמה, זרמים חזקים, תנועת סירות, מדוזות, אלמוגים חדים';

  @override
  String get diveSites_edit_hazards_label => 'סכנות';

  @override
  String get diveSites_edit_marineLife_addButton => 'הוסף';

  @override
  String get diveSites_edit_marineLife_empty => 'לא נוספו מינים צפויים';

  @override
  String get diveSites_edit_marineLife_helperText =>
      'מינים שאתה מצפה לראות באתר זה';

  @override
  String get diveSites_edit_rating_clear => 'נקה דירוג';

  @override
  String diveSites_edit_rating_starTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'כוכבים',
      one: 'כוכב',
    );
    return '$count $_temp0';
  }

  @override
  String get diveSites_edit_section_access => 'גישה ולוגיסטיקה';

  @override
  String get diveSites_edit_section_altitude => 'גובה';

  @override
  String get diveSites_edit_section_depthRange => 'טווח עומק';

  @override
  String get diveSites_edit_section_difficultyLevel => 'רמת קושי';

  @override
  String get diveSites_edit_section_expectedMarineLife => 'חיים ימיים צפויים';

  @override
  String get diveSites_edit_section_gpsCoordinates => 'קואורדינטות GPS';

  @override
  String get diveSites_edit_section_hazards => 'סכנות ובטיחות';

  @override
  String get diveSites_edit_section_rating => 'דירוג';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return 'שגיאה במחיקת אתר: $error';
  }

  @override
  String diveSites_edit_snackbar_errorSaving(Object error) {
    return 'שגיאה בשמירת אתר: $error';
  }

  @override
  String get diveSites_edit_snackbar_locationCaptured => 'המיקום נקלט';

  @override
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'המיקום נקלט (${accuracy}m)';
  }

  @override
  String get diveSites_edit_snackbar_locationSelectedFromMap =>
      'המיקום נבחר מהמפה';

  @override
  String get diveSites_edit_snackbar_locationSettings => 'הגדרות';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      'לא ניתן לקבל מיקום. שירותי המיקום עשויים שלא להיות זמינים.';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      'לא ניתן לקבל מיקום. אנא בדוק הרשאות.';

  @override
  String get diveSites_edit_snackbar_siteAdded => 'האתר נוסף';

  @override
  String get diveSites_edit_snackbar_siteUpdated => 'האתר עודכן';

  @override
  String get diveSites_fab_label => 'הוסף אתר';

  @override
  String get diveSites_fab_tooltip => 'הוסף אתר צלילה חדש';

  @override
  String get diveSites_filter_apply => 'החל מסננים';

  @override
  String get diveSites_filter_cancel => 'ביטול';

  @override
  String get diveSites_filter_clearAll => 'נקה הכל';

  @override
  String get diveSites_filter_country_hint => 'לדוגמה, תאילנד';

  @override
  String get diveSites_filter_country_label => 'מדינה';

  @override
  String get diveSites_filter_depth_max_label => 'מקסימום';

  @override
  String get diveSites_filter_depth_min_label => 'מינימום';

  @override
  String get diveSites_filter_depth_separator => 'עד';

  @override
  String get diveSites_filter_difficulty_any => 'כלשהו';

  @override
  String get diveSites_filter_option_hasCoordinates_subtitle =>
      'הצג רק אתרים עם מיקום GPS';

  @override
  String get diveSites_filter_option_hasCoordinates_title => 'יש קואורדינטות';

  @override
  String get diveSites_filter_option_hasDives_subtitle =>
      'הצג רק אתרים עם צלילות רשומות';

  @override
  String get diveSites_filter_option_hasDives_title => 'יש צלילות';

  @override
  String diveSites_filter_rating_starsPlus(Object count) {
    return '$count+ כוכבים';
  }

  @override
  String get diveSites_filter_region_hint => 'לדוגמה, פוקט';

  @override
  String get diveSites_filter_region_label => 'אזור';

  @override
  String get diveSites_filter_section_depthRange => 'טווח עומק מקסימלי';

  @override
  String get diveSites_filter_section_difficulty => 'רמת קושי';

  @override
  String get diveSites_filter_section_location => 'מיקום';

  @override
  String get diveSites_filter_section_minRating => 'דירוג מינימלי';

  @override
  String get diveSites_filter_section_options => 'אפשרויות';

  @override
  String get diveSites_filter_title => 'סנן אתרים';

  @override
  String get diveSites_import_appBar_title => 'ייבא אתר צלילה';

  @override
  String get diveSites_import_badge_imported => 'יובא';

  @override
  String get diveSites_import_badge_saved => 'נשמר';

  @override
  String get diveSites_import_button_import => 'ייבא';

  @override
  String get diveSites_import_detail_alreadyImported => 'כבר יובא';

  @override
  String get diveSites_import_detail_importToMySites => 'ייבא לאתרים שלי';

  @override
  String diveSites_import_detail_source(Object source) {
    return 'מקור: $source';
  }

  @override
  String get diveSites_import_empty_description =>
      'חפש אתרי צלילה ממאגר הנתונים שלנו\nשל יעדי צלילה פופולריים ברחבי העולם.';

  @override
  String get diveSites_import_empty_hint =>
      'נסה לחפש לפי שם אתר, מדינה או אזור.';

  @override
  String get diveSites_import_empty_title => 'חפש אתרי צלילה';

  @override
  String get diveSites_import_error_retry => 'נסה שוב';

  @override
  String get diveSites_import_error_title => 'שגיאת חיפוש';

  @override
  String get diveSites_import_error_unknown => 'שגיאה לא ידועה';

  @override
  String get diveSites_import_externalSite_locationUnknown => 'מיקום לא ידוע';

  @override
  String get diveSites_import_label_gps => 'GPS';

  @override
  String get diveSites_import_localSite_locationNotSet => 'מיקום לא הוגדר';

  @override
  String diveSites_import_noResults_description(Object query) {
    return 'לא נמצאו אתרי צלילה עבור \"$query\".\nנסה מונח חיפוש אחר.';
  }

  @override
  String get diveSites_import_noResults_title => 'אין תוצאות';

  @override
  String get diveSites_import_quickSearch_caribbean => 'קריביים';

  @override
  String get diveSites_import_quickSearch_indonesia => 'אינדונזיה';

  @override
  String get diveSites_import_quickSearch_maldives => 'מלדיביים';

  @override
  String get diveSites_import_quickSearch_philippines => 'פיליפינים';

  @override
  String get diveSites_import_quickSearch_redSea => 'ים סוף';

  @override
  String get diveSites_import_quickSearch_thailand => 'תאילנד';

  @override
  String get diveSites_import_search_clearTooltip => 'נקה חיפוש';

  @override
  String get diveSites_import_search_hint =>
      'חפש אתרי צלילה (לדוגמה, \"Blue Hole\", \"תאילנד\")';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return 'ייבא ממאגר נתונים ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return 'האתרים שלי ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return 'צפה בפרטים עבור $name';
  }

  @override
  String diveSites_import_semantics_viewSavedSite(Object name) {
    return 'צפה באתר שמור $name';
  }

  @override
  String get diveSites_import_snackbar_failed => 'ייבוא האתר נכשל';

  @override
  String diveSites_import_snackbar_imported(Object name) {
    return 'יובא \"$name\"';
  }

  @override
  String get diveSites_import_snackbar_viewAction => 'צפה';

  @override
  String get diveSites_list_activeFilter_clear => 'נקה';

  @override
  String diveSites_list_activeFilter_country(Object country) {
    return 'מדינה: $country';
  }

  @override
  String diveSites_list_activeFilter_depthRangeBoth(Object min, Object max) {
    return '$min-$maxמ\'';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'עד $maxמ\'';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '$minמ\'+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => 'יש קואורדינטות';

  @override
  String get diveSites_list_activeFilter_hasDives => 'יש צלילות';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return 'אזור: $region';
  }

  @override
  String get diveSites_list_appBar_title => 'אתרי צלילה';

  @override
  String get diveSites_list_bulkDelete_cancel => 'ביטול';

  @override
  String get diveSites_list_bulkDelete_confirm => 'מחק';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'אתרים',
      one: 'אתר',
    );
    return 'האם אתה בטוח שברצונך למחוק $count $_temp0? ניתן לבטל פעולה זו תוך 5 שניות.';
  }

  @override
  String get diveSites_list_bulkDelete_restored => 'האתרים שוחזרו';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'אתרים',
      one: 'אתר',
    );
    return 'נמחקו $count $_temp0';
  }

  @override
  String get diveSites_list_bulkDelete_title => 'מחק אתרים';

  @override
  String get diveSites_list_bulkDelete_undo => 'בטל';

  @override
  String get diveSites_list_emptyFiltered_clearAll => 'נקה את כל המסננים';

  @override
  String get diveSites_list_emptyFiltered_subtitle =>
      'נסה לשנות או לנקות את המסננים';

  @override
  String get diveSites_list_emptyFiltered_title => 'אין אתרים התואמים למסננים';

  @override
  String get diveSites_list_empty_addFirstSite => 'הוסף את האתר הראשון שלך';

  @override
  String get diveSites_list_empty_import => 'ייבא';

  @override
  String get diveSites_list_empty_subtitle =>
      'הוסף אתרי צלילה כדי לעקוב אחר המיקומים האהובים עליך';

  @override
  String get diveSites_list_empty_title => 'אין עדיין אתרי צלילה';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return 'שגיאה בטעינת אתרים: $error';
  }

  @override
  String get diveSites_list_error_retry => 'נסה שוב';

  @override
  String get diveSites_list_menu_import => 'ייבא';

  @override
  String get diveSites_list_search_backTooltip => 'חזרה';

  @override
  String get diveSites_list_search_clearTooltip => 'נקה חיפוש';

  @override
  String get diveSites_list_search_emptyHint => 'חפש לפי שם אתר, מדינה או אזור';

  @override
  String diveSites_list_search_error(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return 'לא נמצאו אתרים עבור \"$query\"';
  }

  @override
  String get diveSites_list_search_placeholder => 'חפש אתרים...';

  @override
  String get diveSites_list_selection_closeTooltip => 'סגור בחירה';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count נבחרו';
  }

  @override
  String get diveSites_list_selection_deleteTooltip => 'מחק נבחרים';

  @override
  String get diveSites_list_selection_deselectAllTooltip => 'בטל בחירת הכל';

  @override
  String get diveSites_list_selection_selectAllTooltip => 'בחר הכל';

  @override
  String get diveSites_list_sort_title => 'מיין אתרים';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות',
      one: 'צלילה אחת',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return 'אתר צלילה: $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => 'סנן אתרים';

  @override
  String get diveSites_list_tooltip_mapView => 'תצוגת מפה';

  @override
  String get diveSites_list_tooltip_searchSites => 'חפש אתרים';

  @override
  String get diveSites_list_tooltip_sort => 'מיין';

  @override
  String get diveSites_locationPicker_appBar_title => 'בחר מיקום';

  @override
  String get diveSites_locationPicker_confirmButton => 'אשר';

  @override
  String get diveSites_locationPicker_confirmTooltip => 'אשר מיקום נבחר';

  @override
  String get diveSites_locationPicker_fab_tooltip => 'השתמש במיקום שלי';

  @override
  String get diveSites_locationPicker_instruction_locationSelected =>
      'המיקום נבחר';

  @override
  String get diveSites_locationPicker_instruction_lookingUp => 'מחפש מיקום...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect =>
      'הקש על המפה כדי לבחור מיקום';

  @override
  String get diveSites_locationPicker_label_latitude => 'קו רוחב';

  @override
  String get diveSites_locationPicker_label_longitude => 'קו אורך';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return 'קואורדינטות נבחרות: קו רוחב $latitude, קו אורך $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp => 'מחפש מיקום';

  @override
  String get diveSites_locationPicker_semantics_map =>
      'מפה אינטראקטיבית לבחירת מיקום אתר צלילה. הקש על המפה כדי לבחור מיקום.';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return 'שגיאה בטעינת אתרי צלילה: $error';
  }

  @override
  String get diveSites_map_appBar_title => 'אתרי צלילה';

  @override
  String get diveSites_map_empty_description =>
      'הוסף קואורדינטות לאתרי הצלילה שלך כדי לראות אותם על המפה';

  @override
  String get diveSites_map_empty_title => 'אין אתרים עם קואורדינטות';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return 'שגיאה בטעינת אתרים: $error';
  }

  @override
  String get diveSites_map_error_retry => 'נסה שוב';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות',
      one: 'צלילה אחת',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return 'אתר צלילה: $name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => 'התאם לכל האתרים';

  @override
  String get diveSites_map_tooltip_listView => 'תצוגת רשימה';

  @override
  String get diveSites_summary_action_addSite => 'הוסף אתר';

  @override
  String get diveSites_summary_action_import => 'ייבא';

  @override
  String get diveSites_summary_action_viewMap => 'הצג מפה';

  @override
  String diveSites_summary_countriesMore(Object count) {
    return '+ $count נוספים';
  }

  @override
  String get diveSites_summary_header_subtitle =>
      'בחר אתר מהרשימה כדי לצפות בפרטים';

  @override
  String get diveSites_summary_header_title => 'אתרי צלילה';

  @override
  String get diveSites_summary_section_countriesRegions => 'מדינות ואזורים';

  @override
  String get diveSites_summary_section_mostDived => 'הנצללים ביותר';

  @override
  String get diveSites_summary_section_overview => 'סקירה כללית';

  @override
  String get diveSites_summary_section_quickActions => 'פעולות מהירות';

  @override
  String get diveSites_summary_section_topRated => 'בעלי הדירוג הגבוה ביותר';

  @override
  String get diveSites_summary_stat_avgRating => 'דירוג ממוצע';

  @override
  String get diveSites_summary_stat_totalDives => 'סה\"כ צלילות';

  @override
  String get diveSites_summary_stat_totalSites => 'סה\"כ אתרים';

  @override
  String get diveSites_summary_stat_withGps => 'עם GPS';

  @override
  String get diveTypes_addDialog_addButton => 'הוסף';

  @override
  String get diveTypes_addDialog_nameHint => 'לדוגמה: חיפוש ושחזור';

  @override
  String get diveTypes_addDialog_nameLabel => 'שם סוג צלילה';

  @override
  String get diveTypes_addDialog_nameValidation => 'נא להזין שם';

  @override
  String get diveTypes_addDialog_title => 'הוסף סוג צלילה מותאם';

  @override
  String get diveTypes_addTooltip => 'הוסף סוג צלילה';

  @override
  String get diveTypes_appBar_title => 'סוגי צלילה';

  @override
  String get diveTypes_builtIn => 'מובנה';

  @override
  String get diveTypes_builtInHeader => 'סוגי צלילה מובנים';

  @override
  String get diveTypes_custom => 'מותאם';

  @override
  String get diveTypes_customHeader => 'סוגי צלילה מותאמים';

  @override
  String diveTypes_deleteDialog_content(Object name) {
    return 'האם אתה בטוח שברצונך למחוק את \"$name\"?';
  }

  @override
  String get diveTypes_deleteDialog_title => 'למחוק סוג צלילה?';

  @override
  String get diveTypes_deleteTooltip => 'מחק סוג צלילה';

  @override
  String diveTypes_snackbar_added(Object name) {
    return 'סוג צלילה נוסף: $name';
  }

  @override
  String diveTypes_snackbar_cannotDelete(Object name) {
    return 'לא ניתן למחוק את \"$name\" - הוא משמש צלילות קיימות';
  }

  @override
  String diveTypes_snackbar_deleted(Object name) {
    return 'נמחק \"$name\"';
  }

  @override
  String diveTypes_snackbar_errorAdding(Object error) {
    return 'שגיאה בהוספת סוג צלילה: $error';
  }

  @override
  String diveTypes_snackbar_errorDeleting(Object error) {
    return 'שגיאה במחיקת סוג צלילה: $error';
  }

  @override
  String get divers_detail_activeDiver => 'צולל פעיל';

  @override
  String get divers_detail_allergiesLabel => 'אלרגיות';

  @override
  String get divers_detail_appBarTitle => 'צולל';

  @override
  String get divers_detail_bloodTypeLabel => 'סוג דם';

  @override
  String get divers_detail_bottomTimeLabel => 'זמן תחתית';

  @override
  String get divers_detail_cancelButton => 'ביטול';

  @override
  String get divers_detail_contactTitle => 'איש קשר';

  @override
  String get divers_detail_defaultLabel => 'ברירת מחדל';

  @override
  String get divers_detail_deleteButton => 'מחיקה';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'האם אתה בטוח שברצונך למחוק את $name? כל יומני הצלילה המשויכים יבוטלו.';
  }

  @override
  String get divers_detail_deleteDialogTitle => 'למחוק צולל?';

  @override
  String divers_detail_deleteError(Object error) {
    return 'המחיקה נכשלה: $error';
  }

  @override
  String get divers_detail_deleteMenuItem => 'מחיקה';

  @override
  String get divers_detail_deletedSnackbar => 'הצולל נמחק';

  @override
  String get divers_detail_diveInsuranceTitle => 'ביטוח צלילה';

  @override
  String get divers_detail_diveStatisticsTitle => 'סטטיסטיקות צלילה';

  @override
  String get divers_detail_editTooltip => 'ערוך צולל';

  @override
  String get divers_detail_emergencyContactTitle => 'איש קשר לחירום';

  @override
  String divers_detail_errorPrefix(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get divers_detail_expiredBadge => 'פג תוקף';

  @override
  String get divers_detail_expiresLabel => 'תפוגה';

  @override
  String get divers_detail_medicalInfoTitle => 'מידע רפואי';

  @override
  String get divers_detail_medicalNotesLabel => 'הערות';

  @override
  String get divers_detail_notFound => 'הצולל לא נמצא';

  @override
  String get divers_detail_notesTitle => 'הערות';

  @override
  String get divers_detail_policyNumberLabel => 'מספר פוליסה';

  @override
  String get divers_detail_providerLabel => 'ספק';

  @override
  String get divers_detail_setAsDefault => 'הגדר כברירת מחדל';

  @override
  String divers_detail_setAsDefaultSnackbar(Object name) {
    return '$name הוגדר כצולל ברירת מחדל';
  }

  @override
  String get divers_detail_switchToTooltip => 'עבור לצולל זה';

  @override
  String divers_detail_switchedTo(Object name) {
    return 'עבר אל $name';
  }

  @override
  String get divers_detail_totalDivesLabel => 'סה\"כ צלילות';

  @override
  String get divers_detail_unableToLoadStats => 'לא ניתן לטעון סטטיסטיקות';

  @override
  String get divers_edit_addButton => 'הוסף צולל';

  @override
  String get divers_edit_addTitle => 'הוסף צולל';

  @override
  String get divers_edit_allergiesHint => 'לדוגמה, פניצילין, פירות ים';

  @override
  String get divers_edit_allergiesLabel => 'אלרגיות';

  @override
  String get divers_edit_bloodTypeHint => 'לדוגמה, O+, A-, B+';

  @override
  String get divers_edit_bloodTypeLabel => 'סוג דם';

  @override
  String get divers_edit_cancelButton => 'ביטול';

  @override
  String get divers_edit_clearInsuranceExpiryTooltip => 'נקה תאריך תפוגת ביטוח';

  @override
  String get divers_edit_clearMedicalClearanceTooltip =>
      'נקה תאריך אישור רפואי';

  @override
  String get divers_edit_contactNameLabel => 'שם איש קשר';

  @override
  String get divers_edit_contactPhoneLabel => 'טלפון איש קשר';

  @override
  String get divers_edit_discardButton => 'מחיקה';

  @override
  String get divers_edit_discardDialogContent =>
      'יש לך שינויים שלא נשמרו. האם אתה בטוח שברצונך לבטל אותם?';

  @override
  String get divers_edit_discardDialogTitle => 'לבטל שינויים?';

  @override
  String get divers_edit_diverAdded => 'הצולל נוסף';

  @override
  String get divers_edit_diverUpdated => 'הצולל עודכן';

  @override
  String get divers_edit_editTitle => 'ערוך צולל';

  @override
  String get divers_edit_emailError => 'הזן כתובת דוא\"ל תקינה';

  @override
  String get divers_edit_emailLabel => 'דוא\"ל';

  @override
  String get divers_edit_emergencyContactsSection => 'אנשי קשר לחירום';

  @override
  String divers_edit_errorLoading(Object error) {
    return 'שגיאה בטעינת צולל: $error';
  }

  @override
  String divers_edit_errorSaving(Object error) {
    return 'שגיאה בשמירת צולל: $error';
  }

  @override
  String get divers_edit_expiryDateNotSet => 'לא הוגדר';

  @override
  String get divers_edit_expiryDateTitle => 'תאריך תפוגה';

  @override
  String get divers_edit_insuranceProviderHint => 'לדוגמה, DAN, DiveAssure';

  @override
  String get divers_edit_insuranceProviderLabel => 'ספק ביטוח';

  @override
  String get divers_edit_insuranceSection => 'ביטוח צלילה';

  @override
  String get divers_edit_keepEditingButton => 'המשך עריכה';

  @override
  String get divers_edit_medicalClearanceExpired => 'פג תוקף';

  @override
  String get divers_edit_medicalClearanceExpiringSoon => 'פג בקרוב';

  @override
  String get divers_edit_medicalClearanceNotSet => 'לא הוגדר';

  @override
  String get divers_edit_medicalClearanceTitle => 'תפוגת אישור רפואי';

  @override
  String get divers_edit_medicalInfoSection => 'מידע רפואי';

  @override
  String get divers_edit_medicalNotesLabel => 'הערות רפואיות';

  @override
  String get divers_edit_medicationsHint => 'לדוגמה, אספירין יומי, EpiPen';

  @override
  String get divers_edit_medicationsLabel => 'תרופות';

  @override
  String get divers_edit_nameError => 'שם הוא שדה חובה';

  @override
  String get divers_edit_nameLabel => 'שם *';

  @override
  String get divers_edit_notesLabel => 'הערות';

  @override
  String get divers_edit_notesSection => 'הערות';

  @override
  String get divers_edit_personalInfoSection => 'מידע אישי';

  @override
  String get divers_edit_phoneLabel => 'טלפון';

  @override
  String get divers_edit_policyNumberLabel => 'מספר פוליסה';

  @override
  String get divers_edit_primaryContactTitle => 'איש קשר ראשי';

  @override
  String get divers_edit_relationshipHint => 'לדוגמה, בן/בת זוג, הורה, חבר/ה';

  @override
  String get divers_edit_relationshipLabel => 'קרבה';

  @override
  String get divers_edit_saveButton => 'שמירה';

  @override
  String get divers_edit_secondaryContactTitle => 'איש קשר משני';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip =>
      'בחר תאריך תפוגת ביטוח';

  @override
  String get divers_edit_selectMedicalClearanceTooltip =>
      'בחר תאריך אישור רפואי';

  @override
  String get divers_edit_updateButton => 'עדכן צולל';

  @override
  String get divers_list_activeBadge => 'פעיל';

  @override
  String get divers_list_addDiverButton => 'הוסף צולל';

  @override
  String get divers_list_addDiverTooltip => 'הוסף פרופיל צולל חדש';

  @override
  String get divers_list_appBarTitle => 'פרופילי צוללים';

  @override
  String get divers_list_compactTitle => 'צוללים';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount צלילות$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle =>
      'הוסף פרופילי צוללים כדי לעקוב אחר יומני צלילה למספר אנשים';

  @override
  String get divers_list_emptyTitle => 'עדיין אין צוללים';

  @override
  String divers_list_errorLoading(Object error) {
    return 'שגיאה בטעינת צוללים: $error';
  }

  @override
  String get divers_list_errorLoadingStats => 'שגיאה בטעינת סטטיסטיקות';

  @override
  String get divers_list_loadingStats => 'טוען...';

  @override
  String get divers_list_retryButton => 'נסה שוב';

  @override
  String divers_list_viewDiverLabel(Object name) {
    return 'הצג צולל $name';
  }

  @override
  String get divers_summary_activeDiverTitle => 'צולל פעיל';

  @override
  String get divers_summary_otherDiversTitle => 'צוללים אחרים';

  @override
  String get divers_summary_overviewTitle => 'סקירה כללית';

  @override
  String get divers_summary_quickActionsTitle => 'פעולות מהירות';

  @override
  String get divers_summary_subtitle => 'בחר צולל מהרשימה כדי לצפות בפרטים';

  @override
  String get divers_summary_title => 'פרופילי צוללים';

  @override
  String get divers_summary_totalDiversLabel => 'סה\"כ צוללים';

  @override
  String get enum_altitudeGroup_extreme => 'גובה קיצוני';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => 'קבוצת גובה 1';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => 'קבוצת גובה 2';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => 'קבוצת גובה 3';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => 'גובה פני הים';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => 'סכנה';

  @override
  String get enum_ascentRate_safe => 'בטוח';

  @override
  String get enum_ascentRate_warning => 'אזהרה';

  @override
  String get enum_buddyRole_buddy => 'שותף';

  @override
  String get enum_buddyRole_diveGuide => 'מדריך צלילה';

  @override
  String get enum_buddyRole_diveMaster => 'דייבמאסטר';

  @override
  String get enum_buddyRole_instructor => 'מדריך';

  @override
  String get enum_buddyRole_solo => 'יחיד';

  @override
  String get enum_buddyRole_student => 'תלמיד';

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
  String get enum_certificationAgency_other => 'אחר';

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
  String get enum_certificationLevel_advancedNitrox => 'ניטרוקס מתקדם';

  @override
  String get enum_certificationLevel_advancedOpenWater => 'מים פתוחים מתקדם';

  @override
  String get enum_certificationLevel_cave => 'מערה';

  @override
  String get enum_certificationLevel_cavern => 'קברן';

  @override
  String get enum_certificationLevel_courseDirector => 'מנהל קורס';

  @override
  String get enum_certificationLevel_decompression => 'דקומפרסיה';

  @override
  String get enum_certificationLevel_diveMaster => 'דייבמאסטר';

  @override
  String get enum_certificationLevel_instructor => 'מדריך';

  @override
  String get enum_certificationLevel_masterInstructor => 'מדריך בכיר';

  @override
  String get enum_certificationLevel_nitrox => 'ניטרוקס';

  @override
  String get enum_certificationLevel_openWater => 'מים פתוחים';

  @override
  String get enum_certificationLevel_other => 'אחר';

  @override
  String get enum_certificationLevel_rebreather => 'ריברידר';

  @override
  String get enum_certificationLevel_rescue => 'צולל חילוץ';

  @override
  String get enum_certificationLevel_sidemount => 'סיידמאונט';

  @override
  String get enum_certificationLevel_techDiver => 'צולל טכני';

  @override
  String get enum_certificationLevel_trimix => 'טרימיקס';

  @override
  String get enum_certificationLevel_wreck => 'ספינה טרופה';

  @override
  String get enum_currentDirection_east => 'מזרח';

  @override
  String get enum_currentDirection_none => 'ללא';

  @override
  String get enum_currentDirection_north => 'צפון';

  @override
  String get enum_currentDirection_northEast => 'צפון-מזרח';

  @override
  String get enum_currentDirection_northWest => 'צפון-מערב';

  @override
  String get enum_currentDirection_south => 'דרום';

  @override
  String get enum_currentDirection_southEast => 'דרום-מזרח';

  @override
  String get enum_currentDirection_southWest => 'דרום-מערב';

  @override
  String get enum_currentDirection_variable => 'משתנה';

  @override
  String get enum_currentDirection_west => 'מערב';

  @override
  String get enum_currentStrength_light => 'קל';

  @override
  String get enum_currentStrength_moderate => 'מתון';

  @override
  String get enum_currentStrength_none => 'ללא';

  @override
  String get enum_currentStrength_strong => 'חזק';

  @override
  String get enum_diveMode_ccr => 'ריברידר מעגל סגור';

  @override
  String get enum_diveMode_oc => 'מעגל פתוח';

  @override
  String get enum_diveMode_scr => 'ריברידר חצי סגור';

  @override
  String get enum_diveType_altitude => 'גובה';

  @override
  String get enum_diveType_boat => 'סירה';

  @override
  String get enum_diveType_cave => 'מערה';

  @override
  String get enum_diveType_deep => 'עמוקה';

  @override
  String get enum_diveType_drift => 'סחף';

  @override
  String get enum_diveType_freedive => 'צלילה חופשית';

  @override
  String get enum_diveType_ice => 'קרח';

  @override
  String get enum_diveType_liveaboard => 'ספינת צלילה';

  @override
  String get enum_diveType_night => 'לילה';

  @override
  String get enum_diveType_recreational => 'פנאי';

  @override
  String get enum_diveType_shore => 'חוף';

  @override
  String get enum_diveType_technical => 'טכנית';

  @override
  String get enum_diveType_training => 'אימון';

  @override
  String get enum_diveType_wreck => 'ספינה טרופה';

  @override
  String get enum_entryMethod_backRoll => 'גלגול אחורה';

  @override
  String get enum_entryMethod_boat => 'כניסה מסירה';

  @override
  String get enum_entryMethod_giantStride => 'צעד ענק';

  @override
  String get enum_entryMethod_jetty => 'מזח/רציף';

  @override
  String get enum_entryMethod_ladder => 'סולם';

  @override
  String get enum_entryMethod_other => 'אחר';

  @override
  String get enum_entryMethod_platform => 'פלטפורמה';

  @override
  String get enum_entryMethod_seatedEntry => 'כניסה בישיבה';

  @override
  String get enum_entryMethod_shore => 'כניסה מהחוף';

  @override
  String get enum_equipmentStatus_active => 'פעיל';

  @override
  String get enum_equipmentStatus_inService => 'בתחזוקה';

  @override
  String get enum_equipmentStatus_loaned => 'מושאל';

  @override
  String get enum_equipmentStatus_lost => 'אבוד';

  @override
  String get enum_equipmentStatus_needsService => 'דורש תחזוקה';

  @override
  String get enum_equipmentStatus_retired => 'הוצא משימוש';

  @override
  String get enum_equipmentType_bcd => 'אפוד ציפה';

  @override
  String get enum_equipmentType_boots => 'נעלי צלילה';

  @override
  String get enum_equipmentType_camera => 'מצלמה';

  @override
  String get enum_equipmentType_computer => 'מחשב צלילה';

  @override
  String get enum_equipmentType_drysuit => 'חליפה יבשה';

  @override
  String get enum_equipmentType_fins => 'סנפירים';

  @override
  String get enum_equipmentType_gloves => 'כפפות';

  @override
  String get enum_equipmentType_hood => 'כיסוי ראש';

  @override
  String get enum_equipmentType_knife => 'סכין';

  @override
  String get enum_equipmentType_light => 'פנס';

  @override
  String get enum_equipmentType_mask => 'מסכה';

  @override
  String get enum_equipmentType_other => 'אחר';

  @override
  String get enum_equipmentType_reel => 'סליל';

  @override
  String get enum_equipmentType_regulator => 'רגולטור';

  @override
  String get enum_equipmentType_smb => 'SMB';

  @override
  String get enum_equipmentType_tank => 'בלון';

  @override
  String get enum_equipmentType_weights => 'משקולות';

  @override
  String get enum_equipmentType_wetsuit => 'חליפת צלילה';

  @override
  String get enum_eventSeverity_alert => 'התראה';

  @override
  String get enum_eventSeverity_info => 'מידע';

  @override
  String get enum_eventSeverity_warning => 'אזהרה';

  @override
  String get enum_pdfPageSize_a4 => 'A4';

  @override
  String get enum_pdfPageSize_a4_description => '210 x 297 mm';

  @override
  String get enum_pdfPageSize_letter => 'Letter';

  @override
  String get enum_pdfPageSize_letter_description => '8.5 x 11 in';

  @override
  String get enum_pdfTemplate_detailed => 'מפורט';

  @override
  String get enum_pdfTemplate_detailed_description =>
      'מידע מלא על הצלילה עם הערות ודירוגים';

  @override
  String get enum_pdfTemplate_nauiStyle => 'סגנון NAUI';

  @override
  String get enum_pdfTemplate_nauiStyle_description =>
      'פריסה בהתאם לפורמט יומן NAUI';

  @override
  String get enum_pdfTemplate_padiStyle => 'סגנון PADI';

  @override
  String get enum_pdfTemplate_padiStyle_description =>
      'פריסה בהתאם לפורמט יומן PADI';

  @override
  String get enum_pdfTemplate_professional => 'מקצועי';

  @override
  String get enum_pdfTemplate_professional_description =>
      'אזורי חתימה וחותמת לאימות';

  @override
  String get enum_pdfTemplate_simple => 'פשוט';

  @override
  String get enum_pdfTemplate_simple_description =>
      'פורמט טבלה קומפקטי, צלילות רבות בעמוד';

  @override
  String get enum_profileEvent_alert => 'התראה';

  @override
  String get enum_profileEvent_ascentRateCritical => 'קצב עלייה קריטי';

  @override
  String get enum_profileEvent_ascentRateWarning => 'אזהרת קצב עלייה';

  @override
  String get enum_profileEvent_ascentStart => 'תחילת עלייה';

  @override
  String get enum_profileEvent_bookmark => 'סימנייה';

  @override
  String get enum_profileEvent_cnsCritical => 'CNS קריטי';

  @override
  String get enum_profileEvent_cnsWarning => 'אזהרת CNS';

  @override
  String get enum_profileEvent_decoStopEnd => 'סוף עצירת דקו';

  @override
  String get enum_profileEvent_decoStopStart => 'תחילת עצירת דקו';

  @override
  String get enum_profileEvent_decoViolation => 'הפרת דקומפרסיה';

  @override
  String get enum_profileEvent_descentEnd => 'סוף ירידה';

  @override
  String get enum_profileEvent_descentStart => 'תחילת ירידה';

  @override
  String get enum_profileEvent_gasSwitch => 'החלפת גז';

  @override
  String get enum_profileEvent_lowGas => 'אזהרת גז נמוך';

  @override
  String get enum_profileEvent_maxDepth => 'עומק מרבי';

  @override
  String get enum_profileEvent_missedStop => 'עצירת דקו שהוחמצה';

  @override
  String get enum_profileEvent_note => 'הערה';

  @override
  String get enum_profileEvent_ppO2High => 'ppO2 גבוה';

  @override
  String get enum_profileEvent_ppO2Low => 'ppO2 נמוך';

  @override
  String get enum_profileEvent_safetyStopEnd => 'סוף עצירת ביטחון';

  @override
  String get enum_profileEvent_safetyStopStart => 'תחילת עצירת ביטחון';

  @override
  String get enum_profileEvent_setpointChange => 'שינוי נקודת כוונון';

  @override
  String get enum_profileMetricCategory_decompression => 'דקומפרסיה';

  @override
  String get enum_profileMetricCategory_gasAnalysis => 'ניתוח גזים';

  @override
  String get enum_profileMetricCategory_gradientFactor => 'מקדמי שיפוע';

  @override
  String get enum_profileMetricCategory_other => 'אחר';

  @override
  String get enum_profileMetricCategory_primary => 'מדדים ראשיים';

  @override
  String get enum_profileMetric_gasDensity => 'צפיפות גז';

  @override
  String get enum_profileMetric_gasDensity_short => 'צפיפות';

  @override
  String get enum_profileMetric_gf => 'GF%';

  @override
  String get enum_profileMetric_gf_short => 'GF%';

  @override
  String get enum_profileMetric_heartRate => 'קצב לב';

  @override
  String get enum_profileMetric_heartRate_short => 'קצב לב';

  @override
  String get enum_profileMetric_meanDepth => 'עומק ממוצע';

  @override
  String get enum_profileMetric_meanDepth_short => 'ממוצע';

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
  String get enum_profileMetric_pressure => 'לחץ';

  @override
  String get enum_profileMetric_pressure_short => 'לחץ';

  @override
  String get enum_profileMetric_sacRate => 'קצב SAC';

  @override
  String get enum_profileMetric_sacRate_short => 'SAC';

  @override
  String get enum_profileMetric_surfaceGf => 'GF פני השטח';

  @override
  String get enum_profileMetric_surfaceGf_short => 'SrfGF';

  @override
  String get enum_profileMetric_temperature => 'טמפרטורה';

  @override
  String get enum_profileMetric_temperature_short => 'טמפ\'';

  @override
  String get enum_profileMetric_tts => 'TTS';

  @override
  String get enum_profileMetric_tts_short => 'TTS';

  @override
  String get enum_scrType_cmf => 'זרימת מסה קבועה';

  @override
  String get enum_scrType_cmf_short => 'CMF';

  @override
  String get enum_scrType_escr => 'בקרה אלקטרונית';

  @override
  String get enum_scrType_escr_short => 'ESCR';

  @override
  String get enum_scrType_pascr => 'הוספה פסיבית';

  @override
  String get enum_scrType_pascr_short => 'PASCR';

  @override
  String get enum_serviceType_annual => 'טיפול שנתי';

  @override
  String get enum_serviceType_calibration => 'כיול';

  @override
  String get enum_serviceType_cleaning => 'ניקוי';

  @override
  String get enum_serviceType_inspection => 'בדיקה';

  @override
  String get enum_serviceType_other => 'אחר';

  @override
  String get enum_serviceType_overhaul => 'שיפוץ כללי';

  @override
  String get enum_serviceType_recall => 'ריקול/בטיחות';

  @override
  String get enum_serviceType_repair => 'תיקון';

  @override
  String get enum_serviceType_replacement => 'החלפת חלק';

  @override
  String get enum_serviceType_warranty => 'שירות אחריות';

  @override
  String get enum_sortDirection_ascending => 'עולה';

  @override
  String get enum_sortDirection_descending => 'יורד';

  @override
  String get enum_sortField_agency => 'ארגון';

  @override
  String get enum_sortField_date => 'תאריך';

  @override
  String get enum_sortField_dateIssued => 'תאריך הנפקה';

  @override
  String get enum_sortField_difficulty => 'רמת קושי';

  @override
  String get enum_sortField_diveCount => 'מספר צלילות';

  @override
  String get enum_sortField_diveNumber => 'מספר צלילה';

  @override
  String get enum_sortField_duration => 'משך';

  @override
  String get enum_sortField_endDate => 'תאריך סיום';

  @override
  String get enum_sortField_lastServiceDate => 'טיפול אחרון';

  @override
  String get enum_sortField_maxDepth => 'עומק מרבי';

  @override
  String get enum_sortField_name => 'שם';

  @override
  String get enum_sortField_purchaseDate => 'תאריך רכישה';

  @override
  String get enum_sortField_rating => 'דירוג';

  @override
  String get enum_sortField_site => 'אתר';

  @override
  String get enum_sortField_startDate => 'תאריך התחלה';

  @override
  String get enum_sortField_status => 'סטטוס';

  @override
  String get enum_sortField_type => 'סוג';

  @override
  String get enum_speciesCategory_coral => 'אלמוג';

  @override
  String get enum_speciesCategory_fish => 'דג';

  @override
  String get enum_speciesCategory_invertebrate => 'חסר חוליות';

  @override
  String get enum_speciesCategory_mammal => 'יונק';

  @override
  String get enum_speciesCategory_other => 'אחר';

  @override
  String get enum_speciesCategory_plant => 'צמח/אצה';

  @override
  String get enum_speciesCategory_ray => 'טריגון';

  @override
  String get enum_speciesCategory_shark => 'כריש';

  @override
  String get enum_speciesCategory_turtle => 'צב ים';

  @override
  String get enum_tankMaterial_aluminum => 'אלומיניום';

  @override
  String get enum_tankMaterial_carbonFiber => 'סיב פחמן';

  @override
  String get enum_tankMaterial_steel => 'פלדה';

  @override
  String get enum_tankRole_backGas => 'גז ראשי';

  @override
  String get enum_tankRole_bailout => 'בלון חירום';

  @override
  String get enum_tankRole_deco => 'דקו';

  @override
  String get enum_tankRole_diluent => 'מדלל';

  @override
  String get enum_tankRole_oxygenSupply => 'אספקת O₂';

  @override
  String get enum_tankRole_pony => 'בלון פוני';

  @override
  String get enum_tankRole_sidemountLeft => 'סיידמאונט שמאל';

  @override
  String get enum_tankRole_sidemountRight => 'סיידמאונט ימין';

  @override
  String get enum_tankRole_stage => 'סטייג\'';

  @override
  String get enum_visibility_excellent => 'מצוינת (>30m / >100ft)';

  @override
  String get enum_visibility_good => 'טובה (15-30m / 50-100ft)';

  @override
  String get enum_visibility_moderate => 'בינונית (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => 'גרועה (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => 'לא ידוע';

  @override
  String get enum_waterType_brackish => 'מי מלוחן';

  @override
  String get enum_waterType_fresh => 'מים מתוקים';

  @override
  String get enum_waterType_salt => 'מי ים';

  @override
  String get enum_weightType_ankleWeights => 'משקולות קרסול';

  @override
  String get enum_weightType_backplate => 'משקולות גב';

  @override
  String get enum_weightType_belt => 'חגורת משקולות';

  @override
  String get enum_weightType_integrated => 'משקולות משולבות';

  @override
  String get enum_weightType_mixed => 'משולב/מעורב';

  @override
  String get enum_weightType_trimWeights => 'משקולות טרים';

  @override
  String get equipment_addSheet_brandHint => 'לדוגמה, Scubapro';

  @override
  String get equipment_addSheet_brandLabel => 'מותג';

  @override
  String get equipment_addSheet_closeTooltip => 'סגור';

  @override
  String get equipment_addSheet_currencyLabel => 'מטבע';

  @override
  String get equipment_addSheet_dateLabel => 'תאריך';

  @override
  String equipment_addSheet_errorSnackbar(Object error) {
    return 'שגיאה בהוספת ציוד: $error';
  }

  @override
  String get equipment_addSheet_modelHint => 'לדוגמה, MK25 EVO';

  @override
  String get equipment_addSheet_modelLabel => 'דגם';

  @override
  String get equipment_addSheet_nameHint => 'לדוגמה, הרגולטור הראשי שלי';

  @override
  String get equipment_addSheet_nameLabel => 'שם';

  @override
  String get equipment_addSheet_nameValidation => 'נא להזין שם';

  @override
  String get equipment_addSheet_notesHint => 'הערות נוספות...';

  @override
  String get equipment_addSheet_notesLabel => 'הערות';

  @override
  String get equipment_addSheet_priceLabel => 'מחיר';

  @override
  String get equipment_addSheet_purchaseInfoTitle => 'פרטי רכישה';

  @override
  String get equipment_addSheet_serialNumberLabel => 'מספר סידורי';

  @override
  String get equipment_addSheet_serviceIntervalHint => 'לדוגמה, 365 לשנתי';

  @override
  String get equipment_addSheet_serviceIntervalLabel => 'מרווח טיפול (ימים)';

  @override
  String get equipment_addSheet_sizeHint => 'לדוגמה, M, L, 42';

  @override
  String get equipment_addSheet_sizeLabel => 'מידה';

  @override
  String get equipment_addSheet_submitButton => 'הוסף ציוד';

  @override
  String get equipment_addSheet_successSnackbar => 'הציוד נוסף בהצלחה';

  @override
  String get equipment_addSheet_title => 'הוסף ציוד';

  @override
  String get equipment_addSheet_typeLabel => 'סוג';

  @override
  String get equipment_appBar_title => 'ציוד';

  @override
  String get equipment_deleteDialog_cancel => 'ביטול';

  @override
  String get equipment_deleteDialog_confirm => 'מחק';

  @override
  String get equipment_deleteDialog_content =>
      'האם אתה בטוח שברצונך למחוק ציוד זה? פעולה זו אינה ניתנת לביטול.';

  @override
  String get equipment_deleteDialog_title => 'מחק ציוד';

  @override
  String get equipment_detail_brandLabel => 'מותג';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return '$days ימים באיחור';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days ימים עד הטיפול';
  }

  @override
  String get equipment_detail_detailsTitle => 'פרטים';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count צלילות';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count צלילה';
  }

  @override
  String get equipment_detail_divesLabel => 'צלילות';

  @override
  String get equipment_detail_divesSemanticLabel =>
      'צפה בצלילות המשתמשות בציוד זה';

  @override
  String equipment_detail_durationDays(Object days) {
    return '$days ימים';
  }

  @override
  String equipment_detail_durationMonths(Object months) {
    return '$months חודשים';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralPlural(
    Object years,
    Object months,
  ) {
    return '$years שנים, $months חודשים';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralSingular(
    Object years,
    Object months,
  ) {
    return '$years שנים, $months חודש';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularPlural(
    Object years,
    Object months,
  ) {
    return '$years שנה, $months חודשים';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularSingular(
    Object years,
    Object months,
  ) {
    return '$years שנה, $months חודש';
  }

  @override
  String equipment_detail_durationYearsPlural(Object years) {
    return '$years שנים';
  }

  @override
  String equipment_detail_durationYearsSingular(Object years) {
    return '$years שנה';
  }

  @override
  String get equipment_detail_editTooltip => 'ערוך ציוד';

  @override
  String get equipment_detail_editTooltipShort => 'ערוך';

  @override
  String equipment_detail_errorMessage(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get equipment_detail_errorTitle => 'שגיאה';

  @override
  String get equipment_detail_lastServiceLabel => 'טיפול אחרון';

  @override
  String get equipment_detail_loadingTitle => 'טוען...';

  @override
  String get equipment_detail_modelLabel => 'דגם';

  @override
  String get equipment_detail_nextServiceDueLabel => 'הטיפול הבא';

  @override
  String get equipment_detail_notFoundMessage => 'פריט ציוד זה כבר לא קיים.';

  @override
  String get equipment_detail_notFoundTitle => 'הציוד לא נמצא';

  @override
  String get equipment_detail_notesTitle => 'הערות';

  @override
  String get equipment_detail_ownedForLabel => 'בבעלות';

  @override
  String get equipment_detail_purchaseDateLabel => 'תאריך רכישה';

  @override
  String get equipment_detail_purchasePriceLabel => 'מחיר רכישה';

  @override
  String get equipment_detail_retiredChip => 'הוצא משימוש';

  @override
  String get equipment_detail_serialNumberLabel => 'מספר סידורי';

  @override
  String get equipment_detail_serviceInfoTitle => 'מידע טיפול';

  @override
  String get equipment_detail_serviceIntervalLabel => 'מרווח טיפול';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days ימים';
  }

  @override
  String get equipment_detail_serviceOverdue => 'הטיפול באיחור!';

  @override
  String get equipment_detail_sizeLabel => 'מידה';

  @override
  String get equipment_detail_statusLabel => 'סטטוס';

  @override
  String equipment_detail_tripsCountPlural(Object count) {
    return '$count טיולים';
  }

  @override
  String equipment_detail_tripsCountSingular(Object count) {
    return '$count טיול';
  }

  @override
  String get equipment_detail_tripsLabel => 'טיולים';

  @override
  String get equipment_detail_tripsSemanticLabel =>
      'צפה בטיולים המשתמשים בציוד זה';

  @override
  String get equipment_edit_appBar_editTitle => 'ערוך ציוד';

  @override
  String get equipment_edit_appBar_newTitle => 'ציוד חדש';

  @override
  String get equipment_edit_appBar_saveButton => 'שמור';

  @override
  String get equipment_edit_appBar_saveTooltip => 'שמור שינויי ציוד';

  @override
  String get equipment_edit_brandLabel => 'מותג';

  @override
  String get equipment_edit_clearDate => 'נקה תאריך';

  @override
  String get equipment_edit_currencyLabel => 'מטבע';

  @override
  String get equipment_edit_disableReminders => 'השבת תזכורות';

  @override
  String get equipment_edit_disableRemindersSubtitle =>
      'כבה את כל ההתראות עבור פריט זה';

  @override
  String get equipment_edit_discardDialog_content =>
      'יש לך שינויים שלא נשמרו. האם אתה בטוח שברצונך לצאת?';

  @override
  String get equipment_edit_discardDialog_discard => 'מחק';

  @override
  String get equipment_edit_discardDialog_keepEditing => 'המשך עריכה';

  @override
  String get equipment_edit_discardDialog_title => 'למחוק שינויים?';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => 'ביטול';

  @override
  String get equipment_edit_embeddedHeader_editTitle => 'ערוך ציוד';

  @override
  String get equipment_edit_embeddedHeader_newTitle => 'ציוד חדש';

  @override
  String get equipment_edit_embeddedHeader_saveButton => 'שמור';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit =>
      'שמור שינויי ציוד';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new => 'הוסף ציוד חדש';

  @override
  String equipment_edit_errorMessage(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get equipment_edit_errorTitle => 'שגיאה';

  @override
  String get equipment_edit_lastServiceDateLabel => 'תאריך טיפול אחרון';

  @override
  String get equipment_edit_loadingTitle => 'טוען...';

  @override
  String get equipment_edit_modelLabel => 'דגם';

  @override
  String get equipment_edit_nameHint => 'לדוגמה, הרגולטור הראשי שלי';

  @override
  String get equipment_edit_nameLabel => 'שם *';

  @override
  String get equipment_edit_nameValidation => 'נא להזין שם';

  @override
  String get equipment_edit_notFoundMessage => 'פריט ציוד זה כבר לא קיים.';

  @override
  String get equipment_edit_notFoundTitle => 'הציוד לא נמצא';

  @override
  String get equipment_edit_notesHint => 'הערות נוספות על ציוד זה...';

  @override
  String get equipment_edit_notesLabel => 'הערות';

  @override
  String get equipment_edit_notificationsSubtitle =>
      'עקוף הגדרות התראה גלובליות עבור פריט זה';

  @override
  String get equipment_edit_notificationsTitle => 'התראות (אופציונלי)';

  @override
  String get equipment_edit_purchaseDateLabel => 'תאריך רכישה';

  @override
  String get equipment_edit_purchaseInfoTitle => 'פרטי רכישה';

  @override
  String get equipment_edit_purchasePriceLabel => 'מחיר רכישה';

  @override
  String get equipment_edit_remindMeBeforeServiceDue =>
      'הזכר לי לפני מועד הטיפול:';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days ימים';
  }

  @override
  String get equipment_edit_saveButton_edit => 'שמור שינויים';

  @override
  String get equipment_edit_saveButton_new => 'הוסף ציוד';

  @override
  String get equipment_edit_saveTooltip_edit => 'שמור שינויי ציוד';

  @override
  String get equipment_edit_saveTooltip_new => 'הוסף פריט ציוד חדש';

  @override
  String get equipment_edit_selectDate => 'בחר תאריך';

  @override
  String get equipment_edit_serialNumberLabel => 'מספר סידורי';

  @override
  String get equipment_edit_serviceIntervalHint => 'לדוגמה, 365 לשנתי';

  @override
  String get equipment_edit_serviceIntervalLabel => 'מרווח טיפול (ימים)';

  @override
  String get equipment_edit_serviceSettingsTitle => 'הגדרות טיפול';

  @override
  String get equipment_edit_sizeHint => 'לדוגמה, M, L, 42';

  @override
  String get equipment_edit_sizeLabel => 'מידה';

  @override
  String get equipment_edit_snackbar_added => 'הציוד נוסף';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return 'שגיאה בשמירת ציוד: $error';
  }

  @override
  String get equipment_edit_snackbar_updated => 'הציוד עודכן';

  @override
  String get equipment_edit_statusLabel => 'סטטוס';

  @override
  String get equipment_edit_typeLabel => 'סוג *';

  @override
  String get equipment_edit_useCustomReminders => 'השתמש בתזכורות מותאמות';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'הגדר ימי תזכורת שונים לפריט זה';

  @override
  String get equipment_fab_addEquipment => 'הוסף ציוד';

  @override
  String get equipment_list_emptyState_addFirstButton =>
      'הוסף את הציוד הראשון שלך';

  @override
  String get equipment_list_emptyState_addPrompt =>
      'הוסף את ציוד הצלילה שלך כדי לעקוב אחר שימוש וטיפול';

  @override
  String get equipment_list_emptyState_filterText_equipment => 'ציוד';

  @override
  String get equipment_list_emptyState_filterText_serviceDue =>
      'ציוד הדורש טיפול';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return 'ציוד $status';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return 'אין $filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch => 'אין ציוד עם סטטוס זה';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate =>
      'כל הציוד שלך מעודכן בטיפול!';

  @override
  String equipment_list_errorLoading(Object error) {
    return 'שגיאה בטעינת ציוד: $error';
  }

  @override
  String get equipment_list_filterAll => 'כל הציוד';

  @override
  String get equipment_list_filterLabel => 'סנן:';

  @override
  String get equipment_list_filterServiceDue => 'טיפול נדרש';

  @override
  String get equipment_list_retryButton => 'נסה שוב';

  @override
  String get equipment_list_searchTooltip => 'חפש ציוד';

  @override
  String get equipment_list_setsTooltip => 'סטי ציוד';

  @override
  String get equipment_list_sortTitle => 'מיין ציוד';

  @override
  String get equipment_list_sortTooltip => 'מיין';

  @override
  String equipment_list_tile_daysCount(Object days) {
    return '$days ימים';
  }

  @override
  String get equipment_list_tile_serviceDueChip => 'טיפול נדרש';

  @override
  String get equipment_list_tile_serviceIn => 'טיפול בעוד';

  @override
  String get equipment_menu_delete => 'מחק';

  @override
  String get equipment_menu_markAsServiced => 'סמן כטופל';

  @override
  String get equipment_menu_reactivate => 'הפעל מחדש';

  @override
  String get equipment_menu_retireEquipment => 'הוצא משימוש';

  @override
  String get equipment_search_backTooltip => 'חזרה';

  @override
  String get equipment_search_clearTooltip => 'נקה חיפוש';

  @override
  String get equipment_search_fieldLabel => 'חפש ציוד...';

  @override
  String get equipment_search_hint => 'חפש לפי שם, מותג, דגם או מספר סידורי';

  @override
  String equipment_search_noResults(Object query) {
    return 'לא נמצא ציוד עבור \"$query\"';
  }

  @override
  String get equipment_serviceDialog_addButton => 'הוסף';

  @override
  String get equipment_serviceDialog_addTitle => 'הוסף רשומת טיפול';

  @override
  String get equipment_serviceDialog_cancelButton => 'ביטול';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip =>
      'נקה תאריך טיפול הבא';

  @override
  String get equipment_serviceDialog_costHint => '0.00';

  @override
  String get equipment_serviceDialog_costLabel => 'עלות';

  @override
  String get equipment_serviceDialog_costValidation => 'הזן סכום חוקי';

  @override
  String get equipment_serviceDialog_editTitle => 'ערוך רשומת טיפול';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel => 'הטיפול הבא';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel =>
      'בחר תאריך לטיפול הבא';

  @override
  String get equipment_serviceDialog_nextServiceNotSet => 'לא הוגדר';

  @override
  String get equipment_serviceDialog_notesLabel => 'הערות';

  @override
  String get equipment_serviceDialog_providerHint => 'לדוגמה, שם חנות הצלילה';

  @override
  String get equipment_serviceDialog_providerLabel => 'ספק/חנות';

  @override
  String get equipment_serviceDialog_serviceDateLabel => 'תאריך טיפול';

  @override
  String get equipment_serviceDialog_serviceDateSemanticLabel =>
      'בחר תאריך טיפול';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => 'סוג טיפול';

  @override
  String get equipment_serviceDialog_snackbar_added => 'רשומת טיפול נוספה';

  @override
  String equipment_serviceDialog_snackbar_error(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get equipment_serviceDialog_snackbar_updated => 'רשומת טיפול עודכנה';

  @override
  String get equipment_serviceDialog_updateButton => 'עדכן';

  @override
  String get equipment_service_addButton => 'הוסף';

  @override
  String get equipment_service_deleteDialog_cancel => 'ביטול';

  @override
  String get equipment_service_deleteDialog_confirm => 'מחק';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return 'האם אתה בטוח שברצונך למחוק רשומת $serviceType זו?';
  }

  @override
  String get equipment_service_deleteDialog_title => 'למחוק רשומת טיפול?';

  @override
  String get equipment_service_deleteMenuItem => 'מחק';

  @override
  String get equipment_service_editMenuItem => 'ערוך';

  @override
  String get equipment_service_emptyState => 'אין עדיין רשומות טיפול';

  @override
  String get equipment_service_historyTitle => 'היסטוריית טיפול';

  @override
  String get equipment_service_snackbar_deleted => 'רשומת טיפול נמחקה';

  @override
  String get equipment_service_totalCostLabel => 'סה\"כ עלות טיפול';

  @override
  String get equipment_setDetail_addEquipmentButton => 'הוסף ציוד';

  @override
  String get equipment_setDetail_deleteDialog_cancel => 'ביטול';

  @override
  String get equipment_setDetail_deleteDialog_confirm => 'מחק';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      'האם אתה בטוח שברצונך למחוק סט ציוד זה? פריטי הציוד בסט לא יימחקו.';

  @override
  String get equipment_setDetail_deleteDialog_title => 'מחק סט ציוד';

  @override
  String get equipment_setDetail_deleteMenuItem => 'מחק';

  @override
  String get equipment_setDetail_editTooltip => 'ערוך סט';

  @override
  String get equipment_setDetail_emptySet => 'אין ציוד בסט זה';

  @override
  String get equipment_setDetail_equipmentInSetTitle => 'ציוד בסט זה';

  @override
  String equipment_setDetail_errorMessage(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get equipment_setDetail_errorTitle => 'שגיאה';

  @override
  String get equipment_setDetail_loadingTitle => 'טוען...';

  @override
  String get equipment_setDetail_notFoundMessage => 'סט ציוד זה כבר לא קיים.';

  @override
  String get equipment_setDetail_notFoundTitle => 'הסט לא נמצא';

  @override
  String get equipment_setDetail_snackbar_deleted => 'סט הציוד נמחק';

  @override
  String get equipment_setEdit_addEquipmentFirst =>
      'הוסף ציוד תחילה לפני יצירת סט.';

  @override
  String get equipment_setEdit_appBar_editTitle => 'ערוך סט';

  @override
  String get equipment_setEdit_appBar_newTitle => 'סט ציוד חדש';

  @override
  String get equipment_setEdit_descriptionHint => 'תיאור אופציונלי...';

  @override
  String get equipment_setEdit_descriptionLabel => 'תיאור';

  @override
  String equipment_setEdit_errorMessage(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get equipment_setEdit_errorTitle => 'שגיאה';

  @override
  String get equipment_setEdit_loadingTitle => 'טוען...';

  @override
  String get equipment_setEdit_nameHint => 'לדוגמה, סט למים חמים';

  @override
  String get equipment_setEdit_nameLabel => 'שם הסט *';

  @override
  String get equipment_setEdit_nameValidation => 'נא להזין שם';

  @override
  String get equipment_setEdit_noEquipmentAvailable => 'אין ציוד זמין';

  @override
  String get equipment_setEdit_notFoundMessage => 'סט ציוד זה כבר לא קיים.';

  @override
  String get equipment_setEdit_notFoundTitle => 'הסט לא נמצא';

  @override
  String get equipment_setEdit_saveButton_edit => 'שמור שינויים';

  @override
  String get equipment_setEdit_saveButton_new => 'צור סט';

  @override
  String get equipment_setEdit_saveTooltip_edit => 'שמור שינויי סט ציוד';

  @override
  String get equipment_setEdit_saveTooltip_new => 'צור סט ציוד חדש';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle =>
      'בחר את פריטי הציוד לכלול בסט זה.';

  @override
  String get equipment_setEdit_selectEquipmentTitle => 'בחר ציוד';

  @override
  String get equipment_setEdit_snackbar_created => 'סט הציוד נוצר';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return 'שגיאה בשמירת סט ציוד: $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated => 'סט הציוד עודכן';

  @override
  String get equipment_sets_appBar_title => 'סטי ציוד';

  @override
  String get equipment_sets_emptyState_createFirstButton =>
      'צור את הסט הראשון שלך';

  @override
  String get equipment_sets_emptyState_description =>
      'צור סטי ציוד כדי להוסיף במהירות שילובי ציוד נפוצים לצלילות שלך.';

  @override
  String get equipment_sets_emptyState_title => 'אין סטי ציוד';

  @override
  String equipment_sets_errorLoading(Object error) {
    return 'שגיאה בטעינת סטים: $error';
  }

  @override
  String get equipment_sets_fabTooltip => 'צור סט ציוד חדש';

  @override
  String get equipment_sets_fab_createSet => 'צור סט';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count פריטים';
  }

  @override
  String equipment_sets_itemCountSemanticLabel(Object count) {
    return '$count בסט';
  }

  @override
  String equipment_sets_itemCountSingular(Object count) {
    return '$count פריט';
  }

  @override
  String get equipment_sets_retryButton => 'נסה שוב';

  @override
  String get equipment_snackbar_deleted => 'הציוד נמחק';

  @override
  String get equipment_snackbar_markedAsServiced => 'סומן כטופל';

  @override
  String get equipment_snackbar_reactivated => 'הציוד הופעל מחדש';

  @override
  String get equipment_snackbar_retired => 'הציוד הוצא משימוש';

  @override
  String get equipment_summary_active => 'פעיל';

  @override
  String get equipment_summary_addEquipmentButton => 'הוסף ציוד';

  @override
  String get equipment_summary_equipmentSetsButton => 'סטי ציוד';

  @override
  String get equipment_summary_overviewTitle => 'סקירה כללית';

  @override
  String get equipment_summary_quickActionsTitle => 'פעולות מהירות';

  @override
  String get equipment_summary_recentEquipmentTitle => 'ציוד אחרון';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name, $type';
  }

  @override
  String get equipment_summary_selectPrompt =>
      'בחר ציוד מהרשימה כדי לצפות בפרטים';

  @override
  String get equipment_summary_serviceDue => 'טיפול נדרש';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name, $type, טיפול נדרש';
  }

  @override
  String get equipment_summary_serviceDueTitle => 'טיפול נדרש';

  @override
  String get equipment_summary_title => 'ציוד';

  @override
  String get equipment_summary_totalItems => 'סה\"כ פריטים';

  @override
  String get equipment_summary_totalValue => 'ערך כולל';

  @override
  String get formatter_approximate_prefix => '~';

  @override
  String get formatter_connector_at => 'ב';

  @override
  String get formatter_connector_from => 'מ';

  @override
  String get formatter_connector_until => 'עד';

  @override
  String get gas_air_description => 'אוויר סטנדרטי (21% O2)';

  @override
  String get gas_air_displayName => 'אוויר';

  @override
  String get gas_diluentAir_description => 'מדלל אוויר סטנדרטי ל-CCR רדוד';

  @override
  String get gas_diluentAir_displayName => 'מדלל אוויר';

  @override
  String get gas_diluentTx1070_description => 'מדלל היפוקסי ל-CCR עמוק מאוד';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description => 'מדלל היפוקסי ל-CCR עמוק';

  @override
  String get gas_diluentTx1260_displayName => 'Tx 12/60';

  @override
  String get gas_ean32_description => 'ניטרוקס מועשר 32%';

  @override
  String get gas_ean32_displayName => 'EAN32';

  @override
  String get gas_ean36_description => 'ניטרוקס מועשר 36%';

  @override
  String get gas_ean36_displayName => 'EAN36';

  @override
  String get gas_ean40_description => 'ניטרוקס מועשר 40%';

  @override
  String get gas_ean40_displayName => 'EAN40';

  @override
  String get gas_ean50_description => 'גז דקו - 50% O2';

  @override
  String get gas_ean50_displayName => 'EAN50';

  @override
  String get gas_helitrox2525_description => 'הליטרוקס 25/25 (טכני פנאי)';

  @override
  String get gas_helitrox2525_displayName => 'Helitrox 25/25';

  @override
  String get gas_oxygen_description => 'חמצן טהור (דקו ב-6m בלבד)';

  @override
  String get gas_oxygen_displayName => 'חמצן';

  @override
  String get gas_scrEan40_description => 'גז אספקה ל-SCR - 40% O2';

  @override
  String get gas_scrEan40_displayName => 'SCR EAN40';

  @override
  String get gas_scrEan50_description => 'גז אספקה ל-SCR - 50% O2';

  @override
  String get gas_scrEan50_displayName => 'SCR EAN50';

  @override
  String get gas_scrEan60_description => 'גז אספקה ל-SCR - 60% O2';

  @override
  String get gas_scrEan60_displayName => 'SCR EAN60';

  @override
  String get gas_tmx1555_description => 'טרימיקס היפוקסי 15/55 (עמוק מאוד)';

  @override
  String get gas_tmx1555_displayName => 'Tx 15/55';

  @override
  String get gas_tmx1845_description => 'טרימיקס 18/45 (צלילה עמוקה)';

  @override
  String get gas_tmx1845_displayName => 'Tx 18/45';

  @override
  String get gas_tmx2135_description => 'טרימיקס נורמוקסי 21/35';

  @override
  String get gas_tmx2135_displayName => 'Tx 21/35';

  @override
  String get gasCalculators_bestMix_bestOxygenMix => 'תערובת חמצן מיטבית';

  @override
  String get gasCalculators_bestMix_commonMixesRef => 'מדריך תערובות נפוצות';

  @override
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2) {
    return 'MOD של אוויר חרג ב-ppO₂ $ppO2';
  }

  @override
  String get gasCalculators_bestMix_targetDepth => 'עומק יעד';

  @override
  String get gasCalculators_bestMix_targetDive => 'צלילת יעד';

  @override
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  ) {
    return 'לחץ סביבה ב-$depth$depthSymbol';
  }

  @override
  String get gasCalculators_consumption_avgDepth => 'עומק ממוצע';

  @override
  String get gasCalculators_consumption_breakdown => 'פירוט חישוב';

  @override
  String get gasCalculators_consumption_diveTime => 'זמן צלילה';

  @override
  String gasCalculators_consumption_exceedsTank(
    Object pressure,
    Object symbol,
  ) {
    return 'חורג מקיבולת המיכל ($pressure $symbol)';
  }

  @override
  String get gasCalculators_consumption_gasAtDepth => 'צריכת גז בעומק';

  @override
  String get gasCalculators_consumption_pressure => 'לחץ';

  @override
  String get gasCalculators_consumption_remainingGas => 'גז נותר';

  @override
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  ) {
    return 'קיבולת מיכל ($tankSize$volumeSymbol @ $fillPressure $pressureSymbol)';
  }

  @override
  String get gasCalculators_consumption_title => 'צריכת גז';

  @override
  String gasCalculators_consumption_totalGas(Object time) {
    return 'גז כולל למשך $time דקות';
  }

  @override
  String get gasCalculators_consumption_volume => 'נפח';

  @override
  String get gasCalculators_mod_aboutMod => 'אודות MOD';

  @override
  String get gasCalculators_mod_aboutModBody =>
      'O₂ נמוך יותר = MOD עמוק יותר = NDL קצר יותר';

  @override
  String get gasCalculators_mod_inputParameters => 'פרמטרי קלט';

  @override
  String get gasCalculators_mod_maximumOperatingDepth => 'עומק הפעלה מקסימלי';

  @override
  String get gasCalculators_mod_oxygenO2 => 'חמצן (O₂)';

  @override
  String get gasCalculators_mod_ppO2Conservative =>
      'מגבלה שמרנית לזמן תחתית ממושך';

  @override
  String get gasCalculators_mod_ppO2Maximum =>
      'מגבלה מקסימלית לעצירות דקומפרסיה בלבד';

  @override
  String get gasCalculators_mod_ppO2Standard =>
      'מגבלת עבודה סטנדרטית לצלילה פנאי';

  @override
  String get gasCalculators_ppO2Limit => 'מגבלת ppO₂';

  @override
  String get gasCalculators_resetAll => 'אפס את כל המחשבונים';

  @override
  String get gasCalculators_sacRate => 'קצב SAC';

  @override
  String get gasCalculators_tab_bestMix => 'תערובת מיטבית';

  @override
  String get gasCalculators_tab_consumption => 'צריכה';

  @override
  String get gasCalculators_tab_mod => 'MOD';

  @override
  String get gasCalculators_tab_rockBottom => 'Rock Bottom';

  @override
  String get gasCalculators_tankSize => 'גודל מיכל';

  @override
  String get gasCalculators_title => 'מחשבוני גז';

  @override
  String get marineLife_siteSection_editExpectedTooltip => 'ערוך מינים צפויים';

  @override
  String get marineLife_siteSection_errorLoadingExpected =>
      'שגיאה בטעינת מינים צפויים';

  @override
  String get marineLife_siteSection_errorLoadingSightings =>
      'שגיאה בטעינת תצפיות';

  @override
  String get marineLife_siteSection_expectedSpecies => 'מינים צפויים';

  @override
  String get marineLife_siteSection_noExpected => 'לא נוספו מינים צפויים';

  @override
  String get marineLife_siteSection_noSpotted => 'עדיין לא נצפה חי ימי';

  @override
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  ) {
    return '$name, נצפה $count פעמים';
  }

  @override
  String get marineLife_siteSection_spottedHere => 'נצפו כאן';

  @override
  String get marineLife_siteSection_title => 'חי ימי';

  @override
  String get marineLife_speciesDetail_backTooltip => 'חזרה';

  @override
  String get marineLife_speciesDetail_depthRangeTitle => 'טווח עומק';

  @override
  String get marineLife_speciesDetail_descriptionTitle => 'תיאור';

  @override
  String get marineLife_speciesDetail_divesLabel => 'צלילות';

  @override
  String get marineLife_speciesDetail_editTooltip => 'ערוך מין';

  @override
  String marineLife_speciesDetail_errorPrefix(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get marineLife_speciesDetail_noSightings => 'עדיין לא נרשמו תצפיות';

  @override
  String get marineLife_speciesDetail_notFound => 'המין לא נמצא';

  @override
  String marineLife_speciesDetail_sightingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'תצפיות',
      one: 'תצפית',
    );
    return '$count $_temp0';
  }

  @override
  String get marineLife_speciesDetail_sightingPeriodTitle => 'תקופת תצפיות';

  @override
  String get marineLife_speciesDetail_sightingStatsTitle => 'סטטיסטיקות תצפיות';

  @override
  String get marineLife_speciesDetail_sitesLabel => 'אתרים';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return 'מחלקה: $className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle => 'אתרים מובילים';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel => 'סה\"כ תצפיות';

  @override
  String get marineLife_speciesEdit_addTitle => 'הוסף מין';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return 'נוסף \"$name\"';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => 'חזרה';

  @override
  String get marineLife_speciesEdit_categoryLabel => 'קטגוריה';

  @override
  String get marineLife_speciesEdit_commonNameError => 'נא להזין שם נפוץ';

  @override
  String get marineLife_speciesEdit_commonNameHint => 'לדוגמה, דג ליצן';

  @override
  String get marineLife_speciesEdit_commonNameLabel => 'שם נפוץ';

  @override
  String get marineLife_speciesEdit_descriptionHint => 'תיאור קצר של המין...';

  @override
  String get marineLife_speciesEdit_descriptionLabel => 'תיאור';

  @override
  String get marineLife_speciesEdit_editTitle => 'ערוך מין';

  @override
  String marineLife_speciesEdit_errorLoading(Object error) {
    return 'שגיאה בטעינת מין: $error';
  }

  @override
  String marineLife_speciesEdit_errorSaving(Object error) {
    return 'שגיאה בשמירת מין: $error';
  }

  @override
  String get marineLife_speciesEdit_saveButton => 'שמירה';

  @override
  String get marineLife_speciesEdit_scientificNameHint =>
      'לדוגמה, Amphiprion ocellaris';

  @override
  String get marineLife_speciesEdit_scientificNameLabel => 'שם מדעי';

  @override
  String get marineLife_speciesEdit_taxonomyClassHint =>
      'לדוגמה, Actinopterygii';

  @override
  String get marineLife_speciesEdit_taxonomyClassLabel => 'מחלקה טקסונומית';

  @override
  String marineLife_speciesEdit_updatedSnackbar(Object name) {
    return 'עודכן \"$name\"';
  }

  @override
  String get marineLife_speciesManage_allFilter => 'הכל';

  @override
  String get marineLife_speciesManage_appBarTitle => 'מינים';

  @override
  String get marineLife_speciesManage_backTooltip => 'חזרה';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return 'מינים מובנים ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => 'ביטול';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return 'לא ניתן למחוק את \"$name\" - יש לו תצפיות';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip => 'נקה חיפוש';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return 'מינים מותאמים אישית ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => 'מחיקה';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return 'האם אתה בטוח שברצונך למחוק את \"$name\"?';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle => 'למחוק מין?';

  @override
  String get marineLife_speciesManage_deleteTooltip => 'מחק מין';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return 'נמחק \"$name\"';
  }

  @override
  String get marineLife_speciesManage_editTooltip => 'ערוך מין';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return 'שגיאה במחיקת מין: $error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return 'שגיאה באיפוס מינים: $error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound => 'לא נמצאו מינים';

  @override
  String get marineLife_speciesManage_resetButton => 'איפוס';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      'פעולה זו תשחזר את כל המינים המובנים לערכים המקוריים שלהם. מינים מותאמים אישית לא יושפעו. מינים מובנים עם תצפיות קיימות יעודכנו אך יישמרו.';

  @override
  String get marineLife_speciesManage_resetDialogTitle => 'לאפס לברירת מחדל?';

  @override
  String get marineLife_speciesManage_resetSuccess =>
      'המינים המובנים שוחזרו לברירת מחדל';

  @override
  String get marineLife_speciesManage_resetToDefaults => 'איפוס לברירת מחדל';

  @override
  String get marineLife_speciesManage_searchHint => 'חיפוש מינים...';

  @override
  String get marineLife_speciesPicker_allFilter => 'הכל';

  @override
  String get marineLife_speciesPicker_cancelButton => 'ביטול';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip => 'נקה חיפוש';

  @override
  String get marineLife_speciesPicker_closeTooltip => 'סגור בורר מינים';

  @override
  String get marineLife_speciesPicker_doneButton => 'סיום';

  @override
  String marineLife_speciesPicker_error(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get marineLife_speciesPicker_noSpeciesFound => 'לא נמצאו מינים';

  @override
  String get marineLife_speciesPicker_searchHint => 'חיפוש מינים...';

  @override
  String marineLife_speciesPicker_selectedCount(Object count) {
    return '$count נבחרו';
  }

  @override
  String get marineLife_speciesPicker_title => 'בחר מינים';

  @override
  String get media_diveMediaSection_addTooltip => 'הוסף תמונה או סרטון';

  @override
  String get media_diveMediaSection_cancelButton => 'ביטול';

  @override
  String get media_diveMediaSection_emptyState => 'עדיין אין תמונות';

  @override
  String get media_diveMediaSection_errorLoading => 'שגיאה בטעינת מדיה';

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'הצג תמונה. לחיצה ארוכה לביטול קישור';

  @override
  String get media_diveMediaSection_title => 'תמונות וסרטונים';

  @override
  String get media_diveMediaSection_unlinkButton => 'בטל קישור';

  @override
  String get media_diveMediaSection_unlinkDialogContent =>
      'להסיר תמונה זו מהצלילה? התמונה תישאר בגלריה שלך.';

  @override
  String get media_diveMediaSection_unlinkDialogTitle => 'ביטול קישור תמונה';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'ביטול הקישור נכשל: $error';
  }

  @override
  String get media_diveMediaSection_unlinkSuccess => 'קישור התמונה בוטל';

  @override
  String get media_gpsBanner_addToSiteButton => 'הוסף לאתר';

  @override
  String media_gpsBanner_coordinates(Object latitude, Object longitude) {
    return 'קואורדינטות: $latitude, $longitude';
  }

  @override
  String get media_gpsBanner_createSiteButton => 'צור אתר';

  @override
  String get media_gpsBanner_dismissTooltip => 'סגור הצעת GPS';

  @override
  String get media_gpsBanner_title => 'נמצא GPS בתמונות';

  @override
  String media_import_failedToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'תמונות',
      one: 'תמונה',
    );
    return 'ייבוא $_temp0 נכשל';
  }

  @override
  String media_import_failedToImportError(Object error) {
    return 'ייבוא תמונות נכשל: $error';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return 'יובאו $imported, נכשלו $failed';
  }

  @override
  String media_import_importedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'תמונות',
      one: 'תמונה',
    );
    return 'יובאו $count $_temp0';
  }

  @override
  String media_import_importingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'תמונות',
      one: 'תמונה',
    );
    return 'מייבא $count $_temp0...';
  }

  @override
  String get media_miniProfile_headerLabel => 'פרופיל צלילה';

  @override
  String get media_miniProfile_semanticLabel => 'תרשים מיני של פרופיל צלילה';

  @override
  String get media_photoPicker_appBarTitle => 'בחר תמונות';

  @override
  String get media_photoPicker_closeTooltip => 'סגור בורר תמונות';

  @override
  String get media_photoPicker_doneButton => 'סיום';

  @override
  String media_photoPicker_doneCountButton(Object count) {
    return 'סיום ($count)';
  }

  @override
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  ) {
    return 'לא נמצאו תמונות בין $startDate $startTime לבין $endDate $endTime.';
  }

  @override
  String get media_photoPicker_emptyTitle => 'לא נמצאו תמונות';

  @override
  String get media_photoPicker_grantAccessButton => 'אשר גישה';

  @override
  String get media_photoPicker_openSettingsButton => 'פתח הגדרות';

  @override
  String get media_photoPicker_openSettingsSnackbar =>
      'נא לפתוח הגדרות ולאפשר גישה לתמונות';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'הגישה לספריית התמונות נדחתה. נא לאפשר אותה בהגדרות כדי להוסיף תמונות צלילה.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion זקוקה לגישה לספריית התמונות שלך כדי להוסיף תמונות צלילה.';

  @override
  String get media_photoPicker_permissionTitle => 'נדרשת גישה לתמונות';

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return 'מציג תמונות מ-$rangeText';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel => 'החלף מצב בחירה לתמונה';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel =>
      'החלף מצב בחירה לתמונה, נבחרה';

  @override
  String get media_photoViewer_cannotShare => 'לא ניתן לשתף תמונה זו';

  @override
  String get media_photoViewer_cannotWriteMetadata =>
      'לא ניתן לכתוב מטא-נתונים - המדיה אינה מקושרת לספרייה';

  @override
  String get media_photoViewer_closeTooltip => 'סגור מציג תמונות';

  @override
  String get media_photoViewer_diveDataWrittenToPhoto =>
      'נתוני צלילה נכתבו לתמונה';

  @override
  String get media_photoViewer_diveDataWrittenToVideo =>
      'נתוני צלילה נכתבו לסרטון';

  @override
  String media_photoViewer_errorLoadingPhotos(Object error) {
    return 'שגיאה בטעינת תמונות: $error';
  }

  @override
  String get media_photoViewer_failedToLoadImage => 'טעינת התמונה נכשלה';

  @override
  String get media_photoViewer_failedToLoadVideo => 'טעינת הסרטון נכשלה';

  @override
  String media_photoViewer_failedToShare(Object error) {
    return 'השיתוף נכשל: $error';
  }

  @override
  String get media_photoViewer_failedToWriteMetadata =>
      'כתיבת המטא-נתונים נכשלה';

  @override
  String media_photoViewer_failedToWriteMetadataError(Object error) {
    return 'כתיבת המטא-נתונים נכשלה: $error';
  }

  @override
  String get media_photoViewer_noPhotosAvailable => 'אין תמונות זמינות';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel => 'הפעל או השהה סרטון';

  @override
  String get media_photoViewer_seekVideoLabel => 'דלג למיקום בסרטון';

  @override
  String get media_photoViewer_shareTooltip => 'שתף תמונה';

  @override
  String get media_photoViewer_toggleOverlayLabel => 'החלף שכבת-על של תמונה';

  @override
  String get media_photoViewer_videoFileNotFound => 'קובץ הסרטון לא נמצא';

  @override
  String get media_photoViewer_videoNotLinked => 'הסרטון אינו מקושר לספרייה';

  @override
  String get media_photoViewer_writeDiveDataTooltip =>
      'כתוב נתוני צלילה לתמונה';

  @override
  String get media_quickSiteDialog_cancelButton => 'ביטול';

  @override
  String get media_quickSiteDialog_createButton => 'צור אתר';

  @override
  String get media_quickSiteDialog_description =>
      'צור אתר צלילה חדש באמצעות קואורדינטות GPS מהתמונה שלך.';

  @override
  String get media_quickSiteDialog_siteNameError => 'נא להזין שם אתר';

  @override
  String get media_quickSiteDialog_siteNameHint => 'הזן שם לאתר זה';

  @override
  String get media_quickSiteDialog_siteNameLabel => 'שם האתר';

  @override
  String get media_quickSiteDialog_title => 'יצירת אתר צלילה';

  @override
  String get media_scanResults_allPhotosLinked => 'כל התמונות כבר מקושרות';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return 'כל $count התמונות מטיול זה כבר מקושרות לצלילות.';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count תמונות כבר מקושרות';
  }

  @override
  String get media_scanResults_cancelButton => 'ביטול';

  @override
  String media_scanResults_diveNumber(Object number) {
    return 'צלילה #$number';
  }

  @override
  String media_scanResults_foundNewPhotos(Object count) {
    return 'נמצאו $count תמונות חדשות';
  }

  @override
  String get media_scanResults_linkButton => 'קשר';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return 'קשר $count תמונות';
  }

  @override
  String get media_scanResults_noPhotosFound => 'לא נמצאו תמונות';

  @override
  String get media_scanResults_okButton => 'אישור';

  @override
  String get media_scanResults_unknownSite => 'אתר לא ידוע';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return 'לא ניתן היה להתאים $count תמונות לאף צלילה (צולמו מחוץ לזמני צלילה)';
  }

  @override
  String get media_writeMetadata_cancelButton => 'ביטול';

  @override
  String get media_writeMetadata_depthLabel => 'עומק';

  @override
  String get media_writeMetadata_descriptionPhoto =>
      'המטא-נתונים הבאים ייכתבו לתמונה:';

  @override
  String get media_writeMetadata_descriptionVideo =>
      'המטא-נתונים הבאים ייכתבו לסרטון:';

  @override
  String get media_writeMetadata_diveTimeLabel => 'זמן צלילה';

  @override
  String get media_writeMetadata_gpsLabel => 'GPS';

  @override
  String get media_writeMetadata_keepOriginalVideo => 'שמור סרטון מקורי';

  @override
  String get media_writeMetadata_noDataAvailable =>
      'אין נתוני צלילה זמינים לכתיבה.';

  @override
  String get media_writeMetadata_siteLabel => 'אתר';

  @override
  String get media_writeMetadata_temperatureLabel => 'טמפרטורה';

  @override
  String get media_writeMetadata_titlePhoto => 'כתוב נתוני צלילה לתמונה';

  @override
  String get media_writeMetadata_titleVideo => 'כתוב נתוני צלילה לסרטון';

  @override
  String get media_writeMetadata_warningPhotoText =>
      'פעולה זו תשנה את התמונה המקורית.';

  @override
  String get media_writeMetadata_warningVideoText =>
      'ייווצר סרטון חדש עם המטא-נתונים. לא ניתן לשנות מטא-נתונים של סרטון במקום.';

  @override
  String get media_writeMetadata_writeButton => 'כתוב';

  @override
  String get nav_buddies => 'שותפים';

  @override
  String get nav_certifications => 'הסמכות';

  @override
  String get nav_courses => 'קורסים';

  @override
  String get nav_coursesSubtitle => 'הכשרה וחינוך';

  @override
  String get nav_diveCenters => 'מועדוני צלילה';

  @override
  String get nav_dives => 'צלילות';

  @override
  String get nav_equipment => 'ציוד';

  @override
  String get nav_home => 'בית';

  @override
  String get nav_more => 'עוד';

  @override
  String get nav_planning => 'תכנון';

  @override
  String get nav_planningSubtitle => 'מתכנן צלילה, מחשבונים';

  @override
  String get nav_settings => 'הגדרות';

  @override
  String get nav_sites => 'אתרים';

  @override
  String get nav_statistics => 'סטטיסטיקות';

  @override
  String get nav_tooltip_closeMenu => 'סגירת תפריט';

  @override
  String get nav_tooltip_collapseMenu => 'כיווץ תפריט';

  @override
  String get nav_tooltip_expandMenu => 'הרחבת תפריט';

  @override
  String get nav_transfer => 'העברה';

  @override
  String get nav_trips => 'טיולים';

  @override
  String get onboarding_welcome_createProfile => 'צור את הפרופיל שלך';

  @override
  String get onboarding_welcome_createProfileSubtitle =>
      'הזן את שמך כדי להתחיל. תוכל להוסיף פרטים נוספים מאוחר יותר.';

  @override
  String get onboarding_welcome_creating => 'יוצר...';

  @override
  String onboarding_welcome_errorCreatingProfile(Object error) {
    return 'שגיאה ביצירת פרופיל: $error';
  }

  @override
  String get onboarding_welcome_getStarted => 'התחל';

  @override
  String get onboarding_welcome_nameHint => 'הזן את שמך';

  @override
  String get onboarding_welcome_nameLabel => 'השם שלך';

  @override
  String get onboarding_welcome_nameValidation => 'נא להזין את שמך';

  @override
  String get onboarding_welcome_subtitle => 'רישום וניתוח צלילה מתקדם';

  @override
  String get onboarding_welcome_title => 'ברוכים הבאים ל-Submersion';

  @override
  String get planning_appBar_title => 'תכנון';

  @override
  String get planning_card_decoCalculator_description =>
      'חשב מגבלות ללא דקומפרסיה, עצירות דקו נדרשות וחשיפת CNS/OTU עבור פרופילי צלילה רב-שלביים.';

  @override
  String get planning_card_decoCalculator_subtitle =>
      'תכנן צלילות עם עצירות דקומפרסיה';

  @override
  String get planning_card_decoCalculator_title => 'מחשבון דקו';

  @override
  String get planning_card_divePlanner_description =>
      'תכנן צלילות מורכבות עם רמות עומק מרובות, החלפות גז וחישובי עצירות דקומפרסיה אוטומטיים.';

  @override
  String get planning_card_divePlanner_subtitle =>
      'צור תוכניות צלילה רב-שלביות';

  @override
  String get planning_card_divePlanner_title => 'מתכנן צלילות';

  @override
  String get planning_card_gasCalculators_description =>
      'ארבעה מחשבוני גז מתמחים:\n• MOD - עומק הפעלה מרבי לתערובת גז\n• תערובת אופטימלית - אחוז O₂ אידיאלי לעומק יעד\n• צריכה - הערכת צריכת גז\n• Rock Bottom - חישוב רזרבת חירום';

  @override
  String get planning_card_gasCalculators_subtitle =>
      'MOD, תערובת אופטימלית, צריכה, Rock Bottom';

  @override
  String get planning_card_gasCalculators_title => 'מחשבוני גז';

  @override
  String get planning_card_surfaceInterval_description =>
      'חשב את מרווח השטח המינימלי הנדרש בין צלילות בהתבסס על עומס הרקמות. צפה כיצד 16 תאי הרקמה שלך פורקים גז לאורך זמן.';

  @override
  String get planning_card_surfaceInterval_subtitle =>
      'תכנן מרווחי צלילות חוזרות';

  @override
  String get planning_card_surfaceInterval_title => 'מרווח שטח';

  @override
  String get planning_card_weightCalculator_description =>
      'הערך את המשקל הנדרש בהתבסס על חליפת הצלילה, חומר הבלון, סוג המים ומשקל הגוף שלך.';

  @override
  String get planning_card_weightCalculator_subtitle => 'משקל מומלץ להגדרה שלך';

  @override
  String get planning_card_weightCalculator_title => 'מחשבון משקל';

  @override
  String get planning_info_disclaimer =>
      'כלים אלה מיועדים למטרות תכנון בלבד. תמיד אמת חישובים ופעל לפי הכשרת הצלילה שלך.';

  @override
  String get planning_sidebar_appBar_title => 'תכנון';

  @override
  String get planning_sidebar_decoCalculator_subtitle => 'NDL ועצירות דקו';

  @override
  String get planning_sidebar_decoCalculator_title => 'מחשבון דקו';

  @override
  String get planning_sidebar_divePlanner_subtitle => 'תוכניות צלילה רב-שלביות';

  @override
  String get planning_sidebar_divePlanner_title => 'מתכנן צלילות';

  @override
  String get planning_sidebar_gasCalculators_subtitle =>
      'MOD, תערובת אופטימלית ועוד';

  @override
  String get planning_sidebar_gasCalculators_title => 'מחשבוני גז';

  @override
  String get planning_sidebar_info_disclaimer =>
      'כלי התכנון מיועדים להתייחסות בלבד. תמיד אמת חישובים.';

  @override
  String get planning_sidebar_surfaceInterval_subtitle => 'תכנון צלילות חוזרות';

  @override
  String get planning_sidebar_surfaceInterval_title => 'מרווח שטח';

  @override
  String get planning_sidebar_weightCalculator_subtitle => 'משקל מומלץ';

  @override
  String get planning_sidebar_weightCalculator_title => 'מחשבון משקל';

  @override
  String get planning_welcome_quickTips_title => 'טיפים מהירים';

  @override
  String get planning_welcome_subtitle => 'בחר כלי מסרגל הצד כדי להתחיל';

  @override
  String get planning_welcome_tip_decoCalculator =>
      'מחשבון דקו ל-NDL וזמני עצירה';

  @override
  String get planning_welcome_tip_divePlanner =>
      'מתכנן צלילות לתכנון צלילות רב-שלביות';

  @override
  String get planning_welcome_tip_gasCalculators =>
      'מחשבוני גז ל-MOD ותכנון גז';

  @override
  String get planning_welcome_tip_weightCalculator => 'מחשבון משקל להגדרת ציפה';

  @override
  String get planning_welcome_title => 'כלי תכנון';

  @override
  String get settings_about_aboutSubmersion => 'אודות Submersion';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description =>
      'עקוב אחר הצלילות שלך, נהל ציוד וחקור אתרי צלילה.';

  @override
  String get settings_about_header => 'אודות';

  @override
  String get settings_about_openSourceLicenses => 'רישיונות קוד פתוח';

  @override
  String get settings_about_reportIssue => 'דווח על בעיה';

  @override
  String get settings_about_reportIssue_snackbar =>
      'בקר ב-github.com/submersion/submersion';

  @override
  String settings_about_version(String version, String buildNumber) {
    return 'גרסה $version ($buildNumber)';
  }

  @override
  String get settings_appBar_title => 'הגדרות';

  @override
  String get settings_appearance_appLanguage => 'שפת האפליקציה';

  @override
  String get settings_appearance_depthColoredCards =>
      'כרטיסי צלילה צבועים לפי עומק';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'הצג כרטיסי צלילה עם רקעים בצבעי אוקיינוס לפי עומק';

  @override
  String get settings_appearance_cardColorAttribute => 'צבע כרטיסים לפי';

  @override
  String get settings_appearance_cardColorAttribute_subtitle =>
      'בחר איזה מאפיין קובע את צבע הרקע של הכרטיסים';

  @override
  String get settings_appearance_cardColorAttribute_none => 'ללא';

  @override
  String get settings_appearance_cardColorAttribute_depth => 'עומק';

  @override
  String get settings_appearance_cardColorAttribute_duration => 'משך';

  @override
  String get settings_appearance_cardColorAttribute_temperature => 'טמפרטורה';

  @override
  String get settings_appearance_colorGradient => 'מעבר צבעים';

  @override
  String get settings_appearance_colorGradient_subtitle =>
      'בחר את טווח הצבעים לרקעי הכרטיסים';

  @override
  String get settings_appearance_colorGradient_ocean => 'אוקיינוס';

  @override
  String get settings_appearance_colorGradient_thermal => 'תרמי';

  @override
  String get settings_appearance_colorGradient_sunset => 'שקיעה';

  @override
  String get settings_appearance_colorGradient_forest => 'יער';

  @override
  String get settings_appearance_colorGradient_monochrome => 'מונוכרום';

  @override
  String get settings_appearance_colorGradient_custom => 'מותאם אישית';

  @override
  String get settings_appearance_gasSwitchMarkers => 'סמני החלפת גז';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'הצג סמנים להחלפות גז';

  @override
  String get settings_appearance_header_diveLog => 'יומן צלילות';

  @override
  String get settings_appearance_header_diveProfile => 'פרופיל צלילה';

  @override
  String get settings_appearance_header_diveSites => 'אתרי צלילה';

  @override
  String get settings_appearance_header_language => 'שפה';

  @override
  String get settings_appearance_header_theme => 'ערכת נושא';

  @override
  String get settings_appearance_mapBackgroundDiveCards =>
      'רקע מפה בכרטיסי צלילה';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitle =>
      'הצג מפת אתר צלילה כרקע בכרטיסי צלילה';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote =>
      'הצג מפת אתר צלילה כרקע בכרטיסי צלילה (דורש מיקום אתר)';

  @override
  String get settings_appearance_mapBackgroundSiteCards =>
      'רקע מפה בכרטיסי אתרים';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitle =>
      'הצג מפה כרקע בכרטיסי אתרי צלילה';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote =>
      'הצג מפה כרקע בכרטיסי אתרי צלילה (דורש מיקום אתר)';

  @override
  String get settings_appearance_maxDepthMarker => 'סמן עומק מרבי';

  @override
  String get settings_appearance_maxDepthMarker_subtitle =>
      'הצג סמן בנקודת העומק המרבי';

  @override
  String get settings_appearance_maxDepthMarker_subtitleFull =>
      'הצג סמן בנקודת העומק המרבי בפרופילי צלילה';

  @override
  String get settings_appearance_metric_ascentRateColors => 'צבעי קצב עלייה';

  @override
  String get settings_appearance_metric_ceiling => 'תקרה';

  @override
  String get settings_appearance_metric_events => 'אירועים';

  @override
  String get settings_appearance_metric_gasDensity => 'צפיפות גז';

  @override
  String get settings_appearance_metric_gfPercent => 'GF%';

  @override
  String get settings_appearance_metric_heartRate => 'קצב לב';

  @override
  String get settings_appearance_metric_meanDepth => 'עומק ממוצע';

  @override
  String get settings_appearance_metric_ndl => 'NDL';

  @override
  String get settings_appearance_metric_ppHe => 'ppHe';

  @override
  String get settings_appearance_metric_ppN2 => 'ppN2';

  @override
  String get settings_appearance_metric_ppO2 => 'ppO2';

  @override
  String get settings_appearance_metric_pressure => 'לחץ';

  @override
  String get settings_appearance_metric_sacRate => 'קצב SAC';

  @override
  String get settings_appearance_metric_surfaceGf => 'GF שטח';

  @override
  String get settings_appearance_metric_temperature => 'טמפרטורה';

  @override
  String get settings_appearance_metric_tts => 'TTS (זמן לשטח)';

  @override
  String get settings_appearance_pressureThresholdMarkers => 'סמני סף לחץ';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'הצג סמנים כאשר לחץ הבלון חוצה ספים';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'הצג סמנים כאשר לחץ הבלון חוצה ספי 2/3, 1/2 ו-1/3';

  @override
  String get settings_appearance_rightYAxisMetric => 'מדד ציר Y ימני';

  @override
  String get settings_appearance_rightYAxisMetric_subtitle =>
      'מדד ברירת מחדל המוצג בציר הימני';

  @override
  String get settings_appearance_subsection_decompressionMetrics =>
      'מדדי דקומפרסיה';

  @override
  String get settings_appearance_subsection_defaultVisibleMetrics =>
      'מדדים גלויים כברירת מחדל';

  @override
  String get settings_appearance_subsection_gasAnalysisMetrics =>
      'מדדי ניתוח גז';

  @override
  String get settings_appearance_subsection_gradientFactorMetrics =>
      'מדדי גורם שיפוע';

  @override
  String get settings_appearance_theme_dark => 'כהה';

  @override
  String get settings_appearance_theme_light => 'בהיר';

  @override
  String get settings_appearance_theme_system => 'ברירת מחדל של המערכת';

  @override
  String get settings_backToSettings_tooltip => 'חזרה להגדרות';

  @override
  String get settings_cloudSync_appBar_title => 'סנכרון ענן';

  @override
  String get settings_cloudSync_autoSync => 'סנכרון אוטומטי';

  @override
  String get settings_cloudSync_autoSync_subtitle =>
      'סנכרן אוטומטית לאחר שינויים';

  @override
  String settings_cloudSync_conflictItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים דורשים תשומת לב',
      one: 'פריט אחד דורש תשומת לב',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_disabledBanner_content =>
      'סנכרון ענן מנוהל אפליקציה מושבת כי אתה משתמש בתיקייה מותאמת אישית. שירות הסנכרון של התיקייה שלך (Dropbox, Google Drive, OneDrive וכו\') מטפל בסנכרון.';

  @override
  String get settings_cloudSync_disabledBanner_title => 'סנכרון ענן מושבת';

  @override
  String get settings_cloudSync_header_advanced => 'מתקדם';

  @override
  String get settings_cloudSync_header_cloudProvider => 'ספק ענן';

  @override
  String settings_cloudSync_header_conflicts(Object count) {
    return 'התנגשויות ($count)';
  }

  @override
  String get settings_cloudSync_header_syncBehavior => 'התנהגות סנכרון';

  @override
  String settings_cloudSync_lastSynced(Object time) {
    return 'סנכרון אחרון: $time';
  }

  @override
  String settings_cloudSync_pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count שינויים ממתינים',
      one: 'שינוי ממתין אחד',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_provider_connected => 'מחובר';

  @override
  String settings_cloudSync_provider_connectedTo(Object providerName) {
    return 'מחובר אל $providerName';
  }

  @override
  String settings_cloudSync_provider_connectionFailed(
    Object providerName,
    Object error,
  ) {
    return 'החיבור אל $providerName נכשל: $error';
  }

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'סנכרון באמצעות Google Drive';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'סנכרון באמצעות Apple iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'אתחול ספק $providerName נכשל';
  }

  @override
  String get settings_cloudSync_provider_notAvailable => 'לא זמין בפלטפורמה זו';

  @override
  String get settings_cloudSync_resetDialog_cancel => 'ביטול';

  @override
  String get settings_cloudSync_resetDialog_content =>
      'פעולה זו תנקה את כל היסטוריית הסנכרון ותתחיל מחדש. הנתונים שלך לא יימחקו, אך ייתכן שתצטרך לפתור התנגשויות בסנכרון הבא.';

  @override
  String get settings_cloudSync_resetDialog_reset => 'איפוס';

  @override
  String get settings_cloudSync_resetDialog_title => 'לאפס מצב סנכרון?';

  @override
  String get settings_cloudSync_resetSuccess => 'מצב הסנכרון אופס';

  @override
  String get settings_cloudSync_resetSyncState => 'אפס מצב סנכרון';

  @override
  String get settings_cloudSync_resetSyncState_subtitle =>
      'נקה היסטוריית סנכרון והתחל מחדש';

  @override
  String get settings_cloudSync_resolveConflicts => 'פתור התנגשויות';

  @override
  String get settings_cloudSync_selectProviderHint =>
      'בחר ספק ענן כדי לאפשר סנכרון';

  @override
  String get settings_cloudSync_signOut => 'התנתק';

  @override
  String get settings_cloudSync_signOutDialog_cancel => 'ביטול';

  @override
  String get settings_cloudSync_signOutDialog_content =>
      'פעולה זו תנתק מספק הענן. הנתונים המקומיים שלך יישארו ללא שינוי.';

  @override
  String get settings_cloudSync_signOutDialog_signOut => 'התנתק';

  @override
  String get settings_cloudSync_signOutDialog_title => 'להתנתק?';

  @override
  String get settings_cloudSync_signOutSuccess => 'התנתקת מספק הענן';

  @override
  String get settings_cloudSync_signOut_subtitle => 'התנתק מספק הענן';

  @override
  String get settings_cloudSync_status_conflictsDetected => 'זוהו התנגשויות';

  @override
  String get settings_cloudSync_status_readyToSync => 'מוכן לסנכרון';

  @override
  String get settings_cloudSync_status_syncComplete => 'הסנכרון הושלם';

  @override
  String get settings_cloudSync_status_syncError => 'שגיאת סנכרון';

  @override
  String get settings_cloudSync_status_syncing => 'מסנכרן...';

  @override
  String get settings_cloudSync_storageSettings => 'הגדרות אחסון';

  @override
  String get settings_cloudSync_syncNow => 'סנכרן עכשיו';

  @override
  String get settings_cloudSync_syncOnLaunch => 'סנכרון בהפעלה';

  @override
  String get settings_cloudSync_syncOnLaunch_subtitle => 'בדוק עדכונים בהפעלה';

  @override
  String get settings_cloudSync_syncOnResume => 'סנכרון בחזרה';

  @override
  String get settings_cloudSync_syncOnResume_subtitle =>
      'בדוק עדכונים כשהאפליקציה נהיית פעילה';

  @override
  String settings_cloudSync_syncProgressPercent(Object percent) {
    return 'התקדמות סנכרון: $percent אחוז';
  }

  @override
  String settings_cloudSync_time_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לפני $count ימים',
      one: 'לפני יום',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_time_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לפני $count שעות',
      one: 'לפני שעה',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_time_justNow => 'הרגע';

  @override
  String settings_cloudSync_time_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לפני $count דקות',
      one: 'לפני דקה',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_applyAll => 'החל על הכל';

  @override
  String get settings_conflict_cancel => 'ביטול';

  @override
  String get settings_conflict_chooseResolution => 'בחר פתרון';

  @override
  String get settings_conflict_close => 'סגירה';

  @override
  String get settings_conflict_close_tooltip => 'סגור חלון התנגשות';

  @override
  String settings_conflict_counterLabel(Object current, Object total) {
    return 'התנגשות $current מתוך $total';
  }

  @override
  String settings_conflict_errorLoading(Object error) {
    return 'שגיאה בטעינת התנגשויות: $error';
  }

  @override
  String get settings_conflict_keepBoth => 'שמור את שניהם';

  @override
  String get settings_conflict_keepLocal => 'שמור מקומי';

  @override
  String get settings_conflict_keepRemote => 'שמור מרוחק';

  @override
  String get settings_conflict_localVersion => 'גרסה מקומית';

  @override
  String settings_conflict_modified(Object time) {
    return 'שונה: $time';
  }

  @override
  String get settings_conflict_next_tooltip => 'ההתנגשות הבאה';

  @override
  String get settings_conflict_noConflicts_message =>
      'כל התנגשויות הסנכרון נפתרו.';

  @override
  String get settings_conflict_noConflicts_title => 'אין התנגשויות';

  @override
  String get settings_conflict_noDataAvailable => 'אין נתונים זמינים';

  @override
  String get settings_conflict_previous_tooltip => 'ההתנגשות הקודמת';

  @override
  String get settings_conflict_remoteVersion => 'גרסה מרוחקת';

  @override
  String settings_conflict_resolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count התנגשויות',
      one: 'התנגשות אחת',
    );
    return 'נפתרו $_temp0';
  }

  @override
  String get settings_conflict_title => 'פתרון התנגשויות';

  @override
  String get settings_data_appDefaultLocation =>
      'מיקום ברירת מחדל של האפליקציה';

  @override
  String get settings_data_backup => 'גיבוי';

  @override
  String get settings_data_backup_subtitle => 'צור גיבוי של הנתונים שלך';

  @override
  String get settings_data_cloudSync => 'סנכרון ענן';

  @override
  String get settings_data_customFolder => 'תיקייה מותאמת אישית';

  @override
  String get settings_data_databaseStorage => 'אחסון מסד נתונים';

  @override
  String get settings_data_export_completed => 'הייצוא הושלם';

  @override
  String get settings_data_export_exporting => 'מייצא...';

  @override
  String settings_data_export_failed(Object error) {
    return 'הייצוא נכשל: $error';
  }

  @override
  String get settings_data_header_backupSync => 'גיבוי וסנכרון';

  @override
  String get settings_data_header_storage => 'אחסון';

  @override
  String get settings_data_import_completed => 'הפעולה הושלמה';

  @override
  String settings_data_import_failed(Object error) {
    return 'הפעולה נכשלה: $error';
  }

  @override
  String get settings_data_offlineMaps => 'מפות לא מקוונות';

  @override
  String get settings_data_offlineMaps_subtitle => 'הורד מפות לשימוש לא מקוון';

  @override
  String get settings_data_restore => 'שחזור';

  @override
  String get settings_data_restoreDialog_cancel => 'ביטול';

  @override
  String get settings_data_restoreDialog_content =>
      'אזהרה: שחזור מגיבוי יחליף את כל הנתונים הנוכחיים בנתוני הגיבוי. לא ניתן לבטל פעולה זו.\n\nהאם אתה בטוח שברצונך להמשיך?';

  @override
  String get settings_data_restoreDialog_restore => 'שחזור';

  @override
  String get settings_data_restoreDialog_title => 'שחזור גיבוי';

  @override
  String get settings_data_restore_subtitle => 'שחזר מגיבוי';

  @override
  String settings_data_syncTime_daysAgo(Object count) {
    return 'לפני $count ימים';
  }

  @override
  String settings_data_syncTime_hoursAgo(Object count) {
    return 'לפני $count שעות';
  }

  @override
  String get settings_data_syncTime_justNow => 'הרגע';

  @override
  String settings_data_syncTime_minutesAgo(Object count) {
    return 'לפני $count דקות';
  }

  @override
  String settings_data_sync_lastSynced(Object time) {
    return 'סנכרון אחרון: $time';
  }

  @override
  String get settings_data_sync_notConfigured => 'לא מוגדר';

  @override
  String get settings_data_sync_syncing => 'מסנכרן...';

  @override
  String get settings_decompression_aboutContent =>
      'גורמי שיפוע (GF) קובעים עד כמה שמרניים חישובי הדקומפרסיה שלך. GF Low משפיע על עצירות עמוקות, בעוד GF High משפיע על עצירות רדודות.\n\nערכים נמוכים יותר = שמרני יותר = עצירות דקו ארוכות יותר\nערכים גבוהים יותר = פחות שמרני = עצירות דקו קצרות יותר';

  @override
  String get settings_decompression_aboutTitle => 'אודות גורמי שיפוע';

  @override
  String get settings_decompression_currentSettings => 'הגדרות נוכחיות';

  @override
  String get settings_decompression_dialog_cancel => 'ביטול';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      'ערכים נמוכים יותר = שמרני יותר (NDL ארוך יותר / יותר דקו)';

  @override
  String get settings_decompression_dialog_customValues =>
      'ערכים מותאמים אישית';

  @override
  String get settings_decompression_dialog_gfHigh => 'GF High';

  @override
  String get settings_decompression_dialog_gfLow => 'GF Low';

  @override
  String get settings_decompression_dialog_info =>
      'GF Low/High קובעים עד כמה שמרניים חישובי ה-NDL והדקו שלך.';

  @override
  String get settings_decompression_dialog_presets => 'הגדרות מוכנות';

  @override
  String get settings_decompression_dialog_save => 'שמירה';

  @override
  String get settings_decompression_dialog_title => 'גורמי שיפוע';

  @override
  String settings_decompression_gfValue(Object gfLow, Object gfHigh) {
    return 'GF $gfLow/$gfHigh';
  }

  @override
  String get settings_decompression_header_gradientFactors => 'גורמי שיפוע';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'בחר הגדרת שמרנות $presetName';
  }

  @override
  String get settings_existingDb_cancel => 'ביטול';

  @override
  String get settings_existingDb_continue => 'המשך';

  @override
  String get settings_existingDb_current => 'נוכחי';

  @override
  String get settings_existingDb_dialog_message =>
      'מסד נתונים של Submersion כבר קיים בתיקייה זו.';

  @override
  String get settings_existingDb_dialog_title => 'נמצא מסד נתונים קיים';

  @override
  String get settings_existingDb_existing => 'קיים';

  @override
  String get settings_existingDb_replaceWarning =>
      'מסד הנתונים הקיים יגובה לפני ההחלפה.';

  @override
  String get settings_existingDb_replaceWithMyData => 'החלף בנתונים שלי';

  @override
  String get settings_existingDb_replaceWithMyData_subtitle =>
      'דרוס במסד הנתונים הנוכחי שלך';

  @override
  String get settings_existingDb_stat_buddies => 'חברי צלילה';

  @override
  String get settings_existingDb_stat_dives => 'צלילות';

  @override
  String get settings_existingDb_stat_sites => 'אתרים';

  @override
  String get settings_existingDb_stat_trips => 'טיולים';

  @override
  String get settings_existingDb_stat_users => 'משתמשים';

  @override
  String get settings_existingDb_unknown => 'לא ידוע';

  @override
  String get settings_existingDb_useExisting => 'השתמש במסד הנתונים הקיים';

  @override
  String get settings_existingDb_useExisting_subtitle =>
      'עבור למסד הנתונים בתיקייה זו';

  @override
  String get settings_gfPreset_custom_description => 'הגדר ערכים משלך';

  @override
  String get settings_gfPreset_custom_name => 'מותאם אישית';

  @override
  String get settings_gfPreset_high_description =>
      'הכי שמרני, עצירות דקו ארוכות יותר';

  @override
  String get settings_gfPreset_high_name => 'גבוה';

  @override
  String get settings_gfPreset_low_description =>
      'הכי פחות שמרני, דקו קצר יותר';

  @override
  String get settings_gfPreset_low_name => 'נמוך';

  @override
  String get settings_gfPreset_medium_description => 'גישה מאוזנת';

  @override
  String get settings_gfPreset_medium_name => 'בינוני';

  @override
  String get settings_import_dialog_title => 'ייבוא נתונים';

  @override
  String get settings_import_doNotClose => 'נא לא לסגור את האפליקציה';

  @override
  String settings_import_itemCount(Object current, Object total) {
    return '$current מתוך $total';
  }

  @override
  String get settings_import_phase_buddies => 'מייבא חברי צלילה...';

  @override
  String get settings_import_phase_certifications => 'מייבא הסמכות...';

  @override
  String get settings_import_phase_complete => 'מסיים...';

  @override
  String get settings_import_phase_diveCenters => 'מייבא מרכזי צלילה...';

  @override
  String get settings_import_phase_diveTypes => 'מייבא סוגי צלילה...';

  @override
  String get settings_import_phase_dives => 'מייבא צלילות...';

  @override
  String get settings_import_phase_equipment => 'מייבא ציוד...';

  @override
  String get settings_import_phase_equipmentSets => 'מייבא ערכות ציוד...';

  @override
  String get settings_import_phase_parsing => 'מנתח קובץ...';

  @override
  String get settings_import_phase_preparing => 'מכין...';

  @override
  String get settings_import_phase_sites => 'מייבא אתרי צלילה...';

  @override
  String get settings_import_phase_tags => 'מייבא תגיות...';

  @override
  String get settings_import_phase_trips => 'מייבא טיולים...';

  @override
  String settings_import_progressLabel(
    Object phase,
    Object current,
    Object total,
  ) {
    return '$phase, $current מתוך $total';
  }

  @override
  String settings_import_progressPercent(Object percent) {
    return 'התקדמות ייבוא: $percent אחוז';
  }

  @override
  String get settings_language_appBar_title => 'שפה';

  @override
  String get settings_language_selected => 'נבחר';

  @override
  String get settings_language_systemDefault => 'ברירת מחדל של המערכת';

  @override
  String get settings_manage_diveTypes => 'סוגי צלילה';

  @override
  String get settings_manage_diveTypes_subtitle =>
      'ניהול סוגי צלילה מותאמים אישית';

  @override
  String get settings_manage_header_manageData => 'ניהול נתונים';

  @override
  String get settings_manage_species => 'מינים';

  @override
  String get settings_manage_species_subtitle => 'ניהול קטלוג מיני חי ימי';

  @override
  String get settings_manage_tankPresets => 'הגדרות בלון מוכנות';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'ניהול תצורות בלון מותאמות אישית';

  @override
  String get settings_migrationProgress_doNotClose =>
      'נא לא לסגור את האפליקציה';

  @override
  String get settings_migration_backupInfo =>
      'ייווצר גיבוי לפני ההעברה. הנתונים שלך לא יאבדו.';

  @override
  String get settings_migration_cancel => 'ביטול';

  @override
  String get settings_migration_cloudSyncWarning =>
      'סנכרון ענן מנוהל אפליקציה יושבת. שירות הסנכרון של התיקייה שלך יטפל בסנכרון.';

  @override
  String get settings_migration_dialog_message => 'מסד הנתונים שלך יועבר:';

  @override
  String get settings_migration_dialog_title => 'להעביר מסד נתונים?';

  @override
  String get settings_migration_from => 'מ';

  @override
  String get settings_migration_moveDatabase => 'העבר מסד נתונים';

  @override
  String get settings_migration_to => 'אל';

  @override
  String settings_notifications_days(Object count) {
    return '$count ימים';
  }

  @override
  String get settings_notifications_disabled_enableButton => 'אפשר';

  @override
  String get settings_notifications_disabled_subtitle =>
      'אפשר בהגדרות המערכת כדי לקבל תזכורות';

  @override
  String get settings_notifications_disabled_title => 'התראות מושבתות';

  @override
  String get settings_notifications_enableServiceReminders =>
      'אפשר תזכורות תחזוקה';

  @override
  String get settings_notifications_enableServiceReminders_subtitle =>
      'קבל התראה כאשר תחזוקת ציוד נדרשת';

  @override
  String get settings_notifications_header_reminderSchedule =>
      'לוח זמנים לתזכורות';

  @override
  String get settings_notifications_header_serviceReminders => 'תזכורות תחזוקה';

  @override
  String get settings_notifications_howItWorks_content =>
      'התראות מתוזמנות בעת הפעלת האפליקציה ומתעדכנות מעת לעת ברקע. ניתן להתאים אישית תזכורות לפריטי ציוד בודדים במסך העריכה שלהם.';

  @override
  String get settings_notifications_howItWorks_title => 'איך זה עובד';

  @override
  String get settings_notifications_permissionRequired =>
      'נא לאפשר התראות בהגדרות המערכת';

  @override
  String get settings_notifications_remindBeforeDue =>
      'הזכר לי לפני שתחזוקה נדרשת:';

  @override
  String get settings_notifications_reminderTime => 'שעת תזכורת';

  @override
  String get settings_profile_activeDiver_subtitle => 'צולל פעיל - הקש להחלפה';

  @override
  String get settings_profile_addNewDiver => 'הוסף צולל חדש';

  @override
  String get settings_profile_error_loadingDiver => 'שגיאה בטעינת צולל';

  @override
  String get settings_profile_header_activeDiver => 'צולל פעיל';

  @override
  String get settings_profile_header_manageDivers => 'ניהול צוללים';

  @override
  String get settings_profile_noDiverProfile => 'אין פרופיל צולל';

  @override
  String get settings_profile_noDiverProfile_subtitle =>
      'הקש ליצירת הפרופיל שלך';

  @override
  String get settings_profile_switchDiver_title => 'החלף צולל';

  @override
  String settings_profile_switchedTo(Object diverName) {
    return 'עבר אל $diverName';
  }

  @override
  String get settings_profile_viewAllDivers => 'הצג את כל הצוללים';

  @override
  String get settings_profile_viewAllDivers_subtitle =>
      'הוסף או ערוך פרופילי צוללים';

  @override
  String get settings_section_about_subtitle => 'מידע על האפליקציה ורישיונות';

  @override
  String get settings_section_about_title => 'אודות';

  @override
  String get settings_section_appearance_subtitle => 'ערכת נושא ותצוגה';

  @override
  String get settings_section_appearance_title => 'מראה';

  @override
  String get settings_section_data_subtitle => 'גיבוי, שחזור ואחסון';

  @override
  String get settings_section_data_title => 'נתונים';

  @override
  String get settings_section_decompression_subtitle => 'גורמי שיפוע';

  @override
  String get settings_section_decompression_title => 'דקומפרסיה';

  @override
  String get settings_section_diverProfile_subtitle => 'צולל פעיל ופרופילים';

  @override
  String get settings_section_diverProfile_title => 'פרופיל צולל';

  @override
  String get settings_section_manage_subtitle => 'סוגי צלילה והגדרות בלון';

  @override
  String get settings_section_manage_title => 'ניהול';

  @override
  String get settings_section_notifications_subtitle => 'תזכורות תחזוקה';

  @override
  String get settings_section_notifications_title => 'התראות';

  @override
  String get settings_section_units_subtitle => 'העדפות מדידה';

  @override
  String get settings_section_units_title => 'יחידות';

  @override
  String get settings_storage_appBar_title => 'אחסון מסד נתונים';

  @override
  String get settings_storage_appDefault => 'ברירת מחדל של האפליקציה';

  @override
  String get settings_storage_appDefaultLocation =>
      'מיקום ברירת מחדל של האפליקציה';

  @override
  String get settings_storage_appDefault_subtitle =>
      'מיקום אחסון סטנדרטי של האפליקציה';

  @override
  String get settings_storage_currentLocation => 'מיקום נוכחי';

  @override
  String get settings_storage_currentLocation_label => 'מיקום נוכחי';

  @override
  String get settings_storage_customFolder => 'תיקייה מותאמת אישית';

  @override
  String get settings_storage_customFolder_change => 'שנה';

  @override
  String get settings_storage_customFolder_subtitle =>
      'בחר תיקייה מסונכרנת (Dropbox, Google Drive וכו\')';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize • $diveCount צלילות • $siteCount אתרים';
  }

  @override
  String get settings_storage_dismissError_tooltip => 'סגור שגיאה';

  @override
  String get settings_storage_dismissSuccess_tooltip => 'סגור הודעת הצלחה';

  @override
  String get settings_storage_header_storageLocation => 'מיקום אחסון';

  @override
  String get settings_storage_info_customActive =>
      'סנכרון ענן מנוהל אפליקציה מושבת. שירות הסנכרון של התיקייה שלך (Dropbox, Google Drive וכו\') מטפל בסנכרון.';

  @override
  String get settings_storage_info_customAvailable =>
      'שימוש בתיקייה מותאמת אישית משבית סנכרון ענן מנוהל אפליקציה. שירות הסנכרון של התיקייה שלך יטפל בסנכרון במקום.';

  @override
  String get settings_storage_loading => 'טוען...';

  @override
  String get settings_storage_migrating_doNotClose =>
      'נא לא לסגור את האפליקציה';

  @override
  String get settings_storage_migrating_movingDatabase => 'מעביר מסד נתונים...';

  @override
  String get settings_storage_migrating_movingToAppDefault =>
      'מעביר לברירת מחדל של האפליקציה...';

  @override
  String get settings_storage_migrating_replacingExisting =>
      'מחליף מסד נתונים קיים...';

  @override
  String get settings_storage_migrating_switchingToExisting =>
      'עובר למסד נתונים קיים...';

  @override
  String get settings_storage_notSet => 'לא הוגדר';

  @override
  String settings_storage_success_backupAt(Object path) {
    return 'המקור נשמר כגיבוי ב:\n$path';
  }

  @override
  String get settings_storage_success_moved => 'מסד הנתונים הועבר בהצלחה';

  @override
  String get settings_summary_activeDiver => 'צולל פעיל';

  @override
  String get settings_summary_currentConfiguration => 'תצורה נוכחית';

  @override
  String get settings_summary_depth => 'עומק';

  @override
  String get settings_summary_error => 'שגיאה';

  @override
  String get settings_summary_gradientFactors => 'גורמי שיפוע';

  @override
  String get settings_summary_loading => 'טוען...';

  @override
  String get settings_summary_notSet => 'לא הוגדר';

  @override
  String get settings_summary_pressure => 'לחץ';

  @override
  String get settings_summary_subtitle => 'בחר קטגוריה להגדרה';

  @override
  String get settings_summary_temperature => 'טמפרטורה';

  @override
  String get settings_summary_theme => 'ערכת נושא';

  @override
  String get settings_summary_theme_dark => 'כהה';

  @override
  String get settings_summary_theme_light => 'בהיר';

  @override
  String get settings_summary_theme_system => 'מערכת';

  @override
  String get settings_summary_tip =>
      'טיפ: השתמש בסעיף נתונים כדי לגבות את יומני הצלילה שלך באופן קבוע.';

  @override
  String get settings_summary_title => 'הגדרות';

  @override
  String get settings_summary_unitPreferences => 'העדפות יחידות';

  @override
  String get settings_summary_units => 'יחידות';

  @override
  String get settings_summary_volume => 'נפח';

  @override
  String get settings_summary_weight => 'משקל';

  @override
  String get settings_units_custom => 'מותאם אישית';

  @override
  String get settings_units_dateFormat => 'פורמט תאריך';

  @override
  String get settings_units_depth => 'עומק';

  @override
  String get settings_units_depth_feet => 'רגל (ft)';

  @override
  String get settings_units_depth_meters => 'מטרים (m)';

  @override
  String get settings_units_dialog_dateFormat => 'פורמט תאריך';

  @override
  String get settings_units_dialog_depthUnit => 'יחידת עומק';

  @override
  String get settings_units_dialog_pressureUnit => 'יחידת לחץ';

  @override
  String get settings_units_dialog_sacRateUnit => 'יחידת קצב SAC';

  @override
  String get settings_units_dialog_temperatureUnit => 'יחידת טמפרטורה';

  @override
  String get settings_units_dialog_timeFormat => 'פורמט שעה';

  @override
  String get settings_units_dialog_volumeUnit => 'יחידת נפח';

  @override
  String get settings_units_dialog_weightUnit => 'יחידת משקל';

  @override
  String get settings_units_header_individualUnits => 'יחידות בודדות';

  @override
  String get settings_units_header_timeDateFormat => 'פורמט שעה ותאריך';

  @override
  String get settings_units_header_unitSystem => 'מערכת יחידות';

  @override
  String get settings_units_imperial => 'אימפריאלי';

  @override
  String get settings_units_metric => 'מטרי';

  @override
  String get settings_units_pressure => 'לחץ';

  @override
  String get settings_units_pressure_bar => 'Bar';

  @override
  String get settings_units_pressure_psi => 'PSI';

  @override
  String get settings_units_quickSelect => 'בחירה מהירה';

  @override
  String get settings_units_sacRate => 'קצב SAC';

  @override
  String get settings_units_sac_pressurePerMinute => 'לחץ לדקה';

  @override
  String get settings_units_sac_pressurePerMinute_subtitle =>
      'ללא צורך בנפח בלון (bar/min או psi/min)';

  @override
  String get settings_units_sac_volumePerMinute => 'נפח לדקה';

  @override
  String get settings_units_sac_volumePerMinute_subtitle =>
      'דורש נפח בלון (L/min או cuft/min)';

  @override
  String get settings_units_temperature => 'טמפרטורה';

  @override
  String get settings_units_temperature_celsius => 'צלזיוס (°C)';

  @override
  String get settings_units_temperature_fahrenheit => 'פרנהייט (°F)';

  @override
  String get settings_units_timeFormat => 'פורמט שעה';

  @override
  String get settings_units_volume => 'נפח';

  @override
  String get settings_units_volume_cubicFeet => 'רגל מעוקב (cuft)';

  @override
  String get settings_units_volume_liters => 'ליטרים (L)';

  @override
  String get settings_units_weight => 'משקל';

  @override
  String get settings_units_weight_kilograms => 'קילוגרם (kg)';

  @override
  String get settings_units_weight_pounds => 'ליברות (lbs)';

  @override
  String get signatures_action_clear => 'נקה';

  @override
  String get signatures_action_closeSignatureView => 'סגור תצוגת חתימה';

  @override
  String get signatures_action_deleteSignature => 'מחק חתימה';

  @override
  String get signatures_action_done => 'סיום';

  @override
  String get signatures_action_readyToSign => 'מוכן לחתימה';

  @override
  String get signatures_action_request => 'בקש';

  @override
  String get signatures_action_saveSignature => 'שמור חתימה';

  @override
  String signatures_buddyCard_notSignedSemantics(Object name) {
    return 'חתימת $name, לא נחתם';
  }

  @override
  String signatures_buddyCard_signedSemantics(Object name) {
    return 'חתימת $name, נחתם';
  }

  @override
  String get signatures_captureInstructorSignature => 'לכוד חתימת מדריך';

  @override
  String signatures_deleteDialog_message(Object name) {
    return 'האם אתה בטוח שברצונך למחוק את החתימה של $name? לא ניתן לבטל פעולה זו.';
  }

  @override
  String get signatures_deleteDialog_title => 'למחוק חתימה?';

  @override
  String get signatures_drawSignatureHint => 'שרטט את החתימה שלך למעלה';

  @override
  String get signatures_drawSignatureHintDetailed =>
      'שרטט חתימה למעלה באמצעות אצבע או עט';

  @override
  String get signatures_drawSignatureSemantics => 'שרטט חתימה';

  @override
  String get signatures_error_drawSignature => 'נא לשרטט חתימה';

  @override
  String get signatures_error_enterSignerName => 'נא להזין שם החותם';

  @override
  String get signatures_field_instructorName => 'שם המדריך';

  @override
  String get signatures_field_instructorNameHint => 'הזן שם מדריך';

  @override
  String get signatures_handoff_title => 'העבר את המכשיר ל';

  @override
  String get signatures_instructorSignature => 'חתימת מדריך';

  @override
  String get signatures_noSignatureImage => 'אין תמונת חתימה';

  @override
  String signatures_signHere(Object name) {
    return '$name - חתום כאן';
  }

  @override
  String get signatures_signed => 'נחתם';

  @override
  String signatures_signedCountSemantics(Object signed, Object total) {
    return '$signed מתוך $total חברי צוללים חתמו';
  }

  @override
  String signatures_signedDate(Object date) {
    return 'נחתם ב-$date';
  }

  @override
  String get signatures_title => 'חתימות';

  @override
  String get signatures_viewSignature => 'הצג חתימה';

  @override
  String signatures_viewSignatureSemantics(Object name) {
    return 'הצג חתימה של $name';
  }

  @override
  String get statistics_appBar_title => 'סטטיסטיקות';

  @override
  String statistics_categoryCard_semanticLabel(Object title) {
    return 'קטגוריית סטטיסטיקות $title';
  }

  @override
  String get statistics_category_conditions_subtitle => 'ראות וטמפרטורה';

  @override
  String get statistics_category_conditions_title => 'תנאים';

  @override
  String get statistics_category_equipment_subtitle => 'שימוש בציוד ומשקל';

  @override
  String get statistics_category_equipment_title => 'ציוד';

  @override
  String get statistics_category_gas_subtitle => 'קצבי SAC ותערובות גזים';

  @override
  String get statistics_category_gas_title => 'צריכת אוויר';

  @override
  String get statistics_category_geographic_subtitle => 'מדינות ואזורים';

  @override
  String get statistics_category_geographic_title => 'גיאוגרפיה';

  @override
  String get statistics_category_marineLife_subtitle => 'תצפיות מינים';

  @override
  String get statistics_category_marineLife_title => 'חיים ימיים';

  @override
  String get statistics_category_profile_subtitle => 'קצבי עלייה ודקו';

  @override
  String get statistics_category_profile_title => 'ניתוח פרופיל';

  @override
  String get statistics_category_progression_subtitle => 'מגמות עומק וזמן';

  @override
  String get statistics_category_progression_title => 'התקדמות';

  @override
  String get statistics_category_social_subtitle => 'שותפים ומרכזי צלילה';

  @override
  String get statistics_category_social_title => 'חברתי';

  @override
  String get statistics_category_timePatterns_subtitle => 'מתי אתה צולל';

  @override
  String get statistics_category_timePatterns_title => 'דפוסי זמן';

  @override
  String statistics_chart_barSemanticLabel(Object count) {
    return 'תרשים עמודות עם $count קטגוריות';
  }

  @override
  String statistics_chart_distributionSemanticLabel(Object count) {
    return 'תרשים עוגה עם $count מקטעים';
  }

  @override
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames) {
    return 'תרשים מגמה רב-קווי המשווה $seriesNames';
  }

  @override
  String get statistics_chart_noBarData => 'אין נתונים זמינים';

  @override
  String get statistics_chart_noDistributionData => 'אין נתוני התפלגות זמינים';

  @override
  String get statistics_chart_noTrendData => 'אין נתוני מגמה זמינים';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return 'תרשים קו מגמה המציג $count נקודות נתונים';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return 'תרשים קו מגמה המציג $count נקודות נתונים עבור $yAxisLabel';
  }

  @override
  String get statistics_conditions_appBar_title => 'תנאים';

  @override
  String get statistics_conditions_entryMethod_empty =>
      'אין נתוני שיטת כניסה זמינים';

  @override
  String get statistics_conditions_entryMethod_error =>
      'שגיאה בטעינת נתוני שיטת כניסה';

  @override
  String get statistics_conditions_entryMethod_subtitle => 'חוף, סירה וכו\'';

  @override
  String get statistics_conditions_entryMethod_title => 'שיטת כניסה';

  @override
  String get statistics_conditions_temperature_empty =>
      'אין נתוני טמפרטורה זמינים';

  @override
  String get statistics_conditions_temperature_error =>
      'שגיאה בטעינת נתוני טמפרטורה';

  @override
  String get statistics_conditions_temperature_seriesAvg => 'ממוצע';

  @override
  String get statistics_conditions_temperature_seriesMax => 'מקסימום';

  @override
  String get statistics_conditions_temperature_seriesMin => 'מינימום';

  @override
  String get statistics_conditions_temperature_subtitle =>
      'טמפרטורות מינ\'/ממוצע/מקס\'';

  @override
  String get statistics_conditions_temperature_title => 'טמפרטורת מים לפי חודש';

  @override
  String get statistics_conditions_visibility_error =>
      'שגיאה בטעינת נתוני ראות';

  @override
  String get statistics_conditions_visibility_subtitle =>
      'צלילות לפי תנאי ראות';

  @override
  String get statistics_conditions_visibility_title => 'התפלגות ראות';

  @override
  String get statistics_conditions_waterType_error =>
      'שגיאה בטעינת נתוני סוג מים';

  @override
  String get statistics_conditions_waterType_subtitle =>
      'צלילות במים מלוחים לעומת מתוקים';

  @override
  String get statistics_conditions_waterType_title => 'סוג מים';

  @override
  String get statistics_equipment_appBar_title => 'ציוד';

  @override
  String get statistics_equipment_mostUsedGear_error =>
      'שגיאה בטעינת נתוני ציוד';

  @override
  String get statistics_equipment_mostUsedGear_subtitle =>
      'ציוד לפי מספר צלילות';

  @override
  String get statistics_equipment_mostUsedGear_title => 'הציוד הנפוץ ביותר';

  @override
  String get statistics_equipment_weightTrend_error => 'שגיאה בטעינת מגמת משקל';

  @override
  String get statistics_equipment_weightTrend_subtitle =>
      'משקל ממוצע לאורך זמן';

  @override
  String get statistics_equipment_weightTrend_title => 'מגמת משקל';

  @override
  String get statistics_error_loadingStatistics => 'שגיאה בטעינת סטטיסטיקות';

  @override
  String get statistics_gas_appBar_title => 'צריכת אוויר';

  @override
  String get statistics_gas_gasMix_error => 'שגיאה בטעינת נתוני תערובת גזים';

  @override
  String get statistics_gas_gasMix_subtitle => 'צלילות לפי סוג גז';

  @override
  String get statistics_gas_gasMix_title => 'התפלגות תערובות גזים';

  @override
  String get statistics_gas_sacByRole_empty => 'אין נתוני ריבוי בלונים זמינים';

  @override
  String get statistics_gas_sacByRole_error => 'שגיאה בטעינת SAC לפי תפקיד';

  @override
  String get statistics_gas_sacByRole_subtitle => 'צריכה ממוצעת לפי סוג בלון';

  @override
  String get statistics_gas_sacByRole_title => 'SAC לפי תפקיד בלון';

  @override
  String get statistics_gas_sacRecords_best => 'קצב SAC הטוב ביותר';

  @override
  String get statistics_gas_sacRecords_empty => 'אין עדיין נתוני SAC זמינים';

  @override
  String get statistics_gas_sacRecords_error => 'שגיאה בטעינת שיאי SAC';

  @override
  String get statistics_gas_sacRecords_highest => 'קצב SAC הגבוה ביותר';

  @override
  String get statistics_gas_sacRecords_subtitle =>
      'צריכת אוויר הטובה והגרועה ביותר';

  @override
  String get statistics_gas_sacRecords_title => 'שיאי קצב SAC';

  @override
  String get statistics_gas_sacTrend_error => 'שגיאה בטעינת מגמת SAC';

  @override
  String get statistics_gas_sacTrend_subtitle => 'ממוצע חודשי על פני 5 שנים';

  @override
  String get statistics_gas_sacTrend_title => 'מגמת קצב SAC';

  @override
  String get statistics_gas_tankRole_backGas => 'גז ראשי';

  @override
  String get statistics_gas_tankRole_bailout => 'חילוץ';

  @override
  String get statistics_gas_tankRole_deco => 'דקו';

  @override
  String get statistics_gas_tankRole_diluent => 'מדלל';

  @override
  String get statistics_gas_tankRole_oxygenSupply => 'אספקת O₂';

  @override
  String get statistics_gas_tankRole_pony => 'פוני';

  @override
  String get statistics_gas_tankRole_sidemountLeft => 'סיידמאונט שמאל';

  @override
  String get statistics_gas_tankRole_sidemountRight => 'סיידמאונט ימין';

  @override
  String get statistics_gas_tankRole_stage => 'סטייג\'';

  @override
  String get statistics_geographic_appBar_title => 'גיאוגרפיה';

  @override
  String get statistics_geographic_countries_empty => 'לא ביקרת במדינות';

  @override
  String get statistics_geographic_countries_error =>
      'שגיאה בטעינת נתוני מדינות';

  @override
  String get statistics_geographic_countries_subtitle => 'צלילות לפי מדינה';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count מדינות. מוביל: $topName עם $topCount צלילות';
  }

  @override
  String get statistics_geographic_countries_title => 'מדינות שביקרת בהן';

  @override
  String get statistics_geographic_regions_empty => 'לא נחקרו אזורים';

  @override
  String get statistics_geographic_regions_error => 'שגיאה בטעינת נתוני אזורים';

  @override
  String get statistics_geographic_regions_subtitle => 'צלילות לפי אזור';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count אזורים. מוביל: $topName עם $topCount צלילות';
  }

  @override
  String get statistics_geographic_regions_title => 'אזורים שנחקרו';

  @override
  String get statistics_geographic_trips_empty => 'אין נתוני טיולים';

  @override
  String get statistics_geographic_trips_error => 'שגיאה בטעינת נתוני טיולים';

  @override
  String get statistics_geographic_trips_subtitle => 'הטיולים הפוריים ביותר';

  @override
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count טיולים. מוביל: $topName עם $topCount צלילות';
  }

  @override
  String get statistics_geographic_trips_title => 'צלילות לפי טיול';

  @override
  String get statistics_listContent_selectedSuffix => ', נבחר';

  @override
  String get statistics_marineLife_appBar_title => 'חיים ימיים';

  @override
  String get statistics_marineLife_bestSites_empty => 'אין נתוני אתרים';

  @override
  String get statistics_marineLife_bestSites_error =>
      'שגיאה בטעינת נתוני אתרים';

  @override
  String get statistics_marineLife_bestSites_subtitle =>
      'אתרים עם מגוון המינים הגדול ביותר';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count אתרים. הטוב ביותר: $topName עם $topCount מינים';
  }

  @override
  String get statistics_marineLife_bestSites_title =>
      'האתרים הטובים ביותר לחיים ימיים';

  @override
  String get statistics_marineLife_mostCommon_empty => 'אין נתוני תצפיות';

  @override
  String get statistics_marineLife_mostCommon_error =>
      'שגיאה בטעינת נתוני תצפיות';

  @override
  String get statistics_marineLife_mostCommon_subtitle =>
      'המינים שנצפו בתדירות הגבוהה ביותר';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count מינים. הנפוץ ביותר: $topName עם $topCount תצפיות';
  }

  @override
  String get statistics_marineLife_mostCommon_title => 'התצפיות הנפוצות ביותר';

  @override
  String get statistics_marineLife_speciesSpotted => 'מינים שנצפו';

  @override
  String get statistics_profile_appBar_title => 'ניתוח פרופיל';

  @override
  String get statistics_profile_ascentDescent_empty =>
      'אין נתוני פרופיל זמינים';

  @override
  String get statistics_profile_ascentDescent_error => 'שגיאה בטעינת נתוני קצב';

  @override
  String get statistics_profile_ascentDescent_subtitle =>
      'מנתוני פרופיל הצלילה';

  @override
  String get statistics_profile_ascentDescent_title =>
      'קצבי עלייה וירידה ממוצעים';

  @override
  String get statistics_profile_avgAscent => 'עלייה ממוצעת';

  @override
  String get statistics_profile_avgDescent => 'ירידה ממוצעת';

  @override
  String get statistics_profile_deco_decoDives => 'צלילות דקו';

  @override
  String get statistics_profile_deco_decoLabel => 'דקו';

  @override
  String get statistics_profile_deco_decoRate => 'שיעור דקו';

  @override
  String get statistics_profile_deco_empty => 'אין נתוני דקו זמינים';

  @override
  String get statistics_profile_deco_error => 'שגיאה בטעינת נתוני דקו';

  @override
  String get statistics_profile_deco_noDeco => 'ללא דקו';

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return 'שיעור דקומפרסיה: $percentage% מהצלילות דרשו עצירות דקו';
  }

  @override
  String get statistics_profile_deco_subtitle => 'צלילות שדרשו עצירות דקו';

  @override
  String get statistics_profile_deco_title => 'חובת דקומפרסיה';

  @override
  String get statistics_profile_timeAtDepth_empty => 'אין נתוני עומק זמינים';

  @override
  String get statistics_profile_timeAtDepth_error =>
      'שגיאה בטעינת נתוני טווח עומק';

  @override
  String get statistics_profile_timeAtDepth_subtitle => 'זמן משוער בכל עומק';

  @override
  String get statistics_profile_timeAtDepth_title => 'זמן בטווחי עומק';

  @override
  String statistics_profile_timeAtDepth_valueFormat(Object value) {
    return '$value min';
  }

  @override
  String get statistics_progression_appBar_title => 'התקדמות צלילה';

  @override
  String get statistics_progression_bottomTime_error =>
      'שגיאה בטעינת מגמת זמן תחתית';

  @override
  String get statistics_progression_bottomTime_subtitle => 'משך ממוצע לפי חודש';

  @override
  String get statistics_progression_bottomTime_title => 'מגמת זמן תחתית';

  @override
  String get statistics_progression_cumulative_error =>
      'שגיאה בטעינת נתונים מצטברים';

  @override
  String get statistics_progression_cumulative_subtitle =>
      'סה\"כ צלילות לאורך זמן';

  @override
  String get statistics_progression_cumulative_title => 'ספירת צלילות מצטברת';

  @override
  String get statistics_progression_depthProgression_error =>
      'שגיאה בטעינת התקדמות עומק';

  @override
  String get statistics_progression_depthProgression_subtitle =>
      'עומק מקסימלי חודשי על פני 5 שנים';

  @override
  String get statistics_progression_depthProgression_title =>
      'התקדמות עומק מקסימלי';

  @override
  String get statistics_progression_divesPerYear_empty =>
      'אין נתונים שנתיים זמינים';

  @override
  String get statistics_progression_divesPerYear_error =>
      'שגיאה בטעינת נתונים שנתיים';

  @override
  String get statistics_progression_divesPerYear_subtitle =>
      'השוואת ספירת צלילות שנתית';

  @override
  String get statistics_progression_divesPerYear_title => 'צלילות לפי שנה';

  @override
  String get statistics_ranking_countLabel_dives => 'צלילות';

  @override
  String get statistics_ranking_countLabel_sightings => 'תצפיות';

  @override
  String get statistics_ranking_countLabel_species => 'מינים';

  @override
  String get statistics_ranking_emptyState => 'אין עדיין נתונים';

  @override
  String statistics_ranking_itemCount(Object count, Object label) {
    return '$count $label';
  }

  @override
  String statistics_ranking_moreItems(Object count) {
    return 'ועוד $count';
  }

  @override
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  ) {
    return '$name, דירוג $rank, $count $label';
  }

  @override
  String get statistics_records_appBar_title => 'שיאי צלילה';

  @override
  String get statistics_records_coldestDive => 'הצלילה הקרה ביותר';

  @override
  String get statistics_records_deepestDive => 'הצלילה העמוקה ביותר';

  @override
  String statistics_records_diveNumber(Object number) {
    return 'צלילה #$number';
  }

  @override
  String get statistics_records_emptySubtitle =>
      'התחל לרשום צלילות כדי לראות את השיאים שלך כאן';

  @override
  String get statistics_records_emptyTitle => 'אין עדיין שיאים';

  @override
  String get statistics_records_error => 'שגיאה בטעינת שיאים';

  @override
  String get statistics_records_firstDive => 'הצלילה הראשונה';

  @override
  String get statistics_records_longestDive => 'הצלילה הארוכה ביותר';

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
  String get statistics_records_milestones => 'אבני דרך';

  @override
  String get statistics_records_mostRecentDive => 'הצלילה האחרונה';

  @override
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  ) {
    return '$title: $value ב-$siteName';
  }

  @override
  String get statistics_records_retry => 'נסה שוב';

  @override
  String get statistics_records_shallowestDive => 'הצלילה הרדודה ביותר';

  @override
  String get statistics_records_unknownSite => 'אתר לא ידוע';

  @override
  String get statistics_records_warmestDive => 'הצלילה החמה ביותר';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return 'מקטע $title';
  }

  @override
  String get statistics_social_appBar_title => 'חברתי ושותפים';

  @override
  String get statistics_social_soloVsBuddy_empty => 'אין נתוני צלילה זמינים';

  @override
  String get statistics_social_soloVsBuddy_error => 'שגיאה בטעינת נתוני שותפים';

  @override
  String get statistics_social_soloVsBuddy_solo => 'סולו';

  @override
  String get statistics_social_soloVsBuddy_subtitle => 'צלילה עם או בלי שותפים';

  @override
  String get statistics_social_soloVsBuddy_title => 'צלילות סולו לעומת שותף';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => 'עם שותף';

  @override
  String get statistics_social_topBuddies_error => 'שגיאה בטעינת דירוג שותפים';

  @override
  String get statistics_social_topBuddies_subtitle =>
      'שותפי הצלילה השכיחים ביותר';

  @override
  String get statistics_social_topBuddies_title => 'שותפי הצלילה המובילים';

  @override
  String get statistics_social_topDiveCenters_error =>
      'שגיאה בטעינת דירוג מרכזי צלילה';

  @override
  String get statistics_social_topDiveCenters_subtitle =>
      'המפעילים הנצפים ביותר';

  @override
  String get statistics_social_topDiveCenters_title => 'מרכזי הצלילה המובילים';

  @override
  String get statistics_summary_avgDepth => 'עומק ממוצע';

  @override
  String get statistics_summary_avgTemp => 'טמפ\' ממוצעת';

  @override
  String get statistics_summary_depthDistribution_empty =>
      'התרשים יופיע כשתרשום צלילות';

  @override
  String get statistics_summary_depthDistribution_semanticLabel =>
      'תרשים עוגה המציג התפלגות עומק';

  @override
  String get statistics_summary_depthDistribution_title => 'התפלגות עומק';

  @override
  String get statistics_summary_diveTypes_empty =>
      'התרשים יופיע כשתרשום צלילות';

  @override
  String statistics_summary_diveTypes_moreTypes(Object count) {
    return 'ועוד $count סוגים';
  }

  @override
  String get statistics_summary_diveTypes_semanticLabel =>
      'תרשים עוגה המציג התפלגות סוגי צלילה';

  @override
  String get statistics_summary_diveTypes_title => 'סוגי צלילה';

  @override
  String get statistics_summary_divesByMonth_empty =>
      'התרשים יופיע כשתרשום צלילות';

  @override
  String get statistics_summary_divesByMonth_semanticLabel =>
      'תרשים עמודות המציג צלילות לפי חודש';

  @override
  String get statistics_summary_divesByMonth_title => 'צלילות לפי חודש';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel\n$count צלילות';
  }

  @override
  String get statistics_summary_header_subtitle =>
      'בחר קטגוריה כדי לחקור סטטיסטיקות מפורטות';

  @override
  String get statistics_summary_header_title => 'סקירת סטטיסטיקות';

  @override
  String get statistics_summary_maxDepth => 'עומק מקסימלי';

  @override
  String get statistics_summary_sitesVisited => 'אתרים שביקרת';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות',
      one: 'צלילה אחת',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty => 'לא נוצרו עדיין תגיות';

  @override
  String get statistics_summary_tagUsage_emptyHint =>
      'הוסף תגיות לצלילות כדי לראות סטטיסטיקות';

  @override
  String statistics_summary_tagUsage_moreTags(Object count) {
    return 'ועוד $count תגיות';
  }

  @override
  String statistics_summary_tagUsage_tagCount(Object count) {
    return '$count תגיות';
  }

  @override
  String get statistics_summary_tagUsage_title => 'שימוש בתגיות';

  @override
  String statistics_summary_topDiveSites_diveCount(Object count) {
    return '$count צלילות';
  }

  @override
  String get statistics_summary_topDiveSites_empty => 'אין עדיין אתרי צלילה';

  @override
  String get statistics_summary_topDiveSites_title => 'אתרי הצלילה המובילים';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count סה\"כ';
  }

  @override
  String get statistics_summary_totalDives => 'סה\"כ צלילות';

  @override
  String get statistics_summary_totalTime => 'זמן כולל';

  @override
  String get statistics_timePatterns_appBar_title => 'דפוסי זמן';

  @override
  String get statistics_timePatterns_dayOfWeek_empty => 'אין נתונים זמינים';

  @override
  String get statistics_timePatterns_dayOfWeek_error =>
      'שגיאה בטעינת נתוני ימי השבוע';

  @override
  String get statistics_timePatterns_dayOfWeek_fri => 'שישי';

  @override
  String get statistics_timePatterns_dayOfWeek_mon => 'שני';

  @override
  String get statistics_timePatterns_dayOfWeek_sat => 'שבת';

  @override
  String get statistics_timePatterns_dayOfWeek_subtitle =>
      'מתי אתה צולל הכי הרבה?';

  @override
  String get statistics_timePatterns_dayOfWeek_sun => 'ראשון';

  @override
  String get statistics_timePatterns_dayOfWeek_thu => 'חמישי';

  @override
  String get statistics_timePatterns_dayOfWeek_title => 'צלילות לפי יום בשבוע';

  @override
  String get statistics_timePatterns_dayOfWeek_tue => 'שלישי';

  @override
  String get statistics_timePatterns_dayOfWeek_wed => 'רביעי';

  @override
  String get statistics_timePatterns_month_apr => 'אפר\'';

  @override
  String get statistics_timePatterns_month_aug => 'אוג\'';

  @override
  String get statistics_timePatterns_month_dec => 'דצמ\'';

  @override
  String get statistics_timePatterns_month_feb => 'פבר\'';

  @override
  String get statistics_timePatterns_month_jan => 'ינו\'';

  @override
  String get statistics_timePatterns_month_jul => 'יולי';

  @override
  String get statistics_timePatterns_month_jun => 'יוני';

  @override
  String get statistics_timePatterns_month_mar => 'מרץ';

  @override
  String get statistics_timePatterns_month_may => 'מאי';

  @override
  String get statistics_timePatterns_month_nov => 'נוב\'';

  @override
  String get statistics_timePatterns_month_oct => 'אוק\'';

  @override
  String get statistics_timePatterns_month_sep => 'ספט\'';

  @override
  String get statistics_timePatterns_seasonal_empty => 'אין נתונים זמינים';

  @override
  String get statistics_timePatterns_seasonal_error =>
      'שגיאה בטעינת נתונים עונתיים';

  @override
  String get statistics_timePatterns_seasonal_subtitle =>
      'צלילות לפי חודש (כל השנים)';

  @override
  String get statistics_timePatterns_seasonal_title => 'דפוסים עונתיים';

  @override
  String get statistics_timePatterns_surfaceInterval_average => 'ממוצע';

  @override
  String get statistics_timePatterns_surfaceInterval_empty =>
      'אין נתוני מרווח שטח זמינים';

  @override
  String get statistics_timePatterns_surfaceInterval_error =>
      'שגיאה בטעינת נתוני מרווח שטח';

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
  String get statistics_timePatterns_surfaceInterval_maximum => 'מקסימום';

  @override
  String get statistics_timePatterns_surfaceInterval_minimum => 'מינימום';

  @override
  String get statistics_timePatterns_surfaceInterval_subtitle =>
      'זמן בין צלילות';

  @override
  String get statistics_timePatterns_surfaceInterval_title =>
      'סטטיסטיקות מרווח שטח';

  @override
  String get statistics_timePatterns_timeOfDay_error =>
      'שגיאה בטעינת נתוני שעות היום';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle =>
      'בוקר, צהריים, ערב או לילה';

  @override
  String get statistics_timePatterns_timeOfDay_title => 'צלילות לפי שעה ביום';

  @override
  String get statistics_tooltip_diveRecords => 'שיאי צלילה';

  @override
  String get statistics_tooltip_refreshRecords => 'רענן שיאים';

  @override
  String get statistics_tooltip_refreshStatistics => 'רענן סטטיסטיקות';

  @override
  String statistics_valueCard_semanticLabel(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String get surfaceInterval_aboutTissueLoading_body =>
      'לגופך יש 16 תאי רקמה הקולטים ומשחררים חנקן בקצבים שונים. רקמות מהירות (כמו דם) נספגות במהירות אך גם משחררות גז במהירות. רקמות איטיות (כמו עצם ושומן) לוקחות יותר זמן גם לספיגה וגם לפריקה. \"תא מוביל\" הוא התא הכי רווי הקובע בדרך כלל את מגבלת הזמן ללא דקומפרסיה (NDL) שלך. במהלך מרווח שטח, כל הרקמות משחררות גז לעבר רמות רוויה של פני השטח (~40% העמסה).';

  @override
  String get surfaceInterval_aboutTissueLoading_title => 'אודות העמסת רקמות';

  @override
  String get surfaceInterval_action_resetDefaults => 'אפס לברירת מחדל';

  @override
  String get surfaceInterval_disclaimer =>
      'כלי זה מיועד למטרות תכנון בלבד. השתמש תמיד במחשב צלילה ופעל לפי ההכשרה שלך. התוצאות מבוססות על אלגוריתם Buhlmann ZH-L16C ועשויות להיות שונות מהמחשב שלך.';

  @override
  String get surfaceInterval_field_depth => 'עומק';

  @override
  String get surfaceInterval_field_gasMix => 'תערובת גז: ';

  @override
  String get surfaceInterval_field_he => 'He';

  @override
  String get surfaceInterval_field_o2 => 'O₂';

  @override
  String get surfaceInterval_field_time => 'זמן';

  @override
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit) {
    return 'עומק צלילה ראשונה: $depth $unit';
  }

  @override
  String surfaceInterval_firstDive_timeSemantics(Object time) {
    return 'זמן צלילה ראשונה: $time דקות';
  }

  @override
  String get surfaceInterval_firstDive_title => 'צלילה ראשונה';

  @override
  String surfaceInterval_format_hours(Object count) {
    return '$count שעות';
  }

  @override
  String surfaceInterval_format_minutes(Object count) {
    return '$count דקות';
  }

  @override
  String get surfaceInterval_gasMix_air => 'אוויר';

  @override
  String surfaceInterval_gasMix_ean(Object percent) {
    return 'EAN$percent';
  }

  @override
  String surfaceInterval_gasMix_trimix(Object o2, Object he) {
    return 'טרימיקס $o2/$he';
  }

  @override
  String surfaceInterval_heSemantics(Object percent) {
    return 'הליום: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'מרווח נוכחי';

  @override
  String get surfaceInterval_result_inDeco => 'בדקו';

  @override
  String get surfaceInterval_result_increaseInterval =>
      'הגדל מרווח שטח או הקטן עומק/זמן צלילה שנייה';

  @override
  String get surfaceInterval_result_minimumInterval => 'מרווח שטח מינימלי';

  @override
  String get surfaceInterval_result_ndlForSecondDive => 'NDL לצלילה ה-2';

  @override
  String surfaceInterval_result_ndlMinutes(Object minutes) {
    return '$minutes דקות NDL';
  }

  @override
  String get surfaceInterval_result_notYetSafe =>
      'עדיין לא בטוח, הגדל מרווח שטח';

  @override
  String get surfaceInterval_result_safeToDive => 'בטוח לצלול';

  @override
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  ) {
    return 'מרווח שטח מינימלי: $interval. מרווח נוכחי: $current. NDL לצלילה שנייה: $ndl. $status';
  }

  @override
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit) {
    return 'עומק צלילה שנייה: $depth $unit';
  }

  @override
  String get surfaceInterval_secondDive_gasAir => '(אוויר)';

  @override
  String surfaceInterval_secondDive_timeSemantics(Object time) {
    return 'זמן צלילה שנייה: $time דקות';
  }

  @override
  String get surfaceInterval_secondDive_title => 'צלילה שנייה';

  @override
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval) {
    return 'תרשים התאוששות רקמות המציג פריקת גז של 16 תאים במשך מרווח שטח של $interval';
  }

  @override
  String get surfaceInterval_tissueRecovery_compartmentsLabel =>
      'תאים (לפי מהירות זמן מחצית)';

  @override
  String get surfaceInterval_tissueRecovery_description =>
      'מציג כיצד כל אחד מ-16 תאי הרקמה משחרר גז במהלך מרווח השטח';

  @override
  String get surfaceInterval_tissueRecovery_fast => 'מהיר (C1-5)';

  @override
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number) {
    return 'תא מוביל: C$number';
  }

  @override
  String get surfaceInterval_tissueRecovery_loadingPercent => '% העמסה';

  @override
  String get surfaceInterval_tissueRecovery_medium => 'בינוני (C6-10)';

  @override
  String get surfaceInterval_tissueRecovery_min => 'דקה';

  @override
  String get surfaceInterval_tissueRecovery_now => 'עכשיו';

  @override
  String get surfaceInterval_tissueRecovery_slow => 'איטי (C11-16)';

  @override
  String get surfaceInterval_tissueRecovery_title => 'התאוששות רקמות';

  @override
  String get surfaceInterval_title => 'מרווח שטח';

  @override
  String tags_action_createNamed(Object tagName) {
    return 'צור \"$tagName\"';
  }

  @override
  String get tags_action_createTag => 'צור תגית';

  @override
  String get tags_action_deleteTag => 'מחק תגית';

  @override
  String tags_dialog_deleteMessage(Object tagName) {
    return 'האם אתה בטוח שברצונך למחוק את \"$tagName\"? פעולה זו תסיר אותה מכל הצלילות.';
  }

  @override
  String get tags_dialog_deleteTitle => 'למחוק תגית?';

  @override
  String get tags_empty => 'עדיין אין תגיות. צור תגיות בעת עריכת צלילות.';

  @override
  String get tags_hint_addMoreTags => 'הוסף תגיות נוספות...';

  @override
  String get tags_hint_addTags => 'הוסף תגיות...';

  @override
  String get tags_title_manageTags => 'נהל תגיות';

  @override
  String get tank_al30Stage_description => 'בלון סטייג\' אלומיניום 30 cuft';

  @override
  String get tank_al30Stage_displayName => 'AL30 Stage';

  @override
  String get tank_al40Stage_description => 'בלון סטייג\' אלומיניום 40 cuft';

  @override
  String get tank_al40Stage_displayName => 'AL40 Stage';

  @override
  String get tank_al40_description => 'אלומיניום 40 cuft (פוני)';

  @override
  String get tank_al40_displayName => 'AL40';

  @override
  String get tank_al63_description => 'אלומיניום 63 cuft';

  @override
  String get tank_al63_displayName => 'AL63';

  @override
  String get tank_al80_description => 'אלומיניום 80 cuft (הנפוץ ביותר)';

  @override
  String get tank_al80_displayName => 'AL80';

  @override
  String get tank_hp100_description => 'פלדה לחץ גבוה 100 cuft';

  @override
  String get tank_hp100_displayName => 'HP100';

  @override
  String get tank_hp120_description => 'פלדה לחץ גבוה 120 cuft';

  @override
  String get tank_hp120_displayName => 'HP120';

  @override
  String get tank_hp80_description => 'פלדה לחץ גבוה 80 cuft';

  @override
  String get tank_hp80_displayName => 'HP80';

  @override
  String get tank_lp85_description => 'פלדה לחץ נמוך 85 cuft';

  @override
  String get tank_lp85_displayName => 'LP85';

  @override
  String get tank_steel10_description => 'פלדה 10 ליטר (אירופה)';

  @override
  String get tank_steel10_displayName => 'Steel 10L';

  @override
  String get tank_steel12_description => 'פלדה 12 ליטר (אירופה)';

  @override
  String get tank_steel12_displayName => 'Steel 12L';

  @override
  String get tank_steel15_description => 'פלדה 15 ליטר (אירופה)';

  @override
  String get tank_steel15_displayName => 'Steel 15L';

  @override
  String get tides_action_refresh => 'רענן נתוני גאות';

  @override
  String get tides_chart_24hourForecast => 'תחזית 24 שעות';

  @override
  String tides_chart_heightAxis(Object depthSymbol) {
    return 'גובה ($depthSymbol)';
  }

  @override
  String get tides_chart_msl => 'MSL';

  @override
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr) {
    return ' עכשיו $nowTimeStr $nowHeightStr';
  }

  @override
  String get tides_error_unableToLoad => 'לא ניתן לטעון נתוני גאות';

  @override
  String get tides_error_unableToLoadChart => 'לא ניתן לטעון תרשים';

  @override
  String tides_label_ago(Object duration) {
    return 'לפני $duration';
  }

  @override
  String tides_label_currentHeight(Object height, Object depthSymbol) {
    return 'נוכחי: $height$depthSymbol';
  }

  @override
  String tides_label_fromNow(Object duration) {
    return 'בעוד $duration';
  }

  @override
  String get tides_label_high => 'גבוהה';

  @override
  String get tides_label_highIn => 'גאות גבוהה בעוד';

  @override
  String get tides_label_highTide => 'גאות גבוהה';

  @override
  String get tides_label_low => 'נמוכה';

  @override
  String get tides_label_lowIn => 'גאות נמוכה בעוד';

  @override
  String get tides_label_lowTide => 'גאות נמוכה';

  @override
  String tides_label_tideIn(Object duration) {
    return 'בעוד $duration';
  }

  @override
  String get tides_label_tideTimes => 'זמני גאות';

  @override
  String get tides_label_today => 'היום';

  @override
  String get tides_label_tomorrow => 'מחר';

  @override
  String get tides_label_upcomingTides => 'גאות קרובה';

  @override
  String get tides_legend_highTide => 'גאות גבוהה';

  @override
  String get tides_legend_lowTide => 'גאות נמוכה';

  @override
  String get tides_legend_now => 'עכשיו';

  @override
  String get tides_legend_tideLevel => 'רמת גאות';

  @override
  String get tides_noDataAvailable => 'אין נתוני גאות זמינים';

  @override
  String get tides_noDataForLocation => 'נתוני גאות לא זמינים עבור מיקום זה';

  @override
  String get tides_noExtremesData => 'אין נתוני קיצוניות';

  @override
  String get tides_noTideTimesAvailable => 'אין זמני גאות זמינים';

  @override
  String tides_semantic_currentTide(
    Object tideState,
    Object height,
    Object depthSymbol,
    Object nextExtreme,
  ) {
    return 'גאות $tideState, $height$depthSymbol$nextExtreme';
  }

  @override
  String tides_semantic_extremeItem(
    Object typeLabel,
    Object time,
    Object height,
    Object depthSymbol,
  ) {
    return 'גאות $typeLabel ב-$time, $height$depthSymbol';
  }

  @override
  String tides_semantic_tideChart(Object extremesSummary) {
    return 'תרשים גאות. $extremesSummary';
  }

  @override
  String tides_semantic_tideState(Object state) {
    return 'מצב גאות: $state';
  }

  @override
  String get tides_title => 'גאות';

  @override
  String get transfer_appBar_title => 'העברה';

  @override
  String get transfer_computers_aboutContent =>
      'חבר את מחשב הצלילה שלך באמצעות Bluetooth כדי להוריד יומני צלילה ישירות לאפליקציה. מחשבים נתמכים כוללים Suunto, Shearwater, Garmin, Mares ועוד מותגים פופולריים רבים.\n\nמשתמשי Apple Watch Ultra יכולים לייבא נתוני צלילה ישירות מאפליקציית הבריאות, כולל עומק, משך וקצב לב.';

  @override
  String get transfer_computers_aboutTitle => 'אודות מחשבי צלילה';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple Watch';

  @override
  String get transfer_computers_appleWatchSubtitle =>
      'ייבא צלילות שהוקלטו ב-Apple Watch Ultra';

  @override
  String get transfer_computers_appleWatchTitle => 'ייבוא מ-Apple Watch';

  @override
  String get transfer_computers_connectSubtitle => 'גלה וצמד מחשב צלילה';

  @override
  String get transfer_computers_connectTitle => 'חבר מחשב חדש';

  @override
  String get transfer_computers_errorLoading => 'שגיאה בטעינת מחשבים';

  @override
  String get transfer_computers_loading => 'טוען...';

  @override
  String get transfer_computers_manageTitle => 'ניהול מחשבים';

  @override
  String get transfer_computers_noComputersSaved => 'לא נשמרו מחשבים';

  @override
  String transfer_computers_savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'מחשבים שמורים',
      one: 'מחשב שמור',
    );
    return '$count $_temp0';
  }

  @override
  String get transfer_computers_sectionHeader => 'מחשבי צלילה';

  @override
  String get transfer_csvExport_cancelButton => 'ביטול';

  @override
  String get transfer_csvExport_dataTypeHeader => 'סוג נתונים';

  @override
  String get transfer_csvExport_descriptionDives =>
      'ייצא את כל יומני הצלילה כגיליון אלקטרוני';

  @override
  String get transfer_csvExport_descriptionEquipment =>
      'ייצא מלאי ציוד ופרטי תחזוקה';

  @override
  String get transfer_csvExport_descriptionSites =>
      'ייצא מיקומי אתרי צלילה ופרטים';

  @override
  String get transfer_csvExport_dialogTitle => 'ייצוא CSV';

  @override
  String get transfer_csvExport_exportButton => 'ייצא CSV';

  @override
  String get transfer_csvExport_optionDivesTitle => 'CSV צלילות';

  @override
  String get transfer_csvExport_optionEquipmentTitle => 'CSV ציוד';

  @override
  String get transfer_csvExport_optionSitesTitle => 'CSV אתרים';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return 'ייצא $typeName';
  }

  @override
  String get transfer_csvExport_typeDives => 'צלילות';

  @override
  String get transfer_csvExport_typeEquipment => 'ציוד';

  @override
  String get transfer_csvExport_typeSites => 'אתרים';

  @override
  String get transfer_detail_backTooltip => 'חזרה להעברה';

  @override
  String get transfer_export_aboutContent =>
      'ייצא את נתוני הצלילה שלך בפורמטים שונים. PDF יוצר יומן צלילות להדפסה. UDDF הוא פורמט אוניברסלי התואם לרוב תוכנות יומני הצלילה. ניתן לפתוח קבצי CSV ביישומי גיליונות אלקטרוניים.';

  @override
  String get transfer_export_aboutTitle => 'אודות ייצוא';

  @override
  String get transfer_export_completed => 'הייצוא הושלם';

  @override
  String get transfer_export_csvSubtitle => 'פורמט גיליון אלקטרוני';

  @override
  String get transfer_export_csvTitle => 'ייצוא CSV';

  @override
  String get transfer_export_excelSubtitle =>
      'כל הנתונים בקובץ אחד (צלילות, אתרים, ציוד, סטטיסטיקות)';

  @override
  String get transfer_export_excelTitle => 'חוברת עבודה של Excel';

  @override
  String transfer_export_failed(Object error) {
    return 'הייצוא נכשל: $error';
  }

  @override
  String get transfer_export_kmlSubtitle => 'הצג אתרי צלילה על גלובוס תלת-ממדי';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => 'ייצוא רב-פורמטי';

  @override
  String get transfer_export_optionSaveSubtitle => 'בחר היכן לשמור במכשיר שלך';

  @override
  String get transfer_export_optionSaveTitle => 'שמור לקובץ';

  @override
  String get transfer_export_optionShareSubtitle =>
      'שלח באמצעות דוא\"ל, הודעות או אפליקציות אחרות';

  @override
  String get transfer_export_optionShareTitle => 'שיתוף';

  @override
  String get transfer_export_pdfSubtitle => 'יומן צלילות להדפסה';

  @override
  String get transfer_export_pdfTitle => 'יומן PDF';

  @override
  String get transfer_export_progressExporting => 'מייצא...';

  @override
  String get transfer_export_sectionHeader => 'ייצוא נתונים';

  @override
  String get transfer_export_uddfSubtitle => 'פורמט נתוני צלילה אוניברסלי';

  @override
  String get transfer_export_uddfTitle => 'ייצוא UDDF';

  @override
  String get transfer_import_aboutContent =>
      'השתמש ב\"ייבוא נתונים\" לחוויה הטובה ביותר -- מזהה אוטומטית את פורמט הקובץ ואפליקציית המקור שלך. אפשרויות הפורמט הבודדות למטה זמינות גם לגישה ישירה.';

  @override
  String get transfer_import_aboutTitle => 'אודות ייבוא';

  @override
  String get transfer_import_autoDetectSemanticLabel =>
      'ייבא נתונים עם זיהוי אוטומטי';

  @override
  String get transfer_import_autoDetectSubtitle =>
      'מזהה אוטומטית CSV, UDDF, FIT ועוד';

  @override
  String get transfer_import_autoDetectTitle => 'ייבוא נתונים';

  @override
  String get transfer_import_byFormatHeader => 'ייבוא לפי פורמט';

  @override
  String get transfer_import_csvSubtitle => 'ייבא צלילות מקובץ CSV';

  @override
  String get transfer_import_csvTitle => 'ייבוא מ-CSV';

  @override
  String get transfer_import_fitSubtitle =>
      'ייבא צלילות מקבצי ייצוא של Garmin Descent';

  @override
  String get transfer_import_fitTitle => 'ייבוא מקובץ FIT';

  @override
  String get transfer_import_operationCompleted => 'הפעולה הושלמה';

  @override
  String transfer_import_operationFailed(Object error) {
    return 'הפעולה נכשלה: $error';
  }

  @override
  String get transfer_import_sectionHeader => 'ייבוא נתונים';

  @override
  String get transfer_import_uddfSubtitle => 'פורמט נתוני צלילה אוניברסלי';

  @override
  String get transfer_import_uddfTitle => 'ייבוא מ-UDDF';

  @override
  String get transfer_pdfExport_cancelButton => 'ביטול';

  @override
  String get transfer_pdfExport_dialogTitle => 'ייצוא יומן PDF';

  @override
  String get transfer_pdfExport_exportButton => 'ייצא PDF';

  @override
  String get transfer_pdfExport_includeCertCards => 'כלול כרטיסי הסמכה';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle =>
      'הוסף תמונות כרטיסי הסמכה סרוקים ל-PDF';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => 'גודל עמוד';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Letter';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => 'מפורט';

  @override
  String get transfer_pdfExport_templateDetailedDesc =>
      'מידע מלא על הצלילה עם הערות ודירוגים';

  @override
  String get transfer_pdfExport_templateHeader => 'תבנית';

  @override
  String get transfer_pdfExport_templateNauiStyle => 'סגנון NAUI';

  @override
  String get transfer_pdfExport_templateNauiStyleDesc =>
      'פריסה התואמת לפורמט יומן NAUI';

  @override
  String get transfer_pdfExport_templatePadiStyle => 'סגנון PADI';

  @override
  String get transfer_pdfExport_templatePadiStyleDesc =>
      'פריסה התואמת לפורמט יומן PADI';

  @override
  String get transfer_pdfExport_templateProfessional => 'מקצועי';

  @override
  String get transfer_pdfExport_templateProfessionalDesc =>
      'אזורי חתימה וחותמת לאימות';

  @override
  String transfer_pdfExport_templateSemanticLabel(Object templateName) {
    return 'בחר תבנית $templateName';
  }

  @override
  String get transfer_pdfExport_templateSimple => 'פשוט';

  @override
  String get transfer_pdfExport_templateSimpleDesc =>
      'פורמט טבלה קומפקטי, צלילות רבות בעמוד';

  @override
  String get transfer_section_computersSubtitle => 'הורדה ממכשיר';

  @override
  String get transfer_section_computersTitle => 'מחשבי צלילה';

  @override
  String get transfer_section_exportSubtitle => 'CSV, UDDF, יומן PDF';

  @override
  String get transfer_section_exportTitle => 'ייצוא';

  @override
  String get transfer_section_importSubtitle => 'קבצי CSV, UDDF';

  @override
  String get transfer_section_importTitle => 'ייבוא';

  @override
  String get transfer_summary_description => 'ייבוא וייצוא נתוני צלילה';

  @override
  String get transfer_summary_selectSection => 'בחר מדור מהרשימה';

  @override
  String get transfer_summary_title => 'העברה';

  @override
  String transfer_unknownSection(Object sectionId) {
    return 'מדור לא ידוע: $sectionId';
  }

  @override
  String get trips_appBar_title => 'טיולים';

  @override
  String get trips_appBar_tripPhotos => 'תמונות טיול';

  @override
  String get trips_detail_action_delete => 'מחיקה';

  @override
  String get trips_detail_action_export => 'ייצוא';

  @override
  String get trips_detail_appBar_title => 'טיול';

  @override
  String get trips_detail_dialog_cancel => 'ביטול';

  @override
  String get trips_detail_dialog_deleteConfirm => 'מחיקה';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return 'האם אתה בטוח שברצונך למחוק את \"$name\"? פעולה זו תסיר את הטיול אך תשמור על הצלילות.';
  }

  @override
  String get trips_detail_dialog_deleteTitle => 'למחוק טיול?';

  @override
  String get trips_detail_dives_empty => 'אין עדיין צלילות בטיול זה';

  @override
  String get trips_detail_dives_errorLoading => 'לא ניתן לטעון צלילות';

  @override
  String get trips_detail_dives_unknownSite => 'אתר לא ידוע';

  @override
  String trips_detail_dives_viewAll(Object count) {
    return 'הצג הכל ($count)';
  }

  @override
  String trips_detail_durationDays(Object days) {
    return '$days ימים';
  }

  @override
  String get trips_detail_export_csv_comingSoon => 'ייצוא CSV בקרוב';

  @override
  String get trips_detail_export_csv_subtitle => 'כל הצלילות בטיול זה';

  @override
  String get trips_detail_export_csv_title => 'ייצוא ל-CSV';

  @override
  String get trips_detail_export_pdf_comingSoon => 'ייצוא PDF בקרוב';

  @override
  String get trips_detail_export_pdf_subtitle => 'סיכום טיול עם פרטי צלילות';

  @override
  String get trips_detail_export_pdf_title => 'ייצוא ל-PDF';

  @override
  String get trips_detail_label_liveaboard => 'ספינת צלילה';

  @override
  String get trips_detail_label_location => 'מיקום';

  @override
  String get trips_detail_label_resort => 'אתר נופש';

  @override
  String get trips_detail_scan_accessDenied => 'הגישה לספריית התמונות נדחתה';

  @override
  String get trips_detail_scan_addDivesFirst =>
      'הוסף צלילות תחילה כדי לקשר תמונות';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return 'שגיאה בקישור תמונות: $error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return 'שגיאה בסריקה: $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return 'קושרו $count תמונות';
  }

  @override
  String get trips_detail_scan_linkingPhotos => 'מקשר תמונות...';

  @override
  String get trips_detail_sectionTitle_details => 'פרטי הטיול';

  @override
  String get trips_detail_sectionTitle_dives => 'צלילות';

  @override
  String get trips_detail_sectionTitle_notes => 'הערות';

  @override
  String get trips_detail_sectionTitle_statistics => 'סטטיסטיקות הטיול';

  @override
  String get trips_detail_snackBar_deleted => 'הטיול נמחק';

  @override
  String get trips_detail_stat_avgDepth => 'עומק ממוצע';

  @override
  String get trips_detail_stat_maxDepth => 'עומק מרבי';

  @override
  String get trips_detail_stat_totalBottomTime => 'סה\"כ זמן תחתית';

  @override
  String get trips_detail_stat_totalDives => 'סה\"כ צלילות';

  @override
  String get trips_detail_tooltip_edit => 'ערוך טיול';

  @override
  String get trips_detail_tooltip_editShort => 'עריכה';

  @override
  String get trips_detail_tooltip_moreOptions => 'אפשרויות נוספות';

  @override
  String get trips_detail_tooltip_viewOnMap => 'הצג על המפה';

  @override
  String get trips_edit_appBar_add => 'הוסף טיול';

  @override
  String get trips_edit_appBar_edit => 'ערוך טיול';

  @override
  String get trips_edit_button_add => 'הוסף טיול';

  @override
  String get trips_edit_button_cancel => 'ביטול';

  @override
  String get trips_edit_button_save => 'שמירה';

  @override
  String get trips_edit_button_update => 'עדכן טיול';

  @override
  String get trips_edit_dialog_discard => 'מחיקה';

  @override
  String get trips_edit_dialog_discardContent =>
      'יש לך שינויים שלא נשמרו. האם אתה בטוח שברצונך לצאת?';

  @override
  String get trips_edit_dialog_discardTitle => 'לבטל שינויים?';

  @override
  String get trips_edit_dialog_keepEditing => 'המשך עריכה';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days ימים';
  }

  @override
  String get trips_edit_hint_liveaboardName => 'לדוגמה, MY Blue Force One';

  @override
  String get trips_edit_hint_location => 'לדוגמה, מצרים, ים סוף';

  @override
  String get trips_edit_hint_notes => 'הערות נוספות על טיול זה';

  @override
  String get trips_edit_hint_resortName => 'לדוגמה, Marsa Shagra';

  @override
  String get trips_edit_hint_tripName => 'לדוגמה, ספארי ים סוף 2024';

  @override
  String get trips_edit_label_endDate => 'תאריך סיום';

  @override
  String get trips_edit_label_liveaboardName => 'שם ספינת הצלילה';

  @override
  String get trips_edit_label_location => 'מיקום';

  @override
  String get trips_edit_label_notes => 'הערות';

  @override
  String get trips_edit_label_resortName => 'שם אתר הנופש';

  @override
  String get trips_edit_label_startDate => 'תאריך התחלה';

  @override
  String get trips_edit_label_tripName => 'שם הטיול *';

  @override
  String get trips_edit_sectionTitle_dates => 'תאריכי הטיול';

  @override
  String get trips_edit_sectionTitle_location => 'מיקום';

  @override
  String get trips_edit_sectionTitle_notes => 'הערות';

  @override
  String get trips_edit_semanticLabel_save => 'שמור טיול';

  @override
  String get trips_edit_snackBar_added => 'הטיול נוסף בהצלחה';

  @override
  String trips_edit_snackBar_errorLoading(Object error) {
    return 'שגיאה בטעינת הטיול: $error';
  }

  @override
  String trips_edit_snackBar_errorSaving(Object error) {
    return 'שגיאה בשמירת הטיול: $error';
  }

  @override
  String get trips_edit_snackBar_updated => 'הטיול עודכן בהצלחה';

  @override
  String get trips_edit_validation_nameRequired => 'נא להזין שם טיול';

  @override
  String get trips_gallery_accessDenied => 'הגישה לספריית התמונות נדחתה';

  @override
  String get trips_gallery_addDivesFirst => 'הוסף צלילות תחילה כדי לקשר תמונות';

  @override
  String get trips_gallery_appBar_title => 'תמונות טיול';

  @override
  String trips_gallery_diveSection_photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'תמונות',
      one: 'תמונה',
    );
    return '$_temp0';
  }

  @override
  String trips_gallery_diveSection_title(Object number, Object site) {
    return 'צלילה #$number - $site';
  }

  @override
  String get trips_gallery_empty_subtitle =>
      'הקש על סמל המצלמה כדי לסרוק את הגלריה שלך';

  @override
  String get trips_gallery_empty_title => 'אין תמונות בטיול זה';

  @override
  String trips_gallery_errorLinking(Object error) {
    return 'שגיאה בקישור תמונות: $error';
  }

  @override
  String trips_gallery_errorScanning(Object error) {
    return 'שגיאה בסריקה: $error';
  }

  @override
  String trips_gallery_error_loading(Object error) {
    return 'שגיאה בטעינת תמונות: $error';
  }

  @override
  String trips_gallery_linkedPhotos(Object count) {
    return 'קושרו $count תמונות';
  }

  @override
  String get trips_gallery_linkingPhotos => 'מקשר תמונות...';

  @override
  String get trips_gallery_tooltip_scan => 'סרוק גלריית מכשיר';

  @override
  String get trips_gallery_tripNotFound => 'הטיול לא נמצא';

  @override
  String get trips_list_button_retry => 'נסה שוב';

  @override
  String get trips_list_empty_button => 'הוסף את הטיול הראשון שלך';

  @override
  String get trips_list_empty_filtered_subtitle =>
      'נסה להתאים או לנקות את המסננים שלך';

  @override
  String get trips_list_empty_filtered_title =>
      'אין טיולים התואמים למסננים שלך';

  @override
  String get trips_list_empty_subtitle =>
      'צור טיולים כדי לקבץ את הצלילות שלך לפי יעד';

  @override
  String get trips_list_empty_title => 'עדיין לא נוספו טיולים';

  @override
  String trips_list_error_loading(Object error) {
    return 'שגיאה בטעינת טיולים: $error';
  }

  @override
  String get trips_list_fab_addTrip => 'הוסף טיול';

  @override
  String get trips_list_filters_clearAll => 'נקה הכל';

  @override
  String get trips_list_sort_title => 'מיון טיולים';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count צלילות';
  }

  @override
  String get trips_list_tooltip_addTrip => 'הוסף טיול';

  @override
  String get trips_list_tooltip_search => 'חיפוש טיולים';

  @override
  String get trips_list_tooltip_sort => 'מיון';

  @override
  String get trips_photos_empty_scanButton => 'סרוק גלריית מכשיר';

  @override
  String get trips_photos_empty_title => 'עדיין אין תמונות';

  @override
  String get trips_photos_error_loading => 'שגיאה בטעינת תמונות';

  @override
  String trips_photos_moreIndicator(Object count) {
    return '+$count';
  }

  @override
  String trips_photos_moreIndicator_semanticLabel(Object count) {
    return 'עוד $count תמונות';
  }

  @override
  String get trips_photos_sectionTitle => 'תמונות';

  @override
  String get trips_photos_tooltip_scan => 'סרוק גלריית מכשיר';

  @override
  String get trips_photos_viewAll => 'הצג הכל';

  @override
  String get trips_picker_clearTooltip => 'נקה בחירה';

  @override
  String get trips_picker_empty_createButton => 'צור טיול';

  @override
  String get trips_picker_empty_title => 'עדיין אין טיולים';

  @override
  String trips_picker_error(Object error) {
    return 'שגיאה בטעינת טיולים: $error';
  }

  @override
  String get trips_picker_hint => 'הקש כדי לבחור טיול';

  @override
  String get trips_picker_newTrip => 'טיול חדש';

  @override
  String get trips_picker_noSelection => 'לא נבחר טיול';

  @override
  String get trips_picker_sheetTitle => 'בחר טיול';

  @override
  String trips_picker_suggestedPrefix(Object name) {
    return 'מוצע: $name';
  }

  @override
  String get trips_picker_suggestedUse => 'השתמש';

  @override
  String get trips_search_empty_hint => 'חיפוש לפי שם, מיקום או אתר נופש';

  @override
  String get trips_search_fieldLabel => 'חיפוש טיולים...';

  @override
  String trips_search_noResults(Object query) {
    return 'לא נמצאו טיולים עבור \"$query\"';
  }

  @override
  String get trips_search_tooltip_back => 'חזרה';

  @override
  String get trips_search_tooltip_clear => 'נקה חיפוש';

  @override
  String get trips_summary_header_subtitle =>
      'בחר טיול מהרשימה כדי לצפות בפרטים';

  @override
  String get trips_summary_header_title => 'טיולים';

  @override
  String get trips_summary_overview_title => 'סקירה כללית';

  @override
  String get trips_summary_quickActions_add => 'הוסף טיול';

  @override
  String get trips_summary_quickActions_title => 'פעולות מהירות';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date • $count צלילות';
  }

  @override
  String get trips_summary_recentTitle => 'טיולים אחרונים';

  @override
  String get trips_summary_stat_daysDiving => 'ימי צלילה';

  @override
  String get trips_summary_stat_liveaboards => 'ספינות צלילה';

  @override
  String get trips_summary_stat_totalDives => 'סה\"כ צלילות';

  @override
  String get trips_summary_stat_totalTrips => 'סה\"כ טיולים';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date • בעוד $days ימים';
  }

  @override
  String get trips_summary_upcomingTitle => 'קרובים';

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
  String get units_sac_pressurePerMin => 'לחץ/min';

  @override
  String get units_temperature_celsius => 'C';

  @override
  String get units_temperature_fahrenheit => 'F';

  @override
  String get units_timeFormat_twelveHour => '12 שעות';

  @override
  String get units_timeFormat_twentyFourHour => '24 שעות';

  @override
  String get units_volume_cubicFeet => 'cuft';

  @override
  String get units_volume_liters => 'L';

  @override
  String get units_weight_kilograms => 'kg';

  @override
  String get units_weight_pounds => 'lbs';

  @override
  String get universalImport_action_continue => 'המשך';

  @override
  String get universalImport_action_deselectAll => 'בטל בחירת הכל';

  @override
  String get universalImport_action_done => 'סיום';

  @override
  String get universalImport_action_import => 'ייבא';

  @override
  String get universalImport_action_selectAll => 'בחר הכל';

  @override
  String get universalImport_action_selectFile => 'בחר קובץ';

  @override
  String get universalImport_description_supportedFormats =>
      'בחר קובץ יומן צלילה לייבוא. פורמטים נתמכים כוללים CSV, UDDF, Subsurface XML ו-Garmin FIT.';

  @override
  String get universalImport_error_unsupportedFormat =>
      'פורמט זה אינו נתמך עדיין. נא לייצא כ-UDDF או CSV.';

  @override
  String get universalImport_hint_tagDescription =>
      'תייג את כל הצלילות המיובאות לסינון קל';

  @override
  String get universalImport_hint_tagExample =>
      'לדוגמה: ייבוא MacDive 2026-02-09';

  @override
  String get universalImport_label_columnMapping => 'מיפוי עמודות';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped מתוך $total עמודות ממופות';
  }

  @override
  String get universalImport_label_detecting => 'מזהה...';

  @override
  String universalImport_label_diveNumber(Object number) {
    return 'צלילה מס\' $number';
  }

  @override
  String get universalImport_label_duplicate => 'כפילות';

  @override
  String universalImport_label_duplicatesFound(Object count) {
    return '$count כפילויות נמצאו ובוטלה בחירתן אוטומטית.';
  }

  @override
  String get universalImport_label_importComplete => 'ייבוא הושלם';

  @override
  String get universalImport_label_importTag => 'תגית ייבוא';

  @override
  String get universalImport_label_importing => 'מייבא';

  @override
  String get universalImport_label_importingEllipsis => 'מייבא...';

  @override
  String universalImport_label_importingProgress(Object current, Object total) {
    return 'מייבא $current מתוך $total';
  }

  @override
  String universalImport_label_percentMatch(Object percent) {
    return '$percent% התאמה';
  }

  @override
  String get universalImport_label_possibleMatch => 'התאמה אפשרית';

  @override
  String get universalImport_label_selectCorrectSource =>
      'לא נכון? בחר את המקור הנכון:';

  @override
  String universalImport_label_selected(Object count) {
    return '$count נבחרו';
  }

  @override
  String get universalImport_label_skip => 'דלג';

  @override
  String universalImport_label_taggedAs(Object tag) {
    return 'מתויג כ: $tag';
  }

  @override
  String get universalImport_label_unknownDate => 'תאריך לא ידוע';

  @override
  String get universalImport_label_unnamed => 'ללא שם';

  @override
  String universalImport_label_xOfY(Object current, Object total) {
    return '$current מתוך $total';
  }

  @override
  String universalImport_label_xOfYSelected(Object selected, Object total) {
    return '$selected מתוך $total נבחרו';
  }

  @override
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  ) {
    return '$selected מתוך $total $entityType נבחרו';
  }

  @override
  String universalImport_semantics_importError(Object error) {
    return 'שגיאת ייבוא: $error';
  }

  @override
  String universalImport_semantics_importProgress(Object percent) {
    return 'התקדמות ייבוא: $percent אחוזים';
  }

  @override
  String universalImport_semantics_itemsSelected(Object count) {
    return '$count פריטים נבחרו לייבוא';
  }

  @override
  String get universalImport_semantics_possibleDuplicate => 'כפילות אפשרית';

  @override
  String get universalImport_semantics_probableDuplicate => 'כפילות סבירה';

  @override
  String universalImport_semantics_sourceDetected(Object description) {
    return 'מקור זוהה: $description';
  }

  @override
  String universalImport_semantics_sourceUncertain(Object description) {
    return 'מקור לא ודאי: $description';
  }

  @override
  String universalImport_semantics_toggleSelection(Object name) {
    return 'החלף בחירה עבור $name';
  }

  @override
  String get universalImport_step_import => 'ייבא';

  @override
  String get universalImport_step_map => 'מפה';

  @override
  String get universalImport_step_review => 'סקירה';

  @override
  String get universalImport_step_select => 'בחר';

  @override
  String get universalImport_title => 'ייבא נתונים';

  @override
  String get universalImport_tooltip_clearTag => 'נקה תגית';

  @override
  String get universalImport_tooltip_closeWizard => 'סגור אשף ייבוא';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return 'בסיס ($suitType): $weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return 'התאמת משקל גוף: +$adjustment kg';
  }

  @override
  String get weightCalc_suit_drysuit => 'חליפה יבשה';

  @override
  String get weightCalc_suit_none => 'ללא חליפה';

  @override
  String get weightCalc_suit_rashguard => 'חולצת גלישה בלבד';

  @override
  String get weightCalc_suit_semidry => 'חליפה חצי יבשה';

  @override
  String get weightCalc_suit_shorty3mm => 'שורטי 3mm';

  @override
  String get weightCalc_suit_wetsuit3mm => 'חליפת צלילה 3mm מלאה';

  @override
  String get weightCalc_suit_wetsuit5mm => 'חליפת צלילה 5mm';

  @override
  String get weightCalc_suit_wetsuit7mm => 'חליפת צלילה 7mm';

  @override
  String weightCalc_tankLine(Object tankMaterial, Object adjustment) {
    return 'בלון ($tankMaterial): $adjustment kg';
  }

  @override
  String get weightCalc_title => 'חישוב משקולות:';

  @override
  String weightCalc_total(Object total) {
    return 'סה\"כ: $total kg';
  }

  @override
  String weightCalc_waterLine(Object waterType, Object adjustment) {
    return 'מים ($waterType): $adjustment kg';
  }

  @override
  String divePlanner_label_resultsWithWarnings(Object count) {
    return 'תוצאות, $count אזהרות';
  }

  @override
  String tides_semantic_tideCycle(Object state, Object height) {
    return 'מחזור גאות, מצב: $state, גובה: $height';
  }

  @override
  String get tides_label_agoSuffix => 'לפני';

  @override
  String get tides_label_fromNowSuffix => 'מעכשיו';

  @override
  String get certifications_card_issued => 'הונפק';

  @override
  String certifications_certificate_cardNumber(Object number) {
    return 'מספר כרטיס: $number';
  }

  @override
  String get certifications_certificate_footer => 'תעודת צלילה רשמית';

  @override
  String get certifications_certificate_hasCompletedTraining =>
      'השלים/ה הכשרה כ';

  @override
  String certifications_certificate_instructor(Object name) {
    return 'מדריך: $name';
  }

  @override
  String certifications_certificate_issued(Object date) {
    return 'תאריך הנפקה: $date';
  }

  @override
  String get certifications_certificate_thisCertifies => 'בזאת מאושר כי';

  @override
  String get diveComputer_discovery_chooseDifferentDevice => 'בחר מכשיר אחר';

  @override
  String get diveComputer_discovery_computer => 'מחשב';

  @override
  String get diveComputer_discovery_connectAndDownload => 'התחבר והורד';

  @override
  String get diveComputer_discovery_connectingToDevice => 'מתחבר למכשיר...';

  @override
  String diveComputer_discovery_deviceNameHint(Object model) {
    return 'לדוגמה, ה-$model שלי';
  }

  @override
  String get diveComputer_discovery_deviceNameLabel => 'שם המכשיר';

  @override
  String get diveComputer_discovery_exitDialogCancel => 'ביטול';

  @override
  String get diveComputer_discovery_exitDialogConfirm => 'יציאה';

  @override
  String get diveComputer_discovery_exitDialogContent =>
      'האם אתה בטוח שברצונך לצאת? ההתקדמות תאבד.';

  @override
  String get diveComputer_discovery_exitDialogTitle => 'לצאת מההגדרה?';

  @override
  String get diveComputer_discovery_exitTooltip => 'יציאה מהגדרה';

  @override
  String get diveComputer_discovery_noDeviceSelected => 'לא נבחר מכשיר';

  @override
  String get diveComputer_discovery_pleaseWaitConnection =>
      'אנא המתן בזמן יצירת החיבור';

  @override
  String get diveComputer_discovery_recognizedDevice => 'מכשיר מזוהה';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      'מכשיר זה נמצא בספריית המכשירים הנתמכים. הורדת צלילות אמורה לפעול אוטומטית.';

  @override
  String get diveComputer_discovery_stepConnect => 'חיבור';

  @override
  String get diveComputer_discovery_stepDone => 'סיום';

  @override
  String get diveComputer_discovery_stepDownload => 'הורדה';

  @override
  String get diveComputer_discovery_stepScan => 'סריקה';

  @override
  String get diveComputer_discovery_titleComplete => 'הושלם';

  @override
  String get diveComputer_discovery_titleConfirmDevice => 'אישור מכשיר';

  @override
  String get diveComputer_discovery_titleConnecting => 'מתחבר';

  @override
  String get diveComputer_discovery_titleDownloading => 'מוריד';

  @override
  String get diveComputer_discovery_titleFindDevice => 'חיפוש מכשיר';

  @override
  String get diveComputer_discovery_unknownDevice => 'מכשיר לא מוכר';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      'מכשיר זה אינו בספרייה שלנו. ננסה להתחבר, אך ייתכן שההורדה לא תעבוד.';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... ועוד $count';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'ביטול';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadFailed => 'ההורדה נכשלה';

  @override
  String get diveComputer_downloadStep_downloadedDives => 'צלילות שהורדו';

  @override
  String diveComputer_downloadStep_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_downloadStep_errorOccurred => 'אירעה שגיאה';

  @override
  String diveComputer_downloadStep_errorSemanticLabel(Object error) {
    return 'שגיאת הורדה: $error';
  }

  @override
  String diveComputer_downloadStep_percentAccessibility(Object percent) {
    return ', $percent אחוז';
  }

  @override
  String get diveComputer_downloadStep_preparing => 'מכין...';

  @override
  String diveComputer_downloadStep_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String diveComputer_downloadStep_progressSemanticLabel(
    Object status,
    Object percent,
  ) {
    return 'התקדמות הורדה: $status$percent';
  }

  @override
  String get diveComputer_downloadStep_retry => 'נסה שוב';

  @override
  String get diveComputer_download_cancel => 'ביטול';

  @override
  String get diveComputer_download_closeTooltip => 'סגירה';

  @override
  String get diveComputer_download_computerNotFound => 'המחשב לא נמצא';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return 'המכשיר לא נמצא. ודא שה-$name שלך קרוב ובמצב העברה.';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle => 'המכשיר לא נמצא';

  @override
  String get diveComputer_download_divesUpdated => 'צלילות עודכנו';

  @override
  String get diveComputer_download_done => 'סיום';

  @override
  String get diveComputer_download_downloadedDives => 'צלילות שהורדו';

  @override
  String get diveComputer_download_duplicatesSkipped => 'כפילויות דולגו';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_download_errorOccurred => 'אירעה שגיאה';

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get diveComputer_download_goBack => 'חזרה';

  @override
  String get diveComputer_download_importFailed => 'הייבוא נכשל';

  @override
  String get diveComputer_download_importResults => 'תוצאות ייבוא';

  @override
  String get diveComputer_download_importedDives => 'צלילות שיובאו';

  @override
  String get diveComputer_download_newDivesImported => 'צלילות חדשות יובאו';

  @override
  String get diveComputer_download_preparing => 'מכין...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_retry => 'נסה שוב';

  @override
  String diveComputer_download_scanError(Object error) {
    return 'שגיאת סריקה: $error';
  }

  @override
  String diveComputer_download_searchingForDevice(Object name) {
    return 'מחפש את $name...';
  }

  @override
  String get diveComputer_download_searchingInstructions =>
      'ודא שהמכשיר קרוב ובמצב העברה';

  @override
  String get diveComputer_download_title => 'הורדת צלילות';

  @override
  String get diveComputer_download_tryAgain => 'נסה שוב';

  @override
  String get diveComputer_list_addComputer => 'הוסף מחשב';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return 'מחשב צלילה: $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count צלילות';
  }

  @override
  String get diveComputer_list_downloadTooltip => 'הורד צלילות';

  @override
  String get diveComputer_list_emptyMessage =>
      'חבר את מחשב הצלילה שלך כדי להוריד צלילות ישירות לאפליקציה.';

  @override
  String get diveComputer_list_emptyTitle => 'אין מחשבי צלילה';

  @override
  String get diveComputer_list_findComputers => 'חפש מחשבים';

  @override
  String get diveComputer_list_helpBluetooth =>
      'Bluetooth LE (רוב המחשבים המודרניים) •';

  @override
  String get diveComputer_list_helpBluetoothClassic =>
      'Bluetooth Classic (דגמים ישנים) •';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi, ועוד 50+ דגמים.';

  @override
  String get diveComputer_list_helpBrandsTitle => 'מותגים נתמכים';

  @override
  String get diveComputer_list_helpConnectionsTitle => 'חיבורים נתמכים';

  @override
  String get diveComputer_list_helpDialogTitle => 'עזרה למחשב צלילה';

  @override
  String get diveComputer_list_helpDismiss => 'הבנתי';

  @override
  String get diveComputer_list_helpTip1 => '• ודא שהמחשב במצב העברה';

  @override
  String get diveComputer_list_helpTip2 =>
      '• שמור את המכשירים קרובים בזמן ההורדה';

  @override
  String get diveComputer_list_helpTip3 => '• ודא שה-Bluetooth מופעל';

  @override
  String get diveComputer_list_helpTipsTitle => 'טיפים';

  @override
  String get diveComputer_list_helpTooltip => 'עזרה';

  @override
  String get diveComputer_list_helpUsb => 'USB (שולחן עבודה בלבד) •';

  @override
  String get diveComputer_list_loadFailed => 'טעינת מחשבי צלילה נכשלה';

  @override
  String get diveComputer_list_retry => 'נסה שוב';

  @override
  String get diveComputer_list_title => 'מחשבי צלילה';

  @override
  String get diveComputer_summary_diveComputer => 'מחשב צלילה';

  @override
  String diveComputer_summary_divesDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צלילות הורדו',
      one: 'צלילה הורדה',
    );
    return '$count $_temp0';
  }

  @override
  String get diveComputer_summary_done => 'סיום';

  @override
  String get diveComputer_summary_imported => 'יובאו';

  @override
  String diveComputer_summary_semanticLabel(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צלילות הורדו',
      one: 'צלילה הורדה',
    );
    return '$count $_temp0 מ-$name';
  }

  @override
  String get diveComputer_summary_skippedDuplicates => 'דולגו (כפילויות)';

  @override
  String get diveComputer_summary_title => 'ההורדה הושלמה!';

  @override
  String get diveComputer_summary_updated => 'עודכנו';

  @override
  String get diveComputer_summary_viewDives => 'הצג צלילות';

  @override
  String get diveImport_alreadyImported => 'כבר יובא';

  @override
  String get diveImport_avgHR => 'דופק ממוצע';

  @override
  String get diveImport_back => 'חזרה';

  @override
  String get diveImport_deselectAll => 'בטל בחירת הכל';

  @override
  String get diveImport_divesImported => 'צלילות יובאו';

  @override
  String get diveImport_divesMerged => 'צלילות מוזגו';

  @override
  String get diveImport_divesSkipped => 'צלילות דולגו';

  @override
  String get diveImport_done => 'סיום';

  @override
  String get diveImport_duration => 'משך';

  @override
  String get diveImport_error => 'שגיאה';

  @override
  String get diveImport_fit_closeTooltip => 'סגור ייבוא FIT';

  @override
  String get diveImport_fit_noDivesDescription =>
      'בחר קובץ .fit אחד או יותר שיוצא מ-Garmin Connect או הועתק ממכשיר Garmin Descent.';

  @override
  String get diveImport_fit_noDivesLoaded => 'לא נטענו צלילות';

  @override
  String diveImport_fit_parsed(int diveCount, int fileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'צלילות',
      one: 'צלילה',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'קבצים',
      one: 'קובץ',
    );
    return 'נותחו $diveCount $_temp0 מ-$fileCount $_temp1';
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
      other: 'צלילות',
      one: 'צלילה',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'קבצים',
      one: 'קובץ',
    );
    return 'נותחו $diveCount $_temp0 מ-$fileCount $_temp1 ($skippedCount דולגו)';
  }

  @override
  String get diveImport_fit_parsing => 'מנתח...';

  @override
  String get diveImport_fit_selectFiles => 'בחר קבצי FIT';

  @override
  String get diveImport_fit_title => 'ייבוא מקובץ FIT';

  @override
  String get diveImport_healthkit_accessDescription =>
      'Submersion זקוק לגישה לנתוני הצלילה מה-Apple Watch שלך כדי לייבא צלילות.';

  @override
  String get diveImport_healthkit_accessRequired => 'נדרשת גישה ל-HealthKit';

  @override
  String get diveImport_healthkit_closeTooltip => 'סגור ייבוא Apple Watch';

  @override
  String get diveImport_healthkit_dateFrom => 'מתאריך';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return 'בורר תאריך $label';
  }

  @override
  String get diveImport_healthkit_dateTo => 'עד תאריך';

  @override
  String get diveImport_healthkit_fetchDives => 'אחזר צלילות';

  @override
  String get diveImport_healthkit_fetching => 'מאחזר...';

  @override
  String get diveImport_healthkit_grantAccess => 'הענק גישה';

  @override
  String get diveImport_healthkit_noDivesFound => 'לא נמצאו צלילות';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'לא נמצאו פעילויות צלילה תת-ימיות בטווח התאריכים שנבחר.';

  @override
  String get diveImport_healthkit_notAvailable => 'לא זמין';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'ייבוא מ-Apple Watch זמין רק במכשירי iOS ו-macOS.';

  @override
  String get diveImport_healthkit_permissionCheckFailed => 'בדיקת הרשאות נכשלה';

  @override
  String get diveImport_healthkit_title => 'ייבוא מ-Apple Watch';

  @override
  String get diveImport_healthkit_watchTitle => 'ייבוא מהשעון';

  @override
  String get diveImport_import => 'ייבוא';

  @override
  String get diveImport_importComplete => 'הייבוא הושלם';

  @override
  String get diveImport_likelyDuplicate => 'כפילות סבירה';

  @override
  String get diveImport_maxDepth => 'עומק מרבי';

  @override
  String get diveImport_newDive => 'צלילה חדשה';

  @override
  String get diveImport_next => 'הבא';

  @override
  String get diveImport_possibleDuplicate => 'כפילות אפשרית';

  @override
  String get diveImport_reviewSelectedDives => 'סקירת צלילות נבחרות';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: ', $possibleCount כפילויות אפשריות',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: ', $skipCount ידולגו',
      zero: '',
    );
    return '$newCount חדשות$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => 'בחר הכל';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count נבחרו';
  }

  @override
  String get diveImport_sourceGarmin => 'Garmin';

  @override
  String get diveImport_sourceSuunto => 'Suunto';

  @override
  String get diveImport_sourceUDDF => 'UDDF';

  @override
  String get diveImport_sourceWatch => 'שעון';

  @override
  String get diveImport_step_done => 'סיום';

  @override
  String get diveImport_step_review => 'סקירה';

  @override
  String get diveImport_step_select => 'בחירה';

  @override
  String get diveImport_temp => 'טמפ\'';

  @override
  String get diveImport_toggleDiveSelection => 'החלף בחירת צלילה';

  @override
  String get diveImport_uddf_buddies => 'שותפים';

  @override
  String get diveImport_uddf_certifications => 'הסמכות';

  @override
  String get diveImport_uddf_closeTooltip => 'סגור ייבוא UDDF';

  @override
  String get diveImport_uddf_diveCenters => 'מרכזי צלילה';

  @override
  String get diveImport_uddf_diveTypes => 'סוגי צלילה';

  @override
  String get diveImport_uddf_dives => 'צלילות';

  @override
  String get diveImport_uddf_duplicate => 'כפילות';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return '$count כפילויות נמצאו ובוטלה בחירתן אוטומטית.';
  }

  @override
  String get diveImport_uddf_equipment => 'ציוד';

  @override
  String get diveImport_uddf_equipmentSets => 'ערכות ציוד';

  @override
  String diveImport_uddf_importProgress(Object current, Object total) {
    return '$current מתוך $total';
  }

  @override
  String get diveImport_uddf_importing => 'מייבא...';

  @override
  String get diveImport_uddf_likelyDuplicate => 'כפילות סבירה';

  @override
  String get diveImport_uddf_noFileDescription =>
      'בחר קובץ .uddf או .xml שיוצא מאפליקציית יומן צלילה אחרת.';

  @override
  String get diveImport_uddf_noFileSelected => 'לא נבחר קובץ';

  @override
  String get diveImport_uddf_parsing => 'מנתח...';

  @override
  String get diveImport_uddf_possibleDuplicate => 'כפילות אפשרית';

  @override
  String get diveImport_uddf_selectFile => 'בחר קובץ UDDF';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '$selected מתוך $total נבחרו';
  }

  @override
  String get diveImport_uddf_sites => 'אתרים';

  @override
  String get diveImport_uddf_stepImport => 'ייבוא';

  @override
  String get diveImport_uddf_tabBuddies => 'שותפים';

  @override
  String get diveImport_uddf_tabCenters => 'מרכזים';

  @override
  String get diveImport_uddf_tabCerts => 'הסמכות';

  @override
  String get diveImport_uddf_tabCourses => 'קורסים';

  @override
  String get diveImport_uddf_tabDives => 'צלילות';

  @override
  String get diveImport_uddf_tabEquipment => 'ציוד';

  @override
  String get diveImport_uddf_tabSets => 'ערכות';

  @override
  String get diveImport_uddf_tabSites => 'אתרים';

  @override
  String get diveImport_uddf_tabTags => 'תגיות';

  @override
  String get diveImport_uddf_tabTrips => 'טיולים';

  @override
  String get diveImport_uddf_tabTypes => 'סוגים';

  @override
  String get diveImport_uddf_tags => 'תגיות';

  @override
  String get diveImport_uddf_title => 'ייבוא מ-UDDF';

  @override
  String get diveImport_uddf_toggleDiveSelection => 'החלף בחירת צלילה';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return 'החלף בחירה עבור $name';
  }

  @override
  String get diveImport_uddf_trips => 'טיולים';

  @override
  String get divePlanner_segmentEditor_addTitle => 'הוסף קטע';

  @override
  String divePlanner_segmentEditor_ascentRate(Object unit) {
    return 'קצב עלייה ($unit/min)';
  }

  @override
  String divePlanner_segmentEditor_descentRate(Object unit) {
    return 'קצב ירידה ($unit/min)';
  }

  @override
  String get divePlanner_segmentEditor_duration => 'משך (min)';

  @override
  String get divePlanner_segmentEditor_editTitle => 'עריכת קטע';

  @override
  String divePlanner_segmentEditor_endDepth(Object unit) {
    return 'עומק סיום ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_gasSwitchTime => 'זמן החלפת גז';

  @override
  String get divePlanner_segmentEditor_segmentType => 'סוג קטע';

  @override
  String divePlanner_segmentEditor_startDepth(Object unit) {
    return 'עומק התחלה ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_tankGas => 'מיכל / גז';

  @override
  String get divePlanner_segmentList_addSegment => 'הוסף קטע';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return 'עלייה $startDepth → $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return 'תחתית $depth למשך $minutes min';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return 'דקו $depth למשך $minutes min';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => 'מחק קטע';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return 'ירידה $startDepth → $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => 'ערוך קטע';

  @override
  String get divePlanner_segmentList_emptyMessage =>
      'הוסף קטעים ידנית או צור תוכנית מהירה';

  @override
  String get divePlanner_segmentList_emptyTitle => 'אין קטעים עדיין';

  @override
  String divePlanner_segmentList_gasSwitch(Object gasName) {
    return 'החלפת גז ל-$gasName';
  }

  @override
  String get divePlanner_segmentList_quickPlan => 'תוכנית מהירה';

  @override
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes) {
    return 'עצירת בטיחות $depth למשך $minutes min';
  }

  @override
  String get divePlanner_segmentList_title => 'קטעי צלילה';

  @override
  String get divePlanner_segmentType_ascent => 'עלייה';

  @override
  String get divePlanner_segmentType_bottomTime => 'זמן תחתית';

  @override
  String get divePlanner_segmentType_decoStop => 'עצירת דקו';

  @override
  String get divePlanner_segmentType_descent => 'ירידה';

  @override
  String get divePlanner_segmentType_gasSwitch => 'החלפת גז';

  @override
  String get divePlanner_segmentType_safetyStop => 'עצירת בטיחות';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'Rock Bottom הוא מינימום עתודת הגז הנדרש לעלייה חירומית תוך שיתוף אוויר עם השותף שלך.\n\n• משתמש בקצבי SAC במצב לחץ (2-3 כפול מהרגיל)\n• מניח ששני הצוללים על מיכל אחד\n• כולל עצירת בטיחות כשמופעלת\n\nתמיד סיים את הצלילה לפני שמגיעים ל-Rock Bottom!';

  @override
  String get gasCalculators_rockBottom_aboutTitle => 'אודות Rock Bottom';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired => 'גז נדרש לעלייה';

  @override
  String get gasCalculators_rockBottom_ascentRate => 'קצב עלייה';

  @override
  String gasCalculators_rockBottom_ascentTimeToDepth(
    Object depth,
    Object unit,
  ) {
    return 'זמן עלייה ל-$depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_ascentTimeToSurface =>
      'זמן עלייה לפני השטח';

  @override
  String get gasCalculators_rockBottom_buddySac => 'SAC השותף';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'SAC משולב במצב לחץ';

  @override
  String get gasCalculators_rockBottom_emergencyAscentBreakdown =>
      'פירוט עלייה חירומית';

  @override
  String get gasCalculators_rockBottom_emergencyScenario => 'תרחיש חירום';

  @override
  String get gasCalculators_rockBottom_includeSafetyStop => 'כלול עצירת בטיחות';

  @override
  String get gasCalculators_rockBottom_maximumDepth => 'עומק מרבי';

  @override
  String get gasCalculators_rockBottom_minimumReserve => 'עתודה מינימלית';

  @override
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  ) {
    return 'עתודה מינימלית: $pressure $pressureUnit, $volume $volumeUnit. סיים את הצלילה כשנשארים $pressure $pressureUnit';
  }

  @override
  String gasCalculators_rockBottom_safetyStopDuration(
    Object depth,
    Object unit,
  ) {
    return '3 דקות ב-$depth$unit';
  }

  @override
  String gasCalculators_rockBottom_safetyStopGas(Object depth, Object unit) {
    return 'גז עצירת בטיחות (3 min @ $depth$unit)';
  }

  @override
  String get gasCalculators_rockBottom_stressedSacHint =>
      'השתמש בקצבי SAC גבוהים יותר לפיצוי על לחץ במצב חירום';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'קצבי SAC במצב לחץ';

  @override
  String get gasCalculators_rockBottom_tankSize => 'גודל מיכל';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded => 'סך עתודה נדרשת';

  @override
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  ) {
    return 'סיים את הצלילה כשנשארים $pressure $pressureUnit';
  }

  @override
  String get gasCalculators_rockBottom_yourSac => 'ה-SAC שלך';

  @override
  String get maps_heatMap_hide => 'הסתר מפת חום';

  @override
  String get maps_heatMap_overlayOff => 'שכבת מפת חום כבויה';

  @override
  String get maps_heatMap_overlayOn => 'שכבת מפת חום פעילה';

  @override
  String get maps_heatMap_show => 'הצג מפת חום';

  @override
  String get maps_offline_bounds => 'גבולות';

  @override
  String maps_offline_cacheHitRateAccessibility(Object rate) {
    return 'אחוז פגיעות מטמון: $rate אחוז';
  }

  @override
  String get maps_offline_cacheHits => 'פגיעות מטמון';

  @override
  String get maps_offline_cacheMisses => 'החטאות מטמון';

  @override
  String get maps_offline_cacheStatistics => 'סטטיסטיקת מטמון';

  @override
  String get maps_offline_cancelDownload => 'בטל הורדה';

  @override
  String get maps_offline_clearAll => 'נקה הכל';

  @override
  String get maps_offline_clearAllCache => 'נקה את כל המטמון';

  @override
  String get maps_offline_clearAllCacheMessage =>
      'למחוק את כל אזורי המפה שהורדו ואריחים שמורים?';

  @override
  String get maps_offline_clearAllCacheTitle => 'לנקות את כל המטמון?';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return 'פעולה זו תמחק $count אריחים ($size).';
  }

  @override
  String get maps_offline_created => 'נוצר';

  @override
  String maps_offline_deleteRegion(Object name) {
    return 'מחק אזור $name';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return 'למחוק את \"$name\" ואת $count האריחים שלו?\n\nפעולה זו תפנה $size של אחסון.';
  }

  @override
  String get maps_offline_deleteRegionTitle => 'למחוק אזור?';

  @override
  String get maps_offline_downloadedRegions => 'אזורים שהורדו';

  @override
  String maps_offline_downloading(Object regionName) {
    return 'מוריד: $regionName';
  }

  @override
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  ) {
    return 'מוריד $regionName, $percent אחוז הושלם, $downloaded מתוך $total אריחים';
  }

  @override
  String maps_offline_error(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String maps_offline_errorLoadingStats(Object error) {
    return 'שגיאה בטעינת סטטיסטיקות: $error';
  }

  @override
  String maps_offline_failedTiles(Object count) {
    return '$count נכשלו';
  }

  @override
  String maps_offline_hitRate(Object rate) {
    return 'אחוז פגיעות: $rate%';
  }

  @override
  String get maps_offline_lastAccessed => 'גישה אחרונה';

  @override
  String get maps_offline_noRegions => 'אין אזורים לא-מקוונים';

  @override
  String get maps_offline_noRegionsDescription =>
      'הורד אזורי מפה מדף פרטי האתר לשימוש במפות ללא חיבור.';

  @override
  String get maps_offline_refresh => 'רענן';

  @override
  String get maps_offline_region => 'אזור';

  @override
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size | $count אריחים | זום $minZoom-$maxZoom';
  }

  @override
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size, $count אריחים, זום $minZoom עד $maxZoom';
  }

  @override
  String get maps_offline_size => 'גודל';

  @override
  String get maps_offline_tiles => 'אריחים';

  @override
  String maps_offline_tilesPerSecond(Object rate) {
    return '$rate אריחים/שנ\'';
  }

  @override
  String maps_offline_tilesProgress(Object downloaded, Object total) {
    return '$downloaded / $total אריחים';
  }

  @override
  String get maps_offline_title => 'מפות לא-מקוונות';

  @override
  String get maps_offline_zoomRange => 'טווח זום';

  @override
  String get maps_regionSelector_dragToAdjust => 'גרור לשינוי הבחירה';

  @override
  String get maps_regionSelector_dragToSelect => 'גרור על המפה לבחירת אזור';

  @override
  String get maps_regionSelector_selectRegion => 'בחר אזור על המפה';

  @override
  String get maps_regionSelector_selectRegionButton => 'בחר אזור';

  @override
  String get tankPresets_addPreset => 'הוסף תבנית מיכל';

  @override
  String get tankPresets_builtInPresets => 'תבניות מובנות';

  @override
  String get tankPresets_customPresets => 'תבניות מותאמות אישית';

  @override
  String tankPresets_deleteMessage(Object name) {
    return 'האם אתה בטוח שברצונך למחוק את \"$name\"?';
  }

  @override
  String get tankPresets_deletePreset => 'מחק תבנית';

  @override
  String get tankPresets_deleteTitle => 'למחוק תבנית מיכל?';

  @override
  String tankPresets_deleted(Object name) {
    return 'נמחק \"$name\"';
  }

  @override
  String get tankPresets_editPreset => 'ערוך תבנית';

  @override
  String tankPresets_edit_created(Object name) {
    return 'נוצר \"$name\"';
  }

  @override
  String get tankPresets_edit_descriptionHint =>
      'לדוגמה, מיכל שכור מחנות הצלילה';

  @override
  String get tankPresets_edit_descriptionOptional => 'תיאור (אופציונלי)';

  @override
  String tankPresets_edit_errorLoading(Object error) {
    return 'שגיאה בטעינת תבנית: $error';
  }

  @override
  String tankPresets_edit_errorSaving(Object error) {
    return 'שגיאה בשמירת תבנית: $error';
  }

  @override
  String tankPresets_edit_gasCapacity(Object capacity) {
    return '• קיבולת גז: $capacity cuft';
  }

  @override
  String get tankPresets_edit_material => 'חומר';

  @override
  String get tankPresets_edit_name => 'שם';

  @override
  String get tankPresets_edit_nameHelper => 'שם ידידותי לתבנית מיכל זו';

  @override
  String get tankPresets_edit_nameHint => 'לדוגמה, ה-AL80 שלי';

  @override
  String get tankPresets_edit_nameRequired => 'אנא הזן שם';

  @override
  String get tankPresets_edit_ratedPressure => 'לחץ נקוב';

  @override
  String get tankPresets_edit_required => 'שדה חובה';

  @override
  String get tankPresets_edit_tankSpecifications => 'מפרט מיכל';

  @override
  String get tankPresets_edit_title => 'עריכת תבנית מיכל';

  @override
  String tankPresets_edit_updated(Object name) {
    return 'עודכן \"$name\"';
  }

  @override
  String get tankPresets_edit_validPressure => 'הזן לחץ תקין';

  @override
  String get tankPresets_edit_validVolume => 'הזן נפח תקין';

  @override
  String get tankPresets_edit_volume => 'נפח';

  @override
  String get tankPresets_edit_volumeHelperCuft => 'קיבולת גז (cuft)';

  @override
  String get tankPresets_edit_volumeHelperLiters => 'נפח מים (L)';

  @override
  String tankPresets_edit_waterVolume(Object volume) {
    return '• נפח מים: $volume L';
  }

  @override
  String get tankPresets_edit_workingPressure => 'לחץ עבודה';

  @override
  String tankPresets_edit_workingPressureBar(Object pressure) {
    return '• לחץ עבודה: $pressure bar';
  }

  @override
  String tankPresets_error(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String tankPresets_errorDeleting(Object error) {
    return 'שגיאה במחיקת תבנית: $error';
  }

  @override
  String get tankPresets_new_title => 'תבנית מיכל חדשה';

  @override
  String get tankPresets_noPresets => 'אין תבניות מיכל זמינות';

  @override
  String get tankPresets_title => 'תבניות מיכל';

  @override
  String get tools_deco_description =>
      'חשב מגבלות ללא-דקומפרסיה, עצירות דקו נדרשות, וחשיפת CNS/OTU לפרופילי צלילה מרובי-שכבות.';

  @override
  String get tools_deco_subtitle => 'תכנן צלילות עם עצירות דקומפרסיה';

  @override
  String get tools_deco_title => 'מחשבון דקו';

  @override
  String get tools_disclaimer =>
      'מחשבונים אלו מיועדים לתכנון בלבד. תמיד אמת חישובים ופעל לפי הכשרת הצלילה שלך.';

  @override
  String get tools_gas_description =>
      'ארבעה מחשבוני גז מתמחים:\n• MOD - עומק פעולה מרבי לתערובת גז\n• Best Mix - אחוז O₂ אידיאלי לעומק יעד\n• Consumption - הערכת צריכת גז\n• Rock Bottom - חישוב עתודה לחירום';

  @override
  String get tools_gas_subtitle => 'MOD, Best Mix, צריכה, Rock Bottom';

  @override
  String get tools_gas_title => 'מחשבוני גז';

  @override
  String get tools_title => 'כלים';

  @override
  String get tools_weight_aluminumImperial => 'ציפה יותר כשריק (+4 lbs)';

  @override
  String get tools_weight_aluminumMetric => 'ציפה יותר כשריק (+2 kg)';

  @override
  String get tools_weight_bodyWeightOptional => 'משקל גוף (אופציונלי)';

  @override
  String get tools_weight_carbonFiberImperial => 'ציפה מאוד (+7 lbs)';

  @override
  String get tools_weight_carbonFiberMetric => 'ציפה מאוד (+3 kg)';

  @override
  String get tools_weight_description =>
      'הערך את המשקל הנדרש על סמך חליפת החשיפה, חומר המיכל, סוג המים ומשקל הגוף.';

  @override
  String get tools_weight_disclaimer =>
      'זוהי הערכה בלבד. תמיד בצע בדיקת ציפה בתחילת הצלילה והתאם לפי הצורך. גורמים כמו BCD, ציפה אישית ודפוסי נשימה ישפיעו על דרישות המשקל בפועל.';

  @override
  String get tools_weight_exposureSuit => 'חליפת חשיפה';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return '• קיבולת גז: $capacity cuft';
  }

  @override
  String get tools_weight_helperImperial =>
      'מוסיף ~2 lbs לכל 22 lbs מעל 154 lbs';

  @override
  String get tools_weight_helperMetric => 'מוסיף ~1 kg לכל 10 kg מעל 70 kg';

  @override
  String get tools_weight_notSpecified => 'לא צוין';

  @override
  String get tools_weight_recommendedWeight => 'משקל מומלץ';

  @override
  String tools_weight_resultAccessibility(Object weight, Object unit) {
    return 'משקל מומלץ: $weight $unit';
  }

  @override
  String get tools_weight_steelImperial => 'שלילי ציפה (-4 lbs)';

  @override
  String get tools_weight_steelMetric => 'שלילי ציפה (-2 kg)';

  @override
  String get tools_weight_subtitle => 'משקל מומלץ להתקנה שלך';

  @override
  String get tools_weight_tankMaterial => 'חומר מיכל';

  @override
  String get tools_weight_tankSpecifications => 'מפרט מיכל';

  @override
  String get tools_weight_title => 'מחשבון משקל';

  @override
  String get tools_weight_waterType => 'סוג מים';

  @override
  String tools_weight_waterVolume(Object volume) {
    return '• נפח מים: $volume L';
  }

  @override
  String tools_weight_workingPressure(Object pressure) {
    return '• לחץ עבודה: $pressure bar';
  }

  @override
  String get tools_weight_yourWeight => 'המשקל שלך';
}
