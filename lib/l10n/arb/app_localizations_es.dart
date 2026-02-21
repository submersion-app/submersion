// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get accessibility_dialog_keyboardShortcutsTitle => 'Atajos de teclado';

  @override
  String get accessibility_keyLabel_backspace => 'Retroceso';

  @override
  String get accessibility_keyLabel_delete => 'Suprimir';

  @override
  String get accessibility_keyLabel_down => 'Abajo';

  @override
  String get accessibility_keyLabel_enter => 'Intro';

  @override
  String get accessibility_keyLabel_esc => 'Esc';

  @override
  String get accessibility_keyLabel_left => 'Izquierda';

  @override
  String get accessibility_keyLabel_right => 'Derecha';

  @override
  String get accessibility_keyLabel_up => 'Arriba';

  @override
  String accessibility_label_chartSummary(
    Object chartType,
    Object description,
  ) {
    return 'Gráfico de $chartType. $description';
  }

  @override
  String get accessibility_label_createNewItem => 'Crear nuevo elemento';

  @override
  String get accessibility_label_hideList => 'Ocultar lista';

  @override
  String get accessibility_label_hideMapView => 'Ocultar vista de mapa';

  @override
  String accessibility_label_listPane(Object title) {
    return 'Panel de lista de $title';
  }

  @override
  String accessibility_label_mapPane(Object title) {
    return 'Panel de mapa de $title';
  }

  @override
  String accessibility_label_mapViewTitle(Object title) {
    return 'Vista de mapa de $title';
  }

  @override
  String get accessibility_label_showList => 'Mostrar lista';

  @override
  String get accessibility_label_showMapView => 'Mostrar vista de mapa';

  @override
  String get accessibility_label_viewDetails => 'Ver detalles';

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
  String get accessibility_shortcutCategory_editing => 'Edición';

  @override
  String get accessibility_shortcutCategory_general => 'General';

  @override
  String get accessibility_shortcutCategory_help => 'Ayuda';

  @override
  String get accessibility_shortcutCategory_navigation => 'Navegación';

  @override
  String get accessibility_shortcutCategory_search => 'Búsqueda';

  @override
  String get accessibility_shortcut_closeCancel => 'Cerrar / Cancelar';

  @override
  String get accessibility_shortcut_goBack => 'Volver';

  @override
  String get accessibility_shortcut_goToDives => 'Ir a Inmersiones';

  @override
  String get accessibility_shortcut_goToEquipment => 'Ir a Equipo';

  @override
  String get accessibility_shortcut_goToSettings => 'Ir a Configuración';

  @override
  String get accessibility_shortcut_goToSites => 'Ir a Puntos de buceo';

  @override
  String get accessibility_shortcut_goToStatistics => 'Ir a Estadísticas';

  @override
  String get accessibility_shortcut_keyboardShortcuts => 'Atajos de teclado';

  @override
  String get accessibility_shortcut_newDive => 'Nueva inmersión';

  @override
  String get accessibility_shortcut_openSettings => 'Abrir configuración';

  @override
  String get accessibility_shortcut_searchDives => 'Buscar inmersiones';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return 'Ordenar por $displayName, actualmente seleccionado';
  }

  @override
  String accessibility_sort_unselectedLabel(Object displayName) {
    return 'Ordenar por $displayName';
  }

  @override
  String get backup_appBar_title => 'Copia de Seguridad y Restaurar';

  @override
  String get backup_backingUp => 'Creando copia...';

  @override
  String get backup_backupNow => 'Hacer Copia Ahora';

  @override
  String get backup_cloud_enabled => 'Copia en la nube';

  @override
  String get backup_cloud_enabled_subtitle =>
      'Subir copias al almacenamiento en la nube';

  @override
  String get backup_delete_dialog_cancel => 'Cancelar';

  @override
  String get backup_delete_dialog_content =>
      'Esta copia de seguridad se eliminará permanentemente. Esta acción no se puede deshacer.';

  @override
  String get backup_delete_dialog_delete => 'Eliminar';

  @override
  String get backup_delete_dialog_title => 'Eliminar Copia';

  @override
  String get backup_frequency_daily => 'Diaria';

  @override
  String get backup_frequency_monthly => 'Mensual';

  @override
  String get backup_frequency_weekly => 'Semanal';

  @override
  String get backup_history_action_delete => 'Eliminar';

  @override
  String get backup_history_action_restore => 'Restaurar';

  @override
  String get backup_history_empty => 'Sin copias de seguridad';

  @override
  String backup_history_error(Object error) {
    return 'Error al cargar historial: $error';
  }

  @override
  String get backup_restore_dialog_cancel => 'Cancelar';

  @override
  String get backup_restore_dialog_restore => 'Restaurar';

  @override
  String get backup_restore_dialog_safetyNote =>
      'Se creará automáticamente una copia de seguridad de sus datos actuales antes de restaurar.';

  @override
  String get backup_restore_dialog_title => 'Restaurar Copia';

  @override
  String get backup_restore_dialog_warning =>
      'Esto reemplazará TODOS los datos actuales con los datos de la copia. Esta acción no se puede deshacer.';

  @override
  String get backup_schedule_enabled => 'Copias automáticas';

  @override
  String get backup_schedule_enabled_subtitle =>
      'Hacer copias de seguridad de forma programada';

  @override
  String get backup_schedule_frequency => 'Frecuencia';

  @override
  String get backup_schedule_retention => 'Conservar copias';

  @override
  String get backup_schedule_retention_subtitle =>
      'Las copias más antiguas se eliminan automáticamente';

  @override
  String get backup_section_cloud => 'Nube';

  @override
  String get backup_section_history => 'Historial';

  @override
  String get backup_section_schedule => 'Programación';

  @override
  String get backup_status_disabled => 'Copias Automáticas Desactivadas';

  @override
  String backup_status_lastBackup(String time) {
    return 'Última copia: $time';
  }

  @override
  String get backup_status_neverBackedUp => 'Sin Copias de Seguridad';

  @override
  String get backup_status_noBackupsYet =>
      'Crea tu primera copia para proteger tus datos';

  @override
  String get backup_status_overdue => 'Copia Atrasada';

  @override
  String get backup_status_upToDate => 'Copias al Día';

  @override
  String backup_time_daysAgo(int count) {
    return 'hace ${count}d';
  }

  @override
  String backup_time_hoursAgo(int count) {
    return 'hace ${count}h';
  }

  @override
  String get backup_time_justNow => 'Ahora mismo';

  @override
  String backup_time_minutesAgo(int count) {
    return 'hace ${count}m';
  }

  @override
  String get buddies_action_add => 'Agregar Compañero';

  @override
  String get buddies_action_addFirst => 'Agregar tu primer compañero';

  @override
  String get buddies_action_addTooltip => 'Agregar un nuevo compañero de buceo';

  @override
  String get buddies_action_clearSearch => 'Limpiar búsqueda';

  @override
  String get buddies_action_edit => 'Editar compañero';

  @override
  String get buddies_action_importFromContacts => 'Importar de Contactos';

  @override
  String get buddies_action_moreOptions => 'Más opciones';

  @override
  String get buddies_action_retry => 'Reintentar';

  @override
  String get buddies_action_search => 'Buscar compañeros';

  @override
  String get buddies_action_shareDives => 'Compartir Inmersiones';

  @override
  String get buddies_action_sort => 'Ordenar';

  @override
  String get buddies_action_sortTitle => 'Ordenar Compañeros';

  @override
  String get buddies_action_update => 'Actualizar Compañero';

  @override
  String buddies_action_viewAll(Object count) {
    return 'Ver Todos ($count)';
  }

  @override
  String buddies_detail_error(Object error) {
    return 'Error: $error';
  }

  @override
  String get buddies_detail_noDivesTogether => 'Aún no hay inmersiones juntos';

  @override
  String get buddies_detail_notFound => 'Compañero no encontrado';

  @override
  String buddies_dialog_deleteMessage(Object name) {
    return '¿Estás seguro de que deseas eliminar a $name? Esta acción no se puede deshacer.';
  }

  @override
  String get buddies_dialog_deleteTitle => '¿Eliminar Compañero?';

  @override
  String get buddies_dialog_discard => 'Descartar';

  @override
  String get buddies_dialog_discardMessage =>
      'Tienes cambios sin guardar. ¿Estás seguro de que deseas descartarlos?';

  @override
  String get buddies_dialog_discardTitle => '¿Descartar Cambios?';

  @override
  String get buddies_dialog_keepEditing => 'Seguir Editando';

  @override
  String get buddies_empty_subtitle =>
      'Agrega tu primer compañero de buceo para comenzar';

  @override
  String get buddies_empty_title => 'Aún no hay compañeros de buceo';

  @override
  String buddies_error_loading(Object error) {
    return 'Error: $error';
  }

  @override
  String get buddies_error_unableToLoadDives =>
      'No se pueden cargar las inmersiones';

  @override
  String get buddies_error_unableToLoadStats =>
      'No se pueden cargar las estadísticas';

  @override
  String get buddies_field_certificationAgency => 'Agencia Certificadora';

  @override
  String get buddies_field_certificationLevel => 'Nivel de Certificación';

  @override
  String get buddies_field_email => 'Correo Electrónico';

  @override
  String get buddies_field_emailHint => 'correo@ejemplo.com';

  @override
  String get buddies_field_nameHint => 'Ingresa el nombre del compañero';

  @override
  String get buddies_field_nameRequired => 'Nombre *';

  @override
  String get buddies_field_notes => 'Notas';

  @override
  String get buddies_field_notesHint => 'Agrega notas sobre este compañero...';

  @override
  String get buddies_field_phone => 'Teléfono';

  @override
  String get buddies_field_phoneHint => '+1 (555) 123-4567';

  @override
  String get buddies_label_agency => 'Agencia';

  @override
  String buddies_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones',
      one: '1 inmersión',
    );
    return '$_temp0';
  }

  @override
  String get buddies_label_level => 'Nivel';

  @override
  String get buddies_label_notSpecified => 'No especificado';

  @override
  String get buddies_label_photoComingSoon =>
      'Soporte para fotos disponible en v2.0';

  @override
  String get buddies_message_added => 'Compañero agregado exitosamente';

  @override
  String get buddies_message_contactImportUnavailable =>
      'La importación de contactos no está disponible en esta plataforma';

  @override
  String get buddies_message_contactLoadFailed =>
      'Error al cargar los contactos';

  @override
  String get buddies_message_contactPermissionRequired =>
      'Se requiere permiso de contactos para importar compañeros';

  @override
  String get buddies_message_deleted => 'Compañero eliminado';

  @override
  String buddies_message_errorImportingContact(Object error) {
    return 'Error al importar contacto: $error';
  }

  @override
  String buddies_message_errorLoading(Object error) {
    return 'Error al cargar compañero: $error';
  }

  @override
  String buddies_message_errorSaving(Object error) {
    return 'Error al guardar compañero: $error';
  }

  @override
  String buddies_message_exportFailed(Object error) {
    return 'Error al exportar: $error';
  }

  @override
  String get buddies_message_noDivesFound =>
      'No se encontraron inmersiones para exportar';

  @override
  String get buddies_message_noDivesToShare =>
      'No hay inmersiones para compartir con este compañero';

  @override
  String get buddies_message_preparingExport => 'Preparando exportación...';

  @override
  String get buddies_message_updated => 'Compañero actualizado exitosamente';

  @override
  String get buddies_picker_add => 'Agregar';

  @override
  String get buddies_picker_addNew => 'Agregar Nuevo Compañero';

  @override
  String get buddies_picker_done => 'Listo';

  @override
  String get buddies_picker_noBuddiesFound => 'No se encontraron compañeros';

  @override
  String get buddies_picker_noBuddiesYet => 'Aún no hay compañeros';

  @override
  String get buddies_picker_noneSelected => 'Ningún compañero seleccionado';

  @override
  String get buddies_picker_searchHint => 'Buscar compañeros...';

  @override
  String get buddies_picker_selectBuddies => 'Seleccionar Compañeros';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Seleccionar Rol para $name';
  }

  @override
  String get buddies_picker_tapToAdd =>
      'Toca \'Agregar\' para seleccionar compañeros de buceo';

  @override
  String get buddies_search_hint => 'Buscar por nombre, correo o teléfono';

  @override
  String buddies_search_noResults(Object query) {
    return 'No se encontraron compañeros para \"$query\"';
  }

  @override
  String get buddies_section_certification => 'Certificación';

  @override
  String get buddies_section_contact => 'Contacto';

  @override
  String get buddies_section_diveStatistics => 'Estadísticas de Inmersión';

  @override
  String get buddies_section_notes => 'Notas';

  @override
  String get buddies_section_sharedDives => 'Inmersiones Compartidas';

  @override
  String get buddies_stat_divesTogether => 'Inmersiones Juntos';

  @override
  String get buddies_stat_favoriteSite => 'Sitio Favorito';

  @override
  String get buddies_stat_firstDive => 'Primera Inmersión';

  @override
  String get buddies_stat_lastDive => 'Última Inmersión';

  @override
  String get buddies_summary_overview => 'Resumen';

  @override
  String get buddies_summary_quickActions => 'Acciones Rápidas';

  @override
  String get buddies_summary_recentBuddies => 'Compañeros Recientes';

  @override
  String get buddies_summary_selectHint =>
      'Selecciona un compañero de la lista para ver detalles';

  @override
  String get buddies_summary_title => 'Compañeros de Buceo';

  @override
  String get buddies_summary_totalBuddies => 'Total de Compañeros';

  @override
  String get buddies_summary_withCertification => 'Con Certificación';

  @override
  String get buddies_title => 'Compañeros';

  @override
  String get buddies_title_add => 'Agregar Compañero';

  @override
  String get buddies_title_edit => 'Editar Compañero';

  @override
  String get buddies_title_singular => 'Compañero';

  @override
  String get buddies_validation_emailInvalid =>
      'Por favor ingresa un correo electrónico válido';

  @override
  String get buddies_validation_nameRequired => 'Por favor ingresa un nombre';

  @override
  String get certifications_appBar_addCertification => 'Agregar certificacion';

  @override
  String get certifications_appBar_certificationWallet =>
      'Cartera de certificaciones';

  @override
  String get certifications_appBar_editCertification => 'Editar certificacion';

  @override
  String get certifications_appBar_title => 'Certificaciones';

  @override
  String get certifications_detail_action_delete => 'Eliminar';

  @override
  String get certifications_detail_appBar_title => 'Certificacion';

  @override
  String get certifications_detail_courseCompleted => 'Completado';

  @override
  String get certifications_detail_courseInProgress => 'En progreso';

  @override
  String get certifications_detail_dialog_cancel => 'Cancelar';

  @override
  String get certifications_detail_dialog_deleteConfirm => 'Eliminar';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return 'Estas seguro de que deseas eliminar \"$name\"?';
  }

  @override
  String get certifications_detail_dialog_deleteTitle =>
      'Eliminar certificacion?';

  @override
  String get certifications_detail_label_agency => 'Agencia';

  @override
  String get certifications_detail_label_cardNumber => 'Numero de tarjeta';

  @override
  String get certifications_detail_label_expiryDate => 'Fecha de vencimiento';

  @override
  String get certifications_detail_label_instructorName => 'Nombre';

  @override
  String get certifications_detail_label_instructorNumber => 'Instructor #';

  @override
  String get certifications_detail_label_issueDate => 'Fecha de emision';

  @override
  String get certifications_detail_label_level => 'Nivel';

  @override
  String get certifications_detail_label_type => 'Tipo';

  @override
  String get certifications_detail_label_validity => 'Validez';

  @override
  String get certifications_detail_noExpiration => 'Sin vencimiento';

  @override
  String get certifications_detail_notFound => 'Certificacion no encontrada';

  @override
  String get certifications_detail_photoLabel_back => 'Reverso';

  @override
  String get certifications_detail_photoLabel_front => 'Frente';

  @override
  String certifications_detail_photo_fullscreenTitle(
    Object label,
    Object name,
  ) {
    return '$label - $name';
  }

  @override
  String get certifications_detail_photo_unableToLoad =>
      'No se pudo cargar la imagen';

  @override
  String get certifications_detail_sectionTitle_cardPhotos =>
      'Fotos de la tarjeta';

  @override
  String get certifications_detail_sectionTitle_dates => 'Fechas';

  @override
  String get certifications_detail_sectionTitle_details =>
      'Detalles de la certificacion';

  @override
  String get certifications_detail_sectionTitle_instructor => 'Instructor';

  @override
  String get certifications_detail_sectionTitle_notes => 'Notas';

  @override
  String get certifications_detail_sectionTitle_trainingCourse =>
      'Curso de formacion';

  @override
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  ) {
    return 'Foto $label de $name. Toca para ver en pantalla completa';
  }

  @override
  String get certifications_detail_snackBar_deleted =>
      'Certificacion eliminada';

  @override
  String get certifications_detail_status_expired =>
      'Esta certificacion ha expirado';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return 'Expiro el $date';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return 'Expira en $days dias';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return 'Expira el $date';
  }

  @override
  String get certifications_detail_tooltip_edit => 'Editar certificacion';

  @override
  String get certifications_detail_tooltip_editShort => 'Editar';

  @override
  String get certifications_detail_tooltip_moreOptions => 'Mas opciones';

  @override
  String get certifications_ecardStack_empty_subtitle =>
      'Agrega tu primera certificacion para verla aqui';

  @override
  String get certifications_ecardStack_empty_title =>
      'Aun no hay certificaciones';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Certificado por $agency';
  }

  @override
  String get certifications_ecard_label_instructor => 'INSTRUCTOR';

  @override
  String get certifications_ecard_label_issued => 'EMITIDO';

  @override
  String get certifications_ecard_statusBadge_expired => 'EXPIRADO';

  @override
  String get certifications_ecard_statusBadge_expiring => 'POR EXPIRAR';

  @override
  String get certifications_edit_appBar_add => 'Agregar certificacion';

  @override
  String get certifications_edit_appBar_edit => 'Editar certificacion';

  @override
  String get certifications_edit_button_add => 'Agregar certificacion';

  @override
  String get certifications_edit_button_cancel => 'Cancelar';

  @override
  String get certifications_edit_button_save => 'Guardar';

  @override
  String get certifications_edit_button_update => 'Actualizar certificacion';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return 'Borrar $label';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect =>
      'Toca para seleccionar';

  @override
  String get certifications_edit_dialog_discard => 'Descartar';

  @override
  String get certifications_edit_dialog_discardContent =>
      'Tienes cambios sin guardar. Estas seguro de que deseas salir?';

  @override
  String get certifications_edit_dialog_discardTitle => 'Descartar cambios?';

  @override
  String get certifications_edit_dialog_keepEditing => 'Seguir editando';

  @override
  String get certifications_edit_help_expiryDate =>
      'Deja vacio para certificaciones que no expiran';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Ingresa el numero de tarjeta de certificacion';

  @override
  String get certifications_edit_hint_certificationName =>
      'p. ej., Open Water Diver';

  @override
  String get certifications_edit_hint_instructorName =>
      'Nombre del instructor certificador';

  @override
  String get certifications_edit_hint_instructorNumber =>
      'Numero de certificacion del instructor';

  @override
  String get certifications_edit_hint_notes => 'Notas adicionales';

  @override
  String get certifications_edit_label_agency => 'Agencia *';

  @override
  String get certifications_edit_label_cardNumber => 'Numero de tarjeta';

  @override
  String get certifications_edit_label_certificationName =>
      'Nombre de la certificacion *';

  @override
  String get certifications_edit_label_expiryDate => 'Fecha de vencimiento';

  @override
  String get certifications_edit_label_instructorName =>
      'Nombre del instructor';

  @override
  String get certifications_edit_label_instructorNumber =>
      'Numero del instructor';

  @override
  String get certifications_edit_label_issueDate => 'Fecha de emision';

  @override
  String get certifications_edit_label_level => 'Nivel';

  @override
  String get certifications_edit_label_notes => 'Notas';

  @override
  String get certifications_edit_level_notSpecified => 'No especificado';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return 'Agregar foto de $label. Toca para seleccionar';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return 'Foto de $label adjunta. Toca para cambiar';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery =>
      'Elegir de la galeria';

  @override
  String certifications_edit_photo_removeTooltip(Object label) {
    return 'Eliminar foto de $label';
  }

  @override
  String get certifications_edit_photo_takePhoto => 'Tomar foto';

  @override
  String get certifications_edit_sectionTitle_cardPhotos =>
      'Fotos de la tarjeta';

  @override
  String get certifications_edit_sectionTitle_dates => 'Fechas';

  @override
  String get certifications_edit_sectionTitle_instructorInfo =>
      'Informacion del instructor';

  @override
  String get certifications_edit_sectionTitle_notes => 'Notas';

  @override
  String get certifications_edit_snackBar_added =>
      'Certificacion agregada exitosamente';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return 'Error al cargar la certificacion: $error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return 'Error al seleccionar la foto: $error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return 'Error al guardar la certificacion: $error';
  }

  @override
  String get certifications_edit_snackBar_updated =>
      'Certificacion actualizada correctamente';

  @override
  String get certifications_edit_validation_nameRequired =>
      'Por favor, introduce un nombre de certificacion';

  @override
  String get certifications_list_button_retry => 'Reintentar';

  @override
  String get certifications_list_empty_button =>
      'Agrega tu primera certificacion';

  @override
  String get certifications_list_empty_subtitle =>
      'Agrega tus certificaciones de buceo para llevar un registro\nde tu formacion y cualificaciones';

  @override
  String get certifications_list_empty_title =>
      'No se han agregado certificaciones';

  @override
  String certifications_list_error_loading(Object error) {
    return 'Error al cargar certificaciones: $error';
  }

  @override
  String get certifications_list_fab_addCertification =>
      'Agregar certificacion';

  @override
  String get certifications_list_section_expired => 'Vencidas';

  @override
  String get certifications_list_section_expiringSoon => 'Por vencer';

  @override
  String get certifications_list_section_valid => 'Vigentes';

  @override
  String get certifications_list_sort_title => 'Ordenar certificaciones';

  @override
  String get certifications_list_tile_expired => 'Vencida';

  @override
  String certifications_list_tile_expiringDays(Object days) {
    return '${days}d';
  }

  @override
  String get certifications_list_tooltip_addCertification =>
      'Agregar certificacion';

  @override
  String get certifications_list_tooltip_search => 'Buscar certificaciones';

  @override
  String get certifications_list_tooltip_sort => 'Ordenar';

  @override
  String get certifications_list_tooltip_walletView => 'Vista de cartera';

  @override
  String get certifications_picker_clearTooltip =>
      'Borrar seleccion de certificacion';

  @override
  String get certifications_picker_empty_addButton => 'Agregar certificacion';

  @override
  String get certifications_picker_empty_title => 'No hay certificaciones aun';

  @override
  String certifications_picker_error(Object error) {
    return 'Error al cargar certificaciones: $error';
  }

  @override
  String get certifications_picker_expired => 'Vencida';

  @override
  String get certifications_picker_hint =>
      'Toca para vincular a una certificacion obtenida';

  @override
  String get certifications_picker_newCert => 'Nueva cert.';

  @override
  String get certifications_picker_noSelection =>
      'No se ha seleccionado certificacion';

  @override
  String get certifications_picker_sheetTitle => 'Vincular a certificacion';

  @override
  String get certifications_renderer_footer => 'Submersion Registro de buceo';

  @override
  String certifications_renderer_label_cardNumber(Object number) {
    return 'Tarjeta #: $number';
  }

  @override
  String get certifications_renderer_label_hasCompletedTraining =>
      'ha completado la formacion como';

  @override
  String certifications_renderer_label_instructor(Object name) {
    return 'Instructor: $name';
  }

  @override
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  ) {
    return 'Instructor: $name ($number)';
  }

  @override
  String certifications_renderer_label_issued(Object date) {
    return 'Emitida: $date';
  }

  @override
  String get certifications_renderer_label_thisCertifies =>
      'Esto certifica que';

  @override
  String get certifications_search_empty_hint =>
      'Buscar por nombre, agencia o numero de tarjeta';

  @override
  String get certifications_search_fieldLabel => 'Buscar certificaciones...';

  @override
  String certifications_search_noResults(Object query) {
    return 'No se encontraron certificaciones para \"$query\"';
  }

  @override
  String get certifications_search_tooltip_back => 'Atras';

  @override
  String get certifications_search_tooltip_clear => 'Borrar busqueda';

  @override
  String certifications_share_error_card(Object error) {
    return 'Error al compartir tarjeta: $error';
  }

  @override
  String certifications_share_error_certificate(Object error) {
    return 'Error al compartir certificado: $error';
  }

  @override
  String get certifications_share_option_card_subtitle =>
      'Imagen de certificacion estilo tarjeta de credito';

  @override
  String get certifications_share_option_card_title => 'Compartir como tarjeta';

  @override
  String get certifications_share_option_certificate_subtitle =>
      'Documento de certificado formal';

  @override
  String get certifications_share_option_certificate_title =>
      'Compartir como certificado';

  @override
  String get certifications_share_title => 'Compartir certificacion';

  @override
  String get certifications_summary_header_subtitle =>
      'Selecciona una certificacion de la lista para ver detalles';

  @override
  String get certifications_summary_header_title => 'Certificaciones';

  @override
  String get certifications_summary_overview_title => 'Resumen';

  @override
  String get certifications_summary_quickActions_add => 'Agregar certificacion';

  @override
  String get certifications_summary_quickActions_title => 'Acciones rapidas';

  @override
  String get certifications_summary_recentTitle => 'Certificaciones recientes';

  @override
  String get certifications_summary_stat_expired => 'Vencidas';

  @override
  String get certifications_summary_stat_expiringSoon => 'Por vencer';

  @override
  String get certifications_summary_stat_total => 'Total';

  @override
  String get certifications_summary_stat_valid => 'Vigentes';

  @override
  String certifications_walletCard_countPlural(Object count) {
    return '$count certificaciones';
  }

  @override
  String certifications_walletCard_countSingular(Object count) {
    return '$count certificacion';
  }

  @override
  String get certifications_walletCard_emptyFooter =>
      'Agrega tu primera certificacion';

  @override
  String get certifications_walletCard_error =>
      'Error al cargar certificaciones';

  @override
  String get certifications_walletCard_semanticLabel =>
      'Cartera de certificaciones. Toca para ver todas las certificaciones';

  @override
  String get certifications_walletCard_tapToAdd => 'Toca para agregar';

  @override
  String get certifications_walletCard_title => 'Cartera de certificaciones';

  @override
  String get certifications_wallet_appBar_title => 'Cartera de certificaciones';

  @override
  String get certifications_wallet_error_retry => 'Reintentar';

  @override
  String get certifications_wallet_error_title =>
      'Error al cargar certificaciones';

  @override
  String get certifications_wallet_options_edit => 'Editar';

  @override
  String get certifications_wallet_options_share => 'Compartir';

  @override
  String get certifications_wallet_options_viewDetails => 'Ver detalles';

  @override
  String get certifications_wallet_tooltip_add => 'Agregar certificacion';

  @override
  String get certifications_wallet_tooltip_share => 'Compartir certificacion';

  @override
  String get common_action_back => 'Atrás';

  @override
  String get common_action_cancel => 'Cancelar';

  @override
  String get common_action_close => 'Cerrar';

  @override
  String get common_action_delete => 'Eliminar';

  @override
  String get common_action_edit => 'Editar';

  @override
  String get common_action_ok => 'Aceptar';

  @override
  String get common_action_save => 'Guardar';

  @override
  String get common_action_search => 'Buscar';

  @override
  String get common_label_error => 'Error';

  @override
  String get common_label_loading => 'Cargando';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get courses_action_add => 'Agregar Curso';

  @override
  String get courses_action_create => 'Crear Curso';

  @override
  String get courses_action_edit => 'Editar curso';

  @override
  String get courses_action_exportTrainingLog =>
      'Exportar Registro de Entrenamiento';

  @override
  String get courses_action_markCompleted => 'Marcar como Completado';

  @override
  String get courses_action_moreOptions => 'Más opciones';

  @override
  String get courses_action_retry => 'Reintentar';

  @override
  String get courses_action_saveChanges => 'Guardar Cambios';

  @override
  String get courses_action_saveSemantic => 'Guardar curso';

  @override
  String get courses_action_sort => 'Ordenar';

  @override
  String get courses_action_sortTitle => 'Ordenar Cursos';

  @override
  String courses_card_instructor(Object name) {
    return 'Instructor: $name';
  }

  @override
  String courses_card_started(Object date) {
    return 'Iniciado $date';
  }

  @override
  String get courses_detail_certificationNotFound =>
      'Certificación no encontrada';

  @override
  String get courses_detail_noTrainingDives =>
      'Aún no hay inmersiones de entrenamiento vinculadas';

  @override
  String get courses_detail_notFound => 'Curso no encontrado';

  @override
  String get courses_dialog_complete => 'Completar';

  @override
  String courses_dialog_deleteMessage(Object name) {
    return '¿Estás seguro de que deseas eliminar $name? Esta acción no se puede deshacer.';
  }

  @override
  String get courses_dialog_deleteTitle => '¿Eliminar Curso?';

  @override
  String get courses_dialog_markCompletedMessage =>
      'Esto marcará el curso como completado con la fecha de hoy. ¿Continuar?';

  @override
  String get courses_dialog_markCompletedTitle => '¿Marcar como Completado?';

  @override
  String get courses_empty_noCompleted => 'No hay cursos completados';

  @override
  String get courses_empty_noInProgress => 'No hay cursos en progreso';

  @override
  String get courses_empty_subtitle => 'Agrega tu primer curso para comenzar';

  @override
  String get courses_empty_title => 'Aún no hay cursos de entrenamiento';

  @override
  String courses_error_generic(Object error) {
    return 'Error: $error';
  }

  @override
  String get courses_error_loadingCertification =>
      'Error al cargar certificación';

  @override
  String get courses_error_loadingDives => 'Error al cargar inmersiones';

  @override
  String get courses_field_courseName => 'Nombre del Curso';

  @override
  String get courses_field_courseNameHint => 'ej. Open Water Diver';

  @override
  String get courses_field_instructorName => 'Nombre del Instructor';

  @override
  String get courses_field_instructorNumber => 'Número de Instructor';

  @override
  String get courses_field_linkCertificationHint =>
      'Vincular una certificación obtenida de este curso';

  @override
  String get courses_field_location => 'Ubicación';

  @override
  String get courses_field_notes => 'Notas';

  @override
  String get courses_field_selectFromBuddies =>
      'Seleccionar de Compañeros (Opcional)';

  @override
  String get courses_filter_all => 'Todos';

  @override
  String get courses_label_agency => 'Agencia';

  @override
  String get courses_label_completed => 'Completado';

  @override
  String get courses_label_completionDate => 'Fecha de Finalización';

  @override
  String get courses_label_courseInProgress => 'Curso en progreso';

  @override
  String get courses_label_instructorNumber => 'Instructor #';

  @override
  String get courses_label_location => 'Ubicación';

  @override
  String get courses_label_name => 'Nombre';

  @override
  String get courses_label_none => '-- Ninguno --';

  @override
  String get courses_label_startDate => 'Fecha de Inicio';

  @override
  String courses_message_errorSaving(Object error) {
    return 'Error al guardar curso: $error';
  }

  @override
  String courses_message_exportFailed(Object error) {
    return 'Error al exportar registro de entrenamiento: $error';
  }

  @override
  String get courses_picker_active => 'Activo';

  @override
  String get courses_picker_clearSelection => 'Limpiar selección';

  @override
  String get courses_picker_createCourse => 'Crear Curso';

  @override
  String courses_picker_errorLoading(Object error) {
    return 'Error al cargar cursos: $error';
  }

  @override
  String get courses_picker_newCourse => 'Nuevo Curso';

  @override
  String get courses_picker_noCourses => 'Aún no hay cursos';

  @override
  String get courses_picker_noneSelected => 'Ningún curso seleccionado';

  @override
  String get courses_picker_selectTitle => 'Seleccionar Curso de Entrenamiento';

  @override
  String get courses_picker_selected => 'seleccionado';

  @override
  String get courses_picker_tapToLink =>
      'Toca para vincular a un curso de entrenamiento';

  @override
  String get courses_section_details => 'Detalles del Curso';

  @override
  String get courses_section_earnedCertification => 'Certificación Obtenida';

  @override
  String get courses_section_instructor => 'Instructor';

  @override
  String get courses_section_notes => 'Notas';

  @override
  String get courses_section_trainingDives => 'Inmersiones de Entrenamiento';

  @override
  String get courses_status_completed => 'Completado';

  @override
  String courses_status_daysSinceStart(Object days) {
    return '$days días desde el inicio';
  }

  @override
  String courses_status_durationDays(Object days) {
    return '$days días';
  }

  @override
  String get courses_status_inProgress => 'En Progreso';

  @override
  String courses_status_semanticLabel(Object status, Object duration) {
    return '$status, $duration';
  }

  @override
  String get courses_summary_overview => 'Resumen';

  @override
  String get courses_summary_quickActions => 'Acciones Rápidas';

  @override
  String get courses_summary_recentCourses => 'Cursos Recientes';

  @override
  String get courses_summary_selectHint =>
      'Selecciona un curso de la lista para ver detalles';

  @override
  String get courses_summary_title => 'Cursos de Entrenamiento';

  @override
  String get courses_summary_total => 'Total';

  @override
  String get courses_title => 'Cursos de Entrenamiento';

  @override
  String get courses_title_edit => 'Editar Curso';

  @override
  String get courses_title_new => 'Nuevo Curso';

  @override
  String get courses_title_singular => 'Curso';

  @override
  String get courses_validation_nameRequired =>
      'Por favor ingresa un nombre de curso';

  @override
  String get dashboard_activity_daySinceDiving => 'Día sin bucear';

  @override
  String get dashboard_activity_daysSinceDiving => 'Días sin bucear';

  @override
  String dashboard_activity_diveInYear(Object year) {
    return 'Inmersión en $year';
  }

  @override
  String get dashboard_activity_diveThisMonth => 'Inmersión este mes';

  @override
  String dashboard_activity_divesInYear(Object year) {
    return 'Inmersiones en $year';
  }

  @override
  String get dashboard_activity_divesThisMonth => 'Inmersiones este mes';

  @override
  String get dashboard_activity_error => 'Error';

  @override
  String get dashboard_activity_lastDive => 'Última inmersión';

  @override
  String get dashboard_activity_loading => 'Cargando';

  @override
  String get dashboard_activity_noDivesYet => 'Aún no hay inmersiones';

  @override
  String get dashboard_activity_today => '¡Hoy!';

  @override
  String get dashboard_alerts_actionUpdate => 'Actualizar';

  @override
  String get dashboard_alerts_actionView => 'Ver';

  @override
  String get dashboard_alerts_checkInsuranceExpiry =>
      'Verifica la fecha de vencimiento de tu seguro';

  @override
  String get dashboard_alerts_daysOverdueOne => '1 día de retraso';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return '$count días de retraso';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => 'Vence en 1 día';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return 'Vence en $count días';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return 'Servicio de $name pendiente';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return 'Servicio de $name vencido';
  }

  @override
  String get dashboard_alerts_insuranceExpired => 'Seguro vencido';

  @override
  String get dashboard_alerts_insuranceExpiredGeneric =>
      'Tu seguro de buceo ha vencido';

  @override
  String dashboard_alerts_insuranceExpiredProvider(Object provider) {
    return '$provider vencido';
  }

  @override
  String dashboard_alerts_insuranceExpiresDate(Object date) {
    return 'Vence el $date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon => 'Seguro por vencer';

  @override
  String get dashboard_alerts_sectionTitle => 'Alertas y recordatorios';

  @override
  String get dashboard_alerts_serviceDueToday => 'Servicio programado para hoy';

  @override
  String get dashboard_alerts_serviceIntervalReached =>
      'Intervalo de servicio alcanzado';

  @override
  String get dashboard_defaultDiverName => 'Buzo';

  @override
  String get dashboard_greeting_afternoon => 'Buenas tardes';

  @override
  String get dashboard_greeting_evening => 'Buenas noches';

  @override
  String get dashboard_greeting_morning => 'Buenos días';

  @override
  String dashboard_greeting_withName(Object greeting, Object name) {
    return '¡$greeting, $name!';
  }

  @override
  String dashboard_greeting_withoutName(Object greeting) {
    return '¡$greeting!';
  }

  @override
  String get dashboard_hero_divesLoggedOne => '1 inmersión registrada';

  @override
  String dashboard_hero_divesLoggedOther(Object count) {
    return '$count inmersiones registradas';
  }

  @override
  String get dashboard_hero_error => '¿Listo para explorar las profundidades?';

  @override
  String dashboard_hero_hoursUnderwater(Object hours) {
    return '$hours horas bajo el agua';
  }

  @override
  String get dashboard_hero_loading => 'Cargando tus estadísticas de buceo...';

  @override
  String dashboard_hero_minutesUnderwater(Object minutes) {
    return '$minutes minutos bajo el agua';
  }

  @override
  String get dashboard_hero_noDives =>
      '¿Listo para registrar tu primera inmersión?';

  @override
  String get dashboard_personalRecords_coldest => 'Más fría';

  @override
  String get dashboard_personalRecords_deepest => 'Más profunda';

  @override
  String get dashboard_personalRecords_longest => 'Más larga';

  @override
  String get dashboard_personalRecords_sectionTitle => 'Récords personales';

  @override
  String get dashboard_personalRecords_warmest => 'Más cálida';

  @override
  String get dashboard_quickActions_addSite => 'Agregar punto';

  @override
  String get dashboard_quickActions_addSiteTooltip =>
      'Agregar un nuevo punto de buceo';

  @override
  String get dashboard_quickActions_logDive => 'Registrar inmersión';

  @override
  String get dashboard_quickActions_logDiveTooltip =>
      'Registrar una nueva inmersión';

  @override
  String get dashboard_quickActions_planDive => 'Planificar inmersión';

  @override
  String get dashboard_quickActions_planDiveTooltip =>
      'Planificar una nueva inmersión';

  @override
  String get dashboard_quickActions_sectionTitle => 'Acciones rápidas';

  @override
  String get dashboard_quickActions_statistics => 'Estadísticas';

  @override
  String get dashboard_quickActions_statisticsTooltip =>
      'Ver estadísticas de buceo';

  @override
  String get dashboard_quickStats_countries => 'Países';

  @override
  String get dashboard_quickStats_countriesSubtitle => 'visitados';

  @override
  String get dashboard_quickStats_sectionTitle => 'De un vistazo';

  @override
  String get dashboard_quickStats_species => 'Especies';

  @override
  String get dashboard_quickStats_speciesSubtitle => 'descubiertas';

  @override
  String get dashboard_quickStats_topBuddy => 'Mejor compañero';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count inmersiones';
  }

  @override
  String get dashboard_recentDives_empty =>
      'Aún no hay inmersiones registradas';

  @override
  String get dashboard_recentDives_errorLoading =>
      'Error al cargar inmersiones';

  @override
  String get dashboard_recentDives_logFirst => 'Registra tu primera inmersión';

  @override
  String get dashboard_recentDives_sectionTitle => 'Inmersiones recientes';

  @override
  String get dashboard_recentDives_viewAll => 'Ver todas';

  @override
  String get dashboard_recentDives_viewAllTooltip =>
      'Ver todas las inmersiones';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count alertas activas';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives =>
      'Error: No se pudieron cargar las inmersiones recientes';

  @override
  String get dashboard_semantics_errorLoadingStatistics =>
      'Error: No se pudieron cargar las estadísticas';

  @override
  String get dashboard_semantics_greetingBanner =>
      'Banner de bienvenida del panel';

  @override
  String get dashboard_stats_errorLoadingStatistics =>
      'Error al cargar las estadísticas';

  @override
  String get dashboard_stats_hoursLogged => 'Horas registradas';

  @override
  String get dashboard_stats_maxDepth => 'Profundidad máxima';

  @override
  String get dashboard_stats_sitesVisited => 'Puntos visitados';

  @override
  String get dashboard_stats_totalDives => 'Total de inmersiones';

  @override
  String get decoCalculator_addToPlanner => 'Agregar al Planificador';

  @override
  String decoCalculator_bottomTimeSemantics(Object time) {
    return 'Tiempo de fondo: $time minutos';
  }

  @override
  String get decoCalculator_createPlanTooltip =>
      'Crear un plan de inmersión con los parámetros actuales';

  @override
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  ) {
    return 'Plan creado: $depth$depthSymbol por ${time}min en $gasMixName';
  }

  @override
  String get decoCalculator_customMixTrimix => 'Mezcla Personalizada (Trimix)';

  @override
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol) {
    return 'Profundidad: $depth $depthSymbol';
  }

  @override
  String get decoCalculator_diveParameters => 'Parámetros de Inmersión';

  @override
  String get decoCalculator_endCaution => 'Precaución';

  @override
  String get decoCalculator_endDanger => 'Peligro';

  @override
  String get decoCalculator_endSafe => 'Seguro';

  @override
  String get decoCalculator_field_bottomTime => 'Tiempo de Fondo';

  @override
  String get decoCalculator_field_depth => 'Profundidad';

  @override
  String get decoCalculator_field_gasMix => 'Mezcla de Gas';

  @override
  String get decoCalculator_gasSafety => 'Seguridad del Gas';

  @override
  String get decoCalculator_hideCustomMix => 'Ocultar Mezcla Personalizada';

  @override
  String get decoCalculator_hideCustomMixSemantics =>
      'Ocultar selector de mezcla de gas personalizada';

  @override
  String get decoCalculator_modExceeded => 'MOD Excedida';

  @override
  String get decoCalculator_modSafe => 'MOD Segura';

  @override
  String get decoCalculator_ppO2Caution => 'ppO2 Precaución';

  @override
  String get decoCalculator_ppO2Danger => 'ppO2 Peligro';

  @override
  String get decoCalculator_ppO2Hypoxic => 'ppO2 Hipóxica';

  @override
  String get decoCalculator_ppO2Safe => 'ppO2 Segura';

  @override
  String get decoCalculator_resetToDefaults =>
      'Restablecer valores predeterminados';

  @override
  String get decoCalculator_showCustomMixSemantics =>
      'Mostrar selector de mezcla de gas personalizada';

  @override
  String decoCalculator_timeValueMin(Object time) {
    return '$time min';
  }

  @override
  String get decoCalculator_title => 'Calculadora de Descompresión';

  @override
  String diveCenters_accessibility_markerLabel(Object name) {
    return 'Centro de buceo: $name';
  }

  @override
  String get diveCenters_accessibility_selected => 'seleccionado';

  @override
  String diveCenters_accessibility_viewDetails(Object name) {
    return 'Ver detalles de $name';
  }

  @override
  String get diveCenters_accessibility_viewDives =>
      'Ver inmersiones con este centro';

  @override
  String get diveCenters_accessibility_viewFullscreenMap =>
      'Ver mapa en pantalla completa';

  @override
  String diveCenters_accessibility_viewSavedCenter(Object name) {
    return 'Ver centro de buceo guardado $name';
  }

  @override
  String get diveCenters_action_addCenter => 'Agregar Centro';

  @override
  String get diveCenters_action_addNew => 'Agregar Nuevo';

  @override
  String get diveCenters_action_clearRating => 'Limpiar';

  @override
  String get diveCenters_action_gettingLocation => 'Obteniendo...';

  @override
  String get diveCenters_action_import => 'Importar';

  @override
  String get diveCenters_action_importToMyCenters => 'Importar a Mis Centros';

  @override
  String get diveCenters_action_lookingUp => 'Buscando...';

  @override
  String get diveCenters_action_lookupFromAddress => 'Buscar desde Dirección';

  @override
  String get diveCenters_action_pickFromMap => 'Elegir del Mapa';

  @override
  String get diveCenters_action_retry => 'Reintentar';

  @override
  String get diveCenters_action_settings => 'Configuración';

  @override
  String get diveCenters_action_useMyLocation => 'Usar Mi Ubicación';

  @override
  String get diveCenters_action_view => 'Ver';

  @override
  String diveCenters_detail_divesLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones registradas',
      one: '1 inmersión registrada',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_detail_divesWithCenter =>
      'Inmersiones con este Centro';

  @override
  String get diveCenters_detail_noDivesLogged =>
      'Aún no hay inmersiones registradas';

  @override
  String diveCenters_dialog_deleteMessage(Object name) {
    return '¿Estás seguro de que deseas eliminar \"$name\"?';
  }

  @override
  String get diveCenters_dialog_deleteTitle => 'Eliminar Centro de Buceo';

  @override
  String get diveCenters_dialog_discard => 'Descartar';

  @override
  String get diveCenters_dialog_discardMessage =>
      'Tienes cambios sin guardar. ¿Estás seguro de que deseas descartarlos?';

  @override
  String get diveCenters_dialog_discardTitle => '¿Descartar Cambios?';

  @override
  String get diveCenters_dialog_keepEditing => 'Seguir Editando';

  @override
  String get diveCenters_empty_subtitle =>
      'Agrega tus tiendas y operadores de buceo favoritos';

  @override
  String get diveCenters_empty_title => 'Aún no hay centros de buceo';

  @override
  String diveCenters_error_generic(Object error) {
    return 'Error: $error';
  }

  @override
  String get diveCenters_error_geocodeFailed =>
      'No se pudieron encontrar coordenadas para esta dirección';

  @override
  String get diveCenters_error_importFailed =>
      'Error al importar centro de buceo';

  @override
  String diveCenters_error_loading(Object error) {
    return 'Error al cargar centros de buceo: $error';
  }

  @override
  String get diveCenters_error_locationPermission =>
      'No se puede obtener la ubicación. Por favor verifica los permisos.';

  @override
  String get diveCenters_error_locationUnavailable =>
      'No se puede obtener la ubicación. Los servicios de ubicación pueden no estar disponibles.';

  @override
  String get diveCenters_error_noAddressForLookup =>
      'Por favor ingresa una dirección para buscar coordenadas';

  @override
  String get diveCenters_error_notFound => 'Centro de buceo no encontrado';

  @override
  String diveCenters_error_saving(Object error) {
    return 'Error al guardar centro de buceo: $error';
  }

  @override
  String get diveCenters_error_unknown => 'Error desconocido';

  @override
  String get diveCenters_field_city => 'Ciudad';

  @override
  String get diveCenters_field_country => 'País';

  @override
  String get diveCenters_field_latitude => 'Latitud';

  @override
  String get diveCenters_field_longitude => 'Longitud';

  @override
  String get diveCenters_field_nameRequired => 'Nombre *';

  @override
  String get diveCenters_field_postalCode => 'Código Postal';

  @override
  String get diveCenters_field_rating => 'Calificación';

  @override
  String get diveCenters_field_stateProvince => 'Estado/Provincia';

  @override
  String get diveCenters_field_street => 'Dirección';

  @override
  String get diveCenters_hint_addressDescription =>
      'Dirección opcional para navegación';

  @override
  String get diveCenters_hint_affiliationsDescription =>
      'Selecciona las agencias de entrenamiento con las que este centro está afiliado';

  @override
  String get diveCenters_hint_city => 'ej., Phuket';

  @override
  String get diveCenters_hint_country => 'ej., Tailandia';

  @override
  String get diveCenters_hint_email => 'info@centrodebueo.com';

  @override
  String get diveCenters_hint_gpsDescription =>
      'Elige un método de ubicación o ingresa coordenadas manualmente';

  @override
  String get diveCenters_hint_importSearch =>
      'Buscar centros de buceo (ej., \"PADI\", \"Tailandia\")';

  @override
  String get diveCenters_hint_latitude => 'ej., 10.4613';

  @override
  String get diveCenters_hint_longitude => 'ej., 99.8359';

  @override
  String get diveCenters_hint_name => 'Ingresa el nombre del centro de buceo';

  @override
  String get diveCenters_hint_notes => 'Cualquier información adicional...';

  @override
  String get diveCenters_hint_phone => '+1 234 567 890';

  @override
  String get diveCenters_hint_postalCode => 'ej., 83100';

  @override
  String get diveCenters_hint_stateProvince => 'ej., Phuket';

  @override
  String get diveCenters_hint_street => 'ej., Calle Playa 123';

  @override
  String get diveCenters_hint_website => 'www.centrodebueo.com';

  @override
  String diveCenters_import_fromDatabase(Object count) {
    return 'Importar de Base de Datos ($count)';
  }

  @override
  String diveCenters_import_myCenters(Object count) {
    return 'Mis Centros ($count)';
  }

  @override
  String get diveCenters_import_noResults => 'Sin Resultados';

  @override
  String diveCenters_import_noResultsMessage(Object query) {
    return 'No se encontraron centros de buceo para \"$query\". Intenta con otro término de búsqueda.';
  }

  @override
  String get diveCenters_import_searchDescription =>
      'Busca centros de buceo, tiendas y clubes de nuestra base de datos de operadores alrededor del mundo.';

  @override
  String get diveCenters_import_searchError => 'Error de Búsqueda';

  @override
  String get diveCenters_import_searchHint =>
      'Intenta buscar por nombre, país o agencia certificadora.';

  @override
  String get diveCenters_import_searchTitle => 'Buscar Centros de Buceo';

  @override
  String get diveCenters_label_alreadyImported => 'Ya Importado';

  @override
  String diveCenters_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones',
      one: '1 inmersión',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_label_email => 'Correo Electrónico';

  @override
  String get diveCenters_label_imported => 'Importado';

  @override
  String get diveCenters_label_locationNotSet => 'Ubicación no establecida';

  @override
  String get diveCenters_label_locationUnknown => 'Ubicación desconocida';

  @override
  String get diveCenters_label_phone => 'Teléfono';

  @override
  String get diveCenters_label_saved => 'Guardado';

  @override
  String diveCenters_label_source(Object source) {
    return 'Fuente: $source';
  }

  @override
  String get diveCenters_label_website => 'Sitio Web';

  @override
  String get diveCenters_map_addCoordinatesHint =>
      'Agrega coordenadas a tus centros de buceo para verlos en el mapa';

  @override
  String get diveCenters_map_noCoordinates =>
      'No hay centros de buceo con coordenadas';

  @override
  String get diveCenters_picker_newCenter => 'Nuevo Centro de Buceo';

  @override
  String get diveCenters_picker_title => 'Seleccionar Centro de Buceo';

  @override
  String diveCenters_search_noResults(Object query) {
    return 'Sin resultados para \"$query\"';
  }

  @override
  String get diveCenters_search_prompt => 'Buscar centros de buceo';

  @override
  String get diveCenters_section_address => 'Dirección';

  @override
  String get diveCenters_section_affiliations => 'Afiliaciones';

  @override
  String get diveCenters_section_basicInfo => 'Información Básica';

  @override
  String get diveCenters_section_contact => 'Contacto';

  @override
  String get diveCenters_section_contactInfo => 'Información de Contacto';

  @override
  String get diveCenters_section_gpsCoordinates => 'Coordenadas GPS';

  @override
  String get diveCenters_section_notes => 'Notas';

  @override
  String get diveCenters_snackbar_coordinatesFound =>
      'Coordenadas encontradas desde dirección';

  @override
  String get diveCenters_snackbar_copiedToClipboard =>
      'Copiado al portapapeles';

  @override
  String diveCenters_snackbar_imported(Object name) {
    return 'Importado \"$name\"';
  }

  @override
  String get diveCenters_snackbar_locationCaptured => 'Ubicación capturada';

  @override
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Ubicación capturada (±${accuracy}m)';
  }

  @override
  String get diveCenters_snackbar_locationSelectedFromMap =>
      'Ubicación seleccionada del mapa';

  @override
  String get diveCenters_sort_title => 'Ordenar Centros de Buceo';

  @override
  String get diveCenters_summary_countries => 'Países';

  @override
  String get diveCenters_summary_highestRating => 'Calificación Más Alta';

  @override
  String get diveCenters_summary_overview => 'Resumen';

  @override
  String get diveCenters_summary_quickActions => 'Acciones Rápidas';

  @override
  String get diveCenters_summary_recentCenters => 'Centros de Buceo Recientes';

  @override
  String get diveCenters_summary_selectPrompt =>
      'Selecciona un centro de buceo de la lista para ver detalles';

  @override
  String get diveCenters_summary_topRated => 'Mejor Calificados';

  @override
  String get diveCenters_summary_totalCenters => 'Total de Centros';

  @override
  String get diveCenters_summary_withGps => 'Con GPS';

  @override
  String get diveCenters_title => 'Centros de Buceo';

  @override
  String get diveCenters_title_add => 'Agregar Centro de Buceo';

  @override
  String get diveCenters_title_edit => 'Editar Centro de Buceo';

  @override
  String get diveCenters_title_import => 'Importar Centro de Buceo';

  @override
  String get diveCenters_tooltip_addNew => 'Agregar un nuevo centro de buceo';

  @override
  String get diveCenters_tooltip_clearSearch => 'Limpiar búsqueda';

  @override
  String get diveCenters_tooltip_edit => 'Editar centro de buceo';

  @override
  String get diveCenters_tooltip_fitAllCenters => 'Ajustar Todos los Centros';

  @override
  String get diveCenters_tooltip_listView => 'Vista de Lista';

  @override
  String get diveCenters_tooltip_mapView => 'Vista de Mapa';

  @override
  String get diveCenters_tooltip_moreOptions => 'Más opciones';

  @override
  String get diveCenters_tooltip_search => 'Buscar centros de buceo';

  @override
  String get diveCenters_tooltip_sort => 'Ordenar';

  @override
  String get diveCenters_validation_invalidEmail =>
      'Por favor ingresa un correo electrónico válido';

  @override
  String get diveCenters_validation_invalidLatitude => 'Latitud inválida';

  @override
  String get diveCenters_validation_invalidLongitude => 'Longitud inválida';

  @override
  String get diveCenters_validation_nameRequired => 'El nombre es requerido';

  @override
  String get diveComputer_action_setFavorite => 'Establecer como favorito';

  @override
  String diveComputer_error_generic(Object error) {
    return 'Ocurrió un error: $error';
  }

  @override
  String get diveComputer_error_notFound => 'Dispositivo no encontrado';

  @override
  String get diveComputer_status_favorite => 'Computadora favorita';

  @override
  String get diveComputer_title => 'Computadora de Buceo';

  @override
  String diveLog_bulkDelete_confirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones',
      one: 'inmersión',
    );
    return '¿Estás seguro de que deseas eliminar $count $_temp0? Esta acción no se puede deshacer.';
  }

  @override
  String get diveLog_bulkDelete_restored => 'Inmersiones restauradas';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones eliminadas',
      one: 'inmersión eliminada',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_bulkDelete_title => 'Eliminar inmersiones';

  @override
  String get diveLog_bulkDelete_undo => 'Deshacer';

  @override
  String get diveLog_bulkEdit_addTags => 'Agregar etiquetas';

  @override
  String get diveLog_bulkEdit_addTagsDescription =>
      'Agregar etiquetas a las inmersiones seleccionadas';

  @override
  String diveLog_bulkEdit_addedTags(int tagCount, int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: 'etiquetas agregadas',
      one: 'etiqueta agregada',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'inmersiones',
      one: 'inmersión',
    );
    return '$tagCount $_temp0 a $diveCount $_temp1';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => 'Cambiar viaje';

  @override
  String get diveLog_bulkEdit_changeTripDescription =>
      'Mover inmersiones seleccionadas a un viaje';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips => 'Error al cargar viajes';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return 'Error al agregar etiquetas: $error';
  }

  @override
  String diveLog_bulkEdit_failedUpdateTrip(Object error) {
    return 'Error al actualizar viaje: $error';
  }

  @override
  String diveLog_bulkEdit_movedToTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones movidas',
      one: 'inmersión movida',
    );
    return '$count $_temp0 al viaje';
  }

  @override
  String get diveLog_bulkEdit_noTagsAvailable =>
      'No hay etiquetas disponibles.';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate =>
      'No hay etiquetas disponibles. Crea etiquetas primero.';

  @override
  String get diveLog_bulkEdit_noTrip => 'Sin viaje';

  @override
  String get diveLog_bulkEdit_removeFromTrip => 'Quitar del viaje';

  @override
  String get diveLog_bulkEdit_removeTags => 'Quitar etiquetas';

  @override
  String get diveLog_bulkEdit_removeTagsDescription =>
      'Quitar etiquetas de las inmersiones seleccionadas';

  @override
  String diveLog_bulkEdit_removedFromTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones quitadas',
      one: 'inmersión quitada',
    );
    return '$count $_temp0 del viaje';
  }

  @override
  String get diveLog_bulkEdit_selectTrip => 'Seleccionar viaje';

  @override
  String diveLog_bulkEdit_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones',
      one: 'inmersión',
    );
    return 'Editar $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_csv => 'CSV';

  @override
  String get diveLog_bulkExport_csvDescription => 'Formato de hoja de cálculo';

  @override
  String diveLog_bulkExport_failed(Object error) {
    return 'Error en la exportación: $error';
  }

  @override
  String get diveLog_bulkExport_pdf => 'Registro PDF';

  @override
  String get diveLog_bulkExport_pdfDescription =>
      'Páginas de registro de buceo imprimibles';

  @override
  String diveLog_bulkExport_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones exportadas',
      one: 'inmersión exportada',
    );
    return '$count $_temp0 correctamente';
  }

  @override
  String diveLog_bulkExport_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones',
      one: 'inmersión',
    );
    return 'Exportar $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_uddf => 'UDDF';

  @override
  String get diveLog_bulkExport_uddfDescription =>
      'Formato Universal de Datos de Buceo';

  @override
  String get diveLog_ccr_diluent_air => 'Aire';

  @override
  String get diveLog_ccr_hint_loopVolume => 'ej., 6.0';

  @override
  String get diveLog_ccr_hint_type => 'ej., Sofnolime';

  @override
  String get diveLog_ccr_label_deco => 'Deco';

  @override
  String get diveLog_ccr_label_he => 'He';

  @override
  String get diveLog_ccr_label_highBottom => 'Alto (fondo)';

  @override
  String get diveLog_ccr_label_loopVolume => 'Volumen del circuito';

  @override
  String get diveLog_ccr_label_lowDescAsc => 'Bajo (desc/asc)';

  @override
  String get diveLog_ccr_label_n2 => 'N₂';

  @override
  String get diveLog_ccr_label_o2 => 'O₂';

  @override
  String get diveLog_ccr_label_rated => 'Capacidad nominal';

  @override
  String get diveLog_ccr_label_remaining => 'Restante';

  @override
  String get diveLog_ccr_label_type => 'Tipo';

  @override
  String get diveLog_ccr_sectionDiluentGas => 'Gas diluyente';

  @override
  String get diveLog_ccr_sectionScrubber => 'Absorbente';

  @override
  String get diveLog_ccr_sectionSetpoints => 'Setpoints (bar)';

  @override
  String get diveLog_ccr_title => 'Configuración CCR';

  @override
  String diveLog_collapsible_semantics_collapse(Object title) {
    return 'Contraer sección $title';
  }

  @override
  String diveLog_collapsible_semantics_expand(Object title) {
    return 'Expandir sección $title';
  }

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return 'Prom: $depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => 'Básico';

  @override
  String get diveLog_cylinderSac_noSac => 'SAC: --';

  @override
  String get diveLog_cylinderSac_tooltip_aiData =>
      'Usando datos del transmisor AI para mayor precisión';

  @override
  String get diveLog_cylinderSac_tooltip_basicData =>
      'Calculado a partir de presiones inicial/final';

  @override
  String get diveLog_deco_badge_deco => 'DECO';

  @override
  String get diveLog_deco_badge_noDeco => 'SIN DECO';

  @override
  String get diveLog_deco_label_ceiling => 'Techo';

  @override
  String get diveLog_deco_label_leading => 'Dominante';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String get diveLog_deco_sectionDecoStops => 'Paradas de descompresión';

  @override
  String get diveLog_deco_sectionTissueLoading => 'Carga tisular';

  @override
  String get diveLog_deco_semantics_notRequired =>
      'No se requiere descompresión';

  @override
  String get diveLog_deco_semantics_required => 'Se requiere descompresión';

  @override
  String get diveLog_deco_tissueFast => 'Rápido';

  @override
  String get diveLog_deco_tissueSlow => 'Lento';

  @override
  String get diveLog_deco_title => 'Estado de descompresión';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return 'Total: $time';
  }

  @override
  String get diveLog_delete_cancel => 'Cancelar';

  @override
  String get diveLog_delete_confirm =>
      'Esta acción no se puede deshacer. La inmersión y todos los datos asociados (perfil, tanques, avistamientos) se eliminarán permanentemente.';

  @override
  String get diveLog_delete_delete => 'Eliminar';

  @override
  String get diveLog_delete_title => '¿Eliminar inmersión?';

  @override
  String get diveLog_detail_appBar => 'Detalles de la inmersión';

  @override
  String get diveLog_detail_badge_critical => 'CRÍTICO';

  @override
  String get diveLog_detail_badge_deco => 'DECO';

  @override
  String get diveLog_detail_badge_noDeco => 'SIN DECO';

  @override
  String get diveLog_detail_badge_warning => 'ADVERTENCIA';

  @override
  String diveLog_detail_buddyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'compañeros',
      one: 'compañero',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_button_playback => 'Reproducción';

  @override
  String get diveLog_detail_button_rangeAnalysis => 'Análisis de rango';

  @override
  String get diveLog_detail_button_showEnd => 'Mostrar final';

  @override
  String get diveLog_detail_captureSignature => 'Capturar firma del instructor';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return 'A las $timestamp';
  }

  @override
  String diveLog_detail_collapsed_atTimeInfo(
    Object timestamp,
    Object baseInfo,
  ) {
    return 'A las $timestamp • $baseInfo';
  }

  @override
  String diveLog_detail_collapsed_ceiling(Object value) {
    return 'Techo: $value';
  }

  @override
  String diveLog_detail_collapsed_cnsMaxPpO2(Object cns, Object maxPpO2) {
    return 'CNS: $cns • Máx ppO₂: $maxPpO2';
  }

  @override
  String diveLog_detail_collapsed_cnsMaxPpO2AtTime(
    Object cns,
    Object maxPpO2,
    Object timestamp,
    Object ppO2,
  ) {
    return 'CNS: $cns • Máx ppO₂: $maxPpO2 • A las $timestamp: $ppO2 bar';
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
      other: 'elementos',
      one: 'elemento',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_errorLoading => 'Error al cargar la inmersión';

  @override
  String get diveLog_detail_fullscreen_sampleData => 'Datos de Muestra';

  @override
  String get diveLog_detail_fullscreen_tapChartCompact =>
      'Toca el gráfico para vista compacta';

  @override
  String get diveLog_detail_fullscreen_tapChartFull =>
      'Toca el gráfico para vista de pantalla completa';

  @override
  String get diveLog_detail_fullscreen_touchChart =>
      'Toca el gráfico para ver datos en ese punto';

  @override
  String get diveLog_detail_label_airTemp => 'Temp. del aire';

  @override
  String get diveLog_detail_label_avgDepth => 'Profundidad media';

  @override
  String get diveLog_detail_label_buddy => 'Compañero';

  @override
  String get diveLog_detail_label_currentDirection =>
      'Dirección de la corriente';

  @override
  String get diveLog_detail_label_currentStrength =>
      'Intensidad de la corriente';

  @override
  String get diveLog_detail_label_diveComputer => 'Ordenador de buceo';

  @override
  String get diveLog_detail_label_serialNumber => 'Serial Number';

  @override
  String get diveLog_detail_label_firmwareVersion => 'Firmware Version';

  @override
  String get diveLog_detail_label_diveMaster => 'Dive Master';

  @override
  String get diveLog_detail_label_diveType => 'Tipo de inmersión';

  @override
  String get diveLog_detail_label_elevation => 'Elevación';

  @override
  String get diveLog_detail_label_entry => 'Entrada:';

  @override
  String get diveLog_detail_label_entryMethod => 'Método de entrada';

  @override
  String get diveLog_detail_label_exit => 'Salida:';

  @override
  String get diveLog_detail_label_exitMethod => 'Método de salida';

  @override
  String get diveLog_detail_label_gradientFactors => 'Factores de gradiente';

  @override
  String get diveLog_detail_label_height => 'Altura';

  @override
  String get diveLog_detail_label_highTide => 'Marea alta';

  @override
  String get diveLog_detail_label_lowTide => 'Marea baja';

  @override
  String get diveLog_detail_label_ppO2AtPoint =>
      'ppO₂ en el punto seleccionado:';

  @override
  String get diveLog_detail_label_rateOfChange => 'Velocidad de cambio';

  @override
  String get diveLog_detail_label_sacRate => 'Consumo SAC';

  @override
  String get diveLog_detail_label_state => 'Estado';

  @override
  String get diveLog_detail_label_surfaceInterval => 'Intervalo de superficie';

  @override
  String get diveLog_detail_label_surfacePressure => 'Presión en superficie';

  @override
  String get diveLog_detail_label_swellHeight => 'Altura del oleaje';

  @override
  String get diveLog_detail_label_total => 'Total:';

  @override
  String get diveLog_detail_label_visibility => 'Visibilidad';

  @override
  String get diveLog_detail_label_waterType => 'Tipo de agua';

  @override
  String get diveLog_detail_menu_delete => 'Eliminar';

  @override
  String get diveLog_detail_menu_export => 'Exportar';

  @override
  String get diveLog_detail_menu_openFullPage => 'Abrir página completa';

  @override
  String get diveLog_detail_noNotes => 'No hay notas para esta inmersión.';

  @override
  String get diveLog_detail_notFound => 'Inmersión no encontrada';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count puntos';
  }

  @override
  String get diveLog_detail_section_altitudeDive => 'Inmersión en altitud';

  @override
  String get diveLog_detail_section_buddies => 'Compañeros';

  @override
  String get diveLog_detail_section_conditions => 'Condiciones';

  @override
  String get diveLog_detail_section_customFields => 'Custom Fields';

  @override
  String get diveLog_detail_section_decoStatus => 'Estado de descompresión';

  @override
  String get diveLog_detail_section_details => 'Detalles';

  @override
  String get diveLog_detail_section_diveProfile => 'Perfil de inmersión';

  @override
  String get diveLog_detail_section_equipment => 'Equipo';

  @override
  String get diveLog_detail_section_marineLife => 'Vida marina';

  @override
  String get diveLog_detail_section_notes => 'Notas';

  @override
  String get diveLog_detail_section_oxygenToxicity => 'Toxicidad del oxígeno';

  @override
  String get diveLog_detail_section_sacByCylinder => 'SAC por cilindro';

  @override
  String get diveLog_detail_section_sacRateBySegment =>
      'Consumo SAC por segmento';

  @override
  String get diveLog_detail_section_tags => 'Etiquetas';

  @override
  String get diveLog_detail_section_tanks => 'Tanques';

  @override
  String get diveLog_detail_section_tide => 'Marea';

  @override
  String get diveLog_detail_section_trainingSignature =>
      'Firma de entrenamiento';

  @override
  String get diveLog_detail_section_weight => 'Lastre';

  @override
  String get diveLog_detail_signatureDescription =>
      'Toca para agregar la verificación del instructor para esta inmersión de entrenamiento';

  @override
  String get diveLog_detail_soloDive =>
      'Inmersión en solitario o sin compañeros registrados';

  @override
  String diveLog_detail_speciesCount(Object count) {
    return '$count especies';
  }

  @override
  String get diveLog_detail_stat_bottomTime => 'Tiempo de fondo';

  @override
  String get diveLog_detail_stat_maxDepth => 'Profundidad máxima';

  @override
  String get diveLog_detail_stat_runtime => 'Tiempo total';

  @override
  String get diveLog_detail_stat_waterTemp => 'Temp. del agua';

  @override
  String diveLog_detail_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'etiquetas',
      one: 'etiqueta',
    );
    return '$count $_temp0';
  }

  @override
  String diveLog_detail_tankCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tanques',
      one: 'tanque',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_tideCalculated =>
      'Calculado a partir del modelo de mareas';

  @override
  String get diveLog_detail_tooltip_addToFavorites => 'Agregar a favoritos';

  @override
  String get diveLog_detail_tooltip_edit => 'Editar';

  @override
  String get diveLog_detail_tooltip_editDive => 'Editar inmersión';

  @override
  String get diveLog_detail_tooltip_exportProfileImage =>
      'Exportar perfil como imagen';

  @override
  String get diveLog_detail_tooltip_removeFromFavorites =>
      'Quitar de favoritos';

  @override
  String get diveLog_detail_tooltip_viewFullscreen =>
      'Ver en pantalla completa';

  @override
  String get diveLog_detail_viewSite => 'Ver punto de buceo';

  @override
  String get diveLog_diveMode_ccrDescription =>
      'Rebreather de circuito cerrado con ppO₂ constante';

  @override
  String get diveLog_diveMode_ocDescription =>
      'Buceo estándar de circuito abierto con tanques';

  @override
  String get diveLog_diveMode_scrDescription =>
      'Rebreather semicerrado con ppO₂ variable';

  @override
  String get diveLog_diveMode_title => 'Modo de buceo';

  @override
  String get diveLog_editSighting_count => 'Cantidad';

  @override
  String get diveLog_editSighting_notes => 'Notas';

  @override
  String get diveLog_editSighting_notesHint =>
      'Tamaño, comportamiento, ubicación...';

  @override
  String get diveLog_editSighting_remove => 'Quitar';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return '¿Quitar $name de esta inmersión?';
  }

  @override
  String get diveLog_editSighting_removeTitle => '¿Quitar avistamiento?';

  @override
  String get diveLog_editSighting_save => 'Guardar cambios';

  @override
  String get diveLog_edit_add => 'Agregar';

  @override
  String get diveLog_edit_addCustomField => 'Add Field';

  @override
  String get diveLog_edit_addTank => 'Agregar tanque';

  @override
  String get diveLog_edit_addWeightEntry => 'Agregar entrada de lastre';

  @override
  String diveLog_edit_addedGps(Object name) {
    return 'GPS agregado a $name';
  }

  @override
  String get diveLog_edit_appBarEdit => 'Editar inmersión';

  @override
  String get diveLog_edit_appBarNew => 'Registrar inmersión';

  @override
  String get diveLog_edit_cancel => 'Cancelar';

  @override
  String get diveLog_edit_clearAllEquipment => 'Limpiar todo';

  @override
  String diveLog_edit_createdSite(Object name) {
    return 'Punto de buceo creado: $name';
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
    return 'Duración: $minutes min';
  }

  @override
  String get diveLog_edit_equipmentHint =>
      'Toca \"Usar conjunto\" o \"Agregar\" para seleccionar equipo';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return 'Error al cargar tipos de inmersión: $error';
  }

  @override
  String get diveLog_edit_gettingLocation => 'Obteniendo ubicación...';

  @override
  String get diveLog_edit_headerNew => 'Registrar nueva inmersión';

  @override
  String get diveLog_edit_label_airTemp => 'Temp. del aire';

  @override
  String get diveLog_edit_label_altitude => 'Altitud';

  @override
  String get diveLog_edit_label_avgDepth => 'Profundidad media';

  @override
  String get diveLog_edit_label_bottomTime => 'Tiempo de fondo';

  @override
  String get diveLog_edit_label_currentDirection => 'Dirección de la corriente';

  @override
  String get diveLog_edit_label_currentStrength => 'Intensidad de la corriente';

  @override
  String get diveLog_edit_label_diveType => 'Tipo de inmersión';

  @override
  String get diveLog_edit_label_entryMethod => 'Método de entrada';

  @override
  String get diveLog_edit_label_exitMethod => 'Método de salida';

  @override
  String get diveLog_edit_label_maxDepth => 'Profundidad máxima';

  @override
  String get diveLog_edit_label_runtime => 'Tiempo total';

  @override
  String get diveLog_edit_label_surfacePressure => 'Presión en superficie';

  @override
  String get diveLog_edit_label_swellHeight => 'Altura del oleaje';

  @override
  String get diveLog_edit_label_type => 'Tipo';

  @override
  String get diveLog_edit_label_visibility => 'Visibilidad';

  @override
  String get diveLog_edit_label_waterTemp => 'Temp. del agua';

  @override
  String get diveLog_edit_label_waterType => 'Tipo de agua';

  @override
  String get diveLog_edit_marineLifeHint =>
      'Toca \"Agregar\" para registrar avistamientos';

  @override
  String get diveLog_edit_nearbySitesFirst => 'Puntos cercanos primero';

  @override
  String get diveLog_edit_noEquipmentSelected => 'No se ha seleccionado equipo';

  @override
  String get diveLog_edit_noMarineLife => 'No se registró vida marina';

  @override
  String get diveLog_edit_notSpecified => 'No especificado';

  @override
  String get diveLog_edit_notesHint => 'Agrega notas sobre esta inmersión...';

  @override
  String get diveLog_edit_save => 'Guardar';

  @override
  String get diveLog_edit_saveAsSet => 'Guardar como conjunto';

  @override
  String diveLog_edit_saveAsSetDialog_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'elementos',
      one: 'elemento',
    );
    return 'Guardar $count $_temp0 como un nuevo conjunto de equipo.';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description =>
      'Descripción (opcional)';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint =>
      'ej., Equipo ligero para aguas cálidas';

  @override
  String diveLog_edit_saveAsSetDialog_error(Object error) {
    return 'Error al crear el conjunto: $error';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_setName => 'Nombre del conjunto';

  @override
  String get diveLog_edit_saveAsSetDialog_setNameHint => 'ej., Buceo tropical';

  @override
  String diveLog_edit_saveAsSetDialog_success(Object name) {
    return 'Conjunto de equipo \"$name\" creado';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title =>
      'Guardar como conjunto de equipo';

  @override
  String get diveLog_edit_saveAsSetDialog_validation =>
      'Por favor ingresa un nombre para el conjunto';

  @override
  String get diveLog_edit_section_conditions => 'Condiciones';

  @override
  String get diveLog_edit_section_customFields => 'Custom Fields';

  @override
  String get diveLog_edit_section_depthDuration => 'Profundidad y duración';

  @override
  String get diveLog_edit_section_diveCenter => 'Centro de buceo';

  @override
  String get diveLog_edit_section_diveSite => 'Punto de buceo';

  @override
  String get diveLog_edit_section_entryTime => 'Hora de entrada';

  @override
  String get diveLog_edit_section_equipment => 'Equipo';

  @override
  String get diveLog_edit_section_exitTime => 'Hora de salida';

  @override
  String get diveLog_edit_section_marineLife => 'Vida marina';

  @override
  String get diveLog_edit_section_notes => 'Notas';

  @override
  String get diveLog_edit_section_rating => 'Valoración';

  @override
  String get diveLog_edit_section_tags => 'Etiquetas';

  @override
  String diveLog_edit_section_tanks(Object count) {
    return 'Tanques ($count)';
  }

  @override
  String get diveLog_edit_section_trainingCourse => 'Curso de formación';

  @override
  String get diveLog_edit_section_trip => 'Viaje';

  @override
  String get diveLog_edit_section_weight => 'Lastre';

  @override
  String get diveLog_edit_select => 'Seleccionar';

  @override
  String get diveLog_edit_selectDiveCenter => 'Seleccionar centro de buceo';

  @override
  String get diveLog_edit_selectDiveSite => 'Seleccionar punto de buceo';

  @override
  String get diveLog_edit_selectTrip => 'Seleccionar viaje';

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Tiempo de fondo calculado: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Error al guardar la inmersión: $error';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'No hay datos de perfil de inmersión disponibles';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'No se pudo calcular el tiempo de fondo a partir del perfil';

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return 'Intervalo de superficie: $interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint =>
      'Estándar: 1013 mbar a nivel del mar';

  @override
  String get diveLog_edit_tooltip_calculateFromProfile =>
      'Calcular desde el perfil de inmersión';

  @override
  String get diveLog_edit_tooltip_clearDiveCenter => 'Borrar centro de buceo';

  @override
  String get diveLog_edit_tooltip_clearSite => 'Borrar punto de buceo';

  @override
  String get diveLog_edit_tooltip_clearTrip => 'Borrar viaje';

  @override
  String get diveLog_edit_tooltip_removeEquipment => 'Quitar equipo';

  @override
  String get diveLog_edit_tooltip_removeSighting => 'Quitar avistamiento';

  @override
  String get diveLog_edit_tooltip_removeWeight => 'Quitar';

  @override
  String get diveLog_edit_trainingCourseHint =>
      'Vincular esta inmersión a un curso de formación';

  @override
  String diveLog_edit_tripSuggested(Object name) {
    return 'Sugerido: $name';
  }

  @override
  String get diveLog_edit_tripUse => 'Usar';

  @override
  String get diveLog_edit_useSet => 'Usar conjunto';

  @override
  String diveLog_edit_weightTotal(Object total) {
    return 'Total: $total';
  }

  @override
  String get diveLog_emptyFiltered_clearFilters => 'Borrar filtros';

  @override
  String get diveLog_emptyFiltered_subtitle =>
      'Intenta ajustar o borrar tus filtros';

  @override
  String get diveLog_emptyFiltered_title =>
      'Ninguna inmersión coincide con tus filtros';

  @override
  String get diveLog_empty_logFirstDive => 'Registra tu primera inmersión';

  @override
  String get diveLog_empty_subtitle =>
      'Toca el botón de abajo para registrar tu primera inmersión';

  @override
  String get diveLog_empty_title => 'Aún no hay inmersiones registradas';

  @override
  String get diveLog_equipmentPicker_addFromTab =>
      'Agrega equipo desde la pestaña de Equipo';

  @override
  String get diveLog_equipmentPicker_allSelected =>
      'Todo el equipo ya está seleccionado';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return 'Error al cargar equipo: $error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => 'Aún no hay equipo';

  @override
  String get diveLog_equipmentPicker_removeToAdd =>
      'Quita elementos para agregar otros diferentes';

  @override
  String get diveLog_equipmentPicker_title => 'Agregar equipo';

  @override
  String get diveLog_equipmentSetPicker_createHint =>
      'Crea conjuntos en Equipo > Conjuntos';

  @override
  String get diveLog_equipmentSetPicker_emptySet => 'Conjunto vacío';

  @override
  String get diveLog_equipmentSetPicker_errorItems =>
      'Error al cargar elementos';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return 'Error al cargar conjuntos de equipo: $error';
  }

  @override
  String get diveLog_equipmentSetPicker_loading => 'Cargando...';

  @override
  String get diveLog_equipmentSetPicker_noSets =>
      'Aún no hay conjuntos de equipo';

  @override
  String get diveLog_equipmentSetPicker_title => 'Usar conjunto de equipo';

  @override
  String get diveLog_error_loadingDives => 'Error al cargar inmersiones';

  @override
  String get diveLog_error_retry => 'Reintentar';

  @override
  String get diveLog_exportImage_captureFailed =>
      'No se pudo capturar la imagen';

  @override
  String get diveLog_exportImage_generateFailed =>
      'No se pudo generar la imagen';

  @override
  String get diveLog_exportImage_generatingPdf => 'Generando PDF...';

  @override
  String get diveLog_exportImage_pdfSaved => 'PDF guardado';

  @override
  String get diveLog_exportImage_saveToFiles => 'Guardar en Archivos';

  @override
  String get diveLog_exportImage_saveToFilesDescription =>
      'Elige una ubicación para guardar el archivo';

  @override
  String get diveLog_exportImage_saveToPhotos => 'Guardar en Fotos';

  @override
  String get diveLog_exportImage_saveToPhotosDescription =>
      'Guardar imagen en tu biblioteca de fotos';

  @override
  String get diveLog_exportImage_savedToFiles => 'Imagen guardada';

  @override
  String get diveLog_exportImage_savedToPhotos => 'Imagen guardada en Fotos';

  @override
  String get diveLog_exportImage_share => 'Compartir';

  @override
  String get diveLog_exportImage_shareDescription =>
      'Compartir a través de otras aplicaciones';

  @override
  String get diveLog_exportImage_titleDetails =>
      'Exportar imagen de detalles de inmersión';

  @override
  String get diveLog_exportImage_titlePdf => 'Exportar PDF';

  @override
  String get diveLog_exportImage_titleProfile => 'Exportar imagen de perfil';

  @override
  String get diveLog_export_csv => 'CSV';

  @override
  String get diveLog_export_csvDescription => 'Formato de hoja de cálculo';

  @override
  String get diveLog_export_exporting => 'Exportando...';

  @override
  String diveLog_export_failed(Object error) {
    return 'Error en la exportación: $error';
  }

  @override
  String get diveLog_export_pageAsImage => 'Página como imagen';

  @override
  String get diveLog_export_pageAsImageDescription =>
      'Captura de pantalla de todos los detalles de la inmersión';

  @override
  String get diveLog_export_pdfDescription =>
      'Página de registro de buceo imprimible';

  @override
  String get diveLog_export_pdfLogbookEntry => 'Entrada de registro PDF';

  @override
  String get diveLog_export_success => 'Inmersión exportada correctamente';

  @override
  String diveLog_export_titleDiveNumber(Object number) {
    return 'Exportar inmersión #$number';
  }

  @override
  String get diveLog_export_uddf => 'UDDF';

  @override
  String get diveLog_export_uddfDescription =>
      'Formato Universal de Datos de Buceo';

  @override
  String get diveLog_filterChip_clearAll => 'Borrar todo';

  @override
  String get diveLog_filterChip_favorites => 'Favoritos';

  @override
  String diveLog_filterChip_from(Object date) {
    return 'Desde $date';
  }

  @override
  String diveLog_filterChip_until(Object date) {
    return 'Hasta $date';
  }

  @override
  String get diveLog_filter_allSites => 'Todos los puntos';

  @override
  String get diveLog_filter_allTypes => 'Todos los tipos';

  @override
  String get diveLog_filter_apply => 'Aplicar filtros';

  @override
  String get diveLog_filter_buddyHint => 'Buscar por nombre del compañero';

  @override
  String get diveLog_filter_buddyName => 'Nombre del compañero';

  @override
  String get diveLog_filter_clearAll => 'Borrar todo';

  @override
  String get diveLog_filter_clearDates => 'Borrar fechas';

  @override
  String get diveLog_filter_clearRating => 'Borrar filtro de valoración';

  @override
  String get diveLog_filter_dateSeparator => 'hasta';

  @override
  String get diveLog_filter_endDate => 'Fecha de fin';

  @override
  String get diveLog_filter_errorLoadingSites =>
      'Error al cargar puntos de buceo';

  @override
  String get diveLog_filter_errorLoadingTags => 'Error al cargar etiquetas';

  @override
  String get diveLog_filter_favoritesOnly => 'Solo favoritos';

  @override
  String get diveLog_filter_gasAir => 'Aire (21%)';

  @override
  String get diveLog_filter_gasAll => 'Todos';

  @override
  String get diveLog_filter_gasNitrox => 'Nitrox (>21%)';

  @override
  String get diveLog_filter_max => 'Máx';

  @override
  String get diveLog_filter_min => 'Mín';

  @override
  String get diveLog_filter_noTagsYet => 'Aún no se han creado etiquetas';

  @override
  String get diveLog_filter_sectionBuddy => 'Compañero';

  @override
  String get diveLog_filter_sectionDateRange => 'Rango de fechas';

  @override
  String get diveLog_filter_sectionDepthRange =>
      'Rango de profundidad (metros)';

  @override
  String get diveLog_filter_sectionDiveSite => 'Punto de buceo';

  @override
  String get diveLog_filter_sectionDiveType => 'Tipo de inmersión';

  @override
  String get diveLog_filter_sectionDuration => 'Duración (minutos)';

  @override
  String get diveLog_filter_sectionGasMix => 'Mezcla de gas (O₂%)';

  @override
  String get diveLog_filter_sectionMinRating => 'Valoración mínima';

  @override
  String get diveLog_filter_sectionTags => 'Etiquetas';

  @override
  String get diveLog_filter_showOnlyFavorites =>
      'Mostrar solo inmersiones favoritas';

  @override
  String get diveLog_filter_startDate => 'Fecha de inicio';

  @override
  String get diveLog_filter_title => 'Filtrar inmersiones';

  @override
  String get diveLog_filter_tooltip_close => 'Cerrar filtro';

  @override
  String get diveLog_fullscreenProfile_close => 'Cerrar pantalla completa';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Perfil de inmersión #$number';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Velocidad de ascenso';

  @override
  String get diveLog_legend_label_ceiling => 'Techo';

  @override
  String get diveLog_legend_label_depth => 'Profundidad';

  @override
  String get diveLog_legend_label_events => 'Eventos';

  @override
  String get diveLog_legend_label_gasDensity => 'Densidad del gas';

  @override
  String get diveLog_legend_label_gasSwitches => 'Cambios de gas';

  @override
  String get diveLog_legend_label_gfPercent => 'GF%';

  @override
  String get diveLog_legend_label_heartRate => 'Frecuencia cardíaca';

  @override
  String get diveLog_legend_label_maxDepth => 'Profundidad máxima';

  @override
  String get diveLog_legend_label_meanDepth => 'Profundidad media';

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
  String get diveLog_legend_label_pressure => 'Presión';

  @override
  String get diveLog_legend_label_pressureThresholds => 'Umbrales de presión';

  @override
  String get diveLog_legend_label_sacRate => 'Consumo SAC';

  @override
  String get diveLog_legend_label_surfaceGf => 'GF en superficie';

  @override
  String get diveLog_legend_label_temp => 'Temp';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Mapa de inmersiones';

  @override
  String get diveLog_listPage_compactTitle => 'Inmersiones';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Error: $error';
  }

  @override
  String get diveLog_listPage_fab_logDive => 'Registrar inmersión';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Búsqueda avanzada';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Numeración de inmersiones';

  @override
  String get diveLog_listPage_searchFieldLabel => 'Buscar inmersiones...';

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return 'No se encontraron inmersiones para \"$query\"';
  }

  @override
  String get diveLog_listPage_searchSuggestion =>
      'Buscar por punto, compañero o notas';

  @override
  String get diveLog_listPage_title => 'Registro de buceo';

  @override
  String get diveLog_listPage_tooltip_back => 'Atrás';

  @override
  String get diveLog_listPage_tooltip_backToDiveList =>
      'Volver a la lista de inmersiones';

  @override
  String get diveLog_listPage_tooltip_clearSearch => 'Borrar búsqueda';

  @override
  String get diveLog_listPage_tooltip_filterDives => 'Filtrar inmersiones';

  @override
  String get diveLog_listPage_tooltip_listView => 'Vista de lista';

  @override
  String get diveLog_listPage_tooltip_mapView => 'Vista de mapa';

  @override
  String get diveLog_listPage_tooltip_searchDives => 'Buscar inmersiones';

  @override
  String get diveLog_listPage_tooltip_sort => 'Ordenar';

  @override
  String get diveLog_listPage_unknownSite => 'Punto desconocido';

  @override
  String get diveLog_map_emptySubtitle =>
      'Registra inmersiones con datos de ubicación para ver tu actividad en el mapa';

  @override
  String get diveLog_map_emptyTitle => 'No hay actividad de buceo para mostrar';

  @override
  String diveLog_map_errorLoading(Object error) {
    return 'Error al cargar datos de inmersiones: $error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => 'Ajustar a todos los puntos';

  @override
  String get diveLog_numbering_actions => 'Acciones';

  @override
  String get diveLog_numbering_allCorrect =>
      'Todas las inmersiones están numeradas correctamente';

  @override
  String get diveLog_numbering_assignMissing => 'Asignar números faltantes';

  @override
  String get diveLog_numbering_assignMissingDesc =>
      'Numerar inmersiones sin numerar a partir de la última inmersión numerada';

  @override
  String get diveLog_numbering_close => 'Cerrar';

  @override
  String get diveLog_numbering_gapsDetected => 'Saltos detectados';

  @override
  String get diveLog_numbering_issuesDetected => 'Problemas detectados';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '$count faltantes';
  }

  @override
  String get diveLog_numbering_renumberAll => 'Renumerar todas las inmersiones';

  @override
  String get diveLog_numbering_renumberAllDesc =>
      'Asignar números secuenciales basados en la fecha/hora de la inmersión';

  @override
  String get diveLog_numbering_renumberDialog_cancel => 'Cancelar';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      'Esto renumerará todas las inmersiones secuencialmente según su fecha/hora de entrada. Esta acción no se puede deshacer.';

  @override
  String get diveLog_numbering_renumberDialog_renumber => 'Renumerar';

  @override
  String get diveLog_numbering_renumberDialog_startFrom =>
      'Comenzar desde el número';

  @override
  String get diveLog_numbering_renumberDialog_title =>
      'Renumerar todas las inmersiones';

  @override
  String get diveLog_numbering_snackbar_assigned =>
      'Números de inmersión faltantes asignados';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return 'Todas las inmersiones renumeradas a partir del #$number';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '$total inmersiones en total • $numbered numeradas';
  }

  @override
  String get diveLog_numbering_title => 'Numeración de inmersiones';

  @override
  String diveLog_numbering_unnumberedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones',
      one: 'inmersión',
    );
    return '$count $_temp0 sin numerar';
  }

  @override
  String get diveLog_o2tox_badge_critical => 'CRÍTICO';

  @override
  String get diveLog_o2tox_badge_warning => 'ADVERTENCIA';

  @override
  String diveLog_o2tox_cnsBadgeLabel(Object value) {
    return 'CNS $value';
  }

  @override
  String get diveLog_o2tox_cnsOxygenClock => 'Reloj de oxígeno CNS';

  @override
  String diveLog_o2tox_deltaDive(Object value) {
    return '+$value% esta inmersión';
  }

  @override
  String get diveLog_o2tox_details => 'Detalles';

  @override
  String get diveLog_o2tox_label_maxPpO2 => 'ppO2 máximo';

  @override
  String get diveLog_o2tox_label_maxPpO2Depth => 'Profundidad del ppO2 máximo';

  @override
  String get diveLog_o2tox_label_timeAbove14 => 'Tiempo por encima de 1.4 bar';

  @override
  String get diveLog_o2tox_label_timeAbove16 => 'Tiempo por encima de 1.6 bar';

  @override
  String get diveLog_o2tox_ofDailyLimit => 'del límite diario';

  @override
  String get diveLog_o2tox_oxygenToleranceUnits =>
      'Unidades de tolerancia al oxígeno';

  @override
  String diveLog_o2tox_semantics_cnsBadge(Object value) {
    return 'Toxicidad por oxígeno CNS $value';
  }

  @override
  String get diveLog_o2tox_semantics_criticalWarning =>
      'Advertencia crítica de toxicidad del oxígeno';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return 'Unidades de Tolerancia al Oxígeno: $value, $percent por ciento del límite diario';
  }

  @override
  String get diveLog_o2tox_semantics_warning =>
      'Advertencia de toxicidad del oxígeno';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return 'Inicio: $value%';
  }

  @override
  String get diveLog_o2tox_title => 'Toxicidad del oxígeno';

  @override
  String get diveLog_playbackStats_deco => 'DECO';

  @override
  String get diveLog_playbackStats_depth => 'Profundidad';

  @override
  String get diveLog_playbackStats_header => 'Datos en vivo';

  @override
  String get diveLog_playbackStats_heartRate => 'Frecuencia cardíaca';

  @override
  String get diveLog_playbackStats_ndl => 'NDL';

  @override
  String get diveLog_playbackStats_ppO2 => 'ppO₂';

  @override
  String get diveLog_playbackStats_pressure => 'Presión';

  @override
  String get diveLog_playbackStats_temp => 'Temp';

  @override
  String get diveLog_playback_sliderLabel => 'Posición de reproducción';

  @override
  String diveLog_playback_speed_label(Object speed) {
    return '${speed}x';
  }

  @override
  String get diveLog_playback_stepThrough => 'Reproducción paso a paso';

  @override
  String get diveLog_playback_tooltip_back10 => 'Retroceder 10 segundos';

  @override
  String get diveLog_playback_tooltip_exit => 'Salir del modo de reproducción';

  @override
  String get diveLog_playback_tooltip_forward10 => 'Avanzar 10 segundos';

  @override
  String get diveLog_playback_tooltip_pause => 'Pausa';

  @override
  String get diveLog_playback_tooltip_play => 'Reproducir';

  @override
  String get diveLog_playback_tooltip_skipEnd => 'Saltar al final';

  @override
  String get diveLog_playback_tooltip_skipStart => 'Saltar al inicio';

  @override
  String get diveLog_playback_tooltip_speed => 'Velocidad de reproducción';

  @override
  String get diveLog_profileSelector_badge_primary => 'Principal';

  @override
  String get diveLog_profileSelector_label_diveComputers =>
      'Ordenadores de buceo';

  @override
  String diveLog_profile_axisDepth(Object unit) {
    return 'Profundidad ($unit)';
  }

  @override
  String get diveLog_profile_axisTime => 'Tiempo (min)';

  @override
  String get diveLog_profile_emptyState => 'Sin datos de perfil de inmersión';

  @override
  String get diveLog_profile_rightAxis_none => 'Ninguno';

  @override
  String get diveLog_profile_semantics_changeRightAxis =>
      'Cambiar métrica del eje derecho';

  @override
  String get diveLog_profile_semantics_chart =>
      'Gráfico de perfil de inmersión, pellizca para hacer zoom';

  @override
  String get diveLog_profile_tooltip_moreOptions => 'Más opciones de gráfico';

  @override
  String get diveLog_profile_tooltip_resetZoom => 'Restablecer zoom';

  @override
  String get diveLog_profile_tooltip_zoomIn => 'Acercar';

  @override
  String get diveLog_profile_tooltip_zoomOut => 'Alejar';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return 'Zoom: ${level}x • Pellizca o desplaza para hacer zoom, arrastra para mover';
  }

  @override
  String get diveLog_rangeSelection_exitRange => 'Salir del rango';

  @override
  String get diveLog_rangeSelection_selectRange => 'Seleccionar rango';

  @override
  String get diveLog_rangeSelection_semantics_adjust =>
      'Ajustar selección de rango';

  @override
  String get diveLog_rangeStats_header_avg => 'Prom';

  @override
  String get diveLog_rangeStats_header_max => 'Máx';

  @override
  String get diveLog_rangeStats_header_min => 'Mín';

  @override
  String get diveLog_rangeStats_label_depth => 'Profundidad';

  @override
  String get diveLog_rangeStats_label_heartRate => 'Frecuencia cardíaca';

  @override
  String get diveLog_rangeStats_label_pressure => 'Presión';

  @override
  String get diveLog_rangeStats_label_temp => 'Temp';

  @override
  String get diveLog_rangeStats_title => 'Análisis de rango';

  @override
  String get diveLog_rangeStats_tooltip_close => 'Cerrar análisis de rango';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return 'FO₂ calculado del circuito: $value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => 'ej., 0.33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => 'Relación de adición';

  @override
  String get diveLog_scr_label_assumedVo2 => 'VO₂ asumido';

  @override
  String get diveLog_scr_label_avg => 'Prom';

  @override
  String get diveLog_scr_label_injectionRate => 'Tasa de inyección';

  @override
  String get diveLog_scr_label_max => 'Max';

  @override
  String get diveLog_scr_label_min => 'Min';

  @override
  String get diveLog_scr_label_orificeSize => 'Tamano del orificio';

  @override
  String get diveLog_scr_sectionCmf => 'Parametros CMF';

  @override
  String get diveLog_scr_sectionEscr => 'Parametros ESCR';

  @override
  String get diveLog_scr_sectionMeasuredLoopO2 =>
      'O₂ medido en el circuito (opcional)';

  @override
  String get diveLog_scr_sectionPascr => 'Parametros PASCR';

  @override
  String get diveLog_scr_sectionScrType => 'Tipo de SCR';

  @override
  String get diveLog_scr_sectionSupplyGas => 'Gas de suministro';

  @override
  String get diveLog_scr_title => 'Configuracion SCR';

  @override
  String get diveLog_search_allCenters => 'Todos los centros';

  @override
  String get diveLog_search_allTrips => 'Todos los viajes';

  @override
  String get diveLog_search_appBar => 'Busqueda avanzada';

  @override
  String get diveLog_search_cancel => 'Cancelar';

  @override
  String get diveLog_search_clearAll => 'Borrar todo';

  @override
  String get diveLog_search_customFieldKey => 'Custom Field Key';

  @override
  String get diveLog_search_customFieldValue => 'Value contains...';

  @override
  String get diveLog_search_end => 'Fin';

  @override
  String get diveLog_search_errorLoadingCenters =>
      'Error al cargar los centros de buceo';

  @override
  String get diveLog_search_errorLoadingDiveTypes =>
      'Error al cargar tipos de inmersión';

  @override
  String get diveLog_search_errorLoadingTrips => 'Error al cargar los viajes';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_depthRange => 'Rango de profundidad (m)';

  @override
  String get diveLog_search_label_diveCenter => 'Centro de buceo';

  @override
  String get diveLog_search_label_diveSite => 'Punto de buceo';

  @override
  String get diveLog_search_label_diveType => 'Tipo de inmersion';

  @override
  String get diveLog_search_label_durationRange => 'Rango de duracion (min)';

  @override
  String get diveLog_search_label_trip => 'Viaje';

  @override
  String get diveLog_search_search => 'Buscar';

  @override
  String get diveLog_search_section_conditions => 'Condiciones';

  @override
  String get diveLog_search_section_dateRange => 'Rango de fechas';

  @override
  String get diveLog_search_section_gasEquipment => 'Gas y equipo';

  @override
  String get diveLog_search_section_location => 'Ubicacion';

  @override
  String get diveLog_search_section_organization => 'Organizacion';

  @override
  String get diveLog_search_section_social => 'Social';

  @override
  String get diveLog_search_start => 'Inicio';

  @override
  String diveLog_selection_countSelected(Object count) {
    return '$count seleccionados';
  }

  @override
  String get diveLog_selection_tooltip_delete => 'Eliminar seleccionados';

  @override
  String get diveLog_selection_tooltip_deselectAll => 'Deseleccionar todo';

  @override
  String get diveLog_selection_tooltip_edit => 'Editar seleccionados';

  @override
  String get diveLog_selection_tooltip_exit => 'Salir de la seleccion';

  @override
  String get diveLog_selection_tooltip_export => 'Exportar seleccionados';

  @override
  String get diveLog_selection_tooltip_selectAll => 'Seleccionar todo';

  @override
  String get diveLog_sighting_add => 'Agregar';

  @override
  String get diveLog_sighting_cancel => 'Cancelar';

  @override
  String get diveLog_sighting_notesHint =>
      'p. ej., tamano, comportamiento, ubicacion...';

  @override
  String get diveLog_sighting_notesOptional => 'Notas (opcional)';

  @override
  String get diveLog_sitePicker_addDiveSite => 'Agregar punto de buceo';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return 'a $distance km';
  }

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return 'a $distance m';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return 'Error al cargar los sitios: $error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => 'Nuevo punto de buceo';

  @override
  String get diveLog_sitePicker_noSites => 'Aun no hay puntos de buceo';

  @override
  String get diveLog_sitePicker_sortedByDistance => 'Ordenados por distancia';

  @override
  String get diveLog_sitePicker_title => 'Seleccionar punto de buceo';

  @override
  String get diveLog_sort_title => 'Ordenar inmersiones';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return 'Agregar \"$name\" como nueva especie';
  }

  @override
  String get diveLog_speciesPicker_noResults => 'No se encontraron especies';

  @override
  String get diveLog_speciesPicker_noSpecies => 'No hay especies disponibles';

  @override
  String get diveLog_speciesPicker_searchHint => 'Buscar especies...';

  @override
  String get diveLog_speciesPicker_title => 'Agregar vida marina';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch => 'Borrar busqueda';

  @override
  String get diveLog_summary_action_importComputer =>
      'Importar desde computadora';

  @override
  String get diveLog_summary_action_logDive => 'Registrar inmersion';

  @override
  String get diveLog_summary_action_viewStats => 'Ver estadisticas';

  @override
  String diveLog_summary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones',
      one: 'inmersion',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_summary_overview => 'Resumen';

  @override
  String get diveLog_summary_record_coldest => 'Inmersion mas fria';

  @override
  String get diveLog_summary_record_deepest => 'Inmersion mas profunda';

  @override
  String get diveLog_summary_record_longest => 'Inmersion mas larga';

  @override
  String get diveLog_summary_record_warmest => 'Inmersion mas calida';

  @override
  String get diveLog_summary_section_mostVisited => 'Sitios mas visitados';

  @override
  String get diveLog_summary_section_quickActions => 'Acciones rapidas';

  @override
  String get diveLog_summary_section_records => 'Records personales';

  @override
  String get diveLog_summary_selectDive =>
      'Selecciona una inmersion de la lista para ver los detalles';

  @override
  String get diveLog_summary_stat_avgMaxDepth => 'Prof. max. promedio';

  @override
  String get diveLog_summary_stat_avgWaterTemp => 'Temp. agua promedio';

  @override
  String get diveLog_summary_stat_diveSites => 'Puntos de buceo';

  @override
  String get diveLog_summary_stat_diveTime => 'Tiempo de inmersion';

  @override
  String get diveLog_summary_stat_maxDepth => 'Prof. maxima';

  @override
  String get diveLog_summary_stat_totalDives => 'Total de inmersiones';

  @override
  String get diveLog_summary_title => 'Resumen del registro de buceo';

  @override
  String get diveLog_tank_label_endPressure => 'Presion final';

  @override
  String get diveLog_tank_label_he => 'He';

  @override
  String get diveLog_tank_label_material => 'Material';

  @override
  String get diveLog_tank_label_n2 => 'N2';

  @override
  String get diveLog_tank_label_o2 => 'O2';

  @override
  String get diveLog_tank_label_role => 'Funcion';

  @override
  String get diveLog_tank_label_startPressure => 'Presion inicial';

  @override
  String get diveLog_tank_label_tankPreset => 'Preajuste de tanque';

  @override
  String get diveLog_tank_label_volume => 'Volumen';

  @override
  String get diveLog_tank_label_workingPressure => 'Presion trab.';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Mezcla de gas';

  @override
  String get diveLog_tank_selectPreset => 'Seleccionar preajuste...';

  @override
  String diveLog_tank_title(Object number) {
    return 'Tanque $number';
  }

  @override
  String get diveLog_tank_tooltip_remove => 'Eliminar tanque';

  @override
  String get diveLog_tissue_label_ceiling => 'Techo';

  @override
  String get diveLog_tissue_label_gf => 'GF';

  @override
  String get diveLog_tissue_label_ndl => 'NDL';

  @override
  String get diveLog_tissue_label_tts => 'TTS';

  @override
  String get diveLog_tissue_legend_he => 'He';

  @override
  String get diveLog_tissue_legend_mValue => '100% valor M';

  @override
  String get diveLog_tissue_legend_n2 => 'N₂';

  @override
  String get diveLog_tissue_title => 'Carga tisular';

  @override
  String get diveLog_tooltip_ceiling => 'Techo';

  @override
  String get diveLog_tooltip_density => 'Densidad';

  @override
  String get diveLog_tooltip_depth => 'Profundidad';

  @override
  String get diveLog_tooltip_gfPercent => 'GF%';

  @override
  String get diveLog_tooltip_hr => 'FC';

  @override
  String get diveLog_tooltip_marker => 'Marcador';

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
  String get diveLog_tooltip_press => 'Presion';

  @override
  String get diveLog_tooltip_rate => 'Velocidad';

  @override
  String get diveLog_tooltip_sac => 'SAC';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Tiempo';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get divePlanner_action_addTank => 'Agregar Botella';

  @override
  String get divePlanner_action_convertToDive => 'Convertir a Inmersión';

  @override
  String get divePlanner_action_editTank => 'Editar Botella';

  @override
  String get divePlanner_action_moreOptions => 'Más opciones';

  @override
  String get divePlanner_action_quickPlan => 'Plan Rápido';

  @override
  String get divePlanner_action_renamePlan => 'Renombrar Plan';

  @override
  String get divePlanner_action_reset => 'Restablecer';

  @override
  String get divePlanner_action_resetPlan => 'Restablecer Plan';

  @override
  String get divePlanner_action_savePlan => 'Guardar Plan';

  @override
  String get divePlanner_error_cannotConvert =>
      'No se puede convertir: el plan tiene advertencias críticas';

  @override
  String get divePlanner_field_hePercent => 'He %';

  @override
  String get divePlanner_field_name => 'Nombre';

  @override
  String get divePlanner_field_o2Percent => 'O₂ %';

  @override
  String get divePlanner_field_planName => 'Nombre del Plan';

  @override
  String get divePlanner_field_role => 'Rol';

  @override
  String divePlanner_field_startPressure(Object pressureSymbol) {
    return 'Inicio ($pressureSymbol)';
  }

  @override
  String divePlanner_field_volume(Object volumeSymbol) {
    return 'Volumen ($volumeSymbol)';
  }

  @override
  String get divePlanner_hint_tankName => 'Ingresa el nombre de la botella';

  @override
  String get divePlanner_label_altitude => 'Altitud:';

  @override
  String get divePlanner_label_belowMinReserve =>
      'Por Debajo de Reserva Mínima';

  @override
  String get divePlanner_label_ceiling => 'Techo';

  @override
  String get divePlanner_label_consumption => 'Consumo';

  @override
  String get divePlanner_label_deco => 'DECO';

  @override
  String get divePlanner_label_decoSchedule => 'Programa de Descompresión';

  @override
  String get divePlanner_label_decompression => 'Descompresión';

  @override
  String divePlanner_label_depthAxis(Object depthSymbol) {
    return 'Profundidad ($depthSymbol)';
  }

  @override
  String get divePlanner_label_diveProfile => 'Perfil de Inmersión';

  @override
  String get divePlanner_label_empty => 'VACÍO';

  @override
  String get divePlanner_label_gasConsumption => 'Consumo de Gas';

  @override
  String get divePlanner_label_gfHigh => 'GF Alto';

  @override
  String get divePlanner_label_gfLow => 'GF Bajo';

  @override
  String get divePlanner_label_max => 'Máx';

  @override
  String get divePlanner_label_ndl => 'NDL';

  @override
  String get divePlanner_label_planSettings => 'Configuración del Plan';

  @override
  String get divePlanner_label_remaining => 'Restante';

  @override
  String get divePlanner_label_runtime => 'Tiempo Total';

  @override
  String get divePlanner_label_sacRate => 'Tasa SAC:';

  @override
  String get divePlanner_label_status => 'Estado';

  @override
  String get divePlanner_label_tanks => 'Botellas';

  @override
  String get divePlanner_label_time => 'Tiempo';

  @override
  String get divePlanner_label_timeAxis => 'Tiempo (min)';

  @override
  String get divePlanner_label_tts => 'TTS';

  @override
  String get divePlanner_label_used => 'Usado';

  @override
  String get divePlanner_label_warnings => 'Advertencias';

  @override
  String get divePlanner_legend_ascent => 'Ascenso';

  @override
  String get divePlanner_legend_bottom => 'Fondo';

  @override
  String get divePlanner_legend_deco => 'Deco';

  @override
  String get divePlanner_legend_descent => 'Descenso';

  @override
  String get divePlanner_legend_safety => 'Seguridad';

  @override
  String get divePlanner_message_addSegmentsForGas =>
      'Agrega segmentos para ver proyecciones de gas';

  @override
  String get divePlanner_message_addSegmentsForProfile =>
      'Agrega segmentos para ver el perfil de inmersión';

  @override
  String get divePlanner_message_convertingPlan =>
      'Convirtiendo plan a inmersión...';

  @override
  String get divePlanner_message_noProfile => 'No hay perfil para mostrar';

  @override
  String get divePlanner_message_planSaved => 'Plan guardado';

  @override
  String get divePlanner_message_resetConfirmation =>
      '¿Estás seguro de que deseas restablecer el plan?';

  @override
  String divePlanner_semantics_criticalWarning(Object message) {
    return 'Advertencia crítica: $message';
  }

  @override
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  ) {
    return 'Parada de deco en $depth por $duration en $gasMix';
  }

  @override
  String divePlanner_semantics_gasConsumption(
    Object tankName,
    Object gasUsed,
    Object remaining,
    Object percent,
    Object warning,
  ) {
    return '$tankName: $gasUsed usado, $remaining restante, $percent usado$warning';
  }

  @override
  String divePlanner_semantics_profileChart(
    Object maxDepth,
    Object totalMinutes,
  ) {
    return 'Plan de inmersión, profundidad máxima $maxDepth, tiempo total $totalMinutes minutos';
  }

  @override
  String divePlanner_semantics_warning(Object message) {
    return 'Advertencia: $message';
  }

  @override
  String get divePlanner_tab_plan => 'Plan';

  @override
  String get divePlanner_tab_profile => 'Perfil';

  @override
  String get divePlanner_tab_results => 'Resultados';

  @override
  String get divePlanner_warning_ascentRateHigh =>
      'Velocidad de ascenso excede el límite seguro';

  @override
  String divePlanner_warning_ascentRateHighWithRate(Object rate) {
    return 'Velocidad de ascenso $rate/min excede el límite seguro';
  }

  @override
  String divePlanner_warning_belowMinReserve(Object reserve) {
    return 'Por debajo de reserva mínima ($reserve)';
  }

  @override
  String get divePlanner_warning_cnsCritical => 'CNS% excede 100%';

  @override
  String divePlanner_warning_cnsWarning(Object threshold) {
    return 'CNS% excede $threshold%';
  }

  @override
  String get divePlanner_warning_endHigh =>
      'Profundidad Narcótica Equivalente demasiado alta';

  @override
  String divePlanner_warning_endHighWithDepth(Object depth) {
    return 'END de $depth excede el límite seguro';
  }

  @override
  String divePlanner_warning_gasLow(Object threshold) {
    return 'Botella por debajo de $threshold de reserva';
  }

  @override
  String get divePlanner_warning_gasOut => 'La botella estará vacía';

  @override
  String get divePlanner_warning_minGasViolation =>
      'Reserva mínima de gas no mantenida';

  @override
  String get divePlanner_warning_modViolation =>
      'Cambio de gas intentado por encima de MOD';

  @override
  String get divePlanner_warning_ndlExceeded =>
      'La inmersión entra en obligación de descompresión';

  @override
  String get divePlanner_warning_otuWarning => 'Acumulación de OTU alta';

  @override
  String divePlanner_warning_ppO2Critical(Object value) {
    return 'ppO₂ de $value bar excede el límite crítico';
  }

  @override
  String divePlanner_warning_ppO2High(Object value) {
    return 'ppO₂ de $value bar excede el límite de trabajo';
  }

  @override
  String get diveSites_detail_access_accessNotes => 'Notas de acceso';

  @override
  String get diveSites_detail_access_mooring => 'Amarre';

  @override
  String get diveSites_detail_access_parking => 'Estacionamiento';

  @override
  String get diveSites_detail_altitude_elevation => 'Altitud';

  @override
  String get diveSites_detail_altitude_pressure => 'Presion';

  @override
  String get diveSites_detail_coordinatesCopied =>
      'Coordenadas copiadas al portapapeles';

  @override
  String get diveSites_detail_deleteDialog_cancel => 'Cancelar';

  @override
  String get diveSites_detail_deleteDialog_confirm => 'Eliminar';

  @override
  String get diveSites_detail_deleteDialog_content =>
      'Estas seguro de que deseas eliminar este sitio? Esta accion no se puede deshacer.';

  @override
  String get diveSites_detail_deleteDialog_title => 'Eliminar sitio';

  @override
  String get diveSites_detail_deleteMenu_label => 'Eliminar';

  @override
  String get diveSites_detail_deleteSnackbar => 'Sitio eliminado';

  @override
  String get diveSites_detail_depth_maximum => 'Maxima';

  @override
  String get diveSites_detail_depth_minimum => 'Minima';

  @override
  String get diveSites_detail_diveCount_one => '1 inmersion registrada';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '$count inmersiones registradas';
  }

  @override
  String get diveSites_detail_diveCount_zero =>
      'Aun no hay inmersiones registradas';

  @override
  String get diveSites_detail_editTooltip => 'Editar sitio';

  @override
  String get diveSites_detail_editTooltipShort => 'Editar';

  @override
  String diveSites_detail_error_body(Object error) {
    return 'Error: $error';
  }

  @override
  String get diveSites_detail_error_title => 'Error';

  @override
  String get diveSites_detail_loading_title => 'Cargando...';

  @override
  String get diveSites_detail_location_country => 'Pais';

  @override
  String get diveSites_detail_location_gpsCoordinates => 'Coordenadas GPS';

  @override
  String get diveSites_detail_location_notSet => 'No establecido';

  @override
  String get diveSites_detail_location_region => 'Region';

  @override
  String get diveSites_detail_noDepthInfo => 'Sin informacion de profundidad';

  @override
  String get diveSites_detail_noDescription => 'Sin descripcion';

  @override
  String get diveSites_detail_noNotes => 'Sin notas';

  @override
  String get diveSites_detail_rating_notRated => 'Sin calificacion';

  @override
  String diveSites_detail_rating_value(Object rating) {
    return '$rating de 5';
  }

  @override
  String get diveSites_detail_section_access => 'Acceso y logistica';

  @override
  String get diveSites_detail_section_altitude => 'Altitud';

  @override
  String get diveSites_detail_section_depthRange => 'Rango de profundidad';

  @override
  String get diveSites_detail_section_description => 'Descripcion';

  @override
  String get diveSites_detail_section_difficultyLevel => 'Nivel de dificultad';

  @override
  String get diveSites_detail_section_divesAtSite =>
      'Inmersiones en este sitio';

  @override
  String get diveSites_detail_section_hazards => 'Peligros y seguridad';

  @override
  String get diveSites_detail_section_location => 'Ubicacion';

  @override
  String get diveSites_detail_section_notes => 'Notas';

  @override
  String get diveSites_detail_section_rating => 'Calificacion';

  @override
  String diveSites_detail_semantics_copyToClipboard(Object label) {
    return 'Copiar $label al portapapeles';
  }

  @override
  String get diveSites_detail_semantics_viewDivesAtSite =>
      'Ver inmersiones en este sitio';

  @override
  String get diveSites_detail_semantics_viewFullscreenMap =>
      'Ver mapa en pantalla completa';

  @override
  String get diveSites_detail_siteNotFound_body => 'Este sitio ya no existe.';

  @override
  String get diveSites_detail_siteNotFound_title => 'Sitio no encontrado';

  @override
  String get diveSites_difficulty_advanced => 'Avanzado';

  @override
  String get diveSites_difficulty_beginner => 'Principiante';

  @override
  String get diveSites_difficulty_intermediate => 'Intermedio';

  @override
  String get diveSites_difficulty_technical => 'Tecnico';

  @override
  String get diveSites_edit_access_accessNotes_hint =>
      'Como llegar al sitio, puntos de entrada/salida, acceso desde costa/barco';

  @override
  String get diveSites_edit_access_accessNotes_label => 'Notas de acceso';

  @override
  String get diveSites_edit_access_mooringNumber_hint => 'p. ej., Boya #12';

  @override
  String get diveSites_edit_access_mooringNumber_label => 'Numero de amarre';

  @override
  String get diveSites_edit_access_parkingInfo_hint =>
      'Disponibilidad de estacionamiento, tarifas, consejos';

  @override
  String get diveSites_edit_access_parkingInfo_label =>
      'Informacion de estacionamiento';

  @override
  String get diveSites_edit_altitude_helperText =>
      'Elevacion del sitio sobre el nivel del mar (para buceo en altitud)';

  @override
  String get diveSites_edit_altitude_hint => 'p. ej., 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return 'Altitud ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => 'Altitud no valida';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => 'Eliminar sitio';

  @override
  String get diveSites_edit_appBar_editSite => 'Editar sitio';

  @override
  String get diveSites_edit_appBar_newSite => 'Nuevo sitio';

  @override
  String get diveSites_edit_appBar_save => 'Guardar';

  @override
  String get diveSites_edit_button_addSite => 'Agregar sitio';

  @override
  String get diveSites_edit_button_saveChanges => 'Guardar cambios';

  @override
  String get diveSites_edit_cancel => 'Cancelar';

  @override
  String get diveSites_edit_depth_helperText =>
      'Desde el punto mas superficial hasta el mas profundo';

  @override
  String get diveSites_edit_depth_maxHint => 'p. ej., 30';

  @override
  String diveSites_edit_depth_maxLabel(Object symbol) {
    return 'Profundidad maxima ($symbol)';
  }

  @override
  String get diveSites_edit_depth_minHint => 'p. ej., 5';

  @override
  String diveSites_edit_depth_minLabel(Object symbol) {
    return 'Profundidad minima ($symbol)';
  }

  @override
  String get diveSites_edit_depth_separator => 'a';

  @override
  String get diveSites_edit_discardDialog_content =>
      'Tienes cambios sin guardar. Estas seguro de que deseas salir?';

  @override
  String get diveSites_edit_discardDialog_discard => 'Descartar';

  @override
  String get diveSites_edit_discardDialog_keepEditing => 'Seguir editando';

  @override
  String get diveSites_edit_discardDialog_title => 'Descartar cambios?';

  @override
  String get diveSites_edit_field_country_label => 'Pais';

  @override
  String get diveSites_edit_field_description_hint =>
      'Breve descripcion del sitio';

  @override
  String get diveSites_edit_field_description_label => 'Descripcion';

  @override
  String get diveSites_edit_field_notes_hint =>
      'Cualquier otra informacion sobre este sitio';

  @override
  String get diveSites_edit_field_notes_label => 'Notas generales';

  @override
  String get diveSites_edit_field_region_label => 'Region';

  @override
  String get diveSites_edit_field_siteName_hint => 'p. ej., Blue Hole';

  @override
  String get diveSites_edit_field_siteName_label => 'Nombre del sitio *';

  @override
  String get diveSites_edit_field_siteName_validation =>
      'Por favor ingresa un nombre de sitio';

  @override
  String get diveSites_edit_gps_gettingLocation => 'Obteniendo...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Elige un metodo de ubicacion - las coordenadas completaran automaticamente el pais y la region';

  @override
  String get diveSites_edit_gps_latitude_hint => 'p. ej., 21.4225';

  @override
  String get diveSites_edit_gps_latitude_label => 'Latitud';

  @override
  String get diveSites_edit_gps_latitude_validation => 'Latitud no valida';

  @override
  String get diveSites_edit_gps_longitude_hint => 'p. ej., -86.7542';

  @override
  String get diveSites_edit_gps_longitude_label => 'Longitud';

  @override
  String get diveSites_edit_gps_longitude_validation => 'Longitud no valida';

  @override
  String get diveSites_edit_gps_pickFromMap => 'Elegir del mapa';

  @override
  String get diveSites_edit_gps_useMyLocation => 'Usar mi ubicacion';

  @override
  String get diveSites_edit_hazards_helperText =>
      'Lista de peligros o consideraciones de seguridad';

  @override
  String get diveSites_edit_hazards_hint =>
      'p. ej., Corrientes fuertes, trafico de embarcaciones, medusas, coral afilado';

  @override
  String get diveSites_edit_hazards_label => 'Peligros';

  @override
  String get diveSites_edit_marineLife_addButton => 'Agregar';

  @override
  String get diveSites_edit_marineLife_empty =>
      'No se han agregado especies esperadas';

  @override
  String get diveSites_edit_marineLife_helperText =>
      'Especies que esperas ver en este sitio';

  @override
  String get diveSites_edit_rating_clear => 'Borrar calificacion';

  @override
  String diveSites_edit_rating_starTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count estrella$_temp0';
  }

  @override
  String get diveSites_edit_section_access => 'Acceso y logistica';

  @override
  String get diveSites_edit_section_altitude => 'Altitud';

  @override
  String get diveSites_edit_section_depthRange => 'Rango de profundidad';

  @override
  String get diveSites_edit_section_difficultyLevel => 'Nivel de dificultad';

  @override
  String get diveSites_edit_section_expectedMarineLife =>
      'Vida marina esperada';

  @override
  String get diveSites_edit_section_gpsCoordinates => 'Coordenadas GPS';

  @override
  String get diveSites_edit_section_hazards => 'Peligros y seguridad';

  @override
  String get diveSites_edit_section_rating => 'Calificacion';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return 'Error al eliminar el sitio: $error';
  }

  @override
  String diveSites_edit_snackbar_errorSaving(Object error) {
    return 'Error al guardar el sitio: $error';
  }

  @override
  String get diveSites_edit_snackbar_locationCaptured => 'Ubicacion capturada';

  @override
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Ubicacion capturada (${accuracy}m)';
  }

  @override
  String get diveSites_edit_snackbar_locationSelectedFromMap =>
      'Ubicacion seleccionada del mapa';

  @override
  String get diveSites_edit_snackbar_locationSettings => 'Configuracion';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      'No se pudo obtener la ubicacion. Los servicios de ubicacion pueden no estar disponibles.';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      'No se pudo obtener la ubicacion. Por favor verifica los permisos.';

  @override
  String get diveSites_edit_snackbar_siteAdded => 'Sitio agregado';

  @override
  String get diveSites_edit_snackbar_siteUpdated => 'Sitio actualizado';

  @override
  String get diveSites_fab_label => 'Agregar sitio';

  @override
  String get diveSites_fab_tooltip => 'Agregar un nuevo punto de buceo';

  @override
  String get diveSites_filter_apply => 'Aplicar filtros';

  @override
  String get diveSites_filter_cancel => 'Cancelar';

  @override
  String get diveSites_filter_clearAll => 'Borrar todo';

  @override
  String get diveSites_filter_country_hint => 'p. ej., Tailandia';

  @override
  String get diveSites_filter_country_label => 'Pais';

  @override
  String get diveSites_filter_depth_max_label => 'Max';

  @override
  String get diveSites_filter_depth_min_label => 'Min';

  @override
  String get diveSites_filter_depth_separator => 'a';

  @override
  String get diveSites_filter_difficulty_any => 'Cualquiera';

  @override
  String get diveSites_filter_option_hasCoordinates_subtitle =>
      'Mostrar solo sitios con ubicacion GPS';

  @override
  String get diveSites_filter_option_hasCoordinates_title =>
      'Tiene coordenadas';

  @override
  String get diveSites_filter_option_hasDives_subtitle =>
      'Mostrar solo sitios con inmersiones registradas';

  @override
  String get diveSites_filter_option_hasDives_title => 'Tiene inmersiones';

  @override
  String diveSites_filter_rating_starsPlus(Object count) {
    return '$count+ estrellas';
  }

  @override
  String get diveSites_filter_region_hint => 'p. ej., Phuket';

  @override
  String get diveSites_filter_region_label => 'Region';

  @override
  String get diveSites_filter_section_depthRange =>
      'Rango de profundidad maxima';

  @override
  String get diveSites_filter_section_difficulty => 'Dificultad';

  @override
  String get diveSites_filter_section_location => 'Ubicacion';

  @override
  String get diveSites_filter_section_minRating => 'Calificacion minima';

  @override
  String get diveSites_filter_section_options => 'Opciones';

  @override
  String get diveSites_filter_title => 'Filtrar sitios';

  @override
  String get diveSites_import_appBar_title => 'Importar punto de buceo';

  @override
  String get diveSites_import_badge_imported => 'Importado';

  @override
  String get diveSites_import_badge_saved => 'Guardado';

  @override
  String get diveSites_import_button_import => 'Importar';

  @override
  String get diveSites_import_detail_alreadyImported => 'Ya importado';

  @override
  String get diveSites_import_detail_importToMySites => 'Importar a mis sitios';

  @override
  String diveSites_import_detail_source(Object source) {
    return 'Fuente: $source';
  }

  @override
  String get diveSites_import_empty_description =>
      'Busca puntos de buceo en nuestra base de datos de destinos\nde buceo populares alrededor del mundo.';

  @override
  String get diveSites_import_empty_hint =>
      'Intenta buscar por nombre del sitio, pais o region.';

  @override
  String get diveSites_import_empty_title => 'Buscar puntos de buceo';

  @override
  String get diveSites_import_error_retry => 'Reintentar';

  @override
  String get diveSites_import_error_title => 'Error de busqueda';

  @override
  String get diveSites_import_error_unknown => 'Error desconocido';

  @override
  String get diveSites_import_externalSite_locationUnknown =>
      'Ubicacion desconocida';

  @override
  String get diveSites_import_label_gps => 'GPS';

  @override
  String get diveSites_import_localSite_locationNotSet =>
      'Ubicacion no establecida';

  @override
  String diveSites_import_noResults_description(Object query) {
    return 'No se encontraron puntos de buceo para \"$query\".\nIntenta con un termino de busqueda diferente.';
  }

  @override
  String get diveSites_import_noResults_title => 'Sin resultados';

  @override
  String get diveSites_import_quickSearch_caribbean => 'Caribe';

  @override
  String get diveSites_import_quickSearch_indonesia => 'Indonesia';

  @override
  String get diveSites_import_quickSearch_maldives => 'Maldivas';

  @override
  String get diveSites_import_quickSearch_philippines => 'Filipinas';

  @override
  String get diveSites_import_quickSearch_redSea => 'Mar Rojo';

  @override
  String get diveSites_import_quickSearch_thailand => 'Tailandia';

  @override
  String get diveSites_import_search_clearTooltip => 'Borrar busqueda';

  @override
  String get diveSites_import_search_hint =>
      'Buscar puntos de buceo (p. ej., \"Blue Hole\", \"Tailandia\")';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return 'Importar de la base de datos ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return 'Mis sitios ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return 'Ver detalles de $name';
  }

  @override
  String diveSites_import_semantics_viewSavedSite(Object name) {
    return 'Ver sitio guardado $name';
  }

  @override
  String get diveSites_import_snackbar_failed => 'Error al importar el sitio';

  @override
  String diveSites_import_snackbar_imported(Object name) {
    return '\"$name\" importado';
  }

  @override
  String get diveSites_import_snackbar_viewAction => 'Ver';

  @override
  String get diveSites_list_activeFilter_clear => 'Borrar';

  @override
  String diveSites_list_activeFilter_country(Object country) {
    return 'Pais: $country';
  }

  @override
  String diveSites_list_activeFilter_depthRangeBoth(Object min, Object max) {
    return '$min-${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Hasta ${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '${min}m+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => 'Tiene coordenadas';

  @override
  String get diveSites_list_activeFilter_hasDives => 'Tiene inmersiones';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return 'Region: $region';
  }

  @override
  String get diveSites_list_appBar_title => 'Puntos de buceo';

  @override
  String get diveSites_list_bulkDelete_cancel => 'Cancelar';

  @override
  String get diveSites_list_bulkDelete_confirm => 'Eliminar';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sitios',
      one: 'sitio',
    );
    return 'Estas seguro de que deseas eliminar $count $_temp0? Esta accion se puede deshacer en 5 segundos.';
  }

  @override
  String get diveSites_list_bulkDelete_restored => 'Sitios restaurados';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sitios',
      one: 'sitio',
    );
    return '$count $_temp0 eliminados';
  }

  @override
  String get diveSites_list_bulkDelete_title => 'Eliminar sitios';

  @override
  String get diveSites_list_bulkDelete_undo => 'Deshacer';

  @override
  String get diveSites_list_emptyFiltered_clearAll =>
      'Borrar todos los filtros';

  @override
  String get diveSites_list_emptyFiltered_subtitle =>
      'Intenta ajustar o borrar tus filtros';

  @override
  String get diveSites_list_emptyFiltered_title =>
      'Ningun sitio coincide con tus filtros';

  @override
  String get diveSites_list_empty_addFirstSite => 'Agrega tu primer sitio';

  @override
  String get diveSites_list_empty_import => 'Importar';

  @override
  String get diveSites_list_empty_subtitle =>
      'Agrega puntos de buceo para rastrear tus ubicaciones favoritas';

  @override
  String get diveSites_list_empty_title => 'Aun no hay puntos de buceo';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return 'Error al cargar los sitios: $error';
  }

  @override
  String get diveSites_list_error_retry => 'Reintentar';

  @override
  String get diveSites_list_menu_import => 'Importar';

  @override
  String get diveSites_list_search_backTooltip => 'Atras';

  @override
  String get diveSites_list_search_clearTooltip => 'Borrar busqueda';

  @override
  String get diveSites_list_search_emptyHint =>
      'Buscar por nombre del sitio, pais o region';

  @override
  String diveSites_list_search_error(Object error) {
    return 'Error: $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return 'No se encontraron sitios para \"$query\"';
  }

  @override
  String get diveSites_list_search_placeholder => 'Buscar sitios...';

  @override
  String get diveSites_list_selection_closeTooltip => 'Cerrar seleccion';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count seleccionados';
  }

  @override
  String get diveSites_list_selection_deleteTooltip => 'Eliminar seleccionados';

  @override
  String get diveSites_list_selection_deselectAllTooltip =>
      'Deseleccionar todo';

  @override
  String get diveSites_list_selection_selectAllTooltip => 'Seleccionar todo';

  @override
  String get diveSites_list_sort_title => 'Ordenar sitios';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones',
      one: '1 inmersion',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return 'Punto de buceo: $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => 'Filtrar sitios';

  @override
  String get diveSites_list_tooltip_mapView => 'Vista de mapa';

  @override
  String get diveSites_list_tooltip_searchSites => 'Buscar sitios';

  @override
  String get diveSites_list_tooltip_sort => 'Ordenar';

  @override
  String get diveSites_locationPicker_appBar_title => 'Elegir ubicacion';

  @override
  String get diveSites_locationPicker_confirmButton => 'Confirmar';

  @override
  String get diveSites_locationPicker_confirmTooltip =>
      'Confirmar ubicacion seleccionada';

  @override
  String get diveSites_locationPicker_fab_tooltip => 'Usar mi ubicacion';

  @override
  String get diveSites_locationPicker_instruction_locationSelected =>
      'Ubicacion seleccionada';

  @override
  String get diveSites_locationPicker_instruction_lookingUp =>
      'Buscando ubicacion...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect =>
      'Toca el mapa para seleccionar una ubicacion';

  @override
  String get diveSites_locationPicker_label_latitude => 'Latitud';

  @override
  String get diveSites_locationPicker_label_longitude => 'Longitud';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return 'Coordenadas seleccionadas: latitud $latitude, longitud $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp =>
      'Buscando ubicacion';

  @override
  String get diveSites_locationPicker_semantics_map =>
      'Mapa interactivo para elegir la ubicacion de un punto de buceo. Toca el mapa para seleccionar una ubicacion.';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return 'Error al cargar los puntos de buceo: $error';
  }

  @override
  String get diveSites_map_appBar_title => 'Puntos de buceo';

  @override
  String get diveSites_map_empty_description =>
      'Agrega coordenadas a tus puntos de buceo para verlos en el mapa';

  @override
  String get diveSites_map_empty_title => 'No hay sitios con coordenadas';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return 'Error al cargar los sitios: $error';
  }

  @override
  String get diveSites_map_error_retry => 'Reintentar';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones',
      one: '1 inmersion',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return 'Punto de buceo: $name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => 'Ajustar a todos los sitios';

  @override
  String get diveSites_map_tooltip_listView => 'Vista de lista';

  @override
  String get diveSites_summary_action_addSite => 'Agregar sitio';

  @override
  String get diveSites_summary_action_import => 'Importar';

  @override
  String get diveSites_summary_action_viewMap => 'Ver mapa';

  @override
  String diveSites_summary_countriesMore(Object count) {
    return '+ $count mas';
  }

  @override
  String get diveSites_summary_header_subtitle =>
      'Selecciona un sitio de la lista para ver los detalles';

  @override
  String get diveSites_summary_header_title => 'Puntos de buceo';

  @override
  String get diveSites_summary_section_countriesRegions => 'Paises y regiones';

  @override
  String get diveSites_summary_section_mostDived => 'Mas frecuentados';

  @override
  String get diveSites_summary_section_overview => 'Resumen';

  @override
  String get diveSites_summary_section_quickActions => 'Acciones rapidas';

  @override
  String get diveSites_summary_section_topRated => 'Mejor calificados';

  @override
  String get diveSites_summary_stat_avgRating => 'Calificacion promedio';

  @override
  String get diveSites_summary_stat_totalDives => 'Total de inmersiones';

  @override
  String get diveSites_summary_stat_totalSites => 'Total de sitios';

  @override
  String get diveSites_summary_stat_withGps => 'Con GPS';

  @override
  String get diveTypes_addDialog_addButton => 'Agregar';

  @override
  String get diveTypes_addDialog_nameHint => 'ej., Búsqueda y Recuperación';

  @override
  String get diveTypes_addDialog_nameLabel => 'Nombre del Tipo de Inmersión';

  @override
  String get diveTypes_addDialog_nameValidation =>
      'Por favor ingresa un nombre';

  @override
  String get diveTypes_addDialog_title =>
      'Agregar Tipo de Inmersión Personalizado';

  @override
  String get diveTypes_addTooltip => 'Agregar tipo de inmersión';

  @override
  String get diveTypes_appBar_title => 'Tipos de Inmersión';

  @override
  String get diveTypes_builtIn => 'Integrado';

  @override
  String get diveTypes_builtInHeader => 'Tipos de Inmersión Integrados';

  @override
  String get diveTypes_custom => 'Personalizado';

  @override
  String get diveTypes_customHeader => 'Tipos de Inmersión Personalizados';

  @override
  String diveTypes_deleteDialog_content(Object name) {
    return '¿Estás seguro de que deseas eliminar \"$name\"?';
  }

  @override
  String get diveTypes_deleteDialog_title => '¿Eliminar Tipo de Inmersión?';

  @override
  String get diveTypes_deleteTooltip => 'Eliminar tipo de inmersión';

  @override
  String diveTypes_snackbar_added(Object name) {
    return 'Tipo de inmersión agregado: $name';
  }

  @override
  String diveTypes_snackbar_cannotDelete(Object name) {
    return 'No se puede eliminar \"$name\" - está siendo usado por inmersiones existentes';
  }

  @override
  String diveTypes_snackbar_deleted(Object name) {
    return 'Eliminado \"$name\"';
  }

  @override
  String diveTypes_snackbar_errorAdding(Object error) {
    return 'Error al agregar tipo de inmersión: $error';
  }

  @override
  String diveTypes_snackbar_errorDeleting(Object error) {
    return 'Error al eliminar tipo de inmersión: $error';
  }

  @override
  String get divers_detail_activeDiver => 'Buceador activo';

  @override
  String get divers_detail_allergiesLabel => 'Alergias';

  @override
  String get divers_detail_appBarTitle => 'Buceador';

  @override
  String get divers_detail_bloodTypeLabel => 'Grupo sanguineo';

  @override
  String get divers_detail_bottomTimeLabel => 'Tiempo de fondo';

  @override
  String get divers_detail_cancelButton => 'Cancelar';

  @override
  String get divers_detail_contactTitle => 'Contacto';

  @override
  String get divers_detail_defaultLabel => 'Predeterminado';

  @override
  String get divers_detail_deleteButton => 'Eliminar';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'Estas seguro de que deseas eliminar a $name? Todos los registros de buceo asociados seran desasignados.';
  }

  @override
  String get divers_detail_deleteDialogTitle => 'Eliminar buceador?';

  @override
  String divers_detail_deleteError(Object error) {
    return 'Error al eliminar: $error';
  }

  @override
  String get divers_detail_deleteMenuItem => 'Eliminar';

  @override
  String get divers_detail_deletedSnackbar => 'Buceador eliminado';

  @override
  String get divers_detail_diveInsuranceTitle => 'Seguro de buceo';

  @override
  String get divers_detail_diveStatisticsTitle => 'Estadisticas de buceo';

  @override
  String get divers_detail_editTooltip => 'Editar buceador';

  @override
  String get divers_detail_emergencyContactTitle => 'Contacto de emergencia';

  @override
  String divers_detail_errorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get divers_detail_expiredBadge => 'Vencido';

  @override
  String get divers_detail_expiresLabel => 'Vence';

  @override
  String get divers_detail_medicalInfoTitle => 'Informacion medica';

  @override
  String get divers_detail_medicalNotesLabel => 'Notas';

  @override
  String get divers_detail_notFound => 'Buceador no encontrado';

  @override
  String get divers_detail_notesTitle => 'Notas';

  @override
  String get divers_detail_policyNumberLabel => 'Poliza #';

  @override
  String get divers_detail_providerLabel => 'Proveedor';

  @override
  String get divers_detail_setAsDefault => 'Establecer como predeterminado';

  @override
  String divers_detail_setAsDefaultSnackbar(Object name) {
    return '$name establecido como buceador predeterminado';
  }

  @override
  String get divers_detail_switchToTooltip => 'Cambiar a este buceador';

  @override
  String divers_detail_switchedTo(Object name) {
    return 'Se cambio a $name';
  }

  @override
  String get divers_detail_totalDivesLabel => 'Total de inmersiones';

  @override
  String get divers_detail_unableToLoadStats =>
      'No se pudieron cargar las estadisticas';

  @override
  String get divers_edit_addButton => 'Agregar buceador';

  @override
  String get divers_edit_addTitle => 'Agregar buceador';

  @override
  String get divers_edit_allergiesHint => 'ej., Penicilina, Mariscos';

  @override
  String get divers_edit_allergiesLabel => 'Alergias';

  @override
  String get divers_edit_bloodTypeHint => 'ej., O+, A-, B+';

  @override
  String get divers_edit_bloodTypeLabel => 'Grupo sanguineo';

  @override
  String get divers_edit_cancelButton => 'Cancelar';

  @override
  String get divers_edit_clearInsuranceExpiryTooltip =>
      'Borrar fecha de vencimiento del seguro';

  @override
  String get divers_edit_clearMedicalClearanceTooltip =>
      'Borrar fecha de autorizacion medica';

  @override
  String get divers_edit_contactNameLabel => 'Nombre del contacto';

  @override
  String get divers_edit_contactPhoneLabel => 'Telefono del contacto';

  @override
  String get divers_edit_discardButton => 'Descartar';

  @override
  String get divers_edit_discardDialogContent =>
      'Tienes cambios sin guardar. Estas seguro de que deseas descartarlos?';

  @override
  String get divers_edit_discardDialogTitle => 'Descartar cambios?';

  @override
  String get divers_edit_diverAdded => 'Buceador agregado';

  @override
  String get divers_edit_diverUpdated => 'Buceador actualizado';

  @override
  String get divers_edit_editTitle => 'Editar buceador';

  @override
  String get divers_edit_emailError => 'Introduce un correo electronico valido';

  @override
  String get divers_edit_emailLabel => 'Correo electronico';

  @override
  String get divers_edit_emergencyContactsSection => 'Contactos de emergencia';

  @override
  String divers_edit_errorLoading(Object error) {
    return 'Error al cargar buceador: $error';
  }

  @override
  String divers_edit_errorSaving(Object error) {
    return 'Error al guardar buceador: $error';
  }

  @override
  String get divers_edit_expiryDateNotSet => 'No establecida';

  @override
  String get divers_edit_expiryDateTitle => 'Fecha de vencimiento';

  @override
  String get divers_edit_insuranceProviderHint => 'ej., DAN, DiveAssure';

  @override
  String get divers_edit_insuranceProviderLabel => 'Proveedor de seguro';

  @override
  String get divers_edit_insuranceSection => 'Seguro de buceo';

  @override
  String get divers_edit_keepEditingButton => 'Seguir editando';

  @override
  String get divers_edit_medicalClearanceExpired => 'Vencida';

  @override
  String get divers_edit_medicalClearanceExpiringSoon => 'Por vencer';

  @override
  String get divers_edit_medicalClearanceNotSet => 'No establecida';

  @override
  String get divers_edit_medicalClearanceTitle =>
      'Vencimiento de autorizacion medica';

  @override
  String get divers_edit_medicalInfoSection => 'Informacion medica';

  @override
  String get divers_edit_medicalNotesLabel => 'Notas medicas';

  @override
  String get divers_edit_medicationsHint => 'ej., Aspirina diaria, EpiPen';

  @override
  String get divers_edit_medicationsLabel => 'Medicamentos';

  @override
  String get divers_edit_nameError => 'El nombre es obligatorio';

  @override
  String get divers_edit_nameLabel => 'Nombre *';

  @override
  String get divers_edit_notesLabel => 'Notas';

  @override
  String get divers_edit_notesSection => 'Notas';

  @override
  String get divers_edit_personalInfoSection => 'Informacion personal';

  @override
  String get divers_edit_phoneLabel => 'Telefono';

  @override
  String get divers_edit_policyNumberLabel => 'Numero de poliza';

  @override
  String get divers_edit_primaryContactTitle => 'Contacto principal';

  @override
  String get divers_edit_relationshipHint => 'ej., Conyuge, Padre/Madre, Amigo';

  @override
  String get divers_edit_relationshipLabel => 'Relacion';

  @override
  String get divers_edit_saveButton => 'Guardar';

  @override
  String get divers_edit_secondaryContactTitle => 'Contacto secundario';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip =>
      'Seleccionar fecha de vencimiento del seguro';

  @override
  String get divers_edit_selectMedicalClearanceTooltip =>
      'Seleccionar fecha de autorizacion medica';

  @override
  String get divers_edit_updateButton => 'Actualizar buceador';

  @override
  String get divers_list_activeBadge => 'Activo';

  @override
  String get divers_list_addDiverButton => 'Agregar buceador';

  @override
  String get divers_list_addDiverTooltip =>
      'Agregar un nuevo perfil de buceador';

  @override
  String get divers_list_appBarTitle => 'Perfiles de buceadores';

  @override
  String get divers_list_compactTitle => 'Buceadores';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount inmersiones$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle =>
      'Agrega perfiles de buceadores para llevar registros de buceo de varias personas';

  @override
  String get divers_list_emptyTitle => 'No hay buceadores aun';

  @override
  String divers_list_errorLoading(Object error) {
    return 'Error al cargar buceadores: $error';
  }

  @override
  String get divers_list_errorLoadingStats => 'Error al cargar estadisticas';

  @override
  String get divers_list_loadingStats => 'Cargando...';

  @override
  String get divers_list_retryButton => 'Reintentar';

  @override
  String divers_list_viewDiverLabel(Object name) {
    return 'Ver buceador $name';
  }

  @override
  String get divers_summary_activeDiverTitle => 'Buceador activo';

  @override
  String get divers_summary_otherDiversTitle => 'Otros buceadores';

  @override
  String get divers_summary_overviewTitle => 'Resumen';

  @override
  String get divers_summary_quickActionsTitle => 'Acciones rapidas';

  @override
  String get divers_summary_subtitle =>
      'Selecciona un buceador de la lista para ver detalles';

  @override
  String get divers_summary_title => 'Perfiles de buceadores';

  @override
  String get divers_summary_totalDiversLabel => 'Total de buceadores';

  @override
  String get enum_altitudeGroup_extreme => 'Altitud extrema';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => 'Grupo de altitud 1';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => 'Grupo de altitud 2';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => 'Grupo de altitud 3';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => 'Nivel del mar';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => 'Peligro';

  @override
  String get enum_ascentRate_safe => 'Seguro';

  @override
  String get enum_ascentRate_warning => 'Advertencia';

  @override
  String get enum_buddyRole_buddy => 'Compañero';

  @override
  String get enum_buddyRole_diveGuide => 'Guía de buceo';

  @override
  String get enum_buddyRole_diveMaster => 'Divemaster';

  @override
  String get enum_buddyRole_instructor => 'Instructor';

  @override
  String get enum_buddyRole_solo => 'Solo';

  @override
  String get enum_buddyRole_student => 'Estudiante';

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
  String get enum_certificationAgency_other => 'Otra';

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
  String get enum_certificationLevel_advancedNitrox => 'Nitrox avanzado';

  @override
  String get enum_certificationLevel_advancedOpenWater =>
      'Aguas abiertas avanzado';

  @override
  String get enum_certificationLevel_cave => 'Cueva';

  @override
  String get enum_certificationLevel_cavern => 'Caverna';

  @override
  String get enum_certificationLevel_courseDirector => 'Director de curso';

  @override
  String get enum_certificationLevel_decompression => 'Descompresión';

  @override
  String get enum_certificationLevel_diveMaster => 'Divemaster';

  @override
  String get enum_certificationLevel_instructor => 'Instructor';

  @override
  String get enum_certificationLevel_masterInstructor => 'Instructor maestro';

  @override
  String get enum_certificationLevel_nitrox => 'Nitrox';

  @override
  String get enum_certificationLevel_openWater => 'Aguas abiertas';

  @override
  String get enum_certificationLevel_other => 'Otro';

  @override
  String get enum_certificationLevel_rebreather => 'Rebreather';

  @override
  String get enum_certificationLevel_rescue => 'Buzo de rescate';

  @override
  String get enum_certificationLevel_sidemount => 'Sidemount';

  @override
  String get enum_certificationLevel_techDiver => 'Buzo técnico';

  @override
  String get enum_certificationLevel_trimix => 'Trimix';

  @override
  String get enum_certificationLevel_wreck => 'Naufragio';

  @override
  String get enum_currentDirection_east => 'Este';

  @override
  String get enum_currentDirection_none => 'Ninguna';

  @override
  String get enum_currentDirection_north => 'Norte';

  @override
  String get enum_currentDirection_northEast => 'Noreste';

  @override
  String get enum_currentDirection_northWest => 'Noroeste';

  @override
  String get enum_currentDirection_south => 'Sur';

  @override
  String get enum_currentDirection_southEast => 'Sureste';

  @override
  String get enum_currentDirection_southWest => 'Suroeste';

  @override
  String get enum_currentDirection_variable => 'Variable';

  @override
  String get enum_currentDirection_west => 'Oeste';

  @override
  String get enum_currentStrength_light => 'Ligera';

  @override
  String get enum_currentStrength_moderate => 'Moderada';

  @override
  String get enum_currentStrength_none => 'Ninguna';

  @override
  String get enum_currentStrength_strong => 'Fuerte';

  @override
  String get enum_diveMode_ccr => 'Rebreather de circuito cerrado';

  @override
  String get enum_diveMode_oc => 'Circuito abierto';

  @override
  String get enum_diveMode_scr => 'Rebreather semicerrado';

  @override
  String get enum_diveType_altitude => 'Altitud';

  @override
  String get enum_diveType_boat => 'Barco';

  @override
  String get enum_diveType_cave => 'Cueva';

  @override
  String get enum_diveType_deep => 'Profunda';

  @override
  String get enum_diveType_drift => 'Deriva';

  @override
  String get enum_diveType_freedive => 'Apnea';

  @override
  String get enum_diveType_ice => 'Hielo';

  @override
  String get enum_diveType_liveaboard => 'Vida a bordo';

  @override
  String get enum_diveType_night => 'Nocturna';

  @override
  String get enum_diveType_recreational => 'Recreativa';

  @override
  String get enum_diveType_shore => 'Costa';

  @override
  String get enum_diveType_technical => 'Técnica';

  @override
  String get enum_diveType_training => 'Entrenamiento';

  @override
  String get enum_diveType_wreck => 'Naufragio';

  @override
  String get enum_entryMethod_backRoll => 'Volteo hacia atrás';

  @override
  String get enum_entryMethod_boat => 'Entrada desde barco';

  @override
  String get enum_entryMethod_giantStride => 'Paso de gigante';

  @override
  String get enum_entryMethod_jetty => 'Muelle';

  @override
  String get enum_entryMethod_ladder => 'Escalera';

  @override
  String get enum_entryMethod_other => 'Otra';

  @override
  String get enum_entryMethod_platform => 'Plataforma';

  @override
  String get enum_entryMethod_seatedEntry => 'Entrada sentado';

  @override
  String get enum_entryMethod_shore => 'Entrada desde costa';

  @override
  String get enum_equipmentStatus_active => 'Activo';

  @override
  String get enum_equipmentStatus_inService => 'En servicio';

  @override
  String get enum_equipmentStatus_loaned => 'Prestado';

  @override
  String get enum_equipmentStatus_lost => 'Perdido';

  @override
  String get enum_equipmentStatus_needsService => 'Necesita servicio';

  @override
  String get enum_equipmentStatus_retired => 'Retirado';

  @override
  String get enum_equipmentType_bcd => 'Chaleco compensador';

  @override
  String get enum_equipmentType_boots => 'Botines';

  @override
  String get enum_equipmentType_camera => 'Cámara';

  @override
  String get enum_equipmentType_computer => 'Ordenador de buceo';

  @override
  String get enum_equipmentType_drysuit => 'Traje seco';

  @override
  String get enum_equipmentType_fins => 'Aletas';

  @override
  String get enum_equipmentType_gloves => 'Guantes';

  @override
  String get enum_equipmentType_hood => 'Capucha';

  @override
  String get enum_equipmentType_knife => 'Cuchillo';

  @override
  String get enum_equipmentType_light => 'Linterna';

  @override
  String get enum_equipmentType_mask => 'Máscara';

  @override
  String get enum_equipmentType_other => 'Otro';

  @override
  String get enum_equipmentType_reel => 'Carrete';

  @override
  String get enum_equipmentType_regulator => 'Regulador';

  @override
  String get enum_equipmentType_smb => 'SMB';

  @override
  String get enum_equipmentType_tank => 'Tanque';

  @override
  String get enum_equipmentType_weights => 'Lastre';

  @override
  String get enum_equipmentType_wetsuit => 'Traje de neopreno';

  @override
  String get enum_eventSeverity_alert => 'Alerta';

  @override
  String get enum_eventSeverity_info => 'Info';

  @override
  String get enum_eventSeverity_warning => 'Advertencia';

  @override
  String get enum_pdfPageSize_a4 => 'A4';

  @override
  String get enum_pdfPageSize_a4_description => '210 x 297 mm';

  @override
  String get enum_pdfPageSize_letter => 'Carta';

  @override
  String get enum_pdfPageSize_letter_description => '8.5 x 11 in';

  @override
  String get enum_pdfTemplate_detailed => 'Detallado';

  @override
  String get enum_pdfTemplate_detailed_description =>
      'Información completa de la inmersión con notas y valoraciones';

  @override
  String get enum_pdfTemplate_nauiStyle => 'Estilo NAUI';

  @override
  String get enum_pdfTemplate_nauiStyle_description =>
      'Diseño similar al formato de registro NAUI';

  @override
  String get enum_pdfTemplate_padiStyle => 'Estilo PADI';

  @override
  String get enum_pdfTemplate_padiStyle_description =>
      'Diseño similar al formato de registro PADI';

  @override
  String get enum_pdfTemplate_professional => 'Profesional';

  @override
  String get enum_pdfTemplate_professional_description =>
      'Áreas de firma y sello para verificación';

  @override
  String get enum_pdfTemplate_simple => 'Simple';

  @override
  String get enum_pdfTemplate_simple_description =>
      'Formato de tabla compacto, muchas inmersiones por página';

  @override
  String get enum_profileEvent_alert => 'Alerta';

  @override
  String get enum_profileEvent_ascentRateCritical =>
      'Velocidad de ascenso crítica';

  @override
  String get enum_profileEvent_ascentRateWarning =>
      'Advertencia de velocidad de ascenso';

  @override
  String get enum_profileEvent_ascentStart => 'Inicio del ascenso';

  @override
  String get enum_profileEvent_bookmark => 'Marcador';

  @override
  String get enum_profileEvent_cnsCritical => 'CNS crítico';

  @override
  String get enum_profileEvent_cnsWarning => 'Advertencia de CNS';

  @override
  String get enum_profileEvent_decoStopEnd => 'Fin de parada deco';

  @override
  String get enum_profileEvent_decoStopStart => 'Inicio de parada deco';

  @override
  String get enum_profileEvent_decoViolation => 'Violación de descompresión';

  @override
  String get enum_profileEvent_descentEnd => 'Fin del descenso';

  @override
  String get enum_profileEvent_descentStart => 'Inicio del descenso';

  @override
  String get enum_profileEvent_gasSwitch => 'Cambio de gas';

  @override
  String get enum_profileEvent_lowGas => 'Advertencia de gas bajo';

  @override
  String get enum_profileEvent_maxDepth => 'Profundidad máxima';

  @override
  String get enum_profileEvent_missedStop => 'Parada deco omitida';

  @override
  String get enum_profileEvent_note => 'Nota';

  @override
  String get enum_profileEvent_ppO2High => 'ppO2 alto';

  @override
  String get enum_profileEvent_ppO2Low => 'ppO2 bajo';

  @override
  String get enum_profileEvent_safetyStopEnd => 'Fin de parada de seguridad';

  @override
  String get enum_profileEvent_safetyStopStart =>
      'Inicio de parada de seguridad';

  @override
  String get enum_profileEvent_setpointChange => 'Cambio de setpoint';

  @override
  String get enum_profileMetricCategory_decompression => 'Descompresión';

  @override
  String get enum_profileMetricCategory_gasAnalysis => 'Análisis de gas';

  @override
  String get enum_profileMetricCategory_gradientFactor =>
      'Factores de gradiente';

  @override
  String get enum_profileMetricCategory_other => 'Otros';

  @override
  String get enum_profileMetricCategory_primary => 'Métricas principales';

  @override
  String get enum_profileMetric_gasDensity => 'Densidad del gas';

  @override
  String get enum_profileMetric_gasDensity_short => 'Densidad';

  @override
  String get enum_profileMetric_gf => 'GF%';

  @override
  String get enum_profileMetric_gf_short => 'GF%';

  @override
  String get enum_profileMetric_heartRate => 'Frecuencia cardíaca';

  @override
  String get enum_profileMetric_heartRate_short => 'FC';

  @override
  String get enum_profileMetric_meanDepth => 'Profundidad media';

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
  String get enum_profileMetric_pressure => 'Presión';

  @override
  String get enum_profileMetric_pressure_short => 'Pres';

  @override
  String get enum_profileMetric_sacRate => 'Consumo SAC';

  @override
  String get enum_profileMetric_sacRate_short => 'SAC';

  @override
  String get enum_profileMetric_surfaceGf => 'GF en superficie';

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
  String get enum_scrType_cmf => 'Flujo de masa constante';

  @override
  String get enum_scrType_cmf_short => 'CMF';

  @override
  String get enum_scrType_escr => 'Control electrónico';

  @override
  String get enum_scrType_escr_short => 'ESCR';

  @override
  String get enum_scrType_pascr => 'Adición pasiva';

  @override
  String get enum_scrType_pascr_short => 'PASCR';

  @override
  String get enum_serviceType_annual => 'Servicio anual';

  @override
  String get enum_serviceType_calibration => 'Calibración';

  @override
  String get enum_serviceType_cleaning => 'Limpieza';

  @override
  String get enum_serviceType_inspection => 'Inspección';

  @override
  String get enum_serviceType_other => 'Otro';

  @override
  String get enum_serviceType_overhaul => 'Revisión general';

  @override
  String get enum_serviceType_recall => 'Retiro/Seguridad';

  @override
  String get enum_serviceType_repair => 'Reparación';

  @override
  String get enum_serviceType_replacement => 'Reemplazo de pieza';

  @override
  String get enum_serviceType_warranty => 'Servicio de garantía';

  @override
  String get enum_sortDirection_ascending => 'Ascendente';

  @override
  String get enum_sortDirection_descending => 'Descendente';

  @override
  String get enum_sortField_agency => 'Agencia';

  @override
  String get enum_sortField_date => 'Fecha';

  @override
  String get enum_sortField_dateIssued => 'Fecha de emisión';

  @override
  String get enum_sortField_difficulty => 'Dificultad';

  @override
  String get enum_sortField_diveCount => 'Número de inmersiones';

  @override
  String get enum_sortField_diveNumber => 'Número de inmersión';

  @override
  String get enum_sortField_duration => 'Duración';

  @override
  String get enum_sortField_endDate => 'Fecha de fin';

  @override
  String get enum_sortField_lastServiceDate => 'Último servicio';

  @override
  String get enum_sortField_maxDepth => 'Profundidad máxima';

  @override
  String get enum_sortField_name => 'Nombre';

  @override
  String get enum_sortField_purchaseDate => 'Fecha de compra';

  @override
  String get enum_sortField_rating => 'Valoración';

  @override
  String get enum_sortField_site => 'Punto de buceo';

  @override
  String get enum_sortField_startDate => 'Fecha de inicio';

  @override
  String get enum_sortField_status => 'Estado';

  @override
  String get enum_sortField_type => 'Tipo';

  @override
  String get enum_speciesCategory_coral => 'Coral';

  @override
  String get enum_speciesCategory_fish => 'Pez';

  @override
  String get enum_speciesCategory_invertebrate => 'Invertebrado';

  @override
  String get enum_speciesCategory_mammal => 'Mamífero';

  @override
  String get enum_speciesCategory_other => 'Otro';

  @override
  String get enum_speciesCategory_plant => 'Planta/Alga';

  @override
  String get enum_speciesCategory_ray => 'Raya';

  @override
  String get enum_speciesCategory_shark => 'Tiburón';

  @override
  String get enum_speciesCategory_turtle => 'Tortuga';

  @override
  String get enum_tankMaterial_aluminum => 'Aluminio';

  @override
  String get enum_tankMaterial_carbonFiber => 'Fibra de carbono';

  @override
  String get enum_tankMaterial_steel => 'Acero';

  @override
  String get enum_tankRole_backGas => 'Gas principal';

  @override
  String get enum_tankRole_bailout => 'Bailout';

  @override
  String get enum_tankRole_deco => 'Deco';

  @override
  String get enum_tankRole_diluent => 'Diluyente';

  @override
  String get enum_tankRole_oxygenSupply => 'Suministro de O₂';

  @override
  String get enum_tankRole_pony => 'Botella pony';

  @override
  String get enum_tankRole_sidemountLeft => 'Sidemount izquierdo';

  @override
  String get enum_tankRole_sidemountRight => 'Sidemount derecho';

  @override
  String get enum_tankRole_stage => 'Stage';

  @override
  String get enum_visibility_excellent => 'Excelente (>30m / >100ft)';

  @override
  String get enum_visibility_good => 'Buena (15-30m / 50-100ft)';

  @override
  String get enum_visibility_moderate => 'Moderada (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => 'Mala (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => 'Desconocida';

  @override
  String get enum_waterType_brackish => 'Salobre';

  @override
  String get enum_waterType_fresh => 'Agua dulce';

  @override
  String get enum_waterType_salt => 'Agua salada';

  @override
  String get enum_weightType_ankleWeights => 'Lastres de tobillo';

  @override
  String get enum_weightType_backplate => 'Lastres de espalda';

  @override
  String get enum_weightType_belt => 'Cinturón de lastre';

  @override
  String get enum_weightType_integrated => 'Lastres integrados';

  @override
  String get enum_weightType_mixed => 'Mixto/Combinado';

  @override
  String get enum_weightType_trimWeights => 'Lastres de trimado';

  @override
  String get equipment_addSheet_brandHint => 'p. ej., Scubapro';

  @override
  String get equipment_addSheet_brandLabel => 'Marca';

  @override
  String get equipment_addSheet_closeTooltip => 'Cerrar';

  @override
  String get equipment_addSheet_currencyLabel => 'Moneda';

  @override
  String get equipment_addSheet_dateLabel => 'Fecha';

  @override
  String equipment_addSheet_errorSnackbar(Object error) {
    return 'Error al agregar equipo: $error';
  }

  @override
  String get equipment_addSheet_modelHint => 'p. ej., MK25 EVO';

  @override
  String get equipment_addSheet_modelLabel => 'Modelo';

  @override
  String get equipment_addSheet_nameHint => 'p. ej., Mi regulador principal';

  @override
  String get equipment_addSheet_nameLabel => 'Nombre';

  @override
  String get equipment_addSheet_nameValidation => 'Por favor ingresa un nombre';

  @override
  String get equipment_addSheet_notesHint => 'Notas adicionales...';

  @override
  String get equipment_addSheet_notesLabel => 'Notas';

  @override
  String get equipment_addSheet_priceLabel => 'Precio';

  @override
  String get equipment_addSheet_purchaseInfoTitle => 'Informacion de compra';

  @override
  String get equipment_addSheet_serialNumberLabel => 'Numero de serie';

  @override
  String get equipment_addSheet_serviceIntervalHint => 'p. ej., 365 para anual';

  @override
  String get equipment_addSheet_serviceIntervalLabel =>
      'Intervalo de servicio (dias)';

  @override
  String get equipment_addSheet_sizeHint => 'p. ej., M, L, 42';

  @override
  String get equipment_addSheet_sizeLabel => 'Talla';

  @override
  String get equipment_addSheet_submitButton => 'Agregar equipo';

  @override
  String get equipment_addSheet_successSnackbar =>
      'Equipo agregado exitosamente';

  @override
  String get equipment_addSheet_title => 'Agregar equipo';

  @override
  String get equipment_addSheet_typeLabel => 'Tipo';

  @override
  String get equipment_appBar_title => 'Equipo';

  @override
  String get equipment_deleteDialog_cancel => 'Cancelar';

  @override
  String get equipment_deleteDialog_confirm => 'Eliminar';

  @override
  String get equipment_deleteDialog_content =>
      'Estas seguro de que deseas eliminar este equipo? Esta accion no se puede deshacer.';

  @override
  String get equipment_deleteDialog_title => 'Eliminar equipo';

  @override
  String get equipment_detail_brandLabel => 'Marca';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return '$days dias de retraso';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days dias hasta el servicio';
  }

  @override
  String get equipment_detail_detailsTitle => 'Detalles';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count inmersiones';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count inmersion';
  }

  @override
  String get equipment_detail_divesLabel => 'Inmersiones';

  @override
  String get equipment_detail_divesSemanticLabel =>
      'Ver inmersiones con este equipo';

  @override
  String equipment_detail_durationDays(Object days) {
    return '$days dias';
  }

  @override
  String equipment_detail_durationMonths(Object months) {
    return '$months meses';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralPlural(
    Object years,
    Object months,
  ) {
    return '$years anos, $months meses';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralSingular(
    Object years,
    Object months,
  ) {
    return '$years anos, $months mes';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularPlural(
    Object years,
    Object months,
  ) {
    return '$years ano, $months meses';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularSingular(
    Object years,
    Object months,
  ) {
    return '$years ano, $months mes';
  }

  @override
  String equipment_detail_durationYearsPlural(Object years) {
    return '$years anos';
  }

  @override
  String equipment_detail_durationYearsSingular(Object years) {
    return '$years ano';
  }

  @override
  String get equipment_detail_editTooltip => 'Editar equipo';

  @override
  String get equipment_detail_editTooltipShort => 'Editar';

  @override
  String equipment_detail_errorMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get equipment_detail_errorTitle => 'Error';

  @override
  String get equipment_detail_lastServiceLabel => 'Ultimo servicio';

  @override
  String get equipment_detail_loadingTitle => 'Cargando...';

  @override
  String get equipment_detail_modelLabel => 'Modelo';

  @override
  String get equipment_detail_nextServiceDueLabel => 'Proximo servicio';

  @override
  String get equipment_detail_notFoundMessage => 'Este equipo ya no existe.';

  @override
  String get equipment_detail_notFoundTitle => 'Equipo no encontrado';

  @override
  String get equipment_detail_notesTitle => 'Notas';

  @override
  String get equipment_detail_ownedForLabel => 'En posesion durante';

  @override
  String get equipment_detail_purchaseDateLabel => 'Fecha de compra';

  @override
  String get equipment_detail_purchasePriceLabel => 'Precio de compra';

  @override
  String get equipment_detail_retiredChip => 'Retirado';

  @override
  String get equipment_detail_serialNumberLabel => 'Numero de serie';

  @override
  String get equipment_detail_serviceInfoTitle => 'Informacion de servicio';

  @override
  String get equipment_detail_serviceIntervalLabel => 'Intervalo de servicio';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days dias';
  }

  @override
  String get equipment_detail_serviceOverdue => 'El servicio esta atrasado!';

  @override
  String get equipment_detail_sizeLabel => 'Talla';

  @override
  String get equipment_detail_statusLabel => 'Estado';

  @override
  String equipment_detail_tripsCountPlural(Object count) {
    return '$count viajes';
  }

  @override
  String equipment_detail_tripsCountSingular(Object count) {
    return '$count viaje';
  }

  @override
  String get equipment_detail_tripsLabel => 'Viajes';

  @override
  String get equipment_detail_tripsSemanticLabel =>
      'Ver viajes con este equipo';

  @override
  String get equipment_edit_appBar_editTitle => 'Editar equipo';

  @override
  String get equipment_edit_appBar_newTitle => 'Nuevo equipo';

  @override
  String get equipment_edit_appBar_saveButton => 'Guardar';

  @override
  String get equipment_edit_appBar_saveTooltip => 'Guardar cambios del equipo';

  @override
  String get equipment_edit_brandLabel => 'Marca';

  @override
  String get equipment_edit_clearDate => 'Borrar fecha';

  @override
  String get equipment_edit_currencyLabel => 'Moneda';

  @override
  String get equipment_edit_disableReminders => 'Desactivar recordatorios';

  @override
  String get equipment_edit_disableRemindersSubtitle =>
      'Desactivar todas las notificaciones para este articulo';

  @override
  String get equipment_edit_discardDialog_content =>
      'Tienes cambios sin guardar. Estas seguro de que deseas salir?';

  @override
  String get equipment_edit_discardDialog_discard => 'Descartar';

  @override
  String get equipment_edit_discardDialog_keepEditing => 'Seguir editando';

  @override
  String get equipment_edit_discardDialog_title => 'Descartar cambios?';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => 'Cancelar';

  @override
  String get equipment_edit_embeddedHeader_editTitle => 'Editar equipo';

  @override
  String get equipment_edit_embeddedHeader_newTitle => 'Nuevo equipo';

  @override
  String get equipment_edit_embeddedHeader_saveButton => 'Guardar';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit =>
      'Guardar cambios del equipo';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new =>
      'Agregar nuevo equipo';

  @override
  String equipment_edit_errorMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get equipment_edit_errorTitle => 'Error';

  @override
  String get equipment_edit_lastServiceDateLabel => 'Fecha del ultimo servicio';

  @override
  String get equipment_edit_loadingTitle => 'Cargando...';

  @override
  String get equipment_edit_modelLabel => 'Modelo';

  @override
  String get equipment_edit_nameHint => 'p. ej., Mi regulador principal';

  @override
  String get equipment_edit_nameLabel => 'Nombre *';

  @override
  String get equipment_edit_nameValidation => 'Por favor ingresa un nombre';

  @override
  String get equipment_edit_notFoundMessage => 'Este equipo ya no existe.';

  @override
  String get equipment_edit_notFoundTitle => 'Equipo no encontrado';

  @override
  String get equipment_edit_notesHint =>
      'Notas adicionales sobre este equipo...';

  @override
  String get equipment_edit_notesLabel => 'Notas';

  @override
  String get equipment_edit_notificationsSubtitle =>
      'Anular la configuracion global de notificaciones para este articulo';

  @override
  String get equipment_edit_notificationsTitle => 'Notificaciones (opcional)';

  @override
  String get equipment_edit_purchaseDateLabel => 'Fecha de compra';

  @override
  String get equipment_edit_purchaseInfoTitle => 'Informacion de compra';

  @override
  String get equipment_edit_purchasePriceLabel => 'Precio de compra';

  @override
  String get equipment_edit_remindMeBeforeServiceDue =>
      'Recordarme antes del proximo servicio:';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days dias';
  }

  @override
  String get equipment_edit_saveButton_edit => 'Guardar cambios';

  @override
  String get equipment_edit_saveButton_new => 'Agregar equipo';

  @override
  String get equipment_edit_saveTooltip_edit => 'Guardar cambios del equipo';

  @override
  String get equipment_edit_saveTooltip_new => 'Agregar nuevo equipo';

  @override
  String get equipment_edit_selectDate => 'Seleccionar fecha';

  @override
  String get equipment_edit_serialNumberLabel => 'Numero de serie';

  @override
  String get equipment_edit_serviceIntervalHint => 'p. ej., 365 para anual';

  @override
  String get equipment_edit_serviceIntervalLabel =>
      'Intervalo de servicio (dias)';

  @override
  String get equipment_edit_serviceSettingsTitle => 'Configuracion de servicio';

  @override
  String get equipment_edit_sizeHint => 'p. ej., M, L, 42';

  @override
  String get equipment_edit_sizeLabel => 'Talla';

  @override
  String get equipment_edit_snackbar_added => 'Equipo agregado';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return 'Error al guardar el equipo: $error';
  }

  @override
  String get equipment_edit_snackbar_updated => 'Equipo actualizado';

  @override
  String get equipment_edit_statusLabel => 'Estado';

  @override
  String get equipment_edit_typeLabel => 'Tipo *';

  @override
  String get equipment_edit_useCustomReminders =>
      'Usar recordatorios personalizados';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'Establecer dias de recordatorio diferentes para este articulo';

  @override
  String get equipment_fab_addEquipment => 'Agregar equipo';

  @override
  String get equipment_list_emptyState_addFirstButton =>
      'Agrega tu primer equipo';

  @override
  String get equipment_list_emptyState_addPrompt =>
      'Agrega tu equipo de buceo para rastrear el uso y servicio';

  @override
  String get equipment_list_emptyState_filterText_equipment => 'equipo';

  @override
  String get equipment_list_emptyState_filterText_serviceDue =>
      'equipo que necesita servicio';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return 'equipo $status';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return 'No hay $filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch =>
      'No hay equipo con este estado';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate =>
      'Todo tu equipo esta al dia con el servicio!';

  @override
  String equipment_list_errorLoading(Object error) {
    return 'Error al cargar el equipo: $error';
  }

  @override
  String get equipment_list_filterAll => 'Todo el equipo';

  @override
  String get equipment_list_filterLabel => 'Filtro:';

  @override
  String get equipment_list_filterServiceDue => 'Servicio pendiente';

  @override
  String get equipment_list_retryButton => 'Reintentar';

  @override
  String get equipment_list_searchTooltip => 'Buscar equipo';

  @override
  String get equipment_list_setsTooltip => 'Conjuntos de equipo';

  @override
  String get equipment_list_sortTitle => 'Ordenar equipo';

  @override
  String get equipment_list_sortTooltip => 'Ordenar';

  @override
  String equipment_list_tile_daysCount(Object days) {
    return '$days dias';
  }

  @override
  String get equipment_list_tile_serviceDueChip => 'Servicio pendiente';

  @override
  String get equipment_list_tile_serviceIn => 'Servicio en';

  @override
  String get equipment_menu_delete => 'Eliminar';

  @override
  String get equipment_menu_markAsServiced => 'Marcar como revisado';

  @override
  String get equipment_menu_reactivate => 'Reactivar';

  @override
  String get equipment_menu_retireEquipment => 'Retirar equipo';

  @override
  String get equipment_search_backTooltip => 'Atras';

  @override
  String get equipment_search_clearTooltip => 'Borrar busqueda';

  @override
  String get equipment_search_fieldLabel => 'Buscar equipo...';

  @override
  String get equipment_search_hint =>
      'Buscar por nombre, marca, modelo o numero de serie';

  @override
  String equipment_search_noResults(Object query) {
    return 'No se encontro equipo para \"$query\"';
  }

  @override
  String get equipment_serviceDialog_addButton => 'Agregar';

  @override
  String get equipment_serviceDialog_addTitle => 'Agregar registro de servicio';

  @override
  String get equipment_serviceDialog_cancelButton => 'Cancelar';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip =>
      'Borrar fecha del proximo servicio';

  @override
  String get equipment_serviceDialog_costHint => '0.00';

  @override
  String get equipment_serviceDialog_costLabel => 'Costo';

  @override
  String get equipment_serviceDialog_costValidation =>
      'Ingresa un monto valido';

  @override
  String get equipment_serviceDialog_editTitle => 'Editar registro de servicio';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel => 'Proximo servicio';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel =>
      'Seleccionar fecha del proximo servicio';

  @override
  String get equipment_serviceDialog_nextServiceNotSet => 'No establecido';

  @override
  String get equipment_serviceDialog_notesLabel => 'Notas';

  @override
  String get equipment_serviceDialog_providerHint =>
      'p. ej., Nombre de la tienda de buceo';

  @override
  String get equipment_serviceDialog_providerLabel => 'Proveedor/Tienda';

  @override
  String get equipment_serviceDialog_serviceDateLabel => 'Fecha de servicio';

  @override
  String get equipment_serviceDialog_serviceDateSemanticLabel =>
      'Seleccionar fecha de servicio';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => 'Tipo de servicio';

  @override
  String get equipment_serviceDialog_snackbar_added =>
      'Registro de servicio agregado';

  @override
  String equipment_serviceDialog_snackbar_error(Object error) {
    return 'Error: $error';
  }

  @override
  String get equipment_serviceDialog_snackbar_updated =>
      'Registro de servicio actualizado';

  @override
  String get equipment_serviceDialog_updateButton => 'Actualizar';

  @override
  String get equipment_service_addButton => 'Agregar';

  @override
  String get equipment_service_deleteDialog_cancel => 'Cancelar';

  @override
  String get equipment_service_deleteDialog_confirm => 'Eliminar';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return 'Estas seguro de que deseas eliminar este registro de $serviceType?';
  }

  @override
  String get equipment_service_deleteDialog_title =>
      'Eliminar registro de servicio?';

  @override
  String get equipment_service_deleteMenuItem => 'Eliminar';

  @override
  String get equipment_service_editMenuItem => 'Editar';

  @override
  String get equipment_service_emptyState => 'Aun no hay registros de servicio';

  @override
  String get equipment_service_historyTitle => 'Historial de servicio';

  @override
  String get equipment_service_snackbar_deleted =>
      'Registro de servicio eliminado';

  @override
  String get equipment_service_totalCostLabel => 'Costo total de servicio';

  @override
  String get equipment_setDetail_addEquipmentButton => 'Agregar equipo';

  @override
  String get equipment_setDetail_deleteDialog_cancel => 'Cancelar';

  @override
  String get equipment_setDetail_deleteDialog_confirm => 'Eliminar';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      'Estas seguro de que deseas eliminar este conjunto de equipo? Los articulos del conjunto no seran eliminados.';

  @override
  String get equipment_setDetail_deleteDialog_title =>
      'Eliminar conjunto de equipo';

  @override
  String get equipment_setDetail_deleteMenuItem => 'Eliminar';

  @override
  String get equipment_setDetail_editTooltip => 'Editar conjunto';

  @override
  String get equipment_setDetail_emptySet => 'No hay equipo en este conjunto';

  @override
  String get equipment_setDetail_equipmentInSetTitle =>
      'Equipo en este conjunto';

  @override
  String equipment_setDetail_errorMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get equipment_setDetail_errorTitle => 'Error';

  @override
  String get equipment_setDetail_loadingTitle => 'Cargando...';

  @override
  String get equipment_setDetail_notFoundMessage =>
      'Este conjunto de equipo ya no existe.';

  @override
  String get equipment_setDetail_notFoundTitle => 'Conjunto no encontrado';

  @override
  String get equipment_setDetail_snackbar_deleted =>
      'Conjunto de equipo eliminado';

  @override
  String get equipment_setEdit_addEquipmentFirst =>
      'Agrega equipo primero antes de crear un conjunto.';

  @override
  String get equipment_setEdit_appBar_editTitle => 'Editar conjunto';

  @override
  String get equipment_setEdit_appBar_newTitle => 'Nuevo conjunto de equipo';

  @override
  String get equipment_setEdit_descriptionHint => 'Descripcion opcional...';

  @override
  String get equipment_setEdit_descriptionLabel => 'Descripcion';

  @override
  String equipment_setEdit_errorMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get equipment_setEdit_errorTitle => 'Error';

  @override
  String get equipment_setEdit_loadingTitle => 'Cargando...';

  @override
  String get equipment_setEdit_nameHint =>
      'p. ej., Configuracion aguas calidas';

  @override
  String get equipment_setEdit_nameLabel => 'Nombre del conjunto *';

  @override
  String get equipment_setEdit_nameValidation => 'Por favor ingresa un nombre';

  @override
  String get equipment_setEdit_noEquipmentAvailable =>
      'No hay equipo disponible';

  @override
  String get equipment_setEdit_notFoundMessage =>
      'Este conjunto de equipo ya no existe.';

  @override
  String get equipment_setEdit_notFoundTitle => 'Conjunto no encontrado';

  @override
  String get equipment_setEdit_saveButton_edit => 'Guardar cambios';

  @override
  String get equipment_setEdit_saveButton_new => 'Crear conjunto';

  @override
  String get equipment_setEdit_saveTooltip_edit =>
      'Guardar cambios del conjunto de equipo';

  @override
  String get equipment_setEdit_saveTooltip_new =>
      'Crear nuevo conjunto de equipo';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle =>
      'Elige los articulos de equipo para incluir en este conjunto.';

  @override
  String get equipment_setEdit_selectEquipmentTitle => 'Seleccionar equipo';

  @override
  String get equipment_setEdit_snackbar_created => 'Conjunto de equipo creado';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return 'Error al guardar el conjunto de equipo: $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated =>
      'Conjunto de equipo actualizado';

  @override
  String get equipment_sets_appBar_title => 'Conjuntos de equipo';

  @override
  String get equipment_sets_emptyState_createFirstButton =>
      'Crea tu primer conjunto';

  @override
  String get equipment_sets_emptyState_description =>
      'Crea conjuntos de equipo para agregar rapidamente combinaciones de equipo de uso frecuente a tus inmersiones.';

  @override
  String get equipment_sets_emptyState_title => 'No hay conjuntos de equipo';

  @override
  String equipment_sets_errorLoading(Object error) {
    return 'Error al cargar los conjuntos: $error';
  }

  @override
  String get equipment_sets_fabTooltip => 'Crear un nuevo conjunto de equipo';

  @override
  String get equipment_sets_fab_createSet => 'Crear conjunto';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count articulos';
  }

  @override
  String equipment_sets_itemCountSemanticLabel(Object count) {
    return '$count en el conjunto';
  }

  @override
  String equipment_sets_itemCountSingular(Object count) {
    return '$count articulo';
  }

  @override
  String get equipment_sets_retryButton => 'Reintentar';

  @override
  String get equipment_snackbar_deleted => 'Equipo eliminado';

  @override
  String get equipment_snackbar_markedAsServiced => 'Marcado como revisado';

  @override
  String get equipment_snackbar_reactivated => 'Equipo reactivado';

  @override
  String get equipment_snackbar_retired => 'Equipo retirado';

  @override
  String get equipment_summary_active => 'Activo';

  @override
  String get equipment_summary_addEquipmentButton => 'Agregar equipo';

  @override
  String get equipment_summary_equipmentSetsButton => 'Conjuntos de equipo';

  @override
  String get equipment_summary_overviewTitle => 'Resumen';

  @override
  String get equipment_summary_quickActionsTitle => 'Acciones rapidas';

  @override
  String get equipment_summary_recentEquipmentTitle => 'Equipo reciente';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name, $type';
  }

  @override
  String get equipment_summary_selectPrompt =>
      'Selecciona un equipo de la lista para ver los detalles';

  @override
  String get equipment_summary_serviceDue => 'Servicio pendiente';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name, $type, servicio pendiente';
  }

  @override
  String get equipment_summary_serviceDueTitle => 'Servicio pendiente';

  @override
  String get equipment_summary_title => 'Equipo';

  @override
  String get equipment_summary_totalItems => 'Total de articulos';

  @override
  String get equipment_summary_totalValue => 'Valor total';

  @override
  String get formatter_approximate_prefix => '~';

  @override
  String get formatter_connector_at => 'a las';

  @override
  String get formatter_connector_from => 'Desde';

  @override
  String get formatter_connector_until => 'Hasta';

  @override
  String get gas_air_description => 'Aire estándar (21% O2)';

  @override
  String get gas_air_displayName => 'Aire';

  @override
  String get gas_diluentAir_description =>
      'Diluyente de aire estándar para CCR poco profundo';

  @override
  String get gas_diluentAir_displayName => 'Diluyente aire';

  @override
  String get gas_diluentTx1070_description =>
      'Diluyente hipóxico para CCR muy profundo';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description =>
      'Diluyente hipóxico para CCR profundo';

  @override
  String get gas_diluentTx1260_displayName => 'Tx 12/60';

  @override
  String get gas_ean32_description => 'Aire enriquecido Nitrox 32%';

  @override
  String get gas_ean32_displayName => 'EAN32';

  @override
  String get gas_ean36_description => 'Aire enriquecido Nitrox 36%';

  @override
  String get gas_ean36_displayName => 'EAN36';

  @override
  String get gas_ean40_description => 'Aire enriquecido Nitrox 40%';

  @override
  String get gas_ean40_displayName => 'EAN40';

  @override
  String get gas_ean50_description => 'Gas deco - 50% O2';

  @override
  String get gas_ean50_displayName => 'EAN50';

  @override
  String get gas_helitrox2525_description =>
      'Helitrox 25/25 (técnico recreativo)';

  @override
  String get gas_helitrox2525_displayName => 'Helitrox 25/25';

  @override
  String get gas_oxygen_description => 'Oxígeno puro (solo deco a 6m)';

  @override
  String get gas_oxygen_displayName => 'Oxígeno';

  @override
  String get gas_scrEan40_description => 'Gas de suministro SCR - 40% O2';

  @override
  String get gas_scrEan40_displayName => 'SCR EAN40';

  @override
  String get gas_scrEan50_description => 'Gas de suministro SCR - 50% O2';

  @override
  String get gas_scrEan50_displayName => 'SCR EAN50';

  @override
  String get gas_scrEan60_description => 'Gas de suministro SCR - 60% O2';

  @override
  String get gas_scrEan60_displayName => 'SCR EAN60';

  @override
  String get gas_tmx1555_description => 'Trimix hipóxico 15/55 (muy profundo)';

  @override
  String get gas_tmx1555_displayName => 'Tx 15/55';

  @override
  String get gas_tmx1845_description => 'Trimix 18/45 (buceo profundo)';

  @override
  String get gas_tmx1845_displayName => 'Tx 18/45';

  @override
  String get gas_tmx2135_description => 'Trimix normóxico 21/35';

  @override
  String get gas_tmx2135_displayName => 'Tx 21/35';

  @override
  String get gasCalculators_bestMix_bestOxygenMix => 'Mejor Mezcla de Oxígeno';

  @override
  String get gasCalculators_bestMix_commonMixesRef =>
      'Referencia de Mezclas Comunes';

  @override
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2) {
    return 'MOD del aire excedida a ppO₂ $ppO2';
  }

  @override
  String get gasCalculators_bestMix_targetDepth => 'Profundidad Objetivo';

  @override
  String get gasCalculators_bestMix_targetDive => 'Inmersión Objetivo';

  @override
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  ) {
    return 'Presión ambiente a $depth$depthSymbol';
  }

  @override
  String get gasCalculators_consumption_avgDepth => 'Profundidad Promedio';

  @override
  String get gasCalculators_consumption_breakdown => 'Desglose del Cálculo';

  @override
  String get gasCalculators_consumption_diveTime => 'Tiempo de Inmersión';

  @override
  String gasCalculators_consumption_exceedsTank(
    Object pressure,
    Object symbol,
  ) {
    return 'Excede la capacidad de la botella ($pressure $symbol)';
  }

  @override
  String get gasCalculators_consumption_gasAtDepth =>
      'Consumo de gas a profundidad';

  @override
  String get gasCalculators_consumption_pressure => 'Presión';

  @override
  String get gasCalculators_consumption_remainingGas => 'Gas restante';

  @override
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  ) {
    return 'Capacidad de la botella ($tankSize$volumeSymbol @ $fillPressure $pressureSymbol)';
  }

  @override
  String get gasCalculators_consumption_title => 'Consumo de Gas';

  @override
  String gasCalculators_consumption_totalGas(Object time) {
    return 'Gas total para $time minutos';
  }

  @override
  String get gasCalculators_consumption_volume => 'Volumen';

  @override
  String get gasCalculators_mod_aboutMod => 'Acerca de MOD';

  @override
  String get gasCalculators_mod_aboutModBody =>
      'Menor O₂ = MOD más profunda = NDL más corta';

  @override
  String get gasCalculators_mod_inputParameters => 'Parámetros de Entrada';

  @override
  String get gasCalculators_mod_maximumOperatingDepth =>
      'Profundidad Máxima de Operación';

  @override
  String get gasCalculators_mod_oxygenO2 => 'Oxígeno (O₂)';

  @override
  String get gasCalculators_mod_ppO2Conservative =>
      'Límite conservador para tiempo de fondo extendido';

  @override
  String get gasCalculators_mod_ppO2Maximum =>
      'Límite máximo solo para paradas de descompresión';

  @override
  String get gasCalculators_mod_ppO2Standard =>
      'Límite de trabajo estándar para buceo recreativo';

  @override
  String get gasCalculators_ppO2Limit => 'Límite ppO₂';

  @override
  String get gasCalculators_resetAll => 'Restablecer todas las calculadoras';

  @override
  String get gasCalculators_sacRate => 'Tasa SAC';

  @override
  String get gasCalculators_tab_bestMix => 'Mejor Mezcla';

  @override
  String get gasCalculators_tab_consumption => 'Consumo';

  @override
  String get gasCalculators_tab_mod => 'MOD';

  @override
  String get gasCalculators_tab_rockBottom => 'Rock Bottom';

  @override
  String get gasCalculators_tankSize => 'Tamaño de Botella';

  @override
  String get gasCalculators_title => 'Calculadoras de Gas';

  @override
  String get marineLife_siteSection_editExpectedTooltip =>
      'Editar especies esperadas';

  @override
  String get marineLife_siteSection_errorLoadingExpected =>
      'Error al cargar especies esperadas';

  @override
  String get marineLife_siteSection_errorLoadingSightings =>
      'Error al cargar avistamientos';

  @override
  String get marineLife_siteSection_expectedSpecies => 'Especies esperadas';

  @override
  String get marineLife_siteSection_noExpected =>
      'No se han agregado especies esperadas';

  @override
  String get marineLife_siteSection_noSpotted =>
      'No se ha avistado vida marina aun';

  @override
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  ) {
    return '$name, avistado $count veces';
  }

  @override
  String get marineLife_siteSection_spottedHere => 'Avistados aqui';

  @override
  String get marineLife_siteSection_title => 'Vida marina';

  @override
  String get marineLife_speciesDetail_backTooltip => 'Atras';

  @override
  String get marineLife_speciesDetail_depthRangeTitle => 'Rango de profundidad';

  @override
  String get marineLife_speciesDetail_descriptionTitle => 'Descripcion';

  @override
  String get marineLife_speciesDetail_divesLabel => 'Inmersiones';

  @override
  String get marineLife_speciesDetail_editTooltip => 'Editar especie';

  @override
  String marineLife_speciesDetail_errorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get marineLife_speciesDetail_noSightings =>
      'No se han registrado avistamientos aun';

  @override
  String get marineLife_speciesDetail_notFound => 'Especie no encontrada';

  @override
  String marineLife_speciesDetail_sightingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'avistamientos',
      one: 'avistamiento',
    );
    return '$count $_temp0';
  }

  @override
  String get marineLife_speciesDetail_sightingPeriodTitle =>
      'Periodo de avistamientos';

  @override
  String get marineLife_speciesDetail_sightingStatsTitle =>
      'Estadisticas de avistamientos';

  @override
  String get marineLife_speciesDetail_sitesLabel => 'Puntos';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return 'Clase: $className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle => 'Mejores puntos';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel =>
      'Total de avistamientos';

  @override
  String get marineLife_speciesEdit_addTitle => 'Agregar especie';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return 'Se agrego \"$name\"';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => 'Atras';

  @override
  String get marineLife_speciesEdit_categoryLabel => 'Categoria';

  @override
  String get marineLife_speciesEdit_commonNameError =>
      'Por favor, introduce un nombre comun';

  @override
  String get marineLife_speciesEdit_commonNameHint => 'ej., Pez payaso comun';

  @override
  String get marineLife_speciesEdit_commonNameLabel => 'Nombre comun';

  @override
  String get marineLife_speciesEdit_descriptionHint =>
      'Breve descripcion de la especie...';

  @override
  String get marineLife_speciesEdit_descriptionLabel => 'Descripcion';

  @override
  String get marineLife_speciesEdit_editTitle => 'Editar especie';

  @override
  String marineLife_speciesEdit_errorLoading(Object error) {
    return 'Error al cargar especie: $error';
  }

  @override
  String marineLife_speciesEdit_errorSaving(Object error) {
    return 'Error al guardar especie: $error';
  }

  @override
  String get marineLife_speciesEdit_saveButton => 'Guardar';

  @override
  String get marineLife_speciesEdit_scientificNameHint =>
      'ej., Amphiprion ocellaris';

  @override
  String get marineLife_speciesEdit_scientificNameLabel => 'Nombre cientifico';

  @override
  String get marineLife_speciesEdit_taxonomyClassHint => 'ej., Actinopterygii';

  @override
  String get marineLife_speciesEdit_taxonomyClassLabel => 'Clase taxonomica';

  @override
  String marineLife_speciesEdit_updatedSnackbar(Object name) {
    return 'Se actualizo \"$name\"';
  }

  @override
  String get marineLife_speciesManage_allFilter => 'Todas';

  @override
  String get marineLife_speciesManage_appBarTitle => 'Especies';

  @override
  String get marineLife_speciesManage_backTooltip => 'Atras';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return 'Especies integradas ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => 'Cancelar';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return 'No se puede eliminar \"$name\": tiene avistamientos';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip => 'Borrar busqueda';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return 'Especies personalizadas ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => 'Eliminar';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return 'Estas seguro de que deseas eliminar \"$name\"?';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle => 'Eliminar especie?';

  @override
  String get marineLife_speciesManage_deleteTooltip => 'Eliminar especie';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return 'Se elimino \"$name\"';
  }

  @override
  String get marineLife_speciesManage_editTooltip => 'Editar especie';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return 'Error al eliminar especie: $error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return 'Error al restablecer especies: $error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound =>
      'No se encontraron especies';

  @override
  String get marineLife_speciesManage_resetButton => 'Restablecer';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      'Esto restaurara todas las especies integradas a sus valores originales. Las especies personalizadas no se veran afectadas. Las especies integradas con avistamientos existentes se actualizaran pero se conservaran.';

  @override
  String get marineLife_speciesManage_resetDialogTitle =>
      'Restablecer a valores predeterminados?';

  @override
  String get marineLife_speciesManage_resetSuccess =>
      'Especies integradas restauradas a valores predeterminados';

  @override
  String get marineLife_speciesManage_resetToDefaults =>
      'Restablecer a valores predeterminados';

  @override
  String get marineLife_speciesManage_searchHint => 'Buscar especies...';

  @override
  String get marineLife_speciesPicker_allFilter => 'Todas';

  @override
  String get marineLife_speciesPicker_cancelButton => 'Cancelar';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip => 'Borrar busqueda';

  @override
  String get marineLife_speciesPicker_closeTooltip =>
      'Cerrar selector de especies';

  @override
  String get marineLife_speciesPicker_doneButton => 'Listo';

  @override
  String marineLife_speciesPicker_error(Object error) {
    return 'Error: $error';
  }

  @override
  String get marineLife_speciesPicker_noSpeciesFound =>
      'No se encontraron especies';

  @override
  String get marineLife_speciesPicker_searchHint => 'Buscar especies...';

  @override
  String marineLife_speciesPicker_selectedCount(Object count) {
    return '$count seleccionadas';
  }

  @override
  String get marineLife_speciesPicker_title => 'Seleccionar especies';

  @override
  String get media_diveMediaSection_addTooltip => 'Agregar foto o video';

  @override
  String get media_diveMediaSection_cancelButton => 'Cancelar';

  @override
  String get media_diveMediaSection_emptyState => 'No hay fotos aun';

  @override
  String get media_diveMediaSection_errorLoading => 'Error al cargar medios';

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Ver foto. Mantener presionado para desvincular';

  @override
  String get media_diveMediaSection_title => 'Fotos y video';

  @override
  String get media_diveMediaSection_unlinkButton => 'Desvincular';

  @override
  String get media_diveMediaSection_unlinkDialogContent =>
      'Eliminar esta foto de la inmersion? La foto permanecera en tu galeria.';

  @override
  String get media_diveMediaSection_unlinkDialogTitle => 'Desvincular foto';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Error al desvincular: $error';
  }

  @override
  String get media_diveMediaSection_unlinkSuccess => 'Foto desvinculada';

  @override
  String get media_gpsBanner_addToSiteButton => 'Agregar al punto';

  @override
  String media_gpsBanner_coordinates(Object latitude, Object longitude) {
    return 'Coordenadas: $latitude, $longitude';
  }

  @override
  String get media_gpsBanner_createSiteButton => 'Crear punto';

  @override
  String get media_gpsBanner_dismissTooltip => 'Descartar sugerencia de GPS';

  @override
  String get media_gpsBanner_title => 'GPS encontrado en las fotos';

  @override
  String media_import_failedToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fotos',
      one: 'foto',
    );
    return 'Error al importar $_temp0';
  }

  @override
  String media_import_failedToImportError(Object error) {
    return 'Error al importar fotos: $error';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return 'Importadas $imported, fallaron $failed';
  }

  @override
  String media_import_importedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fotos',
      one: 'foto',
    );
    return 'Se importaron $count $_temp0';
  }

  @override
  String media_import_importingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fotos',
      one: 'foto',
    );
    return 'Importando $count $_temp0...';
  }

  @override
  String get media_miniProfile_headerLabel => 'Perfil de inmersion';

  @override
  String get media_miniProfile_semanticLabel =>
      'Grafico del perfil de inmersion en miniatura';

  @override
  String get media_photoPicker_appBarTitle => 'Seleccionar fotos';

  @override
  String get media_photoPicker_closeTooltip => 'Cerrar selector de fotos';

  @override
  String get media_photoPicker_doneButton => 'Listo';

  @override
  String media_photoPicker_doneCountButton(Object count) {
    return 'Listo ($count)';
  }

  @override
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  ) {
    return 'No se encontraron fotos entre $startDate $startTime y $endDate $endTime.';
  }

  @override
  String get media_photoPicker_emptyTitle => 'No se encontraron fotos';

  @override
  String get media_photoPicker_grantAccessButton => 'Conceder acceso';

  @override
  String get media_photoPicker_openSettingsButton => 'Abrir ajustes';

  @override
  String get media_photoPicker_openSettingsSnackbar =>
      'Por favor, abre Ajustes y activa el acceso a fotos';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'Se denego el acceso a la biblioteca de fotos. Activalo en Ajustes para agregar fotos de buceo.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion necesita acceso a tu biblioteca de fotos para agregar fotos de buceo.';

  @override
  String get media_photoPicker_permissionTitle => 'Se requiere acceso a fotos';

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return 'Mostrando fotos de $rangeText';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel =>
      'Alternar seleccion de foto';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel =>
      'Alternar seleccion de foto, seleccionada';

  @override
  String get media_photoViewer_cannotShare => 'No se puede compartir esta foto';

  @override
  String get media_photoViewer_cannotWriteMetadata =>
      'No se pueden escribir los metadatos: medio no vinculado a la biblioteca';

  @override
  String get media_photoViewer_closeTooltip => 'Cerrar visor de fotos';

  @override
  String get media_photoViewer_diveDataWrittenToPhoto =>
      'Datos de inmersion escritos en la foto';

  @override
  String get media_photoViewer_diveDataWrittenToVideo =>
      'Datos de inmersion escritos en el video';

  @override
  String media_photoViewer_errorLoadingPhotos(Object error) {
    return 'Error al cargar fotos: $error';
  }

  @override
  String get media_photoViewer_failedToLoadImage => 'Error al cargar la imagen';

  @override
  String get media_photoViewer_failedToLoadVideo => 'Error al cargar el video';

  @override
  String media_photoViewer_failedToShare(Object error) {
    return 'Error al compartir: $error';
  }

  @override
  String get media_photoViewer_failedToWriteMetadata =>
      'Error al escribir los metadatos';

  @override
  String media_photoViewer_failedToWriteMetadataError(Object error) {
    return 'Error al escribir los metadatos: $error';
  }

  @override
  String get media_photoViewer_noPhotosAvailable => 'No hay fotos disponibles';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel =>
      'Reproducir o pausar video';

  @override
  String get media_photoViewer_seekVideoLabel => 'Buscar posicion del video';

  @override
  String get media_photoViewer_shareTooltip => 'Compartir foto';

  @override
  String get media_photoViewer_toggleOverlayLabel =>
      'Alternar superposicion de foto';

  @override
  String get media_photoViewer_videoFileNotFound =>
      'Archivo de video no encontrado';

  @override
  String get media_photoViewer_videoNotLinked =>
      'Video no vinculado a la biblioteca';

  @override
  String get media_photoViewer_writeDiveDataTooltip =>
      'Escribir datos de inmersion en la foto';

  @override
  String get media_quickSiteDialog_cancelButton => 'Cancelar';

  @override
  String get media_quickSiteDialog_createButton => 'Crear punto';

  @override
  String get media_quickSiteDialog_description =>
      'Crea un nuevo punto de buceo usando las coordenadas GPS de tu foto.';

  @override
  String get media_quickSiteDialog_siteNameError =>
      'Por favor, introduce un nombre de punto';

  @override
  String get media_quickSiteDialog_siteNameHint =>
      'Introduce un nombre para este punto';

  @override
  String get media_quickSiteDialog_siteNameLabel => 'Nombre del punto';

  @override
  String get media_quickSiteDialog_title => 'Crear punto de buceo';

  @override
  String get media_scanResults_allPhotosLinked =>
      'Todas las fotos ya estan vinculadas';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return 'Las $count fotos de este viaje ya estan vinculadas a inmersiones.';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count fotos ya vinculadas';
  }

  @override
  String get media_scanResults_cancelButton => 'Cancelar';

  @override
  String media_scanResults_diveNumber(Object number) {
    return 'Inmersion #$number';
  }

  @override
  String media_scanResults_foundNewPhotos(Object count) {
    return 'Se encontraron $count fotos nuevas';
  }

  @override
  String get media_scanResults_linkButton => 'Vincular';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return 'Vincular $count fotos';
  }

  @override
  String get media_scanResults_noPhotosFound => 'No se encontraron fotos';

  @override
  String get media_scanResults_okButton => 'OK';

  @override
  String get media_scanResults_unknownSite => 'Punto desconocido';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return '$count fotos no pudieron asociarse a ninguna inmersion (tomadas fuera de los horarios de buceo)';
  }

  @override
  String get media_writeMetadata_cancelButton => 'Cancelar';

  @override
  String get media_writeMetadata_depthLabel => 'Profundidad';

  @override
  String get media_writeMetadata_descriptionPhoto =>
      'Los siguientes metadatos se escribiran en la foto:';

  @override
  String get media_writeMetadata_descriptionVideo =>
      'Los siguientes metadatos se escribiran en el video:';

  @override
  String get media_writeMetadata_diveTimeLabel => 'Hora de inmersion';

  @override
  String get media_writeMetadata_gpsLabel => 'GPS';

  @override
  String get media_writeMetadata_keepOriginalVideo =>
      'Conservar video original';

  @override
  String get media_writeMetadata_noDataAvailable =>
      'No hay datos de inmersion disponibles para escribir.';

  @override
  String get media_writeMetadata_siteLabel => 'Punto';

  @override
  String get media_writeMetadata_temperatureLabel => 'Temperatura';

  @override
  String get media_writeMetadata_titlePhoto =>
      'Escribir datos de inmersion en la foto';

  @override
  String get media_writeMetadata_titleVideo =>
      'Escribir datos de inmersion en el video';

  @override
  String get media_writeMetadata_warningPhotoText =>
      'Esto modificara la foto original.';

  @override
  String get media_writeMetadata_warningVideoText =>
      'Se creara un nuevo video con los metadatos. Los metadatos del video no se pueden modificar en su lugar.';

  @override
  String get media_writeMetadata_writeButton => 'Escribir';

  @override
  String get nav_buddies => 'Compañeros';

  @override
  String get nav_certifications => 'Certificaciones';

  @override
  String get nav_courses => 'Cursos';

  @override
  String get nav_coursesSubtitle => 'Formación y educación';

  @override
  String get nav_diveCenters => 'Centros de buceo';

  @override
  String get nav_dives => 'Inmersiones';

  @override
  String get nav_equipment => 'Equipo';

  @override
  String get nav_home => 'Inicio';

  @override
  String get nav_more => 'Más';

  @override
  String get nav_planning => 'Planificación';

  @override
  String get nav_planningSubtitle =>
      'Planificador de inmersiones, calculadoras';

  @override
  String get nav_settings => 'Configuración';

  @override
  String get nav_sites => 'Puntos de buceo';

  @override
  String get nav_statistics => 'Estadísticas';

  @override
  String get nav_tooltip_closeMenu => 'Cerrar menú';

  @override
  String get nav_tooltip_collapseMenu => 'Contraer menú';

  @override
  String get nav_tooltip_expandMenu => 'Expandir menú';

  @override
  String get nav_transfer => 'Transferencia';

  @override
  String get nav_trips => 'Viajes';

  @override
  String get onboarding_welcome_createProfile => 'Crea Tu Perfil';

  @override
  String get onboarding_welcome_createProfileSubtitle =>
      'Ingresa tu nombre para comenzar. Puedes agregar más detalles después.';

  @override
  String get onboarding_welcome_creating => 'Creando...';

  @override
  String onboarding_welcome_errorCreatingProfile(Object error) {
    return 'Error al crear perfil: $error';
  }

  @override
  String get onboarding_welcome_getStarted => 'Comenzar';

  @override
  String get onboarding_welcome_nameHint => 'Ingresa tu nombre';

  @override
  String get onboarding_welcome_nameLabel => 'Tu Nombre';

  @override
  String get onboarding_welcome_nameValidation => 'Por favor ingresa tu nombre';

  @override
  String get onboarding_welcome_subtitle =>
      'Registro y análisis avanzado de inmersiones';

  @override
  String get onboarding_welcome_title => 'Bienvenido a Submersion';

  @override
  String get planning_appBar_title => 'Planificacion';

  @override
  String get planning_card_decoCalculator_description =>
      'Calcula los limites de no descompresion, las paradas de deco requeridas y la exposicion CNS/OTU para perfiles de inmersion multinivel.';

  @override
  String get planning_card_decoCalculator_subtitle =>
      'Planifica inmersiones con paradas de descompresion';

  @override
  String get planning_card_decoCalculator_title => 'Calculadora de deco';

  @override
  String get planning_card_divePlanner_description =>
      'Planifica inmersiones complejas con multiples niveles de profundidad, cambios de gas y calculos automaticos de paradas de descompresion.';

  @override
  String get planning_card_divePlanner_subtitle =>
      'Crea planes de inmersion multinivel';

  @override
  String get planning_card_divePlanner_title => 'Planificador de inmersiones';

  @override
  String get planning_card_gasCalculators_description =>
      'Cuatro calculadoras de gas especializadas:\n• MOD - Profundidad maxima operativa para una mezcla de gas\n• Mejor mezcla - % de O₂ ideal para una profundidad objetivo\n• Consumo - Estimacion de uso de gas\n• Reserva minima - Calculo de reserva de emergencia';

  @override
  String get planning_card_gasCalculators_subtitle =>
      'MOD, Mejor mezcla, Consumo, Reserva minima';

  @override
  String get planning_card_gasCalculators_title => 'Calculadoras de gas';

  @override
  String get planning_card_surfaceInterval_description =>
      'Calcula el intervalo de superficie minimo necesario entre inmersiones basado en la carga tisular. Visualiza como tus 16 compartimentos tisulares desaturan con el tiempo.';

  @override
  String get planning_card_surfaceInterval_subtitle =>
      'Planifica intervalos de inmersiones repetitivas';

  @override
  String get planning_card_surfaceInterval_title => 'Intervalo de superficie';

  @override
  String get planning_card_weightCalculator_description =>
      'Estima el peso que necesitas segun tu traje de exposicion, material del tanque, tipo de agua y peso corporal.';

  @override
  String get planning_card_weightCalculator_subtitle =>
      'Peso recomendado para tu configuracion';

  @override
  String get planning_card_weightCalculator_title => 'Calculadora de peso';

  @override
  String get planning_info_disclaimer =>
      'Estas herramientas son solo para fines de planificacion. Siempre verifica los calculos y sigue tu formacion de buceo.';

  @override
  String get planning_sidebar_appBar_title => 'Planificacion';

  @override
  String get planning_sidebar_decoCalculator_subtitle =>
      'NDL y paradas de deco';

  @override
  String get planning_sidebar_decoCalculator_title => 'Calculadora de deco';

  @override
  String get planning_sidebar_divePlanner_subtitle =>
      'Planes de inmersion multinivel';

  @override
  String get planning_sidebar_divePlanner_title =>
      'Planificador de inmersiones';

  @override
  String get planning_sidebar_gasCalculators_subtitle =>
      'MOD, Mejor mezcla y mas';

  @override
  String get planning_sidebar_gasCalculators_title => 'Calculadoras de gas';

  @override
  String get planning_sidebar_info_disclaimer =>
      'Las herramientas de planificacion son solo de referencia. Siempre verifica los calculos.';

  @override
  String get planning_sidebar_surfaceInterval_subtitle =>
      'Planificacion de inmersiones repetitivas';

  @override
  String get planning_sidebar_surfaceInterval_title =>
      'Intervalo de superficie';

  @override
  String get planning_sidebar_weightCalculator_subtitle => 'Peso recomendado';

  @override
  String get planning_sidebar_weightCalculator_title => 'Calculadora de peso';

  @override
  String get planning_welcome_quickTips_title => 'Consejos rapidos';

  @override
  String get planning_welcome_subtitle =>
      'Selecciona una herramienta de la barra lateral para comenzar';

  @override
  String get planning_welcome_tip_decoCalculator =>
      'Calculadora de deco para NDL y tiempos de parada';

  @override
  String get planning_welcome_tip_divePlanner =>
      'Planificador de inmersiones para planificacion multinivel';

  @override
  String get planning_welcome_tip_gasCalculators =>
      'Calculadoras de gas para MOD y planificacion de gases';

  @override
  String get planning_welcome_tip_weightCalculator =>
      'Calculadora de peso para configuracion de flotabilidad';

  @override
  String get planning_welcome_title => 'Herramientas de planificacion';

  @override
  String get settings_about_aboutSubmersion => 'Acerca de Submersion';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description =>
      'Registra tus inmersiones, administra tu equipo y explora puntos de buceo.';

  @override
  String get settings_about_header => 'Acerca de';

  @override
  String get settings_about_openSourceLicenses => 'Licencias de codigo abierto';

  @override
  String get settings_about_reportIssue => 'Reportar un problema';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Visita github.com/submersion/submersion';

  @override
  String settings_about_version(String version, String buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get settings_appBar_title => 'Ajustes';

  @override
  String get settings_appearance_appLanguage => 'Idioma de la aplicacion';

  @override
  String get settings_appearance_depthColoredCards =>
      'Tarjetas coloreadas por profundidad';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Mostrar tarjetas de inmersion con fondos de color oceanico segun la profundidad';

  @override
  String get settings_appearance_cardColorAttribute => 'Colorear tarjetas por';

  @override
  String get settings_appearance_cardColorAttribute_subtitle =>
      'Elegir que atributo determina el color de fondo de las tarjetas';

  @override
  String get settings_appearance_cardColorAttribute_none => 'Ninguno';

  @override
  String get settings_appearance_cardColorAttribute_depth => 'Profundidad';

  @override
  String get settings_appearance_cardColorAttribute_duration => 'Duracion';

  @override
  String get settings_appearance_cardColorAttribute_temperature =>
      'Temperatura';

  @override
  String get settings_appearance_colorGradient => 'Gradiente de color';

  @override
  String get settings_appearance_colorGradient_subtitle =>
      'Elegir el rango de colores para los fondos de las tarjetas';

  @override
  String get settings_appearance_colorGradient_ocean => 'Oceano';

  @override
  String get settings_appearance_colorGradient_thermal => 'Thermal';

  @override
  String get settings_appearance_colorGradient_sunset => 'Atardecer';

  @override
  String get settings_appearance_colorGradient_forest => 'Bosque';

  @override
  String get settings_appearance_colorGradient_monochrome => 'Monocromo';

  @override
  String get settings_appearance_colorGradient_custom => 'Personalizado';

  @override
  String get settings_appearance_gasSwitchMarkers =>
      'Marcadores de cambio de gas';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'Mostrar marcadores para cambios de gas';

  @override
  String get settings_appearance_header_diveLog => 'Registro de buceo';

  @override
  String get settings_appearance_header_diveProfile => 'Perfil de inmersion';

  @override
  String get settings_appearance_header_diveSites => 'Puntos de buceo';

  @override
  String get settings_appearance_header_language => 'Idioma';

  @override
  String get settings_appearance_header_theme => 'Tema';

  @override
  String get settings_appearance_mapBackgroundDiveCards =>
      'Fondo de mapa en tarjetas de inmersion';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitle =>
      'Mostrar mapa del punto de buceo como fondo en tarjetas de inmersion';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote =>
      'Mostrar mapa del punto de buceo como fondo en tarjetas de inmersion (requiere ubicacion del punto)';

  @override
  String get settings_appearance_mapBackgroundSiteCards =>
      'Fondo de mapa en tarjetas de puntos';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitle =>
      'Mostrar mapa como fondo en tarjetas de puntos de buceo';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote =>
      'Mostrar mapa como fondo en tarjetas de puntos de buceo (requiere ubicacion del punto)';

  @override
  String get settings_appearance_maxDepthMarker =>
      'Marcador de profundidad maxima';

  @override
  String get settings_appearance_maxDepthMarker_subtitle =>
      'Mostrar un marcador en el punto de profundidad maxima';

  @override
  String get settings_appearance_maxDepthMarker_subtitleFull =>
      'Mostrar un marcador en el punto de profundidad maxima en los perfiles de inmersion';

  @override
  String get settings_appearance_metric_ascentRateColors =>
      'Colores de velocidad de ascenso';

  @override
  String get settings_appearance_metric_ceiling => 'Techo';

  @override
  String get settings_appearance_metric_events => 'Eventos';

  @override
  String get settings_appearance_metric_gasDensity => 'Densidad del gas';

  @override
  String get settings_appearance_metric_gfPercent => 'GF%';

  @override
  String get settings_appearance_metric_heartRate => 'Frecuencia cardiaca';

  @override
  String get settings_appearance_metric_meanDepth => 'Profundidad media';

  @override
  String get settings_appearance_metric_ndl => 'NDL';

  @override
  String get settings_appearance_metric_ppHe => 'ppHe';

  @override
  String get settings_appearance_metric_ppN2 => 'ppN2';

  @override
  String get settings_appearance_metric_ppO2 => 'ppO2';

  @override
  String get settings_appearance_metric_pressure => 'Presion';

  @override
  String get settings_appearance_metric_sacRate => 'SAC Rate';

  @override
  String get settings_appearance_metric_surfaceGf => 'GF de superficie';

  @override
  String get settings_appearance_metric_temperature => 'Temperatura';

  @override
  String get settings_appearance_metric_tts => 'TTS (Tiempo a superficie)';

  @override
  String get settings_appearance_pressureThresholdMarkers =>
      'Marcadores de umbral de presion';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Mostrar marcadores cuando la presion del tanque cruza los umbrales';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Mostrar marcadores cuando la presion del tanque cruza los umbrales de 2/3, 1/2 y 1/3';

  @override
  String get settings_appearance_rightYAxisMetric =>
      'Metrica del eje Y derecho';

  @override
  String get settings_appearance_rightYAxisMetric_subtitle =>
      'Metrica predeterminada mostrada en el eje derecho';

  @override
  String get settings_appearance_subsection_decompressionMetrics =>
      'Metricas de descompresion';

  @override
  String get settings_appearance_subsection_defaultVisibleMetrics =>
      'Metricas visibles predeterminadas';

  @override
  String get settings_appearance_subsection_gasAnalysisMetrics =>
      'Metricas de analisis de gas';

  @override
  String get settings_appearance_subsection_gradientFactorMetrics =>
      'Metricas de factores de gradiente';

  @override
  String get settings_appearance_theme_dark => 'Oscuro';

  @override
  String get settings_appearance_theme_light => 'Claro';

  @override
  String get settings_appearance_theme_system => 'Predeterminado del sistema';

  @override
  String get settings_backToSettings_tooltip => 'Volver a ajustes';

  @override
  String get settings_cloudSync_appBar_title => 'Sincronizacion en la nube';

  @override
  String get settings_cloudSync_autoSync => 'Sincronizacion automatica';

  @override
  String get settings_cloudSync_autoSync_subtitle =>
      'Sincronizar automaticamente despues de los cambios';

  @override
  String settings_cloudSync_conflictItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos necesitan atencion',
      one: '1 elemento necesita atencion',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_disabledBanner_content =>
      'La sincronizacion en la nube administrada por la app esta desactivada porque estas usando una carpeta de almacenamiento personalizada. El servicio de sincronizacion de tu carpeta (Dropbox, Google Drive, OneDrive, etc.) se encarga de la sincronizacion.';

  @override
  String get settings_cloudSync_disabledBanner_title =>
      'Sincronizacion en la nube desactivada';

  @override
  String get settings_cloudSync_header_advanced => 'Avanzado';

  @override
  String get settings_cloudSync_header_cloudProvider => 'Proveedor en la nube';

  @override
  String settings_cloudSync_header_conflicts(Object count) {
    return 'Conflictos ($count)';
  }

  @override
  String get settings_cloudSync_header_syncBehavior =>
      'Comportamiento de sincronizacion';

  @override
  String settings_cloudSync_lastSynced(Object time) {
    return 'Ultima sincronizacion: $time';
  }

  @override
  String settings_cloudSync_pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambios pendientes',
      one: '1 cambio pendiente',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_provider_connected => 'Conectado';

  @override
  String settings_cloudSync_provider_connectedTo(Object providerName) {
    return 'Conectado a $providerName';
  }

  @override
  String settings_cloudSync_provider_connectionFailed(
    Object providerName,
    Object error,
  ) {
    return 'Error de conexion con $providerName: $error';
  }

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Sincronizar via Google Drive';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Sincronizar via Apple iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Error al inicializar el proveedor $providerName';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'No disponible en esta plataforma';

  @override
  String get settings_cloudSync_resetDialog_cancel => 'Cancelar';

  @override
  String get settings_cloudSync_resetDialog_content =>
      'Esto borrara todo el historial de sincronizacion y comenzara de nuevo. Tus datos no se eliminaran, pero es posible que debas resolver conflictos en la proxima sincronizacion.';

  @override
  String get settings_cloudSync_resetDialog_reset => 'Restablecer';

  @override
  String get settings_cloudSync_resetDialog_title =>
      'Restablecer estado de sincronizacion?';

  @override
  String get settings_cloudSync_resetSuccess =>
      'Estado de sincronizacion restablecido';

  @override
  String get settings_cloudSync_resetSyncState =>
      'Restablecer estado de sincronizacion';

  @override
  String get settings_cloudSync_resetSyncState_subtitle =>
      'Borrar historial de sincronizacion y comenzar de nuevo';

  @override
  String get settings_cloudSync_resolveConflicts => 'Resolver conflictos';

  @override
  String get settings_cloudSync_selectProviderHint =>
      'Selecciona un proveedor en la nube para activar la sincronizacion';

  @override
  String get settings_cloudSync_signOut => 'Cerrar sesion';

  @override
  String get settings_cloudSync_signOutDialog_cancel => 'Cancelar';

  @override
  String get settings_cloudSync_signOutDialog_content =>
      'Esto desconectara del proveedor en la nube. Tus datos locales permaneceran intactos.';

  @override
  String get settings_cloudSync_signOutDialog_signOut => 'Cerrar sesion';

  @override
  String get settings_cloudSync_signOutDialog_title => 'Cerrar sesion?';

  @override
  String get settings_cloudSync_signOutSuccess =>
      'Sesion cerrada del proveedor en la nube';

  @override
  String get settings_cloudSync_signOut_subtitle =>
      'Desconectar del proveedor en la nube';

  @override
  String get settings_cloudSync_status_conflictsDetected =>
      'Conflictos detectados';

  @override
  String get settings_cloudSync_status_readyToSync => 'Listo para sincronizar';

  @override
  String get settings_cloudSync_status_syncComplete =>
      'Sincronizacion completa';

  @override
  String get settings_cloudSync_status_syncError => 'Error de sincronizacion';

  @override
  String get settings_cloudSync_status_syncing => 'Sincronizando...';

  @override
  String get settings_cloudSync_storageSettings => 'Ajustes de almacenamiento';

  @override
  String get settings_cloudSync_syncNow => 'Sincronizar ahora';

  @override
  String get settings_cloudSync_syncOnLaunch => 'Sincronizar al iniciar';

  @override
  String get settings_cloudSync_syncOnLaunch_subtitle =>
      'Buscar actualizaciones al iniciar';

  @override
  String get settings_cloudSync_syncOnResume => 'Sincronizar al reanudar';

  @override
  String get settings_cloudSync_syncOnResume_subtitle =>
      'Buscar actualizaciones cuando la app se activa';

  @override
  String settings_cloudSync_syncProgressPercent(Object percent) {
    return 'Progreso de sincronizacion: $percent por ciento';
  }

  @override
  String settings_cloudSync_time_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count dias',
      one: 'Hace 1 dia',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_time_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count horas',
      one: 'Hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_time_justNow => 'Justo ahora';

  @override
  String settings_cloudSync_time_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count minutos',
      one: 'Hace 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_applyAll => 'Aplicar todo';

  @override
  String get settings_conflict_cancel => 'Cancelar';

  @override
  String get settings_conflict_chooseResolution => 'Elegir resolucion';

  @override
  String get settings_conflict_close => 'Cerrar';

  @override
  String get settings_conflict_close_tooltip => 'Cerrar dialogo de conflictos';

  @override
  String settings_conflict_counterLabel(Object current, Object total) {
    return 'Conflicto $current de $total';
  }

  @override
  String settings_conflict_errorLoading(Object error) {
    return 'Error al cargar conflictos: $error';
  }

  @override
  String get settings_conflict_keepBoth => 'Conservar ambos';

  @override
  String get settings_conflict_keepLocal => 'Conservar local';

  @override
  String get settings_conflict_keepRemote => 'Conservar remoto';

  @override
  String get settings_conflict_localVersion => 'Version local';

  @override
  String settings_conflict_modified(Object time) {
    return 'Modificado: $time';
  }

  @override
  String get settings_conflict_next_tooltip => 'Siguiente conflicto';

  @override
  String get settings_conflict_noConflicts_message =>
      'Todos los conflictos de sincronizacion han sido resueltos.';

  @override
  String get settings_conflict_noConflicts_title => 'Sin conflictos';

  @override
  String get settings_conflict_noDataAvailable => 'No hay datos disponibles';

  @override
  String get settings_conflict_previous_tooltip => 'Conflicto anterior';

  @override
  String get settings_conflict_remoteVersion => 'Version remota';

  @override
  String settings_conflict_resolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conflictos',
      one: '1 conflicto',
    );
    return 'Se resolvieron $_temp0';
  }

  @override
  String get settings_conflict_title => 'Resolver conflictos';

  @override
  String get settings_data_appDefaultLocation =>
      'Ubicacion predeterminada de la app';

  @override
  String get settings_data_backup => 'Respaldo';

  @override
  String get settings_data_backup_subtitle => 'Crear un respaldo de tus datos';

  @override
  String get settings_data_cloudSync => 'Sincronizacion en la nube';

  @override
  String get settings_data_customFolder => 'Carpeta personalizada';

  @override
  String get settings_data_databaseStorage => 'Almacenamiento de base de datos';

  @override
  String get settings_data_export_completed => 'Exportacion completada';

  @override
  String get settings_data_export_exporting => 'Exportando...';

  @override
  String settings_data_export_failed(Object error) {
    return 'Error en la exportacion: $error';
  }

  @override
  String get settings_data_header_backupSync => 'Respaldo y sincronizacion';

  @override
  String get settings_data_header_storage => 'Almacenamiento';

  @override
  String get settings_data_import_completed => 'Operacion completada';

  @override
  String settings_data_import_failed(Object error) {
    return 'La operacion fallo: $error';
  }

  @override
  String get settings_data_offlineMaps => 'Mapas sin conexion';

  @override
  String get settings_data_offlineMaps_subtitle =>
      'Descargar mapas para uso sin conexion';

  @override
  String get settings_data_restore => 'Restaurar';

  @override
  String get settings_data_restoreDialog_cancel => 'Cancelar';

  @override
  String get settings_data_restoreDialog_content =>
      'Advertencia: Restaurar desde un respaldo reemplazara TODOS los datos actuales con los datos del respaldo. Esta accion no se puede deshacer.\n\nEstas seguro de que deseas continuar?';

  @override
  String get settings_data_restoreDialog_restore => 'Restaurar';

  @override
  String get settings_data_restoreDialog_title => 'Restaurar respaldo';

  @override
  String get settings_data_restore_subtitle => 'Restaurar desde respaldo';

  @override
  String settings_data_syncTime_daysAgo(Object count) {
    return 'Hace ${count}d';
  }

  @override
  String settings_data_syncTime_hoursAgo(Object count) {
    return 'Hace ${count}h';
  }

  @override
  String get settings_data_syncTime_justNow => 'Justo ahora';

  @override
  String settings_data_syncTime_minutesAgo(Object count) {
    return 'Hace ${count}m';
  }

  @override
  String settings_data_sync_lastSynced(Object time) {
    return 'Ultima sincronizacion: $time';
  }

  @override
  String get settings_data_sync_notConfigured => 'No configurado';

  @override
  String get settings_data_sync_syncing => 'Sincronizando...';

  @override
  String get settings_decompression_aboutContent =>
      'Los factores de gradiente (GF) controlan que tan conservadores son tus calculos de descompresion. GF Low afecta las paradas profundas, mientras que GF High afecta las paradas someras.\n\nValores mas bajos = mas conservador = paradas de deco mas largas\nValores mas altos = menos conservador = paradas de deco mas cortas';

  @override
  String get settings_decompression_aboutTitle =>
      'Acerca de los factores de gradiente';

  @override
  String get settings_decompression_currentSettings => 'Ajustes actuales';

  @override
  String get settings_decompression_dialog_cancel => 'Cancelar';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      'Valores mas bajos = mas conservador (NDL mas largo/mas deco)';

  @override
  String get settings_decompression_dialog_customValues =>
      'Valores personalizados';

  @override
  String get settings_decompression_dialog_gfHigh => 'GF High';

  @override
  String get settings_decompression_dialog_gfLow => 'GF Low';

  @override
  String get settings_decompression_dialog_info =>
      'GF Low/High controlan que tan conservadores son tus calculos de NDL y deco.';

  @override
  String get settings_decompression_dialog_presets => 'Preajustes';

  @override
  String get settings_decompression_dialog_save => 'Guardar';

  @override
  String get settings_decompression_dialog_title => 'Factores de gradiente';

  @override
  String settings_decompression_gfValue(Object gfLow, Object gfHigh) {
    return 'GF $gfLow/$gfHigh';
  }

  @override
  String get settings_decompression_header_gradientFactors =>
      'Factores de gradiente';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Seleccionar preajuste de conservadurismo $presetName';
  }

  @override
  String get settings_existingDb_cancel => 'Cancelar';

  @override
  String get settings_existingDb_continue => 'Continuar';

  @override
  String get settings_existingDb_current => 'Actual';

  @override
  String get settings_existingDb_dialog_message =>
      'Ya existe una base de datos de Submersion en esta carpeta.';

  @override
  String get settings_existingDb_dialog_title =>
      'Base de datos existente encontrada';

  @override
  String get settings_existingDb_existing => 'Existente';

  @override
  String get settings_existingDb_replaceWarning =>
      'Se creara un respaldo de la base de datos existente antes de reemplazarla.';

  @override
  String get settings_existingDb_replaceWithMyData =>
      'Reemplazar con mis datos';

  @override
  String get settings_existingDb_replaceWithMyData_subtitle =>
      'Sobrescribir con tu base de datos actual';

  @override
  String get settings_existingDb_stat_buddies => 'Companeros';

  @override
  String get settings_existingDb_stat_dives => 'Inmersiones';

  @override
  String get settings_existingDb_stat_sites => 'Puntos';

  @override
  String get settings_existingDb_stat_trips => 'Viajes';

  @override
  String get settings_existingDb_stat_users => 'Usuarios';

  @override
  String get settings_existingDb_unknown => 'Desconocido';

  @override
  String get settings_existingDb_useExisting => 'Usar base de datos existente';

  @override
  String get settings_existingDb_useExisting_subtitle =>
      'Cambiar a la base de datos en esta carpeta';

  @override
  String get settings_gfPreset_custom_description =>
      'Establece tus propios valores';

  @override
  String get settings_gfPreset_custom_name => 'Personalizado';

  @override
  String get settings_gfPreset_high_description =>
      'Mas conservador, paradas de deco mas largas';

  @override
  String get settings_gfPreset_high_name => 'Alto';

  @override
  String get settings_gfPreset_low_description =>
      'Menos conservador, deco mas corta';

  @override
  String get settings_gfPreset_low_name => 'Bajo';

  @override
  String get settings_gfPreset_medium_description => 'Enfoque equilibrado';

  @override
  String get settings_gfPreset_medium_name => 'Medio';

  @override
  String get settings_import_dialog_title => 'Importando datos';

  @override
  String get settings_import_doNotClose =>
      'Por favor, no cierres la aplicacion';

  @override
  String settings_import_itemCount(Object current, Object total) {
    return '$current de $total';
  }

  @override
  String get settings_import_phase_buddies => 'Importando companeros...';

  @override
  String get settings_import_phase_certifications =>
      'Importando certificaciones...';

  @override
  String get settings_import_phase_complete => 'Finalizando...';

  @override
  String get settings_import_phase_diveCenters =>
      'Importando centros de buceo...';

  @override
  String get settings_import_phase_diveTypes =>
      'Importando tipos de inmersion...';

  @override
  String get settings_import_phase_dives => 'Importando inmersiones...';

  @override
  String get settings_import_phase_equipment => 'Importando equipos...';

  @override
  String get settings_import_phase_equipmentSets =>
      'Importando conjuntos de equipos...';

  @override
  String get settings_import_phase_parsing => 'Analizando archivo...';

  @override
  String get settings_import_phase_preparing => 'Preparando...';

  @override
  String get settings_import_phase_sites => 'Importando puntos de buceo...';

  @override
  String get settings_import_phase_tags => 'Importando etiquetas...';

  @override
  String get settings_import_phase_trips => 'Importando viajes...';

  @override
  String settings_import_progressLabel(
    Object phase,
    Object current,
    Object total,
  ) {
    return '$phase, $current de $total';
  }

  @override
  String settings_import_progressPercent(Object percent) {
    return 'Progreso de importacion: $percent por ciento';
  }

  @override
  String get settings_language_appBar_title => 'Idioma';

  @override
  String get settings_language_selected => 'Seleccionado';

  @override
  String get settings_language_systemDefault => 'Predeterminado del sistema';

  @override
  String get settings_manage_diveTypes => 'Tipos de inmersion';

  @override
  String get settings_manage_diveTypes_subtitle =>
      'Administrar tipos de inmersion personalizados';

  @override
  String get settings_manage_header_manageData => 'Administrar datos';

  @override
  String get settings_manage_species => 'Especies';

  @override
  String get settings_manage_species_subtitle =>
      'Administrar catalogo de especies de vida marina';

  @override
  String get settings_manage_tankPresets => 'Preajustes de tanques';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Administrar configuraciones de tanques personalizadas';

  @override
  String get settings_migrationProgress_doNotClose =>
      'Por favor, no cierres la aplicacion';

  @override
  String get settings_migration_backupInfo =>
      'Se creara un respaldo antes del traslado. Tus datos no se perderan.';

  @override
  String get settings_migration_cancel => 'Cancelar';

  @override
  String get settings_migration_cloudSyncWarning =>
      'La sincronizacion en la nube administrada por la app se desactivara. El servicio de sincronizacion de tu carpeta se encargara de la sincronizacion.';

  @override
  String get settings_migration_dialog_message =>
      'Tu base de datos sera trasladada:';

  @override
  String get settings_migration_dialog_title => 'Trasladar base de datos?';

  @override
  String get settings_migration_from => 'Desde';

  @override
  String get settings_migration_moveDatabase => 'Trasladar base de datos';

  @override
  String get settings_migration_to => 'Hacia';

  @override
  String settings_notifications_days(Object count) {
    return '$count dias';
  }

  @override
  String get settings_notifications_disabled_enableButton => 'Activar';

  @override
  String get settings_notifications_disabled_subtitle =>
      'Activa en los ajustes del sistema para recibir recordatorios';

  @override
  String get settings_notifications_disabled_title =>
      'Notificaciones desactivadas';

  @override
  String get settings_notifications_enableServiceReminders =>
      'Activar recordatorios de servicio';

  @override
  String get settings_notifications_enableServiceReminders_subtitle =>
      'Recibir notificaciones cuando el servicio del equipo sea necesario';

  @override
  String get settings_notifications_header_reminderSchedule =>
      'Programacion de recordatorios';

  @override
  String get settings_notifications_header_serviceReminders =>
      'Recordatorios de servicio';

  @override
  String get settings_notifications_howItWorks_content =>
      'Las notificaciones se programan cuando la app se inicia y se actualizan periodicamente en segundo plano. Puedes personalizar los recordatorios para cada equipo individual en su pantalla de edicion.';

  @override
  String get settings_notifications_howItWorks_title => 'Como funciona';

  @override
  String get settings_notifications_permissionRequired =>
      'Por favor, activa las notificaciones en los ajustes del sistema';

  @override
  String get settings_notifications_remindBeforeDue =>
      'Recordar antes de que venza el servicio:';

  @override
  String get settings_notifications_reminderTime => 'Hora del recordatorio';

  @override
  String get settings_profile_activeDiver_subtitle =>
      'Buceador activo - toca para cambiar';

  @override
  String get settings_profile_addNewDiver => 'Agregar nuevo buceador';

  @override
  String get settings_profile_error_loadingDiver => 'Error al cargar buceador';

  @override
  String get settings_profile_header_activeDiver => 'Buceador activo';

  @override
  String get settings_profile_header_manageDivers => 'Administrar buceadores';

  @override
  String get settings_profile_noDiverProfile => 'Sin perfil de buceador';

  @override
  String get settings_profile_noDiverProfile_subtitle =>
      'Toca para crear tu perfil';

  @override
  String get settings_profile_switchDiver_title => 'Cambiar buceador';

  @override
  String settings_profile_switchedTo(Object diverName) {
    return 'Se cambio a $diverName';
  }

  @override
  String get settings_profile_viewAllDivers => 'Ver todos los buceadores';

  @override
  String get settings_profile_viewAllDivers_subtitle =>
      'Agregar o editar perfiles de buceadores';

  @override
  String get settings_section_about_subtitle =>
      'Informacion de la app y licencias';

  @override
  String get settings_section_about_title => 'Acerca de';

  @override
  String get settings_section_appearance_subtitle => 'Tema y visualizacion';

  @override
  String get settings_section_appearance_title => 'Apariencia';

  @override
  String get settings_section_data_subtitle =>
      'Respaldo, restauracion y almacenamiento';

  @override
  String get settings_section_data_title => 'Datos';

  @override
  String get settings_section_decompression_subtitle => 'Factores de gradiente';

  @override
  String get settings_section_decompression_title => 'Descompresion';

  @override
  String get settings_section_diverProfile_subtitle =>
      'Buceador activo y perfiles';

  @override
  String get settings_section_diverProfile_title => 'Perfil de buceador';

  @override
  String get settings_section_manage_subtitle =>
      'Tipos de inmersion y preajustes de tanques';

  @override
  String get settings_section_manage_title => 'Administrar';

  @override
  String get settings_section_notifications_subtitle =>
      'Recordatorios de servicio';

  @override
  String get settings_section_notifications_title => 'Notificaciones';

  @override
  String get settings_section_units_subtitle => 'Preferencias de medidas';

  @override
  String get settings_section_units_title => 'Unidades';

  @override
  String get settings_storage_appBar_title => 'Almacenamiento de base de datos';

  @override
  String get settings_storage_appDefault => 'Predeterminado de la app';

  @override
  String get settings_storage_appDefaultLocation =>
      'Ubicacion predeterminada de la app';

  @override
  String get settings_storage_appDefault_subtitle =>
      'Ubicacion de almacenamiento estandar de la app';

  @override
  String get settings_storage_currentLocation => 'Ubicacion actual';

  @override
  String get settings_storage_currentLocation_label => 'Ubicacion actual';

  @override
  String get settings_storage_customFolder => 'Carpeta personalizada';

  @override
  String get settings_storage_customFolder_change => 'Cambiar';

  @override
  String get settings_storage_customFolder_subtitle =>
      'Elige una carpeta sincronizada (Dropbox, Google Drive, etc.)';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize • $diveCount inmersiones • $siteCount puntos';
  }

  @override
  String get settings_storage_dismissError_tooltip => 'Descartar error';

  @override
  String get settings_storage_dismissSuccess_tooltip =>
      'Descartar mensaje de exito';

  @override
  String get settings_storage_header_storageLocation =>
      'Ubicacion de almacenamiento';

  @override
  String get settings_storage_info_customActive =>
      'La sincronizacion en la nube administrada por la app esta desactivada. El servicio de sincronizacion de tu carpeta (Dropbox, Google Drive, etc.) se encarga de la sincronizacion.';

  @override
  String get settings_storage_info_customAvailable =>
      'Usar una carpeta personalizada desactiva la sincronizacion en la nube administrada por la app. El servicio de sincronizacion de tu carpeta se encargara de la sincronizacion.';

  @override
  String get settings_storage_loading => 'Cargando...';

  @override
  String get settings_storage_migrating_doNotClose =>
      'Por favor, no cierres la aplicacion';

  @override
  String get settings_storage_migrating_movingDatabase =>
      'Trasladando base de datos...';

  @override
  String get settings_storage_migrating_movingToAppDefault =>
      'Trasladando a ubicacion predeterminada...';

  @override
  String get settings_storage_migrating_replacingExisting =>
      'Reemplazando base de datos existente...';

  @override
  String get settings_storage_migrating_switchingToExisting =>
      'Cambiando a base de datos existente...';

  @override
  String get settings_storage_notSet => 'No establecida';

  @override
  String settings_storage_success_backupAt(Object path) {
    return 'El original se conservo como respaldo en:\n$path';
  }

  @override
  String get settings_storage_success_moved =>
      'Base de datos trasladada correctamente';

  @override
  String get settings_summary_activeDiver => 'Buceador activo';

  @override
  String get settings_summary_currentConfiguration => 'Configuracion actual';

  @override
  String get settings_summary_depth => 'Profundidad';

  @override
  String get settings_summary_error => 'Error';

  @override
  String get settings_summary_gradientFactors => 'Factores de gradiente';

  @override
  String get settings_summary_loading => 'Cargando...';

  @override
  String get settings_summary_notSet => 'No establecido';

  @override
  String get settings_summary_pressure => 'Presion';

  @override
  String get settings_summary_subtitle =>
      'Selecciona una categoria para configurar';

  @override
  String get settings_summary_temperature => 'Temperatura';

  @override
  String get settings_summary_theme => 'Tema';

  @override
  String get settings_summary_theme_dark => 'Oscuro';

  @override
  String get settings_summary_theme_light => 'Claro';

  @override
  String get settings_summary_theme_system => 'Sistema';

  @override
  String get settings_summary_tip =>
      'Consejo: Usa la seccion de Datos para respaldar tus registros de buceo regularmente.';

  @override
  String get settings_summary_title => 'Ajustes';

  @override
  String get settings_summary_unitPreferences => 'Preferencias de unidades';

  @override
  String get settings_summary_units => 'Unidades';

  @override
  String get settings_summary_volume => 'Volumen';

  @override
  String get settings_summary_weight => 'Peso';

  @override
  String get settings_units_custom => 'Personalizado';

  @override
  String get settings_units_dateFormat => 'Formato de fecha';

  @override
  String get settings_units_depth => 'Profundidad';

  @override
  String get settings_units_depth_feet => 'Pies (ft)';

  @override
  String get settings_units_depth_meters => 'Metros (m)';

  @override
  String get settings_units_dialog_dateFormat => 'Formato de fecha';

  @override
  String get settings_units_dialog_depthUnit => 'Unidad de profundidad';

  @override
  String get settings_units_dialog_pressureUnit => 'Unidad de presion';

  @override
  String get settings_units_dialog_sacRateUnit => 'Unidad de SAC Rate';

  @override
  String get settings_units_dialog_temperatureUnit => 'Unidad de temperatura';

  @override
  String get settings_units_dialog_timeFormat => 'Formato de hora';

  @override
  String get settings_units_dialog_volumeUnit => 'Unidad de volumen';

  @override
  String get settings_units_dialog_weightUnit => 'Unidad de peso';

  @override
  String get settings_units_header_individualUnits => 'Unidades individuales';

  @override
  String get settings_units_header_timeDateFormat => 'Formato de hora y fecha';

  @override
  String get settings_units_header_unitSystem => 'Sistema de unidades';

  @override
  String get settings_units_imperial => 'Imperial';

  @override
  String get settings_units_metric => 'Metrico';

  @override
  String get settings_units_pressure => 'Presion';

  @override
  String get settings_units_pressure_bar => 'Bar';

  @override
  String get settings_units_pressure_psi => 'PSI';

  @override
  String get settings_units_quickSelect => 'Seleccion rapida';

  @override
  String get settings_units_sacRate => 'SAC Rate';

  @override
  String get settings_units_sac_pressurePerMinute => 'Presion por minuto';

  @override
  String get settings_units_sac_pressurePerMinute_subtitle =>
      'No requiere volumen del tanque (bar/min o psi/min)';

  @override
  String get settings_units_sac_volumePerMinute => 'Volumen por minuto';

  @override
  String get settings_units_sac_volumePerMinute_subtitle =>
      'Requiere volumen del tanque (L/min o cuft/min)';

  @override
  String get settings_units_temperature => 'Temperatura';

  @override
  String get settings_units_temperature_celsius => 'Celsius (°C)';

  @override
  String get settings_units_temperature_fahrenheit => 'Fahrenheit (°F)';

  @override
  String get settings_units_timeFormat => 'Formato de hora';

  @override
  String get settings_units_volume => 'Volumen';

  @override
  String get settings_units_volume_cubicFeet => 'Pies cubicos (cuft)';

  @override
  String get settings_units_volume_liters => 'Litros (L)';

  @override
  String get settings_units_weight => 'Peso';

  @override
  String get settings_units_weight_kilograms => 'Kilogramos (kg)';

  @override
  String get settings_units_weight_pounds => 'Libras (lbs)';

  @override
  String get signatures_action_clear => 'Limpiar';

  @override
  String get signatures_action_closeSignatureView => 'Cerrar vista de firma';

  @override
  String get signatures_action_deleteSignature => 'Eliminar firma';

  @override
  String get signatures_action_done => 'Listo';

  @override
  String get signatures_action_readyToSign => 'Listo para Firmar';

  @override
  String get signatures_action_request => 'Solicitar';

  @override
  String get signatures_action_saveSignature => 'Guardar Firma';

  @override
  String signatures_buddyCard_notSignedSemantics(Object name) {
    return 'Firma de $name, no firmado';
  }

  @override
  String signatures_buddyCard_signedSemantics(Object name) {
    return 'Firma de $name, firmado';
  }

  @override
  String get signatures_captureInstructorSignature =>
      'Capturar Firma del Instructor';

  @override
  String signatures_deleteDialog_message(Object name) {
    return '¿Estás seguro de que deseas eliminar la firma de $name? Esto no se puede deshacer.';
  }

  @override
  String get signatures_deleteDialog_title => '¿Eliminar Firma?';

  @override
  String get signatures_drawSignatureHint => 'Dibuja tu firma arriba';

  @override
  String get signatures_drawSignatureHintDetailed =>
      'Dibuja tu firma arriba usando el dedo o stylus';

  @override
  String get signatures_drawSignatureSemantics => 'Dibujar firma';

  @override
  String get signatures_error_drawSignature => 'Por favor dibuja una firma';

  @override
  String get signatures_error_enterSignerName =>
      'Por favor ingresa el nombre del firmante';

  @override
  String get signatures_field_instructorName => 'Nombre del Instructor';

  @override
  String get signatures_field_instructorNameHint =>
      'Ingresa el nombre del instructor';

  @override
  String get signatures_handoff_title => 'Entrega tu dispositivo a';

  @override
  String get signatures_instructorSignature => 'Firma del Instructor';

  @override
  String get signatures_noSignatureImage => 'Sin imagen de firma';

  @override
  String signatures_signHere(Object name) {
    return '$name - Firma Aquí';
  }

  @override
  String get signatures_signed => 'Firmado';

  @override
  String signatures_signedCountSemantics(Object signed, Object total) {
    return '$signed de $total compañeros han firmado';
  }

  @override
  String signatures_signedDate(Object date) {
    return 'Firmado $date';
  }

  @override
  String get signatures_title => 'Firmas';

  @override
  String get signatures_viewSignature => 'Ver firma';

  @override
  String signatures_viewSignatureSemantics(Object name) {
    return 'Ver firma de $name';
  }

  @override
  String get statistics_appBar_title => 'Estadisticas';

  @override
  String statistics_categoryCard_semanticLabel(Object title) {
    return 'Categoria de estadisticas: $title';
  }

  @override
  String get statistics_category_conditions_subtitle =>
      'Visibilidad y temperatura';

  @override
  String get statistics_category_conditions_title => 'Condiciones';

  @override
  String get statistics_category_equipment_subtitle => 'Uso de equipo y peso';

  @override
  String get statistics_category_equipment_title => 'Equipo';

  @override
  String get statistics_category_gas_subtitle => 'Tasas SAC y mezclas de gas';

  @override
  String get statistics_category_gas_title => 'Consumo de aire';

  @override
  String get statistics_category_geographic_subtitle => 'Paises y regiones';

  @override
  String get statistics_category_geographic_title => 'Geografico';

  @override
  String get statistics_category_marineLife_subtitle =>
      'Avistamientos de especies';

  @override
  String get statistics_category_marineLife_title => 'Vida marina';

  @override
  String get statistics_category_profile_subtitle => 'Tasas de ascenso y deco';

  @override
  String get statistics_category_profile_title => 'Analisis de perfil';

  @override
  String get statistics_category_progression_subtitle =>
      'Tendencias de profundidad y tiempo';

  @override
  String get statistics_category_progression_title => 'Progresion';

  @override
  String get statistics_category_social_subtitle =>
      'Companeros y centros de buceo';

  @override
  String get statistics_category_social_title => 'Social';

  @override
  String get statistics_category_timePatterns_subtitle => 'Cuando buceas';

  @override
  String get statistics_category_timePatterns_title => 'Patrones de tiempo';

  @override
  String statistics_chart_barSemanticLabel(Object count) {
    return 'Grafico de barras con $count categorias';
  }

  @override
  String statistics_chart_distributionSemanticLabel(Object count) {
    return 'Grafico circular de distribucion con $count segmentos';
  }

  @override
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames) {
    return 'Grafico de lineas multitendencia comparando $seriesNames';
  }

  @override
  String get statistics_chart_noBarData => 'No hay datos disponibles';

  @override
  String get statistics_chart_noDistributionData =>
      'No hay datos de distribucion disponibles';

  @override
  String get statistics_chart_noTrendData =>
      'No hay datos de tendencia disponibles';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return 'Grafico de lineas de tendencia mostrando $count puntos de datos';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return 'Grafico de lineas de tendencia mostrando $count puntos de datos para $yAxisLabel';
  }

  @override
  String get statistics_conditions_appBar_title => 'Condiciones';

  @override
  String get statistics_conditions_entryMethod_empty =>
      'No hay datos de metodo de entrada disponibles';

  @override
  String get statistics_conditions_entryMethod_error =>
      'Error al cargar los datos de metodo de entrada';

  @override
  String get statistics_conditions_entryMethod_subtitle => 'Costa, barco, etc.';

  @override
  String get statistics_conditions_entryMethod_title => 'Metodo de entrada';

  @override
  String get statistics_conditions_temperature_empty =>
      'No hay datos de temperatura disponibles';

  @override
  String get statistics_conditions_temperature_error =>
      'Error al cargar los datos de temperatura';

  @override
  String get statistics_conditions_temperature_seriesAvg => 'Prom';

  @override
  String get statistics_conditions_temperature_seriesMax => 'Max';

  @override
  String get statistics_conditions_temperature_seriesMin => 'Min';

  @override
  String get statistics_conditions_temperature_subtitle =>
      'Temperaturas min/prom/max';

  @override
  String get statistics_conditions_temperature_title =>
      'Temperatura del agua por mes';

  @override
  String get statistics_conditions_visibility_error =>
      'Error al cargar los datos de visibilidad';

  @override
  String get statistics_conditions_visibility_subtitle =>
      'Inmersiones por condicion de visibilidad';

  @override
  String get statistics_conditions_visibility_title =>
      'Distribucion de visibilidad';

  @override
  String get statistics_conditions_waterType_error =>
      'Error al cargar los datos de tipo de agua';

  @override
  String get statistics_conditions_waterType_subtitle =>
      'Inmersiones en agua salada vs dulce';

  @override
  String get statistics_conditions_waterType_title => 'Tipo de agua';

  @override
  String get statistics_equipment_appBar_title => 'Equipo';

  @override
  String get statistics_equipment_mostUsedGear_error =>
      'Error al cargar los datos de equipo';

  @override
  String get statistics_equipment_mostUsedGear_subtitle =>
      'Equipo por cantidad de inmersiones';

  @override
  String get statistics_equipment_mostUsedGear_title => 'Equipo mas utilizado';

  @override
  String get statistics_equipment_weightTrend_error =>
      'Error al cargar la tendencia de peso';

  @override
  String get statistics_equipment_weightTrend_subtitle =>
      'Peso promedio a lo largo del tiempo';

  @override
  String get statistics_equipment_weightTrend_title => 'Tendencia de peso';

  @override
  String get statistics_error_loadingStatistics =>
      'Error al cargar las estadisticas';

  @override
  String get statistics_gas_appBar_title => 'Consumo de aire';

  @override
  String get statistics_gas_gasMix_error =>
      'Error al cargar los datos de mezcla de gas';

  @override
  String get statistics_gas_gasMix_subtitle => 'Inmersiones por tipo de gas';

  @override
  String get statistics_gas_gasMix_title => 'Distribucion de mezcla de gas';

  @override
  String get statistics_gas_sacByRole_empty =>
      'No hay datos de multitanque disponibles';

  @override
  String get statistics_gas_sacByRole_error =>
      'Error al cargar SAC por funcion';

  @override
  String get statistics_gas_sacByRole_subtitle =>
      'Consumo promedio por tipo de tanque';

  @override
  String get statistics_gas_sacByRole_title => 'SAC por funcion del tanque';

  @override
  String get statistics_gas_sacRecords_best => 'Mejor tasa SAC';

  @override
  String get statistics_gas_sacRecords_empty =>
      'Aun no hay datos de SAC disponibles';

  @override
  String get statistics_gas_sacRecords_error =>
      'Error al cargar los records de SAC';

  @override
  String get statistics_gas_sacRecords_highest => 'Tasa SAC mas alta';

  @override
  String get statistics_gas_sacRecords_subtitle =>
      'Mejor y peor consumo de aire';

  @override
  String get statistics_gas_sacRecords_title => 'Records de tasa SAC';

  @override
  String get statistics_gas_sacTrend_error =>
      'Error al cargar la tendencia de SAC';

  @override
  String get statistics_gas_sacTrend_subtitle => 'Promedio mensual en 5 anos';

  @override
  String get statistics_gas_sacTrend_title => 'Tendencia de tasa SAC';

  @override
  String get statistics_gas_tankRole_backGas => 'Gas principal';

  @override
  String get statistics_gas_tankRole_bailout => 'Bailout';

  @override
  String get statistics_gas_tankRole_deco => 'Deco';

  @override
  String get statistics_gas_tankRole_diluent => 'Diluyente';

  @override
  String get statistics_gas_tankRole_oxygenSupply => 'Suministro de O₂';

  @override
  String get statistics_gas_tankRole_pony => 'Pony';

  @override
  String get statistics_gas_tankRole_sidemountLeft => 'Sidemount izq.';

  @override
  String get statistics_gas_tankRole_sidemountRight => 'Sidemount der.';

  @override
  String get statistics_gas_tankRole_stage => 'Stage';

  @override
  String get statistics_geographic_appBar_title => 'Geografico';

  @override
  String get statistics_geographic_countries_empty => 'No hay paises visitados';

  @override
  String get statistics_geographic_countries_error =>
      'Error al cargar los datos de paises';

  @override
  String get statistics_geographic_countries_subtitle => 'Inmersiones por pais';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count paises. Principal: $topName con $topCount inmersiones';
  }

  @override
  String get statistics_geographic_countries_title => 'Paises visitados';

  @override
  String get statistics_geographic_regions_empty =>
      'No hay regiones exploradas';

  @override
  String get statistics_geographic_regions_error =>
      'Error al cargar los datos de regiones';

  @override
  String get statistics_geographic_regions_subtitle => 'Inmersiones por region';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count regiones. Principal: $topName con $topCount inmersiones';
  }

  @override
  String get statistics_geographic_regions_title => 'Regiones exploradas';

  @override
  String get statistics_geographic_trips_empty => 'No hay datos de viajes';

  @override
  String get statistics_geographic_trips_error =>
      'Error al cargar los datos de viajes';

  @override
  String get statistics_geographic_trips_subtitle => 'Viajes mas productivos';

  @override
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count viajes. Principal: $topName con $topCount inmersiones';
  }

  @override
  String get statistics_geographic_trips_title => 'Inmersiones por viaje';

  @override
  String get statistics_listContent_selectedSuffix => ', seleccionado';

  @override
  String get statistics_marineLife_appBar_title => 'Vida marina';

  @override
  String get statistics_marineLife_bestSites_empty => 'No hay datos de sitios';

  @override
  String get statistics_marineLife_bestSites_error =>
      'Error al cargar los datos de sitios';

  @override
  String get statistics_marineLife_bestSites_subtitle =>
      'Sitios con mayor variedad de especies';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count sitios. Mejor: $topName con $topCount especies';
  }

  @override
  String get statistics_marineLife_bestSites_title =>
      'Mejores sitios para vida marina';

  @override
  String get statistics_marineLife_mostCommon_empty =>
      'No hay datos de avistamientos';

  @override
  String get statistics_marineLife_mostCommon_error =>
      'Error al cargar los datos de avistamientos';

  @override
  String get statistics_marineLife_mostCommon_subtitle =>
      'Especies avistadas con mayor frecuencia';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count especies. Mas comun: $topName con $topCount avistamientos';
  }

  @override
  String get statistics_marineLife_mostCommon_title =>
      'Avistamientos mas comunes';

  @override
  String get statistics_marineLife_speciesSpotted => 'Especies avistadas';

  @override
  String get statistics_profile_appBar_title => 'Analisis de perfil';

  @override
  String get statistics_profile_ascentDescent_empty =>
      'No hay datos de perfil disponibles';

  @override
  String get statistics_profile_ascentDescent_error =>
      'Error al cargar los datos de velocidad';

  @override
  String get statistics_profile_ascentDescent_subtitle =>
      'De los datos del perfil de inmersion';

  @override
  String get statistics_profile_ascentDescent_title =>
      'Velocidades promedio de ascenso y descenso';

  @override
  String get statistics_profile_avgAscent => 'Ascenso prom.';

  @override
  String get statistics_profile_avgDescent => 'Descenso prom.';

  @override
  String get statistics_profile_deco_decoDives => 'Inmersiones deco';

  @override
  String get statistics_profile_deco_decoLabel => 'Deco';

  @override
  String get statistics_profile_deco_decoRate => 'Tasa deco';

  @override
  String get statistics_profile_deco_empty =>
      'No hay datos de deco disponibles';

  @override
  String get statistics_profile_deco_error =>
      'Error al cargar los datos de deco';

  @override
  String get statistics_profile_deco_noDeco => 'Sin deco';

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return 'Tasa de descompresion: $percentage% de las inmersiones requirieron paradas de deco';
  }

  @override
  String get statistics_profile_deco_subtitle =>
      'Inmersiones que incurrieron en paradas de deco';

  @override
  String get statistics_profile_deco_title => 'Obligacion de descompresion';

  @override
  String get statistics_profile_timeAtDepth_empty =>
      'No hay datos de profundidad disponibles';

  @override
  String get statistics_profile_timeAtDepth_error =>
      'Error al cargar los datos de rango de profundidad';

  @override
  String get statistics_profile_timeAtDepth_subtitle =>
      'Tiempo aproximado en cada profundidad';

  @override
  String get statistics_profile_timeAtDepth_title =>
      'Tiempo en rangos de profundidad';

  @override
  String statistics_profile_timeAtDepth_valueFormat(Object value) {
    return '$value min';
  }

  @override
  String get statistics_progression_appBar_title => 'Progresion de buceo';

  @override
  String get statistics_progression_bottomTime_error =>
      'Error al cargar la tendencia de tiempo de fondo';

  @override
  String get statistics_progression_bottomTime_subtitle =>
      'Duracion promedio por mes';

  @override
  String get statistics_progression_bottomTime_title =>
      'Tendencia de tiempo de fondo';

  @override
  String get statistics_progression_cumulative_error =>
      'Error al cargar los datos acumulados';

  @override
  String get statistics_progression_cumulative_subtitle =>
      'Total de inmersiones a lo largo del tiempo';

  @override
  String get statistics_progression_cumulative_title =>
      'Conteo acumulado de inmersiones';

  @override
  String get statistics_progression_depthProgression_error =>
      'Error al cargar la progresion de profundidad';

  @override
  String get statistics_progression_depthProgression_subtitle =>
      'Profundidad maxima mensual en 5 anos';

  @override
  String get statistics_progression_depthProgression_title =>
      'Progresion de profundidad maxima';

  @override
  String get statistics_progression_divesPerYear_empty =>
      'No hay datos anuales disponibles';

  @override
  String get statistics_progression_divesPerYear_error =>
      'Error al cargar los datos anuales';

  @override
  String get statistics_progression_divesPerYear_subtitle =>
      'Comparacion anual de inmersiones';

  @override
  String get statistics_progression_divesPerYear_title => 'Inmersiones por ano';

  @override
  String get statistics_ranking_countLabel_dives => 'inmersiones';

  @override
  String get statistics_ranking_countLabel_sightings => 'avistamientos';

  @override
  String get statistics_ranking_countLabel_species => 'especies';

  @override
  String get statistics_ranking_emptyState => 'Aun no hay datos';

  @override
  String statistics_ranking_itemCount(Object count, Object label) {
    return '$count $label';
  }

  @override
  String statistics_ranking_moreItems(Object count) {
    return 'y $count mas';
  }

  @override
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  ) {
    return '$name, posicion $rank, $count $label';
  }

  @override
  String get statistics_records_appBar_title => 'Records de buceo';

  @override
  String get statistics_records_coldestDive => 'Inmersion mas fria';

  @override
  String get statistics_records_deepestDive => 'Inmersion mas profunda';

  @override
  String statistics_records_diveNumber(Object number) {
    return 'Inmersion #$number';
  }

  @override
  String get statistics_records_emptySubtitle =>
      'Comienza a registrar inmersiones para ver tus records aqui';

  @override
  String get statistics_records_emptyTitle => 'Aun no hay records';

  @override
  String get statistics_records_error => 'Error al cargar los records';

  @override
  String get statistics_records_firstDive => 'Primera inmersion';

  @override
  String get statistics_records_longestDive => 'Inmersion mas larga';

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
  String get statistics_records_milestones => 'Hitos';

  @override
  String get statistics_records_mostRecentDive => 'Inmersion mas reciente';

  @override
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  ) {
    return '$title: $value en $siteName';
  }

  @override
  String get statistics_records_retry => 'Reintentar';

  @override
  String get statistics_records_shallowestDive => 'Inmersion menos profunda';

  @override
  String get statistics_records_unknownSite => 'Sitio desconocido';

  @override
  String get statistics_records_warmestDive => 'Inmersion mas calida';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return 'Seccion $title';
  }

  @override
  String get statistics_social_appBar_title => 'Social y companeros';

  @override
  String get statistics_social_soloVsBuddy_empty =>
      'No hay datos de inmersiones disponibles';

  @override
  String get statistics_social_soloVsBuddy_error =>
      'Error al cargar los datos de companeros';

  @override
  String get statistics_social_soloVsBuddy_solo => 'Solo';

  @override
  String get statistics_social_soloVsBuddy_subtitle =>
      'Buceo con o sin companeros';

  @override
  String get statistics_social_soloVsBuddy_title =>
      'Inmersiones en solitario vs con companero';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => 'Con companero';

  @override
  String get statistics_social_topBuddies_error =>
      'Error al cargar el ranking de companeros';

  @override
  String get statistics_social_topBuddies_subtitle =>
      'Companeros de buceo mas frecuentes';

  @override
  String get statistics_social_topBuddies_title =>
      'Principales companeros de buceo';

  @override
  String get statistics_social_topDiveCenters_error =>
      'Error al cargar el ranking de centros de buceo';

  @override
  String get statistics_social_topDiveCenters_subtitle =>
      'Operadores mas visitados';

  @override
  String get statistics_social_topDiveCenters_title =>
      'Principales centros de buceo';

  @override
  String get statistics_summary_avgDepth => 'Prof. promedio';

  @override
  String get statistics_summary_avgTemp => 'Temp. promedio';

  @override
  String get statistics_summary_depthDistribution_empty =>
      'El grafico aparecera cuando registres inmersiones';

  @override
  String get statistics_summary_depthDistribution_semanticLabel =>
      'Grafico circular mostrando la distribucion de profundidad';

  @override
  String get statistics_summary_depthDistribution_title =>
      'Distribucion de profundidad';

  @override
  String get statistics_summary_diveTypes_empty =>
      'El grafico aparecera cuando registres inmersiones';

  @override
  String statistics_summary_diveTypes_moreTypes(Object count) {
    return 'y $count tipos mas';
  }

  @override
  String get statistics_summary_diveTypes_semanticLabel =>
      'Grafico circular mostrando la distribucion de tipos de inmersion';

  @override
  String get statistics_summary_diveTypes_title => 'Tipos de inmersion';

  @override
  String get statistics_summary_divesByMonth_empty =>
      'El grafico aparecera cuando registres inmersiones';

  @override
  String get statistics_summary_divesByMonth_semanticLabel =>
      'Grafico de barras mostrando inmersiones por mes';

  @override
  String get statistics_summary_divesByMonth_title => 'Inmersiones por mes';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel\n$count inmersiones';
  }

  @override
  String get statistics_summary_header_subtitle =>
      'Selecciona una categoria para explorar estadisticas detalladas';

  @override
  String get statistics_summary_header_title => 'Resumen de estadisticas';

  @override
  String get statistics_summary_maxDepth => 'Prof. maxima';

  @override
  String get statistics_summary_sitesVisited => 'Sitios visitados';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones',
      one: '1 inmersion',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty =>
      'Aun no hay etiquetas creadas';

  @override
  String get statistics_summary_tagUsage_emptyHint =>
      'Agrega etiquetas a las inmersiones para ver estadisticas';

  @override
  String statistics_summary_tagUsage_moreTags(Object count) {
    return 'y $count etiquetas mas';
  }

  @override
  String statistics_summary_tagUsage_tagCount(Object count) {
    return '$count etiquetas';
  }

  @override
  String get statistics_summary_tagUsage_title => 'Uso de etiquetas';

  @override
  String statistics_summary_topDiveSites_diveCount(Object count) {
    return '$count inmersiones';
  }

  @override
  String get statistics_summary_topDiveSites_empty =>
      'Aun no hay puntos de buceo';

  @override
  String get statistics_summary_topDiveSites_title =>
      'Principales puntos de buceo';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count en total';
  }

  @override
  String get statistics_summary_totalDives => 'Total de inmersiones';

  @override
  String get statistics_summary_totalTime => 'Tiempo total';

  @override
  String get statistics_timePatterns_appBar_title => 'Patrones de tiempo';

  @override
  String get statistics_timePatterns_dayOfWeek_empty =>
      'No hay datos disponibles';

  @override
  String get statistics_timePatterns_dayOfWeek_error =>
      'Error al cargar los datos por dia de la semana';

  @override
  String get statistics_timePatterns_dayOfWeek_fri => 'Vie';

  @override
  String get statistics_timePatterns_dayOfWeek_mon => 'Lun';

  @override
  String get statistics_timePatterns_dayOfWeek_sat => 'Sab';

  @override
  String get statistics_timePatterns_dayOfWeek_subtitle => 'Cuando buceas mas?';

  @override
  String get statistics_timePatterns_dayOfWeek_sun => 'Dom';

  @override
  String get statistics_timePatterns_dayOfWeek_thu => 'Jue';

  @override
  String get statistics_timePatterns_dayOfWeek_title =>
      'Inmersiones por dia de la semana';

  @override
  String get statistics_timePatterns_dayOfWeek_tue => 'Mar';

  @override
  String get statistics_timePatterns_dayOfWeek_wed => 'Mie';

  @override
  String get statistics_timePatterns_month_apr => 'Abr';

  @override
  String get statistics_timePatterns_month_aug => 'Ago';

  @override
  String get statistics_timePatterns_month_dec => 'Dic';

  @override
  String get statistics_timePatterns_month_feb => 'Feb';

  @override
  String get statistics_timePatterns_month_jan => 'Ene';

  @override
  String get statistics_timePatterns_month_jul => 'Jul';

  @override
  String get statistics_timePatterns_month_jun => 'Jun';

  @override
  String get statistics_timePatterns_month_mar => 'Mar';

  @override
  String get statistics_timePatterns_month_may => 'May';

  @override
  String get statistics_timePatterns_month_nov => 'Nov';

  @override
  String get statistics_timePatterns_month_oct => 'Oct';

  @override
  String get statistics_timePatterns_month_sep => 'Sep';

  @override
  String get statistics_timePatterns_seasonal_empty =>
      'No hay datos disponibles';

  @override
  String get statistics_timePatterns_seasonal_error =>
      'Error al cargar los datos estacionales';

  @override
  String get statistics_timePatterns_seasonal_subtitle =>
      'Inmersiones por mes (todos los anos)';

  @override
  String get statistics_timePatterns_seasonal_title => 'Patrones estacionales';

  @override
  String get statistics_timePatterns_surfaceInterval_average => 'Promedio';

  @override
  String get statistics_timePatterns_surfaceInterval_empty =>
      'No hay datos de intervalo de superficie disponibles';

  @override
  String get statistics_timePatterns_surfaceInterval_error =>
      'Error al cargar los datos de intervalo de superficie';

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
  String get statistics_timePatterns_surfaceInterval_maximum => 'Maximo';

  @override
  String get statistics_timePatterns_surfaceInterval_minimum => 'Minimo';

  @override
  String get statistics_timePatterns_surfaceInterval_subtitle =>
      'Tiempo entre inmersiones';

  @override
  String get statistics_timePatterns_surfaceInterval_title =>
      'Estadisticas de intervalo de superficie';

  @override
  String get statistics_timePatterns_timeOfDay_error =>
      'Error al cargar los datos por hora del dia';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle =>
      'Manana, tarde, atardecer o noche';

  @override
  String get statistics_timePatterns_timeOfDay_title =>
      'Inmersiones por hora del dia';

  @override
  String get statistics_tooltip_diveRecords => 'Records de buceo';

  @override
  String get statistics_tooltip_refreshRecords => 'Actualizar records';

  @override
  String get statistics_tooltip_refreshStatistics => 'Actualizar estadisticas';

  @override
  String statistics_valueCard_semanticLabel(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String get surfaceInterval_aboutTissueLoading_body =>
      'Tu cuerpo tiene 16 compartimentos de tejido que absorben y liberan nitrógeno a diferentes velocidades. Los tejidos rápidos (como la sangre) se saturan rápidamente pero también desgasifican rápidamente. Los tejidos lentos (como hueso y grasa) tardan más en cargarse y descargarse. El \"compartimento líder\" es el tejido más saturado y típicamente controla tu límite de no descompresión (NDL). Durante un intervalo de superficie, todos los tejidos desgasifican hacia niveles de saturación de superficie (~40% de carga).';

  @override
  String get surfaceInterval_aboutTissueLoading_title =>
      'Acerca de la Carga de Tejidos';

  @override
  String get surfaceInterval_action_resetDefaults =>
      'Restablecer valores predeterminados';

  @override
  String get surfaceInterval_disclaimer =>
      'Esta herramienta es solo para fines de planificación. Siempre usa una computadora de buceo y sigue tu entrenamiento. Los resultados se basan en el algoritmo Buhlmann ZH-L16C y pueden diferir de tu computadora.';

  @override
  String get surfaceInterval_field_depth => 'Profundidad';

  @override
  String get surfaceInterval_field_gasMix => 'Mezcla de Gas: ';

  @override
  String get surfaceInterval_field_he => 'He';

  @override
  String get surfaceInterval_field_o2 => 'O₂';

  @override
  String get surfaceInterval_field_time => 'Tiempo';

  @override
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit) {
    return 'Profundidad primera inmersión: $depth $unit';
  }

  @override
  String surfaceInterval_firstDive_timeSemantics(Object time) {
    return 'Tiempo primera inmersión: $time minutos';
  }

  @override
  String get surfaceInterval_firstDive_title => 'Primera Inmersión';

  @override
  String surfaceInterval_format_hours(Object count) {
    return '$count horas';
  }

  @override
  String surfaceInterval_format_minutes(Object count) {
    return '$count min';
  }

  @override
  String get surfaceInterval_gasMix_air => 'Aire';

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
    return 'Helio: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Intervalo Actual';

  @override
  String get surfaceInterval_result_inDeco => 'En deco';

  @override
  String get surfaceInterval_result_increaseInterval =>
      'Aumenta el intervalo de superficie o reduce profundidad/tiempo de segunda inmersión';

  @override
  String get surfaceInterval_result_minimumInterval =>
      'Intervalo de Superficie Mínimo';

  @override
  String get surfaceInterval_result_ndlForSecondDive =>
      'NDL para 2da Inmersión';

  @override
  String surfaceInterval_result_ndlMinutes(Object minutes) {
    return '$minutes min NDL';
  }

  @override
  String get surfaceInterval_result_notYetSafe =>
      'Aún no es seguro, aumenta el intervalo de superficie';

  @override
  String get surfaceInterval_result_safeToDive => 'Seguro para bucear';

  @override
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  ) {
    return 'Intervalo de superficie mínimo: $interval. Intervalo actual: $current. NDL para segunda inmersión: $ndl. $status';
  }

  @override
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit) {
    return 'Profundidad segunda inmersión: $depth $unit';
  }

  @override
  String get surfaceInterval_secondDive_gasAir => '(Aire)';

  @override
  String surfaceInterval_secondDive_timeSemantics(Object time) {
    return 'Tiempo segunda inmersión: $time minutos';
  }

  @override
  String get surfaceInterval_secondDive_title => 'Segunda Inmersión';

  @override
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval) {
    return 'Gráfico de recuperación de tejidos mostrando desgasificación de 16 compartimentos durante un intervalo de superficie de $interval';
  }

  @override
  String get surfaceInterval_tissueRecovery_compartmentsLabel =>
      'Compartimentos (por velocidad de tiempo medio)';

  @override
  String get surfaceInterval_tissueRecovery_description =>
      'Mostrando cómo cada uno de los 16 compartimentos de tejido desgasifica durante el intervalo de superficie';

  @override
  String get surfaceInterval_tissueRecovery_fast => 'Rápidos (C1-5)';

  @override
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number) {
    return 'Compartimento líder: C$number';
  }

  @override
  String get surfaceInterval_tissueRecovery_loadingPercent => '% Carga';

  @override
  String get surfaceInterval_tissueRecovery_medium => 'Medios (C6-10)';

  @override
  String get surfaceInterval_tissueRecovery_min => 'Mín';

  @override
  String get surfaceInterval_tissueRecovery_now => 'Ahora';

  @override
  String get surfaceInterval_tissueRecovery_slow => 'Lentos (C11-16)';

  @override
  String get surfaceInterval_tissueRecovery_title => 'Recuperación de Tejidos';

  @override
  String get surfaceInterval_title => 'Intervalo de Superficie';

  @override
  String tags_action_createNamed(Object tagName) {
    return 'Crear \"$tagName\"';
  }

  @override
  String get tags_action_createTag => 'Crear etiqueta';

  @override
  String get tags_action_deleteTag => 'Eliminar etiqueta';

  @override
  String tags_dialog_deleteMessage(Object tagName) {
    return '¿Estás seguro de que deseas eliminar \"$tagName\"? Esto la eliminará de todas las inmersiones.';
  }

  @override
  String get tags_dialog_deleteTitle => '¿Eliminar Etiqueta?';

  @override
  String get tags_empty =>
      'Aún no hay etiquetas. Crea etiquetas al editar inmersiones.';

  @override
  String get tags_hint_addMoreTags => 'Agregar más etiquetas...';

  @override
  String get tags_hint_addTags => 'Agregar etiquetas...';

  @override
  String get tags_title_manageTags => 'Administrar Etiquetas';

  @override
  String get tank_al30Stage_description =>
      'Tanque stage de aluminio de 30 cu ft';

  @override
  String get tank_al30Stage_displayName => 'AL30 Stage';

  @override
  String get tank_al40Stage_description =>
      'Tanque stage de aluminio de 40 cu ft';

  @override
  String get tank_al40Stage_displayName => 'AL40 Stage';

  @override
  String get tank_al40_description => 'Aluminio 40 cu ft (pony)';

  @override
  String get tank_al40_displayName => 'AL40';

  @override
  String get tank_al63_description => 'Aluminio 63 cu ft';

  @override
  String get tank_al63_displayName => 'AL63';

  @override
  String get tank_al80_description => 'Aluminio 80 cu ft (más común)';

  @override
  String get tank_al80_displayName => 'AL80';

  @override
  String get tank_hp100_description => 'Acero alta presión 100 cu ft';

  @override
  String get tank_hp100_displayName => 'HP100';

  @override
  String get tank_hp120_description => 'Acero alta presión 120 cu ft';

  @override
  String get tank_hp120_displayName => 'HP120';

  @override
  String get tank_hp80_description => 'Acero alta presión 80 cu ft';

  @override
  String get tank_hp80_displayName => 'HP80';

  @override
  String get tank_lp85_description => 'Acero baja presión 85 cu ft';

  @override
  String get tank_lp85_displayName => 'LP85';

  @override
  String get tank_steel10_description => 'Acero 10 litros (Europa)';

  @override
  String get tank_steel10_displayName => 'Steel 10L';

  @override
  String get tank_steel12_description => 'Acero 12 litros (Europa)';

  @override
  String get tank_steel12_displayName => 'Steel 12L';

  @override
  String get tank_steel15_description => 'Acero 15 litros (Europa)';

  @override
  String get tank_steel15_displayName => 'Steel 15L';

  @override
  String get tides_action_refresh => 'Actualizar datos de mareas';

  @override
  String get tides_chart_24hourForecast => 'Pronóstico de 24 Horas';

  @override
  String tides_chart_heightAxis(Object depthSymbol) {
    return 'Altura ($depthSymbol)';
  }

  @override
  String get tides_chart_msl => 'MSL';

  @override
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr) {
    return ' Ahora $nowTimeStr $nowHeightStr';
  }

  @override
  String get tides_error_unableToLoad =>
      'No se pueden cargar los datos de mareas';

  @override
  String get tides_error_unableToLoadChart => 'No se puede cargar el gráfico';

  @override
  String tides_label_ago(Object duration) {
    return 'hace $duration';
  }

  @override
  String tides_label_currentHeight(Object height, Object depthSymbol) {
    return 'Actual: $height$depthSymbol';
  }

  @override
  String tides_label_fromNow(Object duration) {
    return 'dentro de $duration';
  }

  @override
  String get tides_label_high => 'Alta';

  @override
  String get tides_label_highIn => 'Alta en';

  @override
  String get tides_label_highTide => 'Marea Alta';

  @override
  String get tides_label_low => 'Baja';

  @override
  String get tides_label_lowIn => 'Baja en';

  @override
  String get tides_label_lowTide => 'Marea Baja';

  @override
  String tides_label_tideIn(Object duration) {
    return 'en $duration';
  }

  @override
  String get tides_label_tideTimes => 'Horarios de Mareas';

  @override
  String get tides_label_today => 'Hoy';

  @override
  String get tides_label_tomorrow => 'Mañana';

  @override
  String get tides_label_upcomingTides => 'Próximas Mareas';

  @override
  String get tides_legend_highTide => 'Marea Alta';

  @override
  String get tides_legend_lowTide => 'Marea Baja';

  @override
  String get tides_legend_now => 'Ahora';

  @override
  String get tides_legend_tideLevel => 'Nivel de Marea';

  @override
  String get tides_noDataAvailable => 'No hay datos de mareas disponibles';

  @override
  String get tides_noDataForLocation =>
      'Datos de mareas no disponibles para esta ubicación';

  @override
  String get tides_noExtremesData => 'Sin datos de extremos';

  @override
  String get tides_noTideTimesAvailable =>
      'No hay horarios de mareas disponibles';

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
    return 'Marea $typeLabel a las $time, $height$depthSymbol';
  }

  @override
  String tides_semantic_tideChart(Object extremesSummary) {
    return 'Gráfico de mareas. $extremesSummary';
  }

  @override
  String tides_semantic_tideState(Object state) {
    return 'Estado de marea: $state';
  }

  @override
  String get tides_title => 'Mareas';

  @override
  String get transfer_appBar_title => 'Transferir';

  @override
  String get transfer_computers_aboutContent =>
      'Conecta tu computadora de buceo por Bluetooth para descargar registros de buceo directamente a la aplicacion. Las computadoras compatibles incluyen Suunto, Shearwater, Garmin, Mares y muchas otras marcas populares.\n\nLos usuarios de Apple Watch Ultra pueden importar datos de buceo directamente desde la app Salud, incluyendo profundidad, duracion y frecuencia cardiaca.';

  @override
  String get transfer_computers_aboutTitle =>
      'Acerca de las computadoras de buceo';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple Watch';

  @override
  String get transfer_computers_appleWatchSubtitle =>
      'Importar inmersiones grabadas en Apple Watch Ultra';

  @override
  String get transfer_computers_appleWatchTitle => 'Importar desde Apple Watch';

  @override
  String get transfer_computers_connectSubtitle =>
      'Descubrir y emparejar una computadora de buceo';

  @override
  String get transfer_computers_connectTitle => 'Conectar nueva computadora';

  @override
  String get transfer_computers_errorLoading => 'Error al cargar computadoras';

  @override
  String get transfer_computers_loading => 'Cargando...';

  @override
  String get transfer_computers_manageTitle => 'Administrar computadoras';

  @override
  String get transfer_computers_noComputersSaved =>
      'No hay computadoras guardadas';

  @override
  String transfer_computers_savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'computadoras guardadas',
      one: 'computadora guardada',
    );
    return '$count $_temp0';
  }

  @override
  String get transfer_computers_sectionHeader => 'Computadoras de buceo';

  @override
  String get transfer_csvExport_cancelButton => 'Cancelar';

  @override
  String get transfer_csvExport_dataTypeHeader => 'Tipo de datos';

  @override
  String get transfer_csvExport_descriptionDives =>
      'Exportar todos los registros de buceo como hoja de calculo';

  @override
  String get transfer_csvExport_descriptionEquipment =>
      'Exportar inventario de equipos e informacion de servicio';

  @override
  String get transfer_csvExport_descriptionSites =>
      'Exportar ubicaciones y detalles de puntos de buceo';

  @override
  String get transfer_csvExport_dialogTitle => 'Exportar CSV';

  @override
  String get transfer_csvExport_exportButton => 'Exportar CSV';

  @override
  String get transfer_csvExport_optionDivesTitle => 'CSV de inmersiones';

  @override
  String get transfer_csvExport_optionEquipmentTitle => 'CSV de equipos';

  @override
  String get transfer_csvExport_optionSitesTitle => 'CSV de puntos';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return 'Exportar $typeName';
  }

  @override
  String get transfer_csvExport_typeDives => 'Inmersiones';

  @override
  String get transfer_csvExport_typeEquipment => 'Equipos';

  @override
  String get transfer_csvExport_typeSites => 'Puntos';

  @override
  String get transfer_detail_backTooltip => 'Volver a transferir';

  @override
  String get transfer_export_aboutContent =>
      'Exporta tus datos de buceo en varios formatos. PDF crea un libro de registro imprimible. UDDF es un formato universal compatible con la mayoria del software de registro de buceo. Los archivos CSV se pueden abrir en aplicaciones de hojas de calculo.';

  @override
  String get transfer_export_aboutTitle => 'Acerca de la exportacion';

  @override
  String get transfer_export_completed => 'Exportacion completada';

  @override
  String get transfer_export_csvSubtitle => 'Formato de hoja de calculo';

  @override
  String get transfer_export_csvTitle => 'Exportar CSV';

  @override
  String get transfer_export_excelSubtitle =>
      'Todos los datos en un archivo (inmersiones, puntos, equipos, estadisticas)';

  @override
  String get transfer_export_excelTitle => 'Libro de Excel';

  @override
  String transfer_export_failed(Object error) {
    return 'Error en la exportacion: $error';
  }

  @override
  String get transfer_export_kmlSubtitle =>
      'Ver puntos de buceo en un globo 3D';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => 'Exportacion multiformato';

  @override
  String get transfer_export_optionSaveSubtitle =>
      'Elige donde guardar en tu dispositivo';

  @override
  String get transfer_export_optionSaveTitle => 'Guardar en archivo';

  @override
  String get transfer_export_optionShareSubtitle =>
      'Enviar por correo, mensajes u otras aplicaciones';

  @override
  String get transfer_export_optionShareTitle => 'Compartir';

  @override
  String get transfer_export_pdfSubtitle =>
      'Libro de registro de buceo imprimible';

  @override
  String get transfer_export_pdfTitle => 'Libro de registro PDF';

  @override
  String get transfer_export_progressExporting => 'Exportando...';

  @override
  String get transfer_export_sectionHeader => 'Exportar datos';

  @override
  String get transfer_export_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_export_uddfTitle => 'Exportar UDDF';

  @override
  String get transfer_import_aboutContent =>
      'Usa \"Importar datos\" para la mejor experiencia: detecta automaticamente el formato de archivo y la aplicacion de origen. Las opciones de formato individuales a continuacion tambien estan disponibles para acceso directo.';

  @override
  String get transfer_import_aboutTitle => 'Acerca de la importacion';

  @override
  String get transfer_import_autoDetectSemanticLabel =>
      'Importar datos con deteccion automatica';

  @override
  String get transfer_import_autoDetectSubtitle =>
      'Detecta automaticamente CSV, UDDF, FIT y mas';

  @override
  String get transfer_import_autoDetectTitle => 'Importar datos';

  @override
  String get transfer_import_byFormatHeader => 'Importar por formato';

  @override
  String get transfer_import_csvSubtitle =>
      'Importar inmersiones desde archivo CSV';

  @override
  String get transfer_import_csvTitle => 'Importar desde CSV';

  @override
  String get transfer_import_fitSubtitle =>
      'Importar inmersiones desde archivos de exportacion Garmin Descent';

  @override
  String get transfer_import_fitTitle => 'Importar desde archivo FIT';

  @override
  String get transfer_import_operationCompleted => 'Operacion completada';

  @override
  String transfer_import_operationFailed(Object error) {
    return 'La operacion fallo: $error';
  }

  @override
  String get transfer_import_sectionHeader => 'Importar datos';

  @override
  String get transfer_import_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_import_uddfTitle => 'Importar desde UDDF';

  @override
  String get transfer_pdfExport_cancelButton => 'Cancelar';

  @override
  String get transfer_pdfExport_dialogTitle => 'Exportar libro de registro PDF';

  @override
  String get transfer_pdfExport_exportButton => 'Exportar PDF';

  @override
  String get transfer_pdfExport_includeCertCards =>
      'Incluir tarjetas de certificacion';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle =>
      'Agregar imagenes escaneadas de tarjetas de certificacion al PDF';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => 'Tamano de pagina';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Carta';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => 'Detallado';

  @override
  String get transfer_pdfExport_templateDetailedDesc =>
      'Informacion completa de la inmersion con notas y valoraciones';

  @override
  String get transfer_pdfExport_templateHeader => 'Plantilla';

  @override
  String get transfer_pdfExport_templateNauiStyle => 'Estilo NAUI';

  @override
  String get transfer_pdfExport_templateNauiStyleDesc =>
      'Diseno que coincide con el formato del libro de registro NAUI';

  @override
  String get transfer_pdfExport_templatePadiStyle => 'Estilo PADI';

  @override
  String get transfer_pdfExport_templatePadiStyleDesc =>
      'Diseno que coincide con el formato del libro de registro PADI';

  @override
  String get transfer_pdfExport_templateProfessional => 'Profesional';

  @override
  String get transfer_pdfExport_templateProfessionalDesc =>
      'Areas de firma y sello para verificacion';

  @override
  String transfer_pdfExport_templateSemanticLabel(Object templateName) {
    return 'Seleccionar plantilla $templateName';
  }

  @override
  String get transfer_pdfExport_templateSimple => 'Simple';

  @override
  String get transfer_pdfExport_templateSimpleDesc =>
      'Formato de tabla compacto, muchas inmersiones por pagina';

  @override
  String get transfer_section_computersSubtitle =>
      'Descargar desde dispositivo';

  @override
  String get transfer_section_computersTitle => 'Computadoras de buceo';

  @override
  String get transfer_section_exportSubtitle =>
      'CSV, UDDF, libro de registro PDF';

  @override
  String get transfer_section_exportTitle => 'Exportar';

  @override
  String get transfer_section_importSubtitle => 'Archivos CSV, UDDF';

  @override
  String get transfer_section_importTitle => 'Importar';

  @override
  String get transfer_summary_description =>
      'Importar y exportar datos de buceo';

  @override
  String get transfer_summary_selectSection =>
      'Selecciona una seccion de la lista';

  @override
  String get transfer_summary_title => 'Transferir';

  @override
  String transfer_unknownSection(Object sectionId) {
    return 'Seccion desconocida: $sectionId';
  }

  @override
  String get trips_appBar_title => 'Viajes';

  @override
  String get trips_appBar_tripPhotos => 'Fotos del viaje';

  @override
  String get trips_detail_action_delete => 'Eliminar';

  @override
  String get trips_detail_action_export => 'Exportar';

  @override
  String get trips_detail_appBar_title => 'Viaje';

  @override
  String get trips_detail_dialog_cancel => 'Cancelar';

  @override
  String get trips_detail_dialog_deleteConfirm => 'Eliminar';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return 'Estas seguro de que deseas eliminar \"$name\"? Se eliminara el viaje pero se conservaran las inmersiones.';
  }

  @override
  String get trips_detail_dialog_deleteTitle => 'Eliminar viaje?';

  @override
  String get trips_detail_dives_empty => 'No hay inmersiones en este viaje aun';

  @override
  String get trips_detail_dives_errorLoading =>
      'No se pudieron cargar las inmersiones';

  @override
  String get trips_detail_dives_unknownSite => 'Punto desconocido';

  @override
  String trips_detail_dives_viewAll(Object count) {
    return 'Ver todas ($count)';
  }

  @override
  String trips_detail_durationDays(Object days) {
    return '$days dias';
  }

  @override
  String get trips_detail_export_csv_comingSoon =>
      'Exportacion CSV disponible proximamente';

  @override
  String get trips_detail_export_csv_subtitle =>
      'Todas las inmersiones de este viaje';

  @override
  String get trips_detail_export_csv_title => 'Exportar a CSV';

  @override
  String get trips_detail_export_pdf_comingSoon =>
      'Exportacion PDF disponible proximamente';

  @override
  String get trips_detail_export_pdf_subtitle =>
      'Resumen del viaje con detalles de las inmersiones';

  @override
  String get trips_detail_export_pdf_title => 'Exportar a PDF';

  @override
  String get trips_detail_label_liveaboard => 'Vida a bordo';

  @override
  String get trips_detail_label_location => 'Ubicacion';

  @override
  String get trips_detail_label_resort => 'Resort';

  @override
  String get trips_detail_scan_accessDenied =>
      'Acceso a la biblioteca de fotos denegado';

  @override
  String get trips_detail_scan_addDivesFirst =>
      'Agrega inmersiones primero para vincular fotos';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return 'Error al vincular fotos: $error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return 'Error al escanear: $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return 'Se vincularon $count fotos';
  }

  @override
  String get trips_detail_scan_linkingPhotos => 'Vinculando fotos...';

  @override
  String get trips_detail_sectionTitle_details => 'Detalles del viaje';

  @override
  String get trips_detail_sectionTitle_dives => 'Inmersiones';

  @override
  String get trips_detail_sectionTitle_notes => 'Notas';

  @override
  String get trips_detail_sectionTitle_statistics => 'Estadisticas del viaje';

  @override
  String get trips_detail_snackBar_deleted => 'Viaje eliminado';

  @override
  String get trips_detail_stat_avgDepth => 'Prof. media';

  @override
  String get trips_detail_stat_maxDepth => 'Prof. max.';

  @override
  String get trips_detail_stat_totalBottomTime => 'Tiempo de fondo total';

  @override
  String get trips_detail_stat_totalDives => 'Total de inmersiones';

  @override
  String get trips_detail_tooltip_edit => 'Editar viaje';

  @override
  String get trips_detail_tooltip_editShort => 'Editar';

  @override
  String get trips_detail_tooltip_moreOptions => 'Mas opciones';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Ver en el mapa';

  @override
  String get trips_edit_appBar_add => 'Agregar viaje';

  @override
  String get trips_edit_appBar_edit => 'Editar viaje';

  @override
  String get trips_edit_button_add => 'Agregar viaje';

  @override
  String get trips_edit_button_cancel => 'Cancelar';

  @override
  String get trips_edit_button_save => 'Guardar';

  @override
  String get trips_edit_button_update => 'Actualizar viaje';

  @override
  String get trips_edit_dialog_discard => 'Descartar';

  @override
  String get trips_edit_dialog_discardContent =>
      'Tienes cambios sin guardar. Estas seguro de que deseas salir?';

  @override
  String get trips_edit_dialog_discardTitle => 'Descartar cambios?';

  @override
  String get trips_edit_dialog_keepEditing => 'Seguir editando';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days dias';
  }

  @override
  String get trips_edit_hint_liveaboardName => 'ej., MY Blue Force One';

  @override
  String get trips_edit_hint_location => 'ej., Egipto, Mar Rojo';

  @override
  String get trips_edit_hint_notes =>
      'Cualquier nota adicional sobre este viaje';

  @override
  String get trips_edit_hint_resortName => 'ej., Marsa Shagra';

  @override
  String get trips_edit_hint_tripName => 'ej., Safari Mar Rojo 2024';

  @override
  String get trips_edit_label_endDate => 'Fecha de fin';

  @override
  String get trips_edit_label_liveaboardName => 'Nombre del vida a bordo';

  @override
  String get trips_edit_label_location => 'Ubicacion';

  @override
  String get trips_edit_label_notes => 'Notas';

  @override
  String get trips_edit_label_resortName => 'Nombre del resort';

  @override
  String get trips_edit_label_startDate => 'Fecha de inicio';

  @override
  String get trips_edit_label_tripName => 'Nombre del viaje *';

  @override
  String get trips_edit_sectionTitle_dates => 'Fechas del viaje';

  @override
  String get trips_edit_sectionTitle_location => 'Ubicacion';

  @override
  String get trips_edit_sectionTitle_notes => 'Notas';

  @override
  String get trips_edit_semanticLabel_save => 'Guardar viaje';

  @override
  String get trips_edit_snackBar_added => 'Viaje agregado correctamente';

  @override
  String trips_edit_snackBar_errorLoading(Object error) {
    return 'Error al cargar el viaje: $error';
  }

  @override
  String trips_edit_snackBar_errorSaving(Object error) {
    return 'Error al guardar el viaje: $error';
  }

  @override
  String get trips_edit_snackBar_updated => 'Viaje actualizado correctamente';

  @override
  String get trips_edit_validation_nameRequired =>
      'Por favor, introduce un nombre de viaje';

  @override
  String get trips_gallery_accessDenied =>
      'Acceso a la biblioteca de fotos denegado';

  @override
  String get trips_gallery_addDivesFirst =>
      'Agrega inmersiones primero para vincular fotos';

  @override
  String get trips_gallery_appBar_title => 'Fotos del viaje';

  @override
  String trips_gallery_diveSection_photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fotos',
      one: 'foto',
    );
    return '$_temp0';
  }

  @override
  String trips_gallery_diveSection_title(Object number, Object site) {
    return 'Inmersion #$number - $site';
  }

  @override
  String get trips_gallery_empty_subtitle =>
      'Toca el icono de camara para escanear tu galeria';

  @override
  String get trips_gallery_empty_title => 'No hay fotos en este viaje';

  @override
  String trips_gallery_errorLinking(Object error) {
    return 'Error al vincular fotos: $error';
  }

  @override
  String trips_gallery_errorScanning(Object error) {
    return 'Error al escanear: $error';
  }

  @override
  String trips_gallery_error_loading(Object error) {
    return 'Error al cargar fotos: $error';
  }

  @override
  String trips_gallery_linkedPhotos(Object count) {
    return 'Se vincularon $count fotos';
  }

  @override
  String get trips_gallery_linkingPhotos => 'Vinculando fotos...';

  @override
  String get trips_gallery_tooltip_scan => 'Escanear galeria del dispositivo';

  @override
  String get trips_gallery_tripNotFound => 'Viaje no encontrado';

  @override
  String get trips_list_button_retry => 'Reintentar';

  @override
  String get trips_list_empty_button => 'Agrega tu primer viaje';

  @override
  String get trips_list_empty_filtered_subtitle =>
      'Intenta ajustar o borrar tus filtros';

  @override
  String get trips_list_empty_filtered_title =>
      'Ningun viaje coincide con tus filtros';

  @override
  String get trips_list_empty_subtitle =>
      'Crea viajes para agrupar tus inmersiones por destino';

  @override
  String get trips_list_empty_title => 'No se han agregado viajes';

  @override
  String trips_list_error_loading(Object error) {
    return 'Error al cargar viajes: $error';
  }

  @override
  String get trips_list_fab_addTrip => 'Agregar viaje';

  @override
  String get trips_list_filters_clearAll => 'Borrar todos';

  @override
  String get trips_list_sort_title => 'Ordenar viajes';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count inmersiones';
  }

  @override
  String get trips_list_tooltip_addTrip => 'Agregar viaje';

  @override
  String get trips_list_tooltip_search => 'Buscar viajes';

  @override
  String get trips_list_tooltip_sort => 'Ordenar';

  @override
  String get trips_photos_empty_scanButton =>
      'Escanear galeria del dispositivo';

  @override
  String get trips_photos_empty_title => 'No hay fotos aun';

  @override
  String get trips_photos_error_loading => 'Error al cargar fotos';

  @override
  String trips_photos_moreIndicator(Object count) {
    return '+$count';
  }

  @override
  String trips_photos_moreIndicator_semanticLabel(Object count) {
    return '$count fotos mas';
  }

  @override
  String get trips_photos_sectionTitle => 'Fotos';

  @override
  String get trips_photos_tooltip_scan => 'Escanear galeria del dispositivo';

  @override
  String get trips_photos_viewAll => 'Ver todas';

  @override
  String get trips_picker_clearTooltip => 'Borrar seleccion';

  @override
  String get trips_picker_empty_createButton => 'Crear viaje';

  @override
  String get trips_picker_empty_title => 'No hay viajes aun';

  @override
  String trips_picker_error(Object error) {
    return 'Error al cargar viajes: $error';
  }

  @override
  String get trips_picker_hint => 'Toca para seleccionar un viaje';

  @override
  String get trips_picker_newTrip => 'Nuevo viaje';

  @override
  String get trips_picker_noSelection => 'No se ha seleccionado viaje';

  @override
  String get trips_picker_sheetTitle => 'Seleccionar viaje';

  @override
  String trips_picker_suggestedPrefix(Object name) {
    return 'Sugerido: $name';
  }

  @override
  String get trips_picker_suggestedUse => 'Usar';

  @override
  String get trips_search_empty_hint => 'Buscar por nombre, ubicacion o resort';

  @override
  String get trips_search_fieldLabel => 'Buscar viajes...';

  @override
  String trips_search_noResults(Object query) {
    return 'No se encontraron viajes para \"$query\"';
  }

  @override
  String get trips_search_tooltip_back => 'Atras';

  @override
  String get trips_search_tooltip_clear => 'Borrar busqueda';

  @override
  String get trips_summary_header_subtitle =>
      'Selecciona un viaje de la lista para ver detalles';

  @override
  String get trips_summary_header_title => 'Viajes';

  @override
  String get trips_summary_overview_title => 'Resumen';

  @override
  String get trips_summary_quickActions_add => 'Agregar viaje';

  @override
  String get trips_summary_quickActions_title => 'Acciones rapidas';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date • $count inmersiones';
  }

  @override
  String get trips_summary_recentTitle => 'Viajes recientes';

  @override
  String get trips_summary_stat_daysDiving => 'Dias de buceo';

  @override
  String get trips_summary_stat_liveaboards => 'Vida a bordo';

  @override
  String get trips_summary_stat_totalDives => 'Total de inmersiones';

  @override
  String get trips_summary_stat_totalTrips => 'Total de viajes';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date • En $days dias';
  }

  @override
  String get trips_summary_upcomingTitle => 'Proximos';

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
  String get units_sac_pressurePerMin => 'presión/min';

  @override
  String get units_temperature_celsius => 'C';

  @override
  String get units_temperature_fahrenheit => 'F';

  @override
  String get units_timeFormat_twelveHour => '12 horas';

  @override
  String get units_timeFormat_twentyFourHour => '24 horas';

  @override
  String get units_volume_cubicFeet => 'cuft';

  @override
  String get units_volume_liters => 'L';

  @override
  String get units_weight_kilograms => 'kg';

  @override
  String get units_weight_pounds => 'lbs';

  @override
  String get universalImport_action_continue => 'Continuar';

  @override
  String get universalImport_action_deselectAll => 'Deseleccionar Todo';

  @override
  String get universalImport_action_done => 'Listo';

  @override
  String get universalImport_action_import => 'Importar';

  @override
  String get universalImport_action_selectAll => 'Seleccionar Todo';

  @override
  String get universalImport_action_selectFile => 'Seleccionar Archivo';

  @override
  String get universalImport_description_supportedFormats =>
      'Selecciona un archivo de registro de inmersiones para importar. Los formatos compatibles incluyen CSV, UDDF, Subsurface XML y Garmin FIT.';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Este formato aún no es compatible. Por favor exporta como UDDF o CSV.';

  @override
  String get universalImport_hint_tagDescription =>
      'Etiqueta todas las inmersiones importadas para filtrado fácil';

  @override
  String get universalImport_hint_tagExample =>
      'ej., Importación MacDive 2026-02-09';

  @override
  String get universalImport_label_columnMapping => 'Mapeo de Columnas';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped de $total columnas mapeadas';
  }

  @override
  String get universalImport_label_detecting => 'Detectando...';

  @override
  String universalImport_label_diveNumber(Object number) {
    return 'Inmersión #$number';
  }

  @override
  String get universalImport_label_duplicate => 'Duplicado';

  @override
  String universalImport_label_duplicatesFound(Object count) {
    return '$count duplicados encontrados y deseleccionados automáticamente.';
  }

  @override
  String get universalImport_label_importComplete => 'Importación Completa';

  @override
  String get universalImport_label_importTag => 'Etiqueta de Importación';

  @override
  String get universalImport_label_importing => 'Importando';

  @override
  String get universalImport_label_importingEllipsis => 'Importando...';

  @override
  String universalImport_label_importingProgress(Object current, Object total) {
    return 'Importando $current de $total';
  }

  @override
  String universalImport_label_percentMatch(Object percent) {
    return '$percent% coincidencia';
  }

  @override
  String get universalImport_label_possibleMatch => 'Posible coincidencia';

  @override
  String get universalImport_label_selectCorrectSource =>
      '¿No es correcto? Selecciona la fuente correcta:';

  @override
  String universalImport_label_selected(Object count) {
    return '$count seleccionado';
  }

  @override
  String get universalImport_label_skip => 'Omitir';

  @override
  String universalImport_label_taggedAs(Object tag) {
    return 'Etiquetado como: $tag';
  }

  @override
  String get universalImport_label_unknownDate => 'Fecha desconocida';

  @override
  String get universalImport_label_unnamed => 'Sin nombre';

  @override
  String universalImport_label_xOfY(Object current, Object total) {
    return '$current de $total';
  }

  @override
  String universalImport_label_xOfYSelected(Object selected, Object total) {
    return '$selected de $total seleccionado';
  }

  @override
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  ) {
    return '$selected de $total $entityType seleccionado';
  }

  @override
  String universalImport_semantics_importError(Object error) {
    return 'Error de importación: $error';
  }

  @override
  String universalImport_semantics_importProgress(Object percent) {
    return 'Progreso de importación: $percent por ciento';
  }

  @override
  String universalImport_semantics_itemsSelected(Object count) {
    return '$count elementos seleccionados para importar';
  }

  @override
  String get universalImport_semantics_possibleDuplicate => 'Posible duplicado';

  @override
  String get universalImport_semantics_probableDuplicate =>
      'Probable duplicado';

  @override
  String universalImport_semantics_sourceDetected(Object description) {
    return 'Fuente detectada: $description';
  }

  @override
  String universalImport_semantics_sourceUncertain(Object description) {
    return 'Fuente incierta: $description';
  }

  @override
  String universalImport_semantics_toggleSelection(Object name) {
    return 'Alternar selección para $name';
  }

  @override
  String get universalImport_step_import => 'Importar';

  @override
  String get universalImport_step_map => 'Mapear';

  @override
  String get universalImport_step_review => 'Revisar';

  @override
  String get universalImport_step_select => 'Seleccionar';

  @override
  String get universalImport_title => 'Importar Datos';

  @override
  String get universalImport_tooltip_clearTag => 'Limpiar etiqueta';

  @override
  String get universalImport_tooltip_closeWizard =>
      'Cerrar asistente de importación';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return 'Base ($suitType): $weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return 'Ajuste por peso corporal: +$adjustment kg';
  }

  @override
  String get weightCalc_suit_drysuit => 'Traje seco';

  @override
  String get weightCalc_suit_none => 'Sin traje';

  @override
  String get weightCalc_suit_rashguard => 'Solo camiseta';

  @override
  String get weightCalc_suit_semidry => 'Traje semiseco';

  @override
  String get weightCalc_suit_shorty3mm => 'Shorty 3mm';

  @override
  String get weightCalc_suit_wetsuit3mm => 'Traje de neopreno 3mm completo';

  @override
  String get weightCalc_suit_wetsuit5mm => 'Traje de neopreno 5mm';

  @override
  String get weightCalc_suit_wetsuit7mm => 'Traje de neopreno 7mm';

  @override
  String weightCalc_tankLine(Object tankMaterial, Object adjustment) {
    return 'Tanque ($tankMaterial): $adjustment kg';
  }

  @override
  String get weightCalc_title => 'Cálculo de lastre:';

  @override
  String weightCalc_total(Object total) {
    return 'Total: $total kg';
  }

  @override
  String weightCalc_waterLine(Object waterType, Object adjustment) {
    return 'Agua ($waterType): $adjustment kg';
  }

  @override
  String divePlanner_label_resultsWithWarnings(Object count) {
    return 'Resultados, $count advertencias';
  }

  @override
  String tides_semantic_tideCycle(Object state, Object height) {
    return 'Ciclo de marea, estado: $state, altura: $height';
  }

  @override
  String get tides_label_agoSuffix => 'atrás';

  @override
  String get tides_label_fromNowSuffix => 'desde ahora';

  @override
  String get certifications_card_issued => 'EMITIDA';

  @override
  String certifications_certificate_cardNumber(Object number) {
    return 'Numero de tarjeta: $number';
  }

  @override
  String get certifications_certificate_footer =>
      'Certificacion oficial de buceo';

  @override
  String get certifications_certificate_hasCompletedTraining =>
      'ha completado la formacion como';

  @override
  String certifications_certificate_instructor(Object name) {
    return 'Instructor: $name';
  }

  @override
  String certifications_certificate_issued(Object date) {
    return 'Emitida: $date';
  }

  @override
  String get certifications_certificate_thisCertifies => 'Se certifica que';

  @override
  String get diveComputer_discovery_chooseDifferentDevice =>
      'Elegir otro dispositivo';

  @override
  String get diveComputer_discovery_computer => 'Ordenador';

  @override
  String get diveComputer_discovery_connectAndDownload =>
      'Conectar y descargar';

  @override
  String get diveComputer_discovery_connectingToDevice =>
      'Conectando al dispositivo...';

  @override
  String diveComputer_discovery_deviceNameHint(Object model) {
    return 'p. ej., Mi $model';
  }

  @override
  String get diveComputer_discovery_deviceNameLabel => 'Nombre del dispositivo';

  @override
  String get diveComputer_discovery_exitDialogCancel => 'Cancelar';

  @override
  String get diveComputer_discovery_exitDialogConfirm => 'Salir';

  @override
  String get diveComputer_discovery_exitDialogContent =>
      'Seguro que quieres salir? Se perdera el progreso.';

  @override
  String get diveComputer_discovery_exitDialogTitle =>
      'Salir de la configuracion?';

  @override
  String get diveComputer_discovery_exitTooltip => 'Salir de la configuracion';

  @override
  String get diveComputer_discovery_noDeviceSelected =>
      'Ningun dispositivo seleccionado';

  @override
  String get diveComputer_discovery_pleaseWaitConnection =>
      'Espera mientras establecemos la conexion';

  @override
  String get diveComputer_discovery_recognizedDevice =>
      'Dispositivo reconocido';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      'Este dispositivo esta en nuestra biblioteca de dispositivos compatibles. La descarga de inmersiones deberia funcionar automaticamente.';

  @override
  String get diveComputer_discovery_stepConnect => 'Conectar';

  @override
  String get diveComputer_discovery_stepDone => 'Listo';

  @override
  String get diveComputer_discovery_stepDownload => 'Descargar';

  @override
  String get diveComputer_discovery_stepScan => 'Buscar';

  @override
  String get diveComputer_discovery_titleComplete => 'Completado';

  @override
  String get diveComputer_discovery_titleConfirmDevice =>
      'Confirmar dispositivo';

  @override
  String get diveComputer_discovery_titleConnecting => 'Conectando';

  @override
  String get diveComputer_discovery_titleDownloading => 'Descargando';

  @override
  String get diveComputer_discovery_titleFindDevice => 'Buscar dispositivo';

  @override
  String get diveComputer_discovery_unknownDevice => 'Dispositivo desconocido';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      'Este dispositivo no esta en nuestra biblioteca. Intentaremos conectar, pero la descarga podria no funcionar.';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... y $count mas';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Cancelar';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadFailed => 'La descarga fallo';

  @override
  String get diveComputer_downloadStep_downloadedDives =>
      'Inmersiones descargadas';

  @override
  String diveComputer_downloadStep_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_downloadStep_errorOccurred => 'Se produjo un error';

  @override
  String diveComputer_downloadStep_errorSemanticLabel(Object error) {
    return 'Error de descarga: $error';
  }

  @override
  String diveComputer_downloadStep_percentAccessibility(Object percent) {
    return ', $percent por ciento';
  }

  @override
  String get diveComputer_downloadStep_preparing => 'Preparando...';

  @override
  String diveComputer_downloadStep_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String diveComputer_downloadStep_progressSemanticLabel(
    Object status,
    Object percent,
  ) {
    return 'Progreso de descarga: $status$percent';
  }

  @override
  String get diveComputer_downloadStep_retry => 'Reintentar';

  @override
  String get diveComputer_download_cancel => 'Cancelar';

  @override
  String get diveComputer_download_closeTooltip => 'Cerrar';

  @override
  String get diveComputer_download_computerNotFound =>
      'Ordenador no encontrado';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return 'Dispositivo no encontrado. Asegurate de que tu $name esta cerca y en modo de transferencia.';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle =>
      'Dispositivo no encontrado';

  @override
  String get diveComputer_download_divesUpdated => 'Inmersiones actualizadas';

  @override
  String get diveComputer_download_done => 'Listo';

  @override
  String get diveComputer_download_downloadedDives => 'Inmersiones descargadas';

  @override
  String get diveComputer_download_duplicatesSkipped => 'Duplicados omitidos';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_download_errorOccurred => 'Se produjo un error';

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get diveComputer_download_goBack => 'Volver';

  @override
  String get diveComputer_download_importFailed => 'La importacion fallo';

  @override
  String get diveComputer_download_importResults => 'Resultados de importacion';

  @override
  String get diveComputer_download_importedDives => 'Inmersiones importadas';

  @override
  String get diveComputer_download_newDivesImported =>
      'Nuevas inmersiones importadas';

  @override
  String get diveComputer_download_preparing => 'Preparando...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_retry => 'Reintentar';

  @override
  String diveComputer_download_scanError(Object error) {
    return 'Error de escaneo: $error';
  }

  @override
  String diveComputer_download_searchingForDevice(Object name) {
    return 'Buscando $name...';
  }

  @override
  String get diveComputer_download_searchingInstructions =>
      'Asegurate de que el dispositivo esta cerca y en modo de transferencia';

  @override
  String get diveComputer_download_title => 'Descargar inmersiones';

  @override
  String get diveComputer_download_tryAgain => 'Intentar de nuevo';

  @override
  String get diveComputer_list_addComputer => 'Anadir ordenador';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return 'Ordenador de buceo: $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count inmersiones';
  }

  @override
  String get diveComputer_list_downloadTooltip => 'Descargar inmersiones';

  @override
  String get diveComputer_list_emptyMessage =>
      'Conecta tu ordenador de buceo para descargar inmersiones directamente en la app.';

  @override
  String get diveComputer_list_emptyTitle => 'Sin ordenadores de buceo';

  @override
  String get diveComputer_list_findComputers => 'Buscar ordenadores';

  @override
  String get diveComputer_list_helpBluetooth =>
      '- Bluetooth LE (la mayoria de ordenadores modernos)';

  @override
  String get diveComputer_list_helpBluetoothClassic =>
      '- Bluetooth Classic (modelos antiguos)';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi y mas de 50 modelos.';

  @override
  String get diveComputer_list_helpBrandsTitle => 'Marcas compatibles';

  @override
  String get diveComputer_list_helpConnectionsTitle => 'Conexiones compatibles';

  @override
  String get diveComputer_list_helpDialogTitle =>
      'Ayuda de ordenadores de buceo';

  @override
  String get diveComputer_list_helpDismiss => 'Entendido';

  @override
  String get diveComputer_list_helpTip1 =>
      '- Asegurate de que tu ordenador esta en modo de transferencia';

  @override
  String get diveComputer_list_helpTip2 =>
      '- Manten los dispositivos cerca durante la descarga';

  @override
  String get diveComputer_list_helpTip3 =>
      '- Asegurate de que el Bluetooth esta activado';

  @override
  String get diveComputer_list_helpTipsTitle => 'Consejos';

  @override
  String get diveComputer_list_helpTooltip => 'Ayuda';

  @override
  String get diveComputer_list_helpUsb => '- USB (solo escritorio)';

  @override
  String get diveComputer_list_loadFailed =>
      'Error al cargar ordenadores de buceo';

  @override
  String get diveComputer_list_retry => 'Reintentar';

  @override
  String get diveComputer_list_title => 'Ordenadores de buceo';

  @override
  String get diveComputer_summary_diveComputer => 'ordenador de buceo';

  @override
  String diveComputer_summary_divesDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones',
      one: 'inmersion',
    );
    return '$count $_temp0 descargadas';
  }

  @override
  String get diveComputer_summary_done => 'Listo';

  @override
  String get diveComputer_summary_imported => 'Importadas';

  @override
  String diveComputer_summary_semanticLabel(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones descargadas',
      one: 'inmersion descargada',
    );
    return '$count $_temp0 de $name';
  }

  @override
  String get diveComputer_summary_skippedDuplicates => 'Omitidas (duplicados)';

  @override
  String get diveComputer_summary_title => 'Descarga completa!';

  @override
  String get diveComputer_summary_updated => 'Actualizadas';

  @override
  String get diveComputer_summary_viewDives => 'Ver inmersiones';

  @override
  String get diveImport_alreadyImported => 'Ya importada';

  @override
  String get diveImport_avgHR => 'FC media';

  @override
  String get diveImport_back => 'Atras';

  @override
  String get diveImport_deselectAll => 'Deseleccionar todo';

  @override
  String get diveImport_divesImported => 'Inmersiones importadas';

  @override
  String get diveImport_divesMerged => 'Inmersiones combinadas';

  @override
  String get diveImport_divesSkipped => 'Inmersiones omitidas';

  @override
  String get diveImport_done => 'Listo';

  @override
  String get diveImport_duration => 'Duracion';

  @override
  String get diveImport_error => 'Error';

  @override
  String get diveImport_fit_closeTooltip => 'Cerrar importacion FIT';

  @override
  String get diveImport_fit_noDivesDescription =>
      'Selecciona uno o mas archivos .fit exportados de Garmin Connect o copiados de un dispositivo Garmin Descent.';

  @override
  String get diveImport_fit_noDivesLoaded => 'Sin inmersiones cargadas';

  @override
  String diveImport_fit_parsed(int diveCount, int fileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'inmersiones',
      one: 'inmersion',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'archivos',
      one: 'archivo',
    );
    return 'Se encontraron $diveCount $_temp0 en $fileCount $_temp1';
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
      other: 'inmersiones',
      one: 'inmersion',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'archivos',
      one: 'archivo',
    );
    return 'Se encontraron $diveCount $_temp0 en $fileCount $_temp1 ($skippedCount omitidas)';
  }

  @override
  String get diveImport_fit_parsing => 'Analizando...';

  @override
  String get diveImport_fit_selectFiles => 'Seleccionar archivos FIT';

  @override
  String get diveImport_fit_title => 'Importar desde archivo FIT';

  @override
  String get diveImport_healthkit_accessDescription =>
      'Submersion necesita acceso a los datos de buceo de tu Apple Watch para importar inmersiones.';

  @override
  String get diveImport_healthkit_accessRequired =>
      'Acceso a HealthKit requerido';

  @override
  String get diveImport_healthkit_closeTooltip =>
      'Cerrar importacion de Apple Watch';

  @override
  String get diveImport_healthkit_dateFrom => 'Desde';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return 'Selector de fecha $label';
  }

  @override
  String get diveImport_healthkit_dateTo => 'Hasta';

  @override
  String get diveImport_healthkit_fetchDives => 'Obtener inmersiones';

  @override
  String get diveImport_healthkit_fetching => 'Obteniendo...';

  @override
  String get diveImport_healthkit_grantAccess => 'Conceder acceso';

  @override
  String get diveImport_healthkit_noDivesFound => 'Sin inmersiones encontradas';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'No se encontraron actividades de buceo en el rango de fechas seleccionado.';

  @override
  String get diveImport_healthkit_notAvailable => 'No disponible';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'La importacion de Apple Watch solo esta disponible en dispositivos iOS y macOS.';

  @override
  String get diveImport_healthkit_permissionCheckFailed =>
      'Error al verificar permisos';

  @override
  String get diveImport_healthkit_title => 'Importar desde Apple Watch';

  @override
  String get diveImport_healthkit_watchTitle => 'Importar desde Watch';

  @override
  String get diveImport_import => 'Importar';

  @override
  String get diveImport_importComplete => 'Importacion completa';

  @override
  String get diveImport_likelyDuplicate => 'Probable duplicado';

  @override
  String get diveImport_maxDepth => 'Prof. max.';

  @override
  String get diveImport_newDive => 'Nueva inmersion';

  @override
  String get diveImport_next => 'Siguiente';

  @override
  String get diveImport_possibleDuplicate => 'Posible duplicado';

  @override
  String get diveImport_reviewSelectedDives =>
      'Revisar inmersiones seleccionadas';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: ', $possibleCount posibles duplicados',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: ', $skipCount se omitiran',
      zero: '',
    );
    return '$newCount nuevas$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => 'Seleccionar todo';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count seleccionadas';
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
  String get diveImport_step_done => 'Listo';

  @override
  String get diveImport_step_review => 'Revisar';

  @override
  String get diveImport_step_select => 'Seleccionar';

  @override
  String get diveImport_temp => 'Temp';

  @override
  String get diveImport_toggleDiveSelection =>
      'Alternar seleccion de inmersion';

  @override
  String get diveImport_uddf_buddies => 'Companeros';

  @override
  String get diveImport_uddf_certifications => 'Certificaciones';

  @override
  String get diveImport_uddf_closeTooltip => 'Cerrar importacion UDDF';

  @override
  String get diveImport_uddf_diveCenters => 'Centros de buceo';

  @override
  String get diveImport_uddf_diveTypes => 'Tipos de inmersion';

  @override
  String get diveImport_uddf_dives => 'Inmersiones';

  @override
  String get diveImport_uddf_duplicate => 'Duplicado';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return '$count duplicados encontrados y deseleccionados automaticamente.';
  }

  @override
  String get diveImport_uddf_equipment => 'Equipo';

  @override
  String get diveImport_uddf_equipmentSets => 'Conjuntos de equipo';

  @override
  String diveImport_uddf_importProgress(Object current, Object total) {
    return '$current de $total';
  }

  @override
  String get diveImport_uddf_importing => 'Importando...';

  @override
  String get diveImport_uddf_likelyDuplicate => 'Probable duplicado';

  @override
  String get diveImport_uddf_noFileDescription =>
      'Selecciona un archivo .uddf o .xml exportado de otra aplicacion de registro de inmersiones.';

  @override
  String get diveImport_uddf_noFileSelected => 'Ningun archivo seleccionado';

  @override
  String get diveImport_uddf_parsing => 'Analizando...';

  @override
  String get diveImport_uddf_possibleDuplicate => 'Posible duplicado';

  @override
  String get diveImport_uddf_selectFile => 'Seleccionar archivo UDDF';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '$selected de $total seleccionadas';
  }

  @override
  String get diveImport_uddf_sites => 'Puntos de buceo';

  @override
  String get diveImport_uddf_stepImport => 'Importar';

  @override
  String get diveImport_uddf_tabBuddies => 'Companeros';

  @override
  String get diveImport_uddf_tabCenters => 'Centros';

  @override
  String get diveImport_uddf_tabCerts => 'Certs';

  @override
  String get diveImport_uddf_tabCourses => 'Cursos';

  @override
  String get diveImport_uddf_tabDives => 'Inmersiones';

  @override
  String get diveImport_uddf_tabEquipment => 'Equipo';

  @override
  String get diveImport_uddf_tabSets => 'Conjuntos';

  @override
  String get diveImport_uddf_tabSites => 'Puntos';

  @override
  String get diveImport_uddf_tabTags => 'Etiquetas';

  @override
  String get diveImport_uddf_tabTrips => 'Viajes';

  @override
  String get diveImport_uddf_tabTypes => 'Tipos';

  @override
  String get diveImport_uddf_tags => 'Etiquetas';

  @override
  String get diveImport_uddf_title => 'Importar desde UDDF';

  @override
  String get diveImport_uddf_toggleDiveSelection =>
      'Alternar seleccion de inmersion';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return 'Alternar seleccion de $name';
  }

  @override
  String get diveImport_uddf_trips => 'Viajes';

  @override
  String get divePlanner_segmentEditor_addTitle => 'Anadir segmento';

  @override
  String divePlanner_segmentEditor_ascentRate(Object unit) {
    return 'Vel. de ascenso ($unit/min)';
  }

  @override
  String divePlanner_segmentEditor_descentRate(Object unit) {
    return 'Vel. de descenso ($unit/min)';
  }

  @override
  String get divePlanner_segmentEditor_duration => 'Duracion (min)';

  @override
  String get divePlanner_segmentEditor_editTitle => 'Editar segmento';

  @override
  String divePlanner_segmentEditor_endDepth(Object unit) {
    return 'Profundidad final ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_gasSwitchTime =>
      'Tiempo de cambio de gas';

  @override
  String get divePlanner_segmentEditor_segmentType => 'Tipo de segmento';

  @override
  String divePlanner_segmentEditor_startDepth(Object unit) {
    return 'Profundidad inicial ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_tankGas => 'Tanque / Gas';

  @override
  String get divePlanner_segmentList_addSegment => 'Anadir segmento';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return 'Ascenso $startDepth -> $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return 'Fondo $depth por $minutes min';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return 'Deco $depth por $minutes min';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => 'Eliminar segmento';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return 'Descenso $startDepth -> $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => 'Editar segmento';

  @override
  String get divePlanner_segmentList_emptyMessage =>
      'Anade segmentos manualmente o crea un plan rapido';

  @override
  String get divePlanner_segmentList_emptyTitle => 'Sin segmentos aun';

  @override
  String divePlanner_segmentList_gasSwitch(Object gasName) {
    return 'Cambio de gas a $gasName';
  }

  @override
  String get divePlanner_segmentList_quickPlan => 'Plan rapido';

  @override
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes) {
    return 'Parada de seguridad $depth por $minutes min';
  }

  @override
  String get divePlanner_segmentList_title => 'Segmentos de inmersion';

  @override
  String get divePlanner_segmentType_ascent => 'Ascenso';

  @override
  String get divePlanner_segmentType_bottomTime => 'Tiempo de fondo';

  @override
  String get divePlanner_segmentType_decoStop => 'Parada deco';

  @override
  String get divePlanner_segmentType_descent => 'Descenso';

  @override
  String get divePlanner_segmentType_gasSwitch => 'Cambio de gas';

  @override
  String get divePlanner_segmentType_safetyStop => 'Parada de seguridad';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'La reserva minima (rock bottom) es la cantidad minima de gas para un ascenso de emergencia compartiendo aire con tu companero.\n\n- Usa tasas SAC de estres (2-3x lo normal)\n- Asume ambos buceadores con un solo tanque\n- Incluye parada de seguridad cuando esta activada\n\nSiempre inicia el regreso ANTES de alcanzar la reserva minima!';

  @override
  String get gasCalculators_rockBottom_aboutTitle => 'Sobre la reserva minima';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired =>
      'Gas de ascenso requerido';

  @override
  String get gasCalculators_rockBottom_ascentRate => 'Velocidad de ascenso';

  @override
  String gasCalculators_rockBottom_ascentTimeToDepth(
    Object depth,
    Object unit,
  ) {
    return 'Tiempo de ascenso a $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_ascentTimeToSurface =>
      'Tiempo de ascenso a superficie';

  @override
  String get gasCalculators_rockBottom_buddySac => 'SAC del companero';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'SAC combinado bajo estres';

  @override
  String get gasCalculators_rockBottom_emergencyAscentBreakdown =>
      'Desglose del ascenso de emergencia';

  @override
  String get gasCalculators_rockBottom_emergencyScenario =>
      'Escenario de emergencia';

  @override
  String get gasCalculators_rockBottom_includeSafetyStop =>
      'Incluir parada de seguridad';

  @override
  String get gasCalculators_rockBottom_maximumDepth => 'Profundidad maxima';

  @override
  String get gasCalculators_rockBottom_minimumReserve => 'Reserva minima';

  @override
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  ) {
    return 'Reserva minima: $pressure $pressureUnit, $volume $volumeUnit. Inicia el regreso al alcanzar $pressure $pressureUnit restantes';
  }

  @override
  String gasCalculators_rockBottom_safetyStopDuration(
    Object depth,
    Object unit,
  ) {
    return '3 minutos a $depth$unit';
  }

  @override
  String gasCalculators_rockBottom_safetyStopGas(Object depth, Object unit) {
    return 'Gas de parada de seguridad (3 min @ $depth$unit)';
  }

  @override
  String get gasCalculators_rockBottom_stressedSacHint =>
      'Usa tasas SAC mas altas para compensar el estres durante una emergencia';

  @override
  String get gasCalculators_rockBottom_stressedSacRates =>
      'Tasas SAC bajo estres';

  @override
  String get gasCalculators_rockBottom_tankSize => 'Tamano del tanque';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded =>
      'Reserva total necesaria';

  @override
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  ) {
    return 'Inicia el regreso al alcanzar $pressure $pressureUnit restantes';
  }

  @override
  String get gasCalculators_rockBottom_yourSac => 'Tu SAC';

  @override
  String get maps_heatMap_hide => 'Ocultar mapa de calor';

  @override
  String get maps_heatMap_overlayOff =>
      'La capa de mapa de calor esta desactivada';

  @override
  String get maps_heatMap_overlayOn => 'La capa de mapa de calor esta activada';

  @override
  String get maps_heatMap_show => 'Mostrar mapa de calor';

  @override
  String get maps_offline_bounds => 'Limites';

  @override
  String maps_offline_cacheHitRateAccessibility(Object rate) {
    return 'Tasa de aciertos de cache: $rate por ciento';
  }

  @override
  String get maps_offline_cacheHits => 'Aciertos de cache';

  @override
  String get maps_offline_cacheMisses => 'Fallos de cache';

  @override
  String get maps_offline_cacheStatistics => 'Estadisticas de cache';

  @override
  String get maps_offline_cancelDownload => 'Cancelar descarga';

  @override
  String get maps_offline_clearAll => 'Borrar todo';

  @override
  String get maps_offline_clearAllCache => 'Borrar toda la cache';

  @override
  String get maps_offline_clearAllCacheMessage =>
      'Eliminar todas las regiones descargadas y las teselas en cache?';

  @override
  String get maps_offline_clearAllCacheTitle => 'Borrar toda la cache?';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return 'Esto eliminara $count teselas ($size).';
  }

  @override
  String get maps_offline_created => 'Creada';

  @override
  String maps_offline_deleteRegion(Object name) {
    return 'Eliminar region $name';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return 'Eliminar \"$name\" y sus $count teselas en cache?\n\nEsto liberara $size de almacenamiento.';
  }

  @override
  String get maps_offline_deleteRegionTitle => 'Eliminar region?';

  @override
  String get maps_offline_downloadedRegions => 'Regiones descargadas';

  @override
  String maps_offline_downloading(Object regionName) {
    return 'Descargando: $regionName';
  }

  @override
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  ) {
    return 'Descargando $regionName, $percent por ciento completado, $downloaded de $total teselas';
  }

  @override
  String maps_offline_error(Object error) {
    return 'Error: $error';
  }

  @override
  String maps_offline_errorLoadingStats(Object error) {
    return 'Error al cargar estadisticas: $error';
  }

  @override
  String maps_offline_failedTiles(Object count) {
    return '$count fallidas';
  }

  @override
  String maps_offline_hitRate(Object rate) {
    return 'Tasa de aciertos: $rate%';
  }

  @override
  String get maps_offline_lastAccessed => 'Ultimo acceso';

  @override
  String get maps_offline_noRegions => 'Sin regiones sin conexion';

  @override
  String get maps_offline_noRegionsDescription =>
      'Descarga regiones de mapa desde la pagina de detalle del punto de buceo para usar mapas sin conexion.';

  @override
  String get maps_offline_refresh => 'Actualizar';

  @override
  String get maps_offline_region => 'Region';

  @override
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size | $count teselas | Zoom $minZoom-$maxZoom';
  }

  @override
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size, $count teselas, zoom $minZoom a $maxZoom';
  }

  @override
  String get maps_offline_size => 'Tamano';

  @override
  String get maps_offline_tiles => 'Teselas';

  @override
  String maps_offline_tilesPerSecond(Object rate) {
    return '$rate teselas/seg';
  }

  @override
  String maps_offline_tilesProgress(Object downloaded, Object total) {
    return '$downloaded / $total teselas';
  }

  @override
  String get maps_offline_title => 'Mapas sin conexion';

  @override
  String get maps_offline_zoomRange => 'Rango de zoom';

  @override
  String get maps_regionSelector_dragToAdjust =>
      'Arrastra para ajustar la seleccion';

  @override
  String get maps_regionSelector_dragToSelect =>
      'Arrastra en el mapa para seleccionar una region';

  @override
  String get maps_regionSelector_selectRegion =>
      'Seleccionar region en el mapa';

  @override
  String get maps_regionSelector_selectRegionButton => 'Seleccionar region';

  @override
  String get tankPresets_addPreset => 'Anadir preset de tanque';

  @override
  String get tankPresets_builtInPresets => 'Presets incluidos';

  @override
  String get tankPresets_customPresets => 'Presets personalizados';

  @override
  String tankPresets_deleteMessage(Object name) {
    return 'Seguro que quieres eliminar \"$name\"?';
  }

  @override
  String get tankPresets_deletePreset => 'Eliminar preset';

  @override
  String get tankPresets_deleteTitle => 'Eliminar preset de tanque?';

  @override
  String tankPresets_deleted(Object name) {
    return 'Se elimino \"$name\"';
  }

  @override
  String get tankPresets_editPreset => 'Editar preset';

  @override
  String tankPresets_edit_created(Object name) {
    return 'Se creo \"$name\"';
  }

  @override
  String get tankPresets_edit_descriptionHint =>
      'p. ej., Mi tanque de alquiler de la tienda de buceo';

  @override
  String get tankPresets_edit_descriptionOptional => 'Descripcion (opcional)';

  @override
  String tankPresets_edit_errorLoading(Object error) {
    return 'Error al cargar preset: $error';
  }

  @override
  String tankPresets_edit_errorSaving(Object error) {
    return 'Error al guardar preset: $error';
  }

  @override
  String tankPresets_edit_gasCapacity(Object capacity) {
    return '- Capacidad de gas: $capacity cuft';
  }

  @override
  String get tankPresets_edit_material => 'Material';

  @override
  String get tankPresets_edit_name => 'Nombre';

  @override
  String get tankPresets_edit_nameHelper =>
      'Un nombre descriptivo para este preset de tanque';

  @override
  String get tankPresets_edit_nameHint => 'p. ej., Mi AL80';

  @override
  String get tankPresets_edit_nameRequired => 'Introduce un nombre';

  @override
  String get tankPresets_edit_ratedPressure => 'Presion nominal';

  @override
  String get tankPresets_edit_required => 'Obligatorio';

  @override
  String get tankPresets_edit_tankSpecifications =>
      'Especificaciones del tanque';

  @override
  String get tankPresets_edit_title => 'Editar preset de tanque';

  @override
  String tankPresets_edit_updated(Object name) {
    return 'Se actualizo \"$name\"';
  }

  @override
  String get tankPresets_edit_validPressure => 'Introduce una presion valida';

  @override
  String get tankPresets_edit_validVolume => 'Introduce un volumen valido';

  @override
  String get tankPresets_edit_volume => 'Volumen';

  @override
  String get tankPresets_edit_volumeHelperCuft => 'Capacidad de gas (cuft)';

  @override
  String get tankPresets_edit_volumeHelperLiters => 'Volumen de agua (L)';

  @override
  String tankPresets_edit_waterVolume(Object volume) {
    return '- Volumen de agua: $volume L';
  }

  @override
  String get tankPresets_edit_workingPressure => 'Presion de trabajo';

  @override
  String tankPresets_edit_workingPressureBar(Object pressure) {
    return '- Presion de trabajo: $pressure bar';
  }

  @override
  String tankPresets_error(Object error) {
    return 'Error: $error';
  }

  @override
  String tankPresets_errorDeleting(Object error) {
    return 'Error al eliminar preset: $error';
  }

  @override
  String get tankPresets_new_title => 'Nuevo preset de tanque';

  @override
  String get tankPresets_noPresets => 'No hay presets de tanque disponibles';

  @override
  String get tankPresets_title => 'Presets de tanque';

  @override
  String get tools_deco_description =>
      'Calcula limites de no descompresion, paradas deco requeridas y exposicion CNS/OTU para perfiles de inmersion multinivel.';

  @override
  String get tools_deco_subtitle =>
      'Planifica inmersiones con paradas de descompresion';

  @override
  String get tools_deco_title => 'Calculadora deco';

  @override
  String get tools_disclaimer =>
      'Estas calculadoras son solo para planificacion. Siempre verifica los calculos y sigue tu formacion de buceo.';

  @override
  String get tools_gas_description =>
      'Cuatro calculadoras de gas especializadas:\n- MOD - Profundidad maxima operativa para una mezcla\n- Mejor mezcla - % de O2 ideal para una profundidad objetivo\n- Consumo - Estimacion de uso de gas\n- Reserva minima - Calculo de reserva de emergencia';

  @override
  String get tools_gas_subtitle => 'MOD, Mejor mezcla, Consumo, Reserva minima';

  @override
  String get tools_gas_title => 'Calculadoras de gas';

  @override
  String get tools_title => 'Herramientas';

  @override
  String get tools_weight_aluminumImperial => 'Mas flotabilidad vacio (+4 lbs)';

  @override
  String get tools_weight_aluminumMetric => 'Mas flotabilidad vacio (+2 kg)';

  @override
  String get tools_weight_bodyWeightOptional => 'Peso corporal (opcional)';

  @override
  String get tools_weight_carbonFiberImperial => 'Muy flotante (+7 lbs)';

  @override
  String get tools_weight_carbonFiberMetric => 'Muy flotante (+3 kg)';

  @override
  String get tools_weight_description =>
      'Estima el peso que necesitas segun tu traje, material del tanque, tipo de agua y peso corporal.';

  @override
  String get tools_weight_disclaimer =>
      'Esto es solo una estimacion. Siempre realiza una comprobacion de flotabilidad al inicio de tu inmersion y ajusta segun sea necesario. Factores como el chaleco, flotabilidad personal y patron de respiracion afectaran tus requisitos de peso reales.';

  @override
  String get tools_weight_exposureSuit => 'Traje de exposicion';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return '- Capacidad de gas: $capacity cuft';
  }

  @override
  String get tools_weight_helperImperial =>
      'Anade ~2 lbs por cada 22 lbs sobre 154 lbs';

  @override
  String get tools_weight_helperMetric =>
      'Anade ~1 kg por cada 10 kg sobre 70 kg';

  @override
  String get tools_weight_notSpecified => 'No especificado';

  @override
  String get tools_weight_recommendedWeight => 'Peso recomendado';

  @override
  String tools_weight_resultAccessibility(Object weight, Object unit) {
    return 'Peso recomendado: $weight $unit';
  }

  @override
  String get tools_weight_steelImperial => 'Flotabilidad negativa (-4 lbs)';

  @override
  String get tools_weight_steelMetric => 'Flotabilidad negativa (-2 kg)';

  @override
  String get tools_weight_subtitle => 'Peso recomendado para tu configuracion';

  @override
  String get tools_weight_tankMaterial => 'Material del tanque';

  @override
  String get tools_weight_tankSpecifications => 'Especificaciones del tanque';

  @override
  String get tools_weight_title => 'Calculadora de peso';

  @override
  String get tools_weight_waterType => 'Tipo de agua';

  @override
  String tools_weight_waterVolume(Object volume) {
    return '- Volumen de agua: $volume L';
  }

  @override
  String tools_weight_workingPressure(Object pressure) {
    return '- Presion de trabajo: $pressure bar';
  }

  @override
  String get tools_weight_yourWeight => 'Tu peso';
}
