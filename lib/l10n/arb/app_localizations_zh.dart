// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get accessibility_dialog_keyboardShortcutsTitle => '键盘快捷键';

  @override
  String get accessibility_keyLabel_backspace => '退格';

  @override
  String get accessibility_keyLabel_delete => '删除';

  @override
  String get accessibility_keyLabel_down => '下';

  @override
  String get accessibility_keyLabel_enter => '回车';

  @override
  String get accessibility_keyLabel_esc => 'Esc';

  @override
  String get accessibility_keyLabel_left => '左';

  @override
  String get accessibility_keyLabel_right => '右';

  @override
  String get accessibility_keyLabel_up => '上';

  @override
  String accessibility_label_chartSummary(
    Object chartType,
    Object description,
  ) {
    return '$chartType图表。$description';
  }

  @override
  String get accessibility_label_createNewItem => '创建新项目';

  @override
  String get accessibility_label_hideList => '隐藏列表';

  @override
  String get accessibility_label_hideMapView => '隐藏地图视图';

  @override
  String accessibility_label_listPane(Object title) {
    return '$title列表面板';
  }

  @override
  String accessibility_label_mapPane(Object title) {
    return '$title地图面板';
  }

  @override
  String accessibility_label_mapViewTitle(Object title) {
    return '$title地图视图';
  }

  @override
  String get accessibility_label_showList => '显示列表';

  @override
  String get accessibility_label_showMapView => '显示地图视图';

  @override
  String get accessibility_label_viewDetails => '查看详情';

  @override
  String get accessibility_modifierKey_alt => 'Alt+';

  @override
  String get accessibility_modifierKey_cmd => 'Cmd+';

  @override
  String get accessibility_modifierKey_ctrl => 'Ctrl+';

  @override
  String get accessibility_modifierKey_option => '选项+';

  @override
  String get accessibility_modifierKey_shift => 'Shift+';

  @override
  String get accessibility_modifierKey_super => 'Super+';

  @override
  String get accessibility_shortcutCategory_editing => '编辑';

  @override
  String get accessibility_shortcutCategory_general => '通用';

  @override
  String get accessibility_shortcutCategory_help => '帮助';

  @override
  String get accessibility_shortcutCategory_navigation => '导航';

  @override
  String get accessibility_shortcutCategory_search => '搜索';

  @override
  String get accessibility_shortcut_closeCancel => '关闭 / 取消';

  @override
  String get accessibility_shortcut_goBack => '返回';

  @override
  String get accessibility_shortcut_goToDives => '前往潜水日志';

  @override
  String get accessibility_shortcut_goToEquipment => '前往装备';

  @override
  String get accessibility_shortcut_goToSettings => '前往设置';

  @override
  String get accessibility_shortcut_goToSites => '前往潜水点';

  @override
  String get accessibility_shortcut_goToStatistics => '前往统计';

  @override
  String get accessibility_shortcut_keyboardShortcuts => '键盘快捷键';

  @override
  String get accessibility_shortcut_newDive => '新建潜水';

  @override
  String get accessibility_shortcut_openSettings => '打开设置';

  @override
  String get accessibility_shortcut_searchDives => '搜索潜水';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return '按$displayName排序，当前已选中';
  }

  @override
  String accessibility_sort_unselectedLabel(Object displayName) {
    return '按$displayName排序';
  }

  @override
  String get backup_appBar_title => '备份与恢复';

  @override
  String get backup_backingUp => '正在备份...';

  @override
  String get backup_backupNow => '立即备份';

  @override
  String get backup_cloud_enabled => '云端备份';

  @override
  String get backup_cloud_enabled_subtitle => '将备份上传至云存储';

  @override
  String get backup_delete_dialog_cancel => '取消';

  @override
  String get backup_delete_dialog_content => '此备份将被永久删除。此操作无法撤消。';

  @override
  String get backup_delete_dialog_delete => '删除';

  @override
  String get backup_delete_dialog_title => '删除备份';

  @override
  String get backup_export_bottomSheet_title => '导出备份';

  @override
  String get backup_export_saveToFile => '保存到文件';

  @override
  String get backup_export_saveToFile_subtitle => '选择备份文件的保存位置';

  @override
  String get backup_export_share => '分享';

  @override
  String get backup_export_share_subtitle => '通过隔空投送、电子邮件或其他应用发送';

  @override
  String get backup_export_subtitle => '将您的潜水数据保存到文件';

  @override
  String get backup_export_success => '备份导出成功';

  @override
  String get backup_export_title => '导出备份';

  @override
  String get backup_frequency_daily => '每天';

  @override
  String get backup_frequency_monthly => '每月';

  @override
  String get backup_frequency_weekly => '每周';

  @override
  String get backup_history_action_delete => '删除';

  @override
  String get backup_history_action_restore => '恢复';

  @override
  String get backup_history_empty => '暂无备份';

  @override
  String backup_history_error(Object error) {
    return '加载历史记录失败：$error';
  }

  @override
  String get backup_import_invalidFile => '此文件似乎不是有效的 Submersion 备份文件';

  @override
  String get backup_import_subtitle => '从任意位置导入备份';

  @override
  String get backup_import_title => '从文件恢复';

  @override
  String get backup_import_validating => '正在验证备份文件...';

  @override
  String get backup_location_change => '更改';

  @override
  String get backup_location_default => '默认位置';

  @override
  String get backup_location_title => '备份位置';

  @override
  String get backup_restore_dialog_cancel => '取消';

  @override
  String get backup_restore_dialog_restore => '恢复';

  @override
  String get backup_restore_dialog_safetyNote => '恢复前将自动创建当前数据的安全备份。';

  @override
  String get backup_restore_dialog_title => '恢复备份';

  @override
  String get backup_restore_dialog_warning => '这将用备份数据替换所有当前数据。此操作无法撤消。';

  @override
  String get backup_restoreComplete_continue => '继续';

  @override
  String get backup_restoreComplete_description =>
      '您的数据已成功恢复。点击继续以使用恢复的数据重新加载应用。';

  @override
  String get backup_restoreComplete_title => '恢复完成';

  @override
  String get backup_schedule_enabled => '自动备份';

  @override
  String get backup_schedule_enabled_subtitle => '按计划备份您的数据';

  @override
  String get backup_schedule_frequency => '频率';

  @override
  String get backup_schedule_retention => '保留备份';

  @override
  String get backup_schedule_retention_subtitle => '旧备份将自动删除';

  @override
  String get backup_section_auto => '自动备份';

  @override
  String get backup_section_cloud => '云端';

  @override
  String get backup_section_history => '历史记录';

  @override
  String get backup_section_schedule => '计划';

  @override
  String get backup_status_disabled => '自动备份已禁用';

  @override
  String backup_status_lastBackup(String time) {
    return '上次备份：$time';
  }

  @override
  String get backup_status_neverBackedUp => '从未备份';

  @override
  String get backup_status_noBackupsYet => '创建您的第一个备份以保护您的数据';

  @override
  String get backup_status_overdue => '备份已过期';

  @override
  String get backup_status_upToDate => '备份已是最新';

  @override
  String backup_time_daysAgo(int count) {
    return '$count天前';
  }

  @override
  String backup_time_hoursAgo(int count) {
    return '$count小时前';
  }

  @override
  String get backup_time_justNow => '刚刚';

  @override
  String backup_time_minutesAgo(int count) {
    return '$count分钟前';
  }

  @override
  String get buddies_action_add => '添加潜伴';

  @override
  String get buddies_action_addFirst => '添加您的第一位潜伴';

  @override
  String get buddies_action_addTooltip => '添加新潜伴';

  @override
  String get buddies_action_clearSearch => '清除搜索';

  @override
  String get buddies_action_edit => '编辑潜伴';

  @override
  String get buddies_action_importFromContacts => '从通讯录导入';

  @override
  String get buddies_action_moreOptions => '更多选项';

  @override
  String get buddies_action_retry => '重试';

  @override
  String get buddies_action_search => '搜索潜伴';

  @override
  String get buddies_action_shareDives => '分享潜水';

  @override
  String get buddies_action_sort => '排序';

  @override
  String get buddies_action_sortTitle => '潜伴排序';

  @override
  String get buddies_action_update => '更新潜伴';

  @override
  String buddies_action_viewAll(Object count) {
    return '查看全部 ($count)';
  }

  @override
  String buddies_detail_error(Object error) {
    return '错误：$error';
  }

  @override
  String get buddies_detail_noDivesTogether => '尚无共同潜水';

  @override
  String get buddies_detail_notFound => '未找到潜伴';

  @override
  String buddies_dialog_deleteMessage(Object name) {
    return '确定要删除 $name 吗？此操作无法撤消。';
  }

  @override
  String get buddies_dialog_deleteTitle => '删除潜伴？';

  @override
  String get buddies_dialog_discard => '丢弃';

  @override
  String get buddies_dialog_discardMessage => '您有未保存的更改。确定要丢弃吗？';

  @override
  String get buddies_dialog_discardTitle => '丢弃更改？';

  @override
  String get buddies_dialog_keepEditing => '继续编辑';

  @override
  String get buddies_empty_subtitle => '添加您的第一位潜伴开始使用';

  @override
  String get buddies_empty_title => '暂无潜伴';

  @override
  String buddies_error_loading(Object error) {
    return '错误：$error';
  }

  @override
  String get buddies_error_unableToLoadDives => '无法加载潜水';

  @override
  String get buddies_error_unableToLoadStats => '无法加载统计';

  @override
  String get buddies_field_certificationAgency => '认证机构';

  @override
  String get buddies_field_certificationLevel => '认证等级';

  @override
  String get buddies_field_email => '电子邮件';

  @override
  String get buddies_field_emailHint => 'email@example.com';

  @override
  String get buddies_field_nameHint => '输入潜伴姓名';

  @override
  String get buddies_field_nameRequired => '姓名 *';

  @override
  String get buddies_field_notes => '备注';

  @override
  String get buddies_field_notesHint => '添加关于此潜伴的备注...';

  @override
  String get buddies_field_phone => '电话';

  @override
  String get buddies_field_phoneHint => '+1 (555) 123-4567';

  @override
  String get buddies_label_agency => '机构';

  @override
  String buddies_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次潜水',
      one: '1 次潜水',
    );
    return '$_temp0';
  }

  @override
  String get buddies_label_level => '等级';

  @override
  String get buddies_label_notSpecified => '未指定';

  @override
  String get buddies_label_photoComingSoon => '照片功能将在 v2.0 推出';

  @override
  String get buddies_message_added => '潜伴添加成功';

  @override
  String get buddies_message_contactImportUnavailable => '此平台不支持通讯录导入';

  @override
  String get buddies_message_contactLoadFailed => '加载通讯录失败';

  @override
  String get buddies_message_contactPermissionRequired => '需要通讯录权限才能导入潜伴';

  @override
  String get buddies_message_deleted => '潜伴已删除';

  @override
  String buddies_message_errorImportingContact(Object error) {
    return '导入联系人出错：$error';
  }

  @override
  String buddies_message_errorLoading(Object error) {
    return '加载潜伴出错：$error';
  }

  @override
  String buddies_message_errorSaving(Object error) {
    return '保存潜伴出错：$error';
  }

  @override
  String buddies_message_exportFailed(Object error) {
    return '导出失败：$error';
  }

  @override
  String get buddies_message_noDivesFound => '未找到可导出的潜水';

  @override
  String get buddies_message_noDivesToShare => '没有可与此潜伴分享的潜水';

  @override
  String get buddies_message_preparingExport => '正在准备导出...';

  @override
  String get buddies_message_updated => '潜伴更新成功';

  @override
  String get buddies_picker_add => '添加';

  @override
  String get buddies_picker_addNew => '添加新潜伴';

  @override
  String get buddies_picker_done => '完成';

  @override
  String get buddies_picker_noBuddiesFound => '未找到潜伴';

  @override
  String get buddies_picker_noBuddiesYet => '暂无潜伴';

  @override
  String get buddies_picker_noneSelected => '未选择潜伴';

  @override
  String get buddies_picker_searchHint => '搜索潜伴...';

  @override
  String get buddies_picker_selectBuddies => '选择潜伴';

  @override
  String buddies_picker_selectRole(Object name) {
    return '为 $name 选择角色';
  }

  @override
  String get buddies_picker_tapToAdd => '点击「添加」选择潜伴';

  @override
  String get buddies_search_hint => '按姓名、邮箱或电话搜索';

  @override
  String buddies_search_noResults(Object query) {
    return '未找到与「$query」匹配的潜伴';
  }

  @override
  String get buddies_section_certification => '认证';

  @override
  String get buddies_section_contact => '联系方式';

  @override
  String get buddies_section_diveStatistics => '潜水统计';

  @override
  String get buddies_section_notes => '备注';

  @override
  String get buddies_section_sharedDives => '共同潜水';

  @override
  String get buddies_stat_divesTogether => '共同潜水次数';

  @override
  String get buddies_stat_favoriteSite => '最爱潜水点';

  @override
  String get buddies_stat_firstDive => '首次潜水';

  @override
  String get buddies_stat_lastDive => '最近潜水';

  @override
  String get buddies_summary_overview => '概览';

  @override
  String get buddies_summary_quickActions => '快捷操作';

  @override
  String get buddies_summary_recentBuddies => '最近潜伴';

  @override
  String get buddies_summary_selectHint => '从列表中选择一位潜伴以查看详情';

  @override
  String get buddies_summary_title => '潜伴';

  @override
  String get buddies_summary_totalBuddies => '潜伴总数';

  @override
  String get buddies_summary_withCertification => '持有认证';

  @override
  String get buddies_title => '潜伴';

  @override
  String get buddies_title_add => '添加潜伴';

  @override
  String get buddies_title_edit => '编辑潜伴';

  @override
  String get buddies_title_singular => '潜伴';

  @override
  String get buddies_validation_emailInvalid => '请输入有效的电子邮件地址';

  @override
  String get buddies_validation_nameRequired => '请输入姓名';

  @override
  String get buddies_list_selection_closeTooltip => '关闭选择';

  @override
  String buddies_list_selection_count(int count) {
    return '已选择 $count 项';
  }

  @override
  String get buddies_list_selection_selectAllTooltip => '全选';

  @override
  String get buddies_list_selection_deselectAllTooltip => '取消全选';

  @override
  String get buddies_list_selection_mergeTooltip => '合并所选';

  @override
  String get buddies_list_selection_deleteTooltip => '删除所选';

  @override
  String buddies_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '位潜伴',
      one: '位潜伴',
    );
    return '已合并 $count $_temp0';
  }

  @override
  String get buddies_list_merge_undo => '撤消';

  @override
  String get buddies_list_merge_restored => '合并已撤消';

  @override
  String get buddies_list_bulkDelete_title => '删除潜伴';

  @override
  String buddies_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '位潜伴',
      one: '位潜伴',
    );
    return '确定要删除 $count $_temp0吗？此操作无法撤消。';
  }

  @override
  String get buddies_list_bulkDelete_cancel => '取消';

  @override
  String get buddies_list_bulkDelete_confirm => '删除';

  @override
  String buddies_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '位潜伴',
      one: '位潜伴',
    );
    return '已删除 $count $_temp0';
  }

  @override
  String get buddies_edit_merge_title => '合并潜伴';

  @override
  String get buddies_edit_merge_fieldSourceCycleTooltip => '使用下一位已选潜伴的值';

  @override
  String buddies_edit_merge_fieldSourceLabel(
    String buddyName,
    int current,
    int total,
  ) {
    return '来自 $buddyName（$current/$total）';
  }

  @override
  String get buddies_edit_merge_confirmTitle => '合并潜伴';

  @override
  String buddies_edit_merge_confirmBody(int count) {
    return '这将把 $count 位潜伴合并为一位。潜水关联将合并到保留的潜伴下。其他潜伴将被删除。';
  }

  @override
  String get buddies_edit_merge_loadingErrorTitle => '合并潜伴';

  @override
  String buddies_edit_merge_loadingErrorBody(String error) {
    return '加载潜伴失败：$error';
  }

  @override
  String get buddies_edit_merge_notEnoughTitle => '合并潜伴';

  @override
  String get buddies_edit_merge_notEnoughBody => '潜伴数量不足，无法合并。';

  @override
  String get certifications_appBar_addCertification => '添加证书';

  @override
  String get certifications_appBar_certificationWallet => '证书卡包';

  @override
  String get certifications_appBar_editCertification => '编辑证书';

  @override
  String get certifications_appBar_title => '证书';

  @override
  String get certifications_detail_action_delete => '删除';

  @override
  String get certifications_detail_appBar_title => '证书';

  @override
  String get certifications_detail_courseCompleted => '已完成';

  @override
  String get certifications_detail_courseInProgress => '进行中';

  @override
  String get certifications_detail_dialog_cancel => '取消';

  @override
  String get certifications_detail_dialog_deleteConfirm => '删除';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return '确定要删除「$name」吗？';
  }

  @override
  String get certifications_detail_dialog_deleteTitle => '删除证书？';

  @override
  String get certifications_detail_label_agency => '机构';

  @override
  String get certifications_detail_label_cardNumber => '卡号';

  @override
  String get certifications_detail_label_expiryDate => '到期日期';

  @override
  String get certifications_detail_label_instructorName => '姓名';

  @override
  String get certifications_detail_label_instructorNumber => '教练编号';

  @override
  String get certifications_detail_label_issueDate => '签发日期';

  @override
  String get certifications_detail_label_level => '等级';

  @override
  String get certifications_detail_label_type => '类型';

  @override
  String get certifications_detail_label_validity => '有效期';

  @override
  String get certifications_detail_noExpiration => '永久有效';

  @override
  String get certifications_detail_notFound => '未找到证书';

  @override
  String get certifications_detail_photoLabel_back => '背面';

  @override
  String get certifications_detail_photoLabel_front => '正面';

  @override
  String certifications_detail_photo_fullscreenTitle(
    Object label,
    Object name,
  ) {
    return '$label - $name';
  }

  @override
  String get certifications_detail_photo_unableToLoad => '无法加载图片';

  @override
  String get certifications_detail_sectionTitle_cardPhotos => '证书照片';

  @override
  String get certifications_detail_sectionTitle_dates => '日期';

  @override
  String get certifications_detail_sectionTitle_details => '证书详情';

  @override
  String get certifications_detail_sectionTitle_instructor => '教练';

  @override
  String get certifications_detail_sectionTitle_notes => '备注';

  @override
  String get certifications_detail_sectionTitle_trainingCourse => '培训课程';

  @override
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  ) {
    return '$name的$label照片。点击查看全屏';
  }

  @override
  String get certifications_detail_snackBar_deleted => '证书已删除';

  @override
  String get certifications_detail_status_expired => '此证书已过期';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return '于 $date 过期';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return '$days 天后到期';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return '于 $date 到期';
  }

  @override
  String get certifications_detail_tooltip_edit => '编辑证书';

  @override
  String get certifications_detail_tooltip_editShort => '编辑';

  @override
  String get certifications_detail_tooltip_moreOptions => '更多选项';

  @override
  String get certifications_ecardStack_empty_subtitle => '添加您的第一个证书即可在此查看';

  @override
  String get certifications_ecardStack_empty_title => '暂无证书';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return '由 $agency 认证';
  }

  @override
  String get certifications_ecard_label_instructor => '教练';

  @override
  String get certifications_ecard_label_issued => '签发日期';

  @override
  String get certifications_ecard_statusBadge_expired => '已过期';

  @override
  String get certifications_ecard_statusBadge_expiring => '即将到期';

  @override
  String get certifications_edit_appBar_add => '添加证书';

  @override
  String get certifications_edit_appBar_edit => '编辑证书';

  @override
  String get certifications_edit_button_add => '添加证书';

  @override
  String get certifications_edit_button_cancel => '取消';

  @override
  String get certifications_edit_button_save => '保存';

  @override
  String get certifications_edit_button_update => '更新证书';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return '清除$label';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect => '点击选择';

  @override
  String get certifications_edit_dialog_discard => '丢弃';

  @override
  String get certifications_edit_dialog_discardContent => '您有未保存的更改。确定要离开吗？';

  @override
  String get certifications_edit_dialog_discardTitle => '丢弃更改？';

  @override
  String get certifications_edit_dialog_keepEditing => '继续编辑';

  @override
  String get certifications_edit_help_expiryDate => '不会过期的证书请留空';

  @override
  String get certifications_edit_hint_cardNumber => '输入证书卡号';

  @override
  String get certifications_edit_hint_certificationName => '例如，开放水域潜水员';

  @override
  String get certifications_edit_hint_instructorName => '认证教练姓名';

  @override
  String get certifications_edit_hint_instructorNumber => '教练认证编号';

  @override
  String get certifications_edit_hint_notes => '其他备注';

  @override
  String get certifications_edit_label_agency => '机构 *';

  @override
  String get certifications_edit_label_cardNumber => '卡号';

  @override
  String get certifications_edit_label_certificationName => '证书名称 *';

  @override
  String get certifications_edit_label_expiryDate => '到期日期';

  @override
  String get certifications_edit_label_instructorName => '教练姓名';

  @override
  String get certifications_edit_label_instructorNumber => '教练编号';

  @override
  String get certifications_edit_label_issueDate => '签发日期';

  @override
  String get certifications_edit_label_level => '等级';

  @override
  String get certifications_edit_label_notes => '备注';

  @override
  String get certifications_edit_level_notSpecified => '未指定';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return '添加$label照片。点击选择';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return '$label照片已附加。点击更改';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery => '从相册选择';

  @override
  String certifications_edit_photo_removeTooltip(Object label) {
    return '移除$label照片';
  }

  @override
  String get certifications_edit_photo_takePhoto => '拍照';

  @override
  String get certifications_edit_sectionTitle_cardPhotos => '证书照片';

  @override
  String get certifications_edit_sectionTitle_dates => '日期';

  @override
  String get certifications_edit_sectionTitle_instructorInfo => '教练信息';

  @override
  String get certifications_edit_sectionTitle_notes => '备注';

  @override
  String get certifications_edit_snackBar_added => '证书添加成功';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return '加载证书出错：$error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return '选择照片出错：$error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return '保存证书出错：$error';
  }

  @override
  String get certifications_edit_snackBar_updated => '证书更新成功';

  @override
  String get certifications_edit_validation_nameRequired => '请输入证书名称';

  @override
  String get certifications_list_button_retry => '重试';

  @override
  String get certifications_list_empty_button => '添加您的第一个证书';

  @override
  String get certifications_list_empty_subtitle => '添加您的潜水证书以跟踪您的培训和资质';

  @override
  String get certifications_list_empty_title => '尚未添加证书';

  @override
  String certifications_list_error_loading(Object error) {
    return '加载证书出错：$error';
  }

  @override
  String get certifications_list_fab_addCertification => '添加证书';

  @override
  String get certifications_list_section_expired => '已过期';

  @override
  String get certifications_list_section_expiringSoon => '即将到期';

  @override
  String get certifications_list_section_valid => '有效';

  @override
  String get certifications_list_sort_title => '证书排序';

  @override
  String get certifications_list_tile_expired => '已过期';

  @override
  String certifications_list_tile_expiringDays(Object days) {
    return '$days天';
  }

  @override
  String get certifications_list_tooltip_addCertification => '添加证书';

  @override
  String get certifications_list_tooltip_search => '搜索证书';

  @override
  String get certifications_list_tooltip_sort => '排序';

  @override
  String get certifications_list_tooltip_walletView => '卡包视图';

  @override
  String get certifications_picker_clearTooltip => '清除证书选择';

  @override
  String get certifications_picker_empty_addButton => '添加证书';

  @override
  String get certifications_picker_empty_title => '暂无证书';

  @override
  String certifications_picker_error(Object error) {
    return '加载证书出错：$error';
  }

  @override
  String get certifications_picker_expired => '已过期';

  @override
  String get certifications_picker_hint => '点击关联已获得的证书';

  @override
  String get certifications_picker_newCert => '新证书';

  @override
  String get certifications_picker_noSelection => '未选择证书';

  @override
  String get certifications_picker_sheetTitle => '关联证书';

  @override
  String get certifications_renderer_footer => 'Submersion 潜水日志';

  @override
  String certifications_renderer_label_cardNumber(Object number) {
    return '卡号：$number';
  }

  @override
  String get certifications_renderer_label_hasCompletedTraining => '已完成以下培训';

  @override
  String certifications_renderer_label_instructor(Object name) {
    return '教练：$name';
  }

  @override
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  ) {
    return '教练：$name（$number）';
  }

  @override
  String certifications_renderer_label_issued(Object date) {
    return '签发日期：$date';
  }

  @override
  String get certifications_renderer_label_thisCertifies => '特此证明';

  @override
  String get certifications_search_empty_hint => '按名称、机构或卡号搜索';

  @override
  String get certifications_search_fieldLabel => '搜索证书...';

  @override
  String certifications_search_noResults(Object query) {
    return '未找到与「$query」匹配的证书';
  }

  @override
  String get certifications_search_tooltip_back => '返回';

  @override
  String get certifications_search_tooltip_clear => '清除搜索';

  @override
  String certifications_share_error_card(Object error) {
    return '分享卡片失败：$error';
  }

  @override
  String certifications_share_error_certificate(Object error) {
    return '分享证书失败：$error';
  }

  @override
  String get certifications_share_option_card_subtitle => '信用卡样式的证书图片';

  @override
  String get certifications_share_option_card_title => '分享为卡片';

  @override
  String get certifications_share_option_certificate_subtitle => '正式证书文档';

  @override
  String get certifications_share_option_certificate_title => '分享为证书';

  @override
  String get certifications_share_title => '分享证书';

  @override
  String get certifications_summary_header_subtitle => '从列表中选择证书以查看详情';

  @override
  String get certifications_summary_header_title => '证书';

  @override
  String get certifications_summary_overview_title => '概览';

  @override
  String get certifications_summary_quickActions_add => '添加证书';

  @override
  String get certifications_summary_quickActions_title => '快捷操作';

  @override
  String get certifications_summary_recentTitle => '最近证书';

  @override
  String get certifications_summary_stat_expired => '已过期';

  @override
  String get certifications_summary_stat_expiringSoon => '即将到期';

  @override
  String get certifications_summary_stat_total => '总计';

  @override
  String get certifications_summary_stat_valid => '有效';

  @override
  String certifications_walletCard_countPlural(Object count) {
    return '$count 个证书';
  }

  @override
  String certifications_walletCard_countSingular(Object count) {
    return '$count 个证书';
  }

  @override
  String get certifications_walletCard_emptyFooter => '添加您的第一个证书';

  @override
  String get certifications_walletCard_error => '加载证书失败';

  @override
  String get certifications_walletCard_semanticLabel => '证书卡包。点击查看所有证书';

  @override
  String get certifications_walletCard_tapToAdd => '点击添加';

  @override
  String get certifications_walletCard_title => '证书卡包';

  @override
  String get certifications_wallet_appBar_title => '证书卡包';

  @override
  String get certifications_wallet_error_retry => '重试';

  @override
  String get certifications_wallet_error_title => '加载证书失败';

  @override
  String get certifications_wallet_options_edit => '编辑';

  @override
  String get certifications_wallet_options_share => '分享';

  @override
  String get certifications_wallet_options_viewDetails => '查看详情';

  @override
  String get certifications_wallet_tooltip_add => '添加证书';

  @override
  String get certifications_wallet_tooltip_share => '分享证书';

  @override
  String get common_action_back => '返回';

  @override
  String get common_action_cancel => '取消';

  @override
  String get common_action_close => '关闭';

  @override
  String get common_action_delete => '删除';

  @override
  String get common_action_edit => '编辑';

  @override
  String get common_action_ok => '确定';

  @override
  String get common_action_save => '保存';

  @override
  String get common_action_search => '搜索';

  @override
  String get common_label_error => '错误';

  @override
  String get common_label_loading => '加载中';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get courses_action_add => '添加课程';

  @override
  String get courses_action_create => '创建课程';

  @override
  String get courses_action_edit => '编辑课程';

  @override
  String get courses_action_exportTrainingLog => '导出训练日志';

  @override
  String get courses_action_markCompleted => '标记为已完成';

  @override
  String get courses_action_moreOptions => '更多选项';

  @override
  String get courses_action_retry => '重试';

  @override
  String get courses_action_saveChanges => '保存更改';

  @override
  String get courses_action_saveSemantic => '保存课程';

  @override
  String get courses_action_sort => '排序';

  @override
  String get courses_action_sortTitle => '排序课程';

  @override
  String courses_card_instructor(Object name) {
    return '教练: $name';
  }

  @override
  String courses_card_started(Object date) {
    return '开始于 $date';
  }

  @override
  String get courses_detail_certificationNotFound => '未找到证书';

  @override
  String get courses_detail_noTrainingDives => '尚未关联训练潜水';

  @override
  String get courses_detail_notFound => '未找到课程';

  @override
  String get courses_dialog_complete => '完成';

  @override
  String courses_dialog_deleteMessage(Object name) {
    return '确定要删除 $name? 此操作无法撤消。';
  }

  @override
  String get courses_dialog_deleteTitle => '删除课程？';

  @override
  String get courses_dialog_markCompletedMessage => '这将以今天的日期标记课程为已完成。继续？';

  @override
  String get courses_dialog_markCompletedTitle => '标记为已完成？';

  @override
  String get courses_empty_button => '添加您的第一个训练课程';

  @override
  String get courses_empty_noCompleted => '暂无已完成的课程';

  @override
  String get courses_empty_noInProgress => '暂无进行中的课程';

  @override
  String get courses_empty_subtitle => '添加您的第一个课程以开始使用';

  @override
  String get courses_empty_title => '暂无训练课程';

  @override
  String courses_error_generic(Object error) {
    return '错误： $error';
  }

  @override
  String get courses_error_loadingCertification => '加载证书时出错';

  @override
  String get courses_error_loadingDives => '加载潜水记录时出错';

  @override
  String get courses_field_courseName => '课程名称';

  @override
  String get courses_field_courseNameHint => '例如：开放水域潜水员';

  @override
  String get courses_field_instructorName => '教练名称';

  @override
  String get courses_field_instructorNumber => '教练编号';

  @override
  String get courses_field_linkCertificationHint => '关联此课程获得的证书';

  @override
  String get courses_field_location => '位置';

  @override
  String get courses_field_notes => '备注';

  @override
  String get courses_field_selectFromBuddies => '从潜伴中选择（可选）';

  @override
  String get courses_filter_all => '全部';

  @override
  String get courses_label_agency => '机构';

  @override
  String get courses_label_completed => '已完成';

  @override
  String get courses_label_completionDate => '完成日期';

  @override
  String get courses_label_courseInProgress => '课程进行中';

  @override
  String get courses_label_instructorNumber => '教练 #';

  @override
  String get courses_label_location => '位置';

  @override
  String get courses_label_name => '名称';

  @override
  String get courses_label_none => '-- 无 --';

  @override
  String get courses_label_startDate => '开始日期';

  @override
  String courses_message_errorSaving(Object error) {
    return '保存课程时出错：$error';
  }

  @override
  String courses_message_exportFailed(Object error) {
    return '导出培训日志失败：$error';
  }

  @override
  String get courses_picker_active => '活跃';

  @override
  String get courses_picker_clearSelection => '清除选择';

  @override
  String get courses_picker_createCourse => '创建课程';

  @override
  String courses_picker_errorLoading(Object error) {
    return '加载课程时出错：$error';
  }

  @override
  String get courses_picker_newCourse => '新课程';

  @override
  String get courses_picker_noCourses => '暂无课程';

  @override
  String get courses_picker_noneSelected => '无课程已选择';

  @override
  String get courses_picker_selectTitle => '选择训练课程';

  @override
  String get courses_picker_selected => '已选择';

  @override
  String get courses_picker_tapToLink => '点击关联培训课程';

  @override
  String get courses_section_details => '课程详情';

  @override
  String get courses_section_earnedCertification => '获得的证书';

  @override
  String get courses_section_instructor => '教练';

  @override
  String get courses_section_notes => '备注';

  @override
  String get courses_section_trainingDives => '培训潜水';

  @override
  String get courses_status_completed => '已完成';

  @override
  String courses_status_daysSinceStart(Object days) {
    return '开始后 $days 天';
  }

  @override
  String courses_status_durationDays(Object days) {
    return '$days 天';
  }

  @override
  String get courses_status_inProgress => '在进度';

  @override
  String courses_status_semanticLabel(Object status, Object duration) {
    return '$status，$duration';
  }

  @override
  String get courses_summary_overview => '概览';

  @override
  String get courses_summary_quickActions => '快捷操作';

  @override
  String get courses_summary_recentCourses => '最近的课程';

  @override
  String get courses_summary_selectHint => '从列表中选择课程以查看详情';

  @override
  String get courses_summary_title => '培训课程';

  @override
  String get courses_summary_total => '总计';

  @override
  String get courses_title => '培训课程';

  @override
  String get courses_title_edit => '编辑课程';

  @override
  String get courses_title_new => '新课程';

  @override
  String get courses_title_singular => '课程';

  @override
  String get courses_validation_nameRequired => '请输入课程名称';

  @override
  String get dashboard_activity_daySinceDiving => '距上次潜水天数';

  @override
  String get dashboard_activity_daysSinceDiving => '距上次潜水天数';

  @override
  String dashboard_activity_diveInYear(Object year) {
    return '$year年潜水';
  }

  @override
  String get dashboard_activity_diveThisMonth => '本月潜水';

  @override
  String dashboard_activity_divesInYear(Object year) {
    return '$year 年潜水次数';
  }

  @override
  String get dashboard_activity_divesThisMonth => '本月潜水次数';

  @override
  String get dashboard_activity_error => '错误';

  @override
  String get dashboard_activity_lastDive => '上次潜水';

  @override
  String get dashboard_activity_loading => '加载中';

  @override
  String get dashboard_activity_noDivesYet => '暂无潜水';

  @override
  String get dashboard_activity_today => '今天!';

  @override
  String get dashboard_alerts_actionUpdate => '更新';

  @override
  String get dashboard_alerts_actionView => '查看';

  @override
  String get dashboard_alerts_checkInsuranceExpiry => '请检查您的保险到期日期';

  @override
  String get dashboard_alerts_daysOverdueOne => '逾期 1 天';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return '已逾期 $count 天';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => '1 天后到期';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return '$count 天后到期';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return '$name 需要维护';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return '$name 维护已逾期';
  }

  @override
  String get dashboard_alerts_insuranceExpired => '保险已过期';

  @override
  String get dashboard_alerts_insuranceExpiredGeneric => '您的潜水保险已过期';

  @override
  String dashboard_alerts_insuranceExpiredProvider(Object provider) {
    return '$provider 已过期';
  }

  @override
  String dashboard_alerts_insuranceExpiresDate(Object date) {
    return '到期 $date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon => '保险即将到期';

  @override
  String get dashboard_alerts_sectionTitle => '提醒与通知';

  @override
  String get dashboard_alerts_serviceDueToday => '今天需要维护';

  @override
  String get dashboard_alerts_serviceIntervalReached => '已达维护间隔';

  @override
  String get dashboard_defaultDiverName => '潜水员';

  @override
  String get dashboard_greeting_afternoon => '下午好';

  @override
  String get dashboard_greeting_evening => '晚上好';

  @override
  String get dashboard_greeting_morning => '上午好';

  @override
  String dashboard_greeting_withName(Object greeting, Object name) {
    return '$greeting, $name!';
  }

  @override
  String dashboard_greeting_withoutName(Object greeting) {
    return '$greeting!';
  }

  @override
  String get dashboard_hero_divesLoggedOne => '已记录 1 次潜水';

  @override
  String dashboard_hero_divesLoggedOther(Object count) {
    return '已记录 $count 次潜水';
  }

  @override
  String get dashboard_hero_error => '准备好探索深海了吗？';

  @override
  String dashboard_hero_hoursUnderwater(Object hours) {
    return '水下 $hours 小时';
  }

  @override
  String get dashboard_hero_loading => '正在加载您的潜水统计...';

  @override
  String dashboard_hero_minutesUnderwater(Object minutes) {
    return '水下 $minutes 分钟';
  }

  @override
  String get dashboard_hero_noDives => '准备好记录您的第一次潜水了吗？';

  @override
  String get dashboard_hero_divesLoggedLabel => '次潜水记录';

  @override
  String get dashboard_hero_hoursUnderwaterLabel => '小时水下时间';

  @override
  String get dashboard_hero_daysSinceLabel => '天前最后一潜';

  @override
  String get dashboard_hero_thisMonthLabel => '本月';

  @override
  String get dashboard_hero_thisYearLabel => '今年潜水次数';

  @override
  String get dashboard_hero_todayLabel => '今天！';

  @override
  String get dashboard_hero_noDivesLabel => '暂无潜水记录';

  @override
  String get dashboard_hero_diverFallbackName => '潜水员';

  @override
  String dashboard_activityStats_divesInYear(String year) {
    return '$year年潜水次数';
  }

  @override
  String get dashboard_semantics_statsBar => '潜水统计摘要';

  @override
  String get dashboard_personalRecords_coldest => '最冷';

  @override
  String get dashboard_personalRecords_deepest => '最深';

  @override
  String get dashboard_personalRecords_longest => '最长';

  @override
  String get dashboard_personalRecords_sectionTitle => '个人记录';

  @override
  String get dashboard_personalRecords_warmest => '最暖';

  @override
  String get dashboard_quickActions_addSite => '添加潜水点';

  @override
  String get dashboard_quickActions_addSiteTooltip => '添加新的潜水点';

  @override
  String get dashboard_quickActions_logDive => '记录潜水';

  @override
  String get dashboard_quickActions_logDiveTooltip => '记录新潜水';

  @override
  String get dashboard_quickActions_planDive => '计划潜水';

  @override
  String get dashboard_quickActions_planDiveTooltip => '计划新潜水';

  @override
  String get dashboard_quickActions_sectionTitle => '快捷操作';

  @override
  String get dashboard_quickActions_statistics => '统计';

  @override
  String get dashboard_quickActions_statisticsTooltip => '查看潜水统计';

  @override
  String get dashboard_quickStats_countries => '国家';

  @override
  String get dashboard_quickStats_countriesSubtitle => '已访问';

  @override
  String get dashboard_quickStats_sectionTitle => '概览';

  @override
  String get dashboard_quickStats_species => '物种';

  @override
  String get dashboard_quickStats_speciesSubtitle => '已发现';

  @override
  String get dashboard_quickStats_topBuddy => '最佳潜伴';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count 次潜水';
  }

  @override
  String get dashboard_recentDives_empty => '尚未记录潜水';

  @override
  String get dashboard_recentDives_errorLoading => '加载潜水记录失败';

  @override
  String get dashboard_recentDives_logFirst => '记录您的第一次潜水';

  @override
  String get dashboard_recentDives_sectionTitle => '最近的潜水';

  @override
  String get dashboard_recentDives_viewAll => '查看全部';

  @override
  String get dashboard_recentDives_viewAllTooltip => '查看全部潜水记录';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count 条活动提醒';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives => '错误：加载最近潜水记录失败';

  @override
  String get dashboard_semantics_errorLoadingStatistics => '错误：加载统计数据失败';

  @override
  String get dashboard_semantics_greetingBanner => '仪表盘问候横幅';

  @override
  String get dashboard_stats_errorLoadingStatistics => '加载统计数据失败';

  @override
  String get dashboard_stats_hoursLogged => '小时已记录';

  @override
  String get dashboard_stats_maxDepth => '最大深度';

  @override
  String get dashboard_stats_sitesVisited => '已访问潜水点';

  @override
  String get dashboard_stats_totalDives => '总计潜水';

  @override
  String get decoCalculator_addToPlanner => '添加到计划';

  @override
  String decoCalculator_bottomTimeSemantics(Object time) {
    return '底部时间：$time 分钟';
  }

  @override
  String get decoCalculator_createPlanTooltip => '根据当前参数创建潜水计划';

  @override
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  ) {
    return '已创建计划：$depth$depthSymbol，$time分钟，使用 $gasMixName';
  }

  @override
  String get decoCalculator_customMixTrimix => '自定义混合气（三混气）';

  @override
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol) {
    return '深度: $depth $depthSymbol';
  }

  @override
  String get decoCalculator_diveParameters => '潜水参数';

  @override
  String get decoCalculator_endCaution => '注意';

  @override
  String get decoCalculator_endDanger => '危险';

  @override
  String get decoCalculator_endSafe => '安全';

  @override
  String get decoCalculator_field_bottomTime => '底部时间';

  @override
  String get decoCalculator_field_depth => '深度';

  @override
  String get decoCalculator_field_gasMix => '气体混合';

  @override
  String get decoCalculator_gasSafety => '气体安全';

  @override
  String get decoCalculator_hideCustomMix => '隐藏自定义混合气';

  @override
  String get decoCalculator_hideCustomMixSemantics => '隐藏自定义混合气选择器';

  @override
  String get decoCalculator_modExceeded => '超过最大作业深度';

  @override
  String get decoCalculator_modSafe => '最大作业深度安全';

  @override
  String get decoCalculator_ppO2Caution => '氧分压注意';

  @override
  String get decoCalculator_ppO2Danger => '氧分压危险';

  @override
  String get decoCalculator_ppO2Hypoxic => '氧分压低氧';

  @override
  String get decoCalculator_ppO2Safe => '氧分压安全';

  @override
  String get decoCalculator_resetToDefaults => '重置为默认值';

  @override
  String get decoCalculator_showCustomMixSemantics => '显示自定义混合气选择器';

  @override
  String decoCalculator_timeValueMin(Object time) {
    return '$time 分钟';
  }

  @override
  String get decoCalculator_title => '减压计算器';

  @override
  String diveCenters_accessibility_markerLabel(Object name) {
    return '潜水中心：$name';
  }

  @override
  String get diveCenters_accessibility_selected => '已选择';

  @override
  String diveCenters_accessibility_viewDetails(Object name) {
    return '查看 $name 的详细信息';
  }

  @override
  String get diveCenters_accessibility_viewDives => '查看在此潜水中心的潜水记录';

  @override
  String get diveCenters_accessibility_viewFullscreenMap => '查看全屏地图';

  @override
  String diveCenters_accessibility_viewSavedCenter(Object name) {
    return '查看已保存的潜水中心 $name';
  }

  @override
  String get diveCenters_action_addCenter => '添加潜水中心';

  @override
  String get diveCenters_action_addNew => '新建';

  @override
  String get diveCenters_action_clearRating => '清除';

  @override
  String get diveCenters_action_gettingLocation => '获取中...';

  @override
  String get diveCenters_action_import => '导入';

  @override
  String get diveCenters_action_importToMyCenters => '导入到我的潜水中心';

  @override
  String get diveCenters_action_lookingUp => '查找中...';

  @override
  String get diveCenters_action_lookupFromAddress => '按地址查找';

  @override
  String get diveCenters_action_pickFromMap => '从地图选择';

  @override
  String get diveCenters_action_retry => '重试';

  @override
  String get diveCenters_action_settings => '设置';

  @override
  String get diveCenters_action_useMyLocation => '使用我的位置';

  @override
  String get diveCenters_action_view => '查看';

  @override
  String diveCenters_detail_divesLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已记录 $count 次潜水',
      one: '已记录 1 次潜水',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_detail_divesWithCenter => '在此潜水中心的潜水';

  @override
  String get diveCenters_detail_noDivesLogged => '尚未记录潜水';

  @override
  String diveCenters_dialog_deleteMessage(Object name) {
    return '确定要删除 \"$name\"?';
  }

  @override
  String get diveCenters_dialog_deleteTitle => '删除潜水中心';

  @override
  String get diveCenters_dialog_discard => '丢弃';

  @override
  String get diveCenters_dialog_discardMessage => '您有未保存的更改。确定要丢弃吗?';

  @override
  String get diveCenters_dialog_discardTitle => '丢弃更改？';

  @override
  String get diveCenters_dialog_keepEditing => '继续编辑';

  @override
  String get diveCenters_empty_button => '添加您的第一个潜水中心';

  @override
  String get diveCenters_empty_subtitle => '添加您喜爱的潜水店和运营商';

  @override
  String get diveCenters_empty_title => '暂无潜水中心';

  @override
  String diveCenters_error_generic(Object error) {
    return '错误： $error';
  }

  @override
  String get diveCenters_error_geocodeFailed => '无法找到此地址的坐标';

  @override
  String get diveCenters_error_importFailed => '导入失败潜水中心';

  @override
  String diveCenters_error_loading(Object error) {
    return '加载出错潜水中心: $error';
  }

  @override
  String get diveCenters_error_locationPermission => '无法获取位置。请检查权限。';

  @override
  String get diveCenters_error_locationUnavailable => '无法获取位置。定位服务可能不可用。';

  @override
  String get diveCenters_error_noAddressForLookup => '请输入地址以查找坐标';

  @override
  String get diveCenters_error_notFound => '未找到潜水中心';

  @override
  String diveCenters_error_saving(Object error) {
    return '保存出错潜水中心: $error';
  }

  @override
  String get diveCenters_error_unknown => '未知错误';

  @override
  String get diveCenters_field_city => '城市';

  @override
  String get diveCenters_field_country => '国家';

  @override
  String get diveCenters_field_latitude => '纬度';

  @override
  String get diveCenters_field_longitude => '经度';

  @override
  String get diveCenters_field_nameRequired => '名称 *';

  @override
  String get diveCenters_field_postalCode => '邮政代码';

  @override
  String get diveCenters_field_rating => '评分';

  @override
  String get diveCenters_field_stateProvince => '州/省';

  @override
  String get diveCenters_field_street => '街道地址';

  @override
  String get diveCenters_hint_addressDescription => '可选的导航街道地址';

  @override
  String get diveCenters_hint_affiliationsDescription => '选择此中心所属的培训机构';

  @override
  String get diveCenters_hint_city => '例如，普吉岛';

  @override
  String get diveCenters_hint_country => '例如，泰国';

  @override
  String get diveCenters_hint_email => 'info@divecenter.com';

  @override
  String get diveCenters_hint_gpsDescription => '选择定位方式或手动输入坐标';

  @override
  String get diveCenters_hint_importSearch => '搜索潜水中心（例如「PADI」、「泰国」）';

  @override
  String get diveCenters_hint_latitude => 'e.g., 10.4613';

  @override
  String get diveCenters_hint_longitude => 'e.g., 99.8359';

  @override
  String get diveCenters_hint_name => '输入潜水中心名称';

  @override
  String get diveCenters_hint_notes => '其他补充信息...';

  @override
  String get diveCenters_hint_phone => '+1 234 567 890';

  @override
  String get diveCenters_hint_postalCode => 'e.g., 83100';

  @override
  String get diveCenters_hint_stateProvince => '例如，普吉岛';

  @override
  String get diveCenters_hint_street => '例如，海滩路123号';

  @override
  String get diveCenters_hint_website => 'www.divecenter.com';

  @override
  String diveCenters_import_fromDatabase(Object count) {
    return '从数据库导入 ($count)';
  }

  @override
  String diveCenters_import_myCenters(Object count) {
    return '我的潜水中心 ($count)';
  }

  @override
  String get diveCenters_import_noResults => '无结果';

  @override
  String diveCenters_import_noResultsMessage(Object query) {
    return '未找到与「$query」匹配的潜水中心。请尝试其他搜索词。';
  }

  @override
  String get diveCenters_import_searchDescription =>
      '从我们的全球运营商数据库中搜索潜水中心、潜水店和俱乐部。';

  @override
  String get diveCenters_import_searchError => '搜索错误';

  @override
  String get diveCenters_import_searchHint => '尝试按名称、国家或认证机构搜索。';

  @override
  String get diveCenters_import_searchTitle => '搜索潜水中心';

  @override
  String get diveCenters_label_alreadyImported => '已导入';

  @override
  String diveCenters_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次潜水',
      one: '1 次潜水',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_label_email => '电子邮件';

  @override
  String get diveCenters_label_imported => '已导入';

  @override
  String get diveCenters_label_locationNotSet => '未设置位置';

  @override
  String get diveCenters_label_locationUnknown => '位置未知';

  @override
  String get diveCenters_label_phone => '电话';

  @override
  String get diveCenters_label_saved => '已保存';

  @override
  String diveCenters_label_source(Object source) {
    return '来源: $source';
  }

  @override
  String get diveCenters_label_website => '网站';

  @override
  String get diveCenters_map_addCoordinatesHint => '为您的潜水中心添加坐标以在地图上显示';

  @override
  String get diveCenters_map_noCoordinates => '没有带坐标的潜水中心';

  @override
  String get diveCenters_picker_newCenter => '新建潜水中心';

  @override
  String get diveCenters_picker_title => '选择潜水中心';

  @override
  String diveCenters_search_noResults(Object query) {
    return '未找到“$query”的结果';
  }

  @override
  String get diveCenters_search_prompt => '搜索潜水中心';

  @override
  String get diveCenters_section_address => '地址';

  @override
  String get diveCenters_section_affiliations => '所属机构';

  @override
  String get diveCenters_section_basicInfo => '基本信息';

  @override
  String get diveCenters_section_contact => '联系人';

  @override
  String get diveCenters_section_contactInfo => '联系信息';

  @override
  String get diveCenters_section_gpsCoordinates => 'GPS 坐标';

  @override
  String get diveCenters_section_notes => '备注';

  @override
  String get diveCenters_snackbar_coordinatesFound => '已从地址获取坐标';

  @override
  String get diveCenters_snackbar_copiedToClipboard => '已复制到剪贴板';

  @override
  String diveCenters_snackbar_imported(Object name) {
    return '已导入“$name”';
  }

  @override
  String get diveCenters_snackbar_locationCaptured => '位置已获取';

  @override
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return '已捕获位置（精度 ±${accuracy}m）';
  }

  @override
  String get diveCenters_snackbar_locationSelectedFromMap => '已从地图选择位置';

  @override
  String get diveCenters_sort_title => '排序潜水中心';

  @override
  String get diveCenters_summary_countries => '国家';

  @override
  String get diveCenters_summary_highestRating => '最高评分';

  @override
  String get diveCenters_summary_overview => '概览';

  @override
  String get diveCenters_summary_quickActions => '快捷操作';

  @override
  String get diveCenters_summary_recentCenters => '最近潜水中心';

  @override
  String get diveCenters_summary_selectPrompt => '从列表中选择潜水中心以查看详情';

  @override
  String get diveCenters_summary_topRated => '评分最高';

  @override
  String get diveCenters_summary_totalCenters => '中心总数';

  @override
  String get diveCenters_summary_withGps => '有 GPS';

  @override
  String get diveCenters_title => '潜水中心';

  @override
  String get diveCenters_title_add => '添加潜水中心';

  @override
  String get diveCenters_title_edit => '编辑潜水中心';

  @override
  String get diveCenters_title_import => '导入潜水中心';

  @override
  String get diveCenters_tooltip_addNew => '添加新的潜水中心';

  @override
  String get diveCenters_tooltip_clearSearch => '清除搜索';

  @override
  String get diveCenters_tooltip_edit => '编辑潜水中心';

  @override
  String get diveCenters_tooltip_fitAllCenters => '显示全部潜水中心';

  @override
  String get diveCenters_tooltip_listView => '列表视图';

  @override
  String get diveCenters_tooltip_mapView => '地图视图';

  @override
  String get diveCenters_tooltip_moreOptions => '更多选项';

  @override
  String get diveCenters_tooltip_search => '搜索潜水中心';

  @override
  String get diveCenters_tooltip_sort => '排序';

  @override
  String get diveCenters_validation_invalidEmail => '请输入有效的电子邮件';

  @override
  String get diveCenters_validation_invalidLatitude => '无效的纬度';

  @override
  String get diveCenters_validation_invalidLongitude => '无效的经度';

  @override
  String get diveCenters_validation_nameRequired => '名称为必填项';

  @override
  String get diveComputer_action_setFavorite => '设为常用';

  @override
  String diveComputer_error_generic(Object error) {
    return '发生错误：$error';
  }

  @override
  String get diveComputer_error_notFound => '未找到设备';

  @override
  String get diveComputer_status_favorite => '常用潜水电脑';

  @override
  String get diveComputer_title => '潜水电脑';

  @override
  String diveLog_bulkDelete_confirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次潜水',
      one: '次潜水',
    );
    return '确定要删除 $count $_temp0吗？此操作无法撤消。';
  }

  @override
  String get diveLog_bulkDelete_restored => '潜水已恢复';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次潜水',
      one: '次潜水',
    );
    return '已删除 $count $_temp0';
  }

  @override
  String get diveLog_bulkDelete_title => '删除潜水';

  @override
  String get diveLog_bulkDelete_undo => '撤消';

  @override
  String get diveLog_bulkEdit_addTags => '添加标签';

  @override
  String get diveLog_bulkEdit_addTagsDescription => '为所选潜水添加标签';

  @override
  String diveLog_bulkEdit_addedTags(int tagCount, int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: '个标签',
      one: '个标签',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '次潜水',
      one: '次潜水',
    );
    return '已将 $tagCount $_temp0添加到 $diveCount $_temp1';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => '更改旅行';

  @override
  String get diveLog_bulkEdit_changeTripDescription => '将所选潜水移动到某个旅行';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips => '加载旅行出错';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return '添加标签失败：$error';
  }

  @override
  String diveLog_bulkEdit_failedUpdateTrip(Object error) {
    return '更新旅行失败：$error';
  }

  @override
  String diveLog_bulkEdit_movedToTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次潜水',
      one: '次潜水',
    );
    return '已将 $count $_temp0移至旅行';
  }

  @override
  String get diveLog_bulkEdit_noTagsAvailable => '暂无可用标签。';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate => '暂无可用标签。请先创建标签。';

  @override
  String get diveLog_bulkEdit_noTrip => '无旅行';

  @override
  String get diveLog_bulkEdit_removeFromTrip => '从旅行中移除';

  @override
  String get diveLog_bulkEdit_removeTags => '移除标签';

  @override
  String get diveLog_bulkEdit_removeTagsDescription => '从所选潜水中移除标签';

  @override
  String diveLog_bulkEdit_removedFromTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次潜水',
      one: '次潜水',
    );
    return '已将 $count $_temp0从旅行中移除';
  }

  @override
  String get diveLog_bulkEdit_selectTrip => '选择旅行';

  @override
  String diveLog_bulkEdit_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次潜水',
      one: '次潜水',
    );
    return '编辑 $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_csv => 'CSV';

  @override
  String get diveLog_bulkExport_csvDescription => '电子表格格式';

  @override
  String diveLog_bulkExport_failed(Object error) {
    return '导出失败：$error';
  }

  @override
  String get diveLog_bulkExport_pdf => 'PDF 日志本';

  @override
  String get diveLog_bulkExport_pdfDescription => '可打印的潜水日志页';

  @override
  String diveLog_bulkExport_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次潜水',
      one: '次潜水',
    );
    return '成功导出 $count $_temp0';
  }

  @override
  String diveLog_bulkExport_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次潜水',
      one: '次潜水',
    );
    return '导出 $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_uddf => 'UDDF';

  @override
  String get diveLog_bulkExport_uddfDescription => '通用潜水数据格式';

  @override
  String get diveLog_ccr_diluent_air => '空气';

  @override
  String get diveLog_ccr_hint_loopVolume => '例如，6.0';

  @override
  String get diveLog_ccr_hint_type => '例如：Sofnolime';

  @override
  String get diveLog_ccr_label_deco => '减压';

  @override
  String get diveLog_ccr_label_he => 'He';

  @override
  String get diveLog_ccr_label_highBottom => '高（底部）';

  @override
  String get diveLog_ccr_label_loopVolume => '回路容积';

  @override
  String get diveLog_ccr_label_lowDescAsc => '低（下降/上升）';

  @override
  String get diveLog_ccr_label_n2 => 'N₂';

  @override
  String get diveLog_ccr_label_o2 => 'O₂';

  @override
  String get diveLog_ccr_label_rated => '额定';

  @override
  String get diveLog_ccr_label_remaining => '剩余';

  @override
  String get diveLog_ccr_label_type => '类型';

  @override
  String get diveLog_ccr_sectionDiluentGas => '稀释气体';

  @override
  String get diveLog_ccr_sectionScrubber => '二氧化碳吸收剂';

  @override
  String get diveLog_ccr_sectionSetpoints => '设定点 (bar)';

  @override
  String get diveLog_ccr_title => '密闭循环呼吸器设置';

  @override
  String diveLog_collapsible_semantics_collapse(Object title) {
    return '折叠$title部分';
  }

  @override
  String diveLog_collapsible_semantics_expand(Object title) {
    return '展开$title部分';
  }

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return '平均：$depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => '基础';

  @override
  String get diveLog_cylinderSac_noSac => 'SAC：--';

  @override
  String get diveLog_cylinderSac_tooltip_aiData => '使用 AI 发射器数据以获得更高精度';

  @override
  String get diveLog_cylinderSac_tooltip_basicData => '根据起始/结束压力计算';

  @override
  String get diveLog_deco_badge_deco => '减压';

  @override
  String get diveLog_deco_badge_noDeco => '免减压';

  @override
  String get diveLog_deco_label_ceiling => '上升限制';

  @override
  String get diveLog_deco_label_leading => '主导';

  @override
  String get diveLog_deco_label_gf99 => 'GF99';

  @override
  String get diveLog_deco_label_surfGf => '水面GF';

  @override
  String get diveLog_deco_label_ndl => '免减压极限';

  @override
  String get diveLog_deco_label_time => '时间';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String get diveLog_deco_sectionDecoStops => '减压停留';

  @override
  String get diveLog_deco_sectionTissueLoading => '组织饱和度';

  @override
  String get diveLog_deco_semantics_notRequired => '不需要减压';

  @override
  String get diveLog_deco_semantics_required => '需要减压';

  @override
  String get diveLog_deco_tissueFast => '快速';

  @override
  String get diveLog_deco_tissueSlow => '慢速';

  @override
  String get diveLog_deco_title => '减压状态';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return '总计：$time';
  }

  @override
  String get diveLog_delete_cancel => '取消';

  @override
  String get diveLog_delete_confirm => '此操作无法撤消。潜水及所有关联数据（轮廓、气瓶、目击）将被永久删除。';

  @override
  String get diveLog_delete_delete => '删除';

  @override
  String get diveLog_delete_title => '删除潜水？';

  @override
  String get diveLog_detail_appBar => '潜水详情';

  @override
  String get diveLog_detail_badge_critical => '危急';

  @override
  String get diveLog_detail_badge_deco => '减压';

  @override
  String get diveLog_detail_badge_noDeco => '免减压';

  @override
  String get diveLog_detail_badge_warning => '警告';

  @override
  String diveLog_detail_buddyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '位潜伴',
      one: '位潜伴',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_button_playback => '回放';

  @override
  String get diveLog_detail_button_rangeAnalysis => '范围统计';

  @override
  String get diveLog_detail_button_showEnd => '显示结束';

  @override
  String get diveLog_detail_captureSignature => '采集教练签名';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return '$timestamp';
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
    return '上升限制：$value';
  }

  @override
  String diveLog_detail_collapsed_cnsMaxPpO2(Object cns, Object maxPpO2) {
    return '中枢神经系统：$cns • 最大氧分压：$maxPpO2';
  }

  @override
  String diveLog_detail_collapsed_cnsMaxPpO2AtTime(
    Object cns,
    Object maxPpO2,
    Object timestamp,
    Object ppO2,
  ) {
    return '中枢神经系统毒性：$cns · 最大氧分压：$maxPpO2 · 在 $timestamp：$ppO2 bar';
  }

  @override
  String diveLog_detail_collapsed_ndl(Object value) {
    return '免减压极限：$value';
  }

  @override
  String diveLog_detail_customFieldCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个字段',
      one: '1 个字段',
    );
    return '$_temp0';
  }

  @override
  String diveLog_detail_equipmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '件装备',
      one: '件装备',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_errorLoading => '加载潜水出错';

  @override
  String get diveLog_detail_fullscreen_sampleData => '采样数据';

  @override
  String get diveLog_detail_fullscreen_tapChartCompact => '点击图表切换紧凑视图';

  @override
  String get diveLog_detail_fullscreen_tapChartFull => '点击图表切换全屏视图';

  @override
  String get diveLog_detail_fullscreen_touchChart => '触摸图表查看该点的数据';

  @override
  String get diveLog_detail_label_airTemp => '气温';

  @override
  String get diveLog_detail_label_avgDepth => '平均深度';

  @override
  String get diveLog_detail_label_buddy => '潜伴';

  @override
  String get diveLog_detail_label_currentDirection => '水流方向';

  @override
  String get diveLog_detail_label_currentStrength => '水流强度';

  @override
  String get diveLog_detail_label_diveComputer => '潜水电脑';

  @override
  String get diveLog_detail_label_serialNumber => '序列号';

  @override
  String get diveLog_detail_label_firmwareVersion => '固件版本';

  @override
  String get diveLog_detail_label_diveMaster => '潜水长';

  @override
  String get diveLog_detail_label_diveType => '潜水类型';

  @override
  String get diveLog_detail_label_elevation => '海拔';

  @override
  String get diveLog_detail_label_entry => '入水：';

  @override
  String get diveLog_detail_label_entryMethod => '入水方式';

  @override
  String get diveLog_detail_label_exit => '出水：';

  @override
  String get diveLog_detail_label_exitMethod => '出水方式';

  @override
  String get diveLog_detail_label_gradientFactors => '梯度因子';

  @override
  String get diveLog_detail_label_height => '高度';

  @override
  String get diveLog_detail_label_highTide => '高潮';

  @override
  String get diveLog_detail_label_lowTide => '低潮';

  @override
  String get diveLog_detail_label_ppO2AtPoint => '所选点的氧分压：';

  @override
  String get diveLog_detail_label_rateOfChange => '变化率';

  @override
  String get diveLog_detail_label_sacRate => '气体消耗率';

  @override
  String get diveLog_detail_label_state => '状态';

  @override
  String get diveLog_detail_label_surfaceInterval => '水面间隔';

  @override
  String get diveLog_detail_label_surfacePressure => '水面压力';

  @override
  String get diveLog_detail_label_swellHeight => '涌浪高度';

  @override
  String get diveLog_detail_label_total => '总计：';

  @override
  String get diveLog_detail_label_visibility => '能见度';

  @override
  String get diveLog_detail_label_waterType => '水类型';

  @override
  String get diveLog_detail_menu_delete => '删除';

  @override
  String get diveLog_detail_menu_export => '导出';

  @override
  String get diveLog_detail_menu_openFullPage => '打开完整页面';

  @override
  String get diveLog_detail_noNotes => '此次潜水无备注。';

  @override
  String get diveLog_detail_notFound => '未找到潜水';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count 个数据点';
  }

  @override
  String get diveLog_detail_section_altitudeDive => '高海拔潜水';

  @override
  String get diveLog_detail_section_buddies => '潜伴';

  @override
  String get diveLog_detail_section_conditions => '条件';

  @override
  String get diveLog_detail_section_customFields => '自定义字段';

  @override
  String get diveLog_detail_section_decoStatus => '减压状态';

  @override
  String get diveLog_detail_section_details => '详情';

  @override
  String get diveLog_detail_section_diveProfile => '潜水轮廓';

  @override
  String get diveLog_detail_section_equipment => '装备';

  @override
  String get diveLog_detail_section_marineLife => '海洋生物';

  @override
  String get diveLog_detail_section_notes => '备注';

  @override
  String get diveLog_detail_section_oxygenToxicity => '氧中毒';

  @override
  String get diveLog_detail_section_sacByCylinder => '按气瓶的气体消耗率';

  @override
  String get diveLog_detail_section_sacRateBySegment => '按分段的气体消耗率';

  @override
  String get diveLog_detail_section_tags => '标签';

  @override
  String get diveLog_detail_section_tanks => '气瓶';

  @override
  String get diveLog_detail_section_tide => '潮汐';

  @override
  String get diveLog_detail_section_trainingSignature => '培训签名';

  @override
  String get diveLog_detail_section_weight => '配重';

  @override
  String get diveLog_detail_signatureDescription => '点击为此培训潜水添加教练验证';

  @override
  String get diveLog_detail_soloDive => '单人潜水或未记录潜伴';

  @override
  String diveLog_detail_speciesCount(Object count) {
    return '$count 种物种';
  }

  @override
  String get diveLog_detail_stat_bottomTime => '底部时间';

  @override
  String get diveLog_detail_stat_maxDepth => '最大深度';

  @override
  String get diveLog_detail_stat_runtime => '运行时间';

  @override
  String get diveLog_detail_stat_waterTemp => '水温';

  @override
  String diveLog_detail_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '个标签',
      one: '个标签',
    );
    return '$count $_temp0';
  }

  @override
  String diveLog_detail_tankCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '个气瓶',
      one: '个气瓶',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_tideCalculated => '根据潮汐模型计算';

  @override
  String get diveLog_detail_tooltip_addToFavorites => '添加到收藏';

  @override
  String get diveLog_detail_tooltip_edit => '编辑';

  @override
  String get diveLog_detail_tooltip_editDive => '编辑潜水';

  @override
  String get diveLog_detail_tooltip_exportProfileImage => '导出轮廓为图片';

  @override
  String get diveLog_detail_tooltip_removeFromFavorites => '从收藏中移除';

  @override
  String get diveLog_detail_tooltip_viewFullscreen => '查看全屏';

  @override
  String get diveLog_detail_viewSite => '查看潜水点';

  @override
  String get diveLog_diveMode_ccrDescription => '密闭循环呼吸器，恒定氧分压';

  @override
  String get diveLog_diveMode_ocDescription => '标准开放式气瓶水肺潜水';

  @override
  String get diveLog_diveMode_scrDescription => '半密闭循环呼吸器，可变氧分压';

  @override
  String get diveLog_diveMode_title => '潜水模式';

  @override
  String get diveLog_editSighting_count => '数量';

  @override
  String get diveLog_editSighting_notes => '备注';

  @override
  String get diveLog_editSighting_notesHint => '大小、行为、位置...';

  @override
  String get diveLog_editSighting_remove => '移除';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return '从此次潜水中移除 $name？';
  }

  @override
  String get diveLog_editSighting_removeTitle => '移除目击？';

  @override
  String get diveLog_editSighting_save => '保存更改';

  @override
  String get diveLog_edit_add => '添加';

  @override
  String get diveLog_edit_addCustomField => '添加字段';

  @override
  String get diveLog_edit_addTank => '添加气瓶';

  @override
  String get diveLog_edit_addWeightEntry => '添加配重条目';

  @override
  String diveLog_edit_addedGps(Object name) {
    return '已为 $name 添加 GPS';
  }

  @override
  String get diveLog_edit_appBarEdit => '编辑潜水';

  @override
  String get diveLog_edit_appBarNew => '记录潜水';

  @override
  String get diveLog_edit_cancel => '取消';

  @override
  String get diveLog_edit_clearAllEquipment => '清除全部';

  @override
  String diveLog_edit_createdSite(Object name) {
    return '已创建潜水点：$name';
  }

  @override
  String get diveLog_edit_customFieldKey => '键';

  @override
  String get diveLog_edit_customFieldKeyHint => '例如：camera_settings';

  @override
  String get diveLog_edit_customFieldValue => '值';

  @override
  String get diveLog_edit_customFieldValueHint => '例如，f/8 ISO400';

  @override
  String diveLog_edit_durationMinutes(Object minutes) {
    return '时长：$minutes 分钟';
  }

  @override
  String get diveLog_edit_equipmentHint => '点击「使用套装」或「添加」选择装备';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return '加载潜水类型出错：$error';
  }

  @override
  String get diveLog_edit_gettingLocation => '正在获取位置...';

  @override
  String get diveLog_edit_headerNew => '记录新潜水';

  @override
  String get diveLog_edit_label_airTemp => '气温';

  @override
  String get diveLog_edit_label_altitude => '海拔';

  @override
  String get diveLog_edit_label_avgDepth => '平均深度';

  @override
  String get diveLog_edit_label_bottomTime => '底部时间';

  @override
  String get diveLog_edit_label_currentDirection => '水流方向';

  @override
  String get diveLog_edit_label_currentStrength => '水流强度';

  @override
  String get diveLog_edit_label_diveType => '潜水类型';

  @override
  String get diveLog_edit_label_diveNumber => '潜水编号';

  @override
  String get diveLog_edit_hint_diveNumber => '留空则自动分配';

  @override
  String get diveLog_edit_label_entryMethod => '入水方式';

  @override
  String get diveLog_edit_label_exitMethod => '出水方式';

  @override
  String get diveLog_edit_label_maxDepth => '最大深度';

  @override
  String get diveLog_edit_label_runtime => '运行时间';

  @override
  String get diveLog_edit_label_surfacePressure => '水面压力';

  @override
  String get diveLog_edit_label_swellHeight => '涌浪高度';

  @override
  String get diveLog_edit_label_type => '类型';

  @override
  String get diveLog_edit_label_visibility => '能见度';

  @override
  String get diveLog_edit_label_waterTemp => '水温';

  @override
  String get diveLog_edit_label_waterType => '水类型';

  @override
  String get diveLog_edit_marineLifeHint => '点击「添加」记录目击';

  @override
  String get diveLog_edit_nearbySitesFirst => '优先显示附近潜水点';

  @override
  String get diveLog_edit_noEquipmentSelected => '未选择装备';

  @override
  String get diveLog_edit_noMarineLife => '未记录海洋生物';

  @override
  String get diveLog_edit_notSpecified => '未指定';

  @override
  String get diveLog_edit_notesHint => '添加关于此次潜水的备注...';

  @override
  String get diveLog_edit_save => '保存';

  @override
  String get diveLog_edit_saveAsSet => '保存为套装';

  @override
  String diveLog_edit_saveAsSetDialog_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '件装备',
      one: '件装备',
    );
    return '将 $count $_temp0保存为新的装备套装。';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description => '描述（可选）';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint => '例如，温暖水域轻装备';

  @override
  String diveLog_edit_saveAsSetDialog_error(Object error) {
    return '创建套装出错：$error';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_setName => '套装名称';

  @override
  String get diveLog_edit_saveAsSetDialog_setNameHint => '例如，热带潜水';

  @override
  String diveLog_edit_saveAsSetDialog_success(Object name) {
    return '装备套装「$name」已创建';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title => '保存为装备套装';

  @override
  String get diveLog_edit_saveAsSetDialog_validation => '请输入套装名称';

  @override
  String get diveLog_edit_section_conditions => '条件';

  @override
  String get diveLog_edit_section_customFields => '自定义字段';

  @override
  String get diveLog_edit_section_depthDuration => '深度与时长';

  @override
  String get diveLog_edit_section_diveCenter => '潜水中心';

  @override
  String get diveLog_edit_section_diveSite => '潜水点';

  @override
  String get diveLog_edit_section_entryTime => '入水时间';

  @override
  String get diveLog_edit_section_equipment => '装备';

  @override
  String get diveLog_edit_section_exitTime => '出水时间';

  @override
  String get diveLog_edit_section_marineLife => '海洋生物';

  @override
  String get diveLog_edit_section_notes => '备注';

  @override
  String get diveLog_edit_section_rating => '评分';

  @override
  String get diveLog_edit_section_tags => '标签';

  @override
  String diveLog_edit_section_tanks(Object count) {
    return '气瓶 ($count)';
  }

  @override
  String get diveLog_edit_section_trainingCourse => '培训课程';

  @override
  String get diveLog_edit_section_trip => '旅行';

  @override
  String get diveLog_edit_section_weight => '配重';

  @override
  String get diveLog_edit_select => '选择';

  @override
  String get diveLog_edit_selectDiveCenter => '选择潜水中心';

  @override
  String get diveLog_edit_selectDiveSite => '选择潜水点';

  @override
  String get diveLog_edit_selectTrip => '选择旅行';

  @override
  String diveLog_edit_snackbar_avgDepthCalculated(Object depth) {
    return '已计算平均深度：$depth';
  }

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return '已计算底部时间：$minutes 分钟';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return '保存潜水出错：$error';
  }

  @override
  String diveLog_edit_snackbar_maxDepthCalculated(Object depth) {
    return '已计算最大深度：$depth';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData => '无可用的潜水轮廓数据';

  @override
  String diveLog_edit_snackbar_runtimeCalculated(Object minutes) {
    return '已计算运行时间：$minutes 分钟';
  }

  @override
  String get diveLog_edit_snackbar_unableToCalculateAvgDepth => '无法从轮廓计算平均深度';

  @override
  String get diveLog_edit_snackbar_unableToCalculate => '无法从轮廓计算底部时间';

  @override
  String get diveLog_edit_snackbar_unableToCalculateMaxDepth => '无法从轮廓计算最大深度';

  @override
  String get diveLog_edit_snackbar_unableToCalculateRuntime => '无法从轮廓计算运行时间';

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return '水面间隔：$interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint => '标准：海平面 1013 mbar';

  @override
  String get diveLog_edit_tooltip_calculateFromProfile => '从潜水轮廓计算';

  @override
  String get diveLog_edit_tooltip_clearDiveCenter => '清除潜水中心';

  @override
  String get diveLog_edit_tooltip_clearSite => '清除潜水点';

  @override
  String get diveLog_edit_tooltip_clearTrip => '清除旅行';

  @override
  String get diveLog_edit_tooltip_removeEquipment => '移除装备';

  @override
  String get diveLog_edit_tooltip_removeSighting => '移除目击';

  @override
  String get diveLog_edit_tooltip_removeWeight => '移除';

  @override
  String get diveLog_edit_trainingCourseHint => '将此次潜水关联到培训课程';

  @override
  String diveLog_edit_tripSuggested(Object name) {
    return '建议：$name';
  }

  @override
  String get diveLog_edit_tripUse => '使用';

  @override
  String get diveLog_edit_useSet => '使用套装';

  @override
  String diveLog_edit_weightTotal(Object total) {
    return '总计：$total';
  }

  @override
  String get diveLog_emptyFiltered_clearFilters => '清除筛选';

  @override
  String get diveLog_emptyFiltered_subtitle => '尝试调整或清除您的筛选条件';

  @override
  String get diveLog_emptyFiltered_title => '没有匹配筛选条件的潜水';

  @override
  String get diveLog_empty_logFirstDive => '记录您的第一次潜水';

  @override
  String get diveLog_empty_subtitle => '点击下方按钮记录您的第一次潜水';

  @override
  String get diveLog_empty_title => '尚未记录潜水';

  @override
  String get diveLog_equipmentPicker_addFromTab => '从装备选项卡添加装备';

  @override
  String get diveLog_equipmentPicker_allSelected => '所有装备已选择';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return '加载装备出错：$error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => '暂无装备';

  @override
  String get diveLog_equipmentPicker_removeToAdd => '移除项目以添加新项目';

  @override
  String get diveLog_equipmentPicker_title => '添加装备';

  @override
  String get diveLog_equipmentSetPicker_createHint => '在装备 > 套装中创建套装';

  @override
  String get diveLog_equipmentSetPicker_emptySet => '空套装';

  @override
  String get diveLog_equipmentSetPicker_errorItems => '加载项目出错';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return '加载装备套装出错：$error';
  }

  @override
  String get diveLog_equipmentSetPicker_loading => '加载中...';

  @override
  String get diveLog_equipmentSetPicker_noSets => '暂无装备套装';

  @override
  String get diveLog_equipmentSetPicker_title => '使用装备套装';

  @override
  String get diveLog_error_loadingDives => '加载潜水出错';

  @override
  String get diveLog_error_retry => '重试';

  @override
  String get diveLog_exportImage_captureFailed => '无法捕获图片';

  @override
  String get diveLog_exportImage_generateFailed => '无法生成图片';

  @override
  String get diveLog_exportImage_generatingPdf => '正在生成 PDF...';

  @override
  String get diveLog_exportImage_pdfSaved => 'PDF 已保存';

  @override
  String get diveLog_exportImage_saveToFiles => '保存到文件';

  @override
  String get diveLog_exportImage_saveToFilesDescription => '选择文件保存位置';

  @override
  String get diveLog_exportImage_saveToPhotos => '保存到相册';

  @override
  String get diveLog_exportImage_saveToPhotosDescription => '将图片保存到您的相册';

  @override
  String get diveLog_exportImage_savedToFiles => '图片已保存';

  @override
  String get diveLog_exportImage_savedToPhotos => '图片已保存到相册';

  @override
  String get diveLog_exportImage_share => '分享';

  @override
  String get diveLog_exportImage_shareDescription => '通过其他应用分享';

  @override
  String get diveLog_exportImage_titleDetails => '导出潜水详情图片';

  @override
  String get diveLog_exportImage_titlePdf => '导出 PDF';

  @override
  String get diveLog_exportImage_titleProfile => '导出轮廓图片';

  @override
  String get diveLog_export_csv => 'CSV';

  @override
  String get diveLog_export_csvDescription => '电子表格格式';

  @override
  String get diveLog_export_exporting => '正在导出...';

  @override
  String diveLog_export_failed(Object error) {
    return '导出失败：$error';
  }

  @override
  String get diveLog_export_pageAsImage => '页面为图片';

  @override
  String get diveLog_export_pageAsImageDescription => '整个潜水详情的截图';

  @override
  String get diveLog_export_pdfDescription => '可打印的潜水日志页';

  @override
  String get diveLog_export_pdfLogbookEntry => 'PDF 日志条目';

  @override
  String get diveLog_export_success => '潜水导出成功';

  @override
  String diveLog_export_titleDiveNumber(Object number) {
    return '导出潜水 #$number';
  }

  @override
  String get diveLog_export_uddf => 'UDDF';

  @override
  String get diveLog_export_uddfDescription => '通用潜水数据格式';

  @override
  String get diveLog_filterChip_clearAll => '清除全部';

  @override
  String get diveLog_filterChip_favorites => '收藏';

  @override
  String diveLog_filterChip_from(Object date) {
    return '从 $date';
  }

  @override
  String diveLog_filterChip_until(Object date) {
    return '至 $date';
  }

  @override
  String get diveLog_filter_allSites => '所有潜水点';

  @override
  String get diveLog_filter_allTypes => '所有类型';

  @override
  String get diveLog_filter_apply => '应用筛选';

  @override
  String get diveLog_filter_buddyHint => '按潜伴姓名搜索';

  @override
  String get diveLog_filter_buddyName => '潜伴姓名';

  @override
  String get diveLog_filter_clearAll => '清除全部';

  @override
  String get diveLog_filter_clearDates => '清除日期';

  @override
  String get diveLog_filter_clearRating => '清除评分筛选';

  @override
  String get diveLog_filter_dateSeparator => '至';

  @override
  String get diveLog_filter_endDate => '结束日期';

  @override
  String get diveLog_filter_errorLoadingSites => '加载潜水点出错';

  @override
  String get diveLog_filter_errorLoadingTags => '加载标签出错';

  @override
  String get diveLog_filter_favoritesOnly => '仅收藏';

  @override
  String get diveLog_filter_gasAir => '空气 (21%)';

  @override
  String get diveLog_filter_gasAll => '全部';

  @override
  String get diveLog_filter_gasNitrox => '高氧空气 (>21%)';

  @override
  String get diveLog_filter_max => '最大';

  @override
  String get diveLog_filter_min => '最小';

  @override
  String get diveLog_filter_noTagsYet => '尚未创建标签';

  @override
  String get diveLog_filter_sectionBuddy => '潜伴';

  @override
  String get diveLog_filter_sectionDateRange => '日期范围';

  @override
  String get diveLog_filter_sectionDepthRange => '深度范围（米）';

  @override
  String get diveLog_filter_sectionDiveSite => '潜水点';

  @override
  String get diveLog_filter_sectionDiveType => '潜水类型';

  @override
  String get diveLog_filter_sectionDuration => '时长（分钟）';

  @override
  String get diveLog_filter_sectionGasMix => '气体混合 (O₂%)';

  @override
  String get diveLog_filter_sectionMinRating => '最低评分';

  @override
  String get diveLog_filter_sectionTags => '标签';

  @override
  String get diveLog_filter_showOnlyFavorites => '仅显示收藏的潜水';

  @override
  String get diveLog_filter_startDate => '开始日期';

  @override
  String get diveLog_filter_title => '筛选潜水';

  @override
  String get diveLog_filter_tooltip_close => '关闭筛选';

  @override
  String get diveLog_fullscreenProfile_close => '关闭全屏';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return '潜水 #$number 轮廓';
  }

  @override
  String get diveLog_legend_label_ascentRate => '上升速率';

  @override
  String get diveLog_legend_label_ceiling => '上升限制';

  @override
  String get diveLog_legend_label_cns => '中枢神经系统%';

  @override
  String get diveLog_legend_label_depth => '深度';

  @override
  String get diveLog_legend_label_events => '事件';

  @override
  String get diveLog_legend_label_gasDensity => '气体密度';

  @override
  String get diveLog_legend_label_gasSwitches => '气体切换';

  @override
  String get diveLog_legend_label_gfPercent => 'GF%';

  @override
  String get diveLog_legend_label_heartRate => '心率';

  @override
  String get diveLog_legend_label_maxDepth => '最大深度';

  @override
  String get diveLog_legend_label_meanDepth => '平均深度';

  @override
  String get diveLog_legend_label_mod => '最大作业深度';

  @override
  String get diveLog_legend_label_ndl => '免减压极限';

  @override
  String get diveLog_legend_label_otu => 'OTU';

  @override
  String get diveLog_legend_label_ppHe => '氦分压';

  @override
  String get diveLog_legend_label_ppN2 => '氮分压';

  @override
  String get diveLog_legend_label_ppO2 => '氧分压';

  @override
  String get diveLog_legend_label_pressure => '压力';

  @override
  String get diveLog_legend_label_pressureThresholds => '压力阈值';

  @override
  String get diveLog_legend_label_sacRate => '气体消耗率';

  @override
  String get diveLog_legend_label_surfaceGf => '水面 GF';

  @override
  String get diveLog_legend_label_temp => '温度';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_legend_source_dc => '潜水电脑';

  @override
  String get diveLog_legend_source_calc => '计算';

  @override
  String get diveLog_chartSection_overlays => '叠加层';

  @override
  String get diveLog_chartSection_markers => '标记';

  @override
  String get diveLog_chartSection_decompression => '减压';

  @override
  String get diveLog_chartSection_gasAnalysis => '气体分析';

  @override
  String get diveLog_chartSection_other => '其他';

  @override
  String get diveLog_chartSection_tankPressures => '气瓶压力';

  @override
  String get diveLog_listPage_appBar_diveMap => '潜水地图';

  @override
  String get diveLog_listPage_compactTitle => '潜水';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return '错误：$error';
  }

  @override
  String get diveLog_listPage_bottomSheet_importFromComputer => '从电脑导入';

  @override
  String get diveLog_listPage_bottomSheet_logManually => '手动记录潜水';

  @override
  String get diveLog_listPage_fab_addDive => '添加潜水';

  @override
  String get diveLog_listPage_fab_logDive => '记录潜水';

  @override
  String get diveLog_listPage_menuAdvancedSearch => '高级搜索';

  @override
  String get diveLog_listPage_menuDiveNumbering => '潜水编号';

  @override
  String get diveLog_listPage_searchFieldLabel => '搜索潜水...';

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return '未找到与「$query」匹配的潜水';
  }

  @override
  String get diveLog_listPage_searchSuggestion => '按潜水点、潜伴或备注搜索';

  @override
  String get diveLog_listPage_title => '潜水日志';

  @override
  String get diveLog_listPage_tooltip_back => '返回';

  @override
  String get diveLog_listPage_tooltip_backToDiveList => '返回潜水列表';

  @override
  String get diveLog_listPage_tooltip_clearSearch => '清除搜索';

  @override
  String get diveLog_listPage_tooltip_filterDives => '筛选潜水';

  @override
  String get diveLog_listPage_tooltip_listView => '列表视图';

  @override
  String get diveLog_listPage_tooltip_mapView => '地图视图';

  @override
  String get diveLog_listPage_tooltip_searchDives => '搜索潜水';

  @override
  String get diveLog_listPage_tooltip_sort => '排序';

  @override
  String get diveLog_listPage_unknownSite => '未知潜水点';

  @override
  String get diveLog_map_emptySubtitle => '记录带有位置数据的潜水以在地图上查看您的活动';

  @override
  String get diveLog_map_emptyTitle => '无潜水活动可显示';

  @override
  String diveLog_map_errorLoading(Object error) {
    return '加载潜水数据出错：$error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => '适应所有潜水点';

  @override
  String get diveLog_numbering_actions => '操作';

  @override
  String get diveLog_numbering_allCorrect => '所有潜水编号正确';

  @override
  String get diveLog_numbering_assignMissing => '分配缺失编号';

  @override
  String get diveLog_numbering_assignMissingDesc => '从最后编号的潜水之后开始为未编号潜水编号';

  @override
  String get diveLog_numbering_close => '关闭';

  @override
  String get diveLog_numbering_gapsDetected => '检测到空缺';

  @override
  String get diveLog_numbering_issuesDetected => '检测到问题';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '缺失 $count 个';
  }

  @override
  String get diveLog_numbering_renumberAll => '重新编号所有潜水';

  @override
  String get diveLog_numbering_renumberAllDesc => '根据潜水日期/时间分配顺序编号';

  @override
  String get diveLog_numbering_renumberDialog_cancel => '取消';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      '这将根据入水日期/时间对所有潜水进行顺序重新编号。此操作无法撤消。';

  @override
  String get diveLog_numbering_renumberDialog_renumber => '重新编号';

  @override
  String get diveLog_numbering_renumberDialog_startFrom => '起始编号';

  @override
  String get diveLog_numbering_renumberDialog_title => '重新编号所有潜水';

  @override
  String get diveLog_numbering_snackbar_assigned => '已分配缺失的潜水编号';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return '所有潜水已从 #$number 开始重新编号';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '共 $total 次潜水 • 已编号 $numbered 次';
  }

  @override
  String get diveLog_numbering_title => '潜水编号';

  @override
  String diveLog_numbering_unnumberedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次潜水',
      one: '次潜水',
    );
    return '$count $_temp0未编号';
  }

  @override
  String get diveLog_o2tox_badge_critical => '危急';

  @override
  String get diveLog_o2tox_badge_warning => '警告';

  @override
  String diveLog_o2tox_cnsBadgeLabel(Object value) {
    return '中枢神经系统 $value';
  }

  @override
  String get diveLog_o2tox_cnsOxygenClock => '中枢神经系统氧时钟';

  @override
  String diveLog_o2tox_deltaDive(Object value) {
    return '本次潜水 +$value%';
  }

  @override
  String get diveLog_o2tox_details => '详情';

  @override
  String get diveLog_o2tox_label_maxPpO2 => '最大氧分压';

  @override
  String get diveLog_o2tox_label_maxPpO2Depth => '最大氧分压深度';

  @override
  String get diveLog_o2tox_label_timeAbove14 => '超过 1.4 bar 的时间';

  @override
  String get diveLog_o2tox_label_timeAbove16 => '超过 1.6 bar 的时间';

  @override
  String get diveLog_o2tox_ofDailyLimit => '占每日限制';

  @override
  String get diveLog_o2tox_oxygenToleranceUnits => '氧耐受单位';

  @override
  String diveLog_o2tox_semantics_cnsBadge(Object value) {
    return '中枢神经系统氧中毒 $value';
  }

  @override
  String get diveLog_o2tox_semantics_criticalWarning => '氧中毒危急警告';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return '氧耐受单位：$value，占每日限制的 $percent%';
  }

  @override
  String get diveLog_o2tox_semantics_warning => '氧中毒警告';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return '起始：$value%';
  }

  @override
  String get diveLog_o2tox_title => '氧中毒';

  @override
  String get diveLog_playbackStats_deco => '减压';

  @override
  String get diveLog_playbackStats_depth => '深度';

  @override
  String get diveLog_playbackStats_header => '实时统计';

  @override
  String get diveLog_playbackStats_heartRate => '心率';

  @override
  String get diveLog_playbackStats_ndl => '免减压极限';

  @override
  String get diveLog_playbackStats_ppO2 => '氧分压';

  @override
  String get diveLog_playbackStats_pressure => '压力';

  @override
  String get diveLog_playbackStats_temp => '温度';

  @override
  String get diveLog_playback_sliderLabel => '回放位置';

  @override
  String diveLog_playback_speed_label(Object speed) {
    return '${speed}x';
  }

  @override
  String get diveLog_playback_stepThrough => '逐步回放';

  @override
  String get diveLog_playback_tooltip_back10 => '后退 10 秒';

  @override
  String get diveLog_playback_tooltip_exit => '退出回放模式';

  @override
  String get diveLog_playback_tooltip_forward10 => '前进 10 秒';

  @override
  String get diveLog_playback_tooltip_pause => '暂停';

  @override
  String get diveLog_playback_tooltip_play => '播放';

  @override
  String get diveLog_playback_tooltip_skipEnd => '跳至结尾';

  @override
  String get diveLog_playback_tooltip_skipStart => '跳至开头';

  @override
  String get diveLog_playback_tooltip_speed => '回放速度';

  @override
  String get diveLog_profileSelector_badge_primary => '主要';

  @override
  String get diveLog_profileSelector_label_diveComputers => '潜水电脑';

  @override
  String diveLog_profile_axisDepth(Object unit) {
    return '深度 ($unit)';
  }

  @override
  String get diveLog_profile_axisTime => '时间（分钟）';

  @override
  String get diveLog_profile_emptyState => '无潜水轮廓数据';

  @override
  String get diveLog_profile_rightAxis_none => '无';

  @override
  String get diveLog_profile_semantics_changeRightAxis => '更改右轴指标';

  @override
  String get diveLog_profile_semantics_chart => '潜水轮廓图，双指缩放';

  @override
  String get diveLog_profile_tooltip_moreOptions => '更多图表选项';

  @override
  String get diveLog_profile_tooltip_resetZoom => '重置缩放';

  @override
  String get diveLog_profile_tooltip_zoomIn => '放大';

  @override
  String get diveLog_profile_tooltip_zoomOut => '缩小';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return '缩放：${level}x • 双指缩放或滚动，拖动平移';
  }

  @override
  String get diveLog_rangeSelection_exitRange => '退出范围';

  @override
  String get diveLog_rangeSelection_selectRange => '选择范围';

  @override
  String get diveLog_rangeSelection_semantics_adjust => '调整范围选择';

  @override
  String get diveLog_rangeStats_label_avgDepth => '平均深度';

  @override
  String get diveLog_rangeStats_label_avgVertSpeed => '平均垂直速度';

  @override
  String get diveLog_rangeStats_label_depthDelta => '深度差';

  @override
  String get diveLog_rangeStats_label_elapsed => '已过时间';

  @override
  String get diveLog_rangeStats_label_gasConsumed => '气体消耗';

  @override
  String get diveLog_rangeStats_label_maxAscent => '最大上升';

  @override
  String get diveLog_rangeStats_label_maxDepth => '最大深度';

  @override
  String get diveLog_rangeStats_label_maxDescent => '最大下降';

  @override
  String get diveLog_rangeStats_label_maxHR => '最大心率';

  @override
  String get diveLog_rangeStats_label_maxTemp => '最高温度';

  @override
  String get diveLog_rangeStats_label_minDepth => '最小深度';

  @override
  String get diveLog_rangeStats_label_minHR => '最小心率';

  @override
  String get diveLog_rangeStats_label_minTemp => '最低温度';

  @override
  String get diveLog_rangeStats_label_sacRate => '气体消耗率';

  @override
  String get diveLog_rangeStats_title => '范围统计';

  @override
  String get diveLog_rangeStats_tooltip_close => '关闭范围分析';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return '计算的循环 FO₂：$value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => '例如，0.33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => '添加比率';

  @override
  String get diveLog_scr_label_assumedVo2 => '假定 VO₂';

  @override
  String get diveLog_scr_label_avg => '平均';

  @override
  String get diveLog_scr_label_injectionRate => '注入速率';

  @override
  String get diveLog_scr_label_max => '最大';

  @override
  String get diveLog_scr_label_min => '最小';

  @override
  String get diveLog_scr_label_orificeSize => '节流口尺寸';

  @override
  String get diveLog_scr_sectionCmf => 'CMF 参数';

  @override
  String get diveLog_scr_sectionEscr => 'ESCR 参数';

  @override
  String get diveLog_scr_sectionMeasuredLoopO2 => '实测回路 O₂（可选）';

  @override
  String get diveLog_scr_sectionPascr => 'PASCR 参数';

  @override
  String get diveLog_scr_sectionScrType => '半密闭循环呼吸器类型';

  @override
  String get diveLog_scr_sectionSupplyGas => '供气';

  @override
  String get diveLog_scr_title => '半密闭循环呼吸器设置';

  @override
  String get diveLog_search_allCenters => '所有中心';

  @override
  String get diveLog_search_allTrips => '所有旅行';

  @override
  String get diveLog_search_appBar => '高级搜索';

  @override
  String get diveLog_search_cancel => '取消';

  @override
  String get diveLog_search_clearAll => '清除全部';

  @override
  String get diveLog_search_customFieldKey => '自定义字段键';

  @override
  String get diveLog_search_customFieldValue => '值包含...';

  @override
  String get diveLog_search_end => '结束';

  @override
  String get diveLog_search_errorLoadingCenters => '加载潜水中心出错';

  @override
  String get diveLog_search_errorLoadingDiveTypes => '加载潜水类型出错';

  @override
  String get diveLog_search_errorLoadingTrips => '加载旅行出错';

  @override
  String get diveLog_search_gasTrimix => '三混气 (<21% O₂)';

  @override
  String get diveLog_search_label_depthRange => '深度范围（米）';

  @override
  String get diveLog_search_label_diveCenter => '潜水中心';

  @override
  String get diveLog_search_label_diveSite => '潜水点';

  @override
  String get diveLog_search_label_diveType => '潜水类型';

  @override
  String get diveLog_search_label_durationRange => '时长范围（分钟）';

  @override
  String get diveLog_search_label_trip => '旅行';

  @override
  String get diveLog_search_search => '搜索';

  @override
  String get diveLog_search_section_conditions => '条件';

  @override
  String get diveLog_search_section_dateRange => '日期范围';

  @override
  String get diveLog_search_section_gasEquipment => '气体与装备';

  @override
  String get diveLog_search_section_location => '位置';

  @override
  String get diveLog_search_section_organization => '组织';

  @override
  String get diveLog_search_section_social => '社交';

  @override
  String get diveLog_search_start => '开始';

  @override
  String diveLog_selection_countSelected(Object count) {
    return '已选择 $count 个';
  }

  @override
  String get diveLog_selection_tooltip_delete => '删除所选';

  @override
  String get diveLog_selection_tooltip_deselectAll => '取消全选';

  @override
  String get diveLog_selection_tooltip_edit => '编辑所选';

  @override
  String get diveLog_selection_tooltip_exit => '退出选择';

  @override
  String get diveLog_selection_tooltip_export => '导出所选';

  @override
  String get diveLog_selection_tooltip_selectAll => '全选';

  @override
  String get diveLog_sighting_add => '添加';

  @override
  String get diveLog_sighting_cancel => '取消';

  @override
  String get diveLog_sighting_notesHint => '例如，大小、行为、位置...';

  @override
  String get diveLog_sighting_notesOptional => '备注（可选）';

  @override
  String get diveLog_sitePicker_addDiveSite => '添加潜水点';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return '距离 $distance 公里';
  }

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return '距离 $distance 米';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return '加载潜水点出错：$error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => '新潜水点';

  @override
  String get diveLog_sitePicker_noSites => '暂无潜水点';

  @override
  String get diveLog_sitePicker_sortedByDistance => '按距离排序';

  @override
  String get diveLog_sitePicker_title => '选择潜水点';

  @override
  String get diveLog_sort_title => '潜水排序';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return '添加「$name」为新物种';
  }

  @override
  String get diveLog_speciesPicker_noResults => '未找到物种';

  @override
  String get diveLog_speciesPicker_noSpecies => '暂无可用物种';

  @override
  String get diveLog_speciesPicker_searchHint => '搜索物种...';

  @override
  String get diveLog_speciesPicker_title => '添加海洋生物';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch => '清除搜索';

  @override
  String get diveLog_summary_action_importComputer => '从电脑导入';

  @override
  String get diveLog_summary_action_logDive => '记录潜水';

  @override
  String get diveLog_summary_action_viewStats => '查看统计';

  @override
  String diveLog_summary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次潜水',
      one: '次潜水',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_summary_overview => '概览';

  @override
  String get diveLog_summary_record_coldest => '最冷潜水';

  @override
  String get diveLog_summary_record_deepest => '最深潜水';

  @override
  String get diveLog_summary_record_longest => '最长潜水';

  @override
  String get diveLog_summary_record_warmest => '最暖潜水';

  @override
  String get diveLog_summary_section_mostVisited => '最常访问的潜水点';

  @override
  String get diveLog_summary_section_quickActions => '快捷操作';

  @override
  String get diveLog_summary_section_records => '个人记录';

  @override
  String get diveLog_summary_selectDive => '从列表中选择潜水以查看详情';

  @override
  String get diveLog_summary_stat_avgMaxDepth => '平均最大深度';

  @override
  String get diveLog_summary_stat_avgWaterTemp => '平均水温';

  @override
  String get diveLog_summary_stat_diveSites => '潜水点';

  @override
  String get diveLog_summary_stat_diveTime => '潜水时间';

  @override
  String get diveLog_summary_stat_maxDepth => '最大深度';

  @override
  String get diveLog_summary_stat_totalDives => '潜水总次数';

  @override
  String get diveLog_summary_title => '潜水日志摘要';

  @override
  String get diveLog_tank_label_endPressure => '结束压力';

  @override
  String get diveLog_tank_label_he => 'He';

  @override
  String get diveLog_tank_label_material => '材质';

  @override
  String get diveLog_tank_label_n2 => 'N2';

  @override
  String get diveLog_tank_label_o2 => 'O2';

  @override
  String get diveLog_tank_label_role => '角色';

  @override
  String get diveLog_tank_label_startPressure => '起始压力';

  @override
  String get diveLog_tank_label_tankPreset => '气瓶预设';

  @override
  String get diveLog_tank_label_volume => '容积';

  @override
  String get diveLog_tank_label_workingPressure => '工作压力';

  @override
  String get diveLog_tank_mndHelper => '设置自动计算 He%';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return '最大作业深度：$depth（氧分压 1.4）';
  }

  @override
  String diveLog_tank_modMndInfo(Object mod, Object mnd) {
    return '最大作业深度：$mod（氧分压 1.4）| 最大等效氮深：$mnd';
  }

  @override
  String get diveLog_tank_section_gasMix => '气体混合';

  @override
  String get diveLog_tank_selectPreset => '选择预设...';

  @override
  String diveLog_tank_title(Object number) {
    return '气瓶 $number';
  }

  @override
  String get diveLog_tank_tooltip_remove => '移除气瓶';

  @override
  String get diveLog_tissue_label_ceiling => '上升限制';

  @override
  String get diveLog_tissue_label_gf => 'GF';

  @override
  String get diveLog_tissue_label_ndl => '免减压极限';

  @override
  String get diveLog_tissue_label_tts => 'TTS';

  @override
  String get diveLog_tissue_legend_he => 'He';

  @override
  String get diveLog_tissue_legend_mValue => '100% M值';

  @override
  String get diveLog_tissue_legend_n2 => 'N₂';

  @override
  String get diveLog_tissue_title => '组织饱和度';

  @override
  String get diveLog_tooltip_ceiling => '上升限制';

  @override
  String get diveLog_tooltip_cns => '中枢神经系统';

  @override
  String get diveLog_tooltip_density => '密度';

  @override
  String get diveLog_tooltip_depth => '深度';

  @override
  String get diveLog_tooltip_gfPercent => 'GF%';

  @override
  String get diveLog_tooltip_hr => '心率';

  @override
  String get diveLog_tooltip_marker => '标记';

  @override
  String get diveLog_tooltip_mean => '平均';

  @override
  String get diveLog_tooltip_mod => '最大作业深度';

  @override
  String get diveLog_tooltip_ndl => '免减压极限';

  @override
  String get diveLog_tooltip_otu => 'OTU';

  @override
  String get diveLog_tooltip_ppHe => '氦分压';

  @override
  String get diveLog_tooltip_ppN2 => '氮分压';

  @override
  String get diveLog_tooltip_ppO2 => '氧分压';

  @override
  String get diveLog_tooltip_press => '压力';

  @override
  String get diveLog_tooltip_rate => '速率';

  @override
  String get diveLog_tooltip_sac => 'SAC';

  @override
  String get diveLog_tooltip_srfGf => '水面GF';

  @override
  String get diveLog_tooltip_temp => '温度';

  @override
  String get diveLog_tooltip_time => '时间';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get divePlanner_action_addTank => '添加气瓶';

  @override
  String get divePlanner_action_convertToDive => '转换为潜水';

  @override
  String get divePlanner_action_editTank => '编辑气瓶';

  @override
  String get divePlanner_action_moreOptions => '更多选项';

  @override
  String get divePlanner_action_quickPlan => '快捷计划';

  @override
  String get divePlanner_action_renamePlan => '重命名计划';

  @override
  String get divePlanner_action_reset => '重置';

  @override
  String get divePlanner_action_resetPlan => '重置计划';

  @override
  String get divePlanner_action_savePlan => '保存计划';

  @override
  String get divePlanner_error_cannotConvert => '无法转换：计划存在严重警告';

  @override
  String get divePlanner_error_reserveExceedsTank => '超过气瓶压力';

  @override
  String get divePlanner_error_reserveMustBePositive => '必须大于 0';

  @override
  String divePlanner_info_reserveDefault(Object unit, Object value) {
    return '未输入 — 假设为 $value $unit';
  }

  @override
  String get divePlanner_field_hePercent => 'He %';

  @override
  String get divePlanner_field_name => '名称';

  @override
  String get divePlanner_field_o2Percent => 'O₂ %';

  @override
  String get divePlanner_field_planName => '计划名称';

  @override
  String get divePlanner_field_role => '角色';

  @override
  String divePlanner_field_startPressure(Object pressureSymbol) {
    return '开始 ($pressureSymbol)';
  }

  @override
  String divePlanner_field_volume(Object volumeSymbol) {
    return '容积 ($volumeSymbol)';
  }

  @override
  String get divePlanner_hint_tankName => '输入气瓶名称';

  @override
  String get divePlanner_label_altitude => '高海拔:';

  @override
  String get divePlanner_label_belowMinReserve => '低于最小储备';

  @override
  String get divePlanner_label_ceiling => '上升限制';

  @override
  String get divePlanner_label_consumption => '消耗';

  @override
  String get divePlanner_label_deco => '减压';

  @override
  String get divePlanner_label_decoSchedule => '减压计划';

  @override
  String get divePlanner_label_decompression => '减压';

  @override
  String divePlanner_label_depthAxis(Object depthSymbol) {
    return '深度 ($depthSymbol)';
  }

  @override
  String get divePlanner_label_diveProfile => '潜水轮廓';

  @override
  String get divePlanner_label_empty => '已空';

  @override
  String get divePlanner_label_gasConsumption => '气体消耗';

  @override
  String get divePlanner_label_gfHigh => 'GF 高值';

  @override
  String get divePlanner_label_gfLow => 'GF 低值';

  @override
  String get divePlanner_label_max => '最大';

  @override
  String get divePlanner_label_ndl => 'NDL';

  @override
  String get divePlanner_label_planSettings => '计划设置';

  @override
  String get divePlanner_label_remaining => '剩余';

  @override
  String get divePlanner_label_reserve => '储备:';

  @override
  String get divePlanner_label_runtime => '运行时间';

  @override
  String get divePlanner_label_sacRate => '气体消耗率:';

  @override
  String get divePlanner_label_status => '状态';

  @override
  String get divePlanner_label_tanks => '气瓶';

  @override
  String get divePlanner_label_time => '时间';

  @override
  String get divePlanner_label_timeAxis => '时间 (分钟)';

  @override
  String get divePlanner_label_tts => '到达水面时间';

  @override
  String get divePlanner_label_used => '已用';

  @override
  String get divePlanner_label_warnings => '警告';

  @override
  String get divePlanner_legend_ascent => '上升';

  @override
  String get divePlanner_legend_bottom => '底部';

  @override
  String get divePlanner_legend_deco => '减压';

  @override
  String get divePlanner_legend_descent => '下降';

  @override
  String get divePlanner_legend_safety => '安全';

  @override
  String get divePlanner_message_addSegmentsForGas => '添加段落以查看气体预测';

  @override
  String get divePlanner_message_addSegmentsForProfile => '添加段落以查看潜水轮廓';

  @override
  String get divePlanner_message_convertingPlan => '正在将计划转换为潜水...';

  @override
  String get divePlanner_message_noProfile => '无档案到显示';

  @override
  String get divePlanner_message_planSaved => '计划已保存';

  @override
  String get divePlanner_message_resetConfirmation => '确定要重置计划吗?';

  @override
  String divePlanner_semantics_criticalWarning(Object message) {
    return '危急警告: $message';
  }

  @override
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  ) {
    return '减压停留在 $depth，$duration，使用 $gasMix';
  }

  @override
  String divePlanner_semantics_gasConsumption(
    Object tankName,
    Object gasUsed,
    Object remaining,
    Object percent,
    Object warning,
  ) {
    return '$tankName：已用 $gasUsed，剩余 $remaining，已用 $percent$warning';
  }

  @override
  String divePlanner_semantics_profileChart(
    Object maxDepth,
    Object totalMinutes,
  ) {
    return '潜水计划，最大深度 $maxDepth，总时间 $totalMinutes 分钟';
  }

  @override
  String divePlanner_semantics_warning(Object message) {
    return '警告: $message';
  }

  @override
  String get divePlanner_tab_plan => '计划';

  @override
  String get divePlanner_tab_profile => '档案';

  @override
  String get divePlanner_tab_results => '结果';

  @override
  String get divePlanner_warning_ascentRateHigh => '上升速率超过安全极限';

  @override
  String divePlanner_warning_ascentRateHighWithRate(Object rate) {
    return '上升速率 $rate/分钟超过安全极限';
  }

  @override
  String divePlanner_warning_belowMinReserve(Object reserve) {
    return '低于最低储备量 ($reserve)';
  }

  @override
  String get divePlanner_warning_cnsCritical => '中枢神经系统%超过 100%';

  @override
  String divePlanner_warning_cnsWarning(Object threshold) {
    return '中枢神经系统%超过 $threshold%';
  }

  @override
  String get divePlanner_warning_endHigh => '等效麻醉深度过高';

  @override
  String divePlanner_warning_endHighWithDepth(Object depth) {
    return '等效麻醉深度 $depth 超过安全极限';
  }

  @override
  String divePlanner_warning_gasLow(Object threshold) {
    return '气瓶低于 $threshold 储备';
  }

  @override
  String get divePlanner_warning_gasOut => '气瓶将耗尽';

  @override
  String get divePlanner_warning_minGasViolation => '未保持最低气体储备';

  @override
  String get divePlanner_warning_modViolation => '在最大作业深度以上尝试切换气体';

  @override
  String get divePlanner_warning_ndlExceeded => '潜水进入减压义务';

  @override
  String get divePlanner_warning_otuWarning => '氧中毒单位累积过高';

  @override
  String divePlanner_warning_ppO2Critical(Object value) {
    return '氧分压 $value bar 超过临界极限';
  }

  @override
  String divePlanner_warning_ppO2High(Object value) {
    return '氧分压 $value bar 超过工作极限';
  }

  @override
  String get diveSites_detail_access_accessNotes => '到达须知';

  @override
  String get diveSites_detail_access_mooring => '系泊';

  @override
  String get diveSites_detail_access_parking => '停车';

  @override
  String get diveSites_detail_altitude_elevation => '海拔';

  @override
  String get diveSites_detail_altitude_pressure => '压力';

  @override
  String get diveSites_detail_coordinatesCopied => '坐标已复制到剪贴板';

  @override
  String get diveSites_detail_deleteDialog_cancel => '取消';

  @override
  String get diveSites_detail_deleteDialog_confirm => '删除';

  @override
  String get diveSites_detail_deleteDialog_content => '确定要删除此潜水点吗？此操作无法撤销。';

  @override
  String get diveSites_detail_deleteDialog_title => '删除潜水点';

  @override
  String get diveSites_detail_deleteMenu_label => '删除';

  @override
  String get diveSites_detail_deleteSnackbar => '潜水点已删除';

  @override
  String get diveSites_detail_depth_maximum => '最大';

  @override
  String get diveSites_detail_depth_minimum => '最小';

  @override
  String get diveSites_detail_diveCount_one => '已记录 1 次潜水';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '已记录 $count 次潜水';
  }

  @override
  String get diveSites_detail_diveCount_zero => '尚未记录潜水';

  @override
  String get diveSites_detail_editTooltip => '编辑潜水点';

  @override
  String get diveSites_detail_editTooltipShort => '编辑';

  @override
  String diveSites_detail_error_body(Object error) {
    return '错误： $error';
  }

  @override
  String get diveSites_detail_error_title => '错误';

  @override
  String get diveSites_detail_loading_title => '加载中...';

  @override
  String get diveSites_detail_location_country => '国家';

  @override
  String get diveSites_detail_location_gpsCoordinates => 'GPS 坐标';

  @override
  String get diveSites_detail_location_notSet => '未设置';

  @override
  String get diveSites_detail_location_region => '地区';

  @override
  String get diveSites_detail_noDepthInfo => '无深度信息';

  @override
  String get diveSites_detail_noDescription => '无描述';

  @override
  String get diveSites_detail_noNotes => '无备注';

  @override
  String get diveSites_detail_rating_notRated => '未评分';

  @override
  String diveSites_detail_rating_value(Object rating) {
    return '$rating / 5';
  }

  @override
  String get diveSites_detail_section_access => '到达与后勤';

  @override
  String get diveSites_detail_section_altitude => '高海拔';

  @override
  String get diveSites_detail_section_depthRange => '深度范围';

  @override
  String get diveSites_detail_section_description => '描述';

  @override
  String get diveSites_detail_section_difficultyLevel => '难度等级';

  @override
  String get diveSites_detail_section_divesAtSite => '此潜水点的潜水记录';

  @override
  String get diveSites_detail_section_hazards => '危险 & 安全';

  @override
  String get diveSites_detail_section_location => '位置';

  @override
  String get diveSites_detail_section_notes => '备注';

  @override
  String get diveSites_detail_section_rating => '评分';

  @override
  String diveSites_detail_semantics_copyToClipboard(Object label) {
    return '复制 $label 到剪贴板';
  }

  @override
  String get diveSites_detail_semantics_viewDivesAtSite => '查看此潜水点的潜水记录';

  @override
  String get diveSites_detail_semantics_viewFullscreenMap => '查看全屏地图';

  @override
  String get diveSites_detail_siteNotFound_body => '此潜水点已不存在。';

  @override
  String get diveSites_detail_siteNotFound_title => '未找到潜水点';

  @override
  String get diveSites_difficulty_advanced => '高级';

  @override
  String get diveSites_difficulty_beginner => '初级';

  @override
  String get diveSites_difficulty_intermediate => '中级';

  @override
  String get diveSites_difficulty_technical => '技术';

  @override
  String get diveSites_edit_access_accessNotes_hint => '如何到达潜水点、入水/出水点、岸潜/船潜';

  @override
  String get diveSites_edit_access_accessNotes_label => '到达须知';

  @override
  String get diveSites_edit_access_mooringNumber_hint => '例如，浮标 #12';

  @override
  String get diveSites_edit_access_mooringNumber_label => '系泊编号';

  @override
  String get diveSites_edit_access_parkingInfo_hint => '停车位、费用、提示';

  @override
  String get diveSites_edit_access_parkingInfo_label => '停车信息';

  @override
  String get diveSites_edit_altitude_helperText => '潜水点海拔高度（用于高海拔潜水）';

  @override
  String get diveSites_edit_altitude_hint => 'e.g., 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return '高海拔 ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => '无效的海拔';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => '删除潜水点';

  @override
  String get diveSites_edit_appBar_editSite => '编辑潜水点';

  @override
  String get diveSites_edit_appBar_merge => '合并';

  @override
  String get diveSites_edit_appBar_mergeSites => '合并潜水点';

  @override
  String get diveSites_edit_appBar_newSite => '新建潜水点';

  @override
  String get diveSites_edit_appBar_save => '保存';

  @override
  String get diveSites_edit_button_addSite => '添加潜水点';

  @override
  String get diveSites_edit_button_mergeSites => '合并潜水点';

  @override
  String get diveSites_edit_button_saveChanges => '保存更改';

  @override
  String get diveSites_edit_cancel => '取消';

  @override
  String get diveSites_edit_depth_helperText => '从最浅处到最深处';

  @override
  String get diveSites_edit_depth_maxHint => 'e.g., 30';

  @override
  String diveSites_edit_depth_maxLabel(Object symbol) {
    return '最大深度 ($symbol)';
  }

  @override
  String get diveSites_edit_depth_minHint => 'e.g., 5';

  @override
  String diveSites_edit_depth_minLabel(Object symbol) {
    return '最小深度 ($symbol)';
  }

  @override
  String get diveSites_edit_depth_separator => '至';

  @override
  String get diveSites_edit_discardDialog_content => '您有未保存的更改。确定要离开吗?';

  @override
  String get diveSites_edit_discardDialog_discard => '丢弃';

  @override
  String get diveSites_edit_discardDialog_keepEditing => '继续编辑';

  @override
  String get diveSites_edit_discardDialog_title => '丢弃更改？';

  @override
  String get diveSites_edit_field_country_label => '国家';

  @override
  String get diveSites_edit_field_description_hint => '潜水点的简要描述';

  @override
  String get diveSites_edit_field_description_label => '描述';

  @override
  String get diveSites_edit_field_notes_hint => '关于此潜水点的其他信息';

  @override
  String get diveSites_edit_field_notes_label => '通用备注';

  @override
  String get diveSites_edit_field_region_label => '地区';

  @override
  String get diveSites_edit_field_siteName_hint => '例如，蓝洞';

  @override
  String get diveSites_edit_field_siteName_label => '潜水点名称 *';

  @override
  String get diveSites_edit_field_siteName_validation => '请输入潜水点名称';

  @override
  String get diveSites_edit_gps_gettingLocation => '获取中...';

  @override
  String get diveSites_edit_gps_helperText => '选择定位方式 - 坐标将自动填充国家和地区';

  @override
  String get diveSites_edit_gps_latitude_hint => 'e.g., 21.4225';

  @override
  String get diveSites_edit_gps_latitude_label => '纬度';

  @override
  String get diveSites_edit_gps_latitude_validation => '无效的纬度';

  @override
  String get diveSites_edit_gps_longitude_hint => 'e.g., -86.7542';

  @override
  String get diveSites_edit_gps_longitude_label => '经度';

  @override
  String get diveSites_edit_gps_longitude_validation => '无效的经度';

  @override
  String get diveSites_edit_gps_pickFromMap => '选择从地图';

  @override
  String get diveSites_edit_gps_useMyLocation => '使用我的位置';

  @override
  String get diveSites_edit_hazards_helperText => '列出任何危险或安全注意事项';

  @override
  String get diveSites_edit_hazards_hint => '例如：强水流、船只交通、水母、尖锐珊瑚';

  @override
  String get diveSites_edit_hazards_label => '危险';

  @override
  String get diveSites_edit_marineLife_addButton => '添加';

  @override
  String get diveSites_edit_marineLife_empty => '未添加预期物种';

  @override
  String get diveSites_edit_marineLife_helperText => '您预计在此潜水点可以看到的物种';

  @override
  String diveSites_edit_merge_confirmBody(int count) {
    return '这将把 $count 个潜水点合并为一个。潜水记录、媒体和预期物种将合并到保留的潜水点下。其他潜水点将被删除。';
  }

  @override
  String get diveSites_edit_merge_confirmTitle => '合并潜水点';

  @override
  String get diveSites_edit_merge_fieldSourceCycleTooltip => '使用下一个已选潜水点的值';

  @override
  String diveSites_edit_merge_fieldSourceLabel(
    Object siteName,
    int current,
    int total,
  ) {
    return '来自 $siteName ($current/$total)';
  }

  @override
  String get diveSites_edit_merge_fieldSourceMenuTooltip => '从已选潜水点中选择值';

  @override
  String get diveSites_edit_merge_marineLifeHelperText => '合计从全部已选择潜水点';

  @override
  String diveSites_edit_merge_loadingErrorBody(Object error) {
    return '加载潜水点失败：$error';
  }

  @override
  String get diveSites_edit_merge_loadingErrorTitle => '合并潜水点';

  @override
  String get diveSites_edit_merge_notEnoughBody => '没有足够的潜水点可合并。';

  @override
  String get diveSites_edit_merge_notEnoughTitle => '合并潜水点';

  @override
  String get diveSites_edit_rating_clear => '清除评分';

  @override
  String diveSites_edit_rating_starTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '',
      one: '',
    );
    return '$count 颗星$_temp0';
  }

  @override
  String get diveSites_edit_section_access => '到达与后勤';

  @override
  String get diveSites_edit_section_altitude => '高海拔';

  @override
  String get diveSites_edit_section_depthRange => '深度范围';

  @override
  String get diveSites_edit_section_difficultyLevel => '难度等级';

  @override
  String get diveSites_edit_section_expectedMarineLife => '预期海洋生物';

  @override
  String get diveSites_edit_section_gpsCoordinates => 'GPS 坐标';

  @override
  String get diveSites_edit_section_hazards => '危险 & 安全';

  @override
  String get diveSites_edit_section_rating => '评分';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return '删除潜水点出错：$error';
  }

  @override
  String diveSites_edit_snackbar_errorSaving(Object error) {
    return '保存潜水点出错：$error';
  }

  @override
  String get diveSites_edit_snackbar_locationCaptured => '位置已获取';

  @override
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return '位置已获取（精度 ${accuracy}m）';
  }

  @override
  String get diveSites_edit_snackbar_locationSelectedFromMap => '已从地图选择位置';

  @override
  String get diveSites_edit_snackbar_locationSettings => '设置';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      '无法获取位置。定位服务可能不可用。';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      '无法获取位置。请检查权限设置。';

  @override
  String get diveSites_edit_snackbar_siteAdded => '潜水点已添加';

  @override
  String get diveSites_edit_snackbar_sitesMerged => '潜水点已合并';

  @override
  String get diveSites_edit_snackbar_siteUpdated => '潜水点已更新';

  @override
  String get diveSites_fab_label => '添加潜水点';

  @override
  String get diveSites_fab_tooltip => '添加新潜水点';

  @override
  String get diveSites_filter_apply => '应用筛选';

  @override
  String get diveSites_filter_cancel => '取消';

  @override
  String get diveSites_filter_clearAll => '清除全部';

  @override
  String get diveSites_filter_country_hint => '例如，泰国';

  @override
  String get diveSites_filter_country_label => '国家';

  @override
  String get diveSites_filter_depth_max_label => '最大';

  @override
  String get diveSites_filter_depth_min_label => '最小';

  @override
  String get diveSites_filter_depth_separator => '至';

  @override
  String get diveSites_filter_difficulty_any => '任意';

  @override
  String get diveSites_filter_option_hasCoordinates_subtitle =>
      '仅显示潜水点与 GPS 位置';

  @override
  String get diveSites_filter_option_hasCoordinates_title => '有坐标';

  @override
  String get diveSites_filter_option_hasDives_subtitle => '仅显示有潜水记录的潜水点';

  @override
  String get diveSites_filter_option_hasDives_title => '有潜水记录';

  @override
  String diveSites_filter_rating_starsPlus(Object count) {
    return '$count+ 颗星';
  }

  @override
  String get diveSites_filter_region_hint => '例如，普吉岛';

  @override
  String get diveSites_filter_region_label => '地区';

  @override
  String get diveSites_filter_section_depthRange => '最大深度范围';

  @override
  String get diveSites_filter_section_difficulty => '难度';

  @override
  String get diveSites_filter_section_location => '位置';

  @override
  String get diveSites_filter_section_minRating => '最低评分';

  @override
  String get diveSites_filter_section_options => '选项';

  @override
  String get diveSites_filter_title => '筛选潜水点';

  @override
  String get diveSites_import_appBar_title => '导入潜水点';

  @override
  String get diveSites_import_badge_imported => '已导入';

  @override
  String get diveSites_import_badge_saved => '已保存';

  @override
  String get diveSites_import_button_import => '导入';

  @override
  String get diveSites_import_detail_alreadyImported => '已导入';

  @override
  String get diveSites_import_detail_importToMySites => '导入到我的潜水点';

  @override
  String diveSites_import_detail_source(Object source) {
    return '来源: $source';
  }

  @override
  String get diveSites_import_empty_description => '从我们全球热门潜水目的地数据库中搜索潜水点。';

  @override
  String get diveSites_import_empty_hint => '尝试按潜水点名称、国家或地区搜索。';

  @override
  String get diveSites_import_empty_title => '搜索潜水点';

  @override
  String get diveSites_import_error_retry => '重试';

  @override
  String get diveSites_import_error_title => '搜索错误';

  @override
  String get diveSites_import_error_unknown => '未知错误';

  @override
  String get diveSites_import_externalSite_locationUnknown => '位置未知';

  @override
  String get diveSites_import_label_gps => 'GPS';

  @override
  String get diveSites_import_localSite_locationNotSet => '位置未设置';

  @override
  String diveSites_import_noResults_description(Object query) {
    return '未找到 \"$query\" 相关的潜水点。请尝试其他搜索词。';
  }

  @override
  String get diveSites_import_noResults_title => '无结果';

  @override
  String get diveSites_import_quickSearch_caribbean => '加勒比海';

  @override
  String get diveSites_import_quickSearch_indonesia => '印度尼西亚';

  @override
  String get diveSites_import_quickSearch_maldives => '马尔代夫';

  @override
  String get diveSites_import_quickSearch_philippines => '菲律宾';

  @override
  String get diveSites_import_quickSearch_redSea => '红海';

  @override
  String get diveSites_import_quickSearch_thailand => '泰国';

  @override
  String get diveSites_import_search_clearTooltip => '清除搜索';

  @override
  String get diveSites_import_search_hint =>
      '搜索潜水点（例如 \"Blue Hole\"、\"Thailand\"）';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return '从数据库导入 ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return '我的潜水点 ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return '查看 $name 的详情';
  }

  @override
  String diveSites_import_semantics_viewSavedSite(Object name) {
    return '查看已保存的潜水点 $name';
  }

  @override
  String get diveSites_import_snackbar_failed => '导入潜水点失败';

  @override
  String diveSites_import_snackbar_imported(Object name) {
    return '已导入 \"$name\"';
  }

  @override
  String get diveSites_import_snackbar_viewAction => '查看';

  @override
  String get diveSites_list_activeFilter_clear => '清除';

  @override
  String diveSites_list_activeFilter_country(Object country) {
    return '国家: $country';
  }

  @override
  String diveSites_list_activeFilter_depthRangeBoth(Object min, Object max) {
    return '$min-${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return '深度不超过 ${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '${min}m+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => '有坐标';

  @override
  String get diveSites_list_activeFilter_hasDives => '有潜水';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return '地区: $region';
  }

  @override
  String get diveSites_list_appBar_title => '潜水点';

  @override
  String get diveSites_list_bulkDelete_cancel => '取消';

  @override
  String get diveSites_list_bulkDelete_confirm => '删除';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '',
      one: '',
    );
    return '确定要删除 $count 个潜水点$_temp0吗？此操作可在 5 秒内撤销。';
  }

  @override
  String get diveSites_list_bulkDelete_restored => '潜水点已恢复';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '个潜水地点',
      one: '个潜水地点',
    );
    return '已删除 $count $_temp0';
  }

  @override
  String get diveSites_list_bulkDelete_title => '删除潜水点';

  @override
  String get diveSites_list_bulkDelete_undo => '撤消';

  @override
  String get diveSites_list_merge_restored => '合并已撤销';

  @override
  String diveSites_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '个潜水地点',
      one: '个潜水地点',
    );
    return '已合并 $count $_temp0';
  }

  @override
  String get diveSites_list_merge_undo => '撤消';

  @override
  String get diveSites_list_emptyFiltered_clearAll => '清除全部筛选';

  @override
  String get diveSites_list_emptyFiltered_subtitle => '请尝试调整或清除筛选条件';

  @override
  String get diveSites_list_emptyFiltered_title => '没有符合筛选条件的潜水点';

  @override
  String get diveSites_list_empty_addFirstSite => '添加您的第一个潜水点';

  @override
  String get diveSites_list_empty_import => '导入';

  @override
  String get diveSites_list_empty_subtitle => '添加潜水点以追踪您喜欢的潜水地点';

  @override
  String get diveSites_list_empty_title => '尚无潜水点';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return '加载潜水点出错：$error';
  }

  @override
  String get diveSites_list_error_retry => '重试';

  @override
  String get diveSites_list_menu_import => '导入';

  @override
  String get diveSites_list_search_backTooltip => '返回';

  @override
  String get diveSites_list_search_clearTooltip => '清除搜索';

  @override
  String get diveSites_list_search_emptyHint => '按潜水点名称、国家或地区搜索';

  @override
  String diveSites_list_search_error(Object error) {
    return '错误： $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return '无潜水点已找到为 \"$query\"';
  }

  @override
  String get diveSites_list_search_placeholder => '搜索潜水点...';

  @override
  String get diveSites_list_selection_closeTooltip => '关闭选择';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count 已选择';
  }

  @override
  String get diveSites_list_selection_deleteTooltip => '删除所选';

  @override
  String get diveSites_list_selection_mergeTooltip => '合并所选';

  @override
  String get diveSites_list_selection_deselectAllTooltip => '取消全选';

  @override
  String get diveSites_list_selection_selectAllTooltip => '全选';

  @override
  String get diveSites_list_sort_title => '排序潜水点';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次潜水',
      one: '1 次潜水',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return '潜水点: $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => '筛选潜水点';

  @override
  String get diveSites_list_tooltip_mapView => '地图视图';

  @override
  String get diveSites_list_tooltip_searchSites => '搜索潜水点';

  @override
  String get diveSites_list_tooltip_sort => '排序';

  @override
  String get diveSites_locationPicker_appBar_title => '选择位置';

  @override
  String get diveSites_locationPicker_confirmButton => '确认';

  @override
  String get diveSites_locationPicker_confirmTooltip => '确认所选位置';

  @override
  String get diveSites_locationPicker_fab_tooltip => '使用我的位置';

  @override
  String get diveSites_locationPicker_instruction_locationSelected => '位置已选择';

  @override
  String get diveSites_locationPicker_instruction_lookingUp => '正在查询位置...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect => '点击地图选择位置';

  @override
  String get diveSites_locationPicker_label_latitude => '纬度';

  @override
  String get diveSites_locationPicker_label_longitude => '经度';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return '已选坐标：纬度 $latitude，经度 $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp => '正在查询位置';

  @override
  String get diveSites_locationPicker_semantics_map =>
      '用于选择潜水点位置的互动地图。点击地图选择位置。';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return '加载出错潜水点: $error';
  }

  @override
  String get diveSites_map_appBar_title => '潜水点';

  @override
  String get diveSites_map_empty_description => '为您的潜水点添加坐标以在地图上显示';

  @override
  String get diveSites_map_empty_title => '无潜水点与坐标';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return '加载潜水点出错：$error';
  }

  @override
  String get diveSites_map_error_retry => '重试';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次潜水',
      one: '1 次潜水',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return '潜水点：$name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => '显示全部潜水点';

  @override
  String get diveSites_map_tooltip_listView => '列表视图';

  @override
  String get diveSites_summary_action_addSite => '添加潜水点';

  @override
  String get diveSites_summary_action_import => '导入';

  @override
  String get diveSites_summary_action_viewMap => '查看地图';

  @override
  String diveSites_summary_countriesMore(Object count) {
    return '+ $count 更多';
  }

  @override
  String get diveSites_summary_header_subtitle => '从列表中选择潜水点以查看详情';

  @override
  String get diveSites_summary_header_title => '潜水点';

  @override
  String get diveSites_summary_section_countriesRegions => '国家与地区';

  @override
  String get diveSites_summary_section_mostDived => '最常潜水';

  @override
  String get diveSites_summary_section_overview => '概览';

  @override
  String get diveSites_summary_section_quickActions => '快捷操作';

  @override
  String get diveSites_summary_section_topRated => '最佳额定';

  @override
  String get diveSites_summary_stat_avgRating => '平均评分';

  @override
  String get diveSites_summary_stat_totalDives => '总计潜水';

  @override
  String get diveSites_summary_stat_totalSites => '总计潜水点';

  @override
  String get diveSites_summary_stat_withGps => '与 GPS';

  @override
  String get diveTypes_addDialog_addButton => '添加';

  @override
  String get diveTypes_addDialog_nameHint => '例如：搜索与救援';

  @override
  String get diveTypes_addDialog_nameLabel => '潜水类型名称';

  @override
  String get diveTypes_addDialog_nameValidation => '请输入名称';

  @override
  String get diveTypes_addDialog_title => '添加自定义潜水类型';

  @override
  String get diveTypes_addTooltip => '添加潜水类型';

  @override
  String get diveTypes_appBar_title => '潜水类型';

  @override
  String get diveTypes_builtIn => '内置';

  @override
  String get diveTypes_builtInHeader => '内置潜水类型';

  @override
  String get diveTypes_custom => '自定义';

  @override
  String get diveTypes_customHeader => '自定义潜水类型';

  @override
  String diveTypes_deleteDialog_content(Object name) {
    return '确定要删除 \"$name\"?';
  }

  @override
  String get diveTypes_deleteDialog_title => '删除潜水类型?';

  @override
  String get diveTypes_deleteTooltip => '删除潜水类型';

  @override
  String diveTypes_snackbar_added(Object name) {
    return '已添加潜水类型：$name';
  }

  @override
  String diveTypes_snackbar_cannotDelete(Object name) {
    return '无法删除 \"$name\" - 已被现有潜水记录使用';
  }

  @override
  String diveTypes_snackbar_deleted(Object name) {
    return '已删除\"$name\"';
  }

  @override
  String diveTypes_snackbar_errorAdding(Object error) {
    return '添加潜水类型出错：$error';
  }

  @override
  String diveTypes_snackbar_errorDeleting(Object error) {
    return '删除出错潜水类型: $error';
  }

  @override
  String get divers_detail_activeDiver => '当前潜水员';

  @override
  String get divers_detail_allergiesLabel => '过敏';

  @override
  String get divers_detail_appBarTitle => '潜水员';

  @override
  String get divers_detail_bloodTypeLabel => '血型';

  @override
  String get divers_detail_bottomTimeLabel => '底部时间';

  @override
  String get divers_detail_cancelButton => '取消';

  @override
  String get divers_detail_contactTitle => '联系人';

  @override
  String get divers_detail_defaultLabel => '默认';

  @override
  String get divers_detail_deleteButton => '删除';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'This will permanently delete $name and all associated data including dive logs, dive computers, equipment, certifications, and sites.';
  }

  @override
  String get divers_detail_deleteDialogTitle => '删除潜水员？';

  @override
  String divers_detail_deleteError(Object error) {
    return '删除失败：$error';
  }

  @override
  String get divers_detail_deleteMenuItem => '删除';

  @override
  String get divers_detail_deletedSnackbar => '潜水员已删除';

  @override
  String get divers_detail_diveInsuranceTitle => '潜水保险';

  @override
  String get divers_detail_diveStatisticsTitle => '潜水统计';

  @override
  String get divers_detail_editTooltip => '编辑潜水员';

  @override
  String get divers_detail_emergencyContactTitle => '紧急联系人';

  @override
  String divers_detail_errorPrefix(Object error) {
    return '错误： $error';
  }

  @override
  String get divers_detail_expiredBadge => '已过期';

  @override
  String get divers_detail_expiresLabel => '到期';

  @override
  String get divers_detail_medicalInfoTitle => '医疗信息';

  @override
  String get divers_detail_medicalNotesLabel => '备注';

  @override
  String get divers_detail_notFound => '未找到该潜水员';

  @override
  String get divers_detail_notesTitle => '备注';

  @override
  String get divers_detail_policyNumberLabel => '保单 #';

  @override
  String get divers_detail_providerLabel => '提供商';

  @override
  String get divers_detail_setAsDefault => '设为默认';

  @override
  String divers_detail_setAsDefaultSnackbar(Object name) {
    return '$name 已设为默认潜水员';
  }

  @override
  String get divers_detail_switchToTooltip => '切换到此潜水员';

  @override
  String divers_detail_switchedTo(Object name) {
    return '已切换到 $name';
  }

  @override
  String get divers_detail_totalDivesLabel => '总计潜水';

  @override
  String get divers_detail_unableToLoadStats => '无法加载统计数据';

  @override
  String get divers_edit_addButton => '添加潜水员';

  @override
  String get divers_edit_addTitle => '添加潜水员';

  @override
  String get divers_edit_allergiesHint => '例如，青霉素、贝类';

  @override
  String get divers_edit_allergiesLabel => '过敏';

  @override
  String get divers_edit_bloodTypeHint => 'e.g., O+, A-, B+';

  @override
  String get divers_edit_bloodTypeLabel => '血型';

  @override
  String get divers_edit_cancelButton => '取消';

  @override
  String get divers_edit_clearInsuranceExpiryTooltip => '清除保险到期日';

  @override
  String get divers_edit_clearMedicalClearanceTooltip => '清除医疗许可日期';

  @override
  String get divers_edit_contactNameLabel => '联系人姓名';

  @override
  String get divers_edit_contactPhoneLabel => '联系电话';

  @override
  String get divers_edit_discardButton => '丢弃';

  @override
  String get divers_edit_discardDialogContent => '您有未保存的更改。确定要丢弃吗?';

  @override
  String get divers_edit_discardDialogTitle => '丢弃更改？';

  @override
  String get divers_edit_diverAdded => '潜水员已添加';

  @override
  String get divers_edit_diverUpdated => '潜水员已更新';

  @override
  String get divers_edit_editTitle => '编辑潜水员';

  @override
  String get divers_edit_emailError => '请输入有效的电子邮件地址';

  @override
  String get divers_edit_emailLabel => '电子邮件';

  @override
  String get divers_edit_emergencyContactsSection => '紧急联系人';

  @override
  String divers_edit_errorLoading(Object error) {
    return '加载潜水员出错：$error';
  }

  @override
  String divers_edit_errorSaving(Object error) {
    return '保存潜水员出错：$error';
  }

  @override
  String get divers_edit_expiryDateNotSet => '未设置';

  @override
  String get divers_edit_expiryDateTitle => '到期日';

  @override
  String get divers_edit_insuranceProviderHint => '例如 DAN、DiveAssure';

  @override
  String get divers_edit_insuranceProviderLabel => '保险提供商';

  @override
  String get divers_edit_insuranceSection => '潜水保险';

  @override
  String get divers_edit_keepEditingButton => '继续编辑';

  @override
  String get divers_edit_medicalClearanceExpired => '已过期';

  @override
  String get divers_edit_medicalClearanceExpiringSoon => '即将到期';

  @override
  String get divers_edit_medicalClearanceNotSet => '未设置';

  @override
  String get divers_edit_medicalClearanceTitle => '医疗许可到期日';

  @override
  String get divers_edit_medicalInfoSection => '医疗信息';

  @override
  String get divers_edit_medicalNotesLabel => '医疗备注';

  @override
  String get divers_edit_medicationsHint => '例如，每日阿司匹林、肾上腺素笔';

  @override
  String get divers_edit_medicationsLabel => '用药';

  @override
  String get divers_edit_nameError => '姓名为必填项';

  @override
  String get divers_edit_nameLabel => '名称 *';

  @override
  String get divers_edit_notesLabel => '备注';

  @override
  String get divers_edit_notesSection => '备注';

  @override
  String get divers_edit_personalInfoSection => '个人信息';

  @override
  String get divers_edit_phoneLabel => '电话';

  @override
  String get divers_edit_policyNumberLabel => '保单编号';

  @override
  String get divers_edit_primaryContactTitle => '主要联系人';

  @override
  String get divers_edit_relationshipHint => '例如，配偶、父母、朋友';

  @override
  String get divers_edit_relationshipLabel => '关系';

  @override
  String get divers_edit_saveButton => '保存';

  @override
  String get divers_edit_secondaryContactTitle => '备用联系人';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip => '选择保险到期日';

  @override
  String get divers_edit_selectMedicalClearanceTooltip => '选择医疗许可日期';

  @override
  String get divers_edit_updateButton => '更新潜水员';

  @override
  String get divers_list_activeBadge => '活跃';

  @override
  String get divers_list_addDiverButton => '添加潜水员';

  @override
  String get divers_list_addDiverTooltip => '添加新的潜水员档案';

  @override
  String get divers_list_appBarTitle => '潜水员档案';

  @override
  String get divers_list_compactTitle => '潜水员';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount 次潜水$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle => '添加潜水员档案以追踪多人的潜水日志';

  @override
  String get divers_list_emptyTitle => '尚无潜水员';

  @override
  String divers_list_errorLoading(Object error) {
    return '加载潜水员出错：$error';
  }

  @override
  String get divers_list_errorLoadingStats => '加载统计数据出错';

  @override
  String get divers_list_loadingStats => '加载中...';

  @override
  String get divers_list_retryButton => '重试';

  @override
  String divers_list_viewDiverLabel(Object name) {
    return '查看潜水员 $name';
  }

  @override
  String get divers_summary_activeDiverTitle => '当前潜水员';

  @override
  String get divers_summary_otherDiversTitle => '其他潜水员';

  @override
  String get divers_summary_overviewTitle => '概览';

  @override
  String get divers_summary_quickActionsTitle => '快捷操作';

  @override
  String get divers_summary_subtitle => '从列表中选择潜水员以查看详情';

  @override
  String get divers_summary_title => '潜水员档案';

  @override
  String get divers_summary_totalDiversLabel => '潜水员总数';

  @override
  String divers_detail_deleteDialogConfirmHint(String name) {
    return 'Type \"Delete $name\" to confirm';
  }

  @override
  String divers_detail_deleteDialogConfirmText(String name) {
    return 'Delete $name';
  }

  @override
  String get enum_altitudeGroup_extreme => '极端高海拔';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => '海拔组 1';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => '海拔组 2';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => '海拔组 3';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => '海等级';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => '危险';

  @override
  String get enum_ascentRate_safe => '安全';

  @override
  String get enum_ascentRate_warning => '警告';

  @override
  String get enum_buddyRole_buddy => '潜伴';

  @override
  String get enum_buddyRole_diveGuide => '潜水指南';

  @override
  String get enum_buddyRole_diveMaster => '潜水长';

  @override
  String get enum_buddyRole_instructor => '教练';

  @override
  String get enum_buddyRole_solo => '单人';

  @override
  String get enum_buddyRole_student => '学生';

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
  String get enum_certificationAgency_other => '其他';

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
  String get enum_certificationLevel_advancedNitrox => '高级高氧空气';

  @override
  String get enum_certificationLevel_advancedOpenWater => '进阶开放水域';

  @override
  String get enum_certificationLevel_cave => '洞穴';

  @override
  String get enum_certificationLevel_cavern => '洞穴潜水员';

  @override
  String get enum_certificationLevel_courseDirector => '课程总监';

  @override
  String get enum_certificationLevel_decompression => '减压';

  @override
  String get enum_certificationLevel_diveMaster => '潜水长';

  @override
  String get enum_certificationLevel_instructor => '教练';

  @override
  String get enum_certificationLevel_masterInstructor => '高级教练';

  @override
  String get enum_certificationLevel_nitrox => '高氧空气';

  @override
  String get enum_certificationLevel_openWater => '开放水域';

  @override
  String get enum_certificationLevel_other => '其他';

  @override
  String get enum_certificationLevel_rebreather => '循环呼吸器';

  @override
  String get enum_certificationLevel_rescue => '救援潜水员';

  @override
  String get enum_certificationLevel_sidemount => '侧挂';

  @override
  String get enum_certificationLevel_techDiver => '技术潜水员';

  @override
  String get enum_certificationLevel_trimix => '三混气';

  @override
  String get enum_certificationLevel_wreck => '沉船';

  @override
  String get enum_currentDirection_east => '东';

  @override
  String get enum_currentDirection_none => '无';

  @override
  String get enum_currentDirection_north => '北';

  @override
  String get enum_currentDirection_northEast => '北-东';

  @override
  String get enum_currentDirection_northWest => '北-西';

  @override
  String get enum_currentDirection_south => '南';

  @override
  String get enum_currentDirection_southEast => '南-东';

  @override
  String get enum_currentDirection_southWest => '南-西';

  @override
  String get enum_currentDirection_variable => '变化';

  @override
  String get enum_currentDirection_west => '西';

  @override
  String get enum_currentStrength_light => '轻微';

  @override
  String get enum_currentStrength_moderate => '中等';

  @override
  String get enum_currentStrength_none => '无';

  @override
  String get enum_currentStrength_strong => '强';

  @override
  String get enum_diveMode_ccr => '密闭循环呼吸器';

  @override
  String get enum_diveMode_oc => '开放式';

  @override
  String get enum_diveMode_scr => '半密闭循环呼吸器';

  @override
  String get enum_diveType_altitude => '高海拔';

  @override
  String get enum_diveType_boat => '船潜';

  @override
  String get enum_diveType_cave => '洞穴';

  @override
  String get enum_diveType_deep => '深潜';

  @override
  String get enum_diveType_drift => '放流';

  @override
  String get enum_diveType_freedive => '自由潜';

  @override
  String get enum_diveType_ice => '冰潜';

  @override
  String get enum_diveType_liveaboard => '船宿';

  @override
  String get enum_diveType_night => '夜间';

  @override
  String get enum_diveType_recreational => '休闲';

  @override
  String get enum_diveType_shore => '岸潜';

  @override
  String get enum_diveType_technical => '技术';

  @override
  String get enum_diveType_training => '培训';

  @override
  String get enum_diveType_wreck => '沉船';

  @override
  String get enum_entryMethod_backRoll => '背滚式入水';

  @override
  String get enum_entryMethod_boat => '船只入水';

  @override
  String get enum_entryMethod_giantStride => '大跨步入水';

  @override
  String get enum_entryMethod_jetty => '码头/栈桥';

  @override
  String get enum_entryMethod_ladder => '梯子';

  @override
  String get enum_entryMethod_other => '其他';

  @override
  String get enum_entryMethod_platform => '平台';

  @override
  String get enum_entryMethod_seatedEntry => '坐式入水';

  @override
  String get enum_entryMethod_shore => '岸边入水';

  @override
  String get enum_equipmentStatus_active => '活跃';

  @override
  String get enum_equipmentStatus_inService => '在维护';

  @override
  String get enum_equipmentStatus_loaned => '已借出';

  @override
  String get enum_equipmentStatus_lost => '遗失';

  @override
  String get enum_equipmentStatus_needsService => '需要维护';

  @override
  String get enum_equipmentStatus_retired => '已退役';

  @override
  String get enum_equipmentType_bcd => '浮力控制装置';

  @override
  String get enum_equipmentType_boots => '潜水靴';

  @override
  String get enum_equipmentType_camera => '相机';

  @override
  String get enum_equipmentType_computer => '潜水电脑';

  @override
  String get enum_equipmentType_drysuit => '干衣';

  @override
  String get enum_equipmentType_fins => '脚蹼';

  @override
  String get enum_equipmentType_gloves => '手套';

  @override
  String get enum_equipmentType_hood => '潜水头套';

  @override
  String get enum_equipmentType_knife => '潜水刀';

  @override
  String get enum_equipmentType_light => '潜水灯';

  @override
  String get enum_equipmentType_mask => '面镜';

  @override
  String get enum_equipmentType_other => '其他';

  @override
  String get enum_equipmentType_reel => '卷线器';

  @override
  String get enum_equipmentType_regulator => '调节器';

  @override
  String get enum_equipmentType_smb => '水面标志浮标';

  @override
  String get enum_equipmentType_tank => '气瓶';

  @override
  String get enum_equipmentType_weights => '重量';

  @override
  String get enum_equipmentType_wetsuit => '湿衣';

  @override
  String get enum_eventSeverity_alert => '警报';

  @override
  String get enum_eventSeverity_info => '信息';

  @override
  String get enum_eventSeverity_warning => '警告';

  @override
  String get enum_pdfPageSize_a4 => 'A4';

  @override
  String get enum_pdfPageSize_a4_description => '210 x 297 mm';

  @override
  String get enum_pdfPageSize_letter => 'Letter';

  @override
  String get enum_pdfPageSize_letter_description => '8.5 x 11 in';

  @override
  String get enum_pdfTemplate_detailed => '详细';

  @override
  String get enum_pdfTemplate_detailed_description => '包含备注和评分的完整潜水信息';

  @override
  String get enum_pdfTemplate_nauiStyle => 'NAUI 样式';

  @override
  String get enum_pdfTemplate_nauiStyle_description => '匹配 NAUI 潜水日志格式的布局';

  @override
  String get enum_pdfTemplate_padiStyle => 'PADI 样式';

  @override
  String get enum_pdfTemplate_padiStyle_description => '匹配 PADI 潜水日志格式的布局';

  @override
  String get enum_pdfTemplate_professional => '专业';

  @override
  String get enum_pdfTemplate_professional_description => '包含签名和盖章区域用于验证';

  @override
  String get enum_pdfTemplate_simple => '简洁';

  @override
  String get enum_pdfTemplate_simple_description => '紧凑的表格格式，每页可容纳多次潜水';

  @override
  String get enum_profileEvent_alert => '警报';

  @override
  String get enum_profileEvent_ascentRateCritical => '上升速率危急';

  @override
  String get enum_profileEvent_ascentRateWarning => '上升速率警告';

  @override
  String get enum_profileEvent_ascentStart => '上升开始';

  @override
  String get enum_profileEvent_bookmark => '书签';

  @override
  String get enum_profileEvent_cnsCritical => 'CNS 危急';

  @override
  String get enum_profileEvent_cnsWarning => 'CNS 警告';

  @override
  String get enum_profileEvent_decoStopEnd => '减压停留结束';

  @override
  String get enum_profileEvent_decoStopStart => '减压停留开始';

  @override
  String get enum_profileEvent_decoViolation => '减压违规';

  @override
  String get enum_profileEvent_gasSwitch => '气体切换';

  @override
  String get enum_profileEvent_lowGas => '低气体警告';

  @override
  String get enum_profileEvent_maxDepth => '最大深度';

  @override
  String get enum_profileEvent_missedStop => '错过减压停留';

  @override
  String get enum_profileEvent_note => '备注';

  @override
  String get enum_profileEvent_ppO2High => '氧分压过高';

  @override
  String get enum_profileEvent_ppO2Low => '氧分压过低';

  @override
  String get enum_profileEvent_safetyStopEnd => '安全停留结束';

  @override
  String get enum_profileEvent_safetyStopStart => '安全停留开始';

  @override
  String get enum_profileEvent_setpointChange => '设定值变更';

  @override
  String get enum_profileMetricCategory_decompression => '减压';

  @override
  String get enum_profileMetricCategory_gasAnalysis => '气体分析';

  @override
  String get enum_profileMetricCategory_gradientFactor => '梯度因子';

  @override
  String get enum_profileMetricCategory_other => '其他';

  @override
  String get enum_profileMetricCategory_primary => '主要指标';

  @override
  String get enum_profileMetric_gasDensity => '气体密度';

  @override
  String get enum_profileMetric_gasDensity_short => '密度';

  @override
  String get enum_profileMetric_gf => 'GF%';

  @override
  String get enum_profileMetric_gf_short => 'GF%';

  @override
  String get enum_profileMetric_heartRate => '心率';

  @override
  String get enum_profileMetric_heartRate_short => '心率';

  @override
  String get enum_profileMetric_meanDepth => '平均深度';

  @override
  String get enum_profileMetric_meanDepth_short => '平均';

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
  String get enum_profileMetric_pressure => '压力';

  @override
  String get enum_profileMetric_pressure_short => '压力';

  @override
  String get enum_profileMetric_sacRate => '气体消耗率';

  @override
  String get enum_profileMetric_sacRate_short => 'SAC';

  @override
  String get enum_profileMetric_surfaceGf => '水面 GF';

  @override
  String get enum_profileMetric_surfaceGf_short => '水面GF';

  @override
  String get enum_profileMetric_temperature => '温度';

  @override
  String get enum_profileMetric_temperature_short => '温度';

  @override
  String get enum_profileMetric_tts => '到达水面时间';

  @override
  String get enum_profileMetric_tts_short => 'TTS';

  @override
  String get enum_scrType_cmf => '恒定质量流';

  @override
  String get enum_scrType_cmf_short => 'CMF';

  @override
  String get enum_scrType_escr => '电控式';

  @override
  String get enum_scrType_escr_short => 'ESCR';

  @override
  String get enum_scrType_pascr => '被动添加式';

  @override
  String get enum_scrType_pascr_short => 'PASCR';

  @override
  String get enum_serviceType_annual => '年度维护';

  @override
  String get enum_serviceType_calibration => '校准';

  @override
  String get enum_serviceType_cleaning => '清洁';

  @override
  String get enum_serviceType_inspection => '检查';

  @override
  String get enum_serviceType_other => '其他';

  @override
  String get enum_serviceType_overhaul => '大修';

  @override
  String get enum_serviceType_recall => '召回/安全';

  @override
  String get enum_serviceType_repair => '维修';

  @override
  String get enum_serviceType_replacement => '部件更换';

  @override
  String get enum_serviceType_warranty => '保修维护';

  @override
  String get enum_sortDirection_ascending => '升序';

  @override
  String get enum_sortDirection_descending => '降序';

  @override
  String get enum_sortField_agency => '机构';

  @override
  String get enum_sortField_date => '日期';

  @override
  String get enum_sortField_dateIssued => '签发日期';

  @override
  String get enum_sortField_difficulty => '难度';

  @override
  String get enum_sortField_diveCount => '潜水计数';

  @override
  String get enum_sortField_diveNumber => '潜水编号';

  @override
  String get enum_sortField_duration => '时长';

  @override
  String get enum_sortField_endDate => '结束日期';

  @override
  String get enum_sortField_lastServiceDate => '最近维护';

  @override
  String get enum_sortField_maxDepth => '最大深度';

  @override
  String get enum_sortField_name => '名称';

  @override
  String get enum_sortField_purchaseDate => '购买日期';

  @override
  String get enum_sortField_rating => '评分';

  @override
  String get enum_sortField_site => '潜水点';

  @override
  String get enum_sortField_startDate => '开始日期';

  @override
  String get enum_sortField_status => '状态';

  @override
  String get enum_sortField_type => '类型';

  @override
  String get enum_speciesCategory_coral => '珊瑚';

  @override
  String get enum_speciesCategory_fish => '鱼类';

  @override
  String get enum_speciesCategory_invertebrate => '无脊椎动物';

  @override
  String get enum_speciesCategory_mammal => '哺乳动物';

  @override
  String get enum_speciesCategory_other => '其他';

  @override
  String get enum_speciesCategory_plant => '植物/藻类';

  @override
  String get enum_speciesCategory_ray => '鳐鱼';

  @override
  String get enum_speciesCategory_shark => '鲨鱼';

  @override
  String get enum_speciesCategory_turtle => '海龟';

  @override
  String get enum_tankMaterial_aluminum => '铝合金';

  @override
  String get enum_tankMaterial_carbonFiber => '碳纤维';

  @override
  String get enum_tankMaterial_steel => '钢';

  @override
  String get enum_tankRole_backGas => '背部气体';

  @override
  String get enum_tankRole_bailout => '应急气瓶';

  @override
  String get enum_tankRole_deco => '减压';

  @override
  String get enum_tankRole_diluent => '稀释气';

  @override
  String get enum_tankRole_oxygenSupply => 'O₂ 供气';

  @override
  String get enum_tankRole_pony => '备用小瓶';

  @override
  String get enum_tankRole_sidemountLeft => '左侧挂';

  @override
  String get enum_tankRole_sidemountRight => '右侧挂';

  @override
  String get enum_tankRole_stage => '阶段';

  @override
  String get enum_visibility_excellent => '极好 (>30m / >100ft)';

  @override
  String get enum_visibility_good => '良好 (15-30m / 50-100ft)';

  @override
  String get enum_visibility_moderate => '一般 (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => '较差 (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => '未知';

  @override
  String get enum_waterType_brackish => '半咸水';

  @override
  String get enum_waterType_fresh => '淡水';

  @override
  String get enum_waterType_salt => '海水';

  @override
  String get enum_weightType_ankleWeights => '脚踝配重';

  @override
  String get enum_weightType_backplate => '背板配重';

  @override
  String get enum_weightType_belt => '配重带';

  @override
  String get enum_weightType_integrated => '整合式配重';

  @override
  String get enum_weightType_mixed => '混合/组合';

  @override
  String get enum_weightType_trimWeights => '配平配重';

  @override
  String get equipment_addSheet_brandHint => '例如 Scubapro';

  @override
  String get equipment_addSheet_brandLabel => '品牌';

  @override
  String get equipment_addSheet_closeTooltip => '关闭';

  @override
  String get equipment_addSheet_currencyLabel => '货币';

  @override
  String get equipment_addSheet_dateLabel => '日期';

  @override
  String equipment_addSheet_errorSnackbar(Object error) {
    return '添加装备出错：$error';
  }

  @override
  String get equipment_addSheet_modelHint => '例如 MK25 EVO';

  @override
  String get equipment_addSheet_modelLabel => '型号';

  @override
  String get equipment_addSheet_nameHint => '例如：我的主调节器';

  @override
  String get equipment_addSheet_nameLabel => '名称';

  @override
  String get equipment_addSheet_nameValidation => '请输入名称';

  @override
  String get equipment_addSheet_notesHint => '其他备注...';

  @override
  String get equipment_addSheet_notesLabel => '备注';

  @override
  String get equipment_addSheet_priceLabel => '价格';

  @override
  String get equipment_addSheet_purchaseInfoTitle => '购买信息';

  @override
  String get equipment_addSheet_serialNumberLabel => '序列编号';

  @override
  String get equipment_addSheet_serviceIntervalHint => '例如 365 表示每年';

  @override
  String get equipment_addSheet_serviceIntervalLabel => '维护间隔（天）';

  @override
  String get equipment_addSheet_sizeHint => 'e.g., M, L, 42';

  @override
  String get equipment_addSheet_sizeLabel => '尺寸';

  @override
  String get equipment_addSheet_submitButton => '添加装备';

  @override
  String get equipment_addSheet_successSnackbar => '装备添加成功';

  @override
  String get equipment_addSheet_title => '添加装备';

  @override
  String get equipment_addSheet_typeLabel => '类型';

  @override
  String get equipment_appBar_title => '装备';

  @override
  String get equipment_deleteDialog_cancel => '取消';

  @override
  String get equipment_deleteDialog_confirm => '删除';

  @override
  String get equipment_deleteDialog_content => '确定要删除此装备吗？此操作无法撤销。';

  @override
  String get equipment_deleteDialog_title => '删除装备';

  @override
  String get equipment_detail_brandLabel => '品牌';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return '已逾期 $days 天';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days 天后需维护';
  }

  @override
  String get equipment_detail_detailsTitle => '详情';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count 次潜水';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count 潜水';
  }

  @override
  String get equipment_detail_divesLabel => '潜水';

  @override
  String get equipment_detail_divesSemanticLabel => '查看使用此装备的潜水记录';

  @override
  String equipment_detail_durationDays(Object days) {
    return '$days 天';
  }

  @override
  String equipment_detail_durationMonths(Object months) {
    return '$months 个月';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralPlural(
    Object years,
    Object months,
  ) {
    return '$years 年 $months 个月';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralSingular(
    Object years,
    Object months,
  ) {
    return '$years 年 $months 个月';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularPlural(
    Object years,
    Object months,
  ) {
    return '$years 年 $months 个月';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularSingular(
    Object years,
    Object months,
  ) {
    return '$years 年, $months 月';
  }

  @override
  String equipment_detail_durationYearsPlural(Object years) {
    return '$years 年';
  }

  @override
  String equipment_detail_durationYearsSingular(Object years) {
    return '$years 年';
  }

  @override
  String get equipment_detail_editTooltip => '编辑装备';

  @override
  String get equipment_detail_editTooltipShort => '编辑';

  @override
  String equipment_detail_errorMessage(Object error) {
    return '错误： $error';
  }

  @override
  String get equipment_detail_errorTitle => '错误';

  @override
  String get equipment_detail_lastServiceLabel => '最近维护';

  @override
  String get equipment_detail_loadingTitle => '加载中...';

  @override
  String get equipment_detail_modelLabel => '型号';

  @override
  String get equipment_detail_nextServiceDueLabel => '下次维护日期';

  @override
  String get equipment_detail_notFoundMessage => '此装备已不存在。';

  @override
  String get equipment_detail_notFoundTitle => '装备未找到';

  @override
  String get equipment_detail_notesTitle => '备注';

  @override
  String get equipment_detail_ownedForLabel => '拥有为';

  @override
  String get equipment_detail_purchaseDateLabel => '购买日期';

  @override
  String get equipment_detail_purchasePriceLabel => '购买价格';

  @override
  String get equipment_detail_retiredChip => '已退役';

  @override
  String get equipment_detail_serialNumberLabel => '序列编号';

  @override
  String get equipment_detail_serviceInfoTitle => '维护信息';

  @override
  String get equipment_detail_serviceIntervalLabel => '维护间隔';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days 天';
  }

  @override
  String get equipment_detail_serviceOverdue => '维护已逾期！';

  @override
  String get equipment_detail_sizeLabel => '尺寸';

  @override
  String get equipment_detail_statusLabel => '状态';

  @override
  String equipment_detail_tripsCountPlural(Object count) {
    return '$count 次旅行';
  }

  @override
  String equipment_detail_tripsCountSingular(Object count) {
    return '$count 旅行';
  }

  @override
  String get equipment_detail_tripsLabel => '旅行';

  @override
  String get equipment_detail_tripsSemanticLabel => '查看使用此装备的旅行';

  @override
  String get equipment_edit_appBar_editTitle => '编辑装备';

  @override
  String get equipment_edit_appBar_newTitle => '新建装备';

  @override
  String get equipment_edit_appBar_saveButton => '保存';

  @override
  String get equipment_edit_appBar_saveTooltip => '保存装备更改';

  @override
  String get equipment_edit_brandLabel => '品牌';

  @override
  String get equipment_edit_clearDate => '清除日期';

  @override
  String get equipment_edit_currencyLabel => '货币';

  @override
  String get equipment_edit_disableReminders => '禁用提醒';

  @override
  String get equipment_edit_disableRemindersSubtitle => '关闭此物品的所有通知';

  @override
  String get equipment_edit_discardDialog_content => '您有未保存的更改。确定要离开吗?';

  @override
  String get equipment_edit_discardDialog_discard => '丢弃';

  @override
  String get equipment_edit_discardDialog_keepEditing => '继续编辑';

  @override
  String get equipment_edit_discardDialog_title => '丢弃更改？';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => '取消';

  @override
  String get equipment_edit_embeddedHeader_editTitle => '编辑装备';

  @override
  String get equipment_edit_embeddedHeader_newTitle => '新建装备';

  @override
  String get equipment_edit_embeddedHeader_saveButton => '保存';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit => '保存装备更改';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new => '添加新装备';

  @override
  String equipment_edit_errorMessage(Object error) {
    return '错误： $error';
  }

  @override
  String get equipment_edit_errorTitle => '错误';

  @override
  String get equipment_edit_lastServiceDateLabel => '上次维护日期';

  @override
  String get equipment_edit_loadingTitle => '加载中...';

  @override
  String get equipment_edit_modelLabel => '型号';

  @override
  String get equipment_edit_nameHint => '例如：我的主调节器';

  @override
  String get equipment_edit_nameLabel => '名称 *';

  @override
  String get equipment_edit_nameValidation => '请输入名称';

  @override
  String get equipment_edit_notFoundMessage => '此装备已不存在。';

  @override
  String get equipment_edit_notFoundTitle => '装备未找到';

  @override
  String get equipment_edit_notesHint => '关于此装备的其他备注...';

  @override
  String get equipment_edit_notesLabel => '备注';

  @override
  String get equipment_edit_notificationsSubtitle => '覆盖此物品的全局通知设置';

  @override
  String get equipment_edit_notificationsTitle => '通知 (可选)';

  @override
  String get equipment_edit_purchaseDateLabel => '购买日期';

  @override
  String get equipment_edit_purchaseInfoTitle => '购买信息';

  @override
  String get equipment_edit_purchasePriceLabel => '购买价格';

  @override
  String get equipment_edit_remindMeBeforeServiceDue => '在维护到期前提醒我：';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days 天';
  }

  @override
  String get equipment_edit_saveButton_edit => '保存更改';

  @override
  String get equipment_edit_saveButton_new => '添加装备';

  @override
  String get equipment_edit_saveTooltip_edit => '保存装备更改';

  @override
  String get equipment_edit_saveTooltip_new => '添加新装备';

  @override
  String get equipment_edit_selectDate => '选择日期';

  @override
  String get equipment_edit_serialNumberLabel => '序列编号';

  @override
  String get equipment_edit_serviceIntervalHint => '例如 365 表示每年';

  @override
  String get equipment_edit_serviceIntervalLabel => '维护间隔（天）';

  @override
  String get equipment_edit_serviceSettingsTitle => '维护设置';

  @override
  String get equipment_edit_sizeHint => 'e.g., M, L, 42';

  @override
  String get equipment_edit_sizeLabel => '尺寸';

  @override
  String get equipment_edit_snackbar_added => '装备已添加';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return '保存装备出错：$error';
  }

  @override
  String get equipment_edit_snackbar_updated => '装备已更新';

  @override
  String get equipment_edit_statusLabel => '状态';

  @override
  String get equipment_edit_typeLabel => '类型 *';

  @override
  String get equipment_edit_useCustomReminders => '使用自定义提醒';

  @override
  String get equipment_edit_useCustomRemindersSubtitle => '为此物品设置不同的提醒天数';

  @override
  String get equipment_fab_addEquipment => '添加装备';

  @override
  String get equipment_fab_addSet => '添加套装';

  @override
  String get equipment_list_emptyState_addFirstButton => '添加您的第一件装备';

  @override
  String get equipment_list_emptyState_addPrompt => '添加您的潜水装备以追踪使用情况和维护';

  @override
  String get equipment_list_emptyState_filterText_equipment => '装备';

  @override
  String get equipment_list_emptyState_filterText_serviceDue => '需要维护的装备';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return '$status 装备';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return '没有$filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch => '没有此状态的装备';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate => '您的所有装备维护都已是最新状态！';

  @override
  String equipment_list_errorLoading(Object error) {
    return '加载装备出错：$error';
  }

  @override
  String get equipment_list_filterAll => '全部装备';

  @override
  String get equipment_list_filterLabel => '筛选:';

  @override
  String get equipment_list_filterServiceDue => '需要维护';

  @override
  String get equipment_list_retryButton => '重试';

  @override
  String get equipment_list_searchTooltip => '搜索装备';

  @override
  String get equipment_list_setsTooltip => '装备套装';

  @override
  String get equipment_list_sortTitle => '排序装备';

  @override
  String get equipment_list_sortTooltip => '排序';

  @override
  String equipment_list_tile_daysCount(Object days) {
    return '$days 天';
  }

  @override
  String get equipment_list_tile_serviceDueChip => '需要维护';

  @override
  String get equipment_list_tile_serviceIn => '维护在';

  @override
  String get equipment_menu_delete => '删除';

  @override
  String get equipment_menu_markAsServiced => '标记为已维护';

  @override
  String get equipment_menu_reactivate => '重新激活';

  @override
  String get equipment_menu_retireEquipment => '停用装备';

  @override
  String get equipment_search_backTooltip => '返回';

  @override
  String get equipment_search_clearTooltip => '清除搜索';

  @override
  String get equipment_search_fieldLabel => '搜索装备...';

  @override
  String get equipment_search_hint => '按名称、品牌、型号或序列号搜索';

  @override
  String equipment_search_noResults(Object query) {
    return '无装备已找到为 \"$query\"';
  }

  @override
  String get equipment_serviceDialog_addButton => '添加';

  @override
  String get equipment_serviceDialog_addTitle => '添加维护记录';

  @override
  String get equipment_serviceDialog_cancelButton => '取消';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip => '清除下次维护日期';

  @override
  String get equipment_serviceDialog_costHint => '0.00';

  @override
  String get equipment_serviceDialog_costLabel => '费用';

  @override
  String get equipment_serviceDialog_costValidation => '请输入有效金额';

  @override
  String get equipment_serviceDialog_editTitle => '编辑维护记录';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel => '下次维护日期';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel => '选择下次维护日期';

  @override
  String get equipment_serviceDialog_nextServiceNotSet => '未设置';

  @override
  String get equipment_serviceDialog_notesLabel => '备注';

  @override
  String get equipment_serviceDialog_providerHint => '例如：潜水店名称';

  @override
  String get equipment_serviceDialog_providerLabel => '服务商/店铺';

  @override
  String get equipment_serviceDialog_serviceDateLabel => '维护日期';

  @override
  String get equipment_serviceDialog_serviceDateSemanticLabel => '选择维护日期';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => '维护类型';

  @override
  String get equipment_serviceDialog_snackbar_added => '维护记录已添加';

  @override
  String equipment_serviceDialog_snackbar_error(Object error) {
    return '错误： $error';
  }

  @override
  String get equipment_serviceDialog_snackbar_updated => '维护记录已更新';

  @override
  String get equipment_serviceDialog_updateButton => '更新';

  @override
  String get equipment_service_addButton => '添加';

  @override
  String get equipment_service_deleteDialog_cancel => '取消';

  @override
  String get equipment_service_deleteDialog_confirm => '删除';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return '确定要删除此 $serviceType 记录吗？';
  }

  @override
  String get equipment_service_deleteDialog_title => '删除维护记录?';

  @override
  String get equipment_service_deleteMenuItem => '删除';

  @override
  String get equipment_service_editMenuItem => '编辑';

  @override
  String get equipment_service_emptyState => '尚无维护记录';

  @override
  String get equipment_service_historyTitle => '维护历史';

  @override
  String get equipment_service_snackbar_deleted => '维护记录已删除';

  @override
  String get equipment_service_totalCostLabel => '维护总费用';

  @override
  String get equipment_setDetail_addEquipmentButton => '添加装备';

  @override
  String get equipment_setDetail_deleteDialog_cancel => '取消';

  @override
  String get equipment_setDetail_deleteDialog_confirm => '删除';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      '确定要删除此装备套装吗？套装中的装备不会被删除。';

  @override
  String get equipment_setDetail_deleteDialog_title => '删除装备套装';

  @override
  String get equipment_setDetail_deleteMenuItem => '删除';

  @override
  String get equipment_setDetail_editTooltip => '编辑套装';

  @override
  String get equipment_setDetail_emptySet => '此套装中没有装备';

  @override
  String get equipment_setDetail_equipmentInSetTitle => '此套装中的装备';

  @override
  String equipment_setDetail_errorMessage(Object error) {
    return '错误： $error';
  }

  @override
  String get equipment_setDetail_errorTitle => '错误';

  @override
  String get equipment_setDetail_loadingTitle => '加载中...';

  @override
  String get equipment_setDetail_notFoundMessage => '此装备套装已不存在。';

  @override
  String get equipment_setDetail_notFoundTitle => '未找到套装';

  @override
  String get equipment_setDetail_snackbar_deleted => '装备套装已删除';

  @override
  String get equipment_setEdit_addEquipmentFirst => '请先添加装备再创建套装。';

  @override
  String get equipment_setEdit_appBar_editTitle => '编辑套装';

  @override
  String get equipment_setEdit_appBar_newTitle => '新建装备套装';

  @override
  String get equipment_setEdit_descriptionHint => '可选描述...';

  @override
  String get equipment_setEdit_descriptionLabel => '描述';

  @override
  String equipment_setEdit_errorMessage(Object error) {
    return '错误： $error';
  }

  @override
  String get equipment_setEdit_errorTitle => '错误';

  @override
  String get equipment_setEdit_loadingTitle => '加载中...';

  @override
  String get equipment_setEdit_nameHint => 'e.g., 温暖水设置';

  @override
  String get equipment_setEdit_nameLabel => '套装名称 *';

  @override
  String get equipment_setEdit_nameValidation => '请输入名称';

  @override
  String get equipment_setEdit_noEquipmentAvailable => '无装备可用';

  @override
  String get equipment_setEdit_notFoundMessage => '此装备套装已不存在。';

  @override
  String get equipment_setEdit_notFoundTitle => '未找到套装';

  @override
  String get equipment_setEdit_saveButton_edit => '保存更改';

  @override
  String get equipment_setEdit_saveButton_new => '创建套装';

  @override
  String get equipment_setEdit_saveTooltip_edit => '保存装备套装更改';

  @override
  String get equipment_setEdit_saveTooltip_new => '创建新装备套装';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle => '选择要包含在此套装中的装备。';

  @override
  String get equipment_setEdit_selectEquipmentTitle => '选择装备';

  @override
  String get equipment_setEdit_snackbar_created => '装备套装已创建';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return '保存出错装备套装: $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated => '装备套装已更新';

  @override
  String get equipment_sets_appBar_title => '装备套装';

  @override
  String get equipment_sets_emptyState_createFirstButton => '创建您的第一个套装';

  @override
  String get equipment_sets_emptyState_description =>
      '创建装备套装以快速将常用装备组合添加到您的潜水中。';

  @override
  String get equipment_sets_emptyState_title => '没有装备套装';

  @override
  String equipment_sets_errorLoading(Object error) {
    return '加载套装出错：$error';
  }

  @override
  String get equipment_sets_fabTooltip => '创建新装备套装';

  @override
  String get equipment_sets_fab_createSet => '创建套装';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count 项目';
  }

  @override
  String equipment_sets_itemCountSemanticLabel(Object count) {
    return '$count 在设置';
  }

  @override
  String equipment_sets_itemCountSingular(Object count) {
    return '$count 项目';
  }

  @override
  String get equipment_sets_retryButton => '重试';

  @override
  String get equipment_snackbar_deleted => '装备已删除';

  @override
  String get equipment_snackbar_markedAsServiced => '已标记为已维护';

  @override
  String get equipment_snackbar_reactivated => '装备已重新启用';

  @override
  String get equipment_snackbar_retired => '装备已停用';

  @override
  String get equipment_summary_active => '活跃';

  @override
  String get equipment_summary_addEquipmentButton => '添加装备';

  @override
  String get equipment_summary_equipmentSetsButton => '装备套装';

  @override
  String get equipment_summary_overviewTitle => '概览';

  @override
  String get equipment_summary_quickActionsTitle => '快捷操作';

  @override
  String get equipment_summary_recentEquipmentTitle => '最近装备';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name, $type';
  }

  @override
  String get equipment_summary_selectPrompt => '从列表中选择装备以查看详情';

  @override
  String get equipment_summary_serviceDue => '需要维护';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name, $type, 维护到期';
  }

  @override
  String get equipment_summary_serviceDueTitle => '需要维护';

  @override
  String get equipment_summary_title => '装备';

  @override
  String get equipment_summary_totalItems => '总件数';

  @override
  String get equipment_summary_totalValue => '总价值';

  @override
  String get equipment_tab_equipment => '装备';

  @override
  String get equipment_tab_sets => '套装';

  @override
  String get formatter_approximate_prefix => '~';

  @override
  String get formatter_connector_at => '于';

  @override
  String get formatter_connector_from => '从';

  @override
  String get formatter_connector_until => '至';

  @override
  String get gas_air_description => '标准空气 (21% O2)';

  @override
  String get gas_air_displayName => '空气';

  @override
  String get gas_diluentAir_description => '用于浅水闭路循环呼吸器的标准空气稀释气';

  @override
  String get gas_diluentAir_displayName => '空气稀释气';

  @override
  String get gas_diluentTx1070_description => '用于极深闭路循环呼吸器的低氧稀释气';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description => '用于深水闭路循环呼吸器的低氧稀释气';

  @override
  String get gas_diluentTx1260_displayName => 'Tx 12/60';

  @override
  String get gas_ean32_description => '高氧空气 32%';

  @override
  String get gas_ean32_displayName => 'EAN32';

  @override
  String get gas_ean36_description => '高氧空气 36%';

  @override
  String get gas_ean36_displayName => 'EAN36';

  @override
  String get gas_ean40_description => '高氧空气 40%';

  @override
  String get gas_ean40_displayName => 'EAN40';

  @override
  String get gas_ean50_description => '减压气体 - 50% O2';

  @override
  String get gas_ean50_displayName => 'EAN50';

  @override
  String get gas_helitrox2525_description => '氦氧三混气 25/25（休闲技术潜水）';

  @override
  String get gas_helitrox2525_displayName => 'Helitrox 25/25';

  @override
  String get gas_oxygen_description => '纯氧（仅用于 6m 减压）';

  @override
  String get gas_oxygen_displayName => '氧气';

  @override
  String get gas_scrEan40_description => '半闭路循环呼吸器供气 - 40% 氧气';

  @override
  String get gas_scrEan40_displayName => 'SCR EAN40';

  @override
  String get gas_scrEan50_description => '半闭路循环呼吸器供气 - 50% 氧气';

  @override
  String get gas_scrEan50_displayName => 'SCR EAN50';

  @override
  String get gas_scrEan60_description => '半闭路循环呼吸器供气 - 60% 氧气';

  @override
  String get gas_scrEan60_displayName => 'SCR EAN60';

  @override
  String get gas_tmx1555_description => '低氧三混气 15/55（极深潜水）';

  @override
  String get gas_tmx1555_displayName => 'Tx 15/55';

  @override
  String get gas_tmx1845_description => '三混气 18/45（深潜）';

  @override
  String get gas_tmx1845_displayName => 'Tx 18/45';

  @override
  String get gas_tmx2135_description => '常氧三混气 21/35';

  @override
  String get gas_tmx2135_displayName => 'Tx 21/35';

  @override
  String get gasCalculators_bestMix_bestOxygenMix => '最佳氧气混合';

  @override
  String get gasCalculators_bestMix_commonMixesRef => '常用混合气参考';

  @override
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2) {
    return '在氧分压 $ppO2 时超过空气最大作业深度';
  }

  @override
  String get gasCalculators_bestMix_targetDepth => '目标深度';

  @override
  String get gasCalculators_bestMix_targetDive => '目标潜水';

  @override
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  ) {
    return '在 $depth$depthSymbol 处的环境压力';
  }

  @override
  String get gasCalculators_consumption_avgDepth => '平均深度';

  @override
  String get gasCalculators_consumption_breakdown => '计算明细';

  @override
  String get gasCalculators_consumption_diveTime => '潜水时间';

  @override
  String gasCalculators_consumption_exceedsTank(
    Object pressure,
    Object symbol,
  ) {
    return '超过气瓶容量 ($pressure $symbol)';
  }

  @override
  String get gasCalculators_consumption_gasAtDepth => '气体消耗在深度';

  @override
  String get gasCalculators_consumption_pressure => '压力';

  @override
  String get gasCalculators_consumption_remainingGas => '剩余气体';

  @override
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  ) {
    return '气瓶容量 ($tankSize$volumeSymbol @ $fillPressure $pressureSymbol)';
  }

  @override
  String get gasCalculators_consumption_title => '气体消耗';

  @override
  String gasCalculators_consumption_totalGas(Object time) {
    return '$time 分钟所需总气量';
  }

  @override
  String get gasCalculators_consumption_volume => '容积';

  @override
  String get gasCalculators_mod_aboutMod => '关于 MOD';

  @override
  String get gasCalculators_mod_aboutModBody => 'O₂ 越低 = 最大作业深度越深 = 免减压极限越短';

  @override
  String get gasCalculators_mod_inputParameters => '输入参数';

  @override
  String get gasCalculators_mod_maximumOperatingDepth => '最大作业深度';

  @override
  String get gasCalculators_mod_oxygenO2 => '氧气 (O₂)';

  @override
  String get gasCalculators_mod_ppO2Conservative => '延长底部时间的保守限制';

  @override
  String get gasCalculators_mod_ppO2Maximum => '仅用于减压停留的最大限制';

  @override
  String get gasCalculators_mod_ppO2Standard => '休闲潜水的标准工作限制';

  @override
  String get gasCalculators_mnd_depthInput => '深度';

  @override
  String get gasCalculators_mnd_endAtDepthTitle => '指定深度的等效麻醉深度';

  @override
  String get gasCalculators_mnd_endLimit => 'END 限制';

  @override
  String get gasCalculators_mnd_hePercent => 'He %';

  @override
  String get gasCalculators_mnd_infoContent =>
      '最大麻醉深度 (MND) 是指在麻醉效应超过您的等效麻醉深度限制之前可以到达的最大深度。等效麻醉深度 (END) 表示您的气体在给定深度的麻醉效应。\n\n启用「氧气具有麻醉性」时，氧气和氮气都会导致麻醉（更保守）。禁用时，仅考虑氮气的麻醉作用。';

  @override
  String get gasCalculators_mnd_infoTitle => '关于最大麻醉深度/等效麻醉深度';

  @override
  String get gasCalculators_mnd_unlimited => '无限';

  @override
  String get gasCalculators_mnd_inputParameters => '气体混合与麻醉设置';

  @override
  String get gasCalculators_mnd_o2Narcotic => 'O2 有麻醉性';

  @override
  String get gasCalculators_mnd_o2Percent => 'O2 %';

  @override
  String get gasCalculators_mnd_resultTitle => '最大麻醉深度';

  @override
  String get gasCalculators_ppO2Limit => '氧分压限制';

  @override
  String get gasCalculators_resetAll => '重置所有计算器';

  @override
  String get gasCalculators_sacRate => '气体消耗率';

  @override
  String get gasCalculators_tab_bestMix => '最佳混合气';

  @override
  String get gasCalculators_tab_consumption => '消耗';

  @override
  String get gasCalculators_tab_mnd => '最大麻醉深度/等效麻醉深度';

  @override
  String get gasCalculators_tab_mod => 'MOD';

  @override
  String get gasCalculators_tab_rockBottom => '最低储备';

  @override
  String get gasCalculators_tankSize => '气瓶大小';

  @override
  String get gasCalculators_title => '气体计算器';

  @override
  String get marineLife_siteSection_editExpectedTooltip => '编辑预期物种';

  @override
  String get marineLife_siteSection_errorLoadingExpected => '加载预期物种出错';

  @override
  String get marineLife_siteSection_errorLoadingSightings => '加载目击记录出错';

  @override
  String get marineLife_siteSection_expectedSpecies => '预期物种';

  @override
  String get marineLife_siteSection_noExpected => '未添加预期物种';

  @override
  String get marineLife_siteSection_noSpotted => '尚无海洋生物目击记录';

  @override
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  ) {
    return '$name，目击 $count 次';
  }

  @override
  String get marineLife_siteSection_spottedHere => '发现此处';

  @override
  String get marineLife_siteSection_title => '海洋生物';

  @override
  String get marineLife_speciesDetail_backTooltip => '返回';

  @override
  String get marineLife_speciesDetail_depthRangeTitle => '深度范围';

  @override
  String get marineLife_speciesDetail_descriptionTitle => '描述';

  @override
  String get marineLife_speciesDetail_divesLabel => '潜水';

  @override
  String get marineLife_speciesDetail_editTooltip => '编辑物种';

  @override
  String marineLife_speciesDetail_errorPrefix(Object error) {
    return '错误： $error';
  }

  @override
  String get marineLife_speciesDetail_noSightings => '尚无目击记录';

  @override
  String get marineLife_speciesDetail_notFound => '未找到物种';

  @override
  String marineLife_speciesDetail_sightingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次目击',
      one: '次目击',
    );
    return '$count $_temp0';
  }

  @override
  String get marineLife_speciesDetail_sightingPeriodTitle => '目击时期';

  @override
  String get marineLife_speciesDetail_sightingStatsTitle => '目击统计';

  @override
  String get marineLife_speciesDetail_sitesLabel => '潜水点';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return '分类纲：$className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle => '热门潜水点';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel => '总目击次数';

  @override
  String get marineLife_speciesEdit_addTitle => '添加物种';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return '已添加 \"$name\"';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => '返回';

  @override
  String get marineLife_speciesEdit_categoryLabel => '类别';

  @override
  String get marineLife_speciesEdit_commonNameError => '请输入常用名';

  @override
  String get marineLife_speciesEdit_commonNameHint => '例如，公子小丑鱼';

  @override
  String get marineLife_speciesEdit_commonNameLabel => '常用名';

  @override
  String get marineLife_speciesEdit_descriptionHint => '物种的简要描述...';

  @override
  String get marineLife_speciesEdit_descriptionLabel => '描述';

  @override
  String get marineLife_speciesEdit_editTitle => '编辑物种';

  @override
  String marineLife_speciesEdit_errorLoading(Object error) {
    return '加载物种出错：$error';
  }

  @override
  String marineLife_speciesEdit_errorSaving(Object error) {
    return '保存物种出错：$error';
  }

  @override
  String get marineLife_speciesEdit_saveButton => '保存';

  @override
  String get marineLife_speciesEdit_scientificNameHint =>
      '例如 Amphiprion ocellaris';

  @override
  String get marineLife_speciesEdit_scientificNameLabel => '学名';

  @override
  String get marineLife_speciesEdit_taxonomyClassHint => '例如 Actinopterygii';

  @override
  String get marineLife_speciesEdit_taxonomyClassLabel => '分类纲';

  @override
  String marineLife_speciesEdit_updatedSnackbar(Object name) {
    return '已更新\"$name\"';
  }

  @override
  String get marineLife_speciesManage_allFilter => '全部';

  @override
  String get marineLife_speciesManage_appBarTitle => '物种';

  @override
  String get marineLife_speciesManage_backTooltip => '返回';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return '内置物种 ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => '取消';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return '无法删除「$name」——它有目击记录';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip => '清除搜索';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return '自定义物种 ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => '删除';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return '确定要删除 \"$name\"?';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle => '删除物种?';

  @override
  String get marineLife_speciesManage_deleteTooltip => '删除物种';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return '已删除\"$name\"';
  }

  @override
  String get marineLife_speciesManage_editTooltip => '编辑物种';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return '删除物种出错：$error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return '重置物种出错：$error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound => '无物种已找到';

  @override
  String get marineLife_speciesManage_resetButton => '重置';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      '这将把所有内置物种恢复为默认值。自定义物种不受影响。有目击记录的内置物种将被更新但保留。';

  @override
  String get marineLife_speciesManage_resetDialogTitle => '恢复默认设置？';

  @override
  String get marineLife_speciesManage_resetSuccess => '内置物种已恢复为默认值';

  @override
  String get marineLife_speciesManage_resetToDefaults => '恢复默认设置';

  @override
  String get marineLife_speciesManage_searchHint => '搜索物种...';

  @override
  String get marineLife_speciesPicker_allFilter => '全部';

  @override
  String get marineLife_speciesPicker_cancelButton => '取消';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip => '清除搜索';

  @override
  String get marineLife_speciesPicker_closeTooltip => '关闭物种选择器';

  @override
  String get marineLife_speciesPicker_doneButton => '完成';

  @override
  String marineLife_speciesPicker_error(Object error) {
    return '错误： $error';
  }

  @override
  String get marineLife_speciesPicker_noSpeciesFound => '无物种已找到';

  @override
  String get marineLife_speciesPicker_searchHint => '搜索物种...';

  @override
  String marineLife_speciesPicker_selectedCount(Object count) {
    return '$count 已选择';
  }

  @override
  String get marineLife_speciesPicker_title => '选择物种';

  @override
  String get media_diveMediaSection_addTooltip => '添加照片或视频';

  @override
  String get media_diveMediaSection_cancelButton => '取消';

  @override
  String get media_diveMediaSection_cancelSelectionButton => '取消';

  @override
  String get media_diveMediaSection_emptyState => '暂无照片';

  @override
  String get media_diveMediaSection_errorLoading => '加载媒体出错';

  @override
  String get media_diveMediaSection_selectAllButton => '全选';

  @override
  String media_diveMediaSection_selectedCount(int count) {
    return '$count 已选择';
  }

  @override
  String get media_diveMediaSection_thumbnailLabel => '查看照片。长按以选择';

  @override
  String get media_diveMediaSection_title => '照片 & 视频';

  @override
  String get media_diveMediaSection_unlinkButton => '取消关联';

  @override
  String get media_diveMediaSection_unlinkDialogContent =>
      '从此次潜水中移除此照片吗？照片将保留在您的相册中。';

  @override
  String get media_diveMediaSection_unlinkDialogTitle => '取消关联照片';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return '取消关联失败：$error';
  }

  @override
  String media_diveMediaSection_unlinkSelectedButton(int count) {
    return '取消关联 $count';
  }

  @override
  String media_diveMediaSection_unlinkSelectedContent(int count) {
    return '这将从此次潜水中移除 $count 个媒体项目。原始文件不会被删除。';
  }

  @override
  String media_diveMediaSection_unlinkSelectedSuccess(int count) {
    return '已取消关联 $count 个项目';
  }

  @override
  String media_diveMediaSection_unlinkSelectedTitle(int count) {
    return '取消关联 $count 项目?';
  }

  @override
  String get media_diveMediaSection_unlinkSuccess => '照片已取消关联';

  @override
  String get media_diveScan_scanTooltip => '扫描图库为照片';

  @override
  String get media_diveScan_noPhotosFound => '未找到此次潜水附近的新照片';

  @override
  String get media_diveScan_accessDenied => '需要照片库访问权限以扫描照片';

  @override
  String media_diveScan_foundPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '张照片',
      one: '张照片',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '它们',
      one: '它',
    );
    return '找到此次潜水附近的 $count $_temp0。关联$_temp1吗？';
  }

  @override
  String get media_diveScan_foundTitle => '照片已找到';

  @override
  String media_diveScan_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '照片',
      one: '照片',
    );
    return '关联 $_temp0';
  }

  @override
  String get media_diveScan_cancelButton => '取消';

  @override
  String media_diveScan_error(String error) {
    return '扫描相册出错：$error';
  }

  @override
  String get media_gpsBanner_addToSiteButton => '添加到潜水点';

  @override
  String media_gpsBanner_coordinates(Object latitude, Object longitude) {
    return '坐标: $latitude, $longitude';
  }

  @override
  String get media_gpsBanner_createSiteButton => '创建潜水点';

  @override
  String get media_gpsBanner_dismissTooltip => '忽略 GPS 建议';

  @override
  String get media_gpsBanner_title => 'GPS 已找到在照片';

  @override
  String media_import_failedToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'photos',
      one: 'photo',
    );
    return '导入失败 $_temp0';
  }

  @override
  String media_import_failedToImportError(Object error) {
    return '导入照片失败：$error';
  }

  @override
  String media_import_allAlreadyLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张照片已关联到此次潜水',
      one: '1 张照片已关联到此次潜水',
    );
    return '$_temp0';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return '已导入 $imported，失败 $failed';
  }

  @override
  String media_import_importedAndSkipped(int imported, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      imported,
      locale: localeName,
      other: '已导入 $imported 张照片',
      one: '已导入 1 张照片',
    );
    return '$_temp0（$skipped 张已关联）';
  }

  @override
  String media_import_importedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '张照片',
      one: '张照片',
    );
    return '已导入 $count $_temp0';
  }

  @override
  String media_import_importingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '张照片',
      one: '张照片',
    );
    return '正在导入 $count $_temp0...';
  }

  @override
  String get media_miniProfile_headerLabel => '潜水轮廓';

  @override
  String get media_miniProfile_semanticLabel => '迷你潜水轮廓图';

  @override
  String get media_photoPicker_appBarTitle => '选择照片';

  @override
  String get media_photoPicker_clearSelectionButton => '清除';

  @override
  String get media_photoPicker_closeTooltip => '关闭照片选择器';

  @override
  String get media_photoPicker_doneButton => '完成';

  @override
  String media_photoPicker_doneCountButton(Object count) {
    return '完成 ($count)';
  }

  @override
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  ) {
    return '在 $startDate $startTime 到 $endDate $endTime 之间未找到照片。';
  }

  @override
  String get media_photoPicker_emptyTitle => '无照片已找到';

  @override
  String get media_photoPicker_grantAccessButton => '继续';

  @override
  String get media_photoPicker_openSettingsButton => '打开设置';

  @override
  String get media_photoPicker_openSettingsSnackbar => '请打开设置并启用照片访问权限';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      '照片库访问被拒绝。请在设置中启用以添加潜水照片。';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion 需要访问您的照片库以添加潜水照片。';

  @override
  String get media_photoPicker_permissionTitle => '照片访问必填';

  @override
  String get media_photoPicker_selectAllButton => '全选';

  @override
  String media_photoPicker_selectedCount(int count) {
    return '$count 已选择';
  }

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return '显示 $rangeText 的照片';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel => '切换照片选择';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel => '切换照片选择，已选中';

  @override
  String get media_photoPicker_thumbnailAlreadyLinkedLabel => '照片已关联到此次潜水';

  @override
  String get media_photoViewer_cannotShare => '无法分享此照片';

  @override
  String get media_photoViewer_cannotWriteMetadata => '无法写入元数据 - 媒体未关联到图库';

  @override
  String get media_photoViewer_closeTooltip => '关闭照片查看器';

  @override
  String get media_photoViewer_diveDataWrittenToPhoto => '潜水数据已写入照片';

  @override
  String get media_photoViewer_diveDataWrittenToVideo => '潜水数据已写入视频';

  @override
  String media_photoViewer_errorLoadingPhotos(Object error) {
    return '加载照片出错：$error';
  }

  @override
  String get media_photoViewer_failedToLoadImage => '加载图片失败';

  @override
  String get media_photoViewer_failedToLoadVideo => '加载视频失败';

  @override
  String media_photoViewer_failedToShare(Object error) {
    return '分享失败: $error';
  }

  @override
  String get media_photoViewer_failedToWriteMetadata => '写入元数据失败';

  @override
  String media_photoViewer_failedToWriteMetadataError(Object error) {
    return '写入元数据失败：$error';
  }

  @override
  String get media_photoViewer_noPhotosAvailable => '无照片可用';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel => '播放或暂停视频';

  @override
  String get media_photoViewer_seekVideoLabel => '调整视频位置';

  @override
  String get media_photoViewer_shareTooltip => '分享照片';

  @override
  String get media_photoViewer_toggleOverlayLabel => '切换照片叠加层';

  @override
  String get media_photoViewer_videoFileNotFound => '视频文件未找到';

  @override
  String get media_photoViewer_videoNotLinked => '视频未关联到图库';

  @override
  String get media_photoViewer_writeDiveDataTooltip => '写入潜水数据到照片';

  @override
  String get media_quickSiteDialog_cancelButton => '取消';

  @override
  String get media_quickSiteDialog_createButton => '创建潜水点';

  @override
  String get media_quickSiteDialog_description => '使用照片中的 GPS 坐标创建新潜水点。';

  @override
  String get media_quickSiteDialog_siteNameError => '请输入潜水点名称';

  @override
  String get media_quickSiteDialog_siteNameHint => '输入此潜水点的名称';

  @override
  String get media_quickSiteDialog_siteNameLabel => '潜水点名称';

  @override
  String get media_quickSiteDialog_title => '创建潜水点';

  @override
  String get media_scanResults_allPhotosLinked => '所有照片已关联';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return '此旅行的全部 $count 张照片已关联到潜水记录。';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count 张照片已关联';
  }

  @override
  String get media_scanResults_cancelButton => '取消';

  @override
  String media_scanResults_diveNumber(Object number) {
    return '潜水 #$number';
  }

  @override
  String media_scanResults_foundNewPhotos(Object count) {
    return '已找到 $count 新照片';
  }

  @override
  String get media_scanResults_linkButton => '关联';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return '关联 $count 照片';
  }

  @override
  String get media_scanResults_noPhotosFound => '无照片已找到';

  @override
  String get media_scanResults_okButton => '确定';

  @override
  String get media_scanResults_unknownSite => '未知潜水点';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return '$count 张照片无法匹配到任何潜水记录（拍摄时间在潜水时间之外）';
  }

  @override
  String get media_unavailablePlaceholder_notOnDevice => '不在此设备上';

  @override
  String get media_writeMetadata_cancelButton => '取消';

  @override
  String get media_writeMetadata_depthLabel => '深度';

  @override
  String get media_writeMetadata_descriptionPhoto => '以下元数据将写入照片：';

  @override
  String get media_writeMetadata_descriptionVideo => '以下元数据将写入视频：';

  @override
  String get media_writeMetadata_diveTimeLabel => '潜水时间';

  @override
  String get media_writeMetadata_gpsLabel => 'GPS';

  @override
  String get media_writeMetadata_keepOriginalVideo => '保留原始视频';

  @override
  String get media_writeMetadata_noDataAvailable => '没有可写入的潜水数据。';

  @override
  String get media_writeMetadata_siteLabel => '潜水点';

  @override
  String get media_writeMetadata_temperatureLabel => '温度';

  @override
  String get media_writeMetadata_titlePhoto => '写入潜水数据到照片';

  @override
  String get media_writeMetadata_titleVideo => '写入潜水数据到视频';

  @override
  String get media_writeMetadata_warningPhotoText => '这将修改原始照片。';

  @override
  String get media_writeMetadata_warningVideoText =>
      '将创建包含元数据的新视频。视频元数据无法就地修改。';

  @override
  String get media_writeMetadata_writeButton => '写入';

  @override
  String get nav_buddies => '潜伴';

  @override
  String get nav_certifications => '证书';

  @override
  String get nav_courses => '课程';

  @override
  String get nav_coursesSubtitle => '培训与教育';

  @override
  String get nav_diveCenters => '潜水中心';

  @override
  String get nav_dives => '潜水';

  @override
  String get nav_equipment => '装备';

  @override
  String get nav_home => '首页';

  @override
  String get nav_more => '更多';

  @override
  String get nav_planning => '计划';

  @override
  String get nav_planningSubtitle => '潜水计划、计算器';

  @override
  String get nav_settings => '设置';

  @override
  String get nav_sites => '潜水点';

  @override
  String get nav_statistics => '统计';

  @override
  String get nav_tooltip_closeMenu => '关闭菜单';

  @override
  String get nav_tooltip_collapseMenu => '折叠菜单';

  @override
  String get nav_tooltip_expandMenu => '展开菜单';

  @override
  String get nav_transfer => '传输';

  @override
  String get nav_trips => '旅行';

  @override
  String get onboarding_welcome_createProfile => '创建您的档案';

  @override
  String get onboarding_welcome_createProfileSubtitle =>
      '输入您的名字以开始使用。稍后可以添加更多详细信息。';

  @override
  String get onboarding_welcome_creating => '正在创建...';

  @override
  String onboarding_welcome_errorCreatingProfile(Object error) {
    return '创建档案时出错：$error';
  }

  @override
  String get onboarding_welcome_getStarted => '开始使用';

  @override
  String get onboarding_welcome_nameHint => '输入您的名字';

  @override
  String get onboarding_welcome_nameLabel => '您的名字';

  @override
  String get onboarding_welcome_nameValidation => '请输入您的名字';

  @override
  String get onboarding_welcome_subtitle => '高级潜水日志与分析';

  @override
  String get onboarding_welcome_title => '欢迎使用 Submersion';

  @override
  String get planning_appBar_title => '计划';

  @override
  String get planning_card_decoCalculator_description =>
      '计算免减压极限、所需减压停留以及多层潜水轮廓的中枢神经系统毒性/氧毒性单位暴露量。';

  @override
  String get planning_card_decoCalculator_subtitle => '规划需要减压停留的潜水';

  @override
  String get planning_card_decoCalculator_title => '减压计算器';

  @override
  String get planning_card_divePlanner_description =>
      '规划多深度层次的复杂潜水，包括气体切换和自动减压停留计算。';

  @override
  String get planning_card_divePlanner_subtitle => '创建多层潜水计划';

  @override
  String get planning_card_divePlanner_title => '潜水计划器';

  @override
  String get planning_card_gasCalculators_description =>
      '四种专用气体计算器：• 最大作业深度 - 气体混合物的最大作业深度 • 最佳混合气 - 目标深度的理想氧气百分比 • 耗气量 - 气体使用量估算 • 底限储备 - 紧急储备计算';

  @override
  String get planning_card_gasCalculators_subtitle => '最大作业深度、最佳混合气、耗气量、底限储备';

  @override
  String get planning_card_gasCalculators_title => '气体计算器';

  @override
  String get planning_card_surfaceInterval_description =>
      '根据组织负荷计算两次潜水之间所需的最短水面间隔。可视化您的16个组织隔间随时间的排气过程。';

  @override
  String get planning_card_surfaceInterval_subtitle => '规划重复潜水间隔';

  @override
  String get planning_card_surfaceInterval_title => '水面间隔';

  @override
  String get planning_card_weightCalculator_description =>
      '根据您的防寒服、气瓶材质、水型和体重估算所需配重。';

  @override
  String get planning_card_weightCalculator_subtitle => '适合您装备配置的推荐配重';

  @override
  String get planning_card_weightCalculator_title => '配重计算器';

  @override
  String get planning_info_disclaimer => '这些工具仅供计划参考。请务必验证计算结果并遵循您的潜水训练。';

  @override
  String get planning_sidebar_appBar_title => '计划';

  @override
  String get planning_sidebar_decoCalculator_subtitle => 'NDL & 减压停留';

  @override
  String get planning_sidebar_decoCalculator_title => '减压计算器';

  @override
  String get planning_sidebar_divePlanner_subtitle => '多层潜水计划';

  @override
  String get planning_sidebar_divePlanner_title => '潜水计划器';

  @override
  String get planning_sidebar_gasCalculators_subtitle => '最大作业深度、最佳混合气等';

  @override
  String get planning_sidebar_gasCalculators_title => '气体计算器';

  @override
  String get planning_sidebar_info_disclaimer => '规划工具仅供参考。请务必验证计算结果。';

  @override
  String get planning_sidebar_surfaceInterval_subtitle => '重复潜水规划';

  @override
  String get planning_sidebar_surfaceInterval_title => '水面间隔';

  @override
  String get planning_sidebar_weightCalculator_subtitle => '推荐配重';

  @override
  String get planning_sidebar_weightCalculator_title => '配重计算器';

  @override
  String get planning_welcome_quickTips_title => '快速提示';

  @override
  String get planning_welcome_subtitle => '从侧边栏选择一个工具开始';

  @override
  String get planning_welcome_tip_decoCalculator => '减压计算器用于计算免减压极限和停留时间';

  @override
  String get planning_welcome_tip_divePlanner => '潜水计划器用于多层潜水规划';

  @override
  String get planning_welcome_tip_gasCalculators => '气体计算器用于最大作业深度和气体规划';

  @override
  String get planning_welcome_tip_weightCalculator => '配重计算器用于浮力配置';

  @override
  String get planning_welcome_title => '规划工具';

  @override
  String get settings_about_aboutSubmersion => '关于 Submersion';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description => '深入探索。';

  @override
  String get settings_about_header => '关于';

  @override
  String get settings_about_openSourceLicenses => '开源许可证';

  @override
  String get settings_about_reportIssue => '报告问题';

  @override
  String get settings_about_reportIssue_snackbar =>
      '请访问 github.com/submersion-app/submersion/issues';

  @override
  String settings_about_version(String version) {
    return '版本 $version';
  }

  @override
  String get settings_appBar_title => '设置';

  @override
  String get settings_appearance_appLanguage => '应用语言';

  @override
  String get settings_appearance_depthColoredCards => '按深度着色的潜水卡片';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      '根据深度显示海洋色调背景的潜水卡片';

  @override
  String get settings_appearance_cardColorAttribute => '卡片颜色依据';

  @override
  String get settings_appearance_cardColorAttribute_subtitle => '选择决定卡片背景颜色的属性';

  @override
  String get settings_appearance_cardColorAttribute_none => '无';

  @override
  String get settings_appearance_cardColorAttribute_depth => '深度';

  @override
  String get settings_appearance_cardColorAttribute_duration => '时长';

  @override
  String get settings_appearance_cardColorAttribute_temperature => '温度';

  @override
  String get settings_appearance_colorGradient => '颜色渐变';

  @override
  String get settings_appearance_colorGradient_subtitle => '选择卡片背景的颜色范围';

  @override
  String get settings_appearance_colorGradient_ocean => '海洋';

  @override
  String get settings_appearance_colorGradient_thermal => '热力';

  @override
  String get settings_appearance_colorGradient_sunset => '日落';

  @override
  String get settings_appearance_colorGradient_forest => '森林';

  @override
  String get settings_appearance_colorGradient_monochrome => '单色';

  @override
  String get settings_appearance_colorGradient_custom => '自定义';

  @override
  String get settings_appearance_gasSwitchMarkers => '气体切换标记';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle => '显示气体切换标记';

  @override
  String get settings_appearance_header_diveDetails => '潜水详情';

  @override
  String get settings_appearance_header_diveLog => '潜水日志';

  @override
  String get settings_appearance_header_diveProfile => '潜水轮廓';

  @override
  String get settings_appearance_header_diveSites => '潜水点';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility =>
      '区块顺序与可见性';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility_subtitle =>
      '选择显示哪些区块及其顺序';

  @override
  String get settings_diveDetailSections_title => '区块顺序与可见性';

  @override
  String get settings_diveDetailSections_resetToDefault => '恢复默认';

  @override
  String get settings_diveDetailSections_fixedSections => '固定区块：头部信息、潜水轮廓图';

  @override
  String get settings_diveDetailSections_configurableSections =>
      '可配置区块（拖动以重新排序）';

  @override
  String get diveDetailSection_decoO2_name => '减压状态 / 组织负荷';

  @override
  String get diveDetailSection_decoO2_description => '免减压极限、上限深度、组织热力图、氧气毒性';

  @override
  String get diveDetailSection_sacSegments_name => '分段耗气率';

  @override
  String get diveDetailSection_sacSegments_description => '阶段/时间分段、气瓶分解';

  @override
  String get diveDetailSection_details_name => '详情';

  @override
  String get diveDetailSection_details_description => '类型、位置、旅行、潜水中心、水面间隔';

  @override
  String get diveDetailSection_environment_name => '环境';

  @override
  String get diveDetailSection_environment_description => '气温/水温、能见度、水流';

  @override
  String get diveDetailSection_altitude_name => '高海拔';

  @override
  String get diveDetailSection_altitude_description => '海拔值、类别、减压要求';

  @override
  String get diveDetailSection_tide_name => '潮汐';

  @override
  String get diveDetailSection_tide_description => '潮汐周期图和时间';

  @override
  String get diveDetailSection_weights_name => '重量';

  @override
  String get diveDetailSection_weights_description => '配重明细、总重量';

  @override
  String get diveDetailSection_tanks_name => '气瓶';

  @override
  String get diveDetailSection_tanks_description => '气瓶列表、气体混合、压力、单瓶耗气率';

  @override
  String get diveDetailSection_buddies_name => '潜伴';

  @override
  String get diveDetailSection_buddies_description => '潜伴列表及角色';

  @override
  String get diveDetailSection_signatures_name => '签名';

  @override
  String get diveDetailSection_signatures_description => '潜伴/教练签名显示和采集';

  @override
  String get diveDetailSection_equipment_name => '装备';

  @override
  String get diveDetailSection_equipment_description => '潜水中使用的装备';

  @override
  String get diveDetailSection_sightings_name => '海洋生物目击';

  @override
  String get diveDetailSection_sightings_description => '观察到的物种、目击详情';

  @override
  String get diveDetailSection_media_name => '媒体';

  @override
  String get diveDetailSection_media_description => '照片/视频画廊';

  @override
  String get diveDetailSection_tags_name => '标签';

  @override
  String get diveDetailSection_tags_description => '潜水标签';

  @override
  String get diveDetailSection_notes_name => '备注';

  @override
  String get diveDetailSection_notes_description => '潜水备注/描述';

  @override
  String get diveDetailSection_customFields_name => '自定义字段';

  @override
  String get diveDetailSection_customFields_description => '用户自定义字段';

  @override
  String get diveDetailSection_dataSources_name => '数据来源';

  @override
  String get diveDetailSection_dataSources_description => '已连接的潜水电脑、数据源管理';

  @override
  String get settings_appearance_header_language => '语言';

  @override
  String get settings_appearance_header_theme => '颜色主题';

  @override
  String get settings_appearance_header_mode => '模式';

  @override
  String get settings_themes_title => '选择主题';

  @override
  String get settings_themes_current => '颜色主题';

  @override
  String get theme_submersion => 'Submersion';

  @override
  String get theme_console => '控制台';

  @override
  String get theme_tropical => '热带';

  @override
  String get theme_minimalist => '极简';

  @override
  String get theme_deep => '深潜';

  @override
  String get settings_appearance_mapBackgroundDiveCards => '潜水卡片地图背景';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitle =>
      '在潜水卡片上显示潜水点地图作为背景';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote =>
      '在潜水卡片上显示潜水点地图作为背景（需要潜水点位置信息）';

  @override
  String get settings_appearance_mapBackgroundSiteCards => '潜水点卡片地图背景';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitle =>
      '在潜水点卡片上显示地图作为背景';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote =>
      '在潜水点卡片上显示地图作为背景（需要潜水点位置信息）';

  @override
  String get settings_appearance_maxDepthMarker => '最大深度标记';

  @override
  String get settings_appearance_maxDepthMarker_subtitle => '在最大深度点显示标记';

  @override
  String get settings_appearance_maxDepthMarker_subtitleFull =>
      '在潜水轮廓上最大深度点显示标记';

  @override
  String get settings_appearance_metric_ascentRateColors => '上升速率颜色';

  @override
  String get settings_appearance_metric_ceiling => '上升限制';

  @override
  String get settings_appearance_metric_events => '事件';

  @override
  String get settings_appearance_metric_gasDensity => '气体密度';

  @override
  String get settings_appearance_metric_gfPercent => '梯度因子%';

  @override
  String get settings_appearance_metric_heartRate => '心率';

  @override
  String get settings_appearance_metric_meanDepth => '平均深度';

  @override
  String get settings_appearance_metric_ndl => 'NDL';

  @override
  String get settings_appearance_metric_ppHe => '氦分压';

  @override
  String get settings_appearance_metric_ppN2 => '氮分压';

  @override
  String get settings_appearance_metric_ppO2 => '氧分压';

  @override
  String get settings_appearance_metric_pressure => '压力';

  @override
  String get settings_appearance_metric_sacRate => '气体消耗率';

  @override
  String get settings_appearance_metric_surfaceGf => '水面梯度因子';

  @override
  String get settings_appearance_metric_temperature => '温度';

  @override
  String get settings_appearance_metric_tts => '到达水面时间';

  @override
  String get settings_appearance_metric_cns => '中枢神经系统% (O2 毒性)';

  @override
  String get settings_appearance_metric_otu => 'OTU (O2 耐受单位)';

  @override
  String settings_appearance_metricsEnabledCount(int count, int total) {
    return '已启用 $count/$total';
  }

  @override
  String get settings_appearance_pressureThresholdMarkers => '压力阈值标记';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      '当气瓶压力超过阈值时显示标记';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      '当气瓶压力超过 2/3、1/2 和 1/3 阈值时显示标记';

  @override
  String get settings_appearance_rightYAxisMetric => '右Y轴指标';

  @override
  String get settings_appearance_rightYAxisMetric_subtitle => '右轴默认显示的指标';

  @override
  String get settings_appearance_subsection_decompressionMetrics => '减压指标';

  @override
  String get settings_appearance_subsection_defaultVisibleMetrics => '默认可见指标';

  @override
  String get settings_appearance_subsection_standardMetrics => '标准指标';

  @override
  String get settings_appearance_subsection_gasAnalysisMetrics => '气体分析指标';

  @override
  String get settings_appearance_subsection_gradientFactorMetrics => '梯度因子指标';

  @override
  String get settings_appearance_theme_dark => '深色';

  @override
  String get settings_appearance_theme_light => '轻微';

  @override
  String get settings_appearance_theme_system => '系统默认';

  @override
  String get settings_backToSettings_tooltip => '返回设置';

  @override
  String get settings_cloudSync_appBar_title => '云同步';

  @override
  String get settings_cloudSync_autoSync => '自动同步';

  @override
  String get settings_cloudSync_autoSync_subtitle => '更改后自动同步';

  @override
  String settings_cloudSync_conflictItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个项目需要处理',
      one: '1 个项目需要处理',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_disabledBanner_content =>
      '由于您正在使用自定义存储文件夹，应用管理的云同步已禁用。您文件夹的同步服务（Dropbox、Google Drive、OneDrive 等）将负责同步。';

  @override
  String get settings_cloudSync_disabledBanner_title => '云同步已禁用';

  @override
  String get settings_cloudSync_header_advanced => '高级';

  @override
  String get settings_cloudSync_header_cloudProvider => '云服务提供商';

  @override
  String settings_cloudSync_header_conflicts(Object count) {
    return '冲突 ($count)';
  }

  @override
  String get settings_cloudSync_header_syncBehavior => '同步行为';

  @override
  String settings_cloudSync_lastSynced(Object time) {
    return '上次同步：$time';
  }

  @override
  String settings_cloudSync_pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个待同步更改',
      one: '1 个待同步更改',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_provider_connected => '已连接';

  @override
  String settings_cloudSync_provider_connectedTo(Object providerName) {
    return '已连接到 $providerName';
  }

  @override
  String settings_cloudSync_provider_connectionFailed(
    Object providerName,
    Object error,
  ) {
    return '$providerName 连接失败：$error';
  }

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      '通过 Google Drive 同步';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      '通过 Apple iCloud 同步';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return '无法初始化 $providerName 提供商';
  }

  @override
  String get settings_cloudSync_provider_notAvailable => '在此平台上不可用';

  @override
  String get settings_cloudSync_resetDialog_cancel => '取消';

  @override
  String get settings_cloudSync_resetDialog_content =>
      '这将清除所有同步历史记录并重新开始。您的数据不会被删除，但下次同步时可能需要解决冲突。';

  @override
  String get settings_cloudSync_resetDialog_reset => '重置';

  @override
  String get settings_cloudSync_resetDialog_title => '重置同步状态？';

  @override
  String get settings_cloudSync_resetSuccess => '同步状态重置';

  @override
  String get settings_cloudSync_resetSyncState => '重置同步状态';

  @override
  String get settings_cloudSync_resetSyncState_subtitle => '清除同步历史记录并重新开始';

  @override
  String get settings_cloudSync_resolveConflicts => '解决冲突';

  @override
  String get settings_cloudSync_selectProviderHint => '选择一个云服务提供商以启用同步';

  @override
  String get settings_cloudSync_signOut => '签名出';

  @override
  String get settings_cloudSync_signOutDialog_cancel => '取消';

  @override
  String get settings_cloudSync_signOutDialog_content =>
      '这将断开与云服务提供商的连接。您的本地数据将保持不变。';

  @override
  String get settings_cloudSync_signOutDialog_signOut => '签名出';

  @override
  String get settings_cloudSync_signOutDialog_title => '签名出?';

  @override
  String get settings_cloudSync_signOutSuccess => '已退出云服务提供商';

  @override
  String get settings_cloudSync_signOut_subtitle => '断开与云服务提供商的连接';

  @override
  String get settings_cloudSync_status_conflictsDetected => '检测到冲突';

  @override
  String get settings_cloudSync_status_readyToSync => '准备就绪到同步';

  @override
  String get settings_cloudSync_status_syncComplete => '同步完成';

  @override
  String get settings_cloudSync_status_syncError => '同步错误';

  @override
  String get settings_cloudSync_status_syncing => '同步中...';

  @override
  String get settings_cloudSync_storageSettings => '存储设置';

  @override
  String get settings_cloudSync_syncNow => '立即同步';

  @override
  String get settings_cloudSync_syncOnLaunch => '启动时同步';

  @override
  String get settings_cloudSync_syncOnLaunch_subtitle => '启动时检查更新';

  @override
  String get settings_cloudSync_syncOnResume => '恢复时同步';

  @override
  String get settings_cloudSync_syncOnResume_subtitle => '应用变为活跃状态时检查更新';

  @override
  String settings_cloudSync_syncProgressPercent(Object percent) {
    return '同步进度: $percent 百分比';
  }

  @override
  String settings_cloudSync_time_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
      one: '1 天前',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_time_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前',
      one: '1 小时前',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_time_justNow => '刚刚';

  @override
  String settings_cloudSync_time_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前',
      one: '1 分钟前',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_applyAll => '全部应用';

  @override
  String get settings_conflict_cancel => '取消';

  @override
  String get settings_conflict_chooseResolution => '选择解决方案';

  @override
  String get settings_conflict_close => '关闭';

  @override
  String get settings_conflict_close_tooltip => '关闭冲突对话框';

  @override
  String settings_conflict_counterLabel(Object current, Object total) {
    return '冲突 $current/$total';
  }

  @override
  String settings_conflict_errorLoading(Object error) {
    return '加载冲突时出错：$error';
  }

  @override
  String get settings_conflict_keepBoth => '保留两者';

  @override
  String get settings_conflict_keepLocal => '保留本地';

  @override
  String get settings_conflict_keepRemote => '保留远程';

  @override
  String get settings_conflict_localVersion => '本地版本';

  @override
  String settings_conflict_modified(Object time) {
    return '已修改: $time';
  }

  @override
  String get settings_conflict_next_tooltip => '下一步冲突';

  @override
  String get settings_conflict_noConflicts_message => '所有同步冲突已解决。';

  @override
  String get settings_conflict_noConflicts_title => '无冲突';

  @override
  String get settings_conflict_noDataAvailable => '无可用数据';

  @override
  String get settings_conflict_previous_tooltip => '上一个冲突';

  @override
  String get settings_conflict_remoteVersion => '远程版本';

  @override
  String settings_conflict_resolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个冲突',
      one: '1 个冲突',
    );
    return '已解决 $_temp0';
  }

  @override
  String get settings_conflict_title => '解决冲突';

  @override
  String get settings_data_appDefaultLocation => '应用默认位置';

  @override
  String get settings_data_backup => '备份与恢复';

  @override
  String get settings_data_backup_subtitle => '创建数据备份';

  @override
  String get settings_data_cloudSync => '云同步';

  @override
  String get settings_data_customFolder => '自定义文件夹';

  @override
  String get settings_data_databaseStorage => '数据库存储';

  @override
  String get settings_data_export_completed => '导出完成';

  @override
  String get settings_data_export_exporting => '正在导出...';

  @override
  String settings_data_export_failed(Object error) {
    return '导出失败：$error';
  }

  @override
  String get settings_data_header_backupSync => '备份与同步';

  @override
  String get settings_data_header_storage => '存储';

  @override
  String get settings_data_import_completed => '操作完成';

  @override
  String settings_data_import_failed(Object error) {
    return '操作失败：$error';
  }

  @override
  String get settings_data_offlineMaps => '离线地图';

  @override
  String get settings_data_offlineMaps_subtitle => '下载地图以供离线使用';

  @override
  String get settings_data_restore => '恢复';

  @override
  String get settings_data_restoreDialog_cancel => '取消';

  @override
  String get settings_data_restoreDialog_content =>
      '警告：从备份恢复将用备份数据替换所有当前数据。此操作无法撤销。确定要继续吗？';

  @override
  String get settings_data_restoreDialog_restore => '恢复';

  @override
  String get settings_data_restoreDialog_title => '恢复备份';

  @override
  String get settings_data_restore_subtitle => '从备份恢复';

  @override
  String settings_data_syncTime_daysAgo(Object count) {
    return '${count}d 前';
  }

  @override
  String settings_data_syncTime_hoursAgo(Object count) {
    return '${count}h 前';
  }

  @override
  String get settings_data_syncTime_justNow => '刚刚';

  @override
  String settings_data_syncTime_minutesAgo(Object count) {
    return '${count}m 前';
  }

  @override
  String settings_data_sync_lastSynced(Object time) {
    return '上次同步：$time';
  }

  @override
  String get settings_data_sync_notConfigured => '未配置';

  @override
  String get settings_data_sync_syncing => '同步中...';

  @override
  String get settings_decompression_aboutContent =>
      '梯度因子（GF）控制减压计算的保守程度。GF Low 影响深停留，而 GF High 影响浅停留。数值越低 = 越保守 = 更长的减压停留；数值越高 = 越不保守 = 更短的减压停留';

  @override
  String get settings_decompression_aboutTitle => '关于梯度因子';

  @override
  String get settings_decompression_currentSettings => '当前设置';

  @override
  String get settings_decompression_dialog_cancel => '取消';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      '数值越低 = 越保守（更长的免减压极限/更多减压停留）';

  @override
  String get settings_decompression_dialog_customValues => '自定义值';

  @override
  String get settings_decompression_dialog_gfHigh => '梯度因子高值';

  @override
  String get settings_decompression_dialog_gfLow => '梯度因子低值';

  @override
  String get settings_decompression_dialog_info =>
      'GF Low/High 控制免减压极限和减压计算的保守程度。';

  @override
  String get settings_decompression_dialog_presets => '预设';

  @override
  String get settings_decompression_dialog_save => '保存';

  @override
  String get settings_decompression_dialog_title => '梯度因子';

  @override
  String settings_decompression_gfValue(Object gfLow, Object gfHigh) {
    return 'GF $gfLow/$gfHigh';
  }

  @override
  String get settings_decompression_header_gradientFactors => '梯度因子';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return '选择 $presetName 保守程度预设';
  }

  @override
  String get settings_decompression_header_narcosis => '麻醉';

  @override
  String get settings_decompression_o2Narcotic => 'O2 有麻醉性';

  @override
  String get settings_decompression_o2Narcotic_subtitle =>
      '启用后，氧气和氮气均被视为具有麻醉性（更保守）。禁用后，仅氮气导致麻醉。';

  @override
  String get settings_decompression_endLimit => 'END 限制';

  @override
  String get settings_decompression_endLimit_subtitle => '用于最大麻醉深度计算的最大等效麻醉深度';

  @override
  String get settings_decompression_endLimit_dialog_title => 'END 限制';

  @override
  String get settings_existingDb_cancel => '取消';

  @override
  String get settings_existingDb_continue => '继续';

  @override
  String get settings_existingDb_current => '当前';

  @override
  String get settings_existingDb_dialog_message => '此文件夹中已存在 Submersion 数据库。';

  @override
  String get settings_existingDb_dialog_title => '现有数据库已找到';

  @override
  String get settings_existingDb_existing => '现有';

  @override
  String get settings_existingDb_replaceWarning => '现有数据库将在替换前进行备份。';

  @override
  String get settings_existingDb_replaceWithMyData => '替换与我的数据';

  @override
  String get settings_existingDb_replaceWithMyData_subtitle => '用您当前的数据库覆盖';

  @override
  String get settings_existingDb_stat_buddies => '潜伴';

  @override
  String get settings_existingDb_stat_dives => '潜水';

  @override
  String get settings_existingDb_stat_sites => '潜水点';

  @override
  String get settings_existingDb_stat_trips => '旅行';

  @override
  String get settings_existingDb_stat_users => '用户';

  @override
  String get settings_existingDb_unknown => '未知';

  @override
  String get settings_existingDb_useExisting => '使用现有数据库';

  @override
  String get settings_existingDb_useExisting_subtitle => '切换到此文件夹中的数据库';

  @override
  String get settings_gfPreset_custom_description => '设置您自己的数值';

  @override
  String get settings_gfPreset_custom_name => '自定义';

  @override
  String get settings_gfPreset_high_description => '最保守，更长的减压停留';

  @override
  String get settings_gfPreset_high_name => '高';

  @override
  String get settings_gfPreset_low_description => '最不保守，更短的减压停留';

  @override
  String get settings_gfPreset_low_name => '低';

  @override
  String get settings_gfPreset_medium_description => '平衡方案';

  @override
  String get settings_gfPreset_medium_name => '中等';

  @override
  String get settings_import_dialog_title => '正在导入数据';

  @override
  String get settings_import_doNotClose => '请不要关闭应用';

  @override
  String settings_import_itemCount(Object current, Object total) {
    return '$current/$total';
  }

  @override
  String get settings_import_phase_buddies => '正在导入潜伴...';

  @override
  String get settings_import_phase_certifications => '正在导入证书...';

  @override
  String get settings_import_phase_complete => '正在完成...';

  @override
  String get settings_import_phase_diveCenters => '正在导入潜水中心...';

  @override
  String get settings_import_phase_diveTypes => '正在导入潜水类型...';

  @override
  String get settings_import_phase_dives => '正在导入潜水...';

  @override
  String get settings_import_phase_equipment => '正在导入装备...';

  @override
  String get settings_import_phase_equipmentSets => '正在导入装备套装...';

  @override
  String get settings_import_phase_parsing => '正在解析文件...';

  @override
  String get settings_import_phase_preparing => '准备中...';

  @override
  String get settings_import_phase_sites => '正在导入潜水点...';

  @override
  String get settings_import_phase_tags => '正在导入标签...';

  @override
  String get settings_import_phase_trips => '正在导入旅行...';

  @override
  String get settings_import_phase_courses => '正在导入课程...';

  @override
  String get settings_import_phase_applyingTags => '正在应用标签...';

  @override
  String settings_import_progressLabel(
    Object phase,
    Object current,
    Object total,
  ) {
    return '$phase，$current/$total';
  }

  @override
  String settings_import_progressPercent(Object percent) {
    return '导入进度：$percent%';
  }

  @override
  String get settings_language_appBar_title => '语言';

  @override
  String get settings_language_selected => '已选择';

  @override
  String get settings_language_systemDefault => '系统默认';

  @override
  String get settings_manage_diveTypes => '潜水类型';

  @override
  String get settings_manage_diveTypes_subtitle => '管理自定义潜水类型';

  @override
  String get settings_manage_header_manageData => '管理数据';

  @override
  String get settings_manage_species => '物种';

  @override
  String get settings_manage_species_subtitle => '管理海洋生物物种目录';

  @override
  String get settings_manage_tags => '标签';

  @override
  String get settings_manage_tags_subtitle => '管理、合并和删除标签';

  @override
  String get settings_manage_tankPresets => '气瓶预设';

  @override
  String get settings_manage_tankPresets_subtitle => '管理自定义气瓶配置';

  @override
  String get settings_migrationProgress_doNotClose => '请不要关闭应用';

  @override
  String get settings_migration_backupInfo => '迁移前将创建备份。您的数据不会丢失。';

  @override
  String get settings_migration_cancel => '取消';

  @override
  String get settings_migration_cloudSyncWarning =>
      '应用管理的云同步将被禁用。您文件夹的同步服务将负责同步。';

  @override
  String get settings_migration_dialog_message => '您的数据库将被迁移：';

  @override
  String get settings_migration_dialog_title => '移动数据库?';

  @override
  String get settings_migration_from => '从';

  @override
  String get settings_migration_moveDatabase => '移动数据库';

  @override
  String get settings_migration_to => '到';

  @override
  String settings_notifications_days(Object count) {
    return '$count 天';
  }

  @override
  String get settings_notifications_disabled_enableButton => '启用';

  @override
  String get settings_notifications_disabled_subtitle => '在系统设置中启用以接收提醒';

  @override
  String get settings_notifications_disabled_title => '通知已禁用';

  @override
  String get settings_notifications_enableServiceReminders => '启用维护提醒';

  @override
  String get settings_notifications_enableServiceReminders_subtitle =>
      '当装备需要维护时获得通知';

  @override
  String get settings_notifications_header_reminderSchedule => '提醒计划';

  @override
  String get settings_notifications_header_serviceReminders => '维护提醒';

  @override
  String get settings_notifications_howItWorks_content =>
      '通知在应用启动时计划，并在后台定期刷新。您可以在每件装备的编辑界面中自定义提醒。';

  @override
  String get settings_notifications_howItWorks_title => '工作原理';

  @override
  String get settings_notifications_permissionRequired => '请在系统设置中启用通知';

  @override
  String get settings_notifications_remindBeforeDue => '在维护到期前提醒我：';

  @override
  String get settings_notifications_reminderTime => '提醒时间';

  @override
  String get settings_profile_activeDiver_subtitle => '当前活跃潜水员 - 点击切换';

  @override
  String get settings_profile_addNewDiver => '添加新潜水员';

  @override
  String get settings_profile_error_loadingDiver => '加载潜水员时出错';

  @override
  String get settings_profile_header_activeDiver => '当前潜水员';

  @override
  String get settings_profile_header_manageDivers => '管理潜水员';

  @override
  String get settings_profile_noDiverProfile => '无潜水员档案';

  @override
  String get settings_profile_noDiverProfile_subtitle => '点击创建您的档案';

  @override
  String get settings_profile_switchDiver_title => '切换潜水员';

  @override
  String settings_profile_switchedTo(Object diverName) {
    return '已切换到 $diverName';
  }

  @override
  String get settings_profile_viewAllDivers => '查看所有潜水员';

  @override
  String get settings_profile_viewAllDivers_subtitle => '添加或编辑潜水员档案';

  @override
  String get settings_profileHub_addNewDiver => '添加新潜水员';

  @override
  String get settings_profileHub_cannotDeleteOnly => '无法删除唯一的潜水员档案';

  @override
  String get settings_profileHub_createDiverTitle => '创建潜水员';

  @override
  String settings_profileHub_deleteConfirmContent(String name) {
    return '确定要删除 $name 吗？所有关联的潜水日志将被取消关联。';
  }

  @override
  String get settings_profileHub_deleteConfirmTitle => '删除潜水员？';

  @override
  String get settings_profileHub_deleteDiver => '删除潜水员';

  @override
  String get settings_profileHub_deleted => '潜水员已删除';

  @override
  String get settings_profileHub_emergencyContacts => '紧急联系人';

  @override
  String settings_profileHub_emergencyContacts_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已设置 $count 位联系人',
      one: '已设置 1 位联系人',
      zero: '未设置',
    );
    return '$_temp0';
  }

  @override
  String get settings_profileHub_insurance => '保险';

  @override
  String get settings_profileHub_insurance_expired => '已过期';

  @override
  String get settings_profileHub_insurance_notSet => '未设置';

  @override
  String get settings_profileHub_medicalInfo => '医疗信息';

  @override
  String get settings_profileHub_medicalInfo_notSet => '未设置';

  @override
  String get settings_profileHub_notes => '备注';

  @override
  String get settings_profileHub_notes_notSet => '未设置';

  @override
  String get settings_profileHub_personalInfo => '个人信息';

  @override
  String get settings_profileHub_personalInfo_notSet => '未设置';

  @override
  String get settings_profileHub_saved => '更改已保存';

  @override
  String get settings_profileHub_switchDiver => '切换潜水员';

  @override
  String get settings_section_about_subtitle => '应用信息与许可证';

  @override
  String get settings_section_about_title => '关于';

  @override
  String get settings_section_appearance_subtitle => '主题 & 显示';

  @override
  String get settings_section_appearance_title => '外观';

  @override
  String get settings_section_data_subtitle => '备份、恢复与存储';

  @override
  String get settings_section_data_title => '数据';

  @override
  String get settings_section_decompression_subtitle => '梯度因子、数据来源与麻醉';

  @override
  String get settings_section_decompression_title => '减压';

  @override
  String get settings_section_diverProfile_subtitle => '当前潜水员与档案';

  @override
  String get settings_section_diverProfile_title => '潜水员档案';

  @override
  String get settings_section_manage_subtitle => '潜水类型与气瓶预设';

  @override
  String get settings_section_manage_title => '管理';

  @override
  String get settings_section_notifications_subtitle => '维护提醒';

  @override
  String get settings_section_notifications_title => '通知';

  @override
  String get settings_section_units_subtitle => '计量单位偏好';

  @override
  String get settings_section_units_title => '单位';

  @override
  String get settings_storage_appBar_title => '数据库存储';

  @override
  String get settings_storage_appDefault => '应用默认';

  @override
  String get settings_storage_appDefaultLocation => '应用默认位置';

  @override
  String get settings_storage_appDefault_subtitle => '标准应用存储位置';

  @override
  String get settings_storage_currentLocation => '当前存储位置';

  @override
  String get settings_storage_currentLocation_label => '当前位置';

  @override
  String get settings_storage_customFolder => '自定义文件夹';

  @override
  String get settings_storage_customFolder_change => '更改';

  @override
  String get settings_storage_customFolder_subtitle =>
      '选择同步文件夹（Dropbox、Google Drive 等）';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize • $diveCount 次潜水 • $siteCount 个潜水点';
  }

  @override
  String get settings_storage_dismissError_tooltip => '关闭错误提示';

  @override
  String get settings_storage_dismissSuccess_tooltip => '关闭成功消息';

  @override
  String get settings_storage_header_storageLocation => '存储位置';

  @override
  String get settings_storage_info_customActive =>
      '应用管理的云同步已禁用。您文件夹的同步服务（Dropbox、Google Drive 等）将负责同步。';

  @override
  String get settings_storage_info_customAvailable =>
      '使用自定义文件夹将禁用应用管理的云同步。您文件夹的同步服务将代替进行同步。';

  @override
  String get settings_storage_loading => '加载中...';

  @override
  String get settings_storage_migrating_doNotClose => '请不要关闭应用';

  @override
  String get settings_storage_migrating_movingDatabase => '移动中数据库...';

  @override
  String get settings_storage_migrating_movingToAppDefault => '移动中到应用默认...';

  @override
  String get settings_storage_migrating_replacingExisting => '正在替换现有数据库...';

  @override
  String get settings_storage_migrating_switchingToExisting => '正在切换到现有数据库...';

  @override
  String get settings_storage_notSet => '未设置';

  @override
  String settings_storage_success_backupAt(Object path) {
    return '原始数据已备份至：$path';
  }

  @override
  String get settings_storage_success_moved => '数据库迁移成功';

  @override
  String get settings_storage_dangerZone => '危险区域';

  @override
  String get settings_storage_resetDatabase => '重置数据库';

  @override
  String get settings_storage_resetDatabase_subtitle => '删除所有数据并重新开始';

  @override
  String get settings_storage_resetDialog_title => '重置数据库？';

  @override
  String get settings_storage_resetDialog_body =>
      '这将永久删除您的所有数据，包括潜水、潜水点、装备和设置。重置前将自动创建备份。';

  @override
  String get settings_storage_resetDialog_confirmHint => '输入「Delete」以确认';

  @override
  String get settings_storage_resetDialog_confirmButton => '重置';

  @override
  String get settings_storage_resetDialog_backupFailed => '备份失败。为保护您的数据，重置已中止。';

  @override
  String settings_storage_resetDialog_resetFailed(Object error) {
    return '重置失败：$error';
  }

  @override
  String get settings_storage_resetComplete_title => '数据库已重置';

  @override
  String get settings_storage_resetComplete_description =>
      '您的数据已清除并已保存备份。点击继续以重新加载应用。';

  @override
  String get settings_summary_activeDiver => '当前潜水员';

  @override
  String get settings_summary_currentConfiguration => '当前配置';

  @override
  String get settings_summary_depth => '深度';

  @override
  String get settings_summary_error => '错误';

  @override
  String get settings_summary_gradientFactors => '梯度因子';

  @override
  String get settings_summary_loading => '加载中...';

  @override
  String get settings_summary_notSet => '未设置';

  @override
  String get settings_summary_pressure => '压力';

  @override
  String get settings_summary_subtitle => '选择一个类别进行配置';

  @override
  String get settings_summary_temperature => '温度';

  @override
  String get settings_summary_theme => '主题';

  @override
  String get settings_summary_theme_dark => '深色';

  @override
  String get settings_summary_theme_light => '浅色';

  @override
  String get settings_summary_theme_system => '系统';

  @override
  String get settings_summary_tip => '提示：使用「数据」部分定期备份您的潜水日志。';

  @override
  String get settings_summary_title => '设置';

  @override
  String get settings_summary_unitPreferences => '单位偏好';

  @override
  String get settings_summary_units => '单位';

  @override
  String get settings_summary_volume => '容积';

  @override
  String get settings_summary_weight => '重量';

  @override
  String get settings_units_custom => '自定义';

  @override
  String get settings_units_dateFormat => '日期格式';

  @override
  String get settings_units_depth => '深度';

  @override
  String get settings_units_depth_feet => '英尺 (ft)';

  @override
  String get settings_units_depth_meters => '米 (m)';

  @override
  String get settings_units_dialog_dateFormat => '日期格式';

  @override
  String get settings_units_dialog_depthUnit => '深度单位';

  @override
  String get settings_units_dialog_pressureUnit => '压力单位';

  @override
  String get settings_units_dialog_sacRateUnit => '耗气率单位';

  @override
  String get settings_units_dialog_temperatureUnit => '温度单位';

  @override
  String get settings_units_dialog_timeFormat => '时间格式';

  @override
  String get settings_units_dialog_volumeUnit => '容量单位';

  @override
  String get settings_units_dialog_weightUnit => '重量单位';

  @override
  String get settings_units_header_individualUnits => '个别单位';

  @override
  String get settings_units_header_timeDateFormat => '时间与日期格式';

  @override
  String get settings_units_header_unitSystem => '单位系统';

  @override
  String get settings_units_imperial => '英制';

  @override
  String get settings_units_metric => '指标';

  @override
  String get settings_units_pressure => '压力';

  @override
  String get settings_units_pressure_bar => 'Bar';

  @override
  String get settings_units_pressure_psi => 'PSI';

  @override
  String get settings_units_quickSelect => '快速选择';

  @override
  String get settings_units_sacRate => '气体消耗率';

  @override
  String get settings_units_sac_pressurePerMinute => '压力/分钟';

  @override
  String get settings_units_sac_pressurePerMinute_subtitle =>
      '无需气瓶容量（bar/min 或 psi/min）';

  @override
  String get settings_units_sac_volumePerMinute => '容量/分钟';

  @override
  String get settings_units_sac_volumePerMinute_subtitle =>
      '需要气瓶容量（L/min 或 cuft/min）';

  @override
  String get settings_units_temperature => '温度';

  @override
  String get settings_units_temperature_celsius => '摄氏度 (°C)';

  @override
  String get settings_units_temperature_fahrenheit => '华氏度 (°F)';

  @override
  String get settings_units_timeFormat => '时间格式';

  @override
  String get settings_units_volume => '容积';

  @override
  String get settings_units_volume_cubicFeet => '立方英尺 (cuft)';

  @override
  String get settings_units_volume_liters => '升 (L)';

  @override
  String get settings_units_weight => '重量';

  @override
  String get settings_units_weight_kilograms => '千克 (kg)';

  @override
  String get settings_units_weight_pounds => '磅 (lbs)';

  @override
  String get signatures_action_clear => '清除';

  @override
  String get signatures_action_closeSignatureView => '关闭签名视图';

  @override
  String get signatures_action_deleteSignature => '删除签名';

  @override
  String get signatures_action_done => '完成';

  @override
  String get signatures_action_readyToSign => '准备就绪到签名';

  @override
  String get signatures_action_request => '请求';

  @override
  String get signatures_action_saveSignature => '保存签名';

  @override
  String signatures_buddyCard_notSignedSemantics(Object name) {
    return '$name 的签名，未签署';
  }

  @override
  String signatures_buddyCard_signedSemantics(Object name) {
    return '$name 的签名，已签署';
  }

  @override
  String get signatures_captureInstructorSignature => '获取教练签名';

  @override
  String signatures_deleteDialog_message(Object name) {
    return '确定要删除 $name 的签名吗？此操作无法撤销。';
  }

  @override
  String get signatures_deleteDialog_title => '删除签名？';

  @override
  String get signatures_drawSignatureHint => '请在上方绘制您的签名';

  @override
  String get signatures_drawSignatureHintDetailed => '使用手指或触控笔在上方绘制签名';

  @override
  String get signatures_drawSignatureSemantics => '绘制签名';

  @override
  String get signatures_error_drawSignature => '请绘制签名';

  @override
  String get signatures_error_enterSignerName => '请输入签名者姓名';

  @override
  String get signatures_field_instructorName => '教练名称';

  @override
  String get signatures_field_instructorNameHint => '输入教练姓名';

  @override
  String get signatures_handoff_title => '请将设备交给';

  @override
  String get signatures_instructorSignature => '教练签名';

  @override
  String get signatures_noSignatureImage => '无签名图片';

  @override
  String signatures_signHere(Object name) {
    return '$name - 签名此处';
  }

  @override
  String get signatures_signed => '已签名';

  @override
  String signatures_signedCountSemantics(Object signed, Object total) {
    return '$signed/$total 位潜伴已签名';
  }

  @override
  String signatures_signedDate(Object date) {
    return '已签名 $date';
  }

  @override
  String get signatures_title => '签名';

  @override
  String get signatures_viewSignature => '查看签名';

  @override
  String signatures_viewSignatureSemantics(Object name) {
    return '查看 $name 的签名';
  }

  @override
  String get statistics_appBar_title => '统计';

  @override
  String statistics_categoryCard_semanticLabel(Object title) {
    return '$title 统计类别';
  }

  @override
  String get statistics_category_conditions_subtitle => '能见度与温度';

  @override
  String get statistics_category_conditions_title => '条件';

  @override
  String get statistics_category_equipment_subtitle => '装备使用与配重';

  @override
  String get statistics_category_equipment_title => '装备';

  @override
  String get statistics_category_gas_subtitle => '耗气率与混合气';

  @override
  String get statistics_category_gas_title => '空气消耗';

  @override
  String get statistics_category_geographic_subtitle => '国家与地区';

  @override
  String get statistics_category_geographic_title => '地理';

  @override
  String get statistics_category_marineLife_subtitle => '物种目击';

  @override
  String get statistics_category_marineLife_title => '海洋生物';

  @override
  String get statistics_category_profile_subtitle => '上升速率与减压';

  @override
  String get statistics_category_profile_title => '轮廓分析';

  @override
  String get statistics_category_progression_subtitle => '深度与时间趋势';

  @override
  String get statistics_category_progression_title => '进展';

  @override
  String get statistics_category_social_subtitle => '潜伴 & 潜水中心';

  @override
  String get statistics_category_social_title => '社交';

  @override
  String get statistics_category_timePatterns_subtitle => '您的潜水时间规律';

  @override
  String get statistics_category_timePatterns_title => '时间模式';

  @override
  String statistics_chart_barSemanticLabel(Object count) {
    return '包含 $count 个类别的柱状图';
  }

  @override
  String statistics_chart_distributionSemanticLabel(Object count) {
    return '包含 $count 个扇区的分布饼图';
  }

  @override
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames) {
    return '比较 $seriesNames 的多趋势折线图';
  }

  @override
  String get statistics_chart_noBarData => '无可用数据';

  @override
  String get statistics_chart_noDistributionData => '无可用分布数据';

  @override
  String get statistics_chart_noTrendData => '无趋势数据可用';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return '显示 $count 个数据点的趋势折线图';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return '显示 $yAxisLabel 的 $count 个数据点的趋势折线图';
  }

  @override
  String get statistics_conditions_appBar_title => '条件';

  @override
  String get statistics_conditions_entryMethod_empty => '无可用入水方式数据';

  @override
  String get statistics_conditions_entryMethod_error => '加载入水方式数据失败';

  @override
  String get statistics_conditions_entryMethod_subtitle => '岸潜、船潜等';

  @override
  String get statistics_conditions_entryMethod_title => '入水方式';

  @override
  String get statistics_conditions_temperature_empty => '无温度数据可用';

  @override
  String get statistics_conditions_temperature_error => '加载温度数据失败';

  @override
  String get statistics_conditions_temperature_seriesAvg => '平均';

  @override
  String get statistics_conditions_temperature_seriesMax => '最高';

  @override
  String get statistics_conditions_temperature_seriesMin => '最低';

  @override
  String get statistics_conditions_temperature_subtitle => '最低/平均/最高温度';

  @override
  String get statistics_conditions_temperature_title => '每月水温';

  @override
  String get statistics_conditions_visibility_error => '加载能见度数据失败';

  @override
  String get statistics_conditions_visibility_subtitle => '按能见度条件分类的潜水';

  @override
  String get statistics_conditions_visibility_title => '能见度分布';

  @override
  String get statistics_conditions_waterType_error => '加载水型数据失败';

  @override
  String get statistics_conditions_waterType_subtitle => '海水与淡水潜水';

  @override
  String get statistics_conditions_waterType_title => '水型';

  @override
  String get statistics_equipment_appBar_title => '装备';

  @override
  String get statistics_equipment_mostUsedGear_error => '加载装备数据失败';

  @override
  String get statistics_equipment_mostUsedGear_subtitle => '按潜水次数统计的装备';

  @override
  String get statistics_equipment_mostUsedGear_title => '最常用装备';

  @override
  String get statistics_equipment_weightTrend_error => '加载配重趋势失败';

  @override
  String get statistics_equipment_weightTrend_subtitle => '平均配重随时间变化';

  @override
  String get statistics_equipment_weightTrend_title => '配重趋势';

  @override
  String get statistics_error_loadingStatistics => '加载统计数据时出错';

  @override
  String get statistics_gas_appBar_title => '空气消耗';

  @override
  String get statistics_gas_gasMix_error => '加载混合气数据失败';

  @override
  String get statistics_gas_gasMix_subtitle => '按气体类型分类的潜水';

  @override
  String get statistics_gas_gasMix_title => '混合气分布';

  @override
  String get statistics_gas_sacByRole_empty => '无可用多气瓶数据';

  @override
  String get statistics_gas_sacByRole_error => '加载按用途分类的耗气率失败';

  @override
  String get statistics_gas_sacByRole_subtitle => '按气瓶类型的平均耗气量';

  @override
  String get statistics_gas_sacByRole_title => '按气瓶用途的耗气率';

  @override
  String get statistics_gas_sacRecords_best => '最佳耗气率';

  @override
  String get statistics_gas_sacRecords_empty => '暂无耗气率数据';

  @override
  String get statistics_gas_sacRecords_error => '加载耗气率记录失败';

  @override
  String get statistics_gas_sacRecords_highest => '最高耗气率';

  @override
  String get statistics_gas_sacRecords_subtitle => '最佳和最差耗气量';

  @override
  String get statistics_gas_sacRecords_title => '耗气率记录';

  @override
  String get statistics_gas_sacTrend_error => '加载耗气率趋势失败';

  @override
  String get statistics_gas_sacTrend_subtitle => '5年月均值';

  @override
  String get statistics_gas_sacTrend_title => '耗气率趋势';

  @override
  String get statistics_gas_tankRole_backGas => '主气';

  @override
  String get statistics_gas_tankRole_bailout => '应急';

  @override
  String get statistics_gas_tankRole_deco => '减压气';

  @override
  String get statistics_gas_tankRole_diluent => '稀释气';

  @override
  String get statistics_gas_tankRole_oxygenSupply => 'O₂ 供气';

  @override
  String get statistics_gas_tankRole_pony => '应急瓶';

  @override
  String get statistics_gas_tankRole_sidemountLeft => '左侧挂';

  @override
  String get statistics_gas_tankRole_sidemountRight => '右侧挂';

  @override
  String get statistics_gas_tankRole_stage => '阶段瓶';

  @override
  String get statistics_geographic_appBar_title => '地理';

  @override
  String get statistics_geographic_countries_empty => '暂无访问的国家';

  @override
  String get statistics_geographic_countries_error => '加载国家数据失败';

  @override
  String get statistics_geographic_countries_subtitle => '按国家分类的潜水';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count 个国家。最多：$topName，$topCount 次潜水';
  }

  @override
  String get statistics_geographic_countries_title => '已访问的国家';

  @override
  String get statistics_geographic_regions_empty => '暂无探索的区域';

  @override
  String get statistics_geographic_regions_error => '加载区域数据失败';

  @override
  String get statistics_geographic_regions_subtitle => '按区域分类的潜水';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count 个区域。最多：$topName，$topCount 次潜水';
  }

  @override
  String get statistics_geographic_regions_title => '已探索的区域';

  @override
  String get statistics_geographic_trips_empty => '无旅行数据';

  @override
  String get statistics_geographic_trips_error => '加载旅行数据失败';

  @override
  String get statistics_geographic_trips_subtitle => '潜水次数最多的旅行';

  @override
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count 次旅行。最多：$topName，$topCount 次潜水';
  }

  @override
  String get statistics_geographic_trips_title => '每次旅行的潜水次数';

  @override
  String get statistics_listContent_selectedSuffix => ', 已选择';

  @override
  String get statistics_marineLife_appBar_title => '海洋生物';

  @override
  String get statistics_marineLife_bestSites_empty => '无潜水点数据';

  @override
  String get statistics_marineLife_bestSites_error => '加载潜水点数据失败';

  @override
  String get statistics_marineLife_bestSites_subtitle => '物种种类最多的潜水点';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count 个潜水点。最佳：$topName，$topCount 种物种';
  }

  @override
  String get statistics_marineLife_bestSites_title => '海洋生物最佳潜水点';

  @override
  String get statistics_marineLife_mostCommon_empty => '无目击数据';

  @override
  String get statistics_marineLife_mostCommon_error => '加载目击数据失败';

  @override
  String get statistics_marineLife_mostCommon_subtitle => '最常见的物种';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count 种物种。最常见：$topName，$topCount 次目击';
  }

  @override
  String get statistics_marineLife_mostCommon_title => '最常见目击';

  @override
  String get statistics_marineLife_speciesSpotted => '已发现物种';

  @override
  String get statistics_profile_appBar_title => '轮廓分析';

  @override
  String get statistics_profile_ascentDescent_empty => '无档案数据可用';

  @override
  String get statistics_profile_ascentDescent_error => '加载速率数据失败';

  @override
  String get statistics_profile_ascentDescent_subtitle => '来自潜水轮廓数据';

  @override
  String get statistics_profile_ascentDescent_title => '平均上升与下降速率';

  @override
  String get statistics_profile_avgAscent => '平均上升';

  @override
  String get statistics_profile_avgDescent => '平均下降';

  @override
  String get statistics_profile_deco_decoDives => '减压潜水';

  @override
  String get statistics_profile_deco_decoLabel => '减压';

  @override
  String get statistics_profile_deco_decoRate => '减压速率';

  @override
  String get statistics_profile_deco_empty => '无减压数据可用';

  @override
  String get statistics_profile_deco_error => '加载减压数据失败';

  @override
  String get statistics_profile_deco_noDeco => '无减压';

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return '减压比率：$percentage% 的潜水需要减压停留';
  }

  @override
  String get statistics_profile_deco_subtitle => '产生减压停留的潜水';

  @override
  String get statistics_profile_deco_title => '减压义务';

  @override
  String get statistics_profile_timeAtDepth_empty => '无深度数据可用';

  @override
  String get statistics_profile_timeAtDepth_error => '加载深度范围数据失败';

  @override
  String get statistics_profile_timeAtDepth_subtitle => '在各深度范围的大致停留时间';

  @override
  String get statistics_profile_timeAtDepth_title => '各深度范围停留时间';

  @override
  String statistics_profile_timeAtDepth_valueFormat(Object value) {
    return '$value 分钟';
  }

  @override
  String get statistics_progression_appBar_title => '潜水进展';

  @override
  String get statistics_progression_bottomTime_error => '加载潜水时间趋势失败';

  @override
  String get statistics_progression_bottomTime_subtitle => '月均潜水时长';

  @override
  String get statistics_progression_bottomTime_title => '潜水时间趋势';

  @override
  String get statistics_progression_cumulative_error => '加载累计数据失败';

  @override
  String get statistics_progression_cumulative_subtitle => '累计潜水次数随时间变化';

  @override
  String get statistics_progression_cumulative_title => '累计潜水次数';

  @override
  String get statistics_progression_depthProgression_error => '加载深度进展失败';

  @override
  String get statistics_progression_depthProgression_subtitle => '5年月度最大深度';

  @override
  String get statistics_progression_depthProgression_title => '最大深度进展';

  @override
  String get statistics_progression_divesPerYear_empty => '无可用年度数据';

  @override
  String get statistics_progression_divesPerYear_error => '加载年度数据失败';

  @override
  String get statistics_progression_divesPerYear_subtitle => '年度潜水次数对比';

  @override
  String get statistics_progression_divesPerYear_title => '每年潜水次数';

  @override
  String get statistics_ranking_countLabel_dives => '次潜水';

  @override
  String get statistics_ranking_countLabel_sightings => '次目击';

  @override
  String get statistics_ranking_countLabel_species => '物种';

  @override
  String get statistics_ranking_emptyState => '暂无数据';

  @override
  String statistics_ranking_itemCount(Object count, Object label) {
    return '$count $label';
  }

  @override
  String statistics_ranking_moreItems(Object count) {
    return '还有 $count 项';
  }

  @override
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  ) {
    return '$name，排名第 $rank，$count $label';
  }

  @override
  String get statistics_records_appBar_title => '潜水记录';

  @override
  String get statistics_records_coldestDive => '最冷潜水';

  @override
  String get statistics_records_deepestDive => '最深潜水';

  @override
  String statistics_records_diveNumber(Object number) {
    return '潜水 #$number';
  }

  @override
  String get statistics_records_emptySubtitle => '开始记录潜水以查看您的纪录';

  @override
  String get statistics_records_emptyTitle => '暂无纪录';

  @override
  String get statistics_records_error => '加载纪录时出错';

  @override
  String get statistics_records_firstDive => '首次潜水';

  @override
  String get statistics_records_longestDive => '最长潜水';

  @override
  String statistics_records_longestDiveValue(Object minutes) {
    return '$minutes 分钟';
  }

  @override
  String statistics_records_milestoneSemanticLabel(
    Object title,
    Object siteName,
  ) {
    return '$title: $siteName';
  }

  @override
  String get statistics_records_milestones => '里程碑';

  @override
  String get statistics_records_mostRecentDive => '最近一次潜水';

  @override
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  ) {
    return '$title：$value，潜水点 $siteName';
  }

  @override
  String get statistics_records_retry => '重试';

  @override
  String get statistics_records_shallowestDive => '最浅潜水';

  @override
  String get statistics_records_unknownSite => '未知潜水点';

  @override
  String get statistics_records_warmestDive => '最暖潜水';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return '$title 部分';
  }

  @override
  String get statistics_social_appBar_title => '社交与潜伴';

  @override
  String get statistics_social_soloVsBuddy_empty => '无潜水数据可用';

  @override
  String get statistics_social_soloVsBuddy_error => '加载潜伴数据失败';

  @override
  String get statistics_social_soloVsBuddy_solo => '独潜';

  @override
  String get statistics_social_soloVsBuddy_subtitle => '有无同伴的潜水统计';

  @override
  String get statistics_social_soloVsBuddy_title => '独潜与结伴潜水';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => '与潜伴';

  @override
  String get statistics_social_topBuddies_error => '加载潜伴排名失败';

  @override
  String get statistics_social_topBuddies_subtitle => '最常一起潜水的伙伴';

  @override
  String get statistics_social_topBuddies_title => '最佳潜伴';

  @override
  String get statistics_social_topDiveCenters_error => '加载潜水中心排名失败';

  @override
  String get statistics_social_topDiveCenters_subtitle => '最常光顾的运营商';

  @override
  String get statistics_social_topDiveCenters_title => '最常去的潜水中心';

  @override
  String get statistics_summary_avgDepth => '平均深度';

  @override
  String get statistics_summary_avgTemp => '平均温度';

  @override
  String get statistics_summary_depthDistribution_empty => '记录潜水后将显示图表';

  @override
  String get statistics_summary_depthDistribution_semanticLabel => '显示深度分布的饼图';

  @override
  String get statistics_summary_depthDistribution_title => '深度分布';

  @override
  String get statistics_summary_diveTypes_empty => '记录潜水后将显示图表';

  @override
  String statistics_summary_diveTypes_moreTypes(Object count) {
    return '还有 $count 种类型';
  }

  @override
  String get statistics_summary_diveTypes_semanticLabel => '显示潜水类型分布的饼图';

  @override
  String get statistics_summary_diveTypes_title => '潜水类型';

  @override
  String get statistics_summary_divesByMonth_empty => '记录潜水后将显示图表';

  @override
  String get statistics_summary_divesByMonth_semanticLabel => '显示每月潜水次数的柱状图';

  @override
  String get statistics_summary_divesByMonth_title => '每月潜水次数';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel $count 次潜水';
  }

  @override
  String get statistics_summary_header_subtitle => '选择一个类别以查看详细统计';

  @override
  String get statistics_summary_header_title => '统计概览';

  @override
  String get statistics_summary_maxDepth => '最大深度';

  @override
  String get statistics_summary_sitesVisited => '已访问潜水点';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次潜水',
      one: '1 次潜水',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty => '尚未创建标签';

  @override
  String get statistics_summary_tagUsage_emptyHint => '为潜水添加标签以查看统计';

  @override
  String statistics_summary_tagUsage_moreTags(Object count) {
    return '还有 $count 个标签';
  }

  @override
  String statistics_summary_tagUsage_tagCount(Object count) {
    return '$count 标签';
  }

  @override
  String get statistics_summary_tagUsage_title => '标签使用情况';

  @override
  String statistics_summary_topDiveSites_diveCount(Object count) {
    return '$count 次潜水';
  }

  @override
  String get statistics_summary_topDiveSites_empty => '暂无潜水点';

  @override
  String get statistics_summary_topDiveSites_title => '热门潜水点';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count 总计';
  }

  @override
  String get statistics_summary_totalDives => '总计潜水';

  @override
  String get statistics_summary_totalTime => '总计时间';

  @override
  String get statistics_timePatterns_appBar_title => '时间模式';

  @override
  String get statistics_timePatterns_dayOfWeek_empty => '无可用数据';

  @override
  String get statistics_timePatterns_dayOfWeek_error => '加载星期数据失败';

  @override
  String get statistics_timePatterns_dayOfWeek_fri => '周五';

  @override
  String get statistics_timePatterns_dayOfWeek_mon => '周一';

  @override
  String get statistics_timePatterns_dayOfWeek_sat => '周六';

  @override
  String get statistics_timePatterns_dayOfWeek_subtitle => '您最常在哪天潜水？';

  @override
  String get statistics_timePatterns_dayOfWeek_sun => '周日';

  @override
  String get statistics_timePatterns_dayOfWeek_thu => '周四';

  @override
  String get statistics_timePatterns_dayOfWeek_title => '按星期统计的潜水次数';

  @override
  String get statistics_timePatterns_dayOfWeek_tue => '周二';

  @override
  String get statistics_timePatterns_dayOfWeek_wed => '周三';

  @override
  String get statistics_timePatterns_month_apr => '4月';

  @override
  String get statistics_timePatterns_month_aug => '8月';

  @override
  String get statistics_timePatterns_month_dec => '12月';

  @override
  String get statistics_timePatterns_month_feb => '2月';

  @override
  String get statistics_timePatterns_month_jan => '1月';

  @override
  String get statistics_timePatterns_month_jul => '7月';

  @override
  String get statistics_timePatterns_month_jun => '6月';

  @override
  String get statistics_timePatterns_month_mar => '3月';

  @override
  String get statistics_timePatterns_month_may => '5月';

  @override
  String get statistics_timePatterns_month_nov => '11月';

  @override
  String get statistics_timePatterns_month_oct => '10月';

  @override
  String get statistics_timePatterns_month_sep => '9月';

  @override
  String get statistics_timePatterns_seasonal_empty => '无可用数据';

  @override
  String get statistics_timePatterns_seasonal_error => '加载季节数据失败';

  @override
  String get statistics_timePatterns_seasonal_subtitle => '按月份统计的潜水（所有年份）';

  @override
  String get statistics_timePatterns_seasonal_title => '季节性模式';

  @override
  String get statistics_timePatterns_surfaceInterval_average => '平均';

  @override
  String get statistics_timePatterns_surfaceInterval_empty => '无可用水面间隔数据';

  @override
  String get statistics_timePatterns_surfaceInterval_error => '加载水面间隔数据失败';

  @override
  String statistics_timePatterns_surfaceInterval_formatHoursMinutes(
    Object hours,
    Object minutes,
  ) {
    return '${hours}h ${minutes}m';
  }

  @override
  String statistics_timePatterns_surfaceInterval_formatMinutes(Object minutes) {
    return '$minutes 分钟';
  }

  @override
  String get statistics_timePatterns_surfaceInterval_maximum => '最大';

  @override
  String get statistics_timePatterns_surfaceInterval_minimum => '最小';

  @override
  String get statistics_timePatterns_surfaceInterval_subtitle => '两次潜水之间的时间';

  @override
  String get statistics_timePatterns_surfaceInterval_title => '水面间隔统计';

  @override
  String get statistics_timePatterns_timeOfDay_error => '加载时段数据失败';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle => '上午、下午、傍晚或夜间';

  @override
  String get statistics_timePatterns_timeOfDay_title => '按时段统计的潜水次数';

  @override
  String get statistics_tooltip_diveRecords => '潜水记录';

  @override
  String get statistics_tooltip_refreshRecords => '刷新纪录';

  @override
  String get statistics_tooltip_refreshStatistics => '刷新统计';

  @override
  String statistics_valueCard_semanticLabel(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String get surfaceInterval_aboutTissueLoading_body =>
      '您的身体有16个组织隔间，以不同速率吸收和释放氮气。快组织（如血液）饱和快但排气也快。慢组织（如骨骼和脂肪）吸收和排放都需要更长时间。「前导隔间」是饱和度最高的组织，通常控制您的免减压极限。在水面间隔期间，所有组织向水面饱和水平（约40%负荷）排气。';

  @override
  String get surfaceInterval_aboutTissueLoading_title => '关于组织负荷';

  @override
  String get surfaceInterval_action_resetDefaults => '恢复默认值';

  @override
  String get surfaceInterval_disclaimer =>
      '此工具仅供计划参考。请务必使用潜水电脑并遵循您的训练。结果基于 Buhlmann ZH-L16C 算法，可能与您的潜水电脑有所不同。';

  @override
  String get surfaceInterval_field_depth => '深度';

  @override
  String get surfaceInterval_field_gasMix => '气体混合: ';

  @override
  String get surfaceInterval_field_he => 'He';

  @override
  String get surfaceInterval_field_o2 => 'O₂';

  @override
  String get surfaceInterval_field_time => '时间';

  @override
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit) {
    return '首次潜水深度: $depth $unit';
  }

  @override
  String surfaceInterval_firstDive_timeSemantics(Object time) {
    return '第一次潜水时间：$time 分钟';
  }

  @override
  String get surfaceInterval_firstDive_title => '首次潜水';

  @override
  String surfaceInterval_format_hours(Object count) {
    return '$count 小时';
  }

  @override
  String surfaceInterval_format_minutes(Object count) {
    return '$count 分钟';
  }

  @override
  String get surfaceInterval_gasMix_air => '空气';

  @override
  String surfaceInterval_gasMix_ean(Object percent) {
    return 'EAN$percent';
  }

  @override
  String surfaceInterval_gasMix_trimix(Object o2, Object he) {
    return '三混气 $o2/$he';
  }

  @override
  String surfaceInterval_heSemantics(Object percent) {
    return '氦气: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String get surfaceInterval_result_currentInterval => '当前间隔';

  @override
  String get surfaceInterval_result_inDeco => '在减压';

  @override
  String get surfaceInterval_result_increaseInterval => '增加水面间隔或减少第二次潜水深度/时间';

  @override
  String get surfaceInterval_result_minimumInterval => '最短水面间隔';

  @override
  String get surfaceInterval_result_ndlForSecondDive => '第二次潜水的免减压极限';

  @override
  String surfaceInterval_result_ndlMinutes(Object minutes) {
    return '$minutes 分钟 NDL';
  }

  @override
  String get surfaceInterval_result_notYetSafe => '尚不安全，请增加水面间隔';

  @override
  String get surfaceInterval_result_safeToDive => '安全到潜水';

  @override
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  ) {
    return '最短水面间隔：$interval。当前间隔：$current。第二次潜水的免减压极限：$ndl。$status';
  }

  @override
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit) {
    return '第二潜水深度: $depth $unit';
  }

  @override
  String get surfaceInterval_secondDive_gasAir => '(空气)';

  @override
  String surfaceInterval_secondDive_timeSemantics(Object time) {
    return '第二次潜水时间：$time 分钟';
  }

  @override
  String get surfaceInterval_secondDive_title => '第二潜水';

  @override
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval) {
    return '组织恢复图表，显示16个隔间在 $interval 水面间隔期间的排气过程';
  }

  @override
  String get surfaceInterval_tissueRecovery_compartmentsLabel => '隔间（按半衰期速度排序）';

  @override
  String get surfaceInterval_tissueRecovery_description =>
      '显示16个组织隔间在水面间隔期间的排气过程';

  @override
  String get surfaceInterval_tissueRecovery_fast => '快速 (C1-5)';

  @override
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number) {
    return '前导隔间：C$number';
  }

  @override
  String get surfaceInterval_tissueRecovery_loadingPercent => '加载中 %';

  @override
  String get surfaceInterval_tissueRecovery_medium => '中等 (C6-10)';

  @override
  String get surfaceInterval_tissueRecovery_min => '分';

  @override
  String get surfaceInterval_tissueRecovery_now => '现在';

  @override
  String get surfaceInterval_tissueRecovery_slow => '慢速 (C11-16)';

  @override
  String get surfaceInterval_tissueRecovery_title => '组织恢复';

  @override
  String get surfaceInterval_title => '水面间隔';

  @override
  String tags_action_createNamed(Object tagName) {
    return '创建 \"$tagName\"';
  }

  @override
  String get tags_action_createTag => '创建标签';

  @override
  String get tags_action_deleteTag => '删除标签';

  @override
  String tags_dialog_deleteMessage(Object tagName) {
    return '确定要删除「$tagName」吗？这将从所有潜水中移除该标签。';
  }

  @override
  String get tags_dialog_deleteTitle => '删除标签？';

  @override
  String get tags_empty => '暂无标签。在编辑潜水时创建标签。';

  @override
  String get tags_hint_addMoreTags => '添加更多标签...';

  @override
  String get importWizard_tagsLabel => '标签';

  @override
  String get tags_hint_addTags => '添加标签...';

  @override
  String get tags_manage_title => '标签';

  @override
  String get tags_manage_searchHint => '搜索标签...';

  @override
  String tags_manage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次潜水',
      one: '1 次潜水',
      zero: '0 次潜水',
    );
    return '$_temp0';
  }

  @override
  String get tags_manage_emptyState => '暂无标签。创建一个开始使用吧。';

  @override
  String tags_manage_selectedCount(int count) {
    return '$count 已选择';
  }

  @override
  String get tags_manage_createTitle => '创建标签';

  @override
  String get tags_manage_editTitle => '编辑标签';

  @override
  String get tags_manage_nameLabel => '标签名称';

  @override
  String get tags_manage_colorLabel => '颜色';

  @override
  String get tags_manage_nameRequired => '标签名称为必填项';

  @override
  String get tags_manage_deleteTitle => '删除标签？';

  @override
  String tags_manage_deleteMessage(String tagName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次潜水',
      one: '1 次潜水',
      zero: '0 次潜水',
    );
    return '「$tagName」将从 $_temp0 中移除。此操作无法撤销。';
  }

  @override
  String tags_manage_bulkDeleteTitle(int count) {
    return '删除 $count 个标签？';
  }

  @override
  String tags_manage_bulkDeleteMessage(int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount 次潜水',
      one: '1 次潜水',
      zero: '0 次潜水',
    );
    return '这些标签将从总共 $_temp0 中移除。此操作无法撤销。';
  }

  @override
  String tags_manage_mergeTitle(int count) {
    return '合并 $count 个标签';
  }

  @override
  String get tags_manage_mergeResultName => '合并后的标签名称：';

  @override
  String get tags_manage_mergeKeepFrom => '或从以下保留名称：';

  @override
  String tags_manage_mergeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次潜水',
      one: '1 次潜水',
      zero: '0 次潜水',
    );
    return '这将影响总共 $_temp0。';
  }

  @override
  String get tags_manage_mergeAction => '合并';

  @override
  String get tags_title_manageTags => '管理标签';

  @override
  String get tank_al30Stage_description => '铝制 30 立方英尺阶段瓶';

  @override
  String get tank_al30Stage_displayName => 'AL30 阶段瓶';

  @override
  String get tank_al40Stage_description => '铝制 40 立方英尺阶段瓶';

  @override
  String get tank_al40Stage_displayName => 'AL40 阶段瓶';

  @override
  String get tank_al40_description => '铝制 40 立方英尺（应急瓶）';

  @override
  String get tank_al40_displayName => 'AL40';

  @override
  String get tank_al63_description => '铝制 63 立方英尺';

  @override
  String get tank_al63_displayName => 'AL63';

  @override
  String get tank_al80_description => '铝制 80 立方英尺（最常见）';

  @override
  String get tank_al80_displayName => 'AL80';

  @override
  String get tank_hp100_description => '高压钢瓶 100 立方英尺';

  @override
  String get tank_hp100_displayName => 'HP100';

  @override
  String get tank_hp120_description => '高压钢瓶 120 立方英尺';

  @override
  String get tank_hp120_displayName => 'HP120';

  @override
  String get tank_hp80_description => '高压钢瓶 80 立方英尺';

  @override
  String get tank_hp80_displayName => 'HP80';

  @override
  String get tank_lp85_description => '低压钢瓶 85 立方英尺';

  @override
  String get tank_lp85_displayName => 'LP85';

  @override
  String get tank_steel10_description => '钢瓶 10 升（欧洲规格）';

  @override
  String get tank_steel10_displayName => '钢 10L';

  @override
  String get tank_steel12_description => '钢瓶 12 升（欧洲规格）';

  @override
  String get tank_steel12_displayName => '钢 12L';

  @override
  String get tank_steel15_description => '钢瓶 15 升（欧洲规格）';

  @override
  String get tank_steel15_displayName => '钢 15L';

  @override
  String get tides_action_refresh => '刷新潮汐数据';

  @override
  String get tides_chart_24hourForecast => '24小时预报';

  @override
  String tides_chart_heightAxis(Object depthSymbol) {
    return '高度 ($depthSymbol)';
  }

  @override
  String get tides_chart_msl => '平均海平面';

  @override
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr) {
    return ' 现在 $nowTimeStr $nowHeightStr';
  }

  @override
  String get tides_error_unableToLoad => '无法加载潮汐数据';

  @override
  String get tides_error_unableToLoadChart => '无法加载图表';

  @override
  String tides_label_ago(Object duration) {
    return '$duration 前';
  }

  @override
  String tides_label_currentHeight(Object height, Object depthSymbol) {
    return '当前潮位: $height$depthSymbol';
  }

  @override
  String tides_label_fromNow(Object duration) {
    return '$duration 后';
  }

  @override
  String get tides_label_high => '高潮';

  @override
  String get tides_label_highIn => '高在';

  @override
  String get tides_label_highTide => '高潮汐';

  @override
  String get tides_label_low => '低潮';

  @override
  String get tides_label_lowIn => '低在';

  @override
  String get tides_label_lowTide => '低潮汐';

  @override
  String tides_label_tideIn(Object duration) {
    return '$duration后';
  }

  @override
  String get tides_label_tideTimes => '潮汐时间';

  @override
  String get tides_label_today => '今天';

  @override
  String get tides_label_tomorrow => '明天';

  @override
  String get tides_label_upcomingTides => '即将到来的潮汐';

  @override
  String get tides_legend_highTide => '高潮汐';

  @override
  String get tides_legend_lowTide => '低潮汐';

  @override
  String get tides_legend_now => '现在';

  @override
  String get tides_legend_tideLevel => '潮汐等级';

  @override
  String get tides_noDataAvailable => '无潮汐数据可用';

  @override
  String get tides_noDataForLocation => '此位置无可用潮汐数据';

  @override
  String get tides_noExtremesData => '无极值数据';

  @override
  String get tides_noTideTimesAvailable => '无可用潮汐时间';

  @override
  String tides_semantic_currentTide(
    Object tideState,
    Object height,
    Object depthSymbol,
    Object nextExtreme,
  ) {
    return '$tideState 潮汐, $height$depthSymbol$nextExtreme';
  }

  @override
  String tides_semantic_extremeItem(
    Object typeLabel,
    Object time,
    Object height,
    Object depthSymbol,
  ) {
    return '$typeLabel 潮汐在 $time, $height$depthSymbol';
  }

  @override
  String tides_semantic_tideChart(Object extremesSummary) {
    return '潮汐图表。$extremesSummary';
  }

  @override
  String tides_semantic_tideState(Object state) {
    return '潮汐状态：$state';
  }

  @override
  String get tides_title => '潮汐';

  @override
  String get transfer_appBar_title => '传输';

  @override
  String get transfer_computers_aboutContent =>
      '通过蓝牙连接您的潜水电脑以直接下载潜水日志到应用。支持的潜水电脑包括 Suunto、Shearwater、Garmin、Mares 以及许多其他热门品牌。Apple Watch Ultra 用户可以直接从健康应用导入潜水数据，包括深度、持续时间和心率。';

  @override
  String get transfer_computers_aboutTitle => '关于潜水电脑';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple 手表';

  @override
  String get transfer_computers_appleWatchSubtitle => '通过 Apple HealthKit 导入潜水';

  @override
  String get transfer_computers_appleWatchTitle => '从 Apple Watch 导入';

  @override
  String get transfer_computers_connectSubtitle => '发现并配对潜水电脑';

  @override
  String get transfer_computers_connectTitle => '连接新潜水电脑';

  @override
  String get transfer_computers_errorLoading => '加载潜水电脑时出错';

  @override
  String get transfer_computers_loading => '加载中...';

  @override
  String get transfer_computers_manageTitle => '管理潜水电脑';

  @override
  String get transfer_computers_noComputersSaved => '没有已保存的潜水电脑';

  @override
  String transfer_computers_savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '潜水电脑',
      one: '潜水电脑',
    );
    return '$count 台已保存的$_temp0';
  }

  @override
  String get transfer_computers_sectionHeader => '潜水电脑';

  @override
  String get transfer_csvExport_cancelButton => '取消';

  @override
  String get transfer_csvExport_dataTypeHeader => '数据类型';

  @override
  String get transfer_csvExport_descriptionDives => '将所有潜水日志导出为电子表格';

  @override
  String get transfer_csvExport_descriptionEquipment => '导出装备库存和维护信息';

  @override
  String get transfer_csvExport_descriptionSites => '导出潜水点位置和详情';

  @override
  String get transfer_csvExport_dialogTitle => '导出 CSV';

  @override
  String get transfer_csvExport_exportButton => '导出 CSV';

  @override
  String get transfer_csvExport_optionDivesTitle => '潜水 CSV';

  @override
  String get transfer_csvExport_optionEquipmentTitle => '装备 CSV';

  @override
  String get transfer_csvExport_optionSitesTitle => '潜水点 CSV';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return '导出 $typeName';
  }

  @override
  String get transfer_csvExport_typeDives => '潜水';

  @override
  String get transfer_csvExport_typeEquipment => '装备';

  @override
  String get transfer_csvExport_typeSites => '潜水点';

  @override
  String get transfer_detail_backTooltip => '返回传输';

  @override
  String get transfer_export_aboutContent =>
      '以多种格式导出您的潜水数据。PDF 可创建可打印的潜水日志。UDDF 是与大多数潜水日志软件兼容的通用格式。CSV 文件可在电子表格应用中打开。';

  @override
  String get transfer_export_backupLink => '前往备份与恢复';

  @override
  String get transfer_export_aboutTitle => '关于导出';

  @override
  String get transfer_export_completed => '导出完成';

  @override
  String get transfer_export_csvSubtitle => '电子表格格式';

  @override
  String get transfer_export_csvTitle => 'CSV 导出';

  @override
  String get transfer_export_excelSubtitle => '所有数据在一个文件中（潜水、潜水点、装备、统计）';

  @override
  String get transfer_export_excelTitle => 'Excel 工作簿';

  @override
  String transfer_export_failed(Object error) {
    return '导出失败：$error';
  }

  @override
  String get transfer_export_kmlSubtitle => '在3D地球上查看潜水点';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => '多格式导出';

  @override
  String get transfer_export_optionSaveSubtitle => '选择保存到设备上的位置';

  @override
  String get transfer_export_optionSaveTitle => '保存到文件';

  @override
  String get transfer_export_optionShareSubtitle => '通过电子邮件、消息或其他应用发送';

  @override
  String get transfer_export_optionShareTitle => '分享';

  @override
  String get transfer_export_pdfSubtitle => '可打印的潜水日志';

  @override
  String get transfer_export_pdfTitle => 'PDF 日志本';

  @override
  String get transfer_export_progressExporting => '正在导出...';

  @override
  String get transfer_export_sectionHeader => '导出数据';

  @override
  String get transfer_export_uddfSubtitle => '通用潜水数据格式';

  @override
  String get transfer_export_uddfTitle => 'UDDF 导出';

  @override
  String get transfer_import_aboutContent =>
      '使用「导入数据」以获得最佳体验——它会自动检测您的文件格式和来源应用。下方的各格式选项也可直接使用。';

  @override
  String get transfer_import_aboutTitle => '关于导入';

  @override
  String get transfer_import_fileImportSemanticLabel => '从文件导入潜水数据';

  @override
  String get transfer_import_fileImportSubtitle => 'UDDF、Subsurface、CSV、FIT 等';

  @override
  String get transfer_import_fileImportTitle => '文件导入';

  @override
  String get transfer_import_sectionHeader => '导入数据';

  @override
  String get transfer_pdfExport_cancelButton => '取消';

  @override
  String get transfer_pdfExport_dialogTitle => '导出 PDF 潜水日志';

  @override
  String get transfer_pdfExport_exportButton => '导出 PDF';

  @override
  String get transfer_pdfExport_includeCertCards => '包含证书卡片';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle => '将扫描的证书卡片图片添加到 PDF';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => '纸张大小';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Letter';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => '详细';

  @override
  String get transfer_pdfExport_templateDetailedDesc => '包含备注和评分的完整潜水信息';

  @override
  String get transfer_pdfExport_templateHeader => '模板';

  @override
  String get transfer_pdfExport_templateNauiStyle => 'NAUI 样式';

  @override
  String get transfer_pdfExport_templateNauiStyleDesc => '匹配 NAUI 潜水日志格式的布局';

  @override
  String get transfer_pdfExport_templatePadiStyle => 'PADI 样式';

  @override
  String get transfer_pdfExport_templatePadiStyleDesc => '匹配 PADI 潜水日志格式的布局';

  @override
  String get transfer_pdfExport_templateProfessional => '专业';

  @override
  String get transfer_pdfExport_templateProfessionalDesc => '用于验证的签名和印章区域';

  @override
  String transfer_pdfExport_templateSemanticLabel(Object templateName) {
    return '选择 $templateName 模板';
  }

  @override
  String get transfer_pdfExport_templateSimple => '简洁';

  @override
  String get transfer_pdfExport_templateSimpleDesc => '紧凑表格格式，每页显示多次潜水';

  @override
  String get transfer_section_computersSubtitle => '下载从设备';

  @override
  String get transfer_section_computersTitle => '潜水电脑';

  @override
  String get transfer_section_exportSubtitle => 'CSV、UDDF、PDF 日志本';

  @override
  String get transfer_section_exportTitle => '导出';

  @override
  String get transfer_section_importSubtitle => 'CSV、UDDF 文件';

  @override
  String get transfer_section_importTitle => '导入';

  @override
  String get transfer_summary_description => '导入和导出潜水数据';

  @override
  String get transfer_summary_selectSection => '从列表中选择一个部分';

  @override
  String get transfer_summary_title => '传输';

  @override
  String transfer_unknownSection(Object sectionId) {
    return '未知部分: $sectionId';
  }

  @override
  String get trips_appBar_title => '旅行';

  @override
  String get trips_appBar_tripPhotos => '旅行照片';

  @override
  String get trips_detail_action_delete => '删除';

  @override
  String get trips_detail_action_export => '导出';

  @override
  String get trips_detail_appBar_title => '旅行';

  @override
  String get trips_detail_dialog_cancel => '取消';

  @override
  String get trips_detail_dialog_deleteConfirm => '删除';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return '确定要删除「$name」吗？这将移除旅行但保留潜水记录。';
  }

  @override
  String get trips_detail_dialog_deleteTitle => '删除旅行？';

  @override
  String get trips_detail_dives_empty => '此旅行暂无潜水记录';

  @override
  String get trips_detail_dives_errorLoading => '无法加载潜水记录';

  @override
  String get trips_detail_dives_unknownSite => '未知潜水点';

  @override
  String trips_detail_dives_viewAll(Object count) {
    return '查看全部 ($count)';
  }

  @override
  String trips_detail_durationDays(Object days) {
    return '$days 天';
  }

  @override
  String get trips_detail_export_csv_comingSoon => 'CSV 导出即将推出';

  @override
  String get trips_detail_export_csv_subtitle => '此旅行中的所有潜水';

  @override
  String get trips_detail_export_csv_title => '导出为 CSV';

  @override
  String get trips_detail_export_pdf_comingSoon => 'PDF 导出即将推出';

  @override
  String get trips_detail_export_pdf_subtitle => '旅行摘要及潜水详情';

  @override
  String get trips_detail_export_pdf_title => '导出为 PDF';

  @override
  String get trips_detail_label_liveaboard => '船宿';

  @override
  String get trips_detail_label_location => '位置';

  @override
  String get trips_detail_label_resort => '度假村';

  @override
  String get trips_detail_scan_accessDenied => '相册访问被拒绝';

  @override
  String get trips_detail_scan_addDivesFirst => '请先添加潜水以关联照片';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return '关联照片时出错：$error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return '扫描出错: $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return '已关联 $count 照片';
  }

  @override
  String get trips_detail_scan_linkingPhotos => '正在关联照片...';

  @override
  String get trips_detail_sectionTitle_details => '旅行详情';

  @override
  String get trips_detail_sectionTitle_dives => '潜水';

  @override
  String get trips_detail_sectionTitle_notes => '备注';

  @override
  String get trips_detail_sectionTitle_statistics => '旅行统计';

  @override
  String get trips_detail_snackBar_deleted => '旅行已删除';

  @override
  String get trips_detail_stat_avgDepth => '平均深度';

  @override
  String get trips_detail_stat_maxDepth => '最大深度';

  @override
  String get trips_detail_stat_totalBottomTime => '总计底部时间';

  @override
  String get trips_detail_stat_totalDives => '总计潜水';

  @override
  String get trips_detail_tooltip_edit => '编辑旅行';

  @override
  String get trips_detail_tooltip_editShort => '编辑';

  @override
  String get trips_detail_tooltip_moreOptions => '更多选项';

  @override
  String get trips_detail_tooltip_viewOnMap => '在地图上查看';

  @override
  String trips_diveScan_addButton(int count) {
    return '添加 $count 潜水';
  }

  @override
  String trips_diveScan_added(int count) {
    return '已将 $count 次潜水添加到旅行';
  }

  @override
  String get trips_diveScan_cancel => '取消';

  @override
  String trips_diveScan_currentTrip(String tripName) {
    return '当前旅行：$tripName';
  }

  @override
  String get trips_diveScan_deselectAll => '取消全选';

  @override
  String trips_diveScan_error(String error) {
    return '扫描潜水时出错：$error';
  }

  @override
  String get trips_diveScan_findButton => '查找匹配的潜水';

  @override
  String trips_diveScan_groupOtherTrips(int count) {
    return '在其他旅行中（$count）';
  }

  @override
  String trips_diveScan_groupUnassigned(int count) {
    return '未分配（$count）';
  }

  @override
  String get trips_diveScan_noMatches => '未找到匹配的潜水';

  @override
  String get trips_diveScan_selectAll => '全选';

  @override
  String trips_diveScan_subtitle(int count) {
    return '在日期范围内找到 $count 次潜水';
  }

  @override
  String get trips_diveScan_title => '将潜水添加到旅行';

  @override
  String get trips_diveScan_unknownSite => '未知潜水点';

  @override
  String get trips_edit_appBar_add => '添加旅行';

  @override
  String get trips_edit_appBar_edit => '编辑旅行';

  @override
  String get trips_edit_button_add => '添加旅行';

  @override
  String get trips_edit_button_cancel => '取消';

  @override
  String get trips_edit_button_save => '保存';

  @override
  String get trips_edit_button_update => '更新旅行';

  @override
  String get trips_edit_dialog_discard => '丢弃';

  @override
  String get trips_edit_dialog_discardContent => '您有未保存的更改。确定要离开吗?';

  @override
  String get trips_edit_dialog_discardTitle => '丢弃更改？';

  @override
  String get trips_edit_dialog_keepEditing => '继续编辑';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days 天';
  }

  @override
  String get trips_edit_hint_liveaboardName => '例如：MY Blue Force One';

  @override
  String get trips_edit_hint_location => '例如：埃及，红海';

  @override
  String get trips_edit_hint_notes => '关于此旅行的其他备注';

  @override
  String get trips_edit_hint_resortName => '例如：Marsa Shagra';

  @override
  String get trips_edit_hint_tripName => '例如：红海探险 2024';

  @override
  String get trips_edit_label_endDate => '结束日期';

  @override
  String get trips_edit_label_liveaboardName => '船宿名称';

  @override
  String get trips_edit_label_location => '位置';

  @override
  String get trips_edit_label_notes => '备注';

  @override
  String get trips_edit_label_resortName => '度假村名称';

  @override
  String get trips_edit_label_startDate => '开始日期';

  @override
  String get trips_edit_label_tripName => '旅行名称 *';

  @override
  String get trips_edit_sectionTitle_dates => '旅行日期';

  @override
  String get trips_edit_sectionTitle_location => '位置';

  @override
  String get trips_edit_sectionTitle_notes => '备注';

  @override
  String get trips_edit_semanticLabel_save => '保存旅行';

  @override
  String get trips_edit_snackBar_added => '旅行添加成功';

  @override
  String trips_edit_snackBar_errorLoading(Object error) {
    return '加载旅行时出错：$error';
  }

  @override
  String trips_edit_snackBar_errorSaving(Object error) {
    return '保存旅行时出错：$error';
  }

  @override
  String get trips_edit_snackBar_updated => '旅行更新成功';

  @override
  String get trips_edit_validation_nameRequired => '请输入旅行名称';

  @override
  String get trips_gallery_accessDenied => '相册访问被拒绝';

  @override
  String get trips_gallery_addDivesFirst => '请先添加潜水以关联照片';

  @override
  String get trips_gallery_appBar_title => '旅行照片';

  @override
  String trips_gallery_diveSection_photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '照片',
      one: '照片',
    );
    return '$_temp0';
  }

  @override
  String trips_gallery_diveSection_title(Object number, Object site) {
    return '潜水 #$number - $site';
  }

  @override
  String get trips_gallery_empty_subtitle => '点击相机图标以扫描您的相册';

  @override
  String get trips_gallery_empty_title => '此旅行暂无照片';

  @override
  String trips_gallery_errorLinking(Object error) {
    return '关联照片时出错：$error';
  }

  @override
  String trips_gallery_errorScanning(Object error) {
    return '扫描出错: $error';
  }

  @override
  String trips_gallery_error_loading(Object error) {
    return '加载照片时出错：$error';
  }

  @override
  String trips_gallery_linkedPhotos(Object count) {
    return '已关联 $count 照片';
  }

  @override
  String get trips_gallery_linkingPhotos => '正在关联照片...';

  @override
  String get trips_gallery_tooltip_scan => '扫描设备图库';

  @override
  String get trips_gallery_tripNotFound => '找不到该旅行';

  @override
  String get trips_list_button_retry => '重试';

  @override
  String get trips_list_empty_button => '添加您的第一次旅行';

  @override
  String get trips_list_empty_filtered_subtitle => '尝试调整或清除您的筛选条件';

  @override
  String get trips_list_empty_filtered_title => '没有匹配筛选条件的旅行';

  @override
  String get trips_list_empty_subtitle => '创建旅行以按目的地组织您的潜水';

  @override
  String get trips_list_empty_title => '尚未添加旅行';

  @override
  String trips_list_error_loading(Object error) {
    return '加载旅行时出错：$error';
  }

  @override
  String get trips_list_fab_addTrip => '添加旅行';

  @override
  String get trips_list_filters_clearAll => '清除全部';

  @override
  String get trips_list_sort_title => '排序旅行';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count 次潜水';
  }

  @override
  String get trips_list_tooltip_addTrip => '添加旅行';

  @override
  String get trips_list_tooltip_search => '搜索旅行';

  @override
  String get trips_list_tooltip_sort => '排序';

  @override
  String get trips_photos_empty_scanButton => '扫描设备图库';

  @override
  String get trips_photos_empty_title => '暂无照片';

  @override
  String get trips_photos_error_loading => '加载照片时出错';

  @override
  String trips_photos_moreIndicator(Object count) {
    return '+$count';
  }

  @override
  String trips_photos_moreIndicator_semanticLabel(Object count) {
    return '$count 更多照片';
  }

  @override
  String get trips_photos_sectionTitle => '照片';

  @override
  String get trips_photos_tooltip_scan => '扫描设备图库';

  @override
  String get trips_photos_viewAll => '查看全部';

  @override
  String get trips_picker_clearTooltip => '清除选择';

  @override
  String get trips_picker_empty_createButton => '创建旅行';

  @override
  String get trips_picker_empty_title => '暂无旅行';

  @override
  String trips_picker_error(Object error) {
    return '加载旅行时出错：$error';
  }

  @override
  String get trips_picker_hint => '点击选择旅行';

  @override
  String get trips_picker_newTrip => '新建旅行';

  @override
  String get trips_picker_noSelection => '无旅行已选择';

  @override
  String get trips_picker_sheetTitle => '选择旅行';

  @override
  String trips_picker_suggestedPrefix(Object name) {
    return '建议：$name';
  }

  @override
  String get trips_picker_suggestedUse => '使用';

  @override
  String get trips_search_empty_hint => '按名称、地点或度假村搜索';

  @override
  String get trips_search_fieldLabel => '搜索旅行...';

  @override
  String trips_search_noResults(Object query) {
    return '未找到「$query」的旅行';
  }

  @override
  String get trips_search_tooltip_back => '返回';

  @override
  String get trips_search_tooltip_clear => '清除搜索';

  @override
  String get trips_summary_header_subtitle => '从列表中选择一个旅行以查看详情';

  @override
  String get trips_summary_header_title => '旅行';

  @override
  String get trips_summary_overview_title => '概览';

  @override
  String get trips_summary_quickActions_add => '添加旅行';

  @override
  String get trips_summary_quickActions_title => '快捷操作';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date • $count 次潜水';
  }

  @override
  String get trips_summary_recentTitle => '近期旅行';

  @override
  String get trips_summary_stat_daysDiving => '潜水天数';

  @override
  String get trips_summary_stat_liveaboards => '船宿';

  @override
  String get trips_summary_stat_totalDives => '总计潜水';

  @override
  String get trips_summary_stat_totalTrips => '总计旅行';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date • $days 天后';
  }

  @override
  String get trips_summary_upcomingTitle => '即将到来';

  @override
  String get trips_type_shore => '岸潜';

  @override
  String get trips_type_liveaboard => '船宿';

  @override
  String get trips_type_resort => '度假村';

  @override
  String get trips_type_dayTrip => '天旅行';

  @override
  String get trips_edit_label_tripType => '旅行类型';

  @override
  String get trips_edit_sectionTitle_vessel => '船只详情';

  @override
  String get trips_edit_label_vesselName => '船只名称 *';

  @override
  String get trips_edit_hint_vesselName => '例如：Ocean Explorer';

  @override
  String get trips_edit_label_operatorName => '运营商/包船';

  @override
  String get trips_edit_hint_operatorName => '例如：Red Sea Divers';

  @override
  String get trips_edit_label_vesselType => '船只类型';

  @override
  String get trips_edit_label_cabinType => '舱房类型';

  @override
  String get trips_edit_hint_cabinType => '例如，豪华双人舱';

  @override
  String get trips_edit_label_capacity => '乘客容量';

  @override
  String get trips_edit_sectionTitle_embarkDisembark => '上船/下船';

  @override
  String get trips_edit_label_embarkPort => '登船港口';

  @override
  String get trips_edit_hint_embarkPort => '例如，胡尔格达码头';

  @override
  String get trips_edit_label_disembarkPort => '下船港口';

  @override
  String get trips_edit_hint_disembarkPort => '例如，胡尔格达码头';

  @override
  String get trips_edit_validation_vesselRequired => '船宿旅行需要填写船只名称';

  @override
  String get trips_detail_tab_overview => '概览';

  @override
  String get trips_detail_tab_itinerary => '行程';

  @override
  String get trips_detail_tab_photos => '照片';

  @override
  String get trips_detail_tab_dives => '潜水';

  @override
  String get trips_detail_sectionTitle_vessel => '船只';

  @override
  String get trips_detail_label_operator => '运营商';

  @override
  String get trips_detail_label_vesselType => '类型';

  @override
  String get trips_detail_label_cabin => '舱房';

  @override
  String get trips_detail_label_capacity => '容量';

  @override
  String get trips_detail_label_embark => '登船';

  @override
  String get trips_detail_label_disembark => '离船';

  @override
  String get trips_detail_stat_divesPerDay => '每日潜水次数';

  @override
  String get trips_detail_stat_diveDays => '潜水天数';

  @override
  String get trips_detail_stat_seaDays => '出海天数';

  @override
  String get trips_detail_stat_sitesVisited => '已访问潜水点';

  @override
  String get trips_detail_stat_speciesSeen => '已发现物种';

  @override
  String get trips_detail_sectionTitle_dailyBreakdown => '每日分解';

  @override
  String get trips_breakdown_column_day => '天';

  @override
  String get trips_breakdown_column_type => '类型';

  @override
  String get trips_breakdown_column_dives => '潜水';

  @override
  String get trips_breakdown_column_bottomTime => '底部时间';

  @override
  String get trips_breakdown_column_sites => '潜水点';

  @override
  String get trips_detail_sectionTitle_voyageMap => '航行路线';

  @override
  String trips_itinerary_dayLabel(int dayNumber) {
    return '第 $dayNumber 天';
  }

  @override
  String trips_itinerary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次潜水',
      one: '1 次潜水',
    );
    return '$_temp0';
  }

  @override
  String get trips_itinerary_editDay => '编辑日程';

  @override
  String get trips_itinerary_dayType_label => '日程类型';

  @override
  String get trips_itinerary_portName_label => '港口/锚地';

  @override
  String get trips_itinerary_notes_label => '备注';

  @override
  String get trips_itinerary_noDives => '无潜水';

  @override
  String get trips_vesselType_catamaran => '双体船';

  @override
  String get trips_vesselType_motorYacht => '马达游艇';

  @override
  String get trips_vesselType_sailingYacht => '帆船游艇';

  @override
  String get trips_vesselType_other => '其他';

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
  String get units_profileMetric_min => '分';

  @override
  String get units_profileMetric_percent => '%';

  @override
  String get units_sac_litersPerMin => 'L/分钟';

  @override
  String get units_sac_pressurePerMin => '压力/分';

  @override
  String get units_temperature_celsius => 'C';

  @override
  String get units_temperature_fahrenheit => 'F';

  @override
  String get units_timeFormat_twelveHour => '12-小时';

  @override
  String get units_timeFormat_twentyFourHour => '24-小时';

  @override
  String get units_volume_cubicFeet => 'cuft';

  @override
  String get units_volume_liters => 'L';

  @override
  String get units_weight_kilograms => 'kg';

  @override
  String get units_weight_pounds => 'lbs';

  @override
  String get universalImport_action_consolidate => '作为附加潜水电脑合并';

  @override
  String get universalImport_action_continue => '继续';

  @override
  String get universalImport_action_deselectAll => '取消全选';

  @override
  String get universalImport_action_done => '完成';

  @override
  String get universalImport_action_import => '导入';

  @override
  String get universalImport_action_selectAll => '全选';

  @override
  String get universalImport_action_changeFile => '更换文件';

  @override
  String get universalImport_action_selectFile => '选择文件';

  @override
  String get universalImport_description_supportedFormats =>
      '选择一个潜水日志文件进行导入。支持的格式包括 CSV、UDDF、Subsurface XML 和 Garmin FIT。';

  @override
  String get universalImport_error_unsupportedFormat =>
      '暂不支持此格式。请导出为 UDDF 或 CSV。';

  @override
  String get universalImport_label_columnMapping => '列映射';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '已映射 $mapped/$total 列';
  }

  @override
  String get universalImport_label_detecting => '检测中...';

  @override
  String universalImport_label_diveNumber(Object number) {
    return '潜水 #$number';
  }

  @override
  String get universalImport_label_duplicate => '重复';

  @override
  String universalImport_label_duplicatesFound(Object count) {
    return '发现 $count 条重复记录并已自动取消选择。';
  }

  @override
  String get universalImport_label_importComplete => '导入完成';

  @override
  String get universalImport_label_importing => '正在导入';

  @override
  String get universalImport_label_importingEllipsis => '正在导入...';

  @override
  String universalImport_label_importingProgress(Object current, Object total) {
    return '正在导入 $current/$total';
  }

  @override
  String universalImport_label_percentMatch(Object percent) {
    return '$percent% 匹配';
  }

  @override
  String get universalImport_label_possibleMatch => '可能匹配';

  @override
  String get universalImport_label_selectCorrectSource => '不正确？请选择正确的来源：';

  @override
  String universalImport_label_selected(Object count) {
    return '$count 已选择';
  }

  @override
  String get universalImport_label_skip => '跳过';

  @override
  String universalImport_label_taggedAs(Object tag) {
    return '标记为：$tag';
  }

  @override
  String get universalImport_label_unknownDate => '未知日期';

  @override
  String get universalImport_label_unnamed => '未命名';

  @override
  String universalImport_label_xOfY(Object current, Object total) {
    return '$current/$total';
  }

  @override
  String universalImport_label_xOfYSelected(Object selected, Object total) {
    return '已选择 $selected/$total';
  }

  @override
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  ) {
    return '已选择 $selected/$total 个$entityType';
  }

  @override
  String universalImport_semantics_importError(Object error) {
    return '导入错误：$error';
  }

  @override
  String universalImport_semantics_importProgress(Object percent) {
    return '导入进度：$percent%';
  }

  @override
  String universalImport_semantics_itemsSelected(Object count) {
    return '$count 项目已选择为导入';
  }

  @override
  String get universalImport_semantics_possibleDuplicate => '可能重复';

  @override
  String get universalImport_semantics_probableDuplicate => '可能重复';

  @override
  String universalImport_semantics_sourceDetected(Object description) {
    return '检测到来源：$description';
  }

  @override
  String universalImport_semantics_sourceUncertain(Object description) {
    return '来源不确定：$description';
  }

  @override
  String universalImport_semantics_toggleSelection(Object name) {
    return '切换 $name 的选择';
  }

  @override
  String get universalImport_step_import => '导入';

  @override
  String get universalImport_step_map => '映射';

  @override
  String get universalImport_step_review => '审查';

  @override
  String get universalImport_step_select => '选择';

  @override
  String get universalImport_title => '导入数据';

  @override
  String get universalImport_tooltip_closeWizard => '关闭导入向导';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return '基础（$suitType）：$weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return '体重调整：+$adjustment kg';
  }

  @override
  String get weightCalc_suit_drysuit => '干衣';

  @override
  String get weightCalc_suit_none => '无防寒服';

  @override
  String get weightCalc_suit_rashguard => '仅防晒衣';

  @override
  String get weightCalc_suit_semidry => '半干衣';

  @override
  String get weightCalc_suit_shorty3mm => '3mm 短款湿衣';

  @override
  String get weightCalc_suit_wetsuit3mm => '3mm 全身湿衣';

  @override
  String get weightCalc_suit_wetsuit5mm => '5mm 湿衣';

  @override
  String get weightCalc_suit_wetsuit7mm => '7mm 湿衣';

  @override
  String weightCalc_tankLine(Object tankMaterial, Object adjustment) {
    return '气瓶（$tankMaterial）：$adjustment kg';
  }

  @override
  String get weightCalc_title => '配重计算：';

  @override
  String weightCalc_total(Object total) {
    return '总计：$total kg';
  }

  @override
  String weightCalc_waterLine(Object waterType, Object adjustment) {
    return '水型（$waterType）：$adjustment kg';
  }

  @override
  String divePlanner_label_resultsWithWarnings(Object count) {
    return '结果，$count 个警告';
  }

  @override
  String tides_semantic_tideCycle(Object state, Object height) {
    return '潮汐周期，状态：$state，高度：$height';
  }

  @override
  String get tides_label_agoSuffix => '前';

  @override
  String get tides_label_fromNowSuffix => '后';

  @override
  String get certifications_card_issued => '签发日期';

  @override
  String certifications_certificate_cardNumber(Object number) {
    return '卡号：$number';
  }

  @override
  String get certifications_certificate_footer => '正式水肺潜水证书';

  @override
  String get certifications_certificate_hasCompletedTraining => '已完成以下培训';

  @override
  String certifications_certificate_instructor(Object name) {
    return '教练：$name';
  }

  @override
  String certifications_certificate_issued(Object date) {
    return '签发日期：$date';
  }

  @override
  String get certifications_certificate_thisCertifies => '特此证明';

  @override
  String get diveComputer_discovery_chooseDifferentDevice => '选择其他设备';

  @override
  String get diveComputer_discovery_computer => '潜水电脑';

  @override
  String get diveComputer_discovery_connectAndDownload => '连接并下载';

  @override
  String get diveComputer_discovery_connectingToDevice => '正在连接设备...';

  @override
  String diveComputer_discovery_deviceNameHint(Object model) {
    return '例如，我的 $model';
  }

  @override
  String get diveComputer_discovery_deviceNameLabel => '设备名称';

  @override
  String get diveComputer_discovery_exitDialogCancel => '取消';

  @override
  String get diveComputer_discovery_exitDialogConfirm => '退出';

  @override
  String get diveComputer_discovery_exitDialogContent => '确定要退出吗？您的进度将丢失。';

  @override
  String get diveComputer_discovery_exitDialogTitle => '退出设置？';

  @override
  String get diveComputer_discovery_exitTooltip => '退出设置';

  @override
  String get diveComputer_discovery_noDeviceSelected => '未选择设备';

  @override
  String get diveComputer_discovery_pleaseWaitConnection => '请等待建立连接';

  @override
  String get diveComputer_discovery_recognizedDevice => '已识别设备';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      '此设备在我们的支持设备库中。潜水下载应能自动进行。';

  @override
  String get diveComputer_discovery_stepConnect => '连接';

  @override
  String get diveComputer_discovery_stepDone => '完成';

  @override
  String get diveComputer_discovery_stepDownload => '下载';

  @override
  String get diveComputer_discovery_stepScan => '扫描';

  @override
  String get diveComputer_discovery_titleComplete => '完成';

  @override
  String get diveComputer_discovery_titleConfirmDevice => '确认设备';

  @override
  String get diveComputer_discovery_titleConnecting => '正在连接';

  @override
  String get diveComputer_discovery_titleDownloading => '正在下载';

  @override
  String get diveComputer_discovery_titleFindDevice => '查找设备';

  @override
  String get diveComputer_discovery_unknownDevice => '未知设备';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      '此设备不在我们的设备库中。我们将尝试连接，但下载可能无法正常工作。';

  @override
  String get diveComputer_discovery_usbInstructions =>
      '通过 USB 线连接您的潜水电脑，然后在下方选择。';

  @override
  String diveComputer_discovery_usbNoResults(String query) {
    return '未找到与「$query」匹配的设备';
  }

  @override
  String get diveComputer_discovery_usbSearchHint => '按制造商或型号搜索...';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... 以及 $count 次更多';
  }

  @override
  String get diveComputer_downloadStep_cancel => '取消';

  @override
  String get diveComputer_downloadStep_cancelled => '下载已取消';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadFailed => '下载失败';

  @override
  String get diveComputer_downloadStep_downloadedDives => '已下载的潜水';

  @override
  String diveComputer_downloadStep_durationMin(Object duration) {
    return '$duration 分钟';
  }

  @override
  String get diveComputer_downloadStep_errorOccurred => '发生错误';

  @override
  String diveComputer_downloadStep_errorSemanticLabel(Object error) {
    return '下载错误：$error';
  }

  @override
  String diveComputer_downloadStep_percentAccessibility(Object percent) {
    return '，$percent 百分比';
  }

  @override
  String get diveComputer_downloadStep_preparing => '准备中...';

  @override
  String diveComputer_downloadStep_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String diveComputer_downloadStep_progressSemanticLabel(
    Object status,
    Object percent,
  ) {
    return '下载进度：$status$percent';
  }

  @override
  String get diveComputer_downloadStep_retry => '重试';

  @override
  String get diveComputer_download_cancel => '取消';

  @override
  String get diveComputer_download_closeTooltip => '关闭';

  @override
  String get diveComputer_download_computerNotFound => '未找到潜水电脑';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return '未找到设备。请确保您的 $name 在附近并处于传输模式。';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle => '未找到设备';

  @override
  String get diveComputer_download_divesUpdated => '潜水已更新';

  @override
  String get diveComputer_download_done => '完成';

  @override
  String get diveComputer_download_downloadedDives => '已下载的潜水';

  @override
  String get diveComputer_download_duplicatesSkipped => '已跳过重复';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration 分钟';
  }

  @override
  String get diveComputer_download_errorOccurred => '发生错误';

  @override
  String get diveComputer_download_noSerialPortsFound =>
      '未找到 USB 串行端口。潜水电脑是否已连接并开机？';

  @override
  String diveComputer_download_serialConnectFailedWithDetails(Object details) {
    return '无法连接到潜水电脑。\n\n诊断详情（请分享给开发人员）：\n$details';
  }

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return '错误： $error';
  }

  @override
  String get diveComputer_download_goBack => '返回';

  @override
  String get diveComputer_download_importFailed => '导入失败';

  @override
  String get diveComputer_download_importResults => '导入结果';

  @override
  String get diveComputer_download_importedDives => '已导入的潜水';

  @override
  String diveComputer_download_importingCountDives(int count) {
    return '正在导入 $count 次潜水...';
  }

  @override
  String diveComputer_download_importingCountNewDives(int count) {
    return '正在导入 $count 次新潜水...';
  }

  @override
  String get diveComputer_download_newDivesImported => '新潜水已导入';

  @override
  String get diveComputer_download_newDivesOnlySubtitle => '仅下载自上次同步以来新增的潜水';

  @override
  String get diveComputer_download_newDivesOnlyTitle => '仅下载新潜水';

  @override
  String get diveComputer_download_preparing => '准备中...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_retry => '重试';

  @override
  String diveComputer_download_scanError(Object error) {
    return '扫描错误：$error';
  }

  @override
  String diveComputer_download_searchingForDevice(Object name) {
    return '正在搜索 $name...';
  }

  @override
  String get diveComputer_download_searchingInstructions => '请确保设备在附近并处于传输模式';

  @override
  String get diveComputer_download_title => '下载潜水记录';

  @override
  String get diveComputer_download_tryAgain => '重试';

  @override
  String get diveComputer_download_upToDate => '未发现新潜水——您的日志已是最新';

  @override
  String get diveComputer_list_addComputer => '添加潜水电脑';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return '潜水电脑: $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count 次潜水';
  }

  @override
  String get diveComputer_list_downloadTooltip => '下载潜水记录';

  @override
  String get diveComputer_list_emptyMessage => '连接您的潜水电脑，将潜水数据直接下载到应用中。';

  @override
  String get diveComputer_list_emptyTitle => '暂无潜水电脑';

  @override
  String get diveComputer_list_findComputers => '查找潜水电脑';

  @override
  String get diveComputer_list_helpBluetooth => '• 低功耗蓝牙（大多数现代电脑）';

  @override
  String get diveComputer_list_helpBluetoothClassic => '• 经典蓝牙（较旧型号）';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater、Suunto、Garmin、Mares、Scubapro、Oceanic、Aqualung、Cressi 及 50 多种其他型号。';

  @override
  String get diveComputer_list_helpBrandsTitle => '支持的品牌';

  @override
  String get diveComputer_list_helpConnectionsTitle => '支持的连接方式';

  @override
  String get diveComputer_list_helpDialogTitle => '潜水电脑帮助';

  @override
  String get diveComputer_list_helpDismiss => '知道了';

  @override
  String get diveComputer_list_helpTip1 => '• 确保您的电脑处于传输模式';

  @override
  String get diveComputer_list_helpTip2 => '• 下载期间保持设备靠近';

  @override
  String get diveComputer_list_helpTip3 => '• 确保蓝牙已开启';

  @override
  String get diveComputer_list_helpTipsTitle => '提示';

  @override
  String get diveComputer_list_helpTooltip => '帮助';

  @override
  String get diveComputer_list_helpUsb => '• USB（仅桌面端）';

  @override
  String get diveComputer_list_loadFailed => '加载潜水电脑失败';

  @override
  String get diveComputer_list_retry => '重试';

  @override
  String get diveComputer_list_title => '潜水电脑';

  @override
  String get diveComputer_summary_diveComputer => '潜水电脑';

  @override
  String diveComputer_summary_divesDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次潜水',
      one: '次潜水',
    );
    return '已下载 $count $_temp0';
  }

  @override
  String get diveComputer_summary_done => '完成';

  @override
  String get diveComputer_summary_imported => '已导入';

  @override
  String diveComputer_summary_semanticLabel(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次潜水',
      one: '次潜水',
    );
    return '从 $name 下载了 $count $_temp0';
  }

  @override
  String get diveComputer_summary_skippedDuplicates => '已跳过（重复）';

  @override
  String get diveComputer_summary_title => '下载完成！';

  @override
  String get diveComputer_summary_updated => '已更新';

  @override
  String get diveComputer_summary_viewDives => '查看潜水';

  @override
  String get diveImport_alreadyImported => '已导入';

  @override
  String get diveImport_avgHR => '平均心率';

  @override
  String get diveImport_back => '返回';

  @override
  String get diveImport_deselectAll => '取消全选';

  @override
  String get diveImport_divesImported => '已导入潜水记录';

  @override
  String get diveImport_divesMerged => '已合并潜水记录';

  @override
  String get diveImport_divesSkipped => '已跳过潜水记录';

  @override
  String get diveImport_done => '完成';

  @override
  String get diveImport_duration => '时长';

  @override
  String get diveImport_error => '错误';

  @override
  String get diveImport_fit_closeTooltip => '关闭 FIT 导入';

  @override
  String get diveImport_fit_noDivesDescription =>
      '选择一个或多个从 Garmin Connect 导出或从 Garmin Descent 设备复制的 .fit 文件。';

  @override
  String get diveImport_fit_noDivesLoaded => '未加载潜水记录';

  @override
  String diveImport_fit_parsed(int diveCount, int fileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: '文件',
      one: '文件',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '潜水',
      one: '潜水',
    );
    return '从 $fileCount 个$_temp0中解析了 $diveCount 次$_temp1';
  }

  @override
  String diveImport_fit_parsedWithSkipped(
    int diveCount,
    int fileCount,
    Object skippedCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: '文件',
      one: '文件',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '潜水',
      one: '潜水',
    );
    return '从 $fileCount 个$_temp0中解析了 $diveCount 次$_temp1（跳过 $skippedCount 次）';
  }

  @override
  String get diveImport_fit_parsing => '正在解析...';

  @override
  String get diveImport_fit_selectFiles => '选择 FIT 文件';

  @override
  String get diveImport_fit_title => '从 FIT 文件导入';

  @override
  String get diveImport_healthkit_accessDescription =>
      'Submersion 使用 Apple HealthKit 读取水下潜水运动数据，包括深度、持续时间、水温和心率，以创建详细的潜水日志。';

  @override
  String get diveImport_healthkit_accessRequired => 'Apple HealthKit 访问必填';

  @override
  String get diveImport_healthkit_attribution => '提供支持按 Apple HealthKit';

  @override
  String get diveImport_healthkit_closeTooltip => '关闭 Apple Watch 导入';

  @override
  String get diveImport_healthkit_dataUsage =>
      '从 Apple Health 读取水下潜水活动，包括深度、持续时间、水温和心率。此数据存储在您的本地潜水日志中，绝不会与第三方共享。';

  @override
  String get diveImport_healthkit_dateFrom => '从';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return '$label日期选择器';
  }

  @override
  String get diveImport_healthkit_dateTo => '到';

  @override
  String get diveImport_healthkit_fetchDives => '获取潜水记录';

  @override
  String get diveImport_healthkit_fetching => '获取中...';

  @override
  String get diveImport_healthkit_grantAccess => '继续';

  @override
  String get diveImport_healthkit_noDivesFound => '未找到潜水记录';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      '在所选日期范围内未找到水下潜水活动。';

  @override
  String get diveImport_healthkit_notAvailable => '不可用';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'Apple Watch 导入仅在 iOS 和 macOS 设备上可用。';

  @override
  String get diveImport_healthkit_permissionCheckFailed => '权限检查失败';

  @override
  String get diveImport_healthkit_title => '从 Apple Watch 导入';

  @override
  String get diveImport_healthkit_watchTitle => '从手表导入';

  @override
  String get diveImport_import => '导入';

  @override
  String get diveImport_importComplete => '导入完成';

  @override
  String get diveImport_likelyDuplicate => '可能重复';

  @override
  String get diveImport_maxDepth => '最大深度';

  @override
  String get diveImport_newDive => '新潜水';

  @override
  String get diveImport_next => '下一步';

  @override
  String get diveImport_possibleDuplicate => '可能重复';

  @override
  String get diveImport_reviewSelectedDives => '审核已选潜水记录';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: '，$possibleCount 条可能重复',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: '，$skipCount 条将被跳过',
      zero: '',
    );
    return '$newCount 条新记录$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => '全选';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count 已选择';
  }

  @override
  String get diveImport_sourceGarmin => 'Garmin';

  @override
  String get diveImport_sourceSuunto => 'Suunto';

  @override
  String get diveImport_sourceUDDF => 'UDDF';

  @override
  String get diveImport_sourceWatch => '手表';

  @override
  String get diveImport_step_done => '完成';

  @override
  String get diveImport_step_review => '审查';

  @override
  String get diveImport_step_select => '选择';

  @override
  String get diveImport_temp => '温度';

  @override
  String get diveImport_toggleDiveSelection => '切换潜水记录选择';

  @override
  String get diveImport_uddf_buddies => '潜伴';

  @override
  String get diveImport_uddf_certifications => '证书';

  @override
  String get diveImport_uddf_closeTooltip => '关闭 UDDF 导入';

  @override
  String get diveImport_uddf_diveCenters => '潜水中心';

  @override
  String get diveImport_uddf_diveTypes => '潜水类型';

  @override
  String get diveImport_uddf_dives => '潜水';

  @override
  String get diveImport_uddf_duplicate => '重复';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return '发现 $count 条重复记录并已自动取消选择。';
  }

  @override
  String get diveImport_uddf_equipment => '装备';

  @override
  String get diveImport_uddf_equipmentSets => '装备套装';

  @override
  String diveImport_uddf_importProgress(Object current, Object total) {
    return '$current/$total';
  }

  @override
  String get diveImport_uddf_importing => '正在导入...';

  @override
  String get diveImport_uddf_likelyDuplicate => '可能重复';

  @override
  String get diveImport_uddf_noFileDescription =>
      '选择一个从其他潜水日志应用导出的 .uddf 或 .xml 文件。';

  @override
  String get diveImport_uddf_noFileSelected => '未选择文件';

  @override
  String get diveImport_uddf_parsing => '正在解析...';

  @override
  String get diveImport_uddf_possibleDuplicate => '可能重复';

  @override
  String get diveImport_uddf_selectFile => '选择 UDDF 文件';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '已选择 $selected/$total';
  }

  @override
  String get diveImport_uddf_sites => '潜水点';

  @override
  String get diveImport_uddf_stepImport => '导入';

  @override
  String get diveImport_uddf_tabBuddies => '潜伴';

  @override
  String get diveImport_uddf_tabCenters => '中心';

  @override
  String get diveImport_uddf_tabCerts => '证书';

  @override
  String get diveImport_uddf_tabCourses => '课程';

  @override
  String get diveImport_uddf_tabDives => '潜水';

  @override
  String get diveImport_uddf_tabEquipment => '装备';

  @override
  String get diveImport_uddf_tabSets => '集合';

  @override
  String get diveImport_uddf_tabSites => '潜水点';

  @override
  String get diveImport_uddf_tabTags => '标签';

  @override
  String get diveImport_uddf_tabTrips => '旅行';

  @override
  String get diveImport_uddf_tabTypes => '类型';

  @override
  String get diveImport_uddf_tags => '标签';

  @override
  String get diveImport_uddf_title => '从 UDDF 导入';

  @override
  String get diveImport_uddf_toggleDiveSelection => '切换潜水记录选择';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return '切换 $name 的选择';
  }

  @override
  String get diveImport_uddf_trips => '旅行';

  @override
  String get divePlanner_segmentEditor_addTitle => '添加段落';

  @override
  String divePlanner_segmentEditor_ascentRate(Object unit) {
    return '上升速率 ($unit/分钟)';
  }

  @override
  String divePlanner_segmentEditor_descentRate(Object unit) {
    return '下降速率 ($unit/分钟)';
  }

  @override
  String get divePlanner_segmentEditor_duration => '时长 (分钟)';

  @override
  String get divePlanner_segmentEditor_editTitle => '编辑段落';

  @override
  String divePlanner_segmentEditor_endDepth(Object unit) {
    return '终止深度 ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_gasSwitchTime => '气体切换时间';

  @override
  String get divePlanner_segmentEditor_segmentType => '段落类型';

  @override
  String divePlanner_segmentEditor_startDepth(Object unit) {
    return '起始深度 ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_tankGas => '气瓶 / 气体';

  @override
  String get divePlanner_segmentList_addSegment => '添加段落';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return '上升 $startDepth → $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return '底部 $depth 停留 $minutes 分钟';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return '减压 $depth 停留 $minutes 分钟';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => '删除段落';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return '下降 $startDepth → $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => '编辑段落';

  @override
  String get divePlanner_segmentList_emptyMessage => '手动添加段落或创建快速计划';

  @override
  String get divePlanner_segmentList_emptyTitle => '尚无段落';

  @override
  String divePlanner_segmentList_gasSwitch(Object gasName) {
    return '切换气体至 $gasName';
  }

  @override
  String get divePlanner_segmentList_quickPlan => '快捷计划';

  @override
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes) {
    return '安全停留 $depth 停留 $minutes 分钟';
  }

  @override
  String get divePlanner_segmentList_title => '潜水分段';

  @override
  String get divePlanner_segmentType_ascent => '上升';

  @override
  String get divePlanner_segmentType_bottomTime => '底部时间';

  @override
  String get divePlanner_segmentType_decoStop => '减压停留';

  @override
  String get divePlanner_segmentType_descent => '下降';

  @override
  String get divePlanner_segmentType_gasSwitch => '气体切换';

  @override
  String get divePlanner_segmentType_safetyStop => '安全停留';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      '最低气量是在与潜伴共用气源进行紧急上升时所需的最低气体储备。\n\n• 使用应激耗气率（正常的 2-3 倍）\n• 假设两位潜水员共用一个气瓶\n• 启用时包含安全停留\n\n务必在到达最低气量之前折返！';

  @override
  String get gasCalculators_rockBottom_aboutTitle => '关于最低气量';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired => '上升气体必填';

  @override
  String get gasCalculators_rockBottom_ascentRate => '上升速率';

  @override
  String gasCalculators_rockBottom_ascentTimeToDepth(
    Object depth,
    Object unit,
  ) {
    return '上升时间到 $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_ascentTimeToSurface => '上升时间到水面';

  @override
  String get gasCalculators_rockBottom_buddySac => '潜伴 SAC';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac => '合计应激耗气率';

  @override
  String get gasCalculators_rockBottom_emergencyAscentBreakdown => '紧急上升分解';

  @override
  String get gasCalculators_rockBottom_emergencyScenario => '紧急情况场景';

  @override
  String get gasCalculators_rockBottom_includeSafetyStop => '包含安全停留';

  @override
  String get gasCalculators_rockBottom_maximumDepth => '最大深度';

  @override
  String get gasCalculators_rockBottom_minimumReserve => '最小储备';

  @override
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  ) {
    return '最低储备量：$pressure $pressureUnit，$volume $volumeUnit。在剩余 $pressure $pressureUnit 时折返';
  }

  @override
  String gasCalculators_rockBottom_safetyStopDuration(
    Object depth,
    Object unit,
  ) {
    return '在 $depth$unit 处 3 分钟';
  }

  @override
  String gasCalculators_rockBottom_safetyStopGas(Object depth, Object unit) {
    return '安全停留气量（在 $depth$unit 处 3 分钟）';
  }

  @override
  String get gasCalculators_rockBottom_stressedSacHint => '使用较高的耗气率以应对紧急情况下的压力';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => '应激耗气率';

  @override
  String get gasCalculators_rockBottom_tankSize => '气瓶大小';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded => '所需总储备量';

  @override
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  ) {
    return '在剩余 $pressure $pressureUnit 时折返';
  }

  @override
  String get gasCalculators_rockBottom_yourSac => '您的 SAC';

  @override
  String get maps_heatMap_hide => '隐藏热力图';

  @override
  String get maps_heatMap_overlayOff => '热力图叠加层已关闭';

  @override
  String get maps_heatMap_overlayOn => '热力图叠加层已开启';

  @override
  String get maps_heatMap_show => '显示热力图';

  @override
  String get maps_offline_bounds => '范围';

  @override
  String maps_offline_cacheHitRateAccessibility(Object rate) {
    return '缓存命中率：$rate%';
  }

  @override
  String get maps_offline_cacheHits => '缓存命中';

  @override
  String get maps_offline_cacheMisses => '缓存未命中';

  @override
  String get maps_offline_cacheStatistics => '缓存统计';

  @override
  String get maps_offline_cancelDownload => '取消下载';

  @override
  String get maps_offline_clearAll => '清除全部';

  @override
  String get maps_offline_clearAllCache => '清除所有缓存';

  @override
  String get maps_offline_clearAllCacheMessage => '删除所有已下载的地图区域和缓存瓦片吗？';

  @override
  String get maps_offline_clearAllCacheTitle => '清除所有缓存？';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return '这将删除 $count 个瓦片（$size）。';
  }

  @override
  String get maps_offline_created => '已创建';

  @override
  String maps_offline_deleteRegion(Object name) {
    return '删除 $name 区域';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return '删除 \"$name\" 及其 $count 个缓存瓦片吗？\n\n这将释放 $size 的存储空间。';
  }

  @override
  String get maps_offline_deleteRegionTitle => '删除地区?';

  @override
  String get maps_offline_downloadedRegions => '已下载区域';

  @override
  String maps_offline_downloading(Object regionName) {
    return '正在下载：$regionName';
  }

  @override
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  ) {
    return '正在下载 $regionName，已完成 $percent%，$downloaded/$total 个瓦片';
  }

  @override
  String maps_offline_error(Object error) {
    return '错误： $error';
  }

  @override
  String maps_offline_errorLoadingStats(Object error) {
    return '加载统计出错：$error';
  }

  @override
  String maps_offline_failedTiles(Object count) {
    return '$count 失败';
  }

  @override
  String maps_offline_hitRate(Object rate) {
    return '命中速率: $rate%';
  }

  @override
  String get maps_offline_lastAccessed => '上次访问';

  @override
  String get maps_offline_noRegions => '没有离线区域';

  @override
  String get maps_offline_noRegionsDescription => '从潜水点详情页面下载地图区域，以便离线使用地图。';

  @override
  String get maps_offline_refresh => '刷新';

  @override
  String get maps_offline_region => '地区';

  @override
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size | $count 个图块 | 缩放 $minZoom-$maxZoom';
  }

  @override
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size，$count 个图块，缩放 $minZoom 至 $maxZoom';
  }

  @override
  String get maps_offline_size => '尺寸';

  @override
  String get maps_offline_tiles => '瓦片';

  @override
  String maps_offline_tilesPerSecond(Object rate) {
    return '$rate 瓦片/秒';
  }

  @override
  String maps_offline_tilesProgress(Object downloaded, Object total) {
    return '$downloaded / $total 个瓦片';
  }

  @override
  String get maps_offline_title => '离线地图';

  @override
  String get maps_offline_zoomRange => '缩放范围';

  @override
  String get maps_regionSelector_dragToAdjust => '拖动以调整选区';

  @override
  String get maps_regionSelector_dragToSelect => '在地图上拖动以选择区域';

  @override
  String get maps_regionSelector_selectRegion => '在地图上选择区域';

  @override
  String get maps_regionSelector_selectRegionButton => '选择地区';

  @override
  String get tankPresets_addPreset => '添加气瓶预设';

  @override
  String get tankPresets_builtInPresets => '内置预设';

  @override
  String get tankPresets_currentDefault => '当前默认';

  @override
  String get tankPresets_customPresets => '自定义预设';

  @override
  String get tankPresets_defaultSettings => '默认气瓶';

  @override
  String get tankPresets_defaultSettings_description => '加星标的预设将在记录新潜水时用作默认气瓶。';

  @override
  String tankPresets_deleteDefaultMessage(String name) {
    return '确定要删除「$name」吗？这是您当前的默认气瓶预设，将被重置为 AL80。';
  }

  @override
  String tankPresets_deleteMessage(Object name) {
    return '确定要删除 \"$name\"?';
  }

  @override
  String get tankPresets_deletePreset => '删除预设';

  @override
  String get tankPresets_deleteTitle => '删除气瓶预设?';

  @override
  String tankPresets_deleted(Object name) {
    return '已删除\"$name\"';
  }

  @override
  String get tankPresets_editPreset => '编辑预设';

  @override
  String tankPresets_edit_created(Object name) {
    return '已创建\"$name\"';
  }

  @override
  String get tankPresets_edit_descriptionHint => '例如：潜水店的租赁气瓶';

  @override
  String get tankPresets_edit_descriptionOptional => '描述（可选）';

  @override
  String tankPresets_edit_errorLoading(Object error) {
    return '加载预设时出错：$error';
  }

  @override
  String tankPresets_edit_errorSaving(Object error) {
    return '保存预设时出错：$error';
  }

  @override
  String tankPresets_edit_gasCapacity(Object capacity) {
    return '• 气体容量：$capacity cuft';
  }

  @override
  String get tankPresets_edit_material => '材质';

  @override
  String get tankPresets_edit_name => '名称';

  @override
  String get tankPresets_edit_nameHelper => '此气瓶预设的友好名称';

  @override
  String get tankPresets_edit_nameHint => '例如：我的 AL80';

  @override
  String get tankPresets_edit_nameRequired => '请输入名称';

  @override
  String get tankPresets_edit_ratedPressure => '额定压力';

  @override
  String get tankPresets_edit_required => '必填';

  @override
  String get tankPresets_edit_tankSpecifications => '气瓶规格';

  @override
  String get tankPresets_edit_title => '编辑气瓶预设';

  @override
  String tankPresets_edit_updated(Object name) {
    return '已更新\"$name\"';
  }

  @override
  String get tankPresets_edit_validPressure => '请输入有效压力';

  @override
  String get tankPresets_edit_validVolume => '请输入有效容积';

  @override
  String get tankPresets_edit_volume => '容积';

  @override
  String get tankPresets_edit_volumeHelperCuft => '气体容量 (cuft)';

  @override
  String get tankPresets_edit_volumeHelperLiters => '水容积 (L)';

  @override
  String tankPresets_edit_waterVolume(Object volume) {
    return '• 水容积: $volume L';
  }

  @override
  String get tankPresets_edit_workingPressure => '工作压力';

  @override
  String tankPresets_edit_workingPressureBar(Object pressure) {
    return '• 工作压力：$pressure bar';
  }

  @override
  String tankPresets_error(Object error) {
    return '错误： $error';
  }

  @override
  String tankPresets_errorDeleting(Object error) {
    return '删除预设时出错：$error';
  }

  @override
  String get tankPresets_applyToImports => '同时应用到导入的潜水';

  @override
  String get tankPresets_applyToImports_subtitle => '使用默认预设为导入的潜水填充缺失的气瓶数据';

  @override
  String get tankPresets_new_title => '新建气瓶预设';

  @override
  String get tankPresets_noPresets => '无可用气瓶预设';

  @override
  String get tankPresets_setAsDefault => '设为默认';

  @override
  String get tankPresets_title => '气瓶预设';

  @override
  String get tools_deco_description =>
      '计算免减压极限、所需减压停留以及多层潜水轮廓的中枢神经系统毒性/氧毒性单位暴露量。';

  @override
  String get tools_deco_subtitle => '规划需要减压停留的潜水';

  @override
  String get tools_deco_title => '减压计算器';

  @override
  String get tools_disclaimer => '这些计算器仅供计划参考。请务必验证计算结果并遵循您的潜水训练。';

  @override
  String get tools_gas_description =>
      '四种专用气体计算器：\n• 最大作业深度 - 气体混合物的最大作业深度\n• 最佳混合气 - 目标深度的理想氧气百分比\n• 耗气量 - 气体使用量估算\n• 底限储备 - 紧急储备计算';

  @override
  String get tools_gas_subtitle => '最大作业深度、最佳混合气、耗气量、底限储备';

  @override
  String get tools_gas_title => '气体计算器';

  @override
  String get tools_title => '工具';

  @override
  String get tools_weight_aluminumImperial => '空瓶时浮力较大（+4 lbs）';

  @override
  String get tools_weight_aluminumMetric => '空瓶时浮力较大（+2 kg）';

  @override
  String get tools_weight_bodyWeightOptional => '体重（可选）';

  @override
  String get tools_weight_carbonFiberImperial => '浮力很大（+7 lbs）';

  @override
  String get tools_weight_carbonFiberMetric => '浮力很大（+3 kg）';

  @override
  String get tools_weight_description => '根据您的防寒服、气瓶材质、水型和体重估算所需配重。';

  @override
  String get tools_weight_disclaimer =>
      '这仅为估算值。请务必在潜水开始时进行浮力检查并根据需要调整。浮力控制装置、个人浮力和呼吸模式等因素都会影响您的实际配重需求。';

  @override
  String get tools_weight_exposureSuit => '防寒服';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return '• 气体容量：$capacity cuft';
  }

  @override
  String get tools_weight_helperImperial =>
      '体重每超过 154 lbs 增加 22 lbs，约增加 2 lbs 配重';

  @override
  String get tools_weight_helperMetric => '体重每超过 70 kg 增加 10 kg，约增加 1 kg 配重';

  @override
  String get tools_weight_notSpecified => '未指定';

  @override
  String get tools_weight_recommendedWeight => '推荐配重';

  @override
  String tools_weight_resultAccessibility(Object weight, Object unit) {
    return '推荐配重: $weight $unit';
  }

  @override
  String get tools_weight_steelImperial => '负浮力（-4 lbs）';

  @override
  String get tools_weight_steelMetric => '负浮力（-2 kg）';

  @override
  String get tools_weight_subtitle => '适合您装备配置的推荐配重';

  @override
  String get tools_weight_tankMaterial => '气瓶材质';

  @override
  String get tools_weight_tankSpecifications => '气瓶规格';

  @override
  String get tools_weight_title => '配重计算器';

  @override
  String get tools_weight_waterType => '水型';

  @override
  String tools_weight_waterVolume(Object volume) {
    return '• 水容积: $volume L';
  }

  @override
  String tools_weight_workingPressure(Object pressure) {
    return '• 工作压力：$pressure bar';
  }

  @override
  String get tools_weight_yourWeight => '您的配重';

  @override
  String get settings_section_dataSources_title => '数据来源';

  @override
  String get settings_section_dataSources_subtitle => '健康数据集成';

  @override
  String get settings_dataSources_header => 'Apple HealthKit 集成';

  @override
  String get settings_dataSources_appleHealth_title => 'Apple Health';

  @override
  String get settings_dataSources_appleHealth_subtitle => '水下潜水数据';

  @override
  String get settings_dataSources_appleHealth_description =>
      'Submersion 使用 Apple HealthKit 从 Apple Health 读取水下潜水运动数据。此数据用于从您的 Apple Watch 潜水中创建详细的潜水日志。';

  @override
  String get settings_dataSources_appleHealth_dataTypesHeader =>
      '数据读取从 HealthKit';

  @override
  String get settings_dataSources_appleHealth_dataTypeWorkouts =>
      '水下潜水运动 - 潜水开始时间、持续时间和活动数据';

  @override
  String get settings_dataSources_appleHealth_dataTypeHeartRate =>
      '心率 - 潜水期间记录的心率样本';

  @override
  String get settings_dataSources_appleHealth_permissionGranted =>
      '已授予 HealthKit 访问权限';

  @override
  String get settings_dataSources_appleHealth_permissionNotGranted =>
      '未授予 HealthKit 访问权限';

  @override
  String get settings_dataSources_appleHealth_permissionChecking =>
      '正在检查 HealthKit 访问权限...';

  @override
  String get settings_dataSources_appleHealth_importAction =>
      '通过 HealthKit 从 Apple Watch 导入潜水';

  @override
  String get settings_dataSources_appleHealth_privacy =>
      '您的健康数据存储在本设备上，绝不会与第三方共享。Submersion 仅从 Apple HealthKit 读取数据，不会向 HealthKit 写入任何数据。';

  @override
  String get settings_dataSources_appleHealth_poweredBy =>
      '提供支持按 Apple HealthKit';

  @override
  String get settings_dataSources_noSources => '此平台上没有可用的数据源集成。';

  @override
  String get diveLog_edit_section_environment => '环境';

  @override
  String get diveLog_edit_subsection_weather => '天气';

  @override
  String get diveLog_edit_subsection_diveConditions => '潜水条件';

  @override
  String get diveLog_edit_label_windSpeed => '风速';

  @override
  String get diveLog_edit_label_windDirection => '风向';

  @override
  String get diveLog_edit_label_cloudCover => '云量';

  @override
  String get diveLog_edit_label_precipitation => '降水';

  @override
  String get diveLog_edit_label_humidity => '湿度';

  @override
  String get diveLog_edit_label_weatherDescription => '天气描述';

  @override
  String get diveLog_edit_button_fetchWeather => '获取天气';

  @override
  String get diveLog_edit_fetchingWeather => '正在获取天气...';

  @override
  String get diveLog_edit_weatherFetched => '天气数据已加载';

  @override
  String get diveLog_edit_fetchWeatherNoConnection => '无网络连接';

  @override
  String get diveLog_edit_fetchWeatherUnavailable => '此日期的天气数据不可用';

  @override
  String get diveLog_edit_fetchWeatherNotYetAvailable => '此日期的天气数据尚不可用';

  @override
  String get diveLog_edit_fetchWeatherHint => '请先添加日期和潜水点';

  @override
  String get diveLog_edit_fetchWeatherConfirm => '用获取的数据替换现有天气数据？';

  @override
  String get diveLog_detail_section_environment => '环境';

  @override
  String get diveLog_detail_subsection_weather => '天气';

  @override
  String get diveLog_detail_subsection_diveConditions => '潜水条件';

  @override
  String get diveLog_detail_label_windSpeed => '风速';

  @override
  String get diveLog_detail_label_windDirection => '风向';

  @override
  String get diveLog_detail_label_cloudCover => '云量';

  @override
  String get diveLog_detail_label_precipitation => '降水';

  @override
  String get diveLog_detail_label_humidity => '湿度';

  @override
  String get diveLog_detail_label_weatherDescription => '描述';

  @override
  String get diveLog_detail_weatherSourceOpenMeteo => '数据来自 Open-Meteo';

  @override
  String get dropTarget_title => '拖放以导入';

  @override
  String get dropTarget_subtitle => '释放以打开导入向导';

  @override
  String get dropTarget_error_unsupportedFile => '不支持的文件类型';

  @override
  String get dropTarget_error_wizardActive => '请先完成当前导入';

  @override
  String get dropTarget_error_readFailed => '无法读取文件';

  @override
  String get enum_cloudCover_clear => '清除';

  @override
  String get enum_cloudCover_partlyCloudy => '局部多云';

  @override
  String get enum_cloudCover_mostlyCloudy => '大部多云';

  @override
  String get enum_cloudCover_overcast => '阴天';

  @override
  String get enum_precipitation_none => '无';

  @override
  String get enum_precipitation_drizzle => '毛毛雨';

  @override
  String get enum_precipitation_lightRain => '轻微雨';

  @override
  String get enum_precipitation_rain => '雨';

  @override
  String get enum_precipitation_heavyRain => '大雨';

  @override
  String get enum_precipitation_snow => '雪';

  @override
  String get enum_precipitation_sleet => '雨夹雪';

  @override
  String get enum_precipitation_hail => '冰雹';

  @override
  String get columnConfig_title => '潜水详情列表字段';

  @override
  String get columnConfig_viewMode => '视图模式';

  @override
  String get columnConfig_visibleColumns => '可见列';

  @override
  String get columnConfig_availableFields => '可用字段';

  @override
  String get columnConfig_extraFields => '额外字段';

  @override
  String get columnConfig_extraFields_description => '显示在卡片主要内容下方';

  @override
  String get columnConfig_slotAssignments => '位置分配';

  @override
  String get columnConfig_resetToDefault => '恢复默认设置';

  @override
  String get columnConfig_preset => '预设';

  @override
  String get columnConfig_presetSaveAs => '另存为';

  @override
  String get columnConfig_presetName => '预设名称';

  @override
  String get columnConfig_presetNameHint => '例如：技术潜水';

  @override
  String get columnConfig_presetSave => '保存';

  @override
  String get columnConfig_presetCancel => '取消';

  @override
  String get columnConfig_columns => '列';

  @override
  String get columnConfig_done => '完成';

  @override
  String get settings_appearance_columnConfig => '潜水详情列表字段';

  @override
  String get settings_appearance_columnConfig_subtitle => '自定义潜水列表视图中显示的字段';

  @override
  String get diveField_category_core => '核心';

  @override
  String get diveField_category_environment => '环境';

  @override
  String get diveField_category_gas => '气体';

  @override
  String get diveField_category_tank => '气瓶';

  @override
  String get diveField_category_weight => '配重';

  @override
  String get diveField_category_equipment => '装备';

  @override
  String get diveField_category_deco => '减压';

  @override
  String get diveField_category_physiology => '生理';

  @override
  String get diveField_category_rebreather => '循环呼吸器';

  @override
  String get diveField_category_people => '人员';

  @override
  String get diveField_category_location => '位置';

  @override
  String get diveField_category_trip => '旅程';

  @override
  String get diveField_category_rating => '评分';

  @override
  String get diveField_category_metadata => '元数据';

  @override
  String get listViewMode_table => '表格';

  @override
  String get settings_appearance_general => '常规';

  @override
  String get settings_appearance_sections => '部分';

  @override
  String get settings_appearance_showDetailsPane => '显示详情面板';

  @override
  String get settings_appearance_showDetailsPane_subtitle => '在表格旁边显示详情面板';

  @override
  String get settings_appearance_showProfilePanel => '在表格视图中显示配置文件面板';

  @override
  String get settings_appearance_showProfilePanel_subtitle => '默认在表格上方显示潜水剖面图';
}
