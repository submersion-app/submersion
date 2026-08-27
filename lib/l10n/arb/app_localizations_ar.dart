// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get universalImport_action_importFromGarmin =>
      'استيراد من جهاز Garmin';

  @override
  String diveLog_edit_flightWindowWarning(String time) {
    return 'ينتهي هذا الغوص بعد آخر وقت آمن للصعود إلى السطح قبل رحلتك ($time)';
  }

  @override
  String diveLog_edit_geofenceSuggestion_near(String location) {
    return 'بالقرب من $location';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_title => 'اقتراح المعدات';

  @override
  String diveLog_edit_geofenceSuggestion_body(String setName) {
    return 'تطبيق مجموعة \"$setName\"؟';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_apply => 'تطبيق';

  @override
  String get common_action_dismiss => 'تجاهل';

  @override
  String get equipment_setEdit_defaultSwitch_title => 'المجموعة الافتراضية';

  @override
  String get equipment_setEdit_defaultSwitch_subtitle =>
      'تُطبَّق تلقائيًا على الغطسات الجديدة التي لا تحتوي على معدات بعد';

  @override
  String get equipment_setEdit_geofencesTitle => 'الأسوار الجغرافية';

  @override
  String get equipment_setEdit_geofencesSubtitle =>
      'اقترح هذه المجموعة تلقائيًا للغطسات القريبة من هذه المواقع';

  @override
  String get equipment_setEdit_addGeofence => 'إضافة سياج جغرافي';

  @override
  String get equipment_setEdit_editGeofence => 'Edit geofence';

  @override
  String get equipment_setEdit_removeGeofence => 'Remove geofence';

  @override
  String equipment_setEdit_geofenceRadius(String distance) {
    return 'نصف القطر: $distance';
  }

  @override
  String get equipment_geofenceEditor_title => 'سياج جغرافي';

  @override
  String get equipment_geofenceEditor_fromSite => 'من موقع الغوص';

  @override
  String get equipment_geofenceEditor_dropPin => 'إسقاط دبوس';

  @override
  String get equipment_geofenceEditor_labelLabel => 'التسمية';

  @override
  String get equipment_geofenceEditor_noCenter => 'اختر نقطة مركزية';

  @override
  String get equipment_geofenceEditor_save => 'حفظ السياج الجغرافي';

  @override
  String get equipment_sets_defaultBadge => 'افتراضي';

  @override
  String get equipment_setDetail_setAsDefault => 'تعيين كافتراضي';

  @override
  String equipment_setDetail_setAsDefaultSnackbar(String name) {
    return 'أصبحت \"$name\" الآن مجموعتك الافتراضية';
  }

  @override
  String get equipment_setDetail_geofencesTitle => 'الأسوار الجغرافية';

  @override
  String get equipment_setDetail_noGeofences => 'لا توجد أسوار جغرافية';

  @override
  String formatter_duration_minutes(Object minutes) {
    return '$minutes د';
  }

  @override
  String formatter_duration_minutesSeconds(Object minutes, Object seconds) {
    return '$minutes د $seconds ث';
  }

  @override
  String formatter_duration_seconds(Object seconds) {
    return '$seconds ث';
  }

  @override
  String gasCalculators_bestMix_densityCritical(Object limit) {
    return 'أعلى من الحد الأقصى للكثافة $limit g/L.';
  }

  @override
  String get gasCalculators_bestMix_densityLabel => 'كثافة الغاز عند العمق';

  @override
  String gasCalculators_bestMix_densityWarn(Object limit) {
    return 'أعلى من حد الكثافة الموصى به $limit g/L.';
  }

  @override
  String gasCalculators_bestMix_endExceeded(Object limit) {
    return 'قيمة END تتجاوز حدك $limit.';
  }

  @override
  String get gasCalculators_bestMix_endLabel => 'END عند العمق';

  @override
  String get gasCalculators_bestMix_endLimitLabel => 'حد END';

  @override
  String gasCalculators_bestMix_heliumAdded(Object limit) {
    return 'تمت إضافة الهيليوم لإبقاء END ضمن حدك $limit.';
  }

  @override
  String get gasCalculators_bestMix_idealLabel => 'النسبة المثالية';

  @override
  String get gasCalculators_bestMix_marginLabel => 'الهامش تحت MOD';

  @override
  String gasCalculators_bestMix_modLabel(Object ppO2) {
    return 'MOD عند ppO2 $ppO2';
  }

  @override
  String get gasCalculators_bestMix_nearestStandard =>
      'أقرب خليط قياسي يغطي هذا العمق';

  @override
  String get gasCalculators_bestMix_recommendedMix => 'الخليط الموصى به';

  @override
  String get gasCalculators_bestMix_withoutHelium => 'بدون هيليوم';

  @override
  String get gasCalculators_planningCaveat =>
      'تقدير تخطيطي. يفترض صعودًا مباشرًا. تحقق منه وفق تدريبك وأضف هامشًا للظروف.';

  @override
  String gasCalculators_rockBottom_solveGas(Object depth, Object unit) {
    return 'غاز حل المشكلة عند $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_solveTime => 'زمن حل المشكلة';

  @override
  String get gasCalculators_rockBottom_solveTimeHint =>
      'الوقت المستغرق في العمق لحل الطارئ قبل بدء الصعود.';

  @override
  String o2Toxicity_addedThisDive(Object value) {
    return '+$value في هذه الغطسة';
  }

  @override
  String o2Toxicity_cnsProgressSemantics(Object percent) {
    return 'تقدم CNS $percent بالمئة';
  }

  @override
  String get o2Toxicity_daily => 'يومي';

  @override
  String o2Toxicity_otuSemantics(
    Object label,
    Object value,
    Object limit,
    Object percent,
  ) {
    return '$label: $value من $limit OTU، $percent بالمئة';
  }

  @override
  String o2Toxicity_otuValueSemantics(Object label, Object value) {
    return '$label: $value OTU';
  }

  @override
  String o2Toxicity_prior(Object value) {
    return 'سابق: $value OTU';
  }

  @override
  String o2Toxicity_start(Object value) {
    return 'البداية: $value OTU';
  }

  @override
  String get o2Toxicity_thisDive => 'هذه الغطسة';

  @override
  String get o2Toxicity_weekly => 'أسبوعي';

  @override
  String trips_story_dayLabel(int number) {
    return 'اليوم $number';
  }

  @override
  String get trips_story_surfaceDay => 'يوم سطح';

  @override
  String get trips_story_today => 'اليوم';

  @override
  String trips_story_dayOfTrip(int current, int total) {
    return 'اليوم $current من $total';
  }

  @override
  String trips_story_daysUntil(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days أيام حتى المغادرة',
      one: 'يوم واحد حتى المغادرة',
    );
    return '$_temp0';
  }

  @override
  String trips_story_checklistProgress(int done, int total) {
    return 'اكتمل $done من $total';
  }

  @override
  String get trips_story_generateItinerary => 'إنشاء خط سير';

  @override
  String get trips_story_openGallery => 'فتح صور الرحلة';

  @override
  String trips_story_generateItineraryError(String error) {
    return 'تعذّر إنشاء برنامج الرحلة: $error';
  }

  @override
  String get trips_dayType_diveDay => 'يوم غوص';

  @override
  String get trips_dayType_seaDay => 'يوم بحري';

  @override
  String get trips_dayType_portDay => 'يوم في الميناء';

  @override
  String get trips_dayType_embark => 'الصعود';

  @override
  String get trips_dayType_disembark => 'النزول';

  @override
  String get trips_story_planned => 'مخطط';

  @override
  String get trips_story_empty_title => 'لا توجد غطسات أو خط سير بعد';

  @override
  String get trips_story_empty_subtitle =>
      'أضف غطسات إلى هذه الرحلة أو خطط أيامها لرؤية القصة.';

  @override
  String trips_story_history_dives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غطسات سابقة هنا',
      one: 'غطسة سابقة واحدة هنا',
    );
    return '$_temp0';
  }

  @override
  String trips_story_history_avgTemp(String value) {
    return 'متوسط $value';
  }

  @override
  String trips_story_history_avgDepth(String value) {
    return 'متوسط العمق $value';
  }

  @override
  String get trips_story_rhythm_semantics => 'أوقات الغطس في هذا اليوم';

  @override
  String get trips_story_map_semantics =>
      'خريطة الرحلة. مواقع اليوم المعروض مميزة.';

  @override
  String get diveLog_bulkEdit_groupRebreather => 'وضع الغوص وجهاز التنفس';

  @override
  String get diveLog_bulkEdit_fieldSetpointLow => 'النقطة المحددة المنخفضة';

  @override
  String get diveLog_bulkEdit_fieldSetpointHigh => 'النقطة المحددة العالية';

  @override
  String get diveLog_bulkEdit_fieldSetpointDeco =>
      'النقطة المحددة لإزالة الضغط';

  @override
  String get diveLog_bulkEdit_fieldScrubberType => 'نوع الفلتر';

  @override
  String get diveLog_bulkEdit_fieldScrubberDuration => 'مدة الفلتر';

  @override
  String get diveLog_bulkEdit_contradiction =>
      'وضع الدائرة المفتوحة لا يدعم إعدادات جهاز التنفس. عطّل تلك الحقول أو غيّر الوضع.';

  @override
  String diveLog_bulkEdit_appBarTitle(int count) {
    return 'تعديل $count غطسات';
  }

  @override
  String get diveLog_bulkEdit_groupLogistics => 'اللوجستيات';

  @override
  String get diveLog_bulkEdit_groupWeather => 'الطقس';

  @override
  String get diveLog_bulkEdit_groupCollections => 'الوسوم والمعدات والحياة';

  @override
  String get diveLog_bulkEdit_fieldFavorite => 'مفضّل';

  @override
  String get diveLog_bulkEdit_fieldMyRole => 'دوري';

  @override
  String get diveLog_bulkEdit_buddyRoleMixed => 'متنوع';

  @override
  String get diveLog_bulkEdit_collectionWeights => 'الأوزان';

  @override
  String get diveLog_bulkEdit_collectionTanks => 'الأسطوانات';

  @override
  String get diveLog_bulkEdit_notesSet => 'تعيين';

  @override
  String get diveLog_bulkEdit_notesAppend => 'إلحاق';

  @override
  String get diveLog_bulkEdit_modeAdd => 'إضافة';

  @override
  String get diveLog_bulkEdit_modeRemove => 'إزالة';

  @override
  String get diveLog_bulkEdit_modeReplace => 'استبدال';

  @override
  String get diveLog_bulkEdit_modeUpdate => 'تحديث';

  @override
  String get diveLog_bulkEdit_tankOnlyIfEmpty =>
      'الغطسات التي لا تحتوي على أسطوانة فقط';

  @override
  String get diveLog_bulkEdit_tankSpecsHint =>
      'اختر السمات التي سيتم استبدالها في الأسطوانات الموجودة بالفعل في هذه الغطسات. لا يتغير ضغط البداية والنهاية أبدًا.';

  @override
  String get diveLog_bulkEdit_tankSpecsNoFields =>
      'اختر سمة واحدة على الأقل للأسطوانة لتحديثها.';

  @override
  String get diveLog_bulkEdit_tankFieldPreset => 'إعداد مسبق';

  @override
  String get diveLog_bulkEdit_tankFieldRole => 'الدور';

  @override
  String get diveLog_bulkEdit_tankFieldVolume => 'الحجم';

  @override
  String get diveLog_bulkEdit_tankFieldWorkingPressure => 'ضغط التشغيل';

  @override
  String get diveLog_bulkEdit_tankFieldMaterial => 'المادة';

  @override
  String get diveLog_bulkEdit_tankFieldGasMix => 'خليط الغاز';

  @override
  String get diveLog_bulkEdit_tankFieldName => 'الاسم';

  @override
  String diveLog_bulkEdit_tankSpecsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غطسات محددة لا تحتوي على أسطوانات وسيتم تخطيها.',
      one: 'غطسة واحدة محددة لا تحتوي على أسطوانات وسيتم تخطيها.',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_bulkEdit_confirmTitle => 'تطبيق التغييرات؟';

  @override
  String get diveLog_bulkEdit_confirmApply => 'تطبيق';

  @override
  String get diveLog_bulkEdit_nothingSelected =>
      'فعّل حقلاً واحداً على الأقل لتطبيق التغييرات.';

  @override
  String diveLog_bulkEdit_applied(int count) {
    return 'تم تحديث $count غطسة';
  }

  @override
  String get settings_cloudSync_error_icloudSignedOut =>
      'iCloud غير متوفر. يُرجى تسجيل الدخول إلى iCloud من إعدادات جهازك.';

  @override
  String get settings_cloudSync_error_icloudUnknown =>
      'تعذّر الوصول إلى iCloud. حاول مرة أخرى.';

  @override
  String get settings_cloudSync_error_icloudUnsupported =>
      'مزامنة iCloud غير متوفرة في هذا الإصدار من Submersion. استخدم مزامنة S3 أو نسخة App Store.';

  @override
  String get settings_cloudSync_provider_icloud_unsupportedSubtitle =>
      'غير متوفر في هذا الإصدار — استخدم S3 أو نسخة App Store';

  @override
  String get settings_cloudSync_encryption_title => 'التشفير من طرف إلى طرف';

  @override
  String get settings_cloudSync_encryption_subtitleOff =>
      'تشفير جميع بيانات المزامنة والنسخ الاحتياطية السحابية قبل الرفع';

  @override
  String get settings_cloudSync_encryption_subtitleNeedsProvider =>
      'اختر مزود التخزين السحابي أولاً';

  @override
  String get settings_cloudSync_encryption_statusOff => 'التشفير معطّل';

  @override
  String get settings_cloudSync_encryption_statusOn => 'التشفير مفعّل';

  @override
  String get settings_cloudSync_encryption_statusOnSubtitle =>
      'يتم تشفير بيانات المزامنة والنسخ الاحتياطية السحابية قبل الرفع';

  @override
  String get settings_cloudSync_encryption_statusLocked =>
      'مشفّر — مطلوب عبارة المرور';

  @override
  String get settings_cloudSync_encryption_statusLockedSubtitle =>
      'أدخل عبارة المرور للمزامنة على هذا الجهاز';

  @override
  String get settings_cloudSync_encryption_enable => 'تفعيل التشفير';

  @override
  String get settings_cloudSync_encryption_enterPassphrase =>
      'إدخال عبارة المرور';

  @override
  String get settings_cloudSync_encryption_passphrase => 'عبارة المرور';

  @override
  String get settings_cloudSync_encryption_passphraseConfirm =>
      'تأكيد عبارة المرور';

  @override
  String get settings_cloudSync_encryption_passphraseMismatch =>
      'عبارتا المرور غير متطابقتين';

  @override
  String get settings_cloudSync_encryption_passphraseTooShort =>
      'استخدم 8 أحرف على الأقل';

  @override
  String get settings_cloudSync_encryption_wrongPassphrase =>
      'عبارة مرور أو رمز استرداد غير صحيح';

  @override
  String get settings_cloudSync_encryption_warnUpdateDevices =>
      'يجب تحديث جميع الأجهزة الأخرى إلى أحدث إصدار من التطبيق وستعيد تنزيل المكتبة.';

  @override
  String get settings_cloudSync_encryption_warnLoss =>
      'إذا فقدت عبارة المرور ورمز الاسترداد معًا، فلا يمكن استرداد البيانات في السحابة. بيانات أجهزتك ليست في خطر أبدًا.';

  @override
  String get settings_cloudSync_encryption_deletePlaintextBackups =>
      'حذف النسخ الاحتياطية السحابية غير المشفرة الموجودة';

  @override
  String get settings_cloudSync_encryption_recoveryTitle => 'رمز الاسترداد';

  @override
  String get settings_cloudSync_encryption_recoveryExplain =>
      'دوّن هذا الرمز واحفظه في مكان آمن. إنه الطريقة الوحيدة للعودة إذا نسيت عبارة المرور.';

  @override
  String get settings_cloudSync_encryption_recoverySavedConfirm =>
      'لقد حفظت رمز الاسترداد الخاص بي';

  @override
  String get settings_cloudSync_encryption_changePassphrase =>
      'تغيير عبارة المرور';

  @override
  String get settings_cloudSync_encryption_currentPassphrase =>
      'عبارة المرور الحالية';

  @override
  String get settings_cloudSync_encryption_newPassphrase =>
      'عبارة المرور الجديدة';

  @override
  String get settings_cloudSync_encryption_regenerateRecovery =>
      'إنشاء رمز استرداد جديد';

  @override
  String get settings_cloudSync_encryption_regenerateRecoveryWarn =>
      'يتوقف رمز الاسترداد القديم عن العمل فورًا.';

  @override
  String get settings_cloudSync_encryption_disable => 'إيقاف التشفير';

  @override
  String get settings_cloudSync_encryption_disableWarn =>
      'سيُعاد رفع المكتبة دون تشفير وستعيد الأجهزة الأخرى تنزيلها. تظل النسخ الاحتياطية المشفرة الموجودة قابلة للاستعادة بعبارة المرور.';

  @override
  String get settings_cloudSync_encryption_unlockTitle =>
      'أدخل عبارة مرور التشفير';

  @override
  String get settings_cloudSync_encryption_unlockHint =>
      'عبارة المرور أو رمز الاسترداد';

  @override
  String get settings_cloudSync_encryption_unlock => 'فتح';

  @override
  String get settings_cloudSync_encryption_continue => 'متابعة';

  @override
  String get settings_cloudSync_encryption_done => 'تم';

  @override
  String get settings_cloudSync_encryption_cancel => 'إلغاء';

  @override
  String get settings_backupEncryption_title => 'تشفير النسخ الاحتياطي';

  @override
  String get settings_backupEncryption_subtitleOff =>
      'احمِ نسخك الاحتياطية بكلمة مرور';

  @override
  String get settings_backupEncryption_subtitleOn =>
      'النسخ الاحتياطية مشفّرة بكلمة مرورك';

  @override
  String get settings_backupEncryption_enable => 'تشفير النسخ الاحتياطية';

  @override
  String get settings_backupEncryption_turnOff => 'إيقاف التشفير';

  @override
  String get settings_backupEncryption_turnOffTitle =>
      'إيقاف تشفير النسخ الاحتياطي؟';

  @override
  String get settings_backupEncryption_turnOffBody =>
      'لن يتم تشفير النسخ الاحتياطية الجديدة بعد الآن. لا تزال النسخ الاحتياطية المشفّرة الحالية بحاجة إلى كلمة مرورك للاستعادة.';

  @override
  String get settings_backupEncryption_changePassword => 'تغيير كلمة المرور';

  @override
  String get settings_backupEncryption_regenerateRecovery =>
      'إعادة إنشاء رمز الاسترداد';

  @override
  String get settings_backupEncryption_password => 'كلمة المرور';

  @override
  String get settings_backupEncryption_passwordConfirm => 'تأكيد كلمة المرور';

  @override
  String get settings_backupEncryption_passwordTooShort =>
      'استخدم 8 أحرف على الأقل';

  @override
  String get settings_backupEncryption_passwordMismatch =>
      'كلمتا المرور غير متطابقتين';

  @override
  String get settings_backupEncryption_currentPassword => 'كلمة المرور الحالية';

  @override
  String get settings_backupEncryption_newPassword => 'كلمة المرور الجديدة';

  @override
  String get settings_backupEncryption_changePasswordWarn =>
      'على جهاز آخر، تُفتح كل نسخة احتياطية باستخدام كلمة المرور أو رمز الاسترداد الذي كان نشطًا عند إنشائها.';

  @override
  String get settings_backupEncryption_warnLoss =>
      'إذا نسيت كلمة المرور وفقدت رمز الاسترداد، فلن يمكن استعادة النسخ الاحتياطية المشفّرة.';

  @override
  String get settings_backupEncryption_recoveryTitle =>
      'رمز الاسترداد الخاص بك';

  @override
  String get settings_backupEncryption_recoveryExplain =>
      'احفظ هذا الرمز في مكان آمن. يمكنه فتح نسخك الاحتياطية إذا نسيت كلمة مرورك.';

  @override
  String get settings_backupEncryption_recoverySavedConfirm =>
      'لقد حفظت رمز الاسترداد الخاص بي';

  @override
  String get settings_backupEncryption_unlockTitle =>
      'أدخل كلمة مرور النسخ الاحتياطي';

  @override
  String get settings_backupEncryption_unlockHint =>
      'أدخل كلمة مرور النسخ الاحتياطي أو رمز الاسترداد';

  @override
  String get settings_backupEncryption_restoreUnlockTitle =>
      'فتح النسخة الاحتياطية المشفّرة';

  @override
  String get settings_backupEncryption_restoreUnlockHint =>
      'أدخل كلمة المرور أو رمز الاسترداد لهذه النسخة الاحتياطية';

  @override
  String get settings_backupEncryption_continue => 'متابعة';

  @override
  String get settings_backupEncryption_cancel => 'إلغاء';

  @override
  String get settings_backupEncryption_done => 'تم';

  @override
  String get settings_backupEncryption_reencryptTitle =>
      'تشفير النسخ الاحتياطية الحالية؟';

  @override
  String get settings_backupEncryption_reencryptBody =>
      'لا تزال نسخك الاحتياطية الحالية غير مشفّرة. هل تريد إعادة تشفيرها الآن بكلمة مرورك الجديدة؟';

  @override
  String get settings_backupEncryption_reencryptNow => 'إعادة التشفير الآن';

  @override
  String get settings_backupEncryption_reencryptNotNow => 'ليس الآن';

  @override
  String settings_backupEncryption_reencryptPartial(int done, int failed) {
    return 'تمت إعادة تشفير $done نسخة احتياطية؛ تعذّر تشفير $failed وما زالت غير محمية';
  }

  @override
  String settings_backupEncryption_reencryptDone(int count) {
    return 'تمت إعادة تشفير $count نسخة احتياطية';
  }

  @override
  String get settings_backupEncryption_wrongPassword =>
      'كلمة المرور أو رمز الاسترداد غير صحيح';

  @override
  String settings_cloudSync_replace_globalBanner(String deviceName) {
    return 'المزامنة متوقفة مؤقتًا — تم استبدال المكتبة من نسخة احتياطية على \"$deviceName\".';
  }

  @override
  String get settings_cloudSync_postRestore_syncing =>
      'تتم مزامنة مكتبتك المستعادة مع السحابة…';

  @override
  String get settings_cloudSync_postRestore_synced =>
      'تمت مزامنة المكتبة المستعادة.';

  @override
  String get settings_cloudSync_replace_reviewAction => 'مراجعة';

  @override
  String get accessibility_dialog_keyboardShortcutsTitle =>
      'اختصارات لوحة المفاتيح';

  @override
  String get accessibility_keyLabel_backspace => 'Backspace';

  @override
  String get accessibility_keyLabel_delete => 'Delete';

  @override
  String get accessibility_keyLabel_down => 'أسفل';

  @override
  String get accessibility_keyLabel_enter => 'Enter';

  @override
  String get accessibility_keyLabel_esc => 'Esc';

  @override
  String get accessibility_keyLabel_left => 'يسار';

  @override
  String get accessibility_keyLabel_right => 'يمين';

  @override
  String get accessibility_keyLabel_up => 'أعلى';

  @override
  String accessibility_label_chartSummary(
    Object chartType,
    Object description,
  ) {
    return 'مخطط $chartType. $description';
  }

  @override
  String get accessibility_label_createNewItem => 'إنشاء عنصر جديد';

  @override
  String get accessibility_label_hideList => 'إخفاء القائمة';

  @override
  String get accessibility_label_hideMapView => 'إخفاء عرض الخريطة';

  @override
  String accessibility_label_listPane(Object title) {
    return 'لوحة قائمة $title';
  }

  @override
  String accessibility_label_mapPane(Object title) {
    return 'لوحة خريطة $title';
  }

  @override
  String accessibility_label_mapViewTitle(Object title) {
    return 'عرض خريطة $title';
  }

  @override
  String get accessibility_label_resizeMasterPane =>
      'تغيير حجم اللوحة الرئيسية';

  @override
  String get accessibility_label_sharedWithAllProfiles =>
      'مشترك مع جميع ملفات الغوص';

  @override
  String get accessibility_label_showList => 'عرض القائمة';

  @override
  String get accessibility_label_showMapView => 'عرض الخريطة';

  @override
  String get accessibility_label_viewDetails => 'عرض التفاصيل';

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
  String get accessibility_shortcutCategory_editing => 'تحرير';

  @override
  String get accessibility_shortcutCategory_general => 'عام';

  @override
  String get accessibility_shortcutCategory_help => 'مساعدة';

  @override
  String get accessibility_shortcutCategory_navigation => 'تنقل';

  @override
  String get accessibility_shortcutCategory_search => 'بحث';

  @override
  String get accessibility_shortcut_closeCancel => 'إغلاق / إلغاء';

  @override
  String get accessibility_shortcut_goBack => 'رجوع';

  @override
  String get accessibility_shortcut_goToDives => 'الانتقال إلى الغوصات';

  @override
  String get accessibility_shortcut_goToEquipment => 'الانتقال إلى المعدات';

  @override
  String get accessibility_shortcut_goToSettings => 'الانتقال إلى الإعدادات';

  @override
  String get accessibility_shortcut_goToSites => 'الانتقال إلى المواقع';

  @override
  String get accessibility_shortcut_goToStatistics => 'الانتقال إلى الإحصائيات';

  @override
  String get accessibility_shortcut_keyboardShortcuts =>
      'اختصارات لوحة المفاتيح';

  @override
  String get accessibility_shortcut_newDive => 'غوصة جديدة';

  @override
  String get accessibility_shortcut_openSettings => 'فتح الإعدادات';

  @override
  String get accessibility_shortcut_searchDives => 'البحث في الغوصات';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return 'ترتيب حسب $displayName، محدد حالياً';
  }

  @override
  String accessibility_sort_unselectedLabel(Object displayName) {
    return 'ترتيب حسب $displayName';
  }

  @override
  String get backup_appBar_title => 'النسخ الاحتياطي والاستعادة';

  @override
  String get backup_backingUp => 'جاري النسخ الاحتياطي...';

  @override
  String get backup_backupNow => 'نسخ احتياطي الآن';

  @override
  String get backup_cloud_enabled => 'نسخ احتياطي سحابي';

  @override
  String get backup_cloud_enabled_subtitle =>
      'رفع النسخ الاحتياطية إلى التخزين السحابي';

  @override
  String get backup_delete_dialog_cancel => 'إلغاء';

  @override
  String get backup_delete_dialog_content =>
      'سيتم حذف هذه النسخة الاحتياطية نهائياً. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get backup_delete_dialog_delete => 'حذف';

  @override
  String get backup_delete_dialog_title => 'حذف النسخة الاحتياطية';

  @override
  String get backup_export_bottomSheet_title => 'تصدير النسخة الاحتياطية';

  @override
  String get backup_export_saveToFile => 'حفظ في ملف';

  @override
  String get backup_export_saveToFile_subtitle =>
      'اختر مكان حفظ ملف النسخة الاحتياطية';

  @override
  String get backup_export_share => 'مشاركة';

  @override
  String get backup_export_share_subtitle =>
      'إرسال عبر AirDrop أو البريد الإلكتروني أو تطبيقات أخرى';

  @override
  String get backup_export_subtitle => 'حفظ بيانات الغوص في ملف';

  @override
  String get backup_export_success => 'تم تصدير النسخة الاحتياطية بنجاح';

  @override
  String get backup_export_title => 'تصدير النسخة الاحتياطية';

  @override
  String get backup_frequency_daily => 'يومي';

  @override
  String get backup_frequency_monthly => 'شهري';

  @override
  String get backup_frequency_weekly => 'أسبوعي';

  @override
  String get backup_history_action_delete => 'حذف';

  @override
  String get backup_history_action_restore => 'استعادة';

  @override
  String get backup_history_empty => 'لا توجد نسخ احتياطية';

  @override
  String backup_history_error(Object error) {
    return 'فشل في تحميل السجل: $error';
  }

  @override
  String get backup_history_pinAction_pin => 'تثبيت النسخة الاحتياطية';

  @override
  String get backup_history_pinAction_unpin => 'إلغاء تثبيت النسخة الاحتياطية';

  @override
  String get backup_history_pinError => 'تعذر تحديث حالة التثبيت.';

  @override
  String backup_history_preMigrationSubtitle(String size) {
    return 'نسخة احتياطية قبل الترحيل - $size';
  }

  @override
  String get backup_import_invalidFile =>
      'لا يبدو أن هذا الملف نسخة احتياطية صالحة من Submersion';

  @override
  String get backup_import_subtitle => 'استيراد نسخة احتياطية من أي مكان';

  @override
  String get backup_import_title => 'الاستعادة من ملف';

  @override
  String get backup_import_validating =>
      'جارٍ التحقق من ملف النسخة الاحتياطية...';

  @override
  String get backup_location_change => 'تغيير';

  @override
  String get backup_location_default => 'الموقع الافتراضي';

  @override
  String get backup_location_title => 'موقع النسخة الاحتياطية';

  @override
  String get backup_replaceConfirm_confirm => 'استبدال في كل مكان';

  @override
  String get backup_replaceConfirm_content =>
      'سيتم استبدال المكتبة على جميع الأجهزة المتزامنة بهذه النسخة الاحتياطية. يقوم كل جهاز أولاً بإنشاء نسخة احتياطية آمنة من بياناته الحالية. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get backup_replaceConfirm_title => 'استبدال المكتبة في كل مكان؟';

  @override
  String get backup_restore_dialog_cancel => 'إلغاء';

  @override
  String get backup_restore_dialog_modeMerge_subtitle =>
      'الاستعادة على هذا الجهاز. ستدمج المزامنة التالية البيانات المستعادة مع مكتبة السحابة.';

  @override
  String get backup_restore_dialog_modeMerge_title =>
      'الدمج عند المزامنة التالية';

  @override
  String get backup_restore_dialog_modeReplace_subtitle =>
      'تصبح النسخة الاحتياطية هي المكتبة على هذا الجهاز وفي السحابة وعلى كل جهاز متزامن.';

  @override
  String get backup_restore_dialog_modeReplace_title => 'استبدال في كل مكان';

  @override
  String get backup_restore_dialog_restore => 'استعادة';

  @override
  String get backup_restore_dialog_restoreReplace =>
      'استعادة واستبدال في كل مكان';

  @override
  String get backup_restore_dialog_safetyNote =>
      'سيتم إنشاء نسخة احتياطية آمنة من بياناتك الحالية تلقائياً قبل الاستعادة.';

  @override
  String get backup_restore_dialog_title => 'استعادة النسخة الاحتياطية';

  @override
  String get backup_restore_dialog_warning =>
      'سيؤدي هذا إلى استبدال جميع البيانات الحالية ببيانات النسخة الاحتياطية. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String backup_restore_safetyReview_progress(int done, int total) {
    return 'تم تحليل $done من $total غطسة';
  }

  @override
  String get backup_restore_safetyReview_skip => 'تخطي';

  @override
  String get backup_restore_safetyReview_title => 'جارٍ تشغيل مراجعة السلامة';

  @override
  String get backup_restoreComplete_continue => 'متابعة';

  @override
  String get backup_restoreComplete_description =>
      'تمت استعادة بياناتك بنجاح. اضغط على متابعة لإعادة تحميل التطبيق ببياناتك المستعادة.';

  @override
  String get backup_restoreComplete_title => 'اكتملت الاستعادة';

  @override
  String get backup_schedule_enabled => 'نسخ احتياطي تلقائي';

  @override
  String get backup_schedule_enabled_subtitle =>
      'نسخ البيانات احتياطياً وفقاً لجدول زمني';

  @override
  String get backup_schedule_frequency => 'التكرار';

  @override
  String get backup_schedule_retention => 'الاحتفاظ بالنسخ';

  @override
  String get backup_schedule_retention_subtitle =>
      'تتم إزالة النسخ الاحتياطية القديمة تلقائياً';

  @override
  String get backup_section_auto => 'النسخ الاحتياطي التلقائي';

  @override
  String get backup_section_cloud => 'السحابة';

  @override
  String get backup_section_history => 'السجل';

  @override
  String get backup_section_schedule => 'الجدولة';

  @override
  String get backup_status_disabled => 'النسخ الاحتياطي التلقائي معطل';

  @override
  String backup_status_lastBackup(String time) {
    return 'آخر نسخة: $time';
  }

  @override
  String get backup_status_neverBackedUp => 'لم يتم النسخ الاحتياطي مطلقاً';

  @override
  String get backup_status_noBackupsYet =>
      'أنشئ أول نسخة احتياطية لحماية بياناتك';

  @override
  String get backup_status_overdue => 'النسخ الاحتياطي متأخر';

  @override
  String get backup_status_upToDate => 'النسخ الاحتياطية محدثة';

  @override
  String backup_time_daysAgo(int count) {
    return 'منذ $count يوم';
  }

  @override
  String backup_time_hoursAgo(int count) {
    return 'منذ $count ساعة';
  }

  @override
  String get backup_time_justNow => 'الآن';

  @override
  String backup_time_minutesAgo(int count) {
    return 'منذ $count دقيقة';
  }

  @override
  String get buddies_action_add => 'إضافة رفيق';

  @override
  String get buddies_action_addCertification => 'إضافة اعتماد';

  @override
  String get buddies_action_addFirst => 'أضف أول رفيق غوص';

  @override
  String get buddies_action_addTooltip => 'إضافة رفيق غوص جديد';

  @override
  String get buddies_action_clearSearch => 'مسح البحث';

  @override
  String get buddies_action_edit => 'تعديل الرفيق';

  @override
  String get buddies_action_importFromContacts => 'استيراد من جهات الاتصال';

  @override
  String get buddies_action_moreOptions => 'المزيد من الخيارات';

  @override
  String get buddies_action_retry => 'إعادة المحاولة';

  @override
  String get buddies_action_search => 'البحث عن الرفاق';

  @override
  String get buddies_action_shareDives => 'مشاركة الغطسات';

  @override
  String get buddies_action_sort => 'ترتيب';

  @override
  String get buddies_action_sortTitle => 'ترتيب الرفاق';

  @override
  String get buddies_action_update => 'تحديث الرفيق';

  @override
  String buddies_action_viewAll(Object count) {
    return 'عرض الكل ($count)';
  }

  @override
  String buddies_detail_error(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get buddies_detail_noDivesTogether => 'لا يوجد غطسات مشتركة بعد';

  @override
  String get buddies_detail_notFound => 'الرفيق غير موجود';

  @override
  String buddies_dialog_deleteMessage(Object name) {
    return 'هل أنت متأكد من حذف $name؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get buddies_dialog_deleteTitle => 'حذف الرفيق؟';

  @override
  String get buddies_dialog_discard => 'تجاهل';

  @override
  String get buddies_dialog_discardMessage =>
      'لديك تغييرات غير محفوظة. هل تريد تجاهلها؟';

  @override
  String get buddies_dialog_discardTitle => 'تجاهل التغييرات؟';

  @override
  String get buddies_dialog_keepEditing => 'متابعة التعديل';

  @override
  String get buddies_empty_subtitle => 'أضف أول رفيق غوص للبدء';

  @override
  String get buddies_empty_title => 'لا يوجد رفاق غوص بعد';

  @override
  String buddies_error_loading(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get buddies_error_unableToLoadDives => 'تعذر تحميل الغطسات';

  @override
  String get buddies_error_unableToLoadStats => 'تعذر تحميل الإحصائيات';

  @override
  String get buddies_field_certificationAgency => 'جهة الاعتماد';

  @override
  String get buddies_field_certificationLevel => 'مستوى الاعتماد';

  @override
  String get buddies_field_email => 'البريد الإلكتروني';

  @override
  String get buddies_field_emailHint => 'email@example.com';

  @override
  String get buddies_field_nameHint => 'أدخل اسم الرفيق';

  @override
  String get buddies_field_nameRequired => 'الاسم *';

  @override
  String get buddies_field_notes => 'ملاحظات';

  @override
  String get buddies_field_notesHint => 'أضف ملاحظات عن هذا الرفيق...';

  @override
  String get buddies_field_phone => 'الهاتف';

  @override
  String get buddies_field_phoneHint => '+1 (555) 123-4567';

  @override
  String get buddies_label_agency => 'الجهة';

  @override
  String buddies_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غطسة',
      one: 'غطسة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get buddies_label_level => 'المستوى';

  @override
  String get buddies_label_notSpecified => 'غير محدد';

  @override
  String get buddies_label_photoComingSoon => 'دعم الصور قادم في الإصدار 2.0';

  @override
  String get buddies_message_added => 'تمت إضافة الرفيق بنجاح';

  @override
  String get buddies_message_contactImportUnavailable =>
      'استيراد جهات الاتصال غير متوفر على هذا النظام';

  @override
  String get buddies_message_contactLoadFailed => 'فشل تحميل جهات الاتصال';

  @override
  String get buddies_message_contactPermissionRequired =>
      'يجب الحصول على إذن جهات الاتصال لاستيراد الرفاق';

  @override
  String get buddies_message_deleted => 'تم حذف الرفيق';

  @override
  String buddies_message_errorImportingContact(Object error) {
    return 'خطأ في استيراد جهة الاتصال: $error';
  }

  @override
  String buddies_message_errorLoading(Object error) {
    return 'خطأ في تحميل الرفيق: $error';
  }

  @override
  String buddies_message_errorSaving(Object error) {
    return 'خطأ في حفظ الرفيق: $error';
  }

  @override
  String buddies_message_exportFailed(Object error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get buddies_message_noDivesFound => 'لم يتم العثور على غطسات للتصدير';

  @override
  String get buddies_message_noDivesToShare =>
      'لا توجد غطسات لمشاركتها مع هذا الرفيق';

  @override
  String get buddies_message_preparingExport => 'جارٍ تحضير التصدير...';

  @override
  String get buddies_message_updated => 'تم تحديث الرفيق بنجاح';

  @override
  String get buddies_picker_add => 'إضافة';

  @override
  String get buddies_picker_addCustomRole => 'إضافة دور مخصص...';

  @override
  String get buddies_picker_addNew => 'إضافة رفيق جديد';

  @override
  String get buddies_picker_done => 'تم';

  @override
  String get buddies_picker_me => 'أنا';

  @override
  String get buddies_picker_noBuddiesFound => 'لم يتم العثور على رفاق';

  @override
  String get buddies_picker_noBuddiesYet => 'لا يوجد رفاق بعد';

  @override
  String get buddies_picker_noRole => 'بدون دور';

  @override
  String get buddies_picker_noneSelected => 'لم يتم تحديد رفاق';

  @override
  String get buddies_picker_searchHint => 'البحث عن الرفاق...';

  @override
  String get buddies_picker_selectBuddies => 'اختيار الرفاق';

  @override
  String get buddies_picker_selectMyRole => 'اختيار دوري';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'اختر دور $name';
  }

  @override
  String get buddies_picker_setMyRole => 'تحديد دوري';

  @override
  String get buddies_picker_tapToAdd => 'اضغط على \'إضافة\' لاختيار رفاق الغوص';

  @override
  String get buddies_search_hint =>
      'البحث بالاسم أو البريد الإلكتروني أو الهاتف';

  @override
  String buddies_search_noResults(Object query) {
    return 'لم يتم العثور على رفاق لـ \"$query\"';
  }

  @override
  String get buddies_section_certification => 'الاعتماد';

  @override
  String get buddies_section_certifications => 'الاعتمادات';

  @override
  String get buddies_certifications_empty => 'لا توجد اعتمادات';

  @override
  String get buddies_section_contact => 'الاتصال';

  @override
  String get buddies_section_diveStatistics => 'إحصائيات الغوص';

  @override
  String get buddies_section_notes => 'ملاحظات';

  @override
  String get buddies_section_sharedDives => 'الغطسات المشتركة';

  @override
  String get buddies_stat_divesTogether => 'الغطسات معاً';

  @override
  String get buddies_stat_favoriteSite => 'الموقع المفضل';

  @override
  String get buddies_stat_firstDive => 'الغطسة الأولى';

  @override
  String get buddies_stat_lastDive => 'آخر غطسة';

  @override
  String get buddies_summary_overview => 'نظرة عامة';

  @override
  String get buddies_summary_quickActions => 'إجراءات سريعة';

  @override
  String get buddies_summary_recentBuddies => 'الرفاق الأخيرون';

  @override
  String get buddies_summary_selectHint =>
      'اختر رفيقاً من القائمة لعرض التفاصيل';

  @override
  String get buddies_summary_title => 'رفاق الغوص';

  @override
  String get buddies_summary_totalBuddies => 'إجمالي الرفاق';

  @override
  String get buddies_summary_withCertification => 'مع الاعتماد';

  @override
  String get buddies_title => 'الرفاق';

  @override
  String get buddies_title_add => 'إضافة رفيق';

  @override
  String get buddies_title_edit => 'تعديل الرفيق';

  @override
  String get buddies_title_singular => 'رفيق';

  @override
  String get buddies_validation_emailInvalid =>
      'الرجاء إدخال بريد إلكتروني صحيح';

  @override
  String get buddies_validation_nameRequired => 'الرجاء إدخال الاسم';

  @override
  String get buddies_list_selection_closeTooltip => 'إغلاق التحديد';

  @override
  String buddies_list_selection_count(int count) {
    return '$count مُحدد';
  }

  @override
  String get buddies_list_selection_selectAllTooltip => 'تحديد الكل';

  @override
  String get buddies_list_selection_deselectAllTooltip => 'إلغاء تحديد الكل';

  @override
  String get buddies_list_selection_mergeTooltip => 'دمج المحددين';

  @override
  String get buddies_list_selection_deleteTooltip => 'حذف المحددين';

  @override
  String buddies_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'رفاق',
      one: 'رفيق',
    );
    return 'تم دمج $count $_temp0';
  }

  @override
  String get buddies_list_merge_undo => 'تراجع';

  @override
  String get buddies_list_merge_restored => 'تم التراجع عن الدمج';

  @override
  String get buddies_list_bulkDelete_title => 'حذف الرفاق';

  @override
  String buddies_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'رفاق',
      one: 'رفيق',
    );
    return 'هل أنت متأكد من حذف $count $_temp0؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get buddies_list_bulkDelete_cancel => 'إلغاء';

  @override
  String get buddies_list_bulkDelete_confirm => 'حذف';

  @override
  String buddies_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'رفاق',
      one: 'رفيق',
    );
    return 'تم حذف $count $_temp0';
  }

  @override
  String get buddies_edit_merge_title => 'دمج الرفاق';

  @override
  String get buddies_edit_merge_fieldSourceCycleTooltip =>
      'استخدام القيمة من الرفيق المحدد التالي';

  @override
  String buddies_edit_merge_fieldSourceLabel(
    String buddyName,
    int current,
    int total,
  ) {
    return 'من $buddyName ($current/$total)';
  }

  @override
  String get buddies_edit_merge_confirmTitle => 'دمج الرفاق';

  @override
  String buddies_edit_merge_confirmBody(int count) {
    return 'سيتم دمج $count من الرفاق في رفيق واحد. ستُجمع ارتباطات الغوص تحت الرفيق الباقي. سيتم حذف الرفاق الآخرين.';
  }

  @override
  String get buddies_edit_merge_loadingErrorTitle => 'دمج الرفاق';

  @override
  String buddies_edit_merge_loadingErrorBody(String error) {
    return 'فشل في تحميل الرفاق: $error';
  }

  @override
  String get buddies_edit_merge_notEnoughTitle => 'دمج الرفاق';

  @override
  String get buddies_edit_merge_notEnoughBody =>
      'لا يوجد عدد كافٍ من الرفاق للدمج.';

  @override
  String get buddies_instructorPicker_label => 'المدرب من قائمة الرفاق';

  @override
  String get buddies_instructorPicker_none => 'لا يوجد (إدخال يدوي)';

  @override
  String get certifications_appBar_addCertification => 'إضافة شهادة';

  @override
  String get certifications_appBar_certificationWallet => 'محفظة الشهادات';

  @override
  String get certifications_appBar_editCertification => 'تعديل الشهادة';

  @override
  String get certifications_appBar_title => 'الشهادات';

  @override
  String get certifications_detail_action_delete => 'حذف';

  @override
  String get certifications_detail_appBar_title => 'الشهادة';

  @override
  String get certifications_detail_courseCompleted => 'مكتمل';

  @override
  String get certifications_detail_courseInProgress => 'قيد التقدم';

  @override
  String get certifications_detail_dialog_cancel => 'إلغاء';

  @override
  String get certifications_detail_dialog_deleteConfirm => 'حذف';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return 'هل أنت متأكد من حذف \"$name\"؟';
  }

  @override
  String get certifications_detail_dialog_deleteTitle => 'حذف الشهادة؟';

  @override
  String get certifications_detail_label_agency => 'الجهة المانحة';

  @override
  String get certifications_detail_label_cardNumber => 'رقم البطاقة';

  @override
  String get certifications_detail_label_certification => 'الشهادة';

  @override
  String get certifications_detail_label_expiryDate => 'تاريخ الانتهاء';

  @override
  String get certifications_detail_label_instructorName => 'الاسم';

  @override
  String get certifications_detail_label_instructorNumber => 'رقم المدرب';

  @override
  String get certifications_detail_label_issueDate => 'تاريخ الإصدار';

  @override
  String get certifications_detail_label_type => 'النوع';

  @override
  String get certifications_detail_label_validity => 'الصلاحية';

  @override
  String get certifications_detail_noExpiration => 'بدون انتهاء صلاحية';

  @override
  String get certifications_detail_notFound => 'الشهادة غير موجودة';

  @override
  String get certifications_detail_photoLabel_back => 'الخلف';

  @override
  String get certifications_detail_photoLabel_front => 'الأمام';

  @override
  String certifications_detail_photo_fullscreenTitle(
    Object label,
    Object name,
  ) {
    return '$label - $name';
  }

  @override
  String get certifications_detail_photo_unableToLoad => 'تعذر تحميل الصورة';

  @override
  String get certifications_detail_sectionTitle_cardPhotos => 'صور البطاقة';

  @override
  String get certifications_detail_sectionTitle_dates => 'التواريخ';

  @override
  String get certifications_detail_sectionTitle_details => 'تفاصيل الشهادة';

  @override
  String get certifications_detail_sectionTitle_instructor => 'المدرب';

  @override
  String get certifications_detail_sectionTitle_notes => 'ملاحظات';

  @override
  String get certifications_detail_sectionTitle_trainingCourse =>
      'الدورة التدريبية';

  @override
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  ) {
    return 'صورة $label لـ $name. اضغط لعرض ملء الشاشة';
  }

  @override
  String get certifications_detail_snackBar_deleted => 'تم حذف الشهادة';

  @override
  String get certifications_detail_status_expired => 'انتهت صلاحية هذه الشهادة';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return 'انتهت الصلاحية في $date';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return 'تنتهي الصلاحية خلال $days يوم';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return 'تنتهي الصلاحية في $date';
  }

  @override
  String get certifications_detail_tooltip_edit => 'تعديل الشهادة';

  @override
  String get certifications_detail_tooltip_editShort => 'تعديل';

  @override
  String get certifications_detail_tooltip_moreOptions => 'خيارات إضافية';

  @override
  String get certifications_ecardStack_empty_subtitle =>
      'أضف شهادتك الأولى لرؤيتها هنا';

  @override
  String get certifications_ecardStack_empty_title => 'لا توجد شهادات بعد';

  @override
  String get certifications_ecard_label_cardNumber => 'رقم البطاقة';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'معتمد من $agency';
  }

  @override
  String get certifications_ecard_label_diver => 'الغواص';

  @override
  String get certifications_ecard_label_instructor => 'المدرب';

  @override
  String get certifications_ecard_label_issued => 'تاريخ الإصدار';

  @override
  String get certifications_ecard_label_validUntil => 'صالحة حتى';

  @override
  String get certifications_ecard_statusBadge_expired => 'منتهية';

  @override
  String get certifications_ecard_statusBadge_expiring => 'قاربت على الانتهاء';

  @override
  String get certifications_edit_appBar_add => 'إضافة شهادة';

  @override
  String get certifications_edit_appBar_edit => 'تعديل الشهادة';

  @override
  String get certifications_edit_button_add => 'إضافة شهادة';

  @override
  String get certifications_edit_button_cancel => 'إلغاء';

  @override
  String get certifications_edit_button_save => 'حفظ';

  @override
  String get certifications_edit_button_update => 'تحديث الشهادة';

  @override
  String get certifications_edit_certification_notSpecified => 'غير محدد';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return 'مسح $label';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect => 'اضغط للاختيار';

  @override
  String get certifications_edit_dialog_discard => 'تجاهل';

  @override
  String get certifications_edit_dialog_discardContent =>
      'لديك تغييرات غير محفوظة. هل أنت متأكد من المغادرة؟';

  @override
  String get certifications_edit_dialog_discardTitle => 'تجاهل التغييرات؟';

  @override
  String get certifications_edit_dialog_keepEditing => 'متابعة التعديل';

  @override
  String get certifications_edit_group_progression => 'التدرج';

  @override
  String get certifications_edit_group_specialties => 'التخصصات';

  @override
  String get certifications_edit_help_expiryDate =>
      'اتركه فارغاً للشهادات التي لا تنتهي صلاحيتها';

  @override
  String get certifications_edit_helper_nameOnCard => 'اختياري';

  @override
  String get certifications_edit_hint_cardNumber => 'أدخل رقم بطاقة الشهادة';

  @override
  String get certifications_edit_hint_instructorName => 'اسم المدرب المعتمد';

  @override
  String get certifications_edit_hint_instructorNumber => 'رقم شهادة المدرب';

  @override
  String get certifications_edit_hint_notes => 'أي ملاحظات إضافية';

  @override
  String get certifications_edit_label_agency => 'الجهة المانحة *';

  @override
  String get certifications_edit_label_cardNumber => 'رقم البطاقة';

  @override
  String get certifications_edit_label_certification => 'الشهادة';

  @override
  String get certifications_edit_label_expiryDate => 'تاريخ الانتهاء';

  @override
  String get certifications_edit_label_instructorName => 'اسم المدرب';

  @override
  String get certifications_edit_label_instructorNumber => 'رقم المدرب';

  @override
  String get certifications_edit_label_issueDate => 'تاريخ الإصدار';

  @override
  String get certifications_edit_label_nameOnCard => 'الاسم على البطاقة';

  @override
  String get certifications_edit_label_notes => 'ملاحظات';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return 'إضافة صورة $label. اضغط للاختيار';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return 'صورة $label مرفقة. اضغط للتغيير';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery => 'اختيار من المعرض';

  @override
  String certifications_edit_photo_removeTooltip(Object label) {
    return 'إزالة صورة $label';
  }

  @override
  String get certifications_edit_photo_takePhoto => 'التقاط صورة';

  @override
  String get certifications_edit_sectionTitle_cardPhotos => 'صور البطاقة';

  @override
  String get certifications_edit_sectionTitle_dates => 'التواريخ';

  @override
  String get certifications_edit_sectionTitle_instructorInfo =>
      'معلومات المدرب';

  @override
  String get certifications_edit_sectionTitle_notes => 'ملاحظات';

  @override
  String get certifications_edit_snackBar_added => 'تمت إضافة الشهادة بنجاح';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return 'خطأ في تحميل الشهادة: $error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return 'خطأ في اختيار الصورة: $error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return 'خطأ في حفظ الشهادة: $error';
  }

  @override
  String get certifications_edit_snackBar_updated => 'تم تحديث الشهادة بنجاح';

  @override
  String get certifications_edit_validation_certificationOrNameRequired =>
      'اختر شهادة أو أدخل اسمًا';

  @override
  String get certifications_list_button_retry => 'إعادة المحاولة';

  @override
  String get certifications_list_empty_button => 'أضف شهادتك الأولى';

  @override
  String get certifications_list_empty_subtitle =>
      'أضف شهادات الغوص الخاصة بك لتتبع\nتدريبك ومؤهلاتك';

  @override
  String get certifications_list_empty_title => 'لم تتم إضافة شهادات بعد';

  @override
  String certifications_list_error_loading(Object error) {
    return 'خطأ في تحميل الشهادات: $error';
  }

  @override
  String get certifications_list_fab_addCertification => 'إضافة شهادة';

  @override
  String get certifications_list_section_expired => 'منتهية الصلاحية';

  @override
  String get certifications_list_section_expiringSoon => 'تنتهي قريبًا';

  @override
  String get certifications_list_section_valid => 'سارية';

  @override
  String get certifications_list_sort_title => 'ترتيب الشهادات';

  @override
  String get certifications_list_tile_expired => 'منتهية الصلاحية';

  @override
  String certifications_list_tile_expiringDays(Object days) {
    return '$daysي';
  }

  @override
  String get certifications_list_tooltip_addCertification => 'إضافة شهادة';

  @override
  String get certifications_list_tooltip_search => 'البحث في الشهادات';

  @override
  String get certifications_list_tooltip_sort => 'ترتيب';

  @override
  String get certifications_list_tooltip_walletView => 'عرض المحفظة';

  @override
  String get certifications_picker_clearTooltip => 'مسح اختيار الشهادة';

  @override
  String get certifications_picker_empty_addButton => 'إضافة شهادة';

  @override
  String get certifications_picker_empty_title => 'لا توجد شهادات بعد';

  @override
  String certifications_picker_error(Object error) {
    return 'خطأ في تحميل الشهادات: $error';
  }

  @override
  String get certifications_picker_expired => 'منتهية الصلاحية';

  @override
  String get certifications_picker_hint => 'انقر للربط بشهادة مكتسبة';

  @override
  String get certifications_picker_newCert => 'شهادة جديدة';

  @override
  String get certifications_picker_noSelection => 'لم يتم اختيار شهادة';

  @override
  String get certifications_picker_sheetTitle => 'الربط بشهادة';

  @override
  String get certifications_renderer_footer => 'سجل غوص Submersion';

  @override
  String certifications_renderer_label_cardNumber(Object number) {
    return 'رقم البطاقة: $number';
  }

  @override
  String get certifications_renderer_label_hasCompletedTraining =>
      'قد أتم التدريب بصفته';

  @override
  String certifications_renderer_label_instructor(Object name) {
    return 'المدرب: $name';
  }

  @override
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  ) {
    return 'المدرب: $name ($number)';
  }

  @override
  String certifications_renderer_label_issued(Object date) {
    return 'تاريخ الإصدار: $date';
  }

  @override
  String get certifications_renderer_label_thisCertifies =>
      'تشهد هذه الوثيقة بأن';

  @override
  String get certifications_search_empty_hint =>
      'البحث بالاسم أو الوكالة أو رقم البطاقة';

  @override
  String get certifications_search_fieldLabel => 'البحث في الشهادات...';

  @override
  String certifications_search_noResults(Object query) {
    return 'لم يتم العثور على شهادات لـ \"$query\"';
  }

  @override
  String get certifications_search_tooltip_back => 'رجوع';

  @override
  String get certifications_search_tooltip_clear => 'مسح البحث';

  @override
  String certifications_share_error_card(Object error) {
    return 'فشل في مشاركة البطاقة: $error';
  }

  @override
  String certifications_share_error_certificate(Object error) {
    return 'فشل في مشاركة الشهادة: $error';
  }

  @override
  String get certifications_share_option_card_subtitle =>
      'صورة شهادة بنمط بطاقة الائتمان';

  @override
  String get certifications_share_option_card_title => 'مشاركة كبطاقة';

  @override
  String get certifications_share_option_certificate_subtitle =>
      'وثيقة شهادة رسمية';

  @override
  String get certifications_share_option_certificate_title => 'مشاركة كشهادة';

  @override
  String get certifications_share_title => 'مشاركة الشهادة';

  @override
  String get certifications_summary_header_subtitle =>
      'اختر شهادة من القائمة لعرض التفاصيل';

  @override
  String get certifications_summary_header_title => 'الشهادات';

  @override
  String get certifications_summary_overview_title => 'نظرة عامة';

  @override
  String get certifications_summary_quickActions_add => 'إضافة شهادة';

  @override
  String get certifications_summary_quickActions_title => 'إجراءات سريعة';

  @override
  String get certifications_summary_recentTitle => 'الشهادات الأخيرة';

  @override
  String get certifications_summary_stat_expired => 'منتهية الصلاحية';

  @override
  String get certifications_summary_stat_expiringSoon => 'تنتهي قريبًا';

  @override
  String get certifications_summary_stat_total => 'الإجمالي';

  @override
  String get certifications_summary_stat_valid => 'سارية';

  @override
  String get certifications_wallet_appBar_title => 'محفظة الشهادات';

  @override
  String get certifications_wallet_error_retry => 'إعادة المحاولة';

  @override
  String get certifications_wallet_error_title => 'فشل في تحميل الشهادات';

  @override
  String get certifications_wallet_options_edit => 'تعديل';

  @override
  String get certifications_wallet_options_share => 'مشاركة';

  @override
  String get certifications_wallet_options_viewDetails => 'عرض التفاصيل';

  @override
  String get certifications_wallet_tooltip_add => 'إضافة شهادة';

  @override
  String get certifications_wallet_tooltip_share => 'مشاركة الشهادة';

  @override
  String get checklists_section_title => 'قائمة التحقق';

  @override
  String checklists_progress(int done, int total) {
    return 'تم إنجاز $done من $total من المهام';
  }

  @override
  String get checklists_empty_upcoming =>
      'خطط لرحلتك - أضف مهامًا أو طبّق قالبًا';

  @override
  String get checklists_empty_past => 'لا توجد عناصر في قائمة التحقق';

  @override
  String get checklists_addItem => 'إضافة عنصر';

  @override
  String get checklists_item_titleLabel => 'العنوان';

  @override
  String get checklists_item_titleRequired => 'العنوان مطلوب';

  @override
  String get checklists_item_categoryLabel => 'الفئة';

  @override
  String get checklists_item_notesLabel => 'ملاحظات';

  @override
  String get checklists_item_dueDateLabel => 'تاريخ الاستحقاق';

  @override
  String get checklists_item_dueOffsetLabel => 'عدد الأيام قبل بدء الرحلة';

  @override
  String get checklists_item_dueOffsetInvalid => 'أدخل 0 يومًا أو أكثر';

  @override
  String get checklists_item_overdue => 'متأخر';

  @override
  String get checklists_item_edit => 'تعديل العنصر';

  @override
  String get checklists_item_delete => 'حذف العنصر';

  @override
  String get checklists_menu_applyTemplate => 'تطبيق قالب...';

  @override
  String get checklists_menu_saveAsTemplate => 'حفظ كقالب...';

  @override
  String get checklists_applySheet_title => 'تطبيق القالب';

  @override
  String get checklists_applySheet_empty =>
      'لا توجد قوالب بعد. يمكنك إنشاؤها من الإعدادات.';

  @override
  String checklists_applySheet_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عناصر',
      one: 'عنصر واحد',
    );
    return '$_temp0';
  }

  @override
  String checklists_applySheet_confirmAppend(int added, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'سيتم إضافة $added عناصر',
      one: 'سيتم إضافة عنصر واحد',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: 'مع تخطي $skipped عناصر مكررة',
      one: 'مع تخطي عنصر مكرر واحد',
      zero: 'دون تخطي أي عناصر مكررة',
    );
    return '$_temp0، $_temp1.';
  }

  @override
  String checklists_apply_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت إضافة $count عناصر',
      one: 'تمت إضافة عنصر واحد',
      zero: 'لم تتم إضافة أي عناصر جديدة',
    );
    return '$_temp0';
  }

  @override
  String get checklists_apply_templateGone => 'القالب لم يعد موجودًا';

  @override
  String get checklists_saveTemplate_title => 'حفظ كقالب';

  @override
  String get checklists_saveTemplate_nameLabel => 'اسم القالب';

  @override
  String get checklists_saveTemplate_success => 'تم حفظ القالب';

  @override
  String get checklists_templates_pageTitle => 'قوالب قوائم التحقق';

  @override
  String get checklists_templates_addTemplate => 'إضافة قالب';

  @override
  String get checklists_templates_empty => 'لا توجد قوالب بعد';

  @override
  String get checklists_templates_deleteTitle => 'حذف القالب';

  @override
  String checklists_templates_deleteContent(Object name) {
    return 'هل تريد حذف \"$name\"؟ ستحتفظ الرحلات التي طبّقته مسبقًا بعناصرها.';
  }

  @override
  String get checklists_template_nameLabel => 'الاسم';

  @override
  String get checklists_template_nameRequired => 'الاسم مطلوب';

  @override
  String get checklists_template_descriptionLabel => 'الوصف';

  @override
  String get checklists_template_itemsHeader => 'العناصر';

  @override
  String get checklists_template_addItem => 'إضافة عنصر';

  @override
  String get preDive_templates_title => 'قوائم تحقق ما قبل الغوص';

  @override
  String get preDive_templates_empty => 'لا توجد قوائم تحقق ما قبل الغوص بعد';

  @override
  String get preDive_templates_builtInBadge => 'مدمجة';

  @override
  String get preDive_templates_clone => 'استنساخ';

  @override
  String get preDive_templates_cloneSuffix => ' (نسخة)';

  @override
  String get preDive_templates_delete => 'حذف';

  @override
  String get preDive_templates_deleteConfirm =>
      'هل تريد حذف قالب قائمة التحقق هذا؟';

  @override
  String get preDive_templates_strictOrderBadge => 'ترتيب صارم';

  @override
  String get preDive_edit_titleNew => 'قائمة تحقق جديدة لما قبل الغوص';

  @override
  String get preDive_edit_titleEdit => 'تعديل قائمة تحقق ما قبل الغوص';

  @override
  String get preDive_edit_name => 'الاسم';

  @override
  String get preDive_edit_description => 'الوصف';

  @override
  String get preDive_edit_category => 'الفئة';

  @override
  String get preDive_edit_strictOrder => 'ترتيب صارم';

  @override
  String get preDive_edit_strictOrderHelp =>
      'يجب إكمال العناصر من الأعلى إلى الأسفل';

  @override
  String get preDive_edit_addItem => 'إضافة عنصر';

  @override
  String get preDive_edit_nameRequired => 'أدخل اسمًا';

  @override
  String get preDive_item_title => 'العنوان';

  @override
  String get preDive_item_section => 'القسم';

  @override
  String get preDive_item_notes => 'ملاحظات';

  @override
  String get preDive_item_required => 'مطلوب';

  @override
  String get preDive_item_type_check => 'خانة اختيار';

  @override
  String get preDive_item_type_value => 'قيمة مسجَّلة';

  @override
  String get preDive_item_type_equipmentSet => 'عناصر طقم المعدات';

  @override
  String get preDive_item_valueLabel => 'تسمية القيمة';

  @override
  String get preDive_item_valueUnit => 'الوحدة';

  @override
  String get preDive_item_valueMin => 'الحد الأدنى (تحذير)';

  @override
  String get preDive_item_valueMax => 'الحد الأقصى (تحذير)';

  @override
  String preDive_runner_progress(int done, int total) {
    return '$done من $total';
  }

  @override
  String get preDive_runner_complete => 'إكمال';

  @override
  String preDive_runner_completeFlagged(int count) {
    return 'هل تريد الإكمال مع $count من العناصر المعلَّمة؟';
  }

  @override
  String get preDive_runner_abort => 'إلغاء قائمة التحقق';

  @override
  String get preDive_runner_abortConfirm =>
      'هل تريد إلغاء قائمة التحقق هذه؟ سيتم الاحتفاظ بها في السجل كملغاة.';

  @override
  String get preDive_runner_skip => 'تخطي';

  @override
  String get preDive_runner_flag => 'وضع علامة';

  @override
  String get preDive_runner_undo => 'إعادة إلى قيد الانتظار';

  @override
  String get preDive_runner_serviceOverdue => 'الصيانة متأخرة';

  @override
  String get preDive_runner_addNote => 'إضافة ملاحظة';

  @override
  String get preDive_runner_enterValue => 'أدخل القيمة';

  @override
  String preDive_runner_flaggedBadge(int count) {
    return '$count معلَّمة';
  }

  @override
  String get preDive_runner_locked => 'قائمة التحقق هذه مقفلة';

  @override
  String get preDive_sessions_title => 'قوائم تحقق ما قبل الغوص';

  @override
  String get preDive_sessions_empty => 'لم يتم تنفيذ أي قائمة تحقق بعد';

  @override
  String get preDive_sessions_resume => 'استئناف';

  @override
  String get preDive_sessions_start => 'بدء قائمة التحقق';

  @override
  String get preDive_sessions_statusCompleted => 'مكتملة';

  @override
  String get preDive_sessions_statusAborted => 'ملغاة';

  @override
  String get preDive_sessions_statusInProgress => 'قيد التنفيذ';

  @override
  String get preDive_sessions_linkedDive => 'الغطسة المرتبطة';

  @override
  String get preDive_link_linkToDive => 'الربط بغطسة';

  @override
  String get preDive_link_unlinkDive => 'إلغاء ربط الغطسة';

  @override
  String get preDive_link_linkChecklist => 'ربط قائمة تحقق ما قبل الغوص';

  @override
  String get preDive_link_unlinkChecklist =>
      'إلغاء ربط قائمة تحقق ما قبل الغوص';

  @override
  String get preDive_link_searchDives => 'البحث في الغطسات';

  @override
  String get preDive_link_noDives => 'لا توجد غطسات للربط';

  @override
  String preDive_link_noDivesMatch(String query) {
    return 'لا توجد غطسات تطابق \"$query\"';
  }

  @override
  String get preDive_link_noUnlinkedSessions => 'لا توجد قوائم تحقق غير مرتبطة';

  @override
  String get preDive_link_linked => 'تم ربط قائمة التحقق بهذه الغطسة';

  @override
  String get preDive_link_unlinked => 'تم إلغاء ربط قائمة التحقق بهذه الغطسة';

  @override
  String get preDive_sessions_delete => 'حذف';

  @override
  String get preDive_sessions_deleteConfirm =>
      'هل تريد حذف سجل قائمة التحقق هذا؟';

  @override
  String get preDive_sessions_filter => 'تصفية';

  @override
  String get preDive_sessions_filterTitle => 'تصفية عمليات قوائم التحقق';

  @override
  String get preDive_sessions_filterChecklist => 'قائمة التحقق';

  @override
  String get preDive_sessions_filterStatus => 'الحالة';

  @override
  String get preDive_sessions_filterFlaggedOnly => 'العمليات المعلَّمة فقط';

  @override
  String get preDive_sessions_filterDateRange => 'النطاق الزمني';

  @override
  String get preDive_sessions_filterAnyDate => 'أي تاريخ';

  @override
  String get preDive_sessions_filterClearAll => 'مسح الكل';

  @override
  String get preDive_sessions_filterApply => 'تطبيق';

  @override
  String get preDive_sessions_filterFlaggedChip => 'المعلَّمة فقط';

  @override
  String get preDive_sessions_emptyFiltered =>
      'لا توجد عمليات قوائم تحقق تطابق هذه المرشحات';

  @override
  String get preDive_sessions_export => 'تصدير إلى Excel';

  @override
  String get preDive_sessions_exportEmpty =>
      'لا توجد عمليات قوائم تحقق للتصدير';

  @override
  String preDive_sessions_exportFailed(String error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get preDive_start_title => 'بدء قائمة تحقق ما قبل الغوص';

  @override
  String get preDive_start_template => 'قائمة التحقق';

  @override
  String get preDive_start_equipmentSet => 'طقم المعدات';

  @override
  String get preDive_start_noEquipmentSet => 'بدون';

  @override
  String get preDive_start_begin => 'بدء';

  @override
  String get diveLog_listPage_bottomSheet_preDiveChecklist =>
      'بدء قائمة تحقق ما قبل الغوص';

  @override
  String get preDive_dashboard_title => 'فحص ما قبل الغوص';

  @override
  String preDive_dashboard_resume(int done, int total) {
    return 'استئناف - $done من $total';
  }

  @override
  String get preDive_dashboard_start => 'بدء فحص ما قبل الغوص';

  @override
  String get trips_detail_preDive_action => 'قائمة تحقق ما قبل الغوص';

  @override
  String get settings_manage_preDiveChecklists => 'قوائم تحقق ما قبل الغوص';

  @override
  String get settings_manage_preDiveChecklists_subtitle =>
      'فحوصات رفيق الغوص، قوائم تجهيز CCR، توضيب المعدات';

  @override
  String get common_action_back => 'رجوع';

  @override
  String get common_action_cancel => 'إلغاء';

  @override
  String get common_action_close => 'إغلاق';

  @override
  String get common_action_continue => 'متابعة';

  @override
  String get common_action_delete => 'حذف';

  @override
  String get common_action_edit => 'تعديل';

  @override
  String get common_action_ok => 'موافق';

  @override
  String get common_action_save => 'حفظ';

  @override
  String get common_action_search => 'بحث';

  @override
  String get common_action_share => 'مشاركة';

  @override
  String get common_label_error => 'خطأ';

  @override
  String get common_label_loading => 'جارٍ التحميل';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get common_error_tryAgain => 'حدث خطأ ما. يُرجى المحاولة مرة أخرى.';

  @override
  String get courses_action_add => 'إضافة دورة';

  @override
  String get courses_action_addFromTemplate => 'إضافة من قالب';

  @override
  String get courses_action_addRequirement => 'إضافة متطلب';

  @override
  String get courses_action_create => 'إنشاء دورة';

  @override
  String get courses_action_deleteRequirement => 'حذف المتطلب';

  @override
  String get courses_action_edit => 'تعديل الدورة';

  @override
  String get courses_action_editRequirement => 'تعديل المتطلب';

  @override
  String get courses_action_exportTrainingLog => 'تصدير سجل التدريب';

  @override
  String get courses_action_linkDive => 'ربط';

  @override
  String get courses_action_markCompleted => 'وضع علامة كمكتمل';

  @override
  String get courses_action_unlinkDive => 'إلغاء ربط الغطسة';

  @override
  String get courses_action_moreOptions => 'المزيد من الخيارات';

  @override
  String get courses_action_retry => 'إعادة المحاولة';

  @override
  String get courses_action_saveChanges => 'حفظ التغييرات';

  @override
  String get courses_action_saveSemantic => 'حفظ الدورة';

  @override
  String get courses_action_sort => 'ترتيب';

  @override
  String get courses_action_sortTitle => 'ترتيب الدورات';

  @override
  String courses_card_instructor(Object name) {
    return 'المدرب: $name';
  }

  @override
  String courses_card_started(Object date) {
    return 'بدأت في $date';
  }

  @override
  String get courses_detail_certificationNotFound => 'الاعتماد غير موجود';

  @override
  String get courses_detail_noTrainingDives =>
      'لا توجد غطسات تدريبية مربوطة بعد';

  @override
  String get courses_detail_notFound => 'الدورة غير موجودة';

  @override
  String get courses_dialog_complete => 'إكمال';

  @override
  String courses_dialog_deleteMessage(Object name) {
    return 'هل أنت متأكد من حذف $name؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get courses_dialog_deleteTitle => 'حذف الدورة؟';

  @override
  String get courses_dialog_markCompletedMessage =>
      'سيتم وضع علامة على الدورة كمكتملة بتاريخ اليوم. هل تريد المتابعة؟';

  @override
  String get courses_dialog_markCompletedTitle => 'وضع علامة كمكتمل؟';

  @override
  String get courses_empty_button => 'أضف أول دورة تدريبية';

  @override
  String get courses_empty_noCompleted => 'لا توجد دورات مكتملة';

  @override
  String get courses_empty_noInProgress => 'لا توجد دورات قيد التنفيذ';

  @override
  String get courses_empty_subtitle => 'أضف أول دورة للبدء';

  @override
  String get courses_empty_title => 'لا توجد دورات تدريبية بعد';

  @override
  String courses_error_generic(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get courses_error_loadingCertification => 'خطأ في تحميل الاعتماد';

  @override
  String get courses_error_loadingDives => 'خطأ في تحميل الغطسات';

  @override
  String get courses_field_courseName => 'اسم الدورة';

  @override
  String get courses_field_courseNameHint => 'مثال: غواص المياه المفتوحة';

  @override
  String get courses_field_instructorName => 'اسم المدرب';

  @override
  String get courses_field_instructorNumber => 'رقم المدرب';

  @override
  String get courses_field_linkCertificationHint =>
      'ربط الاعتماد المكتسب من هذه الدورة';

  @override
  String get courses_field_location => 'الموقع';

  @override
  String get courses_field_notes => 'ملاحظات';

  @override
  String get courses_filter_all => 'الكل';

  @override
  String get courses_label_agency => 'الجهة';

  @override
  String get courses_label_completed => 'مكتمل';

  @override
  String get courses_label_completionDate => 'تاريخ الإكمال';

  @override
  String get courses_label_courseInProgress => 'الدورة قيد التنفيذ';

  @override
  String get courses_label_instructorNumber => 'رقم المدرب';

  @override
  String get courses_label_location => 'الموقع';

  @override
  String get courses_label_name => 'الاسم';

  @override
  String get courses_label_startDate => 'تاريخ البدء';

  @override
  String courses_message_errorSaving(Object error) {
    return 'خطأ في حفظ الدورة: $error';
  }

  @override
  String courses_message_exportFailed(Object error) {
    return 'فشل تصدير سجل التدريب: $error';
  }

  @override
  String get courses_picker_active => 'نشط';

  @override
  String get courses_picker_clearSelection => 'مسح التحديد';

  @override
  String get courses_picker_createCourse => 'إنشاء دورة';

  @override
  String courses_picker_errorLoading(Object error) {
    return 'خطأ في تحميل الدورات: $error';
  }

  @override
  String get courses_picker_newCourse => 'دورة جديدة';

  @override
  String get courses_picker_noCourses => 'لا توجد دورات بعد';

  @override
  String get courses_picker_noneSelected => 'لم يتم اختيار دورة';

  @override
  String get courses_picker_selectTitle => 'اختيار دورة تدريبية';

  @override
  String get courses_picker_selected => 'محدد';

  @override
  String get courses_picker_tapToLink => 'اضغط للربط بدورة تدريبية';

  @override
  String courses_requirement_diveProgress(int count, int target) {
    return '$count من $target غطسات';
  }

  @override
  String get courses_requirement_field_name => 'الاسم';

  @override
  String get courses_requirement_field_targetCount => 'الغطسات المطلوبة';

  @override
  String get courses_requirement_kind_checklist => 'عنصر تحقق';

  @override
  String get courses_requirement_kind_dive => 'متطلب غطس';

  @override
  String get courses_requirement_suggestions => 'غطسات مقترحة';

  @override
  String get courses_requirements_empty =>
      'تتبع غطسات المغامرة والمتطلبات المسبقة وعناصر التحقق لهذه الدورة.';

  @override
  String courses_requirements_progress(int satisfied, int total) {
    return '$satisfied من $total مكتملة';
  }

  @override
  String get courses_section_details => 'تفاصيل الدورة';

  @override
  String get courses_section_earnedCertification => 'الاعتماد المكتسب';

  @override
  String get courses_section_instructor => 'المدرب';

  @override
  String get courses_section_notes => 'ملاحظات';

  @override
  String get courses_section_requirements => 'المتطلبات';

  @override
  String get courses_section_trainingDives => 'الغطسات التدريبية';

  @override
  String get courses_status_completed => 'مكتمل';

  @override
  String courses_status_daysSinceStart(Object days) {
    return '$days يوم منذ البدء';
  }

  @override
  String courses_status_durationDays(Object days) {
    return '$days يوم';
  }

  @override
  String get courses_status_inProgress => 'قيد التنفيذ';

  @override
  String courses_status_semanticLabel(Object status, Object duration) {
    return '$status، $duration';
  }

  @override
  String courses_template_addsCount(int count) {
    return 'يضيف $count متطلبات';
  }

  @override
  String get courses_summary_overview => 'نظرة عامة';

  @override
  String get courses_summary_quickActions => 'إجراءات سريعة';

  @override
  String get courses_summary_recentCourses => 'الدورات الأخيرة';

  @override
  String get courses_summary_selectHint => 'اختر دورة من القائمة لعرض التفاصيل';

  @override
  String get courses_summary_title => 'الدورات التدريبية';

  @override
  String get courses_summary_total => 'الإجمالي';

  @override
  String get courses_title => 'الدورات التدريبية';

  @override
  String get courses_title_edit => 'تعديل الدورة';

  @override
  String get courses_title_new => 'دورة جديدة';

  @override
  String get courses_title_singular => 'دورة';

  @override
  String get courses_validation_nameRequired => 'الرجاء إدخال اسم الدورة';

  @override
  String get dashboard_activeCourses_title => 'الدورات قيد التنفيذ';

  @override
  String get dashboard_activity_daySinceDiving => 'يوم منذ آخر غوصة';

  @override
  String get dashboard_activity_daysSinceDiving => 'أيام منذ آخر غوصة';

  @override
  String dashboard_activity_diveInYear(Object year) {
    return 'غوصة في $year';
  }

  @override
  String get dashboard_activity_diveThisMonth => 'غوصة هذا الشهر';

  @override
  String dashboard_activity_divesInYear(Object year) {
    return 'غوصات في $year';
  }

  @override
  String get dashboard_activity_divesThisMonth => 'غوصات هذا الشهر';

  @override
  String get dashboard_activity_error => 'خطأ';

  @override
  String get dashboard_activity_lastDive => 'آخر غوصة';

  @override
  String get dashboard_activity_loading => 'جارٍ التحميل';

  @override
  String get dashboard_activity_noDivesYet => 'لا توجد غوصات بعد';

  @override
  String get dashboard_activity_today => 'اليوم!';

  @override
  String get dashboard_alerts_actionUpdate => 'تحديث';

  @override
  String get dashboard_alerts_actionView => 'عرض';

  @override
  String get dashboard_alerts_checkInsuranceExpiry =>
      'تحقق من تاريخ انتهاء التأمين';

  @override
  String get dashboard_alerts_daysOverdueOne => 'متأخر يوم واحد';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return 'متأخر $count أيام';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => 'مستحق خلال يوم واحد';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return 'مستحق خلال $count أيام';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return 'صيانة $name مستحقة';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return 'صيانة $name متأخرة';
  }

  @override
  String get dashboard_alerts_insuranceExpired => 'انتهى التأمين';

  @override
  String get dashboard_alerts_insuranceExpiredGeneric =>
      'انتهت صلاحية تأمين الغوص الخاص بك';

  @override
  String dashboard_alerts_insuranceExpiredProvider(Object provider) {
    return 'انتهت صلاحية $provider';
  }

  @override
  String dashboard_alerts_insuranceExpiresDate(Object date) {
    return 'تنتهي الصلاحية $date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon => 'التأمين ينتهي قريباً';

  @override
  String get dashboard_alerts_sectionTitle => 'التنبيهات والتذكيرات';

  @override
  String get dashboard_alerts_serviceDueToday => 'الصيانة مستحقة اليوم';

  @override
  String get dashboard_alerts_serviceIntervalReached => 'تم بلوغ فترة الصيانة';

  @override
  String get dashboard_defaultDiverName => 'غواص';

  @override
  String get dashboard_greeting_afternoon => 'مساء الخير';

  @override
  String get dashboard_greeting_evening => 'مساء الخير';

  @override
  String get dashboard_greeting_morning => 'صباح الخير';

  @override
  String dashboard_greeting_withName(Object greeting, Object name) {
    return '$greeting، $name!';
  }

  @override
  String dashboard_greeting_withoutName(Object greeting) {
    return '$greeting!';
  }

  @override
  String get dashboard_hero_divesLoggedOne => 'غوصة واحدة مسجلة';

  @override
  String dashboard_hero_divesLoggedOther(Object count) {
    return '$count غوصات مسجلة';
  }

  @override
  String get dashboard_hero_divesTotalOne => 'غوصة واحدة';

  @override
  String dashboard_hero_divesTotalOther(Object count) {
    return '$count غوصات';
  }

  @override
  String get dashboard_hero_error => 'هل أنت مستعد لاستكشاف الأعماق؟';

  @override
  String dashboard_hero_hoursUnderwater(Object hours) {
    return '$hours ساعات تحت الماء';
  }

  @override
  String get dashboard_hero_loading => 'جارٍ تحميل إحصائيات الغوص...';

  @override
  String dashboard_hero_minutesUnderwater(Object minutes) {
    return '$minutes دقائق تحت الماء';
  }

  @override
  String get dashboard_hero_noDives => 'هل أنت مستعد لتسجيل أول غوصة؟';

  @override
  String get dashboard_hero_divesLoggedLabel => 'غوصات مسجلة';

  @override
  String get dashboard_hero_hoursUnderwaterLabel => 'ساعات تحت الماء';

  @override
  String get dashboard_hero_daysSinceLabel => 'أيام منذ آخر غوصة';

  @override
  String get dashboard_hero_thisMonthLabel => 'هذا الشهر';

  @override
  String get dashboard_hero_thisYearLabel => 'غوصات هذا العام';

  @override
  String get dashboard_hero_todayLabel => 'اليوم!';

  @override
  String get dashboard_hero_noDivesLabel => 'لا غوصات بعد';

  @override
  String get dashboard_hero_diverFallbackName => 'غواص';

  @override
  String get dashboard_hero_statDives => 'غطسات';

  @override
  String get dashboard_hero_statHours => 'ساعات';

  @override
  String get dashboard_hero_statSites => 'مواقع';

  @override
  String get dashboard_hero_statCountries => 'دول';

  @override
  String dashboard_activityStats_divesInYear(String year) {
    return 'غطسات في $year';
  }

  @override
  String get dashboard_semantics_statsBar => 'ملخص إحصائيات الغوص';

  @override
  String get dashboard_gauges_addGear => 'إضافة معدات';

  @override
  String dashboard_gauges_gearOk(String name) {
    return '$name سليم';
  }

  @override
  String dashboard_gauges_gearDueIn(String name, int days) {
    return '$name مستحق خلال $days يوم';
  }

  @override
  String dashboard_gauges_gearOverdue(String name) {
    return '$name متأخر عن الصيانة';
  }

  @override
  String get dashboard_gauges_insuranceOk => 'التأمين سليم';

  @override
  String dashboard_gauges_insuranceExpires(String date) {
    return 'ينتهي التأمين في $date';
  }

  @override
  String get dashboard_gauges_insuranceExpired => 'انتهى التأمين';

  @override
  String get dashboard_gauges_noInsurance => 'لا يوجد تأمين مسجل';

  @override
  String get dashboard_gauges_noFlyClear => 'حظر الطيران 0:00';

  @override
  String dashboard_gauges_flightWindow(String hours, String minutes) {
    return 'نافذة الغوص $hours:$minutes';
  }

  @override
  String get dashboard_gauges_flightWindowClosed =>
      'لا مزيد من الغوص قبل الرحلة';

  @override
  String dashboard_gauges_noFlyRemaining(String hours, String minutes) {
    return 'حظر الطيران $hours:$minutes';
  }

  @override
  String dashboard_gauges_lastDiveDays(int days) {
    return 'آخر غطسة منذ $days يوم';
  }

  @override
  String get dashboard_gauges_lastDiveToday => 'غطست اليوم';

  @override
  String get dashboard_gauges_noDivesYet => 'لا توجد غطسات بعد';

  @override
  String get settings_homeChips_pageTitle => 'الشاشة الرئيسية';

  @override
  String get settings_homeChips_description =>
      'اختر شرائح الحالة التي تظهر أعلى تبويب الرئيسية.';

  @override
  String get settings_homeChips_sectionTitle => 'شرائح الحالة';

  @override
  String get settings_homeCards_sectionTitle => 'بطاقات الرئيسية';

  @override
  String get settings_homeCards_description =>
      'اختر البطاقات التي تظهر في تبويب الرئيسية واسحبها لإعادة ترتيبها.';

  @override
  String get settings_homeCards_autoHides => 'تُخفى تلقائيًا عندما تكون فارغة';

  @override
  String get settings_homeCards_resetToDefault => 'إعادة التعيين إلى الافتراضي';

  @override
  String get settings_homeCards_resetDialog_title =>
      'إعادة تعيين تخطيط الرئيسية؟';

  @override
  String get settings_homeCards_resetDialog_message =>
      'يستعيد الترتيب الافتراضي للبطاقات ويعرضها جميعًا من جديد.';

  @override
  String get settings_homeCards_resetDialog_cancel => 'إلغاء';

  @override
  String get settings_homeCards_resetDialog_confirm => 'إعادة تعيين';

  @override
  String get settings_homeCards_card_hero => 'ترويسة الترحيب';

  @override
  String get settings_homeCards_card_gaugeStrip => 'شرائح الحالة';

  @override
  String get settings_homeCards_card_preDive => 'قائمة فحص ما قبل الغوص';

  @override
  String get settings_homeCards_card_recentDives => 'الغوصات الأخيرة';

  @override
  String get settings_homeCards_card_quickActions => 'إجراءات سريعة';

  @override
  String get settings_homeCards_card_milestones => 'الإنجازات';

  @override
  String get settings_homeCards_card_photoRibbon => 'أحدث الوسائط';

  @override
  String get settings_homeCards_card_onThisDay => 'في مثل هذا اليوم';

  @override
  String get settings_homeCards_card_yearInReview => 'حصاد العام';

  @override
  String get settings_homeCards_card_activeCourses => 'تقدّم الدورة';

  @override
  String get settings_homeCards_card_recentSitesMap => 'خريطة المواقع الأخيرة';

  @override
  String get dashboard_allHidden_message => 'جميع بطاقات الرئيسية مخفية.';

  @override
  String get dashboard_allHidden_customize => 'تخصيص الرئيسية';

  @override
  String get settings_homeChips_flightWindow => 'نافذة الغوص قبل الرحلة';

  @override
  String get settings_homeChips_gear => 'صيانة المعدات';

  @override
  String get settings_homeChips_insurance => 'التأمين';

  @override
  String get settings_homeChips_noFly => 'مؤقت حظر الطيران';

  @override
  String get settings_homeChips_lastDive => 'حداثة الغطس';

  @override
  String get settings_homeChips_certifications => 'انتهاء الشهادات';

  @override
  String get settings_homeChips_trip => 'الرحلة القادمة';

  @override
  String get settings_homeChips_checklist => 'قائمة التحقق النشطة';

  @override
  String get settings_homeChips_course => 'تقدم الدورة';

  @override
  String get settings_homeChips_uploads => 'رفع الوسائط';

  @override
  String get settings_homeChips_backup => 'عمر النسخ الاحتياطي';

  @override
  String get settings_homeChips_sync => 'حالة المزامنة';

  @override
  String get settings_homeChips_dataQuality => 'جودة البيانات';

  @override
  String dashboard_gauges_certsExpiring(int count) {
    return '$count شهادات على وشك الانتهاء';
  }

  @override
  String dashboard_gauges_tripCountdown(String name, int days) {
    return '$name خلال $days يوم';
  }

  @override
  String get dashboard_gauges_checklistActive => 'قائمة التحقق قيد التنفيذ';

  @override
  String dashboard_gauges_courseProgress(String name, int done, int total) {
    return '$name: $done/$total';
  }

  @override
  String dashboard_gauges_uploadsPending(int count) {
    return '$count عمليات رفع معلقة';
  }

  @override
  String get dashboard_gauges_backupNone => 'لا يوجد نسخ احتياطي';

  @override
  String get dashboard_gauges_backupToday => 'تم النسخ الاحتياطي اليوم';

  @override
  String dashboard_gauges_backupDays(int days) {
    return 'نسخ احتياطي منذ $days يوم';
  }

  @override
  String dashboard_gauges_syncPending(int count) {
    return '$count غير متزامنة';
  }

  @override
  String get dashboard_gauges_synced => 'متزامن';

  @override
  String dashboard_gauges_dataIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مشاكل في البيانات',
      one: 'مشكلة واحدة في البيانات',
    );
    return '$_temp0';
  }

  @override
  String get dashboard_gauges_retry =>
      'الحالة غير متاحة - انقر لإعادة المحاولة';

  @override
  String get dashboard_urgent_title => 'يتطلب الانتباه';

  @override
  String get dashboard_media_title => 'أحدث الوسائط';

  @override
  String get dashboard_recentSites_title => 'المواقع الأخيرة';

  @override
  String get dashboard_yearInReview_title => 'هذا العام';

  @override
  String dashboard_yearInReview_divesVs(int count, int previous) {
    return '$count غطسات (مقابل $previous العام الماضي)';
  }

  @override
  String dashboard_yearInReview_hours(String hours) {
    return '$hours ساعات تحت الماء';
  }

  @override
  String dashboard_yearInReview_maxDepth(String depth) {
    return 'الأعمق: $depth';
  }

  @override
  String get dashboard_onThisDay_title => 'في مثل هذا اليوم';

  @override
  String dashboard_onThisDay_entry(String year, String site) {
    return '$year - $site';
  }

  @override
  String get dashboard_milestones_title => 'الإنجازات';

  @override
  String dashboard_milestones_nextDive(int remaining, int milestone) {
    return '$remaining غطسات حتى رقم $milestone';
  }

  @override
  String dashboard_milestones_certYears(String name, int years, String month) {
    return '$name: $years سنوات في $month';
  }

  @override
  String get dashboard_personalRecords_coldest => 'الأبرد';

  @override
  String get dashboard_personalRecords_deepest => 'الأعمق';

  @override
  String get dashboard_personalRecords_longest => 'الأطول';

  @override
  String get dashboard_personalRecords_sectionTitle =>
      'الأرقام القياسية الشخصية';

  @override
  String get dashboard_personalRecords_warmest => 'الأدفأ';

  @override
  String get dashboard_quickActions_addSite => 'إضافة موقع';

  @override
  String get dashboard_quickActions_addSiteTooltip => 'إضافة موقع غوص جديد';

  @override
  String get dashboard_quickActions_logDive => 'تسجيل غوصة';

  @override
  String get dashboard_quickActions_logDiveTooltip => 'تسجيل غوصة جديدة';

  @override
  String get dashboard_quickActions_planDive => 'تخطيط غوصة';

  @override
  String get dashboard_quickActions_planDiveTooltip => 'تخطيط غوصة جديدة';

  @override
  String get dashboard_quickActions_sectionTitle => 'إجراءات سريعة';

  @override
  String get dashboard_quickActions_statistics => 'الإحصائيات';

  @override
  String get dashboard_quickActions_statisticsTooltip => 'عرض إحصائيات الغوص';

  @override
  String get dashboard_quickStats_countries => 'الدول';

  @override
  String get dashboard_quickStats_countriesSubtitle => 'تمت زيارتها';

  @override
  String get dashboard_quickStats_sectionTitle => 'نظرة سريعة';

  @override
  String get dashboard_quickStats_species => 'الأنواع';

  @override
  String get dashboard_quickStats_speciesSubtitle => 'تم اكتشافها';

  @override
  String get dashboard_quickStats_topBuddy => 'أفضل زميل غوص';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count غوصات';
  }

  @override
  String get dashboard_recentDives_empty => 'لم يتم تسجيل غوصات بعد';

  @override
  String get dashboard_recentDives_errorLoading => 'فشل تحميل الغوصات';

  @override
  String get dashboard_recentDives_latestProfileTitle => 'مخطط آخر غطسة';

  @override
  String get dashboard_recentDives_noProfileData =>
      'لا توجد بيانات مخطط لهذه الغطسة';

  @override
  String get dashboard_recentDives_profileLoadError => 'تعذر تحميل مخطط الغطسة';

  @override
  String dashboard_recentDives_profileMinutes(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get dashboard_recentDives_logFirst => 'سجّل أول غوصة لك';

  @override
  String get dashboard_recentDives_sectionTitle => 'الغوصات الأخيرة';

  @override
  String get dashboard_recentDives_viewAll => 'عرض الكل';

  @override
  String get dashboard_recentDives_viewAllTooltip => 'عرض جميع الغوصات';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count تنبيهات نشطة';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives =>
      'خطأ: فشل تحميل الغوصات الأخيرة';

  @override
  String get dashboard_semantics_errorLoadingStatistics =>
      'خطأ: فشل تحميل الإحصائيات';

  @override
  String get dashboard_semantics_greetingBanner => 'شعار ترحيب لوحة التحكم';

  @override
  String get dashboard_stats_errorLoadingStatistics => 'فشل تحميل الإحصائيات';

  @override
  String get dashboard_stats_hoursLogged => 'الساعات المسجلة';

  @override
  String get dashboard_stats_maxDepth => 'أقصى عمق';

  @override
  String get dashboard_stats_sitesVisited => 'المواقع التي تمت زيارتها';

  @override
  String get dashboard_stats_totalDives => 'إجمالي الغوصات';

  @override
  String get decoCalculator_addToPlanner => 'إضافة إلى المخطط';

  @override
  String decoCalculator_bottomTimeSemantics(Object time) {
    return 'وقت القاع: $time دقيقة';
  }

  @override
  String get decoCalculator_createPlanTooltip =>
      'إنشاء خطة غوص من المعاملات الحالية';

  @override
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  ) {
    return 'تم إنشاء خطة: $depth$depthSymbol لـ $time دقيقة على $gasMixName';
  }

  @override
  String get decoCalculator_customMixTrimix => 'خليط مخصص (Trimix)';

  @override
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol) {
    return 'العمق: $depth $depthSymbol';
  }

  @override
  String get decoCalculator_diveParameters => 'معاملات الغوص';

  @override
  String get decoCalculator_endCaution => 'تحذير';

  @override
  String get decoCalculator_endDanger => 'خطر';

  @override
  String get decoCalculator_endSafe => 'آمن';

  @override
  String get decoCalculator_field_bottomTime => 'وقت القاع';

  @override
  String get decoCalculator_field_depth => 'العمق';

  @override
  String get decoCalculator_field_gasMix => 'خليط الغاز';

  @override
  String get decoCalculator_gasSafety => 'سلامة الغاز';

  @override
  String get decoCalculator_hideCustomMix => 'إخفاء الخليط المخصص';

  @override
  String get decoCalculator_hideCustomMixSemantics =>
      'إخفاء محدد خليط الغاز المخصص';

  @override
  String get decoCalculator_modExceeded => 'تجاوز MOD';

  @override
  String get decoCalculator_modSafe => 'MOD آمن';

  @override
  String get decoCalculator_ppO2Caution => 'تحذير ppO2';

  @override
  String get decoCalculator_ppO2Danger => 'خطر ppO2';

  @override
  String get decoCalculator_ppO2Hypoxic => 'ppO2 نقص أكسجين';

  @override
  String get decoCalculator_ppO2Safe => 'ppO2 آمن';

  @override
  String get decoCalculator_resetToDefaults =>
      'إعادة تعيين إلى الإعدادات الافتراضية';

  @override
  String get decoCalculator_showCustomMixSemantics =>
      'إظهار محدد خليط الغاز المخصص';

  @override
  String decoCalculator_timeValueMin(Object time) {
    return '$time دقيقة';
  }

  @override
  String get decoCalculator_title => 'حاسبة تخفيف الضغط';

  @override
  String get decoCalculator_waterType => 'نوع الماء';

  @override
  String get decoCalculator_waterType_standard => 'قياسي';

  @override
  String diveCenters_accessibility_markerLabel(Object name) {
    return 'مركز غوص: $name';
  }

  @override
  String get diveCenters_accessibility_selected => 'محدد';

  @override
  String diveCenters_accessibility_viewDetails(Object name) {
    return 'عرض تفاصيل $name';
  }

  @override
  String get diveCenters_accessibility_viewDives => 'عرض الغطسات مع هذا المركز';

  @override
  String get diveCenters_accessibility_viewFullscreenMap =>
      'عرض الخريطة بملء الشاشة';

  @override
  String diveCenters_accessibility_viewSavedCenter(Object name) {
    return 'عرض مركز الغوص المحفوظ $name';
  }

  @override
  String get diveCenters_action_addCenter => 'إضافة مركز';

  @override
  String get diveCenters_action_addNew => 'إضافة جديد';

  @override
  String get diveCenters_action_clearRating => 'مسح';

  @override
  String get diveCenters_action_gettingLocation => 'جارٍ الحصول...';

  @override
  String get diveCenters_action_import => 'استيراد';

  @override
  String get diveCenters_action_importToMyCenters => 'استيراد إلى مراكزي';

  @override
  String get diveCenters_action_lookingUp => 'جارٍ البحث...';

  @override
  String get diveCenters_action_lookupFromAddress => 'البحث من العنوان';

  @override
  String get diveCenters_action_pickFromMap => 'اختيار من الخريطة';

  @override
  String get diveCenters_action_retry => 'إعادة المحاولة';

  @override
  String get diveCenters_action_settings => 'الإعدادات';

  @override
  String get diveCenters_action_useMyLocation => 'استخدم موقعي';

  @override
  String get diveCenters_action_view => 'عرض';

  @override
  String diveCenters_detail_divesLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غطسة مسجلة',
      one: 'غطسة واحدة مسجلة',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_detail_divesWithCenter => 'الغطسات مع هذا المركز';

  @override
  String get diveCenters_detail_noDivesLogged => 'لا توجد غطسات مسجلة بعد';

  @override
  String diveCenters_dialog_deleteMessage(Object name) {
    return 'هل أنت متأكد من حذف \"$name\"؟';
  }

  @override
  String get diveCenters_dialog_deleteTitle => 'حذف مركز الغوص';

  @override
  String get diveCenters_dialog_discard => 'تجاهل';

  @override
  String get diveCenters_dialog_discardMessage =>
      'لديك تغييرات غير محفوظة. هل تريد تجاهلها؟';

  @override
  String get diveCenters_dialog_discardTitle => 'تجاهل التغييرات؟';

  @override
  String get diveCenters_dialog_keepEditing => 'متابعة التعديل';

  @override
  String get diveCenters_empty_button => 'أضف أول مركز غوص';

  @override
  String get diveCenters_empty_subtitle =>
      'أضف متاجر ومشغلي الغوص المفضلين لديك';

  @override
  String get diveCenters_empty_title => 'لا توجد مراكز غوص بعد';

  @override
  String diveCenters_error_generic(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get diveCenters_error_geocodeFailed =>
      'تعذر العثور على الإحداثيات لهذا العنوان';

  @override
  String get diveCenters_error_importFailed => 'فشل استيراد مركز الغوص';

  @override
  String diveCenters_error_loading(Object error) {
    return 'خطأ في تحميل مراكز الغوص: $error';
  }

  @override
  String get diveCenters_error_locationPermission =>
      'تعذر الحصول على الموقع. يرجى التحقق من الأذونات.';

  @override
  String get diveCenters_error_locationUnavailable =>
      'تعذر الحصول على الموقع. قد لا تكون خدمات الموقع متاحة.';

  @override
  String get diveCenters_error_noAddressForLookup =>
      'الرجاء إدخال عنوان للبحث عن الإحداثيات';

  @override
  String get diveCenters_error_notFound => 'مركز الغوص غير موجود';

  @override
  String diveCenters_error_saving(Object error) {
    return 'خطأ في حفظ مركز الغوص: $error';
  }

  @override
  String get diveCenters_error_unknown => 'خطأ غير معروف';

  @override
  String get diveCenters_field_city => 'المدينة';

  @override
  String get diveCenters_field_country => 'البلد';

  @override
  String get diveCenters_field_latitude => 'خط العرض';

  @override
  String get diveCenters_field_longitude => 'خط الطول';

  @override
  String get diveCenters_field_nameRequired => 'الاسم *';

  @override
  String get diveCenters_field_postalCode => 'الرمز البريدي';

  @override
  String get diveCenters_field_rating => 'التقييم';

  @override
  String get diveCenters_field_stateProvince => 'الولاية/المقاطعة';

  @override
  String get diveCenters_field_street => 'عنوان الشارع';

  @override
  String get diveCenters_hint_addressDescription =>
      'عنوان الشارع الاختياري للملاحة';

  @override
  String get diveCenters_hint_affiliationsDescription =>
      'اختر وكالات التدريب التي يرتبط بها هذا المركز';

  @override
  String get diveCenters_hint_city => 'مثال: بوكيت';

  @override
  String get diveCenters_hint_country => 'مثال: تايلاند';

  @override
  String get diveCenters_hint_email => 'info@divecenter.com';

  @override
  String get diveCenters_hint_gpsDescription =>
      'اختر طريقة تحديد الموقع أو أدخل الإحداثيات يدوياً';

  @override
  String get diveCenters_hint_importSearch =>
      'البحث عن مراكز الغوص (مثال: \"PADI\"، \"تايلاند\")';

  @override
  String get diveCenters_hint_latitude => 'مثال: 10.4613';

  @override
  String get diveCenters_hint_longitude => 'مثال: 99.8359';

  @override
  String get diveCenters_hint_name => 'أدخل اسم مركز الغوص';

  @override
  String get diveCenters_hint_notes => 'أي معلومات إضافية...';

  @override
  String get diveCenters_hint_phone => '+1 234 567 890';

  @override
  String get diveCenters_hint_postalCode => 'مثال: 83100';

  @override
  String get diveCenters_hint_stateProvince => 'مثال: بوكيت';

  @override
  String get diveCenters_hint_street => 'مثال: 123 شارع الشاطئ';

  @override
  String get diveCenters_hint_website => 'www.divecenter.com';

  @override
  String diveCenters_import_fromDatabase(Object count) {
    return 'استيراد من قاعدة البيانات ($count)';
  }

  @override
  String diveCenters_import_myCenters(Object count) {
    return 'مراكزي ($count)';
  }

  @override
  String get diveCenters_import_noResults => 'لا توجد نتائج';

  @override
  String diveCenters_import_noResultsMessage(Object query) {
    return 'لم يتم العثور على مراكز غوص لـ \"$query\". جرب مصطلح بحث مختلف.';
  }

  @override
  String get diveCenters_import_searchDescription =>
      'البحث عن مراكز الغوص والمتاجر والنوادي من قاعدة بيانات المشغلين حول العالم.';

  @override
  String get diveCenters_import_searchError => 'خطأ في البحث';

  @override
  String get diveCenters_import_searchHint =>
      'جرب البحث بالاسم أو البلد أو وكالة الاعتماد.';

  @override
  String get diveCenters_import_searchTitle => 'البحث عن مراكز الغوص';

  @override
  String get diveCenters_label_alreadyImported => 'مستورد بالفعل';

  @override
  String diveCenters_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غطسة',
      one: 'غطسة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_label_email => 'البريد الإلكتروني';

  @override
  String get diveCenters_label_imported => 'مستورد';

  @override
  String get diveCenters_label_locationNotSet => 'الموقع غير محدد';

  @override
  String get diveCenters_label_locationUnknown => 'الموقع غير معروف';

  @override
  String get diveCenters_label_phone => 'الهاتف';

  @override
  String get diveCenters_label_saved => 'محفوظ';

  @override
  String diveCenters_label_source(Object source) {
    return 'المصدر: $source';
  }

  @override
  String get diveCenters_label_website => 'الموقع الإلكتروني';

  @override
  String get diveCenters_map_addCoordinatesHint =>
      'أضف الإحداثيات إلى مراكز الغوص لرؤيتها على الخريطة';

  @override
  String get diveCenters_map_noCoordinates => 'لا توجد مراكز غوص مع إحداثيات';

  @override
  String get diveCenters_picker_newCenter => 'مركز غوص جديد';

  @override
  String get diveCenters_picker_title => 'اختيار مركز الغوص';

  @override
  String diveCenters_search_noResults(Object query) {
    return 'لا توجد نتائج لـ \"$query\"';
  }

  @override
  String get diveCenters_search_prompt => 'البحث عن مراكز الغوص';

  @override
  String get diveCenters_section_address => 'العنوان';

  @override
  String get diveCenters_section_affiliations => 'الانتماءات';

  @override
  String get diveCenters_section_basicInfo => 'المعلومات الأساسية';

  @override
  String get diveCenters_section_contact => 'الاتصال';

  @override
  String get diveCenters_section_contactInfo => 'معلومات الاتصال';

  @override
  String get diveCenters_section_gpsCoordinates => 'إحداثيات GPS';

  @override
  String get diveCenters_section_notes => 'ملاحظات';

  @override
  String get diveCenters_snackbar_coordinatesFound =>
      'تم العثور على الإحداثيات من العنوان';

  @override
  String get diveCenters_snackbar_copiedToClipboard => 'تم النسخ إلى الحافظة';

  @override
  String diveCenters_snackbar_imported(Object name) {
    return 'تم استيراد \"$name\"';
  }

  @override
  String get diveCenters_snackbar_locationCaptured => 'تم التقاط الموقع';

  @override
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'تم التقاط الموقع (±$accuracyم)';
  }

  @override
  String get diveCenters_snackbar_locationSelectedFromMap =>
      'تم اختيار الموقع من الخريطة';

  @override
  String get diveCenters_sort_title => 'ترتيب مراكز الغوص';

  @override
  String get diveCenters_summary_countries => 'البلدان';

  @override
  String get diveCenters_summary_highestRating => 'أعلى تقييم';

  @override
  String get diveCenters_summary_overview => 'نظرة عامة';

  @override
  String get diveCenters_summary_quickActions => 'إجراءات سريعة';

  @override
  String get diveCenters_summary_recentCenters => 'مراكز الغوص الأخيرة';

  @override
  String get diveCenters_summary_selectPrompt =>
      'اختر مركز غوص من القائمة لعرض التفاصيل';

  @override
  String get diveCenters_summary_totalCenters => 'إجمالي المراكز';

  @override
  String get diveCenters_summary_withGps => 'مع GPS';

  @override
  String get diveCenters_title => 'مراكز الغوص';

  @override
  String get diveCenters_title_add => 'إضافة مركز غوص';

  @override
  String get diveCenters_title_edit => 'تعديل مركز الغوص';

  @override
  String get diveCenters_title_import => 'استيراد مركز الغوص';

  @override
  String get diveCenters_tooltip_addNew => 'إضافة مركز غوص جديد';

  @override
  String get diveCenters_tooltip_clearSearch => 'مسح البحث';

  @override
  String get diveCenters_tooltip_edit => 'تعديل مركز الغوص';

  @override
  String get diveCenters_tooltip_fitAllCenters => 'ملاءمة جميع المراكز';

  @override
  String get diveCenters_tooltip_listView => 'عرض القائمة';

  @override
  String get diveCenters_tooltip_mapView => 'عرض الخريطة';

  @override
  String get diveCenters_tooltip_moreOptions => 'المزيد من الخيارات';

  @override
  String get diveCenters_tooltip_search => 'البحث عن مراكز الغوص';

  @override
  String get diveCenters_tooltip_sort => 'ترتيب';

  @override
  String get diveCenters_validation_invalidEmail =>
      'الرجاء إدخال بريد إلكتروني صحيح';

  @override
  String get diveCenters_validation_invalidLatitude => 'خط العرض غير صحيح';

  @override
  String get diveCenters_validation_invalidLongitude => 'خط الطول غير صحيح';

  @override
  String get diveCenters_validation_nameRequired => 'الاسم مطلوب';

  @override
  String get diveComputer_action_setFavorite => 'تعيين كمفضل';

  @override
  String diveComputer_error_generic(Object error) {
    return 'حدث خطأ: $error';
  }

  @override
  String get diveComputer_error_notFound => 'الجهاز غير موجود';

  @override
  String get diveComputer_status_favorite => 'حاسوب الغوص المفضل';

  @override
  String get diveComputer_title => 'حاسوب الغوص';

  @override
  String diveLog_bulkDelete_confirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غوصات',
      one: 'غوصة',
    );
    return 'هل أنت متأكد أنك تريد حذف $count $_temp0؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get diveLog_bulkDelete_restored => 'تمت استعادة الغوصات';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غوصات',
      one: 'غوصة',
    );
    return 'تم حذف $count $_temp0';
  }

  @override
  String get diveLog_bulkDelete_title => 'حذف الغوصات';

  @override
  String get diveLog_bulkDelete_undo => 'تراجع';

  @override
  String get diveLog_bulkEdit_addTags => 'إضافة وسوم';

  @override
  String get diveLog_bulkEdit_addTagsDescription =>
      'إضافة وسوم إلى الغوصات المحددة';

  @override
  String diveLog_bulkEdit_addedTags(int tagCount, int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: 'وسوم',
      one: 'وسم',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'غوصات',
      one: 'غوصة',
    );
    return 'تمت إضافة $tagCount $_temp0 إلى $diveCount $_temp1';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => 'تغيير الرحلة';

  @override
  String get diveLog_bulkEdit_changeTripDescription =>
      'نقل الغوصات المحددة إلى رحلة';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips => 'خطأ في تحميل الرحلات';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return 'فشلت إضافة الوسوم: $error';
  }

  @override
  String diveLog_bulkEdit_failedUpdateTrip(Object error) {
    return 'فشل تحديث الرحلة: $error';
  }

  @override
  String diveLog_bulkEdit_movedToTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غوصات',
      one: 'غوصة',
    );
    return 'تم نقل $count $_temp0 إلى الرحلة';
  }

  @override
  String get diveLog_bulkEdit_noTagsAvailable => 'لا توجد وسوم متاحة.';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate =>
      'لا توجد وسوم متاحة. قم بإنشاء الوسوم أولاً.';

  @override
  String get diveLog_bulkEdit_noTrip => 'بدون رحلة';

  @override
  String get diveLog_bulkEdit_removeFromTrip => 'إزالة من الرحلة';

  @override
  String get diveLog_bulkEdit_removeTags => 'إزالة الوسوم';

  @override
  String get diveLog_bulkEdit_removeTagsDescription =>
      'إزالة الوسوم من الغوصات المحددة';

  @override
  String diveLog_bulkEdit_removedFromTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غوصات',
      one: 'غوصة',
    );
    return 'تمت إزالة $count $_temp0 من الرحلة';
  }

  @override
  String get diveLog_bulkEdit_selectTrip => 'اختيار رحلة';

  @override
  String diveLog_bulkEdit_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غوصات',
      one: 'غوصة',
    );
    return 'تعديل $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_csv => 'CSV';

  @override
  String get diveLog_bulkExport_csvDescription => 'تنسيق جداول بيانات';

  @override
  String diveLog_bulkExport_failed(Object error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get diveLog_bulkExport_pdf => 'سجل PDF';

  @override
  String get diveLog_bulkExport_pdfDescription => 'صفحات سجل غوص قابلة للطباعة';

  @override
  String diveLog_bulkExport_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غوصات',
      one: 'غوصة',
    );
    return 'تم تصدير $count $_temp0 بنجاح';
  }

  @override
  String diveLog_bulkExport_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غوصات',
      one: 'غوصة',
    );
    return 'تصدير $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_uddf => 'UDDF';

  @override
  String get diveLog_bulkExport_uddfDescription => 'تنسيق بيانات الغوص العالمي';

  @override
  String get diveLog_ccr_diluent_air => 'هواء';

  @override
  String get diveLog_ccr_hint_loopVolume => 'مثال: 6.0';

  @override
  String get diveLog_ccr_hint_type => 'مثال: Sofnolime';

  @override
  String get diveLog_ccr_label_deco => 'تخفيف ضغط';

  @override
  String get diveLog_ccr_label_he => 'He';

  @override
  String get diveLog_ccr_label_highBottom => 'عالٍ (قاع)';

  @override
  String get diveLog_ccr_label_loopVolume => 'حجم الدائرة';

  @override
  String get diveLog_ccr_label_lowDescAsc => 'منخفض (نزول/صعود)';

  @override
  String get diveLog_ccr_label_n2 => 'N₂';

  @override
  String get diveLog_ccr_label_o2 => 'O₂';

  @override
  String get diveLog_ccr_label_rated => 'المقدّر';

  @override
  String get diveLog_ccr_label_remaining => 'المتبقي';

  @override
  String get diveLog_ccr_label_type => 'النوع';

  @override
  String get diveLog_ccr_sectionDiluentGas => 'غاز المخفف';

  @override
  String get diveLog_ccr_sectionScrubber => 'المرشح الكيميائي';

  @override
  String get diveLog_ccr_sectionSetpoints => 'نقاط الضبط (bar)';

  @override
  String get diveLog_ccr_title => 'إعدادات CCR';

  @override
  String diveLog_collapsible_semantics_collapse(Object title) {
    return 'طي قسم $title';
  }

  @override
  String diveLog_collapsible_semantics_expand(Object title) {
    return 'توسيع قسم $title';
  }

  @override
  String get diveLog_combine_confirm => 'دمج في غوصة واحدة';

  @override
  String get diveLog_combine_dataNote =>
      'تُؤخذ التفاصيل من أقدم غوصة، مع تعبئة الفراغات من الغوصات اللاحقة. يتم دمج الملاحظات. يتم الاحتفاظ بجميع الأسطوانات والمعدات ورفقاء الغوص والوسوم والمشاهدات.';

  @override
  String get diveLog_combine_error => 'تعذّر دمج الغوصات. لم يتغيّر شيء.';

  @override
  String diveLog_combine_gapLabel(String duration) {
    return 'فترة السطح: $duration';
  }

  @override
  String get diveLog_combine_longSurfaceWarning =>
      'قد تتجاوز فترة سطح واحدة أو أكثر 30 دقيقة. قد تكون هذه غوصات منفصلة بدلاً من غوصة واحدة متواصلة.';

  @override
  String get diveLog_combine_mixedDivers =>
      'الغوصات المحددة تخص غواصين مختلفين ولا يمكن دمجها.';

  @override
  String get diveLog_combine_profilePreview => 'الملف المدمج';

  @override
  String diveLog_combine_previewIntro(int count) {
    return 'ستُدمَج هذه الغوصات الـ $count في غوصة واحدة متواصلة. تتحول الفجوات بينها إلى وقت على السطح.';
  }

  @override
  String diveLog_combine_resultSummary(
    String runtime,
    String maxDepth,
    String bottomTime,
  ) {
    return 'النتيجة: $runtime إجمالاً، أقصى عمق $maxDepth، ووقت القاع $bottomTime';
  }

  @override
  String diveLog_combine_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غوصات',
      one: 'غوصة',
    );
    return 'تم دمج $count $_temp0';
  }

  @override
  String get diveLog_combine_title => 'دمج الغوصات';

  @override
  String get diveLog_combine_undoError => 'تعذّر التراجع عن الدمج.';

  @override
  String get diveLog_combine_undone => 'تم التراجع عن الدمج';

  @override
  String get diveLog_computerSource_badge_primary => 'أساسي';

  @override
  String get diveLog_consolidate_confirm =>
      'الاحتفاظ بها كغوصة واحدة بجهازي كمبيوتر';

  @override
  String get diveLog_consolidate_error_generic =>
      'تعذّر دمج الغوصات. لم يتغيّر أي شيء.';

  @override
  String get diveLog_consolidate_error_notOverlapping =>
      'هاتان الغوصتان لا تتداخلان زمنيًا، لذا لا يمكن دمجهما كغوصة واحدة.';

  @override
  String get diveLog_consolidate_error_sameComputer =>
      'هاتان الغوصتان من نفس كمبيوتر الغوص ولا يمكن دمجهما بهذه الطريقة.';

  @override
  String get diveLog_consolidate_selectPrimary => 'كمبيوتر الغوص الأساسي';

  @override
  String get diveLog_consolidate_snackbar =>
      'تم دمج الغوصة كجهاز كمبيوتر إضافي.';

  @override
  String get diveLog_consolidate_undoError => 'تعذّر التراجع عن الدمج.';

  @override
  String get diveLog_consolidate_undone => 'تم التراجع عن الدمج';

  @override
  String diveLog_mergeDialog_confirmSubtitle(String time) {
    return 'سيتم دمج الغوصة في الساعة $time مع هذه الغوصة.';
  }

  @override
  String get diveLog_mergeDialog_confirmTitle => 'تأكيد الدمج';

  @override
  String get diveLog_mergeDialog_empty =>
      'لم يتم العثور على غوصات أخرى في هذا اليوم.';

  @override
  String get diveLog_mergeDialog_explanation =>
      'سيتم دمج ملف هذه الغوصة والأسطوانات والضغوط والأحداث والوسوم ورفقاء الغوص والمشاهدات في هذه الغوصة كمصدر كمبيوتر إضافي. يمكن التراجع عن هذا الإجراء باستخدام \'إلغاء ربط الكمبيوتر\'.';

  @override
  String diveLog_mergeDialog_loadError(String error) {
    return 'خطأ في تحميل الغوصات: $error';
  }

  @override
  String get diveLog_mergeDialog_merge => 'دمج';

  @override
  String get diveLog_mergeDialog_next => 'التالي';

  @override
  String get diveLog_mergeDialog_subtitle =>
      'اختر غوصة من نفس اليوم لدمجها كجهاز كمبيوتر إضافي.';

  @override
  String get diveLog_mergeDialog_title => 'دمج مع غوصة أخرى';

  @override
  String get diveLog_mergeDialog_whatThisDoes => 'ما الذي يفعله هذا';

  @override
  String get diveLog_computerSheet_description =>
      'اختر ملف أي كمبيوتر تريد التحرير منه.';

  @override
  String get diveLog_computerSheet_title => 'اختيار الملف الأولي';

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return 'متوسط: $depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => 'أساسي';

  @override
  String get diveLog_cylinderSac_noSac => 'SAC: --';

  @override
  String get diveLog_cylinderSac_tooltip_aiData =>
      'استخدام بيانات جهاز الإرسال AI لدقة أعلى';

  @override
  String get diveLog_cylinderSac_tooltip_basicData =>
      'محسوب من ضغط البداية والنهاية';

  @override
  String get diveLog_deco_badge_deco => 'تخفيف ضغط';

  @override
  String get diveLog_deco_badge_noDeco => 'بدون تخفيف ضغط';

  @override
  String get diveLog_deco_label_ceiling => 'السقف';

  @override
  String get diveLog_deco_label_leading => 'الأنسجة الرائدة';

  @override
  String get diveLog_deco_label_gf99 => 'GF99';

  @override
  String get diveLog_deco_label_surfGf => 'SurfGF';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_time => 'الوقت';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String diveLog_deco_gf_chip(Object low, Object high) {
    return 'GF: $low/$high';
  }

  @override
  String diveLog_deco_gf_chipFromSettings(Object low, Object high) {
    return 'GF: $low/$high · إعداداتك';
  }

  @override
  String diveLog_deco_gf_chipRecordedAlgorithm(
    Object algorithm,
    Object low,
    Object high,
  ) {
    return '$algorithm · جرى تحليلها بـ GF $low/$high';
  }

  @override
  String diveLog_deco_gf_semantics(Object low, Object high) {
    return 'معاملات التدرج: منخفض $low، مرتفع $high';
  }

  @override
  String get diveLog_deco_gf_tooltipFromSettings =>
      'لم يسجّل حاسوب الغوص هذا معاملات التدرج الخاصة به، لذا تُحلَّل هذه الغطسة باستخدام المعاملات من إعداداتك.';

  @override
  String diveLog_deco_gf_tooltipRecordedAlgorithm(Object algorithm) {
    return 'حُسبت هذه الغطسة باستخدام $algorithm الذي لا يستخدم معاملات التدرج. يحللها Submersion باستخدام المعاملات من إعداداتك.';
  }

  @override
  String get diveLog_deco_sectionDecoStops => 'توقفات تخفيف الضغط';

  @override
  String get diveLog_deco_sectionTissueLoading => 'تحميل الأنسجة';

  @override
  String get diveLog_deco_semantics_notRequired => 'لا يلزم تخفيف الضغط';

  @override
  String get diveLog_deco_semantics_required => 'يلزم تخفيف الضغط';

  @override
  String get diveLog_deco_tissueFast => 'سريعة';

  @override
  String get diveLog_deco_tissueSlow => 'بطيئة';

  @override
  String get diveLog_deco_title => 'حالة الديكو';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return 'الإجمالي: $time';
  }

  @override
  String get diveLog_delete_cancel => 'إلغاء';

  @override
  String get diveLog_delete_confirm =>
      'لا يمكن التراجع عن هذا الإجراء. سيتم حذف الغوصة وجميع البيانات المرتبطة بها (الملف الشخصي، الأسطوانات، المشاهدات) نهائياً.';

  @override
  String get diveLog_delete_delete => 'حذف';

  @override
  String get diveLog_delete_title => 'حذف الغوصة؟';

  @override
  String get diveLog_detail_appBar => 'تفاصيل الغوصة';

  @override
  String get diveLog_detail_badge_critical => 'حرج';

  @override
  String get diveLog_detail_badge_deco => 'تخفيف ضغط';

  @override
  String get diveLog_detail_badge_noDeco => 'بدون تخفيف ضغط';

  @override
  String get diveLog_detail_badge_warning => 'تحذير';

  @override
  String diveLog_detail_buddyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'زملاء غوص',
      one: 'زميل غوص',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_button_playback => 'تشغيل';

  @override
  String get diveLog_detail_button_rangeAnalysis => 'إحصائيات النطاق';

  @override
  String get diveLog_detail_button_showEnd => 'عرض النهاية';

  @override
  String get diveLog_detail_captureSignature => 'التقاط توقيع المدرب';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return 'عند $timestamp';
  }

  @override
  String diveLog_detail_collapsed_atTimeInfo(
    Object timestamp,
    Object baseInfo,
  ) {
    return 'عند $timestamp • $baseInfo';
  }

  @override
  String diveLog_detail_collapsed_ceiling(Object value) {
    return 'السقف: $value';
  }

  @override
  String diveLog_detail_collapsed_cnsMaxPpO2(Object cns, Object maxPpO2) {
    return 'CNS: $cns • أقصى ppO₂: $maxPpO2';
  }

  @override
  String diveLog_detail_collapsed_cnsMaxPpO2AtTime(
    Object cns,
    Object maxPpO2,
    Object timestamp,
    Object ppO2,
  ) {
    return 'CNS: $cns • أقصى ppO₂: $maxPpO2 • عند $timestamp: $ppO2 بار';
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
      other: 'عناصر',
      one: 'عنصر',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_errorLoading => 'خطأ في تحميل الغوصة';

  @override
  String get diveLog_detail_label_airTemp => 'درجة حرارة الهواء';

  @override
  String get diveLog_detail_label_avgDepth => 'متوسط العمق';

  @override
  String get diveLog_detail_label_buddy => 'زميل الغوص';

  @override
  String get diveLog_detail_label_currentDirection => 'اتجاه التيار';

  @override
  String get diveLog_detail_label_currentStrength => 'قوة التيار';

  @override
  String get diveLog_detail_label_diveComputer => 'حاسوب الغوص';

  @override
  String get diveLog_detail_label_serialNumber => 'الرقم التسلسلي';

  @override
  String get diveLog_detail_label_firmwareVersion => 'إصدار البرنامج الثابت';

  @override
  String get diveLog_detail_label_diveMaster => 'مدرب الغوص الرئيسي';

  @override
  String get diveLog_detail_label_diveType => 'نوع الغوصة';

  @override
  String get diveLog_detail_label_elevation => 'الارتفاع';

  @override
  String get diveLog_detail_label_entry => 'الدخول:';

  @override
  String get diveLog_detail_label_entryMethod => 'طريقة الدخول';

  @override
  String get diveLog_detail_label_exit => 'الخروج:';

  @override
  String get diveLog_detail_label_exitMethod => 'طريقة الخروج';

  @override
  String get diveLog_detail_label_gradientFactors => 'عوامل التدرج';

  @override
  String get diveLog_detail_label_height => 'الارتفاع';

  @override
  String get diveLog_detail_label_highTide => 'المد العالي';

  @override
  String get diveLog_detail_label_lowTide => 'الجزر المنخفض';

  @override
  String get diveLog_detail_label_ppO2AtPoint => 'ppO₂ عند النقطة المحددة:';

  @override
  String get diveLog_detail_label_rateOfChange => 'معدل التغير';

  @override
  String get diveLog_detail_label_sacRate => 'معدل SAC';

  @override
  String get diveLog_detail_label_state => 'الحالة';

  @override
  String get diveLog_detail_label_surfaceInterval => 'فترة السطح';

  @override
  String get diveLog_detail_label_surfacePressure => 'ضغط السطح';

  @override
  String get diveLog_detail_label_swellHeight => 'ارتفاع الموج';

  @override
  String get diveLog_detail_label_total => 'الإجمالي:';

  @override
  String get diveLog_detail_label_visibility => 'الرؤية';

  @override
  String get diveLog_detail_label_waterType => 'نوع المياه';

  @override
  String get diveLog_detail_menu_delete => 'حذف';

  @override
  String get diveLog_detail_menu_export => 'تصدير';

  @override
  String get diveLog_detail_menu_openFullPage => 'فتح الصفحة الكاملة';

  @override
  String get diveLog_detail_noNotes => 'لا توجد ملاحظات لهذه الغوصة.';

  @override
  String get diveLog_detail_notFound => 'الغوصة غير موجودة';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count نقطة';
  }

  @override
  String get diveLog_detail_section_altitudeDive => 'غوصة ارتفاع';

  @override
  String get diveLog_detail_section_buddies => 'زملاء الغوص';

  @override
  String get diveLog_detail_section_conditions => 'الظروف';

  @override
  String get diveLog_detail_section_customFields => 'Custom Fields';

  @override
  String get diveLog_detail_section_decoStatus => 'حالة الديكو';

  @override
  String get diveLog_detail_section_details => 'التفاصيل';

  @override
  String get diveLog_detail_section_diveProfile => 'ملف الغوصة';

  @override
  String get diveLog_detail_section_equipment => 'المعدات';

  @override
  String get diveLog_detail_section_marineLife => 'الحياة البحرية';

  @override
  String get diveLog_detail_section_notes => 'الملاحظات';

  @override
  String get diveLog_detail_section_oxygenToxicity => 'سمية الأكسجين';

  @override
  String get diveLog_detail_section_sacRateBySegment => 'معدل SAC حسب القطاع';

  @override
  String get diveLog_detail_section_tags => 'الوسوم';

  @override
  String get diveLog_detail_section_cylinders => 'الأسطوانات';

  @override
  String get diveLog_detail_section_tide => 'المد والجزر';

  @override
  String get diveLog_detail_section_trainingSignature => 'توقيع التدريب';

  @override
  String get diveLog_detail_section_weight => 'الأثقال';

  @override
  String get diveLog_detail_signatureDescription =>
      'انقر لإضافة توثيق المدرب لهذه الغوصة التدريبية';

  @override
  String get diveLog_detail_soloDive => 'غوصة منفردة أو لم يتم تسجيل زملاء غوص';

  @override
  String diveLog_detail_speciesCount(Object count) {
    return '$count أنواع';
  }

  @override
  String get diveLog_detail_stat_bottomTime => 'وقت القاع';

  @override
  String get diveLog_detail_stat_maxDepth => 'أقصى عمق';

  @override
  String get diveLog_detail_stat_runtime => 'وقت التشغيل';

  @override
  String get diveLog_detail_stat_waterTemp => 'درجة حرارة الماء';

  @override
  String diveLog_detail_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'وسوم',
      one: 'وسم',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_tideCalculated => 'محسوب من نموذج المد والجزر';

  @override
  String get diveLog_detail_tooltip_addToFavorites => 'إضافة إلى المفضلة';

  @override
  String get diveLog_detail_tooltip_edit => 'تعديل';

  @override
  String get diveLog_detail_tooltip_editDive => 'تعديل الغوصة';

  @override
  String get diveLog_detail_tooltip_previousDive => 'Previous dive';

  @override
  String get diveLog_detail_tooltip_nextDive => 'Next dive';

  @override
  String get diveLog_detail_tooltip_exportProfileImage => 'تصدير الملف كصورة';

  @override
  String get diveLog_detail_tooltip_removeFromFavorites => 'إزالة من المفضلة';

  @override
  String get diveLog_detail_tooltip_viewFullscreen => 'عرض بملء الشاشة';

  @override
  String get diveLog_detail_viewSite => 'عرض الموقع';

  @override
  String get diveLog_diveMode_ccrDescription =>
      'جهاز إعادة تنفس دائرة مغلقة بضغط ppO₂ ثابت';

  @override
  String get diveLog_diveMode_gaugeDescription =>
      'العمق والوقت فقط؛ بدون تتبع الغاز أو تخفيف الضغط';

  @override
  String get diveLog_diveMode_ocDescription =>
      'غوص دائرة مفتوحة قياسي مع أسطوانات';

  @override
  String get diveLog_diveMode_scrDescription =>
      'جهاز إعادة تنفس شبه مغلق بضغط ppO₂ متغير';

  @override
  String get diveLog_diveMode_title => 'وضع الغوص';

  @override
  String get diveLog_editSighting_count => 'العدد';

  @override
  String get diveLog_editSighting_notes => 'ملاحظات';

  @override
  String get diveLog_editSighting_notesHint => 'الحجم، السلوك، الموقع...';

  @override
  String get diveLog_editSighting_remove => 'إزالة';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return 'إزالة $name من هذه الغوصة؟';
  }

  @override
  String get diveLog_editSighting_removeTitle => 'إزالة المشاهدة؟';

  @override
  String get diveLog_editSighting_save => 'حفظ التغييرات';

  @override
  String get diveLog_edit_add => 'إضافة';

  @override
  String get diveLog_edit_addCustomField => 'Add Field';

  @override
  String get diveLog_edit_addTank => 'إضافة أسطوانة';

  @override
  String get diveLog_edit_addWeightEntry => 'إضافة إدخال أثقال';

  @override
  String diveLog_edit_addedGps(Object name) {
    return 'تمت إضافة GPS إلى $name';
  }

  @override
  String get diveLog_edit_appBarEdit => 'تعديل الغوصة';

  @override
  String get diveLog_edit_appBarNew => 'تسجيل غوصة';

  @override
  String get diveLog_edit_cancel => 'إلغاء';

  @override
  String get diveLog_edit_clearAllEquipment => 'مسح الكل';

  @override
  String diveLog_edit_createdSite(Object name) {
    return 'تم إنشاء الموقع: $name';
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
    return 'المدة: $minutes min';
  }

  @override
  String get diveLog_edit_equipmentHint =>
      'انقر \"استخدام طقم\" أو \"إضافة\" لاختيار المعدات';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return 'خطأ في تحميل أنواع الغوص: $error';
  }

  @override
  String get diveLog_edit_gettingLocation => 'جارٍ تحديد الموقع...';

  @override
  String get diveLog_edit_group_buddies => 'الرفاق';

  @override
  String get diveLog_edit_group_conditions => 'الظروف';

  @override
  String get diveLog_edit_group_experience => 'التجربة';

  @override
  String get diveLog_edit_group_gasGear => 'الغاز والمعدات';

  @override
  String get diveLog_edit_group_theDive => 'الغوصة';

  @override
  String get diveLog_edit_group_trip => 'الرحلة';

  @override
  String get diveLog_edit_headerNew => 'تسجيل غوصة جديدة';

  @override
  String get diveLog_edit_invite_buddies => 'إضافة رفاق';

  @override
  String get diveLog_edit_invite_conditions =>
      'إضافة الظروف - الماء والرؤية والطقس';

  @override
  String get diveLog_edit_invite_experience =>
      'إضافة تقييم أو مشاهدات أو ملاحظات أو وسوم';

  @override
  String get diveLog_edit_invite_gasGear =>
      'إضافة الغاز والمعدات - الوضع والأسطوانات والمعدات والأثقال';

  @override
  String get diveLog_edit_invite_trip => 'إضافة رحلة أو مركز غوص';

  @override
  String get diveLog_edit_label_airTemp => 'درجة حرارة الهواء';

  @override
  String get diveLog_edit_label_altitude => 'الارتفاع';

  @override
  String get diveLog_edit_label_avgDepth => 'متوسط العمق';

  @override
  String get diveLog_edit_label_bottomTime => 'وقت القاع';

  @override
  String get diveLog_edit_label_currentDirection => 'اتجاه التيار';

  @override
  String get diveLog_edit_label_currentStrength => 'قوة التيار';

  @override
  String get diveLog_edit_label_diveType => 'نوع الغوصة';

  @override
  String get diveLog_edit_label_diveTypes => 'أنواع الغوص';

  @override
  String get diveLog_edit_label_diveNumber => 'رقم الغوصة';

  @override
  String get diveLog_edit_label_diveName => 'الاسم';

  @override
  String get diveLog_edit_diveNamePlaceholder => 'اسم اختياري لهذه الغطسة';

  @override
  String get diveLog_edit_hint_diveNumber => 'يُعيَّن تلقائياً إذا تُرك فارغاً';

  @override
  String get diveLog_edit_label_entryMethod => 'طريقة الدخول';

  @override
  String get diveLog_edit_label_exitMethod => 'طريقة الخروج';

  @override
  String get diveLog_edit_label_maxDepth => 'أقصى عمق';

  @override
  String get diveLog_edit_label_runtime => 'وقت التشغيل';

  @override
  String get diveLog_edit_label_surfacePressure => 'ضغط السطح';

  @override
  String get diveLog_edit_label_swellHeight => 'ارتفاع الموج';

  @override
  String get diveLog_edit_label_type => 'النوع';

  @override
  String get diveLog_edit_label_visibility => 'الرؤية';

  @override
  String get diveLog_edit_label_waterTemp => 'درجة حرارة الماء';

  @override
  String get diveLog_edit_label_waterType => 'نوع المياه';

  @override
  String get diveLog_edit_marineLifeHint => 'انقر \"إضافة\" لتسجيل المشاهدات';

  @override
  String get diveLog_edit_nearbySitesFirst => 'المواقع القريبة أولاً';

  @override
  String get diveLog_edit_noEquipmentSelected => 'لم يتم اختيار معدات';

  @override
  String get diveLog_edit_noMarineLife => 'لم يتم تسجيل حياة بحرية';

  @override
  String get diveLog_edit_notSpecified => 'غير محدد';

  @override
  String get diveLog_edit_notesHint => 'أضف ملاحظات حول هذه الغوصة...';

  @override
  String get diveLog_edit_overline_tanks => 'الأسطوانات';

  @override
  String get diveLog_edit_profile_draw => 'رسم ملف الغوص';

  @override
  String get diveLog_edit_profile_none => 'غير مسجل';

  @override
  String diveLog_edit_profile_outliers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم اكتشاف $count قيم شاذة محتملة',
      one: 'تم اكتشاف قيمة شاذة محتملة واحدة',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_profile_points(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقاط',
      one: 'نقطة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_row_addSite => 'إضافة موقع';

  @override
  String get diveLog_edit_row_diveCenter => 'مركز الغوص';

  @override
  String get diveLog_edit_row_diveProfile => 'ملف الغوص';

  @override
  String get diveLog_edit_row_entry => 'الدخول';

  @override
  String get diveLog_edit_row_exit => 'الخروج';

  @override
  String get diveLog_edit_row_notSet => 'غير محدد';

  @override
  String get diveLog_edit_row_site => 'الموقع';

  @override
  String get diveLog_edit_row_surfaceInterval => 'فترة السطح';

  @override
  String get diveLog_edit_row_trip => 'الرحلة';

  @override
  String get diveLog_edit_save => 'حفظ';

  @override
  String get diveLog_edit_saveAsSet => 'حفظ كطقم';

  @override
  String diveLog_edit_saveAsSetDialog_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عناصر',
      one: 'عنصر',
    );
    return 'حفظ $count $_temp0 كطقم معدات جديد.';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description => 'الوصف (اختياري)';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint =>
      'مثال: معدات خفيفة للمياه الدافئة';

  @override
  String diveLog_edit_saveAsSetDialog_error(Object error) {
    return 'خطأ في إنشاء الطقم: $error';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_setName => 'اسم الطقم';

  @override
  String get diveLog_edit_saveAsSetDialog_setNameHint => 'مثال: غوص استوائي';

  @override
  String diveLog_edit_saveAsSetDialog_success(Object name) {
    return 'تم إنشاء طقم المعدات \"$name\"';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title => 'حفظ كطقم معدات';

  @override
  String get diveLog_edit_saveAsSetDialog_validation => 'يرجى إدخال اسم الطقم';

  @override
  String get diveLog_edit_section_conditions => 'الظروف';

  @override
  String get diveLog_edit_section_customFields => 'Custom Fields';

  @override
  String get diveLog_edit_section_depthDuration => 'العمق والمدة';

  @override
  String get diveLog_edit_section_diveCenter => 'مركز الغوص';

  @override
  String get diveLog_edit_section_diveSite => 'موقع الغوص';

  @override
  String get diveLog_edit_section_entryTime => 'وقت الدخول';

  @override
  String get diveLog_edit_section_equipment => 'المعدات';

  @override
  String get diveLog_edit_section_exitTime => 'وقت الخروج';

  @override
  String get diveLog_edit_section_marineLife => 'الحياة البحرية';

  @override
  String get diveLog_edit_section_notes => 'الملاحظات';

  @override
  String get diveLog_edit_section_rating => 'التقييم';

  @override
  String get diveLog_edit_section_tags => 'الوسوم';

  @override
  String diveLog_edit_section_tanks(Object count) {
    return 'الأسطوانات ($count)';
  }

  @override
  String get diveLog_edit_section_trainingCourse => 'دورة التدريب';

  @override
  String get diveLog_edit_section_trip => 'الرحلة';

  @override
  String get diveLog_edit_section_weight => 'الأثقال';

  @override
  String get diveLog_edit_select => 'اختيار';

  @override
  String get diveLog_edit_selectDiveCenter => 'اختيار مركز الغوص';

  @override
  String get diveLog_edit_selectDiveSite => 'اختيار موقع الغوص';

  @override
  String get diveLog_edit_selectTrip => 'اختيار رحلة';

  @override
  String diveLog_edit_snackbar_avgDepthCalculated(Object depth) {
    return 'تم حساب متوسط العمق: $depth';
  }

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'تم حساب وقت القاع: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'خطأ في حفظ الغوصة: $error';
  }

  @override
  String diveLog_edit_snackbar_maxDepthCalculated(Object depth) {
    return 'تم حساب أقصى عمق: $depth';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'لا تتوفر بيانات ملف الغوصة';

  @override
  String diveLog_edit_snackbar_runtimeCalculated(Object minutes) {
    return 'تم حساب وقت التشغيل: $minutes min';
  }

  @override
  String get diveLog_edit_snackbar_unableToCalculateAvgDepth =>
      'تعذر حساب متوسط العمق من الملف';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'تعذر حساب وقت القاع من الملف';

  @override
  String get diveLog_edit_snackbar_unableToCalculateMaxDepth =>
      'تعذر حساب أقصى عمق من الملف';

  @override
  String get diveLog_edit_snackbar_unableToCalculateRuntime =>
      'تعذر حساب وقت التشغيل من الملف';

  @override
  String diveLog_edit_summary_items(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عناصر',
      one: 'عنصر واحد',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_summary_notes => 'ملاحظات';

  @override
  String diveLog_edit_summary_species(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أنواع',
      one: 'نوع واحد',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_summary_tanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أسطوانات',
      one: 'أسطوانة واحدة',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return 'فترة السطح: $interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint =>
      'القياسي: 1013 mbar عند مستوى سطح البحر';

  @override
  String get diveLog_edit_tankCard_done => 'تم';

  @override
  String get diveLog_edit_tankCard_edit => 'تحرير';

  @override
  String get diveLog_edit_tankCard_mix => 'الخليط';

  @override
  String get diveLog_edit_tankCard_pressure => 'الضغط';

  @override
  String diveLog_edit_tankCard_title(int number) {
    return 'أسطوانة $number';
  }

  @override
  String get diveLog_edit_tankCard_volume => 'الحجم';

  @override
  String get diveLog_edit_tooltip_calculateFromProfile => 'حساب من ملف الغوصة';

  @override
  String get diveLog_edit_tooltip_clearDiveCenter => 'مسح مركز الغوص';

  @override
  String get diveLog_edit_tooltip_clearSite => 'مسح الموقع';

  @override
  String get diveLog_edit_tooltip_clearTrip => 'مسح الرحلة';

  @override
  String get diveLog_edit_tooltip_removeEquipment => 'إزالة المعدات';

  @override
  String get diveLog_edit_tooltip_removeSighting => 'إزالة المشاهدة';

  @override
  String get diveLog_edit_tooltip_removeWeight => 'إزالة';

  @override
  String get diveLog_edit_trainingCourseHint => 'ربط هذه الغوصة بدورة تدريبية';

  @override
  String diveLog_edit_tripSuggested(Object name) {
    return 'مقترح: $name';
  }

  @override
  String get diveLog_edit_tripUse => 'استخدام';

  @override
  String get diveLog_edit_useSet => 'استخدام طقم';

  @override
  String diveLog_edit_weightTotal(Object total) {
    return 'الإجمالي: $total';
  }

  @override
  String get diveLog_emptyFiltered_clearFilters => 'مسح عوامل التصفية';

  @override
  String get diveLog_emptyFiltered_subtitle =>
      'حاول تعديل أو مسح عوامل التصفية';

  @override
  String get diveLog_emptyFiltered_title => 'لا توجد غوصات تطابق عوامل التصفية';

  @override
  String get diveLog_empty_logFirstDive => 'سجّل أول غوصة لك';

  @override
  String get diveLog_empty_subtitle => 'انقر الزر أدناه لتسجيل أول غوصة لك';

  @override
  String get diveLog_empty_title => 'لم يتم تسجيل غوصات بعد';

  @override
  String get diveLog_equipmentPicker_addFromTab => 'أضف معدات من تبويب المعدات';

  @override
  String get diveLog_equipmentPicker_allSelected =>
      'تم اختيار جميع المعدات بالفعل';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return 'خطأ في تحميل المعدات: $error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => 'لا توجد معدات بعد';

  @override
  String get diveLog_equipmentPicker_removeToAdd =>
      'أزل عناصر لإضافة عناصر مختلفة';

  @override
  String get diveLog_equipmentPicker_title => 'إضافة معدات';

  @override
  String get diveLog_equipmentSetPicker_createHint =>
      'أنشئ أطقم في المعدات > الأطقم';

  @override
  String get diveLog_equipmentSetPicker_emptySet => 'طقم فارغ';

  @override
  String get diveLog_equipmentSetPicker_errorItems => 'خطأ في تحميل العناصر';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return 'خطأ في تحميل أطقم المعدات: $error';
  }

  @override
  String diveLog_equipmentSetPicker_itemsSummary(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عناصر',
      one: 'عنصر واحد',
    );
    return '$_temp0: $names';
  }

  @override
  String get diveLog_equipmentSetPicker_loading => 'جارٍ التحميل...';

  @override
  String get diveLog_equipmentSetPicker_noSets => 'لا توجد أطقم معدات بعد';

  @override
  String get diveLog_equipmentSetPicker_title => 'استخدام طقم معدات';

  @override
  String get diveLog_error_loadingDives => 'خطأ في تحميل الغوصات';

  @override
  String get diveLog_error_retry => 'إعادة المحاولة';

  @override
  String get diveLog_exportImage_captureFailed => 'تعذر التقاط الصورة';

  @override
  String get diveLog_exportImage_generateFailed => 'تعذر إنشاء الصورة';

  @override
  String get diveLog_exportImage_generatingPdf => 'جارٍ إنشاء PDF...';

  @override
  String get diveLog_exportImage_pdfSaved => 'تم حفظ PDF';

  @override
  String get diveLog_exportImage_saveToFiles => 'حفظ في الملفات';

  @override
  String get diveLog_exportImage_saveToFilesDescription =>
      'اختر موقعاً لحفظ الملف';

  @override
  String get diveLog_exportImage_saveToPhotos => 'حفظ في الصور';

  @override
  String get diveLog_exportImage_saveToPhotosDescription =>
      'حفظ الصورة في مكتبة الصور';

  @override
  String get diveLog_exportImage_savedToFiles => 'تم حفظ الصورة';

  @override
  String get diveLog_exportImage_savedToPhotos => 'تم حفظ الصورة في الصور';

  @override
  String get diveLog_exportImage_share => 'مشاركة';

  @override
  String get diveLog_exportImage_shareDescription => 'مشاركة عبر تطبيقات أخرى';

  @override
  String get diveLog_exportImage_titleDetails => 'تصدير صورة تفاصيل الغوصة';

  @override
  String get diveLog_exportImage_titlePdf => 'تصدير PDF';

  @override
  String get diveLog_exportImage_titleProfile => 'تصدير صورة الملف';

  @override
  String get diveLog_export_csv => 'CSV';

  @override
  String get diveLog_export_csvDescription => 'تنسيق جداول بيانات';

  @override
  String get diveLog_export_exporting => 'جارٍ التصدير...';

  @override
  String diveLog_export_failed(Object error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get diveLog_export_pageAsImage => 'الصفحة كصورة';

  @override
  String get diveLog_export_pageAsImageDescription =>
      'لقطة شاشة لتفاصيل الغوصة بالكامل';

  @override
  String get diveLog_export_pdfDescription => 'صفحة سجل غوص قابلة للطباعة';

  @override
  String get diveLog_export_pdfLogbookEntry => 'إدخال سجل PDF';

  @override
  String get diveLog_export_success => 'تم تصدير الغوصة بنجاح';

  @override
  String diveLog_export_titleDiveNumber(Object number) {
    return 'تصدير الغوصة #$number';
  }

  @override
  String get diveLog_export_uddf => 'UDDF';

  @override
  String get diveLog_export_uddfDescription => 'تنسيق بيانات الغوص العالمي';

  @override
  String get diveLog_filterChip_clearAll => 'مسح الكل';

  @override
  String get diveLog_filterChip_favorites => 'المفضلة';

  @override
  String diveLog_filterChip_from(Object date) {
    return 'من $date';
  }

  @override
  String get diveLog_filterChip_noBuddy => 'بدون زميل';

  @override
  String diveLog_filterChip_until(Object date) {
    return 'حتى $date';
  }

  @override
  String get diveLog_filter_allSites => 'جميع المواقع';

  @override
  String get diveLog_filter_allTypes => 'جميع الأنواع';

  @override
  String get diveLog_filter_apply => 'تطبيق عوامل التصفية';

  @override
  String get diveLog_filter_buddyHint => 'البحث باسم زميل الغوص';

  @override
  String get diveLog_filter_buddyName => 'اسم زميل الغوص';

  @override
  String get diveLog_filter_clearAll => 'مسح الكل';

  @override
  String get diveLog_filter_clearDates => 'مسح التواريخ';

  @override
  String get diveLog_filter_clearRating => 'مسح تصفية التقييم';

  @override
  String get diveLog_filter_clearWeekdays => 'مسح أيام الأسبوع';

  @override
  String get diveLog_filter_dateSeparator => 'إلى';

  @override
  String get diveLog_filter_endDate => 'تاريخ الانتهاء';

  @override
  String get diveLog_filter_errorLoadingSites => 'خطأ في تحميل المواقع';

  @override
  String get diveLog_filter_errorLoadingTags => 'خطأ في تحميل الوسوم';

  @override
  String get diveLog_filter_favoritesOnly => 'المفضلة فقط';

  @override
  String get diveLog_filter_gasAir => 'هواء (21%)';

  @override
  String get diveLog_filter_gasAll => 'الكل';

  @override
  String get diveLog_filter_gasNitrox => 'نيتروكس (>21%)';

  @override
  String get diveLog_filter_max => 'الأقصى';

  @override
  String get diveLog_filter_min => 'الأدنى';

  @override
  String get diveLog_filter_noBuddyOnly => 'بدون زميل غوص';

  @override
  String get diveLog_filter_noTagsYet => 'لم يتم إنشاء وسوم بعد';

  @override
  String get diveLog_filter_presetAllTime => 'كل الوقت';

  @override
  String get diveLog_filter_presetLast12Months => 'آخر 12 شهرًا';

  @override
  String get diveLog_filter_presetLastYear => 'العام الماضي';

  @override
  String get diveLog_filter_presetThisYear => 'هذا العام';

  @override
  String get diveLog_filter_sectionBuddy => 'زميل الغوص';

  @override
  String get diveLog_filter_sectionDateRange => 'نطاق التاريخ';

  @override
  String get diveLog_filter_sectionDepthRange => 'نطاق العمق (بالأمتار)';

  @override
  String get diveLog_filter_sectionDiveSite => 'موقع الغوص';

  @override
  String get diveLog_filter_sectionDiveType => 'نوع الغوصة';

  @override
  String get diveLog_filter_sectionDuration => 'المدة (بالدقائق)';

  @override
  String get diveLog_filter_sectionGasMix => 'خليط الغاز (O₂%)';

  @override
  String get diveLog_filter_sectionMinRating => 'الحد الأدنى للتقييم';

  @override
  String get diveLog_filter_sectionTags => 'الوسوم';

  @override
  String get diveLog_filter_sectionWeekdays => 'أيام الأسبوع';

  @override
  String get diveLog_filter_showOnlyFavorites => 'عرض الغوصات المفضلة فقط';

  @override
  String get diveLog_filter_showOnlyNoBuddy => 'عرض الغوصات بدون زميل غوص فقط';

  @override
  String get diveLog_filter_startDate => 'تاريخ البدء';

  @override
  String get diveLog_filter_title => 'تصفية الغوصات';

  @override
  String get diveLog_filter_resizeGrip => 'تغيير حجم لوحة التصفية';

  @override
  String get diveLog_filter_tooltip_close => 'إغلاق التصفية';

  @override
  String get diveLog_fullscreenProfile_close => 'إغلاق ملء الشاشة';

  @override
  String get diveLog_fullscreenProfile_readoutHint =>
      'مرر المؤشر أو اسحب فوق ملف الغوصة';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'ملف الغوصة #$number';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'معدل الصعود';

  @override
  String get diveLog_legend_label_ascentRateLine => 'خط معدل الصعود';

  @override
  String get diveLog_legend_label_ceiling => 'السقف';

  @override
  String get diveLog_legend_label_decoStops => 'Deco stops';

  @override
  String get diveLog_legend_label_cns => 'CNS%';

  @override
  String get diveLog_legend_label_depth => 'العمق';

  @override
  String get diveLog_legend_label_events => 'الأحداث';

  @override
  String get diveLog_legend_label_gasDensity => 'كثافة الغاز';

  @override
  String get diveLog_legend_label_gasSwitches => 'تبديلات الغاز';

  @override
  String get diveLog_legend_label_gfPercent => 'GF%';

  @override
  String get diveLog_legend_label_heartRate => 'معدل نبض القلب';

  @override
  String get diveLog_legend_label_maxDepth => 'أقصى عمق';

  @override
  String get diveLog_legend_label_meanDepth => 'متوسط العمق';

  @override
  String get diveLog_legend_label_mod => 'MOD';

  @override
  String get diveLog_legend_label_ndl => 'NDL';

  @override
  String get diveLog_legend_label_otu => 'OTU';

  @override
  String get diveLog_legend_label_photoMarkers => 'الصور';

  @override
  String get diveLog_legend_label_ppHe => 'ppHe';

  @override
  String get diveLog_legend_label_ppN2 => 'ppN2';

  @override
  String get diveLog_legend_label_ppO2 => 'ppO2';

  @override
  String get diveLog_legend_label_pressure => 'الضغط';

  @override
  String get diveLog_legend_label_pressureThresholds => 'عتبات الضغط';

  @override
  String get diveLog_legend_label_sacRate => 'معدل SAC';

  @override
  String get diveLog_legend_label_showGas => 'الغازات';

  @override
  String get diveLog_legend_label_surfaceGf => 'GF السطح';

  @override
  String get diveLog_legend_label_temp => 'الحرارة';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_legend_source_dc => 'DC';

  @override
  String get diveLog_legend_source_calc => 'محسوب';

  @override
  String get diveLog_chartSection_overlays => 'طبقات إضافية';

  @override
  String get diveLog_chartSection_markers => 'العلامات';

  @override
  String get diveLog_chartSection_decompression => 'تخفيف الضغط';

  @override
  String get diveLog_chartSection_gasAnalysis => 'تحليل الغاز';

  @override
  String get diveLog_chartSection_display => 'العرض';

  @override
  String get diveLog_chartSection_other => 'أخرى';

  @override
  String get diveLog_chartSection_tankPressures => 'ضغوط الأسطوانات';

  @override
  String get diveLog_chartOption_metricsFollowViewport =>
      'إبقاء الطبقات الإضافية ضمن العرض';

  @override
  String get diveLog_pressure_estimatedSuffix => '(تقديري)';

  @override
  String get diveLog_listPage_appBar_diveMap => 'خريطة الغوص';

  @override
  String get diveLog_listPage_compactTitle => 'الغوصات';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get diveLog_listPage_bottomSheet_importFromComputer =>
      'استيراد من حاسوب الغوص';

  @override
  String get diveLog_listPage_bottomSheet_scanPaperLog =>
      'مسح دفتر السجل الورقي';

  @override
  String get ocrImport_scanPage_processing => 'جارٍ قراءة الصفحة...';

  @override
  String get ocrImport_scanPage_pickPhoto => 'اختيار صورة';

  @override
  String get ocrImport_scanPage_takePhoto => 'التقاط صورة';

  @override
  String get ocrImport_scanPage_nothingRead =>
      'تعذرت قراءة الكثير من هذه الصفحة - تُركت الحقول فارغة';

  @override
  String get ocrImport_scanPage_engineMissing =>
      'التعرف على النص غير متوفر. ثبّت Tesseract لمسح السجلات الورقية (مثلاً: sudo apt install tesseract-ocr).';

  @override
  String get ocrImport_editPage_photoAttachFailed =>
      'تم حفظ الغطسة، لكن فشل إرفاق الصفحة الممسوحة';

  @override
  String get diveLog_listPage_bottomSheet_logManually => 'تسجيل غوصة يدويا';

  @override
  String get diveLog_listPage_fab_addDive => 'اضافة غوصة';

  @override
  String get diveLog_listPage_fab_logDive => 'تسجيل غوصة';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'بحث متقدم';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'ترقيم الغوصات';

  @override
  String get diveLog_listPage_menuMatchSites => 'مطابقة الغوصات بالمواقع';

  @override
  String get diveLog_sighting_decreaseCount => 'تقليل العدد';

  @override
  String get diveLog_sighting_increaseCount => 'زيادة العدد';

  @override
  String diveLog_speciesPicker_errorLoading(String error) {
    return 'خطأ في تحميل الأنواع: $error';
  }

  @override
  String get diveRole_builtin_buddy => 'رفيق';

  @override
  String get diveRole_builtin_diveGuide => 'مرشد غوص';

  @override
  String get diveRole_builtin_diveMaster => 'دايف ماستر';

  @override
  String get diveRole_builtin_instructor => 'مدرب';

  @override
  String get diveRole_builtin_rearGuard => 'حارس المؤخرة';

  @override
  String get diveRole_builtin_safetyDiver => 'غواص السلامة';

  @override
  String get diveRole_builtin_solo => 'منفرد';

  @override
  String get diveRole_builtin_student => 'طالب';

  @override
  String get diveRole_builtin_supportDiver => 'غواص دعم';

  @override
  String get diveRoles_addDialog_addButton => 'إضافة';

  @override
  String get diveRoles_addDialog_nameHint => 'مثال: مصور';

  @override
  String get diveRoles_addDialog_nameLabel => 'اسم دور الغوص';

  @override
  String get diveRoles_addDialog_nameValidation => 'الرجاء إدخال اسم';

  @override
  String get diveRoles_addDialog_title => 'إضافة دور غوص مخصص';

  @override
  String get diveRoles_addTooltip => 'إضافة دور غوص';

  @override
  String get diveRoles_appBar_title => 'أدوار الغوص';

  @override
  String get diveRoles_builtInHeader => 'أدوار الغوص المدمجة';

  @override
  String get diveRoles_customHeader => 'أدوار الغوص المخصصة';

  @override
  String diveRoles_deleteDialog_content(Object name) {
    return 'هل أنت متأكد من حذف \"$name\"؟';
  }

  @override
  String get diveRoles_deleteDialog_title => 'حذف دور الغوص؟';

  @override
  String get diveRoles_deleteTooltip => 'حذف دور الغوص';

  @override
  String get diveRoles_renameDialog_title => 'إعادة تسمية دور الغوص';

  @override
  String get diveRoles_renameTooltip => 'إعادة تسمية دور الغوص';

  @override
  String diveRoles_snackbar_added(Object name) {
    return 'تمت إضافة دور الغوص: $name';
  }

  @override
  String diveRoles_snackbar_cannotDelete(Object name) {
    return 'لا يمكن حذف \"$name\" - مستخدم في غطسات موجودة';
  }

  @override
  String diveRoles_snackbar_deleted(Object name) {
    return 'تم حذف دور الغوص: $name';
  }

  @override
  String diveRoles_snackbar_errorAdding(Object error) {
    return 'خطأ في إضافة دور الغوص: $error';
  }

  @override
  String get diveSites_edit_depth_heroMax => 'أقصى عمق';

  @override
  String get diveSites_edit_depth_heroMin => 'أدنى عمق';

  @override
  String get diveSites_edit_group_accessSafety => 'الوصول والسلامة';

  @override
  String get diveSites_edit_group_diveInfo => 'معلومات الغوص';

  @override
  String get diveSites_edit_group_identity => 'الهوية';

  @override
  String get diveSites_edit_group_lifeNotes => 'الحياة البحرية والملاحظات';

  @override
  String get diveSites_edit_group_location => 'الموقع الجغرافي';

  @override
  String get diveSites_edit_invite_accessSafety =>
      'إضافة الوصول أو المواقف أو المرساة أو المخاطر';

  @override
  String get diveSites_edit_invite_diveInfo =>
      'إضافة نطاق العمق أو الصعوبة أو التقييم';

  @override
  String get diveSites_edit_invite_lifeNotes =>
      'إضافة الحياة البحرية أو الملاحظات أو المشاركة';

  @override
  String get diveSites_edit_invite_location => 'إضافة إحداثيات GPS أو الارتفاع';

  @override
  String get diveSites_edit_summary_shared => 'مشترك';

  @override
  String get forms_addSection_prefix => 'إضافة:';

  @override
  String get forms_cancel => 'إلغاء';

  @override
  String get forms_discard_body =>
      'لديك تغييرات غير محفوظة. إذا غادرت الآن فستفقد.';

  @override
  String get forms_discard_discard => 'تجاهل';

  @override
  String get forms_discard_keepEditing => 'متابعة التحرير';

  @override
  String get forms_discard_title => 'تجاهل التغييرات؟';

  @override
  String get forms_save => 'حفظ';

  @override
  String forms_section_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مشاكل',
      one: 'مشكلة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get settings_manage_setupAssistant => 'مساعد الإعداد';

  @override
  String get settings_manage_setupAssistant_subtitle =>
      'مراجعة الوحدات والمظهر وخيارات النسخ الاحتياطي';

  @override
  String get setup_backup_cloudCopy => 'تخزين النسخ الاحتياطية في السحابة';

  @override
  String get setup_backup_frequency => 'التكرار';

  @override
  String get setup_backup_frequency_daily => 'يوميًا';

  @override
  String get setup_backup_frequency_monthly => 'شهريًا';

  @override
  String get setup_backup_frequency_weekly => 'أسبوعيًا';

  @override
  String get setup_backup_scheduleSubtitle =>
      'انسخ بياناتك احتياطيًا وفق جدول زمني';

  @override
  String get setup_backup_scheduleToggle => 'نسخ احتياطي تلقائي';

  @override
  String get setup_backup_subtitle => 'احمِ بياناتك من اليوم الأول.';

  @override
  String get setup_backup_title => 'النسخ الاحتياطي والمزامنة';

  @override
  String get setup_common_back => 'رجوع';

  @override
  String get setup_common_next => 'التالي';

  @override
  String get setup_common_skip => 'تخطي';

  @override
  String get setup_existing_folder_subtitle =>
      'وجّه Submersion إلى مجلد يحتوي بالفعل على مكتبة';

  @override
  String get setup_existing_folder_title => 'فتح مجلد موجود';

  @override
  String get setup_existing_restore_subtitle =>
      'اختر ملف نسخ احتياطي تم تصديره من Submersion';

  @override
  String get setup_existing_restore_title => 'استعادة ملف نسخ احتياطي';

  @override
  String get setup_existing_subtitle =>
      'اختر طريقة تحميل مكتبة Submersion الحالية';

  @override
  String get setup_existing_sync_subtitle =>
      'اسحب مكتبتك من iCloud أو Dropbox أو S3';

  @override
  String get setup_existing_sync_title => 'توصيل مزامنة السحابة';

  @override
  String get setup_existing_title => 'أحضر بياناتك';

  @override
  String get setup_finish_applying => 'جارٍ الإعداد...';

  @override
  String setup_finish_error(Object error) {
    return 'تعذّر إكمال الإعداد: $error';
  }

  @override
  String get setup_finish_feature_diveComputer =>
      'نزّل الغوصات من كمبيوتر الغوص';

  @override
  String get setup_finish_feature_gear => 'تتبّع المعدات ومواعيد الصيانة';

  @override
  String get setup_finish_feature_import =>
      'استورد السجلات من الملفات والتطبيقات الأخرى';

  @override
  String get setup_finish_feature_sites => 'اعرض مواقع الغوص على الخريطة';

  @override
  String get setup_finish_feature_statistics => 'استكشف إحصاءات الغوص';

  @override
  String get setup_finish_start => 'لنبدأ';

  @override
  String get setup_finish_subtitle => 'يمكن لـ Submersion أيضًا...';

  @override
  String get setup_finish_title => 'كل شيء جاهز';

  @override
  String get setup_folder_notFound_message =>
      'المجلد المحدد لا يحتوي على قاعدة بيانات Submersion.';

  @override
  String get setup_folder_notFound_title => 'لا توجد مكتبة في هذا المجلد';

  @override
  String get setup_folder_pick => 'اختيار مجلد';

  @override
  String get setup_folder_switching => 'جارٍ فتح المكتبة...';

  @override
  String get setup_folder_title => 'فتح مجلد موجود';

  @override
  String get setup_profile_nameHint => 'أدخل اسمك';

  @override
  String get setup_profile_nameLabel => 'اسمك';

  @override
  String get setup_profile_nameValidation => 'الرجاء إدخال اسمك';

  @override
  String get setup_profile_subtitle =>
      'أدخل اسمك للبدء. يمكنك إضافة المزيد من التفاصيل لاحقاً.';

  @override
  String get setup_profile_title => 'إنشاء ملفك الشخصي';

  @override
  String get setup_restore_inProgress => 'جارٍ الاستعادة...';

  @override
  String get setup_restore_pick => 'اختيار ملف النسخ الاحتياطي';

  @override
  String get setup_restore_title => 'استعادة النسخة الاحتياطية';

  @override
  String get setup_step_backup => 'نسخ احتياطي';

  @override
  String get setup_step_finish => 'تم';

  @override
  String get setup_step_profile => 'الملف الشخصي';

  @override
  String get setup_step_units => 'الوحدات';

  @override
  String get setup_syncPull_continue => 'متابعة';

  @override
  String get setup_syncPull_incomplete_message =>
      'يحتوي هذا الحساب على مكتبة Submersion لم يكتمل رفعها. دع جهازك الآخر ينهي المزامنة ثم أعد المحاولة.';

  @override
  String get setup_syncPull_incomplete_retry => 'تحقق مرة أخرى';

  @override
  String get setup_syncPull_incomplete_title => 'لم يكتمل رفع المكتبة';

  @override
  String get setup_syncPull_locked_message =>
      'أدخل عبارة مرور التشفير لفتح هذه المكتبة وتنزيلها على هذا الجهاز.';

  @override
  String get setup_syncPull_locked_title => 'هذه المكتبة مشفّرة';

  @override
  String get setup_syncPull_noLibrary_message =>
      'لم يتم العثور على مكتبة Submersion في هذا الحساب. هل تبدأ من جديد؟ سيتم الاحتفاظ باتصالك.';

  @override
  String get setup_syncPull_noLibrary_title => 'لم يتم العثور على مكتبة';

  @override
  String get setup_syncPull_success => 'تم اعتماد المكتبة';

  @override
  String get setup_syncPull_syncing => 'جارٍ سحب مكتبتك...';

  @override
  String get setup_syncPull_title => 'الاتصال والسحب';

  @override
  String get setup_sync_changeProvider => 'تغيير المزوّد';

  @override
  String setup_sync_connectedTo(String provider) {
    return 'متصل بـ $provider';
  }

  @override
  String setup_sync_error(Object error) {
    return 'تعذّر الاتصال: $error';
  }

  @override
  String get setup_sync_header => 'مزامنة السحابة';

  @override
  String get setup_sync_libraryFound_adopt => 'اعتماد المكتبة الحالية';

  @override
  String get setup_sync_libraryFound_keepFresh => 'البدء من جديد';

  @override
  String get setup_sync_libraryFound_message =>
      'يحتوي هذا الحساب بالفعل على مكتبة Submersion. هل تريد اعتمادها بدلًا من البدء من جديد؟';

  @override
  String get setup_sync_libraryFound_title => 'تم العثور على مكتبة موجودة';

  @override
  String get setup_sync_manageInSettings => 'الإدارة في الإعدادات';

  @override
  String get setup_sync_notConnected => 'غير متصل';

  @override
  String get setup_sync_subtitle => 'زامن بياناتك عبر الأجهزة';

  @override
  String get setup_units_advanced => 'ضبط الوحدات';

  @override
  String get setup_units_altitude => 'الارتفاع';

  @override
  String get setup_units_dateFormat => 'تنسيق التاريخ';

  @override
  String get setup_units_depth => 'العمق';

  @override
  String get setup_units_imperial => 'إمبراطوري';

  @override
  String get setup_units_metric => 'متري';

  @override
  String get setup_units_pressure => 'الضغط';

  @override
  String get setup_units_sac => 'معدل SAC';

  @override
  String get setup_units_subtitle =>
      'اختر كيفية عرض القياسات. يمكنك ضبط كل وحدة.';

  @override
  String get setup_units_temperature => 'درجة الحرارة';

  @override
  String get setup_units_timeFormat => 'تنسيق الوقت';

  @override
  String get setup_units_title => 'الوحدات';

  @override
  String get setup_units_volume => 'الحجم';

  @override
  String get setup_units_weight => 'الوزن';

  @override
  String get setup_welcome_existingData_subtitle =>
      'استعد نسخة احتياطية، أو صِل مزامنة السحابة، أو افتح مجلدًا موجودًا';

  @override
  String get setup_welcome_existingData_title =>
      'لديّ بيانات Submersion موجودة';

  @override
  String get setup_welcome_skipSetup => 'تخطي الإعداد';

  @override
  String get setup_welcome_startFresh_subtitle =>
      'أنشئ ملف الغواص الخاص بك واضبط التطبيق';

  @override
  String get setup_welcome_startFresh_title => 'إعداد ملف تعريف جديد';

  @override
  String get setup_welcome_subtitle => 'تسجيل وتحليل متقدم للغوص';

  @override
  String get setup_welcome_title => 'مرحباً بك في Submersion';

  @override
  String get siteMatchReview_title => 'مطابقة المواقع';

  @override
  String siteMatchReview_diveNumber(Object number) {
    return 'الغوصة #$number';
  }

  @override
  String get siteMatchReview_empty => 'لا شيء للمطابقة.';

  @override
  String siteMatchReview_summary(int selected, int review, int none) {
    return '$selected محددة · $review للمراجعة · $none بدون تطابق';
  }

  @override
  String siteMatchReview_confirm(int count) {
    return 'تأكيد $count مطابقات';
  }

  @override
  String get siteMatchReview_cancel => 'إلغاء';

  @override
  String get siteMatchReview_tapToChoose => 'اضغط لاختيار موقع';

  @override
  String siteMatchReview_awayMeters(int meters) {
    return 'على بعد $meters م';
  }

  @override
  String siteMatchReview_depthTo(int meters) {
    return 'حتى $meters م';
  }

  @override
  String siteMatchReview_depthRange(int min, int max) {
    return '$min–$max م';
  }

  @override
  String siteMatchReview_appliedSnack(int dives, int sites) {
    return 'تم ربط $dives غوصات · تمت إضافة $sites مواقع';
  }

  @override
  String get siteMatchReview_applyError => 'تعذّر تطبيق المطابقات';

  @override
  String get siteMatchReview_discardTitle => 'تجاهل المطابقات؟';

  @override
  String get siteMatchReview_discardMessage => 'لن يتم حفظ اختياراتك.';

  @override
  String get siteMatchReview_discardConfirm => 'تجاهل';

  @override
  String get siteMatchReview_keepReviewing => 'متابعة المراجعة';

  @override
  String get siteMatchReview_sourceExisting => 'موقعك';

  @override
  String get siteMatchReview_sourceBundled => 'مستورد';

  @override
  String get siteMatchReview_noNearbySite => 'لا يوجد موقع قريب';

  @override
  String importSummary_matchSitesButton(int count) {
    return 'مطابقة $count غوصات بالمواقع';
  }

  @override
  String get diveLog_listPage_searchFieldLabel => 'البحث في الغوصات...';

  @override
  String diveLog_listPage_searchLimitNotice(int limit) {
    return 'عرض أول $limit نتيجة مطابقة. حسّن البحث لتضييق النتائج.';
  }

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return 'لم يتم العثور على غوصات لـ \"$query\"';
  }

  @override
  String get diveLog_listPage_searchSuggestion =>
      'البحث حسب الموقع أو زميل الغوص أو الملاحظات';

  @override
  String get diveLog_listPage_title => 'سجل الغوص';

  @override
  String get diveLog_listPage_tooltip_back => 'رجوع';

  @override
  String get diveLog_listPage_tooltip_backToDiveList =>
      'العودة إلى قائمة الغوصات';

  @override
  String get diveLog_listPage_tooltip_clearSearch => 'مسح البحث';

  @override
  String get diveLog_listPage_tooltip_filterDives => 'تصفية الغوصات';

  @override
  String get diveLog_listPage_tooltip_listView => 'عرض القائمة';

  @override
  String get diveLog_listPage_tooltip_mapView => 'عرض الخريطة';

  @override
  String get diveLog_listPage_tooltip_searchDives => 'البحث في الغوصات';

  @override
  String get diveLog_listPage_tooltip_sort => 'ترتيب';

  @override
  String get diveLog_listPage_unknownSite => 'موقع غير معروف';

  @override
  String get diveLog_map_emptySubtitle =>
      'سجّل غوصات مع بيانات الموقع لرؤية نشاطك على الخريطة';

  @override
  String get diveLog_map_emptyTitle => 'لا يوجد نشاط غوص لعرضه';

  @override
  String diveLog_map_errorLoading(Object error) {
    return 'خطأ في تحميل بيانات الغوص: $error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => 'احتواء جميع المواقع';

  @override
  String get diveLog_numbering_actions => 'الإجراءات';

  @override
  String get diveLog_numbering_allCorrect => 'جميع الغوصات مرقمة بشكل صحيح';

  @override
  String get diveLog_numbering_assignMissing => 'تعيين الأرقام المفقودة';

  @override
  String get diveLog_numbering_assignMissingDesc =>
      'ترقيم الغوصات غير المرقمة بدءاً من بعد آخر غوصة مرقمة';

  @override
  String get diveLog_numbering_close => 'إغلاق';

  @override
  String get diveLog_numbering_gapsDetected => 'تم اكتشاف فجوات';

  @override
  String get diveLog_numbering_issuesDetected => 'تم اكتشاف مشاكل';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '$count مفقودة';
  }

  @override
  String get diveLog_numbering_renumberAll => 'إعادة ترقيم جميع الغوصات';

  @override
  String get diveLog_numbering_renumberAllDesc =>
      'تعيين أرقام متسلسلة بناءً على تاريخ/وقت الغوصة';

  @override
  String get diveLog_numbering_renumberDialog_cancel => 'إلغاء';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      'سيتم إعادة ترقيم جميع الغوصات بشكل متسلسل بناءً على تاريخ/وقت الدخول. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get diveLog_numbering_renumberDialog_renumber => 'إعادة الترقيم';

  @override
  String get diveLog_numbering_renumberDialog_startFrom => 'البدء من الرقم';

  @override
  String get diveLog_numbering_renumberDialog_title =>
      'إعادة ترقيم جميع الغوصات';

  @override
  String get diveLog_numbering_snackbar_assigned =>
      'تم تعيين أرقام الغوصات المفقودة';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return 'تمت إعادة ترقيم جميع الغوصات بدءاً من #$number';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '$total إجمالي الغوصات • $numbered مرقمة';
  }

  @override
  String get diveLog_numbering_title => 'ترقيم الغوصات';

  @override
  String diveLog_numbering_unnumberedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غوصات',
      one: 'غوصة',
    );
    return '$count $_temp0 بدون أرقام';
  }

  @override
  String get diveLog_o2tox_badge_critical => 'حرج';

  @override
  String get diveLog_o2tox_badge_warning => 'تحذير';

  @override
  String diveLog_o2tox_cnsBadgeLabel(Object value) {
    return 'CNS $value';
  }

  @override
  String get diveLog_o2tox_cnsOxygenClock => 'ساعة أكسجين CNS';

  @override
  String diveLog_o2tox_deltaDive(Object value) {
    return '+$value% في هذه الغوصة';
  }

  @override
  String get diveLog_o2tox_details => 'التفاصيل';

  @override
  String get diveLog_o2tox_label_maxPpO2 => 'أقصى ppO2';

  @override
  String get diveLog_o2tox_label_maxPpO2Depth => 'عمق أقصى ppO2';

  @override
  String get diveLog_o2tox_label_timeAbove14 => 'الوقت فوق 1.4 bar';

  @override
  String get diveLog_o2tox_label_timeAbove16 => 'الوقت فوق 1.6 bar';

  @override
  String get diveLog_o2tox_ofDailyLimit => 'من الحد اليومي';

  @override
  String get diveLog_o2tox_oxygenToleranceUnits => 'وحدات تحمل الأكسجين';

  @override
  String diveLog_o2tox_semantics_cnsBadge(Object value) {
    return 'سمية الأكسجين CNS $value';
  }

  @override
  String get diveLog_o2tox_semantics_criticalWarning =>
      'تحذير حرج لسمية الأكسجين';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return 'وحدات تحمل الأكسجين: $value، $percent بالمئة من الحد اليومي';
  }

  @override
  String get diveLog_o2tox_semantics_warning => 'تحذير سمية الأكسجين';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return 'البداية: $value%';
  }

  @override
  String get diveLog_o2tox_title => 'سمية الأكسجين';

  @override
  String get diveLog_playbackStats_deco => 'تخفيف ضغط';

  @override
  String get diveLog_playbackStats_depth => 'العمق';

  @override
  String get diveLog_playbackStats_header => 'إحصائيات مباشرة';

  @override
  String get diveLog_playbackStats_heartRate => 'معدل نبض القلب';

  @override
  String get diveLog_playbackStats_ndl => 'NDL';

  @override
  String get diveLog_playbackStats_ppO2 => 'ppO₂';

  @override
  String get diveLog_playbackStats_pressure => 'الضغط';

  @override
  String get diveLog_playbackStats_temp => 'الحرارة';

  @override
  String get diveLog_playback_sliderLabel => 'موضع التشغيل';

  @override
  String diveLog_playback_speed_label(Object speed) {
    return '${speed}x';
  }

  @override
  String get diveLog_playback_stepThrough => 'تشغيل خطوة بخطوة';

  @override
  String get diveLog_playback_tooltip_back10 => 'رجوع 10 ثوانٍ';

  @override
  String get diveLog_playback_tooltip_exit => 'الخروج من وضع التشغيل';

  @override
  String get diveLog_playback_tooltip_forward10 => 'تقديم 10 ثوانٍ';

  @override
  String get diveLog_playback_tooltip_pause => 'إيقاف مؤقت';

  @override
  String get diveLog_playback_tooltip_play => 'تشغيل';

  @override
  String get diveLog_playback_tooltip_skipEnd => 'الانتقال إلى النهاية';

  @override
  String get diveLog_playback_tooltip_skipStart => 'الانتقال إلى البداية';

  @override
  String get diveLog_playback_tooltip_speed => 'سرعة التشغيل';

  @override
  String diveLog_profile_axisDepth(Object unit) {
    return 'العمق ($unit)';
  }

  @override
  String get diveLog_profile_axisTime => 'الوقت (min)';

  @override
  String get diveLog_profile_emptyState => 'لا تتوفر بيانات ملف الغوصة';

  @override
  String get diveLog_profile_rightAxis_none => 'لا شيء';

  @override
  String get diveLog_profile_semantics_changeRightAxis =>
      'تغيير مقياس المحور الأيمن';

  @override
  String get diveLog_profile_semantics_chart =>
      'مخطط ملف الغوصة، قم بالتكبير بالضم';

  @override
  String get diveLog_profile_semantics_photoMarker => 'علامة صورة';

  @override
  String get diveLog_profile_tooltip_moreOptions => 'خيارات مخطط إضافية';

  @override
  String get diveLog_profile_tooltip_resetZoom => 'إعادة تعيين التكبير';

  @override
  String get diveLog_profile_tooltip_zoomIn => 'تكبير';

  @override
  String get diveLog_profile_tooltip_zoomOut => 'تصغير';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return 'تكبير: ${level}x • اضم أو مرر للتكبير، اسحب للتحريك';
  }

  @override
  String get diveLog_rangeSelection_exitRange => 'الخروج من النطاق';

  @override
  String get diveLog_rangeSelection_selectRange => 'تحديد النطاق';

  @override
  String get diveLog_rangeSelection_semantics_adjust => 'ضبط تحديد النطاق';

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
  String get diveLog_rangeStats_title => 'إحصائيات النطاق';

  @override
  String get diveLog_rangeStats_tooltip_close => 'إغلاق تحليل النطاق';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return 'FO₂ الدائرة المحسوب: $value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => 'مثال: 0.33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => 'نسبة الإضافة';

  @override
  String get diveLog_scr_label_assumedVo2 => 'VO₂ المفترض';

  @override
  String get diveLog_scr_label_avg => 'متوسط';

  @override
  String get diveLog_scr_label_injectionRate => 'معدل الحقن';

  @override
  String get diveLog_scr_label_max => 'الأقصى';

  @override
  String get diveLog_scr_label_min => 'الأدنى';

  @override
  String get diveLog_scr_label_orificeSize => 'حجم الفتحة';

  @override
  String get diveLog_scr_sectionCmf => 'معاملات CMF';

  @override
  String get diveLog_scr_sectionEscr => 'معاملات ESCR';

  @override
  String get diveLog_scr_sectionMeasuredLoopO2 => 'قياس O₂ في الحلقة (اختياري)';

  @override
  String get diveLog_scr_sectionPascr => 'معاملات PASCR';

  @override
  String get diveLog_scr_sectionScrType => 'نوع SCR';

  @override
  String get diveLog_scr_sectionSupplyGas => 'غاز الإمداد';

  @override
  String get diveLog_scr_title => 'إعدادات SCR';

  @override
  String get diveLog_search_allCenters => 'جميع المراكز';

  @override
  String get diveLog_search_allTrips => 'جميع الرحلات';

  @override
  String get diveLog_search_appBar => 'بحث متقدم';

  @override
  String get diveLog_search_cancel => 'إلغاء';

  @override
  String get diveLog_search_clearAll => 'مسح الكل';

  @override
  String get diveLog_search_customFieldKey => 'Custom Field Key';

  @override
  String get diveLog_search_customFieldValue => 'Value contains...';

  @override
  String get diveLog_search_end => 'النهاية';

  @override
  String get diveLog_search_errorLoadingCenters => 'خطأ في تحميل مراكز الغوص';

  @override
  String get diveLog_search_errorLoadingDiveTypes => 'خطأ في تحميل أنواع الغوص';

  @override
  String get diveLog_search_errorLoadingTrips => 'خطأ في تحميل الرحلات';

  @override
  String get diveLog_search_filter_any => 'أي';

  @override
  String get diveLog_search_gasTrimix => 'ترايمكس (<21% O₂)';

  @override
  String get diveLog_search_label_deco => 'تخفيف الضغط';

  @override
  String get diveLog_search_label_depthRange => 'نطاق العمق (m)';

  @override
  String get diveLog_search_label_diveCenter => 'مركز الغوص';

  @override
  String get diveLog_search_label_diveSite => 'موقع غوص';

  @override
  String get diveLog_search_label_diveType => 'نوع الغوصة';

  @override
  String get diveLog_search_label_durationRange => 'نطاق المدة (min)';

  @override
  String get diveLog_search_label_trip => 'رحلة';

  @override
  String get diveLog_search_search => 'بحث';

  @override
  String get diveLog_search_section_conditions => 'الظروف';

  @override
  String get diveLog_search_section_dateRange => 'نطاق التاريخ';

  @override
  String get diveLog_search_section_gasEquipment => 'الغاز والمعدات';

  @override
  String get diveLog_search_section_location => 'الموقع';

  @override
  String get diveLog_search_section_organization => 'المنظمة';

  @override
  String get diveLog_search_section_social => 'اجتماعي';

  @override
  String get diveLog_search_start => 'البداية';

  @override
  String diveLog_selection_countSelected(Object count) {
    return '$count محدد';
  }

  @override
  String get diveLog_selection_tooltip_combine => 'دمج';

  @override
  String get diveLog_selection_tooltip_delete => 'حذف المحدد';

  @override
  String get diveLog_selection_tooltip_deselectAll => 'إلغاء تحديد الكل';

  @override
  String get diveLog_selection_tooltip_edit => 'تعديل المحدد';

  @override
  String get diveLog_selection_tooltip_exit => 'الخروج من التحديد';

  @override
  String get diveLog_selection_tooltip_export => 'تصدير المحدد';

  @override
  String get diveLog_selection_tooltip_selectAll => 'تحديد الكل';

  @override
  String get diveLog_selection_tooltip_selectDateRange =>
      'التحديد حسب نطاق التاريخ';

  @override
  String get diveLog_sighting_add => 'إضافة';

  @override
  String get diveLog_sighting_cancel => 'إلغاء';

  @override
  String get diveLog_sighting_notesHint => 'مثال: الحجم، السلوك، الموقع...';

  @override
  String get diveLog_sighting_notesOptional => 'ملاحظات (اختياري)';

  @override
  String get diveLog_sitePicker_addDiveSite => 'إضافة موقع غوص';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return '$distance km بعيداً';
  }

  @override
  String diveLog_sitePicker_distanceAway(String distance) {
    return '$distance بعيداً';
  }

  @override
  String get diveLog_sitePicker_sortedByDiveDistance =>
      'مرتبة حسب المسافة من هذه الغطسة';

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return '$distance m بعيداً';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return 'خطأ في تحميل المواقع: $error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => 'موقع غوص جديد';

  @override
  String get diveLog_sitePicker_noSites => 'لا توجد مواقع غوص بعد';

  @override
  String get diveLog_sitePicker_sortedByDistance => 'مرتبة حسب المسافة';

  @override
  String get diveLog_sitePicker_title => 'اختر موقع غوص';

  @override
  String get diveLog_sort_title => 'ترتيب الغوصات';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return 'إضافة \"$name\" كنوع جديد';
  }

  @override
  String get diveLog_speciesPicker_noResults => 'لم يتم العثور على أنواع';

  @override
  String get diveLog_speciesPicker_noSpecies => 'لا توجد أنواع متاحة';

  @override
  String get diveLog_speciesPicker_searchHint => 'البحث عن الأنواع...';

  @override
  String get diveLog_speciesPicker_title => 'إضافة حياة بحرية';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch => 'مسح البحث';

  @override
  String get diveLog_summary_action_importComputer => 'استيراد من الكمبيوتر';

  @override
  String get diveLog_summary_action_logDive => 'تسجيل غوصة';

  @override
  String get diveLog_summary_action_viewStats => 'عرض الإحصائيات';

  @override
  String diveLog_summary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غوصات',
      one: 'غوصة',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_summary_overview => 'نظرة عامة';

  @override
  String get diveLog_summary_record_coldest => 'أبرد غوصة';

  @override
  String get diveLog_summary_record_deepest => 'أعمق غوصة';

  @override
  String get diveLog_summary_record_longest => 'أطول غوصة';

  @override
  String get diveLog_summary_record_warmest => 'أدفأ غوصة';

  @override
  String get diveLog_summary_section_mostVisited => 'المواقع الأكثر زيارة';

  @override
  String get diveLog_summary_section_quickActions => 'إجراءات سريعة';

  @override
  String get diveLog_summary_section_records => 'الأرقام القياسية الشخصية';

  @override
  String get diveLog_summary_selectDive => 'اختر غوصة من القائمة لعرض التفاصيل';

  @override
  String get diveLog_summary_stat_avgMaxDepth => 'متوسط أقصى عمق';

  @override
  String get diveLog_summary_stat_avgWaterTemp => 'متوسط حرارة الماء';

  @override
  String get diveLog_summary_stat_diveSites => 'مواقع الغوص';

  @override
  String get diveLog_summary_stat_diveTime => 'وقت الغوص';

  @override
  String get diveLog_summary_stat_maxDepth => 'أقصى عمق';

  @override
  String get diveLog_summary_stat_totalDives => 'إجمالي الغوصات';

  @override
  String get diveLog_summary_title => 'ملخص سجل الغوص';

  @override
  String get diveLog_tank_label_endPressure => 'ضغط النهاية';

  @override
  String get diveLog_tank_label_he => 'He';

  @override
  String get diveLog_tank_label_material => 'المادة';

  @override
  String get diveLog_tank_label_n2 => 'N2';

  @override
  String get diveLog_tank_label_o2 => 'O2';

  @override
  String get diveLog_tank_label_role => 'الدور';

  @override
  String get diveLog_tank_label_startPressure => 'ضغط البداية';

  @override
  String get diveLog_tank_label_tankPreset => 'إعداد الأسطوانة المسبق';

  @override
  String get diveLog_tank_label_volume => 'الحجم';

  @override
  String get diveLog_tank_label_workingPressure => 'ضغط العمل';

  @override
  String get diveLog_tank_mndHelper => 'تعيين لحساب He% تلقائياً';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String diveLog_tank_modMndInfo(Object mod, Object mnd) {
    return 'MOD: $mod (ppO₂ 1.4) | MND: $mnd';
  }

  @override
  String get diveLog_tank_section_gasMix => 'خليط الغاز';

  @override
  String get diveLog_tank_selectPreset => 'اختر إعداداً مسبقاً...';

  @override
  String get diveLog_tank_saveAsPreset => 'حفظ كإعداد مسبق';

  @override
  String get diveLog_tank_saveAsPreset_needSpecs =>
      'أدخل الحجم وضغط العمل أولاً';

  @override
  String get diveLog_tank_saveAsPreset_nameTitle =>
      'حفظ إعداد الأسطوانة المسبق';

  @override
  String get diveLog_tank_saveAsPreset_nameHint => 'مثال: AL80 خاصتي';

  @override
  String diveLog_tank_saveAsPreset_saved(String name) {
    return 'تم حفظ الإعداد المسبق \"$name\"';
  }

  @override
  String diveLog_tank_title(Object number) {
    return 'أسطوانة $number';
  }

  @override
  String get diveLog_tank_tooltip_remove => 'إزالة الأسطوانة';

  @override
  String get diveLog_tissue_label_ceiling => 'السقف';

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
  String get diveLog_tissue_title => 'تحميل الأنسجة';

  @override
  String get diveLog_tooltip_avgCalculated => '(متوسط، محسوب)';

  @override
  String get diveLog_tooltip_ceiling => 'السقف';

  @override
  String get diveLog_tooltip_decoStop => 'Deco stop';

  @override
  String get diveLog_tooltip_cns => 'CNS';

  @override
  String get diveLog_tooltip_density => 'الكثافة';

  @override
  String get diveLog_tooltip_depth => 'العمق';

  @override
  String get diveLog_tooltip_gfPercent => 'GF%';

  @override
  String get diveLog_tooltip_hr => 'HR';

  @override
  String get diveLog_tooltip_marker => 'علامة';

  @override
  String get diveLog_tooltip_mean => 'المتوسط';

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
  String get diveLog_tooltip_press => 'الضغط';

  @override
  String get diveLog_tooltip_rate => 'المعدل';

  @override
  String get diveLog_tooltip_sac => 'SAC';

  @override
  String get diveLog_tooltip_sensor => 'المستشعر';

  @override
  String get diveLog_legend_label_o2Cells => 'خلايا O2';

  @override
  String get diveLog_tooltip_o2CellsTight => 'متقارب';

  @override
  String get diveLog_tooltip_o2CellsDrifting => 'منحرف';

  @override
  String get diveLog_tooltip_o2CellsWide => 'متباعد';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'الحرارة';

  @override
  String get diveLog_tooltip_time => 'الوقت';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get diveLog_sources_row_metric => 'المقياس';

  @override
  String get diveLog_sources_row_maxDepth => 'أقصى عمق';

  @override
  String get diveLog_sources_row_avgDepth => 'متوسط العمق';

  @override
  String get diveLog_sources_row_duration => 'المدة';

  @override
  String get diveLog_sources_row_waterTemp => 'حرارة الماء';

  @override
  String get diveLog_sources_row_cns => 'CNS';

  @override
  String get diveLog_sources_row_otu => 'OTU';

  @override
  String get diveLog_sources_row_decoAlgorithm => 'خوارزمية إزالة التشبع';

  @override
  String get diveLog_sources_row_gf => 'GF';

  @override
  String diveLog_sources_minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      one: 'دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_unknownComputer => 'جهاز غير معروف';

  @override
  String get diveLog_sources_manualEntry => 'إدخال يدوي';

  @override
  String get diveLog_sources_importedFile => 'ملف مستورد';

  @override
  String get diveLog_sources_editedSuffix => ' (معدل)';

  @override
  String get diveLog_sources_barLabel => 'المصادر';

  @override
  String get diveLog_sources_menu_setPrimary => 'تعيين كمصدر أساسي';

  @override
  String get diveLog_sources_menu_split => 'فصل إلى غطسة منفصلة';

  @override
  String get diveLog_sources_overlayTooltip => 'عرض على الرسم البياني';

  @override
  String get diveLog_sources_splitDialog_title => 'فصل إلى غطسة منفصلة؟';

  @override
  String get diveLog_sources_splitDialog_body =>
      'سيتم نقل ملف العمق والأحداث والأسطوانات الخاصة بهذا المصدر إلى غطسة جديدة. يبقى سجل الغطسة على هذه الغطسة.';

  @override
  String get diveLog_sources_splitDialog_confirm => 'فصل';

  @override
  String get diveLog_sources_splitDone => 'تم فصل الغطسة';

  @override
  String get diveLog_sources_splitFailed => 'فشل الفصل';

  @override
  String get divePlanner_action_addTank => 'إضافة أسطوانة';

  @override
  String get divePlanner_action_convertToDive => 'تحويل إلى غطسة';

  @override
  String get divePlanner_action_deletePlan => 'حذف الخطة';

  @override
  String get divePlanner_action_editTank => 'تعديل الأسطوانة';

  @override
  String get divePlanner_action_moreOptions => 'المزيد من الخيارات';

  @override
  String get divePlanner_action_quickPlan => 'خطة سريعة';

  @override
  String get divePlanner_action_renamePlan => 'إعادة تسمية الخطة';

  @override
  String get divePlanner_action_reset => 'إعادة تعيين';

  @override
  String get divePlanner_action_resetPlan => 'إعادة تعيين الخطة';

  @override
  String get divePlanner_action_savePlan => 'حفظ الخطة';

  @override
  String get divePlanner_error_cannotConvert =>
      'لا يمكن التحويل: الخطة تحتوي على تحذيرات حرجة';

  @override
  String get divePlanner_error_reserveExceedsTank => 'يتجاوز ضغط الأسطوانة';

  @override
  String get divePlanner_error_reserveMustBePositive => 'يجب أن يكون أكبر من 0';

  @override
  String divePlanner_info_reserveDefault(Object unit, Object value) {
    return 'لم يُدخل — افتراض $value $unit';
  }

  @override
  String get divePlanner_field_hePercent => 'He %';

  @override
  String get divePlanner_field_name => 'الاسم';

  @override
  String get divePlanner_field_o2Percent => 'O₂ %';

  @override
  String get divePlanner_field_planName => 'اسم الخطة';

  @override
  String get divePlanner_field_role => 'الدور';

  @override
  String divePlanner_field_startPressure(Object pressureSymbol) {
    return 'البدء ($pressureSymbol)';
  }

  @override
  String get divePlanner_field_travelGas => 'يُستخدم أيضًا كغاز سفر';

  @override
  String divePlanner_field_volume(Object volumeSymbol) {
    return 'الحجم ($volumeSymbol)';
  }

  @override
  String get divePlanner_hint_tankName => 'أدخل اسم الأسطوانة';

  @override
  String get divePlanner_label_altitude => 'الارتفاع:';

  @override
  String get divePlanner_label_belowMinReserve =>
      'أقل من الحد الأدنى للاحتياطي';

  @override
  String get divePlanner_label_ceiling => 'السقف';

  @override
  String get divePlanner_label_consumption => 'الاستهلاك';

  @override
  String get divePlanner_label_deco => 'DECO';

  @override
  String get divePlanner_label_decoSchedule => 'جدول تخفيف الضغط';

  @override
  String get divePlanner_label_decompression => 'تخفيف الضغط';

  @override
  String divePlanner_label_depthAxis(Object depthSymbol) {
    return 'العمق ($depthSymbol)';
  }

  @override
  String get divePlanner_label_diveProfile => 'ملف الغطسة';

  @override
  String get divePlanner_label_empty => 'فارغ';

  @override
  String get divePlanner_label_gasConsumption => 'استهلاك الغاز';

  @override
  String get divePlanner_label_gfHigh => 'GF عالي';

  @override
  String get divePlanner_label_gfLow => 'GF منخفض';

  @override
  String get divePlanner_label_max => 'الأقصى';

  @override
  String get divePlanner_label_ndl => 'NDL';

  @override
  String get divePlanner_label_planSettings => 'إعدادات الخطة';

  @override
  String get divePlanner_label_remaining => 'المتبقي';

  @override
  String get divePlanner_label_reserve => 'الاحتياطي:';

  @override
  String get divePlanner_label_runtime => 'وقت التشغيل';

  @override
  String get divePlanner_label_sacRate => 'RMV:';

  @override
  String get divePlanner_label_status => 'الحالة';

  @override
  String get divePlanner_label_tanks => 'الأسطوانات';

  @override
  String get divePlanner_label_time => 'الوقت';

  @override
  String get divePlanner_label_timeAxis => 'الوقت (دقيقة)';

  @override
  String get divePlanner_label_tts => 'TTS';

  @override
  String get divePlanner_label_used => 'المستخدم';

  @override
  String get divePlanner_label_warnings => 'التحذيرات';

  @override
  String get divePlanner_legend_ascent => 'الصعود';

  @override
  String get divePlanner_legend_bottom => 'القاع';

  @override
  String get divePlanner_legend_deco => 'تخفيف الضغط';

  @override
  String get divePlanner_legend_descent => 'الهبوط';

  @override
  String get divePlanner_legend_safety => 'السلامة';

  @override
  String get divePlanner_message_addSegmentsForGas =>
      'أضف مقاطع لرؤية توقعات الغاز';

  @override
  String get divePlanner_message_addSegmentsForProfile =>
      'أضف مقاطع لرؤية ملف الغطسة';

  @override
  String get divePlanner_message_convertingPlan =>
      'جارٍ تحويل الخطة إلى غطسة...';

  @override
  String get divePlanner_message_noProfile => 'لا يوجد ملف للعرض';

  @override
  String divePlanner_message_deleteConfirmation(String name) {
    return 'حذف \'$name\'؟';
  }

  @override
  String get divePlanner_message_planDeleted => 'تم حذف الخطة';

  @override
  String get divePlanner_message_planSaved => 'تم حفظ الخطة';

  @override
  String get divePlanner_message_resetConfirmation =>
      'هل أنت متأكد من إعادة تعيين الخطة؟';

  @override
  String divePlanner_semantics_criticalWarning(Object message) {
    return 'تحذير حرج: $message';
  }

  @override
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  ) {
    return 'توقف تخفيف ضغط عند $depth لمدة $duration على $gasMix';
  }

  @override
  String divePlanner_semantics_gasConsumption(
    Object tankName,
    Object gasUsed,
    Object remaining,
    Object percent,
    Object warning,
  ) {
    return '$tankName: $gasUsed مستخدم، $remaining متبقي، $percent مستخدم$warning';
  }

  @override
  String divePlanner_semantics_profileChart(
    Object maxDepth,
    Object totalMinutes,
  ) {
    return 'خطة الغوص، أقصى عمق $maxDepth، إجمالي الوقت $totalMinutes دقيقة';
  }

  @override
  String divePlanner_semantics_warning(Object message) {
    return 'تحذير: $message';
  }

  @override
  String get divePlanner_tab_plan => 'الخطة';

  @override
  String get divePlanner_tab_profile => 'الملف';

  @override
  String get divePlanner_tab_results => 'النتائج';

  @override
  String get divePlanner_warning_ascentRateHigh =>
      'معدل الصعود يتجاوز الحد الآمن';

  @override
  String divePlanner_warning_ascentRateHighWithRate(Object rate) {
    return 'معدل الصعود $rate/دقيقة يتجاوز الحد الآمن';
  }

  @override
  String divePlanner_warning_belowMinReserve(Object reserve) {
    return 'أقل من الحد الأدنى للاحتياطي ($reserve)';
  }

  @override
  String get divePlanner_warning_cnsCritical => 'CNS% يتجاوز 100%';

  @override
  String divePlanner_warning_cnsWarning(Object threshold) {
    return 'CNS% يتجاوز $threshold%';
  }

  @override
  String get divePlanner_warning_endHigh => 'العمق المخدر المكافئ مرتفع جداً';

  @override
  String divePlanner_warning_endHighWithDepth(Object depth) {
    return 'END عند $depth يتجاوز الحد الآمن';
  }

  @override
  String divePlanner_warning_gasLow(Object threshold) {
    return 'الأسطوانة أقل من احتياطي $threshold';
  }

  @override
  String get divePlanner_warning_gasOut => 'الأسطوانة ستكون فارغة';

  @override
  String get divePlanner_warning_minGasViolation =>
      'لم يتم الحفاظ على الحد الأدنى للغاز الاحتياطي';

  @override
  String get divePlanner_warning_modViolation =>
      'تم محاولة تبديل الغاز فوق MOD';

  @override
  String get divePlanner_warning_ndlExceeded =>
      'الغطسة تدخل التزام تخفيف الضغط';

  @override
  String get divePlanner_warning_otuWarning => 'تراكم OTU مرتفع';

  @override
  String divePlanner_warning_ppO2Critical(Object value) {
    return 'ppO₂ عند $value بار يتجاوز الحد الحرج';
  }

  @override
  String divePlanner_warning_ppO2High(Object value) {
    return 'ppO₂ عند $value بار يتجاوز حد التشغيل';
  }

  @override
  String get diveSites_detail_access_accessNotes => 'ملاحظات الوصول';

  @override
  String get diveSites_detail_access_mooring => 'مرسى';

  @override
  String get diveSites_detail_access_parking => 'موقف سيارات';

  @override
  String get diveSites_detail_altitude_elevation => 'الارتفاع';

  @override
  String get diveSites_detail_altitude_pressure => 'الضغط';

  @override
  String get diveSites_detail_coordinatesCopied =>
      'تم نسخ الإحداثيات إلى الحافظة';

  @override
  String get diveSites_detail_deleteDialog_cancel => 'إلغاء';

  @override
  String get diveSites_detail_deleteDialog_confirm => 'حذف';

  @override
  String get diveSites_detail_deleteDialog_content =>
      'هل أنت متأكد من حذف هذا الموقع؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get diveSites_detail_deleteDialog_title => 'حذف الموقع';

  @override
  String get diveSites_detail_deleteMenu_label => 'حذف';

  @override
  String get diveSites_detail_deleteSnackbar => 'تم حذف الموقع';

  @override
  String get diveSites_detail_depth_maximum => 'الأقصى';

  @override
  String get diveSites_detail_depth_minimum => 'الأدنى';

  @override
  String get diveSites_detail_diveCount_one => 'غوصة واحدة مسجلة';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '$count غوصات مسجلة';
  }

  @override
  String get diveSites_detail_diveCount_zero => 'لا توجد غوصات مسجلة بعد';

  @override
  String get diveSites_detail_editTooltip => 'تعديل الموقع';

  @override
  String get diveSites_detail_editTooltipShort => 'تعديل';

  @override
  String diveSites_detail_error_body(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get diveSites_detail_error_title => 'خطأ';

  @override
  String get diveSites_detail_loading_title => 'جارٍ التحميل...';

  @override
  String get diveSites_detail_location_country => 'الدولة';

  @override
  String get diveSites_detail_location_city => 'مدينة';

  @override
  String get diveSites_detail_location_island => 'جزيرة';

  @override
  String get diveSites_detail_location_bodyOfWater => 'مسطح مائي';

  @override
  String get diveSites_detail_location_gpsCoordinates => 'إحداثيات GPS';

  @override
  String get diveSites_detail_location_notSet => 'غير محدد';

  @override
  String get diveSites_detail_location_region => 'المنطقة';

  @override
  String get diveSites_detail_noDepthInfo => 'لا توجد معلومات عن العمق';

  @override
  String get diveSites_detail_noDescription => 'لا يوجد وصف';

  @override
  String get diveSites_detail_noNotes => 'لا توجد ملاحظات';

  @override
  String get diveSites_detail_rating_notRated => 'غير مقيّم';

  @override
  String diveSites_detail_rating_value(Object rating) {
    return '$rating من 5';
  }

  @override
  String get diveSites_detail_section_access => 'الوصول والخدمات اللوجستية';

  @override
  String get diveSites_detail_section_altitude => 'الارتفاع';

  @override
  String get diveSites_detail_section_depthRange => 'نطاق العمق';

  @override
  String get diveSites_detail_section_description => 'الوصف';

  @override
  String get diveSites_detail_section_difficultyLevel => 'مستوى الصعوبة';

  @override
  String get diveSites_detail_section_divesAtSite => 'الغوصات في هذا الموقع';

  @override
  String get diveSites_detail_section_hazards => 'المخاطر والسلامة';

  @override
  String get diveSites_detail_section_location => 'الموقع';

  @override
  String get diveSites_detail_section_notes => 'ملاحظات';

  @override
  String get diveSites_detail_section_rating => 'التقييم';

  @override
  String diveSites_detail_semantics_copyToClipboard(Object label) {
    return 'نسخ $label إلى الحافظة';
  }

  @override
  String get diveSites_detail_semantics_viewDivesAtSite =>
      'عرض الغوصات في هذا الموقع';

  @override
  String get diveSites_detail_semantics_viewFullscreenMap =>
      'عرض الخريطة بملء الشاشة';

  @override
  String get diveSites_detail_siteNotFound_body => 'هذا الموقع لم يعد موجوداً.';

  @override
  String get diveSites_detail_siteNotFound_title => 'الموقع غير موجود';

  @override
  String get diveSites_difficulty_advanced => 'متقدم';

  @override
  String get diveSites_difficulty_beginner => 'مبتدئ';

  @override
  String get diveSites_difficulty_intermediate => 'متوسط';

  @override
  String get diveSites_difficulty_technical => 'تقني';

  @override
  String get diveSites_edit_access_accessNotes_hint =>
      'كيفية الوصول إلى الموقع، نقاط الدخول والخروج، الوصول من الشاطئ أو القارب';

  @override
  String get diveSites_edit_access_accessNotes_label => 'ملاحظات الوصول';

  @override
  String get diveSites_edit_access_mooringNumber_hint => 'مثال: العوامة رقم 12';

  @override
  String get diveSites_edit_access_mooringNumber_label => 'رقم المرسى';

  @override
  String get diveSites_edit_access_parkingInfo_hint =>
      'توفر مواقف السيارات، الرسوم، النصائح';

  @override
  String get diveSites_edit_access_parkingInfo_label => 'معلومات موقف السيارات';

  @override
  String get diveSites_edit_access_entryMethod_label => 'طريقة الدخول';

  @override
  String get diveSites_edit_access_exitMethod_label => 'طريقة الخروج';

  @override
  String diveSites_edit_access_entrySuggestionPair(
    int count,
    String entry,
    String exit,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غطساتك الـ$count هنا: دخول $entry، خروج $exit',
      one: 'غطستك هنا: دخول $entry، خروج $exit',
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
      other: 'غطساتك الـ$count هنا: دخول $entry',
      one: 'غطستك هنا: دخول $entry',
    );
    return '$_temp0';
  }

  @override
  String get diveSites_detail_access_entryMethod => 'الدخول';

  @override
  String get diveSites_detail_access_exitMethod => 'الخروج';

  @override
  String get diveSites_edit_altitude_helperText =>
      'ارتفاع الموقع فوق مستوى سطح البحر (للغوص على ارتفاعات)';

  @override
  String get diveSites_edit_altitude_hint => 'مثال: 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return 'الارتفاع ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => 'ارتفاع غير صالح';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => 'حذف الموقع';

  @override
  String get diveSites_edit_appBar_editSite => 'تعديل الموقع';

  @override
  String get diveSites_edit_appBar_merge => 'دمج';

  @override
  String get diveSites_edit_appBar_mergeSites => 'دمج المواقع';

  @override
  String get diveSites_edit_appBar_newSite => 'موقع جديد';

  @override
  String get diveSites_edit_appBar_save => 'حفظ';

  @override
  String get diveSites_edit_button_addSite => 'إضافة موقع';

  @override
  String get diveSites_edit_button_mergeSites => 'دمج المواقع';

  @override
  String get diveSites_edit_button_saveChanges => 'حفظ التغييرات';

  @override
  String get diveSites_edit_cancel => 'إلغاء';

  @override
  String get diveSites_edit_depth_helperText =>
      'من أقل نقطة عمقاً إلى أعمق نقطة';

  @override
  String get diveSites_edit_depth_maxHint => 'مثال: 30';

  @override
  String diveSites_edit_depth_maxLabel(Object symbol) {
    return 'أقصى عمق ($symbol)';
  }

  @override
  String get diveSites_edit_depth_minHint => 'مثال: 5';

  @override
  String diveSites_edit_depth_minLabel(Object symbol) {
    return 'أدنى عمق ($symbol)';
  }

  @override
  String get diveSites_edit_depth_separator => 'إلى';

  @override
  String get diveSites_edit_discardDialog_content =>
      'لديك تغييرات غير محفوظة. هل أنت متأكد من المغادرة؟';

  @override
  String get diveSites_edit_discardDialog_discard => 'تجاهل';

  @override
  String get diveSites_edit_discardDialog_keepEditing => 'متابعة التعديل';

  @override
  String get diveSites_edit_discardDialog_title => 'تجاهل التغييرات؟';

  @override
  String get diveSites_edit_field_country_label => 'الدولة';

  @override
  String get diveSites_edit_field_city_label => 'مدينة';

  @override
  String get diveSites_edit_field_island_label => 'جزيرة';

  @override
  String get diveSites_edit_field_bodyOfWater_label => 'مسطح مائي';

  @override
  String get diveSites_edit_field_description_hint => 'وصف موجز للموقع';

  @override
  String get diveSites_edit_field_description_label => 'الوصف';

  @override
  String get diveSites_edit_field_notes_hint => 'أي معلومات أخرى عن هذا الموقع';

  @override
  String get diveSites_edit_field_notes_label => 'ملاحظات عامة';

  @override
  String get diveSites_edit_field_region_label => 'المنطقة';

  @override
  String get diveSites_edit_field_siteName_hint => 'مثال: الحفرة الزرقاء';

  @override
  String get diveSites_edit_field_siteName_label => 'اسم الموقع *';

  @override
  String get diveSites_edit_field_siteName_validation =>
      'يرجى إدخال اسم الموقع';

  @override
  String diveSites_similarSite_useHint(Object siteName) {
    return 'مشابه لموقع غوص موجود \"$siteName\". انقر للاستخدام.';
  }

  @override
  String diveSites_similarSite_warning(Object siteName) {
    return 'يوجد بالفعل موقع مشابه: \"$siteName\"';
  }

  @override
  String get diveSites_edit_gps_gettingLocation => 'جارٍ الحصول على الموقع...';

  @override
  String get diveSites_edit_gps_helperText =>
      'اختر طريقة لتحديد الموقع أو ابحث عن الإحداثيات لملء البلد والمنطقة والبلدة والمسطح المائي تلقائيًا';

  @override
  String get diveSites_edit_gps_latitude_hint => 'مثال: 21.4225';

  @override
  String get diveSites_edit_gps_latitude_label => 'خط العرض';

  @override
  String get diveSites_edit_gps_latitude_validation => 'خط عرض غير صالح';

  @override
  String get diveSites_edit_gps_longitude_hint => 'مثال: -86.7542';

  @override
  String get diveSites_edit_gps_longitude_label => 'خط الطول';

  @override
  String get diveSites_edit_gps_longitude_validation => 'خط طول غير صالح';

  @override
  String get diveSites_edit_gps_pickFromMap => 'اختيار من الخريطة';

  @override
  String get diveSites_edit_gps_lookupFromCoordinates => 'البحث من الإحداثيات';

  @override
  String get diveSites_edit_snackbar_lookupNothingFound =>
      'لم يتم العثور على تفاصيل موقع لهذه الإحداثيات';

  @override
  String get diveSites_edit_snackbar_lookupFailed =>
      'فشل البحث عن الموقع. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get diveSites_edit_lookupReplace_title => 'استبدال تفاصيل الموقع؟';

  @override
  String get diveSites_edit_lookupReplace_body =>
      'عثر البحث على قيم مختلفة لهذه الحقول:';

  @override
  String get diveSites_edit_lookupReplace_replace => 'استبدال';

  @override
  String get diveSites_edit_lookupReplace_keep => 'إبقاء';

  @override
  String get diveSites_edit_gps_useMyLocation => 'استخدام موقعي';

  @override
  String get diveSites_edit_hazards_helperText =>
      'أدرج أي مخاطر أو اعتبارات سلامة';

  @override
  String get diveSites_edit_hazards_hint =>
      'مثال: تيارات قوية، حركة قوارب، قناديل بحر، شعاب مرجانية حادة';

  @override
  String get diveSites_edit_hazards_label => 'المخاطر';

  @override
  String get diveSites_edit_marineLife_addButton => 'إضافة';

  @override
  String get diveSites_edit_marineLife_empty => 'لم يتم إضافة أنواع متوقعة';

  @override
  String get diveSites_edit_marineLife_helperText =>
      'الأنواع التي تتوقع رؤيتها في هذا الموقع';

  @override
  String diveSites_edit_merge_confirmBody(int count) {
    return 'سيتم دمج $count موقع في موقع واحد. سيتم جمع الغطسات والوسائط والأنواع المتوقعة تحت الموقع المتبقي. سيتم حذف المواقع الأخرى.';
  }

  @override
  String get diveSites_edit_merge_confirmTitle => 'دمج المواقع';

  @override
  String get diveSites_edit_merge_fieldSourceCycleTooltip =>
      'استخدام القيمة من الموقع المحدد التالي';

  @override
  String diveSites_edit_merge_fieldSourceLabel(
    Object siteName,
    int current,
    int total,
  ) {
    return 'من $siteName ($current/$total)';
  }

  @override
  String get diveSites_edit_merge_fieldSourceMenuTooltip =>
      'حدد القيمة من الموقع المحدد';

  @override
  String get diveSites_edit_merge_marineLifeHelperText =>
      'مجمّعة من جميع المواقع المحددة';

  @override
  String diveSites_edit_merge_loadingErrorBody(Object error) {
    return 'فشل تحميل المواقع: $error';
  }

  @override
  String get diveSites_edit_merge_loadingErrorTitle => 'دمج المواقع';

  @override
  String get diveSites_edit_merge_notEnoughBody =>
      'عدد المواقع غير كافٍ للدمج.';

  @override
  String get diveSites_edit_merge_notEnoughTitle => 'دمج المواقع';

  @override
  String get diveSites_edit_rating_clear => 'مسح التقييم';

  @override
  String diveSites_edit_rating_starTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نجوم',
      one: 'نجمة',
    );
    return '$count $_temp0';
  }

  @override
  String get diveSites_edit_section_access => 'الوصول والخدمات اللوجستية';

  @override
  String get diveSites_edit_section_altitude => 'الارتفاع';

  @override
  String get diveSites_edit_section_depthRange => 'نطاق العمق';

  @override
  String get diveSites_edit_section_difficultyLevel => 'مستوى الصعوبة';

  @override
  String get diveSites_edit_section_expectedMarineLife =>
      'الحياة البحرية المتوقعة';

  @override
  String get diveSites_edit_section_gpsCoordinates => 'إحداثيات GPS';

  @override
  String get diveSites_edit_section_hazards => 'المخاطر والسلامة';

  @override
  String get diveSites_edit_section_rating => 'التقييم';

  @override
  String get diveSites_edit_section_waterType => 'نوع المياه';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return 'خطأ في حذف الموقع: $error';
  }

  @override
  String diveSites_edit_snackbar_errorSaving(Object error) {
    return 'خطأ في حفظ الموقع: $error';
  }

  @override
  String get diveSites_edit_snackbar_locationCaptured => 'تم التقاط الموقع';

  @override
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'تم التقاط الموقع (${accuracy}m)';
  }

  @override
  String get diveSites_edit_snackbar_locationSelectedFromMap =>
      'تم اختيار الموقع من الخريطة';

  @override
  String get diveSites_edit_snackbar_locationSettings => 'الإعدادات';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      'تعذر الحصول على الموقع. قد لا تكون خدمات الموقع متاحة.';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      'تعذر الحصول على الموقع. يرجى التحقق من الأذونات.';

  @override
  String get diveSites_edit_snackbar_siteAdded => 'تمت إضافة الموقع';

  @override
  String get diveSites_edit_snackbar_sitesMerged => 'تم دمج المواقع';

  @override
  String get diveSites_edit_snackbar_siteUpdated => 'تم تحديث الموقع';

  @override
  String get diveSites_fab_label => 'إضافة موقع';

  @override
  String get diveSites_fab_tooltip => 'إضافة موقع غوص جديد';

  @override
  String get diveSites_filter_apply => 'تطبيق الفلاتر';

  @override
  String get diveSites_filter_cancel => 'إلغاء';

  @override
  String get diveSites_filter_clearAll => 'مسح الكل';

  @override
  String get diveSites_filter_country_hint => 'مثال: تايلاند';

  @override
  String get diveSites_filter_country_label => 'الدولة';

  @override
  String get diveSites_filter_depth_max_label => 'الأقصى';

  @override
  String get diveSites_filter_depth_min_label => 'الأدنى';

  @override
  String get diveSites_filter_depth_separator => 'إلى';

  @override
  String get diveSites_filter_difficulty_any => 'أي مستوى';

  @override
  String get diveSites_filter_option_hasCoordinates_subtitle =>
      'إظهار المواقع ذات الإحداثيات فقط';

  @override
  String get diveSites_filter_option_hasCoordinates_title =>
      'يحتوي على إحداثيات';

  @override
  String get diveSites_filter_option_hasDives_subtitle =>
      'إظهار المواقع ذات الغوصات المسجلة فقط';

  @override
  String get diveSites_filter_option_hasDives_title => 'يحتوي على غوصات';

  @override
  String diveSites_filter_rating_starsPlus(Object count) {
    return '$count+ نجوم';
  }

  @override
  String get diveSites_filter_region_hint => 'مثال: فوكيت';

  @override
  String get diveSites_filter_region_label => 'المنطقة';

  @override
  String get diveSites_filter_section_depthRange => 'نطاق أقصى عمق';

  @override
  String get diveSites_filter_section_difficulty => 'الصعوبة';

  @override
  String get diveSites_filter_section_location => 'الموقع';

  @override
  String get diveSites_filter_section_minRating => 'الحد الأدنى للتقييم';

  @override
  String get diveSites_filter_section_options => 'الخيارات';

  @override
  String get diveSites_filter_title => 'تصفية المواقع';

  @override
  String get diveSites_import_appBar_title => 'استيراد موقع غوص';

  @override
  String get diveSites_import_badge_imported => 'مستورد';

  @override
  String get diveSites_import_badge_saved => 'محفوظ';

  @override
  String get diveSites_import_button_import => 'استيراد';

  @override
  String get diveSites_import_detail_alreadyImported => 'تم الاستيراد مسبقاً';

  @override
  String get diveSites_import_detail_importToMySites => 'استيراد إلى مواقعي';

  @override
  String diveSites_import_detail_source(Object source) {
    return 'المصدر: $source';
  }

  @override
  String get diveSites_import_empty_description =>
      'ابحث عن مواقع الغوص من قاعدة بياناتنا لوجهات\nالغوص الشهيرة حول العالم.';

  @override
  String get diveSites_import_empty_hint =>
      'جرّب البحث باسم الموقع أو الدولة أو المنطقة.';

  @override
  String get diveSites_import_empty_title => 'البحث عن مواقع الغوص';

  @override
  String get diveSites_import_error_retry => 'إعادة المحاولة';

  @override
  String get diveSites_import_error_title => 'خطأ في البحث';

  @override
  String get diveSites_import_error_unknown => 'خطأ غير معروف';

  @override
  String get diveSites_import_externalSite_locationUnknown =>
      'الموقع غير معروف';

  @override
  String get diveSites_import_label_gps => 'GPS';

  @override
  String get diveSites_import_localSite_locationNotSet => 'الموقع غير محدد';

  @override
  String diveSites_import_noResults_description(Object query) {
    return 'لم يتم العثور على مواقع غوص لـ \"$query\".\nجرّب مصطلح بحث مختلف.';
  }

  @override
  String get diveSites_import_noResults_title => 'لا توجد نتائج';

  @override
  String get diveSites_import_quickSearch_caribbean => 'الكاريبي';

  @override
  String get diveSites_import_quickSearch_indonesia => 'إندونيسيا';

  @override
  String get diveSites_import_quickSearch_maldives => 'المالديف';

  @override
  String get diveSites_import_quickSearch_philippines => 'الفلبين';

  @override
  String get diveSites_import_quickSearch_redSea => 'البحر الأحمر';

  @override
  String get diveSites_import_quickSearch_thailand => 'تايلاند';

  @override
  String get diveSites_import_search_clearTooltip => 'مسح البحث';

  @override
  String get diveSites_import_search_hint =>
      'البحث عن مواقع الغوص (مثال: \"الحفرة الزرقاء\"، \"تايلاند\")';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return 'استيراد من قاعدة البيانات ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return 'مواقعي ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return 'عرض تفاصيل $name';
  }

  @override
  String diveSites_import_semantics_viewSavedSite(Object name) {
    return 'عرض الموقع المحفوظ $name';
  }

  @override
  String get diveSites_import_snackbar_failed => 'فشل استيراد الموقع';

  @override
  String diveSites_import_snackbar_imported(Object name) {
    return 'تم استيراد \"$name\"';
  }

  @override
  String get diveSites_import_snackbar_viewAction => 'عرض';

  @override
  String get diveSites_list_activeFilter_clear => 'مسح';

  @override
  String diveSites_list_activeFilter_country(Object country) {
    return 'الدولة: $country';
  }

  @override
  String diveSites_list_activeFilter_depthRangeBoth(Object min, Object max) {
    return '$min-$max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'حتى $max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '$min+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => 'يحتوي على إحداثيات';

  @override
  String get diveSites_list_activeFilter_hasDives => 'يحتوي على غوصات';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return 'المنطقة: $region';
  }

  @override
  String get diveSites_list_appBar_title => 'مواقع الغوص';

  @override
  String get diveSites_list_bulkDelete_cancel => 'إلغاء';

  @override
  String get diveSites_list_bulkDelete_confirm => 'حذف';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مواقع',
      one: 'موقع',
    );
    return 'هل أنت متأكد من حذف $count $_temp0؟ يمكن التراجع عن هذا الإجراء خلال 5 ثوانٍ.';
  }

  @override
  String get diveSites_list_bulkDelete_restored => 'تمت استعادة المواقع';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مواقع',
      one: 'موقع',
    );
    return 'تم حذف $count $_temp0';
  }

  @override
  String get diveSites_list_bulkDelete_title => 'حذف المواقع';

  @override
  String get diveSites_list_bulkDelete_undo => 'تراجع';

  @override
  String get diveSites_list_merge_restored => 'تم التراجع عن الدمج';

  @override
  String diveSites_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مواقع',
      one: 'موقع',
    );
    return 'تم دمج $count $_temp0';
  }

  @override
  String get diveSites_list_merge_undo => 'تراجع';

  @override
  String get diveSites_list_emptyFiltered_clearAll => 'مسح جميع الفلاتر';

  @override
  String get diveSites_list_emptyFiltered_subtitle =>
      'جرّب تعديل أو مسح الفلاتر';

  @override
  String get diveSites_list_emptyFiltered_title =>
      'لا توجد مواقع تطابق الفلاتر';

  @override
  String get diveSites_list_empty_addFirstSite => 'أضف موقعك الأول';

  @override
  String get diveSites_list_empty_import => 'استيراد';

  @override
  String get diveSites_list_empty_subtitle =>
      'أضف مواقع الغوص لتتبع أماكنك المفضلة';

  @override
  String get diveSites_list_empty_title => 'لا توجد مواقع غوص بعد';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return 'خطأ في تحميل المواقع: $error';
  }

  @override
  String get diveSites_list_error_retry => 'إعادة المحاولة';

  @override
  String get diveSites_list_menu_import => 'استيراد';

  @override
  String get diveSites_list_menu_select => 'تحديد المواقع';

  @override
  String get diveSites_list_menu_fillLocationDetails =>
      'إكمال تفاصيل الموقع الناقصة';

  @override
  String get diveSites_backfill_confirm_title => 'إكمال تفاصيل الموقع الناقصة؟';

  @override
  String diveSites_backfill_confirm_body(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count مواقع غوص لها إحداثيات ينقصها البلد أو المنطقة أو البلدة أو المسطح المائي.',
      one:
          'موقع غوص واحد له إحداثيات ينقصه البلد أو المنطقة أو البلدة أو المسطح المائي.',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقائق',
      two: 'دقيقتين',
      one: 'دقيقة واحدة',
    );
    return '$_temp0 سيبحث Submersion عن كل منها في OpenStreetMap ويملأ الحقول الفارغة فقط. يستغرق ذلك نحو $_temp1.';
  }

  @override
  String get diveSites_backfill_confirm_start => 'بدء';

  @override
  String get diveSites_backfill_nothingToFill =>
      'كل مواقع الغوص التي لها إحداثيات لديها تفاصيل الموقع بالفعل.';

  @override
  String get diveSites_backfill_progress_title => 'جارٍ إكمال تفاصيل الموقع';

  @override
  String diveSites_backfill_progress_count(int done, int total) {
    return '$done من $total';
  }

  @override
  String get diveSites_backfill_cancel => 'إلغاء';

  @override
  String diveSites_backfill_summary(int updated, int unchanged, int failed) {
    return 'تم تحديث $updated، بدون تغيير $unchanged، فشل $failed';
  }

  @override
  String get diveSites_backfill_offline =>
      'البحث عن الموقع غير متاح. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get diveSites_list_search_backTooltip => 'رجوع';

  @override
  String get diveSites_list_search_clearTooltip => 'مسح البحث';

  @override
  String get diveSites_list_search_emptyHint =>
      'البحث باسم الموقع أو الدولة أو المنطقة';

  @override
  String diveSites_list_search_error(Object error) {
    return 'خطأ: $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return 'لم يتم العثور على مواقع لـ \"$query\"';
  }

  @override
  String get diveSites_list_search_placeholder => 'البحث في المواقع...';

  @override
  String get diveSites_list_selection_closeTooltip => 'إغلاق التحديد';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count محدد';
  }

  @override
  String get diveSites_list_selection_deleteTooltip => 'حذف المحدد';

  @override
  String get diveSites_list_selection_mergeTooltip => 'دمج المحدد';

  @override
  String get diveSites_list_selection_deselectAllTooltip => 'إلغاء تحديد الكل';

  @override
  String get diveSites_list_selection_selectAllTooltip => 'تحديد الكل';

  @override
  String get diveSites_list_sort_title => 'ترتيب المواقع';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غوصات',
      one: 'غوصة واحدة',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return 'موقع غوص: $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => 'تصفية المواقع';

  @override
  String get diveSites_list_tooltip_mapView => 'عرض الخريطة';

  @override
  String get diveSites_list_tooltip_searchSites => 'البحث في المواقع';

  @override
  String get diveSites_list_tooltip_sort => 'ترتيب';

  @override
  String get diveSites_locationPicker_appBar_title => 'اختيار الموقع';

  @override
  String get diveSites_locationPicker_confirmButton => 'تأكيد';

  @override
  String get diveSites_locationPicker_confirmTooltip => 'تأكيد الموقع المحدد';

  @override
  String get diveSites_locationPicker_fab_tooltip => 'استخدام موقعي';

  @override
  String get diveSites_locationPicker_instruction_locationSelected =>
      'تم تحديد الموقع';

  @override
  String get diveSites_locationPicker_instruction_lookingUp =>
      'جارٍ البحث عن الموقع...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect =>
      'اضغط على الخريطة لتحديد موقع';

  @override
  String get diveSites_locationPicker_label_latitude => 'خط العرض';

  @override
  String get diveSites_locationPicker_label_longitude => 'خط الطول';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return 'الإحداثيات المحددة: خط العرض $latitude، خط الطول $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp =>
      'جارٍ البحث عن الموقع';

  @override
  String get diveSites_locationPicker_semantics_map =>
      'خريطة تفاعلية لاختيار موقع غوص. اضغط على الخريطة لتحديد موقع.';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return 'خطأ في تحميل مواقع الغوص: $error';
  }

  @override
  String get diveSites_map_appBar_title => 'مواقع الغوص';

  @override
  String get diveSites_map_builtInSites_add => 'إضافة إلى مواقعي';

  @override
  String get diveSites_map_builtInSites_addError =>
      'تعذّر إضافة الموقع. يرجى المحاولة مرة أخرى.';

  @override
  String get diveSites_map_builtInSites_added => 'تمت الإضافة إلى مواقعك';

  @override
  String get diveSites_map_builtInSites_hide => 'إخفاء المواقع المدمجة';

  @override
  String get diveSites_map_builtInSites_off => 'المواقع المدمجة مخفية';

  @override
  String get diveSites_map_builtInSites_on => 'المواقع المدمجة ظاهرة';

  @override
  String get diveSites_map_builtInSites_show => 'إظهار المواقع المدمجة';

  @override
  String get diveSites_map_empty_description =>
      'أضف إحداثيات لمواقع الغوص لرؤيتها على الخريطة';

  @override
  String get diveSites_map_empty_title => 'لا توجد مواقع بإحداثيات';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return 'خطأ في تحميل المواقع: $error';
  }

  @override
  String get diveSites_map_error_retry => 'إعادة المحاولة';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غوصات',
      one: 'غوصة واحدة',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_builtInSiteMarker(Object name) {
    return 'موقع غوص مدمج: $name';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return 'موقع غوص: $name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => 'إظهار جميع المواقع';

  @override
  String get diveSites_map_tooltip_listView => 'عرض القائمة';

  @override
  String get diveSites_summary_action_addSite => 'إضافة موقع';

  @override
  String get diveSites_summary_action_import => 'استيراد';

  @override
  String get diveSites_summary_action_viewMap => 'عرض الخريطة';

  @override
  String diveSites_summary_countriesMore(Object count) {
    return '+ $count أخرى';
  }

  @override
  String get diveSites_summary_header_subtitle =>
      'اختر موقعاً من القائمة لعرض التفاصيل';

  @override
  String get diveSites_summary_header_title => 'مواقع الغوص';

  @override
  String get diveSites_summary_section_countriesRegions => 'الدول والمناطق';

  @override
  String get diveSites_summary_section_mostDived => 'الأكثر غوصاً';

  @override
  String get diveSites_summary_section_overview => 'نظرة عامة';

  @override
  String get diveSites_summary_section_quickActions => 'إجراءات سريعة';

  @override
  String get diveSites_summary_section_topRated => 'الأعلى تقييماً';

  @override
  String get diveSites_summary_stat_avgRating => 'متوسط التقييم';

  @override
  String get diveSites_summary_stat_totalDives => 'إجمالي الغوصات';

  @override
  String get diveSites_summary_stat_totalSites => 'إجمالي المواقع';

  @override
  String get diveSites_summary_stat_withGps => 'مع GPS';

  @override
  String get diveType_builtin_altitude => 'ارتفاع';

  @override
  String get diveType_builtin_boat => 'من القارب';

  @override
  String get diveType_builtin_cave => 'كهف';

  @override
  String get diveType_builtin_cavern => 'كهف ضحل';

  @override
  String get diveType_builtin_deep => 'عميق';

  @override
  String get diveType_builtin_drift => 'انجراف';

  @override
  String get diveType_builtin_freedive => 'غطس حر';

  @override
  String get diveType_builtin_ice => 'جليد';

  @override
  String get diveType_builtin_liveaboard => 'رحلة غوص بحرية';

  @override
  String get diveType_builtin_night => 'ليلي';

  @override
  String get diveType_builtin_recreational => 'ترفيهي';

  @override
  String get diveType_builtin_shore => 'من الشاطئ';

  @override
  String get diveType_builtin_technical => 'تقني';

  @override
  String get diveType_builtin_training => 'تدريب';

  @override
  String get diveType_builtin_wreck => 'حطام';

  @override
  String get diveTypes_addDialog_addButton => 'إضافة';

  @override
  String get diveTypes_addDialog_nameHint => 'مثال: البحث والإنقاذ';

  @override
  String get diveTypes_addDialog_nameLabel => 'اسم نوع الغوص';

  @override
  String get diveTypes_addDialog_nameValidation => 'الرجاء إدخال اسم';

  @override
  String get diveTypes_addDialog_title => 'إضافة نوع غوص مخصص';

  @override
  String get diveTypes_addTooltip => 'إضافة نوع غوص';

  @override
  String get diveTypes_appBar_title => 'أنواع الغوص';

  @override
  String get diveTypes_builtIn => 'مدمج';

  @override
  String get diveTypes_builtInHeader => 'أنواع الغوص المدمجة';

  @override
  String get diveTypes_custom => 'مخصص';

  @override
  String get diveTypes_customHeader => 'أنواع الغوص المخصصة';

  @override
  String diveTypes_deleteDialog_content(Object name) {
    return 'هل أنت متأكد من حذف \"$name\"؟';
  }

  @override
  String get diveTypes_deleteDialog_title => 'حذف نوع الغوص؟';

  @override
  String get diveTypes_deleteTooltip => 'حذف نوع الغوص';

  @override
  String diveTypes_snackbar_added(Object name) {
    return 'تمت إضافة نوع الغوص: $name';
  }

  @override
  String diveTypes_snackbar_cannotDelete(Object name) {
    return 'لا يمكن حذف \"$name\" - مستخدم في غطسات موجودة';
  }

  @override
  String diveTypes_snackbar_deleted(Object name) {
    return 'تم حذف \"$name\"';
  }

  @override
  String diveTypes_snackbar_errorAdding(Object error) {
    return 'خطأ في إضافة نوع الغوص: $error';
  }

  @override
  String diveTypes_snackbar_errorDeleting(Object error) {
    return 'خطأ في حذف نوع الغوص: $error';
  }

  @override
  String get divers_detail_activeDiver => 'الغواص النشط';

  @override
  String get divers_detail_allergiesLabel => 'الحساسية';

  @override
  String get divers_detail_appBarTitle => 'الغواص';

  @override
  String get divers_detail_bloodTypeLabel => 'فصيلة الدم';

  @override
  String get divers_detail_bottomTimeLabel => 'وقت القاع';

  @override
  String get divers_detail_cancelButton => 'إلغاء';

  @override
  String get divers_detail_contactTitle => 'جهة الاتصال';

  @override
  String get divers_detail_defaultLabel => 'افتراضي';

  @override
  String get divers_detail_deleteButton => 'حذف';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'This will permanently delete $name and all associated data including dive logs, dive computers, equipment, certifications, and sites.';
  }

  @override
  String get divers_detail_deleteDialogTitle => 'حذف الغواص؟';

  @override
  String divers_detail_deleteError(Object error) {
    return 'فشل في الحذف: $error';
  }

  @override
  String get divers_detail_deleteMenuItem => 'حذف';

  @override
  String get divers_detail_deletedSnackbar => 'تم حذف الغواص';

  @override
  String get divers_detail_diveInsuranceTitle => 'تأمين الغوص';

  @override
  String get divers_detail_diveStatisticsTitle => 'إحصائيات الغوص';

  @override
  String get divers_detail_editTooltip => 'تعديل الغواص';

  @override
  String get divers_detail_emergencyContactTitle => 'جهة اتصال الطوارئ';

  @override
  String divers_detail_errorPrefix(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get divers_detail_expiredBadge => 'منتهية الصلاحية';

  @override
  String get divers_detail_expiresLabel => 'تنتهي في';

  @override
  String get divers_detail_medicalInfoTitle => 'المعلومات الطبية';

  @override
  String get divers_detail_medicalNotesLabel => 'ملاحظات';

  @override
  String get divers_detail_notFound => 'الغواص غير موجود';

  @override
  String get divers_detail_notesTitle => 'ملاحظات';

  @override
  String get divers_detail_policyNumberLabel => 'رقم الوثيقة';

  @override
  String get divers_detail_providerLabel => 'مزود التأمين';

  @override
  String get divers_detail_setAsDefault => 'تعيين كافتراضي';

  @override
  String divers_detail_setAsDefaultSnackbar(Object name) {
    return 'تم تعيين $name كغواص افتراضي';
  }

  @override
  String get divers_detail_switchToTooltip => 'التبديل إلى هذا الغواص';

  @override
  String divers_detail_switchedTo(Object name) {
    return 'تم التبديل إلى $name';
  }

  @override
  String get divers_detail_totalDivesLabel => 'إجمالي الغوصات';

  @override
  String get divers_detail_unableToLoadStats => 'تعذر تحميل الإحصائيات';

  @override
  String get divers_edit_addButton => 'إضافة غواص';

  @override
  String get divers_edit_addTitle => 'إضافة غواص';

  @override
  String get divers_edit_allergiesHint => 'مثال: بنسلين، محار';

  @override
  String get divers_edit_allergiesLabel => 'الحساسية';

  @override
  String get divers_edit_bloodTypeHint => 'مثال: O+، A-، B+';

  @override
  String get divers_edit_bloodTypeLabel => 'فصيلة الدم';

  @override
  String get divers_edit_cancelButton => 'إلغاء';

  @override
  String get divers_edit_clearInsuranceExpiryTooltip =>
      'مسح تاريخ انتهاء التأمين';

  @override
  String get divers_edit_clearMedicalClearanceTooltip =>
      'مسح تاريخ التصريح الطبي';

  @override
  String get divers_edit_contactNameLabel => 'اسم جهة الاتصال';

  @override
  String get divers_edit_contactPhoneLabel => 'هاتف جهة الاتصال';

  @override
  String get divers_edit_discardButton => 'تجاهل';

  @override
  String get divers_edit_discardDialogContent =>
      'لديك تغييرات غير محفوظة. هل أنت متأكد أنك تريد تجاهلها؟';

  @override
  String get divers_edit_discardDialogTitle => 'تجاهل التغييرات؟';

  @override
  String get divers_edit_diverAdded => 'تمت إضافة الغواص';

  @override
  String get divers_edit_diverUpdated => 'تم تحديث الغواص';

  @override
  String get divers_edit_editTitle => 'تعديل الغواص';

  @override
  String get divers_edit_emailError => 'أدخل بريدًا إلكترونيًا صالحًا';

  @override
  String get divers_edit_emailLabel => 'البريد الإلكتروني';

  @override
  String get divers_edit_emergencyContactsSection => 'جهات اتصال الطوارئ';

  @override
  String divers_edit_errorLoading(Object error) {
    return 'خطأ في تحميل الغواص: $error';
  }

  @override
  String divers_edit_errorSaving(Object error) {
    return 'خطأ في حفظ الغواص: $error';
  }

  @override
  String get divers_edit_expiryDateNotSet => 'غير محدد';

  @override
  String get divers_edit_expiryDateTitle => 'تاريخ الانتهاء';

  @override
  String get divers_edit_insuranceProviderHint => 'مثال: DAN، DiveAssure';

  @override
  String get divers_edit_insuranceProviderLabel => 'مزود التأمين';

  @override
  String get divers_edit_insuranceSection => 'تأمين الغوص';

  @override
  String get divers_edit_keepEditingButton => 'متابعة التعديل';

  @override
  String get divers_edit_medicalClearanceExpired => 'منتهية الصلاحية';

  @override
  String get divers_edit_medicalClearanceExpiringSoon => 'تنتهي قريبًا';

  @override
  String get divers_edit_medicalClearanceNotSet => 'غير محدد';

  @override
  String get divers_edit_medicalClearanceTitle => 'انتهاء التصريح الطبي';

  @override
  String get divers_edit_medicalInfoSection => 'المعلومات الطبية';

  @override
  String get divers_edit_medicalNotesLabel => 'ملاحظات طبية';

  @override
  String get divers_edit_medicationsHint => 'مثال: أسبرين يوميًا، EpiPen';

  @override
  String get divers_edit_medicationsLabel => 'الأدوية';

  @override
  String get divers_edit_nameError => 'الاسم مطلوب';

  @override
  String get divers_edit_nameLabel => 'الاسم *';

  @override
  String get divers_edit_notesLabel => 'ملاحظات';

  @override
  String get divers_edit_notesSection => 'ملاحظات';

  @override
  String get divers_edit_personalInfoSection => 'المعلومات الشخصية';

  @override
  String get divers_edit_phoneLabel => 'الهاتف';

  @override
  String get divers_edit_policyNumberLabel => 'رقم الوثيقة';

  @override
  String get divers_edit_primaryContactTitle => 'جهة الاتصال الأساسية';

  @override
  String get divers_edit_relationshipHint =>
      'مثال: زوج/زوجة، أحد الوالدين، صديق';

  @override
  String get divers_edit_relationshipLabel => 'صلة القرابة';

  @override
  String get divers_edit_saveButton => 'حفظ';

  @override
  String get divers_edit_secondaryContactTitle => 'جهة الاتصال الثانوية';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip =>
      'اختيار تاريخ انتهاء التأمين';

  @override
  String get divers_edit_selectMedicalClearanceTooltip =>
      'اختيار تاريخ التصريح الطبي';

  @override
  String get divers_edit_updateButton => 'تحديث الغواص';

  @override
  String get divers_list_activeBadge => 'نشط';

  @override
  String get divers_list_addDiverButton => 'إضافة غواص';

  @override
  String get divers_list_addDiverTooltip => 'إضافة ملف غواص جديد';

  @override
  String get divers_list_appBarTitle => 'ملفات الغواصين';

  @override
  String get divers_list_compactTitle => 'الغواصون';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount غوصات$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle =>
      'أضف ملفات غواصين لتتبع سجلات الغوص لعدة أشخاص';

  @override
  String get divers_list_emptyTitle => 'لا يوجد غواصون بعد';

  @override
  String divers_list_errorLoading(Object error) {
    return 'خطأ في تحميل الغواصين: $error';
  }

  @override
  String get divers_list_errorLoadingStats => 'خطأ في تحميل الإحصائيات';

  @override
  String get divers_list_loadingStats => 'جارٍ التحميل...';

  @override
  String get divers_list_retryButton => 'إعادة المحاولة';

  @override
  String divers_list_viewDiverLabel(Object name) {
    return 'عرض الغواص $name';
  }

  @override
  String get divers_summary_activeDiverTitle => 'الغواص النشط';

  @override
  String get divers_summary_otherDiversTitle => 'غواصون آخرون';

  @override
  String get divers_summary_overviewTitle => 'نظرة عامة';

  @override
  String get divers_summary_quickActionsTitle => 'إجراءات سريعة';

  @override
  String get divers_summary_subtitle => 'اختر غواصًا من القائمة لعرض التفاصيل';

  @override
  String get divers_summary_title => 'ملفات الغواصين';

  @override
  String get divers_summary_totalDiversLabel => 'إجمالي الغواصين';

  @override
  String divers_detail_deleteDialogConfirmHint(String name) {
    return 'Type \"Delete $name\" to confirm';
  }

  @override
  String divers_detail_deleteDialogConfirmText(String name) {
    return 'Delete $name';
  }

  @override
  String get enum_altitudeGroup_extreme => 'ارتفاع شديد';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => 'مجموعة الارتفاع 1';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => 'مجموعة الارتفاع 2';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => 'مجموعة الارتفاع 3';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => 'مستوى سطح البحر';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => 'خطر';

  @override
  String get enum_ascentRate_safe => 'آمن';

  @override
  String get enum_ascentRate_warning => 'تحذير';

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
  String get enum_certificationAgency_other => 'أخرى';

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
  String get enum_certificationLevel_advancedNitrox => 'نيتروكس متقدم';

  @override
  String get enum_certificationLevel_advancedOpenWater => 'مياه مفتوحة متقدم';

  @override
  String get enum_certificationLevel_cave => 'غوص كهوف';

  @override
  String get enum_certificationLevel_cavern => 'غوص مغارات';

  @override
  String get enum_certificationLevel_courseDirector => 'مدير دورات';

  @override
  String get enum_certificationLevel_decompression => 'تخفيف الضغط';

  @override
  String get enum_certificationLevel_diveGuide => 'مرشد غوص';

  @override
  String get enum_certificationLevel_diveMaster => 'مدرب غوص رئيسي';

  @override
  String get enum_certificationLevel_instructor => 'مدرب';

  @override
  String get enum_certificationLevel_masterInstructor => 'مدرب رئيسي';

  @override
  String get enum_certificationLevel_nitrox => 'نيتروكس';

  @override
  String get enum_certificationLevel_openWater => 'مياه مفتوحة';

  @override
  String get enum_certificationLevel_other => 'أخرى';

  @override
  String get enum_certificationLevel_rebreather => 'جهاز إعادة التنفس';

  @override
  String get enum_certificationLevel_rescue => 'غواص إنقاذ';

  @override
  String get enum_certificationLevel_sidemount => 'تعليق جانبي';

  @override
  String get enum_certificationLevel_techDiver => 'غواص تقني';

  @override
  String get enum_certificationLevel_trimix => 'ترايمكس';

  @override
  String get enum_certificationLevel_wreck => 'غوص حطام';

  @override
  String get enum_currentDirection_east => 'شرق';

  @override
  String get enum_currentDirection_none => 'لا يوجد';

  @override
  String get enum_currentDirection_north => 'شمال';

  @override
  String get enum_currentDirection_northEast => 'شمال شرق';

  @override
  String get enum_currentDirection_northWest => 'شمال غرب';

  @override
  String get enum_currentDirection_south => 'جنوب';

  @override
  String get enum_currentDirection_southEast => 'جنوب شرق';

  @override
  String get enum_currentDirection_southWest => 'جنوب غرب';

  @override
  String get enum_currentDirection_variable => 'متغير';

  @override
  String get enum_currentDirection_west => 'غرب';

  @override
  String get enum_currentStrength_light => 'خفيف';

  @override
  String get enum_currentStrength_moderate => 'معتدل';

  @override
  String get enum_currentStrength_none => 'لا يوجد';

  @override
  String get enum_currentStrength_strong => 'قوي';

  @override
  String get enum_diveMode_ccr => 'جهاز إعادة تنفس دائرة مغلقة';

  @override
  String get enum_diveMode_gauge => 'مقياس';

  @override
  String get enum_diveMode_oc => 'دائرة مفتوحة';

  @override
  String get enum_diveMode_scr => 'جهاز إعادة تنفس شبه مغلق';

  @override
  String get enum_diveType_altitude => 'ارتفاع';

  @override
  String get enum_diveType_boat => 'قارب';

  @override
  String get enum_diveType_cave => 'كهف';

  @override
  String get enum_diveType_deep => 'عميق';

  @override
  String get enum_diveType_drift => 'انجراف';

  @override
  String get enum_diveType_freedive => 'غوص حر';

  @override
  String get enum_diveType_ice => 'جليد';

  @override
  String get enum_diveType_liveaboard => 'مبيت على متن القارب';

  @override
  String get enum_diveType_night => 'ليلي';

  @override
  String get enum_diveType_recreational => 'ترفيهي';

  @override
  String get enum_diveType_shore => 'شاطئ';

  @override
  String get enum_diveType_technical => 'تقني';

  @override
  String get enum_diveType_training => 'تدريب';

  @override
  String get enum_diveType_wreck => 'حطام';

  @override
  String get enum_entryMethod_backRoll => 'دحرجة خلفية';

  @override
  String get enum_entryMethod_boat => 'دخول من القارب';

  @override
  String get enum_entryMethod_giantStride => 'خطوة عملاقة';

  @override
  String get enum_entryMethod_jetty => 'رصيف/مرسى';

  @override
  String get enum_entryMethod_ladder => 'سلم';

  @override
  String get enum_entryMethod_other => 'أخرى';

  @override
  String get enum_entryMethod_platform => 'منصة';

  @override
  String get enum_entryMethod_seatedEntry => 'دخول جلوسي';

  @override
  String get enum_entryMethod_shore => 'دخول من الشاطئ';

  @override
  String get enum_equipmentStatus_active => 'نشط';

  @override
  String get enum_equipmentStatus_inService => 'في الصيانة';

  @override
  String get enum_equipmentStatus_loaned => 'مُعار';

  @override
  String get enum_equipmentStatus_lost => 'مفقود';

  @override
  String get enum_equipmentStatus_needsService => 'يحتاج صيانة';

  @override
  String get enum_equipmentStatus_retired => 'متقاعد';

  @override
  String get enum_equipmentType_bcd => 'سترة الطفو';

  @override
  String get enum_equipmentType_boots => 'أحذية';

  @override
  String get enum_equipmentType_camera => 'كاميرا';

  @override
  String get enum_equipmentType_dpv => 'DPV';

  @override
  String get enum_equipmentType_computer => 'حاسوب غوص';

  @override
  String get enum_equipmentType_drysuit => 'بدلة جافة';

  @override
  String get enum_equipmentType_fins => 'زعانف';

  @override
  String get enum_equipmentType_gloves => 'قفازات';

  @override
  String get enum_equipmentType_hood => 'غطاء رأس';

  @override
  String get enum_equipmentType_knife => 'سكين';

  @override
  String get enum_equipmentType_light => 'مصباح';

  @override
  String get enum_equipmentType_mask => 'قناع';

  @override
  String get enum_equipmentType_other => 'أخرى';

  @override
  String get enum_equipmentType_reel => 'بكرة';

  @override
  String get enum_equipmentType_regulator => 'منظم';

  @override
  String get enum_equipmentType_smb => 'SMB';

  @override
  String get enum_equipmentType_tank => 'أسطوانة';

  @override
  String get enum_equipmentType_weights => 'أثقال';

  @override
  String get enum_equipmentType_wetsuit => 'بدلة غوص';

  @override
  String get enum_eventSeverity_alert => 'تنبيه';

  @override
  String get enum_eventSeverity_info => 'معلومات';

  @override
  String get enum_eventSeverity_warning => 'تحذير';

  @override
  String get enum_pdfPageSize_a4 => 'A4';

  @override
  String get enum_pdfPageSize_a4_description => '210 x 297 mm';

  @override
  String get enum_pdfPageSize_letter => 'Letter';

  @override
  String get enum_pdfPageSize_letter_description => '8.5 x 11 in';

  @override
  String get enum_pdfTemplate_detailed => 'مفصّل';

  @override
  String get enum_pdfTemplate_detailed_description =>
      'معلومات غوصة كاملة مع ملاحظات وتقييمات';

  @override
  String get enum_pdfTemplate_nauiStyle => 'نمط NAUI';

  @override
  String get enum_pdfTemplate_nauiStyle_description =>
      'تخطيط مطابق لتنسيق سجل NAUI';

  @override
  String get enum_pdfTemplate_padiStyle => 'نمط PADI';

  @override
  String get enum_pdfTemplate_padiStyle_description =>
      'تخطيط مطابق لتنسيق سجل PADI';

  @override
  String get enum_pdfTemplate_professional => 'احترافي';

  @override
  String get enum_pdfTemplate_professional_description =>
      'مناطق للتوقيع والختم للتحقق';

  @override
  String get enum_pdfTemplate_simple => 'بسيط';

  @override
  String get enum_pdfTemplate_simple_description =>
      'تنسيق جدول مضغوط، غوصات عديدة في كل صفحة';

  @override
  String get enum_profileEvent_alert => 'تنبيه';

  @override
  String get enum_profileEvent_ascentRateCritical => 'معدل صعود حرج';

  @override
  String get enum_profileEvent_ascentRateWarning => 'تحذير معدل صعود';

  @override
  String get enum_profileEvent_ascentStart => 'بداية الصعود';

  @override
  String get enum_profileEvent_bookmark => 'إشارة مرجعية';

  @override
  String get enum_profileEvent_cnsCritical => 'CNS حرج';

  @override
  String get enum_profileEvent_cnsWarning => 'تحذير CNS';

  @override
  String get enum_profileEvent_decoStopEnd => 'نهاية توقف تخفيف الضغط';

  @override
  String get enum_profileEvent_decoStopStart => 'بداية توقف تخفيف الضغط';

  @override
  String get enum_profileEvent_decoViolation => 'انتهاك تخفيف الضغط';

  @override
  String get enum_profileEvent_gasSwitch => 'تبديل الغاز';

  @override
  String get enum_profileEvent_lowGas => 'تحذير انخفاض الغاز';

  @override
  String get enum_profileEvent_maxDepth => 'أقصى عمق';

  @override
  String get enum_profileEvent_missedStop => 'توقف تخفيف ضغط فائت';

  @override
  String get enum_profileEvent_note => 'ملاحظة';

  @override
  String get enum_profileEvent_ppO2High => 'ppO2 مرتفع';

  @override
  String get enum_profileEvent_ppO2Low => 'ppO2 منخفض';

  @override
  String get enum_profileEvent_safetyStopEnd => 'نهاية توقف أمان';

  @override
  String get enum_profileEvent_safetyStopStart => 'بداية توقف أمان';

  @override
  String get enum_profileEvent_setpointChange => 'تغيير نقطة الضبط';

  @override
  String get enum_profileMetricCategory_decompression => 'تخفيف الضغط';

  @override
  String get enum_profileMetricCategory_gasAnalysis => 'تحليل الغاز';

  @override
  String get enum_profileMetricCategory_gradientFactor => 'عوامل التدرج';

  @override
  String get enum_profileMetricCategory_other => 'أخرى';

  @override
  String get enum_profileMetricCategory_primary => 'المقاييس الأساسية';

  @override
  String get enum_profileMetric_gasDensity => 'كثافة الغاز';

  @override
  String get enum_profileMetric_gasDensity_short => 'كثافة';

  @override
  String get enum_profileMetric_gf => 'GF%';

  @override
  String get enum_profileMetric_gf_short => 'GF%';

  @override
  String get enum_profileMetric_heartRate => 'معدل نبض القلب';

  @override
  String get enum_profileMetric_heartRate_short => 'نبض';

  @override
  String get enum_profileMetric_meanDepth => 'متوسط العمق';

  @override
  String get enum_profileMetric_meanDepth_short => 'متوسط';

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
  String get enum_profileMetric_pressure => 'ضغط';

  @override
  String get enum_profileMetric_pressure_short => 'ضغط';

  @override
  String get enum_profileMetric_sacRate => 'معدل SAC';

  @override
  String get enum_profileMetric_sacRate_short => 'SAC';

  @override
  String get enum_profileMetric_surfaceGf => 'GF السطح';

  @override
  String get enum_profileMetric_surfaceGf_short => 'SrfGF';

  @override
  String get enum_profileMetric_temperature => 'درجة الحرارة';

  @override
  String get enum_profileMetric_temperature_short => 'حرارة';

  @override
  String get enum_profileMetric_tts => 'TTS';

  @override
  String get enum_profileMetric_tts_short => 'TTS';

  @override
  String get enum_scrType_cmf => 'تدفق كتلة ثابت';

  @override
  String get enum_scrType_cmf_short => 'CMF';

  @override
  String get enum_scrType_escr => 'تحكم إلكتروني';

  @override
  String get enum_scrType_escr_short => 'ESCR';

  @override
  String get enum_scrType_pascr => 'إضافة سلبية';

  @override
  String get enum_scrType_pascr_short => 'PASCR';

  @override
  String get enum_serviceType_annual => 'صيانة سنوية';

  @override
  String get enum_serviceType_calibration => 'معايرة';

  @override
  String get enum_serviceType_cleaning => 'تنظيف';

  @override
  String get enum_serviceType_inspection => 'فحص';

  @override
  String get enum_serviceType_other => 'أخرى';

  @override
  String get enum_serviceType_overhaul => 'إصلاح شامل';

  @override
  String get enum_serviceType_recall => 'استدعاء/سلامة';

  @override
  String get enum_serviceType_repair => 'إصلاح';

  @override
  String get enum_serviceType_replacement => 'استبدال قطعة';

  @override
  String get enum_serviceType_warranty => 'خدمة ضمان';

  @override
  String get enum_sortDirection_ascending => 'تصاعدي';

  @override
  String get enum_sortDirection_descending => 'تنازلي';

  @override
  String get enum_sortField_agency => 'الجهة';

  @override
  String get enum_sortField_date => 'التاريخ';

  @override
  String get enum_sortField_dateIssued => 'تاريخ الإصدار';

  @override
  String get enum_sortField_dateTaken => 'تاريخ الالتقاط';

  @override
  String get enum_sortField_difficulty => 'الصعوبة';

  @override
  String get enum_sortField_diveCount => 'عدد الغوصات';

  @override
  String get enum_sortField_diveNumber => 'رقم الغوصة';

  @override
  String get enum_sortField_duration => 'المدة';

  @override
  String get enum_sortField_endDate => 'تاريخ الانتهاء';

  @override
  String get enum_sortField_fileName => 'اسم الملف';

  @override
  String get enum_sortField_fileSize => 'حجم الملف';

  @override
  String get enum_sortField_lastServiceDate => 'آخر صيانة';

  @override
  String get enum_sortField_maxDepth => 'أقصى عمق';

  @override
  String get enum_sortField_name => 'الاسم';

  @override
  String get enum_sortField_purchaseDate => 'تاريخ الشراء';

  @override
  String get enum_sortField_rating => 'التقييم';

  @override
  String get enum_sortField_site => 'الموقع';

  @override
  String get enum_sortField_startDate => 'تاريخ البدء';

  @override
  String get enum_sortField_status => 'الحالة';

  @override
  String get enum_sortField_type => 'النوع';

  @override
  String get enum_speciesCategory_coral => 'مرجان';

  @override
  String get enum_speciesCategory_fish => 'سمك';

  @override
  String get enum_speciesCategory_invertebrate => 'لافقاري';

  @override
  String get enum_speciesCategory_mammal => 'ثديي';

  @override
  String get enum_speciesCategory_other => 'أخرى';

  @override
  String get enum_speciesCategory_plant => 'نبات/طحالب';

  @override
  String get enum_speciesCategory_ray => 'شفنين';

  @override
  String get enum_speciesCategory_shark => 'قرش';

  @override
  String get enum_speciesCategory_turtle => 'سلحفاة';

  @override
  String get enum_tankMaterial_aluminum => 'ألومنيوم';

  @override
  String get enum_tankMaterial_carbonFiber => 'ألياف كربونية';

  @override
  String get enum_tankMaterial_steel => 'فولاذ';

  @override
  String get enum_tankRole_backGas => 'غاز خلفي';

  @override
  String get enum_tankRole_bailout => 'غاز طوارئ';

  @override
  String get enum_tankRole_deco => 'تخفيف ضغط';

  @override
  String get enum_tankRole_diluent => 'مخفف';

  @override
  String get enum_tankRole_oxygenSupply => 'إمداد O₂';

  @override
  String get enum_tankRole_pony => 'أسطوانة احتياطية';

  @override
  String get enum_tankRole_sidemountLeft => 'تعليق جانبي أيسر';

  @override
  String get enum_tankRole_sidemountRight => 'تعليق جانبي أيمن';

  @override
  String get enum_tankRole_stage => 'أسطوانة مرحلية';

  @override
  String get enum_visibility_excellent => 'ممتازة (>30m / >100ft)';

  @override
  String get enum_visibility_good => 'جيدة (15-30m / 50-100ft)';

  @override
  String get enum_visibility_moderate => 'معتدلة (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => 'ضعيفة (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => 'غير معروفة';

  @override
  String get enum_waterType_brackish => 'مياه مالحة قليلاً';

  @override
  String get enum_waterType_fresh => 'مياه عذبة';

  @override
  String get enum_waterType_salt => 'مياه مالحة';

  @override
  String get enum_weightType_ankleWeights => 'أثقال الكاحل';

  @override
  String get enum_weightType_backplate => 'أثقال لوحة الظهر';

  @override
  String get enum_weightType_belt => 'حزام أثقال';

  @override
  String get enum_weightType_integrated => 'أثقال مدمجة';

  @override
  String get enum_weightType_mixed => 'مختلطة/مدمجة';

  @override
  String get enum_weightType_trimWeights => 'أثقال التوازن';

  @override
  String get equipment_appBar_title => 'المعدات';

  @override
  String get equipment_deleteDialog_cancel => 'إلغاء';

  @override
  String get equipment_deleteDialog_confirm => 'حذف';

  @override
  String get equipment_deleteDialog_content =>
      'هل أنت متأكد من حذف هذه المعدات؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get equipment_deleteDialog_title => 'حذف المعدات';

  @override
  String get equipment_detail_brandLabel => 'العلامة التجارية';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return 'متأخرة $days يوم';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days يوم حتى الصيانة';
  }

  @override
  String get equipment_detail_detailsTitle => 'التفاصيل';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count غوصات';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count غوصة';
  }

  @override
  String get equipment_detail_divesLabel => 'الغوصات';

  @override
  String get equipment_detail_divesSemanticLabel =>
      'عرض الغوصات باستخدام هذه المعدات';

  @override
  String equipment_detail_durationDays(Object days) {
    return '$days يوم';
  }

  @override
  String equipment_detail_durationMonths(Object months) {
    return '$months أشهر';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralPlural(
    Object years,
    Object months,
  ) {
    return '$years سنوات، $months أشهر';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralSingular(
    Object years,
    Object months,
  ) {
    return '$years سنوات، $months شهر';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularPlural(
    Object years,
    Object months,
  ) {
    return '$years سنة، $months أشهر';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularSingular(
    Object years,
    Object months,
  ) {
    return '$years سنة، $months شهر';
  }

  @override
  String equipment_detail_durationYearsPlural(Object years) {
    return '$years سنوات';
  }

  @override
  String equipment_detail_durationYearsSingular(Object years) {
    return '$years سنة';
  }

  @override
  String get equipment_detail_editTooltip => 'تعديل المعدات';

  @override
  String get equipment_detail_editTooltipShort => 'تعديل';

  @override
  String equipment_detail_errorMessage(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get equipment_detail_errorTitle => 'خطأ';

  @override
  String get equipment_detail_lastServiceLabel => 'آخر صيانة';

  @override
  String get equipment_detail_loadingTitle => 'جارٍ التحميل...';

  @override
  String get equipment_detail_modelLabel => 'الطراز';

  @override
  String get equipment_detail_nextServiceDueLabel => 'موعد الصيانة القادمة';

  @override
  String get equipment_detail_notFoundMessage =>
      'عنصر المعدات هذا لم يعد موجوداً.';

  @override
  String get equipment_detail_notFoundTitle => 'المعدات غير موجودة';

  @override
  String get equipment_detail_notesTitle => 'ملاحظات';

  @override
  String get equipment_detail_ownedForLabel => 'مدة الملكية';

  @override
  String get equipment_detail_purchaseDateLabel => 'تاريخ الشراء';

  @override
  String get equipment_detail_purchasePriceLabel => 'سعر الشراء';

  @override
  String get equipment_detail_retiredChip => 'متقاعد';

  @override
  String get equipment_detail_serialNumberLabel => 'الرقم التسلسلي';

  @override
  String get equipment_detail_serviceInfoTitle => 'معلومات الصيانة';

  @override
  String get equipment_serviceClocks_title => 'عدادات الصيانة';

  @override
  String get equipment_serviceClocks_addClock => 'إضافة عداد';

  @override
  String get equipment_serviceClocks_logService => 'تسجيل صيانة';

  @override
  String get equipment_serviceClocks_edit => 'تعديل الفترات';

  @override
  String get equipment_serviceClocks_pause => 'إيقاف مؤقت';

  @override
  String get equipment_serviceClocks_resume => 'استئناف';

  @override
  String get equipment_serviceClocks_remove => 'إزالة';

  @override
  String get equipment_serviceClocks_paused => 'متوقف مؤقتًا';

  @override
  String get equipment_serviceClocks_empty => 'لا توجد عدادات صيانة';

  @override
  String get equipment_serviceClocks_unconfigured =>
      'لم يتم تعيين فترة - انقر للإعداد';

  @override
  String equipment_serviceClocks_dueOn(String date) {
    return 'مستحق في $date';
  }

  @override
  String equipment_serviceClocks_overdueSince(String date) {
    return 'متأخر منذ $date';
  }

  @override
  String get equipment_serviceClocks_overdue => 'متأخر';

  @override
  String equipment_serviceClocks_divesLeft(int remaining, int total) {
    return 'متبقٍ $remaining من $total غوصة';
  }

  @override
  String get cylinderConfigs_title => 'إعدادات الأسطوانات';

  @override
  String get cylinderConfigs_empty => 'لا توجد إعدادات بعد';

  @override
  String get cylinderConfigs_emptyBody =>
      'احفظ إعداد المخفف والبديل مرة واحدة ثم طبّقه على أي غوصة.';

  @override
  String get cylinderConfigs_new => 'إعداد جديد';

  @override
  String get cylinderConfigs_name => 'الاسم';

  @override
  String get cylinderConfigs_nameRequired => 'أدخل اسمًا';

  @override
  String get cylinderConfigs_forUnit => 'للجهاز';

  @override
  String get cylinderConfigs_noUnit => 'خطة غاز عامة';

  @override
  String get cylinderConfigs_gasPlans => 'خطط الغاز';

  @override
  String get cylinderConfigs_addCylinder => 'إضافة أسطوانة';

  @override
  String get cylinderConfigs_role => 'الدور';

  @override
  String get cylinderConfigs_startPressure => 'ضغط البداية';

  @override
  String get cylinderConfigs_label => 'التسمية';

  @override
  String get cylinderConfigs_fromPreset => 'من قالب';

  @override
  String get cylinderConfigs_deleteTitle => 'حذف الإعداد؟';

  @override
  String get cylinderConfigs_deleteBody =>
      'لن تتغير الغوصات التي طُبّق عليها بالفعل.';

  @override
  String get cylinderConfigs_applyAction => 'تطبيق إعداد';

  @override
  String cylinderConfigs_applyAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت إضافة $count أسطوانات',
      one: 'تمت إضافة أسطوانة واحدة',
    );
    return '$_temp0';
  }

  @override
  String cylinderConfigs_applyKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مع الإبقاء على $count',
      one: 'مع الإبقاء على واحدة',
    );
    return '$_temp0';
  }

  @override
  String get cylinderConfigs_applyNothingToDo =>
      'هذه الغوصة تطابق الإعداد بالفعل';

  @override
  String get cylinderConfigs_sectionTitle => 'الإعدادات';

  @override
  String get equipment_serviceClocks_hoursSource => 'محسوب من زمن الغوص المسجل';

  @override
  String equipment_serviceClocks_hoursLeft(String remaining, String total) {
    return 'متبقٍ $remaining من $total ساعة';
  }

  @override
  String get equipment_serviceClocks_manageKinds => 'إدارة أنواع الصيانة';

  @override
  String get equipment_serviceClocks_appliesToClock => 'ينطبق على العداد';

  @override
  String get equipment_serviceClocks_noClockOption => 'غير مرتبط بعداد';

  @override
  String get equipment_scheduleDialog_title => 'تعديل العداد';

  @override
  String get equipment_scheduleDialog_intervalDays => 'الفترة (أيام)';

  @override
  String get equipment_scheduleDialog_intervalDives => 'الفترة (غوصات)';

  @override
  String get equipment_scheduleDialog_intervalHours => 'الفترة (ساعات)';

  @override
  String equipment_scheduleDialog_inheritHint(String value) {
    return 'الافتراضي: $value';
  }

  @override
  String get equipment_scheduleDialog_anchorDate => 'تاريخ الأساس';

  @override
  String get equipment_scheduleDialog_anchorHint =>
      'يُستخدم عندما لا يوجد بعد سجل صيانة من هذا النوع';

  @override
  String get equipment_scheduleDialog_clearAnchor => 'مسح تاريخ الأساس';

  @override
  String get equipment_scheduleDialog_save => 'حفظ';

  @override
  String get equipment_scheduleDialog_cancel => 'إلغاء';

  @override
  String get equipment_serviceKinds_title => 'أنواع الصيانة';

  @override
  String get equipment_serviceKinds_builtIn => 'مدمج';

  @override
  String get equipment_serviceKinds_custom => 'مخصص';

  @override
  String get equipment_serviceKinds_add => 'إضافة نوع صيانة';

  @override
  String get equipment_serviceKinds_editTitle => 'تعديل نوع الصيانة';

  @override
  String get equipment_serviceKinds_nameLabel => 'الاسم';

  @override
  String get equipment_serviceKinds_nameRequired => 'الاسم مطلوب';

  @override
  String get equipment_serviceKinds_appliesTo => 'ينطبق على';

  @override
  String get equipment_serviceKinds_autoAttach =>
      'إرفاق تلقائيًا بالمعدات الجديدة';

  @override
  String get equipment_serviceKinds_deleteConfirmTitle => 'حذف نوع الصيانة؟';

  @override
  String get equipment_serviceKinds_deleteConfirmBody =>
      'ستتم إزالة العدادات التي تستخدم هذا النوع من الصيانة.';

  @override
  String get equipment_serviceKinds_delete => 'حذف';

  @override
  String get equipment_serviceKinds_cancel => 'إلغاء';

  @override
  String get equipment_serviceKinds_save => 'حفظ';

  @override
  String get equipment_serviceKinds_emptyCustom =>
      'لا توجد أنواع صيانة مخصصة بعد';

  @override
  String equipment_serviceKinds_everyDays(int days) {
    return 'كل $days يوم';
  }

  @override
  String equipment_serviceKinds_everyDives(int dives) {
    return 'كل $dives غوصة';
  }

  @override
  String equipment_serviceKinds_everyHours(String hours) {
    return 'كل $hours ساعة';
  }

  @override
  String get dashboard_serviceDue_title => 'صيانة مستحقة';

  @override
  String dashboard_serviceDue_more(int count) {
    return '+$count أخرى';
  }

  @override
  String dashboard_alerts_clockDue(String name, String kind) {
    return '$name: $kind مستحقة';
  }

  @override
  String dashboard_alerts_clockOverdue(String name, String kind) {
    return '$name: $kind متأخرة';
  }

  @override
  String equipment_list_worstClock(String kind) {
    return '$kind متأخرة';
  }

  @override
  String trips_serviceAlert_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قطعة معدات تحتاج إلى صيانة قبل هذه الرحلة',
      many: '$count قطعة معدات تحتاج إلى صيانة قبل هذه الرحلة',
      few: '$count قطع معدات تحتاج إلى صيانة قبل هذه الرحلة',
      two: 'قطعتا معدات تحتاجان إلى صيانة قبل هذه الرحلة',
      one: 'قطعة معدات واحدة تحتاج إلى صيانة قبل هذه الرحلة',
      zero: 'لا توجد معدات تحتاج إلى صيانة قبل هذه الرحلة',
    );
    return '$_temp0';
  }

  @override
  String trips_serviceAlert_dueBefore(String kind, String date) {
    return '$kind مستحقة في $date';
  }

  @override
  String trips_serviceAlert_overdue(String kind) {
    return '$kind متأخرة';
  }

  @override
  String get settings_notifications_tripLeadTitle =>
      'مهلة التنبيه لصيانة الرحلة';

  @override
  String settings_notifications_tripLeadDays(int days) {
    return '$days أيام قبل الرحلة';
  }

  @override
  String get equipment_detail_serviceIntervalLabel => 'فترة الصيانة';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days يوم';
  }

  @override
  String get equipment_detail_serviceOverdue => 'الصيانة متأخرة!';

  @override
  String get equipment_detail_sizeLabel => 'المقاس';

  @override
  String get equipment_detail_thicknessLabel => 'السُمك';

  @override
  String get equipment_detail_statusLabel => 'الحالة';

  @override
  String equipment_detail_tripsCountPlural(Object count) {
    return '$count رحلات';
  }

  @override
  String equipment_detail_tripsCountSingular(Object count) {
    return '$count رحلة';
  }

  @override
  String get equipment_detail_tripsLabel => 'الرحلات';

  @override
  String get equipment_detail_tripsSemanticLabel =>
      'عرض الرحلات باستخدام هذه المعدات';

  @override
  String get equipment_edit_appBar_editTitle => 'تعديل المعدات';

  @override
  String get equipment_edit_appBar_newTitle => 'معدات جديدة';

  @override
  String get equipment_edit_appBar_saveButton => 'حفظ';

  @override
  String get equipment_edit_appBar_saveTooltip => 'حفظ تغييرات المعدات';

  @override
  String get equipment_edit_brandLabel => 'العلامة التجارية';

  @override
  String get equipment_edit_clearDate => 'مسح التاريخ';

  @override
  String get equipment_edit_currencyLabel => 'العملة';

  @override
  String get equipment_edit_disableReminders => 'تعطيل التذكيرات';

  @override
  String get equipment_edit_disableRemindersSubtitle =>
      'إيقاف جميع الإشعارات لهذا العنصر';

  @override
  String get equipment_edit_discardDialog_content =>
      'لديك تغييرات غير محفوظة. هل أنت متأكد من المغادرة؟';

  @override
  String get equipment_edit_discardDialog_discard => 'تجاهل';

  @override
  String get equipment_edit_discardDialog_keepEditing => 'متابعة التعديل';

  @override
  String get equipment_edit_discardDialog_title => 'تجاهل التغييرات؟';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => 'إلغاء';

  @override
  String get equipment_edit_embeddedHeader_editTitle => 'تعديل المعدات';

  @override
  String get equipment_edit_embeddedHeader_newTitle => 'معدات جديدة';

  @override
  String get equipment_edit_embeddedHeader_saveButton => 'حفظ';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit =>
      'حفظ تغييرات المعدات';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new =>
      'إضافة معدات جديدة';

  @override
  String equipment_edit_errorMessage(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get equipment_edit_errorTitle => 'خطأ';

  @override
  String get equipment_edit_lastServiceDateLabel => 'تاريخ آخر صيانة';

  @override
  String get equipment_edit_loadingTitle => 'جارٍ التحميل...';

  @override
  String get equipment_edit_modelLabel => 'الطراز';

  @override
  String get equipment_edit_nameHint => 'مثال: منظم الغوص الرئيسي';

  @override
  String get equipment_edit_nameLabel => 'الاسم *';

  @override
  String get equipment_edit_nameValidation => 'يرجى إدخال اسم';

  @override
  String get equipment_edit_notFoundMessage =>
      'عنصر المعدات هذا لم يعد موجوداً.';

  @override
  String get equipment_edit_notFoundTitle => 'المعدات غير موجودة';

  @override
  String get equipment_edit_notesHint => 'ملاحظات إضافية عن هذه المعدات...';

  @override
  String get equipment_edit_notesLabel => 'ملاحظات';

  @override
  String get equipment_edit_notificationsSubtitle =>
      'تجاوز إعدادات الإشعارات العامة لهذا العنصر';

  @override
  String get equipment_edit_notificationsTitle => 'الإشعارات (اختياري)';

  @override
  String get equipment_edit_purchaseDateLabel => 'تاريخ الشراء';

  @override
  String get equipment_edit_purchaseInfoTitle => 'معلومات الشراء';

  @override
  String get equipment_edit_purchasePriceLabel => 'سعر الشراء';

  @override
  String get equipment_edit_purchasePriceValidation => 'أدخل مبلغاً صالحاً';

  @override
  String get equipment_edit_remindMeBeforeServiceDue =>
      'ذكّرني قبل موعد الصيانة:';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days يوم';
  }

  @override
  String get equipment_edit_saveButton_edit => 'حفظ التغييرات';

  @override
  String get equipment_edit_saveButton_new => 'إضافة معدات';

  @override
  String get equipment_edit_saveTooltip_edit => 'حفظ تغييرات المعدات';

  @override
  String get equipment_edit_saveTooltip_new => 'إضافة عنصر معدات جديد';

  @override
  String get equipment_edit_selectDate => 'اختر التاريخ';

  @override
  String get equipment_edit_serialNumberLabel => 'الرقم التسلسلي';

  @override
  String get equipment_edit_serviceIntervalHint => 'مثال: 365 للصيانة السنوية';

  @override
  String get equipment_edit_serviceIntervalLabel => 'فترة الصيانة (بالأيام)';

  @override
  String get equipment_edit_serviceSettingsTitle => 'إعدادات الصيانة';

  @override
  String get equipment_edit_sizeHint => 'مثال: M, L, 42';

  @override
  String get equipment_edit_sizeLabel => 'المقاس';

  @override
  String get equipment_edit_snackbar_added => 'تمت إضافة المعدات';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return 'خطأ في حفظ المعدات: $error';
  }

  @override
  String get equipment_edit_snackbar_updated => 'تم تحديث المعدات';

  @override
  String get equipment_edit_statusLabel => 'الحالة';

  @override
  String get equipment_edit_thicknessDesignationHint => 'مثلاً 5، 5/4، 7/5/3';

  @override
  String get equipment_edit_thicknessHint => 'مثلاً 5 مم، 7 مم';

  @override
  String get equipment_edit_thicknessLabel => 'السُمك';

  @override
  String get equipment_edit_typeLabel => 'النوع *';

  @override
  String get equipment_edit_useCustomReminders => 'استخدام تذكيرات مخصصة';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'تعيين أيام تذكير مختلفة لهذا العنصر';

  @override
  String get equipment_fab_addEquipment => 'إضافة معدات';

  @override
  String get equipment_fab_addSet => 'إضافة طقم';

  @override
  String get equipment_list_emptyState_addFirstButton => 'أضف معداتك الأولى';

  @override
  String get equipment_list_emptyState_addPrompt =>
      'أضف معدات الغوص لتتبع الاستخدام والصيانة';

  @override
  String get equipment_list_emptyState_filterText_equipment => 'معدات';

  @override
  String get equipment_list_emptyState_filterText_serviceDue =>
      'معدات تحتاج صيانة';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return 'معدات $status';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return 'لا توجد $filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch =>
      'لا توجد معدات بهذه الحالة';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate =>
      'جميع معداتك محدثة الصيانة!';

  @override
  String equipment_list_errorLoading(Object error) {
    return 'خطأ في تحميل المعدات: $error';
  }

  @override
  String get equipment_list_filterAll => 'جميع المعدات';

  @override
  String get equipment_list_filterLabel => 'تصفية:';

  @override
  String get equipment_list_filterServiceDue => 'الصيانة مستحقة';

  @override
  String get equipment_list_retryButton => 'إعادة المحاولة';

  @override
  String get equipment_list_searchTooltip => 'البحث في المعدات';

  @override
  String get equipment_list_setsTooltip => 'مجموعات المعدات';

  @override
  String get equipment_list_sortTitle => 'ترتيب المعدات';

  @override
  String get equipment_list_sortTooltip => 'ترتيب';

  @override
  String equipment_list_tile_daysCount(Object days) {
    return '$days يوم';
  }

  @override
  String equipment_list_tile_serviceInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'الصيانة خلال $days يوم',
      one: 'الصيانة خلال يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get equipment_list_tile_serviceDueChip => 'الصيانة مستحقة';

  @override
  String get equipment_list_tile_serviceIn => 'الصيانة خلال';

  @override
  String get equipment_menu_delete => 'حذف';

  @override
  String get equipment_menu_markAsServiced => 'تحديد كمصان';

  @override
  String get equipment_menu_reactivate => 'إعادة تفعيل';

  @override
  String get equipment_menu_retireEquipment => 'إيقاف المعدات';

  @override
  String get equipment_search_backTooltip => 'رجوع';

  @override
  String get equipment_search_clearTooltip => 'مسح البحث';

  @override
  String get equipment_search_fieldLabel => 'البحث في المعدات...';

  @override
  String get equipment_search_hint =>
      'البحث بالاسم أو العلامة التجارية أو الطراز أو الرقم التسلسلي';

  @override
  String equipment_search_noResults(Object query) {
    return 'لم يتم العثور على معدات لـ \"$query\"';
  }

  @override
  String get equipment_serviceDialog_addButton => 'إضافة';

  @override
  String get equipment_serviceDialog_addTitle => 'إضافة سجل صيانة';

  @override
  String get equipment_serviceDialog_cancelButton => 'إلغاء';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip =>
      'مسح تاريخ الصيانة القادمة';

  @override
  String get equipment_serviceDialog_costHint => '0.00';

  @override
  String get equipment_serviceDialog_costLabel => 'التكلفة';

  @override
  String get equipment_serviceDialog_currencyLabel => 'العملة';

  @override
  String get equipment_serviceDialog_costValidation => 'أدخل مبلغاً صالحاً';

  @override
  String get equipment_serviceDialog_editTitle => 'تعديل سجل الصيانة';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel =>
      'موعد الصيانة القادمة';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel =>
      'اختيار تاريخ الصيانة القادمة';

  @override
  String get equipment_serviceDialog_nextServiceNotSet => 'غير محدد';

  @override
  String get equipment_serviceDialog_notesLabel => 'ملاحظات';

  @override
  String get equipment_serviceDialog_providerHint => 'مثال: اسم متجر الغوص';

  @override
  String get equipment_serviceDialog_providerLabel => 'مزود الخدمة/المتجر';

  @override
  String get equipment_serviceDialog_serviceDateLabel => 'تاريخ الصيانة';

  @override
  String get equipment_serviceDialog_serviceDateSemanticLabel =>
      'اختيار تاريخ الصيانة';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => 'نوع الصيانة';

  @override
  String get equipment_serviceDialog_serviceTypeHelper =>
      'تسجيل هذا يعيد ضبط مؤقت نوع الصيانة هذا';

  @override
  String get equipment_serviceDialog_serviceTypeRequired => 'اختر نوع الصيانة';

  @override
  String get equipment_serviceDialog_serviceTypeNotSet => 'غير محدد';

  @override
  String get equipment_serviceDialog_categoryHelper =>
      'تستخدم للتصفية والتصدير';

  @override
  String get equipment_serviceDialog_manageServiceTypes =>
      'إدارة أنواع الصيانة';

  @override
  String get equipment_serviceDialog_categoryLabel => 'الفئة';

  @override
  String get equipment_serviceDialog_snackbar_added => 'تمت إضافة سجل الصيانة';

  @override
  String equipment_serviceDialog_snackbar_error(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get equipment_serviceDialog_snackbar_updated => 'تم تحديث سجل الصيانة';

  @override
  String get equipment_serviceDialog_updateButton => 'تحديث';

  @override
  String get equipment_serviceCategory_annual => 'الصيانة السنوية';

  @override
  String get equipment_serviceCategory_repair => 'إصلاح';

  @override
  String get equipment_serviceCategory_inspection => 'فحص';

  @override
  String get equipment_serviceCategory_overhaul => 'عمرة شاملة';

  @override
  String get equipment_serviceCategory_replacement => 'استبدال قطع';

  @override
  String get equipment_serviceCategory_cleaning => 'تنظيف';

  @override
  String get equipment_serviceCategory_calibration => 'معايرة';

  @override
  String get equipment_serviceCategory_warranty => 'خدمة الضمان';

  @override
  String get equipment_serviceCategory_recall => 'استدعاء/سلامة';

  @override
  String get equipment_serviceCategory_other => 'أخرى';

  @override
  String get equipment_service_addButton => 'إضافة';

  @override
  String get equipment_service_deleteDialog_cancel => 'إلغاء';

  @override
  String get equipment_service_deleteDialog_confirm => 'حذف';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return 'هل أنت متأكد من حذف سجل $serviceType هذا؟';
  }

  @override
  String get equipment_service_deleteDialog_title => 'حذف سجل الصيانة؟';

  @override
  String get equipment_service_deleteMenuItem => 'حذف';

  @override
  String get equipment_service_editMenuItem => 'تعديل';

  @override
  String get equipment_service_emptyState => 'لا توجد سجلات صيانة بعد';

  @override
  String get equipment_service_historyTitle => 'سجل الصيانة';

  @override
  String equipment_service_nextDueLabel(String date) {
    return 'الاستحقاق التالي $date';
  }

  @override
  String get equipment_service_filterTaskAll => 'كل المهام';

  @override
  String get equipment_service_filterTypeAll => 'كل الأنواع';

  @override
  String get equipment_service_filterYearAll => 'كل السنوات';

  @override
  String get equipment_service_filterUntagged => 'غير مرتبط بمؤقت';

  @override
  String get equipment_service_filterClear => 'مسح عامل التصفية';

  @override
  String get equipment_service_filterNoMatches =>
      'لا توجد صيانة تطابق عامل التصفية';

  @override
  String equipment_service_filterMatchCount(int count, int total) {
    return 'عرض $count من $total';
  }

  @override
  String get equipment_serviceKinds_defaultCategoryLabel => 'الفئة الافتراضية';

  @override
  String get equipment_serviceKinds_defaultCategoryNone => 'بدون افتراضي';

  @override
  String get equipment_serviceKinds_defaultCostLabel => 'السعر الافتراضي';

  @override
  String get equipment_serviceKinds_defaultCostHint =>
      'اتركه فارغًا لعدم وجود قيمة افتراضية';

  @override
  String get equipment_scheduleDialog_defaultCostLabel =>
      'السعر الافتراضي لهذه المعدة';

  @override
  String get equipment_serviceKinds_defaultCurrencyLabel => 'العملة';

  @override
  String get equipment_service_exportMenuItem => 'تصدير سجل الصيانة';

  @override
  String get transfer_export_maintenanceTitle => 'سجل الصيانة';

  @override
  String get transfer_export_maintenanceSubtitle =>
      'سجل صيانة جميع المعدات كجدول بيانات';

  @override
  String get settings_export_progress_maintenance =>
      'جارٍ تصدير سجل الصيانة...';

  @override
  String get settings_export_success_maintenance => 'تم تصدير سجل الصيانة';

  @override
  String get settings_export_saved_maintenance => 'تم حفظ سجل الصيانة';

  @override
  String get equipment_serviceKinds_defaultCurrencyInherit =>
      'استخدام العملة الافتراضية';

  @override
  String get equipment_scheduleDialog_defaultCurrencyLabel => 'عملة هذه المعدة';

  @override
  String get equipment_service_snackbar_deleted => 'تم حذف سجل الصيانة';

  @override
  String get equipment_service_totalCostLabel => 'إجمالي تكلفة الصيانة';

  @override
  String get equipment_setDetail_addEquipmentButton => 'إضافة معدات';

  @override
  String get equipment_setDetail_deleteDialog_cancel => 'إلغاء';

  @override
  String get equipment_setDetail_deleteDialog_confirm => 'حذف';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      'هل أنت متأكد من حذف مجموعة المعدات هذه؟ لن يتم حذف عناصر المعدات الموجودة في المجموعة.';

  @override
  String get equipment_setDetail_deleteDialog_title => 'حذف مجموعة المعدات';

  @override
  String get equipment_setDetail_deleteMenuItem => 'حذف';

  @override
  String get equipment_setDetail_editTooltip => 'تعديل المجموعة';

  @override
  String get equipment_setDetail_emptySet => 'لا توجد معدات في هذه المجموعة';

  @override
  String get equipment_setDetail_equipmentInSetTitle =>
      'المعدات في هذه المجموعة';

  @override
  String equipment_setDetail_errorMessage(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get equipment_setDetail_errorTitle => 'خطأ';

  @override
  String get equipment_setDetail_loadingTitle => 'جارٍ التحميل...';

  @override
  String get equipment_setDetail_notFoundMessage =>
      'مجموعة المعدات هذه لم تعد موجودة.';

  @override
  String get equipment_setDetail_notFoundTitle => 'المجموعة غير موجودة';

  @override
  String get equipment_setDetail_snackbar_deleted => 'تم حذف مجموعة المعدات';

  @override
  String get equipment_setEdit_addEquipmentFirst =>
      'أضف معدات أولاً قبل إنشاء مجموعة.';

  @override
  String get equipment_setEdit_appBar_editTitle => 'تعديل المجموعة';

  @override
  String get equipment_setEdit_appBar_newTitle => 'مجموعة معدات جديدة';

  @override
  String get equipment_setEdit_descriptionHint => 'وصف اختياري...';

  @override
  String get equipment_setEdit_descriptionLabel => 'الوصف';

  @override
  String equipment_setEdit_errorMessage(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get equipment_setEdit_errorTitle => 'خطأ';

  @override
  String get equipment_setEdit_loadingTitle => 'جارٍ التحميل...';

  @override
  String get equipment_setEdit_nameHint => 'مثال: إعداد المياه الدافئة';

  @override
  String get equipment_setEdit_nameLabel => 'اسم المجموعة *';

  @override
  String get equipment_setEdit_nameValidation => 'يرجى إدخال اسم';

  @override
  String get equipment_setEdit_noEquipmentAvailable => 'لا توجد معدات متاحة';

  @override
  String get equipment_setEdit_notFoundMessage =>
      'مجموعة المعدات هذه لم تعد موجودة.';

  @override
  String get equipment_setEdit_notFoundTitle => 'المجموعة غير موجودة';

  @override
  String get equipment_setEdit_saveButton_edit => 'حفظ التغييرات';

  @override
  String get equipment_setEdit_saveButton_new => 'إنشاء مجموعة';

  @override
  String get equipment_setEdit_saveTooltip_edit => 'حفظ تغييرات مجموعة المعدات';

  @override
  String get equipment_setEdit_saveTooltip_new => 'إنشاء مجموعة معدات جديدة';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle =>
      'اختر عناصر المعدات لتضمينها في هذه المجموعة.';

  @override
  String get equipment_setEdit_selectEquipmentTitle => 'اختيار المعدات';

  @override
  String get equipment_setEdit_snackbar_created => 'تم إنشاء مجموعة المعدات';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return 'خطأ في حفظ مجموعة المعدات: $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated => 'تم تحديث مجموعة المعدات';

  @override
  String get equipment_sets_appBar_title => 'مجموعات المعدات';

  @override
  String get equipment_sets_emptyState_createFirstButton =>
      'أنشئ مجموعتك الأولى';

  @override
  String get equipment_sets_emptyState_description =>
      'أنشئ مجموعات معدات لإضافة تجهيزات شائعة الاستخدام بسرعة إلى غوصاتك.';

  @override
  String get equipment_sets_emptyState_title => 'لا توجد مجموعات معدات';

  @override
  String equipment_sets_errorLoading(Object error) {
    return 'خطأ في تحميل المجموعات: $error';
  }

  @override
  String get equipment_sets_fabTooltip => 'إنشاء مجموعة معدات جديدة';

  @override
  String get equipment_sets_fab_createSet => 'إنشاء مجموعة';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count عناصر';
  }

  @override
  String equipment_sets_itemCountSemanticLabel(Object count) {
    return '$count في المجموعة';
  }

  @override
  String equipment_sets_itemCountSingular(Object count) {
    return '$count عنصر';
  }

  @override
  String get equipment_sets_retryButton => 'إعادة المحاولة';

  @override
  String get equipment_snackbar_deleted => 'تم حذف المعدات';

  @override
  String get equipment_snackbar_markedAsServiced => 'تم تحديدها كمصانة';

  @override
  String get equipment_snackbar_reactivated => 'تم إعادة تفعيل المعدات';

  @override
  String get equipment_snackbar_retired => 'تم إيقاف المعدات';

  @override
  String get equipment_summary_active => 'نشط';

  @override
  String get equipment_summary_addEquipmentButton => 'إضافة معدات';

  @override
  String get equipment_summary_equipmentSetsButton => 'مجموعات المعدات';

  @override
  String get equipment_summary_overviewTitle => 'نظرة عامة';

  @override
  String get equipment_summary_quickActionsTitle => 'إجراءات سريعة';

  @override
  String get equipment_summary_recentEquipmentTitle => 'المعدات الحديثة';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name، $type';
  }

  @override
  String get equipment_summary_selectPrompt =>
      'اختر معدات من القائمة لعرض التفاصيل';

  @override
  String get equipment_summary_serviceDue => 'الصيانة مستحقة';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name، $type، الصيانة مستحقة';
  }

  @override
  String get equipment_summary_serviceDueTitle => 'الصيانة المستحقة';

  @override
  String get equipment_summary_title => 'المعدات';

  @override
  String get equipment_summary_totalItems => 'إجمالي العناصر';

  @override
  String get equipment_summary_totalValue => 'القيمة الإجمالية';

  @override
  String get equipment_tab_equipment => 'المعدات';

  @override
  String get equipment_tab_sets => 'الأطقم';

  @override
  String get formatter_approximate_prefix => '~';

  @override
  String get formatter_connector_at => 'عند';

  @override
  String get formatter_connector_from => 'من';

  @override
  String get formatter_connector_until => 'حتى';

  @override
  String get gas_air_description => 'هواء قياسي (21% O2)';

  @override
  String get gas_air_displayName => 'هواء';

  @override
  String get gas_diluentAir_description =>
      'مخفف هواء قياسي لأجهزة إعادة التنفس المغلقة الضحلة';

  @override
  String get gas_diluentAir_displayName => 'مخفف هواء';

  @override
  String get gas_diluentTx1070_description =>
      'مخفف ناقص الأكسجين لأجهزة إعادة التنفس المغلقة العميقة جداً';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description =>
      'مخفف ناقص الأكسجين لأجهزة إعادة التنفس المغلقة العميقة';

  @override
  String get gas_diluentTx1260_displayName => 'Tx 12/60';

  @override
  String get gas_ean32_description => 'هواء مخصب بالنيتروكس 32%';

  @override
  String get gas_ean32_displayName => 'EAN32';

  @override
  String get gas_ean36_description => 'هواء مخصب بالنيتروكس 36%';

  @override
  String get gas_ean36_displayName => 'EAN36';

  @override
  String get gas_ean40_description => 'هواء مخصب بالنيتروكس 40%';

  @override
  String get gas_ean40_displayName => 'EAN40';

  @override
  String get gas_ean50_description => 'غاز تخفيف ضغط - 50% O2';

  @override
  String get gas_ean50_displayName => 'EAN50';

  @override
  String get gas_helitrox2525_description => 'هيليتروكس 25/25 (تقني ترفيهي)';

  @override
  String get gas_helitrox2525_displayName => 'Helitrox 25/25';

  @override
  String get gas_oxygen_description => 'أكسجين نقي (تخفيف ضغط 6m فقط)';

  @override
  String get gas_oxygen_displayName => 'أكسجين';

  @override
  String get gas_scrEan40_description => 'غاز تزويد SCR - 40% O2';

  @override
  String get gas_scrEan40_displayName => 'SCR EAN40';

  @override
  String get gas_scrEan50_description => 'غاز تزويد SCR - 50% O2';

  @override
  String get gas_scrEan50_displayName => 'SCR EAN50';

  @override
  String get gas_scrEan60_description => 'غاز تزويد SCR - 60% O2';

  @override
  String get gas_scrEan60_displayName => 'SCR EAN60';

  @override
  String get gas_tmx1555_description =>
      'ترايمكس ناقص الأكسجين 15/55 (عميق جداً)';

  @override
  String get gas_tmx1555_displayName => 'Tx 15/55';

  @override
  String get gas_tmx1845_description => 'ترايمكس 18/45 (غوص عميق)';

  @override
  String get gas_tmx1845_displayName => 'Tx 18/45';

  @override
  String get gas_tmx2135_description => 'ترايمكس طبيعي الأكسجين 21/35';

  @override
  String get gas_tmx2135_displayName => 'Tx 21/35';

  @override
  String get gasCalculators_bestMix_bestOxygenMix => 'أفضل خليط أكسجين';

  @override
  String get gasCalculators_bestMix_commonMixesRef => 'مرجع الخلطات الشائعة';

  @override
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2) {
    return 'تجاوز MOD الهواء عند ppO₂ $ppO2';
  }

  @override
  String get gasCalculators_bestMix_targetDepth => 'العمق المستهدف';

  @override
  String get gasCalculators_bestMix_targetDive => 'الغطسة المستهدفة';

  @override
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  ) {
    return 'الضغط المحيط عند $depth$depthSymbol';
  }

  @override
  String get gasCalculators_consumption_avgDepth => 'متوسط العمق';

  @override
  String get gasCalculators_consumption_breakdown => 'تفصيل الحساب';

  @override
  String get gasCalculators_consumption_diveTime => 'وقت الغوص';

  @override
  String gasCalculators_consumption_exceedsTank(
    Object pressure,
    Object symbol,
  ) {
    return 'يتجاوز سعة الأسطوانة ($pressure $symbol)';
  }

  @override
  String get gasCalculators_consumption_gasAtDepth => 'استهلاك الغاز عند العمق';

  @override
  String get gasCalculators_consumption_pressure => 'الضغط';

  @override
  String get gasCalculators_consumption_remainingGas => 'الغاز المتبقي';

  @override
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  ) {
    return 'سعة الأسطوانة ($tankSize$volumeSymbol @ $fillPressure $pressureSymbol)';
  }

  @override
  String get gasCalculators_consumption_title => 'استهلاك الغاز';

  @override
  String gasCalculators_consumption_totalGas(Object time) {
    return 'إجمالي الغاز لـ $time دقيقة';
  }

  @override
  String get gasCalculators_consumption_volume => 'الحجم';

  @override
  String get gasCalculators_mod_aboutMod => 'حول MOD';

  @override
  String get gasCalculators_mod_aboutModBody => 'أقل O₂ = أعمق MOD = أقصر NDL';

  @override
  String get gasCalculators_mod_inputParameters => 'معاملات الإدخال';

  @override
  String get gasCalculators_mod_maximumOperatingDepth =>
      'العمق التشغيلي الأقصى';

  @override
  String get gasCalculators_mod_oxygenO2 => 'الأكسجين (O₂)';

  @override
  String get gasCalculators_mod_ppO2Conservative =>
      'الحد المحافظ لوقت القاع الممتد';

  @override
  String get gasCalculators_mod_ppO2Maximum =>
      'الحد الأقصى لتوقفات تخفيف الضغط فقط';

  @override
  String get gasCalculators_mod_ppO2Standard =>
      'حد التشغيل القياسي للغوص الترفيهي';

  @override
  String get gasCalculators_mnd_depthInput => 'العمق';

  @override
  String get gasCalculators_mnd_endAtDepthTitle => 'END عند العمق';

  @override
  String get gasCalculators_mnd_endLimit => 'حد END';

  @override
  String get gasCalculators_mnd_hePercent => 'He %';

  @override
  String get gasCalculators_mnd_infoContent =>
      'العمق المخدر الأقصى (MND) هو أعمق نقطة يمكنك الوصول إليها قبل أن يتجاوز التخدير حد END الخاص بك. العمق المخدر المكافئ (END) يخبرك بالتأثير المخدر لغازك عند عمق معين.\n\nعند تفعيل \'O2 مخدر\'، يساهم كل من الأكسجين والنيتروجين في التخدير (أكثر تحفظاً). عند التعطيل، يُعتبر النيتروجين فقط مخدراً.';

  @override
  String get gasCalculators_mnd_infoTitle => 'حول MND/END';

  @override
  String get gasCalculators_mnd_unlimited => 'غير محدود';

  @override
  String get gasCalculators_mnd_inputParameters =>
      'خليط الغاز وإعدادات التخدير';

  @override
  String get gasCalculators_mnd_o2Narcotic => 'O2 مخدر';

  @override
  String get gasCalculators_mnd_o2Percent => 'O2 %';

  @override
  String get gasCalculators_mnd_resultTitle => 'العمق المخدر الأقصى';

  @override
  String get gasCalculators_ppO2Limit => 'حد ppO₂';

  @override
  String get gasCalculators_resetAll => 'إعادة تعيين جميع الحاسبات';

  @override
  String get gasCalculators_sacRate => 'RMV';

  @override
  String get gasCalculators_tab_bestMix => 'أفضل خليط';

  @override
  String get gasCalculators_tab_consumption => 'الاستهلاك';

  @override
  String get gasCalculators_tab_mnd => 'MND/END';

  @override
  String get gasCalculators_tab_blender => 'خلاط ترايمكس';

  @override
  String get gasCalculators_blender_cylinder => 'الأسطوانة';

  @override
  String get gasCalculators_blender_startCylinder => 'في الأسطوانة';

  @override
  String get gasCalculators_blender_targetFill => 'التعبئة المستهدفة';

  @override
  String get gasCalculators_blender_fillGases => 'غازات التعبئة';

  @override
  String get gasCalculators_blender_pressure => 'الضغط';

  @override
  String get gasCalculators_blender_o2 => 'O₂';

  @override
  String get gasCalculators_blender_he => 'He';

  @override
  String get gasCalculators_blender_air => 'هواء';

  @override
  String get gasCalculators_blender_helium => 'هيليوم';

  @override
  String get gasCalculators_blender_procedure => 'خطوات التعبئة';

  @override
  String get gasCalculators_blender_amounts => 'الغاز المطلوب إضافته';

  @override
  String gasCalculators_blender_stepStart(String pressure, String gas) {
    return 'ابدأ بـ $pressure $gas';
  }

  @override
  String gasCalculators_blender_stepFill(
    String gas,
    String pressure,
    String mix,
  ) {
    return 'املأ $gas حتى $pressure → $mix';
  }

  @override
  String get gasCalculators_blender_error_targetPressure =>
      'يجب أن يكون الضغط المستهدف أعلى من الضغط الابتدائي.';

  @override
  String get gasCalculators_blender_error_invalidMix =>
      'لا يمكن أن يتجاوز O₂ + He لأي خليط 100%.';

  @override
  String get gasCalculators_blender_error_identicalGases =>
      'غازا التعبئة متطابقان — لا شيء للخلط.';

  @override
  String get gasCalculators_blender_error_linearlyDependent =>
      'لا يمكن لهذه الغازات إنتاج الخليط المستهدف — هدف الترايمكس يحتاج مصدر هيليوم.';

  @override
  String get gasCalculators_blender_error_negativeAmount =>
      'هذا الخليط غير قابل للتحقيق بهذه الغازات — سيتطلب إخراج غاز.';

  @override
  String gasCalculators_blender_error_drainTo(String pressure) {
    return 'الغاز في الأسطوانة أكثر من اللازم لهذا الخليط. أفرغها حتى $pressure أولاً ثم عبِّئ.';
  }

  @override
  String get gasCalculators_blender_error_drainEmpty =>
      'الغاز الموجود في الأسطوانة لا يصلح لهذا الخليط. أفرغها بالكامل أولاً ثم عبِّئ.';

  @override
  String get gasCalculators_blender_error_cannotRemoveHelium =>
      'الأسطوانة تحتوي على هيليوم بينما الخليط المستهدف لا يحتوي عليه. التعبئة تخفف الهيليوم لكنها لا تزيله، لذا يجب إفراغ الأسطوانة أولاً.';

  @override
  String get gasCalculators_blender_error_insufficientGases =>
      'الهدف الخالي من الهيليوم يحتاج غازي تعبئة خاليين من الهيليوم بنسبتي O₂ مختلفتين.';

  @override
  String get gasCalculators_blender_error_targetNotReached =>
      'غازات التعبئة هذه لا تصل إلى الخليط المستهدف بدقة. تحقق من الغازات وترتيبها.';

  @override
  String get gasCalculators_blender_error_implausibleStartMix =>
      'الأسطوانة تحت ضغط لكنها لا تحتوي على أكسجين ولا هيليوم، أي نيتروجين نقي. تحقّق من الخليط الموجود في الأسطوانة.';

  @override
  String get gasCalculators_blender_about => 'حول الخلط';

  @override
  String get gasCalculators_blender_aboutBody =>
      'خلط بالضغط الجزئي للوصول إلى الخليط المستهدف. أضف كل غاز تعبئة بالترتيب حتى الضغط المعروض، ثم اترك الأسطوانة تستقر. غازات التعبئة وترتيبها قابلة للتعديل، فضبط الغاز الأخير على 32/0 يجعل الاستكمال بـ EAN32 بدلاً من الهواء. حلّل الخليط النهائي دائمًا قبل الغوص به.';

  @override
  String get gasCalculators_blender_conditions => 'ظروف الخلط';

  @override
  String get gasCalculators_blender_fillTemp => 'درجة حرارة التعبئة';

  @override
  String get gasCalculators_blender_fillTempHelp =>
      'درجة حرارة الأسطوانة أثناء التعبئة. كل ضغط في الخطوات هو قراءة المقياس عند هذه الدرجة.';

  @override
  String get gasCalculators_blender_settledTemp => 'درجة الحرارة بعد الاستقرار';

  @override
  String get gasCalculators_blender_settledTempHelp =>
      'درجة الحرارة التي تستقر عليها الأسطوانة في النهاية. الضغط المستهدف هو ما تقرأه عندها.';

  @override
  String get gasCalculators_blender_gasModel => 'نموذج الغاز';

  @override
  String get gasCalculators_blender_modelIdeal => 'غاز مثالي';

  @override
  String get gasCalculators_blender_modelVanDerWaals => 'فان دير فالس';

  @override
  String get gasCalculators_blender_modelZFactor => 'غاز حقيقي (معامل Z)';

  @override
  String get gasCalculators_blender_modelRecommended => 'موصى به';

  @override
  String get gasCalculators_blender_modelHelp =>
      'الغاز الحقيقي (معامل Z) هو الأدق عند ضغوط الأسطوانات. الغاز المثالي يطابق معظم جداول الخلط المنشورة. أما فان دير فالس فيُتاح للمقارنة مع برامج الخلط الأخرى، ويحيد بعدة نقاط مئوية عند ضغط التعبئة.';

  @override
  String gasCalculators_blender_stepAdd(String gas) {
    return 'أضف $gas';
  }

  @override
  String get gasCalculators_blender_stepStartLabel => 'البداية';

  @override
  String gasCalculators_blender_settlesTo(String pressure, String temperature) {
    return 'يستقر عند $pressure في $temperature';
  }

  @override
  String get gasCalculators_blender_templates => 'القوالب';

  @override
  String get gasCalculators_blender_templatesTitle => 'قوالب الخليط المستهدف';

  @override
  String get gasCalculators_blender_saveTemplate => 'حفظ الخليط الحالي';

  @override
  String get gasCalculators_blender_manageTemplates => 'إدارة القوالب';

  @override
  String gasCalculators_blender_templateSaved(String mix) {
    return 'تم حفظ $mix';
  }

  @override
  String get gasCalculators_blender_templateExists =>
      'هذا الخليط محفوظ بالفعل.';

  @override
  String get gasCalculators_blender_templateInvalid =>
      'لا يمكن أن يتجاوز O₂ + He‏ 100%.';

  @override
  String get gasCalculators_blender_templateNeedsNumbers =>
      'أدخل كلًا من O₂ وHe كأرقام.';

  @override
  String gasCalculators_blender_templateLimit(int count) {
    return 'يمكنك حفظ ما يصل إلى $count قالبًا.';
  }

  @override
  String get gasCalculators_blender_templateNone =>
      'لا توجد قوالب بعد. احفظ خليطًا مستهدفًا لإعادة استخدامه هنا.';

  @override
  String gasCalculators_blender_templateDelete(String mix) {
    return 'حذف $mix';
  }

  @override
  String get gasCalculators_blender_templateAdd => 'إضافة قالب';

  @override
  String get gasCalculators_blender_billing => 'التكلفة';

  @override
  String get gasCalculators_blender_cylinderVolume => 'السعة المائية للأسطوانة';

  @override
  String get gasCalculators_blender_cylinderPresets => 'الإعدادات المسبقة';

  @override
  String gasCalculators_blender_unitPrice(String unit) {
    return 'السعر لكل 100 $unit';
  }

  @override
  String get gasCalculators_blender_currency => 'العملة';

  @override
  String get gasCalculators_blender_costTotal => 'الإجمالي';

  @override
  String get gasCalculators_blender_costBasis =>
      'تُحتسب التكلفة على الضغط المُعبأ (السعة المائية للأسطوانة × البار المضافة)، بالطريقة نفسها التي تقيس بها محطة التعبئة.';

  @override
  String get gasCalculators_blender_costMissingPrice =>
      'أدخل سعرًا لكل غاز لعرض الإجمالي.';

  @override
  String get gasCalculators_blender_saveFill => 'حفظ هذه التعبئة';

  @override
  String get gasCalculators_blender_billed => 'الفاتورة';

  @override
  String get gasCalculators_blender_billedNone =>
      'لا شيء في الفاتورة بعد. أكمل تعبئة واحفظها هنا.';

  @override
  String get gasCalculators_blender_billedTo => 'الفاتورة باسم';

  @override
  String get gasCalculators_blender_addManualLine => 'إضافة بند';

  @override
  String get gasCalculators_blender_lineDescription => 'الوصف';

  @override
  String get gasCalculators_blender_lineAmount => 'المبلغ';

  @override
  String get gasCalculators_blender_clearBilled => 'إفراغ';

  @override
  String get gasCalculators_blender_clearBilledTitle => 'إفراغ الفاتورة؟';

  @override
  String gasCalculators_blender_clearBilledBody(int count) {
    return 'سيؤدي هذا إلى حذف جميع التعبئات المحفوظة وعددها $count.';
  }

  @override
  String gasCalculators_blender_editLine(String label) {
    return 'تعديل $label';
  }

  @override
  String gasCalculators_blender_deleteLine(String label) {
    return 'حذف $label';
  }

  @override
  String gasCalculators_blender_fillAdded(String mix) {
    return 'تمت إضافة $mix إلى الفاتورة';
  }

  @override
  String get gasCalculators_blender_billedIncomplete =>
      'أحد البنود بلا سعر، لذا فالإجمالي غير مكتمل.';

  @override
  String get gasCalculators_blender_billedTotal => 'الإجمالي';

  @override
  String get gasCalculators_tab_mod => 'MOD';

  @override
  String get gasCalculators_tab_rockBottom => 'الحد الأدنى';

  @override
  String get gasCalculators_tankSize => 'حجم الأسطوانة';

  @override
  String get gasCalculators_title => 'حاسبات الغاز';

  @override
  String get marineLife_siteSection_editExpectedTooltip =>
      'تعديل الأنواع المتوقعة';

  @override
  String get marineLife_siteSection_errorLoadingExpected =>
      'خطأ في تحميل الأنواع المتوقعة';

  @override
  String get marineLife_siteSection_errorLoadingSightings =>
      'خطأ في تحميل المشاهدات';

  @override
  String get marineLife_siteSection_expectedSpecies => 'الأنواع المتوقعة';

  @override
  String get marineLife_siteSection_noExpected => 'لم تتم إضافة أنواع متوقعة';

  @override
  String get marineLife_siteSection_noSpotted => 'لم يتم رصد حياة بحرية بعد';

  @override
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  ) {
    return '$name، شوهد $count مرات';
  }

  @override
  String get marineLife_siteSection_spottedHere => 'تم رصدها هنا';

  @override
  String get marineLife_siteSection_title => 'الحياة البحرية';

  @override
  String get marineLife_speciesDetail_backTooltip => 'رجوع';

  @override
  String get marineLife_speciesDetail_depthRangeTitle => 'نطاق العمق';

  @override
  String get marineLife_speciesDetail_descriptionTitle => 'الوصف';

  @override
  String get marineLife_speciesDetail_divesLabel => 'الغوصات';

  @override
  String get marineLife_speciesDetail_editTooltip => 'تعديل النوع';

  @override
  String marineLife_speciesDetail_errorPrefix(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get marineLife_speciesDetail_noSightings => 'لم يتم تسجيل مشاهدات بعد';

  @override
  String get marineLife_speciesDetail_notFound => 'النوع غير موجود';

  @override
  String marineLife_speciesDetail_sightingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مشاهدات',
      one: 'مشاهدة',
    );
    return '$count $_temp0';
  }

  @override
  String get marineLife_speciesDetail_sightingPeriodTitle => 'فترة المشاهدة';

  @override
  String get marineLife_speciesDetail_sightingStatsTitle =>
      'إحصائيات المشاهدات';

  @override
  String get marineLife_speciesDetail_sitesLabel => 'المواقع';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return 'الصنف: $className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle => 'أفضل المواقع';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel => 'إجمالي المشاهدات';

  @override
  String get marineLife_speciesEdit_addTitle => 'إضافة نوع';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return 'تمت إضافة \"$name\"';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => 'رجوع';

  @override
  String get marineLife_speciesEdit_categoryLabel => 'الفئة';

  @override
  String get marineLife_speciesEdit_commonNameError =>
      'يرجى إدخال الاسم الشائع';

  @override
  String get marineLife_speciesEdit_commonNameHint => 'مثال: سمكة المهرج';

  @override
  String get marineLife_speciesEdit_commonNameLabel => 'الاسم الشائع';

  @override
  String get marineLife_speciesEdit_descriptionHint => 'وصف مختصر للنوع...';

  @override
  String get marineLife_speciesEdit_descriptionLabel => 'الوصف';

  @override
  String get marineLife_speciesEdit_editTitle => 'تعديل النوع';

  @override
  String marineLife_speciesEdit_errorLoading(Object error) {
    return 'خطأ في تحميل النوع: $error';
  }

  @override
  String marineLife_speciesEdit_errorSaving(Object error) {
    return 'خطأ في حفظ النوع: $error';
  }

  @override
  String get marineLife_speciesEdit_saveButton => 'حفظ';

  @override
  String get marineLife_speciesEdit_scientificNameHint =>
      'مثال: Amphiprion ocellaris';

  @override
  String get marineLife_speciesEdit_scientificNameLabel => 'الاسم العلمي';

  @override
  String get marineLife_speciesEdit_taxonomyClassHint => 'مثال: Actinopterygii';

  @override
  String get marineLife_speciesEdit_taxonomyClassLabel => 'الصنف التصنيفي';

  @override
  String marineLife_speciesEdit_updatedSnackbar(Object name) {
    return 'تم تحديث \"$name\"';
  }

  @override
  String get marineLife_speciesManage_allFilter => 'الكل';

  @override
  String get marineLife_speciesManage_appBarTitle => 'الأنواع';

  @override
  String get marineLife_speciesManage_backTooltip => 'رجوع';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return 'الأنواع المدمجة ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => 'إلغاء';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return 'لا يمكن حذف \"$name\" - يحتوي على مشاهدات';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip => 'مسح البحث';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return 'الأنواع المخصصة ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => 'حذف';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return 'هل أنت متأكد أنك تريد حذف \"$name\"؟';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle => 'حذف النوع؟';

  @override
  String get marineLife_speciesManage_deleteTooltip => 'حذف النوع';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return 'تم حذف \"$name\"';
  }

  @override
  String get marineLife_speciesManage_editTooltip => 'تعديل النوع';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return 'خطأ في حذف النوع: $error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return 'خطأ في إعادة التعيين: $error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound =>
      'لم يتم العثور على أنواع';

  @override
  String get marineLife_speciesManage_resetButton => 'إعادة تعيين';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      'سيؤدي هذا إلى استعادة جميع الأنواع المدمجة إلى قيمها الأصلية. لن تتأثر الأنواع المخصصة. سيتم تحديث الأنواع المدمجة التي لديها مشاهدات حالية مع الحفاظ عليها.';

  @override
  String get marineLife_speciesManage_resetDialogTitle =>
      'إعادة التعيين إلى الافتراضي؟';

  @override
  String get marineLife_speciesManage_resetSuccess =>
      'تمت استعادة الأنواع المدمجة إلى الإعدادات الافتراضية';

  @override
  String get marineLife_speciesManage_resetToDefaults =>
      'إعادة التعيين إلى الافتراضي';

  @override
  String get marineLife_speciesManage_searchHint => 'البحث في الأنواع...';

  @override
  String get marineLife_speciesPicker_allFilter => 'الكل';

  @override
  String get marineLife_speciesPicker_cancelButton => 'إلغاء';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip => 'مسح البحث';

  @override
  String get marineLife_speciesPicker_closeTooltip => 'إغلاق منتقي الأنواع';

  @override
  String get marineLife_speciesPicker_doneButton => 'تم';

  @override
  String marineLife_speciesPicker_error(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get marineLife_speciesPicker_noSpeciesFound =>
      'لم يتم العثور على أنواع';

  @override
  String get marineLife_speciesPicker_searchHint => 'البحث في الأنواع...';

  @override
  String marineLife_speciesPicker_selectedCount(Object count) {
    return '$count محدد';
  }

  @override
  String get marineLife_speciesPicker_title => 'اختيار الأنواع';

  @override
  String get media_diveMediaSection_addTooltip => 'إضافة صورة أو فيديو';

  @override
  String get media_diveMediaSection_cancelButton => 'إلغاء';

  @override
  String get media_diveMediaSection_cancelSelectionButton => 'إلغاء';

  @override
  String get media_diveMediaSection_emptyState => 'لا توجد صور بعد';

  @override
  String get media_diveMediaSection_errorLoading => 'خطأ في تحميل الوسائط';

  @override
  String get media_diveMediaSection_selectAllButton => 'تحديد الكل';

  @override
  String media_diveMediaSection_selectedCount(int count) {
    return '$count محدد';
  }

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'عرض الصورة. اضغط مطولًا لإلغاء الربط';

  @override
  String get media_diveMediaSection_title => 'الصور والفيديو';

  @override
  String get media_diveMediaSection_replaceButton => 'إعادة الربط';

  @override
  String get media_diveMediaSection_replaceEditedContent =>
      'محتوى هذا الملف يختلف عن الأصل. إعادة الربط ستعيد رفعه إلى مخزن الوسائط الخاص بك.';

  @override
  String get media_diveMediaSection_replaceEditedTitle => 'محتوى الملف مختلف';

  @override
  String get media_diveMediaSection_unlinkButton => 'إلغاء الربط';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'فشل في إلغاء الربط: $error';
  }

  @override
  String media_diveMediaSection_unlinkSelectedButton(int count) {
    return 'إلغاء ربط $count';
  }

  @override
  String media_diveMediaSection_unlinkSelectedContent(int count) {
    return 'يزيل $count من عناصر الوسائط من مكتبتك، مع نسخها السحابية والصور المصغرة. تبقى العناصر التي لا يزال موقع غوص يستخدمها. لن تتأثر ملفاتك الأصلية.';
  }

  @override
  String media_diveMediaSection_unlinkSelectedSuccess(int count) {
    return 'تم إلغاء ربط $count عنصر';
  }

  @override
  String media_diveMediaSection_unlinkSelectedTitle(int count) {
    return 'إلغاء ربط $count عنصر؟';
  }

  @override
  String media_library_unlinkConfirmTitle(int count) {
    return 'إلغاء ربط $count عنصر؟';
  }

  @override
  String media_siteMediaSection_unlinkError(Object error) {
    return 'فشل في إلغاء الربط: $error';
  }

  @override
  String get media_library_unlinkConfirmBody =>
      'ستغادر مكتبتك، مع نسخها السحابية والصور المصغرة. لن تتأثر ملفاتك الأصلية. لا يمكن التراجع عن هذا.';

  @override
  String media_library_unlinkMetadataNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'يحتوي $count منها على تعليق أو علامة مفضلة محفوظة في Submersion، وستُفقد هذه التفاصيل.',
      one:
          'يحتوي واحد منها على تعليق أو علامة مفضلة محفوظة في Submersion، وستُفقد هذه التفاصيل.',
    );
    return '$_temp0';
  }

  @override
  String get media_siteMediaSection_title => 'وسائط الموقع';

  @override
  String get media_siteMediaSection_addPhotos => 'إضافة صور أو مقاطع فيديو';

  @override
  String get media_siteMediaSection_addDocument => 'إضافة مستند';

  @override
  String get media_siteMediaSection_emptyState =>
      'لا توجد خرائط أو صور أو مستندات مرفقة بهذا الموقع';

  @override
  String media_siteMediaSection_divePhotosGroup(int count) {
    return 'صور من الغوصات هنا ($count)';
  }

  @override
  String get media_siteMediaSection_divePhotoLabel => 'صورة غوص';

  @override
  String media_siteMediaSection_unlinkSelectedTitle(int count) {
    return 'إلغاء ربط $count عنصر؟';
  }

  @override
  String media_siteMediaSection_unlinkSelectedContent(int count) {
    return 'يزيل $count عنصرًا من مكتبتك مع نسخها السحابية وصورها المصغرة. تُحفظ الوسائط التي لا تزال غطسة تستخدمها. ملفاتك الأصلية لا تتأثر.';
  }

  @override
  String media_siteMediaSection_unlinkSelectedSuccess(int count) {
    return 'تم إلغاء ربط $count عنصر';
  }

  @override
  String get media_documentViewer_title => 'مستند';

  @override
  String get media_documentViewer_unavailable =>
      'هذا المستند غير متاح على هذا الجهاز';

  @override
  String get media_documentViewer_availableOnOriginDevice =>
      'وهو متاح على الجهاز الذي أُضيف منه، أو عبر مخزن وسائط مُهيأ.';

  @override
  String media_documentViewer_attached(int count) {
    return 'تم إرفاق $count من المستندات';
  }

  @override
  String get media_diveScan_scanTooltip => 'مسح المعرض بحثا عن الصور';

  @override
  String get media_diveScan_noPhotosFound =>
      'لم يتم العثور على صور جديدة بالقرب من هذه الغوصة';

  @override
  String get media_diveScan_accessDenied =>
      'يلزم الوصول إلى مكتبة الصور للبحث عن الصور';

  @override
  String media_diveScan_foundPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صور',
      one: 'صورة واحدة',
    );
    return 'تم العثور على $_temp0 بالقرب من هذه الغوصة. هل تريد ربطها؟';
  }

  @override
  String get media_diveScan_foundTitle => 'تم العثور على صور';

  @override
  String media_diveScan_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الصور',
      one: 'الصورة',
    );
    return 'ربط $_temp0';
  }

  @override
  String get media_diveScan_cancelButton => 'إلغاء';

  @override
  String media_diveScan_error(String error) {
    return 'خطأ في مسح المعرض: $error';
  }

  @override
  String get media_gpsBanner_addToSiteButton => 'إضافة إلى الموقع';

  @override
  String media_gpsBanner_coordinates(Object coordinates) {
    return 'الإحداثيات: $coordinates';
  }

  @override
  String get media_gpsBanner_createSiteButton => 'إنشاء موقع غوص';

  @override
  String get media_gpsBanner_dismissTooltip => 'تجاهل اقتراح GPS';

  @override
  String get media_gpsBanner_title => 'تم العثور على GPS في الصور';

  @override
  String media_import_failedToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'صور',
      one: 'صورة',
    );
    return 'فشل في استيراد $_temp0';
  }

  @override
  String media_import_failedToImportError(Object error) {
    return 'فشل في استيراد الصور: $error';
  }

  @override
  String media_import_allAlreadyLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صورة مرتبطة بالفعل بهذه الغوصة',
      one: 'صورة واحدة مرتبطة بالفعل بهذه الغوصة',
    );
    return '$_temp0';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return 'تم استيراد $imported، فشل $failed';
  }

  @override
  String media_import_importedAndSkipped(int imported, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      imported,
      locale: localeName,
      other: 'تم استيراد $imported صورة',
      one: 'تم استيراد صورة واحدة',
    );
    return '$_temp0 ($skipped مرتبطة بالفعل)';
  }

  @override
  String media_import_importedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'صور',
      one: 'صورة',
    );
    return 'تم استيراد $count $_temp0';
  }

  @override
  String media_import_importingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'صور',
      one: 'صورة',
    );
    return 'جارٍ استيراد $count $_temp0...';
  }

  @override
  String get media_lightroom_openInLightroom => 'فتح في Lightroom';

  @override
  String get media_lightroom_suggestion_accept => 'إضافة إلى هذه الغطسة';

  @override
  String get media_lightroom_suggestion_dismiss => 'تجاهل';

  @override
  String get media_lightroom_suggestions_title => 'اقتراحات من Lightroom';

  @override
  String get media_miniProfile_headerLabel => 'ملف الغوصة';

  @override
  String get media_miniProfile_semanticLabel => 'مخطط ملف الغوصة المصغر';

  @override
  String get media_photoPicker_appBarTitle => 'اختيار الصور';

  @override
  String get media_photoPicker_tab_gallery => 'المعرض';

  @override
  String get media_photoPicker_tab_files => 'الملفات';

  @override
  String get media_photoPicker_tab_url => 'URL';

  @override
  String get media_photoPicker_clearSelectionButton => 'مسح';

  @override
  String get media_photoPicker_closeTooltip => 'إغلاق منتقي الصور';

  @override
  String get media_photoPicker_doneButton => 'تم';

  @override
  String media_photoPicker_doneCountButton(Object count) {
    return 'تم ($count)';
  }

  @override
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  ) {
    return 'لم يتم العثور على صور بين $startDate $startTime و $endDate $endTime.';
  }

  @override
  String get media_photoPicker_emptyTitle => 'لم يتم العثور على صور';

  @override
  String get media_photoPicker_grantAccessButton => 'متابعة';

  @override
  String get media_photoPicker_openSettingsButton => 'فتح الإعدادات';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'تم رفض الوصول إلى مكتبة الصور. يرجى تمكينه في الإعدادات لإضافة صور الغوص.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'يحتاج Submersion إلى الوصول إلى مكتبة الصور لإضافة صور الغوص.';

  @override
  String get media_photoPicker_permissionTitle => 'صور الغوص';

  @override
  String get media_photoPicker_selectAllButton => 'تحديد الكل';

  @override
  String media_photoPicker_selectedCount(int count) {
    return '$count محدد';
  }

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return 'عرض الصور من $rangeText';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel => 'تبديل اختيار الصورة';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel =>
      'تبديل اختيار الصورة، محددة';

  @override
  String get media_photoPicker_files_pickFilesButton => 'اختيار الملفات…';

  @override
  String get media_photoPicker_files_pickFolderButton => 'اختيار مجلد…';

  @override
  String get media_photoPicker_files_autoMatchLabel =>
      'مطابقة الصور ومقاطع الفيديو تلقائيًا مع الغوصات حسب التاريخ';

  @override
  String get media_photoPicker_files_emptyHint => 'اختر ملفات أو مجلدًا للبدء.';

  @override
  String media_photoPicker_files_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ربط $count عناصر',
      one: 'ربط عنصر واحد',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachToSiteButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إرفاق $count عناصر بهذا الموقع',
      one: 'إرفاق عنصر واحد بهذا الموقع',
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
      other: '$fileCount ملفات',
      one: 'ملف واحد',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount غوصات',
      one: 'غوصة واحدة',
    );
    return '$_temp0، $_temp1، $unmatchedCount غير مطابق';
  }

  @override
  String media_photoPicker_files_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عناصر',
      one: 'عنصر واحد',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_diveGroupTitle(String diveId) {
    return 'الغوصة $diveId';
  }

  @override
  String media_photoPicker_files_groupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملفات',
      one: 'ملف واحد',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_unmatchedGroupTitle => 'غير مطابق';

  @override
  String media_photoPicker_files_addAllToDive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إضافة كل الـ $count إلى هذه الغوصة',
      one: 'إضافة عنصر واحد إلى هذه الغوصة',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_addToDiveTooltip => 'إضافة إلى هذه الغوصة';

  @override
  String get media_photoPicker_files_chooseDiveTooltip => 'اختيار غوصة';

  @override
  String get media_photoPicker_files_removeTooltip => 'إزالة من التحديد';

  @override
  String get media_photoPicker_files_sourceExif => 'من EXIF';

  @override
  String get media_photoPicker_files_sourceContainer =>
      'من بيانات الملف الوصفية';

  @override
  String get media_photoPicker_files_sourceFileDate => 'من تاريخ الملف';

  @override
  String get media_photoPicker_files_sourceNone => 'لم يُعثر على تاريخ';

  @override
  String media_photoPicker_files_shiftedTime(String shifted, String original) {
    return '$shifted (كان $original)';
  }

  @override
  String get media_photoPicker_files_reasonNoTimestamp =>
      'تعذّرت قراءة وقت الالتقاط';

  @override
  String media_photoPicker_files_reasonBeforeDive(String gap) {
    return '$gap قبل أقرب غوصة';
  }

  @override
  String media_photoPicker_files_reasonAfterDive(String gap) {
    return '$gap بعد أقرب غوصة';
  }

  @override
  String get media_photoPicker_files_reasonNoDives =>
      'لا توجد غوصات للمطابقة معها';

  @override
  String get media_photoPicker_files_offsetLabel =>
      'إزاحة أوقات الالتقاط بمقدار';

  @override
  String get media_photoPicker_files_offsetResetTooltip =>
      'إعادة تعيين الإزاحة';

  @override
  String media_photoPicker_files_offsetBackTooltip(String amount) {
    return 'إزاحة $amount للخلف';
  }

  @override
  String media_photoPicker_files_offsetForwardTooltip(String amount) {
    return 'إزاحة $amount للأمام';
  }

  @override
  String media_photoPicker_files_linkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم ربط $count عناصر',
      one: 'تم ربط عنصر واحد',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachedToSiteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم إرفاق $count عناصر بهذا الموقع',
      one: 'تم إرفاق عنصر واحد بهذا الموقع',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_undo => 'تراجع';

  @override
  String get media_photoPicker_thumbnailAlreadyLinkedLabel =>
      'الصورة مرتبطة بالفعل بهذه الغوصة';

  @override
  String get media_perdixOverlay_labelCns => 'CNS';

  @override
  String get media_perdixOverlay_labelDepth => 'العمق';

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
  String get media_perdixOverlay_labelTemp => 'الحرارة';

  @override
  String get media_perdixOverlay_labelTime => 'الوقت';

  @override
  String get media_perdixOverlay_labelTts => 'TTS';

  @override
  String get media_perdixOverlay_toggleTooltip => 'طبقة كمبيوتر الغوص';

  @override
  String get media_photoViewer_cannotShare => 'لا يمكن مشاركة هذه الصورة';

  @override
  String get media_photoViewer_cannotWriteMetadata =>
      'لا يمكن كتابة البيانات الوصفية - الوسائط غير مرتبطة بالمكتبة';

  @override
  String get media_photoViewer_closeTooltip => 'إغلاق عارض الصور';

  @override
  String get media_photoViewer_diveDataWrittenToPhoto =>
      'تمت كتابة بيانات الغوصة على الصورة';

  @override
  String get media_photoViewer_diveDataWrittenToVideo =>
      'تمت كتابة بيانات الغوصة على الفيديو';

  @override
  String media_photoViewer_errorLoadingPhotos(Object error) {
    return 'خطأ في تحميل الصور: $error';
  }

  @override
  String get media_photoViewer_failedToLoadImage => 'فشل في تحميل الصورة';

  @override
  String get media_photoViewer_failedToLoadVideo => 'فشل في تحميل الفيديو';

  @override
  String media_photoViewer_failedToShare(Object error) {
    return 'فشل في المشاركة: $error';
  }

  @override
  String get media_photoViewer_failedToWriteMetadata =>
      'فشل في كتابة البيانات الوصفية';

  @override
  String media_photoViewer_failedToWriteMetadataError(Object error) {
    return 'فشل في كتابة البيانات الوصفية: $error';
  }

  @override
  String get media_photoViewer_nextTooltip => 'الوسائط التالية';

  @override
  String get media_photoViewer_noPhotosAvailable => 'لا توجد صور متاحة';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel => 'تشغيل أو إيقاف الفيديو';

  @override
  String get media_photoViewer_previousTooltip => 'الوسائط السابقة';

  @override
  String get media_photoViewer_seekVideoLabel => 'تحريك موضع الفيديو';

  @override
  String get media_photoViewer_shareTooltip => 'مشاركة الصورة';

  @override
  String get media_photoViewer_toggleOverlayLabel => 'تبديل طبقة الصورة';

  @override
  String get media_photoViewer_videoFileNotFound => 'ملف الفيديو غير موجود';

  @override
  String get media_photoViewer_videoNotLinked => 'الفيديو غير مرتبط بالمكتبة';

  @override
  String get media_photoViewer_writeDiveDataTooltip =>
      'كتابة بيانات الغوصة على الصورة';

  @override
  String get media_quickSiteDialog_cancelButton => 'إلغاء';

  @override
  String get media_quickSiteDialog_createButton => 'إنشاء موقع غوص';

  @override
  String get media_quickSiteDialog_description =>
      'إنشاء موقع غوص جديد باستخدام إحداثيات GPS من صورتك.';

  @override
  String get media_quickSiteDialog_siteNameError => 'يرجى إدخال اسم الموقع';

  @override
  String get media_quickSiteDialog_siteNameHint => 'أدخل اسمًا لهذا الموقع';

  @override
  String get media_quickSiteDialog_siteNameLabel => 'اسم الموقع';

  @override
  String get media_quickSiteDialog_title => 'إنشاء موقع غوص';

  @override
  String get media_scanResults_allPhotosLinked => 'جميع الصور مرتبطة بالفعل';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return 'جميع الصور البالغ عددها $count من هذه الرحلة مرتبطة بالفعل بالغوصات.';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count صور مرتبطة بالفعل';
  }

  @override
  String get media_scanResults_cancelButton => 'إلغاء';

  @override
  String media_scanResults_diveNumber(Object number) {
    return 'غوصة #$number';
  }

  @override
  String media_scanResults_foundNewPhotos(Object count) {
    return 'تم العثور على $count صور جديدة';
  }

  @override
  String get media_scanResults_linkButton => 'ربط';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return 'ربط $count صور';
  }

  @override
  String get media_scanResults_noPhotosFound => 'لم يتم العثور على صور';

  @override
  String get media_scanResults_okButton => 'موافق';

  @override
  String get media_scanResults_unknownSite => 'موقع غوص غير معروف';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return '$count صور لم يمكن مطابقتها مع أي غوصة (تم التقاطها خارج أوقات الغوص)';
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
      'غير متوفر على هذا الجهاز';

  @override
  String get media_unavailablePlaceholder_signInRequired => 'Sign in to view';

  @override
  String get media_writeMetadata_cancelButton => 'إلغاء';

  @override
  String get media_writeMetadata_depthLabel => 'العمق';

  @override
  String get media_writeMetadata_descriptionPhoto =>
      'سيتم كتابة البيانات الوصفية التالية على الصورة:';

  @override
  String get media_writeMetadata_descriptionVideo =>
      'سيتم كتابة البيانات الوصفية التالية على الفيديو:';

  @override
  String get media_writeMetadata_diveTimeLabel => 'وقت الغوصة';

  @override
  String get media_writeMetadata_gpsLabel => 'GPS';

  @override
  String get media_writeMetadata_keepOriginalVideo =>
      'الاحتفاظ بالفيديو الأصلي';

  @override
  String get media_writeMetadata_livePhotoUnsupported =>
      'صور Live Photos غير مدعومة بعد. كرّر هذه الصورة كصورة ثابتة، ثم اكتب بيانات الغوص في النسخة.';

  @override
  String get media_writeMetadata_noDataAvailable =>
      'لا توجد بيانات غوص متاحة للكتابة.';

  @override
  String get media_writeMetadata_siteLabel => 'الموقع';

  @override
  String get media_writeMetadata_temperatureLabel => 'درجة الحرارة';

  @override
  String get media_writeMetadata_titlePhoto => 'كتابة بيانات الغوصة على الصورة';

  @override
  String get media_writeMetadata_titleVideo =>
      'كتابة بيانات الغوصة على الفيديو';

  @override
  String get media_writeMetadata_warningPhotoText =>
      'سيؤدي هذا إلى تعديل الصورة الأصلية.';

  @override
  String get media_writeMetadata_warningVideoText =>
      'سيتم إنشاء فيديو جديد مع البيانات الوصفية. لا يمكن تعديل البيانات الوصفية للفيديو في مكانها.';

  @override
  String get media_writeMetadata_writeButton => 'كتابة';

  @override
  String get nav_buddies => 'زملاء الغوص';

  @override
  String get nav_certifications => 'الشهادات';

  @override
  String get nav_courses => 'الدورات';

  @override
  String get nav_coursesSubtitle => 'التدريب والتعليم';

  @override
  String get nav_diveCenters => 'مراكز الغوص';

  @override
  String get nav_dives => 'الغوصات';

  @override
  String get nav_equipment => 'المعدات';

  @override
  String get nav_gpsLog => 'سجل GPS';

  @override
  String get media_console_library => 'المكتبة';

  @override
  String get media_console_transfers => 'عمليات النقل';

  @override
  String get media_console_import => 'استيراد';

  @override
  String get media_import_launch => 'استيراد الوسائط...';

  @override
  String get media_import_review_title => 'مراجعة الاستيراد';

  @override
  String media_import_review_confirm(int count) {
    return 'استيراد $count عنصرًا';
  }

  @override
  String media_import_review_result(int linked, int skipped, int failed) {
    return '$linked مرتبطة، $skipped متخطاة، $failed فاشلة';
  }

  @override
  String get media_import_review_chooseSite => 'اختر الموقع';

  @override
  String get media_import_review_ambiguous => 'تتطابق عدة غطسات';

  @override
  String get media_import_review_noMatch => 'لا توجد غطسة مطابقة';

  @override
  String get media_import_review_skipped => 'لم يتم الاستيراد';

  @override
  String media_import_review_linkChip(int number) {
    return 'ربط بالغطسة رقم $number';
  }

  @override
  String get media_import_review_linkToDive => 'ربط بغطسة';

  @override
  String get media_import_review_linkToSite => 'ربط بموقع';

  @override
  String get media_import_review_chooseDive => 'اختيار الغطسة';

  @override
  String get media_import_intro =>
      'تُربط الصور بغطسة أو موقع غطس أثناء استيرادها.';

  @override
  String get media_console_sources => 'المصادر';

  @override
  String get media_sources_browseHeader => 'التصفح حسب المصدر';

  @override
  String get media_sources_watchedHeader => 'المجلدات المراقَبة';

  @override
  String get media_sources_addWatched => 'إضافة مجلد...';

  @override
  String get media_sources_scanFailed => 'فشل الفحص';

  @override
  String get media_sources_scanNow => 'فحص الآن';

  @override
  String get media_sources_autoApply => 'إعادة ربط المطابقات التامة تلقائيًا';

  @override
  String get media_sources_neverScanned => 'لم يتم الفحص مطلقًا';

  @override
  String get media_source_gallery => 'مكتبة الصور';

  @override
  String get media_source_localFile => 'الملفات المحلية';

  @override
  String get media_source_networkUrl => 'روابط الويب';

  @override
  String get media_source_manifest => 'الاشتراكات';

  @override
  String get media_source_connector => 'الخدمات المتصلة';

  @override
  String get media_source_mediaStore => 'مخزن الوسائط السحابي';

  @override
  String get media_source_signature => 'التوقيعات';

  @override
  String get media_repairHistory_title => 'سجل الإصلاحات';

  @override
  String get media_repairHistory_empty => 'لا توجد إصلاحات بعد';

  @override
  String get media_repairHistory_action_relink => 'أعيد ربطه';

  @override
  String get media_repairHistory_action_cloudBacked => 'مدعوم سحابيًا';

  @override
  String get media_repairHistory_action_autoRelink => 'أعيد ربطه تلقائيًا';

  @override
  String get media_smartAlbum_save => 'حفظ كألبوم';

  @override
  String get media_smartAlbum_saveTitle => 'تسمية هذا الألبوم';

  @override
  String get media_smartAlbum_albums => 'الألبومات';

  @override
  String get media_smartAlbum_delete => 'حذف الألبوم';

  @override
  String get media_smartAlbum_deleteFailed => 'تعذّر حذف الألبوم';

  @override
  String get media_smartAlbum_saved => 'تم حفظ الألبوم';

  @override
  String media_sources_lastScanned(String date) {
    return 'آخر فحص $date';
  }

  @override
  String media_sources_scanResult(int indexed, int repaired) {
    return 'تمت فهرسة $indexed ملفات، وأعيد ربط $repaired';
  }

  @override
  String get media_repairHistory_sourceFolder => 'فحص المجلدات';

  @override
  String get media_repairHistory_sourcePhotoLibrary => 'مكتبة الصور';

  @override
  String get media_repairHistory_sourceStore => 'مخزن الوسائط السحابي';

  @override
  String get media_repairHistory_sourceWatcher => 'المجلدات المراقَبة';

  @override
  String get media_repairHistory_sourceManual => 'إعادة ربط يدوية';

  @override
  String media_repairHistory_source(String source) {
    return 'عبر $source';
  }

  @override
  String get media_missing_empty => 'لا توجد ملفات مفقودة';

  @override
  String media_missing_offlineVolumes(int count) {
    return '$count على وحدات تخزين غير متصلة';
  }

  @override
  String get media_missing_repair => 'إصلاح...';

  @override
  String get media_repair_title => 'إصلاح الملفات المفقودة';

  @override
  String get media_repair_addFolder => 'إضافة مجلد...';

  @override
  String get media_repair_usePhotoLibrary => 'البحث في مكتبة الصور';

  @override
  String get media_repair_useStore => 'استخدام مخزن الوسائط السحابي';

  @override
  String get media_repair_scan => 'فحص';

  @override
  String media_repair_prefixMove(String from, String to, int count) {
    return 'تم اكتشاف نقل مجلد: $from إلى $to يغطي $count ملفات';
  }

  @override
  String get media_repair_confidence_exact => 'مطابقة تامة';

  @override
  String get media_repair_confidence_probable => 'الاسم والحجم';

  @override
  String get media_repair_confidence_edited => 'ملف معدل';

  @override
  String get media_repair_confidence_unmatched => 'لا يوجد مرشح';

  @override
  String get media_repair_unverified => 'لم يتم التحقق منه مقابل المخزن';

  @override
  String media_repair_apply(int count) {
    return 'إعادة ربط $count ملفات';
  }

  @override
  String media_repair_summary(
    int relinked,
    int cloudBacked,
    int reuploads,
    int failed,
    int skipped,
  ) {
    return '$relinked أعيد ربطها، $cloudBacked مدعومة سحابيًا، $reuploads في قائمة إعادة الرفع، $failed فشلت، $skipped تم تخطيها';
  }

  @override
  String get media_library_empty => 'لا توجد وسائط بعد';

  @override
  String get media_library_filter_all => 'الكل';

  @override
  String get media_library_filter_photos => 'الصور';

  @override
  String get media_library_filter_videos => 'مقاطع الفيديو';

  @override
  String get media_library_filter_site => 'الموقع';

  @override
  String get media_library_filter_trip => 'الرحلة';

  @override
  String get media_library_filter_dates => 'التواريخ';

  @override
  String get media_library_filter_missing => 'ملفات مفقودة';

  @override
  String media_library_filter_missingCount(int count) {
    return 'ملفات مفقودة ($count)';
  }

  @override
  String get media_library_filter_clear => 'مسح عوامل التصفية';

  @override
  String get media_library_filter_any => 'أي';

  @override
  String get media_library_filter_title => 'تصفية الوسائط';

  @override
  String get media_library_filter_apply => 'تطبيق';

  @override
  String get media_library_sort_title => 'فرز الوسائط';

  @override
  String get media_smartAlbum_load => 'تحميل الألبوم';

  @override
  String get media_divePicker_title => 'نقل إلى غطسة';

  @override
  String get media_divePicker_search => 'البحث في الغطسات';

  @override
  String get media_library_moveToDive => 'نقل إلى غطسة';

  @override
  String get media_library_unlinkSelected => 'إلغاء الربط';

  @override
  String media_library_selectedCount(int count) {
    return 'تم تحديد $count';
  }

  @override
  String get media_library_unlinkedHeader => 'غير مرتبطة';

  @override
  String get media_library_diveHeaderHint => 'فتح هذه الغطسة';

  @override
  String get media_library_untitledDiveHeader => 'غطسة بدون عنوان';

  @override
  String get media_library_viewMode_byDive => 'حسب الغطسة';

  @override
  String get media_library_viewMode_grid => 'شبكة';

  @override
  String get media_library_viewMode_timeline => 'الخط الزمني';

  @override
  String get media_viewer_goToDive => 'الانتقال إلى الغطسة';

  @override
  String get nav_home => 'الرئيسية';

  @override
  String get nav_media => 'الوسائط';

  @override
  String get nav_more => 'المزيد';

  @override
  String get nav_planning => 'التخطيط';

  @override
  String get nav_planningSubtitle => 'مخطط الغوص، الآلات الحاسبة';

  @override
  String get nav_settings => 'الإعدادات';

  @override
  String get nav_sites => 'المواقع';

  @override
  String get nav_statistics => 'الإحصائيات';

  @override
  String get nav_tooltip_closeMenu => 'إغلاق القائمة';

  @override
  String get nav_tooltip_collapseMenu => 'طي القائمة';

  @override
  String get nav_tooltip_expandMenu => 'توسيع القائمة';

  @override
  String get nav_transfer => 'نقل البيانات';

  @override
  String get nav_trips => 'الرحلات';

  @override
  String plannerCanvas_bailout_available(String liters) {
    return 'المتاح $liters';
  }

  @override
  String get plannerCanvas_bailout_insufficient =>
      'غاز الإنقاذ غير كافٍ لأسوأ حالة';

  @override
  String plannerCanvas_bailout_required(String liters) {
    return 'المطلوب $liters';
  }

  @override
  String get plannerCanvas_bailout_title => 'إنقاذ (دائرة مفتوحة)';

  @override
  String plannerCanvas_bailout_tts(String minutes) {
    return 'TTS للإنقاذ $minutes′';
  }

  @override
  String plannerCanvas_bailout_worstCase(String minutes, String depth) {
    return 'أسوأ حالة عند $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_ccr_setpointHigh => 'نقطة الضبط العليا (bar)';

  @override
  String get plannerCanvas_ccr_setpointLow => 'نقطة الضبط الدنيا (bar)';

  @override
  String get plannerCanvas_ccr_switchDepth => 'عمق تبديل نقطة الضبط';

  @override
  String get plannerCanvas_pscr_ratio => 'نسبة pSCR';

  @override
  String get plannerCanvas_pscr_ratio_hint =>
      'أكبر = غاز طازج أكثر وانخفاض أقل في الأكسجين';

  @override
  String plannerCanvas_chip_cns(String value) {
    return 'CNS $value%';
  }

  @override
  String plannerCanvas_chip_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مشكلات',
      one: 'مشكلة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get plannerCanvas_compare_action => 'مقارنة';

  @override
  String get plannerCanvas_compare_needTwo => 'اختر خطتين على الأقل للمقارنة';

  @override
  String get plannerCanvas_compare_title => 'مقارنة الخطط';

  @override
  String get plannerCanvas_contingency_base => 'أساسي';

  @override
  String get plannerCanvas_contingency_depthDelta => 'عمق إضافي';

  @override
  String plannerCanvas_contingency_lostGas(String gas) {
    return 'فقدان $gas';
  }

  @override
  String plannerCanvas_contingency_previewing(String label) {
    return 'معاينة: $label';
  }

  @override
  String get plannerCanvas_contingency_timeDelta => 'دقائق إضافية';

  @override
  String plannerCanvas_chart_meanDepth(String depth) {
    return 'المتوسط $depth';
  }

  @override
  String get plannerCanvas_contingency_title => 'خطط الطوارئ';

  @override
  String get plannerCanvas_contingency_turnFraction => 'نسبة العودة';

  @override
  String get plannerCanvas_contingency_turnRule => 'قاعدة ضغط العودة';

  @override
  String get plannerCanvas_convert_success => 'تم إنشاء غطسة من الخطة';

  @override
  String get plannerCanvas_convert_view => 'عرض';

  @override
  String plannerCanvas_follow_chip(String name) {
    return 'يتبع $name';
  }

  @override
  String get plannerCanvas_follow_empty => 'لا توجد غطسات مسجلة بعد';

  @override
  String get plannerCanvas_follow_noTissues =>
      'لا توجد بيانات ملف تعريف لهذه الغطسة — تم ضبط الفاصل السطحي دون تحميل الأنسجة';

  @override
  String get plannerCanvas_follow_title => 'اتباع غطسة';

  @override
  String plannerCanvas_gas_minGas(String pressure) {
    return 'الحد الأدنى للغاز $pressure';
  }

  @override
  String plannerCanvas_gas_turnAt(String pressure) {
    return 'العودة عند $pressure';
  }

  @override
  String plannerCanvas_issue_gasDensityCritical(String value) {
    return 'كثافة الغاز $value g/L تتجاوز الحد الأقصى';
  }

  @override
  String plannerCanvas_issue_gasDensityHigh(String value) {
    return 'كثافة الغاز $value g/L تتجاوز الحد الموصى به';
  }

  @override
  String plannerCanvas_issue_hypoxic(String depth, String value) {
    return 'غاز ناقص الأكسجين عند $depth (ppO₂ $value bar)';
  }

  @override
  String plannerCanvas_issue_minGas(String pressure) {
    return 'تنتهي الأسطوانة تحت الحد الأدنى الآمن $pressure';
  }

  @override
  String get plannerCanvas_issue_noBailout =>
      'خطة تخفيف الضغط CCR لا تتضمن غاز إنقاذ (bailout)';

  @override
  String get plannerCanvas_issue_noDecoGas =>
      'يلزم تخفيف الضغط ولكن لا يوجد غاز تخفيف';

  @override
  String get plannerCanvas_range_base => 'أساسي';

  @override
  String get plannerCanvas_range_legend =>
      'تعرض الخلايا زمن الصعود إلى السطح؛ الأحمر = غير قابلة للغطس كما هو مخطط';

  @override
  String get plannerCanvas_pane_collapse => 'طي اللوحة';

  @override
  String get plannerCanvas_pane_expand => 'توسيع اللوحة';

  @override
  String get plannerCanvas_tab_setup => 'الإعداد';

  @override
  String get plannerCanvas_o2Narcotic => 'اعتبار الأكسجين مخدرًا';

  @override
  String get plannerCanvas_rates_ascent => 'معدل الصعود';

  @override
  String get plannerCanvas_rates_descent => 'معدل النزول';

  @override
  String get plannerCanvas_rates_title => 'المعدلات';

  @override
  String get plannerCanvas_range_title => 'جدول النطاقات';

  @override
  String get plannerCanvas_results_noDeco => 'لا يلزم تخفيف الضغط';

  @override
  String plannerCanvas_sac_useLogged(String sac) {
    return 'استخدام المتوسط المسجل ($sac)';
  }

  @override
  String plannerCanvas_saved_deleteConfirmBody(String name) {
    return 'حذف \"$name\" نهائيًا؟';
  }

  @override
  String get plannerCanvas_saved_deleteConfirmTitle => 'حذف الخطة؟';

  @override
  String get plannerCanvas_saved_duplicate => 'تكرار';

  @override
  String get plannerCanvas_saved_empty => 'لا توجد خطط محفوظة بعد';

  @override
  String get plannerCanvas_saved_title => 'الخطط المحفوظة';

  @override
  String get plannerCanvas_name_dialogTitle => 'سمِّ خطتك';

  @override
  String get plannerCanvas_name_defaultFallback => 'خطة غوص';

  @override
  String plannerCanvas_scrub_bailout(String minutes) {
    return 'BO $minutes′';
  }

  @override
  String plannerCanvas_scrub_readout(String minutes, String depth) {
    return 'RT $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_share_import => 'استيراد';

  @override
  String plannerCanvas_share_importFailed(String reason) {
    return 'تعذر استيراد الخطة: $reason';
  }

  @override
  String get plannerCanvas_share_menu => 'مشاركة ملف الخطة';

  @override
  String get plannerCanvas_slate_menu => 'تصدير اللوح (PDF)';

  @override
  String get plannerCanvas_slate_minGas => 'الحد الأدنى من الغاز';

  @override
  String get plannerCanvas_slate_turn => 'العودة';

  @override
  String get plannerCanvas_table_depth => 'العمق';

  @override
  String get plannerCanvas_table_gas => 'الغاز';

  @override
  String get plannerCanvas_table_runtime => 'RT';

  @override
  String get plannerCanvas_table_stop => 'توقف';

  @override
  String get plannerCanvas_turnRule_allUsable => 'كل القابل للاستخدام';

  @override
  String get plannerCanvas_turnRule_custom => 'مخصص';

  @override
  String get plannerCanvas_turnRule_halves => 'أنصاف';

  @override
  String get plannerCanvas_turnRule_none => 'بدون';

  @override
  String get plannerCanvas_turnRule_thirds => 'أثلاث';

  @override
  String get planning_appBar_title => 'التخطيط';

  @override
  String get planning_card_decoCalculator_description =>
      'احسب حدود عدم تخفيف الضغط، ومحطات تخفيف الضغط المطلوبة، والتعرض لـ CNS/OTU لملفات الغوص متعددة المستويات.';

  @override
  String get planning_card_decoCalculator_subtitle =>
      'خطط للغوصات مع محطات تخفيف الضغط';

  @override
  String get planning_card_decoCalculator_title => 'حاسبة تخفيف الضغط';

  @override
  String get planning_card_divePlanner_description =>
      'خطط لغوصات معقدة مع مستويات عمق متعددة، وتبديل الغازات، وحسابات محطات تخفيف الضغط التلقائية.';

  @override
  String get planning_card_divePlanner_subtitle =>
      'إنشاء خطط غوص متعددة المستويات';

  @override
  String get planning_card_divePlanner_title => 'مخطط الغوص';

  @override
  String get planning_card_gasCalculators_description =>
      'أربع حاسبات غاز متخصصة:\n• MOD - أقصى عمق تشغيلي لخليط غاز\n• أفضل خليط - نسبة O₂ المثالية لعمق مستهدف\n• الاستهلاك - تقدير استخدام الغاز\n• الاحتياطي الأدنى - حساب احتياطي الطوارئ';

  @override
  String get planning_card_gasCalculators_subtitle =>
      'MOD، أفضل خليط، الاستهلاك، الاحتياطي الأدنى';

  @override
  String get planning_card_gasCalculators_title => 'حاسبات الغاز';

  @override
  String get planning_card_surfaceInterval_description =>
      'احسب الحد الأدنى للفاصل الزمني على السطح المطلوب بين الغوصات بناءً على تحميل الأنسجة. تصور كيف تتخلص أنسجتك الـ 16 من الغاز بمرور الوقت.';

  @override
  String get planning_card_surfaceInterval_subtitle =>
      'تخطيط فترات الغوص المتكرر';

  @override
  String get planning_card_surfaceInterval_title => 'الفاصل الزمني على السطح';

  @override
  String get planning_card_weightCalculator_description =>
      'قدّر الوزن الذي تحتاجه بناءً على بدلة الغوص، ومادة الأسطوانة، ونوع الماء، ووزن الجسم.';

  @override
  String get planning_card_weightCalculator_subtitle =>
      'الوزن الموصى به لإعدادك';

  @override
  String get planning_card_weightCalculator_title => 'حاسبة الأوزان';

  @override
  String get planning_info_disclaimer =>
      'هذه الأدوات لأغراض التخطيط فقط. تحقق دائمًا من الحسابات واتبع تدريبك على الغوص.';

  @override
  String get planning_newPlan => 'خطة جديدة';

  @override
  String get planning_section_tools => 'أدوات';

  @override
  String get planning_summary_prompt => 'اختر أداة للبدء';

  @override
  String get planning_summary_savedPlans => 'الخطط المحفوظة';

  @override
  String get planning_summary_noPlans => 'لا توجد خطط محفوظة بعد';

  @override
  String get planning_sidebar_appBar_title => 'التخطيط';

  @override
  String get planning_sidebar_decoCalculator_subtitle =>
      'NDL ومحطات تخفيف الضغط';

  @override
  String get planning_sidebar_decoCalculator_title => 'حاسبة تخفيف الضغط';

  @override
  String get planning_sidebar_divePlanner_subtitle =>
      'خطط غوص متعددة المستويات';

  @override
  String get planning_sidebar_divePlanner_title => 'مخطط الغوص';

  @override
  String get planning_sidebar_gasCalculators_subtitle =>
      'MOD، أفضل خليط، والمزيد';

  @override
  String get planning_sidebar_gasCalculators_title => 'حاسبات الغاز';

  @override
  String get planning_sidebar_info_disclaimer =>
      'أدوات التخطيط للاستخدام المرجعي فقط. تحقق دائمًا من الحسابات.';

  @override
  String get planning_sidebar_surfaceInterval_subtitle => 'تخطيط الغوص المتكرر';

  @override
  String get planning_sidebar_surfaceInterval_title =>
      'الفاصل الزمني على السطح';

  @override
  String get planning_sidebar_weightCalculator_subtitle => 'الوزن الموصى به';

  @override
  String get planning_sidebar_weightCalculator_title => 'حاسبة الأوزان';

  @override
  String get planning_welcome_quickTips_title => 'نصائح سريعة';

  @override
  String get planning_welcome_subtitle => 'اختر أداة من الشريط الجانبي للبدء';

  @override
  String get planning_welcome_tip_decoCalculator =>
      'حاسبة تخفيف الضغط لحدود NDL وأوقات التوقف';

  @override
  String get planning_welcome_tip_divePlanner =>
      'مخطط الغوص لتخطيط الغوص متعدد المستويات';

  @override
  String get planning_welcome_tip_gasCalculators =>
      'حاسبات الغاز لـ MOD وتخطيط الغاز';

  @override
  String get planning_welcome_tip_weightCalculator =>
      'حاسبة الأوزان لإعداد الطفو';

  @override
  String get planning_welcome_title => 'أدوات التخطيط';

  @override
  String get settings_about_aboutSubmersion => 'حول Submersion';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description =>
      'تتبع غوصاتك، وأدر معداتك، واستكشف مواقع الغوص.';

  @override
  String get settings_about_header => 'حول';

  @override
  String get settings_about_openSourceLicenses => 'تراخيص المصادر المفتوحة';

  @override
  String get settings_about_reportIssue => 'الإبلاغ عن مشكلة';

  @override
  String get settings_about_reportIssue_copy => 'نسخ الرابط';

  @override
  String get settings_about_reportIssue_snackbar =>
      'قم بزيارة github.com/submersion-app/submersion/issues';

  @override
  String settings_about_version(String version) {
    return 'الإصدار $version';
  }

  @override
  String get settings_appBar_title => 'الإعدادات';

  @override
  String get settings_appearance_appLanguage => 'لغة التطبيق';

  @override
  String get settings_appearance_displaySize => 'حجم العرض';

  @override
  String settings_appearance_displaySize_value(int percent) {
    return '$percent%';
  }

  @override
  String get settings_appearance_displaySize_reset => 'إعادة تعيين';

  @override
  String get settings_appearance_displaySize_smaller => 'أصغر';

  @override
  String get settings_appearance_displaySize_larger => 'أكبر';

  @override
  String get settings_appearance_depthColoredCards => 'بطاقات ملونة حسب العمق';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'عرض بطاقات الغوص بخلفيات ملونة بألوان المحيط حسب العمق';

  @override
  String get settings_appearance_cardColorAttribute => 'تلوين البطاقات حسب';

  @override
  String get settings_appearance_cardColorAttribute_subtitle =>
      'اختر السمة التي تحدد لون خلفية البطاقة';

  @override
  String get settings_appearance_cardColorAttribute_none => 'لا شيء';

  @override
  String get settings_appearance_cardColorAttribute_depth => 'العمق';

  @override
  String get settings_appearance_cardColorAttribute_duration => 'المدة';

  @override
  String get settings_appearance_cardColorAttribute_temperature =>
      'درجة الحرارة';

  @override
  String get settings_appearance_colorGradient => 'تدرج الألوان';

  @override
  String get settings_appearance_colorGradient_subtitle =>
      'اختر نطاق الألوان لخلفيات البطاقات';

  @override
  String get settings_appearance_colorGradient_ocean => 'محيط';

  @override
  String get settings_appearance_colorGradient_thermal => 'حراري';

  @override
  String get settings_appearance_colorGradient_sunset => 'غروب';

  @override
  String get settings_appearance_colorGradient_forest => 'غابة';

  @override
  String get settings_appearance_colorGradient_monochrome => 'أحادي اللون';

  @override
  String get settings_appearance_colorGradient_custom => 'مخصص';

  @override
  String get settings_appearance_gasSwitchMarkers => 'علامات تبديل الغاز';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'عرض علامات لتبديل الغازات';

  @override
  String get settings_appearance_gasTimeline => 'الجدول الزمني للغاز';

  @override
  String get settings_appearance_gasTimeline_subtitle =>
      'عرض شريط استهلاك الغاز أسفل ملف الغوصة بشكل افتراضي';

  @override
  String get settings_appearance_header_diveDetails => 'تفاصيل الغوصة';

  @override
  String get settings_appearance_header_diveLog => 'سجل الغوص';

  @override
  String get settings_appearance_header_diveProfile => 'ملف الغوصة';

  @override
  String get settings_appearance_header_diveSites => 'مواقع الغوص';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility =>
      'ترتيب الأقسام وظهورها';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility_subtitle =>
      'اختر الأقسام التي تظهر وترتيبها';

  @override
  String get settings_diveDetailSections_title => 'ترتيب الأقسام وظهورها';

  @override
  String get settings_diveDetailSections_resetToDefault =>
      'إعادة تعيين إلى الافتراضي';

  @override
  String get settings_diveDetailSections_fixedSections =>
      'الأقسام الثابتة: الرأس، مخطط ملف الغوصة';

  @override
  String get settings_diveDetailSections_configurableSections =>
      'الأقسام القابلة للتخصيص (اسحب لإعادة الترتيب)';

  @override
  String get diveDetailSection_decoO2_name =>
      'حالة تخفيف الضغط / تحميل الأنسجة';

  @override
  String get diveDetailSection_decoO2_description =>
      'NDL، السقف، خريطة حرارة الأنسجة، سمية O2';

  @override
  String get diveDetailSection_safetyReview_name => 'مراجعة السلامة';

  @override
  String get diveDetailSection_safetyReview_description =>
      'ملاحظات تلقائية على ملف الغوص بعد الغطسة';

  @override
  String get safetyReview_sectionTitle => 'مراجعة السلامة';

  @override
  String safetyReview_findingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملاحظات',
      one: 'ملاحظة واحدة',
    );
    return '$_temp0';
  }

  @override
  String safetyReview_rapidAscent_title(String rate, String duration) {
    return 'تجاوز الصعود $rate لمدة $duration';
  }

  @override
  String safetyReview_missedDecoStop_title(String excess, String duration) {
    return 'كان العمق أعلى من سقف التوقف المطلوب بمقدار $excess لمدة $duration';
  }

  @override
  String safetyReview_omittedSafetyStop_title(String remaining) {
    return 'تم تقصير توقف السلامة الموصى به بمقدار $remaining';
  }

  @override
  String safetyReview_sawtoothProfile_title(int count) {
    return '$count تغيرات متكررة في العمق صعودًا وهبوطًا أثناء الغطسة';
  }

  @override
  String safetyReview_highSurfaceGf_title(String gf, String gfHigh) {
    return 'الصعود إلى السطح بعامل تدرج $gf، أعلى من $gfHigh المُعد';
  }

  @override
  String safetyReview_timeRange(String start, String end) {
    return 'عند $start–$end';
  }

  @override
  String get safetyReview_dismiss => 'تجاهل';

  @override
  String get safetyReview_restore => 'استعادة';

  @override
  String get safetyReview_dismissAll => 'تجاهل الكل';

  @override
  String get safetyReview_restoreAll => 'استعادة الكل';

  @override
  String get safetySettings_dismissAll => 'تجاهل جميع الملاحظات';

  @override
  String get safetySettings_dismissAll_subtitle =>
      'وضع علامة مراجَعة على جميع الملاحظات في هذا السجل';

  @override
  String get safetySettings_dismissAll_confirmTitle => 'تجاهل جميع الملاحظات؟';

  @override
  String get safetySettings_dismissAll_confirmBody =>
      'ستوضع علامة مراجَعة على كل ملاحظة في كل غطسة تم تحليلها. يمكنك استعادتها غطسة بغطسة من قسم مراجعة السلامة الخاص بها.';

  @override
  String get safetySettings_dismissAll_confirm => 'تجاهل الكل';

  @override
  String get safetySettings_dismissAll_cancel => 'إلغاء';

  @override
  String safetySettings_dismissAll_progress(int done, int total) {
    return 'تم فحص $done من $total غطسة';
  }

  @override
  String safetySettings_dismissAll_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تجاهل $count ملاحظات',
      one: 'تم تجاهل ملاحظة واحدة',
      zero: 'لا توجد ملاحظات لتجاهلها',
    );
    return '$_temp0';
  }

  @override
  String safetySettings_dismissAll_doneWithErrors(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تجاهل $count ملاحظات',
      one: 'تم تجاهل ملاحظة واحدة',
      zero: 'لم يتم تجاهل أي ملاحظة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: 'تعذّر تحديث $failed غطسات',
      one: 'تعذّر تحديث غطسة واحدة',
    );
    return '$_temp0، $_temp1';
  }

  @override
  String get safetySettings_dismissAll_failed =>
      'تعذّرت قراءة قائمة الغطسات. لم يتم تغيير أي شيء.';

  @override
  String get safetySettings_analyzeAll_failed => 'تعذّر تحليل الغطسات.';

  @override
  String get safetyReview_details => 'التفاصيل';

  @override
  String get safetyReview_clearHighlight => 'مسح التمييز';

  @override
  String safetyReview_findingGroupSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملاحظات سلامة',
      one: 'ملاحظة سلامة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get safetySettings_title => 'مراجعة السلامة';

  @override
  String get safetySettings_entry_subtitle => 'ملاحظات وقواعد ما بعد الغطسة';

  @override
  String get safetySettings_masterToggle => 'مراجعة السلامة بعد الغطسة';

  @override
  String get safetySettings_masterToggle_subtitle =>
      'تدوين ملاحظات الصعود والتوقفات والملف تلقائيًا للغطسات المحللة';

  @override
  String get safetySettings_rulesHeader => 'القواعد';

  @override
  String get safetySettings_rule_rapidAscent => 'صعود سريع';

  @override
  String get safetySettings_rule_missedDecoStop =>
      'توقفات تخفيف الضغط الفائتة أو المختصرة';

  @override
  String get safetySettings_rule_omittedSafetyStop => 'توقفات السلامة المُغفلة';

  @override
  String get safetySettings_rule_sawtoothProfile => 'ملفات بنمط سن المنشار';

  @override
  String get safetySettings_rule_highSurfaceGf => 'عامل تدرج مرتفع عند الصعود';

  @override
  String get safetySettings_analyzeAll => 'تحليل جميع الغطسات';

  @override
  String get safetySettings_analyzeAll_subtitle =>
      'تشغيل مراجعة السلامة على كل غطسة ذات ملف لم تُحلل بعد';

  @override
  String safetySettings_analyzeAll_progress(int done, int total) {
    return 'تم تحليل $done من $total';
  }

  @override
  String get safetySettings_analyzeAll_done => 'اكتمل التحليل';

  @override
  String safetySettings_analyzeAll_doneWithErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذّر تحليل $count غوصات',
      one: 'تعذّر تحليل غوصة واحدة',
    );
    return 'اكتمل التحليل — $_temp0';
  }

  @override
  String safetyReview_showDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إظهار $count ملاحظات متجاهلة',
      one: 'إظهار ملاحظة متجاهلة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get diveDetailSection_sacSegments_name => 'معدل SAC حسب المقطع';

  @override
  String get diveDetailSection_sacSegments_description =>
      'تقسيم SAC حسب المراحل/الوقت';

  @override
  String get diveDetailSection_details_name => 'التفاصيل';

  @override
  String get diveDetailSection_details_description =>
      'النوع، الموقع، الرحلة، مركز الغوص، الفترة الفاصلة';

  @override
  String get diveDetailSection_environment_name => 'البيئة';

  @override
  String get diveDetailSection_environment_description =>
      'درجة حرارة الهواء/الماء، الرؤية، التيار';

  @override
  String get diveDetailSection_altitude_name => 'الارتفاع';

  @override
  String get diveDetailSection_altitude_description =>
      'قيمة الارتفاع، الفئة، متطلبات تخفيف الضغط';

  @override
  String get diveDetailSection_tide_name => 'المد والجزر';

  @override
  String get diveDetailSection_tide_description =>
      'رسم بياني لدورة المد والجزر والتوقيت';

  @override
  String get diveDetailSection_reefHealth_name => 'أحوال المياه';

  @override
  String get diveDetailSection_reefHealth_description =>
      'أحوال المياه عبر الأقمار الصناعية في تاريخ الغطسة';

  @override
  String get diveDetailSection_surfaceGps_name => 'GPS السطح';

  @override
  String get diveDetailSection_surfaceGps_description =>
      'نقاط الدخول/الخروج عبر GPS وانجراف السطح';

  @override
  String get diveLog_detail_section_surfaceGps => 'GPS السطح';

  @override
  String get diveLog_detail_surfaceGps_entry => 'الدخول';

  @override
  String get diveLog_detail_surfaceGps_exit => 'الخروج';

  @override
  String get diveLog_detail_label_drift => 'انجراف';

  @override
  String get diveLog_detail_surfaceGps_entryOnly => 'تم تسجيل نقطة الدخول';

  @override
  String get diveLog_detail_surfaceGps_exitOnly => 'تم تسجيل نقطة الخروج';

  @override
  String get diveLog_detail_surfaceGps_site => 'الموقع';

  @override
  String get diveLog_detail_surfaceGps_track => 'مسار السطح';

  @override
  String get diveLog_detail_surfaceGps_showFullTrack => 'المسار الكامل';

  @override
  String diveLog_detail_surfaceGps_trackFixes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقطة',
      few: '$count نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_detail_locationsMap_title => 'مواقع الغوص';

  @override
  String get diveLog_detail_coordinatesCopied =>
      'تم نسخ الإحداثيات إلى الحافظة';

  @override
  String get diveLog_detail_openInMaps => 'فتح في الخرائط';

  @override
  String get diveDetailSection_weights_name => 'الأوزان';

  @override
  String get diveDetailSection_weights_description =>
      'تفصيل الأوزان، إجمالي الوزن';

  @override
  String get diveDetailSection_buoyancy_name => 'الطفو';

  @override
  String get diveDetailSection_buoyancy_description =>
      'الطفو خلال الغطسة، التغيّر، والوزن القابل للإسقاط';

  @override
  String get buoyancy_tooltip =>
      'الطفو الصافي المُنمذَج خلال الغطسة من المخطط واستهلاك الغاز والمعدات.';

  @override
  String buoyancy_verdictBuoyant(String depth, String amount) {
    return 'عند محطتك الأخيرة (~$depth) كان لديك نحو $amount من الطفو';
  }

  @override
  String buoyancy_verdictHeavy(String depth, String amount) {
    return 'عند محطتك الأخيرة (~$depth) كنت أثقل بنحو $amount';
  }

  @override
  String get buoyancy_verdictNeutral =>
      'كانت تهيئتك قريبة من التعادل عند المحطة الأخيرة';

  @override
  String get buoyancy_verdictConvention =>
      'مُقدَّر وفق اصطلاح محطة الأمان عند 5 أمتار';

  @override
  String get buoyancy_breakdownTitle => 'تفصيل العناصر';

  @override
  String get buoyancy_suitTerm => 'البدلة';

  @override
  String get buoyancy_leadTerm => 'الرصاص';

  @override
  String get buoyancy_beginNet => 'بداية الغطسة';

  @override
  String get buoyancy_endNet => 'نهاية الغطسة';

  @override
  String get buoyancy_swing => 'تغيّر الطفو';

  @override
  String get buoyancy_peakLift => 'أقصى رفع مطلوب';

  @override
  String get buoyancy_wingWarning => 'يتجاوز قدرة الرفع الاسمية لجناحك';

  @override
  String get buoyancy_minDitchable => 'أدنى وزن قابل للإسقاط';

  @override
  String get buoyancy_droppable => 'يمكنك إسقاط';

  @override
  String get buoyancy_ditchWarning => 'أكثر مما يمكنك إسقاطه';

  @override
  String get buoyancy_drysuitGas => 'غاز البدلة الجافة المُضاف';

  @override
  String get buoyancy_estimatedPressures => 'ضغوط الأسطوانات تقديرية';

  @override
  String get buoyancy_linkSuitHint =>
      'اربط بدلة تعرّض بهذه الغطسة للحصول على صورة أوفى';

  @override
  String get buoyancy_noLeadHint =>
      'لم يتم تسجيل أي أثقال: أضف أثقالًا إلى هذه الغطسة أو وزنًا جافًا إلى معدات الأثقال';

  @override
  String get buoyancy_chartNet => 'الصافي';

  @override
  String get buoyancy_chartRig => 'المعدات + الرصاص';

  @override
  String get buoyancy_chartMinutes => 'الزمن (دقيقة)';

  @override
  String get buoyancy_historyTitle => 'سجل الترصيص';

  @override
  String get buoyancy_historyCarried => 'المحمول';

  @override
  String get buoyancy_historyModeled => 'المُنمذَج';

  @override
  String buoyancy_historyMore(String delta) {
    return 'عادةً ما تحمل $delta أكثر مما يقترحه النموذج';
  }

  @override
  String buoyancy_historyLess(String delta) {
    return 'عادةً ما تحمل $delta أقل مما يقترحه النموذج';
  }

  @override
  String get buoyancy_throughDive => 'خلال الغطسة';

  @override
  String get buoyancy_adjust => 'تعديل';

  @override
  String get buoyancy_whatIfTitle => 'تعديل هذه الغطسة';

  @override
  String get buoyancy_whatIfLead => 'الرصاص';

  @override
  String get buoyancy_whatIfSuit => 'طفو البدلة';

  @override
  String get buoyancy_whatIfReset => 'إعادة تعيين';

  @override
  String buoyancy_whatIfDelta(String delta) {
    return '$delta مقابل الفعلي';
  }

  @override
  String get diveDetailSection_tanks_name => 'الأسطوانات';

  @override
  String get diveDetailSection_tanks_description =>
      'قائمة الأسطوانات، خلطات الغاز، الضغوط، SAC لكل أسطوانة';

  @override
  String get diveDetailSection_buddies_name => 'الرفقاء';

  @override
  String get diveDetailSection_buddies_description =>
      'قائمة الرفقاء مع الأدوار';

  @override
  String get diveDetailSection_signatures_name => 'التوقيعات';

  @override
  String get diveDetailSection_signatures_description =>
      'عرض توقيعات الرفيق/المدرب والتقاطها';

  @override
  String get diveDetailSection_equipment_name => 'المعدات';

  @override
  String get diveDetailSection_equipment_description =>
      'المعدات المستخدمة في الغوصة';

  @override
  String get diveDetailSection_sightings_name => 'مشاهدات الحياة البحرية';

  @override
  String get diveDetailSection_sightings_description =>
      'الأنواع المرصودة، تفاصيل المشاهدات';

  @override
  String get diveDetailSection_media_name => 'الوسائط';

  @override
  String get diveDetailSection_media_description => 'معرض الصور/مقاطع الفيديو';

  @override
  String get diveDetailSection_tags_name => 'الوسوم';

  @override
  String get diveDetailSection_tags_description => 'وسوم الغوصة';

  @override
  String get diveDetailSection_notes_name => 'الملاحظات';

  @override
  String get diveDetailSection_notes_description => 'ملاحظات/وصف الغوصة';

  @override
  String get diveDetailSection_customFields_name => 'الحقول المخصصة';

  @override
  String get diveDetailSection_customFields_description =>
      'حقول مخصصة يحددها المستخدم';

  @override
  String get diveDetailSection_dataSources_name => 'مصادر البيانات';

  @override
  String get diveDetailSection_dataSources_description =>
      'أجهزة الغوص المتصلة، إدارة المصادر';

  @override
  String get settings_appearance_header_language => 'اللغة';

  @override
  String get settings_appearance_header_theme => 'المظهر';

  @override
  String get settings_appearance_header_mode => 'الوضع';

  @override
  String get settings_themes_title => 'اختيار المظهر';

  @override
  String get settings_themes_current => 'المظهر';

  @override
  String get theme_submersion => 'غمر';

  @override
  String get theme_console => 'وحدة التحكم';

  @override
  String get theme_tropical => 'استوائي';

  @override
  String get theme_minimalist => 'بسيط';

  @override
  String get theme_deep => 'الأعماق';

  @override
  String get settings_appearance_mapBackgroundDiveCards =>
      'خلفية خريطة على بطاقات الغوص';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitle =>
      'عرض خريطة موقع الغوص كخلفية على بطاقات الغوص';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote =>
      'عرض خريطة موقع الغوص كخلفية على بطاقات الغوص (يتطلب موقع الموقع)';

  @override
  String get settings_appearance_mapBackgroundSiteCards =>
      'خلفية خريطة على بطاقات المواقع';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitle =>
      'عرض الخريطة كخلفية على بطاقات مواقع الغوص';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote =>
      'عرض الخريطة كخلفية على بطاقات مواقع الغوص (يتطلب موقع الموقع)';

  @override
  String get settings_appearance_maxDepthMarker => 'علامة أقصى عمق';

  @override
  String get settings_appearance_maxDepthMarker_subtitle =>
      'عرض علامة عند نقطة أقصى عمق';

  @override
  String get settings_appearance_maxDepthMarker_subtitleFull =>
      'عرض علامة عند نقطة أقصى عمق على ملفات الغوص';

  @override
  String get settings_appearance_metric_ascentRateColors => 'ألوان معدل الصعود';

  @override
  String get settings_appearance_metric_ceiling => 'السقف';

  @override
  String get settings_appearance_metric_events => 'الأحداث';

  @override
  String get settings_appearance_metric_estimatedTankPressure =>
      'ضغط الأسطوانة المقدر';

  @override
  String get settings_appearance_metric_gasDensity => 'كثافة الغاز';

  @override
  String get settings_appearance_metric_gfPercent => 'GF%';

  @override
  String get settings_appearance_metric_heartRate => 'معدل ضربات القلب';

  @override
  String get settings_appearance_metric_meanDepth => 'متوسط العمق';

  @override
  String get settings_appearance_metric_ndl => 'NDL';

  @override
  String get settings_appearance_metric_ppHe => 'ppHe';

  @override
  String get settings_appearance_metric_ppN2 => 'ppN2';

  @override
  String get settings_appearance_metric_ppO2 => 'ppO2';

  @override
  String get settings_appearance_metric_pressure => 'الضغط';

  @override
  String get settings_appearance_metric_sacRate => 'معدل SAC';

  @override
  String get settings_appearance_metric_surfaceGf => 'GF السطح';

  @override
  String get settings_appearance_metric_temperature => 'درجة الحرارة';

  @override
  String get settings_appearance_metric_tts => 'TTS (الوقت إلى السطح)';

  @override
  String get settings_appearance_metric_cns => 'CNS% (سمية الأكسجين)';

  @override
  String get settings_appearance_metric_otu => 'OTU (وحدات تحمل الأكسجين)';

  @override
  String get settings_appearance_metric_photoMarkers => 'علامات الصور';

  @override
  String settings_appearance_metricsEnabledCount(int count, int total) {
    return '$count من $total مفعّل';
  }

  @override
  String get settings_appearance_pressureThresholdMarkers =>
      'علامات عتبة الضغط';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'عرض علامات عندما يتجاوز ضغط الأسطوانة العتبات';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'عرض علامات عندما يتجاوز ضغط الأسطوانة عتبات 2/3 و 1/2 و 1/3';

  @override
  String get settings_appearance_metricsFollowViewport =>
      'إبقاء الطبقات الإضافية ضمن العرض عند التكبير';

  @override
  String get settings_appearance_metricsFollowViewport_subtitle =>
      'ملاءمة الطبقات الإضافية مثل NDL وppO2 مع المنطقة المرئية بدلاً من تكبيرها مع محور العمق';

  @override
  String get settings_appearance_rightYAxisMetric => 'مقياس المحور الأيمن';

  @override
  String get settings_appearance_rightYAxisMetric_subtitle =>
      'المقياس الافتراضي المعروض على المحور الأيمن';

  @override
  String get settings_appearance_subsection_decompressionMetrics =>
      'مقاييس تخفيف الضغط';

  @override
  String get settings_appearance_subsection_defaultVisibleMetrics =>
      'المقاييس المرئية الافتراضية';

  @override
  String get settings_appearance_subsection_standardMetrics =>
      'Standard Metrics';

  @override
  String get settings_appearance_subsection_gasAnalysisMetrics =>
      'مقاييس تحليل الغاز';

  @override
  String get settings_appearance_subsection_gradientFactorMetrics =>
      'مقاييس عامل التدرج';

  @override
  String get settings_appearance_theme_dark => 'داكن';

  @override
  String get settings_appearance_theme_light => 'فاتح';

  @override
  String get settings_appearance_theme_system => 'الافتراضي للنظام';

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
  String get settings_backToSettings_tooltip => 'العودة إلى الإعدادات';

  @override
  String get settings_cloudSync_appBar_title =>
      'المزامنة السحابية لقاعدة البيانات';

  @override
  String get settings_cloudSync_autoSync => 'المزامنة التلقائية';

  @override
  String get settings_cloudSync_autoSync_subtitle =>
      'المزامنة تلقائيًا بعد التغييرات';

  @override
  String settings_cloudSync_conflictItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عناصر تحتاج اهتمامًا',
      one: 'عنصر واحد يحتاج اهتمامًا',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_disabledBanner_content =>
      'المزامنة السحابية المُدارة من التطبيق معطلة لأنك تستخدم مجلد تخزين مخصصًا. تتولى خدمة مزامنة المجلد (Dropbox، Google Drive، OneDrive، إلخ) عملية المزامنة.';

  @override
  String get settings_cloudSync_disabledBanner_title =>
      'المزامنة السحابية معطلة';

  @override
  String get settings_cloudSync_entry_subtitle =>
      'المزامنة عبر التخزين السحابي';

  @override
  String get settings_cloudSync_adopt_confirm => 'اعتماد المكتبة المستعادة';

  @override
  String settings_cloudSync_adopt_dialogContent(
    String deviceName,
    String date,
  ) {
    return 'تم استبدال المكتبة من نسخة احتياطية على \"$deviceName\" ($date). عند الاعتماد، سيتم استبدال بيانات هذا الجهاز بالمكتبة المستعادة. سيتم أولاً إنشاء نسخة احتياطية آمنة من البيانات الحالية لهذا الجهاز.';
  }

  @override
  String get settings_cloudSync_adopt_dialogTitle =>
      'اعتماد المكتبة المستعادة؟';

  @override
  String get settings_cloudSync_adopt_notNow => 'ليس الآن';

  @override
  String get settings_cloudSync_dangerZone => 'منطقة الخطر';

  @override
  String get settings_cloudSync_replaceLibrary_tile => 'استبدال مكتبة السحابة';

  @override
  String get settings_cloudSync_replaceLibrary_tileSubtitle =>
      'اجعل مكتبة هذا الجهاز هي المكتبة التي تستخدمها جميع الأجهزة';

  @override
  String get settings_cloudSync_replaceLibrary_dialogTitle =>
      'استبدال مكتبة السحابة؟';

  @override
  String get settings_cloudSync_replaceLibrary_dialogIntro =>
      'تصبح مكتبة هذا الجهاز هي المكتبة التي تستخدمها جميع الأجهزة.';

  @override
  String settings_cloudSync_replaceLibrary_dialogBody(num diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other:
          'تُمحى مكتبة السحابة ويحل محلها $diveCount غوصات الموجودة على هذا الجهاز.',
      one:
          'تُمحى مكتبة السحابة ويحل محلها الغوص الواحد الموجود على هذا الجهاز.',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_replaceLibrary_peers(num peerCount) {
    String _temp0 = intl.Intl.pluralLogic(
      peerCount,
      locale: localeName,
      other:
          'سيُطلب من $peerCount أجهزة أخرى اعتمادها؛ وحتى ذلك الحين لن تُدمج تغييراتها.',
      one:
          'سيُطلب من جهاز واحد آخر اعتمادها؛ وحتى ذلك الحين لن تُدمج تغييراته.',
      zero: 'لا يوجد جهاز آخر يتزامن بعد، لذا لا يوجد ما يمكن اعتماده.',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_replaceLibrary_peersUnknown =>
      'سيُطلب من كل الأجهزة الأخرى اعتمادها؛ وحتى ذلك الحين لن تُدمج تغييراتها.';

  @override
  String get settings_cloudSync_replaceLibrary_backupNote =>
      'تُنشأ نسخة احتياطية من هذا الجهاز أولاً. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get settings_cloudSync_replaceLibrary_confirmWord => 'استبدال';

  @override
  String get settings_cloudSync_replaceLibrary_confirmHint =>
      'اكتب \"استبدال\" للتأكيد';

  @override
  String get settings_cloudSync_replaceLibrary_confirm => 'استبدال';

  @override
  String get settings_cloudSync_firstSync_banner =>
      'المزامنة الأولى في انتظار التأكيد. اضغط على \'مزامنة الآن\' لمراجعة ما سيتم دمجه.';

  @override
  String get settings_cloudSync_firstSync_dialogConfirm => 'دمج ومزامنة';

  @override
  String get settings_cloudSync_firstSync_replaceHint =>
      'إذا كنت تريد بدلاً من ذلك أن تحل مكتبة هذا الجهاز محل ما في السحابة، فألغِ العملية واستخدم الإعدادات > مزامنة السحابة > استبدال مكتبة السحابة.';

  @override
  String settings_cloudSync_firstSync_dialogContent(
    int deviceCount,
    int diveCount,
  ) {
    return 'تم العثور على بيانات مزامنة موجودة في السحابة ($deviceCount من ملفات المزامنة). ستدمج المزامنة الأولى تلك البيانات مع $diveCount من الغطسات على هذا الجهاز، وذلك عبر جميع الأجهزة المتزامنة.\n\nإذا تمت إضافة الغطسات نفسها بشكل منفصل على كل جهاز، فستظهر مرتين.';
  }

  @override
  String get settings_cloudSync_firstSync_dialogTitle => 'دمج المكتبات؟';

  @override
  String settings_cloudSync_replace_banner(String deviceName) {
    return 'المزامنة متوقفة مؤقتًا: تم استبدال المكتبة من نسخة احتياطية على \"$deviceName\". اضغط على \"مزامنة الآن\" للمراجعة.';
  }

  @override
  String get settings_cloudSync_switch_dialogTitle => 'تبديل خدمة المزامنة؟';

  @override
  String settings_cloudSync_switch_dialogContent(
    String fromName,
    String toName,
  ) {
    return 'لن يتم نقل بياناتك من $fromName -- ستبقى هناك حتى تحذفها. بعد التبديل، ستدمج المزامنة التالية لهذا الجهاز بياناته مع ما هو موجود بالفعل على $toName. ستظل أجهزتك الأخرى تستخدم $fromName حتى تبدّل كلاً منها أيضًا.';
  }

  @override
  String get settings_cloudSync_switch_confirm => 'تبديل';

  @override
  String settings_cloudSync_moved_banner(
    String deviceName,
    String destination,
  ) {
    return 'قام $deviceName بنقل هذه المكتبة إلى $destination. لم تعد هذه الخدمة تُحدَّث بواسطته. اختر $destination أدناه لمتابعة النقل.';
  }

  @override
  String get settings_cloudSync_moved_dismiss => 'تجاهل';

  @override
  String settings_cloudSync_cleanup_banner(String backend) {
    return 'لا تزال بيانات المزامنة القديمة مخزّنة على $backend من قبل أن تبدّل الخدمات. لم تعد مستخدمة.';
  }

  @override
  String get settings_cloudSync_cleanup_delete => 'حذف البيانات القديمة';

  @override
  String get settings_cloudSync_cleanup_keep => 'الاحتفاظ';

  @override
  String get settings_cloudSync_header_advanced => 'متقدم';

  @override
  String get settings_cloudSync_signOut_backupWarning =>
      'سيتم إيقاف النسخ الاحتياطي السحابي وسيتم حفظ النسخ الاحتياطية في الموقع الافتراضي.';

  @override
  String get settings_cloudSync_header_cloudProvider => 'مزود السحابة';

  @override
  String settings_cloudSync_header_conflicts(Object count) {
    return 'التعارضات ($count)';
  }

  @override
  String get settings_cloudSync_header_syncBehavior => 'سلوك المزامنة';

  @override
  String settings_cloudSync_lastSynced(Object time) {
    return 'آخر مزامنة: $time';
  }

  @override
  String settings_cloudSync_pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغييرات معلقة',
      one: 'تغيير معلق واحد',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_banner(Object deviceList) {
    return '$deviceList لا يزال يستخدم إصدار مكتبة أقدم أو غير معروف، لذلك لم تُدمج تغييراته. افتح Submersion عليه لاعتماد المكتبة الحالية.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_bannerPlural(Object deviceList) {
    return '$deviceList لا تزال تستخدم إصدار مكتبة أقدم أو غير معروف، لذلك لم تُدمج تغييراتها. افتح Submersion عليها لاعتماد المكتبة الحالية.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_unnamedDevice(Object shortId) {
    return 'الجهاز $shortId';
  }

  @override
  String get settings_cloudSync_peerNeedsAdopt_listSeparator => '، ';

  @override
  String get settings_cloudSync_peerNeedsAdopt_listLastSeparator => ' و';

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamed(Object deviceList) {
    return '$deviceList يزامن من إصدار أحدث من Submersion، لذا يتم تعليق أحدث تغييراته مؤقتًا.';
  }

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(
    Object deviceList,
  ) {
    return '$deviceList تزامن من إصدار أحدث من Submersion، لذا يتم تعليق أحدث تغييراتها مؤقتًا.';
  }

  @override
  String get settings_cloudSync_peerRequiresUpdate_updateAction =>
      'حدّث هذا الجهاز لاستلامها.';

  @override
  String get settings_cloudSync_peerRequiresUpdate_storeAction =>
      'سيتم تطبيقها تلقائيًا فور وصول تحديث متجر التطبيقات لهذا الجهاز؛ وقد يكون التحديث لا يزال قيد المراجعة.';

  @override
  String get settings_cloudSync_provider_connected => 'متصل';

  @override
  String settings_cloudSync_provider_connectedTo(Object providerName) {
    return 'متصل بـ $providerName';
  }

  @override
  String settings_cloudSync_provider_connectionFailed(
    Object providerName,
    Object error,
  ) {
    return 'فشل الاتصال بـ $providerName: $error';
  }

  @override
  String get settings_cloudSync_dropbox_account_title => 'حساب Dropbox';

  @override
  String get settings_cloudSync_dropbox_connect_browserFailed =>
      'تعذر فتح المتصفح. جرب زر إعادة فتح المتصفح.';

  @override
  String get settings_cloudSync_dropbox_connect_codeLabel => 'رمز التفويض';

  @override
  String get settings_cloudSync_dropbox_connect_emptyCode =>
      'أدخل رمز التفويض الظاهر في متصفحك';

  @override
  String settings_cloudSync_dropbox_connect_failed(Object error) {
    return 'فشل الاتصال بـ Dropbox: $error';
  }

  @override
  String get settings_cloudSync_dropbox_connect_instructions =>
      'فتح متصفحك صفحة تفويض من Dropbox. وافق على الوصول، ثم الصق هنا الرمز الذي يعرضه Dropbox.';

  @override
  String get settings_cloudSync_dropbox_connect_reopenBrowser =>
      'إعادة فتح المتصفح';

  @override
  String get settings_cloudSync_dropbox_connect_submit => 'اتصال';

  @override
  String get settings_cloudSync_dropbox_connect_title => 'الاتصال بـ Dropbox';

  @override
  String get settings_cloudSync_dropbox_connected => 'متصل بـ Dropbox';

  @override
  String settings_cloudSync_dropbox_connectedAs(Object account) {
    return 'متصل كـ $account';
  }

  @override
  String get settings_cloudSync_dropbox_disconnect => 'قطع الاتصال';

  @override
  String get settings_cloudSync_provider_dropbox_subtitle =>
      'المزامنة عبر Dropbox (Apps/Submersion)';

  @override
  String get settings_cloudSync_provider_dropbox_title => 'Dropbox';

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'المزامنة عبر Google Drive';

  @override
  String get settings_cloudSync_googleDrive_desktopNotConfigured =>
      'غير متوفر في هذا الإصدار';

  @override
  String get settings_cloudSync_googleDrive_browserWait_title =>
      'تابع في متصفحك';

  @override
  String get settings_cloudSync_googleDrive_browserWait_message =>
      'أكمل تسجيل الدخول إلى Google في متصفح الويب الخاص بك، ثم عد إلى Submersion.';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'فشل في تهيئة مزود $providerName';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'غير متاح على هذه المنصة';

  @override
  String get settings_cloudSync_provider_s3_edit => 'تحرير إعدادات S3';

  @override
  String get settings_cloudSync_provider_s3_subtitle =>
      'يعمل مع أي خدمة تخزين متوافقة مع S3';

  @override
  String get settings_cloudSync_provider_s3_title => 'تخزين متوافق مع S3';

  @override
  String get settings_cloudSync_resetDialog_cancel => 'إلغاء';

  @override
  String get settings_cloudSync_resetDialog_content =>
      'سيؤدي هذا إلى مسح جميع سجلات المزامنة والبدء من جديد. لن يتم حذف بياناتك، لكن قد تحتاج إلى حل التعارضات في المزامنة التالية.';

  @override
  String get settings_cloudSync_resetDialog_reset => 'إعادة تعيين';

  @override
  String get settings_cloudSync_resetDialog_title =>
      'إعادة تعيين حالة المزامنة؟';

  @override
  String get settings_cloudSync_resetSuccess => 'تمت إعادة تعيين حالة المزامنة';

  @override
  String get settings_cloudSync_resetSyncState => 'إعادة تعيين حالة المزامنة';

  @override
  String get settings_cloudSync_resetSyncState_subtitle =>
      'مسح سجل المزامنة والبدء من جديد';

  @override
  String get settings_cloudSync_resolveConflicts => 'حل التعارضات';

  @override
  String get settings_cloudSync_selectProviderHint =>
      'اختر مزود سحابة لتمكين المزامنة';

  @override
  String get settings_cloudSync_signOut => 'تسجيل الخروج';

  @override
  String get settings_cloudSync_signOutDialog_cancel => 'إلغاء';

  @override
  String get settings_cloudSync_signOutDialog_content =>
      'سيؤدي هذا إلى قطع الاتصال بمزود السحابة. ستبقى بياناتك المحلية سليمة.';

  @override
  String get settings_cloudSync_signOutDialog_signOut => 'تسجيل الخروج';

  @override
  String get settings_cloudSync_signOutDialog_title => 'تسجيل الخروج؟';

  @override
  String get settings_cloudSync_signOutSuccess =>
      'تم تسجيل الخروج من مزود السحابة';

  @override
  String get settings_cloudSync_signOut_subtitle => 'قطع الاتصال بمزود السحابة';

  @override
  String get settings_cloudSync_status_conflictsDetected => 'تم اكتشاف تعارضات';

  @override
  String get settings_cloudSync_status_readyToSync => 'جاهز للمزامنة';

  @override
  String get settings_cloudSync_status_syncComplete => 'اكتملت المزامنة';

  @override
  String get settings_cloudSync_status_syncError => 'خطأ في المزامنة';

  @override
  String get settings_cloudSync_status_syncing => 'جارٍ المزامنة...';

  @override
  String get settings_cloudSync_storageSettings => 'إعدادات التخزين';

  @override
  String get settings_cloudSync_syncNow => 'مزامنة الآن';

  @override
  String get settings_cloudSync_syncOnLaunch => 'المزامنة عند التشغيل';

  @override
  String get settings_cloudSync_syncOnLaunch_subtitle =>
      'التحقق من التحديثات عند بدء التشغيل';

  @override
  String get settings_cloudSync_syncOnResume => 'المزامنة عند الاستئناف';

  @override
  String get settings_cloudSync_syncOnResume_subtitle =>
      'التحقق من التحديثات عندما يصبح التطبيق نشطًا';

  @override
  String settings_cloudSync_syncProgressPercent(Object percent) {
    return 'تقدم المزامنة: $percent بالمئة';
  }

  @override
  String settings_cloudSync_time_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count أيام',
      one: 'منذ يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_time_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count ساعات',
      one: 'منذ ساعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_time_justNow => 'الآن';

  @override
  String settings_cloudSync_time_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count دقائق',
      one: 'منذ دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_applyAll => 'تطبيق الكل';

  @override
  String get settings_conflict_cancel => 'إلغاء';

  @override
  String get settings_conflict_chooseResolution => 'اختر الحل';

  @override
  String get settings_conflict_close => 'إغلاق';

  @override
  String get settings_conflict_close_tooltip => 'إغلاق نافذة التعارضات';

  @override
  String settings_conflict_counterLabel(Object current, Object total) {
    return 'التعارض $current من $total';
  }

  @override
  String settings_conflict_errorLoading(Object error) {
    return 'خطأ في تحميل التعارضات: $error';
  }

  @override
  String get settings_conflict_keepBoth => 'الاحتفاظ بكليهما';

  @override
  String get settings_conflict_keepLocal => 'الاحتفاظ بالمحلي';

  @override
  String get settings_conflict_keepRemote => 'الاحتفاظ بالبعيد';

  @override
  String get settings_conflict_localVersion => 'النسخة المحلية';

  @override
  String settings_conflict_modified(Object time) {
    return 'تم التعديل: $time';
  }

  @override
  String get settings_conflict_next_tooltip => 'التعارض التالي';

  @override
  String get settings_conflict_noConflicts_message =>
      'تم حل جميع تعارضات المزامنة.';

  @override
  String get settings_conflict_noConflicts_title => 'لا توجد تعارضات';

  @override
  String get settings_conflict_noDataAvailable => 'لا توجد بيانات متاحة';

  @override
  String get settings_conflict_previous_tooltip => 'التعارض السابق';

  @override
  String get settings_conflict_ref_buddy => 'رفيق الغوص';

  @override
  String get settings_conflict_ref_certification => 'الشهادة';

  @override
  String get settings_conflict_ref_checklistTemplate => 'قالب قائمة التحقق';

  @override
  String get settings_conflict_ref_connectedAccount => 'الحساب المتصل';

  @override
  String get settings_conflict_ref_course => 'الدورة';

  @override
  String get settings_conflict_ref_courseRequirement => 'متطلب الدورة';

  @override
  String get settings_conflict_ref_cylinderConfig => 'إعداد الأسطوانات';

  @override
  String get settings_conflict_ref_dataSource => 'مصدر البيانات';

  @override
  String get settings_conflict_ref_dive => 'الغوصة';

  @override
  String get settings_conflict_ref_diveCenter => 'مركز الغوص';

  @override
  String get settings_conflict_ref_diveComputer => 'حاسوب الغوص';

  @override
  String get settings_conflict_ref_divePlan => 'خطة الغوص';

  @override
  String get settings_conflict_ref_diveSite => 'موقع الغوص';

  @override
  String get settings_conflict_ref_diveType => 'نوع الغوصة';

  @override
  String get settings_conflict_ref_diver => 'الغواص';

  @override
  String get settings_conflict_ref_equipment => 'المعدات';

  @override
  String get settings_conflict_ref_equipmentSet => 'طقم المعدات';

  @override
  String get settings_conflict_ref_finding => 'الملاحظة';

  @override
  String get settings_conflict_ref_instructor => 'المدرب';

  @override
  String get settings_conflict_ref_linkedDive => 'الغوصة المرتبطة';

  @override
  String get settings_conflict_ref_media => 'الوسائط';

  @override
  String get settings_conflict_ref_mediaSubscription => 'اشتراك الوسائط';

  @override
  String get settings_conflict_ref_missing => 'لم تعد موجودة في هذه المكتبة';

  @override
  String settings_conflict_ref_named(Object name, Object date) {
    return '$name ($date)';
  }

  @override
  String get settings_conflict_ref_plannedTank => 'الأسطوانة المخططة';

  @override
  String get settings_conflict_ref_preDiveChecklistTemplate =>
      'قالب قائمة التحقق قبل الغوص';

  @override
  String get settings_conflict_ref_preDiveSession => 'قائمة التحقق قبل الغوص';

  @override
  String get settings_conflict_ref_relatedDive => 'الغوصة ذات الصلة';

  @override
  String get settings_conflict_ref_serviceKind => 'نوع الصيانة';

  @override
  String get settings_conflict_ref_sighting => 'المشاهدة';

  @override
  String get settings_conflict_ref_signer => 'وقّع بواسطة';

  @override
  String get settings_conflict_ref_sourceDive => 'الغوصة المصدر';

  @override
  String get settings_conflict_ref_species => 'الأنواع';

  @override
  String get settings_conflict_ref_tag => 'الوسم';

  @override
  String get settings_conflict_ref_tank => 'الأسطوانة';

  @override
  String get settings_conflict_ref_trip => 'الرحلة';

  @override
  String get settings_conflict_remoteVersion => 'النسخة البعيدة';

  @override
  String settings_conflict_resolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تعارضات',
      one: 'تعارض واحد',
    );
    return 'تم حل $_temp0';
  }

  @override
  String get settings_conflict_title => 'حل التعارضات';

  @override
  String get settings_data_appDefaultLocation => 'موقع التطبيق الافتراضي';

  @override
  String get settings_data_backup => 'نسخ احتياطي واستعادة';

  @override
  String get settings_data_backup_subtitle => 'إنشاء نسخة احتياطية من بياناتك';

  @override
  String get settings_data_cloudSync => 'المزامنة السحابية لقاعدة البيانات';

  @override
  String get settings_data_customFolder => 'مجلد مخصص';

  @override
  String get settings_data_databaseStorage => 'تخزين قاعدة البيانات';

  @override
  String get settings_data_export_completed => 'اكتمل التصدير';

  @override
  String get settings_data_export_exporting => 'جارٍ التصدير...';

  @override
  String settings_data_export_failed(Object error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get settings_data_header_backupSync => 'النسخ الاحتياطي والمزامنة';

  @override
  String get settings_data_header_storage => 'التخزين';

  @override
  String get settings_data_import_completed => 'اكتملت العملية';

  @override
  String settings_data_import_failed(Object error) {
    return 'فشلت العملية: $error';
  }

  @override
  String get settings_data_offlineMaps => 'الخرائط غير المتصلة';

  @override
  String get settings_data_offlineMaps_subtitle =>
      'تنزيل الخرائط للاستخدام بدون اتصال';

  @override
  String get settings_data_restore => 'استعادة';

  @override
  String get settings_data_restoreDialog_cancel => 'إلغاء';

  @override
  String get settings_data_restoreDialog_content =>
      'تحذير: ستؤدي الاستعادة من نسخة احتياطية إلى استبدال جميع البيانات الحالية ببيانات النسخة الاحتياطية. لا يمكن التراجع عن هذا الإجراء.\n\nهل أنت متأكد أنك تريد المتابعة؟';

  @override
  String get settings_data_restoreDialog_restore => 'استعادة';

  @override
  String get settings_data_restoreDialog_title => 'استعادة النسخة الاحتياطية';

  @override
  String get settings_data_restore_subtitle => 'الاستعادة من نسخة احتياطية';

  @override
  String settings_data_syncTime_daysAgo(Object count) {
    return 'منذ $countي';
  }

  @override
  String settings_data_syncTime_hoursAgo(Object count) {
    return 'منذ $countس';
  }

  @override
  String get settings_data_syncTime_justNow => 'الآن';

  @override
  String settings_data_syncTime_minutesAgo(Object count) {
    return 'منذ $countد';
  }

  @override
  String settings_data_sync_lastSynced(Object time) {
    return 'آخر مزامنة: $time';
  }

  @override
  String get settings_data_sync_notConfigured => 'غير مُهيأ';

  @override
  String get settings_data_sync_syncing => 'جارٍ المزامنة...';

  @override
  String get settings_decompression_aboutContent =>
      'تتحكم عوامل التدرج (GF) في مدى تحفظ حسابات تخفيف الضغط. يؤثر GF المنخفض على محطات التوقف العميقة، بينما يؤثر GF المرتفع على محطات التوقف الضحلة.\n\nقيم أقل = أكثر تحفظًا = محطات تخفيف ضغط أطول\nقيم أعلى = أقل تحفظًا = محطات تخفيف ضغط أقصر';

  @override
  String get settings_decompression_aboutTitle => 'حول عوامل التدرج';

  @override
  String get settings_decompression_currentSettings => 'الإعدادات الحالية';

  @override
  String get settings_decompression_dialog_cancel => 'إلغاء';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      'قيم أقل = أكثر تحفظًا (NDL أطول / تخفيف ضغط أكثر)';

  @override
  String get settings_decompression_dialog_customValues => 'قيم مخصصة';

  @override
  String get settings_decompression_dialog_gfHigh => 'GF المرتفع';

  @override
  String get settings_decompression_dialog_gfLow => 'GF المنخفض';

  @override
  String get settings_decompression_dialog_info =>
      'يتحكم GF المنخفض/المرتفع في مدى تحفظ حسابات NDL وتخفيف الضغط.';

  @override
  String get settings_decompression_dialog_presets => 'إعدادات مسبقة';

  @override
  String get settings_decompression_dialog_save => 'حفظ';

  @override
  String get settings_decompression_dialog_title => 'عوامل التدرج';

  @override
  String settings_decompression_gfValue(Object gfLow, Object gfHigh) {
    return 'GF $gfLow/$gfHigh';
  }

  @override
  String get settings_decompression_header_gradientFactors => 'عوامل التدرج';

  @override
  String get settings_decompression_header_oxygenToxicity => 'سمية الأكسجين';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'اختيار إعداد التحفظ المسبق $presetName';
  }

  @override
  String get settings_decompression_header_narcosis => 'التخدير';

  @override
  String get settings_decompression_o2Narcotic => 'O2 مخدر';

  @override
  String get settings_decompression_o2Narcotic_subtitle =>
      'عند التفعيل، يُعتبر كل من O2 و N2 مخدرين (أكثر تحفظاً). عند التعطيل، يساهم N2 فقط في التخدير.';

  @override
  String get settings_decompression_endLimit => 'حد END';

  @override
  String get settings_decompression_endLimit_subtitle =>
      'أقصى عمق مخدر مكافئ مستخدم في حسابات MND';

  @override
  String get settings_decompression_endLimit_dialog_title => 'حد END';

  @override
  String get settings_decompression_cnsMethodTitle => 'حساب الـ CNS';

  @override
  String get settings_decompression_cnsMethodClassic =>
      'جدول NOAA، متدرّج (كلاسيكي)';

  @override
  String get settings_decompression_cnsMethodClassicDesc =>
      'يحسب كل نطاق 0.1 bar عند حدّه الأكثر صرامة. الطريقة الأصلية في Submersion.';

  @override
  String get settings_decompression_cnsMethodShearwater =>
      'استيفاء خطي (بأسلوب Shearwater)';

  @override
  String get settings_decompression_cnsMethodShearwaterDesc =>
      'يستوفي بين حدود NOAA كما توثّقها Shearwater. يتوافق مع معظم حواسيب الغوص.';

  @override
  String get settings_decompression_cnsMethodSubsurface =>
      'ملاءمة أسّية (مثل Subsurface)';

  @override
  String get settings_decompression_cnsMethodSubsurfaceDesc =>
      'ملاءمة منحنى سلس لجدول NOAA. يتوافق مع الـ CNS المحسوب في Subsurface.';

  @override
  String get settings_decompression_cnsMethodAboutTitle => 'حول هذه الطرق';

  @override
  String get settings_decompression_cnsMethodAboutBody =>
      'تستند الطرق الثلاث جميعها إلى حدود التعرض للأكسجين في دليل الغوص من NOAA (300 دقيقة عند ppO2 يبلغ 1.0 bar، و45 دقيقة عند 1.6 bar). لا يحدد الجدول الحدود إلا بخطوات مقدارها 0.1 bar: تحسب الطريقة الكلاسيكية كل ما يقع ضمن نطاق عند حدّه الأكثر صرامة، مما يبالغ بشكل منهجي في تقدير التعرض بين القيم. توثّق حواسيب الغوص من Shearwater استيفاءً خطيًا بين حدود NOAA، بمعدل ثابت قدره 15% في الدقيقة فوق 1.65 bar. استبدلت Subsurface في عام 2019 بحثها في الجدول بملاءمة أسّية سلسة من جزأين على البيانات نفسها من NOAA (Robert C. Helling)، وهي تمتد أيضًا بشكل طبيعي إلى ما بعد 1.6 bar. بين قيم الجدول، تتوافق الطريقتان السلستان في حدود نقطة CNS واحدة تقريبًا؛ بينما تعطي الطريقة الكلاسيكية قيمًا أعلى.';

  @override
  String get settings_decompression_cnsMethodDisclaimer =>
      'تشير الأسماء إلى الطرق المنشورة للمشاريع والمصنّعين المعنيين؛ ولا يتضمن ذلك أي انتماء أو تأييد. قد تختلف القيم المحسوبة عن القراءات الفعلية لحاسوب الغوص.';

  @override
  String get settings_decompression_cnsMethodSourcesTitle => 'المصادر';

  @override
  String get settings_linkOpenFailed => 'تعذر فتح الرابط.';

  @override
  String get settings_decompression_cnsMethodSourceNoaa =>
      'NOAA: Diving Program (ناشر دليل الغوص NOAA Diving Manual)';

  @override
  String get settings_decompression_cnsMethodSourceShearwater =>
      'Shearwater: ساعة أكسجين CNS';

  @override
  String get settings_decompression_cnsMethodSourceTheoreticalDiver =>
      'The Theoretical Diver: حساب سمّية أكسجين CNS';

  @override
  String get settings_decompression_cnsMethodSourceSubsurface =>
      'Subsurface: التنفيذ (divelist.cpp)';

  @override
  String get settings_existingDb_cancel => 'إلغاء';

  @override
  String get settings_existingDb_continue => 'متابعة';

  @override
  String get settings_existingDb_current => 'الحالية';

  @override
  String get settings_existingDb_dialog_message =>
      'توجد بالفعل قاعدة بيانات Submersion في هذا المجلد.';

  @override
  String get settings_existingDb_dialog_title =>
      'تم العثور على قاعدة بيانات موجودة';

  @override
  String get settings_existingDb_existing => 'الموجودة';

  @override
  String get settings_existingDb_replaceWarning =>
      'سيتم إنشاء نسخة احتياطية من قاعدة البيانات الموجودة قبل استبدالها.';

  @override
  String get settings_existingDb_replaceWithMyData => 'استبدال ببياناتي';

  @override
  String get settings_existingDb_replaceWithMyData_subtitle =>
      'الكتابة فوقها بقاعدة بياناتك الحالية';

  @override
  String get settings_existingDb_stat_buddies => 'الرفاق';

  @override
  String get settings_existingDb_stat_dives => 'الغوصات';

  @override
  String get settings_existingDb_stat_sites => 'المواقع';

  @override
  String get settings_existingDb_stat_trips => 'الرحلات';

  @override
  String get settings_existingDb_stat_users => 'المستخدمون';

  @override
  String get settings_existingDb_unknown => 'غير معروف';

  @override
  String get settings_existingDb_useExisting =>
      'استخدام قاعدة البيانات الموجودة';

  @override
  String get settings_existingDb_useExisting_subtitle =>
      'التبديل إلى قاعدة البيانات في هذا المجلد';

  @override
  String get settings_gfPreset_custom_description => 'تعيين القيم الخاصة بك';

  @override
  String get settings_gfPreset_custom_name => 'مخصص';

  @override
  String get settings_gfPreset_high_description =>
      'الأكثر تحفظًا، محطات تخفيف ضغط أطول';

  @override
  String get settings_gfPreset_high_name => 'مرتفع';

  @override
  String get settings_gfPreset_low_description =>
      'الأقل تحفظًا، تخفيف ضغط أقصر';

  @override
  String get settings_gfPreset_low_name => 'منخفض';

  @override
  String get settings_gfPreset_medium_description => 'نهج متوازن';

  @override
  String get settings_gfPreset_medium_name => 'متوسط';

  @override
  String get settings_import_cancelButton => 'إلغاء الاستيراد';

  @override
  String get settings_import_cancelling => 'جارٍ الإلغاء...';

  @override
  String get settings_import_dialog_title => 'جارٍ استيراد البيانات';

  @override
  String get settings_import_doNotClose => 'يرجى عدم إغلاق التطبيق';

  @override
  String settings_import_itemCount(Object current, Object total) {
    return '$current من $total';
  }

  @override
  String get settings_import_phase_buddies => 'جارٍ استيراد الرفاق...';

  @override
  String get settings_import_phase_certifications => 'جارٍ استيراد الشهادات...';

  @override
  String get settings_import_phase_complete => 'جارٍ الإنهاء...';

  @override
  String get settings_import_phase_diveCenters => 'جارٍ استيراد مراكز الغوص...';

  @override
  String get settings_import_phase_diveTypes => 'جارٍ استيراد أنواع الغوص...';

  @override
  String get settings_import_phase_dives => 'جارٍ استيراد الغوصات...';

  @override
  String get settings_import_phase_equipment => 'جارٍ استيراد المعدات...';

  @override
  String get settings_import_phase_equipmentSets =>
      'جارٍ استيراد مجموعات المعدات...';

  @override
  String get settings_import_phase_parsing => 'جارٍ تحليل الملف...';

  @override
  String get settings_import_phase_preparing => 'جارٍ التحضير...';

  @override
  String get settings_import_phase_sites => 'جارٍ استيراد مواقع الغوص...';

  @override
  String get settings_import_phase_tags => 'جارٍ استيراد العلامات...';

  @override
  String get settings_import_phase_trips => 'جارٍ استيراد الرحلات...';

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
    return '$phase، $current من $total';
  }

  @override
  String settings_import_progressPercent(Object percent) {
    return 'تقدم الاستيراد: $percent بالمئة';
  }

  @override
  String get settings_language_appBar_title => 'اللغة';

  @override
  String get settings_language_selected => 'محدد';

  @override
  String get settings_language_systemDefault => 'الافتراضي للنظام';

  @override
  String get settings_lightroom_albumFilter_all => 'الكتالوج بأكمله';

  @override
  String get settings_lightroom_albumFilter_title => 'الألبومات المراد فحصها';

  @override
  String get settings_lightroom_autoPoll_title =>
      'التحقق من الصور الجديدة تلقائيًا';

  @override
  String settings_lightroom_clientId_help(String redirectUri) {
    return 'أنشئ تكاملًا في Adobe Developer Console باستخدام واجهة Lightroom Services API ونوع اعتماد يدعم PKCE. أدخل عنوان إعادة التوجيه الخاص باعتمادك أدناه (تستخدم اعتمادات Native App مخططًا مخصصًا) أو اتركه فارغًا لاستخدام $redirectUri.';
  }

  @override
  String get settings_lightroom_clientId_label => 'معرّف عميل Adobe';

  @override
  String get settings_lightroom_clientSecret_label => 'سر العميل (اختياري)';

  @override
  String get settings_lightroom_redirectUri_label =>
      'عنوان إعادة التوجيه (اختياري)';

  @override
  String get settings_lightroom_connect => 'ربط Lightroom';

  @override
  String get settings_lightroom_connectEmbedded => 'الاتصال عبر Adobe';

  @override
  String get settings_lightroom_advancedByo =>
      'استخدم بيانات اعتماد Adobe الخاصة بك';

  @override
  String get settings_lightroom_connect_codeLabel =>
      'عنوان URL المُعاد توجيهه أو الرمز';

  @override
  String get settings_lightroom_connect_emptyCode =>
      'الصق عنوان URL المُعاد توجيهه أو رمز التفويض';

  @override
  String settings_lightroom_connect_failed(String error) {
    return 'تعذّر الاتصال بـ Lightroom: $error';
  }

  @override
  String get settings_lightroom_connect_instructions =>
      'سجّل الدخول إلى Adobe في نافذة المتصفح، ثم الصق العنوان الكامل للصفحة التي تصل إليها (فهو يحتوي على رمز التفويض).';

  @override
  String get settings_lightroom_connect_reopenBrowser => 'إعادة فتح المتصفح';

  @override
  String get settings_lightroom_connect_submit => 'ربط';

  @override
  String get settings_lightroom_connect_title => 'ربط Lightroom';

  @override
  String settings_lightroom_connected(String name) {
    return 'متصل باسم $name';
  }

  @override
  String get settings_lightroom_disconnect => 'قطع الاتصال';

  @override
  String get settings_lightroom_disconnect_confirmBody =>
      'تبقى الصور المرتبطة في غطساتك وتستمر في الظهور من مخزن الوسائط. لن تتم مطابقة الصور الجديدة بعد الآن.';

  @override
  String get settings_lightroom_disconnect_confirmTitle =>
      'قطع الاتصال بـ Lightroom؟';

  @override
  String settings_lightroom_lastPoll(String when) {
    return 'آخر فحص: $when';
  }

  @override
  String get settings_lightroom_needsReauth => 'يلزم إعادة الاتصال';

  @override
  String get settings_lightroom_scanNow => 'فحص Lightroom';

  @override
  String get settings_lightroom_scan_running => 'جارٍ فحص Lightroom...';

  @override
  String settings_lightroom_scan_summary(
    int attached,
    int suggested,
    int skipped,
  ) {
    return '$attached مرتبطة، $suggested مقترحة، $skipped مرتبطة بالفعل';
  }

  @override
  String get settings_lightroom_subtitle =>
      'ربط الصور ومقاطع الفيديو بالغطسات تلقائيًا';

  @override
  String get settings_lightroom_title => 'Adobe Lightroom';

  @override
  String get settings_manage_checklistTemplates => 'قوالب قوائم التحقق';

  @override
  String get settings_manage_checklistTemplates_subtitle =>
      'قوائم مهام قابلة لإعادة الاستخدام للتخطيط للرحلات';

  @override
  String get settings_manage_diveRoles => 'أدوار الغوص';

  @override
  String get settings_manage_diveRoles_subtitle => 'إدارة أدوار الغوص المخصصة';

  @override
  String get settings_manage_diveTypes => 'أنواع الغوص';

  @override
  String get settings_manage_diveTypes_subtitle => 'إدارة أنواع الغوص المخصصة';

  @override
  String get settings_manage_header_manageData => 'إدارة البيانات';

  @override
  String get settings_manage_species => 'الأنواع';

  @override
  String get settings_manage_species_subtitle =>
      'إدارة كتالوج أنواع الحياة البحرية';

  @override
  String get settings_manage_tags => 'الوسوم';

  @override
  String get settings_manage_tags_subtitle => 'إدارة ودمج وحذف الوسوم';

  @override
  String get settings_manage_tankPresets => 'إعدادات الأسطوانات المسبقة';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'إدارة تهيئات الأسطوانات المخصصة';

  @override
  String get settings_manage_serviceTypes => 'أنواع الصيانة';

  @override
  String get settings_manage_serviceTypes_subtitle =>
      'الصيانة التي تحتاجها معداتك، وعدد مراتها';

  @override
  String get settings_migrationProgress_doNotClose => 'يرجى عدم إغلاق التطبيق';

  @override
  String get settings_migration_backupInfo =>
      'سيتم إنشاء نسخة احتياطية قبل النقل. لن تُفقد بياناتك.';

  @override
  String get settings_migration_cancel => 'إلغاء';

  @override
  String get settings_migration_cloudSyncWarning =>
      'سيتم تعطيل المزامنة السحابية المُدارة من التطبيق. ستتولى خدمة مزامنة المجلد عملية المزامنة.';

  @override
  String get settings_migration_dialog_message => 'سيتم نقل قاعدة البيانات:';

  @override
  String get settings_migration_dialog_title => 'نقل قاعدة البيانات؟';

  @override
  String get settings_migration_from => 'من';

  @override
  String get settings_migration_moveDatabase => 'نقل قاعدة البيانات';

  @override
  String get settings_migration_to => 'إلى';

  @override
  String settings_notifications_days(Object count) {
    return '$count أيام';
  }

  @override
  String get settings_notifications_disabled_continueButton => 'متابعة';

  @override
  String get settings_notifications_disabled_openSettingsButton =>
      'فتح الإعدادات';

  @override
  String get settings_notifications_disabled_subtitleUnrequested =>
      'تحتاج تذكيرات الخدمة إلى إذن لإرسال الإشعارات';

  @override
  String get settings_notifications_disabled_subtitle =>
      'قم بتمكينها في إعدادات النظام لتلقي التذكيرات';

  @override
  String get settings_notifications_disabled_title => 'الإشعارات معطلة';

  @override
  String get settings_notifications_enableServiceReminders =>
      'تمكين تذكيرات الصيانة';

  @override
  String get settings_notifications_enableServiceReminders_subtitle =>
      'الحصول على إشعار عند استحقاق صيانة المعدات';

  @override
  String get settings_notifications_header_reminderSchedule => 'جدول التذكيرات';

  @override
  String get settings_notifications_header_serviceReminders =>
      'تذكيرات الصيانة';

  @override
  String get settings_notifications_howItWorks_content =>
      'تتم جدولة الإشعارات عند تشغيل التطبيق وتُحدّث دوريًا في الخلفية. يمكنك تخصيص التذكيرات لكل عنصر من المعدات في شاشة التعديل الخاصة به.';

  @override
  String get settings_notifications_howItWorks_title => 'كيف يعمل';

  @override
  String get settings_notifications_permissionRequired =>
      'يرجى تمكين الإشعارات في إعدادات النظام';

  @override
  String get settings_notifications_remindBeforeDue =>
      'ذكّرني قبل استحقاق الصيانة:';

  @override
  String get settings_notifications_reminderTime => 'وقت التذكير';

  @override
  String get settings_profile_activeDiver_subtitle =>
      'الغواص النشط - انقر للتبديل';

  @override
  String get settings_profile_addNewDiver => 'إضافة غواص جديد';

  @override
  String get settings_profile_error_loadingDiver => 'خطأ في تحميل الغواص';

  @override
  String get settings_profile_header_activeDiver => 'الغواص النشط';

  @override
  String get settings_profile_header_manageDivers => 'إدارة الغواصين';

  @override
  String get settings_profile_noDiverProfile => 'لا يوجد ملف غواص';

  @override
  String get settings_profile_noDiverProfile_subtitle =>
      'انقر لإنشاء ملفك الشخصي';

  @override
  String get settings_profile_switchDiver_title => 'تبديل الغواص';

  @override
  String settings_profile_switchedTo(Object diverName) {
    return 'تم التبديل إلى $diverName';
  }

  @override
  String get settings_profile_viewAllDivers => 'عرض جميع الغواصين';

  @override
  String get settings_profile_viewAllDivers_subtitle =>
      'إضافة أو تعديل ملفات الغواصين';

  @override
  String get settings_profileHub_addNewDiver => 'إضافة غواص جديد';

  @override
  String get settings_profileHub_cannotDeleteOnly =>
      'لا يمكن حذف ملف الغواص الوحيد';

  @override
  String get settings_profileHub_createDiverTitle => 'إنشاء غواص';

  @override
  String settings_profileHub_deleteConfirmContent(String name) {
    return 'هل أنت متأكد من حذف $name؟ سيتم إلغاء تعيين جميع سجلات الغوص المرتبطة.';
  }

  @override
  String get settings_profileHub_deleteConfirmTitle => 'حذف الغواص؟';

  @override
  String get settings_profileHub_deleteDiver => 'حذف الغواص';

  @override
  String get settings_profileHub_deleted => 'تم حذف الغواص';

  @override
  String get settings_profileHub_emergencyContacts =>
      'جهات الاتصال في حالات الطوارئ';

  @override
  String settings_profileHub_emergencyContacts_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جهات اتصال',
      one: 'جهة اتصال واحدة',
      zero: 'غير محدد',
    );
    return '$_temp0';
  }

  @override
  String get settings_profileHub_insurance => 'التأمين';

  @override
  String get settings_profileHub_insurance_expired => 'منتهي الصلاحية';

  @override
  String get settings_profileHub_insurance_notSet => 'غير محدد';

  @override
  String get settings_profileHub_medicalInfo => 'المعلومات الطبية';

  @override
  String get settings_profileHub_medicalInfo_notSet => 'غير محدد';

  @override
  String get settings_profileHub_notes => 'ملاحظات';

  @override
  String get settings_profileHub_notes_notSet => 'غير محدد';

  @override
  String get settings_profileHub_personalInfo => 'المعلومات الشخصية';

  @override
  String get settings_profileHub_personalInfo_notSet => 'غير محدد';

  @override
  String get settings_profileHub_saved => 'تم حفظ التغييرات';

  @override
  String get settings_profileHub_switchDiver => 'تبديل الغواص';

  @override
  String get settings_s3Config_action_remove => 'إزالة الإعدادات';

  @override
  String get settings_s3Config_action_testConnection => 'اختبار الاتصال';

  @override
  String get settings_s3Config_advanced_title => 'متقدم';

  @override
  String get settings_s3Config_appBar_title => 'تخزين متوافق مع S3';

  @override
  String get settings_s3Config_error_secureStorage =>
      'تعذر الوصول إلى التخزين الآمن';

  @override
  String get settings_s3Config_field_accessKeyId_label => 'Access Key ID';

  @override
  String get settings_s3Config_field_bucket_label => 'الحاوية (Bucket)';

  @override
  String get settings_s3Config_field_endpoint_helper =>
      'على سبيل المثال: https://s3.example.com';

  @override
  String get settings_s3Config_field_endpoint_label =>
      'عنوان URL لنقطة النهاية';

  @override
  String get settings_s3Config_field_pathStyle_label =>
      'استخدام العنونة بنمط المسار (path-style)';

  @override
  String get settings_s3Config_field_pathStyle_subtitle =>
      'مطلوب لمعظم الخوادم المستضافة ذاتيًا';

  @override
  String get settings_s3Config_field_prefix_label => 'بادئة المفاتيح';

  @override
  String settings_s3Config_field_region_helperAuto(String region) {
    return 'تم الاكتشاف تلقائيًا: $region';
  }

  @override
  String get settings_s3Config_field_region_label => 'المنطقة';

  @override
  String get settings_s3Config_field_secretAccessKey_label =>
      'Secret Access Key';

  @override
  String get settings_s3Config_remove_confirm_action => 'إزالة';

  @override
  String get settings_s3Config_remove_confirm_body =>
      'ستتوقف المزامنة عبر S3 على هذا الجهاز. لن تُحذف بياناتك في الحاوية.';

  @override
  String get settings_s3Config_remove_confirm_title =>
      'هل تريد إزالة إعدادات S3؟';

  @override
  String get settings_s3Config_removed => 'تمت إزالة إعدادات S3';

  @override
  String get settings_s3Config_saved => 'تم حفظ إعدادات S3';

  @override
  String settings_s3Config_test_regionDetected(String region) {
    return 'تم اكتشاف المنطقة: $region';
  }

  @override
  String get settings_s3Config_test_success => 'نجح الاتصال';

  @override
  String get settings_s3Config_validation_endpointInvalid =>
      'أدخل عنوان URL صالحًا يبدأ بـ http:// أو https://';

  @override
  String get settings_s3Config_validation_endpointPath =>
      'يجب ألا يتضمن عنوان URL لنقطة النهاية مسارًا';

  @override
  String get settings_s3Config_validation_required => 'مطلوب';

  @override
  String get settings_s3Config_warning_http =>
      'تستخدم نقطة النهاية هذه HTTP غير مشفّر. ستنتقل بيانات الاعتماد وبيانات الغوص دون تشفير؛ استخدمه فقط على شبكة موثوقة.';

  @override
  String get settings_section_about_subtitle => 'معلومات التطبيق والتراخيص';

  @override
  String get settings_section_about_title => 'حول';

  @override
  String get settings_section_appearance_subtitle => 'المظهر والعرض';

  @override
  String get settings_section_appearance_title => 'المظهر';

  @override
  String get settings_section_data_subtitle =>
      'النسخ الاحتياطي والاستعادة والتخزين';

  @override
  String get settings_section_data_title => 'البيانات';

  @override
  String get settings_section_decompression_subtitle => 'عوامل التدرج';

  @override
  String get settings_section_decompression_title => 'تخفيف الضغط';

  @override
  String get settings_section_diverProfile_subtitle =>
      'الغواص النشط والملفات الشخصية';

  @override
  String get settings_section_diverProfile_title => 'ملف الغواص';

  @override
  String get settings_section_manage_subtitle =>
      'أنواع الغوص وإعدادات الأسطوانات';

  @override
  String get settings_section_manage_title => 'الإدارة';

  @override
  String get settings_section_notifications_subtitle => 'تذكيرات الصيانة';

  @override
  String get settings_section_notifications_title => 'الإشعارات';

  @override
  String get settings_section_units_subtitle => 'تفضيلات القياس';

  @override
  String get settings_section_units_title => 'الوحدات';

  @override
  String get settings_storage_appBar_title => 'تخزين قاعدة البيانات';

  @override
  String get settings_storage_appDefault => 'الافتراضي للتطبيق';

  @override
  String get settings_storage_appDefaultLocation => 'موقع التطبيق الافتراضي';

  @override
  String get settings_storage_appDefault_subtitle =>
      'موقع تخزين التطبيق القياسي';

  @override
  String get settings_storage_currentLocation => 'الموقع الحالي';

  @override
  String get settings_storage_currentLocation_label => 'الموقع الحالي';

  @override
  String get settings_storage_customFolder => 'مجلد مخصص';

  @override
  String get settings_storage_customFolder_change => 'تغيير';

  @override
  String get settings_storage_customFolder_subtitle =>
      'اختر مجلدًا متزامنًا (Dropbox، Google Drive، إلخ)';

  @override
  String get settings_storage_customFolder_subtitleDeviceOnly =>
      'نقل قاعدة البيانات إلى التخزين الداخلي أو بطاقة SD';

  @override
  String get settings_storage_customFolder_deviceOnly_noCloudSync =>
      'المزامنة السحابية التي يديرها التطبيق معطَّلة ما دامت قاعدة البيانات موجودة على وحدة تخزين في الجهاز. لا يمكن لأي خدمة مزامنة الوصول إلى هذا المجلد على Android، لذا استخدم النسخ الاحتياطي والاستعادة للاحتفاظ بنسخ في مكان آخر.';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize • $diveCount غوصات • $siteCount مواقع';
  }

  @override
  String get settings_storage_dismissError_tooltip => 'تجاهل الخطأ';

  @override
  String get settings_storage_dismissSuccess_tooltip => 'تجاهل رسالة النجاح';

  @override
  String get settings_storage_header_storageLocation => 'موقع التخزين';

  @override
  String get settings_storage_info_customActive =>
      'المزامنة السحابية المُدارة من التطبيق معطلة. تتولى خدمة مزامنة المجلد (Dropbox، Google Drive، إلخ) عملية المزامنة.';

  @override
  String get settings_storage_info_customAvailable =>
      'استخدام مجلد مخصص يعطل المزامنة السحابية المُدارة من التطبيق. ستتولى خدمة مزامنة المجلد عملية المزامنة بدلًا من ذلك.';

  @override
  String get settings_storage_loading => 'جارٍ التحميل...';

  @override
  String get settings_storage_migrating_doNotClose => 'يرجى عدم إغلاق التطبيق';

  @override
  String get settings_storage_migrating_movingDatabase =>
      'جارٍ نقل قاعدة البيانات...';

  @override
  String get settings_storage_migrating_movingToAppDefault =>
      'جارٍ النقل إلى الموقع الافتراضي...';

  @override
  String get settings_storage_migrating_replacingExisting =>
      'جارٍ استبدال قاعدة البيانات الموجودة...';

  @override
  String get settings_storage_migrating_switchingToExisting =>
      'جارٍ التبديل إلى قاعدة البيانات الموجودة...';

  @override
  String get settings_storage_notSet => 'غير محدد';

  @override
  String settings_storage_success_backupAt(Object path) {
    return 'تم الاحتفاظ بالنسخة الأصلية كنسخة احتياطية في:\n$path';
  }

  @override
  String get settings_storage_success_moved => 'تم نقل قاعدة البيانات بنجاح';

  @override
  String get settings_storage_dangerZone => 'منطقة الخطر';

  @override
  String get settings_storage_resetDatabase => 'إعادة تعيين قاعدة البيانات';

  @override
  String get settings_storage_resetDatabase_subtitle =>
      'حذف جميع البيانات على هذا الجهاز والبدء من جديد';

  @override
  String get settings_storage_resetDialog_title =>
      'إعادة تعيين قاعدة البيانات؟';

  @override
  String get settings_storage_resetDialog_body =>
      'سيؤدي هذا إلى حذف جميع البيانات الموجودة على هذا الجهاز نهائياً، بما في ذلك الغوصات والمواقع والمعدات والإعدادات. سيتم إنشاء نسخة احتياطية تلقائياً قبل إعادة التعيين.\n\nلن تُحذف مكتبتك السحابية، وتحتفظ الأجهزة الأخرى ببياناتها. سيتم فصل مزامنة السحابة حتى لا يُلغى أثر إعادة التعيين؛ يمكنك إعادة توصيلها من الإعدادات > مزامنة السحابة.';

  @override
  String get settings_storage_resetDialog_confirmWord => 'حذف';

  @override
  String get settings_storage_resetDialog_confirmHint => 'اكتب \"حذف\" للتأكيد';

  @override
  String get settings_storage_resetDialog_confirmButton => 'إعادة تعيين';

  @override
  String get settings_storage_resetDialog_backupFailed =>
      'فشل النسخ الاحتياطي. تم إلغاء إعادة التعيين لحماية بياناتك.';

  @override
  String settings_storage_resetDialog_resetFailed(Object error) {
    return 'فشل إعادة التعيين: $error';
  }

  @override
  String get settings_storage_resetComplete_title =>
      'إعادة تعيين قاعدة البيانات';

  @override
  String get settings_storage_resetComplete_description =>
      'تم مسح بيانات هذا الجهاز وحفظ نسخة احتياطية. أصبحت مزامنة السحابة الآن غير متصلة حتى لا يُلغى أثر إعادة التعيين؛ يمكنك إعادة توصيلها من الإعدادات > مزامنة السحابة. اضغط على متابعة لإعادة تحميل التطبيق.';

  @override
  String get settings_summary_activeDiver => 'الغواص النشط';

  @override
  String get settings_summary_currentConfiguration => 'التهيئة الحالية';

  @override
  String get settings_summary_depth => 'العمق';

  @override
  String get settings_summary_error => 'خطأ';

  @override
  String get settings_summary_gradientFactors => 'عوامل التدرج';

  @override
  String get settings_summary_loading => 'جارٍ التحميل...';

  @override
  String get settings_summary_notSet => 'غير محدد';

  @override
  String get settings_summary_pressure => 'الضغط';

  @override
  String get settings_summary_subtitle => 'اختر فئة للتهيئة';

  @override
  String get settings_summary_temperature => 'درجة الحرارة';

  @override
  String get settings_summary_theme => 'المظهر';

  @override
  String get settings_summary_theme_dark => 'داكن';

  @override
  String get settings_summary_theme_light => 'فاتح';

  @override
  String get settings_summary_theme_system => 'النظام';

  @override
  String get settings_summary_tip =>
      'نصيحة: استخدم قسم البيانات لإجراء نسخ احتياطي لسجلات غوصك بانتظام.';

  @override
  String get settings_summary_title => 'الإعدادات';

  @override
  String get settings_summary_unitPreferences => 'تفضيلات الوحدات';

  @override
  String get settings_summary_units => 'الوحدات';

  @override
  String get settings_summary_volume => 'الحجم';

  @override
  String get settings_summary_weight => 'الوزن';

  @override
  String get settings_units_custom => 'مخصص';

  @override
  String get settings_units_dateFormat => 'تنسيق التاريخ';

  @override
  String get settings_units_depth => 'العمق';

  @override
  String get settings_units_depth_feet => 'أقدام (ft)';

  @override
  String get settings_units_depth_meters => 'أمتار (m)';

  @override
  String get settings_units_dialog_dateFormat => 'تنسيق التاريخ';

  @override
  String get settings_units_dialog_depthUnit => 'وحدة العمق';

  @override
  String get settings_units_dialog_pressureUnit => 'وحدة الضغط';

  @override
  String get settings_units_dialog_sacRateUnit => 'وحدة معدل SAC';

  @override
  String get settings_units_gasModel => 'حسابات الغاز';

  @override
  String get settings_units_gasModel_real => 'الغاز الحقيقي';

  @override
  String get settings_units_gasModel_real_subtitle =>
      'يأخذ الانضغاطية في الحسبان. أسطوانة سعة 12 لترًا عند 200 بار تحتوي نحو 2317 لترًا.';

  @override
  String get settings_units_gasModel_ideal => 'الغاز المثالي';

  @override
  String get settings_units_gasModel_ideal_subtitle =>
      'يطابق الحساب اليدوي وجداول الغوص. أسطوانة سعة 12 لترًا عند 200 بار تحتوي 2400 لتر.';

  @override
  String get settings_units_gasModel_explanation =>
      'كيفية تحويل ضغط الأسطوانة إلى حجم غاز. يؤثر ذلك على معدل استهلاك الهواء والإحصاءات ومخطط الغوص وحاسبات الغاز. الغاز المثالي يطابق الحساب الذي تُعلّمه هيئات التدريب، أما الغاز الحقيقي فدقيق فيزيائيًا ويعطي معدل استهلاك أقل بنحو 5%.';

  @override
  String get settings_units_dialog_gasModel => 'حسابات الغاز';

  @override
  String get settings_units_dialog_temperatureUnit => 'وحدة درجة الحرارة';

  @override
  String get settings_units_dialog_timeFormat => 'تنسيق الوقت';

  @override
  String get settings_units_dialog_volumeUnit => 'وحدة الحجم';

  @override
  String get settings_units_dialog_weightUnit => 'وحدة الوزن';

  @override
  String get settings_units_header_individualUnits => 'الوحدات الفردية';

  @override
  String get settings_units_header_timeDateFormat => 'تنسيق الوقت والتاريخ';

  @override
  String get settings_units_header_unitSystem => 'نظام الوحدات';

  @override
  String get settings_units_imperial => 'إمبريالي';

  @override
  String get settings_units_metric => 'متري';

  @override
  String get settings_units_pressure => 'الضغط';

  @override
  String get settings_units_pressure_bar => 'Bar';

  @override
  String get settings_units_pressure_psi => 'PSI';

  @override
  String get settings_units_quickSelect => 'اختيار سريع';

  @override
  String get settings_units_sacRate => 'معدل SAC';

  @override
  String get settings_units_defaultCurrency => 'العملة الافتراضية';

  @override
  String get settings_units_dialog_defaultCurrency => 'العملة الافتراضية';

  @override
  String get settings_units_sac_pressurePerMinute => 'الضغط في الدقيقة';

  @override
  String get settings_units_sac_pressurePerMinute_subtitle =>
      'لا يتطلب حجم الأسطوانة (bar/min أو psi/min)';

  @override
  String get settings_units_sac_volumePerMinute => 'الحجم في الدقيقة';

  @override
  String get settings_units_sac_volumePerMinute_subtitle =>
      'يتطلب حجم الأسطوانة (L/min أو cuft/min)';

  @override
  String get settings_units_temperature => 'درجة الحرارة';

  @override
  String get settings_units_temperature_celsius => 'مئوية (°C)';

  @override
  String get settings_units_temperature_fahrenheit => 'فهرنهايت (°F)';

  @override
  String get settings_units_timeFormat => 'تنسيق الوقت';

  @override
  String get settings_units_volume => 'الحجم';

  @override
  String get settings_units_volume_cubicFeet => 'أقدام مكعبة (cuft)';

  @override
  String get settings_units_volume_liters => 'لترات (L)';

  @override
  String get settings_units_weight => 'الوزن';

  @override
  String get settings_units_weight_kilograms => 'كيلوغرام (kg)';

  @override
  String get settings_units_weight_pounds => 'أرطال (lbs)';

  @override
  String get settings_updates_automaticUpdates => 'التحديثات التلقائية';

  @override
  String get settings_updates_automaticUpdatesSubtitle =>
      'التحقق من التحديثات بشكل دوري';

  @override
  String get settings_updates_betaDialogBody =>
      'تُنشر إصدارات البيتا مع كل تغيير وقد تقوم بترقية قاعدة بيانات سجل الغوص قبل الإصدار المستقر. العودة لاحقًا إلى القناة المستقرة لن تعيد التطبيق إلى إصدار أقدم، وينبغي أن تستخدم جميع الأجهزة التي تتزامن معًا القناة نفسها. يتم إنشاء نسخة احتياطية تلقائيًا قبل أي ترقية لقاعدة البيانات.';

  @override
  String get settings_updates_betaDialogConfirm => 'التبديل إلى البيتا';

  @override
  String get settings_updates_betaDialogTitle => 'هل تريد تلقي تحديثات البيتا؟';

  @override
  String get settings_updates_channel => 'قناة التحديث';

  @override
  String settings_updates_channelBadgeBeta(String version) {
    return '$version (بيتا)';
  }

  @override
  String get settings_updates_channelBeta => 'بيتا';

  @override
  String get settings_updates_channelBetaSubtitle =>
      'إصدارات جديدة مع كل تغيير، قبل الإصدار المستقر';

  @override
  String get settings_updates_channelStable => 'مستقر';

  @override
  String get settings_updates_channelStableSubtitle => 'الإصدارات المختبرة فقط';

  @override
  String get settings_updates_checkForUpdates => 'التحقق من التحديثات';

  @override
  String get settings_updates_checking => 'جارٍ التحقق...';

  @override
  String settings_updates_downloading(String progress) {
    return 'جارٍ التنزيل... $progress%';
  }

  @override
  String settings_updates_error(String message) {
    return 'خطأ: $message';
  }

  @override
  String get settings_updates_header => 'التحديثات';

  @override
  String get settings_updates_joinBeta => 'الانضمام إلى البيتا';

  @override
  String get settings_updates_joinBetaSubtitle =>
      'احصل على الميزات الجديدة مبكرًا من خلال برنامج البيتا';

  @override
  String get settings_updates_lastChecked => 'آخر تحقق';

  @override
  String get settings_updates_never => 'أبدًا';

  @override
  String settings_updates_readyToInstall(String version) {
    return 'الإصدار $version جاهز للتثبيت';
  }

  @override
  String get settings_updates_stableSwitchNotice =>
      'ستبقى على إصدار البيتا هذا حتى يصبح الإصدار المستقر التالي أحدث منه.';

  @override
  String get settings_updates_upToDate => 'محدّث';

  @override
  String settings_updates_versionAvailable(String version) {
    return 'الإصدار $version متاح';
  }

  @override
  String get signatures_action_clear => 'مسح';

  @override
  String get signatures_action_closeSignatureView => 'إغلاق عرض التوقيع';

  @override
  String get signatures_action_deleteSignature => 'حذف التوقيع';

  @override
  String get signatures_action_done => 'تم';

  @override
  String get signatures_action_readyToSign => 'جاهز للتوقيع';

  @override
  String get signatures_action_request => 'طلب';

  @override
  String get signatures_action_saveSignature => 'حفظ التوقيع';

  @override
  String signatures_buddyCard_notSignedSemantics(Object name) {
    return 'توقيع $name، غير موقع';
  }

  @override
  String signatures_buddyCard_signedSemantics(Object name) {
    return 'توقيع $name، موقع';
  }

  @override
  String get signatures_captureInstructorSignature => 'التقاط توقيع المدرب';

  @override
  String signatures_deleteDialog_message(Object name) {
    return 'هل أنت متأكد من حذف توقيع $name؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get signatures_deleteDialog_title => 'حذف التوقيع؟';

  @override
  String get signatures_drawSignatureHint => 'ارسم توقيعك أعلاه';

  @override
  String get signatures_drawSignatureHintDetailed =>
      'ارسم التوقيع أعلاه باستخدام الإصبع أو القلم';

  @override
  String get signatures_drawSignatureSemantics => 'رسم التوقيع';

  @override
  String get signatures_error_drawSignature => 'الرجاء رسم توقيع';

  @override
  String get signatures_error_enterSignerName => 'الرجاء إدخال اسم الموقع';

  @override
  String get signatures_field_instructorName => 'اسم المدرب';

  @override
  String get signatures_field_instructorNameHint => 'أدخل اسم المدرب';

  @override
  String get signatures_handoff_title => 'ناول جهازك إلى';

  @override
  String get signatures_instructorSignature => 'توقيع المدرب';

  @override
  String get signatures_noSignatureImage => 'لا توجد صورة توقيع';

  @override
  String signatures_signHere(Object name) {
    return '$name - وقع هنا';
  }

  @override
  String get signatures_signed => 'موقع';

  @override
  String signatures_signedCountSemantics(Object signed, Object total) {
    return '$signed من $total رفاق وقعوا';
  }

  @override
  String signatures_signedDate(Object date) {
    return 'وقع في $date';
  }

  @override
  String get signatures_title => 'التوقيعات';

  @override
  String get signatures_viewSignature => 'عرض التوقيع';

  @override
  String signatures_viewSignatureSemantics(Object name) {
    return 'عرض توقيع $name';
  }

  @override
  String get statistics_appBar_title => 'الإحصائيات';

  @override
  String statistics_categoryCard_semanticLabel(Object title) {
    return 'فئة إحصائيات $title';
  }

  @override
  String get statistics_category_conditions_subtitle => 'الرؤية ودرجة الحرارة';

  @override
  String get statistics_category_conditions_title => 'الظروف';

  @override
  String get statistics_category_equipment_subtitle =>
      'استخدام المعدات والأوزان';

  @override
  String get statistics_category_equipment_title => 'المعدات';

  @override
  String get statistics_category_gas_subtitle => 'معدلات SAC وخلطات الغاز';

  @override
  String get statistics_category_gas_title => 'استهلاك الهواء';

  @override
  String get statistics_category_geographic_subtitle => 'الدول والمناطق';

  @override
  String get statistics_category_geographic_title => 'جغرافي';

  @override
  String get statistics_category_marineLife_subtitle => 'رصد الأنواع';

  @override
  String get statistics_category_marineLife_title => 'الحياة البحرية';

  @override
  String get statistics_category_overview_title => 'Overview';

  @override
  String get statistics_category_overview_subtitle =>
      'Totals, records, and breakdowns at a glance';

  @override
  String get statistics_category_profile_subtitle =>
      'معدلات الصعود وتخفيف الضغط';

  @override
  String get statistics_category_profile_title => 'تحليل الملف الشخصي';

  @override
  String get statistics_category_progression_subtitle => 'اتجاهات العمق والوقت';

  @override
  String get statistics_category_progression_title => 'التقدم';

  @override
  String get statistics_category_social_subtitle => 'الرفاق ومراكز الغوص';

  @override
  String get statistics_category_social_title => 'اجتماعي';

  @override
  String get statistics_category_timePatterns_subtitle => 'متى تغوص';

  @override
  String get statistics_category_timePatterns_title => 'أنماط الوقت';

  @override
  String statistics_chart_barSemanticLabel(Object count) {
    return 'مخطط أعمدة بـ $count فئات';
  }

  @override
  String statistics_chart_distributionSemanticLabel(Object count) {
    return 'مخطط دائري للتوزيع بـ $count شرائح';
  }

  @override
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames) {
    return 'مخطط خطوط متعددة الاتجاهات يقارن $seriesNames';
  }

  @override
  String get statistics_chart_noBarData => 'لا توجد بيانات متاحة';

  @override
  String get statistics_chart_noDistributionData =>
      'لا توجد بيانات توزيع متاحة';

  @override
  String get statistics_chart_noTrendData => 'لا توجد بيانات اتجاه متاحة';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return 'مخطط خطي للاتجاه يعرض $count نقاط بيانات';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return 'مخطط خطي للاتجاه يعرض $count نقاط بيانات لـ $yAxisLabel';
  }

  @override
  String get statistics_conditions_appBar_title => 'الظروف';

  @override
  String get statistics_conditions_entryMethod_empty =>
      'لا توجد بيانات طريقة الدخول متاحة';

  @override
  String get statistics_conditions_entryMethod_error =>
      'فشل تحميل بيانات طريقة الدخول';

  @override
  String get statistics_conditions_entryMethod_subtitle =>
      'من الشاطئ، قارب، إلخ.';

  @override
  String get statistics_conditions_entryMethod_title => 'طريقة الدخول';

  @override
  String get statistics_conditions_temperature_empty =>
      'لا توجد بيانات حرارة متاحة';

  @override
  String get statistics_conditions_temperature_error =>
      'فشل تحميل بيانات الحرارة';

  @override
  String get statistics_conditions_temperature_seriesAvg => 'المتوسط';

  @override
  String get statistics_conditions_temperature_seriesMax => 'الأقصى';

  @override
  String get statistics_conditions_temperature_seriesMin => 'الأدنى';

  @override
  String get statistics_conditions_temperature_subtitle =>
      'أدنى/متوسط/أقصى درجات الحرارة';

  @override
  String get statistics_conditions_temperature_title => 'حرارة الماء حسب الشهر';

  @override
  String get statistics_conditions_visibility_error =>
      'فشل تحميل بيانات الرؤية';

  @override
  String get statistics_conditions_visibility_subtitle =>
      'الغوصات حسب حالة الرؤية';

  @override
  String get statistics_conditions_visibility_title => 'توزيع الرؤية';

  @override
  String get statistics_conditions_waterType_error =>
      'فشل تحميل بيانات نوع الماء';

  @override
  String get statistics_conditions_waterType_subtitle =>
      'غوصات المياه المالحة مقابل العذبة';

  @override
  String get statistics_conditions_waterType_title => 'نوع الماء';

  @override
  String get statistics_equipment_appBar_title => 'المعدات';

  @override
  String get statistics_equipment_mostUsedGear_error =>
      'فشل تحميل بيانات المعدات';

  @override
  String get statistics_equipment_mostUsedGear_subtitle =>
      'المعدات حسب عدد الغوصات';

  @override
  String get statistics_equipment_mostUsedGear_title =>
      'المعدات الأكثر استخداماً';

  @override
  String get statistics_equipment_weightTrend_error =>
      'فشل تحميل اتجاه الأوزان';

  @override
  String get statistics_equipment_weightTrend_subtitle =>
      'متوسط الوزن عبر الزمن';

  @override
  String get statistics_equipment_weightTrend_title => 'اتجاه الأوزان';

  @override
  String get statistics_error_loadingStatistics => 'خطأ في تحميل الإحصائيات';

  @override
  String get statistics_filterBar_clear => 'مسح التصفية';

  @override
  String statistics_filterBar_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غوصات',
      one: 'غوصة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get statistics_gas_appBar_title => 'استهلاك الهواء';

  @override
  String get statistics_gas_gasMix_error => 'فشل تحميل بيانات خليط الغاز';

  @override
  String get statistics_gas_gasMix_subtitle => 'الغوصات حسب نوع الغاز';

  @override
  String get statistics_gas_gasMix_title => 'توزيع خليط الغاز';

  @override
  String get statistics_gas_sacByRole_empty =>
      'لا توجد بيانات أسطوانات متعددة متاحة';

  @override
  String get statistics_gas_sacByRole_error => 'فشل تحميل SAC حسب الدور';

  @override
  String get statistics_gas_sacByRole_subtitle =>
      'متوسط الاستهلاك حسب نوع الأسطوانة';

  @override
  String get statistics_gas_sacByRole_title => 'SAC حسب دور الأسطوانة';

  @override
  String get statistics_gas_sacRecords_best => 'أفضل معدل SAC';

  @override
  String get statistics_gas_sacRecords_empty => 'لا توجد بيانات SAC متاحة بعد';

  @override
  String get statistics_gas_sacRecords_error => 'فشل تحميل سجلات SAC';

  @override
  String get statistics_gas_sacRecords_highest => 'أعلى معدل SAC';

  @override
  String get statistics_gas_sacRecords_subtitle => 'أفضل وأسوأ استهلاك للهواء';

  @override
  String get statistics_gas_sacRecords_title => 'سجلات معدل SAC';

  @override
  String get statistics_gas_sacTrend_error => 'فشل تحميل اتجاه SAC';

  @override
  String get statistics_gas_sacTrend_subtitle =>
      'المتوسط الشهري على مدى 5 سنوات';

  @override
  String get statistics_gas_sacTrend_title => 'اتجاه معدل SAC';

  @override
  String get statistics_gas_tankRole_backGas => 'غاز رئيسي';

  @override
  String get statistics_gas_tankRole_bailout => 'غاز الطوارئ';

  @override
  String get statistics_gas_tankRole_deco => 'تخفيف الضغط';

  @override
  String get statistics_gas_tankRole_diluent => 'مخفف';

  @override
  String get statistics_gas_tankRole_oxygenSupply => 'إمداد O₂';

  @override
  String get statistics_gas_tankRole_pony => 'أسطوانة احتياطية';

  @override
  String get statistics_gas_tankRole_sidemountLeft => 'جانبي أيسر';

  @override
  String get statistics_gas_tankRole_sidemountRight => 'جانبي أيمن';

  @override
  String get statistics_gas_tankRole_stage => 'أسطوانة مرحلية';

  @override
  String get statistics_geographic_appBar_title => 'جغرافي';

  @override
  String get statistics_geographic_countries_empty => 'لم تتم زيارة أي دول';

  @override
  String get statistics_geographic_countries_error => 'فشل تحميل بيانات الدول';

  @override
  String get statistics_geographic_countries_subtitle => 'الغوصات حسب الدولة';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count دول. الأكثر: $topName بـ $topCount غوصات';
  }

  @override
  String get statistics_geographic_countries_title => 'الدول التي تمت زيارتها';

  @override
  String get statistics_geographic_regions_empty => 'لم يتم استكشاف أي مناطق';

  @override
  String get statistics_geographic_regions_error => 'فشل تحميل بيانات المناطق';

  @override
  String get statistics_geographic_regions_subtitle => 'الغوصات حسب المنطقة';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count مناطق. الأكثر: $topName بـ $topCount غوصات';
  }

  @override
  String get statistics_geographic_regions_title => 'المناطق المستكشفة';

  @override
  String get statistics_geographic_trips_empty => 'لا توجد بيانات رحلات';

  @override
  String get statistics_geographic_trips_error => 'فشل تحميل بيانات الرحلات';

  @override
  String get statistics_geographic_trips_subtitle => 'الرحلات الأكثر إنتاجية';

  @override
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count رحلات. الأكثر: $topName بـ $topCount غوصات';
  }

  @override
  String get statistics_geographic_trips_title => 'الغوصات لكل رحلة';

  @override
  String get statistics_listContent_selectedSuffix => '، محدد';

  @override
  String get statistics_marineLife_appBar_title => 'الحياة البحرية';

  @override
  String get statistics_marineLife_bestSites_empty => 'لا توجد بيانات مواقع';

  @override
  String get statistics_marineLife_bestSites_error =>
      'فشل تحميل بيانات المواقع';

  @override
  String get statistics_marineLife_bestSites_subtitle =>
      'المواقع ذات أكبر تنوع في الأنواع';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count مواقع. الأفضل: $topName بـ $topCount أنواع';
  }

  @override
  String get statistics_marineLife_bestSites_title =>
      'أفضل المواقع للحياة البحرية';

  @override
  String get statistics_marineLife_mostCommon_empty => 'لا توجد بيانات رصد';

  @override
  String get statistics_marineLife_mostCommon_error => 'فشل تحميل بيانات الرصد';

  @override
  String get statistics_marineLife_mostCommon_subtitle =>
      'الأنواع الأكثر مشاهدة';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count أنواع. الأكثر شيوعاً: $topName بـ $topCount مشاهدات';
  }

  @override
  String get statistics_marineLife_mostCommon_title => 'أكثر المشاهدات شيوعاً';

  @override
  String get statistics_marineLife_speciesSpotted => 'الأنواع المرصودة';

  @override
  String get statistics_profile_appBar_title => 'تحليل الملف الشخصي';

  @override
  String get statistics_profile_ascentDescent_empty =>
      'لا توجد بيانات ملف شخصي متاحة';

  @override
  String get statistics_profile_ascentDescent_error =>
      'فشل تحميل بيانات المعدلات';

  @override
  String get statistics_profile_ascentDescent_subtitle => 'من بيانات ملف الغوص';

  @override
  String get statistics_profile_ascentDescent_title =>
      'متوسط معدلات الصعود والنزول';

  @override
  String get statistics_profile_avgAscent => 'متوسط الصعود';

  @override
  String get statistics_profile_avgDescent => 'متوسط النزول';

  @override
  String get statistics_profile_deco_decoDives => 'غوصات تخفيف الضغط';

  @override
  String get statistics_profile_deco_decoLabel => 'تخفيف الضغط';

  @override
  String get statistics_profile_deco_decoRate => 'معدل تخفيف الضغط';

  @override
  String get statistics_profile_deco_empty => 'لا توجد بيانات تخفيف ضغط متاحة';

  @override
  String get statistics_profile_deco_error => 'فشل تحميل بيانات تخفيف الضغط';

  @override
  String get statistics_profile_deco_noDeco => 'بدون تخفيف ضغط';

  @override
  String get statistics_profile_deco_notRecorded => 'غير مسجل';

  @override
  String statistics_profile_deco_notRecordedHint(int count) {
    return '$count غطسة ليس لها بيانات انضغاط مسجلة أو قابلة للحساب، وهي مستبعدة من النسبة';
  }

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return 'معدل تخفيف الضغط: $percentage% من الغوصات تطلبت توقفات تخفيف ضغط';
  }

  @override
  String get statistics_profile_deco_subtitle =>
      'الغوصات التي تطلبت توقفات تخفيف ضغط';

  @override
  String get statistics_profile_deco_title => 'التزام تخفيف الضغط';

  @override
  String get statistics_profile_timeAtDepth_empty => 'لا توجد بيانات عمق متاحة';

  @override
  String get statistics_profile_timeAtDepth_error =>
      'فشل تحميل بيانات نطاق العمق';

  @override
  String get statistics_profile_timeAtDepth_subtitle =>
      'الوقت التقريبي المقضي في كل عمق';

  @override
  String get statistics_profile_timeAtDepth_title => 'الوقت في نطاقات العمق';

  @override
  String statistics_profile_timeAtDepth_valueFormat(Object value) {
    return '$value min';
  }

  @override
  String get statistics_progression_appBar_title => 'تقدم الغوص';

  @override
  String get statistics_progression_bottomTime_error =>
      'فشل تحميل اتجاه وقت القاع';

  @override
  String get statistics_progression_bottomTime_subtitle =>
      'متوسط المدة حسب الشهر';

  @override
  String get statistics_progression_bottomTime_title => 'اتجاه وقت القاع';

  @override
  String get statistics_progression_cumulative_error =>
      'فشل تحميل البيانات التراكمية';

  @override
  String get statistics_progression_cumulative_subtitle =>
      'إجمالي الغوصات عبر الزمن';

  @override
  String get statistics_progression_cumulative_title =>
      'العدد التراكمي للغوصات';

  @override
  String get statistics_progression_depthProgression_error =>
      'فشل تحميل تقدم العمق';

  @override
  String get statistics_progression_depthProgression_subtitle =>
      'أقصى عمق شهري على مدى 5 سنوات';

  @override
  String get statistics_progression_depthProgression_title => 'تقدم أقصى عمق';

  @override
  String get statistics_progression_divesPerYear_empty =>
      'لا توجد بيانات سنوية متاحة';

  @override
  String get statistics_progression_divesPerYear_error =>
      'فشل تحميل البيانات السنوية';

  @override
  String get statistics_progression_divesPerYear_subtitle =>
      'مقارنة عدد الغوصات السنوي';

  @override
  String get statistics_progression_divesPerYear_title => 'الغوصات لكل سنة';

  @override
  String get statistics_ranking_countLabel_dives => 'غوصات';

  @override
  String get statistics_ranking_countLabel_sightings => 'مشاهدات';

  @override
  String get statistics_ranking_countLabel_species => 'أنواع';

  @override
  String get statistics_ranking_emptyState => 'لا توجد بيانات بعد';

  @override
  String statistics_ranking_itemCount(Object count, Object label) {
    return '$count $label';
  }

  @override
  String statistics_ranking_moreItems(Object count) {
    return 'و $count أخرى';
  }

  @override
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  ) {
    return '$name، المرتبة $rank، $count $label';
  }

  @override
  String get statistics_records_appBar_title => 'أرقام الغوص القياسية';

  @override
  String get statistics_records_coldestDive => 'أبرد غوصة';

  @override
  String get statistics_records_deepestDive => 'أعمق غوصة';

  @override
  String statistics_records_diveNumber(Object number) {
    return 'الغوصة #$number';
  }

  @override
  String get statistics_records_emptySubtitle =>
      'ابدأ بتسجيل الغوصات لرؤية أرقامك القياسية هنا';

  @override
  String get statistics_records_emptyTitle => 'لا توجد أرقام قياسية بعد';

  @override
  String get statistics_records_error => 'خطأ في تحميل الأرقام القياسية';

  @override
  String get statistics_records_firstDive => 'أول غوصة';

  @override
  String get statistics_records_longestDive => 'أطول غوصة';

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
  String get statistics_records_milestones => 'الإنجازات';

  @override
  String get statistics_records_mostRecentDive => 'أحدث غوصة';

  @override
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  ) {
    return '$title: $value في $siteName';
  }

  @override
  String get statistics_records_retry => 'إعادة المحاولة';

  @override
  String get statistics_records_shallowestDive => 'أقل غوصة عمقاً';

  @override
  String get statistics_records_unknownSite => 'موقع غير معروف';

  @override
  String get statistics_records_warmestDive => 'أدفأ غوصة';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return 'قسم $title';
  }

  @override
  String get statistics_social_appBar_title => 'الرفاق والمجتمع';

  @override
  String get statistics_social_soloVsBuddy_empty =>
      'لا توجد بيانات غوصات متاحة';

  @override
  String get statistics_social_soloVsBuddy_error => 'فشل تحميل بيانات الرفاق';

  @override
  String get statistics_social_soloVsBuddy_solo => 'منفرد';

  @override
  String get statistics_social_soloVsBuddy_subtitle => 'الغوص مع أو بدون رفاق';

  @override
  String get statistics_social_soloVsBuddy_title =>
      'غوصات منفردة مقابل مع رفيق';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => 'مع رفيق';

  @override
  String get statistics_social_topBuddies_error => 'فشل تحميل تصنيف الرفاق';

  @override
  String get statistics_social_topBuddies_subtitle =>
      'رفاق الغوص الأكثر تكراراً';

  @override
  String get statistics_social_topBuddies_title => 'أفضل رفاق الغوص';

  @override
  String get statistics_social_topDiveCenters_error =>
      'فشل تحميل تصنيف مراكز الغوص';

  @override
  String get statistics_social_topDiveCenters_subtitle =>
      'المشغلون الأكثر زيارة';

  @override
  String get statistics_social_topDiveCenters_title => 'أفضل مراكز الغوص';

  @override
  String get statistics_summary_avgDepth => 'متوسط العمق';

  @override
  String get statistics_summary_avgTemp => 'متوسط الحرارة';

  @override
  String get statistics_summary_depthDistribution_empty =>
      'سيظهر المخطط عند تسجيل الغوصات';

  @override
  String get statistics_summary_depthDistribution_semanticLabel =>
      'مخطط دائري يعرض توزيع العمق';

  @override
  String get statistics_summary_depthDistribution_title => 'توزيع العمق';

  @override
  String get statistics_summary_diveTypes_empty =>
      'سيظهر المخطط عند تسجيل الغوصات';

  @override
  String statistics_summary_diveTypes_moreTypes(Object count) {
    return 'و $count أنواع أخرى';
  }

  @override
  String get statistics_summary_diveTypes_semanticLabel =>
      'مخطط دائري يعرض توزيع أنواع الغوص';

  @override
  String get statistics_summary_diveTypes_title => 'أنواع الغوص';

  @override
  String get statistics_summary_divesByMonth_empty =>
      'سيظهر المخطط عند تسجيل الغوصات';

  @override
  String get statistics_summary_divesByMonth_semanticLabel =>
      'مخطط أعمدة يعرض الغوصات حسب الشهر';

  @override
  String get statistics_summary_divesByMonth_title => 'الغوصات حسب الشهر';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel\n$count غوصات';
  }

  @override
  String get statistics_summary_header_subtitle =>
      'اختر فئة لاستكشاف إحصائيات مفصلة';

  @override
  String get statistics_summary_header_title => 'نظرة عامة على الإحصائيات';

  @override
  String get statistics_summary_maxDepth => 'أقصى عمق';

  @override
  String get statistics_summary_sitesVisited => 'المواقع التي تمت زيارتها';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غوصات',
      one: 'غوصة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty => 'لم يتم إنشاء وسوم بعد';

  @override
  String get statistics_summary_tagUsage_emptyHint =>
      'أضف وسوماً للغوصات لرؤية الإحصائيات';

  @override
  String statistics_summary_tagUsage_moreTags(Object count) {
    return 'و $count وسوم أخرى';
  }

  @override
  String statistics_summary_tagUsage_tagCount(Object count) {
    return '$count وسوم';
  }

  @override
  String get statistics_summary_tagUsage_title => 'استخدام الوسوم';

  @override
  String statistics_summary_topDiveSites_diveCount(Object count) {
    return '$count غوصات';
  }

  @override
  String get statistics_summary_topDiveSites_empty => 'لا توجد مواقع غوص بعد';

  @override
  String get statistics_summary_topDiveSites_title => 'أفضل مواقع الغوص';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count إجمالي';
  }

  @override
  String get statistics_summary_totalDives => 'إجمالي الغوصات';

  @override
  String get statistics_summary_totalTime => 'إجمالي الوقت';

  @override
  String get statistics_timePatterns_appBar_title => 'أنماط الوقت';

  @override
  String get statistics_timePatterns_dayOfWeek_empty => 'لا توجد بيانات متاحة';

  @override
  String get statistics_timePatterns_dayOfWeek_error =>
      'فشل تحميل بيانات أيام الأسبوع';

  @override
  String get statistics_timePatterns_dayOfWeek_fri => 'الجمعة';

  @override
  String get statistics_timePatterns_dayOfWeek_mon => 'الإثنين';

  @override
  String get statistics_timePatterns_dayOfWeek_sat => 'السبت';

  @override
  String get statistics_timePatterns_dayOfWeek_subtitle => 'متى تغوص أكثر؟';

  @override
  String get statistics_timePatterns_dayOfWeek_sun => 'الأحد';

  @override
  String get statistics_timePatterns_dayOfWeek_thu => 'الخميس';

  @override
  String get statistics_timePatterns_dayOfWeek_title =>
      'الغوصات حسب يوم الأسبوع';

  @override
  String get statistics_timePatterns_dayOfWeek_tue => 'الثلاثاء';

  @override
  String get statistics_timePatterns_dayOfWeek_wed => 'الأربعاء';

  @override
  String get statistics_timePatterns_month_apr => 'أبريل';

  @override
  String get statistics_timePatterns_month_aug => 'أغسطس';

  @override
  String get statistics_timePatterns_month_dec => 'ديسمبر';

  @override
  String get statistics_timePatterns_month_feb => 'فبراير';

  @override
  String get statistics_timePatterns_month_jan => 'يناير';

  @override
  String get statistics_timePatterns_month_jul => 'يوليو';

  @override
  String get statistics_timePatterns_month_jun => 'يونيو';

  @override
  String get statistics_timePatterns_month_mar => 'مارس';

  @override
  String get statistics_timePatterns_month_may => 'مايو';

  @override
  String get statistics_timePatterns_month_nov => 'نوفمبر';

  @override
  String get statistics_timePatterns_month_oct => 'أكتوبر';

  @override
  String get statistics_timePatterns_month_sep => 'سبتمبر';

  @override
  String get statistics_timePatterns_seasonal_empty => 'لا توجد بيانات متاحة';

  @override
  String get statistics_timePatterns_seasonal_error =>
      'فشل تحميل البيانات الموسمية';

  @override
  String get statistics_timePatterns_seasonal_subtitle =>
      'الغوصات حسب الشهر (جميع السنوات)';

  @override
  String get statistics_timePatterns_seasonal_title => 'الأنماط الموسمية';

  @override
  String get statistics_timePatterns_surfaceInterval_average => 'المتوسط';

  @override
  String get statistics_timePatterns_surfaceInterval_empty =>
      'لا توجد بيانات فترة السطح متاحة';

  @override
  String get statistics_timePatterns_surfaceInterval_error =>
      'فشل تحميل بيانات فترة السطح';

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
  String get statistics_timePatterns_surfaceInterval_maximum => 'الأقصى';

  @override
  String get statistics_timePatterns_surfaceInterval_minimum => 'الأدنى';

  @override
  String get statistics_timePatterns_surfaceInterval_subtitle =>
      'الوقت بين الغوصات';

  @override
  String get statistics_timePatterns_surfaceInterval_title =>
      'إحصائيات فترة السطح';

  @override
  String get statistics_timePatterns_timeOfDay_error =>
      'فشل تحميل بيانات وقت اليوم';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle =>
      'صباحاً، بعد الظهر، مساءً، أو ليلاً';

  @override
  String get statistics_timePatterns_timeOfDay_title => 'الغوصات حسب وقت اليوم';

  @override
  String get statistics_tooltip_diveRecords => 'أرقام الغوص القياسية';

  @override
  String get statistics_tooltip_filter => 'تصفية الإحصائيات';

  @override
  String get statistics_tooltip_refreshRecords => 'تحديث الأرقام القياسية';

  @override
  String get statistics_tooltip_refreshStatistics => 'تحديث الإحصائيات';

  @override
  String statistics_valueCard_semanticLabel(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String get surfaceInterval_aboutTissueLoading_body =>
      'جسمك يحتوي على 16 حجرة نسيجية تمتص وتطلق النيتروجين بمعدلات مختلفة. الأنسجة السريعة (مثل الدم) تتشبع بسرعة ولكنها أيضاً تطلق الغاز بسرعة. الأنسجة البطيئة (مثل العظام والدهون) تستغرق وقتاً أطول للتحميل والتفريغ. \"الحجرة الرائدة\" هي أي نسيج أكثر تشبعاً وعادة ما تتحكم في حد عدم تخفيف الضغط (NDL). خلال فترة السطح، تطلق جميع الأنسجة الغاز نحو مستويات التشبع السطحي (~40% تحميل).';

  @override
  String get surfaceInterval_aboutTissueLoading_title => 'حول تحميل الأنسجة';

  @override
  String get surfaceInterval_action_resetDefaults =>
      'إعادة تعيين إلى الإعدادات الافتراضية';

  @override
  String get surfaceInterval_disclaimer =>
      'هذه الأداة للتخطيط فقط. استخدم دائماً حاسوب الغوص واتبع تدريبك. النتائج مبنية على خوارزمية Buhlmann ZH-L16C وقد تختلف عن حاسوبك.';

  @override
  String get surfaceInterval_field_depth => 'العمق';

  @override
  String get surfaceInterval_field_gasMix => 'خليط الغاز: ';

  @override
  String get surfaceInterval_field_he => 'He';

  @override
  String get surfaceInterval_field_o2 => 'O₂';

  @override
  String get surfaceInterval_field_time => 'الوقت';

  @override
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit) {
    return 'عمق الغطسة الأولى: $depth $unit';
  }

  @override
  String surfaceInterval_firstDive_timeSemantics(Object time) {
    return 'وقت الغطسة الأولى: $time دقيقة';
  }

  @override
  String get surfaceInterval_firstDive_title => 'الغطسة الأولى';

  @override
  String surfaceInterval_format_hours(Object count) {
    return '$count ساعة';
  }

  @override
  String surfaceInterval_format_minutes(Object count) {
    return '$count دقيقة';
  }

  @override
  String get surfaceInterval_gasMix_air => 'هواء';

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
    return 'ppO₂ $ppO2 على عمق $depth يتجاوز $limit. أقصى عمق تشغيل لهذا الخليط هو $mod.';
  }

  @override
  String surfaceInterval_heSemantics(Object percent) {
    return 'الهيليوم: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String surfaceInterval_result_beyondHorizon(Object hours) {
    return 'زمن الانتظار يتجاوز $hours ساعات التي يبحث فيها هذا المخطط. يستمر التخلص من النيتروجين، لذا ستكفي فترة سطح أطول.';
  }

  @override
  String surfaceInterval_result_beyondHorizonShort(Object hours) {
    return 'أكثر من $hours ساعات';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'الفترة الحالية';

  @override
  String get surfaceInterval_result_gasUnsafe => 'الغاز غير آمن على هذا العمق';

  @override
  String get surfaceInterval_result_inDeco => 'في تخفيف الضغط';

  @override
  String get surfaceInterval_result_increaseInterval =>
      'زد فترة السطح أو قلل عمق/وقت الغطسة الثانية';

  @override
  String get surfaceInterval_result_minimumInterval =>
      'الحد الأدنى لفترة السطح';

  @override
  String get surfaceInterval_result_ndlForSecondDive => 'NDL للغطسة الثانية';

  @override
  String surfaceInterval_result_ndlMinutes(Object minutes) {
    return '$minutes دقيقة NDL';
  }

  @override
  String surfaceInterval_result_noIntervalHelps(Object minutes) {
    return 'لا تكفي أي فترة سطح. أطول غطسة بدون توقف إلزامي على هذا العمق بهذا الخليط هي $minutes دقيقة. قلّل زمن الغطسة الثانية أو قلّل عمقها.';
  }

  @override
  String get surfaceInterval_result_notAchievable =>
      'غير قابل للتحقيق بأي فترة سطح';

  @override
  String get surfaceInterval_result_notYetSafe =>
      'ليس آمناً بعد، زد فترة السطح';

  @override
  String get surfaceInterval_result_safeToDive => 'آمن للغوص';

  @override
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  ) {
    return 'الحد الأدنى لفترة السطح: $interval. الفترة الحالية: $current. NDL للغطسة الثانية: $ndl. $status';
  }

  @override
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit) {
    return 'عمق الغطسة الثانية: $depth $unit';
  }

  @override
  String surfaceInterval_secondDive_heSemantics(Object percent) {
    return 'هيليوم الغطسة الثانية: $percent%';
  }

  @override
  String surfaceInterval_secondDive_o2Semantics(Object percent) {
    return 'أكسجين الغطسة الثانية: $percent%';
  }

  @override
  String surfaceInterval_secondDive_timeSemantics(Object time) {
    return 'وقت الغطسة الثانية: $time دقيقة';
  }

  @override
  String get surfaceInterval_secondDive_title => 'الغطسة الثانية';

  @override
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval) {
    return 'مخطط تعافي الأنسجة يوضح إطلاق الغاز من 16 حجرة خلال فترة سطح $interval';
  }

  @override
  String get surfaceInterval_tissueRecovery_compartmentsLabel =>
      'الحجرات (حسب سرعة نصف الوقت)';

  @override
  String get surfaceInterval_tissueRecovery_description =>
      'يوضح كيفية إطلاق كل من 16 حجرة نسيجية للغاز خلال فترة السطح';

  @override
  String get surfaceInterval_tissueRecovery_fast => 'سريع (C1-5)';

  @override
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number) {
    return 'الحجرة الرائدة: C$number';
  }

  @override
  String get surfaceInterval_tissueRecovery_loadingPercent => 'نسبة التحميل %';

  @override
  String get surfaceInterval_tissueRecovery_medium => 'متوسط (C6-10)';

  @override
  String get surfaceInterval_tissueRecovery_min => 'دقيقة';

  @override
  String get surfaceInterval_tissueRecovery_now => 'الآن';

  @override
  String get surfaceInterval_tissueRecovery_slow => 'بطيء (C11-16)';

  @override
  String get surfaceInterval_tissueRecovery_title => 'تعافي الأنسجة';

  @override
  String get surfaceInterval_title => 'فترة السطح';

  @override
  String tags_action_createNamed(Object tagName) {
    return 'إنشاء \"$tagName\"';
  }

  @override
  String get tags_action_createTag => 'إنشاء وسم';

  @override
  String get tags_action_browse => 'تصفح';

  @override
  String get tags_picker_title => 'اختيار الوسوم';

  @override
  String get tags_picker_empty =>
      'لا توجد وسوم بعد. اكتب اسم وسم لإنشاء أول وسم لك.';

  @override
  String tags_picker_errorLoading(String error) {
    return 'خطأ في تحميل الوسوم: $error';
  }

  @override
  String get tags_picker_allAdded => 'تمت إضافة جميع الوسوم بالفعل.';

  @override
  String get tags_picker_noMatches => 'لا توجد وسوم تطابق بحثك.';

  @override
  String tags_picker_addCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إضافة $count وسم',
      one: 'إضافة وسم واحد',
      zero: 'إضافة وسوم',
    );
    return '$_temp0';
  }

  @override
  String get tags_action_deleteTag => 'حذف الوسم';

  @override
  String tags_dialog_deleteMessage(Object tagName) {
    return 'هل أنت متأكد من حذف \"$tagName\"؟ سيتم إزالته من جميع الغطسات.';
  }

  @override
  String get tags_dialog_deleteTitle => 'حذف الوسم؟';

  @override
  String get tags_empty => 'لا توجد وسوم بعد. أنشئ وسوماً عند تعديل الغطسات.';

  @override
  String get tags_hint_addMoreTags => 'إضافة المزيد من الوسوم...';

  @override
  String get importWizard_tagsLabel => 'Tags';

  @override
  String get importWizard_photos_stepLabel => 'الصور';

  @override
  String importWizard_photos_foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صور مشار إليها في هذا السجل',
      one: 'صورة واحدة مشار إليها في هذا السجل',
    );
    return '$_temp0';
  }

  @override
  String get importWizard_photos_chooseFolder => 'اختر مجلد الصور...';

  @override
  String get importWizard_photos_scanning => 'جارٍ فحص المجلد...';

  @override
  String importWizard_photos_matchSummary(
    int matched,
    int byName,
    int missing,
  ) {
    return '$matched مطابقة، $byName بالاسم فقط، $missing غير موجودة';
  }

  @override
  String get importWizard_photos_skip => 'تخطي الصور';

  @override
  String get importWizard_photos_mobileUnsupported =>
      'يتطلب استيراد الصور مجلدًا على قرص هذا الجهاز. شغّل هذا الاستيراد على جهاز كمبيوتر لتضمينها. تُستورد الغطسات والمواقع بشكل طبيعي.';

  @override
  String importWizard_review_olderDivesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تخطي $count غطسات أقدم — موجودة بالفعل في سجلك',
      one: 'تم تخطي غطسة واحدة أقدم — موجودة بالفعل في سجلك',
    );
    return '$_temp0';
  }

  @override
  String get tags_hint_addTags => 'إضافة وسوم...';

  @override
  String get tags_manage_title => 'الوسوم';

  @override
  String get tags_manage_searchHint => 'البحث في الوسوم...';

  @override
  String tags_manage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غوصة',
      one: 'غوصة واحدة',
      zero: '0 غوصات',
    );
    return '$_temp0';
  }

  @override
  String get tags_manage_emptyState => 'لا توجد وسوم بعد. أنشئ واحداً للبدء.';

  @override
  String tags_manage_selectedCount(int count) {
    return '$count محدد';
  }

  @override
  String get tags_manage_createTitle => 'إنشاء وسم';

  @override
  String get tags_manage_editTitle => 'تعديل الوسم';

  @override
  String get tags_manage_nameLabel => 'اسم الوسم';

  @override
  String get tags_manage_colorLabel => 'اللون';

  @override
  String get tags_manage_nameRequired => 'اسم الوسم مطلوب';

  @override
  String get tags_manage_deleteTitle => 'حذف الوسم؟';

  @override
  String tags_manage_deleteMessage(String tagName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غوصة',
      one: 'غوصة واحدة',
      zero: '0 غوصات',
    );
    return 'سيتم إزالة \"$tagName\" من $_temp0. لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String tags_manage_bulkDeleteTitle(int count) {
    return 'حذف $count وسم؟';
  }

  @override
  String tags_manage_bulkDeleteMessage(int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount غوصة',
      one: 'غوصة واحدة',
      zero: '0 غوصات',
    );
    return 'سيتم إزالة هذه الوسوم من $_temp0 إجمالاً. لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String tags_manage_mergeTitle(int count) {
    return 'دمج $count وسم';
  }

  @override
  String get tags_manage_mergeResultName => 'اسم الوسم الناتج:';

  @override
  String get tags_manage_mergeKeepFrom => 'أو الاحتفاظ بالاسم من:';

  @override
  String tags_manage_mergeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غوصة',
      one: 'غوصة واحدة',
      zero: '0 غوصات',
    );
    return 'سيؤثر هذا على $_temp0 إجمالاً.';
  }

  @override
  String get tags_manage_mergeAction => 'دمج';

  @override
  String get tags_title_manageTags => 'إدارة الوسوم';

  @override
  String get tank_al30Stage_description =>
      'أسطوانة ألومنيوم مرحلية 30 قدم مكعب';

  @override
  String get tank_al30Stage_displayName => 'AL30 Stage';

  @override
  String get tank_al40Stage_description =>
      'أسطوانة ألومنيوم مرحلية 40 قدم مكعب';

  @override
  String get tank_al40Stage_displayName => 'AL40 Stage';

  @override
  String get tank_al40_description => 'أسطوانة ألومنيوم 40 قدم مكعب (احتياطية)';

  @override
  String get tank_al40_displayName => 'AL40';

  @override
  String get tank_al63_description => 'أسطوانة ألومنيوم 63 قدم مكعب';

  @override
  String get tank_al63_displayName => 'AL63';

  @override
  String get tank_al80_description =>
      'أسطوانة ألومنيوم 80 قدم مكعب (الأكثر شيوعاً)';

  @override
  String get tank_al80_displayName => 'AL80';

  @override
  String get tank_hp100_description => 'أسطوانة فولاذ ضغط عالٍ 100 قدم مكعب';

  @override
  String get tank_hp100_displayName => 'HP100';

  @override
  String get tank_hp120_description => 'أسطوانة فولاذ ضغط عالٍ 120 قدم مكعب';

  @override
  String get tank_hp120_displayName => 'HP120';

  @override
  String get tank_hp80_description => 'أسطوانة فولاذ ضغط عالٍ 80 قدم مكعب';

  @override
  String get tank_hp80_displayName => 'HP80';

  @override
  String get tank_lp85_description => 'أسطوانة فولاذ ضغط منخفض 85 قدم مكعب';

  @override
  String get tank_lp85_displayName => 'LP85';

  @override
  String get tank_steel10_description => 'أسطوانة فولاذ 10 لتر (أوروبا)';

  @override
  String get tank_steel10_displayName => 'Steel 10L';

  @override
  String get tank_steel12_description => 'أسطوانة فولاذ 12 لتر (أوروبا)';

  @override
  String get tank_steel12_displayName => 'Steel 12L';

  @override
  String get tank_steel15_description => 'أسطوانة فولاذ 15 لتر (أوروبا)';

  @override
  String get tank_steel15_displayName => 'Steel 15L';

  @override
  String get tides_action_refresh => 'تحديث بيانات المد والجزر';

  @override
  String get tides_chart_24hourForecast => 'توقعات 24 ساعة';

  @override
  String tides_chart_heightAxis(Object depthSymbol) {
    return 'الارتفاع ($depthSymbol)';
  }

  @override
  String get tides_chart_msl => 'MSL';

  @override
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr) {
    return ' الآن $nowTimeStr $nowHeightStr';
  }

  @override
  String get tides_error_unableToLoad => 'تعذر تحميل بيانات المد والجزر';

  @override
  String get tides_error_unableToLoadChart => 'تعذر تحميل المخطط';

  @override
  String tides_label_ago(Object duration) {
    return '$duration مضت';
  }

  @override
  String tides_label_currentHeight(Object height, Object depthSymbol) {
    return 'الحالي: $height$depthSymbol';
  }

  @override
  String tides_label_fromNow(Object duration) {
    return '$duration من الآن';
  }

  @override
  String get tides_label_high => 'مرتفع';

  @override
  String get tides_label_highIn => 'مد في';

  @override
  String get tides_label_highTide => 'مد مرتفع';

  @override
  String get tides_label_low => 'منخفض';

  @override
  String get tides_label_lowIn => 'جزر في';

  @override
  String get tides_label_lowTide => 'جزر منخفض';

  @override
  String tides_label_tideIn(Object duration) {
    return 'في $duration';
  }

  @override
  String get tides_label_tideTimes => 'أوقات المد والجزر';

  @override
  String get tides_label_today => 'اليوم';

  @override
  String get tides_label_tomorrow => 'غداً';

  @override
  String get tides_label_upcomingTides => 'المد والجزر القادم';

  @override
  String get tides_legend_highTide => 'مد مرتفع';

  @override
  String get tides_legend_lowTide => 'جزر منخفض';

  @override
  String get tides_legend_now => 'الآن';

  @override
  String get tides_legend_tideLevel => 'مستوى المد والجزر';

  @override
  String get tides_noDataAvailable => 'لا توجد بيانات مد وجزر متاحة';

  @override
  String get tides_noDataForLocation =>
      'بيانات المد والجزر غير متاحة لهذا الموقع';

  @override
  String get tides_noExtremesData => 'لا توجد بيانات الحدود';

  @override
  String get tides_noTideTimesAvailable => 'لا توجد أوقات مد وجزر متاحة';

  @override
  String tides_semantic_currentTide(
    Object tideState,
    Object height,
    Object depthSymbol,
    Object nextExtreme,
  ) {
    return 'مد وجزر $tideState، $height$depthSymbol$nextExtreme';
  }

  @override
  String tides_semantic_extremeItem(
    Object typeLabel,
    Object time,
    Object height,
    Object depthSymbol,
  ) {
    return 'مد وجزر $typeLabel في $time، $height$depthSymbol';
  }

  @override
  String tides_semantic_tideChart(Object extremesSummary) {
    return 'مخطط المد والجزر. $extremesSummary';
  }

  @override
  String tides_semantic_tideState(Object state) {
    return 'حالة المد والجزر: $state';
  }

  @override
  String tides_source_noaaStation(String name, String distance) {
    return 'محطة NOAA: $name ($distance)';
  }

  @override
  String get tides_source_modelEstimate => 'تقدير نموذج المحيط';

  @override
  String get tides_source_modelCaveat =>
      'نموذج مبني على بيانات الأقمار الصناعية. قد تختلف الأوقات والارتفاعات قرب السواحل المعقدة.';

  @override
  String get tides_source_sheetTitle => 'مصدر بيانات المد والجزر';

  @override
  String get tides_source_datumMllw => 'الارتفاعات نسبة إلى MLLW (مرجع المحطة)';

  @override
  String get tides_source_datumMsl =>
      'الارتفاعات نسبة إلى متوسط مستوى سطح البحر';

  @override
  String get tides_title => 'المد والجزر';

  @override
  String get transfer_appBar_title => 'النقل';

  @override
  String get transfer_computers_aboutContent =>
      'قم بتوصيل حاسوب الغوص عبر البلوتوث لتنزيل سجلات الغوص مباشرة إلى التطبيق. تشمل الحواسيب المدعومة Suunto و Shearwater و Garmin و Mares والعديد من العلامات التجارية الشهيرة الأخرى.\n\nيمكن لمستخدمي Apple Watch Ultra استيراد بيانات الغوص مباشرة من تطبيق الصحة، بما في ذلك العمق والمدة ومعدل ضربات القلب.';

  @override
  String get transfer_computers_aboutTitle => 'حول حواسيب الغوص';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple Watch';

  @override
  String get transfer_computers_appleWatchSubtitle =>
      'Import dives via Apple HealthKit';

  @override
  String get transfer_computers_appleWatchTitle => 'الاستيراد من Apple Watch';

  @override
  String get transfer_computers_connectSubtitle => 'اكتشاف وإقران حاسوب غوص';

  @override
  String get transfer_computers_connectTitle => 'توصيل حاسوب جديد';

  @override
  String get transfer_computers_errorLoading => 'خطأ في تحميل الحواسيب';

  @override
  String get transfer_computers_loading => 'جارٍ التحميل...';

  @override
  String get transfer_computers_manageTitle => 'إدارة الحواسيب';

  @override
  String get transfer_computers_noComputersSaved => 'لا توجد حواسيب محفوظة';

  @override
  String transfer_computers_diveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غوصات',
      one: 'غوصة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get transfer_computers_downloadTooltip => 'تنزيل الغوصات';

  @override
  String get transfer_computers_knownComputersHeader =>
      'أجهزة الكمبيوتر المعروفة';

  @override
  String transfer_computers_lastDownloadDaysAgo(int days) {
    return 'قبل $days أيام';
  }

  @override
  String transfer_computers_lastDownloadHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'قبل $hours ساعات',
      one: 'قبل ساعة',
    );
    return '$_temp0';
  }

  @override
  String transfer_computers_lastDownloadMinutesAgo(int minutes) {
    return 'قبل $minutes دقيقة';
  }

  @override
  String get transfer_computers_lastDownloadNever => 'أبدًا';

  @override
  String get transfer_computers_lastDownloadYesterday => 'أمس';

  @override
  String transfer_computers_savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حواسيب محفوظة',
      one: 'حاسوب محفوظ',
    );
    return '$count $_temp0';
  }

  @override
  String get transfer_computers_sectionHeader => 'حواسيب الغوص';

  @override
  String get transfer_csvExport_cancelButton => 'إلغاء';

  @override
  String get transfer_csvExport_dataTypeHeader => 'نوع البيانات';

  @override
  String get transfer_csvExport_descriptionDives =>
      'تصدير جميع سجلات الغوص كجدول بيانات';

  @override
  String get transfer_csvExport_descriptionEquipment =>
      'تصدير جرد المعدات ومعلومات الصيانة';

  @override
  String get transfer_csvExport_descriptionSites =>
      'تصدير مواقع الغوص وتفاصيلها';

  @override
  String get transfer_csvExport_dialogTitle => 'تصدير CSV';

  @override
  String get transfer_csvExport_exportButton => 'تصدير CSV';

  @override
  String get transfer_csvExport_optionDivesTitle => 'الغوصات CSV';

  @override
  String get transfer_csvExport_optionEquipmentTitle => 'المعدات CSV';

  @override
  String get transfer_csvExport_optionSitesTitle => 'المواقع CSV';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return 'تصدير $typeName';
  }

  @override
  String get transfer_csvExport_typeDives => 'الغوصات';

  @override
  String get transfer_csvExport_typeEquipment => 'المعدات';

  @override
  String get transfer_csvExport_typeSites => 'المواقع';

  @override
  String get transfer_detail_backTooltip => 'العودة إلى النقل';

  @override
  String get transfer_export_aboutContent =>
      'قم بتصدير بيانات الغوص بصيغ متعددة. ينشئ PDF سجل غوص قابل للطباعة. UDDF هو تنسيق عالمي متوافق مع معظم برامج تسجيل الغوص. يمكن فتح ملفات CSV في تطبيقات جداول البيانات.';

  @override
  String get transfer_export_backupLink =>
      'انتقال إلى النسخ الاحتياطي والاستعادة';

  @override
  String get transfer_export_aboutTitle => 'حول التصدير';

  @override
  String get transfer_export_completed => 'اكتمل التصدير';

  @override
  String get transfer_export_csvSubtitle => 'تنسيق جدول بيانات';

  @override
  String get transfer_export_csvTitle => 'تصدير CSV';

  @override
  String get transfer_export_excelSubtitle =>
      'جميع البيانات في ملف واحد (غوصات، مواقع، معدات، إحصائيات)';

  @override
  String get transfer_export_excelTitle => 'مصنف Excel';

  @override
  String transfer_export_failed(Object error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get transfer_export_kmlSubtitle =>
      'عرض مواقع الغوص على كرة أرضية ثلاثية الأبعاد';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => 'تصدير متعدد الصيغ';

  @override
  String get transfer_export_optionSaveSubtitle => 'اختر مكان الحفظ على جهازك';

  @override
  String get transfer_export_optionSaveTitle => 'حفظ كملف';

  @override
  String get transfer_export_optionShareSubtitle =>
      'إرسال عبر البريد الإلكتروني أو الرسائل أو تطبيقات أخرى';

  @override
  String get transfer_export_optionShareTitle => 'مشاركة';

  @override
  String get transfer_export_pdfSubtitle => 'سجل غوص قابل للطباعة';

  @override
  String get transfer_export_pdfTitle => 'سجل PDF';

  @override
  String get transfer_export_progressExporting => 'جارٍ التصدير...';

  @override
  String get transfer_export_sectionHeader => 'تصدير البيانات';

  @override
  String get transfer_export_uddfSubtitle => 'تنسيق بيانات الغوص العالمي';

  @override
  String get transfer_export_uddfTitle => 'تصدير UDDF';

  @override
  String get transfer_import_aboutContent =>
      'استخدم \"استيراد البيانات\" للحصول على أفضل تجربة -- يكتشف تلقائيًا صيغة الملف والتطبيق المصدر. تتوفر أيضًا خيارات الصيغ الفردية أدناه للوصول المباشر.';

  @override
  String get transfer_import_aboutTitle => 'حول الاستيراد';

  @override
  String get transfer_import_fileImportSemanticLabel =>
      'استيراد البيانات مع الكشف التلقائي';

  @override
  String get transfer_import_fileImportSubtitle =>
      'يكتشف تلقائيًا CSV و UDDF و FIT والمزيد';

  @override
  String get transfer_import_fileImportTitle => 'استيراد البيانات';

  @override
  String get transfer_import_sectionHeader => 'استيراد البيانات';

  @override
  String get transfer_pdfExport_cancelButton => 'إلغاء';

  @override
  String get transfer_pdfExport_dialogTitle => 'تصدير سجل PDF';

  @override
  String get transfer_pdfExport_exportButton => 'تصدير PDF';

  @override
  String get transfer_pdfExport_includeCertCards => 'تضمين بطاقات الشهادات';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle =>
      'إضافة صور بطاقات الشهادات الممسوحة ضوئيًا إلى ملف PDF';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => 'حجم الصفحة';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Letter';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => 'مفصل';

  @override
  String get transfer_pdfExport_templateDetailedDesc =>
      'معلومات الغوصة الكاملة مع الملاحظات والتقييمات';

  @override
  String get transfer_pdfExport_templateHeader => 'القالب';

  @override
  String get transfer_pdfExport_templateNauiStyle => 'نمط NAUI';

  @override
  String get transfer_pdfExport_templateNauiStyleDesc =>
      'تخطيط مطابق لتنسيق سجل NAUI';

  @override
  String get transfer_pdfExport_templatePadiStyle => 'نمط PADI';

  @override
  String get transfer_pdfExport_templatePadiStyleDesc =>
      'تخطيط مطابق لتنسيق سجل PADI';

  @override
  String get transfer_pdfExport_templateProfessional => 'احترافي';

  @override
  String get transfer_pdfExport_templateProfessionalDesc =>
      'مساحات للتوقيع والختم للتحقق';

  @override
  String transfer_pdfExport_templateSemanticLabel(Object templateName) {
    return 'اختيار قالب $templateName';
  }

  @override
  String get transfer_pdfExport_templateSimple => 'بسيط';

  @override
  String get transfer_pdfExport_templateSimpleDesc =>
      'تنسيق جدول مضغوط، غوصات كثيرة في كل صفحة';

  @override
  String get transfer_section_computersSubtitle => 'التنزيل من الجهاز';

  @override
  String get transfer_section_computersTitle => 'حواسيب الغوص';

  @override
  String get transfer_section_exportSubtitle => 'CSV، UDDF، سجل PDF';

  @override
  String get transfer_section_exportTitle => 'تصدير';

  @override
  String get transfer_section_importSubtitle => 'ملفات CSV، UDDF';

  @override
  String get transfer_section_importTitle => 'استيراد';

  @override
  String get transfer_summary_description => 'استيراد وتصدير بيانات الغوص';

  @override
  String get transfer_summary_selectSection => 'اختر قسمًا من القائمة';

  @override
  String get transfer_summary_title => 'النقل';

  @override
  String transfer_unknownSection(Object sectionId) {
    return 'قسم غير معروف: $sectionId';
  }

  @override
  String get trips_appBar_title => 'الرحلات';

  @override
  String get trips_appBar_tripPhotos => 'صور الرحلة';

  @override
  String get trips_detail_action_delete => 'حذف';

  @override
  String get trips_detail_action_export => 'تصدير';

  @override
  String get trips_detail_appBar_title => 'الرحلة';

  @override
  String get trips_detail_dialog_cancel => 'إلغاء';

  @override
  String get trips_detail_dialog_deleteConfirm => 'حذف';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return 'هل أنت متأكد أنك تريد حذف \"$name\"؟ سيتم إزالة الرحلة مع الاحتفاظ بالغوصات.';
  }

  @override
  String get trips_detail_dialog_deleteTitle => 'حذف الرحلة؟';

  @override
  String get trips_detail_dives_empty => 'لا توجد غوصات في هذه الرحلة بعد';

  @override
  String get trips_detail_dives_errorLoading => 'تعذر تحميل الغوصات';

  @override
  String get trips_detail_dives_unknownSite => 'موقع غوص غير معروف';

  @override
  String trips_detail_dives_viewAll(Object count) {
    return 'عرض الكل ($count)';
  }

  @override
  String trips_detail_durationDays(Object days) {
    return '$days أيام';
  }

  @override
  String get trips_detail_export_csv_comingSoon => 'تصدير CSV قريبًا';

  @override
  String get trips_detail_export_csv_subtitle => 'جميع الغوصات في هذه الرحلة';

  @override
  String get trips_detail_export_csv_title => 'تصدير إلى CSV';

  @override
  String get trips_detail_export_pdf_comingSoon => 'تصدير PDF قريبًا';

  @override
  String get trips_detail_export_pdf_subtitle =>
      'ملخص الرحلة مع تفاصيل الغوصات';

  @override
  String get trips_detail_export_pdf_title => 'تصدير إلى PDF';

  @override
  String get trips_detail_label_liveaboard => 'سفينة غوص';

  @override
  String get trips_detail_label_location => 'الموقع';

  @override
  String get trips_detail_label_resort => 'المنتجع';

  @override
  String get trips_detail_scan_accessDenied => 'تم رفض الوصول إلى مكتبة الصور';

  @override
  String get trips_detail_scan_addDivesFirst => 'أضف غوصات أولًا لربط الصور';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return 'خطأ في ربط الصور: $error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return 'خطأ في المسح: $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return 'تم ربط $count صور';
  }

  @override
  String get trips_detail_scan_linkingPhotos => 'جارٍ ربط الصور...';

  @override
  String get trips_detail_sectionTitle_details => 'تفاصيل الرحلة';

  @override
  String get trips_detail_sectionTitle_dives => 'الغوصات';

  @override
  String get trips_detail_sectionTitle_notes => 'ملاحظات';

  @override
  String get trips_detail_sectionTitle_statistics => 'إحصائيات الرحلة';

  @override
  String get trips_detail_snackBar_deleted => 'تم حذف الرحلة';

  @override
  String get trips_detail_stat_avgDepth => 'متوسط العمق';

  @override
  String get trips_detail_stat_maxDepth => 'أقصى عمق';

  @override
  String get trips_detail_stat_totalRuntime => 'إجمالي وقت التشغيل';

  @override
  String get trips_detail_stat_totalDives => 'إجمالي الغوصات';

  @override
  String get trips_detail_tab_checklist => 'قائمة التحقق';

  @override
  String get trips_detail_tooltip_edit => 'تعديل الرحلة';

  @override
  String get trips_detail_tooltip_editShort => 'تعديل';

  @override
  String get trips_detail_tooltip_moreOptions => 'خيارات إضافية';

  @override
  String get trips_detail_tooltip_viewOnMap => 'عرض على الخريطة';

  @override
  String trips_diveScan_addButton(int count) {
    return 'إضافة $count غوصات';
  }

  @override
  String trips_diveScan_added(int count) {
    return 'تمت إضافة $count غوصات إلى الرحلة';
  }

  @override
  String get trips_diveScan_cancel => 'إلغاء';

  @override
  String trips_diveScan_currentTrip(String tripName) {
    return 'حاليا في: $tripName';
  }

  @override
  String get trips_diveScan_deselectAll => 'إلغاء تحديد الكل';

  @override
  String trips_diveScan_error(String error) {
    return 'خطأ في البحث عن الغوصات: $error';
  }

  @override
  String get trips_diveScan_findButton => 'البحث عن الغوصات المطابقة';

  @override
  String trips_diveScan_groupOtherTrips(int count) {
    return 'في رحلات أخرى ($count)';
  }

  @override
  String trips_diveScan_groupUnassigned(int count) {
    return 'غير مخصصة ($count)';
  }

  @override
  String get trips_diveScan_noMatches => 'لم يتم العثور على غوصات مطابقة';

  @override
  String get trips_diveScan_noDiver => 'اختر غوّاصًا نشطًا للبحث عن الغطسات';

  @override
  String get trips_diveScan_selectAll => 'تحديد الكل';

  @override
  String trips_diveScan_subtitle(int count) {
    return 'تم العثور على $count غوصات في نطاق التاريخ';
  }

  @override
  String get trips_diveScan_title => 'إضافة غوصات إلى الرحلة';

  @override
  String get trips_diveScan_unknownSite => 'موقع غير معروف';

  @override
  String get trips_edit_appBar_add => 'إضافة رحلة';

  @override
  String get trips_edit_appBar_edit => 'تعديل الرحلة';

  @override
  String get trips_edit_button_add => 'إضافة رحلة';

  @override
  String get trips_edit_button_cancel => 'إلغاء';

  @override
  String get trips_edit_button_save => 'حفظ';

  @override
  String get trips_edit_button_update => 'تحديث الرحلة';

  @override
  String get trips_edit_dialog_discard => 'تجاهل';

  @override
  String get trips_edit_dialog_discardContent =>
      'لديك تغييرات غير محفوظة. هل أنت متأكد أنك تريد المغادرة؟';

  @override
  String get trips_edit_dialog_discardTitle => 'تجاهل التغييرات؟';

  @override
  String get trips_edit_dialog_keepEditing => 'متابعة التعديل';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days أيام';
  }

  @override
  String get trips_edit_hint_liveaboardName => 'مثال: MY Blue Force One';

  @override
  String get trips_edit_hint_location => 'مثال: مصر، البحر الأحمر';

  @override
  String get trips_edit_hint_notes => 'أي ملاحظات إضافية حول هذه الرحلة';

  @override
  String get trips_edit_hint_resortName => 'مثال: مرسى شاجرة';

  @override
  String get trips_edit_hint_tripName => 'مثال: رحلة البحر الأحمر 2024';

  @override
  String get trips_edit_label_endDate => 'تاريخ الانتهاء';

  @override
  String get trips_edit_label_liveaboardName => 'اسم سفينة الغوص';

  @override
  String get trips_edit_label_location => 'الموقع';

  @override
  String get trips_edit_label_notes => 'ملاحظات';

  @override
  String get trips_edit_label_resortName => 'اسم المنتجع';

  @override
  String get trips_edit_label_returnFlight => 'رحلة العودة';

  @override
  String get trips_edit_returnFlightClear => 'مسح رحلة العودة';

  @override
  String get trips_edit_returnFlightNotSet => 'غير محدد';

  @override
  String get trips_edit_label_startDate => 'تاريخ البدء';

  @override
  String get trips_edit_label_tripName => 'اسم الرحلة *';

  @override
  String get trips_edit_sectionTitle_dates => 'تواريخ الرحلة';

  @override
  String get trips_edit_sectionTitle_location => 'الموقع';

  @override
  String get trips_edit_sectionTitle_notes => 'ملاحظات';

  @override
  String get trips_edit_semanticLabel_save => 'حفظ الرحلة';

  @override
  String get trips_edit_snackBar_added => 'تمت إضافة الرحلة بنجاح';

  @override
  String trips_edit_snackBar_errorLoading(Object error) {
    return 'خطأ في تحميل الرحلة: $error';
  }

  @override
  String trips_edit_snackBar_errorSaving(Object error) {
    return 'خطأ في حفظ الرحلة: $error';
  }

  @override
  String get trips_edit_snackBar_updated => 'تم تحديث الرحلة بنجاح';

  @override
  String get trips_edit_validation_nameRequired => 'يرجى إدخال اسم الرحلة';

  @override
  String get trips_gallery_accessDenied => 'تم رفض الوصول إلى مكتبة الصور';

  @override
  String get trips_gallery_addDivesFirst => 'أضف غوصات أولًا لربط الصور';

  @override
  String get trips_gallery_appBar_title => 'صور الرحلة';

  @override
  String trips_gallery_diveSection_photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'صور',
      one: 'صورة',
    );
    return '$_temp0';
  }

  @override
  String trips_gallery_diveSection_title(Object number, Object site) {
    return 'غوصة #$number - $site';
  }

  @override
  String get trips_gallery_empty_subtitle =>
      'انقر على أيقونة الكاميرا لمسح معرض الصور';

  @override
  String get trips_gallery_empty_title => 'لا توجد صور في هذه الرحلة';

  @override
  String trips_gallery_errorLinking(Object error) {
    return 'خطأ في ربط الصور: $error';
  }

  @override
  String trips_gallery_errorScanning(Object error) {
    return 'خطأ في المسح: $error';
  }

  @override
  String trips_gallery_error_loading(Object error) {
    return 'خطأ في تحميل الصور: $error';
  }

  @override
  String trips_gallery_linkedPhotos(Object count) {
    return 'تم ربط $count صور';
  }

  @override
  String get trips_gallery_linkingPhotos => 'جارٍ ربط الصور...';

  @override
  String get trips_gallery_tooltip_scan => 'مسح معرض الجهاز';

  @override
  String get trips_gallery_tripNotFound => 'الرحلة غير موجودة';

  @override
  String get trips_list_button_retry => 'إعادة المحاولة';

  @override
  String trips_list_countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'خلال $days أيام',
      one: 'خلال يوم واحد',
      zero: 'يبدأ اليوم',
    );
    return '$_temp0';
  }

  @override
  String get trips_list_empty_button => 'أضف رحلتك الأولى';

  @override
  String get trips_list_empty_filtered_subtitle =>
      'حاول تعديل أو مسح عوامل التصفية';

  @override
  String get trips_list_empty_filtered_title =>
      'لا توجد رحلات تطابق عوامل التصفية';

  @override
  String get trips_list_empty_subtitle => 'أنشئ رحلات لتجميع غوصاتك حسب الوجهة';

  @override
  String get trips_list_empty_title => 'لم تتم إضافة رحلات بعد';

  @override
  String trips_list_error_loading(Object error) {
    return 'خطأ في تحميل الرحلات: $error';
  }

  @override
  String get trips_list_fab_addTrip => 'إضافة رحلة';

  @override
  String get trips_list_filters_clearAll => 'مسح الكل';

  @override
  String get trips_list_inProgress => 'جارية';

  @override
  String get trips_list_pastSection => 'الرحلات السابقة';

  @override
  String get trips_list_sort_title => 'ترتيب الرحلات';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count غوصات';
  }

  @override
  String get trips_list_tooltip_addTrip => 'إضافة رحلة';

  @override
  String get trips_list_tooltip_search => 'البحث في الرحلات';

  @override
  String get trips_list_tooltip_sort => 'ترتيب';

  @override
  String get trips_list_upcomingSection => 'القادمة';

  @override
  String get trips_photos_empty_scanButton => 'مسح معرض الجهاز';

  @override
  String get trips_photos_empty_title => 'لا توجد صور بعد';

  @override
  String get trips_photos_error_loading => 'خطأ في تحميل الصور';

  @override
  String trips_photos_moreIndicator(Object count) {
    return '+$count';
  }

  @override
  String trips_photos_moreIndicator_semanticLabel(Object count) {
    return '$count صور إضافية';
  }

  @override
  String get trips_photos_sectionTitle => 'الصور';

  @override
  String get trips_photos_tooltip_scan => 'مسح معرض الجهاز';

  @override
  String get trips_photos_viewAll => 'عرض الكل';

  @override
  String get trips_picker_clearTooltip => 'مسح الاختيار';

  @override
  String get trips_picker_empty_createButton => 'إنشاء رحلة';

  @override
  String get trips_picker_empty_title => 'لا توجد رحلات بعد';

  @override
  String trips_picker_error(Object error) {
    return 'خطأ في تحميل الرحلات: $error';
  }

  @override
  String get trips_picker_hint => 'انقر لاختيار رحلة';

  @override
  String get trips_picker_newTrip => 'رحلة جديدة';

  @override
  String get trips_picker_noSelection => 'لم يتم اختيار رحلة';

  @override
  String get trips_picker_sheetTitle => 'اختيار رحلة';

  @override
  String trips_picker_suggestedPrefix(Object name) {
    return 'مقترح: $name';
  }

  @override
  String get trips_picker_suggestedUse => 'استخدام';

  @override
  String get trips_search_empty_hint => 'البحث بالاسم أو الموقع أو المنتجع';

  @override
  String get trips_search_fieldLabel => 'البحث في الرحلات...';

  @override
  String trips_search_noResults(Object query) {
    return 'لم يتم العثور على رحلات لـ \"$query\"';
  }

  @override
  String get trips_search_tooltip_back => 'رجوع';

  @override
  String get trips_search_tooltip_clear => 'مسح البحث';

  @override
  String get trips_summary_header_subtitle =>
      'اختر رحلة من القائمة لعرض التفاصيل';

  @override
  String get trips_summary_header_title => 'الرحلات';

  @override
  String get trips_summary_overview_title => 'نظرة عامة';

  @override
  String get trips_summary_quickActions_add => 'إضافة رحلة';

  @override
  String get trips_summary_quickActions_title => 'إجراءات سريعة';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date • $count غوصات';
  }

  @override
  String get trips_summary_recentTitle => 'الرحلات الأخيرة';

  @override
  String get trips_summary_stat_daysDiving => 'أيام الغوص';

  @override
  String get trips_summary_stat_liveaboards => 'سفن الغوص';

  @override
  String get trips_summary_stat_totalDives => 'إجمالي الغوصات';

  @override
  String get trips_summary_stat_totalTrips => 'إجمالي الرحلات';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date • بعد $days أيام';
  }

  @override
  String get trips_summary_upcomingTitle => 'القادمة';

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
  String get units_sac_pressurePerMin => 'ضغط/min';

  @override
  String get units_temperature_celsius => 'C';

  @override
  String get units_temperature_fahrenheit => 'F';

  @override
  String get units_timeFormat_twelveHour => '12 ساعة';

  @override
  String get units_timeFormat_twentyFourHour => '24 ساعة';

  @override
  String get units_volume_cubicFeet => 'cuft';

  @override
  String get units_volume_liters => 'L';

  @override
  String get units_weight_kilograms => 'kg';

  @override
  String get units_weight_pounds => 'lbs';

  @override
  String get universalImport_action_consolidate => 'دمج كقراءة كمبيوتر إضافية';

  @override
  String get universalImport_action_continue => 'متابعة';

  @override
  String get universalImport_action_deselectAll => 'إلغاء تحديد الكل';

  @override
  String get universalImport_action_done => 'تم';

  @override
  String get universalImport_action_import => 'استيراد';

  @override
  String get universalImport_action_selectAll => 'تحديد الكل';

  @override
  String get universalImport_action_changeFile => 'تغيير الملف';

  @override
  String get universalImport_action_selectFile => 'اختيار ملف';

  @override
  String get universalImport_action_selectFiles => 'تحديد الملفات';

  @override
  String get universalImport_action_chooseFolder => 'اختيار مجلد';

  @override
  String get universalImport_triage_title => 'الملفات المراد استيرادها';

  @override
  String universalImport_triage_readyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملفات جاهزة للاستيراد',
      one: 'ملف واحد جاهز للاستيراد',
    );
    return '$_temp0';
  }

  @override
  String universalImport_label_filesSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديد $count ملفات',
      one: 'تم تحديد ملف واحد',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_triage_excludedCsv => 'استيراد فردي (CSV)';

  @override
  String get universalImport_triage_unsupported => 'تنسيق غير مدعوم';

  @override
  String get universalImport_triage_parseFailed => 'تعذرت القراءة';

  @override
  String universalImport_triage_parsing(int current, int total) {
    return 'جارٍ تحليل الملف $current من $total…';
  }

  @override
  String get universalImport_triage_cancelParsing => 'إلغاء';

  @override
  String get universalImport_triage_allExcluded =>
      'لا يمكن استيراد الملفات المحددة معًا. يجب استيراد ملفات CSV واحدًا تلو الآخر.';

  @override
  String get universalImport_triage_noneImportable =>
      'لا يمكن استيراد أي من الملفات المحددة.';

  @override
  String get universalImport_review_inBatchDuplicate =>
      'نسخة مكررة من غطسة أخرى في دفعة الاستيراد هذه.';

  @override
  String get universalImport_summary_filesTitle => 'الملفات';

  @override
  String get universalImport_summary_noticesTitle => 'غير موجود في الملف';

  @override
  String get universalImport_summary_noticeNoTankPressureTitle =>
      'لم يتم تسجيل ضغط الأسطوانة';

  @override
  String get universalImport_summary_noticeNoTankPressureBody =>
      'لا يمكن حساب استهلاك الهواء و SAC. يمكنك إضافة ضغط البداية والنهاية بتعديل الغطسة.';

  @override
  String universalImport_summary_noticeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يؤثر على $count غطسات',
      one: 'يؤثر على غطسة واحدة',
    );
    return '$_temp0';
  }

  @override
  String universalImport_summary_fileImported(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم استيراد $count غطسات',
      one: 'تم استيراد غطسة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_summary_fileNeedsIndividualImport =>
      'يتطلب استيرادًا فرديًا';

  @override
  String get universalImport_summary_fileUnsupported => 'تنسيق غير مدعوم';

  @override
  String get universalImport_summary_fileParseFailed => 'فشلت القراءة';

  @override
  String universalImport_bulk_consolidateMatched(int count) {
    return 'دمج المتطابقة ($count)';
  }

  @override
  String universalImport_bulk_importAll(int count) {
    return 'استيراد الكل ($count)';
  }

  @override
  String universalImport_bulk_importAllAsNew(int count) {
    return 'استيراد الكل كجديد ($count)';
  }

  @override
  String universalImport_bulk_skipAll(int count) {
    return 'تخطي الكل ($count)';
  }

  @override
  String universalImport_bulk_replaceSourceAll(int count) {
    return 'استبدال الكل ($count)';
  }

  @override
  String get universalImport_description_supportedFormats =>
      'اختر ملف سجل غوص للاستيراد. الصيغ المدعومة تشمل CSV وUDDF وSubsurface XML وGarmin FIT.';

  @override
  String get universalImport_dive_decideAction => 'قرر';

  @override
  String get universalImport_error_unsupportedFormat =>
      'هذه الصيغة غير مدعومة بعد. يرجى التصدير كـ UDDF أو CSV.';

  @override
  String get universalImport_label_columnMapping => 'تعيين الأعمدة';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped من $total أعمدة معينة';
  }

  @override
  String get universalImport_label_consolidate => 'دمج';

  @override
  String get universalImport_label_detecting => 'جارٍ الكشف...';

  @override
  String universalImport_label_diveNumber(Object number) {
    return 'غطسة #$number';
  }

  @override
  String get universalImport_label_duplicate => 'مكرر';

  @override
  String universalImport_label_duplicatesFound(Object count) {
    return 'تم العثور على $count مكررات وتم إلغاء تحديدها تلقائياً.';
  }

  @override
  String get universalImport_label_importAsNew => 'استيراد كجديد';

  @override
  String get universalImport_label_importComplete => 'اكتمل الاستيراد';

  @override
  String get universalImport_label_importing => 'جارٍ الاستيراد';

  @override
  String get universalImport_label_importingEllipsis => 'جارٍ الاستيراد...';

  @override
  String universalImport_label_importingProgress(Object current, Object total) {
    return 'جارٍ استيراد $current من $total';
  }

  @override
  String universalImport_label_percentMatch(Object percent) {
    return '$percent% تطابق';
  }

  @override
  String get universalImport_label_possibleMatch => 'تطابق محتمل';

  @override
  String get universalImport_label_selectCorrectSource =>
      'ليس صحيحاً؟ اختر المصدر الصحيح:';

  @override
  String universalImport_label_selected(Object count) {
    return '$count محدد';
  }

  @override
  String get universalImport_label_skip => 'تخطي';

  @override
  String universalImport_label_taggedAs(Object tag) {
    return 'موسوم كـ: $tag';
  }

  @override
  String get universalImport_label_unknownDate => 'تاريخ غير معروف';

  @override
  String get universalImport_label_unnamed => 'بدون اسم';

  @override
  String universalImport_label_xOfY(Object current, Object total) {
    return '$current من $total';
  }

  @override
  String universalImport_label_xOfYSelected(Object selected, Object total) {
    return '$selected من $total محدد';
  }

  @override
  String get universalImport_entityAction_linkBadge => 'ربط';

  @override
  String get universalImport_entityAction_linkExisting => 'الربط بالموجود';

  @override
  String get universalImport_entityAction_linkExistingSubtitle =>
      'استخدام السجل المطابق';

  @override
  String get universalImport_entityAction_replaceBadge => 'استبدال';

  @override
  String get universalImport_entityAction_replaceExisting => 'استبدال الحالي';

  @override
  String get universalImport_entityAction_replaceExistingSubtitle =>
      'الكتابة فوقه بالبيانات المستوردة';

  @override
  String get universalImport_entityAction_skip => 'تخطي';

  @override
  String get universalImport_entityAction_skipSubtitle => 'تجاهل هذا الاستيراد';

  @override
  String get universalImport_entityAction_importAsNew => 'استيراد كجديد';

  @override
  String get universalImport_entityAction_importAsNewSubtitle =>
      'إنشاء إدخال منفصل';

  @override
  String get universalImport_pending_chooseAction => 'اختر إجراء';

  @override
  String universalImport_pending_gateHint(int count) {
    return '$count نسخة مكررة تحتاج إلى قرار';
  }

  @override
  String get universalImport_pending_needsDecision => 'يتطلب قرارا';

  @override
  String get universalImport_pending_reviewAction => 'مراجعة';

  @override
  String get universalImport_rowHint_tapCompareToDecide =>
      'اضغط على قرر للاختيار';

  @override
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  ) {
    return '$selected من $total $entityType محدد';
  }

  @override
  String universalImport_semantics_importError(Object error) {
    return 'خطأ في الاستيراد: $error';
  }

  @override
  String universalImport_semantics_importProgress(Object percent) {
    return 'تقدم الاستيراد: $percent بالمئة';
  }

  @override
  String universalImport_semantics_itemsSelected(Object count) {
    return '$count عناصر محددة للاستيراد';
  }

  @override
  String get universalImport_semantics_needsDecision =>
      'نسخة مكررة محتملة، يتطلب قرارا';

  @override
  String get universalImport_semantics_possibleDuplicate => 'مكرر محتمل';

  @override
  String get universalImport_semantics_probableDuplicate => 'مكرر مرجح';

  @override
  String universalImport_semantics_sourceDetected(Object description) {
    return 'تم كشف المصدر: $description';
  }

  @override
  String universalImport_semantics_sourceUncertain(Object description) {
    return 'المصدر غير مؤكد: $description';
  }

  @override
  String universalImport_semantics_toggleSelection(Object name) {
    return 'تبديل التحديد لـ $name';
  }

  @override
  String universalImport_snackbar_bulkMarkedAs(int count, String action) {
    return 'تم تحديد $count بـ $action';
  }

  @override
  String universalImport_snackbar_markedAs(String action) {
    return 'تم التحديد بـ $action';
  }

  @override
  String get universalImport_step_import => 'استيراد';

  @override
  String get universalImport_step_map => 'تعيين';

  @override
  String get universalImport_step_review => 'مراجعة';

  @override
  String get universalImport_step_select => 'اختيار';

  @override
  String get universalImport_summary_decidesRequired =>
      'يحتاج كل منها إلى قرار قبل الاستيراد.';

  @override
  String get universalImport_title => 'استيراد البيانات';

  @override
  String get universalImport_tooltip_closeWizard => 'إغلاق معالج الاستيراد';

  @override
  String weather_windFromDirection(Object wind, Object direction) {
    return '$wind من $direction';
  }

  @override
  String get weather_wind_calm => 'هدوء';

  @override
  String get weather_wind_highWind => 'رياح قوية';

  @override
  String get weather_wind_lightBreeze => 'نسيم خفيف';

  @override
  String get weather_wind_moderateBreeze => 'نسيم معتدل';

  @override
  String get weather_wind_strongBreeze => 'نسيم شديد';

  @override
  String get weather_wmo_clear => 'سماء صافية';

  @override
  String get weather_wmo_drizzle => 'رذاذ';

  @override
  String get weather_wmo_fog => 'ضباب';

  @override
  String get weather_wmo_freezingDrizzle => 'رذاذ متجمد';

  @override
  String get weather_wmo_freezingRain => 'مطر متجمد';

  @override
  String get weather_wmo_mainlyClear => 'صافية غالبًا';

  @override
  String get weather_wmo_overcast => 'غائم كليًا';

  @override
  String get weather_wmo_partlyCloudy => 'غائم جزئيًا';

  @override
  String get weather_wmo_rain => 'مطر';

  @override
  String get weather_wmo_rainShowers => 'زخات مطر';

  @override
  String get weather_wmo_snow => 'ثلج';

  @override
  String get weather_wmo_snowGrains => 'حبيبات ثلج';

  @override
  String get weather_wmo_snowShowers => 'زخات ثلج';

  @override
  String get weather_wmo_thunderstorm => 'عاصفة رعدية';

  @override
  String get weather_wmo_thunderstormHail => 'عاصفة رعدية مع برد';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return 'الأساس ($suitType): $weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return 'تعديل وزن الجسم: +$adjustment kg';
  }

  @override
  String get weightCalc_suit_drysuit => 'بدلة جافة';

  @override
  String get weightCalc_suit_none => 'بدون بدلة';

  @override
  String get weightCalc_suit_rashguard => 'قميص حماية فقط';

  @override
  String get weightCalc_suit_semidry => 'بدلة شبه جافة';

  @override
  String get weightCalc_suit_shorty3mm => 'بدلة قصيرة 3mm';

  @override
  String get weightCalc_suit_wetsuit3mm => 'بدلة غوص كاملة 3mm';

  @override
  String get weightCalc_suit_wetsuit5mm => 'بدلة غوص 5mm';

  @override
  String get weightCalc_suit_wetsuit7mm => 'بدلة غوص 7mm';

  @override
  String weightCalc_tankLine(Object tankMaterial, Object adjustment) {
    return 'الأسطوانة ($tankMaterial): $adjustment kg';
  }

  @override
  String get weightCalc_title => 'حساب الأثقال:';

  @override
  String weightCalc_total(Object total) {
    return 'الإجمالي: $total kg';
  }

  @override
  String weightCalc_waterLine(Object waterType, Object adjustment) {
    return 'المياه ($waterType): $adjustment kg';
  }

  @override
  String divePlanner_label_resultsWithWarnings(Object count) {
    return 'النتائج، $count تحذير';
  }

  @override
  String tides_semantic_tideCycle(Object state, Object height) {
    return 'دورة المد والجزر، الحالة: $state، الارتفاع: $height';
  }

  @override
  String get tides_label_agoSuffix => 'مضت';

  @override
  String get tides_label_fromNowSuffix => 'من الآن';

  @override
  String get certifications_card_issued => 'صادرة';

  @override
  String certifications_certificate_cardNumber(Object number) {
    return 'رقم البطاقة: $number';
  }

  @override
  String get certifications_certificate_footer => 'شهادة غوص رسمية';

  @override
  String get certifications_certificate_hasCompletedTraining =>
      'قد أتم التدريب بصفة';

  @override
  String certifications_certificate_instructor(Object name) {
    return 'المدرب: $name';
  }

  @override
  String certifications_certificate_issued(Object date) {
    return 'تاريخ الإصدار: $date';
  }

  @override
  String get certifications_certificate_thisCertifies => 'يشهد هذا بأن';

  @override
  String get diveComputer_connectionType_ble => 'Bluetooth LE';

  @override
  String get diveComputer_connectionType_bluetooth => 'Bluetooth';

  @override
  String get diveComputer_connectionType_infrared => 'الأشعة تحت الحمراء';

  @override
  String get diveComputer_connectionType_unknown => 'غير معروف';

  @override
  String get diveComputer_connectionType_usb => 'USB';

  @override
  String get diveComputer_connectionType_wifi => 'Wi-Fi';

  @override
  String diveComputer_detail_deleteDialogContent(String name) {
    return 'هل تريد حقا إزالة \"$name\"؟ لن يؤدي هذا إلى حذف أي غطسات تم استيرادها من هذا الكمبيوتر.';
  }

  @override
  String get diveComputer_detail_deleteDialogTitle => 'حذف الكمبيوتر؟';

  @override
  String get diveComputer_detail_divesImported => 'الغطسات المستوردة';

  @override
  String get diveComputer_detail_downloadDivesButton => 'تنزيل الغطسات';

  @override
  String get diveComputer_detail_editDialogTitle => 'تعديل الكمبيوتر';

  @override
  String get diveComputer_detail_editNameHint => 'مثال: Perdix الخاص بي';

  @override
  String get diveComputer_detail_editNotesHint => 'ملاحظات اختيارية';

  @override
  String get diveComputer_detail_labelConnection => 'الاتصال';

  @override
  String get diveComputer_detail_labelManufacturer => 'الشركة المصنعة';

  @override
  String get diveComputer_detail_labelModel => 'الطراز';

  @override
  String get diveComputer_detail_labelName => 'الاسم';

  @override
  String get diveComputer_detail_lastDownload => 'آخر تنزيل';

  @override
  String get diveComputer_detail_notesTitle => 'الملاحظات';

  @override
  String get diveComputer_detail_reimportAllButton =>
      'إعادة استيراد جميع الغطسات';

  @override
  String diveComputer_detail_reimportDialogBody(String computerName) {
    return 'تنزيل كل غطسة من $computerName ومراجعتها مقارنة بسجلك. قد يستغرق هذا عدة دقائق.';
  }

  @override
  String get diveComputer_detail_reimportDialogTitle =>
      'إعادة استيراد جميع الغطسات؟';

  @override
  String get diveComputer_detail_statisticsTitle => 'الإحصائيات';

  @override
  String get diveComputer_detail_unknown => 'غير معروف';

  @override
  String get diveComputer_detail_viewDivesButton =>
      'عرض الغطسات من هذا الكمبيوتر';

  @override
  String get diveComputer_discovery_chooseDifferentDevice => 'اختيار جهاز آخر';

  @override
  String get diveComputer_discovery_computer => 'كمبيوتر';

  @override
  String get diveComputer_discovery_connectAndDownload => 'اتصال وتنزيل';

  @override
  String get diveComputer_discovery_connectingToDevice =>
      'جارٍ الاتصال بالجهاز...';

  @override
  String diveComputer_discovery_deviceNameHint(Object model) {
    return 'مثال: $model الخاص بي';
  }

  @override
  String get diveComputer_discovery_deviceNameLabel => 'اسم الجهاز';

  @override
  String get diveComputer_discovery_exitDialogCancel => 'إلغاء';

  @override
  String get diveComputer_discovery_exitDialogConfirm => 'خروج';

  @override
  String get diveComputer_discovery_exitDialogContent =>
      'هل أنت متأكد من الخروج؟ سيتم فقدان تقدمك.';

  @override
  String get diveComputer_discovery_exitDialogTitle => 'الخروج من الإعداد؟';

  @override
  String get diveComputer_discovery_exitTooltip => 'الخروج من الإعداد';

  @override
  String get diveComputer_discovery_noDeviceSelected => 'لم يتم اختيار جهاز';

  @override
  String get diveComputer_discovery_pleaseWaitConnection =>
      'يرجى الانتظار أثناء إنشاء الاتصال';

  @override
  String get diveComputer_discovery_recognizedDevice => 'جهاز معروف';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      'هذا الجهاز موجود في مكتبة الأجهزة المدعومة. يجب أن يعمل تنزيل الغطسات تلقائيًا.';

  @override
  String get diveComputer_discovery_stepConnect => 'اتصال';

  @override
  String get diveComputer_discovery_stepDone => 'تم';

  @override
  String get diveComputer_discovery_stepDownload => 'تنزيل';

  @override
  String get diveComputer_discovery_stepScan => 'بحث';

  @override
  String get diveComputer_discovery_titleComplete => 'اكتمل';

  @override
  String get diveComputer_discovery_titleConfirmDevice => 'تأكيد الجهاز';

  @override
  String get diveComputer_discovery_titleConnecting => 'جارٍ الاتصال';

  @override
  String get diveComputer_discovery_titleDownloading => 'جارٍ التنزيل';

  @override
  String get diveComputer_discovery_titleFindDevice => 'البحث عن جهاز';

  @override
  String get diveComputer_discovery_unknownDevice => 'جهاز غير معروف';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      'هذا الجهاز غير موجود في مكتبتنا. سنحاول الاتصال، لكن التنزيل قد لا يعمل.';

  @override
  String get diveComputer_discovery_usbInstructions =>
      'قم بتوصيل حاسوب الغوص عبر كابل USB، ثم اختره أدناه.';

  @override
  String diveComputer_discovery_usbNoResults(String query) {
    return 'لا توجد أجهزة مطابقة لـ \"$query\"';
  }

  @override
  String get diveComputer_discovery_usbSearchHint =>
      'البحث حسب الشركة المصنعة أو الطراز...';

  @override
  String get diveComputer_downloadExit_content =>
      'سيؤدي المغادرة إلى إلغاء التنزيل الحالي من كمبيوتر الغوص. هل أنت متأكد؟';

  @override
  String get diveComputer_downloadExit_leave => 'مغادرة';

  @override
  String get diveComputer_downloadExit_stay => 'البقاء';

  @override
  String get diveComputer_downloadExit_title => 'التنزيل قيد التقدم';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... و$count أخرى';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'إلغاء';

  @override
  String get diveComputer_downloadStep_cancelled => 'تم إلغاء التنزيل';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadAll => 'تنزيل جميع الغطسات';

  @override
  String get diveComputer_downloadStep_downloadFailed => 'فشل التنزيل';

  @override
  String get diveComputer_downloadStep_downloadNew => 'تنزيل الغطسات الجديدة';

  @override
  String get diveComputer_downloadStep_downloadedDives => 'الغطسات المنزّلة';

  @override
  String diveComputer_downloadStep_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_downloadStep_errorOccurred => 'حدث خطأ';

  @override
  String diveComputer_downloadStep_errorSemanticLabel(Object error) {
    return 'خطأ في التنزيل: $error';
  }

  @override
  String get diveComputer_downloadStep_firstSyncBody =>
      'يحتوي سجل الغطسات الخاص بك بالفعل على غطسات. يمكنك تخطي تنزيل الغطسات التي لديك بالفعل.';

  @override
  String get diveComputer_downloadStep_firstSyncTitle =>
      'أول تنزيل من كمبيوتر الغوص هذا';

  @override
  String diveComputer_downloadStep_onlyAfterDate(String date) {
    return 'تنزيل الغطسات بعد $date فقط';
  }

  @override
  String diveComputer_downloadStep_percentAccessibility(Object percent) {
    return '، $percent بالمئة';
  }

  @override
  String get diveComputer_downloadStep_preparing => 'جارٍ التحضير...';

  @override
  String diveComputer_downloadStep_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String diveComputer_downloadStep_progressSemanticLabel(
    Object status,
    Object percent,
  ) {
    return 'تقدم التنزيل: $status$percent';
  }

  @override
  String get diveComputer_downloadStep_retry => 'إعادة المحاولة';

  @override
  String diveComputer_downloadStep_importPartialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استيراد $count غطسات تم تنزيلها',
      one: 'استيراد غطسة واحدة تم تنزيلها',
    );
    return '$_temp0';
  }

  @override
  String get diveComputer_download_cancel => 'إلغاء';

  @override
  String get diveComputer_download_closeTooltip => 'إغلاق';

  @override
  String get diveComputer_download_computerNotFound =>
      'لم يتم العثور على الكمبيوتر';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return 'لم يتم العثور على الجهاز. تأكد أن $name قريب وفي وضع النقل.';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle =>
      'لم يتم العثور على الجهاز';

  @override
  String get diveComputer_download_divesUpdated => 'تم تحديث الغطسات';

  @override
  String get diveComputer_download_done => 'تم';

  @override
  String get diveComputer_download_downloadedDives => 'الغطسات المنزّلة';

  @override
  String get diveComputer_download_duplicatesSkipped => 'تم تخطي المكررات';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_download_errorOccurred => 'حدث خطأ';

  @override
  String get diveComputer_download_noSerialPortsFound =>
      'لم يتم العثور على منافذ USB تسلسلية. هل حاسوب الغوص متصل وقيد التشغيل؟';

  @override
  String get diveComputer_download_stalePairing =>
      'إقران البلوتوث لكمبيوتر الغوص هذا لم يعد صالحًا. انسَ كمبيوتر الغوص من إعدادات البلوتوث في جهازك، ثم أعد إقرانه من قائمة البلوتوث في كمبيوتر الغوص.';

  @override
  String get diveComputer_download_discoveryStalled =>
      'تم الاتصال بكمبيوتر الغوص، لكنه توقف عن الاستجابة قبل بدء التنزيل. يعني هذا عادةً أن إقران البلوتوث لم يعد صالحًا: انسَ كمبيوتر الغوص من إعدادات البلوتوث في جهازك ثم حاول مرة أخرى.';

  @override
  String diveComputer_download_serialConnectFailedWithDetails(Object details) {
    return 'تعذر الاتصال بحاسوب الغوص.\n\nتفاصيل التشخيص (شاركها مع المطورين):\n$details';
  }

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get diveComputer_download_goBack => 'رجوع';

  @override
  String get diveComputer_download_importFailed => 'فشل الاستيراد';

  @override
  String get diveComputer_download_importResults => 'نتائج الاستيراد';

  @override
  String get diveComputer_download_importedDives => 'الغطسات المستوردة';

  @override
  String diveComputer_download_importingCountDives(int count) {
    return 'جارٍ استيراد $count غطسة...';
  }

  @override
  String diveComputer_download_importingCountNewDives(int count) {
    return 'جارٍ استيراد $count غطسة جديدة...';
  }

  @override
  String get diveComputer_download_newDivesImported => 'تم استيراد غطسات جديدة';

  @override
  String get diveComputer_download_newDivesOnlySubtitle =>
      'يتم تنزيل الغطسات المضافة منذ آخر مزامنة فقط';

  @override
  String get diveComputer_download_newDivesOnlyTitle =>
      'تنزيل الغطسات الجديدة فقط';

  @override
  String get diveComputer_download_preparing => 'جارٍ التحضير...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_reimportHint =>
      'تبحث عن غطسات قديمة أو محذوفة؟ إعادة استيراد الجميع';

  @override
  String get diveComputer_download_retry => 'إعادة المحاولة';

  @override
  String diveComputer_download_scanError(Object error) {
    return 'خطأ في البحث: $error';
  }

  @override
  String diveComputer_download_searchingForDevice(Object name) {
    return 'جارٍ البحث عن $name...';
  }

  @override
  String get diveComputer_download_searchingInstructions =>
      'تأكد أن الجهاز قريب وفي وضع النقل';

  @override
  String get diveComputer_download_title => 'تنزيل الغطسات';

  @override
  String get diveComputer_download_tryAgain => 'حاول مرة أخرى';

  @override
  String get diveComputer_download_upToDate =>
      'لم يتم العثور على غطسات جديدة -- سجلك محدّث';

  @override
  String get diveComputer_list_addComputer => 'إضافة كمبيوتر';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return 'كمبيوتر غوص: $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count غطسة';
  }

  @override
  String get diveComputer_list_downloadTooltip => 'تنزيل الغطسات';

  @override
  String get diveComputer_list_emptyMessage =>
      'قم بتوصيل كمبيوتر الغوص لتنزيل الغطسات مباشرة في التطبيق.';

  @override
  String get diveComputer_list_emptyTitle => 'لا توجد كمبيوترات غوص';

  @override
  String get diveComputer_list_findComputers => 'البحث عن كمبيوترات';

  @override
  String get diveComputer_list_helpBluetooth =>
      'Bluetooth LE (معظم الأجهزة الحديثة) •';

  @override
  String get diveComputer_list_helpBluetoothClassic =>
      'Bluetooth Classic (الموديلات القديمة) •';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater، Suunto، Garmin، Mares، Scubapro، Oceanic، Aqualung، Cressi، وأكثر من 50 موديلًا آخر.';

  @override
  String get diveComputer_list_helpBrandsTitle => 'العلامات التجارية المدعومة';

  @override
  String get diveComputer_list_helpConnectionsTitle => 'الاتصالات المدعومة';

  @override
  String get diveComputer_list_helpDialogTitle => 'مساعدة كمبيوتر الغوص';

  @override
  String get diveComputer_list_helpDismiss => 'حسنًا';

  @override
  String get diveComputer_list_helpTip1 => 'تأكد أن الكمبيوتر في وضع النقل •';

  @override
  String get diveComputer_list_helpTip2 => 'أبقِ الأجهزة قريبة أثناء التنزيل •';

  @override
  String get diveComputer_list_helpTip3 => 'تأكد من تفعيل البلوتوث •';

  @override
  String get diveComputer_list_helpTipsTitle => 'نصائح';

  @override
  String get diveComputer_list_helpTooltip => 'مساعدة';

  @override
  String get diveComputer_list_helpUsb => 'USB (سطح المكتب فقط) •';

  @override
  String get diveComputer_list_loadFailed => 'فشل تحميل كمبيوترات الغوص';

  @override
  String get diveComputer_list_retry => 'إعادة المحاولة';

  @override
  String get diveComputer_list_title => 'كمبيوترات الغوص';

  @override
  String get diveComputer_pinCode_instructions =>
      'أدخل الرمز المعروض على كمبيوتر الغوص.';

  @override
  String get diveComputer_pinCode_label => 'رمز PIN';

  @override
  String get diveComputer_pinCode_submit => 'إرسال';

  @override
  String get diveComputer_pinCode_title => 'رمز PIN مطلوب';

  @override
  String get diveComputer_pinEntry_connectButton => 'اتصال';

  @override
  String get diveComputer_pinEntry_helperText =>
      'أدخل رمز PIN المكون من 4 إلى 6 أرقام المعروض على جهازك';

  @override
  String get diveComputer_pinEntry_instructionsGeneric =>
      'تحقق من شاشة كمبيوتر الغوص لرؤية رمز PIN.';

  @override
  String diveComputer_pinEntry_instructionsWithDevice(String deviceName) {
    return 'تحقق من شاشة $deviceName لرؤية رمز PIN.';
  }

  @override
  String get diveComputer_pinEntry_semanticLabel =>
      'إدخال رمز PIN، من 4 إلى 6 أرقام';

  @override
  String get diveComputer_pinEntry_title => 'أدخل رمز PIN';

  @override
  String diveComputer_scan_bluetoothSemanticLabel(String name) {
    return 'جهاز Bluetooth: $name';
  }

  @override
  String get diveComputer_scan_emptyStateInstructions =>
      'تأكد من أن كمبيوتر الغوص:\n• قيد التشغيل\n• في وضع إقران Bluetooth\n• قريب من جهازك';

  @override
  String get diveComputer_scan_knownBadge => 'معروف';

  @override
  String get diveComputer_scan_lookingForDevicesTitle => 'البحث عن الأجهزة';

  @override
  String get diveComputer_scan_noUsbDevicesAvailable =>
      'لا توجد أجهزة USB متاحة';

  @override
  String get diveComputer_scan_retry => 'إعادة المحاولة';

  @override
  String get diveComputer_scan_scanAgain => 'مسح مرة أخرى';

  @override
  String get diveComputer_scan_scanningStatus =>
      'البحث عن أجهزة كمبيوتر الغوص...';

  @override
  String get diveComputer_scan_stopScanning => 'إيقاف المسح';

  @override
  String get diveComputer_scan_supportedBadge => 'مدعوم';

  @override
  String get diveComputer_scan_tabBluetooth => 'Bluetooth';

  @override
  String get diveComputer_scan_tabUsb => 'كابل USB';

  @override
  String get diveComputer_scan_usbCableLabel => 'كابل USB';

  @override
  String diveComputer_scan_usbSemanticLabel(String model) {
    return 'جهاز USB: $model';
  }

  @override
  String get diveComputer_summary_diveComputer => 'كمبيوتر غوص';

  @override
  String diveComputer_summary_divesDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غطسات تم تنزيلها',
      one: 'غطسة تم تنزيلها',
    );
    return '$count $_temp0';
  }

  @override
  String get diveComputer_summary_done => 'تم';

  @override
  String get diveComputer_summary_imported => 'مستوردة';

  @override
  String diveComputer_summary_semanticLabel(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غطسات تم تنزيلها',
      one: 'غطسة تم تنزيلها',
    );
    return '$count $_temp0 من $name';
  }

  @override
  String get diveComputer_summary_skippedDuplicates => 'تم تخطيها (مكررات)';

  @override
  String get diveComputer_summary_title => 'اكتمل التنزيل!';

  @override
  String get diveComputer_summary_updated => 'محدّثة';

  @override
  String get diveComputer_summary_viewDives => 'عرض الغطسات';

  @override
  String get diveImport_alreadyImported => 'تم استيرادها مسبقًا';

  @override
  String get diveImport_avgHR => 'متوسط معدل القلب';

  @override
  String get diveImport_back => 'رجوع';

  @override
  String get diveImport_deselectAll => 'إلغاء تحديد الكل';

  @override
  String get diveImport_divesImported => 'غطسات مستوردة';

  @override
  String get diveImport_divesMerged => 'غطسات مدمجة';

  @override
  String get diveImport_divesSkipped => 'غطسات تم تخطيها';

  @override
  String get diveImport_done => 'تم';

  @override
  String get diveImport_duration => 'المدة';

  @override
  String get diveImport_error => 'خطأ';

  @override
  String get diveImport_fit_closeTooltip => 'إغلاق استيراد FIT';

  @override
  String get diveImport_fit_noDivesDescription =>
      'اختر ملفات .fit مصدّرة من Garmin Connect أو منسوخة من جهاز Garmin Descent.';

  @override
  String get diveImport_fit_noDivesLoaded => 'لم يتم تحميل غطسات';

  @override
  String diveImport_fit_parsed(int diveCount, int fileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'غطسات',
      one: 'غطسة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'ملفات',
      one: 'ملف',
    );
    return 'تم تحليل $diveCount $_temp0 من $fileCount $_temp1';
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
      other: 'غطسات',
      one: 'غطسة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'ملفات',
      one: 'ملف',
    );
    return 'تم تحليل $diveCount $_temp0 من $fileCount $_temp1 (تم تخطي $skippedCount)';
  }

  @override
  String get diveImport_fit_parsing => 'جارٍ التحليل...';

  @override
  String get diveImport_fit_selectFiles => 'اختيار ملفات FIT';

  @override
  String get diveImport_fit_title => 'استيراد من ملف FIT';

  @override
  String get diveImport_healthkit_accessDescription =>
      'Submersion uses Apple HealthKit to read underwater diving workout data, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get diveImport_healthkit_accessRequired => 'Apple HealthKit';

  @override
  String get diveImport_healthkit_attribution => 'مدعوم من Apple HealthKit';

  @override
  String get diveImport_healthkit_closeTooltip => 'إغلاق استيراد Apple Watch';

  @override
  String get diveImport_healthkit_dataUsage =>
      'يقرأ أنشطة الغوص تحت الماء من Apple Health، بما في ذلك العمق والمدة ودرجة حرارة الماء ومعدل ضربات القلب. يتم تخزين هذه البيانات محليا في سجل الغوص الخاص بك ولا تتم مشاركتها مع أطراف ثالثة.';

  @override
  String get diveImport_healthkit_dateFrom => 'من';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return 'محدد تاريخ $label';
  }

  @override
  String get diveImport_healthkit_dateTo => 'إلى';

  @override
  String get diveImport_healthkit_fetchDives => 'جلب الغطسات';

  @override
  String get diveImport_healthkit_fetching => 'جارٍ الجلب...';

  @override
  String get diveImport_healthkit_grantAccess => 'متابعة';

  @override
  String get diveImport_healthkit_noDivesFound => 'لم يتم العثور على غطسات';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'لم يتم العثور على أنشطة غوص في النطاق الزمني المحدد.';

  @override
  String get diveImport_healthkit_notAvailable => 'غير متاح';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'يتطلب الاستيراد من Apple Watch جهاز iPhone مزوّدًا بتطبيق صحة.';

  @override
  String get diveImport_healthkit_permissionCheckFailed =>
      'فشل التحقق من الأذونات';

  @override
  String get diveImport_healthkit_title => 'استيراد من Apple Watch';

  @override
  String get diveImport_healthkit_watchTitle => 'استيراد من الساعة';

  @override
  String get diveImport_import => 'استيراد';

  @override
  String get diveImport_importComplete => 'اكتمل الاستيراد';

  @override
  String get diveImport_likelyDuplicate => 'مكرر مرجح';

  @override
  String get diveImport_maxDepth => 'أقصى عمق';

  @override
  String get diveImport_newDive => 'غطسة جديدة';

  @override
  String get diveImport_next => 'التالي';

  @override
  String get diveImport_possibleDuplicate => 'مكرر محتمل';

  @override
  String get diveImport_reviewSelectedDives => 'مراجعة الغطسات المحددة';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: '، $possibleCount مكررات محتملة',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: '، $skipCount سيتم تخطيها',
      zero: '',
    );
    return '$newCount جديدة$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => 'تحديد الكل';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count محدد';
  }

  @override
  String get diveImport_sourceGarmin => 'Garmin';

  @override
  String get diveImport_sourceSuunto => 'Suunto';

  @override
  String get diveImport_sourceUDDF => 'UDDF';

  @override
  String get diveImport_sourceWatch => 'ساعة';

  @override
  String get diveImport_step_done => 'تم';

  @override
  String get diveImport_step_review => 'مراجعة';

  @override
  String get diveImport_step_select => 'اختيار';

  @override
  String get diveImport_temp => 'الحرارة';

  @override
  String get diveImport_toggleDiveSelection => 'تبديل تحديد الغطسة';

  @override
  String get diveImport_uddf_buddies => 'رفاق الغوص';

  @override
  String get diveImport_uddf_certifications => 'الشهادات';

  @override
  String get diveImport_uddf_closeTooltip => 'إغلاق استيراد UDDF';

  @override
  String get diveImport_uddf_diveCenters => 'مراكز الغوص';

  @override
  String get diveImport_uddf_diveTypes => 'أنواع الغوص';

  @override
  String get diveImport_uddf_dives => 'الغطسات';

  @override
  String get diveImport_uddf_duplicate => 'مكرر';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return 'تم العثور على $count مكررات وإلغاء تحديدها تلقائيًا.';
  }

  @override
  String get diveImport_uddf_equipment => 'المعدات';

  @override
  String get diveImport_uddf_equipmentSets => 'أطقم المعدات';

  @override
  String diveImport_uddf_importProgress(Object current, Object total) {
    return '$current من $total';
  }

  @override
  String get diveImport_uddf_importing => 'جارٍ الاستيراد...';

  @override
  String get diveImport_uddf_likelyDuplicate => 'مكرر مرجح';

  @override
  String get diveImport_uddf_noFileDescription =>
      'اختر ملف .uddf أو .xml مصدّر من تطبيق سجل غوص آخر.';

  @override
  String get diveImport_uddf_noFileSelected => 'لم يتم اختيار ملف';

  @override
  String get diveImport_uddf_parsing => 'جارٍ التحليل...';

  @override
  String get diveImport_uddf_possibleDuplicate => 'مكرر محتمل';

  @override
  String get diveImport_uddf_selectFile => 'اختيار ملف UDDF';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '$selected من $total محدد';
  }

  @override
  String get diveImport_uddf_sites => 'المواقع';

  @override
  String get diveImport_uddf_stepImport => 'استيراد';

  @override
  String get diveImport_uddf_tabBuddies => 'الرفاق';

  @override
  String get diveImport_uddf_tabCenters => 'المراكز';

  @override
  String get diveImport_uddf_tabCerts => 'الشهادات';

  @override
  String get diveImport_uddf_tabCourses => 'الدورات';

  @override
  String get diveImport_uddf_tabDives => 'الغطسات';

  @override
  String get diveImport_uddf_tabEquipment => 'المعدات';

  @override
  String get diveImport_uddf_tabSets => 'الأطقم';

  @override
  String get diveImport_uddf_tabSites => 'المواقع';

  @override
  String get diveImport_uddf_tabTags => 'الوسوم';

  @override
  String get diveImport_uddf_tabTrips => 'الرحلات';

  @override
  String get diveImport_uddf_tabTypes => 'الأنواع';

  @override
  String get diveImport_uddf_tags => 'الوسوم';

  @override
  String get diveImport_uddf_media => 'الصور';

  @override
  String get diveImport_uddf_title => 'استيراد من UDDF';

  @override
  String get diveImport_uddf_toggleDiveSelection => 'تبديل تحديد الغطسة';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return 'تبديل تحديد $name';
  }

  @override
  String get diveImport_uddf_trips => 'الرحلات';

  @override
  String get divePlanner_segmentEditor_addTitle => 'إضافة مقطع';

  @override
  String divePlanner_segmentEditor_ascentRate(Object unit) {
    return 'معدل الصعود ($unit/min)';
  }

  @override
  String divePlanner_segmentEditor_descentRate(Object unit) {
    return 'معدل النزول ($unit/min)';
  }

  @override
  String get divePlanner_segmentEditor_duration => 'المدة (min)';

  @override
  String get divePlanner_segmentEditor_editTitle => 'تعديل المقطع';

  @override
  String divePlanner_segmentEditor_endDepth(Object unit) {
    return 'عمق النهاية ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_gasSwitchTime => 'وقت تبديل الغاز';

  @override
  String get divePlanner_segmentEditor_segmentType => 'نوع المقطع';

  @override
  String divePlanner_segmentEditor_startDepth(Object unit) {
    return 'عمق البداية ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_tankGas => 'الأسطوانة / الغاز';

  @override
  String get divePlanner_segmentList_addSegment => 'إضافة مقطع';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return 'صعود $startDepth ← $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return 'قاع $depth لمدة $minutes min';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return 'تخفيف ضغط $depth لمدة $minutes min';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => 'حذف المقطع';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return 'نزول $startDepth ← $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => 'تعديل المقطع';

  @override
  String get divePlanner_segmentList_emptyMessage =>
      'أضف مقاطع يدويًا أو أنشئ خطة سريعة';

  @override
  String get divePlanner_segmentList_emptyTitle => 'لا توجد مقاطع بعد';

  @override
  String divePlanner_segmentList_gasSwitch(Object gasName) {
    return 'تبديل الغاز إلى $gasName';
  }

  @override
  String get divePlanner_segmentList_quickPlan => 'خطة سريعة';

  @override
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes) {
    return 'وقفة أمان $depth لمدة $minutes min';
  }

  @override
  String get divePlanner_segmentList_title => 'مقاطع الغطسة';

  @override
  String get divePlanner_segmentType_ascent => 'صعود';

  @override
  String get divePlanner_segmentType_bottomTime => 'وقت القاع';

  @override
  String get divePlanner_segmentType_decoStop => 'وقفة تخفيف ضغط';

  @override
  String get divePlanner_segmentType_descent => 'نزول';

  @override
  String get divePlanner_segmentType_gasSwitch => 'تبديل الغاز';

  @override
  String get divePlanner_segmentType_safetyStop => 'وقفة أمان';

  @override
  String get divePlanner_undo => 'تراجع';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'الحد الأدنى للغاز هو أقل احتياطي غاز للصعود الطارئ أثناء مشاركة الهواء مع رفيقك.\n\n- يستخدم معدلات RMV تحت الضغط (2-3 أضعاف المعدل الطبيعي)\n- يفترض أن كلا الغواصين على أسطوانة واحدة\n- يشمل وقفة الأمان عند تفعيلها\n\nقم بإنهاء الغطسة دائمًا قبل الوصول إلى الحد الأدنى!';

  @override
  String get gasCalculators_rockBottom_aboutTitle => 'حول الحد الأدنى للغاز';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired =>
      'الغاز المطلوب للصعود';

  @override
  String get gasCalculators_rockBottom_ascentRate => 'معدل الصعود';

  @override
  String gasCalculators_rockBottom_ascentTimeToDepth(
    Object depth,
    Object unit,
  ) {
    return 'وقت الصعود إلى $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_ascentTimeToSurface =>
      'وقت الصعود إلى السطح';

  @override
  String get gasCalculators_rockBottom_buddySac => 'RMV الرفيق';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'RMV المشترك تحت الضغط';

  @override
  String get gasCalculators_rockBottom_emergencyAscentBreakdown =>
      'تفصيل الصعود الطارئ';

  @override
  String get gasCalculators_rockBottom_emergencyScenario => 'سيناريو الطوارئ';

  @override
  String get gasCalculators_rockBottom_includeSafetyStop => 'تضمين وقفة الأمان';

  @override
  String get gasCalculators_rockBottom_maximumDepth => 'أقصى عمق';

  @override
  String get gasCalculators_rockBottom_minimumReserve => 'الاحتياطي الأدنى';

  @override
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  ) {
    return 'الاحتياطي الأدنى: $pressure $pressureUnit، $volume $volumeUnit. أنهِ الغطسة عند وصول الضغط إلى $pressure $pressureUnit المتبقي';
  }

  @override
  String gasCalculators_rockBottom_safetyStopDuration(
    Object depth,
    Object unit,
  ) {
    return '3 دقائق عند $depth$unit';
  }

  @override
  String gasCalculators_rockBottom_safetyStopGas(Object depth, Object unit) {
    return 'غاز وقفة الأمان (3 min @ $depth$unit)';
  }

  @override
  String get gasCalculators_rockBottom_stressedSacHint =>
      'استخدم RMV أعلى لاحتساب الإجهاد أثناء الطوارئ';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'RMV تحت الضغط';

  @override
  String get gasCalculators_rockBottom_tankSize => 'حجم الأسطوانة';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded =>
      'إجمالي الاحتياطي المطلوب';

  @override
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  ) {
    return 'أنهِ الغطسة عند وصول الضغط إلى $pressure $pressureUnit المتبقي';
  }

  @override
  String get gasCalculators_rockBottom_yourSac => 'RMV الخاص بك';

  @override
  String get gpsLogger_androidNotificationText => 'يجري تسجيل مسار السطح';

  @override
  String get gpsLogger_androidNotificationTitle => 'مسجّل GPS في Submersion';

  @override
  String get gpsLogger_deleteTrackMessage =>
      'سيؤدي هذا إلى إزالة مسار GPS المسجّل. تبقى المواقع المسندة إلى الغطسات محفوظة.';

  @override
  String get gpsLogger_deleteTrackTitle => 'حذف المسار؟';

  @override
  String get gpsLogger_interruptedNotice =>
      'توقف تسجيل سابق قبل اكتماله. تم حفظ المسار.';

  @override
  String gpsLogger_lastFix(String age, String accuracy) {
    return 'آخر إشارة قبل $age ($accuracy)';
  }

  @override
  String get gpsLogger_locationOff => 'خدمات الموقع متوقفة.';

  @override
  String get gpsLogger_matchButton => 'مطابقة الغطسات مع سجلات GPS';

  @override
  String gpsLogger_matchResult(int count) {
    return 'تم تحديد موقع $count غطسة';
  }

  @override
  String get gpsLogger_matchResultNone => 'لا توجد غطسات تطابق مسارًا مسجّلًا';

  @override
  String get gpsLogger_noFixYet => 'في انتظار إشارة GPS';

  @override
  String get gpsLogger_noTracks => 'لا توجد مسارات GPS مسجّلة بعد';

  @override
  String get gpsLogger_permissionDenied =>
      'يلزم إذن الموقع لتسجيل مسار GPS. فعّله من إعدادات النظام.';

  @override
  String gpsLogger_recordingStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقطة',
      few: '$count نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
    );
    return 'جارٍ التسجيل - $_temp0';
  }

  @override
  String get gpsLogger_reviewSites => 'مراجعة مطابقات مواقع الغطس';

  @override
  String get gpsLogger_startButton => 'بدء التسجيل';

  @override
  String get gpsLogger_stopButton => 'إيقاف التسجيل';

  @override
  String gpsLogger_stripStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقطة',
      few: '$count نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
    );
    return 'جارٍ تسجيل مسار GPS · $_temp0';
  }

  @override
  String get gpsLogger_summary_tracks => 'المسارات';

  @override
  String get gpsLogger_summary_recordedTime => 'الوقت المسجّل';

  @override
  String get gpsLogger_summary_divesCovered => 'الغطسات المغطاة';

  @override
  String gpsLogger_trackSubtitle(num count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقطة',
      few: '$count نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
    );
    return '$_temp0، $duration';
  }

  @override
  String gpsLogger_trackSubtitleTrimmed(String duration) {
    return 'مقتطع، $duration';
  }

  @override
  String get gpsLogger_tracksHeader => 'المسارات المسجّلة';

  @override
  String get gpsTrack_action_trim => 'اقتصاص...';

  @override
  String get gpsTrack_action_split => 'تقسيم...';

  @override
  String get gpsTrack_action_resetTrim => 'إلغاء الاقتصاص';

  @override
  String get gpsTrack_edit_applyTrim => 'تطبيق الاقتصاص';

  @override
  String get gpsTrack_edit_confirmSplit => 'قسّم هنا';

  @override
  String get gpsTrack_edit_splitWarning =>
      'ينشئ التقسيم مسارين ويحذف الأصل. لا يمكن التراجع عن ذلك.';

  @override
  String get gpsTrack_edit_cancel => 'إلغاء';

  @override
  String get gpsTrack_import_action => 'استيراد مسار...';

  @override
  String get gpsTrack_import_reviewTitle => 'مراجعة الاستيراد';

  @override
  String get gpsTrack_import_timezone => 'سُجّل في';

  @override
  String get gpsTrack_import_timezoneHint =>
      'الأوقات في الملف بتوقيت UTC. حدّد المنطقة الزمنية التي سُجّل فيها المسار ليتوافق مع غطساتك.';

  @override
  String get gpsTrack_import_duplicate =>
      'يبدو أن هذا نسخة مكررة من مسار موجود.';

  @override
  String get gpsTrack_import_confirm => 'استيراد';

  @override
  String get gpsTrack_import_csvMapping => 'طابق الأعمدة';

  @override
  String get gpsTrack_import_firstFix => 'أول نقطة';

  @override
  String gpsTrack_import_fixCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقطة',
      few: '$count نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
    );
    return '$_temp0';
  }

  @override
  String gpsTrack_import_failed(String reason) {
    return 'تعذّرت قراءة الملف: $reason';
  }

  @override
  String get gpsTrack_importError_unsupportedFormat =>
      'نوع الملف هذا غير مدعوم. قم باستيراد ملف GPX أو KML أو CSV أو FIT.';

  @override
  String get gpsTrack_importError_unreadable =>
      'تعذرت قراءة هذا الملف. قد يكون تالفًا أو غير مكتمل.';

  @override
  String get gpsTrack_importError_noPositions =>
      'لا يحتوي هذا الملف على مواقع GPS مؤرخة زمنيًا.';

  @override
  String get gpsTrack_importError_badData =>
      'يحتوي هذا الملف على موقع أو طابع زمني يتعذر على التطبيق قراءته.';

  @override
  String get gpsTrack_export_saved => 'تم حفظ المسار';

  @override
  String get gpsTrack_action_export => 'تصدير';

  @override
  String get gpsTrack_action_shareGpx => 'مشاركة كملف GPX';

  @override
  String get gpsTrack_action_saveGpx => 'حفظ كملف GPX...';

  @override
  String get gpsTrack_action_shareKml => 'مشاركة كملف KML';

  @override
  String get gpsTrack_action_saveKml => 'حفظ كملف KML...';

  @override
  String get gpsTrack_export_failed => 'فشل التصدير.';

  @override
  String get gpsTrack_map_title => 'خريطة المسارات';

  @override
  String gpsTrack_map_truncated(int count) {
    return 'يتم عرض أحدث $count مسار. قم بتضييق عامل تصفية التاريخ لعرض المسارات الأخرى.';
  }

  @override
  String get gpsTrack_map_noTracks => 'لا توجد مسارات مسجّلة لعرضها.';

  @override
  String get gpsTrack_map_showMap => 'عرض الخريطة';

  @override
  String get gpsTrack_filter_all => 'كل التواريخ';

  @override
  String get gpsTrack_filter_clear => 'مسح عامل تصفية التاريخ';

  @override
  String get gpsTrack_inspect_speed => 'السرعة';

  @override
  String get gpsTrack_inspect_accuracy => 'الدقة';

  @override
  String get gpsTrack_stats_distance => 'المسافة';

  @override
  String get gpsTrack_stats_duration => 'المدة';

  @override
  String get gpsTrack_stats_avgSpeed => 'متوسط السرعة';

  @override
  String get gpsTrack_stats_maxSpeed => 'أقصى سرعة';

  @override
  String get gpsTrack_stats_fixes => 'النقاط';

  @override
  String get gpsTrack_stats_dives => 'الغطسات';

  @override
  String get gpsTrack_colorMode_uniform => 'عادي';

  @override
  String get gpsTrack_colorMode_speed => 'السرعة';

  @override
  String get gpsTrack_colorMode_elapsed => 'الوقت';

  @override
  String get gpsTrack_legend_slower => 'أبطأ';

  @override
  String get gpsTrack_legend_faster => 'أسرع';

  @override
  String get gpsTrack_legend_start => 'البداية';

  @override
  String get gpsTrack_legend_end => 'النهاية';

  @override
  String get gpsTrack_detail_title => 'مسار GPS';

  @override
  String get gpsTrack_detail_notFound => 'هذا المسار لم يعد متاحًا.';

  @override
  String get gpsTrack_detail_unreadable => 'تعذّرت قراءة بيانات المسار.';

  @override
  String get gpsTrack_detail_noPoints =>
      'لا يحتوي هذا المسار على مواقع مسجّلة.';

  @override
  String get maps_compass_resetLabel => 'إعادة ضبط اتجاه الخريطة نحو الشمال';

  @override
  String get maps_compass_resetTooltip => 'الشمال للأعلى';

  @override
  String get maps_heatMap_hide => 'إخفاء خريطة الحرارة';

  @override
  String get maps_heatMap_overlayOff => 'طبقة خريطة الحرارة معطلة';

  @override
  String get maps_depthOverlay_show => 'إظهار طبقة العمق';

  @override
  String get maps_depthOverlay_hide => 'إخفاء طبقة العمق';

  @override
  String get maps_heatMap_overlayOn => 'طبقة خريطة الحرارة مفعلة';

  @override
  String get maps_heatMap_show => 'إظهار خريطة الحرارة';

  @override
  String get maps_offline_bounds => 'الحدود';

  @override
  String maps_offline_cacheHitRateAccessibility(Object rate) {
    return 'معدل إصابة التخزين المؤقت: $rate بالمئة';
  }

  @override
  String get maps_offline_cacheHits => 'إصابات التخزين المؤقت';

  @override
  String get maps_offline_cacheMisses => 'إخفاقات التخزين المؤقت';

  @override
  String get maps_offline_cacheStatistics => 'إحصائيات التخزين المؤقت';

  @override
  String get maps_offline_cancelDownload => 'إلغاء التنزيل';

  @override
  String get maps_offline_clearAll => 'مسح الكل';

  @override
  String get maps_offline_clearAllCache => 'مسح كل التخزين المؤقت';

  @override
  String get maps_offline_clearAllCacheMessage =>
      'حذف جميع مناطق الخرائط المنزّلة والبلاطات المخزنة مؤقتًا؟';

  @override
  String get maps_offline_clearAllCacheTitle => 'مسح كل التخزين المؤقت؟';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return 'سيتم حذف $count بلاطة ($size).';
  }

  @override
  String get maps_offline_created => 'تاريخ الإنشاء';

  @override
  String maps_offline_deleteRegion(Object name) {
    return 'حذف منطقة $name';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return 'حذف \"$name\" و$count بلاطة مخزنة مؤقتًا؟\n\nسيؤدي ذلك إلى تحرير $size من التخزين.';
  }

  @override
  String get maps_offline_deleteRegionTitle => 'حذف المنطقة؟';

  @override
  String get maps_offline_downloadNewRegion => 'تنزيل منطقة جديدة';

  @override
  String get maps_offline_downloadedRegions => 'المناطق المنزّلة';

  @override
  String maps_offline_downloading(Object regionName) {
    return 'جارٍ التنزيل: $regionName';
  }

  @override
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  ) {
    return 'جارٍ تنزيل $regionName، $percent بالمئة مكتمل، $downloaded من $total بلاطة';
  }

  @override
  String maps_offline_error(Object error) {
    return 'خطأ: $error';
  }

  @override
  String maps_offline_errorLoadingStats(Object error) {
    return 'خطأ في تحميل الإحصائيات: $error';
  }

  @override
  String maps_offline_failedTiles(Object count) {
    return '$count فشلت';
  }

  @override
  String maps_offline_hitRate(Object rate) {
    return 'معدل الإصابة: $rate%';
  }

  @override
  String get maps_offline_lastAccessed => 'آخر وصول';

  @override
  String get maps_offline_noRegions => 'لا توجد مناطق بدون اتصال';

  @override
  String get maps_offline_noRegionsDescription =>
      'نزّل مناطق الخرائط من صفحة تفاصيل الموقع لاستخدامها بدون اتصال.';

  @override
  String get maps_offline_refresh => 'تحديث';

  @override
  String get maps_offline_region => 'المنطقة';

  @override
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size | $count بلاطة | تكبير $minZoom-$maxZoom';
  }

  @override
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size، $count بلاطة، تكبير $minZoom إلى $maxZoom';
  }

  @override
  String get maps_offline_size => 'الحجم';

  @override
  String get maps_offline_tiles => 'البلاطات';

  @override
  String maps_offline_tilesPerSecond(Object rate) {
    return '$rate بلاطة/ثانية';
  }

  @override
  String maps_offline_tilesProgress(Object downloaded, Object total) {
    return '$downloaded / $total بلاطة';
  }

  @override
  String get maps_offline_title => 'الخرائط بدون اتصال';

  @override
  String get maps_offline_zoomRange => 'نطاق التكبير';

  @override
  String get maps_regionSelector_dragToAdjust => 'اسحب لضبط التحديد';

  @override
  String get maps_regionSelector_dragToSelect =>
      'اسحب على الخريطة لتحديد منطقة';

  @override
  String get maps_regionSelector_selectRegion => 'حدد منطقة على الخريطة';

  @override
  String get maps_regionSelector_selectRegionButton => 'تحديد المنطقة';

  @override
  String get tankPresets_addPreset => 'إضافة إعداد أسطوانة';

  @override
  String get tankPresets_builtInPresets => 'الإعدادات المدمجة';

  @override
  String get tankPresets_currentDefault => 'الافتراضي الحالي';

  @override
  String get tankPresets_customPresets => 'الإعدادات المخصصة';

  @override
  String get tankPresets_defaultSettings => 'الخزان الافتراضي';

  @override
  String get tankPresets_defaultSettings_description =>
      'يُستخدم الإعداد المميز بنجمة كخزان افتراضي عند تسجيل غطسات جديدة.';

  @override
  String tankPresets_deleteDefaultMessage(String name) {
    return 'هل أنت متأكد من حذف \"$name\"؟ هذا هو إعداد الخزان الافتراضي الحالي وسيتم إعادته إلى AL80.';
  }

  @override
  String tankPresets_deleteMessage(Object name) {
    return 'هل أنت متأكد من حذف \"$name\"؟';
  }

  @override
  String get tankPresets_deletePreset => 'حذف الإعداد';

  @override
  String get tankPresets_deleteTitle => 'حذف إعداد الأسطوانة؟';

  @override
  String tankPresets_deleted(Object name) {
    return 'تم حذف \"$name\"';
  }

  @override
  String get tankPresets_editPreset => 'تعديل الإعداد';

  @override
  String tankPresets_edit_created(Object name) {
    return 'تم إنشاء \"$name\"';
  }

  @override
  String get tankPresets_edit_descriptionHint =>
      'مثال: أسطوانة الإيجار من متجر الغوص';

  @override
  String get tankPresets_edit_descriptionOptional => 'الوصف (اختياري)';

  @override
  String tankPresets_edit_errorLoading(Object error) {
    return 'خطأ في تحميل الإعداد: $error';
  }

  @override
  String tankPresets_edit_errorSaving(Object error) {
    return 'خطأ في حفظ الإعداد: $error';
  }

  @override
  String tankPresets_edit_gasCapacity(Object capacity) {
    return 'سعة الغاز: $capacity cuft •';
  }

  @override
  String get tankPresets_edit_material => 'المادة';

  @override
  String get tankPresets_edit_name => 'الاسم';

  @override
  String get tankPresets_edit_nameHelper => 'اسم مألوف لإعداد الأسطوانة';

  @override
  String get tankPresets_edit_nameHint => 'مثال: AL80 الخاص بي';

  @override
  String get tankPresets_edit_nameRequired => 'يرجى إدخال اسم';

  @override
  String get tankPresets_edit_ratedPressure => 'الضغط المقدّر';

  @override
  String get tankPresets_edit_required => 'مطلوب';

  @override
  String get tankPresets_edit_tankSpecifications => 'مواصفات الأسطوانة';

  @override
  String get tankPresets_edit_title => 'تعديل إعداد الأسطوانة';

  @override
  String tankPresets_edit_updated(Object name) {
    return 'تم تحديث \"$name\"';
  }

  @override
  String get tankPresets_edit_validPressure => 'أدخل ضغطًا صحيحًا';

  @override
  String get tankPresets_edit_validVolume => 'أدخل حجمًا صحيحًا';

  @override
  String get tankPresets_edit_volume => 'الحجم';

  @override
  String get tankPresets_edit_volumeHelperCuft => 'سعة الغاز (cuft)';

  @override
  String get tankPresets_edit_volumeHelperLiters => 'حجم الماء (L)';

  @override
  String tankPresets_edit_waterVolume(Object volume) {
    return 'حجم الماء: $volume L •';
  }

  @override
  String get tankPresets_edit_workingPressure => 'ضغط العمل';

  @override
  String tankPresets_edit_workingPressureBar(Object pressure) {
    return 'ضغط العمل: $pressure bar •';
  }

  @override
  String tankPresets_error(Object error) {
    return 'خطأ: $error';
  }

  @override
  String tankPresets_errorDeleting(Object error) {
    return 'خطأ في حذف الإعداد: $error';
  }

  @override
  String get tankPresets_applyToImports => 'تطبيق على الغطسات المستوردة أيضاً';

  @override
  String get tankPresets_applyToImports_subtitle =>
      'ملء بيانات الخزان المفقودة في الغطسات المستوردة باستخدام الإعداد الافتراضي';

  @override
  String get tankPresets_new_title => 'إعداد أسطوانة جديد';

  @override
  String get tankPresets_noPresets => 'لا توجد إعدادات أسطوانات';

  @override
  String get tankPresets_setAsDefault => 'تعيين كافتراضي';

  @override
  String get tankPresets_title => 'إعدادات الأسطوانات';

  @override
  String get tools_gpsLogger_description =>
      'سجّل موقعك خلال يوم الغطس وتتم مطابقة الغطسات المستوردة مع مواقع GPS تلقائيًا.';

  @override
  String get tools_gpsLogger_subtitle => 'تسجيل مسار السطح';

  @override
  String get tools_gpsLogger_title => 'مسجّل GPS';

  @override
  String get tools_weight_aluminumImperial => 'أكثر طفوًا عند الفراغ (+4 lbs)';

  @override
  String get tools_weight_aluminumMetric => 'أكثر طفوًا عند الفراغ (+2 kg)';

  @override
  String get tools_weight_bodyWeightOptional => 'وزن الجسم (اختياري)';

  @override
  String get tools_weight_carbonFiberImperial => 'طفو عالٍ جدًا (+7 lbs)';

  @override
  String get tools_weight_carbonFiberMetric => 'طفو عالٍ جدًا (+3 kg)';

  @override
  String get tools_weight_disclaimer =>
      'هذا تقدير فقط. قم دائمًا بفحص الطفو في بداية الغطسة واضبط حسب الحاجة. عوامل مثل BCD والطفو الشخصي وأنماط التنفس تؤثر على متطلبات الوزن الفعلية.';

  @override
  String get tools_weight_exposureSuit => 'بدلة الغوص';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return 'سعة الغاز: $capacity cuft •';
  }

  @override
  String get tools_weight_helperImperial =>
      'يضيف ~2 lbs لكل 22 lbs فوق 154 lbs';

  @override
  String get tools_weight_helperMetric => 'يضيف ~1 kg لكل 10 kg فوق 70 kg';

  @override
  String get tools_weight_notSpecified => 'غير محدد';

  @override
  String get tools_weight_recommendedWeight => 'الوزن الموصى به';

  @override
  String tools_weight_resultAccessibility(Object weight, Object unit) {
    return 'الوزن الموصى به: $weight $unit';
  }

  @override
  String get tools_weight_steelImperial => 'طفو سلبي (-4 lbs)';

  @override
  String get tools_weight_steelMetric => 'طفو سلبي (-2 kg)';

  @override
  String get tools_weight_tankMaterial => 'مادة الأسطوانة';

  @override
  String get tools_weight_tankSpecifications => 'مواصفات الأسطوانة';

  @override
  String get tools_weight_title => 'حاسبة الوزن';

  @override
  String get tools_weight_waterType => 'نوع الماء';

  @override
  String tools_weight_waterVolume(Object volume) {
    return 'حجم الماء: $volume L •';
  }

  @override
  String tools_weight_workingPressure(Object pressure) {
    return 'ضغط العمل: $pressure bar •';
  }

  @override
  String get tools_weight_yourWeight => 'وزنك';

  @override
  String get settings_section_dataSources_title => 'Data Sources';

  @override
  String get settings_section_dataSources_subtitle =>
      'Connected services & integrations';

  @override
  String get settings_siteMatch_title => 'مطابقة المواقع تلقائيًا';

  @override
  String get settings_siteMatch_subtitle =>
      'مدى صرامة مطابقة الغوصات التي تم تنزيلها بالمواقع';

  @override
  String get settings_siteMatch_strict => 'صارم';

  @override
  String get settings_siteMatch_balanced => 'متوازن';

  @override
  String get settings_siteMatch_relaxed => 'متساهل';

  @override
  String get settings_dataSources_header => 'Data Sources';

  @override
  String get settings_dataSources_appleHealth_title => 'Apple Health';

  @override
  String get settings_dataSources_appleHealth_subtitle =>
      'بيانات الغوص تحت الماء';

  @override
  String get settings_dataSources_appleHealth_description =>
      'Submersion reads underwater diving workout data from Apple Health, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get settings_dataSources_appleHealth_dataTypesHeader =>
      'البيانات المقروءة من HealthKit';

  @override
  String get settings_dataSources_appleHealth_dataTypeWorkouts =>
      'تمارين الغوص تحت الماء - وقت بدء الغوصة والمدة وبيانات النشاط';

  @override
  String get settings_dataSources_appleHealth_dataTypeHeartRate =>
      'معدل ضربات القلب - عينات معدل ضربات القلب المسجلة أثناء الغوصات';

  @override
  String get settings_dataSources_appleHealth_permissionGranted =>
      'تم منح الوصول إلى HealthKit';

  @override
  String get settings_dataSources_appleHealth_permissionNotGranted =>
      'لم يتم منح الوصول إلى HealthKit';

  @override
  String get settings_dataSources_appleHealth_permissionChecking =>
      'جارٍ التحقق من الوصول إلى HealthKit...';

  @override
  String get settings_dataSources_appleHealth_importAction =>
      'Import from Apple Watch';

  @override
  String get settings_dataSources_appleHealth_privacy =>
      'Your health data is stored locally and is never shared with third parties.';

  @override
  String get settings_dataSources_appleHealth_poweredBy =>
      'مدعوم من Apple HealthKit';

  @override
  String get settings_dataSources_noSources =>
      'No data source integrations are available on this platform.';

  @override
  String get diveLog_edit_section_environment => 'البيئة';

  @override
  String get diveLog_edit_subsection_autofill => 'تعبئة تلقائية';

  @override
  String get diveLog_edit_subsection_weather => 'الطقس';

  @override
  String get diveLog_edit_subsection_diveConditions => 'ظروف الغوص';

  @override
  String get diveLog_edit_label_windSpeed => 'سرعة الرياح';

  @override
  String get diveLog_edit_label_windDirection => 'اتجاه الرياح';

  @override
  String get diveLog_edit_label_cloudCover => 'الغطاء السحابي';

  @override
  String get diveLog_edit_label_precipitation => 'هطول الأمطار';

  @override
  String get diveLog_edit_label_humidity => 'الرطوبة';

  @override
  String get diveLog_edit_label_weatherDescription => 'وصف الطقس';

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
  String get diveLog_detail_section_environment => 'البيئة';

  @override
  String get diveLog_detail_subsection_weather => 'الطقس';

  @override
  String get diveLog_detail_subsection_diveConditions => 'ظروف الغوص';

  @override
  String get diveLog_detail_label_windSpeed => 'سرعة الرياح';

  @override
  String get diveLog_detail_label_windDirection => 'اتجاه الرياح';

  @override
  String get diveLog_detail_label_cloudCover => 'الغطاء السحابي';

  @override
  String get diveLog_detail_label_precipitation => 'هطول الأمطار';

  @override
  String get diveLog_detail_label_humidity => 'الرطوبة';

  @override
  String get diveLog_detail_label_weatherDescription => 'الوصف';

  @override
  String get diveLog_detail_weatherSourceOpenMeteo => 'via Open-Meteo';

  @override
  String get dropTarget_title => 'أفلت للاستيراد';

  @override
  String get dropTarget_subtitle => 'حرر لفتح معالج الاستيراد';

  @override
  String get dropTarget_error_unsupportedFile => 'نوع ملف غير مدعوم';

  @override
  String get dropTarget_error_wizardActive => 'أنهِ الاستيراد الحالي أولاً';

  @override
  String get dropTarget_error_readFailed => 'تعذرت قراءة الملف';

  @override
  String get enum_cloudCover_clear => 'صافٍ';

  @override
  String get enum_cloudCover_partlyCloudy => 'غائم جزئياً';

  @override
  String get enum_cloudCover_mostlyCloudy => 'غائم في الغالب';

  @override
  String get enum_cloudCover_overcast => 'ملبد بالغيوم';

  @override
  String get enum_precipitation_none => 'لا يوجد';

  @override
  String get enum_precipitation_drizzle => 'رذاذ';

  @override
  String get enum_precipitation_lightRain => 'مطر خفيف';

  @override
  String get enum_precipitation_rain => 'مطر';

  @override
  String get enum_precipitation_heavyRain => 'مطر غزير';

  @override
  String get enum_precipitation_snow => 'ثلج';

  @override
  String get enum_precipitation_sleet => 'مطر متجمد';

  @override
  String get enum_precipitation_hail => 'بَرَد';

  @override
  String get columnConfig_title => 'حقول قائمة تفاصيل الغوصات';

  @override
  String get columnConfig_viewMode => 'وضع العرض';

  @override
  String get columnConfig_visibleColumns => 'الأعمدة المرئية';

  @override
  String get columnConfig_availableFields => 'الحقول المتاحة';

  @override
  String get columnConfig_extraFields => 'حقول إضافية';

  @override
  String get columnConfig_extraFields_description =>
      'تظهر أسفل محتوى البطاقة الرئيسي';

  @override
  String get columnConfig_slotAssignments => 'تعيينات الخانات';

  @override
  String get columnConfig_resetToDefault => 'إعادة التعيين إلى الافتراضي';

  @override
  String get columnConfig_preset => 'إعداد مسبق';

  @override
  String get columnConfig_presetSaveAs => 'حفظ باسم';

  @override
  String get columnConfig_presetName => 'اسم الإعداد المسبق';

  @override
  String get columnConfig_presetNameHint => 'مثال: الغوص التقني';

  @override
  String get columnConfig_presetSave => 'حفظ';

  @override
  String get columnConfig_presetCancel => 'إلغاء';

  @override
  String get columnConfig_columns => 'الأعمدة';

  @override
  String get columnConfig_done => 'تم';

  @override
  String get settings_appearance_columnConfig => 'حقول قائمة تفاصيل الغوصات';

  @override
  String get settings_appearance_columnConfig_subtitle =>
      'تخصيص الحقول المعروضة في عروض قائمة الغوصات';

  @override
  String get diveField_category_core => 'أساسي';

  @override
  String get diveField_category_environment => 'البيئة';

  @override
  String get diveField_category_gas => 'الغاز';

  @override
  String get diveField_category_tank => 'الأسطوانة';

  @override
  String get diveField_category_weight => 'الأثقال';

  @override
  String get diveField_category_equipment => 'المعدات';

  @override
  String get diveField_category_deco => 'تخفيف الضغط';

  @override
  String get diveField_category_physiology => 'علم وظائف الأعضاء';

  @override
  String get diveField_category_rebreather => 'جهاز إعادة التنفس';

  @override
  String get diveField_category_people => 'الأشخاص';

  @override
  String get diveField_category_location => 'الموقع';

  @override
  String get diveField_category_trip => 'الرحلة';

  @override
  String get diveField_category_rating => 'التقييم';

  @override
  String get diveField_category_metadata => 'البيانات الوصفية';

  @override
  String get listViewMode_table => 'جدول';

  @override
  String get settings_appearance_general => 'عام';

  @override
  String get settings_appearance_sections => 'الأقسام';

  @override
  String get settings_appearance_colorAccents => 'التمييز اللوني';

  @override
  String get settings_appearance_accentNavIcons => 'أيقونات تنقل ملونة';

  @override
  String get settings_appearance_accentNavIcons_subtitle =>
      'تلوين أيقونات القائمة الرئيسية بلون كل قسم';

  @override
  String get settings_appearance_accentSectionHeaders => 'عناوين أقسام ملونة';

  @override
  String get settings_appearance_accentSectionHeaders_subtitle =>
      'إظهار أيقونة قسم ملونة بجانب عناوين الصفحات';

  @override
  String get settings_appearance_accentListIcons => 'أيقونات قوائم ملونة';

  @override
  String get settings_appearance_accentListIcons_subtitle =>
      'تلوين الأيقونات في القوائم وصفحات الإعدادات';

  @override
  String get settings_appearance_showDetailsPane => 'إظهار لوحة التفاصيل';

  @override
  String get settings_appearance_showDetailsPane_subtitle =>
      'عرض لوحة التفاصيل بجانب الجدول';

  @override
  String get settings_appearance_showProfilePanel =>
      'إظهار لوحة الملف الشخصي في عرض الجدول';

  @override
  String get settings_appearance_showProfilePanel_subtitle =>
      'عرض مخطط ملف الغوصة فوق الجدول بشكل افتراضي';

  @override
  String get settings_appearance_mapStyle => 'نمط الخريطة';

  @override
  String get settings_appearance_mapStyle_openStreetMap => 'خريطة الشوارع';

  @override
  String get settings_appearance_mapStyle_openTopoMap => 'طبوغرافية';

  @override
  String get settings_appearance_mapStyle_esriSatellite => 'قمر صناعي';

  @override
  String get common_action_reparse => 'إعادة التحليل';

  @override
  String get diveComputer_detail_reparseAllButton => 'إعادة تحليل جميع الغطسات';

  @override
  String get diveComputer_detail_reparseAllTitle => 'إعادة تحليل جميع الغطسات';

  @override
  String diveComputer_detail_reparseAllMessage(int count) {
    return 'إعادة تشغيل محلل الغطسات على $count غطسة لها بيانات أولية مخزنة. يُحدِّث ذلك بيانات الملف الشخصي والمستشعرات لكنه يحافظ على الملاحظات والمواقع والشركاء والتعديلات الأخرى.';
  }

  @override
  String diveComputer_detail_reparseAllProgress(int count) {
    return 'جارٍ إعادة تحليل $count غطسة...';
  }

  @override
  String diveComputer_detail_reparseAllSuccess(int count) {
    return 'تمت إعادة تحليل $count غطسة بنجاح';
  }

  @override
  String diveComputer_detail_reparseAllPartial(
    int succeeded,
    int total,
    int failed,
  ) {
    return 'تمت إعادة تحليل $succeeded من أصل $total غطسة. فشلت $failed.';
  }

  @override
  String diveComputer_detail_reparseRawDataCount(int count) {
    return '$count غطسة بها بيانات أولية';
  }

  @override
  String diveComputer_detail_reparseRawDataCountWithout(
    int count,
    int without,
  ) {
    return '$count غطسة بها بيانات أولية ($without بدون)';
  }

  @override
  String get diveLog_detail_menu_reparseRawData =>
      'إعادة تحليل البيانات الأولية';

  @override
  String get diveLog_detail_reparseSuccess => 'تمت إعادة تحليل الغطسة بنجاح';

  @override
  String get diveLog_detail_reparseProfilePreserved =>
      'تم تحديث تفاصيل المصدر. دُمجت هذه الغطسة من غطسات أخرى، لذلك بقي مخططها دون تغيير.';

  @override
  String diveLog_detail_reparseFailed(String error) {
    return 'فشلت إعادة التحليل: $error';
  }

  @override
  String get universalImport_label_replaceSource => 'استبدال المصدر';

  @override
  String get universalImport_label_replaceSourceSubtitle =>
      'تحديث من نفس الكمبيوتر';

  @override
  String get universalImport_title_importOptions => 'خيارات الاستيراد';

  @override
  String get universalImport_label_options => 'خيارات';

  @override
  String get universalImport_label_retainDiveNumbers =>
      'الاحتفاظ بأرقام الغطسات الأصلية';

  @override
  String get universalImport_label_retainDiveNumbersSubtitle =>
      'استخدام أرقام الغطسات من الملف المستورد بدلاً من تعيينها تلقائياً';

  @override
  String get universalImport_title_successImported => 'تم الاستيراد بنجاح';

  @override
  String get universalImport_title_successUpdated => 'تم التحديث بنجاح';

  @override
  String get universalImport_title_successConsolidated => 'تم الدمج بنجاح';

  @override
  String get universalImport_title_noDivesImported => 'لم يتم استيراد أي غطسة';

  @override
  String get universalImport_label_allDivesSkipped => 'تم تخطي جميع الغطسات.';

  @override
  String get universalImport_label_replacedSourceData =>
      'تم استبدال بيانات المصدر';

  @override
  String get universalImport_label_consolidated => 'مدمجة';

  @override
  String get universalImport_label_photosAttached => 'الصور المرفقة';

  @override
  String get universalImport_label_photosUnmatched => 'صور لم تطابق أي غوصة';

  @override
  String get common_label_shareWithAllProfiles =>
      'المشاركة مع جميع ملفات الغوص';

  @override
  String get settings_shareByDefault_title =>
      'مشاركة المواقع والرحلات الجديدة تلقائيًا';

  @override
  String get settings_shareAllSites_title => 'مشاركة جميع مواقعي';

  @override
  String get settings_shareAllTrips_title => 'مشاركة جميع رحلاتي';

  @override
  String settings_shareAllSites_confirm(int count) {
    return 'هل تريد جعل كل $count من مواقعك مرئية لكل ملفات الغوص في هذا التطبيق؟ يمكنك إلغاء مشاركة مواقع فردية لاحقًا.';
  }

  @override
  String settings_shareAllTrips_confirm(int count) {
    return 'هل تريد جعل كل $count من رحلاتك مرئية لكل ملفات الغوص في هذا التطبيق؟ يمكنك إلغاء مشاركة رحلات فردية لاحقًا.';
  }

  @override
  String settings_shareAllSites_snackbar(int count) {
    return 'تمت مشاركة $count من المواقع مع جميع ملفات الغوص.';
  }

  @override
  String settings_shareAllTrips_snackbar(int count) {
    return 'تمت مشاركة $count من الرحلات مع جميع ملفات الغوص.';
  }

  @override
  String get settings_shareAll_noneToShare => 'لا يوجد شيء لمشاركته.';

  @override
  String get settings_sharedData_sectionTitle => 'البيانات المشتركة';

  @override
  String get settings_sharedData_sectionSubtitle =>
      'مشاركة المواقع والرحلات بين الملفات';

  @override
  String get common_action_unshare => 'إلغاء المشاركة';

  @override
  String get trips_unshareConfirm_title => 'إلغاء مشاركة هذه الرحلة؟';

  @override
  String trips_unshareConfirm_body(String name) {
    return 'سيؤدي هذا إلى إزالة «$name» من عروض ملفات الغوص الأخرى. يمكنك مشاركتها مرة أخرى لاحقًا.';
  }

  @override
  String get sites_unshareConfirm_title => 'إلغاء مشاركة هذا الموقع؟';

  @override
  String sites_unshareConfirm_body(String name) {
    return 'سيؤدي هذا إلى إزالة «$name» من عروض ملفات الغوص الأخرى. يمكنك مشاركته مرة أخرى لاحقًا.';
  }

  @override
  String get trips_deleteShared_title => 'حذف الرحلة المشتركة؟';

  @override
  String trips_deleteShared_body(String name) {
    return '«$name» مشتركة مع ملفات غوص أخرى. حذفها من هنا يزيلها للجميع.';
  }

  @override
  String get sites_deleteShared_title => 'حذف الموقع المشترك؟';

  @override
  String sites_deleteShared_body(String name) {
    return '«$name» مشترك مع ملفات غوص أخرى. حذفه من هنا يزيله للجميع.';
  }

  @override
  String divers_delete_reassigned_snackbar(int trips, int sites, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      trips,
      locale: localeName,
      other: 'رحلات مشتركة',
      one: 'رحلة مشتركة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sites,
      locale: localeName,
      other: 'مواقع مشتركة',
      one: 'موقع مشترك',
    );
    return 'تم حذف الغواص. $trips $_temp0 و$sites $_temp1 أُعيد تعيينها إلى $name.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_title => 'ملفات غواصين مكررة';

  @override
  String get settings_cloudSync_duplicateDivers_description =>
      'وجد المزامنة أكثر من ملف شخصي بالاسم نفسه. يحدث ذلك عادةً عندما أنشأ كل جهاز ملفه الشخصي قبل المزامنة. يؤدي الدمج إلى نقل جميع الغطسات والبيانات إلى ملف واحد.';

  @override
  String settings_cloudSync_duplicateDivers_groupLabel(String name, int count) {
    return '$name ($count ملفات)';
  }

  @override
  String get settings_cloudSync_duplicateDivers_mergeButton => 'دمج';

  @override
  String get settings_cloudSync_duplicateDivers_confirmTitle =>
      'دمج ملفات الغواصين؟';

  @override
  String settings_cloudSync_duplicateDivers_confirmBody(
    int count,
    String name,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملفات مكررة',
      one: 'ملف مكرر',
    );
    return 'سيتم نقل جميع الغطسات والشهادات والمعدات والبيانات الأخرى من $_temp0 إلى \"$name\". لا يمكن التراجع عن هذا تلقائيًا.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_confirmCancel => 'إلغاء';

  @override
  String get settings_cloudSync_duplicateDivers_confirmAction => 'دمج';

  @override
  String settings_cloudSync_duplicateDivers_successSnack(String name) {
    return 'تم الدمج في $name';
  }

  @override
  String settings_cloudSync_duplicateDivers_failureSnack(String error) {
    return 'فشل الدمج: $error';
  }

  @override
  String get settings_cloudSync_duplicateDivers_undo => 'تراجع';

  @override
  String get divers_edit_priorExperienceSection => 'خبرة سابقة';

  @override
  String get divers_edit_priorExperienceHelp =>
      'الغطسات والوقت من قبل أن تبدأ التسجيل في Submersion.';

  @override
  String get divers_edit_priorDivesLabel => 'غطسات سابقة';

  @override
  String get divers_edit_priorHoursLabel => 'ساعات سابقة';

  @override
  String get divers_edit_priorMinutesLabel => 'دقائق';

  @override
  String get divers_edit_divingSinceLabel => 'يغوص منذ';

  @override
  String get divers_edit_divingSinceNotSet => 'غير محدد';

  @override
  String get divers_edit_clearDivingSinceTooltip => 'مسح يغوص منذ';

  @override
  String get divers_edit_priorInvalidNumber => 'أدخل رقمًا صالحًا';

  @override
  String statistics_priorBreakdown(String logged, String prior) {
    return '$logged مسجلة + $prior سابقة';
  }

  @override
  String statistics_divingSince(int year) {
    return 'يغوص منذ $year';
  }

  @override
  String get db_location_choose_volume => 'اختيار موقع التخزين';

  @override
  String get db_location_internal => 'التخزين الداخلي';

  @override
  String get db_location_sd_card => 'بطاقة SD';

  @override
  String get db_location_external_note =>
      'تُحذف الملفات هنا عند إلغاء تثبيت التطبيق.';

  @override
  String get db_location_backup_note =>
      'لا يمكن لنظام Android تشغيل قاعدة البيانات من مجلد مُزامَن مع السحابة. للاحتفاظ بنسخة في Dropbox أو Nextcloud أو Google Drive، حدِّد موقع النسخة الاحتياطية ضمن النسخ الاحتياطي والاستعادة.';

  @override
  String diveLog_bulkEdit_membership_onAll(int count) {
    return 'في كل الـ $count';
  }

  @override
  String diveLog_bulkEdit_membership_onSome(int count, int total) {
    return 'في $count من $total';
  }

  @override
  String diveLog_bulkEdit_membership_adding(int total) {
    return 'إضافة إلى كل الـ $total';
  }

  @override
  String get diveLog_bulkEdit_membership_removing => 'إزالة من الكل';

  @override
  String get diveLog_bulkEdit_membership_empty =>
      'لا توجد عناصر في الغطسات المحددة بعد';

  @override
  String get settings_mediaStorage_entry_title => 'تخزين الوسائط';

  @override
  String get settings_mediaStorage_entry_subtitle =>
      'خزّن النسخ الأصلية للصور والفيديو في التخزين السحابي الخاص بك';

  @override
  String get settings_mediaStorage_status_notConfigured =>
      'لا يوجد مخزن وسائط متصل على هذا الجهاز';

  @override
  String settings_mediaStorage_status_connected(String hint) {
    return 'متصل بـ $hint';
  }

  @override
  String get settings_mediaStorage_test_success => 'نجح الاتصال';

  @override
  String get settings_mediaStorage_saved => 'تم توصيل مخزن الوسائط';

  @override
  String get settings_mediaStorage_action_disconnect => 'قطع الاتصال';

  @override
  String get settings_mediaStorage_disconnect_confirm_title =>
      'قطع اتصال مخزن الوسائط؟';

  @override
  String get settings_mediaStorage_disconnect_confirm_body =>
      'يتوقف هذا الجهاز عن رفع الوسائط وجلبها. لن يُحذف أي شيء من الحاوية الخاصة بك.';

  @override
  String get settings_mediaStorage_action_copyFromSync =>
      'نسخ الإعدادات من المزامنة';

  @override
  String get settings_mediaStorage_transfers_title => 'عمليات النقل';

  @override
  String get settings_mediaStorage_transfers_entry => 'عرض عمليات النقل';

  @override
  String get settings_mediaStorage_transfers_empty => 'لا توجد عمليات نقل';

  @override
  String get settings_mediaStorage_transfers_retry => 'إعادة المحاولة';

  @override
  String get settings_mediaStorage_transfers_clearCompleted => 'مسح المكتملة';

  @override
  String get settings_mediaStorage_transfers_state_pending => 'في الانتظار';

  @override
  String get settings_mediaStorage_transfers_state_transferring => 'جارٍ الرفع';

  @override
  String get settings_mediaStorage_transfers_state_deleting =>
      'جارٍ الإزالة من السحابة';

  @override
  String get settings_mediaStorage_transfers_state_done => 'تم';

  @override
  String get settings_mediaStorage_transfers_state_failed => 'فشل';

  @override
  String settings_mediaStorage_transfers_queued(int count) {
    return '$count في قائمة الانتظار';
  }

  @override
  String settings_mediaStorage_transfers_waitingRetry(int count) {
    return '$count في انتظار إعادة المحاولة';
  }

  @override
  String get settings_mediaStorage_verify_action => 'التحقق من المكتبة';

  @override
  String get settings_mediaStorage_verify_running =>
      'جارٍ التحقق من مكتبة الوسائط...';

  @override
  String settings_mediaStorage_verify_summary(
    int checked,
    int removed,
    int repaired,
    int aborted,
  ) {
    return 'تم فحص $checked عنصرًا: أزيل $removed يتيمًا، وأُدرج $repaired إصلاحًا في قائمة الانتظار، وأُلغي $aborted رفعًا قديمًا';
  }

  @override
  String get settings_mediaStorage_backfill_action => 'رفع المكتبة الحالية';

  @override
  String settings_mediaStorage_backfill_enqueued(int count) {
    return '$count عمليات رفع في قائمة الانتظار';
  }

  @override
  String get settings_mediaStorage_policy_autoUpload => 'رفع الصور تلقائيا';

  @override
  String get settings_mediaStorage_policy_photosOnCellular =>
      'رفع الصور عبر شبكة الجوال';

  @override
  String get settings_mediaStorage_provider_label => 'المزود';

  @override
  String get settings_mediaStorage_connect_dropbox_hint =>
      'يستخدم اتصال Dropbox من مزامنة السحابة. تُخزن الوسائط في مجلد التطبيق في Dropbox.';

  @override
  String get settings_mediaStorage_connect_gdrive_hint =>
      'يسجل الدخول عبر Google. تُخزن الوسائط في مساحة Drive الخاصة بهذا التطبيق.';

  @override
  String get settings_mediaStorage_connect_icloud_hint =>
      'تُخزن الوسائط في حاوية iCloud لهذا التطبيق وتتزامن عبر Apple ID الخاص بك.';

  @override
  String settings_mediaStorage_connect_action(String provider) {
    return 'توصيل $provider';
  }

  @override
  String get bodyWeight_addEntry => 'إضافة قياس';

  @override
  String get bodyWeight_dateLabel => 'التاريخ';

  @override
  String get bodyWeight_deleteTooltip => 'حذف الإدخال';

  @override
  String get bodyWeight_heightLabel => 'الطول (سم)';

  @override
  String get bodyWeight_heightFeetLabel => 'الطول (قدم)';

  @override
  String get bodyWeight_heightInchesLabel => 'بوصة';

  @override
  String bodyWeight_weightLabel(String unit) {
    return 'الوزن ($unit)';
  }

  @override
  String diveLog_edit_weightFeedback_amount(String unit) {
    return 'بمقدار كم تقريبا ($unit)';
  }

  @override
  String get diveLog_edit_weightFeedback_correct => 'مناسب';

  @override
  String get diveLog_edit_weightFeedback_label => 'كيف كانت أوزانك؟';

  @override
  String get diveLog_edit_weightFeedback_over => 'وزن زائد';

  @override
  String get diveLog_edit_weightFeedback_under => 'وزن ناقص';

  @override
  String get diverProfile_bodyWeight_empty => 'غير مسجل';

  @override
  String get diverProfile_bodyWeight_title => 'وزن الجسم';

  @override
  String get equipment_edit_advanced_title => 'متقدم';

  @override
  String get equipment_edit_buoyancyHint_exposure => 'موجب: مقدار الطفو';

  @override
  String get equipment_edit_buoyancyHint_generic => 'سالب إذا كان يغرق';

  @override
  String get equipment_edit_buoyancyHint_tank =>
      'اتركه فارغا - تستخدم الأسطوانات مواصفاتها الخاصة';

  @override
  String equipment_edit_buoyancyLabel(String unit) {
    return 'الطفو ($unit)';
  }

  @override
  String equipment_edit_dryWeightLabel(String unit) {
    return 'الوزن الجاف ($unit)';
  }

  @override
  String equipment_edit_liftCapacityLabel(String unit) {
    return 'سعة الرفع ($unit)';
  }

  @override
  String get equipment_edit_liftCapacityHint => 'قوة رفع الجناح أو منظم الطفو';

  @override
  String get planner_gearWeights_accept => 'استخدام كوزن مخطط';

  @override
  String get planner_gearWeights_addGear => 'إضافة معدات';

  @override
  String get planner_gearWeights_empty => 'أضف معدات للتنبؤ بأوزانك';

  @override
  String planner_gearWeights_planned(String weight) {
    return 'المخطط: $weight';
  }

  @override
  String planner_gearWeights_predicted(String weight) {
    return 'المتوقع: $weight';
  }

  @override
  String get planner_gearWeights_title => 'المعدات والأوزان';

  @override
  String get planner_gearWeights_useSet => 'استخدام مجموعة';

  @override
  String get tools_weight_addGear => 'إضافة معدات';

  @override
  String get tools_weight_addTank => 'إضافة أسطوانة';

  @override
  String tools_weight_basedOnDives(int count) {
    return 'استنادا إلى $count غوصات مسجلة';
  }

  @override
  String get tools_weight_breakdownTitle => 'كيف تم الحساب';

  @override
  String get tools_weight_confidence_high => 'ثقة عالية';

  @override
  String get tools_weight_confidence_low => 'ثقة منخفضة - تقدير';

  @override
  String get tools_weight_confidence_medium => 'ثقة متوسطة';

  @override
  String tools_weight_deltaVsPrevious(String delta) {
    return '$delta مقارنة بالتجهيز السابق';
  }

  @override
  String get tools_weight_noGear =>
      'أضف المعدات التي تخطط للغوص بها لتخصيص التنبؤ.';

  @override
  String get tools_weight_personalTerm => 'الأساس الشخصي';

  @override
  String get tools_weight_placementTitle => 'التوزيع المقترح';

  @override
  String get tools_weight_predictedWeight => 'الوزن المتوقع';

  @override
  String get tools_weight_saveToProfile => 'حفظ الوزن في الملف الشخصي';

  @override
  String get tools_weight_source_measured => 'مقاس من غوصاتك';

  @override
  String get tools_weight_source_physics => 'فيزياء';

  @override
  String get tools_weight_source_typeDefault => 'تقدير افتراضي';

  @override
  String get tools_weight_source_userSpec => 'من مواصفات معداتك';

  @override
  String get tools_weight_tanks => 'الأسطوانات';

  @override
  String get tools_weight_useSet => 'استخدام مجموعة';

  @override
  String get tools_weight_waterTerm => 'نوع الماء';

  @override
  String get dive3d_previewTitle => 'عرض ثلاثي الأبعاد';

  @override
  String get dive3d_previewHint => 'انقر للاستكشاف بشكل ثلاثي الأبعاد';

  @override
  String get dive3d_resetView => 'إعادة تعيين العرض';

  @override
  String get dive3d_zoomIn => 'تكبير';

  @override
  String get dive3d_zoomOut => 'تصغير';

  @override
  String get dive3d_play => 'تشغيل';

  @override
  String get dive3d_pause => 'إيقاف مؤقت';

  @override
  String get dive3d_overlays => 'الطبقات';

  @override
  String get dive3d_overlay_strata => 'طبقات الحرارة';

  @override
  String get dive3d_overlay_ceiling => 'سقف تخفيف الضغط';

  @override
  String get dive3d_overlay_curtain => 'ستارة العمق';

  @override
  String get dive3d_overlay_markers => 'علامات';

  @override
  String get dive3d_seascape_overlay_paths => 'مسارات الغوص';

  @override
  String get dive3d_seascape_overlay_contours => 'خطوط الأعماق';

  @override
  String get dive3d_seascape_overlay_walls => 'جدران شديدة الانحدار';

  @override
  String get dive3d_overlay_water => 'سطح الماء';

  @override
  String get dive3d_seascape_legend_land => 'يابسة';

  @override
  String get dive3d_seascape_appearance => 'مظهر التضاريس';

  @override
  String get dive3d_seascape_chartView => 'عرض الخريطة';

  @override
  String get dive3d_seascape_orbitView => 'عرض ثلاثي الأبعاد';

  @override
  String get dive3d_seascape_appearance_surface => 'سطح التضاريس';

  @override
  String get dive3d_seascape_appearance_surfaceDepth => 'ألوان العمق';

  @override
  String get dive3d_seascape_appearance_surfaceImagery => 'صور الخريطة';

  @override
  String get dive3d_seascape_appearance_surfaceBlend => 'مزيج';

  @override
  String get siteFeature_type_wreck => 'حطام';

  @override
  String get siteFeature_type_mooring => 'مربط';

  @override
  String get siteFeature_type_entry => 'نقطة الدخول';

  @override
  String get siteFeature_type_exit => 'نقطة الخروج';

  @override
  String get siteFeature_type_swimThrough => 'ممر';

  @override
  String get siteFeature_type_hazard => 'خطر';

  @override
  String get siteFeature_type_current => 'تيار';

  @override
  String get siteFeature_sectionTitle => 'معالم';

  @override
  String get siteFeature_addAction => 'إضافة معلم';

  @override
  String get siteFeature_placeHint => 'انقر على الخريطة لوضع المعلم';

  @override
  String get siteFeature_addTitle => 'إضافة معلم';

  @override
  String get siteFeature_editTitle => 'تحرير المعلم';

  @override
  String get siteFeature_field_name => 'الاسم';

  @override
  String get siteFeature_field_bearing => 'الاتجاه (°)';

  @override
  String get siteFeature_field_depth => 'العمق';

  @override
  String get siteFeature_field_notes => 'ملاحظات';

  @override
  String get siteFeature_deleteAction => 'حذف';

  @override
  String siteFeature_deleteConfirm(String name) {
    return 'حذف $name؟';
  }

  @override
  String get siteScape_mode2d => 'خريطة';

  @override
  String get siteScape_mode3d => '3D';

  @override
  String get dive3d_seascape_appearance_rampRange => 'تحديد نطاق عمق الألوان';

  @override
  String get dive3d_seascape_appearance_rampMax => 'أغمق لون عند';

  @override
  String get dive3d_seascape_appearance_banded => 'تدرج شرائطي';

  @override
  String get dive3d_seascape_appearance_contours => 'مستويات خطوط الأعماق';

  @override
  String get dive3d_seascape_appearance_contourAuto => 'تلقائي';

  @override
  String get dive3d_seascape_appearance_contourCustom => 'مخصص';

  @override
  String get dive3d_seascape_appearance_addLevel => 'إضافة مستوى';

  @override
  String get dive3d_seascape_appearance_defaultColor => 'افتراضي';

  @override
  String get dive3d_seascape_appearance_wallAngle => 'زاوية الجدار الشديد';

  @override
  String get dive3d_seascape_appearance_wallAngleNote =>
      'تحسب خلايا قياس الأعماق متوسط الميل داخلها، لذا تبدو الجدران الحقيقية أقل انحدارا. ابق أقل بكثير من 45 درجة.';

  @override
  String get dive3d_seascape_siteTitle => 'المشهد البحري للموقع';

  @override
  String dive3d_seascape_seafloorSource(String source, String resolution) {
    return 'قاع البحر: $source (~$resolution م)';
  }

  @override
  String get dive3d_seascape_noCoordinates =>
      'لا توجد إحداثيات GPS لهذا الموقع';

  @override
  String get dive3d_seascape_noData =>
      'لا توجد بيانات قياس أعماق متاحة لهذا الموقع';

  @override
  String dive3d_seascape_axis_distance(String unitSymbol) {
    return 'المسافة ($unitSymbol)';
  }

  @override
  String get settings_about_bathymetryCredit =>
      'بيانات قياس الأعماق: GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022';

  @override
  String get dive3d_metric_depth => 'العمق';

  @override
  String get dive3d_metric_temperature => 'الحرارة';

  @override
  String get dive3d_metric_ascentRate => 'الصعود';

  @override
  String get dive3d_metric_ppO2 => 'ppO2';

  @override
  String get dive3d_metric_cns => 'CNS';

  @override
  String get dive3d_metric_heartRate => 'معدل النبض';

  @override
  String get dive3d_metric_tankPressure => 'الضغط';

  @override
  String get dive3d_zAxis => 'المحور Z';

  @override
  String get dive3d_zAxis_none => 'بدون';

  @override
  String get dive3d_overlay_shadows => 'ظلال الجدران';

  @override
  String get dive3d_metric_tts => 'TTS';

  @override
  String dive3d_axis_depth(String unitSymbol) {
    return 'العمق ($unitSymbol)';
  }

  @override
  String get dive3d_axis_time => 'زمن الغوص (دقيقة)';

  @override
  String get dive3d_pose_menu => 'الكاميرا';

  @override
  String get dive3d_pose_default => 'العرض الافتراضي';

  @override
  String get dive3d_pose_front => 'أمامي (العمق مقابل الزمن)';

  @override
  String get dive3d_pose_side => 'جانبي (العمق مقابل القياس)';

  @override
  String get dive3d_pose_top => 'علوي (القياس مقابل الزمن)';

  @override
  String get dive3d_readout_runTime => 'زمن الغوص';

  @override
  String get dive3d_readout_ceiling => 'السقف';

  @override
  String dive3d_readout_tank(int n) {
    return 'أسطوانة $n';
  }

  @override
  String get dive3d_scene_dive => 'الغوص';

  @override
  String get dive3d_scene_tissue => 'الأنسجة';

  @override
  String get dive3d_tissue_gasCombined => 'مجمّع';

  @override
  String get dive3d_tissue_gasN2 => 'N2';

  @override
  String get dive3d_tissue_gasHe => 'He';

  @override
  String get dive3d_tissue_colorMValue => '% قيمة M';

  @override
  String get dive3d_tissue_colorAbsolute => 'التحميل';

  @override
  String get dive3d_tissue_controlling => 'المتحكم';

  @override
  String get dive3d_tissue_surfaceInterval => 'فترة السطح';

  @override
  String get dive3d_career_title => 'السجل ثلاثي الأبعاد';

  @override
  String get dive3d_career_colorRecency => 'الحداثة';

  @override
  String get dive3d_career_colorDepth => 'العمق';

  @override
  String get dive3d_career_empty => 'لا توجد غطسات بمخططات';

  @override
  String get dive3d_spatial_title => 'مشهد بحري ثلاثي الأبعاد';

  @override
  String get dive3d_spatial_estimatedPath => 'مسار مقدّر (الحساب الاستدلالي)';

  @override
  String get dive3d_spatial_synthesizedSeafloor => 'قاع بحر مُركّب';

  @override
  String get dive3d_spatial_noPath => 'بيانات غير كافية لإعادة بناء المسار';

  @override
  String get dive3d_tissue_legendHeight => 'الارتفاع واللون: ٪ من حد قيمة M';

  @override
  String get dive3d_tissue_legendLimit => 'المستوى الأحمر = حد تخفيف الضغط';

  @override
  String get dive3d_tissue_legendAxes =>
      'يسار→يمين: الوقت · أمام→خلف: أنسجة سريعة→بطيئة';

  @override
  String get dive3d_tissue_legendDepth => 'المنحنى الأزرق: عمقك';

  @override
  String get dive3d_tissue_onGassing => 'امتصاص';

  @override
  String get dive3d_tissue_offGassing => 'إطلاق';

  @override
  String dive3d_tissue_tooltipCompartment(int number) {
    return 'المقصورة $number';
  }

  @override
  String dive3d_tissue_tooltipHalfTime(int minutes) {
    return '$minutes دقيقة N2';
  }

  @override
  String dive3d_tissue_tooltipSaturation(int percent) {
    return 'التشبع $percent%';
  }

  @override
  String dive3d_tissue_tooltipProgress(int percent) {
    return '$percent% من الغوص';
  }

  @override
  String get dive3d_tissue_stateEquilibrium => 'توازن';

  @override
  String get dive3d_tissue_statePastMValue => 'تجاوز قيمة M';

  @override
  String get dive3d_tissue_axisTime => 'الوقت';

  @override
  String get dive3d_tissue_axisSaturation => 'التشبع %';

  @override
  String get dive3d_tissue_axisCompartment => 'المقصورة';

  @override
  String get dive3d_compare_computers_title => 'مقارنة أجهزة الغوص';

  @override
  String get dive3d_compare_dives_title => 'مقارنة الغطسات';

  @override
  String get dive3d_scene_computers => 'أجهزة الغوص';

  @override
  String get dive3d_compare_layout_sideBySide => 'جنبًا إلى جنب';

  @override
  String get dive3d_compare_layout_overlay => 'متراكب';

  @override
  String get dive3d_compare_empty =>
      'يلزم وجود ملفَّي غوص على الأقل يحتويان على بيانات العمق للمقارنة';

  @override
  String dive3d_compare_showing(Object shown, Object total) {
    return 'عرض $shown من $total';
  }

  @override
  String get dive3d_compare_setReference => 'تعيين كمرجع';

  @override
  String get diveLog_selection_tooltip_compare3d => 'مقارنة ثلاثية الأبعاد';

  @override
  String get diveLog_sources_compareIn3d => 'مقارنة ثلاثية الأبعاد';

  @override
  String get settings_setup_pendingTitle => 'أكمل إعداد هذا الجهاز';

  @override
  String settings_setup_mediaStoreAttach(String hint) {
    return 'الاتصال بتخزين الوسائط ($hint)';
  }

  @override
  String settings_setup_accountSignIn(String label) {
    return 'تسجيل الدخول إلى $label';
  }

  @override
  String get settings_setup_dismiss => 'تجاهل';

  @override
  String get settings_photosMedia_title => 'الصور والوسائط';

  @override
  String get settings_photosMedia_subtitle => 'المصادر والتخزين والحسابات';

  @override
  String get settings_photosMedia_sourcesHeader => 'من أين تأتي الصور';

  @override
  String get settings_photosMedia_storageHeader => 'أين تُحفظ النسخ';

  @override
  String get settings_photosMedia_accountsHeader => 'الحسابات';

  @override
  String get settings_photosMedia_displayHeader => 'العرض';

  @override
  String get settings_photosMedia_guidedSetup => 'إعداد موجه';

  @override
  String get settings_photosMedia_photoSources_title => 'مكتبة الصور والمصادر';

  @override
  String get settings_photosMedia_photoSources_subtitle =>
      'المعرض والملفات وخيارات الاستيراد';

  @override
  String get settings_photosMedia_networkSources_title => 'مصادر الشبكة';

  @override
  String get settings_photosMedia_networkSources_subtitle =>
      'عناوين URL وتغذيات القوائم (متقدم)';

  @override
  String get settings_connectedAccounts_title => 'الحسابات المتصلة';

  @override
  String get settings_connectedAccounts_subtitle =>
      'تسجيلات الدخول للسحابة والخدمات';

  @override
  String get settings_connectedAccounts_empty => 'لا توجد حسابات متصلة بعد';

  @override
  String get settings_connectedAccounts_status_signedIn => 'تم تسجيل الدخول';

  @override
  String get settings_connectedAccounts_status_needsSignIn =>
      'يتطلب تسجيل الدخول';

  @override
  String get settings_connectedAccounts_status_unavailable =>
      'غير متاح على هذا الجهاز';

  @override
  String get settings_connectedAccounts_disconnectDevice =>
      'تسجيل الخروج على هذا الجهاز';

  @override
  String get settings_connectedAccounts_removeFromLibrary => 'إزالة من المكتبة';

  @override
  String get settings_connectedAccounts_removeConfirmTitle => 'إزالة الحساب؟';

  @override
  String get settings_connectedAccounts_removeConfirmBody =>
      'تتم إزالة الحساب من جميع الأجهزة المتزامنة. لا تُحذف بيانات الاعتماد المخزنة على الأجهزة الأخرى.';

  @override
  String get settings_setupGuide_title => 'إعداد الصور والوسائط';

  @override
  String get settings_setupGuide_intro =>
      'اربط مصادر صورك وأماكن حفظ النسخ. يمكنك إعادة تشغيل هذا في أي وقت.';

  @override
  String get settings_setupGuide_stepSources => 'مصادر الصور';

  @override
  String get settings_setupGuide_stepSources_desc =>
      'أرفق الصور من مكتبة الصور أو الملفات أو Lightroom.';

  @override
  String get settings_setupGuide_stepStorage => 'تخزين الوسائط';

  @override
  String get settings_setupGuide_stepStorage_desc =>
      'احفظ نسخًا من صورك في سحابتك الخاصة حتى تعرضها جميع أجهزتك.';

  @override
  String get settings_setupGuide_stepSync => 'مزامنة سحابية';

  @override
  String get settings_setupGuide_stepSync_desc =>
      'زامن بيانات الغوص بين الأجهزة.';

  @override
  String get settings_setupGuide_statusDone => 'تم الإعداد';

  @override
  String get settings_setupGuide_statusTodo => 'لم يتم الإعداد';

  @override
  String get settings_setupGuide_open => 'فتح';

  @override
  String get settings_connectedAccounts_loadError => 'تعذر تحميل الحسابات';

  @override
  String get media_unavailablePlaceholder_volumeOffline =>
      'وحدة التخزين غير مثبتة';

  @override
  String get media_unavailablePlaceholder_stillFetching =>
      'ما زال قيد التحميل. اضغط لإعادة المحاولة.';

  @override
  String get media_unavailablePlaceholder_accessDenied =>
      'لا يوجد وصول إلى مكتبة الصور';

  @override
  String get attrLabel_size => 'المقاس';

  @override
  String get attrLabel_thickness_mm => 'السماكة (مم)';

  @override
  String get attrLabel_suit_style => 'نوع البدلة';

  @override
  String get attrLabel_shell_material => 'مادة الغلاف';

  @override
  String get attrLabel_seal_type => 'نوع العزل';

  @override
  String get attrLabel_volume_l => 'السعة';

  @override
  String get attrLabel_working_pressure_bar => 'ضغط التشغيل';

  @override
  String get attrLabel_tank_material => 'المادة';

  @override
  String get attrLabel_valve_type => 'الصمام';

  @override
  String get attrLabel_tank_identifier => 'المعرف';

  @override
  String get attrLabel_last_visual_inspection => 'آخر فحص بصري';

  @override
  String get attrLabel_last_hydro_test => 'آخر اختبار هيدروستاتيكي';

  @override
  String get attrLabel_connection => 'التوصيل';

  @override
  String get attrLabel_cold_water_rated => 'مخصص للمياه الباردة';

  @override
  String get attrLabel_bcd_style => 'النمط';

  @override
  String get attrLabel_lift_capacity_kg => 'قوة الرفع';

  @override
  String get attrLabel_heel_type => 'الكعب';

  @override
  String get attrLabel_blade_style => 'الزعنفة';

  @override
  String get attrLabel_mount => 'التثبيت';

  @override
  String get attrLabel_connectivity => 'الاتصال';

  @override
  String get attrLabel_lens_config => 'العدسة';

  @override
  String get attrLabel_prescription => 'عدسات طبية';

  @override
  String get attrLabel_weight_style => 'النمط';

  @override
  String get attrLabel_lumens => 'لومن';

  @override
  String get attrLabel_beam_type => 'الشعاع';

  @override
  String get attrLabel_depth_rating_m => 'تصنيف العمق';

  @override
  String get attrLabel_smb_type => 'النوع';

  @override
  String get attrLabel_length_m => 'الطول';

  @override
  String get attrLabel_reel_type => 'النوع';

  @override
  String get attrLabel_line_length_m => 'طول الخيط';

  @override
  String get attrLabel_blade_material => 'مادة النصل';

  @override
  String get attrLabel_tip_type => 'الطرف';

  @override
  String get attrLabel_glove_type => 'النوع';

  @override
  String get attrLabel_sole_type => 'النعل';

  @override
  String get attrLabel_buoyancy_kg => 'الطفو';

  @override
  String get attrLabel_dry_weight_kg => 'الوزن الجاف';

  @override
  String get attrLabel_unit_type => 'نوع الجهاز';

  @override
  String get attrLabel_mount_configuration => 'طريقة التثبيت';

  @override
  String get attrLabel_scrubber_type => 'نوع الماص';

  @override
  String get attrLabel_scrubber_duration_h => 'مدة الماص (ساعة)';

  @override
  String get attrLabel_o2_cell_count => 'خلايا O2';

  @override
  String get attrLabel_diluent_cylinder_l => 'أسطوانة المخفف';

  @override
  String get attrLabel_o2_cylinder_l => 'أسطوانة O2';

  @override
  String get attrLabel_dpv_style => 'النمط';

  @override
  String get attrLabel_burn_time_h => 'زمن التشغيل';

  @override
  String get attrLabel_battery_type => 'البطارية';

  @override
  String get attrLabel_battery_capacity_wh => 'سعة البطارية (واط·ساعة)';

  @override
  String get attrLabel_motor_type => 'المحرك';

  @override
  String get attrLabel_speed_mps => 'السرعة القصوى';

  @override
  String get attrChoice_unit_type_eccr => 'CCR إلكتروني (eCCR)';

  @override
  String get attrChoice_unit_type_mccr => 'CCR يدوي (mCCR)';

  @override
  String get attrChoice_unit_type_hccr => 'CCR هجين (hCCR)';

  @override
  String get attrChoice_unit_type_scr_cmf => 'SCR - تدفق كتلي ثابت';

  @override
  String get attrChoice_unit_type_scr_pascr => 'SCR - إضافة سلبية';

  @override
  String get attrChoice_unit_type_scr_escr => 'SCR - تحكم إلكتروني';

  @override
  String get attrChoice_mount_configuration_back => 'تثبيت خلفي';

  @override
  String get attrChoice_mount_configuration_chest => 'تثبيت أمامي';

  @override
  String get attrChoice_mount_configuration_sidemount => 'تثبيت جانبي';

  @override
  String get attrChoice_scrubber_type_axial => 'محوري';

  @override
  String get attrChoice_scrubber_type_radial => 'شعاعي';

  @override
  String get attrChoice_suit_style_full => 'بدلة كاملة';

  @override
  String get attrChoice_suit_style_shorty => 'شورتي';

  @override
  String get attrChoice_suit_style_two_piece => 'قطعتان';

  @override
  String get attrChoice_suit_style_semi_dry => 'شبه جافة';

  @override
  String get attrChoice_shell_material_trilaminate => 'ثلاثي الطبقات';

  @override
  String get attrChoice_shell_material_neoprene => 'نيوبرين';

  @override
  String get attrChoice_shell_material_crushed_neoprene => 'نيوبرين مضغوط';

  @override
  String get attrChoice_shell_material_vulcanized_rubber => 'مطاط مفلكن';

  @override
  String get attrChoice_seal_type_latex => 'لاتكس';

  @override
  String get attrChoice_seal_type_silicone => 'سيليكون';

  @override
  String get attrChoice_seal_type_neoprene => 'نيوبرين';

  @override
  String get attrChoice_tank_material_aluminum => 'ألومنيوم';

  @override
  String get attrChoice_tank_material_steel => 'فولاذ';

  @override
  String get attrChoice_tank_material_carbon_composite => 'مركب كربوني';

  @override
  String get attrChoice_valve_type_din => 'DIN';

  @override
  String get attrChoice_valve_type_yoke => 'يوك (INT)';

  @override
  String get attrChoice_valve_type_convertible => 'قابل للتحويل';

  @override
  String get attrChoice_connection_din => 'DIN';

  @override
  String get attrChoice_connection_yoke => 'يوك (INT)';

  @override
  String get attrChoice_bcd_style_jacket => 'جاكيت';

  @override
  String get attrChoice_bcd_style_back_inflate => 'نفخ خلفي';

  @override
  String get attrChoice_bcd_style_wing => 'وينغ';

  @override
  String get attrChoice_bcd_style_sidemount => 'تثبيت جانبي';

  @override
  String get attrChoice_heel_type_open_heel => 'كعب مفتوح';

  @override
  String get attrChoice_heel_type_full_foot => 'قدم كاملة';

  @override
  String get attrChoice_blade_style_paddle => 'مجداف';

  @override
  String get attrChoice_blade_style_split => 'مشقوق';

  @override
  String get attrChoice_blade_style_vented => 'مهوى';

  @override
  String get attrChoice_mount_wrist => 'معصم';

  @override
  String get attrChoice_mount_console => 'كونسول';

  @override
  String get attrChoice_mount_hud => 'HUD';

  @override
  String get attrChoice_connectivity_ble => 'بلوتوث (BLE)';

  @override
  String get attrChoice_connectivity_usb => 'USB';

  @override
  String get attrChoice_connectivity_infrared => 'الأشعة تحت الحمراء';

  @override
  String get attrChoice_connectivity_none => 'بدون';

  @override
  String get attrChoice_lens_config_single => 'عدسة واحدة';

  @override
  String get attrChoice_lens_config_twin => 'عدستان';

  @override
  String get attrChoice_lens_config_frameless => 'بدون إطار';

  @override
  String get attrChoice_weight_style_belt => 'حزام';

  @override
  String get attrChoice_weight_style_integrated => 'مدمج';

  @override
  String get attrChoice_weight_style_trim => 'موازنة';

  @override
  String get attrChoice_weight_style_ankle => 'كاحل';

  @override
  String get attrChoice_beam_type_spot => 'سبوت';

  @override
  String get attrChoice_beam_type_flood => 'فيضي';

  @override
  String get attrChoice_beam_type_adjustable => 'قابل للتعديل';

  @override
  String get attrChoice_smb_type_open => 'مفتوح';

  @override
  String get attrChoice_smb_type_closed => 'مغلق';

  @override
  String get attrChoice_reel_type_spool => 'بكرة';

  @override
  String get attrChoice_reel_type_ratchet => 'بكرة بسقاطة';

  @override
  String get attrChoice_blade_material_stainless => 'فولاذ مقاوم للصدأ';

  @override
  String get attrChoice_blade_material_titanium => 'تيتانيوم';

  @override
  String get attrChoice_tip_type_pointed => 'مدبب';

  @override
  String get attrChoice_tip_type_blunt => 'غير حاد';

  @override
  String get attrChoice_tip_type_line_cutter => 'قاطع خيوط';

  @override
  String get attrChoice_glove_type_five_finger => 'خمسة أصابع';

  @override
  String get attrChoice_glove_type_mitt => 'قفاز كفي';

  @override
  String get attrChoice_glove_type_dry => 'جاف';

  @override
  String get attrChoice_sole_type_hard => 'نعل صلب';

  @override
  String get attrChoice_sole_type_soft => 'نعل لين';

  @override
  String get attrChoice_dpv_style_tow_behind => 'سحب خلفي';

  @override
  String get attrChoice_dpv_style_ride_on => 'ركوب';

  @override
  String get attrChoice_dpv_style_handheld => 'محمول باليد';

  @override
  String get attrChoice_battery_type_lithium_ion => 'ليثيوم أيون';

  @override
  String get attrChoice_battery_type_nimh => 'نيكل هيدريد فلزي';

  @override
  String get attrChoice_battery_type_lead_acid => 'حمض الرصاص';

  @override
  String get attrChoice_motor_type_brushless => 'بدون فرشات';

  @override
  String get attrChoice_motor_type_brushed => 'بفرشات';

  @override
  String get equipment_edit_customFieldsTitle => 'حقول مخصصة';

  @override
  String get equipment_edit_addCustomField => 'إضافة حقل مخصص';

  @override
  String get attr_flagYes => 'نعم';

  @override
  String get attr_flagNo => 'لا';

  @override
  String get equipment_edit_invalidThickness => 'استخدم 5 أو 5/4 أو 7/5/3';

  @override
  String get statistics_progression_divesBySuitThickness_title =>
      'الغطسات حسب سماكة البدلة';

  @override
  String get statistics_progression_divesBySuitThickness_subtitle =>
      'السماكة الأساسية لبدلة الغطس عبر غطساتك';

  @override
  String get statistics_progression_divesBySuitThickness_empty =>
      'لا توجد غطسات مسجلة بسماكة بدلة';

  @override
  String get statistics_progression_divesBySuitThickness_error =>
      'تعذر تحميل بيانات سماكة البدلة';

  @override
  String get diveLog_filter_sectionSuitThickness => 'سماكة البدلة (مم)';

  @override
  String get diveLog_filter_thicknessMin => 'الأدنى';

  @override
  String get diveLog_filter_thicknessMax => 'الأقصى';

  @override
  String get safetySettings_noFlyHeader => 'الطيران بعد الغوص';

  @override
  String get safetySettings_noFlyPreset_standard => 'قياسي (12/18/24 س)';

  @override
  String get safetySettings_noFlyPreset_strict => 'صارم (18/24/48 س)';

  @override
  String get safetySettings_noFlyPreset_subtitle =>
      'فترات إرشادية بعد غطسة واحدة بلا توقفات، وغطسات متكررة، وغطسات بتخفيف الضغط';

  @override
  String get flightWindow_closed => 'لا مزيد من الغوص قبل رحلتك';

  @override
  String get flightWindow_conflict =>
      'تمتد فترة حظر الطيران إلى ما بعد إقلاع رحلتك';

  @override
  String flightWindow_departs(String time) {
    return 'تقلع الرحلة $time';
  }

  @override
  String flightWindow_openTitle(String remaining) {
    return 'الوقت المتبقي للغوص: $remaining';
  }

  @override
  String flightWindow_surfaceBy(String time) {
    return 'اصعد إلى السطح قبل $time';
  }

  @override
  String safetyHub_noFly_active_title(String remaining) {
    return 'حظر الطيران: متبقٍ $remaining';
  }

  @override
  String safetyHub_noFly_until(String time) {
    return 'حتى $time';
  }

  @override
  String get safetyHub_noFly_clear_title => 'لا قيود على الطيران';

  @override
  String get safetyHub_noFly_clear_subtitle => 'لا يوجد قيد نشط على الطيران';

  @override
  String safetyHub_noFly_category_single(int hours) {
    return 'بعد غطسة واحدة بلا توقفات: إرشاد $hours ساعة';
  }

  @override
  String safetyHub_noFly_category_repetitive(int hours) {
    return 'بعد غطسات متكررة: إرشاد $hours ساعة';
  }

  @override
  String safetyHub_noFly_category_deco(int hours) {
    return 'بعد غطسة بتخفيف الضغط: إرشاد $hours ساعة';
  }

  @override
  String get safetyHub_noFly_disclaimer =>
      'إرشادات DAN/UHMS منذ آخر غطسة. ليست بديلاً عن وقت حظر الطيران في حاسوب الغوص الخاص بك.';

  @override
  String get diveLog_detail_altitudeMismatch_title => 'موقع الغوص على ارتفاع';

  @override
  String get diveLog_detail_altitudeMismatch_subtitle =>
      'هذا الموقع مسجل له ارتفاع لكن الغطسة بلا ارتفاع، لذا افترض تحليل تخفيف الضغط مستوى سطح البحر. عيّن ارتفاع الغطسة للتصحيح.';

  @override
  String diveLog_detail_sacVolumeHint(String unit) {
    return 'أضف حجم الأسطوانة لعرض معدل SAC بوحدة $unit/min';
  }

  @override
  String safetyHub_alert_noFly(String remaining) {
    return 'حظر الطيران: متبقٍ $remaining';
  }

  @override
  String get emergencyCard_title => 'الطوارئ';

  @override
  String emergencyCard_callDan(String name) {
    return 'اتصل بـ $name';
  }

  @override
  String get emergencyCard_callDan_subtitle =>
      'خط طوارئ الغواصين. اتصل به أولاً: فهم ينسقون الإخلاء والإحالة إلى غرفة الضغط.';

  @override
  String emergencyCard_ems(String number) {
    return 'خدمات الطوارئ المحلية: $number';
  }

  @override
  String get emergencyCard_diverSection => 'الغواص';

  @override
  String emergencyCard_bloodType(String value) {
    return 'فصيلة الدم: $value';
  }

  @override
  String emergencyCard_allergies(String value) {
    return 'الحساسية: $value';
  }

  @override
  String emergencyCard_medications(String value) {
    return 'الأدوية: $value';
  }

  @override
  String get emergencyCard_contactsSection => 'جهات اتصال الطوارئ';

  @override
  String get emergencyCard_insuranceSection => 'تأمين الغوص';

  @override
  String emergencyCard_insurancePolicy(String number) {
    return 'وثيقة $number';
  }

  @override
  String get emergencyCard_chambersSection => 'غرف الضغط العالي';

  @override
  String get emergencyCard_chambersNote =>
      'التوفر يتغير. اتصل دائمًا بخط طوارئ الغواصين أولاً للإحالة.';

  @override
  String emergencyCard_chamberVerified(String date) {
    return 'تم التحقق من البيانات $date';
  }

  @override
  String get emergencyCard_chambersNearby => 'أقرب غرف الضغط';

  @override
  String emergencyCard_chamberViewAll(int count) {
    return 'عرض جميع غرف الضغط ($count)';
  }

  @override
  String get emergencyCard_chambersNoneNearby =>
      'لا توجد غرفة ضغط ضمن النطاق. اتصل بخط الطوارئ للغواصين: سيحيلونك إلى أقرب منشأة قادرة على علاجك.';

  @override
  String get emergencyCard_chamberCapability_divingEmergency =>
      'يعالج إصابات الغوص';

  @override
  String get emergencyCard_chamberCapability_hyperbaricUnit =>
      'وحدة ضغط عالٍ بمستشفى';

  @override
  String get emergencyCard_chamberCapability_elective => 'علاج مجدول فقط';

  @override
  String get emergencyCard_chamberCapability_unknown => 'القدرة غير مؤكدة';

  @override
  String get emergencyCard_chamberAvailability_h24 => '٢٤ ساعة';

  @override
  String get emergencyCard_chamberAvailability_onCall => 'تحت الطلب';

  @override
  String get emergencyCard_chamberAvailability_businessHours => 'ساعات العمل';

  @override
  String get emergencyCard_chamberUnverified => 'غير مؤكد مع المنشأة';

  @override
  String get chambersDirectory_title => 'غرف الضغط العالي';

  @override
  String get chambersDirectory_search => 'ابحث بالاسم أو المدينة أو الدولة';

  @override
  String get chambersDirectory_empty => 'لا توجد غرفة ضغط تطابق البحث.';

  @override
  String chambersDirectory_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غرف ضغط',
      one: 'غرفة ضغط واحدة',
    );
    return '$_temp0';
  }

  @override
  String get emergencyCard_hideChamber => 'إخفاء';

  @override
  String get emergencyCard_chamberHidden => 'تم إخفاء الغرفة';

  @override
  String get emergencyCard_undo => 'تراجع';

  @override
  String get emergencyCard_addChamber => 'إضافة غرفة';

  @override
  String get emergencyCard_deleteChamber => 'حذف';

  @override
  String emergencyCard_regionLabel(String region) {
    return 'المنطقة: $region';
  }

  @override
  String get emergencyCard_regionUnknown =>
      'المنطقة غير معروفة - يُستخدم الخط العالمي';

  @override
  String get emergencyCard_noDiverData =>
      'لا توجد بيانات ملف الغواص. أضف جهات اتصال الطوارئ والبيانات الطبية والتأمين في ملف الغواص.';

  @override
  String get addChamber_title => 'إضافة غرفة';

  @override
  String get addChamber_name => 'الاسم';

  @override
  String get addChamber_country => 'رمز الدولة (مثل EG)';

  @override
  String get addChamber_city => 'المدينة';

  @override
  String get addChamber_phone => 'الهاتف';

  @override
  String get addChamber_notes => 'ملاحظات';

  @override
  String get addChamber_save => 'حفظ';

  @override
  String get addChamber_nameRequired => 'الاسم مطلوب';

  @override
  String get addChamber_countryRequired => 'رمز الدولة مطلوب';

  @override
  String get addChamber_phoneRequired => 'رقم الهاتف مطلوب';

  @override
  String get safetyHub_emergencyCardLink => 'بطاقة الطوارئ';

  @override
  String get safetyHub_emergencyCardLink_subtitle =>
      'دون اتصال: الخط الساخن، الطوارئ، الغرف، بياناتك الطبية والتأمينية';

  @override
  String get dashboard_quickAction_emergency => 'بطاقة الطوارئ';

  @override
  String get incidents_title => 'سجل الحوادث الوشيكة';

  @override
  String get incidents_empty =>
      'لا حوادث وشيكة مسجلة. تدوين ما كاد أن يسوء - دون إصدار أحكام - يجعل الأنماط مرئية قبل أن تتحول إلى حوادث.';

  @override
  String get incidents_add => 'تسجيل حادث وشيك';

  @override
  String get incidents_linkedDive => 'مرتبط بغطسة';

  @override
  String get incidents_delete_confirm => 'حذف تقرير الحادث الوشيك هذا؟';

  @override
  String get incidents_notFound => 'لم يتم العثور على تقرير الحادث الوشيك';

  @override
  String get incidentEdit_title_new => 'تسجيل حادث وشيك';

  @override
  String get incidentEdit_title_edit => 'تعديل الحادث الوشيك';

  @override
  String get incidentEdit_category => 'الفئة';

  @override
  String get incidentEdit_severity => 'الخطورة';

  @override
  String get incidentEdit_severity_minor => 'طفيف';

  @override
  String get incidentEdit_severity_moderate => 'متوسط';

  @override
  String get incidentEdit_severity_serious => 'خطير';

  @override
  String get incidentEdit_date => 'متى حدث';

  @override
  String get incidentEdit_narrative => 'ماذا حدث';

  @override
  String get incidentEdit_narrative_hint =>
      'الحقائق فقط، بكلماتك. يبقى هذا خاصًا.';

  @override
  String get incidentEdit_narrative_required => 'صف ما حدث';

  @override
  String get incidentEdit_contributingFactors => 'ما الذي ساهم (اختياري)';

  @override
  String get incidentEdit_lessonsLearned =>
      'ما الذي سيساعد المرة القادمة (اختياري)';

  @override
  String get incidentEdit_save => 'حفظ';

  @override
  String get incidentEdit_privacyNote =>
      'تتزامن تقارير الحوادث الوشيكة بين أجهزتك وتُضمَّن في النسخ الاحتياطية، لكنها لا تُضمَّن أبدًا في التصدير أو صفحات السجل المشتركة.';

  @override
  String get incidentCategory_buoyancy => 'الطفو';

  @override
  String get incidentCategory_gasSupply => 'إمداد الغاز';

  @override
  String get incidentCategory_equipment => 'المعدات';

  @override
  String get incidentCategory_buddySeparation => 'الانفصال عن الرفيق';

  @override
  String get incidentCategory_marineLife => 'الحياة البحرية';

  @override
  String get incidentCategory_boatSurface => 'القارب / السطح';

  @override
  String get incidentCategory_medical => 'طبي';

  @override
  String get incidentCategory_planning => 'التخطيط';

  @override
  String get incidentCategory_other => 'أخرى';

  @override
  String get safetyHub_incidentsLink => 'سجل الحوادث الوشيكة';

  @override
  String get safetyHub_incidentsLink_subtitle =>
      'ملاحظات حوادث خاصة وغير عقابية';

  @override
  String get diveLog_detail_menu_logNearMiss => 'تسجيل حادث وشيك';

  @override
  String diveLog_detail_linkedIncidents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حوادث وشيكة مرتبطة بهذه الغطسة',
      one: 'حادث وشيك واحد مرتبط بهذه الغطسة',
    );
    return '$_temp0';
  }

  @override
  String get planning_card_noFly_subtitle => 'عدّاد إرشادي منذ آخر غطساتك';

  @override
  String get settings_section_safety_title => 'السلامة';

  @override
  String get settings_section_safety_subtitle =>
      'قواعد المراجعة والطيران بعد الغوص';

  @override
  String get settings_section_security_title => 'أمان التطبيق';

  @override
  String get settings_section_security_subtitle =>
      'قفل التطبيق وتشفير قاعدة البيانات';

  @override
  String get settings_security_appLock => 'قفل التطبيق';

  @override
  String get settings_security_appLock_subtitle =>
      'طلب كلمة المرور أو القياسات الحيوية لفتح التطبيق';

  @override
  String get settings_security_biometrics => 'فتح القفل بالقياسات الحيوية';

  @override
  String get settings_security_autoLock => 'القفل التلقائي';

  @override
  String get settings_security_autoLock_immediately => 'فورًا';

  @override
  String settings_security_autoLock_minutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'بعد $minutes دقائق',
      one: 'بعد دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get settings_security_autoLock_never => 'أبدًا';

  @override
  String get settings_security_encryption => 'تشفير قاعدة البيانات';

  @override
  String get settings_security_encryption_subtitle =>
      'احمِ ملف سجل الغوص الخاص بك بالتشفير أثناء التخزين. قد يؤثر التشفير على الأداء.';

  @override
  String get settings_security_encryption_progress_backup =>
      'جارٍ إنشاء نسخة احتياطية...';

  @override
  String get settings_security_encryption_progress_encrypt =>
      'جارٍ تشفير قاعدة البيانات...';

  @override
  String get settings_security_encryption_progress_decrypt =>
      'جارٍ فك تشفير قاعدة البيانات...';

  @override
  String get settings_security_encryption_progress_reopen =>
      'جارٍ إعادة فتح قاعدة البيانات...';

  @override
  String get settings_security_changePassword => 'تغيير كلمة المرور';

  @override
  String get settings_security_regenerateRecovery => 'رمز استرداد جديد';

  @override
  String get settings_security_setPassword => 'تعيين كلمة مرور التطبيق';

  @override
  String get settings_security_password => 'كلمة المرور';

  @override
  String get settings_security_confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get settings_security_currentPassword => 'كلمة المرور الحالية';

  @override
  String get settings_security_newPassword => 'كلمة المرور الجديدة';

  @override
  String get settings_security_passwordTooShort =>
      'يجب أن تتكون كلمة المرور من 4 أحرف على الأقل.';

  @override
  String get settings_security_passwordMismatch =>
      'كلمتا المرور غير متطابقتين.';

  @override
  String get settings_security_wrongPassword => 'كلمة المرور غير صحيحة.';

  @override
  String get settings_security_recoveryCode_title => 'رمز الاسترداد الخاص بك';

  @override
  String get settings_security_recoveryCode_explain =>
      'دوّنه واحفظه في مكان آمن. إنه الطريقة الوحيدة لفتح التطبيق إذا نسيت كلمة المرور، وهو يحل محل أي رمز استرداد سابق.';

  @override
  String get settings_security_recoveryCode_savedConfirm =>
      'لقد حفظت رمز الاسترداد الخاص بي';

  @override
  String get settings_security_disableBlockedByEncryption_title =>
      'التشفير مفعّل';

  @override
  String get settings_security_disableBlockedByEncryption_body =>
      'أوقف تشفير قاعدة البيانات أولاً قبل إيقاف قفل التطبيق. تحتاج قاعدة البيانات المشفرة إلى بيانات اعتماد.';

  @override
  String get settings_security_enableEncryption_title =>
      'هل تريد تشفير قاعدة البيانات؟';

  @override
  String get settings_security_enableEncryption_body =>
      'يتم أولاً إنشاء نسخة احتياطية، ثم يُعاد تشفير ملف قاعدة البيانات في مكانه. قد يستغرق ذلك وقتًا مع السجلات الكبيرة. قد يؤثر التشفير على الأداء.';

  @override
  String get settings_security_disableEncryption_title =>
      'هل تريد إيقاف التشفير؟';

  @override
  String get settings_security_disableEncryption_body =>
      'سيُخزَّن ملف قاعدة البيانات على القرص من دون تشفير مرة أخرى.';

  @override
  String get settings_security_turnOffAppLock_title =>
      'هل تريد إيقاف قفل التطبيق؟';

  @override
  String get settings_security_turnOffAppLock_body =>
      'سيُفتح التطبيق من دون طلب كلمة المرور.';

  @override
  String get settings_security_unlock_title => 'أدخل كلمة المرور';

  @override
  String get settings_security_cancel => 'إلغاء';

  @override
  String get settings_security_continue => 'متابعة';

  @override
  String get settings_security_done => 'تم';

  @override
  String get settings_security_turnOff => 'إيقاف';

  @override
  String get dataQuality_inbox_title => 'جودة البيانات';

  @override
  String get dataQuality_badge_tooltip => 'مراجعة جودة البيانات';

  @override
  String get dataQuality_scan_start => 'فحص المكتبة';

  @override
  String dataQuality_scan_progress(int done, int total) {
    return 'تم فحص $done من $total غوصة';
  }

  @override
  String get dataQuality_scan_cancel => 'إلغاء';

  @override
  String dataQuality_scan_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'اكتمل الفحص - $count عناصر للمراجعة',
      one: 'اكتمل الفحص - عنصر واحد للمراجعة',
      zero: 'اكتمل الفحص - لا توجد نتائج جديدة',
    );
    return '$_temp0';
  }

  @override
  String dataQuality_scan_errors(int count) {
    return 'تعذّر فحص $count غوصة بالكامل';
  }

  @override
  String dataQuality_lastScan(String when) {
    return 'آخر فحص: $when';
  }

  @override
  String get dataQuality_neverScanned => 'لم يتم فحص سجل الغوص الخاص بك بعد';

  @override
  String get dataQuality_empty_title => 'كل شيء على ما يرام';

  @override
  String get dataQuality_empty_subtitle =>
      'لا توجد نتائج تخص جودة البيانات. افحص مكتبتك للتحقق من مشكلات الغوصات المستوردة.';

  @override
  String get dataQuality_banner_newChecks => 'تتوفر فحوصات جودة جديدة';

  @override
  String get dataQuality_banner_rescan => 'إعادة الفحص';

  @override
  String get dataQuality_action_dismiss => 'تجاهل';

  @override
  String get dataQuality_action_dismissFiltered => 'تجاهل كل ما هو معروض';

  @override
  String get dataQuality_action_goToDive => 'الانتقال إلى الغوصة';

  @override
  String get dataQuality_action_undo => 'تراجع';

  @override
  String get dataQuality_repair_applied => 'تم تطبيق الإصلاح';

  @override
  String get dataQuality_repair_noChange => 'لا يوجد ما يمكن إصلاحه هنا';

  @override
  String get dataQuality_repair_needsReview =>
      'لا يوجد إصلاح تلقائي. افتح الغطسة لتصحيح ذلك.';

  @override
  String get dataQuality_repair_failed => 'فشل الإصلاح';

  @override
  String get dataQuality_chip_all => 'الكل';

  @override
  String get dataQuality_chip_time => 'الوقت';

  @override
  String get dataQuality_chip_profile => 'المخطط';

  @override
  String get dataQuality_chip_gas => 'الغاز';

  @override
  String get dataQuality_chip_tanks => 'الأسطوانات';

  @override
  String get dataQuality_chip_duplicates => 'التكرارات';

  @override
  String get dataQuality_chip_sources => 'المصادر';

  @override
  String get dataQuality_detector_clock_offset => 'الساعة والمنطقة الزمنية';

  @override
  String get dataQuality_detector_duplicate => 'تكرار محتمل';

  @override
  String get dataQuality_detector_split_pair => 'تقسيم غير مقصود';

  @override
  String get dataQuality_detector_sample_gap => 'فجوات في العينات';

  @override
  String get dataQuality_detector_depth_spike => 'قفزة في العمق';

  @override
  String get dataQuality_detector_impossible_rate => 'معدل مستحيل';

  @override
  String get dataQuality_detector_temp_anomaly => 'خلل في درجة الحرارة';

  @override
  String get dataQuality_detector_pressure_anomaly => 'خلل في الضغط';

  @override
  String get dataQuality_detector_gas_mod => 'تعارض بين الغاز وMOD';

  @override
  String get dataQuality_detector_tank_assignment => 'أسطوانة خاطئة';

  @override
  String get dataQuality_detector_source_conflict => 'مصادر متعارضة';

  @override
  String dataQuality_msg_clock_future(String date) {
    return 'تاريخ الغوصة في المستقبل ($date)';
  }

  @override
  String dataQuality_msg_clock_ancient(String date) {
    return 'تاريخ الغوصة قبل عام 1950 ($date)';
  }

  @override
  String dataQuality_msg_clock_offset(int hours) {
    return 'تختلف ساعة أحد المصادر بمقدار $hours ساعة';
  }

  @override
  String dataQuality_msg_clock_overlap(int minutes) {
    return 'تتداخل مع غوصة أخرى بمقدار $minutes دقيقة';
  }

  @override
  String dataQuality_msg_duplicate(int percent, int minutes) {
    return 'تطابق بنسبة $percent% مع غوصة تفصلها $minutes دقيقة';
  }

  @override
  String dataQuality_msg_split(int minutes) {
    return 'استؤنف الكمبيوتر نفسه بعد فترة سطح مدتها $minutes دقيقة';
  }

  @override
  String dataQuality_msg_gap(int count, String longest) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فجوات في العينات',
      one: 'فجوة واحدة في العينات',
    );
    return '$_temp0، أطولها $longest';
  }

  @override
  String dataQuality_msg_spike(String depth, String time) {
    return 'قفزة في العمق إلى $depth عند $time';
  }

  @override
  String dataQuality_msg_negativeDepth(int count) {
    return '$count عينات عمق سالبة';
  }

  @override
  String dataQuality_msg_maxDepthMismatch(String stored, String profile) {
    return 'العمق الأقصى المسجّل $stored لكن المخطط يُظهر $profile';
  }

  @override
  String dataQuality_msg_rate(String rate, int seconds) {
    return 'معدل رأسي قدره $rate استمر لمدة $seconds ثانية';
  }

  @override
  String dataQuality_msg_tempRange(String min, String max) {
    return 'درجة حرارة الماء خارج النطاق المعقول ($min إلى $max)';
  }

  @override
  String get dataQuality_msg_tempUnitBug =>
      'تبدو القيم وكأنها خطأ في وحدة درجة الحرارة';

  @override
  String dataQuality_msg_tempJump(String delta) {
    return 'قفزت درجة الحرارة $delta في عينة واحدة';
  }

  @override
  String dataQuality_msg_tempScalar(String temp) {
    return 'درجة حرارة الماء المسجّلة $temp غير معقولة';
  }

  @override
  String dataQuality_msg_pressureSwap(String end, String start) {
    return 'ضغط النهاية $end أعلى من ضغط البداية $start';
  }

  @override
  String dataQuality_msg_pressureEndpoint(String record, String series) {
    return 'يذكر سجل الأسطوانة $record لكن سلسلة المستشعر تُظهر $series';
  }

  @override
  String dataQuality_msg_pressureRise(String rise) {
    return 'ارتفع الضغط $rise في منتصف الغوصة دون تبديل للغاز';
  }

  @override
  String dataQuality_msg_sac(String sac) {
    return 'معدل الاستهلاك السطحي الضمني $sac غير معقول';
  }

  @override
  String dataQuality_msg_ppo2(String ppo2, String gas, String depth) {
    return 'بلغ ppO2 القيمة $ppo2 على $gas عند $depth';
  }

  @override
  String dataQuality_msg_hypoxic(String gas) {
    return 'يظهر خليط ناقص الأكسجين ($gas) قيد الاستخدام عند السطح';
  }

  @override
  String dataQuality_msg_switchMod(String depth, String mod) {
    return 'تبديل الغاز عند $depth يتجاوز الحد الأقصى للعمق (MOD) لذلك الغاز البالغ $mod';
  }

  @override
  String dataQuality_msg_tankInactive(String drop) {
    return 'فقدت هذه الأسطوانة $drop بينما يشير الخط الزمني للغاز إلى أنها لم تكن قيد الاستخدام';
  }

  @override
  String get dataQuality_msg_twinTanks =>
      'تحمل أسطوانتان سلسلة ضغط شبه متطابقة';

  @override
  String dataQuality_msg_sourceDepth(String primary, String source) {
    return 'تختلف المصادر حول العمق الأقصى: $primary مقابل $source';
  }

  @override
  String get dataQuality_msg_salinityHint =>
      'تشير النسبة الثابتة إلى اختلاف في إعداد الماء المالح/العذب';

  @override
  String get dataQuality_msg_sourceDuration => 'تختلف المصادر حول مدة الغوصة';

  @override
  String get dataQuality_msg_sourceTemp => 'تختلف المصادر حول درجة حرارة الماء';

  @override
  String dataQuality_repairLabel_shiftTime(String offset) {
    return 'إزاحة الوقت بمقدار $offset';
  }

  @override
  String get dataQuality_repairLabel_shiftImport =>
      'إزاحة كل الغوصات من هذا الاستيراد';

  @override
  String get dataQuality_repairLabel_consolidate => 'توحيد';

  @override
  String get dataQuality_repairLabel_combine => 'دمج في غوصة واحدة';

  @override
  String get dataQuality_repairLabel_despike => 'إزالة القفزة';

  @override
  String get dataQuality_repairLabel_clampNegative => 'تثبيت الأعماق فوق السطح';

  @override
  String get dataQuality_repairLabel_smoothRates => 'تنعيم المعدلات المستحيلة';

  @override
  String get dataQuality_repairLabel_fillGaps => 'ملء الفجوات';

  @override
  String get dataQuality_repairLabel_smoothTemp => 'تنعيم درجة الحرارة';

  @override
  String get dataQuality_repairLabel_convertTemp => 'تحويل درجة الحرارة';

  @override
  String get dataQuality_repairLabel_recompute => 'إعادة الحساب من المخطط';

  @override
  String get dataQuality_repairLabel_swapPressures =>
      'تبديل ضغط البداية/النهاية';

  @override
  String get dataQuality_repairLabel_setFromSeries => 'استخدام قيم المستشعر';

  @override
  String get dataQuality_repairLabel_swapSeries => 'تبديل سلاسل الأسطوانات';

  @override
  String get dataQuality_repairLabel_reassignSeries =>
      'نقل السلسلة إلى أسطوانة أخرى';

  @override
  String get dataQuality_repairLabel_setPrimary => 'جعل هذا المصدر أساسيًا';

  @override
  String get dataQuality_repairLabel_split => 'التقسيم إلى غوصات منفصلة';

  @override
  String get dataQuality_repairLabel_compare => 'مقارنة المخططات';

  @override
  String get dataQuality_settings_title => 'جودة البيانات';

  @override
  String get dataQuality_settings_subtitle =>
      'اختر الفحوصات التي تُجرى أثناء الفحص';

  @override
  String dataQuality_summary_flagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عناصر مُعلَّمة للمراجعة',
      one: 'عنصر واحد مُعلَّم للمراجعة',
    );
    return '$_temp0';
  }

  @override
  String get dataQuality_summary_review => 'مراجعة';

  @override
  String get dataQuality_detail_chip => 'مراجعة';

  @override
  String dataQuality_detail_chipCount(int count) {
    return 'مراجعة ($count)';
  }

  @override
  String get settings_mediaStorage_quality_section => 'جودة الرفع';

  @override
  String get settings_mediaStorage_quality_photos => 'الصور';

  @override
  String get settings_mediaStorage_quality_video => 'الفيديو';

  @override
  String get settings_mediaStorage_quality_original => 'الأصلية';

  @override
  String get settings_mediaStorage_quality_high => 'عالية';

  @override
  String get settings_mediaStorage_quality_balanced => 'متوازنة';

  @override
  String get settings_mediaStorage_quality_small => 'صغيرة';

  @override
  String get settings_mediaStorage_quality_caveat =>
      'عند تعيين مستوى ضغط، لا يتم رفع النسخ الأصلية بالدقة الكاملة؛ فهي تبقى على هذا الجهاز فقط.';

  @override
  String get settings_mediaStorage_quality_reuploadQueued =>
      'تمت إضافة إعادة الرفع إلى قائمة الانتظار';

  @override
  String get settings_mediaStorage_quality_linuxFfmpegHint =>
      'ثبّت ffmpeg لتمكين ضغط الفيديو. حتى ذلك الحين يتم رفع النسخ الأصلية.';

  @override
  String get settings_mediaStorage_quality_saveFailed =>
      'تعذّر حفظ جودة الرفع. حاول مرة أخرى.';

  @override
  String get settings_mediaStorage_quality_noTranscoderHint =>
      'لا يمكن لهذا الجهاز ضغط الفيديو. يتم رفع الملفات الأصلية منه.';

  @override
  String get reef_section_title => 'النظام البيئي';

  @override
  String get reef_section_sourcesTooltip => 'مصادر البيانات';

  @override
  String get reef_section_loadError => 'تعذّر تحميل بيانات النظام البيئي الآن';

  @override
  String get reef_habitat_title => 'موئل الشعاب';

  @override
  String get reef_habitat_onReef => 'على شعاب مرجانية';

  @override
  String reef_habitat_onReefWithThreat(String threat) {
    return 'على شعاب مرجانية، مستوى التهديد $threat';
  }

  @override
  String get reef_habitat_noReef => 'لا توجد شعاب مرجانية مرسومة في هذا الموقع';

  @override
  String get reef_habitat_unavailable => 'تعذر التحقق من موئل الشعاب الآن';

  @override
  String get water_conditions_title => 'أحوال المياه';

  @override
  String get water_conditions_unavailable =>
      'تعذّر التحقق من أحوال المياه الآن';

  @override
  String get water_conditions_noData =>
      'لا توجد بيانات مياه من الأقمار الصناعية لهذا الموقع';

  @override
  String get water_conditions_freshwater =>
      'درجة حرارة المياه عبر الأقمار الصناعية تغطي المحيطات فقط';

  @override
  String water_conditions_anomaly(String value) {
    return 'شذوذ $value';
  }

  @override
  String reef_health_degreeHeatingWeeks(String value) {
    return 'أسابيع الحرارة المتراكمة $value درجة-أسبوع';
  }

  @override
  String reef_health_seaSurface(String value) {
    return 'سطح البحر $value';
  }

  @override
  String reef_health_asOf(String date) {
    return 'حتى $date';
  }

  @override
  String get reef_health_levelNoStress => 'لا يوجد إجهاد حراري';

  @override
  String get reef_health_levelWatch => 'مراقبة الابيضاض';

  @override
  String get reef_health_levelWarning => 'تحذير من الابيضاض';

  @override
  String get reef_health_levelAlert1 => 'إنذار ابيضاض المستوى 1';

  @override
  String get reef_health_levelAlert2 => 'إنذار ابيضاض المستوى 2';

  @override
  String get reef_health_levelAlert3 => 'إنذار ابيضاض المستوى 3';

  @override
  String get reef_health_levelAlert4 => 'إنذار ابيضاض المستوى 4';

  @override
  String get reef_health_levelAlert5 => 'إنذار ابيضاض المستوى 5';

  @override
  String get reef_protection_title => 'منطقة محمية';

  @override
  String get reef_protection_none => 'ليست ضمن منطقة بحرية محمية';

  @override
  String get reef_protection_unavailable => 'تعذر التحقق من حالة الحماية الآن';

  @override
  String get reef_protection_viewRegulations => 'عرض اللوائح';

  @override
  String reef_protection_iucn(String category) {
    return 'IUCN $category';
  }

  @override
  String get reef_species_recordedNearby => 'مسجل في الجوار';

  @override
  String get reef_species_addToExpected => 'إضافة إلى الأنواع المتوقعة';

  @override
  String reef_species_showAll(int count) {
    return 'عرض الكل ($count)';
  }

  @override
  String get reef_species_showFewer => 'عرض أقل';

  @override
  String get reef_attribution_title => 'مصادر بيانات الشعاب';

  @override
  String get reef_attribution_wri => 'وجود الشعاب ومستوى التهديد. CC BY 3.0.';

  @override
  String get reef_attribution_noaa =>
      'درجة حرارة سطح البحر والإجهاد الحراري. ملكية عامة.';

  @override
  String get reef_attribution_gbif =>
      'سجلات تواجد الأنواع، مصفاة على CC0 و CC BY 4.0.';

  @override
  String get reef_attribution_protectedSeas =>
      'حدود المناطق البحرية المحمية. CC BY 4.0.';

  @override
  String get enum_visibilityBand_excellent => 'ممتازة';

  @override
  String get enum_visibilityBand_good => 'جيدة';

  @override
  String get enum_visibilityBand_moderate => 'متوسطة';

  @override
  String get enum_visibilityBand_poor => 'ضعيفة';

  @override
  String visibility_range_between(String min, String max, String unit) {
    return '$min-$max $unit';
  }

  @override
  String visibility_range_over(String min, String unit) {
    return 'أكثر من $min $unit';
  }

  @override
  String visibility_range_under(String max, String unit) {
    return 'أقل من $max $unit';
  }

  @override
  String get settings_coordinateFormat_title => 'تنسيق الإحداثيات';

  @override
  String get settings_coordinateFormat_subtitle =>
      'كيفية عرض مواقع GPS وإدخالها';

  @override
  String get settings_placeNameLanguage_title => 'لغة أسماء الأماكن';

  @override
  String get settings_placeNameLanguage_subtitle =>
      'تُستخدم عند البحث عن البلد والمنطقة والبلدة والمسطح المائي من الإحداثيات. لا يتم تغيير المواقع الحالية.';

  @override
  String get settings_coordinateFormat_decimalDegrees => 'درجات عشرية';

  @override
  String get settings_coordinateFormat_degreesDecimalMinutes =>
      'درجات ودقائق عشرية';

  @override
  String get settings_coordinateFormat_degreesMinutesSeconds =>
      'درجات ودقائق وثوانٍ';

  @override
  String get settings_coordinateFormat_utm => 'UTM';

  @override
  String get settings_coordinateFormat_mgrs => 'MGRS';

  @override
  String get settings_visibilityScale_title => 'مقياس الرؤية';

  @override
  String get settings_visibilityScale_subtitle =>
      'المسافات التي تُعد رؤية جيدة في مواقع غوصك';

  @override
  String get settings_visibilityScale_preset_tropical => 'استوائية';

  @override
  String get settings_visibilityScale_preset_temperate => 'معتدلة';

  @override
  String get settings_visibilityScale_preset_coldWater => 'مياه باردة / داخلية';

  @override
  String get settings_visibilityScale_preset_custom => 'مخصصة';

  @override
  String get settings_visibilityScale_customExcellent => 'ممتازة عند أو فوق';

  @override
  String get settings_visibilityScale_customGood => 'جيدة عند أو فوق';

  @override
  String get settings_visibilityScale_customModerate => 'متوسطة عند أو فوق';

  @override
  String get settings_visibilityScale_invalidOrder =>
      'يجب أن تكون كل قيمة أصغر من التي فوقها وأكبر من صفر';

  @override
  String statistics_conditions_visibility_legacySuffix(String band) {
    return '$band (مسجلة قبل القياس)';
  }

  @override
  String common_selection_countSelected(Object count) {
    return '$count محدد';
  }

  @override
  String get common_selection_enterTooltip => 'تحديد العناصر';

  @override
  String get common_selection_exitTooltip => 'إنهاء التحديد';

  @override
  String get common_selection_selectAllTooltip => 'تحديد الكل';

  @override
  String get common_selection_deselectAllTooltip => 'إلغاء تحديد الكل';

  @override
  String common_bulkDelete_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حذف $count عنصر؟',
      many: 'حذف $count عنصرا؟',
      few: 'حذف $count عناصر؟',
      two: 'حذف عنصرين؟',
      one: 'حذف عنصر واحد؟',
      zero: 'حذف $count عنصر؟',
    );
    return '$_temp0';
  }

  @override
  String get common_bulkDelete_body => 'لا يمكن التراجع عن هذا.';

  @override
  String common_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حذف $count',
      many: 'تم حذف $count',
      few: 'تم حذف $count',
      two: 'تم حذف عنصرين',
      one: 'تم حذف عنصر واحد',
      zero: 'تم حذف $count',
    );
    return '$_temp0';
  }

  @override
  String get marineLife_species_delete_confirmTitle => 'حذف النوع؟';

  @override
  String marineLife_species_delete_confirmBody(String name) {
    return 'هل تريد بالتأكيد حذف \"$name\"؟';
  }

  @override
  String marineLife_species_delete_inUseError(String name) {
    return 'لا يمكن حذف \"$name\" - لديه مشاهدات';
  }

  @override
  String marineLife_species_delete_snackbar(String name) {
    return 'تم حذف \"$name\"';
  }

  @override
  String marineLife_species_delete_error(String error) {
    return 'خطأ في حذف النوع: $error';
  }

  @override
  String get enum_diveField_diveNumber => 'رقم الغوصة';

  @override
  String get enum_diveField_dateTime => 'التاريخ والوقت';

  @override
  String get enum_diveField_siteName => 'اسم الموقع';

  @override
  String get enum_diveField_diveName => 'اسم الغوصة';

  @override
  String get enum_diveField_maxDepth => 'أقصى عمق';

  @override
  String get enum_diveField_avgDepth => 'متوسط العمق';

  @override
  String get enum_diveField_bottomTime => 'وقت القاع';

  @override
  String get enum_diveField_runtime => 'وقت التشغيل';

  @override
  String get enum_diveField_waterTemp => 'حرارة الماء';

  @override
  String get enum_diveField_airTemp => 'حرارة الهواء';

  @override
  String get enum_diveField_visibility => 'الرؤية';

  @override
  String get enum_diveField_currentDirection => 'اتجاه التيار';

  @override
  String get enum_diveField_currentStrength => 'قوة التيار';

  @override
  String get enum_diveField_swellHeight => 'ارتفاع الموج';

  @override
  String get enum_diveField_entryMethod => 'طريقة الدخول';

  @override
  String get enum_diveField_exitMethod => 'طريقة الخروج';

  @override
  String get enum_diveField_waterType => 'نوع المياه';

  @override
  String get enum_diveField_altitude => 'الارتفاع';

  @override
  String get enum_diveField_surfacePressure => 'ضغط السطح';

  @override
  String get enum_diveField_windSpeed => 'سرعة الرياح';

  @override
  String get enum_diveField_cloudCover => 'الغطاء السحابي';

  @override
  String get enum_diveField_precipitation => 'هطول الأمطار';

  @override
  String get enum_diveField_humidity => 'الرطوبة';

  @override
  String get enum_diveField_weatherDescription => 'الطقس';

  @override
  String get enum_diveField_primaryGas => 'الغاز الأساسي';

  @override
  String get enum_diveField_diluentGas => 'غاز المخفف';

  @override
  String get enum_diveField_tankCount => 'عدد الأسطوانات';

  @override
  String get enum_diveField_startPressure => 'ضغط البداية';

  @override
  String get enum_diveField_endPressure => 'ضغط النهاية';

  @override
  String get enum_diveField_sacRate => 'معدل SAC';

  @override
  String get enum_diveField_gasConsumed => 'الغاز المستهلك';

  @override
  String get enum_diveField_totalWeight => 'الوزن الإجمالي';

  @override
  String get enum_diveField_diveComputerModel => 'حاسوب الغوص';

  @override
  String get enum_diveField_gradientFactorLow => 'GF منخفض';

  @override
  String get enum_diveField_gradientFactorHigh => 'GF مرتفع';

  @override
  String get enum_diveField_decoAlgorithm => 'خوارزمية إزالة التشبع';

  @override
  String get enum_diveField_decoConservatism => 'التحفظ';

  @override
  String get enum_diveField_cnsStart => 'CNS البداية';

  @override
  String get enum_diveField_cnsEnd => 'CNS النهاية';

  @override
  String get enum_diveField_otu => 'OTU';

  @override
  String get enum_diveField_diveMode => 'وضع الغوص';

  @override
  String get enum_diveField_setpointLow => 'النقطة المحددة المنخفضة';

  @override
  String get enum_diveField_setpointHigh => 'النقطة المحددة المرتفعة';

  @override
  String get enum_diveField_setpointDeco => 'النقطة المحددة للتخفيف';

  @override
  String get enum_diveField_buddy => 'زميل الغوص';

  @override
  String get enum_diveField_diveMaster => 'دايف ماستر';

  @override
  String get enum_diveField_siteLocation => 'موقع الغوصة';

  @override
  String get enum_diveField_diveCenterName => 'مركز الغوص';

  @override
  String get enum_diveField_siteLatitude => 'خط العرض';

  @override
  String get enum_diveField_siteLongitude => 'خط الطول';

  @override
  String get enum_diveField_tripName => 'الرحلة';

  @override
  String get enum_diveField_ratingStars => 'التقييم';

  @override
  String get enum_diveField_isFavorite => 'مفضّل';

  @override
  String get enum_diveField_notes => 'ملاحظات';

  @override
  String get enum_diveField_tags => 'الوسوم';

  @override
  String get enum_diveField_importSource => 'مصدر الاستيراد';

  @override
  String get enum_diveField_diveTypeName => 'نوع الغوصة';

  @override
  String get enum_diveField_surfaceInterval => 'فترة السطح';

  @override
  String get enum_diveField_diveNumber_short => '#';

  @override
  String get enum_diveField_dateTime_short => 'التاريخ';

  @override
  String get enum_diveField_siteName_short => 'الموقع';

  @override
  String get enum_diveField_diveName_short => 'الاسم';

  @override
  String get enum_diveField_maxDepth_short => 'أقصى عمق';

  @override
  String get enum_diveField_avgDepth_short => 'متوسط عمق';

  @override
  String get enum_diveField_bottomTime_short => 'القاع';

  @override
  String get enum_diveField_runtime_short => 'التشغيل';

  @override
  String get enum_diveField_waterTemp_short => 'حرارة ماء';

  @override
  String get enum_diveField_airTemp_short => 'حرارة هواء';

  @override
  String get enum_diveField_visibility_short => 'الرؤية';

  @override
  String get enum_diveField_currentDirection_short => 'اتجاه';

  @override
  String get enum_diveField_currentStrength_short => 'التيار';

  @override
  String get enum_diveField_swellHeight_short => 'الموج';

  @override
  String get enum_diveField_entryMethod_short => 'الدخول';

  @override
  String get enum_diveField_exitMethod_short => 'الخروج';

  @override
  String get enum_diveField_waterType_short => 'المياه';

  @override
  String get enum_diveField_altitude_short => 'الارتفاع';

  @override
  String get enum_diveField_surfacePressure_short => 'ضغط السطح';

  @override
  String get enum_diveField_windSpeed_short => 'الرياح';

  @override
  String get enum_diveField_cloudCover_short => 'السحب';

  @override
  String get enum_diveField_precipitation_short => 'الأمطار';

  @override
  String get enum_diveField_humidity_short => 'الرطوبة';

  @override
  String get enum_diveField_weatherDescription_short => 'الطقس';

  @override
  String get enum_diveField_primaryGas_short => 'الغاز';

  @override
  String get enum_diveField_diluentGas_short => 'المخفف';

  @override
  String get enum_diveField_tankCount_short => 'أسطوانات';

  @override
  String get enum_diveField_startPressure_short => 'البداية';

  @override
  String get enum_diveField_endPressure_short => 'النهاية';

  @override
  String get enum_diveField_sacRate_short => 'SAC';

  @override
  String get enum_diveField_gasConsumed_short => 'المستهلك';

  @override
  String get enum_diveField_totalWeight_short => 'الوزن';

  @override
  String get enum_diveField_diveComputerModel_short => 'الحاسوب';

  @override
  String get enum_diveField_gradientFactorLow_short => 'GFL';

  @override
  String get enum_diveField_gradientFactorHigh_short => 'GFH';

  @override
  String get enum_diveField_decoAlgorithm_short => 'خوارزمية';

  @override
  String get enum_diveField_decoConservatism_short => 'التحفظ';

  @override
  String get enum_diveField_cnsStart_short => 'CNS بداية';

  @override
  String get enum_diveField_cnsEnd_short => 'CNS نهاية';

  @override
  String get enum_diveField_otu_short => 'OTU';

  @override
  String get enum_diveField_diveMode_short => 'الوضع';

  @override
  String get enum_diveField_setpointLow_short => 'SP منخفض';

  @override
  String get enum_diveField_setpointHigh_short => 'SP مرتفع';

  @override
  String get enum_diveField_setpointDeco_short => 'SP تخفيف';

  @override
  String get enum_diveField_buddy_short => 'الزميل';

  @override
  String get enum_diveField_diveMaster_short => 'DM';

  @override
  String get enum_diveField_siteLocation_short => 'المكان';

  @override
  String get enum_diveField_diveCenterName_short => 'المركز';

  @override
  String get enum_diveField_siteLatitude_short => 'العرض';

  @override
  String get enum_diveField_siteLongitude_short => 'الطول';

  @override
  String get enum_diveField_tripName_short => 'الرحلة';

  @override
  String get enum_diveField_ratingStars_short => 'التقييم';

  @override
  String get enum_diveField_isFavorite_short => 'مفضّل';

  @override
  String get enum_diveField_notes_short => 'ملاحظات';

  @override
  String get enum_diveField_tags_short => 'الوسوم';

  @override
  String get enum_diveField_importSource_short => 'المصدر';

  @override
  String get enum_diveField_diveTypeName_short => 'النوع';

  @override
  String get enum_diveField_surfaceInterval_short => 'السطح';

  @override
  String get enum_siteField_siteName => 'الاسم';

  @override
  String get enum_siteField_location => 'الموقع';

  @override
  String get enum_siteField_country => 'الدولة';

  @override
  String get enum_siteField_region => 'المنطقة';

  @override
  String get enum_siteField_city => 'المدينة';

  @override
  String get enum_siteField_island => 'الجزيرة';

  @override
  String get enum_siteField_bodyOfWater => 'مسطح مائي';

  @override
  String get enum_siteField_diveCount => 'عدد الغوصات';

  @override
  String get enum_siteField_maxDepth => 'أقصى عمق';

  @override
  String get enum_siteField_minDepth => 'أدنى عمق';

  @override
  String get enum_siteField_altitude => 'الارتفاع';

  @override
  String get enum_siteField_waterType => 'نوع المياه';

  @override
  String get enum_siteField_typicalVisibility => 'الرؤية المعتادة';

  @override
  String get enum_siteField_typicalCurrent => 'التيار المعتاد';

  @override
  String get enum_siteField_difficulty => 'الصعوبة';

  @override
  String get enum_siteField_entryType => 'نوع الدخول';

  @override
  String get enum_siteField_bestSeason => 'أفضل موسم';

  @override
  String get enum_siteField_mooringNumber => 'رقم المرسى';

  @override
  String get enum_siteField_hazards => 'المخاطر';

  @override
  String get enum_siteField_rating => 'التقييم';

  @override
  String get enum_siteField_notes => 'ملاحظات';

  @override
  String get enum_siteField_latitude => 'خط العرض';

  @override
  String get enum_siteField_longitude => 'خط الطول';

  @override
  String get enum_siteField_siteName_short => 'الاسم';

  @override
  String get enum_siteField_location_short => 'الموقع';

  @override
  String get enum_siteField_country_short => 'الدولة';

  @override
  String get enum_siteField_region_short => 'المنطقة';

  @override
  String get enum_siteField_city_short => 'المدينة';

  @override
  String get enum_siteField_island_short => 'الجزيرة';

  @override
  String get enum_siteField_bodyOfWater_short => 'مسطح مائي';

  @override
  String get enum_siteField_diveCount_short => 'الغوصات';

  @override
  String get enum_siteField_maxDepth_short => 'أقصى عمق';

  @override
  String get enum_siteField_minDepth_short => 'أدنى عمق';

  @override
  String get enum_siteField_altitude_short => 'الارتفاع';

  @override
  String get enum_siteField_waterType_short => 'المياه';

  @override
  String get enum_siteField_typicalVisibility_short => 'الرؤية';

  @override
  String get enum_siteField_typicalCurrent_short => 'التيار';

  @override
  String get enum_siteField_difficulty_short => 'الصعوبة';

  @override
  String get enum_siteField_entryType_short => 'الدخول';

  @override
  String get enum_siteField_exitMethod => 'طريقة الخروج';

  @override
  String get enum_siteField_exitMethod_short => 'خروج';

  @override
  String get enum_siteField_bestSeason_short => 'الموسم';

  @override
  String get enum_siteField_mooringNumber_short => 'المرسى';

  @override
  String get enum_siteField_hazards_short => 'المخاطر';

  @override
  String get enum_siteField_rating_short => 'التقييم';

  @override
  String get enum_siteField_notes_short => 'ملاحظات';

  @override
  String get enum_siteField_latitude_short => 'العرض';

  @override
  String get enum_siteField_longitude_short => 'الطول';

  @override
  String get enum_siteField_depthRange => 'نطاق العمق';

  @override
  String get enum_siteField_depthRange_short => 'العمق';

  @override
  String get enum_siteField_lastDived => 'آخر غوص';

  @override
  String get enum_siteField_lastDived_short => 'الأخير';

  @override
  String get enum_siteField_maxDepthReached => 'أقصى عمق لك';

  @override
  String get enum_siteField_maxDepthReached_short => 'أقصاك';

  @override
  String get enum_buddyField_buddyName => 'الاسم';

  @override
  String get enum_buddyField_email => 'البريد الإلكتروني';

  @override
  String get enum_buddyField_phone => 'الهاتف';

  @override
  String get enum_buddyField_certificationLevel => 'مستوى الاعتماد';

  @override
  String get enum_buddyField_certificationAgency => 'جهة الاعتماد';

  @override
  String get enum_buddyField_diveCount => 'عدد الغوصات';

  @override
  String get enum_buddyField_notes => 'ملاحظات';

  @override
  String get enum_buddyField_buddyName_short => 'الاسم';

  @override
  String get enum_buddyField_email_short => 'البريد';

  @override
  String get enum_buddyField_phone_short => 'الهاتف';

  @override
  String get enum_buddyField_certificationLevel_short => 'المستوى';

  @override
  String get enum_buddyField_certificationAgency_short => 'الجهة';

  @override
  String get enum_buddyField_diveCount_short => 'الغوصات';

  @override
  String get enum_buddyField_notes_short => 'ملاحظات';

  @override
  String get enum_buddyField_lastDive => 'آخر غوصة';

  @override
  String get enum_buddyField_lastDive_short => 'الأخيرة';

  @override
  String get enum_tripField_tripName => 'الاسم';

  @override
  String get enum_tripField_startDate => 'تاريخ البدء';

  @override
  String get enum_tripField_endDate => 'تاريخ الانتهاء';

  @override
  String get enum_tripField_durationDays => 'المدة';

  @override
  String get enum_tripField_location => 'الموقع';

  @override
  String get enum_tripField_tripType => 'نوع الرحلة';

  @override
  String get enum_tripField_resortName => 'المنتجع';

  @override
  String get enum_tripField_liveaboardName => 'سفينة غوص';

  @override
  String get enum_tripField_diveCount => 'عدد الغوصات';

  @override
  String get enum_tripField_totalRuntime => 'إجمالي وقت التشغيل';

  @override
  String get enum_tripField_maxDepth => 'أقصى عمق';

  @override
  String get enum_tripField_avgDepth => 'متوسط العمق';

  @override
  String get enum_tripField_notes => 'ملاحظات';

  @override
  String get enum_tripField_tripName_short => 'الاسم';

  @override
  String get enum_tripField_startDate_short => 'البداية';

  @override
  String get enum_tripField_endDate_short => 'النهاية';

  @override
  String get enum_tripField_durationDays_short => 'الأيام';

  @override
  String get enum_tripField_location_short => 'الموقع';

  @override
  String get enum_tripField_tripType_short => 'النوع';

  @override
  String get enum_tripField_resortName_short => 'المنتجع';

  @override
  String get enum_tripField_liveaboardName_short => 'السفينة';

  @override
  String get enum_tripField_diveCount_short => 'الغوصات';

  @override
  String get enum_tripField_totalRuntime_short => 'إجمالي التشغيل';

  @override
  String get enum_tripField_maxDepth_short => 'أقصى عمق';

  @override
  String get enum_tripField_avgDepth_short => 'متوسط عمق';

  @override
  String get enum_tripField_notes_short => 'ملاحظات';

  @override
  String get enum_equipmentField_itemName => 'الاسم';

  @override
  String get enum_equipmentField_fullName => 'الاسم الكامل';

  @override
  String get enum_equipmentField_type => 'النوع';

  @override
  String get enum_equipmentField_brand => 'العلامة التجارية';

  @override
  String get enum_equipmentField_model => 'الطراز';

  @override
  String get enum_equipmentField_serialNumber => 'الرقم التسلسلي';

  @override
  String get enum_equipmentField_size => 'المقاس';

  @override
  String get enum_equipmentField_status => 'الحالة';

  @override
  String get enum_equipmentField_isActive => 'نشط';

  @override
  String get enum_equipmentField_purchaseDate => 'تاريخ الشراء';

  @override
  String get enum_equipmentField_purchasePrice => 'سعر الشراء';

  @override
  String get enum_equipmentField_lastServiceDate => 'آخر صيانة';

  @override
  String get enum_equipmentField_nextServiceDue => 'موعد الصيانة القادمة';

  @override
  String get enum_equipmentField_daysUntilService => 'أيام حتى الصيانة';

  @override
  String get enum_equipmentField_serviceIntervalDays => 'فترة الصيانة';

  @override
  String get enum_equipmentField_notes => 'ملاحظات';

  @override
  String get enum_equipmentField_itemName_short => 'الاسم';

  @override
  String get enum_equipmentField_fullName_short => 'اسم كامل';

  @override
  String get enum_equipmentField_type_short => 'النوع';

  @override
  String get enum_equipmentField_brand_short => 'العلامة';

  @override
  String get enum_equipmentField_model_short => 'الطراز';

  @override
  String get enum_equipmentField_serialNumber_short => 'التسلسلي';

  @override
  String get enum_equipmentField_size_short => 'المقاس';

  @override
  String get enum_equipmentField_status_short => 'الحالة';

  @override
  String get enum_equipmentField_isActive_short => 'نشط';

  @override
  String get enum_equipmentField_purchaseDate_short => 'الشراء';

  @override
  String get enum_equipmentField_purchasePrice_short => 'السعر';

  @override
  String get enum_equipmentField_lastServiceDate_short => 'آخر صيانة';

  @override
  String get enum_equipmentField_nextServiceDue_short => 'القادمة';

  @override
  String get enum_equipmentField_daysUntilService_short => 'المتبقية';

  @override
  String get enum_equipmentField_serviceIntervalDays_short => 'الفترة';

  @override
  String get enum_equipmentField_notes_short => 'ملاحظات';

  @override
  String get enum_diveCenterField_centerName => 'الاسم';

  @override
  String get enum_diveCenterField_city => 'المدينة';

  @override
  String get enum_diveCenterField_country => 'الدولة';

  @override
  String get enum_diveCenterField_stateProvince => 'الولاية / المقاطعة';

  @override
  String get enum_diveCenterField_street => 'الشارع';

  @override
  String get enum_diveCenterField_postalCode => 'الرمز البريدي';

  @override
  String get enum_diveCenterField_phone => 'الهاتف';

  @override
  String get enum_diveCenterField_email => 'البريد الإلكتروني';

  @override
  String get enum_diveCenterField_website => 'الموقع الإلكتروني';

  @override
  String get enum_diveCenterField_affiliations => 'الانتماءات';

  @override
  String get enum_diveCenterField_rating => 'التقييم';

  @override
  String get enum_diveCenterField_latitude => 'خط العرض';

  @override
  String get enum_diveCenterField_longitude => 'خط الطول';

  @override
  String get enum_diveCenterField_diveCount => 'عدد الغوصات';

  @override
  String get enum_diveCenterField_notes => 'ملاحظات';

  @override
  String get enum_diveCenterField_centerName_short => 'الاسم';

  @override
  String get enum_diveCenterField_city_short => 'المدينة';

  @override
  String get enum_diveCenterField_country_short => 'الدولة';

  @override
  String get enum_diveCenterField_stateProvince_short => 'الولاية';

  @override
  String get enum_diveCenterField_street_short => 'الشارع';

  @override
  String get enum_diveCenterField_postalCode_short => 'الرمز';

  @override
  String get enum_diveCenterField_phone_short => 'الهاتف';

  @override
  String get enum_diveCenterField_email_short => 'البريد';

  @override
  String get enum_diveCenterField_website_short => 'الويب';

  @override
  String get enum_diveCenterField_affiliations_short => 'الانتماءات';

  @override
  String get enum_diveCenterField_rating_short => 'التقييم';

  @override
  String get enum_diveCenterField_latitude_short => 'العرض';

  @override
  String get enum_diveCenterField_longitude_short => 'الطول';

  @override
  String get enum_diveCenterField_diveCount_short => 'الغوصات';

  @override
  String get enum_diveCenterField_notes_short => 'ملاحظات';

  @override
  String get enum_certificationField_certName => 'الاسم';

  @override
  String get enum_certificationField_agency => 'الجهة';

  @override
  String get enum_certificationField_level => 'الشهادة';

  @override
  String get enum_certificationField_cardNumber => 'رقم البطاقة';

  @override
  String get enum_certificationField_issueDate => 'تاريخ الإصدار';

  @override
  String get enum_certificationField_expiryDate => 'تاريخ الانتهاء';

  @override
  String get enum_certificationField_instructorName => 'اسم المدرب';

  @override
  String get enum_certificationField_instructorNumber => 'رقم المدرب';

  @override
  String get enum_certificationField_expiryStatus => 'حالة الصلاحية';

  @override
  String get enum_certificationField_notes => 'ملاحظات';

  @override
  String get enum_certificationField_certName_short => 'الاسم';

  @override
  String get enum_certificationField_agency_short => 'الجهة';

  @override
  String get enum_certificationField_level_short => 'الشهادة';

  @override
  String get enum_certificationField_cardNumber_short => 'البطاقة';

  @override
  String get enum_certificationField_issueDate_short => 'الإصدار';

  @override
  String get enum_certificationField_expiryDate_short => 'الانتهاء';

  @override
  String get enum_certificationField_instructorName_short => 'المدرب';

  @override
  String get enum_certificationField_instructorNumber_short => 'المدرب #';

  @override
  String get enum_certificationField_expiryStatus_short => 'الحالة';

  @override
  String get enum_certificationField_notes_short => 'ملاحظات';

  @override
  String get enum_courseField_courseName => 'الاسم';

  @override
  String get enum_courseField_agency => 'الجهة';

  @override
  String get enum_courseField_startDate => 'تاريخ البدء';

  @override
  String get enum_courseField_completionDate => 'تاريخ الإكمال';

  @override
  String get enum_courseField_durationDays => 'المدة';

  @override
  String get enum_courseField_instructorName => 'اسم المدرب';

  @override
  String get enum_courseField_instructorNumber => 'رقم المدرب';

  @override
  String get enum_courseField_location => 'الموقع';

  @override
  String get enum_courseField_isCompleted => 'مكتمل';

  @override
  String get enum_courseField_notes => 'ملاحظات';

  @override
  String get enum_courseField_courseName_short => 'الاسم';

  @override
  String get enum_courseField_agency_short => 'الجهة';

  @override
  String get enum_courseField_startDate_short => 'البداية';

  @override
  String get enum_courseField_completionDate_short => 'الإكمال';

  @override
  String get enum_courseField_durationDays_short => 'المدة';

  @override
  String get enum_courseField_instructorName_short => 'المدرب';

  @override
  String get enum_courseField_instructorNumber_short => 'المدرب #';

  @override
  String get enum_courseField_location_short => 'الموقع';

  @override
  String get enum_courseField_isCompleted_short => 'تم';

  @override
  String get enum_courseField_notes_short => 'ملاحظات';

  @override
  String get enum_fieldCategory_accommodation => 'الإقامة';

  @override
  String get enum_fieldCategory_address => 'العنوان';

  @override
  String get enum_fieldCategory_certification => 'الشهادة';

  @override
  String get enum_fieldCategory_conditions => 'الظروف';

  @override
  String get enum_fieldCategory_contact => 'الاتصال';

  @override
  String get enum_fieldCategory_coordinates => 'الإحداثيات';

  @override
  String get enum_fieldCategory_dates => 'التواريخ';

  @override
  String get enum_fieldCategory_depth => 'العمق';

  @override
  String get enum_fieldCategory_details => 'التفاصيل';

  @override
  String get enum_fieldCategory_instructor => 'المدرب';

  @override
  String get enum_fieldCategory_other => 'أخرى';

  @override
  String get enum_fieldCategory_purchase => 'الشراء';

  @override
  String get enum_fieldCategory_service => 'الصيانة';

  @override
  String get enum_fieldCategory_statistics => 'الإحصائيات';

  @override
  String get species_whale_shark_name => 'القرش الحوتي';

  @override
  String get species_whale_shark_desc =>
      'أكبر سمكة في المحيط، وهو مرشِّح لطيف يتغذى بالترشيح ويتميز بنمط منقّط فريد.';

  @override
  String get species_great_white_shark_name => 'القرش الأبيض الكبير';

  @override
  String get species_great_white_shark_desc =>
      'مفترس قمة أيقوني يشاهده أحيانًا الغواصون من داخل الأقفاص في المياه المعتدلة.';

  @override
  String get species_great_hammerhead_shark_name => 'قرش المطرقة العظيم';

  @override
  String get species_great_hammerhead_shark_desc =>
      'أكبر أنواع أسماك المطرقة، برأس عريض مسطح وزعنفة ظهرية مرتفعة.';

  @override
  String get species_scalloped_hammerhead_shark_name => 'قرش المطرقة المسنن';

  @override
  String get species_scalloped_hammerhead_shark_desc =>
      'كثيرًا ما يُشاهد في أسراب كبيرة عند الجبال البحرية ومحطات التنظيف.';

  @override
  String get species_smooth_hammerhead_shark_name => 'قرش المطرقة الأملس';

  @override
  String get species_smooth_hammerhead_shark_desc =>
      'قرش مطرقة بحافة رأس ملساء مستديرة يعيش في البحار المعتدلة.';

  @override
  String get species_whitetip_reef_shark_name => 'قرش الشعاب أبيض الأطراف';

  @override
  String get species_whitetip_reef_shark_desc =>
      'ساكن شعاب وديع يُشاهد غالبًا مستريحًا في الكهوف وتحت الحواف الصخرية نهارًا.';

  @override
  String get species_blacktip_reef_shark_name => 'قرش الشعاب أسود الأطراف';

  @override
  String get species_blacktip_reef_shark_desc =>
      'قرش شعاب شائع في المياه الضحلة يتميز بزعانف سوداء الأطراف.';

  @override
  String get species_grey_reef_shark_name => 'قرش الشعاب الرمادي';

  @override
  String get species_grey_reef_shark_desc =>
      'مفترس شعاب نشط يُصادَف غالبًا في مجموعات على طول المنحدرات والقنوات.';

  @override
  String get species_caribbean_reef_shark_name => 'قرش شعاب الكاريبي';

  @override
  String get species_caribbean_reef_shark_desc =>
      'أكثر أسماك قرش الشعاب مصادفةً في الكاريبي، متين البنية وفضولي تجاه الغواصين.';

  @override
  String get species_nurse_shark_name => 'القرش الممرض';

  @override
  String get species_nurse_shark_desc =>
      'ساكن قاع بطيء الحركة يُشاهد غالبًا مستريحًا تحت حواف المرجان.';

  @override
  String get species_tawny_nurse_shark_name => 'القرش الممرض الأسمر';

  @override
  String get species_tawny_nurse_shark_desc =>
      'ساكن قاع من المحيطين الهندي والهادئ يستريح في كهوف الشعاب والمناطق الرملية.';

  @override
  String get species_bull_shark_name => 'القرش الثور';

  @override
  String get species_bull_shark_desc =>
      'قرش ممتلئ وقوي يوجد في البيئات الساحلية والمياه العذبة حول العالم.';

  @override
  String get species_tiger_shark_name => 'القرش النمر';

  @override
  String get species_tiger_shark_desc =>
      'مفترس كبير بنمط مخطط مميز، يُصادَف في غوصات الشعاب العميقة.';

  @override
  String get species_oceanic_whitetip_shark_name =>
      'القرش المحيطي أبيض الأطراف';

  @override
  String get species_oceanic_whitetip_shark_desc =>
      'قرش من أعالي البحار بزعانف مستديرة بيضاء الأطراف، يُشاهد في غوصات المحيط المفتوح.';

  @override
  String get species_thresher_shark_name => 'القرش الدرّاس';

  @override
  String get species_thresher_shark_desc =>
      'يُعرف بزعنفة ذيله الطويلة للغاية، ويُشاهد أحيانًا عند محطات التنظيف.';

  @override
  String get species_pelagic_thresher_shark_name => 'القرش الدرّاس المحيطي';

  @override
  String get species_pelagic_thresher_shark_desc =>
      'أصغر أنواع القرش الدرّاس، ويشتهر بمشاهدته عند ضحل موناد في الفلبين.';

  @override
  String get species_shortfin_mako_shark_name => 'قرش الماكو قصير الزعنفة';

  @override
  String get species_shortfin_mako_shark_desc =>
      'أسرع قرش في المحيط، مفترس أنيق في المياه المفتوحة بلون أزرق معدني.';

  @override
  String get species_blue_shark_name => 'القرش الأزرق';

  @override
  String get species_blue_shark_desc =>
      'قرش نحيل أزرق داكن من أعالي البحار يُصادَف غالبًا في غوصات المياه الزرقاء.';

  @override
  String get species_spotted_wobbegong_name => 'قرش السجاد المرقّط';

  @override
  String get species_spotted_wobbegong_desc =>
      'قرش سجاد مسطح ومموّه يرقد بلا حراك على الشعاب الصخرية في أستراليا.';

  @override
  String get species_tasselled_wobbegong_name => 'قرش السجاد المهدّب';

  @override
  String get species_tasselled_wobbegong_desc =>
      'قرش سجاد مزخرف بفصوص مهدّبة حول رأسه، يعيش في الشعاب المرجانية.';

  @override
  String get species_epaulette_shark_name => 'قرش الكتفية';

  @override
  String get species_epaulette_shark_desc =>
      'قرش صغير يسير على قاع الشعاب مستخدمًا زعانفه الصدرية.';

  @override
  String get species_horn_shark_name => 'القرش القرني';

  @override
  String get species_horn_shark_desc =>
      'ساكن قاع ليلي النشاط بحواف بارزة فوق عينيه، يوجد قبالة كاليفورنيا.';

  @override
  String get species_leopard_shark_name => 'قرش الفهد';

  @override
  String get species_leopard_shark_desc =>
      'قرش بنقوش جميلة يعيش في الخلجان الضحلة على طول ساحل المحيط الهادئ الأمريكي.';

  @override
  String get species_pacific_angel_shark_name => 'قرش الملاك الهادئي';

  @override
  String get species_pacific_angel_shark_desc =>
      'مفترس كمين مسطح الجسم يرقد مدفونًا في الرمال على قاع البحر.';

  @override
  String get species_sand_tiger_shark_name => 'قرش نمر الرمال';

  @override
  String get species_sand_tiger_shark_desc =>
      'قرش مخيف المظهر لكنه وديع، يُشاهد غالبًا محلّقًا في الكهوف وحطام السفن.';

  @override
  String get species_zebra_shark_name => 'قرش الزرد';

  @override
  String get species_zebra_shark_desc =>
      'قرش شعاب منقّط يستريح على القيعان الرملية، وشائع في المحيطين الهندي والهادئ.';

  @override
  String get species_blacktip_shark_name => 'القرش أسود الأطراف';

  @override
  String get species_blacktip_shark_desc =>
      'قرش ساحلي سريع يشتهر بقفزاته الدوّارة، ويوجد في المياه الدافئة حول العالم.';

  @override
  String get species_silvertip_shark_name => 'القرش فضي الأطراف';

  @override
  String get species_silvertip_shark_desc =>
      'قرش شعاب جريء بزعانف بيضاء الحواف، يوجد قرب المنحدرات العميقة والجزر المرجانية.';

  @override
  String get species_silky_shark_name => 'القرش الحريري';

  @override
  String get species_silky_shark_desc =>
      'قرش أنيق من أعالي البحار بجلد ناعم، يوجد غالبًا قرب الشعاب البعيدة عن الساحل.';

  @override
  String get species_lemon_shark_name => 'قرش الليمون';

  @override
  String get species_lemon_shark_desc =>
      'قرش بلون بني مصفرّ يُشاهد عادةً في غابات المانغروف الضحلة والسهول الرملية.';

  @override
  String get species_galapagos_shark_name => 'قرش غالاباغوس';

  @override
  String get species_galapagos_shark_desc =>
      'قرش شعاب كبير يوجد حول الجزر المحيطية، وفضولي تجاه الغواصين.';

  @override
  String get species_port_jackson_shark_name => 'قرش بورت جاكسون';

  @override
  String get species_port_jackson_shark_desc =>
      'ساكن قاع ليلي النشاط بعلامات تشبه الحزام، متوطن في أستراليا.';

  @override
  String get species_bamboo_shark_name => 'قرش الخيزران بنّي الأشرطة';

  @override
  String get species_bamboo_shark_desc =>
      'قرش صغير وديع يعيش على القاع وينتشر في الشعاب المرجانية بالمحيطين الهندي والهادئ.';

  @override
  String get species_basking_shark_name => 'القرش المتشمس';

  @override
  String get species_basking_shark_desc =>
      'ثاني أكبر سمكة في العالم، يتغذى بالترشيح ويُشاهد في المياه السطحية المعتدلة.';

  @override
  String get species_greenland_shark_name => 'قرش غرينلاند';

  @override
  String get species_greenland_shark_desc =>
      'قرش أعماق بطيء الحركة، وأحد أطول الفقاريات عمرًا على وجه الأرض.';

  @override
  String get species_cookiecutter_shark_name => 'القرش قاطع البسكويت';

  @override
  String get species_cookiecutter_shark_desc =>
      'قرش أعماق صغير يقتطع عضّات دائرية من الحيوانات البحرية الأكبر منه.';

  @override
  String get species_sevengill_shark_name => 'القرش سباعي الخياشيم عريض الأنف';

  @override
  String get species_sevengill_shark_desc =>
      'قرش بدائي بسبعة شقوق خيشومية، يُصادَف في غوصات غابات عشب البحر المعتدلة.';

  @override
  String get species_pyjama_shark_name => 'قرش البيجاما';

  @override
  String get species_pyjama_shark_desc =>
      'قرش قطي مخطط متوطن في جنوب أفريقيا، يعيش في الشعاب الصخرية وغابات عشب البحر.';

  @override
  String get species_spiny_dogfish_name => 'كلب البحر الشوكي';

  @override
  String get species_spiny_dogfish_desc =>
      'قرش صغير وفير العدد بأشواك ظهرية سامة، يوجد في المياه المعتدلة.';

  @override
  String get species_swell_shark_name => 'القرش المنتفخ';

  @override
  String get species_swell_shark_desc =>
      'قرش قطي ليلي النشاط ينفخ جسمه عند شعوره بالتهديد، ويوجد قبالة كاليفورنيا.';

  @override
  String get species_giant_oceanic_manta_ray_name =>
      'شفنين المانتا المحيطي العملاق';

  @override
  String get species_giant_oceanic_manta_ray_desc =>
      'أكبر أنواع الشفنين، مرشِّح مهيب يتغذى بالترشيح ويبلغ باع جناحيه سبعة أمتار.';

  @override
  String get species_reef_manta_ray_name => 'شفنين المانتا الشعابي';

  @override
  String get species_reef_manta_ray_desc =>
      'نوع مانتا أصغر حجمًا يُشاهد عادةً عند محطات التنظيف في الشعاب الاستوائية.';

  @override
  String get species_spotted_eagle_ray_name => 'الشفنين النسري المرقّط';

  @override
  String get species_spotted_eagle_ray_desc =>
      'شفنين أنيق ببقع بيضاء وذيل طويل يشبه السوط، يُشاهد غالبًا في وسط الماء.';

  @override
  String get species_common_eagle_ray_name => 'الشفنين النسري الشائع';

  @override
  String get species_common_eagle_ray_desc =>
      'شفنين معيّن الشكل يوجد في المياه المعتدلة بشرق الأطلسي والبحر المتوسط.';

  @override
  String get species_blue_spotted_ribbontail_ray_name =>
      'الشفنين الشريطي الذيل ذو البقع الزرقاء';

  @override
  String get species_blue_spotted_ribbontail_ray_desc =>
      'شفنين زاهي الألوان ببقع زرقاء ساطعة، شائع في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_blue_spotted_stingray_name => 'الشفنين اللاسع أزرق البقع';

  @override
  String get species_blue_spotted_stingray_desc =>
      'شفنين لاسع صغير من الشعاب ببقع زرقاء متناثرة، يُدفن غالبًا في الرقع الرملية.';

  @override
  String get species_southern_stingray_name => 'الشفنين اللاسع الجنوبي';

  @override
  String get species_southern_stingray_desc =>
      'شفنين لاسع كبير يعيش على السهول الرملية في الكاريبي، ويشتهر في موقع ستينغراي سيتي.';

  @override
  String get species_round_stingray_name => 'الشفنين اللاسع المستدير';

  @override
  String get species_round_stingray_desc =>
      'شفنين لاسع صغير دائري الشكل شائع في المناطق الرملية الضحلة بشرق المحيط الهادئ.';

  @override
  String get species_short_tail_stingray_name => 'الشفنين اللاسع قصير الذيل';

  @override
  String get species_short_tail_stingray_desc =>
      'أحد أكبر أنواع الشفنين اللاسع، ويوجد في المياه المعتدلة بنصف الكرة الجنوبي.';

  @override
  String get species_cowtail_stingray_name => 'الشفنين اللاسع ذو ذيل البقرة';

  @override
  String get species_cowtail_stingray_desc =>
      'شفنين لاسع كبير داكن بطية ذيل مميزة تشبه الراية، يوجد على الشعاب الرملية.';

  @override
  String get species_atlantic_torpedo_ray_name => 'الشفنين الرعّاد الأطلسي';

  @override
  String get species_atlantic_torpedo_ray_desc =>
      'شفنين كهربائي قادر على توليد صدمات قوية، يوجد على القيعان الرملية في الأطلسي.';

  @override
  String get species_marbled_electric_ray_name => 'الشفنين الكهربائي المرمّري';

  @override
  String get species_marbled_electric_ray_desc =>
      'شفنين كهربائي متوسطي بنمط مرمّري، يُطلق صدمة كهربائية ملحوظة.';

  @override
  String get species_giant_guitarfish_name => 'سمكة الجيتار العملاقة';

  @override
  String get species_giant_guitarfish_desc =>
      'شفنين بهيئة القرش يوجد على القيعان الرملية قرب الشعاب المرجانية في المحيطين الهندي والهادئ.';

  @override
  String get species_shovelnose_guitarfish_name => 'سمكة الجيتار مجرفية الأنف';

  @override
  String get species_shovelnose_guitarfish_desc =>
      'هيئة مسطحة تجمع بين الشفنين والقرش، وتنتشر في الضحال الرملية بشرق المحيط الهادئ.';

  @override
  String get species_smalltooth_sawfish_name => 'سمكة المنشار صغيرة الأسنان';

  @override
  String get species_smalltooth_sawfish_desc =>
      'شفنين مهدد بالانقراض بشدة بمنقار مسنن، يوجد في المياه الساحلية الاستوائية.';

  @override
  String get species_green_sawfish_name => 'سمكة المنشار الخضراء';

  @override
  String get species_green_sawfish_desc =>
      'سمكة منشار كبيرة بجسم أخضر زيتوني، تعيش في مصبات الأنهار بغرب المحيطين الهندي والهادئ.';

  @override
  String get species_devil_ray_name => 'شفنين الشيطان العملاق';

  @override
  String get species_devil_ray_desc =>
      'شفنين موبولا كبير بزعانف رأسية، يُشاهد وهو يقفز من الماء في مجموعات.';

  @override
  String get species_spinetail_devil_ray_name => 'شفنين الشيطان شوكي الذيل';

  @override
  String get species_spinetail_devil_ray_desc =>
      'شفنين شيطاني من أعالي البحار يُشاهد غالبًا في تجمعات كبيرة قرب السطح.';

  @override
  String get species_lesser_devil_ray_name => 'شفنين الشيطان القزم';

  @override
  String get species_lesser_devil_ray_desc =>
      'أصغر أنواع الموبولا، ويشكّل أسرابًا كبيرة في خليج كاليفورنيا.';

  @override
  String get species_bat_ray_name => 'شفنين الخفاش';

  @override
  String get species_bat_ray_desc =>
      'شفنين معيّن الشكل شائع في غابات عشب البحر والخلجان الرملية بكاليفورنيا.';

  @override
  String get species_undulate_ray_name => 'الشفنين المتموّج';

  @override
  String get species_undulate_ray_desc =>
      'شفنين ذو نقوش جميلة بخطوط متموجة، يوجد في شرق المحيط الأطلسي.';

  @override
  String get species_thornback_ray_name => 'الشفنين الشوكي الظهر';

  @override
  String get species_thornback_ray_desc =>
      'شفنين أوروبي شائع بأشواك حادة على طول ظهره وذيله.';

  @override
  String get species_cownose_ray_name => 'الشفنين ذو أنف البقرة';

  @override
  String get species_cownose_ray_desc =>
      'يتميز برأس مشقوق مميز، ويُشاهد غالبًا في أسراب كبيرة خلال الهجرات الموسمية.';

  @override
  String get species_marble_ray_name => 'الشفنين المرمّري';

  @override
  String get species_marble_ray_desc =>
      'شفنين لاسع كبير داكن ببقع بيضاء، يُشاهد كثيرًا عند محطات التنظيف في المحيطين الهندي والهادئ.';

  @override
  String get species_ocellate_river_stingray_name => 'شفنين النهر ذو العيون';

  @override
  String get species_ocellate_river_stingray_desc =>
      'شفنين لاسع من المياه العذبة ببقع لافتة محاطة بحلقات برتقالية، موطنه أنهار أمريكا الجنوبية.';

  @override
  String get species_ocellaris_clownfish_name => 'سمكة المهرج';

  @override
  String get species_ocellaris_clownfish_desc =>
      'سمكة صغيرة برتقالية بخطوط بيضاء تعيش عادةً في تكافل مع شقائق النعمان البحرية على الشعاب المرجانية.';

  @override
  String get species_clarkii_clownfish_name => 'سمكة مهرج كلارك';

  @override
  String get species_clarkii_clownfish_desc =>
      'سمكة شقائق قوية البنية بجسم داكن وشريطين أبيضين، توجد في أنحاء المحيطين الهندي والهادئ ضمن أنواع مختلفة من شقائق النعمان.';

  @override
  String get species_tomato_clownfish_name => 'سمكة المهرج الطماطمية';

  @override
  String get species_tomato_clownfish_desc =>
      'سمكة شقائق حمراء برتقالية زاهية بشريط أبيض واحد على الرأس، شائعة في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_regal_blue_tang_name => 'سمكة الجراح الزرقاء الملكية';

  @override
  String get species_regal_blue_tang_desc =>
      'سمكة جراح زرقاء زاهية بعلامة سوداء تشبه لوحة الألوان وذيل أصفر، توجد في الشعاب المرجانية بالمحيطين الهندي والهادئ.';

  @override
  String get species_yellow_tang_name => 'سمكة الجراح الصفراء';

  @override
  String get species_yellow_tang_desc =>
      'سمكة جراح صفراء زاهية شائعة في شعاب هاواي والمحيط الهادئ، وتُشاهد غالبًا وهي ترعى الطحالب في مجموعات.';

  @override
  String get species_powder_blue_surgeonfish_name =>
      'سمكة الجراح الزرقاء الفاتحة';

  @override
  String get species_powder_blue_surgeonfish_desc =>
      'سمكة جراح لافتة بلون أزرق فاتح ووجه أسود وزعنفة ظهرية صفراء، توجد في المحيط الهندي.';

  @override
  String get species_sohal_surgeonfish_name => 'سمكة السوهال';

  @override
  String get species_sohal_surgeonfish_desc =>
      'سمكة جراح مخططة جريئة بشوكة برتقالية حادة، متوطنة في شعاب البحر الأحمر والخليج العربي.';

  @override
  String get species_blue_tang_name => 'سمكة الجراح الزرقاء';

  @override
  String get species_blue_tang_desc =>
      'سمكة جراح زرقاء داكنة شائعة في شعاب الكاريبي، وصغارها صفراء زاهية.';

  @override
  String get species_emperor_angelfish_name => 'سمكة الملاك الإمبراطور';

  @override
  String get species_emperor_angelfish_desc =>
      'سمكة ملاك كبيرة بخطوط أفقية زرقاء وصفراء لافتة. وتُظهر صغارها دوائر متحدة المركز بالأزرق والأبيض.';

  @override
  String get species_french_angelfish_name => 'سمكة الملاك الفرنسية';

  @override
  String get species_french_angelfish_desc =>
      'سمكة ملاك كبيرة داكنة بحراشف مذهّبة الحواف، تُشاهد عادةً في أزواج على شعاب الكاريبي وغرب الأطلسي.';

  @override
  String get species_queen_angelfish_name => 'سمكة الملاك الملكة';

  @override
  String get species_queen_angelfish_desc =>
      'سمكة ملاك مذهلة بالأزرق والأصفر مع بقعة تشبه التاج، توجد في الشعاب المرجانية بالكاريبي.';

  @override
  String get species_regal_angelfish_name => 'سمكة الملاك الملكية';

  @override
  String get species_regal_angelfish_desc =>
      'سمكة ملاك أنيقة بأشرطة عمودية متناوبة برتقالية بيضاء وزرقاء، توجد في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_rock_beauty_name => 'جميلة الصخور';

  @override
  String get species_rock_beauty_desc =>
      'سمكة ملاك كاريبية لافتة نصفها الأمامي أصفر ونصفها الخلفي أسود، توجد قرب الشعاب الصخرية والحواف.';

  @override
  String get species_gray_angelfish_name => 'سمكة الملاك الرمادية';

  @override
  String get species_gray_angelfish_desc =>
      'سمكة ملاك رمادية كبيرة بوجه شاحب وزعنفة صدرية صفراء من الداخل، شائعة في شعاب الكاريبي.';

  @override
  String get species_copperband_butterflyfish_name =>
      'سمكة الفراشة نحاسية الأشرطة';

  @override
  String get species_copperband_butterflyfish_desc =>
      'سمكة فراشة مميزة بأشرطة برتقالية عمودية وخطم مستطيل، توجد في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_raccoon_butterflyfish_name => 'سمكة الفراشة الراكونية';

  @override
  String get species_raccoon_butterflyfish_desc =>
      'سمكة فراشة صفراء بقناع داكن حول العينين يشبه قناع الراكون، شائعة في شعاب المحيطين الهندي والهادئ وهاواي.';

  @override
  String get species_longnose_butterflyfish_name => 'سمكة الفراشة طويلة الأنف';

  @override
  String get species_longnose_butterflyfish_desc =>
      'سمكة فراشة صفراء زاهية بخطم طويل جدًا تستخدمه لالتقاط الطعام من الشقوق في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_threadfin_butterflyfish_name =>
      'سمكة الفراشة خيطية الزعنفة';

  @override
  String get species_threadfin_butterflyfish_desc =>
      'سمكة فراشة بيضاء بنمط على شكل شارات وخيط ظهري متدلٍ، منتشرة في أنحاء المحيطين الهندي والهادئ.';

  @override
  String get species_foureye_butterflyfish_name => 'سمكة الفراشة رباعية العيون';

  @override
  String get species_foureye_butterflyfish_desc =>
      'سمكة فراشة شاحبة ببقعة عين كاذبة بارزة قرب الذيل، شائعة في شعاب الكاريبي.';

  @override
  String get species_spotfin_butterflyfish_name =>
      'سمكة الفراشة منقّطة الزعنفة';

  @override
  String get species_spotfin_butterflyfish_desc =>
      'سمكة فراشة بيضاء وصفراء ببقعة داكنة صغيرة على الزعنفة الظهرية، توجد في غرب الأطلسي.';

  @override
  String get species_banner_butterflyfish_name => 'سمكة الراية في البحر الأحمر';

  @override
  String get species_banner_butterflyfish_desc =>
      'سمكة راية بيضاء وسوداء بزعنفة ظهرية مستطيلة وبطن أصفر، متوطنة في البحر الأحمر.';

  @override
  String get species_moorish_idol_name => 'سمكة المعبود المورية';

  @override
  String get species_moorish_idol_desc =>
      'سمكة شعاب أيقونية بأشرطة سوداء وبيضاء وصفراء جريئة وخيط ظهري طويل متدلٍ.';

  @override
  String get species_green_moray_eel_name => 'ثعبان البحر المورَي الأخضر';

  @override
  String get species_green_moray_eel_desc =>
      'مورَي أخضر كبير يبلغ طوله 2.5 متر، ويُشاهد غالبًا فاغرًا فمه في شقوق الشعاب عبر غرب الأطلسي.';

  @override
  String get species_giant_moray_eel_name => 'ثعبان البحر المورَي العملاق';

  @override
  String get species_giant_moray_eel_desc =>
      'أكبر أنواع المورَي، ويتجاوز طوله ثلاثة أمتار وله بقع تشبه بقع الفهد. يوجد في الشعاب المرجانية بالمحيطين الهندي والهادئ.';

  @override
  String get species_spotted_moray_eel_name => 'ثعبان البحر المورَي المرقّط';

  @override
  String get species_spotted_moray_eel_desc =>
      'مورَي أبيض ببقع بنية داكنة، يُصادَف عادةً وهو يطل من ثقوب الشعاب في الكاريبي.';

  @override
  String get species_ribbon_eel_name => 'ثعبان البحر الشريطي';

  @override
  String get species_ribbon_eel_desc =>
      'ثعبان بحر نحيل بمناخر متسعة؛ الذكور زرقاء زاهية والإناث صفراء. يوجد في البحيرات الرملية بالمحيطين الهندي والهادئ.';

  @override
  String get species_spotted_garden_eel_name => 'ثعبان البحر الحديقي المرقّط';

  @override
  String get species_spotted_garden_eel_desc =>
      'ثعبان بحر أبيض رفيع ببقع سوداء يعيش في مستعمرات رملية، ويتمايل مع التيار لالتقاط العوالق.';

  @override
  String get species_splendid_garden_eel_name => 'ثعبان البحر الحديقي البهي';

  @override
  String get species_splendid_garden_eel_desc =>
      'ثعبان بحر حديقي بأشرطة برتقالية وبيضاء يعيش في مستعمرات رملية كبيرة في غرب المحيط الهادئ.';

  @override
  String get species_snowflake_moray_name => 'ثعبان البحر المورَي ندفي النقوش';

  @override
  String get species_snowflake_moray_desc =>
      'مورَي صغير بجسم أبيض وعلامات سوداء تشبه ندف الثلج، شائع في حطام الشعاب بالمحيطين الهندي والهادئ.';

  @override
  String get species_mandarin_dragonet_name => 'سمكة التنين المندرين';

  @override
  String get species_mandarin_dragonet_desc =>
      'سمكة صغيرة زاهية الألوان بنقوش زرقاء وبرتقالية مبهرة، توجد في مناطق الحطام المرجاني بغرب المحيط الهادئ.';

  @override
  String get species_common_lionfish_name => 'سمكة الأسد الشائعة';

  @override
  String get species_common_lionfish_desc =>
      'سمكة عقربية سامة بزعانف صدرية مروحية مذهلة وخطوط حمراء وبيضاء. وهي نوع غازٍ في الكاريبي.';

  @override
  String get species_leaf_scorpionfish_name => 'السمكة العقربية الورقية';

  @override
  String get species_leaf_scorpionfish_desc =>
      'سمكة عقربية شديدة التسطّح على شكل ورقة تتمايل مع التيار لتحاكي الحطام على شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_stonefish_name => 'سمكة الحجر الشعابية';

  @override
  String get species_stonefish_desc =>
      'أشد أسماك العالم سُمّية، وتتمويه تام كصخرة على أرضيات الشعاب بالمحيطين الهندي والهادئ. خطيرة للغاية.';

  @override
  String get species_painted_frogfish_name => 'سمكة الضفدع المرسومة';

  @override
  String get species_painted_frogfish_desc =>
      'مفترس كمين ممتلئ الجسم بطُعم على رأسه، شديد التباين في اللون. يوجد في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_giant_frogfish_name => 'سمكة الضفدع العملاقة';

  @override
  String get species_giant_frogfish_desc =>
      'أكبر أنواع سمك الضفدع، ويبلغ طولها 40 سم، وتتمتع بتمويه ممتاز بين الإسفنجيات وحطام المرجان.';

  @override
  String get species_hairy_frogfish_name => 'سمكة الضفدع الشعرية';

  @override
  String get species_hairy_frogfish_desc =>
      'سمكة ضفدع مغطاة بزوائد لحمية تشبه الديدان وتحاكي الطحالب، وهي صيد ثمين لمصوري ما تحت الماء.';

  @override
  String get species_clown_triggerfish_name => 'سمكة الزناد المهرجة';

  @override
  String get species_clown_triggerfish_desc =>
      'سمكة زناد ذات نقوش جريئة ببقع بيضاء كبيرة على جسم داكن وشفاه صفراء، توجد في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_titan_triggerfish_name => 'سمكة الزناد التيتانية';

  @override
  String get species_titan_triggerfish_desc =>
      'سمكة زناد كبيرة عدوانية معروفة بمهاجمة الغواصين قرب عشها. وهي شائعة في الشعاب المرجانية بالمحيطين الهندي والهادئ.';

  @override
  String get species_queen_triggerfish_name => 'سمكة الزناد الملكة';

  @override
  String get species_queen_triggerfish_desc =>
      'سمكة زناد كاريبية ملونة بعلامات زرقاء على الوجه وخيوط ذيل طويلة.';

  @override
  String get species_picasso_triggerfish_name => 'سمكة زناد بيكاسو';

  @override
  String get species_picasso_triggerfish_desc =>
      'سمكة زناد بنمط تجريدي من الخطوط الزرقاء والصفراء والسوداء، شائعة على مسطحات الشعاب بالمحيطين الهندي والهادئ.';

  @override
  String get species_yellowmargin_triggerfish_name =>
      'سمكة الزناد صفراء الحواف';

  @override
  String get species_yellowmargin_triggerfish_desc =>
      'سمكة زناد كبيرة بلون بيج وزعانف صفراء الحواف، معروفة بحراسة عشها بعدوانية في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_porcupinefish_name => 'سمكة النيص';

  @override
  String get species_porcupinefish_desc =>
      'سمكة شوكية كبيرة تنتفخ لتصير كرة عند شعورها بالتهديد، وتوجد في الشعاب الاستوائية حول العالم.';

  @override
  String get species_guineafowl_pufferfish_name => 'سمكة المنفاخ الغينية';

  @override
  String get species_guineafowl_pufferfish_desc =>
      'سمكة منفاخ داكنة مغطاة ببقع بيضاء صغيرة، وتظهر أحيانًا في طور لوني ذهبي أصفر على شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_map_pufferfish_name => 'سمكة المنفاخ الخريطية';

  @override
  String get species_map_pufferfish_desc =>
      'سمكة منفاخ كبيرة شاحبة بعلامات داكنة متشابكة تشبه الخرائط على جسمها، توجد في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_sharpnose_pufferfish_name => 'سمكة المنفاخ حادة الأنف';

  @override
  String get species_sharpnose_pufferfish_desc =>
      'سمكة منفاخ صغيرة بخطوط زرقاء على الوجه وذيل برتقالي، تُشاهد عادةً في شعاب الكاريبي.';

  @override
  String get species_boxfish_name => 'سمكة الصندوق الصفراء';

  @override
  String get species_boxfish_desc =>
      'الصغار مكعبات صفراء زاهية ببقع سوداء، وتتحول البالغة إلى الرمادي المزرق. توجد في أنحاء المحيطين الهندي والهادئ.';

  @override
  String get species_cowfish_name => 'سمكة البقرة طويلة القرون';

  @override
  String get species_cowfish_desc =>
      'سمكة صفراء صندوقية الشكل بنتوءات مميزة تشبه القرون فوق كل عين، توجد في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_napoleon_wrasse_name => 'سمكة نابليون';

  @override
  String get species_napoleon_wrasse_desc =>
      'سمكة حريد ضخمة يبلغ طولها مترين بنتوء جبهي بارز. وهي مهددة بالانقراض ومحمية، وتوجد في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_cleaner_wrasse_name => 'سمكة الحريد المنظفة زرقاء الخط';

  @override
  String get species_cleaner_wrasse_desc =>
      'سمكة حريد صغيرة مخططة بالأزرق تدير محطات التنظيف وتزيل الطفيليات عن الأسماك الأكبر في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_yellowtail_coris_name => 'حريد الكوريس أصفر الذيل';

  @override
  String get species_yellowtail_coris_desc =>
      'سمكة حريد ملونة بجسم منقّط وذيل أصفر، وصغارها برتقالية حمراء زاهية بعلامات بيضاء.';

  @override
  String get species_bluehead_wrasse_name => 'الحريد أزرق الرأس';

  @override
  String get species_bluehead_wrasse_desc =>
      'سمكة حريد وفيرة في الكاريبي؛ وللذكور في الطور النهائي رأس أزرق زاهٍ وجسم أخضر بأشرطة سوداء وبيضاء.';

  @override
  String get species_spanish_hogfish_name => 'سمكة الخنزير الإسبانية';

  @override
  String get species_spanish_hogfish_desc =>
      'سمكة حريد أرجوانية وصفراء شائعة في شعاب الكاريبي؛ وتعمل صغارها كأسماك منظفة.';

  @override
  String get species_bumphead_parrotfish_name =>
      'سمكة الببغاء ذات الرأس الناتئ';

  @override
  String get species_bumphead_parrotfish_desc =>
      'أكبر أنواع سمك الببغاء ويبلغ طولها 1.3 متر، بنتوء جبهي ضخم. وتتنقل في أسراب على شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_stoplight_parrotfish_name => 'سمكة الببغاء إشارة المرور';

  @override
  String get species_stoplight_parrotfish_desc =>
      'سمكة ببغاء كاريبية شائعة بتغيرات لونية كبيرة بين الطورين الأولي والنهائي.';

  @override
  String get species_queen_parrotfish_name => 'سمكة الببغاء الملكة';

  @override
  String get species_queen_parrotfish_desc =>
      'سمكة ببغاء كبيرة زرقاء مخضرّة توجد في شعاب الكاريبي، وتُشاهد غالبًا وهي تقضم المرجان لتتغذى على الطحالب.';

  @override
  String get species_yellowtail_damselfish_name => 'سمكة الدمسل صفراء الذيل';

  @override
  String get species_yellowtail_damselfish_desc =>
      'سمكة دمسل زرقاء داكنة بذيل أصفر زاهٍ، شائعة على قمم وحواف شعاب الكاريبي.';

  @override
  String get species_sergeant_major_name => 'سمكة الرقيب';

  @override
  String get species_sergeant_major_desc =>
      'سمكة دمسل فضية مصفرّة بخمسة أشرطة سوداء جريئة، توجد في تجمعات كبيرة على شعاب الأطلسي الاستوائي.';

  @override
  String get species_three_spot_damselfish_name => 'سمكة الدمسل ثلاثية البقع';

  @override
  String get species_three_spot_damselfish_desc =>
      'سمكة دمسل بنية داكنة شديدة التمسك بمنطقتها تدافع بشراسة عن حديقتها من الطحالب في شعاب الكاريبي.';

  @override
  String get species_chromis_viridis_name => 'الكروميس الأزرق المخضرّ';

  @override
  String get species_chromis_viridis_desc =>
      'سمكة دمسل صغيرة خضراء لامعة تُشاهد في أسراب كبيرة تحوم فوق المرجان المتفرع في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_blue_chromis_name => 'الكروميس الأزرق';

  @override
  String get species_blue_chromis_desc =>
      'سمكة دمسل زرقاء لامعة تتغذى على العوالق وتوجد في تجمعات كبيرة في وسط الماء فوق جدران شعاب الكاريبي.';

  @override
  String get species_nassau_grouper_name => 'هامور ناسو';

  @override
  String get species_nassau_grouper_desc =>
      'هامور كاريبي كبير بخط داكن مميز عبر العين ونمط مخطط، وهو الآن مهدد بالانقراض بسبب الصيد الجائر.';

  @override
  String get species_giant_grouper_name => 'الهامور العملاق';

  @override
  String get species_giant_grouper_desc =>
      'أكبر سمكة شعاب عظمية، يبلغ طولها 2.7 متر ووزنها 400 كغ. توجد في الكهوف وحطام السفن عبر المحيطين الهندي والهادئ.';

  @override
  String get species_coral_grouper_name => 'الهامور المرجاني';

  @override
  String get species_coral_grouper_desc =>
      'هامور أحمر برتقالي زاهٍ مغطى ببقع زرقاء، وهو نوع مميز لشعاب المحيطين الهندي والهادئ المرجانية.';

  @override
  String get species_goliath_grouper_name => 'الهامور الجالوتي';

  @override
  String get species_goliath_grouper_desc =>
      'هامور أطلسي ضخم يبلغ طوله 2.5 متر، ويُصادَف غالبًا قرب الحطام والحواف الصخرية في فلوريدا والكاريبي.';

  @override
  String get species_potato_grouper_name => 'هامور البطاطا';

  @override
  String get species_potato_grouper_desc =>
      'هامور كبير ودود ببقع داكنة بحجم حبات البطاطا، ويشتهر في موقع كود هول بالحاجز المرجاني العظيم.';

  @override
  String get species_peacock_grouper_name => 'الهامور الطاووسي';

  @override
  String get species_peacock_grouper_desc =>
      'هامور بني داكن ببقع زرقاء زاهية وأشرطة عمودية فاتحة في المؤخرة، شائع في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_yellowfin_tuna_name => 'التونة صفراء الزعانف';

  @override
  String get species_yellowfin_tuna_desc =>
      'مفترس سريع من أعالي البحار بزعنفتين ظهرية وشرجية صفراوين طويلتين، يشاهده الغواصون أحيانًا في المواقع البعيدة عن الساحل.';

  @override
  String get species_dogtooth_tuna_name => 'تونة ناب الكلب';

  @override
  String get species_dogtooth_tuna_desc =>
      'تونة قوية ملازمة للشعاب بأسنان بارزة، تُصادَف عند المنحدرات العميقة في المحيطين الهندي والهادئ.';

  @override
  String get species_great_barracuda_name => 'الباراكودا الكبيرة';

  @override
  String get species_great_barracuda_desc =>
      'مفترس فضي انسيابي يبلغ طوله 1.8 متر بأسنان بارزة، ويُشاهد غالبًا محلّقًا بلا حراك قرب الشعاب الاستوائية.';

  @override
  String get species_blackfin_barracuda_name => 'الباراكودا سوداء الزعانف';

  @override
  String get species_blackfin_barracuda_desc =>
      'باراكودا من المحيطين الهندي والهادئ تشتهر بتشكيل أسراب ضخمة تشبه الإعصار في مواقع مثل باراكودا بوينت.';

  @override
  String get species_mahi_mahi_name => 'سمكة الماهي ماهي';

  @override
  String get species_mahi_mahi_desc =>
      'سمكة من أعالي البحار بألوان زرقاء مخضرّة وذهبية باهرة وجبهة عريضة، تُشاهد أحيانًا في مواقع الغوص البعيدة عن الساحل.';

  @override
  String get species_giant_trevally_name => 'التريفالي العملاق';

  @override
  String get species_giant_trevally_desc =>
      'مفترس فضي قوي يبلغ طوله 1.7 متر، ويشتهر بالصيد في قنوات الشعاب والمنحدرات عبر المحيطين الهندي والهادئ.';

  @override
  String get species_bluefin_trevally_name => 'التريفالي أزرق الزعانف';

  @override
  String get species_bluefin_trevally_desc =>
      'سمكة جاك انسيابية ببقع زرقاء تُشاهد عادةً وهي تجوب حواف الشعاب في المحيطين الهندي والهادئ ضمن مجموعات صيد صغيرة.';

  @override
  String get species_bigeye_trevally_name => 'التريفالي كبير العينين';

  @override
  String get species_bigeye_trevally_desc =>
      'سمكة جاك فضية بعينين كبيرتين تشكّل أسرابًا دوّامية مذهلة قرب جدران الشعاب ومحطات التنظيف.';

  @override
  String get species_bar_jack_name => 'سمكة الجاك المخططة';

  @override
  String get species_bar_jack_desc =>
      'سمكة جاك كاريبية فضية انسيابية بخط أزرق داكن مميز يمتد على طول الظهر حتى أسفل الذيل.';

  @override
  String get species_horse_eye_jack_name => 'سمكة الجاك ذات عين الحصان';

  @override
  String get species_horse_eye_jack_desc =>
      'سمكة جاك فضية كبيرة العينين تشكّل أسرابًا قرب الشعاب والحطام في الكاريبي وغرب الأطلسي.';

  @override
  String get species_yellowtail_snapper_name => 'النهّاش أصفر الذيل';

  @override
  String get species_yellowtail_snapper_desc =>
      'نهّاش انسيابي بخط جانبي وذيل أصفرين، يُشاهد غالبًا في أسراب وسط الماء على شعاب الكاريبي.';

  @override
  String get species_schoolmaster_snapper_name => 'النهّاش معلّم المدرسة';

  @override
  String get species_schoolmaster_snapper_desc =>
      'نهّاش أصفر فضي بخطوط زرقاء تحت العين، يوجد في مجموعات تحت الحواف الصخرية في شعاب الكاريبي.';

  @override
  String get species_bluestripe_snapper_name => 'النهّاش أزرق الخطوط';

  @override
  String get species_bluestripe_snapper_desc =>
      'نهّاش أصفر زاهٍ بأربعة خطوط أفقية زرقاء، يشكّل أسرابًا كثيفة في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_twinspot_snapper_name => 'النهّاش ثنائي البقعة';

  @override
  String get species_twinspot_snapper_desc =>
      'نهّاش أحمر كبير يوجد في الشعاب الخارجية بالمحيطين الهندي والهادئ، ويشكّل أحيانًا أسرابًا على الجدران العميقة والقنوات.';

  @override
  String get species_humphead_snapper_name => 'نهّاش منتصف الليل';

  @override
  String get species_humphead_snapper_desc =>
      'نهّاش داكن كبير يوجد في أسراب قرب المنحدرات الحادة بالمحيطين الهندي والهادئ، وصغاره بنقوش سوداء وبيضاء جريئة.';

  @override
  String get species_longfin_bannerfish_name => 'سمكة الراية طويلة الزعنفة';

  @override
  String get species_longfin_bannerfish_desc =>
      'سمكة بيضاء وسوداء بزعنفة ظهرية طويلة متدلية وذيل أصفر، تُشاهد غالبًا في أزواج على شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_batfish_orbicular_name => 'سمكة الخفاش المستديرة';

  @override
  String get species_batfish_orbicular_desc =>
      'سمكة فضية قرصية الشكل بزعانف مرتفعة تقترب من الغواصين بفضول. شائعة في حطام السفن والشعاب بالمحيطين الهندي والهادئ.';

  @override
  String get species_batfish_teira_name => 'سمكة الخفاش طويلة الزعنفة';

  @override
  String get species_batfish_teira_desc =>
      'سمكة خفاش مرتفعة الزعانف ببقعة داكنة قرب الزعنفة الصدرية، تُشاهد غالبًا عند محطات التنظيف وحطام السفن.';

  @override
  String get species_batfish_pinnatus_name => 'سمكة الخفاش الريشية';

  @override
  String get species_batfish_pinnatus_desc =>
      'صغارها سوداء حالكة بحواف برتقالية زاهية تشبه الدودة المفلطحة السامة. توجد في غرب المحيط الهادئ.';

  @override
  String get species_banggai_cardinalfish_name => 'سمكة الكاردينال البانغّاية';

  @override
  String get species_banggai_cardinalfish_desc =>
      'سمكة كاردينال لافتة بلونين فضي وأسود وزعانف مستطيلة، متوطنة في جزر بانغّاي بإندونيسيا.';

  @override
  String get species_pajama_cardinalfish_name => 'سمكة الكاردينال البيجامية';

  @override
  String get species_pajama_cardinalfish_desc =>
      'سمكة كاردينال غير مألوفة بوجه أصفر وحزام داكن في الوسط ومؤخرة منقّطة، توجد بين المرجان في المحيطين الهندي والهادئ.';

  @override
  String get species_longnose_hawkfish_name => 'سمكة الصقر طويلة الأنف';

  @override
  String get species_longnose_hawkfish_desc =>
      'سمكة بيضاء صغيرة بنمط شبكي أحمر وخطم مستطيل، ترتكز على المرجان المروحي والمرجان الأسود.';

  @override
  String get species_arc_eye_hawkfish_name => 'سمكة الصقر ذات قوس العين';

  @override
  String get species_arc_eye_hawkfish_desc =>
      'سمكة صقر صغيرة بقوس برتقالي مميز خلف العين، ترتكز عادةً على رؤوس المرجان في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_flame_hawkfish_name => 'سمكة الصقر اللهبية';

  @override
  String get species_flame_hawkfish_desc =>
      'سمكة صقر حمراء زاهية بعلامات داكنة حول العين، ترتكز بين مرجان Pocillopora عبر غرب المحيط الهادئ.';

  @override
  String get species_fire_goby_name => 'سمكة القوبيون النارية';

  @override
  String get species_fire_goby_desc =>
      'سمكة قوبيون بيضاء أنيقة بزعنفة ظهرية أولى مرتفعة وذيل أحمر برتقالي، تحوم فوق حطام الشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_purple_firefish_name => 'سمكة النار الأرجوانية';

  @override
  String get species_purple_firefish_desc =>
      'سمكة قوبيون رقيقة بزعانف أرجوانية وشوكة ظهرية مرتفعة، تحوم قرب جحورها في الشعاب الخارجية بالمحيطين الهندي والهادئ.';

  @override
  String get species_yellownose_goby_name => 'سمكة القوبيون صفراء الأنف';

  @override
  String get species_yellownose_goby_desc =>
      'سمكة قوبيون منظفة كاريبية صغيرة بخطم أصفر وخط جانبي أزرق، توجد على الإسفنجيات ورؤوس المرجان.';

  @override
  String get species_citron_goby_name => 'سمكة القوبيون الليمونية';

  @override
  String get species_citron_goby_desc =>
      'سمكة قوبيون صغيرة صفراء زاهية تعيش بين أفرع مرجان Acropora في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_shrimp_goby_name => 'سمكة قوبيون الروبيان الشتاينيتزية';

  @override
  String get species_shrimp_goby_desc =>
      'سمكة قوبيون بلون الرمال تتشارك الجحر مع روبيان من فصيلة Alpheidae في علاقة تكافلية على السهول الرملية بالمحيطين الهندي والهادئ.';

  @override
  String get species_neon_goby_name => 'سمكة القوبيون النيونية';

  @override
  String get species_neon_goby_desc =>
      'سمكة قوبيون داكنة صغيرة بخط أزرق نيوني لامع، تدير محطات التنظيف على رؤوس المرجان في الكاريبي.';

  @override
  String get species_bluestriped_fangblenny_name =>
      'سمكة البليني نابية الأسنان زرقاء الخطوط';

  @override
  String get species_bluestriped_fangblenny_desc =>
      'سمكة بليني صغيرة مخططة بالأزرق تحاكي أسماك الحريد المنظفة لتقتطع الحراشف من الأسماك الغافلة.';

  @override
  String get species_sailfin_blenny_name => 'سمكة البليني شراعية الزعنفة';

  @override
  String get species_sailfin_blenny_desc =>
      'سمكة بليني كاريبية صغيرة ترفع زعنفة ظهرية كبيرة تشبه الشراع من جحرها الأنبوبي لجذب الشريك.';

  @override
  String get species_bicolor_blenny_name => 'سمكة البليني ثنائية اللون';

  @override
  String get species_bicolor_blenny_desc =>
      'سمكة بليني صغيرة نصفها الأمامي بني داكن ونصفها الخلفي برتقالي، تطل من الثقوب في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_redlip_blenny_name => 'سمكة البليني حمراء الشفاه';

  @override
  String get species_redlip_blenny_desc =>
      'سمكة بليني داكنة بشفاه حمراء برتقالية بارزة تدافع عن رقع الطحالب على قمم شعاب الكاريبي.';

  @override
  String get species_pygmy_seahorse_name => 'حصان البحر القزم البارغيباني';

  @override
  String get species_pygmy_seahorse_desc =>
      'حصان بحر ضئيل يقل طوله عن سنتيمترين ويطابق تمامًا المرجان المروحي الذي يعيش عليه، وهو هدف ثمين للتصوير الماكرو.';

  @override
  String get species_common_seahorse_name => 'حصان البحر الشائع';

  @override
  String get species_common_seahorse_desc =>
      'حصان بحر متوسط الحجم يوجد في مروج الأعشاب البحرية وحطام المرجان عبر المحيطين الهندي والهادئ، ويتباين لونه كثيرًا.';

  @override
  String get species_thorny_seahorse_name => 'حصان البحر الشوكي';

  @override
  String get species_thorny_seahorse_desc =>
      'حصان بحر مغطى بأشواك طويلة يوجد في مروج الأعشاب البحرية والقيعان الطرية عبر المحيطين الهندي والهادئ.';

  @override
  String get species_ornate_ghost_pipefish_name =>
      'السمكة الأنبوبية الشبح المزخرفة';

  @override
  String get species_ornate_ghost_pipefish_desc =>
      'سمكة أنبوبية بتمويه بديع تحوم ورأسها إلى الأسفل قرب زنابق البحر والمرجان الطري في المحيطين الهندي والهادئ.';

  @override
  String get species_robust_ghost_pipefish_name =>
      'السمكة الأنبوبية الشبح القوية';

  @override
  String get species_robust_ghost_pipefish_desc =>
      'سمكة أنبوبية شبح كبيرة تحاكي الأعشاب البحرية أو الطحالب، وتوجد غالبًا في أزواج في المياه الساحلية بالمحيطين الهندي والهادئ.';

  @override
  String get species_trumpetfish_name => 'سمكة البوق';

  @override
  String get species_trumpetfish_desc =>
      'سمكة طويلة نحيلة تصطاد بمرافقة الأسماك الأكبر والاختباء خلفها، وتوجد بألوان متعددة في شعاب الكاريبي والأطلسي.';

  @override
  String get species_cornetfish_name => 'سمكة المزمار';

  @override
  String get species_cornetfish_desc =>
      'سمكة شديدة الاستطالة يبلغ طولها 1.5 متر بخيط ذيلي متدلٍ، وتُشاهد غالبًا وهي تنساب فوق مسطحات الشعاب.';

  @override
  String get species_yellowhead_jawfish_name => 'سمكة الفك صفراء الرأس';

  @override
  String get species_yellowhead_jawfish_desc =>
      'سمكة صغيرة زرقاء الجسم برأس أصفر تحوم فوق جحرها الرملي في شعاب الكاريبي. وتحضن الذكور البيض داخل أفواهها.';

  @override
  String get species_flamefish_name => 'سمكة اللهب';

  @override
  String get species_flamefish_desc =>
      'سمكة كاردينال صغيرة حمراء زاهية ببقعة داكنة تحت الزعنفة الظهرية الثانية، تختبئ نهارًا في شقوق شعاب الكاريبي.';

  @override
  String get species_longspine_squirrelfish_name => 'سمكة السنجاب طويلة الشوكة';

  @override
  String get species_longspine_squirrelfish_desc =>
      'سمكة حمراء ليلية النشاط بعينين كبيرتين وشوكة ظهرية طويلة، توجد نهارًا تحت الحواف الصخرية في شعاب الكاريبي.';

  @override
  String get species_soldierfish_name => 'سمكة الجندي كبيرة الحراشف';

  @override
  String get species_soldierfish_desc =>
      'سمكة حمراء ليلية النشاط بعينين داكنتين ضخمتين وحراشف كبيرة، تتجمع نهارًا في الكهوف وتحت النتوءات الصخرية.';

  @override
  String get species_flame_angelfish_name => 'سمكة الملاك اللهبية';

  @override
  String get species_flame_angelfish_desc =>
      'سمكة ملاك قزمة حمراء برتقالية زاهية بأشرطة عمودية سوداء وزعانف زرقاء الأطراف، توجد عبر المحيط الهادئ.';

  @override
  String get species_royal_gramma_name => 'سمكة الغراما الملكية';

  @override
  String get species_royal_gramma_desc =>
      'سمكة باسليت كاريبية صغيرة ثنائية اللون نصفها الأمامي أرجواني ونصفها الخلفي أصفر، توجد تحت الحواف الصخرية.';

  @override
  String get species_anthias_lyretail_name => 'الأنثياس قيثاري الذيل';

  @override
  String get species_anthias_lyretail_desc =>
      'سمكة شعاب وفيرة تشكّل سحبًا برتقالية ووردية كبيرة فوق التكوينات المرجانية بالمحيطين الهندي والهادئ. والذكور أرجوانية اللون.';

  @override
  String get species_mediterranean_grouper_name => 'الهامور الداكن';

  @override
  String get species_mediterranean_grouper_desc =>
      'هامور كبير بني داكن ببقع فاتحة، وهو المفترس الأيقوني للشعاب الصخرية في البحر المتوسط.';

  @override
  String get species_mediterranean_moray_name => 'المورَي المتوسطي';

  @override
  String get species_mediterranean_moray_desc =>
      'ثعبان بحر مورَي بني داكن ببقع صفراء، يُشاهد عادةً وهو يطل من الشقوق الصخرية في البحر المتوسط.';

  @override
  String get species_ornate_wrasse_name => 'الحريد المزخرف';

  @override
  String get species_ornate_wrasse_desc =>
      'سمكة حريد خضراء ملونة بعلامات حمراء على الرأس، وهي من أكثر أسماك الحريد شيوعًا في شعاب البحر المتوسط.';

  @override
  String get species_red_sea_bannerfish_name => 'سمكة الفراشة المقنّعة';

  @override
  String get species_red_sea_bannerfish_desc =>
      'سمكة فراشة صفراء زاهية برقعة داكنة على العين، متوطنة في البحر الأحمر. وتُشاهد غالبًا في أزواج.';

  @override
  String get species_red_sea_anemonefish_name => 'سمكة شقائق البحر الأحمر';

  @override
  String get species_red_sea_anemonefish_desc =>
      'سمكة شقائق برتقالية مصفرّة بشريطين أبيضين، متوطنة في البحر الأحمر وخليج عدن.';

  @override
  String get species_arabian_angelfish_name => 'سمكة الملاك العربية';

  @override
  String get species_arabian_angelfish_desc =>
      'سمكة ملاك كبيرة زرقاء داكنة بشريط عمودي أصفر جريء وذيل أصفر، متوطنة في غرب المحيط الهندي.';

  @override
  String get species_king_angelfish_name => 'سمكة الملاك الملك';

  @override
  String get species_king_angelfish_desc =>
      'سمكة ملاك كبيرة زرقاء داكنة بشريط عمودي أبيض وذيل أصفر، توجد في شرق المحيط الهادئ وجزر غالاباغوس.';

  @override
  String get species_ocean_sunfish_name => 'سمكة الشمس المحيطية';

  @override
  String get species_ocean_sunfish_desc =>
      'أثقل سمكة عظمية في العالم ويتجاوز وزنها طنّين. ويشاهدها الغواصون أحيانًا عند محطات التنظيف في بالي وغالاباغوس.';

  @override
  String get species_lingcod_name => 'سمكة اللينغكود';

  @override
  String get species_lingcod_desc =>
      'سمكة مفترسة كبيرة مبقّعة من فصيلة الغرينلينغ تعيش في الشعاب الصخرية بشمال غرب المحيط الهادئ، وتُشاهد غالبًا وهي تحرس كتل البيض.';

  @override
  String get species_wolf_eel_name => 'ثعبان الذئب';

  @override
  String get species_wolf_eel_desc =>
      'ثعبان ذئب رمادي كبير برأس منتفخ وفكين قويين، يعيش في أوكار صخرية بشمال غرب المحيط الهادئ.';

  @override
  String get species_giant_sea_bass_name => 'القاروص العملاق';

  @override
  String get species_giant_sea_bass_desc =>
      'سمكة قاروص ضخمة يتجاوز طولها مترين ووزنها 250 كغ، وتعيش في الشعاب الصخرية وغابات عشب البحر قبالة جنوب كاليفورنيا.';

  @override
  String get species_garibaldi_name => 'سمكة غاريبالدي';

  @override
  String get species_garibaldi_desc =>
      'سمكة دمسل برتقالية زاهية وهي السمكة البحرية الرسمية لولاية كاليفورنيا، شديدة التمسك بمنطقتها في شعاب غابات عشب البحر.';

  @override
  String get species_sheephead_name => 'سمكة رأس الخروف الكاليفورنية';

  @override
  String get species_sheephead_desc =>
      'سمكة حريد كبيرة برأس وذيل أسودين ووسط أحمر وذقن بيضاء. توجد في غابات عشب البحر بكاليفورنيا.';

  @override
  String get species_copper_rockfish_name => 'سمكة الصخور النحاسية';

  @override
  String get species_copper_rockfish_desc =>
      'سمكة صخور برتقالية نحاسية برقع فاتحة، وهي مشهد مألوف في الشعاب الصخرية وغابات عشب البحر بشمال غرب المحيط الهادئ.';

  @override
  String get species_oriental_sweetlips_name => 'سمكة الشفاه الحلوة الشرقية';

  @override
  String get species_oriental_sweetlips_desc =>
      'سمكة شعاب كبيرة من المحيطين الهندي والهادئ بخطوط سوداء وبيضاء جريئة وزعانف صفراء. وتؤدي صغارها رقصة متلوّية.';

  @override
  String get species_harlequin_sweetlips_name => 'سمكة الشفاه الحلوة المهرجة';

  @override
  String get species_harlequin_sweetlips_desc =>
      'البالغة رمادية ببقع داكنة؛ أما الصغار فبنية ببقع بيضاء كبيرة وتسبح بحركة متموجة.';

  @override
  String get species_blue_ringed_angelfish_name =>
      'سمكة الملاك ذات الحلقة الزرقاء';

  @override
  String get species_blue_ringed_angelfish_desc =>
      'سمكة ملاك بنية كبيرة بخطوط زرقاء منحنية وحلقة زرقاء مميزة فوق غطاء الخياشيم.';

  @override
  String get species_yellowbar_angelfish_name =>
      'سمكة الملاك ذات الشريط الأصفر';

  @override
  String get species_yellowbar_angelfish_desc =>
      'سمكة ملاك كبيرة رمادية مزرقّة برقعة صفراء بارزة على الجسم، توجد في البحر الأحمر وغرب المحيط الهندي.';

  @override
  String get species_filefish_scrawled_name => 'سمكة المبرد المخربشة';

  @override
  String get species_filefish_scrawled_desc =>
      'سمكة مبرد كبيرة بنية زيتونية بعلامات زرقاء تشبه الخربشات وزائدة جلدية برتقالية، توجد في الشعاب الاستوائية حول العالم.';

  @override
  String get species_clown_filefish_name => 'سمكة المبرد برتقالية البقع';

  @override
  String get species_clown_filefish_desc =>
      'سمكة مبرد خضراء صغيرة ببقع برتقالية وخطم طويل، تتغذى حصرًا على سلائل مرجان Acropora.';

  @override
  String get species_unicornfish_name => 'سمكة وحيد القرن زرقاء الشوكة';

  @override
  String get species_unicornfish_desc =>
      'سمكة جراح رمادية بقرن جبهي بارز وشوكتين زرقاوين عند الذيل، شائعة على مسطحات الشعاب بالمحيطين الهندي والهادئ.';

  @override
  String get species_surgeonfish_sailfin_name => 'سمكة الجراح الشراعية';

  @override
  String get species_surgeonfish_sailfin_desc =>
      'سمكة جراح بأشرطة جريئة وزعنفتين ظهرية وشرجية متسعتين للغاية، توجد عبر المحيطين الهندي والهادئ.';

  @override
  String get species_achilles_tang_name => 'سمكة جراح أخيل';

  @override
  String get species_achilles_tang_desc =>
      'سمكة جراح بنية داكنة ببقعة برتقالية جريئة على شكل دمعة قرب الذيل، توجد في مناطق الأمواج القوية بوسط المحيط الهادئ.';

  @override
  String get species_doctorfish_name => 'سمكة الطبيب';

  @override
  String get species_doctorfish_desc =>
      'سمكة جراح رمادية بنية بأشرطة داكنة خفيفة وشوكة ذيلية بارزة، شائعة في شعاب الكاريبي.';

  @override
  String get species_checkerboard_wrasse_name => 'الحريد رقعة الشطرنج';

  @override
  String get species_checkerboard_wrasse_desc =>
      'سمكة حريد ملونة بنمط شبيه برقعة الشطرنج من المربعات الخضراء والوردية والسوداء على طول الجسم.';

  @override
  String get species_bird_wrasse_name => 'حريد الطائر';

  @override
  String get species_bird_wrasse_desc =>
      'سمكة حريد بخطم شديد الاستطالة يشبه منقار الطائر، والذكور خضراء داكنة والإناث بنية.';

  @override
  String get species_sling_jaw_wrasse_name => 'الحريد ذو الفك المقذوف';

  @override
  String get species_sling_jaw_wrasse_desc =>
      'سمكة حريد بفك قابل للامتداد ينطلق إلى الأمام لالتقاط الفريسة، وتوجد بطورين لونيين أصفر أو بني.';

  @override
  String get species_peacock_flounder_name => 'سمكة موسى الطاووسية';

  @override
  String get species_peacock_flounder_desc =>
      'سمكة مفلطحة تعيش على القاع بحلقات وبقع زرقاء، ويمكنها تغيير لونها لتطابق قاع البحر.';

  @override
  String get species_hogfish_name => 'سمكة الخنزير';

  @override
  String get species_hogfish_desc =>
      'سمكة حريد كبيرة من غرب الأطلسي بخطم يشبه خطم الخنزير وأشواك ظهرية مستطيلة، توجد قرب الشعاب والحطام.';

  @override
  String get species_tarpon_name => 'التاربون الأطلسي';

  @override
  String get species_tarpon_desc =>
      'سمكة فضية ضخمة بحراشف كبيرة تشبه المرايا، ويصادفها الغواصون أحيانًا في كهوف الكاريبي وقنواته.';

  @override
  String get species_permit_name => 'سمكة البيرمِت';

  @override
  String get species_permit_desc =>
      'سمكة جاك فضية عميقة الجسم بذيل داكن مشقوق، توجد على السهول الرملية وقرب الشعاب في الكاريبي.';

  @override
  String get species_spotted_drum_name => 'سمكة الطبل المرقّطة';

  @override
  String get species_spotted_drum_desc =>
      'سمكة كاريبية لافتة بزعنفة ظهرية مرتفعة مستطيلة ونمط منقّط جريء بالأسود والأبيض.';

  @override
  String get species_jackknife_fish_name => 'سمكة المطواة';

  @override
  String get species_jackknife_fish_desc =>
      'سمكة كاريبية أنيقة بخط أسود مرتفع على الزعنفة الظهرية وشريط مائل على الجسم، توجد تحت الحواف الصخرية.';

  @override
  String get species_bigeye_name => 'سمكة العين الزجاجية';

  @override
  String get species_bigeye_desc =>
      'سمكة حمراء زاهية ليلية النشاط بعينين كبيرتين عاكستين، تختبئ في كهوف شعاب الكاريبي والأطلسي.';

  @override
  String get species_remora_name => 'سمكة الريمورا';

  @override
  String get species_remora_desc =>
      'سمكة نحيلة بقرص ماص على رأسها تلتصق بأسماك القرش والشفنين والسلاحف وغيرها من الحيوانات الكبيرة.';

  @override
  String get species_tilefish_sand_name => 'سمكة البلاط الرملية';

  @override
  String get species_tilefish_sand_desc =>
      'سمكة مستطيلة زرقاء فاتحة تبني أكوامًا من الحطام فوق المناطق الرملية في شعاب الكاريبي.';

  @override
  String get species_weedy_seadragon_name => 'تنين البحر العشبي';

  @override
  String get species_weedy_seadragon_desc =>
      'قريب مزخرف لأحصنة البحر بزوائد تشبه الأوراق، متوطن في المياه المعتدلة بجنوب أستراليا.';

  @override
  String get species_leafy_seadragon_name => 'تنين البحر الورقي';

  @override
  String get species_leafy_seadragon_desc =>
      'تنين بحر مذهل مغطى بنتوءات ورقية معقدة، متوطن في جنوب أستراليا. وهو من أبرز مشاهدات الغوص التي يحلم بها الغواصون.';

  @override
  String get species_sailfin_snapper_name => 'النهّاش الشراعي';

  @override
  String get species_sailfin_snapper_desc =>
      'نهّاش أنيق بلونين أصفر وأزرق وزعنفتين ظهرية وشرجية مستطيلتين، يوجد على منحدرات الشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_sweetlip_emperor_name => 'الشعري المرصّع';

  @override
  String get species_sweetlip_emperor_desc =>
      'سمكة شعري فضية كبيرة بخطوط زرقاء على الوجه وحواف زعانف صفراء، شائعة فوق المناطق الرملية للشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_crocodilefish_name => 'سمكة التمساح';

  @override
  String get species_crocodilefish_desc =>
      'مفترس كمين مسطح الرأس بأهداب عينية معقدة، يرقد بتمويه تام على أرضيات الشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_devil_scorpionfish_name => 'السمكة العقربية الشيطانية';

  @override
  String get species_devil_scorpionfish_desc =>
      'سمكة عقربية ممتلئة ومموّهة بزعانف صدرية ملونة من الداخل تكشفها كإنذار للمفترسات.';

  @override
  String get species_spiny_devilfish_name => 'لاسع الشيطان';

  @override
  String get species_spiny_devilfish_desc =>
      'ساكن قاع سام يمشي على أشعة زعنفية معدّلة ويكشف زعانفه الصدرية الزاهية عند إزعاجه.';

  @override
  String get species_waspfish_name => 'سمكة الدبور الكوكاتو';

  @override
  String get species_waspfish_desc =>
      'سمكة عقربية صغيرة مضغوطة الجسم تتمايل مع التيار كورقة ذابلة فوق القيعان الطينية في المحيطين الهندي والهادئ.';

  @override
  String get species_stargazer_name => 'سمكة راصد النجوم بيضاء الحواف';

  @override
  String get species_stargazer_desc =>
      'مفترس كمين يدفن نفسه في الرمال ولا تظهر منه سوى عينيه، ويمكنه إطلاق صدمات كهربائية. يوجد في المحيطين الهندي والهادئ.';

  @override
  String get species_striped_catfish_name => 'سمكة السلور المخططة';

  @override
  String get species_striped_catfish_desc =>
      'سمكة سلور بأشواك سامة؛ وتشكّل صغارها أسرابًا كثيفة كروية الشكل تتدحرج فوق أرضيات الشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_red_emperor_name => 'الشعري الأحمر';

  @override
  String get species_red_emperor_desc =>
      'نهّاش كبير؛ البالغة حمراء وردية والصغار بأشرطة حمراء وبيضاء جريئة. يوجد في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_mangrove_snapper_name => 'نهّاش المانغروف';

  @override
  String get species_mangrove_snapper_desc =>
      'نهّاش رمادي يوجد في غابات المانغروف والأعشاب البحرية والشعاب بالكاريبي، ويتجمع غالبًا قرب البنى القائمة.';

  @override
  String get species_dottyback_orchid_name => 'سمكة الدوتيباك الأوركيدية';

  @override
  String get species_dottyback_orchid_desc =>
      'سمكة صغيرة أرجوانية زاهية متوطنة في البحر الأحمر، تندفع داخل الشقوق وخارجها على الجدران المرجانية الحادة.';

  @override
  String get species_dottyback_royal_name => 'سمكة الدوتيباك الملكية';

  @override
  String get species_dottyback_royal_desc =>
      'سمكة صغيرة ثنائية اللون بمقدمة قرمزية ومؤخرة صفراء زاهية، توجد على جدران الشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_coral_trout_name => 'التروتة المرجانية';

  @override
  String get species_coral_trout_desc =>
      'مفترس ثمين في الحاجز المرجاني العظيم بجسم أحمر برتقالي مغطى ببقع زرقاء.';

  @override
  String get species_barramundi_cod_name => 'هامور البراموندي';

  @override
  String get species_barramundi_cod_desc =>
      'هامور مميز برأس صغير وجسم محدودب ونقاط داكنة على خلفية فاتحة.';

  @override
  String get species_spadefish_atlantic_name => 'سمكة المجرفة الأطلسية';

  @override
  String get species_spadefish_atlantic_desc =>
      'سمكة فضية قرصية الشكل بأشرطة عمودية داكنة، تُشاهد غالبًا في أسراب كبيرة حول حطام السفن في الكاريبي.';

  @override
  String get species_fusilier_yellowback_name => 'سمكة الفوزلير صفراء الظهر';

  @override
  String get species_fusilier_yellowback_desc =>
      'سمكة زرقاء انسيابية تتغذى على العوالق وظهرها أصفر، وتشكّل أسرابًا ضخمة فوق منحدرات الشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_fusilier_bluestreak_name => 'سمكة الفوزلير زرقاء الخط';

  @override
  String get species_fusilier_bluestreak_desc =>
      'سمكة فوزلير زرقاء صغيرة بخط جانبي داكن، تُشاهد في أسراب سريعة الحركة على طول جدران الشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_porkfish_name => 'سمكة الخنزير الهادرة';

  @override
  String get species_porkfish_desc =>
      'سمكة هدير كاريبية ملونة بخطوط زرقاء وصفراء وشريطين أسودين على الرأس، توجد قرب الشعاب والحطام.';

  @override
  String get species_blue_striped_grunt_name => 'سمكة الهدير زرقاء الخطوط';

  @override
  String get species_blue_striped_grunt_desc =>
      'سمكة هدير كاريبية صفراء بخطوط أفقية زرقاء زاهية، تشكّل نهارًا أسرابًا كبيرة ساكنة تحت الحواف الصخرية.';

  @override
  String get species_french_grunt_name => 'سمكة الهدير الفرنسية';

  @override
  String get species_french_grunt_desc =>
      'سمكة هدير صغيرة بخطوط صفراء تشكّل أسرابًا ساكنة كثيفة على شعاب الكاريبي خلال ساعات النهار.';

  @override
  String get species_convict_tang_name => 'سمكة الجراح السجينة';

  @override
  String get species_convict_tang_desc =>
      'سمكة جراح فاتحة اللون بستة أشرطة عمودية سوداء، تُشاهد غالبًا وهي ترعى في أسراب كبيرة على مسطحات الشعاب بالمحيطين الهندي والهادئ.';

  @override
  String get species_great_hammerhead_name => 'قرش المطرقة المسنن';

  @override
  String get species_great_hammerhead_desc =>
      'قرش مميز برأس مطرقي مسنن الحواف، يشكّل أسرابًا كبيرة عند الجبال البحرية والجزر البعيدة عن الساحل.';

  @override
  String get species_wobbegong_name => 'قرش السجاد المرقّط';

  @override
  String get species_wobbegong_desc =>
      'قرش سجاد مسطح جيد التمويه بفصوص مهدّبة حول الفم، يوجد في الشعاب المعتدلة بأستراليا.';

  @override
  String get species_manta_ray_name => 'شفنين المانتا الشعابي';

  @override
  String get species_manta_ray_desc =>
      'عملاق رشيق يبلغ باع جناحيه خمسة أمتار، يزور محطات التنظيف ويتغذى على العوالق في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_oceanic_manta_name => 'شفنين المانتا المحيطي';

  @override
  String get species_oceanic_manta_desc =>
      'أكبر أنواع الشفنين ويتجاوز باع جناحيه سبعة أمتار، ويُصادَف عند الجبال البحرية البعيدة عن الساحل ومحطات التنظيف.';

  @override
  String get species_undulated_moray_name => 'ثعبان البحر المورَي المتموّج';

  @override
  String get species_undulated_moray_desc =>
      'مورَي أخضر مصفرّ بعلامات داكنة متموجة، يُشاهد عادةً وهو يصطاد ليلًا في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_whitemouth_moray_name => 'ثعبان البحر المورَي أبيض الفم';

  @override
  String get species_whitemouth_moray_desc =>
      'مورَي بني داكن ببقع بيضاء صغيرة وداخل فم أبيض مميز، يوجد عبر المحيطين الهندي والهادئ.';

  @override
  String get species_dragon_moray_name => 'ثعبان البحر المورَي التنيني';

  @override
  String get species_dragon_moray_desc =>
      'مورَي لافت بقرون تشبه قرون التنين فوق منخريه وبقع برتقالية حمراء تشبه بقع الفهد، يوجد في المحيطين الهندي والهادئ.';

  @override
  String get species_lyretail_grouper_name => 'الهامور قيثاري الذيل';

  @override
  String get species_lyretail_grouper_desc =>
      'هامور أحمر وردي ببقع زرقاء وذيل هلالي مميز، يوجد على جدران الشعاب الخارجية في المحيطين الهندي والهادئ.';

  @override
  String get species_banded_butterflyfish_name => 'سمكة الفراشة المخططة';

  @override
  String get species_banded_butterflyfish_desc =>
      'سمكة فراشة بيضاء بأربعة أشرطة عمودية سوداء جريئة، وهي من أكثر أسماك الفراشة شيوعًا في شعاب الكاريبي.';

  @override
  String get species_ringed_pipefish_name => 'السمكة الأنبوبية ذات الحلقات';

  @override
  String get species_ringed_pipefish_desc =>
      'سمكة أنبوبية نحيلة بحلقات حمراء وبيضاء متناوبة، توجد في الكهوف وتحت الحواف الصخرية في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_razorfish_name => 'سمكة الموسى';

  @override
  String get species_razorfish_desc =>
      'سمكة ضئيلة تسبح عموديًا ورأسها إلى الأسفل ضمن مجموعات، وتختبئ غالبًا بين أشواك قنافذ البحر في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_harlequin_tuskfish_name => 'سمكة الناب المهرجة';

  @override
  String get species_harlequin_tuskfish_desc =>
      'سمكة حريد ملونة بأنياب زرقاء زاهية وأشرطة حمراء برتقالية ورقع بيضاء، توجد في شعاب غرب المحيط الهادئ.';

  @override
  String get species_blue_groper_name => 'الحريد الأزرق الأسترالي';

  @override
  String get species_blue_groper_desc =>
      'سمكة حريد زرقاء كبيرة متوطنة في شرق أستراليا، وديعة وكثيرًا ما تقترب من الغواصين في الشعاب المعتدلة.';

  @override
  String get species_red_lipped_batfish_name => 'سمكة الخفاش حمراء الشفاه';

  @override
  String get species_red_lipped_batfish_desc =>
      'سمكة غريبة مسطحة الجسم بشفاه حمراء زاهية تمشي على زعانف معدّلة على قاع بحر غالاباغوس.';

  @override
  String get species_orangeband_surgeonfish_name =>
      'سمكة الجراح ذات الشريط البرتقالي';

  @override
  String get species_orangeband_surgeonfish_desc =>
      'سمكة جراح رمادية بنية بشريط أفقي برتقالي خلف العين، توجد على منحدرات الشعاب في المحيط الهادئ.';

  @override
  String get species_maori_wrasse_name => 'الحريد الماوري';

  @override
  String get species_maori_wrasse_desc =>
      'سمكة حريد متوسطة الحجم بشريط داكن خلف الزعنفة الصدرية، شائعة في شعاب المحيط الهادئ والمحيط الهندي.';

  @override
  String get species_blue_ringed_octopus_name => 'الأخطبوط ذو الحلقات الزرقاء';

  @override
  String get species_blue_ringed_octopus_desc =>
      'أخطبوط صغير لكنه شديد السمّية بحلقات زرقاء زاهية تتوهج عند شعوره بالتهديد.';

  @override
  String get species_common_octopus_name => 'الأخطبوط الشائع';

  @override
  String get species_common_octopus_desc =>
      'أخطبوط عالي الذكاء يشتهر بتغيير ألوانه السريع وقدرته على حل المشكلات.';

  @override
  String get species_giant_pacific_octopus_name => 'الأخطبوط الهادئي العملاق';

  @override
  String get species_giant_pacific_octopus_desc =>
      'أكبر أنواع الأخطبوط، ويتجاوز امتداد أذرعه أربعة أمتار في مياه المحيط الهادئ الباردة.';

  @override
  String get species_mimic_octopus_name => 'الأخطبوط المحاكي';

  @override
  String get species_mimic_octopus_desc =>
      'أخطبوط مذهل يقلّد مظهر أنواع بحرية أخرى وسلوكها.';

  @override
  String get species_coconut_octopus_name => 'أخطبوط جوز الهند';

  @override
  String get species_coconut_octopus_desc =>
      'أخطبوط صغير يشتهر بحمل قشور جوز الهند واستخدامها ملاجئ متنقلة.';

  @override
  String get species_day_octopus_name => 'الأخطبوط النهاري';

  @override
  String get species_day_octopus_desc =>
      'صياد نشط في النهار شائع في شعاب المحيطين الهندي والهادئ ويتمتع بقدرات تمويه مذهلة.';

  @override
  String get species_wonderpus_octopus_name => 'الأخطبوط العجيب';

  @override
  String get species_wonderpus_octopus_desc =>
      'أخطبوط لافت بأشرطة بيضاء وبنية فريدة يوجد في مواقع الغوص الرملية الطينية.';

  @override
  String get species_broadclub_cuttlefish_name => 'السبيدج عريض المجسّات';

  @override
  String get species_broadclub_cuttlefish_desc =>
      'سبيدج كبير بعروض لونية آسرة، ويُشاهد عادةً في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_pharaoh_cuttlefish_name => 'السبيدج الفرعوني';

  @override
  String get species_pharaoh_cuttlefish_desc =>
      'سبيدج كبير يوجد في أنحاء المحيط الهندي ويشتهر بأنماطه اللونية النابضة.';

  @override
  String get species_flamboyant_cuttlefish_name => 'السبيدج المتباهي';

  @override
  String get species_flamboyant_cuttlefish_desc =>
      'سبيدج ضئيل الحجم يمشي على قاع البحر عارضًا نبضات أرجوانية ووردية وصفراء زاهية.';

  @override
  String get species_giant_cuttlefish_name => 'السبيدج العملاق';

  @override
  String get species_giant_cuttlefish_desc =>
      'أكبر سبيدج في العالم، ويشتهر بتجمعات التكاثر الجماعية في جنوب أستراليا.';

  @override
  String get species_bigfin_reef_squid_name => 'حبّار الشعاب كبير الزعانف';

  @override
  String get species_bigfin_reef_squid_desc =>
      'حبّار يعيش في أسراب ويُصادَف كثيرًا في الغوصات الليلية، وتجذبه أضواء الغواصين.';

  @override
  String get species_caribbean_reef_squid_name => 'حبّار شعاب الكاريبي';

  @override
  String get species_caribbean_reef_squid_desc =>
      'حبّار فضولي يُشاهد غالبًا وهو يحوم في مجموعات صغيرة قرب حواف الشعاب في الكاريبي.';

  @override
  String get species_bobtail_squid_name => 'الحبّار قصير الذيل';

  @override
  String get species_bobtail_squid_desc =>
      'حبّار ضئيل ليلي النشاط يدفن نفسه في الرمال نهارًا، وهو صيد ثمين في غوصات القيعان الطينية.';

  @override
  String get species_chambered_nautilus_name => 'النوتيلوس ذو الحجرات';

  @override
  String get species_chambered_nautilus_desc =>
      'أحفورة حية قديمة بصدفة ملتفة، نادرًا ما يراها الغواصون في المياه العميقة عند الفجر.';

  @override
  String get species_spanish_dancer_name => 'الراقصة الإسبانية';

  @override
  String get species_spanish_dancer_desc =>
      'أكبر أنواع الرخويات عارية الخياشيم، تسبح بتموّج عباءتها الحمراء كراقصة فلامنكو.';

  @override
  String get species_chromodoris_willani_name => 'كروموذوريس ويلان';

  @override
  String get species_chromodoris_willani_desc =>
      'رخوية عارية الخياشيم لافتة بلونين أزرق وأسود وحافة بيضاء، شائعة في المحيطين الهندي والهادئ.';

  @override
  String get species_chromodoris_lochi_name => 'كروموذوريس لوخ';

  @override
  String get species_chromodoris_lochi_desc =>
      'رخوية زرقاء عارية الخياشيم بخطوط داكنة وحافة بيضاء، توجد في أنحاء المحيط الهادئ الاستوائي.';

  @override
  String get species_chromodoris_magnifica_name => 'الكروموذوريس البديع';

  @override
  String get species_chromodoris_magnifica_desc =>
      'رخوية عارية الخياشيم زاهية بالأزرق والأبيض والبرتقالي، توجد في الشعاب المرجانية بالمحيطين الهندي والهادئ.';

  @override
  String get species_chromodoris_annae_name => 'كروموذوريس آنا';

  @override
  String get species_chromodoris_annae_desc =>
      'رخوية عارية الخياشيم زرقاء داكنة بخطوط سوداء وقرون شمية وخياشيم برتقالية الأطراف.';

  @override
  String get species_nembrotha_kubaryana_name => 'بزاقة النيون المتغيّرة';

  @override
  String get species_nembrotha_kubaryana_desc =>
      'رخوية عارية الخياشيم خضراء داكنة بعلامات برتقالية أو حمراء زاهية، تتغذى على البخّاسات.';

  @override
  String get species_nembrotha_cristata_name => 'النمبروثا المعرّفة';

  @override
  String get species_nembrotha_cristata_desc =>
      'رخوية عارية الخياشيم سوداء ببثرات وخطوط خضراء زاهية، توجد في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_phyllidia_varicosa_name => 'الفيليديا الدوالية';

  @override
  String get species_phyllidia_varicosa_desc =>
      'رخوية عارية الخياشيم رمادية مزرقّة بحديبات ناتئة صفراء الأطراف، وهي سامة للمفترسات.';

  @override
  String get species_phyllidia_ocellata_name => 'الفيليديا ذات العيون';

  @override
  String get species_phyllidia_ocellata_desc =>
      'رخوية عارية الخياشيم بيضاء بحديبات ناتئة محاطة بحلقات وردية، توجد في الشعاب الاستوائية.';

  @override
  String get species_pikachu_nudibranch_name => 'رخوية بيكاتشو عارية الخياشيم';

  @override
  String get species_pikachu_nudibranch_desc =>
      'بزاقة بحر ضئيلة صفراء وسوداء تشبه شخصية كرتونية، توجد في المحيط الهادئ.';

  @override
  String get species_anna_rosefieldi_name => 'رخوية الروبوأسترا';

  @override
  String get species_anna_rosefieldi_desc =>
      'رخوية عارية الخياشيم مفترسة بجسم داكن وخطوط طولية زاهية تصطاد البزاقات الأخرى.';

  @override
  String get species_lettuce_sea_slug_name => 'بزاقة البحر الخسّية';

  @override
  String get species_lettuce_sea_slug_desc =>
      'بزاقة بحر خضراء مكشكشة تحتفظ بالصانعات الخضراء من الطحالب لإجراء التمثيل الضوئي.';

  @override
  String get species_blue_dragon_nudibranch_name => 'رخوية التنين الأزرق';

  @override
  String get species_blue_dragon_nudibranch_desc =>
      'رخوية عارية الخياشيم طويلة بزوائد ظهرية زرقاء الأطراف تحتضن طحالب زوزانثيلا متكافلة.';

  @override
  String get species_gloomy_nudibranch_name => 'الرخوية الكئيبة عارية الخياشيم';

  @override
  String get species_gloomy_nudibranch_desc =>
      'رخوية عارية الخياشيم زرقاء مخضرّة داكنة بحواف زرقاء بارزة، شائعة في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_ocellined_nudibranch_name => 'الرخوية ذات الحواف المعيّنة';

  @override
  String get species_ocellined_nudibranch_desc =>
      'رخوية عارية الخياشيم بيضاء بحواف مبطنة بالبرتقالي تشكّل أنماطًا هندسية على عباءتها.';

  @override
  String get species_glossodoris_cincta_name => 'رخوية الغلوسودوريس';

  @override
  String get species_glossodoris_cincta_desc =>
      'رخوية عارية الخياشيم بلون كريمي بإطار بني داكن وحافة برتقالية على العباءة.';

  @override
  String get species_jorunna_funebris_name => 'الرخوية المنقّطة';

  @override
  String get species_jorunna_funebris_desc =>
      'رخوية عارية الخياشيم بيضاء مغطاة بحُليمات caryophyllidia سوداء الأطراف، تشبه أرنبًا وبريًا.';

  @override
  String get species_ceratosoma_trilobatum_name => 'الرخوية ثلاثية الفصوص';

  @override
  String get species_ceratosoma_trilobatum_desc =>
      'رخوية عارية الخياشيم كبيرة بقرن ظهري مرتفع وفصوص جانبية بدرجات أرجوانية وصفراء.';

  @override
  String get species_hypselodoris_apolegma_name => 'الهيبسيلودوريس الأرجواني';

  @override
  String get species_hypselodoris_apolegma_desc =>
      'رخوية عارية الخياشيم أرجوانية أنيقة بحافة عباءة بيضاء، توجد في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_hypselodoris_bullockii_name => 'هيبسيلودوريس بولوك';

  @override
  String get species_hypselodoris_bullockii_desc =>
      'رخوية عارية الخياشيم وردية وأرجوانية بقرون شمية صفراء الأطراف في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_flabellina_exoptata_name => 'الفلابيلينا المرغوبة';

  @override
  String get species_flabellina_exoptata_desc =>
      'رخوية عارية الخياشيم شفافة بزوائد ظهرية برتقالية أرجوانية الأطراف، توجد في المياه الاستوائية.';

  @override
  String get species_risbecia_tryoni_name => 'ريسبيسيا ترايون';

  @override
  String get species_risbecia_tryoni_desc =>
      'رخوية عارية الخياشيم كبيرة بنية وزرقاء تُشاهد غالبًا في أزواج متزاوجة على شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_goniobranchus_kuniei_name => 'رخوية كوني';

  @override
  String get species_goniobranchus_kuniei_desc =>
      'رخوية عارية الخياشيم بيضاء ببقع برتقالية وحافة عباءة أرجوانية، توجد في غرب المحيط الهادئ.';

  @override
  String get species_mexichromis_multituberculata_name =>
      'الرخوية متعددة الحديبات';

  @override
  String get species_mexichromis_multituberculata_desc =>
      'رخوية عارية الخياشيم أرجوانية وبيضاء بحديبات ناتئة وزوائد برتقالية الأطراف.';

  @override
  String get species_chromodoris_dianae_name => 'كروموذوريس ديانا';

  @override
  String get species_chromodoris_dianae_desc =>
      'رخوية عارية الخياشيم زرقاء زاهية بخطوط سوداء وخياشيم برتقالية، توجد في غرب المحيط الهادئ.';

  @override
  String get species_phyllodesmium_poindimiei_name =>
      'الرخوية العاملة بالطاقة الشمسية';

  @override
  String get species_phyllodesmium_poindimiei_desc =>
      'رخوية عارية الخياشيم شفافة بزوائد ظهرية متفرعة تحتضن طحالب الزوزانثيلا.';

  @override
  String get species_chromodoris_elisabethina_name => 'كروموذوريس إليزابيث';

  @override
  String get species_chromodoris_elisabethina_desc =>
      'رخوية عارية الخياشيم بخطوط زرقاء وصفراء وحافة عباءة بيضاء، شائعة في جنوب شرق آسيا.';

  @override
  String get species_doridella_batava_name => 'الدوريد الباتافي';

  @override
  String get species_doridella_batava_desc =>
      'رخوية دوريدية عارية الخياشيم يتراوح لونها بين الأسود والبني، توجد تحت الصخور وبين الحطام في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_tiger_cowrie_name => 'ودع النمر';

  @override
  String get species_tiger_cowrie_desc =>
      'صدفة ودع كبيرة منقّطة توجد في الشعاب الاستوائية، وتغطيها عباءتها جزئيًا في الغالب.';

  @override
  String get species_tritons_trumpet_name => 'بوق ترايتون';

  @override
  String get species_tritons_trumpet_desc =>
      'حلزون مفترس كبير وهو العدو الطبيعي لنجم البحر إكليل الشوك.';

  @override
  String get species_queen_conch_name => 'القوقع الملكي';

  @override
  String get species_queen_conch_desc =>
      'قوقع كبير أيقوني في مروج الأعشاب البحرية بالكاريبي بشفة داخلية وردية مميزة.';

  @override
  String get species_banded_coral_shrimp_name => 'روبيان المرجان المخطط';

  @override
  String get species_banded_coral_shrimp_desc =>
      'روبيان منظف بأشرطة حمراء وبيضاء وقرون استشعار بيضاء طويلة، يوجد في شقوق الشعاب.';

  @override
  String get species_mantis_shrimp_name => 'روبيان السرعوف الطاووسي';

  @override
  String get species_mantis_shrimp_desc =>
      'مفترس ملوّن بزوائد قوية تشبه الهراوات قادرة على تحطيم الأصداف.';

  @override
  String get species_cleaner_shrimp_name => 'الروبيان المنظف القرمزي';

  @override
  String get species_cleaner_shrimp_desc =>
      'روبيان أحمر وأبيض زاهٍ ينشئ محطات تنظيف لخدمة أسماك الشعاب.';

  @override
  String get species_pederson_cleaner_shrimp_name => 'روبيان بيدرسون المنظف';

  @override
  String get species_pederson_cleaner_shrimp_desc =>
      'روبيان منظف كاريبي شفاف يعيش بين مجسّات شقائق النعمان البحرية.';

  @override
  String get species_harlequin_shrimp_name => 'الروبيان المهرج';

  @override
  String get species_harlequin_shrimp_desc =>
      'روبيان بنقوش لافتة وكلّابات مسطحة يتغذى حصرًا على نجوم البحر.';

  @override
  String get species_coleman_shrimp_name => 'روبيان كولمان';

  @override
  String get species_coleman_shrimp_desc =>
      'روبيان ضئيل يعيش في أزواج على قنافذ البحر النارية، وهو مطلب ثمين لمصوري ما تحت الماء.';

  @override
  String get species_emperor_shrimp_name => 'الروبيان الإمبراطور';

  @override
  String get species_emperor_shrimp_desc =>
      'روبيان متعايش ملوّن يمتطي خيار البحر والرخويات عارية الخياشيم.';

  @override
  String get species_sexy_shrimp_name => 'الروبيان الراقص';

  @override
  String get species_sexy_shrimp_desc =>
      'روبيان شقائق ضئيل يشتهر برقصة تلويح ذيله، وهو مفضل في التصوير الماكرو.';

  @override
  String get species_marble_shrimp_name => 'الروبيان المرمّري';

  @override
  String get species_marble_shrimp_desc =>
      'روبيان ليلي النشاط مبقّع بأرجل ريشية، يختبئ نهارًا في شقوق الشعاب.';

  @override
  String get species_spiny_lobster_name => 'الكركند الشوكي الكاريبي';

  @override
  String get species_spiny_lobster_desc =>
      'كركند كبير بلا كلّابات وبقرون استشعار طويلة، يحتمي تحت حواف الشعاب.';

  @override
  String get species_painted_spiny_lobster_name => 'الكركند الشوكي المرسوم';

  @override
  String get species_painted_spiny_lobster_desc =>
      'كركند زاهي الألوان بأرجل مخططة بالأزرق والأخضر والأبيض في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_slipper_lobster_name => 'كركند النعل';

  @override
  String get species_slipper_lobster_desc =>
      'كركند ليلي النشاط مسطح الجسم بصفائح استشعار عريضة بدلًا من القرون الطويلة.';

  @override
  String get species_squat_lobster_name => 'الكركند القرفصائي';

  @override
  String get species_squat_lobster_desc =>
      'قشري ضئيل بلون وردي أرجواني يعيش على الإسفنج البرميلي العملاق، وهو مفضل في التصوير الماكرو.';

  @override
  String get species_hermit_crab_name => 'السرطان الناسك أزرق الأرجل';

  @override
  String get species_hermit_crab_desc =>
      'سرطان ناسك صغير بأرجل زرقاء زاهية يُشاهد عادةً في شعاب الكاريبي.';

  @override
  String get species_orangutan_crab_name => 'سرطان الأورانغوتان';

  @override
  String get species_orangutan_crab_desc =>
      'سرطان ضئيل كثيف الشعر يعيش في المرجان الفقاعي، وسُمّي بذلك لشبهه بالأورانغوتان.';

  @override
  String get species_decorator_crab_name => 'السرطان المزخرِف';

  @override
  String get species_decorator_crab_desc =>
      'سيد التنكّر الذي يثبّت الإسفنج والطحالب والهيدرات على درعه.';

  @override
  String get species_porcelain_crab_name => 'سرطان الشقائق الخزفي';

  @override
  String get species_porcelain_crab_desc =>
      'سرطان مسطح منقّط يعيش في شقائق النعمان البحرية ويتغذى بالترشيح بأجزاء فم ريشية.';

  @override
  String get species_arrow_crab_name => 'سرطان السهم';

  @override
  String get species_arrow_crab_desc =>
      'سرطان كاريبي نحيل الأطراف بمنقار مدبب طويل وأرجل مخططة.';

  @override
  String get species_channel_clinging_crab_name => 'سرطان القنوات المتشبث';

  @override
  String get species_channel_clinging_crab_desc =>
      'سرطان شعاب كاريبي كبير بجسم داكن وكلّابات حمراء برتقالية، يوجد في الشقوق.';

  @override
  String get species_coral_crab_name => 'سرطان حراسة المرجان';

  @override
  String get species_coral_crab_desc =>
      'سرطان صغير منقّط يعيش في تكافل داخل مرجان Pocillopora ويدافع عن مضيفه.';

  @override
  String get species_crown_of_thorns_starfish_name => 'نجم البحر إكليل الشوك';

  @override
  String get species_crown_of_thorns_starfish_desc =>
      'نجم بحر سام متعدد الأذرع يتغذى على المرجان ويمكنه تدمير الشعاب عند تفشّيه.';

  @override
  String get species_blue_linckia_starfish_name => 'نجم البحر لينكيا الأزرق';

  @override
  String get species_blue_linckia_starfish_desc =>
      'نجم بحر أزرق زاهٍ يُشاهد عادةً على مسطحات ومنحدرات الشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_red_knob_starfish_name => 'نجم البحر أحمر النتوءات';

  @override
  String get species_red_knob_starfish_desc =>
      'نجم بحر رمادي كبير بأشواك بارزة حمراء الأطراف، يوجد في المناطق الرملية من الشعاب.';

  @override
  String get species_chocolate_chip_starfish_name =>
      'نجم البحر برقائق الشوكولاتة';

  @override
  String get species_chocolate_chip_starfish_desc =>
      'نجم بحر بلون بيج بعقيدات داكنة ناتئة تشبه رقائق الشوكولاتة على القيعان الرملية.';

  @override
  String get species_cushion_star_name => 'نجم البحر الوسادي';

  @override
  String get species_cushion_star_desc =>
      'نجم بحر منتفخ خماسي الشكل بأذرع قصيرة، يوجد على مسطحات الشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_fromia_starfish_name => 'نجم البحر الأنيق';

  @override
  String get species_fromia_starfish_desc =>
      'نجم بحر صغير أحمر برتقالي بحواف صفائح فاتحة تشكّل نمطًا يشبه البلاط.';

  @override
  String get species_basket_star_name => 'نجم السلة';

  @override
  String get species_basket_star_desc =>
      'أذرع شديدة التفرع تنفرد ليلًا للتغذي بالترشيح من التيار.';

  @override
  String get species_brittle_star_name => 'نجم البحر الهش المخطط';

  @override
  String get species_brittle_star_desc =>
      'نجم بحر هش مخطط يوجد تحت الصخور وفي الشقوق بأذرع رشيقة تشبه الأفاعي.';

  @override
  String get species_feather_star_name => 'نجم الريش';

  @override
  String get species_feather_star_desc =>
      'زنبق بحر متعدد الأذرع يرتكز على نتوءات الشعاب ويتغذى بالترشيح بأذرعه الريشية.';

  @override
  String get species_black_feather_star_name => 'نجم الريش الأسود';

  @override
  String get species_black_feather_star_desc =>
      'زنبق بحر داكن يمكنه السباحة لفترات قصيرة بتلويح أذرعه العديدة بإيقاع منتظم.';

  @override
  String get species_long_spined_sea_urchin_name => 'قنفذ البحر طويل الأشواك';

  @override
  String get species_long_spined_sea_urchin_desc =>
      'قنفذ بحر أسود بأشواك طويلة سامة، وهو راعٍ أساسي للطحالب في شعاب الكاريبي.';

  @override
  String get species_fire_urchin_name => 'قنفذ البحر الناري';

  @override
  String get species_fire_urchin_desc =>
      'قنفذ بحر طري الجسم بأشواك سامة تسبب لسعات مؤلمة عند ملامستها.';

  @override
  String get species_pencil_urchin_name => 'قنفذ البحر القلمي';

  @override
  String get species_pencil_urchin_desc =>
      'قنفذ بحر متين بأشواك غليظة غير مدببة، يوجد محشورًا في شقوق الشعاب.';

  @override
  String get species_collector_urchin_name => 'قنفذ البحر الجامع';

  @override
  String get species_collector_urchin_desc =>
      'قنفذ بحر يغطي نفسه بالحطام وشظايا الطحالب من أجل التمويه.';

  @override
  String get species_sea_apple_name => 'تفاحة البحر';

  @override
  String get species_sea_apple_desc =>
      'خيار بحر زاهي الألوان بمجسّات فموية يستخدمها للتغذي بالترشيح.';

  @override
  String get species_pineapple_sea_cucumber_name => 'خيار البحر الأناناسي';

  @override
  String get species_pineapple_sea_cucumber_desc =>
      'خيار بحر كبير أحمر برتقالي بحُليمات نجمية الشكل، يوجد على منحدرات الشعاب.';

  @override
  String get species_black_sea_cucumber_name => 'خيار البحر الأسود';

  @override
  String get species_black_sea_cucumber_desc =>
      'خيار بحر أسود شائع يوجد على مسطحات الشعاب الرملية في أنحاء المحيطين الهندي والهادئ.';

  @override
  String get species_leopard_sea_cucumber_name => 'خيار البحر الفهدي';

  @override
  String get species_leopard_sea_cucumber_desc =>
      'خيار بحر منقّط يقذف أنابيب كوفييه البيضاء اللزجة عند إزعاجه.';

  @override
  String get species_sand_dollar_name => 'دولار الرمل';

  @override
  String get species_sand_dollar_desc =>
      'قنفذ بحر مسطح قرصي الشكل يوجد مدفونًا جزئيًا في القيعان الرملية.';

  @override
  String get species_moon_jellyfish_name => 'قنديل البحر القمري';

  @override
  String get species_moon_jellyfish_desc =>
      'قنديل بحر شفاف جرسي الشكل بأربع غدد تناسلية على شكل حدوة حصان تُرى عبر جسمه.';

  @override
  String get species_lions_mane_jellyfish_name => 'قنديل بحر عرف الأسد';

  @override
  String get species_lions_mane_jellyfish_desc =>
      'أحد أكبر أنواع قناديل البحر بمجسّات طويلة متدلية، ويعيش في المياه الباردة.';

  @override
  String get species_box_jellyfish_name => 'قنديل البحر الصندوقي';

  @override
  String get species_box_jellyfish_desc =>
      'قنديل بحر شديد الخطورة بسم قوي، يوجد في المياه الاستوائية بالمحيطين الهندي والهادئ.';

  @override
  String get species_upside_down_jellyfish_name => 'قنديل البحر المقلوب';

  @override
  String get species_upside_down_jellyfish_desc =>
      'قنديل بحر غير مألوف يستقر وجرسه إلى الأسفل على القيعان الرملية ليتيح لطحالبه التمثيل الضوئي.';

  @override
  String get species_blue_blubber_jellyfish_name =>
      'قنديل البحر الأزرق الهلامي';

  @override
  String get species_blue_blubber_jellyfish_desc =>
      'قنديل بحر أزرق مائل للبياض بجرس متماسك وأذرع فموية مكشكشة، شائع في المياه الأسترالية.';

  @override
  String get species_fried_egg_jellyfish_name => 'قنديل البحر بيضة مقلية';

  @override
  String get species_fried_egg_jellyfish_desc =>
      'قنديل بحر متوسطي بقبة صفراء تشبه البيضة المقلية ولسعته خفيفة.';

  @override
  String get species_pacific_sea_nettle_name => 'قرّاص البحر الهادئي';

  @override
  String get species_pacific_sea_nettle_desc =>
      'قنديل بحر بني ذهبي بمجسّات طويلة متدلية، يوجد على طول ساحل المحيط الهادئ.';

  @override
  String get species_compass_jellyfish_name => 'قنديل البحر البوصلي';

  @override
  String get species_compass_jellyfish_desc =>
      'قنديل بحر بني وأبيض بعلامات على شكل حرف V تتشعع كوردة البوصلة.';

  @override
  String get species_spotted_jellyfish_name => 'قنديل البحر المنقّط';

  @override
  String get species_spotted_jellyfish_desc =>
      'قنديل بحر ذهبي ببقع بيضاء يشتهر بملء بحيرة قناديل البحر في بالاو.';

  @override
  String get species_barrel_jellyfish_name => 'قنديل البحر البرميلي';

  @override
  String get species_barrel_jellyfish_desc =>
      'قنديل بحر كبير قبّي الشكل بأذرع فموية مكشكشة ولسعة خفيفة، وهو شائع في المحيط الأطلسي.';

  @override
  String get species_persian_carpet_flatworm_name =>
      'الدودة المفلطحة السجادة الفارسية';

  @override
  String get species_persian_carpet_flatworm_desc =>
      'دودة مفلطحة سوداء مزخرفة بحواف صفراء برتقالية، وكثيرًا ما تُخلط مع الرخويات عارية الخياشيم.';

  @override
  String get species_leopard_flatworm_name => 'الدودة المفلطحة الفهدية';

  @override
  String get species_leopard_flatworm_desc =>
      'دودة مفلطحة شفافة ببقع تشبه بقع الفهد تنساب فوق أسطح الشعاب.';

  @override
  String get species_divided_flatworm_name => 'الدودة المفلطحة المقسّمة';

  @override
  String get species_divided_flatworm_desc =>
      'دودة مفلطحة لافتة بالأسود والبرتقالي تحاكي الرخويات السامة عارية الخياشيم لحماية نفسها.';

  @override
  String get species_blue_pseudoceros_flatworm_name =>
      'الدودة المفلطحة الزرقاء بسودوسيروس';

  @override
  String get species_blue_pseudoceros_flatworm_desc =>
      'دودة مفلطحة زرقاء داكنة بحافة برتقالية تنساب فوق أسطح الشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_racing_stripe_flatworm_name =>
      'الدودة المفلطحة ذات الخط السباقي';

  @override
  String get species_racing_stripe_flatworm_desc =>
      'دودة مفلطحة بلون كريمي بخط مركزي داكن واضح وحافة مكشكشة.';

  @override
  String get species_christmas_tree_worm_name => 'دودة شجرة الميلاد';

  @override
  String get species_christmas_tree_worm_desc =>
      'دودة ملوّنة بتاج حلزوني مغروسة في المرجان وتنكمش فورًا عند الاقتراب منها.';

  @override
  String get species_feather_duster_worm_name => 'الدودة الريشية';

  @override
  String get species_feather_duster_worm_desc =>
      'دودة تعيش في أنبوب ولها تاج مروحي من الأشعة الريشية تستخدمه للتغذي بالترشيح.';

  @override
  String get species_fire_worm_name => 'الدودة النارية الملتحية';

  @override
  String get species_fire_worm_desc =>
      'دودة ذات أشواك بيضاء لاسعة تسبب تهيّجًا مؤلمًا عند ملامستها.';

  @override
  String get species_bobbit_worm_name => 'دودة بوبيت';

  @override
  String get species_bobbit_worm_desc =>
      'مفترس كمين يختبئ في الرمال بفكين قويين ينقضّان بسرعة البرق.';

  @override
  String get species_social_feather_duster_name => 'الدودة الريشية الاجتماعية';

  @override
  String get species_social_feather_duster_desc =>
      'دودة أنبوبية مستعمرة تشكّل تجمعات من التيجان الرقيقة المخططة في شعاب الكاريبي.';

  @override
  String get species_giant_clam_name => 'المحار العملاق';

  @override
  String get species_giant_clam_desc =>
      'أكبر ذوات المصراعين الحية، وعباءتها متقزّحة الألوان وتحتضن طحالب متكافلة.';

  @override
  String get species_boring_clam_name => 'المحار الحافر';

  @override
  String get species_boring_clam_desc =>
      'محار صغير ملوّن يحفر داخل الصخر المرجاني ولا تظهر منه سوى عباءته الزاهية.';

  @override
  String get species_maxima_clam_name => 'المحار الأقصى';

  @override
  String get species_maxima_clam_desc =>
      'محار زاهي الألوان مغروس في صخر الشعاب بعباءات زرقاء وخضراء براقة.';

  @override
  String get species_flame_scallop_name => 'الأسقلوب اللهبي';

  @override
  String get species_flame_scallop_desc =>
      'من ذوات المصراعين الحمراء بوميض ضوئي أبيض على طول حافة عباءتها، توجد في شقوق الشعاب.';

  @override
  String get species_thorny_oyster_name => 'المحار الشوكي';

  @override
  String get species_thorny_oyster_desc =>
      'من ذوات المصراعين بصدفة شوكية ملتصقة بصخر الشعاب، وغالبًا ما يكسوها الإسفنج والطحالب.';

  @override
  String get species_magnificent_sea_anemone_name =>
      'شقائق النعمان البحرية البديعة';

  @override
  String get species_magnificent_sea_anemone_desc =>
      'شقائق نعمان كبيرة ملوّنة تستضيف أسماك المهرج، بعمود بارز ومجسّات منسابة.';

  @override
  String get species_bubble_tip_anemone_name => 'شقائق النعمان فقاعية الأطراف';

  @override
  String get species_bubble_tip_anemone_desc =>
      'مضيف شائع لأسماك المهرج بمجسّات منتفخة الأطراف بألوان خضراء أو بنية أو وردية.';

  @override
  String get species_giant_carpet_anemone_name =>
      'شقائق النعمان السجادية العملاقة';

  @override
  String get species_giant_carpet_anemone_desc =>
      'شقائق نعمان ضخمة بمجسّات قصيرة لزجة يمكن أن يتجاوز عرضها المتر الواحد.';

  @override
  String get species_haddon_carpet_anemone_name =>
      'شقائق النعمان السجادية الهادونية';

  @override
  String get species_haddon_carpet_anemone_desc =>
      'شقائق نعمان سجادية مسطحة على القيعان الرملية تستضيف أنواعًا مختلفة من أسماك المهرج والسرطانات الخزفية.';

  @override
  String get species_long_tentacle_anemone_name =>
      'شقائق النعمان طويلة المجسّات';

  @override
  String get species_long_tentacle_anemone_desc =>
      'شقائق نعمان تعيش في القيعان الرملية بمجسّات طويلة منسابة، وتستضيف أسماك المهرج غالبًا.';

  @override
  String get species_tube_anemone_name => 'شقائق النعمان الأنبوبية';

  @override
  String get species_tube_anemone_desc =>
      'شقائق نعمان أنيقة تسكن أنبوبًا رقّيًا في الرمال ولها حلقتان من المجسّات.';

  @override
  String get species_hell_fire_anemone_name => 'شقائق نعمان نار الجحيم';

  @override
  String get species_hell_fire_anemone_desc =>
      'شقائق نعمان شديدة اللسع بمجسّات متفرعة تشبه المرجان الطري.';

  @override
  String get species_beaded_sea_anemone_name => 'شقائق النعمان البحرية الخرزية';

  @override
  String get species_beaded_sea_anemone_desc =>
      'شقائق نعمان بأطراف مجسّات منتفخة تشبه الخرز، توجد في المناطق الرملية من شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_condylactis_anemone_name =>
      'شقائق النعمان الكاريبية العملاقة';

  @override
  String get species_condylactis_anemone_desc =>
      'شقائق نعمان كاريبية كبيرة بمجسّات أرجوانية الأطراف، توجد على قيعان الشعاب الصخرية.';

  @override
  String get species_sand_anemone_name => 'شقائق النعمان الرملية';

  @override
  String get species_sand_anemone_desc =>
      'شقائق نعمان رقيقة مدفونة جزئيًا في الرمال بمجسّات أرجوانية الأطراف.';

  @override
  String get species_barrel_sponge_name => 'الإسفنج البرميلي العملاق';

  @override
  String get species_barrel_sponge_desc =>
      'إسفنج ضخم برميلي الشكل يمكن أن يعيش قرونًا على جدران الشعاب في الكاريبي.';

  @override
  String get species_azure_vase_sponge_name => 'الإسفنج المزهري اللازوردي';

  @override
  String get species_azure_vase_sponge_desc =>
      'إسفنج مزهري الشكل بلون أزرق أرجواني زاهٍ يوجد على جدران الشعاب في الكاريبي.';

  @override
  String get species_yellow_tube_sponge_name => 'الإسفنج الأنبوبي الأصفر';

  @override
  String get species_yellow_tube_sponge_desc =>
      'إسفنج أنبوبي أصفر زاهٍ ينمو في تجمعات على جدران الشعاب في الكاريبي.';

  @override
  String get species_elephant_ear_sponge_name => 'إسفنج أذن الفيل';

  @override
  String get species_elephant_ear_sponge_desc =>
      'إسفنج برتقالي كبير مروحي الشكل ينمو على الجدران وتحت النتوءات الصخرية في الكاريبي.';

  @override
  String get species_rope_sponge_name => 'الإسفنج الحبلي';

  @override
  String get species_rope_sponge_desc =>
      'إسفنج أحمر منتصب متفرع ينمو في تكوينات تشبه الحبال على شعاب الكاريبي.';

  @override
  String get species_portuguese_man_o_war_name => 'السفينة الحربية البرتغالية';

  @override
  String get species_portuguese_man_o_war_desc =>
      'مستعمرة هيدروزوية بعوّامة مملوءة بالغاز ومجسّات متدلية شديدة الإيلام.';

  @override
  String get species_fire_coral_name => 'المرجان الناري';

  @override
  String get species_fire_coral_desc =>
      'ليس مرجانًا حقيقيًا بل كائن هيدروزوي يسبب لسعات مؤلمة للغواصين عند ملامسته.';

  @override
  String get species_by_the_wind_sailor_name => 'بحّار الريح';

  @override
  String get species_by_the_wind_sailor_desc =>
      'مستعمرة هيدروزوية زرقاء طافية بشراع مائل يلتقط الرياح.';

  @override
  String get species_blue_button_name => 'الزر الأزرق';

  @override
  String get species_blue_button_desc =>
      'مستعمرة هيدروزوية طافية بقرص مسطح وهيدرات زرقاء تشبه المجسّات.';

  @override
  String get species_giant_sea_hare_name => 'أرنب البحر العملاق';

  @override
  String get species_giant_sea_hare_desc =>
      'أحد أكبر بزاقات البحر، لونه بني داكن إلى أسود، ويوجد في مروج عشب البحر.';

  @override
  String get species_sea_hare_name => 'أرنب البحر المرقّط';

  @override
  String get species_sea_hare_desc =>
      'أرنب بحر كبير ببقع خضراء يطلق حبرًا أرجوانيًا عند إزعاجه.';

  @override
  String get species_nudibranch_berghia_name => 'رخوية البيرغيا عارية الخياشيم';

  @override
  String get species_nudibranch_berghia_desc =>
      'رخوية عارية الخياشيم شفافة بزوائد ظهرية بيضاء الأطراف تتغذى على شقائق النعمان البحرية.';

  @override
  String get species_sea_pen_name => 'قلم البحر';

  @override
  String get species_sea_pen_desc =>
      'مرجان ثماني مستعمر ريشي الشكل مثبّت في الرمال وينكمش عند إزعاجه.';

  @override
  String get species_blue_sea_star_name => 'نجم البحر الأزرق';

  @override
  String get species_blue_sea_star_desc =>
      'نجم بحر متعدد الألوان يتجدد من شظية ذراع واحدة في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_reef_squid_name => 'حبّار الشعاب';

  @override
  String get species_reef_squid_desc =>
      'حبّار الشعاب الجنوبي الذي يُصادَف عادةً في المياه الأسترالية المعتدلة.';

  @override
  String get species_tiger_shrimp_name => 'روبيان النمر';

  @override
  String get species_tiger_shrimp_desc =>
      'روبيان كبير مخطط يوجد على القيعان الرملية ومروج الأعشاب البحرية في المحيطين الهندي والهادئ.';

  @override
  String get species_candy_crab_name => 'سرطان الحلوى';

  @override
  String get species_candy_crab_desc =>
      'سرطان ضئيل ملوّن يطابق المرجان الطري الذي يسكنه بنتوءات شوكية وردية أو صفراء.';

  @override
  String get species_spider_crab_name => 'السرطان العنكبوتي المزخرِف';

  @override
  String get species_spider_crab_desc =>
      'سرطان بطيء الحركة مغطى بالإسفنج والطحالب التي يثبّتها على جسمه للتمويه.';

  @override
  String get species_anemone_shrimp_name => 'روبيان الشقائق البديعة';

  @override
  String get species_anemone_shrimp_desc =>
      'روبيان شفاف بعلامات بيضاء وأرجوانية يعيش بين مجسّات شقائق النعمان البحرية.';

  @override
  String get species_snapping_shrimp_name => 'الروبيان الطقّاق';

  @override
  String get species_snapping_shrimp_desc =>
      'روبيان صغير يُصدر طقّة عالية بكلّابته الضخمة، وكثيرًا ما يقترن بأسماك القوبيون.';

  @override
  String get species_glass_sponge_name => 'سلة زهرة فينوس';

  @override
  String get species_glass_sponge_desc =>
      'إسفنج زجاجي رقيق بهيكل سيليكوني معقد يوجد في المياه العميقة.';

  @override
  String get species_toxic_sea_urchin_name => 'قنفذ البحر الزهري';

  @override
  String get species_toxic_sea_urchin_desc =>
      'قنفذ بحر خادع الجمال مغطى بزوائد كمّاشية تشبه الأزهار وتحمل سمًّا قويًا.';

  @override
  String get species_slate_pencil_urchin_name => 'قنفذ البحر قلم الأردواز';

  @override
  String get species_slate_pencil_urchin_desc =>
      'قنفذ بحر بأشواك غليظة مستديرة يوجد على قيعان الشعاب في الكاريبي والأطلسي.';

  @override
  String get species_spiny_sea_star_name => 'نجم البحر الشوكي';

  @override
  String get species_spiny_sea_star_desc =>
      'نجم بحر كبير من المياه المعتدلة بأشواك بارزة، يوجد في المياه الأوروبية والأطلسية.';

  @override
  String get species_bat_star_name => 'نجم البحر الخفاشي';

  @override
  String get species_bat_star_desc =>
      'نجم بحر هادئي بأذرع موصولة بغشاء بلون برتقالي أو أحمر أو أرجواني، يوجد في غابات عشب البحر.';

  @override
  String get species_sunflower_star_name => 'نجم عبّاد الشمس';

  @override
  String get species_sunflower_star_desc =>
      'نجم بحر ضخم سريع الحركة له حتى 24 ذراعًا، يوجد في غابات عشب البحر بالمحيط الهادئ.';

  @override
  String get species_blood_star_name => 'نجم الدم';

  @override
  String get species_blood_star_desc =>
      'نجم بحر أحمر برتقالي زاهٍ بأذرع نحيلة، يوجد في المياه المعتدلة بالمحيط الهادئ.';

  @override
  String get species_common_cuttlefish_name => 'السبيدج الشائع';

  @override
  String get species_common_cuttlefish_desc =>
      'سيد التمويه الذي يوجد في المياه الأوروبية والمتوسطية، وحدقتاه على شكل حرف W.';

  @override
  String get species_blue_spotted_crab_name => 'السرطان السابح أزرق البقع';

  @override
  String get species_blue_spotted_crab_desc =>
      'سرطان سابح نشط ببقع زرقاء على درعه، يوجد على القيعان الرملية في المحيطين الهندي والهادئ.';

  @override
  String get species_sponge_crab_name => 'سرطان الإسفنج';

  @override
  String get species_sponge_crab_desc =>
      'سرطان ينحت إسفنجة حية ويحملها على ظهره للتمويه.';

  @override
  String get species_horseshoe_crab_name => 'سرطان حدوة الحصان';

  @override
  String get species_horseshoe_crab_desc =>
      'مفصلي أرجل قديم من كلابيات القرون بصدفة تشبه الخوذة، يوجد على القيعان الرملية في الأطلسي.';

  @override
  String get species_sea_spider_name => 'عنكبوت البحر';

  @override
  String get species_sea_spider_desc =>
      'مفصلي أرجل بحري رقيق طويل الأرجل يُشاهد وهو يزحف على الهيدرات والبريوزوا.';

  @override
  String get species_sea_lily_name => 'زنبق البحر';

  @override
  String get species_sea_lily_desc =>
      'أحفورة حية من زنابق البحر المعنّقة توجد في المياه العميقة وتتغذى بالترشيح بأذرعها الريشية.';

  @override
  String get species_mantis_shrimp_lysiosquilla_name => 'روبيان السرعوف الرامح';

  @override
  String get species_mantis_shrimp_lysiosquilla_desc =>
      'روبيان سرعوف كبير حافر للجحور بزوائد رمحية، يوجد على القيعان الرملية.';

  @override
  String get species_purple_sea_urchin_name => 'قنفذ البحر الأرجواني';

  @override
  String get species_purple_sea_urchin_desc =>
      'قنفذ بحر أرجواني وفير العدد يوجد في غابات عشب البحر وبرك المد الصخرية بالمحيط الهادئ.';

  @override
  String get species_crown_jellyfish_name => 'قنديل البحر المتوّج';

  @override
  String get species_crown_jellyfish_desc =>
      'قنديل بحر أرجواني داكن بجرس مرتفع يشبه التاج، يوجد في المحيطين الهندي والهادئ.';

  @override
  String get species_comb_jelly_name => 'عنبة البحر';

  @override
  String get species_comb_jelly_desc =>
      'كائن مشطي صغير مضيء حيويًا بصفوف مشطية متقزّحة الألوان ومجسّين طويلين.';

  @override
  String get species_warty_sea_slug_name => 'بزاقة البحر الثؤلولية';

  @override
  String get species_warty_sea_slug_desc =>
      'رخوية عارية الخياشيم زرقاء وسوداء بحديبات صفراء القمم، تُشاهد عادةً في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_doris_nudibranch_name => 'ليمونة البحر';

  @override
  String get species_doris_nudibranch_desc =>
      'رخوية دوريدية عارية الخياشيم صفراء منقّطة توجد في مياه المحيط الهادئ المعتدلة وتتغذى على الإسفنج.';

  @override
  String get species_opalescent_nudibranch_name =>
      'الرخوية العقيقية عارية الخياشيم';

  @override
  String get species_opalescent_nudibranch_desc =>
      'رخوية شفافة بزوائد ظهرية برتقالية زاهية وخطوط ظهرية زرقاء في مياه المحيط الهادئ.';

  @override
  String get species_clown_nudibranch_name => 'الرخوية المهرجة عارية الخياشيم';

  @override
  String get species_clown_nudibranch_desc =>
      'رخوية عارية الخياشيم وردية برتقالية ببقع زرقاء وبيضاء، توجد في المياه الأسترالية المعتدلة.';

  @override
  String get species_bottlenose_dolphin_name => 'الدلفين قاروري الأنف';

  @override
  String get species_bottlenose_dolphin_desc =>
      'دلفين فضولي ومرح يصادفه الغواصون كثيرًا في المياه الاستوائية والمعتدلة.';

  @override
  String get species_spinner_dolphin_name => 'الدلفين الدوّار';

  @override
  String get species_spinner_dolphin_desc =>
      'دلفين بهلواني يشتهر بدورانه في الهواء، ويُشاهد غالبًا في مجموعات كبيرة قرب الشعاب المرجانية.';

  @override
  String get species_common_dolphin_name => 'الدلفين الشائع';

  @override
  String get species_common_dolphin_desc =>
      'دلفين سريع السباحة بنمط مميز يشبه الساعة الرملية، يوجد في المحيط المفتوح والمياه الساحلية.';

  @override
  String get species_spotted_dolphin_name => 'الدلفين المرقّط الأطلسي';

  @override
  String get species_spotted_dolphin_desc =>
      'دلفين مرقّط ودود كثيرًا ما يقترب من الغواصين في جزر البهاما والكاريبي.';

  @override
  String get species_rissos_dolphin_name => 'دلفين ريسو';

  @override
  String get species_rissos_dolphin_desc =>
      'دلفين كبير بجسم رمادي تغطيه الندوب بكثافة، يوجد في المياه العميقة البعيدة عن الساحل حول العالم.';

  @override
  String get species_humpback_whale_name => 'الحوت الأحدب';

  @override
  String get species_humpback_whale_desc =>
      'حوت مهيب يشتهر بقفزاته من الماء وأغانيه المعقدة، ويُشاهد خلال هجراته الموسمية.';

  @override
  String get species_grey_whale_name => 'الحوت الرمادي';

  @override
  String get species_grey_whale_desc =>
      'حوت بالييني يتغذى من القاع ويهاجر على طول ساحل المحيط الهادئ، وغالبًا ما تكسوه البرنقيلات.';

  @override
  String get species_blue_whale_name => 'الحوت الأزرق';

  @override
  String get species_blue_whale_desc =>
      'أضخم حيوان عاش على الإطلاق، ويصادفه الغواصون أحيانًا في المياه الزرقاء العميقة.';

  @override
  String get species_sperm_whale_name => 'حوت العنبر';

  @override
  String get species_sperm_whale_desc =>
      'حوت غوّاص إلى الأعماق برأس ضخم، ويُشاهد أحيانًا مستريحًا عند السطح بين غوصاته.';

  @override
  String get species_orca_name => 'الأوركا';

  @override
  String get species_orca_desc =>
      'مفترس قمة بعلامات سوداء وبيضاء مميزة، يوجد في جميع أحواض المحيطات.';

  @override
  String get species_minke_whale_name => 'حوت المنك';

  @override
  String get species_minke_whale_desc =>
      'حوت بالييني أصغر حجمًا يبدي فضولًا تجاه الغواصين، خصوصًا في الحاجز المرجاني العظيم.';

  @override
  String get species_beluga_whale_name => 'حوت البيلوغا';

  @override
  String get species_beluga_whale_desc =>
      'حوت قطبي أبيض يشتهر بأصواته وسلوكه الاجتماعي في المياه الباردة.';

  @override
  String get species_pilot_whale_name => 'الحوت القائد قصير الزعانف';

  @override
  String get species_pilot_whale_desc =>
      'حوت اجتماعي غوّاص إلى الأعماق يُشاهد غالبًا في مجموعات كبيرة في البحار الاستوائية والدافئة المعتدلة.';

  @override
  String get species_false_killer_whale_name => 'الحوت القاتل الكاذب';

  @override
  String get species_false_killer_whale_desc =>
      'دلفين محيطي كبير يقترب أحيانًا من الغواصين في المياه المفتوحة.';

  @override
  String get species_dugong_name => 'الأطوم';

  @override
  String get species_dugong_desc =>
      'عاشب وديع يرعى في مروج الأعشاب البحرية بالمحيطين الهندي والهادئ، وهو قريب الصلة بخراف البحر.';

  @override
  String get species_west_indian_manatee_name => 'خروف بحر الهند الغربية';

  @override
  String get species_west_indian_manatee_desc =>
      'عاشب بطيء الحركة يوجد في المياه الضحلة الدافئة ومصبات الأنهار والينابيع في الكاريبي.';

  @override
  String get species_sea_otter_name => 'قضاعة البحر';

  @override
  String get species_sea_otter_desc =>
      'ثديي بحري محبب يوجد في غابات عشب البحر على طول ساحل شمال المحيط الهادئ.';

  @override
  String get species_california_sea_lion_name => 'أسد بحر كاليفورنيا';

  @override
  String get species_california_sea_lion_desc =>
      'من زعنفيات الأقدام المرحة والرشيقة التي كثيرًا ما تتفاعل مع الغواصين على طول ساحل المحيط الهادئ.';

  @override
  String get species_steller_sea_lion_name => 'أسد بحر ستيلر';

  @override
  String get species_steller_sea_lion_desc =>
      'أكبر أنواع أسود البحر، يوجد في المياه الباردة بشمال المحيط الهادئ قرب السواحل الصخرية.';

  @override
  String get species_harbor_seal_name => 'فقمة الموانئ';

  @override
  String get species_harbor_seal_desc =>
      'فقمة فضولية تُشاهد عادةً في المياه الساحلية المعتدلة، وغالبًا ما تستريح على الصخور قرب مواقع الغوص.';

  @override
  String get species_grey_seal_name => 'الفقمة الرمادية';

  @override
  String get species_grey_seal_desc =>
      'فقمة كبيرة مرحة توجد في شمال الأطلسي، وتشتهر باقترابها من الغواصين تحت الماء.';

  @override
  String get species_northern_elephant_seal_name => 'فقمة الفيل الشمالية';

  @override
  String get species_northern_elephant_seal_desc =>
      'فقمة ضخمة تغوص إلى أعماق كبيرة، وللذكور خرطوم كبير. توجد على طول ساحل شرق المحيط الهادئ.';

  @override
  String get species_hawaiian_monk_seal_name => 'فقمة الراهب الهاوايية';

  @override
  String get species_hawaiian_monk_seal_desc =>
      'فقمة مهددة بالانقراض بشدة ومتوطنة في هاواي، ويراها الغواصون أحيانًا على الشعاب.';

  @override
  String get species_leopard_seal_name => 'الفقمة النمرية';

  @override
  String get species_leopard_seal_desc =>
      'مفترس قوي في القطب الجنوبي بفروة منقّطة، يصادفه غواصو المياه الباردة.';

  @override
  String get species_narwhal_name => 'النارويل';

  @override
  String get species_narwhal_desc =>
      'حوت قطبي بناب حلزوني طويل، نادر المشاهدة لكنه أيقوني بين الثدييات البحرية.';

  @override
  String get species_green_sea_turtle_name => 'السلحفاة البحرية الخضراء';

  @override
  String get species_green_sea_turtle_desc =>
      'سلحفاة بحرية كبيرة تُشاهد عادةً وهي ترعى الأعشاب البحرية في المياه الاستوائية.';

  @override
  String get species_hawksbill_sea_turtle_name =>
      'السلحفاة البحرية صقرية المنقار';

  @override
  String get species_hawksbill_sea_turtle_desc =>
      'سلحفاة تسكن الشعاب بمنقار مدبب، وتتغذى على الإسفنج بين التكوينات المرجانية.';

  @override
  String get species_loggerhead_sea_turtle_name =>
      'السلحفاة البحرية ضخمة الرأس';

  @override
  String get species_loggerhead_sea_turtle_desc =>
      'سلحفاة كبيرة الرأس توجد في البحار المعتدلة والاستوائية، وغالبًا قرب الشعاب الصخرية.';

  @override
  String get species_leatherback_sea_turtle_name =>
      'السلحفاة البحرية جلدية الظهر';

  @override
  String get species_leatherback_sea_turtle_desc =>
      'أكبر سلحفاة حية بصدفة جلدية مرنة، وتغوص إلى أعماق سحيقة.';

  @override
  String get species_olive_ridley_sea_turtle_name => 'سلحفاة ريدلي الزيتونية';

  @override
  String get species_olive_ridley_sea_turtle_desc =>
      'أصغر أنواع السلاحف البحرية، وتشتهر بمواسم التعشيش الجماعي المتزامن المعروفة باسم arribadas.';

  @override
  String get species_kemps_ridley_sea_turtle_name => 'سلحفاة كيمب ريدلي';

  @override
  String get species_kemps_ridley_sea_turtle_desc =>
      'سلحفاة بحرية مهددة بالانقراض بشدة توجد أساسًا في خليج المكسيك.';

  @override
  String get species_flatback_sea_turtle_name => 'السلحفاة البحرية مسطحة الظهر';

  @override
  String get species_flatback_sea_turtle_desc =>
      'متوطنة في المياه الأسترالية، وتتميز بدرعها المسطح وموطنها الساحلي.';

  @override
  String get species_brain_coral_name => 'المرجان الدماغي';

  @override
  String get species_brain_coral_desc =>
      'مرجان ضخم بانٍ للشعاب بسطح محزّز يشبه الدماغ، وهو شائع في شعاب الكاريبي.';

  @override
  String get species_staghorn_coral_name => 'مرجان قرن الأيل';

  @override
  String get species_staghorn_coral_desc =>
      'مرجان متفرع سريع النمو يشكّل أدغالًا كثيفة تمثّل موئلًا حيويًا لأسماك الشعاب.';

  @override
  String get species_elkhorn_coral_name => 'مرجان قرن الموظ';

  @override
  String get species_elkhorn_coral_desc =>
      'مرجان متفرع كبير بأفرع مسطحة كفّية الشكل، وهو بانٍ رئيسي للشعاب في الكاريبي.';

  @override
  String get species_table_coral_name => 'المرجان الطاولي';

  @override
  String get species_table_coral_desc =>
      'مرجان يشكّل صفائح مسطحة في شعاب المحيطين الهندي والهادئ، ويوفر مأوى لأنواع كثيرة من الأسماك.';

  @override
  String get species_mushroom_coral_name => 'المرجان الفطري';

  @override
  String get species_mushroom_coral_desc =>
      'مرجان منفرد حر المعيشة على شكل قرص، يوجد في المناطق الرملية قرب شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_bubble_coral_name => 'المرجان الفقاعي';

  @override
  String get species_bubble_coral_desc =>
      'مرجان مميز بحويصلات تشبه حبات العنب تنتفخ نهارًا لالتقاط الضوء.';

  @override
  String get species_plate_coral_name => 'المرجان الصفائحي';

  @override
  String get species_plate_coral_desc =>
      'مرجان صفائحي رقيق يشكّل رفوفًا حلزونية، وهو شائع على منحدرات الشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_pillar_coral_name => 'المرجان العمودي';

  @override
  String get species_pillar_coral_desc =>
      'مرجان نادر ينمو إلى الأعلى مشكّلًا أعمدة مرتفعة، ويوجد في الكاريبي.';

  @override
  String get species_star_coral_name => 'المرجان النجمي';

  @override
  String get species_star_coral_desc =>
      'بانٍ رئيسي لشعاب الكاريبي يشكّل مستعمرات كبيرة تشبه الصخور بسلائل نجمية الشكل.';

  @override
  String get species_lettuce_coral_name => 'المرجان الخسّي';

  @override
  String get species_lettuce_coral_desc =>
      'مرجان صفائحي رقيق بطيّات تشبه الأوراق، وهو شائع على جدران ومنحدرات شعاب الكاريبي.';

  @override
  String get species_finger_coral_name => 'المرجان الإصبعي';

  @override
  String get species_finger_coral_desc =>
      'مرجان متفرع متين بنتوءات غليظة تشبه الأصابع، يوجد في الشعاب الضحلة.';

  @override
  String get species_massive_porites_name => 'مرجان Porites الضخم';

  @override
  String get species_massive_porites_desc =>
      'مرجان صخري كبير يمكن أن ينمو لقرون، وهو بانٍ مهيمن للشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_cauliflower_coral_name => 'مرجان القرنبيط';

  @override
  String get species_cauliflower_coral_desc =>
      'مرجان متفرع متراص على شكل القرنبيط، منتشر في ضحال الشعاب الاستوائية.';

  @override
  String get species_flower_pot_coral_name => 'مرجان أصيص الزهور';

  @override
  String get species_flower_pot_coral_desc =>
      'مستعمرة من السلائل طويلة المجسّات تمتد نهارًا فتبدو كباقة من الزهور.';

  @override
  String get species_cup_coral_name => 'المرجان الكأسي البرتقالي';

  @override
  String get species_cup_coral_desc =>
      'مرجان برتقالي زاهٍ غير قائم على التمثيل الضوئي، يوجد على الجدران وتحت النتوءات في المياه الاستوائية.';

  @override
  String get species_scroll_coral_name => 'المرجان اللفائفي';

  @override
  String get species_scroll_coral_desc =>
      'مرجان يشكّل صفائح ملتفة كبيرة، وهو شائع على منحدرات الشعاب والبحيرات في المحيطين الهندي والهادئ.';

  @override
  String get species_cabbage_coral_name => 'المرجان الملفوفي';

  @override
  String get species_cabbage_coral_desc =>
      'مرجان صفائحي قرصي الشكل يشبه أوراق الملفوف، يوجد في مناطق الشعاب المحمية.';

  @override
  String get species_hammer_coral_name => 'المرجان المطرقي';

  @override
  String get species_hammer_coral_desc =>
      'مرجان كبير السلائل بأطراف مجسّات تشبه المرساة أو المطرقة، وهو مألوف في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_torch_coral_name => 'المرجان المشعلي';

  @override
  String get species_torch_coral_desc =>
      'مرجان متفرع بمجسّات طويلة منسابة تنتهي بأطراف منتفخة متوهجة.';

  @override
  String get species_frogspawn_coral_name => 'مرجان بيض الضفادع';

  @override
  String get species_frogspawn_coral_desc =>
      'مرجان كبير السلائل بأطراف مجسّات متفرعة تشبه بيض الضفادع.';

  @override
  String get species_sea_fan_name => 'المروحة البحرية الشائعة';

  @override
  String get species_sea_fan_desc =>
      'مرجان مروحي مسطح يتخذ وضعًا عموديًا على اتجاه التيار، وهو أيقوني في شعاب الكاريبي.';

  @override
  String get species_venus_sea_fan_name => 'مروحة فينوس البحرية';

  @override
  String get species_venus_sea_fan_desc =>
      'مرجان مروحي رقيق يوجد في شعاب الكاريبي الضحلة ضمن مناطق التيار المعتدل.';

  @override
  String get species_deepwater_sea_fan_name => 'المروحة البحرية عميقة المياه';

  @override
  String get species_deepwater_sea_fan_desc =>
      'مرجان مروحي كبير كثيف التفرع يوجد على جدران الشعاب العميقة في الكاريبي.';

  @override
  String get species_sea_whip_name => 'سوط البحر';

  @override
  String get species_sea_whip_desc =>
      'مرجان مروحي نحيل قضيبي الشكل يُشاهد وهو يتمايل مع التيارات في شعاب الأطلسي والكاريبي.';

  @override
  String get species_sea_plume_name => 'ريشة البحر';

  @override
  String get species_sea_plume_desc =>
      'مرجان مروحي مرتفع ريشي المظهر يشكّل مستعمرات تشبه الريش على قمم شعاب الكاريبي.';

  @override
  String get species_organ_pipe_coral_name => 'مرجان أنابيب الأرغن';

  @override
  String get species_organ_pipe_coral_desc =>
      'أنابيب هيكلية حمراء زاهية بسلائل رقيقة، توجد في الشعاب المحمية بالمحيطين الهندي والهادئ.';

  @override
  String get species_leather_coral_name => 'المرجان الجلدي';

  @override
  String get species_leather_coral_desc =>
      'مرجان طري بسطح أملس يشبه الجلد يشكّل مستعمرات كبيرة على هيئة الفطر.';

  @override
  String get species_toadstool_leather_coral_name => 'المرجان الجلدي الفطري';

  @override
  String get species_toadstool_leather_coral_desc =>
      'مرجان طري بساق غليظة وقبعة مسطحة، وهو شائع على مسطحات الشعاب في المحيطين الهندي والهادئ.';

  @override
  String get species_pulsing_xenia_name => 'الزينيا النابضة';

  @override
  String get species_pulsing_xenia_desc =>
      'مرجان طري بسلائل تنبض بإيقاع منتظم، يوجد في المياه المحمية بالمحيطين الهندي والهادئ.';

  @override
  String get species_tree_coral_name => 'المرجان الشجري';

  @override
  String get species_tree_coral_desc =>
      'مرجان طري زاهي الألوان يشكّل تجمعات شجرية الشكل على الجدران وتحت النتوءات في البحر الأحمر.';

  @override
  String get species_blue_coral_name => 'المرجان الأزرق';

  @override
  String get species_blue_coral_desc =>
      'مرجان ثماني فريد بهيكل أزرق، يوجد على مسطحات الشعاب الضحلة في المحيطين الهندي والهادئ.';

  @override
  String get species_black_coral_name => 'المرجان الأسود';

  @override
  String get species_black_coral_desc =>
      'مرجان أعماق بهيكل داكن، يوجد على الجدران والمنحدرات دون عمق 30 مترًا.';

  @override
  String get species_carnation_coral_name => 'مرجان القرنفل';

  @override
  String get species_carnation_coral_desc =>
      'مرجان طري زاهي الألوان يوجد تحت الحواف الصخرية وعلى الجدران في المحيطين الهندي والهادئ.';

  @override
  String get species_wire_coral_name => 'المرجان السلكي';

  @override
  String get species_wire_coral_desc =>
      'مرجان أسود طويل حلزوني يشكّل سياطًا ملتفة، ويستضيف أسماك القوبيون والروبيان.';

  @override
  String get species_dead_mans_fingers_name => 'أصابع الرجل الميت';

  @override
  String get species_dead_mans_fingers_desc =>
      'مرجان طري لحمي بفصوص تشبه الأصابع، شائع في شعاب شمال الأطلسي المعتدلة.';

  @override
  String get species_sun_coral_name => 'المرجان الشمسي';

  @override
  String get species_sun_coral_desc =>
      'مرجان أصفر برتقالي غير قائم على التمثيل الضوئي يفتح سلائله ليلًا على جدران المحيطين الهندي والهادئ.';

  @override
  String get species_lace_coral_name => 'المرجان الدانتيلي';

  @override
  String get species_lace_coral_desc =>
      'مرجان هيدروزوي وردي رقيق بأفرع تشبه الدانتيل، يوجد في الشقوق وتحت الحواف الصخرية.';

  @override
  String get species_kenya_tree_coral_name => 'مرجان كينيا الشجري';

  @override
  String get species_kenya_tree_coral_desc =>
      'مرجان طري قوي التحمل بأفرع شجرية الشكل، وهو شائع في المحيطين الهندي والهادئ.';

  @override
  String get species_colt_coral_name => 'مرجان الكولت';

  @override
  String get species_colt_coral_desc =>
      'مرجان طري بأفرع غليظة مطاطية مغطاة بسلائل صغيرة في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_turtle_grass_name => 'عشب السلاحف';

  @override
  String get species_turtle_grass_desc =>
      'العشب البحري المهيمن في الكاريبي بأنصال عريضة مسطحة، وهو مصدر غذاء حيوي للسلاحف البحرية.';

  @override
  String get species_eelgrass_name => 'العشب الثعباني';

  @override
  String get species_eelgrass_desc =>
      'عشب بحري من المياه المعتدلة يشكّل مروجًا كثيفة تحت الماء تعمل موئلًا لتربية الصغار.';

  @override
  String get species_manatee_grass_name => 'عشب خروف البحر';

  @override
  String get species_manatee_grass_desc =>
      'عشب بحري بأنصال أسطوانية يوجد في المناطق الرملية بالكاريبي، وغالبًا قرب مروج عشب السلاحف.';

  @override
  String get species_shoal_grass_name => 'عشب الضحال';

  @override
  String get species_shoal_grass_desc =>
      'عشب بحري رائد بأنصال ضيقة يستوطن المناطق الرملية المضطربة في الكاريبي.';

  @override
  String get species_paddle_grass_name => 'العشب المجدافي';

  @override
  String get species_paddle_grass_desc =>
      'عشب بحري صغير رقيق بأوراق بيضوية، يوجد في المياه الأعمق عبر المناطق الاستوائية.';

  @override
  String get species_neptune_grass_name => 'عشب نبتون';

  @override
  String get species_neptune_grass_desc =>
      'عشب بحري متوسطي يشكّل مروجًا شاسعة بالغة الأهمية للنظم البيئية البحرية الساحلية.';

  @override
  String get species_giant_kelp_name => 'عشب البحر العملاق';

  @override
  String get species_giant_kelp_desc =>
      'نوع يشكّل غابات شاهقة تحت الماء ينمو حتى 60 مترًا، وهو أيقوني في غوصات كاليفورنيا.';

  @override
  String get species_bull_kelp_name => 'عشب البحر الثوري';

  @override
  String get species_bull_kelp_desc =>
      'عشب بحر هادئي بساق واحدة طويلة وعوّامة منتفخة، يشكّل غابات كثيفة المظلة.';

  @override
  String get species_bladder_wrack_name => 'الطحلب المثاني';

  @override
  String get species_bladder_wrack_desc =>
      'طحلب بني شائع بمثانات هوائية مزدوجة، يوجد في مناطق المد والجزر بشمال الأطلسي.';

  @override
  String get species_sargassum_name => 'السرغسوم';

  @override
  String get species_sargassum_desc =>
      'طحلب بني حر الطفو يشكّل أطوافًا تحتمي بها صغار الأسماك واللافقاريات.';

  @override
  String get species_kelp_forest_ecklonia_name => 'عشب البحر الإكلوني';

  @override
  String get species_kelp_forest_ecklonia_desc =>
      'عشب البحر المهيمن في مياه نصف الكرة الجنوبي، ويشكّل غابات مهمة تحت الماء.';

  @override
  String get species_coralline_algae_name => 'الطحالب المرجانية';

  @override
  String get species_coralline_algae_desc =>
      'طحلب أحمر صلب يكسو الأسطح ويلحم بنى الشعاب ويمنحها لونًا ورديًا.';

  @override
  String get species_irish_moss_name => 'الطحلب الإيرلندي';

  @override
  String get species_irish_moss_desc =>
      'طحلب أحمر مروحي الشكل يوجد على الشواطئ الصخرية في منطقة المد والجزر بشمال الأطلسي.';

  @override
  String get species_dulse_name => 'الدلس';

  @override
  String get species_dulse_desc =>
      'طحلب مسطح أحمر أرجواني ينمو على الصخور وسيقان عشب البحر في المياه الشمالية الباردة.';

  @override
  String get species_halimeda_name => 'الهاليميدا';

  @override
  String get species_halimeda_desc =>
      'طحلب أخضر متكلّس بقطع قرصية الشكل، وهو مساهم رئيسي في تكوين رمال الشعاب.';

  @override
  String get species_sea_lettuce_name => 'خس البحر';

  @override
  String get species_sea_lettuce_desc =>
      'طحلب أخضر زاهٍ على هيئة صفائح يوجد في المياه الساحلية الضحلة حول العالم.';

  @override
  String get species_caulerpa_name => 'طحلب العنب الأخضر';

  @override
  String get species_caulerpa_desc =>
      'طحلب أخضر زاحف بسعوف تشبه حبات العنب، يوجد على الحطام المرجاني والرمال في الشعاب الاستوائية.';

  @override
  String get species_mermaid_fan_name => 'مروحة الحورية';

  @override
  String get species_mermaid_fan_desc =>
      'طحلب أخضر متكلّس على شكل مروحة صغيرة، وهو شائع على القيعان الرملية في الكاريبي.';

  @override
  String get species_shaving_brush_algae_name => 'طحلب فرشاة الحلاقة';

  @override
  String get species_shaving_brush_algae_desc =>
      'طحلب أخضر متكلّس بخصلة تشبه الفرشاة فوق ساق، يوجد على القيعان الرملية في الكاريبي.';

  @override
  String get species_finger_kelp_name => 'طحلب المجداف';

  @override
  String get species_finger_kelp_desc =>
      'طحلب بني بسعوف تشبه الأصابع يشكّل مروج عشب البحر في المياه الساحلية بشمال الأطلسي.';

  @override
  String get species_banded_sea_krait_name => 'ثعبان البحر المخطط';

  @override
  String get species_banded_sea_krait_desc =>
      'ثعبان بحر سام بأشرطة زرقاء رمادية وسوداء، وديع ويُشاهد عادةً في شعاب المحيطين الهندي والهادئ.';

  @override
  String get species_olive_sea_snake_name => 'ثعبان البحر الزيتوني';

  @override
  String get species_olive_sea_snake_desc =>
      'ثعبان بحر فضولي يوجد في الشعاب الأسترالية ويشتهر باقترابه من الغواصين.';

  @override
  String get species_yellow_bellied_sea_snake_name => 'ثعبان البحر أصفر البطن';

  @override
  String get species_yellow_bellied_sea_snake_desc =>
      'ثعبان بحر من أعالي البحار ببطن أصفر، وهو أوسع أنواع الثعابين انتشارًا على وجه الأرض.';

  @override
  String get species_marine_iguana_name => 'الإغوانا البحرية';

  @override
  String get species_marine_iguana_desc =>
      'متوطنة في جزر غالاباغوس، وهي السحلية الوحيدة التي ترعى الطحالب تحت الماء.';

  @override
  String get species_saltwater_crocodile_name => 'تمساح المياه المالحة';

  @override
  String get species_saltwater_crocodile_desc =>
      'أكبر الزواحف الحية، ويوجد في المياه الساحلية ومصبات الأنهار بالمحيطين الهندي والهادئ.';

  @override
  String get common_action_done => 'تم';

  @override
  String get common_action_more => 'المزيد';

  @override
  String get common_label_displayName => 'الاسم المعروض';

  @override
  String common_relativeTime_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count يوم',
      many: 'منذ $count يومًا',
      few: 'منذ $count أيام',
      two: 'منذ يومين',
      one: 'منذ يوم',
      zero: 'منذ $count يوم',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count ساعة',
      many: 'منذ $count ساعة',
      few: 'منذ $count ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
      zero: 'منذ $count ساعة',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'خلال $count يوم',
      many: 'خلال $count يومًا',
      few: 'خلال $count أيام',
      two: 'خلال يومين',
      one: 'خلال يوم',
      zero: 'خلال $count يوم',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'خلال $count ساعة',
      many: 'خلال $count ساعة',
      few: 'خلال $count ساعات',
      two: 'خلال ساعتين',
      one: 'خلال ساعة',
      zero: 'خلال $count ساعة',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_inLessThanMinute => 'خلال أقل من دقيقة';

  @override
  String common_relativeTime_inMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'خلال $count دقيقة',
      many: 'خلال $count دقيقة',
      few: 'خلال $count دقائق',
      two: 'خلال دقيقتين',
      one: 'خلال دقيقة',
      zero: 'خلال $count دقيقة',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_justNow => 'الآن';

  @override
  String common_relativeTime_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count دقيقة',
      many: 'منذ $count دقيقة',
      few: 'منذ $count دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
      zero: 'منذ $count دقيقة',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count شهر',
      many: 'منذ $count شهرًا',
      few: 'منذ $count أشهر',
      two: 'منذ شهرين',
      one: 'منذ شهر',
      zero: 'منذ $count شهر',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_overdue => 'متأخر';

  @override
  String get media_cache_calculating => 'جارٍ حساب حجم التخزين المؤقت…';

  @override
  String get media_cache_cardTitle => 'إدارة التخزين المؤقت';

  @override
  String get media_cache_clearAction => 'مسح التخزين المؤقت';

  @override
  String get media_cache_clearBody =>
      'يزيل الصور المصغرة وصور الشبكة بالحجم الكامل التي جرى تنزيلها. تبقى عناصر الوسائط المرتبطة كما هي، وسيعاد تنزيل الصور عند العرض التالي.';

  @override
  String get media_cache_clearConfirm => 'مسح';

  @override
  String media_cache_clearError(String error) {
    return 'فشل المسح: $error';
  }

  @override
  String get media_cache_clearTitle => 'مسح التخزين المؤقت لصور الشبكة؟';

  @override
  String get media_cache_cleared => 'تم مسح التخزين المؤقت';

  @override
  String get media_cache_diskCache => 'التخزين المؤقت على القرص';

  @override
  String media_cache_error(String error) {
    return 'خطأ: $error';
  }

  @override
  String get media_credentials_actionTest => 'اختبار بيانات الاعتماد';

  @override
  String media_credentials_authLabel(String authType) {
    return 'المصادقة: $authType';
  }

  @override
  String get media_credentials_deleteBody =>
      'يزيل بيانات الاعتماد المحفوظة. ستعرض العناصر المرتبطة عبر هذا المضيف عبارة \"يتطلب تسجيل الدخول\" إلى أن تعيد إضافتها.';

  @override
  String media_credentials_deleteError(String error) {
    return 'فشل الحذف: $error';
  }

  @override
  String media_credentials_deleteTitle(String host) {
    return 'حذف $host؟';
  }

  @override
  String media_credentials_deleted(String host) {
    return 'تم حذف $host';
  }

  @override
  String media_credentials_editTitle(String host) {
    return 'تعديل $host';
  }

  @override
  String get media_credentials_emptySubtitle =>
      'تظهر هنا بيانات الاعتماد الخاصة بكل مضيف التي تُضاف أثناء الاستيراد من عنوان URL أو من قائمة.';

  @override
  String get media_credentials_emptyTitle => 'لا توجد بيانات اعتماد محفوظة';

  @override
  String media_credentials_lastUsed(String when) {
    return 'آخر استخدام $when';
  }

  @override
  String get media_credentials_loadError => 'تعذر تحميل المضيفين المحفوظين';

  @override
  String get media_credentials_loading => 'جارٍ تحميل المضيفين المحفوظين...';

  @override
  String media_credentials_saveError(String error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String get media_credentials_savedHostsTitle => 'المضيفون المحفوظون';

  @override
  String media_credentials_testError(String error) {
    return 'فشل الاختبار: $error';
  }

  @override
  String media_credentials_testFailed(String host) {
    return 'فشلت بيانات الاعتماد الخاصة بـ $host';
  }

  @override
  String media_credentials_testOk(String host) {
    return 'بيانات الاعتماد صالحة لـ $host';
  }

  @override
  String get media_manifest_actionPollNow => 'استعلام الآن';

  @override
  String get media_manifest_cardTitle => 'اشتراكات القوائم';

  @override
  String get media_manifest_deleteBody =>
      'يزيل الاشتراك. ستبقى الإدخالات المستوردة بالفعل (يمكنك تنظيفها من قائمة العناصر اليتيمة).';

  @override
  String media_manifest_deleteError(String error) {
    return 'فشل الحذف: $error';
  }

  @override
  String media_manifest_deleteTitle(String name) {
    return 'حذف $name؟';
  }

  @override
  String get media_manifest_editTitle => 'تعديل الاشتراك';

  @override
  String get media_manifest_emptySubtitle =>
      'اشترك في قائمة Atom/RSS أو JSON أو CSV من علامة تبويب URL للحفاظ على تزامن مكتبتك.';

  @override
  String get media_manifest_emptyTitle => 'لا توجد اشتراكات قوائم';

  @override
  String media_manifest_lastError(String error) {
    return 'آخر خطأ: $error';
  }

  @override
  String media_manifest_lastPolled(String when) {
    return 'آخر استعلام $when';
  }

  @override
  String get media_manifest_loadError => 'تعذر تحميل الاشتراكات';

  @override
  String get media_manifest_loading => 'جارٍ تحميل الاشتراكات...';

  @override
  String get media_manifest_neverPolled => 'لم يتم الاستعلام مطلقًا';

  @override
  String media_manifest_nextPoll(String when) {
    return 'التالي $when';
  }

  @override
  String get media_manifest_notFound => 'الاشتراك غير موجود';

  @override
  String media_manifest_pollError(String error) {
    return 'فشل الاستعلام: $error';
  }

  @override
  String media_manifest_polled(String name) {
    return 'تم الاستعلام عن $name';
  }

  @override
  String media_manifest_polling(String name) {
    return 'جارٍ الاستعلام عن $name...';
  }

  @override
  String media_manifest_saveError(String error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String media_manifest_updateError(String error) {
    return 'تعذر التحديث: $error';
  }

  @override
  String get media_manifest_urlLabel => 'عنوان URL للقائمة';

  @override
  String media_scan_failed(String error) {
    return 'فشل الفحص: $error';
  }

  @override
  String media_scan_progressItems(int done, int total) {
    return '$done / $total عنصر';
  }

  @override
  String media_scan_progressReachability(int available, int unreachable) {
    return '$available متاح  ·  $unreachable غير متاح';
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
          'تم فحص $total عنصر في $seconds ثانية: $available متاح، $unreachable غير متاح',
      many:
          'تم فحص $total عنصرًا في $seconds ثانية: $available متاح، $unreachable غير متاح',
      few:
          'تم فحص $total عناصر في $seconds ثانية: $available متاح، $unreachable غير متاح',
      two:
          'تم فحص عنصرين في $seconds ثانية: $available متاح، $unreachable غير متاح',
      one:
          'تم فحص عنصر واحد في $seconds ثانية: $available متاح، $unreachable غير متاح',
      zero:
          'تم فحص $total عنصر في $seconds ثانية: $available متاح، $unreachable غير متاح',
    );
    return '$_temp0';
  }

  @override
  String media_scan_summarySkipped(String base, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تخطي $count عنصر (بدون عنوان URL)',
      many: 'تم تخطي $count عنصرًا (بدون عنوان URL)',
      few: 'تم تخطي $count عناصر (بدون عنوان URL)',
      two: 'تم تخطي عنصرين (بدون عنوان URL)',
      one: 'تم تخطي عنصر واحد (بدون عنوان URL)',
      zero: 'تم تخطي $count عنصر (بدون عنوان URL)',
    );
    return '$base، $_temp0';
  }

  @override
  String get media_scan_title => 'فحص جميع وسائط الشبكة';

  @override
  String get settings_mediaSources_androidUriTitle => 'أذونات URI في أندرويد';

  @override
  String settings_mediaSources_androidUriUsage(int used, int limit) {
    return '$used / $limit من معرفات URI الدائمة قيد الاستخدام';
  }

  @override
  String get settings_mediaSources_counting => 'جارٍ العد…';

  @override
  String settings_mediaSources_error(String error) {
    return 'خطأ: $error';
  }

  @override
  String get settings_mediaSources_loading => 'جارٍ التحميل…';

  @override
  String settings_mediaSources_localFilesCounts(
    int available,
    int unavailable,
  ) {
    return '$available متاح، $unavailable غير متاح';
  }

  @override
  String get settings_mediaSources_photoLibrarySubtitle =>
      'Apple Photos / Google Photos / iCloud';

  @override
  String get settings_mediaSources_reverifyAll =>
      'إعادة التحقق من جميع الملفات المحلية';

  @override
  String settings_mediaSources_reverifyFailed(String error) {
    return 'فشلت إعادة التحقق: $error';
  }

  @override
  String settings_mediaSources_reverifyResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديث $count عنصر',
      many: 'تم تحديث $count عنصرًا',
      few: 'تم تحديث $count عناصر',
      two: 'تم تحديث عنصرين',
      one: 'تم تحديث عنصر واحد',
      zero: 'تم تحديث $count عنصر',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_checkAll => 'فحص جميع الوسائط';

  @override
  String settings_mediaSources_checkAllResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديث $count عنصر',
      many: 'تم تحديث $count عنصرا',
      few: 'تم تحديث $count عناصر',
      two: 'تم تحديث عنصرين',
      one: 'تم تحديث عنصر واحد',
      zero: 'لم يتم تحديث أي عنصر',
    );
    return '$_temp0';
  }

  @override
  String settings_mediaSources_checkAllBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذر فحص أي من العناصر $count. مصادرها غير متاحة حاليا.',
      many: 'تعذر فحص أي من العناصر $count. مصادرها غير متاحة حاليا.',
      few: 'تعذر فحص أي من العناصر $count. مصادرها غير متاحة حاليا.',
      two: 'تعذر فحص العنصرين. مصادرهما غير متاحة حاليا.',
      one: 'تعذر فحص العنصر. مصدره غير متاح حاليا.',
      zero: 'تعذر فحص أي عنصر. مصادرها غير متاحة حاليا.',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_title => 'مصادر الوسائط';

  @override
  String get settings_networkSources_scanDescription =>
      'يعيد فحص كل صورة مستوردة عبر عنوان URL أو قائمة مقابل مضيفها. ويضع علامة على العناصر غير المتاحة لتظهر بحالة \"مفقودة\" في مكتبتك ويمكن تنظيفها.';

  @override
  String statistics_conditions_entryMethod_semanticLabel(String description) {
    return 'مخطط أعمدة. طرق الدخول. $description';
  }

  @override
  String statistics_conditions_visibility_semanticLabel(String description) {
    return 'مخطط دائري. توزيع الرؤية. $description';
  }

  @override
  String statistics_conditions_waterType_semanticLabel(String description) {
    return 'مخطط دائري. توزيع نوع الماء. $description';
  }

  @override
  String statistics_progression_divesBySuitThickness_semanticLabel(
    String description,
  ) {
    return 'مخطط أعمدة. الغوصات حسب سماكة البدلة. $description';
  }

  @override
  String statistics_progression_divesPerYear_countInYear(
    int count,
    String year,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غوصة في $year',
      many: '$count غوصة في $year',
      few: '$count غوصات في $year',
      two: 'غوصتان في $year',
      one: 'غوصة واحدة في $year',
      zero: '$count غوصة في $year',
    );
    return '$_temp0';
  }

  @override
  String statistics_progression_divesPerYear_semanticLabel(String description) {
    return 'مخطط أعمدة. الغوصات لكل سنة. $description';
  }

  @override
  String get statistics_records_unavailable => 'الأرقام القياسية غير متاحة';

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
  String get statistics_summary_distributions_title => 'التوزيعات';

  @override
  String get statistics_summary_diveTypes_error =>
      'تعذر تحميل بيانات أنواع الغوص';

  @override
  String get statistics_summary_diveTypes_unknown => 'غير معروف';

  @override
  String get statistics_summary_divesPerMonth => 'الغوصات / الشهر';

  @override
  String get statistics_summary_divesPerYear => 'الغوصات / السنة';

  @override
  String statistics_timePatterns_dayOfWeek_semanticLabel(String description) {
    return 'مخطط أعمدة. الغوصات حسب يوم الأسبوع. $description';
  }

  @override
  String statistics_timePatterns_seasonal_semanticLabel(String description) {
    return 'مخطط أعمدة. الغوصات حسب الشهر. $description';
  }

  @override
  String statistics_timePatterns_surfaceInterval_statLabel(
    String label,
    String value,
  ) {
    return 'فترة السطح $label: $value';
  }

  @override
  String get statistics_timePatterns_timeOfDay_afternoon => 'بعد الظهر';

  @override
  String get statistics_timePatterns_timeOfDay_evening => 'المساء';

  @override
  String get statistics_timePatterns_timeOfDay_morning => 'الصباح';

  @override
  String get statistics_timePatterns_timeOfDay_night => 'الليل';

  @override
  String statistics_timePatterns_timeOfDay_semanticLabel(String description) {
    return 'مخطط دائري. الغوصات حسب وقت اليوم. $description';
  }

  @override
  String get columnConfig_displayOptions => 'خيارات العرض';

  @override
  String get columnConfig_noExtraFields =>
      'لم يتم إعداد أي حقول إضافية. أضف حقولاً أدناه.';

  @override
  String get columnConfig_savePresetTitle => 'حفظ الإعداد المسبق';

  @override
  String get columnConfig_section => 'القسم';

  @override
  String get columnConfig_showTags => 'إظهار الوسوم';

  @override
  String get columnConfig_showTags_subtitle =>
      'عرض شارات الوسوم على بطاقات الغوص المفصّلة';

  @override
  String get columnConfig_slot_date => 'التاريخ / العنوان الفرعي';

  @override
  String get columnConfig_slot_slot1 => 'الخانة 1';

  @override
  String get columnConfig_slot_slot2 => 'الخانة 2';

  @override
  String get columnConfig_slot_slot3 => 'الخانة 3';

  @override
  String get columnConfig_slot_slot4 => 'الخانة 4';

  @override
  String get columnConfig_slot_stat1 => 'الإحصاء 1';

  @override
  String get columnConfig_slot_stat2 => 'الإحصاء 2';

  @override
  String get columnConfig_slot_subtitle => 'العنوان الفرعي';

  @override
  String get columnConfig_slot_title => 'العنوان';

  @override
  String get columnConfig_tooltip_columnSettings => 'إعدادات الأعمدة';

  @override
  String get common_action_add => 'إضافة';

  @override
  String get common_action_pin => 'تثبيت';

  @override
  String get common_action_remove => 'إزالة';

  @override
  String get common_action_unpin => 'إلغاء التثبيت';

  @override
  String diveLog_filterChip_dateRange(String end, String start) {
    return '$start إلى $end';
  }

  @override
  String diveLog_filterChip_equipmentCount(int count) {
    return '$count معدات';
  }

  @override
  String get diveLog_filter_allComputers => 'جميع حواسيب الغوص';

  @override
  String get diveLog_filter_noComputersRegistered =>
      'لا توجد حواسيب غوص مسجَّلة';

  @override
  String diveLog_filter_sectionDepthRangeUnit(String unit) {
    return 'نطاق العمق ($unit)';
  }

  @override
  String get diveLog_filter_sectionDiveComputer => 'حاسوب الغوص';

  @override
  String diveLog_listPage_semanticsDiveAtSite(int diveNumber, String siteName) {
    return 'الغوصة $diveNumber في $siteName';
  }

  @override
  String get enum_listViewMode_compact => 'مضغوط';

  @override
  String get enum_listViewMode_dense => 'كثيف';

  @override
  String get enum_listViewMode_detailed => 'مفصّل';

  @override
  String get enum_listViewMode_table => 'جدول';

  @override
  String get enum_profileMetric_ascentRate => 'معدل الصعود';

  @override
  String get enum_profileMetric_cns => 'CNS%';

  @override
  String get enum_profileMetric_otu => 'OTU';

  @override
  String get enum_sortField_bottomTime => 'وقت القاع';

  @override
  String get enum_sortField_serviceDue => 'الصيانة مستحقة';

  @override
  String get listViewMode_tooltip => 'وضع العرض';

  @override
  String marineLife_speciesManage_errorLoading(Object error) {
    return 'خطأ أثناء تحميل الأنواع: $error';
  }

  @override
  String get settings_appearance_header_cards => 'البطاقات';

  @override
  String get settings_appearance_header_listView => 'عرض القائمة';

  @override
  String get settings_appearance_header_tableMode => 'وضع الجدول';

  @override
  String get settings_appearance_listFields_buddies => 'حقول قائمة الرفاق';

  @override
  String get settings_appearance_listFields_certifications =>
      'حقول قائمة الشهادات';

  @override
  String get settings_appearance_listFields_courses => 'حقول قائمة الدورات';

  @override
  String get settings_appearance_listFields_diveCenters =>
      'حقول قائمة مراكز الغوص';

  @override
  String get settings_appearance_listFields_dives => 'حقول قائمة الغوصات';

  @override
  String get settings_appearance_listFields_equipment => 'حقول قائمة المعدات';

  @override
  String get settings_appearance_listFields_sites => 'حقول قائمة المواقع';

  @override
  String get settings_appearance_listFields_subtitle =>
      'خصّص الحقول المعروضة في عروض القوائم';

  @override
  String get settings_appearance_listFields_trips => 'حقول قائمة الرحلات';

  @override
  String get settings_appearance_listView_buddies => 'عرض قائمة الرفاق';

  @override
  String get settings_appearance_listView_buddies_subtitle =>
      'التخطيط الافتراضي لقائمة الرفاق';

  @override
  String get settings_appearance_listView_certifications =>
      'عرض قائمة الشهادات';

  @override
  String get settings_appearance_listView_certifications_subtitle =>
      'التخطيط الافتراضي لقائمة الشهادات';

  @override
  String get settings_appearance_listView_courses => 'عرض قائمة الدورات';

  @override
  String get settings_appearance_listView_courses_subtitle =>
      'التخطيط الافتراضي لقائمة الدورات';

  @override
  String get settings_appearance_listView_diveCenters =>
      'عرض قائمة مراكز الغوص';

  @override
  String get settings_appearance_listView_diveCenters_subtitle =>
      'التخطيط الافتراضي لقائمة مراكز الغوص';

  @override
  String get settings_appearance_listView_dives => 'عرض قائمة الغوصات';

  @override
  String get settings_appearance_listView_dives_subtitle =>
      'التخطيط الافتراضي لقائمة الغوصات';

  @override
  String get settings_appearance_listView_equipment => 'عرض قائمة المعدات';

  @override
  String get settings_appearance_listView_equipment_subtitle =>
      'التخطيط الافتراضي لقائمة المعدات';

  @override
  String get settings_appearance_listView_sites => 'عرض قائمة المواقع';

  @override
  String get settings_appearance_listView_sites_subtitle =>
      'التخطيط الافتراضي لقائمة المواقع';

  @override
  String get settings_appearance_listView_trips => 'عرض قائمة الرحلات';

  @override
  String get settings_appearance_listView_trips_subtitle =>
      'التخطيط الافتراضي لقائمة الرحلات';

  @override
  String get settings_appearance_showDataSourceBadges =>
      'إظهار شارات مصدر البيانات';

  @override
  String get settings_appearance_showDataSourceBadges_subtitle =>
      'عرض نسبة المصدر على مقاييس الغوص';

  @override
  String get settings_appearance_title_buddies => 'مظهر الرفاق';

  @override
  String get settings_appearance_title_certifications => 'مظهر الشهادات';

  @override
  String get settings_appearance_title_courses => 'مظهر الدورات';

  @override
  String get settings_appearance_title_diveCenters => 'مظهر مراكز الغوص';

  @override
  String get settings_appearance_title_dives => 'مظهر الغوصات';

  @override
  String get settings_appearance_title_equipment => 'مظهر المعدات';

  @override
  String get settings_appearance_title_sites => 'مظهر المواقع';

  @override
  String get settings_appearance_title_trips => 'مظهر الرحلات';

  @override
  String get settings_cloudSync_troubleshoot_tileSubtitle =>
      'أصلح مزامنة متوقفة أو حرّر مساحة سحابية';

  @override
  String get settings_data_header_dataTools => 'أدوات البيانات';

  @override
  String get settings_decompression_ascentGasLabel => 'خطّط الصعود باستخدام';

  @override
  String get settings_decompression_ascentGas_allCarried =>
      'جميع الأسطوانات المحمولة';

  @override
  String get settings_decompression_ascentGas_decoStage =>
      'غاز الديكو/الستيج + الغاز الخلفي';

  @override
  String get settings_decompression_cnsSource => 'مصدر الـ CNS';

  @override
  String get settings_decompression_decoStopSource => 'مصدر محطات تخفيف الضغط';

  @override
  String get settings_decompression_header_ascent => 'تخطيط الصعود';

  @override
  String get settings_decompression_header_ascent_subtitle =>
      'أي الأسطوانات المحمولة يمكن للصعود المحاكى (TTS والسقف والمحطات) التبديل إليها عند كل عمق. تؤخذ في الاعتبار الغازات المسجَّلة في الغوصة فقط.';

  @override
  String get settings_decompression_header_dataSources =>
      'تفضيلات مصدر البيانات';

  @override
  String get settings_decompression_header_dataSources_subtitle =>
      'عند ضبطه على حاسوب الغوص، يستخدم التطبيق البيانات التي يبلّغ عنها حاسوب الغوص عند توفرها. ويرجع إلى القيم المحسوبة عند عدم توفر بيانات الحاسوب.';

  @override
  String get settings_decompression_ndlSource => 'مصدر NDL';

  @override
  String get settings_decompression_sourceCalculated => 'محسوب';

  @override
  String get settings_decompression_sourceComputer => 'حاسوب الغوص';

  @override
  String get settings_decompression_ttsSource => 'مصدر TTS';

  @override
  String settings_fixDiveTimes_applied(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديث $count غوصة',
      many: 'تم تحديث $count غوصة',
      few: 'تم تحديث $count غوصات',
      two: 'تم تحديث غوصتين',
      one: 'تم تحديث غوصة واحدة',
      zero: 'تم تحديث $count غوصة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'ساعة',
      many: 'ساعة',
      few: 'ساعات',
      two: 'ساعتان',
      one: 'ساعة',
      zero: 'ساعة',
    );
    return '$_temp0 بمقدار $hours $_temp1.';
  }

  @override
  String settings_fixDiveTimes_apply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تطبيق على $count غوصة',
      many: 'تطبيق على $count غوصة',
      few: 'تطبيق على $count غوصات',
      two: 'تطبيق على غوصتين',
      one: 'تطبيق على غوصة واحدة',
      zero: 'تطبيق على $count غوصة',
    );
    return '$_temp0';
  }

  @override
  String get settings_fixDiveTimes_clearRange => 'مسح نطاق التاريخ';

  @override
  String get settings_fixDiveTimes_confirmApply => 'تطبيق';

  @override
  String settings_fixDiveTimes_confirmBody(
    int count,
    String hours,
    int hoursAbs,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غوصة',
      many: '$count غوصة',
      few: '$count غوصات',
      two: 'غوصتين',
      one: 'غوصة واحدة',
      zero: '$count غوصة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'ساعة',
      many: 'ساعة',
      few: 'ساعات',
      two: 'ساعتان',
      one: 'ساعة',
      zero: 'ساعة',
    );
    return 'سيؤدي هذا إلى إزاحة $_temp0 بمقدار $hours $_temp1. لا يمكن التراجع عن ذلك تلقائياً.';
  }

  @override
  String get settings_fixDiveTimes_confirmTitle => 'تطبيق إزاحة الوقت';

  @override
  String get settings_fixDiveTimes_dateRangeFilter => 'مرشّح نطاق التاريخ';

  @override
  String get settings_fixDiveTimes_deselectAll => 'إلغاء تحديد الكل';

  @override
  String get settings_fixDiveTimes_diveFallback => 'غوصة';

  @override
  String settings_fixDiveTimes_diveNumber(int number) {
    return 'الغوصة رقم $number';
  }

  @override
  String get settings_fixDiveTimes_empty => 'لم يتم العثور على غوصات.';

  @override
  String get settings_fixDiveTimes_emptyFiltered =>
      'لم يتم العثور على غوصات في نطاق التاريخ هذا.';

  @override
  String get settings_fixDiveTimes_enterOffsetHint => 'أدخل إزاحة بالساعات';

  @override
  String get settings_fixDiveTimes_from => 'من';

  @override
  String get settings_fixDiveTimes_hourOffset => 'إزاحة الساعات';

  @override
  String get settings_fixDiveTimes_hoursField => 'الساعات (مثال: +7، -5)';

  @override
  String settings_fixDiveTimes_loadError(String error) {
    return 'تعذّر تحميل الغوصات: $error';
  }

  @override
  String get settings_fixDiveTimes_noSelection => 'لم يتم تحديد أي غوصة.';

  @override
  String get settings_fixDiveTimes_offsetHint =>
      'أدخل عدداً صحيحاً موجباً أو سالباً لإزاحة أوقات الغوصات.';

  @override
  String settings_fixDiveTimes_preview(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غوصة',
      many: '$count غوصة',
      few: '$count غوصات',
      two: 'غوصتان',
      one: 'غوصة واحدة',
      zero: '$count غوصة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'ساعة',
      many: 'ساعة',
      few: 'ساعات',
      two: 'ساعتان',
      one: 'ساعة',
      zero: 'ساعة',
    );
    return 'معاينة: $_temp0 ستُزاح بمقدار $hours $_temp1.';
  }

  @override
  String get settings_fixDiveTimes_selectAll => 'تحديد الكل';

  @override
  String get settings_fixDiveTimes_selectDivesHint =>
      'اختر الغوصات المراد تطبيق التغيير عليها';

  @override
  String get settings_fixDiveTimes_subtitle => 'اضبط أوقات الغوصات المستوردة';

  @override
  String get settings_fixDiveTimes_title => 'إصلاح أوقات الغوص';

  @override
  String get settings_fixDiveTimes_to => 'إلى';

  @override
  String get settings_fixDiveTimes_zeroOffset =>
      'إزاحة الساعات هي 0، لا يوجد ما يتغير.';

  @override
  String get settings_syncDevices_appBar_refreshTooltip => 'تحديث';

  @override
  String get settings_syncDevices_appBar_title => 'الأجهزة على هذه الخدمة';

  @override
  String get settings_syncDevices_empty =>
      'لا توجد ملفات مزامنة على هذه الخدمة.';

  @override
  String settings_syncDevices_readError(String error) {
    return 'تعذّرت قراءة الخدمة.\n$error';
  }

  @override
  String get settings_syncDevices_removal_noBackend =>
      'لم يتم إعداد أي خدمة سحابية';

  @override
  String get settings_syncDevices_removal_unreachable =>
      'تعذّر الوصول إلى الخدمة. لم تتم إزالة أي شيء.';

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
          'سيؤدي هذا إلى حذف $count ملف ($size) تخص $name.\n\nما زال ذلك الجهاز جزءاً من هذه المزامنة. إذا عاد إلى الاتصال فسيعيد البناء من الخدمة بدلاً من إحياء البيانات القديمة، لكن أي تغييرات لم ينشرها بعد ستُفقد. بيانات الغوص الخاصة بك على هذا الجهاز لن تتأثر.',
      many:
          'سيؤدي هذا إلى حذف $count ملفًا ($size) تخص $name.\n\nما زال ذلك الجهاز جزءاً من هذه المزامنة. إذا عاد إلى الاتصال فسيعيد البناء من الخدمة بدلاً من إحياء البيانات القديمة، لكن أي تغييرات لم ينشرها بعد ستُفقد. بيانات الغوص الخاصة بك على هذا الجهاز لن تتأثر.',
      few:
          'سيؤدي هذا إلى حذف $count ملفات ($size) تخص $name.\n\nما زال ذلك الجهاز جزءاً من هذه المزامنة. إذا عاد إلى الاتصال فسيعيد البناء من الخدمة بدلاً من إحياء البيانات القديمة، لكن أي تغييرات لم ينشرها بعد ستُفقد. بيانات الغوص الخاصة بك على هذا الجهاز لن تتأثر.',
      two:
          'سيؤدي هذا إلى حذف ملفين ($size) تخص $name.\n\nما زال ذلك الجهاز جزءاً من هذه المزامنة. إذا عاد إلى الاتصال فسيعيد البناء من الخدمة بدلاً من إحياء البيانات القديمة، لكن أي تغييرات لم ينشرها بعد ستُفقد. بيانات الغوص الخاصة بك على هذا الجهاز لن تتأثر.',
      one:
          'سيؤدي هذا إلى حذف ملف واحد ($size) تخص $name.\n\nما زال ذلك الجهاز جزءاً من هذه المزامنة. إذا عاد إلى الاتصال فسيعيد البناء من الخدمة بدلاً من إحياء البيانات القديمة، لكن أي تغييرات لم ينشرها بعد ستُفقد. بيانات الغوص الخاصة بك على هذا الجهاز لن تتأثر.',
      zero:
          'سيؤدي هذا إلى حذف $count ملف ($size) تخص $name.\n\nما زال ذلك الجهاز جزءاً من هذه المزامنة. إذا عاد إلى الاتصال فسيعيد البناء من الخدمة بدلاً من إحياء البيانات القديمة، لكن أي تغييرات لم ينشرها بعد ستُفقد. بيانات الغوص الخاصة بك على هذا الجهاز لن تتأثر.',
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
          'سيؤدي هذا إلى حذف $count ملف ($size) تخص $name. وهي متبقية من مكتبة لم يعد أي جهاز يزامن منها. بيانات الغوص الخاصة بك لن تتأثر.',
      many:
          'سيؤدي هذا إلى حذف $count ملفًا ($size) تخص $name. وهي متبقية من مكتبة لم يعد أي جهاز يزامن منها. بيانات الغوص الخاصة بك لن تتأثر.',
      few:
          'سيؤدي هذا إلى حذف $count ملفات ($size) تخص $name. وهي متبقية من مكتبة لم يعد أي جهاز يزامن منها. بيانات الغوص الخاصة بك لن تتأثر.',
      two:
          'سيؤدي هذا إلى حذف ملفين ($size) تخص $name. وهي متبقية من مكتبة لم يعد أي جهاز يزامن منها. بيانات الغوص الخاصة بك لن تتأثر.',
      one:
          'سيؤدي هذا إلى حذف ملف واحد ($size) تخص $name. وهي متبقية من مكتبة لم يعد أي جهاز يزامن منها. بيانات الغوص الخاصة بك لن تتأثر.',
      zero:
          'سيؤدي هذا إلى حذف $count ملف ($size) تخص $name. وهي متبقية من مكتبة لم يعد أي جهاز يزامن منها. بيانات الغوص الخاصة بك لن تتأثر.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_removeDialog_title(String name) {
    return 'إزالة ملفات $name؟';
  }

  @override
  String settings_syncDevices_removeProgressTitle(String name) {
    return 'جارٍ إزالة ملفات $name';
  }

  @override
  String get settings_syncDevices_removeTooltip => 'إزالة ملفات هذا الجهاز';

  @override
  String get settings_syncDevices_state_active => 'تتم المزامنة بشكل طبيعي';

  @override
  String get settings_syncDevices_state_retired => 'متقاعد';

  @override
  String get settings_syncDevices_state_staleEpoch =>
      'متبقٍ من مكتبة سابقة؛ لا يقرأه أي جهاز';

  @override
  String get settings_syncDevices_state_thisDevice => 'هذا الجهاز';

  @override
  String get settings_syncDevices_state_unreadable =>
      'لا يوجد بيان قابل للقراءة؛ رفع غير مكتمل أو مشفَّر';

  @override
  String settings_syncDevices_summary(
    int deviceCount,
    int fileCount,
    String size,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      deviceCount,
      locale: localeName,
      other: '$deviceCount جهاز',
      many: '$deviceCount جهازًا',
      few: '$deviceCount أجهزة',
      two: 'جهازان',
      one: 'جهاز واحد',
      zero: '$deviceCount جهاز',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: '$fileCount ملف',
      many: '$fileCount ملفًا',
      few: '$fileCount ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
      zero: '$fileCount ملف',
    );
    return '$_temp0، $_temp1، $size';
  }

  @override
  String settings_syncDevices_summary_removable(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جهاز متبقٍ من مكتبة مستبدَلة أو متقاعدة، ويشغل $size.',
      many: '$count جهازًا متبقيًا من مكتبة مستبدَلة أو متقاعدة، ويشغل $size.',
      few: '$count أجهزة متبقية من مكتبة مستبدَلة أو متقاعدة، ويشغل $size.',
      two: 'جهازان متبقيان من مكتبة مستبدَلة أو متقاعدة، ويشغل $size.',
      one: 'جهاز واحد متبقٍ من مكتبة مستبدَلة أو متقاعدة، ويشغل $size.',
      zero: '$count جهاز متبقٍ من مكتبة مستبدَلة أو متقاعدة، ويشغل $size.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_tile_filesSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      many: '$count ملفًا',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
      zero: '$count ملف',
    );
    return '$_temp0، $size';
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
      other: '$count ملف',
      many: '$count ملفًا',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
      zero: '$count ملف',
    );
    return '$_temp0، $size · $when';
  }

  @override
  String settings_syncDevices_unnamedDevice(String shortId) {
    return 'الجهاز $shortId';
  }

  @override
  String get settings_syncMaintenance_keepAppOpen =>
      'أبقِ التطبيق مفتوحاً حتى تنتهي هذه العملية. إغلاقه الآن يترك الخدمة ممسوحة جزئياً، وستضطر المزامنة التالية إلى البدء من جديد.';

  @override
  String get settings_syncMaintenance_phase_clearingOldFiles =>
      'جارٍ مسح الملفات القديمة';

  @override
  String get settings_syncMaintenance_phase_deleting => 'جارٍ الحذف';

  @override
  String get settings_syncMaintenance_phase_publishingLibrary =>
      'جارٍ نشر المكتبة';

  @override
  String get settings_cloudSync_adopt_progressTitle =>
      'جارٍ اعتماد المكتبة المستعادة';

  @override
  String get settings_cloudSync_replaceLibrary_progressTitle =>
      'جارٍ استبدال مكتبة السحابة';

  @override
  String settings_syncDevices_nameWithId(String name, String shortId) {
    return '$name ($shortId)';
  }

  @override
  String get settings_syncMaintenance_phase_applyingLibrary =>
      'جارٍ تطبيق المكتبة';

  @override
  String get settings_syncMaintenance_phase_backingUp =>
      'جارٍ إنشاء نسخة احتياطية لهذا الجهاز';

  @override
  String get settings_syncMaintenance_phase_repairing =>
      'جارٍ مسح حالة المزامنة المحلية';

  @override
  String get settings_troubleshootSync_repair_progressTitle =>
      'جارٍ إصلاح المزامنة';

  @override
  String get settings_syncMaintenance_phase_working => 'جارٍ العمل...';

  @override
  String settings_syncMaintenance_progress_filesOfTotal(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done من $total ملف',
      many: '$done من $total ملفًا',
      few: '$done من $total ملفات',
      two: '$done من ملفين',
      one: '$done من ملف واحد',
      zero: '$done من $total ملف',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_removedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت إزالة $count ملف',
      many: 'تمت إزالة $count ملفًا',
      few: 'تمت إزالة $count ملفات',
      two: 'تمت إزالة ملفين',
      one: 'تمت إزالة ملف واحد',
      zero: 'تمت إزالة $count ملف',
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
          'تمت إزالة $count ملف، لكن $trouble. حاول مرة أخرى أثناء الاتصال بالإنترنت.',
      many:
          'تمت إزالة $count ملفًا، لكن $trouble. حاول مرة أخرى أثناء الاتصال بالإنترنت.',
      few:
          'تمت إزالة $count ملفات، لكن $trouble. حاول مرة أخرى أثناء الاتصال بالإنترنت.',
      two:
          'تمت إزالة ملفين، لكن $trouble. حاول مرة أخرى أثناء الاتصال بالإنترنت.',
      one:
          'تمت إزالة ملف واحد، لكن $trouble. حاول مرة أخرى أثناء الاتصال بالإنترنت.',
      zero:
          'تمت إزالة $count ملف، لكن $trouble. حاول مرة أخرى أثناء الاتصال بالإنترنت.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_trouble_failed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذّر حذف $count',
      many: 'تعذّر حذف $count',
      few: 'تعذّر حذف $count',
      two: 'تعذّر حذف اثنين',
      one: 'تعذّر حذف واحد',
      zero: 'تعذّر حذف $count',
    );
    return '$_temp0';
  }

  @override
  String get settings_syncMaintenance_trouble_listIncomplete =>
      'تعذّر سرد بعض الملفات';

  @override
  String settings_syncMaintenance_wipedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم مسح $count ملف',
      many: 'تم مسح $count ملفًا',
      few: 'تم مسح $count ملفات',
      two: 'تم مسح ملفين',
      one: 'تم مسح ملف واحد',
      zero: 'تم مسح $count ملف',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_wipedFilesPartial(int count, String trouble) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'تم مسح $count ملف، لكن $trouble. حاول مرة أخرى أثناء الاتصال بالإنترنت.',
      many:
          'تم مسح $count ملفًا، لكن $trouble. حاول مرة أخرى أثناء الاتصال بالإنترنت.',
      few:
          'تم مسح $count ملفات، لكن $trouble. حاول مرة أخرى أثناء الاتصال بالإنترنت.',
      two: 'تم مسح ملفين، لكن $trouble. حاول مرة أخرى أثناء الاتصال بالإنترنت.',
      one:
          'تم مسح ملف واحد، لكن $trouble. حاول مرة أخرى أثناء الاتصال بالإنترنت.',
      zero:
          'تم مسح $count ملف، لكن $trouble. حاول مرة أخرى أثناء الاتصال بالإنترنت.',
    );
    return '$_temp0';
  }

  @override
  String get settings_troubleshootSync_appBar_title => 'استكشاف أخطاء المزامنة';

  @override
  String get settings_troubleshootSync_devices_subtitle =>
      'اطّلع على كل جهاز يحتفظ بملفات هنا، ومقدار المساحة التي يستخدمها كل منها، وأزل المخلفات من المكتبات التي لم يعد أي جهاز يزامن منها. بيانات الغوص الخاصة بك لن تتأثر.';

  @override
  String get settings_troubleshootSync_rebuild_confirm => 'إعادة البناء';

  @override
  String get settings_troubleshootSync_rebuild_confirmBody =>
      'يجعل هذا مكتبة هذا الجهاز هي المكتبة الحالية على الخدمة ويعيد نشرها، بحيث تزامن الأجهزة الأخرى منك. استخدمه عندما يتعثر استبدال قادم من جهاز آخر. بيانات الغوص الخاصة بك لن تتأثر.';

  @override
  String get settings_troubleshootSync_rebuild_confirmTitle =>
      'إعادة بناء الخدمة من هذا الجهاز؟';

  @override
  String get settings_troubleshootSync_rebuild_doneSnack =>
      'تمت إعادة بناء الخدمة من هذا الجهاز';

  @override
  String get settings_troubleshootSync_rebuild_failedSnack =>
      'فشلت إعادة البناء';

  @override
  String get settings_troubleshootSync_rebuild_progressTitle =>
      'جارٍ إعادة بناء الخدمة';

  @override
  String get settings_troubleshootSync_rebuild_subtitle =>
      'استخدمه إذا كانت المزامنة متوقفة في انتظار مكتبة استبدلها جهاز آخر لكنه لم يُكمل رفعها أبداً (قد يكون ذلك الجهاز غير متصل). ينشر مكتبة هذا الجهاز باعتبارها الحالية.';

  @override
  String get settings_troubleshootSync_rebuild_title =>
      'إعادة بناء الخدمة من هذا الجهاز';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmBody =>
      'يحذف هذا من الخدمة ملفات المزامنة الخاصة بهذا الجهاز فقط. تستمر الأجهزة الأخرى في المزامنة، وبيانات الغوص الخاصة بك لن تتأثر.';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmTitle =>
      'إزالة ملفات هذا الجهاز السحابية؟';

  @override
  String get settings_troubleshootSync_removeThisDevice_progressTitle =>
      'جارٍ إزالة ملفات هذا الجهاز السحابية';

  @override
  String get settings_troubleshootSync_removeThisDevice_subtitle =>
      'حرّر مساحة هذا الجهاز على الخدمة. تستمر الأجهزة الأخرى في المزامنة. بيانات الغوص الخاصة بك لن تتأثر.';

  @override
  String get settings_troubleshootSync_removeThisDevice_title =>
      'إزالة ملفات هذا الجهاز السحابية';

  @override
  String get settings_troubleshootSync_repair_confirm => 'إصلاح';

  @override
  String get settings_troubleshootSync_repair_confirmBody =>
      'يمسح هذا كل حالة المزامنة المحلية ويمنح هذا الجهاز هوية مزامنة جديدة، ثم يعيد الاتصال من جديد عند المزامنة التالية. بيانات الغوص الخاصة بك آمنة ولن تُحذف.';

  @override
  String get settings_troubleshootSync_repair_confirmTitle => 'إصلاح المزامنة؟';

  @override
  String get settings_troubleshootSync_repair_doneSnack => 'تم إصلاح المزامنة';

  @override
  String get settings_troubleshootSync_repair_subtitle =>
      'أصلح مزامنة متوقفة. يمسح حالة المزامنة الخاصة بهذا الجهاز ويمنحه هوية مزامنة جديدة، ثم يعيد الاتصال عند المزامنة التالية. بيانات الغوص الخاصة بك لن تتأثر.';

  @override
  String get settings_troubleshootSync_repair_title => 'إصلاح المزامنة';

  @override
  String get settings_troubleshootSync_wipeAll_confirm => 'مسح كل شيء';

  @override
  String settings_troubleshootSync_wipeAll_confirmBody(String word) {
    return 'يحذف هذا بيانات المزامنة الخاصة بكل جهاز من هذه الخدمة، بما في ذلك علامات المكتبة. سيتعين على كل جهاز إعادة إنشاء المزامنة من الصفر. بيانات الغوص الخاصة بك لن تتأثر.\n\nاكتب الكلمة $word تماماً للتأكيد.';
  }

  @override
  String get settings_troubleshootSync_wipeAll_confirmTitle =>
      'مسح جميع بيانات المزامنة؟';

  @override
  String get settings_troubleshootSync_wipeAll_progressTitle =>
      'جارٍ مسح بيانات المزامنة';

  @override
  String get settings_troubleshootSync_wipeAll_subtitle =>
      'احذف بيانات المزامنة الخاصة بكل جهاز من هذه الخدمة، بما في ذلك علامات المكتبة. يعيد كل جهاز إنشاء المزامنة من الصفر. بيانات الغوص الخاصة بك لن تتأثر.';

  @override
  String get settings_troubleshootSync_wipeAll_title =>
      'مسح جميع بيانات المزامنة على هذه الخدمة';

  @override
  String get tableMode_tooltip_toggleDetailPane => 'تبديل لوحة التفاصيل';

  @override
  String get tableMode_tooltip_toggleProfilePanel => 'تبديل لوحة المخطط';

  @override
  String get maps_regionDownload_title => 'تنزيل منطقة';

  @override
  String get maps_regionDownload_nameRequired => 'يرجى إدخال اسم لهذه المنطقة';

  @override
  String get maps_regionDownload_nameLabel => 'اسم المنطقة';

  @override
  String get maps_regionDownload_nameHint => 'مثال: كوزوميل، المكسيك';

  @override
  String get maps_regionDownload_zoomLevels => 'مستويات التكبير';

  @override
  String get maps_regionDownload_zoomHint =>
      'تكبير أعلى = تفاصيل أكثر وحجم تنزيل أكبر';

  @override
  String maps_regionDownload_minZoom(int zoom) {
    return 'الأدنى: $zoom';
  }

  @override
  String maps_regionDownload_minZoomSemantics(int zoom) {
    return 'أدنى تكبير: $zoom';
  }

  @override
  String maps_regionDownload_maxZoom(int zoom) {
    return 'الأقصى: $zoom';
  }

  @override
  String maps_regionDownload_maxZoomSemantics(int zoom) {
    return 'أقصى تكبير: $zoom';
  }

  @override
  String get maps_regionDownload_estimatingSemantics =>
      'جارٍ تقدير حجم التنزيل';

  @override
  String maps_regionDownload_estimateSemantics(int count, Object size) {
    return 'التنزيل المقدر: $count بلاطة، $size';
  }

  @override
  String get maps_regionDownload_estimateUnavailableSemantics =>
      'تعذر تقدير حجم التنزيل';

  @override
  String get maps_regionDownload_estimating => 'جارٍ التقدير...';

  @override
  String maps_regionDownload_tileCount(int count) {
    return '~$count بلاطة';
  }

  @override
  String get maps_regionDownload_estimateUnavailable => 'تعذر التقدير';

  @override
  String get maps_regionDownload_largeWarningSemantics =>
      'تحذير: تنزيل كبير. فكّر في خفض مستويات التكبير أو اختيار منطقة أصغر.';

  @override
  String get maps_regionDownload_largeWarning =>
      'تنزيل كبير. فكّر في خفض مستويات التكبير أو اختيار منطقة أصغر.';

  @override
  String get maps_regionDownload_downloadButton => 'تنزيل';

  @override
  String get diveLog_map_title => 'نشاط الغوص';

  @override
  String diveLog_map_infoCard_minutes(int minutes) {
    return '$minutes دقيقة';
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
      'صورة مصغّرة لصورة. انقر للعرض بملء الشاشة';

  @override
  String get trips_gallery_thumbnail_video =>
      'صورة مصغّرة لفيديو. انقر للعرض بملء الشاشة';

  @override
  String get trips_gallery_thumbnail_photoMissing =>
      'صورة مصغّرة لصورة، مفقودة من الجهاز. انقر للعرض بملء الشاشة';

  @override
  String get trips_gallery_thumbnail_videoMissing =>
      'صورة مصغّرة لفيديو، مفقود من الجهاز. انقر للعرض بملء الشاشة';

  @override
  String get trips_photos_thumbnail_photo =>
      'صورة مصغّرة لصورة. انقر لفتح المعرض';

  @override
  String get trips_photos_thumbnail_video =>
      'صورة مصغّرة لفيديو. انقر لفتح المعرض';

  @override
  String trips_picker_suggestedSemantics(Object name) {
    return 'رحلة مقترحة: $name. انقر للاستخدام';
  }

  @override
  String trips_picker_tileSemantics(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name، من $startDate إلى $endDate';
  }

  @override
  String trips_picker_tileSemanticsSelected(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name، من $startDate إلى $endDate، محددة';
  }

  @override
  String get divePlanner_quickPlan_subtitle => 'أنشئ ملف غوص مستطيلاً بسيطاً';

  @override
  String get divePlanner_quickPlan_depthLabel => 'العمق:';

  @override
  String divePlanner_quickPlan_depthSemantics(Object depth) {
    return 'العمق: $depth';
  }

  @override
  String get divePlanner_quickPlan_timeLabel => 'الوقت:';

  @override
  String divePlanner_quickPlan_bottomTimeSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'وقت القاع: $minutes دقيقة',
      many: 'وقت القاع: $minutes دقيقة',
      few: 'وقت القاع: $minutes دقائق',
      two: 'وقت القاع: دقيقتان',
      one: 'وقت القاع: دقيقة واحدة',
      zero: 'وقت القاع: $minutes دقيقة',
    );
    return '$_temp0';
  }

  @override
  String divePlanner_quickPlan_minutes(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String divePlanner_quickPlan_previewSemantics(Object depth, int minutes) {
    return 'معاينة الخطة: نزول إلى $depth، وقت القاع $minutes دقيقة، صعود مع توقف أمان';
  }

  @override
  String get divePlanner_quickPlan_previewTitle => 'معاينة الخطة:';

  @override
  String divePlanner_quickPlan_previewDescent(Object depth) {
    return 'نزول إلى $depth';
  }

  @override
  String divePlanner_quickPlan_previewBottomTime(int minutes) {
    return 'وقت القاع: $minutes دقيقة';
  }

  @override
  String get divePlanner_quickPlan_previewAscent => 'صعود مع توقف أمان';

  @override
  String get divePlanner_quickPlan_create => 'إنشاء';

  @override
  String divePlanner_semantics_sacRate(Object value, Object volumeSymbol) {
    return 'RMV: $value $volumeSymbol في الدقيقة';
  }

  @override
  String divePlanner_semantics_reservePressure(Object pressureSymbol) {
    return 'ضغط الاحتياطي بوحدة $pressureSymbol';
  }

  @override
  String divePlanner_semantics_altitudeGroup(Object group) {
    return 'مجموعة الارتفاع: $group';
  }

  @override
  String diveSites_import_detail_maxDepth(Object depth) {
    return 'أقصى $depth';
  }

  @override
  String get autoUpdate_banner_download => 'تنزيل';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'المزامنة عبر Apple iCloud';

  @override
  String get settings_debugLog_search_hint => 'البحث في السجلات...';

  @override
  String get settings_debugLog_appBar_title => 'سجلات التصحيح';

  @override
  String get settings_debugLog_disableDebugMode => 'تعطيل وضع التصحيح';

  @override
  String get settings_debugLog_clearLogs => 'مسح السجلات';

  @override
  String get settings_debugLog_empty =>
      'لا توجد إدخالات سجل تطابق عوامل التصفية الحالية';

  @override
  String settings_debugLog_loadError(Object error) {
    return 'خطأ في تحميل السجلات: $error';
  }

  @override
  String get settings_debugLog_copiedSnack =>
      'تم نسخ السجلات المصفاة إلى الحافظة';

  @override
  String settings_debugLog_savedSnack(String path) {
    return 'تم حفظ السجلات في $path';
  }

  @override
  String get common_action_copy => 'نسخ';

  @override
  String get settings_appearance_customGradient_title => 'تدرج مخصص';

  @override
  String get settings_appearance_customGradient_start => 'البداية';

  @override
  String get settings_appearance_customGradient_end => 'النهاية';

  @override
  String get settings_appearance_customGradient_hue => 'درجة اللون';

  @override
  String get settings_appearance_customGradient_saturation => 'التشبع';

  @override
  String get settings_appearance_customGradient_brightness => 'السطوع';

  @override
  String get settings_appearance_customGradient_preview => 'معاينة';

  @override
  String get common_action_apply => 'تطبيق';

  @override
  String settings_cloudSync_message_loadStateFailed(Object error) {
    return 'فشل تحميل حالة المزامنة: $error';
  }

  @override
  String get settings_cloudSync_message_noProviderConfigured =>
      'لم يتم إعداد أي مزود سحابي';

  @override
  String get settings_cloudSync_message_adopting =>
      'جارٍ اعتماد المكتبة المستعادة...';

  @override
  String get settings_cloudSync_message_adoptFailed =>
      'فشل اعتماد المكتبة المستعادة';

  @override
  String get settings_cloudSync_message_firstSyncNeedsConfirm =>
      'المزامنة الأولى تحتاج إلى تأكيد. اضغط على مزامنة الآن للمراجعة.';

  @override
  String get settings_cloudSync_message_startingSync => 'جارٍ بدء المزامنة...';

  @override
  String get settings_cloudSync_message_replacePaused =>
      'المزامنة متوقفة مؤقتًا: تم استبدال المكتبة من نسخة احتياطية. اضغط على مزامنة الآن للمراجعة.';

  @override
  String get settings_cloudSync_message_encryptedPaused =>
      'المزامنة متوقفة مؤقتًا: هذه المكتبة مشفرة. أدخل عبارة المرور للمتابعة.';

  @override
  String get settings_cloudSync_message_completedWithConflicts =>
      'اكتملت المزامنة مع وجود تعارضات';

  @override
  String get settings_cloudSync_message_completedSuccessfully =>
      'اكتملت المزامنة بنجاح';

  @override
  String get settings_cloudSync_message_syncFailed => 'فشلت المزامنة';

  @override
  String get settings_cloudSync_message_phaseDefault => 'المزامنة';

  @override
  String settings_cloudSync_message_syncErrorDuring(
    String phase,
    Object error,
  ) {
    return 'خطأ في المزامنة أثناء $phase: $error';
  }

  @override
  String get settings_section_debug_title => 'التصحيح';

  @override
  String get settings_section_debug_subtitle => 'السجلات والتشخيصات';

  @override
  String get settings_debugLog_minSeverityLabel => 'أدنى خطورة:';

  @override
  String get settings_debugLog_shareSubject => 'سجلات تصحيح Submersion';

  @override
  String get settings_debugLog_saveDialogTitle => 'حفظ سجلات التصحيح';

  @override
  String get universalImport_preset_saveTitle => 'حفظ كإعداد مسبق';

  @override
  String get universalImport_preset_nameLabel => 'اسم الإعداد المسبق';

  @override
  String get universalImport_preset_nameHint => 'مثال: ملف CSV لسجل غوصي';

  @override
  String get universalImport_preset_nameRequired => 'الاسم مطلوب';

  @override
  String get universalImport_preset_sourceAppLabel => 'التطبيق المصدر';

  @override
  String get universalImport_preset_sourceAppNone => 'بدون';

  @override
  String get universalImport_preset_entityTypesLabel => 'أنواع الكيانات';

  @override
  String get universalImport_preset_matchThresholdLabel => 'عتبة التطابق';

  @override
  String get universalImport_preset_matchThresholdHelp =>
      'مدى التطابق المطلوب في رؤوس أعمدة CSV للكشف التلقائي';

  @override
  String universalImport_preset_signatureHeaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رأس تعريف من الملف الحالي',
      many: '$count رأس تعريف من الملف الحالي',
      few: '$count رؤوس تعريف من الملف الحالي',
      two: 'رأسا تعريف من الملف الحالي',
      one: 'رأس تعريف واحد من الملف الحالي',
      zero: '$count رأس تعريف من الملف الحالي',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_preset_selectTitle => 'اختيار إعداد مسبق';

  @override
  String universalImport_preset_loadFailed(String error) {
    return 'فشل تحميل الإعدادات المسبقة: $error';
  }

  @override
  String get universalImport_preset_sectionSaved =>
      'الإعدادات المسبقة المحفوظة';

  @override
  String get universalImport_preset_sectionBuiltIn =>
      'الإعدادات المسبقة المدمجة';

  @override
  String get universalImport_preset_deleteTitle => 'حذف الإعداد المسبق';

  @override
  String universalImport_preset_deleteConfirm(String name) {
    return 'حذف \"$name\"؟ لا يمكن التراجع عن هذا.';
  }

  @override
  String universalImport_preset_headersMatched(
    int matched,
    int total,
    int percent,
  ) {
    return '$matched/$total رؤوس متطابقة ($percent%)';
  }

  @override
  String get universalImport_preset_noSignatureHeaders => 'لا توجد رؤوس تعريف';

  @override
  String get universalImport_preset_deleteTooltip => 'حذف الإعداد المسبق';

  @override
  String get universalImport_preset_presetsButton => 'الإعدادات المسبقة';

  @override
  String universalImport_preset_savedSnackbar(String name) {
    return 'تم حفظ الإعداد المسبق \"$name\"';
  }

  @override
  String get universalImport_step_done => 'تم';

  @override
  String get universalImport_cancel_inProgressTitle => 'جارٍ الإلغاء';

  @override
  String get universalImport_cancel_inProgressBody =>
      'سيتم إنهاء الغوصة الحالية قبل التوقف. تبقى الغوصات المستوردة بالفعل محفوظة.';

  @override
  String get universalImport_cancel_confirmTitle => 'إلغاء الاستيراد؟';

  @override
  String get universalImport_cancel_confirmBody =>
      'سيتوقف بعد انتهاء الغوصة الحالية. تبقى الغوصات المستوردة بالفعل محفوظة.';

  @override
  String get universalImport_cancel_keepImporting => 'متابعة الاستيراد';

  @override
  String get universalImport_cancel_confirmAction => 'إلغاء الاستيراد';

  @override
  String get universalImport_cancel_discardSelections =>
      'تجاهل التحديدات والإلغاء؟';

  @override
  String get universalImport_action_importSelected => 'استيراد المحدد';

  @override
  String get universalImport_action_next => 'التالي';

  @override
  String get common_action_yes => 'نعم';

  @override
  String get common_action_no => 'لا';

  @override
  String universalImport_counts_new(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جديد',
      many: '$count جديدًا',
      few: '$count جديدة',
      two: '$count جديدان',
      one: '$count جديد',
      zero: '$count جديد',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_merging(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قيد الدمج',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_replacing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قيد الاستبدال',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_skipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count متخطى',
      many: '$count متخطى',
      few: '$count متخطاة',
      two: '$count متخطيان',
      one: '$count متخطى',
      zero: '$count متخطى',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_counts_nothingSelected => 'لم يتم تحديد أي شيء';

  @override
  String get universalImport_section_potentialDuplicates => 'تكرارات محتملة';

  @override
  String get universalImport_section_possibleDuplicates => 'تكرارات ممكنة';

  @override
  String universalImport_count_duplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تكرار',
      many: '$count تكرارًا',
      few: '$count تكرارات',
      two: 'تكراران',
      one: 'تكرار واحد',
      zero: 'لا تكرارات',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_entityAction_importBadge => 'استيراد';

  @override
  String get universalImport_entityAction_skipBadge => 'تخطي';

  @override
  String get universalImport_compare_existing => 'الحالي';

  @override
  String get universalImport_compare_incoming => 'الوارد';

  @override
  String get universalImport_label_skipped => 'متخطى';

  @override
  String get universalImport_action_viewDives => 'عرض الغوصات';

  @override
  String get diveImport_healthkit_accessGranted =>
      'تم منح الوصول إلى HealthKit';

  @override
  String get diveImport_healthkit_accessGrantedBody =>
      'يمكنك الانتقال إلى الخطوة التالية.';

  @override
  String get diveImport_healthkit_requesting => 'جارٍ الطلب...';

  @override
  String get diveImport_healthkit_selectDateRange => 'اختيار النطاق الزمني';

  @override
  String get diveImport_healthkit_selectDateRangeBody =>
      'اختر النطاق الزمني للبحث عن الغوصات في Apple Health.';

  @override
  String get diveImport_healthkit_fetchingDives =>
      'جارٍ جلب الغوصات من Apple Health...';

  @override
  String get diveImport_healthkit_fetchFailed => 'فشل الجلب';

  @override
  String diveImport_healthkit_fetchFailedBody(String error) {
    return 'فشل جلب الغوصات: $error';
  }

  @override
  String diveImport_healthkit_foundDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم العثور على $count غوصة',
      many: 'تم العثور على $count غوصة',
      few: 'تم العثور على $count غوصات',
      two: 'تم العثور على غوصتين',
      one: 'تم العثور على غوصة واحدة',
      zero: 'لم يتم العثور على غوصات',
    );
    return '$_temp0';
  }

  @override
  String get diveImport_healthkit_proceedingToReview =>
      'جارٍ الانتقال إلى المراجعة...';

  @override
  String get importWizard_dc_knownComputer => 'كمبيوتر غوص معروف';

  @override
  String importWizard_dc_knownComputerBody(String name) {
    return 'محفوظ باسم \"$name\". سيتم تنزيل الغوصات الجديدة فقط.';
  }

  @override
  String get importWizard_dc_noNewDives => 'لا توجد غوصات جديدة للتنزيل';

  @override
  String get importWizard_dc_noNewDivesBody =>
      'تم استيراد جميع الغوصات من هذا الكمبيوتر بالفعل.';

  @override
  String get universalImport_compare_noDiveData =>
      'بيانات الغوصة غير متوفرة للمقارنة.';

  @override
  String get universalImport_entityAction_consolidateBadge => 'دمج';

  @override
  String get diveCenters_import_quickSearch_egypt => 'مصر';

  @override
  String get diveCenters_import_quickSearch_mexico => 'المكسيك';

  @override
  String get accessibility_shortcut_switchDiver => 'تبديل الغواص';

  @override
  String get lock_recoveryCode_title => 'استخدام رمز الاسترداد';

  @override
  String get lock_recoveryCode_body =>
      'أدخل رمز الاسترداد المكوَّن من 8 كلمات الذي حفظته عند إعداد كلمة مرور التطبيق.';

  @override
  String get lock_recoveryCode_error => 'رمز الاسترداد غير صحيح.';

  @override
  String get lock_forcedReset_title => 'تعيين كلمة مرور جديدة';

  @override
  String get lock_forcedReset_body =>
      'لقد فتحت القفل باستخدام رمز الاسترداد، لذلك لم تعد كلمة مرورك القديمة موثوقة. اختر كلمة مرور جديدة الآن.';

  @override
  String get lock_forcedReset_submit => 'تعيين كلمة المرور';

  @override
  String get lock_forcedReset_error =>
      'تعذّر تعيين كلمة المرور الجديدة. حاول مرة أخرى.';

  @override
  String get lock_sidecarRepair_title => 'إصلاح ملف مفتاح الأمان';

  @override
  String get lock_sidecarRepair_body =>
      'كان ملف مفتاح الأمان مفقودًا، وما زالت سلسلة مفاتيح هذا الجهاز تحتفظ بالمفتاح. أكِّد كلمة مرورك لكتابة ملف مفتاح جديد. ملاحظة: كلمة المرور التي تدخلها هنا تصبح كلمة مرور التطبيق من الآن فصاعدًا، وستتلقى رمز استرداد جديدًا.';

  @override
  String get lock_sidecarRepair_submit => 'إصلاح';

  @override
  String get lock_sidecarRepair_error => 'فشل الإصلاح. حاول مرة أخرى.';

  @override
  String get lock_newRecoveryCode_title => 'رمز الاسترداد الجديد الخاص بك';

  @override
  String get lock_startFresh_title => 'فتح قاعدة بيانات أخرى';

  @override
  String lock_startFresh_body(Object token) {
    return 'تبقى قاعدة بياناتك الحالية على القرص، بعد إعادة تسميتها باللاحقة .locked؛ لا يُحذف أي شيء. يمكنك استردادها لاحقًا بكلمة مرورك أو بالتواصل مع الدعم. سيتم إيقاف مزامنة السحابة حتى لا تختلط قاعدة البيانات الجديدة بالقديمة.\n\nسيبدأ التطبيق بقاعدة بيانات جديدة وفارغة. يمكنك الاستعادة من نسخة احتياطية في معالج الإعداد.\n\nاكتب $token للتأكيد.';
  }

  @override
  String get lock_startFresh_confirm => 'وضعها جانبًا والبدء من جديد';

  @override
  String get lock_biometric_reason => 'فتح قفل سجل الغوص';

  @override
  String startup_migrating_progress(Object currentStep, Object totalSteps) {
    return 'جارٍ ترقية قاعدة البيانات... الخطوة $currentStep من $totalSteps';
  }

  @override
  String get startup_error_title => 'تعذّر بدء تشغيل Submersion';

  @override
  String get startup_error_body =>
      'حدث خطأ ما قبل أن يكتمل فتح سجل الغوص الخاص بك. بياناتك ما زالت على القرص ولا تتطلب إعادة تثبيت. حاول إعادة تشغيل التطبيق، وإذا استمرت المشكلة تواصل مع الدعم.';

  @override
  String get startup_engineUnavailable_title =>
      'هذه النسخة لا تستطيع فتح قاعدة بيانات';

  @override
  String get startup_engineUnavailable_body =>
      'محرك قواعد البيانات الخاص بـ Submersion غير موجود في هذه النسخة، لذلك لم يُفتح سجل الغوص الخاص بك على الإطلاق. لم يتغيّر شيء على القرص ولا توجد بيانات معرّضة للخطر.';

  @override
  String get startup_engineUnavailable_guidance =>
      'إعادة التثبيت أو استرداد نسخة احتياطية لن تفيد هنا. ثبّت نسخة سليمة من Submersion، ويُرجى الإبلاغ عن هذه المشكلة: فهي خلل في حزمة التطبيق وليس في بياناتك.';

  @override
  String get startup_migrationFailed_title => 'فشلت ترقية قاعدة البيانات';

  @override
  String get startup_migrationFailed_body =>
      'تعذّرت ترقية سجل الغوص الخاص بك إلى التنسيق الذي تحتاجه هذه النسخة. أُخذت نسخة احتياطية قبل بدء الترقية، فلم يُفقد شيء.';

  @override
  String get startup_dataUnreadable_title => 'تعذّرت قراءة سجل الغوص الخاص بك';

  @override
  String get startup_dataUnreadable_body =>
      'ملف قاعدة البيانات موجود، لكن Submersion لا يستطيع قراءته. يعني هذا عادةً أن الملف تالف. استرداد نسخة احتياطية هو أسرع طريق للعودة.';

  @override
  String get startup_databaseBusy_title => 'كان سجل الغوص الخاص بك مشغولاً';

  @override
  String get startup_databaseBusy_body =>
      'كان هناك شيء آخر لا يزال يستخدم ملف قاعدة البيانات، لذلك توقف Submersion بدلاً من الكتابة فيه. لم يتغيّر أي شيء ولم يتضرر أي شيء. أغلق Submersion تمامًا ثم افتحه مرة أخرى.';

  @override
  String get startup_failure_technicalDetails => 'تفاصيل تقنية';

  @override
  String get startup_failure_backupAvailable_title => 'تتوفر نسخة احتياطية';

  @override
  String startup_failure_backupAvailable_taken(Object timestamp) {
    return 'أُخذت في $timestamp';
  }

  @override
  String startup_failure_backupAvailable_preMigration(
    Object fromVersion,
    Object toVersion,
  ) {
    return 'نسخة احتياطية أُخذت قبل الترقية من المخطط v$fromVersion إلى v$toVersion.';
  }

  @override
  String get startup_failure_restoreAction => 'استرداد هذه النسخة الاحتياطية';

  @override
  String get startup_failure_restoring => 'جارٍ استرداد سجل الغوص...';

  @override
  String get startup_failure_restoreFailed =>
      'تعذّر استرداد النسخة الاحتياطية. تُرك سجل الغوص الخاص بك كما كان تمامًا.';

  @override
  String get startup_failure_backupsFolder => 'نسخك الاحتياطية موجودة في:';

  @override
  String get startup_failure_showBackupsFolder => 'إظهار مجلد النسخ الاحتياطية';

  @override
  String get startup_failure_downgrade_title => 'العودة إلى الإصدار السابق';

  @override
  String get startup_failure_downgrade_body =>
      'إذا استمرت الترقية في الفشل، ثبّت إصدار Submersion الذي كنت تستخدمه سابقًا، ثم استرد النسخة الاحتياطية من داخل ذلك الإصدار. الاسترداد هنا سيعيد تشغيل الترقية نفسها فحسب. لا يخفّض Submersion إصداره تلقائيًا: نقلك تلقائيًا إلى نسخ أقدم سيبقيك بصمت على إصدارات ذات مشكلات معروفة.';

  @override
  String get startup_failure_downgrade_action => 'عرض الإصدارات السابقة';

  @override
  String get startup_recovering_title => 'جارٍ استرداد قاعدة البيانات...';

  @override
  String get startup_recovering_body =>
      'جارٍ التراجع عن المعاملة المتوقفة. يستغرق ذلك عادةً بضع ثوانٍ.';

  @override
  String get startup_recoveryFailed_title => 'لم يكتمل الاسترداد';

  @override
  String get startup_recoveryFailed_body =>
      'تعذّر التراجع عن قاعدة البيانات تلقائيًا. بياناتك ما زالت على القرص؛ تواصل مع الدعم قبل إعادة التثبيت حتى نتمكن من مساعدتك في استردادها.';

  @override
  String get startup_recoveryRequired_title =>
      'قاعدة البيانات بحاجة إلى استرداد';

  @override
  String get startup_recoveryRequired_body =>
      'انقطعت جلسة سابقة أثناء الكتابة في قاعدة البيانات. بياناتك ما زالت على القرص؛ نحتاج فقط إلى إتمام التراجع عن التغيير الملغى قبل أن يتمكن التطبيق من الفتح.';

  @override
  String startup_recovery_sqliteCode(Object code) {
    return 'رمز SQLite $code';
  }

  @override
  String get startup_recovery_action => 'استرداد قاعدة البيانات';

  @override
  String get startup_recovery_closeWithoutRecovering =>
      'الإغلاق من دون استرداد';

  @override
  String get common_action_tryAgain => 'حاول مرة أخرى';

  @override
  String get lock_screen_title => 'التطبيق Submersion مقفل';

  @override
  String get lock_screen_forgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get lock_incorrectPassword => 'كلمة المرور غير صحيحة. حاول مرة أخرى.';

  @override
  String get startup_backup_semanticsLabel => 'جارٍ النسخ الاحتياطي';

  @override
  String get startup_backup_title => 'جارٍ عمل نسخة احتياطية من بياناتك';

  @override
  String get startup_backup_body =>
      'نحفظ نسخة من سجل الغوص الخاص بك قبل تحديث قاعدة بياناتك.';

  @override
  String get startup_backupFailed_title => 'تعذّر عمل نسخة احتياطية من بياناتك';

  @override
  String get startup_backupFailed_body =>
      'لم يتغيّر سجل الغوص الخاص بك؛ لم نقم بتحديثه. حرِّر مساحة (أو عالج المشكلة) ثم حاول مرة أخرى.';

  @override
  String get startup_backupFailed_quit => 'إنهاء';

  @override
  String get startup_backupFailed_technicalDetails => 'تفاصيل تقنية';

  @override
  String get common_action_retry => 'إعادة المحاولة';

  @override
  String get startup_versionMismatch_title => 'التحديث مطلوب';

  @override
  String startup_versionMismatch_body(
    Object databaseVersion,
    Object appVersion,
  ) {
    return 'حُفظت بيانات غوصك بإصدار أحدث من Submersion (المخطط v$databaseVersion). هذا الإصدار يدعم حتى المخطط v$appVersion فقط.';
  }

  @override
  String get startup_versionMismatch_instructions =>
      'يرجى تحديث Submersion إلى أحدث إصدار. بياناتك آمنة ولم تُعدَّل. إذا أُخذت نسخة احتياطية قبل الترقية، فهي موجودة في مجلد Backups ويمكن استعادتها بعد التحديث.';

  @override
  String get startup_versionMismatch_storeInstructions =>
      'تم تثبيت هذا التطبيق من متجر تطبيقات وهو أقدم من الإصدار الذي أنشأ بياناتك. بياناتك آمنة ولم يتم تعديلها. حدّث Submersion عندما يظهر الإصدار الجديد في المتجر، ثم أعد فتحه.';

  @override
  String get startup_versionMismatch_download => 'تنزيل أحدث إصدار';

  @override
  String get startup_versionMismatch_manualLink =>
      'إذا لم يفتح ذلك متصفحًا، فتفضل بزيارة:';

  @override
  String get universalImport_compare_downloaded => 'المنزَّلة';

  @override
  String get universalImport_compare_errorLoading =>
      'خطأ في تحميل بيانات الغوصة';

  @override
  String get universalImport_compare_diveNotFound =>
      'لم يتم العثور على الغوصة الموجودة';

  @override
  String universalImport_compare_sameFields(Object fields) {
    return 'متطابق: $fields';
  }

  @override
  String get universalImport_compare_differences => 'الاختلافات';

  @override
  String get universalImport_compare_notRecorded => 'غير مسجل';

  @override
  String universalImport_compare_serial(Object serial) {
    return 'S/N: $serial';
  }

  @override
  String get universalImport_compare_skipSubtitle => 'تجاهل هذا التنزيل';

  @override
  String get universalImport_compare_importAsNewSubtitle =>
      'الحفظ كغوصة منفصلة';

  @override
  String get universalImport_compare_consolidateSubtitle =>
      'الإضافة كقراءة حاسوب ثانٍ';

  @override
  String get diveLog_tooltip_ndlOverMax => '>60 min';

  @override
  String diveLog_tooltip_interpolated(String value) {
    return '$value (بالاستيفاء)';
  }

  @override
  String get enum_profileMetric_ascentRate_short => 'المعدل';

  @override
  String get enum_profileMetric_cns_short => 'CNS';

  @override
  String get enum_profileMetric_otu_short => 'OTU';

  @override
  String get diveLog_profileEditor_rangeOperations => 'عمليات النطاق';

  @override
  String get diveLog_profileEditor_selectRangeHint =>
      'حدّد نطاقًا على الرسم البياني لتفعيل العمليات';

  @override
  String get diveLog_profileEditor_depthPlusOneMeter => 'العمق +1m';

  @override
  String get diveLog_profileEditor_depthMinusOneMeter => 'العمق -1m';

  @override
  String get diveLog_profileEditor_timePlusFiveSeconds => 'الوقت +5s';

  @override
  String get diveLog_profileEditor_timeMinusFiveSeconds => 'الوقت -5s';

  @override
  String get diveLog_profileEditor_smoothing => 'التنعيم';

  @override
  String get diveLog_profileEditor_smoothLight => 'خفيف';

  @override
  String get diveLog_profileEditor_smoothMedium => 'متوسط';

  @override
  String get diveLog_profileEditor_smoothHeavy => 'قوي';

  @override
  String get diveLog_profileEditor_applyToAll => 'تطبيق على الكل';

  @override
  String get diveLog_profileEditor_applyToSelection => 'تطبيق على التحديد';

  @override
  String get diveLog_profileEditor_outlierDetection => 'كشف القيم الشاذة';

  @override
  String get diveLog_profileEditor_detect => 'كشف';

  @override
  String get diveLog_profileEditor_removeAll => 'إزالة الكل';

  @override
  String diveLog_profileEditor_outliersDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم العثور على $count قيمة شاذة محتملة',
      many: 'تم العثور على $count قيمة شاذة محتملة',
      few: 'تم العثور على $count قيم شاذة محتملة',
      two: 'تم العثور على قيمتين شاذتين محتملتين',
      one: 'تم العثور على قيمة شاذة محتملة واحدة',
      zero: 'لم يتم العثور على قيم شاذة',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_profileEditor_manualDrawing => 'الرسم اليدوي';

  @override
  String get diveLog_profileEditor_drawHint =>
      'انقر على الرسم البياني لوضع نقاط المسار';

  @override
  String get diveLog_profileEditor_clearWaypoints => 'مسح';

  @override
  String get diveLog_profileEditor_generateProfile => 'إنشاء ملف الغوصة';

  @override
  String get diveLog_profileEditor_trimMode => 'وضع القص';

  @override
  String get diveLog_profileEditor_trimHint => 'قص أطراف ملف الغوصة';

  @override
  String get diveLog_profileEditor_trimEnd => 'قص النهاية';

  @override
  String get diveLog_profileEditor_mode_smooth => 'تنعيم';

  @override
  String get diveLog_profileEditor_title => 'تعديل ملف الغوصة';

  @override
  String get diveLog_profileEditor_discardBody =>
      'لديك تغييرات غير محفوظة على ملف الغوصة هذا. هل تريد بالتأكيد تجاهلها؟';

  @override
  String get diveLog_profileEditor_saveTitle => 'حفظ ملف الغوصة؟';

  @override
  String get diveLog_profileEditor_saveBody =>
      'سيؤدي هذا إلى حفظ الملف المعدَّل كملف أساسي لهذه الغوصة. سيبقى الملف الأصلي محفوظًا ويمكن استعادته لاحقًا.';

  @override
  String diveLog_profileEditor_saveFailed(String error) {
    return 'فشل حفظ ملف الغوصة: $error';
  }

  @override
  String diveLog_profileEditor_errorLoadingDive(String error) {
    return 'خطأ في تحميل الغوصة: $error';
  }

  @override
  String get diveLog_profileEditor_noProfileData =>
      'لا تتوفر بيانات ملف الغوصة';

  @override
  String get diveLog_profileEditor_undo => 'تراجع';

  @override
  String get diveLog_profileEditor_mode_select => 'تحديد';

  @override
  String get diveLog_profileEditor_mode_outlier => 'قيمة شاذة';

  @override
  String get diveLog_profileEditor_mode_draw => 'رسم';

  @override
  String get diveLog_profileEditor_mode_trim => 'قص';

  @override
  String diveLog_sources_sectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مصادر البيانات',
      many: 'مصادر البيانات',
      few: 'مصادر البيانات',
      two: 'مصدرا البيانات',
      one: 'مصدر البيانات',
      zero: 'مصدر البيانات',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_badge_manual => 'يدوي';

  @override
  String get diveLog_sources_badge_viewing => 'قيد العرض';

  @override
  String get diveLog_sources_badge_secondary => 'ثانوي';

  @override
  String diveLog_sources_created(String date) {
    return 'أُنشئ في $date';
  }

  @override
  String get diveLog_sources_detail_serial => 'الرقم التسلسلي';

  @override
  String get diveLog_sources_detail_format => 'الصيغة';

  @override
  String get diveLog_sources_detail_imported => 'تاريخ الاستيراد';

  @override
  String diveLog_detail_semantics_viewDiveComputer(String name) {
    return 'عرض حاسوب الغوص $name';
  }

  @override
  String diveLog_detail_semantics_viewTrip(String name) {
    return 'عرض الرحلة $name';
  }

  @override
  String diveLog_detail_semantics_viewDiveCenter(String name) {
    return 'عرض مركز الغوص $name';
  }

  @override
  String diveLog_detail_semantics_viewSpecies(String name) {
    return 'عرض النوع $name';
  }

  @override
  String diveLog_detail_semantics_viewCourse(String name) {
    return 'عرض الدورة $name';
  }

  @override
  String diveLog_detail_serialNumber(String serial) {
    return 'S/N $serial';
  }

  @override
  String diveLog_detail_errorLoadingSignature(String error) {
    return 'خطأ في تحميل التوقيع: $error';
  }

  @override
  String get diveLog_profilePanel_selectDive => 'اختر غوصة لعرض ملفها';

  @override
  String get diveLog_profilePanel_noProfileData =>
      'لا توجد بيانات ملف لهذه الغوصة';

  @override
  String get settings_export_progress_divesCsv =>
      'جارٍ تصدير الغوصات إلى CSV...';

  @override
  String get settings_export_progress_sitesCsv =>
      'جارٍ تصدير المواقع إلى CSV...';

  @override
  String get settings_export_progress_equipmentCsv =>
      'جارٍ تصدير المعدات إلى CSV...';

  @override
  String get settings_export_progress_pdf =>
      'جارٍ إنشاء سجل الغوص بصيغة PDF...';

  @override
  String get settings_export_progress_loadingSignatures =>
      'جارٍ تحميل التوقيعات...';

  @override
  String get settings_export_progress_loadingCertifications =>
      'جارٍ تحميل الشهادات...';

  @override
  String get settings_export_progress_loadingFonts => 'جارٍ تحميل الخطوط...';

  @override
  String settings_export_progress_templatePdf(String template) {
    return 'جارٍ إنشاء ملف PDF بقالب $template...';
  }

  @override
  String get settings_export_progress_uddf => 'جارٍ إنشاء ملف UDDF...';

  @override
  String get settings_export_progress_collectingData =>
      'جارٍ جمع كل البيانات...';

  @override
  String get settings_export_progress_excel => 'جارٍ إنشاء ملف Excel...';

  @override
  String get settings_export_progress_buildingExcel =>
      'جارٍ بناء مصنّف Excel...';

  @override
  String get settings_export_progress_kml => 'جارٍ إنشاء ملف KML...';

  @override
  String get settings_export_progress_buildingKml => 'جارٍ بناء ملف KML...';

  @override
  String get settings_export_progress_preparingExcel =>
      'جارٍ تحضير ملف Excel...';

  @override
  String get settings_export_progress_preparingKml => 'جارٍ تحضير ملف KML...';

  @override
  String get settings_export_progress_chooseLocation => 'اختر موقع الحفظ...';

  @override
  String get settings_export_progress_preparingDivesCsv =>
      'جارٍ تحضير ملف CSV للغوصات...';

  @override
  String get settings_export_progress_preparingSitesCsv =>
      'جارٍ تحضير ملف CSV للمواقع...';

  @override
  String get settings_export_progress_preparingEquipmentCsv =>
      'جارٍ تحضير ملف CSV للمعدات...';

  @override
  String get settings_export_progress_preparingUddf => 'جارٍ تحضير ملف UDDF...';

  @override
  String get settings_export_progress_preparingPdf => 'جارٍ تحضير ملف PDF...';

  @override
  String get settings_export_progress_selectingBackup =>
      'جارٍ اختيار ملف النسخة الاحتياطية...';

  @override
  String get settings_export_progress_restoringBackup =>
      'جارٍ الاستعادة من النسخة الاحتياطية...';

  @override
  String get settings_export_empty_dives => 'لا توجد غوصات للتصدير';

  @override
  String get settings_export_empty_sites => 'لا توجد مواقع للتصدير';

  @override
  String get settings_export_empty_equipment => 'لا توجد معدات للتصدير';

  @override
  String get settings_export_empty_data => 'لا توجد بيانات للتصدير';

  @override
  String get settings_export_empty_diveSites => 'لا توجد مواقع غوص للتصدير';

  @override
  String settings_export_saveFailed(String error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String settings_export_backupFailed(String error) {
    return 'فشل النسخ الاحتياطي: $error';
  }

  @override
  String settings_export_restoreFailed(String error) {
    return 'فشلت الاستعادة: $error';
  }

  @override
  String get settings_export_fileUnreadable => 'تعذّر الوصول إلى الملف';

  @override
  String get settings_export_notADbFile =>
      'يُرجى اختيار ملف نسخة احتياطية بامتداد .db';

  @override
  String get settings_export_success_dives => 'تم تصدير الغوصات بنجاح';

  @override
  String get settings_export_success_sites => 'تم تصدير المواقع بنجاح';

  @override
  String get settings_export_success_equipment => 'تم تصدير المعدات بنجاح';

  @override
  String get settings_export_success_pdf =>
      'تم إنشاء سجل الغوص بصيغة PDF بنجاح';

  @override
  String get settings_export_success_uddf => 'تم إنشاء ملف UDDF بنجاح';

  @override
  String get settings_export_success_excel => 'تم تصدير ملف Excel بنجاح';

  @override
  String settings_export_success_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تصدير ملف KML بنجاح (تم تخطي $count موقع بلا إحداثيات)',
      many: 'تم تصدير ملف KML بنجاح (تم تخطي $count موقعًا بلا إحداثيات)',
      few: 'تم تصدير ملف KML بنجاح (تم تخطي $count مواقع بلا إحداثيات)',
      two: 'تم تصدير ملف KML بنجاح (تم تخطي موقعين بلا إحداثيات)',
      one: 'تم تصدير ملف KML بنجاح (تم تخطي موقع واحد بلا إحداثيات)',
      zero: 'تم تصدير ملف KML بنجاح',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_excel => 'تم حفظ ملف Excel بنجاح';

  @override
  String settings_export_saved_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حفظ ملف KML بنجاح (تم تخطي $count موقع بلا إحداثيات)',
      many: 'تم حفظ ملف KML بنجاح (تم تخطي $count موقعًا بلا إحداثيات)',
      few: 'تم حفظ ملف KML بنجاح (تم تخطي $count مواقع بلا إحداثيات)',
      two: 'تم حفظ ملف KML بنجاح (تم تخطي موقعين بلا إحداثيات)',
      one: 'تم حفظ ملف KML بنجاح (تم تخطي موقع واحد بلا إحداثيات)',
      zero: 'تم حفظ ملف KML بنجاح',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_divesCsv => 'تم حفظ ملف CSV للغوصات بنجاح';

  @override
  String get settings_export_saved_sitesCsv => 'تم حفظ ملف CSV للمواقع بنجاح';

  @override
  String get settings_export_saved_equipmentCsv =>
      'تم حفظ ملف CSV للمعدات بنجاح';

  @override
  String get settings_export_saved_uddf => 'تم حفظ ملف UDDF بنجاح';

  @override
  String get settings_export_saved_pdf => 'تم حفظ ملف PDF بنجاح';

  @override
  String get settings_export_saved_backup => 'تم حفظ النسخة الاحتياطية بنجاح';

  @override
  String get settings_export_restoreComplete => 'اكتملت الاستعادة';

  @override
  String get settings_export_cancelled_save => 'تم إلغاء الحفظ';

  @override
  String get settings_export_cancelled_backup => 'تم إلغاء النسخ الاحتياطي';

  @override
  String get settings_export_cancelled_restore => 'تم إلغاء الاستعادة';

  @override
  String get settings_export_pdfDocumentTitle => 'سجل الغوص';

  @override
  String get settings_export_saveBackupDialogTitle => 'حفظ النسخة الاحتياطية';

  @override
  String backup_operation_created(String size) {
    return 'تم إنشاء نسخة احتياطية: $size';
  }

  @override
  String backup_operation_backupFailed(String error) {
    return 'فشل النسخ الاحتياطي: $error';
  }

  @override
  String get backup_operation_restoring => 'جارٍ استعادة النسخة الاحتياطية...';

  @override
  String backup_operation_restoreFailed(String error) {
    return 'فشلت الاستعادة: $error';
  }

  @override
  String get backup_operation_deleting => 'جارٍ حذف النسخة الاحتياطية...';

  @override
  String get backup_operation_deleted => 'تم حذف النسخة الاحتياطية';

  @override
  String backup_operation_deleteFailed(String error) {
    return 'فشل الحذف: $error';
  }

  @override
  String get backup_operation_exporting => 'جارٍ تصدير النسخة الاحتياطية...';

  @override
  String backup_operation_exported(String size) {
    return 'تم تصدير النسخة الاحتياطية: $size';
  }

  @override
  String backup_operation_exportFailed(String error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get backup_operation_preparingShare =>
      'جارٍ تحضير النسخة الاحتياطية للمشاركة...';

  @override
  String get backup_operation_shareReady => 'النسخة الاحتياطية جاهزة للمشاركة';

  @override
  String backup_operation_upgrading(int step, int total) {
    return 'جارٍ ترقية قاعدة البيانات (الخطوة $step من $total)...';
  }

  @override
  String backup_restore_dialog_counts(int diveCount, int siteCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount غوصة',
      many: '$diveCount غوصة',
      few: '$diveCount غوصات',
      two: 'غوصتان',
      one: 'غوصة واحدة',
      zero: '$diveCount غوصة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      siteCount,
      locale: localeName,
      other: '$siteCount موقع',
      many: '$siteCount موقعًا',
      few: '$siteCount مواقع',
      two: 'موقعان',
      one: 'موقع واحد',
      zero: '$siteCount موقع',
    );
    return '$_temp0، $_temp1';
  }

  @override
  String get backup_restore_preMigration_title =>
      'استعادة نسخة احتياطية سابقة للترحيل';

  @override
  String get backup_restore_preMigration_unknownVersion => 'إصدار غير معروف';

  @override
  String get backup_restore_preMigration_restoreAnyway => 'استعادة على أي حال';

  @override
  String backup_restore_preMigration_incompleteMetadata(
    String timestamp,
    String appVersion,
  ) {
    return 'أُنشئت هذه النسخة الاحتياطية في $timestamp بواسطة إصدار التطبيق $appVersion، لكن بياناتها الوصفية الخاصة بترحيل قاعدة البيانات غير مكتملة.\n\nلا يستطيع التطبيق التحقق مما إذا كانت استعادة هذه النسخة الاحتياطية آمنة، لذا فإن الاستعادة معطّلة.';
  }

  @override
  String backup_restore_preMigration_newerApp(
    String timestamp,
    String appVersion,
    int fromVersion,
  ) {
    return 'هذه النسخة الاحتياطية أحدث من تطبيقك. ثبّت إصدارًا أحدث من التطبيق لاستعادتها.\n\nأُنشئت النسخة الاحتياطية في $timestamp بواسطة إصدار التطبيق $appVersion (قاعدة البيانات v$fromVersion).';
  }

  @override
  String backup_restore_preMigration_safe(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
  ) {
    return 'أُنشئت هذه النسخة الاحتياطية في $timestamp بواسطة إصدار التطبيق $appVersion، قبل ترقية قاعدة البيانات من v$fromVersion إلى v$toVersion مباشرة.\n\nمخطط قاعدة بيانات تطبيقك يطابق هذه النسخة الاحتياطية، لذا فإن الاستعادة آمنة.';
  }

  @override
  String backup_restore_preMigration_warning(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
    int currentVersion,
  ) {
    return 'أُنشئت هذه النسخة الاحتياطية في $timestamp بواسطة إصدار التطبيق $appVersion، قبل ترقية قاعدة البيانات من v$fromVersion إلى v$toVersion مباشرة.\n\nأنت تستخدم تطبيقًا أحدث (قاعدة البيانات v$currentVersion).\n\nالاستعادة الآن ستعيد تشغيل ترقية قاعدة البيانات v$fromVersion → v$toVersion على بياناتك المستعادة: وهي نفس الترقية التي كانت على وشك التشغيل في الأصل. فإذا كانت تلك الترقية هي سبب المشكلة، فستواجه المشكلة نفسها مرة أخرى.\n\nللاستعادة بأمان: ثبّت التطبيق بالإصدار $appVersion أو أقدم، ثم استعد هذه النسخة الاحتياطية من ذلك التطبيق الأقدم.';
  }

  @override
  String get settings_cloudSync_progress_preparing => 'جارٍ تحضير المزامنة...';

  @override
  String get settings_cloudSync_progress_pulling => 'جارٍ سحب التغييرات...';

  @override
  String get settings_cloudSync_progress_publishing => 'جارٍ نشر التغييرات...';

  @override
  String settings_cloudSync_progress_uploadingLibrary(int uploaded, int total) {
    return 'جارٍ رفع المكتبة ($uploaded من $total)';
  }

  @override
  String get settings_cloudSync_result_noProvider =>
      'لم يتم إعداد أي مزود تخزين سحابي';

  @override
  String get settings_cloudSync_result_notAuthenticated =>
      'لم تتم المصادقة مع مزود التخزين السحابي';

  @override
  String get settings_cloudSync_result_timedOut => 'انتهت مهلة المزامنة';

  @override
  String get settings_cloudSync_result_epochMarkerUnreadable =>
      'تعذّرت قراءة علامة حقبة المكتبة';

  @override
  String get settings_cloudSync_result_epochMarkerEncrypted =>
      'علامة حقبة المكتبة مشفّرة';

  @override
  String get settings_cloudSync_result_libraryReplacedRemotely =>
      'تم استبدال مكتبة السحابة من نسخة احتياطية';

  @override
  String get settings_cloudSync_result_noReplacementToRebuild =>
      'لا يوجد استبدال للمكتبة يمكن إعادة البناء منه';

  @override
  String get settings_cloudSync_result_rebuiltFromThisDevice =>
      'تمت إعادة بناء هذه الخدمة من مكتبة هذا الجهاز';

  @override
  String settings_cloudSync_result_rebuildFailed(String error) {
    return 'فشلت إعادة البناء: $error';
  }

  @override
  String get settings_cloudSync_result_libraryReplaced => 'تم استبدال المكتبة';

  @override
  String settings_cloudSync_result_libraryReplaceFailed(String error) {
    return 'فشل استبدال المكتبة: $error';
  }

  @override
  String get settings_cloudSync_result_noReplacementMarker =>
      'لم يتم العثور على علامة استبدال المكتبة';

  @override
  String get settings_cloudSync_result_adoptedRestoredLibrary =>
      'تم اعتماد المكتبة المستعادة';

  @override
  String settings_cloudSync_result_adoptFailed(String error) {
    return 'فشل اعتماد المكتبة المستعادة: $error';
  }

  @override
  String get settings_cloudSync_result_previousLibraryUnreadable =>
      'تعذّرت قراءة المكتبة السابقة؛ وأُعيد إنشاء هذه الخدمة من مكتبة هذا الجهاز.';

  @override
  String get settings_cloudSync_result_replacementStillUploading =>
      'لا يزال رفع المكتبة المستبدَلة جاريًا. حاول مرة أخرى بعد قليل.';

  @override
  String settings_cloudSync_result_recordsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فشل تطبيق $count سجل',
      many: 'فشل تطبيق $count سجلًا',
      few: 'فشل تطبيق $count سجلات',
      two: 'فشل تطبيق سجلين',
      one: 'فشل تطبيق سجل واحد',
      zero: 'فشل تطبيق $count سجل',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_result_adoptedFreshIdentity =>
      'كان جهاز آخر يتزامن باستخدام هوية هذا الجهاز. اعتمد هذا الجهاز هوية جديدة ودمج بيانات السحابة.';

  @override
  String settings_cloudSync_launchCheck_unavailable(String provider) {
    return '$provider غير متاح على هذا الجهاز';
  }

  @override
  String settings_cloudSync_launchCheck_notSignedIn(String provider) {
    return 'لم يتم تسجيل الدخول إلى $provider';
  }

  @override
  String settings_cloudSync_launchCheck_localChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغيير محلي بانتظار الرفع',
      many: '$count تغييرًا محليًا بانتظار الرفع',
      few: '$count تغييرات محلية بانتظار الرفع',
      two: 'تغييران محليان بانتظار الرفع',
      one: 'تغيير محلي واحد بانتظار الرفع',
      zero: '$count تغيير محلي بانتظار الرفع',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_launchCheck_noRemoteData =>
      'لم يتم العثور على بيانات مزامنة في السحابة';

  @override
  String get settings_cloudSync_launchCheck_cloudDataAvailable =>
      'بيانات السحابة متاحة';

  @override
  String get settings_cloudSync_launchCheck_updatesAvailable =>
      'تتوفر تحديثات من السحابة';

  @override
  String get settings_cloudSync_launchCheck_upToDate => 'كل شيء محدّث';

  @override
  String settings_cloudSync_launchCheck_failed(String error) {
    return 'فشل التحقق من المزامنة: $error';
  }

  @override
  String get diveLog_detail_viewMap => 'خريطة';

  @override
  String get diveLog_detail_view3d => '3D';

  @override
  String get setup_sync_icloudUnavailable => 'iCloud غير متاح على هذا الجهاز';

  @override
  String get media_info_title => 'معلومات الوسائط';

  @override
  String get media_info_fileSection => 'الملف';

  @override
  String get media_info_filename => 'اسم الملف';

  @override
  String get media_info_type => 'النوع';

  @override
  String get media_info_dimensions => 'الأبعاد';

  @override
  String get media_info_size => 'الحجم';

  @override
  String get media_info_taken => 'تاريخ الالتقاط';

  @override
  String get media_info_coordinates => 'الإحداثيات';

  @override
  String get media_info_unknown => 'غير معروف';

  @override
  String get media_info_originSection => 'المصدر';

  @override
  String get media_info_source => 'المصدر';

  @override
  String get media_info_reference => 'المرجع';

  @override
  String get media_info_linkedOn => 'تم الربط على';

  @override
  String get media_info_thisDevice => 'هذا الجهاز';

  @override
  String get media_info_otherDevice => 'جهاز آخر';

  @override
  String get media_info_status => 'الحالة';

  @override
  String get media_info_statusFound => 'موجود على هذا الجهاز';

  @override
  String get media_info_statusMissing => 'غير موجود على هذا الجهاز';

  @override
  String get media_info_statusUnchecked => 'لم يتم التحقق بعد';

  @override
  String media_info_lastChecked(String date) {
    return 'آخر فحص $date';
  }

  @override
  String get media_timeInDive_label => 'الوقت في الغوصة';

  @override
  String get media_timeInDive_unknown => 'الوقت في الغوصة غير معروف';

  @override
  String get media_timeInDive_setAction => 'تعيين الوقت في الغوصة';

  @override
  String media_timeInDive_manual(String time) {
    return '$time (تم تعيينه يدويًا)';
  }

  @override
  String get media_timeInDive_fieldLabel => 'الوقت من بداية الغوصة';

  @override
  String get media_timeInDive_fieldHint => 'mm:ss';

  @override
  String media_timeInDive_range(String max) {
    return 'بين 0:00 و $max';
  }

  @override
  String media_timeInDive_invalid(String max) {
    return 'أدخل وقتًا بين 0:00 و $max';
  }

  @override
  String get media_timeInDive_save => 'حفظ';

  @override
  String get media_timeInDive_cancel => 'إلغاء';

  @override
  String get media_timeInDive_reset => 'إعادة التعيين إلى التلقائي';

  @override
  String get media_info_backupSection => 'النسخ الاحتياطي';

  @override
  String get media_info_store => 'التخزين السحابي';

  @override
  String get media_info_storeNotConnected => 'لا يوجد تخزين سحابي متصل';

  @override
  String get media_info_notEligible => 'هذا المصدر غير مؤهل للنسخ الاحتياطي';

  @override
  String get media_info_backupFull => 'تم رفع الأصل';

  @override
  String get media_info_backupThumbOnly => 'صورة مصغرة فقط، لم يتم إرسال الأصل';

  @override
  String get media_info_backupRenditionOnly => 'تم رفع النسخة المضغوطة';

  @override
  String get media_info_backupNone => 'لا يوجد نسخ احتياطي';

  @override
  String media_info_uploadedOn(String date) {
    return 'تم الرفع $date';
  }

  @override
  String get media_info_queuePending => 'في انتظار الرفع';

  @override
  String get media_info_queueTransferring => 'جارٍ الرفع الآن';

  @override
  String media_info_queueFailed(Object error) {
    return 'فشل الرفع: $error';
  }

  @override
  String get media_info_servingSection => 'المصدر الحالي';

  @override
  String get media_info_servingUnobserved => 'لم يتم التحميل بعد';

  @override
  String get media_info_servingFailed => 'تعذر التحميل';

  @override
  String get media_info_servedLocalDisk => 'ملف محلي على هذا الجهاز';

  @override
  String get media_info_servedGallery => 'مكتبة الصور';

  @override
  String get media_info_servedStoreCache =>
      'ذاكرة تخزين محلية، من التخزين السحابي';

  @override
  String get media_info_servedStoreNetwork => 'تم تنزيله من التخزين السحابي';

  @override
  String get media_info_servedNetworkUrl => 'بث من رابط';

  @override
  String get media_info_servedConnectorCache =>
      'ذاكرة تخزين محلية، من الخدمة المتصلة';

  @override
  String get media_info_servedConnectorNetwork => 'تم تنزيله من الخدمة المتصلة';

  @override
  String get media_info_servedEmbedded => 'مخزن داخل هذا السجل';

  @override
  String get media_info_servingFallbackNote =>
      'تعذر الوصول إلى المصدر الأصلي، لذلك تم التقديم من التخزين السحابي.';

  @override
  String get media_info_servingTierThumbnail => 'صورة مصغرة';

  @override
  String get media_info_servingTierRendition => 'نسخة مضغوطة';

  @override
  String get media_info_typePhoto => 'صورة';

  @override
  String get media_info_typeVideo => 'فيديو';

  @override
  String get media_info_typeDocument => 'مستند';

  @override
  String get media_info_typeSignature => 'توقيع';

  @override
  String get media_info_actionCheckNow => 'تحقق الآن';

  @override
  String get media_info_actionLocate => 'تحديد موقع الملف...';

  @override
  String get media_info_actionBackUpNow => 'انسخ احتياطيًا الآن';

  @override
  String get media_info_actionRetryUpload => 'إعادة محاولة الرفع';

  @override
  String get media_info_actionReveal => 'إظهار في مدير الملفات';

  @override
  String get media_info_actionCopyPath => 'نسخ المرجع';

  @override
  String get media_info_referenceCopied => 'تم نسخ المرجع';

  @override
  String get media_info_checkFound => 'تم العثور على المصدر';

  @override
  String get media_info_checkMissing => 'المصدر مفقود';

  @override
  String get media_info_checkUnavailable => 'تعذر التحقق الآن';

  @override
  String get media_info_backupQueued => 'في قائمة انتظار الرفع';

  @override
  String get enum_profileMetric_o2CellMv => 'خلايا الأكسجين';

  @override
  String get enum_profileMetric_o2CellMv_short => 'الخلايا';

  @override
  String get diveLog_o2CellSpread_label => 'تشتت خلايا O2';

  @override
  String get media_status_broken => 'مفقود وغير منسوخ احتياطيًا';

  @override
  String get media_servedFrom_localDisk => 'على هذا الجهاز';

  @override
  String get media_servedFrom_platformGallery => 'مكتبة الصور';

  @override
  String get media_servedFrom_storeCache => 'تخزين سحابي، مخزن مؤقتا هنا';

  @override
  String get media_servedFrom_storeNetwork => 'تخزين سحابي';

  @override
  String get media_servedFrom_networkUrl => 'رابط ويب';

  @override
  String get media_servedFrom_connectorCache => 'خدمة متصلة، مخزنة مؤقتا هنا';

  @override
  String get media_servedFrom_connectorNetwork => 'خدمة متصلة';

  @override
  String get media_servedFrom_embedded => 'محفوظ في سجل الغوص هذا';

  @override
  String get settings_media_provenanceBadges =>
      'إظهار شارات المصدر على الصور المصغرة';

  @override
  String get settings_media_provenanceBadgesSubtitle =>
      'رمز صغير يوضح مصدر كل عنصر. تظهر شارات المشكلات دائما.';

  @override
  String get media_status_transferFailed => 'فشل الرفع';

  @override
  String get media_status_transferring => 'جارٍ الرفع';

  @override
  String get media_status_queued => 'في انتظار الرفع';

  @override
  String get media_status_cloudOnly => 'مخزن في السحابة فقط';

  @override
  String get media_status_notBackedUp => 'لا يوجد نسخ احتياطي';

  @override
  String get media_tile_infoMenuItem => 'معلومات الوسائط';

  @override
  String get diveImport_healthkit_accessGrantedHint =>
      'لا يخبر تطبيق صحة Apple التطبيقات أبدًا بما إذا كان قد تم منح إذن القراءة. إذا لم تظهر أي غطسات، افتح تطبيق صحة ثم المشاركة ثم التطبيقات ثم Submersion، وفعّل التمارين وعمق الغوص ودرجة حرارة الماء ومعدل ضربات القلب.';

  @override
  String get diveImport_healthkit_foundNoDivesHint =>
      'لا توجد تمارين غوص في هذا النطاق. تأكد من أن التواريخ تغطي الغطسة، ومن تفعيل التمارين وعمق الغوص في تطبيق صحة ضمن المشاركة ثم التطبيقات ثم Submersion.';

  @override
  String get settings_dataSources_appleHealth_dataTypeDepth =>
      'عمق الغوص - عينات العمق المسجلة أثناء الغطسات';

  @override
  String get settings_dataSources_appleHealth_dataTypeWaterTemp =>
      'درجة حرارة الماء - عينات درجة الحرارة المسجلة أثناء الغطسات';

  @override
  String get settings_dataSources_appleHealth_permissionManagedInHealth =>
      'تتم إدارة وصول HealthKit من تطبيق صحة';

  @override
  String get settings_dataSources_appleHealth_permissionUnsupported =>
      'HealthKit غير متوفر على هذا الجهاز';
}
