// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get universalImport_action_importFromGarmin =>
      'Importar desde dispositivo Garmin';

  @override
  String diveLog_edit_flightWindowWarning(String time) {
    return 'Esta inmersión termina después de la última hora segura para emerger antes de tu vuelo ($time)';
  }

  @override
  String diveLog_edit_geofenceSuggestion_near(String location) {
    return 'Cerca de $location';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_title => 'Sugerencia de equipo';

  @override
  String diveLog_edit_geofenceSuggestion_body(String setName) {
    return '¿Aplicar tu conjunto \"$setName\"?';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_apply => 'Aplicar';

  @override
  String get common_action_dismiss => 'Descartar';

  @override
  String get equipment_setEdit_defaultSwitch_title => 'Conjunto predeterminado';

  @override
  String get equipment_setEdit_defaultSwitch_subtitle =>
      'Se aplica automáticamente a las inmersiones nuevas que aún no tienen equipo';

  @override
  String get equipment_setEdit_geofencesTitle => 'Geocercas';

  @override
  String get equipment_setEdit_geofencesSubtitle =>
      'Sugerir automáticamente este conjunto para inmersiones cerca de estas ubicaciones';

  @override
  String get equipment_setEdit_addGeofence => 'Añadir geocerca';

  @override
  String get equipment_setEdit_editGeofence => 'Edit geofence';

  @override
  String get equipment_setEdit_removeGeofence => 'Remove geofence';

  @override
  String equipment_setEdit_geofenceRadius(String distance) {
    return 'Radio: $distance';
  }

  @override
  String get equipment_geofenceEditor_title => 'Geocerca';

  @override
  String get equipment_geofenceEditor_fromSite => 'Desde el sitio de buceo';

  @override
  String get equipment_geofenceEditor_dropPin => 'Colocar un pin';

  @override
  String get equipment_geofenceEditor_labelLabel => 'Etiqueta';

  @override
  String get equipment_geofenceEditor_noCenter => 'Elige un punto central';

  @override
  String get equipment_geofenceEditor_save => 'Guardar geocerca';

  @override
  String get equipment_sets_defaultBadge => 'Predeterminado';

  @override
  String get equipment_setDetail_setAsDefault =>
      'Establecer como predeterminado';

  @override
  String equipment_setDetail_setAsDefaultSnackbar(String name) {
    return '\"$name\" es ahora tu conjunto predeterminado';
  }

  @override
  String get equipment_setDetail_geofencesTitle => 'Geocercas';

  @override
  String get equipment_setDetail_noGeofences => 'Sin geocercas';

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
    return 'Por encima del limite maximo de densidad de $limit g/L.';
  }

  @override
  String get gasCalculators_bestMix_densityLabel =>
      'Densidad del gas a profundidad';

  @override
  String gasCalculators_bestMix_densityWarn(Object limit) {
    return 'Por encima del limite de densidad recomendado de $limit g/L.';
  }

  @override
  String gasCalculators_bestMix_endExceeded(Object limit) {
    return 'La END supera tu limite de $limit.';
  }

  @override
  String get gasCalculators_bestMix_endLabel => 'END a profundidad';

  @override
  String get gasCalculators_bestMix_endLimitLabel => 'Limite END';

  @override
  String gasCalculators_bestMix_heliumAdded(Object limit) {
    return 'Helio anadido para mantener la END dentro de tu limite de $limit.';
  }

  @override
  String get gasCalculators_bestMix_idealLabel => 'Fraccion ideal';

  @override
  String get gasCalculators_bestMix_marginLabel => 'Margen bajo la MOD';

  @override
  String gasCalculators_bestMix_modLabel(Object ppO2) {
    return 'MOD a ppO2 $ppO2';
  }

  @override
  String get gasCalculators_bestMix_nearestStandard =>
      'Mezcla estandar mas cercana que cubre esta profundidad';

  @override
  String get gasCalculators_bestMix_recommendedMix => 'Mezcla recomendada';

  @override
  String get gasCalculators_bestMix_withoutHelium => 'Sin helio';

  @override
  String get gasCalculators_planningCaveat =>
      'Estimacion de planificacion. Asume un ascenso directo. Verifica segun tu formacion y anade margen por las condiciones.';

  @override
  String gasCalculators_rockBottom_solveGas(Object depth, Object unit) {
    return 'Gas para resolver el problema a $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_solveTime =>
      'Tiempo de resolucion del problema';

  @override
  String get gasCalculators_rockBottom_solveTimeHint =>
      'Tiempo en el fondo resolviendo la emergencia antes de iniciar el ascenso.';

  @override
  String o2Toxicity_addedThisDive(Object value) {
    return '+$value esta inmersion';
  }

  @override
  String o2Toxicity_cnsProgressSemantics(Object percent) {
    return 'Progreso SNC $percent por ciento';
  }

  @override
  String get o2Toxicity_daily => 'Diario';

  @override
  String o2Toxicity_otuSemantics(
    Object label,
    Object value,
    Object limit,
    Object percent,
  ) {
    return '$label: $value de $limit OTU, $percent por ciento';
  }

  @override
  String o2Toxicity_otuValueSemantics(Object label, Object value) {
    return '$label: $value OTU';
  }

  @override
  String o2Toxicity_prior(Object value) {
    return 'Previo: $value OTU';
  }

  @override
  String o2Toxicity_start(Object value) {
    return 'Inicio: $value OTU';
  }

  @override
  String get o2Toxicity_thisDive => 'Esta inmersion';

  @override
  String get o2Toxicity_weekly => 'Semanal';

  @override
  String trips_story_dayLabel(int number) {
    return 'Día $number';
  }

  @override
  String get trips_story_surfaceDay => 'Día de superficie';

  @override
  String get trips_story_today => 'Hoy';

  @override
  String trips_story_dayOfTrip(int current, int total) {
    return 'Día $current de $total';
  }

  @override
  String trips_story_daysUntil(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días para la salida',
      one: '1 día para la salida',
    );
    return '$_temp0';
  }

  @override
  String trips_story_checklistProgress(int done, int total) {
    return '$done de $total completado';
  }

  @override
  String get trips_story_generateItinerary => 'Generar itinerario';

  @override
  String get trips_story_openGallery => 'Abrir fotos del viaje';

  @override
  String trips_story_generateItineraryError(String error) {
    return 'No se pudo generar el itinerario: $error';
  }

  @override
  String get trips_dayType_diveDay => 'Día de buceo';

  @override
  String get trips_dayType_seaDay => 'Día de mar';

  @override
  String get trips_dayType_portDay => 'Día de puerto';

  @override
  String get trips_dayType_embark => 'Embarque';

  @override
  String get trips_dayType_disembark => 'Desembarque';

  @override
  String get trips_story_planned => 'Planificado';

  @override
  String get trips_story_empty_title => 'Aún no hay inmersiones ni itinerario';

  @override
  String get trips_story_empty_subtitle =>
      'Añade inmersiones o planifica los días para ver la historia.';

  @override
  String trips_story_history_dives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones previas aquí',
      one: '1 inmersión previa aquí',
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
      'Horarios de inmersión de este día';

  @override
  String get trips_story_map_semantics =>
      'Mapa del viaje. Los puntos del día visible están resaltados.';

  @override
  String get diveLog_bulkEdit_groupRebreather => 'Modo de buceo y rebreather';

  @override
  String get diveLog_bulkEdit_fieldSetpointLow => 'Setpoint bajo';

  @override
  String get diveLog_bulkEdit_fieldSetpointHigh => 'Setpoint alto';

  @override
  String get diveLog_bulkEdit_fieldSetpointDeco => 'Setpoint deco';

  @override
  String get diveLog_bulkEdit_fieldScrubberType => 'Tipo de filtro';

  @override
  String get diveLog_bulkEdit_fieldScrubberDuration => 'Duración del filtro';

  @override
  String get diveLog_bulkEdit_contradiction =>
      'El modo OC no admite ajustes de rebreather. Desactiva esos campos o cambia el modo.';

  @override
  String diveLog_bulkEdit_appBarTitle(int count) {
    return 'Editar $count inmersiones';
  }

  @override
  String get diveLog_bulkEdit_groupLogistics => 'Logística';

  @override
  String get diveLog_bulkEdit_groupWeather => 'Clima';

  @override
  String get diveLog_bulkEdit_groupCollections => 'Etiquetas, equipo y vida';

  @override
  String get diveLog_bulkEdit_fieldFavorite => 'Favorito';

  @override
  String get diveLog_bulkEdit_fieldMyRole => 'Mi rol';

  @override
  String get diveLog_bulkEdit_buddyRoleMixed => 'Variado';

  @override
  String get diveLog_bulkEdit_collectionWeights => 'Lastres';

  @override
  String get diveLog_bulkEdit_collectionTanks => 'Botellas';

  @override
  String get diveLog_bulkEdit_notesSet => 'Establecer';

  @override
  String get diveLog_bulkEdit_notesAppend => 'Añadir al final';

  @override
  String get diveLog_bulkEdit_modeAdd => 'Añadir';

  @override
  String get diveLog_bulkEdit_modeRemove => 'Quitar';

  @override
  String get diveLog_bulkEdit_modeReplace => 'Reemplazar';

  @override
  String get diveLog_bulkEdit_modeUpdate => 'Actualizar';

  @override
  String get diveLog_bulkEdit_tankOnlyIfEmpty =>
      'Solo inmersiones que aún no tienen botella';

  @override
  String get diveLog_bulkEdit_tankSpecsHint =>
      'Elige qué atributos sobrescribir en las botellas que estas inmersiones ya tienen. Las presiones inicial y final nunca se modifican.';

  @override
  String get diveLog_bulkEdit_tankSpecsNoFields =>
      'Elige al menos un atributo de botella para actualizar.';

  @override
  String get diveLog_bulkEdit_tankFieldPreset => 'Preajuste';

  @override
  String get diveLog_bulkEdit_tankFieldRole => 'Función';

  @override
  String get diveLog_bulkEdit_tankFieldVolume => 'Volumen';

  @override
  String get diveLog_bulkEdit_tankFieldWorkingPressure => 'Presión de trabajo';

  @override
  String get diveLog_bulkEdit_tankFieldMaterial => 'Material';

  @override
  String get diveLog_bulkEdit_tankFieldGasMix => 'Mezcla de gas';

  @override
  String get diveLog_bulkEdit_tankFieldName => 'Nombre';

  @override
  String diveLog_bulkEdit_tankSpecsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count inmersiones seleccionadas no tienen botellas y se omitirán.',
      one: '1 inmersión seleccionada no tiene botellas y se omitirá.',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_bulkEdit_confirmTitle => '¿Aplicar cambios?';

  @override
  String get diveLog_bulkEdit_confirmApply => 'Aplicar';

  @override
  String get diveLog_bulkEdit_nothingSelected =>
      'Activa al menos un campo para aplicar cambios.';

  @override
  String diveLog_bulkEdit_applied(int count) {
    return '$count inmersiones actualizadas';
  }

  @override
  String get settings_cloudSync_error_icloudSignedOut =>
      'iCloud no está disponible. Inicia sesión en iCloud en los ajustes de tu dispositivo.';

  @override
  String get settings_cloudSync_error_icloudUnknown =>
      'No se pudo conectar con iCloud. Inténtalo de nuevo.';

  @override
  String get settings_cloudSync_error_icloudUnsupported =>
      'La sincronización con iCloud no está disponible en esta versión de Submersion. Usa la sincronización S3 o la versión de la App Store.';

  @override
  String get settings_cloudSync_provider_icloud_unsupportedSubtitle =>
      'No disponible en esta versión: usa S3 o la versión de la App Store';

  @override
  String get settings_cloudSync_encryption_title =>
      'Cifrado de extremo a extremo';

  @override
  String get settings_cloudSync_encryption_subtitleOff =>
      'Cifrar todos los datos de sincronización y las copias en la nube antes de subirlos';

  @override
  String get settings_cloudSync_encryption_subtitleNeedsProvider =>
      'Selecciona primero un proveedor de nube';

  @override
  String get settings_cloudSync_encryption_statusOff =>
      'El cifrado está desactivado';

  @override
  String get settings_cloudSync_encryption_statusOn =>
      'El cifrado está activado';

  @override
  String get settings_cloudSync_encryption_statusOnSubtitle =>
      'Los datos de sincronización y las copias en la nube se cifran antes de subirse';

  @override
  String get settings_cloudSync_encryption_statusLocked =>
      'Cifrado — se necesita la frase de acceso';

  @override
  String get settings_cloudSync_encryption_statusLockedSubtitle =>
      'Introduce la frase de acceso para sincronizar en este dispositivo';

  @override
  String get settings_cloudSync_encryption_enable => 'Activar el cifrado';

  @override
  String get settings_cloudSync_encryption_enterPassphrase =>
      'Introducir frase de acceso';

  @override
  String get settings_cloudSync_encryption_passphrase => 'Frase de acceso';

  @override
  String get settings_cloudSync_encryption_passphraseConfirm =>
      'Confirmar frase de acceso';

  @override
  String get settings_cloudSync_encryption_passphraseMismatch =>
      'Las frases de acceso no coinciden';

  @override
  String get settings_cloudSync_encryption_passphraseTooShort =>
      'Usa al menos 8 caracteres';

  @override
  String get settings_cloudSync_encryption_wrongPassphrase =>
      'Frase de acceso o código de recuperación incorrectos';

  @override
  String get settings_cloudSync_encryption_warnUpdateDevices =>
      'Todos los demás dispositivos deben actualizarse a la última versión de la app y volverán a descargar la biblioteca.';

  @override
  String get settings_cloudSync_encryption_warnLoss =>
      'Si pierdes la frase de acceso y el código de recuperación, los datos en la nube no se podrán recuperar. Los datos en tus dispositivos nunca corren riesgo.';

  @override
  String get settings_cloudSync_encryption_deletePlaintextBackups =>
      'Eliminar las copias en la nube sin cifrar existentes';

  @override
  String get settings_cloudSync_encryption_recoveryTitle =>
      'Código de recuperación';

  @override
  String get settings_cloudSync_encryption_recoveryExplain =>
      'Apunta este código y guárdalo en un lugar seguro. Es la única forma de volver a entrar si olvidas la frase de acceso.';

  @override
  String get settings_cloudSync_encryption_recoverySavedConfirm =>
      'He guardado mi código de recuperación';

  @override
  String get settings_cloudSync_encryption_changePassphrase =>
      'Cambiar frase de acceso';

  @override
  String get settings_cloudSync_encryption_currentPassphrase =>
      'Frase de acceso actual';

  @override
  String get settings_cloudSync_encryption_newPassphrase =>
      'Nueva frase de acceso';

  @override
  String get settings_cloudSync_encryption_regenerateRecovery =>
      'Generar nuevo código de recuperación';

  @override
  String get settings_cloudSync_encryption_regenerateRecoveryWarn =>
      'El código de recuperación anterior deja de funcionar de inmediato.';

  @override
  String get settings_cloudSync_encryption_disable => 'Desactivar el cifrado';

  @override
  String get settings_cloudSync_encryption_disableWarn =>
      'La biblioteca se volverá a subir sin cifrar y los demás dispositivos la descargarán de nuevo. Las copias cifradas existentes siguen siendo restaurables con la frase de acceso.';

  @override
  String get settings_cloudSync_encryption_unlockTitle =>
      'Introduce tu frase de acceso de cifrado';

  @override
  String get settings_cloudSync_encryption_unlockHint =>
      'Frase de acceso o código de recuperación';

  @override
  String get settings_cloudSync_encryption_unlock => 'Desbloquear';

  @override
  String get settings_cloudSync_encryption_continue => 'Continuar';

  @override
  String get settings_cloudSync_encryption_done => 'Hecho';

  @override
  String get settings_cloudSync_encryption_cancel => 'Cancelar';

  @override
  String get settings_backupEncryption_title =>
      'Cifrado de copias de seguridad';

  @override
  String get settings_backupEncryption_subtitleOff =>
      'Protege tus copias de seguridad con una contraseña';

  @override
  String get settings_backupEncryption_subtitleOn =>
      'Las copias de seguridad se cifran con tu contraseña';

  @override
  String get settings_backupEncryption_enable => 'Cifrar copias de seguridad';

  @override
  String get settings_backupEncryption_turnOff => 'Desactivar el cifrado';

  @override
  String get settings_backupEncryption_turnOffTitle =>
      '¿Desactivar el cifrado de copias de seguridad?';

  @override
  String get settings_backupEncryption_turnOffBody =>
      'Las nuevas copias de seguridad ya no se cifrarán. Las copias de seguridad cifradas existentes seguirán necesitando tu contraseña para restaurarse.';

  @override
  String get settings_backupEncryption_changePassword => 'Cambiar contraseña';

  @override
  String get settings_backupEncryption_regenerateRecovery =>
      'Regenerar código de recuperación';

  @override
  String get settings_backupEncryption_password => 'Contraseña';

  @override
  String get settings_backupEncryption_passwordConfirm =>
      'Confirmar contraseña';

  @override
  String get settings_backupEncryption_passwordTooShort =>
      'Usa al menos 8 caracteres';

  @override
  String get settings_backupEncryption_passwordMismatch =>
      'Las contraseñas no coinciden';

  @override
  String get settings_backupEncryption_currentPassword => 'Contraseña actual';

  @override
  String get settings_backupEncryption_newPassword => 'Nueva contraseña';

  @override
  String get settings_backupEncryption_changePasswordWarn =>
      'En otro dispositivo, cada copia de seguridad se abre con la contraseña o el código de recuperación que estaba activo cuando se creó.';

  @override
  String get settings_backupEncryption_warnLoss =>
      'Si olvidas tu contraseña y pierdes el código de recuperación, las copias de seguridad cifradas no se podrán recuperar.';

  @override
  String get settings_backupEncryption_recoveryTitle =>
      'Tu código de recuperación';

  @override
  String get settings_backupEncryption_recoveryExplain =>
      'Guarda este código en un lugar seguro. Puede desbloquear tus copias de seguridad si olvidas tu contraseña.';

  @override
  String get settings_backupEncryption_recoverySavedConfirm =>
      'He guardado mi código de recuperación';

  @override
  String get settings_backupEncryption_unlockTitle =>
      'Introduce la contraseña de la copia de seguridad';

  @override
  String get settings_backupEncryption_unlockHint =>
      'Introduce tu contraseña de copia de seguridad o el código de recuperación';

  @override
  String get settings_backupEncryption_restoreUnlockTitle =>
      'Desbloquear copia de seguridad cifrada';

  @override
  String get settings_backupEncryption_restoreUnlockHint =>
      'Introduce la contraseña o el código de recuperación de esta copia de seguridad';

  @override
  String get settings_backupEncryption_continue => 'Continuar';

  @override
  String get settings_backupEncryption_cancel => 'Cancelar';

  @override
  String get settings_backupEncryption_done => 'Hecho';

  @override
  String get settings_backupEncryption_reencryptTitle =>
      '¿Cifrar las copias de seguridad existentes?';

  @override
  String get settings_backupEncryption_reencryptBody =>
      'Tus copias de seguridad existentes aún no están cifradas. ¿Volver a cifrarlas ahora con tu nueva contraseña?';

  @override
  String get settings_backupEncryption_reencryptNow => 'Volver a cifrar ahora';

  @override
  String get settings_backupEncryption_reencryptNotNow => 'Ahora no';

  @override
  String settings_backupEncryption_reencryptPartial(int done, int failed) {
    return 'Se volvieron a cifrar $done copias de seguridad; $failed no se pudieron cifrar y siguen sin protección';
  }

  @override
  String settings_backupEncryption_reencryptDone(int count) {
    return 'Se volvieron a cifrar $count copias de seguridad';
  }

  @override
  String get settings_backupEncryption_wrongPassword =>
      'Contraseña o código de recuperación incorrectos';

  @override
  String settings_cloudSync_replace_globalBanner(String deviceName) {
    return 'Sincronización en pausa: la biblioteca se reemplazó desde una copia de seguridad en \"$deviceName\".';
  }

  @override
  String get settings_cloudSync_postRestore_syncing =>
      'Sincronizando tu biblioteca restaurada con la nube…';

  @override
  String get settings_cloudSync_postRestore_synced =>
      'Biblioteca restaurada sincronizada.';

  @override
  String get settings_cloudSync_replace_reviewAction => 'Revisar';

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
  String get accessibility_label_resizeMasterPane =>
      'Cambiar el tamano del panel principal';

  @override
  String get accessibility_label_sharedWithAllProfiles =>
      'Compartido con todos los perfiles de buceo';

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
  String get backup_export_bottomSheet_title => 'Exportar Copia de Seguridad';

  @override
  String get backup_export_saveToFile => 'Guardar en Archivo';

  @override
  String get backup_export_saveToFile_subtitle =>
      'Elige donde guardar el archivo de copia de seguridad';

  @override
  String get backup_export_share => 'Compartir';

  @override
  String get backup_export_share_subtitle =>
      'Enviar por AirDrop, correo u otras apps';

  @override
  String get backup_export_subtitle =>
      'Guarda tus datos de buceo en un archivo';

  @override
  String get backup_export_success =>
      'Copia de seguridad exportada correctamente';

  @override
  String get backup_export_title => 'Exportar Copia de Seguridad';

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
  String get backup_history_pinAction_pin => 'Anclar copia de seguridad';

  @override
  String get backup_history_pinAction_unpin => 'Desanclar copia de seguridad';

  @override
  String get backup_history_pinError =>
      'No se pudo actualizar el estado de anclaje.';

  @override
  String backup_history_preMigrationSubtitle(String size) {
    return 'Copia previa a la migracion - $size';
  }

  @override
  String get backup_import_invalidFile =>
      'Este archivo no parece ser una copia de seguridad valida de Submersion';

  @override
  String get backup_import_subtitle =>
      'Importar una copia de seguridad desde cualquier ubicacion';

  @override
  String get backup_import_title => 'Restaurar desde Archivo';

  @override
  String get backup_import_validating =>
      'Validando archivo de copia de seguridad...';

  @override
  String get backup_location_change => 'Cambiar';

  @override
  String get backup_location_default => 'Ubicacion predeterminada';

  @override
  String get backup_location_title => 'Ubicación de Copia de Seguridad';

  @override
  String get backup_replaceConfirm_confirm => 'Reemplazar en todas partes';

  @override
  String get backup_replaceConfirm_content =>
      'La biblioteca de todos los dispositivos sincronizados se reemplazará con esta copia de seguridad. Cada dispositivo crea primero una copia de seguridad de sus datos actuales. Esto no se puede deshacer.';

  @override
  String get backup_replaceConfirm_title =>
      '¿Reemplazar la biblioteca en todas partes?';

  @override
  String get backup_restore_dialog_cancel => 'Cancelar';

  @override
  String get backup_restore_dialog_modeMerge_subtitle =>
      'Restaurar en este dispositivo. La próxima sincronización combinará los datos restaurados con la biblioteca en la nube.';

  @override
  String get backup_restore_dialog_modeMerge_title =>
      'Combinar en la próxima sincronización';

  @override
  String get backup_restore_dialog_modeReplace_subtitle =>
      'La copia de seguridad se convierte en la biblioteca en este dispositivo, en la nube y en todos los dispositivos sincronizados.';

  @override
  String get backup_restore_dialog_modeReplace_title =>
      'Reemplazar en todas partes';

  @override
  String get backup_restore_dialog_restore => 'Restaurar';

  @override
  String get backup_restore_dialog_restoreReplace =>
      'Restaurar y reemplazar en todas partes';

  @override
  String get backup_restore_dialog_safetyNote =>
      'Se creará automáticamente una copia de seguridad de sus datos actuales antes de restaurar.';

  @override
  String get backup_restore_dialog_title => 'Restaurar Copia';

  @override
  String get backup_restore_dialog_warning =>
      'Esto reemplazará TODOS los datos actuales con los datos de la copia. Esta acción no se puede deshacer.';

  @override
  String backup_restore_safetyReview_progress(int done, int total) {
    return 'Analizadas $done de $total inmersiones';
  }

  @override
  String get backup_restore_safetyReview_skip => 'Omitir';

  @override
  String get backup_restore_safetyReview_title =>
      'Ejecutando la revisión de seguridad';

  @override
  String get backup_restoreComplete_continue => 'Continuar';

  @override
  String get backup_restoreComplete_description =>
      'Sus datos han sido restaurados exitosamente. Toque continuar para recargar la app con sus datos restaurados.';

  @override
  String get backup_restoreComplete_title => 'Restauracion Completa';

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
  String get backup_section_auto => 'Copias de Seguridad Automaticas';

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
  String get buddies_action_addCertification => 'Añadir certificación';

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
  String get buddies_picker_addCustomRole => 'Agregar rol personalizado...';

  @override
  String get buddies_picker_addNew => 'Agregar Nuevo Compañero';

  @override
  String get buddies_picker_done => 'Listo';

  @override
  String get buddies_picker_me => 'Yo';

  @override
  String get buddies_picker_noBuddiesFound => 'No se encontraron compañeros';

  @override
  String get buddies_picker_noBuddiesYet => 'Aún no hay compañeros';

  @override
  String get buddies_picker_noRole => 'Sin rol';

  @override
  String get buddies_picker_noneSelected => 'Ningún compañero seleccionado';

  @override
  String get buddies_picker_searchHint => 'Buscar compañeros...';

  @override
  String get buddies_picker_selectBuddies => 'Seleccionar Compañeros';

  @override
  String get buddies_picker_selectMyRole => 'Seleccionar mi rol';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Seleccionar Rol para $name';
  }

  @override
  String get buddies_picker_setMyRole => 'Establecer mi rol';

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
  String get buddies_section_certifications => 'Certificaciones';

  @override
  String get buddies_certifications_empty => 'Sin certificaciones';

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
  String get buddies_list_selection_closeTooltip => 'Cerrar selección';

  @override
  String buddies_list_selection_count(int count) {
    return '$count seleccionado(s)';
  }

  @override
  String get buddies_list_selection_selectAllTooltip => 'Seleccionar todo';

  @override
  String get buddies_list_selection_deselectAllTooltip => 'Deseleccionar todo';

  @override
  String get buddies_list_selection_mergeTooltip => 'Combinar seleccionados';

  @override
  String get buddies_list_selection_deleteTooltip => 'Eliminar seleccionados';

  @override
  String buddies_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'compañeros',
      one: 'compañero',
    );
    return 'Se combinaron $count $_temp0';
  }

  @override
  String get buddies_list_merge_undo => 'Deshacer';

  @override
  String get buddies_list_merge_restored => 'Combinación deshecha';

  @override
  String get buddies_list_bulkDelete_title => 'Eliminar Compañeros';

  @override
  String buddies_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'compañeros',
      one: 'compañero',
    );
    return '¿Estás seguro de que deseas eliminar $count $_temp0? Esta acción no se puede deshacer.';
  }

  @override
  String get buddies_list_bulkDelete_cancel => 'Cancelar';

  @override
  String get buddies_list_bulkDelete_confirm => 'Eliminar';

  @override
  String buddies_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'compañeros',
      one: 'compañero',
    );
    return 'Se eliminaron $count $_temp0';
  }

  @override
  String get buddies_edit_merge_title => 'Combinar Compañeros';

  @override
  String get buddies_edit_merge_fieldSourceCycleTooltip =>
      'Usar valor del siguiente compañero seleccionado';

  @override
  String buddies_edit_merge_fieldSourceLabel(
    String buddyName,
    int current,
    int total,
  ) {
    return 'De $buddyName ($current/$total)';
  }

  @override
  String get buddies_edit_merge_confirmTitle => 'Combinar Compañeros';

  @override
  String buddies_edit_merge_confirmBody(int count) {
    return 'Esto combinará $count compañeros en uno. Las asociaciones de inmersiones se unirán bajo el compañero resultante. Los demás compañeros serán eliminados.';
  }

  @override
  String get buddies_edit_merge_loadingErrorTitle => 'Combinar Compañeros';

  @override
  String buddies_edit_merge_loadingErrorBody(String error) {
    return 'Error al cargar compañeros: $error';
  }

  @override
  String get buddies_edit_merge_notEnoughTitle => 'Combinar Compañeros';

  @override
  String get buddies_edit_merge_notEnoughBody =>
      'No hay suficientes compañeros para combinar.';

  @override
  String get buddies_instructorPicker_label =>
      'Instructor de la lista de compañeros';

  @override
  String get buddies_instructorPicker_none => 'Ninguno (entrada manual)';

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
  String get certifications_detail_label_certification => 'Certificación';

  @override
  String get certifications_detail_label_expiryDate => 'Fecha de vencimiento';

  @override
  String get certifications_detail_label_instructorName => 'Nombre';

  @override
  String get certifications_detail_label_instructorNumber => 'Instructor #';

  @override
  String get certifications_detail_label_issueDate => 'Fecha de emision';

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
  String get certifications_ecard_label_cardNumber => 'N.º DE TARJETA';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Certificado por $agency';
  }

  @override
  String get certifications_ecard_label_diver => 'BUCEADOR';

  @override
  String get certifications_ecard_label_instructor => 'INSTRUCTOR';

  @override
  String get certifications_ecard_label_issued => 'EMITIDO';

  @override
  String get certifications_ecard_label_validUntil => 'VÁLIDA HASTA';

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
  String get certifications_edit_certification_notSpecified =>
      'No especificado';

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
  String get certifications_edit_group_progression => 'Progresión';

  @override
  String get certifications_edit_group_specialties => 'Especialidades';

  @override
  String get certifications_edit_help_expiryDate =>
      'Deja vacio para certificaciones que no expiran';

  @override
  String get certifications_edit_helper_nameOnCard => 'Opcional';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Ingresa el numero de tarjeta de certificacion';

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
  String get certifications_edit_label_certification => 'Certificación';

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
  String get certifications_edit_label_nameOnCard => 'Nombre en la tarjeta';

  @override
  String get certifications_edit_label_notes => 'Notas';

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
  String get certifications_edit_validation_certificationOrNameRequired =>
      'Elige una certificación o introduce un nombre';

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
  String get checklists_section_title => 'Lista de verificación';

  @override
  String checklists_progress(int done, int total) {
    return '$done de $total tareas completadas';
  }

  @override
  String get checklists_empty_upcoming =>
      'Planifica tu viaje: agrega tareas o aplica una plantilla';

  @override
  String get checklists_empty_past =>
      'No hay elementos en la lista de verificación';

  @override
  String get checklists_addItem => 'Agregar elemento';

  @override
  String get checklists_item_titleLabel => 'Título';

  @override
  String get checklists_item_titleRequired => 'El título es obligatorio';

  @override
  String get checklists_item_categoryLabel => 'Categoría';

  @override
  String get checklists_item_notesLabel => 'Notas';

  @override
  String get checklists_item_dueDateLabel => 'Fecha límite';

  @override
  String get checklists_item_dueOffsetLabel =>
      'Días antes del inicio del viaje';

  @override
  String get checklists_item_dueOffsetInvalid => 'Ingresa 0 o más días';

  @override
  String get checklists_item_overdue => 'Vencido';

  @override
  String get checklists_item_edit => 'Editar elemento';

  @override
  String get checklists_item_delete => 'Eliminar elemento';

  @override
  String get checklists_menu_applyTemplate => 'Aplicar plantilla...';

  @override
  String get checklists_menu_saveAsTemplate => 'Guardar como plantilla...';

  @override
  String get checklists_applySheet_title => 'Aplicar plantilla';

  @override
  String get checklists_applySheet_empty =>
      'Aún no hay plantillas. Créalas en Ajustes.';

  @override
  String checklists_applySheet_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String checklists_applySheet_confirmAppend(int added, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Se agregarán $added elementos',
      one: 'Se agregará 1 elemento',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: 'se omitirán $skipped duplicados',
      one: 'se omitirá 1 duplicado',
      zero: 'no se omitirán duplicados',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String checklists_apply_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se agregaron $count elementos',
      one: 'Se agregó 1 elemento',
      zero: 'No se agregaron elementos nuevos',
    );
    return '$_temp0';
  }

  @override
  String get checklists_apply_templateGone => 'La plantilla ya no existe';

  @override
  String get checklists_saveTemplate_title => 'Guardar como plantilla';

  @override
  String get checklists_saveTemplate_nameLabel => 'Nombre de la plantilla';

  @override
  String get checklists_saveTemplate_success => 'Plantilla guardada';

  @override
  String get checklists_templates_pageTitle =>
      'Plantillas de listas de verificación';

  @override
  String get checklists_templates_addTemplate => 'Agregar plantilla';

  @override
  String get checklists_templates_empty => 'Aún no hay plantillas';

  @override
  String get checklists_templates_deleteTitle => 'Eliminar plantilla';

  @override
  String checklists_templates_deleteContent(Object name) {
    return '¿Eliminar \"$name\"? Los viajes que ya la aplicaron conservarán sus elementos.';
  }

  @override
  String get checklists_template_nameLabel => 'Nombre';

  @override
  String get checklists_template_nameRequired => 'El nombre es obligatorio';

  @override
  String get checklists_template_descriptionLabel => 'Descripción';

  @override
  String get checklists_template_itemsHeader => 'Elementos';

  @override
  String get checklists_template_addItem => 'Agregar elemento';

  @override
  String get preDive_templates_title => 'Listas previas a la inmersión';

  @override
  String get preDive_templates_empty =>
      'Aún no hay listas previas a la inmersión';

  @override
  String get preDive_templates_builtInBadge => 'Integrada';

  @override
  String get preDive_templates_clone => 'Duplicar';

  @override
  String get preDive_templates_cloneSuffix => ' (copia)';

  @override
  String get preDive_templates_delete => 'Eliminar';

  @override
  String get preDive_templates_deleteConfirm =>
      '¿Eliminar esta plantilla de lista de verificación?';

  @override
  String get preDive_templates_strictOrderBadge => 'Orden estricto';

  @override
  String get preDive_edit_titleNew => 'Nueva lista previa a la inmersión';

  @override
  String get preDive_edit_titleEdit => 'Editar lista previa a la inmersión';

  @override
  String get preDive_edit_name => 'Nombre';

  @override
  String get preDive_edit_description => 'Descripción';

  @override
  String get preDive_edit_category => 'Categoría';

  @override
  String get preDive_edit_strictOrder => 'Orden estricto';

  @override
  String get preDive_edit_strictOrderHelp =>
      'Los elementos deben completarse de arriba abajo';

  @override
  String get preDive_edit_addItem => 'Agregar elemento';

  @override
  String get preDive_edit_nameRequired => 'Introduce un nombre';

  @override
  String get preDive_item_title => 'Título';

  @override
  String get preDive_item_section => 'Sección';

  @override
  String get preDive_item_notes => 'Notas';

  @override
  String get preDive_item_required => 'Obligatorio';

  @override
  String get preDive_item_type_check => 'Casilla de verificación';

  @override
  String get preDive_item_type_value => 'Valor registrado';

  @override
  String get preDive_item_type_equipmentSet =>
      'Elementos del conjunto de equipo';

  @override
  String get preDive_item_valueLabel => 'Etiqueta del valor';

  @override
  String get preDive_item_valueUnit => 'Unidad';

  @override
  String get preDive_item_valueMin => 'Mín. (aviso)';

  @override
  String get preDive_item_valueMax => 'Máx. (aviso)';

  @override
  String preDive_runner_progress(int done, int total) {
    return '$done de $total';
  }

  @override
  String get preDive_runner_complete => 'Completar';

  @override
  String preDive_runner_completeFlagged(int count) {
    return '¿Completar con $count elementos marcados?';
  }

  @override
  String get preDive_runner_abort => 'Abandonar lista';

  @override
  String get preDive_runner_abortConfirm =>
      '¿Abandonar esta lista de verificación? Se conservará en el historial como abandonada.';

  @override
  String get preDive_runner_skip => 'Omitir';

  @override
  String get preDive_runner_flag => 'Marcar';

  @override
  String get preDive_runner_undo => 'Restablecer a pendiente';

  @override
  String get preDive_runner_serviceOverdue => 'Mantenimiento vencido';

  @override
  String get preDive_runner_addNote => 'Agregar nota';

  @override
  String get preDive_runner_enterValue => 'Introducir valor';

  @override
  String preDive_runner_flaggedBadge(int count) {
    return '$count marcados';
  }

  @override
  String get preDive_runner_locked =>
      'Esta lista de verificación está bloqueada';

  @override
  String get preDive_sessions_title => 'Listas previas a la inmersión';

  @override
  String get preDive_sessions_empty => 'Aún no hay listas ejecutadas';

  @override
  String get preDive_sessions_resume => 'Reanudar';

  @override
  String get preDive_sessions_start => 'Iniciar lista';

  @override
  String get preDive_sessions_statusCompleted => 'Completada';

  @override
  String get preDive_sessions_statusAborted => 'Abandonada';

  @override
  String get preDive_sessions_statusInProgress => 'En curso';

  @override
  String get preDive_sessions_linkedDive => 'Inmersión vinculada';

  @override
  String get preDive_link_linkToDive => 'Vincular a inmersión';

  @override
  String get preDive_link_unlinkDive => 'Desvincular inmersión';

  @override
  String get preDive_link_linkChecklist => 'Vincular lista previa';

  @override
  String get preDive_link_unlinkChecklist => 'Desvincular lista previa';

  @override
  String get preDive_link_searchDives => 'Buscar inmersiones';

  @override
  String get preDive_link_noDives => 'No hay inmersiones para vincular';

  @override
  String preDive_link_noDivesMatch(String query) {
    return 'Ninguna inmersión coincide con «$query»';
  }

  @override
  String get preDive_link_noUnlinkedSessions => 'No hay listas sin vincular';

  @override
  String get preDive_link_linked => 'Lista vinculada a esta inmersión';

  @override
  String get preDive_link_unlinked => 'Lista desvinculada de esta inmersión';

  @override
  String get preDive_sessions_delete => 'Eliminar';

  @override
  String get preDive_sessions_deleteConfirm =>
      '¿Eliminar este registro de lista de verificación?';

  @override
  String get preDive_sessions_filter => 'Filtrar';

  @override
  String get preDive_sessions_filterTitle => 'Filtrar listas realizadas';

  @override
  String get preDive_sessions_filterChecklist => 'Lista de verificación';

  @override
  String get preDive_sessions_filterStatus => 'Estado';

  @override
  String get preDive_sessions_filterFlaggedOnly => 'Solo con incidencias';

  @override
  String get preDive_sessions_filterDateRange => 'Intervalo de fechas';

  @override
  String get preDive_sessions_filterAnyDate => 'Cualquier fecha';

  @override
  String get preDive_sessions_filterClearAll => 'Borrar todo';

  @override
  String get preDive_sessions_filterApply => 'Aplicar';

  @override
  String get preDive_sessions_filterFlaggedChip => 'Solo incidencias';

  @override
  String get preDive_sessions_emptyFiltered =>
      'Ninguna lista coincide con estos filtros';

  @override
  String get preDive_sessions_export => 'Exportar a Excel';

  @override
  String get preDive_sessions_exportEmpty => 'No hay listas para exportar';

  @override
  String preDive_sessions_exportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get preDive_start_title => 'Iniciar lista previa a la inmersión';

  @override
  String get preDive_start_template => 'Lista de verificación';

  @override
  String get preDive_start_equipmentSet => 'Conjunto de equipo';

  @override
  String get preDive_start_noEquipmentSet => 'Ninguno';

  @override
  String get preDive_start_begin => 'Comenzar';

  @override
  String get diveLog_listPage_bottomSheet_preDiveChecklist =>
      'Iniciar lista previa a la inmersión';

  @override
  String get preDive_dashboard_title => 'Comprobación previa a la inmersión';

  @override
  String preDive_dashboard_resume(int done, int total) {
    return 'Reanudar - $done de $total';
  }

  @override
  String get preDive_dashboard_start =>
      'Iniciar comprobación previa a la inmersión';

  @override
  String get trips_detail_preDive_action => 'Lista previa a la inmersión';

  @override
  String get settings_manage_preDiveChecklists =>
      'Listas previas a la inmersión';

  @override
  String get settings_manage_preDiveChecklists_subtitle =>
      'Comprobaciones en pareja, listas de montaje CCR, preparación del equipo';

  @override
  String get common_action_back => 'Atrás';

  @override
  String get common_action_cancel => 'Cancelar';

  @override
  String get common_action_close => 'Cerrar';

  @override
  String get common_action_continue => 'Continuar';

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
  String get common_action_share => 'Compartir';

  @override
  String get common_label_error => 'Error';

  @override
  String get common_label_loading => 'Cargando';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get common_error_tryAgain => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get courses_action_add => 'Agregar Curso';

  @override
  String get courses_action_addFromTemplate => 'Agregar desde plantilla';

  @override
  String get courses_action_addRequirement => 'Agregar requisito';

  @override
  String get courses_action_create => 'Crear Curso';

  @override
  String get courses_action_deleteRequirement => 'Eliminar requisito';

  @override
  String get courses_action_edit => 'Editar curso';

  @override
  String get courses_action_editRequirement => 'Editar requisito';

  @override
  String get courses_action_exportTrainingLog =>
      'Exportar Registro de Entrenamiento';

  @override
  String get courses_action_linkDive => 'Vincular';

  @override
  String get courses_action_markCompleted => 'Marcar como Completado';

  @override
  String get courses_action_unlinkDive => 'Desvincular inmersión';

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
  String get courses_empty_button => 'Agrega tu primer curso de entrenamiento';

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
  String courses_requirement_diveProgress(int count, int target) {
    return '$count de $target inmersiones';
  }

  @override
  String get courses_requirement_field_name => 'Nombre';

  @override
  String get courses_requirement_field_targetCount => 'Inmersiones requeridas';

  @override
  String get courses_requirement_kind_checklist => 'Elemento de verificación';

  @override
  String get courses_requirement_kind_dive => 'Requisito de inmersión';

  @override
  String get courses_requirement_suggestions => 'Inmersiones sugeridas';

  @override
  String get courses_requirements_empty =>
      'Registra inmersiones de aventura, requisitos previos y elementos de verificación para este curso.';

  @override
  String courses_requirements_progress(int satisfied, int total) {
    return '$satisfied de $total completados';
  }

  @override
  String get courses_section_details => 'Detalles del Curso';

  @override
  String get courses_section_earnedCertification => 'Certificación Obtenida';

  @override
  String get courses_section_instructor => 'Instructor';

  @override
  String get courses_section_notes => 'Notas';

  @override
  String get courses_section_requirements => 'Requisitos';

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
  String courses_template_addsCount(int count) {
    return 'Agrega $count requisitos';
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
  String get dashboard_activeCourses_title => 'Cursos en progreso';

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
  String get dashboard_hero_divesTotalOne => '1 inmersión';

  @override
  String dashboard_hero_divesTotalOther(Object count) {
    return '$count inmersiones';
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
  String get dashboard_hero_divesLoggedLabel => 'inmersiones registradas';

  @override
  String get dashboard_hero_hoursUnderwaterLabel => 'horas bajo el agua';

  @override
  String get dashboard_hero_daysSinceLabel => 'días desde última inmersión';

  @override
  String get dashboard_hero_thisMonthLabel => 'este mes';

  @override
  String get dashboard_hero_thisYearLabel => 'inmersiones este año';

  @override
  String get dashboard_hero_todayLabel => '¡hoy!';

  @override
  String get dashboard_hero_noDivesLabel => 'sin inmersiones aún';

  @override
  String get dashboard_hero_diverFallbackName => 'Buzo';

  @override
  String get dashboard_hero_statDives => 'inmersiones';

  @override
  String get dashboard_hero_statHours => 'horas';

  @override
  String get dashboard_hero_statSites => 'sitios';

  @override
  String get dashboard_hero_statCountries => 'países';

  @override
  String dashboard_activityStats_divesInYear(String year) {
    return 'inmersiones en $year';
  }

  @override
  String get dashboard_semantics_statsBar => 'Resumen de estadísticas de buceo';

  @override
  String get dashboard_gauges_addGear => 'Añadir equipo';

  @override
  String dashboard_gauges_gearOk(String name) {
    return '$name OK';
  }

  @override
  String dashboard_gauges_gearDueIn(String name, int days) {
    return '$name vence en ${days}d';
  }

  @override
  String dashboard_gauges_gearOverdue(String name) {
    return '$name con servicio vencido';
  }

  @override
  String get dashboard_gauges_insuranceOk => 'Seguro OK';

  @override
  String dashboard_gauges_insuranceExpires(String date) {
    return 'El seguro vence $date';
  }

  @override
  String get dashboard_gauges_insuranceExpired => 'Seguro vencido';

  @override
  String get dashboard_gauges_noInsurance => 'Sin seguro registrado';

  @override
  String get dashboard_gauges_noFlyClear => 'No volar 0:00';

  @override
  String dashboard_gauges_flightWindow(String hours, String minutes) {
    return 'Ventana de buceo $hours:$minutes';
  }

  @override
  String get dashboard_gauges_flightWindowClosed =>
      'No más buceo antes del vuelo';

  @override
  String dashboard_gauges_noFlyRemaining(String hours, String minutes) {
    return 'No volar $hours:$minutes';
  }

  @override
  String dashboard_gauges_lastDiveDays(int days) {
    return 'Última inmersión hace ${days}d';
  }

  @override
  String get dashboard_gauges_lastDiveToday => 'Buceaste hoy';

  @override
  String get dashboard_gauges_noDivesYet => 'Aún sin inmersiones';

  @override
  String get settings_homeChips_pageTitle => 'Pantalla de inicio';

  @override
  String get settings_homeChips_description =>
      'Elige qué chips de estado aparecen en la parte superior de la pestaña Inicio.';

  @override
  String get settings_homeChips_sectionTitle => 'Chips de estado';

  @override
  String get settings_homeCards_sectionTitle => 'Tarjetas de Inicio';

  @override
  String get settings_homeCards_description =>
      'Elige qué tarjetas aparecen en la pestaña Inicio y arrástralas para reordenarlas.';

  @override
  String get settings_homeCards_autoHides =>
      'Se oculta automáticamente cuando está vacía';

  @override
  String get settings_homeCards_resetToDefault =>
      'Restablecer valores predeterminados';

  @override
  String get settings_homeCards_resetDialog_title =>
      '¿Restablecer el diseño de Inicio?';

  @override
  String get settings_homeCards_resetDialog_message =>
      'Restaura el orden predeterminado de las tarjetas y vuelve a mostrarlas todas.';

  @override
  String get settings_homeCards_resetDialog_cancel => 'Cancelar';

  @override
  String get settings_homeCards_resetDialog_confirm => 'Restablecer';

  @override
  String get settings_homeCards_card_hero => 'Cabecera de bienvenida';

  @override
  String get settings_homeCards_card_gaugeStrip => 'Chips de estado';

  @override
  String get settings_homeCards_card_preDive => 'Lista previa a la inmersión';

  @override
  String get settings_homeCards_card_recentDives => 'Inmersiones recientes';

  @override
  String get settings_homeCards_card_quickActions => 'Acciones rápidas';

  @override
  String get settings_homeCards_card_milestones => 'Hitos';

  @override
  String get settings_homeCards_card_photoRibbon => 'Medios recientes';

  @override
  String get settings_homeCards_card_onThisDay => 'Tal día como hoy';

  @override
  String get settings_homeCards_card_yearInReview => 'Resumen del año';

  @override
  String get settings_homeCards_card_activeCourses => 'Progreso del curso';

  @override
  String get settings_homeCards_card_recentSitesMap =>
      'Mapa de puntos recientes';

  @override
  String get dashboard_allHidden_message =>
      'Todas las tarjetas de Inicio están ocultas.';

  @override
  String get dashboard_allHidden_customize => 'Personalizar Inicio';

  @override
  String get settings_homeChips_flightWindow =>
      'Ventana de buceo antes del vuelo';

  @override
  String get settings_homeChips_gear => 'Mantenimiento del equipo';

  @override
  String get settings_homeChips_insurance => 'Seguro';

  @override
  String get settings_homeChips_noFly => 'Temporizador de no volar';

  @override
  String get settings_homeChips_lastDive => 'Vigencia de buceo';

  @override
  String get settings_homeChips_certifications =>
      'Vencimiento de certificaciones';

  @override
  String get settings_homeChips_trip => 'Próximo viaje';

  @override
  String get settings_homeChips_checklist => 'Lista de verificación activa';

  @override
  String get settings_homeChips_course => 'Progreso del curso';

  @override
  String get settings_homeChips_uploads => 'Subidas de medios';

  @override
  String get settings_homeChips_backup => 'Antigüedad de la copia';

  @override
  String get settings_homeChips_sync => 'Estado de sincronización';

  @override
  String get settings_homeChips_dataQuality => 'Calidad de datos';

  @override
  String dashboard_gauges_certsExpiring(int count) {
    return '$count certificaciones por vencer';
  }

  @override
  String dashboard_gauges_tripCountdown(String name, int days) {
    return '$name en ${days}d';
  }

  @override
  String get dashboard_gauges_checklistActive =>
      'Lista de verificación en curso';

  @override
  String dashboard_gauges_courseProgress(String name, int done, int total) {
    return '$name: $done/$total';
  }

  @override
  String dashboard_gauges_uploadsPending(int count) {
    return '$count subidas pendientes';
  }

  @override
  String get dashboard_gauges_backupNone => 'Sin copia de seguridad';

  @override
  String get dashboard_gauges_backupToday => 'Copia hecha hoy';

  @override
  String dashboard_gauges_backupDays(int days) {
    return 'Copia hace ${days}d';
  }

  @override
  String dashboard_gauges_syncPending(int count) {
    return '$count sin sincronizar';
  }

  @override
  String get dashboard_gauges_synced => 'Sincronizado';

  @override
  String dashboard_gauges_dataIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemas de datos',
      one: '1 problema de datos',
    );
    return '$_temp0';
  }

  @override
  String get dashboard_gauges_retry =>
      'Estado no disponible - toca para reintentar';

  @override
  String get dashboard_urgent_title => 'Requiere atención';

  @override
  String get dashboard_media_title => 'Medios recientes';

  @override
  String get dashboard_recentSites_title => 'Sitios recientes';

  @override
  String get dashboard_yearInReview_title => 'Este año';

  @override
  String dashboard_yearInReview_divesVs(int count, int previous) {
    return '$count inmersiones (frente a $previous el año pasado)';
  }

  @override
  String dashboard_yearInReview_hours(String hours) {
    return '$hours horas bajo el agua';
  }

  @override
  String dashboard_yearInReview_maxDepth(String depth) {
    return 'Máxima: $depth';
  }

  @override
  String get dashboard_onThisDay_title => 'Tal día como hoy';

  @override
  String dashboard_onThisDay_entry(String year, String site) {
    return '$year - $site';
  }

  @override
  String get dashboard_milestones_title => 'Hitos';

  @override
  String dashboard_milestones_nextDive(int remaining, int milestone) {
    return '$remaining inmersiones para la n.º $milestone';
  }

  @override
  String dashboard_milestones_certYears(String name, int years, String month) {
    return '$name: $years años en $month';
  }

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
  String get dashboard_recentDives_latestProfileTitle =>
      'Perfil de la última inmersión';

  @override
  String get dashboard_recentDives_noProfileData =>
      'Sin datos de perfil para esta inmersión';

  @override
  String get dashboard_recentDives_profileLoadError =>
      'No se pudo cargar el perfil de inmersión';

  @override
  String dashboard_recentDives_profileMinutes(int minutes) {
    return '$minutes min';
  }

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
  String get decoCalculator_waterType => 'Tipo de agua';

  @override
  String get decoCalculator_waterType_standard => 'Estándar';

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
  String get diveCenters_empty_button => 'Agrega tu primer centro de buceo';

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
  String get diveLog_combine_confirm => 'Combinar en una inmersión';

  @override
  String get diveLog_combine_dataNote =>
      'Los detalles provienen de la inmersión más antigua, y los espacios en blanco se completan con inmersiones posteriores. Las notas se combinan. Se conservan todos los tanques, el equipo, los compañeros, las etiquetas y los avistamientos.';

  @override
  String get diveLog_combine_error =>
      'No se pudieron combinar las inmersiones. No se realizó ningún cambio.';

  @override
  String diveLog_combine_gapLabel(String duration) {
    return 'Intervalo de superficie: $duration';
  }

  @override
  String get diveLog_combine_longSurfaceWarning =>
      'Uno o más intervalos de superficie superan los 30 minutos. Podrían ser inmersiones separadas en lugar de una sola inmersión continua.';

  @override
  String get diveLog_combine_mixedDivers =>
      'Las inmersiones seleccionadas pertenecen a buceadores diferentes y no se pueden combinar.';

  @override
  String get diveLog_combine_profilePreview => 'Perfil combinado';

  @override
  String diveLog_combine_previewIntro(int count) {
    return 'Estas $count inmersiones se combinarán en una sola inmersión continua. Los intervalos entre ellas se convertirán en tiempo en superficie.';
  }

  @override
  String diveLog_combine_resultSummary(
    String runtime,
    String maxDepth,
    String bottomTime,
  ) {
    return 'Resultado: $runtime en total, profundidad máxima $maxDepth, tiempo de fondo $bottomTime';
  }

  @override
  String diveLog_combine_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se combinaron $count inmersiones',
      one: 'Se combinó $count inmersión',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_combine_title => 'Combinar inmersiones';

  @override
  String get diveLog_combine_undoError => 'No se pudo deshacer la combinación.';

  @override
  String get diveLog_combine_undone => 'Combinación deshecha';

  @override
  String get diveLog_computerSource_badge_primary => 'Principal';

  @override
  String get diveLog_consolidate_confirm =>
      'Mantener como una sola inmersión con ambos ordenadores';

  @override
  String get diveLog_consolidate_error_generic =>
      'No se pudieron fusionar las inmersiones. No se realizó ningún cambio.';

  @override
  String get diveLog_consolidate_error_notOverlapping =>
      'Estas inmersiones no se superponen en el tiempo, por lo que no se pueden fusionar como la misma inmersión.';

  @override
  String get diveLog_consolidate_error_sameComputer =>
      'Estas inmersiones son del mismo ordenador de buceo y no se pueden fusionar de esta manera.';

  @override
  String get diveLog_consolidate_selectPrimary =>
      'Ordenador de buceo principal';

  @override
  String get diveLog_consolidate_snackbar =>
      'Inmersión fusionada como ordenador adicional.';

  @override
  String get diveLog_consolidate_undoError => 'No se pudo deshacer la fusión.';

  @override
  String get diveLog_consolidate_undone => 'Fusión deshecha';

  @override
  String diveLog_mergeDialog_confirmSubtitle(String time) {
    return 'Se fusionará la inmersión de las $time con esta inmersión.';
  }

  @override
  String get diveLog_mergeDialog_confirmTitle => 'Confirmar fusión';

  @override
  String get diveLog_mergeDialog_empty =>
      'No se encontraron otras inmersiones en este día.';

  @override
  String get diveLog_mergeDialog_explanation =>
      'El perfil, los tanques, las presiones, los eventos, las etiquetas, los compañeros y los avistamientos de esta inmersión se incorporarán a esta inmersión como un ordenador adicional. Esta acción se puede revertir con \'Desvincular ordenador\'.';

  @override
  String diveLog_mergeDialog_loadError(String error) {
    return 'Error al cargar las inmersiones: $error';
  }

  @override
  String get diveLog_mergeDialog_merge => 'Fusionar';

  @override
  String get diveLog_mergeDialog_next => 'Siguiente';

  @override
  String get diveLog_mergeDialog_subtitle =>
      'Selecciona una inmersión del mismo día para fusionarla como ordenador adicional.';

  @override
  String get diveLog_mergeDialog_title => 'Fusionar con otra inmersión';

  @override
  String get diveLog_mergeDialog_whatThisDoes => 'Qué hace esto';

  @override
  String get diveLog_computerSheet_description =>
      'Selecciona desde qué perfil de ordenador editar.';

  @override
  String get diveLog_computerSheet_title => 'Elegir perfil inicial';

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
  String get diveLog_deco_label_gf99 => 'GF99';

  @override
  String get diveLog_deco_label_surfGf => 'SurfGF';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_time => 'Tiempo';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String diveLog_deco_gf_chip(Object low, Object high) {
    return 'GF: $low/$high';
  }

  @override
  String diveLog_deco_gf_chipFromSettings(Object low, Object high) {
    return 'GF: $low/$high · tus ajustes';
  }

  @override
  String diveLog_deco_gf_chipRecordedAlgorithm(
    Object algorithm,
    Object low,
    Object high,
  ) {
    return '$algorithm · analizado con GF $low/$high';
  }

  @override
  String diveLog_deco_gf_semantics(Object low, Object high) {
    return 'Factores de gradiente: bajo $low, alto $high';
  }

  @override
  String get diveLog_deco_gf_tooltipFromSettings =>
      'Este ordenador de buceo no registró sus factores de gradiente, así que esta inmersión se analiza con los de tus ajustes.';

  @override
  String diveLog_deco_gf_tooltipRecordedAlgorithm(Object algorithm) {
    return 'Esta inmersión se calculó con $algorithm, que no usa factores de gradiente. Submersion la analiza con los de tus ajustes.';
  }

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
  String get diveLog_deco_title => 'Estado deco';

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
  String get diveLog_detail_button_rangeAnalysis => 'Stats de rango';

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
  String get diveLog_detail_label_serialNumber => 'Numero de serie';

  @override
  String get diveLog_detail_label_firmwareVersion => 'Version de firmware';

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
  String get diveLog_detail_section_decoStatus => 'Estado deco';

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
  String get diveLog_detail_section_sacRateBySegment =>
      'Consumo SAC por segmento';

  @override
  String get diveLog_detail_section_tags => 'Etiquetas';

  @override
  String get diveLog_detail_section_cylinders => 'Tanques';

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
  String get diveLog_detail_tideCalculated =>
      'Calculado a partir del modelo de mareas';

  @override
  String get diveLog_detail_tooltip_addToFavorites => 'Agregar a favoritos';

  @override
  String get diveLog_detail_tooltip_edit => 'Editar';

  @override
  String get diveLog_detail_tooltip_editDive => 'Editar inmersión';

  @override
  String get diveLog_detail_tooltip_previousDive => 'Previous dive';

  @override
  String get diveLog_detail_tooltip_nextDive => 'Next dive';

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
  String get diveLog_diveMode_gaugeDescription =>
      'Solo profundidad y tiempo; sin seguimiento de gas ni descompresión';

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
  String get diveLog_edit_group_buddies => 'Compañeros';

  @override
  String get diveLog_edit_group_conditions => 'Condiciones';

  @override
  String get diveLog_edit_group_experience => 'Experiencia';

  @override
  String get diveLog_edit_group_gasGear => 'Gas y equipo';

  @override
  String get diveLog_edit_group_theDive => 'La inmersión';

  @override
  String get diveLog_edit_group_trip => 'Viaje';

  @override
  String get diveLog_edit_headerNew => 'Registrar nueva inmersión';

  @override
  String get diveLog_edit_invite_buddies => 'Añadir compañeros';

  @override
  String get diveLog_edit_invite_conditions =>
      'Añadir condiciones: agua, visibilidad, clima';

  @override
  String get diveLog_edit_invite_experience =>
      'Añadir valoración, avistamientos, notas o etiquetas';

  @override
  String get diveLog_edit_invite_gasGear =>
      'Añadir gas y equipo: modo, botellas, equipo, lastre';

  @override
  String get diveLog_edit_invite_trip => 'Añadir viaje o centro de buceo';

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
  String get diveLog_edit_label_diveTypes => 'Tipos de inmersión';

  @override
  String get diveLog_edit_label_diveNumber => 'Nro. de inmersión';

  @override
  String get diveLog_edit_label_diveName => 'Nombre';

  @override
  String get diveLog_edit_diveNamePlaceholder =>
      'Nombre opcional para esta inmersión';

  @override
  String get diveLog_edit_hint_diveNumber =>
      'Se asigna automáticamente si se deja en blanco';

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
  String get diveLog_edit_overline_tanks => 'Botellas';

  @override
  String get diveLog_edit_profile_draw => 'Dibujar un perfil';

  @override
  String get diveLog_edit_profile_none => 'No registrado';

  @override
  String diveLog_edit_profile_outliers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posibles valores atípicos detectados',
      one: '1 posible valor atípico detectado',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_profile_points(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puntos',
      one: '1 punto',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_row_addSite => 'Añadir punto';

  @override
  String get diveLog_edit_row_diveCenter => 'Centro de buceo';

  @override
  String get diveLog_edit_row_diveProfile => 'Perfil de inmersión';

  @override
  String get diveLog_edit_row_entry => 'Entrada';

  @override
  String get diveLog_edit_row_exit => 'Salida';

  @override
  String get diveLog_edit_row_notSet => 'Sin definir';

  @override
  String get diveLog_edit_row_site => 'Punto de buceo';

  @override
  String get diveLog_edit_row_surfaceInterval => 'Intervalo en superficie';

  @override
  String get diveLog_edit_row_trip => 'Viaje';

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
  String diveLog_edit_snackbar_avgDepthCalculated(Object depth) {
    return 'Profundidad media calculada: $depth';
  }

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Tiempo de fondo calculado: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Error al guardar la inmersión: $error';
  }

  @override
  String diveLog_edit_snackbar_maxDepthCalculated(Object depth) {
    return 'Profundidad maxima calculada: $depth';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'No hay datos de perfil de inmersión disponibles';

  @override
  String diveLog_edit_snackbar_runtimeCalculated(Object minutes) {
    return 'Tiempo de inmersion calculado: $minutes min';
  }

  @override
  String get diveLog_edit_snackbar_unableToCalculateAvgDepth =>
      'No se pudo calcular la profundidad media a partir del perfil';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'No se pudo calcular el tiempo de fondo a partir del perfil';

  @override
  String get diveLog_edit_snackbar_unableToCalculateMaxDepth =>
      'No se pudo calcular la profundidad maxima a partir del perfil';

  @override
  String get diveLog_edit_snackbar_unableToCalculateRuntime =>
      'No se pudo calcular el tiempo de inmersion a partir del perfil';

  @override
  String diveLog_edit_summary_items(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_summary_notes => 'notas';

  @override
  String diveLog_edit_summary_species(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count especies',
      one: '1 especie',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_summary_tanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count botellas',
      one: '1 botella',
    );
    return '$_temp0';
  }

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
  String get diveLog_edit_tankCard_done => 'Listo';

  @override
  String get diveLog_edit_tankCard_edit => 'Editar';

  @override
  String get diveLog_edit_tankCard_mix => 'Mezcla';

  @override
  String get diveLog_edit_tankCard_pressure => 'Presión';

  @override
  String diveLog_edit_tankCard_title(int number) {
    return 'Botella $number';
  }

  @override
  String get diveLog_edit_tankCard_volume => 'Volumen';

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
  String diveLog_equipmentSetPicker_itemsSummary(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
    );
    return '$_temp0: $names';
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
  String get diveLog_filterChip_noBuddy => 'Sin compañero';

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
  String get diveLog_filter_clearWeekdays => 'Borrar días de la semana';

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
  String get diveLog_filter_noBuddyOnly => 'Sin compañero asignado';

  @override
  String get diveLog_filter_noTagsYet => 'Aún no se han creado etiquetas';

  @override
  String get diveLog_filter_presetAllTime => 'Todo el tiempo';

  @override
  String get diveLog_filter_presetLast12Months => 'Últimos 12 meses';

  @override
  String get diveLog_filter_presetLastYear => 'Año pasado';

  @override
  String get diveLog_filter_presetThisYear => 'Este año';

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
  String get diveLog_filter_sectionWeekdays => 'Días de la semana';

  @override
  String get diveLog_filter_showOnlyFavorites =>
      'Mostrar solo inmersiones favoritas';

  @override
  String get diveLog_filter_showOnlyNoBuddy =>
      'Mostrar solo inmersiones sin compañero';

  @override
  String get diveLog_filter_startDate => 'Fecha de inicio';

  @override
  String get diveLog_filter_title => 'Filtrar inmersiones';

  @override
  String get diveLog_filter_resizeGrip =>
      'Cambiar el tamaño del panel de filtros';

  @override
  String get diveLog_filter_tooltip_close => 'Cerrar filtro';

  @override
  String get diveLog_fullscreenProfile_close => 'Cerrar pantalla completa';

  @override
  String get diveLog_fullscreenProfile_readoutHint =>
      'Pasa el cursor o desliza sobre el perfil';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Perfil de inmersión #$number';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Velocidad de ascenso';

  @override
  String get diveLog_legend_label_ascentRateLine =>
      'Linea de velocidad de ascenso';

  @override
  String get diveLog_legend_label_ceiling => 'Techo';

  @override
  String get diveLog_legend_label_decoStops => 'Deco stops';

  @override
  String get diveLog_legend_label_cns => 'CNS%';

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
  String get diveLog_legend_label_otu => 'OTU';

  @override
  String get diveLog_legend_label_photoMarkers => 'Fotos';

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
  String get diveLog_legend_label_showGas => 'Gases';

  @override
  String get diveLog_legend_label_surfaceGf => 'GF en superficie';

  @override
  String get diveLog_legend_label_temp => 'Temp';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_legend_source_dc => 'DC';

  @override
  String get diveLog_legend_source_calc => 'Calc.';

  @override
  String get diveLog_chartSection_overlays => 'Superposiciones';

  @override
  String get diveLog_chartSection_markers => 'Marcadores';

  @override
  String get diveLog_chartSection_decompression => 'Descompresion';

  @override
  String get diveLog_chartSection_gasAnalysis => 'Analisis de gases';

  @override
  String get diveLog_chartSection_display => 'Visualización';

  @override
  String get diveLog_chartSection_other => 'Otros';

  @override
  String get diveLog_chartSection_tankPressures => 'Presiones de botellas';

  @override
  String get diveLog_chartOption_metricsFollowViewport =>
      'Mantener las superposiciones a la vista';

  @override
  String get diveLog_pressure_estimatedSuffix => '(est.)';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Mapa de inmersiones';

  @override
  String get diveLog_listPage_compactTitle => 'Inmersiones';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Error: $error';
  }

  @override
  String get diveLog_listPage_bottomSheet_importFromComputer =>
      'Importar desde ordenador de buceo';

  @override
  String get diveLog_listPage_bottomSheet_scanPaperLog =>
      'Escanear registro en papel';

  @override
  String get ocrImport_scanPage_processing => 'Leyendo la página...';

  @override
  String get ocrImport_scanPage_pickPhoto => 'Elegir foto';

  @override
  String get ocrImport_scanPage_takePhoto => 'Tomar foto';

  @override
  String get ocrImport_scanPage_nothingRead =>
      'No se pudo leer mucho de esta página - los campos quedaron vacíos';

  @override
  String get ocrImport_scanPage_engineMissing =>
      'El reconocimiento de texto no está disponible. Instala Tesseract para escanear registros en papel (por ejemplo: sudo apt install tesseract-ocr).';

  @override
  String get ocrImport_editPage_photoAttachFailed =>
      'La inmersión se guardó, pero no se pudo adjuntar la página escaneada';

  @override
  String get diveLog_listPage_bottomSheet_logManually =>
      'Registrar inmersion manualmente';

  @override
  String get diveLog_listPage_fab_addDive => 'Agregar inmersion';

  @override
  String get diveLog_listPage_fab_logDive => 'Registrar inmersión';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Búsqueda avanzada';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Numeración de inmersiones';

  @override
  String get diveLog_listPage_menuMatchSites =>
      'Asociar inmersiones a puntos de buceo';

  @override
  String get diveLog_sighting_decreaseCount => 'Disminuir cantidad';

  @override
  String get diveLog_sighting_increaseCount => 'Aumentar cantidad';

  @override
  String diveLog_speciesPicker_errorLoading(String error) {
    return 'Error al cargar especies: $error';
  }

  @override
  String get diveRole_builtin_buddy => 'Compañero';

  @override
  String get diveRole_builtin_diveGuide => 'Guía de buceo';

  @override
  String get diveRole_builtin_diveMaster => 'Divemaster';

  @override
  String get diveRole_builtin_instructor => 'Instructor';

  @override
  String get diveRole_builtin_rearGuard => 'Guía de cola';

  @override
  String get diveRole_builtin_safetyDiver => 'Buzo de seguridad';

  @override
  String get diveRole_builtin_solo => 'Solo';

  @override
  String get diveRole_builtin_student => 'Estudiante';

  @override
  String get diveRole_builtin_supportDiver => 'Buzo de apoyo';

  @override
  String get diveRoles_addDialog_addButton => 'Agregar';

  @override
  String get diveRoles_addDialog_nameHint => 'ej., Fotógrafo';

  @override
  String get diveRoles_addDialog_nameLabel => 'Nombre del Rol de Buceo';

  @override
  String get diveRoles_addDialog_nameValidation =>
      'Por favor ingresa un nombre';

  @override
  String get diveRoles_addDialog_title => 'Agregar Rol de Buceo Personalizado';

  @override
  String get diveRoles_addTooltip => 'Agregar rol de buceo';

  @override
  String get diveRoles_appBar_title => 'Roles de Buceo';

  @override
  String get diveRoles_builtInHeader => 'Roles de Buceo Integrados';

  @override
  String get diveRoles_customHeader => 'Roles de Buceo Personalizados';

  @override
  String diveRoles_deleteDialog_content(Object name) {
    return '¿Estás seguro de que deseas eliminar \"$name\"?';
  }

  @override
  String get diveRoles_deleteDialog_title => '¿Eliminar Rol de Buceo?';

  @override
  String get diveRoles_deleteTooltip => 'Eliminar rol de buceo';

  @override
  String get diveRoles_renameDialog_title => 'Renombrar Rol de Buceo';

  @override
  String get diveRoles_renameTooltip => 'Renombrar rol de buceo';

  @override
  String diveRoles_snackbar_added(Object name) {
    return 'Rol de buceo agregado: $name';
  }

  @override
  String diveRoles_snackbar_cannotDelete(Object name) {
    return 'No se puede eliminar \"$name\" - está siendo usado por inmersiones existentes';
  }

  @override
  String diveRoles_snackbar_deleted(Object name) {
    return 'Rol de buceo eliminado: $name';
  }

  @override
  String diveRoles_snackbar_errorAdding(Object error) {
    return 'Error al agregar rol de buceo: $error';
  }

  @override
  String get diveSites_edit_depth_heroMax => 'Prof. máx.';

  @override
  String get diveSites_edit_depth_heroMin => 'Prof. mín.';

  @override
  String get diveSites_edit_group_accessSafety => 'Acceso y seguridad';

  @override
  String get diveSites_edit_group_diveInfo => 'Datos de buceo';

  @override
  String get diveSites_edit_group_identity => 'Identidad';

  @override
  String get diveSites_edit_group_lifeNotes => 'Vida marina y notas';

  @override
  String get diveSites_edit_group_location => 'Ubicación';

  @override
  String get diveSites_edit_invite_accessSafety =>
      'Añadir acceso, aparcamiento, amarre o peligros';

  @override
  String get diveSites_edit_invite_diveInfo =>
      'Añadir rango de profundidad, dificultad o valoración';

  @override
  String get diveSites_edit_invite_lifeNotes =>
      'Añadir vida marina, notas o compartir';

  @override
  String get diveSites_edit_invite_location => 'Añadir posición GPS o altitud';

  @override
  String get diveSites_edit_summary_shared => 'compartido';

  @override
  String get forms_addSection_prefix => 'Añadir:';

  @override
  String get forms_cancel => 'Cancelar';

  @override
  String get forms_discard_body =>
      'Tienes cambios sin guardar. Si sales ahora, se perderán.';

  @override
  String get forms_discard_discard => 'Descartar';

  @override
  String get forms_discard_keepEditing => 'Seguir editando';

  @override
  String get forms_discard_title => '¿Descartar los cambios?';

  @override
  String get forms_save => 'Guardar';

  @override
  String forms_section_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemas',
      one: '1 problema',
    );
    return '$_temp0';
  }

  @override
  String get settings_manage_setupAssistant => 'Asistente de configuración';

  @override
  String get settings_manage_setupAssistant_subtitle =>
      'Revisa unidades, apariencia y opciones de copia de seguridad';

  @override
  String get setup_backup_cloudCopy =>
      'Almacena copias de seguridad en la nube';

  @override
  String get setup_backup_frequency => 'Frecuencia';

  @override
  String get setup_backup_frequency_daily => 'Diaria';

  @override
  String get setup_backup_frequency_monthly => 'Mensual';

  @override
  String get setup_backup_frequency_weekly => 'Semanal';

  @override
  String get setup_backup_scheduleSubtitle =>
      'Haz copias de seguridad de tus datos según una programación';

  @override
  String get setup_backup_scheduleToggle => 'Copias de seguridad automáticas';

  @override
  String get setup_backup_subtitle => 'Protege tus datos desde el primer día.';

  @override
  String get setup_backup_title => 'Copias de seguridad y sincronización';

  @override
  String get setup_common_back => 'Atrás';

  @override
  String get setup_common_next => 'Siguiente';

  @override
  String get setup_common_skip => 'Omitir';

  @override
  String get setup_existing_folder_subtitle =>
      'Apunta Submersion a una carpeta que ya contiene una biblioteca';

  @override
  String get setup_existing_folder_title => 'Abrir una carpeta existente';

  @override
  String get setup_existing_restore_subtitle =>
      'Elige un archivo de copia de seguridad exportado desde Submersion';

  @override
  String get setup_existing_restore_title =>
      'Restaurar un archivo de copia de seguridad';

  @override
  String get setup_existing_subtitle =>
      'Elige cómo cargar tu biblioteca existente de Submersion';

  @override
  String get setup_existing_sync_subtitle =>
      'Descarga tu biblioteca desde iCloud, Dropbox o S3';

  @override
  String get setup_existing_sync_title => 'Conectar sincronización en la nube';

  @override
  String get setup_existing_title => 'Trae tus datos';

  @override
  String get setup_finish_applying => 'Configurando...';

  @override
  String setup_finish_error(Object error) {
    return 'No se pudo completar la configuración: $error';
  }

  @override
  String get setup_finish_feature_diveComputer =>
      'Descarga inmersiones desde tu ordenador de buceo';

  @override
  String get setup_finish_feature_gear =>
      'Controla tu equipo y los intervalos de mantenimiento';

  @override
  String get setup_finish_feature_import =>
      'Importa registros desde archivos y otras aplicaciones';

  @override
  String get setup_finish_feature_sites =>
      'Visualiza tus puntos de buceo en el mapa';

  @override
  String get setup_finish_feature_statistics =>
      'Explora estadísticas sobre tus inmersiones';

  @override
  String get setup_finish_start => 'Comenzar';

  @override
  String get setup_finish_subtitle => 'Submersion también puede...';

  @override
  String get setup_finish_title => 'Todo listo';

  @override
  String get setup_folder_notFound_message =>
      'La carpeta seleccionada no contiene una base de datos de Submersion.';

  @override
  String get setup_folder_notFound_title => 'No hay biblioteca en esa carpeta';

  @override
  String get setup_folder_pick => 'Elegir carpeta';

  @override
  String get setup_folder_switching => 'Abriendo biblioteca...';

  @override
  String get setup_folder_title => 'Abrir carpeta existente';

  @override
  String get setup_profile_nameHint => 'Ingresa tu nombre';

  @override
  String get setup_profile_nameLabel => 'Tu Nombre';

  @override
  String get setup_profile_nameValidation => 'Por favor ingresa tu nombre';

  @override
  String get setup_profile_subtitle =>
      'Ingresa tu nombre para comenzar. Puedes agregar más detalles después.';

  @override
  String get setup_profile_title => 'Crea Tu Perfil';

  @override
  String get setup_restore_inProgress => 'Restaurando...';

  @override
  String get setup_restore_pick => 'Elegir archivo de copia de seguridad';

  @override
  String get setup_restore_title => 'Restaurar copia de seguridad';

  @override
  String get setup_step_backup => 'Copia';

  @override
  String get setup_step_finish => 'Listo';

  @override
  String get setup_step_profile => 'Perfil';

  @override
  String get setup_step_units => 'Unidades';

  @override
  String get setup_syncPull_continue => 'Continuar';

  @override
  String get setup_syncPull_incomplete_message =>
      'Esta cuenta contiene una biblioteca de Submersion cuya carga nunca se completó. Deja que tu otro dispositivo termine de sincronizar y vuelve a intentarlo.';

  @override
  String get setup_syncPull_incomplete_retry => 'Comprobar de nuevo';

  @override
  String get setup_syncPull_incomplete_title =>
      'Carga de la biblioteca sin terminar';

  @override
  String get setup_syncPull_locked_message =>
      'Introduce la frase de acceso de cifrado para desbloquear esta biblioteca y descargarla en este dispositivo.';

  @override
  String get setup_syncPull_locked_title => 'Esta biblioteca está cifrada';

  @override
  String get setup_syncPull_noLibrary_message =>
      'No se encontró ninguna biblioteca de Submersion en esta cuenta. ¿Empezar de cero? Tu conexión se mantendrá.';

  @override
  String get setup_syncPull_noLibrary_title => 'No se encontró biblioteca';

  @override
  String get setup_syncPull_success => 'Biblioteca adoptada';

  @override
  String get setup_syncPull_syncing => 'Descargando tu biblioteca...';

  @override
  String get setup_syncPull_title => 'Conectar y descargar';

  @override
  String get setup_sync_changeProvider => 'Cambiar proveedor';

  @override
  String setup_sync_connectedTo(String provider) {
    return 'Conectado a $provider';
  }

  @override
  String setup_sync_error(Object error) {
    return 'No se pudo conectar: $error';
  }

  @override
  String get setup_sync_header => 'Sincronización en la nube';

  @override
  String get setup_sync_libraryFound_adopt => 'Adoptar biblioteca existente';

  @override
  String get setup_sync_libraryFound_keepFresh => 'Empezar de cero';

  @override
  String get setup_sync_libraryFound_message =>
      'Esta cuenta ya contiene una biblioteca de Submersion. ¿Adoptarla en lugar de empezar de cero?';

  @override
  String get setup_sync_libraryFound_title =>
      'Se encontró una biblioteca existente';

  @override
  String get setup_sync_manageInSettings => 'Gestionar en Ajustes';

  @override
  String get setup_sync_notConnected => 'No conectado';

  @override
  String get setup_sync_subtitle => 'Sincroniza tus datos entre dispositivos';

  @override
  String get setup_units_advanced => 'Ajustar unidades';

  @override
  String get setup_units_altitude => 'Altitud';

  @override
  String get setup_units_dateFormat => 'Formato de fecha';

  @override
  String get setup_units_depth => 'Profundidad';

  @override
  String get setup_units_imperial => 'Imperial';

  @override
  String get setup_units_metric => 'Métrico';

  @override
  String get setup_units_pressure => 'Presión';

  @override
  String get setup_units_sac => 'Tasa SAC';

  @override
  String get setup_units_subtitle =>
      'Elige cómo se muestran las medidas. Puedes ajustar cada unidad.';

  @override
  String get setup_units_temperature => 'Temperatura';

  @override
  String get setup_units_timeFormat => 'Formato de hora';

  @override
  String get setup_units_title => 'Unidades';

  @override
  String get setup_units_volume => 'Volumen';

  @override
  String get setup_units_weight => 'Peso';

  @override
  String get setup_welcome_existingData_subtitle =>
      'Restaura una copia de seguridad, conecta la sincronización o abre una carpeta existente';

  @override
  String get setup_welcome_existingData_title => 'Ya tengo datos de Submersion';

  @override
  String get setup_welcome_skipSetup => 'Omitir configuración';

  @override
  String get setup_welcome_startFresh_subtitle =>
      'Crea tu perfil de buceador y configura la aplicación';

  @override
  String get setup_welcome_startFresh_title => 'Configurar un perfil nuevo';

  @override
  String get setup_welcome_subtitle =>
      'Registro y análisis avanzado de inmersiones';

  @override
  String get setup_welcome_title => 'Bienvenido a Submersion';

  @override
  String get siteMatchReview_title => 'Asociar puntos';

  @override
  String siteMatchReview_diveNumber(Object number) {
    return 'Inmersion #$number';
  }

  @override
  String get siteMatchReview_empty => 'Nada que asociar.';

  @override
  String siteMatchReview_summary(int selected, int review, int none) {
    return '$selected seleccionadas · $review por revisar · $none sin coincidencia';
  }

  @override
  String siteMatchReview_confirm(int count) {
    return 'Confirmar $count asociaciones';
  }

  @override
  String get siteMatchReview_cancel => 'Cancelar';

  @override
  String get siteMatchReview_tapToChoose =>
      'Toca para elegir un punto de buceo';

  @override
  String siteMatchReview_awayMeters(int meters) {
    return 'a $meters m';
  }

  @override
  String siteMatchReview_depthTo(int meters) {
    return 'hasta $meters m';
  }

  @override
  String siteMatchReview_depthRange(int min, int max) {
    return '$min–$max m';
  }

  @override
  String siteMatchReview_appliedSnack(int dives, int sites) {
    return '$dives inmersiones asociadas · $sites puntos añadidos';
  }

  @override
  String get siteMatchReview_applyError =>
      'No se pudieron aplicar las asociaciones';

  @override
  String get siteMatchReview_discardTitle => '¿Descartar asociaciones?';

  @override
  String get siteMatchReview_discardMessage => 'Tu selección no se guardará.';

  @override
  String get siteMatchReview_discardConfirm => 'Descartar';

  @override
  String get siteMatchReview_keepReviewing => 'Seguir revisando';

  @override
  String get siteMatchReview_sourceExisting => 'tu punto';

  @override
  String get siteMatchReview_sourceBundled => 'importado';

  @override
  String get siteMatchReview_noNearbySite => 'Ningún punto cercano';

  @override
  String importSummary_matchSitesButton(int count) {
    return 'Asociar $count inmersiones a puntos';
  }

  @override
  String get diveLog_listPage_searchFieldLabel => 'Buscar inmersiones...';

  @override
  String diveLog_listPage_searchLimitNotice(int limit) {
    return 'Mostrando las primeras $limit coincidencias. Refina la búsqueda para acotar los resultados.';
  }

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
  String get diveLog_profile_semantics_photoMarker => 'Marcador de foto';

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
  String get diveLog_rangeStats_title => 'Stats de rango';

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
  String get diveLog_search_filter_any => 'Cualquiera';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_deco => 'Descompresión';

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
  String get diveLog_selection_tooltip_combine => 'Combinar';

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
  String get diveLog_selection_tooltip_selectDateRange =>
      'Seleccionar por rango de fechas';

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
  String diveLog_sitePicker_distanceAway(String distance) {
    return 'a $distance';
  }

  @override
  String get diveLog_sitePicker_sortedByDiveDistance =>
      'Ordenados por distancia a esta inmersión';

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
  String get diveLog_tank_mndHelper =>
      'Configurar para calcular He% automaticamente';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String diveLog_tank_modMndInfo(Object mod, Object mnd) {
    return 'MOD: $mod (ppO₂ 1.4) | MND: $mnd';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Mezcla de gas';

  @override
  String get diveLog_tank_selectPreset => 'Seleccionar preajuste...';

  @override
  String get diveLog_tank_saveAsPreset => 'Guardar como preajuste';

  @override
  String get diveLog_tank_saveAsPreset_needSpecs =>
      'Introduce primero un volumen y una presión de trabajo';

  @override
  String get diveLog_tank_saveAsPreset_nameTitle =>
      'Guardar preajuste de tanque';

  @override
  String get diveLog_tank_saveAsPreset_nameHint => 'p. ej. Mi AL80';

  @override
  String diveLog_tank_saveAsPreset_saved(String name) {
    return 'Preajuste \"$name\" guardado';
  }

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
  String get diveLog_tooltip_avgCalculated => '(prom., calculado)';

  @override
  String get diveLog_tooltip_ceiling => 'Techo';

  @override
  String get diveLog_tooltip_decoStop => 'Deco stop';

  @override
  String get diveLog_tooltip_cns => 'CNS';

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
  String get diveLog_tooltip_otu => 'OTU';

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
  String get diveLog_tooltip_sensor => 'Sensor';

  @override
  String get diveLog_legend_label_o2Cells => 'Células O2';

  @override
  String get diveLog_tooltip_o2CellsTight => 'estrecha';

  @override
  String get diveLog_tooltip_o2CellsDrifting => 'divergente';

  @override
  String get diveLog_tooltip_o2CellsWide => 'amplia';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Tiempo';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get diveLog_sources_row_metric => 'Medida';

  @override
  String get diveLog_sources_row_maxDepth => 'Prof. máxima';

  @override
  String get diveLog_sources_row_avgDepth => 'Prof. media';

  @override
  String get diveLog_sources_row_duration => 'Duración';

  @override
  String get diveLog_sources_row_waterTemp => 'Temp. agua';

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
  String get diveLog_sources_unknownComputer => 'Ordenador desconocido';

  @override
  String get diveLog_sources_manualEntry => 'Entrada manual';

  @override
  String get diveLog_sources_importedFile => 'Archivo importado';

  @override
  String get diveLog_sources_editedSuffix => ' (editado)';

  @override
  String get diveLog_sources_barLabel => 'FUENTES';

  @override
  String get diveLog_sources_menu_setPrimary => 'Establecer como principal';

  @override
  String get diveLog_sources_menu_split => 'Separar en otra inmersión';

  @override
  String get diveLog_sources_overlayTooltip => 'Superponer en el gráfico';

  @override
  String get diveLog_sources_splitDialog_title => '¿Separar en otra inmersión?';

  @override
  String get diveLog_sources_splitDialog_body =>
      'El perfil, los eventos y las botellas de esta fuente se moverán a una nueva inmersión. La entrada del diario permanece en esta inmersión.';

  @override
  String get diveLog_sources_splitDialog_confirm => 'Separar';

  @override
  String get diveLog_sources_splitDone => 'Inmersión separada';

  @override
  String get diveLog_sources_splitFailed => 'Error al separar';

  @override
  String get divePlanner_action_addTank => 'Agregar Botella';

  @override
  String get divePlanner_action_convertToDive => 'Convertir a Inmersión';

  @override
  String get divePlanner_action_deletePlan => 'Eliminar plan';

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
  String get divePlanner_error_reserveExceedsTank =>
      'Excede la presión del tanque';

  @override
  String get divePlanner_error_reserveMustBePositive => 'Debe ser mayor que 0';

  @override
  String divePlanner_info_reserveDefault(Object unit, Object value) {
    return 'No ingresado — asumiendo $value $unit';
  }

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
  String get divePlanner_field_travelGas => 'También se usa como gas de viaje';

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
  String get divePlanner_label_reserve => 'Reserva:';

  @override
  String get divePlanner_label_runtime => 'Tiempo Total';

  @override
  String get divePlanner_label_sacRate => 'RMV:';

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
  String divePlanner_message_deleteConfirmation(String name) {
    return '¿Eliminar \'$name\'?';
  }

  @override
  String get divePlanner_message_planDeleted => 'Plan eliminado';

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
  String get diveSites_detail_location_city => 'Ciudad';

  @override
  String get diveSites_detail_location_island => 'Isla';

  @override
  String get diveSites_detail_location_bodyOfWater => 'Masa de agua';

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
  String get diveSites_edit_access_entryMethod_label => 'Método de entrada';

  @override
  String get diveSites_edit_access_exitMethod_label => 'Método de salida';

  @override
  String diveSites_edit_access_entrySuggestionPair(
    int count,
    String entry,
    String exit,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tus $count inmersiones aquí: entrada $entry, salida $exit',
      one: 'Tu inmersión aquí: entrada $entry, salida $exit',
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
      other: 'Tus $count inmersiones aquí: entrada $entry',
      one: 'Tu inmersión aquí: entrada $entry',
    );
    return '$_temp0';
  }

  @override
  String get diveSites_detail_access_entryMethod => 'Entrada';

  @override
  String get diveSites_detail_access_exitMethod => 'Salida';

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
  String get diveSites_edit_appBar_merge => 'Fusionar';

  @override
  String get diveSites_edit_appBar_mergeSites => 'Fusionar puntos de buceo';

  @override
  String get diveSites_edit_appBar_newSite => 'Nuevo sitio';

  @override
  String get diveSites_edit_appBar_save => 'Guardar';

  @override
  String get diveSites_edit_button_addSite => 'Agregar sitio';

  @override
  String get diveSites_edit_button_mergeSites => 'Fusionar puntos de buceo';

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
  String get diveSites_edit_field_city_label => 'Ciudad';

  @override
  String get diveSites_edit_field_island_label => 'Isla';

  @override
  String get diveSites_edit_field_bodyOfWater_label => 'Masa de agua';

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
  String diveSites_similarSite_useHint(Object siteName) {
    return 'Similar a un sitio de buceo existente \"$siteName\". Toca para usar.';
  }

  @override
  String diveSites_similarSite_warning(Object siteName) {
    return 'Ya existe un sitio similar: \"$siteName\"';
  }

  @override
  String get diveSites_edit_gps_gettingLocation => 'Obteniendo...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Elige un método de ubicación o consulta las coordenadas para rellenar país, región, localidad y masa de agua';

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
  String get diveSites_edit_gps_lookupFromCoordinates =>
      'Consultar por coordenadas';

  @override
  String get diveSites_edit_snackbar_lookupNothingFound =>
      'No se encontraron datos de ubicación para estas coordenadas';

  @override
  String get diveSites_edit_snackbar_lookupFailed =>
      'La consulta de ubicación falló. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get diveSites_edit_lookupReplace_title =>
      '¿Reemplazar los datos de ubicación?';

  @override
  String get diveSites_edit_lookupReplace_body =>
      'La consulta encontró valores distintos para estos campos:';

  @override
  String get diveSites_edit_lookupReplace_replace => 'Reemplazar';

  @override
  String get diveSites_edit_lookupReplace_keep => 'Mantener';

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
  String diveSites_edit_merge_confirmBody(int count) {
    return 'Esto fusionará $count puntos de buceo en uno solo. Las inmersiones, los medios y las especies esperadas se combinarán bajo el punto de buceo superviviente. Los demás puntos se eliminarán.';
  }

  @override
  String get diveSites_edit_merge_confirmTitle => 'Fusionar puntos de buceo';

  @override
  String get diveSites_edit_merge_fieldSourceCycleTooltip =>
      'Usar valor del siguiente punto seleccionado';

  @override
  String diveSites_edit_merge_fieldSourceLabel(
    Object siteName,
    int current,
    int total,
  ) {
    return 'De $siteName ($current/$total)';
  }

  @override
  String get diveSites_edit_merge_fieldSourceMenuTooltip =>
      'Seleccionar valor del punto seleccionado';

  @override
  String get diveSites_edit_merge_marineLifeHelperText =>
      'Combinado de todos los puntos seleccionados';

  @override
  String diveSites_edit_merge_loadingErrorBody(Object error) {
    return 'Error al cargar puntos de buceo: $error';
  }

  @override
  String get diveSites_edit_merge_loadingErrorTitle =>
      'Fusionar puntos de buceo';

  @override
  String get diveSites_edit_merge_notEnoughBody =>
      'No hay suficientes puntos de buceo para fusionar.';

  @override
  String get diveSites_edit_merge_notEnoughTitle => 'Fusionar puntos de buceo';

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
  String get diveSites_edit_section_waterType => 'Tipo de agua';

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
  String get diveSites_edit_snackbar_sitesMerged =>
      'Puntos de buceo fusionados';

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
    return '$min-$max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Hasta $max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '$min+';
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
  String get diveSites_list_merge_restored => 'Fusion deshecha';

  @override
  String diveSites_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sitios fusionados',
      one: 'sitio fusionado',
    );
    return '$count $_temp0';
  }

  @override
  String get diveSites_list_merge_undo => 'Deshacer';

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
  String get diveSites_list_menu_select => 'Seleccionar puntos';

  @override
  String get diveSites_list_menu_fillLocationDetails =>
      'Completar datos de ubicación que faltan';

  @override
  String get diveSites_backfill_confirm_title =>
      '¿Completar los datos de ubicación que faltan?';

  @override
  String diveSites_backfill_confirm_body(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count puntos de buceo con coordenadas no tienen país, región, localidad o masa de agua.',
      one:
          '1 punto de buceo con coordenadas no tiene país, región, localidad o masa de agua.',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'unos $minutes minutos',
      one: 'alrededor de 1 minuto',
    );
    return '$_temp0 Submersion consultará cada uno en OpenStreetMap y rellenará solo los campos vacíos. Tarda $_temp1.';
  }

  @override
  String get diveSites_backfill_confirm_start => 'Iniciar';

  @override
  String get diveSites_backfill_nothingToFill =>
      'Todos los puntos de buceo con coordenadas ya tienen sus datos de ubicación.';

  @override
  String get diveSites_backfill_progress_title =>
      'Completando datos de ubicación';

  @override
  String diveSites_backfill_progress_count(int done, int total) {
    return '$done de $total';
  }

  @override
  String get diveSites_backfill_cancel => 'Cancelar';

  @override
  String diveSites_backfill_summary(int updated, int unchanged, int failed) {
    return 'Actualizados $updated, sin cambios $unchanged, fallidos $failed';
  }

  @override
  String get diveSites_backfill_offline =>
      'La consulta de ubicación no está disponible. Comprueba tu conexión e inténtalo de nuevo.';

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
  String get diveSites_list_selection_mergeTooltip => 'Fusionar seleccionados';

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
  String get diveSites_map_builtInSites_add => 'Agregar a mis sitios';

  @override
  String get diveSites_map_builtInSites_addError =>
      'No se pudo agregar el sitio. Inténtalo de nuevo.';

  @override
  String get diveSites_map_builtInSites_added => 'Agregado a tus sitios';

  @override
  String get diveSites_map_builtInSites_hide => 'Ocultar sitios integrados';

  @override
  String get diveSites_map_builtInSites_off => 'Sitios integrados ocultos';

  @override
  String get diveSites_map_builtInSites_on => 'Sitios integrados visibles';

  @override
  String get diveSites_map_builtInSites_show => 'Mostrar sitios integrados';

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
  String diveSites_map_semantics_builtInSiteMarker(Object name) {
    return 'Punto de buceo integrado: $name';
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
  String get diveType_builtin_altitude => 'Altitud';

  @override
  String get diveType_builtin_boat => 'Desde barco';

  @override
  String get diveType_builtin_cave => 'Cueva';

  @override
  String get diveType_builtin_cavern => 'Caverna';

  @override
  String get diveType_builtin_deep => 'Profunda';

  @override
  String get diveType_builtin_drift => 'Deriva';

  @override
  String get diveType_builtin_freedive => 'Apnea';

  @override
  String get diveType_builtin_ice => 'Hielo';

  @override
  String get diveType_builtin_liveaboard => 'Crucero de buceo';

  @override
  String get diveType_builtin_night => 'Nocturna';

  @override
  String get diveType_builtin_recreational => 'Recreativa';

  @override
  String get diveType_builtin_shore => 'Desde costa';

  @override
  String get diveType_builtin_technical => 'Técnica';

  @override
  String get diveType_builtin_training => 'Formación';

  @override
  String get diveType_builtin_wreck => 'Pecio';

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
    return 'This will permanently delete $name and all associated data including dive logs, dive computers, equipment, certifications, and sites.';
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
  String divers_detail_deleteDialogConfirmHint(String name) {
    return 'Type \"Delete $name\" to confirm';
  }

  @override
  String divers_detail_deleteDialogConfirmText(String name) {
    return 'Delete $name';
  }

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
  String get enum_certificationLevel_diveGuide => 'Guía de Buceo';

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
  String get enum_diveMode_gauge => 'Gauge';

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
  String get enum_equipmentType_dpv => 'DPV';

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
  String get enum_sortField_dateTaken => 'Fecha de captura';

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
  String get enum_sortField_fileName => 'Nombre de archivo';

  @override
  String get enum_sortField_fileSize => 'Tamaño de archivo';

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
  String get equipment_serviceClocks_title => 'Intervalos de mantenimiento';

  @override
  String get equipment_serviceClocks_addClock => 'Añadir intervalo';

  @override
  String get equipment_serviceClocks_logService => 'Registrar mantenimiento';

  @override
  String get equipment_serviceClocks_edit => 'Editar intervalos';

  @override
  String get equipment_serviceClocks_pause => 'Pausar';

  @override
  String get equipment_serviceClocks_resume => 'Reanudar';

  @override
  String get equipment_serviceClocks_remove => 'Eliminar';

  @override
  String get equipment_serviceClocks_paused => 'En pausa';

  @override
  String get equipment_serviceClocks_empty => 'Sin intervalos de mantenimiento';

  @override
  String get equipment_serviceClocks_unconfigured =>
      'Sin intervalo definido: toca para configurar';

  @override
  String equipment_serviceClocks_dueOn(String date) {
    return 'Vence el $date';
  }

  @override
  String equipment_serviceClocks_overdueSince(String date) {
    return 'Vencido desde el $date';
  }

  @override
  String get equipment_serviceClocks_overdue => 'Vencido';

  @override
  String equipment_serviceClocks_divesLeft(int remaining, int total) {
    return 'Quedan $remaining de $total inmersiones';
  }

  @override
  String get cylinderConfigs_title => 'Configuraciones de botellas';

  @override
  String get cylinderConfigs_empty => 'Aún no hay configuraciones';

  @override
  String get cylinderConfigs_emptyBody =>
      'Guarda un montaje de diluyente y bailout una vez y aplícalo a cualquier inmersión.';

  @override
  String get cylinderConfigs_new => 'Nueva configuración';

  @override
  String get cylinderConfigs_name => 'Nombre';

  @override
  String get cylinderConfigs_nameRequired => 'Introduce un nombre';

  @override
  String get cylinderConfigs_forUnit => 'Para el equipo';

  @override
  String get cylinderConfigs_noUnit => 'Plan de gas genérico';

  @override
  String get cylinderConfigs_gasPlans => 'Planes de gas';

  @override
  String get cylinderConfigs_addCylinder => 'Añadir botella';

  @override
  String get cylinderConfigs_role => 'Función';

  @override
  String get cylinderConfigs_startPressure => 'Presión inicial';

  @override
  String get cylinderConfigs_label => 'Etiqueta';

  @override
  String get cylinderConfigs_fromPreset => 'Desde preajuste';

  @override
  String get cylinderConfigs_deleteTitle => '¿Eliminar la configuración?';

  @override
  String get cylinderConfigs_deleteBody =>
      'Las inmersiones ya aplicadas no cambian.';

  @override
  String get cylinderConfigs_applyAction => 'Aplicar configuración';

  @override
  String cylinderConfigs_applyAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count botellas añadidas',
      one: '1 botella añadida',
    );
    return '$_temp0';
  }

  @override
  String cylinderConfigs_applyKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conservadas',
      one: '1 conservada',
    );
    return '$_temp0';
  }

  @override
  String get cylinderConfigs_applyNothingToDo =>
      'Esta inmersión ya coincide con la configuración';

  @override
  String get cylinderConfigs_sectionTitle => 'Configuraciones';

  @override
  String get equipment_serviceClocks_hoursSource =>
      'Calculado a partir del tiempo de buceo registrado';

  @override
  String equipment_serviceClocks_hoursLeft(String remaining, String total) {
    return 'Quedan $remaining de $total horas';
  }

  @override
  String get equipment_serviceClocks_manageKinds =>
      'Gestionar tipos de mantenimiento';

  @override
  String get equipment_serviceClocks_appliesToClock => 'Se aplica al intervalo';

  @override
  String get equipment_serviceClocks_noClockOption =>
      'No vinculado a un intervalo';

  @override
  String get equipment_scheduleDialog_title => 'Editar intervalo';

  @override
  String get equipment_scheduleDialog_intervalDays => 'Intervalo (días)';

  @override
  String get equipment_scheduleDialog_intervalDives =>
      'Intervalo (inmersiones)';

  @override
  String get equipment_scheduleDialog_intervalHours => 'Intervalo (horas)';

  @override
  String equipment_scheduleDialog_inheritHint(String value) {
    return 'Predeterminado: $value';
  }

  @override
  String get equipment_scheduleDialog_anchorDate => 'Fecha de referencia';

  @override
  String get equipment_scheduleDialog_anchorHint =>
      'Se usa cuando todavía no existe ningún registro de mantenimiento de este tipo';

  @override
  String get equipment_scheduleDialog_clearAnchor =>
      'Borrar fecha de referencia';

  @override
  String get equipment_scheduleDialog_save => 'Guardar';

  @override
  String get equipment_scheduleDialog_cancel => 'Cancelar';

  @override
  String get equipment_serviceKinds_title => 'Tipos de mantenimiento';

  @override
  String get equipment_serviceKinds_builtIn => 'Integrados';

  @override
  String get equipment_serviceKinds_custom => 'Personalizados';

  @override
  String get equipment_serviceKinds_add => 'Añadir tipo de mantenimiento';

  @override
  String get equipment_serviceKinds_editTitle => 'Editar tipo de mantenimiento';

  @override
  String get equipment_serviceKinds_nameLabel => 'Nombre';

  @override
  String get equipment_serviceKinds_nameRequired => 'Se requiere un nombre';

  @override
  String get equipment_serviceKinds_appliesTo => 'Se aplica a';

  @override
  String get equipment_serviceKinds_autoAttach =>
      'Asociar automáticamente al equipo nuevo';

  @override
  String get equipment_serviceKinds_deleteConfirmTitle =>
      '¿Eliminar tipo de mantenimiento?';

  @override
  String get equipment_serviceKinds_deleteConfirmBody =>
      'Se eliminarán los intervalos que usan este tipo de mantenimiento.';

  @override
  String get equipment_serviceKinds_delete => 'Eliminar';

  @override
  String get equipment_serviceKinds_cancel => 'Cancelar';

  @override
  String get equipment_serviceKinds_save => 'Guardar';

  @override
  String get equipment_serviceKinds_emptyCustom =>
      'Aún no hay tipos de mantenimiento personalizados';

  @override
  String equipment_serviceKinds_everyDays(int days) {
    return 'cada $days días';
  }

  @override
  String equipment_serviceKinds_everyDives(int dives) {
    return 'cada $dives inmersiones';
  }

  @override
  String equipment_serviceKinds_everyHours(String hours) {
    return 'cada $hours horas';
  }

  @override
  String get dashboard_serviceDue_title => 'Mantenimiento pendiente';

  @override
  String dashboard_serviceDue_more(int count) {
    return '+$count más';
  }

  @override
  String dashboard_alerts_clockDue(String name, String kind) {
    return '$name: $kind pendiente';
  }

  @override
  String dashboard_alerts_clockOverdue(String name, String kind) {
    return '$name: $kind vencido';
  }

  @override
  String equipment_list_worstClock(String kind) {
    return '$kind vencido';
  }

  @override
  String trips_serviceAlert_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count equipos necesitan mantenimiento antes de este viaje',
      one: '1 equipo necesita mantenimiento antes de este viaje',
    );
    return '$_temp0';
  }

  @override
  String trips_serviceAlert_dueBefore(String kind, String date) {
    return '$kind vence el $date';
  }

  @override
  String trips_serviceAlert_overdue(String kind) {
    return '$kind vencido';
  }

  @override
  String get settings_notifications_tripLeadTitle =>
      'Antelación del aviso de mantenimiento para viajes';

  @override
  String settings_notifications_tripLeadDays(int days) {
    return '$days días antes de un viaje';
  }

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
  String get equipment_detail_thicknessLabel => 'Grosor';

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
  String get equipment_edit_purchasePriceValidation =>
      'Ingresa un monto valido';

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
  String get equipment_edit_thicknessDesignationHint => 'p. ej., 5, 5/4, 7/5/3';

  @override
  String get equipment_edit_thicknessHint => 'p. ej., 5mm, 7mm';

  @override
  String get equipment_edit_thicknessLabel => 'Grosor';

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
  String get equipment_fab_addSet => 'Agregar Conjunto';

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
  String equipment_list_tile_serviceInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Servicio en $days dias',
      one: 'Servicio en 1 dia',
    );
    return '$_temp0';
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
  String get equipment_serviceDialog_currencyLabel => 'Moneda';

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
  String get equipment_serviceDialog_serviceTypeHelper =>
      'Registrarlo reinicia el contador de este tipo de servicio';

  @override
  String get equipment_serviceDialog_serviceTypeRequired =>
      'Elige un tipo de servicio';

  @override
  String get equipment_serviceDialog_serviceTypeNotSet => 'Sin definir';

  @override
  String get equipment_serviceDialog_categoryHelper =>
      'Se usa para filtrar y exportar';

  @override
  String get equipment_serviceDialog_manageServiceTypes =>
      'Gestionar tipos de servicio';

  @override
  String get equipment_serviceDialog_categoryLabel => 'Categoría';

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
  String get equipment_serviceCategory_annual => 'Servicio anual';

  @override
  String get equipment_serviceCategory_repair => 'Reparación';

  @override
  String get equipment_serviceCategory_inspection => 'Inspección';

  @override
  String get equipment_serviceCategory_overhaul => 'Revisión general';

  @override
  String get equipment_serviceCategory_replacement => 'Sustitución de piezas';

  @override
  String get equipment_serviceCategory_cleaning => 'Limpieza';

  @override
  String get equipment_serviceCategory_calibration => 'Calibración';

  @override
  String get equipment_serviceCategory_warranty => 'Servicio en garantía';

  @override
  String get equipment_serviceCategory_recall => 'Retirada/Seguridad';

  @override
  String get equipment_serviceCategory_other => 'Otro';

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
  String equipment_service_nextDueLabel(String date) {
    return 'Próximo vencimiento $date';
  }

  @override
  String get equipment_service_filterTaskAll => 'Todas las tareas';

  @override
  String get equipment_service_filterTypeAll => 'Todos los tipos';

  @override
  String get equipment_service_filterYearAll => 'Todos los años';

  @override
  String get equipment_service_filterUntagged => 'Sin intervalo asociado';

  @override
  String get equipment_service_filterClear => 'Borrar filtro';

  @override
  String get equipment_service_filterNoMatches =>
      'Ningún mantenimiento coincide con este filtro';

  @override
  String equipment_service_filterMatchCount(int count, int total) {
    return '$count de $total mostrados';
  }

  @override
  String get equipment_serviceKinds_defaultCategoryLabel =>
      'Categoría predeterminada';

  @override
  String get equipment_serviceKinds_defaultCategoryNone => 'Sin predeterminado';

  @override
  String get equipment_serviceKinds_defaultCostLabel => 'Precio predeterminado';

  @override
  String get equipment_serviceKinds_defaultCostHint =>
      'Dejar en blanco para no usar valor predeterminado';

  @override
  String get equipment_scheduleDialog_defaultCostLabel =>
      'Precio predeterminado para este equipo';

  @override
  String get equipment_serviceKinds_defaultCurrencyLabel => 'Moneda';

  @override
  String get equipment_service_exportMenuItem =>
      'Exportar registro de mantenimiento';

  @override
  String get transfer_export_maintenanceTitle => 'Registro de mantenimiento';

  @override
  String get transfer_export_maintenanceSubtitle =>
      'Historial de servicio de todo el equipo como hoja de cálculo';

  @override
  String get settings_export_progress_maintenance =>
      'Exportando registro de mantenimiento...';

  @override
  String get settings_export_success_maintenance =>
      'Registro de mantenimiento exportado';

  @override
  String get settings_export_saved_maintenance =>
      'Registro de mantenimiento guardado';

  @override
  String get equipment_serviceKinds_defaultCurrencyInherit =>
      'Usar la moneda predeterminada';

  @override
  String get equipment_scheduleDialog_defaultCurrencyLabel =>
      'Moneda para este equipo';

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
  String get equipment_tab_equipment => 'Equipo';

  @override
  String get equipment_tab_sets => 'Conjuntos';

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
  String get gasCalculators_mnd_depthInput => 'Profundidad';

  @override
  String get gasCalculators_mnd_endAtDepthTitle => 'END a Profundidad';

  @override
  String get gasCalculators_mnd_endLimit => 'Limite END';

  @override
  String get gasCalculators_mnd_hePercent => 'He %';

  @override
  String get gasCalculators_mnd_infoContent =>
      'La Profundidad Narcotica Maxima (MND) es la profundidad maxima a la que puedes descender antes de que la narcosis supere tu limite de END. La Profundidad Narcotica Equivalente (END) te indica el efecto narcotico de tu gas a una profundidad determinada.\n\nCuando \'O2 es narcotico\' esta activado, tanto el oxigeno como el nitrogeno contribuyen a la narcosis (mas conservador). Cuando esta desactivado, solo el nitrogeno se considera narcotico.';

  @override
  String get gasCalculators_mnd_infoTitle => 'Acerca de MND/END';

  @override
  String get gasCalculators_mnd_unlimited => 'ilimitado';

  @override
  String get gasCalculators_mnd_inputParameters =>
      'Mezcla de Gas y Ajustes de Narcosis';

  @override
  String get gasCalculators_mnd_o2Narcotic => 'O2 es narcotico';

  @override
  String get gasCalculators_mnd_o2Percent => 'O2 %';

  @override
  String get gasCalculators_mnd_resultTitle => 'Profundidad Narcotica Maxima';

  @override
  String get gasCalculators_ppO2Limit => 'Límite ppO₂';

  @override
  String get gasCalculators_resetAll => 'Restablecer todas las calculadoras';

  @override
  String get gasCalculators_sacRate => 'RMV';

  @override
  String get gasCalculators_tab_bestMix => 'Mejor Mezcla';

  @override
  String get gasCalculators_tab_consumption => 'Consumo';

  @override
  String get gasCalculators_tab_mnd => 'MND/END';

  @override
  String get gasCalculators_tab_blender => 'Mezclador de trimix';

  @override
  String get gasCalculators_blender_cylinder => 'Cilindro';

  @override
  String get gasCalculators_blender_startCylinder => 'En el cilindro';

  @override
  String get gasCalculators_blender_targetFill => 'Llenado objetivo';

  @override
  String get gasCalculators_blender_fillGases => 'Gases de llenado';

  @override
  String get gasCalculators_blender_pressure => 'Presión';

  @override
  String get gasCalculators_blender_o2 => 'O₂';

  @override
  String get gasCalculators_blender_he => 'He';

  @override
  String get gasCalculators_blender_air => 'Aire';

  @override
  String get gasCalculators_blender_helium => 'Helio';

  @override
  String get gasCalculators_blender_procedure => 'Procedimiento de llenado';

  @override
  String get gasCalculators_blender_amounts => 'Gas a añadir';

  @override
  String gasCalculators_blender_stepStart(String pressure, String gas) {
    return 'Empieza con $pressure $gas';
  }

  @override
  String gasCalculators_blender_stepFill(
    String gas,
    String pressure,
    String mix,
  ) {
    return 'Llena $gas hasta $pressure → $mix';
  }

  @override
  String get gasCalculators_blender_error_targetPressure =>
      'La presión objetivo debe ser mayor que la inicial.';

  @override
  String get gasCalculators_blender_error_invalidMix =>
      'El O₂ + He de una mezcla no puede superar el 100 %.';

  @override
  String get gasCalculators_blender_error_identicalGases =>
      'Los dos gases de llenado son idénticos: no hay nada que mezclar.';

  @override
  String get gasCalculators_blender_error_linearlyDependent =>
      'Estos gases no pueden producir la mezcla objetivo: un objetivo trimix necesita una fuente de helio.';

  @override
  String get gasCalculators_blender_error_negativeAmount =>
      'Esta mezcla no es posible con estos gases: habría que extraer gas.';

  @override
  String gasCalculators_blender_error_drainTo(String pressure) {
    return 'Demasiado gas en el cilindro para esta mezcla: vacía hasta $pressure y luego llena.';
  }

  @override
  String get gasCalculators_blender_error_drainEmpty =>
      'El gas que hay en el cilindro no sirve para esta mezcla: vacíalo por completo y luego llena.';

  @override
  String get gasCalculators_blender_error_cannotRemoveHelium =>
      'El cilindro contiene helio y la mezcla objetivo no. Rellenar diluye el helio pero no lo elimina: hay que vaciar el cilindro primero.';

  @override
  String get gasCalculators_blender_error_insufficientGases =>
      'Un objetivo sin helio necesita dos gases de llenado sin helio con distinto contenido de O₂.';

  @override
  String get gasCalculators_blender_error_targetNotReached =>
      'Estos gases de llenado no alcanzan exactamente la mezcla objetivo. Revisa los gases y su orden.';

  @override
  String get gasCalculators_blender_error_implausibleStartMix =>
      'El cilindro tiene presión pero ni oxígeno ni helio, lo que sería nitrógeno puro. Comprueba la mezcla que ya hay en el cilindro.';

  @override
  String get gasCalculators_blender_about => 'Sobre la mezcla';

  @override
  String get gasCalculators_blender_aboutBody =>
      'Mezcla por presiones parciales para la mezcla objetivo. Añade cada gas de llenado en orden, hasta la presión indicada, y deja que el cilindro se estabilice. Los gases de llenado y su orden son configurables: si ajustas el último gas a 32/0, el remate se hace con EAN32 en lugar de aire. Analiza siempre la mezcla final antes de bucearla.';

  @override
  String get gasCalculators_blender_conditions => 'Condiciones de mezcla';

  @override
  String get gasCalculators_blender_fillTemp => 'Temperatura de llenado';

  @override
  String get gasCalculators_blender_fillTempHelp =>
      'La temperatura del cilindro mientras lo llenas. Cada presión del procedimiento es la lectura del manómetro a esta temperatura.';

  @override
  String get gasCalculators_blender_settledTemp => 'Temperatura estabilizada';

  @override
  String get gasCalculators_blender_settledTempHelp =>
      'La temperatura a la que acaba el cilindro. La presión objetivo es lo que marca una vez estabilizado.';

  @override
  String get gasCalculators_blender_gasModel => 'Modelo de gas';

  @override
  String get gasCalculators_blender_modelIdeal => 'Gas ideal';

  @override
  String get gasCalculators_blender_modelVanDerWaals => 'Van der Waals';

  @override
  String get gasCalculators_blender_modelZFactor => 'Gas real (factor Z)';

  @override
  String get gasCalculators_blender_modelRecommended => 'Recomendado';

  @override
  String get gasCalculators_blender_modelHelp =>
      'El gas real (factor Z) es el más preciso a presiones de cilindro. El gas ideal coincide con la mayoría de las tablas de mezcla publicadas. Van der Waals se ofrece para comparar con otros programas de mezcla y se desvía varios por ciento a presión de llenado.';

  @override
  String gasCalculators_blender_stepAdd(String gas) {
    return 'Añadir $gas';
  }

  @override
  String get gasCalculators_blender_stepStartLabel => 'Inicio';

  @override
  String gasCalculators_blender_settlesTo(String pressure, String temperature) {
    return 'Se estabiliza en $pressure a $temperature';
  }

  @override
  String get gasCalculators_blender_templates => 'Plantillas';

  @override
  String get gasCalculators_blender_templatesTitle =>
      'Plantillas de mezcla objetivo';

  @override
  String get gasCalculators_blender_saveTemplate => 'Guardar la mezcla actual';

  @override
  String get gasCalculators_blender_manageTemplates => 'Gestionar plantillas';

  @override
  String gasCalculators_blender_templateSaved(String mix) {
    return '$mix guardada';
  }

  @override
  String get gasCalculators_blender_templateExists =>
      'Esa mezcla ya está guardada.';

  @override
  String get gasCalculators_blender_templateInvalid =>
      'O₂ + He no puede superar el 100 %.';

  @override
  String get gasCalculators_blender_templateNeedsNumbers =>
      'Introduce O₂ y He como números.';

  @override
  String gasCalculators_blender_templateLimit(int count) {
    return 'Puedes guardar hasta $count plantillas.';
  }

  @override
  String get gasCalculators_blender_templateNone =>
      'Aún no hay plantillas. Guarda una mezcla objetivo para reutilizarla aquí.';

  @override
  String gasCalculators_blender_templateDelete(String mix) {
    return 'Eliminar $mix';
  }

  @override
  String get gasCalculators_blender_templateAdd => 'Añadir plantilla';

  @override
  String get gasCalculators_blender_billing => 'Coste';

  @override
  String get gasCalculators_blender_cylinderVolume =>
      'Volumen de agua del cilindro';

  @override
  String get gasCalculators_blender_cylinderPresets => 'Preajustes';

  @override
  String gasCalculators_blender_unitPrice(String unit) {
    return 'Precio por 100 $unit';
  }

  @override
  String get gasCalculators_blender_currency => 'Moneda';

  @override
  String get gasCalculators_blender_costTotal => 'Total';

  @override
  String get gasCalculators_blender_costBasis =>
      'Se factura la presión suministrada (volumen de agua del cilindro × bar añadidos), tal como lo mide una estación de carga.';

  @override
  String get gasCalculators_blender_costMissingPrice =>
      'Introduce un precio para cada gas para ver el total.';

  @override
  String get gasCalculators_blender_saveFill => 'Guardar este llenado';

  @override
  String get gasCalculators_blender_billed => 'Facturado';

  @override
  String get gasCalculators_blender_billedNone =>
      'Todavía no hay nada facturado. Termina un llenado y guárdalo aquí.';

  @override
  String get gasCalculators_blender_billedTo => 'Facturado a';

  @override
  String get gasCalculators_blender_addManualLine => 'Añadir una línea';

  @override
  String get gasCalculators_blender_lineDescription => 'Descripción';

  @override
  String get gasCalculators_blender_lineAmount => 'Importe';

  @override
  String get gasCalculators_blender_clearBilled => 'Vaciar';

  @override
  String get gasCalculators_blender_clearBilledTitle => '¿Vaciar la factura?';

  @override
  String gasCalculators_blender_clearBilledBody(int count) {
    return 'Esto elimina los $count llenados guardados.';
  }

  @override
  String gasCalculators_blender_editLine(String label) {
    return 'Editar $label';
  }

  @override
  String gasCalculators_blender_deleteLine(String label) {
    return 'Eliminar $label';
  }

  @override
  String gasCalculators_blender_fillAdded(String mix) {
    return '$mix añadido a la factura';
  }

  @override
  String get gasCalculators_blender_billedIncomplete =>
      'Alguna línea no tiene precio, así que el total está incompleto.';

  @override
  String get gasCalculators_blender_billedTotal => 'Total';

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
  String get media_diveMediaSection_cancelSelectionButton => 'Cancelar';

  @override
  String get media_diveMediaSection_emptyState => 'No hay fotos aun';

  @override
  String get media_diveMediaSection_errorLoading => 'Error al cargar medios';

  @override
  String get media_diveMediaSection_selectAllButton => 'Seleccionar todo';

  @override
  String media_diveMediaSection_selectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Ver foto. Mantener presionado para desvincular';

  @override
  String get media_diveMediaSection_title => 'Fotos y video';

  @override
  String get media_diveMediaSection_replaceButton => 'Volver a vincular';

  @override
  String get media_diveMediaSection_replaceEditedContent =>
      'El contenido de este archivo difiere del original. Volver a vincularlo lo resubirá a su almacén multimedia.';

  @override
  String get media_diveMediaSection_replaceEditedTitle =>
      'El contenido del archivo difiere';

  @override
  String get media_diveMediaSection_unlinkButton => 'Desvincular';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Error al desvincular: $error';
  }

  @override
  String media_diveMediaSection_unlinkSelectedButton(int count) {
    return 'Desvincular $count';
  }

  @override
  String media_diveMediaSection_unlinkSelectedContent(int count) {
    return 'Elimina $count elementos multimedia de tu biblioteca, junto con sus copias en la nube y miniaturas. Se conservan los elementos que aún usa un sitio de buceo. Tus archivos originales no se ven afectados.';
  }

  @override
  String media_diveMediaSection_unlinkSelectedSuccess(int count) {
    return '$count elementos desvinculados';
  }

  @override
  String media_diveMediaSection_unlinkSelectedTitle(int count) {
    return 'Desvincular $count elementos?';
  }

  @override
  String media_library_unlinkConfirmTitle(int count) {
    return 'Desvincular $count elementos?';
  }

  @override
  String media_siteMediaSection_unlinkError(Object error) {
    return 'Error al desvincular: $error';
  }

  @override
  String get media_library_unlinkConfirmBody =>
      'Salen de tu biblioteca, junto con sus copias en la nube y miniaturas. Tus archivos originales no se ven afectados. No se puede deshacer.';

  @override
  String media_library_unlinkMetadataNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count de ellos tienen un pie de foto o marca de favorito guardados en Submersion, y esos detalles se pierden.',
      one:
          'Uno de ellos tiene un pie de foto o marca de favorito guardados en Submersion, y esos detalles se pierden.',
    );
    return '$_temp0';
  }

  @override
  String get media_siteMediaSection_title => 'Medios del punto de buceo';

  @override
  String get media_siteMediaSection_addPhotos => 'Añadir fotos o vídeos';

  @override
  String get media_siteMediaSection_addDocument => 'Añadir documento';

  @override
  String get media_siteMediaSection_emptyState =>
      'No hay mapas, fotos ni documentos adjuntos a este punto de buceo';

  @override
  String media_siteMediaSection_divePhotosGroup(int count) {
    return 'Fotos de inmersiones aquí ($count)';
  }

  @override
  String get media_siteMediaSection_divePhotoLabel => 'Foto de inmersión';

  @override
  String media_siteMediaSection_unlinkSelectedTitle(int count) {
    return 'Desvincular $count elementos?';
  }

  @override
  String media_siteMediaSection_unlinkSelectedContent(int count) {
    return 'Elimina $count elementos de tu biblioteca, junto con sus copias en la nube y miniaturas. Los medios que un buceo todavía usa se conservan. Tus archivos originales no se ven afectados.';
  }

  @override
  String media_siteMediaSection_unlinkSelectedSuccess(int count) {
    return '$count elementos desvinculados';
  }

  @override
  String get media_documentViewer_title => 'Documento';

  @override
  String get media_documentViewer_unavailable =>
      'Este documento no está disponible en este dispositivo';

  @override
  String get media_documentViewer_availableOnOriginDevice =>
      'Está disponible en el dispositivo desde el que se añadió, o mediante un almacén de medios configurado.';

  @override
  String media_documentViewer_attached(int count) {
    return 'Se adjuntaron $count documentos';
  }

  @override
  String get media_diveScan_scanTooltip => 'Buscar fotos en la galeria';

  @override
  String get media_diveScan_noPhotosFound =>
      'No se encontraron fotos nuevas cerca de esta inmersion';

  @override
  String get media_diveScan_accessDenied =>
      'Se requiere acceso a la biblioteca de fotos para buscar fotos';

  @override
  String media_diveScan_foundPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'encontraron $count fotos',
      one: 'encontro 1 foto',
    );
    return 'Se $_temp0 cerca de esta inmersion. Vincular?';
  }

  @override
  String get media_diveScan_foundTitle => 'Fotos encontradas';

  @override
  String media_diveScan_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fotos',
      one: 'foto',
    );
    return 'Vincular $_temp0';
  }

  @override
  String get media_diveScan_cancelButton => 'Cancelar';

  @override
  String media_diveScan_error(String error) {
    return 'Error al buscar en la galeria: $error';
  }

  @override
  String get media_gpsBanner_addToSiteButton => 'Agregar al punto';

  @override
  String media_gpsBanner_coordinates(Object coordinates) {
    return 'Coordenadas: $coordinates';
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
  String media_import_allAlreadyLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos ya vinculadas a esta inmersion',
      one: '1 foto ya vinculada a esta inmersion',
    );
    return '$_temp0';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return 'Importadas $imported, fallaron $failed';
  }

  @override
  String media_import_importedAndSkipped(int imported, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      imported,
      locale: localeName,
      other: 'Se importaron $imported fotos',
      one: 'Se importo 1 foto',
    );
    return '$_temp0 ($skipped ya vinculadas)';
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
  String get media_lightroom_openInLightroom => 'Abrir en Lightroom';

  @override
  String get media_lightroom_suggestion_accept => 'Añadir a esta inmersión';

  @override
  String get media_lightroom_suggestion_dismiss => 'Descartar';

  @override
  String get media_lightroom_suggestions_title => 'Sugerencias de Lightroom';

  @override
  String get media_miniProfile_headerLabel => 'Perfil de inmersion';

  @override
  String get media_miniProfile_semanticLabel =>
      'Grafico del perfil de inmersion en miniatura';

  @override
  String get media_photoPicker_appBarTitle => 'Seleccionar fotos';

  @override
  String get media_photoPicker_tab_gallery => 'Galeria';

  @override
  String get media_photoPicker_tab_files => 'Archivos';

  @override
  String get media_photoPicker_tab_url => 'URL';

  @override
  String get media_photoPicker_clearSelectionButton => 'Limpiar';

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
  String get media_photoPicker_grantAccessButton => 'Continuar';

  @override
  String get media_photoPicker_openSettingsButton => 'Abrir ajustes';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'Se denego el acceso a la biblioteca de fotos. Activalo en Ajustes para agregar fotos de buceo.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion necesita acceso a tu biblioteca de fotos para agregar fotos de buceo.';

  @override
  String get media_photoPicker_permissionTitle => 'Fotos de buceo';

  @override
  String get media_photoPicker_selectAllButton => 'Seleccionar todo';

  @override
  String media_photoPicker_selectedCount(int count) {
    return '$count seleccionados';
  }

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
  String get media_photoPicker_files_pickFilesButton => 'Seleccionar archivos…';

  @override
  String get media_photoPicker_files_pickFolderButton =>
      'Seleccionar una carpeta…';

  @override
  String get media_photoPicker_files_autoMatchLabel =>
      'Asociar automáticamente fotos y vídeos a las inmersiones por fecha';

  @override
  String get media_photoPicker_files_emptyHint =>
      'Selecciona archivos o una carpeta para empezar.';

  @override
  String media_photoPicker_files_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vincular $count elementos',
      one: 'Vincular 1 elemento',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachToSiteButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Adjuntar $count elementos a este punto',
      one: 'Adjuntar 1 elemento a este punto',
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
      other: '$fileCount archivos',
      one: '1 archivo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount inmersiones',
      one: '1 inmersión',
    );
    return '$_temp0, $_temp1, $unmatchedCount sin asociar';
  }

  @override
  String media_photoPicker_files_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_diveGroupTitle(String diveId) {
    return 'Inmersión $diveId';
  }

  @override
  String media_photoPicker_files_groupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '1 archivo',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_unmatchedGroupTitle => 'Sin asociar';

  @override
  String media_photoPicker_files_addAllToDive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Añadir los $count a esta inmersión',
      one: 'Añadir 1 a esta inmersión',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_addToDiveTooltip =>
      'Añadir a esta inmersión';

  @override
  String get media_photoPicker_files_chooseDiveTooltip =>
      'Elegir una inmersión';

  @override
  String get media_photoPicker_files_removeTooltip => 'Quitar de la selección';

  @override
  String get media_photoPicker_files_sourceExif => 'de EXIF';

  @override
  String get media_photoPicker_files_sourceContainer =>
      'de los metadatos del archivo';

  @override
  String get media_photoPicker_files_sourceFileDate =>
      'de la fecha del archivo';

  @override
  String get media_photoPicker_files_sourceNone => 'sin fecha';

  @override
  String media_photoPicker_files_shiftedTime(String shifted, String original) {
    return '$shifted (era $original)';
  }

  @override
  String get media_photoPicker_files_reasonNoTimestamp =>
      'No se pudo leer la hora de captura';

  @override
  String media_photoPicker_files_reasonBeforeDive(String gap) {
    return '$gap antes de la inmersión más cercana';
  }

  @override
  String media_photoPicker_files_reasonAfterDive(String gap) {
    return '$gap después de la inmersión más cercana';
  }

  @override
  String get media_photoPicker_files_reasonNoDives =>
      'No hay inmersiones con las que comparar';

  @override
  String get media_photoPicker_files_offsetLabel =>
      'Desplazar las horas de captura';

  @override
  String get media_photoPicker_files_offsetResetTooltip =>
      'Restablecer sin desplazamiento';

  @override
  String media_photoPicker_files_offsetBackTooltip(String amount) {
    return 'Desplazar $amount antes';
  }

  @override
  String media_photoPicker_files_offsetForwardTooltip(String amount) {
    return 'Desplazar $amount después';
  }

  @override
  String media_photoPicker_files_linkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos vinculados',
      one: '1 elemento vinculado',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachedToSiteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos adjuntados a este punto',
      one: '1 elemento adjuntado a este punto',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_undo => 'Deshacer';

  @override
  String get media_photoPicker_thumbnailAlreadyLinkedLabel =>
      'Foto ya vinculada a esta inmersion';

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
  String get media_perdixOverlay_labelTime => 'TIEMPO';

  @override
  String get media_perdixOverlay_labelTts => 'TTS';

  @override
  String get media_perdixOverlay_toggleTooltip =>
      'Superposición de ordenador de buceo';

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
  String get media_photoViewer_nextTooltip => 'Elemento siguiente';

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
  String get media_photoViewer_previousTooltip => 'Elemento anterior';

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
      'No disponible en este dispositivo';

  @override
  String get media_unavailablePlaceholder_signInRequired => 'Sign in to view';

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
  String get media_writeMetadata_livePhotoUnsupported =>
      'Las Live Photos aún no son compatibles. Duplica esta foto como imagen fija y luego escribe los datos de buceo en la copia.';

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
  String get nav_gpsLog => 'Registro GPS';

  @override
  String get media_console_library => 'Biblioteca';

  @override
  String get media_console_transfers => 'Transferencias';

  @override
  String get media_console_import => 'Importar';

  @override
  String get media_import_launch => 'Importar contenido...';

  @override
  String get media_import_review_title => 'Revisar importación';

  @override
  String media_import_review_confirm(int count) {
    return 'Importar $count elementos';
  }

  @override
  String media_import_review_result(int linked, int skipped, int failed) {
    return '$linked vinculados, $skipped omitidos, $failed fallidos';
  }

  @override
  String get media_import_review_chooseSite => 'Elegir sitio';

  @override
  String get media_import_review_ambiguous => 'Varios buceos coinciden';

  @override
  String get media_import_review_noMatch => 'Ningún buceo coincide';

  @override
  String get media_import_review_skipped => 'No importado';

  @override
  String media_import_review_linkChip(int number) {
    return 'Vincular a #$number';
  }

  @override
  String get media_import_review_linkToDive => 'Vincular a una inmersión';

  @override
  String get media_import_review_linkToSite => 'Vincular a un sitio';

  @override
  String get media_import_review_chooseDive => 'Elegir inmersión';

  @override
  String get media_import_intro =>
      'Las fotos se vinculan a un buceo o a un sitio de buceo al importarlas.';

  @override
  String get media_console_sources => 'Orígenes';

  @override
  String get media_sources_browseHeader => 'Explorar por origen';

  @override
  String get media_sources_watchedHeader => 'Carpetas vigiladas';

  @override
  String get media_sources_addWatched => 'Agregar carpeta...';

  @override
  String get media_sources_scanFailed => 'Error al analizar';

  @override
  String get media_sources_scanNow => 'Buscar ahora';

  @override
  String get media_sources_autoApply =>
      'Volver a vincular automáticamente las coincidencias exactas';

  @override
  String get media_sources_neverScanned => 'Nunca analizada';

  @override
  String get media_source_gallery => 'Fototeca';

  @override
  String get media_source_localFile => 'Archivos locales';

  @override
  String get media_source_networkUrl => 'Enlaces web';

  @override
  String get media_source_manifest => 'Suscripciones';

  @override
  String get media_source_connector => 'Servicios conectados';

  @override
  String get media_source_mediaStore => 'Almacén multimedia en la nube';

  @override
  String get media_source_signature => 'Firmas';

  @override
  String get media_repairHistory_title => 'Historial de reparaciones';

  @override
  String get media_repairHistory_empty => 'Aún no hay reparaciones';

  @override
  String get media_repairHistory_action_relink => 'Revinculado';

  @override
  String get media_repairHistory_action_cloudBacked => 'En la nube';

  @override
  String get media_repairHistory_action_autoRelink =>
      'Revinculado automáticamente';

  @override
  String get media_smartAlbum_save => 'Guardar como álbum';

  @override
  String get media_smartAlbum_saveTitle => 'Nombra este álbum';

  @override
  String get media_smartAlbum_albums => 'Álbumes';

  @override
  String get media_smartAlbum_delete => 'Eliminar álbum';

  @override
  String get media_smartAlbum_deleteFailed => 'No se pudo eliminar el álbum';

  @override
  String get media_smartAlbum_saved => 'Álbum guardado';

  @override
  String media_sources_lastScanned(String date) {
    return 'Último análisis $date';
  }

  @override
  String media_sources_scanResult(int indexed, int repaired) {
    return '$indexed archivos indexados, $repaired revinculados';
  }

  @override
  String get media_repairHistory_sourceFolder => 'análisis de carpetas';

  @override
  String get media_repairHistory_sourcePhotoLibrary => 'fototeca';

  @override
  String get media_repairHistory_sourceStore => 'almacén multimedia en la nube';

  @override
  String get media_repairHistory_sourceWatcher => 'carpetas vigiladas';

  @override
  String get media_repairHistory_sourceManual => 'revinculación manual';

  @override
  String media_repairHistory_source(String source) {
    return 'vía $source';
  }

  @override
  String get media_missing_empty => 'No hay archivos faltantes';

  @override
  String media_missing_offlineVolumes(int count) {
    return '$count en volúmenes sin conexión';
  }

  @override
  String get media_missing_repair => 'Reparar...';

  @override
  String get media_repair_title => 'Reparar archivos faltantes';

  @override
  String get media_repair_addFolder => 'Agregar carpeta...';

  @override
  String get media_repair_usePhotoLibrary => 'Buscar en la fototeca';

  @override
  String get media_repair_useStore => 'Usar el almacén multimedia en la nube';

  @override
  String get media_repair_scan => 'Buscar';

  @override
  String media_repair_prefixMove(String from, String to, int count) {
    return 'Movimiento de carpeta detectado: $from a $to cubre $count archivos';
  }

  @override
  String get media_repair_confidence_exact => 'Exacto';

  @override
  String get media_repair_confidence_probable => 'Nombre y tamaño';

  @override
  String get media_repair_confidence_edited => 'Archivo editado';

  @override
  String get media_repair_confidence_unmatched => 'Sin candidato';

  @override
  String get media_repair_unverified => 'No verificado contra el almacén';

  @override
  String media_repair_apply(int count) {
    return 'Volver a vincular $count archivos';
  }

  @override
  String media_repair_summary(
    int relinked,
    int cloudBacked,
    int reuploads,
    int failed,
    int skipped,
  ) {
    return '$relinked revinculados, $cloudBacked en la nube, $reuploads resubidas en cola, $failed fallidos, $skipped omitidos';
  }

  @override
  String get media_library_empty => 'Todavía no hay contenido multimedia';

  @override
  String get media_library_filter_all => 'Todo';

  @override
  String get media_library_filter_photos => 'Fotos';

  @override
  String get media_library_filter_videos => 'Vídeos';

  @override
  String get media_library_filter_site => 'Sitio';

  @override
  String get media_library_filter_trip => 'Viaje';

  @override
  String get media_library_filter_dates => 'Fechas';

  @override
  String get media_library_filter_missing => 'Archivos faltantes';

  @override
  String media_library_filter_missingCount(int count) {
    return 'Archivos faltantes ($count)';
  }

  @override
  String get media_library_filter_clear => 'Borrar filtros';

  @override
  String get media_library_filter_any => 'Cualquiera';

  @override
  String get media_library_filter_title => 'Filtrar medios';

  @override
  String get media_library_filter_apply => 'Aplicar';

  @override
  String get media_library_sort_title => 'Ordenar medios';

  @override
  String get media_smartAlbum_load => 'Cargar álbum';

  @override
  String get media_divePicker_title => 'Mover a una inmersión';

  @override
  String get media_divePicker_search => 'Buscar inmersiones';

  @override
  String get media_library_moveToDive => 'Mover a una inmersión';

  @override
  String get media_library_unlinkSelected => 'Desvincular';

  @override
  String media_library_selectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String get media_library_unlinkedHeader => 'Sin vincular';

  @override
  String get media_library_diveHeaderHint => 'Abrir esta inmersión';

  @override
  String get media_library_untitledDiveHeader => 'Inmersión sin título';

  @override
  String get media_library_viewMode_byDive => 'Por inmersión';

  @override
  String get media_library_viewMode_grid => 'Cuadrícula';

  @override
  String get media_library_viewMode_timeline => 'Cronología';

  @override
  String get media_viewer_goToDive => 'Ir a la inmersión';

  @override
  String get nav_home => 'Inicio';

  @override
  String get nav_media => 'Multimedia';

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
  String plannerCanvas_bailout_available(String liters) {
    return 'Disponible $liters';
  }

  @override
  String get plannerCanvas_bailout_insufficient =>
      'Gas de bailout insuficiente para el peor caso';

  @override
  String plannerCanvas_bailout_required(String liters) {
    return 'Necesario $liters';
  }

  @override
  String get plannerCanvas_bailout_title => 'Bailout (circuito abierto)';

  @override
  String plannerCanvas_bailout_tts(String minutes) {
    return 'TTS de bailout $minutes′';
  }

  @override
  String plannerCanvas_bailout_worstCase(String minutes, String depth) {
    return 'Peor caso a los $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_ccr_setpointHigh => 'Setpoint alto (bar)';

  @override
  String get plannerCanvas_ccr_setpointLow => 'Setpoint bajo (bar)';

  @override
  String get plannerCanvas_ccr_switchDepth =>
      'Profundidad de cambio de setpoint';

  @override
  String get plannerCanvas_pscr_ratio => 'Relación pSCR';

  @override
  String get plannerCanvas_pscr_ratio_hint =>
      'Mayor = más gas fresco, menor caída de O₂';

  @override
  String plannerCanvas_chip_cns(String value) {
    return 'CNS $value%';
  }

  @override
  String plannerCanvas_chip_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemas',
      one: '1 problema',
    );
    return '$_temp0';
  }

  @override
  String get plannerCanvas_compare_action => 'Comparar';

  @override
  String get plannerCanvas_compare_needTwo =>
      'Selecciona al menos dos planes para comparar';

  @override
  String get plannerCanvas_compare_title => 'Comparar planes';

  @override
  String get plannerCanvas_contingency_base => 'Base';

  @override
  String get plannerCanvas_contingency_depthDelta => 'Profundidad extra';

  @override
  String plannerCanvas_contingency_lostGas(String gas) {
    return '$gas perdido';
  }

  @override
  String plannerCanvas_contingency_previewing(String label) {
    return 'Vista previa: $label';
  }

  @override
  String get plannerCanvas_contingency_timeDelta => 'Minutos extra';

  @override
  String plannerCanvas_chart_meanDepth(String depth) {
    return 'media $depth';
  }

  @override
  String get plannerCanvas_contingency_title => 'Contingencias';

  @override
  String get plannerCanvas_contingency_turnFraction => 'Fracción de retorno';

  @override
  String get plannerCanvas_contingency_turnRule =>
      'Regla de presión de retorno';

  @override
  String get plannerCanvas_convert_success =>
      'Inmersión creada a partir del plan';

  @override
  String get plannerCanvas_convert_view => 'Ver';

  @override
  String plannerCanvas_follow_chip(String name) {
    return 'Siguiendo $name';
  }

  @override
  String get plannerCanvas_follow_empty => 'Aún no hay inmersiones registradas';

  @override
  String get plannerCanvas_follow_noTissues =>
      'Sin datos de perfil en esa inmersión — intervalo en superficie establecido sin saturación de tejidos';

  @override
  String get plannerCanvas_follow_title => 'Seguir una inmersión';

  @override
  String plannerCanvas_gas_minGas(String pressure) {
    return 'gas mínimo $pressure';
  }

  @override
  String plannerCanvas_gas_turnAt(String pressure) {
    return 'retorno a $pressure';
  }

  @override
  String plannerCanvas_issue_gasDensityCritical(String value) {
    return 'Densidad del gas $value g/L sobre el límite máximo';
  }

  @override
  String plannerCanvas_issue_gasDensityHigh(String value) {
    return 'Densidad del gas $value g/L sobre el límite recomendado';
  }

  @override
  String plannerCanvas_issue_hypoxic(String depth, String value) {
    return 'Gas hipóxico a $depth (ppO₂ $value bar)';
  }

  @override
  String plannerCanvas_issue_minGas(String pressure) {
    return 'La botella termina por debajo del mínimo rock bottom de $pressure';
  }

  @override
  String get plannerCanvas_issue_noBailout =>
      'El plan de descompresión CCR no lleva gas de bailout';

  @override
  String get plannerCanvas_issue_noDecoGas =>
      'Se requiere descompresión pero no se lleva gas de deco';

  @override
  String get plannerCanvas_range_base => 'Base';

  @override
  String get plannerCanvas_range_legend =>
      'Las celdas muestran el tiempo hasta la superficie; rojo = no buceable según lo planeado';

  @override
  String get plannerCanvas_pane_collapse => 'Contraer panel';

  @override
  String get plannerCanvas_pane_expand => 'Expandir panel';

  @override
  String get plannerCanvas_tab_setup => 'Configuración';

  @override
  String get plannerCanvas_o2Narcotic => 'Tratar el O₂ como narcótico';

  @override
  String get plannerCanvas_rates_ascent => 'Tasa de ascenso';

  @override
  String get plannerCanvas_rates_descent => 'Tasa de descenso';

  @override
  String get plannerCanvas_rates_title => 'Tasas';

  @override
  String get plannerCanvas_range_title => 'Tabla de rangos';

  @override
  String get plannerCanvas_results_noDeco => 'No se requiere descompresión';

  @override
  String plannerCanvas_sac_useLogged(String sac) {
    return 'Usar promedio registrado ($sac)';
  }

  @override
  String plannerCanvas_saved_deleteConfirmBody(String name) {
    return '¿Eliminar permanentemente «$name»?';
  }

  @override
  String get plannerCanvas_saved_deleteConfirmTitle => '¿Eliminar plan?';

  @override
  String get plannerCanvas_saved_duplicate => 'Duplicar';

  @override
  String get plannerCanvas_saved_empty => 'Aún no hay planes guardados';

  @override
  String get plannerCanvas_saved_title => 'Planes guardados';

  @override
  String get plannerCanvas_name_dialogTitle => 'Nombra tu plan';

  @override
  String get plannerCanvas_name_defaultFallback => 'Plan de buceo';

  @override
  String plannerCanvas_scrub_bailout(String minutes) {
    return 'BO $minutes′';
  }

  @override
  String plannerCanvas_scrub_readout(String minutes, String depth) {
    return 'RT $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_share_import => 'Importar';

  @override
  String plannerCanvas_share_importFailed(String reason) {
    return 'No se pudo importar el plan: $reason';
  }

  @override
  String get plannerCanvas_share_menu => 'Compartir archivo del plan';

  @override
  String get plannerCanvas_slate_menu => 'Exportar pizarra (PDF)';

  @override
  String get plannerCanvas_slate_minGas => 'Gas mínimo';

  @override
  String get plannerCanvas_slate_turn => 'Retorno';

  @override
  String get plannerCanvas_table_depth => 'Profundidad';

  @override
  String get plannerCanvas_table_gas => 'Gas';

  @override
  String get plannerCanvas_table_runtime => 'RT';

  @override
  String get plannerCanvas_table_stop => 'Parada';

  @override
  String get plannerCanvas_turnRule_allUsable => 'Todo utilizable';

  @override
  String get plannerCanvas_turnRule_custom => 'Personalizada';

  @override
  String get plannerCanvas_turnRule_halves => 'Mitades';

  @override
  String get plannerCanvas_turnRule_none => 'Ninguna';

  @override
  String get plannerCanvas_turnRule_thirds => 'Tercios';

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
  String get planning_newPlan => 'Nuevo plan';

  @override
  String get planning_section_tools => 'Herramientas';

  @override
  String get planning_summary_prompt =>
      'Selecciona una herramienta para empezar';

  @override
  String get planning_summary_savedPlans => 'Planes guardados';

  @override
  String get planning_summary_noPlans => 'Aún no hay planes guardados';

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
  String get settings_about_reportIssue_copy => 'Copiar enlace';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Visita github.com/submersion-app/submersion/issues';

  @override
  String settings_about_version(String version) {
    return 'Version $version';
  }

  @override
  String get settings_appBar_title => 'Ajustes';

  @override
  String get settings_appearance_appLanguage => 'Idioma de la aplicacion';

  @override
  String get settings_appearance_displaySize => 'Tamaño de visualización';

  @override
  String settings_appearance_displaySize_value(int percent) {
    return '$percent%';
  }

  @override
  String get settings_appearance_displaySize_reset => 'Restablecer';

  @override
  String get settings_appearance_displaySize_smaller => 'Más pequeño';

  @override
  String get settings_appearance_displaySize_larger => 'Más grande';

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
  String get settings_appearance_gasTimeline => 'Cronología del gas';

  @override
  String get settings_appearance_gasTimeline_subtitle =>
      'Mostrar la franja de consumo de gas debajo del perfil de inmersión por defecto';

  @override
  String get settings_appearance_header_diveDetails => 'Detalles de Inmersion';

  @override
  String get settings_appearance_header_diveLog => 'Registro de buceo';

  @override
  String get settings_appearance_header_diveProfile => 'Perfil de inmersion';

  @override
  String get settings_appearance_header_diveSites => 'Puntos de buceo';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility =>
      'Orden y Visibilidad de Secciones';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility_subtitle =>
      'Elige que secciones se muestran y su orden';

  @override
  String get settings_diveDetailSections_title =>
      'Orden y Visibilidad de Secciones';

  @override
  String get settings_diveDetailSections_resetToDefault =>
      'Restablecer valores predeterminados';

  @override
  String get settings_diveDetailSections_fixedSections =>
      'Secciones fijas: Encabezado, Grafico de Perfil de Inmersion';

  @override
  String get settings_diveDetailSections_configurableSections =>
      'Secciones configurables (arrastra para reordenar)';

  @override
  String get diveDetailSection_decoO2_name => 'Estado Deco / Carga de Tejidos';

  @override
  String get diveDetailSection_decoO2_description =>
      'NDL, techo, mapa de calor de tejidos, toxicidad de O2';

  @override
  String get diveDetailSection_safetyReview_name => 'Revisión de seguridad';

  @override
  String get diveDetailSection_safetyReview_description =>
      'Observaciones automáticas del perfil tras la inmersión';

  @override
  String get safetyReview_sectionTitle => 'Revisión de seguridad';

  @override
  String safetyReview_findingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observaciones',
      one: '1 observación',
    );
    return '$_temp0';
  }

  @override
  String safetyReview_rapidAscent_title(String rate, String duration) {
    return 'El ascenso superó $rate durante $duration';
  }

  @override
  String safetyReview_missedDecoStop_title(String excess, String duration) {
    return 'La profundidad estuvo $excess por encima del techo de parada requerido durante $duration';
  }

  @override
  String safetyReview_omittedSafetyStop_title(String remaining) {
    return 'La parada de seguridad recomendada se acortó en $remaining';
  }

  @override
  String safetyReview_sawtoothProfile_title(int count) {
    return '$count cambios repetidos de profundidad de subida y bajada durante la inmersión';
  }

  @override
  String safetyReview_highSurfaceGf_title(String gf, String gfHigh) {
    return 'Salida a superficie con factor de gradiente $gf, por encima del $gfHigh configurado';
  }

  @override
  String safetyReview_timeRange(String start, String end) {
    return 'En $start–$end';
  }

  @override
  String get safetyReview_dismiss => 'Descartar';

  @override
  String get safetyReview_restore => 'Restaurar';

  @override
  String get safetyReview_dismissAll => 'Descartar todo';

  @override
  String get safetyReview_restoreAll => 'Restaurar todo';

  @override
  String get safetySettings_dismissAll => 'Descartar todas las observaciones';

  @override
  String get safetySettings_dismissAll_subtitle =>
      'Marcar como revisadas todas las observaciones de este cuaderno';

  @override
  String get safetySettings_dismissAll_confirmTitle =>
      '¿Descartar todas las observaciones?';

  @override
  String get safetySettings_dismissAll_confirmBody =>
      'Todas las observaciones de todas las inmersiones analizadas se marcarán como revisadas. Puedes restaurarlas inmersión por inmersión desde su sección de revisión de seguridad.';

  @override
  String get safetySettings_dismissAll_confirm => 'Descartar todo';

  @override
  String get safetySettings_dismissAll_cancel => 'Cancelar';

  @override
  String safetySettings_dismissAll_progress(int done, int total) {
    return '$done de $total inmersiones revisadas';
  }

  @override
  String safetySettings_dismissAll_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observaciones descartadas',
      one: '1 observación descartada',
      zero: 'No hay observaciones que descartar',
    );
    return '$_temp0';
  }

  @override
  String safetySettings_dismissAll_doneWithErrors(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observaciones descartadas',
      one: '1 observación descartada',
      zero: 'No se descartó ninguna observación',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: 'no se pudieron actualizar $failed inmersiones',
      one: 'no se pudo actualizar 1 inmersión',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get safetySettings_dismissAll_failed =>
      'No se pudo leer la lista de inmersiones. No se cambió nada.';

  @override
  String get safetySettings_analyzeAll_failed =>
      'No se pudieron analizar las inmersiones.';

  @override
  String get safetyReview_details => 'Detalles';

  @override
  String get safetyReview_clearHighlight => 'Quitar resaltado';

  @override
  String safetyReview_findingGroupSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observaciones de seguridad',
      one: '1 observación de seguridad',
    );
    return '$_temp0';
  }

  @override
  String get safetySettings_title => 'Revisión de seguridad';

  @override
  String get safetySettings_entry_subtitle =>
      'Observaciones y reglas tras la inmersión';

  @override
  String get safetySettings_masterToggle =>
      'Revisión de seguridad tras la inmersión';

  @override
  String get safetySettings_masterToggle_subtitle =>
      'Anotar automáticamente observaciones de ascenso, paradas y perfil en las inmersiones analizadas';

  @override
  String get safetySettings_rulesHeader => 'Reglas';

  @override
  String get safetySettings_rule_rapidAscent => 'Ascensos rápidos';

  @override
  String get safetySettings_rule_missedDecoStop =>
      'Paradas deco omitidas o acortadas';

  @override
  String get safetySettings_rule_omittedSafetyStop =>
      'Paradas de seguridad omitidas';

  @override
  String get safetySettings_rule_sawtoothProfile =>
      'Perfiles en dientes de sierra';

  @override
  String get safetySettings_rule_highSurfaceGf =>
      'Factor de gradiente alto al salir a superficie';

  @override
  String get safetySettings_analyzeAll => 'Analizar todas las inmersiones';

  @override
  String get safetySettings_analyzeAll_subtitle =>
      'Ejecutar la revisión de seguridad en todas las inmersiones con perfil que aún no se hayan analizado';

  @override
  String safetySettings_analyzeAll_progress(int done, int total) {
    return 'Analizadas $done de $total';
  }

  @override
  String get safetySettings_analyzeAll_done => 'Análisis completado';

  @override
  String safetySettings_analyzeAll_doneWithErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron analizar $count inmersiones',
      one: 'No se pudo analizar 1 inmersión',
    );
    return 'Análisis completado — $_temp0';
  }

  @override
  String safetyReview_showDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar $count descartadas',
      one: 'Mostrar 1 descartada',
    );
    return '$_temp0';
  }

  @override
  String get diveDetailSection_sacSegments_name => 'SAC Rate por Segmento';

  @override
  String get diveDetailSection_sacSegments_description =>
      'Segmentacion SAC por fase/tiempo';

  @override
  String get diveDetailSection_details_name => 'Detalles';

  @override
  String get diveDetailSection_details_description =>
      'Tipo, ubicacion, viaje, centro de buceo, intervalo';

  @override
  String get diveDetailSection_environment_name => 'Entorno';

  @override
  String get diveDetailSection_environment_description =>
      'Temperatura del aire/agua, visibilidad, corriente';

  @override
  String get diveDetailSection_altitude_name => 'Altitud';

  @override
  String get diveDetailSection_altitude_description =>
      'Valor de altitud, categoria, requisito de deco';

  @override
  String get diveDetailSection_tide_name => 'Marea';

  @override
  String get diveDetailSection_tide_description =>
      'Grafico del ciclo de mareas y temporalizacion';

  @override
  String get diveDetailSection_reefHealth_name => 'Condiciones del agua';

  @override
  String get diveDetailSection_reefHealth_description =>
      'Condiciones del agua por satélite en la fecha de la inmersión';

  @override
  String get diveDetailSection_surfaceGps_name => 'GPS de superficie';

  @override
  String get diveDetailSection_surfaceGps_description =>
      'Puntos de entrada/salida por GPS y deriva en superficie';

  @override
  String get diveLog_detail_section_surfaceGps => 'GPS de superficie';

  @override
  String get diveLog_detail_surfaceGps_entry => 'Entrada';

  @override
  String get diveLog_detail_surfaceGps_exit => 'Salida';

  @override
  String get diveLog_detail_label_drift => 'Deriva';

  @override
  String get diveLog_detail_surfaceGps_entryOnly =>
      'Punto de entrada registrado';

  @override
  String get diveLog_detail_surfaceGps_exitOnly => 'Punto de salida registrado';

  @override
  String get diveLog_detail_surfaceGps_site => 'Punto de buceo';

  @override
  String get diveLog_detail_surfaceGps_track => 'Track de superficie';

  @override
  String get diveLog_detail_surfaceGps_showFullTrack => 'Track completo';

  @override
  String diveLog_detail_surfaceGps_trackFixes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puntos',
      one: '1 punto',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_detail_locationsMap_title => 'Ubicaciones de buceo';

  @override
  String get diveLog_detail_coordinatesCopied =>
      'Coordenadas copiadas al portapapeles';

  @override
  String get diveLog_detail_openInMaps => 'Abrir en Mapas';

  @override
  String get diveDetailSection_weights_name => 'Lastres';

  @override
  String get diveDetailSection_weights_description =>
      'Desglose de pesos, peso total';

  @override
  String get diveDetailSection_buoyancy_name => 'Flotabilidad';

  @override
  String get diveDetailSection_buoyancy_description =>
      'Flotabilidad durante la inmersión, variación, lastre soltable';

  @override
  String get buoyancy_tooltip =>
      'Flotabilidad neta modelada durante la inmersión a partir del perfil, el consumo de gas y el equipo.';

  @override
  String buoyancy_verdictBuoyant(String depth, String amount) {
    return 'En tu última parada (~$depth) tenías unos $amount de flotabilidad';
  }

  @override
  String buoyancy_verdictHeavy(String depth, String amount) {
    return 'En tu última parada (~$depth) estabas unos $amount sobrelastrado';
  }

  @override
  String get buoyancy_verdictNeutral =>
      'Tu configuración estaba casi neutra en la última parada';

  @override
  String get buoyancy_verdictConvention =>
      'Estimado en la convención de parada de seguridad a 5 m';

  @override
  String get buoyancy_breakdownTitle => 'Desglose de términos';

  @override
  String get buoyancy_suitTerm => 'Traje';

  @override
  String get buoyancy_leadTerm => 'Lastre';

  @override
  String get buoyancy_beginNet => 'Inicio de la inmersión';

  @override
  String get buoyancy_endNet => 'Fin de la inmersión';

  @override
  String get buoyancy_swing => 'Variación de flotabilidad';

  @override
  String get buoyancy_peakLift => 'Sustentación máxima necesaria';

  @override
  String get buoyancy_wingWarning =>
      'Supera la sustentación nominal de tu wing';

  @override
  String get buoyancy_minDitchable => 'Lastre soltable mínimo';

  @override
  String get buoyancy_droppable => 'Puedes soltar';

  @override
  String get buoyancy_ditchWarning => 'Más de lo que puedes soltar';

  @override
  String get buoyancy_drysuitGas => 'Gas de traje seco añadido';

  @override
  String get buoyancy_estimatedPressures =>
      'Las presiones de botella son estimadas';

  @override
  String get buoyancy_linkSuitHint =>
      'Asocia un traje a esta inmersión para un panorama más completo';

  @override
  String get buoyancy_noLeadHint =>
      'No se registró lastre: añade lastre a esta inmersión o un peso en seco a tu equipo de lastre';

  @override
  String get buoyancy_chartNet => 'Neto';

  @override
  String get buoyancy_chartRig => 'Equipo + lastre';

  @override
  String get buoyancy_chartMinutes => 'Tiempo (min)';

  @override
  String get buoyancy_historyTitle => 'Historial de lastre';

  @override
  String get buoyancy_historyCarried => 'Llevado';

  @override
  String get buoyancy_historyModeled => 'Modelado';

  @override
  String buoyancy_historyMore(String delta) {
    return 'Sueles llevar $delta más de lo que sugiere el modelo';
  }

  @override
  String buoyancy_historyLess(String delta) {
    return 'Sueles llevar $delta menos de lo que sugiere el modelo';
  }

  @override
  String get buoyancy_throughDive => 'Durante la inmersión';

  @override
  String get buoyancy_adjust => 'Ajustar';

  @override
  String get buoyancy_whatIfTitle => 'Ajustar esta inmersión';

  @override
  String get buoyancy_whatIfLead => 'Lastre';

  @override
  String get buoyancy_whatIfSuit => 'Flotabilidad del traje';

  @override
  String get buoyancy_whatIfReset => 'Restablecer';

  @override
  String buoyancy_whatIfDelta(String delta) {
    return '$delta vs real';
  }

  @override
  String get diveDetailSection_tanks_name => 'Tanques';

  @override
  String get diveDetailSection_tanks_description =>
      'Lista de tanques, mezclas de gas, presiones, SAC por tanque';

  @override
  String get diveDetailSection_buddies_name => 'Companeros';

  @override
  String get diveDetailSection_buddies_description =>
      'Lista de companeros con roles';

  @override
  String get diveDetailSection_signatures_name => 'Firmas';

  @override
  String get diveDetailSection_signatures_description =>
      'Visualizacion y captura de firma de companero/instructor';

  @override
  String get diveDetailSection_equipment_name => 'Equipo';

  @override
  String get diveDetailSection_equipment_description =>
      'Equipo utilizado en la inmersion';

  @override
  String get diveDetailSection_sightings_name => 'Avistamientos de Vida Marina';

  @override
  String get diveDetailSection_sightings_description =>
      'Especies avistadas, detalles del avistamiento';

  @override
  String get diveDetailSection_media_name => 'Multimedia';

  @override
  String get diveDetailSection_media_description => 'Galeria de fotos/videos';

  @override
  String get diveDetailSection_tags_name => 'Etiquetas';

  @override
  String get diveDetailSection_tags_description => 'Etiquetas de la inmersion';

  @override
  String get diveDetailSection_notes_name => 'Notas';

  @override
  String get diveDetailSection_notes_description =>
      'Notas/descripcion de la inmersion';

  @override
  String get diveDetailSection_customFields_name => 'Campos Personalizados';

  @override
  String get diveDetailSection_customFields_description =>
      'Campos personalizados definidos por el usuario';

  @override
  String get diveDetailSection_dataSources_name => 'Fuentes de Datos';

  @override
  String get diveDetailSection_dataSources_description =>
      'Computadoras de buceo conectadas, gestion de fuentes';

  @override
  String get settings_appearance_header_language => 'Idioma';

  @override
  String get settings_appearance_header_theme => 'Tema';

  @override
  String get settings_appearance_header_mode => 'Modo';

  @override
  String get settings_themes_title => 'Elegir Tema';

  @override
  String get settings_themes_current => 'Tema';

  @override
  String get theme_submersion => 'Inmersion';

  @override
  String get theme_console => 'Consola';

  @override
  String get theme_tropical => 'Tropical';

  @override
  String get theme_minimalist => 'Minimalista';

  @override
  String get theme_deep => 'Profundo';

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
  String get settings_appearance_metric_estimatedTankPressure =>
      'Presión estimada del tanque';

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
  String get settings_appearance_metric_cns => 'CNS% (Toxicidad de O2)';

  @override
  String get settings_appearance_metric_otu =>
      'OTU (Unidades de Tolerancia al O2)';

  @override
  String get settings_appearance_metric_photoMarkers => 'Marcadores de fotos';

  @override
  String settings_appearance_metricsEnabledCount(int count, int total) {
    return '$count de $total habilitados';
  }

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
  String get settings_appearance_metricsFollowViewport =>
      'Mantener las superposiciones a la vista al hacer zoom';

  @override
  String get settings_appearance_metricsFollowViewport_subtitle =>
      'Ajustar las superposiciones como NDL y ppO2 al área visible en lugar de ampliarlas con el eje de profundidad';

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
  String get settings_appearance_subsection_standardMetrics =>
      'Standard Metrics';

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
  String get settings_backToSettings_tooltip => 'Volver a ajustes';

  @override
  String get settings_cloudSync_appBar_title =>
      'Sincronizacion de base de datos en la nube';

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
  String get settings_cloudSync_entry_subtitle =>
      'Sincronización mediante almacenamiento en la nube';

  @override
  String get settings_cloudSync_adopt_confirm =>
      'Adoptar la biblioteca restaurada';

  @override
  String settings_cloudSync_adopt_dialogContent(
    String deviceName,
    String date,
  ) {
    return 'La biblioteca se reemplazó desde una copia de seguridad en \"$deviceName\" ($date). Al adoptarla, los datos de este dispositivo se reemplazarán con la biblioteca restaurada. Primero se creará una copia de seguridad de los datos actuales de este dispositivo.';
  }

  @override
  String get settings_cloudSync_adopt_dialogTitle =>
      '¿Adoptar la biblioteca restaurada?';

  @override
  String get settings_cloudSync_adopt_notNow => 'Ahora no';

  @override
  String get settings_cloudSync_dangerZone => 'Zona de peligro';

  @override
  String get settings_cloudSync_replaceLibrary_tile =>
      'Reemplazar biblioteca en la nube';

  @override
  String get settings_cloudSync_replaceLibrary_tileSubtitle =>
      'Hacer que la biblioteca de este dispositivo sea la que usan todos los dispositivos';

  @override
  String get settings_cloudSync_replaceLibrary_dialogTitle =>
      '¿Reemplazar la biblioteca en la nube?';

  @override
  String get settings_cloudSync_replaceLibrary_dialogIntro =>
      'La biblioteca de este dispositivo pasa a ser la que usan todos los dispositivos.';

  @override
  String settings_cloudSync_replaceLibrary_dialogBody(num diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other:
          'La biblioteca en la nube se borra y se reemplaza por las $diveCount inmersiones de este dispositivo.',
      one:
          'La biblioteca en la nube se borra y se reemplaza por la 1 inmersión de este dispositivo.',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_replaceLibrary_peers(num peerCount) {
    String _temp0 = intl.Intl.pluralLogic(
      peerCount,
      locale: localeName,
      other:
          'Se pedirá a $peerCount dispositivos más que la adopten; hasta entonces, sus cambios no se combinan.',
      one:
          'Se pedirá a 1 dispositivo más que la adopte; hasta entonces, sus cambios no se combinan.',
      zero:
          'Todavía no se sincroniza ningún otro dispositivo, así que no hay nada que adoptar.',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_replaceLibrary_peersUnknown =>
      'Se pedirá a todos los demás dispositivos que la adopten; hasta entonces, sus cambios no se combinan.';

  @override
  String get settings_cloudSync_replaceLibrary_backupNote =>
      'Primero se crea una copia de seguridad de este dispositivo. Esta acción no se puede deshacer.';

  @override
  String get settings_cloudSync_replaceLibrary_confirmWord => 'Reemplazar';

  @override
  String get settings_cloudSync_replaceLibrary_confirmHint =>
      'Escribe \"Reemplazar\" para confirmar';

  @override
  String get settings_cloudSync_replaceLibrary_confirm => 'Reemplazar';

  @override
  String get settings_cloudSync_firstSync_banner =>
      'La primera sincronización está esperando confirmación. Toca \'Sincronizar ahora\' para revisar lo que se combinará.';

  @override
  String get settings_cloudSync_firstSync_dialogConfirm =>
      'Combinar y sincronizar';

  @override
  String get settings_cloudSync_firstSync_replaceHint =>
      'Si en cambio la biblioteca de este dispositivo debe reemplazar la de la nube, cancela y usa Ajustes > Sincronización en la nube > Reemplazar biblioteca en la nube.';

  @override
  String settings_cloudSync_firstSync_dialogContent(
    int deviceCount,
    int diveCount,
  ) {
    return 'Se encontraron datos de sincronización existentes en la nube ($deviceCount archivo(s) de sincronización). Tu primera sincronización combinará esos datos con las $diveCount inmersiones de este dispositivo, en todos los dispositivos sincronizados.\n\nSi las mismas inmersiones se agregaron por separado en cada dispositivo, aparecerán dos veces.';
  }

  @override
  String get settings_cloudSync_firstSync_dialogTitle =>
      '¿Combinar Bibliotecas?';

  @override
  String settings_cloudSync_replace_banner(String deviceName) {
    return 'Sincronización en pausa: la biblioteca se reemplazó desde una copia de seguridad en \"$deviceName\". Toca Sincronizar ahora para revisarla.';
  }

  @override
  String get settings_cloudSync_switch_dialogTitle =>
      '¿Cambiar el servicio de sincronización?';

  @override
  String settings_cloudSync_switch_dialogContent(
    String fromName,
    String toName,
  ) {
    return 'Tus datos no se moverán de $fromName: permanecen allí hasta que los elimines. Después de cambiar, la próxima sincronización de este dispositivo combina sus datos con lo que ya exista en $toName. Tus otros dispositivos siguen usando $fromName hasta que también cambies cada uno de ellos.';
  }

  @override
  String get settings_cloudSync_switch_confirm => 'Cambiar';

  @override
  String settings_cloudSync_moved_banner(
    String deviceName,
    String destination,
  ) {
    return '$deviceName movió esta biblioteca a $destination. Este servicio ya no se actualiza desde él. Selecciona $destination abajo para seguir el cambio.';
  }

  @override
  String get settings_cloudSync_moved_dismiss => 'Descartar';

  @override
  String settings_cloudSync_cleanup_banner(String backend) {
    return 'En $backend todavía se almacenan datos de sincronización antiguos de antes de que cambiaras de servicio. Ya no se usan.';
  }

  @override
  String get settings_cloudSync_cleanup_delete => 'Eliminar datos antiguos';

  @override
  String get settings_cloudSync_cleanup_keep => 'Conservar';

  @override
  String get settings_cloudSync_header_advanced => 'Avanzado';

  @override
  String get settings_cloudSync_signOut_backupWarning =>
      'La copia de seguridad en la nube se desactivará y las copias se guardarán en la ubicación predeterminada.';

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
  String settings_cloudSync_peerNeedsAdopt_banner(Object deviceList) {
    return '$deviceList todavía tiene una versión de biblioteca antigua o desconocida, por lo que sus cambios no se combinaron. Abre Submersion en él para adoptar la biblioteca actual.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_bannerPlural(Object deviceList) {
    return '$deviceList todavía tienen una versión de biblioteca antigua o desconocida, por lo que sus cambios no se combinaron. Abre Submersion en ellos para adoptar la biblioteca actual.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_unnamedDevice(Object shortId) {
    return 'dispositivo $shortId';
  }

  @override
  String get settings_cloudSync_peerNeedsAdopt_listSeparator => ', ';

  @override
  String get settings_cloudSync_peerNeedsAdopt_listLastSeparator => ' y ';

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamed(Object deviceList) {
    return '$deviceList sincroniza desde una versión más reciente de Submersion, por lo que sus últimos cambios quedan retenidos por ahora.';
  }

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(
    Object deviceList,
  ) {
    return '$deviceList sincronizan desde una versión más reciente de Submersion, por lo que sus últimos cambios quedan retenidos por ahora.';
  }

  @override
  String get settings_cloudSync_peerRequiresUpdate_updateAction =>
      'Actualiza este dispositivo para recibirlos.';

  @override
  String get settings_cloudSync_peerRequiresUpdate_storeAction =>
      'Se aplicarán automáticamente cuando llegue la actualización de la tienda de aplicaciones de este dispositivo; puede que aún esté en revisión.';

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
  String get settings_cloudSync_dropbox_account_title => 'Cuenta de Dropbox';

  @override
  String get settings_cloudSync_dropbox_connect_browserFailed =>
      'No se pudo abrir el navegador. Prueba el botón Reabrir navegador.';

  @override
  String get settings_cloudSync_dropbox_connect_codeLabel =>
      'Código de autorización';

  @override
  String get settings_cloudSync_dropbox_connect_emptyCode =>
      'Introduce el código de autorización que aparece en tu navegador';

  @override
  String settings_cloudSync_dropbox_connect_failed(Object error) {
    return 'No se pudo conectar con Dropbox: $error';
  }

  @override
  String get settings_cloudSync_dropbox_connect_instructions =>
      'Tu navegador abrió una página de autorización de Dropbox. Aprueba el acceso y luego pega aquí el código que te muestra Dropbox.';

  @override
  String get settings_cloudSync_dropbox_connect_reopenBrowser =>
      'Reabrir navegador';

  @override
  String get settings_cloudSync_dropbox_connect_submit => 'Conectar';

  @override
  String get settings_cloudSync_dropbox_connect_title => 'Conectar Dropbox';

  @override
  String get settings_cloudSync_dropbox_connected => 'Conectado a Dropbox';

  @override
  String settings_cloudSync_dropbox_connectedAs(Object account) {
    return 'Conectado como $account';
  }

  @override
  String get settings_cloudSync_dropbox_disconnect => 'Desconectar';

  @override
  String get settings_cloudSync_provider_dropbox_subtitle =>
      'Sincronizar via Dropbox (Apps/Submersion)';

  @override
  String get settings_cloudSync_provider_dropbox_title => 'Dropbox';

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Sincronizar via Google Drive';

  @override
  String get settings_cloudSync_googleDrive_desktopNotConfigured =>
      'No disponible en esta versión';

  @override
  String get settings_cloudSync_googleDrive_browserWait_title =>
      'Continúa en tu navegador';

  @override
  String get settings_cloudSync_googleDrive_browserWait_message =>
      'Termina de iniciar sesión en Google en tu navegador web y luego vuelve a Submersion.';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Error al inicializar el proveedor $providerName';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'No disponible en esta plataforma';

  @override
  String get settings_cloudSync_provider_s3_edit =>
      'Editar configuración de S3';

  @override
  String get settings_cloudSync_provider_s3_subtitle =>
      'Funciona con cualquier servicio de almacenamiento compatible con S3';

  @override
  String get settings_cloudSync_provider_s3_title =>
      'Almacenamiento compatible con S3';

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
  String get settings_conflict_ref_buddy => 'Compañero';

  @override
  String get settings_conflict_ref_certification => 'Certificacion';

  @override
  String get settings_conflict_ref_checklistTemplate =>
      'Plantilla de lista de verificacion';

  @override
  String get settings_conflict_ref_connectedAccount => 'Cuenta conectada';

  @override
  String get settings_conflict_ref_course => 'Curso';

  @override
  String get settings_conflict_ref_courseRequirement => 'Requisito del curso';

  @override
  String get settings_conflict_ref_cylinderConfig =>
      'Configuracion de botellas';

  @override
  String get settings_conflict_ref_dataSource => 'Fuente de datos';

  @override
  String get settings_conflict_ref_dive => 'Inmersion';

  @override
  String get settings_conflict_ref_diveCenter => 'Centro de buceo';

  @override
  String get settings_conflict_ref_diveComputer => 'Ordenador de buceo';

  @override
  String get settings_conflict_ref_divePlan => 'Plan de buceo';

  @override
  String get settings_conflict_ref_diveSite => 'Punto de buceo';

  @override
  String get settings_conflict_ref_diveType => 'Tipo de inmersion';

  @override
  String get settings_conflict_ref_diver => 'Buceador';

  @override
  String get settings_conflict_ref_equipment => 'Equipo';

  @override
  String get settings_conflict_ref_equipmentSet => 'Conjunto de equipo';

  @override
  String get settings_conflict_ref_finding => 'Hallazgo';

  @override
  String get settings_conflict_ref_instructor => 'Instructor';

  @override
  String get settings_conflict_ref_linkedDive => 'Inmersion vinculada';

  @override
  String get settings_conflict_ref_media => 'Multimedia';

  @override
  String get settings_conflict_ref_mediaSubscription =>
      'Suscripcion multimedia';

  @override
  String get settings_conflict_ref_missing => 'Ya no esta en esta biblioteca';

  @override
  String settings_conflict_ref_named(Object name, Object date) {
    return '$name ($date)';
  }

  @override
  String get settings_conflict_ref_plannedTank => 'Tanque planificado';

  @override
  String get settings_conflict_ref_preDiveChecklistTemplate =>
      'Plantilla de lista previa a la inmersion';

  @override
  String get settings_conflict_ref_preDiveSession =>
      'Lista previa a la inmersion';

  @override
  String get settings_conflict_ref_relatedDive => 'Inmersion relacionada';

  @override
  String get settings_conflict_ref_serviceKind => 'Tipo de servicio';

  @override
  String get settings_conflict_ref_sighting => 'Avistamiento';

  @override
  String get settings_conflict_ref_signer => 'Firmado por';

  @override
  String get settings_conflict_ref_sourceDive => 'Inmersion de origen';

  @override
  String get settings_conflict_ref_species => 'Especies';

  @override
  String get settings_conflict_ref_tag => 'Etiqueta';

  @override
  String get settings_conflict_ref_tank => 'Tanque';

  @override
  String get settings_conflict_ref_trip => 'Viaje';

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
  String get settings_data_backup => 'Respaldo y Restauracion';

  @override
  String get settings_data_backup_subtitle => 'Crear un respaldo de tus datos';

  @override
  String get settings_data_cloudSync =>
      'Sincronizacion de base de datos en la nube';

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
  String get settings_decompression_header_oxygenToxicity =>
      'Toxicidad del oxígeno';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Seleccionar preajuste de conservadurismo $presetName';
  }

  @override
  String get settings_decompression_header_narcosis => 'Narcosis';

  @override
  String get settings_decompression_o2Narcotic => 'O2 es narcotico';

  @override
  String get settings_decompression_o2Narcotic_subtitle =>
      'Cuando esta activado, tanto O2 como N2 se consideran narcoticos (mas conservador). Cuando esta desactivado, solo N2 contribuye a la narcosis.';

  @override
  String get settings_decompression_endLimit => 'Limite END';

  @override
  String get settings_decompression_endLimit_subtitle =>
      'Profundidad narcotica equivalente maxima utilizada para calculos de MND';

  @override
  String get settings_decompression_endLimit_dialog_title => 'Limite END';

  @override
  String get settings_decompression_cnsMethodTitle => 'Cálculo de CNS';

  @override
  String get settings_decompression_cnsMethodClassic =>
      'Tabla NOAA, escalonada (clásico)';

  @override
  String get settings_decompression_cnsMethodClassicDesc =>
      'Calcula cada banda de 0,1 bar en su extremo más estricto. Método original de Submersion.';

  @override
  String get settings_decompression_cnsMethodShearwater =>
      'Interpolación lineal (estilo Shearwater)';

  @override
  String get settings_decompression_cnsMethodShearwaterDesc =>
      'Interpola entre los límites de NOAA según lo documentado por Shearwater. Coincide con la mayoría de las computadoras de buceo.';

  @override
  String get settings_decompression_cnsMethodSubsurface =>
      'Ajuste exponencial (como Subsurface)';

  @override
  String get settings_decompression_cnsMethodSubsurfaceDesc =>
      'Ajuste de curva suave a la tabla NOAA. Coincide con el CNS calculado por Subsurface.';

  @override
  String get settings_decompression_cnsMethodAboutTitle =>
      'Acerca de estos métodos';

  @override
  String get settings_decompression_cnsMethodAboutBody =>
      'Los tres métodos se basan en los límites de exposición al oxígeno del NOAA Diving Manual (300 minutos con un ppO2 de 1,0 bar, 45 minutos a 1,6 bar). La tabla solo define límites en pasos de 0,1 bar: el método clásico calcula todo lo que hay dentro de una banda en el extremo más estricto de la banda, lo que sobrestima sistemáticamente la exposición entre las entradas. Las computadoras de buceo de Shearwater documentan una interpolación lineal entre los límites de NOAA, con un 15 % fijo por minuto por encima de 1,65 bar. En 2019, Subsurface reemplazó su búsqueda en tabla por un ajuste exponencial suave de dos tramos a los mismos datos de NOAA (Robert C. Helling), que también se extiende de forma natural más allá de 1,6 bar. Entre las entradas de la tabla, los dos métodos suaves coinciden con una diferencia de aproximadamente un punto de CNS; el método clásico muestra valores más altos.';

  @override
  String get settings_decompression_cnsMethodDisclaimer =>
      'Los nombres se refieren a los métodos publicados de los respectivos proyectos y fabricantes; no implican ninguna afiliación ni respaldo. Los valores calculados pueden diferir de las lecturas reales de la computadora de buceo.';

  @override
  String get settings_decompression_cnsMethodSourcesTitle => 'Fuentes';

  @override
  String get settings_linkOpenFailed => 'No se pudo abrir el enlace.';

  @override
  String get settings_decompression_cnsMethodSourceNoaa =>
      'NOAA: Diving Program (editor del NOAA Diving Manual)';

  @override
  String get settings_decompression_cnsMethodSourceShearwater =>
      'Shearwater: El reloj de oxígeno CNS';

  @override
  String get settings_decompression_cnsMethodSourceTheoreticalDiver =>
      'The Theoretical Diver: Cálculo de la toxicidad CNS del oxígeno';

  @override
  String get settings_decompression_cnsMethodSourceSubsurface =>
      'Subsurface: implementación (divelist.cpp)';

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
  String get settings_import_cancelButton => 'Cancelar importacion';

  @override
  String get settings_import_cancelling => 'Cancelando...';

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
  String get settings_import_phase_courses => 'Importing courses...';

  @override
  String get settings_import_phase_applyingTags => 'Applying tags...';

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
  String get settings_lightroom_albumFilter_all => 'Catálogo completo';

  @override
  String get settings_lightroom_albumFilter_title => 'Álbumes a escanear';

  @override
  String get settings_lightroom_autoPoll_title =>
      'Buscar fotos nuevas automáticamente';

  @override
  String settings_lightroom_clientId_help(String redirectUri) {
    return 'Crea una integración en la Adobe Developer Console con la API de Lightroom Services y un tipo de credencial compatible con PKCE. Introduce a continuación la URI de redirección de tu credencial (las credenciales de Native App usan un esquema personalizado) o déjala en blanco para usar $redirectUri.';
  }

  @override
  String get settings_lightroom_clientId_label => 'ID de cliente de Adobe';

  @override
  String get settings_lightroom_clientSecret_label =>
      'Secreto de cliente (opcional)';

  @override
  String get settings_lightroom_redirectUri_label =>
      'URI de redirección (opcional)';

  @override
  String get settings_lightroom_connect => 'Conectar Lightroom';

  @override
  String get settings_lightroom_connectEmbedded => 'Conectar con Adobe';

  @override
  String get settings_lightroom_advancedByo =>
      'Usa tus propias credenciales de Adobe';

  @override
  String get settings_lightroom_connect_codeLabel => 'URL redirigida o código';

  @override
  String get settings_lightroom_connect_emptyCode =>
      'Pega la URL redirigida o el código de autorización';

  @override
  String settings_lightroom_connect_failed(String error) {
    return 'No se pudo conectar con Lightroom: $error';
  }

  @override
  String get settings_lightroom_connect_instructions =>
      'Inicia sesión en Adobe en la ventana del navegador y pega la dirección completa de la página a la que llegas (contiene el código de autorización).';

  @override
  String get settings_lightroom_connect_reopenBrowser => 'Reabrir navegador';

  @override
  String get settings_lightroom_connect_submit => 'Conectar';

  @override
  String get settings_lightroom_connect_title => 'Conectar Lightroom';

  @override
  String settings_lightroom_connected(String name) {
    return 'Conectado como $name';
  }

  @override
  String get settings_lightroom_disconnect => 'Desconectar';

  @override
  String get settings_lightroom_disconnect_confirmBody =>
      'Las fotos vinculadas permanecen en tus inmersiones y se siguen mostrando desde el almacén de medios. Las fotos nuevas ya no se vincularán.';

  @override
  String get settings_lightroom_disconnect_confirmTitle =>
      '¿Desconectar Lightroom?';

  @override
  String settings_lightroom_lastPoll(String when) {
    return 'Última comprobación: $when';
  }

  @override
  String get settings_lightroom_needsReauth => 'Reconexión necesaria';

  @override
  String get settings_lightroom_scanNow => 'Escanear Lightroom';

  @override
  String get settings_lightroom_scan_running => 'Escaneando Lightroom...';

  @override
  String settings_lightroom_scan_summary(
    int attached,
    int suggested,
    int skipped,
  ) {
    return '$attached vinculadas, $suggested sugeridas, $skipped ya vinculadas';
  }

  @override
  String get settings_lightroom_subtitle =>
      'Vincular automáticamente fotos y vídeos a inmersiones';

  @override
  String get settings_lightroom_title => 'Adobe Lightroom';

  @override
  String get settings_manage_checklistTemplates =>
      'Plantillas de listas de verificación';

  @override
  String get settings_manage_checklistTemplates_subtitle =>
      'Listas de tareas reutilizables para planificar viajes';

  @override
  String get settings_manage_diveRoles => 'Roles de buceo';

  @override
  String get settings_manage_diveRoles_subtitle =>
      'Administrar roles de buceo personalizados';

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
  String get settings_manage_tags => 'Etiquetas';

  @override
  String get settings_manage_tags_subtitle =>
      'Administrar, fusionar y eliminar etiquetas';

  @override
  String get settings_manage_tankPresets => 'Preajustes de tanques';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Administrar configuraciones de tanques personalizadas';

  @override
  String get settings_manage_serviceTypes => 'Tipos de servicio';

  @override
  String get settings_manage_serviceTypes_subtitle =>
      'Mantenimiento que necesita tu equipo y con qué frecuencia';

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
  String get settings_notifications_disabled_continueButton => 'Continuar';

  @override
  String get settings_notifications_disabled_openSettingsButton =>
      'Abrir ajustes';

  @override
  String get settings_notifications_disabled_subtitleUnrequested =>
      'Los recordatorios de servicio necesitan permiso para enviar notificaciones';

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
  String get settings_profileHub_addNewDiver => 'Agregar Nuevo Buceador';

  @override
  String get settings_profileHub_cannotDeleteOnly =>
      'No se puede eliminar el unico perfil de buceador';

  @override
  String get settings_profileHub_createDiverTitle => 'Crear Buceador';

  @override
  String settings_profileHub_deleteConfirmContent(String name) {
    return 'Estas seguro de que deseas eliminar a $name? Todos los registros de inmersion asociados quedaran sin asignar.';
  }

  @override
  String get settings_profileHub_deleteConfirmTitle => 'Eliminar Buceador?';

  @override
  String get settings_profileHub_deleteDiver => 'Eliminar Buceador';

  @override
  String get settings_profileHub_deleted => 'Buceador eliminado';

  @override
  String get settings_profileHub_emergencyContacts => 'Contactos de Emergencia';

  @override
  String settings_profileHub_emergencyContacts_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contactos configurados',
      one: '1 contacto configurado',
      zero: 'No configurado',
    );
    return '$_temp0';
  }

  @override
  String get settings_profileHub_insurance => 'Seguro';

  @override
  String get settings_profileHub_insurance_expired => 'Expirado';

  @override
  String get settings_profileHub_insurance_notSet => 'No configurado';

  @override
  String get settings_profileHub_medicalInfo => 'Informacion Medica';

  @override
  String get settings_profileHub_medicalInfo_notSet => 'No configurado';

  @override
  String get settings_profileHub_notes => 'Notas';

  @override
  String get settings_profileHub_notes_notSet => 'No configurado';

  @override
  String get settings_profileHub_personalInfo => 'Informacion Personal';

  @override
  String get settings_profileHub_personalInfo_notSet => 'No configurado';

  @override
  String get settings_profileHub_saved => 'Cambios guardados';

  @override
  String get settings_profileHub_switchDiver => 'Cambiar de Buceador';

  @override
  String get settings_s3Config_action_remove => 'Eliminar configuración';

  @override
  String get settings_s3Config_action_testConnection => 'Probar conexión';

  @override
  String get settings_s3Config_advanced_title => 'Avanzado';

  @override
  String get settings_s3Config_appBar_title =>
      'Almacenamiento compatible con S3';

  @override
  String get settings_s3Config_error_secureStorage =>
      'No se pudo acceder al almacenamiento seguro';

  @override
  String get settings_s3Config_field_accessKeyId_label => 'Access Key ID';

  @override
  String get settings_s3Config_field_bucket_label => 'Bucket';

  @override
  String get settings_s3Config_field_endpoint_helper =>
      'Por ejemplo: https://s3.example.com';

  @override
  String get settings_s3Config_field_endpoint_label => 'URL del endpoint';

  @override
  String get settings_s3Config_field_pathStyle_label =>
      'Usar direccionamiento path-style';

  @override
  String get settings_s3Config_field_pathStyle_subtitle =>
      'Requerido por la mayoría de los servidores autoalojados';

  @override
  String get settings_s3Config_field_prefix_label => 'Prefijo de claves';

  @override
  String settings_s3Config_field_region_helperAuto(String region) {
    return 'Detectado automáticamente: $region';
  }

  @override
  String get settings_s3Config_field_region_label => 'Región';

  @override
  String get settings_s3Config_field_secretAccessKey_label =>
      'Secret Access Key';

  @override
  String get settings_s3Config_remove_confirm_action => 'Eliminar';

  @override
  String get settings_s3Config_remove_confirm_body =>
      'La sincronización mediante S3 se detendrá en este dispositivo. Los datos del bucket no se eliminan.';

  @override
  String get settings_s3Config_remove_confirm_title =>
      '¿Eliminar la configuración de S3?';

  @override
  String get settings_s3Config_removed => 'Configuración de S3 eliminada';

  @override
  String get settings_s3Config_saved => 'Configuración de S3 guardada';

  @override
  String settings_s3Config_test_regionDetected(String region) {
    return 'Región detectada: $region';
  }

  @override
  String get settings_s3Config_test_success => 'Conexión correcta';

  @override
  String get settings_s3Config_validation_endpointInvalid =>
      'Introduce una URL http:// o https:// válida';

  @override
  String get settings_s3Config_validation_endpointPath =>
      'La URL del endpoint no debe incluir una ruta';

  @override
  String get settings_s3Config_validation_required => 'Obligatorio';

  @override
  String get settings_s3Config_warning_http =>
      'Este endpoint usa HTTP sin cifrar. Las credenciales y los datos de buceo viajarán sin cifrar; úselo solo en una red de confianza.';

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
  String get settings_storage_customFolder_subtitleDeviceOnly =>
      'Mueve la base de datos al almacenamiento interno o a la tarjeta SD';

  @override
  String get settings_storage_customFolder_deviceOnly_noCloudSync =>
      'La sincronización en la nube gestionada por la app está desactivada mientras la base de datos esté en un volumen de almacenamiento del dispositivo. Ningún servicio de sincronización puede acceder a esa carpeta en Android, así que usa Copia de Seguridad y Restaurar para guardar copias en otro lugar.';

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
  String get settings_storage_dangerZone => 'Zona de Peligro';

  @override
  String get settings_storage_resetDatabase => 'Restablecer Base de Datos';

  @override
  String get settings_storage_resetDatabase_subtitle =>
      'Eliminar todos los datos de este dispositivo y comenzar de nuevo';

  @override
  String get settings_storage_resetDialog_title => 'Restablecer Base de Datos?';

  @override
  String get settings_storage_resetDialog_body =>
      'Esto elimina permanentemente todos los datos de ESTE dispositivo, incluidas inmersiones, puntos, equipo y configuraciones. Se crea una copia de seguridad automáticamente antes de restablecer.\n\nTu biblioteca en la nube no se elimina y los demás dispositivos conservan sus datos. La sincronización en la nube se desconectará para que el restablecimiento no se deshaga; puedes volver a conectarla en Ajustes > Sincronización en la nube.';

  @override
  String get settings_storage_resetDialog_confirmWord => 'Eliminar';

  @override
  String get settings_storage_resetDialog_confirmHint =>
      'Escribe \"Eliminar\" para confirmar';

  @override
  String get settings_storage_resetDialog_confirmButton => 'Restablecer';

  @override
  String get settings_storage_resetDialog_backupFailed =>
      'La copia de seguridad fallo. El restablecimiento se aborto para proteger tus datos.';

  @override
  String settings_storage_resetDialog_resetFailed(Object error) {
    return 'El restablecimiento fallo: $error';
  }

  @override
  String get settings_storage_resetComplete_title =>
      'Base de Datos Restablecida';

  @override
  String get settings_storage_resetComplete_description =>
      'Los datos de este dispositivo se han eliminado y se guardó una copia de seguridad. La sincronización en la nube está ahora desconectada para que el restablecimiento no se deshaga; puedes volver a conectarla en Ajustes > Sincronización en la nube. Toca continuar para recargar la app.';

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
  String get settings_units_gasModel => 'Cálculos de gas';

  @override
  String get settings_units_gasModel_real => 'Gas real';

  @override
  String get settings_units_gasModel_real_subtitle =>
      'Tiene en cuenta la compresibilidad. Una botella de 12 L a 200 bar contiene unos 2317 L.';

  @override
  String get settings_units_gasModel_ideal => 'Gas ideal';

  @override
  String get settings_units_gasModel_ideal_subtitle =>
      'Coincide con el cálculo manual y las tablas. Una botella de 12 L a 200 bar contiene 2400 L.';

  @override
  String get settings_units_gasModel_explanation =>
      'Cómo se convierte la presión de la botella en volumen de gas. Afecta al RMV, las estadísticas de gas, el planificador y las calculadoras. El gas ideal coincide con el cálculo que enseñan las agencias; el gas real es físicamente exacto y da un RMV un 5 % menor aproximadamente.';

  @override
  String get settings_units_dialog_gasModel => 'Cálculos de gas';

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
  String get settings_units_defaultCurrency => 'Moneda predeterminada';

  @override
  String get settings_units_dialog_defaultCurrency => 'Moneda predeterminada';

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
  String get settings_updates_automaticUpdates => 'Actualizaciones automáticas';

  @override
  String get settings_updates_automaticUpdatesSubtitle =>
      'Buscar actualizaciones periódicamente';

  @override
  String get settings_updates_betaDialogBody =>
      'Las versiones beta se publican con cada cambio y pueden actualizar la base de datos de tu registro de buceo antes que la versión estable. Volver luego al canal estable no revertirá la app a una versión anterior, y todos los dispositivos que se sincronizan entre sí deberían usar el mismo canal. Se realiza una copia de seguridad automáticamente antes de cualquier actualización de la base de datos.';

  @override
  String get settings_updates_betaDialogConfirm => 'Cambiar a Beta';

  @override
  String get settings_updates_betaDialogTitle =>
      '¿Recibir actualizaciones beta?';

  @override
  String get settings_updates_channel => 'Canal de actualizaciones';

  @override
  String settings_updates_channelBadgeBeta(String version) {
    return '$version (Beta)';
  }

  @override
  String get settings_updates_channelBeta => 'Beta';

  @override
  String get settings_updates_channelBetaSubtitle =>
      'Nuevas versiones con cada cambio, por delante de la estable';

  @override
  String get settings_updates_channelStable => 'Estable';

  @override
  String get settings_updates_channelStableSubtitle =>
      'Solo versiones probadas';

  @override
  String get settings_updates_checkForUpdates => 'Buscar actualizaciones';

  @override
  String get settings_updates_checking => 'Comprobando...';

  @override
  String settings_updates_downloading(String progress) {
    return 'Descargando... $progress%';
  }

  @override
  String settings_updates_error(String message) {
    return 'Error: $message';
  }

  @override
  String get settings_updates_header => 'Actualizaciones';

  @override
  String get settings_updates_joinBeta => 'Únete a la Beta';

  @override
  String get settings_updates_joinBetaSubtitle =>
      'Recibe nuevas funciones antes a través del programa beta';

  @override
  String get settings_updates_lastChecked => 'Última comprobación';

  @override
  String get settings_updates_never => 'Nunca';

  @override
  String settings_updates_readyToInstall(String version) {
    return 'Versión $version lista para instalar';
  }

  @override
  String get settings_updates_stableSwitchNotice =>
      'Permanecerás en esta beta hasta que la próxima versión estable sea más reciente que ella.';

  @override
  String get settings_updates_upToDate => 'Actualizado';

  @override
  String settings_updates_versionAvailable(String version) {
    return 'Versión $version disponible';
  }

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
  String get statistics_category_overview_title => 'Overview';

  @override
  String get statistics_category_overview_subtitle =>
      'Totals, records, and breakdowns at a glance';

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
  String get statistics_filterBar_clear => 'Borrar filtro';

  @override
  String statistics_filterBar_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones',
      one: '1 inmersión',
    );
    return '$_temp0';
  }

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
  String get statistics_profile_deco_notRecorded => 'Sin registrar';

  @override
  String statistics_profile_deco_notRecordedHint(int count) {
    return '$count inmersiones no tienen datos de descompresión registrados ni calculables y se excluyen de la tasa';
  }

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
  String get statistics_tooltip_filter => 'Filtrar estadísticas';

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
  String surfaceInterval_gasWarning_modExceeded(
    Object ppO2,
    Object depth,
    Object limit,
    Object mod,
  ) {
    return 'ppO₂ $ppO2 a $depth supera $limit. La MOD de esta mezcla es $mod.';
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
  String surfaceInterval_result_beyondHorizon(Object hours) {
    return 'La espera supera las $hours horas que busca este planificador. La desaturación continúa, así que un intervalo de superficie más largo lo conseguirá.';
  }

  @override
  String surfaceInterval_result_beyondHorizonShort(Object hours) {
    return 'Más de $hours horas';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Intervalo Actual';

  @override
  String get surfaceInterval_result_gasUnsafe =>
      'Gas inseguro a esta profundidad';

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
  String surfaceInterval_result_noIntervalHelps(Object minutes) {
    return 'Ningún intervalo de superficie es suficiente. La inmersión sin descompresión más larga a esta profundidad con esta mezcla es de $minutes min. Acorta la segunda inmersión o reduce su profundidad.';
  }

  @override
  String get surfaceInterval_result_notAchievable =>
      'No alcanzable con ningún intervalo de superficie';

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
  String surfaceInterval_secondDive_heSemantics(Object percent) {
    return 'Helio segunda inmersión: $percent%';
  }

  @override
  String surfaceInterval_secondDive_o2Semantics(Object percent) {
    return 'O2 segunda inmersión: $percent%';
  }

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
  String get tags_action_browse => 'Explorar';

  @override
  String get tags_picker_title => 'Elegir etiquetas';

  @override
  String get tags_picker_empty =>
      'Aún no hay etiquetas. Escribe un nombre para crear la primera.';

  @override
  String tags_picker_errorLoading(String error) {
    return 'Error al cargar las etiquetas: $error';
  }

  @override
  String get tags_picker_allAdded => 'Todas las etiquetas ya están añadidas.';

  @override
  String get tags_picker_noMatches =>
      'Ninguna etiqueta coincide con tu búsqueda.';

  @override
  String tags_picker_addCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Añadir $count etiquetas',
      one: 'Añadir 1 etiqueta',
      zero: 'Añadir etiquetas',
    );
    return '$_temp0';
  }

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
  String get importWizard_tagsLabel => 'Tags';

  @override
  String get importWizard_photos_stepLabel => 'Fotos';

  @override
  String importWizard_photos_foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos referenciadas en este cuaderno',
      one: '1 foto referenciada en este cuaderno',
    );
    return '$_temp0';
  }

  @override
  String get importWizard_photos_chooseFolder => 'Elegir carpeta de fotos...';

  @override
  String get importWizard_photos_scanning => 'Explorando la carpeta...';

  @override
  String importWizard_photos_matchSummary(
    int matched,
    int byName,
    int missing,
  ) {
    return '$matched coincidencias, $byName solo por nombre de archivo, $missing no encontradas';
  }

  @override
  String get importWizard_photos_skip => 'Omitir fotos';

  @override
  String get importWizard_photos_mobileUnsupported =>
      'Importar fotos requiere una carpeta en el disco de este dispositivo. Ejecuta esta importación en un ordenador para incluirlas. Las inmersiones y los puntos de buceo se importan con normalidad.';

  @override
  String importWizard_review_olderDivesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones antiguas omitidas — ya están en tu registro',
      one: '1 inmersión antigua omitida — ya está en tu registro',
    );
    return '$_temp0';
  }

  @override
  String get tags_hint_addTags => 'Agregar etiquetas...';

  @override
  String get tags_manage_title => 'Etiquetas';

  @override
  String get tags_manage_searchHint => 'Buscar etiquetas...';

  @override
  String tags_manage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones',
      one: '1 inmersion',
      zero: '0 inmersiones',
    );
    return '$_temp0';
  }

  @override
  String get tags_manage_emptyState =>
      'Aun no hay etiquetas. Crea una para empezar.';

  @override
  String tags_manage_selectedCount(int count) {
    return '$count seleccionadas';
  }

  @override
  String get tags_manage_createTitle => 'Crear Etiqueta';

  @override
  String get tags_manage_editTitle => 'Editar Etiqueta';

  @override
  String get tags_manage_nameLabel => 'Nombre de Etiqueta';

  @override
  String get tags_manage_colorLabel => 'Color';

  @override
  String get tags_manage_nameRequired =>
      'El nombre de la etiqueta es obligatorio';

  @override
  String get tags_manage_deleteTitle => 'Eliminar Etiqueta?';

  @override
  String tags_manage_deleteMessage(String tagName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones',
      one: '1 inmersion',
      zero: '0 inmersiones',
    );
    return '\"$tagName\" se eliminara de $_temp0. Esta accion no se puede deshacer.';
  }

  @override
  String tags_manage_bulkDeleteTitle(int count) {
    return 'Eliminar $count Etiquetas?';
  }

  @override
  String tags_manage_bulkDeleteMessage(int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount inmersiones',
      one: '1 inmersion',
      zero: '0 inmersiones',
    );
    return 'Estas etiquetas se eliminaran de $_temp0 en total. Esta accion no se puede deshacer.';
  }

  @override
  String tags_manage_mergeTitle(int count) {
    return 'Fusionar $count Etiquetas';
  }

  @override
  String get tags_manage_mergeResultName => 'Nombre resultante de la etiqueta:';

  @override
  String get tags_manage_mergeKeepFrom => 'O conservar nombre de:';

  @override
  String tags_manage_mergeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones',
      one: '1 inmersion',
      zero: '0 inmersiones',
    );
    return 'Esto afectara a $_temp0 en total.';
  }

  @override
  String get tags_manage_mergeAction => 'Fusionar';

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
  String tides_source_noaaStation(String name, String distance) {
    return 'Estación NOAA: $name ($distance)';
  }

  @override
  String get tides_source_modelEstimate => 'Estimación de modelo oceánico';

  @override
  String get tides_source_modelCaveat =>
      'Modelado a partir de datos satelitales. Las horas y alturas pueden diferir cerca de costas complejas.';

  @override
  String get tides_source_sheetTitle => 'Fuente de datos de mareas';

  @override
  String get tides_source_datumMllw =>
      'Alturas relativas a MLLW (datum de la estación)';

  @override
  String get tides_source_datumMsl =>
      'Alturas relativas al nivel medio del mar';

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
      'Import dives via Apple HealthKit';

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
  String transfer_computers_diveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones',
      one: '1 inmersión',
    );
    return '$_temp0';
  }

  @override
  String get transfer_computers_downloadTooltip => 'Descargar inmersiones';

  @override
  String get transfer_computers_knownComputersHeader => 'Ordenadores conocidos';

  @override
  String transfer_computers_lastDownloadDaysAgo(int days) {
    return 'hace $days días';
  }

  @override
  String transfer_computers_lastDownloadHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'hace $hours horas',
      one: 'hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String transfer_computers_lastDownloadMinutesAgo(int minutes) {
    return 'hace $minutes min';
  }

  @override
  String get transfer_computers_lastDownloadNever => 'Nunca';

  @override
  String get transfer_computers_lastDownloadYesterday => 'Ayer';

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
  String get transfer_export_backupLink =>
      'Ir a Copia de seguridad y restauración';

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
  String get transfer_import_fileImportSemanticLabel =>
      'Importar datos con deteccion automatica';

  @override
  String get transfer_import_fileImportSubtitle =>
      'Detecta automaticamente CSV, UDDF, FIT y mas';

  @override
  String get transfer_import_fileImportTitle => 'Importar datos';

  @override
  String get transfer_import_sectionHeader => 'Importar datos';

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
  String get trips_detail_stat_totalRuntime => 'Tiempo total';

  @override
  String get trips_detail_stat_totalDives => 'Total de inmersiones';

  @override
  String get trips_detail_tab_checklist => 'Lista de verificación';

  @override
  String get trips_detail_tooltip_edit => 'Editar viaje';

  @override
  String get trips_detail_tooltip_editShort => 'Editar';

  @override
  String get trips_detail_tooltip_moreOptions => 'Mas opciones';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Ver en el mapa';

  @override
  String trips_diveScan_addButton(int count) {
    return 'Agregar $count inmersiones';
  }

  @override
  String trips_diveScan_added(int count) {
    return 'Se agregaron $count inmersiones al viaje';
  }

  @override
  String get trips_diveScan_cancel => 'Cancelar';

  @override
  String trips_diveScan_currentTrip(String tripName) {
    return 'Actualmente en: $tripName';
  }

  @override
  String get trips_diveScan_deselectAll => 'Deseleccionar todo';

  @override
  String trips_diveScan_error(String error) {
    return 'Error al buscar inmersiones: $error';
  }

  @override
  String get trips_diveScan_findButton => 'Buscar inmersiones coincidentes';

  @override
  String trips_diveScan_groupOtherTrips(int count) {
    return 'En otros viajes ($count)';
  }

  @override
  String trips_diveScan_groupUnassigned(int count) {
    return 'Sin asignar ($count)';
  }

  @override
  String get trips_diveScan_noMatches =>
      'No se encontraron inmersiones coincidentes';

  @override
  String get trips_diveScan_noDiver =>
      'Selecciona un buceador activo para buscar inmersiones';

  @override
  String get trips_diveScan_selectAll => 'Seleccionar todo';

  @override
  String trips_diveScan_subtitle(int count) {
    return '$count inmersiones encontradas en el rango de fechas';
  }

  @override
  String get trips_diveScan_title => 'Agregar inmersiones al viaje';

  @override
  String get trips_diveScan_unknownSite => 'Sitio desconocido';

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
  String get trips_edit_label_returnFlight => 'Vuelo de regreso';

  @override
  String get trips_edit_returnFlightClear => 'Borrar vuelo de regreso';

  @override
  String get trips_edit_returnFlightNotSet => 'Sin definir';

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
  String trips_list_countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'En $days días',
      one: 'En 1 día',
      zero: 'Comienza hoy',
    );
    return '$_temp0';
  }

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
  String get trips_list_inProgress => 'En curso';

  @override
  String get trips_list_pastSection => 'Viajes pasados';

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
  String get trips_list_upcomingSection => 'Próximos';

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
  String get universalImport_action_consolidate =>
      'Consolidar como ordenador adicional';

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
  String get universalImport_action_changeFile => 'Cambiar archivo';

  @override
  String get universalImport_action_selectFile => 'Seleccionar Archivo';

  @override
  String get universalImport_action_selectFiles => 'Seleccionar archivos';

  @override
  String get universalImport_action_chooseFolder => 'Elegir carpeta';

  @override
  String get universalImport_triage_title => 'Archivos a importar';

  @override
  String universalImport_triage_readyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos listos para importar',
      one: '1 archivo listo para importar',
    );
    return '$_temp0';
  }

  @override
  String universalImport_label_filesSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos seleccionados',
      one: '1 archivo seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_triage_excludedCsv =>
      'Importar individualmente (CSV)';

  @override
  String get universalImport_triage_unsupported => 'Formato no compatible';

  @override
  String get universalImport_triage_parseFailed => 'No se pudo leer';

  @override
  String universalImport_triage_parsing(int current, int total) {
    return 'Analizando archivo $current de $total…';
  }

  @override
  String get universalImport_triage_cancelParsing => 'Cancelar';

  @override
  String get universalImport_triage_allExcluded =>
      'Ninguno de los archivos seleccionados puede importarse junto. Los archivos CSV deben importarse de uno en uno.';

  @override
  String get universalImport_triage_noneImportable =>
      'Ninguno de los archivos seleccionados se puede importar.';

  @override
  String get universalImport_review_inBatchDuplicate =>
      'Duplicado de otra inmersión en este lote de importación.';

  @override
  String get universalImport_summary_filesTitle => 'Archivos';

  @override
  String get universalImport_summary_noticesTitle => 'No está en el archivo';

  @override
  String get universalImport_summary_noticeNoTankPressureTitle =>
      'Presión de la botella no registrada';

  @override
  String get universalImport_summary_noticeNoTankPressureBody =>
      'No se pueden calcular el consumo de aire ni el SAC. Puedes añadir la presión inicial y final editando la inmersión.';

  @override
  String universalImport_summary_noticeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Afecta a $count inmersiones',
      one: 'Afecta a 1 inmersión',
    );
    return '$_temp0';
  }

  @override
  String universalImport_summary_fileImported(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones importadas',
      one: '1 inmersión importada',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_summary_fileNeedsIndividualImport =>
      'Requiere importación individual';

  @override
  String get universalImport_summary_fileUnsupported => 'Formato no compatible';

  @override
  String get universalImport_summary_fileParseFailed => 'Error de lectura';

  @override
  String universalImport_bulk_consolidateMatched(int count) {
    return 'Consolidar coincidentes ($count)';
  }

  @override
  String universalImport_bulk_importAll(int count) {
    return 'Importar todo ($count)';
  }

  @override
  String universalImport_bulk_importAllAsNew(int count) {
    return 'Importar todo como nuevo ($count)';
  }

  @override
  String universalImport_bulk_skipAll(int count) {
    return 'Omitir todo ($count)';
  }

  @override
  String universalImport_bulk_replaceSourceAll(int count) {
    return 'Reemplazar todas ($count)';
  }

  @override
  String get universalImport_description_supportedFormats =>
      'Selecciona un archivo de registro de inmersiones para importar. Los formatos compatibles incluyen CSV, UDDF, Subsurface XML y Garmin FIT.';

  @override
  String get universalImport_dive_decideAction => 'Decidir';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Este formato aún no es compatible. Por favor exporta como UDDF o CSV.';

  @override
  String get universalImport_label_columnMapping => 'Mapeo de Columnas';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped de $total columnas mapeadas';
  }

  @override
  String get universalImport_label_consolidate => 'Consolidar';

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
  String get universalImport_label_importAsNew => 'Importar como nuevo';

  @override
  String get universalImport_label_importComplete => 'Importación Completa';

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
  String get universalImport_entityAction_linkBadge => 'VINCULAR';

  @override
  String get universalImport_entityAction_linkExisting =>
      'Vincular al existente';

  @override
  String get universalImport_entityAction_linkExistingSubtitle =>
      'Usar el registro coincidente';

  @override
  String get universalImport_entityAction_replaceBadge => 'REEMPLAZAR';

  @override
  String get universalImport_entityAction_replaceExisting =>
      'Reemplazar existente';

  @override
  String get universalImport_entityAction_replaceExistingSubtitle =>
      'Sobrescribir con los datos importados';

  @override
  String get universalImport_entityAction_skip => 'Omitir';

  @override
  String get universalImport_entityAction_skipSubtitle =>
      'Descartar esta importación';

  @override
  String get universalImport_entityAction_importAsNew => 'Importar como nuevo';

  @override
  String get universalImport_entityAction_importAsNewSubtitle =>
      'Crear una entrada separada';

  @override
  String get universalImport_pending_chooseAction => 'Elegir una accion';

  @override
  String universalImport_pending_gateHint(int count) {
    return '$count duplicado(s) requieren una decision';
  }

  @override
  String get universalImport_pending_needsDecision => 'Requiere decision';

  @override
  String get universalImport_pending_reviewAction => 'Revisar';

  @override
  String get universalImport_rowHint_tapCompareToDecide =>
      'Toca Decidir para elegir';

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
  String get universalImport_semantics_needsDecision =>
      'Posible duplicado, requiere decision';

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
  String universalImport_snackbar_bulkMarkedAs(int count, String action) {
    return '$count marcados como $action';
  }

  @override
  String universalImport_snackbar_markedAs(String action) {
    return 'Marcado como $action';
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
  String get universalImport_summary_decidesRequired =>
      'Cada uno necesita una decision antes de importarse.';

  @override
  String get universalImport_title => 'Importar Datos';

  @override
  String get universalImport_tooltip_closeWizard =>
      'Cerrar asistente de importación';

  @override
  String weather_windFromDirection(Object wind, Object direction) {
    return '$wind del $direction';
  }

  @override
  String get weather_wind_calm => 'en calma';

  @override
  String get weather_wind_highWind => 'viento fuerte';

  @override
  String get weather_wind_lightBreeze => 'brisa ligera';

  @override
  String get weather_wind_moderateBreeze => 'brisa moderada';

  @override
  String get weather_wind_strongBreeze => 'brisa fuerte';

  @override
  String get weather_wmo_clear => 'Cielo despejado';

  @override
  String get weather_wmo_drizzle => 'Llovizna';

  @override
  String get weather_wmo_fog => 'Niebla';

  @override
  String get weather_wmo_freezingDrizzle => 'Llovizna helada';

  @override
  String get weather_wmo_freezingRain => 'Lluvia helada';

  @override
  String get weather_wmo_mainlyClear => 'Mayormente despejado';

  @override
  String get weather_wmo_overcast => 'Cubierto';

  @override
  String get weather_wmo_partlyCloudy => 'Parcialmente nublado';

  @override
  String get weather_wmo_rain => 'Lluvia';

  @override
  String get weather_wmo_rainShowers => 'Chubascos';

  @override
  String get weather_wmo_snow => 'Nieve';

  @override
  String get weather_wmo_snowGrains => 'Cinarra';

  @override
  String get weather_wmo_snowShowers => 'Chubascos de nieve';

  @override
  String get weather_wmo_thunderstorm => 'Tormenta';

  @override
  String get weather_wmo_thunderstormHail => 'Tormenta con granizo';

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
  String get diveComputer_connectionType_ble => 'Bluetooth LE';

  @override
  String get diveComputer_connectionType_bluetooth => 'Bluetooth';

  @override
  String get diveComputer_connectionType_infrared => 'Infrarrojo';

  @override
  String get diveComputer_connectionType_unknown => 'Desconocido';

  @override
  String get diveComputer_connectionType_usb => 'USB';

  @override
  String get diveComputer_connectionType_wifi => 'Wi-Fi';

  @override
  String diveComputer_detail_deleteDialogContent(String name) {
    return 'Seguro que quieres eliminar \"$name\"? Esto no borrara las inmersiones importadas desde este ordenador.';
  }

  @override
  String get diveComputer_detail_deleteDialogTitle => 'Eliminar ordenador?';

  @override
  String get diveComputer_detail_divesImported => 'Inmersiones importadas';

  @override
  String get diveComputer_detail_downloadDivesButton => 'Descargar inmersiones';

  @override
  String get diveComputer_detail_editDialogTitle => 'Editar ordenador';

  @override
  String get diveComputer_detail_editNameHint => 'Por ejemplo, Mi Perdix';

  @override
  String get diveComputer_detail_editNotesHint => 'Notas opcionales';

  @override
  String get diveComputer_detail_labelConnection => 'Conexion';

  @override
  String get diveComputer_detail_labelManufacturer => 'Fabricante';

  @override
  String get diveComputer_detail_labelModel => 'Modelo';

  @override
  String get diveComputer_detail_labelName => 'Nombre';

  @override
  String get diveComputer_detail_lastDownload => 'Ultima descarga';

  @override
  String get diveComputer_detail_notesTitle => 'Notas';

  @override
  String get diveComputer_detail_reimportAllButton =>
      'Reimportar todas las inmersiones';

  @override
  String diveComputer_detail_reimportDialogBody(String computerName) {
    return 'Descarga todas las inmersiones de $computerName y compáralas con tu registro. Esto puede tardar varios minutos.';
  }

  @override
  String get diveComputer_detail_reimportDialogTitle =>
      '¿Reimportar todas las inmersiones?';

  @override
  String get diveComputer_detail_statisticsTitle => 'Estadisticas';

  @override
  String get diveComputer_detail_unknown => 'Desconocido';

  @override
  String get diveComputer_detail_viewDivesButton =>
      'Ver inmersiones desde este ordenador';

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
  String get diveComputer_discovery_usbInstructions =>
      'Conecte su ordenador de buceo por cable USB y selecciónelo a continuación.';

  @override
  String diveComputer_discovery_usbNoResults(String query) {
    return 'No se encontraron dispositivos para \"$query\"';
  }

  @override
  String get diveComputer_discovery_usbSearchHint =>
      'Buscar por fabricante o modelo...';

  @override
  String get diveComputer_downloadExit_content =>
      'Al salir se cancelara la descarga actual desde tu ordenador de buceo. Seguro?';

  @override
  String get diveComputer_downloadExit_leave => 'Salir';

  @override
  String get diveComputer_downloadExit_stay => 'Quedarse';

  @override
  String get diveComputer_downloadExit_title => 'Descarga en curso';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... y $count mas';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Cancelar';

  @override
  String get diveComputer_downloadStep_cancelled => 'Descarga cancelada';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadAll =>
      'Descargar todas las inmersiones';

  @override
  String get diveComputer_downloadStep_downloadFailed => 'La descarga fallo';

  @override
  String get diveComputer_downloadStep_downloadNew =>
      'Descargar inmersiones nuevas';

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
  String get diveComputer_downloadStep_firstSyncBody =>
      'Tu bitácora ya tiene inmersiones. Puedes omitir la descarga de las inmersiones que ya tienes.';

  @override
  String get diveComputer_downloadStep_firstSyncTitle =>
      'Primera descarga desde este ordenador de buceo';

  @override
  String diveComputer_downloadStep_onlyAfterDate(String date) {
    return 'Descargar solo inmersiones después de $date';
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
  String diveComputer_downloadStep_importPartialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importar $count inmersiones descargadas',
      one: 'Importar 1 inmersión descargada',
    );
    return '$_temp0';
  }

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
  String get diveComputer_download_noSerialPortsFound =>
      'No se encontraron puertos serie USB. ¿Está el ordenador de buceo conectado y encendido?';

  @override
  String get diveComputer_download_stalePairing =>
      'El emparejamiento Bluetooth de este ordenador de buceo está obsoleto. Olvida el ordenador de buceo en los ajustes de Bluetooth de tu dispositivo y vuelve a emparejarlo desde el menú Bluetooth del ordenador de buceo.';

  @override
  String get diveComputer_download_discoveryStalled =>
      'Se conectó al ordenador de buceo, pero dejó de responder antes de que comenzara la descarga. Normalmente esto significa que el emparejamiento Bluetooth está obsoleto: olvida el ordenador de buceo en los ajustes de Bluetooth de tu dispositivo y vuelve a intentarlo.';

  @override
  String diveComputer_download_serialConnectFailedWithDetails(Object details) {
    return 'No se pudo conectar al ordenador de buceo.\n\nDetalles de diagnóstico (compartir con los desarrolladores):\n$details';
  }

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
  String diveComputer_download_importingCountDives(int count) {
    return 'Importando $count inmersiones...';
  }

  @override
  String diveComputer_download_importingCountNewDives(int count) {
    return 'Importando $count inmersiones nuevas...';
  }

  @override
  String get diveComputer_download_newDivesImported =>
      'Nuevas inmersiones importadas';

  @override
  String get diveComputer_download_newDivesOnlySubtitle =>
      'Solo descarga inmersiones agregadas desde tu última sincronización';

  @override
  String get diveComputer_download_newDivesOnlyTitle =>
      'Descargar solo inmersiones nuevas';

  @override
  String get diveComputer_download_preparing => 'Preparando...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_reimportHint =>
      '¿Buscas inmersiones antiguas o eliminadas? Reimportar todas';

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
  String get diveComputer_download_upToDate =>
      'No se encontraron inmersiones nuevas -- tu registro está al día';

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
  String get diveComputer_pinCode_instructions =>
      'Introduce el codigo mostrado en tu ordenador de buceo.';

  @override
  String get diveComputer_pinCode_label => 'Codigo PIN';

  @override
  String get diveComputer_pinCode_submit => 'Enviar';

  @override
  String get diveComputer_pinCode_title => 'Codigo PIN requerido';

  @override
  String get diveComputer_pinEntry_connectButton => 'Conectar';

  @override
  String get diveComputer_pinEntry_helperText =>
      'Introduce el PIN de 4 a 6 digitos mostrado en tu dispositivo';

  @override
  String get diveComputer_pinEntry_instructionsGeneric =>
      'Consulta la pantalla de tu ordenador de buceo para ver el codigo PIN.';

  @override
  String diveComputer_pinEntry_instructionsWithDevice(String deviceName) {
    return 'Consulta la pantalla de tu $deviceName para ver el codigo PIN.';
  }

  @override
  String get diveComputer_pinEntry_semanticLabel =>
      'Entrada de codigo PIN, de 4 a 6 digitos';

  @override
  String get diveComputer_pinEntry_title => 'Introducir codigo PIN';

  @override
  String diveComputer_scan_bluetoothSemanticLabel(String name) {
    return 'Dispositivo Bluetooth: $name';
  }

  @override
  String get diveComputer_scan_emptyStateInstructions =>
      'Asegurate de que tu ordenador de buceo:\n• Este encendido\n• Este en modo de emparejamiento Bluetooth\n• Este cerca de tu dispositivo';

  @override
  String get diveComputer_scan_knownBadge => 'Conocido';

  @override
  String get diveComputer_scan_lookingForDevicesTitle =>
      'Buscando dispositivos';

  @override
  String get diveComputer_scan_noUsbDevicesAvailable =>
      'No hay dispositivos USB disponibles';

  @override
  String get diveComputer_scan_retry => 'Reintentar';

  @override
  String get diveComputer_scan_scanAgain => 'Buscar de nuevo';

  @override
  String get diveComputer_scan_scanningStatus =>
      'Buscando ordenadores de buceo...';

  @override
  String get diveComputer_scan_stopScanning => 'Detener busqueda';

  @override
  String get diveComputer_scan_supportedBadge => 'Compatible';

  @override
  String get diveComputer_scan_tabBluetooth => 'Bluetooth';

  @override
  String get diveComputer_scan_tabUsb => 'Cable USB';

  @override
  String get diveComputer_scan_usbCableLabel => 'Cable USB';

  @override
  String diveComputer_scan_usbSemanticLabel(String model) {
    return 'Dispositivo USB: $model';
  }

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
      'Submersion uses Apple HealthKit to read underwater diving workout data, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get diveImport_healthkit_accessRequired => 'Apple HealthKit';

  @override
  String get diveImport_healthkit_attribution =>
      'Desarrollado con Apple HealthKit';

  @override
  String get diveImport_healthkit_closeTooltip =>
      'Cerrar importacion de Apple Watch';

  @override
  String get diveImport_healthkit_dataUsage =>
      'Lee actividades de buceo subacuatico de Apple Health, incluyendo profundidad, duracion, temperatura del agua y frecuencia cardiaca. Estos datos se almacenan localmente en su registro de buceo y nunca se comparten con terceros.';

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
  String get diveImport_healthkit_grantAccess => 'Continuar';

  @override
  String get diveImport_healthkit_noDivesFound => 'Sin inmersiones encontradas';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'No se encontraron actividades de buceo en el rango de fechas seleccionado.';

  @override
  String get diveImport_healthkit_notAvailable => 'No disponible';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'La importación desde el Apple Watch necesita un iPhone con la app Salud.';

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
  String get diveImport_uddf_media => 'Fotos';

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
  String get divePlanner_undo => 'Deshacer';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'La reserva minima (rock bottom) es la cantidad minima de gas para un ascenso de emergencia compartiendo aire con tu companero.\n\n- Usa tasas RMV de estres (2-3x lo normal)\n- Asume ambos buceadores con un solo tanque\n- Incluye parada de seguridad cuando esta activada\n\nSiempre inicia el regreso ANTES de alcanzar la reserva minima!';

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
  String get gasCalculators_rockBottom_buddySac => 'RMV del companero';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'RMV combinado bajo estres';

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
      'Usa un RMV mas alto para compensar el estres durante una emergencia';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'RMV bajo estres';

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
  String get gasCalculators_rockBottom_yourSac => 'Tu RMV';

  @override
  String get gpsLogger_androidNotificationText =>
      'Grabando tu track de superficie';

  @override
  String get gpsLogger_androidNotificationTitle =>
      'Registrador GPS de Submersion';

  @override
  String get gpsLogger_deleteTrackMessage =>
      'Elimina el track GPS grabado. Las posiciones ya asignadas a las inmersiones se conservan.';

  @override
  String get gpsLogger_deleteTrackTitle => '¿Eliminar track?';

  @override
  String get gpsLogger_interruptedNotice =>
      'Una grabación anterior se interrumpió. El track se guardó.';

  @override
  String gpsLogger_lastFix(String age, String accuracy) {
    return 'Última posición hace $age ($accuracy)';
  }

  @override
  String get gpsLogger_locationOff =>
      'Los servicios de ubicación están desactivados.';

  @override
  String get gpsLogger_matchButton => 'Emparejar inmersiones con registros GPS';

  @override
  String gpsLogger_matchResult(int count) {
    return '$count inmersiones posicionadas';
  }

  @override
  String get gpsLogger_matchResultNone =>
      'Ninguna inmersión coincide con un track grabado';

  @override
  String get gpsLogger_noFixYet => 'Esperando señal GPS';

  @override
  String get gpsLogger_noTracks => 'Aún no hay tracks GPS grabados';

  @override
  String get gpsLogger_permissionDenied =>
      'Se necesita permiso de ubicación para grabar un track GPS. Actívalo en los ajustes del sistema.';

  @override
  String gpsLogger_recordingStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puntos',
      one: '$count punto',
    );
    return 'Grabando - $_temp0';
  }

  @override
  String get gpsLogger_reviewSites =>
      'Revisar coincidencias de puntos de buceo';

  @override
  String get gpsLogger_startButton => 'Iniciar registro';

  @override
  String get gpsLogger_stopButton => 'Detener registro';

  @override
  String gpsLogger_stripStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puntos',
      one: '$count punto',
    );
    return 'Grabando track GPS · $_temp0';
  }

  @override
  String get gpsLogger_summary_tracks => 'Tracks';

  @override
  String get gpsLogger_summary_recordedTime => 'Tiempo grabado';

  @override
  String get gpsLogger_summary_divesCovered => 'Inmersiones cubiertas';

  @override
  String gpsLogger_trackSubtitle(num count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puntos',
      one: '$count punto',
    );
    return '$_temp0, $duration';
  }

  @override
  String gpsLogger_trackSubtitleTrimmed(String duration) {
    return 'Recortada, $duration';
  }

  @override
  String get gpsLogger_tracksHeader => 'Tracks grabados';

  @override
  String get gpsTrack_action_trim => 'Recortar...';

  @override
  String get gpsTrack_action_split => 'Dividir...';

  @override
  String get gpsTrack_action_resetTrim => 'Quitar recorte';

  @override
  String get gpsTrack_edit_applyTrim => 'Aplicar recorte';

  @override
  String get gpsTrack_edit_confirmSplit => 'Dividir aquí';

  @override
  String get gpsTrack_edit_splitWarning =>
      'Al dividir se crean dos tracks y se elimina el original. Esto no se puede deshacer.';

  @override
  String get gpsTrack_edit_cancel => 'Cancelar';

  @override
  String get gpsTrack_import_action => 'Importar track...';

  @override
  String get gpsTrack_import_reviewTitle => 'Revisar importación';

  @override
  String get gpsTrack_import_timezone => 'Grabado en';

  @override
  String get gpsTrack_import_timezoneHint =>
      'Las horas del archivo están en UTC. Indica la zona en la que se grabó el track para que coincida con tus inmersiones.';

  @override
  String get gpsTrack_import_duplicate =>
      'Parece un duplicado de un track existente.';

  @override
  String get gpsTrack_import_confirm => 'Importar';

  @override
  String get gpsTrack_import_csvMapping => 'Asignar columnas';

  @override
  String get gpsTrack_import_firstFix => 'Primer punto';

  @override
  String gpsTrack_import_fixCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puntos',
      one: '1 punto',
    );
    return '$_temp0';
  }

  @override
  String gpsTrack_import_failed(String reason) {
    return 'No se pudo leer el archivo: $reason';
  }

  @override
  String get gpsTrack_importError_unsupportedFormat =>
      'Ese tipo de archivo no es compatible. Importa un archivo GPX, KML, CSV o FIT.';

  @override
  String get gpsTrack_importError_unreadable =>
      'No se pudo leer ese archivo. Puede estar dañado o incompleto.';

  @override
  String get gpsTrack_importError_noPositions =>
      'Ese archivo no contiene posiciones GPS con marca de tiempo.';

  @override
  String get gpsTrack_importError_badData =>
      'Ese archivo contiene una posición o marca de tiempo que la app no puede leer.';

  @override
  String get gpsTrack_export_saved => 'Track guardado';

  @override
  String get gpsTrack_action_export => 'Exportar';

  @override
  String get gpsTrack_action_shareGpx => 'Compartir como GPX';

  @override
  String get gpsTrack_action_saveGpx => 'Guardar como GPX...';

  @override
  String get gpsTrack_action_shareKml => 'Compartir como KML';

  @override
  String get gpsTrack_action_saveKml => 'Guardar como KML...';

  @override
  String get gpsTrack_export_failed => 'Error al exportar.';

  @override
  String get gpsTrack_map_title => 'Mapa de tracks';

  @override
  String gpsTrack_map_truncated(int count) {
    return 'Se muestran las $count rutas más recientes. Ajusta el filtro de fechas para ver las demás.';
  }

  @override
  String get gpsTrack_map_noTracks => 'No hay tracks grabados para mostrar.';

  @override
  String get gpsTrack_map_showMap => 'Mostrar mapa';

  @override
  String get gpsTrack_filter_all => 'Todas las fechas';

  @override
  String get gpsTrack_filter_clear => 'Quitar filtro de fechas';

  @override
  String get gpsTrack_inspect_speed => 'Velocidad';

  @override
  String get gpsTrack_inspect_accuracy => 'Precisión';

  @override
  String get gpsTrack_stats_distance => 'Distancia';

  @override
  String get gpsTrack_stats_duration => 'Duración';

  @override
  String get gpsTrack_stats_avgSpeed => 'Vel. media';

  @override
  String get gpsTrack_stats_maxSpeed => 'Vel. máx.';

  @override
  String get gpsTrack_stats_fixes => 'Puntos';

  @override
  String get gpsTrack_stats_dives => 'Inmersiones';

  @override
  String get gpsTrack_colorMode_uniform => 'Liso';

  @override
  String get gpsTrack_colorMode_speed => 'Velocidad';

  @override
  String get gpsTrack_colorMode_elapsed => 'Tiempo';

  @override
  String get gpsTrack_legend_slower => 'Más lento';

  @override
  String get gpsTrack_legend_faster => 'Más rápido';

  @override
  String get gpsTrack_legend_start => 'Inicio';

  @override
  String get gpsTrack_legend_end => 'Fin';

  @override
  String get gpsTrack_detail_title => 'Track GPS';

  @override
  String get gpsTrack_detail_notFound => 'Este track ya no está disponible.';

  @override
  String get gpsTrack_detail_unreadable =>
      'No se pudieron leer los datos del track.';

  @override
  String get gpsTrack_detail_noPoints =>
      'Este track no tiene posiciones registradas.';

  @override
  String get maps_compass_resetLabel =>
      'Restablecer la orientación del mapa al norte';

  @override
  String get maps_compass_resetTooltip => 'Norte arriba';

  @override
  String get maps_heatMap_hide => 'Ocultar mapa de calor';

  @override
  String get maps_heatMap_overlayOff =>
      'La capa de mapa de calor esta desactivada';

  @override
  String get maps_depthOverlay_show => 'Mostrar capa de profundidad';

  @override
  String get maps_depthOverlay_hide => 'Ocultar capa de profundidad';

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
  String get maps_offline_downloadNewRegion => 'Descargar nueva region';

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
  String get tankPresets_currentDefault => 'Predeterminado actual';

  @override
  String get tankPresets_customPresets => 'Presets personalizados';

  @override
  String get tankPresets_defaultSettings => 'Tanque predeterminado';

  @override
  String get tankPresets_defaultSettings_description =>
      'El preset marcado con estrella se usa como tanque predeterminado al registrar nuevas inmersiones.';

  @override
  String tankPresets_deleteDefaultMessage(String name) {
    return '¿Estás seguro de que quieres eliminar \"$name\"? Este es tu preset de tanque predeterminado actual y se restablecerá a AL80.';
  }

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
  String get tankPresets_applyToImports =>
      'Aplicar también a inmersiones importadas';

  @override
  String get tankPresets_applyToImports_subtitle =>
      'Completar datos de tanque faltantes en inmersiones importadas usando el preset predeterminado';

  @override
  String get tankPresets_new_title => 'Nuevo preset de tanque';

  @override
  String get tankPresets_noPresets => 'No hay presets de tanque disponibles';

  @override
  String get tankPresets_setAsDefault => 'Establecer como predeterminado';

  @override
  String get tankPresets_title => 'Presets de tanque';

  @override
  String get tools_gpsLogger_description =>
      'Graba tu posición durante un día de buceo y empareja automáticamente las inmersiones importadas con ubicaciones GPS.';

  @override
  String get tools_gpsLogger_subtitle => 'Graba un track de superficie';

  @override
  String get tools_gpsLogger_title => 'Registrador GPS';

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

  @override
  String get settings_section_dataSources_title => 'Data Sources';

  @override
  String get settings_section_dataSources_subtitle =>
      'Connected services & integrations';

  @override
  String get settings_siteMatch_title => 'Asociación automática de puntos';

  @override
  String get settings_siteMatch_subtitle =>
      'Con qué intensidad se asocian a puntos de buceo las inmersiones descargadas';

  @override
  String get settings_siteMatch_strict => 'Estricto';

  @override
  String get settings_siteMatch_balanced => 'Equilibrado';

  @override
  String get settings_siteMatch_relaxed => 'Relajado';

  @override
  String get settings_dataSources_header => 'Data Sources';

  @override
  String get settings_dataSources_appleHealth_title => 'Apple Health';

  @override
  String get settings_dataSources_appleHealth_subtitle =>
      'Datos de buceo subacuatico';

  @override
  String get settings_dataSources_appleHealth_description =>
      'Submersion reads underwater diving workout data from Apple Health, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get settings_dataSources_appleHealth_dataTypesHeader =>
      'Datos leidos de HealthKit';

  @override
  String get settings_dataSources_appleHealth_dataTypeWorkouts =>
      'Entrenamientos de buceo subacuatico - hora de inicio, duracion y datos de actividad de la inmersion';

  @override
  String get settings_dataSources_appleHealth_dataTypeHeartRate =>
      'Frecuencia cardiaca - muestras de frecuencia cardiaca registradas durante las inmersiones';

  @override
  String get settings_dataSources_appleHealth_permissionGranted =>
      'Acceso a HealthKit concedido';

  @override
  String get settings_dataSources_appleHealth_permissionNotGranted =>
      'Acceso a HealthKit no concedido';

  @override
  String get settings_dataSources_appleHealth_permissionChecking =>
      'Verificando acceso a HealthKit...';

  @override
  String get settings_dataSources_appleHealth_importAction =>
      'Import from Apple Watch';

  @override
  String get settings_dataSources_appleHealth_privacy =>
      'Your health data is stored locally and is never shared with third parties.';

  @override
  String get settings_dataSources_appleHealth_poweredBy =>
      'Desarrollado con Apple HealthKit';

  @override
  String get settings_dataSources_noSources =>
      'No data source integrations are available on this platform.';

  @override
  String get diveLog_edit_section_environment => 'Entorno';

  @override
  String get diveLog_edit_subsection_autofill => 'Autocompletar';

  @override
  String get diveLog_edit_subsection_weather => 'Clima';

  @override
  String get diveLog_edit_subsection_diveConditions => 'Condiciones de buceo';

  @override
  String get diveLog_edit_label_windSpeed => 'Velocidad del viento';

  @override
  String get diveLog_edit_label_windDirection => 'Dirección del viento';

  @override
  String get diveLog_edit_label_cloudCover => 'Nubosidad';

  @override
  String get diveLog_edit_label_precipitation => 'Precipitación';

  @override
  String get diveLog_edit_label_humidity => 'Humedad';

  @override
  String get diveLog_edit_label_weatherDescription => 'Descripción del clima';

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
  String get diveLog_detail_section_environment => 'Entorno';

  @override
  String get diveLog_detail_subsection_weather => 'Clima';

  @override
  String get diveLog_detail_subsection_diveConditions => 'Condiciones de buceo';

  @override
  String get diveLog_detail_label_windSpeed => 'Velocidad del viento';

  @override
  String get diveLog_detail_label_windDirection => 'Dirección del viento';

  @override
  String get diveLog_detail_label_cloudCover => 'Nubosidad';

  @override
  String get diveLog_detail_label_precipitation => 'Precipitación';

  @override
  String get diveLog_detail_label_humidity => 'Humedad';

  @override
  String get diveLog_detail_label_weatherDescription => 'Descripción';

  @override
  String get diveLog_detail_weatherSourceOpenMeteo => 'via Open-Meteo';

  @override
  String get dropTarget_title => 'Soltar para importar';

  @override
  String get dropTarget_subtitle =>
      'Suelta para abrir el asistente de importación';

  @override
  String get dropTarget_error_unsupportedFile =>
      'Tipo de archivo no compatible';

  @override
  String get dropTarget_error_wizardActive =>
      'Finaliza la importación actual primero';

  @override
  String get dropTarget_error_readFailed => 'No se pudo leer el archivo';

  @override
  String get enum_cloudCover_clear => 'Despejado';

  @override
  String get enum_cloudCover_partlyCloudy => 'Parcialmente nublado';

  @override
  String get enum_cloudCover_mostlyCloudy => 'Mayormente nublado';

  @override
  String get enum_cloudCover_overcast => 'Cubierto';

  @override
  String get enum_precipitation_none => 'Ninguna';

  @override
  String get enum_precipitation_drizzle => 'Llovizna';

  @override
  String get enum_precipitation_lightRain => 'Lluvia ligera';

  @override
  String get enum_precipitation_rain => 'Lluvia';

  @override
  String get enum_precipitation_heavyRain => 'Lluvia intensa';

  @override
  String get enum_precipitation_snow => 'Nieve';

  @override
  String get enum_precipitation_sleet => 'Aguanieve';

  @override
  String get enum_precipitation_hail => 'Granizo';

  @override
  String get columnConfig_title => 'Campos de la lista de inmersiones';

  @override
  String get columnConfig_viewMode => 'Modo de vista';

  @override
  String get columnConfig_visibleColumns => 'Columnas visibles';

  @override
  String get columnConfig_availableFields => 'Campos disponibles';

  @override
  String get columnConfig_extraFields => 'Campos adicionales';

  @override
  String get columnConfig_extraFields_description =>
      'Mostrados debajo del contenido principal de la tarjeta';

  @override
  String get columnConfig_slotAssignments => 'Asignación de posiciones';

  @override
  String get columnConfig_resetToDefault =>
      'Restablecer valores predeterminados';

  @override
  String get columnConfig_preset => 'Preajuste';

  @override
  String get columnConfig_presetSaveAs => 'Guardar como';

  @override
  String get columnConfig_presetName => 'Nombre del preajuste';

  @override
  String get columnConfig_presetNameHint => 'ej., Buceo técnico';

  @override
  String get columnConfig_presetSave => 'Guardar';

  @override
  String get columnConfig_presetCancel => 'Cancelar';

  @override
  String get columnConfig_columns => 'Columnas';

  @override
  String get columnConfig_done => 'Hecho';

  @override
  String get settings_appearance_columnConfig =>
      'Campos de la lista de inmersiones';

  @override
  String get settings_appearance_columnConfig_subtitle =>
      'Personalizar los campos mostrados en las vistas de lista de inmersiones';

  @override
  String get diveField_category_core => 'Esencial';

  @override
  String get diveField_category_environment => 'Entorno';

  @override
  String get diveField_category_gas => 'Gas';

  @override
  String get diveField_category_tank => 'Tanque';

  @override
  String get diveField_category_weight => 'Lastre';

  @override
  String get diveField_category_equipment => 'Equipo';

  @override
  String get diveField_category_deco => 'Descompresión';

  @override
  String get diveField_category_physiology => 'Fisiología';

  @override
  String get diveField_category_rebreather => 'Reciclador';

  @override
  String get diveField_category_people => 'Personas';

  @override
  String get diveField_category_location => 'Ubicación';

  @override
  String get diveField_category_trip => 'Viaje';

  @override
  String get diveField_category_rating => 'Valoración';

  @override
  String get diveField_category_metadata => 'Metadatos';

  @override
  String get listViewMode_table => 'Tabla';

  @override
  String get settings_appearance_general => 'General';

  @override
  String get settings_appearance_sections => 'Secciones';

  @override
  String get settings_appearance_colorAccents => 'Acentos de color';

  @override
  String get settings_appearance_accentNavIcons =>
      'Iconos de navegación en color';

  @override
  String get settings_appearance_accentNavIcons_subtitle =>
      'Colorea los iconos del menú principal con el color de cada sección';

  @override
  String get settings_appearance_accentSectionHeaders =>
      'Encabezados de sección en color';

  @override
  String get settings_appearance_accentSectionHeaders_subtitle =>
      'Muestra un icono de sección en color junto a los títulos de página';

  @override
  String get settings_appearance_accentListIcons => 'Iconos de lista en color';

  @override
  String get settings_appearance_accentListIcons_subtitle =>
      'Colorea los iconos de las listas y las páginas de ajustes';

  @override
  String get settings_appearance_showDetailsPane => 'Mostrar panel de detalles';

  @override
  String get settings_appearance_showDetailsPane_subtitle =>
      'Mostrar panel de detalles junto a la tabla';

  @override
  String get settings_appearance_showProfilePanel =>
      'Mostrar panel de perfil en vista de tabla';

  @override
  String get settings_appearance_showProfilePanel_subtitle =>
      'Mostrar gráfico de perfil de inmersión sobre la tabla por defecto';

  @override
  String get settings_appearance_mapStyle => 'Estilo del Mapa';

  @override
  String get settings_appearance_mapStyle_openStreetMap => 'Mapa de Calles';

  @override
  String get settings_appearance_mapStyle_openTopoMap => 'Topográfico';

  @override
  String get settings_appearance_mapStyle_esriSatellite => 'Satélite';

  @override
  String get common_action_reparse => 'Reanalizar';

  @override
  String get diveComputer_detail_reparseAllButton =>
      'Reanalizar todas las inmersiones';

  @override
  String get diveComputer_detail_reparseAllTitle =>
      'Reanalizar todas las inmersiones';

  @override
  String diveComputer_detail_reparseAllMessage(int count) {
    return 'Volver a ejecutar el analizador de inmersiones para $count inmersiones con datos sin procesar almacenados. Esto actualiza los datos de perfil y sensores, pero conserva tus notas, sitios, compañeros y otras ediciones.';
  }

  @override
  String diveComputer_detail_reparseAllProgress(int count) {
    return 'Reanalizando $count inmersiones...';
  }

  @override
  String diveComputer_detail_reparseAllSuccess(int count) {
    return 'Se reanalizaron $count inmersiones correctamente';
  }

  @override
  String diveComputer_detail_reparseAllPartial(
    int succeeded,
    int total,
    int failed,
  ) {
    return 'Se reanalizaron $succeeded de $total inmersiones. $failed fallaron.';
  }

  @override
  String diveComputer_detail_reparseRawDataCount(int count) {
    return '$count inmersiones con datos sin procesar';
  }

  @override
  String diveComputer_detail_reparseRawDataCountWithout(
    int count,
    int without,
  ) {
    return '$count inmersiones con datos sin procesar ($without sin)';
  }

  @override
  String get diveLog_detail_menu_reparseRawData =>
      'Reanalizar datos sin procesar';

  @override
  String get diveLog_detail_reparseSuccess =>
      'Inmersión reanalizada correctamente';

  @override
  String get diveLog_detail_reparseProfilePreserved =>
      'Detalles de la fuente actualizados. Esta inmersión se combinó a partir de otras inmersiones, por lo que su perfil no se modificó.';

  @override
  String diveLog_detail_reparseFailed(String error) {
    return 'Error al reanalizar: $error';
  }

  @override
  String get universalImport_label_replaceSource => 'Reemplazar Fuente';

  @override
  String get universalImport_label_replaceSourceSubtitle =>
      'Actualizar desde el mismo computador';

  @override
  String get universalImport_title_importOptions => 'Opciones de Importación';

  @override
  String get universalImport_label_options => 'Opciones';

  @override
  String get universalImport_label_retainDiveNumbers =>
      'Conservar números de inmersión de origen';

  @override
  String get universalImport_label_retainDiveNumbersSubtitle =>
      'Usar los números de inmersión del archivo importado en lugar de asignarlos automáticamente';

  @override
  String get universalImport_title_successImported => 'Importación Exitosa';

  @override
  String get universalImport_title_successUpdated => 'Actualización Exitosa';

  @override
  String get universalImport_title_successConsolidated =>
      'Consolidación Exitosa';

  @override
  String get universalImport_title_noDivesImported =>
      'No se Importaron Inmersiones';

  @override
  String get universalImport_label_allDivesSkipped =>
      'Todas las inmersiones fueron omitidas.';

  @override
  String get universalImport_label_replacedSourceData =>
      'Datos de origen reemplazados';

  @override
  String get universalImport_label_consolidated => 'Consolidadas';

  @override
  String get universalImport_label_photosAttached => 'Fotos adjuntadas';

  @override
  String get universalImport_label_photosUnmatched =>
      'Fotos sin coincidencia con una inmersión';

  @override
  String get common_label_shareWithAllProfiles =>
      'Compartir con todos los perfiles de buceo';

  @override
  String get settings_shareByDefault_title =>
      'Compartir los nuevos sitios y viajes por defecto';

  @override
  String get settings_shareAllSites_title => 'Compartir todos mis sitios';

  @override
  String get settings_shareAllTrips_title => 'Compartir todos mis viajes';

  @override
  String settings_shareAllSites_confirm(int count) {
    return '¿Hacer visibles los $count sitios para todos los perfiles de buceo de esta app? Podrás dejar de compartir sitios individuales más tarde.';
  }

  @override
  String settings_shareAllTrips_confirm(int count) {
    return '¿Hacer visibles los $count viajes para todos los perfiles de buceo de esta app? Podrás dejar de compartir viajes individuales más tarde.';
  }

  @override
  String settings_shareAllSites_snackbar(int count) {
    return '$count sitios compartidos con todos los perfiles de buceo.';
  }

  @override
  String settings_shareAllTrips_snackbar(int count) {
    return '$count viajes compartidos con todos los perfiles de buceo.';
  }

  @override
  String get settings_shareAll_noneToShare => 'Nada que compartir.';

  @override
  String get settings_sharedData_sectionTitle => 'Datos compartidos';

  @override
  String get settings_sharedData_sectionSubtitle =>
      'Compartir sitios y viajes entre perfiles';

  @override
  String get common_action_unshare => 'Dejar de compartir';

  @override
  String get trips_unshareConfirm_title => '¿Dejar de compartir este viaje?';

  @override
  String trips_unshareConfirm_body(String name) {
    return 'Esto eliminará «$name» de la vista de los demás perfiles de buceo. Podrás volver a compartirlo más tarde.';
  }

  @override
  String get sites_unshareConfirm_title => '¿Dejar de compartir este sitio?';

  @override
  String sites_unshareConfirm_body(String name) {
    return 'Esto eliminará «$name» de la vista de los demás perfiles de buceo. Podrás volver a compartirlo más tarde.';
  }

  @override
  String get trips_deleteShared_title => '¿Eliminar el viaje compartido?';

  @override
  String trips_deleteShared_body(String name) {
    return '«$name» está compartido con otros perfiles de buceo. Eliminarlo aquí lo elimina para todos.';
  }

  @override
  String get sites_deleteShared_title => '¿Eliminar el sitio compartido?';

  @override
  String sites_deleteShared_body(String name) {
    return '«$name» está compartido con otros perfiles de buceo. Eliminarlo aquí lo elimina para todos.';
  }

  @override
  String divers_delete_reassigned_snackbar(int trips, int sites, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      trips,
      locale: localeName,
      other: 'viajes compartidos',
      one: 'viaje compartido',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sites,
      locale: localeName,
      other: 'sitios compartidos',
      one: 'sitio compartido',
    );
    return 'Buzo eliminado. $trips $_temp0 y $sites $_temp1 reasignados a $name.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_title =>
      'Perfiles de buceador duplicados';

  @override
  String get settings_cloudSync_duplicateDivers_description =>
      'La sincronización encontró más de un perfil con el mismo nombre. Esto ocurre normalmente cuando cada dispositivo creó su propio perfil antes de sincronizarse. Al fusionar, todos los buceos y datos se mueven a un único perfil.';

  @override
  String settings_cloudSync_duplicateDivers_groupLabel(String name, int count) {
    return '$name ($count perfiles)';
  }

  @override
  String get settings_cloudSync_duplicateDivers_mergeButton => 'Fusionar';

  @override
  String get settings_cloudSync_duplicateDivers_confirmTitle =>
      '¿Fusionar perfiles de buceador?';

  @override
  String settings_cloudSync_duplicateDivers_confirmBody(
    int count,
    String name,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perfiles duplicados',
      one: 'un perfil duplicado',
    );
    return 'Todos los buceos, certificaciones, equipo y otros datos de $_temp0 se moverán a \"$name\". Esto no se puede deshacer automáticamente.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_confirmCancel => 'Cancelar';

  @override
  String get settings_cloudSync_duplicateDivers_confirmAction => 'Fusionar';

  @override
  String settings_cloudSync_duplicateDivers_successSnack(String name) {
    return 'Fusionado en $name';
  }

  @override
  String settings_cloudSync_duplicateDivers_failureSnack(String error) {
    return 'Error al fusionar: $error';
  }

  @override
  String get settings_cloudSync_duplicateDivers_undo => 'Deshacer';

  @override
  String get divers_edit_priorExperienceSection => 'Experiencia Previa';

  @override
  String get divers_edit_priorExperienceHelp =>
      'Inmersiones y tiempo de antes de empezar a registrar en Submersion.';

  @override
  String get divers_edit_priorDivesLabel => 'Inmersiones previas';

  @override
  String get divers_edit_priorHoursLabel => 'Horas previas';

  @override
  String get divers_edit_priorMinutesLabel => 'Minutos';

  @override
  String get divers_edit_divingSinceLabel => 'Buceando desde';

  @override
  String get divers_edit_divingSinceNotSet => 'Sin definir';

  @override
  String get divers_edit_clearDivingSinceTooltip => 'Borrar buceando desde';

  @override
  String get divers_edit_priorInvalidNumber => 'Introduce un número válido';

  @override
  String statistics_priorBreakdown(String logged, String prior) {
    return '$logged registradas + $prior previas';
  }

  @override
  String statistics_divingSince(int year) {
    return 'Buceando desde $year';
  }

  @override
  String get db_location_choose_volume => 'Elegir ubicación de almacenamiento';

  @override
  String get db_location_internal => 'Almacenamiento interno';

  @override
  String get db_location_sd_card => 'Tarjeta SD';

  @override
  String get db_location_external_note =>
      'Los archivos aquí se eliminan si desinstalas la aplicación.';

  @override
  String get db_location_backup_note =>
      'Android no puede ejecutar la base de datos desde una carpeta sincronizada en la nube. Para guardar una copia en Dropbox, Nextcloud o Google Drive, configura la Ubicación de Copia de Seguridad en Copia de Seguridad y Restaurar.';

  @override
  String diveLog_bulkEdit_membership_onAll(int count) {
    return 'en todas las $count';
  }

  @override
  String diveLog_bulkEdit_membership_onSome(int count, int total) {
    return 'en $count de $total';
  }

  @override
  String diveLog_bulkEdit_membership_adding(int total) {
    return 'añadiendo a todas ($total)';
  }

  @override
  String get diveLog_bulkEdit_membership_removing => 'quitando de todas';

  @override
  String get diveLog_bulkEdit_membership_empty =>
      'Aún no hay elementos en las inmersiones seleccionadas';

  @override
  String get settings_mediaStorage_entry_title => 'Almacenamiento de medios';

  @override
  String get settings_mediaStorage_entry_subtitle =>
      'Guarda los originales de fotos y videos en tu propio almacenamiento en la nube';

  @override
  String get settings_mediaStorage_status_notConfigured =>
      'No hay un almacén de medios conectado en este dispositivo';

  @override
  String settings_mediaStorage_status_connected(String hint) {
    return 'Conectado a $hint';
  }

  @override
  String get settings_mediaStorage_test_success => 'Conexión correcta';

  @override
  String get settings_mediaStorage_saved => 'Almacén de medios conectado';

  @override
  String get settings_mediaStorage_action_disconnect => 'Desconectar';

  @override
  String get settings_mediaStorage_disconnect_confirm_title =>
      '¿Desconectar el almacén de medios?';

  @override
  String get settings_mediaStorage_disconnect_confirm_body =>
      'Este dispositivo deja de subir y descargar medios. No se elimina nada de tu bucket.';

  @override
  String get settings_mediaStorage_action_copyFromSync =>
      'Copiar ajustes de Sincronización';

  @override
  String get settings_mediaStorage_transfers_title => 'Transferencias';

  @override
  String get settings_mediaStorage_transfers_entry => 'Ver transferencias';

  @override
  String get settings_mediaStorage_transfers_empty => 'Sin transferencias';

  @override
  String get settings_mediaStorage_transfers_retry => 'Reintentar';

  @override
  String get settings_mediaStorage_transfers_clearCompleted =>
      'Borrar completadas';

  @override
  String get settings_mediaStorage_transfers_state_pending => 'En espera';

  @override
  String get settings_mediaStorage_transfers_state_transferring => 'Subiendo';

  @override
  String get settings_mediaStorage_transfers_state_deleting =>
      'Eliminando de la nube';

  @override
  String get settings_mediaStorage_transfers_state_done => 'Completado';

  @override
  String get settings_mediaStorage_transfers_state_failed => 'Fallido';

  @override
  String settings_mediaStorage_transfers_queued(int count) {
    return '$count en cola';
  }

  @override
  String settings_mediaStorage_transfers_waitingRetry(int count) {
    return '$count esperando para reintentar';
  }

  @override
  String get settings_mediaStorage_verify_action => 'Verificar biblioteca';

  @override
  String get settings_mediaStorage_verify_running =>
      'Verificando la biblioteca multimedia...';

  @override
  String settings_mediaStorage_verify_summary(
    int checked,
    int removed,
    int repaired,
    int aborted,
  ) {
    return 'Se comprobaron $checked objetos: $removed huérfanos eliminados, $repaired reparaciones en cola, $aborted subidas obsoletas canceladas';
  }

  @override
  String get settings_mediaStorage_backfill_action =>
      'Subir biblioteca existente';

  @override
  String settings_mediaStorage_backfill_enqueued(int count) {
    return '$count subidas en cola';
  }

  @override
  String get settings_mediaStorage_policy_autoUpload =>
      'Subir fotos automáticamente';

  @override
  String get settings_mediaStorage_policy_photosOnCellular =>
      'Subir fotos con datos móviles';

  @override
  String get settings_mediaStorage_provider_label => 'Proveedor';

  @override
  String get settings_mediaStorage_connect_dropbox_hint =>
      'Usa tu conexión de Dropbox de la sincronización en la nube. Los medios se guardan en la carpeta de la app en Dropbox.';

  @override
  String get settings_mediaStorage_connect_gdrive_hint =>
      'Inicia sesión con Google. Los medios se guardan en el espacio privado de Drive de esta app.';

  @override
  String get settings_mediaStorage_connect_icloud_hint =>
      'Los medios se guardan en el contenedor de iCloud de esta app y se sincronizan con tu Apple ID.';

  @override
  String settings_mediaStorage_connect_action(String provider) {
    return 'Conectar $provider';
  }

  @override
  String get bodyWeight_addEntry => 'Añadir medición';

  @override
  String get bodyWeight_dateLabel => 'Fecha';

  @override
  String get bodyWeight_deleteTooltip => 'Eliminar entrada';

  @override
  String get bodyWeight_heightLabel => 'Altura (cm)';

  @override
  String get bodyWeight_heightFeetLabel => 'Altura (ft)';

  @override
  String get bodyWeight_heightInchesLabel => 'Pulgadas';

  @override
  String bodyWeight_weightLabel(String unit) {
    return 'Peso ($unit)';
  }

  @override
  String diveLog_edit_weightFeedback_amount(String unit) {
    return 'Por cuánto aproximadamente ($unit)';
  }

  @override
  String get diveLog_edit_weightFeedback_correct => 'Correcto';

  @override
  String get diveLog_edit_weightFeedback_label => '¿Cómo fue tu lastre?';

  @override
  String get diveLog_edit_weightFeedback_over => 'Sobrelastrado';

  @override
  String get diveLog_edit_weightFeedback_under => 'Infralastrado';

  @override
  String get diverProfile_bodyWeight_empty => 'Sin registrar';

  @override
  String get diverProfile_bodyWeight_title => 'Peso corporal';

  @override
  String get equipment_edit_advanced_title => 'Avanzado';

  @override
  String get equipment_edit_buoyancyHint_exposure => 'Positivo: cuánto flota';

  @override
  String get equipment_edit_buoyancyHint_generic => 'Negativo si se hunde';

  @override
  String get equipment_edit_buoyancyHint_tank =>
      'Dejar vacío: los tanques usan sus propias especificaciones';

  @override
  String equipment_edit_buoyancyLabel(String unit) {
    return 'Flotabilidad ($unit)';
  }

  @override
  String equipment_edit_dryWeightLabel(String unit) {
    return 'Peso en seco ($unit)';
  }

  @override
  String equipment_edit_liftCapacityLabel(String unit) {
    return 'Capacidad de flotación ($unit)';
  }

  @override
  String get equipment_edit_liftCapacityHint =>
      'Sustentación nominal del wing o jacket';

  @override
  String get planner_gearWeights_accept => 'Usar como lastre planificado';

  @override
  String get planner_gearWeights_addGear => 'Añadir equipo';

  @override
  String get planner_gearWeights_empty =>
      'Añade equipo para predecir tu lastre';

  @override
  String planner_gearWeights_planned(String weight) {
    return 'Planificado: $weight';
  }

  @override
  String planner_gearWeights_predicted(String weight) {
    return 'Predicción: $weight';
  }

  @override
  String get planner_gearWeights_title => 'Equipo y lastre';

  @override
  String get planner_gearWeights_useSet => 'Usar conjunto';

  @override
  String get tools_weight_addGear => 'Añadir equipo';

  @override
  String get tools_weight_addTank => 'Añadir tanque';

  @override
  String tools_weight_basedOnDives(int count) {
    return 'Basado en $count inmersiones registradas';
  }

  @override
  String get tools_weight_breakdownTitle => 'Cómo se calculó';

  @override
  String get tools_weight_confidence_high => 'Confianza alta';

  @override
  String get tools_weight_confidence_low => 'Confianza baja: estimación';

  @override
  String get tools_weight_confidence_medium => 'Confianza media';

  @override
  String tools_weight_deltaVsPrevious(String delta) {
    return '$delta respecto al equipo anterior';
  }

  @override
  String get tools_weight_noGear =>
      'Añade el equipo con el que vas a bucear para personalizar la predicción.';

  @override
  String get tools_weight_personalTerm => 'Base personal';

  @override
  String get tools_weight_placementTitle => 'Colocación sugerida';

  @override
  String get tools_weight_predictedWeight => 'Lastre previsto';

  @override
  String get tools_weight_saveToProfile => 'Guardar peso en el perfil';

  @override
  String get tools_weight_source_measured => 'medido de tus inmersiones';

  @override
  String get tools_weight_source_physics => 'física';

  @override
  String get tools_weight_source_typeDefault => 'estimación por defecto';

  @override
  String get tools_weight_source_userSpec =>
      'de las especificaciones de tu equipo';

  @override
  String get tools_weight_tanks => 'Tanques';

  @override
  String get tools_weight_useSet => 'Usar conjunto';

  @override
  String get tools_weight_waterTerm => 'Tipo de agua';

  @override
  String get dive3d_previewTitle => 'Vista 3D';

  @override
  String get dive3d_previewHint => 'Toca para explorar en 3D';

  @override
  String get dive3d_resetView => 'Restablecer vista';

  @override
  String get dive3d_zoomIn => 'Acercar';

  @override
  String get dive3d_zoomOut => 'Alejar';

  @override
  String get dive3d_play => 'Reproducir';

  @override
  String get dive3d_pause => 'Pausar';

  @override
  String get dive3d_overlays => 'Superposiciones';

  @override
  String get dive3d_overlay_strata => 'Capas de temperatura';

  @override
  String get dive3d_overlay_ceiling => 'Techo de deco';

  @override
  String get dive3d_overlay_curtain => 'Cortina de profundidad';

  @override
  String get dive3d_overlay_markers => 'Marcadores';

  @override
  String get dive3d_seascape_overlay_paths => 'Trayectos de buceo';

  @override
  String get dive3d_seascape_overlay_contours => 'Isóbatas';

  @override
  String get dive3d_seascape_overlay_walls => 'Paredes verticales';

  @override
  String get dive3d_overlay_water => 'Superficie del agua';

  @override
  String get dive3d_seascape_legend_land => 'Tierra';

  @override
  String get dive3d_seascape_appearance => 'Aspecto del terreno';

  @override
  String get dive3d_seascape_chartView => 'Vista de carta';

  @override
  String get dive3d_seascape_orbitView => 'Vista 3D';

  @override
  String get dive3d_seascape_appearance_surface => 'Superficie del terreno';

  @override
  String get dive3d_seascape_appearance_surfaceDepth =>
      'Colores de profundidad';

  @override
  String get dive3d_seascape_appearance_surfaceImagery => 'Imágenes del mapa';

  @override
  String get dive3d_seascape_appearance_surfaceBlend => 'Mezcla';

  @override
  String get siteFeature_type_wreck => 'Pecio';

  @override
  String get siteFeature_type_mooring => 'Boya de amarre';

  @override
  String get siteFeature_type_entry => 'Punto de entrada';

  @override
  String get siteFeature_type_exit => 'Punto de salida';

  @override
  String get siteFeature_type_swimThrough => 'Pasadizo';

  @override
  String get siteFeature_type_hazard => 'Peligro';

  @override
  String get siteFeature_type_current => 'Corriente';

  @override
  String get siteFeature_sectionTitle => 'Características';

  @override
  String get siteFeature_addAction => 'Añadir característica';

  @override
  String get siteFeature_placeHint =>
      'Toca el mapa para colocar la característica';

  @override
  String get siteFeature_addTitle => 'Añadir característica';

  @override
  String get siteFeature_editTitle => 'Editar característica';

  @override
  String get siteFeature_field_name => 'Nombre';

  @override
  String get siteFeature_field_bearing => 'Rumbo (°)';

  @override
  String get siteFeature_field_depth => 'Profundidad';

  @override
  String get siteFeature_field_notes => 'Notas';

  @override
  String get siteFeature_deleteAction => 'Eliminar';

  @override
  String siteFeature_deleteConfirm(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String get siteScape_mode2d => 'Mapa';

  @override
  String get siteScape_mode3d => '3D';

  @override
  String get dive3d_seascape_appearance_rampRange =>
      'Limitar rango de profundidad del color';

  @override
  String get dive3d_seascape_appearance_rampMax => 'Color más oscuro a';

  @override
  String get dive3d_seascape_appearance_banded => 'Degradado en bandas';

  @override
  String get dive3d_seascape_appearance_contours => 'Niveles de isóbatas';

  @override
  String get dive3d_seascape_appearance_contourAuto => 'Automático';

  @override
  String get dive3d_seascape_appearance_contourCustom => 'Personalizado';

  @override
  String get dive3d_seascape_appearance_addLevel => 'Añadir nivel';

  @override
  String get dive3d_seascape_appearance_defaultColor => 'Predeterminado';

  @override
  String get dive3d_seascape_appearance_wallAngle => 'Ángulo de pared vertical';

  @override
  String get dive3d_seascape_appearance_wallAngleNote =>
      'Las celdas batimétricas promedian la pendiente interior, así que las paredes reales parecen menos inclinadas. Manténgalo muy por debajo de 45 grados.';

  @override
  String get dive3d_seascape_siteTitle => 'Paisaje marino del sitio';

  @override
  String dive3d_seascape_seafloorSource(String source, String resolution) {
    return 'Fondo marino: $source (~$resolution m)';
  }

  @override
  String get dive3d_seascape_noCoordinates =>
      'Este sitio no tiene coordenadas GPS';

  @override
  String get dive3d_seascape_noData =>
      'No hay batimetría disponible para esta ubicación';

  @override
  String dive3d_seascape_axis_distance(String unitSymbol) {
    return 'Distancia ($unitSymbol)';
  }

  @override
  String get settings_about_bathymetryCredit =>
      'Datos de batimetría: GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022';

  @override
  String get dive3d_metric_depth => 'Profundidad';

  @override
  String get dive3d_metric_temperature => 'Temp';

  @override
  String get dive3d_metric_ascentRate => 'Ascenso';

  @override
  String get dive3d_metric_ppO2 => 'ppO2';

  @override
  String get dive3d_metric_cns => 'SNC';

  @override
  String get dive3d_metric_heartRate => 'FC';

  @override
  String get dive3d_metric_tankPressure => 'Presión';

  @override
  String get dive3d_zAxis => 'Eje Z';

  @override
  String get dive3d_zAxis_none => 'Ninguno';

  @override
  String get dive3d_overlay_shadows => 'Sombras en paredes';

  @override
  String get dive3d_metric_tts => 'TTS';

  @override
  String dive3d_axis_depth(String unitSymbol) {
    return 'Profundidad ($unitSymbol)';
  }

  @override
  String get dive3d_axis_time => 'Tiempo de inmersión (min)';

  @override
  String get dive3d_pose_menu => 'Cámara';

  @override
  String get dive3d_pose_default => 'Vista predeterminada';

  @override
  String get dive3d_pose_front => 'Frontal (profundidad vs. tiempo)';

  @override
  String get dive3d_pose_side => 'Lateral (profundidad vs. métrica)';

  @override
  String get dive3d_pose_top => 'Superior (métrica vs. tiempo)';

  @override
  String get dive3d_readout_runTime => 'Tiempo de inmersión';

  @override
  String get dive3d_readout_ceiling => 'Techo';

  @override
  String dive3d_readout_tank(int n) {
    return 'Botella $n';
  }

  @override
  String get dive3d_scene_dive => 'Inmersión';

  @override
  String get dive3d_scene_tissue => 'Tejidos';

  @override
  String get dive3d_tissue_gasCombined => 'Combinado';

  @override
  String get dive3d_tissue_gasN2 => 'N2';

  @override
  String get dive3d_tissue_gasHe => 'He';

  @override
  String get dive3d_tissue_colorMValue => '% valor M';

  @override
  String get dive3d_tissue_colorAbsolute => 'Carga';

  @override
  String get dive3d_tissue_controlling => 'Controlador';

  @override
  String get dive3d_tissue_surfaceInterval => 'Intervalo de superficie';

  @override
  String get dive3d_career_title => 'Historial 3D';

  @override
  String get dive3d_career_colorRecency => 'Recencia';

  @override
  String get dive3d_career_colorDepth => 'Profundidad';

  @override
  String get dive3d_career_empty => 'No hay inmersiones con perfiles';

  @override
  String get dive3d_spatial_title => 'Paisaje marino 3D';

  @override
  String get dive3d_spatial_estimatedPath =>
      'Ruta estimada (navegación a estima)';

  @override
  String get dive3d_spatial_synthesizedSeafloor => 'Fondo marino sintetizado';

  @override
  String get dive3d_spatial_noPath =>
      'Datos insuficientes para reconstruir la ruta';

  @override
  String get dive3d_tissue_legendHeight =>
      'Altura y color: % del límite de valor M';

  @override
  String get dive3d_tissue_legendLimit => 'Plano rojo = límite de deco';

  @override
  String get dive3d_tissue_legendAxes =>
      'Izq→der: tiempo · Frente→atrás: tejidos rápidos→lentos';

  @override
  String get dive3d_tissue_legendDepth => 'Curva azul: tu profundidad';

  @override
  String get dive3d_tissue_onGassing => 'Absorción';

  @override
  String get dive3d_tissue_offGassing => 'Liberación';

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
    return 'Saturación $percent%';
  }

  @override
  String dive3d_tissue_tooltipProgress(int percent) {
    return '$percent% de la inmersión';
  }

  @override
  String get dive3d_tissue_stateEquilibrium => 'Equilibrio';

  @override
  String get dive3d_tissue_statePastMValue => 'Sobre el valor M';

  @override
  String get dive3d_tissue_axisTime => 'Tiempo';

  @override
  String get dive3d_tissue_axisSaturation => 'Saturación %';

  @override
  String get dive3d_tissue_axisCompartment => 'Compartimento';

  @override
  String get dive3d_compare_computers_title => 'Comparar ordenadores';

  @override
  String get dive3d_compare_dives_title => 'Comparar inmersiones';

  @override
  String get dive3d_scene_computers => 'Ordenadores';

  @override
  String get dive3d_compare_layout_sideBySide => 'Lado a lado';

  @override
  String get dive3d_compare_layout_overlay => 'Superponer';

  @override
  String get dive3d_compare_empty =>
      'Se necesitan al menos 2 perfiles con datos de profundidad para comparar';

  @override
  String dive3d_compare_showing(Object shown, Object total) {
    return 'Mostrando $shown de $total';
  }

  @override
  String get dive3d_compare_setReference => 'Establecer como referencia';

  @override
  String get diveLog_selection_tooltip_compare3d => 'Comparar en 3D';

  @override
  String get diveLog_sources_compareIn3d => 'Comparar en 3D';

  @override
  String get settings_setup_pendingTitle =>
      'Termina de configurar este dispositivo';

  @override
  String settings_setup_mediaStoreAttach(String hint) {
    return 'Conectar almacenamiento de medios ($hint)';
  }

  @override
  String settings_setup_accountSignIn(String label) {
    return 'Iniciar sesión en $label';
  }

  @override
  String get settings_setup_dismiss => 'Descartar';

  @override
  String get settings_photosMedia_title => 'Fotos y medios';

  @override
  String get settings_photosMedia_subtitle =>
      'Fuentes, almacenamiento y cuentas';

  @override
  String get settings_photosMedia_sourcesHeader => 'De dónde vienen las fotos';

  @override
  String get settings_photosMedia_storageHeader =>
      'Dónde se guardan las copias';

  @override
  String get settings_photosMedia_accountsHeader => 'Cuentas';

  @override
  String get settings_photosMedia_displayHeader => 'Visualización';

  @override
  String get settings_photosMedia_guidedSetup => 'Configuración guiada';

  @override
  String get settings_photosMedia_photoSources_title =>
      'Biblioteca de fotos y fuentes';

  @override
  String get settings_photosMedia_photoSources_subtitle =>
      'Galería, archivos y opciones de importación';

  @override
  String get settings_photosMedia_networkSources_title => 'Fuentes de red';

  @override
  String get settings_photosMedia_networkSources_subtitle =>
      'URLs y fuentes de manifiesto (avanzado)';

  @override
  String get settings_connectedAccounts_title => 'Cuentas conectadas';

  @override
  String get settings_connectedAccounts_subtitle =>
      'Inicios de sesión de nube y servicios';

  @override
  String get settings_connectedAccounts_empty =>
      'Aún no hay cuentas conectadas';

  @override
  String get settings_connectedAccounts_status_signedIn => 'Sesión iniciada';

  @override
  String get settings_connectedAccounts_status_needsSignIn =>
      'Requiere iniciar sesión';

  @override
  String get settings_connectedAccounts_status_unavailable =>
      'No disponible en este dispositivo';

  @override
  String get settings_connectedAccounts_disconnectDevice =>
      'Cerrar sesión en este dispositivo';

  @override
  String get settings_connectedAccounts_removeFromLibrary =>
      'Quitar de la biblioteca';

  @override
  String get settings_connectedAccounts_removeConfirmTitle =>
      '¿Quitar la cuenta?';

  @override
  String get settings_connectedAccounts_removeConfirmBody =>
      'La cuenta se quita de todos los dispositivos sincronizados. Las credenciales guardadas en otros dispositivos no se eliminan.';

  @override
  String get settings_setupGuide_title => 'Configurar fotos y medios';

  @override
  String get settings_setupGuide_intro =>
      'Conecta de dónde vienen tus fotos y dónde se guardan las copias. Puedes volver a ejecutar esto cuando quieras.';

  @override
  String get settings_setupGuide_stepSources => 'Fuentes de fotos';

  @override
  String get settings_setupGuide_stepSources_desc =>
      'Adjunta fotos desde tu biblioteca, archivos o Lightroom.';

  @override
  String get settings_setupGuide_stepStorage => 'Almacenamiento de medios';

  @override
  String get settings_setupGuide_stepStorage_desc =>
      'Guarda copias de tus fotos en tu propia nube para que todos los dispositivos puedan mostrarlas.';

  @override
  String get settings_setupGuide_stepSync => 'Sincronización en la nube';

  @override
  String get settings_setupGuide_stepSync_desc =>
      'Sincroniza los datos de buceo entre dispositivos.';

  @override
  String get settings_setupGuide_statusDone => 'Configurado';

  @override
  String get settings_setupGuide_statusTodo => 'Sin configurar';

  @override
  String get settings_setupGuide_open => 'Abrir';

  @override
  String get settings_connectedAccounts_loadError =>
      'No se pudieron cargar las cuentas';

  @override
  String get media_unavailablePlaceholder_volumeOffline => 'Volumen no montado';

  @override
  String get media_unavailablePlaceholder_stillFetching =>
      'Aún se está cargando. Toca para reintentar.';

  @override
  String get media_unavailablePlaceholder_accessDenied =>
      'Sin acceso a la fototeca';

  @override
  String get attrLabel_size => 'Talla';

  @override
  String get attrLabel_thickness_mm => 'Grosor (mm)';

  @override
  String get attrLabel_suit_style => 'Tipo de traje';

  @override
  String get attrLabel_shell_material => 'Material exterior';

  @override
  String get attrLabel_seal_type => 'Tipo de sellos';

  @override
  String get attrLabel_volume_l => 'Volumen';

  @override
  String get attrLabel_working_pressure_bar => 'Presión de trabajo';

  @override
  String get attrLabel_tank_material => 'Material';

  @override
  String get attrLabel_valve_type => 'Válvula';

  @override
  String get attrLabel_tank_identifier => 'Identificador';

  @override
  String get attrLabel_last_visual_inspection => 'Última inspección visual';

  @override
  String get attrLabel_last_hydro_test => 'Última prueba hidrostática';

  @override
  String get attrLabel_connection => 'Conexión';

  @override
  String get attrLabel_cold_water_rated => 'Apto para agua fría';

  @override
  String get attrLabel_bcd_style => 'Estilo';

  @override
  String get attrLabel_lift_capacity_kg => 'Capacidad de elevación';

  @override
  String get attrLabel_heel_type => 'Talón';

  @override
  String get attrLabel_blade_style => 'Pala';

  @override
  String get attrLabel_mount => 'Montaje';

  @override
  String get attrLabel_connectivity => 'Conectividad';

  @override
  String get attrLabel_lens_config => 'Lente';

  @override
  String get attrLabel_prescription => 'Lentes graduadas';

  @override
  String get attrLabel_weight_style => 'Estilo';

  @override
  String get attrLabel_lumens => 'Lúmenes';

  @override
  String get attrLabel_beam_type => 'Haz';

  @override
  String get attrLabel_depth_rating_m => 'Profundidad máxima';

  @override
  String get attrLabel_smb_type => 'Tipo';

  @override
  String get attrLabel_length_m => 'Longitud';

  @override
  String get attrLabel_reel_type => 'Tipo';

  @override
  String get attrLabel_line_length_m => 'Longitud del hilo';

  @override
  String get attrLabel_blade_material => 'Material de la hoja';

  @override
  String get attrLabel_tip_type => 'Punta';

  @override
  String get attrLabel_glove_type => 'Tipo';

  @override
  String get attrLabel_sole_type => 'Suela';

  @override
  String get attrLabel_buoyancy_kg => 'Flotabilidad';

  @override
  String get attrLabel_dry_weight_kg => 'Peso en seco';

  @override
  String get attrLabel_unit_type => 'Tipo de equipo';

  @override
  String get attrLabel_mount_configuration => 'Montaje';

  @override
  String get attrLabel_scrubber_type => 'Tipo de filtro';

  @override
  String get attrLabel_scrubber_duration_h => 'Duración del filtro (h)';

  @override
  String get attrLabel_o2_cell_count => 'Células de O2';

  @override
  String get attrLabel_diluent_cylinder_l => 'Botella de diluyente';

  @override
  String get attrLabel_o2_cylinder_l => 'Botella de O2';

  @override
  String get attrLabel_dpv_style => 'Estilo';

  @override
  String get attrLabel_burn_time_h => 'Autonomía';

  @override
  String get attrLabel_battery_type => 'Batería';

  @override
  String get attrLabel_battery_capacity_wh => 'Capacidad de batería (Wh)';

  @override
  String get attrLabel_motor_type => 'Motor';

  @override
  String get attrLabel_speed_mps => 'Velocidad máxima';

  @override
  String get attrChoice_unit_type_eccr => 'CCR electrónico (eCCR)';

  @override
  String get attrChoice_unit_type_mccr => 'CCR manual (mCCR)';

  @override
  String get attrChoice_unit_type_hccr => 'CCR híbrido (hCCR)';

  @override
  String get attrChoice_unit_type_scr_cmf => 'SCR - flujo másico constante';

  @override
  String get attrChoice_unit_type_scr_pascr => 'SCR - adición pasiva';

  @override
  String get attrChoice_unit_type_scr_escr => 'SCR - control electrónico';

  @override
  String get attrChoice_mount_configuration_back => 'Montaje dorsal';

  @override
  String get attrChoice_mount_configuration_chest => 'Montaje frontal';

  @override
  String get attrChoice_mount_configuration_sidemount => 'Sidemount';

  @override
  String get attrChoice_scrubber_type_axial => 'Axial';

  @override
  String get attrChoice_scrubber_type_radial => 'Radial';

  @override
  String get attrChoice_suit_style_full => 'Traje completo';

  @override
  String get attrChoice_suit_style_shorty => 'Shorty';

  @override
  String get attrChoice_suit_style_two_piece => 'Dos piezas';

  @override
  String get attrChoice_suit_style_semi_dry => 'Semiseco';

  @override
  String get attrChoice_shell_material_trilaminate => 'Trilaminado';

  @override
  String get attrChoice_shell_material_neoprene => 'Neopreno';

  @override
  String get attrChoice_shell_material_crushed_neoprene =>
      'Neopreno comprimido';

  @override
  String get attrChoice_shell_material_vulcanized_rubber =>
      'Caucho vulcanizado';

  @override
  String get attrChoice_seal_type_latex => 'Látex';

  @override
  String get attrChoice_seal_type_silicone => 'Silicona';

  @override
  String get attrChoice_seal_type_neoprene => 'Neopreno';

  @override
  String get attrChoice_tank_material_aluminum => 'Aluminio';

  @override
  String get attrChoice_tank_material_steel => 'Acero';

  @override
  String get attrChoice_tank_material_carbon_composite =>
      'Compuesto de carbono';

  @override
  String get attrChoice_valve_type_din => 'DIN';

  @override
  String get attrChoice_valve_type_yoke => 'Yugo (INT)';

  @override
  String get attrChoice_valve_type_convertible => 'Convertible';

  @override
  String get attrChoice_connection_din => 'DIN';

  @override
  String get attrChoice_connection_yoke => 'Yugo (INT)';

  @override
  String get attrChoice_bcd_style_jacket => 'Chaleco';

  @override
  String get attrChoice_bcd_style_back_inflate => 'Inflado trasero';

  @override
  String get attrChoice_bcd_style_wing => 'Ala';

  @override
  String get attrChoice_bcd_style_sidemount => 'Sidemount';

  @override
  String get attrChoice_heel_type_open_heel => 'Talón abierto';

  @override
  String get attrChoice_heel_type_full_foot => 'Pie completo';

  @override
  String get attrChoice_blade_style_paddle => 'Pala clásica';

  @override
  String get attrChoice_blade_style_split => 'Dividida';

  @override
  String get attrChoice_blade_style_vented => 'Con ranuras';

  @override
  String get attrChoice_mount_wrist => 'Muñeca';

  @override
  String get attrChoice_mount_console => 'Consola';

  @override
  String get attrChoice_mount_hud => 'HUD';

  @override
  String get attrChoice_connectivity_ble => 'Bluetooth (BLE)';

  @override
  String get attrChoice_connectivity_usb => 'USB';

  @override
  String get attrChoice_connectivity_infrared => 'Infrarrojos';

  @override
  String get attrChoice_connectivity_none => 'Ninguna';

  @override
  String get attrChoice_lens_config_single => 'Lente única';

  @override
  String get attrChoice_lens_config_twin => 'Dos lentes';

  @override
  String get attrChoice_lens_config_frameless => 'Sin marco';

  @override
  String get attrChoice_weight_style_belt => 'Cinturón';

  @override
  String get attrChoice_weight_style_integrated => 'Integrado';

  @override
  String get attrChoice_weight_style_trim => 'Trimado';

  @override
  String get attrChoice_weight_style_ankle => 'Tobillo';

  @override
  String get attrChoice_beam_type_spot => 'Focalizado';

  @override
  String get attrChoice_beam_type_flood => 'Difuso';

  @override
  String get attrChoice_beam_type_adjustable => 'Ajustable';

  @override
  String get attrChoice_smb_type_open => 'Abierta';

  @override
  String get attrChoice_smb_type_closed => 'Cerrada';

  @override
  String get attrChoice_reel_type_spool => 'Carrete simple';

  @override
  String get attrChoice_reel_type_ratchet => 'Carrete con trinquete';

  @override
  String get attrChoice_blade_material_stainless => 'Acero inoxidable';

  @override
  String get attrChoice_blade_material_titanium => 'Titanio';

  @override
  String get attrChoice_tip_type_pointed => 'Puntiaguda';

  @override
  String get attrChoice_tip_type_blunt => 'Roma';

  @override
  String get attrChoice_tip_type_line_cutter => 'Cortacabos';

  @override
  String get attrChoice_glove_type_five_finger => 'Cinco dedos';

  @override
  String get attrChoice_glove_type_mitt => 'Manopla';

  @override
  String get attrChoice_glove_type_dry => 'Seco';

  @override
  String get attrChoice_sole_type_hard => 'Suela dura';

  @override
  String get attrChoice_sole_type_soft => 'Suela blanda';

  @override
  String get attrChoice_dpv_style_tow_behind => 'De remolque';

  @override
  String get attrChoice_dpv_style_ride_on => 'De montar';

  @override
  String get attrChoice_dpv_style_handheld => 'De mano';

  @override
  String get attrChoice_battery_type_lithium_ion => 'Iones de litio';

  @override
  String get attrChoice_battery_type_nimh => 'NiMH';

  @override
  String get attrChoice_battery_type_lead_acid => 'Plomo-ácido';

  @override
  String get attrChoice_motor_type_brushless => 'Sin escobillas';

  @override
  String get attrChoice_motor_type_brushed => 'Con escobillas';

  @override
  String get equipment_edit_customFieldsTitle => 'Campos personalizados';

  @override
  String get equipment_edit_addCustomField => 'Añadir campo personalizado';

  @override
  String get attr_flagYes => 'Sí';

  @override
  String get attr_flagNo => 'No';

  @override
  String get equipment_edit_invalidThickness => 'Usa 5, 5/4 o 7/5/3';

  @override
  String get statistics_progression_divesBySuitThickness_title =>
      'Inmersiones por grosor del traje';

  @override
  String get statistics_progression_divesBySuitThickness_subtitle =>
      'Grosor principal del traje en tus inmersiones';

  @override
  String get statistics_progression_divesBySuitThickness_empty =>
      'No hay inmersiones con grosor de traje registrado';

  @override
  String get statistics_progression_divesBySuitThickness_error =>
      'No se pudieron cargar los datos de grosor del traje';

  @override
  String get diveLog_filter_sectionSuitThickness => 'Grosor del traje (mm)';

  @override
  String get diveLog_filter_thicknessMin => 'Mín';

  @override
  String get diveLog_filter_thicknessMax => 'Máx';

  @override
  String get safetySettings_noFlyHeader => 'Volar después de bucear';

  @override
  String get safetySettings_noFlyPreset_standard => 'Estándar (12/18/24 h)';

  @override
  String get safetySettings_noFlyPreset_strict => 'Estricto (18/24/48 h)';

  @override
  String get safetySettings_noFlyPreset_subtitle =>
      'Intervalos orientativos tras una única inmersión sin deco, inmersiones sucesivas e inmersiones con deco';

  @override
  String get flightWindow_closed => 'No bucees más antes de tu vuelo';

  @override
  String get flightWindow_conflict =>
      'Tu tiempo de no volar se extiende más allá de la salida del vuelo';

  @override
  String flightWindow_departs(String time) {
    return 'El vuelo sale $time';
  }

  @override
  String flightWindow_openTitle(String remaining) {
    return 'Tiempo restante para bucear: $remaining';
  }

  @override
  String flightWindow_surfaceBy(String time) {
    return 'Emerger antes de $time';
  }

  @override
  String safetyHub_noFly_active_title(String remaining) {
    return 'No volar: quedan $remaining';
  }

  @override
  String safetyHub_noFly_until(String time) {
    return 'Hasta $time';
  }

  @override
  String get safetyHub_noFly_clear_title => 'Sin restricción de vuelo';

  @override
  String get safetyHub_noFly_clear_subtitle =>
      'Sin restricción de vuelo activa';

  @override
  String safetyHub_noFly_category_single(int hours) {
    return 'Tras una única inmersión sin deco: pauta de $hours h';
  }

  @override
  String safetyHub_noFly_category_repetitive(int hours) {
    return 'Tras inmersiones sucesivas: pauta de $hours h';
  }

  @override
  String safetyHub_noFly_category_deco(int hours) {
    return 'Tras una inmersión con descompresión: pauta de $hours h';
  }

  @override
  String get safetyHub_noFly_disclaimer =>
      'Pautas DAN/UHMS desde tu última inmersión. No sustituye el tiempo de no volar de tu ordenador de buceo.';

  @override
  String get diveLog_detail_altitudeMismatch_title =>
      'El punto de buceo está en altitud';

  @override
  String get diveLog_detail_altitudeMismatch_subtitle =>
      'Este punto registra una altitud pero la inmersión no tiene ninguna, así que el análisis de descompresión asumió nivel del mar. Establece la altitud de la inmersión para corregirlo.';

  @override
  String diveLog_detail_sacVolumeHint(String unit) {
    return 'Añade el volumen del cilindro para mostrar el SAC en $unit/min';
  }

  @override
  String safetyHub_alert_noFly(String remaining) {
    return 'No volar: quedan $remaining';
  }

  @override
  String get emergencyCard_title => 'Emergencia';

  @override
  String emergencyCard_callDan(String name) {
    return 'Llamar a $name';
  }

  @override
  String get emergencyCard_callDan_subtitle =>
      'Línea de emergencias para buceadores. Llama primero: coordinan la evacuación y la derivación a cámara.';

  @override
  String emergencyCard_ems(String number) {
    return 'Emergencias locales: $number';
  }

  @override
  String get emergencyCard_diverSection => 'Buceador';

  @override
  String emergencyCard_bloodType(String value) {
    return 'Grupo sanguíneo: $value';
  }

  @override
  String emergencyCard_allergies(String value) {
    return 'Alergias: $value';
  }

  @override
  String emergencyCard_medications(String value) {
    return 'Medicación: $value';
  }

  @override
  String get emergencyCard_contactsSection => 'Contactos de emergencia';

  @override
  String get emergencyCard_insuranceSection => 'Seguro de buceo';

  @override
  String emergencyCard_insurancePolicy(String number) {
    return 'Póliza $number';
  }

  @override
  String get emergencyCard_chambersSection => 'Cámaras hiperbáricas';

  @override
  String get emergencyCard_chambersNote =>
      'La disponibilidad cambia. Llama siempre primero a la línea de emergencias para buceadores para la derivación.';

  @override
  String emergencyCard_chamberVerified(String date) {
    return 'Datos verificados $date';
  }

  @override
  String get emergencyCard_chambersNearby => 'Cámaras más cercanas';

  @override
  String emergencyCard_chamberViewAll(int count) {
    return 'Ver las $count cámaras';
  }

  @override
  String get emergencyCard_chambersNoneNearby =>
      'No hay ninguna cámara listada dentro del alcance. Llame a la línea de emergencia para buceadores: le derivarán al centro más cercano que pueda tratarle.';

  @override
  String get emergencyCard_chamberCapability_divingEmergency =>
      'Trata accidentes de buceo';

  @override
  String get emergencyCard_chamberCapability_hyperbaricUnit =>
      'Unidad hiperbárica hospitalaria';

  @override
  String get emergencyCard_chamberCapability_elective =>
      'Solo terapia electiva';

  @override
  String get emergencyCard_chamberCapability_unknown =>
      'Capacidad sin confirmar';

  @override
  String get emergencyCard_chamberAvailability_h24 => '24 h';

  @override
  String get emergencyCard_chamberAvailability_onCall => 'De guardia';

  @override
  String get emergencyCard_chamberAvailability_businessHours =>
      'Horario laboral';

  @override
  String get emergencyCard_chamberUnverified => 'No confirmado con el centro';

  @override
  String get chambersDirectory_title => 'Cámaras hiperbáricas';

  @override
  String get chambersDirectory_search => 'Buscar por nombre, ciudad o país';

  @override
  String get chambersDirectory_empty =>
      'Ninguna cámara coincide con esa búsqueda.';

  @override
  String chambersDirectory_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cámaras',
      one: '1 cámara',
    );
    return '$_temp0';
  }

  @override
  String get emergencyCard_hideChamber => 'Ocultar';

  @override
  String get emergencyCard_chamberHidden => 'Cámara ocultada';

  @override
  String get emergencyCard_undo => 'Deshacer';

  @override
  String get emergencyCard_addChamber => 'Añadir cámara';

  @override
  String get emergencyCard_deleteChamber => 'Eliminar';

  @override
  String emergencyCard_regionLabel(String region) {
    return 'Región: $region';
  }

  @override
  String get emergencyCard_regionUnknown =>
      'Región desconocida: se usa la línea mundial';

  @override
  String get emergencyCard_noDiverData =>
      'Sin datos del perfil del buceador. Añade contactos de emergencia, datos médicos y seguro en Perfil del buceador.';

  @override
  String get addChamber_title => 'Añadir cámara';

  @override
  String get addChamber_name => 'Nombre';

  @override
  String get addChamber_country => 'Código de país (p. ej. ES)';

  @override
  String get addChamber_city => 'Ciudad';

  @override
  String get addChamber_phone => 'Teléfono';

  @override
  String get addChamber_notes => 'Notas';

  @override
  String get addChamber_save => 'Guardar';

  @override
  String get addChamber_nameRequired => 'El nombre es obligatorio';

  @override
  String get addChamber_countryRequired => 'El código de país es obligatorio';

  @override
  String get addChamber_phoneRequired => 'El número de teléfono es obligatorio';

  @override
  String get safetyHub_emergencyCardLink => 'Tarjeta de emergencia';

  @override
  String get safetyHub_emergencyCardLink_subtitle =>
      'Sin conexión: línea directa, emergencias, cámaras, tus datos médicos y de seguro';

  @override
  String get dashboard_quickAction_emergency => 'Tarjeta de emergencia';

  @override
  String get incidents_title => 'Registro de casi incidentes';

  @override
  String get incidents_empty =>
      'Sin casi incidentes registrados. Anotar lo que casi sale mal - sin juzgar - hace visibles los patrones antes de que se conviertan en accidentes.';

  @override
  String get incidents_add => 'Registrar casi incidente';

  @override
  String get incidents_linkedDive => 'Vinculado a una inmersión';

  @override
  String get incidents_delete_confirm =>
      '¿Eliminar este informe de casi incidente?';

  @override
  String get incidents_notFound => 'Informe de casi accidente no encontrado';

  @override
  String get incidentEdit_title_new => 'Registrar casi incidente';

  @override
  String get incidentEdit_title_edit => 'Editar casi incidente';

  @override
  String get incidentEdit_category => 'Categoría';

  @override
  String get incidentEdit_severity => 'Gravedad';

  @override
  String get incidentEdit_severity_minor => 'Leve';

  @override
  String get incidentEdit_severity_moderate => 'Moderado';

  @override
  String get incidentEdit_severity_serious => 'Grave';

  @override
  String get incidentEdit_date => 'Cuándo ocurrió';

  @override
  String get incidentEdit_narrative => 'Qué pasó';

  @override
  String get incidentEdit_narrative_hint =>
      'Solo los hechos, con tus palabras. Esto es privado.';

  @override
  String get incidentEdit_narrative_required => 'Describe qué pasó';

  @override
  String get incidentEdit_contributingFactors => 'Qué contribuyó (opcional)';

  @override
  String get incidentEdit_lessonsLearned =>
      'Qué ayudaría la próxima vez (opcional)';

  @override
  String get incidentEdit_save => 'Guardar';

  @override
  String get incidentEdit_privacyNote =>
      'Los informes de casi incidentes se sincronizan entre tus dispositivos y se incluyen en las copias de seguridad, pero nunca en exportaciones ni páginas compartidas del diario.';

  @override
  String get incidentCategory_buoyancy => 'Flotabilidad';

  @override
  String get incidentCategory_gasSupply => 'Suministro de gas';

  @override
  String get incidentCategory_equipment => 'Equipo';

  @override
  String get incidentCategory_buddySeparation => 'Separación del compañero';

  @override
  String get incidentCategory_marineLife => 'Vida marina';

  @override
  String get incidentCategory_boatSurface => 'Barco / superficie';

  @override
  String get incidentCategory_medical => 'Médico';

  @override
  String get incidentCategory_planning => 'Planificación';

  @override
  String get incidentCategory_other => 'Otro';

  @override
  String get safetyHub_incidentsLink => 'Registro de casi incidentes';

  @override
  String get safetyHub_incidentsLink_subtitle =>
      'Notas de incidentes privadas y sin ánimo punitivo';

  @override
  String get diveLog_detail_menu_logNearMiss => 'Registrar casi incidente';

  @override
  String diveLog_detail_linkedIncidents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count casi incidentes vinculados a esta inmersión',
      one: '1 casi incidente vinculado a esta inmersión',
    );
    return '$_temp0';
  }

  @override
  String get planning_card_noFly_subtitle =>
      'Cuenta atrás orientativa desde tus últimas inmersiones';

  @override
  String get settings_section_safety_title => 'Seguridad';

  @override
  String get settings_section_safety_subtitle =>
      'Reglas de revisión y volar tras bucear';

  @override
  String get settings_section_security_title => 'Seguridad de la app';

  @override
  String get settings_section_security_subtitle =>
      'Bloqueo de la app y cifrado de la base de datos';

  @override
  String get settings_security_appLock => 'Bloqueo de la app';

  @override
  String get settings_security_appLock_subtitle =>
      'Requiere tu contraseña o biometría para abrir la app';

  @override
  String get settings_security_biometrics => 'Desbloquear con biometría';

  @override
  String get settings_security_autoLock => 'Bloqueo automático';

  @override
  String get settings_security_autoLock_immediately => 'Inmediatamente';

  @override
  String settings_security_autoLock_minutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Después de $minutes minutos',
      one: 'Después de 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get settings_security_autoLock_never => 'Nunca';

  @override
  String get settings_security_encryption => 'Cifrar base de datos';

  @override
  String get settings_security_encryption_subtitle =>
      'Protege tu archivo de registro de buceo con cifrado en reposo. El cifrado puede afectar al rendimiento.';

  @override
  String get settings_security_encryption_progress_backup =>
      'Creando copia de seguridad...';

  @override
  String get settings_security_encryption_progress_encrypt =>
      'Cifrando base de datos...';

  @override
  String get settings_security_encryption_progress_decrypt =>
      'Descifrando base de datos...';

  @override
  String get settings_security_encryption_progress_reopen =>
      'Reabriendo base de datos...';

  @override
  String get settings_security_changePassword => 'Cambiar contraseña';

  @override
  String get settings_security_regenerateRecovery =>
      'Nuevo código de recuperación';

  @override
  String get settings_security_setPassword => 'Establecer contraseña de la app';

  @override
  String get settings_security_password => 'Contraseña';

  @override
  String get settings_security_confirmPassword => 'Confirmar contraseña';

  @override
  String get settings_security_currentPassword => 'Contraseña actual';

  @override
  String get settings_security_newPassword => 'Nueva contraseña';

  @override
  String get settings_security_passwordTooShort =>
      'La contraseña debe tener al menos 4 caracteres.';

  @override
  String get settings_security_passwordMismatch =>
      'Las contraseñas no coinciden.';

  @override
  String get settings_security_wrongPassword => 'Contraseña incorrecta.';

  @override
  String get settings_security_recoveryCode_title =>
      'Tu código de recuperación';

  @override
  String get settings_security_recoveryCode_explain =>
      'Anótalo y guárdalo en un lugar seguro. Es la única forma de desbloquear la app si olvidas tu contraseña, y reemplaza cualquier código de recuperación anterior.';

  @override
  String get settings_security_recoveryCode_savedConfirm =>
      'He guardado mi código de recuperación';

  @override
  String get settings_security_disableBlockedByEncryption_title =>
      'El cifrado está activado';

  @override
  String get settings_security_disableBlockedByEncryption_body =>
      'Desactiva el cifrado de la base de datos antes de desactivar el bloqueo de la app. La base de datos cifrada necesita una credencial.';

  @override
  String get settings_security_enableEncryption_title =>
      '¿Cifrar la base de datos?';

  @override
  String get settings_security_enableEncryption_body =>
      'Primero se crea una copia de seguridad y después el archivo de la base de datos se vuelve a cifrar en el mismo lugar. Puede tardar un poco con registros grandes. El cifrado puede afectar al rendimiento.';

  @override
  String get settings_security_disableEncryption_title =>
      '¿Desactivar el cifrado?';

  @override
  String get settings_security_disableEncryption_body =>
      'El archivo de la base de datos volverá a guardarse sin cifrar en el disco.';

  @override
  String get settings_security_turnOffAppLock_title =>
      '¿Desactivar el bloqueo de la app?';

  @override
  String get settings_security_turnOffAppLock_body =>
      'La app se abrirá sin pedir tu contraseña.';

  @override
  String get settings_security_unlock_title => 'Introduce tu contraseña';

  @override
  String get settings_security_cancel => 'Cancelar';

  @override
  String get settings_security_continue => 'Continuar';

  @override
  String get settings_security_done => 'Hecho';

  @override
  String get settings_security_turnOff => 'Desactivar';

  @override
  String get dataQuality_inbox_title => 'Calidad de datos';

  @override
  String get dataQuality_badge_tooltip => 'Revisión de calidad de datos';

  @override
  String get dataQuality_scan_start => 'Analizar biblioteca';

  @override
  String dataQuality_scan_progress(int done, int total) {
    return '$done de $total inmersiones comprobadas';
  }

  @override
  String get dataQuality_scan_cancel => 'Cancelar';

  @override
  String dataQuality_scan_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Análisis completado - $count elementos para revisar',
      one: 'Análisis completado - 1 elemento para revisar',
      zero: 'Análisis completado - sin nuevos hallazgos',
    );
    return '$_temp0';
  }

  @override
  String dataQuality_scan_errors(int count) {
    return 'No se pudieron comprobar por completo $count inmersiones';
  }

  @override
  String dataQuality_lastScan(String when) {
    return 'Último análisis: $when';
  }

  @override
  String get dataQuality_neverScanned =>
      'Tu cuaderno de inmersiones aún no se ha analizado';

  @override
  String get dataQuality_empty_title => 'Todo en orden';

  @override
  String get dataQuality_empty_subtitle =>
      'Sin hallazgos de calidad de datos. Analiza tu biblioteca para comprobar si las inmersiones importadas tienen problemas.';

  @override
  String get dataQuality_banner_newChecks =>
      'Hay nuevas comprobaciones de calidad disponibles';

  @override
  String get dataQuality_banner_rescan => 'Volver a analizar';

  @override
  String get dataQuality_action_dismiss => 'Descartar';

  @override
  String get dataQuality_action_dismissFiltered => 'Descartar todo lo mostrado';

  @override
  String get dataQuality_action_goToDive => 'Ir a la inmersión';

  @override
  String get dataQuality_action_undo => 'Deshacer';

  @override
  String get dataQuality_repair_applied => 'Corrección aplicada';

  @override
  String get dataQuality_repair_noChange => 'Aquí no hay nada que corregir';

  @override
  String get dataQuality_repair_needsReview =>
      'Sin corrección automática. Abre la inmersión para corregirlo.';

  @override
  String get dataQuality_repair_failed => 'La corrección falló';

  @override
  String get dataQuality_chip_all => 'Todos';

  @override
  String get dataQuality_chip_time => 'Tiempo';

  @override
  String get dataQuality_chip_profile => 'Perfil';

  @override
  String get dataQuality_chip_gas => 'Gas';

  @override
  String get dataQuality_chip_tanks => 'Tanques';

  @override
  String get dataQuality_chip_duplicates => 'Duplicados';

  @override
  String get dataQuality_chip_sources => 'Fuentes';

  @override
  String get dataQuality_detector_clock_offset => 'Reloj y zona horaria';

  @override
  String get dataQuality_detector_duplicate => 'Posible duplicado';

  @override
  String get dataQuality_detector_split_pair => 'División accidental';

  @override
  String get dataQuality_detector_sample_gap => 'Huecos en las muestras';

  @override
  String get dataQuality_detector_depth_spike => 'Pico de profundidad';

  @override
  String get dataQuality_detector_impossible_rate => 'Velocidad imposible';

  @override
  String get dataQuality_detector_temp_anomaly => 'Anomalía de temperatura';

  @override
  String get dataQuality_detector_pressure_anomaly => 'Anomalía de presión';

  @override
  String get dataQuality_detector_gas_mod => 'Incoherencia de gas/MOD';

  @override
  String get dataQuality_detector_tank_assignment => 'Tanque incorrecto';

  @override
  String get dataQuality_detector_source_conflict => 'Fuentes en conflicto';

  @override
  String dataQuality_msg_clock_future(String date) {
    return 'La inmersión tiene fecha en el futuro ($date)';
  }

  @override
  String dataQuality_msg_clock_ancient(String date) {
    return 'La inmersión tiene fecha anterior a 1950 ($date)';
  }

  @override
  String dataQuality_msg_clock_offset(int hours) {
    return 'El reloj de una fuente difiere en $hours horas';
  }

  @override
  String dataQuality_msg_clock_overlap(int minutes) {
    return 'Se solapa con otra inmersión durante $minutes min';
  }

  @override
  String dataQuality_msg_duplicate(int percent, int minutes) {
    return '$percent % de coincidencia con una inmersión separada por $minutes min';
  }

  @override
  String dataQuality_msg_split(int minutes) {
    return 'El mismo ordenador se reanudó tras un intervalo de superficie de $minutes min';
  }

  @override
  String dataQuality_msg_gap(int count, String longest) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count huecos en las muestras',
      one: '1 hueco en las muestras',
    );
    return '$_temp0, el mayor $longest';
  }

  @override
  String dataQuality_msg_spike(String depth, String time) {
    return 'Pico de profundidad hasta $depth a las $time';
  }

  @override
  String dataQuality_msg_negativeDepth(int count) {
    return '$count muestras de profundidad negativa';
  }

  @override
  String dataQuality_msg_maxDepthMismatch(String stored, String profile) {
    return 'Profundidad máxima registrada $stored, pero el perfil muestra $profile';
  }

  @override
  String dataQuality_msg_rate(String rate, int seconds) {
    return 'Velocidad vertical de $rate mantenida durante $seconds s';
  }

  @override
  String dataQuality_msg_tempRange(String min, String max) {
    return 'Temperatura del agua fuera del rango plausible ($min a $max)';
  }

  @override
  String get dataQuality_msg_tempUnitBug =>
      'Los valores parecen un error de unidad de temperatura';

  @override
  String dataQuality_msg_tempJump(String delta) {
    return 'La temperatura saltó $delta en una sola muestra';
  }

  @override
  String dataQuality_msg_tempScalar(String temp) {
    return 'La temperatura del agua registrada $temp es inverosímil';
  }

  @override
  String dataQuality_msg_pressureSwap(String end, String start) {
    return 'La presión final $end es mayor que la presión inicial $start';
  }

  @override
  String dataQuality_msg_pressureEndpoint(String record, String series) {
    return 'El registro del tanque indica $record, pero la serie del sensor muestra $series';
  }

  @override
  String dataQuality_msg_pressureRise(String rise) {
    return 'La presión subió $rise a mitad de la inmersión sin cambio de gas';
  }

  @override
  String dataQuality_msg_sac(String sac) {
    return 'El consumo en superficie implícito de $sac es inverosímil';
  }

  @override
  String dataQuality_msg_ppo2(String ppo2, String gas, String depth) {
    return 'La ppO2 alcanzó $ppo2 con $gas a $depth';
  }

  @override
  String dataQuality_msg_hypoxic(String gas) {
    return 'Mezcla hipóxica ($gas) mostrada en uso en la superficie';
  }

  @override
  String dataQuality_msg_switchMod(String depth, String mod) {
    return 'El cambio de gas a $depth supera la MOD de ese gas de $mod';
  }

  @override
  String dataQuality_msg_tankInactive(String drop) {
    return 'Este tanque perdió $drop mientras la cronología de gas indica que no estaba en uso';
  }

  @override
  String get dataQuality_msg_twinTanks =>
      'Dos tanques tienen una serie de presión casi idéntica';

  @override
  String dataQuality_msg_sourceDepth(String primary, String source) {
    return 'Las fuentes no coinciden en la profundidad máxima: $primary frente a $source';
  }

  @override
  String get dataQuality_msg_salinityHint =>
      'La proporción constante sugiere una diferencia en el ajuste de agua salada/dulce';

  @override
  String get dataQuality_msg_sourceDuration =>
      'Las fuentes no coinciden en la duración de la inmersión';

  @override
  String get dataQuality_msg_sourceTemp =>
      'Las fuentes no coinciden en la temperatura del agua';

  @override
  String dataQuality_repairLabel_shiftTime(String offset) {
    return 'Desplazar la hora $offset';
  }

  @override
  String get dataQuality_repairLabel_shiftImport =>
      'Desplazar todas las inmersiones de esta importación';

  @override
  String get dataQuality_repairLabel_consolidate => 'Consolidar';

  @override
  String get dataQuality_repairLabel_combine => 'Combinar en una inmersión';

  @override
  String get dataQuality_repairLabel_despike => 'Eliminar pico';

  @override
  String get dataQuality_repairLabel_clampNegative =>
      'Ajustar profundidades sobre la superficie';

  @override
  String get dataQuality_repairLabel_smoothRates => 'Suavizar tasas imposibles';

  @override
  String get dataQuality_repairLabel_fillGaps => 'Rellenar huecos';

  @override
  String get dataQuality_repairLabel_smoothTemp => 'Suavizar temperatura';

  @override
  String get dataQuality_repairLabel_convertTemp => 'Convertir temperatura';

  @override
  String get dataQuality_repairLabel_recompute =>
      'Recalcular a partir del perfil';

  @override
  String get dataQuality_repairLabel_swapPressures =>
      'Intercambiar presión inicial/final';

  @override
  String get dataQuality_repairLabel_setFromSeries => 'Usar valores del sensor';

  @override
  String get dataQuality_repairLabel_swapSeries =>
      'Intercambiar series de tanques';

  @override
  String get dataQuality_repairLabel_reassignSeries =>
      'Mover la serie a otro tanque';

  @override
  String get dataQuality_repairLabel_setPrimary =>
      'Hacer que esta fuente sea la principal';

  @override
  String get dataQuality_repairLabel_split =>
      'Dividir en inmersiones separadas';

  @override
  String get dataQuality_repairLabel_compare => 'Comparar perfiles';

  @override
  String get dataQuality_settings_title => 'Calidad de datos';

  @override
  String get dataQuality_settings_subtitle =>
      'Elige qué comprobaciones se ejecutan al analizar';

  @override
  String dataQuality_summary_flagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos marcados para revisar',
      one: '1 elemento marcado para revisar',
    );
    return '$_temp0';
  }

  @override
  String get dataQuality_summary_review => 'Revisar';

  @override
  String get dataQuality_detail_chip => 'Revisar';

  @override
  String dataQuality_detail_chipCount(int count) {
    return 'Revisar ($count)';
  }

  @override
  String get settings_mediaStorage_quality_section => 'Calidad de subida';

  @override
  String get settings_mediaStorage_quality_photos => 'Fotos';

  @override
  String get settings_mediaStorage_quality_video => 'Vídeo';

  @override
  String get settings_mediaStorage_quality_original => 'Original';

  @override
  String get settings_mediaStorage_quality_high => 'Alta';

  @override
  String get settings_mediaStorage_quality_balanced => 'Equilibrada';

  @override
  String get settings_mediaStorage_quality_small => 'Pequeña';

  @override
  String get settings_mediaStorage_quality_caveat =>
      'Con un nivel de compresión establecido, los originales a resolución completa no se suben; permanecen solo en este dispositivo.';

  @override
  String get settings_mediaStorage_quality_reuploadQueued => 'Resubida en cola';

  @override
  String get settings_mediaStorage_quality_linuxFfmpegHint =>
      'Instala ffmpeg para habilitar la compresión de vídeo. Hasta entonces se suben los originales.';

  @override
  String get settings_mediaStorage_quality_saveFailed =>
      'No se pudo guardar la calidad de subida. Inténtalo de nuevo.';

  @override
  String get settings_mediaStorage_quality_noTranscoderHint =>
      'Este dispositivo no puede comprimir vídeo. Desde él se suben los originales.';

  @override
  String get reef_section_title => 'Ecosistema';

  @override
  String get reef_section_sourcesTooltip => 'Fuentes de datos';

  @override
  String get reef_section_loadError =>
      'No se pudieron cargar los datos del ecosistema en este momento';

  @override
  String get reef_habitat_title => 'Hábitat del arrecife';

  @override
  String get reef_habitat_onReef => 'En un arrecife de coral';

  @override
  String reef_habitat_onReefWithThreat(String threat) {
    return 'En un arrecife de coral, nivel de amenaza $threat';
  }

  @override
  String get reef_habitat_noReef =>
      'No hay arrecife de coral cartografiado en esta ubicación';

  @override
  String get reef_habitat_unavailable =>
      'No se pudo comprobar el hábitat del arrecife ahora';

  @override
  String get water_conditions_title => 'Condiciones del agua';

  @override
  String get water_conditions_unavailable =>
      'No se pudieron comprobar las condiciones del agua en este momento';

  @override
  String get water_conditions_noData =>
      'No hay datos satelitales del agua para esta ubicación';

  @override
  String get water_conditions_freshwater =>
      'La temperatura del agua por satélite solo cubre los océanos';

  @override
  String water_conditions_anomaly(String value) {
    return 'Anomalía $value';
  }

  @override
  String reef_health_degreeHeatingWeeks(String value) {
    return 'Semanas de calentamiento $value C-semanas';
  }

  @override
  String reef_health_seaSurface(String value) {
    return 'Superficie del mar $value';
  }

  @override
  String reef_health_asOf(String date) {
    return 'A fecha de $date';
  }

  @override
  String get reef_health_levelNoStress => 'Sin estrés térmico';

  @override
  String get reef_health_levelWatch => 'Vigilancia de blanqueamiento';

  @override
  String get reef_health_levelWarning => 'Aviso de blanqueamiento';

  @override
  String get reef_health_levelAlert1 => 'Alerta de blanqueamiento nivel 1';

  @override
  String get reef_health_levelAlert2 => 'Alerta de blanqueamiento nivel 2';

  @override
  String get reef_health_levelAlert3 => 'Alerta de blanqueamiento nivel 3';

  @override
  String get reef_health_levelAlert4 => 'Alerta de blanqueamiento nivel 4';

  @override
  String get reef_health_levelAlert5 => 'Alerta de blanqueamiento nivel 5';

  @override
  String get reef_protection_title => 'Área protegida';

  @override
  String get reef_protection_none => 'No está en un área marina protegida';

  @override
  String get reef_protection_unavailable =>
      'No se pudo comprobar el estado de protección ahora';

  @override
  String get reef_protection_viewRegulations => 'Ver normativa';

  @override
  String reef_protection_iucn(String category) {
    return 'IUCN $category';
  }

  @override
  String get reef_species_recordedNearby => 'Registrado cerca';

  @override
  String get reef_species_addToExpected => 'Añadir a especies esperadas';

  @override
  String reef_species_showAll(int count) {
    return 'Mostrar las $count';
  }

  @override
  String get reef_species_showFewer => 'Mostrar menos';

  @override
  String get reef_attribution_title => 'Fuentes de datos del arrecife';

  @override
  String get reef_attribution_wri =>
      'Presencia de arrecife y nivel de amenaza. CC BY 3.0.';

  @override
  String get reef_attribution_noaa =>
      'Temperatura superficial del mar y estrés térmico. Dominio público.';

  @override
  String get reef_attribution_gbif =>
      'Registros de presencia de especies, filtrados a CC0 y CC BY 4.0.';

  @override
  String get reef_attribution_protectedSeas =>
      'Límites de áreas marinas protegidas. CC BY 4.0.';

  @override
  String get enum_visibilityBand_excellent => 'Excelente';

  @override
  String get enum_visibilityBand_good => 'Buena';

  @override
  String get enum_visibilityBand_moderate => 'Moderada';

  @override
  String get enum_visibilityBand_poor => 'Mala';

  @override
  String visibility_range_between(String min, String max, String unit) {
    return '$min-$max $unit';
  }

  @override
  String visibility_range_over(String min, String unit) {
    return 'más de $min $unit';
  }

  @override
  String visibility_range_under(String max, String unit) {
    return 'menos de $max $unit';
  }

  @override
  String get settings_coordinateFormat_title => 'Formato de coordenadas';

  @override
  String get settings_coordinateFormat_subtitle =>
      'Cómo se muestran e introducen las posiciones GPS';

  @override
  String get settings_placeNameLanguage_title =>
      'Idioma de los nombres de lugar';

  @override
  String get settings_placeNameLanguage_subtitle =>
      'Se usa al obtener país, región, localidad y masa de agua a partir de las coordenadas. Los puntos de buceo existentes no cambian.';

  @override
  String get settings_coordinateFormat_decimalDegrees => 'Grados decimales';

  @override
  String get settings_coordinateFormat_degreesDecimalMinutes =>
      'Grados y minutos decimales';

  @override
  String get settings_coordinateFormat_degreesMinutesSeconds =>
      'Grados, minutos, segundos';

  @override
  String get settings_coordinateFormat_utm => 'UTM';

  @override
  String get settings_coordinateFormat_mgrs => 'MGRS';

  @override
  String get settings_visibilityScale_title => 'Escala de visibilidad';

  @override
  String get settings_visibilityScale_subtitle =>
      'Qué distancias cuentan como buena visibilidad donde buceas';

  @override
  String get settings_visibilityScale_preset_tropical => 'Tropical';

  @override
  String get settings_visibilityScale_preset_temperate => 'Templada';

  @override
  String get settings_visibilityScale_preset_coldWater =>
      'Agua fría / Interior';

  @override
  String get settings_visibilityScale_preset_custom => 'Personalizada';

  @override
  String get settings_visibilityScale_customExcellent =>
      'Excelente a partir de';

  @override
  String get settings_visibilityScale_customGood => 'Buena a partir de';

  @override
  String get settings_visibilityScale_customModerate => 'Moderada a partir de';

  @override
  String get settings_visibilityScale_invalidOrder =>
      'Cada valor debe ser menor que el anterior y mayor que cero';

  @override
  String statistics_conditions_visibility_legacySuffix(String band) {
    return '$band (registrado antes de la medición)';
  }

  @override
  String common_selection_countSelected(Object count) {
    return '$count seleccionados';
  }

  @override
  String get common_selection_enterTooltip => 'Seleccionar elementos';

  @override
  String get common_selection_exitTooltip => 'Salir de la selección';

  @override
  String get common_selection_selectAllTooltip => 'Seleccionar todo';

  @override
  String get common_selection_deselectAllTooltip => 'Deseleccionar todo';

  @override
  String common_bulkDelete_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar $count elementos?',
      one: '¿Eliminar $count elemento?',
    );
    return '$_temp0';
  }

  @override
  String get common_bulkDelete_body => 'Esta acción no se puede deshacer.';

  @override
  String common_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eliminados',
      one: '$count eliminado',
    );
    return '$_temp0';
  }

  @override
  String get marineLife_species_delete_confirmTitle => '¿Eliminar especie?';

  @override
  String marineLife_species_delete_confirmBody(String name) {
    return '¿Seguro que quieres eliminar \"$name\"?';
  }

  @override
  String marineLife_species_delete_inUseError(String name) {
    return 'No se puede eliminar \"$name\": tiene avistamientos';
  }

  @override
  String marineLife_species_delete_snackbar(String name) {
    return '\"$name\" eliminada';
  }

  @override
  String marineLife_species_delete_error(String error) {
    return 'Error al eliminar la especie: $error';
  }

  @override
  String get enum_diveField_diveNumber => 'Número de inmersión';

  @override
  String get enum_diveField_dateTime => 'Fecha y hora';

  @override
  String get enum_diveField_siteName => 'Nombre del punto';

  @override
  String get enum_diveField_diveName => 'Nombre de la inmersión';

  @override
  String get enum_diveField_maxDepth => 'Profundidad máxima';

  @override
  String get enum_diveField_avgDepth => 'Profundidad media';

  @override
  String get enum_diveField_bottomTime => 'Tiempo de fondo';

  @override
  String get enum_diveField_runtime => 'Tiempo total';

  @override
  String get enum_diveField_waterTemp => 'Temperatura del agua';

  @override
  String get enum_diveField_airTemp => 'Temperatura del aire';

  @override
  String get enum_diveField_visibility => 'Visibilidad';

  @override
  String get enum_diveField_currentDirection => 'Dirección de la corriente';

  @override
  String get enum_diveField_currentStrength => 'Intensidad de la corriente';

  @override
  String get enum_diveField_swellHeight => 'Altura del oleaje';

  @override
  String get enum_diveField_entryMethod => 'Método de entrada';

  @override
  String get enum_diveField_exitMethod => 'Método de salida';

  @override
  String get enum_diveField_waterType => 'Tipo de agua';

  @override
  String get enum_diveField_altitude => 'Altitud';

  @override
  String get enum_diveField_surfacePressure => 'Presión en superficie';

  @override
  String get enum_diveField_windSpeed => 'Velocidad del viento';

  @override
  String get enum_diveField_cloudCover => 'Nubosidad';

  @override
  String get enum_diveField_precipitation => 'Precipitación';

  @override
  String get enum_diveField_humidity => 'Humedad';

  @override
  String get enum_diveField_weatherDescription => 'Clima';

  @override
  String get enum_diveField_primaryGas => 'Gas principal';

  @override
  String get enum_diveField_diluentGas => 'Gas diluyente';

  @override
  String get enum_diveField_tankCount => 'Número de botellas';

  @override
  String get enum_diveField_startPressure => 'Presión inicial';

  @override
  String get enum_diveField_endPressure => 'Presión final';

  @override
  String get enum_diveField_sacRate => 'Consumo SAC';

  @override
  String get enum_diveField_gasConsumed => 'Gas consumido';

  @override
  String get enum_diveField_totalWeight => 'Lastre total';

  @override
  String get enum_diveField_diveComputerModel => 'Ordenador de buceo';

  @override
  String get enum_diveField_gradientFactorLow => 'GF bajo';

  @override
  String get enum_diveField_gradientFactorHigh => 'GF alto';

  @override
  String get enum_diveField_decoAlgorithm => 'Algoritmo deco';

  @override
  String get enum_diveField_decoConservatism => 'Conservadurismo';

  @override
  String get enum_diveField_cnsStart => 'CNS inicial';

  @override
  String get enum_diveField_cnsEnd => 'CNS final';

  @override
  String get enum_diveField_otu => 'OTU';

  @override
  String get enum_diveField_diveMode => 'Modo de buceo';

  @override
  String get enum_diveField_setpointLow => 'Setpoint bajo';

  @override
  String get enum_diveField_setpointHigh => 'Setpoint alto';

  @override
  String get enum_diveField_setpointDeco => 'Setpoint deco';

  @override
  String get enum_diveField_buddy => 'Compañero';

  @override
  String get enum_diveField_diveMaster => 'Divemaster';

  @override
  String get enum_diveField_siteLocation => 'Ubicación del punto';

  @override
  String get enum_diveField_diveCenterName => 'Centro de buceo';

  @override
  String get enum_diveField_siteLatitude => 'Latitud';

  @override
  String get enum_diveField_siteLongitude => 'Longitud';

  @override
  String get enum_diveField_tripName => 'Viaje';

  @override
  String get enum_diveField_ratingStars => 'Valoración';

  @override
  String get enum_diveField_isFavorite => 'Favorito';

  @override
  String get enum_diveField_notes => 'Notas';

  @override
  String get enum_diveField_tags => 'Etiquetas';

  @override
  String get enum_diveField_importSource => 'Origen de importación';

  @override
  String get enum_diveField_diveTypeName => 'Tipo de inmersión';

  @override
  String get enum_diveField_surfaceInterval => 'Intervalo de superficie';

  @override
  String get enum_diveField_diveNumber_short => '#';

  @override
  String get enum_diveField_dateTime_short => 'Fecha';

  @override
  String get enum_diveField_siteName_short => 'Punto';

  @override
  String get enum_diveField_diveName_short => 'Nombre';

  @override
  String get enum_diveField_maxDepth_short => 'P máx';

  @override
  String get enum_diveField_avgDepth_short => 'P med';

  @override
  String get enum_diveField_bottomTime_short => 'TF';

  @override
  String get enum_diveField_runtime_short => 'TT';

  @override
  String get enum_diveField_waterTemp_short => 'T agua';

  @override
  String get enum_diveField_airTemp_short => 'T aire';

  @override
  String get enum_diveField_visibility_short => 'Vis';

  @override
  String get enum_diveField_currentDirection_short => 'Dir corr.';

  @override
  String get enum_diveField_currentStrength_short => 'Corr.';

  @override
  String get enum_diveField_swellHeight_short => 'Oleaje';

  @override
  String get enum_diveField_entryMethod_short => 'Entrada';

  @override
  String get enum_diveField_exitMethod_short => 'Salida';

  @override
  String get enum_diveField_waterType_short => 'Agua';

  @override
  String get enum_diveField_altitude_short => 'Alt';

  @override
  String get enum_diveField_surfacePressure_short => 'P sup.';

  @override
  String get enum_diveField_windSpeed_short => 'Viento';

  @override
  String get enum_diveField_cloudCover_short => 'Nubes';

  @override
  String get enum_diveField_precipitation_short => 'Precip.';

  @override
  String get enum_diveField_humidity_short => 'Hum.';

  @override
  String get enum_diveField_weatherDescription_short => 'Clima';

  @override
  String get enum_diveField_primaryGas_short => 'Gas';

  @override
  String get enum_diveField_diluentGas_short => 'Dil';

  @override
  String get enum_diveField_tankCount_short => 'Botellas';

  @override
  String get enum_diveField_startPressure_short => 'P inic.';

  @override
  String get enum_diveField_endPressure_short => 'P fin.';

  @override
  String get enum_diveField_sacRate_short => 'SAC';

  @override
  String get enum_diveField_gasConsumed_short => 'Gas cons.';

  @override
  String get enum_diveField_totalWeight_short => 'Lastre';

  @override
  String get enum_diveField_diveComputerModel_short => 'Ordenador';

  @override
  String get enum_diveField_gradientFactorLow_short => 'GFL';

  @override
  String get enum_diveField_gradientFactorHigh_short => 'GFH';

  @override
  String get enum_diveField_decoAlgorithm_short => 'Algo';

  @override
  String get enum_diveField_decoConservatism_short => 'Conserv.';

  @override
  String get enum_diveField_cnsStart_short => 'CNS inic.';

  @override
  String get enum_diveField_cnsEnd_short => 'CNS fin';

  @override
  String get enum_diveField_otu_short => 'OTU';

  @override
  String get enum_diveField_diveMode_short => 'Modo';

  @override
  String get enum_diveField_setpointLow_short => 'SP bajo';

  @override
  String get enum_diveField_setpointHigh_short => 'SP alto';

  @override
  String get enum_diveField_setpointDeco_short => 'SP deco';

  @override
  String get enum_diveField_buddy_short => 'Compa.';

  @override
  String get enum_diveField_diveMaster_short => 'DM';

  @override
  String get enum_diveField_siteLocation_short => 'Ubicación';

  @override
  String get enum_diveField_diveCenterName_short => 'Centro';

  @override
  String get enum_diveField_siteLatitude_short => 'Lat';

  @override
  String get enum_diveField_siteLongitude_short => 'Lon';

  @override
  String get enum_diveField_tripName_short => 'Viaje';

  @override
  String get enum_diveField_ratingStars_short => 'Valor.';

  @override
  String get enum_diveField_isFavorite_short => 'Fav';

  @override
  String get enum_diveField_notes_short => 'Notas';

  @override
  String get enum_diveField_tags_short => 'Etiq.';

  @override
  String get enum_diveField_importSource_short => 'Origen';

  @override
  String get enum_diveField_diveTypeName_short => 'Tipo';

  @override
  String get enum_diveField_surfaceInterval_short => 'IS';

  @override
  String get enum_siteField_siteName => 'Nombre';

  @override
  String get enum_siteField_location => 'Ubicación';

  @override
  String get enum_siteField_country => 'País';

  @override
  String get enum_siteField_region => 'Región';

  @override
  String get enum_siteField_city => 'Ciudad';

  @override
  String get enum_siteField_island => 'Isla';

  @override
  String get enum_siteField_bodyOfWater => 'Masa de agua';

  @override
  String get enum_siteField_diveCount => 'Número de inmersiones';

  @override
  String get enum_siteField_maxDepth => 'Profundidad máxima';

  @override
  String get enum_siteField_minDepth => 'Profundidad mínima';

  @override
  String get enum_siteField_altitude => 'Altitud';

  @override
  String get enum_siteField_waterType => 'Tipo de agua';

  @override
  String get enum_siteField_typicalVisibility => 'Visibilidad típica';

  @override
  String get enum_siteField_typicalCurrent => 'Corriente típica';

  @override
  String get enum_siteField_difficulty => 'Dificultad';

  @override
  String get enum_siteField_entryType => 'Tipo de entrada';

  @override
  String get enum_siteField_bestSeason => 'Mejor época';

  @override
  String get enum_siteField_mooringNumber => 'Número de amarre';

  @override
  String get enum_siteField_hazards => 'Peligros';

  @override
  String get enum_siteField_rating => 'Valoración';

  @override
  String get enum_siteField_notes => 'Notas';

  @override
  String get enum_siteField_latitude => 'Latitud';

  @override
  String get enum_siteField_longitude => 'Longitud';

  @override
  String get enum_siteField_siteName_short => 'Nombre';

  @override
  String get enum_siteField_location_short => 'Ubicación';

  @override
  String get enum_siteField_country_short => 'País';

  @override
  String get enum_siteField_region_short => 'Región';

  @override
  String get enum_siteField_city_short => 'Ciudad';

  @override
  String get enum_siteField_island_short => 'Isla';

  @override
  String get enum_siteField_bodyOfWater_short => 'Masa agua';

  @override
  String get enum_siteField_diveCount_short => 'Inmers.';

  @override
  String get enum_siteField_maxDepth_short => 'P máx';

  @override
  String get enum_siteField_minDepth_short => 'P mín';

  @override
  String get enum_siteField_altitude_short => 'Alt';

  @override
  String get enum_siteField_waterType_short => 'Agua';

  @override
  String get enum_siteField_typicalVisibility_short => 'Vis';

  @override
  String get enum_siteField_typicalCurrent_short => 'Corr.';

  @override
  String get enum_siteField_difficulty_short => 'Dif.';

  @override
  String get enum_siteField_entryType_short => 'Entrada';

  @override
  String get enum_siteField_exitMethod => 'Método de salida';

  @override
  String get enum_siteField_exitMethod_short => 'Salida';

  @override
  String get enum_siteField_bestSeason_short => 'Época';

  @override
  String get enum_siteField_mooringNumber_short => 'Amarre';

  @override
  String get enum_siteField_hazards_short => 'Peligros';

  @override
  String get enum_siteField_rating_short => 'Valor.';

  @override
  String get enum_siteField_notes_short => 'Notas';

  @override
  String get enum_siteField_latitude_short => 'Lat';

  @override
  String get enum_siteField_longitude_short => 'Lon';

  @override
  String get enum_siteField_depthRange => 'Rango de profundidad';

  @override
  String get enum_siteField_depthRange_short => 'Prof.';

  @override
  String get enum_siteField_lastDived => 'Último buceo';

  @override
  String get enum_siteField_lastDived_short => 'Último';

  @override
  String get enum_siteField_maxDepthReached => 'Tu prof. máxima';

  @override
  String get enum_siteField_maxDepthReached_short => 'Tu máx.';

  @override
  String get enum_buddyField_buddyName => 'Nombre';

  @override
  String get enum_buddyField_email => 'Correo electrónico';

  @override
  String get enum_buddyField_phone => 'Teléfono';

  @override
  String get enum_buddyField_certificationLevel => 'Nivel de certificación';

  @override
  String get enum_buddyField_certificationAgency => 'Agencia certificadora';

  @override
  String get enum_buddyField_diveCount => 'Número de inmersiones';

  @override
  String get enum_buddyField_notes => 'Notas';

  @override
  String get enum_buddyField_buddyName_short => 'Nombre';

  @override
  String get enum_buddyField_email_short => 'Correo';

  @override
  String get enum_buddyField_phone_short => 'Tel.';

  @override
  String get enum_buddyField_certificationLevel_short => 'Nivel';

  @override
  String get enum_buddyField_certificationAgency_short => 'Agencia';

  @override
  String get enum_buddyField_diveCount_short => 'Inmers.';

  @override
  String get enum_buddyField_notes_short => 'Notas';

  @override
  String get enum_buddyField_lastDive => 'Último buceo';

  @override
  String get enum_buddyField_lastDive_short => 'Último';

  @override
  String get enum_tripField_tripName => 'Nombre';

  @override
  String get enum_tripField_startDate => 'Fecha de inicio';

  @override
  String get enum_tripField_endDate => 'Fecha de fin';

  @override
  String get enum_tripField_durationDays => 'Duración';

  @override
  String get enum_tripField_location => 'Ubicación';

  @override
  String get enum_tripField_tripType => 'Tipo de viaje';

  @override
  String get enum_tripField_resortName => 'Resort';

  @override
  String get enum_tripField_liveaboardName => 'Crucero de buceo';

  @override
  String get enum_tripField_diveCount => 'Número de inmersiones';

  @override
  String get enum_tripField_totalRuntime => 'Tiempo total acumulado';

  @override
  String get enum_tripField_maxDepth => 'Profundidad máxima';

  @override
  String get enum_tripField_avgDepth => 'Profundidad media';

  @override
  String get enum_tripField_notes => 'Notas';

  @override
  String get enum_tripField_tripName_short => 'Nombre';

  @override
  String get enum_tripField_startDate_short => 'Inicio';

  @override
  String get enum_tripField_endDate_short => 'Fin';

  @override
  String get enum_tripField_durationDays_short => 'Días';

  @override
  String get enum_tripField_location_short => 'Ubicación';

  @override
  String get enum_tripField_tripType_short => 'Tipo';

  @override
  String get enum_tripField_resortName_short => 'Resort';

  @override
  String get enum_tripField_liveaboardName_short => 'Crucero';

  @override
  String get enum_tripField_diveCount_short => 'Inmers.';

  @override
  String get enum_tripField_totalRuntime_short => 'TT acum.';

  @override
  String get enum_tripField_maxDepth_short => 'P máx';

  @override
  String get enum_tripField_avgDepth_short => 'P med';

  @override
  String get enum_tripField_notes_short => 'Notas';

  @override
  String get enum_equipmentField_itemName => 'Nombre';

  @override
  String get enum_equipmentField_fullName => 'Nombre completo';

  @override
  String get enum_equipmentField_type => 'Tipo';

  @override
  String get enum_equipmentField_brand => 'Marca';

  @override
  String get enum_equipmentField_model => 'Modelo';

  @override
  String get enum_equipmentField_serialNumber => 'Número de serie';

  @override
  String get enum_equipmentField_size => 'Talla';

  @override
  String get enum_equipmentField_status => 'Estado';

  @override
  String get enum_equipmentField_isActive => 'Activo';

  @override
  String get enum_equipmentField_purchaseDate => 'Fecha de compra';

  @override
  String get enum_equipmentField_purchasePrice => 'Precio de compra';

  @override
  String get enum_equipmentField_lastServiceDate => 'Último servicio';

  @override
  String get enum_equipmentField_nextServiceDue => 'Próximo servicio';

  @override
  String get enum_equipmentField_daysUntilService => 'Días hasta el servicio';

  @override
  String get enum_equipmentField_serviceIntervalDays => 'Intervalo de servicio';

  @override
  String get enum_equipmentField_notes => 'Notas';

  @override
  String get enum_equipmentField_itemName_short => 'Nombre';

  @override
  String get enum_equipmentField_fullName_short => 'N. completo';

  @override
  String get enum_equipmentField_type_short => 'Tipo';

  @override
  String get enum_equipmentField_brand_short => 'Marca';

  @override
  String get enum_equipmentField_model_short => 'Modelo';

  @override
  String get enum_equipmentField_serialNumber_short => 'N° serie';

  @override
  String get enum_equipmentField_size_short => 'Talla';

  @override
  String get enum_equipmentField_status_short => 'Estado';

  @override
  String get enum_equipmentField_isActive_short => 'Activo';

  @override
  String get enum_equipmentField_purchaseDate_short => 'Comprado';

  @override
  String get enum_equipmentField_purchasePrice_short => 'Precio';

  @override
  String get enum_equipmentField_lastServiceDate_short => 'Revisado';

  @override
  String get enum_equipmentField_nextServiceDue_short => 'Próximo';

  @override
  String get enum_equipmentField_daysUntilService_short => 'Días rest.';

  @override
  String get enum_equipmentField_serviceIntervalDays_short => 'Intervalo';

  @override
  String get enum_equipmentField_notes_short => 'Notas';

  @override
  String get enum_diveCenterField_centerName => 'Nombre';

  @override
  String get enum_diveCenterField_city => 'Ciudad';

  @override
  String get enum_diveCenterField_country => 'País';

  @override
  String get enum_diveCenterField_stateProvince => 'Estado / Provincia';

  @override
  String get enum_diveCenterField_street => 'Calle';

  @override
  String get enum_diveCenterField_postalCode => 'Código postal';

  @override
  String get enum_diveCenterField_phone => 'Teléfono';

  @override
  String get enum_diveCenterField_email => 'Correo electrónico';

  @override
  String get enum_diveCenterField_website => 'Sitio web';

  @override
  String get enum_diveCenterField_affiliations => 'Afiliaciones';

  @override
  String get enum_diveCenterField_rating => 'Valoración';

  @override
  String get enum_diveCenterField_latitude => 'Latitud';

  @override
  String get enum_diveCenterField_longitude => 'Longitud';

  @override
  String get enum_diveCenterField_diveCount => 'Número de inmersiones';

  @override
  String get enum_diveCenterField_notes => 'Notas';

  @override
  String get enum_diveCenterField_centerName_short => 'Nombre';

  @override
  String get enum_diveCenterField_city_short => 'Ciudad';

  @override
  String get enum_diveCenterField_country_short => 'País';

  @override
  String get enum_diveCenterField_stateProvince_short => 'Estado';

  @override
  String get enum_diveCenterField_street_short => 'Calle';

  @override
  String get enum_diveCenterField_postalCode_short => 'CP';

  @override
  String get enum_diveCenterField_phone_short => 'Tel.';

  @override
  String get enum_diveCenterField_email_short => 'Correo';

  @override
  String get enum_diveCenterField_website_short => 'Web';

  @override
  String get enum_diveCenterField_affiliations_short => 'Afiliaciones';

  @override
  String get enum_diveCenterField_rating_short => 'Valor.';

  @override
  String get enum_diveCenterField_latitude_short => 'Lat';

  @override
  String get enum_diveCenterField_longitude_short => 'Lon';

  @override
  String get enum_diveCenterField_diveCount_short => 'Inmers.';

  @override
  String get enum_diveCenterField_notes_short => 'Notas';

  @override
  String get enum_certificationField_certName => 'Nombre';

  @override
  String get enum_certificationField_agency => 'Agencia';

  @override
  String get enum_certificationField_level => 'Certificación';

  @override
  String get enum_certificationField_cardNumber => 'Número de tarjeta';

  @override
  String get enum_certificationField_issueDate => 'Fecha de emisión';

  @override
  String get enum_certificationField_expiryDate => 'Fecha de vencimiento';

  @override
  String get enum_certificationField_instructorName => 'Nombre del instructor';

  @override
  String get enum_certificationField_instructorNumber => 'Número de instructor';

  @override
  String get enum_certificationField_expiryStatus => 'Estado de vigencia';

  @override
  String get enum_certificationField_notes => 'Notas';

  @override
  String get enum_certificationField_certName_short => 'Nombre';

  @override
  String get enum_certificationField_agency_short => 'Agencia';

  @override
  String get enum_certificationField_level_short => 'Certificación';

  @override
  String get enum_certificationField_cardNumber_short => 'N° tarj.';

  @override
  String get enum_certificationField_issueDate_short => 'Emitida';

  @override
  String get enum_certificationField_expiryDate_short => 'Vence';

  @override
  String get enum_certificationField_instructorName_short => 'Instructor';

  @override
  String get enum_certificationField_instructorNumber_short => 'N° instr.';

  @override
  String get enum_certificationField_expiryStatus_short => 'Estado';

  @override
  String get enum_certificationField_notes_short => 'Notas';

  @override
  String get enum_courseField_courseName => 'Nombre';

  @override
  String get enum_courseField_agency => 'Agencia';

  @override
  String get enum_courseField_startDate => 'Fecha de inicio';

  @override
  String get enum_courseField_completionDate => 'Fecha de finalización';

  @override
  String get enum_courseField_durationDays => 'Duración';

  @override
  String get enum_courseField_instructorName => 'Nombre del instructor';

  @override
  String get enum_courseField_instructorNumber => 'Número de instructor';

  @override
  String get enum_courseField_location => 'Ubicación';

  @override
  String get enum_courseField_isCompleted => 'Completado';

  @override
  String get enum_courseField_notes => 'Notas';

  @override
  String get enum_courseField_courseName_short => 'Nombre';

  @override
  String get enum_courseField_agency_short => 'Agencia';

  @override
  String get enum_courseField_startDate_short => 'Inicio';

  @override
  String get enum_courseField_completionDate_short => 'Completado';

  @override
  String get enum_courseField_durationDays_short => 'Duración';

  @override
  String get enum_courseField_instructorName_short => 'Instructor';

  @override
  String get enum_courseField_instructorNumber_short => 'N° instr.';

  @override
  String get enum_courseField_location_short => 'Ubicación';

  @override
  String get enum_courseField_isCompleted_short => 'Hecho';

  @override
  String get enum_courseField_notes_short => 'Notas';

  @override
  String get enum_fieldCategory_accommodation => 'Alojamiento';

  @override
  String get enum_fieldCategory_address => 'Dirección';

  @override
  String get enum_fieldCategory_certification => 'Certificación';

  @override
  String get enum_fieldCategory_conditions => 'Condiciones';

  @override
  String get enum_fieldCategory_contact => 'Contacto';

  @override
  String get enum_fieldCategory_coordinates => 'Coordenadas';

  @override
  String get enum_fieldCategory_dates => 'Fechas';

  @override
  String get enum_fieldCategory_depth => 'Profundidad';

  @override
  String get enum_fieldCategory_details => 'Detalles';

  @override
  String get enum_fieldCategory_instructor => 'Instructor';

  @override
  String get enum_fieldCategory_other => 'Otros';

  @override
  String get enum_fieldCategory_purchase => 'Compra';

  @override
  String get enum_fieldCategory_service => 'Servicio';

  @override
  String get enum_fieldCategory_statistics => 'Estadísticas';

  @override
  String get species_whale_shark_name => 'Tiburón ballena';

  @override
  String get species_whale_shark_desc =>
      'El pez más grande del océano, un filtrador apacible con un característico patrón de manchas.';

  @override
  String get species_great_white_shark_name => 'Tiburón blanco';

  @override
  String get species_great_white_shark_desc =>
      'Icónico depredador ápice que a veces observan los buceadores en jaula en aguas templadas.';

  @override
  String get species_great_hammerhead_shark_name => 'Tiburón martillo gigante';

  @override
  String get species_great_hammerhead_shark_desc =>
      'La especie de martillo más grande, con la cabeza ancha y plana y una aleta dorsal muy alta.';

  @override
  String get species_scalloped_hammerhead_shark_name =>
      'Tiburón martillo común';

  @override
  String get species_scalloped_hammerhead_shark_desc =>
      'Se ve a menudo en grandes cardúmenes en montes submarinos y estaciones de limpieza.';

  @override
  String get species_smooth_hammerhead_shark_name => 'Tiburón martillo liso';

  @override
  String get species_smooth_hammerhead_shark_desc =>
      'Martillo con el borde de la cabeza liso y redondeado, presente en mares templados.';

  @override
  String get species_whitetip_reef_shark_name =>
      'Tiburón punta blanca de arrecife';

  @override
  String get species_whitetip_reef_shark_desc =>
      'Habitante dócil del arrecife que suele descansar en cuevas y bajo salientes durante el día.';

  @override
  String get species_blacktip_reef_shark_name =>
      'Tiburón punta negra de arrecife';

  @override
  String get species_blacktip_reef_shark_desc =>
      'Tiburón de arrecife común en aguas someras, con las puntas de las aletas negras.';

  @override
  String get species_grey_reef_shark_name => 'Tiburón gris de arrecife';

  @override
  String get species_grey_reef_shark_desc =>
      'Depredador activo del arrecife que suele encontrarse en grupos junto a paredes y canales.';

  @override
  String get species_caribbean_reef_shark_name =>
      'Tiburón de arrecife del Caribe';

  @override
  String get species_caribbean_reef_shark_desc =>
      'El tiburón de arrecife más frecuente en el Caribe, robusto y curioso.';

  @override
  String get species_nurse_shark_name => 'Tiburón nodriza';

  @override
  String get species_nurse_shark_desc =>
      'Habitante del fondo de movimientos lentos que suele descansar bajo salientes de coral.';

  @override
  String get species_tawny_nurse_shark_name => 'Tiburón nodriza leonado';

  @override
  String get species_tawny_nurse_shark_desc =>
      'Habitante del fondo del Indopacífico que descansa en cuevas del arrecife y zonas arenosas.';

  @override
  String get species_bull_shark_name => 'Tiburón toro';

  @override
  String get species_bull_shark_desc =>
      'Tiburón robusto y potente presente en ambientes costeros y de agua dulce de todo el mundo.';

  @override
  String get species_tiger_shark_name => 'Tiburón tigre';

  @override
  String get species_tiger_shark_desc =>
      'Gran depredador con un característico patrón de rayas, se encuentra en inmersiones en arrecifes profundos.';

  @override
  String get species_oceanic_whitetip_shark_name =>
      'Tiburón oceánico punta blanca';

  @override
  String get species_oceanic_whitetip_shark_desc =>
      'Tiburón pelágico con aletas redondeadas de punta blanca, se ve en inmersiones en mar abierto.';

  @override
  String get species_thresher_shark_name => 'Tiburón zorro';

  @override
  String get species_thresher_shark_desc =>
      'Se reconoce por su cola extremadamente larga y a veces se observa en estaciones de limpieza.';

  @override
  String get species_pelagic_thresher_shark_name => 'Tiburón zorro pelágico';

  @override
  String get species_pelagic_thresher_shark_desc =>
      'La especie de zorro más pequeña, famosa por avistarse en Monad Shoal, en Filipinas.';

  @override
  String get species_shortfin_mako_shark_name => 'Marrajo dientuso';

  @override
  String get species_shortfin_mako_shark_desc =>
      'El tiburón más rápido del océano, un esbelto depredador de mar abierto de color azul metálico.';

  @override
  String get species_blue_shark_name => 'Tintorera';

  @override
  String get species_blue_shark_desc =>
      'Tiburón pelágico esbelto y de azul intenso, frecuente en inmersiones en aguas azules.';

  @override
  String get species_spotted_wobbegong_name => 'Tiburón alfombra manchado';

  @override
  String get species_spotted_wobbegong_desc =>
      'Tiburón alfombra plano y camuflado que permanece inmóvil sobre los arrecifes rocosos de Australia.';

  @override
  String get species_tasselled_wobbegong_name => 'Tiburón alfombra barbudo';

  @override
  String get species_tasselled_wobbegong_desc =>
      'Tiburón alfombra ornamentado con lóbulos flecosos alrededor de la cabeza, habita arrecifes de coral.';

  @override
  String get species_epaulette_shark_name => 'Tiburón charretera';

  @override
  String get species_epaulette_shark_desc =>
      'Pequeño tiburón que camina por el fondo del arrecife usando sus aletas pectorales.';

  @override
  String get species_horn_shark_name => 'Tiburón cornudo';

  @override
  String get species_horn_shark_desc =>
      'Habitante nocturno del fondo con crestas sobre los ojos, presente frente a California.';

  @override
  String get species_leopard_shark_name => 'Tiburón leopardo';

  @override
  String get species_leopard_shark_desc =>
      'Tiburón de bello patrón que habita bahías someras de la costa del Pacífico de Estados Unidos.';

  @override
  String get species_pacific_angel_shark_name => 'Angelote del Pacífico';

  @override
  String get species_pacific_angel_shark_desc =>
      'Depredador de emboscada de cuerpo plano que permanece enterrado en la arena del fondo.';

  @override
  String get species_sand_tiger_shark_name => 'Toro bacota';

  @override
  String get species_sand_tiger_shark_desc =>
      'Tiburón de aspecto feroz pero dócil, se ve a menudo suspendido en cuevas y pecios.';

  @override
  String get species_zebra_shark_name => 'Tiburón cebra';

  @override
  String get species_zebra_shark_desc =>
      'Tiburón de arrecife moteado que descansa sobre fondos arenosos, común en el Indopacífico.';

  @override
  String get species_blacktip_shark_name => 'Tiburón punta negra';

  @override
  String get species_blacktip_shark_desc =>
      'Tiburón costero veloz conocido por sus saltos en espiral, presente en aguas cálidas de todo el mundo.';

  @override
  String get species_silvertip_shark_name => 'Tiburón de punta plateada';

  @override
  String get species_silvertip_shark_desc =>
      'Tiburón de arrecife atrevido con los bordes de las aletas blancos, habita cerca de paredes profundas y atolones.';

  @override
  String get species_silky_shark_name => 'Tiburón sedoso';

  @override
  String get species_silky_shark_desc =>
      'Tiburón pelágico esbelto de piel suave, frecuente cerca de arrecifes alejados de la costa.';

  @override
  String get species_lemon_shark_name => 'Tiburón limón';

  @override
  String get species_lemon_shark_desc =>
      'Tiburón de color pardo amarillento común en manglares someros y llanuras arenosas.';

  @override
  String get species_galapagos_shark_name => 'Tiburón de Galápagos';

  @override
  String get species_galapagos_shark_desc =>
      'Gran tiburón de arrecife que habita alrededor de islas oceánicas, curioso con los buceadores.';

  @override
  String get species_port_jackson_shark_name => 'Tiburón de Port Jackson';

  @override
  String get species_port_jackson_shark_desc =>
      'Habitante nocturno del fondo con marcas en forma de arnés, endémico de Australia.';

  @override
  String get species_bamboo_shark_name => 'Tiburón bambú de bandas pardas';

  @override
  String get species_bamboo_shark_desc =>
      'Pequeño tiburón dócil de fondo, común en los arrecifes de coral del Indopacífico.';

  @override
  String get species_basking_shark_name => 'Tiburón peregrino';

  @override
  String get species_basking_shark_desc =>
      'El segundo pez más grande, un filtrador que se observa en aguas superficiales templadas.';

  @override
  String get species_greenland_shark_name => 'Tiburón de Groenlandia';

  @override
  String get species_greenland_shark_desc =>
      'Tiburón de aguas profundas y movimientos lentos, uno de los vertebrados más longevos de la Tierra.';

  @override
  String get species_cookiecutter_shark_name => 'Tiburón cigarro';

  @override
  String get species_cookiecutter_shark_desc =>
      'Pequeño tiburón de aguas profundas que arranca bocados circulares a animales marinos mayores.';

  @override
  String get species_sevengill_shark_name => 'Cañabota gata';

  @override
  String get species_sevengill_shark_desc =>
      'Tiburón primitivo con siete hendiduras branquiales, se encuentra en inmersiones templadas entre bosques de kelp.';

  @override
  String get species_pyjama_shark_name => 'Pintarroja pijama';

  @override
  String get species_pyjama_shark_desc =>
      'Pintarroja rayada endémica de Sudáfrica, habita arrecifes rocosos y bosques de kelp.';

  @override
  String get species_spiny_dogfish_name => 'Mielga';

  @override
  String get species_spiny_dogfish_desc =>
      'Tiburón pequeño y abundante con espinas dorsales venenosas, presente en aguas templadas.';

  @override
  String get species_swell_shark_name => 'Pejegato hinchador';

  @override
  String get species_swell_shark_desc =>
      'Pintarroja nocturna que infla su cuerpo cuando se siente amenazada, presente frente a California.';

  @override
  String get species_giant_oceanic_manta_ray_name => 'Manta gigante';

  @override
  String get species_giant_oceanic_manta_ray_desc =>
      'La raya más grande, un majestuoso filtrador con una envergadura de hasta 7 metros.';

  @override
  String get species_reef_manta_ray_name => 'Manta de arrecife';

  @override
  String get species_reef_manta_ray_desc =>
      'Especie de manta más pequeña, se ve con frecuencia en las estaciones de limpieza de los arrecifes tropicales.';

  @override
  String get species_spotted_eagle_ray_name => 'Raya águila moteada';

  @override
  String get species_spotted_eagle_ray_desc =>
      'Raya elegante con manchas blancas y una larga cola en forma de látigo, se ve a menudo en media agua.';

  @override
  String get species_common_eagle_ray_name => 'Águila marina';

  @override
  String get species_common_eagle_ray_desc =>
      'Raya con forma de rombo presente en aguas templadas del Atlántico oriental y del Mediterráneo.';

  @override
  String get species_blue_spotted_ribbontail_ray_name =>
      'Raya látigo de puntos azules';

  @override
  String get species_blue_spotted_ribbontail_ray_desc =>
      'Raya de colores vivos con manchas de un azul brillante, común en los arrecifes del Indopacífico.';

  @override
  String get species_blue_spotted_stingray_name => 'Raya de puntos azules';

  @override
  String get species_blue_spotted_stingray_desc =>
      'Pequeña raya de arrecife con manchas azules dispersas, a menudo enterrada en zonas de arena.';

  @override
  String get species_southern_stingray_name => 'Raya látigo americana';

  @override
  String get species_southern_stingray_desc =>
      'Gran raya de los llanos arenosos del Caribe, famosa en Stingray City.';

  @override
  String get species_round_stingray_name => 'Raya redonda';

  @override
  String get species_round_stingray_desc =>
      'Pequeña raya circular común en zonas arenosas someras del Pacífico oriental.';

  @override
  String get species_short_tail_stingray_name => 'Raya de cola corta';

  @override
  String get species_short_tail_stingray_desc =>
      'Una de las rayas más grandes, presente en aguas templadas del hemisferio sur.';

  @override
  String get species_cowtail_stingray_name => 'Raya de cola de vaca';

  @override
  String get species_cowtail_stingray_desc =>
      'Gran raya oscura con un característico pliegue caudal en forma de bandera, habita arrecifes arenosos.';

  @override
  String get species_atlantic_torpedo_ray_name => 'Torpedo atlántico';

  @override
  String get species_atlantic_torpedo_ray_desc =>
      'Raya eléctrica capaz de producir fuertes descargas, habita los fondos arenosos del Atlántico.';

  @override
  String get species_marbled_electric_ray_name => 'Torpedo marmoleado';

  @override
  String get species_marbled_electric_ray_desc =>
      'Raya eléctrica mediterránea de patrón marmoleado que produce una descarga eléctrica considerable.';

  @override
  String get species_giant_guitarfish_name => 'Pez guitarra gigante';

  @override
  String get species_giant_guitarfish_desc =>
      'Raya con forma de tiburón que habita fondos arenosos del Indopacífico cerca de los arrecifes de coral.';

  @override
  String get species_shovelnose_guitarfish_name =>
      'Pez guitarra de hocico de pala';

  @override
  String get species_shovelnose_guitarfish_desc =>
      'Forma aplanada a medio camino entre raya y tiburón, común en las zonas arenosas someras del Pacífico oriental.';

  @override
  String get species_smalltooth_sawfish_name =>
      'Pez sierra de dientes pequeños';

  @override
  String get species_smalltooth_sawfish_desc =>
      'Raya en peligro crítico con un rostro dentado, habita aguas costeras tropicales.';

  @override
  String get species_green_sawfish_name => 'Pez sierra verde';

  @override
  String get species_green_sawfish_desc =>
      'Gran pez sierra de cuerpo verde oliva que habita los estuarios del Indopacífico occidental.';

  @override
  String get species_devil_ray_name => 'Diablo de mar gigante';

  @override
  String get species_devil_ray_desc =>
      'Gran mobula con aletas cefálicas, se la ve saltando fuera del agua en grupos.';

  @override
  String get species_spinetail_devil_ray_name => 'Diablo de mar espinoso';

  @override
  String get species_spinetail_devil_ray_desc =>
      'Mobula pelágica que a menudo se observa en grandes agregaciones cerca de la superficie.';

  @override
  String get species_lesser_devil_ray_name => 'Diablo de mar pigmeo';

  @override
  String get species_lesser_devil_ray_desc =>
      'La especie de mobula más pequeña; forma grandes cardúmenes en el golfo de California.';

  @override
  String get species_bat_ray_name => 'Raya murciélago';

  @override
  String get species_bat_ray_desc =>
      'Raya con forma de rombo común en los bosques de kelp y las bahías arenosas de California.';

  @override
  String get species_undulate_ray_name => 'Raya mosaico';

  @override
  String get species_undulate_ray_desc =>
      'Raya de bello patrón con líneas onduladas, presente en el Atlántico oriental.';

  @override
  String get species_thornback_ray_name => 'Raya de clavos';

  @override
  String get species_thornback_ray_desc =>
      'Raya europea común con espinas a lo largo del dorso y la cola.';

  @override
  String get species_cownose_ray_name => 'Raya gavilán';

  @override
  String get species_cownose_ray_desc =>
      'Cabeza con una escotadura característica; se ve a menudo en grandes cardúmenes durante las migraciones estacionales.';

  @override
  String get species_marble_ray_name => 'Raya marmoleada';

  @override
  String get species_marble_ray_desc =>
      'Gran raya oscura con puntos blancos, frecuente en las estaciones de limpieza del Indopacífico.';

  @override
  String get species_ocellate_river_stingray_name => 'Raya motoro';

  @override
  String get species_ocellate_river_stingray_desc =>
      'Raya de agua dulce con llamativas manchas anilladas de color naranja, nativa de los ríos de Sudamérica.';

  @override
  String get species_ocellaris_clownfish_name => 'Pez payaso ocelado';

  @override
  String get species_ocellaris_clownfish_desc =>
      'Pequeño pez de franjas naranjas y blancas que vive en simbiosis con las anémonas de los arrecifes de coral.';

  @override
  String get species_clarkii_clownfish_name => 'Pez payaso de Clark';

  @override
  String get species_clarkii_clownfish_desc =>
      'Pez de anémona resistente, de cuerpo oscuro y dos barras blancas, presente en todo el Indopacífico en distintas anémonas.';

  @override
  String get species_tomato_clownfish_name => 'Pez payaso tomate';

  @override
  String get species_tomato_clownfish_desc =>
      'Pez de anémona de un rojo anaranjado intenso con una única barra blanca en la cabeza, común en los arrecifes del Indopacífico.';

  @override
  String get species_regal_blue_tang_name => 'Pez cirujano azul';

  @override
  String get species_regal_blue_tang_desc =>
      'Pez cirujano de azul intenso con una marca negra en forma de paleta y la cola amarilla, habita los arrecifes de coral del Indopacífico.';

  @override
  String get species_yellow_tang_name => 'Pez cirujano amarillo';

  @override
  String get species_yellow_tang_desc =>
      'Pez cirujano de amarillo brillante, común en los arrecifes de Hawái y del Pacífico, suele pastar algas en grupo.';

  @override
  String get species_powder_blue_surgeonfish_name =>
      'Pez cirujano de cara negra';

  @override
  String get species_powder_blue_surgeonfish_desc =>
      'Llamativo pez cirujano azul pálido con la cara negra y la aleta dorsal amarilla, propio del océano Índico.';

  @override
  String get species_sohal_surgeonfish_name => 'Pez cirujano sohal';

  @override
  String get species_sohal_surgeonfish_desc =>
      'Pez cirujano de rayas marcadas con una espina anaranjada, endémico de los arrecifes del mar Rojo y del golfo Pérsico.';

  @override
  String get species_blue_tang_name => 'Cirujano azul del Caribe';

  @override
  String get species_blue_tang_desc =>
      'Pez cirujano de azul profundo común en los arrecifes del Caribe; los juveniles son de un amarillo brillante.';

  @override
  String get species_emperor_angelfish_name => 'Pez ángel emperador';

  @override
  String get species_emperor_angelfish_desc =>
      'Gran pez ángel con llamativas franjas horizontales azules y amarillas. Los juveniles muestran círculos concéntricos azules y blancos.';

  @override
  String get species_french_angelfish_name => 'Pez ángel francés';

  @override
  String get species_french_angelfish_desc =>
      'Gran pez ángel oscuro con las escamas ribeteadas de dorado, se ve a menudo en pareja en los arrecifes del Caribe y del Atlántico occidental.';

  @override
  String get species_queen_angelfish_name => 'Pez ángel reina';

  @override
  String get species_queen_angelfish_desc =>
      'Espectacular pez ángel azul y amarillo con una característica mancha en forma de corona, habita los arrecifes de coral del Caribe.';

  @override
  String get species_regal_angelfish_name => 'Pez ángel regal';

  @override
  String get species_regal_angelfish_desc =>
      'Elegante pez ángel con bandas verticales alternas naranjas, blancas y azules, presente en los arrecifes del Indopacífico.';

  @override
  String get species_rock_beauty_name => 'Isabelita medioluto';

  @override
  String get species_rock_beauty_desc =>
      'Llamativo pez ángel del Caribe con la mitad delantera amarilla y la trasera negra, habita arrecifes rocosos y salientes.';

  @override
  String get species_gray_angelfish_name => 'Pez ángel gris';

  @override
  String get species_gray_angelfish_desc =>
      'Gran pez ángel gris con la cara pálida y el interior de la aleta pectoral amarillo, común en los arrecifes del Caribe.';

  @override
  String get species_copperband_butterflyfish_name =>
      'Pez mariposa de bandas cobrizas';

  @override
  String get species_copperband_butterflyfish_desc =>
      'Pez mariposa característico con bandas verticales anaranjadas y hocico alargado, habita los arrecifes del Indopacífico.';

  @override
  String get species_raccoon_butterflyfish_name => 'Pez mariposa mapache';

  @override
  String get species_raccoon_butterflyfish_desc =>
      'Pez mariposa amarillo con un antifaz oscuro similar al de un mapache, común en los arrecifes del Indopacífico y de Hawái.';

  @override
  String get species_longnose_butterflyfish_name =>
      'Pez mariposa de hocico largo';

  @override
  String get species_longnose_butterflyfish_desc =>
      'Pez mariposa de amarillo brillante con un hocico larguísimo que usa para extraer alimento de las grietas de los arrecifes del Indopacífico.';

  @override
  String get species_threadfin_butterflyfish_name =>
      'Pez mariposa de filamento';

  @override
  String get species_threadfin_butterflyfish_desc =>
      'Pez mariposa blanco con patrón de galones y un filamento dorsal alargado, ampliamente distribuido por el Indopacífico.';

  @override
  String get species_foureye_butterflyfish_name =>
      'Pez mariposa de cuatro ojos';

  @override
  String get species_foureye_butterflyfish_desc =>
      'Pez mariposa pálido con un llamativo falso ocelo cerca de la cola, común en los arrecifes del Caribe.';

  @override
  String get species_spotfin_butterflyfish_name =>
      'Pez mariposa de aleta manchada';

  @override
  String get species_spotfin_butterflyfish_desc =>
      'Pez mariposa blanco y amarillo con una pequeña mancha oscura en la aleta dorsal, presente en el Atlántico occidental.';

  @override
  String get species_banner_butterflyfish_name => 'Pez bandera del mar Rojo';

  @override
  String get species_banner_butterflyfish_desc =>
      'Pez bandera blanco y negro con la aleta dorsal alargada y el vientre amarillo, endémico del mar Rojo.';

  @override
  String get species_moorish_idol_name => 'Ídolo moro';

  @override
  String get species_moorish_idol_desc =>
      'Icónico pez de arrecife con marcadas bandas negras, blancas y amarillas y un largo filamento dorsal.';

  @override
  String get species_green_moray_eel_name => 'Morena verde';

  @override
  String get species_green_moray_eel_desc =>
      'Gran morena de hasta 2,5 m, se ve a menudo con la boca abierta en las grietas de los arrecifes del Atlántico occidental.';

  @override
  String get species_giant_moray_eel_name => 'Morena gigante';

  @override
  String get species_giant_moray_eel_desc =>
      'La morena más grande, supera los 3 m y luce manchas similares a las de un leopardo. Habita los arrecifes de coral del Indopacífico.';

  @override
  String get species_spotted_moray_eel_name => 'Morena manchada';

  @override
  String get species_spotted_moray_eel_desc =>
      'Morena blanca con manchas pardo oscuras, se ve con frecuencia asomando desde los agujeros del arrecife en el Caribe.';

  @override
  String get species_ribbon_eel_name => 'Morena cinta';

  @override
  String get species_ribbon_eel_desc =>
      'Morena esbelta de fosas nasales acampanadas; los machos son de azul intenso y las hembras amarillas. Habita lagunas arenosas del Indopacífico.';

  @override
  String get species_spotted_garden_eel_name => 'Anguila jardinera moteada';

  @override
  String get species_spotted_garden_eel_desc =>
      'Anguila delgada y blanca con manchas negras que vive en colonias sobre la arena, meciéndose en la corriente para capturar plancton.';

  @override
  String get species_splendid_garden_eel_name => 'Anguila jardinera espléndida';

  @override
  String get species_splendid_garden_eel_desc =>
      'Anguila jardinera con bandas naranjas y blancas que forma grandes colonias en los fondos arenosos del Pacífico occidental.';

  @override
  String get species_snowflake_moray_name => 'Morena copo de nieve';

  @override
  String get species_snowflake_moray_desc =>
      'Pequeña morena de cuerpo blanco con marcas negras en forma de copo de nieve, común en el cascajo de arrecife del Indopacífico.';

  @override
  String get species_mandarin_dragonet_name => 'Pez mandarín';

  @override
  String get species_mandarin_dragonet_desc =>
      'Pez diminuto de colores brillantes con patrones psicodélicos azules y naranjas, habita zonas de cascajo del Pacífico occidental.';

  @override
  String get species_common_lionfish_name => 'Pez león';

  @override
  String get species_common_lionfish_desc =>
      'Escorpénido venenoso con espectaculares aletas pectorales en abanico y rayas rojas y blancas. Invasor en el Caribe.';

  @override
  String get species_leaf_scorpionfish_name => 'Pez escorpión hoja';

  @override
  String get species_leaf_scorpionfish_desc =>
      'Escorpénido muy comprimido y con forma de hoja que se mece con la corriente para imitar restos a la deriva en los arrecifes del Indopacífico.';

  @override
  String get species_stonefish_name => 'Pez piedra de arrecife';

  @override
  String get species_stonefish_desc =>
      'El pez más venenoso del mundo, camuflado a la perfección como una roca en el fondo de los arrecifes del Indopacífico. Extremadamente peligroso.';

  @override
  String get species_painted_frogfish_name => 'Pez rana pintado';

  @override
  String get species_painted_frogfish_desc =>
      'Depredador de emboscada rechoncho con un señuelo en la cabeza y coloración muy variable. Habita los arrecifes del Indopacífico.';

  @override
  String get species_giant_frogfish_name => 'Pez rana gigante';

  @override
  String get species_giant_frogfish_desc =>
      'La especie de pez rana más grande, alcanza los 40 cm y se camufla a la perfección entre esponjas y cascajo de coral.';

  @override
  String get species_hairy_frogfish_name => 'Pez rana peludo';

  @override
  String get species_hairy_frogfish_desc =>
      'Pez rana cubierto de apéndices carnosos con forma de gusano que imitan algas, un hallazgo muy buscado por los fotógrafos submarinos.';

  @override
  String get species_clown_triggerfish_name => 'Pez ballesta payaso';

  @override
  String get species_clown_triggerfish_desc =>
      'Ballesta de patrón llamativo con grandes manchas blancas sobre el cuerpo oscuro y labios amarillos, habita los arrecifes del Indopacífico.';

  @override
  String get species_titan_triggerfish_name => 'Pez ballesta titán';

  @override
  String get species_titan_triggerfish_desc =>
      'Gran ballesta agresiva conocida por embestir a los buceadores cerca de su nido. Común en los arrecifes de coral del Indopacífico.';

  @override
  String get species_queen_triggerfish_name => 'Pez ballesta reina';

  @override
  String get species_queen_triggerfish_desc =>
      'Colorida ballesta del Caribe con marcas azules en la cara y largos filamentos caudales.';

  @override
  String get species_picasso_triggerfish_name => 'Pez ballesta picasso';

  @override
  String get species_picasso_triggerfish_desc =>
      'Ballesta con un patrón abstracto de rayas azules, amarillas y negras, común en las planicies de arrecife del Indopacífico.';

  @override
  String get species_yellowmargin_triggerfish_name =>
      'Pez ballesta de margen amarillo';

  @override
  String get species_yellowmargin_triggerfish_desc =>
      'Gran ballesta parda con las aletas ribeteadas de amarillo, conocida por defender su nido con agresividad en los arrecifes del Indopacífico.';

  @override
  String get species_porcupinefish_name => 'Pez erizo';

  @override
  String get species_porcupinefish_desc =>
      'Gran pez espinoso que se infla como una bola cuando se siente amenazado, presente en arrecifes tropicales de todo el mundo.';

  @override
  String get species_guineafowl_pufferfish_name => 'Pez globo perlado';

  @override
  String get species_guineafowl_pufferfish_desc =>
      'Pez globo oscuro cubierto de pequeñas manchas blancas; a veces aparece en una fase de color amarillo dorado en los arrecifes del Indopacífico.';

  @override
  String get species_map_pufferfish_name => 'Pez globo mapa';

  @override
  String get species_map_pufferfish_desc =>
      'Gran pez globo pálido con intrincadas marcas oscuras que recuerdan a un mapa, habita los arrecifes del Indopacífico.';

  @override
  String get species_sharpnose_pufferfish_name => 'Pez globo de hocico afilado';

  @override
  String get species_sharpnose_pufferfish_desc =>
      'Diminuto pez globo con líneas azules en la cara y la cola anaranjada, se ve con frecuencia en los arrecifes del Caribe.';

  @override
  String get species_boxfish_name => 'Pez cofre amarillo';

  @override
  String get species_boxfish_desc =>
      'Los juveniles son cubos de amarillo brillante con puntos negros. Los adultos se oscurecen hasta un gris azulado. Presente en todo el Indopacífico.';

  @override
  String get species_cowfish_name => 'Pez vaca de cuernos largos';

  @override
  String get species_cowfish_desc =>
      'Pez amarillo de cuerpo cúbico con característicos cuernos sobre cada ojo, habita los arrecifes del Indopacífico.';

  @override
  String get species_napoleon_wrasse_name => 'Napoleón';

  @override
  String get species_napoleon_wrasse_desc =>
      'Enorme lábrido de hasta 2 m con una prominente joroba frontal. En peligro y protegido, habita los arrecifes del Indopacífico.';

  @override
  String get species_cleaner_wrasse_name => 'Lábrido limpiador';

  @override
  String get species_cleaner_wrasse_desc =>
      'Pequeño lábrido con una raya azul que atiende estaciones de limpieza y retira parásitos de peces mayores en los arrecifes del Indopacífico.';

  @override
  String get species_yellowtail_coris_name => 'Doncella de cola amarilla';

  @override
  String get species_yellowtail_coris_desc =>
      'Lábrido colorido de cuerpo moteado y cola amarilla; los juveniles son de un rojo anaranjado intenso con marcas blancas.';

  @override
  String get species_bluehead_wrasse_name => 'Lábrido cabeza azul';

  @override
  String get species_bluehead_wrasse_desc =>
      'Lábrido abundante en el Caribe; los machos terminales tienen la cabeza de un azul intenso y el cuerpo verde con barras blancas y negras.';

  @override
  String get species_spanish_hogfish_name => 'Vieja española';

  @override
  String get species_spanish_hogfish_desc =>
      'Lábrido morado y amarillo común en los arrecifes del Caribe; los juveniles actúan como peces limpiadores.';

  @override
  String get species_bumphead_parrotfish_name => 'Pez loro cabeza de búfalo';

  @override
  String get species_bumphead_parrotfish_desc =>
      'La especie de pez loro más grande, alcanza 1,3 m y tiene una enorme protuberancia frontal. Se desplaza en cardúmenes por los arrecifes del Indopacífico.';

  @override
  String get species_stoplight_parrotfish_name => 'Pez loro semáforo';

  @override
  String get species_stoplight_parrotfish_desc =>
      'Pez loro común en el Caribe con espectaculares cambios de color entre la fase inicial y la terminal.';

  @override
  String get species_queen_parrotfish_name => 'Pez loro reina';

  @override
  String get species_queen_parrotfish_desc =>
      'Gran pez loro verde azulado de los arrecifes del Caribe, se le ve a menudo mordiendo el coral para alimentarse de algas.';

  @override
  String get species_yellowtail_damselfish_name => 'Damisela de cola amarilla';

  @override
  String get species_yellowtail_damselfish_desc =>
      'Damisela azul oscura con la cola de un amarillo brillante, común en las crestas y partes altas de los arrecifes del Caribe.';

  @override
  String get species_sergeant_major_name => 'Sargento mayor';

  @override
  String get species_sergeant_major_desc =>
      'Damisela plateada y amarilla con cinco marcadas barras negras, forma grandes agregaciones en los arrecifes del Atlántico tropical.';

  @override
  String get species_three_spot_damselfish_name => 'Damisela de tres manchas';

  @override
  String get species_three_spot_damselfish_desc =>
      'Damisela territorial de color pardo oscuro que defiende con agresividad su jardín de algas en los arrecifes del Caribe.';

  @override
  String get species_chromis_viridis_name => 'Cromis verde azulado';

  @override
  String get species_chromis_viridis_desc =>
      'Pequeña damisela verde iridiscente que se ve en grandes cardúmenes suspendidos sobre los corales ramificados del Indopacífico.';

  @override
  String get species_blue_chromis_name => 'Cromis azul';

  @override
  String get species_blue_chromis_desc =>
      'Damisela planctívora de un azul brillante que forma grandes agregaciones en media agua sobre las paredes de los arrecifes del Caribe.';

  @override
  String get species_nassau_grouper_name => 'Mero de Nassau';

  @override
  String get species_nassau_grouper_desc =>
      'Gran mero del Caribe con una característica raya oscura en el ojo y patrón de bandas, hoy en peligro por la sobrepesca.';

  @override
  String get species_giant_grouper_name => 'Mero gigante';

  @override
  String get species_giant_grouper_desc =>
      'El mayor pez óseo de arrecife, alcanza 2,7 m y 400 kg. Habita cuevas y pecios de todo el Indopacífico.';

  @override
  String get species_coral_grouper_name => 'Mero de coral';

  @override
  String get species_coral_grouper_desc =>
      'Mero de un rojo anaranjado intenso cubierto de puntos azules, especie emblemática de los arrecifes de coral del Indopacífico.';

  @override
  String get species_goliath_grouper_name => 'Mero guasa';

  @override
  String get species_goliath_grouper_desc =>
      'Enorme mero del Atlántico de hasta 2,5 m, se encuentra a menudo cerca de pecios y salientes en Florida y el Caribe.';

  @override
  String get species_potato_grouper_name => 'Mero patata';

  @override
  String get species_potato_grouper_desc =>
      'Gran mero confiado con manchas oscuras en forma de patata, famoso en el Cod Hole de la Gran Barrera de Coral.';

  @override
  String get species_peacock_grouper_name => 'Mero pavo real';

  @override
  String get species_peacock_grouper_desc =>
      'Mero pardo oscuro con puntos azules brillantes y barras verticales pálidas en la parte trasera, común en los arrecifes del Indopacífico.';

  @override
  String get species_yellowfin_tuna_name => 'Atún de aleta amarilla';

  @override
  String get species_yellowfin_tuna_desc =>
      'Veloz depredador pelágico con largas aletas dorsal y anal amarillas, los buceadores lo ven de vez en cuando en puntos alejados de la costa.';

  @override
  String get species_dogtooth_tuna_name => 'Atún dientes de perro';

  @override
  String get species_dogtooth_tuna_desc =>
      'Poderoso atún asociado a los arrecifes y de dientes prominentes, se encuentra en las paredes profundas del Indopacífico.';

  @override
  String get species_great_barracuda_name => 'Gran barracuda';

  @override
  String get species_great_barracuda_desc =>
      'Esbelto depredador plateado de hasta 1,8 m con dientes prominentes, se ve a menudo inmóvil cerca de los arrecifes tropicales.';

  @override
  String get species_blackfin_barracuda_name => 'Barracuda de aleta negra';

  @override
  String get species_blackfin_barracuda_desc =>
      'Barracuda del Indopacífico conocida por formar enormes bancos en forma de tornado en puntos como Barracuda Point.';

  @override
  String get species_mahi_mahi_name => 'Dorado';

  @override
  String get species_mahi_mahi_desc =>
      'Deslumbrante pez pelágico verde azulado y dorado con la frente roma, se ve de vez en cuando en puntos de buceo alejados de la costa.';

  @override
  String get species_giant_trevally_name => 'Jurel gigante';

  @override
  String get species_giant_trevally_desc =>
      'Poderoso depredador plateado de hasta 1,7 m, conocido por cazar en los canales y las paredes de los arrecifes de todo el Indopacífico.';

  @override
  String get species_bluefin_trevally_name => 'Jurel de aletas azules';

  @override
  String get species_bluefin_trevally_desc =>
      'Esbelto jurel con puntos azules, se ve con frecuencia patrullando los bordes de los arrecifes del Indopacífico en pequeños grupos de caza.';

  @override
  String get species_bigeye_trevally_name => 'Jurel ojón';

  @override
  String get species_bigeye_trevally_desc =>
      'Jurel plateado de ojos grandes que forma impresionantes bancos en remolino cerca de las paredes y las estaciones de limpieza.';

  @override
  String get species_bar_jack_name => 'Cojinúa negra';

  @override
  String get species_bar_jack_desc =>
      'Esbelto jurel caribeño con una característica franja azul oscura a lo largo del dorso que continúa hasta el lóbulo inferior de la cola.';

  @override
  String get species_horse_eye_jack_name => 'Jurel ojo de caballo';

  @override
  String get species_horse_eye_jack_desc =>
      'Jurel plateado de ojos grandes que forma bancos cerca de arrecifes y pecios en el Caribe y el Atlántico occidental.';

  @override
  String get species_yellowtail_snapper_name => 'Pargo rabirrubia';

  @override
  String get species_yellowtail_snapper_desc =>
      'Pargo esbelto con una franja lateral y la cola amarillas, se ve a menudo en bancos en media agua sobre los arrecifes del Caribe.';

  @override
  String get species_schoolmaster_snapper_name => 'Pargo amarillo';

  @override
  String get species_schoolmaster_snapper_desc =>
      'Pargo plateado y amarillo con líneas azules bajo el ojo, se encuentra en grupos bajo los salientes de los arrecifes del Caribe.';

  @override
  String get species_bluestripe_snapper_name => 'Pargo de rayas azules';

  @override
  String get species_bluestripe_snapper_desc =>
      'Pargo de amarillo brillante con cuatro rayas horizontales azules, forma bancos densos en los arrecifes del Indopacífico.';

  @override
  String get species_twinspot_snapper_name => 'Pargo de dos manchas';

  @override
  String get species_twinspot_snapper_desc =>
      'Gran pargo rojo de los arrecifes exteriores del Indopacífico, a veces forma bancos en paredes profundas y canales.';

  @override
  String get species_humphead_snapper_name => 'Pargo de medianoche';

  @override
  String get species_humphead_snapper_desc =>
      'Gran pargo oscuro que forma bancos cerca de las paredes escarpadas del Indopacífico; los juveniles son de un llamativo blanco y negro.';

  @override
  String get species_longfin_bannerfish_name => 'Pez bandera de aleta larga';

  @override
  String get species_longfin_bannerfish_desc =>
      'Pez blanco y negro con una larga aleta dorsal filamentosa y la cola amarilla, se ve a menudo en pareja en los arrecifes del Indopacífico.';

  @override
  String get species_batfish_orbicular_name => 'Pez murciélago orbicular';

  @override
  String get species_batfish_orbicular_desc =>
      'Pez plateado con forma de disco y aletas altas que se acerca a los buceadores con curiosidad. Común en pecios y arrecifes del Indopacífico.';

  @override
  String get species_batfish_teira_name => 'Pez murciélago de aleta larga';

  @override
  String get species_batfish_teira_desc =>
      'Pez murciélago de aletas altas con una mancha oscura junto a la aleta pectoral, se ve a menudo en estaciones de limpieza y pecios.';

  @override
  String get species_batfish_pinnatus_name => 'Pez murciélago pinnado';

  @override
  String get species_batfish_pinnatus_desc =>
      'Los juveniles son de negro azabache con vivos bordes anaranjados que recuerdan a un gusano plano tóxico. Habita el Pacífico occidental.';

  @override
  String get species_banggai_cardinalfish_name => 'Pez cardenal de Banggai';

  @override
  String get species_banggai_cardinalfish_desc =>
      'Llamativo pez cardenal plateado y negro con las aletas alargadas, endémico de las islas Banggai, en Indonesia.';

  @override
  String get species_pajama_cardinalfish_name => 'Pez cardenal pijama';

  @override
  String get species_pajama_cardinalfish_desc =>
      'Curioso pez cardenal con la cara amarilla, una banda oscura a media altura y la parte trasera moteada, vive entre los corales del Indopacífico.';

  @override
  String get species_longnose_hawkfish_name => 'Pez halcón de hocico largo';

  @override
  String get species_longnose_hawkfish_desc =>
      'Pequeño pez blanco con un patrón reticulado rojo y el hocico alargado, se posa sobre gorgonias y corales negros.';

  @override
  String get species_arc_eye_hawkfish_name => 'Pez halcón de arco ocular';

  @override
  String get species_arc_eye_hawkfish_desc =>
      'Pequeño pez halcón con un característico arco naranja detrás del ojo, suele posarse sobre las cabezas de coral de los arrecifes del Indopacífico.';

  @override
  String get species_flame_hawkfish_name => 'Pez halcón llama';

  @override
  String get species_flame_hawkfish_desc =>
      'Pez halcón de un rojo brillante con marcas oscuras alrededor del ojo, se posa entre corales Pocillopora de todo el Pacífico occidental.';

  @override
  String get species_fire_goby_name => 'Gobio de fuego';

  @override
  String get species_fire_goby_desc =>
      'Elegante gobio blanco con la primera aleta dorsal alta y la cola rojo anaranjada, flota sobre el cascajo de arrecife del Indopacífico.';

  @override
  String get species_purple_firefish_name => 'Gobio de fuego morado';

  @override
  String get species_purple_firefish_desc =>
      'Delicado gobio con las aletas moradas y una espina dorsal alta, flota cerca de su madriguera en los arrecifes exteriores del Indopacífico.';

  @override
  String get species_yellownose_goby_name => 'Gobio de nariz amarilla';

  @override
  String get species_yellownose_goby_desc =>
      'Diminuto gobio limpiador del Caribe con el hocico amarillo y una raya lateral azul, vive sobre esponjas y cabezas de coral.';

  @override
  String get species_citron_goby_name => 'Gobio limón';

  @override
  String get species_citron_goby_desc =>
      'Diminuto gobio de amarillo intenso que vive entre las ramas de los corales Acropora de los arrecifes del Indopacífico.';

  @override
  String get species_shrimp_goby_name => 'Gobio de Steinitz';

  @override
  String get species_shrimp_goby_desc =>
      'Gobio de color arena que comparte madriguera con camarones alfeidos en una relación mutualista sobre los llanos arenosos del Indopacífico.';

  @override
  String get species_neon_goby_name => 'Gobio neón';

  @override
  String get species_neon_goby_desc =>
      'Diminuto gobio oscuro con una brillante raya azul neón, atiende estaciones de limpieza en las cabezas de coral del Caribe.';

  @override
  String get species_bluestriped_fangblenny_name =>
      'Blenio colmilludo de raya azul';

  @override
  String get species_bluestriped_fangblenny_desc =>
      'Pequeño blenio con una raya azul que imita a los lábridos limpiadores para arrancar escamas a peces desprevenidos.';

  @override
  String get species_sailfin_blenny_name => 'Blenio velero';

  @override
  String get species_sailfin_blenny_desc =>
      'Diminuto blenio del Caribe que despliega una gran aleta dorsal en forma de vela desde su tubo para atraer pareja.';

  @override
  String get species_bicolor_blenny_name => 'Blenio bicolor';

  @override
  String get species_bicolor_blenny_desc =>
      'Pequeño blenio con la mitad delantera pardo oscura y la trasera anaranjada, asoma desde los agujeros de los arrecifes del Indopacífico.';

  @override
  String get species_redlip_blenny_name => 'Blenio de labios rojos';

  @override
  String get species_redlip_blenny_desc =>
      'Blenio oscuro con llamativos labios rojo anaranjados que defiende sus parcelas de algas en las crestas de los arrecifes del Caribe.';

  @override
  String get species_pygmy_seahorse_name =>
      'Caballito de mar pigmeo de Bargibant';

  @override
  String get species_pygmy_seahorse_desc =>
      'Diminuto caballito de mar de menos de 2 cm que imita a la perfección la gorgonia que lo alberga, un sujeto muy codiciado en fotografía macro.';

  @override
  String get species_common_seahorse_name => 'Caballito de mar común';

  @override
  String get species_common_seahorse_desc =>
      'Caballito de mar de tamaño medio y color variable, habita praderas marinas y cascajo de coral de todo el Indopacífico.';

  @override
  String get species_thorny_seahorse_name => 'Caballito de mar espinoso';

  @override
  String get species_thorny_seahorse_desc =>
      'Caballito de mar cubierto de largas espinas que habita praderas marinas y fondos blandos de todo el Indopacífico.';

  @override
  String get species_ornate_ghost_pipefish_name =>
      'Pez aguja fantasma ornamentado';

  @override
  String get species_ornate_ghost_pipefish_desc =>
      'Pez aguja de camuflaje elaborado que flota cabeza abajo junto a crinoideos y corales blandos del Indopacífico.';

  @override
  String get species_robust_ghost_pipefish_name => 'Pez aguja fantasma robusto';

  @override
  String get species_robust_ghost_pipefish_desc =>
      'Gran pez aguja fantasma que imita fanerógamas marinas o algas, se encuentra a menudo en pareja en las aguas costeras del Indopacífico.';

  @override
  String get species_trumpetfish_name => 'Pez trompeta';

  @override
  String get species_trumpetfish_desc =>
      'Pez largo y esbelto que caza siguiendo la sombra de peces mayores, habita los arrecifes del Caribe y del Atlántico en distintos colores.';

  @override
  String get species_cornetfish_name => 'Pez corneta';

  @override
  String get species_cornetfish_desc =>
      'Pez larguísimo de hasta 1,5 m con un filamento caudal, se ve a menudo planeando sobre las planicies de arrecife.';

  @override
  String get species_yellowhead_jawfish_name =>
      'Pez mandíbula de cabeza amarilla';

  @override
  String get species_yellowhead_jawfish_desc =>
      'Pequeño pez de cuerpo azul y cabeza amarilla que flota sobre su madriguera en la arena de los arrecifes del Caribe. Los machos incuban los huevos en la boca.';

  @override
  String get species_flamefish_name => 'Pez cardenal llama';

  @override
  String get species_flamefish_desc =>
      'Pequeño pez cardenal de rojo intenso con una mancha oscura bajo la segunda aleta dorsal, de día se esconde en las grietas de los arrecifes del Caribe.';

  @override
  String get species_longspine_squirrelfish_name => 'Candil de espina larga';

  @override
  String get species_longspine_squirrelfish_desc =>
      'Pez rojo de hábitos nocturnos con ojos grandes y una espina dorsal alargada, de día se refugia bajo los salientes de los arrecifes del Caribe.';

  @override
  String get species_soldierfish_name => 'Soldado de escama grande';

  @override
  String get species_soldierfish_desc =>
      'Pez rojo nocturno con enormes ojos oscuros y escamas grandes, de día forma grupos en cuevas y voladizos.';

  @override
  String get species_flame_angelfish_name => 'Pez ángel llama';

  @override
  String get species_flame_angelfish_desc =>
      'Pez ángel enano de un rojo anaranjado brillante con barras verticales negras y las aletas de punta azul, presente en todo el Pacífico.';

  @override
  String get species_royal_gramma_name => 'Gramma real';

  @override
  String get species_royal_gramma_desc =>
      'Pequeño pez caribeño bicolor con la mitad delantera morada y la trasera amarilla, vive bajo los salientes.';

  @override
  String get species_anthias_lyretail_name => 'Anthias de cola de lira';

  @override
  String get species_anthias_lyretail_desc =>
      'Pez de arrecife abundante que forma grandes nubes naranjas y rosadas sobre las formaciones coralinas del Indopacífico. Los machos son morados.';

  @override
  String get species_mediterranean_grouper_name => 'Mero moreno';

  @override
  String get species_mediterranean_grouper_desc =>
      'Gran mero pardo oscuro con moteado pálido, el depredador emblemático de los fondos rocosos del Mediterráneo.';

  @override
  String get species_mediterranean_moray_name => 'Morena mediterránea';

  @override
  String get species_mediterranean_moray_desc =>
      'Morena pardo oscura con moteado amarillo, se ve con frecuencia asomando desde las grietas rocosas del Mediterráneo.';

  @override
  String get species_ornate_wrasse_name => 'Fredi';

  @override
  String get species_ornate_wrasse_desc =>
      'Colorido lábrido verde con marcas rojas en la cabeza, uno de los lábridos más comunes de los fondos del Mediterráneo.';

  @override
  String get species_red_sea_bannerfish_name => 'Pez mariposa enmascarado';

  @override
  String get species_red_sea_bannerfish_desc =>
      'Pez mariposa de amarillo brillante con un antifaz oscuro, endémico del mar Rojo. Se ve a menudo en pareja.';

  @override
  String get species_red_sea_anemonefish_name => 'Pez payaso del mar Rojo';

  @override
  String get species_red_sea_anemonefish_desc =>
      'Pez de anémona amarillo anaranjado con dos barras blancas, endémico del mar Rojo y del golfo de Adén.';

  @override
  String get species_arabian_angelfish_name => 'Pez ángel arábigo';

  @override
  String get species_arabian_angelfish_desc =>
      'Gran pez ángel azul oscuro con una marcada barra vertical amarilla y la cola del mismo color, endémico del océano Índico occidental.';

  @override
  String get species_king_angelfish_name => 'Pez ángel rey';

  @override
  String get species_king_angelfish_desc =>
      'Gran pez ángel azul oscuro con una barra vertical blanca y la cola amarilla, habita el Pacífico oriental y las Galápagos.';

  @override
  String get species_ocean_sunfish_name => 'Pez luna';

  @override
  String get species_ocean_sunfish_desc =>
      'El pez óseo más pesado, supera las 2 toneladas. Los buceadores lo ven de vez en cuando en las estaciones de limpieza de Bali y las Galápagos.';

  @override
  String get species_lingcod_name => 'Lingcod';

  @override
  String get species_lingcod_desc =>
      'Gran depredador moteado de los arrecifes rocosos del noroeste del Pacífico, a menudo custodiando sus puestas de huevos.';

  @override
  String get species_wolf_eel_name => 'Anguila lobo';

  @override
  String get species_wolf_eel_desc =>
      'Gran anguila lobo gris de cabeza bulbosa y mandíbulas potentes, habita guaridas rocosas del noroeste del Pacífico.';

  @override
  String get species_giant_sea_bass_name => 'Mero gigante de California';

  @override
  String get species_giant_sea_bass_desc =>
      'Enorme serránido que supera los 2 m y los 250 kg, habita los arrecifes rocosos y los bosques de kelp del sur de California.';

  @override
  String get species_garibaldi_name => 'Garibaldi';

  @override
  String get species_garibaldi_desc =>
      'Damisela de color naranja intenso y pez marino oficial de California, muy territorial en los arrecifes de los bosques de kelp.';

  @override
  String get species_sheephead_name => 'Vieja de California';

  @override
  String get species_sheephead_desc =>
      'Gran lábrido con la cabeza y la cola negras, el centro rojo y la barbilla blanca. Habita los bosques de kelp de California.';

  @override
  String get species_copper_rockfish_name => 'Rocote cobrizo';

  @override
  String get species_copper_rockfish_desc =>
      'Rocote de color naranja cobrizo con manchas pálidas, muy habitual en los arrecifes rocosos y bosques de kelp del noroeste del Pacífico.';

  @override
  String get species_oriental_sweetlips_name => 'Pez labios dulces oriental';

  @override
  String get species_oriental_sweetlips_desc =>
      'Gran pez de arrecife del Indopacífico con marcadas rayas blancas y negras y aletas amarillas. Los juveniles ejecutan una danza ondulante.';

  @override
  String get species_harlequin_sweetlips_name => 'Pez labios dulces arlequín';

  @override
  String get species_harlequin_sweetlips_desc =>
      'Los adultos son grises con manchas oscuras; los juveniles son pardos con grandes manchas blancas y nadan con un movimiento ondulante.';

  @override
  String get species_blue_ringed_angelfish_name => 'Pez ángel de anillo azul';

  @override
  String get species_blue_ringed_angelfish_desc =>
      'Gran pez ángel pardo con líneas azules curvas y un característico anillo azul sobre el opérculo.';

  @override
  String get species_yellowbar_angelfish_name => 'Pez ángel de banda amarilla';

  @override
  String get species_yellowbar_angelfish_desc =>
      'Gran pez ángel gris azulado con una llamativa mancha amarilla en el cuerpo, habita el mar Rojo y el océano Índico occidental.';

  @override
  String get species_filefish_scrawled_name => 'Pez lija garabateado';

  @override
  String get species_filefish_scrawled_desc =>
      'Gran pez lija pardo oliváceo con marcas azules en forma de garabato y papada anaranjada, presente en arrecifes tropicales de todo el mundo.';

  @override
  String get species_clown_filefish_name => 'Pez lija de puntos naranjas';

  @override
  String get species_clown_filefish_desc =>
      'Pequeño pez lija verde con puntos naranjas y hocico largo, se alimenta exclusivamente de pólipos de coral Acropora.';

  @override
  String get species_unicornfish_name => 'Pez unicornio de espina azul';

  @override
  String get species_unicornfish_desc =>
      'Pez cirujano gris con un cuerno prominente en la frente y dos espinas azules en la cola, común en las planicies de arrecife del Indopacífico.';

  @override
  String get species_surgeonfish_sailfin_name => 'Pez cirujano velero';

  @override
  String get species_surgeonfish_sailfin_desc =>
      'Pez cirujano de bandas marcadas con las aletas dorsal y anal enormemente desarrolladas, presente en todo el Indopacífico.';

  @override
  String get species_achilles_tang_name => 'Pez cirujano de Aquiles';

  @override
  String get species_achilles_tang_desc =>
      'Pez cirujano pardo oscuro con una llamativa lágrima naranja junto a la cola, habita las zonas de rompiente del Pacífico central.';

  @override
  String get species_doctorfish_name => 'Navajón cirujano';

  @override
  String get species_doctorfish_desc =>
      'Pez cirujano pardo grisáceo con tenues barras oscuras y un escalpelo caudal prominente, común en los arrecifes del Caribe.';

  @override
  String get species_checkerboard_wrasse_name => 'Lábrido ajedrezado';

  @override
  String get species_checkerboard_wrasse_desc =>
      'Lábrido colorido con un patrón ajedrezado de cuadros verdes, rosas y negros por todo el cuerpo.';

  @override
  String get species_bird_wrasse_name => 'Lábrido pájaro';

  @override
  String get species_bird_wrasse_desc =>
      'Lábrido con un hocico larguísimo que recuerda al pico de un ave; los machos son verde oscuro y las hembras pardas.';

  @override
  String get species_sling_jaw_wrasse_name => 'Lábrido de mandíbula extensible';

  @override
  String get species_sling_jaw_wrasse_desc =>
      'Lábrido con una mandíbula extensible que proyecta hacia delante para capturar presas, presenta formas de color amarillas o pardas.';

  @override
  String get species_peacock_flounder_name => 'Lenguado pavo real';

  @override
  String get species_peacock_flounder_desc =>
      'Pez plano de fondo con anillos y puntos azules, capaz de cambiar de color para confundirse con el sustrato.';

  @override
  String get species_hogfish_name => 'Pez perro';

  @override
  String get species_hogfish_desc =>
      'Gran lábrido del Atlántico occidental con hocico porcino y espinas dorsales alargadas, habita cerca de arrecifes y pecios.';

  @override
  String get species_tarpon_name => 'Sábalo atlántico';

  @override
  String get species_tarpon_desc =>
      'Enorme pez plateado con grandes escamas que parecen espejos, los buceadores lo encuentran a veces en cuevas y canales del Caribe.';

  @override
  String get species_permit_name => 'Palometa';

  @override
  String get species_permit_desc =>
      'Jurel de cuerpo alto y plateado con la cola oscura y ahorquillada, habita los llanos arenosos y las inmediaciones de los arrecifes del Caribe.';

  @override
  String get species_spotted_drum_name => 'Tambor manchado';

  @override
  String get species_spotted_drum_desc =>
      'Llamativo pez del Caribe con una aleta dorsal alta y alargada y un marcado patrón de manchas blancas y negras.';

  @override
  String get species_jackknife_fish_name => 'Obispo';

  @override
  String get species_jackknife_fish_desc =>
      'Elegante pez del Caribe con una alta franja negra en la aleta dorsal y una banda diagonal en el cuerpo, vive bajo los salientes.';

  @override
  String get species_bigeye_name => 'Catalufa ojo de vidrio';

  @override
  String get species_bigeye_desc =>
      'Pez nocturno de rojo intenso con grandes ojos reflectantes, se esconde en las cuevas de los arrecifes del Caribe y del Atlántico.';

  @override
  String get species_remora_name => 'Rémora';

  @override
  String get species_remora_desc =>
      'Pez esbelto con un disco de succión en la cabeza que viaja adherido a tiburones, rayas, tortugas y otros animales de gran tamaño.';

  @override
  String get species_tilefish_sand_name => 'Matajuelo blanco';

  @override
  String get species_tilefish_sand_desc =>
      'Pez alargado de color azul pálido que construye montículos de cascajo sobre las zonas arenosas de los arrecifes del Caribe.';

  @override
  String get species_weedy_seadragon_name => 'Dragón de mar común';

  @override
  String get species_weedy_seadragon_desc =>
      'Pariente ornamentado de los caballitos de mar con apéndices en forma de hoja, endémico de las aguas templadas del sur de Australia.';

  @override
  String get species_leafy_seadragon_name => 'Dragón de mar foliado';

  @override
  String get species_leafy_seadragon_desc =>
      'Espectacular dragón de mar cubierto de elaboradas prolongaciones en forma de hoja, endémico del sur de Australia. Un avistamiento de ensueño.';

  @override
  String get species_sailfin_snapper_name => 'Pargo velero';

  @override
  String get species_sailfin_snapper_desc =>
      'Elegante pargo amarillo y azul con las aletas dorsal y anal alargadas, habita los taludes de arrecife del Indopacífico.';

  @override
  String get species_sweetlip_emperor_name => 'Emperador lentejuelas';

  @override
  String get species_sweetlip_emperor_desc =>
      'Gran emperador plateado con líneas azules en la cara y los bordes de las aletas amarillos, común sobre las zonas arenosas de los arrecifes del Indopacífico.';

  @override
  String get species_crocodilefish_name => 'Pez cocodrilo';

  @override
  String get species_crocodilefish_desc =>
      'Depredador de emboscada de cabeza plana con elaborados flecos oculares, permanece perfectamente camuflado en el fondo de los arrecifes del Indopacífico.';

  @override
  String get species_devil_scorpionfish_name => 'Pez escorpión diablo';

  @override
  String get species_devil_scorpionfish_desc =>
      'Escorpénido robusto y camuflado que despliega el colorido interior de sus aletas pectorales como advertencia a los depredadores.';

  @override
  String get species_spiny_devilfish_name => 'Pez diablo espinoso';

  @override
  String get species_spiny_devilfish_desc =>
      'Habitante venenoso del fondo que camina sobre radios modificados de las aletas y muestra sus vistosas pectorales al ser molestado.';

  @override
  String get species_waspfish_name => 'Pez avispa cacatúa';

  @override
  String get species_waspfish_desc =>
      'Pequeño escorpénido comprimido que se mece como una hoja muerta en la corriente sobre los fondos fangosos del Indopacífico.';

  @override
  String get species_stargazer_name => 'Miracielo de margen blanco';

  @override
  String get species_stargazer_desc =>
      'Depredador de emboscada que se entierra en la arena dejando solo los ojos a la vista y puede producir descargas eléctricas. Habita el Indopacífico.';

  @override
  String get species_striped_catfish_name => 'Bagre rayado de coral';

  @override
  String get species_striped_catfish_desc =>
      'Bagre con espinas venenosas; los juveniles forman densos bancos esféricos que ruedan por el fondo de los arrecifes del Indopacífico.';

  @override
  String get species_red_emperor_name => 'Emperador rojo';

  @override
  String get species_red_emperor_desc =>
      'Gran pargo; los adultos son de color rojo rosado y los juveniles presentan marcadas bandas rojas y blancas. Habita los arrecifes del Indopacífico.';

  @override
  String get species_mangrove_snapper_name => 'Pargo de manglar';

  @override
  String get species_mangrove_snapper_desc =>
      'Pargo gris que habita manglares, praderas marinas y arrecifes del Caribe, suele agruparse cerca de las estructuras.';

  @override
  String get species_dottyback_orchid_name => 'Pseudocromis orquídea';

  @override
  String get species_dottyback_orchid_desc =>
      'Pequeño pez de un morado intenso endémico del mar Rojo, entra y sale de las grietas de las paredes escarpadas del arrecife.';

  @override
  String get species_dottyback_royal_name => 'Pseudocromis real';

  @override
  String get species_dottyback_royal_desc =>
      'Pequeño pez bicolor con la parte delantera magenta y la trasera de un amarillo brillante, habita las paredes de arrecife del Indopacífico.';

  @override
  String get species_coral_trout_name => 'Trucha de coral';

  @override
  String get species_coral_trout_desc =>
      'Codiciado depredador de la Gran Barrera de Coral con el cuerpo rojo anaranjado cubierto de puntos azules.';

  @override
  String get species_barramundi_cod_name => 'Mero barramundi';

  @override
  String get species_barramundi_cod_desc =>
      'Mero característico de cabeza pequeña, cuerpo jorobado y lunares oscuros sobre fondo pálido.';

  @override
  String get species_spadefish_atlantic_name => 'Paguala del Atlántico';

  @override
  String get species_spadefish_atlantic_desc =>
      'Pez plateado con forma de disco y barras verticales oscuras, se ve a menudo en grandes bancos alrededor de los pecios del Caribe.';

  @override
  String get species_fusilier_yellowback_name => 'Fusilero de dorso amarillo';

  @override
  String get species_fusilier_yellowback_desc =>
      'Esbelto pez planctívoro azul con el dorso amarillo, forma bancos enormes sobre los taludes de arrecife del Indopacífico.';

  @override
  String get species_fusilier_bluestreak_name => 'Fusilero de raya azul';

  @override
  String get species_fusilier_bluestreak_desc =>
      'Pequeño fusilero azul con una raya lateral oscura, se ve en bancos veloces a lo largo de las paredes de arrecife del Indopacífico.';

  @override
  String get species_porkfish_name => 'Ronco catalina';

  @override
  String get species_porkfish_desc =>
      'Colorido ronco del Caribe con rayas azules y amarillas y dos barras negras en la cabeza, habita cerca de arrecifes y pecios.';

  @override
  String get species_blue_striped_grunt_name => 'Ronco de rayas azules';

  @override
  String get species_blue_striped_grunt_desc =>
      'Ronco amarillo del Caribe con vivas rayas horizontales azules, forma grandes bancos en reposo bajo los salientes durante el día.';

  @override
  String get species_french_grunt_name => 'Ronco condenado';

  @override
  String get species_french_grunt_desc =>
      'Pequeño ronco con rayas amarillas que forma densos bancos en reposo sobre los arrecifes del Caribe durante las horas de luz.';

  @override
  String get species_convict_tang_name => 'Pez cirujano convicto';

  @override
  String get species_convict_tang_desc =>
      'Pez cirujano pálido con seis barras verticales negras, se ve a menudo pastando en grandes bancos en las planicies de arrecife del Indopacífico.';

  @override
  String get species_great_hammerhead_name => 'Tiburón martillo común';

  @override
  String get species_great_hammerhead_desc =>
      'Tiburón característico con la cabeza en forma de martillo festoneado, forma grandes bancos en montes submarinos e islas oceánicas.';

  @override
  String get species_wobbegong_name => 'Tiburón alfombra manchado';

  @override
  String get species_wobbegong_desc =>
      'Tiburón alfombra plano y bien camuflado con lóbulos flecosos alrededor de la boca, habita los arrecifes templados de Australia.';

  @override
  String get species_manta_ray_name => 'Manta de arrecife';

  @override
  String get species_manta_ray_desc =>
      'Grácil gigante de hasta 5 m de envergadura que visita las estaciones de limpieza y se alimenta de plancton en los arrecifes del Indopacífico.';

  @override
  String get species_oceanic_manta_name => 'Manta oceánica';

  @override
  String get species_oceanic_manta_desc =>
      'La raya más grande, con envergaduras superiores a los 7 m, se encuentra en montes submarinos alejados de la costa y estaciones de limpieza.';

  @override
  String get species_undulated_moray_name => 'Morena ondulada';

  @override
  String get species_undulated_moray_desc =>
      'Morena de color verde amarillento con marcas oscuras onduladas, se ve con frecuencia cazando de noche en los arrecifes del Indopacífico.';

  @override
  String get species_whitemouth_moray_name => 'Morena de boca blanca';

  @override
  String get species_whitemouth_moray_desc =>
      'Morena pardo oscura con pequeñas manchas blancas y el interior de la boca de un blanco característico, presente en todo el Indopacífico.';

  @override
  String get species_dragon_moray_name => 'Morena dragón';

  @override
  String get species_dragon_moray_desc =>
      'Llamativa morena con cuernos de dragón sobre las fosas nasales y manchas rojo anaranjadas de leopardo, habita el Indopacífico.';

  @override
  String get species_lyretail_grouper_name => 'Mero de cola de lira';

  @override
  String get species_lyretail_grouper_desc =>
      'Mero rojo rosado con puntos azules y una característica cola en forma de media luna, habita las paredes exteriores de los arrecifes del Indopacífico.';

  @override
  String get species_banded_butterflyfish_name => 'Pez mariposa de bandas';

  @override
  String get species_banded_butterflyfish_desc =>
      'Pez mariposa blanco con cuatro marcadas bandas verticales negras, uno de los peces mariposa más comunes de los arrecifes del Caribe.';

  @override
  String get species_ringed_pipefish_name => 'Pez aguja anillado';

  @override
  String get species_ringed_pipefish_desc =>
      'Pez aguja esbelto con anillos alternos rojos y blancos, habita cuevas y salientes de los arrecifes del Indopacífico.';

  @override
  String get species_razorfish_name => 'Pez navaja';

  @override
  String get species_razorfish_desc =>
      'Pez diminuto que nada en vertical y cabeza abajo en grupos, a menudo se oculta entre las espinas de los erizos en los arrecifes del Indopacífico.';

  @override
  String get species_harlequin_tuskfish_name => 'Lábrido colmillo arlequín';

  @override
  String get species_harlequin_tuskfish_desc =>
      'Lábrido colorido con colmillos de un azul brillante, barras rojo anaranjadas y parches blancos, habita los arrecifes del Pacífico occidental.';

  @override
  String get species_blue_groper_name => 'Lábrido azul australiano';

  @override
  String get species_blue_groper_desc =>
      'Gran lábrido azul endémico del este de Australia, confiado y suele acercarse a los buceadores en los arrecifes templados.';

  @override
  String get species_red_lipped_batfish_name =>
      'Pez murciélago de labios rojos';

  @override
  String get species_red_lipped_batfish_desc =>
      'Extraño pez de cuerpo plano con labios de un rojo brillante que camina sobre aletas modificadas por el fondo marino de las Galápagos.';

  @override
  String get species_orangeband_surgeonfish_name =>
      'Pez cirujano de banda naranja';

  @override
  String get species_orangeband_surgeonfish_desc =>
      'Pez cirujano pardo grisáceo con una banda horizontal naranja detrás del ojo, habita los taludes de arrecife del Pacífico.';

  @override
  String get species_maori_wrasse_name => 'Lábrido maorí';

  @override
  String get species_maori_wrasse_desc =>
      'Lábrido de tamaño medio con una banda oscura detrás de la aleta pectoral, común en los arrecifes del Pacífico y del océano Índico.';

  @override
  String get species_blue_ringed_octopus_name => 'Pulpo de anillos azules';

  @override
  String get species_blue_ringed_octopus_desc =>
      'Pulpo pequeño pero extremadamente venenoso con anillos de un azul brillante que destellan cuando se siente amenazado.';

  @override
  String get species_common_octopus_name => 'Pulpo común';

  @override
  String get species_common_octopus_desc =>
      'Pulpo muy inteligente, conocido por sus rápidos cambios de color y su capacidad para resolver problemas.';

  @override
  String get species_giant_pacific_octopus_name => 'Pulpo gigante del Pacífico';

  @override
  String get species_giant_pacific_octopus_desc =>
      'La especie de pulpo más grande, con brazos que superan los 4 metros de envergadura en las frías aguas del Pacífico.';

  @override
  String get species_mimic_octopus_name => 'Pulpo imitador';

  @override
  String get species_mimic_octopus_desc =>
      'Pulpo extraordinario que imita el aspecto y el comportamiento de otras especies marinas.';

  @override
  String get species_coconut_octopus_name => 'Pulpo del coco';

  @override
  String get species_coconut_octopus_desc =>
      'Pequeño pulpo famoso por transportar cáscaras de coco y usarlas como refugio portátil.';

  @override
  String get species_day_octopus_name => 'Pulpo diurno';

  @override
  String get species_day_octopus_desc =>
      'Cazador activo de día, común en los arrecifes del Indopacífico y de impresionante capacidad de camuflaje.';

  @override
  String get species_wonderpus_octopus_name => 'Pulpo wonderpus';

  @override
  String get species_wonderpus_octopus_desc =>
      'Llamativo pulpo con un bandeado blanco y pardo único, se encuentra en puntos de buceo de fondo blando.';

  @override
  String get species_broadclub_cuttlefish_name => 'Sepia de mazo ancho';

  @override
  String get species_broadclub_cuttlefish_desc =>
      'Gran sepia con hipnóticos despliegues de color, se ve con frecuencia en los arrecifes del Indopacífico.';

  @override
  String get species_pharaoh_cuttlefish_name => 'Sepia faraón';

  @override
  String get species_pharaoh_cuttlefish_desc =>
      'Gran sepia del océano Índico, conocida por sus patrones de color pulsantes.';

  @override
  String get species_flamboyant_cuttlefish_name => 'Sepia flamboyante';

  @override
  String get species_flamboyant_cuttlefish_desc =>
      'Diminuta sepia que camina por el fondo marino mostrando vivos destellos morados, rosas y amarillos.';

  @override
  String get species_giant_cuttlefish_name => 'Sepia gigante';

  @override
  String get species_giant_cuttlefish_desc =>
      'La sepia más grande del mundo, famosa por sus agregaciones masivas de desove en el sur de Australia.';

  @override
  String get species_bigfin_reef_squid_name =>
      'Calamar de arrecife de aleta grande';

  @override
  String get species_bigfin_reef_squid_desc =>
      'Calamar gregario que se encuentra a menudo en las inmersiones nocturnas, atraído por las luces de buceo.';

  @override
  String get species_caribbean_reef_squid_name =>
      'Calamar de arrecife del Caribe';

  @override
  String get species_caribbean_reef_squid_desc =>
      'Calamar curioso que suele flotar en pequeños grupos cerca de los bordes del arrecife en el Caribe.';

  @override
  String get species_bobtail_squid_name => 'Sepiola';

  @override
  String get species_bobtail_squid_desc =>
      'Diminuto calamar nocturno que de día se entierra en la arena, un hallazgo codiciado en el buceo de fondo blando.';

  @override
  String get species_chambered_nautilus_name => 'Nautilo';

  @override
  String get species_chambered_nautilus_desc =>
      'Antiguo fósil viviente de concha enrollada, los buceadores lo ven rara vez en aguas profundas al amanecer.';

  @override
  String get species_spanish_dancer_name => 'Bailarina española';

  @override
  String get species_spanish_dancer_desc =>
      'El nudibranquio más grande; nada ondulando su manto rojo como una bailarina de flamenco.';

  @override
  String get species_chromodoris_willani_name => 'Chromodoris de Willan';

  @override
  String get species_chromodoris_willani_desc =>
      'Llamativo nudibranquio azul y negro con el margen blanco, común en el Indopacífico.';

  @override
  String get species_chromodoris_lochi_name => 'Chromodoris de Loch';

  @override
  String get species_chromodoris_lochi_desc =>
      'Nudibranquio azul con líneas oscuras y borde blanco, presente en todo el Pacífico tropical.';

  @override
  String get species_chromodoris_magnifica_name => 'Chromodoris magnífica';

  @override
  String get species_chromodoris_magnifica_desc =>
      'Nudibranquio de un azul, blanco y naranja brillantes que habita los arrecifes de coral del Indopacífico.';

  @override
  String get species_chromodoris_annae_name => 'Chromodoris de Anna';

  @override
  String get species_chromodoris_annae_desc =>
      'Nudibranquio azul intenso con líneas negras y los rinóforos y las branquias de punta naranja.';

  @override
  String get species_nembrotha_kubaryana_name => 'Babosa neón variable';

  @override
  String get species_nembrotha_kubaryana_desc =>
      'Nudibranquio verde oscuro con vivas marcas naranjas o rojas, se alimenta de tunicados.';

  @override
  String get species_nembrotha_cristata_name => 'Nembrotha crestada';

  @override
  String get species_nembrotha_cristata_desc =>
      'Nudibranquio negro con pústulas y rayas de un verde brillante, habita los arrecifes del Indopacífico.';

  @override
  String get species_phyllidia_varicosa_name => 'Filidia varicosa';

  @override
  String get species_phyllidia_varicosa_desc =>
      'Nudibranquio gris azulado con tubérculos elevados de punta amarilla, tóxico para los depredadores.';

  @override
  String get species_phyllidia_ocellata_name => 'Filidia ocelada';

  @override
  String get species_phyllidia_ocellata_desc =>
      'Nudibranquio blanco con tubérculos elevados rodeados de rosa, habita los arrecifes tropicales.';

  @override
  String get species_pikachu_nudibranch_name => 'Nudibranquio Pikachu';

  @override
  String get species_pikachu_nudibranch_desc =>
      'Diminuta babosa marina amarilla y negra que recuerda a un personaje de dibujos animados, habita el Pacífico.';

  @override
  String get species_anna_rosefieldi_name => 'Nudibranquio Roboastra';

  @override
  String get species_anna_rosefieldi_desc =>
      'Nudibranquio depredador de cuerpo oscuro y vivas rayas longitudinales que caza otras babosas marinas.';

  @override
  String get species_lettuce_sea_slug_name => 'Babosa marina lechuga';

  @override
  String get species_lettuce_sea_slug_desc =>
      'Babosa marina verde de bordes rizados que conserva los cloroplastos de las algas para hacer la fotosíntesis.';

  @override
  String get species_blue_dragon_nudibranch_name => 'Nudibranquio dragón azul';

  @override
  String get species_blue_dragon_nudibranch_desc =>
      'Nudibranquio eólido alargado con ceratas de punta azul que alberga zooxantelas simbióticas.';

  @override
  String get species_gloomy_nudibranch_name => 'Nudibranquio sombrío';

  @override
  String get species_gloomy_nudibranch_desc =>
      'Nudibranquio verde azulado oscuro con crestas ribeteadas de azul, común en los arrecifes del Indopacífico.';

  @override
  String get species_ocellined_nudibranch_name => 'Nudibranquio ocelinado';

  @override
  String get species_ocellined_nudibranch_desc =>
      'Nudibranquio blanco con crestas perfiladas en naranja que forman patrones geométricos sobre el manto.';

  @override
  String get species_glossodoris_cincta_name => 'Nudibranquio Glossodoris';

  @override
  String get species_glossodoris_cincta_desc =>
      'Nudibranquio de color crema con un borde pardo oscuro y el margen del manto anaranjado.';

  @override
  String get species_jorunna_funebris_name => 'Nudibranquio moteado';

  @override
  String get species_jorunna_funebris_desc =>
      'Nudibranquio blanco cubierto de cariofilidios de punta negra, con aspecto de conejito peludo.';

  @override
  String get species_ceratosoma_trilobatum_name => 'Nudibranquio trilobulado';

  @override
  String get species_ceratosoma_trilobatum_desc =>
      'Gran nudibranquio con un cuerno dorsal alto y lóbulos laterales en tonos morados y amarillos.';

  @override
  String get species_hypselodoris_apolegma_name => 'Hypselodoris morado';

  @override
  String get species_hypselodoris_apolegma_desc =>
      'Elegante nudibranquio morado con el borde del manto blanco, habita los arrecifes del Indopacífico.';

  @override
  String get species_hypselodoris_bullockii_name => 'Hypselodoris de Bullock';

  @override
  String get species_hypselodoris_bullockii_desc =>
      'Nudibranquio rosa y morado con los rinóforos de punta amarilla, habita los arrecifes del Indopacífico.';

  @override
  String get species_flabellina_exoptata_name => 'Flabellina deseable';

  @override
  String get species_flabellina_exoptata_desc =>
      'Nudibranquio eólido translúcido con ceratas anaranjadas de punta morada, habita aguas tropicales.';

  @override
  String get species_risbecia_tryoni_name => 'Risbecia de Tryon';

  @override
  String get species_risbecia_tryoni_desc =>
      'Gran nudibranquio pardo y azul que suele encontrarse en parejas de apareamiento en los arrecifes del Indopacífico.';

  @override
  String get species_goniobranchus_kuniei_name => 'Nudibranquio de Kunie';

  @override
  String get species_goniobranchus_kuniei_desc =>
      'Nudibranquio blanco con puntos naranjas y el margen del manto morado, habita el Pacífico occidental.';

  @override
  String get species_mexichromis_multituberculata_name =>
      'Nudibranquio multituberculado';

  @override
  String get species_mexichromis_multituberculata_desc =>
      'Nudibranquio morado y blanco con tubérculos elevados y apéndices de punta naranja.';

  @override
  String get species_chromodoris_dianae_name => 'Chromodoris de Diana';

  @override
  String get species_chromodoris_dianae_desc =>
      'Nudibranquio de azul brillante con rayas negras y branquias anaranjadas, habita el Pacífico occidental.';

  @override
  String get species_phyllodesmium_poindimiei_name => 'Nudibranquio solar';

  @override
  String get species_phyllodesmium_poindimiei_desc =>
      'Nudibranquio eólido translúcido con ceratas ramificadas que alberga zooxantelas.';

  @override
  String get species_chromodoris_elisabethina_name =>
      'Chromodoris de Elisabeth';

  @override
  String get species_chromodoris_elisabethina_desc =>
      'Nudibranquio con líneas azules y amarillas y el borde del manto blanco, común en el Sudeste Asiático.';

  @override
  String get species_doridella_batava_name => 'Dórido de Batavia';

  @override
  String get species_doridella_batava_desc =>
      'Nudibranquio dórido de color variable, de negro a pardo, se encuentra bajo rocas y cascajo en los arrecifes del Indopacífico.';

  @override
  String get species_tiger_cowrie_name => 'Ciprea tigre';

  @override
  String get species_tiger_cowrie_desc =>
      'Gran concha de ciprea moteada de los arrecifes tropicales, a menudo cubierta en parte por su manto.';

  @override
  String get species_tritons_trumpet_name => 'Caracol tritón';

  @override
  String get species_tritons_trumpet_desc =>
      'Gran caracol depredador y enemigo natural de la estrella de mar corona de espinas.';

  @override
  String get species_queen_conch_name => 'Caracol rosado';

  @override
  String get species_queen_conch_desc =>
      'Icónico caracol de gran tamaño de las praderas marinas del Caribe, con el labio interior de un rosa característico.';

  @override
  String get species_banded_coral_shrimp_name => 'Camarón limpiador de bandas';

  @override
  String get species_banded_coral_shrimp_desc =>
      'Camarón limpiador con bandas rojas y blancas y largas antenas blancas, vive en las grietas del arrecife.';

  @override
  String get species_mantis_shrimp_name => 'Camarón mantis pavo real';

  @override
  String get species_mantis_shrimp_desc =>
      'Depredador colorido con potentes apéndices en forma de maza capaces de romper conchas.';

  @override
  String get species_cleaner_shrimp_name => 'Camarón limpiador escarlata';

  @override
  String get species_cleaner_shrimp_desc =>
      'Camarón de un rojo y blanco brillantes que instala estaciones de limpieza para atender a los peces del arrecife.';

  @override
  String get species_pederson_cleaner_shrimp_name =>
      'Camarón limpiador de Pederson';

  @override
  String get species_pederson_cleaner_shrimp_desc =>
      'Camarón limpiador translúcido del Caribe que vive entre los tentáculos de las anémonas.';

  @override
  String get species_harlequin_shrimp_name => 'Camarón arlequín';

  @override
  String get species_harlequin_shrimp_desc =>
      'Camarón de patrón llamativo y pinzas planas que se alimenta exclusivamente de estrellas de mar.';

  @override
  String get species_coleman_shrimp_name => 'Camarón de Coleman';

  @override
  String get species_coleman_shrimp_desc =>
      'Diminuto camarón que vive en pareja sobre erizos de fuego, muy codiciado por los fotógrafos submarinos.';

  @override
  String get species_emperor_shrimp_name => 'Camarón emperador';

  @override
  String get species_emperor_shrimp_desc =>
      'Colorido camarón comensal que viaja sobre pepinos de mar y nudibranquios.';

  @override
  String get species_sexy_shrimp_name => 'Camarón sexy';

  @override
  String get species_sexy_shrimp_desc =>
      'Diminuto camarón de anémona conocido por su danza de balanceo de cola, muy popular en la fotografía macro.';

  @override
  String get species_marble_shrimp_name => 'Camarón marmoleado';

  @override
  String get species_marble_shrimp_desc =>
      'Camarón nocturno de aspecto moteado y patas plumosas, de día se esconde en las grietas del arrecife.';

  @override
  String get species_spiny_lobster_name => 'Langosta espinosa del Caribe';

  @override
  String get species_spiny_lobster_desc =>
      'Gran langosta sin pinzas y de largas antenas, se refugia bajo los salientes del arrecife.';

  @override
  String get species_painted_spiny_lobster_name => 'Langosta espinosa pintada';

  @override
  String get species_painted_spiny_lobster_desc =>
      'Langosta de colores vibrantes con las patas rayadas en azul, verde y blanco, habita los arrecifes del Indopacífico.';

  @override
  String get species_slipper_lobster_name => 'Cigarra de mar';

  @override
  String get species_slipper_lobster_desc =>
      'Langosta nocturna de cuerpo aplanado con anchas placas antenales en lugar de largos látigos.';

  @override
  String get species_squat_lobster_name => 'Galatea';

  @override
  String get species_squat_lobster_desc =>
      'Diminuto crustáceo rosa violáceo que vive en las esponjas barril gigantes, un favorito de la fotografía macro.';

  @override
  String get species_hermit_crab_name => 'Cangrejo ermitaño de patas azules';

  @override
  String get species_hermit_crab_desc =>
      'Pequeño cangrejo ermitaño con las patas de un azul brillante, muy común en los arrecifes del Caribe.';

  @override
  String get species_orangutan_crab_name => 'Cangrejo orangután';

  @override
  String get species_orangutan_crab_desc =>
      'Diminuto cangrejo peludo que vive en el coral burbuja, llamado así por su parecido con un orangután.';

  @override
  String get species_decorator_crab_name => 'Cangrejo decorador';

  @override
  String get species_decorator_crab_desc =>
      'Maestro del disfraz que fija esponjas, algas e hidroides a su caparazón.';

  @override
  String get species_porcelain_crab_name => 'Cangrejo porcelana de anémona';

  @override
  String get species_porcelain_crab_desc =>
      'Cangrejo plano y moteado que vive en las anémonas y filtra el agua con sus piezas bucales plumosas.';

  @override
  String get species_arrow_crab_name => 'Cangrejo flecha';

  @override
  String get species_arrow_crab_desc =>
      'Cangrejo caribeño de patas larguísimas y rayadas, con un rostro largo y puntiagudo.';

  @override
  String get species_channel_clinging_crab_name => 'Cangrejo araña del Caribe';

  @override
  String get species_channel_clinging_crab_desc =>
      'Gran cangrejo de arrecife del Caribe con el cuerpo oscuro y las pinzas rojo anaranjadas, vive en las grietas.';

  @override
  String get species_coral_crab_name => 'Cangrejo guardián del coral';

  @override
  String get species_coral_crab_desc =>
      'Pequeño cangrejo moteado que vive en simbiosis con los corales Pocillopora y defiende a su anfitrión.';

  @override
  String get species_crown_of_thorns_starfish_name =>
      'Estrella de mar corona de espinas';

  @override
  String get species_crown_of_thorns_starfish_desc =>
      'Estrella venenosa de muchos brazos que se alimenta de coral y puede devastar los arrecifes durante sus explosiones demográficas.';

  @override
  String get species_blue_linckia_starfish_name => 'Estrella de mar azul';

  @override
  String get species_blue_linckia_starfish_desc =>
      'Estrella de mar de un azul intenso, muy habitual en las planicies y los taludes de los arrecifes del Indopacífico.';

  @override
  String get species_red_knob_starfish_name =>
      'Estrella de mar de nódulos rojos';

  @override
  String get species_red_knob_starfish_desc =>
      'Gran estrella de mar gris con prominentes espinas de punta roja, habita las zonas arenosas del arrecife.';

  @override
  String get species_chocolate_chip_starfish_name =>
      'Estrella de mar chip de chocolate';

  @override
  String get species_chocolate_chip_starfish_desc =>
      'Estrella de mar parda con nódulos oscuros elevados que recuerdan a pepitas de chocolate, vive sobre sustratos arenosos.';

  @override
  String get species_cushion_star_name => 'Estrella cojín';

  @override
  String get species_cushion_star_desc =>
      'Estrella de mar pentagonal e hinchada con los brazos reducidos, habita las planicies de arrecife del Indopacífico.';

  @override
  String get species_fromia_starfish_name => 'Estrella de mar elegante';

  @override
  String get species_fromia_starfish_desc =>
      'Pequeña estrella de mar rojo anaranjada con los bordes de las placas pálidos, lo que crea un patrón de mosaico.';

  @override
  String get species_basket_star_name => 'Estrella cesta';

  @override
  String get species_basket_star_desc =>
      'Sus brazos, elaboradamente ramificados, se despliegan de noche para filtrar el alimento de la corriente.';

  @override
  String get species_brittle_star_name => 'Ofiura de bandas';

  @override
  String get species_brittle_star_desc =>
      'Ofiura rayada que vive bajo las rocas y en las grietas, con brazos ágiles y serpenteantes.';

  @override
  String get species_feather_star_name => 'Estrella plumosa';

  @override
  String get species_feather_star_desc =>
      'Crinoideo de muchos brazos posado en los resaltes del arrecife, filtra el alimento con sus brazos plumosos.';

  @override
  String get species_black_feather_star_name => 'Estrella plumosa negra';

  @override
  String get species_black_feather_star_desc =>
      'Crinoideo oscuro capaz de nadar brevemente agitando rítmicamente sus numerosos brazos.';

  @override
  String get species_long_spined_sea_urchin_name => 'Erizo de espinas largas';

  @override
  String get species_long_spined_sea_urchin_desc =>
      'Erizo negro de largas espinas venenosas, un herbívoro clave para los arrecifes del Caribe.';

  @override
  String get species_fire_urchin_name => 'Erizo de fuego';

  @override
  String get species_fire_urchin_desc =>
      'Erizo de cuerpo blando con espinas venenosas que provocan picaduras dolorosas al contacto.';

  @override
  String get species_pencil_urchin_name => 'Erizo lápiz';

  @override
  String get species_pencil_urchin_desc =>
      'Erizo robusto de espinas gruesas y romas, se encaja en las grietas del arrecife.';

  @override
  String get species_collector_urchin_name => 'Erizo coleccionista';

  @override
  String get species_collector_urchin_desc =>
      'Erizo que se cubre de restos y fragmentos de algas para camuflarse.';

  @override
  String get species_sea_apple_name => 'Manzana de mar';

  @override
  String get species_sea_apple_desc =>
      'Pepino de mar de colores vivos con tentáculos orales que utiliza para filtrar el alimento.';

  @override
  String get species_pineapple_sea_cucumber_name => 'Pepino de mar piña';

  @override
  String get species_pineapple_sea_cucumber_desc =>
      'Gran pepino de mar rojo anaranjado con papilas en forma de estrella, habita los taludes de arrecife.';

  @override
  String get species_black_sea_cucumber_name => 'Pepino de mar negro';

  @override
  String get species_black_sea_cucumber_desc =>
      'Pepino de mar negro muy común en las planicies arenosas de arrecife de todo el Indopacífico.';

  @override
  String get species_leopard_sea_cucumber_name => 'Pepino de mar leopardo';

  @override
  String get species_leopard_sea_cucumber_desc =>
      'Pepino de mar moteado que expulsa pegajosos túbulos de Cuvier blancos al ser molestado.';

  @override
  String get species_sand_dollar_name => 'Dólar de arena';

  @override
  String get species_sand_dollar_desc =>
      'Erizo plano con forma de disco que vive parcialmente enterrado en sustratos arenosos.';

  @override
  String get species_moon_jellyfish_name => 'Medusa luna';

  @override
  String get species_moon_jellyfish_desc =>
      'Medusa translúcida con forma de campana y cuatro gónadas en herradura visibles a través del cuerpo.';

  @override
  String get species_lions_mane_jellyfish_name => 'Medusa melena de león';

  @override
  String get species_lions_mane_jellyfish_desc =>
      'Una de las medusas más grandes, con largos tentáculos que arrastra por las aguas frías.';

  @override
  String get species_box_jellyfish_name => 'Cubomedusa';

  @override
  String get species_box_jellyfish_desc =>
      'Medusa extremadamente peligrosa y de veneno potente, habita las aguas tropicales del Indopacífico.';

  @override
  String get species_upside_down_jellyfish_name => 'Medusa invertida';

  @override
  String get species_upside_down_jellyfish_desc =>
      'Medusa singular que reposa con la campana hacia abajo sobre fondos arenosos para que sus algas hagan la fotosíntesis.';

  @override
  String get species_blue_blubber_jellyfish_name => 'Medusa azul australiana';

  @override
  String get species_blue_blubber_jellyfish_desc =>
      'Medusa blanquiazul de campana firme y brazos orales rizados, común en aguas australianas.';

  @override
  String get species_fried_egg_jellyfish_name => 'Medusa huevo frito';

  @override
  String get species_fried_egg_jellyfish_desc =>
      'Medusa mediterránea con una cúpula amarilla que recuerda a un huevo frito y de picadura leve.';

  @override
  String get species_pacific_sea_nettle_name => 'Ortiga de mar del Pacífico';

  @override
  String get species_pacific_sea_nettle_desc =>
      'Medusa pardo dorada con largos tentáculos colgantes, presente a lo largo de la costa del Pacífico.';

  @override
  String get species_compass_jellyfish_name => 'Medusa brújula';

  @override
  String get species_compass_jellyfish_desc =>
      'Medusa parda y blanca con marcas en forma de V que irradian como una rosa de los vientos.';

  @override
  String get species_spotted_jellyfish_name => 'Medusa moteada';

  @override
  String get species_spotted_jellyfish_desc =>
      'Medusa dorada con motas blancas, famosa por llenar el lago de las medusas de Palaos.';

  @override
  String get species_barrel_jellyfish_name => 'Medusa barril';

  @override
  String get species_barrel_jellyfish_desc =>
      'Gran medusa con forma de cúpula, brazos orales rizados y picadura leve, común en el Atlántico.';

  @override
  String get species_persian_carpet_flatworm_name =>
      'Gusano plano alfombra persa';

  @override
  String get species_persian_carpet_flatworm_desc =>
      'Ornamentado gusano plano negro con los márgenes amarillo anaranjados, a menudo se confunde con un nudibranquio.';

  @override
  String get species_leopard_flatworm_name => 'Gusano plano leopardo';

  @override
  String get species_leopard_flatworm_desc =>
      'Gusano plano translúcido con manchas de leopardo que se desliza sobre el sustrato del arrecife.';

  @override
  String get species_divided_flatworm_name => 'Gusano plano dividido';

  @override
  String get species_divided_flatworm_desc =>
      'Llamativo gusano plano negro y naranja que imita a los nudibranquios tóxicos para protegerse.';

  @override
  String get species_blue_pseudoceros_flatworm_name =>
      'Gusano plano Pseudoceros azul';

  @override
  String get species_blue_pseudoceros_flatworm_desc =>
      'Gusano plano azul intenso con el margen anaranjado, se desliza sobre las superficies de los arrecifes del Indopacífico.';

  @override
  String get species_racing_stripe_flatworm_name =>
      'Gusano plano de raya central';

  @override
  String get species_racing_stripe_flatworm_desc =>
      'Gusano plano de color crema con una marcada raya central oscura y el margen rizado.';

  @override
  String get species_christmas_tree_worm_name => 'Gusano árbol de Navidad';

  @override
  String get species_christmas_tree_worm_desc =>
      'Colorido gusano de corona espiral incrustado en el coral que se retrae al instante cuando alguien se acerca.';

  @override
  String get species_feather_duster_worm_name => 'Gusano plumero';

  @override
  String get species_feather_duster_worm_desc =>
      'Gusano tubícola con una corona en abanico de radiolos plumosos con la que filtra el alimento.';

  @override
  String get species_fire_worm_name => 'Gusano de fuego barbudo';

  @override
  String get species_fire_worm_desc =>
      'Gusano de cerdas blancas urticantes que provocan una irritación dolorosa al contacto.';

  @override
  String get species_bobbit_worm_name => 'Gusano bobbit';

  @override
  String get species_bobbit_worm_desc =>
      'Depredador de emboscada que se oculta en la arena con unas mandíbulas potentes que atacan a la velocidad del rayo.';

  @override
  String get species_social_feather_duster_name => 'Gusano plumero social';

  @override
  String get species_social_feather_duster_desc =>
      'Gusano tubícola colonial que forma agrupaciones de delicadas coronas con bandas en los arrecifes del Caribe.';

  @override
  String get species_giant_clam_name => 'Almeja gigante';

  @override
  String get species_giant_clam_desc =>
      'El bivalvo vivo más grande, con un tejido del manto iridiscente que alberga algas simbióticas.';

  @override
  String get species_boring_clam_name => 'Almeja perforadora';

  @override
  String get species_boring_clam_desc =>
      'Pequeña almeja de colores vivos que perfora la roca coralina y solo deja a la vista su llamativo manto.';

  @override
  String get species_maxima_clam_name => 'Almeja maxima';

  @override
  String get species_maxima_clam_desc =>
      'Almeja de colores brillantes incrustada en la roca del arrecife, con mantos de un azul y un verde eléctricos.';

  @override
  String get species_flame_scallop_name => 'Vieira llama';

  @override
  String get species_flame_scallop_desc =>
      'Bivalvo rojo con destellos de luz blanca a lo largo del borde del manto, vive en las grietas del arrecife.';

  @override
  String get species_thorny_oyster_name => 'Ostra espinosa';

  @override
  String get species_thorny_oyster_desc =>
      'Bivalvo de concha espinosa cementado a la roca del arrecife, a menudo recubierto de esponjas y algas.';

  @override
  String get species_magnificent_sea_anemone_name => 'Anémona magnífica';

  @override
  String get species_magnificent_sea_anemone_desc =>
      'Gran anémona colorida que hospeda peces payaso, con una columna prominente y tentáculos ondulantes.';

  @override
  String get species_bubble_tip_anemone_name => 'Anémona de puntas burbuja';

  @override
  String get species_bubble_tip_anemone_desc =>
      'Anfitriona muy popular de los peces payaso, con tentáculos de punta bulbosa verdes, pardos o rosados.';

  @override
  String get species_giant_carpet_anemone_name => 'Anémona alfombra gigante';

  @override
  String get species_giant_carpet_anemone_desc =>
      'Enorme anémona de tentáculos cortos y pegajosos que puede superar el metro de diámetro.';

  @override
  String get species_haddon_carpet_anemone_name => 'Anémona alfombra de Haddon';

  @override
  String get species_haddon_carpet_anemone_desc =>
      'Anémona alfombra plana de sustratos arenosos que hospeda diversos peces payaso y cangrejos porcelana.';

  @override
  String get species_long_tentacle_anemone_name =>
      'Anémona de tentáculos largos';

  @override
  String get species_long_tentacle_anemone_desc =>
      'Anémona de fondos arenosos con largos tentáculos ondulantes, a menudo hospeda peces payaso.';

  @override
  String get species_tube_anemone_name => 'Anémona tubo';

  @override
  String get species_tube_anemone_desc =>
      'Elegante anémona que vive en un tubo apergaminado enterrado en la arena, con dos coronas de tentáculos.';

  @override
  String get species_hell_fire_anemone_name => 'Anémona fuego del infierno';

  @override
  String get species_hell_fire_anemone_desc =>
      'Anémona muy urticante con tentáculos ramificados que recuerdan a un coral blando.';

  @override
  String get species_beaded_sea_anemone_name => 'Anémona de cuentas';

  @override
  String get species_beaded_sea_anemone_desc =>
      'Anémona con las puntas de los tentáculos ensanchadas como cuentas, habita las zonas arenosas de los arrecifes del Indopacífico.';

  @override
  String get species_condylactis_anemone_name => 'Anémona gigante del Caribe';

  @override
  String get species_condylactis_anemone_desc =>
      'Gran anémona caribeña con los tentáculos de punta morada, vive sobre sustratos rocosos de arrecife.';

  @override
  String get species_sand_anemone_name => 'Anémona de arena';

  @override
  String get species_sand_anemone_desc =>
      'Delicada anémona parcialmente enterrada en la arena con los tentáculos de punta morada.';

  @override
  String get species_barrel_sponge_name => 'Esponja barril gigante';

  @override
  String get species_barrel_sponge_desc =>
      'Enorme esponja con forma de barril que puede vivir siglos en las paredes de los arrecifes del Caribe.';

  @override
  String get species_azure_vase_sponge_name => 'Esponja jarrón azul';

  @override
  String get species_azure_vase_sponge_desc =>
      'Vibrante esponja azul violácea con forma de jarrón, habita las paredes de los arrecifes del Caribe.';

  @override
  String get species_yellow_tube_sponge_name => 'Esponja tubo amarilla';

  @override
  String get species_yellow_tube_sponge_desc =>
      'Esponja tubular de amarillo brillante que crece en grupos en las paredes de los arrecifes del Caribe.';

  @override
  String get species_elephant_ear_sponge_name => 'Esponja oreja de elefante';

  @override
  String get species_elephant_ear_sponge_desc =>
      'Gran esponja naranja con forma de abanico que crece en paredes y voladizos del Caribe.';

  @override
  String get species_rope_sponge_name => 'Esponja cuerda';

  @override
  String get species_rope_sponge_desc =>
      'Esponja roja, erecta y ramificada que crece formando estructuras similares a cuerdas en los arrecifes del Caribe.';

  @override
  String get species_portuguese_man_o_war_name => 'Carabela portuguesa';

  @override
  String get species_portuguese_man_o_war_desc =>
      'Hidrozoo colonial con un flotador lleno de gas y tentáculos colgantes de picadura extremadamente dolorosa.';

  @override
  String get species_fire_coral_name => 'Coral de fuego';

  @override
  String get species_fire_coral_desc =>
      'No es un coral verdadero sino un hidrozoo que provoca picaduras dolorosas a los buceadores al contacto.';

  @override
  String get species_by_the_wind_sailor_name => 'Velero del viento';

  @override
  String get species_by_the_wind_sailor_desc =>
      'Colonia flotante de hidrozoos azules con una vela diagonal que aprovecha el viento.';

  @override
  String get species_blue_button_name => 'Botón azul';

  @override
  String get species_blue_button_desc =>
      'Hidrozoo colonial flotante con un disco plano e hidroides azules parecidos a tentáculos.';

  @override
  String get species_giant_sea_hare_name => 'Liebre de mar gigante';

  @override
  String get species_giant_sea_hare_desc =>
      'Una de las babosas marinas más grandes, de color pardo oscuro a negro, habita los bosques de kelp.';

  @override
  String get species_sea_hare_name => 'Liebre de mar moteada';

  @override
  String get species_sea_hare_desc =>
      'Gran liebre de mar con motas verdes que libera tinta morada cuando se la molesta.';

  @override
  String get species_nudibranch_berghia_name => 'Nudibranquio Berghia';

  @override
  String get species_nudibranch_berghia_desc =>
      'Nudibranquio eólido translúcido con ceratas de punta blanca que se alimenta de anémonas.';

  @override
  String get species_sea_pen_name => 'Pluma de mar';

  @override
  String get species_sea_pen_desc =>
      'Octocoral colonial con forma de pluma anclado en la arena que se retrae al ser molestado.';

  @override
  String get species_blue_sea_star_name => 'Estrella de mar de Linckia';

  @override
  String get species_blue_sea_star_desc =>
      'Estrella de mar multicolor que se regenera a partir de fragmentos de un solo brazo en los arrecifes del Indopacífico.';

  @override
  String get species_reef_squid_name => 'Calamar de arrecife';

  @override
  String get species_reef_squid_desc =>
      'Calamar de arrecife austral que se encuentra con frecuencia en las aguas templadas de Australia.';

  @override
  String get species_tiger_shrimp_name => 'Camarón tigre';

  @override
  String get species_tiger_shrimp_desc =>
      'Gran camarón con bandas que habita fondos arenosos y praderas marinas del Indopacífico.';

  @override
  String get species_candy_crab_name => 'Cangrejo caramelo';

  @override
  String get species_candy_crab_desc =>
      'Diminuto cangrejo de colores que iguala el tono de su coral blando anfitrión con proyecciones espinosas rosas o amarillas.';

  @override
  String get species_spider_crab_name => 'Cangrejo araña decorador';

  @override
  String get species_spider_crab_desc =>
      'Cangrejo de movimientos lentos cubierto de esponjas y algas adheridas para camuflarse.';

  @override
  String get species_anemone_shrimp_name => 'Camarón de la anémona magnífica';

  @override
  String get species_anemone_shrimp_desc =>
      'Camarón transparente con marcas blancas y moradas que vive entre los tentáculos de las anémonas.';

  @override
  String get species_snapping_shrimp_name => 'Camarón pistola';

  @override
  String get species_snapping_shrimp_desc =>
      'Pequeño camarón que produce un chasquido sonoro con su pinza desproporcionada, a menudo emparejado con gobios.';

  @override
  String get species_glass_sponge_name => 'Cesta de flores de Venus';

  @override
  String get species_glass_sponge_desc =>
      'Delicada esponja de vidrio con un intrincado esqueleto de sílice que habita aguas profundas.';

  @override
  String get species_toxic_sea_urchin_name => 'Erizo flor';

  @override
  String get species_toxic_sea_urchin_desc =>
      'Erizo engañosamente atractivo cubierto de pedicelarios en forma de flor con un veneno potente.';

  @override
  String get species_slate_pencil_urchin_name => 'Erizo lápiz de pizarra';

  @override
  String get species_slate_pencil_urchin_desc =>
      'Erizo de espinas gruesas y redondeadas que habita los sustratos de arrecife del Caribe y del Atlántico.';

  @override
  String get species_spiny_sea_star_name => 'Estrella de mar espinosa';

  @override
  String get species_spiny_sea_star_desc =>
      'Gran estrella de mar de aguas templadas con espinas prominentes, habita aguas europeas y atlánticas.';

  @override
  String get species_bat_star_name => 'Estrella murciélago';

  @override
  String get species_bat_star_desc =>
      'Estrella de mar del Pacífico con los brazos unidos por una membrana, de color naranja, rojo o morado, habita los bosques de kelp.';

  @override
  String get species_sunflower_star_name => 'Estrella girasol';

  @override
  String get species_sunflower_star_desc =>
      'Enorme estrella de mar de movimientos rápidos con hasta 24 brazos, habita los bosques de kelp del Pacífico.';

  @override
  String get species_blood_star_name => 'Estrella de sangre';

  @override
  String get species_blood_star_desc =>
      'Estrella de mar de un rojo anaranjado brillante y brazos esbeltos, habita las aguas templadas del Pacífico.';

  @override
  String get species_common_cuttlefish_name => 'Sepia común';

  @override
  String get species_common_cuttlefish_desc =>
      'Maestra del camuflaje de las aguas europeas y mediterráneas, con las pupilas en forma de W.';

  @override
  String get species_blue_spotted_crab_name =>
      'Cangrejo nadador de puntos azules';

  @override
  String get species_blue_spotted_crab_desc =>
      'Cangrejo nadador muy activo con puntos azules en el caparazón, habita los sustratos arenosos del Indopacífico.';

  @override
  String get species_sponge_crab_name => 'Cangrejo esponja';

  @override
  String get species_sponge_crab_desc =>
      'Cangrejo que recorta y transporta una esponja viva sobre el dorso para camuflarse.';

  @override
  String get species_horseshoe_crab_name => 'Cangrejo herradura';

  @override
  String get species_horseshoe_crab_desc =>
      'Antiguo artrópodo quelicerado con un caparazón en forma de casco, habita los fondos arenosos del Atlántico.';

  @override
  String get species_sea_spider_name => 'Araña de mar';

  @override
  String get species_sea_spider_desc =>
      'Delicado artrópodo marino de patas largas que repta sobre hidroides y briozoos.';

  @override
  String get species_sea_lily_name => 'Lirio de mar';

  @override
  String get species_sea_lily_desc =>
      'Crinoideo pedunculado y fósil viviente de aguas profundas que filtra el alimento con sus brazos plumosos.';

  @override
  String get species_mantis_shrimp_lysiosquilla_name =>
      'Camarón mantis arponero';

  @override
  String get species_mantis_shrimp_lysiosquilla_desc =>
      'Gran camarón mantis excavador con apéndices en forma de arpón, habita los sustratos arenosos.';

  @override
  String get species_purple_sea_urchin_name => 'Erizo de mar morado';

  @override
  String get species_purple_sea_urchin_desc =>
      'Erizo morado abundante en los bosques de kelp y las pozas rocosas de marea del Pacífico.';

  @override
  String get species_crown_jellyfish_name => 'Medusa corona';

  @override
  String get species_crown_jellyfish_desc =>
      'Medusa de un morado intenso con la campana coronada por un reborde elevado, habita el Indopacífico.';

  @override
  String get species_comb_jelly_name => 'Grosella de mar';

  @override
  String get species_comb_jelly_desc =>
      'Pequeño ctenóforo bioluminiscente con hileras de peines iridiscentes y dos largos tentáculos.';

  @override
  String get species_warty_sea_slug_name => 'Babosa marina verrugosa';

  @override
  String get species_warty_sea_slug_desc =>
      'Nudibranquio azul y negro con tubérculos de ápice amarillo, muy habitual en los arrecifes del Indopacífico.';

  @override
  String get species_doris_nudibranch_name => 'Limón de mar';

  @override
  String get species_doris_nudibranch_desc =>
      'Nudibranquio dórido amarillo y moteado de las aguas templadas del Pacífico, se alimenta de esponjas.';

  @override
  String get species_opalescent_nudibranch_name => 'Nudibranquio opalescente';

  @override
  String get species_opalescent_nudibranch_desc =>
      'Eólido translúcido con ceratas de un naranja brillante y líneas dorsales azules, habita las aguas del Pacífico.';

  @override
  String get species_clown_nudibranch_name => 'Nudibranquio payaso';

  @override
  String get species_clown_nudibranch_desc =>
      'Nudibranquio rosa anaranjado con puntos azules y blancos, habita las aguas templadas de Australia.';

  @override
  String get species_bottlenose_dolphin_name => 'Delfín mular';

  @override
  String get species_bottlenose_dolphin_desc =>
      'Delfín curioso y juguetón que los buceadores encuentran con frecuencia en aguas tropicales y templadas.';

  @override
  String get species_spinner_dolphin_name => 'Delfín girador';

  @override
  String get species_spinner_dolphin_desc =>
      'Delfín acrobático conocido por sus giros en el aire, se ve a menudo en grandes grupos cerca de los arrecifes de coral.';

  @override
  String get species_common_dolphin_name => 'Delfín común';

  @override
  String get species_common_dolphin_desc =>
      'Delfín de nado veloz con un característico patrón en forma de reloj de arena, habita el océano abierto y las aguas costeras.';

  @override
  String get species_spotted_dolphin_name => 'Delfín moteado del Atlántico';

  @override
  String get species_spotted_dolphin_desc =>
      'Delfín moteado y confiado que se acerca con frecuencia a los buceadores en las Bahamas y el Caribe.';

  @override
  String get species_rissos_dolphin_name => 'Delfín de Risso';

  @override
  String get species_rissos_dolphin_desc =>
      'Gran delfín de cuerpo gris muy marcado por cicatrices, habita aguas profundas alejadas de la costa en todo el mundo.';

  @override
  String get species_humpback_whale_name => 'Ballena jorobada';

  @override
  String get species_humpback_whale_desc =>
      'Majestuosa ballena conocida por sus saltos y sus cantos complejos, se observa durante las migraciones estacionales.';

  @override
  String get species_grey_whale_name => 'Ballena gris';

  @override
  String get species_grey_whale_desc =>
      'Ballena con barbas que se alimenta en el fondo y migra a lo largo de la costa del Pacífico, a menudo cubierta de percebes.';

  @override
  String get species_blue_whale_name => 'Ballena azul';

  @override
  String get species_blue_whale_desc =>
      'El animal más grande que ha existido jamás, los buceadores lo encuentran de vez en cuando en aguas azules profundas.';

  @override
  String get species_sperm_whale_name => 'Cachalote';

  @override
  String get species_sperm_whale_desc =>
      'Ballena de buceo profundo y cabeza enorme, a veces se la ve descansando en la superficie entre inmersiones.';

  @override
  String get species_orca_name => 'Orca';

  @override
  String get species_orca_desc =>
      'Depredador ápice con un característico patrón blanco y negro, presente en todos los océanos.';

  @override
  String get species_minke_whale_name => 'Rorcual aliblanco';

  @override
  String get species_minke_whale_desc =>
      'Ballena con barbas de menor tamaño que se muestra curiosa con los buceadores, sobre todo en la Gran Barrera de Coral.';

  @override
  String get species_beluga_whale_name => 'Beluga';

  @override
  String get species_beluga_whale_desc =>
      'Ballena blanca del Ártico conocida por sus vocalizaciones y su comportamiento sociable en aguas frías.';

  @override
  String get species_pilot_whale_name => 'Calderón tropical';

  @override
  String get species_pilot_whale_desc =>
      'Ballena sociable y de buceo profundo, se ve a menudo en grandes grupos en mares tropicales y templados cálidos.';

  @override
  String get species_false_killer_whale_name => 'Falsa orca';

  @override
  String get species_false_killer_whale_desc =>
      'Gran delfín oceánico que de vez en cuando se acerca a los buceadores en mar abierto.';

  @override
  String get species_dugong_name => 'Dugongo';

  @override
  String get species_dugong_desc =>
      'Herbívoro apacible que pasta en las praderas marinas del Indopacífico, pariente cercano de los manatíes.';

  @override
  String get species_west_indian_manatee_name => 'Manatí del Caribe';

  @override
  String get species_west_indian_manatee_desc =>
      'Herbívoro de movimientos lentos que habita aguas cálidas y someras, estuarios y manantiales del Caribe.';

  @override
  String get species_sea_otter_name => 'Nutria marina';

  @override
  String get species_sea_otter_desc =>
      'Carismático mamífero marino de los bosques de kelp de la costa del Pacífico Norte.';

  @override
  String get species_california_sea_lion_name => 'León marino de California';

  @override
  String get species_california_sea_lion_desc =>
      'Pinnípedo juguetón y ágil que suele interactuar con los buceadores a lo largo de la costa del Pacífico.';

  @override
  String get species_steller_sea_lion_name => 'León marino de Steller';

  @override
  String get species_steller_sea_lion_desc =>
      'La especie de león marino más grande, habita las frías aguas del Pacífico Norte cerca de costas rocosas.';

  @override
  String get species_harbor_seal_name => 'Foca común';

  @override
  String get species_harbor_seal_desc =>
      'Foca curiosa que se ve con frecuencia en aguas costeras templadas, a menudo descansando sobre las rocas cerca de los puntos de buceo.';

  @override
  String get species_grey_seal_name => 'Foca gris';

  @override
  String get species_grey_seal_desc =>
      'Gran foca juguetona del Atlántico Norte, conocida por acercarse a los buceadores bajo el agua.';

  @override
  String get species_northern_elephant_seal_name => 'Elefante marino del norte';

  @override
  String get species_northern_elephant_seal_desc =>
      'Enorme foca de buceo profundo; los machos tienen una gran probóscide. Habita la costa oriental del Pacífico.';

  @override
  String get species_hawaiian_monk_seal_name => 'Foca monje de Hawái';

  @override
  String get species_hawaiian_monk_seal_desc =>
      'Foca en peligro crítico endémica de Hawái, los buceadores la ven de vez en cuando en los arrecifes.';

  @override
  String get species_leopard_seal_name => 'Foca leopardo';

  @override
  String get species_leopard_seal_desc =>
      'Poderoso depredador antártico de pelaje moteado, se encuentra en las inmersiones en aguas frías.';

  @override
  String get species_narwhal_name => 'Narval';

  @override
  String get species_narwhal_desc =>
      'Ballena ártica con un largo colmillo en espiral, rara vez se ve pero es icónica entre los mamíferos marinos.';

  @override
  String get species_green_sea_turtle_name => 'Tortuga verde';

  @override
  String get species_green_sea_turtle_desc =>
      'Gran tortuga marina que se ve con frecuencia pastando praderas marinas en aguas tropicales.';

  @override
  String get species_hawksbill_sea_turtle_name => 'Tortuga carey';

  @override
  String get species_hawksbill_sea_turtle_desc =>
      'Tortuga de arrecife con un pico puntiagudo, se alimenta de esponjas entre las formaciones de coral.';

  @override
  String get species_loggerhead_sea_turtle_name => 'Tortuga boba';

  @override
  String get species_loggerhead_sea_turtle_desc =>
      'Tortuga de cabeza grande que habita mares templados y tropicales, a menudo cerca de arrecifes rocosos.';

  @override
  String get species_leatherback_sea_turtle_name => 'Tortuga laúd';

  @override
  String get species_leatherback_sea_turtle_desc =>
      'La tortuga viva más grande, con un caparazón flexible y coriáceo, se sumerge a profundidades extremas.';

  @override
  String get species_olive_ridley_sea_turtle_name => 'Tortuga golfina';

  @override
  String get species_olive_ridley_sea_turtle_desc =>
      'La tortuga marina más pequeña, conocida por sus anidaciones masivas sincronizadas llamadas arribadas.';

  @override
  String get species_kemps_ridley_sea_turtle_name => 'Tortuga lora';

  @override
  String get species_kemps_ridley_sea_turtle_desc =>
      'Tortuga marina en peligro crítico que habita sobre todo el golfo de México.';

  @override
  String get species_flatback_sea_turtle_name => 'Tortuga aplanada';

  @override
  String get species_flatback_sea_turtle_desc =>
      'Endémica de las aguas australianas, se distingue por su caparazón plano y su hábitat costero.';

  @override
  String get species_brain_coral_name => 'Coral cerebro';

  @override
  String get species_brain_coral_desc =>
      'Coral masivo constructor de arrecifes con la superficie surcada como un cerebro, común en los arrecifes del Caribe.';

  @override
  String get species_staghorn_coral_name => 'Coral cuerno de ciervo';

  @override
  String get species_staghorn_coral_desc =>
      'Coral ramificado de crecimiento rápido que forma matorrales densos, un hábitat esencial para los peces de arrecife.';

  @override
  String get species_elkhorn_coral_name => 'Coral cuerno de alce';

  @override
  String get species_elkhorn_coral_desc =>
      'Gran coral ramificado con ramas palmeadas y planas, un constructor clave de los arrecifes del Caribe.';

  @override
  String get species_table_coral_name => 'Coral mesa';

  @override
  String get species_table_coral_desc =>
      'Coral que forma placas planas en los arrecifes del Indopacífico y ofrece refugio a numerosas especies de peces.';

  @override
  String get species_mushroom_coral_name => 'Coral hongo';

  @override
  String get species_mushroom_coral_desc =>
      'Coral solitario de vida libre con forma de disco, habita las zonas arenosas cercanas a los arrecifes del Indopacífico.';

  @override
  String get species_bubble_coral_name => 'Coral burbuja';

  @override
  String get species_bubble_coral_desc =>
      'Coral característico con vesículas parecidas a uvas que se inflan durante el día para captar la luz.';

  @override
  String get species_plate_coral_name => 'Coral placa';

  @override
  String get species_plate_coral_desc =>
      'Coral de láminas finas que forma repisas en espiral, común en los taludes de arrecife del Indopacífico.';

  @override
  String get species_pillar_coral_name => 'Coral pilar';

  @override
  String get species_pillar_coral_desc =>
      'Coral poco frecuente de crecimiento vertical que forma columnas altas, habita el Caribe.';

  @override
  String get species_star_coral_name => 'Coral estrella';

  @override
  String get species_star_coral_desc =>
      'Gran constructor de los arrecifes del Caribe, forma colonias masivas con pólipos en forma de estrella.';

  @override
  String get species_lettuce_coral_name => 'Coral lechuga';

  @override
  String get species_lettuce_coral_desc =>
      'Coral de láminas finas con pliegues en forma de hoja, común en las paredes y los taludes de los arrecifes del Caribe.';

  @override
  String get species_finger_coral_name => 'Coral dedo';

  @override
  String get species_finger_coral_desc =>
      'Coral ramificado y robusto con gruesas proyecciones en forma de dedo, habita los arrecifes someros.';

  @override
  String get species_massive_porites_name => 'Coral Porites masivo';

  @override
  String get species_massive_porites_desc =>
      'Gran coral masivo que puede crecer durante siglos, un constructor dominante de los arrecifes del Indopacífico.';

  @override
  String get species_cauliflower_coral_name => 'Coral coliflor';

  @override
  String get species_cauliflower_coral_desc =>
      'Coral ramificado y compacto con forma de coliflor, extendido por las zonas someras de los arrecifes tropicales.';

  @override
  String get species_flower_pot_coral_name => 'Coral maceta';

  @override
  String get species_flower_pot_coral_desc =>
      'Colonia de pólipos de tentáculos largos que se extienden durante el día y recuerdan a un ramo de flores.';

  @override
  String get species_cup_coral_name => 'Coral copa naranja';

  @override
  String get species_cup_coral_desc =>
      'Coral no fotosintético de un naranja brillante que habita paredes y voladizos de aguas tropicales.';

  @override
  String get species_scroll_coral_name => 'Coral pergamino';

  @override
  String get species_scroll_coral_desc =>
      'Coral que forma grandes placas enrolladas, común en los taludes y las lagunas de los arrecifes del Indopacífico.';

  @override
  String get species_cabbage_coral_name => 'Coral col';

  @override
  String get species_cabbage_coral_desc =>
      'Coral laminar con forma de disco que recuerda a las hojas de una col, habita zonas resguardadas del arrecife.';

  @override
  String get species_hammer_coral_name => 'Coral martillo';

  @override
  String get species_hammer_coral_desc =>
      'Coral de pólipos grandes con las puntas de los tentáculos en forma de ancla o martillo, muy presente en los arrecifes del Indopacífico.';

  @override
  String get species_torch_coral_name => 'Coral antorcha';

  @override
  String get species_torch_coral_desc =>
      'Coral ramificado con largos tentáculos ondulantes rematados por bulbos luminosos.';

  @override
  String get species_frogspawn_coral_name => 'Coral huevas de rana';

  @override
  String get species_frogspawn_coral_desc =>
      'Coral de pólipos grandes con las puntas de los tentáculos ramificadas, parecidas a huevos de rana.';

  @override
  String get species_sea_fan_name => 'Abanico de mar común';

  @override
  String get species_sea_fan_desc =>
      'Gorgonia plana en forma de abanico orientada perpendicular a la corriente, icónica en los arrecifes del Caribe.';

  @override
  String get species_venus_sea_fan_name => 'Abanico de mar de Venus';

  @override
  String get species_venus_sea_fan_desc =>
      'Delicada gorgonia en forma de abanico que habita los arrecifes someros del Caribe en zonas de corriente moderada.';

  @override
  String get species_deepwater_sea_fan_name =>
      'Abanico de mar de aguas profundas';

  @override
  String get species_deepwater_sea_fan_desc =>
      'Gran gorgonia arbustiva que habita las paredes profundas de los arrecifes del Caribe.';

  @override
  String get species_sea_whip_name => 'Látigo de mar';

  @override
  String get species_sea_whip_desc =>
      'Gorgonia esbelta con forma de vara que se mece con la corriente en los arrecifes del Atlántico y del Caribe.';

  @override
  String get species_sea_plume_name => 'Penacho de mar';

  @override
  String get species_sea_plume_desc =>
      'Gorgonia alta y plumosa que forma colonias en forma de penacho en las partes altas de los arrecifes del Caribe.';

  @override
  String get species_organ_pipe_coral_name => 'Coral tubo de órgano';

  @override
  String get species_organ_pipe_coral_desc =>
      'Tubos esqueléticos de un rojo brillante con pólipos delicados, habita arrecifes resguardados del Indopacífico.';

  @override
  String get species_leather_coral_name => 'Coral cuero';

  @override
  String get species_leather_coral_desc =>
      'Coral blando de superficie lisa y coriácea que forma grandes colonias con forma de seta.';

  @override
  String get species_toadstool_leather_coral_name => 'Coral cuero seta';

  @override
  String get species_toadstool_leather_coral_desc =>
      'Coral blando con un pie grueso y un sombrero plano, común en las planicies de arrecife del Indopacífico.';

  @override
  String get species_pulsing_xenia_name => 'Xenia pulsante';

  @override
  String get species_pulsing_xenia_desc =>
      'Coral blando con pólipos que laten rítmicamente, habita aguas resguardadas del Indopacífico.';

  @override
  String get species_tree_coral_name => 'Coral árbol';

  @override
  String get species_tree_coral_desc =>
      'Vibrante coral blando que forma agrupaciones arborescentes en paredes y voladizos del mar Rojo.';

  @override
  String get species_blue_coral_name => 'Coral azul';

  @override
  String get species_blue_coral_desc =>
      'Octocoral singular con esqueleto azul, habita las planicies someras de los arrecifes del Indopacífico.';

  @override
  String get species_black_coral_name => 'Coral negro';

  @override
  String get species_black_coral_desc =>
      'Coral de aguas profundas con esqueleto oscuro, habita paredes y desniveles por debajo de los 30 metros.';

  @override
  String get species_carnation_coral_name => 'Coral clavel';

  @override
  String get species_carnation_coral_desc =>
      'Coral blando de colores vivos que habita bajo los salientes y en las paredes del Indopacífico.';

  @override
  String get species_wire_coral_name => 'Coral alambre';

  @override
  String get species_wire_coral_desc =>
      'Coral negro alargado y espiral que forma látigos enrollados, alberga gobios y camarones.';

  @override
  String get species_dead_mans_fingers_name => 'Dedos de hombre muerto';

  @override
  String get species_dead_mans_fingers_desc =>
      'Coral blando y carnoso con lóbulos en forma de dedo, común en los arrecifes templados del Atlántico Norte.';

  @override
  String get species_sun_coral_name => 'Coral sol';

  @override
  String get species_sun_coral_desc =>
      'Coral no fotosintético de color amarillo anaranjado que abre sus pólipos de noche en las paredes del Indopacífico.';

  @override
  String get species_lace_coral_name => 'Coral encaje';

  @override
  String get species_lace_coral_desc =>
      'Delicado hidrocoral rosado con ramas como de encaje, habita grietas y zonas bajo los salientes.';

  @override
  String get species_kenya_tree_coral_name => 'Coral árbol de Kenia';

  @override
  String get species_kenya_tree_coral_desc =>
      'Coral blando resistente de ramas arborescentes, común en el Indopacífico.';

  @override
  String get species_colt_coral_name => 'Coral potro';

  @override
  String get species_colt_coral_desc =>
      'Coral blando de ramas gruesas y gomosas cubiertas de pequeños pólipos en los arrecifes del Indopacífico.';

  @override
  String get species_turtle_grass_name => 'Hierba de tortuga';

  @override
  String get species_turtle_grass_desc =>
      'Fanerógama marina dominante del Caribe, de hojas anchas y planas y alimento vital para las tortugas marinas.';

  @override
  String get species_eelgrass_name => 'Zostera';

  @override
  String get species_eelgrass_desc =>
      'Fanerógama marina de aguas templadas que forma densas praderas submarinas usadas como criadero.';

  @override
  String get species_manatee_grass_name => 'Hierba de manatí';

  @override
  String get species_manatee_grass_desc =>
      'Fanerógama marina de hojas cilíndricas que habita las zonas arenosas del Caribe, a menudo cerca de las praderas de hierba de tortuga.';

  @override
  String get species_shoal_grass_name => 'Hierba de bajío';

  @override
  String get species_shoal_grass_desc =>
      'Fanerógama pionera de hojas estrechas que coloniza las zonas arenosas alteradas del Caribe.';

  @override
  String get species_paddle_grass_name => 'Hierba pala';

  @override
  String get species_paddle_grass_desc =>
      'Pequeña y delicada fanerógama marina de hojas ovaladas, habita las aguas más profundas de los trópicos.';

  @override
  String get species_neptune_grass_name => 'Posidonia';

  @override
  String get species_neptune_grass_desc =>
      'Fanerógama mediterránea que forma vastas praderas esenciales para los ecosistemas marinos costeros.';

  @override
  String get species_giant_kelp_name => 'Kelp gigante';

  @override
  String get species_giant_kelp_desc =>
      'Especie que forma imponentes bosques submarinos de hasta 60 metros, icónica del buceo en California.';

  @override
  String get species_bull_kelp_name => 'Kelp toro';

  @override
  String get species_bull_kelp_desc =>
      'Kelp del Pacífico con un solo estipe largo y un flotador bulboso, forma densos bosques con dosel.';

  @override
  String get species_bladder_wrack_name => 'Sargazo vejigoso';

  @override
  String get species_bladder_wrack_desc =>
      'Alga parda común con vejigas de aire pareadas, habita las zonas intermareales del Atlántico Norte.';

  @override
  String get species_sargassum_name => 'Sargazo';

  @override
  String get species_sargassum_desc =>
      'Alga parda de vida flotante que forma balsas donde se refugian peces juveniles e invertebrados.';

  @override
  String get species_kelp_forest_ecklonia_name => 'Kelp Ecklonia';

  @override
  String get species_kelp_forest_ecklonia_desc =>
      'Kelp dominante en las aguas del hemisferio sur, forma importantes bosques submarinos.';

  @override
  String get species_coralline_algae_name => 'Algas coralinas';

  @override
  String get species_coralline_algae_desc =>
      'Alga roja incrustante y dura que cementa las estructuras del arrecife y le da un tono rosado.';

  @override
  String get species_irish_moss_name => 'Musgo de Irlanda';

  @override
  String get species_irish_moss_desc =>
      'Alga roja con forma de abanico que habita las costas rocosas de la zona intermareal del Atlántico Norte.';

  @override
  String get species_dulse_name => 'Dulse';

  @override
  String get species_dulse_desc =>
      'Alga plana de color rojo violáceo que crece sobre rocas y estipes de kelp en las frías aguas del norte.';

  @override
  String get species_halimeda_name => 'Halimeda';

  @override
  String get species_halimeda_desc =>
      'Alga verde calcificada con segmentos en forma de disco, gran contribuyente a la arena del arrecife.';

  @override
  String get species_sea_lettuce_name => 'Lechuga de mar';

  @override
  String get species_sea_lettuce_desc =>
      'Alga verde brillante con forma de lámina que habita aguas costeras someras de todo el mundo.';

  @override
  String get species_caulerpa_name => 'Alga uva verde';

  @override
  String get species_caulerpa_desc =>
      'Alga verde rastrera con frondas parecidas a uvas, habita el cascajo y la arena de los arrecifes tropicales.';

  @override
  String get species_mermaid_fan_name => 'Abanico de sirena';

  @override
  String get species_mermaid_fan_desc =>
      'Alga verde calcificada con forma de pequeño abanico, común en los fondos arenosos del Caribe.';

  @override
  String get species_shaving_brush_algae_name => 'Alga brocha de afeitar';

  @override
  String get species_shaving_brush_algae_desc =>
      'Alga verde calcificada con un mechón en forma de brocha sobre un pie, habita los fondos arenosos del Caribe.';

  @override
  String get species_finger_kelp_name => 'Laminaria';

  @override
  String get species_finger_kelp_desc =>
      'Alga parda con frondas en forma de dedos que forma praderas de kelp en las aguas costeras del Atlántico Norte.';

  @override
  String get species_banded_sea_krait_name => 'Serpiente marina de bandas';

  @override
  String get species_banded_sea_krait_desc =>
      'Serpiente marina venenosa con bandas gris azuladas y negras, dócil y muy habitual en los arrecifes del Indopacífico.';

  @override
  String get species_olive_sea_snake_name => 'Serpiente marina oliva';

  @override
  String get species_olive_sea_snake_desc =>
      'Serpiente marina curiosa de los arrecifes australianos, conocida por acercarse a los buceadores.';

  @override
  String get species_yellow_bellied_sea_snake_name =>
      'Serpiente marina de vientre amarillo';

  @override
  String get species_yellow_bellied_sea_snake_desc =>
      'Serpiente marina pelágica con el vientre amarillo, la especie de serpiente más extendida de la Tierra.';

  @override
  String get species_marine_iguana_name => 'Iguana marina';

  @override
  String get species_marine_iguana_desc =>
      'Endémica de las Galápagos, el único lagarto que se alimenta de algas bajo el agua.';

  @override
  String get species_saltwater_crocodile_name => 'Cocodrilo marino';

  @override
  String get species_saltwater_crocodile_desc =>
      'El reptil vivo más grande, habita las aguas costeras y estuarinas del Indopacífico.';

  @override
  String get common_action_done => 'Listo';

  @override
  String get common_action_more => 'Más';

  @override
  String get common_label_displayName => 'Nombre visible';

  @override
  String common_relativeTime_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace ${count}d',
      one: 'hace ${count}d',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace ${count}h',
      one: 'hace ${count}h',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'en ${count}d',
      one: 'en ${count}d',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'en ${count}h',
      one: 'en ${count}h',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_inLessThanMinute => 'en <1m';

  @override
  String common_relativeTime_inMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'en ${count}m',
      one: 'en ${count}m',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_justNow => 'ahora mismo';

  @override
  String common_relativeTime_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace ${count}m',
      one: 'hace ${count}m',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace ${count}mes',
      one: 'hace ${count}mes',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_overdue => 'vencido';

  @override
  String get media_cache_calculating => 'Calculando el tamaño de la caché…';

  @override
  String get media_cache_cardTitle => 'Gestión de la caché';

  @override
  String get media_cache_clearAction => 'Borrar caché';

  @override
  String get media_cache_clearBody =>
      'Elimina las miniaturas y las imágenes de red a tamaño completo descargadas. Los medios vinculados se conservan; las imágenes se volverán a descargar la próxima vez que se vean.';

  @override
  String get media_cache_clearConfirm => 'Borrar';

  @override
  String media_cache_clearError(String error) {
    return 'Error al borrar: $error';
  }

  @override
  String get media_cache_clearTitle => '¿Borrar la caché de imágenes de red?';

  @override
  String get media_cache_cleared => 'Caché borrada';

  @override
  String get media_cache_diskCache => 'Caché en disco';

  @override
  String media_cache_error(String error) {
    return 'Error: $error';
  }

  @override
  String get media_credentials_actionTest => 'Probar credenciales';

  @override
  String media_credentials_authLabel(String authType) {
    return 'Auth: $authType';
  }

  @override
  String get media_credentials_deleteBody =>
      'Elimina las credenciales guardadas. Los elementos vinculados a través de este host mostrarán «Inicia sesión para ver» hasta que los vuelvas a añadir.';

  @override
  String media_credentials_deleteError(String error) {
    return 'Error al eliminar: $error';
  }

  @override
  String media_credentials_deleteTitle(String host) {
    return '¿Eliminar $host?';
  }

  @override
  String media_credentials_deleted(String host) {
    return '$host eliminado';
  }

  @override
  String media_credentials_editTitle(String host) {
    return 'Editar $host';
  }

  @override
  String get media_credentials_emptySubtitle =>
      'Aquí aparecen las credenciales por host añadidas durante las importaciones de URL o de manifiesto.';

  @override
  String get media_credentials_emptyTitle => 'No hay credenciales guardadas';

  @override
  String media_credentials_lastUsed(String when) {
    return 'Último uso $when';
  }

  @override
  String get media_credentials_loadError =>
      'No se pudieron cargar los hosts guardados';

  @override
  String get media_credentials_loading => 'Cargando hosts guardados...';

  @override
  String media_credentials_saveError(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get media_credentials_savedHostsTitle => 'Hosts guardados';

  @override
  String media_credentials_testError(String error) {
    return 'Error en la prueba: $error';
  }

  @override
  String media_credentials_testFailed(String host) {
    return 'Las credenciales fallaron para $host';
  }

  @override
  String media_credentials_testOk(String host) {
    return 'Credenciales correctas para $host';
  }

  @override
  String get media_manifest_actionPollNow => 'Consultar ahora';

  @override
  String get media_manifest_cardTitle => 'Suscripciones a manifiestos';

  @override
  String get media_manifest_deleteBody =>
      'Elimina la suscripción. Las entradas ya importadas se conservan (puedes limpiarlas desde la cola de huérfanos).';

  @override
  String media_manifest_deleteError(String error) {
    return 'Error al eliminar: $error';
  }

  @override
  String media_manifest_deleteTitle(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String get media_manifest_editTitle => 'Editar suscripción';

  @override
  String get media_manifest_emptySubtitle =>
      'Suscríbete a un manifiesto Atom/RSS, JSON o CSV desde la pestaña URL para mantener tu fototeca sincronizada.';

  @override
  String get media_manifest_emptyTitle => 'No hay suscripciones a manifiestos';

  @override
  String media_manifest_lastError(String error) {
    return 'Último error: $error';
  }

  @override
  String media_manifest_lastPolled(String when) {
    return 'Última consulta $when';
  }

  @override
  String get media_manifest_loadError =>
      'No se pudieron cargar las suscripciones';

  @override
  String get media_manifest_loading => 'Cargando suscripciones...';

  @override
  String get media_manifest_neverPolled => 'Nunca consultada';

  @override
  String media_manifest_nextPoll(String when) {
    return 'Siguiente $when';
  }

  @override
  String get media_manifest_notFound => 'Suscripción no encontrada';

  @override
  String media_manifest_pollError(String error) {
    return 'Error en la consulta: $error';
  }

  @override
  String media_manifest_polled(String name) {
    return '$name consultada';
  }

  @override
  String media_manifest_polling(String name) {
    return 'Consultando $name...';
  }

  @override
  String media_manifest_saveError(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String media_manifest_updateError(String error) {
    return 'No se pudo actualizar: $error';
  }

  @override
  String get media_manifest_urlLabel => 'URL del manifiesto';

  @override
  String media_scan_failed(String error) {
    return 'Error al analizar: $error';
  }

  @override
  String media_scan_progressItems(int done, int total) {
    return '$done / $total elementos';
  }

  @override
  String media_scan_progressReachability(int available, int unreachable) {
    return '$available accesibles  ·  $unreachable inaccesibles';
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
          'Se analizaron $total elementos en ${seconds}s: $available accesibles, $unreachable inaccesibles',
      one:
          'Se analizó $total elemento en ${seconds}s: $available accesible, $unreachable inaccesible',
    );
    return '$_temp0';
  }

  @override
  String media_scan_summarySkipped(String base, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count omitidos (sin URL)',
      one: '$count omitido (sin URL)',
    );
    return '$base, $_temp0';
  }

  @override
  String get media_scan_title => 'Analizar todos los medios de red';

  @override
  String get settings_mediaSources_androidUriTitle =>
      'Permisos de URI de Android';

  @override
  String settings_mediaSources_androidUriUsage(int used, int limit) {
    return '$used / $limit URI persistentes en uso';
  }

  @override
  String get settings_mediaSources_counting => 'Contando…';

  @override
  String settings_mediaSources_error(String error) {
    return 'Error: $error';
  }

  @override
  String get settings_mediaSources_loading => 'Cargando…';

  @override
  String settings_mediaSources_localFilesCounts(
    int available,
    int unavailable,
  ) {
    return '$available disponibles, $unavailable no disponibles';
  }

  @override
  String get settings_mediaSources_photoLibrarySubtitle =>
      'Apple Photos / Google Photos / iCloud';

  @override
  String get settings_mediaSources_reverifyAll =>
      'Volver a verificar todos los archivos locales';

  @override
  String settings_mediaSources_reverifyFailed(String error) {
    return 'Error al volver a verificar: $error';
  }

  @override
  String settings_mediaSources_reverifyResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos actualizados',
      one: '$count elemento actualizado',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_checkAll => 'Comprobar todos los archivos';

  @override
  String settings_mediaSources_checkAllResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos actualizados',
      one: '$count elemento actualizado',
    );
    return '$_temp0';
  }

  @override
  String settings_mediaSources_checkAllBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'No se pudo comprobar ninguno de los $count elementos. Sus orígenes no están accesibles ahora mismo.',
      one:
          'No se pudo comprobar el elemento. Su origen no está accesible ahora mismo.',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_title => 'Fuentes de medios';

  @override
  String get settings_networkSources_scanDescription =>
      'Vuelve a comprobar con su host cada foto importada por URL o por manifiesto. Marca los elementos inaccesibles para que aparezcan como «faltantes» en tu fototeca y puedan limpiarse.';

  @override
  String statistics_conditions_entryMethod_semanticLabel(String description) {
    return 'Gráfico de barras. Métodos de entrada. $description';
  }

  @override
  String statistics_conditions_visibility_semanticLabel(String description) {
    return 'Gráfico circular. Distribución de visibilidad. $description';
  }

  @override
  String statistics_conditions_waterType_semanticLabel(String description) {
    return 'Gráfico circular. Distribución de tipos de agua. $description';
  }

  @override
  String statistics_progression_divesBySuitThickness_semanticLabel(
    String description,
  ) {
    return 'Gráfico de barras. Inmersiones por grosor del traje. $description';
  }

  @override
  String statistics_progression_divesPerYear_countInYear(
    int count,
    String year,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones en $year',
      one: '1 inmersión en $year',
    );
    return '$_temp0';
  }

  @override
  String statistics_progression_divesPerYear_semanticLabel(String description) {
    return 'Gráfico de barras. Inmersiones por año. $description';
  }

  @override
  String get statistics_records_unavailable => 'Récords no disponibles';

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
  String get statistics_summary_distributions_title => 'Distribuciones';

  @override
  String get statistics_summary_diveTypes_error =>
      'No se pueden cargar los datos de tipos de inmersión';

  @override
  String get statistics_summary_diveTypes_unknown => 'Desconocido';

  @override
  String get statistics_summary_divesPerMonth => 'Inmersiones / mes';

  @override
  String get statistics_summary_divesPerYear => 'Inmersiones / año';

  @override
  String statistics_timePatterns_dayOfWeek_semanticLabel(String description) {
    return 'Gráfico de barras. Inmersiones por día de la semana. $description';
  }

  @override
  String statistics_timePatterns_seasonal_semanticLabel(String description) {
    return 'Gráfico de barras. Inmersiones por mes. $description';
  }

  @override
  String statistics_timePatterns_surfaceInterval_statLabel(
    String label,
    String value,
  ) {
    return 'Intervalo de superficie $label: $value';
  }

  @override
  String get statistics_timePatterns_timeOfDay_afternoon => 'Tarde';

  @override
  String get statistics_timePatterns_timeOfDay_evening => 'Anochecer';

  @override
  String get statistics_timePatterns_timeOfDay_morning => 'Mañana';

  @override
  String get statistics_timePatterns_timeOfDay_night => 'Noche';

  @override
  String statistics_timePatterns_timeOfDay_semanticLabel(String description) {
    return 'Gráfico circular. Inmersiones por franja horaria. $description';
  }

  @override
  String get columnConfig_displayOptions => 'Opciones de visualización';

  @override
  String get columnConfig_noExtraFields =>
      'No hay campos adicionales configurados. Agrega campos abajo.';

  @override
  String get columnConfig_savePresetTitle => 'Guardar preajuste';

  @override
  String get columnConfig_section => 'Sección';

  @override
  String get columnConfig_showTags => 'Mostrar etiquetas';

  @override
  String get columnConfig_showTags_subtitle =>
      'Mostrar chips de etiquetas en las tarjetas de inmersión detalladas';

  @override
  String get columnConfig_slot_date => 'Fecha / Subtítulo';

  @override
  String get columnConfig_slot_slot1 => 'Posición 1';

  @override
  String get columnConfig_slot_slot2 => 'Posición 2';

  @override
  String get columnConfig_slot_slot3 => 'Posición 3';

  @override
  String get columnConfig_slot_slot4 => 'Posición 4';

  @override
  String get columnConfig_slot_stat1 => 'Estadística 1';

  @override
  String get columnConfig_slot_stat2 => 'Estadística 2';

  @override
  String get columnConfig_slot_subtitle => 'Subtítulo';

  @override
  String get columnConfig_slot_title => 'Título';

  @override
  String get columnConfig_tooltip_columnSettings => 'Ajustes de columnas';

  @override
  String get common_action_add => 'Agregar';

  @override
  String get common_action_pin => 'Anclar';

  @override
  String get common_action_remove => 'Quitar';

  @override
  String get common_action_unpin => 'Desanclar';

  @override
  String diveLog_filterChip_dateRange(String end, String start) {
    return '$start - $end';
  }

  @override
  String diveLog_filterChip_equipmentCount(int count) {
    return '$count equipos';
  }

  @override
  String get diveLog_filter_allComputers => 'Todos los ordenadores';

  @override
  String get diveLog_filter_noComputersRegistered =>
      'No hay ordenadores de buceo registrados';

  @override
  String diveLog_filter_sectionDepthRangeUnit(String unit) {
    return 'Rango de profundidad ($unit)';
  }

  @override
  String get diveLog_filter_sectionDiveComputer => 'Ordenador de buceo';

  @override
  String diveLog_listPage_semanticsDiveAtSite(int diveNumber, String siteName) {
    return 'Inmersión $diveNumber en $siteName';
  }

  @override
  String get enum_listViewMode_compact => 'Compacta';

  @override
  String get enum_listViewMode_dense => 'Densa';

  @override
  String get enum_listViewMode_detailed => 'Detallada';

  @override
  String get enum_listViewMode_table => 'Tabla';

  @override
  String get enum_profileMetric_ascentRate => 'Velocidad de ascenso';

  @override
  String get enum_profileMetric_cns => 'CNS%';

  @override
  String get enum_profileMetric_otu => 'OTU';

  @override
  String get enum_sortField_bottomTime => 'Tiempo de fondo';

  @override
  String get enum_sortField_serviceDue => 'Servicio pendiente';

  @override
  String get listViewMode_tooltip => 'Modo de vista';

  @override
  String marineLife_speciesManage_errorLoading(Object error) {
    return 'Error al cargar las especies: $error';
  }

  @override
  String get settings_appearance_header_cards => 'Tarjetas';

  @override
  String get settings_appearance_header_listView => 'Vista de lista';

  @override
  String get settings_appearance_header_tableMode => 'Modo tabla';

  @override
  String get settings_appearance_listFields_buddies =>
      'Campos de la lista de compañeros';

  @override
  String get settings_appearance_listFields_certifications =>
      'Campos de la lista de certificaciones';

  @override
  String get settings_appearance_listFields_courses =>
      'Campos de la lista de cursos';

  @override
  String get settings_appearance_listFields_diveCenters =>
      'Campos de la lista de centros de buceo';

  @override
  String get settings_appearance_listFields_dives =>
      'Campos de la lista de inmersiones';

  @override
  String get settings_appearance_listFields_equipment =>
      'Campos de la lista de equipo';

  @override
  String get settings_appearance_listFields_sites =>
      'Campos de la lista de puntos de buceo';

  @override
  String get settings_appearance_listFields_subtitle =>
      'Personaliza los campos que se muestran en las vistas de lista';

  @override
  String get settings_appearance_listFields_trips =>
      'Campos de la lista de viajes';

  @override
  String get settings_appearance_listView_buddies =>
      'Vista de lista de compañeros';

  @override
  String get settings_appearance_listView_buddies_subtitle =>
      'Diseño predeterminado de la lista de compañeros';

  @override
  String get settings_appearance_listView_certifications =>
      'Vista de lista de certificaciones';

  @override
  String get settings_appearance_listView_certifications_subtitle =>
      'Diseño predeterminado de la lista de certificaciones';

  @override
  String get settings_appearance_listView_courses => 'Vista de lista de cursos';

  @override
  String get settings_appearance_listView_courses_subtitle =>
      'Diseño predeterminado de la lista de cursos';

  @override
  String get settings_appearance_listView_diveCenters =>
      'Vista de lista de centros de buceo';

  @override
  String get settings_appearance_listView_diveCenters_subtitle =>
      'Diseño predeterminado de la lista de centros de buceo';

  @override
  String get settings_appearance_listView_dives =>
      'Vista de lista de inmersiones';

  @override
  String get settings_appearance_listView_dives_subtitle =>
      'Diseño predeterminado de la lista de inmersiones';

  @override
  String get settings_appearance_listView_equipment =>
      'Vista de lista de equipo';

  @override
  String get settings_appearance_listView_equipment_subtitle =>
      'Diseño predeterminado de la lista de equipo';

  @override
  String get settings_appearance_listView_sites =>
      'Vista de lista de puntos de buceo';

  @override
  String get settings_appearance_listView_sites_subtitle =>
      'Diseño predeterminado de la lista de puntos de buceo';

  @override
  String get settings_appearance_listView_trips => 'Vista de lista de viajes';

  @override
  String get settings_appearance_listView_trips_subtitle =>
      'Diseño predeterminado de la lista de viajes';

  @override
  String get settings_appearance_showDataSourceBadges =>
      'Mostrar insignias de origen de los datos';

  @override
  String get settings_appearance_showDataSourceBadges_subtitle =>
      'Mostrar la atribución de origen en las métricas de inmersión';

  @override
  String get settings_appearance_title_buddies => 'Apariencia de compañeros';

  @override
  String get settings_appearance_title_certifications =>
      'Apariencia de certificaciones';

  @override
  String get settings_appearance_title_courses => 'Apariencia de cursos';

  @override
  String get settings_appearance_title_diveCenters =>
      'Apariencia de centros de buceo';

  @override
  String get settings_appearance_title_dives => 'Apariencia de inmersiones';

  @override
  String get settings_appearance_title_equipment => 'Apariencia de equipo';

  @override
  String get settings_appearance_title_sites => 'Apariencia de puntos de buceo';

  @override
  String get settings_appearance_title_trips => 'Apariencia de viajes';

  @override
  String get settings_cloudSync_troubleshoot_tileSubtitle =>
      'Arregla una sincronización atascada o libera espacio en la nube';

  @override
  String get settings_data_header_dataTools => 'Herramientas de datos';

  @override
  String get settings_decompression_ascentGasLabel =>
      'Planificar el ascenso con';

  @override
  String get settings_decompression_ascentGas_allCarried =>
      'Todos los tanques llevados';

  @override
  String get settings_decompression_ascentGas_decoStage =>
      'Tanque de deco/etapa + gas principal';

  @override
  String get settings_decompression_cnsSource => 'Origen del CNS';

  @override
  String get settings_decompression_decoStopSource =>
      'Origen de las paradas de descompresión';

  @override
  String get settings_decompression_header_ascent =>
      'Planificación del ascenso';

  @override
  String get settings_decompression_header_ascent_subtitle =>
      'A qué tanques llevados puede cambiar el ascenso simulado (TTS, techo y paradas) en cada profundidad. Solo se tienen en cuenta los gases registrados en la inmersión.';

  @override
  String get settings_decompression_header_dataSources =>
      'Preferencias de origen de los datos';

  @override
  String get settings_decompression_header_dataSources_subtitle =>
      'Cuando se selecciona Ordenador de buceo, la app usa los datos informados por el ordenador de buceo cuando están disponibles. Si no hay datos del ordenador, recurre a los valores calculados.';

  @override
  String get settings_decompression_ndlSource => 'Origen del NDL';

  @override
  String get settings_decompression_sourceCalculated => 'Calculado';

  @override
  String get settings_decompression_sourceComputer => 'Ordenador de buceo';

  @override
  String get settings_decompression_ttsSource => 'Origen del TTS';

  @override
  String settings_fixDiveTimes_applied(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'actualizaron',
      one: 'actualizó',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones',
      one: 'inmersión',
    );
    String _temp2 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'horas',
      one: 'hora',
    );
    return 'Se $_temp0 $count $_temp1 en $hours $_temp2.';
  }

  @override
  String settings_fixDiveTimes_apply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones',
      one: 'inmersión',
    );
    return 'Aplicar a $count $_temp0';
  }

  @override
  String get settings_fixDiveTimes_clearRange => 'Borrar el rango de fechas';

  @override
  String get settings_fixDiveTimes_confirmApply => 'Aplicar';

  @override
  String settings_fixDiveTimes_confirmBody(
    int count,
    String hours,
    int hoursAbs,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones',
      one: 'inmersión',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'horas',
      one: 'hora',
    );
    return 'Esto desplazará $count $_temp0 en $hours $_temp1. Esto no se puede deshacer automáticamente.';
  }

  @override
  String get settings_fixDiveTimes_confirmTitle => 'Aplicar desfase horario';

  @override
  String get settings_fixDiveTimes_dateRangeFilter =>
      'Filtro por rango de fechas';

  @override
  String get settings_fixDiveTimes_deselectAll => 'Deseleccionar todo';

  @override
  String get settings_fixDiveTimes_diveFallback => 'Inmersión';

  @override
  String settings_fixDiveTimes_diveNumber(int number) {
    return 'Inmersión n.º $number';
  }

  @override
  String get settings_fixDiveTimes_empty => 'No se encontraron inmersiones.';

  @override
  String get settings_fixDiveTimes_emptyFiltered =>
      'No se encontraron inmersiones en este rango de fechas.';

  @override
  String get settings_fixDiveTimes_enterOffsetHint =>
      'Introduce un desfase en horas';

  @override
  String get settings_fixDiveTimes_from => 'Desde';

  @override
  String get settings_fixDiveTimes_hourOffset => 'Desfase horario';

  @override
  String get settings_fixDiveTimes_hoursField => 'Horas (p. ej. +7, -5)';

  @override
  String settings_fixDiveTimes_loadError(String error) {
    return 'No se pudieron cargar las inmersiones: $error';
  }

  @override
  String get settings_fixDiveTimes_noSelection =>
      'No hay inmersiones seleccionadas.';

  @override
  String get settings_fixDiveTimes_offsetHint =>
      'Introduce un número entero positivo o negativo para desplazar las horas de las inmersiones.';

  @override
  String settings_fixDiveTimes_preview(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inmersiones se desplazarán',
      one: 'inmersión se desplazará',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'horas',
      one: 'hora',
    );
    return 'Vista previa: $count $_temp0 en $hours $_temp1.';
  }

  @override
  String get settings_fixDiveTimes_selectAll => 'Seleccionar todo';

  @override
  String get settings_fixDiveTimes_selectDivesHint =>
      'Selecciona las inmersiones a las que aplicarlo';

  @override
  String get settings_fixDiveTimes_subtitle =>
      'Ajusta las horas de las inmersiones importadas';

  @override
  String get settings_fixDiveTimes_title => 'Corregir horas de inmersión';

  @override
  String get settings_fixDiveTimes_to => 'Hasta';

  @override
  String get settings_fixDiveTimes_zeroOffset =>
      'El desfase horario es 0, no hay nada que cambiar.';

  @override
  String get settings_syncDevices_appBar_refreshTooltip => 'Actualizar';

  @override
  String get settings_syncDevices_appBar_title =>
      'Dispositivos en este servicio';

  @override
  String get settings_syncDevices_empty =>
      'No hay archivos de sincronización en este servicio.';

  @override
  String settings_syncDevices_readError(String error) {
    return 'No se pudo leer el servicio.\n$error';
  }

  @override
  String get settings_syncDevices_removal_noBackend =>
      'No hay ningún servicio en la nube configurado';

  @override
  String get settings_syncDevices_removal_unreachable =>
      'No se pudo contactar con el servicio. No se eliminó nada.';

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
          'Esto elimina $count archivos ($size) que pertenecen a $name.\n\nEse dispositivo sigue formando parte de esta sincronización. Si vuelve a conectarse, se reconstruirá desde el servicio en lugar de resucitar datos antiguos, pero se perderán todos los cambios que aún no haya publicado. Tus datos de inmersión en ESTE dispositivo no se ven afectados.',
      one:
          'Esto elimina 1 archivo ($size) que pertenece a $name.\n\nEse dispositivo sigue formando parte de esta sincronización. Si vuelve a conectarse, se reconstruirá desde el servicio en lugar de resucitar datos antiguos, pero se perderán todos los cambios que aún no haya publicado. Tus datos de inmersión en ESTE dispositivo no se ven afectados.',
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
          'Esto elimina $count archivos ($size) que pertenecen a $name. Son restos de una biblioteca con la que ya no se sincroniza ningún dispositivo. Tus datos de inmersión no se ven afectados.',
      one:
          'Esto elimina 1 archivo ($size) que pertenece a $name. Es un resto de una biblioteca con la que ya no se sincroniza ningún dispositivo. Tus datos de inmersión no se ven afectados.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_removeDialog_title(String name) {
    return '¿Quitar los archivos de $name?';
  }

  @override
  String settings_syncDevices_removeProgressTitle(String name) {
    return 'Quitando los archivos de $name';
  }

  @override
  String get settings_syncDevices_removeTooltip =>
      'Quitar los archivos de este dispositivo';

  @override
  String get settings_syncDevices_state_active =>
      'Sincronizando con normalidad';

  @override
  String get settings_syncDevices_state_retired => 'Retirado';

  @override
  String get settings_syncDevices_state_staleEpoch =>
      'Resto de una biblioteca anterior, ningún dispositivo lo lee';

  @override
  String get settings_syncDevices_state_thisDevice => 'Este dispositivo';

  @override
  String get settings_syncDevices_state_unreadable =>
      'Sin manifiesto legible: una subida sin terminar o cifrada';

  @override
  String settings_syncDevices_summary(
    int deviceCount,
    int fileCount,
    String size,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      deviceCount,
      locale: localeName,
      other: '$deviceCount dispositivos',
      one: '1 dispositivo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: '$fileCount archivos',
      one: '1 archivo',
    );
    return '$_temp0, $_temp1, $size';
  }

  @override
  String settings_syncDevices_summary_removable(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count restos de bibliotecas reemplazadas o retiradas, que ocupan $size.',
      one: '1 resto de una biblioteca reemplazada o retirada, que ocupa $size.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_tile_filesSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '1 archivo',
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
      other: '$count archivos',
      one: '1 archivo',
    );
    return '$_temp0, $size, $when';
  }

  @override
  String settings_syncDevices_unnamedDevice(String shortId) {
    return 'Dispositivo $shortId';
  }

  @override
  String get settings_syncMaintenance_keepAppOpen =>
      'Mantén la app abierta hasta que esto termine. Si la cierras ahora, el servicio queda parcialmente vaciado y la siguiente sincronización tiene que empezar de nuevo.';

  @override
  String get settings_syncMaintenance_phase_clearingOldFiles =>
      'Borrando archivos antiguos';

  @override
  String get settings_syncMaintenance_phase_deleting => 'Eliminando';

  @override
  String get settings_syncMaintenance_phase_publishingLibrary =>
      'Publicando la biblioteca';

  @override
  String get settings_cloudSync_adopt_progressTitle =>
      'Adoptando la biblioteca restaurada';

  @override
  String get settings_cloudSync_replaceLibrary_progressTitle =>
      'Reemplazando la biblioteca en la nube';

  @override
  String settings_syncDevices_nameWithId(String name, String shortId) {
    return '$name ($shortId)';
  }

  @override
  String get settings_syncMaintenance_phase_applyingLibrary =>
      'Aplicando la biblioteca';

  @override
  String get settings_syncMaintenance_phase_backingUp =>
      'Creando una copia de seguridad de este dispositivo';

  @override
  String get settings_syncMaintenance_phase_repairing =>
      'Borrando el estado de sincronización local';

  @override
  String get settings_troubleshootSync_repair_progressTitle =>
      'Reparando la sincronización';

  @override
  String get settings_syncMaintenance_phase_working => 'Trabajando...';

  @override
  String settings_syncMaintenance_progress_filesOfTotal(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done de $total archivos',
      one: '$done de 1 archivo',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_removedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos quitados',
      one: '1 archivo quitado',
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
          '$count archivos quitados, pero $trouble. Vuelve a intentarlo cuando estés en línea.',
      one:
          '1 archivo quitado, pero $trouble. Vuelve a intentarlo cuando estés en línea.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_trouble_failed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count no se pudieron eliminar',
      one: '1 no se pudo eliminar',
    );
    return '$_temp0';
  }

  @override
  String get settings_syncMaintenance_trouble_listIncomplete =>
      'algunos archivos no se pudieron listar';

  @override
  String settings_syncMaintenance_wipedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos borrados',
      one: '1 archivo borrado',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_wipedFilesPartial(int count, String trouble) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count archivos borrados, pero $trouble. Vuelve a intentarlo cuando estés en línea.',
      one:
          '1 archivo borrado, pero $trouble. Vuelve a intentarlo cuando estés en línea.',
    );
    return '$_temp0';
  }

  @override
  String get settings_troubleshootSync_appBar_title =>
      'Solucionar problemas de sincronización';

  @override
  String get settings_troubleshootSync_devices_subtitle =>
      'Consulta todos los dispositivos que guardan archivos aquí, cuánto espacio ocupa cada uno, y elimina los restos de bibliotecas con las que ya no se sincroniza ningún dispositivo. Tus datos de inmersión no se ven afectados.';

  @override
  String get settings_troubleshootSync_rebuild_confirm => 'Reconstruir';

  @override
  String get settings_troubleshootSync_rebuild_confirmBody =>
      'Esto convierte la biblioteca de este dispositivo en la biblioteca actual del servicio y la vuelve a publicar, para que los demás dispositivos sincronicen desde ti. Úsalo cuando una sustitución hecha desde otro dispositivo se queda atascada. Tus datos de inmersión no se ven afectados.';

  @override
  String get settings_troubleshootSync_rebuild_confirmTitle =>
      '¿Reconstruir el servicio desde este dispositivo?';

  @override
  String get settings_troubleshootSync_rebuild_doneSnack =>
      'Servicio reconstruido desde este dispositivo';

  @override
  String get settings_troubleshootSync_rebuild_failedSnack =>
      'La reconstrucción falló';

  @override
  String get settings_troubleshootSync_rebuild_progressTitle =>
      'Reconstruyendo el servicio';

  @override
  String get settings_troubleshootSync_rebuild_subtitle =>
      'Úsalo si la sincronización está atascada esperando una biblioteca que otro dispositivo reemplazó pero nunca terminó de subir (puede que ese dispositivo esté desconectado). Publica la biblioteca de este dispositivo como la actual.';

  @override
  String get settings_troubleshootSync_rebuild_title =>
      'Reconstruir el servicio desde este dispositivo';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmBody =>
      'Esto elimina del servicio solo los archivos de sincronización de este dispositivo. Los demás dispositivos siguen sincronizando y tus datos de inmersión no se ven afectados.';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmTitle =>
      '¿Quitar los archivos en la nube de este dispositivo?';

  @override
  String get settings_troubleshootSync_removeThisDevice_progressTitle =>
      'Quitando los archivos en la nube de este dispositivo';

  @override
  String get settings_troubleshootSync_removeThisDevice_subtitle =>
      'Libera el espacio que ocupa este dispositivo en el servicio. Los demás dispositivos siguen sincronizando. Tus datos de inmersión no se ven afectados.';

  @override
  String get settings_troubleshootSync_removeThisDevice_title =>
      'Quitar los archivos en la nube de este dispositivo';

  @override
  String get settings_troubleshootSync_repair_confirm => 'Reparar';

  @override
  String get settings_troubleshootSync_repair_confirmBody =>
      'Esto borra todo el estado local de sincronización y da a este dispositivo una nueva identidad de sincronización; después se reconecta desde cero en la siguiente sincronización. Tus datos de inmersión están a salvo y no se eliminan.';

  @override
  String get settings_troubleshootSync_repair_confirmTitle =>
      '¿Reparar la sincronización?';

  @override
  String get settings_troubleshootSync_repair_doneSnack =>
      'Sincronización reparada';

  @override
  String get settings_troubleshootSync_repair_subtitle =>
      'Arregla una sincronización atascada. Borra el estado de sincronización de este dispositivo y le da una nueva identidad de sincronización; después se reconecta en la siguiente sincronización. Tus datos de inmersión no se ven afectados.';

  @override
  String get settings_troubleshootSync_repair_title =>
      'Reparar la sincronización';

  @override
  String get settings_troubleshootSync_wipeAll_confirm => 'Borrarlo todo';

  @override
  String settings_troubleshootSync_wipeAll_confirmBody(String word) {
    return 'Esto elimina de este servicio los datos de sincronización de TODOS los dispositivos, incluidos los marcadores de biblioteca. Cada dispositivo tendrá que restablecer la sincronización desde cero. Tus datos de inmersión no se ven afectados.\n\nEscribe $word para confirmar.';
  }

  @override
  String get settings_troubleshootSync_wipeAll_confirmTitle =>
      '¿Borrar todos los datos de sincronización?';

  @override
  String get settings_troubleshootSync_wipeAll_progressTitle =>
      'Borrando los datos de sincronización';

  @override
  String get settings_troubleshootSync_wipeAll_subtitle =>
      'Elimina de este servicio los datos de sincronización de todos los dispositivos, incluidos los marcadores de biblioteca. Cada dispositivo restablece la sincronización desde cero. Tus datos de inmersión no se ven afectados.';

  @override
  String get settings_troubleshootSync_wipeAll_title =>
      'Borrar todos los datos de sincronización de este servicio';

  @override
  String get tableMode_tooltip_toggleDetailPane =>
      'Mostrar u ocultar el panel de detalle';

  @override
  String get tableMode_tooltip_toggleProfilePanel =>
      'Mostrar u ocultar el panel de perfil';

  @override
  String get maps_regionDownload_title => 'Descargar región';

  @override
  String get maps_regionDownload_nameRequired =>
      'Introduce un nombre para esta región';

  @override
  String get maps_regionDownload_nameLabel => 'Nombre de la región';

  @override
  String get maps_regionDownload_nameHint => 'ej., Cozumel, México';

  @override
  String get maps_regionDownload_zoomLevels => 'Niveles de zoom';

  @override
  String get maps_regionDownload_zoomHint =>
      'Más zoom = más detalle, descarga más grande';

  @override
  String maps_regionDownload_minZoom(int zoom) {
    return 'Mín.: $zoom';
  }

  @override
  String maps_regionDownload_minZoomSemantics(int zoom) {
    return 'Zoom mínimo: $zoom';
  }

  @override
  String maps_regionDownload_maxZoom(int zoom) {
    return 'Máx.: $zoom';
  }

  @override
  String maps_regionDownload_maxZoomSemantics(int zoom) {
    return 'Zoom máximo: $zoom';
  }

  @override
  String get maps_regionDownload_estimatingSemantics =>
      'Estimando el tamaño de la descarga';

  @override
  String maps_regionDownload_estimateSemantics(int count, Object size) {
    return 'Descarga estimada: $count teselas, $size';
  }

  @override
  String get maps_regionDownload_estimateUnavailableSemantics =>
      'No se puede estimar el tamaño de la descarga';

  @override
  String get maps_regionDownload_estimating => 'Estimando...';

  @override
  String maps_regionDownload_tileCount(int count) {
    return '~$count teselas';
  }

  @override
  String get maps_regionDownload_estimateUnavailable => 'No se puede estimar';

  @override
  String get maps_regionDownload_largeWarningSemantics =>
      'Aviso: descarga grande. Reduce los niveles de zoom o selecciona una región más pequeña.';

  @override
  String get maps_regionDownload_largeWarning =>
      'Descarga grande. Reduce los niveles de zoom o selecciona una región más pequeña.';

  @override
  String get maps_regionDownload_downloadButton => 'Descargar';

  @override
  String get diveLog_map_title => 'Actividad de buceo';

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
      'Miniatura de foto. Toca para ver en pantalla completa';

  @override
  String get trips_gallery_thumbnail_video =>
      'Miniatura de vídeo. Toca para ver en pantalla completa';

  @override
  String get trips_gallery_thumbnail_photoMissing =>
      'Miniatura de foto, no está en el dispositivo. Toca para ver en pantalla completa';

  @override
  String get trips_gallery_thumbnail_videoMissing =>
      'Miniatura de vídeo, no está en el dispositivo. Toca para ver en pantalla completa';

  @override
  String get trips_photos_thumbnail_photo =>
      'Miniatura de foto. Toca para abrir la galería';

  @override
  String get trips_photos_thumbnail_video =>
      'Miniatura de vídeo. Toca para abrir la galería';

  @override
  String trips_picker_suggestedSemantics(Object name) {
    return 'Viaje sugerido: $name. Toca para usarlo';
  }

  @override
  String trips_picker_tileSemantics(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, del $startDate al $endDate';
  }

  @override
  String trips_picker_tileSemanticsSelected(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, del $startDate al $endDate, seleccionado';
  }

  @override
  String get divePlanner_quickPlan_subtitle =>
      'Crear un perfil de inmersión rectangular simple';

  @override
  String get divePlanner_quickPlan_depthLabel => 'Profundidad:';

  @override
  String divePlanner_quickPlan_depthSemantics(Object depth) {
    return 'Profundidad: $depth';
  }

  @override
  String get divePlanner_quickPlan_timeLabel => 'Tiempo:';

  @override
  String divePlanner_quickPlan_bottomTimeSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Tiempo de fondo: $minutes minutos',
      one: 'Tiempo de fondo: 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String divePlanner_quickPlan_minutes(int minutes) {
    return '$minutes min';
  }

  @override
  String divePlanner_quickPlan_previewSemantics(Object depth, int minutes) {
    return 'Vista previa del plan: descenso a $depth, tiempo de fondo $minutes minutos, ascenso con parada de seguridad';
  }

  @override
  String get divePlanner_quickPlan_previewTitle => 'Vista previa del plan:';

  @override
  String divePlanner_quickPlan_previewDescent(Object depth) {
    return 'Descenso a $depth';
  }

  @override
  String divePlanner_quickPlan_previewBottomTime(int minutes) {
    return 'Tiempo de fondo: $minutes min';
  }

  @override
  String get divePlanner_quickPlan_previewAscent =>
      'Ascenso con parada de seguridad';

  @override
  String get divePlanner_quickPlan_create => 'Crear';

  @override
  String divePlanner_semantics_sacRate(Object value, Object volumeSymbol) {
    return 'RMV: $value $volumeSymbol por minuto';
  }

  @override
  String divePlanner_semantics_reservePressure(Object pressureSymbol) {
    return 'Presión de reserva en $pressureSymbol';
  }

  @override
  String divePlanner_semantics_altitudeGroup(Object group) {
    return 'Grupo de altitud: $group';
  }

  @override
  String diveSites_import_detail_maxDepth(Object depth) {
    return 'Máx. $depth';
  }

  @override
  String get autoUpdate_banner_download => 'Descargar';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Sincronizar mediante Apple iCloud';

  @override
  String get settings_debugLog_search_hint => 'Buscar en los registros...';

  @override
  String get settings_debugLog_appBar_title => 'Registros de depuración';

  @override
  String get settings_debugLog_disableDebugMode =>
      'Desactivar el modo de depuración';

  @override
  String get settings_debugLog_clearLogs => 'Borrar registros';

  @override
  String get settings_debugLog_empty =>
      'Ninguna entrada de registro coincide con los filtros actuales';

  @override
  String settings_debugLog_loadError(Object error) {
    return 'Error al cargar los registros: $error';
  }

  @override
  String get settings_debugLog_copiedSnack =>
      'Registros filtrados copiados al portapapeles';

  @override
  String settings_debugLog_savedSnack(String path) {
    return 'Registros guardados en $path';
  }

  @override
  String get common_action_copy => 'Copiar';

  @override
  String get settings_appearance_customGradient_title =>
      'Degradado personalizado';

  @override
  String get settings_appearance_customGradient_start => 'Inicio';

  @override
  String get settings_appearance_customGradient_end => 'Fin';

  @override
  String get settings_appearance_customGradient_hue => 'Tono';

  @override
  String get settings_appearance_customGradient_saturation => 'Saturación';

  @override
  String get settings_appearance_customGradient_brightness => 'Brillo';

  @override
  String get settings_appearance_customGradient_preview => 'Vista previa';

  @override
  String get common_action_apply => 'Aplicar';

  @override
  String settings_cloudSync_message_loadStateFailed(Object error) {
    return 'Error al cargar el estado de sincronización: $error';
  }

  @override
  String get settings_cloudSync_message_noProviderConfigured =>
      'No hay ningún proveedor en la nube configurado';

  @override
  String get settings_cloudSync_message_adopting =>
      'Adoptando la biblioteca restaurada...';

  @override
  String get settings_cloudSync_message_adoptFailed =>
      'No se pudo adoptar la biblioteca restaurada';

  @override
  String get settings_cloudSync_message_firstSyncNeedsConfirm =>
      'La primera sincronización necesita confirmación. Toca «Sincronizar ahora» para revisarla.';

  @override
  String get settings_cloudSync_message_startingSync =>
      'Iniciando sincronización...';

  @override
  String get settings_cloudSync_message_replacePaused =>
      'Sincronización en pausa: la biblioteca se reemplazó desde una copia de seguridad. Toca «Sincronizar ahora» para revisarla.';

  @override
  String get settings_cloudSync_message_encryptedPaused =>
      'Sincronización en pausa: esta biblioteca está cifrada. Introduce la frase de acceso para continuar.';

  @override
  String get settings_cloudSync_message_completedWithConflicts =>
      'Sincronización completada con conflictos';

  @override
  String get settings_cloudSync_message_completedSuccessfully =>
      'Sincronización completada correctamente';

  @override
  String get settings_cloudSync_message_syncFailed => 'Sincronización fallida';

  @override
  String get settings_cloudSync_message_phaseDefault => 'sincronización';

  @override
  String settings_cloudSync_message_syncErrorDuring(
    String phase,
    Object error,
  ) {
    return 'Error de sincronización durante $phase: $error';
  }

  @override
  String get settings_section_debug_title => 'Depuración';

  @override
  String get settings_section_debug_subtitle => 'Registros y diagnósticos';

  @override
  String get settings_debugLog_minSeverityLabel => 'Gravedad mín.:';

  @override
  String get settings_debugLog_shareSubject =>
      'Registros de depuración de Submersion';

  @override
  String get settings_debugLog_saveDialogTitle =>
      'Guardar registros de depuración';

  @override
  String get universalImport_preset_saveTitle => 'Guardar como preajuste';

  @override
  String get universalImport_preset_nameLabel => 'Nombre del preajuste';

  @override
  String get universalImport_preset_nameHint =>
      'ej., Mi CSV de registro de buceo';

  @override
  String get universalImport_preset_nameRequired => 'El nombre es obligatorio';

  @override
  String get universalImport_preset_sourceAppLabel => 'Aplicación de origen';

  @override
  String get universalImport_preset_sourceAppNone => 'Ninguna';

  @override
  String get universalImport_preset_entityTypesLabel => 'Tipos de entidad';

  @override
  String get universalImport_preset_matchThresholdLabel =>
      'Umbral de coincidencia';

  @override
  String get universalImport_preset_matchThresholdHelp =>
      'Cuánto deben coincidir los encabezados CSV para la detección automática';

  @override
  String universalImport_preset_signatureHeaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count encabezados de firma del archivo actual',
      one: '1 encabezado de firma del archivo actual',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_preset_selectTitle => 'Seleccionar preajuste';

  @override
  String universalImport_preset_loadFailed(String error) {
    return 'Error al cargar los preajustes: $error';
  }

  @override
  String get universalImport_preset_sectionSaved => 'Preajustes guardados';

  @override
  String get universalImport_preset_sectionBuiltIn => 'Preajustes integrados';

  @override
  String get universalImport_preset_deleteTitle => 'Eliminar preajuste';

  @override
  String universalImport_preset_deleteConfirm(String name) {
    return '¿Eliminar «$name»? Esta acción no se puede deshacer.';
  }

  @override
  String universalImport_preset_headersMatched(
    int matched,
    int total,
    int percent,
  ) {
    return '$matched/$total encabezados coincidentes ($percent%)';
  }

  @override
  String get universalImport_preset_noSignatureHeaders =>
      'Sin encabezados de firma';

  @override
  String get universalImport_preset_deleteTooltip => 'Eliminar preajuste';

  @override
  String get universalImport_preset_presetsButton => 'Preajustes';

  @override
  String universalImport_preset_savedSnackbar(String name) {
    return 'Preajuste «$name» guardado';
  }

  @override
  String get universalImport_step_done => 'Listo';

  @override
  String get universalImport_cancel_inProgressTitle => 'Cancelando';

  @override
  String get universalImport_cancel_inProgressBody =>
      'Se terminará la inmersión actual antes de detenerse. Las inmersiones ya importadas se conservan.';

  @override
  String get universalImport_cancel_confirmTitle => '¿Cancelar la importación?';

  @override
  String get universalImport_cancel_confirmBody =>
      'Detener cuando termine la inmersión actual. Las inmersiones ya importadas se conservarán.';

  @override
  String get universalImport_cancel_keepImporting => 'Seguir importando';

  @override
  String get universalImport_cancel_confirmAction => 'Cancelar importación';

  @override
  String get universalImport_cancel_discardSelections =>
      '¿Descartar la selección y cancelar?';

  @override
  String get universalImport_action_importSelected => 'Importar selección';

  @override
  String get universalImport_action_next => 'Siguiente';

  @override
  String get common_action_yes => 'Sí';

  @override
  String get common_action_no => 'No';

  @override
  String universalImport_counts_new(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuevos',
      one: '$count nuevo',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_merging(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count a consolidar',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_replacing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count a reemplazar',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_skipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count omitidos',
      one: '$count omitido',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_counts_nothingSelected => 'Nada seleccionado';

  @override
  String get universalImport_section_potentialDuplicates =>
      'Duplicados potenciales';

  @override
  String get universalImport_section_possibleDuplicates =>
      'Posibles duplicados';

  @override
  String universalImport_count_duplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicados',
      one: '1 duplicado',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_entityAction_importBadge => 'IMPORTAR';

  @override
  String get universalImport_entityAction_skipBadge => 'OMITIR';

  @override
  String get universalImport_compare_existing => 'Existente';

  @override
  String get universalImport_compare_incoming => 'Entrante';

  @override
  String get universalImport_label_skipped => 'Omitido';

  @override
  String get universalImport_action_viewDives => 'Ver inmersiones';

  @override
  String get diveImport_healthkit_accessGranted =>
      'Acceso a HealthKit concedido';

  @override
  String get diveImport_healthkit_accessGrantedBody =>
      'Puedes continuar al siguiente paso.';

  @override
  String get diveImport_healthkit_requesting => 'Solicitando...';

  @override
  String get diveImport_healthkit_selectDateRange =>
      'Seleccionar intervalo de fechas';

  @override
  String get diveImport_healthkit_selectDateRangeBody =>
      'Elige el intervalo de fechas para buscar inmersiones en Apple Health.';

  @override
  String get diveImport_healthkit_fetchingDives =>
      'Obteniendo inmersiones de Apple Health...';

  @override
  String get diveImport_healthkit_fetchFailed => 'Obtención fallida';

  @override
  String diveImport_healthkit_fetchFailedBody(String error) {
    return 'Error al obtener las inmersiones: $error';
  }

  @override
  String diveImport_healthkit_foundDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inmersiones encontradas',
      one: '1 inmersión encontrada',
    );
    return '$_temp0';
  }

  @override
  String get diveImport_healthkit_proceedingToReview =>
      'Pasando a la revisión...';

  @override
  String get importWizard_dc_knownComputer => 'Ordenador conocido';

  @override
  String importWizard_dc_knownComputerBody(String name) {
    return 'Guardado como «$name». Solo se descargarán las inmersiones nuevas.';
  }

  @override
  String get importWizard_dc_noNewDives =>
      'No hay inmersiones nuevas para descargar';

  @override
  String get importWizard_dc_noNewDivesBody =>
      'Todas las inmersiones de este ordenador ya se han importado.';

  @override
  String get universalImport_compare_noDiveData =>
      'Datos de inmersión no disponibles para la comparación.';

  @override
  String get universalImport_entityAction_consolidateBadge => 'CONSOLIDAR';

  @override
  String get diveCenters_import_quickSearch_egypt => 'Egipto';

  @override
  String get diveCenters_import_quickSearch_mexico => 'México';

  @override
  String get accessibility_shortcut_switchDiver => 'Cambiar de buceador';

  @override
  String get lock_recoveryCode_title => 'Usar código de recuperación';

  @override
  String get lock_recoveryCode_body =>
      'Introduce el código de recuperación de 8 palabras que guardaste al configurar la contraseña de la app.';

  @override
  String get lock_recoveryCode_error => 'Código de recuperación incorrecto.';

  @override
  String get lock_forcedReset_title => 'Establece una nueva contraseña';

  @override
  String get lock_forcedReset_body =>
      'Has desbloqueado con tu código de recuperación, así que tu contraseña anterior ya no es de confianza. Elige una nueva ahora.';

  @override
  String get lock_forcedReset_submit => 'Establecer contraseña';

  @override
  String get lock_forcedReset_error =>
      'No se pudo establecer la nueva contraseña. Inténtalo de nuevo.';

  @override
  String get lock_sidecarRepair_title =>
      'Reparar el archivo de clave de seguridad';

  @override
  String get lock_sidecarRepair_body =>
      'Faltaba tu archivo de clave de seguridad y el llavero de este dispositivo todavía conserva la clave. Confirma tu contraseña para escribir un nuevo archivo de clave. Nota: la contraseña que introduzcas aquí pasará a ser la contraseña de la app a partir de ahora, y recibirás un nuevo código de recuperación.';

  @override
  String get lock_sidecarRepair_submit => 'Reparar';

  @override
  String get lock_sidecarRepair_error =>
      'La reparación falló. Inténtalo de nuevo.';

  @override
  String get lock_newRecoveryCode_title => 'Tu nuevo código de recuperación';

  @override
  String get lock_startFresh_title => 'Abrir otra base de datos';

  @override
  String lock_startFresh_body(Object token) {
    return 'Tu base de datos actual permanece en el disco, renombrada con el sufijo .locked; no se elimina nada. Puedes recuperarla más adelante con tu contraseña o contactando con el soporte. La sincronización en la nube se desactivará para que la nueva base de datos no pueda mezclarse con la antigua.\n\nLa app se iniciará con una base de datos nueva y vacía. Puedes restaurar una copia de seguridad en el asistente de configuración.\n\nEscribe $token para confirmar.';
  }

  @override
  String get lock_startFresh_confirm => 'Apartar y empezar de cero';

  @override
  String get lock_biometric_reason => 'Desbloquea tu registro de buceo';

  @override
  String startup_migrating_progress(Object currentStep, Object totalSteps) {
    return 'Actualizando la base de datos... paso $currentStep de $totalSteps';
  }

  @override
  String get startup_error_title => 'Submersion no pudo iniciarse';

  @override
  String get startup_error_body =>
      'Algo salió mal antes de que tu cuaderno de buceo terminara de abrirse. Tus datos siguen en el disco y no requieren una reinstalación. Prueba a reiniciar la aplicación; si el problema persiste, contacta con el soporte.';

  @override
  String get startup_engineUnavailable_title =>
      'Esta compilación no puede abrir una base de datos';

  @override
  String get startup_engineUnavailable_body =>
      'A esta compilación le falta el motor de base de datos de Submersion, por lo que tu cuaderno de buceo nunca llegó a abrirse. Nada ha cambiado en el disco y ningún dato está en riesgo.';

  @override
  String get startup_engineUnavailable_guidance =>
      'Reinstalar o restaurar una copia de seguridad no servirá de nada. Instala una compilación funcional de Submersion e infórmanos de esto: es un fallo del paquete de la aplicación, no de tus datos.';

  @override
  String get startup_migrationFailed_title =>
      'Error al actualizar la base de datos';

  @override
  String get startup_migrationFailed_body =>
      'Tu cuaderno de buceo no pudo actualizarse al formato que necesita esta versión. Se hizo una copia de seguridad antes de empezar la actualización, así que no se ha perdido nada.';

  @override
  String get startup_dataUnreadable_title =>
      'No se pudo leer tu cuaderno de buceo';

  @override
  String get startup_dataUnreadable_body =>
      'El archivo de la base de datos está ahí, pero Submersion no puede leerlo. Normalmente esto significa que el archivo está dañado. Restaurar una copia de seguridad es la forma más rápida de volver.';

  @override
  String get startup_databaseBusy_title =>
      'Tu cuaderno de buceo estaba ocupado';

  @override
  String get startup_databaseBusy_body =>
      'Algo más seguía usando el archivo de la base de datos, así que Submersion se detuvo en lugar de escribir en él. No se cambió nada y nada está dañado. Cierra Submersion por completo y vuelve a abrirlo.';

  @override
  String get startup_failure_technicalDetails => 'Detalles técnicos';

  @override
  String get startup_failure_backupAvailable_title =>
      'Hay una copia de seguridad disponible';

  @override
  String startup_failure_backupAvailable_taken(Object timestamp) {
    return 'Creada el $timestamp';
  }

  @override
  String startup_failure_backupAvailable_preMigration(
    Object fromVersion,
    Object toVersion,
  ) {
    return 'Copia de seguridad creada antes de la actualización del esquema v$fromVersion a v$toVersion.';
  }

  @override
  String get startup_failure_restoreAction =>
      'Restaurar esta copia de seguridad';

  @override
  String get startup_failure_restoring => 'Restaurando tu cuaderno de buceo...';

  @override
  String get startup_failure_restoreFailed =>
      'No se pudo restaurar la copia de seguridad. Tu cuaderno de buceo se ha dejado exactamente como estaba.';

  @override
  String get startup_failure_backupsFolder =>
      'Tus copias de seguridad están en:';

  @override
  String get startup_failure_showBackupsFolder => 'Mostrar carpeta de copias';

  @override
  String get startup_failure_downgrade_title => 'Volver a la versión anterior';

  @override
  String get startup_failure_downgrade_body =>
      'Si la actualización sigue fallando, instala la versión de Submersion que usabas antes y restaura la copia de seguridad desde esa versión. Restaurarla aquí solo volvería a ejecutar la misma actualización. Submersion no se degrada por sí solo: pasarte automáticamente a compilaciones antiguas te mantendría en silencio en versiones con problemas conocidos.';

  @override
  String get startup_failure_downgrade_action => 'Ver versiones anteriores';

  @override
  String get startup_recovering_title => 'Recuperando la base de datos...';

  @override
  String get startup_recovering_body =>
      'Revirtiendo la transacción interrumpida. Esto suele tardar unos segundos.';

  @override
  String get startup_recoveryFailed_title => 'La recuperación no se completó';

  @override
  String get startup_recoveryFailed_body =>
      'La base de datos no se pudo revertir automáticamente. Tus datos siguen en el disco; contacta con el soporte antes de reinstalar para que podamos ayudarte a recuperarlos.';

  @override
  String get startup_recoveryRequired_title =>
      'La base de datos necesita recuperación';

  @override
  String get startup_recoveryRequired_body =>
      'Una sesión anterior se interrumpió mientras escribía en la base de datos. Tus datos siguen en el disco; solo hace falta terminar de revertir el cambio cancelado antes de que la app pueda abrirse.';

  @override
  String startup_recovery_sqliteCode(Object code) {
    return 'Código SQLite $code';
  }

  @override
  String get startup_recovery_action => 'Recuperar base de datos';

  @override
  String get startup_recovery_closeWithoutRecovering => 'Cerrar sin recuperar';

  @override
  String get common_action_tryAgain => 'Inténtalo de nuevo';

  @override
  String get lock_screen_title => 'Submersion está bloqueado';

  @override
  String get lock_screen_forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get lock_incorrectPassword =>
      'Contraseña incorrecta. Inténtalo de nuevo.';

  @override
  String get startup_backup_semanticsLabel => 'Creando copia de seguridad';

  @override
  String get startup_backup_title =>
      'Creando una copia de seguridad de tus datos';

  @override
  String get startup_backup_body =>
      'Estamos guardando una copia de tu registro de buceo antes de actualizar tu base de datos.';

  @override
  String get startup_backupFailed_title =>
      'No se pudo crear la copia de seguridad de tus datos';

  @override
  String get startup_backupFailed_body =>
      'Tu registro de buceo no ha cambiado: no lo hemos actualizado. Libera espacio (o soluciona el problema) e inténtalo de nuevo.';

  @override
  String get startup_backupFailed_quit => 'Salir';

  @override
  String get startup_backupFailed_technicalDetails => 'Detalles técnicos';

  @override
  String get common_action_retry => 'Reintentar';

  @override
  String get startup_versionMismatch_title => 'Actualización requerida';

  @override
  String startup_versionMismatch_body(
    Object databaseVersion,
    Object appVersion,
  ) {
    return 'Tus datos de buceo se guardaron con una versión más reciente de Submersion (esquema v$databaseVersion). Esta versión solo admite esquemas hasta v$appVersion.';
  }

  @override
  String get startup_versionMismatch_instructions =>
      'Actualiza Submersion a la última versión. Tus datos están a salvo y no se han modificado. Si se hizo una copia de seguridad antes de la actualización, está en tu carpeta Backups y se puede restaurar después de actualizar.';

  @override
  String get startup_versionMismatch_storeInstructions =>
      'Esta app se instaló desde una tienda de aplicaciones y es más antigua que la versión que creó tus datos. Tus datos están a salvo y no se han modificado. Actualiza Submersion cuando la nueva versión aparezca en la tienda y vuelve a abrirla.';

  @override
  String get startup_versionMismatch_download => 'Descargar la última versión';

  @override
  String get startup_versionMismatch_manualLink =>
      'Si eso no abre un navegador, visita:';

  @override
  String get universalImport_compare_downloaded => 'Descargada';

  @override
  String get universalImport_compare_errorLoading =>
      'Error al cargar los datos de la inmersión';

  @override
  String get universalImport_compare_diveNotFound =>
      'No se encontró la inmersión existente';

  @override
  String universalImport_compare_sameFields(Object fields) {
    return 'Iguales: $fields';
  }

  @override
  String get universalImport_compare_differences => 'DIFERENCIAS';

  @override
  String get universalImport_compare_notRecorded => 'no registrado';

  @override
  String universalImport_compare_serial(Object serial) {
    return 'N.º serie: $serial';
  }

  @override
  String get universalImport_compare_skipSubtitle => 'Descartar esta descarga';

  @override
  String get universalImport_compare_importAsNewSubtitle =>
      'Guardar como inmersión aparte';

  @override
  String get universalImport_compare_consolidateSubtitle =>
      'Añadir como 2.ª lectura de ordenador';

  @override
  String get diveLog_tooltip_ndlOverMax => '>60 min';

  @override
  String diveLog_tooltip_interpolated(String value) {
    return '$value (interpolado)';
  }

  @override
  String get enum_profileMetric_ascentRate_short => 'Velocidad';

  @override
  String get enum_profileMetric_cns_short => 'CNS';

  @override
  String get enum_profileMetric_otu_short => 'OTU';

  @override
  String get diveLog_profileEditor_rangeOperations => 'Operaciones de rango';

  @override
  String get diveLog_profileEditor_selectRangeHint =>
      'Selecciona un rango en el gráfico para habilitar las operaciones';

  @override
  String get diveLog_profileEditor_depthPlusOneMeter => 'Prof. +1 m';

  @override
  String get diveLog_profileEditor_depthMinusOneMeter => 'Prof. -1 m';

  @override
  String get diveLog_profileEditor_timePlusFiveSeconds => 'Tiempo +5 s';

  @override
  String get diveLog_profileEditor_timeMinusFiveSeconds => 'Tiempo -5 s';

  @override
  String get diveLog_profileEditor_smoothing => 'Suavizado';

  @override
  String get diveLog_profileEditor_smoothLight => 'Ligero';

  @override
  String get diveLog_profileEditor_smoothMedium => 'Medio';

  @override
  String get diveLog_profileEditor_smoothHeavy => 'Fuerte';

  @override
  String get diveLog_profileEditor_applyToAll => 'Aplicar a todo';

  @override
  String get diveLog_profileEditor_applyToSelection => 'Aplicar a la selección';

  @override
  String get diveLog_profileEditor_outlierDetection =>
      'Detección de valores atípicos';

  @override
  String get diveLog_profileEditor_detect => 'Detectar';

  @override
  String get diveLog_profileEditor_removeAll => 'Eliminar todo';

  @override
  String diveLog_profileEditor_outliersDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posibles valores atípicos detectados',
      one: '$count posible valor atípico detectado',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_profileEditor_manualDrawing => 'Dibujo manual';

  @override
  String get diveLog_profileEditor_drawHint =>
      'Toca el gráfico para colocar puntos de referencia';

  @override
  String get diveLog_profileEditor_clearWaypoints => 'Borrar';

  @override
  String get diveLog_profileEditor_generateProfile => 'Generar perfil';

  @override
  String get diveLog_profileEditor_trimMode => 'Modo recorte';

  @override
  String get diveLog_profileEditor_trimHint =>
      'Recortar los extremos del perfil';

  @override
  String get diveLog_profileEditor_trimEnd => 'Recortar el final';

  @override
  String get diveLog_profileEditor_mode_smooth => 'Suavizar';

  @override
  String get diveLog_profileEditor_title => 'Editar perfil';

  @override
  String get diveLog_profileEditor_discardBody =>
      'Tienes cambios sin guardar en este perfil de inmersión. ¿Estás seguro de que deseas descartarlos?';

  @override
  String get diveLog_profileEditor_saveTitle => '¿Guardar el perfil?';

  @override
  String get diveLog_profileEditor_saveBody =>
      'Esto guardará el perfil editado como perfil principal de esta inmersión. El perfil original se conservará y se podrá restaurar más adelante.';

  @override
  String diveLog_profileEditor_saveFailed(String error) {
    return 'No se pudo guardar el perfil: $error';
  }

  @override
  String diveLog_profileEditor_errorLoadingDive(String error) {
    return 'Error al cargar la inmersión: $error';
  }

  @override
  String get diveLog_profileEditor_noProfileData =>
      'No hay datos de perfil disponibles';

  @override
  String get diveLog_profileEditor_undo => 'Deshacer';

  @override
  String get diveLog_profileEditor_mode_select => 'Seleccionar';

  @override
  String get diveLog_profileEditor_mode_outlier => 'Atípico';

  @override
  String get diveLog_profileEditor_mode_draw => 'Dibujar';

  @override
  String get diveLog_profileEditor_mode_trim => 'Recortar';

  @override
  String diveLog_sources_sectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fuentes de datos',
      one: 'Fuente de datos',
      zero: 'Fuente de datos',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_badge_manual => 'Manual';

  @override
  String get diveLog_sources_badge_viewing => 'Visualizando';

  @override
  String get diveLog_sources_badge_secondary => 'Secundaria';

  @override
  String diveLog_sources_created(String date) {
    return 'Creada el $date';
  }

  @override
  String get diveLog_sources_detail_serial => 'Número de serie';

  @override
  String get diveLog_sources_detail_format => 'Formato';

  @override
  String get diveLog_sources_detail_imported => 'Importado';

  @override
  String diveLog_detail_semantics_viewDiveComputer(String name) {
    return 'Ver ordenador de buceo $name';
  }

  @override
  String diveLog_detail_semantics_viewTrip(String name) {
    return 'Ver viaje $name';
  }

  @override
  String diveLog_detail_semantics_viewDiveCenter(String name) {
    return 'Ver centro de buceo $name';
  }

  @override
  String diveLog_detail_semantics_viewSpecies(String name) {
    return 'Ver especie $name';
  }

  @override
  String diveLog_detail_semantics_viewCourse(String name) {
    return 'Ver curso $name';
  }

  @override
  String diveLog_detail_serialNumber(String serial) {
    return 'N.º serie $serial';
  }

  @override
  String diveLog_detail_errorLoadingSignature(String error) {
    return 'Error al cargar la firma: $error';
  }

  @override
  String get diveLog_profilePanel_selectDive =>
      'Selecciona una inmersión para ver su perfil';

  @override
  String get diveLog_profilePanel_noProfileData =>
      'Sin datos de perfil para esta inmersión';

  @override
  String get settings_export_progress_divesCsv =>
      'Exportando inmersiones a CSV...';

  @override
  String get settings_export_progress_sitesCsv =>
      'Exportando puntos de buceo a CSV...';

  @override
  String get settings_export_progress_equipmentCsv =>
      'Exportando equipo a CSV...';

  @override
  String get settings_export_progress_pdf => 'Generando registro PDF...';

  @override
  String get settings_export_progress_loadingSignatures => 'Cargando firmas...';

  @override
  String get settings_export_progress_loadingCertifications =>
      'Cargando certificaciones...';

  @override
  String get settings_export_progress_loadingFonts => 'Cargando fuentes...';

  @override
  String settings_export_progress_templatePdf(String template) {
    return 'Generando PDF $template...';
  }

  @override
  String get settings_export_progress_uddf => 'Generando archivo UDDF...';

  @override
  String get settings_export_progress_collectingData =>
      'Recopilando todos los datos...';

  @override
  String get settings_export_progress_excel => 'Generando archivo Excel...';

  @override
  String get settings_export_progress_buildingExcel =>
      'Creando el libro de Excel...';

  @override
  String get settings_export_progress_kml => 'Generando archivo KML...';

  @override
  String get settings_export_progress_buildingKml =>
      'Creando el archivo KML...';

  @override
  String get settings_export_progress_preparingExcel =>
      'Preparando el archivo Excel...';

  @override
  String get settings_export_progress_preparingKml =>
      'Preparando el archivo KML...';

  @override
  String get settings_export_progress_chooseLocation =>
      'Elige la ubicación de guardado...';

  @override
  String get settings_export_progress_preparingDivesCsv =>
      'Preparando el CSV de inmersiones...';

  @override
  String get settings_export_progress_preparingSitesCsv =>
      'Preparando el CSV de puntos de buceo...';

  @override
  String get settings_export_progress_preparingEquipmentCsv =>
      'Preparando el CSV de equipo...';

  @override
  String get settings_export_progress_preparingUddf =>
      'Preparando el archivo UDDF...';

  @override
  String get settings_export_progress_preparingPdf => 'Preparando el PDF...';

  @override
  String get settings_export_progress_selectingBackup =>
      'Seleccionando el archivo de copia de seguridad...';

  @override
  String get settings_export_progress_restoringBackup =>
      'Restaurando desde la copia de seguridad...';

  @override
  String get settings_export_empty_dives => 'No hay inmersiones para exportar';

  @override
  String get settings_export_empty_sites =>
      'No hay puntos de buceo para exportar';

  @override
  String get settings_export_empty_equipment => 'No hay equipo para exportar';

  @override
  String get settings_export_empty_data => 'No hay datos para exportar';

  @override
  String get settings_export_empty_diveSites =>
      'No hay puntos de buceo para exportar';

  @override
  String settings_export_saveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String settings_export_backupFailed(String error) {
    return 'Error en la copia de seguridad: $error';
  }

  @override
  String settings_export_restoreFailed(String error) {
    return 'Error al restaurar: $error';
  }

  @override
  String get settings_export_fileUnreadable => 'No se pudo acceder al archivo';

  @override
  String get settings_export_notADbFile =>
      'Selecciona un archivo de copia de seguridad .db';

  @override
  String get settings_export_success_dives =>
      'Inmersiones exportadas correctamente';

  @override
  String get settings_export_success_sites =>
      'Puntos de buceo exportados correctamente';

  @override
  String get settings_export_success_equipment =>
      'Equipo exportado correctamente';

  @override
  String get settings_export_success_pdf =>
      'Registro PDF generado correctamente';

  @override
  String get settings_export_success_uddf =>
      'Archivo UDDF generado correctamente';

  @override
  String get settings_export_success_excel =>
      'Archivo Excel exportado correctamente';

  @override
  String settings_export_success_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Archivo KML exportado correctamente ($count puntos de buceo sin coordenadas omitidos)',
      one:
          'Archivo KML exportado correctamente (1 punto de buceo sin coordenadas omitido)',
      zero: 'Archivo KML exportado correctamente',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_excel =>
      'Archivo Excel guardado correctamente';

  @override
  String settings_export_saved_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Archivo KML guardado correctamente ($count puntos de buceo sin coordenadas omitidos)',
      one:
          'Archivo KML guardado correctamente (1 punto de buceo sin coordenadas omitido)',
      zero: 'Archivo KML guardado correctamente',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_divesCsv =>
      'CSV de inmersiones guardado correctamente';

  @override
  String get settings_export_saved_sitesCsv =>
      'CSV de puntos de buceo guardado correctamente';

  @override
  String get settings_export_saved_equipmentCsv =>
      'CSV de equipo guardado correctamente';

  @override
  String get settings_export_saved_uddf =>
      'Archivo UDDF guardado correctamente';

  @override
  String get settings_export_saved_pdf => 'PDF guardado correctamente';

  @override
  String get settings_export_saved_backup =>
      'Copia de seguridad guardada correctamente';

  @override
  String get settings_export_restoreComplete => 'Restauración completa';

  @override
  String get settings_export_cancelled_save => 'Guardado cancelado';

  @override
  String get settings_export_cancelled_backup => 'Copia de seguridad cancelada';

  @override
  String get settings_export_cancelled_restore => 'Restauración cancelada';

  @override
  String get settings_export_pdfDocumentTitle => 'Registro de buceo';

  @override
  String get settings_export_saveBackupDialogTitle =>
      'Guardar copia de seguridad';

  @override
  String backup_operation_created(String size) {
    return 'Copia de seguridad creada: $size';
  }

  @override
  String backup_operation_backupFailed(String error) {
    return 'Error en la copia de seguridad: $error';
  }

  @override
  String get backup_operation_restoring =>
      'Restaurando la copia de seguridad...';

  @override
  String backup_operation_restoreFailed(String error) {
    return 'Error al restaurar: $error';
  }

  @override
  String get backup_operation_deleting => 'Eliminando la copia de seguridad...';

  @override
  String get backup_operation_deleted => 'Copia de seguridad eliminada';

  @override
  String backup_operation_deleteFailed(String error) {
    return 'Error al eliminar: $error';
  }

  @override
  String get backup_operation_exporting =>
      'Exportando la copia de seguridad...';

  @override
  String backup_operation_exported(String size) {
    return 'Copia de seguridad exportada: $size';
  }

  @override
  String backup_operation_exportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get backup_operation_preparingShare =>
      'Preparando la copia de seguridad para compartir...';

  @override
  String get backup_operation_shareReady =>
      'Copia de seguridad lista para compartir';

  @override
  String backup_operation_upgrading(int step, int total) {
    return 'Actualizando la base de datos (paso $step de $total)...';
  }

  @override
  String backup_restore_dialog_counts(int diveCount, int siteCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount inmersiones',
      one: '1 inmersión',
    );
    String _temp1 = intl.Intl.pluralLogic(
      siteCount,
      locale: localeName,
      other: '$siteCount puntos de buceo',
      one: '1 punto de buceo',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get backup_restore_preMigration_title =>
      'Restaurar copia previa a la migración';

  @override
  String get backup_restore_preMigration_unknownVersion =>
      'versión desconocida';

  @override
  String get backup_restore_preMigration_restoreAnyway =>
      'Restaurar de todos modos';

  @override
  String backup_restore_preMigration_incompleteMetadata(
    String timestamp,
    String appVersion,
  ) {
    return 'Esta copia de seguridad se creó el $timestamp con la app $appVersion, pero sus metadatos de migración de la base de datos están incompletos.\n\nLa app no puede verificar si restaurar esta copia es seguro, por lo que la restauración está desactivada.';
  }

  @override
  String backup_restore_preMigration_newerApp(
    String timestamp,
    String appVersion,
    int fromVersion,
  ) {
    return 'Esta copia de seguridad es más reciente que tu app. Instala una versión más reciente de la app para restaurarla.\n\nCopia creada el $timestamp con la app $appVersion (base de datos v$fromVersion).';
  }

  @override
  String backup_restore_preMigration_safe(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
  ) {
    return 'Esta copia de seguridad se creó el $timestamp con la app $appVersion, justo antes de actualizar la base de datos de v$fromVersion a v$toVersion.\n\nEl esquema de base de datos de tu app coincide con esta copia, por lo que restaurarla es seguro.';
  }

  @override
  String backup_restore_preMigration_warning(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
    int currentVersion,
  ) {
    return 'Esta copia de seguridad se creó el $timestamp con la app $appVersion, justo antes de actualizar la base de datos de v$fromVersion a v$toVersion.\n\nEstás usando una app más reciente (base de datos v$currentVersion).\n\nRestaurar ahora volverá a ejecutar la actualización de base de datos de v$fromVersion a v$toVersion sobre tus datos restaurados, es decir, la misma actualización que iba a ejecutarse originalmente. Si esa actualización causó el problema, volverás a encontrarte con él.\n\nPara restaurar de forma segura: instala la app $appVersion o una anterior y restaura esta copia desde esa app más antigua.';
  }

  @override
  String get settings_cloudSync_progress_preparing =>
      'Preparando la sincronización...';

  @override
  String get settings_cloudSync_progress_pulling => 'Descargando cambios...';

  @override
  String get settings_cloudSync_progress_publishing => 'Publicando cambios...';

  @override
  String settings_cloudSync_progress_uploadingLibrary(int uploaded, int total) {
    return 'Subiendo la biblioteca ($uploaded de $total)';
  }

  @override
  String get settings_cloudSync_result_noProvider =>
      'No hay ningún proveedor en la nube configurado';

  @override
  String get settings_cloudSync_result_notAuthenticated =>
      'Sin autenticar con el proveedor en la nube';

  @override
  String get settings_cloudSync_result_timedOut =>
      'Se agotó el tiempo de sincronización';

  @override
  String get settings_cloudSync_result_epochMarkerUnreadable =>
      'No se pudo leer el marcador de época de la biblioteca';

  @override
  String get settings_cloudSync_result_epochMarkerEncrypted =>
      'El marcador de época de la biblioteca está cifrado';

  @override
  String get settings_cloudSync_result_libraryReplacedRemotely =>
      'La biblioteca en la nube se reemplazó desde una copia de seguridad';

  @override
  String get settings_cloudSync_result_noReplacementToRebuild =>
      'No hay ningún reemplazo de biblioteca desde el que reconstruir';

  @override
  String get settings_cloudSync_result_rebuiltFromThisDevice =>
      'Este servicio se reconstruyó a partir de la biblioteca de este dispositivo';

  @override
  String settings_cloudSync_result_rebuildFailed(String error) {
    return 'Error en la reconstrucción: $error';
  }

  @override
  String get settings_cloudSync_result_libraryReplaced =>
      'Biblioteca reemplazada';

  @override
  String settings_cloudSync_result_libraryReplaceFailed(String error) {
    return 'Error al reemplazar la biblioteca: $error';
  }

  @override
  String get settings_cloudSync_result_noReplacementMarker =>
      'No se encontró ningún marcador de reemplazo de biblioteca';

  @override
  String get settings_cloudSync_result_adoptedRestoredLibrary =>
      'Se adoptó la biblioteca restaurada';

  @override
  String settings_cloudSync_result_adoptFailed(String error) {
    return 'No se pudo adoptar la biblioteca restaurada: $error';
  }

  @override
  String get settings_cloudSync_result_previousLibraryUnreadable =>
      'No se pudo leer la biblioteca anterior; este servicio se restableció a partir de la biblioteca de este dispositivo.';

  @override
  String get settings_cloudSync_result_replacementStillUploading =>
      'La biblioteca reemplazada aún se está subiendo. Inténtalo de nuevo en un momento.';

  @override
  String settings_cloudSync_result_recordsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron aplicar $count registros',
      one: 'No se pudo aplicar 1 registro',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_result_adoptedFreshIdentity =>
      'Otro dispositivo se estaba sincronizando con la identidad de este dispositivo. Este dispositivo adoptó una identidad nueva y combinó los datos de la nube.';

  @override
  String settings_cloudSync_launchCheck_unavailable(String provider) {
    return '$provider no está disponible en este dispositivo';
  }

  @override
  String settings_cloudSync_launchCheck_notSignedIn(String provider) {
    return 'No has iniciado sesión en $provider';
  }

  @override
  String settings_cloudSync_launchCheck_localChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambios locales para subir',
      one: '1 cambio local para subir',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_launchCheck_noRemoteData =>
      'No se encontraron datos de sincronización en la nube';

  @override
  String get settings_cloudSync_launchCheck_cloudDataAvailable =>
      'Datos disponibles en la nube';

  @override
  String get settings_cloudSync_launchCheck_updatesAvailable =>
      'Actualizaciones disponibles en la nube';

  @override
  String get settings_cloudSync_launchCheck_upToDate => 'Todo está actualizado';

  @override
  String settings_cloudSync_launchCheck_failed(String error) {
    return 'Error al comprobar la sincronización: $error';
  }

  @override
  String get diveLog_detail_viewMap => 'Mapa';

  @override
  String get diveLog_detail_view3d => '3D';

  @override
  String get setup_sync_icloudUnavailable =>
      'iCloud no está disponible en este dispositivo';

  @override
  String get media_info_title => 'Información del medio';

  @override
  String get media_info_fileSection => 'Archivo';

  @override
  String get media_info_filename => 'Nombre del archivo';

  @override
  String get media_info_type => 'Tipo';

  @override
  String get media_info_dimensions => 'Dimensiones';

  @override
  String get media_info_size => 'Tamaño';

  @override
  String get media_info_taken => 'Capturada';

  @override
  String get media_info_coordinates => 'Coordenadas';

  @override
  String get media_info_unknown => 'Desconocido';

  @override
  String get media_info_originSection => 'Origen';

  @override
  String get media_info_source => 'Fuente';

  @override
  String get media_info_reference => 'Referencia';

  @override
  String get media_info_linkedOn => 'Vinculada en';

  @override
  String get media_info_thisDevice => 'Este dispositivo';

  @override
  String get media_info_otherDevice => 'Otro dispositivo';

  @override
  String get media_info_status => 'Estado';

  @override
  String get media_info_statusFound => 'Encontrada en este dispositivo';

  @override
  String get media_info_statusMissing => 'No esta en este dispositivo';

  @override
  String get media_info_statusUnchecked => 'Aun sin comprobar';

  @override
  String media_info_lastChecked(String date) {
    return 'Última comprobación $date';
  }

  @override
  String get media_timeInDive_label => 'Momento de la inmersión';

  @override
  String get media_timeInDive_unknown => 'Momento de la inmersión desconocido';

  @override
  String get media_timeInDive_setAction => 'Definir momento de la inmersión';

  @override
  String media_timeInDive_manual(String time) {
    return '$time (definido manualmente)';
  }

  @override
  String get media_timeInDive_fieldLabel =>
      'Tiempo desde el inicio de la inmersión';

  @override
  String get media_timeInDive_fieldHint => 'mm:ss';

  @override
  String media_timeInDive_range(String max) {
    return 'Entre 0:00 y $max';
  }

  @override
  String media_timeInDive_invalid(String max) {
    return 'Introduce un tiempo entre 0:00 y $max';
  }

  @override
  String get media_timeInDive_save => 'Guardar';

  @override
  String get media_timeInDive_cancel => 'Cancelar';

  @override
  String get media_timeInDive_reset => 'Restablecer a automático';

  @override
  String get media_info_backupSection => 'Copia de seguridad';

  @override
  String get media_info_store => 'Almacén en la nube';

  @override
  String get media_info_storeNotConnected => 'Sin almacén en la nube conectado';

  @override
  String get media_info_notEligible =>
      'Esta fuente no admite copia de seguridad';

  @override
  String get media_info_backupFull => 'Original subido';

  @override
  String get media_info_backupThumbOnly =>
      'Solo miniatura, el original no se envió';

  @override
  String get media_info_backupRenditionOnly => 'Versión comprimida subida';

  @override
  String get media_info_backupNone => 'Sin copia de seguridad';

  @override
  String media_info_uploadedOn(String date) {
    return 'Subida $date';
  }

  @override
  String get media_info_queuePending => 'Esperando para subir';

  @override
  String get media_info_queueTransferring => 'Subiendo ahora';

  @override
  String media_info_queueFailed(Object error) {
    return 'Falló la subida: $error';
  }

  @override
  String get media_info_servingSection => 'Sirviendo ahora';

  @override
  String get media_info_servingUnobserved => 'Aún no cargada';

  @override
  String get media_info_servingFailed => 'No se pudo cargar';

  @override
  String get media_info_servedLocalDisk => 'Archivo local en este dispositivo';

  @override
  String get media_info_servedGallery => 'Fototeca';

  @override
  String get media_info_servedStoreCache =>
      'Caché local, desde el almacén en la nube';

  @override
  String get media_info_servedStoreNetwork =>
      'Descargada del almacén en la nube';

  @override
  String get media_info_servedNetworkUrl => 'Transmitiendo desde una URL';

  @override
  String get media_info_servedConnectorCache =>
      'Caché local, del servicio conectado';

  @override
  String get media_info_servedConnectorNetwork =>
      'Descargada del servicio conectado';

  @override
  String get media_info_servedEmbedded => 'Guardada dentro de este cuaderno';

  @override
  String get media_info_servingFallbackNote =>
      'No se pudo acceder a la fuente original, así que el almacén en la nube la sirvió.';

  @override
  String get media_info_servingTierThumbnail => 'Miniatura';

  @override
  String get media_info_servingTierRendition => 'Versión comprimida';

  @override
  String get media_info_typePhoto => 'Foto';

  @override
  String get media_info_typeVideo => 'Vídeo';

  @override
  String get media_info_typeDocument => 'Documento';

  @override
  String get media_info_typeSignature => 'Firma';

  @override
  String get media_info_actionCheckNow => 'Comprobar ahora';

  @override
  String get media_info_actionLocate => 'Buscar archivo...';

  @override
  String get media_info_actionBackUpNow => 'Copiar ahora';

  @override
  String get media_info_actionRetryUpload => 'Reintentar subida';

  @override
  String get media_info_actionReveal => 'Mostrar en el gestor de archivos';

  @override
  String get media_info_actionCopyPath => 'Copiar referencia';

  @override
  String get media_info_referenceCopied => 'Referencia copiada';

  @override
  String get media_info_checkFound => 'Fuente encontrada';

  @override
  String get media_info_checkMissing => 'Falta la fuente';

  @override
  String get media_info_checkUnavailable => 'No se pudo comprobar ahora';

  @override
  String get media_info_backupQueued => 'En cola para subir';

  @override
  String get enum_profileMetric_o2CellMv => 'Células O2';

  @override
  String get enum_profileMetric_o2CellMv_short => 'Células';

  @override
  String get diveLog_o2CellSpread_label => 'Dispersión de células O2';

  @override
  String get media_status_broken => 'Falta y sin copia';

  @override
  String get media_servedFrom_localDisk => 'En este dispositivo';

  @override
  String get media_servedFrom_platformGallery => 'Fototeca';

  @override
  String get media_servedFrom_storeCache => 'Almacén en la nube, en caché aquí';

  @override
  String get media_servedFrom_storeNetwork => 'Almacén en la nube';

  @override
  String get media_servedFrom_networkUrl => 'Enlace web';

  @override
  String get media_servedFrom_connectorCache =>
      'Servicio conectado, en caché aquí';

  @override
  String get media_servedFrom_connectorNetwork => 'Servicio conectado';

  @override
  String get media_servedFrom_embedded => 'Guardado en este cuaderno';

  @override
  String get settings_media_provenanceBadges =>
      'Mostrar distintivos de origen en las miniaturas';

  @override
  String get settings_media_provenanceBadgesSubtitle =>
      'Un pequeño icono que indica de dónde procede cada elemento. Los distintivos de problemas siempre se muestran.';

  @override
  String get media_status_transferFailed => 'Falló la subida';

  @override
  String get media_status_transferring => 'Subiendo';

  @override
  String get media_status_queued => 'Esperando para subir';

  @override
  String get media_status_cloudOnly => 'Solo en la nube';

  @override
  String get media_status_notBackedUp => 'Sin copia de seguridad';

  @override
  String get media_tile_infoMenuItem => 'Información del medio';

  @override
  String get diveImport_healthkit_accessGrantedHint =>
      'Apple Salud nunca indica a las apps si se concedió el acceso de lectura. Si no aparece ninguna inmersión, abre Salud, luego Compartir, Apps, Submersion, y activa Entrenamientos, Profundidad bajo el agua, Temperatura del agua y Frecuencia cardíaca.';

  @override
  String get diveImport_healthkit_foundNoDivesHint =>
      'No hay entrenamientos de buceo en este intervalo. Comprueba que las fechas incluyan la inmersión y que en Salud, Compartir, Apps, Submersion estén activados Entrenamientos y Profundidad bajo el agua.';

  @override
  String get settings_dataSources_appleHealth_dataTypeDepth =>
      'Profundidad bajo el agua - muestras de profundidad registradas durante las inmersiones';

  @override
  String get settings_dataSources_appleHealth_dataTypeWaterTemp =>
      'Temperatura del agua - muestras de temperatura registradas durante las inmersiones';

  @override
  String get settings_dataSources_appleHealth_permissionManagedInHealth =>
      'El acceso a HealthKit se gestiona en la app Salud';

  @override
  String get settings_dataSources_appleHealth_permissionUnsupported =>
      'HealthKit no está disponible en este dispositivo';
}
