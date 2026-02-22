// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

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
  String get backup_restore_dialog_cancel => 'إلغاء';

  @override
  String get backup_restore_dialog_restore => 'استعادة';

  @override
  String get backup_restore_dialog_safetyNote =>
      'سيتم إنشاء نسخة احتياطية آمنة من بياناتك الحالية تلقائياً قبل الاستعادة.';

  @override
  String get backup_restore_dialog_title => 'استعادة النسخة الاحتياطية';

  @override
  String get backup_restore_dialog_warning =>
      'سيؤدي هذا إلى استبدال جميع البيانات الحالية ببيانات النسخة الاحتياطية. لا يمكن التراجع عن هذا الإجراء.';

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
  String get buddies_picker_addNew => 'إضافة رفيق جديد';

  @override
  String get buddies_picker_done => 'تم';

  @override
  String get buddies_picker_noBuddiesFound => 'لم يتم العثور على رفاق';

  @override
  String get buddies_picker_noBuddiesYet => 'لا يوجد رفاق بعد';

  @override
  String get buddies_picker_noneSelected => 'لم يتم تحديد رفاق';

  @override
  String get buddies_picker_searchHint => 'البحث عن الرفاق...';

  @override
  String get buddies_picker_selectBuddies => 'اختيار الرفاق';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'اختر دور $name';
  }

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
  String get certifications_detail_label_expiryDate => 'تاريخ الانتهاء';

  @override
  String get certifications_detail_label_instructorName => 'الاسم';

  @override
  String get certifications_detail_label_instructorNumber => 'رقم المدرب';

  @override
  String get certifications_detail_label_issueDate => 'تاريخ الإصدار';

  @override
  String get certifications_detail_label_level => 'المستوى';

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
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'معتمد من $agency';
  }

  @override
  String get certifications_ecard_label_instructor => 'المدرب';

  @override
  String get certifications_ecard_label_issued => 'تاريخ الإصدار';

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
  String get certifications_edit_help_expiryDate =>
      'اتركه فارغاً للشهادات التي لا تنتهي صلاحيتها';

  @override
  String get certifications_edit_hint_cardNumber => 'أدخل رقم بطاقة الشهادة';

  @override
  String get certifications_edit_hint_certificationName =>
      'مثال: غواص مياه مفتوحة';

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
  String get certifications_edit_label_certificationName => 'اسم الشهادة *';

  @override
  String get certifications_edit_label_expiryDate => 'تاريخ الانتهاء';

  @override
  String get certifications_edit_label_instructorName => 'اسم المدرب';

  @override
  String get certifications_edit_label_instructorNumber => 'رقم المدرب';

  @override
  String get certifications_edit_label_issueDate => 'تاريخ الإصدار';

  @override
  String get certifications_edit_label_level => 'المستوى';

  @override
  String get certifications_edit_label_notes => 'ملاحظات';

  @override
  String get certifications_edit_level_notSpecified => 'غير محدد';

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
  String get certifications_edit_validation_nameRequired =>
      'يرجى إدخال اسم الشهادة';

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
  String certifications_walletCard_countPlural(Object count) {
    return '$count شهادات';
  }

  @override
  String certifications_walletCard_countSingular(Object count) {
    return '$count شهادة';
  }

  @override
  String get certifications_walletCard_emptyFooter => 'أضف شهادتك الأولى';

  @override
  String get certifications_walletCard_error => 'فشل في تحميل الشهادات';

  @override
  String get certifications_walletCard_semanticLabel =>
      'محفظة الشهادات. انقر لعرض جميع الشهادات';

  @override
  String get certifications_walletCard_tapToAdd => 'انقر للإضافة';

  @override
  String get certifications_walletCard_title => 'محفظة الشهادات';

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
  String get common_action_back => 'رجوع';

  @override
  String get common_action_cancel => 'إلغاء';

  @override
  String get common_action_close => 'إغلاق';

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
  String get common_label_error => 'خطأ';

  @override
  String get common_label_loading => 'جارٍ التحميل';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get courses_action_add => 'إضافة دورة';

  @override
  String get courses_action_create => 'إنشاء دورة';

  @override
  String get courses_action_edit => 'تعديل الدورة';

  @override
  String get courses_action_exportTrainingLog => 'تصدير سجل التدريب';

  @override
  String get courses_action_markCompleted => 'وضع علامة كمكتمل';

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
  String get courses_field_selectFromBuddies => 'اختر من الرفاق (اختياري)';

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
  String get courses_label_none => '-- لا شيء --';

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
  String get courses_section_details => 'تفاصيل الدورة';

  @override
  String get courses_section_earnedCertification => 'الاعتماد المكتسب';

  @override
  String get courses_section_instructor => 'المدرب';

  @override
  String get courses_section_notes => 'ملاحظات';

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
  String get diveCenters_summary_topRated => 'الأعلى تقييماً';

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
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_tts => 'TTS';

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
  String get diveLog_deco_title => 'حالة تخفيف الضغط';

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
  String get diveLog_detail_button_rangeAnalysis => 'تحليل النطاق';

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
  String get diveLog_detail_fullscreen_sampleData => 'بيانات العينة';

  @override
  String get diveLog_detail_fullscreen_tapChartCompact =>
      'اضغط على المخطط للعرض المدمج';

  @override
  String get diveLog_detail_fullscreen_tapChartFull =>
      'اضغط على المخطط للعرض بملء الشاشة';

  @override
  String get diveLog_detail_fullscreen_touchChart =>
      'المس المخطط لرؤية البيانات عند تلك النقطة';

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
  String get diveLog_detail_section_decoStatus => 'حالة تخفيف الضغط';

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
  String get diveLog_detail_section_sacByCylinder => 'SAC حسب الأسطوانة';

  @override
  String get diveLog_detail_section_sacRateBySegment => 'معدل SAC حسب القطاع';

  @override
  String get diveLog_detail_section_tags => 'الوسوم';

  @override
  String get diveLog_detail_section_tanks => 'الأسطوانات';

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
  String diveLog_detail_tankCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أسطوانات',
      one: 'أسطوانة',
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
  String get diveLog_edit_headerNew => 'تسجيل غوصة جديدة';

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
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'تم حساب وقت القاع: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'خطأ في حفظ الغوصة: $error';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'لا تتوفر بيانات ملف الغوصة';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'تعذر حساب وقت القاع من الملف';

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
  String get diveLog_filter_noTagsYet => 'لم يتم إنشاء وسوم بعد';

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
  String get diveLog_filter_showOnlyFavorites => 'عرض الغوصات المفضلة فقط';

  @override
  String get diveLog_filter_startDate => 'تاريخ البدء';

  @override
  String get diveLog_filter_title => 'تصفية الغوصات';

  @override
  String get diveLog_filter_tooltip_close => 'إغلاق التصفية';

  @override
  String get diveLog_fullscreenProfile_close => 'إغلاق ملء الشاشة';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'ملف الغوصة #$number';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'معدل الصعود';

  @override
  String get diveLog_legend_label_ceiling => 'السقف';

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
  String get diveLog_legend_label_surfaceGf => 'GF السطح';

  @override
  String get diveLog_legend_label_temp => 'الحرارة';

  @override
  String get diveLog_legend_label_tts => 'TTS';

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
  String get diveLog_listPage_searchFieldLabel => 'البحث في الغوصات...';

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
  String get diveLog_profileSelector_badge_primary => 'أساسي';

  @override
  String get diveLog_profileSelector_label_diveComputers => 'حواسيب الغوص';

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
  String get diveLog_rangeStats_header_avg => 'متوسط';

  @override
  String get diveLog_rangeStats_header_max => 'أقصى';

  @override
  String get diveLog_rangeStats_header_min => 'أدنى';

  @override
  String get diveLog_rangeStats_label_depth => 'العمق';

  @override
  String get diveLog_rangeStats_label_heartRate => 'معدل نبض القلب';

  @override
  String get diveLog_rangeStats_label_pressure => 'الضغط';

  @override
  String get diveLog_rangeStats_label_temp => 'الحرارة';

  @override
  String get diveLog_rangeStats_title => 'تحليل النطاق';

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
  String get diveLog_search_gasTrimix => 'ترايمكس (<21% O₂)';

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
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String get diveLog_tank_section_gasMix => 'خليط الغاز';

  @override
  String get diveLog_tank_selectPreset => 'اختر إعداداً مسبقاً...';

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
  String get diveLog_tooltip_ceiling => 'السقف';

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
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'الحرارة';

  @override
  String get diveLog_tooltip_time => 'الوقت';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get divePlanner_action_addTank => 'إضافة أسطوانة';

  @override
  String get divePlanner_action_convertToDive => 'تحويل إلى غطسة';

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
  String get divePlanner_label_runtime => 'وقت التشغيل';

  @override
  String get divePlanner_label_sacRate => 'معدل SAC:';

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
  String get diveSites_edit_appBar_newSite => 'موقع جديد';

  @override
  String get diveSites_edit_appBar_save => 'حفظ';

  @override
  String get diveSites_edit_button_addSite => 'إضافة موقع';

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
  String get diveSites_edit_gps_gettingLocation => 'جارٍ الحصول على الموقع...';

  @override
  String get diveSites_edit_gps_helperText =>
      'اختر طريقة تحديد الموقع - سيتم ملء الدولة والمنطقة تلقائياً';

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
    return '$min-$maxم';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'حتى $maxم';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '$minم+';
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
    return 'هل أنت متأكد أنك تريد حذف $name؟ سيتم إلغاء تعيين جميع سجلات الغوص المرتبطة.';
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
  String get enum_buddyRole_buddy => 'زميل غوص';

  @override
  String get enum_buddyRole_diveGuide => 'مرشد غوص';

  @override
  String get enum_buddyRole_diveMaster => 'مدرب غوص رئيسي';

  @override
  String get enum_buddyRole_instructor => 'مدرب';

  @override
  String get enum_buddyRole_solo => 'منفرد';

  @override
  String get enum_buddyRole_student => 'طالب';

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
  String get enum_profileEvent_descentEnd => 'نهاية النزول';

  @override
  String get enum_profileEvent_descentStart => 'بداية النزول';

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
  String get equipment_addSheet_brandHint => 'مثال: Scubapro';

  @override
  String get equipment_addSheet_brandLabel => 'العلامة التجارية';

  @override
  String get equipment_addSheet_closeTooltip => 'إغلاق';

  @override
  String get equipment_addSheet_currencyLabel => 'العملة';

  @override
  String get equipment_addSheet_dateLabel => 'التاريخ';

  @override
  String equipment_addSheet_errorSnackbar(Object error) {
    return 'خطأ في إضافة المعدات: $error';
  }

  @override
  String get equipment_addSheet_modelHint => 'مثال: MK25 EVO';

  @override
  String get equipment_addSheet_modelLabel => 'الطراز';

  @override
  String get equipment_addSheet_nameHint => 'مثال: منظم الغوص الرئيسي';

  @override
  String get equipment_addSheet_nameLabel => 'الاسم';

  @override
  String get equipment_addSheet_nameValidation => 'يرجى إدخال اسم';

  @override
  String get equipment_addSheet_notesHint => 'ملاحظات إضافية...';

  @override
  String get equipment_addSheet_notesLabel => 'ملاحظات';

  @override
  String get equipment_addSheet_priceLabel => 'السعر';

  @override
  String get equipment_addSheet_purchaseInfoTitle => 'معلومات الشراء';

  @override
  String get equipment_addSheet_serialNumberLabel => 'الرقم التسلسلي';

  @override
  String get equipment_addSheet_serviceIntervalHint =>
      'مثال: 365 للصيانة السنوية';

  @override
  String get equipment_addSheet_serviceIntervalLabel =>
      'فترة الصيانة (بالأيام)';

  @override
  String get equipment_addSheet_sizeHint => 'مثال: M, L, 42';

  @override
  String get equipment_addSheet_sizeLabel => 'المقاس';

  @override
  String get equipment_addSheet_submitButton => 'إضافة معدات';

  @override
  String get equipment_addSheet_successSnackbar => 'تمت إضافة المعدات بنجاح';

  @override
  String get equipment_addSheet_title => 'إضافة معدات';

  @override
  String get equipment_addSheet_typeLabel => 'النوع';

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
  String get equipment_edit_typeLabel => 'النوع *';

  @override
  String get equipment_edit_useCustomReminders => 'استخدام تذكيرات مخصصة';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'تعيين أيام تذكير مختلفة لهذا العنصر';

  @override
  String get equipment_fab_addEquipment => 'إضافة معدات';

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
  String get gasCalculators_ppO2Limit => 'حد ppO₂';

  @override
  String get gasCalculators_resetAll => 'إعادة تعيين جميع الحاسبات';

  @override
  String get gasCalculators_sacRate => 'معدل SAC';

  @override
  String get gasCalculators_tab_bestMix => 'أفضل خليط';

  @override
  String get gasCalculators_tab_consumption => 'الاستهلاك';

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
  String get media_diveMediaSection_emptyState => 'لا توجد صور بعد';

  @override
  String get media_diveMediaSection_errorLoading => 'خطأ في تحميل الوسائط';

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'عرض الصورة. اضغط مطولًا لإلغاء الربط';

  @override
  String get media_diveMediaSection_title => 'الصور والفيديو';

  @override
  String get media_diveMediaSection_unlinkButton => 'إلغاء الربط';

  @override
  String get media_diveMediaSection_unlinkDialogContent =>
      'هل تريد إزالة هذه الصورة من الغوصة؟ ستبقى الصورة في معرض الصور.';

  @override
  String get media_diveMediaSection_unlinkDialogTitle => 'إلغاء ربط الصورة';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'فشل في إلغاء الربط: $error';
  }

  @override
  String get media_diveMediaSection_unlinkSuccess => 'تم إلغاء ربط الصورة';

  @override
  String get media_gpsBanner_addToSiteButton => 'إضافة إلى الموقع';

  @override
  String media_gpsBanner_coordinates(Object latitude, Object longitude) {
    return 'الإحداثيات: $latitude، $longitude';
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
  String media_import_importedAndFailed(Object imported, Object failed) {
    return 'تم استيراد $imported، فشل $failed';
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
  String get media_miniProfile_headerLabel => 'ملف الغوصة';

  @override
  String get media_miniProfile_semanticLabel => 'مخطط ملف الغوصة المصغر';

  @override
  String get media_photoPicker_appBarTitle => 'اختيار الصور';

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
  String get media_photoPicker_grantAccessButton => 'منح الوصول';

  @override
  String get media_photoPicker_openSettingsButton => 'فتح الإعدادات';

  @override
  String get media_photoPicker_openSettingsSnackbar =>
      'يرجى فتح الإعدادات وتمكين الوصول إلى الصور';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'تم رفض الوصول إلى مكتبة الصور. يرجى تمكينه في الإعدادات لإضافة صور الغوص.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'يحتاج Submersion إلى الوصول إلى مكتبة الصور لإضافة صور الغوص.';

  @override
  String get media_photoPicker_permissionTitle => 'مطلوب الوصول إلى الصور';

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
  String get media_photoViewer_noPhotosAvailable => 'لا توجد صور متاحة';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel => 'تشغيل أو إيقاف الفيديو';

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
  String get nav_home => 'الرئيسية';

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
  String get onboarding_welcome_createProfile => 'إنشاء ملفك الشخصي';

  @override
  String get onboarding_welcome_createProfileSubtitle =>
      'أدخل اسمك للبدء. يمكنك إضافة المزيد من التفاصيل لاحقاً.';

  @override
  String get onboarding_welcome_creating => 'جارٍ الإنشاء...';

  @override
  String onboarding_welcome_errorCreatingProfile(Object error) {
    return 'خطأ في إنشاء الملف الشخصي: $error';
  }

  @override
  String get onboarding_welcome_getStarted => 'البدء';

  @override
  String get onboarding_welcome_nameHint => 'أدخل اسمك';

  @override
  String get onboarding_welcome_nameLabel => 'اسمك';

  @override
  String get onboarding_welcome_nameValidation => 'الرجاء إدخال اسمك';

  @override
  String get onboarding_welcome_subtitle => 'تسجيل وتحليل متقدم للغوص';

  @override
  String get onboarding_welcome_title => 'مرحباً بك في Submersion';

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
  String get settings_about_reportIssue_snackbar =>
      'قم بزيارة github.com/submersion/submersion';

  @override
  String settings_about_version(String version, String buildNumber) {
    return 'الإصدار $version ($buildNumber)';
  }

  @override
  String get settings_appBar_title => 'الإعدادات';

  @override
  String get settings_appearance_appLanguage => 'لغة التطبيق';

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
  String get settings_appearance_header_diveLog => 'سجل الغوص';

  @override
  String get settings_appearance_header_diveProfile => 'ملف الغوصة';

  @override
  String get settings_appearance_header_diveSites => 'مواقع الغوص';

  @override
  String get settings_appearance_header_language => 'اللغة';

  @override
  String get settings_appearance_header_theme => 'المظهر';

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
  String get settings_appearance_pressureThresholdMarkers =>
      'علامات عتبة الضغط';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'عرض علامات عندما يتجاوز ضغط الأسطوانة العتبات';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'عرض علامات عندما يتجاوز ضغط الأسطوانة عتبات 2/3 و 1/2 و 1/3';

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
  String get settings_backToSettings_tooltip => 'العودة إلى الإعدادات';

  @override
  String get settings_cloudSync_appBar_title => 'المزامنة السحابية';

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
  String get settings_cloudSync_header_advanced => 'متقدم';

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
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'المزامنة عبر Google Drive';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'المزامنة عبر Apple iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'فشل في تهيئة مزود $providerName';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'غير متاح على هذه المنصة';

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
  String get settings_data_backup => 'نسخ احتياطي';

  @override
  String get settings_data_backup_subtitle => 'إنشاء نسخة احتياطية من بياناتك';

  @override
  String get settings_data_cloudSync => 'المزامنة السحابية';

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
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'اختيار إعداد التحفظ المسبق $presetName';
  }

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
  String get settings_manage_tankPresets => 'إعدادات الأسطوانات المسبقة';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'إدارة تهيئات الأسطوانات المخصصة';

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
  String get settings_notifications_disabled_enableButton => 'تمكين';

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
  String surfaceInterval_heSemantics(Object percent) {
    return 'الهيليوم: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'الفترة الحالية';

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
  String get surfaceInterval_secondDive_gasAir => '(هواء)';

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
  String get tags_hint_addTags => 'إضافة وسوم...';

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
      'استيراد الغوصات المسجلة على Apple Watch Ultra';

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
  String get transfer_import_autoDetectSemanticLabel =>
      'استيراد البيانات مع الكشف التلقائي';

  @override
  String get transfer_import_autoDetectSubtitle =>
      'يكتشف تلقائيًا CSV و UDDF و FIT والمزيد';

  @override
  String get transfer_import_autoDetectTitle => 'استيراد البيانات';

  @override
  String get transfer_import_byFormatHeader => 'الاستيراد حسب الصيغة';

  @override
  String get transfer_import_csvSubtitle => 'استيراد الغوصات من ملف CSV';

  @override
  String get transfer_import_csvTitle => 'الاستيراد من CSV';

  @override
  String get transfer_import_fitSubtitle =>
      'استيراد الغوصات من ملفات تصدير Garmin Descent';

  @override
  String get transfer_import_fitTitle => 'الاستيراد من ملف FIT';

  @override
  String get transfer_import_operationCompleted => 'اكتملت العملية';

  @override
  String transfer_import_operationFailed(Object error) {
    return 'فشلت العملية: $error';
  }

  @override
  String get transfer_import_sectionHeader => 'استيراد البيانات';

  @override
  String get transfer_import_uddfSubtitle => 'تنسيق بيانات الغوص العالمي';

  @override
  String get transfer_import_uddfTitle => 'الاستيراد من UDDF';

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
  String get trips_detail_stat_totalBottomTime => 'إجمالي وقت القاع';

  @override
  String get trips_detail_stat_totalDives => 'إجمالي الغوصات';

  @override
  String get trips_detail_tooltip_edit => 'تعديل الرحلة';

  @override
  String get trips_detail_tooltip_editShort => 'تعديل';

  @override
  String get trips_detail_tooltip_moreOptions => 'خيارات إضافية';

  @override
  String get trips_detail_tooltip_viewOnMap => 'عرض على الخريطة';

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
  String get universalImport_action_selectFile => 'اختيار ملف';

  @override
  String get universalImport_description_supportedFormats =>
      'اختر ملف سجل غوص للاستيراد. الصيغ المدعومة تشمل CSV وUDDF وSubsurface XML وGarmin FIT.';

  @override
  String get universalImport_error_unsupportedFormat =>
      'هذه الصيغة غير مدعومة بعد. يرجى التصدير كـ UDDF أو CSV.';

  @override
  String get universalImport_hint_tagDescription =>
      'ضع وسماً على جميع الغطسات المستوردة للتصفية السهلة';

  @override
  String get universalImport_hint_tagExample =>
      'مثال: استيراد MacDive 2026-02-09';

  @override
  String get universalImport_label_columnMapping => 'تعيين الأعمدة';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped من $total أعمدة معينة';
  }

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
  String get universalImport_label_importComplete => 'اكتمل الاستيراد';

  @override
  String get universalImport_label_importTag => 'وسم الاستيراد';

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
  String get universalImport_step_import => 'استيراد';

  @override
  String get universalImport_step_map => 'تعيين';

  @override
  String get universalImport_step_review => 'مراجعة';

  @override
  String get universalImport_step_select => 'اختيار';

  @override
  String get universalImport_title => 'استيراد البيانات';

  @override
  String get universalImport_tooltip_clearTag => 'مسح الوسم';

  @override
  String get universalImport_tooltip_closeWizard => 'إغلاق معالج الاستيراد';

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
  String get diveComputer_downloadStep_downloadFailed => 'فشل التنزيل';

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
  String get diveComputer_download_newDivesImported => 'تم استيراد غطسات جديدة';

  @override
  String get diveComputer_download_preparing => 'جارٍ التحضير...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

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
      'يحتاج Submersion إلى الوصول لبيانات الغوص من Apple Watch لاستيراد الغطسات.';

  @override
  String get diveImport_healthkit_accessRequired =>
      'مطلوب الوصول إلى HealthKit';

  @override
  String get diveImport_healthkit_closeTooltip => 'إغلاق استيراد Apple Watch';

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
  String get diveImport_healthkit_grantAccess => 'منح الوصول';

  @override
  String get diveImport_healthkit_noDivesFound => 'لم يتم العثور على غطسات';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'لم يتم العثور على أنشطة غوص في النطاق الزمني المحدد.';

  @override
  String get diveImport_healthkit_notAvailable => 'غير متاح';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'استيراد Apple Watch متاح فقط على أجهزة iOS وmacOS.';

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
  String get gasCalculators_rockBottom_aboutDescription =>
      'الحد الأدنى للغاز هو أقل احتياطي غاز للصعود الطارئ أثناء مشاركة الهواء مع رفيقك.\n\n- يستخدم معدلات SAC تحت الضغط (2-3 أضعاف المعدل الطبيعي)\n- يفترض أن كلا الغواصين على أسطوانة واحدة\n- يشمل وقفة الأمان عند تفعيلها\n\nقم بإنهاء الغطسة دائمًا قبل الوصول إلى الحد الأدنى!';

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
  String get gasCalculators_rockBottom_buddySac => 'SAC الرفيق';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'SAC المشترك تحت الضغط';

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
      'استخدم معدلات SAC أعلى لاحتساب الإجهاد أثناء الطوارئ';

  @override
  String get gasCalculators_rockBottom_stressedSacRates =>
      'معدلات SAC تحت الضغط';

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
  String get gasCalculators_rockBottom_yourSac => 'SAC الخاص بك';

  @override
  String get maps_heatMap_hide => 'إخفاء خريطة الحرارة';

  @override
  String get maps_heatMap_overlayOff => 'طبقة خريطة الحرارة معطلة';

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
  String get tankPresets_customPresets => 'الإعدادات المخصصة';

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
  String get tankPresets_new_title => 'إعداد أسطوانة جديد';

  @override
  String get tankPresets_noPresets => 'لا توجد إعدادات أسطوانات';

  @override
  String get tankPresets_title => 'إعدادات الأسطوانات';

  @override
  String get tools_deco_description =>
      'احسب حدود عدم تخفيف الضغط، ووقفات التخفيف المطلوبة، والتعرض لـ CNS/OTU لملفات الغطسات متعددة المستويات.';

  @override
  String get tools_deco_subtitle => 'خطط للغطسات مع وقفات تخفيف الضغط';

  @override
  String get tools_deco_title => 'حاسبة تخفيف الضغط';

  @override
  String get tools_disclaimer =>
      'هذه الحاسبات للتخطيط فقط. تحقق دائمًا من الحسابات واتبع تدريبك على الغوص.';

  @override
  String get tools_gas_description =>
      'أربع حاسبات غاز متخصصة:\n- MOD - أقصى عمق تشغيلي لخليط غاز\n- Best Mix - نسبة O₂ المثالية لعمق مستهدف\n- الاستهلاك - تقدير استخدام الغاز\n- الحد الأدنى - حساب احتياطي الطوارئ';

  @override
  String get tools_gas_subtitle => 'MOD، Best Mix، الاستهلاك، الحد الأدنى';

  @override
  String get tools_gas_title => 'حاسبات الغاز';

  @override
  String get tools_title => 'الأدوات';

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
  String get tools_weight_description =>
      'قدّر الوزن المطلوب بناءً على بدلة الغوص ومادة الأسطوانة ونوع الماء ووزن الجسم.';

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
  String get tools_weight_subtitle => 'الوزن الموصى به لإعدادك';

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
}
