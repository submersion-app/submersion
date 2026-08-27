// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get universalImport_action_importFromGarmin => 'ייבוא מהתקן Garmin';

  @override
  String diveLog_edit_flightWindowWarning(String time) {
    return 'הצלילה הזו מסתיימת אחרי הזמן הבטוח האחרון לעלייה לפני הטיסה שלך ($time)';
  }

  @override
  String diveLog_edit_geofenceSuggestion_near(String location) {
    return 'ליד $location';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_title => 'הצעת ציוד';

  @override
  String diveLog_edit_geofenceSuggestion_body(String setName) {
    return 'להחיל את ערכת \"$setName\"?';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_apply => 'החל';

  @override
  String get common_action_dismiss => 'התעלם';

  @override
  String get equipment_setEdit_defaultSwitch_title => 'ערכת ברירת מחדל';

  @override
  String get equipment_setEdit_defaultSwitch_subtitle =>
      'מוחלת אוטומטית על צלילות חדשות שאין בהן ציוד עדיין';

  @override
  String get equipment_setEdit_geofencesTitle => 'גדרות גאוגרפיות';

  @override
  String get equipment_setEdit_geofencesSubtitle =>
      'הצע ערכה זו אוטומטית לצלילות ליד מיקומים אלה';

  @override
  String get equipment_setEdit_addGeofence => 'הוסף גדר גאוגרפית';

  @override
  String get equipment_setEdit_editGeofence => 'Edit geofence';

  @override
  String get equipment_setEdit_removeGeofence => 'Remove geofence';

  @override
  String equipment_setEdit_geofenceRadius(String distance) {
    return 'רדיוס: $distance';
  }

  @override
  String get equipment_geofenceEditor_title => 'גדר גאוגרפית';

  @override
  String get equipment_geofenceEditor_fromSite => 'מאתר הצלילה';

  @override
  String get equipment_geofenceEditor_dropPin => 'הצב סיכה';

  @override
  String get equipment_geofenceEditor_labelLabel => 'תווית';

  @override
  String get equipment_geofenceEditor_noCenter => 'בחר נקודת מרכז';

  @override
  String get equipment_geofenceEditor_save => 'שמור גדר גאוגרפית';

  @override
  String get equipment_sets_defaultBadge => 'ברירת מחדל';

  @override
  String get equipment_setDetail_setAsDefault => 'הגדר כברירת מחדל';

  @override
  String equipment_setDetail_setAsDefaultSnackbar(String name) {
    return '\"$name\" היא כעת ערכת ברירת המחדל שלך';
  }

  @override
  String get equipment_setDetail_geofencesTitle => 'גדרות גאוגרפיות';

  @override
  String get equipment_setDetail_noGeofences => 'אין גדרות גאוגרפיות';

  @override
  String formatter_duration_minutes(Object minutes) {
    return '$minutes דק\'';
  }

  @override
  String formatter_duration_minutesSeconds(Object minutes, Object seconds) {
    return '$minutes דק\' $seconds שנ\'';
  }

  @override
  String formatter_duration_seconds(Object seconds) {
    return '$seconds שנ\'';
  }

  @override
  String gasCalculators_bestMix_densityCritical(Object limit) {
    return 'מעל תקרת הצפיפות המוחלטת של $limit g/L.';
  }

  @override
  String get gasCalculators_bestMix_densityLabel => 'צפיפות הגז בעומק';

  @override
  String gasCalculators_bestMix_densityWarn(Object limit) {
    return 'מעל מגבלת הצפיפות המומלצת של $limit g/L.';
  }

  @override
  String gasCalculators_bestMix_endExceeded(Object limit) {
    return 'ה-END חורג מהמגבלה שלך $limit.';
  }

  @override
  String get gasCalculators_bestMix_endLabel => 'END בעומק';

  @override
  String get gasCalculators_bestMix_endLimitLabel => 'מגבלת END';

  @override
  String gasCalculators_bestMix_heliumAdded(Object limit) {
    return 'נוסף הליום כדי לשמור על ה-END בתוך המגבלה שלך $limit.';
  }

  @override
  String get gasCalculators_bestMix_idealLabel => 'שיעור אידאלי';

  @override
  String get gasCalculators_bestMix_marginLabel => 'מרווח מתחת ל-MOD';

  @override
  String gasCalculators_bestMix_modLabel(Object ppO2) {
    return 'MOD ב-ppO2 $ppO2';
  }

  @override
  String get gasCalculators_bestMix_nearestStandard =>
      'התערובת התקנית הקרובה ביותר המכסה עומק זה';

  @override
  String get gasCalculators_bestMix_recommendedMix => 'תערובת מומלצת';

  @override
  String get gasCalculators_bestMix_withoutHelium => 'ללא הליום';

  @override
  String get gasCalculators_planningCaveat =>
      'הערכת תכנון. מניחה עלייה ישירה. ודא מול ההכשרה שלך והוסף מרווח לתנאים.';

  @override
  String gasCalculators_rockBottom_solveGas(Object depth, Object unit) {
    return 'גז לפתרון תקלה בעומק $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_solveTime => 'זמן לפתרון תקלה';

  @override
  String get gasCalculators_rockBottom_solveTimeHint =>
      'הזמן בעומק לפתרון החירום לפני תחילת העלייה.';

  @override
  String o2Toxicity_addedThisDive(Object value) {
    return '+$value בצלילה זו';
  }

  @override
  String o2Toxicity_cnsProgressSemantics(Object percent) {
    return 'התקדמות CNS $percent אחוזים';
  }

  @override
  String get o2Toxicity_daily => 'יומי';

  @override
  String o2Toxicity_otuSemantics(
    Object label,
    Object value,
    Object limit,
    Object percent,
  ) {
    return '$label: $value מתוך $limit OTU, $percent אחוזים';
  }

  @override
  String o2Toxicity_otuValueSemantics(Object label, Object value) {
    return '$label: $value OTU';
  }

  @override
  String o2Toxicity_prior(Object value) {
    return 'קודם: $value OTU';
  }

  @override
  String o2Toxicity_start(Object value) {
    return 'התחלה: $value OTU';
  }

  @override
  String get o2Toxicity_thisDive => 'צלילה זו';

  @override
  String get o2Toxicity_weekly => 'שבועי';

  @override
  String trips_story_dayLabel(int number) {
    return 'יום $number';
  }

  @override
  String get trips_story_surfaceDay => 'יום פני השטח';

  @override
  String get trips_story_today => 'היום';

  @override
  String trips_story_dayOfTrip(int current, int total) {
    return 'יום $current מתוך $total';
  }

  @override
  String trips_story_daysUntil(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ימים עד היציאה',
      one: 'יום אחד עד היציאה',
    );
    return '$_temp0';
  }

  @override
  String trips_story_checklistProgress(int done, int total) {
    return '$done מתוך $total הושלמו';
  }

  @override
  String get trips_story_generateItinerary => 'צור מסלול';

  @override
  String get trips_story_openGallery => 'פתיחת תמונות הטיול';

  @override
  String trips_story_generateItineraryError(String error) {
    return 'לא ניתן ליצור מסלול: $error';
  }

  @override
  String get trips_dayType_diveDay => 'יום צלילה';

  @override
  String get trips_dayType_seaDay => 'יום ים';

  @override
  String get trips_dayType_portDay => 'יום נמל';

  @override
  String get trips_dayType_embark => 'עלייה לסיפון';

  @override
  String get trips_dayType_disembark => 'ירידה מהסיפון';

  @override
  String get trips_story_planned => 'מתוכנן';

  @override
  String get trips_story_empty_title => 'אין עדיין צלילות או מסלול';

  @override
  String get trips_story_empty_subtitle =>
      'הוסף צלילות לטיול או תכנן את הימים כדי לראות את הסיפור.';

  @override
  String trips_story_history_dives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות קודמות כאן',
      one: 'צלילה קודמת אחת כאן',
    );
    return '$_temp0';
  }

  @override
  String trips_story_history_avgTemp(String value) {
    return 'ממוצע $value';
  }

  @override
  String trips_story_history_avgDepth(String value) {
    return 'עומק ממוצע $value';
  }

  @override
  String get trips_story_rhythm_semantics => 'זמני הצלילה ביום זה';

  @override
  String get trips_story_map_semantics => 'מפת הטיול. אתרי היום המוצג מודגשים.';

  @override
  String get diveLog_bulkEdit_groupRebreather => 'מצב צלילה וריבריא\'תר';

  @override
  String get diveLog_bulkEdit_fieldSetpointLow => 'ערך יעד נמוך';

  @override
  String get diveLog_bulkEdit_fieldSetpointHigh => 'ערך יעד גבוה';

  @override
  String get diveLog_bulkEdit_fieldSetpointDeco => 'ערך יעד דקומפרסיה';

  @override
  String get diveLog_bulkEdit_fieldScrubberType => 'סוג מסנן';

  @override
  String get diveLog_bulkEdit_fieldScrubberDuration => 'משך המסנן';

  @override
  String get diveLog_bulkEdit_contradiction =>
      'מצב מעגל פתוח אינו תומך בהגדרות ריבריא\'תר. כבה שדות אלה או שנה את המצב.';

  @override
  String diveLog_bulkEdit_appBarTitle(int count) {
    return 'עריכת $count צלילות';
  }

  @override
  String get diveLog_bulkEdit_groupLogistics => 'לוגיסטיקה';

  @override
  String get diveLog_bulkEdit_groupWeather => 'מזג אוויר';

  @override
  String get diveLog_bulkEdit_groupCollections => 'תגיות, ציוד וחיים';

  @override
  String get diveLog_bulkEdit_fieldFavorite => 'מועדף';

  @override
  String get diveLog_bulkEdit_fieldMyRole => 'התפקיד שלי';

  @override
  String get diveLog_bulkEdit_buddyRoleMixed => 'מעורב';

  @override
  String get diveLog_bulkEdit_collectionWeights => 'משקולות';

  @override
  String get diveLog_bulkEdit_collectionTanks => 'מכלים';

  @override
  String get diveLog_bulkEdit_notesSet => 'הגדר';

  @override
  String get diveLog_bulkEdit_notesAppend => 'הוסף בסוף';

  @override
  String get diveLog_bulkEdit_modeAdd => 'הוסף';

  @override
  String get diveLog_bulkEdit_modeRemove => 'הסר';

  @override
  String get diveLog_bulkEdit_modeReplace => 'החלף';

  @override
  String get diveLog_bulkEdit_modeUpdate => 'עדכון';

  @override
  String get diveLog_bulkEdit_tankOnlyIfEmpty => 'רק צלילות ללא מכל קיים';

  @override
  String get diveLog_bulkEdit_tankSpecsHint =>
      'בחר אילו מאפיינים לדרוס במיכלים שכבר קיימים בצלילות אלה. לחצי ההתחלה והסיום לעולם אינם משתנים.';

  @override
  String get diveLog_bulkEdit_tankSpecsNoFields =>
      'בחר לפחות מאפיין אחד של מיכל לעדכון.';

  @override
  String get diveLog_bulkEdit_tankFieldPreset => 'הגדרה מראש';

  @override
  String get diveLog_bulkEdit_tankFieldRole => 'תפקיד';

  @override
  String get diveLog_bulkEdit_tankFieldVolume => 'נפח';

  @override
  String get diveLog_bulkEdit_tankFieldWorkingPressure => 'לחץ עבודה';

  @override
  String get diveLog_bulkEdit_tankFieldMaterial => 'חומר';

  @override
  String get diveLog_bulkEdit_tankFieldGasMix => 'תערובת גז';

  @override
  String get diveLog_bulkEdit_tankFieldName => 'שם';

  @override
  String diveLog_bulkEdit_tankSpecsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות שנבחרו ללא מיכלים וידולגו.',
      one: 'צלילה אחת שנבחרה ללא מיכלים ותידולג.',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_bulkEdit_confirmTitle => 'להחיל שינויים?';

  @override
  String get diveLog_bulkEdit_confirmApply => 'החל';

  @override
  String get diveLog_bulkEdit_nothingSelected =>
      'הפעל לפחות שדה אחד כדי להחיל שינויים.';

  @override
  String diveLog_bulkEdit_applied(int count) {
    return '$count צלילות עודכנו';
  }

  @override
  String get settings_cloudSync_error_icloudSignedOut =>
      'iCloud אינו זמין. היכנס ל-iCloud דרך הגדרות המכשיר.';

  @override
  String get settings_cloudSync_error_icloudUnknown =>
      'לא ניתן היה להגיע ל-iCloud. נסה שוב.';

  @override
  String get settings_cloudSync_error_icloudUnsupported =>
      'סנכרון iCloud אינו זמין בגרסה זו של Submersion. השתמש בסנכרון S3 או בגרסת App Store.';

  @override
  String get settings_cloudSync_provider_icloud_unsupportedSubtitle =>
      'לא זמין בגרסה זו — השתמש ב-S3 או בגרסת App Store';

  @override
  String get settings_cloudSync_encryption_title => 'הצפנה מקצה לקצה';

  @override
  String get settings_cloudSync_encryption_subtitleOff =>
      'הצפנת כל נתוני הסנכרון והגיבויים בענן לפני ההעלאה';

  @override
  String get settings_cloudSync_encryption_subtitleNeedsProvider =>
      'בחרו קודם ספק ענן';

  @override
  String get settings_cloudSync_encryption_statusOff => 'ההצפנה כבויה';

  @override
  String get settings_cloudSync_encryption_statusOn => 'ההצפנה פועלת';

  @override
  String get settings_cloudSync_encryption_statusOnSubtitle =>
      'נתוני סנכרון וגיבויים בענן מוצפנים לפני ההעלאה';

  @override
  String get settings_cloudSync_encryption_statusLocked =>
      'מוצפן — נדרש משפט סיסמה';

  @override
  String get settings_cloudSync_encryption_statusLockedSubtitle =>
      'הזינו את משפט הסיסמה כדי לסנכרן במכשיר זה';

  @override
  String get settings_cloudSync_encryption_enable => 'הפעלת הצפנה';

  @override
  String get settings_cloudSync_encryption_enterPassphrase => 'הזנת משפט סיסמה';

  @override
  String get settings_cloudSync_encryption_passphrase => 'משפט סיסמה';

  @override
  String get settings_cloudSync_encryption_passphraseConfirm =>
      'אישור משפט הסיסמה';

  @override
  String get settings_cloudSync_encryption_passphraseMismatch =>
      'משפטי הסיסמה אינם תואמים';

  @override
  String get settings_cloudSync_encryption_passphraseTooShort =>
      'השתמשו ב-8 תווים לפחות';

  @override
  String get settings_cloudSync_encryption_wrongPassphrase =>
      'משפט סיסמה או קוד שחזור שגויים';

  @override
  String get settings_cloudSync_encryption_warnUpdateDevices =>
      'יש לעדכן את כל שאר המכשירים לגרסת האפליקציה האחרונה והם יורידו מחדש את הספרייה.';

  @override
  String get settings_cloudSync_encryption_warnLoss =>
      'אם תאבדו גם את משפט הסיסמה וגם את קוד השחזור, לא ניתן יהיה לשחזר את הנתונים בענן. הנתונים במכשירים שלכם לעולם אינם בסיכון.';

  @override
  String get settings_cloudSync_encryption_deletePlaintextBackups =>
      'מחיקת גיבויי ענן לא מוצפנים קיימים';

  @override
  String get settings_cloudSync_encryption_recoveryTitle => 'קוד שחזור';

  @override
  String get settings_cloudSync_encryption_recoveryExplain =>
      'רשמו את הקוד הזה ושמרו אותו במקום בטוח. זו הדרך היחידה לחזור אם תשכחו את משפט הסיסמה.';

  @override
  String get settings_cloudSync_encryption_recoverySavedConfirm =>
      'שמרתי את קוד השחזור שלי';

  @override
  String get settings_cloudSync_encryption_changePassphrase =>
      'שינוי משפט סיסמה';

  @override
  String get settings_cloudSync_encryption_currentPassphrase =>
      'משפט הסיסמה הנוכחי';

  @override
  String get settings_cloudSync_encryption_newPassphrase => 'משפט סיסמה חדש';

  @override
  String get settings_cloudSync_encryption_regenerateRecovery =>
      'יצירת קוד שחזור חדש';

  @override
  String get settings_cloudSync_encryption_regenerateRecoveryWarn =>
      'קוד השחזור הישן מפסיק לפעול מיד.';

  @override
  String get settings_cloudSync_encryption_disable => 'כיבוי ההצפנה';

  @override
  String get settings_cloudSync_encryption_disableWarn =>
      'הספרייה תועלה מחדש ללא הצפנה ושאר המכשירים יורידו אותה שוב. גיבויים מוצפנים קיימים יישארו ניתנים לשחזור עם משפט הסיסמה.';

  @override
  String get settings_cloudSync_encryption_unlockTitle =>
      'הזינו את משפט הסיסמה של ההצפנה';

  @override
  String get settings_cloudSync_encryption_unlockHint =>
      'משפט סיסמה או קוד שחזור';

  @override
  String get settings_cloudSync_encryption_unlock => 'ביטול נעילה';

  @override
  String get settings_cloudSync_encryption_continue => 'המשך';

  @override
  String get settings_cloudSync_encryption_done => 'סיום';

  @override
  String get settings_cloudSync_encryption_cancel => 'ביטול';

  @override
  String get settings_backupEncryption_title => 'הצפנת גיבוי';

  @override
  String get settings_backupEncryption_subtitleOff =>
      'הגן על הגיבויים שלך באמצעות סיסמה';

  @override
  String get settings_backupEncryption_subtitleOn =>
      'הגיבויים מוצפנים באמצעות הסיסמה שלך';

  @override
  String get settings_backupEncryption_enable => 'הצפן גיבויים';

  @override
  String get settings_backupEncryption_turnOff => 'כבה הצפנה';

  @override
  String get settings_backupEncryption_turnOffTitle => 'לכבות את הצפנת הגיבוי?';

  @override
  String get settings_backupEncryption_turnOffBody =>
      'גיבויים חדשים לא יוצפנו עוד. גיבויים מוצפנים קיימים עדיין דורשים את הסיסמה שלך לשחזור.';

  @override
  String get settings_backupEncryption_changePassword => 'שנה סיסמה';

  @override
  String get settings_backupEncryption_regenerateRecovery =>
      'צור מחדש קוד שחזור';

  @override
  String get settings_backupEncryption_password => 'סיסמה';

  @override
  String get settings_backupEncryption_passwordConfirm => 'אימות סיסמה';

  @override
  String get settings_backupEncryption_passwordTooShort =>
      'השתמש בלפחות 8 תווים';

  @override
  String get settings_backupEncryption_passwordMismatch =>
      'הסיסמאות אינן תואמות';

  @override
  String get settings_backupEncryption_currentPassword => 'סיסמה נוכחית';

  @override
  String get settings_backupEncryption_newPassword => 'סיסמה חדשה';

  @override
  String get settings_backupEncryption_changePasswordWarn =>
      'במכשיר אחר, כל גיבוי נפתח באמצעות הסיסמה או קוד השחזור שהיו פעילים בעת יצירתו.';

  @override
  String get settings_backupEncryption_warnLoss =>
      'אם תשכח את הסיסמה שלך ותאבד את קוד השחזור, לא ניתן יהיה לשחזר גיבויים מוצפנים.';

  @override
  String get settings_backupEncryption_recoveryTitle => 'קוד השחזור שלך';

  @override
  String get settings_backupEncryption_recoveryExplain =>
      'שמור קוד זה במקום בטוח. הוא יכול לבטל את נעילת הגיבויים שלך אם תשכח את הסיסמה.';

  @override
  String get settings_backupEncryption_recoverySavedConfirm =>
      'שמרתי את קוד השחזור שלי';

  @override
  String get settings_backupEncryption_unlockTitle => 'הזן סיסמת גיבוי';

  @override
  String get settings_backupEncryption_unlockHint =>
      'הזן את סיסמת הגיבוי או קוד השחזור שלך';

  @override
  String get settings_backupEncryption_restoreUnlockTitle =>
      'פתיחת גיבוי מוצפן';

  @override
  String get settings_backupEncryption_restoreUnlockHint =>
      'הזן את הסיסמה או קוד השחזור עבור גיבוי זה';

  @override
  String get settings_backupEncryption_continue => 'המשך';

  @override
  String get settings_backupEncryption_cancel => 'ביטול';

  @override
  String get settings_backupEncryption_done => 'סיום';

  @override
  String get settings_backupEncryption_reencryptTitle =>
      'להצפין גיבויים קיימים?';

  @override
  String get settings_backupEncryption_reencryptBody =>
      'הגיבויים הקיימים שלך עדיין אינם מוצפנים. להצפין אותם מחדש כעת באמצעות הסיסמה החדשה שלך?';

  @override
  String get settings_backupEncryption_reencryptNow => 'הצפן מחדש כעת';

  @override
  String get settings_backupEncryption_reencryptNotNow => 'לא כעת';

  @override
  String settings_backupEncryption_reencryptPartial(int done, int failed) {
    return '$done גיבויים הוצפנו מחדש; לא ניתן היה להצפין $failed והם עדיין אינם מוגנים';
  }

  @override
  String settings_backupEncryption_reencryptDone(int count) {
    return '$count גיבויים הוצפנו מחדש';
  }

  @override
  String get settings_backupEncryption_wrongPassword =>
      'סיסמה או קוד שחזור שגויים';

  @override
  String settings_cloudSync_replace_globalBanner(String deviceName) {
    return 'הסנכרון מושהה — הספרייה הוחלפה מגיבוי במכשיר \"$deviceName\".';
  }

  @override
  String get settings_cloudSync_postRestore_syncing =>
      'מסנכרן את הספרייה המשוחזרת שלך עם הענן…';

  @override
  String get settings_cloudSync_postRestore_synced =>
      'הספרייה המשוחזרת סונכרנה.';

  @override
  String get settings_cloudSync_replace_reviewAction => 'סקירה';

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
  String get accessibility_label_resizeMasterPane =>
      'שינוי גודל החלונית הראשית';

  @override
  String get accessibility_label_sharedWithAllProfiles =>
      'משותף עם כל פרופילי הצלילה';

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
  String get backup_export_bottomSheet_title => 'ייצוא גיבוי';

  @override
  String get backup_export_saveToFile => 'שמירה לקובץ';

  @override
  String get backup_export_saveToFile_subtitle =>
      'בחר היכן לשמור את קובץ הגיבוי';

  @override
  String get backup_export_share => 'שיתוף';

  @override
  String get backup_export_share_subtitle =>
      'שליחה דרך AirDrop, דוא\"ל או אפליקציות אחרות';

  @override
  String get backup_export_subtitle => 'שמור את נתוני הצלילה שלך לקובץ';

  @override
  String get backup_export_success => 'הגיבוי יוצא בהצלחה';

  @override
  String get backup_export_title => 'ייצוא גיבוי';

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
  String get backup_history_pinAction_pin => 'הצמד גיבוי';

  @override
  String get backup_history_pinAction_unpin => 'בטל הצמדת גיבוי';

  @override
  String get backup_history_pinError => 'לא ניתן לעדכן את מצב ההצמדה.';

  @override
  String backup_history_preMigrationSubtitle(String size) {
    return 'גיבוי לפני העברה - $size';
  }

  @override
  String get backup_import_invalidFile =>
      'נראה שקובץ זה אינו גיבוי תקין של Submersion';

  @override
  String get backup_import_subtitle => 'ייבא גיבוי מכל מיקום';

  @override
  String get backup_import_title => 'שחזור מקובץ';

  @override
  String get backup_import_validating => 'מאמת קובץ גיבוי...';

  @override
  String get backup_location_change => 'שינוי';

  @override
  String get backup_location_default => 'מיקום ברירת מחדל';

  @override
  String get backup_location_title => 'מיקום הגיבוי';

  @override
  String get backup_replaceConfirm_confirm => 'החלפה בכל מקום';

  @override
  String get backup_replaceConfirm_content =>
      'הספרייה בכל המכשירים המסונכרנים תוחלף בגיבוי זה. כל מכשיר יוצר תחילה גיבוי בטיחות של הנתונים הנוכחיים שלו. לא ניתן לבטל פעולה זו.';

  @override
  String get backup_replaceConfirm_title => 'להחליף את הספרייה בכל מקום?';

  @override
  String get backup_restore_dialog_cancel => 'ביטול';

  @override
  String get backup_restore_dialog_modeMerge_subtitle =>
      'שחזור במכשיר זה. הסנכרון הבא ישלב את הנתונים המשוחזרים עם ספריית הענן.';

  @override
  String get backup_restore_dialog_modeMerge_title => 'מיזוג בסנכרון הבא';

  @override
  String get backup_restore_dialog_modeReplace_subtitle =>
      'הגיבוי הופך לספרייה במכשיר זה, בענן ובכל מכשיר מסונכרן.';

  @override
  String get backup_restore_dialog_modeReplace_title => 'החלפה בכל מקום';

  @override
  String get backup_restore_dialog_restore => 'שחזור';

  @override
  String get backup_restore_dialog_restoreReplace => 'שחזור והחלפה בכל מקום';

  @override
  String get backup_restore_dialog_safetyNote =>
      'גיבוי בטיחות של הנתונים הנוכחיים שלך ייווצר אוטומטית לפני השחזור.';

  @override
  String get backup_restore_dialog_title => 'שחזור גיבוי';

  @override
  String get backup_restore_dialog_warning =>
      'פעולה זו תחליף את כל הנתונים הנוכחיים בנתוני הגיבוי. לא ניתן לבטל פעולה זו.';

  @override
  String backup_restore_safetyReview_progress(int done, int total) {
    return 'נותחו $done מתוך $total צלילות';
  }

  @override
  String get backup_restore_safetyReview_skip => 'דלג';

  @override
  String get backup_restore_safetyReview_title => 'מריץ את סקירת הבטיחות';

  @override
  String get backup_restoreComplete_continue => 'המשך';

  @override
  String get backup_restoreComplete_description =>
      'הנתונים שלך שוחזרו בהצלחה. הקש על המשך כדי לטעון מחדש את האפליקציה עם הנתונים המשוחזרים.';

  @override
  String get backup_restoreComplete_title => 'השחזור הושלם';

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
  String get backup_section_auto => 'גיבויים אוטומטיים';

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
  String get buddies_action_addCertification => 'הוסף הסמכה';

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
  String get buddies_picker_addCustomRole => 'הוסף תפקיד מותאם...';

  @override
  String get buddies_picker_addNew => 'הוסף חבר צוללים חדש';

  @override
  String get buddies_picker_done => 'סיום';

  @override
  String get buddies_picker_me => 'אני';

  @override
  String get buddies_picker_noBuddiesFound => 'לא נמצאו חברי צוללים';

  @override
  String get buddies_picker_noBuddiesYet => 'עדיין אין חברי צוללים';

  @override
  String get buddies_picker_noRole => 'ללא תפקיד';

  @override
  String get buddies_picker_noneSelected => 'לא נבחרו חברי צוללים';

  @override
  String get buddies_picker_searchHint => 'חפש חברי צוללים...';

  @override
  String get buddies_picker_selectBuddies => 'בחר חברי צוללים';

  @override
  String get buddies_picker_selectMyRole => 'בחר את התפקיד שלי';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'בחר תפקיד עבור $name';
  }

  @override
  String get buddies_picker_setMyRole => 'הגדר את התפקיד שלי';

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
  String get buddies_section_certifications => 'הסמכות';

  @override
  String get buddies_certifications_empty => 'אין הסמכות';

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
  String get buddies_list_selection_closeTooltip => 'סגור בחירה';

  @override
  String buddies_list_selection_count(int count) {
    return '$count נבחרו';
  }

  @override
  String get buddies_list_selection_selectAllTooltip => 'בחר הכל';

  @override
  String get buddies_list_selection_deselectAllTooltip => 'בטל בחירת הכל';

  @override
  String get buddies_list_selection_mergeTooltip => 'מזג נבחרים';

  @override
  String get buddies_list_selection_deleteTooltip => 'מחק נבחרים';

  @override
  String buddies_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'חברי צוללים',
      one: 'חבר צוללים',
    );
    return 'מוזגו $count $_temp0';
  }

  @override
  String get buddies_list_merge_undo => 'בטל';

  @override
  String get buddies_list_merge_restored => 'המיזוג בוטל';

  @override
  String get buddies_list_bulkDelete_title => 'מחק חברי צוללים';

  @override
  String buddies_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'חברי צוללים',
      one: 'חבר צוללים',
    );
    return 'האם אתה בטוח שברצונך למחוק $count $_temp0? לא ניתן לבטל פעולה זו.';
  }

  @override
  String get buddies_list_bulkDelete_cancel => 'ביטול';

  @override
  String get buddies_list_bulkDelete_confirm => 'מחק';

  @override
  String buddies_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'חברי צוללים',
      one: 'חבר צוללים',
    );
    return 'נמחקו $count $_temp0';
  }

  @override
  String get buddies_edit_merge_title => 'מזג חברי צוללים';

  @override
  String get buddies_edit_merge_fieldSourceCycleTooltip =>
      'השתמש בערך מחבר הצוללים הנבחר הבא';

  @override
  String buddies_edit_merge_fieldSourceLabel(
    String buddyName,
    int current,
    int total,
  ) {
    return 'מ-$buddyName ($current/$total)';
  }

  @override
  String get buddies_edit_merge_confirmTitle => 'מזג חברי צוללים';

  @override
  String buddies_edit_merge_confirmBody(int count) {
    return 'פעולה זו תמזג $count חברי צוללים לאחד. קישורי הצלילות יאוחדו תחת חבר הצוללים הנותר. שאר חברי הצוללים יימחקו.';
  }

  @override
  String get buddies_edit_merge_loadingErrorTitle => 'מזג חברי צוללים';

  @override
  String buddies_edit_merge_loadingErrorBody(String error) {
    return 'טעינת חברי צוללים נכשלה: $error';
  }

  @override
  String get buddies_edit_merge_notEnoughTitle => 'מזג חברי צוללים';

  @override
  String get buddies_edit_merge_notEnoughBody =>
      'אין מספיק חברי צוללים למיזוג.';

  @override
  String get buddies_instructorPicker_label => 'מדריך מתוך חברי הצוללים';

  @override
  String get buddies_instructorPicker_none => 'ללא (הזנה ידנית)';

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
  String get certifications_detail_label_certification => 'הסמכה';

  @override
  String get certifications_detail_label_expiryDate => 'תאריך תפוגה';

  @override
  String get certifications_detail_label_instructorName => 'שם';

  @override
  String get certifications_detail_label_instructorNumber => 'מספר מדריך';

  @override
  String get certifications_detail_label_issueDate => 'תאריך הנפקה';

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
  String get certifications_ecard_label_cardNumber => 'מספר כרטיס';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'הוסמך על ידי $agency';
  }

  @override
  String get certifications_ecard_label_diver => 'צוללן';

  @override
  String get certifications_ecard_label_instructor => 'מדריך';

  @override
  String get certifications_ecard_label_issued => 'הונפק';

  @override
  String get certifications_ecard_label_validUntil => 'בתוקף עד';

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
  String get certifications_edit_certification_notSpecified => 'לא צוין';

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
  String get certifications_edit_group_progression => 'התקדמות';

  @override
  String get certifications_edit_group_specialties => 'התמחויות';

  @override
  String get certifications_edit_help_expiryDate =>
      'השאר ריק להסמכות ללא תפוגה';

  @override
  String get certifications_edit_helper_nameOnCard => 'אופציונלי';

  @override
  String get certifications_edit_hint_cardNumber => 'הזן מספר כרטיס הסמכה';

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
  String get certifications_edit_label_certification => 'הסמכה';

  @override
  String get certifications_edit_label_expiryDate => 'תאריך תפוגה';

  @override
  String get certifications_edit_label_instructorName => 'שם המדריך';

  @override
  String get certifications_edit_label_instructorNumber => 'מספר המדריך';

  @override
  String get certifications_edit_label_issueDate => 'תאריך הנפקה';

  @override
  String get certifications_edit_label_nameOnCard => 'השם על הכרטיס';

  @override
  String get certifications_edit_label_notes => 'הערות';

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
  String get certifications_edit_validation_certificationOrNameRequired =>
      'יש לבחור הסמכה או להזין שם';

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
  String get checklists_section_title => 'רשימת משימות';

  @override
  String checklists_progress(int done, int total) {
    return '$done מתוך $total משימות הושלמו';
  }

  @override
  String get checklists_empty_upcoming =>
      'תכנן את הטיול שלך - הוסף משימות או החל תבנית';

  @override
  String get checklists_empty_past => 'אין פריטים ברשימת המשימות';

  @override
  String get checklists_addItem => 'הוסף פריט';

  @override
  String get checklists_item_titleLabel => 'כותרת';

  @override
  String get checklists_item_titleRequired => 'כותרת נדרשת';

  @override
  String get checklists_item_categoryLabel => 'קטגוריה';

  @override
  String get checklists_item_notesLabel => 'הערות';

  @override
  String get checklists_item_dueDateLabel => 'תאריך יעד';

  @override
  String get checklists_item_dueOffsetLabel => 'ימים לפני תחילת הטיול';

  @override
  String get checklists_item_dueOffsetInvalid => 'הזן 0 ימים או יותר';

  @override
  String get checklists_item_overdue => 'באיחור';

  @override
  String get checklists_item_edit => 'ערוך פריט';

  @override
  String get checklists_item_delete => 'מחק פריט';

  @override
  String get checklists_menu_applyTemplate => 'החל תבנית...';

  @override
  String get checklists_menu_saveAsTemplate => 'שמור כתבנית...';

  @override
  String get checklists_applySheet_title => 'החלת תבנית';

  @override
  String get checklists_applySheet_empty =>
      'עדיין אין תבניות. ניתן ליצור אותן בהגדרות.';

  @override
  String checklists_applySheet_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים',
      one: 'פריט אחד',
    );
    return '$_temp0';
  }

  @override
  String checklists_applySheet_confirmAppend(int added, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added פריטים יתווספו',
      one: 'פריט אחד יתווסף',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped כפילויות ידולגו',
      one: 'כפילות אחת תדולג',
      zero: 'לא ידולגו כפילויות',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String checklists_apply_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים נוספו',
      one: 'פריט אחד נוסף',
      zero: 'לא נוספו פריטים חדשים',
    );
    return '$_temp0';
  }

  @override
  String get checklists_apply_templateGone => 'התבנית כבר לא קיימת';

  @override
  String get checklists_saveTemplate_title => 'שמירה כתבנית';

  @override
  String get checklists_saveTemplate_nameLabel => 'שם התבנית';

  @override
  String get checklists_saveTemplate_success => 'התבנית נשמרה';

  @override
  String get checklists_templates_pageTitle => 'תבניות רשימות משימות';

  @override
  String get checklists_templates_addTemplate => 'הוסף תבנית';

  @override
  String get checklists_templates_empty => 'עדיין אין תבניות';

  @override
  String get checklists_templates_deleteTitle => 'מחיקת תבנית';

  @override
  String checklists_templates_deleteContent(Object name) {
    return 'למחוק את \"$name\"? טיולים שכבר החילו אותה ישמרו את הפריטים שלהם.';
  }

  @override
  String get checklists_template_nameLabel => 'שם';

  @override
  String get checklists_template_nameRequired => 'שם נדרש';

  @override
  String get checklists_template_descriptionLabel => 'תיאור';

  @override
  String get checklists_template_itemsHeader => 'פריטים';

  @override
  String get checklists_template_addItem => 'הוסף פריט';

  @override
  String get preDive_templates_title => 'רשימות בדיקה לפני צלילה';

  @override
  String get preDive_templates_empty => 'עדיין אין רשימות בדיקה לפני צלילה';

  @override
  String get preDive_templates_builtInBadge => 'מובנית';

  @override
  String get preDive_templates_clone => 'שכפול';

  @override
  String get preDive_templates_cloneSuffix => ' (עותק)';

  @override
  String get preDive_templates_delete => 'מחיקה';

  @override
  String get preDive_templates_deleteConfirm =>
      'למחוק את תבנית רשימת הבדיקה הזו?';

  @override
  String get preDive_templates_strictOrderBadge => 'סדר מחייב';

  @override
  String get preDive_edit_titleNew => 'רשימת בדיקה חדשה לפני צלילה';

  @override
  String get preDive_edit_titleEdit => 'עריכת רשימת בדיקה לפני צלילה';

  @override
  String get preDive_edit_name => 'שם';

  @override
  String get preDive_edit_description => 'תיאור';

  @override
  String get preDive_edit_category => 'קטגוריה';

  @override
  String get preDive_edit_strictOrder => 'סדר מחייב';

  @override
  String get preDive_edit_strictOrderHelp => 'יש להשלים את הפריטים מלמעלה למטה';

  @override
  String get preDive_edit_addItem => 'הוסף פריט';

  @override
  String get preDive_edit_nameRequired => 'הזן שם';

  @override
  String get preDive_item_title => 'כותרת';

  @override
  String get preDive_item_section => 'מקטע';

  @override
  String get preDive_item_notes => 'הערות';

  @override
  String get preDive_item_required => 'חובה';

  @override
  String get preDive_item_type_check => 'תיבת סימון';

  @override
  String get preDive_item_type_value => 'ערך מתועד';

  @override
  String get preDive_item_type_equipmentSet => 'פריטי סט ציוד';

  @override
  String get preDive_item_valueLabel => 'תווית ערך';

  @override
  String get preDive_item_valueUnit => 'יחידה';

  @override
  String get preDive_item_valueMin => 'מינימום (אזהרה)';

  @override
  String get preDive_item_valueMax => 'מקסימום (אזהרה)';

  @override
  String preDive_runner_progress(int done, int total) {
    return '$done מתוך $total';
  }

  @override
  String get preDive_runner_complete => 'סיום';

  @override
  String preDive_runner_completeFlagged(int count) {
    return 'לסיים עם $count פריטים מסומנים בדגל?';
  }

  @override
  String get preDive_runner_abort => 'ביטול רשימת הבדיקה';

  @override
  String get preDive_runner_abortConfirm =>
      'לבטל את רשימת הבדיקה הזו? היא תישמר בהיסטוריה כמבוטלת.';

  @override
  String get preDive_runner_skip => 'דלג';

  @override
  String get preDive_runner_flag => 'סמן בדגל';

  @override
  String get preDive_runner_undo => 'אפס לממתין';

  @override
  String get preDive_runner_serviceOverdue => 'פג תוקף הטיפול';

  @override
  String get preDive_runner_addNote => 'הוסף הערה';

  @override
  String get preDive_runner_enterValue => 'הזן ערך';

  @override
  String preDive_runner_flaggedBadge(int count) {
    return '$count מסומנים בדגל';
  }

  @override
  String get preDive_runner_locked => 'רשימת הבדיקה הזו נעולה';

  @override
  String get preDive_sessions_title => 'רשימות בדיקה לפני צלילה';

  @override
  String get preDive_sessions_empty => 'עדיין אין הרצות של רשימות בדיקה';

  @override
  String get preDive_sessions_resume => 'המשך';

  @override
  String get preDive_sessions_start => 'התחל רשימת בדיקה';

  @override
  String get preDive_sessions_statusCompleted => 'הושלמה';

  @override
  String get preDive_sessions_statusAborted => 'בוטלה';

  @override
  String get preDive_sessions_statusInProgress => 'בתהליך';

  @override
  String get preDive_sessions_linkedDive => 'צלילה מקושרת';

  @override
  String get preDive_link_linkToDive => 'קישור לצלילה';

  @override
  String get preDive_link_unlinkDive => 'בטל קישור צלילה';

  @override
  String get preDive_link_linkChecklist => 'קישור רשימת בדיקה לפני צלילה';

  @override
  String get preDive_link_unlinkChecklist =>
      'ביטול קישור רשימת בדיקה לפני צלילה';

  @override
  String get preDive_link_searchDives => 'חיפוש צלילות';

  @override
  String get preDive_link_noDives => 'אין צלילות לקישור';

  @override
  String preDive_link_noDivesMatch(String query) {
    return 'אין צלילות התואמות ל-\"$query\"';
  }

  @override
  String get preDive_link_noUnlinkedSessions =>
      'אין הרצות רשימת בדיקה ללא קישור';

  @override
  String get preDive_link_linked => 'רשימת הבדיקה קושרה לצלילה זו';

  @override
  String get preDive_link_unlinked => 'קישור רשימת הבדיקה לצלילה זו בוטל';

  @override
  String get preDive_sessions_delete => 'מחיקה';

  @override
  String get preDive_sessions_deleteConfirm =>
      'למחוק את רשומת רשימת הבדיקה הזו?';

  @override
  String get preDive_sessions_filter => 'סינון';

  @override
  String get preDive_sessions_filterTitle => 'סינון רשימות בדיקה שבוצעו';

  @override
  String get preDive_sessions_filterChecklist => 'רשימת בדיקה';

  @override
  String get preDive_sessions_filterStatus => 'סטטוס';

  @override
  String get preDive_sessions_filterFlaggedOnly => 'רק ריצות מסומנות';

  @override
  String get preDive_sessions_filterDateRange => 'טווח תאריכים';

  @override
  String get preDive_sessions_filterAnyDate => 'כל תאריך';

  @override
  String get preDive_sessions_filterClearAll => 'נקה הכול';

  @override
  String get preDive_sessions_filterApply => 'החל';

  @override
  String get preDive_sessions_filterFlaggedChip => 'מסומנות בלבד';

  @override
  String get preDive_sessions_emptyFiltered =>
      'אין רשימות בדיקה התואמות למסננים אלה';

  @override
  String get preDive_sessions_export => 'ייצוא ל-Excel';

  @override
  String get preDive_sessions_exportEmpty => 'אין רשימות בדיקה לייצוא';

  @override
  String preDive_sessions_exportFailed(String error) {
    return 'הייצוא נכשל: $error';
  }

  @override
  String get preDive_start_title => 'התחלת רשימת בדיקה לפני צלילה';

  @override
  String get preDive_start_template => 'רשימת בדיקה';

  @override
  String get preDive_start_equipmentSet => 'סט ציוד';

  @override
  String get preDive_start_noEquipmentSet => 'ללא';

  @override
  String get preDive_start_begin => 'התחל';

  @override
  String get diveLog_listPage_bottomSheet_preDiveChecklist =>
      'התחל רשימת בדיקה לפני צלילה';

  @override
  String get preDive_dashboard_title => 'בדיקה לפני צלילה';

  @override
  String preDive_dashboard_resume(int done, int total) {
    return 'המשך - $done מתוך $total';
  }

  @override
  String get preDive_dashboard_start => 'התחל בדיקה לפני צלילה';

  @override
  String get trips_detail_preDive_action => 'רשימת בדיקה לפני צלילה';

  @override
  String get settings_manage_preDiveChecklists => 'רשימות בדיקה לפני צלילה';

  @override
  String get settings_manage_preDiveChecklists_subtitle =>
      'בדיקות באדי, רשימות הרכבת CCR, אריזת ציוד';

  @override
  String get common_action_back => 'חזרה';

  @override
  String get common_action_cancel => 'ביטול';

  @override
  String get common_action_close => 'סגירה';

  @override
  String get common_action_continue => 'המשך';

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
  String get common_action_share => 'שיתוף';

  @override
  String get common_label_error => 'שגיאה';

  @override
  String get common_label_loading => 'טוען';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get common_error_tryAgain => 'משהו השתבש. יש לנסות שוב.';

  @override
  String get courses_action_add => 'הוסף קורס';

  @override
  String get courses_action_addFromTemplate => 'הוסף מתבנית';

  @override
  String get courses_action_addRequirement => 'הוסף דרישה';

  @override
  String get courses_action_create => 'צור קורס';

  @override
  String get courses_action_deleteRequirement => 'מחק דרישה';

  @override
  String get courses_action_edit => 'ערוך קורס';

  @override
  String get courses_action_editRequirement => 'ערוך דרישה';

  @override
  String get courses_action_exportTrainingLog => 'ייצא יומן אימונים';

  @override
  String get courses_action_linkDive => 'קשר';

  @override
  String get courses_action_markCompleted => 'סמן כהושלם';

  @override
  String get courses_action_unlinkDive => 'בטל קישור צלילה';

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
  String get courses_empty_button => 'הוסף את קורס האימון הראשון שלך';

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
  String courses_requirement_diveProgress(int count, int target) {
    return '$count מתוך $target צלילות';
  }

  @override
  String get courses_requirement_field_name => 'שם';

  @override
  String get courses_requirement_field_targetCount => 'צלילות נדרשות';

  @override
  String get courses_requirement_kind_checklist => 'פריט לסימון';

  @override
  String get courses_requirement_kind_dive => 'דרישת צלילה';

  @override
  String get courses_requirement_suggestions => 'צלילות מוצעות';

  @override
  String get courses_requirements_empty =>
      'עקוב אחר צלילות הרפתקה, דרישות קדם ופריטים לסימון עבור קורס זה.';

  @override
  String courses_requirements_progress(int satisfied, int total) {
    return '$satisfied מתוך $total הושלמו';
  }

  @override
  String get courses_section_details => 'פרטי הקורס';

  @override
  String get courses_section_earnedCertification => 'הסמכה שהושגה';

  @override
  String get courses_section_instructor => 'מדריך';

  @override
  String get courses_section_notes => 'הערות';

  @override
  String get courses_section_requirements => 'דרישות';

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
  String courses_template_addsCount(int count) {
    return 'מוסיף $count דרישות';
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
  String get dashboard_activeCourses_title => 'קורסים בתהליך';

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
  String get dashboard_hero_divesTotalOne => 'צלילה אחת';

  @override
  String dashboard_hero_divesTotalOther(Object count) {
    return '$count צלילות';
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
  String get dashboard_hero_divesLoggedLabel => 'צלילות מתועדות';

  @override
  String get dashboard_hero_hoursUnderwaterLabel => 'שעות מתחת למים';

  @override
  String get dashboard_hero_daysSinceLabel => 'ימים מהצלילה האחרונה';

  @override
  String get dashboard_hero_thisMonthLabel => 'החודש';

  @override
  String get dashboard_hero_thisYearLabel => 'צלילות השנה';

  @override
  String get dashboard_hero_todayLabel => '!היום';

  @override
  String get dashboard_hero_noDivesLabel => 'אין צלילות עדיין';

  @override
  String get dashboard_hero_diverFallbackName => 'צוללן';

  @override
  String get dashboard_hero_statDives => 'צלילות';

  @override
  String get dashboard_hero_statHours => 'שעות';

  @override
  String get dashboard_hero_statSites => 'אתרים';

  @override
  String get dashboard_hero_statCountries => 'מדינות';

  @override
  String dashboard_activityStats_divesInYear(String year) {
    return 'צלילות ב-$year';
  }

  @override
  String get dashboard_semantics_statsBar => 'סיכום סטטיסטיקות צלילה';

  @override
  String get dashboard_gauges_addGear => 'הוסף ציוד';

  @override
  String dashboard_gauges_gearOk(String name) {
    return '$name תקין';
  }

  @override
  String dashboard_gauges_gearDueIn(String name, int days) {
    return '$name דורש טיפול בעוד $days ימים';
  }

  @override
  String dashboard_gauges_gearOverdue(String name) {
    return '$name באיחור טיפול';
  }

  @override
  String get dashboard_gauges_insuranceOk => 'ביטוח תקין';

  @override
  String dashboard_gauges_insuranceExpires(String date) {
    return 'הביטוח פג ב-$date';
  }

  @override
  String get dashboard_gauges_insuranceExpired => 'הביטוח פג תוקף';

  @override
  String get dashboard_gauges_noInsurance => 'אין ביטוח רשום';

  @override
  String get dashboard_gauges_noFlyClear => 'איסור טיסה 0:00';

  @override
  String dashboard_gauges_flightWindow(String hours, String minutes) {
    return 'חלון צלילה $hours:$minutes';
  }

  @override
  String get dashboard_gauges_flightWindowClosed =>
      'אין יותר צלילות לפני הטיסה';

  @override
  String dashboard_gauges_noFlyRemaining(String hours, String minutes) {
    return 'איסור טיסה $hours:$minutes';
  }

  @override
  String dashboard_gauges_lastDiveDays(int days) {
    return 'צלילה אחרונה לפני $days ימים';
  }

  @override
  String get dashboard_gauges_lastDiveToday => 'צללת היום';

  @override
  String get dashboard_gauges_noDivesYet => 'אין צלילות עדיין';

  @override
  String get settings_homeChips_pageTitle => 'מסך הבית';

  @override
  String get settings_homeChips_description =>
      'בחר אילו שבבי מצב יופיעו בראש לשונית הבית.';

  @override
  String get settings_homeChips_sectionTitle => 'שבבי מצב';

  @override
  String get settings_homeCards_sectionTitle => 'כרטיסי דף הבית';

  @override
  String get settings_homeCards_description =>
      'בחר אילו כרטיסים יופיעו בלשונית הבית וגרור כדי לסדר מחדש.';

  @override
  String get settings_homeCards_autoHides => 'מוסתר אוטומטית כשהוא ריק';

  @override
  String get settings_homeCards_resetToDefault => 'איפוס לברירת המחדל';

  @override
  String get settings_homeCards_resetDialog_title => 'לאפס את פריסת דף הבית?';

  @override
  String get settings_homeCards_resetDialog_message =>
      'משחזר את סדר הכרטיסים המוגדר כברירת מחדל ומציג את כולם מחדש.';

  @override
  String get settings_homeCards_resetDialog_cancel => 'ביטול';

  @override
  String get settings_homeCards_resetDialog_confirm => 'איפוס';

  @override
  String get settings_homeCards_card_hero => 'כותרת פתיחה';

  @override
  String get settings_homeCards_card_gaugeStrip => 'שבבי מצב';

  @override
  String get settings_homeCards_card_preDive => 'רשימת בדיקה לפני צלילה';

  @override
  String get settings_homeCards_card_recentDives => 'צלילות אחרונות';

  @override
  String get settings_homeCards_card_quickActions => 'פעולות מהירות';

  @override
  String get settings_homeCards_card_milestones => 'אבני דרך';

  @override
  String get settings_homeCards_card_photoRibbon => 'מדיה אחרונה';

  @override
  String get settings_homeCards_card_onThisDay => 'ביום זה';

  @override
  String get settings_homeCards_card_yearInReview => 'סיכום השנה';

  @override
  String get settings_homeCards_card_activeCourses => 'התקדמות בקורס';

  @override
  String get settings_homeCards_card_recentSitesMap => 'מפת אתרים אחרונים';

  @override
  String get dashboard_allHidden_message => 'כל כרטיסי דף הבית מוסתרים.';

  @override
  String get dashboard_allHidden_customize => 'התאמה אישית של דף הבית';

  @override
  String get settings_homeChips_flightWindow => 'חלון צלילה לפני טיסה';

  @override
  String get settings_homeChips_gear => 'תחזוקת ציוד';

  @override
  String get settings_homeChips_insurance => 'ביטוח';

  @override
  String get settings_homeChips_noFly => 'טיימר איסור טיסה';

  @override
  String get settings_homeChips_lastDive => 'עדכניות צלילה';

  @override
  String get settings_homeChips_certifications => 'תפוגת הסמכות';

  @override
  String get settings_homeChips_trip => 'טיול קרוב';

  @override
  String get settings_homeChips_checklist => 'רשימת תיוג פעילה';

  @override
  String get settings_homeChips_course => 'התקדמות קורס';

  @override
  String get settings_homeChips_uploads => 'העלאות מדיה';

  @override
  String get settings_homeChips_backup => 'גיל הגיבוי';

  @override
  String get settings_homeChips_sync => 'מצב סנכרון';

  @override
  String get settings_homeChips_dataQuality => 'איכות נתונים';

  @override
  String dashboard_gauges_certsExpiring(int count) {
    return '$count הסמכות עומדות לפוג';
  }

  @override
  String dashboard_gauges_tripCountdown(String name, int days) {
    return '$name בעוד $days ימים';
  }

  @override
  String get dashboard_gauges_checklistActive => 'רשימת תיוג בתהליך';

  @override
  String dashboard_gauges_courseProgress(String name, int done, int total) {
    return '$name: $done/$total';
  }

  @override
  String dashboard_gauges_uploadsPending(int count) {
    return '$count העלאות ממתינות';
  }

  @override
  String get dashboard_gauges_backupNone => 'אין גיבוי עדיין';

  @override
  String get dashboard_gauges_backupToday => 'גובה היום';

  @override
  String dashboard_gauges_backupDays(int days) {
    return 'גיבוי לפני $days ימים';
  }

  @override
  String dashboard_gauges_syncPending(int count) {
    return '$count לא מסונכרנים';
  }

  @override
  String get dashboard_gauges_synced => 'מסונכרן';

  @override
  String dashboard_gauges_dataIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count בעיות נתונים',
      one: 'בעיית נתונים אחת',
    );
    return '$_temp0';
  }

  @override
  String get dashboard_gauges_retry => 'הסטטוס אינו זמין - הקש לניסיון חוזר';

  @override
  String get dashboard_urgent_title => 'דורש תשומת לב';

  @override
  String get dashboard_media_title => 'מדיה אחרונה';

  @override
  String get dashboard_recentSites_title => 'אתרים אחרונים';

  @override
  String get dashboard_yearInReview_title => 'השנה';

  @override
  String dashboard_yearInReview_divesVs(int count, int previous) {
    return '$count צלילות (לעומת $previous בשנה שעברה)';
  }

  @override
  String dashboard_yearInReview_hours(String hours) {
    return '$hours שעות מתחת למים';
  }

  @override
  String dashboard_yearInReview_maxDepth(String depth) {
    return 'העמוקה ביותר: $depth';
  }

  @override
  String get dashboard_onThisDay_title => 'ביום הזה';

  @override
  String dashboard_onThisDay_entry(String year, String site) {
    return '$year - $site';
  }

  @override
  String get dashboard_milestones_title => 'אבני דרך';

  @override
  String dashboard_milestones_nextDive(int remaining, int milestone) {
    return 'עוד $remaining צלילות עד מספר $milestone';
  }

  @override
  String dashboard_milestones_certYears(String name, int years, String month) {
    return '$name: $years שנים ב$month';
  }

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
  String get dashboard_recentDives_latestProfileTitle =>
      'פרופיל הצלילה האחרונה';

  @override
  String get dashboard_recentDives_noProfileData =>
      'אין נתוני פרופיל לצלילה זו';

  @override
  String get dashboard_recentDives_profileLoadError =>
      'לא ניתן לטעון את פרופיל הצלילה';

  @override
  String dashboard_recentDives_profileMinutes(int minutes) {
    return '$minutes דק\'';
  }

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
  String get decoCalculator_waterType => 'סוג מים';

  @override
  String get decoCalculator_waterType_standard => 'רגיל';

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
  String get diveCenters_empty_button => 'הוסף את מרכז הצלילה הראשון שלך';

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
  String get diveLog_combine_confirm => 'מיזוג לצלילה אחת';

  @override
  String get diveLog_combine_dataNote =>
      'הפרטים מגיעים מהצלילה המוקדמת ביותר, והשדות הריקים מתמלאים מצלילות מאוחרות יותר. ההערות מתמזגות. כל הבלונים, הציוד, השותפים, התגיות והתצפיות נשמרים.';

  @override
  String get diveLog_combine_error =>
      'לא ניתן היה למזג את הצלילות. שום דבר לא השתנה.';

  @override
  String diveLog_combine_gapLabel(String duration) {
    return 'מרווח פני שטח: $duration';
  }

  @override
  String get diveLog_combine_longSurfaceWarning =>
      'מרווח פני שטח אחד או יותר ארוך מ-30 דקות. ייתכן שאלה צלילות נפרדות ולא צלילה אחת רציפה.';

  @override
  String get diveLog_combine_mixedDivers =>
      'הצלילות שנבחרו שייכות לצוללנים שונים ולא ניתן למזג אותן.';

  @override
  String get diveLog_combine_profilePreview => 'פרופיל ממוזג';

  @override
  String diveLog_combine_previewIntro(int count) {
    return '$count הצלילות האלה ימוזגו לצלילה אחת רציפה. הפערים ביניהן יהפכו לזמן פני שטח.';
  }

  @override
  String diveLog_combine_resultSummary(
    String runtime,
    String maxDepth,
    String bottomTime,
  ) {
    return 'תוצאה: $runtime בסך הכול, עומק מרבי $maxDepth, זמן תחתית $bottomTime';
  }

  @override
  String diveLog_combine_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צלילות',
      one: 'צלילה',
    );
    return 'מוזגו $count $_temp0';
  }

  @override
  String get diveLog_combine_title => 'מיזוג צלילות';

  @override
  String get diveLog_combine_undoError => 'לא ניתן היה לבטל את המיזוג.';

  @override
  String get diveLog_combine_undone => 'המיזוג בוטל';

  @override
  String get diveLog_computerSource_badge_primary => 'ראשי';

  @override
  String get diveLog_consolidate_confirm => 'לשמור כצלילה אחת עם שני המחשבים';

  @override
  String get diveLog_consolidate_error_generic =>
      'לא ניתן היה למזג את הצלילות. שום דבר לא השתנה.';

  @override
  String get diveLog_consolidate_error_notOverlapping =>
      'הצלילות האלה אינן חופפות בזמן, ולכן לא ניתן למזג אותן כצלילה אחת.';

  @override
  String get diveLog_consolidate_error_sameComputer =>
      'הצלילות האלה מגיעות מאותו מחשב צלילה ולא ניתן למזג אותן בדרך זו.';

  @override
  String get diveLog_consolidate_selectPrimary => 'מחשב הצלילה הראשי';

  @override
  String get diveLog_consolidate_snackbar => 'הצלילה מוזגה כמחשב נוסף.';

  @override
  String get diveLog_consolidate_undoError => 'לא ניתן היה לבטל את המיזוג.';

  @override
  String get diveLog_consolidate_undone => 'המיזוג בוטל';

  @override
  String diveLog_mergeDialog_confirmSubtitle(String time) {
    return 'הצלילה בשעה $time תמוזג לתוך צלילה זו.';
  }

  @override
  String get diveLog_mergeDialog_confirmTitle => 'אישור מיזוג';

  @override
  String get diveLog_mergeDialog_empty => 'לא נמצאו צלילות נוספות ביום זה.';

  @override
  String get diveLog_mergeDialog_explanation =>
      'הפרופיל, הבלונים, הלחצים, האירועים, התגיות, השותפים והתצפיות של צלילה זו ימוזגו לתוך צלילה זו כמקור מחשב נוסף. ניתן לבטל פעולה זו באמצעות \'ביטול קישור מחשב\'.';

  @override
  String diveLog_mergeDialog_loadError(String error) {
    return 'שגיאה בטעינת הצלילות: $error';
  }

  @override
  String get diveLog_mergeDialog_merge => 'מיזוג';

  @override
  String get diveLog_mergeDialog_next => 'הבא';

  @override
  String get diveLog_mergeDialog_subtitle =>
      'בחר צלילה מאותו היום למיזוג כמחשב נוסף.';

  @override
  String get diveLog_mergeDialog_title => 'מיזוג עם צלילה אחרת';

  @override
  String get diveLog_mergeDialog_whatThisDoes => 'מה זה עושה';

  @override
  String get diveLog_computerSheet_description =>
      'בחר מאיזה פרופיל מחשב לערוך.';

  @override
  String get diveLog_computerSheet_title => 'בחירת פרופיל התחלתי';

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
  String get diveLog_deco_label_gf99 => 'GF99';

  @override
  String get diveLog_deco_label_surfGf => 'SurfGF';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_time => 'זמן';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String diveLog_deco_gf_chip(Object low, Object high) {
    return 'GF: $low/$high';
  }

  @override
  String diveLog_deco_gf_chipFromSettings(Object low, Object high) {
    return 'GF: $low/$high · ההגדרות שלך';
  }

  @override
  String diveLog_deco_gf_chipRecordedAlgorithm(
    Object algorithm,
    Object low,
    Object high,
  ) {
    return '$algorithm · נותחה עם GF $low/$high';
  }

  @override
  String diveLog_deco_gf_semantics(Object low, Object high) {
    return 'מקדמי מדרון: נמוך $low, גבוה $high';
  }

  @override
  String get diveLog_deco_gf_tooltipFromSettings =>
      'מחשב הצלילה הזה לא תיעד את מקדמי המדרון שלו, ולכן הצלילה מנותחת עם אלה שבהגדרות שלך.';

  @override
  String diveLog_deco_gf_tooltipRecordedAlgorithm(Object algorithm) {
    return 'הצלילה הזו חושבה עם $algorithm, שאינו משתמש במקדמי מדרון. Submersion מנתח אותה עם אלה שבהגדרות שלך.';
  }

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
  String get diveLog_deco_title => 'מצב דקו';

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
  String get diveLog_detail_button_rangeAnalysis => 'סטטיסטיקת טווח';

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
  String get diveLog_detail_label_serialNumber => 'מספר סידורי';

  @override
  String get diveLog_detail_label_firmwareVersion => 'גרסת קושחה';

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
  String get diveLog_detail_section_decoStatus => 'מצב דקו';

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
  String get diveLog_detail_section_sacRateBySegment => 'קצב SAC לפי מקטע';

  @override
  String get diveLog_detail_section_tags => 'תגיות';

  @override
  String get diveLog_detail_section_cylinders => 'בלונים';

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
  String get diveLog_detail_tideCalculated => 'חושב ממודל גאות ושפל';

  @override
  String get diveLog_detail_tooltip_addToFavorites => 'הוספה למועדפים';

  @override
  String get diveLog_detail_tooltip_edit => 'עריכה';

  @override
  String get diveLog_detail_tooltip_editDive => 'עריכת צלילה';

  @override
  String get diveLog_detail_tooltip_previousDive => 'Previous dive';

  @override
  String get diveLog_detail_tooltip_nextDive => 'Next dive';

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
  String get diveLog_diveMode_gaugeDescription =>
      'עומק וזמן בלבד; ללא מעקב גז או דקומפרסיה';

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
  String get diveLog_edit_group_buddies => 'שותפים';

  @override
  String get diveLog_edit_group_conditions => 'תנאים';

  @override
  String get diveLog_edit_group_experience => 'חוויה';

  @override
  String get diveLog_edit_group_gasGear => 'גז וציוד';

  @override
  String get diveLog_edit_group_theDive => 'הצלילה';

  @override
  String get diveLog_edit_group_trip => 'טיול';

  @override
  String get diveLog_edit_headerNew => 'רישום צלילה חדשה';

  @override
  String get diveLog_edit_invite_buddies => 'הוספת שותפים';

  @override
  String get diveLog_edit_invite_conditions =>
      'הוספת תנאים - מים, ראות, מזג אוויר';

  @override
  String get diveLog_edit_invite_experience =>
      'הוספת דירוג, תצפיות, הערות או תגיות';

  @override
  String get diveLog_edit_invite_gasGear =>
      'הוספת גז וציוד - מצב, מיכלים, ציוד, משקולות';

  @override
  String get diveLog_edit_invite_trip => 'הוספת טיול או מרכז צלילה';

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
  String get diveLog_edit_label_diveTypes => 'סוגי צלילה';

  @override
  String get diveLog_edit_label_diveNumber => 'מס\' צלילה';

  @override
  String get diveLog_edit_label_diveName => 'שם';

  @override
  String get diveLog_edit_diveNamePlaceholder => 'שם אופציונלי לצלילה זו';

  @override
  String get diveLog_edit_hint_diveNumber => 'מוקצה אוטומטית אם נותר ריק';

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
  String get diveLog_edit_overline_tanks => 'מיכלים';

  @override
  String get diveLog_edit_profile_draw => 'שרטוט פרופיל';

  @override
  String get diveLog_edit_profile_none => 'לא הוקלט';

  @override
  String diveLog_edit_profile_outliers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'זוהו $count חריגות אפשריות',
      one: 'זוהתה חריגה אפשרית אחת',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_profile_points(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count נקודות',
      one: 'נקודה אחת',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_row_addSite => 'הוספת אתר';

  @override
  String get diveLog_edit_row_diveCenter => 'מרכז צלילה';

  @override
  String get diveLog_edit_row_diveProfile => 'פרופיל צלילה';

  @override
  String get diveLog_edit_row_entry => 'כניסה';

  @override
  String get diveLog_edit_row_exit => 'יציאה';

  @override
  String get diveLog_edit_row_notSet => 'לא הוגדר';

  @override
  String get diveLog_edit_row_site => 'אתר';

  @override
  String get diveLog_edit_row_surfaceInterval => 'זמן פני השטח';

  @override
  String get diveLog_edit_row_trip => 'טיול';

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
  String diveLog_edit_snackbar_avgDepthCalculated(Object depth) {
    return 'עומק ממוצע חושב: $depth';
  }

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'זמן תחתית חושב: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'שגיאה בשמירת צלילה: $error';
  }

  @override
  String diveLog_edit_snackbar_maxDepthCalculated(Object depth) {
    return 'עומק מרבי חושב: $depth';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'אין נתוני פרופיל צלילה זמינים';

  @override
  String diveLog_edit_snackbar_runtimeCalculated(Object minutes) {
    return 'זמן ריצה חושב: $minutes min';
  }

  @override
  String get diveLog_edit_snackbar_unableToCalculateAvgDepth =>
      'לא ניתן לחשב עומק ממוצע מהפרופיל';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'לא ניתן לחשב זמן תחתית מהפרופיל';

  @override
  String get diveLog_edit_snackbar_unableToCalculateMaxDepth =>
      'לא ניתן לחשב עומק מרבי מהפרופיל';

  @override
  String get diveLog_edit_snackbar_unableToCalculateRuntime =>
      'לא ניתן לחשב זמן ריצה מהפרופיל';

  @override
  String diveLog_edit_summary_items(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים',
      one: 'פריט אחד',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_summary_notes => 'הערות';

  @override
  String diveLog_edit_summary_species(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מינים',
      one: 'מין אחד',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_summary_tanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מיכלים',
      one: 'מיכל אחד',
    );
    return '$_temp0';
  }

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
  String get diveLog_edit_tankCard_done => 'סיום';

  @override
  String get diveLog_edit_tankCard_edit => 'עריכה';

  @override
  String get diveLog_edit_tankCard_mix => 'תערובת';

  @override
  String get diveLog_edit_tankCard_pressure => 'לחץ';

  @override
  String diveLog_edit_tankCard_title(int number) {
    return 'מיכל $number';
  }

  @override
  String get diveLog_edit_tankCard_volume => 'נפח';

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
  String diveLog_equipmentSetPicker_itemsSummary(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים',
      one: 'פריט אחד',
    );
    return '$_temp0: $names';
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
  String get diveLog_filterChip_noBuddy => 'ללא שותף';

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
  String get diveLog_filter_clearWeekdays => 'ניקוי ימי השבוע';

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
  String get diveLog_filter_noBuddyOnly => 'ללא שותף';

  @override
  String get diveLog_filter_noTagsYet => 'לא נוצרו תגיות עדיין';

  @override
  String get diveLog_filter_presetAllTime => 'כל הזמן';

  @override
  String get diveLog_filter_presetLast12Months => '12 החודשים האחרונים';

  @override
  String get diveLog_filter_presetLastYear => 'השנה שעברה';

  @override
  String get diveLog_filter_presetThisYear => 'השנה';

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
  String get diveLog_filter_sectionWeekdays => 'ימי השבוע';

  @override
  String get diveLog_filter_showOnlyFavorites => 'הצגת צלילות מועדפות בלבד';

  @override
  String get diveLog_filter_showOnlyNoBuddy => 'הצגת צלילות ללא שותף בלבד';

  @override
  String get diveLog_filter_startDate => 'תאריך התחלה';

  @override
  String get diveLog_filter_title => 'סינון צלילות';

  @override
  String get diveLog_filter_resizeGrip => 'שינוי גודל חלונית הסינון';

  @override
  String get diveLog_filter_tooltip_close => 'סגירת מסנן';

  @override
  String get diveLog_fullscreenProfile_close => 'סגירת מסך מלא';

  @override
  String get diveLog_fullscreenProfile_readoutHint => 'רחפו או גררו על הפרופיל';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'פרופיל צלילה #$number';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'קצב עלייה';

  @override
  String get diveLog_legend_label_ascentRateLine => 'קו קצב עלייה';

  @override
  String get diveLog_legend_label_ceiling => 'תקרה';

  @override
  String get diveLog_legend_label_decoStops => 'Deco stops';

  @override
  String get diveLog_legend_label_cns => 'CNS%';

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
  String get diveLog_legend_label_otu => 'OTU';

  @override
  String get diveLog_legend_label_photoMarkers => 'תמונות';

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
  String get diveLog_legend_label_showGas => 'גזים';

  @override
  String get diveLog_legend_label_surfaceGf => 'GF פני השטח';

  @override
  String get diveLog_legend_label_temp => 'טמפ\'';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_legend_source_dc => 'DC';

  @override
  String get diveLog_legend_source_calc => 'מחושב';

  @override
  String get diveLog_chartSection_overlays => 'שכבות על';

  @override
  String get diveLog_chartSection_markers => 'סמנים';

  @override
  String get diveLog_chartSection_decompression => 'דקומפרסיה';

  @override
  String get diveLog_chartSection_gasAnalysis => 'ניתוח גזים';

  @override
  String get diveLog_chartSection_display => 'תצוגה';

  @override
  String get diveLog_chartSection_other => 'אחר';

  @override
  String get diveLog_chartSection_tankPressures => 'לחצי מיכלים';

  @override
  String get diveLog_chartOption_metricsFollowViewport =>
      'שמירת שכבות העל בתצוגה';

  @override
  String get diveLog_pressure_estimatedSuffix => '(משוער)';

  @override
  String get diveLog_listPage_appBar_diveMap => 'מפת צלילות';

  @override
  String get diveLog_listPage_compactTitle => 'צלילות';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'שגיאה: $error';
  }

  @override
  String get diveLog_listPage_bottomSheet_importFromComputer =>
      'ייבוא ממחשב צלילה';

  @override
  String get diveLog_listPage_bottomSheet_scanPaperLog =>
      'סריקת יומן צלילה מנייר';

  @override
  String get ocrImport_scanPage_processing => 'קורא את העמוד...';

  @override
  String get ocrImport_scanPage_pickPhoto => 'בחירת תמונה';

  @override
  String get ocrImport_scanPage_takePhoto => 'צילום תמונה';

  @override
  String get ocrImport_scanPage_nothingRead =>
      'לא ניתן היה לקרוא הרבה מהעמוד הזה - השדות נותרו ריקים';

  @override
  String get ocrImport_scanPage_engineMissing =>
      'זיהוי טקסט אינו זמין. התקינו את Tesseract כדי לסרוק יומנים מנייר (לדוגמה: sudo apt install tesseract-ocr).';

  @override
  String get ocrImport_editPage_photoAttachFailed =>
      'הצלילה נשמרה, אך צירוף העמוד הסרוק נכשל';

  @override
  String get diveLog_listPage_bottomSheet_logManually => 'רישום צלילה ידנית';

  @override
  String get diveLog_listPage_fab_addDive => 'הוספת צלילה';

  @override
  String get diveLog_listPage_fab_logDive => 'רישום צלילה';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'חיפוש מתקדם';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'מספור צלילות';

  @override
  String get diveLog_listPage_menuMatchSites => 'התאמת צלילות לאתרים';

  @override
  String get diveLog_sighting_decreaseCount => 'הקטנת הכמות';

  @override
  String get diveLog_sighting_increaseCount => 'הגדלת הכמות';

  @override
  String diveLog_speciesPicker_errorLoading(String error) {
    return 'שגיאה בטעינת מינים: $error';
  }

  @override
  String get diveRole_builtin_buddy => 'חבר צוללים';

  @override
  String get diveRole_builtin_diveGuide => 'מוביל צלילה';

  @override
  String get diveRole_builtin_diveMaster => 'דייבמאסטר';

  @override
  String get diveRole_builtin_instructor => 'מדריך';

  @override
  String get diveRole_builtin_rearGuard => 'מאסף';

  @override
  String get diveRole_builtin_safetyDiver => 'צולל בטיחות';

  @override
  String get diveRole_builtin_solo => 'סולו';

  @override
  String get diveRole_builtin_student => 'חניך';

  @override
  String get diveRole_builtin_supportDiver => 'צולל תמיכה';

  @override
  String get diveRoles_addDialog_addButton => 'הוסף';

  @override
  String get diveRoles_addDialog_nameHint => 'לדוגמה: צלם';

  @override
  String get diveRoles_addDialog_nameLabel => 'שם תפקיד צלילה';

  @override
  String get diveRoles_addDialog_nameValidation => 'נא להזין שם';

  @override
  String get diveRoles_addDialog_title => 'הוסף תפקיד צלילה מותאם';

  @override
  String get diveRoles_addTooltip => 'הוסף תפקיד צלילה';

  @override
  String get diveRoles_appBar_title => 'תפקידי צלילה';

  @override
  String get diveRoles_builtInHeader => 'תפקידי צלילה מובנים';

  @override
  String get diveRoles_customHeader => 'תפקידי צלילה מותאמים';

  @override
  String diveRoles_deleteDialog_content(Object name) {
    return 'האם אתה בטוח שברצונך למחוק את \"$name\"?';
  }

  @override
  String get diveRoles_deleteDialog_title => 'למחוק תפקיד צלילה?';

  @override
  String get diveRoles_deleteTooltip => 'מחק תפקיד צלילה';

  @override
  String get diveRoles_renameDialog_title => 'שנה שם תפקיד צלילה';

  @override
  String get diveRoles_renameTooltip => 'שנה שם תפקיד צלילה';

  @override
  String diveRoles_snackbar_added(Object name) {
    return 'תפקיד צלילה נוסף: $name';
  }

  @override
  String diveRoles_snackbar_cannotDelete(Object name) {
    return 'לא ניתן למחוק את \"$name\" - הוא משמש צלילות קיימות';
  }

  @override
  String diveRoles_snackbar_deleted(Object name) {
    return 'תפקיד צלילה נמחק: $name';
  }

  @override
  String diveRoles_snackbar_errorAdding(Object error) {
    return 'שגיאה בהוספת תפקיד צלילה: $error';
  }

  @override
  String get diveSites_edit_depth_heroMax => 'עומק מקס\'';

  @override
  String get diveSites_edit_depth_heroMin => 'עומק מינ\'';

  @override
  String get diveSites_edit_group_accessSafety => 'גישה ובטיחות';

  @override
  String get diveSites_edit_group_diveInfo => 'פרטי צלילה';

  @override
  String get diveSites_edit_group_identity => 'זהות';

  @override
  String get diveSites_edit_group_lifeNotes => 'חיים ימיים והערות';

  @override
  String get diveSites_edit_group_location => 'מיקום';

  @override
  String get diveSites_edit_invite_accessSafety =>
      'הוספת גישה, חניה, עגינה או סכנות';

  @override
  String get diveSites_edit_invite_diveInfo =>
      'הוספת טווח עומק, רמת קושי או דירוג';

  @override
  String get diveSites_edit_invite_lifeNotes =>
      'הוספת חיים ימיים, הערות או שיתוף';

  @override
  String get diveSites_edit_invite_location => 'הוספת מיקום GPS או גובה';

  @override
  String get diveSites_edit_summary_shared => 'משותף';

  @override
  String get forms_addSection_prefix => 'הוספה:';

  @override
  String get forms_cancel => 'ביטול';

  @override
  String get forms_discard_body =>
      'יש לך שינויים שלא נשמרו. אם תצא עכשיו הם יאבדו.';

  @override
  String get forms_discard_discard => 'ביטול שינויים';

  @override
  String get forms_discard_keepEditing => 'המשך עריכה';

  @override
  String get forms_discard_title => 'לבטל את השינויים?';

  @override
  String get forms_save => 'שמירה';

  @override
  String forms_section_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count בעיות',
      one: 'בעיה אחת',
    );
    return '$_temp0';
  }

  @override
  String get settings_manage_setupAssistant => 'אשף ההגדרה';

  @override
  String get settings_manage_setupAssistant_subtitle =>
      'עיון מחדש ביחידות, במראה ובאפשרויות הגיבוי';

  @override
  String get setup_backup_cloudCopy => 'אחסון גיבויים בענן';

  @override
  String get setup_backup_frequency => 'תדירות';

  @override
  String get setup_backup_frequency_daily => 'יומי';

  @override
  String get setup_backup_frequency_monthly => 'חודשי';

  @override
  String get setup_backup_frequency_weekly => 'שבועי';

  @override
  String get setup_backup_scheduleSubtitle => 'גיבוי הנתונים לפי לוח זמנים';

  @override
  String get setup_backup_scheduleToggle => 'גיבויים אוטומטיים';

  @override
  String get setup_backup_subtitle => 'הגנו על הנתונים שלכם מהיום הראשון.';

  @override
  String get setup_backup_title => 'גיבויים וסנכרון';

  @override
  String get setup_common_back => 'חזרה';

  @override
  String get setup_common_next => 'הבא';

  @override
  String get setup_common_skip => 'דילוג';

  @override
  String get setup_existing_folder_subtitle =>
      'הפנו את Submersion לתיקייה שכבר מכילה ספרייה';

  @override
  String get setup_existing_folder_title => 'פתיחת תיקייה קיימת';

  @override
  String get setup_existing_restore_subtitle =>
      'בחרו קובץ גיבוי שיוצא מ-Submersion';

  @override
  String get setup_existing_restore_title => 'שחזור קובץ גיבוי';

  @override
  String get setup_existing_subtitle =>
      'בחרו כיצד לטעון את ספריית Submersion הקיימת שלכם';

  @override
  String get setup_existing_sync_subtitle =>
      'משכו את הספרייה שלכם מ-iCloud, מ-Dropbox או מ-S3';

  @override
  String get setup_existing_sync_title => 'חיבור סנכרון ענן';

  @override
  String get setup_existing_title => 'הביאו את הנתונים שלכם';

  @override
  String get setup_finish_applying => 'מגדיר...';

  @override
  String setup_finish_error(Object error) {
    return 'לא ניתן להשלים את ההגדרה: $error';
  }

  @override
  String get setup_finish_feature_diveComputer => 'הורדת צלילות ממחשב הצלילה';

  @override
  String get setup_finish_feature_gear => 'מעקב אחר ציוד ומועדי טיפולים';

  @override
  String get setup_finish_feature_import =>
      'ייבוא יומנים מקבצים ומאפליקציות אחרות';

  @override
  String get setup_finish_feature_sites => 'מיפוי אתרי הצלילה שלכם';

  @override
  String get setup_finish_feature_statistics =>
      'חקר סטטיסטיקות על הצלילות שלכם';

  @override
  String get setup_finish_start => 'בואו נתחיל';

  @override
  String get setup_finish_subtitle => 'Submersion יכול גם...';

  @override
  String get setup_finish_title => 'הכול מוכן';

  @override
  String get setup_folder_notFound_message =>
      'התיקייה שנבחרה אינה מכילה מסד נתונים של Submersion.';

  @override
  String get setup_folder_notFound_title => 'אין ספרייה בתיקייה זו';

  @override
  String get setup_folder_pick => 'בחירת תיקייה';

  @override
  String get setup_folder_switching => 'פותח ספרייה...';

  @override
  String get setup_folder_title => 'פתיחת תיקייה קיימת';

  @override
  String get setup_profile_nameHint => 'הזן את שמך';

  @override
  String get setup_profile_nameLabel => 'השם שלך';

  @override
  String get setup_profile_nameValidation => 'נא להזין את שמך';

  @override
  String get setup_profile_subtitle =>
      'הזן את שמך כדי להתחיל. תוכל להוסיף פרטים נוספים מאוחר יותר.';

  @override
  String get setup_profile_title => 'צור את הפרופיל שלך';

  @override
  String get setup_restore_inProgress => 'משחזר...';

  @override
  String get setup_restore_pick => 'בחירת קובץ גיבוי';

  @override
  String get setup_restore_title => 'שחזור גיבוי';

  @override
  String get setup_step_backup => 'גיבוי';

  @override
  String get setup_step_finish => 'סיום';

  @override
  String get setup_step_profile => 'פרופיל';

  @override
  String get setup_step_units => 'יחידות';

  @override
  String get setup_syncPull_continue => 'המשך';

  @override
  String get setup_syncPull_incomplete_message =>
      'בחשבון זה קיימת ספריית Submersion שהעלאתה מעולם לא הושלמה. אפשרו למכשיר האחר לסיים את הסנכרון ונסו שוב.';

  @override
  String get setup_syncPull_incomplete_retry => 'בדיקה חוזרת';

  @override
  String get setup_syncPull_incomplete_title => 'העלאת הספרייה לא הושלמה';

  @override
  String get setup_syncPull_locked_message =>
      'הזינו את משפט הסיסמה של ההצפנה כדי לפתוח את הספרייה ולהוריד אותה למכשיר זה.';

  @override
  String get setup_syncPull_locked_title => 'הספרייה הזו מוצפנת';

  @override
  String get setup_syncPull_noLibrary_message =>
      'לא נמצאה ספריית Submersion בחשבון זה. להתחיל מחדש? החיבור יישמר.';

  @override
  String get setup_syncPull_noLibrary_title => 'לא נמצאה ספרייה';

  @override
  String get setup_syncPull_success => 'הספרייה אומצה';

  @override
  String get setup_syncPull_syncing => 'מושך את הספרייה...';

  @override
  String get setup_syncPull_title => 'חיבור ומשיכה';

  @override
  String get setup_sync_changeProvider => 'החלפת ספק';

  @override
  String setup_sync_connectedTo(String provider) {
    return 'מחובר אל $provider';
  }

  @override
  String setup_sync_error(Object error) {
    return 'החיבור נכשל: $error';
  }

  @override
  String get setup_sync_header => 'סנכרון ענן';

  @override
  String get setup_sync_libraryFound_adopt => 'אימוץ הספרייה הקיימת';

  @override
  String get setup_sync_libraryFound_keepFresh => 'התחלה חדשה';

  @override
  String get setup_sync_libraryFound_message =>
      'חשבון זה כבר מכיל ספריית Submersion. לאמץ אותה במקום להתחיל מחדש?';

  @override
  String get setup_sync_libraryFound_title => 'נמצאה ספרייה קיימת';

  @override
  String get setup_sync_manageInSettings => 'ניהול בהגדרות';

  @override
  String get setup_sync_notConnected => 'לא מחובר';

  @override
  String get setup_sync_subtitle => 'סנכרון הנתונים בין מכשירים';

  @override
  String get setup_units_advanced => 'כוונון יחידות';

  @override
  String get setup_units_altitude => 'גובה';

  @override
  String get setup_units_dateFormat => 'תבנית תאריך';

  @override
  String get setup_units_depth => 'עומק';

  @override
  String get setup_units_imperial => 'אימפריאלי';

  @override
  String get setup_units_metric => 'מטרי';

  @override
  String get setup_units_pressure => 'לחץ';

  @override
  String get setup_units_sac => 'קצב SAC';

  @override
  String get setup_units_subtitle =>
      'בחרו כיצד יוצגו המדידות. ניתן לכוונן כל יחידה.';

  @override
  String get setup_units_temperature => 'טמפרטורה';

  @override
  String get setup_units_timeFormat => 'תבנית שעה';

  @override
  String get setup_units_title => 'יחידות';

  @override
  String get setup_units_volume => 'נפח';

  @override
  String get setup_units_weight => 'משקל';

  @override
  String get setup_welcome_existingData_subtitle =>
      'שחזרו גיבוי, חברו סנכרון ענן או פתחו תיקייה קיימת';

  @override
  String get setup_welcome_existingData_title => 'יש לי כבר נתוני Submersion';

  @override
  String get setup_welcome_skipSetup => 'דילוג על ההגדרה';

  @override
  String get setup_welcome_startFresh_subtitle =>
      'צרו פרופיל צולל והגדירו את האפליקציה';

  @override
  String get setup_welcome_startFresh_title => 'הגדרת פרופיל חדש';

  @override
  String get setup_welcome_subtitle => 'רישום וניתוח צלילה מתקדם';

  @override
  String get setup_welcome_title => 'ברוכים הבאים ל-Submersion';

  @override
  String get siteMatchReview_title => 'התאמת אתרים';

  @override
  String siteMatchReview_diveNumber(Object number) {
    return 'צלילה #$number';
  }

  @override
  String get siteMatchReview_empty => 'אין מה להתאים.';

  @override
  String siteMatchReview_summary(int selected, int review, int none) {
    return '$selected נבחרו · $review לבדיקה · $none ללא התאמה';
  }

  @override
  String siteMatchReview_confirm(int count) {
    return 'אישור $count התאמות';
  }

  @override
  String get siteMatchReview_cancel => 'ביטול';

  @override
  String get siteMatchReview_tapToChoose => 'הקש כדי לבחור אתר';

  @override
  String siteMatchReview_awayMeters(int meters) {
    return 'במרחק $meters מ׳';
  }

  @override
  String siteMatchReview_depthTo(int meters) {
    return 'עד $meters מ׳';
  }

  @override
  String siteMatchReview_depthRange(int min, int max) {
    return '$min–$max מ׳';
  }

  @override
  String siteMatchReview_appliedSnack(int dives, int sites) {
    return '$dives צלילות שויכו · $sites אתרים נוספו';
  }

  @override
  String get siteMatchReview_applyError => 'לא ניתן היה להחיל את ההתאמות';

  @override
  String get siteMatchReview_discardTitle => 'לבטל את ההתאמות?';

  @override
  String get siteMatchReview_discardMessage => 'הבחירות שלך לא יישמרו.';

  @override
  String get siteMatchReview_discardConfirm => 'בטל';

  @override
  String get siteMatchReview_keepReviewing => 'המשך בדיקה';

  @override
  String get siteMatchReview_sourceExisting => 'האתר שלך';

  @override
  String get siteMatchReview_sourceBundled => 'מיובא';

  @override
  String get siteMatchReview_noNearbySite => 'אין אתר בקרבת מקום';

  @override
  String importSummary_matchSitesButton(int count) {
    return 'התאמת $count צלילות לאתרים';
  }

  @override
  String get diveLog_listPage_searchFieldLabel => 'חיפוש צלילות...';

  @override
  String diveLog_listPage_searchLimitNotice(int limit) {
    return 'מוצגות $limit ההתאמות הראשונות. חדדו את החיפוש כדי לצמצם את התוצאות.';
  }

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
  String get diveLog_profile_semantics_photoMarker => 'סמן תמונה';

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
  String get diveLog_rangeStats_title => 'סטטיסטיקת טווח';

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
  String get diveLog_search_filter_any => 'הכול';

  @override
  String get diveLog_search_gasTrimix => 'טריימיקס (<21% O₂)';

  @override
  String get diveLog_search_label_deco => 'דקומפרסיה';

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
  String get diveLog_selection_tooltip_combine => 'מזג';

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
  String get diveLog_selection_tooltip_selectDateRange =>
      'בחירה לפי טווח תאריכים';

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
  String diveLog_sitePicker_distanceAway(String distance) {
    return '$distance משם';
  }

  @override
  String get diveLog_sitePicker_sortedByDiveDistance =>
      'ממוין לפי מרחק מהצלילה הזו';

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
  String get diveLog_tank_mndHelper => 'הגדר לחישוב אוטומטי של He%';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String diveLog_tank_modMndInfo(Object mod, Object mnd) {
    return 'MOD: $mod (ppO₂ 1.4) | MND: $mnd';
  }

  @override
  String get diveLog_tank_section_gasMix => 'תערובת גזים';

  @override
  String get diveLog_tank_selectPreset => 'בחר תבנית...';

  @override
  String get diveLog_tank_saveAsPreset => 'שמור כתבנית';

  @override
  String get diveLog_tank_saveAsPreset_needSpecs => 'הזן תחילה נפח ולחץ עבודה';

  @override
  String get diveLog_tank_saveAsPreset_nameTitle => 'שמור תבנית בלון';

  @override
  String get diveLog_tank_saveAsPreset_nameHint => 'לדוגמה AL80 שלי';

  @override
  String diveLog_tank_saveAsPreset_saved(String name) {
    return 'התבנית \"$name\" נשמרה';
  }

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
  String get diveLog_tooltip_avgCalculated => '(ממוצע, מחושב)';

  @override
  String get diveLog_tooltip_ceiling => 'תקרה';

  @override
  String get diveLog_tooltip_decoStop => 'Deco stop';

  @override
  String get diveLog_tooltip_cns => 'CNS';

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
  String get diveLog_tooltip_otu => 'OTU';

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
  String get diveLog_tooltip_sensor => 'חיישן';

  @override
  String get diveLog_legend_label_o2Cells => 'תאי O2';

  @override
  String get diveLog_tooltip_o2CellsTight => 'צמוד';

  @override
  String get diveLog_tooltip_o2CellsDrifting => 'סטייה';

  @override
  String get diveLog_tooltip_o2CellsWide => 'רחב';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'טמפ\'';

  @override
  String get diveLog_tooltip_time => 'זמן';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get diveLog_sources_row_metric => 'מדד';

  @override
  String get diveLog_sources_row_maxDepth => 'עומק מקסימלי';

  @override
  String get diveLog_sources_row_avgDepth => 'עומק ממוצע';

  @override
  String get diveLog_sources_row_duration => 'משך';

  @override
  String get diveLog_sources_row_waterTemp => 'טמפ\' מים';

  @override
  String get diveLog_sources_row_cns => 'CNS';

  @override
  String get diveLog_sources_row_otu => 'OTU';

  @override
  String get diveLog_sources_row_decoAlgorithm => 'אלגוריתם דקומפרסיה';

  @override
  String get diveLog_sources_row_gf => 'GF';

  @override
  String diveLog_sources_minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count דקות',
      one: 'דקה אחת',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_unknownComputer => 'מחשב לא ידוע';

  @override
  String get diveLog_sources_manualEntry => 'הזנה ידנית';

  @override
  String get diveLog_sources_importedFile => 'קובץ מיובא';

  @override
  String get diveLog_sources_editedSuffix => ' (נערך)';

  @override
  String get diveLog_sources_barLabel => 'מקורות';

  @override
  String get diveLog_sources_menu_setPrimary => 'הגדר כראשי';

  @override
  String get diveLog_sources_menu_split => 'פצל לצלילה נפרדת';

  @override
  String get diveLog_sources_overlayTooltip => 'הצג כשכבה בגרף';

  @override
  String get diveLog_sources_splitDialog_title => 'לפצל לצלילה נפרדת?';

  @override
  String get diveLog_sources_splitDialog_body =>
      'הפרופיל, האירועים והמיכלים של מקור זה יועברו לצלילה חדשה. רישום היומן נשאר בצלילה זו.';

  @override
  String get diveLog_sources_splitDialog_confirm => 'פצל';

  @override
  String get diveLog_sources_splitDone => 'הצלילה פוצלה';

  @override
  String get diveLog_sources_splitFailed => 'הפיצול נכשל';

  @override
  String get divePlanner_action_addTank => 'הוסף מיכל';

  @override
  String get divePlanner_action_convertToDive => 'המר לצלילה';

  @override
  String get divePlanner_action_deletePlan => 'מחק תוכנית';

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
  String get divePlanner_error_reserveExceedsTank => 'חורג מלחץ המיכל';

  @override
  String get divePlanner_error_reserveMustBePositive => 'חייב להיות גדול מ-0';

  @override
  String divePlanner_info_reserveDefault(Object unit, Object value) {
    return 'לא הוזן — מניח $value $unit';
  }

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
  String get divePlanner_field_travelGas => 'משמש גם כגז מעבר';

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
  String get divePlanner_label_reserve => 'עתודה:';

  @override
  String get divePlanner_label_runtime => 'זמן ריצה';

  @override
  String get divePlanner_label_sacRate => 'RMV:';

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
  String divePlanner_message_deleteConfirmation(String name) {
    return 'למחוק את \'$name\'?';
  }

  @override
  String get divePlanner_message_planDeleted => 'התוכנית נמחקה';

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
  String get diveSites_detail_location_city => 'עיר';

  @override
  String get diveSites_detail_location_island => 'אי';

  @override
  String get diveSites_detail_location_bodyOfWater => 'מקווה מים';

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
  String get diveSites_edit_access_entryMethod_label => 'שיטת כניסה';

  @override
  String get diveSites_edit_access_exitMethod_label => 'שיטת יציאה';

  @override
  String diveSites_edit_access_entrySuggestionPair(
    int count,
    String entry,
    String exit,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count הצלילות שלך כאן: כניסה $entry, יציאה $exit',
      one: 'הצלילה שלך כאן: כניסה $entry, יציאה $exit',
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
      other: '$count הצלילות שלך כאן: כניסה $entry',
      one: 'הצלילה שלך כאן: כניסה $entry',
    );
    return '$_temp0';
  }

  @override
  String get diveSites_detail_access_entryMethod => 'כניסה';

  @override
  String get diveSites_detail_access_exitMethod => 'יציאה';

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
  String get diveSites_edit_appBar_merge => 'מיזוג';

  @override
  String get diveSites_edit_appBar_mergeSites => 'מיזוג אתרי צלילה';

  @override
  String get diveSites_edit_appBar_newSite => 'אתר חדש';

  @override
  String get diveSites_edit_appBar_save => 'שמור';

  @override
  String get diveSites_edit_button_addSite => 'הוסף אתר';

  @override
  String get diveSites_edit_button_mergeSites => 'מיזוג אתרי צלילה';

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
  String get diveSites_edit_field_city_label => 'עיר';

  @override
  String get diveSites_edit_field_island_label => 'אי';

  @override
  String get diveSites_edit_field_bodyOfWater_label => 'מקווה מים';

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
  String diveSites_similarSite_useHint(Object siteName) {
    return 'דומה לאתר צלילה קיים \"$siteName\". הקש כדי להשתמש.';
  }

  @override
  String diveSites_similarSite_warning(Object siteName) {
    return 'כבר קיים אתר דומה: \"$siteName\"';
  }

  @override
  String get diveSites_edit_gps_gettingLocation => 'מאתר...';

  @override
  String get diveSites_edit_gps_helperText =>
      'בחרו שיטת מיקום או חפשו את הקואורדינטות כדי למלא אוטומטית מדינה, אזור, עיר וגוף מים';

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
  String get diveSites_edit_gps_lookupFromCoordinates =>
      'חיפוש לפי קואורדינטות';

  @override
  String get diveSites_edit_snackbar_lookupNothingFound =>
      'לא נמצאו פרטי מיקום לקואורדינטות אלה';

  @override
  String get diveSites_edit_snackbar_lookupFailed =>
      'חיפוש המיקום נכשל. בדקו את החיבור ונסו שוב.';

  @override
  String get diveSites_edit_lookupReplace_title => 'להחליף את פרטי המיקום?';

  @override
  String get diveSites_edit_lookupReplace_body =>
      'החיפוש מצא ערכים שונים לשדות אלה:';

  @override
  String get diveSites_edit_lookupReplace_replace => 'החלפה';

  @override
  String get diveSites_edit_lookupReplace_keep => 'שמירה';

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
  String diveSites_edit_merge_confirmBody(int count) {
    return 'פעולה זו תמזג $count אתרים לאחד. צלילות, מדיה ומינים צפויים ישולבו תחת האתר הנותר. שאר האתרים יימחקו.';
  }

  @override
  String get diveSites_edit_merge_confirmTitle => 'מיזוג אתרי צלילה';

  @override
  String get diveSites_edit_merge_fieldSourceCycleTooltip =>
      'השתמש בערך מהאתר הנבחר הבא';

  @override
  String diveSites_edit_merge_fieldSourceLabel(
    Object siteName,
    int current,
    int total,
  ) {
    return 'מתוך $siteName ($current/$total)';
  }

  @override
  String get diveSites_edit_merge_fieldSourceMenuTooltip =>
      'בחר ערך מהאתר הנבחר';

  @override
  String get diveSites_edit_merge_marineLifeHelperText =>
      'משולב מכל האתרים שנבחרו';

  @override
  String diveSites_edit_merge_loadingErrorBody(Object error) {
    return 'נכשל בטעינת אתרים: $error';
  }

  @override
  String get diveSites_edit_merge_loadingErrorTitle => 'מיזוג אתרי צלילה';

  @override
  String get diveSites_edit_merge_notEnoughBody => 'אין מספיק אתרים למיזוג.';

  @override
  String get diveSites_edit_merge_notEnoughTitle => 'מיזוג אתרי צלילה';

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
  String get diveSites_edit_section_waterType => 'סוג מים';

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
  String get diveSites_edit_snackbar_sitesMerged => 'אתרי צלילה מוזגו';

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
    return '$min-$max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'עד $max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '$min+';
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
  String get diveSites_list_merge_restored => 'המיזוג בוטל';

  @override
  String diveSites_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'אתרים',
      one: 'אתר',
    );
    return 'מוזגו $count $_temp0';
  }

  @override
  String get diveSites_list_merge_undo => 'בטל';

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
  String get diveSites_list_menu_select => 'בחירת אתרים';

  @override
  String get diveSites_list_menu_fillLocationDetails =>
      'השלמת פרטי מיקום חסרים';

  @override
  String get diveSites_backfill_confirm_title => 'להשלים פרטי מיקום חסרים?';

  @override
  String diveSites_backfill_confirm_body(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ל-$count אתרים עם קואורדינטות חסרים מדינה, אזור, עיר או גוף מים.',
      one: 'לאתר אחד עם קואורדינטות חסרים מדינה, אזור, עיר או גוף מים.',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'כ-$minutes דקות',
      one: 'כדקה',
    );
    return '$_temp0 Submersion יחפש כל אחד מהם ב-OpenStreetMap וימלא רק שדות ריקים. זה נמשך $_temp1.';
  }

  @override
  String get diveSites_backfill_confirm_start => 'התחלה';

  @override
  String get diveSites_backfill_nothingToFill =>
      'לכל האתרים עם קואורדינטות כבר יש פרטי מיקום.';

  @override
  String get diveSites_backfill_progress_title => 'משלים פרטי מיקום';

  @override
  String diveSites_backfill_progress_count(int done, int total) {
    return '$done מתוך $total';
  }

  @override
  String get diveSites_backfill_cancel => 'ביטול';

  @override
  String diveSites_backfill_summary(int updated, int unchanged, int failed) {
    return 'עודכנו $updated, ללא שינוי $unchanged, נכשלו $failed';
  }

  @override
  String get diveSites_backfill_offline =>
      'חיפוש המיקום אינו זמין. בדקו את החיבור ונסו שוב.';

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
  String get diveSites_list_selection_mergeTooltip => 'מיזוג נבחרים';

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
  String get diveSites_map_builtInSites_add => 'הוסף לאתרים שלי';

  @override
  String get diveSites_map_builtInSites_addError =>
      'לא ניתן להוסיף את האתר. נסה שוב.';

  @override
  String get diveSites_map_builtInSites_added => 'נוסף לאתרים שלך';

  @override
  String get diveSites_map_builtInSites_hide => 'הסתר אתרים מובנים';

  @override
  String get diveSites_map_builtInSites_off => 'אתרים מובנים מוסתרים';

  @override
  String get diveSites_map_builtInSites_on => 'אתרים מובנים מוצגים';

  @override
  String get diveSites_map_builtInSites_show => 'הצג אתרים מובנים';

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
  String diveSites_map_semantics_builtInSiteMarker(Object name) {
    return 'אתר צלילה מובנה: $name';
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
  String get diveType_builtin_altitude => 'גובה רב';

  @override
  String get diveType_builtin_boat => 'מסירה';

  @override
  String get diveType_builtin_cave => 'מערה';

  @override
  String get diveType_builtin_cavern => 'מערה פתוחה';

  @override
  String get diveType_builtin_deep => 'עמוקה';

  @override
  String get diveType_builtin_drift => 'סחף';

  @override
  String get diveType_builtin_freedive => 'צלילה חופשית';

  @override
  String get diveType_builtin_ice => 'קרח';

  @override
  String get diveType_builtin_liveaboard => 'שייט צלילה';

  @override
  String get diveType_builtin_night => 'לילה';

  @override
  String get diveType_builtin_recreational => 'ספורטיבי';

  @override
  String get diveType_builtin_shore => 'מהחוף';

  @override
  String get diveType_builtin_technical => 'טכני';

  @override
  String get diveType_builtin_training => 'הכשרה';

  @override
  String get diveType_builtin_wreck => 'ספינה טבועה';

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
    return 'This will permanently delete $name and all associated data including dive logs, dive computers, equipment, certifications, and sites.';
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
  String divers_detail_deleteDialogConfirmHint(String name) {
    return 'Type \"Delete $name\" to confirm';
  }

  @override
  String divers_detail_deleteDialogConfirmText(String name) {
    return 'Delete $name';
  }

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
  String get enum_certificationLevel_diveGuide => 'מדריך צלילה';

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
  String get enum_diveMode_gauge => 'מד עומק';

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
  String get enum_equipmentType_dpv => 'DPV';

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
  String get enum_sortField_dateTaken => 'תאריך הצילום';

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
  String get enum_sortField_fileName => 'שם הקובץ';

  @override
  String get enum_sortField_fileSize => 'גודל הקובץ';

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
  String get equipment_serviceClocks_title => 'שעוני טיפולים';

  @override
  String get equipment_serviceClocks_addClock => 'הוספת שעון';

  @override
  String get equipment_serviceClocks_logService => 'רישום טיפול';

  @override
  String get equipment_serviceClocks_edit => 'עריכת מרווחים';

  @override
  String get equipment_serviceClocks_pause => 'השהיה';

  @override
  String get equipment_serviceClocks_resume => 'המשך';

  @override
  String get equipment_serviceClocks_remove => 'הסרה';

  @override
  String get equipment_serviceClocks_paused => 'מושהה';

  @override
  String get equipment_serviceClocks_empty => 'אין שעוני טיפולים';

  @override
  String get equipment_serviceClocks_unconfigured =>
      'לא הוגדר מרווח - הקישו כדי להגדיר';

  @override
  String equipment_serviceClocks_dueOn(String date) {
    return 'לביצוע עד $date';
  }

  @override
  String equipment_serviceClocks_overdueSince(String date) {
    return 'באיחור מאז $date';
  }

  @override
  String get equipment_serviceClocks_overdue => 'באיחור';

  @override
  String equipment_serviceClocks_divesLeft(int remaining, int total) {
    return 'נותרו $remaining מתוך $total צלילות';
  }

  @override
  String get cylinderConfigs_title => 'תצורות בלונים';

  @override
  String get cylinderConfigs_empty => 'אין עדיין תצורות';

  @override
  String get cylinderConfigs_emptyBody =>
      'שמור פעם אחת מערך מדלל וביילאאוט, ואז החל אותו על כל צלילה.';

  @override
  String get cylinderConfigs_new => 'תצורה חדשה';

  @override
  String get cylinderConfigs_name => 'שם';

  @override
  String get cylinderConfigs_nameRequired => 'הזן שם';

  @override
  String get cylinderConfigs_forUnit => 'עבור היחידה';

  @override
  String get cylinderConfigs_noUnit => 'תוכנית גז כללית';

  @override
  String get cylinderConfigs_gasPlans => 'תוכניות גז';

  @override
  String get cylinderConfigs_addCylinder => 'הוסף בלון';

  @override
  String get cylinderConfigs_role => 'תפקיד';

  @override
  String get cylinderConfigs_startPressure => 'לחץ התחלתי';

  @override
  String get cylinderConfigs_label => 'תווית';

  @override
  String get cylinderConfigs_fromPreset => 'מתבנית';

  @override
  String get cylinderConfigs_deleteTitle => 'למחוק את התצורה?';

  @override
  String get cylinderConfigs_deleteBody =>
      'צלילות שהתצורה כבר הוחלה עליהן לא ישתנו.';

  @override
  String get cylinderConfigs_applyAction => 'החל תצורה';

  @override
  String cylinderConfigs_applyAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count בלונים נוספו',
      one: 'בלון אחד נוסף',
    );
    return '$_temp0';
  }

  @override
  String cylinderConfigs_applyKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count נשמרו',
      one: 'אחד נשמר',
    );
    return '$_temp0';
  }

  @override
  String get cylinderConfigs_applyNothingToDo => 'הצלילה כבר תואמת לתצורה';

  @override
  String get cylinderConfigs_sectionTitle => 'תצורות';

  @override
  String get equipment_serviceClocks_hoursSource => 'מחושב מזמן הצלילה המתועד';

  @override
  String equipment_serviceClocks_hoursLeft(String remaining, String total) {
    return 'נותרו $remaining מתוך $total שעות';
  }

  @override
  String get equipment_serviceClocks_manageKinds => 'ניהול סוגי טיפול';

  @override
  String get equipment_serviceClocks_appliesToClock => 'חל על שעון';

  @override
  String get equipment_serviceClocks_noClockOption => 'לא משויך לשעון';

  @override
  String get equipment_scheduleDialog_title => 'עריכת שעון';

  @override
  String get equipment_scheduleDialog_intervalDays => 'מרווח (ימים)';

  @override
  String get equipment_scheduleDialog_intervalDives => 'מרווח (צלילות)';

  @override
  String get equipment_scheduleDialog_intervalHours => 'מרווח (שעות)';

  @override
  String equipment_scheduleDialog_inheritHint(String value) {
    return 'ברירת מחדל: $value';
  }

  @override
  String get equipment_scheduleDialog_anchorDate => 'תאריך בסיס';

  @override
  String get equipment_scheduleDialog_anchorHint =>
      'בשימוש כאשר עדיין אין רשומת טיפול מסוג זה';

  @override
  String get equipment_scheduleDialog_clearAnchor => 'ניקוי תאריך הבסיס';

  @override
  String get equipment_scheduleDialog_save => 'שמירה';

  @override
  String get equipment_scheduleDialog_cancel => 'ביטול';

  @override
  String get equipment_serviceKinds_title => 'סוגי טיפול';

  @override
  String get equipment_serviceKinds_builtIn => 'מובנה';

  @override
  String get equipment_serviceKinds_custom => 'מותאם אישית';

  @override
  String get equipment_serviceKinds_add => 'הוספת סוג טיפול';

  @override
  String get equipment_serviceKinds_editTitle => 'עריכת סוג טיפול';

  @override
  String get equipment_serviceKinds_nameLabel => 'שם';

  @override
  String get equipment_serviceKinds_nameRequired => 'נדרש שם';

  @override
  String get equipment_serviceKinds_appliesTo => 'חל על';

  @override
  String get equipment_serviceKinds_autoAttach => 'צירוף אוטומטי לציוד חדש';

  @override
  String get equipment_serviceKinds_deleteConfirmTitle =>
      'למחוק את סוג הטיפול?';

  @override
  String get equipment_serviceKinds_deleteConfirmBody =>
      'שעונים המשתמשים בסוג טיפול זה יוסרו.';

  @override
  String get equipment_serviceKinds_delete => 'מחיקה';

  @override
  String get equipment_serviceKinds_cancel => 'ביטול';

  @override
  String get equipment_serviceKinds_save => 'שמירה';

  @override
  String get equipment_serviceKinds_emptyCustom =>
      'אין עדיין סוגי טיפול מותאמים אישית';

  @override
  String equipment_serviceKinds_everyDays(int days) {
    return 'כל $days ימים';
  }

  @override
  String equipment_serviceKinds_everyDives(int dives) {
    return 'כל $dives צלילות';
  }

  @override
  String equipment_serviceKinds_everyHours(String hours) {
    return 'כל $hours שעות';
  }

  @override
  String get dashboard_serviceDue_title => 'טיפול נדרש';

  @override
  String dashboard_serviceDue_more(int count) {
    return '+$count נוספים';
  }

  @override
  String dashboard_alerts_clockDue(String name, String kind) {
    return '$name: $kind נדרש';
  }

  @override
  String dashboard_alerts_clockOverdue(String name, String kind) {
    return '$name: $kind באיחור';
  }

  @override
  String equipment_list_worstClock(String kind) {
    return '$kind באיחור';
  }

  @override
  String trips_serviceAlert_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטי ציוד זקוקים לטיפול לפני הטיול הזה',
      many: '$count פריטי ציוד זקוקים לטיפול לפני הטיול הזה',
      two: 'שני פריטי ציוד זקוקים לטיפול לפני הטיול הזה',
      one: 'פריט ציוד אחד זקוק לטיפול לפני הטיול הזה',
    );
    return '$_temp0';
  }

  @override
  String trips_serviceAlert_dueBefore(String kind, String date) {
    return '$kind לביצוע עד $date';
  }

  @override
  String trips_serviceAlert_overdue(String kind) {
    return '$kind באיחור';
  }

  @override
  String get settings_notifications_tripLeadTitle =>
      'זמן התראה לטיפול לפני טיול';

  @override
  String settings_notifications_tripLeadDays(int days) {
    return '$days ימים לפני טיול';
  }

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
  String get equipment_detail_thicknessLabel => 'עובי';

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
  String get equipment_edit_purchasePriceValidation => 'הזן סכום חוקי';

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
  String get equipment_edit_thicknessDesignationHint => 'למשל, 5, 5/4, 7/5/3';

  @override
  String get equipment_edit_thicknessHint => 'למשל, 5 מ\"מ, 7 מ\"מ';

  @override
  String get equipment_edit_thicknessLabel => 'עובי';

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
  String get equipment_fab_addSet => 'הוסף ערכה';

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
  String equipment_list_tile_serviceInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'טיפול בעוד $days ימים',
      one: 'טיפול בעוד יום אחד',
    );
    return '$_temp0';
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
  String get equipment_serviceDialog_currencyLabel => 'מטבע';

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
  String get equipment_serviceDialog_serviceTypeHelper =>
      'רישום מאפס את השעון של סוג טיפול זה';

  @override
  String get equipment_serviceDialog_serviceTypeRequired => 'בחר סוג טיפול';

  @override
  String get equipment_serviceDialog_serviceTypeNotSet => 'לא הוגדר';

  @override
  String get equipment_serviceDialog_categoryHelper => 'משמשת לסינון ולייצוא';

  @override
  String get equipment_serviceDialog_manageServiceTypes => 'ניהול סוגי טיפול';

  @override
  String get equipment_serviceDialog_categoryLabel => 'קטגוריה';

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
  String get equipment_serviceCategory_annual => 'טיפול שנתי';

  @override
  String get equipment_serviceCategory_repair => 'תיקון';

  @override
  String get equipment_serviceCategory_inspection => 'בדיקה';

  @override
  String get equipment_serviceCategory_overhaul => 'שיפוץ כללי';

  @override
  String get equipment_serviceCategory_replacement => 'החלפת חלקים';

  @override
  String get equipment_serviceCategory_cleaning => 'ניקוי';

  @override
  String get equipment_serviceCategory_calibration => 'כיול';

  @override
  String get equipment_serviceCategory_warranty => 'שירות אחריות';

  @override
  String get equipment_serviceCategory_recall => 'ריקול/בטיחות';

  @override
  String get equipment_serviceCategory_other => 'אחר';

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
  String equipment_service_nextDueLabel(String date) {
    return 'מועד הבא $date';
  }

  @override
  String get equipment_service_filterTaskAll => 'כל המשימות';

  @override
  String get equipment_service_filterTypeAll => 'כל הסוגים';

  @override
  String get equipment_service_filterYearAll => 'כל השנים';

  @override
  String get equipment_service_filterUntagged => 'לא משויך למחזור';

  @override
  String get equipment_service_filterClear => 'ניקוי הסינון';

  @override
  String get equipment_service_filterNoMatches => 'אין תחזוקה התואמת לסינון זה';

  @override
  String equipment_service_filterMatchCount(int count, int total) {
    return 'מוצגים $count מתוך $total';
  }

  @override
  String get equipment_serviceKinds_defaultCategoryLabel =>
      'קטגוריית ברירת מחדל';

  @override
  String get equipment_serviceKinds_defaultCategoryNone => 'ללא ברירת מחדל';

  @override
  String get equipment_serviceKinds_defaultCostLabel => 'מחיר ברירת מחדל';

  @override
  String get equipment_serviceKinds_defaultCostHint =>
      'השאירו ריק ללא ברירת מחדל';

  @override
  String get equipment_scheduleDialog_defaultCostLabel =>
      'מחיר ברירת מחדל לפריט זה';

  @override
  String get equipment_serviceKinds_defaultCurrencyLabel => 'מטבע';

  @override
  String get equipment_service_exportMenuItem => 'ייצוא יומן התחזוקה';

  @override
  String get transfer_export_maintenanceTitle => 'יומן תחזוקה';

  @override
  String get transfer_export_maintenanceSubtitle =>
      'היסטוריית הטיפולים של כל הציוד כגיליון אלקטרוני';

  @override
  String get settings_export_progress_maintenance => 'מייצא את יומן התחזוקה...';

  @override
  String get settings_export_success_maintenance => 'יומן התחזוקה יוצא';

  @override
  String get settings_export_saved_maintenance => 'יומן התחזוקה נשמר';

  @override
  String get equipment_serviceKinds_defaultCurrencyInherit =>
      'שימוש במטבע ברירת המחדל';

  @override
  String get equipment_scheduleDialog_defaultCurrencyLabel => 'מטבע לפריט זה';

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
  String get equipment_tab_equipment => 'ציוד';

  @override
  String get equipment_tab_sets => 'ערכות';

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
  String get gasCalculators_mnd_depthInput => 'עומק';

  @override
  String get gasCalculators_mnd_endAtDepthTitle => 'END בעומק';

  @override
  String get gasCalculators_mnd_endLimit => 'מגבלת END';

  @override
  String get gasCalculators_mnd_hePercent => 'He %';

  @override
  String get gasCalculators_mnd_infoContent =>
      'עומק נרקוטי מרבי (MND) הוא העומק הגדול ביותר שאליו אפשר לצלול לפני שהנרקוזה חורגת ממגבלת ה-END שלך. עומק נרקוטי שווה ערך (END) מציין את ההשפעה הנרקוטית של הגז שלך בעומק נתון.\n\nכאשר \'O2 נרקוטי\' מופעל, גם חמצן וגם חנקן תורמים לנרקוזה (שמרני יותר). כאשר מושבת, רק חנקן נחשב נרקוטי.';

  @override
  String get gasCalculators_mnd_infoTitle => 'אודות MND/END';

  @override
  String get gasCalculators_mnd_unlimited => 'ללא הגבלה';

  @override
  String get gasCalculators_mnd_inputParameters => 'תערובת גז והגדרות נרקוזה';

  @override
  String get gasCalculators_mnd_o2Narcotic => 'O2 נרקוטי';

  @override
  String get gasCalculators_mnd_o2Percent => 'O2 %';

  @override
  String get gasCalculators_mnd_resultTitle => 'עומק נרקוטי מרבי';

  @override
  String get gasCalculators_ppO2Limit => 'מגבלת ppO₂';

  @override
  String get gasCalculators_resetAll => 'אפס את כל המחשבונים';

  @override
  String get gasCalculators_sacRate => 'RMV';

  @override
  String get gasCalculators_tab_bestMix => 'תערובת מיטבית';

  @override
  String get gasCalculators_tab_consumption => 'צריכה';

  @override
  String get gasCalculators_tab_mnd => 'MND/END';

  @override
  String get gasCalculators_tab_blender => 'מערבל טרימיקס';

  @override
  String get gasCalculators_blender_cylinder => 'בלון';

  @override
  String get gasCalculators_blender_startCylinder => 'בבלון';

  @override
  String get gasCalculators_blender_targetFill => 'מילוי יעד';

  @override
  String get gasCalculators_blender_fillGases => 'גזי מילוי';

  @override
  String get gasCalculators_blender_pressure => 'לחץ';

  @override
  String get gasCalculators_blender_o2 => 'O₂';

  @override
  String get gasCalculators_blender_he => 'He';

  @override
  String get gasCalculators_blender_air => 'אוויר';

  @override
  String get gasCalculators_blender_helium => 'הליום';

  @override
  String get gasCalculators_blender_procedure => 'סדר המילוי';

  @override
  String get gasCalculators_blender_amounts => 'גז להוספה';

  @override
  String gasCalculators_blender_stepStart(String pressure, String gas) {
    return 'התחל עם $pressure $gas';
  }

  @override
  String gasCalculators_blender_stepFill(
    String gas,
    String pressure,
    String mix,
  ) {
    return 'מלא $gas עד $pressure → $mix';
  }

  @override
  String get gasCalculators_blender_error_targetPressure =>
      'לחץ היעד חייב להיות גבוה מלחץ ההתחלה.';

  @override
  String get gasCalculators_blender_error_invalidMix =>
      'O₂ + He של תערובת לא יכול לעלות על 100%.';

  @override
  String get gasCalculators_blender_error_identicalGases =>
      'שני גזי המילוי זהים — אין מה לערבב.';

  @override
  String get gasCalculators_blender_error_linearlyDependent =>
      'גזי המילוי האלה לא יכולים לייצר את תערובת היעד — יעד טרימיקס דורש מקור הליום.';

  @override
  String get gasCalculators_blender_error_negativeAmount =>
      'לא ניתן להשיג את התערובת הזו עם הגזים האלה — יידרש להוציא גז.';

  @override
  String gasCalculators_blender_error_drainTo(String pressure) {
    return 'יש יותר מדי גז בבלון לתערובת הזו. רוקנו תחילה עד $pressure ואז מלאו.';
  }

  @override
  String get gasCalculators_blender_error_drainEmpty =>
      'הגז שבבלון אינו מתאים לתערובת הזו. רוקנו אותו לגמרי ואז מלאו.';

  @override
  String get gasCalculators_blender_error_cannotRemoveHelium =>
      'הבלון מכיל הליום והתערובת המבוקשת לא. מילוי נוסף מדלל את ההליום אך אינו מסלק אותו, ולכן יש לרוקן את הבלון תחילה.';

  @override
  String get gasCalculators_blender_error_insufficientGases =>
      'יעד ללא הליום דורש שני גזי מילוי ללא הליום עם תכולת O₂ שונה.';

  @override
  String get gasCalculators_blender_error_targetNotReached =>
      'גזי המילוי האלה לא מגיעים בדיוק לתערובת היעד. בדקו את הגזים ואת סדרם.';

  @override
  String get gasCalculators_blender_error_implausibleStartMix =>
      'הבלון תחת לחץ אך ללא חמצן וללא הליום, כלומר חנקן טהור. בדוק את התערובת שכבר נמצאת בבלון.';

  @override
  String get gasCalculators_blender_about => 'על הערבוב';

  @override
  String get gasCalculators_blender_aboutBody =>
      'ערבוב בלחצים חלקיים לתערובת היעד. הוסף כל גז מילוי לפי הסדר עד ללחץ המוצג, ואז תן לבלון להתייצב. גזי המילוי וסדרם ניתנים להגדרה, כך שקביעת הגז האחרון ל-32/0 משלימה את המילוי ב-EAN32 במקום באוויר. תמיד נתח את התערובת הסופית לפני צלילה איתה.';

  @override
  String get gasCalculators_blender_conditions => 'תנאי הערבוב';

  @override
  String get gasCalculators_blender_fillTemp => 'טמפרטורת המילוי';

  @override
  String get gasCalculators_blender_fillTempHelp =>
      'טמפרטורת הבלון בזמן המילוי. כל לחץ בסדר המילוי הוא הקריאה במד הלחץ בטמפרטורה הזו.';

  @override
  String get gasCalculators_blender_settledTemp => 'טמפרטורה לאחר התייצבות';

  @override
  String get gasCalculators_blender_settledTempHelp =>
      'הטמפרטורה שאליה הבלון מגיע בסוף. לחץ היעד הוא מה שהוא מראה כשהוא שם.';

  @override
  String get gasCalculators_blender_gasModel => 'מודל הגז';

  @override
  String get gasCalculators_blender_modelIdeal => 'גז אידיאלי';

  @override
  String get gasCalculators_blender_modelVanDerWaals => 'ואן דר ואלס';

  @override
  String get gasCalculators_blender_modelZFactor => 'גז ממשי (מקדם Z)';

  @override
  String get gasCalculators_blender_modelRecommended => 'מומלץ';

  @override
  String get gasCalculators_blender_modelHelp =>
      'גז ממשי (מקדם Z) הוא המדויק ביותר בלחצי בלון. גז אידיאלי תואם את רוב טבלאות הערבוב המפורסמות. ואן דר ואלס מוצע להשוואה מול תוכנות ערבוב אחרות וסוטה באחוזים בודדים בלחץ המילוי.';

  @override
  String gasCalculators_blender_stepAdd(String gas) {
    return 'הוסף $gas';
  }

  @override
  String get gasCalculators_blender_stepStartLabel => 'התחלה';

  @override
  String gasCalculators_blender_settlesTo(String pressure, String temperature) {
    return 'מתייצב על $pressure ב-$temperature';
  }

  @override
  String get gasCalculators_blender_templates => 'תבניות';

  @override
  String get gasCalculators_blender_templatesTitle => 'תבניות תערובת יעד';

  @override
  String get gasCalculators_blender_saveTemplate => 'שמור את התערובת הנוכחית';

  @override
  String get gasCalculators_blender_manageTemplates => 'ניהול תבניות';

  @override
  String gasCalculators_blender_templateSaved(String mix) {
    return '$mix נשמרה';
  }

  @override
  String get gasCalculators_blender_templateExists => 'התערובת הזו כבר שמורה.';

  @override
  String get gasCalculators_blender_templateInvalid =>
      '‏O₂ + He לא יכולים לעלות על 100%.';

  @override
  String get gasCalculators_blender_templateNeedsNumbers =>
      'הזן גם O₂ וגם He כמספרים.';

  @override
  String gasCalculators_blender_templateLimit(int count) {
    return 'אפשר לשמור עד $count תבניות.';
  }

  @override
  String get gasCalculators_blender_templateNone =>
      'אין עדיין תבניות. שמור תערובת יעד כדי להשתמש בה כאן שוב.';

  @override
  String gasCalculators_blender_templateDelete(String mix) {
    return 'מחק $mix';
  }

  @override
  String get gasCalculators_blender_templateAdd => 'הוסף תבנית';

  @override
  String get gasCalculators_blender_billing => 'עלות';

  @override
  String get gasCalculators_blender_cylinderVolume => 'נפח המים של הבלון';

  @override
  String get gasCalculators_blender_cylinderPresets => 'הגדרות מוכנות';

  @override
  String gasCalculators_blender_unitPrice(String unit) {
    return 'מחיר ל-100 $unit';
  }

  @override
  String get gasCalculators_blender_currency => 'מטבע';

  @override
  String get gasCalculators_blender_costTotal => 'סה\"כ';

  @override
  String get gasCalculators_blender_costBasis =>
      'החיוב הוא לפי הלחץ שסופק (נפח המים של הבלון × בר שהוסף), כפי שתחנת המילוי מודדת.';

  @override
  String get gasCalculators_blender_costMissingPrice =>
      'הזן מחיר לכל גז כדי לראות את הסכום הכולל.';

  @override
  String get gasCalculators_blender_saveFill => 'שמור את המילוי הזה';

  @override
  String get gasCalculators_blender_billed => 'חיוב';

  @override
  String get gasCalculators_blender_billedNone =>
      'עדיין אין חיובים. סיים מילוי ושמור אותו כאן.';

  @override
  String get gasCalculators_blender_billedTo => 'החיוב על שם';

  @override
  String get gasCalculators_blender_addManualLine => 'הוסף שורה';

  @override
  String get gasCalculators_blender_lineDescription => 'תיאור';

  @override
  String get gasCalculators_blender_lineAmount => 'סכום';

  @override
  String get gasCalculators_blender_clearBilled => 'נקה';

  @override
  String get gasCalculators_blender_clearBilledTitle => 'לנקות את החיוב?';

  @override
  String gasCalculators_blender_clearBilledBody(int count) {
    return 'פעולה זו תמחק את כל $count המילויים השמורים.';
  }

  @override
  String gasCalculators_blender_editLine(String label) {
    return 'עריכת $label';
  }

  @override
  String gasCalculators_blender_deleteLine(String label) {
    return 'מחיקת $label';
  }

  @override
  String gasCalculators_blender_fillAdded(String mix) {
    return '$mix נוסף לחיוב';
  }

  @override
  String get gasCalculators_blender_billedIncomplete =>
      'לשורה אחת או יותר אין מחיר, ולכן הסכום חלקי.';

  @override
  String get gasCalculators_blender_billedTotal => 'סה\"כ';

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
  String get media_diveMediaSection_cancelSelectionButton => 'ביטול';

  @override
  String get media_diveMediaSection_emptyState => 'עדיין אין תמונות';

  @override
  String get media_diveMediaSection_errorLoading => 'שגיאה בטעינת מדיה';

  @override
  String get media_diveMediaSection_selectAllButton => 'בחר הכל';

  @override
  String media_diveMediaSection_selectedCount(int count) {
    return '$count נבחרו';
  }

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'הצג תמונה. לחיצה ארוכה לביטול קישור';

  @override
  String get media_diveMediaSection_title => 'תמונות וסרטונים';

  @override
  String get media_diveMediaSection_replaceButton => 'קישור מחדש';

  @override
  String get media_diveMediaSection_replaceEditedContent =>
      'תוכן הקובץ שונה מהמקור. קישור מחדש יעלה אותו שוב למאגר המדיה שלך.';

  @override
  String get media_diveMediaSection_replaceEditedTitle => 'תוכן הקובץ שונה';

  @override
  String get media_diveMediaSection_unlinkButton => 'בטל קישור';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'ביטול הקישור נכשל: $error';
  }

  @override
  String media_diveMediaSection_unlinkSelectedButton(int count) {
    return 'בטל קישור $count';
  }

  @override
  String media_diveMediaSection_unlinkSelectedContent(int count) {
    return 'מסיר $count פריטי מדיה מהספרייה שלך, יחד עם העותקים בענן והתמונות הממוזערות. פריטים שאתר צלילה עדיין משתמש בהם יישמרו. קובצי המקור שלך לא ייפגעו.';
  }

  @override
  String media_diveMediaSection_unlinkSelectedSuccess(int count) {
    return 'בוטל קישור של $count פריטים';
  }

  @override
  String media_diveMediaSection_unlinkSelectedTitle(int count) {
    return 'לבטל קישור של $count פריטים?';
  }

  @override
  String media_library_unlinkConfirmTitle(int count) {
    return 'לבטל קישור של $count פריטים?';
  }

  @override
  String media_siteMediaSection_unlinkError(Object error) {
    return 'ביטול הקישור נכשל: $error';
  }

  @override
  String get media_library_unlinkConfirmBody =>
      'הם יוסרו מהספרייה שלך, יחד עם העותקים בענן והתמונות הממוזערות. קובצי המקור שלך לא ייפגעו. לא ניתן לבטל זאת.';

  @override
  String media_library_unlinkMetadataNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'ל-$count מהם יש כיתוב או סימון מועדף השמורים ב-Submersion, והפרטים האלה יאבדו.',
      one:
          'לאחד מהם יש כיתוב או סימון מועדף השמורים ב-Submersion, והפרטים האלה יאבדו.',
    );
    return '$_temp0';
  }

  @override
  String get media_siteMediaSection_title => 'מדיה של האתר';

  @override
  String get media_siteMediaSection_addPhotos => 'הוספת תמונות או סרטונים';

  @override
  String get media_siteMediaSection_addDocument => 'הוספת מסמך';

  @override
  String get media_siteMediaSection_emptyState =>
      'אין מפות, תמונות או מסמכים המצורפים לאתר זה';

  @override
  String media_siteMediaSection_divePhotosGroup(int count) {
    return 'תמונות מצלילות כאן ($count)';
  }

  @override
  String get media_siteMediaSection_divePhotoLabel => 'תמונת צלילה';

  @override
  String media_siteMediaSection_unlinkSelectedTitle(int count) {
    return 'לבטל קישור של $count פריטים?';
  }

  @override
  String media_siteMediaSection_unlinkSelectedContent(int count) {
    return 'מסיר $count פריטים מהספרייה שלך, יחד עם עותקי הענן והתמונות הממוזערות. מדיה שצלילה עדיין משתמשת בה נשמרת. הקבצים המקוריים שלך אינם מושפעים.';
  }

  @override
  String media_siteMediaSection_unlinkSelectedSuccess(int count) {
    return 'בוטל קישור של $count פריטים';
  }

  @override
  String get media_documentViewer_title => 'מסמך';

  @override
  String get media_documentViewer_unavailable => 'מסמך זה אינו זמין במכשיר זה';

  @override
  String get media_documentViewer_availableOnOriginDevice =>
      'הוא זמין במכשיר שממנו נוסף, או דרך אחסון מדיה מוגדר.';

  @override
  String media_documentViewer_attached(int count) {
    return 'צורפו $count מסמכים';
  }

  @override
  String get media_diveScan_scanTooltip => 'סרוק גלריה לחיפוש תמונות';

  @override
  String get media_diveScan_noPhotosFound =>
      'לא נמצאו תמונות חדשות ליד צלילה זו';

  @override
  String get media_diveScan_accessDenied =>
      'נדרשת גישה לספריית התמונות כדי לסרוק תמונות';

  @override
  String media_diveScan_foundPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תמונות',
      one: 'תמונה אחת',
    );
    return 'נמצאו $_temp0 ליד צלילה זו. לקשר?';
  }

  @override
  String get media_diveScan_foundTitle => 'נמצאו תמונות';

  @override
  String media_diveScan_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'תמונות',
      one: 'תמונה',
    );
    return 'קשר $_temp0';
  }

  @override
  String get media_diveScan_cancelButton => 'ביטול';

  @override
  String media_diveScan_error(String error) {
    return 'שגיאה בסריקת הגלריה: $error';
  }

  @override
  String get media_gpsBanner_addToSiteButton => 'הוסף לאתר';

  @override
  String media_gpsBanner_coordinates(Object coordinates) {
    return 'קואורדינטות: $coordinates';
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
  String media_import_allAlreadyLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תמונות כבר מקושרות לצלילה זו',
      one: 'תמונה אחת כבר מקושרת לצלילה זו',
    );
    return '$_temp0';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return 'יובאו $imported, נכשלו $failed';
  }

  @override
  String media_import_importedAndSkipped(int imported, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      imported,
      locale: localeName,
      other: 'יובאו $imported תמונות',
      one: 'יובאה תמונה אחת',
    );
    return '$_temp0 ($skipped כבר מקושרות)';
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
  String get media_lightroom_openInLightroom => 'פתיחה ב-Lightroom';

  @override
  String get media_lightroom_suggestion_accept => 'הוספה לצלילה זו';

  @override
  String get media_lightroom_suggestion_dismiss => 'התעלמות';

  @override
  String get media_lightroom_suggestions_title => 'הצעות מ-Lightroom';

  @override
  String get media_miniProfile_headerLabel => 'פרופיל צלילה';

  @override
  String get media_miniProfile_semanticLabel => 'תרשים מיני של פרופיל צלילה';

  @override
  String get media_photoPicker_appBarTitle => 'בחר תמונות';

  @override
  String get media_photoPicker_tab_gallery => 'גלריה';

  @override
  String get media_photoPicker_tab_files => 'קבצים';

  @override
  String get media_photoPicker_tab_url => 'URL';

  @override
  String get media_photoPicker_clearSelectionButton => 'נקה';

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
  String get media_photoPicker_grantAccessButton => 'המשך';

  @override
  String get media_photoPicker_openSettingsButton => 'פתח הגדרות';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'הגישה לספריית התמונות נדחתה. נא לאפשר אותה בהגדרות כדי להוסיף תמונות צלילה.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion זקוקה לגישה לספריית התמונות שלך כדי להוסיף תמונות צלילה.';

  @override
  String get media_photoPicker_permissionTitle => 'תמונות צלילה';

  @override
  String get media_photoPicker_selectAllButton => 'בחר הכל';

  @override
  String media_photoPicker_selectedCount(int count) {
    return '$count נבחרו';
  }

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
  String get media_photoPicker_files_pickFilesButton => 'בחירת קבצים…';

  @override
  String get media_photoPicker_files_pickFolderButton => 'בחירת תיקייה…';

  @override
  String get media_photoPicker_files_autoMatchLabel =>
      'התאמה אוטומטית של תמונות וסרטונים לצלילות לפי תאריך';

  @override
  String get media_photoPicker_files_emptyHint =>
      'בחר קבצים או תיקייה כדי להתחיל.';

  @override
  String media_photoPicker_files_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'קישור $count פריטים',
      one: 'קישור פריט אחד',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachToSiteButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'צירוף $count פריטים לאתר זה',
      one: 'צירוף פריט אחד לאתר זה',
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
      other: '$fileCount קבצים',
      one: 'קובץ אחד',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount צלילות',
      one: 'צלילה אחת',
    );
    return '$_temp0, $_temp1, $unmatchedCount ללא התאמה';
  }

  @override
  String media_photoPicker_files_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים',
      one: 'פריט אחד',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_diveGroupTitle(String diveId) {
    return 'צלילה $diveId';
  }

  @override
  String media_photoPicker_files_groupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count קבצים',
      one: 'קובץ אחד',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_unmatchedGroupTitle => 'ללא התאמה';

  @override
  String media_photoPicker_files_addAllToDive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הוספת כל $count הפריטים לצלילה זו',
      one: 'הוספת פריט אחד לצלילה זו',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_addToDiveTooltip => 'הוספה לצלילה זו';

  @override
  String get media_photoPicker_files_chooseDiveTooltip => 'בחירת צלילה';

  @override
  String get media_photoPicker_files_removeTooltip => 'הסרה מהבחירה';

  @override
  String get media_photoPicker_files_sourceExif => 'מ-EXIF';

  @override
  String get media_photoPicker_files_sourceContainer => 'ממטא-נתוני הקובץ';

  @override
  String get media_photoPicker_files_sourceFileDate => 'מתאריך הקובץ';

  @override
  String get media_photoPicker_files_sourceNone => 'לא נמצא תאריך';

  @override
  String media_photoPicker_files_shiftedTime(String shifted, String original) {
    return '$shifted (היה $original)';
  }

  @override
  String get media_photoPicker_files_reasonNoTimestamp =>
      'לא ניתן לקרוא את זמן הצילום';

  @override
  String media_photoPicker_files_reasonBeforeDive(String gap) {
    return '$gap לפני הצלילה הקרובה ביותר';
  }

  @override
  String media_photoPicker_files_reasonAfterDive(String gap) {
    return '$gap אחרי הצלילה הקרובה ביותר';
  }

  @override
  String get media_photoPicker_files_reasonNoDives => 'אין צלילות להשוואה';

  @override
  String get media_photoPicker_files_offsetLabel => 'הסטת זמני הצילום ב-';

  @override
  String get media_photoPicker_files_offsetResetTooltip => 'איפוס ההסטה';

  @override
  String media_photoPicker_files_offsetBackTooltip(String amount) {
    return 'הסטה של $amount אחורה';
  }

  @override
  String media_photoPicker_files_offsetForwardTooltip(String amount) {
    return 'הסטה של $amount קדימה';
  }

  @override
  String media_photoPicker_files_linkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים קושרו',
      one: 'פריט אחד קושר',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachedToSiteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים צורפו לאתר זה',
      one: 'פריט אחד צורף לאתר זה',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_undo => 'ביטול';

  @override
  String get media_photoPicker_thumbnailAlreadyLinkedLabel =>
      'תמונה כבר מקושרת לצלילה זו';

  @override
  String get media_perdixOverlay_labelCns => 'CNS';

  @override
  String get media_perdixOverlay_labelDepth => 'עומק';

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
  String get media_perdixOverlay_labelTemp => 'טמפ';

  @override
  String get media_perdixOverlay_labelTime => 'זמן';

  @override
  String get media_perdixOverlay_labelTts => 'TTS';

  @override
  String get media_perdixOverlay_toggleTooltip => 'שכבת מחשב צלילה';

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
  String get media_photoViewer_nextTooltip => 'המדיה הבאה';

  @override
  String get media_photoViewer_noPhotosAvailable => 'אין תמונות זמינות';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel => 'הפעל או השהה סרטון';

  @override
  String get media_photoViewer_previousTooltip => 'המדיה הקודמת';

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
  String get media_unavailablePlaceholder_notOnDevice => 'לא במכשיר הזה';

  @override
  String get media_unavailablePlaceholder_signInRequired => 'Sign in to view';

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
  String get media_writeMetadata_livePhotoUnsupported =>
      '‏Live Photos עדיין אינן נתמכות. שכפל תמונה זו כתמונת סטילס, ולאחר מכן כתוב את נתוני הצלילה בעותק.';

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
  String get nav_gpsLog => 'יומן GPS';

  @override
  String get media_console_library => 'ספרייה';

  @override
  String get media_console_transfers => 'העברות';

  @override
  String get media_console_import => 'ייבוא';

  @override
  String get media_import_launch => 'ייבוא מדיה...';

  @override
  String get media_import_review_title => 'סקירת ייבוא';

  @override
  String media_import_review_confirm(int count) {
    return 'ייבוא $count פריטים';
  }

  @override
  String media_import_review_result(int linked, int skipped, int failed) {
    return '$linked מקושרים, $skipped דולגו, $failed נכשלו';
  }

  @override
  String get media_import_review_chooseSite => 'בחירת אתר';

  @override
  String get media_import_review_ambiguous => 'כמה צלילות תואמות';

  @override
  String get media_import_review_noMatch => 'אין צלילה תואמת';

  @override
  String get media_import_review_skipped => 'לא יובא';

  @override
  String media_import_review_linkChip(int number) {
    return 'קישור אל #$number';
  }

  @override
  String get media_import_review_linkToDive => 'קישור לצלילה';

  @override
  String get media_import_review_linkToSite => 'קישור לאתר';

  @override
  String get media_import_review_chooseDive => 'בחירת צלילה';

  @override
  String get media_import_intro =>
      'תמונות מקושרות לצלילה או לאתר צלילה בעת הייבוא.';

  @override
  String get media_console_sources => 'מקורות';

  @override
  String get media_sources_browseHeader => 'עיון לפי מקור';

  @override
  String get media_sources_watchedHeader => 'תיקיות במעקב';

  @override
  String get media_sources_addWatched => 'הוספת תיקייה...';

  @override
  String get media_sources_scanFailed => 'הסריקה נכשלה';

  @override
  String get media_sources_scanNow => 'סריקה עכשיו';

  @override
  String get media_sources_autoApply => 'קישור אוטומטי של התאמות מדויקות';

  @override
  String get media_sources_neverScanned => 'לא נסרק מעולם';

  @override
  String get media_source_gallery => 'ספריית תמונות';

  @override
  String get media_source_localFile => 'קבצים מקומיים';

  @override
  String get media_source_networkUrl => 'קישורי אינטרנט';

  @override
  String get media_source_manifest => 'מנויים';

  @override
  String get media_source_connector => 'שירותים מחוברים';

  @override
  String get media_source_mediaStore => 'מאגר מדיה בענן';

  @override
  String get media_source_signature => 'חתימות';

  @override
  String get media_repairHistory_title => 'היסטוריית תיקונים';

  @override
  String get media_repairHistory_empty => 'אין תיקונים עדיין';

  @override
  String get media_repairHistory_action_relink => 'קושר מחדש';

  @override
  String get media_repairHistory_action_cloudBacked => 'מגובה בענן';

  @override
  String get media_repairHistory_action_autoRelink => 'קושר מחדש אוטומטית';

  @override
  String get media_smartAlbum_save => 'שמירה כאלבום';

  @override
  String get media_smartAlbum_saveTitle => 'שם לאלבום';

  @override
  String get media_smartAlbum_albums => 'אלבומים';

  @override
  String get media_smartAlbum_delete => 'מחיקת אלבום';

  @override
  String get media_smartAlbum_deleteFailed => 'מחיקת האלבום נכשלה';

  @override
  String get media_smartAlbum_saved => 'האלבום נשמר';

  @override
  String media_sources_lastScanned(String date) {
    return 'נסרק לאחרונה $date';
  }

  @override
  String media_sources_scanResult(int indexed, int repaired) {
    return '$indexed קבצים נסרקו, $repaired קושרו מחדש';
  }

  @override
  String get media_repairHistory_sourceFolder => 'סריקת תיקיות';

  @override
  String get media_repairHistory_sourcePhotoLibrary => 'ספריית התמונות';

  @override
  String get media_repairHistory_sourceStore => 'אחסון מדיה בענן';

  @override
  String get media_repairHistory_sourceWatcher => 'תיקיות במעקב';

  @override
  String get media_repairHistory_sourceManual => 'קישור ידני';

  @override
  String media_repairHistory_source(String source) {
    return 'דרך $source';
  }

  @override
  String get media_missing_empty => 'אין קבצים חסרים';

  @override
  String media_missing_offlineVolumes(int count) {
    return '$count בכוננים לא מחוברים';
  }

  @override
  String get media_missing_repair => 'תיקון...';

  @override
  String get media_repair_title => 'תיקון קבצים חסרים';

  @override
  String get media_repair_addFolder => 'הוספת תיקייה...';

  @override
  String get media_repair_usePhotoLibrary => 'חיפוש בספריית התמונות';

  @override
  String get media_repair_useStore => 'שימוש במאגר המדיה בענן';

  @override
  String get media_repair_scan => 'סריקה';

  @override
  String media_repair_prefixMove(String from, String to, int count) {
    return 'זוהתה העברת תיקייה: $from אל $to מכסה $count קבצים';
  }

  @override
  String get media_repair_confidence_exact => 'מדויק';

  @override
  String get media_repair_confidence_probable => 'שם וגודל';

  @override
  String get media_repair_confidence_edited => 'קובץ ערוך';

  @override
  String get media_repair_confidence_unmatched => 'אין מועמד';

  @override
  String get media_repair_unverified => 'לא אומת מול המאגר';

  @override
  String media_repair_apply(int count) {
    return 'קישור מחדש של $count קבצים';
  }

  @override
  String media_repair_summary(
    int relinked,
    int cloudBacked,
    int reuploads,
    int failed,
    int skipped,
  ) {
    return '$relinked קושרו מחדש, $cloudBacked מגובים בענן, $reuploads העלאות חוזרות בתור, $failed נכשלו, $skipped דולגו';
  }

  @override
  String get media_library_empty => 'אין מדיה עדיין';

  @override
  String get media_library_filter_all => 'הכול';

  @override
  String get media_library_filter_photos => 'תמונות';

  @override
  String get media_library_filter_videos => 'סרטונים';

  @override
  String get media_library_filter_site => 'אתר';

  @override
  String get media_library_filter_trip => 'טיול';

  @override
  String get media_library_filter_dates => 'תאריכים';

  @override
  String get media_library_filter_missing => 'קבצים חסרים';

  @override
  String media_library_filter_missingCount(int count) {
    return 'קבצים חסרים ($count)';
  }

  @override
  String get media_library_filter_clear => 'ניקוי מסננים';

  @override
  String get media_library_filter_any => 'הכול';

  @override
  String get media_library_filter_title => 'סינון מדיה';

  @override
  String get media_library_filter_apply => 'החל';

  @override
  String get media_library_sort_title => 'מיון מדיה';

  @override
  String get media_smartAlbum_load => 'טעינת אלבום';

  @override
  String get media_divePicker_title => 'העברה לצלילה';

  @override
  String get media_divePicker_search => 'חיפוש צלילות';

  @override
  String get media_library_moveToDive => 'העברה לצלילה';

  @override
  String get media_library_unlinkSelected => 'בטל קישור';

  @override
  String media_library_selectedCount(int count) {
    return '$count נבחרו';
  }

  @override
  String get media_library_unlinkedHeader => 'לא מקושרים';

  @override
  String get media_library_diveHeaderHint => 'פתיחת צלילה זו';

  @override
  String get media_library_untitledDiveHeader => 'צלילה ללא שם';

  @override
  String get media_library_viewMode_byDive => 'לפי צלילה';

  @override
  String get media_library_viewMode_grid => 'רשת';

  @override
  String get media_library_viewMode_timeline => 'ציר זמן';

  @override
  String get media_viewer_goToDive => 'מעבר לצלילה';

  @override
  String get nav_home => 'בית';

  @override
  String get nav_media => 'מדיה';

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
  String plannerCanvas_bailout_available(String liters) {
    return 'זמין $liters';
  }

  @override
  String get plannerCanvas_bailout_insufficient =>
      'גז חילוץ אינו מספיק למקרה הגרוע ביותר';

  @override
  String plannerCanvas_bailout_required(String liters) {
    return 'נדרש $liters';
  }

  @override
  String get plannerCanvas_bailout_title => 'חילוץ (מעגל פתוח)';

  @override
  String plannerCanvas_bailout_tts(String minutes) {
    return 'TTS חילוץ $minutes′';
  }

  @override
  String plannerCanvas_bailout_worstCase(String minutes, String depth) {
    return 'המקרה הגרוע ב-$minutes′ · $depth';
  }

  @override
  String get plannerCanvas_ccr_setpointHigh => 'נקודת כיוון גבוהה (bar)';

  @override
  String get plannerCanvas_ccr_setpointLow => 'נקודת כיוון נמוכה (bar)';

  @override
  String get plannerCanvas_ccr_switchDepth => 'עומק החלפת נקודת הכיוון';

  @override
  String get plannerCanvas_pscr_ratio => 'יחס pSCR';

  @override
  String get plannerCanvas_pscr_ratio_hint =>
      'גדול יותר = יותר גז טרי, ירידת חמצן קטנה יותר';

  @override
  String plannerCanvas_chip_cns(String value) {
    return 'CNS $value%';
  }

  @override
  String plannerCanvas_chip_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count בעיות',
      one: 'בעיה אחת',
    );
    return '$_temp0';
  }

  @override
  String get plannerCanvas_compare_action => 'השוואה';

  @override
  String get plannerCanvas_compare_needTwo => 'בחר לפחות שתי תוכניות להשוואה';

  @override
  String get plannerCanvas_compare_title => 'השוואת תוכניות';

  @override
  String get plannerCanvas_contingency_base => 'בסיס';

  @override
  String get plannerCanvas_contingency_depthDelta => 'עומק נוסף';

  @override
  String plannerCanvas_contingency_lostGas(String gas) {
    return 'אבדן $gas';
  }

  @override
  String plannerCanvas_contingency_previewing(String label) {
    return 'תצוגה מקדימה: $label';
  }

  @override
  String get plannerCanvas_contingency_timeDelta => 'דקות נוספות';

  @override
  String plannerCanvas_chart_meanDepth(String depth) {
    return 'ממוצע $depth';
  }

  @override
  String get plannerCanvas_contingency_title => 'תוכניות חירום';

  @override
  String get plannerCanvas_contingency_turnFraction => 'שבר פנייה';

  @override
  String get plannerCanvas_contingency_turnRule => 'כלל לחץ פנייה';

  @override
  String get plannerCanvas_convert_success => 'נוצרה צלילה מהתוכנית';

  @override
  String get plannerCanvas_convert_view => 'הצג';

  @override
  String plannerCanvas_follow_chip(String name) {
    return 'עוקב אחרי $name';
  }

  @override
  String get plannerCanvas_follow_empty => 'אין עדיין צלילות מתועדות';

  @override
  String get plannerCanvas_follow_noTissues =>
      'אין נתוני פרופיל לצלילה זו — מרווח הפנים נקבע ללא העמסת רקמות';

  @override
  String get plannerCanvas_follow_title => 'עקוב אחרי צלילה';

  @override
  String plannerCanvas_gas_minGas(String pressure) {
    return 'גז מינימלי $pressure';
  }

  @override
  String plannerCanvas_gas_turnAt(String pressure) {
    return 'פנייה ב-$pressure';
  }

  @override
  String plannerCanvas_issue_gasDensityCritical(String value) {
    return 'צפיפות הגז $value g/L מעל הגבול המרבי';
  }

  @override
  String plannerCanvas_issue_gasDensityHigh(String value) {
    return 'צפיפות הגז $value g/L מעל הגבול המומלץ';
  }

  @override
  String plannerCanvas_issue_hypoxic(String depth, String value) {
    return 'גז היפוקסי ב-$depth (ppO₂ $value bar)';
  }

  @override
  String plannerCanvas_issue_minGas(String pressure) {
    return 'המיכל מסתיים מתחת למינימום rock bottom של $pressure';
  }

  @override
  String get plannerCanvas_issue_noBailout =>
      'תוכנית דקומפרסיה CCR ללא גז חילוץ (bailout)';

  @override
  String get plannerCanvas_issue_noDecoGas =>
      'נדרשת דקומפרסיה אך לא נלקח גז דקו';

  @override
  String get plannerCanvas_range_base => 'בסיס';

  @override
  String get plannerCanvas_range_legend =>
      'התאים מציגים את זמן העלייה לפני המים; אדום = לא ניתן לצלול כמתוכנן';

  @override
  String get plannerCanvas_pane_collapse => 'כווץ חלונית';

  @override
  String get plannerCanvas_pane_expand => 'הרחב חלונית';

  @override
  String get plannerCanvas_tab_setup => 'הגדרה';

  @override
  String get plannerCanvas_o2Narcotic => 'התייחס לחמצן כמשכר';

  @override
  String get plannerCanvas_rates_ascent => 'קצב עלייה';

  @override
  String get plannerCanvas_rates_descent => 'קצב ירידה';

  @override
  String get plannerCanvas_rates_title => 'קצבים';

  @override
  String get plannerCanvas_range_title => 'טבלת טווחים';

  @override
  String get plannerCanvas_results_noDeco => 'לא נדרשת דקומפרסיה';

  @override
  String plannerCanvas_sac_useLogged(String sac) {
    return 'השתמש בממוצע המתועד ($sac)';
  }

  @override
  String plannerCanvas_saved_deleteConfirmBody(String name) {
    return 'למחוק לצמיתות את \"$name\"?';
  }

  @override
  String get plannerCanvas_saved_deleteConfirmTitle => 'למחוק את התוכנית?';

  @override
  String get plannerCanvas_saved_duplicate => 'שכפול';

  @override
  String get plannerCanvas_saved_empty => 'אין עדיין תוכניות שמורות';

  @override
  String get plannerCanvas_saved_title => 'תוכניות שמורות';

  @override
  String get plannerCanvas_name_dialogTitle => 'תן שם לתוכנית';

  @override
  String get plannerCanvas_name_defaultFallback => 'תוכנית צלילה';

  @override
  String plannerCanvas_scrub_bailout(String minutes) {
    return 'BO $minutes′';
  }

  @override
  String plannerCanvas_scrub_readout(String minutes, String depth) {
    return 'RT $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_share_import => 'ייבוא';

  @override
  String plannerCanvas_share_importFailed(String reason) {
    return 'לא ניתן לייבא את התוכנית: $reason';
  }

  @override
  String get plannerCanvas_share_menu => 'שיתוף קובץ תוכנית';

  @override
  String get plannerCanvas_slate_menu => 'ייצוא לוח (PDF)';

  @override
  String get plannerCanvas_slate_minGas => 'גז מינימלי';

  @override
  String get plannerCanvas_slate_turn => 'נקודת חזרה';

  @override
  String get plannerCanvas_table_depth => 'עומק';

  @override
  String get plannerCanvas_table_gas => 'גז';

  @override
  String get plannerCanvas_table_runtime => 'RT';

  @override
  String get plannerCanvas_table_stop => 'עצירה';

  @override
  String get plannerCanvas_turnRule_allUsable => 'הכול שמיש';

  @override
  String get plannerCanvas_turnRule_custom => 'מותאם אישית';

  @override
  String get plannerCanvas_turnRule_halves => 'חצאים';

  @override
  String get plannerCanvas_turnRule_none => 'ללא';

  @override
  String get plannerCanvas_turnRule_thirds => 'שלישים';

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
  String get planning_newPlan => 'תוכנית חדשה';

  @override
  String get planning_section_tools => 'כלים';

  @override
  String get planning_summary_prompt => 'בחר כלי כדי להתחיל';

  @override
  String get planning_summary_savedPlans => 'תוכניות שמורות';

  @override
  String get planning_summary_noPlans => 'אין עדיין תוכניות שמורות';

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
  String get settings_about_reportIssue_copy => 'העתקת קישור';

  @override
  String get settings_about_reportIssue_snackbar =>
      'בקר ב-github.com/submersion-app/submersion/issues';

  @override
  String settings_about_version(String version) {
    return 'גרסה $version';
  }

  @override
  String get settings_appBar_title => 'הגדרות';

  @override
  String get settings_appearance_appLanguage => 'שפת האפליקציה';

  @override
  String get settings_appearance_displaySize => 'גודל התצוגה';

  @override
  String settings_appearance_displaySize_value(int percent) {
    return '$percent%';
  }

  @override
  String get settings_appearance_displaySize_reset => 'איפוס';

  @override
  String get settings_appearance_displaySize_smaller => 'קטן יותר';

  @override
  String get settings_appearance_displaySize_larger => 'גדול יותר';

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
  String get settings_appearance_gasTimeline => 'ציר זמן של הגז';

  @override
  String get settings_appearance_gasTimeline_subtitle =>
      'הצג את רצועת צריכת הגז מתחת לפרופיל הצלילה כברירת מחדל';

  @override
  String get settings_appearance_header_diveDetails => 'פרטי צלילה';

  @override
  String get settings_appearance_header_diveLog => 'יומן צלילות';

  @override
  String get settings_appearance_header_diveProfile => 'פרופיל צלילה';

  @override
  String get settings_appearance_header_diveSites => 'אתרי צלילה';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility =>
      'סדר וחשיפת סעיפים';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility_subtitle =>
      'בחר אילו סעיפים יוצגו ובאיזה סדר';

  @override
  String get settings_diveDetailSections_title => 'סדר וחשיפת סעיפים';

  @override
  String get settings_diveDetailSections_resetToDefault => 'איפוס לברירת מחדל';

  @override
  String get settings_diveDetailSections_fixedSections =>
      'סעיפים קבועים: כותרת, תרשים פרופיל צלילה';

  @override
  String get settings_diveDetailSections_configurableSections =>
      'סעיפים הניתנים להגדרה (גרור לסידור מחדש)';

  @override
  String get diveDetailSection_decoO2_name => 'סטטוס דקו / עומס רקמות';

  @override
  String get diveDetailSection_decoO2_description =>
      'NDL, תקרה, מפת חום של רקמות, רעילות O2';

  @override
  String get diveDetailSection_safetyReview_name => 'סקירת בטיחות';

  @override
  String get diveDetailSection_safetyReview_description =>
      'תצפיות אוטומטיות על פרופיל הצלילה לאחר הצלילה';

  @override
  String get safetyReview_sectionTitle => 'סקירת בטיחות';

  @override
  String safetyReview_findingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תצפיות',
      one: 'תצפית אחת',
    );
    return '$_temp0';
  }

  @override
  String safetyReview_rapidAscent_title(String rate, String duration) {
    return 'העלייה חרגה מ-$rate למשך $duration';
  }

  @override
  String safetyReview_missedDecoStop_title(String excess, String duration) {
    return 'העומק היה $excess מעל תקרת העצירה הנדרשת למשך $duration';
  }

  @override
  String safetyReview_omittedSafetyStop_title(String remaining) {
    return 'עצירת הבטיחות המומלצת קוצרה ב-$remaining';
  }

  @override
  String safetyReview_sawtoothProfile_title(int count) {
    return '$count שינויי עומק חוזרים מעלה ומטה במהלך הצלילה';
  }

  @override
  String safetyReview_highSurfaceGf_title(String gf, String gfHigh) {
    return 'עלייה לפני השטח עם פקטור גרדיאנט $gf, מעל $gfHigh שהוגדר';
  }

  @override
  String safetyReview_timeRange(String start, String end) {
    return 'ב-$start–$end';
  }

  @override
  String get safetyReview_dismiss => 'התעלם';

  @override
  String get safetyReview_restore => 'שחזר';

  @override
  String get safetyReview_dismissAll => 'התעלם מהכול';

  @override
  String get safetyReview_restoreAll => 'שחזר הכול';

  @override
  String get safetySettings_dismissAll => 'התעלם מכל התצפיות';

  @override
  String get safetySettings_dismissAll_subtitle =>
      'סמן את כל התצפיות ביומן זה כנסקרו';

  @override
  String get safetySettings_dismissAll_confirmTitle => 'להתעלם מכל התצפיות?';

  @override
  String get safetySettings_dismissAll_confirmBody =>
      'כל תצפית בכל צלילה שנותחה תסומן כנסקרה. אפשר לשחזר אותן צלילה אחר צלילה במקטע סקירת הבטיחות שלה.';

  @override
  String get safetySettings_dismissAll_confirm => 'התעלם מהכול';

  @override
  String get safetySettings_dismissAll_cancel => 'ביטול';

  @override
  String safetySettings_dismissAll_progress(int done, int total) {
    return 'נבדקו $done מתוך $total צלילות';
  }

  @override
  String safetySettings_dismissAll_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'בוצעה התעלמות מ-$count תצפיות',
      one: 'בוצעה התעלמות מתצפית אחת',
      zero: 'אין תצפיות להתעלם מהן',
    );
    return '$_temp0';
  }

  @override
  String safetySettings_dismissAll_doneWithErrors(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'בוצעה התעלמות מ-$count תצפיות',
      one: 'בוצעה התעלמות מתצפית אחת',
      zero: 'לא בוצעה התעלמות מתצפיות',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: 'לא ניתן היה לעדכן $failed צלילות',
      one: 'לא ניתן היה לעדכן צלילה אחת',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get safetySettings_dismissAll_failed =>
      'לא ניתן לקרוא את רשימת הצלילות. דבר לא שונה.';

  @override
  String get safetySettings_analyzeAll_failed => 'לא ניתן לנתח את הצלילות.';

  @override
  String get safetyReview_details => 'פרטים';

  @override
  String get safetyReview_clearHighlight => 'ניקוי הדגשה';

  @override
  String safetyReview_findingGroupSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ממצאי בטיחות',
      one: 'ממצא בטיחות אחד',
    );
    return '$_temp0';
  }

  @override
  String get safetySettings_title => 'סקירת בטיחות';

  @override
  String get safetySettings_entry_subtitle => 'תצפיות וכללים לאחר הצלילה';

  @override
  String get safetySettings_masterToggle => 'סקירת בטיחות לאחר הצלילה';

  @override
  String get safetySettings_masterToggle_subtitle =>
      'רישום אוטומטי של תצפיות עלייה, עצירות ופרופיל בצלילות שנותחו';

  @override
  String get safetySettings_rulesHeader => 'כללים';

  @override
  String get safetySettings_rule_rapidAscent => 'עליות מהירות';

  @override
  String get safetySettings_rule_missedDecoStop =>
      'עצירות דקו שהוחמצו או קוצרו';

  @override
  String get safetySettings_rule_omittedSafetyStop => 'עצירות בטיחות שהושמטו';

  @override
  String get safetySettings_rule_sawtoothProfile => 'פרופילי שן מסור';

  @override
  String get safetySettings_rule_highSurfaceGf =>
      'פקטור גרדיאנט גבוה בעלייה לפני השטח';

  @override
  String get safetySettings_analyzeAll => 'נתח את כל הצלילות';

  @override
  String get safetySettings_analyzeAll_subtitle =>
      'הרצת סקירת הבטיחות על כל צלילה עם פרופיל שטרם נותחה';

  @override
  String safetySettings_analyzeAll_progress(int done, int total) {
    return 'נותחו $done מתוך $total';
  }

  @override
  String get safetySettings_analyzeAll_done => 'הניתוח הושלם';

  @override
  String safetySettings_analyzeAll_doneWithErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לא ניתן היה לנתח $count צלילות',
      one: 'לא ניתן היה לנתח צלילה אחת',
    );
    return 'הניתוח הושלם — $_temp0';
  }

  @override
  String safetyReview_showDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הצג $count תצפיות שהוסתרו',
      one: 'הצג תצפית אחת שהוסתרה',
    );
    return '$_temp0';
  }

  @override
  String get diveDetailSection_sacSegments_name => 'קצב SAC לפי קטע';

  @override
  String get diveDetailSection_sacSegments_description =>
      'פילוח SAC לפי שלב/זמן';

  @override
  String get diveDetailSection_details_name => 'פרטים';

  @override
  String get diveDetailSection_details_description =>
      'סוג, מיקום, טיול, מרכז צלילה, מרווח';

  @override
  String get diveDetailSection_environment_name => 'סביבה';

  @override
  String get diveDetailSection_environment_description =>
      'טמפרטורת אוויר/מים, ראות, זרם';

  @override
  String get diveDetailSection_altitude_name => 'גובה';

  @override
  String get diveDetailSection_altitude_description =>
      'ערך גובה, קטגוריה, דרישת דקומפרסיה';

  @override
  String get diveDetailSection_tide_name => 'גאות ושפל';

  @override
  String get diveDetailSection_tide_description => 'גרף מחזור גאות ושפל וזמן';

  @override
  String get diveDetailSection_reefHealth_name => 'תנאי המים';

  @override
  String get diveDetailSection_reefHealth_description =>
      'תנאי מים לווייניים בתאריך הצלילה';

  @override
  String get diveDetailSection_surfaceGps_name => 'GPS פני המים';

  @override
  String get diveDetailSection_surfaceGps_description =>
      'נקודות כניסה/יציאה ב-GPS וסחף פני המים';

  @override
  String get diveLog_detail_section_surfaceGps => 'GPS פני המים';

  @override
  String get diveLog_detail_surfaceGps_entry => 'כניסה';

  @override
  String get diveLog_detail_surfaceGps_exit => 'יציאה';

  @override
  String get diveLog_detail_label_drift => 'סחף';

  @override
  String get diveLog_detail_surfaceGps_entryOnly => 'נקודת הכניסה נרשמה';

  @override
  String get diveLog_detail_surfaceGps_exitOnly => 'נקודת היציאה נרשמה';

  @override
  String get diveLog_detail_surfaceGps_site => 'אתר';

  @override
  String get diveLog_detail_surfaceGps_track => 'מסלול פני השטח';

  @override
  String get diveLog_detail_surfaceGps_showFullTrack => 'מסלול מלא';

  @override
  String diveLog_detail_surfaceGps_trackFixes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count נקודות',
      two: 'שתי נקודות',
      one: 'נקודה אחת',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_detail_locationsMap_title => 'מיקומי צלילה';

  @override
  String get diveLog_detail_coordinatesCopied => 'הקואורדינטות הועתקו ללוח';

  @override
  String get diveLog_detail_openInMaps => 'פתח במפות';

  @override
  String get diveDetailSection_weights_name => 'משקולות';

  @override
  String get diveDetailSection_weights_description =>
      'פירוט משקולות, משקל כולל';

  @override
  String get diveDetailSection_buoyancy_name => 'ציפה';

  @override
  String get diveDetailSection_buoyancy_description =>
      'ציפה לאורך הצלילה, שינוי ומשקל הניתן להשלכה';

  @override
  String get buoyancy_tooltip =>
      'ציפה נטו מודלת לאורך הצלילה מהפרופיל, צריכת הגז והציוד.';

  @override
  String buoyancy_verdictBuoyant(String depth, String amount) {
    return 'בעצירה האחרונה (~$depth) היית בערך $amount ציפה';
  }

  @override
  String buoyancy_verdictHeavy(String depth, String amount) {
    return 'בעצירה האחרונה (~$depth) היית כבד בערך ב-$amount';
  }

  @override
  String get buoyancy_verdictNeutral =>
      'התצורה שלך הייתה קרובה לניטרלית בעצירה האחרונה';

  @override
  String get buoyancy_verdictConvention =>
      'מוערך לפי מוסכמת עצירת הבטיחות ב-5 מ\'';

  @override
  String get buoyancy_breakdownTitle => 'פירוט מרכיבים';

  @override
  String get buoyancy_suitTerm => 'חליפה';

  @override
  String get buoyancy_leadTerm => 'משקולות';

  @override
  String get buoyancy_beginNet => 'תחילת הצלילה';

  @override
  String get buoyancy_endNet => 'סוף הצלילה';

  @override
  String get buoyancy_swing => 'שינוי ציפה';

  @override
  String get buoyancy_peakLift => 'כוח ציפה מרבי נדרש';

  @override
  String get buoyancy_wingWarning => 'חורג מכוח הציפה הנקוב של האגף';

  @override
  String get buoyancy_minDitchable => 'משקל מזערי הניתן להשלכה';

  @override
  String get buoyancy_droppable => 'ניתן להשליך';

  @override
  String get buoyancy_ditchWarning => 'יותר ממה שניתן להשליך';

  @override
  String get buoyancy_drysuitGas => 'גז יבשה שנוסף';

  @override
  String get buoyancy_estimatedPressures => 'לחצי המכלים משוערים';

  @override
  String get buoyancy_linkSuitHint =>
      'קשר חליפת חשיפה לצלילה זו לתמונה מלאה יותר';

  @override
  String get buoyancy_noLeadHint =>
      'לא נרשמו משקולות: הוסף משקולות לצלילה זו או משקל יבש לציוד המשקולות שלך';

  @override
  String get buoyancy_chartNet => 'נטו';

  @override
  String get buoyancy_chartRig => 'ציוד + משקולות';

  @override
  String get buoyancy_chartMinutes => 'זמן (דק\')';

  @override
  String get buoyancy_historyTitle => 'היסטוריית משקולות';

  @override
  String get buoyancy_historyCarried => 'נישא';

  @override
  String get buoyancy_historyModeled => 'ממודל';

  @override
  String buoyancy_historyMore(String delta) {
    return 'בדרך כלל אתה נושא $delta יותר ממה שהמודל מציע';
  }

  @override
  String buoyancy_historyLess(String delta) {
    return 'בדרך כלל אתה נושא $delta פחות ממה שהמודל מציע';
  }

  @override
  String get buoyancy_throughDive => 'לאורך הצלילה';

  @override
  String get buoyancy_adjust => 'התאמה';

  @override
  String get buoyancy_whatIfTitle => 'התאמת צלילה זו';

  @override
  String get buoyancy_whatIfLead => 'משקולות';

  @override
  String get buoyancy_whatIfSuit => 'ציפת החליפה';

  @override
  String get buoyancy_whatIfReset => 'איפוס';

  @override
  String buoyancy_whatIfDelta(String delta) {
    return '$delta מול בפועל';
  }

  @override
  String get diveDetailSection_tanks_name => 'בלונים';

  @override
  String get diveDetailSection_tanks_description =>
      'רשימת בלונים, תערובות גז, לחצים, SAC לבלון';

  @override
  String get diveDetailSection_buddies_name => 'חברי צלילה';

  @override
  String get diveDetailSection_buddies_description =>
      'רשימת חברי צלילה עם תפקידים';

  @override
  String get diveDetailSection_signatures_name => 'חתימות';

  @override
  String get diveDetailSection_signatures_description =>
      'הצגה ולכידה של חתימות חבר/מדריך';

  @override
  String get diveDetailSection_equipment_name => 'ציוד';

  @override
  String get diveDetailSection_equipment_description => 'ציוד שהשתמש בצלילה';

  @override
  String get diveDetailSection_sightings_name => 'תצפיות חיי ים';

  @override
  String get diveDetailSection_sightings_description =>
      'מינים שנצפו, פרטי תצפית';

  @override
  String get diveDetailSection_media_name => 'מדיה';

  @override
  String get diveDetailSection_media_description => 'גלריית תמונות/סרטונים';

  @override
  String get diveDetailSection_tags_name => 'תגיות';

  @override
  String get diveDetailSection_tags_description => 'תגיות צלילה';

  @override
  String get diveDetailSection_notes_name => 'הערות';

  @override
  String get diveDetailSection_notes_description => 'הערות/תיאור צלילה';

  @override
  String get diveDetailSection_customFields_name => 'שדות מותאמים אישית';

  @override
  String get diveDetailSection_customFields_description =>
      'שדות מותאמים אישית שהוגדרו על ידי המשתמש';

  @override
  String get diveDetailSection_dataSources_name => 'מקורות נתונים';

  @override
  String get diveDetailSection_dataSources_description =>
      'מחשבי צלילה מחוברים, ניהול מקורות';

  @override
  String get settings_appearance_header_language => 'שפה';

  @override
  String get settings_appearance_header_theme => 'ערכת נושא';

  @override
  String get settings_appearance_header_mode => 'מצב';

  @override
  String get settings_themes_title => 'בחר ערכת נושא';

  @override
  String get settings_themes_current => 'ערכת נושא';

  @override
  String get theme_submersion => 'טבילה';

  @override
  String get theme_console => 'קונסולה';

  @override
  String get theme_tropical => 'טרופי';

  @override
  String get theme_minimalist => 'מינימליסטי';

  @override
  String get theme_deep => 'מעמקים';

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
  String get settings_appearance_metric_estimatedTankPressure =>
      'לחץ בלון משוער';

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
  String get settings_appearance_metric_cns => 'CNS% (רעילות חמצן)';

  @override
  String get settings_appearance_metric_otu => 'OTU (יחידות סבילות חמצן)';

  @override
  String get settings_appearance_metric_photoMarkers => 'סמני תמונות';

  @override
  String settings_appearance_metricsEnabledCount(int count, int total) {
    return '$count מתוך $total מופעלים';
  }

  @override
  String get settings_appearance_pressureThresholdMarkers => 'סמני סף לחץ';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'הצג סמנים כאשר לחץ הבלון חוצה ספים';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'הצג סמנים כאשר לחץ הבלון חוצה ספי 2/3, 1/2 ו-1/3';

  @override
  String get settings_appearance_metricsFollowViewport =>
      'שמירת שכבות העל בתצוגה בעת זום';

  @override
  String get settings_appearance_metricsFollowViewport_subtitle =>
      'התאמת שכבות על כגון NDL ו-ppO2 לאזור הנראה במקום להגדיל אותן יחד עם ציר העומק';

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
  String get settings_appearance_subsection_standardMetrics =>
      'Standard Metrics';

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
  String get settings_backToSettings_tooltip => 'חזרה להגדרות';

  @override
  String get settings_cloudSync_appBar_title => 'סנכרון ענן של מסד נתונים';

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
  String get settings_cloudSync_entry_subtitle => 'סנכרון באמצעות אחסון ענן';

  @override
  String get settings_cloudSync_adopt_confirm => 'אימוץ הספרייה המשוחזרת';

  @override
  String settings_cloudSync_adopt_dialogContent(
    String deviceName,
    String date,
  ) {
    return 'הספרייה הוחלפה מגיבוי במכשיר \"$deviceName\" ($date). אימוץ יחליף את נתוני מכשיר זה בספרייה המשוחזרת. תחילה ייווצר גיבוי בטיחות של הנתונים הנוכחיים של מכשיר זה.';
  }

  @override
  String get settings_cloudSync_adopt_dialogTitle =>
      'לאמץ את הספרייה המשוחזרת?';

  @override
  String get settings_cloudSync_adopt_notNow => 'לא עכשיו';

  @override
  String get settings_cloudSync_dangerZone => 'אזור מסוכן';

  @override
  String get settings_cloudSync_replaceLibrary_tile => 'החלפת ספריית הענן';

  @override
  String get settings_cloudSync_replaceLibrary_tileSubtitle =>
      'להפוך את הספרייה של מכשיר זה לספרייה שכל המכשירים משתמשים בה';

  @override
  String get settings_cloudSync_replaceLibrary_dialogTitle =>
      'להחליף את ספריית הענן?';

  @override
  String get settings_cloudSync_replaceLibrary_dialogIntro =>
      'הספרייה של מכשיר זה הופכת לספרייה שכל המכשירים משתמשים בה.';

  @override
  String settings_cloudSync_replaceLibrary_dialogBody(num diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'ספריית הענן נמחקת ומוחלפת ב-$diveCount הצלילות שבמכשיר זה.',
      one: 'ספריית הענן נמחקת ומוחלפת בצלילה 1 שבמכשיר זה.',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_replaceLibrary_peers(num peerCount) {
    String _temp0 = intl.Intl.pluralLogic(
      peerCount,
      locale: localeName,
      other:
          '$peerCount מכשירים נוספים יתבקשו לאמץ אותה; עד אז השינויים שלהם לא ימוזגו.',
      one: 'מכשיר אחד נוסף יתבקש לאמץ אותה; עד אז השינויים שלו לא ימוזגו.',
      zero: 'אף מכשיר אחר עדיין לא מסתנכרן, ולכן אין מה לאמץ.',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_replaceLibrary_peersUnknown =>
      'כל שאר המכשירים יתבקשו לאמץ אותה; עד אז השינויים שלהם לא ימוזגו.';

  @override
  String get settings_cloudSync_replaceLibrary_backupNote =>
      'תחילה נוצר גיבוי של מכשיר זה. לא ניתן לבטל פעולה זו.';

  @override
  String get settings_cloudSync_replaceLibrary_confirmWord => 'החלפה';

  @override
  String get settings_cloudSync_replaceLibrary_confirmHint =>
      'הקלד \"החלפה\" לאישור';

  @override
  String get settings_cloudSync_replaceLibrary_confirm => 'החלפה';

  @override
  String get settings_cloudSync_firstSync_banner =>
      'הסנכרון הראשון ממתין לאישור. הקש על \'סנכרן עכשיו\' כדי לבדוק מה ישולב.';

  @override
  String get settings_cloudSync_firstSync_dialogConfirm => 'מזג וסנכרן';

  @override
  String get settings_cloudSync_firstSync_replaceHint =>
      'אם במקום זאת הספרייה של מכשיר זה אמורה להחליף את מה שנמצא בענן, בטל והשתמש בהגדרות > סנכרון ענן > החלפת ספריית הענן.';

  @override
  String settings_cloudSync_firstSync_dialogContent(
    int deviceCount,
    int diveCount,
  ) {
    return 'נמצאו נתוני סנכרון קיימים בענן ($deviceCount קובצי סנכרון). הסנכרון הראשון ישלב נתונים אלה עם $diveCount הצלילות שבמכשיר זה, בכל המכשירים המסונכרנים.\n\nאם אותן צלילות נוספו בנפרד בכל מכשיר, הן יופיעו פעמיים.';
  }

  @override
  String get settings_cloudSync_firstSync_dialogTitle => 'לשלב ספריות?';

  @override
  String settings_cloudSync_replace_banner(String deviceName) {
    return 'הסנכרון מושהה: הספרייה הוחלפה מגיבוי במכשיר \"$deviceName\". יש להקיש על \"סנכרן עכשיו\" לבדיקה.';
  }

  @override
  String get settings_cloudSync_switch_dialogTitle => 'להחליף שירות סנכרון?';

  @override
  String settings_cloudSync_switch_dialogContent(
    String fromName,
    String toName,
  ) {
    return 'הנתונים שלך לא יועברו מ-$fromName -- הם יישארו שם עד שתמחק אותם. לאחר ההחלפה, הסנכרון הבא של מכשיר זה ישלב את הנתונים שלו עם מה שכבר קיים ב-$toName. המכשירים האחרים שלך ימשיכו להשתמש ב-$fromName עד שתחליף גם כל אחד מהם.';
  }

  @override
  String get settings_cloudSync_switch_confirm => 'החלף';

  @override
  String settings_cloudSync_moved_banner(
    String deviceName,
    String destination,
  ) {
    return '$deviceName העביר ספרייה זו אל $destination. שירות זה כבר אינו מתעדכן על ידיו. בחר $destination למטה כדי לעקוב אחר ההעברה.';
  }

  @override
  String get settings_cloudSync_moved_dismiss => 'התעלם';

  @override
  String settings_cloudSync_cleanup_banner(String backend) {
    return 'נתוני סנכרון ישנים עדיין מאוחסנים ב-$backend מהזמן שלפני שהחלפת שירותים. הם כבר אינם בשימוש.';
  }

  @override
  String get settings_cloudSync_cleanup_delete => 'מחק נתונים ישנים';

  @override
  String get settings_cloudSync_cleanup_keep => 'שמור';

  @override
  String get settings_cloudSync_header_advanced => 'מתקדם';

  @override
  String get settings_cloudSync_signOut_backupWarning =>
      'גיבוי הענן יכובה והגיבויים יישמרו במיקום ברירת המחדל.';

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
  String settings_cloudSync_peerNeedsAdopt_banner(Object deviceList) {
    return 'ל$deviceList עדיין יש גרסת ספרייה ישנה או לא מוכרת, ולכן השינויים שלו לא מוזגו. פתח את Submersion במכשיר כדי לאמץ את הספרייה הנוכחית.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_bannerPlural(Object deviceList) {
    return 'ל$deviceList עדיין יש גרסת ספרייה ישנה או לא מוכרת, ולכן השינויים שלהם לא מוזגו. פתח את Submersion במכשירים כדי לאמץ את הספרייה הנוכחית.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_unnamedDevice(Object shortId) {
    return 'מכשיר $shortId';
  }

  @override
  String get settings_cloudSync_peerNeedsAdopt_listSeparator => ', ';

  @override
  String get settings_cloudSync_peerNeedsAdopt_listLastSeparator => ' ו-';

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamed(Object deviceList) {
    return '$deviceList מסתנכרן מגרסה חדשה יותר של Submersion, ולכן השינויים האחרונים שלו מוחזקים בינתיים.';
  }

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(
    Object deviceList,
  ) {
    return '$deviceList מסתנכרנים מגרסה חדשה יותר של Submersion, ולכן השינויים האחרונים שלהם מוחזקים בינתיים.';
  }

  @override
  String get settings_cloudSync_peerRequiresUpdate_updateAction =>
      'עדכן מכשיר זה כדי לקבל אותם.';

  @override
  String get settings_cloudSync_peerRequiresUpdate_storeAction =>
      'הם יוחלו אוטומטית ברגע שעדכון חנות האפליקציות של מכשיר זה יגיע; ייתכן שהעדכון עדיין בבדיקה.';

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
  String get settings_cloudSync_dropbox_account_title => 'חשבון Dropbox';

  @override
  String get settings_cloudSync_dropbox_connect_browserFailed =>
      'לא ניתן לפתוח את הדפדפן. נסה את כפתור פתח מחדש את הדפדפן.';

  @override
  String get settings_cloudSync_dropbox_connect_codeLabel => 'קוד הרשאה';

  @override
  String get settings_cloudSync_dropbox_connect_emptyCode =>
      'הזן את קוד ההרשאה המוצג בדפדפן שלך';

  @override
  String settings_cloudSync_dropbox_connect_failed(Object error) {
    return 'החיבור אל Dropbox נכשל: $error';
  }

  @override
  String get settings_cloudSync_dropbox_connect_instructions =>
      'הדפדפן שלך פתח דף הרשאה של Dropbox. אשר את הגישה, ולאחר מכן הדבק כאן את הקוד שמוצג על ידי Dropbox.';

  @override
  String get settings_cloudSync_dropbox_connect_reopenBrowser =>
      'פתח מחדש את הדפדפן';

  @override
  String get settings_cloudSync_dropbox_connect_submit => 'התחבר';

  @override
  String get settings_cloudSync_dropbox_connect_title => 'התחבר ל-Dropbox';

  @override
  String get settings_cloudSync_dropbox_connected => 'מחובר ל-Dropbox';

  @override
  String settings_cloudSync_dropbox_connectedAs(Object account) {
    return 'מחובר בתור $account';
  }

  @override
  String get settings_cloudSync_dropbox_disconnect => 'התנתק';

  @override
  String get settings_cloudSync_provider_dropbox_subtitle =>
      'סנכרון באמצעות Dropbox (Apps/Submersion)';

  @override
  String get settings_cloudSync_provider_dropbox_title => 'Dropbox';

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'סנכרון באמצעות Google Drive';

  @override
  String get settings_cloudSync_googleDrive_desktopNotConfigured =>
      'לא זמין בגרסה זו';

  @override
  String get settings_cloudSync_googleDrive_browserWait_title => 'המשך בדפדפן';

  @override
  String get settings_cloudSync_googleDrive_browserWait_message =>
      'סיים את ההתחברות לחשבון Google בדפדפן האינטרנט שלך, ולאחר מכן חזור אל Submersion.';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'אתחול ספק $providerName נכשל';
  }

  @override
  String get settings_cloudSync_provider_notAvailable => 'לא זמין בפלטפורמה זו';

  @override
  String get settings_cloudSync_provider_s3_edit => 'עריכת תצורת S3';

  @override
  String get settings_cloudSync_provider_s3_subtitle =>
      'עובד עם כל שירות אחסון תואם S3';

  @override
  String get settings_cloudSync_provider_s3_title => 'אחסון תואם S3';

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
  String get settings_conflict_ref_buddy => 'שותף';

  @override
  String get settings_conflict_ref_certification => 'הסמכה';

  @override
  String get settings_conflict_ref_checklistTemplate => 'תבנית רשימת משימות';

  @override
  String get settings_conflict_ref_connectedAccount => 'חשבון מחובר';

  @override
  String get settings_conflict_ref_course => 'קורס';

  @override
  String get settings_conflict_ref_courseRequirement => 'דרישת קורס';

  @override
  String get settings_conflict_ref_cylinderConfig => 'תצורת בלונים';

  @override
  String get settings_conflict_ref_dataSource => 'מקור נתונים';

  @override
  String get settings_conflict_ref_dive => 'צלילה';

  @override
  String get settings_conflict_ref_diveCenter => 'מועדון צלילה';

  @override
  String get settings_conflict_ref_diveComputer => 'מחשב צלילה';

  @override
  String get settings_conflict_ref_divePlan => 'תוכנית צלילה';

  @override
  String get settings_conflict_ref_diveSite => 'אתר צלילה';

  @override
  String get settings_conflict_ref_diveType => 'סוג צלילה';

  @override
  String get settings_conflict_ref_diver => 'צולל';

  @override
  String get settings_conflict_ref_equipment => 'ציוד';

  @override
  String get settings_conflict_ref_equipmentSet => 'סט ציוד';

  @override
  String get settings_conflict_ref_finding => 'ממצא';

  @override
  String get settings_conflict_ref_instructor => 'מדריך';

  @override
  String get settings_conflict_ref_linkedDive => 'צלילה מקושרת';

  @override
  String get settings_conflict_ref_media => 'מדיה';

  @override
  String get settings_conflict_ref_mediaSubscription => 'מנוי מדיה';

  @override
  String get settings_conflict_ref_missing => 'כבר לא בספרייה הזו';

  @override
  String settings_conflict_ref_named(Object name, Object date) {
    return '$name ($date)';
  }

  @override
  String get settings_conflict_ref_plannedTank => 'בלון מתוכנן';

  @override
  String get settings_conflict_ref_preDiveChecklistTemplate =>
      'תבנית רשימת בדיקות לפני צלילה';

  @override
  String get settings_conflict_ref_preDiveSession => 'רשימת בדיקות לפני צלילה';

  @override
  String get settings_conflict_ref_relatedDive => 'צלילה קשורה';

  @override
  String get settings_conflict_ref_serviceKind => 'סוג טיפול';

  @override
  String get settings_conflict_ref_sighting => 'תצפית';

  @override
  String get settings_conflict_ref_signer => 'נחתם על ידי';

  @override
  String get settings_conflict_ref_sourceDive => 'צלילת מקור';

  @override
  String get settings_conflict_ref_species => 'מינים';

  @override
  String get settings_conflict_ref_tag => 'תגית';

  @override
  String get settings_conflict_ref_tank => 'בלון';

  @override
  String get settings_conflict_ref_trip => 'טיול';

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
  String get settings_data_backup => 'גיבוי ושחזור';

  @override
  String get settings_data_backup_subtitle => 'צור גיבוי של הנתונים שלך';

  @override
  String get settings_data_cloudSync => 'סנכרון ענן של מסד נתונים';

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
  String get settings_decompression_header_oxygenToxicity => 'רעילות חמצן';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'בחר הגדרת שמרנות $presetName';
  }

  @override
  String get settings_decompression_header_narcosis => 'נרקוזה';

  @override
  String get settings_decompression_o2Narcotic => 'O2 נרקוטי';

  @override
  String get settings_decompression_o2Narcotic_subtitle =>
      'כאשר מופעל, גם O2 וגם N2 נחשבים נרקוטיים (שמרני יותר). כאשר מושבת, רק N2 תורם לנרקוזה.';

  @override
  String get settings_decompression_endLimit => 'מגבלת END';

  @override
  String get settings_decompression_endLimit_subtitle =>
      'עומק נרקוטי שווה ערך מרבי המשמש לחישובי MND';

  @override
  String get settings_decompression_endLimit_dialog_title => 'מגבלת END';

  @override
  String get settings_decompression_cnsMethodTitle => 'חישוב CNS';

  @override
  String get settings_decompression_cnsMethodClassic =>
      'טבלת NOAA, מדורגת (קלאסי)';

  @override
  String get settings_decompression_cnsMethodClassicDesc =>
      'מחשב כל תחום של 0.1 bar לפי הקצה המחמיר שלו. השיטה המקורית של Submersion.';

  @override
  String get settings_decompression_cnsMethodShearwater =>
      'אינטרפולציה לינארית (בסגנון Shearwater)';

  @override
  String get settings_decompression_cnsMethodShearwaterDesc =>
      'מבצע אינטרפולציה בין גבולות NOAA כפי שמתועד על ידי Shearwater. תואם את רוב מחשבי הצלילה.';

  @override
  String get settings_decompression_cnsMethodSubsurface =>
      'התאמה מעריכית (כמו Subsurface)';

  @override
  String get settings_decompression_cnsMethodSubsurfaceDesc =>
      'התאמת עקומה חלקה לטבלת NOAA. תואם את ה-CNS המחושב של Subsurface.';

  @override
  String get settings_decompression_cnsMethodAboutTitle => 'אודות שיטות אלה';

  @override
  String get settings_decompression_cnsMethodAboutBody =>
      'שלוש השיטות מבוססות על גבולות החשיפה לחמצן שבמדריך הצלילה של NOAA (300 דקות ב-ppO2 של 1.0 bar, 45 דקות ב-1.6 bar). הטבלה מגדירה גבולות רק בצעדים של 0.1 bar: השיטה הקלאסית מחשבת את כל מה שנמצא בתוך תחום לפי הקצה המחמיר של התחום, ובכך מעריכה ביתר באופן שיטתי את החשיפה שבין הערכים. מחשבי הצלילה של Shearwater מתעדים אינטרפולציה לינארית בין גבולות NOAA, עם 15% קבועים לדקה מעל 1.65 bar. בשנת 2019 החליפה Subsurface את חיפוש הטבלה שלה בהתאמה מעריכית חלקה בשני מקטעים לאותם נתוני NOAA (Robert C. Helling), שגם מתרחבת באופן טבעי מעבר ל-1.6 bar. בין ערכי הטבלה שתי השיטות החלקות תואמות זו את זו בהפרש של כנקודת CNS אחת בקירוב; השיטה הקלאסית מציגה ערכים גבוהים יותר.';

  @override
  String get settings_decompression_cnsMethodDisclaimer =>
      'השמות מתייחסים לשיטות שפורסמו של הפרויקטים והיצרנים המתאימים; אין בכך כדי לרמז על שיוך או חסות. ערכים מחושבים עשויים להיות שונים מהקריאות בפועל של מחשב הצלילה.';

  @override
  String get settings_decompression_cnsMethodSourcesTitle => 'מקורות';

  @override
  String get settings_linkOpenFailed => 'לא ניתן לפתוח את הקישור.';

  @override
  String get settings_decompression_cnsMethodSourceNoaa =>
      'NOAA: Diving Program (המוציא לאור של NOAA Diving Manual)';

  @override
  String get settings_decompression_cnsMethodSourceShearwater =>
      'Shearwater: שעון החמצן של CNS';

  @override
  String get settings_decompression_cnsMethodSourceTheoreticalDiver =>
      'The Theoretical Diver: חישוב רעילות חמצן CNS';

  @override
  String get settings_decompression_cnsMethodSourceSubsurface =>
      'Subsurface: מימוש (divelist.cpp)';

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
  String get settings_import_cancelButton => 'ביטול ייבוא';

  @override
  String get settings_import_cancelling => 'מבטל...';

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
  String get settings_import_phase_courses => 'Importing courses...';

  @override
  String get settings_import_phase_applyingTags => 'Applying tags...';

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
  String get settings_lightroom_albumFilter_all => 'כל הקטלוג';

  @override
  String get settings_lightroom_albumFilter_title => 'אלבומים לסריקה';

  @override
  String get settings_lightroom_autoPoll_title =>
      'בדיקה אוטומטית של תמונות חדשות';

  @override
  String settings_lightroom_clientId_help(String redirectUri) {
    return 'צרו אינטגרציה ב-Adobe Developer Console עם Lightroom Services API וסוג אישור התומך ב-PKCE. הזינו למטה את כתובת ההפניה של האישור שלכם — אישורי Native App משתמשים בסכימה מותאמת אישית — או השאירו ריק כדי להשתמש ב-$redirectUri.';
  }

  @override
  String get settings_lightroom_clientId_label => 'מזהה לקוח של Adobe';

  @override
  String get settings_lightroom_clientSecret_label => 'סוד לקוח (אופציונלי)';

  @override
  String get settings_lightroom_redirectUri_label => 'כתובת הפניה (אופציונלי)';

  @override
  String get settings_lightroom_connect => 'חיבור Lightroom';

  @override
  String get settings_lightroom_connectEmbedded => 'התחברות עם Adobe';

  @override
  String get settings_lightroom_advancedByo => 'שימוש בפרטי הכניסה שלך ב-Adobe';

  @override
  String get settings_lightroom_connect_codeLabel => 'כתובת URL מופנית או קוד';

  @override
  String get settings_lightroom_connect_emptyCode =>
      'הדביקו את כתובת ה-URL המופנית או את קוד ההרשאה';

  @override
  String settings_lightroom_connect_failed(String error) {
    return 'לא ניתן להתחבר ל-Lightroom: $error';
  }

  @override
  String get settings_lightroom_connect_instructions =>
      'התחברו ל-Adobe בחלון הדפדפן, ואז הדביקו את הכתובת המלאה של הדף שאליו הגעתם (היא מכילה את קוד ההרשאה).';

  @override
  String get settings_lightroom_connect_reopenBrowser => 'פתיחת הדפדפן מחדש';

  @override
  String get settings_lightroom_connect_submit => 'חיבור';

  @override
  String get settings_lightroom_connect_title => 'חיבור Lightroom';

  @override
  String settings_lightroom_connected(String name) {
    return 'מחובר בתור $name';
  }

  @override
  String get settings_lightroom_disconnect => 'ניתוק';

  @override
  String get settings_lightroom_disconnect_confirmBody =>
      'תמונות מקושרות נשארות בצלילות שלכם וממשיכות להיות מוצגות מאחסון המדיה. תמונות חדשות לא יותאמו יותר.';

  @override
  String get settings_lightroom_disconnect_confirmTitle => 'לנתק את Lightroom?';

  @override
  String settings_lightroom_lastPoll(String when) {
    return 'בדיקה אחרונה: $when';
  }

  @override
  String get settings_lightroom_needsReauth => 'נדרש חיבור מחדש';

  @override
  String get settings_lightroom_scanNow => 'סריקת Lightroom';

  @override
  String get settings_lightroom_scan_running => 'סורק את Lightroom...';

  @override
  String settings_lightroom_scan_summary(
    int attached,
    int suggested,
    int skipped,
  ) {
    return '$attached קושרו, $suggested הוצעו, $skipped כבר מקושרות';
  }

  @override
  String get settings_lightroom_subtitle =>
      'קישור אוטומטי של תמונות וסרטונים לצלילות';

  @override
  String get settings_lightroom_title => 'Adobe Lightroom';

  @override
  String get settings_manage_checklistTemplates => 'תבניות רשימות משימות';

  @override
  String get settings_manage_checklistTemplates_subtitle =>
      'רשימות משימות לשימוש חוזר לתכנון טיולים';

  @override
  String get settings_manage_diveRoles => 'תפקידי צלילה';

  @override
  String get settings_manage_diveRoles_subtitle =>
      'ניהול תפקידי צלילה מותאמים אישית';

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
  String get settings_manage_tags => 'תגיות';

  @override
  String get settings_manage_tags_subtitle => 'ניהול, מיזוג ומחיקת תגיות';

  @override
  String get settings_manage_tankPresets => 'הגדרות בלון מוכנות';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'ניהול תצורות בלון מותאמות אישית';

  @override
  String get settings_manage_serviceTypes => 'סוגי טיפול';

  @override
  String get settings_manage_serviceTypes_subtitle =>
      'הטיפולים שהציוד שלך צריך, ובאיזו תדירות';

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
  String get settings_notifications_disabled_continueButton => 'המשך';

  @override
  String get settings_notifications_disabled_openSettingsButton => 'פתח הגדרות';

  @override
  String get settings_notifications_disabled_subtitleUnrequested =>
      'תזכורות שירות דורשות הרשאה לשליחת התראות';

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
  String get settings_profileHub_addNewDiver => 'הוסף צולל חדש';

  @override
  String get settings_profileHub_cannotDeleteOnly =>
      'לא ניתן למחוק את פרופיל הצולל היחיד';

  @override
  String get settings_profileHub_createDiverTitle => 'צור צולל';

  @override
  String settings_profileHub_deleteConfirmContent(String name) {
    return 'האם אתה בטוח שברצונך למחוק את $name? כל יומני הצלילה המשויכים יבוטלו.';
  }

  @override
  String get settings_profileHub_deleteConfirmTitle => 'למחוק צולל?';

  @override
  String get settings_profileHub_deleteDiver => 'מחק צולל';

  @override
  String get settings_profileHub_deleted => 'הצולל נמחק';

  @override
  String get settings_profileHub_emergencyContacts => 'אנשי קשר לחירום';

  @override
  String settings_profileHub_emergencyContacts_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count אנשי קשר',
      one: 'איש קשר אחד',
      zero: 'לא הוגדר',
    );
    return '$_temp0';
  }

  @override
  String get settings_profileHub_insurance => 'ביטוח';

  @override
  String get settings_profileHub_insurance_expired => 'פג תוקף';

  @override
  String get settings_profileHub_insurance_notSet => 'לא הוגדר';

  @override
  String get settings_profileHub_medicalInfo => 'מידע רפואי';

  @override
  String get settings_profileHub_medicalInfo_notSet => 'לא הוגדר';

  @override
  String get settings_profileHub_notes => 'הערות';

  @override
  String get settings_profileHub_notes_notSet => 'לא הוגדר';

  @override
  String get settings_profileHub_personalInfo => 'מידע אישי';

  @override
  String get settings_profileHub_personalInfo_notSet => 'לא הוגדר';

  @override
  String get settings_profileHub_saved => 'השינויים נשמרו';

  @override
  String get settings_profileHub_switchDiver => 'החלף צולל';

  @override
  String get settings_s3Config_action_remove => 'הסרת התצורה';

  @override
  String get settings_s3Config_action_testConnection => 'בדיקת חיבור';

  @override
  String get settings_s3Config_advanced_title => 'מתקדם';

  @override
  String get settings_s3Config_appBar_title => 'אחסון תואם S3';

  @override
  String get settings_s3Config_error_secureStorage =>
      'לא ניתן לגשת לאחסון המאובטח';

  @override
  String get settings_s3Config_field_accessKeyId_label => 'Access Key ID';

  @override
  String get settings_s3Config_field_bucket_label => 'Bucket';

  @override
  String get settings_s3Config_field_endpoint_helper =>
      'לדוגמה: https://s3.example.com';

  @override
  String get settings_s3Config_field_endpoint_label =>
      'כתובת URL של נקודת הקצה';

  @override
  String get settings_s3Config_field_pathStyle_label =>
      'שימוש במיעון path-style';

  @override
  String get settings_s3Config_field_pathStyle_subtitle =>
      'נדרש על ידי רוב השרתים באירוח עצמי';

  @override
  String get settings_s3Config_field_prefix_label => 'קידומת מפתחות';

  @override
  String settings_s3Config_field_region_helperAuto(String region) {
    return 'זוהה אוטומטית: $region';
  }

  @override
  String get settings_s3Config_field_region_label => 'אזור';

  @override
  String get settings_s3Config_field_secretAccessKey_label =>
      'Secret Access Key';

  @override
  String get settings_s3Config_remove_confirm_action => 'הסרה';

  @override
  String get settings_s3Config_remove_confirm_body =>
      'הסנכרון דרך S3 ייפסק במכשיר זה. הנתונים שלכם ב-bucket לא יימחקו.';

  @override
  String get settings_s3Config_remove_confirm_title => 'להסיר את תצורת S3?';

  @override
  String get settings_s3Config_removed => 'תצורת S3 הוסרה';

  @override
  String get settings_s3Config_saved => 'תצורת S3 נשמרה';

  @override
  String settings_s3Config_test_regionDetected(String region) {
    return 'זוהה אזור: $region';
  }

  @override
  String get settings_s3Config_test_success => 'החיבור הצליח';

  @override
  String get settings_s3Config_validation_endpointInvalid =>
      'יש להזין כתובת http:// או https:// תקינה';

  @override
  String get settings_s3Config_validation_endpointPath =>
      'כתובת ה-URL של נקודת הקצה לא יכולה לכלול נתיב';

  @override
  String get settings_s3Config_validation_required => 'שדה חובה';

  @override
  String get settings_s3Config_warning_http =>
      'נקודת קצה זו משתמשת ב-HTTP לא מוצפן. פרטי הגישה ונתוני הצלילה יועברו ללא הצפנה; השתמשו רק ברשת מהימנה.';

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
  String get settings_storage_customFolder_subtitleDeviceOnly =>
      'העברת מסד הנתונים לאחסון הפנימי או לכרטיס SD';

  @override
  String get settings_storage_customFolder_deviceOnly_noCloudSync =>
      'סנכרון הענן המנוהל על ידי האפליקציה מושבת כל עוד מסד הנתונים נמצא באחסון המכשיר. ב-Android אף שירות סנכרון אינו יכול להגיע לתיקייה הזו, לכן השתמשו בגיבוי ושחזור כדי לשמור עותקים במקום אחר.';

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
  String get settings_storage_dangerZone => 'אזור סכנה';

  @override
  String get settings_storage_resetDatabase => 'איפוס מסד נתונים';

  @override
  String get settings_storage_resetDatabase_subtitle =>
      'מחק את כל הנתונים במכשיר זה והתחל מחדש';

  @override
  String get settings_storage_resetDialog_title => 'לאפס את מסד הנתונים?';

  @override
  String get settings_storage_resetDialog_body =>
      'פעולה זו מוחקת לצמיתות את כל הנתונים במכשיר הזה, כולל צלילות, אתרים, ציוד והגדרות. גיבוי נוצר אוטומטית לפני האיפוס.\n\nספריית הענן שלך לא נמחקת, ומכשירים אחרים שומרים על הנתונים שלהם. סנכרון הענן ינותק כדי שהאיפוס לא יבוטל; ניתן לחבר אותו מחדש בהגדרות > סנכרון ענן.';

  @override
  String get settings_storage_resetDialog_confirmWord => 'מחיקה';

  @override
  String get settings_storage_resetDialog_confirmHint =>
      'הקלד \"מחיקה\" לאישור';

  @override
  String get settings_storage_resetDialog_confirmButton => 'איפוס';

  @override
  String get settings_storage_resetDialog_backupFailed =>
      'הגיבוי נכשל. האיפוס בוטל כדי להגן על הנתונים שלך.';

  @override
  String settings_storage_resetDialog_resetFailed(Object error) {
    return 'האיפוס נכשל: $error';
  }

  @override
  String get settings_storage_resetComplete_title => 'איפוס מסד נתונים';

  @override
  String get settings_storage_resetComplete_description =>
      'הנתונים במכשיר זה נמחקו וגיבוי נשמר. סנכרון הענן מנותק כעת כדי שהאיפוס לא יבוטל; ניתן לחבר אותו מחדש בהגדרות > סנכרון ענן. הקש על המשך כדי לטעון מחדש את האפליקציה.';

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
  String get settings_units_gasModel => 'חישובי גז';

  @override
  String get settings_units_gasModel_real => 'גז ממשי';

  @override
  String get settings_units_gasModel_real_subtitle =>
      'מתחשב בדחיסות. מיכל 12 ליטר ב-200 בר מכיל כ-2317 ליטר.';

  @override
  String get settings_units_gasModel_ideal => 'גז אידיאלי';

  @override
  String get settings_units_gasModel_ideal_subtitle =>
      'תואם לחישוב ידני ולטבלאות צלילה. מיכל 12 ליטר ב-200 בר מכיל 2400 ליטר.';

  @override
  String get settings_units_gasModel_explanation =>
      'כיצד לחץ המיכל מומר לנפח גז. משפיע על קצב צריכת האוויר, סטטיסטיקות הגז, המתכנן ומחשבוני הגז. גז אידיאלי תואם לחישוב שמלמדים ארגוני ההסמכה; גז ממשי מדויק פיזיקלית ומציג קצב צריכה נמוך בכ-5%.';

  @override
  String get settings_units_dialog_gasModel => 'חישובי גז';

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
  String get settings_units_defaultCurrency => 'מטבע ברירת מחדל';

  @override
  String get settings_units_dialog_defaultCurrency => 'מטבע ברירת מחדל';

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
  String get settings_updates_automaticUpdates => 'עדכונים אוטומטיים';

  @override
  String get settings_updates_automaticUpdatesSubtitle =>
      'בדיקת עדכונים מעת לעת';

  @override
  String get settings_updates_betaDialogBody =>
      'גרסאות בטא מתפרסמות מכל שינוי ועשויות לשדרג את מסד הנתונים של יומן הצלילה שלך לפני הגרסה היציבה. חזרה מאוחר יותר לערוץ היציב לא תחזיר את האפליקציה לגרסה קודמת, וכל המכשירים שמסתנכרנים יחד צריכים להשתמש באותו ערוץ. גיבוי נוצר אוטומטית לפני כל שדרוג של מסד הנתונים.';

  @override
  String get settings_updates_betaDialogConfirm => 'מעבר לבטא';

  @override
  String get settings_updates_betaDialogTitle => 'לקבל עדכוני בטא?';

  @override
  String get settings_updates_channel => 'ערוץ עדכונים';

  @override
  String settings_updates_channelBadgeBeta(String version) {
    return '$version (בטא)';
  }

  @override
  String get settings_updates_channelBeta => 'בטא';

  @override
  String get settings_updates_channelBetaSubtitle =>
      'גרסאות חדשות מכל שינוי, לפני היציבה';

  @override
  String get settings_updates_channelStable => 'יציב';

  @override
  String get settings_updates_channelStableSubtitle => 'גרסאות שנבדקו בלבד';

  @override
  String get settings_updates_checkForUpdates => 'בדוק אם יש עדכונים';

  @override
  String get settings_updates_checking => 'בודק...';

  @override
  String settings_updates_downloading(String progress) {
    return 'מוריד... $progress%';
  }

  @override
  String settings_updates_error(String message) {
    return 'שגיאה: $message';
  }

  @override
  String get settings_updates_header => 'עדכונים';

  @override
  String get settings_updates_joinBeta => 'הצטרפות לבטא';

  @override
  String get settings_updates_joinBetaSubtitle =>
      'קבל תכונות חדשות מוקדם דרך תוכנית הבטא';

  @override
  String get settings_updates_lastChecked => 'בדיקה אחרונה';

  @override
  String get settings_updates_never => 'אף פעם';

  @override
  String settings_updates_readyToInstall(String version) {
    return 'גרסה $version מוכנה להתקנה';
  }

  @override
  String get settings_updates_stableSwitchNotice =>
      'תישאר בגרסת הבטא הזו עד שהגרסה היציבה הבאה תהיה חדשה ממנה.';

  @override
  String get settings_updates_upToDate => 'מעודכן';

  @override
  String settings_updates_versionAvailable(String version) {
    return 'גרסה $version זמינה';
  }

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
  String get statistics_category_overview_title => 'Overview';

  @override
  String get statistics_category_overview_subtitle =>
      'Totals, records, and breakdowns at a glance';

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
  String get statistics_filterBar_clear => 'ניקוי מסנן';

  @override
  String statistics_filterBar_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות',
      one: 'צלילה אחת',
    );
    return '$_temp0';
  }

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
  String get statistics_profile_deco_notRecorded => 'לא נרשם';

  @override
  String statistics_profile_deco_notRecordedHint(int count) {
    return 'ל-$count צלילות אין נתוני דקומפרסיה שנרשמו או שניתן לחשב, והן אינן נכללות בשיעור';
  }

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
  String get statistics_tooltip_filter => 'סינון סטטיסטיקות';

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
  String surfaceInterval_gasWarning_modExceeded(
    Object ppO2,
    Object depth,
    Object limit,
    Object mod,
  ) {
    return 'ppO₂ $ppO2 בעומק $depth חורג מ-$limit. ה-MOD של תערובת זו הוא $mod.';
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
  String surfaceInterval_result_beyondHorizon(Object hours) {
    return 'ההמתנה חורגת מ-$hours השעות שמתכנן זה מחפש. הסילוק ממשיך, ולכן מרווח שטח ארוך יותר יספיק.';
  }

  @override
  String surfaceInterval_result_beyondHorizonShort(Object hours) {
    return 'יותר מ-$hours שעות';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'מרווח נוכחי';

  @override
  String get surfaceInterval_result_gasUnsafe => 'הגז אינו בטוח בעומק זה';

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
  String surfaceInterval_result_noIntervalHelps(Object minutes) {
    return 'שום מרווח שטח אינו מספיק. הצלילה הארוכה ביותר ללא דקומפרסיה בעומק זה עם תערובת זו היא $minutes דקות. קצר את הצלילה השנייה או הקטן את עומקה.';
  }

  @override
  String get surfaceInterval_result_notAchievable =>
      'לא ניתן להשגה בשום מרווח שטח';

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
  String surfaceInterval_secondDive_heSemantics(Object percent) {
    return 'הליום צלילה שנייה: $percent%';
  }

  @override
  String surfaceInterval_secondDive_o2Semantics(Object percent) {
    return 'חמצן צלילה שנייה: $percent%';
  }

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
  String get tags_action_browse => 'עיון';

  @override
  String get tags_picker_title => 'בחירת תגיות';

  @override
  String get tags_picker_empty =>
      'אין עדיין תגיות. הקלד שם תגית כדי ליצור את הראשונה.';

  @override
  String tags_picker_errorLoading(String error) {
    return 'שגיאה בטעינת התגיות: $error';
  }

  @override
  String get tags_picker_allAdded => 'כל התגיות כבר נוספו.';

  @override
  String get tags_picker_noMatches => 'אין תגיות התואמות לחיפוש שלך.';

  @override
  String tags_picker_addCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הוספת $count תגיות',
      one: 'הוספת תגית אחת',
      zero: 'הוספת תגיות',
    );
    return '$_temp0';
  }

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
  String get importWizard_tagsLabel => 'Tags';

  @override
  String get importWizard_photos_stepLabel => 'תמונות';

  @override
  String importWizard_photos_foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תמונות מוזכרות ביומן הזה',
      one: 'תמונה אחת מוזכרת ביומן הזה',
    );
    return '$_temp0';
  }

  @override
  String get importWizard_photos_chooseFolder => 'בחר תיקיית תמונות...';

  @override
  String get importWizard_photos_scanning => 'סורק את התיקייה...';

  @override
  String importWizard_photos_matchSummary(
    int matched,
    int byName,
    int missing,
  ) {
    return '$matched הותאמו, $byName לפי שם קובץ בלבד, $missing לא נמצאו';
  }

  @override
  String get importWizard_photos_skip => 'דלג על התמונות';

  @override
  String get importWizard_photos_mobileUnsupported =>
      'ייבוא תמונות מחייב תיקייה בדיסק של המכשיר הזה. הרץ את הייבוא במחשב כדי לכלול אותן. צלילות ואתרים מיובאים כרגיל.';

  @override
  String importWizard_review_olderDivesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות ישנות דולגו — כבר ביומן שלך',
      one: 'צלילה ישנה אחת דולגה — כבר ביומן שלך',
    );
    return '$_temp0';
  }

  @override
  String get tags_hint_addTags => 'הוסף תגיות...';

  @override
  String get tags_manage_title => 'תגיות';

  @override
  String get tags_manage_searchHint => 'חיפוש תגיות...';

  @override
  String tags_manage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות',
      one: 'צלילה אחת',
      zero: '0 צלילות',
    );
    return '$_temp0';
  }

  @override
  String get tags_manage_emptyState => 'אין עדיין תגיות. צור אחת כדי להתחיל.';

  @override
  String tags_manage_selectedCount(int count) {
    return '$count נבחרו';
  }

  @override
  String get tags_manage_createTitle => 'צור תגית';

  @override
  String get tags_manage_editTitle => 'ערוך תגית';

  @override
  String get tags_manage_nameLabel => 'שם תגית';

  @override
  String get tags_manage_colorLabel => 'צבע';

  @override
  String get tags_manage_nameRequired => 'שם תגית נדרש';

  @override
  String get tags_manage_deleteTitle => 'למחוק תגית?';

  @override
  String tags_manage_deleteMessage(String tagName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות',
      one: 'צלילה אחת',
      zero: '0 צלילות',
    );
    return '\"$tagName\" תוסר מ-$_temp0. לא ניתן לבטל פעולה זו.';
  }

  @override
  String tags_manage_bulkDeleteTitle(int count) {
    return 'למחוק $count תגיות?';
  }

  @override
  String tags_manage_bulkDeleteMessage(int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount צלילות',
      one: 'צלילה אחת',
      zero: '0 צלילות',
    );
    return 'תגיות אלו יוסרו מ-$_temp0 בסך הכל. לא ניתן לבטל פעולה זו.';
  }

  @override
  String tags_manage_mergeTitle(int count) {
    return 'מזג $count תגיות';
  }

  @override
  String get tags_manage_mergeResultName => 'שם התגית שייווצר:';

  @override
  String get tags_manage_mergeKeepFrom => 'או שמור שם מ:';

  @override
  String tags_manage_mergeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות',
      one: 'צלילה אחת',
      zero: '0 צלילות',
    );
    return 'פעולה זו תשפיע על $_temp0 בסך הכל.';
  }

  @override
  String get tags_manage_mergeAction => 'מיזוג';

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
  String tides_source_noaaStation(String name, String distance) {
    return 'תחנת NOAA: $name ($distance)';
  }

  @override
  String get tides_source_modelEstimate => 'אומדן מודל אוקיינוס';

  @override
  String get tides_source_modelCaveat =>
      'מבוסס על נתוני לוויין. זמנים וגבהים עשויים להיות שונים ליד קווי חוף מורכבים.';

  @override
  String get tides_source_sheetTitle => 'מקור נתוני הגאות';

  @override
  String get tides_source_datumMllw => 'גבהים ביחס ל-MLLW (ייחוס התחנה)';

  @override
  String get tides_source_datumMsl => 'גבהים ביחס לגובה פני הים הממוצע';

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
      'Import dives via Apple HealthKit';

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
  String transfer_computers_diveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות',
      one: 'צלילה אחת',
    );
    return '$_temp0';
  }

  @override
  String get transfer_computers_downloadTooltip => 'הורדת צלילות';

  @override
  String get transfer_computers_knownComputersHeader => 'מחשבים מוכרים';

  @override
  String transfer_computers_lastDownloadDaysAgo(int days) {
    return 'לפני $days ימים';
  }

  @override
  String transfer_computers_lastDownloadHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'לפני $hours שעות',
      one: 'לפני שעה',
    );
    return '$_temp0';
  }

  @override
  String transfer_computers_lastDownloadMinutesAgo(int minutes) {
    return 'לפני $minutes דק\'';
  }

  @override
  String get transfer_computers_lastDownloadNever => 'אף פעם';

  @override
  String get transfer_computers_lastDownloadYesterday => 'אתמול';

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
  String get transfer_export_backupLink => 'עבור לגיבוי ושחזור';

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
  String get transfer_import_fileImportSemanticLabel =>
      'ייבא נתונים עם זיהוי אוטומטי';

  @override
  String get transfer_import_fileImportSubtitle =>
      'מזהה אוטומטית CSV, UDDF, FIT ועוד';

  @override
  String get transfer_import_fileImportTitle => 'ייבוא נתונים';

  @override
  String get transfer_import_sectionHeader => 'ייבוא נתונים';

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
  String get trips_detail_stat_totalRuntime => 'סה\"כ זמן ריצה';

  @override
  String get trips_detail_stat_totalDives => 'סה\"כ צלילות';

  @override
  String get trips_detail_tab_checklist => 'רשימת משימות';

  @override
  String get trips_detail_tooltip_edit => 'ערוך טיול';

  @override
  String get trips_detail_tooltip_editShort => 'עריכה';

  @override
  String get trips_detail_tooltip_moreOptions => 'אפשרויות נוספות';

  @override
  String get trips_detail_tooltip_viewOnMap => 'הצג על המפה';

  @override
  String trips_diveScan_addButton(int count) {
    return 'הוסף $count צלילות';
  }

  @override
  String trips_diveScan_added(int count) {
    return 'נוספו $count צלילות לטיול';
  }

  @override
  String get trips_diveScan_cancel => 'ביטול';

  @override
  String trips_diveScan_currentTrip(String tripName) {
    return 'כרגע ב: $tripName';
  }

  @override
  String get trips_diveScan_deselectAll => 'בטל בחירת הכל';

  @override
  String trips_diveScan_error(String error) {
    return 'שגיאה בחיפוש צלילות: $error';
  }

  @override
  String get trips_diveScan_findButton => 'מצא צלילות תואמות';

  @override
  String trips_diveScan_groupOtherTrips(int count) {
    return 'בטיולים אחרים ($count)';
  }

  @override
  String trips_diveScan_groupUnassigned(int count) {
    return 'לא משויכות ($count)';
  }

  @override
  String get trips_diveScan_noMatches => 'לא נמצאו צלילות תואמות';

  @override
  String get trips_diveScan_noDiver => 'בחר צולל פעיל כדי לסרוק אחר צלילות';

  @override
  String get trips_diveScan_selectAll => 'בחר הכל';

  @override
  String trips_diveScan_subtitle(int count) {
    return 'נמצאו $count צלילות בטווח התאריכים';
  }

  @override
  String get trips_diveScan_title => 'הוסף צלילות לטיול';

  @override
  String get trips_diveScan_unknownSite => 'אתר לא ידוע';

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
  String get trips_edit_label_returnFlight => 'טיסת חזרה';

  @override
  String get trips_edit_returnFlightClear => 'נקה טיסת חזרה';

  @override
  String get trips_edit_returnFlightNotSet => 'לא הוגדר';

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
  String trips_list_countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'בעוד $days ימים',
      one: 'בעוד יום אחד',
      zero: 'מתחיל היום',
    );
    return '$_temp0';
  }

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
  String get trips_list_inProgress => 'בעיצומו';

  @override
  String get trips_list_pastSection => 'טיולים קודמים';

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
  String get trips_list_upcomingSection => 'קרובים';

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
  String get universalImport_action_consolidate => 'איחוד כמחשב צלילה נוסף';

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
  String get universalImport_action_changeFile => 'שנה קובץ';

  @override
  String get universalImport_action_selectFile => 'בחר קובץ';

  @override
  String get universalImport_action_selectFiles => 'בחירת קבצים';

  @override
  String get universalImport_action_chooseFolder => 'בחירת תיקייה';

  @override
  String get universalImport_triage_title => 'קבצים לייבוא';

  @override
  String universalImport_triage_readyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count קבצים מוכנים לייבוא',
      one: 'קובץ אחד מוכן לייבוא',
    );
    return '$_temp0';
  }

  @override
  String universalImport_label_filesSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נבחרו $count קבצים',
      one: 'נבחר קובץ אחד',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_triage_excludedCsv => 'ייבוא נפרד (CSV)';

  @override
  String get universalImport_triage_unsupported => 'פורמט לא נתמך';

  @override
  String get universalImport_triage_parseFailed => 'לא ניתן לקרוא';

  @override
  String universalImport_triage_parsing(int current, int total) {
    return 'מנתח קובץ $current מתוך $total…';
  }

  @override
  String get universalImport_triage_cancelParsing => 'ביטול';

  @override
  String get universalImport_triage_allExcluded =>
      'לא ניתן לייבא יחד את הקבצים שנבחרו. יש לייבא קובצי CSV אחד אחד.';

  @override
  String get universalImport_triage_noneImportable =>
      'לא ניתן לייבא אף אחד מהקבצים שנבחרו.';

  @override
  String get universalImport_review_inBatchDuplicate =>
      'כפילות של צלילה אחרת באצוות הייבוא הזו.';

  @override
  String get universalImport_summary_filesTitle => 'קבצים';

  @override
  String get universalImport_summary_noticesTitle => 'לא נמצא בקובץ';

  @override
  String get universalImport_summary_noticeNoTankPressureTitle =>
      'לחץ המכל לא נרשם';

  @override
  String get universalImport_summary_noticeNoTankPressureBody =>
      'לא ניתן לחשב צריכת אוויר ו-SAC. אפשר להוסיף לחץ התחלה וסיום בעריכת הצלילה.';

  @override
  String universalImport_summary_noticeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'משפיע על $count צלילות',
      one: 'משפיע על צלילה אחת',
    );
    return '$_temp0';
  }

  @override
  String universalImport_summary_fileImported(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות יובאו',
      one: 'צלילה אחת יובאה',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_summary_fileNeedsIndividualImport =>
      'נדרש ייבוא נפרד';

  @override
  String get universalImport_summary_fileUnsupported => 'פורמט לא נתמך';

  @override
  String get universalImport_summary_fileParseFailed => 'הקריאה נכשלה';

  @override
  String universalImport_bulk_consolidateMatched(int count) {
    return 'איחוד מתאימים ($count)';
  }

  @override
  String universalImport_bulk_importAll(int count) {
    return 'ייבוא הכל ($count)';
  }

  @override
  String universalImport_bulk_importAllAsNew(int count) {
    return 'ייבוא הכל כחדש ($count)';
  }

  @override
  String universalImport_bulk_skipAll(int count) {
    return 'דלג על הכל ($count)';
  }

  @override
  String universalImport_bulk_replaceSourceAll(int count) {
    return 'החלף הכול ($count)';
  }

  @override
  String get universalImport_description_supportedFormats =>
      'בחר קובץ יומן צלילה לייבוא. פורמטים נתמכים כוללים CSV, UDDF, Subsurface XML ו-Garmin FIT.';

  @override
  String get universalImport_dive_decideAction => 'החלט';

  @override
  String get universalImport_error_unsupportedFormat =>
      'פורמט זה אינו נתמך עדיין. נא לייצא כ-UDDF או CSV.';

  @override
  String get universalImport_label_columnMapping => 'מיפוי עמודות';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped מתוך $total עמודות ממופות';
  }

  @override
  String get universalImport_label_consolidate => 'איחוד';

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
  String get universalImport_label_importAsNew => 'ייבוא כחדש';

  @override
  String get universalImport_label_importComplete => 'ייבוא הושלם';

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
  String get universalImport_entityAction_linkBadge => 'קישור';

  @override
  String get universalImport_entityAction_linkExisting => 'קישור לקיים';

  @override
  String get universalImport_entityAction_linkExistingSubtitle =>
      'שימוש ברשומה התואמת';

  @override
  String get universalImport_entityAction_replaceBadge => 'החלפה';

  @override
  String get universalImport_entityAction_replaceExisting => 'החלף את הקיים';

  @override
  String get universalImport_entityAction_replaceExistingSubtitle =>
      'דרוס בנתונים המיובאים';

  @override
  String get universalImport_entityAction_skip => 'דלג';

  @override
  String get universalImport_entityAction_skipSubtitle => 'בטל ייבוא זה';

  @override
  String get universalImport_entityAction_importAsNew => 'ייבוא כחדש';

  @override
  String get universalImport_entityAction_importAsNewSubtitle =>
      'צור רשומה נפרדת';

  @override
  String get universalImport_pending_chooseAction => 'בחר פעולה';

  @override
  String universalImport_pending_gateHint(int count) {
    return '$count כפילויות דורשות החלטה';
  }

  @override
  String get universalImport_pending_needsDecision => 'נדרשת החלטה';

  @override
  String get universalImport_pending_reviewAction => 'סקור';

  @override
  String get universalImport_rowHint_tapCompareToDecide =>
      'הקש על החלט כדי לבחור';

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
  String get universalImport_semantics_needsDecision =>
      'כפילות חשודה, נדרשת החלטה';

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
  String universalImport_snackbar_bulkMarkedAs(int count, String action) {
    return '$count סומנו כ-$action';
  }

  @override
  String universalImport_snackbar_markedAs(String action) {
    return 'סומן כ-$action';
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
  String get universalImport_summary_decidesRequired =>
      'כל אחד דורש החלטה לפני הייבוא.';

  @override
  String get universalImport_title => 'ייבא נתונים';

  @override
  String get universalImport_tooltip_closeWizard => 'סגור אשף ייבוא';

  @override
  String weather_windFromDirection(Object wind, Object direction) {
    return '$wind מכיוון $direction';
  }

  @override
  String get weather_wind_calm => 'רגוע';

  @override
  String get weather_wind_highWind => 'רוח עזה';

  @override
  String get weather_wind_lightBreeze => 'רוח קלה';

  @override
  String get weather_wind_moderateBreeze => 'רוח מתונה';

  @override
  String get weather_wind_strongBreeze => 'רוח חזקה';

  @override
  String get weather_wmo_clear => 'שמים בהירים';

  @override
  String get weather_wmo_drizzle => 'טפטוף';

  @override
  String get weather_wmo_fog => 'ערפל';

  @override
  String get weather_wmo_freezingDrizzle => 'טפטוף קופא';

  @override
  String get weather_wmo_freezingRain => 'גשם קופא';

  @override
  String get weather_wmo_mainlyClear => 'בהיר ברובו';

  @override
  String get weather_wmo_overcast => 'מעונן';

  @override
  String get weather_wmo_partlyCloudy => 'מעונן חלקית';

  @override
  String get weather_wmo_rain => 'גשם';

  @override
  String get weather_wmo_rainShowers => 'ממטרי גשם';

  @override
  String get weather_wmo_snow => 'שלג';

  @override
  String get weather_wmo_snowGrains => 'גרגרי שלג';

  @override
  String get weather_wmo_snowShowers => 'ממטרי שלג';

  @override
  String get weather_wmo_thunderstorm => 'סופת רעמים';

  @override
  String get weather_wmo_thunderstormHail => 'סופת רעמים עם ברד';

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
  String get diveComputer_connectionType_ble => 'Bluetooth LE';

  @override
  String get diveComputer_connectionType_bluetooth => 'Bluetooth';

  @override
  String get diveComputer_connectionType_infrared => 'אינפרא אדום';

  @override
  String get diveComputer_connectionType_unknown => 'לא ידוע';

  @override
  String get diveComputer_connectionType_usb => 'USB';

  @override
  String get diveComputer_connectionType_wifi => 'Wi-Fi';

  @override
  String diveComputer_detail_deleteDialogContent(String name) {
    return 'האם אתה בטוח שברצונך להסיר את \"$name\"? פעולה זו לא תמחק צלילות שיובאו ממחשב זה.';
  }

  @override
  String get diveComputer_detail_deleteDialogTitle => 'למחוק את המחשב?';

  @override
  String get diveComputer_detail_divesImported => 'צלילות שיובאו';

  @override
  String get diveComputer_detail_downloadDivesButton => 'הורד צלילות';

  @override
  String get diveComputer_detail_editDialogTitle => 'ערוך מחשב';

  @override
  String get diveComputer_detail_editNameHint => 'לדוגמה, ה-Perdix שלי';

  @override
  String get diveComputer_detail_editNotesHint => 'הערות אופציונליות';

  @override
  String get diveComputer_detail_labelConnection => 'חיבור';

  @override
  String get diveComputer_detail_labelManufacturer => 'יצרן';

  @override
  String get diveComputer_detail_labelModel => 'דגם';

  @override
  String get diveComputer_detail_labelName => 'שם';

  @override
  String get diveComputer_detail_lastDownload => 'הורדה אחרונה';

  @override
  String get diveComputer_detail_notesTitle => 'הערות';

  @override
  String get diveComputer_detail_reimportAllButton => 'ייבא מחדש את כל הצלילות';

  @override
  String diveComputer_detail_reimportDialogBody(String computerName) {
    return 'הורד כל צלילה מ־$computerName והשווה אותן ליומן שלך. פעולה זו עשויה להימשך מספר דקות.';
  }

  @override
  String get diveComputer_detail_reimportDialogTitle =>
      'לייבא מחדש את כל הצלילות?';

  @override
  String get diveComputer_detail_statisticsTitle => 'סטטיסטיקה';

  @override
  String get diveComputer_detail_unknown => 'לא ידוע';

  @override
  String get diveComputer_detail_viewDivesButton => 'צפה בצלילות ממחשב זה';

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
  String get diveComputer_discovery_usbInstructions =>
      'חבר את מחשב הצלילה שלך באמצעות כבל USB, ואז בחר אותו למטה.';

  @override
  String diveComputer_discovery_usbNoResults(String query) {
    return 'לא נמצאו מכשירים עבור \"$query\"';
  }

  @override
  String get diveComputer_discovery_usbSearchHint => 'חיפוש לפי יצרן או דגם...';

  @override
  String get diveComputer_downloadExit_content =>
      'יציאה תבטל את ההורדה הנוכחית ממחשב הצלילה. האם אתה בטוח?';

  @override
  String get diveComputer_downloadExit_leave => 'עזוב';

  @override
  String get diveComputer_downloadExit_stay => 'הישאר';

  @override
  String get diveComputer_downloadExit_title => 'הורדה בתהליך';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... ועוד $count';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'ביטול';

  @override
  String get diveComputer_downloadStep_cancelled => 'ההורדה בוטלה';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadAll => 'הורדת כל הצלילות';

  @override
  String get diveComputer_downloadStep_downloadFailed => 'ההורדה נכשלה';

  @override
  String get diveComputer_downloadStep_downloadNew => 'הורדת צלילות חדשות';

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
  String get diveComputer_downloadStep_firstSyncBody =>
      'ביומן הצלילות שלך כבר יש צלילות. אפשר לדלג על הורדת הצלילות שכבר יש לך.';

  @override
  String get diveComputer_downloadStep_firstSyncTitle =>
      'הורדה ראשונה ממחשב הצלילה הזה';

  @override
  String diveComputer_downloadStep_onlyAfterDate(String date) {
    return 'הורדת צלילות אחרי $date בלבד';
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
  String diveComputer_downloadStep_importPartialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ייבוא $count צלילות שהורדו',
      one: 'ייבוא צלילה אחת שהורדה',
    );
    return '$_temp0';
  }

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
  String get diveComputer_download_noSerialPortsFound =>
      'לא נמצאו חיבורי USB טוריים. האם מחשב הצלילה מחובר ופועל?';

  @override
  String get diveComputer_download_stalePairing =>
      'התאמת ה-Bluetooth של מחשב הצלילה הזה אינה עדכנית. שכח את מחשב הצלילה בהגדרות ה-Bluetooth של המכשיר שלך, ולאחר מכן התאם אותו מחדש מתפריט ה-Bluetooth של מחשב הצלילה.';

  @override
  String get diveComputer_download_discoveryStalled =>
      'ההתחברות למחשב הצלילה הצליחה, אך הוא הפסיק להגיב לפני תחילת ההורדה. בדרך כלל המשמעות היא שהתאמת ה-Bluetooth אינה עדכנית: שכח את מחשב הצלילה בהגדרות ה-Bluetooth של המכשיר שלך ונסה שוב.';

  @override
  String diveComputer_download_serialConnectFailedWithDetails(Object details) {
    return 'לא ניתן להתחבר למחשב הצלילה.\n\nפרטי אבחון (שתפו עם המפתחים):\n$details';
  }

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
  String diveComputer_download_importingCountDives(int count) {
    return 'מייבא $count צלילות...';
  }

  @override
  String diveComputer_download_importingCountNewDives(int count) {
    return 'מייבא $count צלילות חדשות...';
  }

  @override
  String get diveComputer_download_newDivesImported => 'צלילות חדשות יובאו';

  @override
  String get diveComputer_download_newDivesOnlySubtitle =>
      'מוריד רק צלילות שנוספו מאז הסנכרון האחרון';

  @override
  String get diveComputer_download_newDivesOnlyTitle =>
      'הורד צלילות חדשות בלבד';

  @override
  String get diveComputer_download_preparing => 'מכין...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_reimportHint =>
      'מחפש צלילות ישנות או שנמחקו? ייבא מחדש את הכול';

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
  String get diveComputer_download_upToDate =>
      'לא נמצאו צלילות חדשות -- היומן שלך מעודכן';

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
  String get diveComputer_pinCode_instructions =>
      'הזן את הקוד המוצג במחשב הצלילה.';

  @override
  String get diveComputer_pinCode_label => 'קוד PIN';

  @override
  String get diveComputer_pinCode_submit => 'שלח';

  @override
  String get diveComputer_pinCode_title => 'נדרש קוד PIN';

  @override
  String get diveComputer_pinEntry_connectButton => 'התחבר';

  @override
  String get diveComputer_pinEntry_helperText =>
      'הזן את ה-PIN בן 4-6 הספרות המוצג במכשיר';

  @override
  String get diveComputer_pinEntry_instructionsGeneric =>
      'בדוק את תצוגת מחשב הצלילה לקבלת קוד ה-PIN.';

  @override
  String diveComputer_pinEntry_instructionsWithDevice(String deviceName) {
    return 'בדוק את תצוגת $deviceName לקבלת קוד ה-PIN.';
  }

  @override
  String get diveComputer_pinEntry_semanticLabel =>
      'הזנת קוד PIN, 4 עד 6 ספרות';

  @override
  String get diveComputer_pinEntry_title => 'הזן קוד PIN';

  @override
  String diveComputer_scan_bluetoothSemanticLabel(String name) {
    return 'התקן Bluetooth: $name';
  }

  @override
  String get diveComputer_scan_emptyStateInstructions =>
      'ודא שמחשב הצלילה שלך:\n• דלוק\n• במצב התאמת Bluetooth\n• קרוב למכשיר שלך';

  @override
  String get diveComputer_scan_knownBadge => 'מוכר';

  @override
  String get diveComputer_scan_lookingForDevicesTitle => 'מחפש התקנים';

  @override
  String get diveComputer_scan_noUsbDevicesAvailable => 'אין התקני USB זמינים';

  @override
  String get diveComputer_scan_retry => 'נסה שוב';

  @override
  String get diveComputer_scan_scanAgain => 'סרוק שוב';

  @override
  String get diveComputer_scan_scanningStatus => 'סורק מחשבי צלילה...';

  @override
  String get diveComputer_scan_stopScanning => 'הפסק סריקה';

  @override
  String get diveComputer_scan_supportedBadge => 'נתמך';

  @override
  String get diveComputer_scan_tabBluetooth => 'Bluetooth';

  @override
  String get diveComputer_scan_tabUsb => 'כבל USB';

  @override
  String get diveComputer_scan_usbCableLabel => 'כבל USB';

  @override
  String diveComputer_scan_usbSemanticLabel(String model) {
    return 'התקן USB: $model';
  }

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
      'Submersion uses Apple HealthKit to read underwater diving workout data, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get diveImport_healthkit_accessRequired => 'Apple HealthKit';

  @override
  String get diveImport_healthkit_attribution => 'מופעל על ידי Apple HealthKit';

  @override
  String get diveImport_healthkit_closeTooltip => 'סגור ייבוא Apple Watch';

  @override
  String get diveImport_healthkit_dataUsage =>
      'קורא פעילויות צלילה תת-ימיות מ-Apple Health, כולל עומק, משך, טמפרטורת מים ודופק. נתונים אלה מאוחסנים מקומית ביומן הצלילה שלך ולעולם אינם משותפים עם צדדים שלישיים.';

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
  String get diveImport_healthkit_grantAccess => 'המשך';

  @override
  String get diveImport_healthkit_noDivesFound => 'לא נמצאו צלילות';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'לא נמצאו פעילויות צלילה תת-ימיות בטווח התאריכים שנבחר.';

  @override
  String get diveImport_healthkit_notAvailable => 'לא זמין';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'ייבוא מ-Apple Watch מחייב אייפון עם אפליקציית הבריאות.';

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
  String get diveImport_uddf_media => 'תמונות';

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
  String get divePlanner_undo => 'בטל';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'Rock Bottom הוא מינימום עתודת הגז הנדרש לעלייה חירומית תוך שיתוף אוויר עם השותף שלך.\n\n• משתמש בקצבי RMV במצב לחץ (2-3 כפול מהרגיל)\n• מניח ששני הצוללים על מיכל אחד\n• כולל עצירת בטיחות כשמופעלת\n\nתמיד סיים את הצלילה לפני שמגיעים ל-Rock Bottom!';

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
  String get gasCalculators_rockBottom_buddySac => 'RMV השותף';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'RMV משולב במצב לחץ';

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
      'השתמש ב-RMV גבוה יותר לפיצוי על לחץ במצב חירום';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'RMV במצב לחץ';

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
  String get gasCalculators_rockBottom_yourSac => 'ה-RMV שלך';

  @override
  String get gpsLogger_androidNotificationText => 'מקליט את מסלול פני המים';

  @override
  String get gpsLogger_androidNotificationTitle => 'מקליט ה-GPS של Submersion';

  @override
  String get gpsLogger_deleteTrackMessage =>
      'פעולה זו תסיר את מסלול ה-GPS שהוקלט. מיקומים שכבר הוצמדו לצלילות יישמרו.';

  @override
  String get gpsLogger_deleteTrackTitle => 'למחוק את המסלול?';

  @override
  String get gpsLogger_interruptedNotice => 'הקלטה קודמת נקטעה. המסלול נשמר.';

  @override
  String gpsLogger_lastFix(String age, String accuracy) {
    return 'איתור אחרון לפני $age ($accuracy)';
  }

  @override
  String get gpsLogger_locationOff => 'שירותי המיקום כבויים.';

  @override
  String get gpsLogger_matchButton => 'התאמת צלילות ליומני GPS';

  @override
  String gpsLogger_matchResult(int count) {
    return '$count צלילות מוקמו';
  }

  @override
  String get gpsLogger_matchResultNone => 'אף צלילה לא תואמת מסלול שהוקלט';

  @override
  String get gpsLogger_noFixYet => 'ממתין לאות GPS';

  @override
  String get gpsLogger_noTracks => 'עדיין לא הוקלטו מסלולי GPS';

  @override
  String get gpsLogger_permissionDenied =>
      'נדרשת הרשאת מיקום כדי להקליט מסלול GPS. יש להפעיל אותה בהגדרות המערכת.';

  @override
  String gpsLogger_recordingStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count נקודות',
      two: 'שתי נקודות',
      one: 'נקודה אחת',
    );
    return 'מקליט - $_temp0';
  }

  @override
  String get gpsLogger_reviewSites => 'סקירת התאמות אתרי צלילה';

  @override
  String get gpsLogger_startButton => 'התחל הקלטה';

  @override
  String get gpsLogger_stopButton => 'עצור הקלטה';

  @override
  String gpsLogger_stripStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count נקודות',
      two: 'שתי נקודות',
      one: 'נקודה אחת',
    );
    return 'מקליט מסלול GPS · $_temp0';
  }

  @override
  String get gpsLogger_summary_tracks => 'מסלולים';

  @override
  String get gpsLogger_summary_recordedTime => 'זמן מוקלט';

  @override
  String get gpsLogger_summary_divesCovered => 'צלילות מכוסות';

  @override
  String gpsLogger_trackSubtitle(num count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count נקודות',
      two: 'שתי נקודות',
      one: 'נקודה אחת',
    );
    return '$_temp0, $duration';
  }

  @override
  String gpsLogger_trackSubtitleTrimmed(String duration) {
    return 'נחתך, $duration';
  }

  @override
  String get gpsLogger_tracksHeader => 'מסלולים שהוקלטו';

  @override
  String get gpsTrack_action_trim => 'חיתוך...';

  @override
  String get gpsTrack_action_split => 'פיצול...';

  @override
  String get gpsTrack_action_resetTrim => 'איפוס החיתוך';

  @override
  String get gpsTrack_edit_applyTrim => 'החל חיתוך';

  @override
  String get gpsTrack_edit_confirmSplit => 'פצל כאן';

  @override
  String get gpsTrack_edit_splitWarning =>
      'פיצול יוצר שני מסלולים ומוחק את המקורי. לא ניתן לבטל פעולה זו.';

  @override
  String get gpsTrack_edit_cancel => 'ביטול';

  @override
  String get gpsTrack_import_action => 'ייבוא מסלול...';

  @override
  String get gpsTrack_import_reviewTitle => 'בדיקת ייבוא';

  @override
  String get gpsTrack_import_timezone => 'הוקלט באזור';

  @override
  String get gpsTrack_import_timezoneHint =>
      'הזמנים בקובץ הם UTC. בחר את אזור הזמן שבו הוקלט המסלול כדי שיתאים לצלילות שלך.';

  @override
  String get gpsTrack_import_duplicate => 'נראה שזהו כפיל של מסלול קיים.';

  @override
  String get gpsTrack_import_confirm => 'ייבוא';

  @override
  String get gpsTrack_import_csvMapping => 'התאמת עמודות';

  @override
  String get gpsTrack_import_firstFix => 'נקודה ראשונה';

  @override
  String gpsTrack_import_fixCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count נקודות',
      two: 'שתי נקודות',
      one: 'נקודה אחת',
    );
    return '$_temp0';
  }

  @override
  String gpsTrack_import_failed(String reason) {
    return 'לא ניתן לקרוא את הקובץ: $reason';
  }

  @override
  String get gpsTrack_importError_unsupportedFormat =>
      'סוג הקובץ אינו נתמך. ייבא קובץ GPX, KML, CSV או FIT.';

  @override
  String get gpsTrack_importError_unreadable =>
      'לא ניתן לקרוא את הקובץ. ייתכן שהוא פגום או חלקי.';

  @override
  String get gpsTrack_importError_noPositions =>
      'בקובץ אין מיקומי GPS עם חותמת זמן.';

  @override
  String get gpsTrack_importError_badData =>
      'בקובץ יש מיקום או חותמת זמן שהאפליקציה אינה יכולה לקרוא.';

  @override
  String get gpsTrack_export_saved => 'המסלול נשמר';

  @override
  String get gpsTrack_action_export => 'ייצוא';

  @override
  String get gpsTrack_action_shareGpx => 'שיתוף כ-GPX';

  @override
  String get gpsTrack_action_saveGpx => 'שמירה כ-GPX...';

  @override
  String get gpsTrack_action_shareKml => 'שיתוף כ-KML';

  @override
  String get gpsTrack_action_saveKml => 'שמירה כ-KML...';

  @override
  String get gpsTrack_export_failed => 'הייצוא נכשל.';

  @override
  String get gpsTrack_map_title => 'מפת מסלולים';

  @override
  String gpsTrack_map_truncated(int count) {
    return 'מוצגים $count המסלולים האחרונים. צמצם את מסנן התאריכים כדי לראות אחרים.';
  }

  @override
  String get gpsTrack_map_noTracks => 'אין מסלולים מוקלטים להצגה.';

  @override
  String get gpsTrack_map_showMap => 'הצג מפה';

  @override
  String get gpsTrack_filter_all => 'כל התאריכים';

  @override
  String get gpsTrack_filter_clear => 'נקה סינון תאריכים';

  @override
  String get gpsTrack_inspect_speed => 'מהירות';

  @override
  String get gpsTrack_inspect_accuracy => 'דיוק';

  @override
  String get gpsTrack_stats_distance => 'מרחק';

  @override
  String get gpsTrack_stats_duration => 'משך';

  @override
  String get gpsTrack_stats_avgSpeed => 'מהירות ממוצעת';

  @override
  String get gpsTrack_stats_maxSpeed => 'מהירות מרבית';

  @override
  String get gpsTrack_stats_fixes => 'נקודות';

  @override
  String get gpsTrack_stats_dives => 'צלילות';

  @override
  String get gpsTrack_colorMode_uniform => 'אחיד';

  @override
  String get gpsTrack_colorMode_speed => 'מהירות';

  @override
  String get gpsTrack_colorMode_elapsed => 'זמן';

  @override
  String get gpsTrack_legend_slower => 'אטי יותר';

  @override
  String get gpsTrack_legend_faster => 'מהיר יותר';

  @override
  String get gpsTrack_legend_start => 'התחלה';

  @override
  String get gpsTrack_legend_end => 'סוף';

  @override
  String get gpsTrack_detail_title => 'מסלול GPS';

  @override
  String get gpsTrack_detail_notFound => 'מסלול זה אינו זמין עוד.';

  @override
  String get gpsTrack_detail_unreadable => 'לא ניתן היה לקרוא את נתוני המסלול.';

  @override
  String get gpsTrack_detail_noPoints => 'למסלול זה אין מיקומים מוקלטים.';

  @override
  String get maps_compass_resetLabel => 'איפוס כיוון המפה לצפון';

  @override
  String get maps_compass_resetTooltip => 'צפון למעלה';

  @override
  String get maps_heatMap_hide => 'הסתר מפת חום';

  @override
  String get maps_heatMap_overlayOff => 'שכבת מפת חום כבויה';

  @override
  String get maps_depthOverlay_show => 'הצגת שכבת עומק';

  @override
  String get maps_depthOverlay_hide => 'הסתרת שכבת עומק';

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
  String get maps_offline_downloadNewRegion => 'הורד אזור חדש';

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
  String get tankPresets_currentDefault => 'ברירת מחדל נוכחית';

  @override
  String get tankPresets_customPresets => 'תבניות מותאמות אישית';

  @override
  String get tankPresets_defaultSettings => 'מיכל ברירת מחדל';

  @override
  String get tankPresets_defaultSettings_description =>
      'התבנית המסומנת בכוכב משמשת כמיכל ברירת מחדל בעת רישום צלילות חדשות.';

  @override
  String tankPresets_deleteDefaultMessage(String name) {
    return 'האם אתה בטוח שברצונך למחוק את \"$name\"? זוהי תבנית מיכל ברירת המחדל הנוכחית שלך ותאופס ל-AL80.';
  }

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
  String get tankPresets_applyToImports => 'החל גם על צלילות מיובאות';

  @override
  String get tankPresets_applyToImports_subtitle =>
      'השלם נתוני מיכל חסרים בצלילות מיובאות באמצעות תבנית ברירת המחדל';

  @override
  String get tankPresets_new_title => 'תבנית מיכל חדשה';

  @override
  String get tankPresets_noPresets => 'אין תבניות מיכל זמינות';

  @override
  String get tankPresets_setAsDefault => 'הגדר כברירת מחדל';

  @override
  String get tankPresets_title => 'תבניות מיכל';

  @override
  String get tools_gpsLogger_description =>
      'הקלט את מיקומך במהלך יום צלילה והתאם אוטומטית צלילות מיובאות למיקומי GPS.';

  @override
  String get tools_gpsLogger_subtitle => 'הקלטת מסלול פני המים';

  @override
  String get tools_gpsLogger_title => 'מקליט GPS';

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

  @override
  String get settings_section_dataSources_title => 'Data Sources';

  @override
  String get settings_section_dataSources_subtitle =>
      'Connected services & integrations';

  @override
  String get settings_siteMatch_title => 'התאמת אתרים אוטומטית';

  @override
  String get settings_siteMatch_subtitle =>
      'באיזו מידה צלילות שהורדו מותאמות לאתרים';

  @override
  String get settings_siteMatch_strict => 'קפדני';

  @override
  String get settings_siteMatch_balanced => 'מאוזן';

  @override
  String get settings_siteMatch_relaxed => 'גמיש';

  @override
  String get settings_dataSources_header => 'Data Sources';

  @override
  String get settings_dataSources_appleHealth_title => 'Apple Health';

  @override
  String get settings_dataSources_appleHealth_subtitle => 'נתוני צלילה תת-ימית';

  @override
  String get settings_dataSources_appleHealth_description =>
      'Submersion reads underwater diving workout data from Apple Health, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get settings_dataSources_appleHealth_dataTypesHeader =>
      'נתונים הנקראים מ-HealthKit';

  @override
  String get settings_dataSources_appleHealth_dataTypeWorkouts =>
      'אימוני צלילה תת-ימית - שעת התחלה, משך ונתוני פעילות של הצלילה';

  @override
  String get settings_dataSources_appleHealth_dataTypeHeartRate =>
      'דופק - דגימות דופק שנרשמו במהלך צלילות';

  @override
  String get settings_dataSources_appleHealth_permissionGranted =>
      'גישה ל-HealthKit אושרה';

  @override
  String get settings_dataSources_appleHealth_permissionNotGranted =>
      'גישה ל-HealthKit לא אושרה';

  @override
  String get settings_dataSources_appleHealth_permissionChecking =>
      'בודק גישה ל-HealthKit...';

  @override
  String get settings_dataSources_appleHealth_importAction =>
      'Import from Apple Watch';

  @override
  String get settings_dataSources_appleHealth_privacy =>
      'Your health data is stored locally and is never shared with third parties.';

  @override
  String get settings_dataSources_appleHealth_poweredBy =>
      'מופעל על ידי Apple HealthKit';

  @override
  String get settings_dataSources_noSources =>
      'No data source integrations are available on this platform.';

  @override
  String get diveLog_edit_section_environment => 'סביבה';

  @override
  String get diveLog_edit_subsection_autofill => 'מילוי אוטומטי';

  @override
  String get diveLog_edit_subsection_weather => 'מזג אוויר';

  @override
  String get diveLog_edit_subsection_diveConditions => 'תנאי צלילה';

  @override
  String get diveLog_edit_label_windSpeed => 'מהירות רוח';

  @override
  String get diveLog_edit_label_windDirection => 'כיוון רוח';

  @override
  String get diveLog_edit_label_cloudCover => 'כיסוי עננים';

  @override
  String get diveLog_edit_label_precipitation => 'משקעים';

  @override
  String get diveLog_edit_label_humidity => 'לחות';

  @override
  String get diveLog_edit_label_weatherDescription => 'תיאור מזג האוויר';

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
  String get diveLog_detail_section_environment => 'סביבה';

  @override
  String get diveLog_detail_subsection_weather => 'מזג אוויר';

  @override
  String get diveLog_detail_subsection_diveConditions => 'תנאי צלילה';

  @override
  String get diveLog_detail_label_windSpeed => 'מהירות רוח';

  @override
  String get diveLog_detail_label_windDirection => 'כיוון רוח';

  @override
  String get diveLog_detail_label_cloudCover => 'כיסוי עננים';

  @override
  String get diveLog_detail_label_precipitation => 'משקעים';

  @override
  String get diveLog_detail_label_humidity => 'לחות';

  @override
  String get diveLog_detail_label_weatherDescription => 'תיאור';

  @override
  String get diveLog_detail_weatherSourceOpenMeteo => 'via Open-Meteo';

  @override
  String get dropTarget_title => 'שחרר לייבוא';

  @override
  String get dropTarget_subtitle => 'שחרר כדי לפתוח את אשף הייבוא';

  @override
  String get dropTarget_error_unsupportedFile => 'סוג קובץ לא נתמך';

  @override
  String get dropTarget_error_wizardActive => 'סיים את הייבוא הנוכחי קודם';

  @override
  String get dropTarget_error_readFailed => 'לא ניתן לקרוא את הקובץ';

  @override
  String get enum_cloudCover_clear => 'בהיר';

  @override
  String get enum_cloudCover_partlyCloudy => 'מעונן חלקית';

  @override
  String get enum_cloudCover_mostlyCloudy => 'מעונן ברובו';

  @override
  String get enum_cloudCover_overcast => 'מעונן';

  @override
  String get enum_precipitation_none => 'ללא';

  @override
  String get enum_precipitation_drizzle => 'טפטוף';

  @override
  String get enum_precipitation_lightRain => 'גשם קל';

  @override
  String get enum_precipitation_rain => 'גשם';

  @override
  String get enum_precipitation_heavyRain => 'גשם כבד';

  @override
  String get enum_precipitation_snow => 'שלג';

  @override
  String get enum_precipitation_sleet => 'גשם קפוא';

  @override
  String get enum_precipitation_hail => 'ברד';

  @override
  String get columnConfig_title => 'שדות רשימת פרטי צלילות';

  @override
  String get columnConfig_viewMode => 'מצב תצוגה';

  @override
  String get columnConfig_visibleColumns => 'עמודות גלויות';

  @override
  String get columnConfig_availableFields => 'שדות זמינים';

  @override
  String get columnConfig_extraFields => 'שדות נוספים';

  @override
  String get columnConfig_extraFields_description =>
      'מוצגים מתחת לתוכן הכרטיס הראשי';

  @override
  String get columnConfig_slotAssignments => 'הקצאות משבצות';

  @override
  String get columnConfig_resetToDefault => 'איפוס לברירת מחדל';

  @override
  String get columnConfig_preset => 'הגדרה מוגדרת מראש';

  @override
  String get columnConfig_presetSaveAs => 'שמירה בשם';

  @override
  String get columnConfig_presetName => 'שם ההגדרה';

  @override
  String get columnConfig_presetNameHint => 'לדוגמה: צלילה טכנית';

  @override
  String get columnConfig_presetSave => 'שמור';

  @override
  String get columnConfig_presetCancel => 'ביטול';

  @override
  String get columnConfig_columns => 'עמודות';

  @override
  String get columnConfig_done => 'סיום';

  @override
  String get settings_appearance_columnConfig => 'שדות רשימת פרטי צלילות';

  @override
  String get settings_appearance_columnConfig_subtitle =>
      'התאמה אישית של שדות המוצגים בתצוגות רשימת הצלילות';

  @override
  String get diveField_category_core => 'ליבה';

  @override
  String get diveField_category_environment => 'סביבה';

  @override
  String get diveField_category_gas => 'גז';

  @override
  String get diveField_category_tank => 'מיכל';

  @override
  String get diveField_category_weight => 'משקולות';

  @override
  String get diveField_category_equipment => 'ציוד';

  @override
  String get diveField_category_deco => 'דקומפרסיה';

  @override
  String get diveField_category_physiology => 'פיזיולוגיה';

  @override
  String get diveField_category_rebreather => 'ריברידר';

  @override
  String get diveField_category_people => 'אנשים';

  @override
  String get diveField_category_location => 'מיקום';

  @override
  String get diveField_category_trip => 'טיול';

  @override
  String get diveField_category_rating => 'דירוג';

  @override
  String get diveField_category_metadata => 'מטא-נתונים';

  @override
  String get listViewMode_table => 'טבלה';

  @override
  String get settings_appearance_general => 'כללי';

  @override
  String get settings_appearance_sections => 'חלקים';

  @override
  String get settings_appearance_colorAccents => 'הדגשות צבע';

  @override
  String get settings_appearance_accentNavIcons => 'סמלי ניווט צבעוניים';

  @override
  String get settings_appearance_accentNavIcons_subtitle =>
      'צביעת סמלי התפריט הראשי בצבע של כל מדור';

  @override
  String get settings_appearance_accentSectionHeaders =>
      'כותרות מדורים צבעוניות';

  @override
  String get settings_appearance_accentSectionHeaders_subtitle =>
      'הצגת סמל מדור צבעוני לצד כותרות הדפים';

  @override
  String get settings_appearance_accentListIcons => 'סמלי רשימה צבעוניים';

  @override
  String get settings_appearance_accentListIcons_subtitle =>
      'צביעת סמלים ברשימות ובדפי ההגדרות';

  @override
  String get settings_appearance_showDetailsPane => 'הצג חלונית פרטים';

  @override
  String get settings_appearance_showDetailsPane_subtitle =>
      'הצג חלונית פרטים לצד הטבלה';

  @override
  String get settings_appearance_showProfilePanel =>
      'הצג חלונית פרופיל בתצוגת טבלה';

  @override
  String get settings_appearance_showProfilePanel_subtitle =>
      'הצג תרשים פרופיל צלילה מעל הטבלה כברירת מחדל';

  @override
  String get settings_appearance_mapStyle => 'סגנון מפה';

  @override
  String get settings_appearance_mapStyle_openStreetMap => 'מפת רחובות';

  @override
  String get settings_appearance_mapStyle_openTopoMap => 'טופוגרפי';

  @override
  String get settings_appearance_mapStyle_esriSatellite => 'לוויין';

  @override
  String get common_action_reparse => 'נתח מחדש';

  @override
  String get diveComputer_detail_reparseAllButton => 'נתח מחדש את כל הצלילות';

  @override
  String get diveComputer_detail_reparseAllTitle => 'נתח מחדש את כל הצלילות';

  @override
  String diveComputer_detail_reparseAllMessage(int count) {
    return 'הפעל את מנתח הצלילות מחדש על $count צלילות שיש להן נתונים גולמיים שמורים. פעולה זו מעדכנת את נתוני הפרופיל והחיישנים אך שומרת על ההערות, האתרים, השותפים ושאר העריכות.';
  }

  @override
  String diveComputer_detail_reparseAllProgress(int count) {
    return 'מנתח מחדש $count צלילות...';
  }

  @override
  String diveComputer_detail_reparseAllSuccess(int count) {
    return 'נותחו מחדש $count צלילות בהצלחה';
  }

  @override
  String diveComputer_detail_reparseAllPartial(
    int succeeded,
    int total,
    int failed,
  ) {
    return 'נותחו מחדש $succeeded מתוך $total צלילות. $failed נכשלו.';
  }

  @override
  String diveComputer_detail_reparseRawDataCount(int count) {
    return '$count צלילות עם נתונים גולמיים';
  }

  @override
  String diveComputer_detail_reparseRawDataCountWithout(
    int count,
    int without,
  ) {
    return '$count צלילות עם נתונים גולמיים ($without ללא)';
  }

  @override
  String get diveLog_detail_menu_reparseRawData => 'נתח מחדש נתונים גולמיים';

  @override
  String get diveLog_detail_reparseSuccess => 'הצלילה נותחה מחדש בהצלחה';

  @override
  String get diveLog_detail_reparseProfilePreserved =>
      'פרטי המקור רועננו. צלילה זו אוחדה מצלילות אחרות, ולכן הפרופיל שלה נותר ללא שינוי.';

  @override
  String diveLog_detail_reparseFailed(String error) {
    return 'הניתוח מחדש נכשל: $error';
  }

  @override
  String get universalImport_label_replaceSource => 'החלף מקור';

  @override
  String get universalImport_label_replaceSourceSubtitle => 'עדכן מאותו מחשב';

  @override
  String get universalImport_title_importOptions => 'אפשרויות ייבוא';

  @override
  String get universalImport_label_options => 'אפשרויות';

  @override
  String get universalImport_label_retainDiveNumbers =>
      'שמור על מספרי הצלילה מהמקור';

  @override
  String get universalImport_label_retainDiveNumbersSubtitle =>
      'השתמש במספרי הצלילה מהקובץ המיובא במקום להקצות אוטומטית';

  @override
  String get universalImport_title_successImported => 'יובאו בהצלחה';

  @override
  String get universalImport_title_successUpdated => 'עודכנו בהצלחה';

  @override
  String get universalImport_title_successConsolidated => 'אוחדו בהצלחה';

  @override
  String get universalImport_title_noDivesImported => 'לא יובאו צלילות';

  @override
  String get universalImport_label_allDivesSkipped => 'כל הצלילות דולגו.';

  @override
  String get universalImport_label_replacedSourceData => 'נתוני מקור הוחלפו';

  @override
  String get universalImport_label_consolidated => 'אוחדו';

  @override
  String get universalImport_label_photosAttached => 'תמונות שצורפו';

  @override
  String get universalImport_label_photosUnmatched => 'תמונות ללא צלילה תואמת';

  @override
  String get common_label_shareWithAllProfiles => 'שיתוף עם כל פרופילי הצלילה';

  @override
  String get settings_shareByDefault_title =>
      'שתף אתרים וטיולים חדשים כברירת מחדל';

  @override
  String get settings_shareAllSites_title => 'שתף את כל האתרים שלי';

  @override
  String get settings_shareAllTrips_title => 'שתף את כל הטיולים שלי';

  @override
  String settings_shareAllSites_confirm(int count) {
    return 'להציג את כל $count האתרים שלך לכל פרופיל צלילה באפליקציה? תוכל לבטל שיתוף של אתרים בודדים בהמשך.';
  }

  @override
  String settings_shareAllTrips_confirm(int count) {
    return 'להציג את כל $count הטיולים שלך לכל פרופיל צלילה באפליקציה? תוכל לבטל שיתוף של טיולים בודדים בהמשך.';
  }

  @override
  String settings_shareAllSites_snackbar(int count) {
    return '$count אתרים שותפו עם כל פרופילי הצלילה.';
  }

  @override
  String settings_shareAllTrips_snackbar(int count) {
    return '$count טיולים שותפו עם כל פרופילי הצלילה.';
  }

  @override
  String get settings_shareAll_noneToShare => 'אין מה לשתף.';

  @override
  String get settings_sharedData_sectionTitle => 'נתונים משותפים';

  @override
  String get settings_sharedData_sectionSubtitle =>
      'שיתוף אתרים וטיולים בין פרופילים';

  @override
  String get common_action_unshare => 'ביטול שיתוף';

  @override
  String get trips_unshareConfirm_title => 'לבטל שיתוף של טיול זה?';

  @override
  String trips_unshareConfirm_body(String name) {
    return 'פעולה זו תסיר את «$name» מתצוגות של פרופילי צלילה אחרים. תוכל לשתף שוב בהמשך.';
  }

  @override
  String get sites_unshareConfirm_title => 'לבטל שיתוף של אתר זה?';

  @override
  String sites_unshareConfirm_body(String name) {
    return 'פעולה זו תסיר את «$name» מתצוגות של פרופילי צלילה אחרים. תוכל לשתף שוב בהמשך.';
  }

  @override
  String get trips_deleteShared_title => 'למחוק את הטיול המשותף?';

  @override
  String trips_deleteShared_body(String name) {
    return '«$name» משותף עם פרופילי צלילה אחרים. מחיקה כאן תסיר אותו עבור כולם.';
  }

  @override
  String get sites_deleteShared_title => 'למחוק את האתר המשותף?';

  @override
  String sites_deleteShared_body(String name) {
    return '«$name» משותף עם פרופילי צלילה אחרים. מחיקה כאן תסיר אותו עבור כולם.';
  }

  @override
  String divers_delete_reassigned_snackbar(int trips, int sites, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      trips,
      locale: localeName,
      other: 'טיולים משותפים הועברו',
      one: 'טיול משותף הועבר',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sites,
      locale: localeName,
      other: 'אתרים משותפים הועברו',
      one: 'אתר משותף הועבר',
    );
    return 'הצולל נמחק. $trips $_temp0 ו-$sites $_temp1 אל $name.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_title =>
      'פרופילי צוללים כפולים';

  @override
  String get settings_cloudSync_duplicateDivers_description =>
      'המזכור מצא יותר מפרופיל אחד עם אותו שם. זה קורה בדרך כלל כשכל מכשיר יצר פרופיל משלו לפני הסנכרון. המיזוג מעביר את כל הצלילות והנתונים לפרופיל אחד.';

  @override
  String settings_cloudSync_duplicateDivers_groupLabel(String name, int count) {
    return '$name ($count פרופילים)';
  }

  @override
  String get settings_cloudSync_duplicateDivers_mergeButton => 'מזג';

  @override
  String get settings_cloudSync_duplicateDivers_confirmTitle =>
      'למזג פרופילי צוללים?';

  @override
  String settings_cloudSync_duplicateDivers_confirmBody(
    int count,
    String name,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פרופילים כפולים',
      one: 'פרופיל כפול אחד',
    );
    return 'כל הצלילות, הסמכות, הציוד ושאר הנתונים מ-$_temp0 יועברו אל \"$name\". לא ניתן לבטל פעולה זו באופן אוטומטי.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_confirmCancel => 'ביטול';

  @override
  String get settings_cloudSync_duplicateDivers_confirmAction => 'מזג';

  @override
  String settings_cloudSync_duplicateDivers_successSnack(String name) {
    return 'מוזג אל $name';
  }

  @override
  String settings_cloudSync_duplicateDivers_failureSnack(String error) {
    return 'המיזוג נכשל: $error';
  }

  @override
  String get settings_cloudSync_duplicateDivers_undo => 'בטל';

  @override
  String get divers_edit_priorExperienceSection => 'ניסיון קודם';

  @override
  String get divers_edit_priorExperienceHelp =>
      'צלילות וזמן מהתקופה שלפני שהתחלת לתעד ב-Submersion.';

  @override
  String get divers_edit_priorDivesLabel => 'צלילות קודמות';

  @override
  String get divers_edit_priorHoursLabel => 'שעות קודמות';

  @override
  String get divers_edit_priorMinutesLabel => 'דקות';

  @override
  String get divers_edit_divingSinceLabel => 'צולל מאז';

  @override
  String get divers_edit_divingSinceNotSet => 'לא הוגדר';

  @override
  String get divers_edit_clearDivingSinceTooltip => 'נקה צולל מאז';

  @override
  String get divers_edit_priorInvalidNumber => 'הזן מספר תקין';

  @override
  String statistics_priorBreakdown(String logged, String prior) {
    return '$logged מתועדות + $prior קודמות';
  }

  @override
  String statistics_divingSince(int year) {
    return 'צולל מאז $year';
  }

  @override
  String get db_location_choose_volume => 'בחירת מיקום אחסון';

  @override
  String get db_location_internal => 'אחסון פנימי';

  @override
  String get db_location_sd_card => 'כרטיס SD';

  @override
  String get db_location_external_note =>
      'הקבצים כאן נמחקים אם מסירים את האפליקציה.';

  @override
  String get db_location_backup_note =>
      'Android אינו יכול להריץ את מסד הנתונים מתיקייה המסונכרנת בענן. כדי לשמור עותק ב-Dropbox, ב-Nextcloud או ב-Google Drive, הגדירו את מיקום הגיבוי תחת גיבוי ושחזור.';

  @override
  String diveLog_bulkEdit_membership_onAll(int count) {
    return 'בכל $count';
  }

  @override
  String diveLog_bulkEdit_membership_onSome(int count, int total) {
    return 'ב-$count מתוך $total';
  }

  @override
  String diveLog_bulkEdit_membership_adding(int total) {
    return 'מוסיף לכל $total';
  }

  @override
  String get diveLog_bulkEdit_membership_removing => 'מסיר מהכול';

  @override
  String get diveLog_bulkEdit_membership_empty =>
      'אין עדיין פריטים בצלילות שנבחרו';

  @override
  String get settings_mediaStorage_entry_title => 'אחסון מדיה';

  @override
  String get settings_mediaStorage_entry_subtitle =>
      'שמור מקורות של תמונות ווידאו באחסון הענן שלך';

  @override
  String get settings_mediaStorage_status_notConfigured =>
      'לא מחובר אחסון מדיה במכשיר זה';

  @override
  String settings_mediaStorage_status_connected(String hint) {
    return 'מחובר אל $hint';
  }

  @override
  String get settings_mediaStorage_test_success => 'החיבור הצליח';

  @override
  String get settings_mediaStorage_saved => 'אחסון המדיה חובר';

  @override
  String get settings_mediaStorage_action_disconnect => 'התנתק';

  @override
  String get settings_mediaStorage_disconnect_confirm_title =>
      'לנתק את אחסון המדיה?';

  @override
  String get settings_mediaStorage_disconnect_confirm_body =>
      'מכשיר זה יפסיק להעלות ולהוריד מדיה. שום דבר לא יימחק מהדלי שלך.';

  @override
  String get settings_mediaStorage_action_copyFromSync =>
      'העתק הגדרות מהסנכרון';

  @override
  String get settings_mediaStorage_transfers_title => 'העברות';

  @override
  String get settings_mediaStorage_transfers_entry => 'הצג העברות';

  @override
  String get settings_mediaStorage_transfers_empty => 'אין העברות';

  @override
  String get settings_mediaStorage_transfers_retry => 'נסה שוב';

  @override
  String get settings_mediaStorage_transfers_clearCompleted => 'נקה שהושלמו';

  @override
  String get settings_mediaStorage_transfers_state_pending => 'ממתין';

  @override
  String get settings_mediaStorage_transfers_state_transferring => 'מעלה';

  @override
  String get settings_mediaStorage_transfers_state_deleting => 'מסיר מהענן';

  @override
  String get settings_mediaStorage_transfers_state_done => 'הושלם';

  @override
  String get settings_mediaStorage_transfers_state_failed => 'נכשל';

  @override
  String settings_mediaStorage_transfers_queued(int count) {
    return '$count בתור';
  }

  @override
  String settings_mediaStorage_transfers_waitingRetry(int count) {
    return '$count ממתינים לניסיון חוזר';
  }

  @override
  String get settings_mediaStorage_verify_action => 'אימות הספרייה';

  @override
  String get settings_mediaStorage_verify_running => 'מאמת את ספריית המדיה...';

  @override
  String settings_mediaStorage_verify_summary(
    int checked,
    int removed,
    int repaired,
    int aborted,
  ) {
    return 'נבדקו $checked אובייקטים: הוסרו $removed יתומים, $repaired תיקונים נוספו לתור, $aborted העלאות ישנות בוטלו';
  }

  @override
  String get settings_mediaStorage_backfill_action => 'העלה ספריה קיימת';

  @override
  String settings_mediaStorage_backfill_enqueued(int count) {
    return '$count העלאות בתור';
  }

  @override
  String get settings_mediaStorage_policy_autoUpload => 'העלה תמונות אוטומטית';

  @override
  String get settings_mediaStorage_policy_photosOnCellular =>
      'העלה תמונות ברשת סלולרית';

  @override
  String get settings_mediaStorage_provider_label => 'ספק';

  @override
  String get settings_mediaStorage_connect_dropbox_hint =>
      'משתמש בחיבור Dropbox מסנכרון הענן. המדיה נשמרת בתיקיית האפליקציה ב-Dropbox.';

  @override
  String get settings_mediaStorage_connect_gdrive_hint =>
      'מתחבר עם Google. המדיה נשמרת בשטח ה-Drive הפרטי של האפליקציה.';

  @override
  String get settings_mediaStorage_connect_icloud_hint =>
      'המדיה נשמרת במיכל ה-iCloud של האפליקציה ומסתנכרנת דרך ה-Apple ID שלך.';

  @override
  String settings_mediaStorage_connect_action(String provider) {
    return 'חבר את $provider';
  }

  @override
  String get bodyWeight_addEntry => 'הוסף מדידה';

  @override
  String get bodyWeight_dateLabel => 'תאריך';

  @override
  String get bodyWeight_deleteTooltip => 'מחק רשומה';

  @override
  String get bodyWeight_heightLabel => 'גובה (ס״מ)';

  @override
  String get bodyWeight_heightFeetLabel => 'גובה (רגל)';

  @override
  String get bodyWeight_heightInchesLabel => 'אינץ\'';

  @override
  String bodyWeight_weightLabel(String unit) {
    return 'משקל ($unit)';
  }

  @override
  String diveLog_edit_weightFeedback_amount(String unit) {
    return 'בכמה בערך ($unit)';
  }

  @override
  String get diveLog_edit_weightFeedback_correct => 'הרגיש נכון';

  @override
  String get diveLog_edit_weightFeedback_label => 'איך היה המשקול שלך?';

  @override
  String get diveLog_edit_weightFeedback_over => 'משקל יתר';

  @override
  String get diveLog_edit_weightFeedback_under => 'תת-משקל';

  @override
  String get diverProfile_bodyWeight_empty => 'לא נרשם';

  @override
  String get diverProfile_bodyWeight_title => 'משקל גוף';

  @override
  String get equipment_edit_advanced_title => 'מתקדם';

  @override
  String get equipment_edit_buoyancyHint_exposure => 'חיובי: כמה הוא צף';

  @override
  String get equipment_edit_buoyancyHint_generic => 'שלילי אם הוא שוקע';

  @override
  String get equipment_edit_buoyancyHint_tank =>
      'השאר ריק - מכלים משתמשים במפרט משלהם';

  @override
  String equipment_edit_buoyancyLabel(String unit) {
    return 'ציפה ($unit)';
  }

  @override
  String equipment_edit_dryWeightLabel(String unit) {
    return 'משקל יבש ($unit)';
  }

  @override
  String equipment_edit_liftCapacityLabel(String unit) {
    return 'כושר ציפה ($unit)';
  }

  @override
  String get equipment_edit_liftCapacityHint =>
      'כוח הציפה הנקוב של האגף או המצוף';

  @override
  String get planner_gearWeights_accept => 'השתמש כמשקל מתוכנן';

  @override
  String get planner_gearWeights_addGear => 'הוסף ציוד';

  @override
  String get planner_gearWeights_empty => 'הוסף ציוד כדי לחזות את המשקול שלך';

  @override
  String planner_gearWeights_planned(String weight) {
    return 'מתוכנן: $weight';
  }

  @override
  String planner_gearWeights_predicted(String weight) {
    return 'חזוי: $weight';
  }

  @override
  String get planner_gearWeights_title => 'ציוד ומשקולות';

  @override
  String get planner_gearWeights_useSet => 'השתמש בערכה';

  @override
  String get tools_weight_addGear => 'הוסף ציוד';

  @override
  String get tools_weight_addTank => 'הוסף מכל';

  @override
  String tools_weight_basedOnDives(int count) {
    return 'מבוסס על $count צלילות מתועדות';
  }

  @override
  String get tools_weight_breakdownTitle => 'כיצד זה חושב';

  @override
  String get tools_weight_confidence_high => 'ודאות גבוהה';

  @override
  String get tools_weight_confidence_low => 'ודאות נמוכה - הערכה';

  @override
  String get tools_weight_confidence_medium => 'ודאות בינונית';

  @override
  String tools_weight_deltaVsPrevious(String delta) {
    return '$delta לעומת התצורה הקודמת';
  }

  @override
  String get tools_weight_noGear =>
      'הוסף את הציוד שאיתו תצלול כדי להתאים אישית את החיזוי.';

  @override
  String get tools_weight_personalTerm => 'בסיס אישי';

  @override
  String get tools_weight_placementTitle => 'מיקום מוצע';

  @override
  String get tools_weight_predictedWeight => 'משקל חזוי';

  @override
  String get tools_weight_saveToProfile => 'שמור משקל בפרופיל';

  @override
  String get tools_weight_source_measured => 'נמדד מהצלילות שלך';

  @override
  String get tools_weight_source_physics => 'פיזיקה';

  @override
  String get tools_weight_source_typeDefault => 'הערכת ברירת מחדל';

  @override
  String get tools_weight_source_userSpec => 'מהמפרט של הציוד שלך';

  @override
  String get tools_weight_tanks => 'מכלים';

  @override
  String get tools_weight_useSet => 'השתמש בערכה';

  @override
  String get tools_weight_waterTerm => 'סוג מים';

  @override
  String get dive3d_previewTitle => 'תצוגת תלת־ממד';

  @override
  String get dive3d_previewHint => 'הקש כדי לחקור בתלת־ממד';

  @override
  String get dive3d_resetView => 'איפוס תצוגה';

  @override
  String get dive3d_zoomIn => 'התקרבות';

  @override
  String get dive3d_zoomOut => 'התרחקות';

  @override
  String get dive3d_play => 'הפעלה';

  @override
  String get dive3d_pause => 'השהיה';

  @override
  String get dive3d_overlays => 'שכבות';

  @override
  String get dive3d_overlay_strata => 'שכבות טמפרטורה';

  @override
  String get dive3d_overlay_ceiling => 'תקרת דקומפרסיה';

  @override
  String get dive3d_overlay_curtain => 'וילון עומק';

  @override
  String get dive3d_overlay_markers => 'סמנים';

  @override
  String get dive3d_seascape_overlay_paths => 'מסלולי צלילה';

  @override
  String get dive3d_seascape_overlay_contours => 'קווי עומק';

  @override
  String get dive3d_seascape_overlay_walls => 'קירות תלולים';

  @override
  String get dive3d_overlay_water => 'פני המים';

  @override
  String get dive3d_seascape_legend_land => 'יבשה';

  @override
  String get dive3d_seascape_appearance => 'מראה פני השטח';

  @override
  String get dive3d_seascape_chartView => 'תצוגת מפה';

  @override
  String get dive3d_seascape_orbitView => 'תצוגת תלת-ממד';

  @override
  String get dive3d_seascape_appearance_surface => 'פני הקרקע';

  @override
  String get dive3d_seascape_appearance_surfaceDepth => 'צבעי עומק';

  @override
  String get dive3d_seascape_appearance_surfaceImagery => 'תמונות מפה';

  @override
  String get dive3d_seascape_appearance_surfaceBlend => 'שילוב';

  @override
  String get siteFeature_type_wreck => 'ספינה טרופה';

  @override
  String get siteFeature_type_mooring => 'מצוף עגינה';

  @override
  String get siteFeature_type_entry => 'נקודת כניסה';

  @override
  String get siteFeature_type_exit => 'נקודת יציאה';

  @override
  String get siteFeature_type_swimThrough => 'מעבר';

  @override
  String get siteFeature_type_hazard => 'סכנה';

  @override
  String get siteFeature_type_current => 'זרם';

  @override
  String get siteFeature_sectionTitle => 'מאפיינים';

  @override
  String get siteFeature_addAction => 'הוספת מאפיין';

  @override
  String get siteFeature_placeHint => 'הקישו על המפה למיקום המאפיין';

  @override
  String get siteFeature_addTitle => 'הוספת מאפיין';

  @override
  String get siteFeature_editTitle => 'עריכת מאפיין';

  @override
  String get siteFeature_field_name => 'שם';

  @override
  String get siteFeature_field_bearing => 'כיוון (°)';

  @override
  String get siteFeature_field_depth => 'עומק';

  @override
  String get siteFeature_field_notes => 'הערות';

  @override
  String get siteFeature_deleteAction => 'מחיקה';

  @override
  String siteFeature_deleteConfirm(String name) {
    return 'למחוק את $name?';
  }

  @override
  String get siteScape_mode2d => 'מפה';

  @override
  String get siteScape_mode3d => '3D';

  @override
  String get dive3d_seascape_appearance_rampRange => 'הגבלת טווח עומק הצבעים';

  @override
  String get dive3d_seascape_appearance_rampMax => 'הצבע הכהה ביותר בעומק';

  @override
  String get dive3d_seascape_appearance_banded => 'מעבר צבע במדרגות';

  @override
  String get dive3d_seascape_appearance_contours => 'רמות קווי עומק';

  @override
  String get dive3d_seascape_appearance_contourAuto => 'אוטומטי';

  @override
  String get dive3d_seascape_appearance_contourCustom => 'מותאם אישית';

  @override
  String get dive3d_seascape_appearance_addLevel => 'הוספת רמה';

  @override
  String get dive3d_seascape_appearance_defaultColor => 'ברירת מחדל';

  @override
  String get dive3d_seascape_appearance_wallAngle => 'זווית קיר תלול';

  @override
  String get dive3d_seascape_appearance_wallAngleNote =>
      'תאי מדידת עומק ממצעים את השיפוע שבתוכם, ולכן קירות אמיתיים נראים מתונים יותר. יש להישאר הרבה מתחת ל-45 מעלות.';

  @override
  String get dive3d_seascape_siteTitle => 'נוף ימי של האתר';

  @override
  String dive3d_seascape_seafloorSource(String source, String resolution) {
    return 'קרקעית הים: $source (~$resolution מ\')';
  }

  @override
  String get dive3d_seascape_noCoordinates => 'לאתר זה אין נקודות ציון GPS';

  @override
  String get dive3d_seascape_noData => 'אין נתוני עומק זמינים למיקום זה';

  @override
  String dive3d_seascape_axis_distance(String unitSymbol) {
    return 'מרחק ($unitSymbol)';
  }

  @override
  String get settings_about_bathymetryCredit =>
      'נתוני עומק: GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022';

  @override
  String get dive3d_metric_depth => 'עומק';

  @override
  String get dive3d_metric_temperature => 'טמפ';

  @override
  String get dive3d_metric_ascentRate => 'עלייה';

  @override
  String get dive3d_metric_ppO2 => 'ppO2';

  @override
  String get dive3d_metric_cns => 'CNS';

  @override
  String get dive3d_metric_heartRate => 'דופק';

  @override
  String get dive3d_metric_tankPressure => 'לחץ';

  @override
  String get dive3d_zAxis => 'ציר Z';

  @override
  String get dive3d_zAxis_none => 'ללא';

  @override
  String get dive3d_overlay_shadows => 'צללי קירות';

  @override
  String get dive3d_metric_tts => 'TTS';

  @override
  String dive3d_axis_depth(String unitSymbol) {
    return 'עומק ($unitSymbol)';
  }

  @override
  String get dive3d_axis_time => 'זמן צלילה (דק\')';

  @override
  String get dive3d_pose_menu => 'מצלמה';

  @override
  String get dive3d_pose_default => 'תצוגת ברירת מחדל';

  @override
  String get dive3d_pose_front => 'חזית (עומק מול זמן)';

  @override
  String get dive3d_pose_side => 'צד (עומק מול מדד)';

  @override
  String get dive3d_pose_top => 'מלמעלה (מדד מול זמן)';

  @override
  String get dive3d_readout_runTime => 'זמן צלילה';

  @override
  String get dive3d_readout_ceiling => 'תקרה';

  @override
  String dive3d_readout_tank(int n) {
    return 'מיכל $n';
  }

  @override
  String get dive3d_scene_dive => 'צלילה';

  @override
  String get dive3d_scene_tissue => 'רקמות';

  @override
  String get dive3d_tissue_gasCombined => 'משולב';

  @override
  String get dive3d_tissue_gasN2 => 'N2';

  @override
  String get dive3d_tissue_gasHe => 'He';

  @override
  String get dive3d_tissue_colorMValue => '% ערך M';

  @override
  String get dive3d_tissue_colorAbsolute => 'עומס';

  @override
  String get dive3d_tissue_controlling => 'מוביל';

  @override
  String get dive3d_tissue_surfaceInterval => 'מרווח פני השטח';

  @override
  String get dive3d_career_title => 'היסטוריה תלת־ממד';

  @override
  String get dive3d_career_colorRecency => 'עדכניות';

  @override
  String get dive3d_career_colorDepth => 'עומק';

  @override
  String get dive3d_career_empty => 'אין צלילות עם פרופילים';

  @override
  String get dive3d_spatial_title => 'נוף ים תלת־ממדי';

  @override
  String get dive3d_spatial_estimatedPath => 'נתיב משוער (ניווט משוער)';

  @override
  String get dive3d_spatial_synthesizedSeafloor => 'קרקעית ים מסונתזת';

  @override
  String get dive3d_spatial_noPath => 'אין מספיק נתונים לשחזור הנתיב';

  @override
  String get dive3d_tissue_legendHeight => 'גובה וצבע: ٪ מגבול ערך M';

  @override
  String get dive3d_tissue_legendLimit => 'מישור אדום = גבול דקו';

  @override
  String get dive3d_tissue_legendAxes =>
      'שמאל→ימין: זמן · קדימה→אחורה: רקמות מהירות→איטיות';

  @override
  String get dive3d_tissue_legendDepth => 'עקומה כחולה: העומק שלך';

  @override
  String get dive3d_tissue_onGassing => 'ספיגה';

  @override
  String get dive3d_tissue_offGassing => 'שחרור';

  @override
  String dive3d_tissue_tooltipCompartment(int number) {
    return 'תא $number';
  }

  @override
  String dive3d_tissue_tooltipHalfTime(int minutes) {
    return '$minutes דק׳ N2';
  }

  @override
  String dive3d_tissue_tooltipSaturation(int percent) {
    return 'רוויה $percent%';
  }

  @override
  String dive3d_tissue_tooltipProgress(int percent) {
    return '$percent% מהצלילה';
  }

  @override
  String get dive3d_tissue_stateEquilibrium => 'שיווי משקל';

  @override
  String get dive3d_tissue_statePastMValue => 'מעל ערך M';

  @override
  String get dive3d_tissue_axisTime => 'זמן';

  @override
  String get dive3d_tissue_axisSaturation => 'רוויה %';

  @override
  String get dive3d_tissue_axisCompartment => 'תא';

  @override
  String get dive3d_compare_computers_title => 'השוואת מחשבי צלילה';

  @override
  String get dive3d_compare_dives_title => 'השוואת צלילות';

  @override
  String get dive3d_scene_computers => 'מחשבי צלילה';

  @override
  String get dive3d_compare_layout_sideBySide => 'זה לצד זה';

  @override
  String get dive3d_compare_layout_overlay => 'חופף';

  @override
  String get dive3d_compare_empty =>
      'נדרשים לפחות 2 פרופילים עם נתוני עומק להשוואה';

  @override
  String dive3d_compare_showing(Object shown, Object total) {
    return 'מוצג $shown מתוך $total';
  }

  @override
  String get dive3d_compare_setReference => 'הגדר כעוגן';

  @override
  String get diveLog_selection_tooltip_compare3d => 'השוואה בתלת-ממד';

  @override
  String get diveLog_sources_compareIn3d => 'השוואה בתלת-ממד';

  @override
  String get settings_setup_pendingTitle => 'השלם את הגדרת המכשיר הזה';

  @override
  String settings_setup_mediaStoreAttach(String hint) {
    return 'חיבור אחסון מדיה ($hint)';
  }

  @override
  String settings_setup_accountSignIn(String label) {
    return 'התחברות אל $label';
  }

  @override
  String get settings_setup_dismiss => 'התעלם';

  @override
  String get settings_photosMedia_title => 'תמונות ומדיה';

  @override
  String get settings_photosMedia_subtitle => 'מקורות, אחסון וחשבונות';

  @override
  String get settings_photosMedia_sourcesHeader => 'מאיפה מגיעות התמונות';

  @override
  String get settings_photosMedia_storageHeader => 'איפה נשמרים העותקים';

  @override
  String get settings_photosMedia_accountsHeader => 'חשבונות';

  @override
  String get settings_photosMedia_displayHeader => 'תצוגה';

  @override
  String get settings_photosMedia_guidedSetup => 'הגדרה מודרכת';

  @override
  String get settings_photosMedia_photoSources_title => 'ספריית תמונות ומקורות';

  @override
  String get settings_photosMedia_photoSources_subtitle =>
      'גלריה, קבצים ואפשרויות ייבוא';

  @override
  String get settings_photosMedia_networkSources_title => 'מקורות רשת';

  @override
  String get settings_photosMedia_networkSources_subtitle =>
      'כתובות URL והזנות מניפסט (מתקדם)';

  @override
  String get settings_connectedAccounts_title => 'חשבונות מחוברים';

  @override
  String get settings_connectedAccounts_subtitle => 'כניסות לענן ולשירותים';

  @override
  String get settings_connectedAccounts_empty => 'אין עדיין חשבונות מחוברים';

  @override
  String get settings_connectedAccounts_status_signedIn => 'מחובר';

  @override
  String get settings_connectedAccounts_status_needsSignIn => 'נדרשת כניסה';

  @override
  String get settings_connectedAccounts_status_unavailable =>
      'לא זמין במכשיר זה';

  @override
  String get settings_connectedAccounts_disconnectDevice => 'התנתק במכשיר זה';

  @override
  String get settings_connectedAccounts_removeFromLibrary => 'הסר מהספרייה';

  @override
  String get settings_connectedAccounts_removeConfirmTitle =>
      'להסיר את החשבון?';

  @override
  String get settings_connectedAccounts_removeConfirmBody =>
      'החשבון מוסר מכל המכשירים המסונכרנים. אישורים השמורים במכשירים אחרים אינם נמחקים.';

  @override
  String get settings_setupGuide_title => 'הגדרת תמונות ומדיה';

  @override
  String get settings_setupGuide_intro =>
      'חבר את מקורות התמונות ואת מקום שמירת העותקים. אפשר להריץ זאת שוב בכל עת.';

  @override
  String get settings_setupGuide_stepSources => 'מקורות תמונות';

  @override
  String get settings_setupGuide_stepSources_desc =>
      'צרף תמונות מספריית התמונות, מקבצים או מ-Lightroom.';

  @override
  String get settings_setupGuide_stepStorage => 'אחסון מדיה';

  @override
  String get settings_setupGuide_stepStorage_desc =>
      'שמור עותקים של התמונות בענן שלך כדי שכל מכשיר יוכל להציגן.';

  @override
  String get settings_setupGuide_stepSync => 'סנכרון ענן';

  @override
  String get settings_setupGuide_stepSync_desc =>
      'סנכרן נתוני צלילה בין מכשירים.';

  @override
  String get settings_setupGuide_statusDone => 'מוגדר';

  @override
  String get settings_setupGuide_statusTodo => 'לא מוגדר';

  @override
  String get settings_setupGuide_open => 'פתח';

  @override
  String get settings_connectedAccounts_loadError => 'לא ניתן לטעון חשבונות';

  @override
  String get media_unavailablePlaceholder_volumeOffline => 'הכונן אינו מחובר';

  @override
  String get media_unavailablePlaceholder_stillFetching =>
      'עדיין נטען. הקש כדי לנסות שוב.';

  @override
  String get media_unavailablePlaceholder_accessDenied =>
      'אין גישה לספריית התמונות';

  @override
  String get attrLabel_size => 'מידה';

  @override
  String get attrLabel_thickness_mm => 'עובי (מ\"מ)';

  @override
  String get attrLabel_suit_style => 'סוג חליפה';

  @override
  String get attrLabel_shell_material => 'חומר מעטפת';

  @override
  String get attrLabel_seal_type => 'סוג אטמים';

  @override
  String get attrLabel_volume_l => 'נפח';

  @override
  String get attrLabel_working_pressure_bar => 'לחץ עבודה';

  @override
  String get attrLabel_tank_material => 'חומר';

  @override
  String get attrLabel_valve_type => 'שסתום';

  @override
  String get attrLabel_tank_identifier => 'מזהה';

  @override
  String get attrLabel_last_visual_inspection => 'בדיקה חזותית אחרונה';

  @override
  String get attrLabel_last_hydro_test => 'מבחן הידרוסטטי אחרון';

  @override
  String get attrLabel_connection => 'חיבור';

  @override
  String get attrLabel_cold_water_rated => 'מתאים למים קרים';

  @override
  String get attrLabel_bcd_style => 'סגנון';

  @override
  String get attrLabel_lift_capacity_kg => 'כושר הרמה';

  @override
  String get attrLabel_heel_type => 'עקב';

  @override
  String get attrLabel_blade_style => 'להב';

  @override
  String get attrLabel_mount => 'התקנה';

  @override
  String get attrLabel_connectivity => 'קישוריות';

  @override
  String get attrLabel_lens_config => 'עדשה';

  @override
  String get attrLabel_prescription => 'עדשות אופטיות';

  @override
  String get attrLabel_weight_style => 'סגנון';

  @override
  String get attrLabel_lumens => 'לומן';

  @override
  String get attrLabel_beam_type => 'אלומה';

  @override
  String get attrLabel_depth_rating_m => 'דירוג עומק';

  @override
  String get attrLabel_smb_type => 'סוג';

  @override
  String get attrLabel_length_m => 'אורך';

  @override
  String get attrLabel_reel_type => 'סוג';

  @override
  String get attrLabel_line_length_m => 'אורך חוט';

  @override
  String get attrLabel_blade_material => 'חומר להב';

  @override
  String get attrLabel_tip_type => 'קצה';

  @override
  String get attrLabel_glove_type => 'סוג';

  @override
  String get attrLabel_sole_type => 'סוליה';

  @override
  String get attrLabel_buoyancy_kg => 'ציפה';

  @override
  String get attrLabel_dry_weight_kg => 'משקל יבש';

  @override
  String get attrLabel_unit_type => 'סוג היחידה';

  @override
  String get attrLabel_mount_configuration => 'אופן ההרכבה';

  @override
  String get attrLabel_scrubber_type => 'סוג הסופח';

  @override
  String get attrLabel_scrubber_duration_h => 'משך הסופח (שעות)';

  @override
  String get attrLabel_o2_cell_count => 'תאי O2';

  @override
  String get attrLabel_diluent_cylinder_l => 'בלון מדלל';

  @override
  String get attrLabel_o2_cylinder_l => 'בלון O2';

  @override
  String get attrLabel_dpv_style => 'סגנון';

  @override
  String get attrLabel_burn_time_h => 'זמן פעולה';

  @override
  String get attrLabel_battery_type => 'סוללה';

  @override
  String get attrLabel_battery_capacity_wh => 'קיבולת סוללה (Wh)';

  @override
  String get attrLabel_motor_type => 'מנוע';

  @override
  String get attrLabel_speed_mps => 'מהירות מרבית';

  @override
  String get attrChoice_unit_type_eccr => 'CCR אלקטרוני (eCCR)';

  @override
  String get attrChoice_unit_type_mccr => 'CCR ידני (mCCR)';

  @override
  String get attrChoice_unit_type_hccr => 'CCR היברידי (hCCR)';

  @override
  String get attrChoice_unit_type_scr_cmf => 'SCR - ספיקת מסה קבועה';

  @override
  String get attrChoice_unit_type_scr_pascr => 'SCR - הוספה פסיבית';

  @override
  String get attrChoice_unit_type_scr_escr => 'SCR - בקרה אלקטרונית';

  @override
  String get attrChoice_mount_configuration_back => 'הרכבה על הגב';

  @override
  String get attrChoice_mount_configuration_chest => 'הרכבה על החזה';

  @override
  String get attrChoice_mount_configuration_sidemount => 'הרכבה בצד';

  @override
  String get attrChoice_scrubber_type_axial => 'צירי';

  @override
  String get attrChoice_scrubber_type_radial => 'רדיאלי';

  @override
  String get attrChoice_suit_style_full => 'חליפה מלאה';

  @override
  String get attrChoice_suit_style_shorty => 'שורטי';

  @override
  String get attrChoice_suit_style_two_piece => 'שני חלקים';

  @override
  String get attrChoice_suit_style_semi_dry => 'חצי יבשה';

  @override
  String get attrChoice_shell_material_trilaminate => 'טרילמינט';

  @override
  String get attrChoice_shell_material_neoprene => 'ניאופרן';

  @override
  String get attrChoice_shell_material_crushed_neoprene => 'ניאופרן דחוס';

  @override
  String get attrChoice_shell_material_vulcanized_rubber => 'גומי מגופר';

  @override
  String get attrChoice_seal_type_latex => 'לטקס';

  @override
  String get attrChoice_seal_type_silicone => 'סיליקון';

  @override
  String get attrChoice_seal_type_neoprene => 'ניאופרן';

  @override
  String get attrChoice_tank_material_aluminum => 'אלומיניום';

  @override
  String get attrChoice_tank_material_steel => 'פלדה';

  @override
  String get attrChoice_tank_material_carbon_composite => 'מרוכב פחמן';

  @override
  String get attrChoice_valve_type_din => 'DIN';

  @override
  String get attrChoice_valve_type_yoke => 'יוק (INT)';

  @override
  String get attrChoice_valve_type_convertible => 'הפיך';

  @override
  String get attrChoice_connection_din => 'DIN';

  @override
  String get attrChoice_connection_yoke => 'יוק (INT)';

  @override
  String get attrChoice_bcd_style_jacket => 'ז\'קט';

  @override
  String get attrChoice_bcd_style_back_inflate => 'ניפוח גב';

  @override
  String get attrChoice_bcd_style_wing => 'כנף';

  @override
  String get attrChoice_bcd_style_sidemount => 'סייד-מאונט';

  @override
  String get attrChoice_heel_type_open_heel => 'עקב פתוח';

  @override
  String get attrChoice_heel_type_full_foot => 'רגל מלאה';

  @override
  String get attrChoice_blade_style_paddle => 'חתירה';

  @override
  String get attrChoice_blade_style_split => 'מפוצל';

  @override
  String get attrChoice_blade_style_vented => 'מאוורר';

  @override
  String get attrChoice_mount_wrist => 'פרק יד';

  @override
  String get attrChoice_mount_console => 'קונסולה';

  @override
  String get attrChoice_mount_hud => 'HUD';

  @override
  String get attrChoice_connectivity_ble => 'Bluetooth (BLE)';

  @override
  String get attrChoice_connectivity_usb => 'USB';

  @override
  String get attrChoice_connectivity_infrared => 'אינפרא אדום';

  @override
  String get attrChoice_connectivity_none => 'ללא';

  @override
  String get attrChoice_lens_config_single => 'עדשה אחת';

  @override
  String get attrChoice_lens_config_twin => 'שתי עדשות';

  @override
  String get attrChoice_lens_config_frameless => 'ללא מסגרת';

  @override
  String get attrChoice_weight_style_belt => 'חגורה';

  @override
  String get attrChoice_weight_style_integrated => 'משולב';

  @override
  String get attrChoice_weight_style_trim => 'טרים';

  @override
  String get attrChoice_weight_style_ankle => 'קרסול';

  @override
  String get attrChoice_beam_type_spot => 'ספוט';

  @override
  String get attrChoice_beam_type_flood => 'רחב';

  @override
  String get attrChoice_beam_type_adjustable => 'מתכוונן';

  @override
  String get attrChoice_smb_type_open => 'פתוח';

  @override
  String get attrChoice_smb_type_closed => 'סגור';

  @override
  String get attrChoice_reel_type_spool => 'סליל';

  @override
  String get attrChoice_reel_type_ratchet => 'רצ\'ט';

  @override
  String get attrChoice_blade_material_stainless => 'פלדת אל-חלד';

  @override
  String get attrChoice_blade_material_titanium => 'טיטניום';

  @override
  String get attrChoice_tip_type_pointed => 'מחודד';

  @override
  String get attrChoice_tip_type_blunt => 'קהה';

  @override
  String get attrChoice_tip_type_line_cutter => 'חותך חוטים';

  @override
  String get attrChoice_glove_type_five_finger => 'חמש אצבעות';

  @override
  String get attrChoice_glove_type_mitt => 'כפפת אגרוף';

  @override
  String get attrChoice_glove_type_dry => 'יבש';

  @override
  String get attrChoice_sole_type_hard => 'סוליה קשה';

  @override
  String get attrChoice_sole_type_soft => 'סוליה רכה';

  @override
  String get attrChoice_dpv_style_tow_behind => 'נגרר';

  @override
  String get attrChoice_dpv_style_ride_on => 'רכיבה';

  @override
  String get attrChoice_dpv_style_handheld => 'מוחזק ביד';

  @override
  String get attrChoice_battery_type_lithium_ion => 'ליתיום-יון';

  @override
  String get attrChoice_battery_type_nimh => 'NiMH';

  @override
  String get attrChoice_battery_type_lead_acid => 'עופרת-חומצה';

  @override
  String get attrChoice_motor_type_brushless => 'ללא מברשות';

  @override
  String get attrChoice_motor_type_brushed => 'עם מברשות';

  @override
  String get equipment_edit_customFieldsTitle => 'שדות מותאמים אישית';

  @override
  String get equipment_edit_addCustomField => 'הוספת שדה מותאם אישית';

  @override
  String get attr_flagYes => 'כן';

  @override
  String get attr_flagNo => 'לא';

  @override
  String get equipment_edit_invalidThickness => 'השתמשו ב-5, 5/4 או 7/5/3';

  @override
  String get statistics_progression_divesBySuitThickness_title =>
      'צלילות לפי עובי חליפה';

  @override
  String get statistics_progression_divesBySuitThickness_subtitle =>
      'העובי העיקרי של חליפת הצלילה על פני הצלילות';

  @override
  String get statistics_progression_divesBySuitThickness_empty =>
      'אין צלילות עם עובי חליפה מתועד';

  @override
  String get statistics_progression_divesBySuitThickness_error =>
      'לא ניתן לטעון נתוני עובי חליפה';

  @override
  String get diveLog_filter_sectionSuitThickness => 'עובי חליפה (מ\"מ)';

  @override
  String get diveLog_filter_thicknessMin => 'מינ\'';

  @override
  String get diveLog_filter_thicknessMax => 'מקס\'';

  @override
  String get safetySettings_noFlyHeader => 'טיסה אחרי צלילה';

  @override
  String get safetySettings_noFlyPreset_standard => 'רגיל (12/18/24 ש\')';

  @override
  String get safetySettings_noFlyPreset_strict => 'מחמיר (18/24/48 ש\')';

  @override
  String get safetySettings_noFlyPreset_subtitle =>
      'מרווחים מנחים אחרי צלילה בודדת ללא דקו, צלילות חוזרות וצלילות דקומפרסיה';

  @override
  String get flightWindow_closed => 'אין יותר צלילות לפני הטיסה';

  @override
  String get flightWindow_conflict => 'זמן איסור הטיסה שלך נמשך מעבר להמראה';

  @override
  String flightWindow_departs(String time) {
    return 'הטיסה ממריאה $time';
  }

  @override
  String flightWindow_openTitle(String remaining) {
    return 'זמן צלילה שנותר: $remaining';
  }

  @override
  String flightWindow_surfaceBy(String time) {
    return 'לעלות אל פני השטח עד $time';
  }

  @override
  String safetyHub_noFly_active_title(String remaining) {
    return 'איסור טיסה: נותרו $remaining';
  }

  @override
  String safetyHub_noFly_until(String time) {
    return 'עד $time';
  }

  @override
  String get safetyHub_noFly_clear_title => 'אין הגבלת טיסה';

  @override
  String get safetyHub_noFly_clear_subtitle => 'אין הגבלת טיסה פעילה';

  @override
  String safetyHub_noFly_category_single(int hours) {
    return 'אחרי צלילה בודדת ללא דקו: הנחיה של $hours שעות';
  }

  @override
  String safetyHub_noFly_category_repetitive(int hours) {
    return 'אחרי צלילות חוזרות: הנחיה של $hours שעות';
  }

  @override
  String safetyHub_noFly_category_deco(int hours) {
    return 'אחרי צלילת דקומפרסיה: הנחיה של $hours שעות';
  }

  @override
  String get safetyHub_noFly_disclaimer =>
      'הנחיות DAN/UHMS מאז הצלילה האחרונה. אינו תחליף לזמן איסור הטיסה של מחשב הצלילה שלך.';

  @override
  String get diveLog_detail_altitudeMismatch_title => 'אתר הצלילה נמצא בגובה';

  @override
  String get diveLog_detail_altitudeMismatch_subtitle =>
      'לאתר זה רשום גובה אך לצלילה אין, ולכן ניתוח הדקומפרסיה הניח גובה פני הים. הגדר את גובה הצלילה כדי לתקן.';

  @override
  String diveLog_detail_sacVolumeHint(String unit) {
    return 'הוסף נפח בלון כדי להציג קצב SAC ב-$unit/min';
  }

  @override
  String safetyHub_alert_noFly(String remaining) {
    return 'איסור טיסה: נותרו $remaining';
  }

  @override
  String get emergencyCard_title => 'חירום';

  @override
  String emergencyCard_callDan(String name) {
    return 'התקשר אל $name';
  }

  @override
  String get emergencyCard_callDan_subtitle =>
      'קו חירום לצוללים. התקשר אליו קודם: הם מתאמים פינוי והפניה לתא לחץ.';

  @override
  String emergencyCard_ems(String number) {
    return 'שירותי חירום מקומיים: $number';
  }

  @override
  String get emergencyCard_diverSection => 'צולל';

  @override
  String emergencyCard_bloodType(String value) {
    return 'סוג דם: $value';
  }

  @override
  String emergencyCard_allergies(String value) {
    return 'אלרגיות: $value';
  }

  @override
  String emergencyCard_medications(String value) {
    return 'תרופות: $value';
  }

  @override
  String get emergencyCard_contactsSection => 'אנשי קשר לחירום';

  @override
  String get emergencyCard_insuranceSection => 'ביטוח צלילה';

  @override
  String emergencyCard_insurancePolicy(String number) {
    return 'פוליסה $number';
  }

  @override
  String get emergencyCard_chambersSection => 'תאי לחץ';

  @override
  String get emergencyCard_chambersNote =>
      'הזמינות משתנה. תמיד התקשר קודם לקו החירום לצוללים להפניה.';

  @override
  String emergencyCard_chamberVerified(String date) {
    return 'הפרטים אומתו $date';
  }

  @override
  String get emergencyCard_chambersNearby => 'תאי לחץ קרובים';

  @override
  String emergencyCard_chamberViewAll(int count) {
    return 'הצג את כל $count תאי הלחץ';
  }

  @override
  String get emergencyCard_chambersNoneNearby =>
      'אין תא לחץ בטווח. התקשר לקו החירום לצוללנים: הם יפנו אותך למתקן הקרוב ביותר שיכול לטפל בך.';

  @override
  String get emergencyCard_chamberCapability_divingEmergency =>
      'מטפל בתאונות צלילה';

  @override
  String get emergencyCard_chamberCapability_hyperbaricUnit =>
      'יחידה היפרברית בבית חולים';

  @override
  String get emergencyCard_chamberCapability_elective => 'טיפול אלקטיבי בלבד';

  @override
  String get emergencyCard_chamberCapability_unknown => 'היכולת לא אומתה';

  @override
  String get emergencyCard_chamberAvailability_h24 => '24 שעות';

  @override
  String get emergencyCard_chamberAvailability_onCall => 'כוננות';

  @override
  String get emergencyCard_chamberAvailability_businessHours => 'שעות פעילות';

  @override
  String get emergencyCard_chamberUnverified => 'לא אומת מול המתקן';

  @override
  String get chambersDirectory_title => 'תאי לחץ';

  @override
  String get chambersDirectory_search => 'חיפוש לפי שם, עיר או מדינה';

  @override
  String get chambersDirectory_empty => 'אין תא לחץ התואם לחיפוש.';

  @override
  String chambersDirectory_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תאי לחץ',
      one: 'תא לחץ אחד',
    );
    return '$_temp0';
  }

  @override
  String get emergencyCard_hideChamber => 'הסתר';

  @override
  String get emergencyCard_chamberHidden => 'התא הוסתר';

  @override
  String get emergencyCard_undo => 'בטל';

  @override
  String get emergencyCard_addChamber => 'הוסף תא לחץ';

  @override
  String get emergencyCard_deleteChamber => 'מחק';

  @override
  String emergencyCard_regionLabel(String region) {
    return 'אזור: $region';
  }

  @override
  String get emergencyCard_regionUnknown =>
      'אזור לא ידוע - נעשה שימוש בקו העולמי';

  @override
  String get emergencyCard_noDiverData =>
      'אין נתוני פרופיל צולל. הוסף אנשי קשר לחירום, נתונים רפואיים וביטוח בפרופיל הצולל.';

  @override
  String get addChamber_title => 'הוסף תא לחץ';

  @override
  String get addChamber_name => 'שם';

  @override
  String get addChamber_country => 'קוד מדינה (למשל IL)';

  @override
  String get addChamber_city => 'עיר';

  @override
  String get addChamber_phone => 'טלפון';

  @override
  String get addChamber_notes => 'הערות';

  @override
  String get addChamber_save => 'שמור';

  @override
  String get addChamber_nameRequired => 'שם נדרש';

  @override
  String get addChamber_countryRequired => 'קוד מדינה נדרש';

  @override
  String get addChamber_phoneRequired => 'מספר טלפון נדרש';

  @override
  String get safetyHub_emergencyCardLink => 'כרטיס חירום';

  @override
  String get safetyHub_emergencyCardLink_subtitle =>
      'לא מקוון: קו חם, חירום, תאי לחץ, הנתונים הרפואיים והביטוחיים שלך';

  @override
  String get dashboard_quickAction_emergency => 'כרטיס חירום';

  @override
  String get incidents_title => 'יומן כמעט-תאונות';

  @override
  String get incidents_empty =>
      'לא נרשמו כמעט-תאונות. תיעוד של מה שכמעט השתבש - ללא שיפוטיות - חושף דפוסים לפני שהם הופכים לתאונות.';

  @override
  String get incidents_add => 'רישום כמעט-תאונה';

  @override
  String get incidents_linkedDive => 'מקושר לצלילה';

  @override
  String get incidents_delete_confirm => 'למחוק דוח כמעט-תאונה זה?';

  @override
  String get incidents_notFound => 'דוח כמעט-תאונה לא נמצא';

  @override
  String get incidentEdit_title_new => 'רישום כמעט-תאונה';

  @override
  String get incidentEdit_title_edit => 'עריכת כמעט-תאונה';

  @override
  String get incidentEdit_category => 'קטגוריה';

  @override
  String get incidentEdit_severity => 'חומרה';

  @override
  String get incidentEdit_severity_minor => 'קלה';

  @override
  String get incidentEdit_severity_moderate => 'בינונית';

  @override
  String get incidentEdit_severity_serious => 'חמורה';

  @override
  String get incidentEdit_date => 'מתי זה קרה';

  @override
  String get incidentEdit_narrative => 'מה קרה';

  @override
  String get incidentEdit_narrative_hint =>
      'רק העובדות, במילים שלך. זה נשאר פרטי.';

  @override
  String get incidentEdit_narrative_required => 'תאר מה קרה';

  @override
  String get incidentEdit_contributingFactors => 'מה תרם (אופציונלי)';

  @override
  String get incidentEdit_lessonsLearned => 'מה יעזור בפעם הבאה (אופציונלי)';

  @override
  String get incidentEdit_save => 'שמור';

  @override
  String get incidentEdit_privacyNote =>
      'דוחות כמעט-תאונה מסתנכרנים בין המכשירים שלך ונכללים בגיבויים, אך לעולם לא בייצוא או בדפי יומן משותפים.';

  @override
  String get incidentCategory_buoyancy => 'ציפה';

  @override
  String get incidentCategory_gasSupply => 'אספקת גז';

  @override
  String get incidentCategory_equipment => 'ציוד';

  @override
  String get incidentCategory_buddySeparation => 'היפרדות מהבן זוג';

  @override
  String get incidentCategory_marineLife => 'חיים ימיים';

  @override
  String get incidentCategory_boatSurface => 'סירה / פני השטח';

  @override
  String get incidentCategory_medical => 'רפואי';

  @override
  String get incidentCategory_planning => 'תכנון';

  @override
  String get incidentCategory_other => 'אחר';

  @override
  String get safetyHub_incidentsLink => 'יומן כמעט-תאונות';

  @override
  String get safetyHub_incidentsLink_subtitle =>
      'הערות אירועים פרטיות ולא ענישתיות';

  @override
  String get diveLog_detail_menu_logNearMiss => 'רישום כמעט-תאונה';

  @override
  String diveLog_detail_linkedIncidents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count כמעט-תאונות מקושרות לצלילה זו',
      one: 'כמעט-תאונה אחת מקושרת לצלילה זו',
    );
    return '$_temp0';
  }

  @override
  String get planning_card_noFly_subtitle =>
      'ספירה לאחור מנחה מהצלילות האחרונות שלך';

  @override
  String get settings_section_safety_title => 'בטיחות';

  @override
  String get settings_section_safety_subtitle => 'כללי סקירה וטיסה אחרי צלילה';

  @override
  String get settings_section_security_title => 'אבטחת האפליקציה';

  @override
  String get settings_section_security_subtitle =>
      'נעילת אפליקציה והצפנת מסד הנתונים';

  @override
  String get settings_security_appLock => 'נעילת אפליקציה';

  @override
  String get settings_security_appLock_subtitle =>
      'דרישת סיסמה או ביומטריה לפתיחת האפליקציה';

  @override
  String get settings_security_biometrics => 'ביטול נעילה באמצעות ביומטריה';

  @override
  String get settings_security_autoLock => 'נעילה אוטומטית';

  @override
  String get settings_security_autoLock_immediately => 'מיד';

  @override
  String settings_security_autoLock_minutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'אחרי $minutes דקות',
      one: 'אחרי דקה אחת',
    );
    return '$_temp0';
  }

  @override
  String get settings_security_autoLock_never => 'אף פעם';

  @override
  String get settings_security_encryption => 'הצפנת מסד הנתונים';

  @override
  String get settings_security_encryption_subtitle =>
      'הגנו על קובץ יומן הצלילות שלכם באמצעות הצפנה במנוחה. הצפנה עשויה להשפיע על הביצועים.';

  @override
  String get settings_security_encryption_progress_backup =>
      'יוצר גיבוי בטיחות...';

  @override
  String get settings_security_encryption_progress_encrypt =>
      'מצפין את מסד הנתונים...';

  @override
  String get settings_security_encryption_progress_decrypt =>
      'מפענח את מסד הנתונים...';

  @override
  String get settings_security_encryption_progress_reopen =>
      'פותח מחדש את מסד הנתונים...';

  @override
  String get settings_security_changePassword => 'שינוי סיסמה';

  @override
  String get settings_security_regenerateRecovery => 'קוד שחזור חדש';

  @override
  String get settings_security_setPassword => 'הגדרת סיסמת אפליקציה';

  @override
  String get settings_security_password => 'סיסמה';

  @override
  String get settings_security_confirmPassword => 'אישור סיסמה';

  @override
  String get settings_security_currentPassword => 'סיסמה נוכחית';

  @override
  String get settings_security_newPassword => 'סיסמה חדשה';

  @override
  String get settings_security_passwordTooShort =>
      'הסיסמה חייבת להכיל לפחות 4 תווים.';

  @override
  String get settings_security_passwordMismatch => 'הסיסמאות אינן תואמות.';

  @override
  String get settings_security_wrongPassword => 'סיסמה שגויה.';

  @override
  String get settings_security_recoveryCode_title => 'קוד השחזור שלכם';

  @override
  String get settings_security_recoveryCode_explain =>
      'רשמו אותו ושמרו אותו במקום בטוח. זו הדרך היחידה לפתוח את האפליקציה אם תשכחו את הסיסמה, והוא מחליף כל קוד שחזור קודם.';

  @override
  String get settings_security_recoveryCode_savedConfirm =>
      'שמרתי את קוד השחזור שלי';

  @override
  String get settings_security_disableBlockedByEncryption_title =>
      'ההצפנה פעילה';

  @override
  String get settings_security_disableBlockedByEncryption_body =>
      'כבו תחילה את הצפנת מסד הנתונים לפני כיבוי נעילת האפליקציה. מסד הנתונים המוצפן דורש אמצעי אימות.';

  @override
  String get settings_security_enableEncryption_title =>
      'להצפין את מסד הנתונים?';

  @override
  String get settings_security_enableEncryption_body =>
      'תחילה נוצר גיבוי בטיחות ואז קובץ מסד הנתונים מוצפן מחדש במקומו. זה עשוי להימשך זמן מה ביומנים גדולים. הצפנה עשויה להשפיע על הביצועים.';

  @override
  String get settings_security_disableEncryption_title => 'לכבות את ההצפנה?';

  @override
  String get settings_security_disableEncryption_body =>
      'קובץ מסד הנתונים יישמר שוב ללא הצפנה בדיסק.';

  @override
  String get settings_security_turnOffAppLock_title =>
      'לכבות את נעילת האפליקציה?';

  @override
  String get settings_security_turnOffAppLock_body =>
      'האפליקציה תיפתח מבלי לבקש את הסיסמה.';

  @override
  String get settings_security_unlock_title => 'הזינו את הסיסמה';

  @override
  String get settings_security_cancel => 'ביטול';

  @override
  String get settings_security_continue => 'המשך';

  @override
  String get settings_security_done => 'סיום';

  @override
  String get settings_security_turnOff => 'כיבוי';

  @override
  String get dataQuality_inbox_title => 'איכות הנתונים';

  @override
  String get dataQuality_badge_tooltip => 'בדיקת איכות הנתונים';

  @override
  String get dataQuality_scan_start => 'סריקת הספרייה';

  @override
  String dataQuality_scan_progress(int done, int total) {
    return 'נבדקו $done מתוך $total צלילות';
  }

  @override
  String get dataQuality_scan_cancel => 'ביטול';

  @override
  String dataQuality_scan_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הסריקה הושלמה - $count פריטים לבדיקה',
      one: 'הסריקה הושלמה - פריט אחד לבדיקה',
      zero: 'הסריקה הושלמה - אין ממצאים חדשים',
    );
    return '$_temp0';
  }

  @override
  String dataQuality_scan_errors(int count) {
    return 'לא ניתן היה לבדוק במלואן $count צלילות';
  }

  @override
  String dataQuality_lastScan(String when) {
    return 'סריקה אחרונה: $when';
  }

  @override
  String get dataQuality_neverScanned => 'יומן הצלילה שלך עדיין לא נסרק';

  @override
  String get dataQuality_empty_title => 'הכול תקין';

  @override
  String get dataQuality_empty_subtitle =>
      'אין ממצאים לגבי איכות הנתונים. סרוק את הספרייה כדי לבדוק אם יש בעיות בצלילות המיובאות.';

  @override
  String get dataQuality_banner_newChecks => 'זמינות בדיקות איכות חדשות';

  @override
  String get dataQuality_banner_rescan => 'סריקה מחדש';

  @override
  String get dataQuality_action_dismiss => 'התעלם';

  @override
  String get dataQuality_action_dismissFiltered => 'התעלם מכל המוצגים';

  @override
  String get dataQuality_action_goToDive => 'מעבר לצלילה';

  @override
  String get dataQuality_action_undo => 'בטל';

  @override
  String get dataQuality_repair_applied => 'התיקון הוחל';

  @override
  String get dataQuality_repair_noChange => 'אין כאן מה לתקן';

  @override
  String get dataQuality_repair_needsReview =>
      'אין תיקון אוטומטי. פתח את הצלילה כדי לתקן זאת.';

  @override
  String get dataQuality_repair_failed => 'התיקון נכשל';

  @override
  String get dataQuality_chip_all => 'הכול';

  @override
  String get dataQuality_chip_time => 'זמן';

  @override
  String get dataQuality_chip_profile => 'פרופיל';

  @override
  String get dataQuality_chip_gas => 'גז';

  @override
  String get dataQuality_chip_tanks => 'בלונים';

  @override
  String get dataQuality_chip_duplicates => 'כפילויות';

  @override
  String get dataQuality_chip_sources => 'מקורות';

  @override
  String get dataQuality_detector_clock_offset => 'שעון ואזור זמן';

  @override
  String get dataQuality_detector_duplicate => 'כפילות סבירה';

  @override
  String get dataQuality_detector_split_pair => 'פיצול בשוגג';

  @override
  String get dataQuality_detector_sample_gap => 'פערים בדגימות';

  @override
  String get dataQuality_detector_depth_spike => 'קפיצת עומק';

  @override
  String get dataQuality_detector_impossible_rate => 'קצב בלתי אפשרי';

  @override
  String get dataQuality_detector_temp_anomaly => 'חריגת טמפרטורה';

  @override
  String get dataQuality_detector_pressure_anomaly => 'חריגת לחץ';

  @override
  String get dataQuality_detector_gas_mod => 'אי-התאמה בין גז ל-MOD';

  @override
  String get dataQuality_detector_tank_assignment => 'בלון שגוי';

  @override
  String get dataQuality_detector_source_conflict => 'מקורות סותרים';

  @override
  String dataQuality_msg_clock_future(String date) {
    return 'הצלילה מתוארכת לעתיד ($date)';
  }

  @override
  String dataQuality_msg_clock_ancient(String date) {
    return 'הצלילה מתוארכת לפני 1950 ($date)';
  }

  @override
  String dataQuality_msg_clock_offset(int hours) {
    return 'שעון של מקור אחד שונה ב-$hours שעות';
  }

  @override
  String dataQuality_msg_clock_overlap(int minutes) {
    return 'חופפת לצלילה אחרת ב-$minutes דק׳';
  }

  @override
  String dataQuality_msg_duplicate(int percent, int minutes) {
    return 'התאמה של $percent% לצלילה במרחק $minutes דק׳';
  }

  @override
  String dataQuality_msg_split(int minutes) {
    return 'אותו מחשב חודש לאחר מרווח פני שטח של $minutes דק׳';
  }

  @override
  String dataQuality_msg_gap(int count, String longest) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פערים בדגימות',
      one: 'פער אחד בדגימות',
    );
    return '$_temp0, הארוך ביותר $longest';
  }

  @override
  String dataQuality_msg_spike(String depth, String time) {
    return 'קפיצת עומק אל $depth בשעה $time';
  }

  @override
  String dataQuality_msg_negativeDepth(int count) {
    return '$count דגימות עומק שליליות';
  }

  @override
  String dataQuality_msg_maxDepthMismatch(String stored, String profile) {
    return 'העומק המרבי שנרשם $stored, אך הפרופיל מציג $profile';
  }

  @override
  String dataQuality_msg_rate(String rate, int seconds) {
    return 'קצב אנכי של $rate נשמר במשך $seconds שנ׳';
  }

  @override
  String dataQuality_msg_tempRange(String min, String max) {
    return 'טמפרטורת המים מחוץ לטווח הסביר ($min עד $max)';
  }

  @override
  String get dataQuality_msg_tempUnitBug =>
      'הערכים נראים כמו תקלה ביחידת הטמפרטורה';

  @override
  String dataQuality_msg_tempJump(String delta) {
    return 'הטמפרטורה קפצה ב-$delta בדגימה אחת';
  }

  @override
  String dataQuality_msg_tempScalar(String temp) {
    return 'טמפרטורת המים שנרשמה $temp אינה סבירה';
  }

  @override
  String dataQuality_msg_pressureSwap(String end, String start) {
    return 'לחץ הסיום $end גבוה מלחץ ההתחלה $start';
  }

  @override
  String dataQuality_msg_pressureEndpoint(String record, String series) {
    return 'רשומת הבלון מציינת $record, אך סדרת החיישן מציגה $series';
  }

  @override
  String dataQuality_msg_pressureRise(String rise) {
    return 'הלחץ עלה ב-$rise באמצע הצלילה ללא החלפת גז';
  }

  @override
  String dataQuality_msg_sac(String sac) {
    return 'צריכת פני השטח המשתמעת של $sac אינה סבירה';
  }

  @override
  String dataQuality_msg_ppo2(String ppo2, String gas, String depth) {
    return 'ה-ppO2 הגיע ל-$ppo2 עם $gas בעומק $depth';
  }

  @override
  String dataQuality_msg_hypoxic(String gas) {
    return 'תערובת היפוקסית ($gas) מוצגת כבשימוש בפני השטח';
  }

  @override
  String dataQuality_msg_switchMod(String depth, String mod) {
    return 'החלפת הגז בעומק $depth חורגת מה-MOD של אותו גז שהוא $mod';
  }

  @override
  String dataQuality_msg_tankInactive(String drop) {
    return 'בלון זה איבד $drop בעוד ציר הזמן של הגז מציין שהוא לא היה בשימוש';
  }

  @override
  String get dataQuality_msg_twinTanks => 'שני בלונים נושאים סדרת לחץ כמעט זהה';

  @override
  String dataQuality_msg_sourceDepth(String primary, String source) {
    return 'המקורות חלוקים לגבי העומק המרבי: $primary מול $source';
  }

  @override
  String get dataQuality_msg_salinityHint =>
      'היחס הקבוע מרמז על הבדל בהגדרת מים מלוחים/מתוקים';

  @override
  String get dataQuality_msg_sourceDuration => 'המקורות חלוקים לגבי משך הצלילה';

  @override
  String get dataQuality_msg_sourceTemp => 'המקורות חלוקים לגבי טמפרטורת המים';

  @override
  String dataQuality_repairLabel_shiftTime(String offset) {
    return 'הסטת הזמן ב-$offset';
  }

  @override
  String get dataQuality_repairLabel_shiftImport => 'הסטת כל הצלילות מייבוא זה';

  @override
  String get dataQuality_repairLabel_consolidate => 'איחוד';

  @override
  String get dataQuality_repairLabel_combine => 'מיזוג לצלילה אחת';

  @override
  String get dataQuality_repairLabel_despike => 'הסרת הקפיצה';

  @override
  String get dataQuality_repairLabel_clampNegative =>
      'הגבלת עומקים מעל פני המים';

  @override
  String get dataQuality_repairLabel_smoothRates => 'החלקת קצבים בלתי אפשריים';

  @override
  String get dataQuality_repairLabel_fillGaps => 'מילוי הפערים';

  @override
  String get dataQuality_repairLabel_smoothTemp => 'החלקת הטמפרטורה';

  @override
  String get dataQuality_repairLabel_convertTemp => 'המרת הטמפרטורה';

  @override
  String get dataQuality_repairLabel_recompute => 'חישוב מחדש מהפרופיל';

  @override
  String get dataQuality_repairLabel_swapPressures => 'החלפת לחץ התחלה/סיום';

  @override
  String get dataQuality_repairLabel_setFromSeries => 'שימוש בערכי החיישן';

  @override
  String get dataQuality_repairLabel_swapSeries => 'החלפת סדרות הבלונים';

  @override
  String get dataQuality_repairLabel_reassignSeries => 'העברת הסדרה לבלון אחר';

  @override
  String get dataQuality_repairLabel_setPrimary => 'הגדרת מקור זה כראשי';

  @override
  String get dataQuality_repairLabel_split => 'פיצול לצלילות נפרדות';

  @override
  String get dataQuality_repairLabel_compare => 'השוואת פרופילים';

  @override
  String get dataQuality_settings_title => 'איכות הנתונים';

  @override
  String get dataQuality_settings_subtitle => 'בחירת הבדיקות שירוצו בעת הסריקה';

  @override
  String dataQuality_summary_flagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים סומנו לבדיקה',
      one: 'פריט אחד סומן לבדיקה',
    );
    return '$_temp0';
  }

  @override
  String get dataQuality_summary_review => 'סקירה';

  @override
  String get dataQuality_detail_chip => 'סקירה';

  @override
  String dataQuality_detail_chipCount(int count) {
    return 'סקירה ($count)';
  }

  @override
  String get settings_mediaStorage_quality_section => 'איכות העלאה';

  @override
  String get settings_mediaStorage_quality_photos => 'תמונות';

  @override
  String get settings_mediaStorage_quality_video => 'וידאו';

  @override
  String get settings_mediaStorage_quality_original => 'מקורי';

  @override
  String get settings_mediaStorage_quality_high => 'גבוהה';

  @override
  String get settings_mediaStorage_quality_balanced => 'מאוזנת';

  @override
  String get settings_mediaStorage_quality_small => 'קטנה';

  @override
  String get settings_mediaStorage_quality_caveat =>
      'כאשר נקבעת רמת דחיסה, קבצי המקור ברזולוציה מלאה אינם מועלים; הם נשארים במכשיר זה בלבד.';

  @override
  String get settings_mediaStorage_quality_reuploadQueued => 'העלאה מחדש בתור';

  @override
  String get settings_mediaStorage_quality_linuxFfmpegHint =>
      'התקן ffmpeg כדי לאפשר דחיסת וידאו. עד אז מועלים קבצי המקור.';

  @override
  String get settings_mediaStorage_quality_saveFailed =>
      'לא ניתן היה לשמור את איכות ההעלאה. נסה שוב.';

  @override
  String get settings_mediaStorage_quality_noTranscoderHint =>
      'מכשיר זה אינו יכול לדחוס וידאו. ממנו מועלים הקבצים המקוריים.';

  @override
  String get reef_section_title => 'מערכת אקולוגית';

  @override
  String get reef_section_sourcesTooltip => 'מקורות נתונים';

  @override
  String get reef_section_loadError =>
      'לא ניתן לטעון נתוני מערכת אקולוגית כרגע';

  @override
  String get reef_habitat_title => 'בית גידול השונית';

  @override
  String get reef_habitat_onReef => 'על שונית אלמוגים';

  @override
  String reef_habitat_onReefWithThreat(String threat) {
    return 'על שונית אלמוגים, רמת איום $threat';
  }

  @override
  String get reef_habitat_noReef => 'אין שונית אלמוגים ממופה במיקום זה';

  @override
  String get reef_habitat_unavailable => 'לא ניתן לבדוק כעת את בית הגידול';

  @override
  String get water_conditions_title => 'תנאי המים';

  @override
  String get water_conditions_unavailable => 'לא ניתן לבדוק את תנאי המים כרגע';

  @override
  String get water_conditions_noData => 'אין נתוני לוויין על המים למיקום זה';

  @override
  String get water_conditions_freshwater =>
      'טמפרטורת מים לוויינית מכסה אוקיינוסים בלבד';

  @override
  String water_conditions_anomaly(String value) {
    return 'סטייה $value';
  }

  @override
  String reef_health_degreeHeatingWeeks(String value) {
    return 'שבועות חום מצטברים $value מעלות-שבוע';
  }

  @override
  String reef_health_seaSurface(String value) {
    return 'פני הים $value';
  }

  @override
  String reef_health_asOf(String date) {
    return 'נכון ל-$date';
  }

  @override
  String get reef_health_levelNoStress => 'אין עקת חום';

  @override
  String get reef_health_levelWatch => 'תצפית הלבנה';

  @override
  String get reef_health_levelWarning => 'אזהרת הלבנה';

  @override
  String get reef_health_levelAlert1 => 'התראת הלבנה רמה 1';

  @override
  String get reef_health_levelAlert2 => 'התראת הלבנה רמה 2';

  @override
  String get reef_health_levelAlert3 => 'התראת הלבנה רמה 3';

  @override
  String get reef_health_levelAlert4 => 'התראת הלבנה רמה 4';

  @override
  String get reef_health_levelAlert5 => 'התראת הלבנה רמה 5';

  @override
  String get reef_protection_title => 'אזור מוגן';

  @override
  String get reef_protection_none => 'לא נמצא באזור ימי מוגן';

  @override
  String get reef_protection_unavailable => 'לא ניתן לבדוק כעת את מצב ההגנה';

  @override
  String get reef_protection_viewRegulations => 'הצגת תקנות';

  @override
  String reef_protection_iucn(String category) {
    return 'IUCN $category';
  }

  @override
  String get reef_species_recordedNearby => 'תועד בסביבה';

  @override
  String get reef_species_addToExpected => 'הוספה למינים צפויים';

  @override
  String reef_species_showAll(int count) {
    return 'הצג הכול ($count)';
  }

  @override
  String get reef_species_showFewer => 'הצג פחות';

  @override
  String get reef_attribution_title => 'מקורות נתוני השונית';

  @override
  String get reef_attribution_wri => 'נוכחות שונית ורמת איום. CC BY 3.0.';

  @override
  String get reef_attribution_noaa => 'טמפרטורת פני הים ועקת חום. נחלת הכלל.';

  @override
  String get reef_attribution_gbif =>
      'רשומות תצפית מינים, מסוננות ל-CC0 ו-CC BY 4.0.';

  @override
  String get reef_attribution_protectedSeas =>
      'גבולות אזורים ימיים מוגנים. CC BY 4.0.';

  @override
  String get enum_visibilityBand_excellent => 'מצוינת';

  @override
  String get enum_visibilityBand_good => 'טובה';

  @override
  String get enum_visibilityBand_moderate => 'בינונית';

  @override
  String get enum_visibilityBand_poor => 'ירודה';

  @override
  String visibility_range_between(String min, String max, String unit) {
    return '$min-$max $unit';
  }

  @override
  String visibility_range_over(String min, String unit) {
    return 'מעל $min $unit';
  }

  @override
  String visibility_range_under(String max, String unit) {
    return 'מתחת ל-$max $unit';
  }

  @override
  String get settings_coordinateFormat_title => 'פורמט קואורדינטות';

  @override
  String get settings_coordinateFormat_subtitle =>
      'כיצד מוצגים ומוזנים מיקומי GPS';

  @override
  String get settings_placeNameLanguage_title => 'שפת שמות המקומות';

  @override
  String get settings_placeNameLanguage_subtitle =>
      'בשימוש כאשר מדינה, אזור, עיר וגוף מים נשלפים מהקואורדינטות. אתרים קיימים אינם משתנים.';

  @override
  String get settings_coordinateFormat_decimalDegrees => 'מעלות עשרוניות';

  @override
  String get settings_coordinateFormat_degreesDecimalMinutes =>
      'מעלות ודקות עשרוניות';

  @override
  String get settings_coordinateFormat_degreesMinutesSeconds =>
      'מעלות, דקות, שניות';

  @override
  String get settings_coordinateFormat_utm => 'UTM';

  @override
  String get settings_coordinateFormat_mgrs => 'MGRS';

  @override
  String get settings_visibilityScale_title => 'סולם ראות';

  @override
  String get settings_visibilityScale_subtitle =>
      'אילו מרחקים נחשבים ראות טובה במקום שבו אתה צולל';

  @override
  String get settings_visibilityScale_preset_tropical => 'טרופי';

  @override
  String get settings_visibilityScale_preset_temperate => 'ממוזג';

  @override
  String get settings_visibilityScale_preset_coldWater => 'מים קרים / יבשתיים';

  @override
  String get settings_visibilityScale_preset_custom => 'מותאם אישית';

  @override
  String get settings_visibilityScale_customExcellent => 'מצוינת מ-';

  @override
  String get settings_visibilityScale_customGood => 'טובה מ-';

  @override
  String get settings_visibilityScale_customModerate => 'בינונית מ-';

  @override
  String get settings_visibilityScale_invalidOrder =>
      'כל ערך חייב להיות קטן מזה שמעליו וגדול מאפס';

  @override
  String statistics_conditions_visibility_legacySuffix(String band) {
    return '$band (נרשם לפני מדידה)';
  }

  @override
  String common_selection_countSelected(Object count) {
    return '$count נבחרו';
  }

  @override
  String get common_selection_enterTooltip => 'בחירת פריטים';

  @override
  String get common_selection_exitTooltip => 'יציאה מבחירה';

  @override
  String get common_selection_selectAllTooltip => 'בחר הכול';

  @override
  String get common_selection_deselectAllTooltip => 'בטל בחירת הכול';

  @override
  String common_bulkDelete_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'למחוק $count פריטים?',
      many: 'למחוק $count פריטים?',
      two: 'למחוק שני פריטים?',
      one: 'למחוק פריט אחד?',
    );
    return '$_temp0';
  }

  @override
  String get common_bulkDelete_body => 'לא ניתן לבטל פעולה זו.';

  @override
  String common_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count נמחקו',
      many: '$count נמחקו',
      two: 'שני פריטים נמחקו',
      one: 'פריט אחד נמחק',
    );
    return '$_temp0';
  }

  @override
  String get marineLife_species_delete_confirmTitle => 'למחוק מין?';

  @override
  String marineLife_species_delete_confirmBody(String name) {
    return 'האם למחוק את \"$name\"?';
  }

  @override
  String marineLife_species_delete_inUseError(String name) {
    return 'לא ניתן למחוק את \"$name\" - יש לו תצפיות';
  }

  @override
  String marineLife_species_delete_snackbar(String name) {
    return '\"$name\" נמחק';
  }

  @override
  String marineLife_species_delete_error(String error) {
    return 'שגיאה במחיקת המין: $error';
  }

  @override
  String get enum_diveField_diveNumber => 'מספר צלילה';

  @override
  String get enum_diveField_dateTime => 'תאריך ושעה';

  @override
  String get enum_diveField_siteName => 'שם האתר';

  @override
  String get enum_diveField_diveName => 'שם הצלילה';

  @override
  String get enum_diveField_maxDepth => 'עומק מרבי';

  @override
  String get enum_diveField_avgDepth => 'עומק ממוצע';

  @override
  String get enum_diveField_bottomTime => 'זמן תחתית';

  @override
  String get enum_diveField_runtime => 'זמן ריצה';

  @override
  String get enum_diveField_waterTemp => 'טמפרטורת מים';

  @override
  String get enum_diveField_airTemp => 'טמפרטורת אוויר';

  @override
  String get enum_diveField_visibility => 'ראות';

  @override
  String get enum_diveField_currentDirection => 'כיוון זרם';

  @override
  String get enum_diveField_currentStrength => 'עוצמת זרם';

  @override
  String get enum_diveField_swellHeight => 'גובה גלים';

  @override
  String get enum_diveField_entryMethod => 'שיטת כניסה';

  @override
  String get enum_diveField_exitMethod => 'שיטת יציאה';

  @override
  String get enum_diveField_waterType => 'סוג מים';

  @override
  String get enum_diveField_altitude => 'גובה';

  @override
  String get enum_diveField_surfacePressure => 'לחץ פני שטח';

  @override
  String get enum_diveField_windSpeed => 'מהירות רוח';

  @override
  String get enum_diveField_cloudCover => 'כיסוי עננים';

  @override
  String get enum_diveField_precipitation => 'משקעים';

  @override
  String get enum_diveField_humidity => 'לחות';

  @override
  String get enum_diveField_weatherDescription => 'מזג אוויר';

  @override
  String get enum_diveField_primaryGas => 'גז ראשי';

  @override
  String get enum_diveField_diluentGas => 'גז מדלל';

  @override
  String get enum_diveField_tankCount => 'מספר מכלים';

  @override
  String get enum_diveField_startPressure => 'לחץ התחלה';

  @override
  String get enum_diveField_endPressure => 'לחץ סיום';

  @override
  String get enum_diveField_sacRate => 'קצב SAC';

  @override
  String get enum_diveField_gasConsumed => 'צריכת גז';

  @override
  String get enum_diveField_totalWeight => 'משקל כולל';

  @override
  String get enum_diveField_diveComputerModel => 'מחשב צלילה';

  @override
  String get enum_diveField_gradientFactorLow => 'GF נמוך';

  @override
  String get enum_diveField_gradientFactorHigh => 'GF גבוה';

  @override
  String get enum_diveField_decoAlgorithm => 'אלגוריתם דקומפרסיה';

  @override
  String get enum_diveField_decoConservatism => 'שמרנות';

  @override
  String get enum_diveField_cnsStart => 'CNS התחלה';

  @override
  String get enum_diveField_cnsEnd => 'CNS סיום';

  @override
  String get enum_diveField_otu => 'OTU';

  @override
  String get enum_diveField_diveMode => 'מצב צלילה';

  @override
  String get enum_diveField_setpointLow => 'ערך יעד נמוך';

  @override
  String get enum_diveField_setpointHigh => 'ערך יעד גבוה';

  @override
  String get enum_diveField_setpointDeco => 'ערך יעד דקומפרסיה';

  @override
  String get enum_diveField_buddy => 'שותף';

  @override
  String get enum_diveField_diveMaster => 'דייבמאסטר';

  @override
  String get enum_diveField_siteLocation => 'מיקום האתר';

  @override
  String get enum_diveField_diveCenterName => 'מרכז צלילה';

  @override
  String get enum_diveField_siteLatitude => 'קו רוחב';

  @override
  String get enum_diveField_siteLongitude => 'קו אורך';

  @override
  String get enum_diveField_tripName => 'טיול';

  @override
  String get enum_diveField_ratingStars => 'דירוג';

  @override
  String get enum_diveField_isFavorite => 'מועדף';

  @override
  String get enum_diveField_notes => 'הערות';

  @override
  String get enum_diveField_tags => 'תגיות';

  @override
  String get enum_diveField_importSource => 'מקור ייבוא';

  @override
  String get enum_diveField_diveTypeName => 'סוג צלילה';

  @override
  String get enum_diveField_surfaceInterval => 'מרווח פני שטח';

  @override
  String get enum_diveField_diveNumber_short => '#';

  @override
  String get enum_diveField_dateTime_short => 'תאריך';

  @override
  String get enum_diveField_siteName_short => 'אתר';

  @override
  String get enum_diveField_diveName_short => 'שם';

  @override
  String get enum_diveField_maxDepth_short => 'ע. מרבי';

  @override
  String get enum_diveField_avgDepth_short => 'ע. ממוצע';

  @override
  String get enum_diveField_bottomTime_short => 'תחתית';

  @override
  String get enum_diveField_runtime_short => 'ריצה';

  @override
  String get enum_diveField_waterTemp_short => 'טמפ\' מים';

  @override
  String get enum_diveField_airTemp_short => 'טמפ\' אוויר';

  @override
  String get enum_diveField_visibility_short => 'ראות';

  @override
  String get enum_diveField_currentDirection_short => 'כיוון';

  @override
  String get enum_diveField_currentStrength_short => 'זרם';

  @override
  String get enum_diveField_swellHeight_short => 'גלים';

  @override
  String get enum_diveField_entryMethod_short => 'כניסה';

  @override
  String get enum_diveField_exitMethod_short => 'יציאה';

  @override
  String get enum_diveField_waterType_short => 'מים';

  @override
  String get enum_diveField_altitude_short => 'גובה';

  @override
  String get enum_diveField_surfacePressure_short => 'לחץ שטח';

  @override
  String get enum_diveField_windSpeed_short => 'רוח';

  @override
  String get enum_diveField_cloudCover_short => 'עננים';

  @override
  String get enum_diveField_precipitation_short => 'משקעים';

  @override
  String get enum_diveField_humidity_short => 'לחות';

  @override
  String get enum_diveField_weatherDescription_short => 'מזג אוויר';

  @override
  String get enum_diveField_primaryGas_short => 'גז';

  @override
  String get enum_diveField_diluentGas_short => 'מדלל';

  @override
  String get enum_diveField_tankCount_short => 'מכלים';

  @override
  String get enum_diveField_startPressure_short => 'התחלה';

  @override
  String get enum_diveField_endPressure_short => 'סיום';

  @override
  String get enum_diveField_sacRate_short => 'SAC';

  @override
  String get enum_diveField_gasConsumed_short => 'צריכת גז';

  @override
  String get enum_diveField_totalWeight_short => 'משקל';

  @override
  String get enum_diveField_diveComputerModel_short => 'מחשב';

  @override
  String get enum_diveField_gradientFactorLow_short => 'GFL';

  @override
  String get enum_diveField_gradientFactorHigh_short => 'GFH';

  @override
  String get enum_diveField_decoAlgorithm_short => 'אלגו\'';

  @override
  String get enum_diveField_decoConservatism_short => 'שמרנות';

  @override
  String get enum_diveField_cnsStart_short => 'CNS התחלה';

  @override
  String get enum_diveField_cnsEnd_short => 'CNS סיום';

  @override
  String get enum_diveField_otu_short => 'OTU';

  @override
  String get enum_diveField_diveMode_short => 'מצב';

  @override
  String get enum_diveField_setpointLow_short => 'SP נמוך';

  @override
  String get enum_diveField_setpointHigh_short => 'SP גבוה';

  @override
  String get enum_diveField_setpointDeco_short => 'SP דקו';

  @override
  String get enum_diveField_buddy_short => 'שותף';

  @override
  String get enum_diveField_diveMaster_short => 'DM';

  @override
  String get enum_diveField_siteLocation_short => 'מיקום';

  @override
  String get enum_diveField_diveCenterName_short => 'מרכז';

  @override
  String get enum_diveField_siteLatitude_short => 'רוחב';

  @override
  String get enum_diveField_siteLongitude_short => 'אורך';

  @override
  String get enum_diveField_tripName_short => 'טיול';

  @override
  String get enum_diveField_ratingStars_short => 'דירוג';

  @override
  String get enum_diveField_isFavorite_short => 'מועדף';

  @override
  String get enum_diveField_notes_short => 'הערות';

  @override
  String get enum_diveField_tags_short => 'תגיות';

  @override
  String get enum_diveField_importSource_short => 'מקור';

  @override
  String get enum_diveField_diveTypeName_short => 'סוג';

  @override
  String get enum_diveField_surfaceInterval_short => 'מרווח';

  @override
  String get enum_siteField_siteName => 'שם';

  @override
  String get enum_siteField_location => 'מיקום';

  @override
  String get enum_siteField_country => 'מדינה';

  @override
  String get enum_siteField_region => 'אזור';

  @override
  String get enum_siteField_city => 'עיר';

  @override
  String get enum_siteField_island => 'אי';

  @override
  String get enum_siteField_bodyOfWater => 'מקווה מים';

  @override
  String get enum_siteField_diveCount => 'מספר צלילות';

  @override
  String get enum_siteField_maxDepth => 'עומק מרבי';

  @override
  String get enum_siteField_minDepth => 'עומק מזערי';

  @override
  String get enum_siteField_altitude => 'גובה';

  @override
  String get enum_siteField_waterType => 'סוג מים';

  @override
  String get enum_siteField_typicalVisibility => 'ראות אופיינית';

  @override
  String get enum_siteField_typicalCurrent => 'זרם אופייני';

  @override
  String get enum_siteField_difficulty => 'רמת קושי';

  @override
  String get enum_siteField_entryType => 'סוג כניסה';

  @override
  String get enum_siteField_bestSeason => 'עונה מיטבית';

  @override
  String get enum_siteField_mooringNumber => 'מספר עגינה';

  @override
  String get enum_siteField_hazards => 'סכנות';

  @override
  String get enum_siteField_rating => 'דירוג';

  @override
  String get enum_siteField_notes => 'הערות';

  @override
  String get enum_siteField_latitude => 'קו רוחב';

  @override
  String get enum_siteField_longitude => 'קו אורך';

  @override
  String get enum_siteField_siteName_short => 'שם';

  @override
  String get enum_siteField_location_short => 'מיקום';

  @override
  String get enum_siteField_country_short => 'מדינה';

  @override
  String get enum_siteField_region_short => 'אזור';

  @override
  String get enum_siteField_city_short => 'עיר';

  @override
  String get enum_siteField_island_short => 'אי';

  @override
  String get enum_siteField_bodyOfWater_short => 'מקווה מים';

  @override
  String get enum_siteField_diveCount_short => 'צלילות';

  @override
  String get enum_siteField_maxDepth_short => 'ע. מרבי';

  @override
  String get enum_siteField_minDepth_short => 'ע. מזערי';

  @override
  String get enum_siteField_altitude_short => 'גובה';

  @override
  String get enum_siteField_waterType_short => 'מים';

  @override
  String get enum_siteField_typicalVisibility_short => 'ראות';

  @override
  String get enum_siteField_typicalCurrent_short => 'זרם';

  @override
  String get enum_siteField_difficulty_short => 'קושי';

  @override
  String get enum_siteField_entryType_short => 'כניסה';

  @override
  String get enum_siteField_exitMethod => 'שיטת יציאה';

  @override
  String get enum_siteField_exitMethod_short => 'יציאה';

  @override
  String get enum_siteField_bestSeason_short => 'עונה';

  @override
  String get enum_siteField_mooringNumber_short => 'עגינה';

  @override
  String get enum_siteField_hazards_short => 'סכנות';

  @override
  String get enum_siteField_rating_short => 'דירוג';

  @override
  String get enum_siteField_notes_short => 'הערות';

  @override
  String get enum_siteField_latitude_short => 'רוחב';

  @override
  String get enum_siteField_longitude_short => 'אורך';

  @override
  String get enum_siteField_depthRange => 'טווח עומק';

  @override
  String get enum_siteField_depthRange_short => 'עומק';

  @override
  String get enum_siteField_lastDived => 'צלילה אחרונה';

  @override
  String get enum_siteField_lastDived_short => 'אחרונה';

  @override
  String get enum_siteField_maxDepthReached => 'העומק המרבי שלך';

  @override
  String get enum_siteField_maxDepthReached_short => 'המרבי שלך';

  @override
  String get enum_buddyField_buddyName => 'שם';

  @override
  String get enum_buddyField_email => 'דוא\"ל';

  @override
  String get enum_buddyField_phone => 'טלפון';

  @override
  String get enum_buddyField_certificationLevel => 'רמת הסמכה';

  @override
  String get enum_buddyField_certificationAgency => 'גוף הסמכה';

  @override
  String get enum_buddyField_diveCount => 'מספר צלילות';

  @override
  String get enum_buddyField_notes => 'הערות';

  @override
  String get enum_buddyField_buddyName_short => 'שם';

  @override
  String get enum_buddyField_email_short => 'דוא\"ל';

  @override
  String get enum_buddyField_phone_short => 'טלפון';

  @override
  String get enum_buddyField_certificationLevel_short => 'רמת הסמכה';

  @override
  String get enum_buddyField_certificationAgency_short => 'גוף';

  @override
  String get enum_buddyField_diveCount_short => 'צלילות';

  @override
  String get enum_buddyField_notes_short => 'הערות';

  @override
  String get enum_buddyField_lastDive => 'צלילה אחרונה';

  @override
  String get enum_buddyField_lastDive_short => 'אחרונה';

  @override
  String get enum_tripField_tripName => 'שם';

  @override
  String get enum_tripField_startDate => 'תאריך התחלה';

  @override
  String get enum_tripField_endDate => 'תאריך סיום';

  @override
  String get enum_tripField_durationDays => 'משך';

  @override
  String get enum_tripField_location => 'מיקום';

  @override
  String get enum_tripField_tripType => 'סוג טיול';

  @override
  String get enum_tripField_resortName => 'אתר נופש';

  @override
  String get enum_tripField_liveaboardName => 'ספינת צלילה';

  @override
  String get enum_tripField_diveCount => 'מספר צלילות';

  @override
  String get enum_tripField_totalRuntime => 'סה\"כ זמן ריצה';

  @override
  String get enum_tripField_maxDepth => 'עומק מרבי';

  @override
  String get enum_tripField_avgDepth => 'עומק ממוצע';

  @override
  String get enum_tripField_notes => 'הערות';

  @override
  String get enum_tripField_tripName_short => 'שם';

  @override
  String get enum_tripField_startDate_short => 'התחלה';

  @override
  String get enum_tripField_endDate_short => 'סיום';

  @override
  String get enum_tripField_durationDays_short => 'ימים';

  @override
  String get enum_tripField_location_short => 'מיקום';

  @override
  String get enum_tripField_tripType_short => 'סוג';

  @override
  String get enum_tripField_resortName_short => 'נופש';

  @override
  String get enum_tripField_liveaboardName_short => 'ספינה';

  @override
  String get enum_tripField_diveCount_short => 'צלילות';

  @override
  String get enum_tripField_totalRuntime_short => 'סה\"כ ריצה';

  @override
  String get enum_tripField_maxDepth_short => 'ע. מרבי';

  @override
  String get enum_tripField_avgDepth_short => 'ע. ממוצע';

  @override
  String get enum_tripField_notes_short => 'הערות';

  @override
  String get enum_equipmentField_itemName => 'שם';

  @override
  String get enum_equipmentField_fullName => 'שם מלא';

  @override
  String get enum_equipmentField_type => 'סוג';

  @override
  String get enum_equipmentField_brand => 'מותג';

  @override
  String get enum_equipmentField_model => 'דגם';

  @override
  String get enum_equipmentField_serialNumber => 'מספר סידורי';

  @override
  String get enum_equipmentField_size => 'מידה';

  @override
  String get enum_equipmentField_status => 'סטטוס';

  @override
  String get enum_equipmentField_isActive => 'פעיל';

  @override
  String get enum_equipmentField_purchaseDate => 'תאריך רכישה';

  @override
  String get enum_equipmentField_purchasePrice => 'מחיר רכישה';

  @override
  String get enum_equipmentField_lastServiceDate => 'טיפול אחרון';

  @override
  String get enum_equipmentField_nextServiceDue => 'הטיפול הבא';

  @override
  String get enum_equipmentField_daysUntilService => 'ימים עד הטיפול';

  @override
  String get enum_equipmentField_serviceIntervalDays => 'מרווח טיפול';

  @override
  String get enum_equipmentField_notes => 'הערות';

  @override
  String get enum_equipmentField_itemName_short => 'שם';

  @override
  String get enum_equipmentField_fullName_short => 'שם מלא';

  @override
  String get enum_equipmentField_type_short => 'סוג';

  @override
  String get enum_equipmentField_brand_short => 'מותג';

  @override
  String get enum_equipmentField_model_short => 'דגם';

  @override
  String get enum_equipmentField_serialNumber_short => 'סידורי';

  @override
  String get enum_equipmentField_size_short => 'מידה';

  @override
  String get enum_equipmentField_status_short => 'סטטוס';

  @override
  String get enum_equipmentField_isActive_short => 'פעיל';

  @override
  String get enum_equipmentField_purchaseDate_short => 'נרכש';

  @override
  String get enum_equipmentField_purchasePrice_short => 'מחיר';

  @override
  String get enum_equipmentField_lastServiceDate_short => 'טופל';

  @override
  String get enum_equipmentField_nextServiceDue_short => 'טיפול הבא';

  @override
  String get enum_equipmentField_daysUntilService_short => 'ימים נותרו';

  @override
  String get enum_equipmentField_serviceIntervalDays_short => 'מרווח';

  @override
  String get enum_equipmentField_notes_short => 'הערות';

  @override
  String get enum_diveCenterField_centerName => 'שם';

  @override
  String get enum_diveCenterField_city => 'עיר';

  @override
  String get enum_diveCenterField_country => 'מדינה';

  @override
  String get enum_diveCenterField_stateProvince => 'מדינה / מחוז';

  @override
  String get enum_diveCenterField_street => 'רחוב';

  @override
  String get enum_diveCenterField_postalCode => 'מיקוד';

  @override
  String get enum_diveCenterField_phone => 'טלפון';

  @override
  String get enum_diveCenterField_email => 'דוא\"ל';

  @override
  String get enum_diveCenterField_website => 'אתר אינטרנט';

  @override
  String get enum_diveCenterField_affiliations => 'השתייכויות';

  @override
  String get enum_diveCenterField_rating => 'דירוג';

  @override
  String get enum_diveCenterField_latitude => 'קו רוחב';

  @override
  String get enum_diveCenterField_longitude => 'קו אורך';

  @override
  String get enum_diveCenterField_diveCount => 'מספר צלילות';

  @override
  String get enum_diveCenterField_notes => 'הערות';

  @override
  String get enum_diveCenterField_centerName_short => 'שם';

  @override
  String get enum_diveCenterField_city_short => 'עיר';

  @override
  String get enum_diveCenterField_country_short => 'מדינה';

  @override
  String get enum_diveCenterField_stateProvince_short => 'מחוז';

  @override
  String get enum_diveCenterField_street_short => 'רחוב';

  @override
  String get enum_diveCenterField_postalCode_short => 'מיקוד';

  @override
  String get enum_diveCenterField_phone_short => 'טלפון';

  @override
  String get enum_diveCenterField_email_short => 'דוא\"ל';

  @override
  String get enum_diveCenterField_website_short => 'אתר';

  @override
  String get enum_diveCenterField_affiliations_short => 'השתייכויות';

  @override
  String get enum_diveCenterField_rating_short => 'דירוג';

  @override
  String get enum_diveCenterField_latitude_short => 'רוחב';

  @override
  String get enum_diveCenterField_longitude_short => 'אורך';

  @override
  String get enum_diveCenterField_diveCount_short => 'צלילות';

  @override
  String get enum_diveCenterField_notes_short => 'הערות';

  @override
  String get enum_certificationField_certName => 'שם';

  @override
  String get enum_certificationField_agency => 'גוף הסמכה';

  @override
  String get enum_certificationField_level => 'הסמכה';

  @override
  String get enum_certificationField_cardNumber => 'מספר כרטיס';

  @override
  String get enum_certificationField_issueDate => 'תאריך הנפקה';

  @override
  String get enum_certificationField_expiryDate => 'תאריך תפוגה';

  @override
  String get enum_certificationField_instructorName => 'שם המדריך';

  @override
  String get enum_certificationField_instructorNumber => 'מספר המדריך';

  @override
  String get enum_certificationField_expiryStatus => 'סטטוס תפוגה';

  @override
  String get enum_certificationField_notes => 'הערות';

  @override
  String get enum_certificationField_certName_short => 'שם';

  @override
  String get enum_certificationField_agency_short => 'גוף';

  @override
  String get enum_certificationField_level_short => 'הסמכה';

  @override
  String get enum_certificationField_cardNumber_short => 'כרטיס #';

  @override
  String get enum_certificationField_issueDate_short => 'הונפק';

  @override
  String get enum_certificationField_expiryDate_short => 'תפוגה';

  @override
  String get enum_certificationField_instructorName_short => 'מדריך';

  @override
  String get enum_certificationField_instructorNumber_short => 'מדריך #';

  @override
  String get enum_certificationField_expiryStatus_short => 'סטטוס';

  @override
  String get enum_certificationField_notes_short => 'הערות';

  @override
  String get enum_courseField_courseName => 'שם';

  @override
  String get enum_courseField_agency => 'גוף הסמכה';

  @override
  String get enum_courseField_startDate => 'תאריך התחלה';

  @override
  String get enum_courseField_completionDate => 'תאריך השלמה';

  @override
  String get enum_courseField_durationDays => 'משך';

  @override
  String get enum_courseField_instructorName => 'שם המדריך';

  @override
  String get enum_courseField_instructorNumber => 'מספר המדריך';

  @override
  String get enum_courseField_location => 'מיקום';

  @override
  String get enum_courseField_isCompleted => 'הושלם';

  @override
  String get enum_courseField_notes => 'הערות';

  @override
  String get enum_courseField_courseName_short => 'שם';

  @override
  String get enum_courseField_agency_short => 'גוף';

  @override
  String get enum_courseField_startDate_short => 'התחיל';

  @override
  String get enum_courseField_completionDate_short => 'הושלם';

  @override
  String get enum_courseField_durationDays_short => 'משך';

  @override
  String get enum_courseField_instructorName_short => 'מדריך';

  @override
  String get enum_courseField_instructorNumber_short => 'מדריך #';

  @override
  String get enum_courseField_location_short => 'מיקום';

  @override
  String get enum_courseField_isCompleted_short => 'בוצע';

  @override
  String get enum_courseField_notes_short => 'הערות';

  @override
  String get enum_fieldCategory_accommodation => 'לינה';

  @override
  String get enum_fieldCategory_address => 'כתובת';

  @override
  String get enum_fieldCategory_certification => 'הסמכה';

  @override
  String get enum_fieldCategory_conditions => 'תנאים';

  @override
  String get enum_fieldCategory_contact => 'יצירת קשר';

  @override
  String get enum_fieldCategory_coordinates => 'קואורדינטות';

  @override
  String get enum_fieldCategory_dates => 'תאריכים';

  @override
  String get enum_fieldCategory_depth => 'עומק';

  @override
  String get enum_fieldCategory_details => 'פרטים';

  @override
  String get enum_fieldCategory_instructor => 'מדריך';

  @override
  String get enum_fieldCategory_other => 'אחר';

  @override
  String get enum_fieldCategory_purchase => 'רכישה';

  @override
  String get enum_fieldCategory_service => 'טיפול';

  @override
  String get enum_fieldCategory_statistics => 'סטטיסטיקות';

  @override
  String get species_whale_shark_name => 'כריש לווייתן';

  @override
  String get species_whale_shark_desc =>
      'הדג הגדול ביותר באוקיינוס, מסנן מזון עדין בעל דוגמת נקודות ייחודית.';

  @override
  String get species_great_white_shark_name => 'כריש לבן';

  @override
  String get species_great_white_shark_desc =>
      'טורף-על אייקוני שנצפה מדי פעם על ידי צוללני כלוב במים ממוזגים.';

  @override
  String get species_great_hammerhead_shark_name => 'כריש פטיש גדול';

  @override
  String get species_great_hammerhead_shark_desc =>
      'מין כריש הפטיש הגדול ביותר, בעל ראש רחב ושטוח וסנפיר גב גבוה.';

  @override
  String get species_scalloped_hammerhead_shark_name => 'כריש פטיש משונן';

  @override
  String get species_scalloped_hammerhead_shark_desc =>
      'נצפה לעיתים קרובות בלהקות גדולות סביב הרי ים ותחנות ניקוי.';

  @override
  String get species_smooth_hammerhead_shark_name => 'כריש פטיש חלק';

  @override
  String get species_smooth_hammerhead_shark_desc =>
      'כריש פטיש בעל שולי ראש חלקים ומעוגלים, מצוי בימים ממוזגים.';

  @override
  String get species_whitetip_reef_shark_name => 'כריש שונית לבן-קצה';

  @override
  String get species_whitetip_reef_shark_desc =>
      'דייר שונית נוח שנמצא לרוב נח במערות ומתחת למדפי סלע במהלך היום.';

  @override
  String get species_blacktip_reef_shark_name => 'כריש שונית שחור-קצה';

  @override
  String get species_blacktip_reef_shark_desc =>
      'כריש שונית נפוץ במים רדודים, בעל קצות סנפירים שחורים אופייניים.';

  @override
  String get species_grey_reef_shark_name => 'כריש שונית אפור';

  @override
  String get species_grey_reef_shark_desc =>
      'טורף שונית פעיל שנפגשים בו לרוב בקבוצות לאורך מדרונות תלולים ותעלות.';

  @override
  String get species_caribbean_reef_shark_name => 'כריש שונית קריבי';

  @override
  String get species_caribbean_reef_shark_desc =>
      'כריש השונית הנפוץ ביותר בקריביים, חסון וסקרן.';

  @override
  String get species_nurse_shark_name => 'כריש אומנת';

  @override
  String get species_nurse_shark_desc =>
      'דייר קרקעית איטי שנמצא לרוב נח מתחת למדפי אלמוגים.';

  @override
  String get species_tawny_nurse_shark_name => 'כריש אומנת שחום';

  @override
  String get species_tawny_nurse_shark_desc =>
      'דייר קרקעית הודו-פסיפי הנח במערות שונית ובאזורי חול.';

  @override
  String get species_bull_shark_name => 'כריש שור';

  @override
  String get species_bull_shark_desc =>
      'כריש חסון ורב-עוצמה המצוי בסביבות חוף ובמים מתוקים בכל העולם.';

  @override
  String get species_tiger_shark_name => 'כריש טיגריס';

  @override
  String get species_tiger_shark_desc =>
      'טורף גדול בעל דוגמת פסים אופיינית, נפגש בצלילות שונית עמוקות.';

  @override
  String get species_oceanic_whitetip_shark_name => 'כריש לבן-קצה אוקייני';

  @override
  String get species_oceanic_whitetip_shark_desc =>
      'כריש פלגי בעל סנפירים מעוגלים לבני-קצה, נצפה בצלילות באוקיינוס הפתוח.';

  @override
  String get species_thresher_shark_name => 'כריש שועל';

  @override
  String get species_thresher_shark_desc =>
      'ניכר בסנפיר הזנב הארוך במיוחד שלו, ולעיתים נצפה בתחנות ניקוי.';

  @override
  String get species_pelagic_thresher_shark_name => 'כריש שועל פלגי';

  @override
  String get species_pelagic_thresher_shark_desc =>
      'המין הקטן ביותר בקרב כרישי השועל, מפורסם בתצפיות במונאד שול שבפיליפינים.';

  @override
  String get species_shortfin_mako_shark_name => 'כריש מאקו קצר-סנפיר';

  @override
  String get species_shortfin_mako_shark_desc =>
      'הכריש המהיר ביותר באוקיינוס, טורף מים פתוחים חלקלק בגוון כחול מתכתי.';

  @override
  String get species_blue_shark_name => 'כריש כחול';

  @override
  String get species_blue_shark_desc =>
      'כריש פלגי תמיר בגוון כחול עמוק, נפגש לעיתים קרובות בצלילות מים כחולים.';

  @override
  String get species_spotted_wobbegong_name => 'וובגונג מנוקד';

  @override
  String get species_spotted_wobbegong_desc =>
      'כריש שטיח שטוח ומוסווה השוכב ללא תנועה על שוניות סלע באוסטרליה.';

  @override
  String get species_tasselled_wobbegong_name => 'וובגונג מצויץ';

  @override
  String get species_tasselled_wobbegong_desc =>
      'כריש שטיח מקושט בעל אונות משוננות סביב הראש, מצוי בשוניות אלמוגים.';

  @override
  String get species_epaulette_shark_name => 'כריש כתפייה';

  @override
  String get species_epaulette_shark_desc =>
      'כריש קטן הצועד על קרקעית השונית בעזרת סנפירי החזה שלו.';

  @override
  String get species_horn_shark_name => 'כריש קרן';

  @override
  String get species_horn_shark_desc =>
      'דייר קרקעית לילי בעל רכסים מעל העיניים, מצוי מול חופי קליפורניה.';

  @override
  String get species_leopard_shark_name => 'כריש נמר';

  @override
  String get species_leopard_shark_desc =>
      'כריש בעל דוגמה יפהפייה המצוי במפרצים רדודים לאורך חופי האוקיינוס השקט של ארצות הברית.';

  @override
  String get species_pacific_angel_shark_name => 'כריש מלאך פסיפי';

  @override
  String get species_pacific_angel_shark_desc =>
      'טורף מארב שטוח-גוף השוכב טמון בחול על קרקעית הים.';

  @override
  String get species_sand_tiger_shark_name => 'כריש חול';

  @override
  String get species_sand_tiger_shark_desc =>
      'כריש בעל מראה מאיים אך אופי נוח, נצפה לעיתים קרובות מרחף במערות ובספינות טרופות.';

  @override
  String get species_zebra_shark_name => 'כריש זברה';

  @override
  String get species_zebra_shark_desc =>
      'כריש שונית מנוקד הנח על קרקעיות חול, נפוץ בהודו-פסיפי.';

  @override
  String get species_blacktip_shark_name => 'כריש שחור-קצה';

  @override
  String get species_blacktip_shark_desc =>
      'כריש חופי מהיר הידוע בקפיצות המסתובבות שלו, מצוי במים חמים בכל העולם.';

  @override
  String get species_silvertip_shark_name => 'כריש כסוף-קצה';

  @override
  String get species_silvertip_shark_desc =>
      'כריש שונית נועז בעל סנפירים לבני-שוליים, מצוי ליד מדרונות עמוקים ואטולים.';

  @override
  String get species_silky_shark_name => 'כריש משיי';

  @override
  String get species_silky_shark_desc =>
      'כריש פלגי חלקלק בעל עור חלק, מצוי לרוב סמוך לשוניות מרוחקות מהחוף.';

  @override
  String get species_lemon_shark_name => 'כריש לימון';

  @override
  String get species_lemon_shark_desc =>
      'כריש בגוון חום-צהבהב הנצפה לרוב במנגרובים רדודים ובמישורי חול.';

  @override
  String get species_galapagos_shark_name => 'כריש גלפגוס';

  @override
  String get species_galapagos_shark_desc =>
      'כריש שונית גדול המצוי סביב איים אוקייניים, סקרן כלפי צוללנים.';

  @override
  String get species_port_jackson_shark_name => 'כריש פורט ג\'קסון';

  @override
  String get species_port_jackson_shark_desc =>
      'דייר קרקעית לילי בעל סימנים דמויי רתמה, אנדמי לאוסטרליה.';

  @override
  String get species_bamboo_shark_name => 'כריש במבוק חום-פסים';

  @override
  String get species_bamboo_shark_desc =>
      'כריש קרקעית קטן ונוח, נפוץ בשוניות האלמוגים של ההודו-פסיפי.';

  @override
  String get species_basking_shark_name => 'כריש מתחמם';

  @override
  String get species_basking_shark_desc =>
      'הדג השני בגודלו בעולם, מסנן מזון הנצפה במים ממוזגים סמוך לפני השטח.';

  @override
  String get species_greenland_shark_name => 'כריש גרינלנד';

  @override
  String get species_greenland_shark_desc =>
      'כריש מים עמוקים איטי, אחד מבעלי החוליות המאריכים ימים ביותר על פני כדור הארץ.';

  @override
  String get species_cookiecutter_shark_name => 'כריש חותך העוגיות';

  @override
  String get species_cookiecutter_shark_desc =>
      'כריש מים עמוקים קטן הנוגס נגיסות עגולות מבעלי חיים ימיים גדולים ממנו.';

  @override
  String get species_sevengill_shark_name => 'כריש שבעת הזימים רחב-חוטם';

  @override
  String get species_sevengill_shark_desc =>
      'כריש קדום בעל שבעה חריצי זימים, נפגש בצלילות ביערות קלפ ממוזגים.';

  @override
  String get species_pyjama_shark_name => 'כריש פיג\'מה';

  @override
  String get species_pyjama_shark_desc =>
      'כריש חתול מפוספס האנדמי לדרום אפריקה, מצוי בשוניות סלע וביערות קלפ.';

  @override
  String get species_spiny_dogfish_name => 'כלבתן קוצני';

  @override
  String get species_spiny_dogfish_desc =>
      'כריש קטן ונפוץ בעל קוצי גב ארסיים, מצוי במים ממוזגים.';

  @override
  String get species_swell_shark_name => 'כריש מתנפח';

  @override
  String get species_swell_shark_desc =>
      'כריש חתול לילי המנפח את גופו כשהוא מאוים, מצוי מול חופי קליפורניה.';

  @override
  String get species_giant_oceanic_manta_ray_name => 'מנטה אוקיינית ענקית';

  @override
  String get species_giant_oceanic_manta_ray_desc =>
      'מין הטריגון הגדול ביותר, מסנן מזון מלכותי בעל מוטת כנפיים של עד 7 מטרים.';

  @override
  String get species_reef_manta_ray_name => 'מנטת שונית';

  @override
  String get species_reef_manta_ray_desc =>
      'מין מנטה קטן יותר הנצפה לרוב בתחנות ניקוי בשוניות טרופיות.';

  @override
  String get species_spotted_eagle_ray_name => 'טריגון נשר מנוקד';

  @override
  String get species_spotted_eagle_ray_desc =>
      'טריגון אלגנטי בעל נקודות לבנות וזנב ארוך דמוי שוט, נצפה לרוב באמצע המים.';

  @override
  String get species_common_eagle_ray_name => 'טריגון נשר מצוי';

  @override
  String get species_common_eagle_ray_desc =>
      'טריגון בצורת מעוין המצוי במים הממוזגים של מזרח האוקיינוס האטלנטי ושל הים התיכון.';

  @override
  String get species_blue_spotted_ribbontail_ray_name =>
      'טריגון סרט-זנב כחול-נקודות';

  @override
  String get species_blue_spotted_ribbontail_ray_desc =>
      'טריגון עז-צבעים בעל נקודות כחולות זוהרות, נפוץ בשוניות ההודו-פסיפי.';

  @override
  String get species_blue_spotted_stingray_name => 'טריגון כחול-נקודות';

  @override
  String get species_blue_spotted_stingray_desc =>
      'טריגון שונית קטן בעל נקודות כחולות פזורות, טמון לעיתים קרובות בכתמי חול.';

  @override
  String get species_southern_stingray_name => 'טריגון דרומי';

  @override
  String get species_southern_stingray_desc =>
      'טריגון גדול המצוי במישורי החול של הקריביים, מפורסם באתר סטינגריי סיטי.';

  @override
  String get species_round_stingray_name => 'טריגון עגול';

  @override
  String get species_round_stingray_desc =>
      'טריגון עגול קטן, נפוץ באזורי חול רדודים במזרח האוקיינוס השקט.';

  @override
  String get species_short_tail_stingray_name => 'טריגון קצר-זנב';

  @override
  String get species_short_tail_stingray_desc =>
      'אחד הטריגונים הגדולים בעולם, מצוי במים ממוזגים של חצי הכדור הדרומי.';

  @override
  String get species_cowtail_stingray_name => 'טריגון זנב-פרה';

  @override
  String get species_cowtail_stingray_desc =>
      'טריגון כהה וגדול בעל קפל זנב אופייני דמוי דגל, מצוי בשוניות חוליות.';

  @override
  String get species_atlantic_torpedo_ray_name => 'טריגון חשמלי אטלנטי';

  @override
  String get species_atlantic_torpedo_ray_desc =>
      'טריגון חשמלי המסוגל לייצר מכות חשמל חזקות, מצוי בקרקעיות חול באוקיינוס האטלנטי.';

  @override
  String get species_marbled_electric_ray_name => 'טריגון חשמלי משויש';

  @override
  String get species_marbled_electric_ray_desc =>
      'טריגון חשמלי ים-תיכוני בעל דוגמת שיש, ומכת החשמל שלו מורגשת היטב.';

  @override
  String get species_giant_guitarfish_name => 'דג גיטרה ענק';

  @override
  String get species_giant_guitarfish_desc =>
      'טריגון בעל צורת כריש המצוי בקרקעיות חול בהודו-פסיפי סמוך לשוניות אלמוגים.';

  @override
  String get species_shovelnose_guitarfish_name => 'דג גיטרה חוטם-את';

  @override
  String get species_shovelnose_guitarfish_desc =>
      'בעל מבנה שטוח המשלב מראה של כריש וטריגון, נפוץ ברדודי החול של מזרח האוקיינוס השקט.';

  @override
  String get species_smalltooth_sawfish_name => 'דג מסור קטן-שיניים';

  @override
  String get species_smalltooth_sawfish_desc =>
      'טריגון בסכנת הכחדה חמורה בעל מסור משונן בקדמת הראש, מצוי במים חופיים טרופיים.';

  @override
  String get species_green_sawfish_name => 'דג מסור ירוק';

  @override
  String get species_green_sawfish_desc =>
      'דג מסור גדול בעל גוף ירוק-זית, החי בשפכי נהרות בהודו-מערב פסיפי.';

  @override
  String get species_devil_ray_name => 'טריגון שטן ענק';

  @override
  String get species_devil_ray_desc =>
      'מובולה גדולה בעלת סנפירי ראש, נצפית קופצת מהמים בקבוצות.';

  @override
  String get species_spinetail_devil_ray_name => 'טריגון שטן קוץ-זנב';

  @override
  String get species_spinetail_devil_ray_desc =>
      'טריגון שטן פלגי הנצפה לעיתים קרובות בהתקהלויות גדולות סמוך לפני המים.';

  @override
  String get species_lesser_devil_ray_name => 'טריגון שטן גמדי';

  @override
  String get species_lesser_devil_ray_desc =>
      'מין המובולה הקטן ביותר, יוצר להקות גדולות במפרץ קליפורניה.';

  @override
  String get species_bat_ray_name => 'טריגון עטלף';

  @override
  String get species_bat_ray_desc =>
      'טריגון בצורת מעוין, נפוץ ביערות הקלפ ובמפרצי החול של קליפורניה.';

  @override
  String get species_undulate_ray_name => 'טריגון גלי';

  @override
  String get species_undulate_ray_desc =>
      'טריגון בעל דוגמת קווים גליים יפהפייה, מצוי במזרח האוקיינוס האטלנטי.';

  @override
  String get species_thornback_ray_name => 'טריגון קוצני';

  @override
  String get species_thornback_ray_desc =>
      'טריגון אירופי נפוץ בעל קוצים חדים לאורך הגב והזנב.';

  @override
  String get species_cownose_ray_name => 'טריגון אף-פרה';

  @override
  String get species_cownose_ray_desc =>
      'ניכר בראשו המחורץ, ונצפה לרוב בלהקות גדולות בעת נדידות עונתיות.';

  @override
  String get species_marble_ray_name => 'טריגון משויש';

  @override
  String get species_marble_ray_desc =>
      'טריגון כהה וגדול בעל נקודות לבנות, נצפה תכופות בתחנות ניקוי בהודו-פסיפי.';

  @override
  String get species_ocellate_river_stingray_name => 'טריגון נהרות עינוני';

  @override
  String get species_ocellate_river_stingray_desc =>
      'טריגון מים מתוקים בעל נקודות מוקפות טבעות כתומות בולטות, מקורו בנהרות דרום אמריקה.';

  @override
  String get species_ocellaris_clownfish_name => 'דג ליצן מצוי';

  @override
  String get species_ocellaris_clownfish_desc =>
      'דג קטן בפסים כתומים ולבנים החי בסימביוזה עם שושנות ים בשוניות אלמוגים.';

  @override
  String get species_clarkii_clownfish_name => 'דג ליצן של קלארק';

  @override
  String get species_clarkii_clownfish_desc =>
      'דג שושנון עמיד בעל גוף כהה ושני פסים לבנים, מצוי ברחבי ההודו-פסיפי במגוון מיני שושנות ים.';

  @override
  String get species_tomato_clownfish_name => 'דג ליצן עגבנייה';

  @override
  String get species_tomato_clownfish_desc =>
      'דג שושנון בגוון אדום-כתום עז עם פס לבן יחיד בראש, נפוץ בשוניות ההודו-פסיפי.';

  @override
  String get species_regal_blue_tang_name => 'דג כירורג כחול מלכותי';

  @override
  String get species_regal_blue_tang_desc =>
      'דג כירורג בכחול עז בעל סימן שחור דמוי לוח צבעים וזנב צהוב, מצוי בשוניות האלמוגים של ההודו-פסיפי.';

  @override
  String get species_yellow_tang_name => 'דג כירורג צהוב';

  @override
  String get species_yellow_tang_desc =>
      'דג כירורג בצהוב עז הנפוץ בשוניות הוואי והאוקיינוס השקט, נצפה לרוב רועה אצות בקבוצות.';

  @override
  String get species_powder_blue_surgeonfish_name => 'דג כירורג תכול';

  @override
  String get species_powder_blue_surgeonfish_desc =>
      'דג כירורג תכול ומרשים בעל פנים שחורות וסנפיר גב צהוב, מצוי באוקיינוס ההודי.';

  @override
  String get species_sohal_surgeonfish_name => 'דג כירורג ים סוף';

  @override
  String get species_sohal_surgeonfish_desc =>
      'דג כירורג מפוספס ונועז בעל קוץ אזמל כתום, אנדמי לשוניות ים סוף והמפרץ הערבי.';

  @override
  String get species_blue_tang_name => 'דג כירורג כחול';

  @override
  String get species_blue_tang_desc =>
      'דג כירורג בגוון כחול עמוק הנפוץ בשוניות הקריביים; הצעירים צהובים בוהקים.';

  @override
  String get species_emperor_angelfish_name => 'דג מלאך קיסרי';

  @override
  String get species_emperor_angelfish_desc =>
      'דג מלאך גדול בעל פסים אופקיים כחולים וצהובים מרשימים; הצעירים מציגים מעגלים קונצנטריים כחולים ולבנים.';

  @override
  String get species_french_angelfish_name => 'דג מלאך צרפתי';

  @override
  String get species_french_angelfish_desc =>
      'דג מלאך גדול וכהה בעל קשקשים משוליים בזהב, נצפה לרוב בזוגות בשוניות הקריביים ומערב האטלנטי.';

  @override
  String get species_queen_angelfish_name => 'דג מלאך מלכה';

  @override
  String get species_queen_angelfish_desc =>
      'דג מלאך מרהיב בכחול וצהוב בעל כתם כתר אופייני, מצוי בשוניות האלמוגים של הקריביים.';

  @override
  String get species_regal_angelfish_name => 'דג מלאך מלכותי';

  @override
  String get species_regal_angelfish_desc =>
      'דג מלאך אלגנטי בעל פסים אנכיים לסירוגין בכתום-לבן ובכחול, מצוי בשוניות ההודו-פסיפי.';

  @override
  String get species_rock_beauty_name => 'יפהפיית הסלעים';

  @override
  String get species_rock_beauty_desc =>
      'דג מלאך קריבי מרשים שחציו הקדמי צהוב וחציו האחורי שחור, מצוי ליד שוניות סלע ומדפי סלע.';

  @override
  String get species_gray_angelfish_name => 'דג מלאך אפור';

  @override
  String get species_gray_angelfish_desc =>
      'דג מלאך אפור וגדול בעל פנים בהירות וצדם הפנימי הצהוב של סנפירי החזה, נפוץ בשוניות הקריביים.';

  @override
  String get species_copperband_butterflyfish_name => 'דג פרפר נחושת-פסים';

  @override
  String get species_copperband_butterflyfish_desc =>
      'דג פרפר ייחודי בעל פסים אנכיים כתומים וחרטום מוארך, מצוי בשוניות ההודו-פסיפי.';

  @override
  String get species_raccoon_butterflyfish_name => 'דג פרפר רקון';

  @override
  String get species_raccoon_butterflyfish_desc =>
      'דג פרפר צהוב בעל מסכת עיניים כהה דמוית רקון, נפוץ בשוניות ההודו-פסיפי והוואי.';

  @override
  String get species_longnose_butterflyfish_name => 'דג פרפר ארוך-חרטום';

  @override
  String get species_longnose_butterflyfish_desc =>
      'דג פרפר צהוב בוהק בעל חרטום ארוך במיוחד שבעזרתו הוא לוקט מזון מנקיקים בשוניות ההודו-פסיפי.';

  @override
  String get species_threadfin_butterflyfish_name => 'דג פרפר חוטי-סנפיר';

  @override
  String get species_threadfin_butterflyfish_desc =>
      'דג פרפר לבן בעל דוגמת שברונים וחוט נגרר בסנפיר הגב, נפוץ ברחבי ההודו-פסיפי.';

  @override
  String get species_foureye_butterflyfish_name => 'דג פרפר ארבע-עיניים';

  @override
  String get species_foureye_butterflyfish_desc =>
      'דג פרפר בהיר בעל כתם עין מדומה בולט סמוך לזנב, נפוץ בשוניות הקריביים.';

  @override
  String get species_spotfin_butterflyfish_name => 'דג פרפר מנוקד-סנפיר';

  @override
  String get species_spotfin_butterflyfish_desc =>
      'דג פרפר לבן-צהוב בעל כתם כהה קטן על סנפיר הגב, מצוי במערב האוקיינוס האטלנטי.';

  @override
  String get species_banner_butterflyfish_name => 'דגלן ים סוף';

  @override
  String get species_banner_butterflyfish_desc =>
      'דגלן שחור-לבן בעל סנפיר גב מוארך ובטן צהובה, אנדמי לים סוף.';

  @override
  String get species_moorish_idol_name => 'אליל מורי';

  @override
  String get species_moorish_idol_desc =>
      'דג שונית אייקוני בעל פסים נועזים בשחור, לבן וצהוב וחוט ארוך נגרר בסנפיר הגב.';

  @override
  String get species_green_moray_eel_name => 'מורנה ירוקה';

  @override
  String get species_green_moray_eel_desc =>
      'מורנה ירוקה גדולה המגיעה ל-2.5 מטר, נצפית לרוב בפה פעור בנקיקי שונית ברחבי מערב האטלנטי.';

  @override
  String get species_giant_moray_eel_name => 'מורנה ענקית';

  @override
  String get species_giant_moray_eel_desc =>
      'מין המורנה הגדול ביותר, מגיע ליותר מ-3 מטרים ומעוטר בכתמים דמויי נמר, ומצוי בשוניות האלמוגים של ההודו-פסיפי.';

  @override
  String get species_spotted_moray_eel_name => 'מורנה מנוקדת';

  @override
  String get species_spotted_moray_eel_desc =>
      'מורנה לבנה בעלת נקודות חום כהה, נצפית לרוב מציצה מחורי השונית בקריביים.';

  @override
  String get species_ribbon_eel_name => 'צלופח סרט';

  @override
  String get species_ribbon_eel_desc =>
      'צלופח תמיר בעל נחיריים מתרחבים; הזכרים כחולים עזים והנקבות צהובות, והוא מצוי בלגונות חול בהודו-פסיפי.';

  @override
  String get species_spotted_garden_eel_name => 'צלופח גן מנוקד';

  @override
  String get species_spotted_garden_eel_desc =>
      'צלופח דק ולבן בנקודות שחורות החי במושבות בקרקעית חול ומתנועע בזרם כדי ללכוד פלנקטון.';

  @override
  String get species_splendid_garden_eel_name => 'צלופח גן מפואר';

  @override
  String get species_splendid_garden_eel_desc =>
      'צלופח גן בפסים כתומים ולבנים, מצוי במושבות חול גדולות במערב האוקיינוס השקט.';

  @override
  String get species_snowflake_moray_name => 'מורנת פתית שלג';

  @override
  String get species_snowflake_moray_desc =>
      'מורנה קטנה בעלת גוף לבן וסימנים שחורים דמויי פתיתי שלג, נפוצה בשברי אלמוגים בהודו-פסיפי.';

  @override
  String get species_mandarin_dragonet_name => 'דרקונית מנדרין';

  @override
  String get species_mandarin_dragonet_desc =>
      'דג זעיר וצבעוני להפליא בדוגמאות פסיכדליות של כחול וכתום, מצוי באזורי שברי אלמוגים במערב האוקיינוס השקט.';

  @override
  String get species_common_lionfish_name => 'דג אריה מצוי';

  @override
  String get species_common_lionfish_desc =>
      'דג עקרב ארסי בעל סנפירי חזה מרהיבים דמויי מניפה ופסים אדומים ולבנים, ומין פולש בקריביים.';

  @override
  String get species_leaf_scorpionfish_name => 'דג עקרב עלה';

  @override
  String get species_leaf_scorpionfish_desc =>
      'דג עקרב שטוח מאוד בצורת עלה, מתנועע עם הזרם כדי להיראות כשריד צמחי נסחף בשוניות ההודו-פסיפי.';

  @override
  String get species_stonefish_name => 'דג אבן';

  @override
  String get species_stonefish_desc =>
      'הדג הארסי ביותר בעולם, מוסווה להפליא כסלע על קרקעיות השונית בהודו-פסיפי ומסוכן ביותר.';

  @override
  String get species_painted_frogfish_name => 'דג צפרדע מצויר';

  @override
  String get species_painted_frogfish_desc =>
      'טורף מארב מגושם בעל פתיון על ראשו, צבעו משתנה מאוד, והוא מצוי בשוניות ההודו-פסיפי.';

  @override
  String get species_giant_frogfish_name => 'דג צפרדע ענק';

  @override
  String get species_giant_frogfish_desc =>
      'מין דג הצפרדע הגדול ביותר, מגיע ל-40 ס\"מ ומצטיין בהסוואה בין ספוגים ושברי אלמוגים.';

  @override
  String get species_hairy_frogfish_name => 'דג צפרדע שעיר';

  @override
  String get species_hairy_frogfish_desc =>
      'דג צפרדע המכוסה בתוספות בשרניות דמויות תולעים המחקות אצות, מציאה נחשקת לצלמי תת-מים.';

  @override
  String get species_clown_triggerfish_name => 'דג הדק ליצן';

  @override
  String get species_clown_triggerfish_desc =>
      'דג הדק בעל דוגמה נועזת של נקודות לבנות גדולות על גוף כהה ושפתיים צהובות, מצוי בשוניות ההודו-פסיפי.';

  @override
  String get species_titan_triggerfish_name => 'דג הדק טיטאן';

  @override
  String get species_titan_triggerfish_desc =>
      'דג הדק גדול ותוקפני הידוע בהסתערות על צוללנים בקרבת הקן שלו, ונפוץ בשוניות האלמוגים של ההודו-פסיפי.';

  @override
  String get species_queen_triggerfish_name => 'דג הדק מלכותי';

  @override
  String get species_queen_triggerfish_desc =>
      'דג הדק קריבי צבעוני בעל סימנים כחולים בפנים וסרטי זנב ארוכים.';

  @override
  String get species_picasso_triggerfish_name => 'דג הדק פיקאסו';

  @override
  String get species_picasso_triggerfish_desc =>
      'דג הדק בעל דוגמה מופשטת של פסים כחולים, צהובים ושחורים, נפוץ במישורי השונית של ההודו-פסיפי.';

  @override
  String get species_yellowmargin_triggerfish_name => 'דג הדק צהוב-שוליים';

  @override
  String get species_yellowmargin_triggerfish_desc =>
      'דג הדק גדול בגוון חום בהיר ובעל סנפירים משוליים בצהוב, ידוע בשמירה תוקפנית על הקן בשוניות ההודו-פסיפי.';

  @override
  String get species_porcupinefish_name => 'דג דורבן';

  @override
  String get species_porcupinefish_desc =>
      'דג קוצני גדול המתנפח לכדור כשהוא מאוים, מצוי בשוניות טרופיות בכל העולם.';

  @override
  String get species_guineafowl_pufferfish_name => 'דג נפוח פנינייה';

  @override
  String get species_guineafowl_pufferfish_desc =>
      'דג נפוח כהה המכוסה בנקודות לבנות קטנות, ולעיתים מופיע בגוון זהוב-צהוב בשוניות ההודו-פסיפי.';

  @override
  String get species_map_pufferfish_name => 'דג נפוח מפה';

  @override
  String get species_map_pufferfish_desc =>
      'דג נפוח בהיר וגדול בעל סימנים כהים ומורכבים דמויי מפה על גופו, מצוי בשוניות ההודו-פסיפי.';

  @override
  String get species_sharpnose_pufferfish_name => 'דג נפוח חד-חרטום';

  @override
  String get species_sharpnose_pufferfish_desc =>
      'דג נפוח זעיר בעל קווים כחולים בפנים וזנב כתום, נצפה לרוב בשוניות הקריביים.';

  @override
  String get species_boxfish_name => 'דג קופסה צהוב';

  @override
  String get species_boxfish_desc =>
      'הצעירים הם קוביות צהובות בוהקות בנקודות שחורות והבוגרים מכהים לכחול-אפור, והמין מצוי ברחבי ההודו-פסיפי.';

  @override
  String get species_cowfish_name => 'דג פרה ארוך-קרניים';

  @override
  String get species_cowfish_desc =>
      'דג צהוב ומרובע בעל בליטות אופייניות דמויות קרניים מעל כל עין, מצוי בשוניות ההודו-פסיפי.';

  @override
  String get species_napoleon_wrasse_name => 'דג נפוליאון';

  @override
  String get species_napoleon_wrasse_desc =>
      'דג נסיכה ענק המגיע ל-2 מטרים ובעל גבשושית מצח בולטת, נמצא בסכנת הכחדה ומוגן, ומצוי בשוניות ההודו-פסיפי.';

  @override
  String get species_cleaner_wrasse_name => 'דג מנקה כחול-פס';

  @override
  String get species_cleaner_wrasse_desc =>
      'דג נסיכה קטן בפס כחול המפעיל תחנות ניקוי ומסיר טפילים מדגים גדולים ממנו בשוניות ההודו-פסיפי.';

  @override
  String get species_yellowtail_coris_name => 'קוריס צהוב-זנב';

  @override
  String get species_yellowtail_coris_desc =>
      'דג נסיכה צבעוני בעל גוף מנוקד וזנב צהוב; הצעירים כתומים-אדומים בוהקים עם סימנים לבנים.';

  @override
  String get species_bluehead_wrasse_name => 'דג נסיכה כחול-ראש';

  @override
  String get species_bluehead_wrasse_desc =>
      'דג נסיכה נפוץ בקריביים; לזכרים הבוגרים ראש כחול עז וגוף ירוק עם פסים שחורים ולבנים.';

  @override
  String get species_spanish_hogfish_name => 'דג חזיר ספרדי';

  @override
  String get species_spanish_hogfish_desc =>
      'דג נסיכה סגול-צהוב הנפוץ בשוניות הקריביים; הצעירים משמשים כדגי ניקוי.';

  @override
  String get species_bumphead_parrotfish_name => 'דג תוכי גבנוני';

  @override
  String get species_bumphead_parrotfish_desc =>
      'מין דג התוכי הגדול ביותר, מגיע ל-1.3 מטר ובעל גבשושית מצח עצומה, ונע בלהקות בשוניות ההודו-פסיפי.';

  @override
  String get species_stoplight_parrotfish_name => 'דג תוכי רמזור';

  @override
  String get species_stoplight_parrotfish_desc =>
      'דג תוכי נפוץ בקריביים שצבעיו משתנים באופן דרמטי בין שלב הצעירות לשלב הבגרות.';

  @override
  String get species_queen_parrotfish_name => 'דג תוכי מלכותי';

  @override
  String get species_queen_parrotfish_desc =>
      'דג תוכי גדול בגוון כחול-ירוק המצוי בשוניות הקריביים, ונצפה לרוב נוגס באלמוגים כדי לאכול אצות.';

  @override
  String get species_yellowtail_damselfish_name => 'דג עלמה צהוב-זנב';

  @override
  String get species_yellowtail_damselfish_desc =>
      'דג עלמה כחול כהה בעל זנב צהוב בוהק, נפוץ בפסגות שוניות הקריביים.';

  @override
  String get species_sergeant_major_name => 'דג סמל';

  @override
  String get species_sergeant_major_desc =>
      'דג עלמה כסוף-צהוב בעל חמישה פסים שחורים בולטים, מצוי בהתקהלויות גדולות בשוניות האטלנטי הטרופי.';

  @override
  String get species_three_spot_damselfish_name => 'דג עלמה תלת-נקודה';

  @override
  String get species_three_spot_damselfish_desc =>
      'דג עלמה חום כהה וטריטוריאלי המגן בתוקפנות על גינת האצות שלו בשוניות הקריביים.';

  @override
  String get species_chromis_viridis_name => 'כרומיס כחול-ירוק';

  @override
  String get species_chromis_viridis_desc =>
      'דג עלמה ירוק ונוצץ קטן הנצפה בלהקות גדולות המרחפות מעל אלמוגים מסועפים בשוניות ההודו-פסיפי.';

  @override
  String get species_blue_chromis_name => 'כרומיס כחול';

  @override
  String get species_blue_chromis_desc =>
      'דג עלמה כחול וזוהר הניזון מפלנקטון, מצוי בהתקהלויות גדולות באמצע המים מעל קירות השונית בקריביים.';

  @override
  String get species_nassau_grouper_name => 'דקר נסאו';

  @override
  String get species_nassau_grouper_desc =>
      'דקר קריבי גדול בעל פס עין כהה אופייני ודוגמת פסים, וכיום בסכנת הכחדה בשל דיג יתר.';

  @override
  String get species_giant_grouper_name => 'דקר ענק';

  @override
  String get species_giant_grouper_desc =>
      'דג השונית הגרמי הגדול ביותר, מגיע ל-2.7 מטרים ו-400 ק\"ג, ומצוי במערות ובספינות טרופות ברחבי ההודו-פסיפי.';

  @override
  String get species_coral_grouper_name => 'דקר אלמוגים';

  @override
  String get species_coral_grouper_desc =>
      'דקר בגוון אדום-כתום בוהק המכוסה בנקודות כחולות, מין מובהק של שוניות האלמוגים בהודו-פסיפי.';

  @override
  String get species_goliath_grouper_name => 'דקר גוליית';

  @override
  String get species_goliath_grouper_desc =>
      'דקר אטלנטי ענק המגיע ל-2.5 מטרים, נפגש לרוב סמוך לספינות טרופות ולמדפי סלע בפלורידה ובקריביים.';

  @override
  String get species_potato_grouper_name => 'דקר תפוח אדמה';

  @override
  String get species_potato_grouper_desc =>
      'דקר גדול וידידותי בעל כתמים כהים בצורת תפוח אדמה, מפורסם באתר קוד הול שבשונית המחסום הגדולה.';

  @override
  String get species_peacock_grouper_name => 'דקר טווס';

  @override
  String get species_peacock_grouper_desc =>
      'דקר חום כהה בעל נקודות כחולות בוהקות ופסים אנכיים בהירים בחלקו האחורי, נפוץ בשוניות ההודו-פסיפי.';

  @override
  String get species_yellowfin_tuna_name => 'טונה צהובת-סנפיר';

  @override
  String get species_yellowfin_tuna_desc =>
      'טורף פלגי מהיר בעל סנפירי גב ופי הטבעת צהובים וארוכים, נצפה מדי פעם על ידי צוללנים באתרים מרוחקים מהחוף.';

  @override
  String get species_dogtooth_tuna_name => 'טונה שיני-כלב';

  @override
  String get species_dogtooth_tuna_desc =>
      'טונה חזקה הקשורה לשוניות ובעלת שיניים בולטות, נפגשת במדרונות שונית עמוקים בהודו-פסיפי.';

  @override
  String get species_great_barracuda_name => 'ברקודה גדולה';

  @override
  String get species_great_barracuda_desc =>
      'טורף כסוף וחלקלק באורך של עד 1.8 מטרים בעל שיניים בולטות, נצפה לרוב מרחף ללא תנועה סמוך לשוניות טרופיות.';

  @override
  String get species_blackfin_barracuda_name => 'ברקודה שחורת-סנפיר';

  @override
  String get species_blackfin_barracuda_desc =>
      'ברקודה הודו-פסיפית הידועה בלהקות ענק דמויות טורנדו באתרי צלילה כמו ברקודה פוינט.';

  @override
  String get species_mahi_mahi_name => 'מהי-מהי';

  @override
  String get species_mahi_mahi_desc =>
      'דג פלגי מסנוור בגוני כחול-ירוק וזהב בעל מצח קהה, נצפה מדי פעם באתרי צלילה מרוחקים מהחוף.';

  @override
  String get species_giant_trevally_name => 'טרוואלי ענק';

  @override
  String get species_giant_trevally_desc =>
      'טורף כסוף רב-עוצמה באורך של עד 1.7 מטרים, ידוע בציד בתעלות ובמדרונות שונית ברחבי ההודו-פסיפי.';

  @override
  String get species_bluefin_trevally_name => 'טרוואלי כחול-סנפיר';

  @override
  String get species_bluefin_trevally_desc =>
      'טרוואלי חלקלק בנקודות כחולות הנצפה לרוב סורק את שולי השוניות בהודו-פסיפי בקבוצות ציד קטנות.';

  @override
  String get species_bigeye_trevally_name => 'טרוואלי גדול-עין';

  @override
  String get species_bigeye_trevally_desc =>
      'טרוואלי כסוף בעל עיניים גדולות היוצר להקות מסתחררות ומרשימות סמוך לקירות שונית ולתחנות ניקוי.';

  @override
  String get species_bar_jack_name => 'ג\'ק מפוספס';

  @override
  String get species_bar_jack_desc =>
      'ג\'ק קריבי כסוף וחלקלק בעל פס כחול כהה אופייני לאורך הגב ועד לאונה התחתונה של הזנב.';

  @override
  String get species_horse_eye_jack_name => 'ג\'ק עין-סוס';

  @override
  String get species_horse_eye_jack_desc =>
      'ג\'ק כסוף בעל עיניים גדולות היוצר להקות סמוך לשוניות ולספינות טרופות בקריביים ובמערב האטלנטי.';

  @override
  String get species_yellowtail_snapper_name => 'לוציאן צהוב-זנב';

  @override
  String get species_yellowtail_snapper_desc =>
      'לוציאן חלקלק בעל פס וזנב צהובים, נצפה לרוב בלהקות באמצע המים בשוניות הקריביים.';

  @override
  String get species_schoolmaster_snapper_name => 'לוציאן מורה';

  @override
  String get species_schoolmaster_snapper_desc =>
      'לוציאן צהוב-כסוף בעל קווים כחולים מתחת לעין, מצוי בקבוצות מתחת למדפי סלע בשוניות הקריביים.';

  @override
  String get species_bluestripe_snapper_name => 'לוציאן כחול-פסים';

  @override
  String get species_bluestripe_snapper_desc =>
      'לוציאן צהוב בוהק בעל ארבעה פסים כחולים אופקיים, יוצר להקות צפופות בשוניות ההודו-פסיפי.';

  @override
  String get species_twinspot_snapper_name => 'לוציאן דו-כתמי';

  @override
  String get species_twinspot_snapper_desc =>
      'לוציאן אדום גדול המצוי בשוניות חיצוניות בהודו-פסיפי, ולעיתים יוצר להקות בקירות עמוקים ובתעלות.';

  @override
  String get species_humphead_snapper_name => 'לוציאן חצות';

  @override
  String get species_humphead_snapper_desc =>
      'לוציאן כהה וגדול המצוי בלהקות ליד מדרונות תלולים בהודו-פסיפי; הצעירים שחורים ולבנים בניגוד חד.';

  @override
  String get species_longfin_bannerfish_name => 'דגלן ארוך-סנפיר';

  @override
  String get species_longfin_bannerfish_desc =>
      'דג שחור-לבן בעל סנפיר גב ארוך ונגרר וזנב צהוב, נצפה לרוב בזוגות בשוניות ההודו-פסיפי.';

  @override
  String get species_batfish_orbicular_name => 'דג עטלף עגול';

  @override
  String get species_batfish_orbicular_desc =>
      'דג כסוף בצורת דיסקה בעל סנפירים גבוהים המתקרב לצוללנים בסקרנות, נפוץ בספינות טרופות ובשוניות בהודו-פסיפי.';

  @override
  String get species_batfish_teira_name => 'דג עטלף ארוך-סנפיר';

  @override
  String get species_batfish_teira_desc =>
      'דג עטלף בעל סנפירים גבוהים וכתם כהה סמוך לסנפיר החזה, נצפה לרוב בתחנות ניקוי ובספינות טרופות.';

  @override
  String get species_batfish_pinnatus_name => 'דג עטלף מכונף';

  @override
  String get species_batfish_pinnatus_desc =>
      'הצעירים שחורים כפחם עם שוליים כתומים עזים המזכירים תולעת שטוחה רעילה, והמין מצוי במערב האוקיינוס השקט.';

  @override
  String get species_banggai_cardinalfish_name => 'דג חשמן בנגאי';

  @override
  String get species_banggai_cardinalfish_desc =>
      'דג חשמן מרשים בכסוף ושחור בעל סנפירים מוארכים, אנדמי לאיי בנגאי שבאינדונזיה.';

  @override
  String get species_pajama_cardinalfish_name => 'דג חשמן פיג\'מה';

  @override
  String get species_pajama_cardinalfish_desc =>
      'דג חשמן יוצא דופן בעל פנים צהובות, פס מותניים כהה וחלק אחורי מנוקד, מצוי בין אלמוגים בהודו-פסיפי.';

  @override
  String get species_longnose_hawkfish_name => 'דג נץ ארוך-חרטום';

  @override
  String get species_longnose_hawkfish_desc =>
      'דג לבן קטן בעל דוגמת רשת אדומה וחרטום מוארך, נח על גורגוניות ואלמוגים שחורים.';

  @override
  String get species_arc_eye_hawkfish_name => 'דג נץ קשת-עין';

  @override
  String get species_arc_eye_hawkfish_desc =>
      'דג נץ קטן בעל קשת כתומה אופיינית מאחורי העין, נח לרוב על ראשי אלמוג בשוניות ההודו-פסיפי.';

  @override
  String get species_flame_hawkfish_name => 'דג נץ להבה';

  @override
  String get species_flame_hawkfish_desc =>
      'דג נץ אדום זוהר בעל סימנים כהים סביב העין, נח בין אלמוגי Pocillopora ברחבי מערב האוקיינוס השקט.';

  @override
  String get species_fire_goby_name => 'גובי אש';

  @override
  String get species_fire_goby_desc =>
      'גובי לבן אלגנטי בעל סנפיר גב קדמי גבוה וזנב אדום-כתום, מרחף מעל שברי אלמוגים בהודו-פסיפי.';

  @override
  String get species_purple_firefish_name => 'דג אש סגול';

  @override
  String get species_purple_firefish_desc =>
      'גובי עדין בעל סנפירים סגולים וקוץ גב גבוה, מרחף סמוך למחילות בשוניות החיצוניות של ההודו-פסיפי.';

  @override
  String get species_yellownose_goby_name => 'גובי צהוב-חרטום';

  @override
  String get species_yellownose_goby_desc =>
      'גובי מנקה קריבי זעיר בעל חרטום צהוב ופס צדדי כחול, מצוי על ספוגים וראשי אלמוג.';

  @override
  String get species_citron_goby_name => 'גובי לימוני';

  @override
  String get species_citron_goby_desc =>
      'גובי זעיר בצהוב בוהק החי בין ענפי אלמוגי Acropora בשוניות ההודו-פסיפי.';

  @override
  String get species_shrimp_goby_name => 'גובי חסילונים של שטייניץ';

  @override
  String get species_shrimp_goby_desc =>
      'גובי בגוון חול החולק מחילה עם חסילון אלפאידי ביחסי גומלין, במישורי החול של ההודו-פסיפי.';

  @override
  String get species_neon_goby_name => 'גובי ניאון';

  @override
  String get species_neon_goby_desc =>
      'גובי כהה וזעיר בעל פס כחול ניאוני זוהר, מפעיל תחנות ניקוי על ראשי אלמוג בקריביים.';

  @override
  String get species_bluestriped_fangblenny_name => 'בלני ניבים כחול-פס';

  @override
  String get species_bluestriped_fangblenny_desc =>
      'בלני קטן בפס כחול המחקה דגי ניקוי כדי לנשוך קשקשים מדגים תמימים.';

  @override
  String get species_sailfin_blenny_name => 'בלני מפרשי';

  @override
  String get species_sailfin_blenny_desc =>
      'בלני קריבי זעיר המרים סנפיר גב גדול דמוי מפרש מתוך מחילתו כדי למשוך בנות זוג.';

  @override
  String get species_bicolor_blenny_name => 'בלני דו-גוני';

  @override
  String get species_bicolor_blenny_desc =>
      'בלני קטן שחציו הקדמי חום כהה וחציו האחורי כתום, מציץ מחורים בשוניות ההודו-פסיפי.';

  @override
  String get species_redlip_blenny_name => 'בלני אדום-שפתיים';

  @override
  String get species_redlip_blenny_desc =>
      'בלני כהה בעל שפתיים אדומות-כתומות בולטות המגן על כתמי אצות בפסגות השוניות בקריביים.';

  @override
  String get species_pygmy_seahorse_name => 'סוסון ים גמדי של ברגיבנט';

  @override
  String get species_pygmy_seahorse_desc =>
      'סוסון ים זעיר באורך של פחות מ-2 ס\"מ המתמזג באופן מושלם עם הגורגוניה המארחת, נושא מבוקש לצילומי מאקרו.';

  @override
  String get species_common_seahorse_name => 'סוסון ים מצוי';

  @override
  String get species_common_seahorse_desc =>
      'סוסון ים בינוני המצוי בערוגות עשב ים ובשברי אלמוגים ברחבי ההודו-פסיפי, וצבעו משתנה.';

  @override
  String get species_thorny_seahorse_name => 'סוסון ים קוצני';

  @override
  String get species_thorny_seahorse_desc =>
      'סוסון ים המכוסה בקוצים ארוכים, מצוי בערוגות עשב ים ובקרקעיות רכות ברחבי ההודו-פסיפי.';

  @override
  String get species_ornate_ghost_pipefish_name => 'דג צינור רפאים מקושט';

  @override
  String get species_ornate_ghost_pipefish_desc =>
      'דג צינור מוסווה להפליא המרחף עם הראש כלפי מטה סמוך לקרינואידים ולאלמוגים רכים בהודו-פסיפי.';

  @override
  String get species_robust_ghost_pipefish_name => 'דג צינור רפאים חסון';

  @override
  String get species_robust_ghost_pipefish_desc =>
      'דג צינור רפאים גדול המחקה עשב ים או אצות, ונמצא לרוב בזוגות במים חופיים בהודו-פסיפי.';

  @override
  String get species_trumpetfish_name => 'דג חצוצרה';

  @override
  String get species_trumpetfish_desc =>
      'דג ארוך ותמיר הצד בהסתתרות בצל דגים גדולים, מצוי בשוניות הקריביים והאטלנטי במגוון צבעים.';

  @override
  String get species_cornetfish_name => 'דג חליל';

  @override
  String get species_cornetfish_desc =>
      'דג מוארך במיוחד באורך של עד 1.5 מטרים בעל חוט זנב נגרר, נצפה לרוב גולש מעל מישורי שונית.';

  @override
  String get species_yellowhead_jawfish_name => 'דג לסת צהוב-ראש';

  @override
  String get species_yellowhead_jawfish_desc =>
      'דג קטן בעל גוף כחול וראש צהוב המרחף מעל מחילת החול שלו בשוניות הקריביים, והזכרים דוגרים על הביצים בפיהם.';

  @override
  String get species_flamefish_name => 'דג להבה';

  @override
  String get species_flamefish_desc =>
      'דג חשמן קטן ואדום בוהק בעל כתם כהה מתחת לסנפיר הגב השני, מסתתר בנקיקי שונית בקריביים במשך היום.';

  @override
  String get species_longspine_squirrelfish_name => 'דג סנאי ארוך-קוץ';

  @override
  String get species_longspine_squirrelfish_desc =>
      'דג לילי אדום בעל עיניים גדולות וקוץ גב ארוך, מצוי ביום מתחת למדפי סלע בשוניות הקריביים.';

  @override
  String get species_soldierfish_name => 'דג חייל גדול-קשקש';

  @override
  String get species_soldierfish_desc =>
      'דג לילי אדום בעל עיניים כהות ענקיות וקשקשים גדולים, מתקבץ ביום במערות ומתחת לגגונים.';

  @override
  String get species_flame_angelfish_name => 'דג מלאך להבה';

  @override
  String get species_flame_angelfish_desc =>
      'דג מלאך ננסי באדום-כתום זוהר בעל פסים אנכיים שחורים וסנפירים כחולי-קצה, מצוי ברחבי האוקיינוס השקט.';

  @override
  String get species_royal_gramma_name => 'גרמה מלכותית';

  @override
  String get species_royal_gramma_desc =>
      'דג בסלט קריבי קטן ודו-גוני שחציו הקדמי סגול וחציו האחורי צהוב, מצוי מתחת למדפי סלע.';

  @override
  String get species_anthias_lyretail_name => 'אנתיאס נבל-זנב';

  @override
  String get species_anthias_lyretail_desc =>
      'דג שונית נפוץ היוצר ענני כתום וורוד גדולים מעל מבני אלמוג בהודו-פסיפי, והזכרים סגולים.';

  @override
  String get species_mediterranean_grouper_name => 'לוקוס';

  @override
  String get species_mediterranean_grouper_desc =>
      'דקר גדול בחום כהה עם כתמים בהירים, הטורף האייקוני של שוניות הסלע בים התיכון.';

  @override
  String get species_mediterranean_moray_name => 'מורנה ים-תיכונית';

  @override
  String get species_mediterranean_moray_desc =>
      'מורנה בחום כהה עם כתמים צהובים, נצפית לרוב מציצה מנקיקי סלע בים התיכון.';

  @override
  String get species_ornate_wrasse_name => 'דג נסיכה מקושט';

  @override
  String get species_ornate_wrasse_desc =>
      'דג נסיכה ירוק וצבעוני בעל סימנים אדומים בראש, אחד מדגי הנסיכה הנפוצים ביותר בשוניות הים התיכון.';

  @override
  String get species_red_sea_bannerfish_name => 'דג פרפר ממוסך';

  @override
  String get species_red_sea_bannerfish_desc =>
      'דג פרפר צהוב בוהק בעל כתם עין כהה, אנדמי לים סוף ונצפה לרוב בזוגות.';

  @override
  String get species_red_sea_anemonefish_name => 'דג שושנון ים סוף';

  @override
  String get species_red_sea_anemonefish_desc =>
      'דג שושנון בגוון כתום-צהוב עם שני פסים לבנים, אנדמי לים סוף ולמפרץ עדן.';

  @override
  String get species_arabian_angelfish_name => 'דג מלאך ערבי';

  @override
  String get species_arabian_angelfish_desc =>
      'דג מלאך גדול בכחול כהה בעל פס אנכי וזנב צהובים ובולטים, אנדמי למערב האוקיינוס ההודי.';

  @override
  String get species_king_angelfish_name => 'דג מלאך מלך';

  @override
  String get species_king_angelfish_desc =>
      'דג מלאך גדול בכחול כהה בעל פס אנכי לבן וזנב צהוב, מצוי במזרח האוקיינוס השקט ובגלפגוס.';

  @override
  String get species_ocean_sunfish_name => 'דג שמש';

  @override
  String get species_ocean_sunfish_desc =>
      'הדג הגרמי הכבד ביותר, מגיע למשקל של יותר משני טונות ונצפה מדי פעם על ידי צוללנים בתחנות ניקוי בבאלי ובגלפגוס.';

  @override
  String get species_lingcod_name => 'לינגקוד';

  @override
  String get species_lingcod_desc =>
      'דג טורף גדול ומנומר ממשפחת הגרינלינגים, מצוי בשוניות סלע בצפון-מערב האוקיינוס השקט ולרוב שומר על גושי ביצים.';

  @override
  String get species_wolf_eel_name => 'צלופח זאב';

  @override
  String get species_wolf_eel_desc =>
      'צלופח זאב אפור וגדול בעל ראש בולבוסי ולסתות חזקות, מצוי במאורות סלע בצפון-מערב האוקיינוס השקט.';

  @override
  String get species_giant_sea_bass_name => 'בס ים ענק';

  @override
  String get species_giant_sea_bass_desc =>
      'בס ענק המגיע ליותר מ-2 מטרים ו-250 ק\"ג, מצוי בשוניות סלע וביערות קלפ מול חופי דרום קליפורניה.';

  @override
  String get species_garibaldi_name => 'גריבלדי';

  @override
  String get species_garibaldi_desc =>
      'דג עלמה כתום בוהק והדג הימי הרשמי של קליפורניה, טריטוריאלי בשוניות שביערות הקלפ.';

  @override
  String get species_sheephead_name => 'דג ראש-כבש קליפורני';

  @override
  String get species_sheephead_desc =>
      'דג נסיכה גדול בעל ראש וזנב שחורים, גוף אמצעי אדום וסנטר לבן, מצוי ביערות הקלפ של קליפורניה.';

  @override
  String get species_copper_rockfish_name => 'דג סלע נחושתי';

  @override
  String get species_copper_rockfish_desc =>
      'דג סלע בגוון נחושת-כתום עם כתמים בהירים, מראה נפוץ בשוניות הסלע וביערות הקלפ של צפון-מערב האוקיינוס השקט.';

  @override
  String get species_oriental_sweetlips_name => 'דג שפתיים מתוקות מזרחי';

  @override
  String get species_oriental_sweetlips_desc =>
      'דג שונית הודו-פסיפי גדול בעל פסים שחורים ולבנים נועזים וסנפירים צהובים, והצעירים מבצעים ריקוד מתפתל.';

  @override
  String get species_harlequin_sweetlips_name => 'דג שפתיים מתוקות הרלקין';

  @override
  String get species_harlequin_sweetlips_desc =>
      'הבוגרים אפורים עם נקודות כהות והצעירים חומים עם נקודות לבנות גדולות ושוחים בתנועה גלית.';

  @override
  String get species_blue_ringed_angelfish_name => 'דג מלאך כחול-טבעת';

  @override
  String get species_blue_ringed_angelfish_desc =>
      'דג מלאך חום וגדול בעל קווים כחולים מעוקלים וטבעת כחולה אופיינית מעל מכסה הזימים.';

  @override
  String get species_yellowbar_angelfish_name => 'דג מלאך צהוב-פס';

  @override
  String get species_yellowbar_angelfish_desc =>
      'דג מלאך גדול בגוון אפור-כחול בעל כתם גוף צהוב בולט, מצוי בים סוף ובמערב האוקיינוס ההודי.';

  @override
  String get species_filefish_scrawled_name => 'דג פצירה משורבט';

  @override
  String get species_filefish_scrawled_desc =>
      'דג פצירה גדול בגוון חום-זית בעל סימנים כחולים דמויי שרבוט וזפק כתום, מצוי בשוניות טרופיות בכל העולם.';

  @override
  String get species_clown_filefish_name => 'דג פצירה כתום-נקודות';

  @override
  String get species_clown_filefish_desc =>
      'דג פצירה ירוק וקטן בעל נקודות כתומות וחרטום ארוך, ניזון אך ורק מפוליפים של אלמוגי Acropora.';

  @override
  String get species_unicornfish_name => 'דג חד-קרן כחול-קוץ';

  @override
  String get species_unicornfish_desc =>
      'דג כירורג אפור בעל קרן מצח בולטת ושני קוצי זנב כחולים, נפוץ במישורי השונית של ההודו-פסיפי.';

  @override
  String get species_surgeonfish_sailfin_name => 'דג כירורג מפרשי';

  @override
  String get species_surgeonfish_sailfin_desc =>
      'דג כירורג בעל פסים נועזים וסנפירי גב ופי הטבעת מורחבים מאוד, מצוי ברחבי ההודו-פסיפי.';

  @override
  String get species_achilles_tang_name => 'דג כירורג אכילס';

  @override
  String get species_achilles_tang_desc =>
      'דג כירורג בחום כהה בעל כתם דמעה כתום בולט סמוך לזנב, מצוי באזורי גלים סוערים במרכז האוקיינוס השקט.';

  @override
  String get species_doctorfish_name => 'דג רופא';

  @override
  String get species_doctorfish_desc =>
      'דג כירורג בגוון אפרפר-חום בעל פסים כהים עדינים ואזמל זנב בולט, נפוץ בשוניות הקריביים.';

  @override
  String get species_checkerboard_wrasse_name => 'דג נסיכה משבצות';

  @override
  String get species_checkerboard_wrasse_desc =>
      'דג נסיכה צבעוני בעל דוגמת משבצות ירוקות, ורודות ושחורות לאורך הגוף.';

  @override
  String get species_bird_wrasse_name => 'דג נסיכה ציפור';

  @override
  String get species_bird_wrasse_desc =>
      'דג נסיכה בעל חרטום מוארך במיוחד המזכיר מקור של ציפור; הזכרים ירוקים כהים והנקבות חומות.';

  @override
  String get species_sling_jaw_wrasse_name => 'דג נסיכה מקלע-לסת';

  @override
  String get species_sling_jaw_wrasse_desc =>
      'דג נסיכה בעל לסת נשלפת הנורית קדימה כדי ללכוד טרף, ומופיע בגרסאות צבע צהובה או חומה.';

  @override
  String get species_peacock_flounder_name => 'דג שטוח טווסי';

  @override
  String get species_peacock_flounder_desc =>
      'דג קרקעית שטוח בעל טבעות ונקודות כחולות המסוגל לשנות את צבעו כדי להתמזג עם קרקעית הים.';

  @override
  String get species_hogfish_name => 'דג חזיר';

  @override
  String get species_hogfish_desc =>
      'דג נסיכה גדול ממערב האטלנטי בעל חרטום דמוי חזיר וקוצי גב מוארכים, מצוי סמוך לשוניות ולספינות טרופות.';

  @override
  String get species_tarpon_name => 'טרפון אטלנטי';

  @override
  String get species_tarpon_desc =>
      'דג כסוף ענק בעל קשקשים גדולים דמויי מראה, נפגש לעיתים על ידי צוללנים במערות ובתעלות בקריביים.';

  @override
  String get species_permit_name => 'פרמיט';

  @override
  String get species_permit_desc =>
      'דג ג\'ק כסוף בעל גוף גבוה וזנב מפוצל כהה, מצוי במישורי החול של הקריביים וסמוך לשוניות.';

  @override
  String get species_spotted_drum_name => 'דג תוף מנוקד';

  @override
  String get species_spotted_drum_desc =>
      'דג קריבי מרשים בעל סנפיר גב גבוה ומוארך ודוגמת נקודות נועזת בשחור ולבן.';

  @override
  String get species_jackknife_fish_name => 'דג אולר';

  @override
  String get species_jackknife_fish_desc =>
      'דג קריבי אלגנטי בעל פס שחור גבוה בסנפיר הגב ופס אלכסוני בגוף, מצוי מתחת למדפי סלע.';

  @override
  String get species_bigeye_name => 'עין-זכוכית';

  @override
  String get species_bigeye_desc =>
      'דג לילי אדום בוהק בעל עיניים גדולות ומחזירות אור, מסתתר במערות בשוניות הקריביים והאטלנטי.';

  @override
  String get species_remora_name => 'רמורה';

  @override
  String get species_remora_desc =>
      'דג תמיר בעל דיסקת יניקה על ראשו הנטפל לכרישים, לטריגונים, לצבים ולבעלי חיים גדולים אחרים.';

  @override
  String get species_tilefish_sand_name => 'דג אריח חולי';

  @override
  String get species_tilefish_sand_desc =>
      'דג מוארך בכחול בהיר הבונה תלוליות משברי אלמוגים מעל אזורי חול בשוניות הקריביים.';

  @override
  String get species_weedy_seadragon_name => 'דרקון ים עשבי';

  @override
  String get species_weedy_seadragon_desc =>
      'קרוב משפחה מקושט של סוסוני הים בעל תוספות דמויות עלים, אנדמי למים הממוזגים של דרום אוסטרליה.';

  @override
  String get species_leafy_seadragon_name => 'דרקון ים עלים';

  @override
  String get species_leafy_seadragon_desc =>
      'דרקון ים מרהיב המכוסה בבליטות מורכבות דמויות עלים, אנדמי לדרום אוסטרליה ותצפית שכל צוללן חולם עליה.';

  @override
  String get species_sailfin_snapper_name => 'לוציאן מפרשי';

  @override
  String get species_sailfin_snapper_desc =>
      'לוציאן אלגנטי בצהוב וכחול בעל סנפירי גב ופי הטבעת מוארכים, מצוי במדרונות שונית בהודו-פסיפי.';

  @override
  String get species_sweetlip_emperor_name => 'דג קיסר מנצנץ';

  @override
  String get species_sweetlip_emperor_desc =>
      'דג קיסר כסוף וגדול בעל קווים כחולים בפנים ושולי סנפירים צהובים, נפוץ מעל אזורי חול סמוך לשוניות בהודו-פסיפי.';

  @override
  String get species_crocodilefish_name => 'דג תנין';

  @override
  String get species_crocodilefish_desc =>
      'טורף מארב שטוח-ראש בעל גדילים מורכבים סביב העיניים, שוכב מוסווה להפליא על קרקעיות השונית בהודו-פסיפי.';

  @override
  String get species_devil_scorpionfish_name => 'דג עקרב שטן';

  @override
  String get species_devil_scorpionfish_desc =>
      'דג עקרב חסון ומוסווה החושף צבעים עזים בצדם הפנימי של סנפירי החזה כאזהרה לטורפים.';

  @override
  String get species_spiny_devilfish_name => 'עוקצן שד';

  @override
  String get species_spiny_devilfish_desc =>
      'דייר קרקעית ארסי הצועד על קרני סנפיר מותאמות וחושף סנפירי חזה בוהקים כשמפריעים לו.';

  @override
  String get species_waspfish_name => 'דג צרעה קקדו';

  @override
  String get species_waspfish_desc =>
      'דג עקרב קטן ושטוח המתנועע בזרם כמו עלה מת מעל קרקעיות בוציות בהודו-פסיפי.';

  @override
  String get species_stargazer_name => 'צופה בכוכבים לבן-שוליים';

  @override
  String get species_stargazer_desc =>
      'טורף מארב הטומן את עצמו בחול כשרק עיניו גלויות, ומסוגל לתת מכות חשמל; מצוי בהודו-פסיפי.';

  @override
  String get species_striped_catfish_name => 'שפמנון ים מפוספס';

  @override
  String get species_striped_catfish_desc =>
      'שפמנון בעל קוצים ארסיים; הצעירים יוצרים להקות כדוריות צפופות המתגלגלות על קרקעיות השונית בהודו-פסיפי.';

  @override
  String get species_red_emperor_name => 'קיסר אדום';

  @override
  String get species_red_emperor_desc =>
      'לוציאן גדול; הבוגרים בגוון אדום-ורדרד והצעירים בעלי פסים אדומים ולבנים בולטים, והמין מצוי בשוניות ההודו-פסיפי.';

  @override
  String get species_mangrove_snapper_name => 'לוציאן מנגרובים';

  @override
  String get species_mangrove_snapper_desc =>
      'לוציאן אפור המצוי במנגרובים, בערוגות עשב ים ובשוניות בקריביים, ולרוב מתקבץ סמוך למבנים.';

  @override
  String get species_dottyback_orchid_name => 'דוטיבק סחלב';

  @override
  String get species_dottyback_orchid_desc =>
      'דג קטן בסגול עז האנדמי לים סוף, מזנק פנימה והחוצה מנקיקים בקירות שונית תלולים.';

  @override
  String get species_dottyback_royal_name => 'דוטיבק מלכותי';

  @override
  String get species_dottyback_royal_desc =>
      'דג קטן ודו-גוני שחלקו הקדמי מג\'נטה וחלקו האחורי צהוב בוהק, מצוי בקירות שונית בהודו-פסיפי.';

  @override
  String get species_coral_trout_name => 'דקר נמרי';

  @override
  String get species_coral_trout_desc =>
      'טורף נחשק של שונית המחסום הגדולה, בעל גוף אדום-כתום המכוסה בנקודות כחולות.';

  @override
  String get species_barramundi_cod_name => 'דקר ברמונדי';

  @override
  String get species_barramundi_cod_desc =>
      'דקר ייחודי בעל ראש קטן, גוף גבנוני ונקודות כהות גדולות על רקע בהיר.';

  @override
  String get species_spadefish_atlantic_name => 'דג את אטלנטי';

  @override
  String get species_spadefish_atlantic_desc =>
      'דג כסוף בצורת דיסקה בעל פסים אנכיים כהים, נצפה לרוב בלהקות גדולות סביב ספינות טרופות בקריביים.';

  @override
  String get species_fusilier_yellowback_name => 'פוזיליר צהוב-גב';

  @override
  String get species_fusilier_yellowback_desc =>
      'דג כחול וחלקלק הניזון מפלנקטון ובעל גב צהוב, יוצר להקות ענק מעל מדרונות שונית בהודו-פסיפי.';

  @override
  String get species_fusilier_bluestreak_name => 'פוזיליר כחול-פס';

  @override
  String get species_fusilier_bluestreak_desc =>
      'פוזיליר כחול קטן בעל פס צדדי כהה, נצפה בלהקות מהירות לאורך קירות שונית בהודו-פסיפי.';

  @override
  String get species_porkfish_name => 'דג נוהם חזירי';

  @override
  String get species_porkfish_desc =>
      'דג נוהם קריבי צבעוני בעל פסים כחולים וצהובים ושני פסי ראש שחורים, מצוי סמוך לשוניות ולספינות טרופות.';

  @override
  String get species_blue_striped_grunt_name => 'דג נוהם כחול-פסים';

  @override
  String get species_blue_striped_grunt_desc =>
      'דג נוהם קריבי צהוב בעל פסים אופקיים כחולים עזים, יוצר ביום להקות מנוחה גדולות מתחת למדפי סלע.';

  @override
  String get species_french_grunt_name => 'דג נוהם צרפתי';

  @override
  String get species_french_grunt_desc =>
      'דג נוהם קטן בפסים צהובים היוצר להקות מנוחה צפופות בשוניות הקריביים בשעות היום.';

  @override
  String get species_convict_tang_name => 'דג כירורג אסיר';

  @override
  String get species_convict_tang_desc =>
      'דג כירורג בהיר בעל שישה פסים שחורים אנכיים, נצפה לרוב רועה בלהקות גדולות במישורי השונית של ההודו-פסיפי.';

  @override
  String get species_great_hammerhead_name => 'כריש פטיש משונן';

  @override
  String get species_great_hammerhead_desc =>
      'כריש ייחודי בעל ראש משונן בצורת פטיש, יוצר להקות גדולות סביב הרי ים ואיים מרוחקים מהחוף.';

  @override
  String get species_wobbegong_name => 'וובגונג מנוקד';

  @override
  String get species_wobbegong_desc =>
      'כריש שטיח שטוח ומוסווה היטב בעל אונות משוננות סביב הפה, מצוי בשוניות ממוזגות באוסטרליה.';

  @override
  String get species_manta_ray_name => 'מנטת שונית';

  @override
  String get species_manta_ray_desc =>
      'ענק חינני במוטת כנפיים של עד 5 מטרים המבקר בתחנות ניקוי וניזון מפלנקטון בשוניות ההודו-פסיפי.';

  @override
  String get species_oceanic_manta_name => 'מנטה אוקיינית';

  @override
  String get species_oceanic_manta_desc =>
      'מין הטריגון הגדול ביותר, במוטת כנפיים של יותר מ-7 מטרים, נפגש בהרי ים מרוחקים מהחוף ובתחנות ניקוי.';

  @override
  String get species_undulated_moray_name => 'מורנה גלית';

  @override
  String get species_undulated_moray_desc =>
      'מורנה בגוון ירוק-צהבהב עם סימנים גליים כהים, נצפית לרוב צדה בלילה בשוניות ההודו-פסיפי.';

  @override
  String get species_whitemouth_moray_name => 'מורנה לבנת-פה';

  @override
  String get species_whitemouth_moray_desc =>
      'מורנה בחום כהה עם נקודות לבנות קטנות וחלל פה לבן אופייני, מצויה ברחבי ההודו-פסיפי.';

  @override
  String get species_dragon_moray_name => 'מורנת דרקון';

  @override
  String get species_dragon_moray_desc =>
      'מורנה מרשימה בעלת קרניים דמויות דרקון מעל הנחיריים וכתמי נמר אדומים-כתומים, מצויה בהודו-פסיפי.';

  @override
  String get species_lyretail_grouper_name => 'דקר נבל-זנב';

  @override
  String get species_lyretail_grouper_desc =>
      'דקר בגוון אדום-ורוד בעל נקודות כחולות וזנב אופייני בצורת סהר, מצוי בקירות שונית חיצוניים בהודו-פסיפי.';

  @override
  String get species_banded_butterflyfish_name => 'דג פרפר מפוספס';

  @override
  String get species_banded_butterflyfish_desc =>
      'דג פרפר לבן בעל ארבעה פסים אנכיים שחורים בולטים, אחד מדגי הפרפר הנפוצים ביותר בשוניות הקריביים.';

  @override
  String get species_ringed_pipefish_name => 'דג צינור טבעות';

  @override
  String get species_ringed_pipefish_desc =>
      'דג צינור תמיר בטבעות אדומות ולבנות לסירוגין, מצוי במערות ומתחת למדפי סלע בשוניות ההודו-פסיפי.';

  @override
  String get species_razorfish_name => 'דג תער';

  @override
  String get species_razorfish_desc =>
      'דג זעיר השוחה בקבוצות במאונך כשראשו כלפי מטה, ומסתתר לרוב בין קוצי קיפודי ים בשוניות ההודו-פסיפי.';

  @override
  String get species_harlequin_tuskfish_name => 'דג ניבים הרלקין';

  @override
  String get species_harlequin_tuskfish_desc =>
      'דג נסיכה צבעוני בעל ניבים כחולים בוהקים, פסים אדומים-כתומים וכתמים לבנים, מצוי בשוניות מערב האוקיינוס השקט.';

  @override
  String get species_blue_groper_name => 'גרופר כחול';

  @override
  String get species_blue_groper_desc =>
      'דג נסיכה כחול וגדול האנדמי למזרח אוסטרליה, ידידותי ומתקרב לעיתים קרובות לצוללנים בשוניות ממוזגות.';

  @override
  String get species_red_lipped_batfish_name => 'דג עטלף אדום-שפתיים';

  @override
  String get species_red_lipped_batfish_desc =>
      'דג מוזר ושטוח-גוף בעל שפתיים אדומות בוהקות הצועד על סנפירים מותאמים על קרקעית הים בגלפגוס.';

  @override
  String get species_orangeband_surgeonfish_name => 'דג כירורג כתום-פס';

  @override
  String get species_orangeband_surgeonfish_desc =>
      'דג כירורג בגוון אפור-חום בעל פס אופקי כתום מאחורי העין, מצוי במדרונות שונית באוקיינוס השקט.';

  @override
  String get species_maori_wrasse_name => 'דג נסיכה מאורי';

  @override
  String get species_maori_wrasse_desc =>
      'דג נסיכה בינוני בעל פס כהה מאחורי סנפיר החזה, נפוץ בשוניות האוקיינוס השקט והאוקיינוס ההודי.';

  @override
  String get species_blue_ringed_octopus_name => 'תמנון כחול-טבעות';

  @override
  String get species_blue_ringed_octopus_desc =>
      'תמנון קטן אך ארסי ביותר בעל טבעות כחולות בוהקות המהבהבות כשהוא מאוים.';

  @override
  String get species_common_octopus_name => 'תמנון מצוי';

  @override
  String get species_common_octopus_desc =>
      'תמנון אינטליגנטי מאוד הידוע בשינויי צבע מהירים וביכולות פתרון בעיות.';

  @override
  String get species_giant_pacific_octopus_name => 'תמנון פסיפי ענק';

  @override
  String get species_giant_pacific_octopus_desc =>
      'מין התמנון הגדול ביותר, מוטת זרועותיו מגיעה ליותר מ-4 מטרים במים הקרים של האוקיינוס השקט.';

  @override
  String get species_mimic_octopus_name => 'תמנון מחקה';

  @override
  String get species_mimic_octopus_desc =>
      'תמנון יוצא דופן המחקה את מראם ואת התנהגותם של מינים ימיים אחרים.';

  @override
  String get species_coconut_octopus_name => 'תמנון קוקוס';

  @override
  String get species_coconut_octopus_desc =>
      'תמנון קטן המפורסם בנשיאת קליפות קוקוס ובשימוש בהן כמחסה נייד.';

  @override
  String get species_day_octopus_name => 'תמנון יום';

  @override
  String get species_day_octopus_desc =>
      'צייד פעיל בשעות היום, נפוץ בשוניות ההודו-פסיפי ובעל יכולות הסוואה מרשימות.';

  @override
  String get species_wonderpus_octopus_name => 'תמנון וונדרפוס';

  @override
  String get species_wonderpus_octopus_desc =>
      'תמנון מרשים בעל פסים לבנים וחומים ייחודיים, מצוי באתרי צלילת מאק חוליים.';

  @override
  String get species_broadclub_cuttlefish_name => 'ספיה רחבת-אלה';

  @override
  String get species_broadclub_cuttlefish_desc =>
      'ספיה גדולה בעלת מופעי צבע מהפנטים, נצפית לרוב בשוניות ההודו-פסיפי.';

  @override
  String get species_pharaoh_cuttlefish_name => 'ספיית פרעה';

  @override
  String get species_pharaoh_cuttlefish_desc =>
      'ספיה גדולה המצויה ברחבי האוקיינוס ההודי, ידועה בדוגמאות צבע פועמות.';

  @override
  String get species_flamboyant_cuttlefish_name => 'ספיה ראוותנית';

  @override
  String get species_flamboyant_cuttlefish_desc =>
      'ספיה זעירה הצועדת על קרקעית הים ומציגה פעימות עזות של סגול, ורוד וצהוב.';

  @override
  String get species_giant_cuttlefish_name => 'ספיה ענקית';

  @override
  String get species_giant_cuttlefish_desc =>
      'הספיה הגדולה בעולם, מפורסמת בהתקהלויות הרבייה ההמוניות בדרום אוסטרליה.';

  @override
  String get species_bigfin_reef_squid_name => 'דיונון שונית גדול-סנפיר';

  @override
  String get species_bigfin_reef_squid_desc =>
      'דיונון להקתי הנפגש תכופות בצלילות לילה ונמשך אל פנסי הצוללנים.';

  @override
  String get species_caribbean_reef_squid_name => 'דיונון שונית קריבי';

  @override
  String get species_caribbean_reef_squid_desc =>
      'דיונון סקרן המרחף לרוב בקבוצות קטנות סמוך לשולי השוניות בקריביים.';

  @override
  String get species_bobtail_squid_name => 'דיונון קטום-זנב';

  @override
  String get species_bobtail_squid_desc =>
      'דיונון לילי זעיר הטומן את עצמו בחול ביום, מציאה נחשקת בצלילות מאק.';

  @override
  String get species_chambered_nautilus_name => 'נאוטילוס תאי';

  @override
  String get species_chambered_nautilus_desc =>
      'מאובן חי קדום בעל קונכייה מסולסלת, נצפה לעיתים רחוקות בידי צוללנים במים עמוקים עם שחר.';

  @override
  String get species_spanish_dancer_name => 'הרקדנית הספרדייה';

  @override
  String get species_spanish_dancer_desc =>
      'מין חשופית הים הגדול ביותר, שוחה בתנועות גליות של מעטפת אדומה המזכירות רקדנית פלמנקו.';

  @override
  String get species_chromodoris_willani_name => 'כרומודוריס של וילן';

  @override
  String get species_chromodoris_willani_desc =>
      'חשופית ים מרשימה בכחול ושחור עם שוליים לבנים, נפוצה בהודו-פסיפי.';

  @override
  String get species_chromodoris_lochi_name => 'כרומודוריס של לוך';

  @override
  String get species_chromodoris_lochi_desc =>
      'חשופית ים כחולה בעלת קווים כהים ומסגרת לבנה, מצויה ברחבי האוקיינוס השקט הטרופי.';

  @override
  String get species_chromodoris_magnifica_name => 'כרומודוריס מפואר';

  @override
  String get species_chromodoris_magnifica_desc =>
      'חשופית ים זוהרת בכחול, לבן וכתום, מצויה בשוניות האלמוגים של ההודו-פסיפי.';

  @override
  String get species_chromodoris_annae_name => 'כרומודוריס של אנה';

  @override
  String get species_chromodoris_annae_desc =>
      'חשופית ים בכחול עמוק בעלת קווים שחורים וקרנוני חוש וזימים כתומי-קצה.';

  @override
  String get species_nembrotha_kubaryana_name => 'חשופית ניאון משתנה';

  @override
  String get species_nembrotha_kubaryana_desc =>
      'חשופית ים ירוקה כהה בעלת סימנים כתומים או אדומים עזים, ניזונה מנרתיקיות.';

  @override
  String get species_nembrotha_cristata_name => 'נמברותה מצויצת';

  @override
  String get species_nembrotha_cristata_desc =>
      'חשופית ים שחורה בעלת יבלות ופסים בירוק זוהר, מצויה בשוניות ההודו-פסיפי.';

  @override
  String get species_phyllidia_varicosa_name => 'פילידיה מגובששת';

  @override
  String get species_phyllidia_varicosa_desc =>
      'חשופית ים בגוון כחול-אפור בעלת יבלות מורמות צהובות-קצה, רעילה לטורפים.';

  @override
  String get species_phyllidia_ocellata_name => 'פילידיה עינונית';

  @override
  String get species_phyllidia_ocellata_desc =>
      'חשופית ים לבנה בעלת יבלות מורמות מוקפות טבעות ורודות, מצויה בשוניות טרופיות.';

  @override
  String get species_pikachu_nudibranch_name => 'חשופית פיקאצ\'ו';

  @override
  String get species_pikachu_nudibranch_desc =>
      'חשופית ים זעירה בצהוב ושחור המזכירה דמות מצוירת, מצויה באוקיינוס השקט.';

  @override
  String get species_anna_rosefieldi_name => 'חשופית רובואסטרה';

  @override
  String get species_anna_rosefieldi_desc =>
      'חשופית ים טורפת בעלת גוף כהה ופסים אורכיים בוהקים, הצדה חשופיות אחרות.';

  @override
  String get species_lettuce_sea_slug_name => 'חשופית חסה';

  @override
  String get species_lettuce_sea_slug_desc =>
      'חשופית ים ירוקה ומקומטת השומרת בגופה כלורופלסטים מאצות לצורך פוטוסינתזה.';

  @override
  String get species_blue_dragon_nudibranch_name => 'חשופית דרקון כחול';

  @override
  String get species_blue_dragon_nudibranch_desc =>
      'חשופית ים ארוכה ממשפחת האאוליד בעלת בליטות כחולות-קצה המאכסנות אצות סימביוטיות.';

  @override
  String get species_gloomy_nudibranch_name => 'חשופית קודרת';

  @override
  String get species_gloomy_nudibranch_desc =>
      'חשופית ים בגוון כחול-ירוק כהה בעלת רכסים כחולי-שוליים, נפוצה בשוניות ההודו-פסיפי.';

  @override
  String get species_ocellined_nudibranch_name => 'חשופית מקווקוות';

  @override
  String get species_ocellined_nudibranch_desc =>
      'חשופית ים לבנה בעלת רכסים בקווים כתומים היוצרים דוגמאות גיאומטריות על המעטפת.';

  @override
  String get species_glossodoris_cincta_name => 'חשופית גלוסודוריס';

  @override
  String get species_glossodoris_cincta_desc =>
      'חשופית ים בגוון שמנת בעלת מסגרת חומה כהה ושוליים כתומים במעטפת.';

  @override
  String get species_jorunna_funebris_name => 'חשופית מנוקדת';

  @override
  String get species_jorunna_funebris_desc =>
      'חשופית ים לבנה המכוסה בפקעיות שחורות-קצה, ומזכירה ארנבון פרוותי.';

  @override
  String get species_ceratosoma_trilobatum_name => 'חשופית תלת-אונתית';

  @override
  String get species_ceratosoma_trilobatum_desc =>
      'חשופית ים גדולה בעלת קרן גב גבוהה ואונות צדדיות בגווני סגול וצהוב.';

  @override
  String get species_hypselodoris_apolegma_name => 'היפסלודוריס סגולה';

  @override
  String get species_hypselodoris_apolegma_desc =>
      'חשופית ים סגולה ואלגנטית בעלת שוליים לבנים במעטפת, מצויה בשוניות ההודו-פסיפי.';

  @override
  String get species_hypselodoris_bullockii_name => 'היפסלודוריס של בולוק';

  @override
  String get species_hypselodoris_bullockii_desc =>
      'חשופית ים בוורוד וסגול בעלת קרנוני חוש צהובי-קצה, בשוניות ההודו-פסיפי.';

  @override
  String get species_flabellina_exoptata_name => 'פלבלינה נחשקת';

  @override
  String get species_flabellina_exoptata_desc =>
      'חשופית ים שקופה למחצה ממשפחת האאוליד בעלת בליטות כתומות סגולות-קצה, מצויה במים טרופיים.';

  @override
  String get species_risbecia_tryoni_name => 'ריסבקיה של טריון';

  @override
  String get species_risbecia_tryoni_desc =>
      'חשופית ים גדולה בחום וכחול, נמצאת לרוב בזוגות הזדווגות בשוניות ההודו-פסיפי.';

  @override
  String get species_goniobranchus_kuniei_name => 'חשופית של קוניה';

  @override
  String get species_goniobranchus_kuniei_desc =>
      'חשופית ים לבנה בנקודות כתומות ובעלת שולי מעטפת סגולים, מצויה במערב האוקיינוס השקט.';

  @override
  String get species_mexichromis_multituberculata_name => 'חשופית רבת-פקעיות';

  @override
  String get species_mexichromis_multituberculata_desc =>
      'חשופית ים בסגול ולבן בעלת פקעיות מורמות ותוספות כתומות-קצה.';

  @override
  String get species_chromodoris_dianae_name => 'כרומודוריס של דיאנה';

  @override
  String get species_chromodoris_dianae_desc =>
      'חשופית ים כחולה בוהקת בעלת פסים שחורים וזימים כתומים, מצויה במערב האוקיינוס השקט.';

  @override
  String get species_phyllodesmium_poindimiei_name => 'חשופית סולארית';

  @override
  String get species_phyllodesmium_poindimiei_desc =>
      'חשופית ים שקופה למחצה ממשפחת האאוליד בעלת בליטות מסועפות המאכסנות אצות סימביוטיות.';

  @override
  String get species_chromodoris_elisabethina_name => 'כרומודוריס של אליזבת';

  @override
  String get species_chromodoris_elisabethina_desc =>
      'חשופית ים בעלת קווים כחולים וצהובים ושוליים לבנים במעטפת, נפוצה בדרום-מזרח אסיה.';

  @override
  String get species_doridella_batava_name => 'דורית בטאבית';

  @override
  String get species_doridella_batava_desc =>
      'חשופית ים ממשפחת הדורידים שצבעה משתנה משחור לחום, מצויה מתחת לסלעים ולשברי אלמוגים בשוניות ההודו-פסיפי.';

  @override
  String get species_tiger_cowrie_name => 'קאורית טיגריס';

  @override
  String get species_tiger_cowrie_desc =>
      'קונכיית קאורי גדולה ומנוקדת המצויה בשוניות טרופיות, ולרוב מכוסה חלקית במעטפת שלה.';

  @override
  String get species_tritons_trumpet_name => 'חצוצרת טריטון';

  @override
  String get species_tritons_trumpet_desc =>
      'חילזון טורף גדול ואויבו הטבעי של כוכב ים כתר הקוצים.';

  @override
  String get species_queen_conch_name => 'קונכיית המלכה';

  @override
  String get species_queen_conch_desc =>
      'קונכייה גדולה ואייקונית של ערוגות עשב הים בקריביים, בעלת שפה פנימית ורודה אופיינית.';

  @override
  String get species_banded_coral_shrimp_name => 'חסילון אלמוגים מפוספס';

  @override
  String get species_banded_coral_shrimp_desc =>
      'חסילון מנקה בפסים אדומים ולבנים ובעל מחושים לבנים ארוכים, מצוי בנקיקי שונית.';

  @override
  String get species_mantis_shrimp_name => 'חסילון גמל שלמה טווסי';

  @override
  String get species_mantis_shrimp_desc =>
      'טורף צבעוני בעל תוספות חזקות דמויות אלה המסוגלות לנפץ קונכיות.';

  @override
  String get species_cleaner_shrimp_name => 'חסילון מנקה ארגמן';

  @override
  String get species_cleaner_shrimp_desc =>
      'חסילון אדום ולבן בוהק המקים תחנות ניקוי לשירות דגי השונית.';

  @override
  String get species_pederson_cleaner_shrimp_name => 'חסילון מנקה של פדרסון';

  @override
  String get species_pederson_cleaner_shrimp_desc =>
      'חסילון מנקה קריבי שקוף למחצה החי בין זרועות שושנות ים.';

  @override
  String get species_harlequin_shrimp_name => 'חסילון הרלקין';

  @override
  String get species_harlequin_shrimp_desc =>
      'חסילון בעל דוגמה מרהיבה וצבתות שטוחות הניזון אך ורק מכוכבי ים.';

  @override
  String get species_coleman_shrimp_name => 'חסילון קולמן';

  @override
  String get species_coleman_shrimp_desc =>
      'חסילון זעיר החי בזוגות על קיפודי אש, נחשק מאוד בקרב צלמי תת-מים.';

  @override
  String get species_emperor_shrimp_name => 'חסילון קיסרי';

  @override
  String get species_emperor_shrimp_desc =>
      'חסילון קומנסלי צבעוני הרוכב על מלפפוני ים ועל חשופיות ים.';

  @override
  String get species_sexy_shrimp_name => 'חסילון סקסי';

  @override
  String get species_sexy_shrimp_desc =>
      'חסילון שושנות ים זעיר הידוע בריקוד נענוע הזנב שלו, פופולרי בצילומי מאקרו.';

  @override
  String get species_marble_shrimp_name => 'חסילון שיש';

  @override
  String get species_marble_shrimp_desc =>
      'חסילון לילי מנומר בעל רגליים נוצתיות, מסתתר ביום בנקיקי שונית.';

  @override
  String get species_spiny_lobster_name => 'לובסטר קוצני קריבי';

  @override
  String get species_spiny_lobster_desc =>
      'לובסטר גדול נטול צבתות בעל מחושים ארוכים, מסתתר מתחת למדפי שונית.';

  @override
  String get species_painted_spiny_lobster_name => 'לובסטר קוצני מצויר';

  @override
  String get species_painted_spiny_lobster_desc =>
      'לובסטר צבעוני להפליא בעל רגליים מפוספסות בכחול, ירוק ולבן בשוניות ההודו-פסיפי.';

  @override
  String get species_slipper_lobster_name => 'לובסטר נעל';

  @override
  String get species_slipper_lobster_desc =>
      'לובסטר לילי שטוח-גוף בעל לוחות מחושים רחבים במקום שוטים ארוכים.';

  @override
  String get species_squat_lobster_name => 'לובסטר גוץ';

  @override
  String get species_squat_lobster_desc =>
      'סרטן זעיר בגוון ורוד-סגול החי על ספוגי חבית ענקיים, אהוב על צלמי מאקרו.';

  @override
  String get species_hermit_crab_name => 'סרטן נזיר כחול-רגליים';

  @override
  String get species_hermit_crab_desc =>
      'סרטן נזיר קטן בעל רגליים כחולות בוהקות, נצפה לרוב בשוניות הקריביים.';

  @override
  String get species_orangutan_crab_name => 'סרטן אורנגאוטן';

  @override
  String get species_orangutan_crab_desc =>
      'סרטן שעיר וזעיר החי באלמוג בועות, ושמו ניתן לו בשל דמיונו לאורנגאוטן.';

  @override
  String get species_decorator_crab_name => 'סרטן מקשט';

  @override
  String get species_decorator_crab_desc =>
      'אמן התחפושות המצמיד ספוגים, אצות והידרואידים אל שריון הגב שלו.';

  @override
  String get species_porcelain_crab_name => 'סרטן חרסינה של שושנות ים';

  @override
  String get species_porcelain_crab_desc =>
      'סרטן שטוח ומנוקד החי בשושנות ים ומסנן מזון בעזרת איברי פה נוצתיים.';

  @override
  String get species_arrow_crab_name => 'סרטן חץ';

  @override
  String get species_arrow_crab_desc =>
      'סרטן קריבי דקיק בעל חרטום מחודד ארוך ורגליים מפוספסות.';

  @override
  String get species_channel_clinging_crab_name => 'סרטן נאחז';

  @override
  String get species_channel_clinging_crab_desc =>
      'סרטן שונית קריבי גדול בעל גוף כהה וצבתות אדומות-כתומות, מצוי בנקיקים.';

  @override
  String get species_coral_crab_name => 'סרטן שומר אלמוגים';

  @override
  String get species_coral_crab_desc =>
      'סרטן קטן ומנוקד החי בסימביוזה באלמוגי Pocillopora ומגן על מארחו.';

  @override
  String get species_crown_of_thorns_starfish_name => 'כוכב ים כתר הקוצים';

  @override
  String get species_crown_of_thorns_starfish_desc =>
      'כוכב ים ארסי רב-זרועות הניזון מאלמוגים ומסוגל להחריב שוניות בעת התפרצויות.';

  @override
  String get species_blue_linckia_starfish_name => 'כוכב ים לינקיה כחול';

  @override
  String get species_blue_linckia_starfish_desc =>
      'כוכב ים בכחול עז הנצפה לרוב במישורי ובמדרונות השוניות של ההודו-פסיפי.';

  @override
  String get species_red_knob_starfish_name => 'כוכב ים אדום-פקעות';

  @override
  String get species_red_knob_starfish_desc =>
      'כוכב ים אפור וגדול בעל קוצים בולטים אדומי-קצה, מצוי באזורי חול בשוניות.';

  @override
  String get species_chocolate_chip_starfish_name => 'כוכב ים שוקולד צ\'יפס';

  @override
  String get species_chocolate_chip_starfish_desc =>
      'כוכב ים בגוון חול בעל פקעות כהות מורמות המזכירות שבבי שוקולד, מצוי במצעים חוליים.';

  @override
  String get species_cushion_star_name => 'כוכב ים כרית';

  @override
  String get species_cushion_star_desc =>
      'כוכב ים תפוח ומחומש בעל זרועות מקוצרות, מצוי במישורי השונית של ההודו-פסיפי.';

  @override
  String get species_fromia_starfish_name => 'כוכב ים אלגנטי';

  @override
  String get species_fromia_starfish_desc =>
      'כוכב ים קטן בגוון כתום-אדום בעל שולי לוחיות בהירים היוצרים דוגמה דמויית ריצוף.';

  @override
  String get species_basket_star_name => 'כוכב סל';

  @override
  String get species_basket_star_desc =>
      'זרועותיו המסועפות להפליא נפרשות בלילה כדי לסנן מזון מן הזרם.';

  @override
  String get species_brittle_star_name => 'כוכב שביר מפוספס';

  @override
  String get species_brittle_star_desc =>
      'כוכב שביר מפוספס המצוי מתחת לסלעים ובנקיקים, בעל זרועות זריזות דמויות נחש.';

  @override
  String get species_feather_star_name => 'כוכב נוצה';

  @override
  String get species_feather_star_desc =>
      'קרינואיד רב-זרועות הנח על בליטות בשונית ומסנן מזון בעזרת זרועותיו הנוצתיות.';

  @override
  String get species_black_feather_star_name => 'כוכב נוצה שחור';

  @override
  String get species_black_feather_star_desc =>
      'קרינואיד כהה המסוגל לשחות למרחקים קצרים בנפנוף קצבי של זרועותיו הרבות.';

  @override
  String get species_long_spined_sea_urchin_name => 'קיפוד ים ארוך-קוצים';

  @override
  String get species_long_spined_sea_urchin_desc =>
      'קיפוד ים שחור בעל קוצים ארוכים וארסיים, רועה חיוני בשוניות הקריביים.';

  @override
  String get species_fire_urchin_name => 'קיפוד ים אש';

  @override
  String get species_fire_urchin_desc =>
      'קיפוד ים רך-גוף בעל קוצים ארסיים הגורמים לעקיצות כואבות במגע.';

  @override
  String get species_pencil_urchin_name => 'קיפוד ים עיפרון';

  @override
  String get species_pencil_urchin_desc =>
      'קיפוד ים חסון בעל קוצים עבים וקהים, נתקע בנקיקי השונית.';

  @override
  String get species_collector_urchin_name => 'קיפוד ים אספן';

  @override
  String get species_collector_urchin_desc =>
      'קיפוד ים המכסה את עצמו בשברי פסולת ובקטעי אצות לצורך הסוואה.';

  @override
  String get species_sea_apple_name => 'תפוח ים';

  @override
  String get species_sea_apple_desc =>
      'מלפפון ים צבעוני להפליא בעל זרועות פה המשמשות לסינון מזון.';

  @override
  String get species_pineapple_sea_cucumber_name => 'מלפפון ים אננס';

  @override
  String get species_pineapple_sea_cucumber_desc =>
      'מלפפון ים גדול בגוון כתום-אדום בעל פטמיות בצורת כוכב, מצוי במדרונות שונית.';

  @override
  String get species_black_sea_cucumber_name => 'מלפפון ים שחור';

  @override
  String get species_black_sea_cucumber_desc =>
      'מלפפון ים שחור ונפוץ המצוי במישורי חול בשוניות ברחבי ההודו-פסיפי.';

  @override
  String get species_leopard_sea_cucumber_name => 'מלפפון ים מנומר';

  @override
  String get species_leopard_sea_cucumber_desc =>
      'מלפפון ים מנוקד הפולט צינוריות קובייריאניות לבנות ודביקות כשמפריעים לו.';

  @override
  String get species_sand_dollar_name => 'דולר החול';

  @override
  String get species_sand_dollar_desc =>
      'קיפוד ים שטוח בצורת דיסקה, מצוי טמון חלקית במצעים חוליים.';

  @override
  String get species_moon_jellyfish_name => 'מדוזת ירח';

  @override
  String get species_moon_jellyfish_desc =>
      'מדוזה שקופה למחצה בצורת פעמון שארבע בלוטות המין שלה, בצורת פרסה, נראות דרך גופה.';

  @override
  String get species_lions_mane_jellyfish_name => 'מדוזת רעמת האריה';

  @override
  String get species_lions_mane_jellyfish_desc =>
      'אחד ממיני המדוזות הגדולים בעולם, בעל זרועות ארוכות ונגררות במים קרים.';

  @override
  String get species_box_jellyfish_name => 'מדוזת קופסה';

  @override
  String get species_box_jellyfish_desc =>
      'מדוזה מסוכנת ביותר בעלת ארס רב-עוצמה, מצויה במים הטרופיים של ההודו-פסיפי.';

  @override
  String get species_upside_down_jellyfish_name => 'מדוזה הפוכה';

  @override
  String get species_upside_down_jellyfish_desc =>
      'מדוזה יוצאת דופן הנחה על קרקעיות חול כשפעמונה כלפי מטה כדי לאפשר פוטוסינתזה לאצות שבגופה.';

  @override
  String get species_blue_blubber_jellyfish_name => 'מדוזה כחולה אוסטרלית';

  @override
  String get species_blue_blubber_jellyfish_desc =>
      'מדוזה בכחול-לבן בעלת פעמון מוצק וזרועות פה מסולסלות, נפוצה במים האוסטרליים.';

  @override
  String get species_fried_egg_jellyfish_name => 'מדוזת ביצת עין';

  @override
  String get species_fried_egg_jellyfish_desc =>
      'מדוזה ים-תיכונית בעלת כיפה צהובה המזכירה ביצת עין, ועקיצתה קלה.';

  @override
  String get species_pacific_sea_nettle_name => 'סרפד ים פסיפי';

  @override
  String get species_pacific_sea_nettle_desc =>
      'מדוזה בגוון חום-זהוב בעלת זרועות ארוכות ונגררות, מצויה לאורך חופי האוקיינוס השקט.';

  @override
  String get species_compass_jellyfish_name => 'מדוזת מצפן';

  @override
  String get species_compass_jellyfish_desc =>
      'מדוזה חומה-לבנה בעלת סימנים בצורת V המתפצלים כמו שושנת רוחות.';

  @override
  String get species_spotted_jellyfish_name => 'מדוזה מנוקדת';

  @override
  String get species_spotted_jellyfish_desc =>
      'מדוזה זהובה בנקודות לבנות, מפורסמת במילוי אגם המדוזות שבפלאו.';

  @override
  String get species_barrel_jellyfish_name => 'מדוזת חבית';

  @override
  String get species_barrel_jellyfish_desc =>
      'מדוזה גדולה בצורת כיפה בעלת זרועות פה מסולסלות ועקיצה קלה, נפוצה באוקיינוס האטלנטי.';

  @override
  String get species_persian_carpet_flatworm_name => 'תולעת שטוחה שטיח פרסי';

  @override
  String get species_persian_carpet_flatworm_desc =>
      'תולעת שטוחה שחורה ומקושטת בעלת שוליים צהובים-כתומים, ולרוב מבלבלים בינה לבין חשופית ים.';

  @override
  String get species_leopard_flatworm_name => 'תולעת שטוחה מנומרת';

  @override
  String get species_leopard_flatworm_desc =>
      'תולעת שטוחה שקופה למחצה בעלת כתמים דמויי נמר, גולשת על מצעי השונית.';

  @override
  String get species_divided_flatworm_name => 'תולעת שטוחה מחולקת';

  @override
  String get species_divided_flatworm_desc =>
      'תולעת שטוחה מרשימה בשחור וכתום המחקה חשופיות ים רעילות לשם הגנה.';

  @override
  String get species_blue_pseudoceros_flatworm_name =>
      'תולעת שטוחה פסאודוצרוס כחולה';

  @override
  String get species_blue_pseudoceros_flatworm_desc =>
      'תולעת שטוחה בכחול עמוק בעלת שוליים כתומים, גולשת על פני השונית בהודו-פסיפי.';

  @override
  String get species_racing_stripe_flatworm_name => 'תולעת שטוחה פס מרוץ';

  @override
  String get species_racing_stripe_flatworm_desc =>
      'תולעת שטוחה בגוון שמנת בעלת פס מרכזי כהה ובולט ושוליים מסולסלים.';

  @override
  String get species_christmas_tree_worm_name => 'תולעת עץ חג המולד';

  @override
  String get species_christmas_tree_worm_desc =>
      'תולעת צבעונית בעלת כתר לולייני הנעוצה באלמוג ונסוגה מיד עם התקרבות.';

  @override
  String get species_feather_duster_worm_name => 'תולעת מטאטא נוצות';

  @override
  String get species_feather_duster_worm_desc =>
      'תולעת החיה בצינור ובעלת כתר מניפתי של שערות נוצתיות לסינון מזון.';

  @override
  String get species_fire_worm_name => 'תולעת אש מזוקנת';

  @override
  String get species_fire_worm_desc =>
      'תולעת זיפים בעלת זיפים עוקצניים לבנים הגורמים לגירוי כואב במגע.';

  @override
  String get species_bobbit_worm_name => 'תולעת בוביט';

  @override
  String get species_bobbit_worm_desc =>
      'טורף מארב המסתתר בחול ובעל לסתות חזקות המכות במהירות הבזק.';

  @override
  String get species_social_feather_duster_name => 'תולעת מטאטא נוצות חברתית';

  @override
  String get species_social_feather_duster_desc =>
      'תולעת צינור מושבתית היוצרת אשכולות של כתרים עדינים ומפוספסים בשוניות הקריביים.';

  @override
  String get species_giant_clam_name => 'צדפת ענק';

  @override
  String get species_giant_clam_desc =>
      'הצדפה הדו-קשוותית הגדולה ביותר בעולם, ורקמת המעטפת הנוצצת שלה מאכסנת אצות סימביוטיות.';

  @override
  String get species_boring_clam_name => 'צדפה קודחת';

  @override
  String get species_boring_clam_desc =>
      'צדפה קטנה וצבעונית הקודחת אל תוך סלע האלמוג וחושפת רק את מעטפתה העזה.';

  @override
  String get species_maxima_clam_name => 'צדפת מקסימה';

  @override
  String get species_maxima_clam_desc =>
      'צדפה צבעונית להפליא הנעוצה בסלע השונית ובעלת מעטפת בכחול וירוק חשמליים.';

  @override
  String get species_flame_scallop_name => 'צדפת להבה';

  @override
  String get species_flame_scallop_desc =>
      'צדפה דו-קשוותית אדומה ובה הבזקי אור לבנים לאורך שולי המעטפת, מצויה בנקיקי שונית.';

  @override
  String get species_thorny_oyster_name => 'צדפת קוצים';

  @override
  String get species_thorny_oyster_desc =>
      'צדפה דו-קשוותית קוצנית המחוברת לסלע השונית, ולרוב מכוסה בספוגים ובאצות.';

  @override
  String get species_magnificent_sea_anemone_name => 'שושנת ים מפוארת';

  @override
  String get species_magnificent_sea_anemone_desc =>
      'שושנת ים גדולה וצבעונית המארחת דגי ליצן, בעלת עמוד בולט וזרועות מתנופפות.';

  @override
  String get species_bubble_tip_anemone_name => 'שושנת ים בועות';

  @override
  String get species_bubble_tip_anemone_desc =>
      'מארחת פופולרית של דגי ליצן, בעלת זרועות עם קצוות בולבוסיים בירוק, חום או ורוד.';

  @override
  String get species_giant_carpet_anemone_name => 'שושנת ים שטיח ענקית';

  @override
  String get species_giant_carpet_anemone_desc =>
      'שושנת ים ענקית בעלת זרועות קצרות ודביקות, שקוטרה עשוי לעלות על מטר.';

  @override
  String get species_haddon_carpet_anemone_name => 'שושנת ים שטיח של האדון';

  @override
  String get species_haddon_carpet_anemone_desc =>
      'שושנת שטיח שטוחה במצעים חוליים המארחת מגוון דגי ליצן וסרטני חרסינה.';

  @override
  String get species_long_tentacle_anemone_name => 'שושנת ים ארוכת-זרועות';

  @override
  String get species_long_tentacle_anemone_desc =>
      'שושנת ים של קרקעיות חול בעלת זרועות ארוכות ומתנופפות, ולרוב מארחת דגי ליצן.';

  @override
  String get species_tube_anemone_name => 'שושנת ים צינורית';

  @override
  String get species_tube_anemone_desc =>
      'שושנת ים אלגנטית החיה בצינור קלפי בחול ובעלת שני מעגלי זרועות.';

  @override
  String get species_hell_fire_anemone_name => 'שושנת ים אש הגיהינום';

  @override
  String get species_hell_fire_anemone_desc =>
      'שושנת ים עוקצנית ביותר בעלת זרועות מסועפות הדומות לאלמוג רך.';

  @override
  String get species_beaded_sea_anemone_name => 'שושנת ים חרוזים';

  @override
  String get species_beaded_sea_anemone_desc =>
      'שושנת ים בעלת קצות זרועות תפוחים דמויי חרוזים, מצויה באזורי חול בשוניות ההודו-פסיפי.';

  @override
  String get species_condylactis_anemone_name => 'שושנת ים קריבית ענקית';

  @override
  String get species_condylactis_anemone_desc =>
      'שושנת ים קריבית גדולה בעלת זרועות סגולות-קצה, מצויה על מצעי שונית סלעיים.';

  @override
  String get species_sand_anemone_name => 'שושנת ים חולית';

  @override
  String get species_sand_anemone_desc =>
      'שושנת ים עדינה הטמונה חלקית בחול ובעלת זרועות סגולות-קצה.';

  @override
  String get species_barrel_sponge_name => 'ספוג חבית ענק';

  @override
  String get species_barrel_sponge_desc =>
      'ספוג עצום בצורת חבית המסוגל לחיות מאות שנים על קירות השונית בקריביים.';

  @override
  String get species_azure_vase_sponge_name => 'ספוג אגרטל תכול';

  @override
  String get species_azure_vase_sponge_desc =>
      'ספוג תוסס בצורת אגרטל בגוון כחול-סגול, מצוי על קירות השונית בקריביים.';

  @override
  String get species_yellow_tube_sponge_name => 'ספוג צינור צהוב';

  @override
  String get species_yellow_tube_sponge_desc =>
      'ספוג צינורי בצהוב בוהק הגדל באשכולות על קירות השונית בקריביים.';

  @override
  String get species_elephant_ear_sponge_name => 'ספוג אוזן פיל';

  @override
  String get species_elephant_ear_sponge_desc =>
      'ספוג כתום גדול בצורת מניפה הגדל על קירות ומתחת לגגונים בקריביים.';

  @override
  String get species_rope_sponge_name => 'ספוג חבל';

  @override
  String get species_rope_sponge_desc =>
      'ספוג אדום זקוף ומסועף הגדל במבנים דמויי חבל בשוניות הקריביים.';

  @override
  String get species_portuguese_man_o_war_name => 'ספינת המלחמה הפורטוגזית';

  @override
  String get species_portuguese_man_o_war_desc =>
      'מושבת הידרוזואה בעלת מצוף מלא גז וזרועות נגררות שעקיצתן כואבת ביותר.';

  @override
  String get species_fire_coral_name => 'אלמוג אש';

  @override
  String get species_fire_coral_desc =>
      'אינו אלמוג אמיתי אלא הידרוזואה הגורמת לצוללנים עקיצות כואבות במגע.';

  @override
  String get species_by_the_wind_sailor_name => 'מפרשן הרוח';

  @override
  String get species_by_the_wind_sailor_desc =>
      'מושבת הידרוזואה כחולה וצפה בעלת מפרש אלכסוני התופס את הרוח.';

  @override
  String get species_blue_button_name => 'כפתור כחול';

  @override
  String get species_blue_button_desc =>
      'מושבת הידרוזואה צפה בעלת דיסקה שטוחה והידרואידים כחולים דמויי זרועות.';

  @override
  String get species_giant_sea_hare_name => 'ארנבת ים ענקית';

  @override
  String get species_giant_sea_hare_desc =>
      'אחת מחשופיות הים הגדולות בעולם, בגוון חום כהה עד שחור, מצויה בערוגות קלפ.';

  @override
  String get species_sea_hare_name => 'ארנבת ים מנוקדת';

  @override
  String get species_sea_hare_desc =>
      'ארנבת ים גדולה בנקודות ירוקות הפולטת דיו סגול כשמפריעים לה.';

  @override
  String get species_nudibranch_berghia_name => 'חשופית ברגיה';

  @override
  String get species_nudibranch_berghia_desc =>
      'חשופית ים שקופה למחצה ממשפחת האאוליד בעלת בליטות לבנות-קצה, ניזונה משושנות ים.';

  @override
  String get species_sea_pen_name => 'עט ים';

  @override
  String get species_sea_pen_desc =>
      'אלמוג רך מושבתי בצורת נוצה המעוגן בחול ונסוג פנימה כשמפריעים לו.';

  @override
  String get species_blue_sea_star_name => 'כוכב ים כחול';

  @override
  String get species_blue_sea_star_desc =>
      'כוכב ים רב-גוני המתחדש משבר של זרוע בודדת, מצוי בשוניות ההודו-פסיפי.';

  @override
  String get species_reef_squid_name => 'דיונון שונית';

  @override
  String get species_reef_squid_desc =>
      'דיונון שונית דרומי הנפגש לרוב במים הממוזגים של אוסטרליה.';

  @override
  String get species_tiger_shrimp_name => 'חסילון טיגריס';

  @override
  String get species_tiger_shrimp_desc =>
      'חסילון גדול ומפוספס המצוי בקרקעיות חול ובערוגות עשב ים בהודו-פסיפי.';

  @override
  String get species_candy_crab_name => 'סרטן סוכריות';

  @override
  String get species_candy_crab_desc =>
      'סרטן זעיר וצבעוני המתמזג עם האלמוג הרך המארח בעזרת בליטות קוצניות ורודות או צהובות.';

  @override
  String get species_spider_crab_name => 'סרטן עכביש מקשט';

  @override
  String get species_spider_crab_desc =>
      'סרטן איטי המכוסה בספוגים ובאצות שהצמיד לגופו לצורך הסוואה.';

  @override
  String get species_anemone_shrimp_name => 'חסילון שושנת ים מפואר';

  @override
  String get species_anemone_shrimp_desc =>
      'חסילון שקוף בעל סימנים לבנים וסגולים החי בין זרועות שושנות ים.';

  @override
  String get species_snapping_shrimp_name => 'חסילון מקיש';

  @override
  String get species_snapping_shrimp_desc =>
      'חסילון קטן המפיק נקישה רועמת בעזרת צבתו הענקית, ולרוב חי בשותפות עם גוביים.';

  @override
  String get species_glass_sponge_name => 'סל הפרחים של ונוס';

  @override
  String get species_glass_sponge_desc =>
      'ספוג זכוכית עדין בעל שלד צורן מורכב, מצוי במים עמוקים.';

  @override
  String get species_toxic_sea_urchin_name => 'קיפוד ים פרח';

  @override
  String get species_toxic_sea_urchin_desc =>
      'קיפוד ים מושך למראה אך מטעה, מכוסה בצבתונים דמויי פרחים ובעל ארס רב-עוצמה.';

  @override
  String get species_slate_pencil_urchin_name => 'קיפוד ים עיפרון צפחה';

  @override
  String get species_slate_pencil_urchin_desc =>
      'קיפוד ים בעל קוצים עבים ומעוגלים, מצוי על מצעי שונית בקריביים ובאוקיינוס האטלנטי.';

  @override
  String get species_spiny_sea_star_name => 'כוכב ים קוצני';

  @override
  String get species_spiny_sea_star_desc =>
      'כוכב ים ממוזג וגדול בעל קוצים בולטים, מצוי במים האירופיים והאטלנטיים.';

  @override
  String get species_bat_star_name => 'כוכב ים עטלף';

  @override
  String get species_bat_star_desc =>
      'כוכב ים פסיפי בעל זרועות מחוברות בקרום, בגוני כתום, אדום או סגול, מצוי ביערות קלפ.';

  @override
  String get species_sunflower_star_name => 'כוכב ים חמנייה';

  @override
  String get species_sunflower_star_desc =>
      'כוכב ים ענק ומהיר בעל עד 24 זרועות, מצוי ביערות הקלפ של האוקיינוס השקט.';

  @override
  String get species_blood_star_name => 'כוכב ים דם';

  @override
  String get species_blood_star_desc =>
      'כוכב ים בגוון אדום-כתום בוהק בעל זרועות דקות, מצוי במים הממוזגים של האוקיינוס השקט.';

  @override
  String get species_common_cuttlefish_name => 'ספיה מצויה';

  @override
  String get species_common_cuttlefish_desc =>
      'אמנית הסוואה המצויה במים האירופיים ובים התיכון, ואישוניה בצורת האות W.';

  @override
  String get species_blue_spotted_crab_name => 'סרטן שחייה כחול-נקודות';

  @override
  String get species_blue_spotted_crab_desc =>
      'סרטן שחייה פעיל בעל נקודות כחולות על שריון הגב, מצוי במצעים חוליים בהודו-פסיפי.';

  @override
  String get species_sponge_crab_name => 'סרטן ספוג';

  @override
  String get species_sponge_crab_desc =>
      'סרטן החוצב ספוג חי ונושא אותו על גבו לצורך הסוואה.';

  @override
  String get species_horseshoe_crab_name => 'סרטן פרסה';

  @override
  String get species_horseshoe_crab_desc =>
      'פרוק רגליים קדום ממערכת הצבתניים בעל שריון דמוי קסדה, מצוי בקרקעיות חול באוקיינוס האטלנטי.';

  @override
  String get species_sea_spider_name => 'עכביש ים';

  @override
  String get species_sea_spider_desc =>
      'פרוק רגליים ימי עדין בעל רגליים ארוכות, נצפה זוחל על הידרואידים ועל טחביתנים.';

  @override
  String get species_sea_lily_name => 'שושן ים';

  @override
  String get species_sea_lily_desc =>
      'קרינואיד מגובעל ומאובן חי המצוי במים עמוקים ומסנן מזון בזרועותיו הנוצתיות.';

  @override
  String get species_mantis_shrimp_lysiosquilla_name => 'חסילון גמל שלמה דוקרן';

  @override
  String get species_mantis_shrimp_lysiosquilla_desc =>
      'חסילון גמל שלמה גדול וחופר בעל תוספות דוקרניות, מצוי במצעים חוליים.';

  @override
  String get species_purple_sea_urchin_name => 'קיפוד ים סגול';

  @override
  String get species_purple_sea_urchin_desc =>
      'קיפוד ים סגול ונפוץ המצוי ביערות הקלפ ובשלוליות הסלע של האוקיינוס השקט.';

  @override
  String get species_crown_jellyfish_name => 'מדוזת כתר';

  @override
  String get species_crown_jellyfish_desc =>
      'מדוזה בסגול עמוק בעלת פעמון מורם דמוי כתר, מצויה בהודו-פסיפי.';

  @override
  String get species_comb_jelly_name => 'דומדמנית ים';

  @override
  String get species_comb_jelly_desc =>
      'מסרקן זעיר וזוהר-ביולוגית בעל טורי מסרק נוצצים ושתי זרועות ארוכות.';

  @override
  String get species_warty_sea_slug_name => 'חשופית ים יבלולית';

  @override
  String get species_warty_sea_slug_desc =>
      'חשופית ים בכחול ושחור בעלת יבלות בכיפות צהובות, נצפית לרוב בשוניות ההודו-פסיפי.';

  @override
  String get species_doris_nudibranch_name => 'לימון ים';

  @override
  String get species_doris_nudibranch_desc =>
      'חשופית ים צהובה ומנוקדת ממשפחת הדורידים, מצויה במים הממוזגים של האוקיינוס השקט וניזונה מספוגים.';

  @override
  String get species_opalescent_nudibranch_name => 'חשופית אופלית';

  @override
  String get species_opalescent_nudibranch_desc =>
      'חשופית שקופה למחצה ממשפחת האאוליד בעלת בליטות כתומות בוהקות וקווי גב כחולים, במימי האוקיינוס השקט.';

  @override
  String get species_clown_nudibranch_name => 'חשופית ליצן';

  @override
  String get species_clown_nudibranch_desc =>
      'חשופית ים בגוון ורוד-כתום בעלת נקודות כחולות ולבנות, מצויה במים הממוזגים של אוסטרליה.';

  @override
  String get species_bottlenose_dolphin_name => 'דולפין אף-בקבוק';

  @override
  String get species_bottlenose_dolphin_desc =>
      'דולפין סקרן ושובב הנפגש תכופות על ידי צוללנים במים טרופיים וממוזגים.';

  @override
  String get species_spinner_dolphin_name => 'דולפין מסתחרר';

  @override
  String get species_spinner_dolphin_desc =>
      'דולפין אקרובטי הידוע בסיבובי האוויר שלו, נצפה לרוב בעדרים גדולים סמוך לשוניות אלמוגים.';

  @override
  String get species_common_dolphin_name => 'דולפין מצוי';

  @override
  String get species_common_dolphin_desc =>
      'דולפין מהיר בעל דוגמת שעון חול אופיינית, מצוי באוקיינוס הפתוח ובמים חופיים.';

  @override
  String get species_spotted_dolphin_name => 'דולפין מנוקד אטלנטי';

  @override
  String get species_spotted_dolphin_desc =>
      'דולפין מנוקד וידידותי המתקרב תכופות לצוללנים באיי בהאמה ובקריביים.';

  @override
  String get species_rissos_dolphin_name => 'דולפין של ריסו';

  @override
  String get species_rissos_dolphin_desc =>
      'דולפין גדול בעל גוף אפור מצולק היטב, מצוי במים עמוקים ומרוחקים מהחוף בכל העולם.';

  @override
  String get species_humpback_whale_name => 'לווייתן גדול-סנפיר';

  @override
  String get species_humpback_whale_desc =>
      'לווייתן מלכותי הידוע בקפיצותיו מהמים ובשירים מורכבים, נצפה בנדידות עונתיות.';

  @override
  String get species_grey_whale_name => 'לווייתן אפור';

  @override
  String get species_grey_whale_desc =>
      'לווייתן מזיפים הניזון מהקרקעית ונודד לאורך חופי האוקיינוס השקט, ולרוב מכוסה בברנקלים.';

  @override
  String get species_blue_whale_name => 'לווייתן כחול';

  @override
  String get species_blue_whale_desc =>
      'בעל החיים הגדול ביותר שחי אי פעם, נפגש מדי פעם על ידי צוללנים במים כחולים עמוקים.';

  @override
  String get species_sperm_whale_name => 'לווייתן הזרע';

  @override
  String get species_sperm_whale_desc =>
      'לווייתן צולל עמוק בעל ראש עצום, נצפה לעיתים נח על פני המים בין צלילה לצלילה.';

  @override
  String get species_orca_name => 'לווייתן קטלן';

  @override
  String get species_orca_desc =>
      'טורף-על בעל סימנים אופייניים בשחור ולבן, מצוי בכל אגני האוקיינוס.';

  @override
  String get species_minke_whale_name => 'לווייתן מינקי';

  @override
  String get species_minke_whale_desc =>
      'לווייתן מזיפים קטן יחסית המגלה סקרנות כלפי צוללנים, במיוחד בשונית המחסום הגדולה.';

  @override
  String get species_beluga_whale_name => 'בלוגה';

  @override
  String get species_beluga_whale_desc =>
      'לווייתן ארקטי לבן הידוע בקולותיו ובהתנהגותו החברתית במים קרים.';

  @override
  String get species_pilot_whale_name => 'לווייתן טייס קצר-סנפיר';

  @override
  String get species_pilot_whale_desc =>
      'לווייתן חברתי הצולל לעומק ונצפה לרוב בעדרים גדולים בימים טרופיים וממוזגים-חמים.';

  @override
  String get species_false_killer_whale_name => 'לווייתן קטלן מדומה';

  @override
  String get species_false_killer_whale_desc =>
      'דולפין אוקייני גדול המתקרב מדי פעם לצוללנים במים פתוחים.';

  @override
  String get species_dugong_name => 'דוגונג';

  @override
  String get species_dugong_desc =>
      'אוכל עשב עדין הרועה בערוגות עשב ים בהודו-פסיפי, קרוב משפחה של פרות הים.';

  @override
  String get species_west_indian_manatee_name => 'פרת ים מערב-הודית';

  @override
  String get species_west_indian_manatee_desc =>
      'אוכל עשב איטי המצוי במים חמים ורדודים, בשפכי נהרות ובמעיינות של הקריביים.';

  @override
  String get species_sea_otter_name => 'לוטרת ים';

  @override
  String get species_sea_otter_desc =>
      'יונק ימי כריזמטי המצוי ביערות הקלפ לאורך חופי צפון האוקיינוס השקט.';

  @override
  String get species_california_sea_lion_name => 'אריה ים קליפורני';

  @override
  String get species_california_sea_lion_desc =>
      'יונק סנפירי שובב וזריז המשחק לא פעם עם צוללנים לאורך חופי האוקיינוס השקט.';

  @override
  String get species_steller_sea_lion_name => 'אריה ים של שטלר';

  @override
  String get species_steller_sea_lion_desc =>
      'מין אריה הים הגדול ביותר, מצוי במים הקרים של צפון האוקיינוס השקט סמוך לחופים סלעיים.';

  @override
  String get species_harbor_seal_name => 'כלב ים נמל';

  @override
  String get species_harbor_seal_desc =>
      'כלב ים סקרן הנצפה לרוב במים חופיים ממוזגים, ולעיתים נח על סלעים סמוך לאתרי צלילה.';

  @override
  String get species_grey_seal_name => 'כלב ים אפור';

  @override
  String get species_grey_seal_desc =>
      'כלב ים גדול ושובב המצוי בצפון האוקיינוס האטלנטי, ידוע בהתקרבותו לצוללנים מתחת למים.';

  @override
  String get species_northern_elephant_seal_name => 'פיל ים צפוני';

  @override
  String get species_northern_elephant_seal_desc =>
      'כלב ים ענק הצולל לעומק רב, ולזכרים חדק גדול; מצוי לאורך חופי מזרח האוקיינוס השקט.';

  @override
  String get species_hawaiian_monk_seal_name => 'כלב ים נזירי הוואי';

  @override
  String get species_hawaiian_monk_seal_desc =>
      'כלב ים בסכנת הכחדה חמורה האנדמי להוואי, נצפה מדי פעם על ידי צוללנים בשוניות.';

  @override
  String get species_leopard_seal_name => 'כלב ים מנומר';

  @override
  String get species_leopard_seal_desc =>
      'טורף אנטארקטי רב-עוצמה בעל פרווה מנוקדת, נפגש על ידי צוללני מים קרים.';

  @override
  String get species_narwhal_name => 'נרוול';

  @override
  String get species_narwhal_desc =>
      'לווייתן ארקטי בעל חט לולייני ארוך, נצפה לעיתים רחוקות אך אייקוני בקרב היונקים הימיים.';

  @override
  String get species_green_sea_turtle_name => 'צב ים ירוק';

  @override
  String get species_green_sea_turtle_desc =>
      'צב ים גדול הנצפה לרוב רועה עשב ים במים טרופיים.';

  @override
  String get species_hawksbill_sea_turtle_name => 'צב ים חד-מקור';

  @override
  String get species_hawksbill_sea_turtle_desc =>
      'צב דייר שונית בעל מקור מחודד, ניזון מספוגים בין מבני האלמוגים.';

  @override
  String get species_loggerhead_sea_turtle_name => 'צב ים חום';

  @override
  String get species_loggerhead_sea_turtle_desc =>
      'צב בעל ראש גדול המצוי בימים ממוזגים וטרופיים, לרוב סמוך לשוניות סלע.';

  @override
  String get species_leatherback_sea_turtle_name => 'צב ים עורי';

  @override
  String get species_leatherback_sea_turtle_desc =>
      'הצב הגדול ביותר החי כיום, בעל שריון עורי וגמיש, וצולל לעומקים קיצוניים.';

  @override
  String get species_olive_ridley_sea_turtle_name => 'צב ים זיתי';

  @override
  String get species_olive_ridley_sea_turtle_desc =>
      'מין צב הים הקטן ביותר, ידוע באירועי הטלה המוניים ומתואמים המכונים arribadas.';

  @override
  String get species_kemps_ridley_sea_turtle_name => 'צב ים של קמפ';

  @override
  String get species_kemps_ridley_sea_turtle_desc =>
      'צב ים בסכנת הכחדה חמורה המצוי בעיקר במפרץ מקסיקו.';

  @override
  String get species_flatback_sea_turtle_name => 'צב ים שטוח-גב';

  @override
  String get species_flatback_sea_turtle_desc =>
      'אנדמי למים האוסטרליים, ניכר בשריונו השטוח ובבית הגידול החופי שלו.';

  @override
  String get species_brain_coral_name => 'אלמוג מוח';

  @override
  String get species_brain_coral_desc =>
      'אלמוג בונה שונית מסיבי בעל פני שטח מחורצים המזכירים מוח, נפוץ בשוניות הקריביים.';

  @override
  String get species_staghorn_coral_name => 'אלמוג קרן צבי';

  @override
  String get species_staghorn_coral_desc =>
      'אלמוג מסועף מהיר צמיחה היוצר סבכים צפופים, בית גידול קריטי לדגי השונית.';

  @override
  String get species_elkhorn_coral_name => 'אלמוג קרן איל';

  @override
  String get species_elkhorn_coral_desc =>
      'אלמוג מסועף גדול בעל ענפים שטוחים ומורחבים, בונה שונית מרכזי בקריביים.';

  @override
  String get species_table_coral_name => 'אלמוג שולחן';

  @override
  String get species_table_coral_desc =>
      'אלמוג שטוח היוצר לוחות, מצוי בשוניות ההודו-פסיפי ומספק מחסה למיני דגים רבים.';

  @override
  String get species_mushroom_coral_name => 'אלמוג פטרייה';

  @override
  String get species_mushroom_coral_desc =>
      'אלמוג בודד וחופשי בצורת דיסקה, מצוי באזורי חול סמוך לשוניות ההודו-פסיפי.';

  @override
  String get species_bubble_coral_name => 'אלמוג בועות';

  @override
  String get species_bubble_coral_desc =>
      'אלמוג ייחודי בעל שלפוחיות דמויות ענבים המתנפחות ביום כדי לקלוט אור.';

  @override
  String get species_plate_coral_name => 'אלמוג צלחת';

  @override
  String get species_plate_coral_desc =>
      'אלמוג לוחי דק היוצר מדפים מסולסלים, נפוץ במדרונות השונית של ההודו-פסיפי.';

  @override
  String get species_pillar_coral_name => 'אלמוג עמוד';

  @override
  String get species_pillar_coral_desc =>
      'אלמוג נדיר הצומח כלפי מעלה ויוצר עמודים גבוהים, מצוי בקריביים.';

  @override
  String get species_star_coral_name => 'אלמוג כוכב';

  @override
  String get species_star_coral_desc =>
      'בונה שונית מרכזי בקריביים היוצר מושבות גדולות בצורת גוש ופוליפים בצורת כוכב.';

  @override
  String get species_lettuce_coral_name => 'אלמוג חסה';

  @override
  String get species_lettuce_coral_desc =>
      'אלמוג לוחי דק בעל קפלים דמויי עלים, נפוץ בקירות ובמדרונות השונית בקריביים.';

  @override
  String get species_finger_coral_name => 'אלמוג אצבע';

  @override
  String get species_finger_coral_desc =>
      'אלמוג מסועף וחסון בעל בליטות עבות דמויות אצבעות, מצוי בשוניות רדודות.';

  @override
  String get species_massive_porites_name => 'אלמוג פוריטס מסיבי';

  @override
  String get species_massive_porites_desc =>
      'אלמוג גושי גדול שיכול לגדול במשך מאות שנים, בונה שונית דומיננטי בהודו-פסיפי.';

  @override
  String get species_cauliflower_coral_name => 'אלמוג כרובית';

  @override
  String get species_cauliflower_coral_desc =>
      'אלמוג מסועף וקומפקטי בצורת כרובית, נפוץ ברדודי השוניות הטרופיות.';

  @override
  String get species_flower_pot_coral_name => 'אלמוג עציץ';

  @override
  String get species_flower_pot_coral_desc =>
      'מושבה של פוליפים ארוכי זרועות הנפרשים ביום ומזכירים זר פרחים.';

  @override
  String get species_cup_coral_name => 'אלמוג גביע כתום';

  @override
  String get species_cup_coral_desc =>
      'אלמוג כתום בוהק שאינו מבצע פוטוסינתזה, מצוי על קירות ומתחת לגגונים במים טרופיים.';

  @override
  String get species_scroll_coral_name => 'אלמוג מגילה';

  @override
  String get species_scroll_coral_desc =>
      'אלמוג היוצר לוחות מגולגלים גדולים, נפוץ במדרונות השונית ובלגונות של ההודו-פסיפי.';

  @override
  String get species_cabbage_coral_name => 'אלמוג כרוב';

  @override
  String get species_cabbage_coral_desc =>
      'אלמוג לוחי בצורת דיסקה המזכיר עלי כרוב, מצוי באזורי שונית מוגנים.';

  @override
  String get species_hammer_coral_name => 'אלמוג פטיש';

  @override
  String get species_hammer_coral_desc =>
      'אלמוג בעל פוליפים גדולים וקצות זרועות בצורת עוגן או פטיש, פופולרי בשוניות ההודו-פסיפי.';

  @override
  String get species_torch_coral_name => 'אלמוג לפיד';

  @override
  String get species_torch_coral_desc =>
      'אלמוג מסועף בעל זרועות ארוכות ומתנופפות שקצותיהן זוהרים כנורות.';

  @override
  String get species_frogspawn_coral_name => 'אלמוג ביצי צפרדע';

  @override
  String get species_frogspawn_coral_desc =>
      'אלמוג בעל פוליפים גדולים וקצות זרועות מסועפים המזכירים ביצי צפרדע.';

  @override
  String get species_sea_fan_name => 'מניפת ים מצויה';

  @override
  String get species_sea_fan_desc =>
      'גורגוניה שטוחה בצורת מניפה הניצבת בניצב לזרם, אייקונית בשוניות הקריביים.';

  @override
  String get species_venus_sea_fan_name => 'מניפת ים של ונוס';

  @override
  String get species_venus_sea_fan_desc =>
      'גורגוניה עדינה בצורת מניפה, מצויה בשוניות רדודות בקריביים באזורי זרם מתון.';

  @override
  String get species_deepwater_sea_fan_name => 'מניפת ים של מים עמוקים';

  @override
  String get species_deepwater_sea_fan_desc =>
      'גורגוניה גדולה ושיחנית המצויה בקירות שונית עמוקים בקריביים.';

  @override
  String get species_sea_whip_name => 'שוט ים';

  @override
  String get species_sea_whip_desc =>
      'גורגוניה תמירה בצורת מוט, נצפית מתנועעת בזרם בשוניות האטלנטי והקריביים.';

  @override
  String get species_sea_plume_name => 'נוצת ים';

  @override
  String get species_sea_plume_desc =>
      'גורגוניה גבוהה ונוצתית היוצרת מושבות דמויות נוצה בפסגות השוניות בקריביים.';

  @override
  String get species_organ_pipe_coral_name => 'אלמוג עוגב';

  @override
  String get species_organ_pipe_coral_desc =>
      'צינורות שלד אדומים בוהקים עם פוליפים עדינים, מצוי בשוניות מוגנות בהודו-פסיפי.';

  @override
  String get species_leather_coral_name => 'אלמוג עור';

  @override
  String get species_leather_coral_desc =>
      'אלמוג רך בעל פני שטח חלקים ועוריים היוצר מושבות גדולות בצורת פטרייה.';

  @override
  String get species_toadstool_leather_coral_name => 'אלמוג עור פטרייה';

  @override
  String get species_toadstool_leather_coral_desc =>
      'אלמוג רך בעל גבעול עבה וכיפה שטוחה, נפוץ במישורי השונית של ההודו-פסיפי.';

  @override
  String get species_pulsing_xenia_name => 'קסניה פועמת';

  @override
  String get species_pulsing_xenia_desc =>
      'אלמוג רך בעל פוליפים הפועמים בקצב, מצוי במים מוגנים בהודו-פסיפי.';

  @override
  String get species_tree_coral_name => 'אלמוג עץ';

  @override
  String get species_tree_coral_desc =>
      'אלמוג רך ותוסס היוצר אשכולות דמויי עץ על קירות ומתחת לגגונים בים סוף.';

  @override
  String get species_blue_coral_name => 'אלמוג כחול';

  @override
  String get species_blue_coral_desc =>
      'אלמוג רך ייחודי בעל שלד כחול, מצוי במישורי שונית רדודים בהודו-פסיפי.';

  @override
  String get species_black_coral_name => 'אלמוג שחור';

  @override
  String get species_black_coral_desc =>
      'אלמוג מים עמוקים בעל שלד כהה, מצוי בקירות ובמדרונות תלולים מתחת ל-30 מטרים.';

  @override
  String get species_carnation_coral_name => 'אלמוג ציפורן';

  @override
  String get species_carnation_coral_desc =>
      'אלמוג רך וצבעוני להפליא המצוי מתחת למדפי סלע ועל קירות בהודו-פסיפי.';

  @override
  String get species_wire_coral_name => 'אלמוג חוט';

  @override
  String get species_wire_coral_desc =>
      'אלמוג שחור וארוך היוצר שוטים מסולסלים, ומארח גוביים וחסילונים.';

  @override
  String get species_dead_mans_fingers_name => 'אצבעות המת';

  @override
  String get species_dead_mans_fingers_desc =>
      'אלמוג רך ובשרני בעל אונות דמויות אצבעות, נפוץ בשוניות ממוזגות בצפון האטלנטי.';

  @override
  String get species_sun_coral_name => 'אלמוג שמש';

  @override
  String get species_sun_coral_desc =>
      'אלמוג בגוון צהוב-כתום שאינו מבצע פוטוסינתזה ופורש את פוליפיו בלילה על קירות בהודו-פסיפי.';

  @override
  String get species_lace_coral_name => 'אלמוג תחרה';

  @override
  String get species_lace_coral_desc =>
      'הידרו-אלמוג ורוד ועדין בעל ענפים דמויי תחרה, מצוי בנקיקים ומתחת למדפי סלע.';

  @override
  String get species_kenya_tree_coral_name => 'אלמוג עץ קניה';

  @override
  String get species_kenya_tree_coral_desc =>
      'אלמוג רך ועמיד בעל ענפים דמויי עץ, נפוץ בהודו-פסיפי.';

  @override
  String get species_colt_coral_name => 'אלמוג סייח';

  @override
  String get species_colt_coral_desc =>
      'אלמוג רך בעל ענפים עבים וגמישים המכוסים בפוליפים קטנים, בשוניות ההודו-פסיפי.';

  @override
  String get species_turtle_grass_name => 'עשב צבים';

  @override
  String get species_turtle_grass_desc =>
      'עשב הים הדומיננטי בקריביים, בעל עלים רחבים ושטוחים ומקור מזון חיוני לצבי ים.';

  @override
  String get species_eelgrass_name => 'זוסטרה';

  @override
  String get species_eelgrass_desc =>
      'עשב ים ממוזג היוצר אחווי מים צפופים המשמשים בית גידול לגידול צאצאים.';

  @override
  String get species_manatee_grass_name => 'עשב פרות ים';

  @override
  String get species_manatee_grass_desc =>
      'עשב ים בעל עלים גליליים המצוי באזורי חול בקריביים, לרוב סמוך לערוגות עשב צבים.';

  @override
  String get species_shoal_grass_name => 'עשב שרטון';

  @override
  String get species_shoal_grass_desc =>
      'עשב ים חלוץ בעל עלים צרים המאכלס אזורי חול שהופרו בקריביים.';

  @override
  String get species_paddle_grass_name => 'עשב משוט';

  @override
  String get species_paddle_grass_desc =>
      'עשב ים קטן ועדין בעל עלים סגלגלים, מצוי במים עמוקים יותר ברחבי האזורים הטרופיים.';

  @override
  String get species_neptune_grass_name => 'עשב נפטון';

  @override
  String get species_neptune_grass_desc =>
      'עשב ים ים-תיכוני היוצר אחווים נרחבים החיוניים למערכות האקולוגיות של החוף.';

  @override
  String get species_giant_kelp_name => 'קלפ ענק';

  @override
  String get species_giant_kelp_desc =>
      'מין היוצר יערות תת-מימיים מתנשאים לגובה של עד 60 מטרים, אייקוני לצלילה בקליפורניה.';

  @override
  String get species_bull_kelp_name => 'קלפ שור';

  @override
  String get species_bull_kelp_desc =>
      'קלפ של האוקיינוס השקט בעל גבעול ארוך יחיד ומצוף בולבוסי, יוצר יערות בעלי חופה צפופה.';

  @override
  String get species_bladder_wrack_name => 'פוקוס שלפוחי';

  @override
  String get species_bladder_wrack_desc =>
      'אצה חומה נפוצה בעלת שלפוחיות אוויר בזוגות, מצויה באזורי הגאות והשפל של צפון האטלנטי.';

  @override
  String get species_sargassum_name => 'סרגסום';

  @override
  String get species_sargassum_desc =>
      'אצה חומה צפה חופשית היוצרת רפסודות המספקות מחסה לדגים צעירים ולחסרי חוליות.';

  @override
  String get species_kelp_forest_ecklonia_name => 'קלפ אקלוניה';

  @override
  String get species_kelp_forest_ecklonia_desc =>
      'הקלפ הדומיננטי במימי חצי הכדור הדרומי, יוצר יערות תת-מימיים חשובים.';

  @override
  String get species_coralline_algae_name => 'אצות גיריות';

  @override
  String get species_coralline_algae_desc =>
      'אצה אדומה קשה ומצפה המלכדת את מבני השונית ומעניקה לשוניות גוון ורדרד.';

  @override
  String get species_irish_moss_name => 'טחב אירי';

  @override
  String get species_irish_moss_desc =>
      'אצה אדומה בצורת מניפה המצויה בחופי הסלע של אזור הגאות והשפל בצפון האטלנטי.';

  @override
  String get species_dulse_name => 'דולסה';

  @override
  String get species_dulse_desc =>
      'אצה שטוחה בגוון אדמדם-סגול הגדלה על סלעים ועל גבעולי קלפ במים צפוניים קרים.';

  @override
  String get species_halimeda_name => 'הלימדה';

  @override
  String get species_halimeda_desc =>
      'אצה ירוקה מסויידת בעלת פרקים בצורת דיסקה, תורמת מרכזית לחול השונית.';

  @override
  String get species_sea_lettuce_name => 'חסת ים';

  @override
  String get species_sea_lettuce_desc =>
      'אצה ירוקה בוהקת דמוית יריעה, מצויה במים חופיים רדודים בכל העולם.';

  @override
  String get species_caulerpa_name => 'אצת ענבי ים';

  @override
  String get species_caulerpa_desc =>
      'אצה ירוקה זוחלת בעלת גבעולונים דמויי ענבים, מצויה על שברי אלמוגים וחול בשוניות טרופיות.';

  @override
  String get species_mermaid_fan_name => 'מניפת בת הים';

  @override
  String get species_mermaid_fan_desc =>
      'אצה ירוקה מסויידת בצורת מניפה קטנה, נפוצה בקרקעיות החול של הקריביים.';

  @override
  String get species_shaving_brush_algae_name => 'אצת מברשת גילוח';

  @override
  String get species_shaving_brush_algae_desc =>
      'אצה ירוקה מסויידת בעלת ציצית דמוית מברשת על גבעול, מצויה בקרקעיות החול של הקריביים.';

  @override
  String get species_finger_kelp_name => 'אצת משוט';

  @override
  String get species_finger_kelp_desc =>
      'אצה חומה בעלת גבעולונים דמויי אצבעות היוצרת ערוגות קלפ במים החופיים של צפון האטלנטי.';

  @override
  String get species_banded_sea_krait_name => 'נחש ים מפוספס';

  @override
  String get species_banded_sea_krait_desc =>
      'נחש ים ארסי בעל טבעות בכחול-אפור ושחור, נוח אופי ונצפה לרוב בשוניות ההודו-פסיפי.';

  @override
  String get species_olive_sea_snake_name => 'נחש ים זיתי';

  @override
  String get species_olive_sea_snake_desc =>
      'נחש ים סקרן המצוי בשוניות אוסטרליה, ידוע בהתקרבותו לצוללנים.';

  @override
  String get species_yellow_bellied_sea_snake_name => 'נחש ים צהוב-בטן';

  @override
  String get species_yellow_bellied_sea_snake_desc =>
      'נחש ים פלגי בעל בטן צהובה, מין הנחשים הנפוץ ביותר בעולם.';

  @override
  String get species_marine_iguana_name => 'איגואנה ימית';

  @override
  String get species_marine_iguana_desc =>
      'אנדמית לאיי גלפגוס, והלטאה היחידה המלקטת אצות מתחת למים.';

  @override
  String get species_saltwater_crocodile_name => 'תנין ימי';

  @override
  String get species_saltwater_crocodile_desc =>
      'הזוחל הגדול ביותר החי כיום, מצוי במים חופיים ובשפכי נהרות בהודו-פסיפי.';

  @override
  String get common_action_done => 'סיום';

  @override
  String get common_action_more => 'עוד';

  @override
  String get common_label_displayName => 'שם תצוגה';

  @override
  String common_relativeTime_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לפני $count ימים',
      many: 'לפני $count ימים',
      two: 'לפני יומיים',
      one: 'לפני יום',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לפני $count שעות',
      many: 'לפני $count שעות',
      two: 'לפני שעתיים',
      one: 'לפני שעה',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'בעוד $count ימים',
      many: 'בעוד $count ימים',
      two: 'בעוד יומיים',
      one: 'בעוד יום',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'בעוד $count שעות',
      many: 'בעוד $count שעות',
      two: 'בעוד שעתיים',
      one: 'בעוד שעה',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_inLessThanMinute => 'בעוד פחות מדקה';

  @override
  String common_relativeTime_inMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'בעוד $count דקות',
      many: 'בעוד $count דקות',
      two: 'בעוד שתי דקות',
      one: 'בעוד דקה',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_justNow => 'הרגע';

  @override
  String common_relativeTime_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לפני $count דקות',
      many: 'לפני $count דקות',
      two: 'לפני שתי דקות',
      one: 'לפני דקה',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לפני $count חודשים',
      many: 'לפני $count חודשים',
      two: 'לפני חודשיים',
      one: 'לפני חודש',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_overdue => 'באיחור';

  @override
  String get media_cache_calculating => 'מחשב את גודל המטמון…';

  @override
  String get media_cache_cardTitle => 'ניהול מטמון';

  @override
  String get media_cache_clearAction => 'ניקוי מטמון';

  @override
  String get media_cache_clearBody =>
      'מסיר תמונות ממוזערות ותמונות רשת בגודל מלא שהורדו. פריטי המדיה המקושרים נשמרים; התמונות יורדו מחדש בצפייה הבאה.';

  @override
  String get media_cache_clearConfirm => 'ניקוי';

  @override
  String media_cache_clearError(String error) {
    return 'הניקוי נכשל: $error';
  }

  @override
  String get media_cache_clearTitle => 'לנקות את מטמון תמונות הרשת?';

  @override
  String get media_cache_cleared => 'המטמון נוקה';

  @override
  String get media_cache_diskCache => 'מטמון בדיסק';

  @override
  String media_cache_error(String error) {
    return 'שגיאה: $error';
  }

  @override
  String get media_credentials_actionTest => 'בדיקת פרטי התחברות';

  @override
  String media_credentials_authLabel(String authType) {
    return 'אימות: $authType';
  }

  @override
  String get media_credentials_deleteBody =>
      'מסיר את פרטי ההתחברות השמורים. פריטים המקושרים דרך מארח זה יציגו \"נדרשת כניסה\" עד שתוסיף אותם מחדש.';

  @override
  String media_credentials_deleteError(String error) {
    return 'המחיקה נכשלה: $error';
  }

  @override
  String media_credentials_deleteTitle(String host) {
    return 'למחוק את $host?';
  }

  @override
  String media_credentials_deleted(String host) {
    return '$host נמחק';
  }

  @override
  String media_credentials_editTitle(String host) {
    return 'עריכת $host';
  }

  @override
  String get media_credentials_emptySubtitle =>
      'פרטי התחברות לכל מארח שנוספו במהלך ייבוא מכתובת URL או ממניפסט מופיעים כאן.';

  @override
  String get media_credentials_emptyTitle => 'אין פרטי התחברות שמורים';

  @override
  String media_credentials_lastUsed(String when) {
    return 'שימוש אחרון $when';
  }

  @override
  String get media_credentials_loadError => 'לא ניתן לטעון את המארחים השמורים';

  @override
  String get media_credentials_loading => 'טוען מארחים שמורים...';

  @override
  String media_credentials_saveError(String error) {
    return 'השמירה נכשלה: $error';
  }

  @override
  String get media_credentials_savedHostsTitle => 'מארחים שמורים';

  @override
  String media_credentials_testError(String error) {
    return 'הבדיקה נכשלה: $error';
  }

  @override
  String media_credentials_testFailed(String host) {
    return 'פרטי ההתחברות ל-$host נכשלו';
  }

  @override
  String media_credentials_testOk(String host) {
    return 'פרטי ההתחברות ל-$host תקינים';
  }

  @override
  String get media_manifest_actionPollNow => 'תשאול עכשיו';

  @override
  String get media_manifest_cardTitle => 'מנויי מניפסט';

  @override
  String get media_manifest_deleteBody =>
      'מסיר את המנוי. הרשומות שכבר יובאו יישארו (אפשר לנקות אותן דרך תור הפריטים היתומים).';

  @override
  String media_manifest_deleteError(String error) {
    return 'המחיקה נכשלה: $error';
  }

  @override
  String media_manifest_deleteTitle(String name) {
    return 'למחוק את $name?';
  }

  @override
  String get media_manifest_editTitle => 'עריכת מנוי';

  @override
  String get media_manifest_emptySubtitle =>
      'הירשם למניפסט Atom/RSS, JSON או CSV מלשונית ה-URL כדי לשמור על סנכרון הספרייה.';

  @override
  String get media_manifest_emptyTitle => 'אין מנויי מניפסט';

  @override
  String media_manifest_lastError(String error) {
    return 'שגיאה אחרונה: $error';
  }

  @override
  String media_manifest_lastPolled(String when) {
    return 'תשאול אחרון $when';
  }

  @override
  String get media_manifest_loadError => 'לא ניתן לטעון את המנויים';

  @override
  String get media_manifest_loading => 'טוען מנויים...';

  @override
  String get media_manifest_neverPolled => 'מעולם לא תושאל';

  @override
  String media_manifest_nextPoll(String when) {
    return 'הבא $when';
  }

  @override
  String get media_manifest_notFound => 'המנוי לא נמצא';

  @override
  String media_manifest_pollError(String error) {
    return 'התשאול נכשל: $error';
  }

  @override
  String media_manifest_polled(String name) {
    return '$name תושאל';
  }

  @override
  String media_manifest_polling(String name) {
    return 'מתשאל את $name...';
  }

  @override
  String media_manifest_saveError(String error) {
    return 'השמירה נכשלה: $error';
  }

  @override
  String media_manifest_updateError(String error) {
    return 'לא ניתן לעדכן: $error';
  }

  @override
  String get media_manifest_urlLabel => 'כתובת URL של מניפסט';

  @override
  String media_scan_failed(String error) {
    return 'הסריקה נכשלה: $error';
  }

  @override
  String media_scan_progressItems(int done, int total) {
    return '$done / $total פריטים';
  }

  @override
  String media_scan_progressReachability(int available, int unreachable) {
    return '$available נגישים  ·  $unreachable לא נגישים';
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
          'נסרקו $total פריטים ב-$seconds שניות: $available נגישים, $unreachable לא נגישים',
      many:
          'נסרקו $total פריטים ב-$seconds שניות: $available נגישים, $unreachable לא נגישים',
      two:
          'נסרקו שני פריטים ב-$seconds שניות: $available נגישים, $unreachable לא נגישים',
      one:
          'נסרק פריט אחד ב-$seconds שניות: $available נגישים, $unreachable לא נגישים',
    );
    return '$_temp0';
  }

  @override
  String media_scan_summarySkipped(String base, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים דולגו (ללא כתובת URL)',
      many: '$count פריטים דולגו (ללא כתובת URL)',
      two: 'שני פריטים דולגו (ללא כתובת URL)',
      one: 'פריט אחד דולג (ללא כתובת URL)',
    );
    return '$base, $_temp0';
  }

  @override
  String get media_scan_title => 'סריקת כל מדיית הרשת';

  @override
  String get settings_mediaSources_androidUriTitle => 'הרשאות URI ב-Android';

  @override
  String settings_mediaSources_androidUriUsage(int used, int limit) {
    return '$used / $limit כתובות URI קבועות בשימוש';
  }

  @override
  String get settings_mediaSources_counting => 'סופר…';

  @override
  String settings_mediaSources_error(String error) {
    return 'שגיאה: $error';
  }

  @override
  String get settings_mediaSources_loading => 'טוען…';

  @override
  String settings_mediaSources_localFilesCounts(
    int available,
    int unavailable,
  ) {
    return '$available זמינים, $unavailable לא זמינים';
  }

  @override
  String get settings_mediaSources_photoLibrarySubtitle =>
      'Apple Photos / Google Photos / iCloud';

  @override
  String get settings_mediaSources_reverifyAll =>
      'אימות מחדש של כל הקבצים המקומיים';

  @override
  String settings_mediaSources_reverifyFailed(String error) {
    return 'האימות מחדש נכשל: $error';
  }

  @override
  String settings_mediaSources_reverifyResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים עודכנו',
      many: '$count פריטים עודכנו',
      two: 'שני פריטים עודכנו',
      one: 'פריט אחד עודכן',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_checkAll => 'בדיקת כל המדיה';

  @override
  String settings_mediaSources_checkAllResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים עודכנו',
      many: '$count פריטים עודכנו',
      two: '$count פריטים עודכנו',
      one: 'פריט אחד עודכן',
    );
    return '$_temp0';
  }

  @override
  String settings_mediaSources_checkAllBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'לא ניתן היה לבדוק אף אחד מ-$count הפריטים. המקורות שלהם אינם זמינים כרגע.',
      many:
          'לא ניתן היה לבדוק אף אחד מ-$count הפריטים. המקורות שלהם אינם זמינים כרגע.',
      two:
          'לא ניתן היה לבדוק אף אחד מ-$count הפריטים. המקורות שלהם אינם זמינים כרגע.',
      one: 'לא ניתן היה לבדוק את הפריט. המקור שלו אינו זמין כרגע.',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_title => 'מקורות מדיה';

  @override
  String get settings_networkSources_scanDescription =>
      'בודק מחדש כל תמונה שיובאה מכתובת URL או ממניפסט מול המארח שלה. מסמן פריטים לא נגישים כך שיוצגו כ\"חסרים\" בספרייה וניתן יהיה לנקות אותם.';

  @override
  String statistics_conditions_entryMethod_semanticLabel(String description) {
    return 'תרשים עמודות. שיטות כניסה. $description';
  }

  @override
  String statistics_conditions_visibility_semanticLabel(String description) {
    return 'תרשים עוגה. התפלגות ראות. $description';
  }

  @override
  String statistics_conditions_waterType_semanticLabel(String description) {
    return 'תרשים עוגה. התפלגות סוג מים. $description';
  }

  @override
  String statistics_progression_divesBySuitThickness_semanticLabel(
    String description,
  ) {
    return 'תרשים עמודות. צלילות לפי עובי חליפה. $description';
  }

  @override
  String statistics_progression_divesPerYear_countInYear(
    int count,
    String year,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות ב-$year',
      many: '$count צלילות ב-$year',
      two: 'שתי צלילות ב-$year',
      one: 'צלילה אחת ב-$year',
    );
    return '$_temp0';
  }

  @override
  String statistics_progression_divesPerYear_semanticLabel(String description) {
    return 'תרשים עמודות. צלילות לפי שנה. $description';
  }

  @override
  String get statistics_records_unavailable => 'השיאים אינם זמינים';

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
  String get statistics_summary_distributions_title => 'התפלגויות';

  @override
  String get statistics_summary_diveTypes_error =>
      'לא ניתן לטעון נתוני סוגי צלילה';

  @override
  String get statistics_summary_diveTypes_unknown => 'לא ידוע';

  @override
  String get statistics_summary_divesPerMonth => 'צלילות / חודש';

  @override
  String get statistics_summary_divesPerYear => 'צלילות / שנה';

  @override
  String statistics_timePatterns_dayOfWeek_semanticLabel(String description) {
    return 'תרשים עמודות. צלילות לפי יום בשבוע. $description';
  }

  @override
  String statistics_timePatterns_seasonal_semanticLabel(String description) {
    return 'תרשים עמודות. צלילות לפי חודש. $description';
  }

  @override
  String statistics_timePatterns_surfaceInterval_statLabel(
    String label,
    String value,
  ) {
    return 'מרווח פני שטח $label: $value';
  }

  @override
  String get statistics_timePatterns_timeOfDay_afternoon => 'צהריים';

  @override
  String get statistics_timePatterns_timeOfDay_evening => 'ערב';

  @override
  String get statistics_timePatterns_timeOfDay_morning => 'בוקר';

  @override
  String get statistics_timePatterns_timeOfDay_night => 'לילה';

  @override
  String statistics_timePatterns_timeOfDay_semanticLabel(String description) {
    return 'תרשים עוגה. צלילות לפי שעה ביום. $description';
  }

  @override
  String get columnConfig_displayOptions => 'אפשרויות תצוגה';

  @override
  String get columnConfig_noExtraFields =>
      'לא הוגדרו שדות נוספים. הוסיפו שדות למטה.';

  @override
  String get columnConfig_savePresetTitle => 'שמירת הגדרה';

  @override
  String get columnConfig_section => 'מקטע';

  @override
  String get columnConfig_showTags => 'הצגת תגיות';

  @override
  String get columnConfig_showTags_subtitle =>
      'הצגת תגיות על כרטיסי צלילה מפורטים';

  @override
  String get columnConfig_slot_date => 'תאריך / כותרת משנה';

  @override
  String get columnConfig_slot_slot1 => 'משבצת 1';

  @override
  String get columnConfig_slot_slot2 => 'משבצת 2';

  @override
  String get columnConfig_slot_slot3 => 'משבצת 3';

  @override
  String get columnConfig_slot_slot4 => 'משבצת 4';

  @override
  String get columnConfig_slot_stat1 => 'נתון 1';

  @override
  String get columnConfig_slot_stat2 => 'נתון 2';

  @override
  String get columnConfig_slot_subtitle => 'כותרת משנה';

  @override
  String get columnConfig_slot_title => 'כותרת';

  @override
  String get columnConfig_tooltip_columnSettings => 'הגדרות עמודות';

  @override
  String get common_action_add => 'הוסף';

  @override
  String get common_action_pin => 'הצמד';

  @override
  String get common_action_remove => 'הסר';

  @override
  String get common_action_unpin => 'בטל הצמדה';

  @override
  String diveLog_filterChip_dateRange(String end, String start) {
    return '$start עד $end';
  }

  @override
  String diveLog_filterChip_equipmentCount(int count) {
    return '$count פריטי ציוד';
  }

  @override
  String get diveLog_filter_allComputers => 'כל מחשבי הצלילה';

  @override
  String get diveLog_filter_noComputersRegistered => 'לא רשומים מחשבי צלילה';

  @override
  String diveLog_filter_sectionDepthRangeUnit(String unit) {
    return 'טווח עומק ($unit)';
  }

  @override
  String get diveLog_filter_sectionDiveComputer => 'מחשב צלילה';

  @override
  String diveLog_listPage_semanticsDiveAtSite(int diveNumber, String siteName) {
    return 'צלילה $diveNumber באתר $siteName';
  }

  @override
  String get enum_listViewMode_compact => 'קומפקטי';

  @override
  String get enum_listViewMode_dense => 'צפוף';

  @override
  String get enum_listViewMode_detailed => 'מפורט';

  @override
  String get enum_listViewMode_table => 'טבלה';

  @override
  String get enum_profileMetric_ascentRate => 'קצב עלייה';

  @override
  String get enum_profileMetric_cns => 'CNS%';

  @override
  String get enum_profileMetric_otu => 'OTU';

  @override
  String get enum_sortField_bottomTime => 'זמן תחתית';

  @override
  String get enum_sortField_serviceDue => 'טיפול נדרש';

  @override
  String get listViewMode_tooltip => 'מצב תצוגה';

  @override
  String marineLife_speciesManage_errorLoading(Object error) {
    return 'שגיאה בטעינת המינים: $error';
  }

  @override
  String get settings_appearance_header_cards => 'כרטיסים';

  @override
  String get settings_appearance_header_listView => 'תצוגת רשימה';

  @override
  String get settings_appearance_header_tableMode => 'מצב טבלה';

  @override
  String get settings_appearance_listFields_buddies =>
      'שדות רשימת חברי הצוללים';

  @override
  String get settings_appearance_listFields_certifications =>
      'שדות רשימת ההסמכות';

  @override
  String get settings_appearance_listFields_courses => 'שדות רשימת הקורסים';

  @override
  String get settings_appearance_listFields_diveCenters =>
      'שדות רשימת מרכזי הצלילה';

  @override
  String get settings_appearance_listFields_dives => 'שדות רשימת הצלילות';

  @override
  String get settings_appearance_listFields_equipment => 'שדות רשימת הציוד';

  @override
  String get settings_appearance_listFields_sites => 'שדות רשימת האתרים';

  @override
  String get settings_appearance_listFields_subtitle =>
      'התאמת השדות המוצגים בתצוגות הרשימה';

  @override
  String get settings_appearance_listFields_trips => 'שדות רשימת הטיולים';

  @override
  String get settings_appearance_listView_buddies => 'תצוגת רשימת חברי הצוללים';

  @override
  String get settings_appearance_listView_buddies_subtitle =>
      'פריסת ברירת המחדל לרשימת חברי הצוללים';

  @override
  String get settings_appearance_listView_certifications =>
      'תצוגת רשימת ההסמכות';

  @override
  String get settings_appearance_listView_certifications_subtitle =>
      'פריסת ברירת המחדל לרשימת ההסמכות';

  @override
  String get settings_appearance_listView_courses => 'תצוגת רשימת הקורסים';

  @override
  String get settings_appearance_listView_courses_subtitle =>
      'פריסת ברירת המחדל לרשימת הקורסים';

  @override
  String get settings_appearance_listView_diveCenters =>
      'תצוגת רשימת מרכזי הצלילה';

  @override
  String get settings_appearance_listView_diveCenters_subtitle =>
      'פריסת ברירת המחדל לרשימת מרכזי הצלילה';

  @override
  String get settings_appearance_listView_dives => 'תצוגת רשימת הצלילות';

  @override
  String get settings_appearance_listView_dives_subtitle =>
      'פריסת ברירת המחדל לרשימת הצלילות';

  @override
  String get settings_appearance_listView_equipment => 'תצוגת רשימת הציוד';

  @override
  String get settings_appearance_listView_equipment_subtitle =>
      'פריסת ברירת המחדל לרשימת הציוד';

  @override
  String get settings_appearance_listView_sites => 'תצוגת רשימת האתרים';

  @override
  String get settings_appearance_listView_sites_subtitle =>
      'פריסת ברירת המחדל לרשימת האתרים';

  @override
  String get settings_appearance_listView_trips => 'תצוגת רשימת הטיולים';

  @override
  String get settings_appearance_listView_trips_subtitle =>
      'פריסת ברירת המחדל לרשימת הטיולים';

  @override
  String get settings_appearance_showDataSourceBadges =>
      'הצגת תגי מקור הנתונים';

  @override
  String get settings_appearance_showDataSourceBadges_subtitle =>
      'הצגת ייחוס המקור על מדדי הצלילה';

  @override
  String get settings_appearance_title_buddies => 'מראה חברי הצוללים';

  @override
  String get settings_appearance_title_certifications => 'מראה ההסמכות';

  @override
  String get settings_appearance_title_courses => 'מראה הקורסים';

  @override
  String get settings_appearance_title_diveCenters => 'מראה מרכזי הצלילה';

  @override
  String get settings_appearance_title_dives => 'מראה הצלילות';

  @override
  String get settings_appearance_title_equipment => 'מראה הציוד';

  @override
  String get settings_appearance_title_sites => 'מראה האתרים';

  @override
  String get settings_appearance_title_trips => 'מראה הטיולים';

  @override
  String get settings_cloudSync_troubleshoot_tileSubtitle =>
      'תיקון סנכרון תקוע או פינוי שטח בענן';

  @override
  String get settings_data_header_dataTools => 'כלי נתונים';

  @override
  String get settings_decompression_ascentGasLabel => 'תכנון העלייה עם';

  @override
  String get settings_decompression_ascentGas_allCarried =>
      'כל הבלונים הנישאים';

  @override
  String get settings_decompression_ascentGas_decoStage =>
      'בלוני דקו/סטייג + גז גב';

  @override
  String get settings_decompression_cnsSource => 'מקור CNS';

  @override
  String get settings_decompression_decoStopSource => 'מקור עצירות הדקו';

  @override
  String get settings_decompression_header_ascent => 'תכנון העלייה';

  @override
  String get settings_decompression_header_ascent_subtitle =>
      'לאילו בלונים נישאים העלייה המדומה (TTS, תקרה ועצירות) יכולה לעבור בכל עומק. נלקחים בחשבון רק גזים שנרשמו בצלילה.';

  @override
  String get settings_decompression_header_dataSources => 'העדפות מקור נתונים';

  @override
  String get settings_decompression_header_dataSources_subtitle =>
      'כאשר ההגדרה היא מחשב צלילה, האפליקציה משתמשת בנתונים שמדווח מחשב הצלילה כשהם זמינים. בהיעדר נתוני מחשב, היא חוזרת לערכים המחושבים.';

  @override
  String get settings_decompression_ndlSource => 'מקור NDL';

  @override
  String get settings_decompression_sourceCalculated => 'מחושב';

  @override
  String get settings_decompression_sourceComputer => 'מחשב צלילה';

  @override
  String get settings_decompression_ttsSource => 'מקור TTS';

  @override
  String settings_fixDiveTimes_applied(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות עודכנו',
      many: '$count צלילות עודכנו',
      two: 'שתי צלילות עודכנו',
      one: 'צלילה אחת עודכנה',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'שעות',
      many: 'שעות',
      two: 'שעות',
      one: 'שעה',
    );
    return '$_temp0 ב-$hours $_temp1.';
  }

  @override
  String settings_fixDiveTimes_apply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'החל על $count צלילות',
      many: 'החל על $count צלילות',
      two: 'החל על שתי צלילות',
      one: 'החל על צלילה אחת',
    );
    return '$_temp0';
  }

  @override
  String get settings_fixDiveTimes_clearRange => 'ניקוי טווח התאריכים';

  @override
  String get settings_fixDiveTimes_confirmApply => 'החל';

  @override
  String settings_fixDiveTimes_confirmBody(
    int count,
    String hours,
    int hoursAbs,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות',
      many: '$count צלילות',
      two: 'שתי צלילות',
      one: 'צלילה אחת',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'שעות',
      many: 'שעות',
      two: 'שעות',
      one: 'שעה',
    );
    return 'פעולה זו תזיז $_temp0 ב-$hours $_temp1. לא ניתן לבטל זאת אוטומטית.';
  }

  @override
  String get settings_fixDiveTimes_confirmTitle => 'החלת היסט זמן';

  @override
  String get settings_fixDiveTimes_dateRangeFilter => 'מסנן טווח תאריכים';

  @override
  String get settings_fixDiveTimes_deselectAll => 'בטל בחירת הכל';

  @override
  String get settings_fixDiveTimes_diveFallback => 'צלילה';

  @override
  String settings_fixDiveTimes_diveNumber(int number) {
    return 'צלילה מספר $number';
  }

  @override
  String get settings_fixDiveTimes_empty => 'לא נמצאו צלילות.';

  @override
  String get settings_fixDiveTimes_emptyFiltered =>
      'לא נמצאו צלילות בטווח תאריכים זה.';

  @override
  String get settings_fixDiveTimes_enterOffsetHint => 'הזינו היסט בשעות';

  @override
  String get settings_fixDiveTimes_from => 'מתאריך';

  @override
  String get settings_fixDiveTimes_hourOffset => 'היסט שעות';

  @override
  String get settings_fixDiveTimes_hoursField => 'שעות (לדוגמה: +7, -5)';

  @override
  String settings_fixDiveTimes_loadError(String error) {
    return 'טעינת הצלילות נכשלה: $error';
  }

  @override
  String get settings_fixDiveTimes_noSelection => 'לא נבחרו צלילות.';

  @override
  String get settings_fixDiveTimes_offsetHint =>
      'הזינו מספר שלם חיובי או שלילי כדי להזיז את זמני הצלילות.';

  @override
  String settings_fixDiveTimes_preview(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count צלילות יוזזו',
      many: '$count צלילות יוזזו',
      two: 'שתי צלילות יוזזו',
      one: 'צלילה אחת תוזז',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'שעות',
      many: 'שעות',
      two: 'שעות',
      one: 'שעה',
    );
    return 'תצוגה מקדימה: $_temp0 ב-$hours $_temp1.';
  }

  @override
  String get settings_fixDiveTimes_selectAll => 'בחר הכל';

  @override
  String get settings_fixDiveTimes_selectDivesHint => 'בחרו את הצלילות להחלה';

  @override
  String get settings_fixDiveTimes_subtitle => 'התאמת הזמנים של צלילות מיובאות';

  @override
  String get settings_fixDiveTimes_title => 'תיקון זמני צלילה';

  @override
  String get settings_fixDiveTimes_to => 'עד תאריך';

  @override
  String get settings_fixDiveTimes_zeroOffset =>
      'היסט השעות הוא 0, אין מה לשנות.';

  @override
  String get settings_syncDevices_appBar_refreshTooltip => 'רענון';

  @override
  String get settings_syncDevices_appBar_title => 'מכשירים בשירות זה';

  @override
  String get settings_syncDevices_empty => 'אין קובצי סנכרון בשירות זה.';

  @override
  String settings_syncDevices_readError(String error) {
    return 'לא ניתן היה לקרוא את השירות.\n$error';
  }

  @override
  String get settings_syncDevices_removal_noBackend => 'לא הוגדר שירות ענן';

  @override
  String get settings_syncDevices_removal_unreachable =>
      'לא ניתן היה להגיע לשירות. דבר לא הוסר.';

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
          'פעולה זו תמחק $count קבצים ($size) השייכים ל-$name.\n\nהמכשיר הזה עדיין חלק מהסנכרון הזה. אם הוא יחזור לחיבור, הוא ייבנה מחדש מהשירות במקום להחיות נתונים ישנים, אך כל שינוי שטרם פרסם יאבד. נתוני הצלילה שלך במכשיר הזה אינם מושפעים.',
      many:
          'פעולה זו תמחק $count קבצים ($size) השייכים ל-$name.\n\nהמכשיר הזה עדיין חלק מהסנכרון הזה. אם הוא יחזור לחיבור, הוא ייבנה מחדש מהשירות במקום להחיות נתונים ישנים, אך כל שינוי שטרם פרסם יאבד. נתוני הצלילה שלך במכשיר הזה אינם מושפעים.',
      two:
          'פעולה זו תמחק שני קבצים ($size) השייכים ל-$name.\n\nהמכשיר הזה עדיין חלק מהסנכרון הזה. אם הוא יחזור לחיבור, הוא ייבנה מחדש מהשירות במקום להחיות נתונים ישנים, אך כל שינוי שטרם פרסם יאבד. נתוני הצלילה שלך במכשיר הזה אינם מושפעים.',
      one:
          'פעולה זו תמחק קובץ אחד ($size) השייכים ל-$name.\n\nהמכשיר הזה עדיין חלק מהסנכרון הזה. אם הוא יחזור לחיבור, הוא ייבנה מחדש מהשירות במקום להחיות נתונים ישנים, אך כל שינוי שטרם פרסם יאבד. נתוני הצלילה שלך במכשיר הזה אינם מושפעים.',
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
          'פעולה זו תמחק $count קבצים ($size) השייכים ל-$name. הם שרידים מספרייה שאף מכשיר כבר אינו מסנכרן ממנה. נתוני הצלילה שלך אינם מושפעים.',
      many:
          'פעולה זו תמחק $count קבצים ($size) השייכים ל-$name. הם שרידים מספרייה שאף מכשיר כבר אינו מסנכרן ממנה. נתוני הצלילה שלך אינם מושפעים.',
      two:
          'פעולה זו תמחק שני קבצים ($size) השייכים ל-$name. הם שרידים מספרייה שאף מכשיר כבר אינו מסנכרן ממנה. נתוני הצלילה שלך אינם מושפעים.',
      one:
          'פעולה זו תמחק קובץ אחד ($size) השייכים ל-$name. הם שרידים מספרייה שאף מכשיר כבר אינו מסנכרן ממנה. נתוני הצלילה שלך אינם מושפעים.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_removeDialog_title(String name) {
    return 'להסיר את הקבצים של $name?';
  }

  @override
  String settings_syncDevices_removeProgressTitle(String name) {
    return 'מסיר את הקבצים של $name';
  }

  @override
  String get settings_syncDevices_removeTooltip => 'הסרת הקבצים של מכשיר זה';

  @override
  String get settings_syncDevices_state_active => 'מסתנכרן כרגיל';

  @override
  String get settings_syncDevices_state_retired => 'הוצא משימוש';

  @override
  String get settings_syncDevices_state_staleEpoch =>
      'שריד מספרייה קודמת; אף מכשיר אינו קורא אותו';

  @override
  String get settings_syncDevices_state_thisDevice => 'המכשיר הזה';

  @override
  String get settings_syncDevices_state_unreadable =>
      'אין מניפסט קריא; העלאה שלא הושלמה או מוצפנת';

  @override
  String settings_syncDevices_summary(
    int deviceCount,
    int fileCount,
    String size,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      deviceCount,
      locale: localeName,
      other: '$deviceCount מכשירים',
      many: '$deviceCount מכשירים',
      two: 'שני מכשירים',
      one: 'מכשיר אחד',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: '$fileCount קבצים',
      many: '$fileCount קבצים',
      two: 'שני קבצים',
      one: 'קובץ אחד',
    );
    return '$_temp0, $_temp1, $size';
  }

  @override
  String settings_syncDevices_summary_removable(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count נותרו מספרייה שהוחלפה או הוצאה משימוש, ותופסים $size.',
      many: '$count נותרו מספרייה שהוחלפה או הוצאה משימוש, ותופסים $size.',
      two: 'שניים נותרו מספרייה שהוחלפה או הוצאה משימוש, ותופסים $size.',
      one: 'אחד נותר מספרייה שהוחלפה או הוצאה משימוש, ותופסים $size.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_tile_filesSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count קבצים',
      many: '$count קבצים',
      two: 'שני קבצים',
      one: 'קובץ אחד',
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
      other: '$count קבצים',
      many: '$count קבצים',
      two: 'שני קבצים',
      one: 'קובץ אחד',
    );
    return '$_temp0, $size · $when';
  }

  @override
  String settings_syncDevices_unnamedDevice(String shortId) {
    return 'מכשיר $shortId';
  }

  @override
  String get settings_syncMaintenance_keepAppOpen =>
      'השאירו את האפליקציה פתוחה עד לסיום. סגירה עכשיו תשאיר את השירות מנוקה חלקית, והסנכרון הבא ייאלץ להתחיל מחדש.';

  @override
  String get settings_syncMaintenance_phase_clearingOldFiles =>
      'מנקה קבצים ישנים';

  @override
  String get settings_syncMaintenance_phase_deleting => 'מוחק';

  @override
  String get settings_syncMaintenance_phase_publishingLibrary =>
      'מפרסם את הספרייה';

  @override
  String get settings_cloudSync_adopt_progressTitle =>
      'מאמץ את הספרייה ששוחזרה';

  @override
  String get settings_cloudSync_replaceLibrary_progressTitle =>
      'מחליף את ספריית הענן';

  @override
  String settings_syncDevices_nameWithId(String name, String shortId) {
    return '$name ($shortId)';
  }

  @override
  String get settings_syncMaintenance_phase_applyingLibrary =>
      'מחיל את הספרייה';

  @override
  String get settings_syncMaintenance_phase_backingUp => 'מגבה את המכשיר הזה';

  @override
  String get settings_syncMaintenance_phase_repairing =>
      'מנקה את מצב הסנכרון המקומי';

  @override
  String get settings_troubleshootSync_repair_progressTitle =>
      'מתקן את הסנכרון';

  @override
  String get settings_syncMaintenance_phase_working => 'מעבד...';

  @override
  String settings_syncMaintenance_progress_filesOfTotal(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done מתוך $total קבצים',
      many: '$done מתוך $total קבצים',
      two: '$done מתוך שני קבצים',
      one: '$done מתוך קובץ אחד',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_removedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הוסרו $count קבצים',
      many: 'הוסרו $count קבצים',
      two: 'הוסרו שני קבצים',
      one: 'הוסר קובץ אחד',
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
      other: 'הוסרו $count קבצים, אך $trouble. נסו שוב כשיש חיבור לאינטרנט.',
      many: 'הוסרו $count קבצים, אך $trouble. נסו שוב כשיש חיבור לאינטרנט.',
      two: 'הוסרו שני קבצים, אך $trouble. נסו שוב כשיש חיבור לאינטרנט.',
      one: 'הוסר קובץ אחד, אך $trouble. נסו שוב כשיש חיבור לאינטרנט.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_trouble_failed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count לא ניתנו למחיקה',
      many: '$count לא ניתנו למחיקה',
      two: 'שניים לא ניתנו למחיקה',
      one: 'אחד לא ניתן היה למחיקה',
    );
    return '$_temp0';
  }

  @override
  String get settings_syncMaintenance_trouble_listIncomplete =>
      'לא ניתן היה להציג חלק מהקבצים';

  @override
  String settings_syncMaintenance_wipedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נמחקו $count קבצים',
      many: 'נמחקו $count קבצים',
      two: 'נמחקו שני קבצים',
      one: 'נמחק קובץ אחד',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_wipedFilesPartial(int count, String trouble) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נמחקו $count קבצים, אך $trouble. נסו שוב כשיש חיבור לאינטרנט.',
      many: 'נמחקו $count קבצים, אך $trouble. נסו שוב כשיש חיבור לאינטרנט.',
      two: 'נמחקו שני קבצים, אך $trouble. נסו שוב כשיש חיבור לאינטרנט.',
      one: 'נמחק קובץ אחד, אך $trouble. נסו שוב כשיש חיבור לאינטרנט.',
    );
    return '$_temp0';
  }

  @override
  String get settings_troubleshootSync_appBar_title => 'פתרון תקלות סנכרון';

  @override
  String get settings_troubleshootSync_devices_subtitle =>
      'צפו בכל מכשיר שמחזיק כאן קבצים, בכמות השטח שכל אחד תופס, והסירו שרידים מספריות שאף מכשיר כבר אינו מסנכרן מהן. נתוני הצלילה שלכם אינם מושפעים.';

  @override
  String get settings_troubleshootSync_rebuild_confirm => 'בנייה מחדש';

  @override
  String get settings_troubleshootSync_rebuild_confirmBody =>
      'פעולה זו הופכת את הספרייה של מכשיר זה לספרייה הנוכחית בשירות ומפרסמת אותה מחדש, כך שמכשירים אחרים יסתנכרנו ממך. השתמשו בה כאשר החלפה ממכשיר אחר תקועה. נתוני הצלילה שלכם אינם מושפעים.';

  @override
  String get settings_troubleshootSync_rebuild_confirmTitle =>
      'לבנות מחדש את השירות ממכשיר זה?';

  @override
  String get settings_troubleshootSync_rebuild_doneSnack =>
      'השירות נבנה מחדש ממכשיר זה';

  @override
  String get settings_troubleshootSync_rebuild_failedSnack =>
      'הבנייה מחדש נכשלה';

  @override
  String get settings_troubleshootSync_rebuild_progressTitle =>
      'בונה מחדש את השירות';

  @override
  String get settings_troubleshootSync_rebuild_subtitle =>
      'השתמשו בכך אם הסנכרון תקוע בהמתנה לספרייה שמכשיר אחר החליף אך מעולם לא סיים להעלות (ייתכן שאותו מכשיר מנותק). פעולה זו מפרסמת את הספרייה של מכשיר זה כספרייה הנוכחית.';

  @override
  String get settings_troubleshootSync_rebuild_title =>
      'בנייה מחדש של השירות ממכשיר זה';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmBody =>
      'פעולה זו מוחקת מהשירות רק את קובצי הסנכרון של מכשיר זה. מכשירים אחרים ימשיכו להסתנכרן, ונתוני הצלילה שלכם אינם מושפעים.';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmTitle =>
      'להסיר את קובצי הענן של מכשיר זה?';

  @override
  String get settings_troubleshootSync_removeThisDevice_progressTitle =>
      'מסיר את קובצי הענן של מכשיר זה';

  @override
  String get settings_troubleshootSync_removeThisDevice_subtitle =>
      'פינוי השטח של מכשיר זה בשירות. מכשירים אחרים ימשיכו להסתנכרן. נתוני הצלילה שלכם אינם מושפעים.';

  @override
  String get settings_troubleshootSync_removeThisDevice_title =>
      'הסרת קובצי הענן של מכשיר זה';

  @override
  String get settings_troubleshootSync_repair_confirm => 'תיקון';

  @override
  String get settings_troubleshootSync_repair_confirmBody =>
      'פעולה זו מנקה את כל מצב הסנכרון המקומי ומעניקה למכשיר זה זהות סנכרון חדשה, ואז מתחברת מחדש מאפס בסנכרון הבא. נתוני הצלילה שלכם בטוחים ואינם נמחקים.';

  @override
  String get settings_troubleshootSync_repair_confirmTitle =>
      'לתקן את הסנכרון?';

  @override
  String get settings_troubleshootSync_repair_doneSnack => 'הסנכרון תוקן';

  @override
  String get settings_troubleshootSync_repair_subtitle =>
      'תיקון סנכרון תקוע. מנקה את מצב הסנכרון של מכשיר זה ומעניק לו זהות סנכרון חדשה, ואז מתחבר מחדש בסנכרון הבא. נתוני הצלילה שלכם אינם מושפעים.';

  @override
  String get settings_troubleshootSync_repair_title => 'תיקון הסנכרון';

  @override
  String get settings_troubleshootSync_wipeAll_confirm => 'מחיקת הכול';

  @override
  String settings_troubleshootSync_wipeAll_confirmBody(String word) {
    return 'פעולה זו מוחקת את נתוני הסנכרון של כל מכשיר מהשירות הזה, כולל סמני הספרייה. כל מכשיר יצטרך להקים את הסנכרון מחדש מאפס. נתוני הצלילה שלכם אינם מושפעים.\n\nהקלידו בדיוק $word כדי לאשר.';
  }

  @override
  String get settings_troubleshootSync_wipeAll_confirmTitle =>
      'למחוק את כל נתוני הסנכרון?';

  @override
  String get settings_troubleshootSync_wipeAll_progressTitle =>
      'מוחק את נתוני הסנכרון';

  @override
  String get settings_troubleshootSync_wipeAll_subtitle =>
      'מחיקת נתוני הסנכרון של כל מכשיר מהשירות הזה, כולל סמני הספרייה. כל מכשיר יקים את הסנכרון מחדש מאפס. נתוני הצלילה שלכם אינם מושפעים.';

  @override
  String get settings_troubleshootSync_wipeAll_title =>
      'מחיקת כל נתוני הסנכרון בשירות זה';

  @override
  String get tableMode_tooltip_toggleDetailPane => 'הצגת חלונית הפרטים';

  @override
  String get tableMode_tooltip_toggleProfilePanel => 'הצגת חלונית הפרופיל';

  @override
  String get maps_regionDownload_title => 'הורדת אזור';

  @override
  String get maps_regionDownload_nameRequired => 'יש להזין שם לאזור זה';

  @override
  String get maps_regionDownload_nameLabel => 'שם האזור';

  @override
  String get maps_regionDownload_nameHint => 'לדוגמה, קוזומל, מקסיקו';

  @override
  String get maps_regionDownload_zoomLevels => 'רמות זום';

  @override
  String get maps_regionDownload_zoomHint =>
      'זום גבוה יותר = יותר פרטים, הורדה גדולה יותר';

  @override
  String maps_regionDownload_minZoom(int zoom) {
    return 'מינימום: $zoom';
  }

  @override
  String maps_regionDownload_minZoomSemantics(int zoom) {
    return 'זום מינימלי: $zoom';
  }

  @override
  String maps_regionDownload_maxZoom(int zoom) {
    return 'מקסימום: $zoom';
  }

  @override
  String maps_regionDownload_maxZoomSemantics(int zoom) {
    return 'זום מקסימלי: $zoom';
  }

  @override
  String get maps_regionDownload_estimatingSemantics => 'מעריך את גודל ההורדה';

  @override
  String maps_regionDownload_estimateSemantics(int count, Object size) {
    return 'הורדה משוערת: $count אריחים, $size';
  }

  @override
  String get maps_regionDownload_estimateUnavailableSemantics =>
      'לא ניתן להעריך את גודל ההורדה';

  @override
  String get maps_regionDownload_estimating => 'מעריך...';

  @override
  String maps_regionDownload_tileCount(int count) {
    return '~$count אריחים';
  }

  @override
  String get maps_regionDownload_estimateUnavailable => 'לא ניתן להעריך';

  @override
  String get maps_regionDownload_largeWarningSemantics =>
      'אזהרה: הורדה גדולה. כדאי להקטין את רמות הזום או לבחור אזור קטן יותר.';

  @override
  String get maps_regionDownload_largeWarning =>
      'הורדה גדולה. כדאי להקטין את רמות הזום או לבחור אזור קטן יותר.';

  @override
  String get maps_regionDownload_downloadButton => 'הורדה';

  @override
  String get diveLog_map_title => 'פעילות צלילה';

  @override
  String diveLog_map_infoCard_minutes(int minutes) {
    return '$minutes דקות';
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
      'תמונה ממוזערת של תמונה. הקש לצפייה במסך מלא';

  @override
  String get trips_gallery_thumbnail_video =>
      'תמונה ממוזערת של סרטון. הקש לצפייה במסך מלא';

  @override
  String get trips_gallery_thumbnail_photoMissing =>
      'תמונה ממוזערת של תמונה, חסרה במכשיר. הקש לצפייה במסך מלא';

  @override
  String get trips_gallery_thumbnail_videoMissing =>
      'תמונה ממוזערת של סרטון, חסר במכשיר. הקש לצפייה במסך מלא';

  @override
  String get trips_photos_thumbnail_photo =>
      'תמונה ממוזערת של תמונה. הקש לפתיחת הגלריה';

  @override
  String get trips_photos_thumbnail_video =>
      'תמונה ממוזערת של סרטון. הקש לפתיחת הגלריה';

  @override
  String trips_picker_suggestedSemantics(Object name) {
    return 'טיול מוצע: $name. הקש לשימוש';
  }

  @override
  String trips_picker_tileSemantics(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, מ-$startDate עד $endDate';
  }

  @override
  String trips_picker_tileSemanticsSelected(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, מ-$startDate עד $endDate, נבחר';
  }

  @override
  String get divePlanner_quickPlan_subtitle => 'יצירת פרופיל צלילה מלבני פשוט';

  @override
  String get divePlanner_quickPlan_depthLabel => 'עומק:';

  @override
  String divePlanner_quickPlan_depthSemantics(Object depth) {
    return 'עומק: $depth';
  }

  @override
  String get divePlanner_quickPlan_timeLabel => 'זמן:';

  @override
  String divePlanner_quickPlan_bottomTimeSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'זמן תחתית: $minutes דקות',
      many: 'זמן תחתית: $minutes דקות',
      two: 'זמן תחתית: שתי דקות',
      one: 'זמן תחתית: דקה אחת',
    );
    return '$_temp0';
  }

  @override
  String divePlanner_quickPlan_minutes(int minutes) {
    return '$minutes דקות';
  }

  @override
  String divePlanner_quickPlan_previewSemantics(Object depth, int minutes) {
    return 'תצוגה מקדימה של התכנית: ירידה ל-$depth, זמן תחתית $minutes דקות, עלייה עם עצירת בטיחות';
  }

  @override
  String get divePlanner_quickPlan_previewTitle => 'תצוגה מקדימה של התכנית:';

  @override
  String divePlanner_quickPlan_previewDescent(Object depth) {
    return 'ירידה ל-$depth';
  }

  @override
  String divePlanner_quickPlan_previewBottomTime(int minutes) {
    return 'זמן תחתית: $minutes דקות';
  }

  @override
  String get divePlanner_quickPlan_previewAscent => 'עלייה עם עצירת בטיחות';

  @override
  String get divePlanner_quickPlan_create => 'יצירה';

  @override
  String divePlanner_semantics_sacRate(Object value, Object volumeSymbol) {
    return 'RMV: $value $volumeSymbol לדקה';
  }

  @override
  String divePlanner_semantics_reservePressure(Object pressureSymbol) {
    return 'לחץ רזרבה ביחידות $pressureSymbol';
  }

  @override
  String divePlanner_semantics_altitudeGroup(Object group) {
    return 'קבוצת גובה: $group';
  }

  @override
  String diveSites_import_detail_maxDepth(Object depth) {
    return 'מקסימום $depth';
  }

  @override
  String get autoUpdate_banner_download => 'הורדה';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'סנכרון באמצעות Apple iCloud';

  @override
  String get settings_debugLog_search_hint => 'חיפוש ביומנים...';

  @override
  String get settings_debugLog_appBar_title => 'יומני ניפוי באגים';

  @override
  String get settings_debugLog_disableDebugMode => 'כיבוי מצב ניפוי באגים';

  @override
  String get settings_debugLog_clearLogs => 'ניקוי יומנים';

  @override
  String get settings_debugLog_empty =>
      'אין רשומות יומן התואמות למסננים הנוכחיים';

  @override
  String settings_debugLog_loadError(Object error) {
    return 'שגיאה בטעינת היומנים: $error';
  }

  @override
  String get settings_debugLog_copiedSnack => 'היומנים המסוננים הועתקו ללוח';

  @override
  String settings_debugLog_savedSnack(String path) {
    return 'היומנים נשמרו אל $path';
  }

  @override
  String get common_action_copy => 'העתקה';

  @override
  String get settings_appearance_customGradient_title =>
      'מעבר צבעים מותאם אישית';

  @override
  String get settings_appearance_customGradient_start => 'התחלה';

  @override
  String get settings_appearance_customGradient_end => 'סיום';

  @override
  String get settings_appearance_customGradient_hue => 'גוון';

  @override
  String get settings_appearance_customGradient_saturation => 'רוויה';

  @override
  String get settings_appearance_customGradient_brightness => 'בהירות';

  @override
  String get settings_appearance_customGradient_preview => 'תצוגה מקדימה';

  @override
  String get common_action_apply => 'החל';

  @override
  String settings_cloudSync_message_loadStateFailed(Object error) {
    return 'טעינת מצב הסנכרון נכשלה: $error';
  }

  @override
  String get settings_cloudSync_message_noProviderConfigured =>
      'לא הוגדר ספק ענן';

  @override
  String get settings_cloudSync_message_adopting =>
      'מאמץ את הספרייה ששוחזרה...';

  @override
  String get settings_cloudSync_message_adoptFailed =>
      'אימוץ הספרייה ששוחזרה נכשל';

  @override
  String get settings_cloudSync_message_firstSyncNeedsConfirm =>
      'הסנכרון הראשון דורש אישור. הקש על סנכרן עכשיו לבדיקה.';

  @override
  String get settings_cloudSync_message_startingSync => 'מתחיל סנכרון...';

  @override
  String get settings_cloudSync_message_replacePaused =>
      'הסנכרון מושהה: הספרייה הוחלפה מגיבוי. הקש על סנכרן עכשיו לבדיקה.';

  @override
  String get settings_cloudSync_message_encryptedPaused =>
      'הסנכרון מושהה: ספרייה זו מוצפנת. הזן את משפט הסיסמה כדי להמשיך.';

  @override
  String get settings_cloudSync_message_completedWithConflicts =>
      'הסנכרון הושלם עם התנגשויות';

  @override
  String get settings_cloudSync_message_completedSuccessfully =>
      'הסנכרון הושלם בהצלחה';

  @override
  String get settings_cloudSync_message_syncFailed => 'הסנכרון נכשל';

  @override
  String get settings_cloudSync_message_phaseDefault => 'סנכרון';

  @override
  String settings_cloudSync_message_syncErrorDuring(
    String phase,
    Object error,
  ) {
    return 'שגיאת סנכרון במהלך $phase: $error';
  }

  @override
  String get settings_section_debug_title => 'ניפוי באגים';

  @override
  String get settings_section_debug_subtitle => 'יומנים ואבחון';

  @override
  String get settings_debugLog_minSeverityLabel => 'חומרה מינימלית:';

  @override
  String get settings_debugLog_shareSubject =>
      'יומני ניפוי באגים של Submersion';

  @override
  String get settings_debugLog_saveDialogTitle => 'שמירת יומני ניפוי באגים';

  @override
  String get universalImport_preset_saveTitle => 'שמירה כתבנית';

  @override
  String get universalImport_preset_nameLabel => 'שם התבנית';

  @override
  String get universalImport_preset_nameHint =>
      'לדוגמה, CSV של יומן הצלילה שלי';

  @override
  String get universalImport_preset_nameRequired => 'שם הוא שדה חובה';

  @override
  String get universalImport_preset_sourceAppLabel => 'אפליקציית מקור';

  @override
  String get universalImport_preset_sourceAppNone => 'ללא';

  @override
  String get universalImport_preset_entityTypesLabel => 'סוגי ישויות';

  @override
  String get universalImport_preset_matchThresholdLabel => 'סף התאמה';

  @override
  String get universalImport_preset_matchThresholdHelp =>
      'עד כמה כותרות ה-CSV חייבות להתאים לזיהוי אוטומטי';

  @override
  String universalImport_preset_signatureHeaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count כותרות חתימה מהקובץ הנוכחי',
      many: '$count כותרות חתימה מהקובץ הנוכחי',
      two: 'שתי כותרות חתימה מהקובץ הנוכחי',
      one: 'כותרת חתימה אחת מהקובץ הנוכחי',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_preset_selectTitle => 'בחירת תבנית';

  @override
  String universalImport_preset_loadFailed(String error) {
    return 'טעינת התבניות נכשלה: $error';
  }

  @override
  String get universalImport_preset_sectionSaved => 'תבניות שמורות';

  @override
  String get universalImport_preset_sectionBuiltIn => 'תבניות מובנות';

  @override
  String get universalImport_preset_deleteTitle => 'מחיקת תבנית';

  @override
  String universalImport_preset_deleteConfirm(String name) {
    return 'למחוק את \"$name\"? לא ניתן לבטל פעולה זו.';
  }

  @override
  String universalImport_preset_headersMatched(
    int matched,
    int total,
    int percent,
  ) {
    return '$matched/$total כותרות תואמות ($percent%)';
  }

  @override
  String get universalImport_preset_noSignatureHeaders => 'אין כותרות חתימה';

  @override
  String get universalImport_preset_deleteTooltip => 'מחק תבנית';

  @override
  String get universalImport_preset_presetsButton => 'תבניות';

  @override
  String universalImport_preset_savedSnackbar(String name) {
    return 'התבנית \"$name\" נשמרה';
  }

  @override
  String get universalImport_step_done => 'סיום';

  @override
  String get universalImport_cancel_inProgressTitle => 'מבטל';

  @override
  String get universalImport_cancel_inProgressBody =>
      'מסיים את הצלילה הנוכחית לפני העצירה. צלילות שכבר יובאו יישמרו.';

  @override
  String get universalImport_cancel_confirmTitle => 'לבטל את הייבוא?';

  @override
  String get universalImport_cancel_confirmBody =>
      'עצירה לאחר סיום הצלילה הנוכחית. צלילות שכבר יובאו יישמרו.';

  @override
  String get universalImport_cancel_keepImporting => 'המשך הייבוא';

  @override
  String get universalImport_cancel_confirmAction => 'ביטול הייבוא';

  @override
  String get universalImport_cancel_discardSelections =>
      'להשליך את הבחירות ולבטל?';

  @override
  String get universalImport_action_importSelected => 'ייבוא הנבחרים';

  @override
  String get universalImport_action_next => 'הבא';

  @override
  String get common_action_yes => 'כן';

  @override
  String get common_action_no => 'לא';

  @override
  String universalImport_counts_new(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count חדשים',
      many: '$count חדשים',
      two: '$count חדשים',
      one: '$count חדש',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_merging(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count במיזוג',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_replacing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count בהחלפה',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_skipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count דולגו',
      many: '$count דולגו',
      two: '$count דולגו',
      one: '$count דולג',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_counts_nothingSelected => 'לא נבחר דבר';

  @override
  String get universalImport_section_potentialDuplicates =>
      'כפילויות פוטנציאליות';

  @override
  String get universalImport_section_possibleDuplicates => 'כפילויות אפשריות';

  @override
  String universalImport_count_duplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count כפילויות',
      many: '$count כפילויות',
      two: 'שתי כפילויות',
      one: 'כפילות אחת',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_entityAction_importBadge => 'ייבוא';

  @override
  String get universalImport_entityAction_skipBadge => 'דילוג';

  @override
  String get universalImport_compare_existing => 'קיים';

  @override
  String get universalImport_compare_incoming => 'נכנס';

  @override
  String get universalImport_label_skipped => 'דולג';

  @override
  String get universalImport_action_viewDives => 'הצג צלילות';

  @override
  String get diveImport_healthkit_accessGranted => 'הגישה ל-HealthKit אושרה';

  @override
  String get diveImport_healthkit_accessGrantedBody => 'אפשר להמשיך לשלב הבא.';

  @override
  String get diveImport_healthkit_requesting => 'מבקש...';

  @override
  String get diveImport_healthkit_selectDateRange => 'בחירת טווח תאריכים';

  @override
  String get diveImport_healthkit_selectDateRangeBody =>
      'בחר את טווח התאריכים לחיפוש צלילות ב-Apple Health.';

  @override
  String get diveImport_healthkit_fetchingDives =>
      'מאחזר צלילות מ-Apple Health...';

  @override
  String get diveImport_healthkit_fetchFailed => 'האחזור נכשל';

  @override
  String diveImport_healthkit_fetchFailedBody(String error) {
    return 'אחזור הצלילות נכשל: $error';
  }

  @override
  String diveImport_healthkit_foundDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נמצאו $count צלילות',
      many: 'נמצאו $count צלילות',
      two: 'נמצאו שתי צלילות',
      one: 'נמצאה צלילה אחת',
    );
    return '$_temp0';
  }

  @override
  String get diveImport_healthkit_proceedingToReview => 'ממשיך לסקירה...';

  @override
  String get importWizard_dc_knownComputer => 'מחשב צלילה מוכר';

  @override
  String importWizard_dc_knownComputerBody(String name) {
    return 'נשמר בשם \"$name\". רק צלילות חדשות יורדו.';
  }

  @override
  String get importWizard_dc_noNewDives => 'אין צלילות חדשות להורדה';

  @override
  String get importWizard_dc_noNewDivesBody =>
      'כל הצלילות ממחשב הצלילה הזה כבר יובאו.';

  @override
  String get universalImport_compare_noDiveData =>
      'נתוני הצלילה אינם זמינים להשוואה.';

  @override
  String get universalImport_entityAction_consolidateBadge => 'איחוד';

  @override
  String get diveCenters_import_quickSearch_egypt => 'מצרים';

  @override
  String get diveCenters_import_quickSearch_mexico => 'מקסיקו';

  @override
  String get accessibility_shortcut_switchDiver => 'החלף צולל';

  @override
  String get lock_recoveryCode_title => 'שימוש בקוד שחזור';

  @override
  String get lock_recoveryCode_body =>
      'הזינו את קוד השחזור בן 8 המילים ששמרתם בעת הגדרת סיסמת האפליקציה.';

  @override
  String get lock_recoveryCode_error => 'קוד השחזור שגוי.';

  @override
  String get lock_forcedReset_title => 'הגדרת סיסמה חדשה';

  @override
  String get lock_forcedReset_body =>
      'ביטלתם את הנעילה באמצעות קוד השחזור, ולכן הסיסמה הישנה שלכם אינה אמינה עוד. בחרו סיסמה חדשה כעת.';

  @override
  String get lock_forcedReset_submit => 'הגדרת סיסמה';

  @override
  String get lock_forcedReset_error =>
      'לא ניתן היה להגדיר את הסיסמה החדשה. נסו שוב.';

  @override
  String get lock_sidecarRepair_title => 'תיקון קובץ מפתח האבטחה';

  @override
  String get lock_sidecarRepair_body =>
      'קובץ מפתח האבטחה שלכם היה חסר, ומחזיק המפתחות של מכשיר זה עדיין מחזיק את המפתח. אשרו את הסיסמה שלכם כדי לכתוב קובץ מפתח חדש. שימו לב: הסיסמה שתזינו כאן הופכת לסיסמת האפליקציה מכאן ואילך, ותקבלו קוד שחזור חדש.';

  @override
  String get lock_sidecarRepair_submit => 'תיקון';

  @override
  String get lock_sidecarRepair_error => 'התיקון נכשל. נסו שוב.';

  @override
  String get lock_newRecoveryCode_title => 'קוד השחזור החדש שלכם';

  @override
  String get lock_startFresh_title => 'פתיחת מסד נתונים אחר';

  @override
  String lock_startFresh_body(Object token) {
    return 'מסד הנתונים הנוכחי שלכם נשאר בדיסק, בשם חדש עם הסיומת .locked; שום דבר אינו נמחק. תוכלו לשחזר אותו מאוחר יותר באמצעות הסיסמה שלכם או בפנייה לתמיכה. סנכרון הענן יכובה כדי שמסד הנתונים החדש לא יתערבב עם הישן.\n\nהאפליקציה תיפתח עם מסד נתונים חדש וריק. תוכלו לשחזר מגיבוי באשף ההגדרה.\n\nהקלידו $token לאישור.';
  }

  @override
  String get lock_startFresh_confirm => 'לשים בצד ולהתחיל מחדש';

  @override
  String get lock_biometric_reason => 'ביטול נעילת יומן הצלילה שלכם';

  @override
  String startup_migrating_progress(Object currentStep, Object totalSteps) {
    return 'משדרג את מסד הנתונים... שלב $currentStep מתוך $totalSteps';
  }

  @override
  String get startup_error_title => 'Submersion לא הצליחה להיפתח';

  @override
  String get startup_error_body =>
      'משהו השתבש לפני שיומן הצלילה שלך נפתח במלואו. הנתונים שלך עדיין על הדיסק ואין צורך בהתקנה מחדש. נסה להפעיל מחדש את האפליקציה; אם התקלה נמשכת, פנה לתמיכה.';

  @override
  String get startup_engineUnavailable_title =>
      'גרסה זו אינה יכולה לפתוח מסד נתונים';

  @override
  String get startup_engineUnavailable_body =>
      'מנוע מסד הנתונים של Submersion חסר בגרסה הזו, ולכן יומן הצלילה שלך מעולם לא נפתח. שום דבר על הדיסק לא השתנה ואין נתונים בסיכון.';

  @override
  String get startup_engineUnavailable_guidance =>
      'התקנה מחדש או שחזור גיבוי לא יעזרו כאן. התקן גרסה תקינה של Submersion, ונשמח אם תדווח על כך: זו תקלה בחבילת האפליקציה, לא בנתונים שלך.';

  @override
  String get startup_migrationFailed_title => 'שדרוג מסד הנתונים נכשל';

  @override
  String get startup_migrationFailed_body =>
      'לא ניתן היה לשדרג את יומן הצלילה שלך לתבנית שגרסה זו דורשת. עותק בטיחות נוצר לפני תחילת השדרוג, כך ששום דבר לא אבד.';

  @override
  String get startup_dataUnreadable_title =>
      'לא ניתן היה לקרוא את יומן הצלילה שלך';

  @override
  String get startup_dataUnreadable_body =>
      'קובץ מסד הנתונים קיים, אבל Submersion לא מצליחה לקרוא אותו. בדרך כלל המשמעות היא שהקובץ פגום. שחזור גיבוי הוא הדרך המהירה ביותר לחזור.';

  @override
  String get startup_databaseBusy_title => 'יומן הצלילה שלך היה תפוס';

  @override
  String get startup_databaseBusy_body =>
      'משהו אחר עדיין השתמש בקובץ מסד הנתונים, ולכן Submersion עצר במקום לכתוב אליו. שום דבר לא השתנה ושום דבר לא ניזוק. סגור את Submersion לגמרי ופתח אותו שוב.';

  @override
  String get startup_failure_technicalDetails => 'פרטים טכניים';

  @override
  String get startup_failure_backupAvailable_title => 'יש גיבוי זמין';

  @override
  String startup_failure_backupAvailable_taken(Object timestamp) {
    return 'נוצר ב-$timestamp';
  }

  @override
  String startup_failure_backupAvailable_preMigration(
    Object fromVersion,
    Object toVersion,
  ) {
    return 'עותק בטיחות שנוצר לפני השדרוג מסכימה v$fromVersion ל-v$toVersion.';
  }

  @override
  String get startup_failure_restoreAction => 'שחזר גיבוי זה';

  @override
  String get startup_failure_restoring => 'משחזר את יומן הצלילה...';

  @override
  String get startup_failure_restoreFailed =>
      'לא ניתן היה לשחזר את הגיבוי. יומן הצלילה שלך נשאר בדיוק כפי שהיה.';

  @override
  String get startup_failure_backupsFolder => 'הגיבויים שלך נמצאים ב:';

  @override
  String get startup_failure_showBackupsFolder => 'הצג את תיקיית הגיבויים';

  @override
  String get startup_failure_downgrade_title => 'חזרה לגרסה הקודמת';

  @override
  String get startup_failure_downgrade_body =>
      'אם השדרוג ממשיך להיכשל, התקן את גרסת Submersion שהשתמשת בה קודם, ואז שחזר את עותק הבטיחות מתוך אותה גרסה. שחזור כאן רק יריץ שוב את אותו שדרוג. Submersion לעולם אינה חוזרת לגרסה ישנה מעצמה: העברה אוטומטית לגרסאות ישנות הייתה משאירה אותך בשקט על גרסאות עם בעיות ידועות.';

  @override
  String get startup_failure_downgrade_action => 'הצג גרסאות קודמות';

  @override
  String get startup_recovering_title => 'משחזר את מסד הנתונים...';

  @override
  String get startup_recovering_body =>
      'מבטל את הפעולה שנקטעה. זה נמשך בדרך כלל כמה שניות.';

  @override
  String get startup_recoveryFailed_title => 'השחזור לא הושלם';

  @override
  String get startup_recoveryFailed_body =>
      'לא ניתן היה לבטל את השינויים במסד הנתונים באופן אוטומטי. הנתונים שלכם עדיין בדיסק; פנו לתמיכה לפני התקנה מחדש כדי שנוכל לעזור לכם לשחזר אותם.';

  @override
  String get startup_recoveryRequired_title => 'מסד הנתונים זקוק לשחזור';

  @override
  String get startup_recoveryRequired_body =>
      'הפעלה קודמת נקטעה בזמן כתיבה למסד הנתונים. הנתונים שלכם עדיין בדיסק; עלינו רק להשלים את ביטול השינוי שבוטל לפני שהאפליקציה תוכל להיפתח.';

  @override
  String startup_recovery_sqliteCode(Object code) {
    return 'קוד SQLite $code';
  }

  @override
  String get startup_recovery_action => 'שחזור מסד הנתונים';

  @override
  String get startup_recovery_closeWithoutRecovering => 'סגירה ללא שחזור';

  @override
  String get common_action_tryAgain => 'נסו שוב';

  @override
  String get lock_screen_title => 'האפליקציה Submersion נעולה';

  @override
  String get lock_screen_forgotPassword => 'שכחתם את הסיסמה?';

  @override
  String get lock_incorrectPassword => 'סיסמה שגויה. נסו שוב.';

  @override
  String get startup_backup_semanticsLabel => 'מגבה';

  @override
  String get startup_backup_title => 'מגבה את הנתונים שלכם';

  @override
  String get startup_backup_body =>
      'אנחנו שומרים עותק של יומן הצלילות שלכם לפני עדכון מסד הנתונים.';

  @override
  String get startup_backupFailed_title => 'לא ניתן היה לגבות את הנתונים שלכם';

  @override
  String get startup_backupFailed_body =>
      'יומן הצלילות שלכם לא השתנה; לא עדכנו אותו. פנו מקום (או תקנו את התקלה) ונסו שוב.';

  @override
  String get startup_backupFailed_quit => 'יציאה';

  @override
  String get startup_backupFailed_technicalDetails => 'פרטים טכניים';

  @override
  String get common_action_retry => 'נסה שוב';

  @override
  String get startup_versionMismatch_title => 'נדרש עדכון';

  @override
  String startup_versionMismatch_body(
    Object databaseVersion,
    Object appVersion,
  ) {
    return 'נתוני הצלילה שלכם נשמרו בגרסה חדשה יותר של Submersion (סכמה v$databaseVersion). גרסה זו תומכת רק עד סכמה v$appVersion.';
  }

  @override
  String get startup_versionMismatch_instructions =>
      'עדכנו את Submersion לגרסה האחרונה. הנתונים שלכם בטוחים ולא שונו. אם נוצר גיבוי לפני השדרוג, הוא נמצא בתיקיית Backups וניתן לשחזר אותו לאחר העדכון.';

  @override
  String get startup_versionMismatch_storeInstructions =>
      'אפליקציה זו הותקנה מחנות אפליקציות והיא ישנה יותר מהגרסה שיצרה את הנתונים שלך. הנתונים שלך בטוחים ולא שונו. עדכן את Submersion כשהגרסה החדשה תופיע בחנות, ואז פתח את האפליקציה מחדש.';

  @override
  String get startup_versionMismatch_download => 'הורדת הגרסה האחרונה';

  @override
  String get startup_versionMismatch_manualLink =>
      'אם פעולה זו אינה פותחת דפדפן, בקרו בכתובת:';

  @override
  String get universalImport_compare_downloaded => 'הורד';

  @override
  String get universalImport_compare_errorLoading =>
      'שגיאה בטעינת נתוני הצלילה';

  @override
  String get universalImport_compare_diveNotFound => 'הצלילה הקיימת לא נמצאה';

  @override
  String universalImport_compare_sameFields(Object fields) {
    return 'זהה: $fields';
  }

  @override
  String get universalImport_compare_differences => 'הבדלים';

  @override
  String get universalImport_compare_notRecorded => 'לא הוקלט';

  @override
  String universalImport_compare_serial(Object serial) {
    return 'S/N: $serial';
  }

  @override
  String get universalImport_compare_skipSubtitle => 'השלכת הורדה זו';

  @override
  String get universalImport_compare_importAsNewSubtitle =>
      'שמירה כצלילה נפרדת';

  @override
  String get universalImport_compare_consolidateSubtitle =>
      'הוספה כקריאה של מחשב שני';

  @override
  String get diveLog_tooltip_ndlOverMax => '>60 min';

  @override
  String diveLog_tooltip_interpolated(String value) {
    return '$value (אינטרפולציה)';
  }

  @override
  String get enum_profileMetric_ascentRate_short => 'קצב';

  @override
  String get enum_profileMetric_cns_short => 'CNS';

  @override
  String get enum_profileMetric_otu_short => 'OTU';

  @override
  String get diveLog_profileEditor_rangeOperations => 'פעולות על טווח';

  @override
  String get diveLog_profileEditor_selectRangeHint =>
      'בחרו טווח בגרף כדי לאפשר פעולות';

  @override
  String get diveLog_profileEditor_depthPlusOneMeter => 'עומק +1m';

  @override
  String get diveLog_profileEditor_depthMinusOneMeter => 'עומק -1m';

  @override
  String get diveLog_profileEditor_timePlusFiveSeconds => 'זמן +5s';

  @override
  String get diveLog_profileEditor_timeMinusFiveSeconds => 'זמן -5s';

  @override
  String get diveLog_profileEditor_smoothing => 'החלקה';

  @override
  String get diveLog_profileEditor_smoothLight => 'קלה';

  @override
  String get diveLog_profileEditor_smoothMedium => 'בינונית';

  @override
  String get diveLog_profileEditor_smoothHeavy => 'חזקה';

  @override
  String get diveLog_profileEditor_applyToAll => 'החלה על הכל';

  @override
  String get diveLog_profileEditor_applyToSelection => 'החלה על הבחירה';

  @override
  String get diveLog_profileEditor_outlierDetection => 'זיהוי חריגות';

  @override
  String get diveLog_profileEditor_detect => 'זיהוי';

  @override
  String get diveLog_profileEditor_removeAll => 'הסרת הכל';

  @override
  String diveLog_profileEditor_outliersDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'זוהו $count חריגות אפשריות',
      many: 'זוהו $count חריגות אפשריות',
      two: 'זוהו שתי חריגות אפשריות',
      one: 'זוהתה חריגה אפשרית אחת',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_profileEditor_manualDrawing => 'ציור ידני';

  @override
  String get diveLog_profileEditor_drawHint =>
      'הקישו על הגרף כדי למקם נקודות ציון';

  @override
  String get diveLog_profileEditor_clearWaypoints => 'ניקוי';

  @override
  String get diveLog_profileEditor_generateProfile => 'יצירת פרופיל';

  @override
  String get diveLog_profileEditor_trimMode => 'מצב חיתוך';

  @override
  String get diveLog_profileEditor_trimHint => 'חיתוך קצות הפרופיל';

  @override
  String get diveLog_profileEditor_trimEnd => 'חיתוך הסוף';

  @override
  String get diveLog_profileEditor_mode_smooth => 'החלקה';

  @override
  String get diveLog_profileEditor_title => 'עריכת פרופיל';

  @override
  String get diveLog_profileEditor_discardBody =>
      'יש לכם שינויים שלא נשמרו בפרופיל הצלילה הזה. בטוחים שברצונכם לבטל אותם?';

  @override
  String get diveLog_profileEditor_saveTitle => 'לשמור את הפרופיל?';

  @override
  String get diveLog_profileEditor_saveBody =>
      'פעולה זו תשמור את הפרופיל הערוך כפרופיל הראשי של הצלילה הזו. הפרופיל המקורי יישמר וניתן יהיה לשחזר אותו מאוחר יותר.';

  @override
  String diveLog_profileEditor_saveFailed(String error) {
    return 'שמירת הפרופיל נכשלה: $error';
  }

  @override
  String diveLog_profileEditor_errorLoadingDive(String error) {
    return 'שגיאה בטעינת הצלילה: $error';
  }

  @override
  String get diveLog_profileEditor_noProfileData => 'אין נתוני פרופיל זמינים';

  @override
  String get diveLog_profileEditor_undo => 'ביטול פעולה';

  @override
  String get diveLog_profileEditor_mode_select => 'בחירה';

  @override
  String get diveLog_profileEditor_mode_outlier => 'חריגה';

  @override
  String get diveLog_profileEditor_mode_draw => 'ציור';

  @override
  String get diveLog_profileEditor_mode_trim => 'חיתוך';

  @override
  String diveLog_sources_sectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'מקורות נתונים',
      many: 'מקורות נתונים',
      two: 'מקורות נתונים',
      one: 'מקור נתונים',
      zero: 'מקור נתונים',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_badge_manual => 'ידני';

  @override
  String get diveLog_sources_badge_viewing => 'בתצוגה';

  @override
  String get diveLog_sources_badge_secondary => 'משני';

  @override
  String diveLog_sources_created(String date) {
    return 'נוצר ב-$date';
  }

  @override
  String get diveLog_sources_detail_serial => 'מספר סידורי';

  @override
  String get diveLog_sources_detail_format => 'פורמט';

  @override
  String get diveLog_sources_detail_imported => 'יובא';

  @override
  String diveLog_detail_semantics_viewDiveComputer(String name) {
    return 'הצגת מחשב הצלילה $name';
  }

  @override
  String diveLog_detail_semantics_viewTrip(String name) {
    return 'הצגת הטיול $name';
  }

  @override
  String diveLog_detail_semantics_viewDiveCenter(String name) {
    return 'הצגת מרכז הצלילה $name';
  }

  @override
  String diveLog_detail_semantics_viewSpecies(String name) {
    return 'הצגת המין $name';
  }

  @override
  String diveLog_detail_semantics_viewCourse(String name) {
    return 'הצגת הקורס $name';
  }

  @override
  String diveLog_detail_serialNumber(String serial) {
    return 'S/N $serial';
  }

  @override
  String diveLog_detail_errorLoadingSignature(String error) {
    return 'שגיאה בטעינת החתימה: $error';
  }

  @override
  String get diveLog_profilePanel_selectDive =>
      'בחרו צלילה כדי לראות את הפרופיל שלה';

  @override
  String get diveLog_profilePanel_noProfileData => 'אין נתוני פרופיל לצלילה זו';

  @override
  String get settings_export_progress_divesCsv => 'מייצא צלילות ל-CSV...';

  @override
  String get settings_export_progress_sitesCsv => 'מייצא אתרים ל-CSV...';

  @override
  String get settings_export_progress_equipmentCsv => 'מייצא ציוד ל-CSV...';

  @override
  String get settings_export_progress_pdf => 'יוצר יומן צלילות בפורמט PDF...';

  @override
  String get settings_export_progress_loadingSignatures => 'טוען חתימות...';

  @override
  String get settings_export_progress_loadingCertifications => 'טוען הסמכות...';

  @override
  String get settings_export_progress_loadingFonts => 'טוען גופנים...';

  @override
  String settings_export_progress_templatePdf(String template) {
    return 'יוצר PDF בתבנית $template...';
  }

  @override
  String get settings_export_progress_uddf => 'יוצר קובץ UDDF...';

  @override
  String get settings_export_progress_collectingData => 'אוסף את כל הנתונים...';

  @override
  String get settings_export_progress_excel => 'יוצר קובץ Excel...';

  @override
  String get settings_export_progress_buildingExcel =>
      'בונה חוברת עבודה של Excel...';

  @override
  String get settings_export_progress_kml => 'יוצר קובץ KML...';

  @override
  String get settings_export_progress_buildingKml => 'בונה קובץ KML...';

  @override
  String get settings_export_progress_preparingExcel => 'מכין קובץ Excel...';

  @override
  String get settings_export_progress_preparingKml => 'מכין קובץ KML...';

  @override
  String get settings_export_progress_chooseLocation => 'בחר מיקום לשמירה...';

  @override
  String get settings_export_progress_preparingDivesCsv =>
      'מכין CSV של צלילות...';

  @override
  String get settings_export_progress_preparingSitesCsv =>
      'מכין CSV של אתרים...';

  @override
  String get settings_export_progress_preparingEquipmentCsv =>
      'מכין CSV של ציוד...';

  @override
  String get settings_export_progress_preparingUddf => 'מכין קובץ UDDF...';

  @override
  String get settings_export_progress_preparingPdf => 'מכין PDF...';

  @override
  String get settings_export_progress_selectingBackup => 'בוחר קובץ גיבוי...';

  @override
  String get settings_export_progress_restoringBackup => 'משחזר מגיבוי...';

  @override
  String get settings_export_empty_dives => 'אין צלילות לייצוא';

  @override
  String get settings_export_empty_sites => 'אין אתרים לייצוא';

  @override
  String get settings_export_empty_equipment => 'אין ציוד לייצוא';

  @override
  String get settings_export_empty_data => 'אין נתונים לייצוא';

  @override
  String get settings_export_empty_diveSites => 'אין אתרי צלילה לייצוא';

  @override
  String settings_export_saveFailed(String error) {
    return 'השמירה נכשלה: $error';
  }

  @override
  String settings_export_backupFailed(String error) {
    return 'הגיבוי נכשל: $error';
  }

  @override
  String settings_export_restoreFailed(String error) {
    return 'השחזור נכשל: $error';
  }

  @override
  String get settings_export_fileUnreadable => 'לא ניתן לגשת לקובץ';

  @override
  String get settings_export_notADbFile => 'יש לבחור קובץ גיבוי בסיומת .db';

  @override
  String get settings_export_success_dives => 'הצלילות יוצאו בהצלחה';

  @override
  String get settings_export_success_sites => 'האתרים יוצאו בהצלחה';

  @override
  String get settings_export_success_equipment => 'הציוד יוצא בהצלחה';

  @override
  String get settings_export_success_pdf =>
      'יומן הצלילות בפורמט PDF נוצר בהצלחה';

  @override
  String get settings_export_success_uddf => 'קובץ UDDF נוצר בהצלחה';

  @override
  String get settings_export_success_excel => 'קובץ Excel יוצא בהצלחה';

  @override
  String settings_export_success_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'קובץ KML יוצא בהצלחה ($count אתרים ללא קואורדינטות דולגו)',
      many: 'קובץ KML יוצא בהצלחה ($count אתרים ללא קואורדינטות דולגו)',
      two: 'קובץ KML יוצא בהצלחה (שני אתרים ללא קואורדינטות דולגו)',
      one: 'קובץ KML יוצא בהצלחה (אתר אחד ללא קואורדינטות דולג)',
      zero: 'קובץ KML יוצא בהצלחה',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_excel => 'קובץ Excel נשמר בהצלחה';

  @override
  String settings_export_saved_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'קובץ KML נשמר בהצלחה ($count אתרים ללא קואורדינטות דולגו)',
      many: 'קובץ KML נשמר בהצלחה ($count אתרים ללא קואורדינטות דולגו)',
      two: 'קובץ KML נשמר בהצלחה (שני אתרים ללא קואורדינטות דולגו)',
      one: 'קובץ KML נשמר בהצלחה (אתר אחד ללא קואורדינטות דולג)',
      zero: 'קובץ KML נשמר בהצלחה',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_divesCsv => 'CSV של הצלילות נשמר בהצלחה';

  @override
  String get settings_export_saved_sitesCsv => 'CSV של האתרים נשמר בהצלחה';

  @override
  String get settings_export_saved_equipmentCsv => 'CSV של הציוד נשמר בהצלחה';

  @override
  String get settings_export_saved_uddf => 'קובץ UDDF נשמר בהצלחה';

  @override
  String get settings_export_saved_pdf => 'קובץ PDF נשמר בהצלחה';

  @override
  String get settings_export_saved_backup => 'הגיבוי נשמר בהצלחה';

  @override
  String get settings_export_restoreComplete => 'השחזור הושלם';

  @override
  String get settings_export_cancelled_save => 'השמירה בוטלה';

  @override
  String get settings_export_cancelled_backup => 'הגיבוי בוטל';

  @override
  String get settings_export_cancelled_restore => 'השחזור בוטל';

  @override
  String get settings_export_pdfDocumentTitle => 'יומן צלילות';

  @override
  String get settings_export_saveBackupDialogTitle => 'שמירת גיבוי';

  @override
  String backup_operation_created(String size) {
    return 'נוצר גיבוי: $size';
  }

  @override
  String backup_operation_backupFailed(String error) {
    return 'הגיבוי נכשל: $error';
  }

  @override
  String get backup_operation_restoring => 'משחזר גיבוי...';

  @override
  String backup_operation_restoreFailed(String error) {
    return 'השחזור נכשל: $error';
  }

  @override
  String get backup_operation_deleting => 'מוחק גיבוי...';

  @override
  String get backup_operation_deleted => 'הגיבוי נמחק';

  @override
  String backup_operation_deleteFailed(String error) {
    return 'המחיקה נכשלה: $error';
  }

  @override
  String get backup_operation_exporting => 'מייצא גיבוי...';

  @override
  String backup_operation_exported(String size) {
    return 'הגיבוי יוצא: $size';
  }

  @override
  String backup_operation_exportFailed(String error) {
    return 'הייצוא נכשל: $error';
  }

  @override
  String get backup_operation_preparingShare => 'מכין את הגיבוי לשיתוף...';

  @override
  String get backup_operation_shareReady => 'הגיבוי מוכן לשיתוף';

  @override
  String backup_operation_upgrading(int step, int total) {
    return 'משדרג את מסד הנתונים (שלב $step מתוך $total)...';
  }

  @override
  String backup_restore_dialog_counts(int diveCount, int siteCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount צלילות',
      many: '$diveCount צלילות',
      two: 'שתי צלילות',
      one: 'צלילה אחת',
    );
    String _temp1 = intl.Intl.pluralLogic(
      siteCount,
      locale: localeName,
      other: '$siteCount אתרים',
      many: '$siteCount אתרים',
      two: 'שני אתרים',
      one: 'אתר אחד',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get backup_restore_preMigration_title =>
      'שחזור גיבוי שנוצר לפני המיגרציה';

  @override
  String get backup_restore_preMigration_unknownVersion => 'גרסה לא ידועה';

  @override
  String get backup_restore_preMigration_restoreAnyway => 'שחזר בכל זאת';

  @override
  String backup_restore_preMigration_incompleteMetadata(
    String timestamp,
    String appVersion,
  ) {
    return 'גיבוי זה נוצר בתאריך $timestamp על ידי גרסת האפליקציה $appVersion, אך מטא-הנתונים של מיגרציית מסד הנתונים שלו חסרים.\n\nהאפליקציה אינה יכולה לוודא אם שחזור הגיבוי הזה בטוח, ולכן השחזור מושבת.';
  }

  @override
  String backup_restore_preMigration_newerApp(
    String timestamp,
    String appVersion,
    int fromVersion,
  ) {
    return 'גיבוי זה חדש יותר מהאפליקציה שלך. התקן גרסת אפליקציה חדשה יותר כדי לשחזר אותו.\n\nהגיבוי נוצר בתאריך $timestamp על ידי גרסת האפליקציה $appVersion (מסד נתונים v$fromVersion).';
  }

  @override
  String backup_restore_preMigration_safe(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
  ) {
    return 'גיבוי זה נוצר בתאריך $timestamp על ידי גרסת האפליקציה $appVersion, ממש לפני שדרוג מסד הנתונים מגרסה v$fromVersion לגרסה v$toVersion.\n\nסכמת מסד הנתונים של האפליקציה שלך תואמת לגיבוי הזה, ולכן השחזור בטוח.';
  }

  @override
  String backup_restore_preMigration_warning(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
    int currentVersion,
  ) {
    return 'גיבוי זה נוצר בתאריך $timestamp על ידי גרסת האפליקציה $appVersion, ממש לפני שדרוג מסד הנתונים מגרסה v$fromVersion לגרסה v$toVersion.\n\nאתה מריץ אפליקציה חדשה יותר (מסד נתונים v$currentVersion).\n\nשחזור עכשיו יריץ מחדש את שדרוג מסד הנתונים v$fromVersion → v$toVersion על הנתונים המשוחזרים: בדיוק אותו שדרוג שעמד לרוץ במקור. אם השדרוג הזה גרם לבעיה, תיתקל באותה תקלה שוב.\n\nכדי לשחזר בבטחה: התקן את האפליקציה בגרסה $appVersion או קודמת לה, ואז שחזר את הגיבוי הזה מאותה אפליקציה ישנה יותר.';
  }

  @override
  String get settings_cloudSync_progress_preparing => 'מכין סנכרון...';

  @override
  String get settings_cloudSync_progress_pulling => 'מושך שינויים...';

  @override
  String get settings_cloudSync_progress_publishing => 'מפרסם שינויים...';

  @override
  String settings_cloudSync_progress_uploadingLibrary(int uploaded, int total) {
    return 'מעלה את הספרייה ($uploaded מתוך $total)';
  }

  @override
  String get settings_cloudSync_result_noProvider => 'לא הוגדר ספק ענן';

  @override
  String get settings_cloudSync_result_notAuthenticated =>
      'אין אימות מול ספק הענן';

  @override
  String get settings_cloudSync_result_timedOut => 'תם הזמן המוקצב לסנכרון';

  @override
  String get settings_cloudSync_result_epochMarkerUnreadable =>
      'לא ניתן היה לקרוא את סמן העידן של הספרייה';

  @override
  String get settings_cloudSync_result_epochMarkerEncrypted =>
      'סמן העידן של הספרייה מוצפן';

  @override
  String get settings_cloudSync_result_libraryReplacedRemotely =>
      'ספריית הענן הוחלפה מגיבוי';

  @override
  String get settings_cloudSync_result_noReplacementToRebuild =>
      'אין החלפת ספרייה שניתן לבנות ממנה מחדש';

  @override
  String get settings_cloudSync_result_rebuiltFromThisDevice =>
      'השירות הזה נבנה מחדש מהספרייה של מכשיר זה';

  @override
  String settings_cloudSync_result_rebuildFailed(String error) {
    return 'הבנייה מחדש נכשלה: $error';
  }

  @override
  String get settings_cloudSync_result_libraryReplaced => 'הספרייה הוחלפה';

  @override
  String settings_cloudSync_result_libraryReplaceFailed(String error) {
    return 'החלפת הספרייה נכשלה: $error';
  }

  @override
  String get settings_cloudSync_result_noReplacementMarker =>
      'לא נמצא סמן להחלפת ספרייה';

  @override
  String get settings_cloudSync_result_adoptedRestoredLibrary =>
      'הספרייה המשוחזרת אומצה';

  @override
  String settings_cloudSync_result_adoptFailed(String error) {
    return 'אימוץ הספרייה המשוחזרת נכשל: $error';
  }

  @override
  String get settings_cloudSync_result_previousLibraryUnreadable =>
      'לא ניתן היה לקרוא את הספרייה הקודמת; השירות הזה הוקם מחדש מהספרייה של מכשיר זה.';

  @override
  String get settings_cloudSync_result_replacementStillUploading =>
      'הספרייה שהוחלפה עדיין בהעלאה. נסה שוב בעוד רגע.';

  @override
  String settings_cloudSync_result_recordsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'החלת $count רשומות נכשלה',
      many: 'החלת $count רשומות נכשלה',
      two: 'החלת שתי רשומות נכשלה',
      one: 'החלת רשומה אחת נכשלה',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_result_adoptedFreshIdentity =>
      'מכשיר אחר סנכרן באמצעות הזהות של מכשיר זה. מכשיר זה אימץ זהות חדשה ומיזג את נתוני הענן.';

  @override
  String settings_cloudSync_launchCheck_unavailable(String provider) {
    return '$provider אינו זמין במכשיר זה';
  }

  @override
  String settings_cloudSync_launchCheck_notSignedIn(String provider) {
    return 'לא מחובר אל $provider';
  }

  @override
  String settings_cloudSync_launchCheck_localChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count שינויים מקומיים להעלאה',
      many: '$count שינויים מקומיים להעלאה',
      two: 'שני שינויים מקומיים להעלאה',
      one: 'שינוי מקומי אחד להעלאה',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_launchCheck_noRemoteData =>
      'לא נמצאו נתוני סנכרון בענן';

  @override
  String get settings_cloudSync_launchCheck_cloudDataAvailable =>
      'נתוני ענן זמינים';

  @override
  String get settings_cloudSync_launchCheck_updatesAvailable =>
      'יש עדכונים זמינים מהענן';

  @override
  String get settings_cloudSync_launchCheck_upToDate => 'הכול מעודכן';

  @override
  String settings_cloudSync_launchCheck_failed(String error) {
    return 'בדיקת הסנכרון נכשלה: $error';
  }

  @override
  String get diveLog_detail_viewMap => 'מפה';

  @override
  String get diveLog_detail_view3d => '3D';

  @override
  String get setup_sync_icloudUnavailable => 'iCloud אינו זמין במכשיר זה';

  @override
  String get media_info_title => 'פרטי מדיה';

  @override
  String get media_info_fileSection => 'קובץ';

  @override
  String get media_info_filename => 'שם הקובץ';

  @override
  String get media_info_type => 'סוג';

  @override
  String get media_info_dimensions => 'ממדים';

  @override
  String get media_info_size => 'גודל';

  @override
  String get media_info_taken => 'צולם';

  @override
  String get media_info_coordinates => 'קואורדינטות';

  @override
  String get media_info_unknown => 'לא ידוע';

  @override
  String get media_info_originSection => 'מקור';

  @override
  String get media_info_source => 'מקור';

  @override
  String get media_info_reference => 'הפניה';

  @override
  String get media_info_linkedOn => 'קושר במכשיר';

  @override
  String get media_info_thisDevice => 'מכשיר זה';

  @override
  String get media_info_otherDevice => 'מכשיר אחר';

  @override
  String get media_info_status => 'מצב';

  @override
  String get media_info_statusFound => 'נמצא במכשיר זה';

  @override
  String get media_info_statusMissing => 'חסר במכשיר זה';

  @override
  String get media_info_statusUnchecked => 'טרם נבדק';

  @override
  String media_info_lastChecked(String date) {
    return 'נבדק לאחרונה $date';
  }

  @override
  String get media_timeInDive_label => 'זמן בצלילה';

  @override
  String get media_timeInDive_unknown => 'זמן בצלילה לא ידוע';

  @override
  String get media_timeInDive_setAction => 'הגדרת זמן בצלילה';

  @override
  String media_timeInDive_manual(String time) {
    return '$time (הוגדר ידנית)';
  }

  @override
  String get media_timeInDive_fieldLabel => 'זמן מתחילת הצלילה';

  @override
  String get media_timeInDive_fieldHint => 'mm:ss';

  @override
  String media_timeInDive_range(String max) {
    return 'בין 0:00 ל-$max';
  }

  @override
  String media_timeInDive_invalid(String max) {
    return 'יש להזין זמן בין 0:00 ל-$max';
  }

  @override
  String get media_timeInDive_save => 'שמור';

  @override
  String get media_timeInDive_cancel => 'ביטול';

  @override
  String get media_timeInDive_reset => 'איפוס לאוטומטי';

  @override
  String get media_info_backupSection => 'גיבוי';

  @override
  String get media_info_store => 'אחסון בענן';

  @override
  String get media_info_storeNotConnected => 'לא מחובר אחסון בענן';

  @override
  String get media_info_notEligible => 'מקור זה אינו זכאי לגיבוי';

  @override
  String get media_info_backupFull => 'המקור הועלה';

  @override
  String get media_info_backupThumbOnly => 'תמונה ממוזערת בלבד, המקור לא נשלח';

  @override
  String get media_info_backupRenditionOnly => 'גרסה דחוסה הועלתה';

  @override
  String get media_info_backupNone => 'לא מגובה';

  @override
  String media_info_uploadedOn(String date) {
    return 'הועלה $date';
  }

  @override
  String get media_info_queuePending => 'ממתין להעלאה';

  @override
  String get media_info_queueTransferring => 'מעלה כעת';

  @override
  String media_info_queueFailed(Object error) {
    return 'ההעלאה נכשלה: $error';
  }

  @override
  String get media_info_servingSection => 'מוגש כעת';

  @override
  String get media_info_servingUnobserved => 'טרם נטען';

  @override
  String get media_info_servingFailed => 'לא ניתן היה לטעון';

  @override
  String get media_info_servedLocalDisk => 'קובץ מקומי במכשיר זה';

  @override
  String get media_info_servedGallery => 'ספריית התמונות';

  @override
  String get media_info_servedStoreCache => 'מטמון מקומי, מהאחסון בענן';

  @override
  String get media_info_servedStoreNetwork => 'הורד מהאחסון בענן';

  @override
  String get media_info_servedNetworkUrl => 'הזרמה מכתובת URL';

  @override
  String get media_info_servedConnectorCache => 'מטמון מקומי, מהשירות המחובר';

  @override
  String get media_info_servedConnectorNetwork => 'הורד מהשירות המחובר';

  @override
  String get media_info_servedEmbedded => 'מאוחסן ביומן זה';

  @override
  String get media_info_servingFallbackNote =>
      'לא ניתן היה להגיע למקור המקורי, ולכן האחסון בענן סיפק זאת.';

  @override
  String get media_info_servingTierThumbnail => 'תמונה ממוזערת';

  @override
  String get media_info_servingTierRendition => 'גרסה דחוסה';

  @override
  String get media_info_typePhoto => 'תמונה';

  @override
  String get media_info_typeVideo => 'וידאו';

  @override
  String get media_info_typeDocument => 'מסמך';

  @override
  String get media_info_typeSignature => 'חתימה';

  @override
  String get media_info_actionCheckNow => 'בדוק עכשיו';

  @override
  String get media_info_actionLocate => 'אתר קובץ...';

  @override
  String get media_info_actionBackUpNow => 'גבה עכשיו';

  @override
  String get media_info_actionRetryUpload => 'נסה להעלות שוב';

  @override
  String get media_info_actionReveal => 'הצג במנהל הקבצים';

  @override
  String get media_info_actionCopyPath => 'העתק הפניה';

  @override
  String get media_info_referenceCopied => 'ההפניה הועתקה';

  @override
  String get media_info_checkFound => 'המקור נמצא';

  @override
  String get media_info_checkMissing => 'המקור חסר';

  @override
  String get media_info_checkUnavailable => 'לא ניתן לבדוק כעת';

  @override
  String get media_info_backupQueued => 'בתור להעלאה';

  @override
  String get enum_profileMetric_o2CellMv => 'תאי O2';

  @override
  String get enum_profileMetric_o2CellMv_short => 'תאים';

  @override
  String get diveLog_o2CellSpread_label => 'פיזור תאי O2';

  @override
  String get media_status_broken => 'חסר ולא מגובה';

  @override
  String get media_servedFrom_localDisk => 'במכשיר הזה';

  @override
  String get media_servedFrom_platformGallery => 'ספריית התמונות';

  @override
  String get media_servedFrom_storeCache => 'אחסון ענן, שמור במטמון כאן';

  @override
  String get media_servedFrom_storeNetwork => 'אחסון ענן';

  @override
  String get media_servedFrom_networkUrl => 'קישור אינטרנט';

  @override
  String get media_servedFrom_connectorCache => 'שירות מחובר, שמור במטמון כאן';

  @override
  String get media_servedFrom_connectorNetwork => 'שירות מחובר';

  @override
  String get media_servedFrom_embedded => 'שמור ביומן הזה';

  @override
  String get settings_media_provenanceBadges =>
      'הצגת תגי מקור על תמונות ממוזערות';

  @override
  String get settings_media_provenanceBadgesSubtitle =>
      'סמל קטן שמראה מאיפה כל פריט מוגש. תגי בעיה מוצגים תמיד.';

  @override
  String get media_status_transferFailed => 'ההעלאה נכשלה';

  @override
  String get media_status_transferring => 'מעלה';

  @override
  String get media_status_queued => 'ממתין להעלאה';

  @override
  String get media_status_cloudOnly => 'מאוחסן בענן בלבד';

  @override
  String get media_status_notBackedUp => 'לא מגובה';

  @override
  String get media_tile_infoMenuItem => 'פרטי מדיה';

  @override
  String get diveImport_healthkit_accessGrantedHint =>
      'אפליקציית הבריאות של Apple לעולם אינה מגלה ליישומים אם ניתנה הרשאת קריאה. אם לא מופיעות צלילות, פתחו את אפליקציית הבריאות, ואז שיתוף, יישומים, Submersion, והפעילו אימונים, עומק מתחת למים, טמפרטורת מים ודופק.';

  @override
  String get diveImport_healthkit_foundNoDivesHint =>
      'אין אימוני צלילה בטווח הזה. ודאו שהתאריכים כוללים את הצלילה ושבאפליקציית הבריאות, בשיתוף, יישומים, Submersion, מופעלים אימונים ועומק מתחת למים.';

  @override
  String get settings_dataSources_appleHealth_dataTypeDepth =>
      'עומק מתחת למים - דגימות עומק שנרשמו במהלך צלילות';

  @override
  String get settings_dataSources_appleHealth_dataTypeWaterTemp =>
      'טמפרטורת מים - דגימות טמפרטורה שנרשמו במהלך צלילות';

  @override
  String get settings_dataSources_appleHealth_permissionManagedInHealth =>
      'הגישה ל-HealthKit מנוהלת באפליקציית הבריאות';

  @override
  String get settings_dataSources_appleHealth_permissionUnsupported =>
      'HealthKit אינו זמין במכשיר הזה';
}
